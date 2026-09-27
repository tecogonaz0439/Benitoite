//! 組み込みの名前・実装・型の表（設計書 02-04「prelude」、10-10「組み込みの表の関数」）。

use crate::types::{EffectSet, ParamConstraint, Scheme, Ty, TyCon, TySet, TypeParamInfo};

use super::{BuiltinId, BuiltinKind, BuiltinSpec, PreludeModule};

/// 識別子に対応する実装と名前を返す。
///
/// 名前解決・型検査・実行が同じ項目を参照するため、表の各分岐は識別子ごとに固定する。
pub fn spec(id: BuiltinId) -> BuiltinSpec {
    macro_rules! pure {
        ($id:ident, $module:expr, $name:literal, $implementation:path, $arity:literal) => {
            BuiltinSpec {
                id: BuiltinId::$id,
                module: $module,
                name: $name,
                kind: BuiltinKind::Pure($implementation),
                prelude_only: false,
                arity: $arity,
            }
        };
        ($id:ident, $module:expr, $name:literal, $implementation:path, $arity:literal, prelude_only) => {
            BuiltinSpec {
                id: BuiltinId::$id,
                module: $module,
                name: $name,
                kind: BuiltinKind::Pure($implementation),
                prelude_only: true,
                arity: $arity,
            }
        };
    }
    macro_rules! io {
        ($id:ident, $module:expr, $name:literal, $operation:expr, $arity:literal) => {
            BuiltinSpec {
                id: BuiltinId::$id,
                module: $module,
                name: $name,
                kind: BuiltinKind::Io($operation),
                prelude_only: false,
                arity: $arity,
            }
        };
    }

    use crate::runtime::io::IoOp;
    use BuiltinId::*;
    use PreludeModule::*;

    match id {
        AddInt => pure!(AddInt, None, "+", super::ops::add_int, 2),
        SubInt => pure!(SubInt, None, "-", super::ops::sub_int, 2),
        MulInt => pure!(MulInt, None, "*", super::ops::mul_int, 2),
        DivInt => pure!(DivInt, None, "/", super::ops::div_int, 2),
        RemInt => pure!(RemInt, None, "%", super::ops::rem_int, 2),
        NegInt => pure!(NegInt, None, "-", super::ops::neg_int, 1),
        AddFloat => pure!(AddFloat, None, "+", super::ops::add_float, 2),
        SubFloat => pure!(SubFloat, None, "-", super::ops::sub_float, 2),
        MulFloat => pure!(MulFloat, None, "*", super::ops::mul_float, 2),
        DivFloat => pure!(DivFloat, None, "/", super::ops::div_float, 2),
        NegFloat => pure!(NegFloat, None, "-", super::ops::neg_float, 1),
        ConcatString => pure!(ConcatString, None, "+", super::ops::concat_string, 2),
        LtInt => pure!(LtInt, None, "<", super::ops::lt_int, 2),
        LeInt => pure!(LeInt, None, "<=", super::ops::le_int, 2),
        GtInt => pure!(GtInt, None, ">", super::ops::gt_int, 2),
        GeInt => pure!(GeInt, None, ">=", super::ops::ge_int, 2),
        LtFloat => pure!(LtFloat, None, "<", super::ops::lt_float, 2),
        LeFloat => pure!(LeFloat, None, "<=", super::ops::le_float, 2),
        GtFloat => pure!(GtFloat, None, ">", super::ops::gt_float, 2),
        GeFloat => pure!(GeFloat, None, ">=", super::ops::ge_float, 2),
        LtString => pure!(LtString, None, "<", super::ops::lt_string, 2),
        LeString => pure!(LeString, None, "<=", super::ops::le_string, 2),
        GtString => pure!(GtString, None, ">", super::ops::gt_string, 2),
        GeString => pure!(GeString, None, ">=", super::ops::ge_string, 2),
        LtChar => pure!(LtChar, None, "<", super::ops::lt_char, 2),
        LeChar => pure!(LeChar, None, "<=", super::ops::le_char, 2),
        GtChar => pure!(GtChar, None, ">", super::ops::gt_char, 2),
        GeChar => pure!(GeChar, None, ">=", super::ops::ge_char, 2),
        Eq => pure!(Eq, None, "==", super::ops::eq, 2),
        Ne => pure!(Ne, None, "!=", super::ops::ne, 2),
        IntToString => pure!(IntToString, Some(Int), "toString", super::int::to_string, 1),
        IntParse => pure!(IntParse, Some(Int), "parse", super::int::parse, 1),
        IntToFloat => pure!(IntToFloat, Some(Int), "toFloat", super::int::to_float, 1),
        IntFloorDiv => pure!(IntFloorDiv, Some(Int), "floorDiv", super::int::floor_div, 2),
        IntMod => pure!(IntMod, Some(Int), "mod", super::int::modulo, 2),
        IntAbs => pure!(IntAbs, Some(Int), "abs", super::int::abs, 1),
        IntMin => pure!(IntMin, Some(Int), "min", super::int::min, 2),
        IntMax => pure!(IntMax, Some(Int), "max", super::int::max, 2),
        FloatToString => pure!(
            FloatToString,
            Some(Float),
            "toString",
            super::float::to_string,
            1
        ),
        FloatParse => pure!(FloatParse, Some(Float), "parse", super::float::parse, 1),
        FloatTruncate => pure!(
            FloatTruncate,
            Some(Float),
            "truncate",
            super::float::truncate,
            1
        ),
        FloatIsNaN => pure!(FloatIsNaN, Some(Float), "isNaN", super::float::is_nan, 1),
        FloatAbs => pure!(FloatAbs, Some(Float), "abs", super::float::abs, 1),
        FloatFloor => pure!(FloatFloor, Some(Float), "floor", super::float::floor, 1),
        FloatCeil => pure!(FloatCeil, Some(Float), "ceil", super::float::ceil, 1),
        FloatRound => pure!(FloatRound, Some(Float), "round", super::float::round, 1),
        FloatSqrt => pure!(FloatSqrt, Some(Float), "sqrt", super::float::sqrt, 1),
        CharToInt => pure!(CharToInt, Some(Char), "toInt", super::character::to_int, 1),
        CharFromInt => pure!(
            CharFromInt,
            Some(Char),
            "fromInt",
            super::character::from_int,
            1
        ),
        CharToString => pure!(
            CharToString,
            Some(Char),
            "toString",
            super::character::to_string,
            1
        ),
        CharIsAsciiDigit => pure!(
            CharIsAsciiDigit,
            Some(Char),
            "isAsciiDigit",
            super::character::is_ascii_digit,
            1
        ),
        CharIsAsciiWhitespace => pure!(
            CharIsAsciiWhitespace,
            Some(Char),
            "isAsciiWhitespace",
            super::character::is_ascii_whitespace,
            1
        ),
        StringByteLength => pure!(
            StringByteLength,
            Some(String),
            "byteLength",
            super::string::byte_length,
            1
        ),
        StringByteSlice => pure!(
            StringByteSlice,
            Some(String),
            "byteSlice",
            super::string::byte_slice,
            3
        ),
        StringCharCount => pure!(
            StringCharCount,
            Some(String),
            "charCount",
            super::string::char_count,
            1
        ),
        StringCharAt => pure!(
            StringCharAt,
            Some(String),
            "charAt",
            super::string::char_at,
            2
        ),
        StringCharSlice => pure!(
            StringCharSlice,
            Some(String),
            "charSlice",
            super::string::char_slice,
            3
        ),
        StringIsEmpty => pure!(
            StringIsEmpty,
            Some(String),
            "isEmpty",
            super::string::is_empty,
            1
        ),
        StringContains => pure!(
            StringContains,
            Some(String),
            "contains",
            super::string::contains,
            2
        ),
        StringStartsWith => pure!(
            StringStartsWith,
            Some(String),
            "startsWith",
            super::string::starts_with,
            2
        ),
        StringEndsWith => pure!(
            StringEndsWith,
            Some(String),
            "endsWith",
            super::string::ends_with,
            2
        ),
        StringByteIndexOf => pure!(
            StringByteIndexOf,
            Some(String),
            "byteIndexOf",
            super::string::byte_index_of,
            2
        ),
        StringSplit => pure!(StringSplit, Some(String), "split", super::string::split, 2),
        StringLines => pure!(StringLines, Some(String), "lines", super::string::lines, 1),
        StringJoin => pure!(StringJoin, Some(String), "join", super::string::join, 2),
        StringTrim => pure!(StringTrim, Some(String), "trim", super::string::trim, 1),
        StringReplace => pure!(
            StringReplace,
            Some(String),
            "replace",
            super::string::replace,
            3
        ),
        StringRepeat => pure!(
            StringRepeat,
            Some(String),
            "repeat",
            super::string::repeat,
            2
        ),
        StringChars => pure!(StringChars, Some(String), "chars", super::string::chars, 1),
        StringFromChars => pure!(
            StringFromChars,
            Some(String),
            "fromChars",
            super::string::from_chars,
            1
        ),
        ListLength => pure!(ListLength, Some(List), "length", super::list::length, 1),
        ListIsEmpty => pure!(ListIsEmpty, Some(List), "isEmpty", super::list::is_empty, 1),
        ListHead => pure!(ListHead, Some(List), "head", super::list::head, 1),
        ListTail => pure!(ListTail, Some(List), "tail", super::list::tail, 1),
        ListGet => pure!(ListGet, Some(List), "get", super::list::get, 2),
        ListPrepend => pure!(ListPrepend, Some(List), "prepend", super::list::prepend, 2),
        ListAppend => pure!(ListAppend, Some(List), "append", super::list::append, 2),
        ListConcat => pure!(ListConcat, Some(List), "concat", super::list::concat, 2),
        ListReverse => pure!(ListReverse, Some(List), "reverse", super::list::reverse, 1),
        ListTake => pure!(ListTake, Some(List), "take", super::list::take, 2),
        ListDrop => pure!(ListDrop, Some(List), "drop", super::list::drop, 2),
        ListRange => pure!(ListRange, Some(List), "range", super::list::range, 2),
        ListContains => pure!(
            ListContains,
            Some(List),
            "contains",
            super::list::contains,
            2
        ),
        ListSort => pure!(ListSort, Some(List), "sort", super::list::sort, 1),
        ListDropFirst => pure!(
            ListDropFirst,
            Some(List),
            "dropFirst",
            super::list::drop_first,
            1,
            prelude_only
        ),
        IoErrorMessage => pure!(
            IoErrorMessage,
            Some(IoError),
            "message",
            super::io_error::message,
            1
        ),
        ConsolePrint => io!(ConsolePrint, Some(Console), "print", IoOp::Print, 1),
        ConsolePrintln => io!(ConsolePrintln, Some(Console), "println", IoOp::Println, 1),
        ConsoleEprintln => io!(
            ConsoleEprintln,
            Some(Console),
            "eprintln",
            IoOp::Eprintln,
            1
        ),
        FileReadText => io!(FileReadText, Some(File), "readText", IoOp::ReadText, 1),
        ProcessArgs => io!(ProcessArgs, Some(Process), "args", IoOp::Args, 0),
    }
}

/// 組み込み関数の多相型と制約を返す。
///
/// 演算子の閉じた型集合は型検査器が扱うため、ここには Eq と Ne の等値制約だけを記録する。
pub fn scheme(id: BuiltinId) -> Scheme {
    use BuiltinId::*;

    match id {
        AddInt | SubInt | MulInt | DivInt | RemInt => {
            monomorphic(vec![Ty::int(), Ty::int()], Ty::int())
        }
        NegInt => monomorphic(vec![Ty::int()], Ty::int()),
        AddFloat | SubFloat | MulFloat | DivFloat => {
            monomorphic(vec![Ty::float(), Ty::float()], Ty::float())
        }
        NegFloat => monomorphic(vec![Ty::float()], Ty::float()),
        ConcatString => monomorphic(vec![Ty::string(), Ty::string()], Ty::string()),
        LtInt | LeInt | GtInt | GeInt => monomorphic(vec![Ty::int(), Ty::int()], Ty::bool()),
        LtFloat | LeFloat | GtFloat | GeFloat => {
            monomorphic(vec![Ty::float(), Ty::float()], Ty::bool())
        }
        LtString | LeString | GtString | GeString => {
            monomorphic(vec![Ty::string(), Ty::string()], Ty::bool())
        }
        LtChar | LeChar | GtChar | GeChar => monomorphic(vec![Ty::char(), Ty::char()], Ty::bool()),
        Eq | Ne => generic_t(
            ParamConstraint::Equality,
            vec![Ty::Param(0), Ty::Param(0)],
            Ty::bool(),
        ),
        IntToString => monomorphic(vec![Ty::int()], Ty::string()),
        IntParse => monomorphic(vec![Ty::string()], Ty::option(Ty::int())),
        IntToFloat => monomorphic(vec![Ty::int()], Ty::float()),
        IntFloorDiv | IntMod => monomorphic(vec![Ty::int(), Ty::int()], Ty::int()),
        IntAbs => monomorphic(vec![Ty::int()], Ty::int()),
        IntMin | IntMax => monomorphic(vec![Ty::int(), Ty::int()], Ty::int()),
        FloatToString => monomorphic(vec![Ty::float()], Ty::string()),
        FloatParse => monomorphic(vec![Ty::string()], Ty::option(Ty::float())),
        FloatTruncate => monomorphic(vec![Ty::float()], Ty::option(Ty::int())),
        FloatIsNaN => monomorphic(vec![Ty::float()], Ty::bool()),
        FloatAbs | FloatFloor | FloatCeil | FloatRound | FloatSqrt => {
            monomorphic(vec![Ty::float()], Ty::float())
        }
        CharToInt => monomorphic(vec![Ty::char()], Ty::int()),
        CharFromInt => monomorphic(vec![Ty::int()], Ty::option(Ty::char())),
        CharToString => monomorphic(vec![Ty::char()], Ty::string()),
        CharIsAsciiDigit | CharIsAsciiWhitespace => monomorphic(vec![Ty::char()], Ty::bool()),
        StringByteLength | StringCharCount => monomorphic(vec![Ty::string()], Ty::int()),
        StringByteSlice | StringCharSlice => monomorphic(
            vec![Ty::string(), Ty::int(), Ty::int()],
            Ty::option(Ty::string()),
        ),
        StringCharAt => monomorphic(vec![Ty::string(), Ty::int()], Ty::option(Ty::char())),
        StringIsEmpty => monomorphic(vec![Ty::string()], Ty::bool()),
        StringContains | StringStartsWith | StringEndsWith => {
            monomorphic(vec![Ty::string(), Ty::string()], Ty::bool())
        }
        StringByteIndexOf => monomorphic(vec![Ty::string(), Ty::string()], Ty::option(Ty::int())),
        StringSplit => monomorphic(vec![Ty::string(), Ty::string()], Ty::list(Ty::string())),
        StringLines => monomorphic(vec![Ty::string()], Ty::list(Ty::string())),
        StringJoin => monomorphic(vec![Ty::list(Ty::string()), Ty::string()], Ty::string()),
        StringTrim => monomorphic(vec![Ty::string()], Ty::string()),
        StringReplace => monomorphic(vec![Ty::string(), Ty::string(), Ty::string()], Ty::string()),
        StringRepeat => monomorphic(vec![Ty::string(), Ty::int()], Ty::string()),
        StringChars => monomorphic(vec![Ty::string()], Ty::list(Ty::char())),
        StringFromChars => monomorphic(vec![Ty::list(Ty::char())], Ty::string()),
        ListLength => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0))],
            Ty::int(),
        ),
        ListIsEmpty => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0))],
            Ty::bool(),
        ),
        ListHead => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0))],
            Ty::option(Ty::Param(0)),
        ),
        ListTail => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0))],
            Ty::option(Ty::list(Ty::Param(0))),
        ),
        ListGet => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0)), Ty::int()],
            Ty::option(Ty::Param(0)),
        ),
        ListPrepend | ListAppend => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0)), Ty::Param(0)],
            Ty::list(Ty::Param(0)),
        ),
        ListConcat => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0)), Ty::list(Ty::Param(0))],
            Ty::list(Ty::Param(0)),
        ),
        ListReverse => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0))],
            Ty::list(Ty::Param(0)),
        ),
        ListTake | ListDrop => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0)), Ty::int()],
            Ty::list(Ty::Param(0)),
        ),
        ListRange => monomorphic(vec![Ty::int(), Ty::int()], Ty::list(Ty::int())),
        ListContains => generic_t(
            ParamConstraint::Equality,
            vec![Ty::list(Ty::Param(0)), Ty::Param(0)],
            Ty::bool(),
        ),
        ListSort => generic_t(
            ParamConstraint::OneOf(TySet::ORD),
            vec![Ty::list(Ty::Param(0))],
            Ty::list(Ty::Param(0)),
        ),
        ListDropFirst => generic_t(
            ParamConstraint::None,
            vec![Ty::list(Ty::Param(0))],
            Ty::list(Ty::Param(0)),
        ),
        IoErrorMessage => monomorphic(vec![Ty::con(TyCon::IoError)], Ty::string()),
        ConsolePrint | ConsolePrintln | ConsoleEprintln => {
            io_scheme(vec![Ty::string()], Ty::unit())
        }
        FileReadText => io_scheme(
            vec![Ty::string()],
            Ty::result(Ty::string(), Ty::con(TyCon::IoError)),
        ),
        ProcessArgs => io_scheme(Vec::new(), Ty::list(Ty::string())),
    }
}

/// モジュール名と関数名が一致する組み込みを返す。
///
/// 演算子はモジュールを持たず、モジュールの検索から除外される。
pub fn lookup(module: PreludeModule, name: &str) -> Option<BuiltinId> {
    BuiltinId::ALL.into_iter().find(|id| {
        let item = spec(*id);
        item.module == Some(module) && item.name == name
    })
}

fn monomorphic(params: Vec<Ty>, ret: Ty) -> Scheme {
    make_scheme(Vec::new(), params, ret, EffectSet::empty())
}

fn generic_t(constraint: ParamConstraint, params: Vec<Ty>, ret: Ty) -> Scheme {
    make_scheme(
        vec![TypeParamInfo {
            name: String::from("T"),
            constraint,
        }],
        params,
        ret,
        EffectSet::empty(),
    )
}

fn io_scheme(params: Vec<Ty>, ret: Ty) -> Scheme {
    make_scheme(Vec::new(), params, ret, EffectSet::io())
}

fn make_scheme(
    type_params: Vec<TypeParamInfo>,
    params: Vec<Ty>,
    ret: Ty,
    effects: EffectSet,
) -> Scheme {
    Scheme {
        type_params,
        effect_params: Vec::new(),
        params,
        ret,
        effects,
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // 組み込みの表が型・名前解決・実装の対応を保つことを公開関数で確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::builtins::{BuiltinId, PreludeModule};
    use crate::types::{EffectSet, ParamConstraint, Scheme, Ty, TyCon, TySet, TypeParamInfo};

    use super::{lookup, scheme, spec};

    #[test]
    fn all_builtin_entries_have_consistent_arity_and_names() {
        for id in BuiltinId::ALL {
            let item = spec(id);
            assert_eq!(item.id, id);
            assert_eq!(usize::from(item.arity), scheme(id).params.len());
            assert_eq!(item.module.is_none(), id.is_operator());
            if !id.is_operator() {
                let Some(module) = item.module else {
                    panic!("non-operator builtin has no module");
                };
                assert_eq!(lookup(module, item.name), Some(id));
            }
        }
    }

    #[test]
    fn schemes_preserve_polymorphic_constraints_and_io_effects() {
        let contains = scheme(BuiltinId::ListContains);
        assert_eq!(contains.type_params.len(), 1);
        assert_eq!(
            contains.type_params.first().map(|param| param.constraint),
            Some(ParamConstraint::Equality)
        );

        let sort = scheme(BuiltinId::ListSort);
        assert_eq!(sort.type_params.len(), 1);
        assert_eq!(
            sort.type_params.first().map(|param| param.constraint),
            Some(ParamConstraint::OneOf(TySet::ORD))
        );

        assert_eq!(
            scheme(BuiltinId::Eq),
            Scheme {
                type_params: vec![TypeParamInfo {
                    name: String::from("T"),
                    constraint: ParamConstraint::Equality,
                }],
                effect_params: Vec::new(),
                params: vec![Ty::Param(0), Ty::Param(0)],
                ret: Ty::bool(),
                effects: EffectSet::empty(),
            }
        );

        let read_text = scheme(BuiltinId::FileReadText);
        assert_eq!(
            read_text.ret,
            Ty::result(Ty::string(), Ty::con(TyCon::IoError))
        );
        assert_eq!(read_text.effects, EffectSet::io());
    }

    #[test]
    fn lookup_keeps_prelude_source_functions_out_of_the_builtin_table() {
        assert_eq!(lookup(PreludeModule::List, "map"), None);
        assert_eq!(
            lookup(PreludeModule::List, "dropFirst"),
            Some(BuiltinId::ListDropFirst)
        );
        assert_eq!(lookup(PreludeModule::String, "length"), None);
        assert!(
            BuiltinId::ALL
                .into_iter()
                .all(|id| { spec(id).prelude_only == (id == BuiltinId::ListDropFirst) })
        );
    }
}
