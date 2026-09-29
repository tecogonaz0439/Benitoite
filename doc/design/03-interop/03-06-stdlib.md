# 標準ライブラリ

- 状態: 確定
- 関連ADR: [0006](../decisions/0006-basic-types-semantics.md), [0007](../decisions/0007-constructors-and-list.md), [0008](../decisions/0008-effect-variables.md), [0009](../decisions/0009-typing-without-type-classes.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0030](../decisions/0030-call-stack-size-limit.md), [0041](../decisions/0041-list-as-linked-list.md), [0042](../decisions/0042-minimal-prelude-scope.md), [0043](../decisions/0043-option-result-rust-names-no-unwrap.md), [0049](../decisions/0049-size-limit-for-built-values.md), [0077](../decisions/0077-abolish-go-layer.md), [0091](../decisions/0091-acronyms-in-uppercase.md), [0096](../decisions/0096-explicit-return.md), [0099](../decisions/0099-qualified-option-result-constructors.md), [0101](../decisions/0101-unabbreviated-names.md), [0102](../decisions/0102-pair-and-triple.md), [0103](../decisions/0103-map-and-set-ordered-by-key.md), [0104](../decisions/0104-list-as-persistent-vector.md), [0105](../decisions/0105-byte-type.md), [0106](../decisions/0106-bitwise-functions.md), [0107](../decisions/0107-bytes.md), [0113](../decisions/0113-div-and-mod-operators.md), [0114](../decisions/0114-decimal-type.md), [0115](../decisions/0115-structured-io-concurrency.md), [0119](../decisions/0119-attributes-test-and-deprecated.md), [0120](../decisions/0120-test-functions-and-assert-effect.md), [0125](../decisions/0125-doc-comments.md), [0126](../decisions/0126-import-by-module-name.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0132](../decisions/0132-language-name-benitoite.md), [0133](../decisions/0133-builtin-equality-and-key-constraints.md), [0134](../decisions/0134-standard-type-classes.md), [0136](../decisions/0136-map-and-set-in-constants.md), [0137](../decisions/0137-first-release-library-scope.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0145](../decisions/0145-network-error.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0062](../decisions/0062-operators-stay-outside-traits.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0169](../decisions/0169-unicode-character-property-functions.md), [0171](../decisions/0171-map-set-higher-order-functions.md), [0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-040](../open-issues.md#open-040), [OPEN-043](../open-issues.md#open-043), [OPEN-046](../open-issues.md#open-046), [OPEN-049](../open-issues.md#open-049), [OPEN-050](../open-issues.md#open-050)
- 移行元: [設計メモ](../sources/fp-language-design.md) なし（10 の層1・層2）

## 目的と範囲

標準ライブラリの名前空間と prelude の範囲、初期版の API 範囲、永続コレクション。永続コレクションは、公開 API と利用者向けの規則（等値比較、反復順序）に加え、実装設計（採用するデータ構造と内部表現、構造共有の規則、各操作の計算量の目標、テストする不変条件）も扱う。値を VM 上で保持・受け渡す表現は[仮想機械](../02-impl/02-08-vm.md)、メモリの生存管理は[ランタイム](../02-impl/02-09-runtime.md)が扱う。永続コレクションの実装設計が大きくなった場合は、`02-impl/` の独立章に分けることを検討する。

現在の版は、初回リリース版の標準ライブラリの名前空間と prelude（後述の「名前空間と prelude（初回リリース版）」）、prelude の型と関数、標準の型クラス（後述の「標準の型クラス（初回リリース版）」）、永続コレクションの表現、標準ライブラリのソースの書き方を定める。最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）のライブラリは prelude だけであり、`Benitoite.IO` の下のモジュールと永続コレクションはなかった。初回リリース版では、prelude に型（`Byte`・`Decimal`・`RoundingMode`・`Reference`・`Lazy`・`Task`・`TaskGroup`・`Pair`・`Triple`・`Map`・`Set`・`Bytes`・`ByteOrder`）と関数を加え、`List` の表現を変える（[ADR 0104](../decisions/0104-list-as-persistent-vector.md)）。初回リリース版の標準ライブラリに入れるモジュールは [ADR 0137](../decisions/0137-first-release-library-scope.md) で決めた。IO を行うモジュール（`Benitoite.IO` の下）は[IO のモジュール](03-07-io-modules.md)で、テキストとデータを扱う純粋なモジュール（`Benitoite.Path`・`Benitoite.Json` など）は[テキストとデータの処理](03-08-text-and-data.md)で定める。標準ライブラリの作り方（組み込みの関数とソースの分担、使う Rust のクレート）は[ライブラリの構成](03-01-library-structure.md)で定める。標準ライブラリのほかにパッケージをどう提供するかは【未決】である（[OPEN-049](../open-issues.md#open-049)）。

## 前提

基本型の演算子と、位置を扱う文字列の関数、型の変換の関数は[基本型の意味論](../01-spec/01-04-types-basic.md)（[ADR 0006](../decisions/0006-basic-types-semantics.md)）で、IO を行う関数の意味は[エフェクト](../01-spec/01-07-effects.md)で、IO のモジュールの関数の一覧は[IO のモジュール](03-07-io-modules.md)で定める。本章は、それらを含む標準ライブラリの関数の一覧と、残りの関数の意味を定める。標準ライブラリの名前は、すべてモジュールの名前で修飾して使う（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)）。

標準ライブラリの関数は、処理系の実装言語（Rust）で実装する組み込みの関数と、言語で書いた標準ライブラリのソースの関数から成る（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)）。どちらで実装するかは、prelude に入るかどうかと関係しない（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。関数を引数にとる関数は標準ライブラリのソースで定める（[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の Σ）。

## 仕様

### 範囲と名前の付け方

【決定】最小実行版の prelude には、仕様の各章・完了条件・ベンチマークが参照する関数に加え、文字列とリストのよく使う操作と、`Option`・`Result` をつなぐ関数を入れる。Unicode の文字の性質の規則に依る関数（大文字と小文字の変換、文字の分類）は初回リリース版に回し、最小実行版で文字を分類する関数は ASCII の範囲だけを扱って名前にそれを示す（[ADR 0042](../decisions/0042-minimal-prelude-scope.md)）。

【決定】標準ライブラリの型と関数の名前は、省略しない英単語で書く（`Integer`、`Boolean`、`Character`、`Console.writeLine`、`Process.arguments`。[ADR 0101](../decisions/0101-unabbreviated-names.md)）。ただし、`Float` と、利用者が頭字語のまま見聞きする語（次の段落）は例外とする。

【決定】標準ライブラリの名前の中の頭字語（IO、UTF-8、ASCII など）は、すべて大文字で書く（`IOError`、`IOErrorKind.InvalidUTF8`、`Character.isASCIIDigit`）。ただし、小文字で始まる名前の先頭に頭字語を置くときは、頭字語をすべて小文字で書く。利用者が付ける名前に対しては、処理系はこの規則を検査しない（[ADR 0091](../decisions/0091-acronyms-in-uppercase.md)）。

【方針】初回リリース版では、標準ライブラリの型・関数・構成子・定数の説明を、利用者のモジュールと同じくドキュメントコメント（`///`）で持つ（[ADR 0125](../decisions/0125-doc-comments.md)）。MCP サーバと LSP サーバは、利用者の宣言と同じ方法で標準ライブラリの説明を示す。

【方針】関数の引数は、操作の対象（文字列、リスト、`Option` など）を第 1 引数に置く。パイプ（`xs |> List.map(f)`）で対象を渡せるようにするためである。

【方針】以下の表の型の欄の `function[T, effect E](A1, …) -> B uses E` は、型パラメータとエフェクト変数を持つ関数の型を表す本章の表記である。関数の宣言の型パラメータの並び（[構文](../01-spec/01-02-syntax.md)）と同じ意味を持つ。

【方針】以下の表の「実装」の欄は、関数を組み込みの関数（Rust）として実装する（「組み込み」）か、標準ライブラリのソース（言語）で定める（「ソース」）かを示す。この区別は利用者からは見えない。「実行時エラー」の欄が空の関数は、実行時エラーを起こさない。

### 名前空間と prelude（初回リリース版）

【決定】標準ライブラリは、処理系と一緒に配るモジュールの全体であり、名前空間 `Benitoite` の下に置く。prelude は、標準ライブラリのうち import なしで使える部分である（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。

| 部分 | モジュール・型・エフェクト | 使い方 |
|---|---|---|
| prelude | 基本型とその関数のモジュール（`Integer`・`Float`・`Decimal`・`Byte`・`Character`・`String`・`Boolean`）、`List`・`Map`・`Set`・`Bytes`・`ByteOrder`、`Option`・`Result`・`Pair`・`Triple`、`IOError`・`IOErrorKind`、`NetworkError`・`NetworkErrorKind`、`RoundingMode`、`Reference`、`Lazy`、`Task`・`TaskGroup`、`Assert`、エフェクト `State`、モジュール `IO` | import なしで `List.map` と書ける。`Benitoite.List.map` とも書ける |
| 標準の型クラス | `Benitoite.Trait`（後述の「標準の型クラス（初回リリース版）」） | `import Benitoite.Trait` で取り込み、`Trait.Monad.flatMap` と書く |
| IO を行うモジュール | `Benitoite.IO.Console`・`Benitoite.IO.File`・`Benitoite.IO.Process`・`Benitoite.IO.Clock`・`Benitoite.IO.Random`（[IO のモジュール](03-07-io-modules.md)） | `import Benitoite.IO.Console` で取り込み、`Console.writeLine` と書く |
| ネットワークの操作を行うモジュール | `Benitoite.Network.Http`（[ネットワークのモジュール](03-09-network.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)） | `import Benitoite.Network.Http` で取り込み、`Http.get` と書く |
| テキストとデータを扱うモジュール | `Benitoite.Path`・`Benitoite.Json`・`Benitoite.Regex`・`Benitoite.Csv`・`Benitoite.Time`・`Benitoite.Encoding`・`Benitoite.Hash`（[テキストとデータの処理](03-08-text-and-data.md)、[ADR 0137](../decisions/0137-first-release-library-scope.md)） | `import Benitoite.Json` で取り込み、`Json.parse` と書く |

- prelude のモジュール `IO`（`Benitoite.IO`）は、`State` と `Benitoite.IO` の下のモジュールのエフェクトをまとめたエフェクト `IO.All` だけを持つ。ネットワークのエフェクトは `IO.All` に含まれない（[エフェクト](../01-spec/01-07-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。`uses IO.All` は import なしに書ける。`Benitoite.IO` の下のモジュールの関数を呼ぶには import が要る。
- import なしに完全な名前で書けるのは prelude だけである。`Benitoite.IO.Console.writeLine` を import なしに書くことはできない。
- 利用者の宣言や取り込みが prelude と同じ名前を持つときの扱いと、根の直下の `Benitoite` を取り込めないことは、[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)で定める。

```text
import Benitoite.IO.Console

function main(): Unit uses Console.Write
  let doubled = List.map([1, 2, 3], lambda(x) return x * 2 end lambda)
  Console.writeLine(Integer.toString(List.length(doubled)))
end function
```

最小実行版には `Benitoite` の名前空間と import がなく、`Console`・`File`・`Process` も prelude にある。最小実行版のスクリプトを初回リリース版で動かすには、`import Benitoite.IO.Console` などを加え、`uses IO` を `uses IO.All` などに改める。処理系は、足りない import と `uses IO.All` を修正案として示す。

### 関数を引数にとる関数の共通の規則

【方針】関数を引数にとる関数は、次の規則に従う。

- 受け取った関数を、要素を先頭から順に一つずつ渡して呼ぶ。同じ要素について二度呼ばない。受け取った関数が IO を行うとき、その IO はこの順に起こる。
- `List.any`・`List.all`・`List.find` は、結果が決まった時点で残りの要素について関数を呼ばない。
- 受け取った関数の呼び出しで実行時エラーが起きたら、そこで止まる（[評価意味論](../01-spec/01-08-evaluation.md)）。
- 型は、受け取る関数のエフェクトをエフェクト変数 `E` で表し、同じ `E` を自身のエフェクトとする（[ADR 0008](../decisions/0008-effect-variables.md)）。

【方針】標準ライブラリのソースの関数は、リストの長さに比例する深さの末尾でない再帰を使わない。長いリストを処理しても、呼び出しの入れ子が深くならないようにするためである（[ADR 0030](../decisions/0030-call-stack-size-limit.md)）。

### 作る値の大きさの上限

【決定】文字列かリストを新しく作る組み込みの関数（`String.repeat`・`String.join`・`String.replace`・`String.fromCharacters`・`String.split`・`String.lines`・`String.characters`・`String.toUppercase`・`String.toLowercase`・`List.range`・`List.prepend`・`List.append`・`List.concatenate` など）と、`String` の `+` は、結果の大きさを値を作る前に計算し、処理系の上限を超えるときは、値を作らずに資源の不足で停止する（[ADR 0049](../decisions/0049-size-limit-for-built-values.md)、[評価意味論](../01-spec/01-08-evaluation.md)）。

【方針】上限は、文字列が 2^30 バイト、リストが 2^24 要素である。上限の値と、結果の大きさの計算の仕方は[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」で定める。

### Integer

| 関数 | 型 | 値 | 実行時エラー | 実装 |
|---|---|---|---|---|
| `Integer.toString(n)` | `function(Integer) -> String` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「型の変換」 | | 組み込み |
| `Integer.parse(s)` | `function(String) -> Option[Integer]` | 同上 | | 組み込み |
| `Integer.toFloat(n)` | `function(Integer) -> Float` | 同上 | | 組み込み |
| `Integer.floorDivide(a, b)` | `function(Integer, Integer) -> Integer` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「Integer」 | 同左 | 組み込み |
| `Integer.floorModulo(a, b)` | `function(Integer, Integer) -> Integer` | 同上 | 同左 | 組み込み |
| `Integer.absolute(n)` | `function(Integer) -> Integer` | `n` の絶対値 | `n` が −2^63 | 組み込み |
| `Integer.minimum(a, b)` | `function(Integer, Integer) -> Integer` | 小さいほう | | 組み込み |
| `Integer.maximum(a, b)` | `function(Integer, Integer) -> Integer` | 大きいほう | | 組み込み |

初回リリース版では、ビット演算の関数（`Integer.bitwiseAnd`・`bitwiseOr`・`bitwiseExclusiveOr`・`bitwiseNot`・`shiftLeft`・`shiftRight`・`shiftRightUnsigned`）を加える。意味は[基本型の意味論](../01-spec/01-04-types-basic.md)の「ビット演算（初回リリース版）」で定め、すべて組み込みで実装する（[ADR 0106](../decisions/0106-bitwise-functions.md)）。

### Float

| 関数 | 型 | 値 | 実行時エラー | 実装 |
|---|---|---|---|---|
| `Float.toString(x)` | `function(Float) -> String` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「型の変換」 | | 組み込み |
| `Float.parse(s)` | `function(String) -> Option[Float]` | 同上 | | 組み込み |
| `Float.truncate(x)` | `function(Float) -> Option[Integer]` | 同上 | | 組み込み |
| `Float.isNaN(x)` | `function(Float) -> Boolean` | `x` が NaN か | | 組み込み |
| `Float.absolute(x)` | `function(Float) -> Float` | 符号を正にした値。NaN は NaN | | 組み込み |
| `Float.floor(x)` | `function(Float) -> Float` | `x` 以下の最大の整数値。NaN・無限大・±0 はそのまま。結果が 0 のとき、符号は `x` と同じ | | 組み込み |
| `Float.ceiling(x)` | `function(Float) -> Float` | `x` 以上の最小の整数値。NaN・無限大・±0 はそのまま。結果が 0 のとき、符号は `x` と同じ（`Float.ceiling(-0.5)` は `-0.0`） | | 組み込み |
| `Float.round(x)` | `function(Float) -> Float` | 最も近い整数値。ちょうど中間なら 0 から遠いほう。NaN・無限大・±0 はそのまま。結果が 0 のとき、符号は `x` と同じ（`Float.round(-0.4)` は `-0.0`） | | 組み込み |
| `Float.squareRoot(x)` | `function(Float) -> Float` | IEEE 754 の平方根。負の数は NaN | | 組み込み |

### Character

| 関数 | 型 | 値 | 実行時エラー | 実装 |
|---|---|---|---|---|
| `Character.toInteger(c)` | `function(Character) -> Integer` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「Character」 | | 組み込み |
| `Character.fromInteger(n)` | `function(Integer) -> Option[Character]` | 同上 | | 組み込み |
| `Character.toString(c)` | `function(Character) -> String` | 同上 | | 組み込み |
| `Character.isASCIIDigit(c)` | `function(Character) -> Boolean` | `c` が `'0'`〜`'9'` か | | 組み込み |
| `Character.isASCIIWhitespace(c)` | `function(Character) -> Boolean` | `c` が ASCII の空白（U+0020、U+0009、U+000A、U+000D）か | | 組み込み |
| `Character.isAlphabetic(c)` | `function(Character) -> Boolean` | `c` が Unicode の Alphabetic の性質を持つか（初回リリース版） | | 組み込み |
| `Character.isNumeric(c)` | `function(Character) -> Boolean` | `c` の Unicode の一般カテゴリが Nd・Nl・No のどれかか（初回リリース版） | | 組み込み |
| `Character.isWhitespace(c)` | `function(Character) -> Boolean` | `c` が Unicode の White_Space の性質を持つか（初回リリース版） | | 組み込み |
| `Character.isUppercase(c)` | `function(Character) -> Boolean` | `c` が Unicode の Uppercase の性質を持つか（初回リリース版） | | 組み込み |
| `Character.isLowercase(c)` | `function(Character) -> Boolean` | `c` が Unicode の Lowercase の性質を持つか（初回リリース版） | | 組み込み |
| `Character.toUppercase(c)` | `function(Character) -> String` | `c` を大文字にした文字列（初回リリース版。後述） | | 組み込み |
| `Character.toLowercase(c)` | `function(Character) -> String` | `c` を小文字にした文字列（初回リリース版。後述） | | 組み込み |

【決定】初回リリース版では、Unicode の文字の性質に依る分類と変換の関数を加える（[ADR 0169](../decisions/0169-unicode-character-property-functions.md)）。

- 変換は、Unicode の大文字と小文字の対応のうち、地域に依らないもの（特殊な対応を含む）に従う。一つの文字が複数の文字に変わることがあるので、`Character` の変換の結果は `String` である（`Character.toUppercase('ß')` は `"SS"`）。対応のない文字は、その文字だけの文字列になる。
- 従う Unicode の版は、処理系を作った Rust の標準ライブラリが従う版である。処理系は、その版を `benitoite --version` の出力に示す（[CLI](../06-tooling/06-01-cli.md)）。ASCII の範囲だけを扱う関数（`Character.isASCIIDigit` など）の結果は、Unicode の版に依らない。

### String

位置と長さを扱う関数（`byteLength`・`byteSlice`・`characterCount`・`characterAt`・`characterSlice`）は[基本型の意味論](../01-spec/01-04-types-basic.md)で定め、すべて組み込みで実装する。

| 関数 | 型 | 値 | 実装 |
|---|---|---|---|
| `String.isEmpty(s)` | `function(String) -> Boolean` | `s` が空文字列か | 組み込み |
| `String.contains(s, sub)` | `function(String, String) -> Boolean` | `s` が `sub` を部分文字列として含むか。`sub` が空なら `true` | 組み込み |
| `String.startsWith(s, prefix)` | `function(String, String) -> Boolean` | `s` が `prefix` で始まるか | 組み込み |
| `String.endsWith(s, suffix)` | `function(String, String) -> Boolean` | `s` が `suffix` で終わるか | 組み込み |
| `String.byteIndexOf(s, sub)` | `function(String, String) -> Option[Integer]` | `sub` が最初に現れるバイト位置。現れなければ `Option.None`。`sub` が空なら `Option.Some(0)` | 組み込み |
| `String.split(s, sep)` | `function(String, String) -> List[String]` | 後述 | 組み込み |
| `String.lines(s)` | `function(String) -> List[String]` | 後述 | 組み込み |
| `String.join(xs, sep)` | `function(List[String], String) -> String` | `xs` の要素を、間に `sep` を挟んで順に連結した文字列。`xs` が空なら空文字列 | 組み込み |
| `String.trim(s)` | `function(String) -> String` | 先頭と末尾の ASCII の空白（`Character.isASCIIWhitespace`）を取り除いた文字列 | 組み込み |
| `String.replace(s, old, new)` | `function(String, String, String) -> String` | `s` の中の `old` の出現を、先頭から重ならないように順にすべて `new` に置き換えた文字列。`old` が空なら `s` | 組み込み |
| `String.repeat(s, n)` | `function(String, Integer) -> String` | `s` を `n` 回連結した文字列。`n` が 0 以下なら空文字列 | 組み込み |
| `String.characters(s)` | `function(String) -> List[Character]` | `s` のスカラー値を順に並べたリスト | 組み込み |
| `String.fromCharacters(cs)` | `function(List[Character]) -> String` | `cs` の文字を順に連結した文字列 | 組み込み |
| `String.toUppercase(s)` | `function(String) -> String` | `s` の各文字を `Character.toUppercase` で変換して連結した文字列（初回リリース版） | 組み込み |
| `String.toLowercase(s)` | `function(String) -> String` | `s` を小文字にした文字列。ギリシャ文字のシグマは、語の終わりでは `ς` にする（初回リリース版） | 組み込み |

【方針】`String.split(s, sep)` は次の値を返す。

- `sep` が空でなければ、`s` を `sep` の出現（先頭から重ならないように探す）で区切った部分文字列の並び。区切りの前後や連続する区切りの間は空文字列になる。要素は常に 1 個以上であり、`s` が空なら `[""]` である（`String.split("a,,b", ",")` は `["a", "", "b"]`）。
- `sep` が空なら、`s` の各スカラー値を 1 文字の文字列にした並び。`s` が空なら `[]` である。

【方針】`String.lines(s)` は、`s` を行に分けた並びを返す。行は LF（U+000A）で区切り、各行の末尾に CR（U+000D）が一つあれば取り除く。`s` が LF で終わるとき、その後の空の行は含めない。`s` が空なら `[]` である（`String.lines("a\r\nb\n")` は `["a", "b"]`、`String.lines("a\n\nb")` は `["a", "", "b"]`）。

### List

【決定】`List[T]` は構成子を公開しない型であり、リストはリストリテラルと `List` モジュールの関数だけで作り、分解する（[ADR 0007](../decisions/0007-constructors-and-list.md)）。`List[T]` は、添字で引ける永続ベクタで表す（[ADR 0104](../decisions/0104-list-as-persistent-vector.md)）。表現は後述の「List の内部の表現」で定める。最小実行版の処理系は、単方向の連結リストで表している（[ADR 0041](../decisions/0041-list-as-linked-list.md)。0104 で置き換えた）。

| 関数 | 型 | 値 | 計算量 | 実装 |
|---|---|---|---|---|
| `List.length(xs)` | `function[T](List[T]) -> Integer` | 要素の数 | O(1) | 組み込み |
| `List.isEmpty(xs)` | `function[T](List[T]) -> Boolean` | 空か | O(1) | 組み込み |
| `List.head(xs)` | `function[T](List[T]) -> Option[T]` | 先頭の要素。空なら `Option.None` | O(log n) | 組み込み |
| `List.tail(xs)` | `function[T](List[T]) -> Option[List[T]]` | 先頭を除いたリスト。空なら `Option.None` | O(log n) | 組み込み |
| `List.get(xs, i)` | `function[T](List[T], Integer) -> Option[T]` | 位置 `i`（0 から数える）の要素。`i` が範囲の外なら `Option.None` | O(log n) | 組み込み |
| `List.prepend(xs, x)` | `function[T](List[T], T) -> List[T]` | 先頭に `x` を加えたリスト | O(log n) | 組み込み |
| `List.append(xs, x)` | `function[T](List[T], T) -> List[T]` | 末尾に `x` を加えたリスト | O(log n) | 組み込み |
| `List.concatenate(xs, ys)` | `function[T](List[T], List[T]) -> List[T]` | `xs` の後に `ys` を続けたリスト | O(log n) | 組み込み |
| `List.reverse(xs)` | `function[T](List[T]) -> List[T]` | 逆順のリスト | O(n) | 組み込み |
| `List.take(xs, n)` | `function[T](List[T], Integer) -> List[T]` | 先頭から `n` 個。`n` が 0 以下なら `[]`、長さ以上なら `xs` | O(log n) | 組み込み |
| `List.drop(xs, n)` | `function[T](List[T], Integer) -> List[T]` | 先頭の `n` 個を除いたリスト。`n` が 0 以下なら `xs`、長さ以上なら `[]` | O(log n) | 組み込み |
| `List.range(start, end)` | `function(Integer, Integer) -> List[Integer]` | `start` 以上 `end` 未満の整数を昇順に並べたリスト。`end` が `start` 以下なら `[]` | O(end − start) | 組み込み |
| `List.contains(xs, x)` | `function[T: equality](List[T], T) -> Boolean` | `x` と `=` で等しい要素があるか | O(n) | 組み込み |
| `List.sort(xs)` | `function[T: ordered](List[T]) -> List[T]` | 昇順に並べ替えたリスト（後述） | O(n log n) | 組み込み |
| `List.map(xs, f)` | `function[T, U, effect E](List[T], function(T) -> U uses E) -> List[U] uses E` | 各要素に `f` を適用した値のリスト | O(n) | ソース |
| `List.filter(xs, p)` | `function[T, effect E](List[T], function(T) -> Boolean uses E) -> List[T] uses E` | `p` が `true` を返す要素だけを、順序を保って並べたリスト | O(n) | ソース |
| `List.fold(xs, init, f)` | `function[T, A, effect E](List[T], A, function(A, T) -> A uses E) -> A uses E` | `init` から始め、先頭の要素から順に `f(acc, x)` で畳み込んだ値 | O(n) | ソース |
| `List.forEach(xs, f)` | `function[T, effect E](List[T], function(T) -> Unit uses E) -> Unit uses E` | 各要素に `f` を適用する | O(n) | ソース |
| `List.any(xs, p)` | `function[T, effect E](List[T], function(T) -> Boolean uses E) -> Boolean uses E` | `p` が `true` を返す要素があるか | O(n) | ソース |
| `List.all(xs, p)` | `function[T, effect E](List[T], function(T) -> Boolean uses E) -> Boolean uses E` | すべての要素で `p` が `true` を返すか。空なら `true` | O(n) | ソース |
| `List.find(xs, p)` | `function[T, effect E](List[T], function(T) -> Boolean uses E) -> Option[T] uses E` | `p` が `true` を返す最初の要素 | O(n) | ソース |

計算量の n は `xs` の長さ（`List.concatenate` では二つのリストの長さの和）である。O(log n) の対数の底は木の分岐の数（32）であり、実用上の長さでは小さい定数になる。関数を引数にとる関数の計算量は、受け取った関数の呼び出しを 1 と数えたものである。

`List.contains` の型の `equality` は、`T` が等値の型であるという組み込みの制約である。利用者も関数の型に書ける（[型システム](../01-spec/01-06-type-system.md)、[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）。`List.sort` の型の `ordered` は、`T` が順序の比較演算子の型の集まり（[型システム](../01-spec/01-06-type-system.md)の「演算子の型付け」。初回リリース版では `Byte`・`Decimal` を含む）のどれかであるという制約である。演算子の型の集まりの制約は、利用者は関数の型に書けず、標準ライブラリの関数だけが持てる（[ADR 0009](../decisions/0009-typing-without-type-classes.md)、[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。

【方針】`List.sort` は安定な並べ替えであり、等しい要素の順序を保つ。順序は `<` に従う（[基本型の意味論](../01-spec/01-04-types-basic.md)）。ただし `Float` の NaN は、どの値よりも後に置き、NaN どうしは元の順序を保つ。`0.0` と `-0.0` は等しいものとして扱う。

末尾への追加と添字での参照は対数時間なので、`List.append` で末尾に一つずつ加えてリストを作ってよく、添字で要素を順に読んでもよい。

### Option

`Option` の関数は、すべて標準ライブラリのソースで定める。

【決定】関数の名前は Rust の名前を lowerCamelCase にしたものに合わせ、`Option.None` のときに実行時エラーになる `unwrap` などは設けない（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)）。ただし、`Result` の失敗の構成子を `Result.Error` としたので、Rust の名前の `err` に当たる部分は `Error` とする（`Result.mapError`、`Result.isError`。[ADR 0099](../decisions/0099-qualified-option-result-constructors.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `Option.map(o, f)` | `function[T, U, effect E](Option[T], function(T) -> U uses E) -> Option[U] uses E` | `Option.Some(x)` なら `Option.Some(f(x))`、`Option.None` なら `Option.None` |
| `Option.andThen(o, f)` | `function[T, U, effect E](Option[T], function(T) -> Option[U] uses E) -> Option[U] uses E` | `Option.Some(x)` なら `f(x)`、`Option.None` なら `Option.None` |
| `Option.unwrapOr(o, d)` | `function[T](Option[T], T) -> T` | `Option.Some(x)` なら `x`、`Option.None` なら `d` |
| `Option.isSome(o)` | `function[T](Option[T]) -> Boolean` | `Option.Some` か |
| `Option.isNone(o)` | `function[T](Option[T]) -> Boolean` | `Option.None` か |
| `Option.okOr(o, e)` | `function[T, X](Option[T], X) -> Result[T, X]` | `Option.Some(x)` なら `Result.Ok(x)`、`Option.None` なら `Result.Error(e)` |

### Result

`Result` の関数は、すべて標準ライブラリのソースで定める。名前の付け方は `Option` と同じである（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `Result.map(r, f)` | `function[T, U, X, effect E](Result[T, X], function(T) -> U uses E) -> Result[U, X] uses E` | `Result.Ok(x)` なら `Result.Ok(f(x))`、`Result.Error(e)` なら `Result.Error(e)` |
| `Result.mapError(r, f)` | `function[T, X, Y, effect E](Result[T, X], function(X) -> Y uses E) -> Result[T, Y] uses E` | `Result.Ok(x)` なら `Result.Ok(x)`、`Result.Error(e)` なら `Result.Error(f(e))` |
| `Result.andThen(r, f)` | `function[T, U, X, effect E](Result[T, X], function(T) -> Result[U, X] uses E) -> Result[U, X] uses E` | `Result.Ok(x)` なら `f(x)`、`Result.Error(e)` なら `Result.Error(e)` |
| `Result.unwrapOr(r, d)` | `function[T, X](Result[T, X], T) -> T` | `Result.Ok(x)` なら `x`、`Result.Error` なら `d` |
| `Result.isOk(r)` | `function[T, X](Result[T, X]) -> Boolean` | `Result.Ok` か |
| `Result.isError(r)` | `function[T, X](Result[T, X]) -> Boolean` | `Result.Error` か |
| `Result.ok(r)` | `function[T, X](Result[T, X]) -> Option[T]` | `Result.Ok(x)` なら `Option.Some(x)`、`Result.Error` なら `Option.None` |

### Assert（初回リリース版）

【決定】prelude のモジュール `Assert` は、テストの期待の確認を表すエフェクト `Assert.Check` を宣言する。その操作（`Assert.equal`・`Assert.notEqual`・`Assert.isTrue`・`Assert.fail`）は、[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める（[ADR 0120](../decisions/0120-test-functions-and-assert-effect.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。

【方針】標準ライブラリの宣言は、非推奨にするときに `@deprecated` の属性を付ける（[構文](../01-spec/01-02-syntax.md)の「属性（初回リリース版）」、[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md)）。非推奨にした宣言を取り除く時期は、互換性を壊す変更の範囲（[OPEN-040](../open-issues.md#open-040)）とあわせて決める。

### Task と TaskGroup（初回リリース版）

【決定】タスクを起動して結果を待つ `Task` モジュールの関数と、タスクの集まりのリソースの型 `TaskGroup` は、[並行処理](../01-spec/01-11-concurrency.md)で定める（[ADR 0115](../decisions/0115-structured-io-concurrency.md)）。どれも組み込みで実装する。`Task` と `TaskGroup` は prelude に入る。`Task` と `TaskGroup` の関数のエフェクトは、prelude の `State` である。これらはエフェクトの操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。`TaskGroup.open()` は `with` の束縛の式としてだけ書ける（[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)）。時間の経過を待つ関数は `Benitoite.IO.Clock` の `Clock.sleep` である。`Task[T]` は中身を見せない型であり、等値の型ではない。HTTP のサーバとクライアントは[ネットワークのモジュール](03-09-network.md)で定める。

### Reference と Lazy（初回リリース版）

【決定】可変のセルの型 `Reference[T]` と、明示遅延の型 `Lazy[T]` は prelude に入る。`Reference` の関数（`Reference.new`・`Reference.get`・`Reference.set`・`Reference.update`）は[エフェクト](../01-spec/01-07-effects.md)の「可変のセル（初回リリース版）」で、`Lazy.force` は[評価意味論](../01-spec/01-08-evaluation.md)の「明示遅延（初回リリース版）」と[型システム](../01-spec/01-06-type-system.md)の「明示遅延の型（初回リリース版）」で定める。どれも組み込みで実装する。`Reference.update` と `Lazy.force` は、受け取った関数を呼ぶので、専用の命令で実装する（[ランタイム](../02-impl/02-09-runtime.md)）。

### Byte（初回リリース版）

【決定】`Byte` は 0 以上 255 以下の整数の基本型である（[ADR 0105](../decisions/0105-byte-type.md)）。変換の関数（`Byte.fromInteger`・`Byte.toInteger`・`Byte.toString`）とビット演算の関数は、[基本型の意味論](../01-spec/01-04-types-basic.md)の「Byte（初回リリース版）」と「ビット演算（初回リリース版）」で定め、すべて組み込みで実装する。

### Decimal と RoundingMode（初回リリース版）

【決定】`Decimal` は 10 進の小数の基本型である（[ADR 0114](../decisions/0114-decimal-type.md)）。丸めの関数（`Decimal.round`・`Decimal.absolute`）と変換の関数（`Decimal.fromInteger`・`Decimal.truncate`・`Decimal.toFloat`・`Decimal.fromFloat`・`Decimal.toString`・`Decimal.parse`）は、[基本型の意味論](../01-spec/01-04-types-basic.md)の「Decimal（初回リリース版）」と「型の変換」で定め、すべて組み込みで実装する。丸め方を表す `RoundingMode` は、構成子を公開する代数的データ型である（[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)）。

### Pair と Triple（初回リリース版）

【決定】組の型 `Pair[A, B]` と `Triple[A, B, C]` は、構成子が一つだけの代数的データ型である（[ADR 0102](../decisions/0102-pair-and-triple.md)、[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)）。4 要素以上の組は、利用者が `record` を宣言して書く。

| 関数 | 型 | 値 | 実装 |
|---|---|---|---|
| `Pair.first(p)` | `function[A, B](Pair[A, B]) -> A` | 1 番目の要素 | ソース |
| `Pair.second(p)` | `function[A, B](Pair[A, B]) -> B` | 2 番目の要素 | ソース |
| `Triple.first(t)` | `function[A, B, C](Triple[A, B, C]) -> A` | 1 番目の要素 | ソース |
| `Triple.second(t)` | `function[A, B, C](Triple[A, B, C]) -> B` | 2 番目の要素 | ソース |
| `Triple.third(t)` | `function[A, B, C](Triple[A, B, C]) -> C` | 3 番目の要素 | ソース |

### Map と Set（初回リリース版）

【決定】`Map[K, V]` と `Set[T]` は、構成子を公開しない永続コレクションである（[ADR 0103](../decisions/0103-map-and-set-ordered-by-key.md)）。更新する関数は新しい値を返し、元の値は変わらない。鍵と集合の要素の型は、鍵の型（[型システム](../01-spec/01-06-type-system.md)の「鍵の型（初回リリース版）」）でなければならない。反復の順序（`Map.toList` などが要素を並べる順序）は、後述の鍵の順序の昇順である。

| 関数 | 型 | 値 | 計算量 |
|---|---|---|---|
| `Map.empty()` | `function[K: key, V]() -> Map[K, V]` | 空のマップ | O(1) |
| `Map.fromList(ps)` | `function[K: key, V](List[Pair[K, V]]) -> Map[K, V]` | 組を順に加えたマップ。同じ鍵があれば後の組の値を使う | O(n log n) |
| `Map.toList(m)` | `function[K: key, V](Map[K, V]) -> List[Pair[K, V]]` | 鍵の順序で並べた組のリスト | O(n) |
| `Map.get(m, k)` | `function[K: key, V](Map[K, V], K) -> Option[V]` | `k` の値。なければ `Option.None` | O(log n) |
| `Map.set(m, k, v)` | `function[K: key, V](Map[K, V], K, V) -> Map[K, V]` | `k` の値を `v` にしたマップ | O(log n) |
| `Map.remove(m, k)` | `function[K: key, V](Map[K, V], K) -> Map[K, V]` | `k` を除いたマップ。`k` がなければ `m` と等しい | O(log n) |
| `Map.contains(m, k)` | `function[K: key, V](Map[K, V], K) -> Boolean` | `k` があるか | O(log n) |
| `Map.size(m)` | `function[K: key, V](Map[K, V]) -> Integer` | 組の数 | O(1) |
| `Map.keys(m)` | `function[K: key, V](Map[K, V]) -> List[K]` | 鍵の順序で並べた鍵のリスト | O(n) |
| `Map.values(m)` | `function[K: key, V](Map[K, V]) -> List[V]` | 鍵の順序で並べた値のリスト | O(n) |

| 関数 | 型 | 値 | 計算量 |
|---|---|---|---|
| `Set.empty()` | `function[T: key]() -> Set[T]` | 空の集合 | O(1) |
| `Set.fromList(xs)` | `function[T: key](List[T]) -> Set[T]` | `xs` の要素の集合 | O(n log n) |
| `Set.toList(s)` | `function[T: key](Set[T]) -> List[T]` | 鍵の順序で並べた要素のリスト | O(n) |
| `Set.contains(s, x)` | `function[T: key](Set[T], T) -> Boolean` | `x` を含むか | O(log n) |
| `Set.add(s, x)` | `function[T: key](Set[T], T) -> Set[T]` | `x` を加えた集合 | O(log n) |
| `Set.remove(s, x)` | `function[T: key](Set[T], T) -> Set[T]` | `x` を除いた集合 | O(log n) |
| `Set.size(s)` | `function[T: key](Set[T]) -> Integer` | 要素の数 | O(1) |
| `Set.union(a, b)`・`Set.intersection(a, b)`・`Set.difference(a, b)` | `function[T: key](Set[T], Set[T]) -> Set[T]` | 和集合・共通部分・差集合 | O(m log(n/m + 1))。m と n は小さいほうと大きいほうの要素の数 |

表の型の `key` は、`K` と `T` が鍵の型であるという組み込みの制約である。利用者も関数の型に書けるので、`Map` と `Set` を使う汎用の関数（`function countBy[T, K: key](xs: List[T], f: function(T) -> K): Map[K, Integer]` など）を書ける（[型システム](../01-spec/01-06-type-system.md)、[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）。

【決定】`Map` と `Set` の関数を引数にとる関数は、次のとおりとする（[ADR 0171](../decisions/0171-map-set-higher-order-functions.md)）。どれも標準ライブラリのソースで書き、受け取った関数を鍵の順序で呼ぶ（前述の「関数を引数にとる関数の共通の規則」）。計算量は、受け取った関数の呼び出しを 1 と数えたものである。

| 関数 | 型 | 値 | 計算量 |
|---|---|---|---|
| `Map.map(m, f)` | `function[K: key, V, U, effect E](Map[K, V], function(K, V) -> U uses E) -> Map[K, U] uses E` | 各組の値を `f(k, v)` に替えたマップ。鍵は変えない | O(n) |
| `Map.filter(m, p)` | `function[K: key, V, effect E](Map[K, V], function(K, V) -> Boolean uses E) -> Map[K, V] uses E` | `p(k, v)` が `true` を返す組だけのマップ | O(n) |
| `Map.fold(m, initial, f)` | `function[K: key, V, A, effect E](Map[K, V], A, function(A, K, V) -> A uses E) -> A uses E` | `initial` から始め、鍵の順に `f(acc, k, v)` で畳み込んだ値 | O(n) |
| `Map.forEach(m, f)` | `function[K: key, V, effect E](Map[K, V], function(K, V) -> Unit uses E) -> Unit uses E` | 各組に `f` を適用する | O(n) |
| `Set.map(s, f)` | `function[T: key, U: key, effect E](Set[T], function(T) -> U uses E) -> Set[U] uses E` | 各要素に `f` を適用した値の集合。同じ値になった要素は一つにまとめる | O(n log n) |
| `Set.filter(s, p)` | `function[T: key, effect E](Set[T], function(T) -> Boolean uses E) -> Set[T] uses E` | `p` が `true` を返す要素だけの集合 | O(n) |
| `Set.fold(s, initial, f)` | `function[T: key, A, effect E](Set[T], A, function(A, T) -> A uses E) -> A uses E` | `initial` から始め、鍵の順に `f(acc, x)` で畳み込んだ値 | O(n) |
| `Set.forEach(s, f)` | `function[T: key, effect E](Set[T], function(T) -> Unit uses E) -> Unit uses E` | 各要素に `f` を適用する | O(n) |

【決定】`Map` と `Set` のリテラルの構文はない（[ADR 0103](../decisions/0103-map-and-set-ordered-by-key.md)）。`Map.fromList`・`Set.fromList`・`Map.empty()`・`Set.empty()` は、定数式に書ける（[構文](../01-spec/01-02-syntax.md)の「定数（初回リリース版）」、[ADR 0136](../decisions/0136-map-and-set-in-constants.md)）。定数式の外で、`Map.fromList` の引数のリストのリテラルに、鍵が定数式で同じ値になる組が二つ以上あるときは、処理系は警告を出す。`Set.fromList` の要素も同じである。警告は検査と実行を止めず、値は表のとおり後の組の値を使う。定数式の中では誤りとする。

【方針】鍵の順序は、鍵の型の値に定める全順序であり、次のとおりとする。

- `Integer`・`Byte`・`Decimal` は数の大小、`String` は `<` と同じ順序（スカラー値の列の辞書式）、`Character` はスカラー値の大小による。`Boolean` は `false` を `true` より前、`Unit` の値は一つである。
- 代数的データ型の値は、まず構成子を型の宣言に書いた順で比べ、構成子が同じなら引数を前から順に比べる（辞書式）。初回リリース版のレコードは、フィールドを宣言の順に並べた構成子が一つの型として比べる。`Pair` と `Triple` も同じである。
- `List`・`Bytes` は、要素を前から順に比べ、一方が他方の先頭の部分に当たるときは短いほうを前とする（辞書式）。
- `Set` は、要素を鍵の順序で並べたリストとして比べる。`Map` は、組を鍵の順序で並べたリストとして比べる。

`Decimal` の値は、小数の桁数が違っても数が等しければ同じ鍵である（`1.0m` と `1.00m`）。`Map.set`・`Set.add`・`Map.fromList` などで、同じ鍵が既にあるマップや集合に鍵を加えるときは、元の鍵を保つ（`Map.set` は値だけを替える）。

【方針】`Map` と `Set` は、平衡二分木で表す。木の種類（重みで平衡させる木）とノードの持つものは[仮想機械](../02-impl/02-08-vm.md)の「値の表現」で定める。ノードは作った後に変更せず、更新は根から変わるノードまでの道筋だけを写す。処理系のテストでは、リストと同じく（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)）、操作の列を単純なモデル（Rust の `BTreeMap`・`BTreeSet`）と同時に適用し、内容と鍵の順序が一致することを確かめる。木の平衡の条件は、テストではなく、デバッグ用のビルドで実装の中の `debug_assert!` として確かめる。

### Bytes と ByteOrder（初回リリース版）

【決定】`Bytes` は、変更できないバイト列の型であり、要素は `Byte` である（[ADR 0107](../decisions/0107-bytes.md)）。`Bytes` は等値の型である。リテラルはなく、次の関数で作る。位置を指定する関数は、位置が正しくなければ `Option.None` を返す。

| 関数 | 型 | 値 | 計算量 |
|---|---|---|---|
| `Bytes.empty()` | `function() -> Bytes` | 空のバイト列 | O(1) |
| `Bytes.fromList(bs)` | `function(List[Byte]) -> Bytes` | `bs` を並べたバイト列 | O(n) |
| `Bytes.fromIntegers(ns)` | `function(List[Integer]) -> Option[Bytes]` | `ns` の各値を `Byte` にして並べたバイト列。0〜255 の外の値があれば `Option.None` | O(n) |
| `Bytes.fromHex(s)` | `function(String) -> Option[Bytes]` | 16 進の表記を 2 桁ずつ 1 バイトとして読んだバイト列。後述の規則に合わなければ `Option.None` | O(n) |
| `Bytes.fromBinary(s)` | `function(String) -> Option[Bytes]` | 2 進の表記を 8 桁ずつ 1 バイトとして読んだバイト列。後述の規則に合わなければ `Option.None` | O(n) |
| `Bytes.toList(b)` | `function(Bytes) -> List[Byte]` | 要素のリスト | O(n) |
| `Bytes.toHex(b)` | `function(Bytes) -> String` | 各バイトを小文字の 16 進 2 桁で表し、区切りなしで並べた文字列 | O(n) |
| `Bytes.toBinary(b)` | `function(Bytes) -> String` | 各バイトを 2 進 8 桁で表し、区切りなしで並べた文字列 | O(n) |
| `Bytes.length(b)` | `function(Bytes) -> Integer` | バイト数 | O(1) |
| `Bytes.get(b, i)` | `function(Bytes, Integer) -> Option[Byte]` | 位置 `i` のバイト | O(1) |
| `Bytes.slice(b, start, end)` | `function(Bytes, Integer, Integer) -> Option[Bytes]` | 位置 `start` から `end` の手前までのバイト列 | O(1) |
| `Bytes.concatenate(a, b)` | `function(Bytes, Bytes) -> Bytes` | `a` の後に `b` を続けたバイト列 | O(n) |
| `Bytes.readUnsigned(b, offset, count, order)` | `function(Bytes, Integer, Integer, ByteOrder) -> Option[Integer]` | `offset` から `count` バイトを、符号なしの整数として `order` のバイト順で読んだ値 | O(count) |
| `Bytes.readSigned(b, offset, count, order)` | `function(Bytes, Integer, Integer, ByteOrder) -> Option[Integer]` | 同じく、2 の補数の符号付きの整数として読んだ値 | O(count) |
| `Bytes.fromUnsigned(n, count, order)` | `function(Integer, Integer, ByteOrder) -> Option[Bytes]` | `n` を符号なしの `count` バイトで表したバイト列。収まらなければ `Option.None` | O(count) |
| `Bytes.fromSigned(n, count, order)` | `function(Integer, Integer, ByteOrder) -> Option[Bytes]` | `n` を 2 の補数の符号付きの `count` バイトで表したバイト列。収まらなければ `Option.None` | O(count) |
| `String.toUTF8(s)` | `function(String) -> Bytes` | `s` を UTF-8 で表したバイト列 | O(n) |
| `String.fromUTF8(b)` | `function(Bytes) -> Option[String]` | `b` を UTF-8 として読んだ文字列。正しくない UTF-8 なら `Option.None` | O(n) |

- `count` は 1 以上 8 以下でなければならず、外なら `Option.None` を返す。`Bytes.readUnsigned` の `count` が 8 で、値が `Integer` の範囲を超えるときも `Option.None` を返す。
- `Bytes.fromHex` と `Bytes.fromBinary` は、区切りとして `_` と空白（U+0020）を読み飛ばす。16 進の数字は大文字と小文字のどちらも受け付ける。区切りを除いた桁の数が、16 進では 2 の倍数、2 進では 8 の倍数でなければならない。
- `String.fromUTF8` は、正しくない UTF-8 を置き換えたり捨てたりしない（[ADR 0012](../decisions/0012-invalid-utf8-input.md) の方針と同じ）。先頭の BOM（U+FEFF）は取り除かない。
- `ByteOrder` は構成子 `ByteOrder.BigEndian`（上位のバイトが先）と `ByteOrder.LittleEndian`（下位のバイトが先）を持つ代数的データ型である（[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)）。
- ファイルとの読み書きは `File.readBytes`・`File.writeBytes` で行う（[エフェクト](../01-spec/01-07-effects.md)）。Base64 との変換は `Benitoite.Encoding`（[テキストとデータの処理](03-08-text-and-data.md)）で行う。UTF-8 以外の文字コードとの変換と、Base64 以外の符号化は、[OPEN-043](../open-issues.md#open-043) で検討する。

【方針】`Bytes` は、連続したバイトの領域と、その中の開始位置と長さで表す。領域は作った後に変更しない。`Bytes.slice` は、同じ領域を共有し、開始位置と長さだけを変えた値を作る。

### 標準の型クラス（初回リリース版）

【決定】標準ライブラリのモジュール `Benitoite.Trait` に、標準の型クラスと、比較の結果を表す型 `Ordering` を置く（[ADR 0134](../decisions/0134-standard-type-classes.md)）。`Benitoite.Trait` は prelude に入らない。使うには `import Benitoite.Trait` と書き、型クラスは `Trait.Monad`、メソッドは `Trait.Monad.flatMap(x, f)`、制約は `[F: Trait.Monad]` と書く。型クラスの宣言と実装の規則（上位の型クラス、戻り値の型で実装を選ぶメソッドを含む）は、[型システム](../01-spec/01-06-type-system.md)の「型クラス（初回リリース版）」で定める。

【決定】標準の型クラスのメソッドは、既存の関数と同じ役割を持つ（`Trait.Functor.map` と `Option.map`・`List.map`、`Trait.Foldable.fold` と `List.fold` など）。これは、学習の目的のために設けた原則 5（[目的と設計原則](../00-overview/00-01-goals.md)）の例外である。重複する既存の関数を隠すかは、初回リリース版を実装した後に評価して決める（[OPEN-050](../open-issues.md#open-050)）。

```text
import Benitoite.Trait

function pairUp[F[_]: Trait.Monad, A, B](xs: F[A], ys: F[B]): F[Pair[A, B]]
  return Trait.Monad.flatMap(xs, lambda(x)
    return Trait.Functor.map(ys, lambda(y) return Pair(x, y) end lambda)
  end lambda)
end function
```

`pairUp` の本体は、`F` の `Trait.Monad` の制約から、上位の型クラス `Trait.Functor` の制約も使える。`pairUp([1, 2], ["a", "b"])` の値は、4 つの組のリストである。

`Ordering` は、構成子 `Ordering.Less`・`Ordering.Equal`・`Ordering.Greater` を、この順に宣言した代数的データ型である。

以下の表と説明では、`Benitoite.Trait` の中の名前を、`Trait.` を省いて書く（`Show.show`、`Ordering.Less`）。利用者のプログラムでは、`import Benitoite.Trait` と書いたうえで、`Trait.Show.show`、`Trait.Ordering.Less` のように `Trait.` を付けて書く。

| 型クラス | 上位の型クラス | メソッド |
|---|---|---|
| `Show[T]` | — | `function show(x: T): String` |
| `Order[T]` | — | `function compare(x: T, y: T): Ordering` |
| `Semigroup[T]` | — | `function combine(x: T, y: T): T` |
| `Monoid[T]` | `Semigroup` | `function empty(): T` |
| `Functor[F[_]]` | — | `function map[A, B, effect E](x: F[A], f: function(A) -> B uses E): F[B] uses E` |
| `Applicative[F[_]]` | `Functor` | `function pure[A](x: A): F[A]`<br>`function apply[A, B, effect E](fs: F[function(A) -> B uses E], x: F[A]): F[B] uses E` |
| `Monad[F[_]]` | `Applicative` | `function flatMap[A, B, effect E](x: F[A], f: function(A) -> F[B] uses E): F[B] uses E` |
| `Foldable[F[_]]` | — | `function fold[A, B, effect E](x: F[A], initial: B, f: function(B, A) -> B uses E): B uses E` |
| `Traversable[F[_]]` | `Functor`、`Foldable` | `function traverse[G[_]: Applicative, A, B, effect E](x: F[A], f: function(A) -> G[B] uses E): G[F[B]] uses E` |

`Monoid.empty` と `Applicative.pure` は、型クラスの引数を戻り値の型にだけ含むので、呼び出した位置で求める型から実装を選ぶ。等値の型クラスは置かない。等値は `=` と組み込みの制約 `equality` で扱う（[型システム](../01-spec/01-06-type-system.md)、[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）。

【決定】標準ライブラリの型に、次の実装を置く。実装は、どれも標準ライブラリのソースで書く。

| 型クラス | 実装する型 |
|---|---|
| `Show`・`Order` | 基本型（`Integer`・`Float`・`Decimal`・`Byte`・`Character`・`String`・`Boolean`・`Unit`）、`List[T]`・`Option[T]`・`Pair[A, B]`・`Triple[A, B, C]`（要素の型が同じ型クラスを実装するとき） |
| `Show` | `Map[K, V]`・`Set[T]`（鍵・値・要素の型が `Show` を実装するとき） |
| `Semigroup`・`Monoid` | `String`・`List[T]`・`Map[K, V]`・`Set[T]` |
| `Functor`・`Applicative`・`Monad`・`Foldable`・`Traversable` | `Option`・`List` |

- `Result[T, X]` は型引数を二つとるので、型構成子を引数にとる型クラスを実装できない。型の部分適用がないからである（[型システム](../01-spec/01-06-type-system.md)の「高カインド型（初回リリース版）」）。
- 利用者の型の実装は `implement` で書く。実装を導出する仕組みは設けない。導出は [OPEN-046](../open-issues.md#open-046) で決める。
- メソッドの既定の実装はない。型クラスから派生する関数も、初回リリース版では置かない（[ADR 0171](../decisions/0171-map-set-higher-order-functions.md)）。
- 演算子と文字列補間は、型クラスを使わない（[ADR 0062](../decisions/0062-operators-stay-outside-traits.md)）。`Order` を実装した型に `<` は使えず、`Show` を実装した型の値を文字列補間に埋め込むことはできない。

【方針】`Show.show` は、値を式の書き方に近い文字列で表す。

- `Integer`・`Float`・`Decimal`・`Byte` は、それぞれの `toString` と同じ文字列である。`Boolean` は `true` か `false`、`Unit` は `()` である。
- `String` と `Character` は、リテラルの形で表す（`"a\"b"`、`'x'`）。引用符と、字句構造でエスケープが要る文字（[字句構造](../01-spec/01-01-lexical.md)）は、エスケープシーケンスで書く。`String` の `$` は `\$` で書く。
- `Option` は `Option.Some(1)`・`Option.None`、`Pair` と `Triple` は `Pair(1, "a")`・`Triple(1, "a", true)` の形で表す。
- `List` は `[1, 2, 3]` の形で表す。`Set` は `Set.fromList([1, 2])`、`Map` は `Map.fromList([Pair(1, "a")])` の形で、要素を鍵の順序で並べて表す。

【方針】`Order.compare` は、次の順序で比べる。

- 鍵の型の値は、鍵の順序（前節の「Map と Set（初回リリース版）」）と同じ順序で比べる。`Option` は構成子を宣言の順で比べるので、`Option.Some(x)` は `Option.None` より前（`Ordering.Less`）である。`List`・`Pair`・`Triple` は辞書式に比べる。
- `Float` は、`<` の順序に、次の規則を加えた全順序で比べる。NaN はどの値よりも大きく、NaN どうしは `Ordering.Equal` とする。`0.0` と `-0.0` は `Ordering.Equal` とする。この結果は `=` と異なる（NaN は自分自身と `=` で等しくない）。`Float` を含む `List`・`Option` などは、要素をこの順序で比べる。

【方針】`Semigroup.combine` と `Monoid.empty` は、次のとおりとする。

| 型 | `combine(x, y)` | `empty()` |
|---|---|---|
| `String` | `x` の後に `y` を続けた文字列（`x + y`） | `""` |
| `List[T]` | `List.concatenate(x, y)` | `[]` |
| `Map[K, V]` | 両方の組を合わせたマップ。同じ鍵があれば `y` の値を使う | `Map.empty()` |
| `Set[T]` | `Set.union(x, y)` | `Set.empty()` |

【方針】`Option` と `List` の、型構成子を引数にとる型クラスのメソッドは、次のとおりとする。

| メソッド | `Option` | `List` |
|---|---|---|
| `Functor.map(x, f)` | `Option.map(x, f)` | `List.map(x, f)` |
| `Applicative.pure(v)` | `Option.Some(v)` | `[v]` |
| `Applicative.apply(fs, x)` | `fs` と `x` がどちらも `Option.Some` なら、関数を値に適用した値の `Option.Some`。そうでなければ `Option.None` | `fs` の各関数を、`x` の各要素に適用した値のリスト。`fs` の前の関数から順に、各関数について `x` の前の要素から順に並べる |
| `Monad.flatMap(x, f)` | `Option.andThen(x, f)` | 各要素に `f` を適用したリストを、要素の順に連結したリスト |
| `Foldable.fold(x, initial, f)` | `Option.Some(v)` なら `f(initial, v)`、`Option.None` なら `initial` | `List.fold(x, initial, f)` |
| `Traversable.traverse(x, f)` | `Option.None` なら `Applicative.pure(Option.None)`。`Option.Some(v)` なら、`f(v)` の値の中身を `Functor.map` で `Option.Some` に包んだ値 | 要素を前から順に `f` に渡し、`Applicative.apply` で結果を前から順に組み合わせる |

関数を引数にとるメソッドは、受け取った関数を、表の値を作るのに必要な順に呼ぶ。`List` のメソッドは、要素を前から順に処理する。

### IO を行うモジュール（初回リリース版）

IO を行う関数は、`Benitoite.IO` の下のモジュールに置く。各モジュールの関数、エフェクト、要する権限、`IOError` の扱いは[IO のモジュール](03-07-io-modules.md)で定める。ネットワークの操作を行う関数は `Benitoite.Network` の下のモジュールに置き、[ネットワークのモジュール](03-09-network.md)で定める。

### List の内部の表現

【決定】`List[T]` は、添字で引ける永続ベクタ（persistent vector）で表す（[ADR 0104](../decisions/0104-list-as-persistent-vector.md)）。

【方針】永続ベクタは、分岐の数を 32 とする木（RRB 木、relaxed radix balanced tree）で表す。

- 要素は葉に最大 32 個ずつ入れ、内部のノードは最大 32 個の子を持つ。木の高さは、要素の数を n として O(log n) である。
- 末尾の葉は木とは別に持ち、末尾への追加をほとんどの場合に葉の写し一つで済ませる。
- 連結と分割（`List.concatenate`・`List.take`・`List.drop`・`List.tail`）のために、子の要素の数が揃わないノード（緩和したノード）を許し、そのノードに子ごとの要素の数の累積の表を持たせる。
- ノードと葉は、作った後に変更しない。更新は、根から変わる葉までの道筋のノードだけを写し、ほかのノードを共有する（構造共有、structural sharing）。
- リストどうしの `=` と `List.contains`、`List.sort` の比較は、処理系の再帰に頼らずに要素を辿る（[仮想機械](../02-impl/02-08-vm.md)）。

木の形の細部（緩和したノードを詰め直す条件など）は、実装プランで定める。

【決定】リストの次の不変条件は、それぞれ次の方法で確かめる（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)）。

| 不変条件 | 確かめ方 |
|---|---|
| 各ノードの要素の数の表は、子の要素の数の和と一致する。長さは、木と末尾の葉の要素の数の和である | 実装の中の `debug_assert!` で、デバッグビルドのときだけ確かめる。木の形の細部を変えるときは、この確認も一緒に書き直す |
| どの関数も、引数のリストのノードと葉を変更しない | 処理系のテストで、関数を呼ぶ前後で引数のリストの要素の並びが変わらないことを確かめる |
| 木の高さは、要素の数に対して O(log n) に収まる | [性能](../07-quality/07-02-performance.md)の測定で、大きなリストの添字の操作の時間として観察する |

【決定】リストの処理系のテストは、無作為に選んだ操作の列を、リストと単純なモデル（Rust の `Vec`）の両方に同じ順に適用し、要素の並びと長さが一致することを確かめる（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)、[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)）。テストはデバッグビルドで実行するので、操作のたびに一つ目の不変条件も確かめられる。

### 標準ライブラリのソースの書き方

【決定】標準ライブラリのソースは、利用者のモジュールと同じ構文のモジュールとして書く（[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。モジュール `Benitoite.X.Y` のソースは、処理系に同梱する標準ライブラリの根の下の `X/Y.bnt` に置く。読み込みと名前解決は[名前解決とモジュール読込](../02-impl/02-04-resolver.md)で定める。

- 利用者から見える関数・型・型クラス・エフェクトには `public` を付ける。補助の関数は `public` を付けずに書き、そのモジュールの中からだけ使う。
- 組み込みの関数は、本体のない関数の宣言に属性 `@builtin("名前")` を付けて宣言する。名前は処理系の組み込みの関数の表の鍵であり、型は宣言のシグネチャで与える。`@builtin` と本体のない宣言は、標準ライブラリのソースでだけ書ける。
- 順序の比較演算子の型の集まりの制約は、組み込みの制約 `ordered` として書く（[型システム](../01-spec/01-06-type-system.md)）。
- 中身を見せない組み込みの型（`Integer`・`List`・`Map` など）、操作を持たないエフェクト `State`、まとめたエフェクト `IO.All` は、ソースに宣言を置かず、処理系の表で与える。
- ほかのモジュールの関数は、利用者のモジュールと同じく import して使う。
- リストを辿る処理は、添字を累積の引数に持つ末尾再帰で書き、結果のリストは `List.append` で末尾に加えて作る。

```text
/// リストの各要素に f を適用したリストを返す。
public function map[T, U, effect E](xs: List[T], f: function(T) -> U uses E): List[U] uses E
  return mapFrom(xs, f, 0, [])
end function

function mapFrom[T, U, effect E](xs: List[T], f: function(T) -> U uses E, i: Integer, acc: List[U]): List[U] uses E
  return case get(xs, i) of
    when Option.None: acc
    when Option.Some(x):
      let y = f(x)
      mapFrom(xs, f, i + 1, append(acc, y))
  end case
end function

/// 添字 i の要素を返す。範囲の外なら Option.None を返す。
@builtin("List.get")
public function get[T](xs: List[T], i: Integer): Option[T]

@builtin("List.sort")
public function sort[T: ordered](xs: List[T]): List[T]
```

上の例は `List` のモジュールのソース（`List.bnt`）の一部であり、同じモジュールの関数は修飾せずに呼ぶ。

この例は書き方を示すものであり、`List.get` の代わりに、標準ライブラリのソースの中だけで使える組み込みの関数（`Option` を作らずに要素を順に取り出すもの）を使ってよい。この例は O(n log n) であり、要素を順に取り出す組み込みの関数を使えば O(n) にできる。標準ライブラリのソースの関数の定義そのものは、実装プランで与える。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（最小実行版の prelude の関数が、測定に足りるか）
- [OPEN-040](../open-issues.md#open-040): 正式リリース版とする条件と、互換性を壊す変更の範囲（非推奨にした宣言を取り除く時期）
- [OPEN-043](../open-issues.md#open-043): UTF-8 以外の文字コードとの変換と、Base64 以外の符号化
- [OPEN-046](../open-issues.md#open-046): プロパティベーステストと、入力の生成器の導出（標準の型クラスの実装の導出を含む）
- [OPEN-049](../open-issues.md#open-049): パッケージの名前空間と取り込み方
- [OPEN-050](../open-issues.md#open-050): 標準の型クラスと重複する既存の関数を隠すか
