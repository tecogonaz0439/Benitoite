# 組み込みの関数

本章は、組み込みの関数の一覧（識別子・名前・型・実装・実行時エラー）と、組み込みの表の型とシグネチャを定める。設計書の対応する章は[名前解決とモジュール読込](../../2026-09-27-design-initial/02-impl/02-04-resolver.md)の「prelude」、[標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md)、[基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)、[エフェクト](../../2026-09-27-design-initial/01-spec/01-07-effects.md)の「IO を行う組み込み関数」である。関数の値の意味は、それらの章の表に従う。

## 組み込みの表の型

組み込みの関数は、`BuiltinId` の列挙子一つで識別する。演算子（01-12 の `⊕_T`）も組み込みの関数であり、演算子とオペランドの型の組ごとに一つの列挙子を持つ（02-06「コア IR」）。`==` と `!=` は型パラメータを一つ持つ `Eq`・`Ne` で表す。

IO を行わない組み込みの関数は、Rust の関数 `PureFn` で実装する。VM は演算子を専用の命令で実行し（02-07「演算子の移し方」）、`PureFn` を使わない。参照インタプリタは、演算子を含むすべての IO を行わない組み込みの関数を `PureFn` で実行する。VM の `Int` の演算の命令と `CONCAT` は、`PureFn` と同じ `ops.rs` の補助の関数（`int_*`・`string_concat`）を呼び、意味を一か所で定める。`Float` の演算と比較の命令は、IEEE 754 の演算そのものなので、Rust の演算で直接書いてよい。

```rust file=src/builtins/mod.rs
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
```

## 組み込みの関数の一覧

「実装」の欄は、`PureFn` を実装する Rust の関数（`crate::builtins::` からのパス）か、IO の操作である。「実行時エラー」の欄は、その関数が止まりうる理由である（「作る値が大きすぎる」は資源の不足 R0902）。型の欄の書き方は 03-06 の表記に従う。

### 演算子

| 識別子 | 記号 | 型 | 実装 | 実行時エラー |
|---|---|---|---|---|
| `AddInt` | `+` | `fn(Int, Int) -> Int` | `ops::add_int` | 整数の溢れ |
| `SubInt` | `-` | `fn(Int, Int) -> Int` | `ops::sub_int` | 整数の溢れ |
| `MulInt` | `*` | `fn(Int, Int) -> Int` | `ops::mul_int` | 整数の溢れ |
| `DivInt` | `/` | `fn(Int, Int) -> Int` | `ops::div_int` | 0 による除算、整数の溢れ |
| `RemInt` | `%` | `fn(Int, Int) -> Int` | `ops::rem_int` | 0 による除算 |
| `NegInt` | `-`（単項） | `fn(Int) -> Int` | `ops::neg_int` | 整数の溢れ |
| `AddFloat` | `+` | `fn(Float, Float) -> Float` | `ops::add_float` |  |
| `SubFloat` | `-` | `fn(Float, Float) -> Float` | `ops::sub_float` |  |
| `MulFloat` | `*` | `fn(Float, Float) -> Float` | `ops::mul_float` |  |
| `DivFloat` | `/` | `fn(Float, Float) -> Float` | `ops::div_float` |  |
| `NegFloat` | `-`（単項） | `fn(Float) -> Float` | `ops::neg_float` |  |
| `ConcatString` | `+` | `fn(String, String) -> String` | `ops::concat_string` | 作る値が大きすぎる |
| `LtInt` | `<` | `fn(Int, Int) -> Bool` | `ops::lt_int` |  |
| `LeInt` | `<=` | `fn(Int, Int) -> Bool` | `ops::le_int` |  |
| `GtInt` | `>` | `fn(Int, Int) -> Bool` | `ops::gt_int` |  |
| `GeInt` | `>=` | `fn(Int, Int) -> Bool` | `ops::ge_int` |  |
| `LtFloat` | `<` | `fn(Float, Float) -> Bool` | `ops::lt_float` |  |
| `LeFloat` | `<=` | `fn(Float, Float) -> Bool` | `ops::le_float` |  |
| `GtFloat` | `>` | `fn(Float, Float) -> Bool` | `ops::gt_float` |  |
| `GeFloat` | `>=` | `fn(Float, Float) -> Bool` | `ops::ge_float` |  |
| `LtString` | `<` | `fn(String, String) -> Bool` | `ops::lt_string` |  |
| `LeString` | `<=` | `fn(String, String) -> Bool` | `ops::le_string` |  |
| `GtString` | `>` | `fn(String, String) -> Bool` | `ops::gt_string` |  |
| `GeString` | `>=` | `fn(String, String) -> Bool` | `ops::ge_string` |  |
| `LtChar` | `<` | `fn(Char, Char) -> Bool` | `ops::lt_char` |  |
| `LeChar` | `<=` | `fn(Char, Char) -> Bool` | `ops::le_char` |  |
| `GtChar` | `>` | `fn(Char, Char) -> Bool` | `ops::gt_char` |  |
| `GeChar` | `>=` | `fn(Char, Char) -> Bool` | `ops::ge_char` |  |
| `Eq` | `==` | `fn[T](T, T) -> Bool`。T は等値の型 | `ops::eq` |  |
| `Ne` | `!=` | `fn[T](T, T) -> Bool`。T は等値の型 | `ops::ne` |  |

`Gt*`・`Ge*` は、VM ではオペランドを入れ替えた `LT*`・`LE*` の命令に移す（02-07「演算子の移し方」）。`Eq`・`Ne` の `PureFn` は、基本型なら値で、代数的データ型とリストなら `values_equal` で比べる。

### prelude のモジュールの関数

| 識別子 | 名前 | 型 | 実装 | 実行時エラー |
|---|---|---|---|---|
| `IntToString` | `Int.toString` | `fn(Int) -> String` | `int::to_string` |  |
| `IntParse` | `Int.parse` | `fn(String) -> Option[Int]` | `int::parse` |  |
| `IntToFloat` | `Int.toFloat` | `fn(Int) -> Float` | `int::to_float` |  |
| `IntFloorDiv` | `Int.floorDiv` | `fn(Int, Int) -> Int` | `int::floor_div` | 0 による除算、整数の溢れ |
| `IntMod` | `Int.mod` | `fn(Int, Int) -> Int` | `int::modulo` | 0 による除算 |
| `IntAbs` | `Int.abs` | `fn(Int) -> Int` | `int::abs` | 整数の溢れ |
| `IntMin` | `Int.min` | `fn(Int, Int) -> Int` | `int::min` |  |
| `IntMax` | `Int.max` | `fn(Int, Int) -> Int` | `int::max` |  |
| `FloatToString` | `Float.toString` | `fn(Float) -> String` | `float::to_string` |  |
| `FloatParse` | `Float.parse` | `fn(String) -> Option[Float]` | `float::parse` |  |
| `FloatTruncate` | `Float.truncate` | `fn(Float) -> Option[Int]` | `float::truncate` |  |
| `FloatIsNaN` | `Float.isNaN` | `fn(Float) -> Bool` | `float::is_nan` |  |
| `FloatAbs` | `Float.abs` | `fn(Float) -> Float` | `float::abs` |  |
| `FloatFloor` | `Float.floor` | `fn(Float) -> Float` | `float::floor` |  |
| `FloatCeil` | `Float.ceil` | `fn(Float) -> Float` | `float::ceil` |  |
| `FloatRound` | `Float.round` | `fn(Float) -> Float` | `float::round` |  |
| `FloatSqrt` | `Float.sqrt` | `fn(Float) -> Float` | `float::sqrt` |  |
| `CharToInt` | `Char.toInt` | `fn(Char) -> Int` | `character::to_int` |  |
| `CharFromInt` | `Char.fromInt` | `fn(Int) -> Option[Char]` | `character::from_int` |  |
| `CharToString` | `Char.toString` | `fn(Char) -> String` | `character::to_string` |  |
| `CharIsAsciiDigit` | `Char.isAsciiDigit` | `fn(Char) -> Bool` | `character::is_ascii_digit` |  |
| `CharIsAsciiWhitespace` | `Char.isAsciiWhitespace` | `fn(Char) -> Bool` | `character::is_ascii_whitespace` |  |
| `StringByteLength` | `String.byteLength` | `fn(String) -> Int` | `string::byte_length` |  |
| `StringByteSlice` | `String.byteSlice` | `fn(String, Int, Int) -> Option[String]` | `string::byte_slice` |  |
| `StringCharCount` | `String.charCount` | `fn(String) -> Int` | `string::char_count` |  |
| `StringCharAt` | `String.charAt` | `fn(String, Int) -> Option[Char]` | `string::char_at` |  |
| `StringCharSlice` | `String.charSlice` | `fn(String, Int, Int) -> Option[String]` | `string::char_slice` |  |
| `StringIsEmpty` | `String.isEmpty` | `fn(String) -> Bool` | `string::is_empty` |  |
| `StringContains` | `String.contains` | `fn(String, String) -> Bool` | `string::contains` |  |
| `StringStartsWith` | `String.startsWith` | `fn(String, String) -> Bool` | `string::starts_with` |  |
| `StringEndsWith` | `String.endsWith` | `fn(String, String) -> Bool` | `string::ends_with` |  |
| `StringByteIndexOf` | `String.byteIndexOf` | `fn(String, String) -> Option[Int]` | `string::byte_index_of` |  |
| `StringSplit` | `String.split` | `fn(String, String) -> List[String]` | `string::split` | 作る値が大きすぎる |
| `StringLines` | `String.lines` | `fn(String) -> List[String]` | `string::lines` | 作る値が大きすぎる |
| `StringJoin` | `String.join` | `fn(List[String], String) -> String` | `string::join` | 作る値が大きすぎる |
| `StringTrim` | `String.trim` | `fn(String) -> String` | `string::trim` |  |
| `StringReplace` | `String.replace` | `fn(String, String, String) -> String` | `string::replace` | 作る値が大きすぎる |
| `StringRepeat` | `String.repeat` | `fn(String, Int) -> String` | `string::repeat` | 作る値が大きすぎる |
| `StringChars` | `String.chars` | `fn(String) -> List[Char]` | `string::chars` | 作る値が大きすぎる |
| `StringFromChars` | `String.fromChars` | `fn(List[Char]) -> String` | `string::from_chars` | 作る値が大きすぎる |
| `ListLength` | `List.length` | `fn[T](List[T]) -> Int` | `list::length` |  |
| `ListIsEmpty` | `List.isEmpty` | `fn[T](List[T]) -> Bool` | `list::is_empty` |  |
| `ListHead` | `List.head` | `fn[T](List[T]) -> Option[T]` | `list::head` |  |
| `ListTail` | `List.tail` | `fn[T](List[T]) -> Option[List[T]]` | `list::tail` |  |
| `ListGet` | `List.get` | `fn[T](List[T], Int) -> Option[T]` | `list::get` |  |
| `ListPrepend` | `List.prepend` | `fn[T](List[T], T) -> List[T]` | `list::prepend` | 作る値が大きすぎる |
| `ListAppend` | `List.append` | `fn[T](List[T], T) -> List[T]` | `list::append` | 作る値が大きすぎる |
| `ListConcat` | `List.concat` | `fn[T](List[T], List[T]) -> List[T]` | `list::concat` | 作る値が大きすぎる |
| `ListReverse` | `List.reverse` | `fn[T](List[T]) -> List[T]` | `list::reverse` |  |
| `ListTake` | `List.take` | `fn[T](List[T], Int) -> List[T]` | `list::take` |  |
| `ListDrop` | `List.drop` | `fn[T](List[T], Int) -> List[T]` | `list::drop` |  |
| `ListRange` | `List.range` | `fn(Int, Int) -> List[Int]` | `list::range` | 作る値が大きすぎる |
| `ListContains` | `List.contains` | `fn[T](List[T], T) -> Bool`。T は等値の型 | `list::contains` |  |
| `ListSort` | `List.sort` | `fn[T](List[T]) -> List[T]`。T は Int・Float・String・Char のどれか | `list::sort` |  |
| `ListDropFirst` | `List.dropFirst` | `fn[T](List[T]) -> List[T]`（prelude のソースの中だけで使える） | `list::drop_first` |  |
| `IoErrorMessage` | `IoError.message` | `fn(IoError) -> String` | `io_error::message` |  |
| `ConsolePrint` | `Console.print` | `fn(String) -> Unit uses IO` | IO の操作 `IoOp::Print` | 書き込みの失敗 |
| `ConsolePrintln` | `Console.println` | `fn(String) -> Unit uses IO` | IO の操作 `IoOp::Println` | 書き込みの失敗 |
| `ConsoleEprintln` | `Console.eprintln` | `fn(String) -> Unit uses IO` | IO の操作 `IoOp::Eprintln` | 書き込みの失敗 |
| `FileReadText` | `File.readText` | `fn(String) -> Result[String, IoError] uses IO` | IO の操作 `IoOp::ReadText` | 作る値が大きすぎる |
| `ProcessArgs` | `Process.args` | `fn() -> List[String] uses IO` | IO の操作 `IoOp::Args` |  |

`List.dropFirst` は、prelude のソースの中だけで使える組み込みの関数である（02-04「prelude」の印）。先頭を除いたリストを返し、空のリストには空のリストを返す。`List.drop(xs, 1)` と同じ値だが、`Int` の引数を持たない。利用者のプログラムから `List.dropFirst` を使うと、E0303（`List` に `dropFirst` がない）とする。

関数を引数にとる prelude の関数（`List.map` など）と、`Option`・`Result` の関数は、組み込みの関数ではなく prelude のソースで定める（[prelude のソース](10-11-prelude-source.md)）。

## 組み込みの表の関数

```rust sig=src/builtins/table.rs
use crate::types::Scheme;
use super::{BuiltinId, BuiltinSpec, PreludeModule};

/// 組み込みの表の項目。
pub fn spec(id: BuiltinId) -> BuiltinSpec;

/// 組み込みの関数の型（本章の一覧の型の欄）。型パラメータの制約（等値の型、型の集まり）を含む。
pub fn scheme(id: BuiltinId) -> Scheme;

/// モジュールと修飾しない名前から組み込みの関数を引く。演算子は引けない。
pub fn lookup(module: PreludeModule, name: &str) -> Option<BuiltinId>;
```

## 実装の関数

各 `PureFn` は次の形である。

```rust sig=src/builtins/int.rs
use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::value::Value;

/// `Int.toString`（一覧の他の関数も同じ形）
pub fn to_string(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop>;
```

演算子の補助の関数は、VM の命令と `PureFn` が共有する。

```rust sig=src/builtins/ops.rs
use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::value::Value;

/// `Int` の `+`。溢れは `Stop::Runtime(RuntimeError::IntegerOverflow)`（01-04「Int」）
pub fn int_add(a: i64, b: i64) -> Result<i64, Stop>;
pub fn int_sub(a: i64, b: i64) -> Result<i64, Stop>;
pub fn int_mul(a: i64, b: i64) -> Result<i64, Stop>;
/// 0 の方向に切り捨てる。b が 0 なら 0 による除算、a が −2^63 で b が −1 なら溢れ
pub fn int_div(a: i64, b: i64) -> Result<i64, Stop>;
/// 結果の符号は a と同じか 0。b が 0 なら 0 による除算。a が −2^63 で b が −1 なら 0
pub fn int_rem(a: i64, b: i64) -> Result<i64, Stop>;
pub fn int_neg(a: i64) -> Result<i64, Stop>;
/// `String` の `+`。結果の大きさを先に計算し、上限を超えるなら資源の不足（関数の名前は `+`）
pub fn string_concat(heap: &mut Heap, a: &str, b: &str) -> Result<Value, Stop>;

/// 一覧の `ops::add_int` など、演算子の `PureFn`（形は `int::to_string` と同じ）
pub fn add_int(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop>;
```

一覧に挙げたほかの実装の関数も、`int::to_string` と同じ形で、同じ名前のモジュールに置く。
