# R27 出力の書き出し用のスレッド

- 依存する作業: [R40](R40-event-loop-and-worker-threads.md)（R26 を含む）
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R27-output

## 目的

標準出力と標準エラー出力の転送を、出力ごとに一つ置く書き出し用のスレッドで行う（ADR 0265）。書き込みは VM のスレッドでバッファに加え、転送は書き出し用のスレッドが順に行う。転送の時点を「依頼するだけ」と「それまでの出力の完了を待つ」に分け、転送していない量が上限を超えたときだけ、書いたタスクを待たせる。書き出しの失敗と書き出し用のスレッドの panic は出力ごとに記録し、書いたタスクの寿命に依存させない。

R26 が書いた一時的な `OutputPort`（出力先を持つ最小の書き出し用のスレッドで、容量の待ちと完了の待ちを持たず、バッファが `TRANSFER_THRESHOLD` に達したときと `finish` で転送する形。R26「一時的な `OutputPort`」）を、同じシグネチャのまま置き換える。あわせて、R26 が置いた出力の待ちの扱いの欠け（`serve_inner` が `IoWait::Output` の待ちを受けず、`submit` が `after_output_flush` の完了の待ちを行わない）を埋め、`run_program` の出力の最後の転送と転送の失敗の扱い（10-13「実行の流れ」の最後の段落。R26 が `run_program` の終わりの `finish` と非公開の `flush_failure` に置いた）を、書き出し用のスレッドの形で確かめる。

## 読む設計書の節

- [ランタイム](../../design/02-impl/02-09-runtime.md)の「出力のバッファ」（全体）、「panic 境界」、「プログラムの実行の流れ」の手順 4・5 と転送に失敗したときの箇条、「タスクの待ちと取り消し」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」の待つ理由の表の出力の行、「実行時エラーの情報の記録」の最後から二つ目の段落（書き込みの失敗は主な位置と履歴を持たない）、「タスクの切り替え」の最後の段落（一回の書き込みはほかのタスクの出力と混ざらない）
- [エフェクト](../../design/01-spec/01-07-effects.md)の「IO が起きる時期と順序」「IO の失敗」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の「タスクの切り替え」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md)の「実行時エラーと資源の不足の報告」の書き込みの失敗の段落
- ADR: [0265](../../design/decisions/0265-output-transfer-by-writer-threads.md)、[0045](../../design/decisions/0045-late-detection-of-output-write-failure.md)、[0079](../../design/decisions/0079-rust-readings-of-go-based-decisions.md)（SIGPIPE の既定を変えないこと）
- 検討資料: [相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 2。転送の依頼を完了と取り違えることと、満杯の channel への送信や `join` で VM を止めることを主な危険とし、転送を止められる出力先で標準出力が詰まっても標準エラー出力・タイマー・中断が進むこと、各転送の時点、最後の書き込みの後の失敗、メモリに捕らえる出力でも同じ手順を通すことを確かめるよう求めている

インターフェース:

- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「実装プランで決める値」、「出力のバッファと書き出し用のスレッド」（`OutputPort`・`WriterShared`・`WriterState`・`WriteFailure`・`Accept`、転送の時点の表）、「完了の処理と行き詰まりの判定の順序」の手順 3・4
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `IoWait::Output`・`OutputWaitKind`、`IoServices::write_output`、`WorkerWait::after_output_flush`
- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「止まったときの報告」の `write_failed`・`add_flush_failure`・`FaultThread::Writer`、「実行の流れ」の終わり方の表と最後の段落、`RunEnv::dev_panic_after_first_write`

## 作るもの

- `src/runtime/io/output.rs`: `OutputPort` の関数と書き出し用のスレッドの本体（R26 の一時的な形を置き換える）。
- `src/runtime/io/services.rs`: `IoServices::write_output` の受け付けと待ちの扱い。R26 は `Deferred` を `IoWait::Output { stream, kind: Capacity }` に写し、失敗を `WriteFailed`（`Panicked` は処理系の不具合）にしている。これを確かめ、要るところだけ改める。`IoRuntime` に、本作業の非公開の欄（容量の待ちのタスクと命令の位置の対応など）を加えてよい（10-10 の `IoRuntime` のコメント）。
- `src/vm/dispatch/tasks/io.rs`（R26 が書いたもの）に書き足す:
  - `serve_inner` の `Reply::Wait(WaitRequest::Io(IoWait::Output { .. }))` の分岐（後述の「容量の待ち」）。今は全部受けの `Reply::Wait(_)` に入り、`Stop::Internal`（"IO reply has unsupported wait or spawn"）になる。
  - `submit` の頭の、`WorkerWait::needs_output_flush` による完了の待ち（後述の「完了の待ち」）。
  - `io::boundary` か、それに続く `tasks::boundary` の手順 3 の、両方の出力の `OutputPort::poll` の取り込み（後述の「`poll` の結果の処理」）。
  - `reflect_cancellation` の、`cancel_pending` の呼び出し（後述の「取り消しと止める手順」）。
- `src/vm/dispatch/tasks.rs`（R25 が書いたもの）に書き足す: `boundary` の手順 3 の出力の取り込み（上の `poll` を `tasks::boundary` に置く場合）と、`switch_inner` の手順 4（進められるタスクがなく、行き詰まりの判定と `idle` の前に、両方の出力の `request_transfer`）。手順 5 の行き詰まりの判定には、転送中の出力を数えない。出力の容量か転送の完了を待つタスクは `WaitReason::Output` で待つので、その待ちで数えられる（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）。
- `src/runtime/io/event.rs`: R40 が `WakeupInner` に加えた非公開の欄 `backend` の `enum` `WakeBackend`（`WithoutPoll` と `WithPoll { waker, poll }` の二つの分岐）に、三つ目の分岐としてテスト用の待てる形を加える（後述の「テスト用の部品の待ち」）。
- `src/runtime/sched/testing.rs`: テスト用の `WorkerExec`（`ScriptWorkers`）の `idle` が、筋書きを進められないときに上の待てる形の知らせを待つようにする。
- `src/runtime/run.rs`: R26 が置いた `run_program` の最後の転送（標準出力、標準エラー出力の順の `finish`）と `flush_failure` を確かめ、足りないものを足す。
- 上のファイルのテスト。

R26 の `io.rs`（`serve_inner`・`submit`・`io::boundary`・`reflect_cancellation`）と R25 の `tasks.rs`（`boundary`・`switch_inner`）、R40 の `event.rs` の `WakeupInner` の `enum`、R25・R26 の `sched/testing.rs` の上の箇所は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。`io.rs` の非公開の関数（`fail_task`・`repark`・`reflect_cancellation` など）を `tasks.rs` から使うときは、公開の範囲を `pub(super)` などに広げてよい。

### 並行して実装する場合

R28 も `switch_inner` の `idle` の直前（本作業は手順 4 の転送の依頼、R28 は `IdleWake::Interrupted` の処理）を書き換える。R27 と R28 は順に取り込み、後に取り込む方が `switch_inner` の衝突を直す。

## 手順の要点

### 数え方と受け付け（ADR 0265 の決定 4）

転送していない量 N は、`OutputPort` のバッファの長さ、`WriterState::queue` の長さの合計、`WriterState::in_flight` の和である。書き込む量を n、上限 B を `UNSENT_LIMIT`（1 MiB）として、`write` は次のように受け付ける。

- 預けた書き込み（`deferred`）がなく、N + n ≤ B なら、バッファに加えて `Accepted`。
- 預けた書き込みがなく、n > B で N = 0 なら、加えて `Accepted`。
- それ以外は、バッファの中身の転送を依頼し、書き込みを `deferred` の末尾に預けて `Deferred`。預けた書き込みがある間は、後から来た書き込みもその後ろに預け、追い越さない。

一回の書き込みの文字列は一度に加えるので、ほかのタスクの出力に割り込まれない。受け付けた出力は、書いたタスクを取り消しても取り下げない。預けた書き込みは受け付けていないので、`cancel_pending` で取り下げる。

`IoServices::write_output` は、`Accepted` なら `Ok(None)`、`Deferred` なら `Ok(Some(IoWait::Output { stream, kind: Capacity }))` を返す。書き込んだタスクは `rt.output_task` である（R26 の `serve_inner` と `complete` が、組み込みの関数を呼ぶ前に設定する）。

### 容量の待ち

`serve_inner` は、`Reply::Wait(WaitRequest::Io(IoWait::Output { stream, kind: Capacity }))` を受けたら、`repark` でタスクを `WaitReason::Response` から `WaitReason::Output(stream, Capacity)` に移し、タスクと命令の位置（`req.site`）の対応を `IoRuntime` の本作業の欄に記録する（`Sleep` の分岐が `rt.sleeps` に記録するのと同じ形）。`OutputWaitKind::Flush` は組み込みの関数が返さない（完了の待ちは `submit` が行う）ので、受けたら `Stop::Internal` にする。

`poll` が容量が空いて受け付けた書き込みのタスクを返したら、記録した命令の位置を取り出し、R26 の `io::write_result(program, state, ctx, task, site, Value::Unit)`（結果の書き込みと命令の位置の更新を一続きに行う）で書き込みの関数の結果の `()` を入れてから、`state.scheduler.wake_if(task, WaitReason::Output(stream, Capacity))` で起こす。

待つ枠は、命令の位置が待っている `IO` の命令を指す「命令の入口」である（[ADR 0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md) の決定 5、R26「回収の前の整理」）。R26 の分類の表に「容量の待ち｜`Output`｜命令の入口」の行を加え、完了の報告に書く。

### 転送の時点（ADR 0265 の決定 3、10-10 の転送の時点の表）

| 時点 | 行うこと |
|---|---|
| `write` でバッファが `TRANSFER_THRESHOLD`（64 KiB）以上になったとき | `request_transfer` |
| 進められるタスクがなくなり、イベントループで待つ前（10-10 の手順 4） | 両方の出力の `request_transfer` |
| 出力先が端末であり、書き込みで改行を書いたとき | `request_transfer` |
| 標準入力を読む仕事（`after_output_flush` の仕事）を出す前 | 標準出力、標準エラー出力の順に一つずつ完了を待ってから、仕事を出す（後述の「完了の待ち」） |
| 止める手順の終わりと、プログラムを終える前 | `finish` |

`request_transfer` は、バッファの中身を一つのかたまりとして `WriterState::queue` に移して `cond` で知らせるだけで、転送の完了を待たない。依頼を完了と取り違えない（相談の第 3 回の問い 2）。

`flush_target` は、その時点までに依頼したかたまりの通し番号（`sent_seq`）を返し、`flush_waiters` に（タスク、番号）を加える。`poll` は、`WriterState::done_seq` がその番号に達した待ちを外して、そのタスクを返す。完了を待つのは、その時点までに加えた出力に限る。ほかのタスクが後から加える出力は待たない。完了を待つ間も、VM はほかのタスクを進め、イベントの処理と中断の確かめを続ける（待つのはタスクであり、VM のスレッドではない）。

`Process.runAttached` の前の完了の待ち（02-09「出力のバッファ」）は、`Process.runAttached` を U3 が書くときに同じ仕組み（`after_output_flush`）を使う。

### 完了の待ち（10-10 の段階の表）

R26 の `submit`（`vm/dispatch/tasks/io.rs`）の頭に、次の手順 1 を加える。今の `submit` の中身（貸し出しと仕事を出す処理）が手順 2 になる。

1. `work.needs_output_flush()` が真なら、標準出力、標準エラー出力の順に、一つずつ完了を待つ。各出力で `request_transfer` をし、その出力に依頼して書き終えていないかたまりがなければ待たずに次の出力へ進む（この判定のために `OutputPort` に非公開の補助の関数を加えてよい）。書き終えていなければ `flush_target` をし、要求と仕事を段階 `AwaitFlush` で `DispatchQueue::live` に置き（`park_request`）、`repark` でタスクを `from` から `WaitReason::Output(stream, Flush)` に移して戻る。
2. 両方の出力を待ち終えたら、仕事を出す（今の `submit` の中身）。

`poll` が完了を待ち終えたタスクを返したら、結果を書かず、命令の位置も進めない。`take_task_request` で段階 `AwaitFlush` の要求と仕事を取り出し、標準出力の完了で起きたなら標準エラー出力について手順 1 を続け、標準エラー出力の完了で起きたなら手順 2 に進む。このときの `from` は、タスクがいま待っている `WaitReason::Output(stream, Flush)` である。待つ枠は「命令の入口」である（R26 の分類の表の `AwaitFlush` の行）。

### `poll` の結果の処理

10-10 の順序の手順 3 で、両方の出力の `poll` を取り込む。返ったタスクごとに、いま待っている理由で振り分ける（R26 の非公開の `waiting` で確かめる）。

- `WaitReason::Output(stream, Capacity)`: 前述の「容量の待ち」のとおり、`()` を書いて起こす。
- `WaitReason::Output(stream, Flush)`: 前述の「完了の待ち」のとおり、次の出力の待ちか仕事を出す処理に進む。
- どちらでもない（取り消しや止める手順で待ちを外した後）: 何もしない。

`poll` が失敗（`WriteFailure::Io`）を返したときは、待っていたタスクをすべて、書き込みの失敗の実行時エラー（`RuntimeError::WriteFailed`）で止める。容量の待ちのタスクは、`OutputPort` が預けた書き込みを捨て、記録した命令の位置で失敗にする。完了の待ちのタスクは、取り出した要求の命令の位置で失敗にする。止め方は R26 の他の失敗と同じく、`fail_task`（最初の理由だけを `StopReason::Error` に残す）の後に `begin_stop_all` と `reflect_cancellation` を続ける。待つタスクがなければ、失敗は次の書き込みか完了の待ち、または `run_program` の `finish` で見つかる。

`poll` が `WriteFailure::Panicked` を返したときは、待つタスクを処理系の不具合（`Stop::Internal`）で止めてもよく、そのまま進めて `run_program` の `finish` の結果で報告を置き換えてもよい。R26 の `run_program` は、`finish` が `Panicked` を返したら終わり方を処理系の不具合（スレッドは `FaultThread::Writer`）に置き換えるので、どちらでも報告は同じになる。

### 取り消しと止める手順

`cancel_pending` は、R26 の `reflect_cancellation`（`io.rs`）で呼ぶ。R39 の取り消しの手順（`cancel.rs`）には入れない。

- 取り消したタスク（`state.scheduling.cancelled_io` の各タスク）について、両方の出力の `cancel_pending` を呼び、容量の待ちの命令の位置の記録を消す。
- 止める手順（`state.scheduling.expire_io` が立ったとき）では、両方の出力の、すべての預けた書き込みと完了の待ちを捨て、記録を空にする（`rt.sleeps.clear()` と同じ位置）。

止める手順の始まりで待ちを外す処理（`begin_stop_all`）と、R28 の止める手順は、`cancel_pending` を呼ばない。止める手順でこれを受け持つのは本作業である。

### テスト用の部品の待ち

テスト用の `WorkerExec`（`sched/testing.rs` の `ScriptWorkers`）の `idle` は、筋書きを進められないと `IdleWake::ScriptExhausted` を返す。容量か完了を待つタスクだけが残ると、書き出し用のスレッドの知らせを待たずにテストが失敗する。そこで次のようにする。

- `event.rs` で、R40 が `WakeupInner` に加えた `enum` `WakeBackend` に、三つ目の分岐としてテスト用の待てる形を加える。lint（`clippy::wildcard_enum_match_arm`）で `_` の分岐を使えないので、`WakeBackend` を照合する箇所（`Wakeup::wake`、`EventLoop::take` など）すべてに三つ目の分岐を明示して書く（`EventLoop::take` では `None` を返す）。`Mutex` と `Condvar` で `wake` の回数を数える形とし、`wake` は回数を一つ増やして `Condvar` で知らせる。この形を作る `pub(crate)` の関数と、ある回数を超えるまで待つ `pub(crate)` の関数を `event.rs` に置く。
- `ScheduleHandle` が待てる形の `Wakeup` を一つ持ち、それを返す公開の関数を置く。`ScriptWorkers` はその `Wakeup` を共有し、`idle` で筋書きを進められないときは、前回見た回数を超える知らせを待ってから `Progress` を返す。待てる形でない `Wakeup` のとき（既存のテスト）は、今の振る舞いのままにする。
- 知らせが来ないまま止まり続けることを防ぐため、待ちに上限の時間（数秒）を置き、超えたら今と同じく `ScriptExhausted` を返す。上限は誤りを見つけるためのものであり、テストの順序は知らせで決める。

テスト用の部品と書き出し用のスレッドの知らせを組み合わせるテストは、`IoRuntime` を直接作る VM の単体テストの補助（`vm::dispatch::test_support` の `TestIo` など）で書き、`OutputPort::start` と `IoRuntime::new` に `ScheduleHandle` の待てる形の `Wakeup` を渡す。`run_program` に `RunEnv::parts` で部品を渡す経路のために、10-10 の `WorkerExec` に既定の本体付きの関数 `fn wakeup(&self) -> Option<Wakeup> { None }` を加える（オーケストレータが R30・R31 の事前点検を受けて認めた追加。R25 の `TaskPicker::spawned` と同じく既存の実装を壊さない）。`src/runtime/sched/parts.rs`（`WorkerExec` の宣言）に写し、R25・R26 の `ScriptWorkers` は `ScheduleHandle` の待てる形の `Wakeup` を返す。`run_program` は、`RunEnv::parts` が `Some` のとき `parts.workers.wakeup()` が `Some` ならその `Wakeup` を `OutputPort::start` と `IoRuntime::new` に渡し、`None` なら今の `wakeup_without_poll()` を使う。これで R29・R30・R31 の統合テストが、部品を渡す経路で出力の待ちを含むプログラムを動かせる。このことを確かめる統合テスト（`tests/` から `run_program` に筋書きの部品を渡し、`Console.write` の後の出力の完了の待ちを経て終わる）を一件加える。

### 書き出し用のスレッド（ADR 0265 の決定 2・5）

- `start` は、出力ごとにスレッドを一つ起こす。スレッドは `WriterShared::state` の `queue` から先頭のかたまりを取り出し、`in_flight` にその長さを入れ、出力先に `write_all` と `flush` で書く。書き終えたら `in_flight` を 0 にし、`done_seq` を一つ進め、`Wakeup::wake` で VM のイベントループを起こす。
- 書き出しの失敗は、`failure` に `WriteFailure::Io(理由)` を記録し、`queue` を捨てる。以後のかたまりは書かずに捨てる。失敗した出力を、もう一度書き出そうとはしない。失敗したら、`Wakeup::wake` で VM を起こし、容量と完了の待ちを解く（`poll` が待つタスクをすべて返す）。
- スレッドの処理は `catch_unwind` で囲む。panic したら、panic の記録を `WriteFailure::Panicked` として記録し、待ちを解いてから終わる。VM のスレッドは、失敗の記録を読むときにこれを見つけたら、panic 境界の処理（処理系の不具合、スレッドは書き出し用のスレッド）に移るか、実行を続けて `run_program` の `finish` の結果で報告を置き換える（前述の「`poll` の結果の処理」）。
- VM のスレッドは、`write`・`request_transfer`・`poll`・`finish` のときに失敗の記録を読む。`write` で失敗が記録されていれば、書いたものを捨てて `Err(WriteFailure)` を返し、`write_output` は書き込みの失敗の実行時エラー（`RuntimeError::WriteFailed`）を返す。この実行時エラーは主な位置と履歴を持たない（02-08「実行時エラーの情報の記録」）。
- `finish` は、残りのバッファを依頼し、`shutdown` を立てて、スレッドが列を書き終えて終わるのを待つ（`join`）。`finish` はプログラムを終える前と止める手順の終わりにだけ呼ぶ。VM の実行中に `join` で VM を止めない。
- `Mutex` の lock の失敗（毒）は、処理系の不具合として扱う（`unwrap` を使わない。[実装の規約](../00-common/00-02-conventions.md)の「失敗を panic で表さない」）。

出力先が端末かどうかは、`start` の引数で受け取る。`run_program` は、`OutputTarget::Stdout`・`OutputTarget::Stderr` の出力には、それぞれのストリームを `OutputTarget::is_terminal` で一度だけ調べた値を、`Capture` には偽を渡す（10-10「実装プランで決める値」、10-13 の `OutputTarget`）。メモリに捕らえる出力先も、同じ書き出し用のスレッドと完了の手順を通す（ADR 0265 の決定 6）。

### 開発用の panic

`RunEnv::dev_panic_after_first_write` が真なら、最初の書き込みを出力のバッファに加えた直後に Rust の panic を起こす（10-13 の `RunEnv` の欄の説明）。F18 が第 1 段の形で入れ、R26 が引き継いだ処理が、本作業の後も同じ時点で起きることを確かめる。`#[allow(clippy::panic)]` を理由のコメント付きで書くのは、[実装の規約](../00-common/00-02-conventions.md)の `#[allow]` の表の「IO 実行器の `BENITOITE_DEV_PANIC` の処理」の箇所に限る。

### `run_program` の最後の転送（10-13「実行の流れ」）

VM が `Finished` か `Stopped` を返したら、標準出力、標準エラー出力の順に `finish` を呼ぶ。panic 境界で処理系の不具合を捕らえた場合も、報告の前に `finish` を呼ぶ（02-09「panic 境界」）。転送の失敗は、10-13 の最後の段落のとおりに扱う。

| 終わり方 | 転送に失敗したとき |
|---|---|
| `Returned`・`MainError` | `write_failed` の報告を加え、終了状態を 1 にする |
| `Stopped` | 先の報告に `add_flush_failure` で注記を加える |
| `Exited`・`Interrupted` | `write_failed` の報告を加え、終了状態は変えない |
| `Internal` | 転送の失敗を報告しない |

書き出し用のスレッドの panic は、どの終わり方でも処理系の不具合（終了状態 3、スレッドは `FaultThread::Writer`）とする。R26 の `run_program` は、`finish` が `WriteFailure::Panicked` を返したら終わり方をこれで置き換えるので、VM の実行中に見つけた panic も、この置き換えに任せてよい。

### 性能

普通の経路に処理を足さない。本作業が足す処理は、IO の組み込みの関数の中（`write_output`）と、待たせる位置の順序の関数と要求の処理（`serve_inner`・`submit`・`boundary`・`switch_inner`。どれも `#[cold]`）だけで行う。振り分けのループ（`run_until_exit`）と呼び出しの速い経路には手を入れない。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（オーケストレータが行う）。本測定の道具（`examples/stage1_bench.rs` と `tools/bench/`）は変えない。

## 受け入れテスト

テストのために、出力先の `Write` の偽の実装を使う。止めておける出力先（`write` が channel の知らせを受けるまで戻らない）、書いた内容を記録する出力先、常に `BrokenPipe` を返す出力先、`write` で panic する出力先である。実時間の待ちに頼らず、知らせと `Wakeup` で順序を決める。タスクの順序と時間は R25 のテスト用の部品で与え、書き出し用のスレッドの知らせは前述の「テスト用の部品の待ち」の待てる形の `Wakeup` で待つ。

- 受け付けの規則（`OutputPort` の単体テスト）: N + n ≤ B で受け付ける。上限を超える書き込みが `Deferred` になり、後から来た小さな書き込みも追い越さずに預けられる。n > B の書き込みは N = 0 のときに限り受け付ける。容量が空くと、預けた書き込みが呼んだ順に受け付けられる。`cancel_pending` で預けた書き込みが取り下げられ、受け付けた分は取り下げられない。
- 転送の時点: 64 KiB に達した書き込みで転送が依頼される（書いた内容を記録する出力先に、`finish` の前に届く）。端末として作った出力で改行を書くと転送が依頼され、端末でない出力では依頼されない。進められるタスクがなくなると両方の出力の転送が依頼される。
- 詰まった出力先（OPEN-062 の R04 の形。正式な再現テストは R30）: 標準出力を止めておける出力先にし、タスク A が 64 KiB ずつ 32 回（合わせて 2 MiB）書く。一回の 2 MiB の書き込みは、N = 0 のときの n > B の規則で受け付けられ、容量の待ちに入らない。A が容量の待ちに入った後も、タスク B の標準エラー出力への書き込みと、仮想の時間のタイマーが進み、B が終わる。出力先を動かすと A が再開し、すべての出力が書いた順に届く。
- 完了の待ち: `after_output_flush` の仕事を出す前に、それまでの出力が出力先に届いている（書いた内容を記録する出力先で、仕事を実行した時点の内容を調べる）。標準出力の完了を待ってから標準エラー出力の完了を待ち、書き終えている出力では待たない。完了を待つ間も、ほかのタスクが進む。`after_output_flush` の仕事を作る組み込みの関数（`Console.readLine`）は R29 が書くので、本作業のテストは R26 の `IoRuntime::builtin_overrides`（`cfg(test)`）で偽の組み込みの関数に差し替え、`WorkerWait::after_output_flush` を付けた仕事を返させて作る。
- 待つタスクのない転送と行き詰まり（相談の第 7 回の指摘 6、[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）: 二つのタスクが互いを `Task.await` で待つ直前に標準出力へ書き、止めておける出力先で転送を止めておく。どのタスクも出力を待っていないので、転送が終わるのを待たずに、`Vm::run` が `TaskDeadlock` で止まる。その後に出力先を動かすと、最後の転送（`OutputPort::finish`）で書いた内容が出力先に届く。
- 完了を待つタスクのある転送と行き詰まり: 上と同じ形で、三つ目のタスクが `after_output_flush` の仕事の前に転送の完了を待つ（`WaitReason::Output`。仕事は上と同じく `builtin_overrides` の偽の組み込みの関数で作る）。転送が終わるまでは行き詰まりにしない。
- 書き出しの失敗: `BrokenPipe` の出力先で、次の書き込みか完了の待ちで `WriteFailed` の実行時エラーになり、主な位置と履歴を持たない。容量の待ちと完了の待ちにあったタスクが、その命令の位置で `WriteFailed` になる（預けた書き込みは出力先に届かない）。
- 失敗を記録した後の書き込み: 書き出し用のスレッドが失敗を記録した後（知らせと `Wakeup` で記録を待ってから）に同じ出力へ書くと、その書き込みの命令で `WriteFailed` になる。R26 で `vm/tests.rs` の `io_modes_write_the_same_output_and_finish_reports_sink_failure` の期待を、非同期の `OutputPort` に合わせて「`finish` が失敗を返す」に改めたので、この場合を本作業で確かめる。
- 最後の転送の失敗: 10-13 の表の四つの終わり方のそれぞれで、報告と終了状態が表のとおりになる（`main` の成功で R0201 と終了状態 1、`Result.Error` で `main_error` と R0201、0 の除算で R0101 の報告に注記、`Process.exit` は R29 の後に R31 が確かめる）。
- 書き出し用のスレッドの panic: panic する出力先で、実行が処理系の不具合（終了状態 3、スレッドは書き出し用のスレッド）で終わり、待っていたタスクが残らない。
- 開発用の panic: `dev_panic_after_first_write` を真にした実行で、最初の書き込みの後に処理系の不具合になり、報告の前に書き込みの内容が出力先に届いている。
- メモリに捕らえる出力先（`OutputTarget::Capture`）で、既存のゴールデンテストが両方の IO の方式で通る。

## 完了条件

- `scripts/check.sh` が通る
- `scripts/check-heap.sh` は本作業では走らせなくてよい。`vm/` を変えるので、オーケストレータが取り込むときに走らせ、10 分以内に終わることを確かめる（ADR 0318 の決定 5）。本作業のテストは `vm::miri_tests` に置かない（書き出し用のスレッドは `unsafe` のヒープを新しい形で使わない）
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、短い測定と機械語の数と、R26 の分類の表に加えた容量の待ちの行を書いている
- VM のスレッドが、出力先への書き出しと書き出し用のスレッドの終わり（`join`）を、`finish` のほかで待たない
- 失敗の記録と知らせ方が、書いたタスクの状態に依存しない

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「出力」の行（書き込みの受け付けの条件が ADR 0265 の決定 4 のとおりか、転送の完了を待つ位置で VM がイベントの処理と中断の確かめを続けているか）。
- 数え方 N に、バッファ・書き出し用のスレッドの列・転送中の量の三つを含めているか。加えてから待たせる形になっていないか（加える前に待たせる）。
- 転送の依頼と完了を取り違えていないか。
- `Mutex` の中で出力先に書いていないか（書いている間、VM のスレッドが `lock` で止まる）。
- 書き込みの失敗の実行時エラーに、主な位置と履歴を付けていないか。

## 難易度の理由

二つのスレッドの間の知らせと数え方を誤ると、VM が止まるか、出力が失われるか、順序が崩れる。転送の時点、容量の待ち、完了の待ち、失敗の記録がそれぞれ別の規則を持ち、どれも順序を与えるテストで確かめる必要がある。
