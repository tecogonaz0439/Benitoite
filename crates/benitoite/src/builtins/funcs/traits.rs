//! Show のリテラルの表記（設計書 03-06「標準の型クラス（初回リリース版）」、01-01「文字列リテラル」「文字リテラル」）。
//! 名前・権限・引数の数は標準ライブラリのソースの宣言と一致させる
//! （設計書 02-04「標準ライブラリのソースの持ち方」）。番号は表の中の位置で決まるので、DECLS の中の位置は変えない。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::MAX_STRING_BYTES;
use crate::runtime::ResourceError;
use crate::runtime::SizeUnit;
use crate::runtime::Stop;
use crate::runtime::heap::CheckedLen;
use crate::runtime::heap::StrBuf;
use crate::runtime::heap::Value;

builtin! {
    /// `Trait.showString` の本体。
    name = "Trait.showString",
    pure fn show_string(ctx, s: &'c str) -> Value<'e> {
        show(&ctx, s.chars(), '"', "Trait.showString")
    }
}

builtin! {
    /// `Trait.showCharacter` の本体。
    name = "Trait.showCharacter",
    pure fn show_character(ctx, c: char) -> Value<'e> {
        show(&ctx, std::iter::once(c), '\'', "Trait.showCharacter")
    }
}

fn escaped(c: char, quote: char) -> String {
    let mut out = String::new();
    crate::base::literal::escape_into(&mut out, c, quote);
    out
}

fn show<'e>(
    ctx: &crate::runtime::heap::ValueCtx<'e>,
    chars: impl Iterator<Item = char> + Clone,
    quote: char,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut size = 2u64;
    for c in chars.clone() {
        size = size
            .checked_add(super::count(escaped(c, quote).len())?)
            .ok_or(Stop::Resource(ResourceError::ValueTooLarge {
                function,
                size: u64::MAX,
                unit: SizeUnit::Bytes,
                limit: MAX_STRING_BYTES,
            }))?;
    }
    CheckedLen::bytes(size, function)?;
    let mut buf = StrBuf::new(function);
    buf.push_char(quote)?;
    for c in chars {
        buf.push_str(&escaped(c, quote))?;
    }
    buf.push_char(quote)?;
    ctx.alloc_str_buf(buf)
}
/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[show_string::DECL, show_character::DECL];
