| ファイル | 機械 | 意味 | コメント | 一意の宣言 | 診断の種類 |
|---|---:|---:|---:|---:|---|
| `src/bytecode/codegen/tables.rs` | 0 | 2 | 0 | 1 | E0023 |
| `src/cli/inspection.rs` | 0 | 2 | 0 | 1 | E0023 |
| `src/ir/check.rs` | 9 | 1 | 0 | 9 | E0061 |
| `src/ir/decision.rs` | 3 | 0 | 0 | 3 | E0061 |
| `src/ir/desugar/die_tests.rs` | 1 | 0 | 0 | 1 | E0061 |
| `src/ir/desugar/effects.rs` | 1 | 0 | 0 | 1 | E0061, E0277, E0599 |
| `src/ir/desugar/tests.rs` | 1 | 0 | 0 | 1 | E0061, E0507 |
| `src/typeck/decls.rs` | 6 | 1 | 0 | 4 | E0061 |
| `src/typeck/effects/declarations.rs` | 2 | 7 | 0 | 3 | E0023, E0061, E0277, E0507, E0593, E0599 |
| `src/typeck/effects/handle.rs` | 0 | 1 | 0 | 1 | E0061 |
| `src/typeck/effects/mod.rs` | 2 | 0 | 0 | 2 | E0061 |
| `src/typeck/effects/tests.rs` | 2 | 0 | 0 | 2 | E0061 |
| `src/typeck/external.rs` | 0 | 2 | 0 | 1 | E0061 |
| `src/typeck/solve.rs` | 0 | 1 | 0 | 1 | E0023, E0204, E0507 |
| `src/typeck/tests.rs` | 3 | 0 | 0 | 1 | E0061 |
| `src/types/builtin.rs` | 0 | 0 | 1 | 1 | - |
| `src/types/mod.rs` | 4 | 4 | 0 | 4 | E0023, E0061, E0507 |
| `tests/declarations.rs` | 0 | 1 | 0 | 1 | - |
| `tests/desugar_export/builtins.rs` | 1 | 0 | 0 | 1 | E0061 |
| `tests/desugar_export/exchange.rs` | 0 | 4 | 0 | 2 | E0023 |

| ファイル／宣言 | 機械 | 意味 | 基準行（診断の種類） |
|---|---:|---:|---|
| `src/bytecode/codegen/tables.rs` / `fn operation` | 0 | 2 | 274(E0023), 279(E0023) |
| `src/cli/inspection.rs` / `fn function_contract` | 0 | 2 | 72(E0023), 94(E0023) |
| `src/ir/check.rs` / `fn continuations_are_hidden_by_lambda_and_lazy_but_visible_in_nested_handlers` | 1 | 0 | 2640(E0061) |
| `src/ir/check.rs` / `fn handle` | 0 | 1 | 1326(E0061) |
| `src/ir/check.rs` / `fn handled_effects_require_every_operation_and_never_include_state` | 1 | 0 | 3667(E0061) |
| `src/ir/check.rs` / `fn handled_program` | 1 | 0 | 2353(E0061) |
| `src/ir/check.rs` / `fn handlers_resume_and_rigid_clause_parameters` | 1 | 0 | 2565(E0061) |
| `src/ir/check.rs` / `fn op_program` | 2 | 0 | 2283(E0061), 2293(E0061) |
| `src/ir/check.rs` / `fn state` | 1 | 0 | 1675(E0061) |
| `src/ir/check.rs` / `fn use_comp` | 1 | 0 | 936(E0061) |
| `src/ir/check.rs` / `fn write` | 1 | 0 | 1665(E0061) |
| `src/ir/decision.rs` / `fn generated_nodes_have_minimal_effects_types_and_match_origins` | 1 | 0 | 3519(E0061) |
| `src/ir/decision.rs` / `fn handle` | 1 | 0 | 3282(E0061) |
| `src/ir/decision.rs` / `fn non_match_nodes_metadata_methods_constants_and_nested_bodies_are_preserved` | 1 | 0 | 3672(E0061) |
| `src/ir/desugar/die_tests.rs` / `fn die_failure_core_has_one_message_then_one_cause_and_canonical_exit` | 1 | 0 | 210(E0061) |
| `src/ir/desugar/effects.rs` / `fn state_effect` | 1 | 0 | 432(E0061) |
| `src/ir/desugar/tests.rs` / `fn with_nested_releases_lazy_and_annotated_lambdas` | 1 | 0 | 858(E0061) |
| `src/typeck/decls.rs` / `fn check_declarations` | 1 | 0 | 1183(E0061) |
| `src/typeck/decls.rs` / `fn declared_uses` | 1 | 1 | 328(E0061), 334(E0061) |
| `src/typeck/decls.rs` / `fn effect_name` | 3 | 0 | 185(E0061), 191(E0061), 194(E0061) |
| `src/typeck/decls.rs` / `fn failure_declarations` | 1 | 0 | 1420(E0061) |
| `src/typeck/effects/declarations.rs` / `fn check_body` | 1 | 1 | 216(E0061), 259(E0061) |
| `src/typeck/effects/declarations.rs` / `fn check_entries` | 1 | 4 | 107(E0593), 113(E0023), 132(E0023), 153(E0023), 153(E0023) |
| `src/typeck/effects/declarations.rs` / `fn effect_name` | 0 | 2 | 348(E0023), 400(E0023) |
| `src/typeck/effects/handle.rs` / `fn check` | 0 | 1 | 77(E0061) |
| `src/typeck/effects/mod.rs` / `fn try_expr` | 1 | 0 | 123(E0061) |
| `src/typeck/effects/mod.rs` / `fn with` | 1 | 0 | 202(E0061) |
| `src/typeck/effects/tests.rs` / `fn die_uses_standard_show_and_exit_despite_local_names_and_aliases` | 1 | 0 | 1229(E0061) |
| `src/typeck/effects/tests.rs` / `fn specification_examples_and_output_tables` | 1 | 0 | 135(E0061) |
| `src/typeck/external.rs` / `fn check` | 0 | 2 | 40(E0061), 48(E0061) |
| `src/typeck/solve.rs` / `fn solve_effects` | 0 | 1 | 2265(E0023) |
| `src/typeck/tests.rs` / `fn effect_inference_names_and_stubs` | 3 | 0 | 1017(E0061), 1023(E0061), 1030(E0061) |
| `src/types/mod.rs` / `fn function_type_display_groups_all_io_effects_and_keeps_other_effects` | 1 | 0 | 890(E0061) |
| `src/types/mod.rs` / `fn io_all_for_display` | 1 | 0 | 915(E0061) |
| `src/types/mod.rs` / `fn show_ty` | 0 | 4 | 773(E0061), 781(E0023), 786(E0023), 789(E0023) |
| `src/types/mod.rs` / `fn substitution_is_simultaneous_and_preserves_unbound_parameters` | 2 | 0 | 939(E0061), 940(E0061) |
| `tests/declarations.rs` / `fn log_standard_declarations_and_effect_identity` | 0 | 1 | 611(-) |
| `tests/desugar_export/builtins.rs` / `fn named_builtin_tables` | 1 | 0 | 298(E0061) |
| `tests/desugar_export/exchange.rs` / `fn eff` | 0 | 2 | 385(E0023), 386(E0023) |
| `tests/desugar_export/exchange.rs` / `fn named_operation_tables` | 0 | 2 | 2774(E0023), 2796(E0023) |
