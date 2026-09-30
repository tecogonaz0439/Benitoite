# D11 テストの実行器 2: 結果の報告と `test` のコマンドライン

- 依存する作業: [D10](D10-test-runner-core.md), [D03](D03-fmt-command.md)
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/D11-test-command

## 目的

`benitoite test [オプション] <パス>...` を実行できるようにする（06-01「`test` のコマンドライン（初回リリース版）」、06-04「テストの実行」「結果の報告」、ADR 0206・0208・0252）。テストするファイルの並び、テストの関数の集め方、ファイルごとの検査とコンパイル、テストの結果の文章の形と JSON Lines の形、終了状態を書く。確認の失敗の位置と履歴を書く関数を 10-02 の `render.rs` に加える。

D03 に依存するのは、コマンドラインの解釈（`args::parse_path_args`）と `bnt_files` を D03 が書くからである。R38（実行時エラーの報告）は D00 の依存に含まれる。

## 読む設計書の節

- [CLI](../../design/06-tooling/06-01-cli.md): 「ディレクトリの指定（初回リリース版）」「`test` のコマンドライン（初回リリース版）」「オプション」「終了状態」
- [利用者プログラムのテスト](../../design/06-tooling/06-04-test-runner.md): 「テストの関数」「テストの実行」「結果の報告」
- [スクリプト実行と埋め込み](../../design/02-impl/02-11-embedding.md): 「テストの実行」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md): 「文章の形式」「JSON の形式」「実行時エラーと資源の不足の報告」「テストの実行器への受け渡し」
- [ADR 0206](../../design/decisions/0206-test-command-line-and-exit-status.md)、[ADR 0208](../../design/decisions/0208-test-report-destination.md)、[ADR 0252](../../design/decisions/0252-test-report-format.md)
- インターフェース: [10-18](../10-interfaces/10-18-test-runner.md) の「結果の報告」「診断の書き出しに加える関数」、[10-17](../10-interfaces/10-17-formatter.md) の「`test` と `fmt` のコマンドライン」、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「パイプライン」「止まったときの報告」「コマンドの実行」、[10-02](../10-interfaces/10-02-diagnostics.md) の「診断の書き出し」

## 作るもの

- `src/cli/tools/test_runner/mod.rs`: `run_test_command`・`test_entries`・`collect_tests` の本体。中断の要求の読み口をテストごとの `RunEnv` で共有する包みを、非公開の型で書く。
- `src/cli/tools/test_runner/report.rs`: 報告の関数の本体。
- `src/diag/render.rs`: 10-18 が加えた四つの関数（`render_trace_text`・`json_location`・`json_trace_fields`・`json_string`）の本体。F16 が書いた `render_one_text`・`render_json_line` の同じ部分を、これらの関数を呼ぶ形に改めて共通にする（出力は変えない。既存のゴールデンテストが確かめる）。
- `src/cli/tools.rs`: `run_tool` の `ToolCommand::Test` の場合を `parse_path_args` と `run_test_command` を呼ぶ形に改める。F18 が `test` の `TOOL_UNAVAILABLE` を確かめたテストは、本作業のテストに置き換える。
- 上のテスト。

## 手順の要点

1. `test_entries`: 与えたパスの順に、ファイルは `pipeline::entry_spec`、ディレクトリは `bnt_files` で展開し、根のディレクトリを指定したディレクトリ、表示名をディレクトリのパスに相対パスを続けたものにした `EntrySpec` を作る（ADR 0206 の決定 2）。
2. `collect_tests`: 実行を始めるファイルのモジュールの AST のトップレベルの宣言のうち、属性 `test` を持つ関数を宣言の順に集める。説明は属性の最初の引数、束縛は `ResolveOutput::decls`、戻り値の型は `TypeckOutput::decl_types` の型が `Result` の型か `Unit` かで決める。
3. `run_test_command`: 10-18「ファイルごとの手順」のとおり。テストの関数の原型は `CompiledProgram::top_fns` を束縛で引く。見つからなければ処理系の不具合とする。`AssertTable::build` はファイルごとに一度だけ行い、`Arc` で共有する。
4. 報告: 10-18「文章の形」「JSON Lines の形」のとおり。失敗の詳細は `TestEnd` から次のように作る。
   - `CheckFailed`: `CheckFailure` の `at` から `runtime::report::instr_span` で位置を、`frames`・`spawns` から `runtime::report::frame_name`・`instr_span` で呼び出しの履歴とタスクの起動の履歴を、実行時エラーの報告と同じ規則（02-08「実行時エラーの情報の記録」、20 段を超えるときの省き方を含む）で作る。止める途中の解放の失敗は、`runtime::report::add_release_failures` を中身のない報告に当てて得た注記の文を使う。
   - `MainError`・`Stopped`・`Exited`: `main_error` と `reports` から作る。
5. 終了状態: 10-18「終了状態」のとおり。検査の誤りのファイルは `files_not_run` に数え、終了状態 2 に寄与する。
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
| JSON Lines | `--diagnostics=json` で、テストごとの行と集計の行が ADR 0252 の項目と順で書かれる。`"runtime"` の `failure` が実行時エラーの報告の JSON の項目を持つ |
| 中断の要求 | 要求のある読み口を `CliEnv::interrupt` に与えると、`interrupted` の集計で終了状態 130 |
| 使い方の誤り | パスがない、`test --check` で、使い方の誤りの 2 行と終了状態 2 |
| テストのないファイル | 集計の行だけを書き、終了状態 0 |
| `render.rs` の共通化 | 既存の実行時エラーのゴールデンテスト（文章と JSON）の出力が変わらない |

別のプロセスでの中断の要求のテスト（07-03「中断の要求のテスト（初回リリース版）」の最後の段落）を、R31 の `tests/` のテストと同じ手順で一つ加える。`benitoite test` の子のプロセスが、準備の行を書いてから待つテストを実行している間に `SIGINT` を送り、終了状態 130 と、それまでに終えたテストの行と `interrupted` の集計を確かめる。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け持つ関数に `todo!()` が残っていない
- 受け入れテストのすべての場合を確かめるテストがある

## 難易度の理由

報告の形はすべて ADR 0252 と 10-18 が定めている。判断が要るのは、確認の失敗の位置と履歴を実行時エラーの報告と同じ規則で作ることと、`render.rs` を出力を変えずに共通化することである。
