# R25 タスクとスケジューラ

- 依存する作業: [R24](R24-resources.md)、[R22](R22-lazy.md)、[R23](R23-reference-cells.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/R25-tasks

## 目的

タスクを VM に加える。タスクの対象とタスクの表、取り消しを除くタスクの状態の遷移（`Ready`・`Waiting`・原因 `Stop`・`DropRel` の `Unwinding`・`Done`。ADR 0266 の決定 1）、切り替えの位置での切り替え、タスクの起動と、取り消しを伴わない待ち方（`Task.all`・`TaskGroup.spawn`・`Task.await`）、`handle` に属するタスクの記録と待ち（ADR 0266 の決定 6・7）、`Lazy`・`handle` の終わり・`TaskGroup` の解放（原因 `Return`）・リソースの解放の待ちと起こし方、行き詰まりの判定、止める手順のすべてのタスクへの拡張を書く。

あわせて、テストでスケジュールを決めるための部品（次に進めるタスクを選ぶ部品と仮想の時間。ADR 0274）と、その筋書きの型を作る。R39 以降の作業と、OPEN-062 の再現テスト（R30）、ランタイムのゴールデンテスト（C12）は、この部品で切り替えの順序を与えてテストを書く。

タスクの取り消しと、取り消しを伴う三つの待ち方（`Task.allOk`・`Task.race`・`Task.withTimeout`）は、本作業の後の [R39](R39-task-cancellation.md) が書く。本作業の時点では、R21・R24 が置いた取り消しの関数（後述の「R39 へ残すもの」）は何もしない中身のまま残る。

R20〜R24 が「タスクを起動できないので R25 で確かめる」とした経路のうち、取り消しを伴わないもの（引き継いだハンドラ、`Lazy` を待つタスク、セルの更新のやり直し、`handle` と `TaskGroup` が子のタスクを待つこと、待ちをまたぐ戻りの再開状態）のテストも、本作業で書く。取り消しを伴うものは R39 が書く。

## 本作業が書く組み込みの関数

10-12 は、`Task.all`・`Task.await`・`TaskGroup.open`・`TaskGroup.spawn` の四つの本体を本作業に、`Task.allOk`・`Task.race`・`Task.withTimeout` の三つを R39 に割り当てる（10-11・10-12「作業の割り当て」）。本作業の受け入れテストはタスクを起動しなければ書けず、R29 は本作業より後（R26・R27 の後）だからである。どれも応答（`StateReply`）を組み立てるだけの短い関数である。[ADR 0273](../../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md) の U2 と U3 の境目は変わらない。

四つの意味は、応答を受けた VM の処理（起動、待ち方）にある。そこで、応答の構造をそのまま期待値にする単体テストは書かず、受け入れテストのスクリプトで各項目を呼んで確かめる（10-12「確かめること」、相談の第 7 回の指摘 9、[ADR 0284](../../design/decisions/0284-task-builtins-tested-by-scripts.md)。ADR 0276 の決定 4 の例外）。

本作業は R23 のセルの関数をテストで使うので、R23 にも依存する。

## スケジューラとリソースの表の置き場所

スケジューラは `RunState::scheduler`、リソースの表は `RunState::resources` である（どちらも R20 が置いた。10-09「実行ごとの状態」）。本作業は `Scheduler` の関数の中身を書き、`RunState::scheduler` のスケジューラとして使う。

## 読む設計書の節

- [並行処理](../../design/01-spec/01-11-concurrency.md)の全体（取り消しの節は、R39 との境目を知るために読む）
- [仮想機械](../../design/02-impl/02-08-vm.md)の「実行ごとの状態のうち VM が使うもの」（タスクに関わる参照の持ち方の表と、`Done` にするときに外すもの）、「組み込みの関数の呼び出し」（応答の表と、待つ理由と起こす規則の表）、「タスクの切り替え」（全体）、「タスクの起動と待ち方」、「実行時エラーの情報の記録」（タスクの起動の履歴と行き詰まりの材料）、「止める手順」、「実行の開始と終わり」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「タスクの待ちと取り消し」、「リソースの追跡」の `TaskGroup` の解放の箇条
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「順序を与えるスケジューラと仮想の時間（初回リリース版）」「ほかの章が求めるテスト（初回リリース版）」のタスクの行、「ヒープとランタイムの確かめ方（初回リリース版）」の最後の行
- ADR: [0161](../../design/decisions/0161-single-threaded-task-scheduler.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md)、[0274](../../design/decisions/0274-deterministic-scheduler-and-virtual-time-for-tests.md)、[0263](../../design/decisions/0263-dispatch-loop-locals-and-verifier.md) の決定 3、[0151](../../design/decisions/0151-inherited-handlers-tail-resume-only.md)、[0153](../../design/decisions/0153-taskgroup-open-only-in-with.md)、[0164](../../design/decisions/0164-taskgroup-release-while-stopping.md)、[0238](../../design/decisions/0238-task-wait-deadlock-as-runtime-error.md)
- 検討資料: [相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 1・6・7・9（起こす理由の照合と返却を待つ並びからの除去、行き詰まりの判定の条件、筋書きを進める境界、応答の形だけのテストの削減）、[相談の第 2 回](../studies/u2-runtime/consult/02-frames-and-dispatch.md)の問い 5（予算の 0 のときの減算、末尾呼び出しとハンドラの節の暗黙の呼び出し、回収の要求を実行全体で持つこと）、[相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 3（`handle` を本体が終わり属するタスクが 0 になるまで残すこと、孫の登録は親を終わったとする前に行うこと、行き詰まりの判定に返却・解放・出力の完了の待ちを含めること、止める途中で元の理由を置き換えないこと）、[相談の第 6 回](../studies/u2-runtime/consult/06-plan-vm-review.md)の指摘 1・2・6（待ちをまたぐ戻りの再開状態、既に辿っているタスクの全体の停止、引き継いだハンドラの直接の実行の繰り返し）

インターフェース:

- [仮想機械](../10-interfaces/10-09-vm.md)の「実行ごとの状態」、「タスク」（全体）、「ハンドラの記録、継続、`Lazy`」、「枠を降ろす原因と処理」、`StopInfo`・`SpawnRecord`・`DeadlockWaiter`
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「タスクとスケジューラ」「テストで差し替える部品」「リソースの表と状態」「完了の処理と行き詰まりの判定の順序」「作業の割り当て」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `StateReply`・`StateWait`・`TaskEndTarget`・`SpawnMode`・`Spawn`・`TaskPoll`・`StateServices`
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の `task`・`task_group` の部分

## 作るもの

- `src/builtins/iface.rs`: 10-11 の `StateCtx` に、転送の関数 `task_poll` を加える（2026-10-06 に 10-11 の `file=` に加えた。`Task.await` が `ctx.task_poll(task)?` で結果を読むため。`services()` で文脈の全体を可変で借りると、ヒープを同時に渡せない）。既存の関数と欄は変えない。
- `src/vm/mod.rs`: 後述の「タスクの対象と実行中のタスク」が指定する `start_main` の本体の変更（`sig=` は変えない）。
- `src/vm/dispatch/cell.rs`: 後述の「切り替えの位置の集約」が指定する `precall` の変更。
- `src/vm/task.rs`: `TaskTable` の関数の中身。すべての `todo!()` を書き換えるので、仮置きの許可とコメント（00-02）を消す。
- `src/runtime/sched/mod.rs`: `Scheduler` の関数の中身（タイマーの関数を含む）。`new_ext_op_id` と `new_timer_id` は R24 が書いた（10-10）。本作業ですべての `todo!()` を書き換えるので、仮置きの許可とコメント（00-02）を消す。
- `src/runtime/sched/parts.rs`: `Clock` の実際の実装（OS の時計と、実行を始めた時点からの単調な時計）。`RuntimeParts::real` は `WorkerExec` の実際の実装を要るので、R26 が一時的な中身を、R40 が作業用のスレッドの中身を書く。
- `src/runtime/sched/testing.rs`: 筋書きの型、`TaskPicker` のテスト用の実装、仮想の時間の `Clock`。`sched/mod.rs` が `pub mod testing;` と宣言し、C02 が中身のないモジュールを置いた（10-10）。本作業がその中身を書く。
- `src/vm/state.rs`: `RunState` の第 2 段の欄（タスクの表、タスクごとの起動の履歴の材料、テスト用の部品と筋書きへの口など）と、R23 が置いた一時的な `StateServices` の実装（`Stage1StateServices`）を、タスクの表と `RunState::resources` のリソースの表を使う実装に置き換える（10-10・10-11「作業の割り当て」）。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する非公開の子のモジュール `src/vm/dispatch/tasks.rs`: `PRIM` の応答のうち「待つ」と「タスクの起動」の処理、切り替え、待たせる位置と遅い経路の順序の関数、行き詰まりの判定、止める手順のすべてのタスクへの拡張。本体は `tasks.rs` の冷たい関数に置く（後述の「性能」）。
- `src/vm/dispatch/resource.rs`: R24 が置いた `group_children_pending`（原因 `Return` の `TaskGroup` の解放の枠が、終わっていない子を調べる関数）の中身。同じファイルの `cancel_group_children` は R39 が書く。
- `src/vm/dispatch/handlers.rs`・`unwinding.rs`・`lazy.rs`・`resource.rs`: 後述の「仮の待ちの経路の置き換え」と「切り替えの位置の集約」の箇所。`unwinding.rs` の `cleanup` は、止める手順をすべてのタスクに広げる形に書き換える。
- `src/vm/stage1.rs`: 第 1 段の実行の関数で、タスクを切り替えながら実行する形への変更（後述）。
- `src/builtins/funcs/task.rs`・`src/builtins/funcs/task_group.rs`: `Task.all`・`Task.await`・`TaskGroup.open`・`TaskGroup.spawn` の本体。`Task.allOk`・`Task.race`・`Task.withTimeout` は仮の本体のまま残す（R39）。
- 上のファイルのテストと、`tests/` の下の統合テストのファイル（後述の「テストの置き場所」）。

R20〜R24 が置いた `handlers.rs`・`unwinding.rs`・`lazy.rs`・`resource.rs`・`unwind.rs` の上の箇所は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。

### テスト用の部品の置き場所

10-10 は、筋書きの型を `src/runtime/sched/testing.rs` に置き、`sched/mod.rs`（C02 の `file=`）が `pub mod testing;` と宣言する。`#[cfg(test)]` にしないのは、統合テストと CLI のテストの補助が使うからである（10-10、ADR 0274）。

`testing` の型と関数は公開する。ゴールデンテストの実行器（C10・C12）と `tests/` の統合テスト（R30・R31）が、実行の環境（10-13 の `RunEnv::parts`）に渡す部品を作るのに使うからである（10-10「テストで差し替える部品」の「ゴールデンテストの実行器が使う公開の関数」）。CLI と `benitoite test` の経路からは使わない（ADR 0274 の決定 2）。モジュールの `//!` のコメントに、処理系のテスト専用であることを書く。

### テストの置き場所

本作業の時点では、テスト用の部品を VM に渡す口は `vm` のモジュールの中の `pub(crate)` の関数である（後述の「第 1 段の実行の関数との関係」）。`RunEnv::parts` を `run_program` につなぐのは R26 なので、`tests/` の統合テストからは部品を差し替えられない。そこで、筋書きで順序を与えるテストと、予算を小さくして切り替えを増やすテストは、クレートの中のテスト（`src/vm/dispatch/tasks/tests.rs` など `src/vm/` の下の `#[cfg(test)]` のモジュール）に置き、スクリプトをパイプラインの関数でコンパイルして実行する。既定の部品だけで確かめられるテスト（順序によらない結果）は、`tests/` の統合テストに置いてよい。

## 手順の要点

### タスクの対象と実行中のタスク（02-08「実行ごとの状態のうち VM が使うもの」）

- `start_main` は、`main` を呼ぶ呼び出しの枠一つを積んだ積み重ねを持つタスクの対象（`spawner: None`）を作り、タスクの表に加えて、実行中のタスクにする。R20 が置いた決まった番号（`RunState::current_task`）は、タスクの表が返す番号を入れる形に改める。
- 実行中のタスクの状態は `RunState` の欄に置き、切り替えるときにタスクの対象の欄と移し合う（`host_mut` の中で `std::mem::take`。10-09「タスク」）。移す前に局所の状態を書き戻し、移した後に読み直す。移し合う欄は次のとおりである。一つでも移し忘れると、待つ間に別のタスクの `RETURN` が戻る値と戻り先を上書きするなど、切り替えた先のタスクが別のタスクの状態を使う（相談の第 6 回の指摘 1）。

| `RunState` の欄 | `TaskObj` の欄 | 備考 |
|---|---|---|
| `stack` | `stack` | 実行中は `TaskObj::stack` が空 |
| `current_task` | `id` | 移すのではなく、切り替えた先の番号を入れる |
| `inherited` | `inherited` | 引き継いだハンドラの連鎖 |
| `returning` | `returning` | 戻りの再開状態（R20） |
| `unwinding` | `state` の `TaskState::Unwinding(UnwindWork)` | 実行中は `RunState::unwinding` に置き、切り替えるときに `TaskState::Unwinding` へ移す（R21 の欄のコメントの「R25 が移す」を、この移し合いで実現する） |
| `budget` | `budget` | 後述の「予算」 |
| `precall_done` | `precall_done` | 呼び出しの前の安全点の印（R09） |

  移さない欄は、`meter`（呼び出しの入れ子の計数は実行全体で一つ。02-08「呼び出しの入れ子の上限」）、`roots`、`constants`、`stopping`、`step`、`pending`（第 1 段の要求。R26 が消す）、`scheduler`、`resources` である。
- 予算: `TaskObj::budget` と `RunState::budget` は、切り替えのときだけ移し合う。実行中のタスクの予算は `RunState::budget` に置き、普通の経路の `tick` は今のまま `RunState::budget` だけを触る。タスクの対象を引いて予算を読み書きする処理を、普通の経路に足さない（ADR 0263 の決定 3。後述の「性能」）。回収の要求は実行全体で持つので、`notify_collect` は今のまま実行中のタスクの予算（`RunState::budget`）を `Budget::interrupt` する。
- 進めるタスクを選んだら、命令を実行する前に、`Unwinding` なら辿りを、`ReturnWork` があれば戻りの処理の続きを行う（10-09「戻りの再開状態」）。今の `run_until_exit` の先頭の確かめ（`state.unwinding` か `state.returning` があれば `unwinding::resume`）を通す形にし、新しいタスクに入る経路がこの確かめを飛ばさないようにする。
- タスクを `Done` にするときは、`stack`・`inherited`・`handle`・`awaiters`（起こした後）を空にしてからタスクの表から除く。対象に残るのは状態と結果だけである（ADR 0266 の決定 10）。自分の解放が終わっていないタスクは `Done` にしない（同 決定 5）。

### 切り替え（02-08「タスクの切り替え」）

- 切り替えの位置の処理の遅い経路の手順 4 で `Budget::finish_slow` が `Switch` を返したら、実行中のタスクを待ち行列の末尾に移し、`Scheduler::next` で次のタスクを選んで進める。
- タスクを待たせる位置では、実行中のタスクを `Scheduler::park` で待たせ、10-10「完了の処理と行き詰まりの判定の順序」の順を一つの関数で行ってから、次のタスクを選ぶ。本作業はその関数を作り、手順 3 のタイマー、手順 5 の行き詰まり、手順 6 の待ちを書く。手順 1・2（送り出しの列と完了の取り込み）は R26、手順 3 の出力の取り込みと手順 4 は R27 が同じ関数に足す。手順 3 で満了したタイマーを `SpawnWait::timer` と照らす処理は R39 が足す。
- 回収の要求は `Budget::interrupt` で予算を 0 にして知らせる（今のまま）。取り消しの要求の知らせ方は R39 が書く。

#### 切り替えの位置の集約

今のコードは、`Budget::finish_slow` の結果（`Continue` か `Switch`）をどこでも捨てている。次の箇所である（行は 2026-10-06 の `san_benito` と、取り込み中の作業ディレクトリのもの。R22・R23 の取り込みで前後する）。

| 箇所 | 今の形 |
|---|---|
| `dispatch.rs` の `call`（1003 行付近） | 呼び出しの前の安全点。`Continue \| Switch => {}` |
| `dispatch/handlers.rs` の `precall`（164 行付近） | `HANDLE`・`PERFORM`・`IO` の節・`RESUME` の前の安全点。同上 |
| `dispatch/lazy.rs` の `force`（R22。110 行付近） | `FORCE` の本体の呼び出しの前の安全点。同上 |
| `dispatch/cell.rs` の `precall`（R23。45 行付近） | `UPDATE` の関数の呼び出しと、命令のない呼び直しの前の安全点。同上 |
| `stage1.rs` の `run_stage1`（57 行付近） | 呼び出しの前の安全点で回収に出た後（`precall_done` が `Some`）の `finish_slow`。同上 |

これらを一つの冷たい関数（例 `tasks::slow_path_end`）の呼び出しに寄せ、`Switch` のときに切り替える。`dispatch.rs` の `LoopExit`（`Collect`・`Return`）は凍結しているので、切り替えは次のどちらかで行う。どちらにするかは作業が決め、完了の報告の「判断したこと」に書く。

- `run_until_exit` の中の冷たい経路で、局所の状態を書き戻し、タスクを移し合って、局所の状態を読み直す。
- `RunState` に「切り替える」の印を立てて局所の状態を書き戻し、`run_until_exit` から出て `run_epoch` の周回で入り直す。入り直した先頭の冷たい経路で印を読み、タスクを移し合う。

どちらでも、呼び出しの前の安全点で切り替えるときは、回収に出るときと同じく `precall_done` に命令を記録して局所の状態を保存し（10-09「呼び出しの前の安全点」）、そのタスクに戻ったら同じ命令を初めから実行し直して `tick` を繰り返さない。印は `precall_done` とともにタスクの対象へ移る。

`stage1.rs` の回収の後の `finish_slow` も、`Switch` を捨てずに同じ印を立てる。回収の要求で遅い経路に入った場合（回収の強制のビルドでは毎回）と入らない場合とで、`finish_slow` が `Switch` を返す時点は同じなので、ここで `Switch` を扱わないと、回収の強制のビルドと既定のビルドで切り替えの列がずれる（受け入れテストの「予算」）。

#### 仮の待ちの経路の置き換え

R20〜R24 は、タスクを待たせる処理がないので、待つ位置を `state.step = Some(VmStep::Requests(Vec::new()))` と `Control::Return` で止める仮の形にした。本作業は、次の箇所を「`Scheduler::park` で実行中のタスクを待たせ、順序の関数を通して次のタスクに切り替える」形に置き換える。

| 箇所 | 待つ理由 | 置き換えの要点 |
|---|---|---|
| `dispatch/handlers.rs` の `continue_return`（R20。840 行付近） | 段 `OwnReleases` の解放の枠の `Wait(Release)` | `ReturnWork` を残して待たせ、起きたら段から続ける |
| `dispatch/handlers.rs` の `continue_return`（R20。889 行付近） | 包む枠の `Wait`（`handle` の枠の `TaskEnd(HandleEnd)`、`TaskGroup` の解放の枠の `TaskEnd(TaskGroupRelease)`、解放の枠の `Release`） | 同上 |
| `dispatch/unwinding.rs` の `escape_one`（R21。94 行付近） | `ESCAPE` で降ろす途中の枠の `Wait` | 同上（段は `Escaping`） |
| `dispatch/unwinding.rs` の `traverse`（R21。265 行付近） | `UnwindWork::waiting` が `Some` | 待たせる。起こすときの扱いは後述の「R21 からの申し送り」 |
| `dispatch/lazy.rs` の `force`（R22。82〜83 行付近） | `Lazy`（別のタスクが評価中） | 直前の `state.scheduler.park(task, WaitReason::Lazy)` は残し、続く `VmStep::Requests` と `Control::Return` を切り替えに替える |
| `dispatch/resource.rs` の `dispatch`（R24。84 行付近） | `RELEASE` の `Wait(Release)` | 枠を元の位置に戻し `pc` を `RELEASE` に保ったまま待たせる（R24 の形のまま） |

R23 の `cell.rs` には仮の待ちの経路がない（切り替えの位置の集約だけが対象である）。`dispatch.rs` の `run_until_exit` の先頭（182 行付近）と `finish_builtin`（843 行付近）の `VmStep::Requests` は、第 1 段の要求と応答の方式の形であり、R26 が移すので本作業の対象外である。`unwinding.rs` の `traverse` の原因 `Cancel` の辿りの終わり（311 行付近）は R39 が書き換える。

#### R21 からの申し送り

- `UnwindWork::waiting` の解除: `traverse` は、`waiting` が `Some` なら待つ位置へ戻る（265 行付近）。待ちが解けてタスクを起こし、辿りを再開するときは、`waiting` を `None` にしてから `traverse` を呼ぶ。消し忘れると、起きたタスクが同じ位置でまた待つ。同じ枠をもう一度処理しても二度解放しないことは、各 `unwind_*` が枠の中身で判断する（R21「辿り方」）。
- `cleanup` の繰り返し: `unwinding.rs` の `cleanup`（359〜369 行付近）は、`traverse` が `Err` を返すと無条件に繰り返す。`advance` が枠を手放した後に失敗を返す場合は進むが、進まずに同じ `Err` を返し続けると抜けない。止める手順をすべてのタスクに広げるときに、抜ける条件を加える（例: `Err` の後に `UnwindWork` の区画と枠の数が減っていなければ、そのタスクの残りの区画を手放して次のタスクへ進む）。止める理由は置き換えない（R21「全体の停止」の最後の段落）。

### 回収の要求の確かめ

回収の要求は、確保する分岐の中で確かめる（R22「性能」、ADR 0263 の決定 4）。タスクの起動では、タスクの対象（`alloc_host`）と、結果のリスト（`Task.all` の結果）を確保した後に、`after_alloc` と同じ処理で要求を調べて予算に知らせる。`PRIM` の速い経路の末尾には確かめを足さない。

R23 の `Stage1StateServices`（大きさ 0）を、タスクの表とリソースの表を借りる実装に替えるときも、純粋な関数の `PRIM` の経路を変えない。`execute_builtin` は実行中の区画の窓を借りているので、状態を借りる `StateServices` を同じ経路で作れない。権限が `State` の関数は、既にある権限の照合（`opcode` と `reference.capability` の比べ）と一つにまとめた分岐で `tasks.rs` の冷たい関数へ出し、そこで窓と `RunState` の欄を分けて借りる。権限が `Pure` の関数の経路に比べや確保を増やさない。

### 第 1 段の実行の関数との関係

R26 が送り出しの列と第 2 段の実行の関数（10-10 の `Vm::run`）を作るまで、実行は `Vm::run_stage1` で行う。本作業は `run_stage1` を、タスクを切り替えながら実行する形に広げる。IO の命令は、第 1 段の形（直ちに呼び、作業用のスレッドの仕事はその場で実行する）のまま扱う。IO の応答のうちタイマー（`IoWait::Sleep`）は、本作業のタイマー（`Scheduler::timers`）に登録して `WaitReason::Timer` でタスクを待たせ、満了で `wake_if` で起こす形で扱う（本体の `Clock.sleep` は R29 が書く）。

進められるタスクがなく、タイマーだけが残るとき、実際の部品ではスレッドを次の期限まで眠らせ、テスト用の部品では筋書きの次の一歩（時間を進める）を行う。これは R26 がイベントループと `WorkerExec::idle` に置き換えるまでの一時的な形である。

テスト用の部品（`TaskPicker` と `Clock`）は、`RunState` に置き、`vm` のモジュールの中の `pub(crate)` の関数で差し替えられるようにする。R26 が `IoRuntime::parts` へ移す。

### タスクの起動（02-08「タスクの起動と待ち方」）

`PRIM` で呼んだ `state` の関数が `StateReply::SpawnTasks(Spawn { funcs, mode })` を返したら、次を行う。

1. 関数の値ごとに、その関数を引数なしで呼ぶ呼び出しの枠一つからなる積み重ねを作る（枠の `call_site` は `PRIM` の命令、`ret` は `None`）。枠とレジスタの分を `StackMeter::fits` で確かめ、超えれば `PRIM` の命令で `CallStackTooDeep` として止まる。
2. タスクの対象を作る。`inherited` は、起動したタスクの積み重ねの `handle` の枠のハンドラの記録を上から並べ、その後に起動したタスクの `inherited` を続けたものである（02-08「ハンドラの記録とハンドラの連鎖」）。`handle` は、起動したタスクの積み重ねに `handle` の枠があれば最も上のもの、なければ起動したタスク自身の `handle` とする。そのハンドラの記録の `members` に新しいタスクを加える（ADR 0266 の決定 6）。登録は起動したタスクを終わったとする前に行われる（起動は起動したタスクの実行中に起きるので、この順は自然に守られる）。`spawner` に（起動したタスク、`PRIM` の命令）を入れ、起動の履歴の材料（起動したときの呼び出しの枠。10-09 の `SpawnRecord::spawner_frames`）を `RunState` の表に記録する。行き詰まりの報告は待つタスクを起動した順に並べるので（02-10「実行時エラーと資源の不足の報告」の R1001）、起動の通し番号も記録する。筋書きへの口があれば、通し番号と番号の対応を知らせる（後述の「テスト用の部品」）。
3. 新しいタスクを待ち行列の末尾に加える。
4. 待ち方で分ける。`funcs` が空なら、タスクを作らずに結果を返す（`All` は空のリスト）。
   - `All`: 起動した `Task` の値を `SpawnWait::children` に起動した順に置き、`WaitReason::TaskEnd(TaskEndWait::Spawned)` で起動したタスクを待たせる。
   - `GroupSpawn { group }`: 新しいタスクを `TaskGroup` の項目の子の並びに加え（解放した `TaskGroup` なら `ReleasedResourceUsed`）、`Task` の値を結果として続ける。待たない。
   - `AllOk`・`Race`・`WithTimeout` は R39 が加える。本作業の時点では三つの本体が仮の本体なので、この応答は来ない。

### タスクの終わりと待ち方の結果（02-08「タスクの起動と待ち方」、01-11「タスクを起動する関数」）

タスクの最初の呼び出しの枠が値を返したら、`TaskResult::Value` を入れ、`Done` にし、次を行う。

- `awaiters` のタスクを `wake_if(待つタスク, TaskEnd(Await(このタスク)))` で起こす。
- 属する `handle` のハンドラの記録の `members` から除く。本体が終わり（`body_finished`）、`members` が空になったら、`handle` の枠で待っているタスク（`evaluated_by`）を `wake_if(…, TaskEnd(HandleEnd))` で起こす（E-HRet）。
- `TaskGroup` の子であれば、その `TaskGroup` の解放の枠で待つタスクを `TaskEnd(TaskGroupRelease(番号))` で起こす（`wake_all` を使ってよい）。起きたタスクは同じ解放の枠を同じ原因でもう一度処理し、`group_children_pending` で終わっていない子が残れば待ち直す。
- 起動したタスクが `SpawnWait`（`All`）で待っていて、すべての子が `Done` になったら、結果を起動した順に並べたリストを作り、起動したタスクの `PRIM` の結果のレジスタに入れ、`wake_if(…, TaskEnd(Spawned))` で起こす。取り消す子を持つ待ち方（`AllOk`・`Race`・`WithTimeout`）の判断は R39 が加える。

### `Task.await` と `StateServices`

`StateServices` の実装は、`RunState` のタスクの表と `RunState::resources` のリソースの表を使う（R23 の一時的な実装を置き換える）。

- `task_poll`: `Task` の値のタスクが `Done` で結果があれば `Done(結果)`、終わっていなければ `Pending(番号)`。結果なしで終わった（取り消した）タスクを待つことは、型検査を通ったプログラムでは起きない（取り消されうるタスクの `Task` の値はプログラムに渡らない）ので `Stop::Internal`。
- `Task.await` の本体は、`Pending(番号)` なら `StateReply::Wait(TaskEnd(Await(番号)))` を返す。VM は、待たれるタスクの `awaiters` に加えて待たせる。待たせるときは命令の位置を進めずに `PRIM` を指したまま待たせ、起きたら `PRIM` をもう一度実行する（そのときは `Done` の結果が返る）。
- `open_task_group`: 子の並びが空の `ResourceContent::TaskGroup` をリソースの表に加える。
- `begin_release`: R24 の `check_release` で番号と項目を確かめ、食い違いを `Stop::Internal` で返してから（10-10「リソースの表と状態」）、リソースの表の `request_release` で解放を始める。すぐに終われば `None`、待つなら `StateWait::Resource(番号)` を返す（`IO.File.closeReader` が使う。本体は R29）。VM は `StateWait::Resource(番号)` を `WaitReason::Release(番号)` として待たせ、命令の位置を進めずに `PRIM` を指したまま待たせる。解放の完了で起きて `PRIM` をもう一度実行すると `AlreadyReleased` になるので、`take_release_failure` で記録した失敗を取り出し、リソースの型の規則で扱う。
- 本作業が `ResourceTable::lend` を呼ぶことはない（貸し出しは R26）。`request_release` を呼ぶほかの箇所を加えるときも、先に `check_release` を呼ぶ。

### 待つ理由ごとの起こし方

待つタスクを知らせで起こすときは、`Scheduler::wake_if` で、そのタスクが今もその理由で待っていることを確かめてから起こす（10-10「タスクとスケジューラ」）。待ち直したタスクを古い知らせで起こさない。

| 待つ理由 | 待つ位置 | 起こす知らせ |
|---|---|---|
| `TaskEnd(Await(番号))` | `Task.await` の `PRIM` | 待たれるタスクの終わり |
| `TaskEnd(Spawned)` | `Task.all` の `PRIM` | すべての子の終わり（結果を書いてから起こす） |
| `TaskEnd(HandleEnd)` | 戻りの処理か E-DropRel の辿りの `handle` の枠 | 本体が終わった `handle` の `members` が空になったこと |
| `TaskEnd(TaskGroupRelease(番号))` | 戻りの処理の `TaskGroup` の解放の枠（原因 `Return`） | 子のタスクの終わり |
| `Lazy` | `FORCE`（R22） | `update` の枠を降ろしたこと（`unwind_update` が `wake_if` を呼ぶ。R22 が書いた） |
| `Release(番号)` | 解放の枠、`RELEASE`、`begin_release` の `PRIM` | 解放の完了（R26 の `ReleaseFinished`。本作業のテストでは、テスト用の補助で `finish_release` を記録して `wake_if` を呼ぶ） |
| `Timer(番号)` | `IoWait::Sleep` の待ち | 手順 3 の `expire_timers` |

### 行き詰まり（02-08「タスクの切り替え」、ADR 0238・0266 の決定 8）

10-10「完了の処理と行き詰まりの判定の順序」の手順 5 で、待ち行列が空で、`Scheduler::is_deadlocked` が真であれば、行き詰まりの実行時エラー（`RuntimeError::TaskDeadlock`）とする。`is_deadlocked` は、待つタスクがあり、外部の待ち（`WaitReason::is_external` が真の待ちとタイマー）がないことを調べる。本作業は、手順 5 を一か所の判定の関数にまとめる。外部の操作の記録、要求、出力の転送は、それを待つタスクがあればその待ちで数えられ、待つタスクがなければ数えないので、ほかの条件は足さない（[ADR 0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）。止める手順の途中では、この結果で元の停止の理由を置き換えない。

`StopInfo` は、`at` を `None`、`frames` を空にし、待つタスクごとの `DeadlockWaiter` を起動した順に並べる。待つ種類と待つ命令は、02-08「実行時エラーの情報の記録」のとおり（組み込みの関数は `PRIM` の命令、`Lazy` は `FORCE`、`handle` の終わりは `HandleFrame::at`、`TaskGroup` の解放は解放の枠の `at`）とする。

### 止める手順（02-08「止める手順」）

R21 の止める手順を、すべての終わっていないタスクに広げる。すべてのタスクを `Unwinding(Stop)` にし、待っていたタスクの待ちを外して（`Scheduler::wake`。返却を待つ並びからも `ResourceTable::remove_waiter` で除いて）、タスクごとに辿る。ただし、解放の枠の処理が返した `Wait(Release)` の待ちは外さない（ADR 0266 の決定 5）。既に `Unwinding`（原因 `Cancel` か `DropRel`）のタスクは、`UnwindWork` を作り直さずに `UnwindWork::escalate(残りの積み重ね, Stop)` で移し、`escalate` が子のタスクの終わりの待ちを外したら進められるタスクに戻す（10-09「既に枠を降ろしているタスクの扱い」、相談の第 6 回の指摘 2）。本作業の時点で原因 `Cancel` のタスクは現れないが、同じ分岐で扱い、R39 が確かめる。どのタスクの `ReturnWork` と呼び出しの前の安全点の印も消す。解放が完了を待つタスクは待たせ、ほかのタスクの手順を進める。止める途中では予算と取り消しの要求を使わない。実行時エラーが起きたタスクがメインのタスクでなければ、`StopInfo::spawns` に、そのタスクからメインのタスクまでの起動の履歴の材料を入れる。前述の「R21 からの申し送り」の `cleanup` の抜ける条件も、ここで加える。

### テスト用の部品（ADR 0274）

- 筋書きの型: 切り替えの位置ごとに次に進めるタスクを選ぶ指示（待ち行列の中の位置か、起動の通し番号）、仮想の時間を進める指示、作業用のスレッドの仕事をいつ実行するかの指示を、順に並べたもの。三つのテスト用の部品が一つの筋書きを共有する。仕事の実行の指示は、`WorkerExec` のテスト用の実装（R26）が読む。筋書きが尽きたときは、`TaskPicker` は待ち行列の先頭を選び、時間を進める指示がなければ `IdleWake::ScriptExhausted` になる（VM は `Stop::Internal` にする。テストの誤りとして見つけるため）。
- 起動の通し番号で選ぶ指示: `TaskPicker::pick` は待ち行列の `TaskId` の並びしか受け取らず、`TaskPicker`・`Clock` の trait は凍結している（10-10）ので変えない。代わりに、`RunState` に筋書きの共有の状態への口（`Option`。テスト用の部品を渡したときだけ `Some`）を置き、VM がタスクを起動するたびに、起動の通し番号と `TaskId` の対応（と、そのときの仮想の時間の位置）を口に知らせる。テスト用の `TaskPicker` は、共有の状態のこの対応を引いて位置を求める。この口は本作業の仮の口であり、R26 が、10-10 の `TaskPicker` に加えた既定の本体を持つ関数 `spawned(serial, task)`（2026-10-06 に `file=` に加えた）に置き換える。R26 の後は、VM が起動のたびに `IoRuntime::parts` の `TaskPicker` の `spawned` を呼び、テスト用の `TaskPicker` がそれで対応を受け取る。`RunState::scheduling.script` と、テスト用の部品を差し替える `use_schedule` も、R26 が `IoRuntime::parts` を使う形に改める（R26「起動を筋書きに知らせる口」）。
- 筋書きを進める境界（10-10「テストで差し替える部品」、相談の第 7 回の指摘 7）: タスクを選ぶ指示は `TaskPicker::pick` が消費する。時間を進める指示と仕事を実行する指示は、完了の取り込みの境界（10-10「完了の処理と行き詰まりの判定の順序」の手順 2。待たせる位置と、予算を使い切った遅い経路の両方）で、筋書きの先頭から次のタスクを選ぶ指示の前までをまとめて行う。進められるタスクがないときは待ちの口が同じことを行う。本作業の時点では `WorkerExec` がないので、手順 2 の位置で筋書きの共有の状態を直接呼んで時間を進める一時的な形を置き、R26 がテスト用の `WorkerExec::try_recv` と `idle` に移す。先頭の指示を行えないときの扱いと、筋書きのない選択で先頭へ戻ることを誤りにする設定は、本作業が決めて完了の報告の「判断したこと」に書く。
- 筋書きの記録: 消費した指示の数と、実際に選んだタスクと行った指示の並びを、テストが読めるようにする。順序に依存するテスト（本作業、R39、R26、R30、R31、C12）は、筋書きを使い切ったことと、狙った順序で選び・実行したことを、この記録で確かめる。
- 仮想の時間の `Clock`: `now_millis`・`monotonic_millis` は、筋書きが進めた時間だけを返す。タイマーは、時間を進めたときにだけ満了する。

### 凍結した戻り値で処理系の不具合を扱う方法

R24 と同じく（R24「凍結した戻り値で処理系の不具合を扱う方法」）、次の関数の戻り値は凍結しており（10-09・10-10 の `sig=`）、`Result` ではない。シグネチャは変えずに、次のように扱う。

- `Scheduler::next(&mut dyn TaskPicker) -> Option<TaskId>` と `TaskPicker::pick -> Option<usize>`: `pick` が範囲外の位置を返したとき、`next` は待ち行列を変えずに `None` を返す。VM は「`next` が `None` なのに進められるタスクの並びが空でない」を `Stop::Internal` にする。筋書きの誤り（範囲外の位置、行えない指示、知らない通し番号）は、テスト用の部品が筋書きの共有の状態に記録し、VM かテストが読む（VM が読むなら `Stop::Internal` にする）。
- `TaskTable::insert -> TaskId`（項目の数が `u32` を超える）、`TaskTable::remove -> ()`（番号の世代が合わない、項目が空）、`Scheduler::park -> ()`（既に待っているタスクを二度待たせる、待ち行列にあるタスクを待たせる）: 非公開の確かめの関数（例 `TaskTable::check_insert`・`check_remove`、`Scheduler::check_park`。名前は作業が決める）を加え、VM は呼ぶ前に確かめて、食い違いを `Stop::Internal` で返す。凍結した関数の中では、確かめを通った入力を前提にし、到達しないはずの分岐は `debug_assert!` で不具合を示したうえで、状態を変えない。到達しない理由をコメントに書く。
- 世代の計数は `wrapping_add(1)` で進める。同じ世代に戻るには一つの項目を 2^32 回使い回す必要があり、そのあいだ古い番号を持ち続ける参照が残っている必要もあるので、古い番号が新しいタスクを指すことは実際上起きない。この理由を、計数を進める箇所のコメントに書く。

### 回収の前の整理（ADR 0314）

R16 の後の VM は、回収の前に各枠の窓の生きていないレジスタを空にする（[ADR 0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md)）。本作業は、すべてのタスク（実行中、切り替えられた、待つ、まだ始まっていない）の区画に、決定 3 の規則を当てる。各タスクの最も上の区画の最も上の呼び出しの枠が「最も内側の枠」である。R21 と同じく、本作業が加える状態を決定 5 の「命令の入口」と「結果が書かれる前の呼び出し元」のどちらかに分類する表を、完了の報告に書き、分類どおりに空にする。少なくとも次の状態を表に入れる。

- 呼び出しの前の安全点で切り替えたタスク（`precall_done` が `Some`）: 「命令の入口」。回収に出るときと同じ扱いである。
- まだ始まっていないタスク（最初の呼び出しの枠の `pc` が 0）: 「命令の入口」。
- `Task.await` と `begin_release` の待ち（`pc` は `PRIM` を指したまま。起きたら `PRIM` を実行し直す）: 「命令の入口」。
- 別のタスクの評価を待つ `FORCE`（`WaitReason::Lazy`）: 「命令の入口」。`pc` は `FORCE` を指したままであり、起きたら `FORCE` を実行し直すので `R[B]` が残る（R22 の分類）。
- `RELEASE` の待ち: 「命令の入口」（R24 の分類）。
- `Task.all` の子を待つ `PRIM`（`TaskEnd(Spawned)`）: 待つ間は「命令の入口」。子の結果の配送は、結果のレジスタへの書き込みと命令の位置の更新（次の命令へ進める）を、回収を挟まずに一続きに行う。結果を書いた後に命令の位置が待った命令を指したまま回収すると、入口の集合が結果のレジスタを含まず、新しい結果を消す（相談の第 9 回の指摘 2）。
- 戻りの途中の待ち（`ReturnWork` の段が `OwnReleases`・`Wrapping`・`Escaping`）: R20・R21 の表のとおり。
- 辿りの途中の待ち（`UnwindWork` の区画）: 整理せず、保守的に残す（R21）。

分類を確かめていない状態は、空にしない。受け入れテストで、回収の強制（`gc-stress`）の下で、待つ間と完了の直後に回収が起きても、引数と結果が残ることを確かめる。

### 性能

普通の経路（`CALL`・`TAILCALL`・`RETURN` の速い経路、`PRIM` の純粋な関数の経路、`execute` のループの頭）に処理を足さない。切り替え、待たせる位置の順序の関数、タスクの起動、待つ応答の処理、止める手順の本体は `dispatch/tasks.rs` の冷たい関数（`#[cold]`・`#[inline(never)]`）に置く（R21・R22 の形）。`handlers.rs` の冷たい関数 `dispatch` の `else if` の連なりには分岐を足さない。前述の「切り替えの位置の集約」で寄せる関数も冷たい関数にし、`tick` が `true` を返す経路からは呼ばない。予算は前述のとおり切り替えのときだけ移し合い、`tick` の費用を変えない。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（R40 の後と最後に、オーケストレータが行う）。

## 受け入れテスト

テストは、スクリプトをパイプラインでコンパイルし、テスト用の部品を渡して実行する（置き場所は前述の「テストの置き場所」）。予算を 1 などの小さな値にして切り替えを増やしたもの、筋書きで順序を変えたものを並べ、結果が切り替えの順序によらないはずの場合に一致することを確かめる。筋書きで順序を与えたテストは、筋書きの記録で、筋書きを使い切ったことと狙った順序になったことも確かめる。

- `Task.all`: 三つのタスクの結果が起動した順に並ぶ。筋書きで終わる順を変えても同じである。空のリストで空のリスト。
- `TaskGroup`: `with` の中で `TaskGroup.spawn` した子の終わりを、`with` を抜けるときに待つ。`Task.await` で結果を読む。解放した `TaskGroup` への `spawn` が `ReleasedResourceUsed`。
- 起こす理由の照合: `Scheduler` の単体テストで、`wake_if` が、別の理由で待つタスクと待っていないタスクを起こさないことを確かめる。`park` の確かめの関数が二重の待ちを拒むことも確かめる。
- `handle` と子孫のタスク: `handle` の本体の中で起動したタスクが引き継いだハンドラの操作を呼び、末尾で再開する節がそのタスクの中で直接実行される。末尾で再開しない節なら `InheritedHandlerClause` で止まる。本体が終わっても、属するタスクが終わるまで `handle` の式の値が返らない。外側で開いた `TaskGroup` を内側の `handle` の本体から使って子 A を起動し、A が同じ集まりに孫 B を起動して終わった場合に、`handle` が B も待つ（OPEN-062 の R03 の形。正式な再現テストは R30）。
- `Lazy` を待つタスク（R22 からの引き渡し）: タスク A が評価している `Lazy` を、タスク B が `force` して待つ（筋書きで A の本体の評価の途中に B を選ぶ）。A の評価が終わると B が起こされ、`FORCE` をもう一度実行して `Done` の結果を得る。`Lazy` の本体は一度だけ評価される（R22 の確かめ方で、二度目の `FORCE` が `Done` の経路を通ることを確かめる）。
- `unwind_update` が起こすタスク（R22 からの引き渡し）: `unwind_update` を原因 `DropRel` と `Cancel` で直接呼ぶ単体テストで、`Lazy` を待つ並びのタスクの全員が起こされ、原因 `Stop` では誰も起こされない。R22 の時点では `Scheduler::wake_if` の中身がないので、R22 は状態が `Before` に戻り待つ並びが空になることまでを確かめている（直接呼ぶ単体テストなので、取り消しの手順は要らない）。
- セルの更新のやり直し（R23 からの引き渡し）: タスク A の `Reference.update` の関数の実行の途中（予算で切り替わる長い計算）で、タスク B が同じセルに `Reference.set` すると、A がやり直し、最後の値が「B の書き込みの後に A の関数を適用した値」になる。
- 行き詰まり: `Task` の値をセルに入れて二つのタスクが互いを `Task.await` で待つプログラムが `TaskDeadlock` で止まり、`StopInfo::deadlock` に二つのタスクの記録が起動した順に並ぶ。`Scheduler` の単体テストで、タイマーで待つタスクがあるあいだは `is_deadlocked` が偽になることを確かめる（スクリプトでの確かめは R39 の `Task.withTimeout`）。
- タイマー: VM の単体テストで、タスクを `WaitReason::Timer` で待たせてタイマーを登録し、仮想の時間を期限の直前まで進めても起きず、期限まで進めると起きる。
- 止める手順: 子のタスクの中で 0 の除算を起こすと、プログラム全体が止まり、すべてのタスクの解放の枠が降ろされ、`StopInfo::spawns` に起動の履歴の材料が入る。止める途中で `handle` と `TaskGroup` が子の終わりを待たない（子のタスクが長い計算の途中でも、止める手順が終わる）。
- E-DropRel で辿っているタスクの全体の停止（R21 からの引き渡しの一部）: E-DropRel で偽の資源のブロックする解放（R24 の偽の資源を `Blocking` にし、テスト用の補助で解放の完了を記録して待ちを解く）を待っているタスクがあるときに、別のタスクで 0 の除算を起こす。解放の完了を待ってから止める手順が終わり、解放は一度ずつ呼ばれ、`escalate` の前に集めた解放の失敗が `StopEnd::release_failures` に残り、止まる理由は `DivisionByZero` のままであり、捕まえた継続の中の `update` の枠の `Lazy` を待つタスクが起こされない。取り消しで辿っているタスクと、E-DropRel で `handle` の枠が属するタスクの終わりを待っているタスクの場合は、R39 が確かめる。
- `cleanup` の抜ける条件: VM の単体テストで、止める手順の途中の `traverse` が進まずに `Err` を返す状態（テスト用の補助で作る）から、止める手順が終わり、止まる理由が変わらない。
- 予算: 予算を使い切ったタスクが待ち行列の末尾に回り、計算を続けるタスクがあってもほかのタスクが進む。回収の要求で遅い経路に入っても、タスクを切り替える時期が変わらない（回収の強制のビルドと既定のビルドで、筋書きどおりの切り替えの列が一致する）。
- 待ちをまたぐ戻りの再開状態（相談の第 6 回の指摘 1）: `handle` の本体が値 v を返したときに属するタスク B が残っている（`handle` の枠が `Wait(TaskEnd(HandleEnd))` で待つ）間に、B が多くの関数の呼び出しと `RETURN`（包む枠のある戻りを含む）を行って終わる。予算を 1 にした実行と筋書きで順序を変えた実行の両方で、`handle` の式の値が v になる。同じ形を、E-DropRel で偽の資源のブロックする解放を待つ間に別のタスクが値を返す場合でも確かめ、節の値が元の `handle` の戻り先に入り、解放がちょうど一度呼ばれる（R21 からの引き渡し。`UnwindWork::waiting` を消してから辿りを再開することもこのテストで確かめる）。
- 引き継いだハンドラの直接の実行の繰り返し（相談の第 6 回の指摘 6）: `handle` の本体の中で起動したタスクが、引き継いだハンドラの末尾で再開する節の操作を末尾再帰で 100 万回呼ぶプログラムが、小さな `max_call_stack_bytes`（例 1 MiB）でも止まらずに終わる。
- タスクの状態とリソースの状態の組み合わせ（02-09「リソースの追跡」の表）のうち、作業用のスレッドと取り消しを使わない行（`Waiting` × `Releasing`、原因 `Stop`・`DropRel` の `Unwinding` × `Releasing`、`Done` の条件）。取り消しを使う行は R39、作業用のスレッドを使う行は R26 が確かめる。
- 根の置き場ごとの回収の強制（R03「根の列挙の引き渡し」の表の、本作業の行）: `HeapConfig::stress` を真にした設定で、値が次の置き場だけに残る状態を作って回収し、その後の結果が正しいことを確かめる。待っているタスクの対象の積み重ね（`TaskObj::stack`）、引き継いだハンドラの連鎖（`TaskObj::inherited`）、属する `handle` の記録（`TaskObj::handle`）、終わったタスクの結果（`TaskResult::Value`。`Task.await` の前に回収する）、`SpawnWait::children`、待ちをまたぐ `UnwindWork`（解放の完了を待つ間に別のタスクで回収を起こす）、待ちをまたぐ `TaskObj::returning`（上の「待ちをまたぐ戻りの再開状態」の待ちの間に回収を起こす）。
- 回収の強制のビルドで、上のテストがすべて通る。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- タスクを指す参照が、10-09「タスク」の持ち方の表のとおり（所有するのはタスクの表と `Task` の値だけ）になっている
- 前述の「仮の待ちの経路の置き換え」の箇所（R39 が書き換える `traverse` の原因 `Cancel` の終わりを除く）に、`VmStep::Requests(Vec::new())` で止める仮の形が残っていない
- `finish_slow` の結果を捨てる箇所が残っていない
- 実時間の待ちやスレッドの実行の順序の偶然に頼るテストがない（[実装の規約](../00-common/00-02-conventions.md)の「テストの規約」）
- `RunState` に加えた欄と、切り替えの方式（前述の「切り替えの位置の集約」）を、完了の報告の「判断したこと」に書いている
- 後述の「R39 へ残すもの」の関数を何もしない中身のまま残したことを、完了の報告の「残したこと」に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」と「スケジューラと IO」の行。
- 予算の退避と戻しが ADR 0263 の決定 3 のとおりか。予算を切り替えのときだけ移し、普通の経路でタスクの対象を引いていないか。
- 切り替えで、積み重ねとともに `precall_done`・`returning`・`UnwindWork`・`inherited`・予算を移しているか。新しいタスクに入る経路が、入口の `unwinding`・`returning` の確かめを通るか。
- 既に辿っているタスクの全体の停止で、`UnwindWork` を作り直さずに `escalate` を使っているか。
- 孫のタスクの `handle` への登録が、起動したタスクの `handle` を引き継いでいるか（起動の命令の位置の `handle` の枠だけに登録していないか。ADR 0266 の背景の R03）。
- `handle` の記録を、本体が終わり属するタスクが 0 になるまで残しているか。
- 起こす処理がすべて `wake_if` を通り、待つ理由を照らしているか。
- 行き詰まりの判定を、送り出しの列と未処理の完了を処理した後に行っているか。止める途中で元の理由を置き換えていないか。
- 回収の要求の確かめが確保する分岐の中にあり、`PRIM` の純粋な関数の経路に比べや確保が増えていないか。

## R39 へ残すもの

次の関数と経路は、R21・R24 が「R25 が書く」として置いたもののうち、取り消しに関わるものである。本作業では今の中身（何もしない、`false` を返す）のまま残し、R39 が書く。

| 箇所 | 中身 |
|---|---|
| `src/vm/unwind.rs` の `cancel_handle_members` | `handle` の枠（原因 `Cancel`・`DropRel`）が属するタスクを取り消す |
| `src/vm/unwind.rs` の `cancel_requested` | E-DropRel を辿り終えた時点で、取り消しの要求を読む |
| `src/vm/dispatch/resource.rs` の `cancel_group_children` | `TaskGroup` の解放の枠（原因 `Cancel`・`DropRel`）が終わっていない子を取り消す |
| `src/vm/dispatch/unwinding.rs` の `traverse` の原因 `Cancel` の辿りの終わり（311 行付近） | `TaskResult::Cancelled` で `Done` にし、知らせる（今は仮の待ちの形） |

`group_children_pending` は本作業が書く（原因 `Return` で子を待つのに要る）。R39 は、原因 `Cancel` の分岐でも同じ関数を使う。

## 難易度の理由

タスクの状態、待ち方、`handle` の記録、`Lazy` とセル、リソースの解放が互いに組み合わさり、組み合わせごとの振る舞いを 01-11 と ADR 0266 の表から一つずつ実装する必要がある。R20〜R24 が仮の形で残した待ちの経路と切り替えの位置を、一つの切り替えの仕組みにまとめて置き換える。切り替えの順序で結果が変わる誤りは、順序を与える部品がなければ再現しないので、部品を作ってからそれでテストを書く順になる。
