# R26 送り出しの列と IO 実行器

- 依存する作業: [R25](R25-tasks-and-scheduler.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/R26-io-executor

## 目的

組み込みのエフェクトの操作を、二つの IO の方式のどちらでも、一つの送り出しの列を通して行う形にする（ADR 0264）。タスクを待たせてから要求を列に公開し、タスクを待たせる位置と予算を使い切った遅い経路で、列の要求を送り出して完了を取り込む。作業用のスレッドとイベントループで行う外部の操作は、番号付きの操作の記録で持ち、完了は「返すリソースを戻す → 処理系の不具合を報告する → 配送する」の順に処理する（ADR 0266 の決定 3・4）。

あわせて、第 1 段の一時的な実行の関数（`Vm::run_stage1`・`serve_request_stage1`）を、第 2 段の実行の関数（`Vm::run`・`serve_request`）と実行ごとの状態のランタイムの部分（`IoRuntime`）に置き換え、`runtime::run::run_program` をその上に移してから、第 1 段の形を消す。

## スケジューラとリソースの表の置き場所

10-10 の `IoRuntime` は `scheduler`・`resources` の欄を持たない。二つは `RunState` の欄にある（R20 が置いた。10-09「実行ごとの状態」、10-10「実行ごとの状態と VM のつなぎ目」）。`io` の関数がリソースの表に書けるように、VM は `io` の関数を呼ぶたびに `IoView { rt, resources: &mut state.resources }` を作って渡す（10-10 の `IoView`）。

## 読む設計書の節

- [ランタイム](../../design/02-impl/02-09-runtime.md)の「実行ごとの状態」「組み込みの操作とハンドラ表」「操作の振り分け」「IO 実行器」「タスクの待ちと取り消し」「リソースの追跡」（作業用のスレッドへの貸し出しと、すべてのタスクが終わった後に残る操作の段落）「panic 境界」「プログラムの実行の流れ」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」「タスクの切り替え」（待たせる位置の段落と行き詰まりの段落）「IO の命令」
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「IO の方式のテスト」「順序を与えるスケジューラと仮想の時間（初回リリース版）」「ヒープとランタイムの確かめ方（初回リリース版）」の最後の行
- [スクリプト実行と埋め込み](../../design/02-impl/02-11-embedding.md)の「実行の入力と結果」
- ADR: [0264](../../design/decisions/0264-single-dispatch-queue-for-builtin-operations.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md) の決定 3・4・8・9・11、[0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)、[0029](../../design/decisions/0029-two-io-execution-modes.md)、[0088](../../design/decisions/0088-keep-both-io-execution-modes.md)、[0274](../../design/decisions/0274-deterministic-scheduler-and-virtual-time-for-tests.md)、[0261](../../design/decisions/0261-typed-builtin-interface.md) の決定 5・6
- 検討資料: [相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 1（要求の送り出しだけ直して完了の取り込みを忘れること、すぐに完了した後に待ちの状態を上書きすることを主な危険とし、要求の送り出しと、計算を続けるタスクがある間に届く完了の両方を確かめるよう求めている）と問い 3（完了の共通の処理は先に返却の欄を処理してから、タスクがまだ結果を待っているかを調べる）、その他の箇条（作業用のスレッドが panic しても返却の欄を作れるよう、貸したリソースを `catch_unwind` の外で持つ）。[相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 1・3・4・5・6・7（返却の後の解放の完了を待たずに枠を降ろすこと、記録を除いた後に `site` を失うこと、取り消した要求を後から処理すること、ブロックする解放の仕事の受け渡し、行き詰まりの判定の条件、筋書きを進める境界）

インターフェース:

- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の全体（とくに「送り出しの列と二つの部品」「外部の操作の記録と完了」「テストで差し替える部品」「イベントループ」「実行ごとの状態と VM のつなぎ目」「完了の処理と行き詰まりの判定の順序」）
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の「作業用のスレッドの仕事」、`IoWait`・`WorkerWait`・`WorkerDone`・`Lend`・`Lent`・`IoServices`
- [仮想機械](../10-interfaces/10-09-vm.md)の「第 1 段の実行の関数」
- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「実行の流れ」（`RunEnv`・`RunEnd`・`run_program` の終わり方の表）

## 作るもの

- `src/runtime/io/mod.rs`: `DispatchQueue` の関数（要求の段階と失効を含む）と、二つの部品（`DirectDispatcher`・`RequestDispatcher`）の `on_wait_point`。
- `src/runtime/io/ops.rs`: `OpTable` の関数と `accept_completion`。VM の側の `Accepted` の処理と、ブロックする解放の仕事の受け渡し（R24 の `take_release_job` から `WorkerExec::submit` まで）。
- `src/runtime/io/event.rs`: `Wakeup`（`WakeupInner` の欄を決める）とイベントループの本体（`mio::Poll` と `mio::Waker`、タイマーの期限までの待ち）。
- `src/runtime/sched/parts.rs`: `RuntimeParts::real` と、`WorkerExec` の実際の実装（作業用のスレッド）。
- `src/runtime/sched/testing.rs`（R25 が置いたもの）: `WorkerExec` のテスト用の実装（筋書きの仕事の実行の指示を読む）と、テスト用の部品の組を作る公開の関数の仕上げ。
- `src/runtime/io/services.rs`: `IoRuntime::new`、`IoServices for IoView<'_>`（`IoView` は C02 が `file=` で置いた）、`Vm::run`・`Vm::serve_request`。VM は `io` の関数を呼ぶたびに `IoView { rt, resources: &mut state.resources }` を作る。`register_resource` は `IoView::resources`（`RunState::resources`）に書く。VM の内部に触れる補助は `vm` のモジュールに `pub(crate)` で置いてよい（10-10「実行ごとの状態と VM のつなぎ目」）。
- `src/runtime/io/output.rs`: R27 が書き出し用のスレッドで作るまでの、一時的な `OutputPort` の中身（後述）。
- `src/runtime/run.rs`: `run_program` を `IoRuntime` と `Vm::run` の上に移す。`RunEnv::parts` と `StdinSource` を使う。
- `src/vm/stage1.rs`: 第 1 段の実行の関数を消す（後述）。
- VM の単体テストのうち `run_stage1` を使っていたものを、`Vm::run` に移す。
- `crates/benitoite/Cargo.toml` と `Cargo.lock`: 依存に `mio` を加える。
- 上のファイルのテスト。

### 加えるクレート

- `mio` 1.2.3（[ADR 0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)。[実装の規約](../00-common/00-02-conventions.md)の「依存するクレート」が版と機能を記録したクレート）。ライセンスは `MIT`、`rust-version` は 1.71 である。`default-features = false` とし、機能 `os-poll` と `os-ext` を有効にする（`net` は U3 の HTTP の作業が加える）。`Cargo.lock` に版を固定する。本作業の時点で 1.2.3 より新しい 1.x の版があれば、その版の文書で機能の名前が変わっていないことを確かめて使い、版を完了の報告に書く。`cargo deny check licenses` を通す。`MIT` は ADR 0138 の許可の一覧にあり `deny.toml` で許可済みの見込みなので、足りなければ要るものだけを加える。

### 第 1 段の形の消し方

10-09 の `vm/mod.rs` は C01 の `file=` であり、`pub mod stage1;` を宣言している。宣言を消すと凍結したファイルを変えることになるので、`src/vm/stage1.rs` は、中身の関数（`run_stage1`・`serve_request_stage1`）と、それだけが使っていた補助を消し、`//!` のコメントだけを残したモジュールにする。コメントには、R26 が第 2 段の実行の関数に置き換えたことと、宣言の行とファイルは移行の締め（C18）で消すことを書く（10-09「第 1 段の実行の関数」）。

### 一時的な `OutputPort`

`IoServices::write_output` は `OutputPort` に書く。`OutputPort` の中身と書き出し用のスレッドは R27 が書くが、本作業で `run_program` を移すと、出力が動かなければ既存のテストが通らない。そこで本作業は、書き出し用のスレッドを使わない一時的な中身を書く。`start` は出力先を持つだけ、`write` はバッファに加える、`request_transfer` と `finish` は VM のスレッドで出力先に書いて flush する、`flush_target`・`poll`・`cancel_pending` は待つものがない前提の中身にする。書き出しの失敗は、第 1 段の出力のバッファ（R08 の `IoServices` の一時的な実装）と同じく記録する。R27 が、同じシグネチャのまま書き出し用のスレッドの中身に置き換える。

## 手順の要点

### IO の命令と送り出しの列（ADR 0264 の決定 1〜3）

`IO A B C` で処理する言語のハンドラがなければ（ハンドラの探索は R20）、VM は次の順に行う。

1. 実行中のタスクを `Scheduler::park(task, WaitReason::Response)` で待たせる。命令の位置は次の命令に進めておく。
2. `DispatchQueue::publish(task, op, site)` で要求を列に公開する。待たせてから公開する順は、すぐに完了する操作でも守る（ADR 0264 の決定 2）。
3. 待たせる位置の処理（10-10「完了の処理と行き詰まりの判定の順序」の関数）に進む。

`Response` は、要求を出してから処理が決まるまでの待ちである。直接呼び出しの方式でも、要求を処理するまではこの理由で待つ。

### 要求の処理（`serve`）

直接呼び出しの方式では `on_wait_point` が返した `ServeNow` の番号ごとに、要求と応答の方式では外側の実行器が `Vm::serve_request` を呼んだときに、同じ処理を行う。要求と呼び出しの命令を持つ場所は、10-10「送り出しの列と二つの部品」の段階の表のとおりである。

1. `DispatchQueue::take_for_serve(番号)` で要求を除く。`None`（取り消しか止める手順で失効した、または別の段階にある）なら何もしない。要求のタスクが番号の世代のまま `WaitReason::Response` で待っていなければ、`Stop::Internal` とする（失効させずに待ちを外す経路は作業の誤りである）。
2. 要求の `site` の命令を `CompiledProgram::builtin_call_operands` に渡し、引数のレジスタと結果のレジスタを求める。引数は待っているタスクの枠のレジスタから読む。
3. 組み込みの関数の `raw` を、`IoServices` として `IoView { rt, resources: &mut state.resources }` を渡した文脈で呼ぶ。応答で分ける。
   - `Done(v)`: 結果のレジスタに入れ、タスクを起こす。
   - `Wait(Worker(w))`: 後述の「仕事を出す手順」に進む。
   - `Wait(Sleep { millis })`: タイマーを登録してタスクを待たせる（R25 のタイマー）。
   - `Wait(Output { .. })`: R27 が中身を書く。本作業の一時的な `OutputPort` では起きない。
   - `Wait(Readiness { .. })`: U2 には、イベントループの準備を待つ組み込みの関数がない（HTTP は U3）。本作業では `Stop::Internal` を返す形で置き、U3 がイベントループの登録を使う形に書く。
   - `Exit(状態)`: 止める手順を `StopReason::Exit` で始める（止める手順のランタイムの部分は R28）。
   - `Err(Stop)`: 要求を出したタスクの `site` の命令で止まったものとして、止める手順を始める。

### 仕事を出す手順

応答が作業用のスレッドの仕事（`WorkerWait`）のときは、次の順に行う。途中で待つときは、要求と仕事を段階付きで `DispatchQueue::park_request` に戻し、待ちが解けたら `take_task_request` で取り出して、待った手順の続きから行う。組み込みの関数は呼び直さない。

1. `w.needs_output_flush()` が真で、まだ出力の転送の完了を待っていなければ、段階 `AwaitFlush(w)` で要求を戻し、タスクを `WaitReason::Output(stream, Flush)` で待たせる（R27 が中身を書く。本作業の一時的な `OutputPort` では転送がすぐに終わるので、この段階を通らずに手順 2 へ進む）。
2. `w.lend()` に従って貸すものを取り出す（`Lend::Resource` は `RunState::resources` の表の `ResourceTable::lend`、`Lend::Stdin` は `IoRuntime::stdin` を取り出す）。`MustWait` なら、段階 `AwaitLend(リソース, w)` で要求を戻し、タスクを `WaitReason::Lend(リソース)` で待たせる。`Released(種類)` なら、`site` の命令で `ReleasedResourceUsed` の実行時エラーとする。
3. 貸せたら、`ExtOpId` を付けて `OpRecord { kind: Worker, deliver_to: Some(task), lent, site }` を記録し、`WorkerJob { work: JobWork::Builtin(w), .. }` を `WorkerExec::submit` で出し、タスクを `WaitReason::Worker(番号)` で待たせる。要求はここで `live` から離れ、呼び出しの命令は記録の `site` が持つ。

要求を出したタスクを取り消したときと止める手順を始めたときは、外部の操作に移る前の要求を `expire_task`・`expire_all` で失効させ、応答の仕事を捨てる（相談の第 7 回の指摘 4、[ADR 0282](../../design/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。失効した要求は、後から処理を求められても（要求と応答の方式で外側の実行器が遅れて `serve_request` を呼ぶ、返却で返却を待つ並びが進む）何もしない。

### 二つの部品（ADR 0264 の決定 4）

- `DirectDispatcher::on_wait_point`: 列の要求の番号をすべて `ServeNow` で返す。VM は番号ごとに上の「要求の処理」を行う。途中の要求で止める手順が始まったら、残りの番号は失効しているので処理されない。
- `RequestDispatcher::on_wait_point`: 列に要求があれば、段階を `Outstanding` にして `ReturnToExecutor` で返す。列が空でも、段階が `Outstanding` の要求があり（`has_outstanding`）、呼ばれた位置が `WaitPoint::SlowPath` なら、空の `ReturnToExecutor` を返す（外側の実行器が届いた応答を渡せるようにする）。
- VM は `ReturnToExecutor(ids)` を受けたら、局所の状態を書き戻して `VmStep::Requests(ids)` を返す。進められるタスクが残っていても戻る（OPEN-062 の R02）。

### 待たせる位置と遅い経路の順序（10-10「完了の処理と行き詰まりの判定の順序」）

R25 が作った関数に、手順 1（`on_wait_point` と、ブロックする解放の仕事を出すこと）と手順 2（`WorkerExec::try_recv` で届いた完了をすべて取り込み、`accept_completion` で処理し、`Accepted` を順に処理する）を足す。手順 6 の待ちは、`WorkerExec::idle(次のタイマーの期限)` で行い、R25 の一時的な待ち（眠る、筋書きの時間を進める）を置き換える。R25 が手順 2 の位置に置いた筋書きの一時的な呼び出しは、テスト用の `WorkerExec::try_recv` に移す（10-10「テストで差し替える部品」の筋書きを進める境界）。予算を使い切った遅い経路の手順 2 でも、同じく手順 1・2 を行う（`WaitPoint::SlowPath`）。予算が残っているときの速い経路は、この二か所を飛ばすが、要求を置いたタスクは必ず待つので、待たせる位置を通る（ADR 0264 の決定 5）。

行き詰まりの判定（手順 5。R25 が作った）には、条件を足さない。外部の操作の記録と生きている要求は、それを待つタスクの待つ理由（`Worker`・`Readiness`・`Response`・`Lend`・`Output`）で数えられ、配送先を外した記録は数えない（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)。相談の第 7 回の指摘 6 への初めの対応では記録と要求の有無を条件に足したが、設計者の判断で改めた）。本作業は、外部の完了で起きるタスクを、必ず 10-10 の段階の表の「待つタスクの理由」で待たせる。

止める手順の途中も同じ関数を通り、手順 1〜3 で完了を取り込み続ける。返却を待って解放する枠と、ブロックする解放の完了を待つ枠があるからである。止める手順を始めるときに `expire_all` で生きている要求を失効させ、手順 5 では元の停止の理由を置き換えない。

### 完了の処理（ADR 0266 の決定 4、10-10 の `accept_completion`）

`accept_completion` は次の順に行い、VM が行うことを `Accepted` で返す。引数の `resources` には `RunState::resources` を渡す。個々の組み込みの関数には任せない。

1. 記録を表から除き、欄（種類、`deliver_to`、`site`）を取り出しておく。記録がなければ（起きないはずである）、`returned` を破棄して何も返さない。
2. `returned` を戻す。`LentOwned::Resource(番号, 資源)` は `ResourceTable::give_back` で戻し、`false` なら `Returned(番号)`、`true`（閉じる要求がある）なら `StartRelease(番号)` を加える。`LentOwned::Stdin(読み手)` は `stdin` の置き場に戻す。
3. 種類が `Release(番号)` なら、`outcome` の `Released(結果)` を `finish_release` で記録して `ReleaseFinished(番号)` を加える。`Panicked` なら失敗を記録せずに `finish_release(番号, Ok(()))` で `Released` にし、`ReleaseFinished(番号)` を加える。
4. `outcome` が `Panicked` なら、タスクが待っているかによらず `Bug(報告)` を加える。
5. そうでなければ、種類が `Worker` か `Readiness` の記録について、`deliver_to` があれば `Deliver { task, op, site, outcome }`、なければ `Dropped`（値と失敗だけを捨てる）を加える。

VM は `Accepted` を順に処理する（10-10「外部の操作の記録と完了」）。

- `Returned(番号)`: `pop_waiter` で返却を待つ並びの先頭のタスクを取り出し、そのタスクが `WaitReason::Lend(番号)` で待っていれば、`take_task_request` で要求（段階 `AwaitLend`）を取り出して、上の「仕事を出す手順」の手順 2 からやり直す。待っていなければ（取り消しで除き忘れた場合も含む）次のタスクを取り出す。
- `StartRelease(番号)`: `Scheduler::new_ext_op_id` の番号で `request_release` を呼ぶ。`Done(結果)` なら `finish_release` で記録して `ReleaseFinished` と同じく扱う。`Blocking` なら、次の手順 1 で仕事を出す。
- `ReleaseFinished(番号)`: `wake_all(WaitReason::Release(番号))` で解放を待つタスクを起こす。返却を待つ並びに残るタスクの要求も貸し出しからやり直し、「解放したリソースの使用」にする（10-10 の遷移の表の「操作の待ち × `Released`」）。
- `Bug`: panic 境界の処理（処理系の不具合、スレッドは作業用のスレッド）に移る。
- `Deliver { task, op, site, outcome }`: `task` が `WaitReason::Worker(op)` か `Readiness(op)` で待っていなければ、結果を捨てる。待っていれば、`site` から引数を読み直して `WorkerDone::complete` を呼び、結果の値を結果のレジスタに入れて `wake_if` で起こす。`complete` が `Err(Stop)` を返したら、そのタスクの `site` の命令で止まったものとして止める手順を始める。

取り消したタスクの外部の操作の記録は、R25 の取り消しの手順に `OpTable::detach_task` を足して、配送だけを外す。記録は完了するまで消さない（ADR 0266 の決定 3）。同じ手順に `DispatchQueue::expire_task` も足す。すべてのタスクが終わった後に残る外部の操作は待たない（同 決定 11）。

### ブロックする解放の仕事の受け渡し（相談の第 7 回の指摘 5）

R24 の `request_release` は、ブロックする解放で OS の資源を項目に残し、番号を `ResourceTable::release_jobs` に加える。本作業は、10-10「完了の処理と行き詰まりの判定の順序」の手順 1 の後に、`take_release_job` が返すものをすべて、種類 `Release(番号)` の記録（`deliver_to`・`lent`・`site` は `None`）として `OpTable` に加え、`WorkerJob { op, work: JobWork::Release(資源), lent: LentOwned::Nothing }` を `WorkerExec::submit` で出す。作業用のスレッドは `OsResource::release` を呼び、結果を `Outcome::Released` にして送る（panic なら `Panicked`）。解放を待つタスクは、完了の `ReleaseFinished` で起き、解放の枠が `take_release_failure` で失敗を読む（R24）。この受け渡しは、解放の枠（R24）、`StateServices::begin_release`（R25）、返却の後の解放（上の `StartRelease`）のどれから始めた解放にも使う。

### 作業用のスレッド（`WorkerExec` の実際の実装）

- 仕事を出すときに空いたスレッドがなければ新しく作り、数の上限を 64 とする。上限に達したら、仕事は空くまで列で待つ。空いたスレッドは実行の終わりまで残す（10-10「実装プランで決める値」）。
- スレッドは、`WorkerJob::lent` を `catch_unwind` の外で持ち、そこから借りた `Lent` を仕事に渡して `WorkerWait::run` を `catch_unwind` で囲んで呼ぶ（ADR 0266 の決定 9）。`JobWork::Release(資源)` は、`OsResource::release` を `catch_unwind` で囲んで呼び、結果を `Outcome::Released` にする。panic したら、panic の記録（02-09「panic 境界」のスレッドローカルな記録を取り出したもの）を `Outcome::Panicked` にし、貸したものを `returned` に入れて送る。
- 完了は `std::sync::mpsc` の channel で送り、`Wakeup::wake` でイベントループを起こす。
- `idle(deadline)`: イベントループ（`mio::Poll::poll`）を、次のタイマーの期限までの時間を上限に待つ。channel に完了があれば待たない。中断の要求でイベントループが起こされた（R28 が `Wakeup` を使って起こす）ときは `Interrupted` を返す。
- 実行ごとの状態を捨てるとき（`IoRuntime` を落とすとき）に、スレッドに終わるよう知らせる。終わっていない仕事を待たない（ADR 0266 の決定 11）。仕事が後で完了したときは、送り先がないので `returned` を破棄して OS の資源を閉じる。

### `WorkerExec` のテスト用の実装（ADR 0274 の決定 1）

`submit` は仕事を預かるだけにする。筋書きの「仕事を実行する」の指示で、預かった仕事を VM のスレッドでその場で実行し（`catch_unwind` と貸し出しの扱いは実際の実装と同じ）、完了を `try_recv` が返す列に置く。筋書きは R25 が決めた型を使う。指示を行う境界は、10-10「テストで差し替える部品」のとおり、完了の取り込み（`try_recv`）と `idle` に限る。`try_recv` は、筋書きの先頭から次のタスクを選ぶ指示の前までの「時間を進める」「仕事を実行する」の指示を行ってから、届いた完了を返す。予算を使い切った遅い経路でも `try_recv` を通るので、「タスク B が計算を続けている間に完了が届く」「取り消しの後に完了が届く」順序を筋書きの位置だけで決まった形で作れる。R25 が手順 2 の位置に置いた一時的な呼び出しは、ここへ移して消す。

### `run_program` の移し方

- `RunEnv` から `IoRuntime` を作る。`StdinSource::Process` はプロセスの標準入力をバッファ付きで読む読み手、`Empty` は空の読み手、`Bytes` は与えたバイト列の読み手にする。出力先は `OutputPort::start` で作る。部品は `RunEnv::parts` があればそれを、なければ `RuntimeParts::real` を使う。中断の読み口は `RunEnv::interrupt` を使う。
- `Vm::run` を呼び、`VmStep::Requests(ids)` なら要求ごとに `Vm::serve_request` を呼んでから `Vm::run` を呼び直す。`Finished` か `Stopped` になるまで繰り返す。
- VM の実行を `runtime::panic::catch` で囲む。終わり方から `RunEnd` を作る規則（10-13「実行の流れ」の表）は、F18 が第 1 段の実行の関数で書いたものを引き継ぐ。出力の最後の転送（`OutputPort::finish`）と転送の失敗の扱いは R27 が仕上げる。
- `RuntimeParts::real` の `Clock` は、R25 の実際の実装を使う。R25 が `RunState` に置いた `TaskPicker` と `Clock` の差し替えの口は、`IoRuntime::parts` を使う形に改めて消す。

## 受け入れテスト

テストは、スクリプトをパイプラインでコンパイルし、R25 のテスト用の部品（`WorkerExec` のテスト用の実装を含む）を渡して、二つの方式で実行する。

- 二つの方式で同じ結果: `File.readText` と `Console.writeLine` を使う既存のゴールデンテストのうち C05 が移したものが、`run_program` の置き換えの後も両方式で通る。
- 要求の送り出し（ADR 0264 の決定 5）: タスク A が `File.readText` を呼んで待ち、タスク B が長い計算を末尾再帰で続ける。要求と応答の方式で、A の要求が B の計算の終わりを待たずに `VmStep::Requests` で外側に渡る。直接呼び出しの方式では、A の要求が B の計算の途中で作業用のスレッドに出される（テスト用の実装が預かった時点で確かめる）。
- 完了の取り込み: 上の形で、筋書きが B の計算の途中で仕事を実行すると、A が B の計算の終わりを待たずに起こされる（予算の一巡りのうちに遅い経路で取り込む）。
- すぐに完了する操作: `Console.writeLine` を呼んだタスクも一度待ちに入り、同じ待たせる位置で起こされる。待ちの状態を上書きしない（相談の第 3 回の問い 1 の危険）。
- 完了の処理の順序（`accept_completion` の単体テスト）: 偽の資源を貸した記録に完了が届いたとき、先に資源が表に戻り（`Returned`）、`Deliver` が操作の番号と `site` を持つ。`deliver_to` を外した記録の完了は `Dropped` になり、資源は戻る。`Panicked` の完了は、タスクが待っていなくても `Bug` になり、資源は戻る。閉じる要求のある資源の返却で `StartRelease` が返る。種類 `Release` の記録の完了は、配送先がなくても `finish_release` まで行い、`ReleaseFinished` を返す。
- 配送の照合: タスク A の仕事の完了を、B の実行中（筋書きで B の計算の途中に実行）に取り込むと、A の `site` の結果のレジスタに結果が入る。完了の前に A が取り消されていれば、結果は捨てられ、A は通常の実行に戻らない。
- 失効した要求（二つの方式。相談の第 7 回の指摘 4）: 要求と応答の方式で、A の要求を外側へ返し、応答を渡す前に別のタスクが A を取り消す。その後に外側の実行器が同じ番号で `serve_request` を呼んでも、組み込みの関数は呼ばれず（副作用を記録する偽の組み込みの関数で確かめる）、A は `Cancelled` で終わる。直接呼び出しの方式では、`ServeNow` の途中の要求で止める手順が始まったとき、残りの要求の組み込みの関数が呼ばれない。どちらの方式でも、返却を待つ要求（段階 `AwaitLend`）のタスクを取り消すと、後の返却で要求がやり直されない。
- 返却の後の要求のやり直し（二つの方式）: 同じ偽の資源を貸す仕事を二つのタスクが順に求め、二つ目が `Lend` で待つ。一つ目の完了の後、二つ目の要求が組み込みの関数を呼び直さずに貸し出しからやり直され、正しい `site` の結果のレジスタに結果が入る。
- 返却の後の解放の完了を待つ（相談の第 7 回の指摘 1）: タスク A が偽の資源 r の貸し出しを待って返却を待つ並びに入り、取り消され、自分の解放の枠で `AfterReturn` を待つ。元の仕事が r を返すと、ブロックする解放が始まる（偽の資源をブロックする種類にする）。筋書きで解放の仕事の実行を後に回している間、A の枠とタスクは残り、A は `Done` にならない。解放の完了の後に枠が降り、A が `Cancelled` で終わる。解放が失敗する場合は、失敗が原因 `Cancel` の規則で報告される。
- ブロックする解放の受け渡し（相談の第 7 回の指摘 5）: テスト用の VM の補助で、ブロックする種類の偽の資源をリソースの表に加え、`USE`・`RETURN` の実際の命令の経路で解放する。`release_jobs` から仕事が出され（テスト用の `WorkerExec` が預かった仕事の種類で確かめる）、筋書きで実行すると `Outcome::Released` が取り込まれ、状態が `Released` になり、枠が降りる。解放が失敗する偽の資源では、`ReleaseFailed` の実行時エラーになり、報告の開いた位置が項目の `opened_at` である。`unwind_release` を直接呼んで完了を補助で記録するテストでは、この受け渡しの誤りを見つけられないので、この経路で確かめる。
- 作業用のスレッドの panic: 仕事の中で panic を起こす組み込みの関数はないので、`WorkerExec` の実際の実装に panic する仕事を直接出す単体テストで、完了が `Panicked` になり、貸したものが返ることを確かめる。
- 作業用のスレッドの上限: 実際の実装に、channel で止めておける仕事を 65 個出すと、64 個が始まり、1 個が待つ。一つを終わらせると待っていた仕事が始まる（実時間の待ちではなく、channel で順序を決めて確かめる）。
- 行き詰まりの判定（相談の第 7 回の指摘 6、[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）: 作業用のスレッドの仕事を待つタスクがある間は、ほかのタスクが互いを待っていても行き詰まりにしない。要求と応答の方式で、応答を待つタスクがある間も行き詰まりにしない。配送先を外した記録が借りている偽の資源の返却を `Lend` で待つタスクがある間も、行き詰まりにしない。待つタスクのない出力の転送は、R27 が確かめる。
- 取り消したタスクの終わらない標準入力の読み取りと行き詰まり（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）: タスク A が、標準入力の読み手を借りる（`Lend::Stdin`）偽の組み込みの関数を呼び、仕事を待つ。筋書きはこの仕事を最後まで実行しない（終わらない読み取り）。`Task.race` で先に B が終わり、A が取り消される。その後、残る二つのタスクが `Task` の値を入れたセルを通して互いを `Task.await` で待つ。A の配送先を外した記録が残ったまま、`TaskDeadlock` で止まり、`StopInfo::deadlock` に二つのタスクだけが並ぶ。実行は A の仕事の完了を待たずに終わる（ADR 0266 の決定 11）。二つの方式で確かめる。
- 止める手順の間の完了の取り込み: 偽の資源を貸した仕事の完了を筋書きで後に回し、その間に別のタスクで 0 の除算を起こす。止める手順の間も完了が取り込まれ、資源が戻ってから解放され、止まる理由は `DivisionByZero` のままである。
- 筋書きの消費: 上の順序に依存するテストは、筋書きの記録で、筋書きを使い切ったことと、仕事を実行した時点が狙ったとおりであることを確かめる。
- 残る外部の操作: 仕事が終わらないまま（筋書きが実行しないまま）すべてのタスクが終わると、実行は仕事を待たずに終わる。
- VM の単体テストのうち第 1 段の実行の関数を使っていたものが、第 2 段の実行の関数で通る。
- 根の置き場ごとの回収の強制（R03「根の列挙の引き渡し」の表の「待つ組み込みの関数の状態と完了の結果」の行）: `HeapConfig::stress` を真にした設定で、作業用のスレッドの仕事を待つ組み込みの関数の引数（定数の表に残らないヒープの値）が待つタスクの枠のレジスタだけに残る状態を作り、筋書きで仕事を実行する前に別のタスクで回収を起こす。完了の処理が読み直した引数と結果が正しいことを、二つの方式で確かめる（要求と応答の方式では、要求を返した後、応答を渡す前に回収する）。
- タスクの状態とリソースの状態の組み合わせのうち、作業用のスレッドを使う行（`Waiting(操作)` × `Lent(操作, 閉じる要求なし)`、`Unwinding` × `Lent(操作, 閉じる要求あり)`、`Done` × `Lent`）を、偽の資源を貸す単体テストで確かめる。プログラムからの確かめ（`File.readLine` を使うもの）は R29 と R30（OPEN-062 の R05）が行う。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 二つの方式の違いが、部品（`Dispatcher` の実装）の中だけにある（ADR 0264 の決定 4）
- 外部の操作に移る前の要求の呼び出しの命令が、10-10 の段階の表の場所だけにある
- 待たせる位置と遅い経路の順序が、どちらの方式でも一つの関数を通る
- `vm/stage1.rs` の関数と、それを呼ぶ箇所が残っていない
- `mio` の版と機能が上の記録（1.2.3、`os-poll`・`os-ext`）と一致するか、新しい版を使ったときはその版を完了の報告に書いている。`cargo deny check licenses` が通る
- 一時的な `OutputPort` を書いたことを、完了の報告の「残したこと」に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「スケジューラと IO」の行（タスクを待たせてから要求を公開しているか、待たせる位置と遅い経路で送り出しと取り込みを行っているか、完了の処理の順序）。
- 作業用のスレッドに渡すものに言語の値が入っていないか（型で防いであるが、`Send` の抜け道を作っていないか）。
- 完了を言語の値に変える処理が、待っているタスクの枠のレジスタから引数を読み直しているか（閉包に捕えていないか）。
- イベントループが VM を止めていないか。外部の操作の終わりを VM のスレッドで待っていないか。
- `mio` の型が `runtime::io::event` の外に出ていないか。

## 難易度の理由

二つの方式を一つの規則にまとめ、作業用のスレッド、イベントループ、完了の処理の順序、取り消しとの競合を同時に正しくする必要がある。順序の誤りはまれにしか起きないので、テスト用の部品で順序を与えて一つずつ確かめる。第 1 段の実行の関数から移す間も、既存のテストを通し続けなければならない。
