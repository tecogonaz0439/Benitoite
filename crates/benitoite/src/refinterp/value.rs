//! 参照インタプリタ独自の値（設計書 02-08「参照インタプリタ」、ADR 0268・0276）。
//! VM の値と対象を含まず、共有する並びは Rc で持つ。リストは連結セルでなく平坦な並びとする。
//! セル・Lazy・継続はストアの番号で表し、各項目に状態を置く。辞書は実装と制約の並び、
//! 上位への射影を独自の値で持つ。中身を見せない値は変換の境目の表の番号だけを持つ。

use std::fmt;
use std::rc::Rc;

use crate::base::{BindingId, Decimal, NodeId};
use crate::builtins::BuiltinId;
use crate::ir::core_ir::{BodyId, BuiltinInfo, VarId};
use crate::runtime::Stop;
use crate::runtime::heap::ResourceId;

/// 評価の側で使う値。可視性は refinterp の中に限る。
#[derive(Clone)]
pub(super) enum Value {
    Decimal(Decimal),
    Location(usize),
    Resource(ResourceId),
    Opaque(u32),
    Dict { code: DictCode, args: Rc<Values> },
    Map(Rc<Values>),
    Set(Rc<Values>),
    Int(i64),
    Float(f64),
    Byte(u8),
    Bool(bool),
    Char(char),
    Unit,
    Str(Rc<str>),
    Bytes(Rc<[u8]>),
    Ctor { tag: u32, args: Rc<Values> },
    List(Rc<Values>),
    Func(Rc<Closure>),
    IoError { kind: u32, reason: Rc<str> },
}

/// 共有する子の並び。最後の参照の解放で深い構造へ再帰しないよう Drop を持つ。
pub(super) struct Values {
    pub(super) items: Vec<Value>,
}

/// 関数の本体の識別。F14 はこの識別からコア IR の本体を引く。
#[derive(Clone, Copy, Debug)]
pub(super) enum FunctionCode {
    Body(BodyId),
    TopFn(BindingId),
    Builtin(BuiltinId, BuiltinInfo),
    Op(BindingId),
}

/// 関数の本体と捕捉した変数。評価の状態や継続の枠は F14 が別に持つ。
pub(super) struct Closure {
    pub(super) code: FunctionCode,
    pub(super) captures: Vec<(VarId, Value)>,
    pub(super) impl_dicts: Rc<Values>,
}

#[derive(Clone, Copy, Debug)]
pub(super) enum DictCode {
    Impl(NodeId),
    Super(u32),
}

impl Value {
    /// 構成子のタグと引数を独立した値として持つ。
    pub(super) fn ctor(tag: u32, args: Vec<Value>) -> Self {
        Self::Ctor {
            tag,
            args: Rc::new(Values { items: args }),
        }
    }

    /// 並びの順のリスト。上限の検査は、評価時とヒープへの変換時に行う。
    pub(super) fn list(items: Vec<Value>) -> Self {
        Self::List(Rc::new(Values { items }))
    }
}

// 診断用の Debug も子を辿らず、深い値のテストが失敗したときにスタックを使い果たさない。
impl fmt::Debug for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Decimal(d) => f.debug_tuple("Decimal").field(d).finish(),
            Self::Location(n) => f.debug_tuple("Location").field(n).finish(),
            Self::Resource(n) => f.debug_tuple("Resource").field(n).finish(),
            Self::Opaque(n) => f.debug_tuple("Opaque").field(n).finish(),
            Self::Dict { code, .. } => f.debug_tuple("Dict").field(code).finish(),
            Self::Map(xs) => f.debug_tuple("Map").field(&xs.items.len()).finish(),
            Self::Set(xs) => f.debug_tuple("Set").field(&xs.items.len()).finish(),
            Self::Int(n) => f.debug_tuple("Int").field(n).finish(),
            Self::Float(x) => f.debug_tuple("Float").field(x).finish(),
            Self::Byte(b) => f.debug_tuple("Byte").field(b).finish(),
            Self::Bool(b) => f.debug_tuple("Bool").field(b).finish(),
            Self::Char(c) => f.debug_tuple("Char").field(c).finish(),
            Self::Unit => f.write_str("Unit"),
            Self::Str(s) => f.debug_tuple("Str").field(s).finish(),
            Self::Bytes(b) => f.debug_tuple("Bytes").field(b).finish(),
            Self::Ctor { tag, args } => f
                .debug_struct("Ctor")
                .field("tag", tag)
                .field("arity", &args.items.len())
                .finish(),
            Self::List(xs) => f
                .debug_struct("List")
                .field("len", &xs.items.len())
                .finish(),
            Self::Func(func) => f.debug_tuple("Func").field(&func.code).finish(),
            Self::IoError { kind, reason } => f
                .debug_struct("IoError")
                .field("kind", kind)
                .field("reason", reason)
                .finish(),
        }
    }
}

/// 言語の構造の等しさ。Float は IEEE 754、関数と IOError は非等値の型として扱う
/// （設計書 01-06「等値の型」）。VM の runtime::equal は使わない。
pub(super) fn values_equal(a: &Value, b: &Value) -> Result<bool, Stop> {
    let mut pending = vec![(a, b)];
    while let Some((a, b)) = pending.pop() {
        // 同じ Rc でも子を調べる。NaN は自分自身と等しくない。
        let equal = match (a, b) {
            (Value::Decimal(a), Value::Decimal(b)) => a.cmp_num(*b).is_eq(),
            (Value::Int(a), Value::Int(b)) => a == b,
            (Value::Float(a), Value::Float(b)) => a == b,
            (Value::Byte(a), Value::Byte(b)) => a == b,
            (Value::Bool(a), Value::Bool(b)) => a == b,
            (Value::Char(a), Value::Char(b)) => a == b,
            (Value::Unit, Value::Unit) => true,
            (Value::Str(a), Value::Str(b)) => a == b,
            (Value::Bytes(a), Value::Bytes(b)) => a == b,
            (
                Value::Ctor {
                    tag: a_tag,
                    args: a,
                },
                Value::Ctor {
                    tag: b_tag,
                    args: b,
                },
            ) => {
                if a_tag != b_tag || a.items.len() != b.items.len() {
                    false
                } else {
                    pending.extend(a.items.iter().zip(&b.items).rev());
                    true
                }
            }
            (Value::List(a), Value::List(b))
            | (Value::Map(a), Value::Map(b))
            | (Value::Set(a), Value::Set(b)) => {
                if a.items.len() != b.items.len() {
                    false
                } else {
                    pending.extend(a.items.iter().zip(&b.items).rev());
                    true
                }
            }
            (
                Value::Decimal(_)
                | Value::Location(_)
                | Value::Resource(_)
                | Value::Opaque(_)
                | Value::Dict { .. }
                | Value::Map(_)
                | Value::Set(_)
                | Value::Int(_)
                | Value::Float(_)
                | Value::Byte(_)
                | Value::Bool(_)
                | Value::Char(_)
                | Value::Unit
                | Value::Str(_)
                | Value::Bytes(_)
                | Value::Ctor { .. }
                | Value::List(_)
                | Value::Func(_)
                | Value::IoError { .. },
                _,
            ) => {
                return Err(Stop::Internal(
                    "incompatible or non-equality reference values".into(),
                ));
            }
        };
        if !equal {
            return Ok(false);
        }
    }
    Ok(true)
}

// 最後の Rc だけを開き、子を先に取り出す。共有している子は参照の数を減らすだけである。
// 同じ子を複数持つ場合も、一つずつ try_unwrap するので最後の参照を取りこぼさない。
// 開いた対象の Drop は空の並びを受け取るため、値の深さに比例する再帰を起こさない
// （実装プラン 00-02「再帰の深さ」）。
fn release(mut pending: Vec<Value>) {
    while let Some(value) = pending.pop() {
        match value {
            Value::Ctor { args, .. }
            | Value::List(args)
            | Value::Map(args)
            | Value::Set(args)
            | Value::Dict { args, .. } => {
                if let Ok(mut values) = Rc::try_unwrap(args) {
                    pending.append(&mut values.items);
                }
            }
            Value::Func(func) => {
                if let Ok(mut closure) = Rc::try_unwrap(func) {
                    pending.extend(closure.captures.drain(..).map(|(_, value)| value));
                    if let Ok(mut values) = Rc::try_unwrap(std::mem::replace(
                        &mut closure.impl_dicts,
                        Rc::new(Values { items: vec![] }),
                    )) {
                        pending.append(&mut values.items);
                    }
                }
            }
            Value::Decimal(_)
            | Value::Location(_)
            | Value::Resource(_)
            | Value::Opaque(_)
            | Value::Int(_)
            | Value::Float(_)
            | Value::Byte(_)
            | Value::Bool(_)
            | Value::Char(_)
            | Value::Unit
            | Value::Str(_)
            | Value::Bytes(_)
            | Value::IoError { .. } => {}
        }
    }
}

impl Drop for Values {
    fn drop(&mut self) {
        release(std::mem::take(&mut self.items));
    }
}

impl Drop for Closure {
    fn drop(&mut self) {
        release(self.captures.drain(..).map(|(_, value)| value).collect());
    }
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
    use super::*;

    // 作成時の関門: 独自の値の等値規則を、仕様から決めた期待値で守る。
    // VM のテストは独自の比較を呼ばず、Rc の同一性で NaN を省く退行も検出できない。
    // R10 の指示に従い非公開の値の境界で検査し、本番の可視性と差し込み口は増やさない。
    #[test]
    fn equality_obeys_scalar_and_structural_rules() {
        for (a, b, expected) in [
            (Value::Int(-1), Value::Int(-1), true),
            (Value::Int(-1), Value::Int(1), false),
            (Value::Float(0.0), Value::Float(-0.0), true),
            (Value::Float(f64::NAN), Value::Float(f64::NAN), false),
            (Value::Byte(255), Value::Byte(0), false),
            (Value::Bool(true), Value::Bool(false), false),
            (Value::Char('あ'), Value::Char('あ'), true),
            (Value::Unit, Value::Unit, true),
            (
                Value::Str(Rc::from("é")),
                Value::Str(Rc::from("e\u{301}")),
                false,
            ),
            (
                Value::Bytes(Rc::from([0, 255].as_slice())),
                Value::Bytes(Rc::from([0, 254].as_slice())),
                false,
            ),
            (Value::ctor(0, vec![]), Value::ctor(1, vec![]), false),
            (
                Value::ctor(0, vec![]),
                Value::ctor(1, vec![Value::Int(1)]),
                false,
            ),
            (
                Value::ctor(0, vec![Value::Int(1)]),
                Value::ctor(0, vec![]),
                false,
            ),
            (
                Value::ctor(0, vec![Value::Int(1)]),
                Value::ctor(0, vec![Value::Int(2)]),
                false,
            ),
            (
                Value::list(vec![Value::Int(1), Value::Int(2)]),
                Value::list(vec![Value::Int(2), Value::Int(1)]),
                false,
            ),
            (Value::list(vec![]), Value::list(vec![Value::Unit]), false),
        ] {
            assert_eq!(values_equal(&a, &b).unwrap(), expected, "{a:?}, {b:?}");
            assert_eq!(values_equal(&b, &a).unwrap(), expected);
        }
        let nan = Value::ctor(0, vec![Value::list(vec![Value::Float(f64::NAN)])]);
        assert!(!values_equal(&nan, &nan.clone()).unwrap());
        for invalid in [
            Value::Func(Rc::new(Closure {
                code: FunctionCode::Body(BodyId(0)),
                captures: vec![],
                impl_dicts: Rc::new(Values { items: vec![] }),
            })),
            Value::IoError {
                kind: 0,
                reason: Rc::from("missing"),
            },
        ] {
            assert!(matches!(
                values_equal(&invalid, &invalid),
                Err(Stop::Internal(_))
            ));
            let wrapped = Value::ctor(0, vec![Value::list(vec![invalid])]);
            assert!(matches!(
                values_equal(&wrapped, &wrapped),
                Err(Stop::Internal(_))
            ));
        }
        assert!(matches!(
            values_equal(&Value::Int(1), &Value::Bool(true)),
            Err(Stop::Internal(_))
        ));
    }

    // 作成時の関門: 最後の共有の参照から解放するときも、捕捉した値を再帰で落とさない。
    // 往復のテストは関数を変換しないため、その Drop の連鎖の退行を捕まえない。
    #[test]
    fn shared_closure_captures_release_deep_values_iteratively() {
        let mut value = Value::ctor(0, vec![]);
        let Value::Ctor { args, .. } = &value else {
            panic!("constructor")
        };
        let leaf = Rc::downgrade(args);
        for _ in 0..1_000_000 {
            value = Value::Func(Rc::new(Closure {
                code: FunctionCode::TopFn(BindingId(0)),
                captures: vec![(VarId(0), value)],
                impl_dicts: Rc::new(Values { items: vec![] }),
            }));
        }
        let kept = value.clone();
        drop(Value::list(vec![value.clone(), value]));
        assert!(leaf.upgrade().is_some());
        drop(kept);
        assert!(leaf.upgrade().is_none());
    }
}
