# R27 出力の書き出し用のスレッド

- 依存する作業: [R26](R26-dispatch-queue-and-io-executor.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R27-output

## 目的

標準出力と標準エラー出力の転送を、出力ごとに一つ置く書き出し用のスレッドで行う（ADR 0265）。書き込みは VM のスレッドでバッファに加え、転送は書き出し用のスレッドが順に行う。転送の時点を「依頼するだけ」と「それまでの出力の完了を待つ」に分け、転送していない量が上限を超えたときだけ、書いたタスクを待たせる。書き出しの失敗と書き出し用のスレッドの panic は出力ごとに記録し、書いたタスクの寿命に依存させない。

R26 が書いた一時的な `OutputPort`（VM のスレッドで書き出す形）を、同じシグネチャのまま置き換える。あわせて、`run_program` の出力の最後の転送と、転送の失敗の扱い（10-13「実行の流れ」の最後の段落）を仕上げる。

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

- `src/runtime/io/output.rs`: `OutputPort` の関数と書き出し用のスレッドの本体。
- `src/runtime/io/services.rs`: `IoServices::write_output` の、受け付けと待ちの扱い（R26 が書いたものを改める）。
- 待たせる位置と遅い経路の順序の関数（R25・R26 が作ったもの）への、手順 3 の出力の取り込みと手順 4 の転送の依頼の追加。手順 5 の行き詰まりの判定には、転送中の出力を数えない。出力の容量か転送の完了を待つタスクは `WaitReason::Output` で待つので、その待ちで数えられる（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）。取り消しの手順（R25）への `cancel_pending` の追加。作業用のスレッドの仕事を出す処理（R26）の、`after_output_flush` の完了の待ち。
- `src/runtime/run.rs`: `run_program` の出力の最後の転送と、転送の失敗の扱い。
- 上のファイルのテスト。

## 手順の要点

### 数え方と受け付け（ADR 0265 の決定 4）

転送していない量 N は、`OutputPort` のバッファの長さ、`WriterState::queue` の長さの合計、`WriterState::in_flight` の和である。書き込む量を n、上限 B を `UNSENT_LIMIT`（1 MiB）として、`write` は次のように受け付ける。

- 預けた書き込み（`deferred`）がなく、N + n ≤ B なら、バッファに加えて `Accepted`。
- 預けた書き込みがなく、n > B で N = 0 なら、加えて `Accepted`。
- それ以外は、バッファの中身の転送を依頼し、書き込みを `deferred` の末尾に預けて `Deferred`。預けた書き込みがある間は、後から来た書き込みもその後ろに預け、追い越さない。

一回の書き込みの文字列は一度に加えるので、ほかのタスクの出力に割り込まれない。受け付けた出力は、書いたタスクを取り消しても取り下げない。預けた書き込みは受け付けていないので、`cancel_pending` で取り下げる。

`IoServices::write_output` は、`Accepted` なら `Ok(None)`、`Deferred` なら `Ok(Some(IoWait::Output { stream, kind: Capacity }))` を返す。VM はタスクを `WaitReason::Output(stream, Capacity)` で待たせる。`poll` が容量が空いて受け付けた書き込みのタスクを返したら、そのタスクを起こし、書き込みの関数の結果の `()` を結果のレジスタに入れる。

### 転送の時点（ADR 0265 の決定 3、10-10 の転送の時点の表）

| 時点 | 行うこと |
|---|---|
| `write` でバッファが `TRANSFER_THRESHOLD`（64 KiB）以上になったとき | `request_transfer` |
| 進められるタスクがなくなり、イベントループで待つ前（10-10 の手順 4） | 両方の出力の `request_transfer` |
| 出力先が端末であり、書き込みで改行を書いたとき | `request_transfer` |
| 標準入力を読む仕事（`after_output_flush` の仕事）を出す前 | 標準出力、標準エラー出力の順に、`request_transfer` と `flush_target` をし、`WaitReason::Output(stream, Flush)` でタスクを待たせる。両方の完了を `poll` で受けてから、仕事を出す。待つ間、要求と仕事は段階 `AwaitFlush` で `DispatchQueue::live` に置き、完了の後に `take_task_request` で取り出して R26 の「仕事を出す手順」の手順 2 から続ける（10-10 の段階の表） |
| 止める手順の終わりと、プログラムを終える前 | `finish` |

`request_transfer` は、バッファの中身を一つのかたまりとして `WriterState::queue` に移して `cond` で知らせるだけで、転送の完了を待たない。依頼を完了と取り違えない（相談の第 3 回の問い 2）。

`flush_target` は、その時点までに依頼したかたまりの通し番号（`sent_seq`）を返し、`flush_waiters` に（タスク、番号）を加える。`poll` は、`WriterState::done_seq` がその番号に達した待ちを外して、そのタスクを返す。完了を待つのは、その時点までに加えた出力に限る。ほかのタスクが後から加える出力は待たない。完了を待つ間も、VM はほかのタスクを進め、イベントの処理と中断の確かめを続ける（待つのはタスクであり、VM のスレッドではない）。

`Process.runAttached` の前の完了の待ち（02-09「出力のバッファ」）は、`Process.runAttached` を U3 が書くときに同じ仕組み（`after_output_flush`）を使う。

### 書き出し用のスレッド（ADR 0265 の決定 2・5）

- `start` は、出力ごとにスレッドを一つ起こす。スレッドは `WriterShared::state` の `queue` から先頭のかたまりを取り出し、`in_flight` にその長さを入れ、出力先に `write_all` と `flush` で書く。書き終えたら `in_flight` を 0 にし、`done_seq` を一つ進め、`Wakeup::wake` で VM のイベントループを起こす。
- 書き出しの失敗は、`failure` に `WriteFailure::Io(理由)` を記録し、`queue` を捨てる。以後のかたまりは書かずに捨てる。失敗した出力を、もう一度書き出そうとはしない。失敗したら、`Wakeup::wake` で VM を起こし、容量と完了の待ちを解く（`poll` が待つタスクをすべて返す）。
- スレッドの処理は `catch_unwind` で囲む。panic したら、panic の記録を `WriteFailure::Panicked` として記録し、待ちを解いてから終わる。VM のスレッドは、失敗の記録を読むときにこれを見つけたら、panic 境界の処理（処理系の不具合、スレッドは書き出し用のスレッド）に移る。
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

書き出し用のスレッドの panic は、どの終わり方でも処理系の不具合（終了状態 3、スレッドは `FaultThread::Writer`）とする。

## 受け入れテスト

テストのために、出力先の `Write` の偽の実装を使う。止めておける出力先（`write` が channel の知らせを受けるまで戻らない）、書いた内容を記録する出力先、常に `BrokenPipe` を返す出力先、`write` で panic する出力先である。実時間の待ちに頼らず、知らせと `Wakeup` で順序を決める。タスクの順序と時間は R25 のテスト用の部品で与える。

- 受け付けの規則（`OutputPort` の単体テスト）: N + n ≤ B で受け付ける。上限を超える書き込みが `Deferred` になり、後から来た小さな書き込みも追い越さずに預けられる。n > B の書き込みは N = 0 のときに限り受け付ける。容量が空くと、預けた書き込みが呼んだ順に受け付けられる。`cancel_pending` で預けた書き込みが取り下げられ、受け付けた分は取り下げられない。
- 転送の時点: 64 KiB に達した書き込みで転送が依頼される（書いた内容を記録する出力先に、`finish` の前に届く）。端末として作った出力で改行を書くと転送が依頼され、端末でない出力では依頼されない。進められるタスクがなくなると両方の出力の転送が依頼される。
- 詰まった出力先（OPEN-062 の R04 の形。正式な再現テストは R30）: 標準出力を止めておける出力先にし、タスク A が 2 MiB を書く。A が容量の待ちに入った後も、タスク B の標準エラー出力への書き込みと、仮想の時間のタイマーが進み、B が終わる。出力先を動かすと A が再開し、すべての出力が書いた順に届く。
- 完了の待ち: `after_output_flush` の仕事を出す前に、それまでの出力が出力先に届いている（書いた内容を記録する出力先で、仕事を実行した時点の内容を調べる）。完了を待つ間も、ほかのタスクが進む。
- 待つタスクのない転送と行き詰まり（相談の第 7 回の指摘 6、[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）: 二つのタスクが互いを `Task.await` で待つ直前に標準出力へ書き、止めておける出力先で転送を止めておく。どのタスクも出力を待っていないので、転送が終わるのを待たずに、`Vm::run` が `TaskDeadlock` で止まる。その後に出力先を動かすと、最後の転送（`OutputPort::finish`）で書いた内容が出力先に届く。
- 完了を待つタスクのある転送と行き詰まり: 上と同じ形で、三つ目のタスクが `after_output_flush` の仕事の前に転送の完了を待つ（`WaitReason::Output`）。転送が終わるまでは行き詰まりにしない。
- 書き出しの失敗: `BrokenPipe` の出力先で、次の書き込みか転送の依頼で `WriteFailed` の実行時エラーになり、主な位置と履歴を持たない。容量の待ちと完了の待ちにあったタスクが起こされる。
- 最後の転送の失敗: 10-13 の表の四つの終わり方のそれぞれで、報告と終了状態が表のとおりになる（`main` の成功で R0201 と終了状態 1、`Result.Error` で `main_error` と R0201、0 の除算で R0101 の報告に注記、`Process.exit` は R29 の後に R31 が確かめる）。
- 書き出し用のスレッドの panic: panic する出力先で、実行が処理系の不具合（終了状態 3、スレッドは書き出し用のスレッド）で終わり、待っていたタスクが残らない。
- 開発用の panic: `dev_panic_after_first_write` を真にした実行で、最初の書き込みの後に処理系の不具合になり、報告の前に書き込みの内容が出力先に届いている。
- メモリに捕らえる出力先（`OutputTarget::Capture`）で、既存のゴールデンテストが両方の IO の方式で通る。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
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
