//! 組み込みの関数を呼ぶときの値の変換（設計書 02-08「参照インタプリタ」）。
//! BuiltinBridge は評価の実行ごとに一つ持つ。呼び出しごとに区間を開き、引数と結果を区間の中で
//! 変換し終えた後、成功・停止・終了のいずれでも回収する。中身を見せない値は Bridge の根の表で
//! 保持し、独自の値には表の位置だけを持たせる。次の区間では表から読み直し、終了時に根を手放す。
//! リソースも独自の番号で表す。セル・Lazy・継続は独自のストアで扱い、Force・Update は
//! 評価器が raw を呼ばず評価する。関数を引数に取るタスクの起動は変換の前に Unsupported にする。

use std::rc::Rc;

use super::resources::{self, Resources, Shared};
use super::value::{Value, Values};
use crate::builtins::iface::{
    BuiltinDecl, CallCtx, Capability, IoServices, IoWait, Reply, StateServices, WaitRequest,
};
use crate::builtins::table::call_builtin;
use crate::builtins::{BuiltinId, builtin_decl};
use crate::runtime::Stop;
use crate::runtime::heap::{
    CheckedLen, CtorTag, FieldsKind, Heap, HeapConfig, ObjKind, OpaqueData, RootStack, Trace,
    Tracer, Value as HeapValue, ValueCtx,
};
use crate::runtime::list;
use std::cell::RefCell;

/// F14 が継続の評価に戻す、区間に依存しない組み込みの関数の結果。
#[derive(Debug)]
pub(super) enum BuiltinOutcome {
    Done(Value),
    Stopped(Stop),
    Exited(u8),
    Unsupported(String),
}

/// 組み込みの関数との境目でだけ使う、実行ごとの一時ヒープ。
pub(super) struct BuiltinBridge {
    heap: Heap,
    roots: RootStack,
    pub(super) resources: Shared,
    #[cfg(test)]
    pub(super) overrides: std::collections::HashMap<BuiltinId, &'static BuiltinDecl>,
}

// 関数と位置は評価器の値のまま保持する。ヒープには呼び出し中の表の番号だけを置くので、
// ヒープの値や Slot を辿る必要はない（設計書 02-08「参照インタプリタ」）。
#[derive(Debug)]
struct RefValue(u32);
impl OpaqueData for RefValue {}
impl Trace for RefValue {
    fn trace(&self, _tracer: &mut Tracer<'_>) {}
}

impl BuiltinBridge {
    /// 実行ごとに作る。VM やほかの実行のヒープは借りない。
    pub(super) fn new() -> Self {
        Self {
            heap: Heap::new(HeapConfig::default()),
            roots: RootStack::new(),
            resources: Rc::new(RefCell::new(Resources::default())),
            #[cfg(test)]
            overrides: std::collections::HashMap::new(),
        }
    }

    /// 番号から表を引いて呼ぶ。状態の口は評価器から受け取る。
    pub(super) fn call(
        &mut self,
        id: BuiltinId,
        args: &[Value],
        io: &mut dyn IoServices,
        state: Option<&mut dyn StateServices>,
    ) -> BuiltinOutcome {
        let Some(decl) = self.declaration(id) else {
            return BuiltinOutcome::Stopped(Stop::Internal("unknown builtin number".into()));
        };
        self.call_decl(decl, args, io, state)
    }

    pub(super) fn declaration(&self, id: BuiltinId) -> Option<&'static BuiltinDecl> {
        #[cfg(test)]
        if let Some(decl) = self.overrides.get(&id) {
            return Some(*decl);
        }
        builtin_decl(id)
    }

    fn call_decl(
        &mut self,
        decl: &BuiltinDecl,
        args: &[Value],
        io: &mut dyn IoServices,
        state: Option<&mut dyn StateServices>,
    ) -> BuiltinOutcome {
        let resources = Rc::clone(&self.resources);
        let mut io = resources::Io {
            base: io,
            resources: Rc::clone(&resources),
        };
        let roots = &mut self.roots;
        let result = self.heap.epoch(|ctx| {
            let mut references = Vec::new();
            let opaque = (0..roots.len())
                .map(|n| {
                    roots
                        .get(ctx, crate::runtime::heap::RootIdx(n))
                        .ok_or_else(invalid_conversion)
                })
                .collect::<Result<Vec<_>, _>>()?;
            let args = args
                .iter()
                .map(|v| to_heap_with(ctx, v, decl.name, &opaque, &mut references))
                .collect::<Result<Vec<_>, _>>()?;
            let reply = call_builtin(
                decl,
                ctx,
                if decl.capability == Capability::Io {
                    Some(&mut io)
                } else {
                    None
                },
                state,
                None,
                &args,
            )?;
            let value = match reply {
                Reply::Done(value) => value,
                Reply::Wait(WaitRequest::Io(IoWait::Worker(wait))) => {
                    // 貸すリソースを独自の表から借り、完了の処理では登録の口を同じ表に戻す（F14「解放」）。
                    let done = resources
                        .try_borrow_mut()
                        .map_err(|_| resources::fault())?
                        .worker(wait)?;
                    done.complete(
                        &mut CallCtx::new(ctx, Some(&mut io), None, None).io_ctx()?,
                        &args,
                    )?
                }
                Reply::Wait(WaitRequest::Io(
                    IoWait::Sleep { .. } | IoWait::Readiness { .. } | IoWait::Output { .. },
                ))
                | Reply::Wait(WaitRequest::State(_)) => {
                    return Err(Stop::Internal("unsupported reference builtin wait".into()));
                }
                Reply::SpawnTasks(_) => return Ok(BuiltinOutcome::Unsupported(decl.name.into())),
                Reply::Exit(status) => return Ok(BuiltinOutcome::Exited(status.0)),
            };
            from_heap_with(ctx, value, &mut |v| {
                if let Some(reference) = ctx.opaque::<RefValue>(v) {
                    references
                        .get(usize::try_from(reference.0).map_err(|_| invalid_conversion())?)
                        .cloned()
                        .ok_or_else(invalid_conversion)
                } else {
                    Ok(Value::Opaque(roots.push(ctx, v).0))
                }
            })
            .map(BuiltinOutcome::Done)
        });
        self.heap.collect(&self.roots);
        if let Some(fault) = self.heap.take_fault() {
            return BuiltinOutcome::Stopped(Stop::Internal(fault.detail));
        }
        if let Ok(mut table) = resources.try_borrow_mut()
            && let Some(fault) = table.take_fault()
        {
            return BuiltinOutcome::Stopped(fault);
        }
        result.unwrap_or_else(BuiltinOutcome::Stopped)
    }
}
impl Drop for BuiltinBridge {
    fn drop(&mut self) {
        self.heap.epoch(|ctx| self.roots.truncate(ctx, 0));
        self.heap.collect(&self.roots);
    }
}

enum ToHeap<'a> {
    Visit(&'a Value),
    Ctor { tag: u32, len: usize },
    List { len: usize },
    Map { len: usize },
    Set { len: usize },
}

// 子を先に変換し、明示した作業列で親を組み立てる（実装プラン 00-02「再帰の深さ」）。
fn to_heap_with<'e>(
    ctx: &ValueCtx<'e>,
    value: &Value,
    function: &'static str,
    opaque: &[HeapValue<'e>],
    references: &mut Vec<Value>,
) -> Result<HeapValue<'e>, Stop> {
    let mut pending = vec![ToHeap::Visit(value)];
    let mut ready = Vec::new();
    while let Some(step) = pending.pop() {
        match step {
            ToHeap::Visit(value) => match value {
                Value::Decimal(d) => ready.push(ctx.alloc_decimal(*d)),
                Value::Resource(id) => ready.push(HeapValue::Resource(*id)),
                Value::Opaque(n) => ready.push(
                    *opaque
                        .get(usize::try_from(*n).map_err(|_| invalid_conversion())?)
                        .ok_or_else(invalid_conversion)?,
                ),
                Value::Map(items) if items.items.is_empty() => ready.push(HeapValue::EmptyMap),
                Value::Map(items) => {
                    pending.push(ToHeap::Map {
                        len: items.items.len(),
                    });
                    pending.extend(items.items.iter().rev().map(ToHeap::Visit));
                }
                Value::Set(items) if items.items.is_empty() => ready.push(HeapValue::EmptySet),
                Value::Set(items) => {
                    pending.push(ToHeap::Set {
                        len: items.items.len(),
                    });
                    pending.extend(items.items.iter().rev().map(ToHeap::Visit));
                }
                Value::Func(_) | Value::Location(_) => {
                    let index =
                        u32::try_from(references.len()).map_err(|_| invalid_conversion())?;
                    references.push(value.clone());
                    ready.push(ctx.alloc_opaque(RefValue(index)));
                }
                Value::Dict { .. } => return Err(invalid_conversion()),
                Value::Int(n) => ready.push(HeapValue::Int(*n)),
                Value::Float(x) => ready.push(HeapValue::Float(*x)),
                Value::Byte(b) => ready.push(HeapValue::Byte(*b)),
                Value::Bool(b) => ready.push(HeapValue::Bool(*b)),
                Value::Char(c) => ready.push(HeapValue::Char(*c)),
                Value::Unit => ready.push(HeapValue::Unit),
                Value::Str(s) => ready.push(ctx.alloc_str(s, function)?),
                Value::Bytes(b) => ready.push(ctx.alloc_bytes(b, function)?),
                Value::Ctor { tag, args } => {
                    if args.items.is_empty() {
                        ready.push(HeapValue::Tag(CtorTag(*tag)));
                    } else {
                        u32::try_from(args.items.len()).map_err(|_| invalid_conversion())?;
                        pending.push(ToHeap::Ctor {
                            tag: *tag,
                            len: args.items.len(),
                        });
                        pending.extend(args.items.iter().rev().map(ToHeap::Visit));
                    }
                }
                Value::List(items) => {
                    let len = items.items.len();
                    CheckedLen::elements(
                        u64::try_from(len).map_err(|_| invalid_conversion())?,
                        function,
                    )?;
                    pending.push(ToHeap::List { len });
                    pending.extend(items.items.iter().rev().map(ToHeap::Visit));
                }
                Value::IoError { kind, reason } => {
                    let reason = ctx.alloc_str(reason, function)?;
                    ready.push(ctx.alloc_fields(FieldsKind::IoError, *kind, &[reason])?);
                }
            },
            ToHeap::Map { len } | ToHeap::Set { len } => {
                let start = ready
                    .len()
                    .checked_sub(len)
                    .ok_or_else(invalid_conversion)?;
                let items = ready.get(start..).ok_or_else(invalid_conversion)?;
                let value = match step {
                    ToHeap::Map { .. } => {
                        if len % 2 != 0 {
                            return Err(invalid_conversion());
                        }
                        let pairs = items
                            .as_chunks::<2>()
                            .0
                            .iter()
                            .map(|[k, v]| (*k, *v))
                            .collect::<Vec<_>>();
                        crate::runtime::map::map_from_sorted(ctx, &pairs, function)?
                    }
                    ToHeap::Set { .. } => {
                        crate::runtime::map::set_from_sorted(ctx, items, function)?
                    }
                    ToHeap::Visit(_) | ToHeap::Ctor { .. } | ToHeap::List { .. } => {
                        return Err(invalid_conversion());
                    }
                };
                ready.truncate(start);
                ready.push(value);
            }
            ToHeap::Ctor { tag, len } => {
                let start = ready
                    .len()
                    .checked_sub(len)
                    .ok_or_else(invalid_conversion)?;
                let fields = ready.get(start..).ok_or_else(invalid_conversion)?;
                let value = ctx.alloc_fields(FieldsKind::Ctor, tag, fields)?;
                ready.truncate(start);
                ready.push(value);
            }
            ToHeap::List { len } => {
                let start = ready
                    .len()
                    .checked_sub(len)
                    .ok_or_else(invalid_conversion)?;
                let items = ready.get(start..).ok_or_else(invalid_conversion)?;
                let value = list::from_values(ctx, items, function)?;
                ready.truncate(start);
                ready.push(value);
            }
        }
    }
    if ready.len() != 1 {
        return Err(invalid_conversion());
    }
    ready.pop().ok_or_else(invalid_conversion)
}

enum FromHeap<'e> {
    Visit(HeapValue<'e>),
    Ctor { tag: u32, len: usize },
    List { len: usize },
    Map { len: usize },
    Set { len: usize },
}

// 区間が閉じる前に、ヒープを指さない値へ戻す。リストは公開 API で読む（設計書 02-08「参照インタプリタ」）。
fn from_heap_with<'e>(
    ctx: &ValueCtx<'e>,
    value: HeapValue<'e>,
    opaque: &mut impl FnMut(HeapValue<'e>) -> Result<Value, Stop>,
) -> Result<Value, Stop> {
    let mut pending = vec![FromHeap::Visit(value)];
    let mut ready = Vec::new();
    while let Some(step) = pending.pop() {
        match step {
            FromHeap::Visit(value) => match value {
                HeapValue::Int(n) => ready.push(Value::Int(n)),
                HeapValue::Float(x) => ready.push(Value::Float(x)),
                HeapValue::Byte(b) => ready.push(Value::Byte(b)),
                HeapValue::Bool(b) => ready.push(Value::Bool(b)),
                HeapValue::Char(c) => ready.push(Value::Char(c)),
                HeapValue::Unit => ready.push(Value::Unit),
                HeapValue::Tag(tag) => ready.push(Value::ctor(tag.0, Vec::new())),
                HeapValue::EmptyList => ready.push(Value::list(Vec::new())),
                HeapValue::Resource(id) => ready.push(Value::Resource(id)),
                HeapValue::EmptyMap => ready.push(Value::Map(Rc::new(Values { items: vec![] }))),
                HeapValue::EmptySet => ready.push(Value::Set(Rc::new(Values { items: vec![] }))),
                HeapValue::Obj(_) => match ctx.kind(value).ok_or_else(invalid_conversion)? {
                    ObjKind::Str => ready.push(Value::Str(Rc::from(
                        ctx.str(value).ok_or_else(invalid_conversion)?,
                    ))),
                    ObjKind::Bytes => ready.push(Value::Bytes(Rc::from(
                        ctx.bytes(value).ok_or_else(invalid_conversion)?,
                    ))),
                    ObjKind::Fields(FieldsKind::Ctor) => {
                        let (_, tag) = ctx.fields_header(value).ok_or_else(invalid_conversion)?;
                        let len = ctx.fields_len(value).ok_or_else(invalid_conversion)?;
                        pending.push(FromHeap::Ctor {
                            tag,
                            len: usize::try_from(len).map_err(|_| invalid_conversion())?,
                        });
                        for i in (0..len).rev() {
                            pending.push(FromHeap::Visit(
                                ctx.field(value, i).ok_or_else(invalid_conversion)?,
                            ));
                        }
                    }
                    ObjKind::Fields(_) if list::is_list(ctx, value) => {
                        let items = list::to_vec(ctx, value)?;
                        pending.push(FromHeap::List { len: items.len() });
                        pending.extend(items.into_iter().rev().map(FromHeap::Visit));
                    }
                    ObjKind::Fields(FieldsKind::IoError) => {
                        let (_, kind) = ctx.fields_header(value).ok_or_else(invalid_conversion)?;
                        if ctx.fields_len(value) != Some(1) {
                            return Err(invalid_conversion());
                        }
                        let reason = ctx.field(value, 0).ok_or_else(invalid_conversion)?;
                        ready.push(Value::IoError {
                            kind,
                            reason: Rc::from(ctx.str(reason).ok_or_else(invalid_conversion)?),
                        });
                    }
                    ObjKind::Decimal => ready.push(Value::Decimal(
                        ctx.decimal(value).ok_or_else(invalid_conversion)?,
                    )),
                    ObjKind::Fields(FieldsKind::MapNode) => {
                        let pairs = crate::runtime::map::map_to_vec(ctx, value)?;
                        let len = pairs.len().checked_mul(2).ok_or_else(invalid_conversion)?;
                        pending.push(FromHeap::Map { len });
                        for (k, v) in pairs.into_iter().rev() {
                            pending.push(FromHeap::Visit(v));
                            pending.push(FromHeap::Visit(k));
                        }
                    }
                    ObjKind::Fields(FieldsKind::SetNode) => {
                        let items = crate::runtime::map::set_to_vec(ctx, value)?;
                        pending.push(FromHeap::Set { len: items.len() });
                        pending.extend(items.into_iter().rev().map(FromHeap::Visit));
                    }
                    ObjKind::Opaque | ObjKind::Host | ObjKind::Fields(FieldsKind::NetworkError) => {
                        ready.push(opaque(value)?)
                    }
                    ObjKind::Cell
                    | ObjKind::Fields(
                        FieldsKind::Func
                        | FieldsKind::Dict
                        | FieldsKind::ListCell
                        | FieldsKind::ListNode,
                    ) => {
                        return Err(invalid_conversion());
                    }
                },
            },
            FromHeap::Map { len } | FromHeap::Set { len } => {
                let start = ready
                    .len()
                    .checked_sub(len)
                    .ok_or_else(invalid_conversion)?;
                let items = Rc::new(Values {
                    items: ready.split_off(start),
                });
                ready.push(match step {
                    FromHeap::Map { .. } => Value::Map(items),
                    FromHeap::Set { .. } => Value::Set(items),
                    FromHeap::Visit(_) | FromHeap::Ctor { .. } | FromHeap::List { .. } => {
                        return Err(invalid_conversion());
                    }
                });
            }
            FromHeap::Ctor { tag, len } => {
                let start = ready
                    .len()
                    .checked_sub(len)
                    .ok_or_else(invalid_conversion)?;
                let items = ready.split_off(start);
                ready.push(Value::ctor(tag, items));
            }
            FromHeap::List { len } => {
                let start = ready
                    .len()
                    .checked_sub(len)
                    .ok_or_else(invalid_conversion)?;
                let items = ready.split_off(start);
                ready.push(Value::list(items));
            }
        }
    }
    if ready.len() != 1 {
        return Err(invalid_conversion());
    }
    ready.pop().ok_or_else(invalid_conversion)
}

fn invalid_conversion() -> Stop {
    Stop::Internal("unsupported or malformed reference builtin value".into())
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use std::ffi::OsString;
    use std::path::{Path, PathBuf};

    use super::super::value::{Closure, FunctionCode, values_equal};
    use super::*;
    use crate::builtins::funcs::samples;
    use crate::builtins::iface::{
        CallCtx, IoReply, OsResource, Spawn, SpawnMode, StateReply, StateWait, TaskPoll, builtin,
    };
    use crate::builtins::table::{complete_worker, tags};
    use crate::runtime::heap::{HostData, NoGcCtx, OpaqueData, ResourceId, Trace, Tracer};
    use crate::runtime::{
        MAX_STRING_BYTES, ResourceError, ResourceKind, RuntimeError, SizeUnit, Stream,
    };
    use crate::vm::InstrRef;

    fn to_heap<'e>(
        ctx: &ValueCtx<'e>,
        v: &Value,
        function: &'static str,
    ) -> Result<HeapValue<'e>, Stop> {
        to_heap_with(ctx, v, function, &[], &mut Vec::new())
    }
    fn from_heap<'e>(ctx: &ValueCtx<'e>, v: HeapValue<'e>) -> Result<Value, Stop> {
        from_heap_with(ctx, v, &mut |_| Err(invalid_conversion()))
    }

    // 作成時の関門: 変換でタグ・順序・文字・エラーの内容を失わないことと、非再帰を守る。
    // R06 のテストは独自の値との変換を通らない。R10 が求めた非公開の境界で往復し、
    // 等値規則のテストとは別に、ヒープ側の種類も確かめる。差し込み口は加えない。
    fn round_trip(heap: &mut Heap, input: &Value) -> Value {
        let output =
            heap.epoch(|ctx| from_heap(ctx, to_heap(ctx, input, "test").unwrap()).unwrap());
        heap.collect(&RootStack::new());
        assert!(heap.take_fault().is_none());
        assert!(heap.object_ids().is_empty());
        output
    }

    #[test]
    fn round_trips_preserve_stage_one_values_and_heap_kinds() {
        let mut heap = Heap::new(HeapConfig::default());
        for input in [
            Value::Resource(ResourceId(0)),
            Value::Map(Rc::new(Values { items: vec![] })),
            Value::Set(Rc::new(Values { items: vec![] })),
            Value::Int(i64::MIN),
            Value::Int(i64::MAX),
            Value::Float(-0.0),
            Value::Float(f64::INFINITY),
            Value::Byte(255),
            Value::Bool(true),
            Value::Char('あ'),
            Value::Unit,
            Value::Str(Rc::from("")),
            Value::Str(Rc::from("éあ\0")),
            Value::Bytes(Rc::from([])),
            Value::Bytes(Rc::from([0, 255].as_slice())),
            Value::list(vec![]),
            Value::list(vec![Value::Unit]),
            Value::list(vec![Value::Int(1), Value::Int(2), Value::Int(3)]),
            Value::ctor(37, vec![]),
            Value::ctor(38, vec![Value::Int(17)]),
            Value::ctor(
                39,
                vec![
                    Value::ctor(40, vec![Value::Char('あ')]),
                    Value::list(vec![Value::ctor(41, vec![])]),
                ],
            ),
        ] {
            let output = round_trip(&mut heap, &input);
            assert!(
                if matches!(input, Value::Resource(_)) {
                    matches!(output, Value::Resource(ResourceId(0)))
                } else {
                    values_equal(&input, &output).unwrap()
                },
                "{input:?}, {output:?}"
            );
        }
        heap.epoch(|ctx| {
            assert!(matches!(
                to_heap(ctx, &Value::ctor(37, vec![]), "test").unwrap(),
                HeapValue::Tag(CtorTag(37))
            ));
            let value = to_heap(ctx, &Value::ctor(38, vec![Value::Int(17)]), "test").unwrap();
            assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, 38)));
            assert_eq!(ctx.field(value, 0).unwrap().as_int(), Some(17));
            assert!(matches!(
                to_heap(ctx, &Value::list(vec![]), "test").unwrap(),
                HeapValue::EmptyList
            ));
            let nan = to_heap(ctx, &Value::Float(f64::NAN), "test").unwrap();
            assert!(matches!(from_heap(ctx, nan).unwrap(), Value::Float(x) if x.is_nan()));
        });
        // IOError は非等値の型なので、種類と理由の保存を別に確かめる（設計書 01-06「等値の型」）。
        for kind in 0..=8 {
            let input = Value::IoError {
                kind,
                reason: Rc::from("理由\0"),
            };
            let Value::IoError {
                kind: actual,
                reason,
            } = round_trip(&mut heap, &input)
            else {
                panic!("IOError")
            };
            assert_eq!(actual, kind);
            assert_eq!(&*reason, "理由\0");
        }
    }

    #[test]
    #[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
    fn million_element_lists_and_million_deep_constructors_round_trip_and_drop() {
        let mut heap = Heap::new(HeapConfig::default());
        let input = Value::list((0..1_000_000).map(Value::Int).collect());
        let output = round_trip(&mut heap, &input);
        assert!(values_equal(&input, &output).unwrap());
        drop(input);
        drop(output);
        let mut input = Value::Int(17);
        for _ in 0..1_000_000 {
            input = Value::ctor(3, vec![input]);
        }
        let output = round_trip(&mut heap, &input);
        assert!(values_equal(&input, &output).unwrap());
        let shared = input.clone();
        drop(Value::ctor(4, vec![input.clone(), input]));
        assert!(values_equal(&shared, &output).unwrap());
        drop(shared);
        drop(output);
    }

    #[derive(Debug)]
    struct Opaque;
    impl OpaqueData for Opaque {}
    #[derive(Debug)]
    struct Host;
    impl Trace for Host {
        fn trace(&self, _t: &mut Tracer<'_>) {}
    }
    impl HostData for Host {}

    #[test]
    fn unsupported_and_malformed_values_are_internal_errors() {
        let mut bridge = BuiltinBridge::new();
        let mut io = TestIo {
            directory: PathBuf::from("."),
        };
        let func = Value::Func(Rc::new(Closure {
            code: FunctionCode::TopFn(crate::base::BindingId(0)),
            captures: vec![],
            impl_dicts: Rc::new(Values { items: vec![] }),
        }));
        assert!(matches!(
            bridge.call_decl(&samples::integer_absolute::DECL, &[func], &mut io, None),
            BuiltinOutcome::Stopped(Stop::Internal(_))
        ));
        assert!(bridge.heap.object_ids().is_empty());
        bridge.heap.epoch(|ctx| {
            for value in [
                ctx.alloc_cell(HeapValue::Unit),
                ctx.alloc_host(Host),
                ctx.alloc_opaque(Opaque),
                ctx.alloc_fields(FieldsKind::Func, 0, &[]).unwrap(),
                ctx.alloc_fields(FieldsKind::Dict, 0, &[]).unwrap(),
                ctx.alloc_fields(FieldsKind::IoError, 0, &[]).unwrap(),
                ctx.alloc_fields(FieldsKind::IoError, 0, &[HeapValue::Int(1)])
                    .unwrap(),
            ] {
                assert!(matches!(from_heap(ctx, value), Err(Stop::Internal(_))));
            }
        });
    }

    struct TestIo {
        directory: PathBuf,
    }
    impl IoServices for TestIo {
        fn write_output(&mut self, _stream: Stream, _text: &str) -> Result<Option<IoWait>, Stop> {
            panic!("unexpected output")
        }
        fn arguments(&self) -> &[String] {
            &[]
        }
        fn script_directory(&self) -> &Path {
            &self.directory
        }
        fn working_directory(&self) -> &Path {
            &self.directory
        }
        fn environment_variable(&self, _name: &str) -> Option<OsString> {
            None
        }
        fn now_millis(&self) -> i64 {
            0
        }
        fn local_offset_minutes(&self) -> i32 {
            0
        }
        fn monotonic_millis(&self) -> i64 {
            0
        }
        fn random_u64(&mut self) -> u64 {
            panic!("unexpected randomness")
        }
        fn register_resource(
            &mut self,
            _kind: ResourceKind,
            _handle: Box<dyn OsResource>,
            _opened_at: Option<InstrRef>,
        ) -> ResourceId {
            panic!("unexpected resource")
        }
    }

    // 作成時の関門: 呼び出しの境目で、包みへの引数・応答の変換・停止の伝達・回収を守る。
    // R07 は独自の値を使わないためこの退行を捕まえない。本体の直接の結果と仕様の期待値を
    // 両方確かめる。見本は本番の表にないので R10 の指示に従い call_decl で呼ぶ。
    fn done(outcome: BuiltinOutcome) -> Value {
        match outcome {
            BuiltinOutcome::Done(value) => value,
            other @ (BuiltinOutcome::Stopped(_)
            | BuiltinOutcome::Exited(_)
            | BuiltinOutcome::Unsupported(_)) => panic!("expected value: {other:?}"),
        }
    }

    #[test]
    fn samples_match_direct_bodies_and_preserve_stops() {
        let mut bridge = BuiltinBridge::new();
        let mut io = TestIo {
            directory: PathBuf::from("."),
        };
        let mut direct_heap = Heap::new(HeapConfig::default());
        for n in [-17, 0, i64::MAX, i64::MIN] {
            let direct = direct_heap.epoch(|ctx| {
                samples::integer_absolute(CallCtx::new(ctx, None, None, None).pure_ctx(), n)
            });
            let actual = bridge.call_decl(
                &samples::integer_absolute::DECL,
                &[Value::Int(n)],
                &mut io,
                None,
            );
            match direct {
                Ok(expected) => assert!(matches!(done(actual), Value::Int(n) if n == expected)),
                Err(stop) => {
                    assert_eq!(stop, Stop::Runtime(RuntimeError::IntegerOverflow));
                    assert!(matches!(actual, BuiltinOutcome::Stopped(actual) if actual == stop));
                }
            }
        }
        for (s, n, expected) in [
            ("あ", 2, "ああ"),
            ("ab", 3, "ababab"),
            ("ab", -1, ""),
            ("", i64::MAX, ""),
        ] {
            let direct = direct_heap.epoch(|ctx| {
                let result =
                    samples::string_repeat(CallCtx::new(ctx, None, None, None).pure_ctx(), s, n)
                        .unwrap();
                ctx.str(result).unwrap().to_owned()
            });
            let actual = done(bridge.call_decl(
                &samples::string_repeat::DECL,
                &[Value::Str(Rc::from(s)), Value::Int(n)],
                &mut io,
                None,
            ));
            assert_eq!(direct, expected);
            assert!(values_equal(&actual, &Value::Str(Rc::from(expected))).unwrap());
        }
        for (s, n, size) in [
            (
                "ab",
                i64::try_from(MAX_STRING_BYTES / 2 + 1).unwrap(),
                MAX_STRING_BYTES + 2,
            ),
            ("abc", i64::MAX, u64::MAX),
        ] {
            let direct = direct_heap.epoch(|ctx| {
                samples::string_repeat(CallCtx::new(ctx, None, None, None).pure_ctx(), s, n)
                    .unwrap_err()
            });
            assert_eq!(
                direct,
                Stop::Resource(ResourceError::ValueTooLarge {
                    function: "Sample.repeat",
                    size,
                    unit: SizeUnit::Bytes,
                    limit: MAX_STRING_BYTES
                })
            );
            assert!(
                matches!(bridge.call_decl(&samples::string_repeat::DECL, &[Value::Str(Rc::from(s)), Value::Int(n)], &mut io, None), BuiltinOutcome::Stopped(stop) if stop == direct)
            );
        }
        // 本番の番号の経路も本物の表につなぎ、別名の呼び出しで代用しない。
        let id = crate::builtins::lookup_builtin("Integer.absolute").unwrap();
        assert!(matches!(
            done(bridge.call(id, &[Value::Int(-17)], &mut io, None)),
            Value::Int(17)
        ));
        assert!(matches!(
            bridge.call(BuiltinId(u16::MAX), &[], &mut io, None),
            BuiltinOutcome::Stopped(Stop::Internal(_))
        ));
        assert!(bridge.heap.object_ids().is_empty());
    }

    struct TempDirectory(PathBuf);
    impl TempDirectory {
        fn new() -> Self {
            let base = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target");
            std::fs::create_dir_all(&base).unwrap();
            for attempt in 0..1000 {
                let path = base.join(format!("r10-read-{}-{attempt}", std::process::id()));
                match std::fs::create_dir(&path) {
                    Ok(()) => return Self(path),
                    Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {}
                    Err(error) => panic!("cannot create directory: {error}"),
                }
            }
            panic!("no unused directory")
        }
    }
    impl Drop for TempDirectory {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).unwrap();
        }
    }

    #[test]
    fn read_text_worker_finishes_synchronously_and_preserves_io_errors() {
        let directory = TempDirectory::new();
        std::fs::write(directory.0.join("valid"), "hello あ\n").unwrap();
        std::fs::write(directory.0.join("invalid"), [0xff]).unwrap();
        let mut io = TestIo {
            directory: directory.0.clone(),
        };
        let mut bridge = BuiltinBridge::new();
        let mut direct_heap = Heap::new(HeapConfig::default());
        for (path, error) in [
            ("valid", None),
            ("missing", Some(tags::IO_ERROR_KIND_NOT_FOUND)),
            ("invalid", Some(tags::IO_ERROR_KIND_INVALID_UTF8)),
        ] {
            let direct = direct_heap.epoch(|ctx| {
                let mut call = CallCtx::new(ctx, Some(&mut io), None, None);
                let IoReply::Wait(IoWait::Worker(wait)) =
                    samples::file_read_text(call.io_ctx().unwrap(), path).unwrap()
                else {
                    panic!("worker")
                };
                let result = complete_worker(wait, ctx, &mut io, None, &[]).unwrap();
                from_heap(ctx, result).unwrap()
            });
            let actual = done(bridge.call_decl(
                &samples::file_read_text::DECL,
                &[Value::Str(Rc::from(path))],
                &mut io,
                None,
            ));
            let Value::Ctor { tag, args } = &actual else {
                panic!("Result")
            };
            assert_eq!(args.items.len(), 1);
            if let Some(expected_kind) = error {
                assert_eq!(*tag, tags::RESULT_ERROR);
                let Value::IoError { kind, reason } = &args.items[0] else {
                    panic!("IOError")
                };
                assert_eq!(*kind, expected_kind);
                assert!(!reason.is_empty());
                let Value::Ctor {
                    tag: direct_tag,
                    args: direct_args,
                } = direct
                else {
                    panic!("direct Result")
                };
                let Value::IoError {
                    kind: direct_kind,
                    reason: direct_reason,
                } = &direct_args.items[0]
                else {
                    panic!("direct IOError")
                };
                assert_eq!(*tag, direct_tag);
                assert_eq!(kind, direct_kind);
                assert_eq!(reason, direct_reason);
            } else {
                assert_eq!(*tag, tags::RESULT_OK);
                assert!(
                    values_equal(
                        &actual,
                        &Value::ctor(tags::RESULT_OK, vec![Value::Str(Rc::from("hello あ\n"))])
                    )
                    .unwrap()
                );
                assert!(values_equal(&actual, &direct).unwrap());
            }
            assert!(bridge.heap.object_ids().is_empty());
        }
    }

    builtin! {
        /// 終了の応答を変換の境目で確かめる。
        name = "Test.exit",
        io fn exit(ctx) -> IoReply<'e> {
            let _ = ctx;
            Ok(IoReply::Exit(crate::builtins::iface::ExitStatus(37)))
        }
    }
    builtin! {
        /// Worker 以外の待ちを実行しないことを確かめる。
        name = "Test.sleep",
        io fn sleep(ctx) -> IoReply<'e> {
            let _ = ctx;
            Ok(IoReply::Wait(IoWait::Sleep { millis: 1 }))
        }
    }
    builtin! {
        /// タスクの起動を停止の理由と区別することを確かめる。
        name = "Test.spawn",
        state fn spawn(ctx) -> StateReply<'e> {
            let _ = ctx;
            Ok(StateReply::SpawnTasks(Spawn { funcs: vec![], mode: SpawnMode::All }))
        }
    }
    struct TestState;
    impl StateServices for TestState {
        fn task_poll<'e>(
            &mut self,
            _ctx: &NoGcCtx<'e>,
            _task: HeapValue<'e>,
        ) -> Result<TaskPoll<'e>, Stop> {
            panic!("unexpected task poll")
        }
        fn open_task_group(&mut self, _opened_at: Option<InstrRef>) -> ResourceId {
            panic!("unexpected task group")
        }
        fn begin_release(&mut self, _resource: ResourceId) -> Result<Option<StateWait>, Stop> {
            panic!("unexpected release")
        }
    }

    #[test]
    fn exit_spawn_and_other_waits_remain_distinct() {
        let mut bridge = BuiltinBridge::new();
        let mut io = TestIo {
            directory: PathBuf::from("."),
        };
        assert!(matches!(
            bridge.call_decl(&exit::DECL, &[], &mut io, None),
            BuiltinOutcome::Exited(37)
        ));
        assert!(matches!(
            bridge.call_decl(&sleep::DECL, &[], &mut io, None),
            BuiltinOutcome::Stopped(Stop::Internal(_))
        ));
        assert!(
            matches!(bridge.call_decl(&spawn::DECL, &[], &mut io, Some(&mut TestState)), BuiltinOutcome::Unsupported(name) if name == "Test.spawn")
        );
        assert!(bridge.heap.object_ids().is_empty());
    }
    builtin! {
        /// 中身を見せない値は、変換の境目の表でだけ保持する（F14、設計書 02-08「参照インタプリタ」）。
        name = "Test.makeOpaque",
        pure fn make_opaque(ctx) -> HeapValue<'e> { Ok(ctx.alloc_opaque(Opaque)) }
    }
    builtin! {
        /// 回収を挟んでも同じ中身を見せない値を本体へ渡す。
        name = "Test.readOpaque",
        pure fn read_opaque(ctx, v: HeapValue<'e>) -> i64 {
            if ctx.opaque::<Opaque>(v).is_none() {return Err(Stop::Internal("missing opaque value".into()));}
            Ok(42)
        }
    }
    // 作成時の関門: opaque の根を保持し、区間を越えて読み直す契約を守る。
    // 既存の往復は中身を見せない値を拒むので根の削除・変換の取り違えを捕まえない。
    #[test]
    fn opaque_values_remain_rooted_across_builtin_calls() {
        let mut bridge = BuiltinBridge::new();
        let mut io = TestIo {
            directory: PathBuf::from("."),
        };
        let value = done(bridge.call_decl(&make_opaque::DECL, &[], &mut io, None));
        for _ in 0..3 {
            assert!(matches!(
                done(bridge.call_decl(
                    &read_opaque::DECL,
                    std::slice::from_ref(&value),
                    &mut io,
                    None
                )),
                Value::Int(42)
            ));
        }
        assert_eq!(bridge.roots.len(), 1);
        bridge.heap.epoch(|ctx| bridge.roots.truncate(ctx, 0));
        bridge.heap.collect(&bridge.roots);
        assert!(bridge.heap.object_ids().is_empty());
    }
}
