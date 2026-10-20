# H2 の結果

基準は開始時の `git merge-base HEAD san_benito` で得た `92c5b3fe185a149ccc1bde2b2304ee181cf6e6c3` である。コミットと docs/todo/ の変更は行わない。

## 実装と作成時の関門

ExternalSession が遅延 Engine・通常/補助 Component 表・中断の見張りを所有する。SHA-256 の一致後にも bytes を照合し、補助は既存 ComponentKey と生成 bytes を照合する。通常テスト・複数入口・doc の通常テスト/例/main へ同じ所有者を渡す。Store・Instance・外部ハンドル・解放待ち・言語ヒープ・出力・実行番号は各実行に分ける。既存 new は単独 session を作り、新しい crate 内の new_in を共用する。公開 RunEnv/VmConfig・check/check_externals/CheckResult は変えない。

テストの持ち主は CLI と外部実行の入口である。CLI で 1/10/50 個の通常テスト・複数入口・doc の通常テスト/例/main を通し、同じキーの実行用コンパイル回数・stateful の最初の live=1・同じ実行の bump=12・補助の純粋な初期値41・実行ごとの統計の分離を独立の期待値で確かめる。同じ bytes の別パスは共有し、同じ表示パス/配列番号の異なる bytes と別 Engine は混同しない。失敗したコンパイルは保存しない。共有 session の別実行からの外部ハンドルを拒否し、燃料の再設定とメモリ上限の失敗後の新しい Store を確認する。SIGINT/SIGTERM は run/test で終了130を保ち、先に終了したテストから準備を引き継いだ後も中断し、後のテストのファイルを作らない。

既存のキャッシュ件数の assert は所有先だけを session へ移し、同じ件数と空の条件を保つ。assert の削除・期待値の緩和・新しい ignore はない。追加入力に深い再帰・長いリスト・大きな共有合成はない。反復はテスト数50以下・制限の呼び出し30回である。既存の2048要素等は転送予算1024/2048の境界そのものを確認するための値であり変更しない。Lean・GC本体・根と障壁・構文・標準宣言・診断表に変更はなく、生成Skillの変更は不要である。

## 途中の検査

- `cargo check -p benitoite --tests`: 成功。最初の実装時に補助の準備型と生成集合の型の取り違え、および機械的な欄追加が戻り型の直後にも入った誤りを検出し、引数を既存のkey/bytesへ分け、余分な挿入を修正した。
- `cargo test -p benitoite --lib external::runtime::adapter_tests`: 既存7件成功。
- `cargo test -p benitoite --lib external::runtime::session_tests`: 新規2件成功。
- `cargo test -p benitoite --test test_command external_session_shares_preparation_and_isolates_each_test -- --nocapture`: 成功。新しい入力の型名を既存のUnsignedInteger32へ合わせ、E1010は対応外のDecimal宣言で確かめた。既存契約で --check は --wasm-stats と併用できないため、その確認は通常の --check と未使用の宣言の統計へ分けた。既存テストの期待は変えていない。
- 共有を渡さない変更を一時的に本番の通常test入口へ適用し、同じ新規CLIテストが意図どおり失敗した。最初の1件/入口で実行用normal=4/adapter=2となり、期待normal=2/adapter=1との差を検出した。変更は直ちに戻し、修正後に同じテストが成功した。テスト自身を弱めていない。
- `cargo test -p benitoite --test external_signals interrupts_during_wasm_have_exit_status_130 -- --nocapture`: 成功。run/test と SIGINT/SIGTERM の4組を確認した。

途中のコマンドの外側時間は未計測である。CLI の静的宣言照合は通常の二入口で4回、docを含む起動で8回を計数し、実行用normal=2/adapter=1と別に照合した。宣言が未使用なら実行用は両方0である。E1010の入口を先行の成功した入口の後に置いても、静的に拒否した。

## 完了検査

同じ基準と名指しのdry-runは終了0で選択を確認した。最初の全ターゲットclippyは、新規CLIテストの不要なformat!一件で終了101となった。補間を含むソースをそのまま文字列リテラルへ置き、失敗したclippyだけを再実行して終了0を確認した。workはその後に一度だけ実行し、各補完も一度だけ実行した。コマンド・終了状態・外側時間は [commands.jsonl](commands.jsonl)、件数と検査単位の要約は [validation-summary.txt](validation-summary.txt) に保存した。

| 検査 | 結果 | 外側の時間 |
|---|---|---|
| H2のwork | 終了0。lib 1,246件成功・既存ignore21件。指定4統合ターゲットは既定・heap-verify・heap-verify+gc-stressで各64件成功。通常文書17件成功・既存ignore1件、compile_fail17件成功。fmt・規約・生成Skill・仕様集計も成功 | 155.487秒 |
| 全ターゲットclippy（修正後） | 終了0 | 0.302秒 |
| external::のheap-verify | 終了0。133件成功・ignoreなし | 23.585秒 |
| external::のheap-verify+gc-stress | 終了0。133件成功・ignoreなし | 23.462秒 |

時間はPythonのmonotonicでコマンド全体を外側から測った値であり、ビルドを含む。作業末の追加変更はclippyで検出した不要なformat!の修正と文書・結果の整備だけであり、成功したwork/補完の後にRustの変更はない。生成Skillとbundleの差分はない。formal/は変更せず、lake buildと全体のcheck-formal/check-heapはこの作業では実行しない。新しいignoreとテストの弱化はない。

Rustの行数の純増は、本番部分214行、テスト部分302行（runtime.rs内のテストと新しいsession_tests.rsを含む）である。既存テストを削除していない。主要な追加は共有所有者、静的/実行用の計数、同じCLI起動と外部実行の境界での契約の検査である。

## ずれと申し送り

R186に、静的照合の計数用のcrate内の入口とlintの置換を記録した。計画の機能範囲と保証に変更はない。次の作業は同じsessionの共有と実行状態の隔離を保つこと。02-09にも旧所有先の記述があったため、02-11/03-10/06-04/07-04と同じ状態へ更新した。形式化の定義・定理・仮定は変更していない。
