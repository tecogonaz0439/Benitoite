---
name: git-workflow
description: このリポジトリで git のコミットを作成するときと、ソースだけのリリース（0.0.x）を準備するときの規約。コミットメッセージの書式、履歴の集約、タグと push の手順を定める。
---

# Git の運用規約

## コミットメッセージ

公開するブランチ `san_benito` の履歴に入るコミットは、次の形で書く。作業用のブランチで作り、`san_benito` に取り込むコミットも同じ形で書く。

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

## ソースだけのリリース（0.0.x）

`0.0.x` はソースだけを公開し、各版で互換性を壊してよい。バイナリを伴う最初の版は `0.1.0` とし、その後の互換性を壊す変更は `0.x.0` に限る（ADR 0358。計画は docs/todo の TODO-001・073）。設計者がリリースの準備を指示したら、次の順に行う。

1. 版・CHANGELOG・`docs/reference/`・`docs/ja/` の版の記述と訳をそろえる。版を上げた後、`cargo update --offline -p benitoite` と `cargo update --offline --manifest-path fuzz/Cargo.toml -p benitoite` で二つの lock のパス依存の記録を同期し、両方の差分を確認する。依存のキャッシュが足りなければ不足を確認して取得し、対象を benitoite に絞った同じコマンドを使う。一括更新はしない。同梱の Skill と生成物も候補に合わせる。性能の測定は準備に入る前に済ませる（スキル `benchmark`）。
2. 計画に割り当てた検査と、実際の候補の CLI・版・同梱物・生成物・移行案内・配布の照合を終え、レビューと設計者の受け入れを得る。検査と引用は AGENTS.md「テストの運用」に従う。候補のワークスペースと fuzz の二 lock、および Rust・Cargo・Lean・elan の固定版の勧告を、スキル [security-advisories](../security-advisories/SKILL.md) に従って再照合する。Rust は `rust-toolchain.toml`、Lean・elan は Lean 担当の引き渡した候補の版を使い、影響する構成と機能/APIも確認する。cargo-deny の成功や Lean のビルドだけでツールチェーンまで確認済みとしない。取りまとめは照合日・入力と版・根拠・最初の照合との差・未照合の範囲を改造の `security-advisories.md` に残し、候補の results.md から参照する。新しい勧告や未照合は表示・記録して設計者へ報告し、検査の不合格条件や受け入れの停止条件にしない。新しい勧告への対応は次の改造の最初の判断へ引き継ぎ、ignore の追加や期限で候補を止めない。最初に対応すると決めた項目の完了条件は保つ。
3. `docs/todo/README.md` に従って項目を閉じ、残る課題を記録する。通常は docs/todo の中でコミットする。改造のディレクトリを `git mv` で `docs/archive/` へ移し、相対リンクと保管先への参照を直す。
4. 公開する変更をコミットした後、元の先頭を手元の控えのブランチ `backup/before-v<版>` に残す。このブランチは送らない。
5. 前のリリースのタグの後ろを、一つのコミットに集約する。上の書式で集約のメッセージを作り、設計者の承認を得る。集約の前後で木の ID が一致することを確かめる。集約を終えてからタグを付ける。
6. 注釈なしの軽量タグ `v<版>` を付ける。`--version=json` や Skill の producer など、コミットに依存する候補の情報と証拠を集約後の状態へ照合する。
7. スキル `archive-and-bundle` に従って tar.gz と zip を作る。
8. push は設計者の指示を得てから、`git push --atomic origin san_benito v<版>` で早送りする。送るのは `san_benito` と当該リリースのタグだけとし、`backup/*` と作業用のブランチは送らない。

依頼でコミット等を禁じられている場合は、その指示を優先する。集約やタグの付け直しが自動承認の審査で止められたときは、拒否された操作と理由を設計者に伝える。設計者が実行するスクリプトを用意する場合も、エージェントから実行して拒否を迂回しない。
