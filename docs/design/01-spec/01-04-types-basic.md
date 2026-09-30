# 基本型の意味論

- 状態: 確定
- 関連ADR: [0006](../decisions/0006-basic-types-semantics.md), [0012](../decisions/0012-invalid-utf8-input.md), [0058](../decisions/0058-string-interpolation-of-base-types.md), [0101](../decisions/0101-unabbreviated-names.md), [0105](../decisions/0105-byte-type.md), [0106](../decisions/0106-bitwise-functions.md), [0113](../decisions/0113-div-and-mod-operators.md), [0114](../decisions/0114-decimal-type.md), [0123](../decisions/0123-top-level-constants.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0146](../decisions/0146-runtime-errors-not-in-types.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-042](../open-issues.md#open-042), [OPEN-051](../open-issues.md#open-051)
- 移行元: [設計メモ](../sources/fp-language-design.md) 2.5

## 目的と範囲

基本型である `Integer`・`Float`・`String`・`Character`・`Boolean`・`Unit` と、初回リリース版で加える `Byte`・`Decimal` について、値の範囲、リテラルが表す値、演算子の意味、実行時エラーになる条件を定める。初回リリース版のビット演算の関数もここで定める。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。最小実行版にない型と関数は、節の見出しに「初回リリース版」と記す。基本型を扱う関数のうち、意味の定義に必要なもの（位置や長さを扱う文字列の関数、型の変換）は本章で定める。それ以外の関数の一覧は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

## 前提

リテラルの字句の形は[字句構造](01-01-lexical.md)で、演算子の優先順位と結合性は[構文](01-02-syntax.md)で定める。演算子の型付け（`+` が複数の型に使えることを型推論でどう扱うか）は[型システム](01-06-type-system.md)で、式の評価順序と、実行時エラーが起きたときにプログラムがどう停止するかは[評価意味論](01-08-evaluation.md)で定める。

本章で「実行時エラーとする」と書いた操作は、値を返さずにプログラムを停止させる。最小実行版には、実行時エラーを捕捉する手段はない。【決定】関数の型は、その関数が実行時エラーを起こしうるかどうかを型にもエフェクトにも表さない。実行時エラーは、プロセスを異常終了（クラッシュ）させる。算術の失敗を `Option` や `Result` で返す版の関数は設けない（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。

【決定】算術の実行時エラー（整数の溢れ、初回リリース版の `Decimal` の溢れ、0 による除算）は、次の二段で扱う（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。

- 実行の前の検査: 実行する前に起きることが確実に分かる次のものを、警告とする。警告は検査と実行を止めない。
  - `div`・`mod`・`Integer.floorDivide`・`Integer.floorModulo`、`Decimal` の `/` の除数が定数式（[構文](01-02-syntax.md)の「定数（初回リリース版）」）であり、その値が 0 であるとき。割られる数は定数式でなくてよい。
  - 溢れうる演算（`Integer` の `+`・`-`・`*`・単項の `-`・`div`、`Integer.floorDivide`・`Integer.absolute`（[標準ライブラリ](../03-interop/03-06-stdlib.md)）、`Decimal` の `+`・`-`・`*`・`/`）のすべての引数が定数式であり、その計算が溢れの条件に当たるとき（`9223372036854775807 + 1` など）。
- 実行時: 値が実行して初めて分かるとき（変数に 0 や大きな値が入っているときなど）は、実行時エラーとする。

トップレベルの定数の定数式の中でこれらの条件に当たるときは、警告ではなく検査の誤りとする（[ADR 0123](../decisions/0123-top-level-constants.md)）。`Float` の演算は、0 による除算や範囲を超える結果でも実行時エラーにならない（後述）ので、警告の対象にしない。

本章の型の名前 `Option[T]` は、prelude が定める型であり、値は `Option.Some(x)` または `Option.None` である（[代数的データ型とパターンマッチ](01-05-data-types.md)、[標準ライブラリ](../03-interop/03-06-stdlib.md)）。

## 仕様

### 型の一覧

【方針】基本型は次の六つである。初回リリース版では、`Byte` と `Decimal` を加えて八つとする（[ADR 0105](../decisions/0105-byte-type.md)、[ADR 0114](../decisions/0114-decimal-type.md)）。

| 型 | 値 |
|---|---|
| `Integer` | 64 bit の符号付き整数 |
| `Float` | IEEE 754 の倍精度（binary64）の浮動小数点数 |
| `String` | Unicode のスカラー値の列 |
| `Character` | Unicode のスカラー値 1 個 |
| `Boolean` | `true` と `false` |
| `Unit` | `()` だけ |
| `Byte`（初回リリース版） | 0 以上 255 以下の整数 |
| `Decimal`（初回リリース版） | 10 進の小数（128 bit） |

【方針】基本型のあいだに暗黙の変換はない。`Integer` と `Float` を混ぜた演算（`1 + 2.0`）は型の誤りである。初回リリース版の `Decimal` と、`Integer`・`Float` を混ぜた演算も同じである。変換は、本章の「型の変換」の関数で明示する。`Float` の値を書くべき位置に整数リテラルを書いたとき（`x * 2` で `x` が `Float` など）は、`2.0` と書くよう診断で示す。

### Integer

【決定】`Integer` は 64 bit の符号付き整数であり、値の範囲は −2^63 以上 2^63 − 1 以下である（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。演算の結果がこの範囲を超えるときは、実行時エラーとする。範囲を超えた値を回り込ませて返してはならない。

【方針】整数リテラルが表す値は、字句の数字列が表す数である。値が `Integer` の範囲を超える整数リテラルは、型検査の誤りとする。ただし、単項の `-` を整数リテラルに直接適用した式（`-9223372036854775808`）は、符号を含めた値で範囲を判定する。

【方針】`Integer` の演算子の意味は次のとおりである。`a`・`b` は `Integer` の値である。

| 式 | 値 | 実行時エラーになる条件 |
|---|---|---|
| `a + b`、`a - b`、`a * b` | 数学的な和・差・積 | 結果が範囲を超える |
| `-a` | 符号を反転した値 | `a` が −2^63 |
| `a div b` | 商を 0 の方向に切り捨てた値 | `b` が 0。`a` が −2^63 で `b` が −1 |
| `a mod b` | 数学の整数として計算した `a − q × b`。`q` は、`a` を `b` で割った商を 0 の方向に切り捨てた整数 | `b` が 0 |

【決定】整数の除算は `div`、剰余は `mod` と書く（[ADR 0113](../decisions/0113-div-and-mod-operators.md)）。`div` は 0 の方向に切り捨て、`mod` の結果の符号は `a` と同じか 0 になる（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。例えば、`-7 div 2` は `-3`、`-7 mod 2` は `-1`、`7 mod -2` は `1` である。`a` が −2^63 で `b` が −1 のとき、商 `q` は `Integer` の範囲を超えるが、`a mod b` は `0` であり、実行時エラーにはならない。

【決定】`Integer` には `/` を使えない（[ADR 0113](../decisions/0113-div-and-mod-operators.md)）。`Integer` に `/` を使うと型検査の誤りとし、診断は `div` を修正案として示す。実数の商を求めるときは、`Integer.toFloat` で `Float` に変換してから `/` を使うことも示す。

【方針】負の無限大の方向に丸める除算と剰余は、関数として提供する。

| 関数 | 値 | 実行時エラーになる条件 |
|---|---|---|
| `Integer.floorDivide(a, b)` | 商を負の無限大の方向に丸めた値 | `b` が 0。`a` が −2^63 で `b` が −1 |
| `Integer.floorModulo(a, b)` | 数学の整数として計算した `a − q × b`。`q` は、`a` を `b` で割った商を負の無限大の方向に丸めた整数。結果の符号は `b` と同じか 0 | `b` が 0 |

例えば、`Integer.floorDivide(-7, 2)` は `-4`、`Integer.floorModulo(-7, 2)` は `1` である。`a` が −2^63 で `b` が −1 のとき、`Integer.floorModulo(a, b)` は `0` である。

【方針】`Integer` の比較演算子（`=`・`<>`・`<`・`<=`・`>`・`>=`）は、数の大小と等しさで判定する。

最小実行版には、ビット演算（論理積、シフトなど）の演算子と関数はない。

### Float

【方針】`Float` は IEEE 754 の倍精度（binary64）の値であり、正負の 0、正負の無限大、NaN を含む。

【方針】浮動小数リテラルが表す値は、字句の 10 進数に最も近い `Float` の値である。最も近い値が二つあるときは、仮数の最下位ビットが 0 である方をとる。値の絶対値が有限の最大値を超える浮動小数リテラル（丸めると無限大になるもの）は、型検査の誤りとする。

【方針】`Float` の演算子 `+`・`-`・`*`・`/` と単項の `-` は、IEEE 754 の規則に従い、結果を最も近い値に丸める（最近接偶数丸め）。0 による除算は実行時エラーにせず、IEEE 754 の規則どおり無限大または NaN を返す。`div` と `mod` は `Float` には使えない。

【方針】`Float` の比較演算子は IEEE 754 の比較に従う。したがって次のようになる。

- `0.0 = -0.0` は `true` である。
- NaN と比べた `=`・`<`・`<=`・`>`・`>=` はすべて `false`、`<>` は `true` である。NaN 自身とも等しくない。

値が NaN かどうかは `Float.isNaN(x)` で調べる。

`Float` の値はパターンに書けない（[構文](01-02-syntax.md)）。

### String

【決定】`String` の値は Unicode のスカラー値（U+0000〜U+D7FF と U+E000〜U+10FFFF）の列である（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。文字列は、その列を UTF-8 で符号化したバイト列としても扱える。サロゲートや、正しくない UTF-8 のバイト列を含む文字列の値は存在しない。文字列は変更できない。

【決定】ファイルの内容など、外部から受け取るバイト列を `String` として受け取る操作は、正しくない UTF-8 のバイト列を置き換えたり捨てたりしない（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。最小実行版の操作の振る舞いは[エフェクト](01-07-effects.md)で定める。外部の関数（WASM のモジュールの関数。[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）との値の受け渡しは、外部の関数を実装する版で定める（[OPEN-051](../open-issues.md#open-051)）。

文字列の位置には次の二つの単位がある。どちらも 0 から数える。

- **バイト位置**: UTF-8 で符号化したバイト列の中の位置。文字の境界にあるバイト位置（先頭、末尾、各スカラー値の符号化の始まり）を、境界の位置と呼ぶ。
- **文字位置**: スカラー値の列の中の位置。

【決定】位置や長さを扱う関数は、名前に単位を含める。バイト位置を扱う関数は `byte`、文字位置を扱う関数は `character` を名前に含める（単位の語も省略しない。[ADR 0101](../decisions/0101-unabbreviated-names.md)）。単位を持たない `String.length` は設けない（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。この命名が LLM の誤りを減らすかは【要検証】である（[OPEN-012](../open-issues.md#open-012)）。`String.length` などの存在しない名前を使ったときは、単位を持つ関数を修正案として診断で示す。

【方針】位置や長さを扱う関数は次のとおりである。範囲は半開区間（`start` を含み `stop` を含まない）で指定する。

| 関数 | 型 | 値 |
|---|---|---|
| `String.byteLength(s)` | `function(String) -> Integer` | `s` のバイト数 |
| `String.byteSlice(s, start, stop)` | `function(String, Integer, Integer) -> Option[String]` | バイト位置 `start` から `stop` までの部分文字列 |
| `String.characterCount(s)` | `function(String) -> Integer` | `s` のスカラー値の個数 |
| `String.characterAt(s, i)` | `function(String, Integer) -> Option[Character]` | 文字位置 `i` のスカラー値 |
| `String.characterSlice(s, start, stop)` | `function(String, Integer, Integer) -> Option[String]` | 文字位置 `start` から `stop` までの部分文字列 |

【決定】位置を指定する関数は、位置が正しくないときに実行時エラーにせず `Option.None` を返す（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。正しくない位置とは、次のいずれかに当たるものである。

- `String.characterAt(s, i)`: `i < 0` または `i >= String.characterCount(s)`。
- `String.byteSlice(s, start, stop)`: `start < 0`、`stop < start`、`stop > String.byteLength(s)`、または `start` か `stop` が境界の位置でない。
- `String.characterSlice(s, start, stop)`: `start < 0`、`stop < start`、`stop > String.characterCount(s)`。

【決定】`String.byteLength` は、文字列の長さによらない時間で値を返さなければならない。`character` を名前に含む関数は、文字列の長さに比例する時間がかかってよい（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。

位置を使わない文字列の操作（分割、行への分解、前方一致、検索、置換、`Character` の列への分解など）は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

【決定】`a + b` は、`a` の後に `b` を連結した文字列である。両辺はどちらも `String` でなければならない（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。`String` と他の型を `+` でつなぐと型の誤りとし、`Integer.toString` などで変換するよう診断で示す。

【方針】`String` の `=` と `<>` は、スカラー値の列が等しいかどうかで判定する。Unicode の正規化は行わない（NFC の「が」と NFD の「か」＋濁点は等しくない）。`<`・`<=`・`>`・`>=` は、スカラー値の値による辞書式の順序で判定する。この順序は、UTF-8 のバイト列の辞書式の順序と一致する。

### Character

【方針】`Character` の値は Unicode のスカラー値 1 個である。文字リテラル（[字句構造](01-01-lexical.md)）で書く。

【方針】`Character` の比較演算子は、スカラー値の値の大小と等しさで判定する。`Character` には算術演算子を使えない。`Character` と `String` を `+` でつなぐこともできない。

【方針】`Character` を扱う変換の関数は次のとおりである。

| 関数 | 型 | 値 |
|---|---|---|
| `Character.toInteger(c)` | `function(Character) -> Integer` | スカラー値の値 |
| `Character.fromInteger(n)` | `function(Integer) -> Option[Character]` | 値 `n` のスカラー値。`n` がスカラー値の範囲にないときは `Option.None` |
| `Character.toString(c)` | `function(Character) -> String` | `c` だけからなる文字列 |

### Boolean

【方針】`Boolean` の値は `true` と `false` である。

| 式 | 値 |
|---|---|
| `not a` | `a` の否定 |
| `a and b` | `a` が `false` なら `b` を評価せずに `false`、`a` が `true` なら `b` の値 |
| `a or b` | `a` が `true` なら `b` を評価せずに `true`、`a` が `false` なら `b` の値 |

`and` と `or` は、右辺を評価しないことがある（短絡評価）。`b` が外部に作用する式であれば、その作用も起きない。

【方針】`Boolean` には `=` と `<>` だけを使える。`<` などの順序の比較はできない。

### Unit

【方針】`Unit` の値は `()` だけである。`Unit` には `=` と `<>` を使え、`() = ()` は常に `true` である。

### Byte（初回リリース版）

【決定】`Byte` の値は 0 以上 255 以下の整数である（[ADR 0105](../decisions/0105-byte-type.md)）。

- `Byte` には、`=`・`<>` と、順序の比較演算子（`<`・`<=`・`>`・`>=`）を使える。比較は数の大小による。
- `Byte` には、算術の演算子（`+`・`-`・`*`・`/`・`div`・`mod`・単項の `-`）を使えない。計算は `Byte.toInteger` で `Integer` にしてから行う。
- `Byte` のリテラルはない。`Integer` との間に暗黙の変換はない。

| 関数 | 型 | 値 |
|---|---|---|
| `Byte.fromInteger(n)` | `function(Integer) -> Option[Byte]` | `n` が 0 以上 255 以下なら、その値の `Byte`。そうでなければ `Option.None` |
| `Byte.toInteger(b)` | `function(Byte) -> Integer` | `b` の値 |
| `Byte.toString(b)` | `function(Byte) -> String` | `b` の値の 10 進表記 |

### Decimal（初回リリース版）

【決定】`Decimal` の値は、`m / 10^e` の形の数である（[ADR 0114](../decisions/0114-decimal-type.md)）。m は −2^96 < m < 2^96 の整数、e は 0 以上 28 以下の整数である。e を小数の桁数（scale）と呼ぶ。

- 同じ数を、小数の桁数の違う値で表せる（`1.0m` は m = 10、e = 1、`1.00m` は m = 100、e = 2）。どちらも同じ数を表し、`=` で等しい。小数の桁数は `Decimal.toString` の表記に現れる。
- m が 0 の値は符号を持たない。`-0.0m` は `0.0m` と同じ値である。
- 値の絶対値の最大は (2^96 − 1)（約 7.9 × 10^28）である。

【方針】`Decimal` のリテラル（[字句構造](01-01-lexical.md)）が表す値は、接尾辞 `m` の前の 10 進数の値そのものであり、小数の桁数は小数点の後に書いた桁の数（小数点がなければ 0）である。`1.50m` の小数の桁数は 2 である。小数点の後に 29 桁以上を書いたリテラルと、値が上の範囲を超えるリテラルは、型検査の誤りとする。丸めはしない。単項の `-` を `Decimal` のリテラルに直接適用した式は、符号を含めた値で範囲を判定する。

【方針】`Decimal` の演算子の意味は次のとおりである。`a`・`b` は `Decimal` の値、`ea`・`eb` はそれぞれの小数の桁数である。

| 式 | 値 | 結果の小数の桁数 | 実行時エラーになる条件 |
|---|---|---|---|
| `a + b`、`a - b` | 数学的な和・差 | `ea` と `eb` の大きいほう | 結果を後述の規則で丸めても表せない |
| `a * b` | 数学的な積 | `ea + eb` | 同上 |
| `a / b` | 数学的な商 | 後述 | `b` が 0。結果を後述の規則で丸めても表せない |
| `-a` | 符号を反転した値 | `ea` | なし |

【方針】演算の結果の数を、上の表の小数の桁数で表せないとき（小数の桁数が 28 を超えるか、m が範囲を超えるとき）は、m が範囲に収まり小数の桁数が 28 以下になる最大の小数の桁数まで桁数を減らし、最近接偶数丸め（ちょうど中間なら m が偶数になるほう）で丸める。小数の桁数を 0 まで減らしても m が範囲を超えるときは、実行時エラーとする。

【方針】`a / b` の結果は次のとおりである。

- 商が、小数の桁数 28 以下で m が範囲に収まる値として正確に表せるときは、その値のうち、小数の桁数が `ea − eb` と 0 の大きいほう以上で最も小さいものとする。例えば、`1.00m / 4m` は `0.25m`、`6.0m / 2m` は `3.0m`、`6m / 2.0m` は `3m` である。
- 正確に表せないときは、m が範囲に収まり小数の桁数が 28 以下になる最大の小数の桁数で、最近接偶数丸めで丸める。例えば、`1m / 3m` は `0.3333333333333333333333333333m`（小数 28 桁）である。

【方針】`Decimal` の比較演算子（`=`・`<>`・`<`・`<=`・`>`・`>=`）は、数の大小と等しさで判定する。小数の桁数は比べない。`div` と `mod` は `Decimal` には使えない（[ADR 0113](../decisions/0113-div-and-mod-operators.md)）。

`Decimal` の値はパターンに書けない（[構文](01-02-syntax.md)）。

【方針】`Decimal` を丸める関数と、丸め方を表す prelude の型 `RoundingMode`（[代数的データ型とパターンマッチ](01-05-data-types.md)）は次のとおりである。

| 関数 | 型 | 値 |
|---|---|---|
| `Decimal.round(x, places, mode)` | `function(Decimal, Integer, RoundingMode) -> Decimal` | `x` を小数の桁数 `places` の値に、`mode` の丸め方で丸めた値。`x` の小数の桁数が `places` より少なければ、末尾に 0 を補う（`Decimal.round(1.5m, 2, mode)` は `1.50m`） |
| `Decimal.absolute(x)` | `function(Decimal) -> Decimal` | 絶対値。小数の桁数は `x` と同じ |

| `RoundingMode` の構成子 | 丸め方 |
|---|---|
| `RoundingMode.HalfToEven` | 最も近い値。ちょうど中間なら、最後の桁が偶数になるほう |
| `RoundingMode.HalfAwayFromZero` | 最も近い値。ちょうど中間なら、0 から遠いほう（四捨五入） |
| `RoundingMode.TowardZero` | 0 の方向（切り捨て） |
| `RoundingMode.TowardNegativeInfinity` | 負の無限大の方向 |
| `RoundingMode.TowardPositiveInfinity` | 正の無限大の方向 |

【決定】`Decimal.round` の `places` が 0 以上 28 以下でなければ、実行時エラーとする。丸めた結果や 0 を補った結果の m が範囲を超えるときも、実行時エラーとする。

### ビット演算（初回リリース版）

【決定】ビット演算は、演算子ではなく関数として設ける（[ADR 0106](../decisions/0106-bitwise-functions.md)）。`Integer` の値は、64 bit の 2 の補数で表したビットの並びとして扱う。

| 関数 | 型 | 値 |
|---|---|---|
| `Integer.bitwiseAnd(a, b)` | `function(Integer, Integer) -> Integer` | ビットごとの論理積 |
| `Integer.bitwiseOr(a, b)` | `function(Integer, Integer) -> Integer` | ビットごとの論理和 |
| `Integer.bitwiseExclusiveOr(a, b)` | `function(Integer, Integer) -> Integer` | ビットごとの排他的論理和 |
| `Integer.bitwiseNot(a)` | `function(Integer) -> Integer` | すべてのビットを反転した値 |
| `Integer.shiftLeft(a, n)` | `function(Integer, Integer) -> Integer` | 左へ `n` ビットずらした値。上位からはみ出たビットは捨て、下位を 0 で埋める |
| `Integer.shiftRight(a, n)` | `function(Integer, Integer) -> Integer` | 右へ `n` ビットずらした値。上位を符号のビットで埋める（算術シフト） |
| `Integer.shiftRightUnsigned(a, n)` | `function(Integer, Integer) -> Integer` | 右へ `n` ビットずらした値。上位を 0 で埋める（論理シフト） |

【決定】`Integer` のシフトで、ずらす量 `n` が 0 以上 63 以下でなければ、実行時エラーとする。`shiftLeft` で上位からはみ出たビットは捨て、溢れの実行時エラーにはしない。

`Byte` にも、同じ名前のビット演算を設ける。値は 8 bit の並びとして扱う。

| 関数 | 型 | 値 |
|---|---|---|
| `Byte.bitwiseAnd(a, b)`・`Byte.bitwiseOr(a, b)`・`Byte.bitwiseExclusiveOr(a, b)` | `function(Byte, Byte) -> Byte` | `Integer` の同じ名前の関数と同じ |
| `Byte.bitwiseNot(a)` | `function(Byte) -> Byte` | 8 bit のすべてを反転した値 |
| `Byte.shiftLeft(a, n)` | `function(Byte, Integer) -> Byte` | 左へ `n` ビットずらした値。8 bit からはみ出たビットは捨てる |
| `Byte.shiftRight(a, n)` | `function(Byte, Integer) -> Byte` | 右へ `n` ビットずらした値。上位を 0 で埋める |

【決定】`Byte` のシフトで、ずらす量 `n` が 0 以上 7 以下でなければ、実行時エラーとする。

### 型の変換

【方針】基本型のあいだの変換の関数は次のとおりである。失敗しうる変換は `Option` を返す。

| 関数 | 型 | 値 |
|---|---|---|
| `Integer.toFloat(n)` | `function(Integer) -> Float` | `n` に最も近い `Float` の値（最近接偶数丸め） |
| `Float.truncate(x)` | `function(Float) -> Option[Integer]` | `x` を 0 の方向に切り捨てた整数。`x` が NaN・無限大か、結果が `Integer` の範囲を超えるときは `Option.None` |
| `Integer.toString(n)` | `function(Integer) -> String` | `n` の 10 進表記。負の数は先頭に `-` を付ける |
| `Float.toString(x)` | `function(Float) -> String` | 下の規則による表記 |
| `Integer.parse(s)` | `function(String) -> Option[Integer]` | 10 進の整数の表記を読んだ値。表記が正しくないか範囲を超えるときは `Option.None` |
| `Float.parse(s)` | `function(String) -> Option[Float]` | 10 進の数の表記を読み、浮動小数リテラルと同じ規則で丸めた値。表記が正しくないときと、浮動小数リテラルなら型検査の誤りになる値（丸めると無限大になるもの）のときは `Option.None` |
| `Decimal.fromInteger(n)`（初回リリース版） | `function(Integer) -> Decimal` | `n` と等しい値。小数の桁数は 0 |
| `Decimal.truncate(x)`（初回リリース版） | `function(Decimal) -> Option[Integer]` | `x` を 0 の方向に切り捨てた整数。結果が `Integer` の範囲を超えるときは `Option.None` |
| `Decimal.toFloat(x)`（初回リリース版） | `function(Decimal) -> Float` | `x` に最も近い `Float` の値（最近接偶数丸め） |
| `Decimal.fromFloat(x)`（初回リリース版） | `function(Float) -> Option[Decimal]` | `Float.toString(x)` の表記が表す数を、`Decimal` の値として読んだもの。小数点の後が 29 桁以上になるときは、小数の桁数 28 に最近接偶数丸めで丸める。`x` が NaN・無限大か、絶対値が `Decimal` の範囲を超えるときは `Option.None` |
| `Decimal.toString(x)`（初回リリース版） | `function(Decimal) -> String` | 下の規則による表記 |
| `Decimal.parse(s)`（初回リリース版） | `function(String) -> Option[Decimal]` | 10 進の数の表記を読んだ値。表記が正しくないときと、`Decimal` のリテラルなら型検査の誤りになる値のときは `Option.None` |

【方針】初回リリース版では、文字列補間（[字句構造](01-01-lexical.md)）は、`String` の値をそのまま、`Integer`・`Float`・`Character`・`Byte`・`Decimal` の値をそれぞれの `toString` と同じ文字列に、`Boolean` の値を `true` か `false` の文字列にして埋め込む（[ADR 0058](../decisions/0058-string-interpolation-of-base-types.md)、[ADR 0114](../decisions/0114-decimal-type.md)）。

【方針】`Float.toString(x)` の表記は次のとおりである。同じ値に対して常に同じ文字列を返す。

- NaN は `NaN`、正の無限大は `Infinity`、負の無限大は `-Infinity` とする。
- 有限の値は、`Float.parse` で読み戻すと元の値になる 10 進表記のうち、有効数字が最も少ないものを使う。有効数字の桁数が同じ候補が複数あるときは、元の値に最も近いものを使う。
- 10 進の指数（有効数字を `d.ddd × 10^e` と書いたときの `e`）が −5 以上 21 未満なら、指数を使わずに書き、小数点の後に少なくとも 1 桁を置く（`1.0`、`0.001`、`123.45`）。それ以外は、仮数、`e`、指数の符号（`+` または `-`）、指数の 10 進表記の順に書く（`1.0e+21`、`1.5e-7`）。仮数は小数点の前に 1 桁、後に少なくとも 1 桁を置き、指数には先頭の 0 を付けない。
- 負の値と −0 は、先頭に `-` を付ける（`-0.0`）。

これらの表記は、どれも浮動小数リテラルとして書ける形である（NaN と無限大を除く）。

【方針】`Decimal.toString(x)` の表記は、`x` の符号（負の値だけ `-`）、整数部の 10 進表記、小数の桁数が 1 以上なら小数点と小数の桁数と同じ数の桁、の順に並べたものである。指数と接尾辞 `m` は付けない。`Decimal.toString(1.50m)` は `"1.50"`、`Decimal.toString(-3m)` は `"-3"`、`Decimal.toString(0.05m)` は `"0.05"` である。

【方針】`Integer.parse` と `Float.parse` が受け付ける表記は、それぞれ整数リテラルの 10 進の形と浮動小数リテラルの形に、先頭の任意の `-` を加えたものである。ただし、桁の区切り `_`、先頭の `+`、前後の空白は受け付けない。`Float.parse` は、整数リテラルの 10 進の形（`42`）も受け付ける。`NaN`・`Infinity` は受け付けない。絶対値が小さすぎて 0 に丸められる表記（`1e-9999`）は、浮動小数リテラルと同じく受け付け、符号を保った 0 を返す（`Float.parse("-1e-9999")` は `Option.Some(-0.0)`）。

【方針】初回リリース版の `Decimal.parse` が受け付ける表記は、`Decimal` のリテラルから接尾辞 `m` を除いた形（`12`、`1.25`）に、先頭の任意の `-` を加えたものである。`Integer.parse` と同じく、桁の区切り `_`、先頭の `+`、前後の空白は受け付けない。

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細（外部の関数との値の受け渡し）
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（単位を名前に含めた文字列の関数、整数の除算の丸めが、LLM の誤りを減らすかどうか）
- [OPEN-042](../open-issues.md#open-042): 相互運用のための幅の違う数の型
