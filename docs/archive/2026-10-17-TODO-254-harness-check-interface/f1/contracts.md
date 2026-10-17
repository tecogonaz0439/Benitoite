# F1 契約・実装・検査の対応表

## 照合の基準

HEAD `c55042c952aebaeb713e3279e68ce4cc6b78f14f`（`mod254/F1`）を、[P1 の契約表](../p1/contracts.md)、[P2 の型表](../p2/interfaces.md)・[受け入れ条件](../p2/acceptance.md)、[design.md](../design.md)、[decisions.md](../decisions.md) の Q1〜Q14・R1〜R30 と照合した。P1 からの最終差分は `git diff dae448c00cbb47307b2699438c9045ec6e691565 HEAD` で確認した。本表の Rust のパスは `crates/benitoite/` からの相対パスである。

本表は既存実装の照合であり、契約の追加・変更ではない。検査の実施結果と、オーケストレータへ渡す検査は [results.md](results.md) に記す。

## 六機能と既存出力

| P1 の項目・判断 | 最終実装と観察する契約 | 主な検査の境界 |
|---|---|---|
| main の報告（BH-022、Q1〜Q3、R13〜R16） | `src/cli/check_report.rs`・`inspection.rs` と `mod.rs::prepare_script`。検査は一度、利用者コードは実行せず、所有する契約・診断・ソースから単一 JSON+LF を返す。成功した純粋関数は空集合、検査失敗の main と全体の集合は null | `cli_process` の `main_check_reports_*`、`check_usage_reports_respect_option_scope_and_argument_order`、panic・出力失敗の表 |
| test の非実行（BH-023、Q3/Q4、R17〜R20） | `src/cli/tools/test_runner/check_report.rs`。通常実行と `select_test_entries`・`collect_tests` を共有。指定順・重複・根・パッケージ境界・宣言順・import 先の除外を保持。成功した対象を残し、全体が不完全なら aggregateEffects=null | `test_command` の `check_report_and_execution_select_the_same_entries_and_functions`、`check_report_preserves_contracts_descriptions_locations_and_source_identity`、部分失敗・探索・空・中断の表 |
| 非実行の開始条件（Q4、R8/R26） | Inspect は検査・情報抽出で終え、AssertTable・脱糖・コード生成・VM を作らない。report なしでは stdout 空、report ありでも test/testSummary 行なし。中断は既存のファイル開始前の読み口で確認 | `test_command::check_does_not_run_user_code_or_write_result_lines`、`check_observes_interrupts_only_before_each_file`、`check_report_keeps_completed_and_unstarted_targets_on_interrupt` |
| 許す集合（BH-027、Q5、R16/R21/R23/R24） | `src/cli/effect_limit.rs`。正規名13個、両構文、一回、空集合、順不同と余分な許可を受理。IO.All・別名・未知・重複・空要素・空白は拒否。run のスクリプト以後は引数 | `cli_process::run_effect_limits_check_declared_contracts_before_execution`、`test_command::limited_test_options_reject_invalid_or_check_only_invocations`、args の単体の表 |
| run の同じ成果物（Q5/Q14、R25） | 同じ CheckedProgram の宣言上限を照合してからコンパイル。不足は関数の位置と E0512・終了状態2。report 後に main の契約が広がれば拒否。import 先だけの契約違反は先行する E0501 を保持 | `cli_process::run_effect_limits_recheck_changed_sources`、`main_control_flow_reports_match_effect_limits` |
| test の全体開始（Q6、R1/R9/R26） | 全入口の検査・照合・コンパイル・原型・RunInput の準備後に、保持した Prepared を順に消費。後ろの拒否があれば先頭も非実行。再探索・再検査・再コンパイルなし | `test_command::limited_tests_reject_every_entry_before_any_execution`、`limited_tests_consume_the_prepared_artifacts_in_order`、`limited_tests_recheck_reported_contracts_after_changes` |
| Assert.Check（Q2/Q5） | `inspection::function_contract` は Scheme.effects の全件を使う。main の集合、各テストの集合、和、effect_limit の包含で Assert.Check を除かない。IO.All の10個と区別 | `cli_process` の main 契約と上限の表、`test_command` の契約・空上限の拒否・Assert.Check を許した成功の対照 |
| shell の参照（Q2、R15） | IO.Process の未読と索引欠落を区別。refs の束縛と expr_types を照合し、ハンドラの操作名だけを除外。呼ばれない関数・依存内の式の参照も含む | `cli_process::main_check_reports_shell_without_execution`、`test_command::check_report_preserves_warning_promotion_and_program_shell_scope` |
| ソース（Q3） | `check_report::sources` は読み込んだ SourceTable の `source.text()` 全バイトを SHA-256 にする。BOM・CRLF・不正 UTF-8、設定・依存・prelude を含む。同じパスの別対象を sourceId で分ける。再読なし | `cli_process::main_check_reports_sources_without_execution`、`test_command` の契約・sourceSets・診断添字の表 |
| 版と由来（BH-025、Q7/Q8、R2/R10/R11） | `build.rs` と `src/cli/build_info.rs`。明示入力を検証し、未指定 dirty は null/notCollected。実行時に Git と環境を再採取しない。存在する HEAD/ref/packed-refs/logs/HEAD のみ監視し、検知の限界を05-01と回答に明記 | `cli_process::cli_process_contracts`。独立した実ビルドの5件は `build_info` の既存 long。今回 ignore を外して再実行しない |
| 明示環境の拒否（BH-026、Q10/Q11） | `src/builtins/funcs/process.rs::execute`。既存不正入力を先に検査し、DYLD_/LD_ を ASCII 大小無視で拒否。LD_RUN_PATH・空値・同値上書きも InvalidInput。値を出さず、絶対化・spawn より前に返す | `l13_external_commands::cli_rejects_explicit_loader_environment_before_starting_child`、lib の Process の既存表 |
| 環境継承（Q11） | `.envs(command.environment)` を保ち、env_clear/env_remove を加えていない。shell の明示環境は空のまま。親のダミー変数と通常の追加・上書きを継続 | `l13_external_commands::cli_preserves_inherited_loader_environment_and_allows_other_names`、`l10_console_clock_process`・`runtime_builtins` |
| Skill（BH-024、Q12、R6/R29） | FILES の全62文書を論理名で取得。list/show/install は同じ render_document を使用し、SKILL.md だけ版を置換。list/show は HOME・インストール先を読まない。不正・未知名は stdout 空と状態2 | `cli_process::skill_documents_match_the_embedded_bundle_and_installed_bytes`、使用法・書込み不可・出力失敗の表、`skill_docs`・`skill_examples` |
| 通常 run/check（P1 既存 CLI） | report のない分岐の stdout/stderr を保持。run はスクリプト出力、check は診断だけ。main の Result.Error は diagnostics=json でも既存の文章 | `cli_process::cli_process_contracts`、`golden` |
| die と診断形式1（Q9/Q14、R5） | 既存 JSON Lines に schemaVersion・開始行を加えない。kind:die/code:null、test.failure.die と通常の Process.exit の区別を維持。usageError の kind:check/code:null は新報告内だけ | `cli_process::die_source_reports_cause_message_and_location_once`・`die_reports_precede_real_release_and_flush_failures`、`test_command::die_source_fails_one_test_and_keeps_running`、`golden` |
| 通常 test と集計（P1 既存 CLI、R1/R9） | 上限なしは入口ごとの逐次準備・実行を維持。全体拒否で既知 N>0 なら test 行なし、0/0・filesNotRun=N。不明件数・探索失敗では集計なし。文章は `; {count} files not run`、JSON の欄・型は同じ | `test_command` の通常の順序・失敗・全体拒否の表、`prepared_sources_are_reused_and_the_next_file_is_prepared_after_execution` |
| fmt/package/install/uninstall（P1 既存 CLI） | fmt は report/allow を拒否。package の依存・契約・ハッシュ・操作出力を維持。install/uninstall の既存の出力・保護と公開 run_skill の home 引数を保持 | `fmt_command`、`package_command`、`cli_process`、lib の formatter/package/skill の表 |
| help/licenses/旧版表示（P1 既存 CLI） | 問い合わせは非実行。旧 --version は二行と既存の後続引数の扱いを保持。新 --version=json だけ余分な引数・未知値を拒否 | `cli_process::cli_process_contracts`。ライセンス一覧の段末検査はオーケストレータ担当 |

## 全 formats と終了状態

| formats のキー | 実装が返す版 | 契約・現行文書・検査 |
|---|---|---|
| version | [1] | `--version=json`。06-01「版と対応する形式の問い合わせ」、cli_process |
| diagnostics | [1] | 既存の診断 JSON Lines。02-10「JSON の形式」、cli_process/golden |
| testResults | [1] | 既存の test/testSummary。06-04、test_command |
| checkReport | [1] | main の非実行の単一報告。06-01、cli_process |
| testCheckReport | [1] | test の非実行の単一報告。06-01・06-04、test_command |
| effectLimit | [1] | 引数・包含・E0512。06-01、cli_process/test_command |
| loaderEnvironment | [1] | always、二接頭辞、asciiCaseInsensitive、unchanged、InvalidInput。03-07・06-01、l13_external_commands |
| skillList | [1] | 論理名順の一覧と置換後の長さ・hash。06-06、cli_process/skill_docs |
| skillDocument | [1] | 同じ置換後の本文と長さ・hash。06-06、cli_process/skill_docs |

九キーは `src/cli/mod.rs::execute` の VersionJson と、[回答](../harness-response.md)・英語リファレンス・Skill の inspection.md・日本語訳で一致する。未提供のキーと空の版配列はない。main/test 成功報告の抜粋は sources/sourceSets の省略を明記し、完全な出力の必須欄を減らしていない。design.md の仮ハッシュは形の説明、回答のハッシュは採取時の実値として区別する。

| 終了状態 | 対応する観察 |
|---|---|
| 0 | 成功した問い合わせ・検査・実行。報告は status:ok/complete:true と同時に確認 |
| 1 | スクリプト・テストの失敗、die、機械向け出力の書込み失敗。出力失敗は元の status より優先 |
| 2 | 検査・読取り・使い方・deny-warnings・制限・E0512。上限付き test は全体を非実行 |
| 3 | 捕捉した処理系の不具合。報告認識後の境界内なら不完全な単一報告 |
| 130 | 既存の読み口で捕捉した中断。通常 test の優先順位130 > 3 > 2 > 1 > 0を維持 |

`Process.exit` の0〜255、環境入力を Result.Error として処理した場合の成功、abort・強制終了・出力切断の限界は別に保持する。0/0 の件数だけを成功とは判定しない。

## 型・所有・形式化の最終対応

| P2 の型・入口 | 最終状態 |
|---|---|
| Options/PathArgs/Command | report/allow_effects は既定 None。VersionJson は実際の JSON 分岐へ接続。fmt の構築・拒否も対応 |
| parse_args/parse_path_args | 公開シグネチャを保持。内部の CliParseError/TestParseError が認識した報告と指定パスを所有。PathTool::Test の公開入口で wasm を受けて捨てない |
| parse_test_args/ReportKind::Test の旧計画 | R18/R22 が置換。不要となった内部 parse_test_args は残さず、CLI は parse_test_invocation を使用。main 用 ReportKind に未使用の Test を加えていない |
| collect_tests/TestFn | 戻り値は計画どおり Result<Vec<TestFn>,InternalError>。TestFn の欄は保持。binding で契約を照合し、説明省略 null と明示した空文字列を区別 |
| Prepared/Compiled | AST/型表/コア IR は段のスタックで破棄。Prepared.result.program=None。Inspect の所有する TestInspection、実行用の原型・RunInput・AssertTable が本番経路へ接続 |
| Summary | 欄・型と JSON は保持。既知の全入口数を u32::try_from で確認し、飽和させない |
| CheckedProgram/CheckResult/TypeckOutput/Scheme | 型・欄・型検査の受理規則を変更せず、CLI が既存の契約を読む |
| Process.Command/read_command/execute | 欄・シグネチャを保持し、既存 Result[_,IOError] の入力条件を変更 |
| SkillFile/files/install_dir/run_skill | 公開シグネチャを保持。CLI 用の内部入口だけ HOME を遅延取得 |
| R4・形式化 | P1 から pipeline.rs、syntax/、resolve/、desugar/、formal/ に差分なし。型関連の差分は表示名の共通化と版付きfixtureであり、型の規則・推論・脱糖は不変。07-04/01-12/formal/ の変更と lake build は不要 |

## 通常検査が読む入力

| 検査 | 入力の根・指定と作業記録の扱い |
|---|---|
| golden | `tests/golden.rs::GOLDEN_ROOTS = ["testdata"]`。改造ディレクトリを探索しない |
| spec_examples | `docs/design/01-spec/` と付録08-04、数の章を明示。docs 全体を再帰走査しない |
| reference_examples | `docs/reference/benitoite.md` 一件を明示 |
| skill_examples | 同梱 SKILL.md と手書き三文書を明示。inspection.md は契約資料で、実出力は CLI のテストと今回の照合で確認する |
| skill_docs/gen_skill | 構文章・診断表・標準ソース・HAND_WRITTEN・ライセンスから生成・比較。f1 の確認表や docs/ja は埋め込みに含めない |
| CLI・package・process の統合テスト | 自身が作る一時入力と testdata を使う。改造の manifest・採取済み JSON を期待値の生成元にしない |
| check.sh の skill_eval | `python3 tools/skill-eval/skill_eval.py --self-test`。LLM を呼ぶ評価ではない |
| check.sh の python | 列挙した tools の Python 構文を読み、source-migrate/try-actions-migrate の自己検査を実行。改造の一時入力を渡さない |

F1 の一時的な照合だけが M2a/M2b/M3b の記録を読む。これは通常の検査や処理系へ接続していない。旧移行器の基準データ・fuzz の古い lock・R29 の Skill 評価は既存の申し送りとして残し、今回の検査の成功に含めない。
