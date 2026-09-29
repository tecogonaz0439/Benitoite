# 0100. パターンで分岐する式のキーワードを `match` から `switch` に改める

- 状態: 置換済み（[0111](0111-case-of-when.md) により）
- 日付: 2026-09-28
- 関連章: [構文](../01-spec/01-02-syntax.md), [字句構造](../01-spec/01-01-lexical.md), [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

パターンで分岐する式は、`match` で始め、分岐を `case パターン: 式` の形で書いていた（[ADR 0095](0095-case-arms.md)）。`match … { case … }` の組み合わせは Scala に近く、分岐の `:` は Swift と Python に近い。

関数型言語は `case … of`（Haskell・Elm）、`match … with`（OCaml・F#）、`case … { }`（Gleam）、`match … { }`（Rust・Koka）を使う。`switch … { case …: }` は C・Java・JavaScript・Swift の形である。これらの言語の書き方は、一次資料で確かめていない。

## 決定

1. パターンで分岐する式のキーワードを `switch` とする（`switch shape { case Shape.Circle(r): … }`）。`switch` をキーワードにし、`match` はキーワードから外す。
2. 分岐の書き方（`case パターン: 式`、改行による区切り、波括弧）は、[ADR 0095](0095-case-arms.md) のまま変えない。
3. 概念の名前（パターンマッチ、網羅性の検査など）と、[コア計算と脱糖](../01-spec/01-12-core-calculus.md)と中間表現の記法の `match` は変えない。

## 検討した代替案

- **`match` のままにする**: Rust・Scala・Koka と同じである。しかし、`case パターン:` と組み合わせると、`switch … { case …: }` の形をとる言語（C・Java・JavaScript・Swift）に近い見た目でありながら、語だけが違う。

採った案の弱点は、C 系の言語の `switch` の書き方を LLM が持ち込む誤りが起きうることである。次の書き方は、構文の誤りとして報告し、修正案を示す。

- `default:` と書く。`case _:` と書くよう示す。
- 分岐の後に `break` を書く。分岐は次の分岐へ続かない（fallthrough しない）ので、`break` は要らないことを示す。
- `case パターン:` の後の行に、波括弧で囲まずに複数の文を並べる。ブロック `{ ... }` で囲むよう示す。

## 帰結

- [構文](../01-spec/01-02-syntax.md)の文法と例、[字句構造](../01-spec/01-01-lexical.md)のキーワードの一覧、全章の例の `match` を `switch` に改める。
- `match` を予約語に残すかは、[ADR 0093](0093-no-reserved-words-for-absent-constructs.md) と同じく予約しない。予約語に加えるかどうかは、[OPEN-012](../open-issues.md#open-012) の測定の結果で決める。
- `switch` と `match` の LLM の書き誤りの率を、[OPEN-012](../open-issues.md#open-012) の測定の対象に含めるかは【未決】である。
