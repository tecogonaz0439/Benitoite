# 名前付き引数の移行確認表

全候補は未確認である。保留のない案も、manifest の review を approved にして内容とハッシュを確認してから適用する。

| 分類 | 件数 |
|---|---:|
| held | 264 |
| proposal | 20 |

## proposal

| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |
|---|---|---|---|---|
| d09428a10a0b5b6c5f04 | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[275, 310] | component | ['value'] |  |
| 4aa5faac4df0b4845f8a | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[196, 252] | call | ['s', 'separator'] |  |
| 112a201060dcdd3f5538 | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[321, 344] | call | ['xs', 'separator'] |  |
| 468b8ea697910c514284 | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[599, 659] | call | ['o', 'fallback'] |  |
| 770c2deaa9b41fd5be9e | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[615, 652] | call | ['s', 'start', 'stop'] |  |
| 08c92407326ac7142977 | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[275, 310] | component | ['value'] |  |
| 89837654a5ba0d022fb4 | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[196, 252] | call | ['s', 'separator'] |  |
| 22b25f88dd1a3d7ca02c | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[321, 344] | call | ['xs', 'separator'] |  |
| 5205360cf158d96b9d1f | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[599, 659] | call | ['o', 'fallback'] |  |
| efc6c77a1518f8b474e4 | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[615, 652] | call | ['s', 'start', 'stop'] |  |
| 99510f488f7590d658dc | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[275, 310] | component | ['value'] |  |
| 891c8117de5e4133862e | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[196, 252] | call | ['s', 'separator'] |  |
| c52ae5fec21524c0eea7 | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[321, 344] | call | ['xs', 'separator'] |  |
| e2dff31007b74ab1f0a0 | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[599, 659] | call | ['o', 'fallback'] |  |
| 95437e7200fd9440dcf1 | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[615, 652] | call | ['s', 'start', 'stop'] |  |
| eb0d924dde68f223b4e0 | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[275, 310] | component | ['value'] |  |
| a76a6f17303bfc384211 | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[196, 252] | call | ['s', 'separator'] |  |
| d40916db0736d28a6f3a | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[321, 344] | call | ['xs', 'separator'] |  |
| 6fe054380c96feac31c4 | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[599, 659] | call | ['o', 'fallback'] |  |
| e2a1157c0393cac32c3e | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[615, 652] | call | ['s', 'start', 'stop'] |  |

## held

| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |
|---|---|---|---|---|
| 27025569ddfc2a6ccad1 | crates/benitoite/testdata/concurrency/c12-cancelled-await.bnt:[741, 812] | component | [] | negative_input_requires_diagnostic_review |
| 98edcc1a3290e39993df | crates/benitoite/testdata/concurrency/c12-cancelled-await.bnt:[718, 813] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| ce4645084536b7e60e97 | crates/benitoite/testdata/concurrency/c12-cancelled-await.bnt:[820, 859] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| b339262fea3516ae6430 | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| b0b571d10889943a67d5 | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[991, 1231] | component | [] | negative_input_requires_diagnostic_review |
| ecc4b8339fd68d5a26df | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[1056, 1091] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 4d108334a8a9ec647c96 | crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt:[1103, 1144] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| 712cb29c13c54e079b38 | crates/benitoite/testdata/concurrency/c12-deadlock.bnt:[733, 777] | component | [] | negative_input_requires_diagnostic_review |
| 0c14293eac0d5867c939 | crates/benitoite/testdata/concurrency/c12-deadlock.bnt:[710, 778] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| a34f3fa38bf3346d9ef4 | crates/benitoite/testdata/concurrency/c12-deadlock.bnt:[783, 822] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| cb8c49f91128ed234e6d | crates/benitoite/testdata/concurrency/c12-group-released.bnt:[714, 766] | component | [] | negative_input_requires_diagnostic_review |
| 0a713b525bfec0703f00 | crates/benitoite/testdata/concurrency/c12-group-released.bnt:[558, 598] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| b3b6b0dace7efdc8ca60 | crates/benitoite/testdata/concurrency/c12-group-released.bnt:[691, 767] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| 93f29cc173d46ad51976 | crates/benitoite/testdata/concurrency/inherited_operation_task_location.bnt:None | component | [] | negative_input_requires_diagnostic_review |
| fb0091c092687e221504 | crates/benitoite/testdata/concurrency/inherited_operation_task_location.bnt:[306, 333] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| 5dbe4993fda8a22256c4 | crates/benitoite/testdata/concurrency/r41-inherited-non-tail.bnt:[359, 392] | component | [] | negative_input_requires_diagnostic_review |
| 77b3f52d39bc342a1ba1 | crates/benitoite/testdata/concurrency/r41-inherited-non-tail.bnt:[336, 393] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| e460d12bb1ed18c62e14 | crates/benitoite/testdata/concurrency/r41-task-error.bnt:[282, 318] | component | [] | negative_input_requires_diagnostic_review |
| 459786ba9771b7eb238c | crates/benitoite/testdata/effects/c11-high-impact-missing.bnt:[218, 244] | call | ['path', 'text'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 7d704ead810060e8af22 | crates/benitoite/testdata/effects/c11-state-no-cascade.bnt:[170, 189] | call | ['reference', 'value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 44f3901526402235e687 | crates/benitoite/testdata/effects/choose_io_violation.bnt:[277, 306] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 0bce99cba405a2f99b9a | crates/benitoite/testdata/effects/choose_io_violation.bnt:[308, 360] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 3cc544c2f44fa0bc03dd | crates/benitoite/testdata/effects/choose_io_violation.bnt:[270, 361] | call | ['unused', 'action'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| bbb9e32d0c45df4baafa | crates/benitoite/testdata/effects/effect_var_rigid.bnt:[122, 152] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f1892d57046ee049075c | crates/benitoite/testdata/effects/effect_var_rigid.bnt:[84, 109] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 4815a9b284205a23d269 | crates/benitoite/testdata/effects/effect_var_rigid.bnt:[237, 245] | call | None | callee_contract_unresolved, component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 110bbdb280c7b3c52d37 | crates/benitoite/testdata/effects/lambda_uses_violation.bnt:[119, 144] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 347010e308826aa989e2 | crates/benitoite/testdata/effects/lambda_uses_violation.bnt:[181, 267] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 84d8be2710f5fb9b41fb | crates/benitoite/testdata/effects/map_with_io_pure_violation.bnt:[180, 280] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 91c1fe884cbfcac9f72e | crates/benitoite/testdata/effects/map_with_io_pure_violation.bnt:[163, 281] | call | ['xs', 'f'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 4182f28e3cc9662210a0 | crates/benitoite/testdata/effects/outermost_only.bnt:[231, 260] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 9461bf22db3ba8fce14e | crates/benitoite/testdata/effects/r41-task-state-required.bnt:[411, 439] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 626ba7978402059ca772 | crates/benitoite/testdata/effects/r41-task-state-required.bnt:[278, 306] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 901c49fa60a1186d53de | crates/benitoite/testdata/effects/r41-task-state-required.bnt:[390, 440] | call | ['milliseconds', 'action'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e2def36aed996c441639 | crates/benitoite/testdata/eval/div_by_zero_tail.bnt:[289, 342] | component | ['value'] | negative_input_requires_diagnostic_review |
| 32bbaa111e8b9a7e4c66 | crates/benitoite/testdata/eval/div_by_zero_tail.bnt:[272, 343] | call | ['xs', 'f'] | negative_input_requires_diagnostic_review |
| a9899b5f76c4f0de10bf | crates/benitoite/testdata/eval/div_by_zero_tail.bnt:[310, 331] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 533e31c03b09af6eda84 | crates/benitoite/testdata/eval/div_by_zero_trace.bnt:[297, 354] | component | ['value'] | negative_input_requires_diagnostic_review |
| 8d30af5a2cd94e013ac2 | crates/benitoite/testdata/eval/div_by_zero_trace.bnt:[280, 355] | call | ['xs', 'f'] | negative_input_requires_diagnostic_review |
| 10598a394f3f40f8dfb8 | crates/benitoite/testdata/eval/div_by_zero_trace.bnt:[318, 339] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 5d1de349a79ef24d4fba | crates/benitoite/testdata/eval/int_overflow_floor_div.bnt:[176, 221] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 824625b566c5dc95d8c6 | crates/benitoite/testdata/eval/named_failure.bnt:[269, 312] | component | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 3036dce53b6b6d0ae245 | crates/benitoite/testdata/eval/named_failure.bnt:[552, 590] | call | None | callee_contract_unresolved, negative_input_requires_diagnostic_review |
| 6fbe9bebb3a434aae77e | crates/benitoite/testdata/eval/named_failure.bnt:[132, 175] | annotation | None | annotation_contract_unresolved, negative_input_requires_diagnostic_review |
| 67ed485675308c2cffce | crates/benitoite/testdata/eval/value_too_large.bnt:[198, 229] | call | ['s', 'n'] | negative_input_requires_diagnostic_review |
| 9d0f6301ae8d67304924 | crates/benitoite/testdata/eval/width-signed-s16-add-overflow.bnt:[182, 207] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| c449bfab7edbb2f27a73 | crates/benitoite/testdata/eval/width-signed-s16-divide-overflow.bnt:[184, 211] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| e9e1320c60d0c054a7c6 | crates/benitoite/testdata/eval/width-signed-s16-divide-zero.bnt:[184, 205] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 3251aac2c2ee0d7af68c | crates/benitoite/testdata/eval/width-signed-s16-modulo-zero.bnt:[184, 205] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| fe6c6605e3ee6e6268b1 | crates/benitoite/testdata/eval/width-signed-s16-multiply-overflow.bnt:[182, 207] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 43842642baa84dbff5ee | crates/benitoite/testdata/eval/width-signed-s16-negate-overflow.bnt:[179, 205] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| fb68f60ec9319427ecad | crates/benitoite/testdata/eval/width-signed-s16-subtract-overflow.bnt:[182, 208] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 710564e2b3947ac13e7f | crates/benitoite/testdata/eval/width-signed-s32-add-overflow.bnt:[182, 212] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 357773d44f17226fb944 | crates/benitoite/testdata/eval/width-signed-s32-divide-overflow.bnt:[184, 216] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 1556b2aaaa181557341d | crates/benitoite/testdata/eval/width-signed-s32-divide-zero.bnt:[184, 205] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 9cb3d70caab469c785a6 | crates/benitoite/testdata/eval/width-signed-s32-modulo-zero.bnt:[184, 205] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 5a883f70c5bee4594857 | crates/benitoite/testdata/eval/width-signed-s32-multiply-overflow.bnt:[182, 212] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 4003652c205b25b2eded | crates/benitoite/testdata/eval/width-signed-s32-negate-overflow.bnt:[179, 210] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 8f4f31233cf7f11ee4fd | crates/benitoite/testdata/eval/width-signed-s32-subtract-overflow.bnt:[182, 213] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 9015bbaf70a6cf4e40d3 | crates/benitoite/testdata/eval/width-signed-s8-add-overflow.bnt:[179, 200] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| b09a4cde0dc819e98eea | crates/benitoite/testdata/eval/width-signed-s8-divide-overflow.bnt:[181, 204] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| b903e2a90715429d7dd0 | crates/benitoite/testdata/eval/width-signed-s8-divide-zero.bnt:[181, 200] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 5d2f9941762ddddfc266 | crates/benitoite/testdata/eval/width-signed-s8-modulo-zero.bnt:[181, 200] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| ffef3aa316f7cf2c4ce1 | crates/benitoite/testdata/eval/width-signed-s8-multiply-overflow.bnt:[179, 200] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 8d0b21886de80c2f3a68 | crates/benitoite/testdata/eval/width-signed-s8-negate-overflow.bnt:[176, 198] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| a8a8d8726e5aec4c6ecf | crates/benitoite/testdata/eval/width-signed-s8-subtract-overflow.bnt:[179, 201] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 078b7b7ff1b4792038cf | crates/benitoite/testdata/eval/width-unsigned-u16-add-overflow.bnt:[206, 231] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| a9a738512d4963f84faf | crates/benitoite/testdata/eval/width-unsigned-u16-divide-zero.bnt:[208, 233] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| ec1e2a7ab8c23f254b9d | crates/benitoite/testdata/eval/width-unsigned-u16-modulo-zero.bnt:[208, 233] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| c474e70436cfb3d24b7a | crates/benitoite/testdata/eval/width-unsigned-u16-multiply-overflow.bnt:[206, 231] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| fb87606b686c6eae8a5c | crates/benitoite/testdata/eval/width-unsigned-u16-subtract-underflow.bnt:[206, 227] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| fef00ed28615dfdd8617 | crates/benitoite/testdata/eval/width-unsigned-u32-add-overflow.bnt:[206, 236] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| ef1155a166d804f3e1e1 | crates/benitoite/testdata/eval/width-unsigned-u32-divide-zero.bnt:[208, 238] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| a754b8910f3d54b562cf | crates/benitoite/testdata/eval/width-unsigned-u32-modulo-zero.bnt:[208, 238] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| afec387d882bcb2ed196 | crates/benitoite/testdata/eval/width-unsigned-u32-multiply-overflow.bnt:[206, 236] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 5af4078f27aada2bd43e | crates/benitoite/testdata/eval/width-unsigned-u32-subtract-underflow.bnt:[206, 227] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| db84338ccf11c9f8caa0 | crates/benitoite/testdata/eval/width-unsigned-u64-add-overflow.bnt:[206, 246] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 2e9aea0e379561fe0ddf | crates/benitoite/testdata/eval/width-unsigned-u64-divide-zero.bnt:[208, 248] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| c0ef625a87efd551b0fc | crates/benitoite/testdata/eval/width-unsigned-u64-modulo-zero.bnt:[208, 248] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 1c998500c2a208684057 | crates/benitoite/testdata/eval/width-unsigned-u64-multiply-overflow.bnt:[206, 246] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 89b0fdca59190d0514fc | crates/benitoite/testdata/eval/width-unsigned-u64-subtract-underflow.bnt:[206, 227] | call | ['a', 'b'] | negative_input_requires_diagnostic_review |
| 03fad431cffa514be2c5 | crates/benitoite/testdata/handlers/c12-discard-reader.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 45a7310e6e17ed2f32d3 | crates/benitoite/testdata/handlers/c12-discard-reader.bnt:[909, 944] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 0b8c6b415a1a1cf4f3fa | crates/benitoite/testdata/handlers/c12-discard-reader.bnt:[954, 995] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| d3cb075f09d346d5661e | crates/benitoite/testdata/handlers/secf1-captured-local.bnt:[321, 345] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e5068872b16360d4166f | crates/benitoite/testdata/handlers/secf1-closure.bnt:[346, 384] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 9bff1f4296d246a9621f | crates/benitoite/testdata/handlers/secf1-closure.bnt:[413, 454] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| fe22df8fb0e263b3aa7f | crates/benitoite/testdata/handlers/secf1-deferred-alias.bnt:[342, 366] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 53e78219ec40ae9226c9 | crates/benitoite/testdata/handlers/secf1-deferred-alias.bnt:[444, 481] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 665fce32d7e96e3fa586 | crates/benitoite/testdata/handlers/secf1-early-return.bnt:[318, 468] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 922a766c6fafd6ef7674 | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[495, 580] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| ba2a071524899661cc3e | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[602, 651] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 8693611012c4383b60d7 | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[514, 569] | call | ['path', 'text'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| cb47394fe1e5503d6c40 | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[657, 660] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5de9b35ec4ae78fa4b93 | crates/benitoite/testdata/handlers/secf1-effect-confusion.bnt:[734, 769] | call | ['reference', 'value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 9b39f24b0702e5053817 | crates/benitoite/testdata/handlers/secf1-nested-escape.bnt:[508, 543] | call | ['reference', 'value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 08ea13d7b4d2b491ddd6 | crates/benitoite/testdata/handlers/secf1-value-confusion.bnt:[523, 558] | call | ['reference', 'value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c329d501244123a94166 | crates/benitoite/testdata/handlers/todo178-placeholder-resume-error.bnt:[375, 393] | call | ['a', 'b'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 57300c600c731da4ee66 | crates/benitoite/testdata/handlers/todo178-placeholder-resume-error.bnt:[400, 404] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| edc137e681c28f41a59c | crates/benitoite/testdata/handlers/todo178-placeholder-resume-error.bnt:[525, 543] | call | ['a', 'b'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 30e8e8ece3c07851cd49 | crates/benitoite/testdata/handlers/todo178-placeholder-resume-error.bnt:[550, 554] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 8c9108d302f83e26733c | crates/benitoite/testdata/handlers/todo190-guard-resume.bnt:[473, 483] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 8e64237d188a8371c0e7 | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 3dec595632acd375d01f | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[652, 687] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 80bd897d15103476ab5b | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[709, 797] | call | ['o', 'fallback'] | negative_input_requires_diagnostic_review |
| 6676b831909768f49b8a | crates/benitoite/testdata/io/c12-process-exit-flush.bnt:[754, 789] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 9c33f501aec3cf7ce83a | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 7b15a5af4407aec8f02b | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[714, 749] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 84a2d15c513999a9d85f | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[757, 798] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| cb8fba8313204248cc07 | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[821, 909] | call | ['o', 'fallback'] | negative_input_requires_diagnostic_review |
| acf89f18a724bba087fe | crates/benitoite/testdata/io/c12-with-reader-release.bnt:[866, 901] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 0acfa964d6b7fd2e0fa2 | crates/benitoite/testdata/io/c12-with-return-release.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| faeefa834242c8dcd7b5 | crates/benitoite/testdata/io/c12-with-return-release.bnt:[625, 660] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| c54e5e7f4e806d4c2819 | crates/benitoite/testdata/io/c12-with-return-release.bnt:[668, 709] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| b4bcf280df484b874677 | crates/benitoite/testdata/io/c12-with-try-release.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 41d2355fe7ed4b031f6d | crates/benitoite/testdata/io/c12-with-try-release.bnt:[622, 657] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 07bf6f18a562a4c68308 | crates/benitoite/testdata/io/c12-with-try-release.bnt:[665, 706] | call | ['reference', 'value'] | negative_input_requires_diagnostic_review |
| ff7f4136ca441c040d56 | crates/benitoite/testdata/modules/c11-missing/main.bnt:[109, 124] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 10b26924d3a4dae2a667 | crates/benitoite/testdata/modules/c11-missing/main.bnt:[127, 143] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| ca8707e6759eb5ab71bb | crates/benitoite/testdata/modules/c11-not-reexported/main.bnt:[103, 114] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 02f9abbcb089b662c0a9 | crates/benitoite/testdata/modules/c11-private/main.bnt:[86, 98] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| dc906c21ace605acd9e4 | crates/benitoite/testdata/modules/effect_alias_references.bnt:[158, 175] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 2469217e45fa4ca830c5 | crates/benitoite/testdata/modules/todo177-effect-module-alias.bnt:[184, 224] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 47ce5e00e7fa363f82c3 | crates/benitoite/testdata/modules/todo177-effect-module-alias.bnt:[232, 267] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review, pipe_requires_review |
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
| 7c2253c69f72a8195cbe | crates/benitoite/testdata/network/respond-twice.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 77af23ffc1092cf8f97a | crates/benitoite/testdata/network/respond-twice.bnt:[513, 856] | component | [] | negative_input_requires_diagnostic_review |
| 8e87e21eab26e1ccd7ff | crates/benitoite/testdata/network/respond-twice.bnt:[370, 397] | call | ['host', 'port'] | negative_input_requires_diagnostic_review |
| 933c4f48b4826f5d6f1a | crates/benitoite/testdata/network/respond-twice.bnt:[401, 441] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| afae49b4c54475e45936 | crates/benitoite/testdata/network/respond-twice.bnt:[490, 857] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| 45502002ad82aab9a6bd | crates/benitoite/testdata/network/respond-twice.bnt:[573, 613] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| d6cb1408daf6c9682ebf | crates/benitoite/testdata/network/respond-twice.bnt:[639, 686] | call | ['exchange', 'response'] | negative_input_requires_diagnostic_review |
| 778187425d59c6237824 | crates/benitoite/testdata/network/respond-twice.bnt:[662, 685] | call | ['status', 's'] | negative_input_requires_diagnostic_review |
| 3f3553043ecee5bfb3f7 | crates/benitoite/testdata/network/respond-twice.bnt:[690, 730] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 11f01b755c1301724653 | crates/benitoite/testdata/network/respond-twice.bnt:[749, 797] | call | ['exchange', 'response'] | negative_input_requires_diagnostic_review |
| b47ef5b3b523f28624a1 | crates/benitoite/testdata/network/respond-twice.bnt:[772, 796] | call | ['status', 's'] | negative_input_requires_diagnostic_review |
| 4a728cd6bdbf85e5ee73 | crates/benitoite/testdata/network/status-above-range.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 6e5a72878e6747f5f484 | crates/benitoite/testdata/network/status-above-range.bnt:[513, 743] | component | [] | negative_input_requires_diagnostic_review |
| ba39fd9fbc379034e157 | crates/benitoite/testdata/network/status-above-range.bnt:[370, 397] | call | ['host', 'port'] | negative_input_requires_diagnostic_review |
| 15ef80eaf71f6f04be88 | crates/benitoite/testdata/network/status-above-range.bnt:[401, 441] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 8278ab4b74130e14c345 | crates/benitoite/testdata/network/status-above-range.bnt:[490, 744] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| 8ebc438574b8e08ef2be | crates/benitoite/testdata/network/status-above-range.bnt:[573, 613] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 5c2110d46dc5c293cd9b | crates/benitoite/testdata/network/status-above-range.bnt:[635, 684] | call | ['exchange', 'response'] | negative_input_requires_diagnostic_review |
| 54349154f9b1553e7a0e | crates/benitoite/testdata/network/status-above-range.bnt:[658, 683] | call | ['status', 's'] | negative_input_requires_diagnostic_review |
| 184bf6b091e45e14dd5c | crates/benitoite/testdata/network/status-below-range.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| d67d789236b43e49eafa | crates/benitoite/testdata/network/status-below-range.bnt:[513, 742] | component | [] | negative_input_requires_diagnostic_review |
| ed3a6bb825d1e2528062 | crates/benitoite/testdata/network/status-below-range.bnt:[370, 397] | call | ['host', 'port'] | negative_input_requires_diagnostic_review |
| f37307c3d14a80aea0ff | crates/benitoite/testdata/network/status-below-range.bnt:[401, 441] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 4a070a8705958c8dae65 | crates/benitoite/testdata/network/status-below-range.bnt:[490, 743] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| 7948c9aa22a4468e0f88 | crates/benitoite/testdata/network/status-below-range.bnt:[573, 613] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| f752c1309c018d4746ee | crates/benitoite/testdata/network/status-below-range.bnt:[635, 683] | call | ['exchange', 'response'] | negative_input_requires_diagnostic_review |
| 288104f0c6c94f128b96 | crates/benitoite/testdata/network/status-below-range.bnt:[658, 682] | call | ['status', 's'] | negative_input_requires_diagnostic_review |
| 327434756306a87592e9 | crates/benitoite/testdata/network/status-informational.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, negative_input_requires_diagnostic_review, public_contract |
| 1665ab640481efa1ed4c | crates/benitoite/testdata/network/status-informational.bnt:[513, 743] | component | [] | negative_input_requires_diagnostic_review |
| 6f4fa6063e7e4aca116f | crates/benitoite/testdata/network/status-informational.bnt:[370, 397] | call | ['host', 'port'] | negative_input_requires_diagnostic_review |
| 7ef63bb5775df82bb076 | crates/benitoite/testdata/network/status-informational.bnt:[401, 441] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 26e9fca9a57ecc91bae9 | crates/benitoite/testdata/network/status-informational.bnt:[490, 744] | call | ['group', 'action'] | negative_input_requires_diagnostic_review |
| 38da2a7f640fdabb88b3 | crates/benitoite/testdata/network/status-informational.bnt:[573, 613] | call | ['r', 'f'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 14d120e72cd196ebb007 | crates/benitoite/testdata/network/status-informational.bnt:[635, 684] | call | ['exchange', 'response'] | negative_input_requires_diagnostic_review |
| ce733de237f4fa466b37 | crates/benitoite/testdata/network/status-informational.bnt:[658, 683] | call | ['status', 's'] | negative_input_requires_diagnostic_review |
| 66f45bcfb2536af5b5bf | crates/benitoite/testdata/packages/alias-only/deps/textkit/Slug.bnt:[260, 311] | call | ['xs', 'p'] | pipe_requires_review |
| 517e612ad09ad22c9604 | crates/benitoite/testdata/packages/dependency-collision/Textkit/Slug.bnt:[260, 311] | call | ['xs', 'p'] | pipe_requires_review |
| 4e0ab8d7ef2bb8901336 | crates/benitoite/testdata/packages/dependency-collision/deps/textkit/Slug.bnt:[260, 311] | call | ['xs', 'p'] | pipe_requires_review |
| c6cbaddafb0e53a7a288 | crates/benitoite/testdata/packages/dependency-no-config/deps/textkit/Slug.bnt:[260, 311] | call | ['xs', 'p'] | pipe_requires_review |
| 0e24b5a27574c7a76dde | crates/benitoite/testdata/packages/dependency-root-import/Textkit/Slug.bnt:[175, 183] | call | None | callee_contract_unresolved |
| 74cbe6ab7834bc27b9e6 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[292, 327] | component | ['w'] | input_not_typed_successfully |
| f1cdb7f590dc5e98aeed | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[213, 269] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| e4f121252329aa69d3fb | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[226, 263] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 4a066ef516565558521d | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[245, 262] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| d37ada5abaa9c8e3a58e | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[277, 328] | call | None | callee_contract_unresolved, input_not_typed_successfully, pipe_requires_review |
| 5d3c7e786922585b6e12 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[338, 361] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| e5b0197b341a0ad046e7 | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[540, 567] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 36b8be9398dc563efe6d | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[616, 676] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 9ce2d91335972bf5b61f | crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt:[632, 669] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 0310f9cd8b16f0f22021 | crates/benitoite/testdata/packages/package-private-name/main.bnt:[141, 154] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 423e08678d0b4ef031e2 | crates/benitoite/testdata/packages/package-visibility-hidden/main.bnt:[156, 173] | call | None | callee_contract_unresolved, input_not_typed_successfully |
| 0a712fb451c08795369f | crates/benitoite/testdata/stdlib/l40-csv-invalid-delimiter.bnt:[368, 394] | call | ['text', 'delimiter'] | negative_input_requires_diagnostic_review |
| cda335a9b895e1719a7a | crates/benitoite/testdata/stdlib/l40-path-invalid-extension.bnt:[370, 400] | call | ['p', 'extension'] | negative_input_requires_diagnostic_review |
| 8f12b41d80b5c9b0f689 | crates/benitoite/testdata/stdlib/width-bits-s8-invalid.bnt:[152, 188] | call | ['a', 'n'] | negative_input_requires_diagnostic_review |
| 94350e18535d66ed6e94 | crates/benitoite/testdata/stdlib/width-bits-u64-invalid.bnt:[152, 189] | call | ['a', 'n'] | negative_input_requires_diagnostic_review |
| c613f8e28719999e7e15 | crates/benitoite/testdata/syntax/c11-lambda-colon.bnt:[61, 76] | component | ['x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| ec6e43e6b356aaf7467d | crates/benitoite/testdata/syntax/call-type-arguments.bnt:[111, 129] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e3d6dfda180b2e90a2cf | crates/benitoite/testdata/syntax/lambda_underscore_param.bnt:[69, 110] | component | ['_unused', 'x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 80aa0e7d85d6e263b637 | crates/benitoite/testdata/syntax/uses_then_bracket.bnt:[85, 155] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| c7fbb286285671b1034b | crates/benitoite/testdata/syntax/uses_then_bracket.bnt:[94, 146] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f9bba8e30031f266b2e7 | crates/benitoite/testdata/test/assert_equal.bnt:[307, 347] | component | ['acc', 'value'] | negative_input_requires_diagnostic_review |
| 817af8e19ccd0d9c1237 | crates/benitoite/testdata/test/assert_equal.bnt:[273, 359] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| ecfad0e92855705ee46b | crates/benitoite/testdata/test/assert_equal.bnt:[286, 348] | call | ['xs', 'initial', 'f'] | negative_input_requires_diagnostic_review |
| ce27f70bdb10471c0442 | crates/benitoite/testdata/test/assert_equal.bnt:[446, 468] | call | ['values', 'expected'] | negative_input_requires_diagnostic_review |
| ad6de2a2357543cd97ef | crates/benitoite/testdata/test/assert_equal.bnt:[536, 564] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| e8adcec26af8c60cea28 | crates/benitoite/testdata/test/assert_equal.bnt:[567, 585] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| 541d56ffdf949103259c | crates/benitoite/testdata/test/assert_is_true.bnt:[234, 276] | call | ['condition', 'message'] | negative_input_requires_diagnostic_review |
| fe2520e87223455b4c9a | crates/benitoite/testdata/test/assert_not_equal.bnt:[207, 238] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| 49c661f864e0869df4c9 | crates/benitoite/testdata/test/captured_output.bnt:[511, 529] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| f4e3363ca30a9d4e5486 | crates/benitoite/testdata/test/exit.bnt:[379, 416] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| d2c263365205a0bd2e42 | crates/benitoite/testdata/test/result_error.bnt:[267, 306] | call | ['o', 'error'] | negative_input_requires_diagnostic_review, pipe_requires_review |
| 68b25d3a7e633b77de6d | crates/benitoite/testdata/test/runtime_error.bnt:[541, 577] | component | [] | negative_input_requires_diagnostic_review |
| da757220b01dc43acb03 | crates/benitoite/testdata/test/runtime_error.bnt:[661, 687] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| 79769cdd3127e8f9a481 | crates/benitoite/testdata/test/task_assert.bnt:[384, 419] | component | [] | negative_input_requires_diagnostic_review |
| 74977f516757ff2121f2 | crates/benitoite/testdata/test/task_assert.bnt:[262, 280] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| ec353374b8ccfeccb9f7 | crates/benitoite/testdata/test/values.bnt:[384, 453] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| fea35d31d395e224f5d3 | crates/benitoite/testdata/test/values.bnt:[521, 583] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| 64676282696a2861ea40 | crates/benitoite/testdata/test/values.bnt:[652, 716] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| 73ceb8450c132c6cfcce | crates/benitoite/testdata/test/values.bnt:[784, 855] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| d520ba7ac22d509da3bd | crates/benitoite/testdata/test/values.bnt:[920, 993] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| 74a149a846538747c4b9 | crates/benitoite/testdata/test/values.bnt:[1058, 1123] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| b0810cd557ede006577a | crates/benitoite/testdata/test/values.bnt:[1189, 1247] | call | ['actual', 'expected'] | negative_input_requires_diagnostic_review |
| ab1e2b5830d3c1403c1c | crates/benitoite/testdata/traits/c11-builtin-propagation.bnt:[237, 247] | call | ['a', 'b'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 23528c113ee68fc4d9af | crates/benitoite/testdata/traits/c11-hk-arity.bnt:[169, 185] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 0cfa04e838c3870a942e | crates/benitoite/testdata/traits/c11-hk-arity.bnt:[277, 293] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| acbac84ffbc6f13f8876 | crates/benitoite/testdata/traits/c11-hk-arity.bnt:[323, 339] | call | ['r', 'f'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5b5fac1ad0184955ab1c | crates/benitoite/testdata/traits/todo178-impl-target-cascade.bnt:[180, 208] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 80c789153e36b1971eaf | crates/benitoite/testdata/traits/todo178-impl-target-cascade.bnt:[279, 307] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 086ce7f6d8d6c19b869d | crates/benitoite/testdata/traits/todo178-impl-target-independent.bnt:[180, 208] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 3162e1675c39e822b779 | crates/benitoite/testdata/traits/todo178-impl-target-independent.bnt:[338, 366] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f09f69031815d719a6b4 | crates/benitoite/testdata/types/arity.bnt:[207, 213] | call | ['left', 'right'] | arity_mismatch, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5018e600ea9f5c78ea53 | crates/benitoite/testdata/types/c11-alias-not-module.bnt:[111, 129] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 99a777aeb141aab385be | crates/benitoite/testdata/types/c11-constant-call.bnt:[105, 108] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| f87148a4411b9ae49710 | crates/benitoite/testdata/types/duplicate_in_uses.bnt:[123, 148] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| aa328bcaf5086f728765 | crates/benitoite/testdata/types/equality_summary.bnt:[223, 252] | component | [] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 6ea41bbe748cb2b9d95c | crates/benitoite/testdata/types/f20-interpolation-no-show.bnt:[99, 137] | component | ['x'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 820d1c96623c69e2622d | crates/benitoite/testdata/types/infinite_type.bnt:[86, 118] | component | ['f'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 2b126d8aa688fd549c0e | crates/benitoite/testdata/types/infinite_type.bnt:[103, 107] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 5a32f4a126eef47680ce | crates/benitoite/testdata/types/main_signature_effect.bnt:[72, 97] | component | None | component_not_determined, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 67474246c076b7aad165 | crates/benitoite/testdata/types/no_let_polymorphism.bnt:[61, 98] | component | ['value'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| 7e1324a0bbfcb9e8c938 | crates/benitoite/testdata/types/not_a_function.bnt:[98, 106] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| fdcf4e18458460609c41 | crates/benitoite/testdata/types/todo178-placeholder-return-error.bnt:[270, 294] | call | ['a', 'b'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| e90fb146024e777dda51 | crates/benitoite/testdata/types/todo178-placeholder-return-error.bnt:[321, 325] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
| de5d4c6e1d21fbbd5e3e | crates/benitoite/testdata/types/todo178-placeholder-try-error.bnt:[280, 303] | call | ['a', 'b'] | input_not_typed_successfully, negative_input_requires_diagnostic_review |
| b8a4a3f4326f345dc5b9 | crates/benitoite/testdata/types/todo178-placeholder-try-error.bnt:[333, 337] | call | None | callee_contract_unresolved, input_not_typed_successfully, negative_input_requires_diagnostic_review |
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
    "held_extraction_or_context_difference": 61,
    "matched": 6,
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
