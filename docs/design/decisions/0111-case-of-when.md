# 0111. パターンで分岐する式を `case 対象 of when パターン: … end case` の形で書く

- 状態: 置換済み（[0257](0257-match-with-case-arms.md) により）
- 日付: 2026-09-28
- 関連章: [構文](../01-spec/01-02-syntax.md), [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

パターンで分岐する式は、`switch 対象 { case パターン: 式 }` の形で書いていた（[ADR 0095](0095-case-arms.md)、[ADR 0100](0100-switch-keyword.md)）。ブロックを語で閉じる形にした（[ADR 0108](0108-keyword-blocks-closed-by-end.md)）ので、分岐の本体に複数の文を書いたときに、本体の続きの文と次の分岐の始まりを見分ける手がかりが要る。Pascal は `case x of 値: 文 end`、Ada は `case X is when 値 => … end case`、Ruby は `case x when 値 … end` と書く。これらの言語の書き方は、一次資料で確かめていない。

## 決定

1. パターンで分岐する式を、`case 対象 of` で始め、`end case` で閉じる。
2. 分岐は `when パターン:` で始める。分岐の本体には、一つの式も、改行で区切った複数の文も書ける。本体は、次の `when` か `end case` までである。分岐の本体の値は、最後の式の値である。
3. `case`・`of`・`when` をキーワードにし、`switch` はキーワードから外す。
4. LLM が `switch` と書いたときは、`case … of` の形を修正案として示す。

## 検討した代替案

- **`switch … { case …: }` のままにする**: 直前に決めた形である。しかし、ブロックを語で閉じる形と揃わない。
- **分岐の先頭に語を置かない（Pascal と同じ `パターン: 式`）**: 記述量が少ない。しかし、分岐の本体に複数の文を書いたとき、本体の続きと次の分岐を見分けられない。
- **分岐の先頭を `case` にする（Scala と同じ）**: 全体の始まりの `case` と同じ語になり、紛らわしい。

## 帰結

- ADR 0095 と ADR 0100 を置き換える。
- C 系の `switch` の書き方（`default:`、`break`）への診断は、`switch` と書いたときの診断にまとめる。
- `case … of … when` の LLM の書き誤りの率を、[OPEN-012](../open-issues.md#open-012) の測定の対象とする。
