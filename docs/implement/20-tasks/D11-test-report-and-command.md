# D11 テストの実行器 2: 結果の報告と `test` のコマンドライン

- 依存する作業: [D10](D10-test-runner-core.md), [D03](D03-fmt-command.md)
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/D11-test-command

## 目的

`benitoite test [オプション] <パス>...` を実行できるようにする（06-01「`test` のコマンドライン（初回リリース版）」、06-04「テストの実行」「結果の報告」、ADR 0206・0208・0252）。テストするファイルの並び、テストの関数の集め方、ファイルごとの検査とコンパイル、テストの結果の文章の形と JSON Lines の形、終了状態を書く。確認の失敗の位置と履歴を書く関数を 10-02 の `render.rs` に加える。

D03 に依存するのは、コマンドラインの解釈（`args::parse_path_args`）と `bnt_files` を D03 が書くからである。D03 は D01・D02 の後である。D11 は D03 を取り込んだ後に始める。R38（実行時エラーの報告）は D00 の依存に含まれる。

## 読む設計書の節

- [CLI](../../design/06-tooling/06-01-cli.md): 「ディレクトリの指定（初回リリース版）」「`test` のコマンドライン（初回リリース版）」「オプション」「終了状態」
- [利用者プログラムのテスト](../../design/06-tooling/06-04-test-runner.md): 「テストの関数」「テストの実行」「結果の報告」
- [スクリプト実行と埋め込み](../../design/02-impl/02-11-embedding.md): 「テストの実行」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md): 「文章の形式」「JSON の形式」「実行時エラーと資源の不足の報告」「テストの実行器への受け渡し」
- [ADR 0206](../../design/decisions/0206-test-command-line-and-exit-status.md)、[ADR 0208](../../design/decisions/0208-test-report-destination.md)、[ADR 0252](../../design/decisions/0252-test-report-format.md)、[ADR 0324](../../design/decisions/0324-test-task-origins-end-at-test-function.md)、[ADR 0333](../../design/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md)
- インターフェース: [10-18](../10-interfaces/10-18-test-runner.md) の「結果の報告」「診断の書き出しに加える関数」、[10-17](../10-interfaces/10-17-formatter.md) の「`test` と `fmt` のコマンドライン」、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「パイプライン」「止まったときの報告」「コマンドの実行」、[10-02](../10-interfaces/10-02-diagnostics.md) の「診断の書き出し」

## 作るもの

- `src/cli/tools/test_runner/mod.rs`: `run_test_command`・`test_entries`・`collect_tests` の本体。中断の要求の読み口をテストごとの `RunEnv` で共有する包みを、非公開の型で書く。包みは `requested` だけでなく `attach`・`flag` も中の読み口へ渡す（渡さないと、待っているテストが中断の要求で起きない）。テストの `RunEnv` の `parts` には常に `None` を渡す（`RuntimeParts` は Clone できない）。
- `src/cli/tools/test_runner/report.rs`: 報告の関数の本体。
- `src/diag/render.rs`: 10-18 が加えた四つの関数（`render_trace_text`・`json_location`・`json_trace_fields`・`json_string`）の本体。F16 が書いた `render_one_text`・`render_json_line` の同じ部分を共通にする（出力は変えない。既存のゴールデンテストが確かめる）。`render_one_text` を `render_trace_text` を呼ぶ形にはできない。`render_one_text` では、位置の行は `append_primary_excerpt` が抜粋の一部として書き、末尾呼び出しの注記は `diag.notes` の一つとして（`runtime::report` の `insert_before_tail` により解放の注記の後に）並ぶからである。そこで、呼び出しの履歴とタスクの起動の履歴を書く非公開の補助を一つ書き、`render_one_text` と `render_trace_text` の両方から呼ぶ形でよい。JSON の側も同じく、`render_json_line` から `json_location`・`json_trace_fields`・`json_string` を呼ぶか、共通の非公開の補助を両方から呼ぶ形でよい。
  - `render_trace_text` の位置の行の字下げは、`render_one_text` と同じく溝の幅（主な位置の行番号の桁数、最小 2）の空白とする（`  --> tests/sum.bnt:14:3`）。シグネチャのコメントの ` --> ` は行の形を示したもので、字下げの数を定めたものではない。抜粋の行と、抜粋の後の `|` だけの行は書かない。
  - `"assert"` の失敗の注記の並びは、実行時エラーの報告と同じく、止める途中の解放の注記を末尾呼び出しの注記の前に置く。`render_trace_text` は注記の並びを受け取らないので、解放の注記の並びを受け取って末尾呼び出しの注記の前に書く `pub(crate)` の補助を `render.rs` に加え、`render_trace_text` はそれを空の並びで呼び、`text_failure` は `"assert"` でそれを `Failure::Assert` の `notes` で呼ぶ形でよい（`render_trace_text` のシグネチャは変えない）。
- `src/cli/tools.rs`: `run_tool` の `ToolCommand::Test` の場合を `parse_path_args` と `run_test_command` を呼ぶ形に改める。F18 が `test` の `TOOL_UNAVAILABLE` を確かめたテストは、本作業のテストに置き換える。そのテストは `src/cli/mod.rs` の `usage_errors_and_unavailable_tools_have_two_lines_and_exit_two` にあり、名前を並べたループから `"test"` を外す（このファイルを変えてよい。00-03 の「ほかの作業が置いたファイルを改める作業」の表。D03 が `"fmt"` を外すのと同じ）。
- `src/runtime/report.rs`・`src/runtime/run.rs` は変えない。タスクの起動の履歴の最後の段をテストの関数の名前にすること（[ADR 0324](../../design/decisions/0324-test-task-origins-end-at-test-function.md)）は、`test_runner` の中で報告のデータを書き換えて行う（手順の要点の 4）。ADR 0324 の決定 3 は `report.rs` の `main_frame` を変えることを許すが、この方法では変えずに済むので、その許可は使わない（ADR 0324 の帰結、2026-10-07 の改め）。`"runtime"` の報告は `run.rs` の `step_end` の中で `report::stop_diagnostic(program, &info)` が作り、テストの関数の名前を受け取らない。`stop_diagnostic`（10-13）・`StopInfo`（10-09）・`CompiledProgram`（10-07）は凍結した型とシグネチャなので、名前を渡す形には変えられない。
- 上のテスト。CLI のテストは新しいファイル `tests/test_command.rs` に置く。別のプロセスでの中断の要求のテスト（受け入れテストの最後の段落）も同じファイルに書く。CLI のテストはどの OS でも動くので、ファイル全体ではなく、中断のテストとその補助だけを `#[cfg(unix)]` の子のモジュールにまとめる（シグナルを送り `std::os::unix` を使うため。既存の `tests/interrupt_process.rs` はファイル全体が中断のテストなので `#![cfg(unix)]` にしている）。

## 手順の要点

1. `test_entries`: 与えたパスの順に、ファイルは `pipeline::entry_spec`、ディレクトリは `bnt_files` で展開し、根のディレクトリを指定したディレクトリ、表示名をディレクトリのパスに相対パスを続けたものにした `EntrySpec` を作る（ADR 0206 の決定 2）。`test_entries` は全部か失敗かの `Result` を返す。パスのディレクトリを読めないときは、`run_test_command` は E0101（`path` と `reason`。D03 の作業文書の E0101 の作り方と同じく `DiagBuilder::new(DiagCode::E0101).arg("path", パス).arg("reason", OS の誤りの文).note("reason")` の形で、span はない）を `--diagnostics` の形式で `env.stderr` に書き、テストを一つも実行せずに終了状態 2 とする（テストの行も集計の行も書かない）。
2. `collect_tests`: 実行を始めるファイルのモジュールの AST のトップレベルの宣言のうち、属性 `test` を持つ関数を宣言の順に集める。説明は属性の最初の引数、束縛は `ResolveOutput::decls`、戻り値の型は `TypeckOutput::decl_types` の型が `Result` の型か `Unit` かで決める。
3. `run_test_command`: 10-18「ファイルごとの手順」のとおり。`pipeline::check` に渡す `fs` は実際のファイルシステム（`modules::RealFs`）である。テストの関数の原型は `CompiledProgram::top_fns` を束縛で引く。見つからなければ処理系の不具合とする。`AssertTable::build` はファイルごとに一度だけ行い、`Arc` で共有する。
4. 報告: 10-18「文章の形」「JSON Lines の形」のとおり。`test_name` の説明のエスケープには、D10 が `runtime/assert.rs` に書いた `String` のエスケープの補助の関数を使ってよい（そのために `pub(crate)` に改めてよい）。失敗の詳細は `TestEnd` から次のように作る。
   - `CheckFailed`: 位置と呼び出しの履歴とタスクの起動の履歴は、`StopInfo { stop: 任意の実行時エラー, at: Some(at), frames, spawns, deadlock: vec![] }` を作って `runtime::report::stop_diagnostic` に渡し、結果の `primary`・`trace`・`task_origins` を使う。実行時エラーは位置と履歴を持つもの（たとえば `Stop::Runtime(RuntimeError::DivisionByZero)`）を選ぶ。規則（02-08「実行時エラーの情報の記録」、20 段を超えるときの省き方を含む）を書き写さないのは、R41 の直しと自動で揃うようにするためである。止める途中の解放の失敗は、`runtime::report::add_release_failures` を中身のない報告に当てて得た注記の文を使う。
   - `MainError`・`Stopped`・`Exited`: `main_error` と `reports` から作る。
   - テストの関数の名前への書き換え（[ADR 0324](../../design/decisions/0324-test-task-origins-end-at-test-function.md)）: `runtime::report` は、タスクの起動の履歴の最後の段と、行き詰まりで待つ最初のタスクを、常に `main` の段（`TraceFrame { name: FrameName::Named("main"), call_site: None }`。`report.rs` の非公開の `main_frame`）にする。テストの実行では最初のタスクはテストの関数なので、`test_runner` は、`Failure` を作るときに次の二つを `TestFn::function` に書き換える。書き換えは報告のデータ（`Diagnostic` と `Failure` の欄）の上で行い、文字列にした後の置換はしない。
     - タスクの起動の履歴: `Failure::Runtime` の `report.task_origins`（`Vec<TraceFrame>`）と、`CheckFailed` で `stop_diagnostic` から得た `task_origins`（`Failure::Assert` の `task_origins` にするもの）が空でなければ、その最後の要素の `name` を `FrameName::Named(関数の名前)` にする（`call_site` は `None` のまま）。空の配列（テストの関数のタスクで起きたとき）は空のままにする。
     - 行き詰まりの報告（R1001）: `Failure::Runtime` の `report.waiting`（`Vec<WaitingTask>`）のうち、`task` が `main` の段（名前が `Named("main")` で `call_site` が `None`）である要素の `task.name` を `FrameName::Named(関数の名前)` にする。起動したタスクの段は、起動した関数か組み込みの関数の名前を持つので書き換えない（位置のない `main` の段は `main_frame` だけが作る）。
   - 書き換えた報告から文章の形と JSON の形の両方を書くので、`"runtime"` の `render_one_text`・`render_json_line` の出力にも、テストの関数の名前が出る。
5. 終了状態: 10-18「終了状態」のとおり。検査の誤りのファイルは `files_not_run` に数え、終了状態 2 に寄与する。集計の行の `{outcome}` は、`failed` が 0、`files_not_run` が 0、中断の要求で終えていない、のすべてを満たすときだけ `ok`、ほかは `FAILED` とする（10-18「文章の形」）。
6. 捕らえた出力の書き出しでは、正しくない UTF-8 のバイト列を U+FFFD に置き換える（`String::from_utf8_lossy`）。JSON の `stdout`・`stderr` も同じ文字列にする。

## 受け入れテスト

`tests/` の CLI のテスト（`cli::execute` を `Capture` の出力先で呼ぶもの）と、各モジュールのテストのモジュールで確かめる。一時ディレクトリにテストのファイルを置いて実行する。

| 場合 | 期待 |
|---|---|
| 成功と失敗の混じったファイル | テストの行、`failures:` の節、集計の行が 06-04 の例の形になる。終了状態 1 |
| すべて成功 | `failures:` の節がなく、`test result: ok.`。終了状態 0 |
| 説明の有無 | 説明があれば引用符で囲んだ説明、なければ関数の名前 |
| 失敗の理由ごとの詳細 | `"assert"`（`equal` の `left`・`right`、`isTrue` の `message`、位置と履歴）、`"error"`、`"runtime"`、`"exit"` が 10-18 の形になる |
| 捕らえた出力 | 失敗したテストの詳細に `captured stdout`・`captured stderr` の節がある。成功したテストの出力は示さない |
| ディレクトリの指定 | 下のすべての `.bnt` をパスの辞書順に扱い、根のディレクトリを指定したディレクトリにする（下の階層のファイルが、指定したディレクトリからの名前でモジュールを取り込める） |
| 取り込むモジュールのテスト | 取り込んだモジュールのファイルを指定しなければ、そのテストを実行しない |
| 検査の誤りのファイル | 診断を標準エラー出力に書き、そのファイルのテストを実行しない。ほかのファイルのテストは実行する。集計に実行しなかったファイルの数。終了状態 2 |
| `--deny-warnings` | 警告のあるファイルのテストを実行しない。終了状態 2 |
| `--max-call-stack` | 小さな値で深い再帰のテストが資源の不足で失敗する |
| 起動したタスクの中の失敗 | テストの関数が起動したタスクの中の確認の失敗と実行時エラーで、報告の `taskOrigins` の最後の段がテストの関数の名前である（`main` ではない）。テストの関数のタスクで起きたときは `taskOrigins` が空の配列。`run` の経路の報告の最後の段は `main` のまま |
| 行き詰まり | テストの最初のタスクが待ったまま行き詰まると、R1001 の報告の待つタスクの行で、最初のタスクがテストの関数の名前で示される（`main` ではない） |
| 集計の `ok`・`FAILED` | 失敗したテストがなくても、検査の誤りで実行しなかったファイルがあるか中断の要求で終えたときは `test result: FAILED.` |
| 読めないディレクトリ | E0101 を標準エラー出力に書き、テストを一つも実行せず、標準出力に何も書かない。終了状態 2（`#[cfg(unix)]`） |
| JSON Lines | `--diagnostics=json` で、テストごとの行と集計の行が ADR 0252 の項目と順で書かれる。`"runtime"` の `failure` が実行時エラーの報告の JSON の項目を持つ。`"assert"`・`"exit"` の `failure` が、止める途中の解放の失敗の注記を `notes` に持つ（ADR 0333 の決定 2。10-18「JSON Lines の形」） |
| 中断の要求 | 要求のある読み口を `CliEnv::interrupt` に与えると、`interrupted` の集計で終了状態 130 |
| 使い方の誤り | パスがない、`test --check` で、使い方の誤りの 2 行と終了状態 2 |
| テストのないファイル | 集計の行だけを書き、終了状態 0 |
| `render.rs` の共通化 | 既存の実行時エラーのゴールデンテスト（文章と JSON）の出力が変わらない |

別のプロセスでの中断の要求のテスト（07-03「中断の要求のテスト（初回リリース版）」の最後の段落）を、R31 の `tests/interrupt_process.rs` と同じ手順で一つ、`tests/test_command.rs` の `#[cfg(unix)]` の子のモジュールに加える。テストの出力は `Capture` に捕らえられて子のプロセスの標準出力に出ないので、前に成功したテストの結果の行（`test …: … ok`）を準備の合図にし、次のテストが待つ形にする。待つテストは、`import Benitoite.Unofficial.IO.Clock` で `Clock.sleep(60000)` のように、準備の合図を待つ上限（`interrupt_process.rs` の `LIMIT` と同じ 30 秒）より十分長く待つ（`uses Clock.Time`）。実時間の待ちに頼らず、準備の合図の行を読んでから中断を送る（中断を送るまでの時間を固定の待ちで作らない）。`benitoite test` の子のプロセスがその行を書いた後、待つテストを実行している間に `SIGINT` を送り、終了状態 130 と、それまでに終えたテストの行と `interrupted` の集計を確かめる。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け持つ関数に `todo!()` が残っていない
- 受け入れテストのすべての場合を確かめるテストがある

## 難易度の理由

報告の形はすべて ADR 0252 と 10-18 が定めている。判断が要るのは、確認の失敗の位置と履歴を実行時エラーの報告と同じ規則で作ることと、`render.rs` を出力を変えずに共通化することである。
