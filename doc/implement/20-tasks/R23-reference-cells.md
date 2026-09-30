# R23 `Reference` の VM への組み込み

- 依存する作業: [R21](R21-unwinding-and-stop.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/R23-reference

## 目的

可変のセル（`Reference`）を言語から使えるようにする。`Reference.new`・`Reference.get`・`Reference.set` を `PRIM` で呼べるようにし、`Reference.update` を命令 `UPDATE` とセルの更新の枠で実行する。`UPDATE` は、関数を適用する間もほかのタスクを進められるように、セルの版の番号で書き込みを確かめ、変わっていればやり直す（ADR 0167）。

セルの対象（中身の値と版の番号を持ち、その場で書き換える）と、ヒープの関数（`alloc_cell`・`cell_get`・`cell_version`・`cell_set`）は、第 1 段（R02・R06）で作ってある。本作業は、それを VM と組み込みの関数から使う部分である。

## 本作業が書く組み込みの関数

10-12 は `Reference.new`・`Reference.get`・`Reference.set` の本体を本作業に割り当てる（10-11・10-12「作業の割り当て」）。受け入れテストがセルを作るために要るからである。

`Reference.update` の `raw` は `Stop::Internal` を返すまま残す（`UPDATE` だけで呼ばれる。10-12「項目の種類」）。

## 読む設計書の節

- [仮想機械](../../design/02-impl/02-08-vm.md)の「値の表現」の `Reference` の行、「枠の種類」のセルの更新の枠、「枠を降ろす原因と処理」、「組み込みの関数の呼び出し」の `State` を型に持つ関数の段落、「可変のセル」、「タスクの切り替え」の切り替えの位置の処理（`UPDATE` は関数を呼ぶ切り替えの位置である）と `PRIM` の途中で切り替えないこと
- [エフェクト](../../design/01-spec/01-07-effects.md)の「可変のセル（初回リリース版）」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の「タスクの切り替え」（セルの操作が一つのまとまりとして起きること）
- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md)の「ストア：可変のセルと明示遅延」（E-RefNew・E-RefGet・E-RefSet と `Reference.update` の遷移）
- ADR: [0167](../../design/decisions/0167-reference-update-by-version-retry.md)、[0267](../../design/decisions/0267-lazy-and-reference-objects.md) の決定 1・4、[0063](../../design/decisions/0063-ref-cells-with-io-effect.md)、[0239](../../design/decisions/0239-cycle-collection-for-reference-cells.md)（参照カウントを採った場合の生きているセルの表）

インターフェース:

- [仮想機械](../10-interfaces/10-09-vm.md)の「区画と枠」の `CellUpdate`、「枠を降ろす原因と処理」のセルの更新の枠の行、`unwind_cell_update`
- [バイトコード](../10-interfaces/10-07-bytecode.md)の「明示遅延、可変のセル、リソース」の `UPDATE`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「セルと `Host` の対象」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `state` の権限、`StateCtx`、`StateServices`
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の `reference` の部分

## 作るもの

- `src/builtins/funcs/reference.rs`: `Reference.new`・`Reference.get`・`Reference.set` の本体（R08 が置いた仮の本体を置き換える）と、その単体テスト。名前・権限・引数の数と、部分の中の位置は変えない（10-12「まだ書かない項目の仮の本体」）。
- `src/vm/unwind.rs`: `unwind_cell_update` の中身（すべての原因）。`src/vm/unwind.rs` の `todo!()` の仮置き（00-02）は、R20・R22・R23・R24 がそれぞれ受け持つ関数を書き換える。R22〜R24 は R21 の後に並行して進めるので、仮置きの許可とコメントは、四つのうち最後に `todo!()` を書き換えた作業（取り込みの時点でファイルに `todo!()` が残っていない作業）が消す。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する非公開の子のモジュール `src/vm/dispatch/cell.rs`: `UPDATE` の命令の処理とやり直し。`dispatch.rs` には `match` の分岐と、`Retry` を受け取ったときの呼び出しだけを加える。
- `src/vm/state.rs`: 第 1 段の VM が `state` の権限の組み込みの関数を呼ぶための、一時的な `StateServices` の実装（後述）。
- 上のファイルのテストと、`tests/` の下の統合テストのファイル。

## 手順の要点

### `state` の関数を呼ぶ口

`state` の権限の関数は、`CallCtx` に `StateServices` が渡されていなければ `Stop::Internal` を返す（10-11 の `CallCtx::state_ctx`）。第 1 段の `PRIM` は `StateServices` を渡していない。本作業は、`PRIM` が `state` の権限の関数を呼ぶときに `StateServices` を渡すようにし、その実装を一時的な形で置く。三つのメソッド（`task_poll`・`open_task_group`・`begin_release`）は、本作業の時点では呼ばれないので `Stop::Internal` を返す（`open_task_group` は `ResourceId` を返すので、呼ばれた時点で処理系の不具合として止まる形にできない。R25 が実装するまで、`TaskGroup.open` の仮の本体が先に `Stop::Internal` を返すので呼ばれない）。R25 が、タスクの表とリソースの表を持つ実装に置き換える。

### 三つの組み込みの関数（E-RefNew・E-RefGet・E-RefSet）

- `Reference.new(v)`: `StateCtx` の `NoGcCtx::alloc_cell(v)` で作ったセルを返す。
- `Reference.get(r)`: `cell_get(r)` の値を返す。セルでなければ `Stop::Internal`。
- `Reference.set(r, v)`: `cell_set(r, v)` で書き、`()` を返す。`cell_set` が版の番号を一つ増やす。

どれも待たず、送り出しの列も通さない（02-08「組み込みの関数の呼び出し」）。`PRIM` の途中でタスクを切り替えないので、ほかのタスクの操作と混ざらない。

### `UPDATE A B C`（02-08「可変のセル」）

1. セルの更新の枠一つと、関数 `R[C]` の呼び出しの枠と窓を `StackMeter::fits` で確かめる。
2. 切り替えの位置の処理を行う（関数の呼び出しは切り替えの位置である）。手順 1・2 と、回収・切り替えの後の再開は 10-09「呼び出しの前の安全点」に従う。
3. `cell_get(R[B])` と `cell_version(R[B])` を読む。
4. セルの更新の枠（`OtherKind::CellUpdate(CellUpdate { cell: R[B], version, func: R[C] })`、深さは実行中の区画の呼び出しの枠の数）を積み、関数 `R[C]` を読んだ値を引数として呼ぶ。呼び出しの枠の `ret` は `R[A]` の位置とする。

### `unwind_cell_update`（02-08「枠を降ろす原因と処理」のセルの更新の枠の行）

| 原因 | 処理 |
|---|---|
| `Return` | セルの今の版の番号を枠の `version` と比べる。等しければ、戻る値（実行中のタスクの `ReturnWork::value`。10-09「戻りの再開状態」）をセルに `cell_set` で書き（版の番号が一つ増える）、戻る値を `()` に替えて `Popped` を返す。`UPDATE` の結果は `()` だからである。等しくなければ `Retry` を返す |
| `Cancel`・`DropRel`・`Stop` | 書かずに `Popped` |

版の番号の確かめと書き込みの間にタスクを切り替えない（02-08「可変のセル」の最後の段落）。

### `Retry` を受けたとき

`RETURN` の包む枠の処理（R20）が `Retry` を受けたら、枠を残したまま、手順の 3 からやり直す。すなわち、セルの値と版の番号を読み直し、枠の `version` を新しい版に書き換え、関数をもう一度呼ぶ。関数の呼び直しも暗黙の呼び出しであり、切り替えの位置の処理を通す（ADR 0263 の決定 3）。呼び直しは 10-09「呼び出しの前の安全点」の順（上限、切り替えの位置の処理、成立）で行う。命令がないので、安全点を通った印には `ReturnWork::at`（戻りを始めた `RETURN`）を使う。回収か切り替えの後は `ReturnWork` の段から戻りの処理を続け、セルの更新の枠でもう一度 `Retry` になったら、印を見て切り替えの位置の処理を飛ばす（予算を二度数えない）。呼び出しを成立させるときに `ReturnWork` を `NoGcCtx::discard` で手放して消す（戻りの処理はここで終わり、新しい呼び出しの値は同じ `ret` に戻る）。枠の書き換えは、実行中の区画の `others` の最後の要素を書き換えるだけであり、ヒープの対象の書き換えではないので、書き込みの障壁は要らない。

関数は純粋（`function(T) -> T`）なので、やり直しても観測できる違いはない（ADR 0167）。

## 受け入れテスト

- 三つの組み込みの関数の単体テスト（10-12「確かめること」の項目ごとの単体テスト）: `new` の後の `get` が値を返す、`set` の後の `get` が新しい値を返す、`set` で版の番号が一つ増える（`cell_version` で確かめる）。
- `Reference.update` のプログラム: セルの値に関数を適用した値が書かれ、式の値が `()` である。関数が大きな値を作る場合（リストに要素を加えるなど）も同じである。
- 続けて呼ぶ `update`: 同じセルに `Reference.update` を 10 万回続けて呼ぶ末尾再帰のプログラムが、小さな `max_call_stack_bytes` でも止まらず、最後の値が正しい（セルの更新の枠を毎回降ろしている）。関数は純粋であり、ほかのセルを読み書きできない（型が `function(T) -> T` である）ので、関数の中からセルを使う形は確かめない。
- `unwind_cell_update` の単体テスト: 枠の `version` とセルの版が違うとき `Retry` を返し、セルを書かない。原因 `Cancel`・`DropRel`・`Stop` では、版が同じでも書かずに `Popped` を返す。
- 全体の停止: `update` の関数の中で 0 の除算を起こしたプログラムが止まり、セルの値が変わっていない。
- やり直しの経路（関数の実行の途中で別のタスクがセルに書く場合）は、タスクを使うので R25 の受け入れテストで確かめる。
- 根の置き場ごとの回収の強制（R03「根の列挙の引き渡し」の表の、本作業の行）: `HeapConfig::stress` を真にした設定で、セルと関数の値がセルの更新の枠（`CellUpdate` の `cell`・`func`）だけから辿れる状態（`UPDATE` の被演算子のレジスタを最後の使用として空にした後、関数の中で回収する）と、関数の返した値が `ReturnWork::value` だけに残る状態（枠の処理の直前に回収する）のそれぞれで回収し、セルの最後の値が正しいことを確かめる（二つの方式の両方で）。
- 循環: セルを持つ構成子の値を作り、そのセルに同じ値を入れて循環を作るプログラム（`data Node` の構成子の引数に `Reference[Option[Node]]` を持たせる形）を、作っては捨てる繰り返しが、回収の強制のビルドで正しく動いて終わる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-12 の `reference` の部分の三つの項目の名前・権限・引数の数と位置を変えていない
- 一時的な `StateServices` の実装を置いたことを、完了の報告の「判断したこと」に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」と「組み込みの関数」の行。
- セルの書き込みが `cell_set` だけで行われているか（書き込みの障壁の位置。10-08 の不変条件 H7）。
- `Retry` の後に、枠の `version` を新しい版に書き換えているか。書き換えずに呼び直すと、やり直しが止まらない。
- 原因 `Return` のほかで、セルに書いていないか。

## 難易度の理由

`UPDATE` の手順は短いが、戻る値を `()` に替えることと、やり直しで枠の版を書き換えることを落としやすい。やり直しの経路はタスクがないと起きないので、本作業では単体テストで押さえ、プログラムからの確かめを後の作業に残すことになる。
