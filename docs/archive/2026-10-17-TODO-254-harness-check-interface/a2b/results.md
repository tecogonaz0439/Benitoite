# A2b test の上限比較・全保持・全体拒否

## 目的と変更

`test --allow-effects` は、全入口の検査・テスト関数ごとの契約の照合・コンパイル・実行準備が成功するまで、一つもテストを開始しない。検査失敗・不足・コンパイル制限では後の入口も準備し、全体を拒否する。不足のある関数には入口順・宣言順に E0512 を出す。不具合と中断は準備を止める。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/args.rs` | PathArgs.allow_effects を追加し、test でも上限の両構文を共通の解析器で受け付ける。分離値を一引数として消費し、test --check との併用を拒否する |
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | ExecuteLimited と全入口の準備・保持・開始条件を接続する。診断の確認と実行を分け、全成功時には検証済みの同じ成果物を順に消費する |
| `crates/benitoite/src/cli/tools/args/tests.rs`・`formatter/tests.rs` | 既存の PathArgs の構築に allow_effects: None を追加する |
| `crates/benitoite/tests/test_command.rs` | 後の拒否による全体の非実行、診断の順と内容、全成功時の順と成果物の再利用、入力の誤り、中断時の非実行数を確認する |
| `docs/design/02-impl/02-01-pipeline.md`・`02-11-embedding.md` | 契約の照合と脱糖の順、上限付きの所有と全保持、上限なしの逐次実行を明記する |
| `docs/design/06-tooling/06-01-cli.md`・`06-04-test-runner.md` | test の上限の受理、関数ごとの E0512、全体の開始条件と拒否時の集計を反映する |
| `decisions.md`・`harness-response.md` | R24 を記録し、提供済み範囲を A2b に合わせる |
| 本書 | 共通の関門 K、検査と申し送り |

公開の型の変更は、計画どおり PathArgs.allow_effects の追加だけである。ExecuteLimited は許す集合を借用する非公開の準備モードとし、欄・variant は本番の処理と同時に接続した。tools.rs は既に解析済みの PathArgs を実行器へ渡すため、変更を要しなかった。

上限付きでは、探索した全入口数を u32 へ検査付きで変換してから準備する。実行開始前の全体拒否では、テストの結果行を作らず、成功数・失敗数0、filesNotRun=全入口数の集計を出す。通常の拒否は2、不具合は3、中断は interrupted=true・130とする。探索失敗では集計を書かない。文章の集計の共通文言は A3 の範囲として維持した。

成功した成果物は Vec<(EntrySpec, Prepared)> が所有する。Prepared は検査済み AST・型表を保持せず、コンパイル済みプログラム・ソース・テストと原型の組・AssertTable・RunInput を持つ。AST とコア IR は入口ごとの段のスタックで捨てる。実行はその Vec を順に消費し、探索・ソースの読み込み・検査・コンパイル・実行準備を繰り返さない。RunEnv と RuntimeParts は従来どおりテストごとに作る。上限なしは全保持せず、従来の逐次実行を保つ。

## テストの作成時の関門

守る観測可能な契約は、後の入口の拒否によって先頭のテストも開始しないこと、検査失敗後も後の診断を集めること、全成功時は比較済みの成果物を順に実行すること、test の引数解析でも上限の両構文と使い方の誤りを区別することである。現実的な退行は、一入口ずつ照合と実行を交互に行うこと、最初の拒否で通常の検査を打ち切ること、後の入口を実行時に再読すること、分離値をパスや report の指定にすることである。

主となる境界は CLI の実行・診断・集計・ファイル状態とした。上限なしの既存テストでは、上限付きだけの全体拒否と全保持の退行を捕まえない。拒否の表には、先頭の書き込みと、後の不足・E0401・既存の L0112 入力を組み合わせ、さらに後の不足の診断も比較する。出力は集計一行だけ、filesNotRun=4、目印ファイルなしを確認する。E0512 の関数名、位置、正規名のソート、不足と許可も確認する。

全成功の対照では、先頭のテストが後の入口を不正なソースへ書き換えても、準備済みの元のテストが成功することを確認する。通常実行の出力との対応と、空集合の両構文も同じテストで確認する。中断の既存テストには、上限付きでは明示パスの重複も含む全入口数を報告する対照を追加した。テスト専用の本番 API・フラグ・差し込み口、時間待ちによる競合試験は追加していない。

既存の assert・負の入力・期待値は維持し、テストの削除・期待値の緩和・ignore の追加はない。Rust の本番コードは193行追加・39行削除（差し引き154行増）、テストは221行追加・削除なしである。

## 検査

既定の構成（gc-mark-sweep）で実行した。出力の整理には rtk を使った。依頼に従い scripts/check.sh は dry-run も含め実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、既存の21 ignored（80.81秒） |
| `cargo test -p benitoite --test test_command --test cli_process` | 53 passed、0 failed（2 suites、9.62秒） |
| `cargo test -p benitoite --test test_command --test cli_process --test interrupt_process` | 62 passed、0 failed（3 suites、20.26秒） |
| `cargo test -p benitoite --lib --test test_command --test cli_process --test interrupt_process` | 最終修正後に1257 passed、0 failed、既存の21 ignored（4 suites、97.35秒）。lib 1195件、test_command 32件、cli_process 21件、interrupt_process 9件 |
| `cargo clippy --workspace --all-targets` | 修正後は終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した設計書の相対リンクの確認 | 4文書の Markdown の相対リンク178件で参照先の存在を確認 |
| `git diff --check` | 終了状態0 |

最初の新規テストでは、E0512 を期待する入力に Console と Process の import が欠け、E0332 で失敗した。必要な import を加え、宣言位置の期待値も合わせて修正し、意図した E0512 で拒否することを確認した。最初の clippy は追加した PrepareMode のワイルドカード分岐を拒否したため、Inspect と Execute を明示し、指摘なしとなった。既存のテストの失敗はない。

## 計画との差と申し送り

実装の範囲・所有・開始条件は計画どおりである。共通の関門 K に従い、変更先の列挙にない 06-01 と harness-response.md も実装済みの範囲へ更新した。この判断は [R24](../decisions.md#r24-test-の上限を受理した段階の-cli-文書をどう揃えるか) に記録した。tools.rs は既存の受け渡しをそのまま使う。

A3 は集計と終了状態の広い対照、共通の FILES_NOT_RUN の文言の変更を担当する。A2b では全体拒否の基本の集計・非0終了は既に接続した。A4 は検査後のファイル変更の最終照合、formats.effectLimit の宣言と段末の検査を担当する。形式の宣言を先置きしていない。

scripts/check.sh、gc-stress の構成、段末の検査、G4 のレビューと san_benito への取り込みはオーケストレータへ引き継ぐ。本書は A2b 個別作業の記録であり、段3全体を完了扱いにしない。formal/・構文・型の規則・脱糖の規則は変更していないため、lake build は不要である。診断表・標準ライブラリのソース・Skill の生成元を変更していないため、gen_skill は実行していない。docs/todo/ は変更せず、コミットは作成していない。
