# R34 型クラスの命令の VM の処理

- 依存する作業: [R09](R09-vm-core.md)、[C02](C02-remaining-interfaces.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R34-type-class-instructions

## 目的

型クラスの制約を辞書の受け渡しで実装する命令（`GETDICT`・`DICT`・`SUPER`・`METHOD`・`TAILMETHOD`）と、制約を持たない実装の辞書の定数（`LOADK` の `ConstDesc::Dict`）を、VM で実行できるようにする（[ADR 0158](../../design/decisions/0158-type-classes-by-dictionary-passing.md)、10-07「命令の表」）。第 1 段の VM は、これらの命令で `Stop::Internal` を返している。

本作業は、二つのメモリの管理に共通の API だけを使い、根の持ち方も確保の負荷も変えないので、第 1 段の測定（R12）を待たずに R09 の後に進めてよい（[ADR 0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md) の決定 3、README の「決めたこと」の 13）。R14 の前に取り込むときは、両方のメモリの管理の機能でテストを通す。

## 読む設計書の節

- [バイトコードとコード生成](../../design/02-impl/02-07-bytecode.md)の「コンパイル済みプログラム」（型クラスの表と実装の表）、「辞書とメソッドの呼び出し」、「定数表」、「末尾呼び出し」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「値の表現」の辞書の行、「枠の種類」の呼び出しの枠（メソッドの呼び出しでは辞書と原型を持つ）、「実行の手順」の `METHOD`・`TAILMETHOD`、「タスクの切り替え」の切り替えの位置の命令、「呼び出しの入れ子の上限」
- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md)の「型クラス」（E-Meth と辞書の値）
- ADR: [0158](../../design/decisions/0158-type-classes-by-dictionary-passing.md)、[0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md)、[0263](../../design/decisions/0263-dispatch-loop-locals-and-verifier.md) の決定 3（`TAILMETHOD` も切り替えの位置の確かめを通す）

インターフェース:

- [バイトコード](../10-interfaces/10-07-bytecode.md)の「命令の表」の「移動、関数、型クラス」、「オペランドの補足」（`METHOD`・`TAILMETHOD` の引数の並びはメソッド自身の制約の辞書を含む）、「コンパイル済みプログラム」（`TraitInfo`・`MethodInfo`・`ImplInfo`・`DictRecipe`、辞書の対象の `tag` は実装の番号）、「定数の記述」の `Dict`
- [仮想機械](../10-interfaces/10-09-vm.md)の「区画と枠」の `CallFrame::func`（メソッドの呼び出しでは辞書）、「振り分けのループの局所の状態」、「作業の割り当て」の R34 の行
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `FieldsKind::Dict`、`ValueCtx::alloc_fields`・`fields_header`・`field`

## 作るもの

- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する非公開の子のモジュール `src/vm/dispatch/traits.rs`: 五つの命令の処理と、`LOADK` の `ConstDesc::Dict` の処理。`dispatch.rs` には `match` の分岐と、定数を作る処理の `Dict` の分岐だけを加える。R35・R37 も同じ時期に `dispatch.rs` に分岐を加えるので、変える箇所を分岐の行に絞る。取り込みで衝突したら、後から取り込む側が直す（[作業の進め方](../00-common/00-03-workflow.md)の「ブランチと並行作業」）。
- `src/bytecode/disasm.rs`: 五つの命令の表示が F15 で入っていなければ加える（入っていれば触れない）。
- 上のファイルのテスト。

## 手順の要点

辞書の対象は `alloc_fields(FieldsKind::Dict, 実装の番号, 実装の制約の辞書の並び)` で作る。辞書の値を受け取る命令は、`fields_header` で種類が `Dict` であることを確かめ、違えば `Stop::Internal` とする。

- `DICT A B C`: 実装 B の `ImplInfo::dict_arity` の数だけ、`R[C]` から始まる並びを読み、辞書の対象を作って `R[A]` に入れる。確保をする命令なので、後に回収の要求の知らせ（`take_collect_signal`）を調べる（10-09 の命令の集合によらない手順の表）。
- `LOADK` の `ConstDesc::Dict(実装)`: 制約を持たない実装の辞書（並びが空）を作り、実行ごとの定数の値の表に `ConstIdx` を鍵として取っておく（10-07「定数の記述」）。二度目以降の `LOADK` は取っておいた値を使う。
- `GETDICT A B`: 実行中の呼び出しの枠の `func`（メソッドの呼び出しの枠では、呼び出しに使った辞書）の B 番目の値を `R[A]` に入れる。枠の `func` が辞書でなければ `Stop::Internal`。
- `SUPER A B C`: 辞書 `R[B]` の実装の `ImplInfo::supers[C]` の辞書の式（`DictRecipe`）を、`R[B]` の制約の辞書の並びを使って計算し、結果を `R[A]` に入れる。`Impl { imp, args }` は各引数の式を計算してから実装 `imp` の辞書を作る。`Param(i)` は `R[B]` の i 番目の値。`Super { of, index }` は `of` の辞書の実装の `supers[index]` を、その辞書の制約の辞書の並びで計算する。辞書の式の深さはプログラムの型クラスと実装の宣言で決まり、実行時の値によらない（02-07「辞書とメソッドの呼び出し」）ので、コンパイル済みプログラムの構造を辿る処理として再帰で書いてよい（[実装の規約](../00-common/00-02-conventions.md)の「再帰の深さ」）。途中で作った辞書は、次の確保の前に局所変数だけに残して区間を閉じることがないようにする（計算は一つの命令の中で終わり、途中で安全点に行かない）。
- `METHOD A B C`: 辞書 `R[B]` の実装の番号で `ImplInfo::methods[C]` の原型を決め、`CALL` と同じ手順で呼ぶ。引数は `R[B+1]` から、原型の `method_traits` が示す型クラスの `MethodInfo::arity` 個（メソッド自身の制約の辞書を含む。ADR 0310）。呼び出しの枠の `func` には、関数の値ではなく辞書 `R[B]` を入れる（10-09 の `CallFrame::func` の説明）。メソッドは自由な変数を捕捉しないので、`GETCAP` は現れない。切り替えの位置の処理と、呼び出しの入れ子の上限の確かめを `CALL` と同じく行う。
- `TAILMETHOD B C`: 同じく原型を決め、`TAILCALL` と同じ手順で現在の呼び出しの枠を置き換える。辞書と引数を先にすべて読んでから写す（引数のレジスタと窓の先頭は重なりうる）。枠の `func` を辞書に替える。切り替えの位置の処理を通す（ADR 0263 の決定 3）。

`CALL`・`TAILCALL` の処理（R09）と共通にできる部分は、非公開の補助の関数に分けて共有してよい。共有するときは、R09 のテストがそのまま通ることを確かめる。

## 受け入れテスト

テストは、`bytecode::asm` で命令列を組み立て、`CompiledProgram` の `traits`・`impls` を手で埋めて VM で実行する。F15 と F18 が取り込まれていれば、型クラスを使う小さなスクリプトをパイプラインでコンパイルして実行するテストも加えてよい（ゴールデンテストは C11・C12 が書く）。

- 制約を持たない実装: `LOADK` で作った辞書で `METHOD` を呼び、メソッドの結果が返る。同じ `LOADK` を二度実行して、同じ対象が返る（`same_object`）。
- 制約を持つ実装: `Show[List[T]]` に当たる実装（制約の辞書を一つ持つ）の辞書を `DICT` で作り、メソッドの本体が `GETDICT 0` で要素の型の辞書を読んで、そのメソッドを呼ぶ。
- 上位の型クラス: `SUPER` で、`Impl`・`Param`・`Super` の三つの形の辞書の式を計算する。入れ子の式（`Impl` の引数に `Super` を含むもの）。
- 末尾のメソッドの呼び出し: 自分自身を `TAILMETHOD` で呼ぶメソッドを 100 万回続けても、小さな `max_call_stack_bytes` で止まらない。窓の大きさの違うメソッドの間の `TAILMETHOD`。
- 上限: 末尾でない `METHOD` の再帰が `CallStackTooDeep` で止まる。
- 誤った値: 辞書でない値に `METHOD`・`GETDICT` を使うと `Stop::Internal`。
- 回収の強制: 回収の強制のビルドで、辞書を作りながら長く実行するテストが通る（定数の値の表と枠の `func` の辞書が根として辿られる）。
- R14 の前に取り込むときは、`gc-mark-sweep` と `gc-refcount` の両方の機能で、上のテストが通る。

## 完了条件

- `scripts/check.sh` が通る（R14 の前なら、両方のメモリの管理の機能と回収の強制で）
- 受け入れテストのすべての場合を確かめるテストがある
- 受け持つ関数に `todo!()` の仮置きが残っていない。ファイルに `todo!()` が残っていなければ、仮置きの許可とコメントを消している（00-02「`todo!()` の仮置き」。`runtime/heap/ctx.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が消す）
- 型クラスの命令が、`Stop::Internal` を返さずに実行される

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」の行。とくに、`METHOD`・`TAILMETHOD` の前後で局所の状態を書き戻し、読み直しているか。
- `METHOD`・`TAILMETHOD` の引数の数を、原型の `method_traits` が示す型クラスの `MethodInfo::arity` から読んでいるか（メソッド自身の制約の辞書を数えているか。ADR 0310）。
- 呼び出しの枠の `func` に辞書を入れ、`GETDICT` がそれを読んでいるか。
- 回収の方式に依存するコードを `runtime::heap` の外に書いていないか。

## 難易度の理由

命令は `CALL`・`TAILCALL` の変形であり、手順の多くを共有できる。`SUPER` の辞書の式の計算と、呼び出しの枠の `func` に辞書を持たせることに注意が要る。
