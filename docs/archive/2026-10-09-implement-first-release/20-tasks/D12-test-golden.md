# D12 ゴールデンテストの `test` の方式

- 依存する作業: [D11](D11-test-report-and-command.md), [C10](C10-golden-runner.md), [R41](R41-open-062-fixes.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。テストのデータを含む）
- ブランチ: impl/D12-test-golden

## 目的

ゴールデンテストの実行器（C05 の後は `tests/golden.rs`）に `test` の方式を加え（ADR 0224 の決定 2、07-03「ゴールデンテストの形式（初回リリース版）」）、`test` の区分のゴールデンテストを置く。確かめるのは、終了状態、`.stdout` のテストの結果の報告と集計、検査の誤りの診断である。

R41 に依存するのは、`task_assert`・`runtime_error` の期待値（位置と履歴）が R41 の直し 4 で変わるからである。

## 読む設計書の節

- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md): 「ゴールデンテスト」「ゴールデンテストの形式（初回リリース版）」
- [利用者プログラムのテスト](../../2026-10-09-design-first-release/06-tooling/06-04-test-runner.md): 全体
- [CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md): 「`test` のコマンドライン（初回リリース版）」
- [ADR 0224](../../2026-10-09-design-first-release/decisions/0224-golden-test-format-for-first-release.md)、[ADR 0252](../../2026-10-09-design-first-release/decisions/0252-test-report-format.md)、[ADR 0324](../../2026-10-09-design-first-release/decisions/0324-test-task-origins-end-at-test-function.md)、[ADR 0325](../../2026-10-09-design-first-release/decisions/0325-outermost-frame-shows-no-call-site.md)
- インターフェース: [10-18](../10-interfaces/10-18-test-runner.md) の「結果の報告」
- 作業の文書: [C10](C10-golden-runner.md) の「期待値のファイル」「実行の手順」「書き直しの指定」

## 作るもの

- `tests/golden.rs` と `tests/golden/` の下: `.mode` が `test` のテストの実行。
- `testdata/test/`: `test` の区分のゴールデンテスト（後述の「受け入れテスト」）。

## 手順の要点

1. `test` の方式のテストは、`["test", "--diagnostics=json", <.options の行>…, <パス>]` を `cli::parse_args` で解釈し、`cli::execute` で実行する（`--diagnostics` の扱いは C10「実行の手順」の 1 と同じ）。
2. 比べるものは、終了状態（`.exit`）、標準出力（`.stdout`。`--diagnostics=json` なので JSON Lines のテストの結果と集計）、標準エラー出力の JSON の行（`.diag.json`。検査の誤りの診断）とそれ以外（`.stderr`）である。
3. `.text.stdout` を置いたテストは、`--diagnostics=json` を加えずにもう一度実行し、文章の形の標準出力の全体を比べる（`.text.stderr` と同じ考え方。文章の形の体裁を確かめるテストだけに置く）。07-03 の期待値のファイルの表には、オーケストレータが `.text.stdout` の行を加えてある（文書の更新は不要）。書き直しの指定では、`.text.stderr` と同じく、あるときだけ書き直す。
4. IO の二つの方式で実行して、どちらも期待値と一致することを確かめる（C10「実行の手順」の 5 と同じ）。
5. JSON の `stdout`・`stderr` の項目と、捕らえた出力に一時ディレクトリのパスが入らないように、テストのスクリプトを書く。
6. `test` の方式は、fmt の方式と同じく `run_case` の頭で分け、フォーマッタの性質の確かめ（07-03 が対象を `check`・`run` に限る）に数えない。
7. 解放の失敗を起こすテストは置かない。JSON の `"assert"`・`"exit"` に解放の注記を `notes` として載せることを [ADR 0333](../../2026-10-09-design-first-release/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 2 で決めたが、実装の直しは後の作業で行い、その作業が解放の失敗のテストを置くためである。深い再帰・長いリストを使うテストは置かない（使うなら `cfg!(feature = "gc-stress")` で小さくし、まず小さな規模で時間を見積もる）。

## 受け入れテスト

`testdata/test/` に次のテストを置く。`// spec:` の行には 01-spec の節だけを書く。`tools/spec-coverage/spec_coverage.py` は見出しを `docs/archive/2026-10-09-design-first-release/01-spec/` からしか読まず、表にない章の印を誤りにするからである。確かめる 06-04 の節は、普通のコメント（例 `// 06-04「組み込みの操作の差し替え」`）で示す。ディレクトリの形のテストでは、`// spec:` の行と節を示すコメントを入口のファイル（`main.bnt`。`main.bnt` のない `test` の方式のディレクトリでは、どれか一つのファイル）に書く。

| テスト | 確かめること |
|---|---|
| `passing` | 成功するテストだけ。終了状態 0 |
| `assert_equal`・`assert_not_equal`・`assert_is_true`・`assert_fail` | 各確認の失敗の詳細（`left`・`right`・`message`、位置と履歴）。終了状態 1 |
| `values` | 標準の型・利用者の `data`・レコード・`Map`・`Set` の値の書き出し（`.text.stdout` も置く） |
| `result_error` | `Result.Error` を返すテスト |
| `runtime_error` | 実行時エラーで失敗するテストと、続くテストが実行されること。起動したタスクの中で起きる実行時エラーのテストも置く。テストの関数のタスクで起きた実行時エラーの `taskOrigins` は空の配列、起動したタスクの中で起きた実行時エラーの `taskOrigins` の最後の段はテストの関数の名前である（[ADR 0324](../../2026-10-09-design-first-release/decisions/0324-test-task-origins-end-at-test-function.md)） |
| `exit` | `Process.exit` で失敗するテスト |
| `captured_output` | 失敗したテストの捕らえた出力（`.text.stdout` も置く） |
| `handler_replacement` | 06-04「組み込みの操作の差し替え」の二つの例（`File.readText`・`Process.run` をハンドラで差し替える）が成功し、実際のファイルとコマンドに触れない |
| `user_assert_handler` | 利用者が `Assert.Check` を処理するハンドラで、失敗する確認がテストを失敗させない |
| `task_assert` | 起動したタスクの中の確認の失敗。`taskOrigins` の最後の段は `main` ではなくテストの関数の名前である（[ADR 0324](../../2026-10-09-design-first-release/decisions/0324-test-task-origins-end-at-test-function.md)） |
| `directory` | ディレクトリの指定で、下の複数のファイルのテストがパスの辞書順に実行される。ほかのファイルが取り込むモジュールのテストは、そのファイル自身の行として一度だけ出る（取り込まれるだけのモジュールのテストが実行されないことは、D11 の `tests/test_command.rs` の `tests_of_imported_modules_run_only_when_their_file_is_given` が確かめるので、D12 では扱わない） |
| `check_error` | 検査の誤りのあるファイルと誤りのないファイルを並べ、誤りのファイルのテストを実行せず、終了状態 2、集計に実行しなかったファイルの数 |
| `deny_warnings` | `.options` に `--deny-warnings`。警告のあるファイルのテストを実行しない |
| `no_tests` | テストの関数のないファイル |

06-04 の例は、非公式のモジュールの import を取り込みの名前（`import Benitoite.Unofficial.IO.File`）に置き換えて使う（07-03「言語仕様の例の検査」の最後の項と同じ扱い）。`handler_replacement` は U3 の `Process.run`・`Process.command`（L13）を要するので、L13 は L 系の統合用のブランチにあり、san_benito にはまだ取り込まれていないので、`File.readText` の例だけを置き、`Process.run` の例を D34 の受け入れテストに回して完了の報告に書く。

あわせて、実行器の検出力（`.stdout` を 1 バイト変えるとテストが失敗する）を手で確かめ、完了の報告に書く。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある

## 難易度の理由

実行器に方式を一つ足し、テストのスクリプトと期待値を書く作業である。期待値は `BENITOITE_BLESS=1` で作れるが、作った期待値が 06-04 と ADR 0252 の形になっていることを読んで確かめる必要がある。
