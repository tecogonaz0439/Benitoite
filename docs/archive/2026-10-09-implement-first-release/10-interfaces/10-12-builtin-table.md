# 組み込みの関数の表

本章は、初回リリース版の U1・U2 の範囲の組み込みの関数の表を定める。表の項目（名前・権限・引数の数・宣言の型・専用の命令）、表の組み立て方と番号の振り方、名前の付け方、脱糖・コード生成・コア IR の検査器が表を引く関数、組み込みの関数が値を作るときに使う構成子のタグである。設計書の対応する箇所は、[名前解決とモジュール読込](../../2026-10-09-design-first-release/02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」、[中間表現と脱糖](../../2026-10-09-design-first-release/02-impl/02-06-ir-and-lowering.md)の「脱糖」、[バイトコードとコード生成](../../2026-10-09-design-first-release/02-impl/02-07-bytecode.md)の「演算子の移し方」であり、判断の根拠は [ADR 0157](../../2026-10-09-design-first-release/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)（組み込みの関数を `@builtin` を付けた本体のない宣言で表す）と [ADR 0273](../../2026-10-09-design-first-release/decisions/0273-u2-u3-boundary-for-runtime-builtins.md)（U2 と U3 の境目）である。組み込みの関数を書く形（`builtin!`、`BuiltinDecl`、権限ごとの文脈）は[組み込みの関数の型付きの形](10-11-builtin-interface.md)で定める。

- 置く作業: C02

本章は U1 と U2 が共有する章である。U2 が表を作り（R08・R23・R25・R29・R35・R37・R39）、U1 が表を引く（名前解決の F06、脱糖の F11、検査器の F13、コード生成の F15）。U3 は、本章の末尾に項目を足す。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

本章のコードは、すべて `src/builtins/table.rs` の `sig=` である。`table.rs` は、10-11 が C01 で `sig=`（`builtin_decl`・`lookup_builtin`）として置くファイルであり、本章は `file=` を置かない（[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」）。本章の `sig=` は、次の二つに分かれる。

| ブロック | 置く作業 | 中身を書く作業 | 理由 |
|---|---|---|---|
| 構成子のタグ（`table::tags`） | C01（`task=C01`） | R07 が写して置く | 第 1 段の組み込みの関数（R07・R08）が `Option`・`Result` の値を作るので、C01 の時点で凍結する。値を持つ定数だけなので、写せば済む |
| 項目の種類と、表を引く関数 | C02 | R08 | [型と型検査](10-05-types.md)の `BuiltinTypeId`・`Scheme` と、[中間表現](10-06-ir.md)の `OperatorKind`・`Intrinsic`・`ListEnd` を使うので、C02 で凍結する |

R08 は、表の全体（本章の項目の一覧のすべての項目）と、C02 のブロックの関数を書く。そのため、R08 は R07 のほかに C02 にも依存する。C02 はインターフェースを置くだけの作業であり C01 の直後に行えるので、この依存は U2 第 1 段の進みを遅らせない。

組み込みの関数の本体は `src/builtins/funcs/` の子のモジュールに書く（10-11「登録と第 1 段の扱い」）。子のモジュールのファイルは R08 がすべて作り、後の作業（R23・R25・R29・R35・R37・R39）が本体を書き足す（後述の「まだ書かない項目の仮の本体」）。

## 表の組み立て

### 部分と番号

組み込みの関数を書く `funcs` の子のモジュールは、宣言した関数の `DECL` を並べた定数 `pub const DECLS: &[BuiltinDecl]` を持つ（10-11「登録と第 1 段の扱い」）。一つのモジュールの `DECLS` を、表の「部分」と呼ぶ。`funcs/mod.rs` は、部分を並べた定数 `PARTS` を持つ。

```text
// src/builtins/funcs/mod.rs（R08 が置く形。部分を加える作業は、末尾に一行足す）
pub mod operators;
pub mod integer;
// …（後述の「部分の一覧」の順）

/// 表の部分。並びの順が番号の順である（実装プラン 10-12「部分と番号」）。末尾にだけ加える。
pub const PARTS: &[&[BuiltinDecl]] = &[operators::DECLS, integer::DECLS, /* … */ clock::DECLS];
```

組み込みの関数の番号（`BuiltinId`）は、`PARTS` の部分を順につないだ並びの中の位置である。`builtin_decl(id)` は部分の長さを引きながら位置を探し、`lookup_builtin(name)` はすべての項目を先頭から調べる。項目は数百にとどまり、`lookup_builtin` を呼ぶのは名前解決が組み込みの関数と操作の束縛を作るときと、脱糖が特別な項目を引くときだけなので、索引は作らない。表は初期化の後に変更しないので、`const` と関数で表し、大域の可変状態を持たない（[ADR 0015](../../2026-10-09-design-first-release/decisions/0015-shared-program-per-execution-state.md)）。

`funcs/mod.rs` は、組み込みの関数を書く作業が子のモジュールを宣言して加えるファイルである（[作業の進め方](../00-common/00-03-workflow.md)の「ブランチと並行作業」の、作業が触れてよいファイルの例外）。部分を加える作業は、同じ例外により、`PARTS` の末尾に部分を加えてよい。`table.rs` を変える必要はない。

### 番号の振り方

- 番号は、実行のたびに作るコンパイル済みプログラム（10-07 の `BuiltinRef`）の中にだけ現れ、ファイルに保存しない。したがって、どのコードも番号の値を書き込まず、名前か本章の関数（`lookup_builtin`、`operator_builtin` など）で引く。テストも同じである。
- 部分は `PARTS` の末尾にだけ加え、部分の中の項目は `DECLS` の末尾にだけ加える。既存の項目を消したり並べ替えたりしない。逆アセンブラの出力（組み込みの関数の参照を番号で示す）を記録したテストが、項目を加えても変わらないようにするためである。
- U1・U2 の範囲のすべての項目は、R08 が第 1 段で一度に並べる（後述の「まだ書かない項目の仮の本体」）。後の作業は項目の本体を書くだけで、番号を変えない。
- U3 は、新しい部分を `PARTS` の末尾に加える。既存のモジュールの型に関数を足すとき（`String.toUppercase` など）も、既存の `DECLS` の途中には入れず、同じファイルに別の定数（`UNICODE_DECLS` など）を作って新しい部分として末尾に加える。

番号は 65536 個に満たない（10-11 の `BuiltinId` は `u16`）。後述の「部分の一覧」の番号の欄は、この並べ方から決まる値を参考に示したものであり、コードに書かない。

### まだ書かない項目の仮の本体

名前解決は、標準ライブラリのソースの `@builtin` の名前と組み込みのエフェクトの操作を表で引き、表にない名前を処理系の不具合として報告する（[モジュールと名前解決](10-04-modules-and-resolve.md)の「名前解決の表」）。prelude のモジュール（`Task`・`Reference` など）は、どのプログラムを検査するときも読む。したがって、prelude のソースが宣言する組み込みの関数は、その本体を書く作業（R29 など）より前から、表に載っていなければならない。

そこで、R08 は、本章の項目の一覧のすべての項目を `builtin!` で宣言する。第 1 段で本体を書かない項目は、名前・権限・引数の数だけが正しい仮の本体とし、呼ばれたら次の値を返す。

```text
Err(Stop::Internal(format!("builtin {} is not implemented yet", "Task.all")))
```

仮の本体の引数の Rust の型は `Value<'e>` でよい。本体を書く作業は、本体と引数の Rust の型を書き換えてよいが、名前・権限・引数の数と、部分の中の位置は変えない。仮の本体の項目は、型検査を通ったプログラムから呼ばれうるが、呼ばれるのはその機能を使ったときだけであり、そのときは処理系の不具合（まだ作っていない）として報告される。

## 名前の付け方

表の名前（`BuiltinDecl::name`）は、項目の種類ごとに次の形とする。名前は表の中で重ならない。`builtin!` の `name` には、この名前をそのまま書く。

| 項目 | 名前の形 | 例 | 名前を引く箇所 |
|---|---|---|---|
| `@builtin` を付けて宣言した関数 | モジュールの名前から `Benitoite.` を除いた段と関数の名前をドットでつないだもの。`@builtin("…")` の引数と同じ | `List.get`、`Integer.toString`、`IO.File.closeReader`、`Trait.showString` | 名前解決（`@builtin` の引数で `lookup_builtin`） |
| 組み込みのエフェクトの操作 | `Benitoite.` から始まる、操作の完全な名前 | `Benitoite.IO.Console.writeLine`、`Benitoite.IO.Clock.sleep` | 名前解決（操作の束縛から組み立てた名前で `lookup_builtin`。10-04） |
| ソースに宣言のない内部の項目（演算子、`eq`・`ne`、リストのパターン、文字列補間） | `%` から始まる名前 | `%Integer.add`、`%eq`、`%List.getFront`、`%Boolean.toString` | 本章の関数（`operator_builtin` など） |

- `@builtin` の名前の形は、[標準ライブラリ](../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「標準ライブラリのソースの書き方」の例（`@builtin("List.get")`）に合わせた。操作の名前の形は、10-04 が名前解決の手順として定めたもの（`Benitoite.IO.Console.writeLine`）である。操作の名前だけが `Benitoite.` から始まり、内部の項目だけが `%` から始まるので、名前の頭で三つを見分けられる。
- `@builtin` の引数に `Benitoite.` か `%` から始まる名前を書くと、標準ライブラリのソースの誤り（処理系の不具合）とする。F06 のテストが確かめる（後述の「確かめること」）。
- 修飾した名前の最後の段は、関数と操作の名前である。修飾の段は、宣言したモジュールの名前であり、型の名前ではない（`IO.File.closeReader` の `IO.File` はモジュール `Benitoite.IO.File`）。非公式のモジュール（03-06「標準のモジュールと非公式のモジュール（初回リリース版）」）の項目も、取り込みの名前（`Benitoite.Unofficial.IO.File`）ではなく、標準に加えた後のモジュールの名前で書く（[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。モジュールを標準に移しても、本章の名前は変わらない。
- 内部の項目の `%` の後の段は、読みやすさのための名前であり、名前解決の規則には従わない。

## 項目の種類

表の項目は、次の種類のどれか一つである（`EntryKind`）。種類は名前と権限から決まる。

| 種類 | 当たる項目 | 権限 | 宣言の型の出どころ | 専用の命令（`Intrinsic`） |
|---|---|---|---|---|
| `Declared` | `@builtin` を付けて宣言した関数 | `Pure` か `State` | 標準ライブラリのソースの宣言（10-14） | `Lazy.force` は `Force`、`Reference.update` は `Update`。ほかはない |
| `EffectOp` | 組み込みのエフェクトの操作 | `Io` | 同上（エフェクトの宣言の操作） | ない |
| `Operator` | 演算子 `⊕_T`・`neg_T`（`=`・`<>` を除く） | `Pure` | 本章の `builtin_scheme` | `Operator { op, operand }` |
| `Equality` | `eq`・`ne` | `Pure` | 同上（`[T: equality](T, T) -> Boolean`） | `Eq`・`Ne` |
| `ListPattern` | リストのパターンの内部の項目 | `Pure` | 同上 | ない |
| `Interpolation` | ソースに名前を持たない文字列補間の `str_T`（`Boolean` の分だけ） | `Pure` | 同上 | ない |

- 権限が `Io` の項目と、組み込みのエフェクトの操作は一対一に対応する。`State` を型に持つ関数（`Reference`・`TaskGroup` の関数、`Task.await`、`File.closeReader`）とタスクを起動する関数（`Task.all` など）は、操作ではなく `Declared` の項目であり、権限は `State` である（10-11「権限と応答」、[ADR 0150](../../2026-10-09-design-first-release/decisions/0150-resource-release-as-state.md)）。
- `Declared` と `EffectOp` の項目の型は、標準ライブラリのソースの宣言が与える（ADR 0157）。表は型を持たず、名前から実装への対応だけを持つ。ソースの宣言と Rust の実装が合うことは、後述の「確かめること」のテストと、項目ごとの単体テストで確かめる。
- ソースに宣言のない項目は、ソースから型を得られないので、本章の `builtin_scheme` が型を与える。これらの型は組み込みの型だけからなり、ソースで宣言した型（`Option` など）を含まない。
- `Lazy.force` と `Reference.update` の `raw` は、呼ばれたら `Stop::Internal` を返す。受け取った関数を呼ぶので、組み込みの関数の本体としては書けず、VM は `FORCE`・`UPDATE` の命令で実行するからである（[ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」）。参照インタプリタも、この二つを `raw` で呼ばずに 01-12 の遷移のとおりに実行する（後述の「10-06 との対応」）。

## 構成子のタグ

組み込みの関数が、標準ライブラリのソースで宣言した型（`Option`・`Result`・`Pair`・`IOErrorKind` など）の値を作るときと読むときは、構成子のタグ（型の宣言の中で 0 から数えた番号。10-08 の `CtorTag`）を使う。タグは 10-14 のソースの構成子の宣言の順で決まるので、本章で定数として固定し、ソースの宣言の順と一致することを F06 のテストで確かめる。引数を持つ構成子は `alloc_fields(FieldsKind::Ctor, tag, …)` で、引数を持たない構成子は `Value::Tag(CtorTag(tag))` で作る。`IOError` の値の `tag`（10-08 の `FieldsKind::IoError`）も、`IOErrorKind` のタグと同じ番号である。

```rust sig=src/builtins/table.rs task=C01
/// 標準ライブラリのソースで宣言した型の構成子のタグ（実装プラン 10-12「構成子のタグ」）。
/// 10-14 のソースの構成子の宣言の順であり、F06 のテストがソースと一致することを確かめる。
pub mod tags {
    /// `Option.Some`
    pub const OPTION_SOME: u32 = 0;
    /// `Option.None`
    pub const OPTION_NONE: u32 = 1;
    /// `Result.Ok`
    pub const RESULT_OK: u32 = 0;
    /// `Result.Error`
    pub const RESULT_ERROR: u32 = 1;
    /// `Pair`
    pub const PAIR: u32 = 0;
    /// `Triple`
    pub const TRIPLE: u32 = 0;
    /// `IOErrorKind` の構成子（01-09「IO の失敗の種類」の順）
    pub const IO_ERROR_KIND_NOT_FOUND: u32 = 0;
    pub const IO_ERROR_KIND_PERMISSION_DENIED: u32 = 1;
    pub const IO_ERROR_KIND_ALREADY_EXISTS: u32 = 2;
    pub const IO_ERROR_KIND_IS_DIRECTORY: u32 = 3;
    pub const IO_ERROR_KIND_NOT_DIRECTORY: u32 = 4;
    pub const IO_ERROR_KIND_DIRECTORY_NOT_EMPTY: u32 = 5;
    pub const IO_ERROR_KIND_INVALID_UTF8: u32 = 6;
    pub const IO_ERROR_KIND_INVALID_INPUT: u32 = 7;
    pub const IO_ERROR_KIND_OTHER: u32 = 8;
    /// `RoundingMode` の構成子（01-05「prelude が定める型」の順）
    pub const ROUNDING_MODE_HALF_TO_EVEN: u32 = 0;
    pub const ROUNDING_MODE_HALF_AWAY_FROM_ZERO: u32 = 1;
    pub const ROUNDING_MODE_TOWARD_ZERO: u32 = 2;
    pub const ROUNDING_MODE_TOWARD_NEGATIVE_INFINITY: u32 = 3;
    pub const ROUNDING_MODE_TOWARD_POSITIVE_INFINITY: u32 = 4;
}
```

## 表を引く関数

脱糖・コード生成・検査器は、次の関数で表を引く。どれも、表にない項目には `None` を返す。型検査を通ったプログラムの脱糖で `None` が返ったら、脱糖は `InternalError` を返す（10-06「脱糖」）。

| 関数 | 使う作業 | 内容 |
|---|---|---|
| `builtin_kind` | F11、F13、R08 のテスト | 項目の種類。名前の頭と権限、本章の定数の表から決める |
| `builtin_intrinsic` | F11（`BuiltinInfo::intrinsic`） | 専用の命令に移す項目の `Intrinsic` |
| `operator_builtin` | F11 | 演算子とオペランドの型から項目を引く。01-06「演算子の型付け」の組（02-07「演算子の移し方」の表の「—」でない組）をすべて持つ |
| `equality_builtin` | F11 | `eq`（`negated` が偽）と `ne`（真） |
| `interpolation_builtin` | F11 | 文字列補間の `str_T`。`String` を除く補間の型（10-05 の `TySet::INTERP`）をすべて持つ |
| `list_pattern_builtin` | F15 | リストのパターンの内部の項目（10-06 の `CaseLength`・`ListGet`・`ListSlice`） |
| `builtin_scheme` | F13 | ソースに宣言のない項目の宣言の型 |

`builtin_decl` と `lookup_builtin` は 10-11 が C01 で置き、中身は R08 が書く。

```rust sig=src/builtins/table.rs needs=10-05,10-06
use crate::ir::core_ir::{Intrinsic, OperatorKind};
use crate::ir::lower_ir::ListEnd;
use crate::types::Scheme;
use crate::types::builtin::BuiltinTypeId;

/// 組み込みの表の項目の種類（実装プラン 10-12「項目の種類」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EntryKind {
    /// 標準ライブラリのソースで `@builtin` を付けて宣言した関数。型はソースの宣言が与える
    Declared,
    /// 組み込みのエフェクトの操作（権限は `Io`）。型はソースの操作の宣言が与える
    EffectOp,
    /// 演算子 `⊕_T`・`neg_T`（01-12）。`=` と `<>` は `Equality`
    Operator { op: OperatorKind, operand: BuiltinTypeId },
    /// `eq[T]`（`negated` が偽）と `ne[T]`（真）
    Equality { negated: bool },
    /// リストのパターンの内部の項目（02-06「判定の木への変換」）
    ListPattern(ListPatternOp),
    /// ソースに名前を持たない文字列補間の `str_T`
    Interpolation { operand: BuiltinTypeId },
}

/// リストのパターンの内部の項目（10-06 の下位 IR の `CaseLength`・`ListGet`・`ListSlice`）。
/// どれも実行時エラーを起こさない。範囲の外の位置を受け取ったら `Stop::Internal` を返す（判定の木が長さを
/// 確かめてから呼ぶので、型検査を通ったプログラムでは起きない）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ListPatternOp {
    /// `%List.length`: `function[T](List[T]) -> Integer`
    Length,
    /// `%List.getFront`・`%List.getBack`: `function[T](List[T], Integer) -> T`。端から 0 で数えた位置の要素
    Get(ListEnd),
    /// `%List.slice`: `function[T](List[T], Integer, Integer) -> List[T]`。前の n 個と後の m 個を除いた部分
    Slice,
}

/// 演算子の項目（01-06「演算子の型付け」、02-07「演算子の移し方」）。
pub const OPERATORS: &[(OperatorKind, BuiltinTypeId, &str)] = &[
    (OperatorKind::Add, BuiltinTypeId::INTEGER, "%Integer.add"),
    (OperatorKind::Sub, BuiltinTypeId::INTEGER, "%Integer.subtract"),
    (OperatorKind::Mul, BuiltinTypeId::INTEGER, "%Integer.multiply"),
    (OperatorKind::IntDiv, BuiltinTypeId::INTEGER, "%Integer.div"),
    (OperatorKind::Mod, BuiltinTypeId::INTEGER, "%Integer.mod"),
    (OperatorKind::Neg, BuiltinTypeId::INTEGER, "%Integer.negate"),
    (OperatorKind::Lt, BuiltinTypeId::INTEGER, "%Integer.less"),
    (OperatorKind::Le, BuiltinTypeId::INTEGER, "%Integer.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::INTEGER, "%Integer.greater"),
    (OperatorKind::Ge, BuiltinTypeId::INTEGER, "%Integer.greaterOrEqual"),
    (OperatorKind::Add, BuiltinTypeId::FLOAT, "%Float.add"),
    (OperatorKind::Sub, BuiltinTypeId::FLOAT, "%Float.subtract"),
    (OperatorKind::Mul, BuiltinTypeId::FLOAT, "%Float.multiply"),
    (OperatorKind::Div, BuiltinTypeId::FLOAT, "%Float.divide"),
    (OperatorKind::Neg, BuiltinTypeId::FLOAT, "%Float.negate"),
    (OperatorKind::Lt, BuiltinTypeId::FLOAT, "%Float.less"),
    (OperatorKind::Le, BuiltinTypeId::FLOAT, "%Float.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::FLOAT, "%Float.greater"),
    (OperatorKind::Ge, BuiltinTypeId::FLOAT, "%Float.greaterOrEqual"),
    (OperatorKind::Add, BuiltinTypeId::DECIMAL, "%Decimal.add"),
    (OperatorKind::Sub, BuiltinTypeId::DECIMAL, "%Decimal.subtract"),
    (OperatorKind::Mul, BuiltinTypeId::DECIMAL, "%Decimal.multiply"),
    (OperatorKind::Div, BuiltinTypeId::DECIMAL, "%Decimal.divide"),
    (OperatorKind::Neg, BuiltinTypeId::DECIMAL, "%Decimal.negate"),
    (OperatorKind::Lt, BuiltinTypeId::DECIMAL, "%Decimal.less"),
    (OperatorKind::Le, BuiltinTypeId::DECIMAL, "%Decimal.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::DECIMAL, "%Decimal.greater"),
    (OperatorKind::Ge, BuiltinTypeId::DECIMAL, "%Decimal.greaterOrEqual"),
    (OperatorKind::Add, BuiltinTypeId::STRING, "%String.add"),
    (OperatorKind::Lt, BuiltinTypeId::STRING, "%String.less"),
    (OperatorKind::Le, BuiltinTypeId::STRING, "%String.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::STRING, "%String.greater"),
    (OperatorKind::Ge, BuiltinTypeId::STRING, "%String.greaterOrEqual"),
    (OperatorKind::Lt, BuiltinTypeId::CHARACTER, "%Character.less"),
    (OperatorKind::Le, BuiltinTypeId::CHARACTER, "%Character.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::CHARACTER, "%Character.greater"),
    (OperatorKind::Ge, BuiltinTypeId::CHARACTER, "%Character.greaterOrEqual"),
    (OperatorKind::Lt, BuiltinTypeId::BYTE, "%Byte.less"),
    (OperatorKind::Le, BuiltinTypeId::BYTE, "%Byte.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::BYTE, "%Byte.greater"),
    (OperatorKind::Ge, BuiltinTypeId::BYTE, "%Byte.greaterOrEqual"),
];

/// `eq[T]` の項目の名前。
pub const EQUALITY: &str = "%eq";
/// `ne[T]` の項目の名前。
pub const INEQUALITY: &str = "%ne";

/// 文字列補間の `str_T` の項目（01-06「演算子の型付け」の補間の型のうち `String` を除くもの）。
/// ソースに同じ意味の関数があるものはその項目を使い、`Boolean` だけ内部の項目を置く。
pub const INTERPOLATION: &[(BuiltinTypeId, &str)] = &[
    (BuiltinTypeId::INTEGER, "Integer.toString"),
    (BuiltinTypeId::FLOAT, "Float.toString"),
    (BuiltinTypeId::CHARACTER, "Character.toString"),
    (BuiltinTypeId::BOOLEAN, "%Boolean.toString"),
    (BuiltinTypeId::BYTE, "Byte.toString"),
    (BuiltinTypeId::DECIMAL, "Decimal.toString"),
];

/// リストのパターンの内部の項目。
pub const LIST_PATTERN: &[(ListPatternOp, &str)] = &[
    (ListPatternOp::Length, "%List.length"),
    (ListPatternOp::Get(ListEnd::Front), "%List.getFront"),
    (ListPatternOp::Get(ListEnd::Back), "%List.getBack"),
    (ListPatternOp::Slice, "%List.slice"),
];

/// 専用の命令に移す `@builtin` の関数（02-07「コード生成」の `FORCE`・`UPDATE`）。
pub const INTRINSIC_FUNCTIONS: &[(&str, Intrinsic)] = &[
    ("Lazy.force", Intrinsic::Force),
    ("Reference.update", Intrinsic::Update),
];

/// 項目の種類。名前が `%` から始まる項目は上の定数の表から、`Benitoite.` から始まる項目は `EffectOp`、
/// ほかは `Declared` とする。
pub fn builtin_kind(id: BuiltinId) -> Option<EntryKind>;

/// 専用の命令に移す項目の `Intrinsic`（`Operator`・`Equality` の項目と `INTRINSIC_FUNCTIONS`）。
pub fn builtin_intrinsic(id: BuiltinId) -> Option<Intrinsic>;

/// 演算子とオペランドの型から項目を引く（`OPERATORS`）。
pub fn operator_builtin(op: OperatorKind, operand: BuiltinTypeId) -> Option<BuiltinId>;

/// `eq`（`negated` が偽）か `ne`（真）の項目。
pub fn equality_builtin(negated: bool) -> Option<BuiltinId>;

/// 文字列補間の `str_T` の項目（`INTERPOLATION`）。`String` には `None` を返す（`str_T` を通さない）。
pub fn interpolation_builtin(operand: BuiltinTypeId) -> Option<BuiltinId>;

/// リストのパターンの内部の項目（`LIST_PATTERN`）。
pub fn list_pattern_builtin(op: ListPatternOp) -> Option<BuiltinId>;

/// ソースに宣言のない項目（`Operator`・`Equality`・`ListPattern`・`Interpolation`）の宣言の型。
/// `Declared` と `EffectOp` の項目には `None` を返す（型はソースの宣言が与える）。
/// 型パラメータは `T` 一つ（`Equality` は組み込みの制約 `equality` を持つ）か、ない。エフェクトは空集合である。
pub fn builtin_scheme(id: BuiltinId) -> Option<Scheme>;
```

## 部分の一覧

U1・U2 の範囲の部分と、その順は次のとおりである。「作業」の欄は、項目の本体を書く作業である（R08 は、ほかの作業の項目も仮の本体で宣言する）。

| 順 | 部分（`funcs` の子のモジュール） | 項目の数 | 番号（参考） | 作業 |
|---|---|---|---|---|
| 1 | `operators` | 43 | 0〜42 | R08（30）、R35（13） |
| 2 | `integer` | 15 | 43〜57 | R08（8）、R35（7） |
| 3 | `float` | 9 | 58〜66 | R08 |
| 4 | `character` | 5 | 67〜71 | R08 |
| 5 | `string` | 18 | 72〜89 | R08 |
| 6 | `boolean` | 1 | 90 | R08 |
| 7 | `byte` | 9 | 91〜99 | R35 |
| 8 | `decimal` | 8 | 100〜107 | R35 |
| 9 | `list` | 18 | 108〜125 | R08 |
| 10 | `map` | 3 | 126〜128 | R37 |
| 11 | `set` | 3 | 129〜131 | R37 |
| 12 | `io_error` | 2 | 132〜133 | R08（1）、R29（1） |
| 13 | `reference` | 4 | 134〜137 | R23（3）、R29（1） |
| 14 | `lazy` | 1 | 138 | R29 |
| 15 | `task` | 5 | 139〜143 | R25（2）、R39（3） |
| 16 | `task_group` | 2 | 144〜145 | R25 |
| 17 | `traits` | 2 | 146〜147 | R08 |
| 18 | `console` | 6 | 148〜153 | R08（4）、R29（2） |
| 19 | `file` | 6 | 154〜159 | R08（1）、R29（5） |
| 20 | `process` | 2 | 160〜161 | R08（1）、R29（1） |
| 21 | `clock` | 2 | 162〜163 | R29 |

合計は 164 項目である。U3 の部分は 22 番から後に加える。

## 項目の一覧

各部分の項目を、部分の中の順に示す。「引数」は `BuiltinDecl::arity`、「型」は宣言の型である。`Declared` と `EffectOp` の型は標準ライブラリのソース（[標準ライブラリのソース](10-14-prelude-and-stdlib-sources.md)）の宣言を写したもので、食い違うときはソースを正とする。関数の意味と実行時エラーは、各行の「意味」の欄に挙げた設計書の箇所で定める。

### 演算子（`operators`）

演算子の項目は、どれも権限が `Pure` で、種類が `Operator`（`%eq`・`%ne` は `Equality`）である。意味と実行時エラー（整数の溢れ、0 での除算など）は[基本型の意味論](../../2026-10-09-design-first-release/01-spec/01-04-types-basic.md)で、移す命令は 02-07「演算子の移し方」で定める。VM は専用の命令で実行し、`raw` は参照インタプリタが呼ぶ（[ADR 0276](../../2026-10-09-design-first-release/decisions/0276-reference-interpreter-shares-builtin-bodies.md)）。

| 名前 | 演算子 | 引数 | 型 | 作業 |
|---|---|---|---|---|
| `%Integer.add`・`%Integer.subtract`・`%Integer.multiply`・`%Integer.div`・`%Integer.mod` | `+`・`-`・`*`・`div`・`mod` | 2 | `function(Integer, Integer) -> Integer` | R08 |
| `%Integer.negate` | 単項の `-` | 1 | `function(Integer) -> Integer` | R08 |
| `%Integer.less`・`%Integer.lessOrEqual`・`%Integer.greater`・`%Integer.greaterOrEqual` | `<`・`<=`・`>`・`>=` | 2 | `function(Integer, Integer) -> Boolean` | R08 |
| `%Float.add`・`%Float.subtract`・`%Float.multiply`・`%Float.divide` | `+`・`-`・`*`・`/` | 2 | `function(Float, Float) -> Float` | R08 |
| `%Float.negate` | 単項の `-` | 1 | `function(Float) -> Float` | R08 |
| `%Float.less`・`%Float.lessOrEqual`・`%Float.greater`・`%Float.greaterOrEqual` | `<`・`<=`・`>`・`>=` | 2 | `function(Float, Float) -> Boolean` | R08 |
| `%Decimal.add`・`%Decimal.subtract`・`%Decimal.multiply`・`%Decimal.divide` | `+`・`-`・`*`・`/` | 2 | `function(Decimal, Decimal) -> Decimal` | R35 |
| `%Decimal.negate` | 単項の `-` | 1 | `function(Decimal) -> Decimal` | R35 |
| `%Decimal.less`・`%Decimal.lessOrEqual`・`%Decimal.greater`・`%Decimal.greaterOrEqual` | `<`・`<=`・`>`・`>=` | 2 | `function(Decimal, Decimal) -> Boolean` | R35 |
| `%String.add` | `+` | 2 | `function(String, String) -> String` | R08 |
| `%String.less`・`%String.lessOrEqual`・`%String.greater`・`%String.greaterOrEqual` | `<`・`<=`・`>`・`>=` | 2 | `function(String, String) -> Boolean` | R08 |
| `%Character.less`・`%Character.lessOrEqual`・`%Character.greater`・`%Character.greaterOrEqual` | `<`・`<=`・`>`・`>=` | 2 | `function(Character, Character) -> Boolean` | R08 |
| `%Byte.less`・`%Byte.lessOrEqual`・`%Byte.greater`・`%Byte.greaterOrEqual` | `<`・`<=`・`>`・`>=` | 2 | `function(Byte, Byte) -> Boolean` | R35 |
| `%eq`・`%ne` | `=`・`<>` | 2 | `function[T: equality](T, T) -> Boolean` | R08 |

- 部分の中の順は、`OPERATORS` の順、続けて `%eq`・`%ne` である。
- `%eq`・`%ne` の本体は、構造の等しさ（10-08 の `runtime::equal::values_equal`）を使う。基本型の値は、その型の `=` で比べる（`Float` は IEEE 754、`Decimal` は数の等しさ）。
- `%Decimal.*` の本体は、F07 が `base::decimal` に書く算術（[ADR 0275](../../2026-10-09-design-first-release/decisions/0275-self-made-decimal-arithmetic.md)）を呼ぶ。

### 基本型のモジュール（`integer`・`float`・`character`・`string`・`boolean`・`byte`・`decimal`）

どれも権限が `Pure` で、種類が `Declared`（`%Boolean.toString` だけ `Interpolation`）である。

| 名前 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|
| `Integer.toString` | 1 | `function(Integer) -> String` | 01-04「型の変換」 | R08 |
| `Integer.parse` | 1 | `function(String) -> Option[Integer]` | 同上 | R08 |
| `Integer.toFloat` | 1 | `function(Integer) -> Float` | 同上 | R08 |
| `Integer.floorDivide` | 2 | `function(Integer, Integer) -> Integer` | 01-04「Integer」 | R08 |
| `Integer.floorModulo` | 2 | `function(Integer, Integer) -> Integer` | 同上 | R08 |
| `Integer.absolute` | 1 | `function(Integer) -> Integer` | 03-06「Integer」 | R08 |
| `Integer.minimum` | 2 | `function(Integer, Integer) -> Integer` | 同上 | R08 |
| `Integer.maximum` | 2 | `function(Integer, Integer) -> Integer` | 同上 | R08 |
| `Integer.bitwiseAnd`・`Integer.bitwiseOr`・`Integer.bitwiseExclusiveOr` | 2 | `function(Integer, Integer) -> Integer` | 01-04「ビット演算（初回リリース版）」 | R35 |
| `Integer.bitwiseNot` | 1 | `function(Integer) -> Integer` | 同上 | R35 |
| `Integer.shiftLeft`・`Integer.shiftRight`・`Integer.shiftRightUnsigned` | 2 | `function(Integer, Integer) -> Integer` | 同上 | R35 |
| `Float.toString`・`Float.parse`・`Float.truncate` | 1 | `function(Float) -> String`・`function(String) -> Option[Float]`・`function(Float) -> Option[Integer]` | 01-04「型の変換」 | R08 |
| `Float.isNaN` | 1 | `function(Float) -> Boolean` | 03-06「Float」 | R08 |
| `Float.absolute`・`Float.floor`・`Float.ceiling`・`Float.round`・`Float.squareRoot` | 1 | `function(Float) -> Float` | 同上 | R08 |
| `Character.toInteger` | 1 | `function(Character) -> Integer` | 01-04「Character」 | R08 |
| `Character.fromInteger` | 1 | `function(Integer) -> Option[Character]` | 同上 | R08 |
| `Character.toString` | 1 | `function(Character) -> String` | 同上 | R08 |
| `Character.isASCIIDigit`・`Character.isASCIIWhitespace` | 1 | `function(Character) -> Boolean` | 03-06「Character」 | R08 |
| `String.byteLength`・`String.characterCount` | 1 | `function(String) -> Integer` | 01-04「String」 | R08 |
| `String.byteSlice`・`String.characterSlice` | 3 | `function(String, Integer, Integer) -> Option[String]` | 同上 | R08 |
| `String.characterAt` | 2 | `function(String, Integer) -> Option[Character]` | 同上 | R08 |
| `String.isEmpty` | 1 | `function(String) -> Boolean` | 03-06「String」 | R08 |
| `String.contains`・`String.startsWith`・`String.endsWith` | 2 | `function(String, String) -> Boolean` | 同上 | R08 |
| `String.byteIndexOf` | 2 | `function(String, String) -> Option[Integer]` | 同上 | R08 |
| `String.split` | 2 | `function(String, String) -> List[String]` | 同上 | R08 |
| `String.lines` | 1 | `function(String) -> List[String]` | 同上 | R08 |
| `String.join` | 2 | `function(List[String], String) -> String` | 同上 | R08 |
| `String.trim` | 1 | `function(String) -> String` | 同上 | R08 |
| `String.replace` | 3 | `function(String, String, String) -> String` | 同上 | R08 |
| `String.repeat` | 2 | `function(String, Integer) -> String` | 同上 | R08 |
| `String.characters` | 1 | `function(String) -> List[Character]` | 同上 | R08 |
| `String.fromCharacters` | 1 | `function(List[Character]) -> String` | 同上 | R08 |
| `%Boolean.toString` | 1 | `function(Boolean) -> String` | 文字列補間の `Boolean`（`true`・`false`） | R08 |
| `Byte.fromInteger` | 1 | `function(Integer) -> Option[Byte]` | 01-04「Byte（初回リリース版）」 | R35 |
| `Byte.toInteger` | 1 | `function(Byte) -> Integer` | 同上 | R35 |
| `Byte.toString` | 1 | `function(Byte) -> String` | 同上 | R35 |
| `Byte.bitwiseAnd`・`Byte.bitwiseOr`・`Byte.bitwiseExclusiveOr` | 2 | `function(Byte, Byte) -> Byte` | 01-04「ビット演算（初回リリース版）」 | R35 |
| `Byte.bitwiseNot` | 1 | `function(Byte) -> Byte` | 同上 | R35 |
| `Byte.shiftLeft`・`Byte.shiftRight` | 2 | `function(Byte, Integer) -> Byte` | 同上 | R35 |
| `Decimal.round` | 3 | `function(Decimal, Integer, RoundingMode) -> Decimal` | 01-04「Decimal（初回リリース版）」 | R35 |
| `Decimal.absolute` | 1 | `function(Decimal) -> Decimal` | 同上 | R35 |
| `Decimal.fromInteger` | 1 | `function(Integer) -> Decimal` | 01-04「型の変換」 | R35 |
| `Decimal.truncate` | 1 | `function(Decimal) -> Option[Integer]` | 同上 | R35 |
| `Decimal.toFloat` | 1 | `function(Decimal) -> Float` | 同上 | R35 |
| `Decimal.fromFloat` | 1 | `function(Float) -> Option[Decimal]` | 同上 | R35 |
| `Decimal.toString` | 1 | `function(Decimal) -> String` | 同上 | R35 |
| `Decimal.parse` | 1 | `function(String) -> Option[Decimal]` | 同上 | R35 |

- 表の一つの行に複数の名前を挙げたものは、挙げた順に部分に並べる。`Float` の行の型は、名前と同じ順に対応する。
- 最小実行版の組み込みの関数からの名前の改め（`Integer.floorDiv` を `Integer.floorDivide` に、`Console.println` を `Console.writeLine` になど）は、03-06 の名前に合わせた。R08 は `src/legacy/builtins/` の意味を写し、名前は本章に従う。
- `Byte` と `Decimal` の項目を読む・作る関数は 10-08 の `ValueCtx::decimal`・`alloc_decimal`（`task=C02`）と `Value::Byte` を使う。`Decimal.round` は、引数の `RoundingMode` の値を `Value::Tag` のタグで読む（`tags::ROUNDING_MODE_*`）。

### リスト・マップ・集合（`list`・`map`・`set`）

どれも権限が `Pure` である。リストの表現は 10-08 の `runtime::list` の関数だけで扱い、マップと集合の表現は `runtime::map` の関数だけで扱う。

| 名前 | 種類 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|
| `List.length` | `Declared` | 1 | `function[T](List[T]) -> Integer` | 03-06「List」 | R08 |
| `List.isEmpty` | `Declared` | 1 | `function[T](List[T]) -> Boolean` | 同上 | R08 |
| `List.head` | `Declared` | 1 | `function[T](List[T]) -> Option[T]` | 同上 | R08 |
| `List.tail` | `Declared` | 1 | `function[T](List[T]) -> Option[List[T]]` | 同上 | R08 |
| `List.get` | `Declared` | 2 | `function[T](List[T], Integer) -> Option[T]` | 同上 | R08 |
| `List.prepend`・`List.append` | `Declared` | 2 | `function[T](List[T], T) -> List[T]` | 同上 | R08 |
| `List.concatenate` | `Declared` | 2 | `function[T](List[T], List[T]) -> List[T]` | 同上。リストの展開の脱糖も使う（ADR 0272） | R08 |
| `List.reverse` | `Declared` | 1 | `function[T](List[T]) -> List[T]` | 同上 | R08 |
| `List.take`・`List.drop` | `Declared` | 2 | `function[T](List[T], Integer) -> List[T]` | 同上 | R08 |
| `List.range` | `Declared` | 2 | `function(Integer, Integer) -> List[Integer]` | 同上 | R08 |
| `List.contains` | `Declared` | 2 | `function[T: equality](List[T], T) -> Boolean` | 同上。比べ方は `%eq` と同じ | R08 |
| `List.sort` | `Declared` | 1 | `function[T: ordered](List[T]) -> List[T]` | 同上 | R08 |
| `%List.length` | `ListPattern` | 1 | `function[T](List[T]) -> Integer` | 長さ | R08 |
| `%List.getFront`・`%List.getBack` | `ListPattern` | 2 | `function[T](List[T], Integer) -> T` | 前から・後ろから 0 で数えた位置の要素 | R08 |
| `%List.slice` | `ListPattern` | 3 | `function[T](List[T], Integer, Integer) -> List[T]` | 前の n 個と後の m 個を除いた部分 | R08 |
| `Map.empty` | `Declared` | 0 | `function[K: key, V]() -> Map[K, V]` | 03-06「Map と Set（初回リリース版）」 | R37 |
| `Map.fromList` | `Declared` | 1 | `function[K: key, V](List[Pair[K, V]]) -> Map[K, V]` | 同上 | R37 |
| `Map.toList` | `Declared` | 1 | `function[K: key, V](Map[K, V]) -> List[Pair[K, V]]` | 同上 | R37 |
| `Set.empty` | `Declared` | 0 | `function[T: key]() -> Set[T]` | 同上 | R37 |
| `Set.fromList` | `Declared` | 1 | `function[T: key](List[T]) -> Set[T]` | 同上 | R37 |
| `Set.toList` | `Declared` | 1 | `function[T: key](Set[T]) -> List[T]` | 同上 | R37 |

- `%List.*` の項目は、判定の木が長さを確かめた後にだけ呼ばれる（10-06「判定の木への変換」）。位置は、コード生成が `LOADK` した `Integer` の値で渡す（10-07「コード生成」）。
- `Map` と `Set` のうち U1・U2 に置くのは、定数式に書ける `Map.empty`・`Map.fromList`・`Set.empty`・`Set.fromList`（01-02「定数（初回リリース版）」、10-04 の定数の検査）と、その値をテストで確かめるための `Map.toList`・`Set.toList` だけである。定数式は U1 の機能なので、名前解決と型検査がこれらの束縛を要る。残りの関数（`Map.get` など）は U3 が加える。本体は、マップと集合の表現を作る R37 が書く。

### IO の失敗と、ランタイムに結び付いた関数（`io_error`・`reference`・`lazy`・`task`・`task_group`）

| 名前 | 権限 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|
| `IOError.message` | `Pure` | 1 | `function(IOError) -> String` | 01-07「IO の失敗」 | R08 |
| `IOError.kind` | `Pure` | 1 | `function(IOError) -> IOErrorKind` | 01-09「IO の失敗の種類」 | R29 |
| `Reference.new` | `State` | 1 | `function[T](T) -> Reference[T] uses State` | 01-07「可変のセル（初回リリース版）」 | R23 |
| `Reference.get` | `State` | 1 | `function[T](Reference[T]) -> T uses State` | 同上 | R23 |
| `Reference.set` | `State` | 2 | `function[T](Reference[T], T) -> Unit uses State` | 同上 | R23 |
| `Reference.update` | `State` | 2 | `function[T](Reference[T], function(T) -> T) -> Unit uses State` | 同上。専用の命令 `UPDATE`（`Intrinsic::Update`） | R29 |
| `Lazy.force` | `Pure` | 1 | `function[T](Lazy[T]) -> T` | 01-08「明示遅延（初回リリース版）」。専用の命令 `FORCE`（`Intrinsic::Force`） | R29 |
| `Task.all` | `State` | 1 | `function[T, effect E](List[function() -> T uses E]) -> List[T] uses E` | 01-11「タスクを起動する関数」 | R25 |
| `Task.allOk` | `State` | 1 | `function[T, X, effect E](List[function() -> Result[T, X] uses E]) -> Result[List[T], X] uses E` | 同上 | R39 |
| `Task.race` | `State` | 1 | `function[T, effect E](List[function() -> T uses E]) -> Option[T] uses Clock.Time, State, E` | 同上 | R39 |
| `Task.withTimeout` | `State` | 2 | `function[T, effect E](Integer, function() -> T uses E) -> Option[T] uses Clock.Time, State, E` | 同上 | R39 |
| `Task.await` | `State` | 1 | `function[T](Task[T]) -> T uses State` | 01-11「タスクの集まり」 | R25 |
| `TaskGroup.open` | `State` | 0 | `function() -> TaskGroup uses State` | 同上。`with` の束縛の式としてだけ書ける（型検査が確かめる） | R25 |
| `TaskGroup.spawn` | `State` | 2 | `function[T, effect E](TaskGroup, function() -> T uses E) -> Task[T] uses State, E` | 同上 | R25 |

- タスクを起動する関数（`Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout`・`TaskGroup.spawn`）は、`StateReply::SpawnTasks` を返し、10-11 の `SpawnMode`（`All`・`AllOk`・`Race`・`WithTimeout`・`GroupSpawn`）で待ち方を指定する。起動の後の待ち方と結果の組み立ては、共通の部分（10-09・10-10）が行う。型に `State` を書かない関数（`Task.all` など）も、権限は `State` である（02-06「下位 IR からコード生成へ渡すもの」の「呼び出しの種類」）。
- `Reference.new`・`get`・`set` は、10-08 の `alloc_cell`・`cell_get`・`cell_set` を使う。`Reference.update` と `Lazy.force` の `raw` は `Stop::Internal` を返す（前述の「項目の種類」）。
- `IOError.kind` は、`IOError` の値の `tag` を `Value::Tag(CtorTag(tag))` にして返す。

### 標準の型クラスの補助（`traits`）

| 名前 | 権限 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|
| `Trait.showString` | `Pure` | 1 | `function(String) -> String` | `Show[String]` の `show`。文字列リテラルの形（03-06「標準の型クラス（初回リリース版）」の `Show.show`、01-01 のエスケープ） | R08 |
| `Trait.showCharacter` | `Pure` | 1 | `function(Character) -> String` | `Show[Character]` の `show`。文字リテラルの形 | R08 |

この二つは `Benitoite.Trait` の公開しない関数であり、`Show` の実装だけが使う。エスケープシーケンスの規則をソースで書くと長くなるので、組み込みの関数にした。

### IO のモジュール（`console`・`file`・`process`・`clock`）

`IO.File.closeReader` のほかは組み込みのエフェクトの操作であり、権限が `Io`、種類が `EffectOp` である。意味は [IO のモジュール](../../2026-10-09-design-first-release/03-interop/03-07-io-modules.md)で定める。U2 に置くのは、[ADR 0273](../../2026-10-09-design-first-release/decisions/0273-u2-u3-boundary-for-runtime-builtins.md) の決定 1 のとおり、最小実行版のテスト（C03 が書き直し、C05 が走らせる）と OPEN-062 の再現テスト（R30）と IO の方式のテスト（R31）が呼ぶものだけである。

| 名前 | 権限 | 引数 | 型 | 使うテスト | 作業 |
|---|---|---|---|---|---|
| `Benitoite.IO.Console.write` | `Io` | 1 | `function(String) -> Unit uses Console.Write` | OPEN-062 R04・R13 | R08 |
| `Benitoite.IO.Console.writeLine` | `Io` | 1 | 同上 | 最小実行版のテスト | R08 |
| `Benitoite.IO.Console.writeError` | `Io` | 1 | 同上 | 標準エラー出力のテスト | R08 |
| `Benitoite.IO.Console.writeErrorLine` | `Io` | 1 | 同上 | 最小実行版のテスト | R08 |
| `Benitoite.IO.Console.readLine` | `Io` | 0 | `function() -> Result[Option[String], IOError] uses Console.Read` | OPEN-062 R13 | R29 |
| `Benitoite.IO.Console.readAll` | `Io` | 0 | `function() -> Result[String, IOError] uses Console.Read` | IO の方式のテスト | R29 |
| `Benitoite.IO.File.readText` | `Io` | 1 | `function(String) -> Result[String, IOError] uses File.Read` | 最小実行版のテスト、OPEN-062 R02 | R08 |
| `Benitoite.IO.File.writeText` | `Io` | 2 | `function(String, String) -> Result[Unit, IOError] uses File.Write` | IO の方式のテスト | R29 |
| `Benitoite.IO.File.appendText` | `Io` | 2 | `function(String, String) -> Result[Unit, IOError] uses File.Write` | IO の方式のテスト | R29 |
| `Benitoite.IO.File.openReader` | `Io` | 1 | `function(String) -> Result[File.Reader, IOError] uses File.Read` | OPEN-062 R05、リソースのテスト | R29 |
| `Benitoite.IO.File.readLine` | `Io` | 1 | `function(File.Reader) -> Result[Option[String], IOError] uses File.Read` | OPEN-062 R05 | R29 |
| `IO.File.closeReader` | `State` | 1 | `function(File.Reader) -> Result[Unit, IOError] uses State` | リソースの解放のテスト | R29 |
| `Benitoite.IO.Process.arguments` | `Io` | 0 | `function() -> List[String] uses Process.Environment` | 最小実行版のテスト | R08 |
| `Benitoite.IO.Process.exit` | `Io` | 1 | `function[T](Integer) -> T uses Process.Exit` | 止める手順のテスト（R28・R31） | R29 |
| `Benitoite.IO.Clock.sleep` | `Io` | 1 | `function(Integer) -> Unit uses Clock.Time` | タスクと時間の待ち（ADR 0273） | R29 |
| `Benitoite.IO.Clock.monotonicMilliseconds` | `Io` | 0 | `function() -> Integer uses Clock.Time` | 時間の待ちの長さの確かめ | R29 |

- 最小実行版の IO の関数（`Console.print`・`println`・`eprintln`、`File.readText`、`Process.args`）は、名前を改めて R08 が第 1 段で移す。第 1 段の `IoServices` は一時的な実装である（10-11「作業の割り当て」）。
- 標準入力を読む関数（`Console.readLine`・`readAll`）は、`WorkerWait::after_output_flush` と `Lend::Stdin` を使う（10-11「作業用のスレッドの仕事」）。`File.readLine` は `Lend::Resource` でリソースを借りる。`File.openReader` の完了の処理は `IoServices::register_resource` でリソースを表に加える。`IO.File.closeReader` は `StateServices::begin_release` で解放を始める。
- `Process.exit` は `IoReply::Exit` を返す。終了状態の値の扱い（範囲の外の値）は 03-07「Process」に従う。
- 残りの IO の関数（`Console.readAllLines`、`File.Writer` の関数、ディレクトリの操作、`Process.run`、`Clock.now`、`Random` など）は U3 が加える。本節の関数は、属するモジュール（`Benitoite.IO.Console`・`File`・`Process`・`Clock`）とともに非公式から始める（[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md)。ADR 0273 の決定 3 が U3 の実装プランに委ねた点）。スクリプトは `import Benitoite.Unofficial.IO.Console` の形で取り込む。

## 10-06 との対応

[中間表現](10-06-ir.md)の「10-12 に求めるもの」の各項目を、本章は次のように満たす。

| 10-06 が求めるもの | 本章で満たすもの |
|---|---|
| 項目ごとの権限 | `builtin_decl(id)` の `BuiltinDecl::capability` |
| 項目ごとの専用の命令 | `builtin_intrinsic` |
| 演算子の項目の引き方と `eq`・`ne` の項目 | `operator_builtin`・`equality_builtin`（`OPERATORS`・`EQUALITY`・`INEQUALITY`） |
| `str_T` の項目 | `interpolation_builtin`（`INTERPOLATION`）。`Integer.toString` など、ソースに同じ意味の関数があるものはその項目を返す |
| リストのパターンの内部の項目 | `list_pattern_builtin`（`LIST_PATTERN`） |
| 項目ごとの宣言の型と引数の数 | 引数の数は `BuiltinDecl::arity`。宣言の型は、ソースに宣言のない項目は `builtin_scheme`、`Declared`・`EffectOp` の項目は `BuiltinInfo::decl` の束縛のソースの宣言の型（型検査の `decl_types` の写しの `Program::schemes`） |
| 項目ごとの修飾した名前 | `BuiltinDecl::name` |

- 脱糖は、文字列補間の `str_T` を `interpolation_builtin` で引き、`ValKind::Builtin` にする。U1・U2 の範囲では、補間の型のどれにも組み込みの関数の項目がある。
- 検査器（F13）は、`Declared`・`EffectOp` の項目の `ValKind::Builtin` を、10-06 の `BuiltinInfo::decl`（脱糖が名前解決の表から埋める宣言の束縛）の宣言の型で型付けする。本章の関数は、項目の番号から束縛への対応を持たない。
- `Lazy.force` と `Reference.update` の `raw` は `Stop::Internal` を返すので、参照インタプリタ（F14）は、`intrinsic` が `Force`・`Update` の適用を `raw` で呼ばず、01-12 の遷移のとおりに実行する。

## 確かめること

| テスト | 書く作業 | 内容 |
|---|---|---|
| 表の形 | R08 | 名前が重ならない。すべての項目の名前が本章の「名前の付け方」の形に合う。`builtin_decl(lookup_builtin(n))` の名前が `n` になる。権限が `Io` の項目と名前が `Benitoite.` から始まる項目が一致する。`OPERATORS`・`EQUALITY`・`INEQUALITY`・`INTERPOLATION`・`LIST_PATTERN`・`INTRINSIC_FUNCTIONS` のすべての名前が表にある。`builtin_scheme` が、ソースに宣言のない項目にだけ型を返し、その引数の数が `arity` と一致する。部分の数と各部分の項目の数が本章の「部分の一覧」と一致する |
| 項目ごとの単体テスト | 本体を書く作業（R08・R23・R25・R29・R35・R37・R39） | 項目ごとに、本体の関数（`builtin!` が作る名前の付いた関数）を直接呼んで、設計書の意味どおりの値と実行時エラーを確かめる。組み込みの関数の正しさは差分テストでは確かめられないので、このテストで確かめる（ADR 0276 の決定 4）。R25・R39 の七つの項目は例外とし、スクリプトのテストで確かめる（[ADR 0284](../../2026-10-09-design-first-release/decisions/0284-task-builtins-tested-by-scripts.md)） |
| ソースと表の照合 | F06 | 標準ライブラリのソース（10-14）のすべての `@builtin` の名前と組み込みのエフェクトの操作が表にあり、`@builtin` の名前が `Benitoite.`・`%` から始まらない。宣言の引数の数が `arity` と一致する。操作の項目の権限が `Io` であり、`Declared` の項目の権限が `Io` でない。権限が `Pure` の項目の宣言の `uses` が、エフェクトの名前を含まない（エフェクト変数だけか、ない）。逆に、表の `Declared`・`EffectOp` の項目は、どれもソースのちょうど一つの宣言から参照される。`tags` の定数が、ソースの構成子の宣言の順と一致する |

仮の本体の項目があっても、上のテストは通る。仮の本体は名前・権限・引数の数が正しいからである。

## 作業ごとの項目の数

| 作業 | `Pure` | `State` | `Io` | 計 |
|---|---|---|---|---|
| R08（第 1 段。表の全体と、仮の本体を含む宣言も置く） | 92 | 0 | 6 | 98 |
| R23（`Reference` のセルを作り読み書きする関数） | 0 | 3 | 0 | 3 |
| R25（タスクを起動し待つ関数と `TaskGroup`） | 0 | 4 | 0 | 4 |
| R29（第 2 段。残りのランタイムに結び付いた関数と、最小限の IO） | 2 | 2 | 9 | 13 |
| R39（取り消しを伴う、タスクを起動し待つ関数） | 0 | 3 | 0 | 3 |
| R35（`Decimal`・`Byte`・ビット演算） | 37 | 0 | 0 | 37 |
| R37（`Map`・`Set`） | 6 | 0 | 0 | 6 |
| 計 | 137 | 12 | 15 | 164 |

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C01 | `table.rs` の構成子のタグ（`task=C01` の `sig=`）を凍結する |
| C02 | `table.rs` の項目の種類と表を引く関数（`sig=`）を凍結する |
| R07 | 構成子のタグ（`table::tags`）を写して置く |
| R08 | `funcs/mod.rs` の `PARTS` と、本章の 21 の部分のすべての項目の宣言（本体を書かない項目は仮の本体）。R08 の項目の本体と単体テスト。`builtin_decl`・`lookup_builtin` と、C02 のブロックの関数と定数。表の形のテスト。依存に C02 を加える |
| R23 | R23 の項目の本体と単体テスト（仮の本体を置き換える） |
| R25 | R25 の項目の本体（仮の本体を置き換える）。四つは応答を組み立てるだけで、意味は応答を受けた VM の処理にあるので、項目ごとの単体テストは書かず、R25 の受け入れテストのスクリプトが各項目を呼んで確かめる（[相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 9、[ADR 0284](../../2026-10-09-design-first-release/decisions/0284-task-builtins-tested-by-scripts.md)） |
| R39 | R39 の項目の本体（仮の本体を置き換える）。三つも応答を組み立てるだけなので、項目ごとの単体テストは独立した境界条件を持つもの（`Task.withTimeout` の期限の正規化）に限り、ほかは R39 の受け入れテストのスクリプトが各項目を呼んで確かめる（同上） |
| R29 | R29 の項目の本体と単体テスト（仮の本体を置き換える） |
| R35 | R35 の項目の本体と単体テスト |
| R37 | R37 の項目の本体と単体テスト |
| F06 | 名前解決で `@builtin` と操作を表で引く（10-04）。ソースと表の照合のテスト |
| F11 | `builtin_intrinsic`・`operator_builtin`・`equality_builtin`・`interpolation_builtin` を使う |
| F13 | `builtin_scheme` を使う |
| F15 | `list_pattern_builtin` を使う |
