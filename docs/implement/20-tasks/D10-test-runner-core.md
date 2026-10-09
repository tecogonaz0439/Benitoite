# D10 テストの実行器 1: テストの関数の実行と `Assert.Check` の処理

- 依存する作業: [D00](D00-u4-interfaces.md), [R28](R28-interrupt-and-stop-procedure.md), [R29](R29-runtime-builtins.md)
- 難易度: 4（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 大（1500 行超。テストを含む）
- ブランチ: impl/D10-test-runner-core

## 目的

テストの関数を一つの実行として動かす `runtime::run::run_test` と、`Assert.Check` の操作の処理を書く（02-11「テストの実行」、[README](../README.md) の「U3・U4 で決めたこと」の 12）。VM の `IO` の命令で、どの言語のハンドラも処理しなかった `Assert` の操作を、送り出しの列に置かずにその場で確かめ、失敗なら `StopReason::CheckFailed` で止める手順を始める。確認の失敗の報告に使う値の書き出し（`render_value`）と、呼び出しの式の型の表（`AssertTable::build`）もここで書く。値の書き出しは失敗を見つけた時点（ヒープの値が生きている間）に行う必要があるからである。

テストの関数を集める処理、結果の報告、`test` のコマンドラインは D11 が書く。

依存の理由: 止める手順（R21）とタスク・IO 実行器（R25・R26）・出力の転送（R27）・中断の要求（R28）がそろっていないと、`run_test` を `run_program` と同じ流れで書けない。R29 は、テストで確かめる `Process.exit` と `Console` の関数を作る。どれも R28・R29 の依存に含まれる。F09 は D00 の依存（F18）に含まれる。

## 読む設計書の節

- [スクリプト実行と埋め込み](../../design/02-impl/02-11-embedding.md): 「テストの実行」「実行の入力と結果」
- [利用者プログラムのテスト](../../design/06-tooling/06-04-test-runner.md): 「テストの関数」「期待の確認」「テストの実行」「結果の報告」の表と値の書き出し
- [ランタイム](../../design/02-impl/02-09-runtime.md): 「操作の振り分け」「プログラムの実行の流れ」「出力のバッファ」「中断の要求」
- [仮想機械](../../design/02-impl/02-08-vm.md): 「止める手順」「実行時エラーの情報の記録」「タスクの起動と待ち方」
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md): 「標準の型クラス（初回リリース版）」の `Show.show` の形
- [ソース管理と位置情報](../../design/02-impl/02-02-source-and-spans.md): 「合成ノードの由来位置」
- [ADR 0120](../../design/decisions/0120-test-functions-and-assert-effect.md)、[ADR 0151](../../design/decisions/0151-inherited-handlers-tail-resume-only.md)、[ADR 0165](../../design/decisions/0165-exit-and-stdio-in-embedded-runs.md)
- インターフェース: [10-18](../10-interfaces/10-18-test-runner.md) の「`Assert.Check` の処理」「テストの関数の実行」、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「実行の流れ」、[10-09](../10-interfaces/10-09-vm.md) の `StopReason`・`StopInfo`・`FrameRecord`・「実行ごとの状態」、[10-10](../10-interfaces/10-10-scheduler-and-io.md) の「送り出しの列と二つの部品」、[10-08](../10-interfaces/10-08-values-and-heap.md) の `ValueCtx`・`runtime::equal`・`runtime::list`・`runtime::map`、[10-05](../10-interfaces/10-05-types.md) の `Ty`・`AdtTable`・`TypeckOutput`、[10-04](../10-interfaces/10-04-modules-and-resolve.md) の `ResolveOutput`

## 作るもの

- `src/runtime/run.rs`: `run_test` の本体。`run_program` と共通の部分は非公開の関数にまとめてよい（`run_program` のシグネチャと振る舞いは変えない）。
- `src/runtime/assert.rs`: `AssertTable::build`・`op_of`、`evaluate`、`render_value` の本体。
- `src/vm/mod.rs`: `Vm::start_test`・`take_check_failure` の本体。
- `src/vm/state.rs`: `RunState` に欄を加える（`Assert` の表 `Option<Arc<AssertTable>>`、最初のタスクの戻り値の型、確認の失敗の記録）。
- `src/vm/dispatch/tasks.rs` の `finish`（`main_outcome(program.main_kind, …)` を読む箇所）: 最初のタスクの戻り値の型を、手順 1 の型から読む。同じファイルの予算の切り替えの経路は R41 も変えるので、D10 は `finish` だけを変え、切り替えの経路に触れない。
- VM の `IO` の命令の処理（R20・R26 が書いたファイル）: 10-18「`Assert.Check` の処理」の手順 2〜5 の分岐を加える。加える場所は、`src/vm/dispatch/handlers.rs` の `Opcode::Io` の分岐で、`io(...)` が `None` を返した後、`execute_builtin` の前の一か所とする（直接呼び出しと要求と応答の両方の方式がここを通る）。
- 上のテスト。

## 手順の要点

1. `start_test`: `start_main` と同じく最初のタスクを作り、`proto` を引数なしで呼ぶ枠を積む。`RunState` に `AssertTable` と戻り値の型を置く。最初のタスクが値で終わったときの `MainOutcome` の決め方は、`CompiledProgram::main_kind` の代わりにこの型で行う。
2. `IO` の命令の分岐: `AssertTable` があり `op_of(BuiltinRef::id)` が操作を返したら、引数のレジスタを読み、`runtime::report::instr_span` で命令の由来位置を求めて `evaluate` を呼ぶ。`Passed` なら結果のレジスタに `Value::Unit` を入れて次の命令へ進む。`Failed` なら、`StopInfo` を作るときと同じ方法で呼び出しの枠とタスクの起動の履歴を集めて `CheckFailure` を作り、`RunState` に置いて、`StopReason::CheckFailed(op.name())` で止める手順を始める。`CheckFailure` の `frames`・`spawns` は `RunState::stop_info` の結果から作る。止める手順は、`interrupt_call`（`src/vm/dispatch.rs`）と同じ形で始める（`state.stopping` が空なら枠を保存して `state.stopping = Some(StopReason::CheckFailed(..))` を置き、`Control::Reload` を返す）。どちらの IO の方式でも、要求を作らない。
3. `evaluate`: 10-18「確認と値の書き出し」の表のとおり。`Assert.equal`・`notEqual` は `runtime::equal::values_equal` で比べ、失敗なら二つの値を `render_value` で書き出す。型は `value_types` を `site` で引く。
4. `render_value`: 10-18 の表の書き方で、値を明示の積み重ねで辿って書く（00-02「再帰の深さ」）。代数的データ型は `Ty::Con(TyCon::Adt(b), args)` の `AdtTable` の定義から構成子の名前と引数の型（型パラメータを `args` で置き換えたもの）を引く。型が分からないときの書き方も 10-18 に従う。`String`・`Character` のエスケープは、`src/builtins/funcs/traits.rs` の非公開の関数 `escaped` と同じ規則を、`runtime/assert.rs` の非公開の補助の関数として書き写す（traits.rs は変えない）。
5. `AssertTable::build`: 利用者のモジュールの AST（`CheckedProgram::asts` のうち、`checked.modules` の `ModuleKind::Entry`・`ModuleKind::User` のモジュールのもの。`CheckedProgram` は `SourceTable` を持たない）を辿り、10-18「確認と値の書き出し」の規則で `value_types` を作る。操作の束縛は `ResolveOutput::stdlib_names` の `Benitoite.Assert.equal`・`Benitoite.Assert.notEqual`、項目の番号は `lookup_builtin` の `Benitoite.Assert.*` で引く。
6. `run_test`: 10-18「テストの関数の実行」の表のとおりに `TestEnd` を作る。`IoRuntime` を作った直後に、L14 が `src/runtime/run.rs` に置く隠れた乱数の生成器の種を入れる共有の関数を呼ぶ（`benitoite test` でも `Random.Generate` の隠れた生成器に OS の乱数の種が入るようにする。L14「作るもの」）。L14 がまだ入っていなければ呼ばず、L14 が `run_test` の経路にも加える。（注記: その後の事前点検で、`run_program` と `run_test` はどちらも `run_entry` を通るので、L14 が `run_entry` で種を入れる形に改めた。L14「作るもの」）VM の実行は `runtime::panic::catch` で囲む。`CheckFailed` のときは `take_check_failure` で記録を取り出し、止める途中の解放の失敗を `release_failures` に入れる。
7. 起動したタスクの中の `Assert` の操作も同じ分岐を通ること、利用者が `Assert.Check` を処理するハンドラを書いたときはそちらが先に処理することを、テストで確かめる。

## 受け入れテスト

段ごとの単体テスト（`runtime::run` と `runtime::assert`）として、`pipeline::check_text`（`require_main` は偽）・`desugar_checked`・`compile` で作ったプログラムに `run_test` をかけて確かめる。`RunEnv` の出力先は `Capture`、標準入力は `Empty` とする。二つの IO の方式（`ExecMode::Direct`・`Request`）の両方で通す。

| 場合 | 期待 |
|---|---|
| 成功する `Unit` のテスト | `Returned`、終了状態 0 |
| `Result.Ok(())`・`Result.Error("x")` を返すテスト | `Returned`／`MainError`（`main_error` が `x`） |
| `Assert.equal(1, 2)` | `CheckFailed`、終了状態 1、`check_failure` の `left` が `1`、`right` が `2`、`at` の由来位置が呼び出しの式 |
| `Assert.notEqual`・`isTrue`・`fail` | それぞれ 10-18 の表の `message` と `left`・`right` |
| 失敗の後の文 | 評価されない（失敗の後の `Console.writeLine` が捕らえた出力にない） |
| `with` のリソース | 確認の失敗で止めたとき、開いていたリソースが内側から解放される。作業用のスレッド（または `OsResource`）を差し替えて close を失敗させ、`release_failures` に内側から外側の順で並ぶことで確かめる（既存の解放の失敗のテストと同じ形） |
| 起動したタスクの中の確認 | `Task.all` で起動したタスクの中の失敗も `CheckFailed` になり、`check_failure` にタスクの起動の履歴がある |
| 利用者のハンドラ | `handle … with case Assert.equal(a, b) -> resume(())` で囲んだ失敗する確認は、テストを失敗させない |
| 値の書き出し | `Integer`・`Float`・`Decimal`・`String`（エスケープを含む）・`Character`・`Boolean`・`Unit`・`List`・`Option`・`Result`・`Pair`・`Triple`・利用者の `data`・レコード・`Map`・`Set` の値が、10-18 の表の形になる。深い入れ子のリストと長いリストでも処理系の不具合にならない |
| 型の分からない値 | 型パラメータを持つ補助の関数の中の `Assert.equal` で、構成子の値が `<constructor #タグ>` の形になる |
| パイプの確認 | `x \|> Assert.equal(_, 3)` の失敗で、値が型に従って書き出される |
| `Process.exit(4)` | `Exited(4)`、終了状態 4 |
| 実行時エラー | `Stopped`、報告が一つ |
| 中断の要求 | 要求のある読み口を与えると `Interrupted`、終了状態 130 |
| 出力の捕捉 | テストが書いた標準出力と標準エラー出力が、それぞれの `Capture` に入る |
| `run` の経路 | `run_program` の振る舞いが変わらない（既存のテストが通る） |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け持つ関数に `todo!()` が残っていない
- 受け入れテストのすべての場合を確かめるテストがある

## 確認の観点

- `Assert` の操作を、ハンドラの連鎖を探した後でだけ受けているか。利用者のハンドラより先に受ける経路がないか
- 確認の失敗の記録を、枠を一つも降ろさないうちに作っているか
- 値の書き出しを明示の積み重ねで書いているか。ヒープの値を区間の外へ持ち出していないか（書き出した文字列だけを持ち出す）
- `run_program` の振る舞いを変えていないか

## 難易度の理由

VM の命令の処理に分岐を加え、止める手順の新しい理由を実際に通すので、第 2 段の VM の作り（止める手順、タスク、区間）を読んで合わせる必要がある。値の書き出しは、静的な型と実行時の値を対応させて辿る。ただし、どれも新しい仕組みを作らず、既存の口（`StopInfo` の作り方、`values_equal`、読み出しの関数）を組み合わせて書ける。
