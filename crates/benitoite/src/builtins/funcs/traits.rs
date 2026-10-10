//! Show のリテラルの表記（設計書 03-06「標準の型クラス（初回リリース版）」、01-01「文字列リテラル」「文字リテラル」）。
//! 仮の本体は、後の作業が本体と Rust の引数型だけを書き換える。
//! 名前・権限・引数の数・DECLS の中の位置は変えない（実装プラン 10-12「まだ書かない項目の仮の本体」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::MAX_STRING_BYTES;
use crate::runtime::ResourceError;
use crate::runtime::SizeUnit;
use crate::runtime::Stop;
use crate::runtime::heap::CheckedLen;
use crate::runtime::heap::StrBuf;
use crate::runtime::heap::Value;

builtin! {
    /// `Trait.showString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Trait.showString",
    pure fn show_string(ctx, s: &'c str) -> Value<'e> {
        show(&ctx, s.chars(), '"', "Trait.showString")
    }
}

builtin! {
    /// `Trait.showCharacter` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Trait.showCharacter",
    pure fn show_character(ctx, c: char) -> Value<'e> {
        show(&ctx, std::iter::once(c), '\'', "Trait.showCharacter")
    }
}

fn escaped(c: char, quote: char) -> String {
    match c {
        '\n' => "\\n".into(),
        '\r' => "\\r".into(),
        '\t' => "\\t".into(),
        '\\' => "\\\\".into(),
        '$' if quote == '"' => "\\$".into(),
        c if c == quote => format!("\\{c}"),
        '\u{0}'..='\u{1f}'
        | '\u{7f}'
        | '\u{61c}'
        | '\u{200e}'
        | '\u{200f}'
        | '\u{202a}'..='\u{202e}'
        | '\u{2066}'..='\u{2069}'
        | '\u{feff}' => format!("\\u{{{:x}}}", u32::from(c)),
        c => c.to_string(),
    }
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
/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[show_string::DECL, show_character::DECL];
