# 基本型の意味論

## 目的と範囲

基本型である各幅の整数・浮動小数点数と、`String`・`Character`・`Boolean`・`Unit`・`Decimal` について、値の範囲、リテラルが表す値、演算子の意味、実行時エラーになる条件を定める。ビット演算の関数もここで定める。

基本型を扱う関数のうち、意味の定義に必要なもの（位置や長さを扱う文字列の関数、型の変換）は本章で定める。それ以外の関数の一覧は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

## 前提

リテラルの字句の形は[字句構造](01-01-lexical.md)で、演算子の優先順位と結合性は[構文](01-02-syntax.md)で定める。演算子の型付け（`+` が複数の型に使えることを型推論でどう扱うか）は[型システム](01-06-type-system.md)で、式の評価順序と、実行時エラーが起きたときにプログラムがどう停止するかは[評価意味論](01-08-evaluation.md)で定める。

本章で「実行時エラーとする」と書いた操作は、値を返さずにプログラムを停止させる。実行時エラーを捕捉する手段はない。【決定】関数の型は、その関数が実行時エラーを起こしうるかどうかを型にもエフェクトにも表さない。実行時エラーは、プロセスを異常終了（クラッシュ）させる。算術の失敗を `Option` や `Result` で返す版の関数は設けない。

【決定】算術の実行時エラー（整数の溢れ、`Decimal` の溢れ、0 による除算）は、次の二段で扱う。

- 実行の前の検査: 実行する前に起きることが確実に分かる次のものを、警告とする。警告は検査と実行を止めない。
  - 各整数型の `div`・`mod`・`Integer.floorDivide`・`Integer.floorModulo`、`Decimal` の `/` の除数が定数式（[構文](01-02-syntax.md)の「定数（初回リリース版）」）であり、その値が 0 であるとき（W0401）。割られる数は定数式でなくてよい。
  - 溢れうる演算（各整数型の `+`・`-`・`*`・`div`、符号付き整数の単項の `-`、`Integer.floorDivide`・`Integer.absolute`（[標準ライブラリ](../03-interop/03-06-stdlib.md)）、`Decimal` の `+`・`-`・`*`・`/`）のすべての引数が定数式であり、その計算が溢れの条件に当たるとき（W0402）。符号なしの減算が 0 未満になる場合も含む（`0u16 - 1u16` など）。
- 実行時: 値が実行して初めて分かるとき（変数に 0 や大きな値が入っているときなど）は、実行時エラーとする。

トップレベルの定数の定数式の中でこれらの条件に当たるときは、警告ではなく検査の誤り（E0435）とする。`Float`・`Float32` の演算は、0 による除算や範囲を超える結果でも実行時エラーにならない（後述）ので、警告の対象にしない。変換関数が `Option.None` を返す場合も、これらの警告の対象にしない。幅付きの整数の標準関数の呼び出しには、この算術の警告は適用しない。

本章の型の名前 `Option[T]` は、prelude が定める型であり、値は `Option.Some(x)` または `Option.None` である（[代数的データ型とパターンマッチ](01-05-data-types.md)、[標準ライブラリ](../03-interop/03-06-stdlib.md)）。

## 仕様

関数一覧の表の `f(a, b)` は、関数とパラメータを示す記法である。実際のコードでは、複数の引数を取る通常の関数は宣言のパラメータ名を付けて名前付きで呼ぶ。

### 型の一覧

【決定】数の型の正の名前、別名と既定の表示名は、次のとおりである。別名は同じ型を表し、演算の規則も同じである。

| 正の名前 | 別名・既定の表示名 | 値の範囲 |
|---|---|---|
| `Integer8`・`Integer16`・`Integer32` | 正の名前 | 幅 w が 8・16・32 bit の符号付き整数。−2^(w−1) 以上 2^(w−1) − 1 以下 |
| `Integer64` | `Integer` | −2^63 以上 2^63 − 1 以下 |
| `UnsignedInteger8` | `Byte` | 0 以上 255 以下。算術演算を持たない |
| `UnsignedInteger16`・`UnsignedInteger32` | 正の名前 | 幅 w が 16・32 bit の符号なし整数。0 以上 2^w − 1 以下 |
| `UnsignedInteger64` | 別名 `UnsignedInteger`。表示は `UnsignedInteger64` | 0 以上 2^64 − 1 以下 |
| `Float32` | 正の名前 | IEEE 754 の単精度（binary32） |
| `Float64` | `Float` | IEEE 754 の倍精度（binary64） |

理由: 幅を明示した名前を使えるようにしつつ、既存のスクリプトと診断・結果の表示を保つ。以下では、64 bit の符号付き整数、倍精度、8 bit の符号なし整数を、主に `Integer`・`Float`・`Byte` と書く。

【決定】基本型は、数の十種類と、次の五種類である。

| 型 | 値 |
|---|---|
| `String` | Unicode のスカラー値の列 |
| `Character` | Unicode のスカラー値 1 個 |
| `Boolean` | `true` と `false` |
| `Unit` | `()` だけ |
| `Decimal` | 10 進の小数（128 bit） |

【方針】基本型のあいだに暗黙の変換はない。`Integer` と `Float` を混ぜた演算（`1 + 2.0`）は型の誤りである。`Decimal` と、`Integer`・`Float` を混ぜた演算も同じである。変換は、本章の「型の変換」の関数で明示する。`Float` の値を書くべき位置に整数リテラルを書いたとき（`x * 2` で `x` が `Float` など）は、`2.0` と書くよう診断で示す。

【決定】異なる幅・符号の数を混ぜた演算・比較・等値も型の誤りとする。接尾辞なしの `1` は、求められる型が `Integer32` でも `Integer` のままである。リテラルには目的の接尾辞を、動的な値には変換関数を使う。

### Integer

【決定】`Integer` は 64 bit の符号付き整数であり、値の範囲は −2^63 以上 2^63 − 1 以下である。演算の結果がこの範囲を超えるときは、実行時エラーとする。範囲を超えた値を回り込ませて返してはならない。

【方針】整数リテラルが表す値は、字句の数字列が表す数である。値が `Integer` の範囲を超える整数リテラルは、型検査の誤りとする。ただし、単項の `-` を整数リテラルに直接適用した式（`-9223372036854775808`）は、符号を含めた値で範囲を判定する。

【方針】`Integer` の演算子の意味は次のとおりである。`a`・`b` は `Integer` の値である。

| 式 | 値 | 実行時エラーになる条件 |
|---|---|---|
| `a + b`、`a - b`、`a * b` | 数学的な和・差・積 | 結果が範囲を超える |
| `-a` | 符号を反転した値 | `a` が −2^63 |
| `a div b` | 商を 0 の方向に切り捨てた値 | `b` が 0。`a` が −2^63 で `b` が −1 |
| `a mod b` | 数学の整数として計算した `a − q × b`。`q` は、`a` を `b` で割った商を 0 の方向に切り捨てた整数 | `b` が 0 |

【決定】整数の除算は `div`、剰余は `mod` と書く。`div` は 0 の方向に切り捨て、`mod` の結果の符号は `a` と同じか 0 になる。例えば、`-7 div 2` は `-3`、`-7 mod 2` は `-1`、`7 mod -2` は `1` である。`a` が −2^63 で `b` が −1 のとき、商 `q` は `Integer` の範囲を超えるが、`a mod b` は `0` であり、実行時エラーにはならない。

【決定】`Integer` には `/` を使えない。`Integer` に `/` を使うと型検査の誤りとし、診断は `div` を修正案として示す。実数の商を求めるときは、`Integer.toFloat` で `Float` に変換してから `/` を使うことも示す。

【方針】負の無限大の方向に丸める除算と剰余は、関数として提供する。

| 関数 | 値 | 実行時エラーになる条件 |
|---|---|---|
| `Integer.floorDivide(a, b)` | 商を負の無限大の方向に丸めた値 | `b` が 0。`a` が −2^63 で `b` が −1 |
| `Integer.floorModulo(a: a, b: b)` | 数学の整数として計算した `a − q × b`。`q` は、`a` を `b` で割った商を負の無限大の方向に丸めた整数。結果の符号は `b` と同じか 0 | `b` が 0 |

例えば、`Integer.floorDivide(a: -7, b: 2)` は `-4`、`Integer.floorModulo(a: -7, b: 2)` は `1` である。`a` が −2^63 で `b` が −1 のとき、`Integer.floorModulo(a: a, b: b)` は `0` である。

【方針】`Integer` の比較演算子（`=`・`<>`・`<`・`<=`・`>`・`>=`）は、数の大小と等しさで判定する。

ビット演算（論理積、シフトなど）の演算子はない。ビット演算は関数として設ける（後述の「ビット演算（初回リリース版）」）。

【決定】`Integer8`・`Integer16`・`Integer32` は、幅に応じた上記の値域で、`Integer` と同じ算術・比較を持つ。`UnsignedInteger16`・`UnsignedInteger32`・`UnsignedInteger64` は、同型の `+`・二項の `-`・`*`・`div`・`mod` と比較を持つ。結果が値域を超える場合と、符号なしの減算が 0 未満になる場合は実行時エラーとし、折り返さない。`/` は使えず、符号なしの単項の `-` は 0 にも使えない。

符号付きの `div` は 0 の方向に切り捨て、`mod` は左辺と同符号か 0 である。各幅の最小値 `div -1` は実行時エラー、最小値 `mod -1` は 0 である。符号なしの `div`・`mod` は非負の商と剰余を返す。いずれも除数 0 は実行時エラーとする。各モジュールの `floorDivide`・`floorModulo` は、符号付きでは `Integer` と同じ負の無限大の方向の商と剰余であり、符号なしでは `div`・`mod` と一致する。`absolute` は、符号付きの最小値で実行時エラー、符号なしでは元の値を返す。

理由: 幅だけを変えたときに、除算と算術の失敗の意味を変えない。

【決定】接尾辞を持つ整数リテラルは、その型の値域で検査する。`u64` は 2^64 − 1 まで表せる。符号付きリテラルへの直接の負号は、符号を含めて検査するので、`-128s8` は正しい。括弧を挟む `-(128s8)` はこの特例に含めず、内側のリテラルが範囲外であるため誤りとする。`-0u16`・`-1u8` も静的な誤りである。べき乗と折り返す算術の関数は設けない。

`Integer8`・`Integer16`・`Integer32` と符号なしの各幅には、定数・範囲パターンを使えない。束縛・ワイルドカードとガードで分岐する。`s64` の接尾辞は既存の `Integer` のパターン規則に従う。

次の例は、各幅の境界値と別名の同一性を示す。出力には接尾辞を付けない。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind a: Integer8 <- -128s8
  bind b: Integer16 <- -32768s16
  bind c: Integer32 <- -2147483648s32
  bind d: Integer64 <- -9223372036854775808s64
  bind e: UnsignedInteger8 <- 255u8
  bind f: UnsignedInteger16 <- 65535u16
  bind g: UnsignedInteger32 <- 4294967295u32
  bind h: UnsignedInteger <- 18446744073709551615u64
  Console.writeLine("${a}, ${b}, ${c}, ${Integer.toString(d)}")
  Console.writeLine("${Byte.toString(e)}, ${f}, ${g}, ${UnsignedInteger64.toString(h)}")
  Console.writeLine("${(-128s8) mod -1s8}, ${Integer8.floorModulo(a: -128s8, b: -1s8)}")
end function
```

```output
-128, -32768, -2147483648, -9223372036854775808
255, 65535, 4294967295, 18446744073709551615
0, 0
```

括弧を挟んだ負号は、範囲外の正のリテラルを許さない。

```benitoite error
function main() -> Unit
  bind _ <- -(128s8)
end function
```

```diagnostic
E0447
integer literal is out of range for `Integer8`
```

符号なしの負号と `Byte` の算術は、零でも使えない。

```benitoite error
function main() -> Unit
  bind _ <- -0u16
  bind _ <- 1u8 + 2u8
end function
```

```diagnostic
E0405
`-` cannot be applied to `UnsignedInteger16`
`+` cannot be applied to `Byte`
```

接尾辞を省略した整数は、型注釈に合わせて縮小されない。

```benitoite error
function main() -> Unit
  bind n: Integer32 <- 1
end function
```

```diagnostic
E0401
```

`const` の算術の溢れは、実行前の誤りになる。

```benitoite error
const belowZero: UnsignedInteger16 = 0u16 - 1u16
function main() -> Unit
end function
```

```diagnostic
E0435
integer overflow
```

### Float

【方針】`Float` は IEEE 754 の倍精度（binary64）の値であり、正負の 0、正負の無限大、NaN を含む。

【方針】浮動小数リテラルが表す値は、字句の 10 進数に最も近い `Float` の値である。最も近い値が二つあるときは、仮数の最下位ビットが 0 である方をとる。値の絶対値が有限の最大値を超える浮動小数リテラル（丸めると無限大になるもの）は、型検査の誤りとする。

【方針】`Float` の演算子 `+`・`-`・`*`・`/` と単項の `-` は、IEEE 754 の規則に従い、結果を最も近い値に丸める（最近接偶数丸め）。0 による除算は実行時エラーにせず、IEEE 754 の規則どおり無限大または NaN を返す。`div` と `mod` は `Float` には使えない。

【方針】`Float` の比較演算子は IEEE 754 の比較に従う。したがって次のようになる。

- `0.0 = -0.0` は `true` である。
- NaN と比べた `=`・`<`・`<=`・`>`・`>=` はすべて `false`、`<>` は `true` である。NaN 自身とも等しくない。

値が NaN かどうかは `Float.isNaN(x)` で調べる。

`Float` の値はパターンに書けない（[構文](01-02-syntax.md)）。

【決定】`Float32` は binary32 の値であり、正負の零・無限大・NaN を含む。値の生成と `+`・`-`・`*`・`/` の各結果を、binary32 の最近接偶数丸めで丸める。倍精度で計算を続けたり、複数の演算を融合積和にまとめたりしない。単項の `-` は符号を反転する。0 による除算、特殊値と比較の規則は `Float` と同じであり、有限値の演算結果が無限大になっても実行時エラーにしない。NaN の追加のビット情報の保存は保証しない。

理由: 各演算の後の丸めを定めることで、言語内の計算と比較を単精度の意味に揃える。

`f32` のリテラルは、十進の数字列から直接 binary32 に丸めた値である。無限大に丸められるリテラルは静的な誤りとし、符号を保った零への丸めは認める。`Float32` の定数・範囲パターンは認めない。`f64` の接尾辞は `Float` の規則に従う。

次の例では、各演算後の丸めによって `16777216.0f32 + 1.0f32` が元の値に戻る。後の減算の結果は零になる。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind single: Float32 <- (16777216.0f32 + 1.0f32) - 16777216.0f32
  bind double: Float64 <- 1.5f64
  Console.writeLine("${single}, ${Float.toString(double)}, ${0.1f32}, ${-0.0f32}")
  Console.writeLine("${Float32.isNaN(0.0f32 / 0.0f32)}, ${Float32.isInfinite(1.0f32 / 0.0f32)}")
  Console.writeLine("${Integer8.fromInteger(128) = Option.None}, ${UnsignedInteger64.fromDecimal(1.0m) = Option.Some(1u64)}")
end function
```

```output
0.0, 1.5, 0.1, -0.0
true, true
true, true
```

### String

【決定】`String` の値は Unicode のスカラー値（U+0000〜U+D7FF と U+E000〜U+10FFFF）の列である。文字列は、その列を UTF-8 で符号化したバイト列としても扱える。サロゲートや、正しくない UTF-8 のバイト列を含む文字列の値は存在しない。文字列は変更できない。

【決定】ファイルの内容など、外部から受け取るバイト列を `String` として受け取る操作は、正しくない UTF-8 のバイト列を置き換えたり捨てたりしない。操作の振る舞いは[エフェクト](01-07-effects.md)で定める。

文字列の位置には次の二つの単位がある。どちらも 0 から数える。

- **バイト位置**: UTF-8 で符号化したバイト列の中の位置。文字の境界にあるバイト位置（先頭、末尾、各スカラー値の符号化の始まり）を、境界の位置と呼ぶ。
- **文字位置**: スカラー値の列の中の位置。

【決定】位置や長さを扱う関数は、名前に単位を含める。バイト位置を扱う関数は `byte`、文字位置を扱う関数は `character` を名前に含める（単位の語も省略しない）。単位を持たない `String.length` は設けない。`String.length` などの存在しない名前を使ったときは、単位を持つ関数を修正案として診断で示す。

【方針】位置や長さを扱う関数は次のとおりである。範囲は半開区間（`start` を含み `stop` を含まない）で指定する。

| 関数 | 型 | 値 |
|---|---|---|
| `String.byteLength(s)` | `function(s: String) -> Integer` | `s` のバイト数 |
| `String.byteSlice(s: s, start: start, stop: stop)` | `function(s: String, start: Integer, stop: Integer) -> Option[String]` | バイト位置 `start` から `stop` までの部分文字列 |
| `String.characterCount(s)` | `function(s: String) -> Integer` | `s` のスカラー値の個数 |
| `String.characterAt(s: s, i: i)` | `function(s: String, i: Integer) -> Option[Character]` | 文字位置 `i` のスカラー値 |
| `String.characterSlice(s: s, start: start, stop: stop)` | `function(s: String, start: Integer, stop: Integer) -> Option[String]` | 文字位置 `start` から `stop` までの部分文字列 |

【決定】位置を指定する関数は、位置が正しくないときに実行時エラーにせず `Option.None` を返す。正しくない位置とは、次のいずれかに当たるものである。

- `String.characterAt(s: s, i: i)`: `i < 0` または `i >= String.characterCount(s)`。
- `String.byteSlice(s: s, start: start, stop: stop)`: `start < 0`、`stop < start`、`stop > String.byteLength(s)`、または `start` か `stop` が境界の位置でない。
- `String.characterSlice(s: s, start: start, stop: stop)`: `start < 0`、`stop < start`、`stop > String.characterCount(s)`。

【決定】`String.byteLength` は、文字列の長さによらない時間で値を返さなければならない。`character` を名前に含む関数は、文字列の長さに比例する時間がかかってよい。

位置を使わない文字列の操作（分割、行への分解、前方一致、検索、置換、`Character` の列への分解など）は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

【決定】`a + b` は、`a` の後に `b` を連結した文字列である。両辺はどちらも `String` でなければならない。`String` と他の型を `+` でつなぐと型の誤りとし、`Integer.toString` などで変換するよう診断で示す。

【方針】`String` の `=` と `<>` は、スカラー値の列が等しいかどうかで判定する。Unicode の正規化は行わない（NFC の「が」と NFD の「か」＋濁点は等しくない）。`<`・`<=`・`>`・`>=` は、スカラー値の値による辞書式の順序で判定する。この順序は、UTF-8 のバイト列の辞書式の順序と一致する。

### Character

【方針】`Character` の値は Unicode のスカラー値 1 個である。文字リテラル（[字句構造](01-01-lexical.md)）で書く。

【方針】`Character` の比較演算子は、スカラー値の値の大小と等しさで判定する。`Character` には算術演算子を使えない。`Character` と `String` を `+` でつなぐこともできない。

【方針】`Character` を扱う変換の関数は次のとおりである。

| 関数 | 型 | 値 |
|---|---|---|
| `Character.toInteger(c)` | `function(c: Character) -> Integer` | スカラー値の値 |
| `Character.fromInteger(n)` | `function(n: Integer) -> Option[Character]` | 値 `n` のスカラー値。`n` がスカラー値の範囲にないときは `Option.None` |
| `Character.toString(c)` | `function(c: Character) -> String` | `c` だけからなる文字列 |

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

【決定】`Byte` の値は 0 以上 255 以下の整数である。

- `Byte` には、`=`・`<>` と、順序の比較演算子（`<`・`<=`・`>`・`>=`）を使える。比較は数の大小による。
- `Byte` には、算術の演算子（`+`・`-`・`*`・`/`・`div`・`mod`・単項の `-`）を使えない。計算は `Byte.toInteger` で `Integer` にしてから行う。
- 接尾辞 `u8` のリテラルで値を作れる（`255u8`）。`UnsignedInteger8` は同じ型であり、別名によって算術を使えるようにはならない。`Integer` との間に暗黙の変換はない。

| 関数 | 型 | 値 |
|---|---|---|
| `Byte.fromInteger(n)` | `function(n: Integer) -> Option[Byte]` | `n` が 0 以上 255 以下なら、その値の `Byte`。そうでなければ `Option.None` |
| `Byte.toInteger(b)` | `function(b: Byte) -> Integer` | `b` の値 |
| `Byte.toString(b)` | `function(b: Byte) -> String` | `b` の値の 10 進表記 |

### Decimal（初回リリース版）

【決定】`Decimal` の値は、`m / 10^e` の形の数である。m は −2^96 < m < 2^96 の整数、e は 0 以上 28 以下の整数である。e を小数の桁数（scale）と呼ぶ。

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

【方針】`Decimal` の比較演算子（`=`・`<>`・`<`・`<=`・`>`・`>=`）は、数の大小と等しさで判定する。小数の桁数は比べない。`div` と `mod` は `Decimal` には使えない。

`Decimal` の値はパターンに書けない（[構文](01-02-syntax.md)）。

【方針】`Decimal` を丸める関数と、丸め方を表す prelude の型 `RoundingMode`（[代数的データ型とパターンマッチ](01-05-data-types.md)）は次のとおりである。

| 関数 | 型 | 値 |
|---|---|---|
| `Decimal.round(x, places, mode)` | `function(x: Decimal, places: Integer, mode: RoundingMode) -> Decimal` | `x` を小数の桁数 `places` の値に、`mode` の丸め方で丸めた値。`x` の小数の桁数が `places` より少なければ、末尾に 0 を補う（`Decimal.round(x: 1.5m, places: 2, mode: mode)` は `1.50m`） |
| `Decimal.absolute(x)` | `function(x: Decimal) -> Decimal` | 絶対値。小数の桁数は `x` と同じ |

| `RoundingMode` の構成子 | 丸め方 |
|---|---|
| `RoundingMode.HalfToEven` | 最も近い値。ちょうど中間なら、最後の桁が偶数になるほう |
| `RoundingMode.HalfAwayFromZero` | 最も近い値。ちょうど中間なら、0 から遠いほう（四捨五入） |
| `RoundingMode.TowardZero` | 0 の方向（切り捨て） |
| `RoundingMode.TowardNegativeInfinity` | 負の無限大の方向 |
| `RoundingMode.TowardPositiveInfinity` | 正の無限大の方向 |

【決定】`Decimal.round` の `places` が 0 以上 28 以下でなければ、実行時エラーとする。丸めた結果や 0 を補った結果の m が範囲を超えるときも、実行時エラーとする。

### ビット演算（初回リリース版）

【決定】ビット演算は、演算子ではなく関数として設ける。`Integer` の値は、64 bit の 2 の補数で表したビットの並びとして扱う。

| 関数 | 型 | 値 |
|---|---|---|
| `Integer.bitwiseAnd(a, b)` | `function(a: Integer, b: Integer) -> Integer` | ビットごとの論理積 |
| `Integer.bitwiseOr(a, b)` | `function(a: Integer, b: Integer) -> Integer` | ビットごとの論理和 |
| `Integer.bitwiseExclusiveOr(a, b)` | `function(a: Integer, b: Integer) -> Integer` | ビットごとの排他的論理和 |
| `Integer.bitwiseNot(a)` | `function(a: Integer) -> Integer` | すべてのビットを反転した値 |
| `Integer.shiftLeft(a, n)` | `function(a: Integer, n: Integer) -> Integer` | 左へ `n` ビットずらした値。上位からはみ出たビットは捨て、下位を 0 で埋める |
| `Integer.shiftRight(a, n)` | `function(a: Integer, n: Integer) -> Integer` | 右へ `n` ビットずらした値。上位を符号のビットで埋める（算術シフト） |
| `Integer.shiftRightUnsigned(a, n)` | `function(a: Integer, n: Integer) -> Integer` | 右へ `n` ビットずらした値。上位を 0 で埋める（論理シフト） |

【決定】`Integer` のシフトで、ずらす量 `n` が 0 以上 63 以下でなければ、実行時エラーとする。`shiftLeft` で上位からはみ出たビットは捨て、溢れの実行時エラーにはしない。

`Byte` にも、同じ名前のビット演算を設ける。値は 8 bit の並びとして扱う。

| 関数 | 型 | 値 |
|---|---|---|
| `Byte.bitwiseAnd(a, b)`・`Byte.bitwiseOr(a, b)`・`Byte.bitwiseExclusiveOr(a, b)` | `function(a: Byte, b: Byte) -> Byte` | `Integer` の同じ名前の関数と同じ |
| `Byte.bitwiseNot(a)` | `function(a: Byte) -> Byte` | 8 bit のすべてを反転した値 |
| `Byte.shiftLeft(a, n)` | `function(a: Byte, n: Integer) -> Byte` | 左へ `n` ビットずらした値。8 bit からはみ出たビットは捨てる |
| `Byte.shiftRight(a, n)` | `function(a: Byte, n: Integer) -> Byte` | 右へ `n` ビットずらした値。上位を 0 で埋める |

【決定】`Byte` のシフトで、ずらす量 `n` が 0 以上 7 以下でなければ、実行時エラーとする。

【決定】新しい整数六種にも `bitwiseAnd`・`bitwiseOr`・`bitwiseExclusiveOr`・`bitwiseNot`・`shiftLeft`・`shiftRight` を設け、符号付き三種には `shiftRightUnsigned` も設ける。二項のビット演算の型は `function(a: T, b: T) -> T`、反転は `function(a: T) -> T`、シフトは `function(a: T, n: Integer) -> T` である。T は各整数型であり、シフト量は `Integer` で渡す。

幅 w のシフト量は 0 以上 w−1 以下に限り、範囲外は実行時エラーとする。左シフトは幅からはみ出たビットを捨て、下位に零を入れる。右シフトは符号付きでは符号ビット、符号なしと `shiftRightUnsigned` では零を入れる。符号付きの値は、その幅の 2 の補数のビット列として扱う。理由: ビット列の切り捨てを、算術の溢れとは区別する。

### 型の変換

【方針】基本型のあいだの変換の関数は次のとおりである。失敗しうる変換は `Option` を返す。

| 関数 | 型 | 値 |
|---|---|---|
| `Integer.toFloat(n)` | `function(n: Integer) -> Float` | `n` に最も近い `Float` の値（最近接偶数丸め） |
| `Float.truncate(x)` | `function(x: Float) -> Option[Integer]` | `x` を 0 の方向に切り捨てた整数。`x` が NaN・無限大か、結果が `Integer` の範囲を超えるときは `Option.None` |
| `Integer.toString(n)` | `function(n: Integer) -> String` | `n` の 10 進表記。負の数は先頭に `-` を付ける |
| `Float.toString(x)` | `function(x: Float) -> String` | 下の規則による表記 |
| `Integer.parse(s)` | `function(s: String) -> Option[Integer]` | 10 進の整数の表記を読んだ値。表記が正しくないか範囲を超えるときは `Option.None` |
| `Float.parse(s)` | `function(s: String) -> Option[Float]` | 10 進の数の表記を読み、浮動小数リテラルと同じ規則で丸めた値。表記が正しくないときと、浮動小数リテラルなら型検査の誤りになる値（丸めると無限大になるもの）のときは `Option.None` |
| `Decimal.fromInteger(n)` | `function(n: Integer) -> Decimal` | `n` と等しい値。小数の桁数は 0 |
| `Decimal.truncate(x)` | `function(x: Decimal) -> Option[Integer]` | `x` を 0 の方向に切り捨てた整数。結果が `Integer` の範囲を超えるときは `Option.None` |
| `Decimal.toFloat(x)` | `function(x: Decimal) -> Float` | `x` に最も近い `Float` の値（最近接偶数丸め） |
| `Decimal.fromFloat(x)` | `function(x: Float) -> Option[Decimal]` | `Float.toString(x)` の表記が表す数を、`Decimal` の値として読んだもの。小数の桁数は、表記の指数を展開した後の小数点の後の桁数である（`Decimal.fromFloat(1.0e21)` の中身は小数の桁数 0 の `1000000000000000000000`、`Decimal.fromFloat(1.5e-7)` の中身は 8 の `0.00000015`、`Decimal.fromFloat(0.1)` の中身は 1 の `0.1`）。小数点の後が 29 桁以上になるときは、小数の桁数 28 に最近接偶数丸めで丸める。`x` が NaN・無限大か、絶対値が `Decimal` の範囲を超えるときは `Option.None` |
| `Decimal.toString(x)` | `function(x: Decimal) -> String` | 下の規則による表記 |
| `Decimal.parse(s)` | `function(s: String) -> Option[Decimal]` | 10 進の数の表記を読んだ値。表記が正しくないときと、`Decimal` のリテラルなら型検査の誤りになる値のときは `Option.None` |

【決定】新しい数の変換は次のとおりである。表の T は `Integer8`・`Integer16`・`Integer32`・`UnsignedInteger16`・`UnsignedInteger32`、U はそれらと `UnsignedInteger64` の六種を表す。関数は各型と同名のモジュールに置き、すべて純粋である。

| 関数 | 型 | 値 |
|---|---|---|
| `T.fromInteger(n)` | `function(n: Integer) -> Option[T]` | T の値域に収まれば `Some`、範囲外は `None` |
| `T.toInteger(n)` | `function(n: T) -> Integer` | 全域で正確な値 |
| `U.parse(s)` | `function(s: String) -> Option[U]` | `Integer.parse` と同じ十進の字句。符号なしは負号を拒否し、範囲外は `None` |
| `U.toString(n)` | `function(n: U) -> String` | 十進表記。負値は先頭に `-`。接尾辞を付けない |
| `U.toFloat(n)` | `function(n: U) -> Float` | 最近接偶数丸めによる binary64 の値。T の五種では全域で正確 |
| `UnsignedInteger64.fromInteger(n)` | `function(n: Integer) -> Option[UnsignedInteger64]` | 負値は `None`、それ以外は正確な値 |
| `UnsignedInteger64.toInteger(n)` | `function(n: UnsignedInteger64) -> Option[Integer]` | 2^63 以上は `None`、それ以外は正確な値 |
| `UnsignedInteger64.toDecimal(n)` | `function(n: UnsignedInteger64) -> Decimal` | 全域で正確な値。小数の桁数は 0 |
| `UnsignedInteger64.fromDecimal(x)` | `function(x: Decimal) -> Option[UnsignedInteger64]` | 数学的に整数で、0 以上 2^64 − 1 以下なら `Some`。`1.0m` も認める。それ以外は `None` |
| `Float32.fromFloat(n)` | `function(n: Float) -> Option[Float32]` | 最近接偶数丸めで縮小。有限値が無限大になる場合は `None`。元からの無限大・NaN は `Some`。零への丸めと零の符号を保つ |
| `Float32.toFloat(n)` | `function(n: Float32) -> Float` | 有限値を正確に拡大し、零の符号を保つ |
| `Float32.parse(s)` | `function(s: String) -> Option[Float32]` | `Float.parse` と同じ字句を直接 binary32 に丸める。不正な表記と無限大になる値は `None` |
| `Float32.toString(n)` | `function(n: Float32) -> String` | 下の規則による表記 |
| `Float32.truncate(n)` | `function(n: Float32) -> Option[Integer]` | 0 の方向に切り捨てる。NaN・無限大・`Integer` の範囲外は `None` |

理由: 変換の失敗を `Option` で返し、算術の停止と区別する。幅どうしの直接の変換を全組み合わせで設けず、`Integer` と、u64 の全域では `Decimal` を介す。

`Float32` から狭い整数へは `truncate` と `fromInteger` を組み合わせる。`Float` から u64 の上半分への直接変換は設けない。`Decimal.fromFloat` は十進表記を介す関数であり、二進の値の正確な整数値を保存する変換ではない。

【方針】文字列補間（[字句構造](01-01-lexical.md)）は、`String` の値をそのまま、各幅の数・`Character`・`Decimal` の値をそれぞれの `toString` と同じ文字列に、`Boolean` の値を `true` か `false` の文字列にして埋め込む。

【方針】`Float.toString(x)` の表記は次のとおりである。同じ値に対して常に同じ文字列を返す。

- NaN は `NaN`、正の無限大は `Infinity`、負の無限大は `-Infinity` とする。
- 有限の値は、`Float.parse` で読み戻すと元の値になる 10 進表記のうち、有効数字が最も少ないものを使う。有効数字の桁数が同じ候補が複数あるときは、元の値に最も近いものを使う。
- 10 進の指数（有効数字を `d.ddd × 10^e` と書いたときの `e`）が −5 以上 21 未満なら、指数を使わずに書き、小数点の後に少なくとも 1 桁を置く（`1.0`、`0.001`、`123.45`）。それ以外は、仮数、`e`、指数の符号（`+` または `-`）、指数の 10 進表記の順に書く（`1.0e+21`、`1.5e-7`）。仮数は小数点の前に 1 桁、後に少なくとも 1 桁を置き、指数には先頭の 0 を付けない。
- 負の値と −0 は、先頭に `-` を付ける（`-0.0`）。

これらの表記は、どれも浮動小数リテラルとして書ける形である（NaN と無限大を除く）。

【決定】`Float32.toString` は、binary32 へ読み戻すと元の値になる最短の十進表記を使う。有効数字の選び方、小数点・指数の切り替え、`NaN`・`Infinity`・`-Infinity` と負の零の表記は `Float.toString` と同じであり、接尾辞は付けない。倍精度に拡大した値の最短表記は使わない。文字列補間と `Trait.Show` も同じ表記を使う。理由: 単精度の値を、表示先によらず同じ文字列で表す。

【方針】`Decimal.toString(x)` の表記は、`x` の符号（負の値だけ `-`）、整数部の 10 進表記、小数の桁数が 1 以上なら小数点と小数の桁数と同じ数の桁、の順に並べたものである。指数と接尾辞 `m` は付けない。`Decimal.toString(1.50m)` は `"1.50"`、`Decimal.toString(-3m)` は `"-3"`、`Decimal.toString(0.05m)` は `"0.05"` である。

【方針】`Integer.parse` と `Float.parse` が受け付ける表記は、それぞれ接尾辞のない整数リテラルの 10 進の形と浮動小数リテラルの形に、先頭の任意の `-` を加えたものである。ただし、接尾辞、基数の接頭辞、桁の区切り `_`、先頭の `+`、前後の空白は受け付けない。`Float.parse` は、整数リテラルの 10 進の形（`42`）も受け付ける。`NaN`・`Infinity` は受け付けない。絶対値が小さすぎて 0 に丸められる表記（`1e-9999`）は、浮動小数リテラルと同じく受け付け、符号を保った 0 を返す（`Float.parse("-1e-9999")` は `Option.Some(-0.0)`）。

【方針】`Decimal.parse` が受け付ける表記は、`Decimal` のリテラルから接尾辞 `m` を除いた形（`12`、`1.25`）に、先頭の任意の `-` を加えたものである。`Integer.parse` と同じく、桁の区切り `_`、先頭の `+`、前後の空白は受け付けない。リテラルと同じく、`0` 自身を除き `0` で始まる整数部（`"01.5"`、`"007"`、`"-01.5"`）も受け付けない。
