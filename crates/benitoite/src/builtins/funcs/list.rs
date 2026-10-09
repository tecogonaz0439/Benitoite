//! リストの操作とパターンの内部の項目（設計書 03-06「List」、実装プラン 10-12「リスト・マップ・集合」）。
//! 仮の本体は、後の作業が本体と Rust の引数型だけを書き換える。
//! 名前・権限・引数の数・DECLS の中の位置は変えない（実装プラン 10-12「まだ書かない項目の仮の本体」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::CheckedLen;
use crate::runtime::heap::Value;

builtin! {
    /// `List.length` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.length",
    pure fn length(ctx, xs: Value<'e>) -> i64 {
        Ok(i64::from(crate::runtime::list::len(&ctx, xs)?))
    }
}

builtin! {
    /// `List.isEmpty` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.isEmpty",
    pure fn is_empty(ctx, xs: Value<'e>) -> bool {
        Ok(crate::runtime::list::len(&ctx, xs)? == 0)
    }
}

builtin! {
    /// `List.head` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.head",
    pure fn head(ctx, xs: Value<'e>) -> Value<'e> {
        super::option(&ctx, crate::runtime::list::get(&ctx, xs, 0)?)
    }
}

builtin! {
    /// `List.tail` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.tail",
    pure fn tail(ctx, xs: Value<'e>) -> Value<'e> {
        super::option(&ctx, crate::runtime::list::tail(&ctx, xs)?)
    }
}

builtin! {
    /// `List.get` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.get",
    pure fn get(ctx, xs: Value<'e>, i: i64) -> Value<'e> {
        let value = match u32::try_from(i) {
            Ok(i) => crate::runtime::list::get(&ctx, xs, i)?,
            Err(_) => {
                crate::runtime::list::len(&ctx, xs)?;
                None
            }
        };
        super::option(&ctx, value)
    }
}

builtin! {
    /// `List.prepend` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.prepend",
    pure fn prepend(ctx, xs: Value<'e>, x: Value<'e>) -> Value<'e> {
        crate::runtime::list::prepend(&ctx, xs, x, "List.prepend")
    }
}

builtin! {
    /// `List.append` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.append",
    pure fn append(ctx, xs: Value<'e>, x: Value<'e>) -> Value<'e> {
        crate::runtime::list::append(&ctx, xs, x, "List.append")
    }
}

builtin! {
    /// `List.concatenate` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.concatenate",
    pure fn concatenate(ctx, xs: Value<'e>, ys: Value<'e>) -> Value<'e> {
        crate::runtime::list::concat(&ctx, xs, ys, "List.concatenate")
    }
}

builtin! {
    /// `List.reverse` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.reverse",
    pure fn reverse(ctx, xs: Value<'e>) -> Value<'e> {
        let mut items = crate::runtime::list::to_vec(&ctx, xs)?;
        items.reverse();
        crate::runtime::list::from_values(&ctx, &items, "List.reverse")
    }
}

builtin! {
    /// `List.take` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.take",
    pure fn take(ctx, xs: Value<'e>, n: i64) -> Value<'e> {
        let len = crate::runtime::list::len(&ctx, xs)?;
        let n = u32::try_from(n.max(0)).unwrap_or(u32::MAX).min(len);
        crate::runtime::list::slice(&ctx, xs, 0, n)
    }
}

builtin! {
    /// `List.drop` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.drop",
    pure fn drop(ctx, xs: Value<'e>, n: i64) -> Value<'e> {
        let len = crate::runtime::list::len(&ctx, xs)?;
        let n = u32::try_from(n.max(0)).unwrap_or(u32::MAX).min(len);
        crate::runtime::list::slice(&ctx, xs, n, len)
    }
}

builtin! {
    /// `List.range` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.range",
    pure fn range(ctx, start: i64, end: i64) -> Value<'e> {
        if end <= start {
            return Ok(Value::EmptyList);
        }
        // i128 で差を計算し、端点の差が i64 を超えるときも上限超過として報告する（設計書 02-09）。
        let size = i128::from(end)
            .checked_sub(i128::from(start))
            .and_then(|n| u64::try_from(n).ok())
            .ok_or_else(|| Stop::Internal("range difference does not fit u64".into()))?;
        CheckedLen::elements(size, "List.range")?;
        let items = (start..end).map(Value::Int).collect::<Vec<_>>();
        crate::runtime::list::from_values(&ctx, &items, "List.range")
    }
}

builtin! {
    /// `List.contains` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.contains",
    pure fn contains(ctx, xs: Value<'e>, x: Value<'e>) -> bool {
        for value in crate::runtime::list::to_vec(&ctx, xs)? {
            if crate::runtime::equal::values_equal(&ctx, value, x)? {
                return Ok(true);
            }
        }
        Ok(false)
    }
}

builtin! {
    /// `List.sort` の本体（実装プラン 10-12「項目の一覧」）。
    name = "List.sort",
    pure fn sort(ctx, xs: Value<'e>) -> Value<'e> {
        let mut items = crate::runtime::list::to_vec(&ctx, xs)?;
        // 比較器に不正な種類を渡さず、一要素だけの場合も型を確かめる
        // （設計書 03-06「List」、実装プラン 00-02「失敗を panic で表さない」）。
        if let Some(first) = items.first().copied() {
            for item in &items {
                compare(&ctx, first, *item)?;
            }
        }
        let mut failure = None;
        items.sort_by(|a, b| match compare(&ctx, *a, *b) {
            Ok(order) => order,
            Err(error) => {
                failure = Some(error);
                std::cmp::Ordering::Equal
            }
        });
        if let Some(error) = failure {
            return Err(error);
        }
        crate::runtime::list::from_values(&ctx, &items, "List.sort")
    }
}

builtin! {
    /// `%List.length` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%List.length",
    pure fn pattern_length(ctx, xs: Value<'e>) -> i64 {
        length(ctx, xs)
    }
}

builtin! {
    /// `%List.getFront` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%List.getFront",
    pure fn get_front(ctx, xs: Value<'e>, i: i64) -> Value<'e> {
        let i =
            u32::try_from(i).map_err(|_| Stop::Internal("invalid list pattern front index".into()))?;
        crate::runtime::list::get(&ctx, xs, i)?
            .ok_or_else(|| Stop::Internal("list pattern front index out of bounds".into()))
    }
}

builtin! {
    /// `%List.getBack` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%List.getBack",
    pure fn get_back(ctx, xs: Value<'e>, i: i64) -> Value<'e> {
        let n = crate::runtime::list::len(&ctx, xs)?;
        let i = u32::try_from(i)
            .ok()
            .and_then(|i| n.checked_sub(i))
            .and_then(|i| i.checked_sub(1))
            .ok_or_else(|| Stop::Internal("invalid list pattern back index".into()))?;
        crate::runtime::list::get(&ctx, xs, i)?
            .ok_or_else(|| Stop::Internal("list pattern back index out of bounds".into()))
    }
}

builtin! {
    /// `%List.slice` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%List.slice",
    pure fn slice(ctx, xs: Value<'e>, front: i64, back: i64) -> Value<'e> {
        let n = crate::runtime::list::len(&ctx, xs)?;
        let (Ok(front), Ok(back)) = (u32::try_from(front), u32::try_from(back)) else {
            return Err(Stop::Internal("invalid list pattern slice bounds".into()));
        };
        let end = n
            .checked_sub(back)
            .filter(|end| *end >= front)
            .ok_or_else(|| Stop::Internal("list pattern slice out of bounds".into()))?;
        crate::runtime::list::slice(&ctx, xs, front, end)
    }
}

fn compare<'e>(
    ctx: &crate::runtime::heap::ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
) -> Result<std::cmp::Ordering, Stop> {
    use std::cmp::Ordering;
    match (a, b) {
        (Value::Int(a), Value::Int(b)) => Ok(a.cmp(&b)),
        (Value::Byte(a), Value::Byte(b)) => Ok(a.cmp(&b)),
        (Value::Char(a), Value::Char(b)) => Ok(a.cmp(&b)),
        (Value::Float(a), Value::Float(b)) => Ok(match (a.is_nan(), b.is_nan()) {
            (true, true) => Ordering::Equal,
            (true, false) => Ordering::Greater,
            (false, true) => Ordering::Less,
            (false, false) => a
                .partial_cmp(&b)
                .ok_or_else(|| Stop::Internal("finite float comparison failed".into()))?,
        }),
        (Value::Obj(_), Value::Obj(_)) => {
            if let (Some(a), Some(b)) = (ctx.str(a), ctx.str(b)) {
                return Ok(a.cmp(b));
            }
            if let (Some(a), Some(b)) = (ctx.decimal(a), ctx.decimal(b)) {
                return Ok(a.cmp_num(b));
            }
            Err(Stop::Internal("List.sort expected ordered values".into()))
        }
        _ => Err(Stop::Internal(
            "List.sort expected matching ordered values".into(),
        )),
    }
}
/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    length::DECL,
    is_empty::DECL,
    head::DECL,
    tail::DECL,
    get::DECL,
    prepend::DECL,
    append::DECL,
    concatenate::DECL,
    reverse::DECL,
    take::DECL,
    drop::DECL,
    range::DECL,
    contains::DECL,
    sort::DECL,
    pattern_length::DECL,
    get_front::DECL,
    get_back::DECL,
    slice::DECL,
];
