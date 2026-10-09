---
name: git-workflow
description: このリポジトリで git のコミットを作成するときの規約。コミットメッセージの書式を定める。git commit を実行する前に使用する。
---

# Git の運用規約

## コミットメッセージ

公開するブランチ `san_benito` の履歴に入るコミットは、次の形で書く（ADR 0358 の決定 7）。作業用のブランチで作り、`san_benito` に取り込むコミットも同じ形で書く。

1. 1 行目に、変更の要約を英語だけで書く。
2. 空行の後に、変更内容を英語の箇条書き（`- `）で列挙する。
3. 空行の後に、1 行目の日本語の訳を書く。
4. 空行の後に、変更内容を日本語の箇条書き（`- `）で列挙する。英語の箇条書きと同じ内容にする。
5. 空行の後に、`Co-Authored-By` などの行を置く。

例:

```
Add the Git workflow rules to AGENTS.md

- Add the "Git workflow" section
- State the rule for writing commit messages in English and Japanese

AGENTS.md に Git の運用規約を追加

- 「Git の運用」節を追加
- コミットメッセージを英語と日本語で書く規約を明記
```

取り込みのコミット（`git merge --no-ff`）の 1 行目は、git が作る `Merge ...` のままでよい。
