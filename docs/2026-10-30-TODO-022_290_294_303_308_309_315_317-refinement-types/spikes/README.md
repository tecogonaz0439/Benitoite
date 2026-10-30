# 捨てる試作 P1〜P4

0.0.14 の改造の捨てる試作（2026-10-30）の写しである。原本は作業用のディレクトリにあり、取りまとめがここへ写した。本番の `formal/`・`crates/` には取り込まない。

| 試作 | 内容 | 依頼文 | レビュー |
|---|---|---|---|
| [P1](P1/findings.md) | 値に依存する篩型の Lean の骨格を三案で比べる | [prompts/P1-prompt.md](prompts/P1-prompt.md) | [RV-P1](../reviews/RV-P1.md) |
| [P2](P2/findings.md) | 自作の線形整数の判定の手続きと証明書の検査器 | [prompts/P2-prompt.md](prompts/P2-prompt.md) | [RV-P2](../reviews/RV-P2.md) |
| [P3](P3/findings.md) | 構文の型付け・主な定理・権限の値への接続（P3b を含む） | [prompts/P3-prompt.md](prompts/P3-prompt.md)・[prompts/P3b-prompt.md](prompts/P3b-prompt.md) | [RV-P3](../reviews/RV-P3.md) |
| [P4](P4/findings.md) | 部分型の文脈を論理の埋め込みで表す案 | [prompts/P4-prompt.md](prompts/P4-prompt.md) | [RV-P4](../reviews/RV-P4.md) |

共通条件は [prompts/P-common.md](prompts/P-common.md)。

## 写したときに変えたこと

- 手元の絶対パスを `<repo>`（リポジトリの根）・`<home>`・`<tmp>` に置き換え、作業用のディレクトリの中の試作と依頼文への参照を、この写しの中の相対の位置（`spikes/`・`spikes/prompts/`）に置き換えた（209ファイル）。そのため、試作が記録した各ファイルの SHA-256 は、置き換えの後のファイルとは一致しない。記録の SHA-256 は原本の値である。
- Lean のビルドの生成物（`.olean`・`.ilean`、7ファイル）と Rust の `target/` は写していない。
- 200 KiB を超える次の4ファイルは gzip で圧縮した（圧縮の前、置き換えの後の SHA-256）。

| ファイル | SHA-256（圧縮の前） |
|---|---|
| P1/checks/10.log | 2762b2a9d4874beb7e48a6bf6df0cbf217cf4c8adf733fa929f579d8c3ab7a4a |
| P1/inventory.json | 31cf9495bee80786b40235b3d4c4bc7ac93a9b305950ec9a2c9c395b36c17695 |
| P3/P3b-inventory.json | 2a6395d769d78b607601e16833accc00e68ebab001346f10334dd821328345d5 |
| P4/protected-before-final.json | 9aa61a7153e92993113faf992d4b336301173a5ae440e7f8970fe1f0d3382477 |
