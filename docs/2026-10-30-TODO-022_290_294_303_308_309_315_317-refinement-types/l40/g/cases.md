# 第2節の全表と本番の対応

2026-11-04。表の行を一行ずつ保つ。生成器・変性の再帰・数値の展開数・遷移数を足して証明件数にしない。各単位の全証拠と所在は [unit-evidence.json](unit-evidence.json)。全76葉は [群 C の76行](../c/leaves.md)、H04 の109場合は [constructors.json](constructors.json) と [reconciliation.json](reconciliation.json) に対応する。

## 部分型、依存列、変性

| detail の行 | 本番の証拠 | 判定と後段 |
|---|---|---|
| Ty.LeQ | `Ty.LeQ`（Le）；`HasTypeVQ.inv_var`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| TelLe | `TelLe`（Le）；`TelLe.open_done`（TelApplication）；`TelLe.open_tail`（TelApplication） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| TelClosure | `TelClosure`（Le）；`TelClosure.apply`（TelApplication） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| TypeArgsLe | `TypeArgsLe`（Le）；`valid`（StandardVariance） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| Polarity.compose と位置 | `Polarity.compose`（VarianceSyntax）；`valid`（StandardVariance） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 変性の構造再帰 | `Ty.VarianceOK`（VarianceValidation）；`valid`（StandardVariance） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 組込みの共変位置 | `covariant_positions`（StandardVariance） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 範囲添字 | `Ty.LeQ.holds`（HeldValues）；`HasTypeVQ.canonical_held`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |

## 値、計算、状態の開始逆転

| detail の行 | 本番の証拠 | 判定と後段 |
|---|---|---|
| var | `HasTypeVQ.inv_var`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| const | `HasTypeVQ.inv_const`（ValueFacts）；`HasTypeVQ.facts`（ValueFacts） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| fnRef | `HasTypeVQ.inv_var`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| prim | `HasTypeVQ.inv_var`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| op | `HasTypeVQ.inv_op`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| lam / dependentLam | `HasTypeVQ.inv_lam`（ValueInversion）；`HasTypeVQ.inv_dependentLam`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| closure | `HasTypeVQ.inv_closure`（Canonical）；`StateTyE.closure_contract_inputs`（LeafInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| raise | `HasTypeVQ.inv_raise`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| con | `HasTypeVQ.constructor_field_inputs`（ValueFacts）；`HasTypeVQ.canonical_data`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| list | `HasTypeVQ.inv_list_core`（ValueInversion）；`HasTypeVQ.list_element_facts`（ValueFacts） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| loc | `HasTypeVQ.inv_loc`（CanonicalCells）；`StoreOk.ref_cell`（CanonicalCells）；`StoreOk.lazy_cell`（CanonicalCells） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| mapV | `HasTypeVQ.inv_mapV`（CollectionInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| setV | `HasTypeVQ.inv_setV`（CollectionInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| bytesV | `HasTypeVQ.inv_bytesV`（CollectionInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| dict / super | `HasTypeVQ.inv_dict`（ValueInversion）；`HasTypeVQ.inv_super`（ValueInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| externalRef | `HasTypeVQ.inv_externalRef`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |
| externalHandle | `HasTypeVQ.inv_externalHandle`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |
| pathBases / scopePattern | `HasTypeVQ.inv_pathBases`（CanonicalValues）；`HasTypeVQ.inv_scopePattern`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |
| checked / checkedRequest / checkedAt | `HasTypeVQ.inv_checked`（HeldValues）；`HasTypeVQ.inv_checkedRequest`（HeldValues）；`HasTypeVQ.inv_checkedAt`（HeldValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |
| atError | `HasTypeVQ.inv_atError`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |
| app | `HasTypeCQ.inv_app`（ComputationInversion）；`HasTypeCQ.app_tel`（ComputationInversion）；`StateTyE.app_inputs`（ApplicationInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| ret / escape | `HasTypeCQ.ret_value`（DependentBeta）；`HasTypeCQ.inv_escape`（ComputationInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| letIn / meth | `HasTypeCQ.inv_let`（ComputationInversion）；`HasTypeCQ.inputs`（ComputationInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| ite | `false_if_typing`（StandardFactExamples）；`StateTyE.if_inputs`（LeafInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| match | `HasTypeCQ.inv_match`（ComputationInputs）；`StateTyE.match_inputs`（LeafInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| handle / use / resume | `HasTypeCQ.inputs`（ComputationInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| builderLet / builderOp / lazyC | `StoreOk.builder_cell`（CanonicalCells）；`StoreOk.lazy_cell`（CanonicalCells）；`HasTypeCQ.inputs`（ComputationInputs） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| externalCall / issuePathBases / checkAt | `HasTypeCQ.inputs`（ComputationInputs）；`HasTypeVQ.inv_atError`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |

## 全 sort と measure の本番からの導出

| detail の行 | 本番の証拠 | 判定と後段 |
|---|---|---|
| integer | `integerConvert_result`（StandardInteger）；`integerDelta_binary_facts`（StandardInteger） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| character | `character_scalar`（StandardByteCharacter）；`character_code`（StandardByteCharacter） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| float64 / float32（2） | `float32_class_reply`（StandardFloat）；`float64_class_reply`（StandardFloat）；`float32_compare_reply`（StandardFloat）；`float64_compare_reply`（StandardFloat） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| decimal | `decimalRound_represented`（StandardDecimal）；`decimal_compare_reply`（StandardDecimal） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| boolean | `HasTypeVQ.canonical_boolean`（CanonicalValues）；`false_if_typing`（StandardFactExamples） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| unit | `HasTypeVQ.canonical_scalar`（CanonicalValues）；`typed_value_meaning_closed`（TypedMeaning） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| string | `string_lengths`（StandardCollections） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| list | `HasTypeVQ.inv_list_core`（ValueInversion）；`HasTypeVQ.list_element_facts`（ValueFacts） | 局所の宣言と読者を照合。主定理の全合成は L70。正常時の長さは精密 tel の型付け、callback の順序は R40 の実行の検査 |
| bytes | `bytes_length`（StandardCollections）；`HasTypeVQ.inv_bytesV`（CollectionInversion） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| map | `key_map_normal`（StandardKeySound）；`HasTypeVQ.inv_mapV`（CollectionInversion） | 局所の宣言と読者を照合。主定理の全合成は L70。正常時の長さは精密 tel の型付け、callback の順序は R40 の実行の検査 |
| set | `key_set_normal`（StandardKeySound）；`HasTypeVQ.inv_setV`（CollectionInversion） | 局所の宣言と読者を照合。主定理の全合成は L70。正常時の長さは精密 tel の型付け、callback の順序は R40 の実行の検査 |
| data | `HasTypeVQ.canonical_data`（CanonicalValues）；`record_valid`（StandardRecordFields）；`record_chain`（StandardRecordFields） | 局所の宣言と読者を照合。主定理の全合成は L70。O135は同じ通常Resultの実行へ接続済み。生成器全体はR40 |
| target path/host/endpoint（3） | `HasTypeVQ.canonical_held`（CanonicalValues）；`HasTypeVQ.represented`（ExternalObservation） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |

## 数値の正常結果と Stop

| detail の行 | 本番の証拠 | 判定と後段 |
|---|---|---|
| 幅 | `integerConvert_result`（StandardInteger）；`HasTypeVQ.canonical_scalar`（CanonicalValues） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 線形に使う算術 | `integerDelta_binary_facts`（StandardInteger）；`integerDelta_negate`（StandardInteger）；`binary_delta_split`（StandardIntegerFailure） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 除算・剰余 | `divMod_delta_split`（StandardIntegerFailure）；`division_overflow_iff`（StandardIntegerFailure） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 整数比較 | `integerDelta_equality`（StandardInteger）；`integerDelta_order`（StandardInteger） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| Byte | `byteConvert_some`（StandardByteCharacter）；`byteConvert_none`（StandardByteCharacter）；`byte_compare`（StandardByteCharacter） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| Character | `character_scalar`（StandardByteCharacter）；`characterConvert_some`（StandardByteCharacter）；`character_code`（StandardByteCharacter）；`character_compare`（StandardByteCharacter） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| Float | `float32_class_reply`（StandardFloat）；`float64_class_reply`（StandardFloat）；`float32_compare_reply`（StandardFloat）；`float64_compare_reply`（StandardFloat） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| Decimal | `decimalRound_represented`（StandardDecimal）；`decimalRound_typed`（StandardDecimal）；`decimalDelta_round`（StandardDecimal） | 局所の宣言と読者を照合。主定理の全合成は L70 |
| 応答 | `response_math`（StandardArithmeticResponse）；`response`（StandardListResponse） | 局所の宣言と読者を照合。主定理の全合成は L70、全有効 σ は L50、外部・実表の全欄は L60 |
| 区間の失敗理由 | `binary_delta_split`（StandardIntegerFailure）；`divMod_delta_split`（StandardIntegerFailure）；`floor_delta_split`（StandardIntegerFailure）；`absolute_split`（StandardIntegerFailure）；`shift_outside`（StandardIntegerFailure）；`tracked_failure_sound`（IntervalFailure） | 局所の宣言と読者を照合。主定理の全合成は L70 |

## 表の外で固定した母集団

Val25・Comp16・State4・Frame7・Cell6、値の導出29＋2＋2、計算の導出24、ContTy10、KeyShape11・KeySlots2・KeyPairs2、Measure7、Step76を現行構成子から抽出した。sort は13行のうち Float 二幅と target 三形を展開して16。独立評価は69＋4＋4＋6×3＋14＝109、EvalStandard7は別に保持する。H04 の第一候補の unknown 除外は TrackedFailure の範囲であり、unknown の失敗例を削除しない。

旧31逆転は旧14移植・既済み7・供給側10。var の移植1を群 A が先行し、dependentLam/raise は新2目的として別計上。群 C が loc1・計算9の供給側を閉じ、N_V=N_C=N_g=0。B15全22行と76行の入力の証拠は群 C の最終表を使う。
