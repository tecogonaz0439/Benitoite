# R22 `Lazy` の対象と `FORCE`・`UPDATE` の枠

- 依存する作業: [R21](R21-unwinding-and-stop.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R22-lazy

## 目的

明示遅延（`lazy` の式と `Lazy.force`）を VM で実行する。`LAZY` で「評価の前」の `Lazy` の対象を作り、`FORCE` で本体を一度だけ評価して結果を対象に書く。`Lazy` の対象は三つの状態（`Before`・`Evaluating`・`Done`）を持ち、評価の途中の対象を枠を降ろす原因ごとに正しく戻す（ADR 0267 の決定 2・4）。

命令の `UPDATE`（`Reference.update`）は R23 が扱う。本作業が扱うのは `update` の枠（02-08「枠の種類」の、評価の途中の `Lazy` の対象を持つ枠。10-09 の `OtherKind::Update`）である。

## スケジューラの置き場所

`update` の枠を降ろす処理は、`Lazy` を待つタスクを起こす。待つタスクは、そのタスクが今も `Lazy` の評価を待っていることを確かめてから `rt.scheduler.wake_if` で起こす（`RunState::scheduler`。R20 が置いた。10-09「実行ごとの状態」、R25「待つタスクを知らせで起こすとき」）。本作業の時点ではタスクが一つなので待つタスクの並びは常に空だが、起こす処理はこの形で書く（`Scheduler::wake_if` の中身は R25 が書き、今は `todo!()` である）。

## 読む設計書の節

- [仮想機械](../../design/02-impl/02-08-vm.md)の「値の表現」の `Lazy` の行、「枠の種類」の `update` の枠、「枠を降ろす原因と処理」、「組み込みの関数の呼び出し」の待つ理由の表の `Lazy` の行、「明示遅延」、「タスクの切り替え」の切り替えの位置の処理（`FORCE` は本体を呼ぶ切り替えの位置である）、「止める手順」の手順 2 の `update` の枠
- [評価意味論](../../design/01-spec/01-08-evaluation.md)の「明示遅延（初回リリース版）」
- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md)の「ストア：可変のセルと明示遅延」（E-Lazy・E-ForceDone・E-Force・E-Update）
- [型システム](../../design/01-spec/01-06-type-system.md)の「明示遅延の型（初回リリース版）」
- ADR: [0267](../../design/decisions/0267-lazy-and-reference-objects.md)、[0066](../../design/decisions/0066-explicit-laziness-pure-body.md)、[0155](../../design/decisions/0155-resume-not-in-lazy.md)、[0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 7（`Lazy` の結果の書き込みは書き込みの障壁の位置）
- 検討資料: [相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)の問い 4。全体の停止の途中で待つタスクを通常の実行に戻すと、止めている途中に本体を評価し直せてしまうという指摘と、そのためのテスト（評価しているタスクだけを取り消す場合、待つタスクだけを取り消す場合、全体の停止、E-DropRel、待つ間の安全点）を挙げている

インターフェース:

- [仮想機械](../10-interfaces/10-09-vm.md)の「ハンドラの記録、継続、`Lazy`」（`LazyState`）、「枠を降ろす原因と処理」の `update` の枠の行、`unwind_update`
- [バイトコード](../10-interfaces/10-07-bytecode.md)の「明示遅延、可変のセル、リソース」の `LAZY`・`FORCE`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「セルと `Host` の対象」（`alloc_host`・`host`・`host_mut`）
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の `Lazy.force`（専用の命令 `FORCE`。`raw` は `Stop::Internal` を返す）

## 作るもの

- `src/vm/unwind.rs`: `unwind_update` の中身（すべての原因）。後述の「並行の作業とのぶつかりの回避」に従う。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する子のモジュール `src/vm/dispatch/lazy.rs`: `LAZY`・`FORCE` の命令の処理。命令の本体は `lazy.rs` の冷たい関数に置き、`dispatch.rs` では `execute` の速い経路の `match` の `Opcode::Lazy | Opcode::Force` の分岐を、その関数の呼び出しに書き換える（後述の「性能」）。
- `src/vm/dispatch.rs` の `build_closure`: `LAZY` が `CLOSURE` の処理を共有するために、関数の値を作って返す補助の関数を切り出してよい。今の `build_closure` は作った値を `R[A]` に書き込む作りであり、`LAZY` は関数の値を `Lazy` の対象に入れるからである。`CLOSURE` の分岐の振る舞いは変えない。
- 上のファイルのテストと、`tests/` の下の統合テストのファイル。

### 並行の作業とのぶつかりの回避

R22〜R24 は R21 の後に並行して進め、同じファイル（`dispatch.rs`・`unwind.rs`）を書き換える。取り込みのときにぶつからないように、次を守る。

- `dispatch.rs` の `Opcode::Lazy | Opcode::Force | Opcode::Update | Opcode::Use | Opcode::Release => Err(..)` の一つの分岐は、オーケストレータが起動の前に `Opcode::Lazy | Opcode::Force`・`Opcode::Update`・`Opcode::Use | Opcode::Release` の三つの分岐に分けておく。本作業は `Opcode::Lazy | Opcode::Force` の分岐だけを書き換える。
- 子のモジュールの宣言 `mod lazy;` は、`dispatch.rs` の先頭の `mod` の並びの、名前の順の位置に置く。`unwind.rs` から `lazy.rs` の補助の関数を呼ぶときは、宣言を `pub(super) mod lazy;` とし、その関数を `pub(in crate::vm)` にする（`dispatch` の非公開の子のモジュールは、そのままでは `unwind.rs` から見えない）。
- `unwind.rs` は、受け持つ関数（`unwind_update`）の本体だけを書き換え、先頭の `use` の塊を変えない。補助の関数は `lazy.rs` に置き、`unwind.rs` の本体からは完全なパス（`super::state::internal` など。R21 の `unwind_handle` と同じ書き方）で呼ぶ。
- `unwind.rs` の `todo!()` の仮置きの許可とコメント（00-02）は、本作業では消さない。R22〜R24 のうち最後に取り込むときに、オーケストレータが消す。

## 手順の要点

### `LAZY A Bx`（E-Lazy）

原型 `P[Bx]`（引数のない `lazy` の本体）と、その捕捉の表に従って集めた値から、`CLOSURE` と同じく関数の値を作り、それを持つ `LazyState::Before { body }` の対象を `alloc_host` で作って `R[A]` に入れる。関数の値を作る処理は、第 1 段の `CLOSURE` の処理（R09）を共有する（「作るもの」の `build_closure` の箇条）。確保する命令なので、分岐の中で `after_alloc` を返す。

### `FORCE A B`

`R[B]` の対象を `host::<LazyState>` で読み、状態で分ける。対象が `Lazy` でなければ `Stop::Internal`。

- `Done { value }`（E-ForceDone）: `value` を `R[A]` に入れて続ける。
- `Before { body }`（E-Force）:
  1. `update` の枠一つと本体の呼び出しの枠と本体の原型のレジスタの数を `StackMeter::fits` で確かめる。
  2. 切り替えの位置の処理を行う（本体の呼び出しは切り替えの位置である。02-08「タスクの切り替え」）。手順 1・2 と、回収・切り替えの後の再開は 10-09「呼び出しの前の安全点」に従う。再開したときは `FORCE` を初めから実行し直すので、切り替えの間に別のタスクが評価を始めていれば、下の `Evaluating` の経路に進む（そのときも印を消す）。
  3. `host_mut` で状態を `Evaluating { body, by: 実行中のタスク, waiters: [] }` にする。本体の関数を捨てない（取り消しと止める手順で「評価の前」に戻すため。ADR 0267 の決定 2）。
  4. `update` の枠（`OtherKind::Update { lazy: R[B], at: この命令 }`、深さは実行中の区画の呼び出しの枠の数）を積み、本体の関数を引数なしで呼ぶ（呼び出しの枠の `ret` は `R[A]` の位置）。`FORCE` は呼び出しに似た命令（生存の解析の `call_writes` に入る）なので、10-09「呼び出しの前の安全点」の手順 3 のとおり、呼び出し元の枠の `pc` を次の命令へ進めて保存してから枠を積む（後述の「回収の前の整理」）。
- `Evaluating { by, .. }` で `by` が実行中のタスク: 型検査を通ったプログラムでは起きない（01-12「ストア：可変のセルと明示遅延」の最後の箇条）。`Stop::Internal` で止まる。
- `Evaluating { by, waiters }` で `by` が別のタスク: 実行中のタスクを `waiters` に加え、`WaitReason::Lazy` でタスクを待たせる。命令の位置を進めずに（`FORCE` を指したまま）待たせ、起きたら `FORCE` をもう一度実行する。タスクは R25 が作るので、この経路のテストは R25 が行う。

### `unwind_update`（02-08「枠を降ろす原因と処理」の `update` の枠の行）

| 原因 | 処理 |
|---|---|
| `Return` | 戻る値（実行中のタスクの `ReturnWork::value`。10-09「戻りの再開状態」）を読み、`host_mut` で状態を `Done { value }` にし、本体の関数を捨てる。待つタスクをすべて起こし、`Popped` を返す（E-Update）。値を `update` の枠の下の呼び出しの結果のレジスタに入れるのは、`RETURN` の手順（R20）が行う |
| `Cancel`・`DropRel` | 状態を `Before { body }` に戻し、待つタスクをすべて起こして `Popped`。起きたタスクは `FORCE` をやり直し、そのうち一つが評価を始める |
| `Stop` | 状態を `Before { body }` に戻して `Popped`。待つタスクは起こさない。待つタスクも同じ止める手順で止まるからである（ADR 0267 の決定 4、相談の第 3 回の問い 4） |

- 状態が `Evaluating` でなければ `Stop::Internal`（`update` の枠が指す対象は、枠を積んでから降ろすまで `Evaluating` のはずである）。
- 起こすタスクの番号は所有しない `TaskId` であり、世代が合わなければ（そのタスクが終わっていれば）飛ばす（ADR 0267 の決定 3）。
- 状態の書き換えは `host_mut` だけで行う（書き込みの障壁の位置。10-08 の不変条件 H7）。

`Lazy` の本体は純粋なので、途中まで評価して「評価の前」に戻した本体をもう一度評価しても、観測できる違いはない（02-08「明示遅延」）。

### 行き詰まりの判定での扱い

`WaitReason::Lazy` は内部の待ちであり、外部の完了の待ちに数えない（`WaitReason::is_external` は C02 が置いた。ADR 0267 の決定 5）。行き詰まりの記録（`DeadlockWaitKind::Lazy`、待つ命令は `FORCE`）は R25 が作る。

### 回収の前の整理（ADR 0314）

R21 と同じく、本作業が加える状態を [ADR 0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md) の決定 5 の「命令の入口」と「結果が書かれる前の呼び出し元」のどちらかに分類する表を、完了の報告に書き、分類どおりに空にする。少なくとも次の状態を表に入れる。

- `FORCE` の本体の評価中の、`FORCE` を実行した枠: 「結果が書かれる前の呼び出し元」。本体の値は、`RETURN` が `update` の枠を処理した後に `R[A]` へ書かれる。`pc` を次の命令へ進めて保存してあるので、`call_write(pc − 1)` が `R[A]` を指す。進めずに保存すると、`pc − 1` の別の命令の結果のレジスタを消す（R20「回収の前の整理」の最初の箇条と同じ）。
- 別のタスクの評価を待つ `FORCE`（`Evaluating` の対象の `waiters` に加わって待つ間）: 「命令の入口」。`pc` は `FORCE` を指したままであり、起きたら `FORCE` を実行し直すので、`R[B]` が残る。

分類を確かめていない状態は、空にしない。

### 性能

普通の経路（`CALL`・`TAILCALL`・`RETURN` の速い経路、`execute` のループの頭）に処理を足さない。`LAZY`・`FORCE` の本体は `lazy.rs` の冷たい関数（`#[cold]`・`#[inline(never)]`）に置き、`execute` の速い経路の `match` の `Opcode::Lazy | Opcode::Force` の分岐からその関数を呼ぶ。`handlers.rs` の冷たい関数 `dispatch` の `else if` の連なりには分岐を足さない。確保する `LAZY` は、その分岐の中で `after_alloc` を返す（振り分けの末尾で回収の要求を確かめる処理はもうない）。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（R26 の後と最後に、オーケストレータが行う）。

## 受け入れテスト

テストは、スクリプトをパイプラインでコンパイルして `run_program` で実行するか、VM の単体テストで確かめる。タスクを使う場合（別のタスクが評価している `Lazy` を待つ場合、評価しているタスクの取り消し）は、R25 の受け入れテスト（取り消しを伴う場合は R39）で確かめる。

- `lazy` の本体が一度だけ評価される: 本体の中で `Console.writeLine` を呼べない（純粋）ので、本体の評価の回数は、本体の中の重い計算の有無ではなく、同じ `Lazy` を二度 `Lazy.force` した結果が等しいことと、二度目の `FORCE` が `Done` の経路を通ること（VM の単体テストで状態を確かめる）で確かめる。
- 入れ子の `Lazy`: `Lazy` の本体の中で別の `Lazy` を `force` する。
- 全体の停止: 本体の中で 0 の除算を起こしたプログラムが止まり、止めた後の対象の状態が `Before` に戻っている（VM の単体テストで確かめる）。
- E-DropRel: `Lazy` の本体の評価の途中で操作を呼び、`handle` の節が `resume` せずに終わる形を作れるかを確かめる。`lazy` の本体は純粋であり、`resume` を書けない（ADR 0155）が、本体から外側のハンドラの操作を呼ぶことも型検査が許さない。この経路はプログラムからは作れないので、`unwind_update` を原因 `DropRel` で直接呼ぶ単体テストで、状態が `Before` に戻り、待つタスクの並びが空になることを確かめる。待つ並びにタスクがあると `Scheduler::wake_if`（中身は R25。今は `todo!()`）を呼ぶので、待つ並びのタスクが起こされたかどうかと、原因 `Stop` で誰も起こされないことは、R25 の受け入れテストへ引き渡す（後述の「R25 へ引き渡すテスト」）。本作業のテストで待つ並びにタスクを入れるかは、作業が決めてよい（入れるなら、`wake_if` を呼ばずに確かめられる形にする。たとえば原因 `Stop` で並びを手放すだけの経路）。
- 深い `Lazy` の連鎖: 前の `Lazy` を `force` する本体の `Lazy` を 10 万個つないだ値の最後を `force` しても、処理系の再帰で深くならない（呼び出しの入れ子の上限の範囲で止まるか、結果を返す）。止まる場合は `CallStackTooDeep` で止まる。
- 回収の強制のビルドで、上のテストがすべて通る。`Evaluating` の対象の本体の関数が、評価の途中の回収で残る。
- 根の置き場ごとの回収の強制（R03「根の列挙の引き渡し」の表の、本作業の行）: `HeapConfig::stress` を真にした設定で、`Lazy` の対象が `update` の枠（`OtherKind::Update` の `lazy`）だけから辿れる状態（`FORCE` の被演算子のレジスタを最後の使用として空にした後、本体の中で回収する）と、`Before` の対象の本体の関数の捕捉だけに残る値のそれぞれで回収し、評価の後に `Done` の値と、もう一度の `force` の結果が正しいことを確かめる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- `Lazy` の状態の書き換えが `host_mut` だけで行われている
- 全体の停止の原因で、待つタスクを起こしていない

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」の行。
- `unwind_update` の各原因の処理が、02-08 の表の `update` の枠の行と一対一で対応しているか。とくに `Stop` と `Cancel`・`DropRel` を取り違えていないか。
- `FORCE` で待たせたタスクが起きたとき、命令の位置を進めずに `FORCE` をやり直す形になっているか。
- 待つタスクの並びを、所有しない番号として扱い、回収で辿っていないか。

## R25 へ引き渡すテスト

次の場合は、`Scheduler::wake_if` の中身（R25）がないので本作業では確かめられない。R25 の受け入れテストに書いてある。

| 場合 | 引き受ける作業 |
|---|---|
| `unwind_update` を原因 `DropRel`（と `Cancel`）で呼ぶと、`Lazy` を待つ並びのタスクの全員が起こされる | R25 |
| `unwind_update` を原因 `Stop` で呼ぶと、待つ並びのタスクが誰も起こされない | R25 |

## 難易度の理由

命令そのものは短いが、`Lazy` の対象の三つの状態と、枠を降ろす四つの原因の組み合わせを誤ると、止める途中に本体を評価し直すような、再現しにくい誤りになる。タスクを使う経路は後の作業で確かめるので、本作業では単体テストで原因ごとの振る舞いを押さえておく必要がある。
