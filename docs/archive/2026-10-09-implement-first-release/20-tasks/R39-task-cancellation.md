# R39 タスクの取り消し

- 依存する作業: [R25](R25-tasks-and-scheduler.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R39-task-cancellation

## 目的

R25 が作ったタスクとスケジューラに、タスクの取り消しを加える。取り消しの要求（待っているタスクを起こすことを含む）、取り消しの手順（原因 `Cancel` で枠を降ろし、`TaskResult::Cancelled` で `Done` にする）、`handle` の枠と `TaskGroup` の解放の枠が属するタスク・子のタスクを取り消すこと、E-DropRel の途中に届いた取り消しの要求の扱い（ADR 0282 の決定 1）を書く。あわせて、取り消しを伴う三つの待ち方（`Task.allOk`・`Task.race`・`Task.withTimeout`）と、`Task.withTimeout` の期限のタイマーを書く。取り消したタスクを `Task.await` で待ったときの実行時エラー（`RuntimeError::AwaitedTaskCancelled`、診断コード R1002。[ADR 0317](../../2026-10-09-design-first-release/decisions/0317-await-on-cancelled-task-is-runtime-error.md)）も本作業が加える。

R25 は、取り消しの関数（R25「R39 へ残すもの」）を何もしない中身のまま残した。本作業はその中身を書く。R21・R22・R24 が「R25 で確かめる」とした経路のうち、取り消しを伴うもののテストも本作業で書く。

## 本作業が書く組み込みの関数

10-12 は、`Task.allOk`・`Task.race`・`Task.withTimeout` の三つの本体を本作業に割り当てる（10-11・10-12「作業の割り当て」）。どれも応答（`StateReply::SpawnTasks`）を組み立てるだけの短い関数であり、意味は応答を受けた VM の処理にある。単体テストは、独立した境界条件を持つ `Task.withTimeout` の期限の正規化（0 以下を 0 に直す）に限り、ほかは受け入れテストのスクリプトで確かめる（10-12「確かめること」、相談の第 7 回の指摘 9、[ADR 0284](../../2026-10-09-design-first-release/decisions/0284-task-builtins-tested-by-scripts.md)）。

## 読む設計書の節

- [並行処理](../../2026-10-09-design-first-release/01-spec/01-11-concurrency.md)の「タスクを起動する関数」「取り消し」「失敗と停止」「タスクとハンドラ」「タスクの集まり」、冒頭の「構造化」の決定
- [評価意味論](../../2026-10-09-design-first-release/01-spec/01-08-evaluation.md)の「実行時エラーによる停止」の表の「取り消したタスクの結果の待ち」の行
- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「タスクの起動と待ち方」、「取り消し」、「枠を降ろす原因と処理」の「取り消し、E-DropRel」の列、「タスクの切り替え」の取り消しの要求を調べる位置
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「タスクの待ちと取り消し」、「リソースの追跡」の `TaskGroup` の解放の箇条と、タスクの状態とリソースの状態の組み合わせの表
- ADR: [0266](../../2026-10-09-design-first-release/decisions/0266-task-and-resource-state-machines.md) の決定 1・3・5・6・7、[0282](../../2026-10-09-design-first-release/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)、[0152](../../2026-10-09-design-first-release/decisions/0152-task-allok-list-order.md)、[0164](../../2026-10-09-design-first-release/decisions/0164-taskgroup-release-while-stopping.md)、[0263](../../2026-10-09-design-first-release/decisions/0263-dispatch-loop-locals-and-verifier.md) の決定 3、[0317](../../2026-10-09-design-first-release/decisions/0317-await-on-cancelled-task-is-runtime-error.md)
- 検討資料: [相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 1・2・8（返却を待つ並びからの除去、`TaskGroup` の子の終わりを待つ親の取り消し、`Task.allOk` の取り消しの時点）、[相談の第 2 回](../studies/u2-runtime/consult/02-frames-and-dispatch.md)の問い 5（待っているタスクの取り消しには起こす処理が要ること）、[相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 4（`Lazy` を評価しているタスクと待つタスクの取り消し）

インターフェース:

- [仮想機械](../10-interfaces/10-09-vm.md)の「タスク」（`TaskObj::cancel_requested`・`spawn_wait`、`SpawnWait`、`TaskResult::Cancelled`）、「枠を降ろす原因と処理」（`UnwindWork::escalate`、「既に枠を降ろしているタスクの扱い」）、「作業の割り当て」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「タスクとスケジューラ」（`wake`・`wake_if`・`expire_timers`・`new_timer_id`）、「リソースの表と状態」（`remove_waiter`）、「完了の処理と行き詰まりの判定の順序」の手順 3
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `SpawnMode`・`Spawn`
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の `task` の部分
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `RuntimeError`（`AwaitedTaskCancelled`）、[診断](../10-interfaces/10-02-diagnostics.md)の `codes.rs` の R1002 の行と「実行時エラー、資源の不足、処理系の制限」の表

## 作るもの

- `src/vm/dispatch/tasks.rs`（R25 が置いた）と、その子のモジュール `src/vm/dispatch/tasks/cancel.rs`（新しく置く。`tasks.rs` に `pub(in crate::vm) mod cancel;` と宣言する。`unwind.rs` と `dispatch/resource.rs` から完全なパスで呼ぶので、`crate::vm` の中に公開する）: 取り消しの要求と手順、取り消しを伴う待ち方の結果の判断、タイマーの満了の扱い。本体は冷たい関数に置く（後述の「性能」）。`tasks.rs` では、ほかに次を直す。
  - `boundary`: タイマーの満了を `SpawnWait::timer` と照らすために、`NoGcCtx` を受け取るようにしてよい（後述の「タイマーの満了」）。
  - `deliver_all`: `AllOk`・`Race`・`WithTimeout` の結果と、取り消しの要求を受けた親の扱いを加える（後述の「取り消しを伴う待ち方」「子の終わりを待つ親の取り消し」）。
  - `deadlock`: 枠を降ろしているタスクの枠の位置を `UnwindWork::segments` からも引く（後述の「行き詰まりの判定と枠を降ろしているタスク」）。
- `src/vm/unwind.rs`: R21 が置いた `cancel_handle_members`（`handle` の枠が属するタスクを取り消す）と `cancel_requested`（E-DropRel を辿り終えた時点で取り消しの要求を読む）の中身。受け持つ関数の本体だけを書き換え、先頭の `use` の塊を変えない。補助の関数は `tasks/cancel.rs` に置き、完全なパスで呼ぶ（R22〜R24 の「並行の作業とのぶつかりの回避」と同じ書き方）。
- `src/vm/dispatch/resource.rs`: R24 が置いた `cancel_group_children`（`TaskGroup` の解放の枠が終わっていない子を取り消す）の中身。
- `src/vm/dispatch/unwinding.rs`: `traverse` の原因 `Cancel` の辿りの終わりを、`TaskResult::Cancelled` で `Done` にする処理に書き換える。今は、`traverse` の中の `UnwindCause::Cancel` の分岐が、「R25 が結果なしでタスクを Done にする処理を入れる」とコメントして `state.step = Some(VmStep::Requests(Vec::new()))` で止める仮の待ちの形である。
- `src/vm/state.rs`: `Stage1StateServices::task_poll` の `TaskResult::Cancelled` の分岐と、`Scheduling` の「期限の来た親の集合」の欄（後述の「タイマーの満了」）。`task_poll` の分岐は R25 が `Stop::Internal`（`awaited task has no result`）を返す形で書いた箇所であり、本作業が直してよい（後述の「取り消したタスクの待ち」）。
- `src/runtime/mod.rs`: `RuntimeError` に変種 `AwaitedTaskCancelled` を加える（10-08 の `file=` のとおり。ADR 0317 の帰結で凍結したコードに加えた変種である）。
- `src/diag/codes.rs`: R1002 の項目を、10-02 の `codes.rs` の表の R1001 の後に同じ文言で加える。10-02「番号の付け方」の「コードを加えるときは、作業を止めて報告する」には当たらない（ADR 0317 で加えると決めてある）。
- `src/runtime/report.rs`（R38 が書いた）: `Stop::Runtime(RuntimeError::AwaitedTaskCancelled)` から R1002 の診断を作る分岐と、型板の文言を確かめる表のテストの行。主な位置、呼び出しの履歴、タスクの起動の履歴は、R0801 などほかの実行時エラーと同じ規則で作る（R38「実行時エラー」）。
- `src/builtins/funcs/task.rs`: `Task.allOk`・`Task.race`・`Task.withTimeout` の本体（仮の本体を置き換える）と、`Task.withTimeout` の期限の正規化の単体テスト。
- 上のファイルのテストと、`tests/` の下の統合テストのファイル（置き場所は R25「テストの置き場所」と同じ。筋書きで順序を与えるテストはクレートの中のテストに置く）。

R25 が置いた `tasks.rs`・順序の関数・止める手順の関数と、R21・R24 が置いた上の関数は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。

## 手順の要点

### 取り消しの要求（02-08「取り消し」、02-09「タスクの待ちと取り消し」）

対象のタスクの `cancel_requested` を立て、`Budget::interrupt` で予算を 0 にする。対象は実行中のタスクではない（取り消すのは起動したタスクか、`handle`・`TaskGroup` の子である）ので、タスクの対象の `TaskObj::budget` に知らせる。R25 は予算を切り替えのときだけ移し合うので、待ち行列にあるタスクの予算は `TaskObj::budget` にある（R25「タスクの対象と実行中のタスク」）。取り消しの要求を既に受けたタスクには何もしない。タスクの表（`RunState::tasks`）にない番号への要求も、何もしない。R25 は終わったタスクを `TaskGroup` の並びと起動したタスクの `spawned` から外し、表からも除くので、終わったタスクへの要求はこの形で届く。

タスクが待っていれば、待ちを外して進められるタスクに戻す（`Scheduler::wake`。ADR 0263 の決定 3）。待ちを外すときは、待ちの表から除き、タイマーを外し、待たれるタスクの `awaiters` から外し（`TaskEndWait::Await(番号)` が番号を持つので引ける）、返却を待つ並びから `ResourceTable::remove_waiter` で除く（相談の第 7 回の指摘 1）。`Lazy` の待つタスクの並びからは外さなくてよい。`WaitReason::Lazy` は対象の `Lazy` を持たず、取り消しを呼ぶ関数は `CompiledProgram` を受け取らないので、並びを引けない。外さなくても、R22 の `lazy.rs` は待つタスクを `wake_if(task, WaitReason::Lazy)` で理由を照らして起こし、`TaskId` は世代付きなので、並びに残った古い項目が、取り消して終わったタスクや番号を使い回した別のタスクを誤って起こすことはない。取り消しの手順の間、タスクは `FORCE` を実行しないので、別の `Lazy` を待ち直して古い項目で起こされることもない。外部の操作の記録から配送を外す処理と外部の操作に移る前の要求を失効させる処理（R26）と、出力の待ちを取り下げる処理（R27）は、それぞれの作業がこの手順に足す。

次の待ちは外さない、または特別に扱う。

- 解放の枠の処理が返した `Wait(Release)` で待つタスク（解放の完了か、解放の前の返却を待つ。戻りの処理の途中でも、枠を降ろす途中でも）は、待ちを外さない。解放が終わって起きたときに取り消しの手順に移る（ADR 0266 の決定 5、10-09「既に枠を降ろしているタスクの扱い」）。貸し出しを受けるために返却を待つタスク（`lend` の `MustWait`。`WaitReason::Lend`）は、ほかの待ちと同じく起こし、返却を待つ並びから除く。
- 戻りの処理の途中で `TaskGroup` の解放の枠が子の終わりを待つタスク（`WaitReason::TaskEnd(TaskGroupRelease(番号))`）は、ほかの内部の待ちと同じく待ちを外す。取り消しの手順で同じ解放の枠が原因 `Cancel` で呼ばれ、終わっていない子を `cancel_group_children` で取り消して待つ（R24「`unwind_release`」の手順 5、相談の第 7 回の指摘 2）。
- E-DropRel で辿っているタスク（`Unwinding` で原因 `DropRel`）は、要求を記録するだけで、辿りの原因を変えない。`cancel_requested` の中身（タスクの対象の `cancel_requested` を読む）を書き、R21 の `traverse` が辿り終えた時点でこれを読んで、戻りの処理に進まずに `UnwindWork::escalate(残りの積み重ね, Cancel)` で取り消しの手順に移す（[ADR 0282](../../2026-10-09-design-first-release/decisions/0282-cancellation-timing-during-unwinding-and-requests.md) の決定 1）。待っていた場合の待ちの外し方は上の規則に従う（解放の待ちは外さず、属するタスクの終わりの待ちは外す）。
- 既に原因 `Cancel` か `Stop` で辿っているタスクへの要求は、何もしない。
- `SpawnWait` で子を待っている親（`WaitReason::TaskEnd(TaskEndWait::Spawned)`）は、待ちを外さず、子をすべて取り消す（後述の「子の終わりを待つ親の取り消し」）。

### 子の終わりを待つ親の取り消し（01-11「取り消し」「構造化」）

01-11「取り消し」は、`Task.all` などで起動したタスクの終わりを待っているタスクを取り消すと、待っていたタスクも取り消すと定める。01-11 冒頭の「構造化」の決定は、`Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout` が起動したタスクが、呼び出しの終わる時点ですべて終わっていることを求める。そこで、`SpawnWait` を持つ親を取り消すときは、子をすべて取り消し、子がすべて終わるのを待ってから、親の取り消しの手順に進む（オーケストレータの決定、2026-10-06）。

1. 取り消しの要求で、親の `cancel_requested` を立てて予算を 0 にする（ほかのタスクと同じ）。親は待ちを外さず、`WaitReason::TaskEnd(TaskEndWait::Spawned)` で待ち続ける。
2. 子の結果を親へ配らないように、`RunState::scheduling.deliveries` から親の項目を除く。`SpawnWait::timer` があれば、`Scheduler::timers` からそのタイマーを外し、「期限の来た親の集合」（後述の「タイマーの満了」）からも親を除く。
3. `SpawnWait::children` のうち終わっていない子（結果が `TaskResult::Pending`）すべてに取り消しの要求を出す。要求を既に受けた子（`Task.allOk`・`Task.race` が既に取り消した子を含む）には何もしない。
4. 子が終わるたびに R25 の `finish_task` が `deliver_all(親)` を呼ぶ。`deliver_all` は、`SpawnWait` の結果を判断する前に親の `cancel_requested` を確かめる。立っていれば、子の結果を一切書かない。終わっていない子が残れば何もせずに戻り、すべての子が終わっていれば、`SpawnWait` を取り出して `children` を `NoGcCtx::discard` で手放し（結果は捨てる）、`wake_if(親, TaskEnd(Spawned))` で親を起こす。
5. 起きた親は、選ばれたときに次の「取り消しの手順への移り方」で取り消しの手順に移る。このとき親の `SpawnWait` はなく、`pc` は待ち方の `PRIM` を指したままである。
6. 要求を出した時点で終わっていない子が一つもなければ（R25 では子が終わるたびに配るので起きないはずだが、確かめずに前提にしない）、手順 4 のすべての子が終わった場合と同じく、その場で `SpawnWait` を手放して親を起こす。

手順 4 で結果を書かないのは、取り消したタスクの結果を待ち方の結果に使わない（01-11）ためと、親の積み重ねに触れないためである。取り消しの手順に移った親の積み重ねの区画は `UnwindWork::segments` に移るので、`deliver_all` が親の `stack` に書こうとすると、R25 の `spawner segment missing` の `Stop::Internal` になる。手順 1 で親を待たせ続けるので、子が終わるまで親は取り消しの手順に移らないが、`deliver_all` は親の状態によらず `cancel_requested` を先に確かめる。

子が終わるのを待つ間にプログラム全体が止まるときは、止める手順の規則に従い、子の終わりを待たない（R25 の止める手順のとおり。`begin_stop_all` は `deliveries` を空にする）。

02-08「取り消し」の最初の段落は、取り消しの要求で「そのタスクが待っていれば進められるタスクに戻す」とし、例外を解放の待ちだけに挙げている（10-09「既に枠を降ろしているタスクの扱い」も同じ）。手順 1 で親の `TaskEnd(Spawned)` の待ちを外さないことは、本作業ではこの規則の例外として扱い、手順 1〜6 のとおりに書く。外から見える振る舞い（子がすべて止まり終えてから親が取り消しの手順で枠を降ろし、`Cancelled` で終わる）は、待ちを外して取り消しの手順の始めで子を待つ形と変わらない。

### 取り消しの手順への移り方

取り消しの要求を受けたタスクは、次に切り替えの位置の遅い経路の手順 3.1（待っていたタスクは、進められるタスクに戻って選ばれたとき）で取り消しの手順に移る。R25 が作った「進めるタスクを選んだら命令を実行する前に行う」確かめに、取り消しの要求の確かめを加える。子の終わりを待っていた親は、子がすべて終わって起こされた後にここを通る（前述の手順 5）。状態を `Unwinding(UnwindWork { cause: Cancel, .. })` にし、積み重ねの区画をすべて移して、R21 の辿りの関数で降ろす。`ReturnWork` があれば（戻りの処理の途中で `handle` の枠が属するタスクや `TaskGroup` の子を待っていたなど）、`NoGcCtx::discard` で手放して消し、呼び出しの前の安全点の印も消す。

`handle` の枠（原因 `Cancel`・`DropRel`）の `cancel_handle_members` は、`HandlerRecord::members` の終わっていないタスクに取り消しの要求を出す。残れば `unwind_handle` が `Wait(TaskEnd(HandleEnd))` を返して止まり終えるのを待つ（R21）。`TaskGroup` の解放の枠（原因 `Cancel`・`DropRel`）の `cancel_group_children` は、子の並びの終わっていないタスクに取り消しの要求を出す（要求を既に受けた子には何もしない）。残れば R24 の分岐が `group_children_pending`（R25）で調べて待つ。

### 取り消しの終わり（`traverse` の原因 `Cancel`）

辿り終え、解放の失敗がなければ、`TaskResult::Cancelled` で `Done` にし、R25「タスクの終わりと待ち方の結果」と同じく、起動したタスクと `awaiters` と `handle` と `TaskGroup` に知らせる。取り消したタスクの結果は、待ち方の結果に使わない。解放の失敗があれば、辿り終えてから実行時エラー（`ReleaseFailed`）とし、プログラム全体を止める（01-11「失敗と停止」。今の `traverse` が `log` の失敗を `Err` にする経路のとおり）。

### 取り消しを伴う待ち方（02-08「タスクの起動と待ち方」、01-11「タスクを起動する関数」）

R25 の起動の手順（R25「タスクの起動」）に、`AllOk`・`Race`・`WithTimeout` を加える。起動した `Task` の値を `SpawnWait::children` に起動した順に置き、`WaitReason::TaskEnd(TaskEndWait::Spawned)` で起動したタスクを待たせる点は `All` と同じである。`funcs` が空なら、タスクを作らずに結果を返す（`AllOk` は `Result.Ok` の空のリスト、`Race` は `Option.None`）。`WithTimeout` は子が一つであり、`Scheduler::new_timer_id` の番号で期限 `millis`（0 以下は 0。本体が直してある）のタイマーを登録して `SpawnWait::timer` に入れる。

子が終わるたびに（取り消して終わった場合を含む）、起動したタスクの `SpawnWait` で次のように判断する。

- `AllOk`: 起動した順の i 番目の子が `Result.Error` を返したら、i より後ろの終わっていない子を取り消し、i より前の子の終わりを待つ。i より前の子がすべて `Result.Ok` なら i 番目の `Result.Error` を結果とする。i より前の子が `Result.Error` を返したら、その子について同じ規則を繰り返す。すべてが `Result.Ok` なら値のリストの `Result.Ok`（ADR 0152）。
- `Race`: 最初に終わった子の結果の `Option.Some` を結果とし、ほかの子を取り消す。
- `WithTimeout`: 期限の前に子が終われば、タイマーを外して結果の `Option.Some`。期限が来たら子を取り消して `Option.None`。親が「期限の来た親の集合」にあれば、子の終わり方によらず `Option.None` とし、集合から親を除く（後述の「タイマーの満了」）。
- 取り消す子を持つ待ち方では、取り消した子がすべて止まり終えてから結果を返す。
- 親が取り消しの要求を受けていれば、上の判断をせずに前述の「子の終わりを待つ親の取り消し」の手順 4 に従う。

結果を起動したタスクの `PRIM` の結果のレジスタに入れ、命令の位置を次へ進めて（回収を挟まずに一続きに。後述の「回収の前の整理」）、`wake_if(…, TaskEnd(Spawned))` で起動したタスクを起こす。

行き詰まりの記録の待つ種類（`DeadlockWaitKind::Builtin`）は、R25 は `TaskEnd(Spawned)` をすべて `"Task.all"` としている。`SpawnWait::mode` に合わせて `"Task.allOk"`・`"Task.race"`・`"Task.withTimeout"` を出し分ける（`Task.withTimeout` はタイマーがあるあいだ行き詰まりにならないが、期限が来て子を取り消した後は待つ種類として現れうる）。

### タイマーの満了

`Task.withTimeout` の親は `TaskEnd(Spawned)` で待つので、タイマーの満了を `wake_if(…, Timer(番号))` では起こせない。R25 が作った順序の関数の手順 3（`tasks.rs` の `boundary`）では、`Scheduler::expire_timers` の結果を、`Timer` の待ちを起こす前に、そのタスクの `SpawnWait::timer` と照らす。一致すれば、子を取り消し、期限が来たことを記録する（結果の `Option.None` は、取り消した子が止まり終えてから返す）。一致しなければ、R25 のとおり `wake_if(…, Timer(番号))` で起こす。期限の前に子が終わってタイマーを外した後に、古い満了を受けないようにする（タイマーを外すのは `Scheduler::timers` から除くことである）。

期限が来たことの記録先: `SpawnWait`（10-09 の `file=`、凍結）には記録する欄がない。記録は、`RunState::scheduling`（`src/vm/state.rs` の `Scheduling`。凍結の外）に加える「期限の来た親の集合」（例 `timed_out: BTreeSet<TaskId>`。名前は作業が決める）に親の番号を入れる形で行う。`deliver_all` は `WithTimeout` の結果をこの集合で判断する。親が終わるとき（`finish_task`）、親が取り消されるとき（前述の手順 2）、止める手順に移るときに、集合から親を除くか集合を空にして、古い番号を残さない。

`SpawnWait::timer` と照らすには親の `TaskObj` を読む `NoGcCtx` が要るが、R25 の `boundary(state)` は受け取らない。R25 の手直しで、`boundary` は切り替え（`Switch`）のときだけ `switch()` の中で呼ぶ形になっている。これを前提に、`boundary` の引数に `&mut NoGcCtx` を足してよい（`boundary` は R25 の非公開の関数であり、凍結の外である）。

### 取り消したタスクの待ち（ADR 0317）

取り消したタスクを `Task.await` で待つと、待ったタスクの側で実行時エラー `RuntimeError::AwaitedTaskCancelled`（R1002）として止まる（01-11「取り消し」、[ADR 0317](../../2026-10-09-design-first-release/decisions/0317-await-on-cancelled-task-is-runtime-error.md)）。

- `Stage1StateServices::task_poll`（`src/vm/state.rs`）の `TaskResult::Cancelled` の分岐を、`Err(internal("awaited task has no result"))` から `Err(Stop::Runtime(RuntimeError::AwaitedTaskCancelled))` に改める。R25 が書いた箇所だが、本作業が直してよい。
- 止まった命令は `Task.await` の `PRIM` である。待つ時点で既に取り消して終わっていれば、その場で `task_poll` が返す。待っている間に待たれるタスクが取り消して終わったときは、R25 の `finish_task` が `awaiters` を `wake_if(…, TaskEnd(Await(番号)))` で起こし、起きたタスクが `PRIM` を実行し直して `task_poll` が返す（R25「回収の前の整理」の `Task.await` の待ち）。どちらも、ほかの組み込みの関数の実行時エラーと同じ経路で `StopInfo` を作るので、知らせの仕組みと止める手順は変えない。
- 待つタスク自身が取り消しの要求を受けていれば、起きた後は `PRIM` を実行せずに取り消しの手順に移るので、この実行時エラーにはならない（後述の受け入れテストの「起こす理由の照合」）。

### 行き詰まりの判定と枠を降ろしているタスク（R25 からの申し送り）

R25 の行き詰まりの判定（`tasks.rs` の `deadlock`）は、待つ命令の位置と、`handle` の枠・`TaskGroup` の解放の枠の `at` を `task.stack` からだけ探す。E-DropRel や取り消しの辿りで `HandleEnd`・`TaskGroupRelease` を待つタスクは、辿る区画を `UnwindWork::segments` に移しているので、`task.stack` が空か継続の外の区画だけになり、`deadlock location missing` の `Stop::Internal` になる。

`TaskState::Unwinding(work)` のタスクでは、`work.segments`（最後の要素が最も上の区画）を `task.stack` の区画より上にあるものとして扱い、呼び出しの枠、`handle` の枠の `at`、解放の枠の `at` を、両方を合わせた並びの上から引く。呼び出した命令の並び（`DeadlockWaiter::call_sites`）も同じ並びから作る。

### 回収の要求の確かめ

回収の要求は、確保する分岐の中で確かめる（R25「回収の要求の確かめ」、ADR 0263 の決定 4）。本作業では、待ち方の結果（`Task.allOk` の `Result.Ok` の値のリストと `Result.Ok`、`Result.Error` を返すときに作る値、`Task.race`・`Task.withTimeout` の `Option.Some`）を作った分岐の中で、結果を書いて命令の位置を進めた後に `notify_collect` を呼ぶ（R25 の `deliver_all` の `Task.all` と同じ位置）。確保しない分岐（子の結果をそのまま返す、確保の要らない値を返す、取り消した親の結果を捨てる）と、取り消しの要求と手順には足さない。

### 凍結した戻り値で処理系の不具合を扱う方法

R24・R25 と同じく（R25「凍結した戻り値で処理系の不具合を扱う方法」）、本作業が使う次の関数の戻り値は `Result` ではない。シグネチャは変えずに、R25 の `Scheduler::check_park` に倣って扱う。

- `unwind.rs` の `cancel_requested -> bool`: タスクの対象が引けないなどの食い違いを `bool` では返せない。非公開の確かめの関数（例 `Result<bool, Stop>` を返す関数。名前は作業が決める）を `tasks/cancel.rs` に置き、`traverse` はそれを先に呼んで食い違いを `Stop::Internal` で返す。`cancel_requested` の中では確かめを通った入力を前提にし、到達しないはずの分岐は `debug_assert!` で示したうえで `false` を返す。到達しない理由をコメントに書く。
- `Scheduler::wake -> ()`・`wake_if -> bool`・`ResourceTable::remove_waiter -> ()`: 待っていない・並びにないタスクに対して何もしないのは定めた振る舞いであり、不具合ではない。取り消しの要求の手順は、待つ理由を呼ぶ前に `Scheduler::waiting` から読み、理由ごとの扱い（外す、外さない、親として待たせ続ける）を決めてから呼ぶ。`TaskObj::state` の `Waiting` は切り替えのときに書かれ、`wake` では改まらないので、待っているかの判断に使わない。理由ごとの扱いの前提が崩れていること（例: `TaskEnd(Spawned)` で待つのに `spawn_wait` がない）は、呼ぶ前に照らして `Stop::Internal` で返す。

### 回収の前の整理（ADR 0314）

R25 と同じく、本作業が加える状態を [ADR 0314](../../2026-10-09-design-first-release/decisions/0314-clear-dead-registers-at-safepoints.md) の決定 5 の「命令の入口」と「結果が書かれる前の呼び出し元」のどちらかに分類する表を、完了の報告に書き、分類どおりに空にする。少なくとも次の状態を表に入れる。

- `Task.allOk`・`Task.race`・`Task.withTimeout` の子を待つ `PRIM`: 待つ間は「命令の入口」。結果の配送は、結果の書き込みと命令の位置の更新を、回収を挟まずに一続きに行う（相談の第 9 回の指摘 2。R25 の `Task.all` と同じ）。取り消した子が止まり終えるのを待つ間も、結果はまだ書かない。
- 取り消しの手順に移ったタスク: 積み重ねの区画は `UnwindWork::segments` に移るので整理せず、保守的に残す（R21）。
- 取り消しで待ちを外されたタスク（取り消しの手順に移る前）: 待っていた位置の分類（R25 の表）のまま。
- 取り消しの要求を受け、子が止まり終えるのを待つ親（前述の「子の終わりを待つ親の取り消し」）: 待つ間は「命令の入口」（`pc` は待ち方の `PRIM` を指したまま）。結果は書かない。

分類を確かめていない状態は、空にしない。

### 性能

普通の経路（`CALL`・`TAILCALL`・`RETURN` の速い経路、`PRIM` の純粋な関数の経路、`execute` のループの頭）に処理を足さない。取り消しの要求の確かめは、R25 の切り替えの冷たい経路（進めるタスクを選んだ後）と、遅い経路の手順 3.1 にだけ置く。取り消しの要求は予算を 0 にして知らせるので、`tick` の速い経路に印の確かめを足さない。本体は `tasks/cancel.rs` の冷たい関数（`#[cold]`・`#[inline(never)]`）に置く。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（R40 の後と最後に、オーケストレータが行う）。

## 受け入れテスト

テストの書き方は R25 の受け入れテストと同じである（予算を小さくした実行と筋書きで順序を変えた実行を並べ、筋書きの記録で狙った順序になったことを確かめる）。解放の順序と失敗は、プログラムから開ける失敗するリソースがまだない（`File.openReader` は R29）ので、R24 と同じ偽の資源を使う VM の単体テストで確かめる。

- 組み込みの関数の単体テストは、`Task.withTimeout` の期限の正規化（0 以下を 0 に直す）に限る。ほかの二つは下のスクリプトのテストで確かめる。
- `Task.allOk`: 1 番目と 3 番目が `Result.Error` を返す場合に、終わる順によらず 1 番目の `Result.Error` を返す。1 番目が `Result.Error` を返したと確かめた後で、2 番目以降の終わっていないタスクが取り消され、取り消したタスクが止まり終えてから結果が返る（ADR 0152）。空のリストで `Result.Ok` の空のリスト。
- `Task.allOk` の取り消しの時点（相談の第 7 回の指摘 8）: 筋書きで「3 番目が `Result.Error` で終わる → 1 番目が `Result.Ok` で終わる → 2 番目が `Result.Error` で終わる」の順にする。2 番目は途中で取り消されず、結果は 2 番目の `Result.Error` である。3 番目の失敗の時点で 2 番目を取り消す誤りを、このテストで見つける。
- `Task.race`: 最初に終わったタスクの結果の `Option.Some`。ほかのタスクが取り消され、取り消したタスクが `with` で開いていた `TaskGroup` の子も取り消されてから結果が返る。空で `Option.None`。
- `Task.race` と `TaskGroup` の終わりを待つ親（相談の第 7 回の指摘 2。`TaskGroup` の解放の枠の原因 `Cancel` の経路）: `Task.race` で起動したタスク P が、`with` で開いた `TaskGroup` に長い計算の子 C を `spawn` して `with` を抜け、C の終わりを待っている（本体の実行中ではなく、解放の枠で待っている）間に、別のタスクが先に終わって P が取り消される。C が取り消されて止まり終え、その後に P が `Cancelled` で終わり、それから `Task.race` の結果が返る。C が残ったまま結果が返らない。
- `Task.withTimeout`: 仮想の時間で、期限の前に終わる場合と期限が来る場合。期限が 0 以下の場合。期限の前に終わった後に時間を進めても、古いタイマーの満了で親が起こされない。子と別のタスクが互いを `Task.await` で待ち合っていても、期限のタイマーがあるあいだは行き詰まりにせず、期限が来て子が取り消される（R25 は `is_deadlocked` を `Scheduler` の単体テストで確かめた。ここではスクリプトで確かめる）。
- 子の終わりを待つ親の取り消し（オーケストレータの決定、2026-10-06）: `Task.race` で起動したタスク P が `Task.all` で長い計算の子を二つ起動して待っている間に、別のタスクが先に終わって P が取り消される。P の子が二つとも取り消されて止まり終え、その後に P が `Cancelled` で終わり、それから `Task.race` の結果が返る。子が終わるときに P の積み重ねへ結果が書かれず、`Stop::Internal`（`spawner segment missing` など）にならない。筋書きで、一つ目の子が止まり終えた時点で P がまだ取り消しの手順に移っていない（待ちを外されていない）ことも確かめる。`Task.withTimeout` で待つ P を取り消した場合に、外したタイマーの古い満了が P にも「期限の来た親の集合」にも残らないことを、仮想の時間を進めて確かめる。
- 取り消したタスクの待ち（ADR 0317）: (a) タスク P が `with` で開いた `TaskGroup` に長い計算の子 C を `spawn` し、C の `Task` の値を `Reference` に入れる。`Task.race` で P が取り消され、C も取り消される。`Task.race` の後に `main` が `Reference` から C の値を読んで `Task.await` で待つと、`RuntimeError::AwaitedTaskCancelled` で止まり、`StopInfo::at` がその `Task.await` の `PRIM` の命令である。(b) 別のタスク W が C を `Task.await` で待っている間に（筋書きで、W が待ち始めてから P を取り消す順にする）C が取り消して終わると、W が起こされ、同じく `AwaitedTaskCancelled` で止まり、`at` が W の `Task.await` の `PRIM` である。(c) `runtime::report` の表のテストに、`AwaitedTaskCancelled` から R1002 と文言 `the awaited task was cancelled, so it has no result` を作る行を加える。
- 起こす理由の照合: `Task.await` で待つタスクを取り消した後に待たれていたタスクが終わっても、取り消したタスクが通常の実行に戻らない。
- 取り消し: 待っているタスク（`Task.await` で待つタスク、`Lazy` を待つタスク）を取り消すと、起こされて止まる。取り消したタスクの解放の枠が内側から解放され、途中の解放の失敗が辿り終えてから `ReleaseFailed` になる。
- 返却を待つ並びからの除去: `WaitReason::Lend` で待つタスク（テスト用の補助で `lend` の `MustWait` の状態を作る）を取り消すと、起こされ、返却を待つ並びから除かれる。解放の完了を待つタスク（`WaitReason::Release`）を取り消しても待ちが外れず、解放の完了の後に取り消しの手順に移る。
- `Lazy` と取り消し（R22 からの引き渡し。相談の第 3 回の問い 4）: 二つのタスクが同じ `Lazy` を `force` し、評価しているタスクだけを取り消すと、残る待つタスクが評価をやり直して結果を得る。待つタスクだけを取り消すと、評価しているタスクは影響を受けない。
- E-DropRel の途中の取り消し（R21 からの引き渡し）: 節が `resume` せずに終わり、捨てる継続の中の偽の資源の解放を待っている間に、そのタスクを取り消す。解放の待ちが外れず、解放の完了の後に通常の実行に戻らず（`handle` の後の式が実行されない）、残りの枠が取り消しとして降ろされ、解放がちょうど一度ずつ呼ばれ、タスクが `Cancelled` で終わる。
- 既に辿っているタスクの全体の停止（R21 からの引き渡しのうち、R25 が確かめない二つ）: (a) 取り消しで属するタスクの終わりを待っているタスク、(c) E-DropRel で `handle` の枠が属するタスクの終わりを待っているタスクのそれぞれがあるときに、別のタスクで 0 の除算を起こす。子のタスクの終わりを待たずに止める手順が終わる。解放は一度ずつ呼ばれ、`escalate` の前に集めた解放の失敗が `StopEnd::release_failures` に残り、止まる理由は `DivisionByZero` のままであり、捕まえた継続の中の `update` の枠の `Lazy` を待つタスクが起こされない。(b) E-DropRel で解放の完了を待っているタスクの場合は R25 が確かめた。加えて、(d) 取り消しの辿り（原因 `Cancel` の `Unwinding`）で偽の資源の解放の完了を待っているタスクがあるときに、別のタスクで 0 の除算を起こす。解放の完了の待ちが外れずに `escalate(…, Stop)` で原因が `Stop` に改まり、解放の完了の後に残りの枠が全体の停止として降ろされ、解放が一度ずつ呼ばれ、取り消しの辿りで集めた解放の失敗が `StopEnd::release_failures` に残り、止まる理由は `DivisionByZero` のままである。
- 行き詰まりの判定と枠を降ろしているタスク（R25 からの申し送り）: `TaskState::Unwinding` で `HandleEnd`・`TaskGroupRelease` を待つタスク（E-DropRel の辿りと、取り消しの辿りのそれぞれ）を含む待ちの表で行き詰まりを判定すると、`Stop::Internal` にならず、そのタスクの `DeadlockWaiter::at` が `handle` の枠の `HANDLE`・解放の枠の `USE` の命令になる。スクリプトでこの状態を作れなければ、テスト用の補助で状態を組み立てる VM の単体テストで確かめる。`Task.allOk`・`Task.race` の子を待つ親が行き詰まりに入ると、待つ種類がそれぞれ `Task.allOk`・`Task.race` になる。
- タスクの状態とリソースの状態の組み合わせ（02-09「リソースの追跡」の表）のうち、取り消しを使い作業用のスレッドを使わない行（原因 `Cancel` の `Unwinding` × `Releasing`、取り消しで外す待ち × `Lent`・`Released`）。
- 根の置き場ごとの回収の強制: `HeapConfig::stress` を真にした設定で、取り消した子が止まり終えるのを待つ間の `SpawnWait::children`（終わった子の結果だけが `Task` の値から辿れる状態）と、取り消しの手順の途中で解放の完了を待つ `UnwindWork` の区画で回収し、その後の結果が正しいことを確かめる。
- 回収の強制のビルドで、上のテストがすべて通る。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- R25「R39 へ残すもの」の関数と経路に、何もしない中身と仮の待ちの形が残っていない
- `src/vm/dispatch/unwinding.rs` に `VmStep::Requests(Vec::new())` で止める仮の形が残っていない
- `task_poll` に `awaited task has no result` の `Stop::Internal` が残っておらず、`RuntimeError::AwaitedTaskCancelled`・`DiagCode::R1002`・`runtime::report` の分岐が 10-08・10-02 のとおりにある
- 実時間の待ちやスレッドの実行の順序の偶然に頼るテストがない（[実装の規約](../00-common/00-02-conventions.md)の「テストの規約」）

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」と「スケジューラと IO」の行。
- 待っているタスクの取り消しで、そのタスクを起こしているか（解放の完了の待ちは除く）。返却を待つ並びから除いているか。
- E-DropRel の途中の要求を記録だけにし、辿り終えてから `escalate` で取り消しの手順に移っているか。次の切り替えの位置を待っていないか。
- 取り消したタスクの結果を、待ち方の結果に使っていないか。取り消した子が止まり終える前に結果を返していないか。
- `Task.allOk` で、i 番目の失敗の時点で i より前の子を取り消していないか。
- `Task.withTimeout` の満了を、`SpawnWait::timer` と照らしてから扱っているか。外したタイマーの古い満了で親を起こしていないか。「期限の来た親の集合」に古い番号を残していないか。
- 子の終わりを待つ親を取り消したとき、子がすべて止まり終えるまで親を取り消しの手順に移さず、子の結果を親へ書いていないか。
- 取り消したタスクの `Task.await` が、処理系の不具合ではなく `AwaitedTaskCancelled` で止まり、止まった命令が `Task.await` の呼び出しか。

## 難易度の理由

取り消しは、待つ理由ごとに外すか外さないかが違い（解放の完了は外さず、返却の待ちは外して並びから除き、子の終わりの待ちは外して同じ枠を原因 `Cancel` で処理し直す）、E-DropRel の途中では記録だけにする。表の一つの升目を取り違えると、解放の前に枠を降ろす、取り消したタスクが通常の実行に戻る、結果が返らないといった、順序を与えなければ再現しない誤りになる。`Task.allOk` の結果の規則も、終わる順によらず同じ結果にするために、取り消す範囲と待つ範囲を正しく分ける必要がある。
