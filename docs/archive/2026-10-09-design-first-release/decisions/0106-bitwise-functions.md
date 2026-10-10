# 0106. ビット演算を、演算子ではなく `Integer` と `Byte` の関数として設ける

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [基本型の意味論](../01-spec/01-04-types-basic.md), [標準ライブラリ](../03-interop/03-06-stdlib.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

最小実行版には、ビット演算（ビットごとの論理積、シフトなど）がなかった。バイナリの形式の読み書きとハッシュなどの計算で要る。

C 系の言語は、ビット演算に演算子（`&`・`|`・`^`・`~`・`<<`・`>>`）を使う。C の `a & b == c` は `a & (b == c)` と読まれ、優先順位の誤りの原因として知られている。Kotlin は演算子を設けず、名前の付いた関数（`a and b`、`a shl 2` など）で書く。これらの言語の扱いは、一次資料で確かめていない。

## 決定

1. ビット演算は、演算子ではなく関数として設ける。
2. `Integer` に、`bitwiseAnd`・`bitwiseOr`・`bitwiseExclusiveOr`・`bitwiseNot`・`shiftLeft`・`shiftRight`（空いた上位のビットを符号のビットで埋める）・`shiftRightUnsigned`（0 で埋める）を設ける。
3. `Byte` に、`bitwiseAnd`・`bitwiseOr`・`bitwiseExclusiveOr`・`bitwiseNot`・`shiftLeft`・`shiftRight`（0 で埋める）を設ける。
4. `shiftLeft` ではみ出たビットは捨てる。溢れの実行時エラーにはしない。
5. ずらす量が `Integer` で 0〜63、`Byte` で 0〜7 の範囲の外なら、実行時エラーとする。

## 検討した代替案

- **C 系の演算子を設ける**: LLM に最もなじみがある。しかし、優先順位の誤りを招き、`&` は型クラスの制約に（[ADR 0098](0098-constraints-joined-by-ampersand.md)）、`|` は `|>` に近く、`^` は他の言語の累乗と紛れる。
- **ずらす量の下位のビットだけを使う（Kotlin・Java と同じ）**: 実行時エラーが起きない。しかし、`shiftLeft(a, 64)` が `a` のままになる動きは、LLM も人間も予想しにくい。整数の溢れを実行時エラーにする方針（[ADR 0006](0006-basic-types-semantics.md)）とも揃わない。
- **`bitwiseXor` と縮めて書く**: 短い。しかし、省略しない名前の方針（[ADR 0101](0101-unabbreviated-names.md)）に合わせて、`bitwiseExclusiveOr` とする。

## 帰結

- 演算子の優先順位の表と字句の記号は変わらない。
- パイプと組み合わせて書ける（`x |> Integer.shiftRight(8) |> Integer.bitwiseAnd(0xFF)`）。
- 関数と演算子の LLM の書き誤りの率を、[OPEN-012](../open-issues.md#open-012) の測定の対象に含めるかは【未決】である。
