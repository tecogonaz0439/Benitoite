# 申し送り59行の受け口と読者

生成物（[records.py](records.py)）。読者の型又は値の定数の閉包に証拠が含まれることを確かめた。経路は handoffs.json。

| 行 | 分類 | 単位 | 証拠 | 読者 | 状態 | 読者のない証拠 | 注記 |
|---|---|---|---|---|---|---|---|
| H01 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70の全開始の合成。C06/C12を継承 |
| H02 | L60受持 | .14/.17 | `StateTyE.externalRef_contract_inputs` | なし | 未使用（後段の読者） | なし | 名前付きの読者はなく、既定ビルドの適用例が読む。L70は全合成 |
| H03 | L60受持 | .24〜.29 | `ScopeResponse.response` | `StandardModel.scope_rows`・`StandardModel.normal_facts` | 読者あり | なし | L70へ全実行 |
| H04 | L60受持 | .28/.29 | `ScopedIOResponse.response` | `StandardModel.io_rows` | 読者あり | なし | 全位置の到達はL70、実装はR30/R50 |
| H05 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | R30/R50の同じ要求の比較 |
| H06 | L60受持 | .21/.23/.29 | `StandardModel.sig_scoped`・`StandardModel.body_scoped` | `StandardModel.core`・`StandardModel.program_wellFormed` | 読者あり | なし | ソース生成はL70/R10b |
| H07 | L60受持 | .12/.13/.22 | `ExternalModels.conditions` | `ExternalModels.ModelCase.composition` | 読者あり | なし |  |
| H08 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70の初期表層・全到達 |
| H09 | L60受持 | .22/.29 | `ModelConstraints.sat_values`・`ModelConstraints.sat_subst` | `StandardModel.substitution_assumptions` | 読者あり | なし |  |
| H10 | L60受持 | .22/.29 | `ModelConstraints.sat_rename`・`ModelConstraints.sat_renameTypes`・`ModelConstraints.admits_renameTypes` | `StandardModel.substitution_assumptions` | 読者あり | なし |  |
| H11 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70の全効果、R30の実発行 |
| H12 | L60受持 | .28/.29 | `StandardModel.io_op` | `StandardModel.core` | 読者あり | なし |  |
| H13 | L60受持 | .23/.27/.29 | `StandardModel.http_declarations`・`StandardModel.core_arity` | `StandardModel.program_typed`・`StandardModel.cons_scoped` | 読者あり | なし |  |
| H14 | L60受持 | .10/.11/.14 | `Builtins.ExternalAssumptions.external_adequate`・`Builtins.ExternalAssumptions.received_value` | `ExternalModel.receive_value`・`step_external_selected` | 読者あり | なし |  |
| H15 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | R30/R50の同じ保持値の受理・拒否 |
| H16 | L60受持 | .21/.28/.29 | `StandardModel.resource_table` | `StandardModel.release_all` | 読者あり | なし | R30は実装側 |
| H17 | 既済み継承 | C18 | `AtPrepared.request`・`Val.reqTarget_kind`・`checkAt.absolute` | なし | 既済み継承（L60で再実装・再読者なし） | なし | 再証明しない |
| H18 | 既済み継承 | C18 | `HasTypeVQ.data_observation`・`Detail.match_pattern_typed` | なし | 既済み継承（L60で再実装・再読者なし） | なし | 公開形はU02後の別作業 |
| H19 | L60受持 | .28/.29 | `ScopeResponse.response` | `StandardModel.scope_rows` | 読者あり | なし | R50へ二つのlength観測を渡す（L60.33） |
| H20 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | U02後の公開写し/L70/R30/R60 |
| H21 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | U02確定後・L70前の別作業 |
| H22 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70の全主定理 |
| H23 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | R30/R50のPathBases偽造拒否 |
| H24 | L60受持 | .29/.30 | `StandardModel.pure_rows`・`StandardModel.io_rows` | `StandardModel.core` | 読者あり | なし | O144は他段（obligations） |
| H25 | L60受持 | .23/.26/.27/.29 | `StandardModel.table` | `StandardModel.collection_rows` | 読者あり | なし | ソース合成と全比較はL70/R10b/R50 |
| H26 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | R50のRustとの比較と設計者の登録判断 |
| H27 | L60受持 | .10〜.13/.19〜.22 | `ExternalModels.conditions`・`ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` | 読者あり | なし |  |
| H28 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70/R50の全開始・全応答 |
| H29 | L60受持 | .10/.19/.28 | `StandardModel.io_rows`・`StandardModel.external_assumptions` | `StandardModel.core` | 読者あり | なし | 実IOの固定σはR30 |
| H30 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70/F-REG、R50/F-CONN |
| H31 | L60受持 | .10/.11/.14 | `Builtins.ExternalAssumptions.external_adequate` | `step_external_selected` | 読者あり | なし | 公開元入力の再点検はU02後 |
| S01 | L60受持 | .21/.29 | `StandardModel.sig_scoped` | `StandardModel.core` | 読者あり | なし | H06へ合流 |
| S02 | L60受持 | .22/.29 | `ModelConstraints.sat`・`ModelConstraints.admits` | `StandardModel.substitution_assumptions` | 読者あり | なし |  |
| S03 | L60受持 | .24〜.29 | `ScopeResponse.response` | `StandardModel.scope_rows` | 読者あり | なし | PreparedLeafの再定義なし |
| S04 | L60受持 | .29/.30 | `PreparedLeaf.machine_exact` | なし | 未使用（後段の読者） | なし | 算法一致は型付けから推測しない。R50の算法比較 |
| S05 | L60受持 | .19/.22/.29 | `StandardModel.core`・`StandardModel.targets` | なし | 未使用（後段の読者） | なし | L70が読む |
| S06 | L60受持 | .21/.29 | `StandardModel.reference_rows`・`StandardModel.store_shape` | `StandardModel.core` | 読者あり | `StandardModel.reference_rows` |  |
| S07 | L60受持 | .34 | なし | なし | 群Hの単位へ（群Gの分なし） | なし | 群Hの単位（01-12の写し） |
| S08 | L60受持 | .10/.11 | `ExternalModel.receive_value`・`ExternalModel.receive_reject` | `ExternalModels.responses` | 読者あり | なし |  |
| S09 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | L70/R50はRust受理→ExternalSignature.WFの一方向 |
| S10 | 既済み継承 | C03 | `ExternalCallAdmissible.types_nil` | なし | 既済み継承（L60で再実装・再読者なし） | なし | 多相外部を追加しない |
| S11 | 既済み継承 | C11/C12 | `StateTyE.external_apply_all` | `step_external_apply` | 既済み継承（L60の読者あり） | なし |  |
| S12 | L60受持 | .08/.11 | `ExternalSignatureLeaves.handle_arguments` | `ExternalModels.handle_inputs` | 読者あり | なし |  |
| S13 | L60受持 | .11 | `ExternalModelExamples.receive_pair`・`ExternalCarrier.accepted` | `ExternalModels.responses` | 読者あり | `ExternalCarrier.accepted` | 任意深さは記号の深さの帰納 |
| S14 | 他段受持 |  | なし | なし | 他段（L60の読者なし） | なし | R50/L70の既定所有 |
| S15 | L60受持 | .21/.29 | `BuiltinArgs`・`BuiltinArgs.normalized` | `StandardModel.pure_rows` | 読者あり | `BuiltinArgs.normalized` | Canonicalを外していない |
| S16 | L60受持 | .21/.29 | `StandardModel.opEff_io`・`StandardModel.effect_ops` | `StandardModel.core` | 読者あり | なし |  |
| S17 | L60受持 | .21/.29 | `StandardModel.sig_scoped` | `StandardModel.core` | 読者あり | なし |  |
| S18 | L60受持 | .23/.27/.29 | `StandardModel.core_arity`・`StandardModel.http_declarations` | `StandardModel.body_typed`・`StandardModel.program_typed` | 読者あり | なし |  |
| S19 | L60受持 | .04/.25/.26/.33 | なし | なし | 記録で照合（function-values.json） | なし | 関数値が到達しうる27行を族ごとに照合し、二表現の比較の入力としてR50へ（L60.33） |
| S20 | L60受持 | .24 | `StandardNumericRemainingResponse.response` | `StandardModel.numeric_rows` | 読者あり | なし |  |
| S21 | L60受持 | .23〜.29 | なし | なし | 記録で照合（本記録のtable_responseの閉包） | なし | 合成表の宣言は table_response に依存しない（閉包で照合） |
| S22 | L60受持 | .25/.29/.30 | `StandardOperatorResponse.response`・`StandardStructuralEqualityResponse.response` | `StandardModel.operator_rows` | 読者あり | なし |  |
| S23 | L60受持 | .12/.19/.22 | `ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` | 読者あり | なし |  |
| S24 | L60受持 | .13/.19/.22 | `ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` | 読者あり | なし |  |
| S25 | L60受持 | .13/.22 | `ExternalModels.conditions` | `ExternalModels.ModelCase.composition` | 読者あり | なし |  |
| S26 | L60受持 | .31 | なし | なし | 記録で照合（本記録） | なし | 本記録の型と値の閉包の照合 |
| S27 | L60受持 | .32 | なし | なし | 記録で照合（conditions.json） | なし | conditions.json の別集計 |
| S28 | L60受持 | .19/.32 | `ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` | 読者あり | なし |  |
