# 0254. 関数の宣言とラムダの戻り値の型を `->` の後に書く

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [構文](../01-spec/01-02-syntax.md), [型システム](../01-spec/01-06-type-system.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

[ADR 0094](0094-return-type-after-colon.md) は、関数の宣言とラムダの戻り値の型を `:` の後に書き（`function add(x: Integer, y: Integer): Integer`）、関数の型だけを `->` で書く（`function(Integer, Integer) -> Integer`）とした。設計者は、宣言と型で戻り値の書き方を揃える案を示した。

構文だけの測定（[OPEN-012](../open-issues.md#open-012) の第一段階、[ADR 0246](0246-syntax-measurement-in-two-stages.md)）の途中の結果では、Codex＋GPT-6-Luna の 720 試行で、この書き方を含む案（V05〜V08 と、四つをまとめた V15）も基準の案（V00）も、45 試行のうち 45 が 1 回目で構文の誤りなく書けた（2026-09-29。OpenCode＋LongCat の測定は続いている）。構文の案の違いは LLM の書きやすさを損ねていないので、設計者は、読みやすさと検査の明確さの理由から、次の四つの変更（戻り値の型の `->`、`bind` と `shadow`、`data`、`match … with` と `case … ->`）をまとめて採った。

## 決定

1. 関数の宣言とラムダの戻り値の型を `->` の後に書く（`function add(x: Integer, y: Integer) -> Integer`、`lambda(x: Integer) -> Integer … end lambda`）。
2. 関数の型の書き方（`function(Integer) -> Integer`）は変えない。
3. 戻り値の型を `:` の後に書いた宣言には、`->` と書く修正案を示す。

## 検討した代替案

- **`:` のまま**（ADR 0094）: 引数の型注釈と同じ記号で揃う。しかし、宣言の戻り値と関数の型の戻り値で記号が変わり、関数の型を返す関数（`function f() -> (function() -> Integer)`）でも宣言と型の区別が記号に頼らなくなる利点を捨てることになる。

## 帰結

- ADR 0094 の決定のうち、宣言とラムダの戻り値の型の記号を本 ADR で置き換える。
- 構文の章の文法、すべての章の例、文法を確かめる道具を改める。
