# Z7 G7 の指摘の修正結果

## 変更

G7 の軽微な指摘 L1〜L4 を、オーケストレータが指定した修正案に従って直した。

| 指摘 | 変更ファイルと内容 |
|---|---|
| L1 | `crates/benitoite/src/modules/text.rs` の `LOADER_ENVIRONMENT_MIGRATION` は、宣言の更新先を `the current version` とし、参照先も `see CHANGELOG.md` として版の数字を除いた。`src/modules/tests.rs`・`src/modules/package.rs` の全文の期待値、`testdata/packages/older-language.diag.json`、`design.md` を同じ文言に揃えた。`CHANGELOG.md`、設計書 01-03・06-09、英語リファレンスと日本語訳にも、現在の処理系の版への更新であることを反映した |
| L2 | `CHANGELOG.md` の Harness interfaces の3で、全対象の準備と検査を先に行うのは `--allow-effects` を付けた場合だけであり、付けない場合はファイルごとに準備・実行することを明記した |
| L3 | `harness-response.md` の移行段落で、依存の `language` の更新自体が内容の変更になるため、すべての依存の内容を確定してから記録したハッシュを更新するよう案内した。余分な半角空白を除き、2件の相対リンクをリポジトリの根からのパスの文字表記にした。ほかの節に同種のリンクはなかった |
| L4 | `docs/ja/reference/install.md`・`docs/ja/skill/references/inspection.md` の「後者」を「これらの誤りでは」へ、`docs/ja/reference/benitoite.md` の「どの位置の空白も」を「どの位置にある空白」へ、install.md の「だけでも」を「だけでは」へ直した |
| 記録 | 依頼に添付された G7 の報告全文を `reviews/G7.md` へそのまま保存し、本書に修正と検査の結果を記録した |

テストは既存の期待値の更新だけであり、新設・削除はない。`test-audit` の作成時の関門では、既存の読み込みと CLI の境界で診断全文と版の境界を守ること、旧い help なら全文比較が失敗すること、追加テストと差し込み口が不要であることを確認した。assert・入力・ignore は変更していない。本番コードは1行追加・1行削除、Rust のテストは2行追加・2行削除で、行数の純増減はそれぞれ0である。golden は最後の help.message だけを変え、ほかの JSON の値と構造を保持した。

## 検査

実行前にコマンドと所要時間の見込みを知らせ、既定構成で実施した。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,197 passed、0 failed、既存21 ignored。79.61秒 |
| 下記8統合テスト | 95 passed、0 failed。88.70秒 |
| `cargo clippy --all-targets` | 成功、指摘なし |
| `cargo fmt --check` | 成功 |
| `git diff --check` | 成功 |
| 一時 Python による文書・期待値の照合 | 成功。現行の help は実装・二つのテスト・golden・design.md の5件で一致。golden の変更箇所、assert と入力の保持、英日3組のコードブロックの一致を確認。回答文は移行段落以外の本文と全コードブロックが変更前と一致し、相対リンクは残っていない |

統合テストのコマンドは次のとおりである。

```sh
cargo test -p benitoite --test golden --test package_command --test skill_docs --test reference_examples --test spec_examples --test cli_process --test test_command --test skill_examples
```

## 計画との差と申し送り

依頼の範囲内の修正であり、計画との食い違いや新たな R 判断はなかった。`decisions.md`、`docs/todo/`、`formal/` は変更していない。コミットは作成していない。

- 旧い help が残る `m2a/inputs.md` と `m2b/cli-observations.json`・`m3b/cli-observations.json` は、Z7 より前の移行計画と採取した実出力の記録として保持した。`reviews/G7.md` の旧文言も原文のままである。現在の案内・期待値の取り残しではない。
- オーケストレータ: 取り込みとコミット、`scripts/check.sh`（dry-run を含め今回未実施）・gc-stress の構成・全ターゲットのテスト・公開前の `--full` は指定の分担どおり実施する。clippy の `--all-targets` だけは今回の指定検査に含めた。`formal/` に触れていないため `lake build` は実施していない。
- F2: 最終の実出力を照合する際は、この help の変更も反映する。回答文の JSON 例、採取元の版・ビルド情報は今回変更していない。
