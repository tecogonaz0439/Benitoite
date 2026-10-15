### レビューの記録（高なし、中 2、低 5）

中
1. 型検査とコア検査で Known と Legacy の名前の扱いが食い違う（typeck/solve.rs の equal_contracts、ir/check.rs の accepts・legacy_equal）。型検査は旧位置呼び出しの Call・CallArg に限り Known と Legacy の名前の違いを許すが、コア検査は両方 Legacy か名前一致のときだけ受け入れる。名前付きの呼び出しを一つ含む関数（R55 で本体全体が新しい境界）の中で `bind add1 <- addTo(_, 1)`（Legacy(arg1)）を作り `List.map(xs, add1)`（期待は Known(value)）と位置指定で呼ぶと、型検査は通り、コア検査（desugar_files）と Lean の差分検査で落ちる見込み。本番は位置で実行するので振る舞いは変わらない。修正案: 再現テストを加え、コア検査の App の引数でも同じ条件で Legacy を許すか、型検査を厳密にするかを決めて揃える。
2. 旧注釈で書いた利用者の型クラス実装が E0711 になる（typeck/traits/impls.rs の check_methods の `params == found.params`）。構造上の Eq なので入れ子の関数型の名前と names_origin まで比べる。標準の Trait.Functor の `f: function(value: A) -> B` が Named に移ったので、利用者が `implement Trait.Functor[Box]` の中で `f: function(A) -> B uses E` と旧注釈で書くと新たに E0711。旧入力は N33 まで通すという R1 に反する。テストもない（traits/functor.bnt は独自の trait）。修正案: 入れ子の比較を、両方が Legacy なら名前を無視する比較（legacy_equal）にし、ゴールデンテストを加える。

低
3. Legacy の経路で名前付き呼び出しの対応が黙って入れ替わる: 旧本体で宣言の型を写すとき入れ子も Legacy にするので、`apply(f: function(x: Integer, y: Integer) -> Integer, ...)` に `sub(y, x)` を位置指定で渡しても通り、apply の中の `f(x: 1, y: 2)` が sub に y=1、x=2 を渡す。R11・R47 のとおりだが記録がない。修正案: この入力を N33 の削除の完了条件の回帰テストにする（plan.md の N33 に書き足し、記録に残す）。
4. 呼ぶ値の型が後回しの流れ込みで決まると E0455 を誤って出しうる（solve.rs の solve。calls::resolve を後回しの制約のループより前に行う）。例: `[factory(n: 1)]` の要素を match で取り出した cb に `cb(a: 1, b: 2)`。修正案: 直すか、既知の制限としてテストと記録を加える（N22 で扱われていれば確かめる）。
5. 厳密な引数を Span で識別している（solve.rs の strict_call_arguments、Vec<Span> に contains）。同じ Span の別の CallArg と衝突しうるうえ、二乗の時間。修正案: HashSet にするか NodeId で識別する。
6. E0455 の示す位置と案内: check_type_limits の E0455 は関数名の位置を指し原因の式を示さない。calls::generate はパイプや穴を含む名前付き呼び出しにも「注釈を加える」を案内する（今は構文解析で止まるが誤った案内）。修正案: 位置と案内を直す。
7. 生成する名前を処理の関数に直接書いている: `format!("arg{i}")` が本番のコードに約 10 箇所（decls.rs、handle.rs、generate.rs、effects/mod.rs、desugar.rs ほか）、"value"・"left"・"right" なども。修正案: 生成の補助と定数を一つにまとめる。

問題のなかった観点: 評価順（prepare で呼ぶ関数を先に、引数をソース順に pending へ、planned_arguments は並べ替えだけ、対応表の検査、named_order・named_escape・named_failure・named_tail のテスト）、混在（名前付きを一つでも含めば新経路で E0450）、型の表示（diag.json 3 件の変更は妥当）、実行時の費用（codegen・VM・runtime の変更なし、call_allocations に名前付きの末尾呼び出し）、テストの弱化なし、規約の違反なし。

## 対応

1. `typeck/solve.rs` の片側 Known の引数比較を厳密にし、位置指定の見逃しを `tests/named_arguments.rs` に追加した（R68）。元の複数位置指定の穴は N23 で新経路へ接続済みであり、List.map へ渡す再現入力が E0449 になることも既存の回帰表に追加して確認した。
2. `typeck/traits/impls.rs` と `ir/check.rs` で、旧実装の内側の出どころを引き継いで `legacy_equal` で比較し、`testdata/traits/functor.bnt` に標準 Trait.Functor[Box] の旧注釈の実装を追加し、N25 の定義・網羅性と実装の厳密な件数を追加分だけ増やした（R69・R70）。
3. `plan.md` の N33 に、旧本体の名前の入れ替わりと、移行後に E0454 を要求する対照付きの回帰条件を追記した。
4. N22 の反復解決で修正済みであり、factory の結果をリスト・match 経由で呼ぶ回帰テストを `tests/named_arguments.rs` に追加して型検査・脱糖・独立したコア検査の成功を確認した。
5. `typeck/solve.rs` の `strict_call_arguments` を `HashSet<Span>` にし、指摘の選択肢に従って線形探索の反復を除いた。
6. `typeck/context.rs` の最終検査で元の式の位置を使い、`typeck/calls.rs` と `diag/codes.rs` に穴・パイプ用の案内を追加した。`tests/named_arguments.rs` で案内と主位置を検査し、Skill の診断参照を再生成した。
7. `base/parameter_names.rs` に位置名の生成と固定名をまとめ、型検査・構文解析・組み込み表・外部関数の案内の生成から使うようにした。脱糖は N23 時点で型・対応表の名前を写しており、生成名の直書きは残っていない。


検証: `cargo test -p benitoite --lib` は 1,148 件成功（既存の ignore 21 件）。`named_arguments`・`golden`・`desugar_export`・`random_programs`・`reference_examples`・`skill_docs`・`skill_examples`・`spec_examples`、`cargo clippy --all-targets`、`cargo fmt --check` は成功した。`scripts/check-formal.sh` も成功し、Lean のビルドは sorry なし、脱糖・表層型検査・網羅性の不一致は 0 件、N25 の 1,724 入力の分類と件数は完全一致した。`scripts/check.sh` と gc-stress の構成は実行していない。

付随補正: 既存の `names/prelude_only_hidden.diag.json` の副位置を、変更していない標準 List.bnt の宣言の実位置 2336〜2343 バイトに合わせた（R71）。診断コード・文言・行・列と既存の assert は維持した。

テストの削除・assert の削除・ignore の追加はない。行数の差分は本番コードが追加 136・削除 78 行、テストが追加 109・削除 1 行（診断 JSON の一行の置換を含む）である。N33 では指摘3の負の回帰条件を実施し、R68・R69 の旧適合と出どころの引き継ぎを削除する。
