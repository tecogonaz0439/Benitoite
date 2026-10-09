# 標準ライブラリのソース

本章は、標準ライブラリのソース（言語で書き、処理系に埋め込むモジュール）の置き方と、U1・U2 の範囲のソースの全文を与える。[標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「標準ライブラリのソースの書き方」が「標準ライブラリのソースの関数の定義そのものは、実装プランで与える」とした部分である。置き方は[名前解決とモジュール読込](../../design/02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」に、名前空間と prelude は [ADR 0128](../../design/decisions/0128-prelude-and-benitoite-namespace.md) に、組み込みの関数の宣言の形は [ADR 0157](../../design/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md) に、標準の型クラスは [ADR 0134](../../design/decisions/0134-standard-type-classes.md) に従う。ソースは[構文](../../design/01-spec/01-02-syntax.md)の「初回リリース版の文法の全体」で書く。

- 置く作業: C02

本章は U1 が持つ。U2 のランタイムに結び付いた関数と最小限の IO（[ADR 0273](../../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md)）の宣言も本章に置く。名前解決は prelude のソースをどの検査でも読むので、宣言は U1 の名前解決（F06）より前に揃っている必要があるからである。U3 は、本章にモジュールと宣言を足す。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。標準ライブラリのソースは `text file=` の見出しで示し、C02 がそのままファイルに置く。

## 置く作業と既存のファイル

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/prelude/mod.rs` | 置く（`file=`）。モジュールの一覧の表 | — |
| `src/prelude/stdlib/` の下の `.bnt` | 置く（`text file=`）。本章のソースの全文 | — |

最小実行版の prelude（`src/prelude/`。`list.bnt`・`option.bnt`・`result.bnt` と、ファイルの名前と内容の表）は、C04 が `src/legacy/prelude/` へ移す。本章のファイルは、空いたパスに新しく置く。最小実行版のソースは古い構文で書いてあり、名前も初回リリース版と違う（`List.dropFirst` など）ので、写さない。

本章のソースは、処理系の実装を始める前に書いたものである。F05 以降の作業が、本章のソースを読んで誤り（構文の誤り、型の誤り、03-06 の定義との食い違い）を見つけたときは、ソースを直さずに作業を止めて報告する（[作業の進め方](../00-common/00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。ソースは本章で凍結したインターフェースの一部であり、直すと表（10-12）の照合や、ほかの作業のテストに影響するからである。ただし、正規形のテスト（D02）で、整形で変わるのが空白（字下げ・空の行・字句の間の空白）だけなら、`format_source` の結果で標準ライブラリのソースと 10-14・10-15 の写しを直してよい（字句と型は変わらない）。直したファイルを完了の報告に書く。

## 置き方

### ファイルとモジュールの名前

- 標準ライブラリの根のディレクトリを `src/prelude/stdlib/` とする。モジュール `Benitoite.X.Y` のソースは `src/prelude/stdlib/X/Y.bnt` に置く（02-04「標準ライブラリのソースの持ち方」）。
- ソースは `include_str!` で処理系に埋め込み、`src/prelude/mod.rs` の表 `STDLIB`（要素は 10-04 の `StdlibModuleSource`）から引く。表は、モジュールの名前の段（`Benitoite` を除く）、prelude に入るか、非公式のモジュールか、ソースの内容を持つ。読み込みの段（F05）が表を引き、表示名 `<benitoite>/X/Y.bnt` を組み立てる（10-04「読み込みの段」）。
- 表の順は、読み込みの段が prelude のモジュールをソースの表に置く順である（10-04 の `load_program`）。したがって、表の順がモジュールの ID と束縛の番号の振り方を決める。項目は末尾にだけ加える。U3 が prelude のモジュールを加えるときも末尾に加える。

### prelude と `Benitoite` の名前空間

- prelude のモジュールは、import なしで `X` と、`Benitoite.X` とも書ける。prelude でないモジュールは、取り込んだときだけ読む（02-04「標準ライブラリのソースの持ち方」、[ADR 0156](../../design/decisions/0156-module-loading-and-whole-program-checking.md)）。標準のモジュールは `import Benitoite.X.Y` で、非公式のモジュール（`unofficial` が真）は `import Benitoite.Unofficial.X.Y` で取り込む（03-06「標準のモジュールと非公式のモジュール（初回リリース版）」、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。
- 表の `path`、ソースの置き場所、組み込みの型とエフェクトの表（10-05）、組み込みの関数の表の名前（10-12）は、非公式のモジュールでも標準に加えた後の名前（`IO.Console`）で書く。非公式のモジュールを標準に移すときは、表の `unofficial` を偽にし、そのモジュールを取り込む標準ライブラリのソースの import の行を改める。
- 組み込みの型（`Integer`・`List`・`Task` など）はソースに宣言を置かず、10-05 の組み込みの型の表から、属するモジュールのトップレベルの型として束縛を作る。束縛を作るには、そのモジュールが読まれていなければならない。そのため、組み込みの型だけを持ち関数を持たないモジュール（`Boolean`・`IO`）にも、説明のコメントだけのソースを置く。
- `Unit` と `State` は `Benitoite` の直下の prelude の名前であり、モジュールを持たない。`IO.All` は prelude のモジュール `Benitoite.IO` のエフェクトとして、組み込みのエフェクトの表から束縛を作る（10-05「組み込みの型とエフェクトの表」）。
- prelude のモジュールが prelude でないモジュールを使うときは、利用者のモジュールと同じく import する。U1・U2 の範囲では、`Task` の関数の型に `Clock.Time` を書くために、`Benitoite.Task` が `Benitoite.IO.Clock` を取り込む（非公式のモジュールなので、import の行は `import Benitoite.Unofficial.IO.Clock`）。そのため、`Benitoite.IO.Clock` はどの検査でも読まれる。prelude のモジュールへの import の辺はないので、この取り込みで循環は起きない（02-04「依存グラフと循環の検出」）。

### 書き方の方針

- 利用者から見える関数・型・型クラス・エフェクトに `public` を付ける。補助の関数は `public` を付けずに書く（03-06「標準ライブラリのソースの書き方」）。
- 組み込みの関数は、本体のない関数の宣言に `@builtin("名前")` を付けて宣言する。名前は、10-12 の表の名前（モジュールの名前から `Benitoite.` を除いた段と関数の名前をつないだもの）である。組み込みのエフェクト（`Console.Write` など）は普通のエフェクトの宣言として書き、操作に `@builtin` を付けない。操作は、10-12 の表で `Benitoite.` から始まる名前で引く。
- 同じモジュールの関数・型・エフェクトは修飾せずに書き、ほかのモジュールのものはモジュールの名前で修飾する（`Option.Some`、`List.get`）。構成子は型の名前で修飾する（`Option.Some`）。ただし、構成子が一つで型と同じ名前のもの（`Pair`・`Triple`）は修飾しない（01-05「prelude が定める型」）。
- 構成子の宣言の順は、10-12 の `table::tags` の値を決める。`Option` は `Some`・`None`、`Result` は `Ok`・`Error` の順とし、`IOErrorKind` と `RoundingMode` は設計書の表の順とする。順を変えると 10-12 の照合のテスト（F06）が失敗する。
- 関数を引数にとる関数は、受け取った関数を要素の先頭から順に一つずつ呼び、長さに比例する深さの末尾でない再帰を使わない（03-06「関数を引数にとる関数の共通の規則」）。リストを辿る処理は、添字を累積の引数に持つ末尾再帰で書き、`List.get` で要素を取り出し、結果のリストは `List.append` で末尾に加えて作る（03-06「標準ライブラリのソースの書き方」）。この書き方は要素ごとに `Option` の値を一つ作るので O(n log n) になる。要素を順に取り出す内部の組み込みの関数で O(n) にする最適化は、測定の後に U3 で決める。
- 引数の名前にキーワード（`end`・`data`・`type` など。01-01「キーワード」）を使わない。範囲の終わりの引数は、設計書の表（01-04・03-06）と同じく `stop` とする（`List.range(start, stop)`、`String.byteSlice(s, start, stop)` など）。
- 説明は、利用者のモジュールと同じくドキュメントコメント（`///`・`//!`）で書く（03-06「範囲と名前の付け方」、[ADR 0125](../../design/decisions/0125-doc-comments.md)）。説明は MCP サーバと LSP サーバが利用者に示すものなので、処理系の診断の文言と同じく英語で書く。意味の詳しい定めは設計書にあり、説明は一行か二行に要約する。
- 03-06 の表で型の欄に `function[T, effect E](…)` と書いた関数は、宣言の型パラメータの並び（`[T, effect E]`）で同じ型を書く。

## モジュールの一覧

U1・U2 で置くモジュールは次のとおりである。「組み込み」の欄は、10-12 の表の部分である。

| 順 | モジュール | prelude | 中身 | 組み込み（10-12 の部分） |
|---|---|---|---|---|
| 1 | `Benitoite.Integer` | 入る | 組み込みの関数だけ | `integer` |
| 2 | `Benitoite.Float` | 入る | 同上 | `float` |
| 3 | `Benitoite.Decimal` | 入る | 同上 | `decimal` |
| 4 | `Benitoite.RoundingMode` | 入る | 型 `RoundingMode` | — |
| 5 | `Benitoite.Byte` | 入る | 組み込みの関数だけ | `byte` |
| 6 | `Benitoite.Character` | 入る | 同上 | `character` |
| 7 | `Benitoite.String` | 入る | 同上 | `string` |
| 8 | `Benitoite.Boolean` | 入る | 説明だけ（型 `Boolean` は組み込み） | — |
| 9 | `Benitoite.List` | 入る | 組み込みの関数と、関数を引数にとる関数 | `list` |
| 10 | `Benitoite.Map` | 入る | 定数式に書ける関数と `toList` | `map` |
| 11 | `Benitoite.Set` | 入る | 同上 | `set` |
| 12 | `Benitoite.Option` | 入る | 型 `Option` と関数 | — |
| 13 | `Benitoite.Result` | 入る | 型 `Result` と関数 | — |
| 14 | `Benitoite.Pair` | 入る | 型 `Pair` と関数 | — |
| 15 | `Benitoite.Triple` | 入る | 型 `Triple` と関数 | — |
| 16 | `Benitoite.IOError` | 入る | 組み込みの関数だけ | `io_error` |
| 17 | `Benitoite.IOErrorKind` | 入る | 型 `IOErrorKind` | — |
| 18 | `Benitoite.Reference` | 入る | 組み込みの関数だけ | `reference` |
| 19 | `Benitoite.Lazy` | 入る | 同上 | `lazy` |
| 20 | `Benitoite.Task` | 入る | 同上 | `task` |
| 21 | `Benitoite.TaskGroup` | 入る | 同上 | `task_group` |
| 22 | `Benitoite.IO` | 入る | 説明だけ（`IO.All` は組み込み） | — |
| 23 | `Benitoite.IO.Clock`（非公式） | 入らない | エフェクト `Clock.Time` | `clock` |
| 24 | `Benitoite.IO.Console`（非公式） | 入らない | エフェクト `Console.Write`・`Console.Read` | `console` |
| 25 | `Benitoite.IO.File`（非公式） | 入らない | エフェクト `File.Read`・`File.Write` と `closeReader` | `file` |
| 26 | `Benitoite.IO.Process`（非公式） | 入らない | エフェクト `Process.Environment`・`Process.Exit` | `process` |
| 27 | `Benitoite.Trait` | 入らない | 標準の型クラス、`Ordering`、標準の型の実装 | `traits` |

03-06「名前空間と prelude（初回リリース版）」の prelude のうち、`Bytes`・`ByteOrder`・`NetworkError`・`NetworkErrorKind`・`Assert` のモジュールは、U3（`Assert` は U3・U4）が加える。IO のモジュールの残りの関数、`Benitoite.IO.Random`、テキストとデータのモジュール、`Benitoite.Network.Http` も U3 が加える。U1・U2 の範囲にこれらの名前はないので、U1・U2 のテストはこれらを使わない。「（非公式）」を付けたモジュールは非公式のモジュールであり、ほかは標準のモジュールである（ADR 0286）。U3 が加える prelude のモジュールと `Benitoite.Trait` の関数は標準、IO・ネットワーク・テキストとデータのモジュールは非公式とする。`Benitoite.Trait` の実装のうち、`Map`・`Set` の `Show`・`Semigroup`・`Monoid` は、`Map`・`Set` の関数を加える U3 が加える。

組み込みの型の表（10-05）の型のうち、属するモジュールが上の一覧にない型（`Bytes`・`NetworkError`・`Random.Generator` など）は、U1・U2 では束縛が作られない。`File.Writer` は、`Benitoite.IO.File` を置くので束縛が作られるが、U1・U2 にはそれを使う関数がない。

## モジュールの一覧の表

```rust file=src/prelude/mod.rs needs=10-04
//! 標準ライブラリのソース（設計書 02-04「標準ライブラリのソースの持ち方」、03-06「標準ライブラリのソースの書き方」、
//! ADR 0128・0157）。`stdlib/` の下のソースを `include_str!` で処理系に埋め込む。
//! 表示名 `<benitoite>/X/Y.bnt` は、読み込みの段が `path` から組み立てる（実装プラン 10-04「読み込みの段」）。

use crate::modules::StdlibModuleSource;

/// 処理系に埋め込んだ標準ライブラリのモジュール（実装プラン 10-14「モジュールの一覧」）。
/// 読み込みの段は、prelude のモジュールをこの順にソースの表に置く。項目は末尾にだけ加える。
pub const STDLIB: &[StdlibModuleSource] = &[
    StdlibModuleSource {
        path: &["Integer"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Integer.bnt"),
    },
    StdlibModuleSource {
        path: &["Float"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Float.bnt"),
    },
    StdlibModuleSource {
        path: &["Decimal"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Decimal.bnt"),
    },
    StdlibModuleSource {
        path: &["RoundingMode"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/RoundingMode.bnt"),
    },
    StdlibModuleSource {
        path: &["Byte"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Byte.bnt"),
    },
    StdlibModuleSource {
        path: &["Character"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Character.bnt"),
    },
    StdlibModuleSource {
        path: &["String"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/String.bnt"),
    },
    StdlibModuleSource {
        path: &["Boolean"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Boolean.bnt"),
    },
    StdlibModuleSource {
        path: &["List"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/List.bnt"),
    },
    StdlibModuleSource {
        path: &["Map"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Map.bnt"),
    },
    StdlibModuleSource {
        path: &["Set"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Set.bnt"),
    },
    StdlibModuleSource {
        path: &["Option"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Option.bnt"),
    },
    StdlibModuleSource {
        path: &["Result"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Result.bnt"),
    },
    StdlibModuleSource {
        path: &["Pair"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Pair.bnt"),
    },
    StdlibModuleSource {
        path: &["Triple"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Triple.bnt"),
    },
    StdlibModuleSource {
        path: &["IOError"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/IOError.bnt"),
    },
    StdlibModuleSource {
        path: &["IOErrorKind"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/IOErrorKind.bnt"),
    },
    StdlibModuleSource {
        path: &["Reference"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Reference.bnt"),
    },
    StdlibModuleSource {
        path: &["Lazy"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Lazy.bnt"),
    },
    StdlibModuleSource {
        path: &["Task"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Task.bnt"),
    },
    StdlibModuleSource {
        path: &["TaskGroup"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/TaskGroup.bnt"),
    },
    StdlibModuleSource {
        path: &["IO"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/IO.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Clock"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Clock.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Console"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Console.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "File"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/File.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Process"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Process.bnt"),
    },
    StdlibModuleSource {
        path: &["Trait"],
        prelude: false,
        unofficial: false,
        text: include_str!("stdlib/Trait.bnt"),
    },
];
```

## 基本型のモジュール

基本型の関数は、どれも組み込みの関数である（03-06「Integer」〜「String」、01-04）。

```text file=src/prelude/stdlib/Integer.bnt
//! Functions on `Integer`, the 64-bit signed integer type.

/// Returns the decimal representation of `n`, with a leading `-` when negative.
@builtin("Integer.toString")
public function toString(n: Integer) -> String

/// Reads a decimal integer. Returns `Option.None` when `s` is not an integer or is out of range.
@builtin("Integer.parse")
public function parse(s: String) -> Option[Integer]

/// Returns the `Float` nearest to `n`.
@builtin("Integer.toFloat")
public function toFloat(n: Integer) -> Float

/// Divides and rounds the quotient toward negative infinity. Stops the program when `b` is 0.
@builtin("Integer.floorDivide")
public function floorDivide(a: Integer, b: Integer) -> Integer

/// Returns the remainder whose sign follows `b`. Stops the program when `b` is 0.
@builtin("Integer.floorModulo")
public function floorModulo(a: Integer, b: Integer) -> Integer

/// Returns the absolute value. Stops the program when `n` is the smallest `Integer`.
@builtin("Integer.absolute")
public function absolute(n: Integer) -> Integer

/// Returns the smaller of `a` and `b`.
@builtin("Integer.minimum")
public function minimum(a: Integer, b: Integer) -> Integer

/// Returns the larger of `a` and `b`.
@builtin("Integer.maximum")
public function maximum(a: Integer, b: Integer) -> Integer

/// Returns the bitwise AND.
@builtin("Integer.bitwiseAnd")
public function bitwiseAnd(a: Integer, b: Integer) -> Integer

/// Returns the bitwise OR.
@builtin("Integer.bitwiseOr")
public function bitwiseOr(a: Integer, b: Integer) -> Integer

/// Returns the bitwise exclusive OR.
@builtin("Integer.bitwiseExclusiveOr")
public function bitwiseExclusiveOr(a: Integer, b: Integer) -> Integer

/// Inverts all bits.
@builtin("Integer.bitwiseNot")
public function bitwiseNot(a: Integer) -> Integer

/// Shifts left by `n` bits, filling the low bits with 0.
@builtin("Integer.shiftLeft")
public function shiftLeft(a: Integer, n: Integer) -> Integer

/// Shifts right by `n` bits, filling the high bits with the sign bit.
@builtin("Integer.shiftRight")
public function shiftRight(a: Integer, n: Integer) -> Integer

/// Shifts right by `n` bits, filling the high bits with 0.
@builtin("Integer.shiftRightUnsigned")
public function shiftRightUnsigned(a: Integer, n: Integer) -> Integer
```

```text file=src/prelude/stdlib/Float.bnt
//! Functions on `Float`, the IEEE 754 double-precision type.

/// Returns the text representation of `x`.
@builtin("Float.toString")
public function toString(x: Float) -> String

/// Reads a decimal number. Returns `Option.None` when `s` is not a number.
@builtin("Float.parse")
public function parse(s: String) -> Option[Float]

/// Rounds toward zero. Returns `Option.None` for NaN, infinities, and values out of the `Integer` range.
@builtin("Float.truncate")
public function truncate(x: Float) -> Option[Integer]

/// Returns whether `x` is NaN.
@builtin("Float.isNaN")
public function isNaN(x: Float) -> Boolean

/// Returns `x` with a positive sign.
@builtin("Float.absolute")
public function absolute(x: Float) -> Float

/// Returns the largest integral value not greater than `x`.
@builtin("Float.floor")
public function floor(x: Float) -> Float

/// Returns the smallest integral value not less than `x`.
@builtin("Float.ceiling")
public function ceiling(x: Float) -> Float

/// Returns the nearest integral value, rounding halves away from zero.
@builtin("Float.round")
public function round(x: Float) -> Float

/// Returns the square root. Negative numbers give NaN.
@builtin("Float.squareRoot")
public function squareRoot(x: Float) -> Float
```

```text file=src/prelude/stdlib/Decimal.bnt
//! Functions on `Decimal`, the 128-bit decimal fraction type.

/// Rounds `x` to `places` digits after the decimal point in the direction `mode`.
@builtin("Decimal.round")
public function round(x: Decimal, places: Integer, mode: RoundingMode) -> Decimal

/// Returns the absolute value, keeping the number of digits after the decimal point.
@builtin("Decimal.absolute")
public function absolute(x: Decimal) -> Decimal

/// Returns the `Decimal` equal to `n`.
@builtin("Decimal.fromInteger")
public function fromInteger(n: Integer) -> Decimal

/// Rounds toward zero. Returns `Option.None` when the result is out of the `Integer` range.
@builtin("Decimal.truncate")
public function truncate(x: Decimal) -> Option[Integer]

/// Returns the `Float` nearest to `x`.
@builtin("Decimal.toFloat")
public function toFloat(x: Decimal) -> Float

/// Reads the text of `Float.toString(x)` as a `Decimal`. Returns `Option.None` for NaN, infinities, and values out of range.
@builtin("Decimal.fromFloat")
public function fromFloat(x: Float) -> Option[Decimal]

/// Returns the text representation of `x`.
@builtin("Decimal.toString")
public function toString(x: Decimal) -> String

/// Reads a decimal number. Returns `Option.None` when `s` is not a valid `Decimal`.
@builtin("Decimal.parse")
public function parse(s: String) -> Option[Decimal]
```

```text file=src/prelude/stdlib/RoundingMode.bnt
//! Rounding directions for `Decimal.round`.

/// How `Decimal.round` chooses the result.
public data RoundingMode
  /// The nearest value; halves go to the value whose last digit is even.
  HalfToEven
  /// The nearest value; halves go away from zero.
  HalfAwayFromZero
  /// Toward zero.
  TowardZero
  /// Toward negative infinity.
  TowardNegativeInfinity
  /// Toward positive infinity.
  TowardPositiveInfinity
end data
```

```text file=src/prelude/stdlib/Byte.bnt
//! Functions on `Byte`, the integers from 0 to 255.

/// Returns the `Byte` equal to `n`, or `Option.None` when `n` is not between 0 and 255.
@builtin("Byte.fromInteger")
public function fromInteger(n: Integer) -> Option[Byte]

/// Returns the value of `b` as an `Integer`.
@builtin("Byte.toInteger")
public function toInteger(b: Byte) -> Integer

/// Returns the decimal representation of `b`.
@builtin("Byte.toString")
public function toString(b: Byte) -> String

/// Returns the bitwise AND.
@builtin("Byte.bitwiseAnd")
public function bitwiseAnd(a: Byte, b: Byte) -> Byte

/// Returns the bitwise OR.
@builtin("Byte.bitwiseOr")
public function bitwiseOr(a: Byte, b: Byte) -> Byte

/// Returns the bitwise exclusive OR.
@builtin("Byte.bitwiseExclusiveOr")
public function bitwiseExclusiveOr(a: Byte, b: Byte) -> Byte

/// Inverts all 8 bits.
@builtin("Byte.bitwiseNot")
public function bitwiseNot(a: Byte) -> Byte

/// Shifts left by `n` bits, dropping the bits that leave the 8 bits.
@builtin("Byte.shiftLeft")
public function shiftLeft(a: Byte, n: Integer) -> Byte

/// Shifts right by `n` bits, filling the high bits with 0.
@builtin("Byte.shiftRight")
public function shiftRight(a: Byte, n: Integer) -> Byte
```

```text file=src/prelude/stdlib/Character.bnt
//! Functions on `Character`, a Unicode scalar value.

/// Returns the scalar value of `c`.
@builtin("Character.toInteger")
public function toInteger(c: Character) -> Integer

/// Returns the character with scalar value `n`, or `Option.None` when `n` is not a scalar value.
@builtin("Character.fromInteger")
public function fromInteger(n: Integer) -> Option[Character]

/// Returns the string made of `c` alone.
@builtin("Character.toString")
public function toString(c: Character) -> String

/// Returns whether `c` is one of '0' to '9'.
@builtin("Character.isASCIIDigit")
public function isASCIIDigit(c: Character) -> Boolean

/// Returns whether `c` is an ASCII space, tab, line feed, or carriage return.
@builtin("Character.isASCIIWhitespace")
public function isASCIIWhitespace(c: Character) -> Boolean
```

```text file=src/prelude/stdlib/String.bnt
//! Functions on `String`, a sequence of Unicode scalar values.

/// Returns the number of bytes in the UTF-8 encoding of `s`.
@builtin("String.byteLength")
public function byteLength(s: String) -> Integer

/// Returns the part from byte position `start` to `stop`, or `Option.None` when the positions are not valid.
@builtin("String.byteSlice")
public function byteSlice(s: String, start: Integer, stop: Integer) -> Option[String]

/// Returns the number of scalar values in `s`.
@builtin("String.characterCount")
public function characterCount(s: String) -> Integer

/// Returns the scalar value at character position `i`, or `Option.None` when `i` is out of range.
@builtin("String.characterAt")
public function characterAt(s: String, i: Integer) -> Option[Character]

/// Returns the part from character position `start` to `stop`, or `Option.None` when the positions are not valid.
@builtin("String.characterSlice")
public function characterSlice(s: String, start: Integer, stop: Integer) -> Option[String]

/// Returns whether `s` is the empty string.
@builtin("String.isEmpty")
public function isEmpty(s: String) -> Boolean

/// Returns whether `s` contains `part`.
@builtin("String.contains")
public function contains(s: String, part: String) -> Boolean

/// Returns whether `s` starts with `prefix`.
@builtin("String.startsWith")
public function startsWith(s: String, prefix: String) -> Boolean

/// Returns whether `s` ends with `suffix`.
@builtin("String.endsWith")
public function endsWith(s: String, suffix: String) -> Boolean

/// Returns the byte position of the first `part` in `s`, or `Option.None` when it does not appear.
@builtin("String.byteIndexOf")
public function byteIndexOf(s: String, part: String) -> Option[Integer]

/// Splits `s` at each `separator`. An empty separator splits into single characters.
@builtin("String.split")
public function split(s: String, separator: String) -> List[String]

/// Splits `s` into lines at LF, dropping a CR before each LF.
@builtin("String.lines")
public function lines(s: String) -> List[String]

/// Joins the strings of `xs`, putting `separator` between them.
@builtin("String.join")
public function join(xs: List[String], separator: String) -> String

/// Removes ASCII whitespace from both ends.
@builtin("String.trim")
public function trim(s: String) -> String

/// Replaces every non-overlapping `old` in `s` with `new`, from the start.
@builtin("String.replace")
public function replace(s: String, old: String, new: String) -> String

/// Repeats `s` `n` times. Returns the empty string when `n` is 0 or less.
@builtin("String.repeat")
public function repeat(s: String, n: Integer) -> String

/// Returns the scalar values of `s` in order.
@builtin("String.characters")
public function characters(s: String) -> List[Character]

/// Joins the characters of `cs` into a string.
@builtin("String.fromCharacters")
public function fromCharacters(cs: List[Character]) -> String
```

```text file=src/prelude/stdlib/Boolean.bnt
//! The type `Boolean` with the values `true` and `false`. It is built in and has no functions here;
//! use `not`, `and`, and `or`.
```

## コレクションのモジュール

`List` の関数を引数にとる関数（`map`・`filter`・`fold`・`forEach`・`any`・`all`・`find`）は、03-06「List」で実装を「ソース」とした関数である。`any`・`all`・`find` は、結果が決まった時点で残りの要素について関数を呼ばない。`or`・`and` の右辺と `if` の分岐は末尾位置にあるので（01-08「末尾呼び出し」）、どの補助の関数も末尾再帰になる。

```text file=src/prelude/stdlib/List.bnt
//! Functions on `List`. Lists are made with list literals and these functions.

/// Returns the number of elements.
@builtin("List.length")
public function length[T](xs: List[T]) -> Integer

/// Returns whether the list has no elements.
@builtin("List.isEmpty")
public function isEmpty[T](xs: List[T]) -> Boolean

/// Returns the first element, or `Option.None` when the list is empty.
@builtin("List.head")
public function head[T](xs: List[T]) -> Option[T]

/// Returns the list without its first element, or `Option.None` when the list is empty.
@builtin("List.tail")
public function tail[T](xs: List[T]) -> Option[List[T]]

/// Returns the element at position `i`, counting from 0, or `Option.None` when `i` is out of range.
@builtin("List.get")
public function get[T](xs: List[T], i: Integer) -> Option[T]

/// Returns the list with `x` added at the front.
@builtin("List.prepend")
public function prepend[T](xs: List[T], x: T) -> List[T]

/// Returns the list with `x` added at the end.
@builtin("List.append")
public function append[T](xs: List[T], x: T) -> List[T]

/// Returns the elements of `xs` followed by the elements of `ys`.
@builtin("List.concatenate")
public function concatenate[T](xs: List[T], ys: List[T]) -> List[T]

/// Returns the elements in reverse order.
@builtin("List.reverse")
public function reverse[T](xs: List[T]) -> List[T]

/// Returns the first `n` elements.
@builtin("List.take")
public function take[T](xs: List[T], n: Integer) -> List[T]

/// Returns the list without its first `n` elements.
@builtin("List.drop")
public function drop[T](xs: List[T], n: Integer) -> List[T]

/// Returns the integers from `start` up to, but not including, `stop`.
@builtin("List.range")
public function range(start: Integer, stop: Integer) -> List[Integer]

/// Returns whether some element is equal to `x` by `=`.
@builtin("List.contains")
public function contains[T: equality](xs: List[T], x: T) -> Boolean

/// Returns the elements in ascending order by `<`. Equal elements keep their order. NaN goes last.
@builtin("List.sort")
public function sort[T: ordered](xs: List[T]) -> List[T]

/// Returns the list of `f` applied to each element.
public function map[T, U, effect E](xs: List[T], f: function(T) -> U uses E) -> List[U] uses E
  return mapFrom(xs, f, 0, [])
end function

function mapFrom[T, U, effect E](xs: List[T], f: function(T) -> U uses E, i: Integer, acc: List[U]) -> List[U] uses E
  return match get(xs, i) with
    case Option.None -> acc
    case Option.Some(x) ->
      bind y <- f(x)
      mapFrom(xs, f, i + 1, append(acc, y))
  end match
end function

/// Returns the elements for which `p` returns `true`, in order.
public function filter[T, effect E](xs: List[T], p: function(T) -> Boolean uses E) -> List[T] uses E
  return filterFrom(xs, p, 0, [])
end function

function filterFrom[T, effect E](xs: List[T], p: function(T) -> Boolean uses E, i: Integer, acc: List[T]) -> List[T] uses E
  return match get(xs, i) with
    case Option.None -> acc
    case Option.Some(x) ->
      if p(x) then
        filterFrom(xs, p, i + 1, append(acc, x))
      else
        filterFrom(xs, p, i + 1, acc)
      end if
  end match
end function

/// Combines the elements from the first with `f`, starting from `initial`.
public function fold[T, A, effect E](xs: List[T], initial: A, f: function(A, T) -> A uses E) -> A uses E
  return foldFrom(xs, initial, f, 0)
end function

function foldFrom[T, A, effect E](xs: List[T], acc: A, f: function(A, T) -> A uses E, i: Integer) -> A uses E
  return match get(xs, i) with
    case Option.None -> acc
    case Option.Some(x) -> foldFrom(xs, f(acc, x), f, i + 1)
  end match
end function

/// Calls `f` with each element in order.
public function forEach[T, effect E](xs: List[T], f: function(T) -> Unit uses E) -> Unit uses E
  return forEachFrom(xs, f, 0)
end function

function forEachFrom[T, effect E](xs: List[T], f: function(T) -> Unit uses E, i: Integer) -> Unit uses E
  return match get(xs, i) with
    case Option.None -> ()
    case Option.Some(x) ->
      f(x)
      forEachFrom(xs, f, i + 1)
  end match
end function

/// Returns whether `p` returns `true` for some element. Stops calling `p` at the first `true`.
public function any[T, effect E](xs: List[T], p: function(T) -> Boolean uses E) -> Boolean uses E
  return anyFrom(xs, p, 0)
end function

function anyFrom[T, effect E](xs: List[T], p: function(T) -> Boolean uses E, i: Integer) -> Boolean uses E
  return match get(xs, i) with
    case Option.None -> false
    case Option.Some(x) -> p(x) or anyFrom(xs, p, i + 1)
  end match
end function

/// Returns whether `p` returns `true` for every element. Stops calling `p` at the first `false`.
public function all[T, effect E](xs: List[T], p: function(T) -> Boolean uses E) -> Boolean uses E
  return allFrom(xs, p, 0)
end function

function allFrom[T, effect E](xs: List[T], p: function(T) -> Boolean uses E, i: Integer) -> Boolean uses E
  return match get(xs, i) with
    case Option.None -> true
    case Option.Some(x) -> p(x) and allFrom(xs, p, i + 1)
  end match
end function

/// Returns the first element for which `p` returns `true`, or `Option.None` when there is none.
public function find[T, effect E](xs: List[T], p: function(T) -> Boolean uses E) -> Option[T] uses E
  return findFrom(xs, p, 0)
end function

function findFrom[T, effect E](xs: List[T], p: function(T) -> Boolean uses E, i: Integer) -> Option[T] uses E
  return match get(xs, i) with
    case Option.None -> Option.None
    case Option.Some(x) ->
      if p(x) then
        Option.Some(x)
      else
        findFrom(xs, p, i + 1)
      end if
  end match
end function
```

`Map` と `Set` は、定数式に書ける関数（01-02「定数（初回リリース版）」）と、値をテストで確かめるための `toList` だけを置く（10-12「リスト・マップ・集合」）。

```text file=src/prelude/stdlib/Map.bnt
//! Functions on `Map`, a persistent map ordered by its keys.

/// Returns the empty map.
@builtin("Map.empty")
public function empty[K: key, V]() -> Map[K, V]

/// Returns the map of the pairs in `pairs`. A later pair wins when two pairs have the same key.
@builtin("Map.fromList")
public function fromList[K: key, V](pairs: List[Pair[K, V]]) -> Map[K, V]

/// Returns the pairs in the order of their keys.
@builtin("Map.toList")
public function toList[K: key, V](m: Map[K, V]) -> List[Pair[K, V]]
```

```text file=src/prelude/stdlib/Set.bnt
//! Functions on `Set`, a persistent set ordered by its elements.

/// Returns the empty set.
@builtin("Set.empty")
public function empty[T: key]() -> Set[T]

/// Returns the set of the elements of `xs`.
@builtin("Set.fromList")
public function fromList[T: key](xs: List[T]) -> Set[T]

/// Returns the elements in order.
@builtin("Set.toList")
public function toList[T: key](s: Set[T]) -> List[T]
```

## Option・Result・Pair・Triple

どの関数もソースで定める（03-06「Option」「Result」「Pair と Triple（初回リリース版）」）。03-06 の表で `d` とした `unwrapOr` の引数は、`fallback` とする。

```text file=src/prelude/stdlib/Option.bnt
//! Optional values.

/// A value that may be absent: `Option.Some(x)` holds `x`, and `Option.None` holds nothing.
public data Option[T]
  Some(T)
  None
end data

/// Applies `f` to the value inside `Option.Some`.
public function map[T, U, effect E](o: Option[T], f: function(T) -> U uses E) -> Option[U] uses E
  return match o with
    case Option.Some(x) -> Option.Some(f(x))
    case Option.None -> Option.None
  end match
end function

/// Applies `f` to the value inside `Option.Some` and returns its result.
public function andThen[T, U, effect E](o: Option[T], f: function(T) -> Option[U] uses E) -> Option[U] uses E
  return match o with
    case Option.Some(x) -> f(x)
    case Option.None -> Option.None
  end match
end function

/// Returns the value inside `Option.Some`, or `fallback` for `Option.None`.
public function unwrapOr[T](o: Option[T], fallback: T) -> T
  return match o with
    case Option.Some(x) -> x
    case Option.None -> fallback
  end match
end function

/// Returns whether `o` is `Option.Some`.
public function isSome[T](o: Option[T]) -> Boolean
  return match o with
    case Option.Some(_) -> true
    case Option.None -> false
  end match
end function

/// Returns whether `o` is `Option.None`.
public function isNone[T](o: Option[T]) -> Boolean
  return match o with
    case Option.Some(_) -> false
    case Option.None -> true
  end match
end function

/// Turns `Option.Some(x)` into `Result.Ok(x)` and `Option.None` into `Result.Error(error)`.
public function okOr[T, X](o: Option[T], error: X) -> Result[T, X]
  return match o with
    case Option.Some(x) -> Result.Ok(x)
    case Option.None -> Result.Error(error)
  end match
end function
```

```text file=src/prelude/stdlib/Result.bnt
//! Results of operations that may fail.

/// The result of an operation: `Result.Ok(x)` on success, `Result.Error(e)` on failure.
public data Result[T, E]
  Ok(T)
  Error(E)
end data

/// Applies `f` to the value inside `Result.Ok`.
public function map[T, U, X, effect E](r: Result[T, X], f: function(T) -> U uses E) -> Result[U, X] uses E
  return match r with
    case Result.Ok(x) -> Result.Ok(f(x))
    case Result.Error(e) -> Result.Error(e)
  end match
end function

/// Applies `f` to the value inside `Result.Error`.
public function mapError[T, X, Y, effect E](r: Result[T, X], f: function(X) -> Y uses E) -> Result[T, Y] uses E
  return match r with
    case Result.Ok(x) -> Result.Ok(x)
    case Result.Error(e) -> Result.Error(f(e))
  end match
end function

/// Applies `f` to the value inside `Result.Ok` and returns its result.
public function andThen[T, U, X, effect E](r: Result[T, X], f: function(T) -> Result[U, X] uses E) -> Result[U, X] uses E
  return match r with
    case Result.Ok(x) -> f(x)
    case Result.Error(e) -> Result.Error(e)
  end match
end function

/// Returns the value inside `Result.Ok`, or `fallback` for `Result.Error`.
public function unwrapOr[T, X](r: Result[T, X], fallback: T) -> T
  return match r with
    case Result.Ok(x) -> x
    case Result.Error(_) -> fallback
  end match
end function

/// Returns whether `r` is `Result.Ok`.
public function isOk[T, X](r: Result[T, X]) -> Boolean
  return match r with
    case Result.Ok(_) -> true
    case Result.Error(_) -> false
  end match
end function

/// Returns whether `r` is `Result.Error`.
public function isError[T, X](r: Result[T, X]) -> Boolean
  return match r with
    case Result.Ok(_) -> false
    case Result.Error(_) -> true
  end match
end function

/// Turns `Result.Ok(x)` into `Option.Some(x)` and `Result.Error` into `Option.None`.
public function ok[T, X](r: Result[T, X]) -> Option[T]
  return match r with
    case Result.Ok(x) -> Option.Some(x)
    case Result.Error(_) -> Option.None
  end match
end function
```

```text file=src/prelude/stdlib/Pair.bnt
//! Pairs of two values.

/// A pair of two values, written `Pair(a, b)`.
public data Pair[A, B]
  Pair(A, B)
end data

/// Returns the first value.
public function first[A, B](p: Pair[A, B]) -> A
  bind Pair(a, _) <- p
  return a
end function

/// Returns the second value.
public function second[A, B](p: Pair[A, B]) -> B
  bind Pair(_, b) <- p
  return b
end function
```

```text file=src/prelude/stdlib/Triple.bnt
//! Triples of three values.

/// A triple of three values, written `Triple(a, b, c)`.
public data Triple[A, B, C]
  Triple(A, B, C)
end data

/// Returns the first value.
public function first[A, B, C](t: Triple[A, B, C]) -> A
  bind Triple(a, _, _) <- t
  return a
end function

/// Returns the second value.
public function second[A, B, C](t: Triple[A, B, C]) -> B
  bind Triple(_, b, _) <- t
  return b
end function

/// Returns the third value.
public function third[A, B, C](t: Triple[A, B, C]) -> C
  bind Triple(_, _, c) <- t
  return c
end function
```

## IO の失敗と、ランタイムに結び付いた関数

`IOError` は中身を見せない組み込みの型であり、`IOErrorKind` は構成子を公開する型である（01-07「IO の失敗」、01-09「IO の失敗の種類」）。`Reference`・`Lazy`・`Task`・`TaskGroup` の関数は、どれも組み込みの関数である（03-06「Task と TaskGroup（初回リリース版）」「Reference と Lazy（初回リリース版）」）。

```text file=src/prelude/stdlib/IOError.bnt
//! Failures of IO operations. The type `IOError` is built in.

/// Returns a human-readable description of the failure. The wording may change between versions.
@builtin("IOError.message")
public function message(e: IOError) -> String

/// Returns the kind of the failure.
@builtin("IOError.kind")
public function kind(e: IOError) -> IOErrorKind
```

```text file=src/prelude/stdlib/IOErrorKind.bnt
//! Kinds of IO failures.

/// The kind of an IO failure, returned by `IOError.kind`.
public data IOErrorKind
  /// The path or the command does not exist.
  NotFound
  /// The operating system refused the operation.
  PermissionDenied
  /// The thing to create already exists.
  AlreadyExists
  /// A directory was given where a file is needed.
  IsDirectory
  /// Something other than a directory was given where a directory is needed.
  NotDirectory
  /// A non-empty directory was given where an empty one is needed.
  DirectoryNotEmpty
  /// The content read is not valid UTF-8.
  InvalidUTF8
  /// An argument cannot be passed to the operating system, such as a path containing NUL.
  InvalidInput
  /// None of the above.
  Other
end data
```

```text file=src/prelude/stdlib/Reference.bnt
//! Mutable cells. The type `Reference` is built in.

/// Returns a new cell holding `value`.
@builtin("Reference.new")
public function new[T](value: T) -> Reference[T] uses State

/// Returns the value in the cell.
@builtin("Reference.get")
public function get[T](reference: Reference[T]) -> T uses State

/// Replaces the value in the cell with `value`.
@builtin("Reference.set")
public function set[T](reference: Reference[T], value: T) -> Unit uses State

/// Replaces the value in the cell with `f` applied to it. No other task touches the cell in between.
@builtin("Reference.update")
public function update[T](reference: Reference[T], f: function(T) -> T) -> Unit uses State
```

```text file=src/prelude/stdlib/Lazy.bnt
//! Explicitly delayed values, made with `lazy ... end lazy`. The type `Lazy` is built in.

/// Evaluates the delayed body on the first call and returns the remembered value afterwards.
@builtin("Lazy.force")
public function force[T](value: Lazy[T]) -> T
```

`Task.race` と `Task.withTimeout` の型は `Clock.Time` を持つ（01-11「タスクを起動する関数」）ので、`Benitoite.Task` は `Benitoite.IO.Clock` を取り込む。`Benitoite.IO.Clock` は非公式のモジュールなので、取り込みの名前で書く（ADR 0286）。

```text file=src/prelude/stdlib/Task.bnt
//! Running tasks concurrently and waiting for their results. The type `Task` is built in.

import Benitoite.Unofficial.IO.Clock

/// Runs each action as a task and returns their results in the order of `actions`.
@builtin("Task.all")
public function all[T, effect E](actions: List[function() -> T uses E]) -> List[T] uses E

/// Runs each action as a task. Returns all values when every task returns `Result.Ok`;
/// otherwise returns the `Result.Error` of the earliest failing action in `actions`.
@builtin("Task.allOk")
public function allOk[T, X, effect E](actions: List[function() -> Result[T, X] uses E]) -> Result[List[T], X] uses E

/// Runs each action as a task and returns the result of the first to finish, cancelling the others.
@builtin("Task.race")
public function race[T, effect E](actions: List[function() -> T uses E]) -> Option[T] uses Clock.Time, State, E

/// Runs `action` as a task and returns its result if it finishes within `milliseconds`; otherwise cancels it.
@builtin("Task.withTimeout")
public function withTimeout[T, effect E](milliseconds: Integer, action: function() -> T uses E) -> Option[T] uses Clock.Time, State, E

/// Waits for `task` to finish and returns its result.
@builtin("Task.await")
public function await[T](task: Task[T]) -> T uses State
```

```text file=src/prelude/stdlib/TaskGroup.bnt
//! Groups of tasks started one by one. The resource type `TaskGroup` is built in.

/// Returns an empty group. It can be written only as the expression of a `with` binding.
@builtin("TaskGroup.open")
public function open() -> TaskGroup uses State

/// Runs `action` as a task in `group` and returns without waiting for it.
@builtin("TaskGroup.spawn")
public function spawn[T, effect E](group: TaskGroup, action: function() -> T uses E) -> Task[T] uses State, E
```

```text file=src/prelude/stdlib/IO.bnt
//! The effect `IO.All`, which stands for all the effects of the modules under `Benitoite.IO`.
//! It is built in. Import the modules under it, such as `Console`, to use their functions.
```

## IO のモジュール

IO のモジュールの関数は、組み込みのエフェクトの操作として宣言する（03-07「モジュールとエフェクト」、[ADR 0129](../../design/decisions/0129-effects-declared-in-modules.md)、[ADR 0130](../../design/decisions/0130-builtin-effect-names-and-placement.md)）。型検査は、宣言したモジュールの名前とエフェクトの名前から組み込みのエフェクトの表（10-05）を引き、`Console.Write` などを組み込みのエフェクトとする。名前解決は、操作ごとに `Benitoite.IO.Console.writeLine` などの名前で 10-12 の表を引く。`File.closeReader` は操作ではなく `State` を型に持つ組み込みの関数である（ADR 0150）。ここに置く操作は、10-12「IO のモジュール」の U2 の範囲だけである。

```text file=src/prelude/stdlib/IO/Clock.bnt
//! Reading the clock and waiting for time to pass.

/// Operations that depend on time.
public effect Time
  /// Stops the calling task for at least `milliseconds` while other tasks run. Returns at once for 0 or less.
  function sleep(milliseconds: Integer) -> Unit
  /// Returns milliseconds from an unspecified start. The value never decreases within a run.
  function monotonicMilliseconds() -> Integer
end effect
```

```text file=src/prelude/stdlib/IO/Console.bnt
//! Standard input, standard output, and standard error.

/// Writing to standard output and standard error.
public effect Write
  /// Writes `text` to standard output.
  function write(text: String) -> Unit
  /// Writes `text` and a line feed to standard output.
  function writeLine(text: String) -> Unit
  /// Writes `text` to standard error.
  function writeError(text: String) -> Unit
  /// Writes `text` and a line feed to standard error.
  function writeErrorLine(text: String) -> Unit
end effect

/// Reading standard input.
public effect Read
  /// Reads one line. Returns `Option.None` at the end of the input.
  function readLine() -> Result[Option[String], IOError]
  /// Reads the rest of the input.
  function readAll() -> Result[String, IOError]
end effect
```

```text file=src/prelude/stdlib/IO/File.bnt
//! Reading and writing files. The resource types `Reader` and `Writer` are built in.

/// Reading files.
public effect Read
  /// Reads the whole file as text. Fails with `IOErrorKind.InvalidUTF8` when the content is not UTF-8.
  function readText(path: String) -> Result[String, IOError]
  /// Opens the file for reading line by line.
  function openReader(path: String) -> Result[Reader, IOError]
  /// Reads one line. Returns `Option.None` at the end of the file.
  function readLine(reader: Reader) -> Result[Option[String], IOError]
end effect

/// Writing files.
public effect Write
  /// Creates or replaces the file with `text`.
  function writeText(path: String, text: String) -> Result[Unit, IOError]
  /// Adds `text` to the end of the file, creating it when missing.
  function appendText(path: String, text: String) -> Result[Unit, IOError]
end effect

/// Closes the reader. A `with` binding closes it in the same way.
@builtin("IO.File.closeReader")
public function closeReader(reader: Reader) -> Result[Unit, IOError] uses State
```

```text file=src/prelude/stdlib/IO/Process.bnt
//! The running process: its arguments and its exit.

/// Reading the environment of the process.
public effect Environment
  /// Returns the command-line arguments given to the script.
  function arguments() -> List[String]
end effect

/// Ending the process.
public effect Exit
  /// Ends the run with the exit status `code`. It does not return.
  function exit[T](code: Integer) -> T
end effect
```

## 標準の型クラス

`Benitoite.Trait` は、03-06「標準の型クラス（初回リリース版）」の九つの型クラスと `Ordering`、標準の型の実装を持つ（[ADR 0134](../../design/decisions/0134-standard-type-classes.md)）。prelude には入らない。実装の意味は 03-06 の同節の表のとおりである。

- `Show[String]` と `Show[Character]` は、リテラルの形にエスケープする組み込みの関数（10-12 の `Trait.showString`・`Trait.showCharacter`）を使う。
- `Order[Float]` は、NaN をどの値よりも大きく、NaN どうしと `0.0` と `-0.0` を `Ordering.Equal` とする全順序である。`<` は NaN との比較で `false` を返し、`0.0 < -0.0` も `-0.0 < 0.0` も `false` なので、NaN を先に分ければ残りは `<` で比べられる。
- `Order` の `Decimal` は `<` で比べるので、`1.0m` と `1.00m` は `Ordering.Equal` である（鍵の順序と同じ）。
- `List` の `Order`・`Applicative.apply`・`Monad.flatMap`・`Traversable.traverse` は、添字を累積の引数に持つ末尾再帰の補助の関数で書く。
- `Map`・`Set` の実装は U3 が加える（前述の「モジュールの一覧」）。

```text file=src/prelude/stdlib/Trait.bnt
//! Standard type classes. Import `Benitoite.Trait` and write `Trait.Show.show(x)`.

/// The result of comparing two values.
public data Ordering
  Less
  Equal
  Greater
end data

/// Values that can be shown as text close to how they are written in code.
public trait Show[T]
  /// Returns the text of `x`.
  function show(x: T) -> String
end trait

/// Values with a total order.
public trait Order[T]
  /// Compares `x` with `y`.
  function compare(x: T, y: T) -> Ordering
end trait

/// Values that can be combined.
public trait Semigroup[T]
  /// Combines `x` and `y`.
  function combine(x: T, y: T) -> T
end trait

/// Values that can be combined and have an empty value.
public trait Monoid[T: Semigroup]
  /// Returns the empty value.
  function empty() -> T
end trait

/// Containers whose values can be transformed.
public trait Functor[F[_]]
  /// Applies `f` to each value inside `x`.
  function map[A, B, effect E](x: F[A], f: function(A) -> B uses E) -> F[B] uses E
end trait

/// Functors that can wrap a value and apply wrapped functions.
public trait Applicative[F[_]: Functor]
  /// Wraps `x`.
  function pure[A](x: A) -> F[A]
  /// Applies the functions in `fs` to the values in `x`.
  function apply[A, B, effect E](fs: F[function(A) -> B uses E], x: F[A]) -> F[B] uses E
end trait

/// Applicatives whose computations can depend on earlier values.
public trait Monad[F[_]: Applicative]
  /// Applies `f` to each value inside `x` and flattens the results.
  function flatMap[A, B, effect E](x: F[A], f: function(A) -> F[B] uses E) -> F[B] uses E
end trait

/// Containers whose values can be combined in order.
public trait Foldable[F[_]]
  /// Combines the values from the first with `f`, starting from `initial`.
  function fold[A, B, effect E](x: F[A], initial: B, f: function(B, A) -> B uses E) -> B uses E
end trait

/// Containers that can be walked through with an applicative effect.
public trait Traversable[F[_]: Functor & Foldable]
  /// Applies `f` to each value in order and collects the results inside `G`.
  function traverse[G[_]: Applicative, A, B, effect E](x: F[A], f: function(A) -> G[B] uses E) -> G[F[B]] uses E
end trait

@builtin("Trait.showString")
function showString(s: String) -> String

@builtin("Trait.showCharacter")
function showCharacter(c: Character) -> String

// Show

implement Show[Integer]
  function show(x: Integer) -> String
    return Integer.toString(x)
  end function
end implement

implement Show[Float]
  function show(x: Float) -> String
    return Float.toString(x)
  end function
end implement

implement Show[Decimal]
  function show(x: Decimal) -> String
    return Decimal.toString(x)
  end function
end implement

implement Show[Byte]
  function show(x: Byte) -> String
    return Byte.toString(x)
  end function
end implement

implement Show[Character]
  function show(x: Character) -> String
    return showCharacter(x)
  end function
end implement

implement Show[String]
  function show(x: String) -> String
    return showString(x)
  end function
end implement

implement Show[Boolean]
  function show(x: Boolean) -> String
    return if x then "true" else "false" end if
  end function
end implement

implement Show[Unit]
  function show(x: Unit) -> String
    return "()"
  end function
end implement

implement[T: Show] Show[List[T]]
  function show(x: List[T]) -> String
    bind items <- List.map(x, lambda(e) return Show.show(e) end lambda)
    return "[" + String.join(items, ", ") + "]"
  end function
end implement

implement[T: Show] Show[Option[T]]
  function show(x: Option[T]) -> String
    return match x with
      case Option.Some(v) -> "Option.Some(" + Show.show(v) + ")"
      case Option.None -> "Option.None"
    end match
  end function
end implement

implement[A: Show, B: Show] Show[Pair[A, B]]
  function show(x: Pair[A, B]) -> String
    bind Pair(a, b) <- x
    return "Pair(" + Show.show(a) + ", " + Show.show(b) + ")"
  end function
end implement

implement[A: Show, B: Show, C: Show] Show[Triple[A, B, C]]
  function show(x: Triple[A, B, C]) -> String
    bind Triple(a, b, c) <- x
    return "Triple(" + Show.show(a) + ", " + Show.show(b) + ", " + Show.show(c) + ")"
  end function
end implement

// Order

implement Order[Integer]
  function compare(x: Integer, y: Integer) -> Ordering
    return if x < y then Ordering.Less else if y < x then Ordering.Greater else Ordering.Equal end if
  end function
end implement

implement Order[Float]
  function compare(x: Float, y: Float) -> Ordering
    if Float.isNaN(x) then
      return if Float.isNaN(y) then Ordering.Equal else Ordering.Greater end if
    end if
    if Float.isNaN(y) then
      return Ordering.Less
    end if
    return if x < y then Ordering.Less else if y < x then Ordering.Greater else Ordering.Equal end if
  end function
end implement

implement Order[Decimal]
  function compare(x: Decimal, y: Decimal) -> Ordering
    return if x < y then Ordering.Less else if y < x then Ordering.Greater else Ordering.Equal end if
  end function
end implement

implement Order[Byte]
  function compare(x: Byte, y: Byte) -> Ordering
    return if x < y then Ordering.Less else if y < x then Ordering.Greater else Ordering.Equal end if
  end function
end implement

implement Order[Character]
  function compare(x: Character, y: Character) -> Ordering
    return if x < y then Ordering.Less else if y < x then Ordering.Greater else Ordering.Equal end if
  end function
end implement

implement Order[String]
  function compare(x: String, y: String) -> Ordering
    return if x < y then Ordering.Less else if y < x then Ordering.Greater else Ordering.Equal end if
  end function
end implement

implement Order[Boolean]
  function compare(x: Boolean, y: Boolean) -> Ordering
    return if x = y then Ordering.Equal else if y then Ordering.Less else Ordering.Greater end if
  end function
end implement

implement Order[Unit]
  function compare(x: Unit, y: Unit) -> Ordering
    return Ordering.Equal
  end function
end implement

implement[T: Order] Order[List[T]]
  function compare(x: List[T], y: List[T]) -> Ordering
    return compareListsFrom(x, y, 0)
  end function
end implement

function compareListsFrom[T: Order](x: List[T], y: List[T], i: Integer) -> Ordering
  return match Pair(List.get(x, i), List.get(y, i)) with
    case Pair(Option.None, Option.None) -> Ordering.Equal
    case Pair(Option.None, Option.Some(_)) -> Ordering.Less
    case Pair(Option.Some(_), Option.None) -> Ordering.Greater
    case Pair(Option.Some(a), Option.Some(b)) ->
      match Order.compare(a, b) with
        case Ordering.Equal -> compareListsFrom(x, y, i + 1)
        case other -> other
      end match
  end match
end function

implement[T: Order] Order[Option[T]]
  function compare(x: Option[T], y: Option[T]) -> Ordering
    return match Pair(x, y) with
      case Pair(Option.Some(a), Option.Some(b)) -> Order.compare(a, b)
      case Pair(Option.Some(_), Option.None) -> Ordering.Less
      case Pair(Option.None, Option.Some(_)) -> Ordering.Greater
      case Pair(Option.None, Option.None) -> Ordering.Equal
    end match
  end function
end implement

implement[A: Order, B: Order] Order[Pair[A, B]]
  function compare(x: Pair[A, B], y: Pair[A, B]) -> Ordering
    bind Pair(a1, b1) <- x
    bind Pair(a2, b2) <- y
    return match Order.compare(a1, a2) with
      case Ordering.Equal -> Order.compare(b1, b2)
      case other -> other
    end match
  end function
end implement

implement[A: Order, B: Order, C: Order] Order[Triple[A, B, C]]
  function compare(x: Triple[A, B, C], y: Triple[A, B, C]) -> Ordering
    bind Triple(a1, b1, c1) <- x
    bind Triple(a2, b2, c2) <- y
    return match Order.compare(a1, a2) with
      case Ordering.Equal ->
        match Order.compare(b1, b2) with
          case Ordering.Equal -> Order.compare(c1, c2)
          case other -> other
        end match
      case other -> other
    end match
  end function
end implement

// Semigroup and Monoid

implement Semigroup[String]
  function combine(x: String, y: String) -> String
    return x + y
  end function
end implement

implement Monoid[String]
  function empty() -> String
    return ""
  end function
end implement

implement[T] Semigroup[List[T]]
  function combine(x: List[T], y: List[T]) -> List[T]
    return List.concatenate(x, y)
  end function
end implement

implement[T] Monoid[List[T]]
  function empty() -> List[T]
    return []
  end function
end implement

// Functor, Applicative, Monad, Foldable, and Traversable for Option

implement Functor[Option]
  function map[A, B, effect E](x: Option[A], f: function(A) -> B uses E) -> Option[B] uses E
    return Option.map(x, f)
  end function
end implement

implement Applicative[Option]
  function pure[A](x: A) -> Option[A]
    return Option.Some(x)
  end function

  function apply[A, B, effect E](fs: Option[function(A) -> B uses E], x: Option[A]) -> Option[B] uses E
    return match Pair(fs, x) with
      case Pair(Option.Some(f), Option.Some(v)) -> Option.Some(f(v))
      case _ -> Option.None
    end match
  end function
end implement

implement Monad[Option]
  function flatMap[A, B, effect E](x: Option[A], f: function(A) -> Option[B] uses E) -> Option[B] uses E
    return Option.andThen(x, f)
  end function
end implement

implement Foldable[Option]
  function fold[A, B, effect E](x: Option[A], initial: B, f: function(B, A) -> B uses E) -> B uses E
    return match x with
      case Option.Some(v) -> f(initial, v)
      case Option.None -> initial
    end match
  end function
end implement

implement Traversable[Option]
  function traverse[G[_]: Applicative, A, B, effect E](x: Option[A], f: function(A) -> G[B] uses E) -> G[Option[B]] uses E
    return match x with
      case Option.None -> Applicative.pure(Option.None)
      case Option.Some(v) -> Functor.map(f(v), lambda(b) return Option.Some(b) end lambda)
    end match
  end function
end implement

// Functor, Applicative, Monad, Foldable, and Traversable for List

implement Functor[List]
  function map[A, B, effect E](x: List[A], f: function(A) -> B uses E) -> List[B] uses E
    return List.map(x, f)
  end function
end implement

implement Applicative[List]
  function pure[A](x: A) -> List[A]
    return [x]
  end function

  function apply[A, B, effect E](fs: List[function(A) -> B uses E], x: List[A]) -> List[B] uses E
    return applyFrom(fs, x, 0, [])
  end function
end implement

function applyFrom[A, B, effect E](fs: List[function(A) -> B uses E], xs: List[A], i: Integer, acc: List[B]) -> List[B] uses E
  return match List.get(fs, i) with
    case Option.None -> acc
    case Option.Some(f) -> applyFrom(fs, xs, i + 1, List.concatenate(acc, List.map(xs, f)))
  end match
end function

implement Monad[List]
  function flatMap[A, B, effect E](x: List[A], f: function(A) -> List[B] uses E) -> List[B] uses E
    return flatMapFrom(x, f, 0, [])
  end function
end implement

function flatMapFrom[A, B, effect E](xs: List[A], f: function(A) -> List[B] uses E, i: Integer, acc: List[B]) -> List[B] uses E
  return match List.get(xs, i) with
    case Option.None -> acc
    case Option.Some(v) -> flatMapFrom(xs, f, i + 1, List.concatenate(acc, f(v)))
  end match
end function

implement Foldable[List]
  function fold[A, B, effect E](x: List[A], initial: B, f: function(B, A) -> B uses E) -> B uses E
    return List.fold(x, initial, f)
  end function
end implement

implement Traversable[List]
  function traverse[G[_]: Applicative, A, B, effect E](x: List[A], f: function(A) -> G[B] uses E) -> G[List[B]] uses E
    return traverseFrom(x, f, 0, Applicative.pure([]))
  end function
end implement

function traverseFrom[G[_]: Applicative, A, B, effect E](xs: List[A], f: function(A) -> G[B] uses E, i: Integer, acc: G[List[B]]) -> G[List[B]] uses E
  return match List.get(xs, i) with
    case Option.None -> acc
    case Option.Some(v) ->
      bind appendTo <- Functor.map(acc, lambda(bs) return lambda(b) return List.append(bs, b) end lambda end lambda)
      traverseFrom(xs, f, i + 1, Applicative.apply(appendTo, f(v)))
  end match
end function
```

## 文法の確かめ

本章のソースは、Python の道具 `tools/grammar-check`（C13 が消した）の字句解析器と照合器で、01-02「初回リリース版の文法の全体」に、`@builtin` を付けた本体のない関数の宣言（02-03「標準ライブラリのソースの構文」）を加えた文法で読めることを確かめた（2026-09-30）。局所の束縛の規則（`scope_check.py`）も確かめた。この道具が確かめるのは文法と局所の束縛の規則だけであり、名前解決と型検査の誤りは確かめていない。名前と型の誤りは、F05〜F10 の作業が、本章のソースを処理系で読んで見つける（前述の「置く作業と既存のファイル」）。

本章のソースを変えたときは、処理系で標準ライブラリのソースを検査するテスト（F06 の照合のテストを含む）で確かめる。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C02 | `src/prelude/mod.rs` と `src/prelude/stdlib/` の下のソースを置く |
| F05 | 読み込みの段が `STDLIB` を引き、prelude のモジュールを表の順に置き、import で辿れるモジュールを読む |
| F06 | 名前解決が標準ライブラリのソースを読み、`@builtin` と操作を 10-12 の表で引く。10-12 の「ソースと表の照合」のテスト（構成子の宣言の順と `table::tags` の一致を含む） |
| F07〜F10 | 型検査が本章のソースを利用者のモジュールと同じく検査し、誤りがないことを確かめるテスト |
| F08 | `Benitoite.Trait` の型クラスと実装を使うテスト（上位の型クラス、戻り値の型で実装を選ぶメソッド、型構成子を引数にとる型クラス） |
| C11 | 標準ライブラリのソースの関数（`List.map` など）と `Benitoite.Trait` のゴールデンテスト |
