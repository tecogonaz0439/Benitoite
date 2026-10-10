# R37 `Map` と `Set` の重みで平衡させる二分木

- 依存する作業: [R08](R08-builtin-table.md)、[R09](R09-vm-core.md)、[C02](C02-remaining-interfaces.md)、[R35](R35-decimal-and-byte.md)、[F07](F07-typeck-records-constants.md)（鍵の順序の葉を比べる `base::prim::cmp_key_atom` を F07 が書く。F07 は取り込み済み）
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超。テストを含む）
- ブランチ: impl/R37-map-and-set

## 目的

`Map` と `Set` の値を、重みで平衡させる二分木（weight-balanced tree）の永続コレクションとして作る（[ADR 0103](../../2026-10-09-design-first-release/decisions/0103-map-and-set-ordered-by-key.md)、02-08「値の表現」）。`runtime::map` の関数（鍵の比較、作成、探索、挿入、削除、集合の演算、並べた取り出し）、構造の等しさ（`values_equal`）のマップと集合の比較、`LOADK` の `ConstDesc::Map`・`Set` を書く。組み込みの関数は、定数式に書ける `Map.empty`・`Map.fromList`・`Set.empty`・`Set.fromList` と、その値をテストで確かめる `Map.toList`・`Set.toList` の六つだけを書く（10-12）。残りの `Map`・`Set` の関数は U3 が、本作業の `runtime::map` の関数を使って書く。

本作業は、二つのメモリの管理に共通の API だけを使うので、第 1 段の測定を待たずに進めてよい（[ADR 0278](../../2026-10-09-design-first-release/decisions/0278-stage-1-completes-on-new-syntax-tests.md) の決定 3）。R14 の前に取り込むときは、両方のメモリの管理の機能でテストを通す。`Decimal` の鍵を比べるので、R35 の後に行う。

## 読む設計書の節

- [標準ライブラリ](../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「Map と Set（初回リリース版）」（関数の表と計算量、鍵の順序、同じ鍵を加えるときに元の鍵を保つこと、木の表現と確かめ方）
- [型システム](../../2026-10-09-design-first-release/01-spec/01-06-type-system.md)の「鍵の型（初回リリース版）」「等値の型」
- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」のマップと集合の箇条
- [構文](../../2026-10-09-design-first-release/01-spec/01-02-syntax.md)の「定数（初回リリース版）」、[バイトコードとコード生成](../../2026-10-09-design-first-release/02-impl/02-07-bytecode.md)の「定数表」
- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md)の「ほかの章が求めるテスト（初回リリース版）」の `Map` と `Set` の行
- ADR: [0103](../../2026-10-09-design-first-release/decisions/0103-map-and-set-ordered-by-key.md)、[0136](../../2026-10-09-design-first-release/decisions/0136-map-and-set-in-constants.md)、[0133](../../2026-10-09-design-first-release/decisions/0133-builtin-equality-and-key-constraints.md)、[0211](../../2026-10-09-design-first-release/decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)、[0278](../../2026-10-09-design-first-release/decisions/0278-stage-1-completes-on-new-syntax-tests.md)

インターフェース:

- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「マップと集合」（`runtime::map` の関数。平衡の条件の定数は本作業が決め、この節に書き足す）、「構造の等しさ」、`FieldsKind::MapNode`・`SetNode`（`tag` の使い方は本作業が決める）、`Value::EmptyMap`・`EmptySet`
- [バイトコード](../10-interfaces/10-07-bytecode.md)の「定数の記述」の `Map`・`Set`（記述の順は鍵の順で、並べ替えない）
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「リスト・マップ・集合」の `map`・`set` の部分、「確かめること」

## 作るもの

- `src/runtime/map.rs`: `runtime::map` の関数の中身。木の操作は、`map.rs` の中で宣言する非公開の子のモジュールに置いてよい。
- `src/runtime/equal.rs`: `values_equal` のマップと集合の比較（R35 が `Decimal` の分岐を加えている。本作業はマップと集合の分岐だけを加える）。欄の数が 4（マップ）か 3（集合）でないノードは `Stop::Internal` にする（壊れたノードを検出するため。既存のテスト `non_equality_values_and_incompatible_kinds_are_internal_errors` は欄 0 個のノードで `Stop::Internal` を求めており、この規則でそのまま通る）。
- `src/builtins/funcs/mod.rs` のテスト `placeholders_and_their_wrappers_fail_without_runtime_operations` から、本作業の項目の行（`map::empty`・`set::empty`）を消す。仮の本体でなくなるためである。このファイルのほかの部分は変えない。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する非公開の子のモジュール `src/vm/dispatch/collections.rs`: `LOADK` の `ConstDesc::Map`・`Set` の処理。`dispatch.rs` には分岐の行だけを加える。ただし `constant()` の子の取り出し（`children` の計算。今は借用の並び `&[ConstIdx]`）は、`Map` の組を鍵・値の順に平らに並べられる形（`Vec` など）に変えてよい。組への組み立て直しは `collections.rs` に置く。
- `src/builtins/funcs/map.rs`・`src/builtins/funcs/set.rs`: 六つの項目の本体（R08 の仮の本体を置き換える）と単体テスト。
- 平衡の条件の定数を 10-08「マップと集合」に書き足すことは、実装プランの文書の変更なので、本作業は完了の報告に定数を書き、オーケストレータが 10-08 に書き足す。
- 上のファイルのテスト。

## 手順の要点

### 木の形

- ノードは作った後に変更せず、更新は根から変わるノードまでの道筋だけを写す（03-06）。
- マップのノードは `FieldsKind::MapNode` の対象で、値の並びを（鍵、値、左の子、右の子）とし、`tag` にそのノードを根とする部分木の要素の数を入れる（02-08「値の表現」の「部分木の要素の数を持つ」。要素の数は `u32` に収まる。リストの長さの上限が 2^24 であり、`Map.fromList` などの引数はその中にある）。集合のノードは `FieldsKind::SetNode` で、並びを（要素、左の子、右の子）とする。空の子は `Value::EmptyMap`・`EmptySet` とする。この割り当ては本作業が決めて、`map.rs` の先頭の `//!` に書く。
- 平衡の条件は、Adams の重みで平衡させる木の条件を、パラメータ（Δ, Γ）= (3, 2) で使う。重みを「部分木の要素の数 + 1」として、どのノードでも `Δ × weight(左) ≥ weight(右)` と `Δ × weight(右) ≥ weight(左)` が成り立つ。崩れたら、`Γ` を使って一重の回転か二重の回転を選ぶ。整数のパラメータで挿入と削除の後に平衡を保てるのが (3, 2) であることは、Hirai と Yamamoto の Balancing weight-balanced trees（Journal of Functional Programming、2011 年）が示したとされる【要検証：一次資料で確かめる】。本作業は、この条件を `debug_assert!` で確かめ、単純なモデルとの比較のテストで操作の結果を確かめるので、文献の確かめがなくても誤りは見つかる。定数と文献の確かめの結果を完了の報告に書く。
- 集合の演算（`set_union`・`set_intersection`・`set_difference`）は、03-06 の計算量 O(m log(n/m + 1)) を満たすように、分割（split）と連結（join）に基づく分割統治で書く【要検証：この計算量が join に基づく方法で得られることは、Blelloch・Ferizovic・Sun の Just Join for Parallel Ordered Sets（SPAA 2016）が示したとされる】。

### 共通の規則

- どの関数も Rust の再帰を使わず、明示の積み重ね（`Vec`）で辿る（AGENTS.md「再帰の深さ」、10-08「マップと集合」）。挿入と削除は、根からの道筋を積み重ねに記録してから、下から写し直して平衡を直す。集合の演算の分割統治も、作業の積み重ねで書く。
- 鍵の順序（`compare_keys`）は、03-06「Map と Set」の鍵の順序の規則に従う。`Integer`・`Byte`・`Decimal` は数の大小（`Decimal` は小数の桁数によらない。R35 の `Decimal::cmp_num`）、`String` はスカラー値の列の辞書式、`Character` はスカラー値、`Boolean` は `false` が先、`Unit` は一つ。構成子の値は、構成子のタグ（型の宣言の順）で比べ、同じなら引数を前から辞書式に比べる。引数のない構成子（`Value::Tag`）と引数のある構成子（`Fields(Ctor, tag)` の対象）は、混ぜてタグで比べる（`None` と `Some(x)` など）。`List`・`Bytes` は辞書式で、短いほうが先。`Set` と `Map` は、要素（組）を鍵の順に並べたリストとして比べる。比べる処理も明示の積み重ねで辿る。鍵の型でない値に出会ったら `Stop::Internal`。基本型と `Bytes` の葉は、値を `base::prim::KeyAtom` に写して `base::prim::cmp_key_atom` で比べる（10-01「値の表現によらない基本型の計算」）。定数の評価器（F07）と同じ関数を使い、定数式の `Map`・`Set` と実行時の値で鍵の順序が食い違わないようにするためである。`cmp_key_atom` が `None`（型の違う葉）を返したら `Stop::Internal`。構成子・リスト・集合・マップは本作業がヒープの値の上で辿る。
- 同じ鍵を加えるときは、元の鍵を保つ（`map_insert` は値だけを替える。`set_insert` は元の要素を保つ）。`Decimal` の `1.0m` と `1.00m` は同じ鍵である。
- `map_from_sorted`・`set_from_sorted` は、鍵の順に並び同じ鍵を含まない並びから、平衡した木を下から作る（O(n)）。定数の記述（10-07）から作るときに使い、並べ替えない。
- 値を作る関数は、確保の前に大きさを確かめる必要がない（マップと集合には一つの操作で作る値の大きさの上限がない。02-09「一つの操作で作る値の大きさの上限」はリストと文字列と `Bytes` だけを対象にする）。`map_to_vec` などから作るリストは、`runtime::list::from_values` が上限を確かめる。
- 平衡の条件と、`tag` の要素の数が子の要素の数の和に 1 を足したものであることを、`debug_assert!` で確かめる（03-06、ADR 0211）。確かめは、ノードを作るときにそのノードの局所の条件（子の重みと `tag`）だけを見る（操作のたびに木の全体を辿ると、100 万の要素のテストがデバッグのビルドで終わらない）。

### 構造の等しさ

`values_equal` は、マップどうし（集合どうし）を、要素の数が同じで、鍵の順に並べた組（要素）が前から順に等しいときに等しいとする。木の形は比べない（同じ内容でも挿入の順で形が違いうる）。組の鍵は `compare_keys` で、値は `values_equal` で比べる。明示の積み重ねで二つの木を同時に中順で辿る。

### `LOADK` と組み込みの関数

- `LOADK` の `ConstDesc::Map(組の並び)`・`Set(要素の並び)`: 子の記述から作った値を使い、`map_from_sorted`・`set_from_sorted` で木を作る。記述の順（鍵の順）のまま作り、並べ替えない（10-07「定数の記述」）。定数の値の表に取っておく。
- `Map.empty()`・`Set.empty()`: 空の値。
- `Map.fromList(ps)`: 組を順に加える。同じ鍵があれば後の組の値を使い、鍵は最初に加えた鍵を保つ（03-06 の表と鍵の段落）。計算量は O(n log n)。
- `Set.fromList(xs)`: 要素を順に加える。同じ要素は最初のものを保つ。
- `Map.toList(m)`・`Set.toList(s)`: 鍵の順に並べたリスト（`Map.toList` は `Pair` の値のリスト。`Pair` の構成子のタグは 10-12「構成子のタグ」の定数）。

## 受け入れテスト

- 単純なモデルとの比較（07-03、ADR 0211 と同じ扱い）: 無作為に選んだ操作の列（挿入、削除、探索、`len`、`to_vec`、集合の和・共通部分・差）を、マップと Rust の `BTreeMap`（集合と `BTreeSet`）の両方に同じ順に適用し、各操作の後に内容と鍵の順序が一致することを確かめる。鍵は `Integer` を中心に、`String` と構成子の値も混ぜる。乱数はテストの中の小さな生成器で作り、種を固定する。デバッグのビルドなので、操作のたびに平衡の条件も確かめられる。
- 元の鍵を保つこと: `Decimal` の鍵 `1.0m` のマップに `1.00m` で挿入すると、値だけが替わり、`to_vec` の鍵の表示が `1.0m` のままである。
- 引数を変えないこと: 挿入と削除の前後で、元のマップの内容が変わらない。
- 鍵の順序: 03-06 の鍵の順序の各規則（構成子のタグの順、リストの辞書式と短いほうが先、集合とマップの比較、`Decimal` の数の比較）を単体テストで確かめる。
- 構造の等しさ: 同じ内容を違う順で挿入した二つのマップが `=` で等しい。値だけが違うマップは等しくない。
- 大きな木: 要素が 100 万のマップと集合を作り、探索と削除を繰り返しても処理系のスタックを使い果たさない。集合の演算で、小さい集合と大きい集合の和が、大きい集合を写し直さない（確保した対象の数が小さい集合の要素の数と log の積の程度に収まることを、`HeapStats::allocations` の差で確かめる）。
- 六つの組み込みの関数の単体テスト（10-12「確かめること」）。
- `LOADK`: `ConstDesc::Map`・`Set` から作った値の `to_vec` が記述の順と一致し、同じ定数を二度 `LOADK` して同じ対象が返る。
- R14 の前に取り込むときは、`gc-mark-sweep` と `gc-refcount` の両方の機能と回収の強制で、上のテストが通る。

## 完了条件

- `scripts/check.sh` が通る（R14 の前なら、両方のメモリの管理の機能と回収の強制で）
- 受け入れテストのすべての場合を確かめるテストがある
- 受け持つ関数に `todo!()` の仮置きが残っていない。ファイルに `todo!()` が残っていなければ、仮置きの許可とコメントを消している（00-02「`todo!()` の仮置き」。`runtime/heap/ctx.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が消す）
- `runtime::map` の関数のシグネチャと、10-12 の六つの項目の名前・権限・引数の数と位置を変えていない
- 平衡の条件の定数、`tag` と値の並びの割り当て、文献の確かめの結果を、完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「永続コレクション」の行。
- 鍵の順序が 03-06 の規則と一致しているか。`Float` の鍵を受け付けていないか（`Float` は鍵の型でない。01-06「鍵の型」）。
- 同じ鍵を加えるときに元の鍵を保っているか。
- 挿入・削除・集合の演算が、道筋の外のノードを写さずに共有しているか。Rust の再帰で木を辿っていないか。

## 難易度の理由

重みで平衡させる木の回転の条件、分割と連結に基づく集合の演算、鍵の順序の規則を、再帰を使わずに書く必要がある。誤りは特定の挿入の順でだけ平衡が崩れる形で現れるので、`debug_assert!` と単純なモデルとの比較で見つける。
