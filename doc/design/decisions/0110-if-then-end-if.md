# 0110. `if` を `if 条件 then … else … end if` の形で書く

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [構文](../01-spec/01-02-syntax.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

これまでの `if` は、条件の後に波括弧のブロックを書いていた（`if c { … } else { … }`）。ブロックを語で閉じる形にした（[ADR 0108](0108-keyword-blocks-closed-by-end.md)）ので、条件と分岐の区切りを語で示す必要がある。Pascal・OCaml・Haskell・Elm は `then` を使い、Ada は `end if` で閉じる。これらの言語の書き方は、一次資料で確かめていない。

## 決定

1. `if` は `if 条件 then 文の並び else 文の並び end if` の形で書き、いつも `end if` で閉じる。`else` は省略できる。
2. 分岐には、一つの式も、改行で区切った複数の文も書ける（`return if x = 0 then 0 else 1 end if`）。
3. `else` の直後の `if` は、同じ `if` の続きの分岐として読み、`end if` は一つで閉じる（`if a then … else if b then … else … end if`）。
4. `if` は、これまでどおり値を持つ式である。

## 検討した代替案

- **`end if` を省き、単一の式の分岐では閉じない（Pascal と同じ）**: 短い `if` の式が短く書ける。しかし、入れ子の `if` で `else` がどの `if` に付くかが曖昧になる（ぶら下がり else）。
- **`else if` に専用の語を設ける（Ada の `elsif`、Lua の `elseif`）**: 規則は明確になる。しかし、語が一つ増え、C 系の言語に慣れた LLM は `else if` と書きやすい。

採った案は、いつも `end if` で閉じるので、ぶら下がり else が起きない。条件の終わりを `then` が示すので、条件の直後の波括弧をブロックの始まりとして読む特別の規則も要らない。

## 帰結

- 最も短い `if` の式でも `end if` が要り、記述量が増える。
- `if … then` の LLM の書き誤りの率を、[OPEN-012](../open-issues.md#open-012) の測定の対象とする。
