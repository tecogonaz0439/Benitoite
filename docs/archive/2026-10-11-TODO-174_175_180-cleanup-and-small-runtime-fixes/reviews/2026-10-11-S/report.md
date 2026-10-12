# 作業 S のレビュー

対象はコミット dc74f08（親は 037f0b0）である。ファイルは `git show` と `git diff 037f0b0 dc74f08` で読んだ。cargo は走らせていない。振る舞いを変える誤りは見つからなかった。要修正は check.sh の 1 件だけで、軽い直しで済む。そのほかの指摘はすべて任意である。

## 指摘

### 1. `--only release_stack` では long のテスト 5 本が黙って飛ばされる（要修正・軽微）

- **場所**: `scripts/check.sh` 333 行（`run_check "release measured-stack tests" ... $test_args`）、292〜295 行（`test_args` を決める箇所）。
- **問題**: `test_args` が `--include-ignored` になるのは、`has long` のときだけである。`--full` では long も選ばれるので、9 本すべてが走る。一方、報告は「`--only release_stack --dry-run` でも単独で選べます」と書いている。その形で走らせると `test_args` が空になり、`#[ignore = "long: ..."]` の付いた 5 本（flat_sequences・deep_records・deep_blocks・nested_patterns・nested_lists）が走らない。この 5 本には、今回の直しの中心である文の並び（Let の連なり）を確かめる `statements` が含まれる。表示の説明は「release measured-stack stage tests」なので、一部しか走っていないことに気づけない。
- **直し方**: この段では、`$test_args` に頼らず常に `--include-ignored` を渡す（`cargo test --release -p benitoite --lib -- pipeline::tests::stages_fit_the_measured_stack_ --include-ignored`）。この段は `--full` か `--only` でしか選ばれないので、`--full` でないときの選択は変わらない。

### 2. 文の並びの回帰を確かめるテストが long だけにある（任意）

- **場所**: `crates/benitoite/src/pipeline.rs` 435〜438 行付近、`stages_fit_the_measured_stack_for_flat_sequences`。
- **問題**: 判定の木の `lower_lets`、脱糖の `statement_sequence`、コード生成の `let_` のループの最悪の場合は `statements` である。ところが `statements` は、時間のかかる `list`・`arguments`・`fields` と同じ long のテストに入っている。普段の `check.sh`（long なし）では、この三つのループの退行を捕まえられない。long の理由「wide expressions require repeated type and liveness traversal」は、広い式（list・arguments・fields）の説明に読める。
- **直し方**: `statements` を一本で走らせて時間を測る。10 秒に収まるなら、`stages_fit_the_measured_stack_for_statement_sequences` のような long でないテストに分ける。

### 3. パターンの束縛の連なりと文字列補間を測っていない（任意。後の項目の候補）

- **場所**: `crates/benitoite/examples/stack_probe/support.rs` の `SHAPES` と `source`。
- **問題**: `statements` の形は `bind _ <- 1` だけで、ワイルドカードの束縛（Let）の連なりしか測っていない。
  - `bind (a, _) <- …` や `bind [x] <- …` を約 997 個並べると、脱糖は今回 `StatementWrap::Match` でループにしたが、できるコア IR は Match の本体の入れ子になる。その結果、判定の木では `match_comp`→`match_bodies`→`comp`、コード生成では case の再帰が、文の数だけ積み重なる。この形は測っておらず、テストもない。
  - study-175 の 1.1 が Let の連なりになると挙げた文字列補間の式の並びも、形にない。
- **直し方**: 今回の範囲で測るなら、`pattern-statements` と `interp` の形を足して上限の深さで測る。範囲の外とするなら、docs/todo に項目を足す（オーケストレータの判断）。

### 4. テストの入力を examples から `#[path]` で読んでいる（任意）

- **場所**: `crates/benitoite/src/pipeline.rs` 355〜357 行（`#[cfg(test)] #[path = "../examples/stack_probe/support.rs"] mod stack_test_inputs;`）。
- **問題**: lib の単体テストが examples の下のファイルに依存している。support.rs の `pub const SHAPES`・`pub fn limit`・`pub fn source` には `///` のコメントがない。これらは lib のテストの構成の中で公開の項目としてコンパイルされる。AGENTS.md「コメントと名前」には「公開の関数と型には `///` のコメントを書く」とある。
- **直し方**: 入力を一か所で共有する方針は保つ。そのうえで、support.rs の公開の三項目に `///` を足す。ファイルの頭の `//!` に、lib のテストからも `#[path]` で読まれることを書く。

### 5. 新しく付けた `#[inline(never)]` のうち 3 か所に、理由のコメントがないか、内容がずれている（任意）

- `crates/benitoite/src/typeck/generate.rs` 303 行の `call_body` と、`crates/benitoite/src/syntax/parser/exprs.rs` 1032 行の `push_arm` は、`#[inline(never)]` だけでコメントがない。ほかの箇所と同じ理由のコメントを足す。
- `crates/benitoite/src/ir/decision.rs` 1704 行付近では、テストの補助の `fn val(kind, ty) -> CoreVal`（`mod tests` の中）に `#[inline(never)]` とコメントが付いている。これは置換で誤って付いたものと見られ、意味がない。消す。
- `syntax/parser/exprs.rs` の `report_chain`・`skip_dot` は `#[cold]` だが、コメントは汎用の「再帰の入口の枠を小さく保ち…」のままである。`report_match_with_newline` などと同じく、「誤りのときだけ通るので、再帰する枠に置かない」という趣旨に揃える。

### 6. テストのコメントの文が逆の意味に読める（任意）

- **場所**: `crates/benitoite/src/pipeline.rs` 420 行付近、「破棄も同じ上限の中で行い、AST と IR を返すことで退行を隠さない」。
- **問題**: 結果をスレッドから返すと、破棄が上限の外で行われる。意図は「返さない」ことである。
- **直し方**: 「AST と IR をスレッドの外へ返さず、破棄の退行も同じ上限の中で捕まえる」などに直す。

### 7. テストの中の `eprintln!` で時間を出している（任意）

- **場所**: `pipeline.rs` の `assert_stages_fit_measured_stack` の末尾、`eprintln!("{shape}: {:?}", started.elapsed())`。
- **問題**: 測るための一時的な出力が残っている。害はないが、ほかのテストの書き方と揃っていない。
- **直し方**: `started` と `eprintln!` を消す。

### 8. stack_probe で、溢れ以外のシグナルも溢れと数える（任意）

- **場所**: `crates/benitoite/examples/stack_probe.rs` の `succeeds`（`None => Ok(false)`）。
- **問題**: SIGKILL などで子のプロセスが終わっても「溢れた」とみなし、二分探索が大きい側へ進む。開発用の道具なので実害は小さい。
- **直し方**: unix では `std::os::unix::process::ExitStatusExt::signal()` で SIGABRT と SIGSEGV・SIGBUS だけを溢れとし、ほかのシグナルは Err にする。

### 9. try の脱糖で、同じ確かめが二か所にある（任意）

- **場所**: `crates/benitoite/src/ir/desugar/effects.rs` 20〜22 行と 37〜39 行。
- **問題**: 戻り値の型が `Ty::Con` かどうかを、`eval` の前と `finish_try` の中で二度確かめている。誤りの順を保つための前置きなので振る舞いは正しいが、後ろの確かめは通らない分岐である。
- **直し方**: このままでもよい。直すなら、前で取り出した `ret_args` を `finish_try` に渡す。

## 確かめて問題がなかった点

- **判定の木の Let の連なり**（`decision.rs` の `lower_lets`・`finish_lets`）: 下りながら各 `bound` をその場で `self.comp(bound, renew)?` で下ろして積み、最後に body を下ろしている。番号（var・body・join・tree_work）の割り当ての順と、`?` で返る最初の誤りは、再帰版と同じである。組み直す Let の `ty`・`eff`・`origin` は、元の `Comp` から `made` で写しており、`let_comp` は使っていない。
- **判定の木のほかの分割**:
  - `comp` の各分岐（Return・App・Method・If・Escape・Use・Lazy・Handle・Resume）と `lower_lambda` は、元と同じ順で下ろし、`made(kind, c.ty, c.eff, c.origin)` で包んでいる。Handle は、body から節の順に下ろす順も同じである。
  - `match_comp` を `match_tree`・`match_bodies`・`finish_match` に分けた形でも、`tree_work = 0` と `match_origin` の設定、`count`、join の番号と本体の順、join を逆順に包むことは元のままである。
  - `tree` から分けた `leaf_tree` では、幅の確かめが分ける前の `tree` の中に残っている。ガードの fallback の行の除き方（`skip(1)` と同じ分岐の行を除く）も同じである。
  - `leaf` は、本体（join への jump か本体の取り出し）→ガード（`guard_seen` と `renew`、ガードを下ろしてから `var`、次に fallback の順）→束縛を逆順に包む、の順を保っている。
  - `emit_*` の四つは、エフェクトの和の取り方と `made` の引数が元と同じである。
- **脱糖の文の並び**（`statement_sequence`・`binding_stmt`・`binding_wrap`・`finish_statement`）:
  - 文ごとに `expr`→`ty`→`local`/`var`→`bind`→`pattern` の順で呼んでいる。
  - 一つの式だけのブロック、空の並び、最後が束縛の文のとき（`unit(span)`）、`Stmt::Error` の誤りの位置は、元と同じである。
  - パターンの束縛の Match は、包む時点で内側の body から `ty`・`eff` を取っている。`origin` は束縛の文の span、`finish(pending, comp, span)` も元と同じである。
- **脱糖の else if の連なり**（`if_expr`）:
  - 各段で条件と then を同じ順で下ろし、最後に else（ブロックか `unit(current.span)`）を下ろしている。
  - `result_ty`（`desugar.rs:208`。状態を変えない参照だけの関数）を内側から順に取って包むので、型の取り方も誤りの順も元と同じである。
- **コード生成の `let_`**:
  - 各段で `mark`→`alloc`→`with_reads(future, Node::Comp(body_i))`→bound の生成→`bind`→`alias` の順を保っている。連なりの body の `future` は外側と同じなので、各 bound の future も元と同じになる。
  - 最後の body の後、`unbind`・`release` を逆順に行っている。`Gen::comp` の入口には振り分けのほかの処理がないので、内側の Let で `comp` を通らなくても差は出ない。
  - 誤りで早く返るときに後始末をしないのは、元と同じである。
- **補助の関数に分けたほかの箇所**:
  - 名前解決の `resolve_record`・`resolve_lambda`・`resolve_with`・`resolve_handle`・`arm_bindings` で、スコープの push と pop の対応と順は元のままである。元の `arm` には早い戻りがない。
  - 型検査の `lazy_expr`・`try_expr`・`resume_expr`・`report_value_call`・`check_missing_fields` も、元のままである。
  - 構文解析は、属性を付けたほかは `report_match_with_newline` を外に出しただけである。
  - 脱糖の `finish_logic_binary`・`finish_strict_binary`・`finish_unary`・`finish_list`・`match_arms`・`finish_try` では、`pending` の受け渡しと早い戻り（`finish_list` の `after.is_empty()`）が元と同じである。
- **整形**（`cli/tools/formatter/mod.rs` の `fmt_file`）:
  - 包むのはファイルごとの `format` の呼び出しだけで、`panic_boundary::catch` は段のスレッドの内側にある。この形は `pipeline::check` と同じである。
  - スレッドを起こせないときは `internal_diagnostic(STAGE_FMT, …, FaultThread::Stage)` を書き、`EXIT_INTERNAL` を返す。構文の誤りと検証の誤りの分岐は元と同じである。
- **pipeline.rs の入口**:
  - `memory_entry` は、元の `check_files` の組み立てをそのまま移したものである。`check_files` は今も `check`（段のスレッド）を通る。
  - `check_text_on_current_thread` は `#[doc(hidden)]` を付けて `check_stages` を直接呼ぶだけで、`check`・`desugar_checked`・`compile` の経路には触れていない。
- **新しいテスト**:
  - 各形について、診断が空であること、`program` が `Some` であること、`desugar`・`lower_program`・`codegen` がすべて `Ok` であることを確かめている。結果は 16 MiB のスレッドの中で drop している。
  - 深さは `(MAX_DEPTH - c) / k` で決めている。
  - 接頭辞 `stages_fit_the_measured_stack_` は、クレートのほかの場所に現れない。
  - 改名した `deep_if_and_else_if_check_on_the_stage_stack` は `check_text`（64 MiB の段のスレッド）を使っており、名前と実際が合っている。
- **check.sh**: `release_stack` は `check_names`、`--full` のループ、`describe`、実行の段に加わっている。`classify` は変えていないので、`--full` でないときの選択は変わらない（指摘 1 の `--only` を除く）。
- **規約**:
  - 新しいコードの `unwrap`・`expect` はテストのモジュールの中だけにある。`#[allow]` と `unsafe` の追加はない。
  - 新しいコメントには、保管した実装プランや作業の ID がない（`実装プラン F18` は既存のコメントである）。
  - コメントが引く設計書の節（02-01・02-03・02-06・02-07・01-12・07-03）は、すべて実在する。
  - `src/vm`・`runtime`・`builtins` は変えていない。
- **stack_probe**:
  - lint に合わせて、算術は `checked_*`・`saturating_*`、引数は `get`・`?` で書いている。
  - 子のプロセスの終わり方は、成功（0）・溢れ（シグナル）・入力の誤り（2）に分けている。入力の誤り（診断がある、段が `Err` を返した、段が panic した）では探索を止める。
  - 段の結果は、測るスレッドの中で破棄している。
