//! 乱数の生成器と値への変換（設計書 03-07「Random」、ADR 0172）。

use crate::builtins::iface::IoReply;
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CtorTag, FieldsKind, OpaqueData, Value, ValueCtx};
use crate::runtime::{RuntimeError, Stop, list};

#[derive(Clone, Copy, Debug)]
struct Generator([u64; 4]);
impl OpaqueData for Generator {}

/// 純粋な生成器と実行開始時の種の設定は、同じ展開手順を使う（設計書 03-07「Random」）。
pub(crate) fn seeded_state(mut seed: u64) -> [u64; 4] {
    std::array::from_fn(|_| {
        seed = seed.wrapping_add(0x9e3779b97f4a7c15);
        let mut value = seed;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
        value ^ (value >> 31)
    })
}

impl Generator {
    fn next(&mut self) -> u64 {
        let [a, b, c, d] = self.0;
        let value = b.wrapping_mul(5).rotate_left(7).wrapping_mul(9);
        self.0 = [
            a ^ d ^ b,
            b ^ c ^ a,
            c ^ a ^ b.wrapping_shl(17),
            (d ^ b).rotate_left(45),
        ];
        value
    }
}

fn generator<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Generator, Stop> {
    ctx.opaque::<Generator>(value)
        .copied()
        .ok_or_else(|| Stop::Internal("expected Random.Generator".into()))
}

fn width(low: i64, high: i64, function: &'static str, argument: u16) -> Result<u64, Stop> {
    if high <= low {
        return Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
            function,
            argument,
        }));
    }
    Ok(high.abs_diff(low))
}

fn offset(n: u64, mut next: impl FnMut() -> u64) -> Result<u64, Stop> {
    // 2^64 を表現せず、仕様の上端未満という判定を等価な形で書く（設計書 03-07「Random」）。
    let remainder = n
        .wrapping_neg()
        .checked_rem(n)
        .ok_or_else(|| Stop::Internal("zero random range width".into()))?;
    loop {
        let x = next();
        if x <= u64::MAX.saturating_sub(remainder) {
            return x
                .checked_rem(n)
                .ok_or_else(|| Stop::Internal("zero random range width".into()));
        }
    }
}

fn ranged(low: i64, n: u64, next: impl FnMut() -> u64) -> Result<i64, Stop> {
    low.checked_add_unsigned(offset(n, next)?)
        .ok_or_else(|| Stop::Internal("random integer outside checked range".into()))
}

fn fraction(x: u64) -> f64 {
    // 右シフト後は 53 ビット以内であり、f64 が整数を正確に表せる（設計書 03-07「Random」）。
    (x >> 11) as f64 * (1.0 / 9_007_199_254_740_992.0)
}

fn shuffled<'e>(
    ctx: &ValueCtx<'e>,
    xs: Value<'e>,
    mut next: impl FnMut() -> u64,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut items = list::to_vec(ctx, xs)?;
    for i in (1..items.len()).rev() {
        let n = u64::try_from(i.saturating_add(1))
            .map_err(|_| Stop::Internal("random list length does not fit u64".into()))?;
        let j = usize::try_from(offset(n, &mut next)?)
            .map_err(|_| Stop::Internal("random list index does not fit usize".into()))?;
        items.swap(i, j);
    }
    list::from_values(ctx, &items, function)
}

fn pair<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, next: Generator) -> Result<Value<'e>, Stop> {
    ctx.alloc_fields(
        FieldsKind::Ctor,
        tags::PAIR,
        &[value, ctx.alloc_opaque(next)],
    )
}

builtin! {
    /// `Benitoite.IO.Random.integer` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Random.integer",
    io fn integer(ctx, low: i64, high: i64) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let n = width(low, high, integer::DECL.name, 1)?;
        Ok(IoReply::Done(Value::Int(ranged(low, n, || ctx.services().random_u64())?)))
    }
}

builtin! {
    /// `Benitoite.IO.Random.float` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Random.float",
    io fn float(ctx) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        Ok(IoReply::Done(Value::Float(fraction(ctx.services().random_u64()))))
    }
}

builtin! {
    /// `Benitoite.IO.Random.boolean` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Random.boolean",
    io fn boolean(ctx) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        Ok(IoReply::Done(Value::Bool(ctx.services().random_u64() >> 63 != 0)))
    }
}

builtin! {
    /// `Benitoite.IO.Random.shuffle` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Random.shuffle",
    io fn shuffle(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let values = ctx.values();
        Ok(IoReply::Done(shuffled(values, arg0, || ctx.services().random_u64(), shuffle::DECL.name)?))
    }
}

builtin! {
    /// `Benitoite.IO.Random.choose` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Random.choose",
    io fn choose(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let n = list::len(&ctx, arg0)?;
        if n == 0 {
            return Ok(IoReply::Done(Value::Tag(CtorTag(tags::OPTION_NONE))));
        }
        let index = u32::try_from(offset(u64::from(n), || ctx.services().random_u64())?)
            .map_err(|_| Stop::Internal("random choice index does not fit u32".into()))?;
        let value = list::get(&ctx, arg0, index)?.ok_or_else(|| Stop::Internal("random choice outside list".into()))?;
        Ok(IoReply::Done(ctx.alloc_fields(FieldsKind::Ctor, tags::OPTION_SOME, &[value])?))
    }
}

builtin! {
    /// `IO.Random.fromSeed` の本体（実装プラン 10-15「項目の一覧」）。
    name = "IO.Random.fromSeed",
    pure fn from_seed(ctx, seed: i64) -> Value<'e> {
        Ok(ctx.alloc_opaque(Generator(seeded_state(u64::from_ne_bytes(seed.to_ne_bytes())))))
    }
}

builtin! {
    /// `IO.Random.nextInteger` の本体（実装プラン 10-15「項目の一覧」）。
    name = "IO.Random.nextInteger",
    pure fn next_integer(ctx, arg0: Value<'e>, low: i64, high: i64) -> Value<'e> {
        let n = width(low, high, next_integer::DECL.name, 2)?;
        let mut next = generator(&ctx, arg0)?;
        let value = Value::Int(ranged(low, n, || next.next())?);
        pair(&ctx, value, next)
    }
}

builtin! {
    /// `IO.Random.nextFloat` の本体（実装プラン 10-15「項目の一覧」）。
    name = "IO.Random.nextFloat",
    pure fn next_float(ctx, arg0: Value<'e>) -> Value<'e> {
        let mut next = generator(&ctx, arg0)?;
        let value = Value::Float(fraction(next.next()));
        pair(&ctx, value, next)
    }
}

builtin! {
    /// `IO.Random.shuffleWith` の本体（実装プラン 10-15「項目の一覧」）。
    name = "IO.Random.shuffleWith",
    pure fn shuffle_with(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let mut next = generator(&ctx, arg0)?;
        let value = shuffled(&ctx, arg1, || next.next(), shuffle_with::DECL.name)?;
        pair(&ctx, value, next)
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    integer::DECL,
    float::DECL,
    boolean::DECL,
    shuffle::DECL,
    choose::DECL,
    from_seed::DECL,
    next_integer::DECL,
    next_float::DECL,
    shuffle_with::DECL,
];

#[cfg(test)]
mod tests;
