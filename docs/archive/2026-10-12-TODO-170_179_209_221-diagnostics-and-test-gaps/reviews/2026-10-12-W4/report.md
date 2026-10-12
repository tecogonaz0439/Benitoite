# W4（c1228c07）のレビュー

対象: `c1228c07`「Show operation type parameters, IO.All, and constant keys in diagnostics (W4)」。計画 `plan.md` の作業 W4、`decisions.md` の Q6・R8〜R12、事前点検の補足（W4W6-pf.md「W4 への補足」）、実装者の報告（W4-report.md）と照らした。ファイルは `git show c1228c07:<path>` で読み、ビルドとテストは走らせていない。

総評: 計画の 6 点はすべて実装されており、凍結した型（`TyNames`、`show_ty` の `Rigid` の枝）も変えていない。重大な所見はない。中の所見は 3 件ある。2 件は E0401 の剛な型の表示と脱出の注記の正しさ、1 件は E0209 の置き換えが「当てれば誤りが消える」という 02-10 の規則を満たさない文脈があることである。

## 重大

なし。

## 中

### M1. 外側の関数の型パラメータと操作の型パラメータが同じ名前のとき、表示で区別できない

- 場所: `crates/benitoite/src/typeck/solve.rs` の `name_rigid_types`（585 行付近）。`names.push(p.name.clone())` は、名前の表に同じ名前がすでにあるかを確かめない。
- 問題: `function run[T](a: T) -> Option[T]` の中で `case store(x) -> Option.Some(x)`（`store[T]`）の値が外へ出ると、外側の `T` は `Ty::Param(0)`、操作の `T` は `Ty::Param(1)` になるが、どちらも `T` と書かれる。結果は「expected `Option[T]`, found `Option[T]`」になり、Q6 が直そうとした「読めない表示」が残る。02-05 に加えた【決定】の理由「外側の関数の型パラメータと取り違えず」とも合わない。別の節（別の操作）の同名の型パラメータが一つの型に並ぶ場合（`Pair[T, T]` で二つが別の剛な型）も同じである。新しいゴールデン `secf1-outer-type-param` は外側を `A` にしているので、この場合を確かめていない。
- 直し方の案: 名前を足すとき、`names` に同じ文字列があれば区別できる形にする。例: 操作の名前で修飾した `store.T`、または `T'`・`T2` のように重ならない名前を作る。注記の `{param}` も同じ表示名を使うよう、`name_rigid_types` が作った名前を `failure` に渡す（今は `clause_params` から元の名前を引き直している）。ゴールデンかテストに、外側も `T` の場合を 1 件加える（`secf1-outer-type-param.bnt` を `run[T]` にするか、もう 1 件足す）。

### M2. `escaped` が `failure` を通らない経路で残り、後の別の E0401 に誤った注記が付く・本来の診断で注記が落ちる

- 場所: `crates/benitoite/src/typeck/solve.rs` の `restrict_clauses`（324 行）、`failure`（655 行の `take()`）。
- 問題: `escaped` は「失敗した単一化の直後に `failure` が呼ばれる」ことを前提にしているが、そうでない経路がある。
  1. `pair_failure`（1020 行付近）は、宣言の側の変数との E0401 を `self.late` に積み、`failure` をすぐには呼ばない。`call_return`（540 行）も同じく `late` に積む。`late` を報告するのは制約の解決の終わり（976 行）なので、その間にほかの失敗（残りの `Flow`、`solve_effects` の 1354 行の E0401 など）が起きると、そちらが `escaped` を取り出して誤った注記と節の補助の位置を付け、本来の脱出の診断からは注記が落ちる。
  2. `typeck/effects/special.rs` 175 行は `ctx.solver.equal(expected, error, r).is_err()` で試し、失敗を E0442 として自前で報告する。`failure` を通らないので、ここで剛な型の脱出が起きると `escaped` が残り、次の無関係な E0401 に付く。
  加えたテスト `type_escape_note_is_not_reused_for_other_failures` は、脱出の失敗がすぐ `failure` に届く場合だけを確かめている。
- 直し方の案: 脱出の情報を「次の失敗」という暗黙の順序に頼らず、失敗そのものに結び付ける。例: `late` の要素に `Option<(NodeId, u32)>` を足し、積むときに `self.escaped.take()` を入れ、`failure` には引数で渡す（`failure` は `pub` なので、非公開の補助の関数を挟む）。`special.rs` の試行の後、および `equal` の結果を捨てるほかの箇所では `escaped` を捨てる（`Solver` に `clear_escape` のような非公開の関数を置く）。少なくとも、`late` を経る SECF1 の場合と、E0442 の後に別の E0401 がある場合のどちらかをテストで固定する。

### M3. E0209 の置き換えを、型の並びでない文脈でも付けるため、当てても誤りが残る

- 場所: `crates/benitoite/src/syntax/parser/types.rs` の `parse_fn`（176 行、`parse_uses(p, depth, Some(start))`）と `parse_uses` の E0209 の枝（217〜249 行）。
- 問題: `parse_fn` はどの文脈から呼ばれても `Some(start)` を渡す。置き換え（関数の型の先頭に `(`、直前のエフェクトの後に `)`）が誤りを消すのは、関数の型が型の並び（関数の型の引数、型引数）の要素であるときだけである。次の文脈では、当てた後も構文の誤りが残る。
  - 宣言の引数の型: `function f(cb: function() -> Unit uses A, List[Integer]) -> Unit` は `f(cb: (function() -> Unit uses A), List[Integer])` になり、名前のない引数で誤りになる。
  - 宣言の戻り値の型: `function f() -> function() -> Unit uses A, List[Integer]` は `-> (function() -> Unit uses A), List[Integer]` になり、戻り値の型の後の `,` で誤りになる。
  - レコードのフィールドの型、束縛の型注釈なども同様。
  02-10「修正案」は「置き換えは、それを当てれば誤りがなくなると処理系が決められるときだけ付ける」と定め、02-03 に加えた文の理由（「誤りを解消できる形が分かる場合だけ編集を提示する」）とも合わない。単体テスト `uses_before_type_arguments_can_be_repaired_with_parentheses` は関数の型の引数の文脈だけを確かめている。
- 直し方の案: 型の並びの要素として型を読む呼び出し（`parse_fn` の引数の並び、型引数の並び）からだけ、関数の型の開始位置を `parse_uses` に届ける。例: `parse_type` に「型の並びの要素か」を示す引数か、それを受け取る別の入口を設ける（`parse_type` が凍結の対象かを先に確かめる）。それが重いなら、`fn_start` の直前の字句が `(` か `,` か `[` で、かつそれが型の並びを開いた字句であるときだけ置き換えを付ける。宣言の引数の型と戻り値の型の場合をテストに加え、置き換えがないことを確かめる。02-03 の文を「型の並びの要素の関数の型に限り」と直す。

## 軽微

### L1. `matching_bracket` がファイルの終わりまで探す

- 場所: `crates/benitoite/src/syntax/parser/types.rs` の `matching_bracket`（272 行）。
- 問題: 対応する `]` を `Eof` まで探すので、`[` を閉じ忘れたときに、後の宣言の `]` と偶然つり合えば、主な位置が複数の宣言にまたがり、置き換えも付く（当てても閉じ忘れは残る）。後のコードがつり合っていれば `None` になるので起きにくい。
- 直し方の案: `)`（深さ 0 で現れたもの）、改行で終わる文の区切り、`end` などで探索を止める。

### L2. 02-10 の修正案の表に E0209 の条件が反映されていない。コミットの文と実際の変更が食い違う

- 場所: `docs/design/02-impl/02-10-diagnostics.md` の修正案の表の「`uses` の並びにエフェクトでない名前を書いた | 関数の型を括弧で囲むこと | あり」の行。コミットの文は「Update 02-03, 02-05, 02-10」「02-03・02-05・02-10…を更新」と書くが、02-10 は変わっていない。
- 問題: 置き換えは条件付き（宣言・ラムダの `uses` と対応する `]` がない場合はなし。M3 を直せば型の並びの要素の場合だけ）になったが、表は無条件の「あり」のままである。
- 直し方の案: 表の置き換えの欄に条件（「型の並びの要素の関数の型で、対応する `]` があるとき」）を書く。コミットの文は保管の前の取り込みで直すか、次の作業のコミットで 02-10 を直すときに合わせる。

### L3. `typeck` が `runtime::assert`（テストの実行器の表記）に依存する

- 場所: `crates/benitoite/src/typeck/text.rs` 2 行（`use crate::runtime::assert::{quoted, text};`）、`crates/benitoite/src/runtime/assert.rs` 279 行の `pub(crate) mod text`。
- 問題: `typeck` から `runtime` への依存は `consts.rs` の上限の定数（`MAX_STRING_BYTES` など）で既にあるので、層の決まりへの違反ではない。ただし、型検査がテストの実行器の内部の表に依存するのは向きが不自然で、`runtime/assert.rs` を変えるたびに型検査の診断が変わる結び付きができる。実際、`assert.rs` の 1 行の変更で `check.sh` が `[long]`（約 15 分）を選んだ。
- 直し方の案: 今のままでも誤りではない。直すなら、`Show.show` の形の記号の表と `quoted` を、両者が使う中立のモジュール（`base` の下など）へ移す。後の改造の候補として docs/todo に載せるのでもよい。

### L4. `typeck/text.rs` に表記の処理（約 130 行）を置いた

- 場所: `crates/benitoite/src/typeck/text.rs` の `const_key`・`key_append`・`KeyWork`。
- 問題: `text.rs` の役割は先頭の `//!` で「型検査の診断に埋める固定の文言」とされ、AGENTS.md の文言の規約も `text` を定数の置き場とする。事前点検の補足は「写すなら `typeck/text.rs`」としたが、実装は記号の表を共有する方を選んだので、処理を `text` に置く理由がない。
- 直し方の案: `const_key` などを `consts.rs`（呼び手の `key_text` の隣）か新しい子のモジュール（例: `typeck/consts/key.rs`）へ移し、`text.rs` には `code_list` のような文言の組み立てだけを残す。

### L5. 剛な型の表示が `Solver::show` だけに入り、他の型の表示の経路では元のままである

- 場所: `crates/benitoite/src/typeck/effects/special.rs` 210〜225 行の `show`、`generate.rs` 288・951 行、`pattern_ext.rs` 395 行、`traits/collect.rs` 349 行。
- 問題: 例えば E0442（`special.rs` の `show`）の期待と実際に剛な型が入ると、`Option[T]` でなく元の `Rigid` の枝の表示になり、同じ型が診断ごとに違う形で示される。計画は `Solver::show` だけを範囲としているので、計画からの逸脱ではない。
- 直し方の案: `name_rigid_types` を `Body` の側の補助の関数にして、型検査の中の型の表示をすべてそこへ通す。今回直さないなら docs/todo に記録する。

### L6. 注記の操作の名前は書いた形（`store`）で、Q6 の例（`Swap.store`）と違う

- 場所: `crates/benitoite/src/typeck/effects/handle.rs` 107 行（`clause_ops` に `clause.op.path` をつないだ名前を入れる）。
- 問題: 事前点検の補足が「書いた名前（E0507・E0508 と同じ作り方）」と指定したので、補足には合っている。ただし、二つのエフェクトが同じ名前の操作を持つ場合、注記の `store` からはどのエフェクトの操作かが分からない。
- 直し方の案: 今のままでよい。M1 で操作の名前で修飾した型パラメータ名を使う場合は、宣言のエフェクトの名前で修飾した形（`Swap.store`）を使うかを合わせて決める。

## 確かめて問題のなかった点

- `IO.All` のまとめ: `show_ty` の `Ty::Fn` の枝だけにあり、10 個がそろうときだけまとめる。エフェクトの不足の診断（`solve.rs` 1365 行付近）は一つのエフェクトの集合を表示して `" uses "` の後を切り出すので、まとめの影響を受けない。E0405 の `allowed` の一覧、W0501（`effects/declarations.rs` 174 行。表示でなく集合で判定）とも矛盾しない。脱糖（`ir/desugar/decls.rs` 346 行）は実装の対象の型の名前に `show` を使うが、まとめは単射なので名前が衝突しない。処理系に LSP はない。
- 脱出の注記の条件: `code == DiagCode::E0401` かつ `escaped` があり、節の記録が引けるときだけ付く。`failure` の早く戻る経路の前で `take()` している（M2 の経路を除く）。
- 定数の鍵の表記: 記号は `runtime::assert::text` と共有し、レコード・`Pair` の修飾なし・構成子の修飾・`Set.fromList`・`Map.fromList` の形は `runtime/assert.rs` の `render_shape`（637〜660 行）と一致する。上限の扱い（末尾の `…` を含めて 4,096 バイト、文字の途中で切らない）も `render_value`（267〜273 行）と同じである。値は `Vec` の積み重ねで辿り、AGENTS.md「再帰の深さ」に合う。
- E0507: `ModuleKind::Prelude | ModuleKind::Stdlib` かつ型に `State` があるときだけ注記し、利用者の `uses State` の関数で注記が付かないテストがある。
- E0412: `pattern_path` を E0413 と共有し、ゴールデンが `Shape.Rect` に変わった。
- E0211: コメントだけで、コードは変えていない。
- 実装の規約: 本番のコードに `unwrap`・`expect`・添字はない（テストのモジュールの中の `unwrap` と `helps[0]` は許可の範囲）。文言は `codes.rs` の表に鍵で加えた。`name_rigid_types` の再帰は型の深さの上限で抑えられ、02-01 の決まりの範囲である。
- テスト: 新しいテストは公開の検査の入口（`check_files`、`user`）を通して振る舞いを確かめ、境界（4,096 バイトちょうど・超過・多バイト文字・長いリスト）と、外したら失敗する退行（記録の持ち越し）を含む。test-audit の原則に合う。不足は M1・M2・M3 に書いた場合である。
- 生成物: `skill/references/diagnostics.md` に E0209 のラベルと E0401 の 2 つの鍵が加わり、`codes.rs` の表と合う。CHANGELOG の記述は実装と合う（M3 を直したら E0209 の文の条件を合わせる）。
