//! 型付きの外部呼び出しの具体化（設計書 03-10「実行」）。
//! 文字列と Bytes はヒープから借り、リストの引数と戻り値は型付きの並びで所有する。

use super::runtime::CallLimits;
use super::{ExternalSpec, TypedKind, TypedShape, convert};
use crate::runtime::heap::{CheckedLen, NoGcCtx, Value};
use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop, list};
use std::borrow::Cow;
use wasmtime::{
    Store,
    component::{ComponentNamedList, Func, Lift, Lower},
};

#[derive(Clone, Copy)]
enum TypedArg<'a> {
    Int(i64),
    Float(f64),
    Str(&'a str),
    Bytes(&'a [u8]),
    Ints(&'a [i64]),
    Floats(&'a [f64]),
}

// Bytes は借用、List[Byte] は所有して、同じ &[u8] の具体化を使う。
// 数のリストも所有し、呼び出しまで型付きの並びを保つ（設計書 03-10「実行」）。
enum PreparedArg<'a> {
    Int(i64),
    Float(f64),
    Str(&'a str),
    Bytes(Cow<'a, [u8]>),
    Ints(Vec<i64>),
    Floats(Vec<f64>),
}
impl PreparedArg<'_> {
    fn borrowed(&self) -> TypedArg<'_> {
        match self {
            Self::Int(v) => TypedArg::Int(*v),
            Self::Float(v) => TypedArg::Float(*v),
            Self::Str(v) => TypedArg::Str(v),
            Self::Bytes(v) => TypedArg::Bytes(v),
            Self::Ints(v) => TypedArg::Ints(v),
            Self::Floats(v) => TypedArg::Floats(v),
        }
    }
}
/// 具体化の外で一度だけ言語の値へ変換する、所有された戻り値。
pub(super) enum TypedOut {
    Int(i64),
    Float(f64),
    Str(String),
    Bytes(Vec<u8>),
    Ints(Vec<i64>),
    Floats(Vec<f64>),
}
/// 変換・型の不整合の停止と、Wasm の呼び出しの失敗を分ける。
pub(super) enum CallError {
    Stop(Stop),
    Call(wasmtime::Error),
}
impl From<Stop> for CallError {
    fn from(stop: Stop) -> Self {
        Self::Stop(stop)
    }
}

fn call_leaf<P, R>(
    store: &mut Store<CallLimits>,
    func: &Func,
    params: P,
    out: fn(R) -> TypedOut,
) -> Result<TypedOut, CallError>
where
    P: ComponentNamedList + Lower,
    R: ComponentNamedList + Lift,
{
    let typed = func
        .typed::<P, R>(&*store)
        .map_err(|e| CallError::Stop(Stop::Internal(e.to_string())))?;
    typed
        .call(&mut *store, params)
        .map(out)
        .map_err(CallError::Call)
}

macro_rules! leaf {
    (($store:ident, $func:ident, $result:ident) [$($t:ty : $v:ident),*]) => {
        match $result {
            TypedKind::S64 => call_leaf::<($($t,)*), (i64,)>(
                $store, $func, ($($v,)*), |(v,)| TypedOut::Int(v)),
            TypedKind::F64 => call_leaf::<($($t,)*), (f64,)>(
                $store, $func, ($($v,)*), |(v,)| TypedOut::Float(v)),
            TypedKind::String => call_leaf::<($($t,)*), (String,)>(
                $store, $func, ($($v,)*), |(v,)| TypedOut::Str(v)),
            TypedKind::Bytes | TypedKind::ListU8 => call_leaf::<($($t,)*), (Vec<u8>,)>(
                $store, $func, ($($v,)*), |(v,)| TypedOut::Bytes(v)),
            TypedKind::ListS64 => call_leaf::<($($t,)*), (Vec<i64>,)>(
                $store, $func, ($($v,)*), |(v,)| TypedOut::Ints(v)),
            TypedKind::ListF64 => call_leaf::<($($t,)*), (Vec<f64>,)>(
                $store, $func, ($($v,)*), |(v,)| TypedOut::Floats(v)),
        }
    };
}
macro_rules! dispatch {
    ($cx:tt [$($t:ty : $v:ident),*]) => { leaf!($cx [$($t : $v),*]) };
    ($cx:tt [$($t:ty : $v:ident),*] $a:ident $($rest:ident)*) => {
        match $a {
            TypedArg::Int(x) => dispatch!($cx [$($t : $v,)* i64 : x] $($rest)*),
            TypedArg::Float(x) => dispatch!($cx [$($t : $v,)* f64 : x] $($rest)*),
            TypedArg::Str(x) => dispatch!($cx [$($t : $v,)* &str : x] $($rest)*),
            TypedArg::Bytes(x) => dispatch!($cx [$($t : $v,)* &[u8] : x] $($rest)*),
            TypedArg::Ints(x) => dispatch!($cx [$($t : $v,)* &[i64] : x] $($rest)*),
            TypedArg::Floats(x) => dispatch!($cx [$($t : $v,)* &[f64] : x] $($rest)*),
        }
    };
}
// 3 引数では数のリストを具体化せず、型の組による実行ファイルの増大を抑える
// （設計書 03-10「実行」）。
macro_rules! dispatch_three {
    ($cx:tt [$($t:ty : $v:ident),*]) => { leaf!($cx [$($t : $v),*]) };
    ($cx:tt [$($t:ty : $v:ident),*] $a:ident $($rest:ident)*) => {
        match $a {
            TypedArg::Int(x) => dispatch_three!($cx [$($t : $v,)* i64 : x] $($rest)*),
            TypedArg::Float(x) => dispatch_three!($cx [$($t : $v,)* f64 : x] $($rest)*),
            TypedArg::Str(x) => dispatch_three!($cx [$($t : $v,)* &str : x] $($rest)*),
            TypedArg::Bytes(x) => dispatch_three!($cx [$($t : $v,)* &[u8] : x] $($rest)*),
            TypedArg::Ints(_) | TypedArg::Floats(_) => Err(convert::invalid().into()),
        }
    };
}

/// インスタンス化より先に変換と予算の検査を済ませた引数。
pub(super) struct PreparedArgs<'a>(Vec<PreparedArg<'a>>, pub u64);

/// 借用または型付きの並びを準備し、全引数のバイト数の合計を検査する。
pub(super) fn prepare<'a, 'e>(
    ctx: &'a NoGcCtx<'e>,
    spec: &ExternalSpec,
    shape: &TypedShape,
    args: &[Value<'e>],
    transfer: u64,
) -> Result<PreparedArgs<'a>, Stop> {
    if shape.params.len() != args.len() {
        return Err(convert::invalid());
    }
    let mut total = 0_u64;
    let mut params = Vec::with_capacity(args.len());
    for (kind, value) in shape.params.iter().zip(args.iter().copied()) {
        let size = match kind {
            TypedKind::S64 | TypedKind::F64 => 0,
            TypedKind::String => {
                let s = ctx.str(value).ok_or_else(convert::invalid)?;
                convert::check_size(spec, s.len(), SizeUnit::Bytes, MAX_STRING_BYTES)?;
                u64::try_from(s.len()).map_err(|_| convert::invalid())?
            }
            TypedKind::Bytes => {
                let bytes = ctx.bytes(value).ok_or_else(convert::invalid)?;
                convert::check_size(spec, bytes.len(), SizeUnit::Bytes, MAX_STRING_BYTES)?;
                u64::try_from(bytes.len()).map_err(|_| convert::invalid())?
            }
            TypedKind::ListU8 | TypedKind::ListS64 | TypedKind::ListF64 => {
                let length = list::len(ctx, value)?;
                let width = match kind {
                    TypedKind::ListU8 => size_of::<u8>(),
                    TypedKind::ListS64 => size_of::<i64>(),
                    TypedKind::ListF64 => size_of::<f64>(),
                    TypedKind::S64 | TypedKind::F64 | TypedKind::String | TypedKind::Bytes => {
                        return Err(convert::invalid());
                    }
                };
                let width = u64::try_from(width).map_err(|_| convert::invalid())?;
                u64::from(length).saturating_mul(width)
            }
        };
        total = total.saturating_add(size);
        if total > transfer {
            return Err(Stop::Resource(ResourceError::ExternalTransfer {
                function: spec.function.clone(),
                component: spec.component.display.clone(),
                limit: transfer,
            }));
        }
        // 予算を超えるリストは、型付きの並びを確保する前に拒否する。
        let arg = match kind {
            TypedKind::S64 => PreparedArg::Int(value.as_int().ok_or_else(convert::invalid)?),
            TypedKind::F64 => PreparedArg::Float(value.as_float().ok_or_else(convert::invalid)?),
            TypedKind::String => PreparedArg::Str(ctx.str(value).ok_or_else(convert::invalid)?),
            TypedKind::Bytes => PreparedArg::Bytes(Cow::Borrowed(
                ctx.bytes(value).ok_or_else(convert::invalid)?,
            )),
            TypedKind::ListU8 => {
                PreparedArg::Bytes(Cow::Owned(collect_list(ctx, value, Value::as_byte)?))
            }
            TypedKind::ListS64 => PreparedArg::Ints(collect_list(ctx, value, Value::as_int)?),
            TypedKind::ListF64 => PreparedArg::Floats(collect_list(ctx, value, Value::as_float)?),
        };
        params.push(arg);
    }
    Ok(PreparedArgs(params, total))
}

// 動的な値を要素ごとに作らず、カーソルから型付きの並びへ直接詰める。
// 明示の走査によりリストの長さで Rust のスタックを増やさない（設計書 03-10「実行」）。
fn collect_list<'e, T>(
    ctx: &NoGcCtx<'e>,
    value: Value<'e>,
    element: fn(Value<'e>) -> Option<T>,
) -> Result<Vec<T>, Stop> {
    let length = usize::try_from(list::len(ctx, value)?).map_err(|_| convert::invalid())?;
    let mut items = Vec::with_capacity(length);
    let mut cursor = list::cursor(ctx, value)?;
    while let Some(item) = cursor.next(ctx)? {
        items.push(element(item).ok_or_else(convert::invalid)?);
    }
    if items.len() != length {
        return Err(convert::invalid());
    }
    Ok(items)
}

/// 検査済みの引数から借りた値で型付きの呼び出しを行う。
pub(super) fn call(
    store: &mut Store<CallLimits>,
    func: &Func,
    shape: &TypedShape,
    params: &PreparedArgs<'_>,
) -> Result<TypedOut, CallError> {
    let result = shape.result;
    // 引数は 6^0 + 6^1 + 6^2 + 4^3 = 107 通り、戻り値は 6 通りなので
    // マクロは計 642 通りを具体化する。Bytes と List[Byte] は共有する（設計書 03-10「実行」）。
    match params.0.as_slice() {
        [] => dispatch!((store, func, result) []),
        [a] => {
            let a = a.borrowed();
            dispatch!((store, func, result) [] a)
        }
        [a, b] => {
            let (a, b) = (a.borrowed(), b.borrowed());
            dispatch!((store, func, result) [] a b)
        }
        [a, b, c] => {
            let (a, b, c) = (a.borrowed(), b.borrowed(), c.borrowed());
            dispatch_three!((store, func, result) [] a b c)
        }
        _ => Err(convert::invalid().into()),
    }
}

/// 戻り値の大きさと UTF-8 を確かめ、回収しない区間に値を作る。
pub(super) fn into_value<'e>(
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    result: TypedKind,
    out: TypedOut,
) -> Result<Value<'e>, Stop> {
    match out {
        TypedOut::Int(v) => Ok(Value::Int(v)),
        TypedOut::Float(v) => Ok(Value::Float(v)),
        TypedOut::Str(s) => {
            convert::check_size(spec, s.len(), SizeUnit::Bytes, MAX_STRING_BYTES)?;
            ctx.alloc_str_utf8(s.as_bytes(), "external result")?
                .ok_or_else(convert::invalid)
        }
        TypedOut::Bytes(bytes) => {
            if result == TypedKind::ListU8 {
                return into_list(ctx, spec, bytes, Value::Byte);
            }
            convert::check_size(spec, bytes.len(), SizeUnit::Bytes, MAX_STRING_BYTES)?;
            let len = CheckedLen::bytes(
                u64::try_from(bytes.len()).map_err(|_| convert::invalid())?,
                "external result",
            )?;
            ctx.alloc_bytes_with(len, |dst| dst.copy_from_slice(&bytes))
        }
        TypedOut::Ints(items) => into_list(ctx, spec, items, Value::Int),
        TypedOut::Floats(items) => into_list(ctx, spec, items, Value::Float),
    }
}

// 要素数を先に検査し、型付きの戻り値から葉へ直接変換して中間の Vec<Value> を省く
// （設計書 02-09「外部の関数の実行」）。
fn into_list<'e, T>(
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    items: Vec<T>,
    value: fn(T) -> Value<'e>,
) -> Result<Value<'e>, Stop> {
    convert::check_size(spec, items.len(), SizeUnit::Elements, MAX_LIST_LEN)?;
    let length = u64::try_from(items.len()).map_err(|_| convert::invalid())?;
    list::from_iter_exact(ctx, length, items.into_iter().map(value), "external result")
}

impl TypedOut {
    pub(super) fn transfer(&self) -> u64 {
        match self {
            Self::Int(_) | Self::Float(_) => 0,
            Self::Str(s) => u64::try_from(s.len()).unwrap_or(u64::MAX),
            Self::Bytes(bytes) => u64::try_from(bytes.len()).unwrap_or(u64::MAX),
            Self::Ints(items) => u64::try_from(items.len())
                .unwrap_or(u64::MAX)
                .saturating_mul(u64::try_from(size_of::<i64>()).unwrap_or(u64::MAX)),
            Self::Floats(items) => u64::try_from(items.len())
                .unwrap_or(u64::MAX)
                .saturating_mul(u64::try_from(size_of::<f64>()).unwrap_or(u64::MAX)),
        }
    }
}
