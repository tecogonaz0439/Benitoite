# L02 `Map`・`Set` の残りの関数と、`Trait` の実装

- 依存する作業: [L00](L00-u3-interfaces.md)、[R37](R37-map-and-set.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L02-map-and-set-functions

## 目的

`Map` と `Set` の組み込みの関数のうち、R37 が書いた六つ（`empty`・`fromList`・`toList`）を除く 14 の本体を、R37 の `runtime::map` の関数を使って書く。10-15 の部分 24（`map::MORE_DECLS`）と部分 25（`set::MORE_DECLS`）である。あわせて、L00 が置いたソースの関数（`Map.map`・`filter`・`fold`・`forEach`、`Set` の同じ四つ）と、`Benitoite.Trait` の `Map`・`Set` の `Show`・`Semigroup`・`Monoid` の実装を、スクリプトのテストで確かめる。

| 部分 | 項目 | 権限 |
|---|---|---|
| 24 | `Map.get`・`set`・`remove`・`contains`・`size`・`keys`・`values` | `Pure` |
| 25 | `Set.contains`・`add`・`remove`・`size`・`union`・`intersection`・`difference` | `Pure` |

## 読む設計書の節

- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「Map と Set（初回リリース版）」（関数の表と計算量、鍵の順序、元の鍵を保つ規則、確かめ方）、「関数を引数にとる関数の共通の規則」、「標準の型クラス（初回リリース版）」の `Show`・`Semigroup`・`Monoid` の方針
- [型システム](../../design/01-spec/01-06-type-system.md)の「鍵の型（初回リリース版）」
- ADR: [0103](../../design/decisions/0103-map-and-set-ordered-by-key.md)、[0171](../../design/decisions/0171-map-set-higher-order-functions.md)、[0211](../../design/decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)、[0134](../../design/decisions/0134-standard-type-classes.md)

インターフェース:

- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「マップと集合」（`map_get`・`map_insert`・`map_remove`・`map_len`・`map_to_vec`、`set_contains`・`set_insert`・`set_remove`・`set_len`・`set_union`・`set_intersection`・`set_difference`・`set_to_vec`）
- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「マップと集合」の表、「`Map` と `Set`」「標準の型クラスの `Map`・`Set` の実装」のソース
- R37 の作業の文書（操作の列のモデルとの比較のテスト）

## 作るもの

- `src/builtins/funcs/map.rs`・`set.rs` の `MORE_DECLS` の 14 項目の本体と単体テスト。新しい単体テストは `map.rs`・`set.rs` のテストのモジュールに置く（R37 の `src/runtime/map/tests.rs` は `runtime::map` のテストであり、本作業の組み込みの関数のテストを置かない）
- R37 が作った操作の列のモデルとの比較のテストを、本作業の関数（組み込みの関数の入口）を通す形に広げたもの
- ソースの関数と `Trait` の実装を確かめるスクリプトのテスト（ゴールデンテストの `stdlib` の区分に置くかは L40 と重ならないように、本作業は Rust の統合テストとして、既存の `tests/runtime_builtins.rs` に加える）。`Trait.Show` などを使うスクリプトには `import Benitoite.Trait` が要る

## 手順の要点

- どの関数も、引数のマップと集合を変えずに新しい値を返す。表現は `runtime::map` の関数だけで扱い、木のノードを直接読まない（10-08）。
- `Map.set` と `Set.add` は、同じ鍵が既にあれば元の鍵を保ち、`Map.set` は値だけを替える（03-06）。`runtime::map::map_insert`・`set_insert` がこの規則を満たすことを確かめ、満たさなければ作業を止めて報告する（R37 の関数の不具合であり、本作業では直さない）。
- `Map.remove`・`Set.remove` は、鍵がなければ元と等しい値を返す。
- `runtime::map` に `map_contains` はない。`Map.contains` は `map_get` の結果が値を持つかで書く。
- `Map.keys`・`Map.values` は `map_to_vec` の順（鍵の順）に並べたリストを `runtime::list::from_values` で作る。長さは要素の数であり、リストの長さの上限（2^24 要素）を超えたら資源の不足とする。
- `Set.union` の計算量は 03-06 の表のとおり O(m log(n/m + 1)) を目標にするが、`runtime::map` の関数の計算量に従う。本作業は計算量を変えない。
- ソースの関数（`Map.map` など）は L00 が置いた。本作業はソースを変えない。スクリプトのテストで、受け取った関数が鍵の順に一度ずつ呼ばれること（`Reference` で呼び出しの順を記録して確かめる）、`Map.map` が鍵を変えないこと、`Set.map` が同じ値を一つにまとめることを確かめる。ソースの誤りを見つけたら、作業を止めて報告する。

## 受け入れテスト

- 項目ごとの単体テスト: 空のマップと集合、要素が一つ、多数（1000 以上）の場合。鍵の型として `Integer`・`String`・`Decimal`（`1.0m` と `1.00m` が同じ鍵で、元の鍵を保つ）・構成子の値・`Pair` を使う。
- 集合の演算: 和・共通部分・差を、Rust の `BTreeSet` で求めた結果と比べる。
- 操作の列のモデルとの比較（ADR 0211）: 無作為に選んだ操作（`Map.set`・`Map.remove`・`Map.get`・`Map.contains`・`Map.size`、`Set.add`・`Set.remove`・`Set.contains`・和・共通部分・差）を、組み込みの関数の入口と `BTreeMap`・`BTreeSet` に同じ順に適用し、各操作の後に内容と鍵の順が一致する。種を固定した小さな生成器で作る（R37 と同じ）。
- 引数を変えない: 各関数を呼ぶ前後で、引数のマップと集合を `Map.toList` で読んだ並びが変わらない。
- ソースの関数と `Trait` の実装（スクリプト）: 上の手順の要点のとおり。`Trait.Show.show(Map.fromList([Pair(2, "b"), Pair(1, "a")]))` が `Map.fromList([Pair(1, "a"), Pair(2, "b")])`、`Set` も同じ形。`Trait.Semigroup.combine` の `Map` で同じ鍵は後の値になり、`Trait.Monoid.empty` が空のマップと集合を返す。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（`import Benitoite.Unofficial.Json` など。ADR 0286 の決定 3）で書く。03-08 などの設計書の例の `import Benitoite.Json` の形を写すと、E0321 になる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- `runtime::map` の関数の不具合を見つけたら、直さずに完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」と「永続コレクション」の行。
- 鍵の比較を、`runtime::map::compare_keys` を通さずに書いていないか。
- テストが、非公開の木の形ではなく、関数の結果（並び、大きさ、真偽）を確かめているか。

## 難易度の理由

関数そのものは R37 の関数を呼ぶだけだが、元の鍵を保つ規則、引数を変えないこと、モデルとの比較のテストを正しく組む必要がある。ソースの関数と型クラスの実装の確かめも含む。
