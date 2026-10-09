# R26 送り出しの列と IO 実行器

- 依存する作業: [R25](R25-tasks-and-scheduler.md)、[R39](R39-task-cancellation.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/R26-io-executor

## 目的

組み込みのエフェクトの操作を、二つの IO の方式のどちらでも、一つの送り出しの列を通して行う形にする（ADR 0264）。タスクを待たせてから要求を列に公開し、タスクを待たせる位置と予算を使い切った遅い経路で、列の要求を送り出して完了を取り込む。作業用のスレッドで行う外部の操作は、番号付きの操作の記録で持ち、完了は「返すリソースを戻す → 処理系の不具合を報告する → 配送する」の順に処理する（ADR 0266 の決定 3・4）。

あわせて、第 1 段の一時的な実行の関数（`Vm::run_stage1`・`serve_request_stage1`）を、第 2 段の実行の関数（`Vm::run`・`serve_request`）と実行ごとの状態のランタイムの部分（`IoRuntime`）に置き換え、`runtime::run::run_program` をその上に移してから、第 1 段の形を消す。

作業用のスレッドの実際の実装（スレッドの数の上限、panic、実行ごとの状態を捨てるときの扱い）と、`mio` によるイベントループと `Wakeup` の本物は、本作業の後の [R40](R40-event-loop-and-worker-threads.md) が書く。本作業の `RuntimeParts::real` は、仕事を VM のスレッドでその場で実行する一時的な実装と、何もしない `Wakeup` で作る（後述の「一時的な `RuntimeParts::real` と `Wakeup`」）。本作業のテストは、R25 のテスト用の部品と、本作業が書くテスト用の `WorkerExec` で書く。

## スケジューラとリソースの表の置き場所

10-10 の `IoRuntime` は `scheduler`・`resources` の欄を持たない。二つは `RunState` の欄にある（R20 が置いた。10-09「実行ごとの状態」、10-10「実行ごとの状態と VM のつなぎ目」）。`io` の関数がリソースの表に書けるように、VM は `io` の関数を呼ぶたびに `IoView { rt, resources: &mut state.resources }` を作って渡す（10-10 の `IoView`）。

## 読む設計書の節

- [ランタイム](../../design/02-impl/02-09-runtime.md)の「実行ごとの状態」「組み込みの操作とハンドラ表」「操作の振り分け」「IO 実行器」「タスクの待ちと取り消し」「リソースの追跡」（作業用のスレッドへの貸し出しと、すべてのタスクが終わった後に残る操作の段落）「panic 境界」「プログラムの実行の流れ」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」「タスクの切り替え」（待たせる位置の段落と行き詰まりの段落）「IO の命令」
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「IO の方式のテスト」「順序を与えるスケジューラと仮想の時間（初回リリース版）」「ヒープとランタイムの確かめ方（初回リリース版）」の最後の行
- [スクリプト実行と埋め込み](../../design/02-impl/02-11-embedding.md)の「実行の入力と結果」
- ADR: [0264](../../design/decisions/0264-single-dispatch-queue-for-builtin-operations.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md) の決定 3・4・8・9・11、[0029](../../design/decisions/0029-two-io-execution-modes.md)、[0088](../../design/decisions/0088-keep-both-io-execution-modes.md)、[0274](../../design/decisions/0274-deterministic-scheduler-and-virtual-time-for-tests.md)、[0261](../../design/decisions/0261-typed-builtin-interface.md) の決定 5・6、[0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md)、[0313](../../design/decisions/0313-vm-performance-recovery-before-stage-2.md) の帰結
- 検討資料: [相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 1（要求の送り出しだけ直して完了の取り込みを忘れること、すぐに完了した後に待ちの状態を上書きすることを主な危険とし、要求の送り出しと、計算を続けるタスクがある間に届く完了の両方を確かめるよう求めている）と問い 3（完了の共通の処理は先に返却の欄を処理してから、タスクがまだ結果を待っているかを調べる）。[相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 1・3・4・5・6・7（返却の後の解放の完了を待たずに枠を降ろすこと、記録を除いた後に `site` を失うこと、取り消した要求を後から処理すること、ブロックする解放の仕事の受け渡し、行き詰まりの判定の条件、筋書きを進める境界）

インターフェース:

- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「タスクとスケジューラ」「テストで差し替える部品」（`TaskPicker::spawned` を含む）「送り出しの列と二つの部品」「外部の操作の記録と完了」「リソースの表と状態」「実行ごとの状態と VM のつなぎ目」「完了の処理と行き詰まりの判定の順序」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の「作業用のスレッドの仕事」、`IoWait`・`WorkerWait`・`WorkerDone`・`Lend`・`Lent`・`IoServices`
- [仮想機械](../10-interfaces/10-09-vm.md)の「第 1 段の実行の関数」
- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「実行の流れ」（`RunEnv`・`RunEnd`・`run_program` の終わり方の表）

## 作るもの

- `src/runtime/sched/parts.rs`: 10-10 の `TaskPicker` に、既定の本体を持つ関数 `spawned` を加える（2026-10-06 に 10-10 の `file=` に加えた。既存の関数は変えない。後述の「起動を筋書きに知らせる口」）。`RuntimeParts::real` の一時的な中身（後述）。このファイルの `todo!()` をすべて書き換えるので、仮置きの許可とコメント（00-02）を消す。
- `src/runtime/sched/mod.rs`: 待つ理由を改める補助と、タイマーを加える補助（`pub(crate)`。後述の「待つ理由を改める補助」）。
- `src/runtime/sched/testing.rs`（R25 が置いたもの）: `WorkerExec` のテスト用の実装（筋書きの仕事の実行の指示を読む）、テスト用の `TaskPicker` の `spawned`、テスト用の部品の組を作る公開の関数の仕上げ。
- `src/runtime/io/mod.rs`: `DispatchQueue` の関数（要求の段階と失効を含む）と、二つの部品（`DirectDispatcher`・`RequestDispatcher`）の `on_wait_point`。標準入力の貸し出しの待ちに使う予約の番号の定数（後述の「標準入力の貸し出しの待ち」）。
- `src/runtime/io/ops.rs`: `OpTable` の関数と `accept_completion`。
- `src/runtime/io/event.rs`: `mio` を使わない形の `Wakeup`（何もしない）と、それを作る `pub(crate)` の関数（後述の「一時的な `RuntimeParts::real` と `Wakeup`」）。イベントループの本体と `mio` の `Wakeup` は R40 が書く。
- `src/runtime/io/services.rs`: `IoRuntime::new`、`IoServices for IoView<'_>`（`IoView` は C02 が `file=` で置いた）、`Vm::run`・`Vm::serve_request`、`IoRuntime` に加える欄（後述）。VM の内部に触れる補助は `vm` のモジュールに `pub(crate)` で置いてよい（10-10「実行ごとの状態と VM のつなぎ目」）。
- `src/runtime/io/output.rs`: R27 が書き出し用のスレッドの中身を書くまでの、一時的な `OutputPort` の中身（後述）。
- `src/runtime/run.rs`: `run_program` を `IoRuntime` と `Vm::run` の上に移す。`RunEnv::parts` と `StdinSource` を使う。第 1 段の `IoServices` を包む型（`StageIo`・`PanicIo`）を消す。
- `src/vm/dispatch.rs`・`src/vm/dispatch/tasks.rs`・`src/vm/state.rs`（R20・R25 が置いたもの）: `IO` の命令の要求の公開、`run_epoch` の引数の置き換え、待たせる位置と遅い経路の順序の関数への手順 1・2 の追加、第 1 段の要求（`RunState::pending`・`Stage1Request`、`dispatch::serve` の第 1 段の経路）の削除、`Scheduling` の `picker`・`clock`・`script` の欄の削除（`IoRuntime::parts` へ移す）。
- `src/vm/dispatch/tasks/cancel.rs`（R39 が置いたもの）: 取り消しの手順に、要求の失効、記録の配送の取り外し、標準入力の待ちの並びからの除去を足す（後述の「取り消しと止める手順で行うこと」）。
- `src/vm/stage1.rs`: 第 1 段の実行の関数を消す（後述）。`use_schedule` は `vm` の中のテスト用の場所へ移す。
- VM の単体テストのうち `run_stage1` を使っていたものを、`Vm::run` に移す（後述の「既存のテストの手直し」）。
- 上のファイルのテスト。

R20・R25・R39 が置いた `dispatch.rs`・`tasks.rs`・`state.rs`・`cancel.rs` の上の箇所は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。

### 第 1 段の形の消し方

10-09 の `vm/mod.rs` は C01 の `file=` であり、`pub mod stage1;` を宣言している。宣言を消すと凍結したファイルを変えることになるので、`src/vm/stage1.rs` は、中身の関数（`run_stage1`・`serve_request_stage1`）と、それだけが使っていた補助を消し、`//!` のコメントだけを残したモジュールにする。コメントには、R26 が第 2 段の実行の関数に置き換えたことと、宣言の行とファイルは U1・U2 を終えた後に消すこと（90-after-completion の「移行の締めの残り」）を書く（10-09「第 1 段の実行の関数」）。

今 `stage1.rs` の末尾にある `Vm::use_schedule`（R25 がテストの部品を差し替えるために置いた `pub(crate)` の関数）は、`stage1.rs` を `//!` だけにすると置き場がなくなる。役割（テスト用の部品の組を VM の実行に渡すこと）は後述の「起動を筋書きに知らせる口」で `IoRuntime::parts` に移るので、残す補助は `vm` の中の `#[cfg(test)]` の場所（例 `vm/dispatch/tasks.rs` の `#[cfg(test)]` の関数か、`vm` の下に新しく宣言する `#[cfg(test)]` の子のモジュール `vm/test_support.rs`）へ移す。子のモジュールを加えるときは、`vm/dispatch.rs` のように作業が受け持つファイルの中で宣言する（`vm/mod.rs` は凍結している）。

### 一時的な `OutputPort`

`IoServices::write_output` は `OutputPort` に書く。`OutputPort` の中身と、容量の待ち・完了の待ちは R27 が書くが、本作業で `run_program` を移すと、出力が動かなければ既存のテストが通らない。そこで本作業は、出力先を持つ最小の書き出し用のスレッドで一時的な中身を書く。凍結した `OutputPort` の欄には出力先を置く欄がない（出力先は `start` の引数で受け取る）ので、出力先は `start` が起こすスレッドへ移す。

- `start`: `WriterShared` を作り、出力先を持つ書き出し用のスレッドを起こして `thread` に入れる。スレッドは、`WriterState::queue` にかたまりがあれば取り出して出力先に書いて flush し、`done_seq` を進める。書き出しに失敗したら `failure` に `WriteFailure::Io` を記録し、以後のかたまりは捨てる。`queue` が空で `shutdown` が立っていれば終わる。待つときは `WriterShared::cond` を使う。
- `write`: `failure` が記録されていればそれを返す。そうでなければ `buf` に加えて `Accept::Accepted` を返す。転送していない量の上限での預け（`Deferred`）は R27 が書く。
- `request_transfer`: `buf` が空でなければ、中身を `shared` の `queue` へ移し、`sent_seq` を進めて `cond` で知らせる。
- `flush_target`・`poll`: 知らせが来たら空の結果を返す（`flush_target` は `sent_seq` を返して待ちを登録せず、`poll` は空の並びと記録された失敗を返す）。本作業では `AwaitFlush` の段階を通らない（後述の「仕事を出す手順」）ので、待つタスクはできない。
- `cancel_pending`: 預けた書き込みと完了の待ちがないので、何もしない。
- `finish`: `request_transfer` を行い、`shutdown` を立てて知らせ、スレッドを `join` して、記録された失敗を返す。スレッドの panic は `WriteFailure::Panicked` にする。

本作業の時点では、手順 4（待ち行列が空のときの `request_transfer`）を順序の関数に足すのは R27 である。そこで、本作業の `write` は、`buf` が `TRANSFER_THRESHOLD` 以上になったときに `request_transfer` を行う（第 1 段の出力のバッファの閾値と同じ扱い）。`run_program` は、終わり方を決めた後に標準出力、標準エラー出力の順に `finish` を呼び、失敗を第 1 段と同じく終わり方の報告に加える（今の `flush_failure` の規則）。R27 が、同じシグネチャのまま、容量の待ち・完了の待ち・転送の時点の表のとおりの中身に置き換える。

### 一時的な `RuntimeParts::real` と `Wakeup`

`RuntimeParts::real(wakeup)` は、R25 の `FifoPicker` と `RealClock`、本作業が書く一時的な `WorkerExec` の組を返す。一時的な `WorkerExec` は次のとおりとする。作業用のスレッドを使う本物は R40 が書く。

- `submit`: 仕事を VM のスレッドでその場で実行し、完了を `try_recv` が返す列に置く。貸したものの持ち方と `catch_unwind` の扱いは、後述のテスト用の実装と同じ関数を使う（第 1 段の「作業用のスレッドの仕事はその場で実行する」形を、完了の取り込みの経路に乗せたもの）。
- `try_recv`: 列の先頭の完了を返す。
- `idle(deadline)`: 列に完了があればすぐ `Progress` を返す。なければ期限まで `std::thread::sleep` で眠って `Progress` を返す（R25 の一時的な待ちを移したもの）。期限がなければすぐ `Progress` を返す。中断の要求は R28 が扱う。

`Wakeup` は、`mio` を使わない形だけを本作業で置く。`WakeupInner` の欄に、何もしない形を表すもの（例 `enum` の一つの分岐。R40 が `mio::Waker` を持つ分岐を加える）を置き、`Wakeup::wake` はその形では何もしない。`Wakeup` を作る `pub(crate)` の関数（例 `event::wakeup_without_poll()`）を `event.rs` に置き、`run_program` とテストが使う。R40 は、同じ関数をテスト用の部品と Miri で動かすテストのために残す。

## 手順の要点

### IO の命令と送り出しの列（ADR 0264 の決定 1〜3）

`IO A B C` で処理する言語のハンドラがなければ（ハンドラの探索は R20）、VM は次の順に行う。

1. 実行中のタスクを `Scheduler::park(task, WaitReason::Response)` で待たせる（呼ぶ前に R25 の `check_park` で確かめる）。命令の位置は待っている `IO` の命令を指したままにする（後述の「回収の前の整理（ADR 0314）」）。
2. `DispatchQueue::publish(task, op, site)` で要求を列に公開する。`op` は `builtin_decl(BuiltinId)` で引いた登録の項目である（テストでは後述の「偽の組み込みの関数の差し替え」）。待たせてから公開する順は、すぐに完了する操作でも守る（ADR 0264 の決定 2）。
3. 待たせる位置の処理（10-10「完了の処理と行き詰まりの判定の順序」の関数）に進む。

`Response` は、要求を出してから処理が決まるまでの待ちである。直接呼び出しの方式でも、要求を処理するまではこの理由で待つ。

### 要求の処理（`serve`）

直接呼び出しの方式では `on_wait_point` が返した `ServeNow` の番号ごとに、要求と応答の方式では外側の実行器が `Vm::serve_request` を呼んだときに、同じ処理を行う。要求と呼び出しの命令を持つ場所は、10-10「送り出しの列と二つの部品」の段階の表のとおりである。

1. `DispatchQueue::take_for_serve(番号)` で要求を除く。`None`（取り消しか止める手順で失効した、または別の段階にある）なら何もしない。要求のタスクが番号の世代のまま `WaitReason::Response` で待っていなければ、`Stop::Internal` とする（失効させずに待ちを外す経路は作業の誤りである）。
2. 要求の `site` の命令を `CompiledProgram::builtin_call_operands` に渡し、引数のレジスタと結果のレジスタを求める。引数は待っているタスクの枠のレジスタから読む。
3. 組み込みの関数の `raw` を、`IoServices` として `IoView { rt, resources: &mut state.resources }` を渡した文脈で呼ぶ。`CallCtx` の状態のサービスは `None` のままでよい（権限が `Io` の関数は `StateServices` を使わない。10-11）。応答で分ける。
   - `Done(v)`: 結果のレジスタに入れ、命令の位置を次へ進めて、タスクを起こす（後述の「回収の前の整理」の一続きの書き込み）。
   - `Wait(Worker(w))`: 後述の「仕事を出す手順」に進む。
   - `Wait(Sleep { millis })`: タイマーを登録し、タスクの待つ理由を `Response` から `Timer(番号)` に改める（後述の「待つ理由を改める補助」）。満了で起きたら、結果のレジスタに `()` を入れて命令の位置を次へ進める。
   - `Wait(Output { .. })`: R27 が中身を書く。本作業の一時的な `OutputPort` では起きない。
   - `Wait(Readiness { .. })`: U2 には、イベントループの準備を待つ組み込みの関数がない（HTTP は U3）。本作業では `Stop::Internal` を返す形で置き、U3 がイベントループの登録を使う形に書く。
   - `Exit(状態)`: 止める手順を `StopReason::Exit` で始める（止める手順のランタイムの部分は R28）。
   - `Err(Stop)`: 要求を出したタスクの `site` の命令で止まったものとして、止める手順を始める。

### 仕事を出す手順

応答が作業用のスレッドの仕事（`WorkerWait`）のときは、次の順に行う。途中で待つときは、要求と仕事を段階付きで `DispatchQueue::park_request` に戻し、待ちが解けたら `take_task_request` で取り出して、待った手順の続きから行う。組み込みの関数は呼び直さない。

1. `w.needs_output_flush()` が真で、まだ出力の転送の完了を待っていなければ、段階 `AwaitFlush(w)` で要求を戻し、タスクを `WaitReason::Output(stream, Flush)` で待たせる（R27 が中身を書く）。本作業では、この段階を通らずに手順 2 へ進む。
2. `w.lend()` に従って貸すものを取り出す。
   - `Lend::Resource(番号)`: R24 の `check_lend` で番号と項目を確かめ、食い違いを `Stop::Internal` で返す（10-10「リソースの表と状態」）。続けて `Scheduler::new_ext_op_id` で操作の番号を取り、`RunState::resources` の表の `ResourceTable::lend(番号, 操作の番号, タスク)` を呼ぶ（`lend` は操作の番号を先に要る）。`MustWait` なら、取った操作の番号は捨ててよく（番号は使い回さないだけで、欠けてもよい）、段階 `AwaitLend(リソース, w)` で要求を戻し、タスクの待つ理由を `WaitReason::Lend(リソース)` に改める。`Released(種類)` なら、`site` の命令で `ReleasedResourceUsed` の実行時エラーとする。
   - `Lend::Stdin`: 後述の「標準入力の貸し出しの待ち」。
3. 貸せたら、手順 2 で取った操作の番号（`Lend::Nothing` と `Lend::Stdin` はここで取る）で `OpRecord { kind: Worker, deliver_to: Some(task), lent, site }` を記録し、`WorkerJob { work: JobWork::Builtin(w), .. }` を `WorkerExec::submit` で出し、タスクの待つ理由を `WaitReason::Worker(番号)` に改める。要求はここで `live` から離れ、呼び出しの命令は記録の `site` が持つ。

### 標準入力の貸し出しの待ち

凍結した `WaitReason::Lend(ResourceId)` と `RequestPhase::AwaitLend(ResourceId, ..)` には、標準入力を表す形がない。標準入力はリソースの表に載らないので、次のように扱う。

- 予約の番号 `ResourceId(u64::MAX)` を、標準入力の貸し出しの待ちを表す定数（例 `runtime::io::STDIN_LEND`）として `src/runtime/io/mod.rs` の一か所に置く。リソースの表には載せない（表の番号は 0 から `wrapping_add(1)` で進むので、一実行で `u64::MAX` に届かない。R24 の計数の理由と同じ）。`check_lend` と `lend` にはこの番号を渡さない。
- `IoRuntime` に、標準入力を待つタスクの並び（例 `stdin_waiters: VecDeque<TaskId>`。呼んだ順）を加える。
- `Lend::Stdin` で `IoRuntime::stdin` が `Some` なら取り出して貸す。`None`（別のタスクの仕事が借りている）なら、タスクを並びの末尾に加え、段階 `AwaitLend(STDIN_LEND, w)` で要求を戻し、タスクの待つ理由を `WaitReason::Lend(STDIN_LEND)` に改める。
- 完了で読み手が戻ったら（`accept_completion` が `stdin` の置き場に戻す）、並びの先頭から `WaitReason::Lend(STDIN_LEND)` で待つタスクを取り出し、その要求を `take_task_request` で取り出して上の手順 2 からやり直す。待っていないタスク（取り消しで除き忘れた場合も含む）は捨てて次を取り出す。`Accepted` には標準入力の返却を表す分岐がないので、VM は `accept_completion` の後に `stdin` が `Some` で並びが空でないかを調べて、やり直しを行う。

これで、二つのタスクが同時に標準入力を読むときに、操作を呼んだ順に一つずつ行う（02-09「IO 実行器」）。10-10 の「リソースの表と状態」の本文にも、予約の番号を使うことを一文で書いた。

### 待つ理由を改める補助

要求を出したタスクは、まず `Response` で待ち、要求の処理の結果に従って `Timer`・`Lend`・`Worker`（R27 で `Output`）の待ちに移る。R25 の `check_park` は二度待たせることを拒むので、`park` を呼び直さずに待つ理由を改める補助を `src/runtime/sched/mod.rs` に `pub(crate)` で加えてよい（例 `Scheduler::repark(task, from, to) -> Result<(), Stop>`。今 `from` で待っていなければ `Stop::Internal`）。タイマーを加える補助（例 `Scheduler::add_timer(deadline, timer, task)`）も同じく加えてよい。

R39 は、`Task.withTimeout` の期限のタイマーを `Scheduler::timers` に直接加え（`tasks.rs`）、`tasks/cancel.rs` の非公開の関数 `remove_timer` で外している。本作業で `add_timer` を加えるときは、R39 の直接の挿入をこの補助に置き換えてもよいが、必須ではない。`Scheduler` に除く補助を加えるときは、R39 の `remove_timer` と名前と意味が食い違わないようにする。

### 起動を筋書きに知らせる口

R25 は、起動の通し番号と `TaskId` の対応を筋書きに知らせるために、`RunState::scheduling.script`（`ScheduleHandle`）を仮の口として置き、起動のたびに `register_spawn` を呼んでいる。本作業は、これを凍結した部品の口に置き換える。

- 10-10 の `file=` の `TaskPicker` に、既定の本体を持つ関数を加えた（2026-10-06）。

  ```rust
  /// タスクを起動したことを知らせる（`serial` は起動の通し番号。メインのタスクは 0）。
  /// テスト用の実装が、筋書きの起動の通し番号で選ぶ指示を引くために使う。既定は何もしない。
  fn spawned(&mut self, _serial: u64, _task: TaskId) {}
  ```

  既存の関数は変えない。引数名の頭の `_` は、既定の本体で引数を使わないことへの `unused_variables` を避けるためであり、実装する側の引数名は自由である。
- VM は、タスクを起動するたびに `rt.parts.picker.spawned(通し番号, 番号)` を呼ぶ。メインのタスクは、`Vm::run` が初めて実行を始めるときに `spawned(0, メインのタスク)` を知らせる（R25 の `use_schedule` が `register_spawn(0, main)` を呼んでいた扱いを引き継ぐ）。
- テスト用の `TaskPicker`（`sched/testing.rs` の `ScriptPicker`）は、`spawned` で共有の状態の `register_spawn` を呼ぶ。
- `RunState::scheduling` の `picker`・`clock`・`script` の欄は消し、切り替えでは `rt.parts.picker`、時計は `rt.parts.clock` を使う。R25 の順序の関数が呼んでいた `script.advance_time()` などの筋書きの一時的な呼び出しは、テスト用の `WorkerExec::try_recv` と `idle` に移す（後述）。

R25 の作業文書の「テスト用の部品」の起動の通し番号で選ぶ指示の箇条は、この形に合わせて改めてある。

### 偽の組み込みの関数の差し替え

受け入れテストの一部は、副作用を記録する偽の組み込みの関数、偽の資源を貸す仕事を返す組み込みの関数、標準入力を借りる偽の組み込みの関数を、スクリプトの `IO` の命令から呼ぶ必要がある。組み込みの関数は大域の表から `builtin_decl(BuiltinId)` で引くので、テストの偽の関数を表に加える経路はない。そこで次のようにする。

- `IoRuntime` に `#[cfg(test)]` の欄として、`BuiltinId` から `&'static BuiltinDecl` への差し替えの表（例 `builtin_overrides: BTreeMap<BuiltinId, &'static BuiltinDecl>`）を置く。`IoRuntime::new` は空にし、テストが作った後に入れる。
- VM は、要求を公開するとき（上の「IO の命令と送り出しの列」の手順 2。冷たい経路）に、この表に番号があれば差し替えた項目を `Request::op` に入れる。普通の経路と `PRIM` の経路には手を入れない。
- テストのスクリプトは、引数と結果の型が合う既存の `Io` の権限の組み込みの関数（例 `File.readText`）を呼び、テストはその番号を偽の項目に差し替える。偽の項目はテストのモジュールの `static` に置く。
- 偽の資源を貸す仕事の `Lend::Resource(番号)` の番号は、テストの補助で最初にリソースの表に登録した番号（`ResourceTable::insert` の最初の番号 `ResourceId(0)`）に決めておく。

### 取り消しと止める手順で行うこと

要求を出したタスクを取り消したときと止める手順を始めたときは、外部の操作に移る前の要求を `expire_task`・`expire_all` で失効させ、応答の仕事を捨てる（相談の第 7 回の指摘 4、[ADR 0282](../../design/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。失効した要求は、後から処理を求められても（要求と応答の方式で外側の実行器が遅れて `serve_request` を呼ぶ、返却で返却を待つ並びが進む）何もしない。

取り消したタスクの外部の操作の記録は、R39 の取り消しの手順（`tasks/cancel.rs`）に `OpTable::detach_task` を足して、配送だけを外す。記録は完了するまで消さない（ADR 0266 の決定 3）。同じ手順に、`DispatchQueue::expire_task` と、標準入力を待つタスクの並びからの除去を足す。止める手順の始め（R25 の `begin_stop_all`）には `expire_all` と、並びを空にすることを足す。すべてのタスクが終わった後に残る外部の操作は待たない（同 決定 11）。

R39 の取り消しの手順と R25 の止める手順は `RunState` だけを受け取り、`IoRuntime` を受け取らない。次のどちらかで行う。どちらにしたかを完了の報告の「判断したこと」に書く。

- 取り消しと止める手順の関数に `IoRuntime` を渡す。
- `RunState` に、取り消したタスクの並びと「止める手順を始めた」の印を記録し、`IoRuntime` に触れる処理（`expire_task`・`expire_all`・`detach_task`・並びからの除去）を、順序の関数の手順 1 の前、`ServeNow` の番号ごとの処理の前、`Vm::serve_request` の頭でまとめて行う。要求を処理するのはこの三か所だけなので、記録を反映する前に失効すべき要求が処理されることはない。配送は `wake_if` で待ちを照らすので、`detach_task` が遅れても取り消したタスクに結果は渡らない。

### 二つの部品（ADR 0264 の決定 4）

- `DirectDispatcher::on_wait_point`: 列の要求の番号をすべて `ServeNow` で返す。VM は番号ごとに上の「要求の処理」を行う。途中の要求で止める手順が始まったら、残りの番号は失効しているので処理されない。
- `RequestDispatcher::on_wait_point`: 列に要求があれば、段階を `Outstanding` にして `ReturnToExecutor` で返す。列が空でも、段階が `Outstanding` の要求があり（`has_outstanding`）、呼ばれた位置が `WaitPoint::SlowPath` なら、空の `ReturnToExecutor` を返す（外側の実行器が届いた応答を渡せるようにする）。
- VM は `ReturnToExecutor(ids)` を受けたら、局所の状態を書き戻して `VmStep::Requests(ids)` を返す。進められるタスクが残っていても戻る（OPEN-062 の R02）。

### 待たせる位置と遅い経路の順序（10-10「完了の処理と行き詰まりの判定の順序」）

R25 が作った関数（`tasks.rs` の `boundary` と `switch_inner`）に、手順 1（`on_wait_point` と、ブロックする解放の仕事を出すこと）と手順 2（`WorkerExec::try_recv` で届いた完了をすべて取り込み、`accept_completion` で処理し、`Accepted` を順に処理する）を足す。手順 6 の待ちは、`WorkerExec::idle(次のタイマーの期限)` で行い、R25 の一時的な待ち（`std::thread::sleep` と筋書きの時間を進める呼び出し）を置き換える。`idle` が `ScriptExhausted` を返したら `Stop::Internal` とする。R25 が手順 2 の位置に置いた筋書きの一時的な呼び出しは、テスト用の `WorkerExec::try_recv` に移す（10-10「テストで差し替える部品」の筋書きを進める境界）。予算を使い切った遅い経路の手順 2 でも、同じく手順 1・2 を行う（`WaitPoint::SlowPath`）。予算が残っているときの速い経路は、この二か所を飛ばすが、要求を置いたタスクは必ず待つので、待たせる位置を通る（ADR 0264 の決定 5）。

手順 3 には、R39 が `Scheduler::expire_timers` の結果を `SpawnWait::timer` と照らす処理を足している（R39「タイマーの満了」。`boundary` が `NoGcCtx` を受け取る形）。本作業の置き換えでこの照合を消さない。

行き詰まりの判定（手順 5。R25 が作った）には、条件を足さない。外部の操作の記録と生きている要求は、それを待つタスクの待つ理由（`Worker`・`Readiness`・`Response`・`Lend`・`Output`）で数えられ、配送先を外した記録は数えない（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）。本作業は、外部の完了で起きるタスクを、必ず 10-10 の段階の表の「待つタスクの理由」で待たせる。標準入力の待ちも `WaitReason::Lend(STDIN_LEND)` で数えられる。

止める手順の途中も同じ関数を通り、手順 1〜3 で完了を取り込み続ける。返却を待って解放する枠と、ブロックする解放の完了を待つ枠があるからである。止める手順を始めるときに `expire_all` で生きている要求を失効させ、手順 5 では元の停止の理由を置き換えない。

### 完了の処理（ADR 0266 の決定 4、10-10 の `accept_completion`）

`accept_completion` は次の順に行い、VM が行うことを `Accepted` で返す。引数の `resources` には `RunState::resources` を渡す。個々の組み込みの関数には任せない。

1. 記録を表から除き、欄（種類、`deliver_to`、`site`）を取り出しておく。
2. `returned` を戻す。`LentOwned::Resource(番号, 資源)` は `ResourceTable::give_back` で戻し、`false` なら `Returned(番号)`、`true`（閉じる要求がある）なら `StartRelease(番号)` を加える。`LentOwned::Stdin(読み手)` は `stdin` の置き場に戻す。
3. 種類が `Release(番号)` なら、`outcome` の `Released(結果)` を `finish_release` で記録して `ReleaseFinished(番号)` を加える。`Panicked` なら失敗を記録せずに `finish_release(番号, Ok(()))` で `Released` にし、`ReleaseFinished(番号)` を加える。
4. `outcome` が `Panicked` なら、タスクが待っているかによらず `Bug(報告)` を加える。
5. そうでなければ、種類が `Worker` か `Readiness` の記録について、`deliver_to` があれば `Deliver { task, op, site, outcome }`、なければ `Dropped`（値と失敗だけを捨てる）を加える。

VM は `Accepted` を順に処理する（10-10「外部の操作の記録と完了」）。

- `Returned(番号)`: `pop_waiter` で返却を待つ並びの先頭のタスクを取り出し、そのタスクが `WaitReason::Lend(番号)` で待っていれば、`take_task_request` で要求（段階 `AwaitLend`）を取り出して、上の「仕事を出す手順」の手順 2 からやり直す。待っていなければ（取り消しで除き忘れた場合も含む）次のタスクを取り出す。
- `StartRelease(番号)`: `check_release` で確かめてから、`Scheduler::new_ext_op_id` の番号で `request_release` を呼ぶ。`Done(結果)` なら `finish_release` で記録して `ReleaseFinished` と同じく扱う。`Blocking` なら、次の手順 1 で仕事を出す。
- `ReleaseFinished(番号)`: `wake_all(WaitReason::Release(番号))` で解放を待つタスクを起こす。返却を待つ並びに残るタスクの要求も貸し出しからやり直し、「解放したリソースの使用」にする（10-10 の遷移の表の「操作の待ち × `Released`」）。
- `Bug`: panic 境界の処理（処理系の不具合、スレッドは作業用のスレッド）に移る。
- `Deliver { task, op, site, outcome }`: `task` が `WaitReason::Worker(op)` か `Readiness(op)` で待っていなければ、結果を捨てる。待っていれば、`site` から引数を読み直して `WorkerDone::complete` を呼び、結果の値を結果のレジスタに入れ、命令の位置を次へ進めて `wake_if` で起こす。`complete` が `Err(Stop)` を返したら、そのタスクの `site` の命令で止まったものとして止める手順を始める。

### ブロックする解放の仕事の受け渡し（相談の第 7 回の指摘 5）

R24 の `request_release` は、ブロックする解放で OS の資源を項目に残し、番号を `ResourceTable::release_jobs` に加える。本作業は、10-10「完了の処理と行き詰まりの判定の順序」の手順 1 の後に、`take_release_job` が返すものをすべて、種類 `Release(番号)` の記録（`deliver_to`・`lent`・`site` は `None`）として `OpTable` に加え、`WorkerJob { op, work: JobWork::Release(資源), lent: LentOwned::Nothing }` を `WorkerExec::submit` で出す。仕事を実行する側（本作業のテスト用の実装と一時的な実装、R40 の作業用のスレッド）は `OsResource::release` を呼び、結果を `Outcome::Released` にして送る（panic なら `Panicked`）。解放を待つタスクは、完了の `ReleaseFinished` で起き、解放の枠が `take_release_failure` で失敗を読む（R24）。この受け渡しは、解放の枠（R24）、`StateServices::begin_release`（R25）、返却の後の解放（上の `StartRelease`）のどれから始めた解放にも使う。

### `WorkerExec` のテスト用の実装（ADR 0274 の決定 1）

`submit` は仕事を預かるだけにする。筋書きの「仕事を実行する」の指示で、預かった仕事を VM のスレッドでその場で実行し、完了を `try_recv` が返す列に置く。実行するときは、`WorkerJob::lent` を `catch_unwind` の外で持ち、そこから借りた `Lent` を仕事に渡して `WorkerWait::run` を `catch_unwind` で囲んで呼ぶ（ADR 0266 の決定 9）。`JobWork::Release(資源)` は、`OsResource::release` を `catch_unwind` で囲んで呼ぶ。panic したら、panic の記録（02-09「panic 境界」のスレッドローカルな記録を取り出したもの）を `Outcome::Panicked` にし、貸したものを `returned` に入れる。この実行の関数は、本作業の一時的な `RuntimeParts::real` と共有し、R40 の作業用のスレッドも使えるように、`WorkerExec` の実装から独立した関数にしておく。

筋書きは R25 が決めた型を使う。指示を行う境界は、10-10「テストで差し替える部品」のとおり、完了の取り込み（`try_recv`）と `idle` に限る。`try_recv` は、筋書きの先頭から次のタスクを選ぶ指示の前までの「時間を進める」「仕事を実行する」の指示を行ってから、届いた完了を返す。予算を使い切った遅い経路でも `try_recv` を通るので、「タスク B が計算を続けている間に完了が届く」「取り消しの後に完了が届く」順序を筋書きの位置だけで決まった形で作れる。R25 が手順 2 の位置に置いた一時的な呼び出しは、ここへ移して消す。

### `run_program` の移し方

- `RunEnv` から `IoRuntime` を作る。`StdinSource::Process` はプロセスの標準入力をバッファ付きで読む読み手、`Empty` は空の読み手、`Bytes` は与えたバイト列の読み手にする。出力先は `OutputPort::start` で作る（`OutputTarget::Stdout`・`Stderr`・`Capture` のどの組み合わせも受け付ける。第 1 段の「出力先の混在は処理系の不具合」の制約はなくなる）。`Wakeup` は上の `pub(crate)` の関数で作る。部品は `RunEnv::parts` があればそれを、なければ `RuntimeParts::real` を使う。中断の読み口は `RunEnv::interrupt` を使う。
- `Vm::run` を呼び、`VmStep::Requests(ids)` なら要求ごとに `Vm::serve_request` を呼んでから `Vm::run` を呼び直す。`Finished` か `Stopped` になるまで繰り返す。
- VM の実行を `runtime::panic::catch` で囲む。終わり方から `RunEnd` を作る規則（10-13「実行の流れ」の表）は、F18 が第 1 段の実行の関数で書いたもの（`step_end`）を引き継ぐ。出力の最後の転送は上の一時的な `OutputPort::finish` で行い、R27 が仕上げる。
- `RunEnv::dev_panic_after_first_write` は、`IoRuntime` に加える欄（例 `dev_panic_after_first_write: bool`）に写し、`IoView::write_output` が最初の書き込みをバッファに加えた直後に Rust の panic を起こす。`#[allow(clippy::panic)]` は理由のコメントを付けてこの箇所だけに書く（[実装の規約](../00-common/00-02-conventions.md)の `#[allow]` の表の「IO 実行器、`src/runtime/run.rs` の第 1 段の IoServices を包む型（R26 が IO 実行器へ移す）の `BENITOITE_DEV_PANIC` の処理」）。今の `run.rs` の `PanicIo` は消す。
- `RuntimeParts::real` の `Clock` は、R25 の実際の実装を使う。

### 回収の前の整理と `IO` の命令の位置（ADR 0314）

第 1 段の要求と応答の方式では、`IO` は待つ前に命令の位置を次へ進める（R09 の実装）。第 1 段は要求を待つ間に回収しないので問題にならなかった。本作業が待つ間に回収を加えると、回収の前の整理（[ADR 0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md) の決定 3）が、`serve` と完了の処理が読み直す引数を、命令の位置の次の命令の入口の集合に従って空にしてしまう。待つ枠の命令の位置は待っている `IO` の命令を指すようにし（完了で結果を書き、続けて次へ進める）、その状態を「命令の入口」として扱う。完了の書き込みと位置の更新は、回収を挟まずに一続きに行う（R25 の同じ節）。

R21・R25 と同じく、本作業が加える状態を決定 5 の「命令の入口」と「結果が書かれる前の呼び出し元」のどちらかに分類する表を完了の報告に書き、分類どおりに空にする。少なくとも次の状態を表に入れる。

| 状態 | 待つ理由 | 分類 |
|---|---|---|
| 要求が列にある（段階 `Queued`）・外側の応答を待つ（段階 `Outstanding`） | `Response` | 「命令の入口」（`pc` は `IO`。引数は `IO` の入口の集合に入るので残る） |
| 返却を待つ（段階 `AwaitLend`。標準入力の待ちを含む） | `Lend` | 「命令の入口」 |
| 出力の転送の完了を待つ（段階 `AwaitFlush`。R27） | `Output` | 「命令の入口」 |
| 作業用のスレッドの仕事を待つ | `Worker` | 「命令の入口」。完了の処理は引数を枠から読み直す |
| `Sleep` のタイマーを待つ | `Timer` | 「命令の入口」。満了の `()` の書き込みと位置の更新を一続きに行う |
| `Deliver` で結果を書いた直後 | なし（起こした） | 結果の書き込みと位置の更新を回収を挟まずに行うので、回収が見るのは次の命令の「命令の入口」だけである |

分類を確かめていない状態は、空にしない。受け入れテストの「根の置き場ごとの回収の強制」で、待つ間と完了の直後に回収が起きても、引数と結果が残ることを確かめる。

### 凍結した戻り値で処理系の不具合を扱う方法

R24・R25 と同じく（R24「凍結した戻り値で処理系の不具合を扱う方法」）、次の関数の戻り値は凍結しており（10-10 の `sig=`）、処理系の不具合を表せない。シグネチャは変えずに、次のように扱う。

- `OpTable::insert -> ()`（同じ番号の記録がある）と `DispatchQueue::park_request -> ()`（同じ番号の要求が `live` にある、同じタスクに別の生きている要求がある）: 非公開の確かめの関数（例 `OpTable::check_insert`・`DispatchQueue::check_park_request`。名前は作業が決める）を加え、VM は呼ぶ前に確かめて、食い違いを `Stop::Internal` で返す。凍結した関数の中では、確かめを通った入力を前提にし、到達しないはずの分岐は `debug_assert!` で不具合を示したうえで、状態を変えない。到達しない理由をコメントに書く。
- `DispatchQueue::take_task_request -> Option<LiveRequest>`: VM が `Lend`・`Output` の待ちを解いて要求を取り出すとき、`None` か、段階が待った理由と合わない要求（例 `Lend` で待つのに段階が `AwaitLend` でない）は `Stop::Internal` とする。`wake_if` で待ちを照らしてから取り出すので、`Lend` で待つタスクには必ず段階 `AwaitLend` の要求がある。
- `DispatchQueue::take_for_serve -> Option<Request>`: `None` は失効の正常な結果なので何もしない（上の「要求の処理」）。
- `accept_completion -> Vec<Accepted>`: 記録のない完了（記録は完了でしか除かないので起きないはずである）と、`give_back` の食い違い（返すリソースが表で `Lent` でない、記録の `lent` と `returned` の番号が違う）は、結果で表せない。VM は `accept_completion` を呼ぶ前に、非公開の確かめの関数（例 `check_completion(&ops, &resources, &completion)`）で、記録があることと、`returned` が記録の `lent` と一致し表の項目が `Lent` であることを確かめ、食い違いを `Stop::Internal` で返す。`accept_completion` の中では、確かめを通った入力を前提にし、到達しない分岐は `debug_assert!` で示して状態を変えない（`give_back` の中の分岐と同じ扱い）。
- `ExtOpId` の計数は R24 が `wrapping_add` で書いた。本作業は番号を使い回さないことだけを前提にする。

### 性能

普通の経路（`CALL`・`TAILCALL`・`RETURN` の速い経路、`PRIM` の純粋な関数の経路、`execute` のループの頭）に処理を足さない。`IO` の命令の要求の公開、要求の処理、仕事を出す手順、完了の処理、順序の関数の手順 1・2 の本体は、`dispatch/tasks.rs` か `runtime::io` の冷たい関数（`#[cold]`・`#[inline(never)]`）に置く（R21・R22・R25 の形）。

`run_epoch`（`dispatch.rs`）の引数は、今の `services: &mut dyn IoServices` と `mode: ExecMode` を `rt: &mut IoRuntime` に置き換えるだけにする。方式の違いは `IoRuntime::dispatcher` の中にあるので、`run_until_exit` に方式の分岐を残さない。`run_until_exit` の頭で退避するレジスタとスタックの量を増やさない（引数の数を増やさない、普通の経路で `rt` の欄を読まない）。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（R40 の後と最後に、オーケストレータが行う）。

本測定の道具（`examples/stage1_bench.rs` と `tools/bench/`）は変えない。`stage1_bench` は `run::run_program` を `RunEnv { parts: None, mode: Direct, .. }` で呼んでおり、公開の形は凍結しているので、本作業の後も同じ呼び方で動く。release で `stage1_bench` が fib と loop を走らせて `run_nanos` を出すことを確かめる。

### 既存のテストの手直し

`run_stage1`・`serve_request_stage1` を呼ぶテストは、次のファイルにある（2026-10-06 の `san_benito`）。どれも本作業が第 1 段の実行の関数を消すために手直しする対象であり、00-03 の「ほかの作業のファイル」には当たらない。

- `src/vm/tests.rs`、`src/vm/verification_tests.rs`
- `src/vm/dispatch.rs`・`src/vm/dispatch/collections.rs`・`src/vm/dispatch/numeric.rs` の `#[cfg(test)]` のモジュール
- `src/vm/dispatch/cell/tests.rs`・`handlers/tests.rs`・`lazy/tests.rs`・`resource/tests.rs`・`tasks/tests.rs`・`traits/tests.rs`
- `src/bytecode/codegen/tests.rs`
- `src/runtime/run.rs` のテスト

次の手直しは、止まらずに行ってよい。

- 準備処理の手直し: `run_stage1(&mut io, mode)` と `serve_request_stage1` の呼び出しを、テスト用の `IoRuntime` を作る補助（例 `vm` の `#[cfg(test)]` の補助に置く）と `Vm::run`・`serve_request` に置き換える。テスト用の部品の組の作り方を、`use_schedule` から `IoRuntime::parts` に移す。
- 置き換えた仮の経路を前提にした期待の手直し: 第 1 段の要求の形（要求が一つずつ、`state.pending`、要求の番号の付け方）や、R25 の一時的な待ちの形を前提にした期待を、本作業の形に合わせて改める。`run.rs` の `start_main_failure_invalid_targets_and_panic_are_internal` が、`Stdout` と `Capture` の出力先の混在を `Internal` と期待している部分は、第 1 段の制約を確かめるものなので、混在を受け付けることを確かめる形に書き換えてよい。

テストが確かめていた振る舞いそのもの（実行の結果、止まる理由、報告）を変える必要が生じたら、作業を止めて報告する。`builtins/funcs/stage1_io.rs`（R08 の第 1 段の `IoServices` の一時的な実装）は、VM の単体テストを移した後も `src/refinterp/tests.rs` が使うので、消さない。

## 受け入れテスト

テストは、スクリプトをパイプラインでコンパイルし、R25 のテスト用の部品（本作業の `WorkerExec` のテスト用の実装を含む）を渡して、二つの方式で実行する。偽の組み込みの関数は、上の「偽の組み込みの関数の差し替え」で呼ぶ。VM のテストは、テスト用の部品と `mio` を使わない `Wakeup` で書く。

- 二つの方式で同じ結果: `File.readText` と `Console.writeLine` を使う既存のゴールデンテストのうち C05 が移したものが、`run_program` の置き換えの後も両方式で通る（本作業の一時的な `RuntimeParts::real` で走る）。
- 要求の送り出し（ADR 0264 の決定 5）: タスク A が `File.readText` を呼んで待ち、タスク B が長い計算を末尾再帰で続ける。要求と応答の方式で、A の要求が B の計算の終わりを待たずに `VmStep::Requests` で外側に渡る。直接呼び出しの方式では、A の要求が B の計算の途中で作業用のスレッドの仕事として出される（テスト用の実装が預かった時点で確かめる）。
- 完了の取り込み: 上の形で、筋書きが B の計算の途中で仕事を実行すると、A が B の計算の終わりを待たずに起こされる（予算の一巡りのうちに遅い経路で取り込む）。
- すぐに完了する操作: `Console.writeLine` を呼んだタスクも一度待ちに入り、同じ待たせる位置で起こされる。待ちの状態を上書きしない（相談の第 3 回の問い 1 の危険）。
- 完了の処理の順序（`accept_completion` の単体テスト）: 偽の資源を貸した記録に完了が届いたとき、先に資源が表に戻り（`Returned`）、`Deliver` が操作の番号と `site` を持つ。`deliver_to` を外した記録の完了は `Dropped` になり、資源は戻る。`Panicked` の完了は、タスクが待っていなくても `Bug` になり、資源は戻る。閉じる要求のある資源の返却で `StartRelease` が返る。種類 `Release` の記録の完了は、配送先がなくても `finish_release` まで行い、`ReleaseFinished` を返す。確かめの関数が、記録のない完了と `returned` の食い違いを拒む。
- 配送の照合: タスク A の仕事の完了を、B の実行中（筋書きで B の計算の途中に実行）に取り込むと、A の `site` の結果のレジスタに結果が入る。完了の前に A が取り消されていれば、結果は捨てられ、A は通常の実行に戻らない。
- 失効した要求（二つの方式。相談の第 7 回の指摘 4）: 要求と応答の方式で、A の要求を外側へ返し、応答を渡す前に別のタスクが A を取り消す。その後に外側の実行器が同じ番号で `serve_request` を呼んでも、組み込みの関数は呼ばれず（副作用を記録する偽の組み込みの関数で確かめる）、A は `Cancelled` で終わる。直接呼び出しの方式では、`ServeNow` の途中の要求で止める手順が始まったとき、残りの要求の組み込みの関数が呼ばれない。どちらの方式でも、返却を待つ要求（段階 `AwaitLend`）のタスクを取り消すと、後の返却で要求がやり直されない。
- 返却の後の要求のやり直し（二つの方式）: 同じ偽の資源を貸す仕事を二つのタスクが順に求め、二つ目が `Lend` で待つ。一つ目の完了の後、二つ目の要求が組み込みの関数を呼び直さずに貸し出しからやり直され、正しい `site` の結果のレジスタに結果が入る。
- 標準入力の貸し出しの待ち（二つの方式）: 二つのタスクが標準入力を借りる偽の組み込みの関数を順に呼ぶ。二つ目は `WaitReason::Lend(STDIN_LEND)` で待ち、一つ目の完了で読み手が戻った後に、組み込みの関数を呼び直さずに貸し出しからやり直される。読んだ順が呼んだ順である（`StdinSource::Bytes` で確かめる）。待っている二つ目を取り消すと、読み手が戻ってもやり直されない。
- 返却の後の解放の完了を待つ（相談の第 7 回の指摘 1）: タスク A が偽の資源 r の貸し出しを待って返却を待つ並びに入り、取り消され、自分の解放の枠で `AfterReturn` を待つ。元の仕事が r を返すと、ブロックする解放が始まる（偽の資源をブロックする種類にする）。筋書きで解放の仕事の実行を後に回している間、A の枠とタスクは残り、A は `Done` にならない。解放の完了の後に枠が降り、A が `Cancelled` で終わる。解放が失敗する場合は、失敗が原因 `Cancel` の規則で報告される。
- ブロックする解放の受け渡し（相談の第 7 回の指摘 5）: テスト用の VM の補助で、ブロックする種類の偽の資源をリソースの表に加え、`USE`・`RETURN` の実際の命令の経路で解放する。`release_jobs` から仕事が出され（テスト用の `WorkerExec` が預かった仕事の種類で確かめる）、筋書きで実行すると `Outcome::Released` が取り込まれ、状態が `Released` になり、枠が降りる。解放が失敗する偽の資源では、`ReleaseFailed` の実行時エラーになり、報告の開いた位置が項目の `opened_at` である。`unwind_release` を直接呼んで完了を補助で記録するテストでは、この受け渡しの誤りを見つけられないので、この経路で確かめる。
- 仕事の panic: 実行すると panic する偽の仕事を返す組み込みの関数を呼び、筋書きで実行すると、完了が `Panicked` になり、貸したものが表に戻り、実行が処理系の不具合（スレッドは作業用のスレッド）で終わる。作業用のスレッドの上での同じ確かめは R40 が行う。
- 行き詰まりの判定（相談の第 7 回の指摘 6、[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）: 作業用のスレッドの仕事を待つタスクがある間は、ほかのタスクが互いを待っていても行き詰まりにしない。要求と応答の方式で、応答を待つタスクがある間も行き詰まりにしない。配送先を外した記録が借りている偽の資源の返却を `Lend` で待つタスクがある間も、行き詰まりにしない。待つタスクのない出力の転送は、R27 が確かめる。
- 取り消したタスクの終わらない標準入力の読み取りと行き詰まり（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）: タスク A が、標準入力の読み手を借りる（`Lend::Stdin`）偽の組み込みの関数を呼び、仕事を待つ。筋書きはこの仕事を最後まで実行しない（終わらない読み取り）。`Task.race` で先に B が終わり、A が取り消される。その後、残る二つのタスクが `Task` の値を入れたセルを通して互いを `Task.await` で待つ。A の配送先を外した記録が残ったまま、`TaskDeadlock` で止まり、`StopInfo::deadlock` に二つのタスクだけが並ぶ。実行は A の仕事の完了を待たずに終わる（ADR 0266 の決定 11）。二つの方式で確かめる。
- 止める手順の間の完了の取り込み: 偽の資源を貸した仕事の完了を筋書きで後に回し、その間に別のタスクで 0 の除算を起こす。止める手順の間も完了が取り込まれ、資源が戻ってから解放され、止まる理由は `DivisionByZero` のままである。
- `Clock.sleep` の形の待ち: `IoWait::Sleep` を返す偽の組み込みの関数を呼んだタスクが、`Response` から `Timer` の待ちに移り、仮想の時間で期限まで進めると起き、結果のレジスタに `()` が入る。`repark` の補助が、今の理由で待っていないタスクを拒む（単体テスト）。
- 起動を筋書きに知らせる口: 筋書きの起動の通し番号で選ぶ指示（R25 のテスト）が、`TaskPicker::spawned` を通して本作業の後も通る。メインのタスクが通し番号 0 で知らされる。
- 筋書きの消費: 上の順序に依存するテストは、筋書きの記録で、筋書きを使い切ったことと、仕事を実行した時点が狙ったとおりであることを確かめる。
- 残る外部の操作: 仕事が終わらないまま（筋書きが実行しないまま）すべてのタスクが終わると、実行は仕事を待たずに終わる。
- `run_program` の出力: 一時的な `OutputPort` で、`Stdout` と `Capture` を混ぜた出力先を受け付ける。書き出しに失敗する出力先で、失敗が第 1 段と同じ規則で終わり方の報告に入る（既存の `final_output_failure_preserves_the_reason_for_ending_and_reports_once` が通る）。`dev_panic_after_first_write` で、最初の書き込みの直後に処理系の不具合で終わり、書いた内容が出力先に出る。
- VM の単体テストのうち第 1 段の実行の関数を使っていたものが、第 2 段の実行の関数で通る。
- 根の置き場ごとの回収の強制（R03「根の列挙の引き渡し」の表の「待つ組み込みの関数の状態と完了の結果」の行）: `HeapConfig::stress` を真にした設定で、作業用のスレッドの仕事を待つ組み込みの関数の引数（定数の表に残らないヒープの値）が待つタスクの枠のレジスタだけに残る状態を作り、筋書きで仕事を実行する前に別のタスクで回収を起こす。完了の処理が読み直した引数と結果が正しいことを、二つの方式で確かめる（要求と応答の方式では、要求を返した後、応答を渡す前に回収する）。段階 `AwaitLend` の待ちと `Timer` の待ちでも同じく確かめる。
- タスクの状態とリソースの状態の組み合わせのうち、作業用のスレッドを使う行（`Waiting(操作)` × `Lent(操作, 閉じる要求なし)`、`Unwinding` × `Lent(操作, 閉じる要求あり)`、`Done` × `Lent`）を、偽の資源を貸す単体テストで確かめる。プログラムからの確かめ（`File.readLine` を使うもの）は R29 と R30（OPEN-062 の R05）が行う。
- 回収の強制のビルドで、上のテストがすべて通る。

## 完了条件

- `scripts/check.sh` が通る
- `scripts/check-heap.sh` が通り、10 分以内に終わる（ADR 0318。Miri は `runtime::heap::` と `vm::miri_tests` だけを走らせる）。本作業が `vm/miri_tests.rs` を作り、ADR 0318 の決定 2 の代表の形（安全点での回収と生きているレジスタの整理、継続の捕捉・再開・破棄、タスクの待ちの間の回収、`Lazy` の結果とセルの書き込み、リソースの貸し借りと返却、IO の完了の待ち）を、一つの形につき一件程度、Miri で数秒から数十秒で終わる大きさで置く。既存のテストの補助を使ってよい。完了の報告に、置いたテストの一覧と `check-heap.sh` の各段の時間を書く
- 受け入れテストのすべての場合を確かめるテストがある
- 二つの方式の違いが、部品（`Dispatcher` の実装）の中だけにある（ADR 0264 の決定 4）
- 外部の操作に移る前の要求の呼び出しの命令が、10-10 の段階の表の場所だけにある
- 待たせる位置と遅い経路の順序が、どちらの方式でも一つの関数を通る。R39 のタイマーの照合が残っている
- `vm/stage1.rs` の関数と、それを呼ぶ箇所が残っていない。`RunState::pending` と `Scheduling` の `picker`・`clock`・`script` が残っていない
- 実時間の待ちやスレッドの実行の順序の偶然に頼るテストがない（[実装の規約](../00-common/00-02-conventions.md)の「テストの規約」）
- 完了の報告に、短い測定と機械語の数、前述の ADR 0314 の分類の表、取り消しと止める手順で `IoRuntime` に触れる方式（前述）を書いている
- 一時的な `OutputPort`、一時的な `RuntimeParts::real`（仕事を VM のスレッドで実行する）、何もしない `Wakeup` を書いたことを、完了の報告の「残したこと」に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」と「スケジューラと IO」の行（タスクを待たせてから要求を公開しているか、待たせる位置と遅い経路で送り出しと取り込みを行っているか、完了の処理の順序）。
- 作業用のスレッドに渡すものに言語の値が入っていないか（型で防いであるが、`Send` の抜け道を作っていないか）。
- 完了を言語の値に変える処理が、待っているタスクの枠のレジスタから引数を読み直しているか（閉包に捕えていないか）。
- 結果の書き込みと命令の位置の更新を、回収を挟まずに一続きに行っているか。
- 待つ理由を改めるとき、`park` を呼び直していないか（`check_park` の二重の待ちの拒否を迂回していないか）。
- `run_epoch` の引数の置き換えで、`run_until_exit` の頭の退避が増えていないか。
- 偽の組み込みの関数の差し替えの表が `#[cfg(test)]` の中にだけあり、普通の経路に分岐を足していないか。

## 難易度の理由

二つの方式を一つの規則にまとめ、完了の処理の順序、返却と標準入力の待ちのやり直し、取り消しと止める手順との競合を同時に正しくする必要がある。順序の誤りはまれにしか起きないので、テスト用の部品で順序を与えて一つずつ確かめる。第 1 段の実行の関数から移す間も、既存のテストを通し続けなければならない。作業用のスレッドとイベントループの本物は R40 に分けた。
