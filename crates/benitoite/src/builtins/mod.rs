//! 組み込みの表（設計書 02-04「prelude」、03-06）。
//! 実装: ops.rs（演算子）、int.rs、float.rs、character.rs、string.rs、list.rs、io_error.rs、table.rs（表）。

pub mod character;
pub mod float;
pub mod int;
pub mod io_error;
pub mod list;
pub mod ops;
pub mod string;
pub mod table;

use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::io::IoOp;
use crate::runtime::value::Value;

/// prelude のモジュール。型の名前を兼ねるもの（Int など）と、型を持たないもの（Console・File・Process）がある。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum PreludeModule {
    Int,
    Float,
    Char,
    String,
    List,
    Option,
    Result,
    IoError,
    Console,
    File,
    Process,
}

impl PreludeModule {
    pub const ALL: [PreludeModule; 11] = [
        PreludeModule::Int,
        PreludeModule::Float,
        PreludeModule::Char,
        PreludeModule::String,
        PreludeModule::List,
        PreludeModule::Option,
        PreludeModule::Result,
        PreludeModule::IoError,
        PreludeModule::Console,
        PreludeModule::File,
        PreludeModule::Process,
    ];

    pub fn name(self) -> &'static str {
        match self {
            PreludeModule::Int => "Int",
            PreludeModule::Float => "Float",
            PreludeModule::Char => "Char",
            PreludeModule::String => "String",
            PreludeModule::List => "List",
            PreludeModule::Option => "Option",
            PreludeModule::Result => "Result",
            PreludeModule::IoError => "IoError",
            PreludeModule::Console => "Console",
            PreludeModule::File => "File",
            PreludeModule::Process => "Process",
        }
    }
}

/// IO を行わない組み込みの関数の実装。引数の個数と種類は型検査で保証されているが、
/// 違うときは panic せずに `Stop::Internal` を返す。
pub type PureFn = fn(&mut Heap, &[Value]) -> Result<Value, Stop>;

/// 組み込みの関数の実装の種類。
#[derive(Clone, Copy, Debug)]
pub enum BuiltinKind {
    Pure(PureFn),
    Io(IoOp),
}

/// 組み込みの表の項目。
#[derive(Clone, Copy, Debug)]
pub struct BuiltinSpec {
    pub id: BuiltinId,
    /// 属するモジュール。演算子は `None`
    pub module: Option<PreludeModule>,
    /// 修飾しない名前（`map`）。演算子は記号（`+`）
    pub name: &'static str,
    pub kind: BuiltinKind,
    /// prelude のソースの中だけで使える（02-04「prelude」）
    pub prelude_only: bool,
    /// 引数の個数
    pub arity: u16,
}

/// 組み込みの関数の識別子。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum BuiltinId {
    AddInt,
    SubInt,
    MulInt,
    DivInt,
    RemInt,
    NegInt,
    AddFloat,
    SubFloat,
    MulFloat,
    DivFloat,
    NegFloat,
    ConcatString,
    LtInt,
    LeInt,
    GtInt,
    GeInt,
    LtFloat,
    LeFloat,
    GtFloat,
    GeFloat,
    LtString,
    LeString,
    GtString,
    GeString,
    LtChar,
    LeChar,
    GtChar,
    GeChar,
    Eq,
    Ne,
    IntToString,
    IntParse,
    IntToFloat,
    IntFloorDiv,
    IntMod,
    IntAbs,
    IntMin,
    IntMax,
    FloatToString,
    FloatParse,
    FloatTruncate,
    FloatIsNaN,
    FloatAbs,
    FloatFloor,
    FloatCeil,
    FloatRound,
    FloatSqrt,
    CharToInt,
    CharFromInt,
    CharToString,
    CharIsAsciiDigit,
    CharIsAsciiWhitespace,
    StringByteLength,
    StringByteSlice,
    StringCharCount,
    StringCharAt,
    StringCharSlice,
    StringIsEmpty,
    StringContains,
    StringStartsWith,
    StringEndsWith,
    StringByteIndexOf,
    StringSplit,
    StringLines,
    StringJoin,
    StringTrim,
    StringReplace,
    StringRepeat,
    StringChars,
    StringFromChars,
    ListLength,
    ListIsEmpty,
    ListHead,
    ListTail,
    ListGet,
    ListPrepend,
    ListAppend,
    ListConcat,
    ListReverse,
    ListTake,
    ListDrop,
    ListRange,
    ListContains,
    ListSort,
    ListDropFirst,
    IoErrorMessage,
    ConsolePrint,
    ConsolePrintln,
    ConsoleEprintln,
    FileReadText,
    ProcessArgs,
}

impl BuiltinId {
    /// すべての組み込みの関数（宣言の順）。
    pub const ALL: [BuiltinId; 91] = [
        BuiltinId::AddInt,
        BuiltinId::SubInt,
        BuiltinId::MulInt,
        BuiltinId::DivInt,
        BuiltinId::RemInt,
        BuiltinId::NegInt,
        BuiltinId::AddFloat,
        BuiltinId::SubFloat,
        BuiltinId::MulFloat,
        BuiltinId::DivFloat,
        BuiltinId::NegFloat,
        BuiltinId::ConcatString,
        BuiltinId::LtInt,
        BuiltinId::LeInt,
        BuiltinId::GtInt,
        BuiltinId::GeInt,
        BuiltinId::LtFloat,
        BuiltinId::LeFloat,
        BuiltinId::GtFloat,
        BuiltinId::GeFloat,
        BuiltinId::LtString,
        BuiltinId::LeString,
        BuiltinId::GtString,
        BuiltinId::GeString,
        BuiltinId::LtChar,
        BuiltinId::LeChar,
        BuiltinId::GtChar,
        BuiltinId::GeChar,
        BuiltinId::Eq,
        BuiltinId::Ne,
        BuiltinId::IntToString,
        BuiltinId::IntParse,
        BuiltinId::IntToFloat,
        BuiltinId::IntFloorDiv,
        BuiltinId::IntMod,
        BuiltinId::IntAbs,
        BuiltinId::IntMin,
        BuiltinId::IntMax,
        BuiltinId::FloatToString,
        BuiltinId::FloatParse,
        BuiltinId::FloatTruncate,
        BuiltinId::FloatIsNaN,
        BuiltinId::FloatAbs,
        BuiltinId::FloatFloor,
        BuiltinId::FloatCeil,
        BuiltinId::FloatRound,
        BuiltinId::FloatSqrt,
        BuiltinId::CharToInt,
        BuiltinId::CharFromInt,
        BuiltinId::CharToString,
        BuiltinId::CharIsAsciiDigit,
        BuiltinId::CharIsAsciiWhitespace,
        BuiltinId::StringByteLength,
        BuiltinId::StringByteSlice,
        BuiltinId::StringCharCount,
        BuiltinId::StringCharAt,
        BuiltinId::StringCharSlice,
        BuiltinId::StringIsEmpty,
        BuiltinId::StringContains,
        BuiltinId::StringStartsWith,
        BuiltinId::StringEndsWith,
        BuiltinId::StringByteIndexOf,
        BuiltinId::StringSplit,
        BuiltinId::StringLines,
        BuiltinId::StringJoin,
        BuiltinId::StringTrim,
        BuiltinId::StringReplace,
        BuiltinId::StringRepeat,
        BuiltinId::StringChars,
        BuiltinId::StringFromChars,
        BuiltinId::ListLength,
        BuiltinId::ListIsEmpty,
        BuiltinId::ListHead,
        BuiltinId::ListTail,
        BuiltinId::ListGet,
        BuiltinId::ListPrepend,
        BuiltinId::ListAppend,
        BuiltinId::ListConcat,
        BuiltinId::ListReverse,
        BuiltinId::ListTake,
        BuiltinId::ListDrop,
        BuiltinId::ListRange,
        BuiltinId::ListContains,
        BuiltinId::ListSort,
        BuiltinId::ListDropFirst,
        BuiltinId::IoErrorMessage,
        BuiltinId::ConsolePrint,
        BuiltinId::ConsolePrintln,
        BuiltinId::ConsoleEprintln,
        BuiltinId::FileReadText,
        BuiltinId::ProcessArgs,
    ];

    /// 演算子の組み込みの関数か（コード生成が専用の命令に移すもの）。
    pub fn is_operator(self) -> bool {
        matches!(
            self,
            BuiltinId::AddInt
                | BuiltinId::SubInt
                | BuiltinId::MulInt
                | BuiltinId::DivInt
                | BuiltinId::RemInt
                | BuiltinId::NegInt
                | BuiltinId::AddFloat
                | BuiltinId::SubFloat
                | BuiltinId::MulFloat
                | BuiltinId::DivFloat
                | BuiltinId::NegFloat
                | BuiltinId::ConcatString
                | BuiltinId::LtInt
                | BuiltinId::LeInt
                | BuiltinId::GtInt
                | BuiltinId::GeInt
                | BuiltinId::LtFloat
                | BuiltinId::LeFloat
                | BuiltinId::GtFloat
                | BuiltinId::GeFloat
                | BuiltinId::LtString
                | BuiltinId::LeString
                | BuiltinId::GtString
                | BuiltinId::GeString
                | BuiltinId::LtChar
                | BuiltinId::LeChar
                | BuiltinId::GtChar
                | BuiltinId::GeChar
                | BuiltinId::Eq
                | BuiltinId::Ne
        )
    }
}
