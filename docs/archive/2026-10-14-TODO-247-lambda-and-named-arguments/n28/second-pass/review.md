# 名前付き引数の移行確認表

全候補は未確認である。保留のない案も、manifest の review を approved にして内容とハッシュを確認してから適用する。

| 分類 | 件数 |
|---|---:|
| held | 156 |
| proposal | 4 |

## proposal

| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |
|---|---|---|---|---|
| a61dc3da53d099a49446 | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[296, 339] | component | ['value'] |  |
| a8e06bed2110d7d81782 | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[296, 339] | component | ['value'] |  |
| 2e8091f8e2b6a41cec44 | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[296, 339] | component | ['value'] |  |
| f9ad871e942a4d55ddfa | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[296, 339] | component | ['value'] |  |

## held

| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |
|---|---|---|---|---|
| 4e357c32a18c98513ab5 | crates/benitoite/testdata/concurrency/c12-cancelled-await.bnt:[756, 827] | component | [] | negative_input_requires_diagnostic_review |
| ada75481c2d2274bc19c | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[1081, 1135] | component | ['error'] | negative_input_requires_diagnostic_review |
| a18eff948dd40fdf83b3 | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[991, 1294] | component | [] | negative_input_requires_diagnostic_review |
| ee1841f0bdc39fb916d3 | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[1056, 1136] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 1aac8ddd586aaf86cb2e | crates/benitoite/testdata/concurrency/c12-deadlock.bnt:[748, 792] | component | [] | negative_input_requires_diagnostic_review |
| e4bdb205efaa41d4fafc | crates/benitoite/testdata/concurrency/c12-group-released.bnt:[747, 799] | component | [] | negative_input_requires_diagnostic_review |
| 93f29cc173d46ad51976 | crates/benitoite/testdata/concurrency/inherited_operation_task_location.bnt:[413, 435] | component | [] | negative_input_requires_diagnostic_review |
| 1190c33cb400bc679a33 | crates/benitoite/testdata/concurrency/r41-inherited-non-tail.bnt:[374, 407] | component | [] | negative_input_requires_diagnostic_review |
| e460d12bb1ed18c62e14 | crates/benitoite/testdata/concurrency/r41-task-error.bnt:[282, 318] | component | [] | negative_input_requires_diagnostic_review |
| ef68c9f4cf92c900e77d | crates/benitoite/testdata/effects/choose_io_violation.bnt:[285, 314] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 7dd070ea46a7fd406e2b | crates/benitoite/testdata/effects/choose_io_violation.bnt:[324, 376] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| bbb9e32d0c45df4baafa | crates/benitoite/testdata/effects/effect_var_rigid.bnt:[122, 152] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f1892d57046ee049075c | crates/benitoite/testdata/effects/effect_var_rigid.bnt:[84, 109] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 4815a9b284205a23d269 | crates/benitoite/testdata/effects/effect_var_rigid.bnt:[237, 245] | call | None | callee_contract_unresolved, component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 110bbdb280c7b3c52d37 | crates/benitoite/testdata/effects/lambda_uses_violation.bnt:[119, 144] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 347010e308826aa989e2 | crates/benitoite/testdata/effects/lambda_uses_violation.bnt:[181, 267] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| d7b991016fb24e8653cb | crates/benitoite/testdata/effects/map_with_io_pure_violation.bnt:[187, 287] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 4182f28e3cc9662210a0 | crates/benitoite/testdata/effects/outermost_only.bnt:[231, 260] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c7a916a6a7f2a8b8996c | crates/benitoite/testdata/effects/r41-task-state-required.bnt:[433, 461] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 626ba7978402059ca772 | crates/benitoite/testdata/effects/r41-task-state-required.bnt:[278, 306] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| d8e23894ba00b876e165 | crates/benitoite/testdata/eval/div_by_zero_tail.bnt:[296, 355] | component | ['value'] | negative_input_requires_diagnostic_review |
| b67c0e55ebd253d63151 | crates/benitoite/testdata/eval/div_by_zero_trace.bnt:[304, 367] | component | ['value'] | negative_input_requires_diagnostic_review |
| 824625b566c5dc95d8c6 | crates/benitoite/testdata/eval/named_failure.bnt:[269, 312] | component | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 3036dce53b6b6d0ae245 | crates/benitoite/testdata/eval/named_failure.bnt:[552, 590] | call | None | callee_contract_unresolved, negative_input_requires_diagnostic_review |
| 6fbe9bebb3a434aae77e | crates/benitoite/testdata/eval/named_failure.bnt:[132, 175] | annotation | None | annotation_contract_unresolved, negative_input_requires_diagnostic_review |
| f333dc446432b6c6196e | crates/benitoite/testdata/handlers/c12-discard-reader.bnt:[934, 988] | component | ['error'] | negative_input_requires_diagnostic_review |
| c0418868aeae4acbe0a3 | crates/benitoite/testdata/handlers/c12-discard-reader.bnt:[909, 989] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| d3cb075f09d346d5661e | crates/benitoite/testdata/handlers/secf1-captured-local.bnt:[321, 345] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e5068872b16360d4166f | crates/benitoite/testdata/handlers/secf1-closure.bnt:[346, 384] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 9bff1f4296d246a9621f | crates/benitoite/testdata/handlers/secf1-closure.bnt:[413, 454] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| fe22df8fb0e263b3aa7f | crates/benitoite/testdata/handlers/secf1-deferred-alias.bnt:[342, 366] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 53e78219ec40ae9226c9 | crates/benitoite/testdata/handlers/secf1-deferred-alias.bnt:[444, 481] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 665fce32d7e96e3fa586 | crates/benitoite/testdata/handlers/secf1-early-return.bnt:[318, 468] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 9f4ae258fedd10dc3c53 | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[495, 592] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| cb8d923b1ce79a39ea44 | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[614, 663] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 4d8bd0793ffc94fac3da | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[669, 672] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 305d6c81d48ba8eaca99 | crates/benitoite/testdata/handlers/todo178-placeholder-resume-error.bnt:[406, 410] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 2a2f11513c1315f77769 | crates/benitoite/testdata/handlers/todo178-placeholder-resume-error.bnt:[562, 566] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 8c9108d302f83e26733c | crates/benitoite/testdata/handlers/todo190-guard-resume.bnt:[473, 483] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f3524aef8930711ee4a6 | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[677, 731] | component | ['error'] | negative_input_requires_diagnostic_review |
| d82fd0857f5977a7bc6f | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[652, 732] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 2f5abbc135710f868823 | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[802, 882] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 9beb73a3f15eeb85b5f3 | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[739, 793] | component | ['error'] | negative_input_requires_diagnostic_review |
| e1160e233725d528fd45 | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[714, 794] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 2da7d6b139dcb4fb9e43 | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[932, 1012] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 9d8ffcce8d9ba885af9a | crates/benitoite/testdata/io/c12-with-return-release.bnt:[650, 704] | component | ['error'] | negative_input_requires_diagnostic_review |
| 0d20f983308c5e52e344 | crates/benitoite/testdata/io/c12-with-return-release.bnt:[625, 705] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 09c8bbaba65b3a0249ef | crates/benitoite/testdata/io/c12-with-try-release.bnt:[647, 701] | component | ['error'] | negative_input_requires_diagnostic_review |
| 07abcea6b3017b586a8a | crates/benitoite/testdata/io/c12-with-try-release.bnt:[622, 702] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| ff7f4136ca441c040d56 | crates/benitoite/testdata/modules/c11-missing/main.bnt:[109, 124] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 10b26924d3a4dae2a667 | crates/benitoite/testdata/modules/c11-missing/main.bnt:[127, 143] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| ca8707e6759eb5ab71bb | crates/benitoite/testdata/modules/c11-not-reexported/main.bnt:[103, 114] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 02f9abbcb089b662c0a9 | crates/benitoite/testdata/modules/c11-private/main.bnt:[86, 98] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| dc906c21ace605acd9e4 | crates/benitoite/testdata/modules/effect_alias_references.bnt:[158, 175] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5867931242196de96723 | crates/benitoite/testdata/modules/todo177-effect-module-alias.bnt:[269, 323] | component | ['error'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c8d47264b8ec7ac5b9a2 | crates/benitoite/testdata/modules/todo177-effect-module-alias.bnt:[184, 236] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 08b919e6ff3620a6281c | crates/benitoite/testdata/modules/todo177-effect-module-alias.bnt:[244, 324] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review, pipe_requires_review |
| ccce6e53876a19eb33a5 | crates/benitoite/testdata/modules/todo177-effect-module-alias.bnt:[290, 312] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| d25155b14bf5643ec7c3 | crates/benitoite/testdata/names/alias_member.bnt:[82, 113] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| a90037dbf189928aa237 | crates/benitoite/testdata/names/alias_member.bnt:[93, 104] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 8e4b03a34da2f3bc2c2e | crates/benitoite/testdata/names/aliased_string_length.bnt:[112, 127] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| d43f40424da3bff7ae5d | crates/benitoite/testdata/names/available_members.bnt:[82, 111] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| b26656d0f513f678c065 | crates/benitoite/testdata/names/available_members.bnt:[99, 110] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 0c79a23199555eb2d060 | crates/benitoite/testdata/names/c11-lambda-hides.bnt:[87, 116] | component | ['x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 002051cea394e824e567 | crates/benitoite/testdata/names/c11-missing-import.bnt:[116, 139] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| b14c7e7f49b97bda67b9 | crates/benitoite/testdata/names/c11-mixed-pattern.bnt:[98, 108] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 61d14c5084c75e75cf3d | crates/benitoite/testdata/names/duplicate_param.bnt:[181, 243] | component | ['value', 'value'] | input_not_typed_successfully, local_name_collision, negative_input_requires_diagnostic_review |
| 4f679585606af294bcf8 | crates/benitoite/testdata/names/duplicate_pattern_var.bnt:[131, 147] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| a55173308c4bad540644 | crates/benitoite/testdata/names/option_unwrap.bnt:[82, 111] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| dafd7330922cd4a357a4 | crates/benitoite/testdata/names/option_unwrap.bnt:[96, 110] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| a15932f0ccfe24424f36 | crates/benitoite/testdata/names/option_unwrap.bnt:[124, 151] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f6b9a10d15ae460976d6 | crates/benitoite/testdata/names/option_unwrap.bnt:[138, 150] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| df011a45315af8af9ed9 | crates/benitoite/testdata/names/prelude_only_hidden.bnt:[100, 137] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 9c073b49973ddfb22b9c | crates/benitoite/testdata/names/prelude_only_hidden.bnt:[82, 145] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| fbac4efec98f23e156d5 | crates/benitoite/testdata/names/prelude_shadowed_member.bnt:[166, 178] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 7eee3a34e2fdfad9856e | crates/benitoite/testdata/names/qualified_missing_import.bnt:[72, 98] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 6d7e9226b2d581f63d8d | crates/benitoite/testdata/names/qualified_some.bnt:[82, 89] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| ee6ad8276f1f2514a0e2 | crates/benitoite/testdata/names/record-construction.bnt:[141, 152] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c180d8b8621bd76f220f | crates/benitoite/testdata/names/record-construction.bnt:[165, 180] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 679d97efb1760be6ba99 | crates/benitoite/testdata/names/renamed_member.bnt:[82, 105] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e90264882c4d631ec6a1 | crates/benitoite/testdata/names/renamed_module.bnt:[82, 93] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 1bef8a0033df4439c1e9 | crates/benitoite/testdata/names/string_length.bnt:[82, 102] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 1c8b98f80afab6c8b4fc | crates/benitoite/testdata/names/string_length.bnt:[115, 144] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 341062a541eb642055e8 | crates/benitoite/testdata/names/string_length.bnt:[157, 183] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| de59bfa5e0761683f3d2 | crates/benitoite/testdata/names/unknown_member.bnt:[97, 143] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 67e14923cab01b1d665d | crates/benitoite/testdata/names/unknown_member.bnt:[82, 144] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 35d559477f7da0dcf8a8 | crates/benitoite/testdata/names/unknown_module.bnt:[95, 141] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e9a4173e51e9d238addb | crates/benitoite/testdata/names/unknown_module.bnt:[82, 142] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 28c3c011a1724de471d0 | crates/benitoite/testdata/names/unknown_name.bnt:[328, 336] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 8f3ec498dded5cae562c | crates/benitoite/testdata/names/wrong_kind.bnt:[188, 197] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c1db338d3274f6a1c252 | crates/benitoite/testdata/network/respond-twice.bnt:[438, 497] | component | ['error'] | negative_input_requires_diagnostic_review |
| d7a12e7c999514d87c9a | crates/benitoite/testdata/network/respond-twice.bnt:[585, 1080] | component | [] | negative_input_requires_diagnostic_review |
| 0c20c50e4199cfe36ddf | crates/benitoite/testdata/network/respond-twice.bnt:[413, 498] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 5bba8e7437a899bf7599 | crates/benitoite/testdata/network/respond-twice.bnt:[645, 730] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 1a55787deed39cba1686 | crates/benitoite/testdata/network/respond-twice.bnt:[838, 923] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 26d8b6f581c639ed0cc3 | crates/benitoite/testdata/network/status-above-range.bnt:[438, 497] | component | ['error'] | negative_input_requires_diagnostic_review |
| 84f2b2129cbfc9e2e588 | crates/benitoite/testdata/network/status-above-range.bnt:[585, 891] | component | [] | negative_input_requires_diagnostic_review |
| 096c399f3d818b524bf4 | crates/benitoite/testdata/network/status-above-range.bnt:[413, 498] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| f6300673f39d0cfc269d | crates/benitoite/testdata/network/status-above-range.bnt:[645, 730] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| b990806164999e23531c | crates/benitoite/testdata/network/status-below-range.bnt:[438, 497] | component | ['error'] | negative_input_requires_diagnostic_review |
| a77b62f5882c464f29a0 | crates/benitoite/testdata/network/status-below-range.bnt:[585, 890] | component | [] | negative_input_requires_diagnostic_review |
| fddebbdbabd693848919 | crates/benitoite/testdata/network/status-below-range.bnt:[413, 498] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| f8e80b1438b076b4e827 | crates/benitoite/testdata/network/status-below-range.bnt:[645, 730] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| db35f7f0a2b372300376 | crates/benitoite/testdata/network/status-informational.bnt:[438, 497] | component | ['error'] | negative_input_requires_diagnostic_review |
| ce33c29e01f6c61026c3 | crates/benitoite/testdata/network/status-informational.bnt:[585, 891] | component | [] | negative_input_requires_diagnostic_review |
| ce9b20634939df1ea17a | crates/benitoite/testdata/network/status-informational.bnt:[413, 498] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 67cb0287145c5fecc02d | crates/benitoite/testdata/network/status-informational.bnt:[645, 730] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 01727c0eedb481cc3076 | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[274, 340] | call | ['xs', 'p'] | pipe_requires_review |
| ce3db8d1d47f085a29ac | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[274, 340] | call | ['xs', 'p'] | pipe_requires_review |
| 9ebaf5b6747e245d95e4 | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[274, 340] | call | ['xs', 'p'] | pipe_requires_review |
| 7034625b247973671f3d | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[274, 340] | call | ['xs', 'p'] | pipe_requires_review |
| 0e24b5a27574c7a76dde | crates/benitoite/testdata/packages/dependency-root-import/Textkit/Slug.bnt:[175, 183] | call | None | callee_contract_unresolved |
| d8dba11b1883dfba44a0 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[313, 356] | component | ['value'] | input_not_typed_successfully |
| 81bf887eef5e21fc65f7 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[213, 283] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| b1921a5516fe85be8467 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[229, 266] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 89af9c9e87dee53a4ab3 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[248, 265] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 5195d045c163a1701db6 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[291, 357] | call | None | callee_contract_unresolved, input_not_typed_successfully, pipe_requires_review |
| cc8cf15e2d4879272340 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[367, 405] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 406186bbb1590c8e1385 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[584, 611] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| bc17d2dade765bc9a8d2 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[660, 749] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 3daa7ce9b27973a6f6f0 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[679, 732] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 0310f9cd8b16f0f22021 | crates/benitoite/testdata/packages/package-private-name/main.bnt:[141, 154] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 423e08678d0b4ef031e2 | crates/benitoite/testdata/packages/package-visibility-hidden/main.bnt:[156, 173] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| c613f8e28719999e7e15 | crates/benitoite/testdata/syntax/c11-lambda-colon.bnt:[61, 76] | component | ['x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 257d2022ed34f7b5cece | crates/benitoite/testdata/syntax/call-type-arguments.bnt:[111, 144] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e3d6dfda180b2e90a2cf | crates/benitoite/testdata/syntax/lambda_underscore_param.bnt:[69, 110] | component | ['_unused', 'x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c953070e7efac01ff2c3 | crates/benitoite/testdata/syntax/uses_then_bracket.bnt:[102, 154] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| fe7e0028d661a1af922b | crates/benitoite/testdata/syntax/uses_then_bracket.bnt:[85, 163] | component | ['action'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 91edef0b997068f98402 | crates/benitoite/testdata/test/assert_equal.bnt:[331, 379] | component | ['acc', 'value'] | negative_input_requires_diagnostic_review |
| 47e138abe937d817a168 | crates/benitoite/testdata/test/result_error.bnt:[267, 316] | call | ['o', 'error'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 68b25d3a7e633b77de6d | crates/benitoite/testdata/test/runtime_error.bnt:[541, 577] | component | [] | negative_input_requires_diagnostic_review |
| 1fdc4d924773e3e759ab | crates/benitoite/testdata/test/task_assert.bnt:[402, 437] | component | [] | negative_input_requires_diagnostic_review |
| a7f5f5ad93a1c760fcdc | crates/benitoite/testdata/traits/c11-hk-arity.bnt:[169, 192] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 3efc8b4304550793c551 | crates/benitoite/testdata/traits/c11-hk-arity.bnt:[284, 307] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f362a8ec36f35035eb14 | crates/benitoite/testdata/traits/todo178-impl-target-cascade.bnt:[187, 222] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 434766637adbec86927f | crates/benitoite/testdata/traits/todo178-impl-target-cascade.bnt:[293, 328] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| d8ad1b9cd95a43fedba9 | crates/benitoite/testdata/traits/todo178-impl-target-independent.bnt:[187, 222] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 91b8c7b15d203f657720 | crates/benitoite/testdata/traits/todo178-impl-target-independent.bnt:[352, 387] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 646396b268658d401e23 | crates/benitoite/testdata/types/arity-single.bnt:[257, 267] | call | ['value'] | arity_mismatch, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 3847a828638e5e457aef | crates/benitoite/testdata/types/arity.bnt:[207, 219] | call | ['left', 'right'] | arity_mismatch, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5018e600ea9f5c78ea53 | crates/benitoite/testdata/types/c11-alias-not-module.bnt:[111, 129] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 99a777aeb141aab385be | crates/benitoite/testdata/types/c11-constant-call.bnt:[105, 108] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f87148a4411b9ae49710 | crates/benitoite/testdata/types/duplicate_in_uses.bnt:[123, 148] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| aa328bcaf5086f728765 | crates/benitoite/testdata/types/equality_summary.bnt:[223, 252] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 6ea41bbe748cb2b9d95c | crates/benitoite/testdata/types/f20-interpolation-no-show.bnt:[99, 137] | component | ['x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 820d1c96623c69e2622d | crates/benitoite/testdata/types/infinite_type.bnt:[86, 118] | component | ['f'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 2b126d8aa688fd549c0e | crates/benitoite/testdata/types/infinite_type.bnt:[103, 107] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5a32f4a126eef47680ce | crates/benitoite/testdata/types/main_signature_effect.bnt:[72, 97] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| a0317fe16c1ad9684d8c | crates/benitoite/testdata/types/named-required-pipe.bnt:[324, 333] | call | ['left', 'right'] | arity_mismatch, input_not_typed_successfully, negative_input_requires_diagnostic_review, pipe_requires_review |
| 67474246c076b7aad165 | crates/benitoite/testdata/types/no_let_polymorphism.bnt:[61, 98] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 7e1324a0bbfcb9e8c938 | crates/benitoite/testdata/types/not_a_function.bnt:[98, 106] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 0ae43b9505c6d369d3d9 | crates/benitoite/testdata/types/todo178-placeholder-return-error.bnt:[327, 331] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 64a823e7c43000947b7d | crates/benitoite/testdata/types/todo178-placeholder-try-error.bnt:[339, 343] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 13e7d036ff82ed687112 | crates/benitoite/testdata/types/too_many_effect_vars.bnt:[123, 148] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 817a4cd535633c24c38e | crates/benitoite/testdata/types/too_many_effect_vars.bnt:[89, 114] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 0b17545c250d032ede45 | crates/benitoite/testdata/types/undetermined.bnt:[76, 126] | component | ['left', 'right'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |

## N1 との照合

抽出器を変更したため、字句候補の数を AST の移行件数とは扱わない。元の全候補と合流を reconciliation.json に残し、対応する AST の候補または未一致の理由を記録する。

```json
{
  "baseline_join_kinds": {
    "list": 45,
    "return": 127,
    "if": 22
  },
  "join_status": {
    "held_extraction_or_context_difference": 62,
    "matched": 5,
    "held_generated_input_regenerate_from_source": 127
  },
  "call_status": {
    "held_lexical_candidate_requires_review": 3810,
    "matched": 171,
    "held_ambiguous_ast_candidates": 8,
    "excluded_by_design": 1604
  },
  "generated_snapshot_count": 300
}
```
