# 試行 T の読者の分類

基準は `a26ed29afaeb444325da1daf362d9fe7ad12b18b` である。計画の検索語 `Ty::Con` は `ITy::Con` も含む。同じファイル・行・桁を一出現、同じファイル・関数名・定義開始行を一宣言として数える。宣言の行はその宣言の開始位置である。

「機械」は既存の構築の明示の Top と、分類・子だけの走査のパターンの引数追加である。「意味」は添字を保持・比較・表示する処理と、旧版への書き出しの拒否を要する処理である。コメントは別に数える。意味の分類は対象宣言全体に付ける。

初回の診断の位置は 正規化した相対パスで照合する。列挙した診断がない読者は検査済みとはしない。lib/lib test の失敗のため、独立した全統合ターゲットと examples の検査はまだ閉じていない。`tests/desugar_export` の3ファイル13出現はlib testにも含まれ、初回診断がある。残る5ファイル20出現と examples 3ファイル4出現は初回の下流で未検査である。

| 対象 | ファイル | 出現 | 宣言 | 機械 | 意味 | 注記 | 初回診断ありの出現 |
|---|---:|---:|---:|---:|---:|---:|---:|
| src | 51 | 288 | 179 | 235 | 52 | 1 | 265 |
| tests | 8 | 33 | 21 | 24 | 9 | 0 | 13 |
| examples | 3 | 4 | 4 | 3 | 1 | 0 | 0 |

src は51ファイル288箇所、tests は8ファイル33箇所であり計画と一致する。examples の3ファイル4箇所を追加して数えた。src のうち1箇所は代入の説明コメントである。

初回の一意の診断は281件・54ファイルである。E0023が153件、E0061が126件、二次的なE0614が2件である。libは196件、lib testは281件で失敗した。二重に表示されたlibの診断を足さない。

## ファイルごとの分類

| ファイル（crates/benitoite/ 起点） | 出現 | 宣言 | 機械 | 意味 | 注記 | 診断のない出現 |
|---|---:|---:|---:|---:|---:|---:|
| `examples/derive_inventory/mod.rs` | 1 | 1 | 1 | 0 | 0 | 1 |
| `examples/derive_inventory/schema.rs` | 2 | 2 | 1 | 1 | 0 | 2 |
| `examples/try_actions_inventory.rs` | 1 | 1 | 1 | 0 | 0 | 1 |
| `src/builtins/table.rs` | 4 | 3 | 4 | 0 | 0 | 0 |
| `src/bytecode/codegen/emit.rs` | 4 | 3 | 4 | 0 | 0 | 0 |
| `src/bytecode/codegen/tests.rs` | 5 | 4 | 5 | 0 | 0 | 0 |
| `src/cli/tools/test_runner/docs/prepare.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/cli/tools/test_runner/mod.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/external/check.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/external/expansion.rs` | 3 | 2 | 3 | 0 | 0 | 0 |
| `src/external/tests.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/external/types.rs` | 17 | 5 | 11 | 6 | 0 | 2 |
| `src/ir/check.rs` | 37 | 17 | 36 | 1 | 0 | 6 |
| `src/ir/core_ir.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/ir/decision.rs` | 10 | 6 | 10 | 0 | 0 | 0 |
| `src/ir/decision/arena.rs` | 1 | 1 | 0 | 1 | 0 | 0 |
| `src/ir/decision/rows.rs` | 2 | 1 | 2 | 0 | 0 | 0 |
| `src/ir/desugar.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/ir/desugar/decls.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/ir/desugar/die_tests.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/ir/desugar/effects.rs` | 3 | 3 | 3 | 0 | 0 | 0 |
| `src/ir/desugar/exprs.rs` | 6 | 5 | 6 | 0 | 0 | 2 |
| `src/ir/desugar/tests.rs` | 2 | 2 | 2 | 0 | 0 | 0 |
| `src/runtime/assert.rs` | 5 | 4 | 3 | 2 | 0 | 0 |
| `src/runtime/assert/tests.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/builders.rs` | 2 | 1 | 2 | 0 | 0 | 0 |
| `src/typeck/calls.rs` | 9 | 5 | 9 | 0 | 0 | 7 |
| `src/typeck/consts.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/context.rs` | 5 | 3 | 3 | 2 | 0 | 0 |
| `src/typeck/decls.rs` | 15 | 11 | 15 | 0 | 0 | 1 |
| `src/typeck/effects/mod.rs` | 2 | 2 | 2 | 0 | 0 | 0 |
| `src/typeck/effects/special.rs` | 8 | 2 | 8 | 0 | 0 | 1 |
| `src/typeck/effects/tests.rs` | 4 | 4 | 4 | 0 | 0 | 0 |
| `src/typeck/external.rs` | 2 | 2 | 2 | 0 | 0 | 0 |
| `src/typeck/generate.rs` | 2 | 2 | 2 | 0 | 0 | 0 |
| `src/typeck/interval/discovery.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/interval/domain.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/interval/fixed_domain.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/interval/flow/independent.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/interval/flow/range/tables_tests.rs` | 2 | 1 | 2 | 0 | 0 | 0 |
| `src/typeck/limits.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/pattern_ext.rs` | 3 | 2 | 3 | 0 | 0 | 0 |
| `src/typeck/patterns.rs` | 17 | 9 | 17 | 0 | 0 | 1 |
| `src/typeck/solve.rs` | 38 | 19 | 21 | 17 | 0 | 1 |
| `src/typeck/solve/effect_key.rs` | 1 | 1 | 0 | 1 | 0 | 0 |
| `src/typeck/solve/provenance.rs` | 18 | 10 | 6 | 12 | 0 | 1 |
| `src/typeck/tests.rs` | 7 | 6 | 7 | 0 | 0 | 0 |
| `src/typeck/tests/interpolation_formats.rs` | 1 | 1 | 1 | 0 | 0 | 0 |
| `src/typeck/traits/collect.rs` | 2 | 2 | 2 | 0 | 0 | 0 |
| `src/typeck/traits/impls.rs` | 2 | 2 | 2 | 0 | 0 | 0 |
| `src/typeck/traits/solve.rs` | 12 | 8 | 6 | 6 | 0 | 0 |
| `src/typeck/traits/tests.rs` | 5 | 3 | 5 | 0 | 0 | 0 |
| `src/types/mod.rs` | 14 | 10 | 9 | 4 | 1 | 1 |
| `src/vm/builder_tests.rs` | 3 | 2 | 3 | 0 | 0 | 0 |
| `tests/coverage_export.rs` | 12 | 6 | 6 | 6 | 0 | 12 |
| `tests/desugar_export.rs` | 3 | 3 | 3 | 0 | 0 | 3 |
| `tests/desugar_export/builtins.rs` | 3 | 2 | 1 | 2 | 0 | 0 |
| `tests/desugar_export/exchange.rs` | 8 | 5 | 7 | 1 | 0 | 0 |
| `tests/desugar_export/lib.rs` | 2 | 1 | 2 | 0 | 0 | 0 |
| `tests/desugar_export/named.rs` | 1 | 1 | 1 | 0 | 0 | 1 |
| `tests/named_arguments.rs` | 3 | 2 | 3 | 0 | 0 | 3 |
| `tests/runtime_builtins.rs` | 1 | 1 | 1 | 0 | 0 | 1 |

## 宣言ごとの分類

| ファイル・宣言 | 出現 | 分類 | 診断のない位置 |
|---|---:|---|---|
| `examples/derive_inventory/mod.rs::dependencies:113` | 1 | 機械 | 115:13 |
| `examples/derive_inventory/schema.rs::declaration_tables:211` | 1 | 機械 | 285:26 |
| `examples/derive_inventory/schema.rs::ty:51` | 1 | 意味 | 53:13 |
| `examples/try_actions_inventory.rs::inventory:91` | 1 | 機械 | 301:21 |
| `src/builtins/table.rs::basic:893` | 1 | 機械 | — |
| `src/builtins/table.rs::builtin_scheme:767` | 2 | 機械 | — |
| `src/builtins/table.rs::internal_lookup_functions_supply_the_language_types_and_intrinsics:1199` | 1 | 機械 | — |
| `src/bytecode/codegen/emit.rs::app:266` | 1 | 機械 | — |
| `src/bytecode/codegen/emit.rs::const_ty:1653` | 1 | 機械 | — |
| `src/bytecode/codegen/emit.rs::equality:658` | 2 | 機械 | — |
| `src/bytecode/codegen/tests.rs::builtin_value_prototypes_respect_type_dependent_instructions:945` | 1 | 機械 | — |
| `src/bytecode/codegen/tests.rs::fill:1027` | 1 | 機械 | — |
| `src/bytecode/codegen/tests.rs::malformed_length_cases_are_internal_errors:1097` | 2 | 機械 | — |
| `src/bytecode/codegen/tests.rs::over_limit_program:864` | 1 | 機械 | — |
| `src/cli/tools/test_runner/docs/prepare.rs::prepare_examples:9` | 1 | 機械 | — |
| `src/cli/tools/test_runner/mod.rs::collect_tests:312` | 1 | 機械 | — |
| `src/external/check.rs::user_type_note:751` | 1 | 機械 | — |
| `src/external/expansion.rs::check_dependencies:169` | 1 | 機械 | — |
| `src/external/expansion.rs::walk:66` | 2 | 機械 | — |
| `src/external/tests.rs::declaration_plan_checks_dependencies_and_record_fields:1250` | 1 | 機械 | — |
| `src/external/types.rs::build:191` | 8 | 機械 | 276:9 |
| `src/external/types.rs::is_unit:8` | 1 | 機械 | — |
| `src/external/types.rs::plan:46` | 1 | 機械 | — |
| `src/external/types.rs::scalar:124` | 1 | 機械 | — |
| `src/external/types.rs::validate:169` | 6 | 意味 | 186:9 |
| `src/ir/check.rs::application:885` | 1 | 機械 | 909:13 |
| `src/ir/check.rs::builtin:146` | 1 | 機械 | — |
| `src/ir/check.rs::constrained_top_functions_check_equality_key_and_declaration_summaries:3542` | 4 | 機械 | — |
| `src/ir/check.rs::dictionary_program:2729` | 7 | 機械 | — |
| `src/ir/check.rs::dictionary_types_supertraits_scope_and_method_contracts:3063` | 2 | 機械 | — |
| `src/ir/check.rs::higher_kinded_dictionaries_substitute_constructor_heads:3135` | 2 | 機械 | — |
| `src/ir/check.rs::lambda:601` | 1 | 機械 | — |
| `src/ir/check.rs::list:630` | 2 | 機械 | 635:13 |
| `src/ir/check.rs::method:1115` | 1 | 機械 | 1148:13 |
| `src/ir/check.rs::pattern:1525` | 5 | 機械 | 1532:21, 1560:17, 1594:17 |
| `src/ir/check.rs::pattern_alternatives_ranges_lists_and_guards:3340` | 1 | 機械 | — |
| `src/ir/check.rs::reports_require_canonical_exit_one_and_checked_strings:4103` | 2 | 機械 | — |
| `src/ir/check.rs::rigid_scope:565` | 1 | 機械 | — |
| `src/ir/check.rs::satisfies:435` | 4 | 機械 | — |
| `src/ir/check.rs::use_comp:927` | 1 | 機械 | — |
| `src/ir/check.rs::valid_contracts:175` | 1 | 意味 | — |
| `src/ir/check.rs::value:481` | 1 | 機械 | — |
| `src/ir/core_ir.rs::contents:292` | 1 | 機械 | — |
| `src/ir/decision.rs::adt_ty:1917` | 1 | 機械 | — |
| `src/ir/decision.rs::build_tree:894` | 5 | 機械 | — |
| `src/ir/decision.rs::builtin_ty:114` | 1 | 機械 | — |
| `src/ir/decision.rs::copied_guards_renew_lambda_lazy_handle_and_clause_body_ids:3454` | 1 | 機械 | — |
| `src/ir/decision.rs::list_ty:1914` | 1 | 機械 | — |
| `src/ir/decision.rs::non_match_nodes_metadata_methods_constants_and_nested_bodies_are_preserved:3625` | 1 | 機械 | — |
| `src/ir/decision/arena.rs::ty_bytes:393` | 1 | 意味 | — |
| `src/ir/decision/rows.rs::row_plan:245` | 2 | 機械 | — |
| `src/ir/desugar.rs::basic:63` | 1 | 機械 | — |
| `src/ir/desugar/decls.rs::implementation:380` | 1 | 機械 | — |
| `src/ir/desugar/die_tests.rs::ty:25` | 1 | 機械 | — |
| `src/ir/desugar/effects.rs::finish_try:31` | 1 | 機械 | — |
| `src/ir/desugar/effects.rs::lazy:294` | 1 | 機械 | — |
| `src/ir/desugar/effects.rs::try_expr:14` | 1 | 機械 | — |
| `src/ir/desugar/exprs.rs::basic_id:1284` | 2 | 機械 | — |
| `src/ir/desugar/exprs.rs::lambda:678` | 1 | 機械 | 710:21 |
| `src/ir/desugar/exprs.rs::list:942` | 1 | 機械 | — |
| `src/ir/desugar/exprs.rs::placeholder:425` | 1 | 機械 | 482:21 |
| `src/ir/desugar/exprs.rs::record:1082` | 1 | 機械 | — |
| `src/ir/desugar/tests.rs::operators_choose_intrinsics_and_negative_literals_keep_checked_values:334` | 1 | 機械 | — |
| `src/ir/desugar/tests.rs::with_nested_releases_lazy_and_annotated_lambdas:811` | 1 | 機械 | — |
| `src/runtime/assert.rs::fits:819` | 1 | 機械 | — |
| `src/runtime/assert.rs::has_params:955` | 1 | 機械 | — |
| `src/runtime/assert.rs::render_typed:1000` | 1 | 機械 | — |
| `src/runtime/assert.rs::substitute:964` | 2 | 意味 | — |
| `src/runtime/assert/tests.rs::width_immediates_render_with_and_without_static_types:160` | 1 | 機械 | — |
| `src/typeck/builders.rs::operation:44` | 2 | 機械 | — |
| `src/typeck/calls.rs::builder:630` | 4 | 機械 | 721:19, 727:13 |
| `src/typeck/calls.rs::generate:156` | 2 | 機械 | 258:19, 264:13 |
| `src/typeck/calls.rs::prepare:60` | 1 | 機械 | 79:9 |
| `src/typeck/calls.rs::ready:115` | 1 | 機械 | 123:9 |
| `src/typeck/calls.rs::resolve_arguments:350` | 1 | 機械 | 566:11 |
| `src/typeck/consts.rs::contains_param:167` | 1 | 機械 | — |
| `src/typeck/context.rs::name_rigid_types:337` | 1 | 機械 | — |
| `src/typeck/context.rs::qualified_type_names:226` | 2 | 機械 | — |
| `src/typeck/context.rs::substitute:802` | 2 | 意味 | — |
| `src/typeck/decls.rs::basic:61` | 1 | 機械 | — |
| `src/typeck/decls.rs::check_declarations:943` | 2 | 機械 | — |
| `src/typeck/decls.rs::contains_prelude_type:239` | 1 | 機械 | — |
| `src/typeck/decls.rs::has_effect:813` | 1 | 機械 | — |
| `src/typeck/decls.rs::has_param:826` | 1 | 機械 | — |
| `src/typeck/decls.rs::named:492` | 1 | 機械 | — |
| `src/typeck/decls.rs::prelude_type_in:221` | 1 | 機械 | — |
| `src/typeck/decls.rs::push_type_children:265` | 1 | 機械 | — |
| `src/typeck/decls.rs::returns_result:1269` | 2 | 機械 | 1277:9 |
| `src/typeck/decls.rs::summary:1374` | 3 | 機械 | — |
| `src/typeck/decls.rs::unit:57` | 1 | 機械 | — |
| `src/typeck/effects/mod.rs::lazy_expr:62` | 1 | 機械 | — |
| `src/typeck/effects/mod.rs::try_expr:75` | 1 | 機械 | — |
| `src/typeck/effects/special.rs::solve:11` | 1 | 機械 | — |
| `src/typeck/effects/special.rs::solve_try:101` | 7 | 機械 | 129:11 |
| `src/typeck/effects/tests.rs::basic:34` | 1 | 機械 | — |
| `src/typeck/effects/tests.rs::lazy_resources_and_taskgroup_placement:430` | 1 | 機械 | — |
| `src/typeck/effects/tests.rs::specification_examples_and_output_tables:125` | 1 | 機械 | — |
| `src/typeck/effects/tests.rs::try_infers_return_types_and_reports_incompatible_types:481` | 1 | 機械 | — |
| `src/typeck/external.rs::contains_external:74` | 1 | 機械 | — |
| `src/typeck/external.rs::is_unit:95` | 1 | 機械 | — |
| `src/typeck/generate.rs::basic:15` | 1 | 機械 | — |
| `src/typeck/generate.rs::list:1201` | 1 | 機械 | — |
| `src/typeck/interval/discovery.rs::interpolation:337` | 1 | 機械 | — |
| `src/typeck/interval/domain.rs::of_type:44` | 1 | 機械 | — |
| `src/typeck/interval/fixed_domain.rs::matches:34` | 1 | 機械 | — |
| `src/typeck/interval/flow/independent.rs::unknown_interpolation:306` | 1 | 機械 | — |
| `src/typeck/interval/flow/range/tables_tests.rs::shift_tables_identify_all_resolved_declarations_and_lean_contracts:19` | 2 | 機械 | — |
| `src/typeck/limits.rs::substituted:65` | 1 | 機械 | — |
| `src/typeck/pattern_ext.rs::pattern:13` | 1 | 機械 | — |
| `src/typeck/pattern_ext.rs::range_and_list_outputs_feed_lowering:1111` | 2 | 機械 | — |
| `src/typeck/patterns.rs::boolean_record:2135` | 1 | 機械 | — |
| `src/typeck/patterns.rs::builtin:1290` | 1 | 機械 | — |
| `src/typeck/patterns.rs::check_match_diagnostic:283` | 1 | 機械 | — |
| `src/typeck/patterns.rs::extensible_shapes_require_catchalls_in_nested_source_patterns:1830` | 3 | 機械 | — |
| `src/typeck/patterns.rs::inconsistent_constructor_matrices_remain_useful:1601` | 1 | 機械 | — |
| `src/typeck/patterns.rs::key_cost:210` | 1 | 機械 | — |
| `src/typeck/patterns.rs::lists_distinguish_exact_lengths_and_front_back_alignment:1654` | 1 | 機械 | — |
| `src/typeck/patterns.rs::option:1740` | 1 | 機械 | — |
| `src/typeck/patterns.rs::shapes:523` | 7 | 機械 | 662:9 |
| `src/typeck/solve.rs::bound_failure:1913` | 1 | 機械 | — |
| `src/typeck/solve.rs::bounds:1715` | 3 | 機械 | — |
| `src/typeck/solve.rs::contains_float:1885` | 3 | 機械 | — |
| `src/typeck/solve.rs::contract_difference:995` | 2 | 機械 | — |
| `src/typeck/solve.rs::diagnostic_type:962` | 3 | 意味 | — |
| `src/typeck/solve.rs::equal_with_outer:695` | 4 | 意味 | — |
| `src/typeck/solve.rs::failure_mentions_row:2040` | 1 | 機械 | — |
| `src/typeck/solve.rs::finalize_failure_type_normalized:535` | 3 | 意味 | — |
| `src/typeck/solve.rs::finalize_zonked:487` | 3 | 意味 | — |
| `src/typeck/solve.rs::format_diagnostic:1982` | 1 | 機械 | — |
| `src/typeck/solve.rs::fresh_head:224` | 1 | 機械 | 227:13 |
| `src/typeck/solve.rs::has_error:2383` | 1 | 機械 | — |
| `src/typeck/solve.rs::invalid_contract:457` | 1 | 機械 | — |
| `src/typeck/solve.rs::occurs:597` | 1 | 機械 | — |
| `src/typeck/solve.rs::poison:929` | 1 | 機械 | — |
| `src/typeck/solve.rs::render_failure:1038` | 3 | 機械 | — |
| `src/typeck/solve.rs::restrict_clauses:638` | 1 | 機械 | — |
| `src/typeck/solve.rs::unresolved_type:572` | 1 | 機械 | — |
| `src/typeck/solve.rs::zonk_checked:282` | 4 | 意味 | — |
| `src/typeck/solve/effect_key.rs::new:115` | 1 | 意味 | — |
| `src/typeck/solve/provenance.rs::build_value:162` | 4 | 意味 | — |
| `src/typeck/solve/provenance.rs::has_recovery:751` | 1 | 機械 | — |
| `src/typeck/solve/provenance.rs::intrinsic_type:688` | 1 | 機械 | — |
| `src/typeck/solve/provenance.rs::known_mismatch:528` | 2 | 意味 | — |
| `src/typeck/solve/provenance.rs::known_value_part:270` | 2 | 機械 | 305:23 |
| `src/typeck/solve/provenance.rs::provenance_failure:803` | 2 | 意味 | — |
| `src/typeck/solve/provenance.rs::provisional_dependency:775` | 1 | 機械 | — |
| `src/typeck/solve/provenance.rs::record_provenance:639` | 2 | 意味 | — |
| `src/typeck/solve/provenance.rs::recovered_type:726` | 2 | 意味 | — |
| `src/typeck/solve/provenance.rs::uses_marked:492` | 1 | 機械 | — |
| `src/typeck/tests.rs::contracts_come_from_declarations_and_written_lambda_parameters:1896` | 2 | 機械 | — |
| `src/typeck/tests.rs::higher_kinded_instantiation_and_equatable_declaration_summaries:1210` | 1 | 機械 | — |
| `src/typeck/tests.rs::records_aliases_constants_and_output_tables:332` | 1 | 機械 | — |
| `src/typeck/tests.rs::width_integer_division_waits_for_operands_and_defaults_unconstrained_lambdas:1666` | 1 | 機械 | — |
| `src/typeck/tests.rs::width_integer_literals_check_both_boundaries_and_record_exact_values:1507` | 1 | 機械 | — |
| `src/typeck/tests.rs::width_literals_keep_their_exact_types_and_values:1443` | 1 | 機械 | — |
| `src/typeck/tests/interpolation_formats.rs::format_type_matrix_and_locations:8` | 1 | 機械 | — |
| `src/typeck/traits/collect.rs::collect_impl:208` | 1 | 機械 | — |
| `src/typeck/traits/collect.rs::has_param:341` | 1 | 機械 | — |
| `src/typeck/traits/impls.rs::check_shape:184` | 1 | 機械 | — |
| `src/typeck/traits/impls.rs::target_ty:29` | 1 | 機械 | — |
| `src/typeck/traits/solve.rs::argument_ty:535` | 1 | 機械 | — |
| `src/typeck/traits/solve.rs::charge_type:283` | 1 | 機械 | — |
| `src/typeck/traits/solve.rs::finalize_normalized:303` | 3 | 意味 | — |
| `src/typeck/traits/solve.rs::report:556` | 1 | 機械 | — |
| `src/typeck/traits/solve.rs::resolve:81` | 1 | 機械 | — |
| `src/typeck/traits/solve.rs::resolve_normalized:118` | 3 | 意味 | — |
| `src/typeck/traits/solve.rs::target_con:22` | 1 | 機械 | — |
| `src/typeck/traits/solve.rs::unresolved_argument:390` | 1 | 機械 | — |
| `src/typeck/traits/tests.rs::higher_kinded_methods_select_heads_and_keep_method_arguments:344` | 2 | 機械 | — |
| `src/typeck/traits/tests.rs::permuted_implementation_arguments_and_method_dictionaries_keep_their_order:721` | 2 | 機械 | — |
| `src/typeck/traits/tests.rs::show_example_records_nested_dictionaries_and_method_values:280` | 1 | 機械 | — |
| `src/types/mod.rs::constructor_fields_are_instantiated_and_missing_entries_return_none:1171` | 2 | 機械 | — |
| `src/types/mod.rs::contains:566` | 1 | 注記 | 574:52 |
| `src/types/mod.rs::failure_rows_valid:622` | 1 | 機械 | — |
| `src/types/mod.rs::integer:858` | 1 | 機械 | — |
| `src/types/mod.rs::show_ty:716` | 1 | 意味 | — |
| `src/types/mod.rs::signature_no_fail:251` | 1 | 機械 | — |
| `src/types/mod.rs::single_failure:603` | 1 | 機械 | — |
| `src/types/mod.rs::subst:576` | 3 | 意味 | — |
| `src/types/mod.rs::substitution_is_simultaneous_and_preserves_unbound_parameters:1062` | 1 | 機械 | — |
| `src/types/mod.rs::width_type_display_preserves_legacy_names:864` | 2 | 機械 | — |
| `src/vm/builder_tests.rs::dedicated_builders_survive_handle_resume_drop_and_nested_bodies:101` | 2 | 機械 | — |
| `src/vm/builder_tests.rs::ty:17` | 1 | 機械 | — |
| `tests/coverage_export.rs::base:61` | 1 | 機械 | 62:5 |
| `tests/coverage_export.rs::data:64` | 1 | 機械 | 65:5 |
| `tests/coverage_export.rs::gen_pat:205` | 3 | 機械 | 211:9, 224:9, 260:9 |
| `tests/coverage_export.rs::list:67` | 1 | 機械 | 68:5 |
| `tests/coverage_export.rs::named_ty_json:734` | 3 | 意味 | 755:9, 758:9, 759:11 |
| `tests/coverage_export.rs::ty_json:269` | 3 | 意味 | 271:9, 274:9, 278:9 |
| `tests/desugar_export.rs::export_batch2_character:907` | 1 | 機械 | 949:32 |
| `tests/desugar_export.rs::write_batch2:956` | 1 | 機械 | 973:32 |
| `tests/desugar_export.rs::write_batch2_coverage:979` | 1 | 機械 | 989:31 |
| `tests/desugar_export/builtins.rs::opaque_arguments:27` | 1 | 機械 | — |
| `tests/desugar_export/builtins.rs::remap_ty:89` | 2 | 意味 | — |
| `tests/desugar_export/exchange.rs::definitions_recorded:2586` | 1 | 機械 | — |
| `tests/desugar_export/exchange.rs::expr_unlocated:1055` | 4 | 機械 | — |
| `tests/desugar_export/exchange.rs::named_class_tables:2826` | 1 | 機械 | — |
| `tests/desugar_export/exchange.rs::references:2922` | 1 | 機械 | — |
| `tests/desugar_export/exchange.rs::ty:530` | 1 | 意味 | — |
| `tests/desugar_export/lib.rs::typed_try_exchange_matches_independent_corpus_ten:35` | 2 | 機械 | — |
| `tests/desugar_export/named.rs::well_formed:348` | 1 | 機械 | 360:13 |
| `tests/named_arguments.rs::named_holes_and_pipe_insertion_keep_exact_contracts_and_causes:638` | 1 | 機械 | 795:43 |
| `tests/named_arguments.rs::nested_dictionary_arguments_wait_for_numeric_defaulting:594` | 2 | 機械 | 631:10, 633:30 |
| `tests/runtime_builtins.rs::format_all_fourteen_heads_have_fixed_contracts_and_execute:70` | 1 | 機械 | 78:22 |
