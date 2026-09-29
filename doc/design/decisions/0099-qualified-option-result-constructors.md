# 0099. `Option` と `Result` の構成子を型名で修飾して書き、`Err` を `Error` に改める

- 状態: 採択（[0148](0148-keep-qualified-constructors-and-shared-namespace.md) で維持を確認した）
- 日付: 2026-09-27
- 関連章: [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md), [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md), [エラー処理](../01-spec/01-09-errors.md), [標準ライブラリ](../03-interop/03-06-stdlib.md)
- 関連する未決事項: [OPEN-041](../open-issues.md#open-041), [OPEN-012](../open-issues.md#open-012)

## 背景

設計書は、`Option` と `Result` の構成子（`Some`・`None`・`Ok`・`Err`）だけを修飾せずに書き、ほかの型の構成子は型名で修飾して書く（`Shape.Circle`）としていた（[ADR 0007](0007-constructors-and-list.md)）。名前は Rust に合わせていた（[ADR 0043](0043-option-result-rust-names-no-unwrap.md)）。

`Err` は Error の省略形である。キーワードは省略しない語で書くことにした（[ADR 0092](0092-unabbreviated-keywords.md)）。OCaml・F#・Gleam は `Result` の構成子を `Ok`・`Error` とする（一次資料では確かめていない）。

大文字の名前は、型・モジュール・構成子などを一つの名前空間に入れる（[ADR 0010](0010-shared-namespace-and-shadowing.md)）。修飾せずに書く構成子の名前は、利用者が型の名前に使えない。構成子を `Error` とし、修飾せずに書くと、利用者が型を `Error` と名付けられなくなる。

## 決定

1. `Option` と `Result` の構成子も、ほかの型の構成子と同じく型名で修飾して書く（`Option.Some(x)`、`Option.None`、`Result.Ok(x)`、`Result.Error(e)`）。式の中でもパターンの中でも同じである。
2. `Result` の失敗の構成子の名前を `Err` から `Error` に改める。`Err` を含む関数の名前も改める（`Result.mapErr` を `Result.mapError`、`Result.isErr` を `Result.isError`）。
3. `Some`・`None`・`Ok`・`Error` は、利用者が型の名前に使ってよい。

## 検討した代替案

- **修飾せずに書き、型名 `Error` を誤りとする**: `Ok(x)` と書く多くの言語の習慣に合う。しかし、利用者（LLM）が付けたくなりやすい型名 `Error` を使えなくなる。
- **`Result` の構成子だけを修飾する**: `Option` と `Result` で構成子の扱いが分かれる。
- **型と構成子の名前空間を分ける（OCaml・Gleam）**: 修飾せずに書いたまま型名 `Error` を使える。しかし、[ADR 0010](0010-shared-namespace-and-shadowing.md) を改めることになり、名前解決の規則が変わる。名前空間の扱いは、[OPEN-041](../open-issues.md#open-041) で改めて検討する。

採った案の弱点は、記述量が増えることと、多くの言語で修飾せずに書く `Some(x)`・`Ok(x)` を LLM がそのまま書く誤りが起きうることである。この誤りの診断は、修飾した書き方を修正案として示す。

## 帰結

- すべての構成子を型名で修飾して書くので、構成子の書き方の規則が一つになる。
- [OPEN-041](../open-issues.md#open-041) の検討の結果、`Option` と `Result` の構成子の扱いを改めることがある。
- 全章の例と、[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の構成子の名前を改める。
- 修飾の有無による LLM の書き誤りの率を、[OPEN-012](../open-issues.md#open-012) の測定の対象に含めるかは【未決】である。
