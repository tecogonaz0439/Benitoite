# T07 組み込み関数: 数値と文字と演算子

- 依存する作業: [T06](T06-values-heap.md)
- 難易度: 3（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T07-builtins-numeric

## 目的

演算子の意味を一か所で定める補助の関数（`ops.rs`）と、演算子・`Int`・`Float`・`Char` の組み込みの関数（`PureFn`）を実装する。VM の演算の命令と参照インタプリタは、同じ補助の関数を呼ぶので、ここで決めた意味が両方の実行の意味になる。`Float` の文字列への変換と読み取りの細かな規則を、01-04 のとおりに実装する。

## 読む設計書の節

- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)の「Int」「Float」「String」（`+` と比較）「Char」「Bool」「Unit」「型の変換」
- [標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md)の「Int」「Float」「Char」「作る値の大きさの上限」
- [型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md)の「等値の型」（`==` の意味）
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」
- [組み込みの関数](../10-interfaces/10-10-builtins.md)の「組み込みの表の型」「演算子」「prelude のモジュールの関数」のうち `Int`・`Float`・`Char`、「実装の関数」
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「止まる理由」「実行時の値」「ヒープ」

## 作るもの

- `src/builtins/ops.rs`: 10-10 の `sig=src/builtins/ops.rs` の補助の関数（`int_add` から `string_concat` まで）と、演算子の一覧のすべての `PureFn`（`add_int` から `ne` まで）。
- `src/builtins/int.rs`・`src/builtins/float.rs`・`src/builtins/character.rs`: 10-10 の一覧の `Int`・`Float`・`Char` の関数の `PureFn`。
- 上のファイルの中のテスト。

## 手順の要点

### 共通

- `PureFn` は、引数の個数と種類を `args.get(i)` と `Value::as_*` で読み、合わなければ `Stop::Internal` を返す。この読み取りの補助は各ファイルで書いてよい（非公開の関数）。
- `Option` の値は、`heap.ctor(0, vec![x])`（`Some`）と `heap.ctor(1, vec![])`（`None`）で作る（タグは 02-07「コンパイル済みプログラム」）。
- 実行時エラーは `Stop::Runtime(RuntimeError::IntegerOverflow)` と `Stop::Runtime(RuntimeError::DivisionByZero)` で返す。

### Int の演算子

- `int_add`・`int_sub`・`int_mul` は `checked_*` を使い、`None` を溢れにする。
- `int_div(a, b)`: `b == 0` なら 0 による除算。`checked_div` が `None`（`a == i64::MIN && b == -1`）なら溢れ。Rust の `/` は 0 の方向に切り捨てるので、そのまま 01-04 の意味になる。
- `int_rem(a, b)`: `b == 0` なら 0 による除算。`checked_rem` が `None` になる `a == i64::MIN && b == -1` のときは `0` を返す（01-04 は溢れにしないと定める）。
- `int_neg(a)`: `checked_neg` が `None` なら溢れ。
- `Int.floorDiv(a, b)`: 0 による除算と溢れの条件は `/` と同じ。`q = a / b` を求め、`a % b != 0` で `a` と `b` の符号が違えば `q - 1`（この減算は溢れない）。`Int.mod(a, b)`: `b == 0` なら 0 による除算、`a == i64::MIN && b == -1` なら `0`、それ以外は `r = a % b` を求め、`r != 0` で `r` と `b` の符号が違えば `r + b`。例: `floorDiv(-7, 2) = -4`、`mod(-7, 2) = 1`。
- `Int.abs`: `checked_abs` が `None` なら溢れ。`Int.min`・`Int.max` は溢れない。

### Float の演算子と比較

- `+ - * /` と単項の `-` は Rust の `f64` の演算そのものである（IEEE 754 の最近接偶数丸め。0 による除算は無限大か NaN）。
- 比較 `<`・`<=`・`>`・`>=`・`==` は Rust の `f64` の比較そのものである。NaN との比較はすべて `false` になる。`!=` は `==` の否定である（NaN でも `true`）。

### String と Char の比較と連結

- `String` の `<` などは、Rust の `str` の比較（バイト列の辞書式の順序）をそのまま使う。01-04 は、スカラー値の辞書式の順序と UTF-8 のバイト列の辞書式の順序が一致すると定める。
- `Char` の比較は `char` の比較（スカラー値の大小）である。
- `string_concat(heap, a, b)`: `a.len()` と `b.len()` の和を `checked_add` で求め、`MAX_STRING_BYTES` を超えるなら、文字列を作らずに `ValueTooLarge { function: "+", size, unit: Bytes, limit: MAX_STRING_BYTES }` を返す。和が `u64` に収まらないときも同じく返す（`size` は `u64::MAX`）。

### `==` と `!=`

`eq` と `ne` の `PureFn` は、引数の値の種類で比べ方を選ぶ。`Int`・`Float`・`Bool`・`Char`・`Unit`・`Str` は値で比べ、`Ctor` と `List` は `values_equal`（T06）で比べる。関数の値と `IoError` は `Stop::Internal` にする。

### 変換の関数

- `Int.toString`: Rust の `i64` の `to_string` と同じ 10 進表記（負の数は `-` を付ける）。
- `Int.parse(s)`: 受け付ける表記は、任意の先頭の `-` と、10 進の数字列（`0` 自身を除き `0` で始まらない）である。`_`・`+`・空白・空文字列・`-` だけは `None`。範囲を超えれば `None`。`-9223372036854775808` は `Some`。数字列の検査を先に行ってから `str::parse::<i64>` を使う。
- `Int.toFloat`: `n as f64` は最近接偶数丸めである（Rust の数値の変換の規則）。`as` を使う箇所として、[実装の規約](../00-common/00-02-conventions.md)の「数値の変換」に当たる理由をコメントに書く。
- `Float.truncate(x)`: NaN と無限大は `None`。`x.trunc()` が `-9223372036854775808.0` 以上 `9223372036854775808.0` 未満なら `Some`、そうでなければ `None`。
- `Float.isNaN`・`Float.abs`・`Float.sqrt`: Rust の `f64` の同名の関数。
- `Float.floor`・`Float.ceil`・`Float.round`: Rust の `f64::floor`・`ceil`・`round` は、NaN・無限大・±0 をそのまま返し、結果が 0 のときの符号を引数と同じにし、`round` は中間を 0 から遠いほうに丸める。これは 03-06 の規則と一致するので、そのまま使う。受け入れテストで、03-06 の例（`Float.ceil(-0.5)` が `-0.0`、`Float.round(-0.4)` が `-0.0`）を確かめる。
- `Char.toInt`・`Char.fromInt`（`char::from_u32`。サロゲートと U+10FFFF を超える値は `None`、負の数と `u32` に収まらない数も `None`）・`Char.toString`・`Char.isAsciiDigit`・`Char.isAsciiWhitespace`（U+0020・U+0009・U+000A・U+000D の四つだけ。Rust の `is_ascii_whitespace` は U+000C も含むので使わない）。

### `Float.toString`

01-04「型の変換」の規則で書く。

1. NaN は `NaN`、正の無限大は `Infinity`、負の無限大は `-Infinity`。
2. 有限の値は、`format!("{:e}", x.abs())` で、読み戻すと元の値になる最も短い 10 進の有効数字と指数を得る（Rust の `LowerExp` の書式は、有効数字の桁数を指定しないとき、読み戻して同じ値になる最も短い表記を出す）。出力は `d.ddde<指数>` か `de<指数>` の形なので、`e` で分けて、仮数の数字列（小数点を除く）と 10 進の指数 `e` を取り出す。
3. 指数 `e` が −5 以上 21 未満なら、指数を使わずに書く。数字列を小数点の位置 `e + 1` に合わせて並べ、足りない桁は 0 で埋め、小数点の後に少なくとも 1 桁を置く（`100000000000000000000.0`、`0.00001`）。
4. それ以外は、仮数を小数点の前に 1 桁、後に少なくとも 1 桁（数字が 1 桁なら `0`）置き、`e`、指数の符号（`+` か `-`）、先頭の 0 を付けない指数を続ける（`1.0e+21`、`1.5e-7`）。
5. 負の値と −0 は先頭に `-` を付ける（符号は `is_sign_negative` で判定する。`-0.0` は `-0.0`）。

### `Float.parse`

1. 受け付ける表記は、任意の先頭の `-` に続く、浮動小数リテラルの形（01-01「浮動小数リテラル」から `_` を除いたもの）か、整数リテラルの 10 進の形である。`+`・`_`・空白・`NaN`・`Infinity`・`inf`・`.5`・`1.`・`01.5` は `None`。この文法の検査を先に手で書く。
2. 検査を通った文字列を `str::parse::<f64>` で読む。Rust の `f64` の `FromStr` は最近接偶数丸めで読む。
3. 結果が無限大なら `None`（浮動小数リテラルなら型検査の誤りになる値）。0 に丸められた値は、符号を保って `Some` にする（`Float.parse("-1e-9999")` は `Some(-0.0)`）。

## 受け入れテスト

- `int_div`: `(-7, 2)` → `-3`、`(7, -2)` → `-3`、`(1, 0)` → 0 による除算、`(i64::MIN, -1)` → 溢れ。`int_rem`: `(-7, 2)` → `-1`、`(7, -2)` → `1`、`(i64::MIN, -1)` → `0`、`(1, 0)` → 0 による除算。
- `int_add(i64::MAX, 1)`・`int_mul(i64::MIN, -1)`・`int_neg(i64::MIN)`・`Int.abs(i64::MIN)` → 溢れ。
- `Int.floorDiv(-7, 2)` → `-4`、`Int.mod(-7, 2)` → `1`、`Int.mod(7, -2)` → `-1`、`Int.mod(i64::MIN, -1)` → `0`、`Int.floorDiv(i64::MIN, -1)` → 溢れ。
- `Int.parse`: `"42"` → `Some(42)`、`"-0"` → `Some(0)`、`"007"`・`"+1"`・`"1_000"`・`" 1"`・`""`・`"-"`・`"9223372036854775808"` → `None`、`"-9223372036854775808"` → `Some(i64::MIN)`。
- `Float.toString` の表: `1.0` → `"1.0"`、`0.1` → `"0.1"`、`1e21` → `"1.0e+21"`、`1e20` → `"100000000000000000000.0"`、`1.5e-7` → `"1.5e-7"`、`0.00001` → `"0.00001"`、`0.000001` → `"1.0e-6"`、`123.45` → `"123.45"`、`-0.0` → `"-0.0"`、`f64::MAX` → `"1.7976931348623157e+308"`、`5e-324` → `"5.0e-324"`、NaN → `"NaN"`、`-inf` → `"-Infinity"`。
- `Float.parse`: `"1.5"` → `Some(1.5)`、`"42"` → `Some(42.0)`、`"1e10"` → `Some(1e10)`、`"-1e-9999"` → `Some(-0.0)`（符号が負）、`"1e400"`・`"NaN"`・`"inf"`・`".5"`・`"1."`・`"1_0.0"`・`"+1.0"` → `None`。`Float.toString` の表の NaN と無限大以外の各値について、`Float.parse(Float.toString(x))` が `x` と同じビット列になる。
- `Float.truncate`: `2.9` → `Some(2)`、`-2.9` → `Some(-2)`、NaN・無限大・`9.3e18` → `None`、`-9.223372036854775808e18` → `Some(i64::MIN)`。
- `Float.floor(-0.5)` → `-1.0`、`Float.ceil(-0.5)` → `-0.0`、`Float.round(2.5)` → `3.0`、`Float.round(-0.4)` → `-0.0`、`Float.sqrt(-1.0)` → NaN。
- 比較: `lt_float(NaN, 1.0)`・`eq`（NaN と NaN）→ `false`、`ne`（NaN と NaN）→ `true`、`eq(0.0, -0.0)` → `true`。`lt_string("a", "b")` → `true`、`lt_string("é", "z")` → `false`（U+00E9 は `z` より大きい）。
- `string_concat` が上限を超える場合（長さの合計が `MAX_STRING_BYTES + 1` になる二つの文字列を作らずに済むよう、補助の関数の大きさの判定を、長さの数値で確かめられる非公開の関数に分けてテストする）→ `ValueTooLarge { function: "+", unit: Bytes, .. }`。
- `Char.fromInt`: `0x41` → `Some('A')`、`0xD800`・`0x110000`・`-1` → `None`。`Char.isAsciiWhitespace('\u{0C}')` → `false`。
- `eq` に構成子の値を渡すと `values_equal` の結果になり、関数の値を渡すと `Stop::Internal`。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 10-10 の一覧の演算子と `Int`・`Float`・`Char` の関数の `PureFn` が、一覧の名前ですべてある

## 難易度の理由

個々の関数は短いが、境界の場合（`i64::MIN`、`-1` との除算、符号付きの 0、NaN、指数の境目）が多く、01-04 の規則と一つずつ突き合わせる必要がある。特に `Float.toString` は、Rust の `LowerExp` の出力から数字列と指数を取り出して別の書式に組み直す処理であり、桁の埋め方と指数の境目で誤りやすい。
