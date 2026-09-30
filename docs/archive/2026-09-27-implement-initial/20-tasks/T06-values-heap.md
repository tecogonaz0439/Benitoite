# T06 実行時の値とヒープ

- 依存する作業: [T01](T01-interfaces.md)
- 難易度: 3（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T06-values-heap

## 目的

言語の値の表現（`Value` と、ヒープの対象を指す専用の参照の型）の操作と、ヒープの対象を作る唯一の入口 `Heap` を実装する。値の解放と構造の `==` を、Rust の再帰に頼らず明示の積み重ねで行い、長いリストや深い木の値でも処理系のスタックを使い果たさないようにする。VM・参照インタプリタ・組み込みの関数は、すべてこの作業の関数を通して値を作り、読む。

## 読む設計書の節

- [仮想機械](../../2026-09-27-design-initial/02-impl/02-08-vm.md)の「値の表現」「組み込みの関数の呼び出し」（構造の `==` と解放を明示の積み重ねで行う段落）
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「メモリの管理」「一つの操作で作る値の大きさの上限」
- [型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md)の「等値の型」（代数的データ型とリストの `==` の意味）
- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)の「Float」（IEEE 754 の比較）と「String」（`==` はスカラー値の列の比較）
- [標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md)の「List の内部の表現」
- [性能](../../2026-09-27-design-initial/07-quality/07-02-performance.md)の「測る項目」の「確保と解放」
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「止まる理由」「実行時の値」「ヒープ」
- [実装の規約](../00-common/00-02-conventions.md)の「大域の状態」「再帰の深さ」「言語の値を作る経路」

## 作るもの

- `src/runtime/value.rs`: 10-08 の `sig=src/runtime/value.rs` の関数すべて、`ListIter` の `Iterator` の実装、`Cell`・`CtorFields`・`FuncObj` の `Drop` の実装、`values_equal`。
- `src/runtime/heap.rs`: 10-08 の `sig=src/runtime/heap.rs` の関数すべてと、機能 `alloc-stats` のときだけ使える解放の計数（後述）。
- 上の二つのファイルの中のテスト（`#[cfg(test)] mod tests`）。

## 手順の要点

### 値を読む関数と作る関数

- `Value::as_*` は、選択肢が合わなければ `None` を返す。`as_ctor` は `(tag, fields)` を返し、引数のない構成子では空のスライスを返す。
- `StrRef::new`・`FuncRef::new`・`CtorRef::new`・`ListRef::cons`・`IoErrorRef::new` は `pub(super)` のままにする。`Heap` だけが呼ぶ（ADR 0078）。
- `CtorRef::new(tag, fields)` は、`fields` が空なら `fields: None` にし、確保しない。
- `ListRef::cons(head, tail)` は、`len = tail.len() + 1` のセルを作る。長さの上限は呼び出し側の `Heap::cons` が先に確かめるので、ここでは `saturating_add` で足してよい。
- `ListRef::same_cells` は、両方が空なら `true`、両方がセルを持てば `Rc::ptr_eq` の結果、一方だけなら `false` を返す。
- `ListIter` は、`cur` が指すリストの先頭の要素を返して `cur` を残りに進める。

### ヒープと統計

- `Heap` の各関数は、対象を一つ作るたびに `allocations` を 1 増やし、`bytes` に大きさを加える。大きさは 10-08 の `AllocStats::bytes` のコメントの規則で数える（文字列はバイト数、捕捉や引数の並びは要素の数に 32 を掛けた値、そのほかは 32）。数値の加算は `saturating_add` と `saturating_mul` で行う。
- `Heap::cons` は、`tail.len()` に 1 を加えた長さが `MAX_LIST_LEN` を超えるなら、値を作らずに `Stop::Resource(ResourceError::ValueTooLarge { function, size, unit: SizeUnit::Elements, limit: MAX_LIST_LEN })` を返す。
- `Heap::list_from_vec` は、`items.len()` が `MAX_LIST_LEN` を超えるなら同じ資源の不足を返す。超えなければ、末尾の要素から順にセルを作る（03-06「List の内部の表現」）。
- `Heap::string` は大きさの上限を確かめない（呼び出し側が値を作る前に確かめる。10-08）。

### 解放を明示の積み重ねで行う

`Rc` の既定の解放は、値が指す値を再帰的に解放する。長いリストや深い木では、Rust のスタックを使い果たす。そこで `Cell` と `CtorFields` に `Drop` を書き、子の値を一つの作業の列（`Vec<Value>`）に移してから、列が空になるまで次を繰り返す。

1. 列から値を一つ取り出す。
2. その値がリスト・構成子・関数の値で、指している `Rc` の参照の数が 1 なら（`Rc::try_unwrap` が成功すれば）、中身の子の値（セルの先頭と残り、構成子の引数、関数の値の捕捉）を作業の列に移す。移し終えた中身は子を持たないので、その `Drop` は再帰しない。
3. そうでなければ（ほかからも参照されていれば）、参照の数を 1 減らすだけで終わる。

`Cell` の `Drop` の中では、`self.head` と `self.tail` を `std::mem::replace` で `Value::Unit` と `ListRef::empty()` に置き換えてから作業の列に移す。`CtorFields` の `Drop` は `std::mem::take(&mut self.values)` で引数の並びを取り出す。`FuncObj` の `Drop` は、`Proto` の `captures` と `Ref` の `env` の値を同じく取り出す（関数の捕捉の入れ子でも再帰しないようにするため）。こうすると、リストのリスト、構成子の中のリスト、関数が捕捉した木など、種類の違う入れ子が深くなっても再帰しない。

### 構造の `==`

`values_equal(a, b)` は、比べる値の組の積み重ね（`Vec<(&Value, &Value)>`）を持って辿る。

- `Int`・`Bool`・`Char`・`Unit` は値で比べる。`Float` は IEEE 754 の `==`（Rust の `f64` の `==`）で比べる。NaN はどの値とも等しくない。
- `Str` は中身の文字列で比べる（スカラー値の列が等しい。正規化しない）。
- `Ctor` はタグが違えば `false`。同じなら、引数の組を積み重ねに加える。
- `List` は長さ（`len`）が違えば `false`。同じなら、要素の組を順に積み重ねに加える。長さを先に比べることで、長いリストを最後まで辿らずに済む場合がある。
- 二つの値の選択肢の種類が違う組、`Func`、`IoError` に出会ったら `Stop::Internal` を返す。等値の型の規則により、型検査を通ったプログラムでは起きない（ADR 0048）。
- 積み重ねが空になれば `true` を返す。途中で `false` が決まれば、そこで返す。

### 解放の回数の計数（新しく決めること）

機能 `alloc-stats` を有効にしたビルドでだけ、`Cell` と `CtorFields` と `FuncObj` の中身を手放した回数を `thread_local!` の `Cell<u64>` で数える（[実装の規約](../00-common/00-02-conventions.md)の「大域の状態」の例外）。公開の関数は次の一つだけとし、`#[cfg(feature = "alloc-stats")]` を付けて `heap.rs` に置く。

```rust
/// このスレッドで解放したヒープの対象の数。機能 alloc-stats のときだけある。
#[cfg(feature = "alloc-stats")]
pub fn freed_count() -> u64
```

既定のビルドでは、計数の処理も関数もコンパイルされない。

## 受け入れテスト

- 値を読む関数: `Heap::string("あい")` の `as_str` が `Some("あい")`、`as_int` が `None`。`Heap::ctor(1, vec![])` の `as_ctor` が `Some((1, &[]))` で、`stats().allocations` が増えない。
- リストの不変条件（03-06「List の内部の表現」）: `list_from_vec` で作った長さ 5 のリストの各セルの `len` が 5, 4, 3, 2, 1。`Heap::cons` で先頭に加えたリストの `tail` が元のリストと `same_cells` で `true`。`cons` の前後で元のリストの要素の並び（`iter` で得る）が変わらない。
- 長さの上限: 長さ `MAX_LIST_LEN` の要素数のリストに対する `cons` が、`ValueTooLarge { function: "List.prepend", size: 16777217, unit: Elements, limit: 16777216 }` を返す（リストを作るには時間がかかるので、上限の判定は `len` を持つセルを直接作るテスト用の補助で確かめてよい。補助はテストのモジュールの中に置き、`pub(super)` の `ListRef::cons` を使う）。
- 解放が再帰しない: テストの既定のスレッドで、要素が 1000 万のリスト、深さ 100 万の構成子の入れ子（`Node(Node(...))`）、深さ 100 万のリストのリスト、深さ 100 万の関数の捕捉の入れ子を作って捨てても、スタックを使い果たさない。
- 共有した値の解放: 共有しているリストの一方を捨てても、他方の要素がすべて読める。
- 構造の `==`: 同じ形の構成子の木は `true`、タグの違いと引数の違いは `false`。長さの違うリストは `false`。`Some(NaN) == Some(NaN)` に当たる比較が `false`。`0.0` と `-0.0` の成分は `true`。関数の値を含む比較は `Stop::Internal`。要素が 100 万の等しいリストどうしの比較がスタックを使い果たさない。
- 統計: `string` の `bytes` が文字列のバイト数だけ増える。`alloc-stats` の機能を有効にしたテスト（`#[cfg(feature = "alloc-stats")]`）で、100 要素のリストを捨てると `freed_count` が 100 増える。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- `Rc` の対象を作る箇所が `value.rs` と `heap.rs` の中だけにある

## 難易度の理由

値の操作の多くは定型だが、解放と構造の `==` を明示の積み重ねで書く部分に、Rust の所有権の扱い（`Rc::try_unwrap`、`mem::replace`、借用の寿命を持つ積み重ね）の注意が要る。誤ると、テストでは深い入れ子のときだけスタックを使い果たすので、見落としやすい。種類の違う入れ子（リストのリスト、関数の捕捉）まで一つの作業の列で扱う点が要になる。
