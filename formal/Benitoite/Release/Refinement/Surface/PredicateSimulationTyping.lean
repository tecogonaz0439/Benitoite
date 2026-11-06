import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.InversionCore

/-! # 解決後の型付けが除く、判定結果へのパイプ適用 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

set_option maxHeartbeats 400000 in
private theorem result_not_function {D B op Q Δ C Γ Φ R position expression a ε}
    (typed : HasTypeQ D B op Q Δ C Γ Φ R position expression a ε)
    {name types effects ranges arguments result effect}
    (shape : expression = .partialCall (.primName name types effects ranges) [] arguments result effect)
    (holes : arguments.holeTypes = []) (nonFunction : result.fnCore = none) : a.fnCore = none := by
  match typed with
  | .E_Sub child le covers annotation =>
    have source := result_not_function child shape holes nonFunction
    cases found : a.fnCore with
    | none => rfl
    | some telescope =>
      obtain ⟨other, impossible, relation⟩ := le.fnCore_right found
      rw [source] at impossible
      cases impossible
  | .E_Refine child value .. => cases shape; cases value
  | .E_PredicateCall .. => cases shape; exact nonFunction
  | .E_PredicateProject .. => cases shape; exact nonFunction
  | .E_PartialCallDirect notEmpty .. | .E_PartialCallDirectDep notEmpty .. =>
    cases shape; exact False.elim (notEmpty holes)
  | .E_PartialCall notDirect notEmpty .. | .E_PartialCallDep notDirect notEmpty .. =>
    cases shape; exact False.elim (notEmpty holes)
  | .E_BuilderOp .. => cases shape
  | .E_Local .. => cases shape
  | .E_Const .. => cases shape
  | .E_Fun .. => cases shape
  | .E_FunDicts .. => cases shape
  | .E_MethName .. => cases shape
  | .E_Prim .. => cases shape
  | .E_Raise .. => cases shape
  | .E_HandleFail .. => cases shape
  | .E_Op .. => cases shape
  | .E_OpDicts .. => cases shape
  | .E_ExternalName .. => cases shape
  | .E_NullCon .. => cases shape
  | .E_ConValue .. => cases shape
  | .E_Literal .. => cases shape
  | .E_NegInt .. => cases shape
  | .E_NegFloat .. => cases shape
  | .E_NegDecimal .. => cases shape
  | .E_NegInteger8 .. => cases shape
  | .E_NegInteger16 .. => cases shape
  | .E_NegInteger32 .. => cases shape
  | .E_NegFloat32 .. => cases shape
  | .E_Unit .. => cases shape
  | .E_Block .. => cases shape
  | .E_Paren .. => cases shape
  | .E_Record .. => cases shape
  | .E_RecordUpdate .. => cases shape
  | .E_RecordRefined .. => cases shape
  | .E_RecordUpdateRefined .. => cases shape
  | .E_ConCall .. => cases shape
  | .E_CallDirect .. => cases shape
  | .E_CallExternal .. => cases shape
  | .E_Call .. => cases shape
  | .E_PipeConCall .. => cases shape
  | .E_PipeConValue .. => cases shape
  | .E_PipeCallDirect .. => cases shape
  | .E_PipeCall .. => cases shape
  | .E_PipeApplyDirect .. => cases shape
  | .E_PipeApply .. => cases shape
  | .E_PartialCon .. => cases shape
  | .E_Binary .. => cases shape
  | .E_Neg .. => cases shape
  | .E_Not .. => cases shape
  | .E_And .. => cases shape
  | .E_Or .. => cases shape
  | .E_List .. => cases shape
  | .E_ListRefined .. => cases shape
  | .E_ListSpread .. => cases shape
  | .E_Interpolation .. => cases shape
  | .E_Lam .. => cases shape
  | .E_If .. => cases shape
  | .E_ElseIf .. => cases shape
  | .E_IfOnly .. => cases shape
  | .E_Match .. => cases shape
  | .E_ReturnTail .. => cases shape
  | .E_ReturnOther .. => cases shape
  | .E_TryResult .. => cases shape
  | .E_TryOption .. => cases shape
  | .E_TryResultDie .. => cases shape
  | .E_TryResultDieMessage .. => cases shape
  | .E_TryOptionDie .. => cases shape
  | .E_TryOptionDieMessage .. => cases shape
  | .E_With .. => cases shape
  | .E_Lazy .. => cases shape
  | .E_Handle .. => cases shape
  | .E_Resume .. => cases shape
termination_by structural typed

/-- 穴のない内部呼出しの明示した結果型が非関数なら、部分型で広げても関数にはならない。 -/
theorem predicate_result_not_function {D B op Q Δ C Γ Φ R position name types effects ranges arguments result effect a ε}
    (holes : arguments.holeTypes = []) (nonFunction : result.fnCore = none)
    (typed : HasTypeQ D B op Q Δ C Γ Φ R position
      (.partialCall (.primName name types effects ranges) [] arguments result effect) a ε) :
    a.fnCore = none := result_not_function typed rfl holes nonFunction

set_option maxHeartbeats 400000 in
private theorem pipe_untypable {D B op Q Δ C Γ Φ R position expression a ε}
    (typed : HasTypeQ D B op Q Δ C Γ Φ R position expression a ε)
    {lhs name types effects ranges arguments result effect}
    (shape : expression = .pipe lhs (.partialCall (.primName name types effects ranges) [] arguments result effect))
    (holes : arguments.holeTypes = []) (nonFunction : result.fnCore = none) : False := by
  match typed with
  | .E_Sub child .. => exact pipe_untypable child shape holes nonFunction
  | .E_Refine child value .. => cases shape; cases value
  | .E_PipeApplyDirect pvalue head .. => cases shape; cases head
  | .E_PipeApply pvalue notDirect source target .. =>
    cases shape
    have impossible := predicate_result_not_function holes nonFunction target
    cases impossible
  | .E_BuilderOp .. => cases shape
  | .E_Local .. => cases shape
  | .E_Const .. => cases shape
  | .E_Fun .. => cases shape
  | .E_FunDicts .. => cases shape
  | .E_MethName .. => cases shape
  | .E_Prim .. => cases shape
  | .E_Raise .. => cases shape
  | .E_HandleFail .. => cases shape
  | .E_Op .. => cases shape
  | .E_OpDicts .. => cases shape
  | .E_ExternalName .. => cases shape
  | .E_NullCon .. => cases shape
  | .E_ConValue .. => cases shape
  | .E_Literal .. => cases shape
  | .E_NegInt .. => cases shape
  | .E_NegFloat .. => cases shape
  | .E_NegDecimal .. => cases shape
  | .E_NegInteger8 .. => cases shape
  | .E_NegInteger16 .. => cases shape
  | .E_NegInteger32 .. => cases shape
  | .E_NegFloat32 .. => cases shape
  | .E_Unit .. => cases shape
  | .E_Block .. => cases shape
  | .E_Paren .. => cases shape
  | .E_Record .. => cases shape
  | .E_RecordUpdate .. => cases shape
  | .E_RecordRefined .. => cases shape
  | .E_RecordUpdateRefined .. => cases shape
  | .E_ConCall .. => cases shape
  | .E_CallDirect .. => cases shape
  | .E_PredicateCall .. => cases shape
  | .E_PredicateProject .. => cases shape
  | .E_CallExternal .. => cases shape
  | .E_Call .. => cases shape
  | .E_PipeConCall .. => cases shape
  | .E_PipeConValue .. => cases shape
  | .E_PipeCallDirect .. => cases shape
  | .E_PipeCall .. => cases shape
  | .E_PartialCallDirect .. => cases shape
  | .E_PartialCall .. => cases shape
  | .E_PartialCallDirectDep .. => cases shape
  | .E_PartialCallDep .. => cases shape
  | .E_PartialCon .. => cases shape
  | .E_Binary .. => cases shape
  | .E_Neg .. => cases shape
  | .E_Not .. => cases shape
  | .E_And .. => cases shape
  | .E_Or .. => cases shape
  | .E_List .. => cases shape
  | .E_ListRefined .. => cases shape
  | .E_ListSpread .. => cases shape
  | .E_Interpolation .. => cases shape
  | .E_Lam .. => cases shape
  | .E_If .. => cases shape
  | .E_ElseIf .. => cases shape
  | .E_IfOnly .. => cases shape
  | .E_Match .. => cases shape
  | .E_ReturnTail .. => cases shape
  | .E_ReturnOther .. => cases shape
  | .E_TryResult .. => cases shape
  | .E_TryOption .. => cases shape
  | .E_TryResultDie .. => cases shape
  | .E_TryResultDieMessage .. => cases shape
  | .E_TryOptionDie .. => cases shape
  | .E_TryOptionDieMessage .. => cases shape
  | .E_With .. => cases shape
  | .E_Lazy .. => cases shape
  | .E_Handle .. => cases shape
  | .E_Resume .. => cases shape
termination_by structural typed

/-- 解決後の非関数の判定をrhsに置いたパイプは、表層の型導出を持たない。 -/
theorem predicate_pipe_untypable {D B op Q Δ C Γ Φ R position lhs name types effects ranges arguments result effect a ε}
    (holes : arguments.holeTypes = []) (nonFunction : result.fnCore = none)
    (typed : HasTypeQ D B op Q Δ C Γ Φ R position
      (.pipe lhs (.partialCall (.primName name types effects ranges) [] arguments result effect)) a ε) : False :=
  pipe_untypable typed rfl holes nonFunction

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
