# R38 実行時エラーの報告

- 依存する作業: [R09](R09-vm-core.md)、[C02](C02-remaining-interfaces.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R38-runtime-reports

## 目的

止まったときの記録（`StopInfo`）、止める途中の解放の失敗（`ReleaseFailure`）、捕らえた panic（`PanicReport`）から、診断の `Diagnostic` を組み立てる `runtime::report` の関数を書く（10-13「止まったときの報告」）。呼び出しの履歴、タスクの起動の履歴、行き詰まりの待つタスクの並び、解放の失敗の報告、書き込みの失敗の報告、処理系の不具合の報告である。報告を標準エラー出力に書くのは呼び出し側（`run_program` の呼び出し側）であり、報告の文章の形式への書き出しは F16 の `diag::render` が行う。

最小実行版の `src/legacy/runtime/report.rs` を写し、初回リリース版の `Stop`・`StopInfo`・原型の由来の種類（10-07 の `ProtoOrigin`）・診断の表現（10-02）に合わせて広げる。

本作業は、止まったときの記録をデータとして受け取るだけで、VM の状態にもメモリの管理にも触れないので、第 1 段の測定を待たずに R09 の後に進めてよい（[ADR 0278](../../2026-10-09-design-first-release/decisions/0278-stage-1-completes-on-new-syntax-tests.md) の決定 3）。F18（`run_program` の最初の形）が本作業を使う。

## 読む設計書の節

- [診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「診断の内部の表現」「診断コード」「実行時エラーと資源の不足の報告」「解放の失敗の報告」「処理系の不具合と処理系の制限の報告」「JSON の形式」（報告が持つ欄の確かめのため）
- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「実行時エラーの情報の記録」（材料と、履歴と主な位置の作り方の手順 1〜4、行き詰まりの材料、書き込みの失敗の段落）
- [バイトコードとコード生成](../../2026-10-09-design-first-release/02-impl/02-07-bytecode.md)の「原型の名前と由来の種類」
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「リソースの追跡」の解放の失敗のまとめ方、「panic 境界」、「プログラムの実行の流れ」の終わり方の表と転送の失敗の箇条
- [評価意味論](../../2026-10-09-design-first-release/01-spec/01-08-evaluation.md)の「実行時エラーによる停止」「資源の不足」
- ADR: [0034](../../2026-10-09-design-first-release/decisions/0034-call-trace-in-runtime-errors.md)、[0068](../../2026-10-09-design-first-release/decisions/0068-release-resources-on-stop.md)、[0149](../../2026-10-09-design-first-release/decisions/0149-http-exchange-release-failure.md)、[0238](../../2026-10-09-design-first-release/decisions/0238-task-wait-deadlock-as-runtime-error.md)、[0045](../../2026-10-09-design-first-release/decisions/0045-late-detection-of-output-write-failure.md)、[0033](../../2026-10-09-design-first-release/decisions/0033-english-diagnostic-messages.md)、[0037](../../2026-10-09-design-first-release/decisions/0037-exit-status-values.md)

インターフェース:

- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「止まったときの報告」（`FaultThread`・`ReleaseCause`・`text`、本作業が中身を書く関数の一覧）、「作業の割り当て」
- [診断](../10-interfaces/10-02-diagnostics.md)の「診断の内部の表現」（`Diagnostic`・`DiagBuilder`・`FrameName`・`TraceFrame`・`CallTrace`・`WaitingTask`）、`codes::text` の定数、「コードの一覧」の「実行時エラー、資源の不足、処理系の制限」、「型板の直し方」
- [仮想機械](../10-interfaces/10-09-vm.md)の `StopInfo`・`FrameRecord`・`SpawnRecord`・`DeadlockWaiter`・`DeadlockWaitKind`・`InstrRef`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「止まる理由」（`Stop`・`RuntimeError`・`ResourceError`・`ReleaseFailure`・`ResourceKind`）、「panic 境界」（`PanicReport`）
- [バイトコード](../10-interfaces/10-07-bytecode.md)の `Proto`（`name`・`origin`・`span`・`positions`）、`ProtoOrigin`、`CompiledProgram::sources`

## 作るもの

- `src/runtime/report.rs`: 10-13 の `sig=` の関数（`stop_diagnostic`・`add_release_failures`・`release_report`・`write_failed`・`add_flush_failure`・`internal_diagnostic`・`frame_name`・`instr_span`）の中身と、その単体テスト。
- `src/diag/codes.rs`: 本作業が出すコード（R0101〜R1001 のうち `Stop` から作るもの）の型板の言い回しと説明を、10-02「型板の直し方」の範囲で直す必要があれば直す（[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」の例外）。直したものは完了の報告の「判断したこと」に挙げる。

## 手順の要点

### 段の名前と位置（02-08「実行時エラーの情報の記録」の手順 1・2、02-10 の名前の規則）

- `frame_name(program, proto)`: 原型の `origin` で分ける。`UserFn`・`UserMethod`・`StdlibPublic`・`BuiltinValue` は `FrameName::Named(原型の name)`。`UserLambda` は `Lambda(span)`、`UserHandleBody` は `Handle(span)`、`UserHandleClause` は `Case { operation, span }`（操作の名前は、原型の名前の決まった形（`<case Log.write>` など）から取り出すか、原型の名前をそのまま使うかを、F15 のコード生成が付ける名前に合わせて決める）、`UserLazy` は `Lazy(span)`。`span` は原型の `span`。`StdlibHelper` は `None`（履歴に含めない）。原型が表にないときは `None` とし、呼び出し側が処理系の不具合として扱う。
- `instr_span(program, at)`: 原型の `positions[pc]`。表にない命令と位置なしの命令は `None`。
- 位置が利用者のソースにあるかは、span のファイル ID で `CompiledProgram::sources` を引き、標準ライブラリのソースかどうかで決める（10-01 のソースの表）。

### 呼び出しの履歴と主な位置（手順 1〜4）

`StopInfo::frames` を内側から順に見て、次のように作る。

1. `frame_name` が `None` の段（標準ライブラリの補助の関数）を除く。
2. 各段の呼び出した位置は、その枠の `call_site` の命令の位置とする。`call_site` が `None` の段（`main` の段、タスクの最初の段）、位置が `None` の段、位置が利用者のソースにない段は、位置を示さない。
3. 主な位置は、`StopInfo::at` の命令の位置が利用者のソースにあればそれ。そうでなければ、内側の段から順に `call_site` の命令の位置を見て、利用者のソースにある最初のもの。見つからなければなし。補助の関数の枠の呼び出した位置は標準ライブラリのソースの中にあるので、手順 1 で除く前の枠を見ても除いた後の段を見ても結果は同じである。
4. 手順 1 で除いた後の段が 20 を超えるときは、内側の 10 段と外側の 10 段を残し、除いた段の数を `CallTrace` の省いた数にする。

履歴を持つ報告には、注記の最後に `codes::text::TRACE_TAIL_NOTE`（末尾呼び出しで通った関数が現れないことの注記）を置く。ほかの注記（R0901 の枠の数など）はその前に置く。

### タスクの起動の履歴

`StopInfo::spawns` の各段（止まったタスクから最初のタスクへ向かう順）について、起動した関数の名前と、その呼び出しの位置を示す。起動した呼び出しが標準ライブラリのソースの中にあるときは、`spawner_frames` を内側から見て、呼び出しの履歴の主な位置と同じ規則で、利用者のソースにある最も内側の呼び出しの名前と位置を示す（02-10「実行時エラーと資源の不足の報告」のタスクの段落）。最初のタスクの段は `main` とする。止まったタスクが最初のタスクなら、起動の履歴は空である。

### コードごとの報告（10-02「コードの一覧」の実行時エラーの表）

`stop_diagnostic` は、`StopInfo::stop` でコードを選ぶ。

- 実行時エラー（R0101〜R0103、R0401、R0402、R0501、R0502、R0701、R0801）と資源の不足（R0901〜R0903）: 上の主な位置、呼び出しの履歴、タスクの起動の履歴を持つ。型板に埋める値（R0401・R0402 の `{resource}` は `text::RESOURCE_*`、R0502 の `{operation}`、R0701 の `{index}` と `{function}`、R0901 の枠の数と修正案、R0902・R0903 の `{function}`・大きさ・`{unit}`（`text::UNIT_*`）・上限）を埋める。R0401（`with` を抜けるとき、取り消し、節が本体の続きを捨てるときの解放の失敗）は、失敗した解放ごとに、リソースの型、開いた位置（`ReleaseFailure::opened_at` の命令の位置。なければ `text::UNKNOWN_LOCATION`）、理由を注記に並べる。
- 書き込みの失敗（R0201・R0202）: 主な位置と履歴を持たず、失敗の理由を注記にする。
- 行き詰まり（R1001）: 主な位置と呼び出しの履歴を持たず、待つタスクの並び（`WaitingTask`）を `StopInfo::deadlock` の順（起動した順）に作る。各タスクの名前は、最初のタスクなら `main`、ほかは起動の履歴の最も内側の段の名前と位置。待つ種類は、組み込みの関数なら `DeadlockWaitKind::Builtin` の修飾した名前、ほかは `text::WAIT_*`。待つ位置は、待つ命令と `call_sites` から、主な位置と同じ規則で作る。
- `Stop::Internal(説明)`: `internal_diagnostic("run", 説明, None, FaultThread::Vm)` と同じ形の処理系の不具合の報告にする。

### 解放の失敗と書き込みの失敗の注記

- `add_release_failures`: 実行時エラーか資源の不足で止める途中の解放の失敗を、`codes::text::RELEASE_WHILE_STOPPING` の形の注記として、`TRACE_TAIL_NOTE` の前に置く（02-10「解放の失敗の報告」）。
- `release_report`: `Process.exit` と中断の要求で止める途中の解放の失敗一つを、R0401 の報告（報告の種類を `Release` に変える。10-02 の `DiagBuilder::kind`）にする。注記に理由と、止めた理由の注記（`RELEASE_EXIT_NOTE` の終了状態、`RELEASE_INTERRUPT_NOTE`）を置く。`HttpExchange` の失敗は呼び出し側が渡さない。
- `write_failed`: R0201（標準出力）か R0202（標準エラー出力）の報告。主な位置と履歴を持たず、理由を注記にする。
- `add_flush_failure`: 先の実行時エラーの報告に `FLUSH_FAILED_NOTE`（`{stream}` は `text::STDOUT_NAME`・`STDERR_NAME`）を加える。`TRACE_TAIL_NOTE` があれば、それが最後に残るようにその直前に入れる。

### 処理系の不具合の報告

`internal_diagnostic` は、コードを持たないので `DiagBuilder` を使わず、`Diagnostic` を直接組み立てる（10-13 のシグネチャの説明）。報告の種類は `Internal`、文言は `codes::text::INTERNAL_MESSAGE`。注記に、版（`env!("CARGO_PKG_VERSION")` を `INTERNAL_VERSION` に埋める）、段（`INTERNAL_STAGE`）、スレッド（`INTERNAL_THREAD` に `text::THREAD_*`）、説明（空でなければ）、panic の内容と位置（あれば `INTERNAL_PANIC`）、報告を求める文（`INTERNAL_REPORT`）の順に置き、バックトレースを `backtrace` に入れる。

### 文言

英語の文言は `diag::codes` の型板と `text`、本モジュールの `text` の定数だけを使い、関数の中に英語の文を直接書かない（[実装の規約](../00-common/00-02-conventions.md)の「文言」）。`Stop::Internal` の説明の文字列は、処理系の不具合を調べるためのものであり、そのまま注記に入れる。

## 受け入れテスト

テストは、`bytecode::asm` で原型の名前・由来の種類・位置の表を持つ小さなコンパイル済みプログラムを組み立て、`StopInfo` を手で作って `stop_diagnostic` などを呼び、`Diagnostic` の欄を確かめる。文章の形式への書き出しの確かめは、F16 の単体テストと C12 のゴールデンテストが受け持つ。

- 履歴の段: 利用者の関数 → 標準ライブラリの公開の関数 → 標準ライブラリの補助の関数 → 利用者のラムダの順に呼ばれ、ラムダの中の除算で止まった記録から、履歴が「ラムダ、公開の関数、利用者の関数」の順で補助の関数を含まず、主な位置が除算の命令の位置になる。
- 主な位置の繰り上げ: 止まった命令が標準ライブラリのソースにある場合に、主な位置が内側から見て最初の利用者のソースの呼び出した位置になる。見つからなければなし。
- 名前の形: `UserLambda`・`UserHandleBody`・`UserHandleClause`・`UserLazy` の原型の段が、それぞれ `Lambda`・`Handle`・`Case`・`Lazy` の名前になる。`BuiltinValue` の原型が修飾した名前になる。
- 20 段を超える履歴: 25 段の記録で、内側の 10 段と外側の 10 段が残り、省いた数が 5 である。数えるのは補助の関数を除いた後の段である。
- タスクの起動の履歴: 子のタスクで止まった記録の起動の履歴が、起動した関数の名前と位置、最後に `main` になる。起動した呼び出しが標準ライブラリのソースの中にある場合に、利用者のソースにある最も内側の呼び出しの名前と位置になる。最初のタスクで止まった記録では空である。
- 行き詰まり: 三つの待つタスク（`main` が `TaskGroup` の解放を待ち、二つの子が `Task.await` を待つ）の記録から、主な位置と履歴を持たず、待つタスクの並びが記録の順で、待つ種類と位置が正しい報告になる（02-10 の例の形）。
- コードごと: 10-02 の実行時エラーの表のすべてのコードについて、対応する `Stop` の値から正しいコードと、埋めた値を持つ報告ができる。R0901 の注記の順（枠の数と修正案の後に `TRACE_TAIL_NOTE`）。
- 解放の失敗: `add_release_failures` の注記が `TRACE_TAIL_NOTE` の前に入る。`release_report` の報告の種類が `Release` で、止めた理由の注記を持つ。
- 書き込みの失敗: `write_failed` の報告が主な位置と履歴を持たない。`add_flush_failure` の注記が `TRACE_TAIL_NOTE` の直前に入る。
- 処理系の不具合: `internal_diagnostic` の注記の順と、スレッドの呼び名、バックトレースの欄。`Stop::Internal` の `stop_diagnostic` が処理系の不具合の報告になる。

## 完了条件

- `scripts/check.sh` が通る（R14 の前なら、両方のメモリの管理の機能で）
- 受け入れテストのすべての場合を確かめるテストがある
- 受け持つ関数に `todo!()` の仮置きが残っていない。ファイルに `todo!()` が残っていなければ、仮置きの許可とコメントを消している（00-02「`todo!()` の仮置き」。`runtime/heap/ctx.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が消す）
- 報告を標準エラー出力に直接書く処理が、このモジュールにない
- 関数の中に英語の文を直接書いていない

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「誤りを文字列で表している箇所」と「設計書との対応」の行。
- 履歴の作り方が、02-08「実行時エラーの情報の記録」の手順 1〜4 と一対一で対応しているか。とくに、省く段を数えるのが補助の関数を除いた後か。
- 書き込みの失敗と行き詰まりの報告に、主な位置と履歴を付けていないか。
- 注記の順（`TRACE_TAIL_NOTE` を最後に残す）が、02-10 の例と一致しているか。

## 難易度の理由

最小実行版の報告の組み立てを写せる部分が多いが、タスクの起動の履歴、行き詰まりの報告、原型の由来の種類ごとの名前が加わる。規則の細部（どの段を除くか、どこで数えるか、注記の順）を取り違えると、ゴールデンテストの期待値と食い違う。
