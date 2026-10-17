# Z5 G5 のレビュー指摘の修正

## 変更

G5 の中程度の指摘1と軽微な指摘1〜6を、オーケストレータの指定した処置に沿って扱った。[レビューの全文](../reviews/G5.md)は依頼に添付された本文をそのまま保存した。

| ファイル | 変更 |
|---|---|
| `harness-response.md` | BH-026・BH-024・BH-027 を0.0.7の提供予定と formats による能力判定に揃え、内部の作業 ID と実装・提供済みの表現を除いた。全体を見直し、BH-022 の R14 参照も除いた。JSON のオブジェクトの欄の順序は契約に含めず、解析して比較することを明記した |
| `docs/design/06-tooling/06-06-agent-skills.md`・`docs/design/README.md` | 章の範囲と目次に同梱文書の取得を加え、導入・除去のパスを出す主語を install/uninstall に限定した。06-06 の取得の JSON にも欄の順序の規定を加えた |
| `docs/design/06-tooling/06-01-cli.md` | Skill の JSON の欄の順序は契約に含めず、解析して欄と値を読むことを明記した。文書の配列の順序は変えていない |
| `docs/design/02-impl/02-11-embedding.md` | 中断の読み口の根拠を AGENTS.md から02-09「中断の要求」へ変更した |
| `crates/benitoite/tests/cli_process.rs` | 既存の usage の表に `show --agent SKILL.md` の一行を追加した。分離値を消費したときの文言・終了状態2・空の標準出力を text/json の両方で確認する |
| `decisions.md` | 軽微な指摘3について、使い方の誤りの既存の表示を今回は許容し、実装は変更しない判断を R27 に推す案として記録した |
| `e1/results.md` | E1 で追加した拒否と継承・通常変数の対照のテストを個別に計測して追記した |

## テストの作成時の関門

追加した一行は、取得で `--agent` が論理名を分離値として消費した場合にも、使い方の誤りとして終了状態2・空の標準出力と既存の文言を返す契約を守る。現実的な退行は、取得でこの指定を受理すること、論理名の不足や未知のオプションへ文言が変わることである。既存の `show SKILL.md --agent=codex` は、有効なエージェント名を伴う指定の拒否であり、不正な分離値を先に検査する場合を確かめない。

主な境界は既存の CLI・標準出力・標準エラー出力・終了状態と一時ディレクトリである。既存の表と共通の検証を使い、本番の差し込み口やテスト関数は増やしていない。この一行は既存の挙動を記録する対照であり、振る舞いの修正に対する退行テストではない。修正前の失敗を確認したとは扱わない。

既存の assert の削除、期待値の緩和、ignore の追加、テストの削除はない。本番の Rust コードは変更せず、テストは4行追加・0行削除である。

## 検査

既定構成（gc-mark-sweep）で実行し、出力の整理に rtk を使った。以下の経過時間はビルドと rtk を含むコマンド全体の時間であり、テスト実行器が表示する時間とは区別する。

最初の統合テストでは、追加行の期待文言に既存のエージェント候補の一覧を含め忘れ、cli_process の1件が失敗した。実際の文言全文を期待値に入れて修正した。本番の表示、既存の期待値、assert は変更していない。


| コマンド | 結果 | 経過時間 |
|---|---|---|
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行78.49秒 | 104.854秒 |
| `cargo test -p benitoite --test cli_process --test l10_console_clock_process --test l13_external_commands --test runtime_builtins --test skill_docs --test skill_examples --test test_command --test interrupt_process` | 修正後は8 suites、99 passed、0 failed。テスト実行計34.29秒 | 39.077秒 |
| `cargo clippy --all-targets` | 終了状態0、指摘なし | 12.570秒 |
| `cargo fmt --check` | 終了状態0 | 2.147秒 |
| `git diff --check` | 終了状態0 | — |
| JSON の例と相対リンク | harness-response の7例の構文と、変更前から意味が変わらないことを確認。設計の目次・3章・回答文・判断記録の相対リンク154件と、作業記録の2件の参照先を確認。02-09 の見出し・読み口と R27 のリンク先も確認 | — |

E1 の個別測定は次のとおりで、各1 passed・終了状態0だった。`cargo test -p benitoite --test l13_external_commands <名前> -- --exact` を使い、テスト実行時間は Rust のテスト実行器の表示である。

| テスト | テスト実行時間 | コマンド全体 |
|---|---|---|
| `cli_rejects_explicit_loader_environment_before_starting_child` | 1.45秒 | 4.665秒 |
| `cli_preserves_inherited_loader_environment_and_allows_other_names` | 1.28秒 | 1.377秒 |

両方10秒未満であり、長いテストへの変更は要らない。今回の環境での一回の観測であり、所要時間の上限は保証しない。既存の長いテストの ignore を外す実行と check-heap.sh は行っていない。

## 計画との差と申し送り

実装上の計画からのずれはない。軽微な指摘3はオーケストレータの指定どおり、[R27](../decisions.md#r27-skill-の使い方の誤りに含まれる制御文字を今回どう扱うか)の記録だけとした。D1 では使い方の誤りのすべてをエスケープすると説明しないことを確認する。中程度の指摘1と軽微な指摘5の回答文の修正は今回済ませたため、D3 へ先送りしていない。D3 では残る六機能の照合と、後続変更で内部の作業 ID や公開済みの表現が再び入らないことを確認する。

scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。S2 の段末の検査と gc-stress の記録はオーケストレータへ引き継ぎ、G5 の確認事項をこの作業の検査で閉じたとは扱わない。0.0.7 への版の更新、E0908 の変更表と CHANGELOG・LD_RUN_PATH の移行案内を揃えるまでは公開しない前提も保つ。

formal/・構文・型の規則・脱糖は変更していないため、lake build は実行していない。Skill の生成元も変えておらず、再生成は不要である。docs/todo/ は変更せず、コミットは作成していない。san_benito への取り込みはオーケストレータへ引き継ぐ。
