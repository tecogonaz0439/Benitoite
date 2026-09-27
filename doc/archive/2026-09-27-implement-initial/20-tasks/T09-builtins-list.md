# T09 組み込み関数: リスト

- 依存する作業: [T06](T06-values-heap.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T09-builtins-list

## 目的

`List` モジュールの組み込みの関数（`PureFn`）を実装する。リストは長さを持つ単方向の連結リスト（T06 の `ListRef`）であり、セルを変更しない。構造を共有してよい関数（`prepend`・`tail`・`drop`）はセルを写さず、ほかの関数は新しいセルを作る。03-06 の計算量と不変条件を守る。

## 読む設計書の節

- [標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md)の「List」（関数の表と計算量、`List.sort` の順序、`append` と `concat` の注意）「List の内部の表現」「作る値の大きさの上限」
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」
- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)の「Float」（比較と NaN）
- [組み込みの関数](../10-interfaces/10-10-builtins.md)の「prelude のモジュールの関数」のうち `List`
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「実行時の値」「ヒープ」

## 作るもの

- `src/builtins/list.rs`: 10-10 の一覧の `List` の関数の `PureFn` すべて（`length` から `drop_first` まで）。
- 同じファイルの中のテスト。

## 手順の要点

- `length`・`isEmpty`・`head`・`tail` は O(1)。`head` と `tail` は `Option` の値（`Some` はタグ 0、`None` はタグ 1）を返す。`tail` の結果は元のリストの 2 番目のセルをそのまま指す。
- `get(xs, i)`: `i < 0` か `i >= len` なら `None`。先頭から `i` 個辿る（O(i)）。
- `prepend(xs, x)`: `heap.cons(x, xs, "List.prepend")`。上限は `Heap::cons` が確かめる。
- `append(xs, x)`: 結果の長さ `len + 1` を先に確かめ（上限を超えれば `ValueTooLarge { function: "List.append", unit: Elements, .. }`）、`xs` の要素と `x` を並べた `Vec` から `heap.list_from_vec` で作る。
- `concat(xs, ys)`: 長さの和を先に確かめる（`List.concat`）。`xs` のセルを写し、`ys` を共有する。`xs` の要素を `Vec` に集め、末尾から順に `ys` の前に `Heap::cons` で加える。
- `reverse(xs)`: 先頭から順に空のリストの前に加える（長さは変わらないので、上限は超えない）。
- `take(xs, n)`: `n <= 0` なら空のリスト、`n >= len` なら `xs` そのもの（セルを写さない）、そのほかは先頭の `n` 個の新しいセル。
- `drop(xs, n)`: `n <= 0` なら `xs` そのもの、`n >= len` なら空のリスト、そのほかは `n` 個辿った先のセルをそのまま返す（写さない）。
- `range(start, end)`: `end <= start` なら空のリスト。長さ `end − start` は `i64` で溢れうるので `checked_sub` で求め、溢れるか `MAX_LIST_LEN` を超えれば値を作らずに資源の不足（`List.range`）。末尾から順に作る。
- `contains(xs, x)`: 先頭から `values_equal`（T06）で比べ、等しい要素があれば `true`。`Int` などの基本型の要素も `values_equal` で比べてよい。
- `sort(xs)`: 要素を `Vec` に集め、`sort_by`（安定な並べ替え）で並べてからリストを作る。比較の関数は、要素の種類ごとに次の全順序を返す。
  - `Int`・`Char`・`String` は、それぞれの `Ord` の順序（`String` はバイト列の順序）。
  - `Float` は、NaN をどの値よりも大きいものとし、NaN どうしは等しいものとする。NaN でない値どうしは `partial_cmp` の順序で、`0.0` と `-0.0` は等しい（`partial_cmp` が `Equal` を返す）。安定な並べ替えなので、NaN どうしと、`0.0` と `-0.0` は元の順序を保つ（03-06「List」の `List.sort` の方針）。
  - 要素の種類が混ざっているか、ほかの種類なら、並べ替えをやめて `Stop::Internal` を返す（比較の関数の外で先に種類を確かめる）。
- `dropFirst(xs)`: 空なら空のリスト、そうでなければ `tail` の中身（2 番目のセル）をそのまま返す。
- 引数の種類が違うときは `Stop::Internal` を返す。

## 受け入れテスト

- 不変条件（03-06「List の内部の表現」）: `append`・`concat`・`take`・`reverse`・`range`・`sort` の結果の各セルの長さが、残りの長さに 1 を加えた値である。どの関数も、呼ぶ前後で引数のリストの要素の並びが変わらない。
- 共有: `prepend(xs, x)` の `tail`、`drop(xs, 2)`、`dropFirst(xs)`、`take(xs, 10)`（長さ 3 の `xs`）、`drop(xs, 0)` が、元のリストのセルを `same_cells` で指す。`concat(xs, ys)` の、`xs` の長さだけ辿った先が `ys` と `same_cells`。
- 値: `get([10, 20], 1)` → `Some(20)`、`get([10, 20], 2)`・`get([10, 20], -1)` → `None`。`take([1, 2, 3], -1)` → `[]`、`drop([1, 2, 3], 5)` → `[]`。`range(3, 6)` → `[3, 4, 5]`、`range(5, 5)` → `[]`。`reverse([1, 2, 3])` → `[3, 2, 1]`。`contains([Some(1), None], None)` → `true`。
- 上限: `range(0, 16777217)` → `ValueTooLarge { function: "List.range", size: 16777217, unit: Elements, limit: 16777216 }`（値を作らない）、`range(i64::MIN, i64::MAX)` → 溢れを検出した資源の不足。
- `sort` の安定性と NaN: `[3.0, NaN(1 番目), 1.0, NaN(2 番目), -0.0, 0.0]` → `[-0.0, 0.0, 1.0, 3.0, NaN(1 番目), NaN(2 番目)]`（NaN の順序は、ビット列の違う二つの NaN で見分ける）。`["b", "a", "é"]` → `["a", "b", "é"]`。要素が 100 万のリストの `sort`・`reverse`・`concat` がスタックを使い果たさない。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 03-06 の表の計算量を超える処理（`length` で先頭から数えるなど）がない

## 難易度の理由

関数ごとの処理は単純で、どれも標準的なリストの操作である。注意する点は、構造を共有してよい関数と写す関数の区別、`n` の境界の扱い、`Float` の並べ替えの全順序の作り方に限られ、どれも 03-06 に明記されている。
