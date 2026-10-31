# `.02b-closures` の公開宣言と変更した入口

共通接頭辞は `Benitoite.Release.Refinement.` である。構成子・射影・recursor・自動生成の等式定理・非公開の補助は下表へ重ねない。それらも含む全宣言は [A-L](02b-closures-axioms.lean) と [集計](02b-closures-axioms-summary.json)で照合する。

| 本番モジュール | 新しく置いた手書きの公開宣言（移動は次表） |
|---|---|
| [Capture](../../../formal/Benitoite/Release/Refinement/Capture.lean) | `Tel.SameInputs`、`Tel.RuntimeShape`、`Closure.instantiate` |
| [ClosureTyping](../../../formal/Benitoite/Release/Refinement/ClosureTyping.lean) | `openValue`、`valEnv_openValue`、`Ty.openValue_shift`、`Pred.openValue_lift`、`HasTypeVQ.notContCore`、`SubstOk.openValue`、`SubstOk.annotation`、`HasTypeTelArgsQ.of_arguments`、`CaptureOk.substOk`、`CaptureOk.conditions`、`CaptureOk.transport`、`Tel.bind_values_of_wf_zero`、`Capture.closeTel_instantiate`、`Tel.SameInputs.refl`、`Tel.SameInputs.bind`、`Tel.SameInputs.toTel`、`bindParams_cons`、`Eff.shiftV_add`、`TelBodyTy.toTel_iff`、`closeVal_observation`、`closeVals_observations`、`Tel.instantiate_observations`、`Capture.closeTel_instantiate_runtime`、`CaptureOk.wf`、`CaptureOk.declared`、`ClosureTy.annotation`、`DependentClosureTy.annotation`、`CaptureOk.empty`、`ClosureTy.pure`、`Tel.result`、`Tel.effect`、`Capture.openTel`、`Capture.instantiate` |
| [Narrowing](../../../formal/Benitoite/Release/Refinement/Narrowing.lean) | `TelBodyTy.narrow` |
| [StateTyping](../../../formal/Benitoite/Release/Refinement/StateTyping.lean) | `LocTy.Declared`、`StoreTy.Declared`、`BuilderCellOk`、`ContTy`、`ContTy.adequate`、`EndsWithHandle`、`Frame.Closed`、`Cont.Closed`、`Cell.Closed`、`Store.Closed`、`CellOk`、`StoreOk`、`BuiltinOnly`、`StateTyE`、`StateTy`、`Ty.Declared.closed_context`、`StoreOk.wf`、`StoreOk.declared`、`StoreOk.reference_declared`、`StoreOk.lazy_declared`、`StoreOk.cont_result_declared`、`StoreOk.empty`、`CellOk.adequate`、`StoreOk.adequate`、`HasTypeArmsQ.guard_context` |
| [SubstTyping](../../../formal/Benitoite/Release/Refinement/SubstTyping.lean) | `TelBodyTy.subst` |
| [TypeShiftTyping](../../../formal/Benitoite/Release/Refinement/TypeShiftTyping.lean) | `TelBodyTy.shift_types` |
| [Typing](../../../formal/Benitoite/Release/Refinement/Typing.lean) | `TelBodyTy`、`CaptureOk`、`ClosureTy`、`DependentClosureTy` |
| [TypingShift](../../../formal/Benitoite/Release/Refinement/TypingShift.lean) | `TelBodyTy.shift_values`、`CaptureOk.store`、`ImageOk.store`、`ClosureTy.store`、`DependentClosureTy.store` |

| 移動・改訂した群 | 内容 |
|---|---|
| Ctx.WF | 定義を変えず TypeShiftContext から Admissible へ移した |
| ゼロ移動の既存6名 | shiftIndex_zero/add、Ty/Eff/Pred/Tel の shiftV_zero を TypingStore から TypingShift へ移した。新しい補題には数えない |
| HasTypeVQ/CQ | V_DependentLam/V_Closure/C_DependentApp を追加した。V_Closure は実行用署名と静的契約を RuntimeShape で照合する |
| 相互の値移動 | V/Vs/Each/CQ/Arms/Clauses/Failure/TelArgs/CheckedWitness/AtCall の既存の入口に追加の場合を接続した。TelBodyTy.shift_values と CaptureOk/ImageOk/ClosureTy/DependentClosureTy.store を追加した |
| 型パラメータの移動 | HasTypeVQ/CQ等の shift_types に追加の場合を接続し、TelBodyTy.shift_types を追加した |
| 値の相互置換とNone版 | 公開のHasTypeVQ/CQ等のsubst/subst_under_noneを通る。新しいTelBodyの内部はReturnFreeImagesを使い、公開はTelBodyTy.substである |
| narrowing | HasTypeVQ/CQ等のnarrowを通り、TelBodyTy.narrowを追加した。閉じた捕捉の証拠は再利用する |
| TypedFacts | data_observation/observation_declared/observation_references/observation/assume/assume_optionalの全入口をV28へ追随させた |
| 宣言の正則性・逆転・既存の反例 | TypingDeclaredのV/C、HandlerAlgebraの変数の逆転、HandlerTypingのResumeLの逆転、SubstTypingObstruction/NarrowingObstructionを追随させた |
| 既定import | ClosureTyping/StateTypingの2行をformal/Benitoite.leanへ追加した |

新しい本番ファイルは **ClosureTyping.lean と StateTyping.lean の2件**である。実際の全変更の一覧とハッシュは [source-changes](02b-closures-source-changes.json)を正とする。ContTyの10構成子、CellOkの6場合、StateTyEの4場合はStateTypingへ置いた。StateTyEとStateTyの定義は全状態の保存を証明したことを意味しない。
