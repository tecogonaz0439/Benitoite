//! 見つからない名前に示す旧名と別名（設計書 02-04「誤りと修正案」）。
//! 名前解決の前に拒むキーワードの旧名・別名にも同じ案内を出すため、構文解析器からもこの表を引く。

/// 改名の版と、別名の置き換えを付けられるかを区別する。
#[derive(Clone, Copy)]
pub(crate) enum RenameKind {
    Renamed,
    Alias { replace: bool },
}

impl RenameKind {
    /// 診断の表の修正案の鍵。
    pub(crate) fn key(self) -> &'static str {
        match self {
            Self::Renamed => "renamed",
            Self::Alias { .. } => "alias",
        }
    }

    /// 引数の数と順を変えずに名前だけを置き換えられるか。
    pub(crate) fn replace(self) -> bool {
        match self {
            Self::Renamed => true,
            Self::Alias { replace } => replace,
        }
    }
}

use RenameKind::{Alias, Renamed};

/// 本来のモジュール名、書いた名前、正しい名前、種類の順で持つ。
/// モジュール自体の改名は名前空間の根 `Benitoite` に属する。
pub(super) const RENAMES: &[(&str, &str, &str, RenameKind)] = &[
    ("Benitoite", "Int", "Integer", Renamed),
    ("Benitoite", "Bool", "Boolean", Renamed),
    ("Benitoite", "Char", "Character", Renamed),
    ("Benitoite", "IoError", "IOError", Renamed),
    ("Benitoite.IO.Console", "println", "writeLine", Renamed),
    ("Benitoite.IO.Console", "print", "write", Renamed),
    (
        "Benitoite.IO.Console",
        "eprintln",
        "writeErrorLine",
        Renamed,
    ),
    ("Benitoite.IO.Process", "args", "arguments", Renamed),
    ("Benitoite.String", "charCount", "characterCount", Renamed),
    ("Benitoite.String", "charAt", "characterAt", Renamed),
    ("Benitoite.String", "charSlice", "characterSlice", Renamed),
    ("Benitoite.String", "chars", "characters", Renamed),
    ("Benitoite.String", "fromChars", "fromCharacters", Renamed),
    ("Benitoite.Float", "sqrt", "squareRoot", Renamed),
    ("Benitoite.Float", "abs", "absolute", Renamed),
    ("Benitoite.Float", "ceil", "ceiling", Renamed),
    ("Benitoite.List", "concat", "concatenate", Renamed),
    ("Benitoite.Result", "mapErr", "mapError", Renamed),
    ("Benitoite.Result", "isErr", "isError", Renamed),
    ("Benitoite.Character", "toInt", "toInteger", Renamed),
    ("Benitoite.Character", "fromInt", "fromInteger", Renamed),
    (
        "Benitoite.Character",
        "isAsciiDigit",
        "isASCIIDigit",
        Renamed,
    ),
    (
        "Benitoite.Character",
        "isAsciiWhitespace",
        "isASCIIWhitespace",
        Renamed,
    ),
    ("Benitoite.Integer", "abs", "absolute", Renamed),
    ("Benitoite.Integer", "min", "minimum", Renamed),
    ("Benitoite.Integer", "max", "maximum", Renamed),
    ("Benitoite.Integer", "floorDiv", "floorDivide", Renamed),
    ("Benitoite.Integer", "mod", "floorModulo", Renamed),
    ("Benitoite.Map", "insert", "set", Alias { replace: true }),
    ("Benitoite.Map", "put", "set", Alias { replace: true }),
    ("Benitoite.Map", "lookup", "get", Alias { replace: true }),
    ("Benitoite.Map", "find", "get", Alias { replace: true }),
    ("Benitoite.Map", "has", "contains", Alias { replace: true }),
    (
        "Benitoite.Map",
        "containsKey",
        "contains",
        Alias { replace: true },
    ),
    ("Benitoite.Map", "length", "size", Alias { replace: true }),
    ("Benitoite.Map", "count", "size", Alias { replace: true }),
    ("Benitoite.List", "size", "length", Alias { replace: true }),
    ("Benitoite.List", "len", "length", Alias { replace: true }),
    (
        "Benitoite.List",
        "count",
        "length",
        Alias { replace: false },
    ),
    ("Benitoite.List", "push", "append", Alias { replace: true }),
    ("Benitoite.List", "first", "head", Alias { replace: true }),
    ("Benitoite.List", "nth", "get", Alias { replace: true }),
    ("Benitoite.List", "at", "get", Alias { replace: true }),
    ("Benitoite.List", "reduce", "fold", Alias { replace: false }),
    ("Benitoite.List", "each", "forEach", Alias { replace: true }),
    (
        "Benitoite.List",
        "includes",
        "contains",
        Alias { replace: true },
    ),
    ("Benitoite.List", "has", "contains", Alias { replace: true }),
    ("Benitoite.Set", "insert", "add", Alias { replace: true }),
    (
        "Benitoite.String",
        "toUpper",
        "toUppercase",
        Alias { replace: true },
    ),
    (
        "Benitoite.String",
        "upper",
        "toUppercase",
        Alias { replace: true },
    ),
    ("Benitoite.String", "strip", "trim", Alias { replace: true }),
    (
        "Benitoite.Option",
        "flatMap",
        "andThen",
        Alias { replace: true },
    ),
    (
        "Benitoite.Option",
        "bind",
        "andThen",
        Alias { replace: true },
    ),
    (
        "Benitoite.Option",
        "getOrElse",
        "unwrapOr",
        Alias { replace: true },
    ),
    (
        "Benitoite.Result",
        "toOption",
        "ok",
        Alias { replace: true },
    ),
];

/// 本来のモジュールの名前と見つからない段の名前で表を引く。
pub(crate) fn find(module: &str, name: &str) -> Option<(&'static str, RenameKind)> {
    RENAMES
        .iter()
        .find_map(|(m, old, new, kind)| (*m == module && *old == name).then_some((*new, *kind)))
}
