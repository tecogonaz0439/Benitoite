# Z4 G4 のレビュー指摘の修正

## 変更

G4 の軽微な指摘1〜6を修正した。[レビューの全文](../reviews/G4.md)は依頼に添付された本文をそのまま保存した。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/mod.rs`・`effect_limit.rs` | help とモジュールの説明を run と test の両方に揃え、help の説明の開始桁を揃えた。run の包含の照合は main の契約だけを抽出する |
| `crates/benitoite/src/cli/inspection.rs` | main の宣言と型表を照合する main_contract を分けた。検査報告は従来どおり shell の参照も調べる |
| `crates/benitoite/src/cli/tools/args.rs`・`args/tests.rs` | fmt で report と allow-effects をコマンドに適さない指定として拒否する。既存の引数の表に対照を一行ずつ足した |
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | reject_all で中断の印を読み直さず、渡された終了状態を使う。全準備後の確認は最初のファイルの実行前として残した |
| `crates/benitoite/src/diag/codes.rs`・`crates/benitoite/skill/references/diagnostics.md` | E0512 の説明を main と test の両方に揃え、gen_skill で生成し直した |
| `crates/benitoite/tests/cli_process.rs`・`test_command.rs` | 大文字小文字を誤った名前の拒否を既存の usage の表に一行ずつ追加した。run の書式比較は成功と拒否の二例に絞った |
| `docs/design/02-impl/02-01-pipeline.md`・`02-10-diagnostics.md`・`02-11-embedding.md`、`docs/design/06-tooling/06-01-cli.md` | 静的な報告・照合と実行時の権限制御を区別し、E0512 の対象と中断の確認点を実装に揃えた。02-01 の食い違いもこの作業で修正した |
| `decisions.md` | R26 に全準備後の中断の確認を残す理由と、reject_all の読み直しを除く判断を記録した |

## テストの作成時の関門

fmt の既存の引数解析テストは、指定を未知のオプションと取り違えず、コマンドに適さない指定として拒否する契約を守る。二つの名前が拒否の一覧から抜ける退行を、返す文の完全一致で検出する。既存の表は deny-warnings だけを比較していたため、この二つの欠落を捕まえない。公開の parse_path_args を使い、本番の差し込み口は加えていない。修正前の実行では追加した report の行で `unknown option` と期待する文が異なり失敗した。

run と test の usage の表には `console.write` を足した。正規名の大文字小文字を補正せず拒否する契約を、終了状態2、空の標準出力、既存の使い方の文の完全一致で守る。既存の未知名・別名の入力は大文字小文字の補正を捕まえないため、各 CLI の受理境界に一行ずつ足した。

run の包含の表は七例を保ち、書式の比較だけを成功する console と拒否する empty の二例に絞った。四書式すべての成功・拒否の接続を残し、包含の各例、診断全体の比較、非実行のファイルの比較を維持した。表の実行回数は28回から13回となり、プロセス起動を15回減らした。既存の assert の削除、期待値の緩和、ignore の追加はない。

テスト関数は削除していない。重複は、包含の例と引数の書式をすべて掛け合わせたことで生じていた。main の契約の抽出を分けたことで、run の包含の照合から不要な shell の参照判定と、そのための失敗経路を除いた。Rust の本番コードは23行追加・21行削除（差し引き2行増）、テストは26行追加・3行削除（差し引き23行増）である。

上限付きで対象確定後に不具合となる `reject_all(count, 3)` のテストは追加していない。prepare_entry の panic 捕捉・段のスレッド作成、検査済みの束縛や型・原型の欠落、AssertTable の構築・脱糖・コンパイル、run_input の失敗に至る経路を確認した。通常の不正なソースは検査失敗やコンパイル制限として終了状態2になる。run_input が行う canonicalize の失敗は、検査成功後のファイル削除などを要する。決定的な入力を見つけられず、内部の表の破壊、テスト専用の本番フック、実行順に依存するファイル削除の競合試験は作成時の関門に合わないため採らなかった。この経路の終了状態3と filesNotRun=N は今回、実行による確認を加えていない。実行開始後の不具合を確かめる既存のテストは残した。

## 検査

既定の構成で実行した。出力の整理には rtk を使った。以下の時間はコマンド全体の経過時間であり、ビルドと rtk の時間を含む。テスト実行器が報告する時間も結果の欄に併記する。

| コマンド | 結果 | 経過時間 |
|---|---|---|
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、既存の21 ignored。テスト実行は81.63秒 | 93.775秒 |
| `cargo test -p benitoite --test cli_process --test test_command --test fmt_command --test interrupt_process --test skill_docs` | 5 suites、89 passed、0 failed。テスト実行は計20.72秒 | 30.334秒 |
| `cargo clippy --all-targets` | 終了状態0、指摘なし | 13.691秒 |
| `cargo fmt --check` | 終了状態0 | 3.609秒 |
| `cargo run -p benitoite --example gen_skill` | 終了状態0。生成物の差分は E0512 の説明だけ | — |
| `git diff --check` | 終了状態0 | — |
| 変更した設計書4章と decisions.md の相対リンク | 266件の参照先ファイルの存在を確認 | — |

変更したテストと関連する全体拒否・中断のテストは、一件ずつ実行し、所要時間を確認した。`cargo test -p benitoite --lib <名前> -- --exact` または `cargo test -p benitoite --test <スイート> <名前> -- --exact` を使用し、いずれも1 passed・終了状態0だった。テスト実行時間は Rust のテスト実行器の表示（小数点以下2桁）である。測定した全件が10秒未満であり、長いテストへの変更は要らない。

| スイート | テスト | テスト実行時間 | コマンド全体 |
|---|---|---|---|
| lib | `cli::tools::args::tests::path_arguments_accept_check_and_reject_usage_errors` | 0.00秒 | 4.981秒 |
| cli_process | `run_effect_limits_check_declared_contracts_before_execution` | 3.19秒 | 3.298秒 |
| cli_process | `cli_process_contracts` | 2.19秒 | 2.347秒 |
| test_command | `limited_test_options_reject_invalid_or_check_only_invocations` | 0.00秒 | 0.166秒 |
| test_command | `limited_tests_reject_every_entry_before_any_execution` | 3.32秒 | 3.515秒 |
| test_command | `an_interrupt_request_ends_with_the_interrupted_summary` | 0.15秒 | 0.290秒 |

lib の個別実行のコマンド全体の時間は再ビルドを含む。変更したテストの最長は3.19秒、関連する測定対象も含めた最長は3.32秒だった。所要時間は今回の環境での一回の観測であり、上限を保証する値ではない。

## 計画との差と申し送り

全準備後の中断の確認は、最初のファイルの実行を始める前に当たると判断して残した。[R26](../decisions.md#r26-全入口の準備後の確認をどの境界とするか)に推す案として記録し、02-11 にも反映した。AGENTS.md の大域の状態の例外と、R8 の非実行の test の確認点は広げていない。公開の引数・診断・JSON の形式・型の規則・脱糖の規則は変更していない。

scripts/check.sh は dry-run も含め実行せず、gc-stress の構成も実行していない。これらの段末の検査と san_benito への取り込みはオーケストレータへ引き継ぐ。G4 の確認事項はこの作業では閉じない。formal/ は変更していないため、lake build は実行していない。docs/todo/ は変更せず、コミットは作成していない。
