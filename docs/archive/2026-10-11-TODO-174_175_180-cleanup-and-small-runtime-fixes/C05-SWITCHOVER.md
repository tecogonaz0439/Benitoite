# C05 テスト切り替えの検査記録

C05 の移行、CLI とベンチマークの切り替えを実施した。追加指示による修正に続き、オーケストレータの確認で指摘された宣言の補助位置と演算子の診断を直した。`scripts/check.sh` は既定の設定ですべて通り、採用済みの GC の強制の除外を含む C05 の完了条件を満たした。

## 作ったもの

- C03 の 197 ケース、U1 の 60 ケース、C10 の 6 ケース、計 263 ケースを `testdata/` に移した。書き直せなかったものは 0 ケースであり、全ケースに `.exit` がある。`acceptance/INDEX.md` の内容と対象の名前を維持した。
- C10 の実行器を `tests/golden.rs`、補助モジュールを `tests/golden/` に移し、探索先を指定どおりにした。古い実行器、`tests/next_syntax.rs`、`testdata-next/`、`REWRITE.md` を削除した。
- 許可された U1 の入力 2 件と、仕様の参照のコメントを直した C10 の 6 件を除き、移した `.bnt` は書き換えていない。期待値は 124 ケースの `.diag.json` と、そのうち 7 ケースの `.text.stderr` を更新した。終了状態とスクリプトの標準出力・標準エラー出力は維持した。C10 の書き直しが空の出力ファイルを省く場合はある。
- `src/main.rs` と `tests/cli_process.rs` を初回リリース版へ切り替えた。CLI のテストの場合の一覧を維持し、版の表示には Unicode の版の行も期待した。
- ベンチマークの 9 本の `.bnt`（`depth.bnt` を含む）と `run.py` の生成する起動時間用・検査時間用のソースを新しい構文と名前にした。`.args.small`、小さな入力ファイル、比較対象の言語のプログラムは維持した。確保統計の 4 欄と、C18 まで使えない `--bytecode-stats` の理由付き終了を実装し、README を更新した。

## 追加指示による修正

| 対象 | 修正と確認する契約 |
|---|---|
| `src/syntax/parser/foreign.rs` | 文脈で決まらない他言語の演算子に記号ごとの修正案を付けた。`?` に `try` を示す |
| `src/typeck/decls.rs`・`src/typeck/tests.rs` | E0418 の主な位置を、使わないエフェクト変数の名前にした。既存の単体テストの期待値も、関数名の列 10 から宣言の E の列 19 に更新した |
| `src/typeck/generate.rs` | 二項演算と if の両分岐に整数リテラルの情報を載せ、Float の修正案を保持した。if の不一致は結果の式を指す。E0408 に上下限の注記を付けた |
| `src/typeck/pattern_ext.rs` | パターンの範囲の E0408 に上下限の注記を付けた |
| `src/typeck/solve.rs` | 関数型の不変なエフェクトの不一致で、外側の型の期待と実際を示す。診断用の型の表示では未確定の変数を `_` にし、出力用の Unit の既定値を使わない |
| `src/typeck/effects/declarations.rs` | W0501 の置き換えの集合が空なら、`remove` の修正案で宣言の削除を示す |
| `src/resolve/lookup.rs` | `String.substring` に `slice` の修正案を対応させた。取り込み済みの型板の `characterCount`・`characterSlice` を使う。`Benitoite.String` の表示名は今回の指示で受け入れた |
| `src/refinterp/convert.rs` | 関数と位置の値を、呼び出し中の表の番号を持つ非公開の opaque の値で写す。戻りで元の値に戻し、表は呼び出しを越えて残さない |
| `src/prelude/stdlib/List.bnt` | map・filter・fold・forEach・any・all・find の補助の関数を、head と tail で残りのリストを辿る形にした。map と filter の結果は prepend で積み、最後に reverse する。補助の名前と公開シグネチャ、評価順序・短絡・エフェクトは維持した |
| `docs/archive/2026-10-09-implement-first-release/10-interfaces/10-14-prelude-and-stdlib-sources.md` | 上の List.bnt の写しを同じ内容にした。実ファイルとブロックの完全一致、公開の関数の全シグネチャの維持を確認した |
| `patterns/f04_scores.bnt`・`syntax/f03_constants_aliases.bnt` | 指定された match と lambda に return を加えた。成功する終了状態の期待値は変えていない |

取り込み済みの 10 ファイルの参照の変更も維持した。47 個の `include_str!` と 2 個の実行時のパスから `testdata-next/` がなくなったことを確認した。

C10 の 6 ケースの参照のコメントに存在しない見出しがあり、仕様の集計の self-test が失敗したため、実在する節名へ直した。01-spec の対象は `// spec:`、02-11・06-01 の実装と CLI の対象は `// test:` とし、仕様の網羅率を誤って数えない。コメントの長さで変わる 4 ケースの診断のオフセットも、位置の区分として更新した。

## 今回の確認による修正

| 対象のケース | 修正した診断 |
|---|---|
| `acceptance/effect_violation.bnt`、`effects/choose_io_violation.bnt`、`effects/map_with_io_pure_violation.bnt`、`effects/pure_calls_io.bnt` | E0501 の理由の `related` に関数名の span を渡し、`declared here` の補助位置を戻した |
| `types/arity.bnt` | 呼び出し先の宣言位置を理由に渡し、E0402 の 2 件に `function declared here` を戻した |
| `types/equality_function.bnt`、`types/equality_ioerror.bnt`、`types/equality_summary.bnt` | E0406 の主な位置を式全体に戻した。後者 2 件の型は `Result[String, IOError]`、`Nest[function() -> Unit]` とし、外側の型を示す |
| `types/operator_set.bnt`、`types/operator_on_type_param.bnt` | E0405 の主な位置を式全体に戻した |
| `types/undetermined.bnt` | E0407 の主な位置を式全体に戻した |

期待値の更新は上の 11 ケースの `.diag.json` に限る。前回の期待値との違いは、E0501・E0402 の補助位置の追加、演算子の主な位置、E0406 の外側の型の表示だけであり、診断コード・件数・終了状態・スクリプトの出力は維持した。`src/typeck/generate.rs` と `solve.rs` を直し、`context.rs` の既存の補助位置の処理を使った。整数の `/` の修正案は、式全体の主な位置とは別に演算子の span を保持し、`/` だけを `div` に置き換える。

同じ位置の変更を検査する既存の単体テスト 5 件も更新した。対象は `typeck::tests::operators_warnings_and_fixes`・`returns_monomorphism_unknown_types_and_error_recovery`・`higher_kinded_instantiation_and_equatable_declaration_summaries`、`typeck::effects::tests::declared_operation_bounds_are_available_in_clauses`、`typeck::traits::tests::builtin_parameter_bounds_and_strength` である。3 ファイルの期待する列・開始の字句だけを直し、入力と診断コードを維持した。00-03「ブランチと並行作業」の「そのファイルのテスト」の範囲で、今回の診断の修正に伴う更新と判断した。型検査に関係する単体テスト 96 件は通った。

## テストの作成時の関門

既存のゴールデンテストと差分テストが、診断のコード・位置・注記・修正案、関数の値の変換、評価順序、長いリストの出力・停止を守る。修正前の失敗は前回の検査と今回の期待値更新前の検査で確認し、処理系の実装の修正で解消した。新しい公開の範囲・フラグ・差し込み口は設けず、同じ契約を繰り返す単体テストは追加しない。参照インタプリタの変換の既存の 7 単体テストも通った。E0418 の既存の単体テストは、診断が宣言の名前を指す契約を守り、関数名へ戻る退行を捕まえる。期待値だけを仕様上の列 19 に更新し、同じ検査の追加と本番の差し込み口は不要と判断した。

削除したのは、作業が指定した古いゴールデン実行器 940 行と、切り替えで役割を終えた構文の実行器 152 行である。各言語ケースの検査は C10 の実行器に引き継いだ。C10 の実行器は、オーケストレータの除外の処理を含めて 648 行から 663 行、257 行の補助モジュールは内容を維持し、CLI のテストは 7 行増えた。Rust のテストコード全体の差は 1070 行減、本番の Rust の変更ファイルの差は 127 行増である。テストのためだけの本番の API は加えなかった。通常設定の長いリストの CLI の検査は出力と非再帰の実行を守るため残した。

## 長いリストの差分検査の除外

線形にした後の `eval/list_hof_long.bnt` は、release の CLI で 5 万要素を約 0.49 秒で処理し、期待する `50000`、`0`、`1249975000` を出力した。同じケースの差分検査は 31 秒で中断した。参照インタプリタが組み込みを呼ぶたびにリスト全体を写す費用は残るため、追加指示の条件に従って、このケースだけを `EXPENSIVE_REFERENCE_CASES` に加えた。除外理由は `reference list conversion cost` である。

入力の 5 万要素と期待値は維持した。通常設定では CLI の Direct と Request の検査とコア IR の検査を残し、参照インタプリタとの照合だけを外した。上の所要時間は除外の条件を判断する検査の記録であり、言語間の性能測定は行っていない。

## GC の強制での長いリストの除外

オーケストレータが加えた `STRESS_EXCLUDED_CASES` と 07-03 の規則を維持した。`gc-stress` のビルドに限り、`eval/list_hof_long.bnt` を除き、実行器は除いた名前を表示する。通常設定の 5 万要素の CLI の検査は残る。参照インタプリタの変換の費用による差分だけの除外とは、対象の設定と検査が異なる。

`scripts/check.sh` と `scripts/check-heap.sh` は変更していない。前回の分離案 `C00-long-gc-proposal.patch` は採用していない。

## 検査の結果

最終の `scripts/check.sh` は終了コード 0 で、最後に `all checks passed` を出力した。format、両方式の lint、通常設定と GC の強制のテスト、仮置きの許可、仕様の集計の self-test、ライセンスの検査がすべて通った。テスト用の最適化レベルとスタックの大きさは変えていない。最終実行の記録は `target/c05/review-check-final.log` にある。

| 検査 | mark-sweep | 参照カウント |
|---|---|---|
| lint（heap-verify・alloc-stats） | 通過 | 通過 |
| 通常設定の単体テスト | 729 件通過 | 730 件通過 |
| 通常設定のゴールデン・ベンチマーク | 271 ケース通過 | 271 ケース通過 |
| GC の強制の単体テスト | 729 件通過 | 730 件通過 |
| GC の強制のゴールデン・ベンチマーク | 採用済みの 1 ケースの除外後、270 ケース通過 | 採用済みの 1 ケースの除外後、270 ケース通過 |
| CLI のプロセステスト | 通常・GC の強制とも通過 | 通常・GC の強制とも通過 |
| 言語リファレンス・仕様の例 | 通常・GC の強制とも通過 | 通常・GC の強制とも通過 |
| rustdoc の検査 | 通過 | 通過 |

通常設定の 271 ケースは、移した 263 ケースとベンチマークの 8 本の和である。GC の強制は `eval/list_hof_long.bnt` を除いた 262 ケースと同じ 8 本を検査し、除いた名前を実行器が表示する。通常設定では同ケースの Direct・Request とコア IR の検査を維持した。

差分の対象と集計は、今回の診断の修正前から変わっていない。各設定で 113 件が一致し、資源の不足による除外は 2 件である。通常設定では参照インタプリタのリストの変換の費用による除外が 1 件、GC の強制では同ケース自体を除くため、この理由の除外は 0 件である。`Unsupported`・`.stdin`・時計と乱数による除外は 0 件である。終了状態、スクリプトの標準出力・標準エラー出力、表に当てはまらない新しい差はない。

U2 第 1 段の完了条件のうち、テストの条件（両方式と回収の強制で通ること）も、今回の指示と 07-03 の除外の規則を適用した状態で満たした。`runtime::heap` を変更していないので、`scripts/check-heap.sh` の実行対象には当たらない。

前回に確認済みのベンチマークの `run.py --verify` は、対象の 8 本すべてが Python の出力と一致し、利用可能な比較対象の 6 設定との 48 通りの照合が通った。CPython の JIT と Rust の比較実行は、利用可能な実行器がないため飛ばした。`depth.bnt` は構文を移し、元の `.args.small` のない状態を維持した。`acceptance/hello.bnt` の `cargo run` は終了コード 0 で `Hello, world!` を出力した。今回、ベンチマークと CLI の入力は変更していない。

## 受け入れた期待値の変化

C05 の表の行ごとの全一覧である。一つのケースが複数の行に属する。パスはこのディレクトリからの相対パスであり、一覧の和集合は更新した 124 ケースに一致する。

### 診断・報告の位置とソースの抜き出し

新しい構文上の字句に合わせた。例: `types/effect_var_unused.bnt` は宣言の `E`、`types/mismatch_if_branches.bnt` は else の `1` を指す。標準ライブラリの書き直しで変わった `names/prelude_only_hidden.bnt` の補助位置のオフセットも反映した。

- acceptance: `acceptance/effect_violation.bnt`, `acceptance/nonexhaustive.bnt`, `acceptance/syntax_error.bnt`, `acceptance/type_error_check.bnt`, `acceptance/type_error_run.bnt`
- effects: `effects/choose_io_violation.bnt`, `effects/effect_var_rigid.bnt`, `effects/lambda_uses_violation.bnt`, `effects/map_with_io_pure_violation.bnt`, `effects/outermost_only.bnt`, `effects/pure_calls_io.bnt`
- eval: `eval/call_stack_limit.bnt`, `eval/div_by_zero_tail.bnt`, `eval/div_by_zero_trace.bnt`, `eval/int_overflow_abs.bnt`, `eval/int_overflow_add.bnt`, `eval/int_overflow_div.bnt`, `eval/int_overflow_floor_div.bnt`, `eval/int_overflow_mul.bnt`, `eval/int_overflow_neg.bnt`, `eval/int_overflow_sub.bnt`, `eval/trace_truncated.bnt`, `eval/value_too_large.bnt`
- io: `io/runtime_error_flushes.bnt`
- lexical: `lexical/bad_escape.bnt`, `lexical/bidi_in_comment.bnt`, `lexical/bidi_in_string.bnt`, `lexical/bom_in_middle.bnt`, `lexical/control_in_literal.bnt`, `lexical/empty_char.bnt`, `lexical/float_malformed.bnt`, `lexical/fullwidth_space.bnt`, `lexical/int_malformed.bnt`, `lexical/invalid_utf8.bnt`, `lexical/lone_cr.bnt`, `lexical/multi_char.bnt`, `lexical/nbsp_outside.bnt`, `lexical/reserved_loop.bnt`, `lexical/reserved_other.bnt`, `lexical/reserved_return.bnt`, `lexical/semicolon.bnt`, `lexical/unknown_symbol.bnt`, `lexical/unterminated_char.bnt`, `lexical/unterminated_string.bnt`
- names: `names/duplicate_ctor.bnt`, `names/duplicate_fn.bnt`, `names/duplicate_param.bnt`, `names/duplicate_pattern_var.bnt`, `names/duplicate_type.bnt`, `names/duplicate_type_param.bnt`, `names/effect_as_type.bnt`, `names/option_unwrap.bnt`, `names/prelude_only_hidden.bnt`, `names/qualified_some.bnt`, `names/string_length.bnt`, `names/type_param_toplevel.bnt`, `names/unknown_member.bnt`, `names/unknown_module.bnt`, `names/unknown_name.bnt`, `names/uses_not_effect_first.bnt`, `names/uses_not_effect_later.bnt`, `names/wrong_kind.bnt`
- patterns: `patterns/match_on_error_type.bnt`, `patterns/nonexhaustive_adt.bnt`, `patterns/nonexhaustive_literals.bnt`, `patterns/nonexhaustive_option.bnt`, `patterns/pattern_arity.bnt`, `patterns/unreachable_after_wild.bnt`, `patterns/unreachable_covering_many.bnt`
- runner: `runner/modules_basic`, `runner/run-stopped.bnt`, `runner/warning-allowed.bnt`, `runner/warning-denied.bnt`
- syntax: `syntax/brace_next_line.bnt`, `syntax/chained_comparison.bnt`, `syntax/ctor_decl_parens.bnt`, `syntax/dot_after_value.bnt`, `syntax/lambda_underscore_param.bnt`, `syntax/placeholder_misplaced.bnt`, `syntax/qualified_fn_decl.bnt`, `syntax/recovery_many.bnt`, `syntax/too_deep.bnt`, `syntax/unexpected_token.bnt`, `syntax/uses_then_bracket.bnt`
- types: `types/arity.bnt`, `types/condition_not_bool.bnt`, `types/discarded_value.bnt`, `types/duplicate_in_uses.bnt`, `types/effect_var_unused.bnt`, `types/equality_function.bnt`, `types/equality_ioerror.bnt`, `types/equality_summary.bnt`, `types/errors_across_functions.bnt`, `types/float_literal_help.bnt`, `types/float_literal_range.bnt`, `types/if_without_else_not_unit.bnt`, `types/independent_errors.bnt`, `types/infinite_type.bnt`, `types/int_literal_range.bnt`, `types/main_signature_effect.bnt`, `types/main_signature_int.bnt`, `types/main_signature_params.bnt`, `types/main_signature_result.bnt`, `types/main_signature_type_params.bnt`, `types/mismatch_call_arg.bnt`, `types/mismatch_call_arg_undetermined.bnt`, `types/mismatch_if_branches.bnt`, `types/mismatch_let_annotation.bnt`, `types/no_cascade.bnt`, `types/no_let_polymorphism.bnt`, `types/not_a_function.bnt`, `types/nullary_ctor_parens.bnt`, `types/operator_on_type_param.bnt`, `types/operator_set.bnt`, `types/rem_operands.bnt`, `types/string_plus_int.bnt`, `types/too_many_effect_vars.bnt`, `types/type_arg_count.bnt`, `types/undetermined.bnt`

### 表示名

C10 が与える `testdata/...` に合わせた。例: `runner/check-error.bnt`。ソース位置のない `runner/run-stopped.bnt` はこの区分に含めない。

- acceptance: `acceptance/effect_violation.bnt`, `acceptance/nonexhaustive.bnt`, `acceptance/syntax_error.bnt`, `acceptance/type_error_check.bnt`, `acceptance/type_error_run.bnt`
- effects: `effects/choose_example.bnt`, `effects/choose_io_violation.bnt`, `effects/effect_var_rigid.bnt`, `effects/lambda_uses_violation.bnt`, `effects/map_with_io_pure_violation.bnt`, `effects/outermost_only.bnt`, `effects/pure_calls_io.bnt`
- eval: `eval/call_stack_limit.bnt`, `eval/div_by_zero_tail.bnt`, `eval/div_by_zero_trace.bnt`, `eval/int_overflow_abs.bnt`, `eval/int_overflow_add.bnt`, `eval/int_overflow_div.bnt`, `eval/int_overflow_floor_div.bnt`, `eval/int_overflow_mul.bnt`, `eval/int_overflow_neg.bnt`, `eval/int_overflow_sub.bnt`, `eval/trace_truncated.bnt`, `eval/value_too_large.bnt`
- io: `io/runtime_error_flushes.bnt`
- lexical: `lexical/bad_escape.bnt`, `lexical/bidi_in_comment.bnt`, `lexical/bidi_in_string.bnt`, `lexical/bom_at_start.bnt`, `lexical/bom_in_middle.bnt`, `lexical/control_in_literal.bnt`, `lexical/empty_char.bnt`, `lexical/float_malformed.bnt`, `lexical/fullwidth_space.bnt`, `lexical/int_malformed.bnt`, `lexical/invalid_utf8.bnt`, `lexical/lone_cr.bnt`, `lexical/multi_char.bnt`, `lexical/nbsp_outside.bnt`, `lexical/reserved_loop.bnt`, `lexical/reserved_other.bnt`, `lexical/reserved_return.bnt`, `lexical/semicolon.bnt`, `lexical/unknown_symbol.bnt`, `lexical/unterminated_char.bnt`, `lexical/unterminated_string.bnt`
- names: `names/duplicate_ctor.bnt`, `names/duplicate_fn.bnt`, `names/duplicate_param.bnt`, `names/duplicate_pattern_var.bnt`, `names/duplicate_type.bnt`, `names/duplicate_type_param.bnt`, `names/effect_as_type.bnt`, `names/option_unwrap.bnt`, `names/prelude_only_hidden.bnt`, `names/qualified_some.bnt`, `names/string_length.bnt`, `names/type_param_toplevel.bnt`, `names/unknown_member.bnt`, `names/unknown_module.bnt`, `names/unknown_name.bnt`, `names/uses_not_effect_first.bnt`, `names/uses_not_effect_later.bnt`, `names/wrong_kind.bnt`
- patterns: `patterns/match_on_error_type.bnt`, `patterns/nonexhaustive_adt.bnt`, `patterns/nonexhaustive_literals.bnt`, `patterns/nonexhaustive_option.bnt`, `patterns/pattern_arity.bnt`, `patterns/unreachable_after_wild.bnt`, `patterns/unreachable_covering_many.bnt`
- runner: `runner/check-error.bnt`, `runner/modules_basic`, `runner/run-stopped.bnt`, `runner/warning-allowed.bnt`, `runner/warning-denied.bnt`
- syntax: `syntax/brace_next_line.bnt`, `syntax/chained_comparison.bnt`, `syntax/ctor_decl_parens.bnt`, `syntax/dot_after_value.bnt`, `syntax/lambda_underscore_param.bnt`, `syntax/placeholder_misplaced.bnt`, `syntax/qualified_fn_decl.bnt`, `syntax/recovery_many.bnt`, `syntax/too_deep.bnt`, `syntax/unexpected_token.bnt`, `syntax/uses_then_bracket.bnt`
- types: `types/arity.bnt`, `types/condition_not_bool.bnt`, `types/discarded_value.bnt`, `types/duplicate_in_uses.bnt`, `types/effect_var_unused.bnt`, `types/equality_function.bnt`, `types/equality_ioerror.bnt`, `types/equality_summary.bnt`, `types/errors_across_functions.bnt`, `types/float_literal_help.bnt`, `types/float_literal_range.bnt`, `types/if_without_else_not_unit.bnt`, `types/independent_errors.bnt`, `types/infinite_type.bnt`, `types/int_literal_range.bnt`, `types/main_signature_effect.bnt`, `types/main_signature_int.bnt`, `types/main_signature_params.bnt`, `types/main_signature_result.bnt`, `types/main_signature_type_params.bnt`, `types/mismatch_call_arg.bnt`, `types/mismatch_call_arg_undetermined.bnt`, `types/mismatch_if_branches.bnt`, `types/mismatch_let_annotation.bnt`, `types/no_cascade.bnt`, `types/no_let_polymorphism.bnt`, `types/not_a_function.bnt`, `types/nullary_ctor_parens.bnt`, `types/operator_on_type_param.bnt`, `types/operator_set.bnt`, `types/rem_operands.bnt`, `types/string_plus_int.bnt`, `types/too_many_effect_vars.bnt`, `types/type_arg_count.bnt`, `types/type_no_ctors.bnt`, `types/undetermined.bnt`

### 診断の文言・ラベル・注記・修正案

初回リリース版の型板に合わせた。例: `types/discarded_value.bnt` の `bind _ <-`、`patterns/nonexhaustive_option.bnt` の `case Option.Some(_) ->`。`types/float_literal_help.bnt` の `2.0` と `types/int_literal_range.bnt` の上下限の案内は、実装を直して保持した。E0406 は最小実行版と同じ外側の型を示す。`types/equality_summary.bnt` は `Nest[function() -> Unit]` を示し、比較できない部分の型を説明する注記を維持した。

- acceptance: `acceptance/effect_violation.bnt`, `acceptance/nonexhaustive.bnt`, `acceptance/syntax_error.bnt`, `acceptance/type_error_check.bnt`, `acceptance/type_error_run.bnt`
- effects: `effects/choose_io_violation.bnt`, `effects/effect_var_rigid.bnt`, `effects/lambda_uses_violation.bnt`, `effects/map_with_io_pure_violation.bnt`, `effects/outermost_only.bnt`, `effects/pure_calls_io.bnt`
- eval: `eval/call_stack_limit.bnt`
- lexical: `lexical/float_malformed.bnt`, `lexical/int_malformed.bnt`, `lexical/unknown_symbol.bnt`, `lexical/unterminated_string.bnt`
- names: `names/duplicate_fn.bnt`, `names/duplicate_type.bnt`, `names/effect_as_type.bnt`, `names/option_unwrap.bnt`, `names/prelude_only_hidden.bnt`, `names/string_length.bnt`, `names/type_param_toplevel.bnt`, `names/unknown_member.bnt`, `names/unknown_module.bnt`, `names/uses_not_effect_first.bnt`, `names/uses_not_effect_later.bnt`, `names/wrong_kind.bnt`
- patterns: `patterns/match_on_error_type.bnt`, `patterns/nonexhaustive_adt.bnt`, `patterns/nonexhaustive_literals.bnt`, `patterns/nonexhaustive_option.bnt`, `patterns/pattern_arity.bnt`, `patterns/unreachable_after_wild.bnt`, `patterns/unreachable_covering_many.bnt`
- syntax: `syntax/chained_comparison.bnt`, `syntax/dot_after_value.bnt`, `syntax/uses_then_bracket.bnt`
- types: `types/condition_not_bool.bnt`, `types/discarded_value.bnt`, `types/duplicate_in_uses.bnt`, `types/equality_function.bnt`, `types/equality_ioerror.bnt`, `types/equality_summary.bnt`, `types/errors_across_functions.bnt`, `types/float_literal_help.bnt`, `types/if_without_else_not_unit.bnt`, `types/independent_errors.bnt`, `types/int_literal_range.bnt`, `types/main_signature_effect.bnt`, `types/mismatch_call_arg.bnt`, `types/mismatch_call_arg_undetermined.bnt`, `types/mismatch_if_branches.bnt`, `types/mismatch_let_annotation.bnt`, `types/missing_main.bnt`, `types/no_cascade.bnt`, `types/no_let_polymorphism.bnt`, `types/not_a_function.bnt`, `types/nullary_ctor_parens.bnt`, `types/operator_on_type_param.bnt`, `types/operator_set.bnt`, `types/rem_operands.bnt`, `types/string_plus_int.bnt`, `types/type_arg_count.bnt`

### 診断コード

`names/prelude_only_hidden.bnt` は非公開の mapFrom なので E0330 と補助位置 declared にした。標準ライブラリへの make_public の修正案はない。`names/wrong_kind.bnt` は修飾していない構築子の E0331、`lexical/unknown_symbol.bnt` の ? は E0211、`types/type_arg_count.bnt` の型引数がない List は E0426 にした。いずれも改めた C05 の表の条件に当たる。

- lexical: `lexical/unknown_symbol.bnt`
- names: `names/prelude_only_hidden.bnt`, `names/wrong_kind.bnt`
- types: `types/type_arg_count.bnt`

### 警告の追加

`effects/choose_example.bnt` と `effects/outermost_only.bnt` の広すぎる IO.All に W0501 を加えた。後者の純粋な関数には削除を示す修正案を付ける。整数溢れ 7 件の W0402、ゼロ除算 2 件の W0401 も加え、元の実行時エラーと終了状態を維持した。

- effects: `effects/choose_example.bnt`, `effects/outermost_only.bnt`
- eval: `eval/int_overflow_abs.bnt`, `eval/int_overflow_add.bnt`, `eval/int_overflow_div.bnt`, `eval/int_overflow_floor_div.bnt`, `eval/int_overflow_mul.bnt`, `eval/int_overflow_neg.bnt`, `eval/int_overflow_sub.bnt`, `eval/trace_truncated.bnt`
- io: `io/runtime_error_flushes.bnt`

### JSON・文章の形式

helps を message と edits を持つオブジェクトにし、履歴を持つ報告に taskOrigins を加えた。例: `acceptance/type_error_check.bnt` と `eval/div_by_zero_trace.bnt`。文章の期待値 7 件には新しい位置と文言を反映した。Unicode の版の行は cli_process で確かめる。more errors から more diagnostics への変更を要するケースはなかった。

- acceptance: `acceptance/effect_violation.bnt`, `acceptance/nonexhaustive.bnt`, `acceptance/type_error_check.bnt`, `acceptance/type_error_run.bnt`
- effects: `effects/choose_io_violation.bnt`, `effects/map_with_io_pure_violation.bnt`, `effects/pure_calls_io.bnt`
- eval: `eval/call_stack_limit.bnt`, `eval/div_by_zero_tail.bnt`, `eval/div_by_zero_trace.bnt`, `eval/int_overflow_abs.bnt`, `eval/int_overflow_add.bnt`, `eval/int_overflow_div.bnt`, `eval/int_overflow_floor_div.bnt`, `eval/int_overflow_mul.bnt`, `eval/int_overflow_neg.bnt`, `eval/int_overflow_sub.bnt`, `eval/trace_truncated.bnt`, `eval/value_too_large.bnt`
- io: `io/runtime_error_flushes.bnt`
- lexical: `lexical/bidi_in_string.bnt`, `lexical/control_in_literal.bnt`, `lexical/multi_char.bnt`, `lexical/semicolon.bnt`, `lexical/unterminated_string.bnt`
- names: `names/effect_as_type.bnt`, `names/option_unwrap.bnt`, `names/string_length.bnt`, `names/unknown_member.bnt`, `names/unknown_module.bnt`, `names/unknown_name.bnt`, `names/uses_not_effect_later.bnt`, `names/wrong_kind.bnt`
- patterns: `patterns/nonexhaustive_adt.bnt`, `patterns/nonexhaustive_literals.bnt`, `patterns/nonexhaustive_option.bnt`
- syntax: `syntax/chained_comparison.bnt`, `syntax/ctor_decl_parens.bnt`, `syntax/dot_after_value.bnt`, `syntax/lambda_underscore_param.bnt`, `syntax/qualified_fn_decl.bnt`, `syntax/uses_then_bracket.bnt`
- types: `types/discarded_value.bnt`, `types/float_literal_help.bnt`, `types/missing_main.bnt`, `types/nullary_ctor_parens.bnt`, `types/string_plus_int.bnt`, `types/type_no_ctors.bnt`, `types/undetermined.bnt`

### 呼び出しの履歴の段

直接呼んだ組み込みの段を除いた。例: `eval/int_overflow_abs.bnt`。List.map が mapFrom への末尾呼び出しで去る段も除いた。`eval/call_stack_limit.bnt` は活動中の呼び出しが 204 から 227、省いた段が 184 から 207 になった。同じ停止の種類と主な位置を維持した。

- eval: `eval/call_stack_limit.bnt`, `eval/div_by_zero_tail.bnt`, `eval/div_by_zero_trace.bnt`, `eval/int_overflow_abs.bnt`, `eval/int_overflow_floor_div.bnt`, `eval/value_too_large.bnt`

### 関数・型・エフェクトの名前

Integer・Boolean・Character・IOError・Console.Write・function などの初回リリース版の名前にした。例: `types/condition_not_bool.bnt` と `effects/pure_calls_io.bnt`。Benitoite.String の表示名は今回の追加指示で受け入れた。

- acceptance: `acceptance/effect_violation.bnt`, `acceptance/type_error_check.bnt`, `acceptance/type_error_run.bnt`
- effects: `effects/choose_io_violation.bnt`, `effects/effect_var_rigid.bnt`, `effects/lambda_uses_violation.bnt`, `effects/map_with_io_pure_violation.bnt`, `effects/outermost_only.bnt`, `effects/pure_calls_io.bnt`
- names: `names/effect_as_type.bnt`, `names/uses_not_effect_first.bnt`, `names/uses_not_effect_later.bnt`, `names/prelude_only_hidden.bnt`, `names/option_unwrap.bnt`, `names/unknown_member.bnt`
- patterns: `patterns/match_on_error_type.bnt`, `patterns/nonexhaustive_option.bnt`
- types: `types/condition_not_bool.bnt`, `types/discarded_value.bnt`, `types/duplicate_in_uses.bnt`, `types/equality_function.bnt`, `types/equality_ioerror.bnt`, `types/equality_summary.bnt`, `types/errors_across_functions.bnt`, `types/float_literal_help.bnt`, `types/if_without_else_not_unit.bnt`, `types/independent_errors.bnt`, `types/int_literal_range.bnt`, `types/mismatch_call_arg.bnt`, `types/mismatch_call_arg_undetermined.bnt`, `types/mismatch_if_branches.bnt`, `types/mismatch_let_annotation.bnt`, `types/no_cascade.bnt`, `types/no_let_polymorphism.bnt`, `types/not_a_function.bnt`, `types/operator_set.bnt`, `types/rem_operands.bnt`, `types/string_plus_int.bnt`, `types/nullary_ctor_parens.bnt`
- eval: `eval/div_by_zero_tail.bnt`, `eval/div_by_zero_trace.bnt`

### 報告の数

`syntax/brace_next_line.bnt` は、開始の { に加えて、閉じる } の E0212 も報告する。字句に使えない記号の診断を抑えない現行の規則と、改めた C05 の表で説明できる。警告による増加は「警告の追加」に挙げた。派生した診断の削減として更新したケースはない。

- syntax: `syntax/brace_next_line.bnt`

文章の期待値を更新した 7 ケースは `acceptance/syntax_error.bnt`、`acceptance/type_error_check.bnt`、`acceptance/type_error_run.bnt`、`lexical/fullwidth_space.bnt`、`names/duplicate_type.bnt`、`runner/check-error.bnt`、`syntax/unexpected_token.bnt` である。

## 残したこと

今回の診断の修正に伴う単体テストの更新は、00-03「ブランチと並行作業」の「そのファイルのテスト」の範囲と判断した。追加したテスト、公開 API、フラグはない。取り込み済みの 10 ファイルの参照の変更と、オーケストレータの GC の強制の除外の変更は維持した。

`eval/list_hof_long.bnt` の GC の強制と参照インタプリタとの差分は、上に記した規則と追加指示で除外する。通常設定の CLI の検査、5 万要素の入力、期待値は維持した。`names/string_length.bnt` などの `Benitoite.String` の表示は今回受け入れ、後の見直しに残す。

`git diff --check` は `lexical/crlf_ok.bnt` の CRLF と `lexical/lone_cr.bnt` の単独 CR を末尾の空白として報告する。この 2 ケースの改行は検査の入力なので、C03 が置いたバイト列を維持した。凍結した型と公開のシグネチャ、`runtime::heap` は変更していない。unsafe の追加は 0 個であり、コミットはしていない。
