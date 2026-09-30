# 0257. パターンで分岐する式を `match 対象 with case パターン -> … end match` と書き、ハンドラの節も `with case …` で書く

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [構文](../01-spec/01-02-syntax.md), [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md), [エフェクト](../01-spec/01-07-effects.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

パターンで分岐する式は `case 対象 of when パターン: … end case` と書き（[ADR 0111](0111-case-of-when.md)）、ハンドラの節も `handle 本体 when op(x): … end handle` と、同じ `when …:` で書いた（[ADR 0118](0118-effect-handlers.md)）。設計者は、OCaml や F# と同じ `match … with` の形で書き、分岐を `case パターン -> 式` と書く案を示した。

構文だけの測定（[OPEN-012](../open-issues.md#open-012) の第一段階、[ADR 0246](0246-syntax-measurement-in-two-stages.md)）の途中の結果では、Codex＋GPT-6-Luna の 720 試行で、この書き方を含む案（V05〜V08 と、四つをまとめた V15）も基準の案（V00）も、45 試行のうち 45 が 1 回目で構文の誤りなく書けた（2026-09-29。OpenCode＋LongCat の測定は続いている）。構文の案の違いは LLM の書きやすさを損ねていないので、設計者は、読みやすさと検査の明確さの理由から、次の四つの変更（戻り値の型の `->`、`bind` と `shadow`、`data`、`match … with` と `case … ->`）をまとめて採った。

## 決定

1. パターンで分岐する式を `match 対象 with` の後に、分岐 `case パターン -> 本体` を並べ、`end match` で閉じる。ガードは `case パターン if 条件 -> 本体`、選択肢はこれまでどおりコンマで並べる（`case 1, 2 -> …`。[ADR 0121](0121-pattern-extensions.md)）。本体が複数の文からなるときは、`->` の後で改行して続ける。
2. ハンドラの節も同じ形にする。`handle 本体 with case op(x) -> 節の本体 end handle` と書く。分岐を書く形を一つにする（原則 5）。
3. `case` は分岐の頭の語になる。`of` と `when` はキーワードでなくなる。
4. `with` は、`match`・`handle` の分岐の並びの始まりと、リソーススコープ（`with x = e do … end with`）の両方に使う。文法の上では、`match 対象` と `handle 本体` の後の `with` は分岐の並びの始まりであり、文の頭の `with` はリソーススコープである。
5. `case 対象 of` の形で書いたときは、予約語にはせず（[ADR 0093](0093-no-reserved-words-for-absent-constructs.md)）、`match … with` の書き方を修正案として示す。

## 検討した代替案

- **`case … of when …:`**（ADR 0111）: Pascal や Ada の `case … of` に近い。しかし、`case` が式の頭と分岐の頭の両方の候補になりうる書き方を、多くの関数型言語は `match` で書く。
- **ハンドラの節は `when` のまま**: 変更が小さい。しかし、分岐を書く形が二つになり、原則 5 に反する。

## 帰結

- ADR 0111 を本 ADR で置き換える。ADR 0118 の節の書き方と、ADR 0121 のガードの書き方を本 ADR の形に改める。
- 改行の規則（[字句構造](../01-spec/01-01-lexical.md)）のうち、ガードの `if` をブロックと読まない範囲を、`case` から `->` までに改める。
