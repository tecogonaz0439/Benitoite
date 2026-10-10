# R24 リソースの表と解放の枠

- 依存する作業: [R21](R21-unwinding-and-stop.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R24-resources

## 目的

`with` で束縛したリソースを、解放の枠で管理して解放できるようにする。リソースの表（`ResourceTable`）の関数と、リソースの状態の遷移（`Open`・`Lent`・`Releasing`・`Released`。ADR 0266 の決定 2・5）、`USE`・`RELEASE` の命令、`RETURN` が自分の解放の枠を先に解放する手順、枠を降ろす原因ごとの解放の枠の処理（`unwind_release`）を書く。

リソースを開く組み込みの関数（`File.openReader`・`TaskGroup.open`）は R25・R29 が書き、作業用のスレッドへの貸し出しと返却を行う完了の処理は R26 が書く。本作業は、それらが使う表と状態の遷移と、VM の解放の枠を作る。

## リソースの表の置き場所

リソースの表は `RunState::resources`（R20 が置いた。10-09「実行ごとの状態」）を使う。`unwind_release` と `USE`・`RELEASE` の処理は、この表を使う。

## 読む設計書の節

- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「リソースの追跡」（全体）、「タスクの待ちと取り消し」の完了の処理の順序（手順 1 の返却）
- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」のリソースの箇条、「枠の種類」の解放の枠、「実行の手順」の `RETURN`、「枠を降ろす原因と処理」、「リソースの解放の枠」、「組み込みの関数の呼び出し」の待つ理由の表のリソースの行、「止める手順」
- [リソース管理](../../2026-10-09-design-first-release/01-spec/01-10-resources.md)の全体
- [コア計算と脱糖](../../2026-10-09-design-first-release/01-spec/01-12-core-calculus.md)の「解放の枠と実行時エラーの継続：`with`」（E-Use・E-Release・E-RelErr・E-EscRel・E-ErrRel・E-ErrRelErr）
- ADR: [0266](../../2026-10-09-design-first-release/decisions/0266-task-and-resource-state-machines.md) の決定 2・4・5・9・11、[0150](../../2026-10-09-design-first-release/decisions/0150-resource-release-as-state.md)、[0149](../../2026-10-09-design-first-release/decisions/0149-http-exchange-release-failure.md)、[0164](../../2026-10-09-design-first-release/decisions/0164-taskgroup-release-while-stopping.md)、[0068](../../2026-10-09-design-first-release/decisions/0068-release-resources-on-stop.md)
- 検討資料: [相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 3。貸している間の記録を消すこと、解放の要求の後の再貸し出し、古い完了によるタスクの復活を主な危険として挙げ、取り消しと完了の順序を入れ替えて返却と解放が一度ずつ行われることを確かめるよう求めている。[相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 1・2・5（`Releasing` を見て解放の完了の前に枠を降ろすこと、`TaskGroup` の子の終わりを待つ間の取り消しで子を取り消さないこと、ブロックする解放の仕事の受け渡し）

インターフェース:

- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「リソースの表と状態」（状態の遷移の表、`ResourceTable` の関数）
- [仮想機械](../10-interfaces/10-09-vm.md)の「区画と枠」の `OtherKind::Release`、「枠を降ろす原因と処理」の解放の枠の行、`unwind_release`
- [バイトコード](../10-interfaces/10-07-bytecode.md)の `USE`・`RELEASE`・`RETURN`
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `OsResource`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「止まる理由」（`ResourceKind`・`ReleaseFailure`・`RuntimeError::ReleaseFailed`・`ReleasedResourceUsed`）

## 作るもの

- `src/runtime/io/resources.rs`: `ResourceTable` の関数の中身と、その単体テスト。
- `src/runtime/sched/mod.rs`: `Scheduler::new_ext_op_id` と `Scheduler::new_timer_id` の中身（欄 `next_ext_op`・`next_timer` を一つ進めて番号を返す。10-10）。`request_release` に渡す `ExtOpId` を作るために要る。ほかの `Scheduler` の関数は R25 が書くので、`sched/mod.rs` の仮置きの許可とコメントは消さない。
- `src/vm/unwind.rs`: `unwind_release` の中身（すべての原因）。後述の「並行の作業とのぶつかりの回避」に従う。`TaskGroup` の解放の枠は、原因ごとの分かれ方の形（戻りで待つ、取り消しで取り消して待つ、全体の停止で待たない）まで本作業が書き、子のタスクを待つ・取り消す中身は R25 が書く（10-09「作業の割り当て」）。中身を R25 が書く非公開の関数は、`unwind.rs` でなく `resource.rs` に置く。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する子のモジュール `src/vm/dispatch/resource.rs`: `USE`・`RELEASE` の命令の処理。命令の本体は `resource.rs` の冷たい関数に置き、`dispatch.rs` では `execute` の速い経路の `match` の `Opcode::Use | Opcode::Release` の分岐を、その関数の呼び出しに書き換える（後述の「性能」）。`RETURN` の解放の枠の処理は、R20 が `unwind_release` を呼ぶ形で置いてあるので、本作業はそれが動くことを確かめる。`Popped` の後に枠を `Vec` から取り出すのは呼び出し側である（10-09「枠を降ろす原因と処理」）。`RETURN` の途中で解放を待つ（`Wait(Release)`）ときは、戻る値と段が `ReturnWork` に残り（段は `OwnReleases`。10-09「戻りの再開状態」）、待ちが解けたら同じ枠から続く。
- `src/vm/dispatch/handlers.rs`（R20 が置いた）: 冷たい関数 `dispatch` の `RETURN` の判定を絞る（後述の「`RETURN` の遅い経路の判定」）。R20・R21 が置いたこの箇所は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。
- 上のファイルのテスト。

### 並行の作業とのぶつかりの回避

R22〜R24 は R21 の後に並行して進め、同じファイル（`dispatch.rs`・`unwind.rs`）を書き換える。取り込みのときにぶつからないように、次を守る。

- `dispatch.rs` の `Opcode::Lazy | Opcode::Force | Opcode::Update | Opcode::Use | Opcode::Release => Err(..)` の一つの分岐は、オーケストレータが起動の前に `Opcode::Lazy | Opcode::Force`・`Opcode::Update`・`Opcode::Use | Opcode::Release` の三つの分岐に分けておく。本作業は `Opcode::Use | Opcode::Release` の分岐だけを書き換える。
- 子のモジュールの宣言 `mod resource;` は、`dispatch.rs` の先頭の `mod` の並びの、名前の順の位置に置く。`unwind.rs` から `resource.rs` の補助の関数を呼ぶときは、宣言を `pub(super) mod resource;` とし、その関数を `pub(in crate::vm)` にする（`dispatch` の非公開の子のモジュールは、そのままでは `unwind.rs` から見えない）。
- `unwind.rs` は、受け持つ関数（`unwind_release`）の本体だけを書き換え、先頭の `use` の塊を変えない。補助の関数（中身を R25 が書く関数を含む）は `resource.rs` に置き、`unwind.rs` の本体からは完全なパス（`super::state::internal` など。R21 の `unwind_handle` と同じ書き方）で呼ぶ。
- `unwind.rs` の `todo!()` の仮置きの許可とコメント（00-02）は、本作業では消さない。R22〜R24 のうち最後に取り込むときに、オーケストレータが消す。

## 手順の要点

### リソースの型ごとの解放の仕方

`request_release` は、リソースの種類（`ResourceKind`）で解放がブロックするかを決める。02-09「リソースの追跡」のリソースの型ごとの解放の処理に従い、次のとおりとする。

| 種類 | 解放 | U2 での扱い |
|---|---|---|
| `FileReader` | ブロックしない。VM のスレッドで `OsResource::release`（ファイルを閉じる）を呼び、`Done` を返す | R29 が `File.openReader` で作る |
| `FileWriter` | ブロックする（書き出してから閉じる）。`Blocking` を返し、作業用のスレッドで解放する（仕事を出すのは R26） | U3 が作る。本作業は分岐だけを置く |
| `HttpListener` | ブロックしない（イベントループの登録を外して閉じる） | U3 が作る。本作業は分岐だけを置く |
| `HttpExchange` | ブロックする（応答を送っていなければ 500 を送ってから閉じる）。失敗は捨てる（ADR 0149） | U3 が作る。本作業は分岐と、失敗を捨てる規則を置く |
| `TaskGroup` | OS の資源を持たない。`TaskGroup(子のタスク)` を返し、待つか取り消すかは解放の枠が決める | R25 が `TaskGroup.open` で作る |

### `ResourceTable` の関数（10-10 の状態の遷移の表）

- `insert`: 番号を一つ進めて項目を加える。番号は実行の中で使い回さない（02-09「リソースの追跡」）。状態は `Open`。
- `lend`: `Open` なら資源を取り出して `Lent(op, false)` にし `Lent(資源)` を返す。`Lent(_, _)` なら呼んだタスクを `waiters` の末尾に加えて `MustWait`（返るまで待たせ、呼んだ順に行う）。`Releasing`・`Released` なら `Released(種類)`（解放したリソースの使用）。
- `remove_waiter`・`pop_waiter`: 返却を待つ並びからタスクを除く。`remove_waiter` は取り消しと止める手順（R25）が、`pop_waiter` は返却の後に要求をやり直す処理（R26）が呼ぶ。取り消したタスクを並びに残すと、返却の知らせで、解放の完了を待っているそのタスクを起こしてしまう（相談の第 7 回の指摘 1）。
- `give_back`: 資源を項目に戻す。`Lent(op, false)` なら `Open` に戻して `false`、`Lent(op, true)`（閉じる要求がある）なら `Open` に戻して `true` を返す。`true` を受けた呼び出し側（R26 の完了の処理）は、ほかの処理を挟まずに新しい操作の番号で `request_release` を呼ぶ。受け取る項目がない（表を捨てた後）ときは資源を破棄して OS の資源を閉じる（言語の解放ではない。ADR 0266 の決定 11）。返却を待っていたタスクの要求をやり直すのは呼び出し側である（`pop_waiter`）。
- `request_release`: 10-10 の遷移の表のとおりである。`Open` なら種類ごとの解放に進む（ブロックしない解放は `OsResource::release` を VM のスレッドで呼び、`Released` にして `Done`。ブロックする解放は OS の資源を項目に残したまま `Releasing(op)` にし、番号を `release_jobs` の末尾に加えて `Blocking`。`TaskGroup` は `Released` にして `TaskGroup(子)`）。`Lent(op, _)` なら `Lent(op, true)` にして `AfterReturn`（返った後に解放する。新しい貸し出しは受け付けない）。`Releasing` なら `InProgress`。`Released` なら `AlreadyReleased`、ただし `TaskGroup` は `TaskGroup(子)` を返し直す（後述の手順 5）。どの経路でも、解放の成否によらず最後は `Released` にする（01-12 の「事象 `release(V)` は、応答が `ok` か `error(r)` かによらず、V を解放済みにする」）。
- `take_release_job`: `release_jobs` の先頭の番号の項目から OS の資源を取り出し（`ResourceContent::Os(None)` にする）、番号、状態の `Releasing(op)` の `op`、資源を返す。仕事を `OpTable` に記録して作業用のスレッドへ出すのは R26 である（10-10「外部の操作の記録と完了」のブロックする解放の仕事の受け渡し）。
- `finish_release`: 状態を `Released` にし、結果が失敗なら理由を `release_failure` に入れる。`Releasing` のほか、返却の後に `request_release` が `Done` を返した場合（状態は既に `Released`）にも呼ばれる。
- `take_release_failure`: `release_failure` を取り出す。解放の完了を待った側（解放の枠か `begin_release` の呼び出し）が一度だけ読む。
- `close_all_silently`: 表に残った OS の資源を閉じる。失敗は報告しない（02-09「リソースの追跡」の束縛の文のリソースの段落）。

#### 凍結した戻り値で処理系の不具合を扱う方法（オーケストレータの決定、2026-10-06）

`new_ext_op_id`・`new_timer_id`・`insert`・`lend`・`request_release` の戻り値は凍結しており（10-10 の `sig=`）、`Result` ではない。シグネチャは変えずに、次のように扱う。

- 番号の計数（`next_ext_op`・`next_timer`・`next` の `u64`）は `wrapping_add(1)` で進める。一つの実行の中で 2^64 個の番号を使い切ることは起きない（1 ナノ秒に一つ作っても 500 年を超える）ので、番号を使い回さない規則（02-09「リソースの追跡」）は実際上守られる。この理由を、計数を進める箇所のコメントに書く。`checked_add` の失敗を `Stop` にする経路は作らない。
- `lend` と `request_release` に、表にない番号や状態・種類・中身の食い違った項目が渡ることは、処理系の不具合である。これを `Stop::Internal` で報告するために、`ResourceTable` に非公開の補助の関数（例 `pub(crate) fn check_lend(&self, id) -> Result<(), Stop>` と `check_release`。名前は作業が決める）を加え、VM と本作業の呼び出し側は、`lend`・`request_release` を呼ぶ前にこの関数で確かめて、食い違いを `Stop::Internal` で返す。凍結した関数の中では、確かめを通った入力を前提にし、到達しないはずの分岐は `debug_assert!` で不具合を示したうえで、状態を変えない安全な値（`lend` は `Released(種類)`、種類も決められなければ `MustWait` は使わず `Released` に表の既定の種類を入れるなど、作業が決める）を返す。到達しない理由をコメントに書く。
- 後の作業（R25・R26・R29・U3）が `lend`・`request_release` を呼ぶときも、同じ補助の関数で先に確かめる（10-10「リソースの表」の本文に書く）。

### `USE A`（E-Use）

上限を確かめて（解放の枠一つ）、`OtherKind::Release { resource: R[A] のリソースの番号, at: この命令 }` の解放の枠を積む。深さは実行中の区画の呼び出しの枠の数（積んだ呼び出しの枠に属するので、その呼び出しの枠の上にある）。`R[A]` がリソースの値でなければ `Stop::Internal`。

### `RELEASE`（E-Release）

実行中の呼び出しの枠に属する最も上の解放の枠（深さが実行中の区画の呼び出しの枠の数と等しい、最も上の解放の枠）を、原因 `Return` で `unwind_release` に渡す。ない場合は `Stop::Internal`。

`unwind_top`（R20）は `ReturnWork` を要る（`RETURN` の途中の処理である）ので使わず、自分で枠を `others` から取り出して `unwind_release` を呼び、結果で次のように分ける。

- `Popped`: 取り出した枠を `NoGcCtx::discard` でちょうど一度手放し、`StackMeter::shrink(1, 0)` して、次の命令へ進む。
- `Wait(理由)`: 枠を元の位置に戻し、`pc` を `RELEASE` に保ったまま待つ（命令の入口）。本作業の時点では、R21 と同じく `state.step = Some(VmStep::Requests(vec![]))` の形で止める（R25 が待たせる処理に改める）。起きたら `RELEASE` を初めから実行し直す。解放が完了していれば、`request_release` が `AlreadyReleased` を返し、手順 1 の経路で `Popped` になる。
- `Err(Stop)`: 枠を元の位置に戻して止まる。止める手順（R21）は、同じ枠を原因 `Stop` で処理するときに `request_release` から `AlreadyReleased` を受けるので、二度解放しない。同じ解放の失敗を、止まる理由と `StopEnd::release_failures` の両方に入れて二度報告しない。

### `unwind_release`（02-08「枠を降ろす原因と処理」の解放の枠の行）

1. `request_release` で解放を始める。`AlreadyReleased` なら、`take_release_failure` で記録した失敗を取り出す。失敗があれば手順 3 と同じく原因ごとに扱い、なければ `Popped`（02-08「リソースの解放の枠」。`close` で解放済みのリソースを `with` が二度解放しない）。`AlreadyReleased` を返すのは `Released` のときだけである。
2. `Done(Ok)` なら `Popped`。
3. `Done(Err(理由))` なら、原因で分ける。`HttpExchange` の失敗はどの原因でも捨てて `Popped`。
   - `Return`: `Err(Stop::Runtime(RuntimeError::ReleaseFailed(vec![ReleaseFailure { .. }])))` を返す（E-RelErr。組 `ReleaseFailed(Vec<ReleaseFailure>)` に、この解放の失敗一つを入れる）。止める手順（R21）が残りの解放の枠を解放し、失敗を加える（E-ErrRel・E-ErrRelErr）。
   - `Cancel`・`DropRel`: `log` に `ReleaseFailure` を加えて `Popped`。辿り終えてから実行時エラーにするのは辿りの関数（R21）である。
   - `Stop`: `log` に加えて `Popped`。
4. `Blocking`・`AfterReturn`・`InProgress` なら、`Wait(WaitReason::Release(番号))` を返す。枠は残り、解放の完了（`ReleaseFinished`。R26）で起こされた後に同じ枠に同じ原因でもう一度呼ばれる。もう一度呼ばれたときの状態が `Lent(_, true)` か `Releasing` なら（返却は済んだが解放の完了がまだの場合を含む）、`AfterReturn`・`InProgress` の経路でもう一度待ち、`Released` になって初めて手順 1 の `AlreadyReleased` の経路で `Popped` にする。解放を繰り返さず、解放を終える前に枠を降ろさない。ブロックする解放の失敗は、完了（`Outcome::Released(Err)`）を取り込んだときに `finish_release` が `release_failure` に記録し、手順 1 で取り出して、今の原因で扱う（取り消しか全体の停止で原因が変わっていれば、変わった後の原因で扱う）。作業用のスレッドへ解放の仕事を出す処理は R26 が書く。本作業は `release_jobs` に番号を加えるところまでを書く。本作業の時点では、U2 にブロックする解放を持つリソースの型がないので、この経路は `ResourceTable` の単体テストと、`unwind_release` を直接呼ぶ単体テストで確かめる。
5. `TaskGroup(子)` なら、原因で分ける（ADR 0164）。`TaskGroup` は、一度目の呼び出しで `Released` になり（新しい `spawn` を受け付けない）、枠が残る間は、呼ばれるたびに `request_release` が子の並びを返し直す。子の終わりの待ちが済んだことは、状態ではなく、この手順で終わっていない子がないことで決める（相談の第 7 回の指摘 2）。
   - `Return`: 終わっていない子があれば `Wait(TaskEnd(TaskGroupRelease(番号)))`、なければ `Popped`。
   - `Cancel`: 終わっていない子を取り消し（取り消しの要求を既に受けた子には何もしない）、残れば `Wait(TaskEnd(TaskGroupRelease(番号)))`、なければ `Popped`。`DropRel` も同じとする。`Return` で子の終わりを待っている間にタスクが取り消されると、同じ枠が原因 `Cancel` で呼ばれ、この分岐で子を取り消す。
   - `Stop`: 待たずに `Popped`。
   タスクの終わりを調べる処理は R25、取り消す処理は R39 が書く（10-09「作業の割り当て」）。本作業は、中身を後の作業が書く非公開の関数を呼ぶ形で分岐を置き、`TaskGroup` の経路のテストは R25（原因 `Return`）と R39（原因 `Cancel`）が行う。

解放の失敗の `ReleaseFailure::opened_at` には、項目の `opened_at`（リソースを開いた呼び出しの命令）を入れる。`unwind_release` の `opened_at` の引数（枠を積んだ `USE`）は、項目に開いた位置がないときに使う。

### `RETURN` の遅い経路の判定

`execute` の速い経路の `RETURN` は、実行中の区画の `others` が空でなければ `handlers.rs` の冷たい関数 `dispatch` へ出る。そこでは今、最も上のほかの枠の深さ `o.depth` が `calls.len() − 1` 以上なら `begin_return`（`ReturnWork` を作る経路）へ進む。この判定は、呼び出し元の解放の枠（深さ = `calls.len() − 1`）でも真になるので、`with` の中から呼んだ関数の戻りが、すべて `ReturnWork` を作る経路を通る。

判定を `o.depth == calls.len() || (o.depth + 1 == calls.len() && o.kind が包む枠)` の形に絞る（`OtherKind::is_wrapping`）。前者は `RETURN` 自身の解放の枠、後者は降ろす呼び出しの枠を包む枠である。呼び出し元の解放の枠だけが最も上にあるときは、普通の戻り（`return_plain`）を通る。速い経路の `others.is_empty()` の判定は変えない。

### 回収の前の整理（ADR 0314）

R21 と同じく、本作業が加える状態を [ADR 0314](../../2026-10-09-design-first-release/decisions/0314-clear-dead-registers-at-safepoints.md) の決定 5 の「命令の入口」と「結果が書かれる前の呼び出し元」のどちらかに分類する表を、完了の報告に書き、分類どおりに空にする。少なくとも次の状態を表に入れる。

- `RELEASE` の待ち: 「命令の入口」。`pc` は `RELEASE` を指したままであり、起きたら `RELEASE` を実行し直す。
- `RETURN` の途中の解放の待ち（`ReturnWork` の段が `OwnReleases` の間）: R20 の表のとおり（最も内側の枠は `RETURN` の入口。今の `clear_dead_registers` の扱い）。
- 辿りの途中の解放の待ち（E-DropRel・取り消し・全体の停止で `UnwindWork` の区画の解放の枠が待つ間と、`ESCAPE` で降ろす途中の解放の枠が待つ間）: 保守的に残す。`UnwindWork::segments` の区画は整理しない（R21）。段が `Escaping` の間は、今の `clear_dead_registers` が窓を空にしない。

分類を確かめていない状態は、空にしない。

### 性能

普通の経路（`CALL`・`TAILCALL`・`RETURN` の速い経路、`execute` のループの頭）に処理を足さない。`USE`・`RELEASE` の本体は `resource.rs` の冷たい関数（`#[cold]`・`#[inline(never)]`）に置き、`execute` の速い経路の `match` の `Opcode::Use | Opcode::Release` の分岐からその関数を呼ぶ。`handlers.rs` の冷たい関数 `dispatch` の `else if` の連なりには分岐を足さない（前述の `RETURN` の判定を絞る変更は、既存の分岐の条件を変えるだけである）。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（R26 の後と最後に、オーケストレータが行う）。

## 受け入れテスト

リソースを開く組み込みの関数は後の作業が書くので、本作業のテストは、テストのモジュールの中で `OsResource` を実装する偽の資源（解放の成否と、解放を呼んだ回数を記録するもの）を使う。VM の命令の経路は、組み立てたバイトコードのプログラム（`bytecode::asm`）を VM に載せ、偽の資源をリソースの表に加えて、その番号のリソースの値をレジスタに置いてから実行する VM の単体テストで確かめる（リソースの値を作る命令はないので、レジスタに置く処理は `vm` のモジュールの中のテスト用の非公開の補助として書いてよい）。スクリプトからの確かめは R29（`File.openReader`）と C12 が行う。

- `ResourceTable` の状態の遷移: 10-10 の遷移の表のすべての升目（状態 × 操作）を一つずつ確かめる。とくに、`Lent(op, false)` の間の解放の要求で `Lent(op, true)` になり、`give_back` が `true` を返すこと。`Lent(op, true)` の間の貸し出しが待たされること。`Released` の使用が `Released(種類)` になること。`Releasing` の解放の要求が `InProgress` を返し、`AlreadyReleased` を返さないこと。ブロックする解放の `request_release` の後、`take_release_job` が資源を一度だけ返すこと。
- 返却を待つ並びからの除去: 返却を待つ並びに入れたタスクを `remove_waiter` で除くと、後の返却で `pop_waiter` がそのタスクを返さない。
- 返却を待つ順序: 同じリソースに三つのタスクが貸し出しを求めたとき、返却のたびに呼んだ順に一つずつ受け付ける。
- 解放の枠と `RETURN`: `USE` の後に `RETURN` する関数の呼び出しで、偽の資源の解放がちょうど一度呼ばれる。二つの `USE` を積んだ関数で、後に積んだものから順に解放される。
- 呼び出し元の解放の枠に進まない: 呼び出し元 A が `USE` を積んでから関数 B を呼び、B が `RETURN` しても A のリソースは解放されず、A の `RETURN` で解放される。B の `RETURN` は普通の戻り（`return_plain`）を通り、`ReturnWork` を作らない（前述の「`RETURN` の遅い経路の判定」。VM の単体テストで、B の戻りの間に `RunState::returning` が作られないことなどで確かめる）。
- `RELEASE`: `RELEASE` がそのリソースを解放し、後の `RETURN` は二度解放しない。
- 解放の失敗（`Return`）: 失敗する偽の資源の解放で `ReleaseFailed` の実行時エラーになり、同じ関数の別の解放の枠のリソースも解放され、その失敗も止める手順の解放の失敗に加わる。
- 解放の失敗（`Stop`）: 0 の除算で止まるプログラムの止める手順で、解放の枠のリソースが内側から順に解放され、失敗が `StopEnd::release_failures` に入り、止まる理由は `DivisionByZero` のままである。
- 捨てる継続の中の解放の枠（E-DropRel）: `handle` の本体の中の `with` に当たる解放の枠を持つ継続を、節が `resume` せずに捨てると、そのリソースが解放される。失敗は、辿り終えてから `ReleaseFailed` の実行時エラーになる。
- 待つ解放: `unwind_release` を直接呼ぶ単体テストで、`AfterReturn` と `Blocking` のときに `Wait(Release)` を返す。返却を記録した後（`give_back` の後に `request_release` で `Releasing` にし、解放の完了はまだ記録しない）に呼び直すと、もう一度 `Wait(Release)` を返し、枠が残る。解放の完了を `finish_release` で記録した後の呼び出しで初めて、解放を繰り返さずに `Popped` を返す（相談の第 7 回の指摘 1）。解放の完了を失敗で記録した場合は、原因 `Return` で `ReleaseFailed`、`Cancel`・`Stop` で `log` に加わり、`HttpExchange` では捨てられる。待つ間に原因を `Return` から `Cancel` に変えて呼び直すと、失敗は `Cancel` の規則で扱われる。
- `HttpExchange` の種類の偽の資源の解放の失敗が、どの原因でも捨てられる。
- 回収の強制のビルドで、上のテストがすべて通る。
- 上限の直前の `PERFORM`（R21 からの引き渡し。相談の第 6 回の指摘 3）: `HANDLE` の本体の中で `USE r` を積み、`drop` の枠と節の呼び出しの枠と節の窓の分だけが足りない `max_call_stack_bytes` で `PERFORM` する。`PERFORM` の命令で `CallStackTooDeep` で止まり、止める手順で `r` の偽の資源の解放がちょうど一度呼ばれ、止めた後の計数が 0 に戻る。上限に余裕のある設定で同じプログラムを実行し、節が `resume` せずに終わる場合（E-DropRel）と、節の中で 0 の除算を起こす場合（捕まえた継続の中を原因 `Stop` で辿る）でも、解放がちょうど一度呼ばれることを確かめる。
- 枠の順序と解放の順序（R21 からの引き渡し）: 一つの区画に「呼び出しの枠 A、A に属する解放の枠、A が呼んだ関数を包む枠、呼び出しの枠 B、B に属する解放の枠」を持つ状態を実際の `USE` と `HANDLE` で作り、全体の停止と E-DropRel のそれぞれで、偽の資源の解放が B のもの、A のものの順に一度ずつ呼ばれる。`ESCAPE` で `handle` を抜けるとき、途中の解放の枠が内側から一度ずつ解放される。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 同じリソースの解放が、どの経路でも一度しか行われない
- 解放したリソースの番号を使い回さない
- `TaskGroup` の子を待つ・取り消す箇所を R25 が埋める形で置いたことと、ブロックする解放の仕事を `release_jobs` に残し、出すのは R26 であることを、完了の報告の「残したこと」に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」と「スケジューラと IO」の行。とくに、タスクとリソースの状態の組み合わせごとにテストがあるか。
- 10-10 の遷移の表の各升目が、コードの分岐と一対一で対応しているか。
- `Lent(op, true)` の後に新しい貸し出しを受け付けていないか。
- 解放の成否によらず、最後に `Released` にしているか。
- `AlreadyReleased` を `Released` のときだけ返し、`Releasing` と `Lent(_, true)` で枠を降ろしていないか。
- `RETURN` が、自分の解放の枠を呼び出しの枠を降ろす前に処理し、呼び出し元の解放の枠に進んでいないか。

## 難易度の理由

リソースの四つの状態と、解放・貸し出し・返却・使用の操作と、枠を降ろす四つの原因の組み合わせが多く、どれかを誤ると二重の解放か、戻らないリソースになる。作業用のスレッドとタスクが揃う前に書くので、待つ経路を単体テストで押さえておく必要がある。
