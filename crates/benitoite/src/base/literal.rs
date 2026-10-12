//! 型検査・テストの実行器・Trait.showString／Trait.showCharacter の組み込みの関数が共有する値の表記と、リテラルのエスケープ。
//! 設計書 02-10「文言の言語」、06-04「結果の報告」、03-06「標準の型クラス（初回リリース版）」、01-01「文字列リテラル」「文字リテラル」。

/// `Show.show` の形の記号と、値の続きを省いたときや型が分からないときの表記。
pub(crate) mod text {
    /// 書き出しの上限で値の続きを省いたことを示す末尾の記号（設計書 06-04「結果の報告」）。
    pub const ELLIPSIS: &str = "…";
    pub const TRUE: &str = "true";
    pub const FALSE: &str = "false";
    pub const UNIT: &str = "()";
    pub const LIST_OPEN: &str = "[";
    pub const LIST_CLOSE: &str = "]";
    pub const MAP_OPEN: &str = "Map.fromList([";
    pub const SET_OPEN: &str = "Set.fromList([";
    pub const BYTES_OPEN: &str = "Bytes.fromList([";
    pub const FROM_LIST_CLOSE: &str = "])";
    pub const PAIR_OPEN: &str = "Pair(";
    pub const ARGS_OPEN: &str = "(";
    pub const ARGS_CLOSE: &str = ")";
    pub const SEPARATOR: &str = ", ";
    pub const FIELD_SEPARATOR: &str = ": ";
    pub const QUALIFIER: &str = ".";
    /// 型が分からない構成子の値。`{tag}` は構成子のタグ
    pub const UNKNOWN_CONSTRUCTOR: &str = "<constructor #{tag}>";
}

/// 文字列と文字を、`Trait.showString`・`Trait.showCharacter` と同じリテラルの形にする。
pub(crate) fn quoted(chars: impl Iterator<Item = char>, quote: char) -> String {
    let mut out = String::new();
    out.push(quote);
    for c in chars {
        escape_into(&mut out, c, quote);
    }
    out.push(quote);
    out
}

/// リテラルに含める一文字を逃がす。上限付きの書き出しでも同じ規則を使う。
pub(crate) fn escape_into(out: &mut String, c: char, quote: char) {
    match c {
        '\n' => out.push_str("\\n"),
        '\r' => out.push_str("\\r"),
        '\t' => out.push_str("\\t"),
        '\\' => out.push_str("\\\\"),
        '$' if quote == '"' => out.push_str("\\$"),
        c if c == quote => {
            out.push('\\');
            out.push(c);
        }
        '\u{0}'..='\u{1f}'
        | '\u{7f}'
        | '\u{61c}'
        | '\u{200e}'
        | '\u{200f}'
        | '\u{202a}'..='\u{202e}'
        | '\u{2066}'..='\u{2069}'
        | '\u{feff}' => out.push_str(&format!("\\u{{{:x}}}", u32::from(c))),
        c => out.push(c),
    }
}
