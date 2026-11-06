import Benitoite.Release.Refinement.Surface.CheckOpenExprSimpleSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprHeadSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprCallSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprControlSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprCollectionSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprRecordSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprPartialSound
import Benitoite.Release.Refinement.Surface.CheckOpenExprSpecialSound
import Benitoite.Release.Refinement.Surface.CheckOpenTrySound
import Benitoite.Release.Refinement.Surface.CheckOpenCollectionSound
import Benitoite.Release.Refinement.Surface.CheckOpenBlockSound
import Benitoite.Release.Refinement.Surface.CheckOpenResultSound

/-! 検査の全ての式・ブロック・補助判断の、案内による相互帰納の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments

theorem checkExprAt_step {g : Guide} (ih : SoundBelow g) : ExprSoundAt g := by
  cases g with
  | unknown =>
    intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
    rw [checkExprAt.eq_def] at hc
    simp only [Bool.and_false, Bool.false_eq_true] at hc
  | failure failure =>
    intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
    rw [checkExprAt.eq_def] at hc
    simp only [Bool.and_false, Bool.false_eq_true] at hc
  | node rule h cs =>
    cases rule
    case E_BuilderOp => exact builderOp_step ih
    case E_Local => exact local_step
    case E_Const => exact const_step ih
    case E_Fun => exact fun_step
    case E_Prim => exact prim_step
    case E_Op => exact op_step
    case E_FunDicts => exact funDicts_step
    case E_MethName => exact methName_step
    case E_OpDicts => exact opDicts_step
    case E_Raise => exact raise_step
    case E_HandleFail => exact handleFail_step ih
    case E_ExternalName => exact externalName_step
    case E_NullCon => exact nullCon_step
    case E_ConValue => exact conValue_step
    case E_Literal => exact literal_step
    case E_NegInt => exact negInt_step
    case E_NegFloat => exact negFloat_step
    case E_NegDecimal => exact negDecimal_step
    case E_NegInteger8 => exact negInteger8_step
    case E_NegInteger16 => exact negInteger16_step
    case E_NegInteger32 => exact negInteger32_step
    case E_NegFloat32 => exact negFloat32_step
    case E_Unit => exact unit_step
    case E_Block => exact block_step ih
    case E_Paren => exact paren_step ih
    case E_Refine => exact refine_step ih
    case E_Sub => exact sub_step ih
    case E_Record => exact record_step ih
    case E_RecordRefined => exact recordRefined_step ih
    case E_RecordUpdate => exact recordUpdate_step ih
    case E_RecordUpdateRefined => exact recordUpdateRefined_step ih
    case E_ConCall => exact conCall_step ih
    case E_CallDirect => exact callDirect_step ih
    case E_CallExternal => exact callExternal_step ih
    case E_Call => exact call_step ih
    case E_PipeConCall => exact pipeConCall_step ih
    case E_PipeConValue => exact pipeConValue_step ih
    case E_PipeCallDirect => exact pipeCallDirect_step ih
    case E_PipeCall => exact pipeCall_step ih
    case E_PipeApplyDirect => exact pipeApplyDirect_step ih
    case E_PipeApply => exact pipeApply_step ih
    case E_PartialCallDirect => exact partialCallDirect_step ih
    case E_PartialCall => exact partialCall_step ih
    case E_PartialCallDirectDep => exact partialCallDirectDep_step ih
    case E_PartialCallDep => exact partialCallDep_step ih
    case E_PartialCon => exact partialCon_step ih
    case E_Binary => exact binary_step ih
    case E_Neg => exact neg_step ih
    case E_Not => exact not_step ih
    case E_And => exact and_step ih
    case E_Or => exact or_step ih
    case E_List => exact list_step ih
    case E_ListRefined => exact listRefined_step ih
    case E_ListSpread => exact listSpread_step ih
    case E_Interpolation => exact interpolation_step ih
    case E_Lam => exact lam_step ih
    case E_If => exact if_step ih
    case E_ElseIf => exact elseIf_step ih
    case E_IfOnly => exact ifOnly_step ih
    case E_Match => exact match_step ih
    case E_ReturnTail => exact returnTail_step ih
    case E_ReturnOther => exact returnOther_step ih
    case E_TryResult => exact tryResult_step ih
    case E_TryOption => exact tryOption_step ih
    case E_TryResultDie => exact tryResultDie_step ih
    case E_TryResultDieMessage => exact tryResultDieMessage_step ih
    case E_TryOptionDie => exact tryOptionDie_step ih
    case E_TryOptionDieMessage => exact tryOptionDieMessage_step ih
    case E_With => exact with_step ih
    case E_Lazy => exact lazy_step ih
    case E_Handle => exact handle_step ih
    case E_Resume => exact resume_step ih
    all_goals
      intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
      rw [checkExprAt.eq_def] at hc
      dsimp only at hc
      have hf := (Bool.and_eq_true_iff.mp hc).2
      cases hf

/-- 有限な案内の大きさの帰納により、七つの判断を全入力について同時に得る。 -/
theorem guideSound (g : Guide) : GuideSound g :=
  (measure sizeOf).wf.induction g (fun g ih =>
    ⟨checkExprAt_step ih, checkTypesAt_step ih, checkEachAt_step ih, checkFixedAt_step ih,
      checkArmsAt_step ih, checkClausesAt_step ih, checkBlockAt_step g ih⟩)

theorem checkBlockAt_sound {g : Guide} : BlockSoundAt g := (guideSound g).block

end Benitoite.Release.Refinement.Surface.CheckOpen
