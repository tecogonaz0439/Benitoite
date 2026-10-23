//! 型別の書式化の内部頭（設計書 02-06「書式化の内部頭」）。
//! 数字列と幅は base::format に委ね、ここでは固定引数の取り出しと確保を行う。

use crate::base::format::{FormatError, FormatSpec, FormatValue};
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::{CheckedLen, Value};

fn internal(error: FormatError) -> Stop {
    Stop::Internal(format!("invalid internal format arguments: {error:?}"))
}

macro_rules! formatter {
    ($module:ident, $name:literal, $ty:ty, $ctx:ident, $value:ident, $converted:expr) => {
        mod $module {
            use super::*;
            builtin! {
                /// 検査済みの七定数を受け、予算と全長を検査して書式化した文字列を作る。
                name = $name,
                pure fn format($ctx, ($value: $ty, kind: i64, align: i64, sign: i64, alternate: bool, zero: bool, width: i64, precision: i64)) -> Value<'e> {
                    let spec = FormatSpec::decode(kind, align, sign, alternate, zero, width, precision).map_err(internal)?;
                    let result = spec.prepare($converted).map_err(internal)?;
                    CheckedLen::bytes(result.byte_len(), $name)?;
                    // 各片を借りたまま全長を検査し、共通のヒープ計上の後で一度だけ写す。
                    $ctx.alloc_str_parts(&result.parts().map_err(internal)?, $name)
                }
            }
        }
    };
}

formatter!(
    integer,
    "%Format.Integer",
    i64,
    ctx,
    value,
    FormatValue::Signed(value)
);
formatter!(
    integer8,
    "%Format.Integer8",
    i8,
    ctx,
    value,
    FormatValue::Signed(i64::from(value))
);
formatter!(
    integer16,
    "%Format.Integer16",
    i16,
    ctx,
    value,
    FormatValue::Signed(i64::from(value))
);
formatter!(
    integer32,
    "%Format.Integer32",
    i32,
    ctx,
    value,
    FormatValue::Signed(i64::from(value))
);
formatter!(
    byte,
    "%Format.Byte",
    u8,
    ctx,
    value,
    FormatValue::Unsigned(u64::from(value))
);
formatter!(
    unsigned16,
    "%Format.UnsignedInteger16",
    u16,
    ctx,
    value,
    FormatValue::Unsigned(u64::from(value))
);
formatter!(
    unsigned32,
    "%Format.UnsignedInteger32",
    u32,
    ctx,
    value,
    FormatValue::Unsigned(u64::from(value))
);
formatter!(
    unsigned64,
    "%Format.UnsignedInteger64",
    u64,
    ctx,
    value,
    FormatValue::Unsigned(value)
);
formatter!(
    float,
    "%Format.Float",
    f64,
    ctx,
    value,
    FormatValue::Float(value)
);
formatter!(
    float32,
    "%Format.Float32",
    f32,
    ctx,
    value,
    FormatValue::Float32(value)
);
formatter!(
    decimal,
    "%Format.Decimal",
    Value<'e>,
    ctx,
    value,
    FormatValue::Decimal(super::super::decimal::operand(&ctx, value)?)
);
formatter!(
    string,
    "%Format.String",
    &'c str,
    ctx,
    value,
    FormatValue::String(value)
);
formatter!(
    character,
    "%Format.Character",
    char,
    ctx,
    value,
    FormatValue::Character(value)
);
formatter!(
    boolean,
    "%Format.Boolean",
    bool,
    ctx,
    value,
    FormatValue::Boolean(value)
);

/// 既存の番号を保ち、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    integer::format::DECL,
    integer8::format::DECL,
    integer16::format::DECL,
    integer32::format::DECL,
    byte::format::DECL,
    unsigned16::format::DECL,
    unsigned32::format::DECL,
    unsigned64::format::DECL,
    float::format::DECL,
    float32::format::DECL,
    decimal::format::DECL,
    string::format::DECL,
    character::format::DECL,
    boolean::format::DECL,
];
