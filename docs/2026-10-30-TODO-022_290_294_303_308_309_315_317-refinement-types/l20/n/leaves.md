# 全76遷移の葉と入力の対応

全行の基礎入力は同じ P・B・固定 σ・末尾効果 Eb のソース側 StateTyE である。各行に Step の実際の前提（view 又は code、lookup、照合、応答、空き場所）を加える。行先のコードの型付けは含めない。一般の葉の量化と前提は各宣言の実物を正とする。σ の変更は0件である。

L40 は任意の元状態の canonical forms、値の種別・引数の長さ・セルの形・署名の逆転を供給する。応答と空き場所は .116 と L40/L50/L60 の既存の契約から選ぶ。全保存・進行・step_sound と効果・対象への合成は L70 であり、この表の件数へ数えない。

| 遷移 | モジュールと一般の葉 | 実際の入口・後段との境界 | 区分 |
|---|---|---|---|
| `E_BuilderNew` | `BuilderStateLeaves`：`StateTyE.builder_new` | 元状態と規則の前提、CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_BuilderOp` | `BuilderStateLeaves`：`StateTyE.builder_operation` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_BuilderErr` | `BuilderStateLeaves`：`StateTyE.builder_error` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_Let` | `ClosureStateLeaves`：`StateTyE.let_step` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_Return` | `ClosureStateLeaves`：`StateTyE.return_step` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Lam` | `ClosureStateLeaves`：`StateTyE.dependent_beta_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExternalApply` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_ExternalApply` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_ExternalApply`。Step と行先の StateTyE を返す。 | 継承 |
| `E_External` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_External` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_External`。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExternalErr` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_ExternalErr` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_ExternalErr`。Step と行先の StateTyE を返す。 | 継承 |
| `E_PathBasesApply` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_PathBasesApply` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_PathBasesApply`。Step と行先の StateTyE を返す。 | 継承 |
| `E_IssuePathBases` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_IssuePathBases` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_IssuePathBases`。Step と行先の StateTyE を返す。 | 継承 |
| `E_AtOk` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_AtOk` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_AtOk`。Step と行先の StateTyE を返す。 | 継承 |
| `E_AtError` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_AtError` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_AtError`。Step と行先の StateTyE を返す。 | 継承 |
| `E_AtPrepareError` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_AtPrepareError` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_AtPrepareError`。Step と行先の StateTyE を返す。 | 継承 |
| `E_Fun` | `ClosureStateLeaves`：`StateTyE.fun_step` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Meth` | `ClosureStateLeaves`：`StateTyE.method_step` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Super` | `ClosureStateLeaves`：`StateTyE.super_step` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_IfT` | `PathConditions`：`StateTyE.if_true` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_IfF` | `PathConditions`：`StateTyE.if_false` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_Match` | `MatchPaths`：`StateTyE.match_start` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_MatchSkip` | `MatchPaths`：`StateTyE.match_skip` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_MatchBody` | `MatchStateLeaves`：`StateTyE.match_body` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_MatchGuard` | `MatchStateLeaves`：`StateTyE.match_guard` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_GuardT` | `MatchPaths`：`StateTyE.guard_true` | 元状態と規則の前提、SubstitutionAssumptions。行先の StateTyE を返す。Step は返さない。 SubstitutionAssumptions は `CoreAssumptions.substitutions` から供給する。 | 継承 |
| `E_GuardF` | `MatchPaths`：`StateTyE.guard_false` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_ErrPopGuard` | `MatchStateLeaves`：`StateTyE.err_pop_guard` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_ExitPopGuard` | `MatchStateLeaves`：`StateTyE.exit_pop_guard` | 元状態と規則の前提。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_Prim` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_Prim` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_Prim`。Step と行先の StateTyE を返す。 | 継承 |
| `E_Err` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_Err` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_Err`。Step と行先の StateTyE を返す。 | 継承 |
| `E_IO` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_IO` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_IO`。Step と行先の StateTyE を返す。 | 継承 |
| `E_IOErr` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_IOErr` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_IOErr`。Step と行先の StateTyE を返す。 | 継承 |
| `E_Exit` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_Exit` | 一括入口の元状態・WellFormed・WellTyped・CoreAssumptions・σ.Valid と `StoreReplyInputs.E_Exit`。Step と行先の StateTyE を返す。 | 継承 |
| `E_RefNew` | `StateLeaves`：`StateTyE.reference_new_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_RefGet` | `StateLeaves`：`StateTyE.reference_get_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_RefSet` | `StateLeaves`：`StateTyE.reference_set_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_RefUpdate` | `StateLeaves`：`StateTyE.reference_update_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Lazy` | `LazyPreservation`：`StateTyE.lazy_transition` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ForceDone` | `StateLeaves`：`StateTyE.force_done_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Force` | `StateLeaves`：`StateTyE.force_thunk_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Update` | `StateLeaves`：`StateTyE.lazy_update_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Mark` | `ClosureStateLeaves`：`StateTyE.mark_step` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_EscLet` | `StateLeaves`：`StateTyE.escape_let` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 追加 |
| `E_EscHandle` | `StateLeaves`：`StateTyE.escape_handler` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 追加 |
| `E_EscMark` | `StateLeaves`：`StateTyE.escape_mark` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 追加 |
| `E_Use` | `HandlerGeneral`：`StateTyE.use_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_Release` | `HandlerGeneral`：`StateTyE.return_release` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_RelErr` | `HandlerGeneral`：`StateTyE.return_release_failure` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_EscRel` | `HandlerGeneral`：`StateTyE.escape_release` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_EscRelErr` | `HandlerGeneral`：`StateTyE.escape_release_failure` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ErrPopLet` | `StateLeaves`：`StateTyE.error_let` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 追加 |
| `E_ErrPopMark` | `StateLeaves`：`StateTyE.error_mark` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 追加 |
| `E_ErrPopUpdate` | `LazyPreservation`：`StateTyE.lazy_update_pop_error` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ErrPopHandle` | `HandlerGeneral`：`StateTyE.error_handler` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ErrRel` | `HandlerGeneral`：`StateTyE.error_release` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ErrRelErr` | `HandlerGeneral`：`StateTyE.error_release_failure` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExitPopLet` | `StateLeaves`：`StateTyE.exit_let` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 追加 |
| `E_ExitPopMark` | `StateLeaves`：`StateTyE.exit_mark` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 追加 |
| `E_ExitPopUpdate` | `LazyPreservation`：`StateTyE.lazy_update_pop_exit` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExitPopHandle` | `HandlerGeneral`：`StateTyE.exit_handler` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExitRel` | `HandlerGeneral`：`StateTyE.exit_release` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExitRelErr` | `HandlerGeneral`：`StateTyE.exit_release_failure` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_Handle` | `HandlerGeneral`：`StateTyE.handle_step` | 元状態と規則の前提、CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_HRet` | `HandlerGeneral`：`StateTyE.handler_return` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_Op` | `HandlerGeneral`：`StateTyE.operation_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_OpFail` | `HandlerGeneral`：`StateTyE.operation_failure` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_OpPrim` | `HandlerGeneral`：`StateTyE.operation_primitive` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions・EffectsOk。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_Resume` | `HandlerGeneral`：`StateTyE.resume_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。行先の StateTyE を返す。Step は返さない。 | 継承 |
| `E_ResumeErr` | `HandlerPreservation`：`StateTyE.resume_used` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_Drop` | `HandlerGeneral`：`StateTyE.drop_used_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_DropRel` | `HandlerGeneral`：`StateTyE.drop_release_all` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions・EffectsOk。Step と行先の StateTyE を返す。 | 継承 |
| `E_EscDrop` | `HandlerGeneral`：`StateTyE.escape_drop_used` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions。Step と行先の StateTyE を返す。 | 継承 |
| `E_EscDropRel` | `HandlerGeneral`：`StateTyE.escape_drop_release` | 元状態と規則の前提、WellFormed・WellTyped・CoreAssumptions・EffectsOk。Step と行先の StateTyE を返す。 | 継承 |
| `E_ErrDrop` | `HandlerGeneral`：`StateTyE.error_drop` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ErrDropRel` | `HandlerPreservation`：`StateTyE.err_drop_rel` | 元状態と規則の前提、EffectsOk。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExitDrop` | `HandlerGeneral`：`StateTyE.exit_drop` | 元状態と規則の前提。Step と行先の StateTyE を返す。 | 継承 |
| `E_ExitDropRel` | `HandlerPreservation`：`StateTyE.exit_drop_rel` | 元状態と規則の前提、EffectsOk。Step と行先の StateTyE を返す。 | 継承 |

一般の葉69遷移を継承し、制御の7遷移を本担当で追加する。代表の match_body_zero・handler_return_const・drop_used_const・resume_const・drop_rel_const・esc_drop_rel_const は一般の葉へ数えない。既定 import に残るこれらは限定された具体の構成・適用の入口であり、一般の状態の証拠は上表の別の葉が受け持つ。

捕捉の読まれない位置の局所参照については群 L の全76行のソース点検を継承する。専用セルの参照・更新と、本体としてのコード実行が対象である。δ が構文の場所番号を読むことと区別する。新しい7遷移は継続枠を外し、view の escape 値又はエラー理由を渡すだけで、捕捉の全位置を走査しない。
