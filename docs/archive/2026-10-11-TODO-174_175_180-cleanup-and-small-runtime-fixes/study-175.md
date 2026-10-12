# TODO-175 の調査

調べたのは san_benito の HEAD（8ca4d47）である。ファイルは書き換えず、ビルドとテストも走らせていない。行番号は HEAD のもの。

## 0. 前提の確認（判定の木の直前の変更）

直前の改造（TODO-195）が `decision.rs` に入れたのは、行列のセルの数の予算だけである（`decision.rs:14` の `MAX_TREE_WORK = 600_000`、`:16` の `MAX_DEF_TREE_WORK`、`Lowerer::tree` の冒頭 `:542`〜`:567`。コミット e315087）。ワイルドカードの列をまとめて除く処理とメモは、網羅性の判定（`typeck/patterns.rs`）の側の変更であり、判定の木にはない（オーケストレータの依頼文の誤りを、この節で正した）。

## 1. 所見がまだ成り立つか

### 1.1 判定の木と脱糖（later-issues の 20）

所見はすべて成り立つ。

| 項目の記述 | HEAD での位置と状態 |
|---|---|
| `Lowerer::comp`（`decision.rs:198`） | `decision.rs:227`〜`304`。一つの大きな `match` のままで、`LCompKind` の各分岐を同じ枠の中で組み立てている。Let・If・Use・Lazy・Handle の分岐は、本体を同じ関数の中で `self.comp` へ再帰する。Handle の分岐は節の `Vec` を組み立てるループも持つ |
| `match_comp` | `decision.rs:306`〜`443`。行列の作成、`tree`、`count`、本体の写し（`self.comp`）、`emit`、join の組み立てが一つの枠にある |
| `emit` | `decision.rs:1155`〜`1248`。Ctor・Constant・Length・Gets の四つの分岐を、`Vec` とループを含めて同じ枠の中に書いている |
| `leaf` | `decision.rs:1258`〜`1351`。ガードの分岐で `self.comp(guard)` と `self.emit(fallback)` へ再帰する |
| `tree`（項目には挙がっていない） | `decision.rs:542`〜`659`。再帰の経路にあるのに、上限超過の診断（`DiagBuilder`、`:561`）を同じ枠で組み立てている。ガード付きの分岐では fallback の木へ `self.tree` を直接再帰する（`:599`） |
| 脱糖の `if_expr` | `ir/desugar/exprs.rs:540`〜`561`。`else if` を `self.if_expr` で再帰し、`branching`・`finish`・`result_ty` の一時的な `Comp` を同じ枠に持つ |
| `ir/decision.rs` と `ir/desugar/` の `#[inline(never)]` | 0 個（`git grep 'inline(never)'` で確かめた） |
| 「`decision.rs:3143` は 64 段」 | 今は `decision.rs:3191` の `nested_patterns_and_long_lists_preserve_bindings_without_changing_stack_size`。構成子の入れ子 64 段と、1024 要素のリストのパターン |

重要な追加の所見は次のとおり。最も重い `comp` を深く積むのは、深い式の入れ子よりも Let の連なりである。02-03「入れ子の深さ」が定めるとおり、ブロックの文、リストの要素、呼び出しの引数、レコードのフィールド、補間の式は、脱糖の `finish`（`ir/desugar.rs:134`。これ自体はループ）でコア IR の Let の連なりになる。`comp` は Let の body へ毎回自分を再帰する（`:231`〜`235`）。このため、997 個の文や 997 要素のリストで、`comp` の枠がそのまま 997 段積まれる。later-issues の 20 にある「平らな文 997 で約 19 MiB」は、この経路の値である。コード生成の `let_`（`bytecode/codegen/emit.rs:123`）も body へ `self.comp` を再帰するので、1 文あたり 2 枠を積む。

### 1.2 構文解析（later-issues の F03・121）

所見は成り立つ。

- `parse_leaf` は `syntax/parser/exprs.rs:314`。分けた補助の関数の行は、項目の記述と同じだった。`parse_literal_or_error` が `:325`、`parse_foreign_lambda` が `:345`、`finish_name` が `:364`。`syntax/` の下に `inline(never)` は 0 個である。
- 構文解析器は、大きいノードを `finish_*` で組み立てる方針で書かれている（`exprs.rs:2` のコメント）。`finish_*` は parser の下に 28 個ある（exprs 12、effects 5、records 4、types 2、ほかに 1 個ずつ）。どれも呼び出し元が一つの非公開の関数なので、最適化したビルドでは LLVM が呼び出し元へインライン展開しうる。展開されると、分けた効果が消える。
- 再帰の各段で必ず通る `parse_primary`（`exprs.rs:226`〜`312`）も同じ問題を持つ。`parse_paren`・`parse_list`・`parse_if`・`parse_match`・`parse_lambda`・`effects::parse_*`・`interp::parse_interp`・`foreign_case` を、それぞれ一か所から呼んでいる。インライン展開されると、`parse_primary` の枠はこれらの局所変数の最大（最適化しないビルドなら和）まで膨らむ。
- 121 のテスト `records_obey_sequence_and_recursive_depth_limits` は `syntax/parser/records.rs:440` にある。更新元の再帰 `R(.. R(.. x, f: 0), f: 0)` を 996 段まで通す。再帰の経路は `parse_record_expr` → `parse_base` → `parse_expr` → `parse_bp` → `parse_primary` → `parse_leaf` → `parse_name` → `parse_record_expr` で、1 段あたり 7 枠になる。2 MiB で 996 段を通すには、1 段あたりおよそ 2 KB に収める必要がある。

### 1.3 フォーマッタ（later-issues の 119）

所見は成り立つ。`cli/tools/formatter/mod.rs:66` の `format_source` は `parse`（`:73`）を直接呼ぶ。`verify.rs:60` も同じである。`run_fmt_with`（`:122` 以下）にも `on_large_stack` はない。

check・run・test 側の今の位置は次のとおり。項目の行番号から一部がずれている。

- `pipeline.rs:123`・`184`・`204`
- `cli/mod.rs:515`（項目では 490）
- `cli/tools/test_runner/mod.rs:325`

`on_large_stack` は `pipeline.rs:225` に `pub(super)` で定義してあり、`pipeline` はクレートの根の子なので、クレート全体から呼べる。

### 1.4 テスト用の補助の関数（C-11）

- `resolve::test_support::resolve_files`（`resolve/test_support.rs:9`）は、読み込み（字句解析と構文解析）と名前解決を、テストのスレッドで直接行う。
- `typeck::test_support::check_files` と脱糖の `desugar_files`（`ir/desugar.rs:360`）も同じである。コード生成のテストの `compile_files`（`bytecode/codegen/tests.rs:22`）は、さらに `lower_program` と `codegen` もテストのスレッドで行う。

match の本体を 300 段入れ子にすると、深さはおよそ 900 になる（1 段で match・分岐・ブロックの 3 段を数える）。構文解析の境界のテスト（`parser/mod.rs:1818`）には「match の本体」の入れ子がないので、構文解析と名前解決のどちらで溢れたかはまだ分からない。`if` を 192 段入れ子にした場合については、later-issues の 20 の実測で、脱糖が溢れると分かっている（2 MiB で、`else if` を含む `if` が 180 段）。

実装の規約との関係は次のとおり。AGENTS.md「再帰の深さ」の「スレッドのスタックの大きさを変えてテストを通すことはしない」と ADR 0087 の決定 3 は、補助の関数のために大きなスレッドを作ることを禁じている。したがって、直し方は枠を小さくすることだけである。これらの補助の関数を `on_large_stack` で包む直し方は、規約に反する。

### 1.5 `#[inline(never)]` の今の付き方

- 付いている箇所は、`typeck/`（`generate.rs` に 19 個、`consts.rs` に 7 個、`pattern_ext.rs` に 2 個、`decls.rs` に 1 個）と `vm/dispatch*` だけである。型検査は作業 F10 で、大きな分岐を `#[inline(never)]` の関数に分け終えている（`typeck/generate.rs:139` の `expr`、`:1031` 付近の「大きい分岐を再帰する入口から分け…」というコメント）。今回の直し方の手本になる。
- 型検査で付いていない再帰の関数もある。`generate.rs:202` の `call`、`typeck/records.rs:68` の `expr`、`typeck/effects/mod.rs:27` の `expr`、`generate.rs:960` の `reach_expr` である。
- 構文解析、名前解決（`resolve/`）、脱糖、判定の木、コード生成（`bytecode/codegen/`）には、一つも付いていない。

## 2. 1 段の枠が大きそうな関数の候補（読んで付けた見当）

最適化しないビルドでは、一つの関数の中のすべての分岐の局所変数と一時的な値が、それぞれ別の場所に置かれる。このため、`match` の分岐を同じ関数の中に書くと、枠はそれらの和になる。最適化したビルドでは場所の重ね合わせで和から最大に近づくが、一か所から呼ぶ補助の関数がインライン展開されて戻ってくる。どちらのビルドでも、再帰の各段で必ず通る振り分けの関数を細くすることが効く。

| 段 | 関数（位置） | 理由 | 見込み |
|---|---|---|---|
| 判定の木 | `Lowerer::comp`（`decision.rs:227`） | 分岐ごとに `LCompKind` を組み立て、`Result<LComp, _>` の一時的な値が約 20 か所ある。Let の連なりで文の数だけ積む | 最も重い（debug で 19.6 KB/段の実測） |
| 判定の木 | `match_comp`（`:306`） | 行列、counts、labels、bodies、`Emission` を一つの枠に持ち、本体の `comp` へ再帰する | 重い |
| 判定の木 | `emit`（`:1155`）、`leaf`（`:1258`） | 四つの分岐の `Vec` とループ。ガードの fallback で `emit` → `leaf` → `emit` と連なる | 中 |
| 判定の木 | `tree`（`:542`） | 上限超過の診断の組み立てが同じ枠にある。ガードの fallback で直接再帰する | 中 |
| 判定の木 | `val`（`:183`） | ラムダの本体で `comp` へ再帰する。`ValKind` の組み立てが同じ枠にある | 中 |
| 脱糖 | `State::expr`（`ir/desugar/exprs.rs:16`） | 約 20 の補助の関数を振り分ける。最適化したビルドでは、一か所から呼ぶ補助の関数（`list`・`record`・`binary`・`lambda`・`match_expr` など）がインライン展開されうる | 最適化したビルドで重い |
| 脱糖 | `if_expr`（`:540`）、`statements`（`:570`）、`binding_stmt`（`:592`） | 一時的な `Comp`（構造体全体を値で持つ）が多い。`statements` は文ごとに再帰する（`statements` → `binding_stmt` → `statements`） | debug で重い（20 の実測） |
| 脱糖 | `binary`（`:389`）、`list`（`:666`）、`record`（`:775`）、`match_expr`（`patterns.rs:127`）、`handle`（`effects.rs:199`） | 分岐の中で表を引き、`Comp` を組み立てる | 中 |
| 構文解析 | `parse_primary`（`exprs.rs:226`） | 前述のインライン展開の問題 | 最適化したビルドで重い（121） |
| 構文解析 | `continue_bp`（`exprs.rs:94`） | 演算子の連鎖、`report_chain`（`DiagBuilder` と `format!`）、`skip_dot`、`finish_call`、`finish_binary` | 中 |
| 名前解決 | `Resolver::expr`（`resolve/walk.rs:301`） | Record・Lambda・With・Handle の分岐を同じ枠の中に書いている。Handle の分岐は `BTreeMap` を持ち、`duplicate` の診断も組み立てる | 中（C-11 の候補） |
| 型検査 | `call`（`generate.rs:202`）、`records::expr`、`effects::expr`、`reach_expr` | F10 の分割から漏れている | 小〜中 |
| コード生成 | `Gen::comp`（`bytecode/codegen/emit.rs:8`） | Escape・Lazy・Resume の分岐を同じ枠の中に書いている。ほかの分岐は補助の関数（`let_`・`if_`・`case_*`・`join`）へ分けてあるが、`inline(never)` がないので、最適化したビルドでは戻りうる | 中 |
| コード生成 | `let_`（`emit.rs:123`） | Let の連なりで 1 文あたり `let_` と `comp` の 2 枠を積む。`with_reads` が作る `HashSet` を `Box` で持つ | 中 |

コード生成の `free_keys`・`captured`（`analysis.rs`）は明示の積み重ねで書いてあり、問題ない。ラムダの本体は `pending` に積んで後で処理する（`emit.rs:1179`・`1230`）ので、コード生成ではラムダの入れ子が再帰にならない。

## 3. 直し方の具体案

### 3.1 共通の決まり

1. 再帰の各段で必ず通る振り分けの関数（`comp`・`expr`・`parse_primary` など）は、分岐ごとに補助の関数を一つ呼ぶだけにする。補助の関数には `#[inline(never)]` を付ける。型検査の F10 と同じ形で、コメントで理由と設計書の節を書く（例: 「再帰の入口から大きい分岐を分け、構文の上限内で積み重なる枠を抑える（設計書 02-01「関数の呼び出しと処理系のスタック」）。展開すると再び枠が大きくなる」）。
2. 再帰の経路にない重い処理（診断の組み立て、`format!`、表の引き当て、大きな構造体の組み立て）は、`#[cold]` と `#[inline(never)]` を付けた関数へ出す。`finish_*` 系にも `#[inline(never)]` を付ける。
3. 振り分けの関数自身にも `#[inline(never)]` を付ける。呼び出し元へ展開されて、呼び出し元の枠と合わさるのを防ぐためである。

### 3.2 判定の木（`decision.rs`）

- `comp` の分岐を、`lower_let`・`lower_app`・`lower_method`・`lower_if`・`lower_use`・`lower_lazy`・`lower_handle`・`lower_return`・`lower_escape`・`lower_resume` に分ける。どれにも `#[inline(never)]` を付ける。`comp` は `match` と `Ok(LComp { .. })` だけにする。
- Let の連なりの扱い（設計者の判断が要る。7 の問い 3）。案 A は分割だけにとどめる案で、1 文あたりの枠は `comp` と `lower_let` の和になる。案 B は、`comp` の中で Let の body の連なりをループで下り、`(var, lowered bound)` を `Vec` に積んでから後ろ向きに組み立て直す案である。案 B では、文・要素・引数の数が再帰の深さに効かなくなる。
- `match_comp` は前半（行列と木の作成、counts）、本体の写し、join の組み立ての三つの関数に分ける。それぞれに `#[inline(never)]` を付ける。
- `emit` は `emit_ctor`・`emit_constant`・`emit_length`・`emit_gets` に分け、`leaf` のガードの分岐を `leaf_guard` に分ける。どれにも `#[inline(never)]` を付ける。
- `tree` は上限超過の診断を `#[cold] #[inline(never)] fn limit_error(&self, note) -> LowerError` に出す。葉の手順 2 も `leaf_tree` に分ける。
- `val` はラムダの分岐を `#[inline(never)] fn lower_lambda` に出す。

### 3.3 脱糖（`ir/desugar/`）

- `State::expr` の振り分け先のうち、再帰の経路で枠が大きいものに `#[inline(never)]` を付ける。対象は `list`・`record`・`binary`・`unary`・`pipe`・`lambda`・`if_expr`・`match_expr`・`call`・`try_expr`・`with`・`handle`・`lazy`・`interpolation` である。
- `if_expr` は、再帰の後の組み立て（`result_ty`・`branching`・`finish`）を `#[inline(never)] fn finish_if(...)` に出す。こうすると、再帰の呼び出しのときに枠に残る一時的な値を、cond と then の結果だけにできる。
- `statements`・`binding_stmt` の文ごとの再帰は、案 B と同じく、文をループで処理して最後に `finish` でまとめる形に直す余地がある（問い 3）。

### 3.4 構文解析（`syntax/parser/`）

- F03 への対応として、`parse_literal_or_error`・`parse_foreign_lambda`・`finish_name` に `#[inline(never)]` を付ける。
- `parse_primary` の振り分け先（`parse_paren`・`parse_list`・`parse_if`・`parse_match`・`parse_lambda`・`parse_return`・`parse_unary`・`foreign_case`、`effects::parse_*`・`interp::parse_interp`）に `#[inline(never)]` を付ける。
- `finish_*` の全体（28 個）と、`report_chain`・`skip_dot` に `#[inline(never)]` を付ける。`report_chain`・`skip_dot` には `#[cold]` も付ける。
- records 側は、`parse_record_expr`・`finish_expr`・`finish_field_arg`・`record_placeholder` に付ける。

### 3.5 名前解決とコード生成

- 名前解決の `walk.rs:301` `expr` は、Record・Lambda・With・Handle の分岐を `#[inline(never)]` の関数に分ける。`shadow.rs` の `arm`・`bind_statement` にも付ける。
- コード生成の `Gen::comp` は、Escape・Lazy・Resume を補助の関数へ出し、既存の補助の関数（`let_`・`if_`・`case_ctor`・`case_const`・`case_length`・`join`・`app`・`handle`）に `#[inline(never)]` を付ける。

### 3.6 フォーマッタ（119）

`run_fmt_with` から `format` を呼ぶところ（または `format_source` の中身）を `pipeline::on_large_stack` で包む。check と同じく、スレッドの panic を受け取って処理系の不具合として報告する経路に合わせる。単体テストは、今の `deep_nesting_uses_the_default_test_thread_stack`（`cli/tools/formatter/print/tests.rs:452`）のとおり既定のスタックで行う。

## 4. 回帰テストの案

### 4.1 入れ子の上限の定義

- `syntax/parser/mod.rs:82` `pub const MAX_DEPTH: u32 = 1000;`
- 判定は `Parser::enter`（`:400`）、数え方は `child`（`:591`）・`nth_child`（`:601`）、設計は 02-03「入れ子の深さ」による。

### 4.2 今ある深さのテスト

| テスト | 位置 | 経路とスタック | 深さ |
|---|---|---|---|
| `nesting_and_sequence_limits_use_the_default_test_thread_stack` | `syntax/parser/mod.rs:1818` | 構文解析だけ、既定のスレッド | 上限ちょうどと超過。括弧、if、ラムダ、文、リストの要素、演算子の連鎖、入れ子のパターン、入れ子のリスト、単項、呼び出しの連鎖、パターンの節、型（括弧・名前付き・関数）、引数、分岐をまたぐパターン。match の本体はない |
| `extension_sequence_and_nesting_limits_use_default_thread_stack` | `syntax/parser/effects.rs:829` | 構文解析、既定 | 上限 |
| `interpolation_sequence_and_nesting_limits_use_default_stack` | `syntax/parser/interp.rs:179` | 構文解析、既定 | 上限 |
| `records_obey_sequence_and_recursive_depth_limits` | `syntax/parser/records.rs:440` | 構文解析、既定 | 上限（121 は opt-level 1・2 で溢れる） |
| `deep_expressions_stay_within_the_normal_stack` ほか 2 件 | `typeck/pattern_ext.rs:784`・`810`・`820` | 型検査まで、既定 | 上限より浅い（binary 450/498、if 450/498、lambda 300/332、match の本体 200/331） |
| `deep_ir_is_checked_without_changing_the_thread_stack` | `ir/check.rs:3077` | コア IR の検査、既定 | Let 1000 |
| `nested_expressions_and_long_list_literals_pass_with_the_normal_stack` | `ir/desugar/tests.rs:1311` | 脱糖まで、既定 | 括弧 48、要素 256 |
| `nested_patterns_and_long_lists_preserve_bindings_without_changing_stack_size` | `ir/decision.rs:3191` | 判定の木、既定 | 構成子 64、リストのパターン 1024 |
| `deep_nesting_uses_the_default_test_thread_stack` | `cli/tools/formatter/print/tests.rs:452` | 整形、既定 | 上限付近 |
| `deep_expressions_check_at_the_parser_depth_limit` | `pipeline.rs:606` | check だけ、64 MiB | 上限 |
| `deep_patterns_check_at_the_parser_depth_limit`（long、約 26 秒） | `pipeline.rs:650` | check だけ、64 MiB | 上限 |
| `long_list_patterns_and_boolean_matrix_check_near_the_depth_limit` | `pipeline.rs:685` | check だけ、64 MiB | 上限付近 |
| `deep_if_and_else_if_check_on_the_default_calling_stack` | `pipeline.rs:738` | check だけ、64 MiB（名前と違って段のスレッドで動く） | if 490 |
| ゴールデンテスト（`validate_core`、差分テスト） | `tests/golden.rs:680`、`tests/golden/differential.rs:48` | 脱糖・実行、`STAGE_STACK_BYTES` | 入力しだい |

脱糖・判定の木・コード生成を、上限近くの入れ子で小さいスタックのまま通すテストは一つもない。

### 4.3 新しいテストの形

- 置き場所は `pipeline.rs` の `mod tests` がよい。非公開の `check_stages`（`pipeline.rs:237`）を直接呼べるからである。
- スレッドの作り方: `std::thread::Builder::new().stack_size(SMALL).spawn(...)` で作ったスレッドの中で、次の順に呼ぶ。`check_stages`（`on_large_stack` を通さない） → `crate::ir::desugar::desugar` → `crate::ir::decision::lower_program` → `crate::bytecode::codegen::codegen`。最後に結果を drop する。AST と IR を破棄する処理もスタックを使うので、スレッドの中で drop させる。
- `SMALL` を明示する理由は、環境変数 `RUST_MIN_STACK` やテストの実行器の都合で、既定のスタックの大きさが変わらないようにするためである。値は問い 1 で決める。
- 各形の深さは、`deep_expressions_check_at_the_parser_depth_limit` と同じく `(MAX_DEPTH - c) / k` で上限ちょうどに置く。上限を 1 超える側は、既存のテストが確かめているので要らない。
- 実行（VM）は Rust の再帰を使わない（ADR 0016）。数件だけ `run_with` で結果を確かめてもよいが、必須ではない。

### 4.4 対象にする構文の入れ子（優先順）

1. 平らなブロックの文 997 個（Let の連なり。判定の木の `comp` とコード生成の `let_` の最悪の場合）
2. リストの要素 997 個、呼び出しの引数 997 個、レコードのフィールド 996 個（同じく Let の連なりになる）
3. `if` の then の入れ子と、`else if` の連なり（脱糖の `if_expr`。20 の実測で最初に溢れた）
4. match の本体の入れ子、match の対象の入れ子
5. ガード付きの分岐を多く並べた match（`case x if g -> …` を約 330 個並べる。判定の木の fallback で `tree`・`emit`・`leaf` が連なり、`If` の入れ子にもなる）
6. 入れ子の構成子のパターンとリストのパターン（`L.Mk(L.Mk(…))`、`[[…]]`。網羅性の判定に時間がかかる。`pipeline.rs:650` は 26 秒の long なので、別の long のテストにするか、大きさを見積もってから入れる）
7. 二項演算子の右の入れ子 `(1 + (1 + …))` と、左の連鎖 `x + x + …`（左に深い木になる）。パイプの連鎖 `x |> f |> f …`
8. レコード式の入れ子 `R(f: R(f: …))` と、更新元の入れ子 `R(.. R(.. x, f: 0), f: 0)`
9. ラムダの入れ子、ブロックの入れ子（`with`・`lazy`・`handle`）、`try`
10. 単項の連鎖 `not not …`、括弧、入れ子のリスト `[[[x]]]`
11. 型注釈（引数の `List[List[…]]` と関数型）。名前解決と型検査で型の木を辿り、コア IR の `Ty` の複製と破棄も通る

### 4.5 debug と release

- `scripts/check.sh` はテストを dev のプロファイル（opt-level 0）だけで走らせる。`:299` の `cargo test --workspace …` と `:300` の gc-stress がそれで、`--release` を使う検査はどこにもない。`Cargo.toml` の `[profile.release]` は `overflow-checks` と `panic` だけを定め、opt-level は既定（3）である。
- 121 が示すとおり、最適化しないビルドでは通るのに最適化したビルドでは溢れる場合がある。逆に、debug の枠は場所の重ね合わせがないので一般に大きい。両方で通すべきである（問い 2）。
- 注意: `--release` で走らせても opt-level 3 しか確かめられない。121 が起きた opt-level 1・2 を確かめるには、独自のプロファイルが要る。

## 5. 本番の 64 MiB のスレッドについての見解

変えなくてよいと考える。

- スレッドのスタックは仮想の領域を予約するだけで、使った分だけ実際のメモリが割り当てられるのが一般的である（確かめた事実ではないので設計書には書かない）。小さくしても、測って分かるほどの利益はない見込みである。
- 今回の分割で必要なスタックが減れば、64 MiB に対する余裕が増える。ADR 0087 が退けた「関数ごとの調整だけで上限いっぱいの入力を守る」状態に戻らないためにも、本番の大きさは今のまま保つのがよい。
- 気にかかる点は、`cli/mod.rs:515` の `on_large_stack` の中で `pipeline::check` がさらに `on_large_stack` を呼び、64 MiB のスレッドが入れ子に 2 本並ぶことである。害は見当たらないが、整理するなら別の項目にする。

## 6. スタックの消費を測る方法

### 案 A（推奨）: 子のプロセスで、溢れない最小のスタックを二分探索する

1. 測定用の入口を用意する。開発用の例（`crates/benitoite/examples/stack_probe.rs`）か、`#[ignore]` のテストにする。環境変数で「構文の形、深さ N、スタックの大きさ S、段（parse・check・desugar・lower・codegen・全部）」を受け取り、4.3 と同じ手順を S のスレッドで行う。
2. 駆動する側（Python か、同じテストのバイナリを `std::env::current_exe()` で子として起動する ignore のテスト）が S を二分探索し、溢れない最小の S を求める。スタックが溢れると子は異常終了する（stderr に "has overflowed its stack" が出る）ので、終了状態で判定できる。
3. 深さを N/2 と N の二通りにして、`(S(N) − S(N/2)) / (N/2)` を 1 段あたりのバイト数とする。4 KiB 刻みで探しても、500 段の差なら誤差は 1 段あたり 10 バイト程度に収まる。
4. debug と `--release` の両方で、直す前と直した後を測り、改造のディレクトリに表として残す。

この方法は Rust の stable だけで動き、子のプロセスを起動できれば Codex のサンドボックスでも使える。段ごとに測れるので、どの段が溢れるかも分かる（C-11 の切り分け）。

### 案 B（補助）: 関数ごとの枠の大きさをアセンブリから読む

`cargo rustc -p benitoite --lib [--release] -- --emit=asm` で出力を作り、関数の前置き（aarch64 の `sub sp, sp, #N`。大きい枠は `lsl #12` 付き。x86_64 の `sub rsp, N`）から枠の大きさを拾う。候補の関数の順位付けと、`#[inline(never)]` が効いたか（関数が残っているか）の確認に使える。シンボル名は mangle されたまま出る。

### 使えない方法と勧めない方法

- nightly の `-Z emit-stack-sizes` は ELF だけが対象なので、macOS の手元では使えない見込みである（未確認）。
- 再帰の関数に、局所変数の番地を記録する仕組みを入れる方法は、本番のコードを変えるので勧めない。

## 7. 影響する設計書とテスト、設計者への問い

### 7.1 影響する設計書

- 02-01「関数の呼び出しと処理系のスタック」: 段の再帰の関数を細く保つ方法（振り分けの関数と `#[inline(never)]`、Let の連なりの扱い）と、小さいスタックで run の経路を通すテストを書き足す。フォーマッタを段のスレッドで動かすことも書く。
- 06-03（フォーマッタ）「整形の流れ」: 構文解析と整形を段のスレッドで行うこと。
- 07-03「実装の規約と静的な検査」: 道具では確かめにくい規約の一覧に、再帰の振り分けの関数の書き方を加える。テストの種類に、小さいスタックの run の経路のテストと、その release での実行を加える。
- AGENTS.md「再帰の深さ」: 「再帰の入口の大きい分岐は `#[inline(never)]` の補助の関数に分ける」を加える。4 MiB を使う場合は、例外の記述も要る（問い 1）。
- 02-03「入れ子の深さ」は、数え方を変えなければ直さなくてよい。

### 7.2 影響するテスト

- 新設: `pipeline.rs` の小さいスタックの run の経路のテスト。
- 既存の手直しの候補:
  - `typeck/pattern_ext.rs:784` の深さを上限まで上げる。今は上限の 60〜90%。
  - `syntax/parser/mod.rs:1818` に「match の本体」の入れ子を加える（C-11 の切り分け）。
  - `ir/desugar/tests.rs:1311` と `ir/decision.rs:3191` は、新しいテストで覆えるなら test-audit の手順で整理を検討する。
  - `pipeline.rs:738` の名前（"default calling stack"）が実際（64 MiB の段のスレッド）と合っていない。
- `scripts/check.sh` は、問い 2 の答えによって手直しが要る。

### 7.3 設計者への問い

**問い 1: run の経路のテストのスタックの大きさ**

- 選択肢 A: 2 MiB（既定と同じ値を明示する）。規約と ADR 0087 の決定 3 にそのまま合う。Let の連なりをループにする（問い 3 の案 B）ことと、段ごとの分割が要る見込みである。構文解析と型検査は、最小実行版の時点で上限いっぱいに約 1.6〜1.7 MB を使っていたので、余裕が小さい。
- 選択肢 B: 4 MiB。直す範囲は小さくて済むが、「スタックの大きさを変えて通さない」の例外になる。例外とその理由を書き足す必要がある。
- 推奨: まず案 A の測定（6 の案 A）で分割後の値を見る。debug で 2 MiB に収まるなら A、収まらない段が残るなら、その段の数字を記録したうえで B を例外として認める。

**問い 2: release でのテストの走らせ方**

- 選択肢:
  - (a) 走らせない。
  - (b) `check.sh --full` のときだけ、`cargo test --release -p benitoite --lib -- <小さいスタックのテストの名前>` を走らせる。
  - (c) 構文解析・名前解決・型検査・IR・コード生成のファイルを変えたときの選んだ検査にも入れる。
  - (d) 独自のプロファイル（opt-level 2）も加える。
- 推奨: (b)。この改造の中で一度は (c) 相当を手で走らせる。release のテストのバイナリのビルドには数分かかる見込みなので、(c) の常用は重い。opt-level 1・2（121）は、構文解析の `#[inline(never)]` で直ったことを、この改造の中で一度手で確かめるにとどめる。

**問い 3: Let の連なりの扱い（ADR 0087 の決定 3 の分割に加えて、ループにするか）**

- 選択肢:
  - 案 A: 分割だけにする。
  - 案 B: 判定の木の `comp` だけ、Let の body をループで下る。
  - 案 C: 案 B に加えて、脱糖の `statements` とコード生成の `let_` もループにする。
- 推奨: 案 B。文・要素・引数の数で積む最悪の場合を、変更の小さい一か所で消せる。脱糖とコード生成は、測ってから決める。

**問い 4: フォーマッタ（119）をこの改造に含めるか**

- 推奨: 含める。変更は `run_fmt_with` を `on_large_stack` で包むことと、panic の報告の経路を合わせることだけで小さい。

**問い 5: 測定の道具を残すか**

- 推奨: `examples/stack_probe.rs` として残し、後の構文の追加のときにも使えるようにする。残さない場合は、改造のディレクトリに測定の手順と結果だけを書く。
