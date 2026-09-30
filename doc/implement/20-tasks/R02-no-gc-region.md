# R02 回収しない区間の型と根の保存領域

- 依存する作業: [R01](R01-allocator.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R02-no-gc-region

## 目的

回収しない区間（`Heap::epoch` の閉包の実行）を Rust の寿命で表す公開の層を作る（[ADR 0260](../../design/decisions/0260-heap-and-unsafe-boundary.md) の決定 3・4・5）。区間の中の値 `Value<'e>` は区間の外へ出せず、区間の外で値を保つのは `Slot` だけにする。回収は区間の外の `Heap::collect` だけが行い、区間の中の処理（`NoGcCtx`）は回収の機能を持たない。この境界が、VM と組み込みの関数が「回収の後に古い値を読む」誤りを型で防ぐ中心になる。

あわせて、二つのメモリの管理（マーク・スイープの R03 と参照カウントの R04）が同じ公開の層の裏で入れ替わるための、内部の層の境目を作る。R03 と R04 は、この境目の向こう側の別々のファイルに中身を書き、公開の層の関数には触れない。

## 読む設計書の節

- [ランタイム](../../design/02-impl/02-09-runtime.md)の「メモリの管理」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「値の表現」の最後の段落、「実行ごとの状態のうち VM が使うもの」の根の保存領域と回収の要求の行
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「ヒープとランタイムの確かめ方（初回リリース版）」
- [ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)（決定 5・7）、[ADR 0260](../../design/decisions/0260-heap-and-unsafe-boundary.md)、[ADR 0267](../../design/decisions/0267-lazy-and-reference-objects.md)（決定 1）、[ADR 0277](../../design/decisions/0277-refcount-defers-freeing-to-safepoints.md)、[ADR 0281](../../design/decisions/0281-heap-number-in-slot-and-contract-safety.md)
- インターフェース: [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「不変条件」（「安全と言える範囲」を含む）「根の保存領域」「根と対象を辿る」「ヒープと区間」「区間と回収」「セルと `Host` の対象」「確かめ方の口」「コンパイルの失敗のテスト」
- 共通の決まり: [実装の規約](../00-common/00-02-conventions.md)の「`unsafe` の書き方」「回収しない区間と値の扱い」「テストの規約」
- 経緯: [相談の第 1 回](../studies/u2-runtime/consult/01-memory-and-values.md)の「要点」の 5（`&Heap` に借用を結び付けるだけでは、回収の前に写した値を回収の後に読む誤りを防げない理由）、[検討資料 03-options](../studies/u2-runtime/03-options.md)の「Q3」の暫定の推奨

## 作るもの

- `src/runtime/heap/ctx.rs`: 次の関数の中身。
  - `Heap::new`・`config`・`epoch`・`collect_requested`・`collect`・`stats`・`verify`・`take_fault`・`object_ids`
  - `NoGcCtx::load`・`new_slot`・`store`・`clear`・`move_slot`・`take`・`discard`・`take_collect_signal`・`collect_requested`
  - `NoGcCtx::alloc_cell`・`cell_get`・`cell_version`・`cell_set`・`alloc_host`・`host`・`host_mut`
  - `SlotOps` の七つの関数
- `src/runtime/heap/slot.rs`: `RootStack` の六つの関数。
- `src/runtime/heap/trace.rs`: `Tracer::new`・`slot`・`slots`、`Discarder::new`・`slot`。
- `src/runtime/heap/core/` の下の方式の境目（後述）と、二つの方式の仮の中身のファイル（例: `core/mark_sweep.rs`・`core/refcount.rs`）。
- `Heap::epoch` の `///` のコメントに、10-08「コンパイルの失敗のテスト」の例をすべて置く（`compile_fail` と `no_run` の対）。
- 上のファイルの中のテスト。

C01 は `sig=` の宣言を `todo!()` の仮置きとして置いている。本作業は受け持つ関数の本体を書き換え、ファイルに `todo!()` が残らなければ仮置きの許可とコメントを消す（00-02「`todo!()` の仮置き」）。`runtime/heap/ctx.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が許可を消す。

10-08「作業の割り当て」は、`Heap::collect`・`collect_requested`・`take_collect_signal` を R03（マーク・スイープ）と R04（参照カウント）に割り当てている。本作業は、これらの公開の層の関数を、方式の境目を呼ぶだけの形で書き、方式ごとの中身を R03・R04 が境目の向こうのファイルに書く。こうすると、並行する R03 と R04 が同じ関数を書き換えずに済む。`Heap::verify` は、R03・R04 が回収の前後に呼ぶので、本作業が最初の形（後述）を書き、R11 が検査を足す。

## 手順の要点

### 区間

- `Heap::epoch` は、`&mut self` を借りたまま、`HeapCore` と新しい `Epoch<'e>` から `NoGcCtx<'e>` を作り、閉包に渡す。閉包の型 `for<'e> FnOnce(&mut NoGcCtx<'e>) -> R` により、`R` は `'e` を含められない（不変条件 H3）。`Epoch<'e>` は `'e` について不変（invariant）なので、別の区間の値を取り違えて渡すとコンパイルの誤りになる（H9）。この二つが寿命の印の要であり、`Epoch` を共変にする変更（`PhantomData<&'e ()>` にするなど）や、`'static` の値を区間に入れる抜け道を作らない。
- `NoGcCtx` は回収の関数を持たない（H2）。`Heap::collect` は `&mut Heap` を取るので、区間の中からは呼べない。
- 区間の中の確保は `&HeapCore` から行う（R01 の内部の可変性）。区間の中では対象を解放も移動もしない（H1）。

### `Slot` の操作と方式の境目

`Slot` を作る・写す・消す操作は、`NoGcCtx`（と `SlotOps`）の関数だけに集める（10-08「根の保存領域」）。各関数は、方式の境目の関数を呼んで、方式ごとの処理（参照カウントの数の増減など）を行う。

方式の境目は内部の層に置き、少なくとも次の出来事を方式に知らせる形にする。名前と形は本作業が決め、ファイルの先頭の `//!` に一覧を書く。

| 出来事 | 例 |
|---|---|
| `Slot` が対象を指し始めた | `new_slot`、`store` の新しい値、`reuse_ctor` が書く引数 |
| `Slot` が対象を指さなくなった | `store` の前の値、`clear`、`take`、`Discarder::slot` |
| 対象を確保した（対象と量） | 回収の要求の判定に使う。参照カウントでは、確保した対象を解放の候補に加える（R04。10-08「区間と回収」）ので、対象を識別できる形で知らせる |
| セルを確保した | ADR 0239 の生きているセルの表（R04） |
| 回収 | `Heap::collect(roots)` |
| 回収の要求の問い合わせ | `collect_requested`、`take_collect_signal` |
| 一意な対象の確かめと書き換え | `reuse_ctor`（R04） |

`move_slot` は、移した値について「指し始めた」「指さなくなった」の両方を省く（数を変えない。最後の使用での移動）。`dst` の前の値は「指さなくなった」として知らせる。

二つの方式の中身は、`#[cfg(feature = "gc-mark-sweep")]` と `#[cfg(feature = "gc-refcount")]` の下の別のファイルに置く（10-08「ヒープのモジュールの構成」）。本作業は、両方に、正しいが回収しない仮の中身を書く。

- 仮の中身の `collect` は、どの対象も解放せず、回収の要求を下ろし、`collections` と `roots_traced` を更新する。`collect_requested` は `HeapConfig::stress` のときだけ真を返す。
- 解放しないので未定義動作は起きない。R03・R04 がそれぞれの中身に置き換えるまで、両方の機能でビルドとテストが通る状態を保つ。

### ヒープの番号と世代の確かめ

`Slot` の中身の形（`SlotRaw`）と、ヒープの番号の読み書き（`Slot::raw`・`set_raw`）は、10-08 の `file=` のコードのとおりである。`Slot` を読む・書き換える・辿るすべての関数（`NoGcCtx` と `SlotOps` の `load`・`new_slot`・`store`・`clear`・`move_slot`・`take`、`Tracer::slot`・`slots`、`Discarder::slot`、`RootStack` の関数）は、`Slot` が対象を指すとき、そのヒープの番号と `HeapCore` の番号を比べる。比較はすべての構成で行い、一回の整数の比較にとどめる（ADR 0281）。食い違えば、対象を読まず、数も変えずに `HeapFault`（`ForeignHeap`）を記録する。`load` と `take` は `Value::Unit` を返し、`store`・`clear`・`move_slot`・`take` は `Slot` を上書きしてよい（前の値の数は変えない）。`Tracer` はその `Slot` を辿らない。記録は `Heap::take_fault` で取り出す。`Slot` に対象を書くときは、`HeapCore` の番号を書く。

機能 `heap-verify` の構成では、`load` と `SlotOps::load` は、さらに `Slot` の値が指す対象の世代（R01）を確かめる。食い違えば `StaleReference` を記録し、`Value::Unit` を返す。対象ごとの確保の構成では、世代を内部の表で確かめ、解放した領域を読まない（R01）。

### `Tracer` と `RootStack`

- `Tracer` は `&mut dyn TraceSink` を持ち、`slot`・`slots` で `Slot` を `TraceSink::visit` に知らせるだけにする。辿った先の対象を辿るのは内部の層（明示の積み重ね）であり、`Tracer` は再帰しない（00-02「再帰の深さ」）。
- `Discarder` は `&HeapCore` を持ち、`slot` で受け取った `Slot` が対象を指していれば、方式の境目に「指さなくなった」を知らせてから `Slot` を捨てる。`NoGcCtx::discard` と `SlotOps::discard` だけが `Discarder` を作る。
- `RootStack` は 10-08 のシグネチャのとおりに書く。`push` は `NoGcCtx::new_slot` で `Slot` を作って積み、`truncate` は除く `Slot` を `NoGcCtx::clear` で空にしてから縮める。長さは `u32` で返し、`u32` に収まらないときの扱い（積まずに処理系の不具合とするなど）を決めて `///` に書く。

### セルと `Host` の対象

- セル（`Reference` のセル。ADR 0267 の決定 1）は、中身の `Slot` と版の番号を持つ。`alloc_cell` は版の番号 0 で作り、方式の境目に「セルを確保した」を知らせる（参照カウントの表への登録は R04 が方式の側に書く）。`cell_set` は中身を書き換え、版の番号を一つ増やす。書き込みの障壁の位置であり（H7、ADR 0259 の決定 7）、書き換えはこの関数の中の一か所で行う。セルでない値には `Stop::Internal` を返す。
- `alloc_host` は `HostData` の値を対象に入れる。`host` は型が合えば共有の参照を返す。`host_mut` は、`&mut self` を取り、対象の Rust の値を `&mut T` で閉包に渡す。閉包には `SlotOps` だけを渡し、ほかの対象を読めないようにする（書き換え中の対象との別名を防ぐ。10-08「セルと `Host` の対象」）。`host_mut` も書き込みの障壁の位置である。
- `discard(x)` は、`Discarder` を作って `x.discard(&mut d)` を呼ぶ（`Discard`。10-08 の不変条件 H11）。`Trace` で辿って数を減らす形にしない。`Trace` は借用した `Slot` の見え方にも実装できるので、それを捨てると、元の `Slot` が残ったまま数が減るからである。`Slot` を Rust の `drop` で捨てると参照カウントの数が戻らない（未定義動作ではない。10-08「根の保存領域」）ので、VM が枠や区画を捨てるときはこの関数を使う。

### ヒープの検証器の最初の形

`Heap::verify(roots)` は、機能 `heap-verify` を無効にした構成では何もせず `Ok(())` を返す。有効にした構成では、本作業の時点で確かめられる次のことを確かめる。

- 列挙したすべての対象の頭が壊れていない（種類と長さが取りうる値の範囲にある）。
- 生きている対象の中の値と、`roots` が辿る `Slot` が指す先が、生きている対象である（世代が合い、`Slot` のヒープの番号が合う）。

参照カウントの数の食い違い（`CountMismatch`）と、根から辿れる対象の解放（`ReachableFreed`）の検査は R11 が足す。

### 測定の記録と識別

- `Heap::stats` は `HeapStats` の写しを返す。`peak_heap_bytes` は確保している量の最大である。
- `Heap::object_ids` は、R01 の列挙で生きている対象の `ObjId` をすべて返す（到達可能性を比べるテストが使う。R11）。

## 受け入れテスト

- 区間と `Slot`: 区間の中で文字列を確保して `Slot` に書き、区間を閉じて開き直してから読むと、同じ中身が読める（R06 の前なので、文字列は内部の層の確保の関数か、R01 のテスト用の補助で作ってよい）。
- `store`・`clear`・`move_slot`・`take`: 各操作の後の `Slot` の中身（`is_immediate` と読んだ値）が 10-08 のコメントのとおりになる。`move_slot` の後の `src` は空である。
- `RootStack`: 積んだ位置で読めること、`truncate` で除いた位置が `None` になること、長さが一致すること。
- セル: `alloc_cell` の版の番号が 0、`cell_set` のたびに一つ増え、`cell_get` が最後に書いた値を返す。セルでない値に `cell_set` を使うと `Stop::Internal`、`cell_get`・`cell_version` は `None`。
- `Host` の対象: `host` と `host_mut` が型の合う値にだけ `Some` を返す。`host_mut` の閉包の中で `SlotOps` で書いた `Slot` が、閉包の後に読める。
- `discard`: `Slot` を持つ Rust の値（`Vec<Slot>`、`Option<Slot>`、テストで `Discard` を実装した構造体）を `discard` すると、方式の境目に「指さなくなった」がその数だけ知らされる（方式の境目を数えるテスト用の仕組みで確かめる。仕組みはテストのモジュールの中に置く）。
- ヒープの番号（すべての構成。機能で限らない）: ヒープ `a` の対象を指す `Slot` を、ヒープ `b` の区間で `load`・`store`・`clear`・`take`・`discard` し、`b` の `collect` の根に入れると、どれも `a` の対象を読まず数も変えず、`b.take_fault()` が `ForeignHeap` を返す（`load` と `take` は `Value::Unit`）。`a` の数と `object_ids` は変わらない。
- 世代の確かめ（`heap-verify`）: 内部の層で解放した対象を指す `Slot` を `load` すると、`Value::Unit` が返り、`take_fault` が `StaleReference` を返す。`#[cfg(feature = "heap-verify")]` で限る。
- 検証器の最初の形（`heap-verify`）: 正しいヒープで `Ok(())`、頭を壊した対象（内部の層のテスト用の補助で壊す）で `CorruptHeader` を返す。
- コンパイルの失敗: 10-08「コンパイルの失敗のテスト」の九つの `compile_fail` の例がコンパイルに失敗し、対にした `no_run` の例がコンパイルできる（`cargo test --doc` で走る）。
- 回収の共通の契約（恒久のテスト。公開の層のテストのモジュールに置く）: 両方の機能で、根（`RootStack`）から辿れる対象が `collect` の後も残って同じ中身を読め、`collections` がちょうど一つ増える。`HeapConfig::stress` が真なら `collect_requested` が真である。R03・R04 が方式の中身を置き換えた後も、このテストは変えずに通る。
- 仮の方式（仮の中身のテスト）: 両方の機能で、根から辿れない対象も `collect` の後に残る。このテストは仮の中身のファイル（`core/mark_sweep.rs`・`core/refcount.rs` など）のテストのモジュールに置き、R03・R04 が中身を置き換えるときに消す（仮の中身でだけ成り立つため）。

## 完了条件

- `scripts/check.sh` と `scripts/check-heap.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 公開の層のファイル（`ctx.rs`・`slot.rs`・`trace.rs`）に `unsafe` がない
- 10-08 の九つの `compile_fail` の例と、対にした `no_run` の例が `Heap::epoch` の `///` にある
- 方式の境目の出来事の一覧が、内部の層のファイルの先頭の `//!` にある

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「ヒープの内部の層」「回収しない区間（R02）」に加えて、次の点を読む。

- `Value<'e>` を区間より長く持てる抜け道がないか。とくに、`Epoch` の変性を変えていないか、`'static` の値を区間の中の値として返す関数（`Slot::raw` の結果をそのまま公開するなど）を作っていないか、`NoGcCtx` から `&HeapCore` を取り出して区間の外へ持ち出せないか。
- `Slot` の操作のすべてが方式の境目を通っているか。境目を通らずに `Slot::set_raw` を呼ぶ箇所がないか（参照カウントの数が崩れる）。
- `Slot` を読む・書き換える・辿るすべての経路で、ヒープの番号を比べているか。比較が `heap-verify` の構成だけに入っていないか。
- `discard` が `Trace` を使っていないか。
- `host_mut` の閉包から、ほかの対象を読み書きできる経路がないか。
- 仮の方式の中身が、R03・R04 の中身と別のファイルにあり、R03・R04 が公開の層を変えずに置き換えられるか。

## 難易度の理由

寿命の印（不変な `'e` と `for<'e>` の閉包）の設計は一度崩すと型の保証がすべて失われ、しかも崩れても通常のテストは通る。コンパイルの失敗のテストだけがその崩れを見つける。加えて、二つの方式が同じ公開の層の裏で入れ替わる境目を、後の二つの作業が並行して書ける形で先に決める必要がある。
