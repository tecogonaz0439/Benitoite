# R22 `Lazy` の対象と `FORCE`・`UPDATE` の枠

- 依存する作業: [R21](R21-unwinding-and-stop.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R22-lazy

## 目的

明示遅延（`lazy` の式と `Lazy.force`）を VM で実行する。`LAZY` で「評価の前」の `Lazy` の対象を作り、`FORCE` で本体を一度だけ評価して結果を対象に書く。`Lazy` の対象は三つの状態（`Before`・`Evaluating`・`Done`）を持ち、評価の途中の対象を枠を降ろす原因ごとに正しく戻す（ADR 0267 の決定 2・4）。

命令の `UPDATE`（`Reference.update`）は R23 が扱う。本作業が扱うのは `update` の枠（02-08「枠の種類」の、評価の途中の `Lazy` の対象を持つ枠。10-09 の `OtherKind::Update`）である。

## スケジューラの置き場所

`update` の枠を降ろす処理は、`Lazy` を待つタスクを起こす。待つタスクは `rt.scheduler.wake` で起こす（`RunState::scheduler`。R20 が置いた。10-09「実行ごとの状態」）。本作業の時点ではタスクが一つなので待つタスクの並びは常に空だが、起こす処理はこの形で書く。

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

- `src/vm/unwind.rs`: `unwind_update` の中身（すべての原因）。`src/vm/unwind.rs` の `todo!()` の仮置き（00-02）は、R20・R22・R23・R24 がそれぞれ受け持つ関数を書き換える。R22〜R24 は R21 の後に並行して進めるので、仮置きの許可とコメントは、四つのうち最後に `todo!()` を書き換えた作業（取り込みの時点でファイルに `todo!()` が残っていない作業）が消す。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する非公開の子のモジュール `src/vm/dispatch/lazy.rs`: `LAZY`・`FORCE` の命令の処理。`dispatch.rs` には `match` の分岐だけを加える。
- 上のファイルのテストと、`tests/` の下の統合テストのファイル。

## 手順の要点

### `LAZY A Bx`（E-Lazy）

原型 `P[Bx]`（引数のない `lazy` の本体）と、その捕捉の表に従って集めた値から、`CLOSURE` と同じく関数の値を作り、それを持つ `LazyState::Before { body }` の対象を `alloc_host` で作って `R[A]` に入れる。関数の値を作る処理は、第 1 段の `CLOSURE` の処理（R09）を共有する。

### `FORCE A B`

`R[B]` の対象を `host::<LazyState>` で読み、状態で分ける。対象が `Lazy` でなければ `Stop::Internal`。

- `Done { value }`（E-ForceDone）: `value` を `R[A]` に入れて続ける。
- `Before { body }`（E-Force）:
  1. `update` の枠一つと本体の呼び出しの枠と本体の原型のレジスタの数を `StackMeter::fits` で確かめる。
  2. 切り替えの位置の処理を行う（本体の呼び出しは切り替えの位置である。02-08「タスクの切り替え」）。手順 1・2 と、回収・切り替えの後の再開は 10-09「呼び出しの前の安全点」に従う。再開したときは `FORCE` を初めから実行し直すので、切り替えの間に別のタスクが評価を始めていれば、下の `Evaluating` の経路に進む（そのときも印を消す）。
  3. `host_mut` で状態を `Evaluating { body, by: 実行中のタスク, waiters: [] }` にする。本体の関数を捨てない（取り消しと止める手順で「評価の前」に戻すため。ADR 0267 の決定 2）。
  4. `update` の枠（`OtherKind::Update { lazy: R[B], at: この命令 }`、深さは実行中の区画の呼び出しの枠の数）を積み、本体の関数を引数なしで呼ぶ（呼び出しの枠の `ret` は `R[A]` の位置）。
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

## 受け入れテスト

テストは、スクリプトをパイプラインでコンパイルして `run_program` で実行するか、VM の単体テストで確かめる。タスクを使う場合（別のタスクが評価している `Lazy` を待つ場合、評価しているタスクの取り消し）は、R25 の受け入れテストで確かめる。

- `lazy` の本体が一度だけ評価される: 本体の中で `Console.writeLine` を呼べない（純粋）ので、本体の評価の回数は、本体の中の重い計算の有無ではなく、同じ `Lazy` を二度 `Lazy.force` した結果が等しいことと、二度目の `FORCE` が `Done` の経路を通ること（VM の単体テストで状態を確かめる）で確かめる。
- 入れ子の `Lazy`: `Lazy` の本体の中で別の `Lazy` を `force` する。
- 全体の停止: 本体の中で 0 の除算を起こしたプログラムが止まり、止めた後の対象の状態が `Before` に戻っている（VM の単体テストで確かめる）。
- E-DropRel: `Lazy` の本体の評価の途中で操作を呼び、`handle` の節が `resume` せずに終わる形を作れるかを確かめる。`lazy` の本体は純粋であり、`resume` を書けない（ADR 0155）が、本体から外側のハンドラの操作を呼ぶことも型検査が許さない。この経路はプログラムからは作れないので、`unwind_update` を原因 `DropRel` で直接呼ぶ単体テストで、状態が `Before` に戻り、待つタスクの並び（テストで入れた番号）の全員が起こされることを確かめる。同じ単体テストで、原因 `Stop` では誰も起こされないことを確かめる。
- 深い `Lazy` の連鎖: 前の `Lazy` を `force` する本体の `Lazy` を 10 万個つないだ値の最後を `force` しても、処理系の再帰で深くならない（呼び出しの入れ子の上限の範囲で止まるか、結果を返す）。止まる場合は `CallStackTooDeep` で止まる。
- 回収の強制のビルドで、上のテストがすべて通る。`Evaluating` の対象の本体の関数が、評価の途中の回収で残る。
- 根の置き場ごとの回収の強制（R03「根の列挙の引き渡し」の表の、本作業の行）: `HeapConfig::stress` を真にした設定で、`Lazy` の対象が `update` の枠（`OtherKind::Update` の `lazy`）だけから辿れる状態（`FORCE` の被演算子のレジスタを最後の使用として空にした後、本体の中で回収する）と、`Before` の対象の本体の関数の捕捉だけに残る値のそれぞれで回収し、評価の後に `Done` の値と、もう一度の `force` の結果が正しいことを確かめる（二つの方式の両方で）。

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

## 難易度の理由

命令そのものは短いが、`Lazy` の対象の三つの状態と、枠を降ろす四つの原因の組み合わせを誤ると、止める途中に本体を評価し直すような、再現しにくい誤りになる。タスクを使う経路は後の作業で確かめるので、本作業では単体テストで原因ごとの振る舞いを押さえておく必要がある。
