# C2b 報告の panic 境界と書き込み失敗

## 目的と変更ファイル

認識済みの check の報告では、捕捉した不具合を単一の internalError に収める。未知の契約を成功した空集合へ置き換えず、出力失敗は終了状態1で終える。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/check_report.rs` | 確定した入口と持ち出し済みのソースの保持、入口選択から直列化までの panic 境界、内部エラーの単一報告、書き込みを一度だけ試みる共通処理 |
| `crates/benitoite/tests/cli_process.rs` | 既存の受け入れ表に警告の許可・昇格の対照を追加。既存の開発用 panic、初期化失敗、閉じたパイプの検査を追加 |
| `docs/design/06-tooling/06-01-cli.md` | 捕捉の範囲、ソースを保持できない場合の null と空配列、出力失敗、保証外の失敗 |
| `docs/design/02-impl/02-10-diagnostics.md` | 報告内の internalError と checkError、二重出力をしない契約 |
| `design.md`・`decisions.md`・`harness-response.md` | R14 と、失敗時に保持できる情報・完成した報告の保証範囲の補足 |
| 本書 | 共通の関門 K、検査と申し送り |

## 型・契約と所有

公開 API、prepare_script、通常の run/check のシグネチャと実行処理は変更していない。非公開の ReportContext が選択済みの EntrySpec と、AST を除いた CheckResult を保持する。深い AST の走査・破棄は既存の段のスレッドで行う。検査・コンパイルの再実行、ソースの再読は行わない。

prepare_script が返す不具合の診断を、標準エラー出力へ送る代わりに報告へ包む。検査段の panic の段・スレッド・内容を保つ。入口選択・報告の組立・直列化の panic も捕捉し、主スレッドの内部エラーにする。再組立では途中の診断を再利用せず、不具合の診断だけを使う。完成した JSON と末尾の LF を用意してから書き込みを一度だけ試み、書き込み・flush の失敗で別の報告を送らない。

入口を選べていれば targetsComplete=true とし、Target を残す。検査段の巻き戻しで SourceTable を持ち出せなかった場合、sources と該当の sourceIds は空配列、入口の sourceId は null となる。main と aggregateEffects は null、complete=false、終了状態3であり、純粋な成功の空集合とは区別する。入口選択前に捕捉した場合は targetsComplete=false、targets・sourceSets は空配列である。

標準ソースの誤りは、従来の prelude_error の分類を報告でも使い、internalError・3とする。既存の `cli::tests::prelude_source_errors_are_internal_and_user_errors_are_check_failures` をライブラリの検査に含め、報告側の呼び出しと status の選択もコードで照合した。埋め込みソースを書き換えるテスト用の本番入口は加えていない。利用者の警告の昇格は checkError・2、使い方の誤りは usageError・2とする。出力失敗は元の分類によらず1である。

## test-audit の作成時の関門

- 観測する契約は、認識後の panic が単一の internalError・3になること、主スレッドの初期化失敗に完成した報告を約束しないこと、警告の許可と昇格の分類、すべての報告の出力失敗が1で終わり stderr へ再送しないことである。
- 現実的な退行は、検査段の不具合だけが stderr へ抜けること、不明の main・aggregateEffects を成功した空集合にすること、panic hook の文や二つ目の JSON が混ざること、出力失敗でも0・2・3を返すことである。
- 通常の check の panic は stderr が正しいため、報告の取りこぼしを捕まえられない。既存の run のパイプ失敗も別の実行時の経路である。報告の panic は CLI 境界の一つのテストで、diagnostics の既定と json の双方を検査し、全必須欄と診断の種類・注記を比較する。警告は既存の報告の表へ二行を加え、通常の JSON 診断との一致、重大度、完全性、null を検査する。
- 実プロセス、実ファイル、既存の BENITOITE_DEV_PANIC だけを使う。出力失敗は、子の起動前に読み口を閉じた実際のパイプで作り、プロセスの実行順の偶然に依存しない。成功、読み取り失敗、解析中の誤り、パスなし、main.bnt なし、内部エラーの六ケースを同じ表で検査する。テスト専用の API・フラグ・大域の状態は追加していない。

変更前の本番コードで新しい panic のテストを実行し、stdout が空で stderr に内部エラーが出るために失敗することを確認した。変更後は同じテストが通る。新規の初期化失敗の対照に書いた文言は、実際の既存出力に合わせて修正した。既存の assert は削除せず、期待値を緩めず、ignore を追加せず、テストを削除していない。本番コードは134行追加・53行削除（差し引き81行増）、テストは137行追加・5行削除（差し引き132行増。削除は既存のコマンド組立を警告昇格の指定にも使うために組み直したもの）である。

## 検査

実行には rtk を使った。scripts/check.sh は dry-run も含めて実行していない。依頼の指定を共通の関門 K の6より優先し、分類のコードを読み、変更した Rust は crates/* により rust、設計書と作業記録は追加の検査なしとなることを確認した。check.sh と gc-stress の最終検査はオーケストレータが行う。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定、79.65秒） |
| `cargo test -p benitoite --test cli_process --test interrupt_process` | 23 passed、0 failed（2 suites、40.65秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、lint の診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |
| 変更した文書内のローカルリンク | 本書を含む149件の参照先が存在 |

通常構成だけを実行し、gc-stress は実行していない。変更前の新規テストの失敗は退行の検出の確認であり、変更後の検査の失敗ではない。

## 計画との差と申し送り

既存の prepare_script は、検査段の panic から SourceTable を返さない。型の変更や再読へ広げず、報告側に持ち出し済みの情報だけを使う最小の判断を R14 に記録した。06-01 の従来の「報告を組み立てる前の panic」は stderr へ送るという記述も、報告モード確定後の境界と保証外の外側を区別する内容へ改めた。形式の版と必須欄は変えていない。

構文・型の規則・脱糖・formal/ は変更せず、R4 の判定を保つ。診断コードの表、標準ソース、Skill の生成元も変更していないため、gen_skill は不要である。docs/todo には触れず、コミットしていない。

C3 の広い受け入れ表と formats.checkReport=[1] の宣言、T2b の test 側の接続は残る。G2 のレビューと段末検査、scripts/check.sh、gc-stress はオーケストレータへ渡す。捕捉の範囲外の panic、失敗報告自身の組立の失敗、abort・強制終了・出力切断には、完成した報告を保証しない。
