import Benitoite.Release.Refinement.Surface.PredicateSimulationPipeSafety

/-! # 開いた範囲の型判断からのパイプの形の条件 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation.OpenPipe
noncomputable section
set_option maxHeartbeats 400000 in
private theorem result_not_function {D B ks op Q Δ C Γ Φ R position expression a ε}
    (typed : OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R position expression a ε)
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
theorem predicate_result_not_function {D B ks op Q Δ C Γ Φ R position name types effects ranges arguments result effect a ε}
    (holes : arguments.holeTypes = []) (nonFunction : result.fnCore = none)
    (typed : OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R position
      (.partialCall (.primName name types effects ranges) [] arguments result effect) a ε) :
    a.fnCore = none := result_not_function typed rfl holes nonFunction

set_option maxHeartbeats 400000 in
private theorem pipe_untypable {D B ks op Q Δ C Γ Φ R position expression a ε}
    (typed : OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R position expression a ε)
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
theorem predicate_pipe_untypable {D B ks op Q Δ C Γ Φ R position lhs name types effects ranges arguments result effect a ε}
    (holes : arguments.holeTypes = []) (nonFunction : result.fnCore = none)
    (typed : OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R position
      (.pipe lhs (.partialCall (.primName name types effects ranges) [] arguments result effect)) a ε) : False :=
  pipe_untypable typed rfl holes nonFunction

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation.OpenPipe
namespace Benitoite.Release.Refinement.Surface.OpenSurface
open PredicateSimulation
noncomputable section


private theorem callHead_safe {D B ks Q C Γ expression telescope dictionaries}
    (typed : CallHeadTy D B ks Q C Γ expression telescope dictionaries) : SafeExpr expression := by
  cases typed <;> trivial

macro "open_predicate_safety_case" outer:term : tactic => do
  let lemma0 := Lean.mkIdent `HasTypeQ.predicate_pipe_safe
  let lemma1 := Lean.mkIdent `HasTypesQ.predicate_pipe_safe
  let lemma2 := Lean.mkIdent `HasEachQ.predicate_pipe_safe
  let lemma3 := Lean.mkIdent `HasFixedQ.predicate_pipe_safe
  let lemma4 := Lean.mkIdent `HasArmsQ.predicate_pipe_safe
  let lemma5 := Lean.mkIdent `HasClausesQ.predicate_pipe_safe
  let lemma6 := Lean.mkIdent `HasBlockQ.predicate_pipe_safe
  `(tactic| (
    try dsimp only [SafeExpr,SafeExprs,SafeHoles,SafeArms,SafeClauses,SafeBlock]
    repeat' first
      | exact True.intro
      | apply And.intro
      | exact $outer _ _ rfl
      | apply SafeExpr.of_value; assumption
      | apply callHead_safe; assumption
      | apply $lemma0:ident; assumption
      | apply $lemma1:ident; assumption
      | apply $lemma2:ident; assumption
      | apply $lemma3:ident; assumption
      | apply $lemma4:ident; assumption
      | apply $lemma5:ident; assumption
      | apply $lemma6:ident; assumption
))

set_option maxHeartbeats 400000 in
mutual
  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasTypeQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R position expression a ε}
      (typed : HasTypeQ D B ks op Q Δ C Γ Φ R position expression a ε) : SafeExpr expression := by
    have head : ∀ lhs rhs, expression = .pipe lhs rhs → PipeHeadSafe rhs := by
      intro lhs rhs same key types effects ranges arguments result effect shape holes nonFunction
      subst expression
      subst rhs
      exact PredicateSimulation.OpenPipe.predicate_pipe_untypable holes nonFunction typed
    match typed with
    | .E_BuilderOp .. => open_predicate_safety_case head
    | .E_Local .. => open_predicate_safety_case head
    | .E_Const .. => open_predicate_safety_case head
    | .E_Fun .. => open_predicate_safety_case head
    | .E_FunDicts .. => open_predicate_safety_case head
    | .E_MethName .. => open_predicate_safety_case head
    | .E_Prim .. => open_predicate_safety_case head
    | .E_Raise .. => open_predicate_safety_case head
    | .E_HandleFail .. => open_predicate_safety_case head
    | .E_Op .. => open_predicate_safety_case head
    | .E_OpDicts .. => open_predicate_safety_case head
    | .E_ExternalName .. => open_predicate_safety_case head
    | .E_NullCon .. => open_predicate_safety_case head
    | .E_ConValue .. => open_predicate_safety_case head
    | .E_Refine .. => open_predicate_safety_case head
    | .E_Literal .. => open_predicate_safety_case head
    | .E_NegInt .. => open_predicate_safety_case head
    | .E_NegFloat .. => open_predicate_safety_case head
    | .E_NegDecimal .. => open_predicate_safety_case head
    | .E_NegInteger8 .. => open_predicate_safety_case head
    | .E_NegInteger16 .. => open_predicate_safety_case head
    | .E_NegInteger32 .. => open_predicate_safety_case head
    | .E_NegFloat32 .. => open_predicate_safety_case head
    | .E_Unit .. => open_predicate_safety_case head
    | .E_Block .. => open_predicate_safety_case head
    | .E_Paren .. => open_predicate_safety_case head
    | .E_Record .. => open_predicate_safety_case head
    | .E_RecordUpdate .. => open_predicate_safety_case head
    | .E_RecordRefined .. => open_predicate_safety_case head
    | .E_RecordUpdateRefined .. => open_predicate_safety_case head
    | .E_ConCall .. => open_predicate_safety_case head
    | .E_CallDirect .. => open_predicate_safety_case head
    | .E_PredicateCall .. => open_predicate_safety_case head
    | .E_PredicateProject .. => open_predicate_safety_case head
    | .E_CallExternal .. => open_predicate_safety_case head
    | .E_Call .. => open_predicate_safety_case head
    | .E_PipeConCall .. => open_predicate_safety_case head
    | .E_PipeConValue .. => open_predicate_safety_case head
    | .E_PipeCallDirect .. => open_predicate_safety_case head
    | .E_PipeCall .. => open_predicate_safety_case head
    | .E_PipeApplyDirect .. => open_predicate_safety_case head
    | .E_PipeApply .. => open_predicate_safety_case head
    | .E_PartialCallDirect .. => open_predicate_safety_case head
    | .E_PartialCall .. => open_predicate_safety_case head
    | .E_PartialCallDirectDep .. => open_predicate_safety_case head
    | .E_PartialCallDep .. => open_predicate_safety_case head
    | .E_PartialCon .. => open_predicate_safety_case head
    | .E_Binary .. => open_predicate_safety_case head
    | .E_Neg .. => open_predicate_safety_case head
    | .E_Not .. => open_predicate_safety_case head
    | .E_And .. => open_predicate_safety_case head
    | .E_Or .. => open_predicate_safety_case head
    | .E_List .. => open_predicate_safety_case head
    | .E_ListRefined .. => open_predicate_safety_case head
    | .E_ListSpread .. => open_predicate_safety_case head
    | .E_Interpolation .. => open_predicate_safety_case head
    | .E_Lam .. => open_predicate_safety_case head
    | .E_If .. => open_predicate_safety_case head
    | .E_ElseIf .. => open_predicate_safety_case head
    | .E_IfOnly .. => open_predicate_safety_case head
    | .E_Match .. => open_predicate_safety_case head
    | .E_ReturnTail .. => open_predicate_safety_case head
    | .E_ReturnOther .. => open_predicate_safety_case head
    | .E_TryResult .. => open_predicate_safety_case head
    | .E_TryOption .. => open_predicate_safety_case head
    | .E_TryResultDie .. => open_predicate_safety_case head
    | .E_TryResultDieMessage .. => open_predicate_safety_case head
    | .E_TryOptionDie .. => open_predicate_safety_case head
    | .E_TryOptionDieMessage .. => open_predicate_safety_case head
    | .E_With .. => open_predicate_safety_case head
    | .E_Lazy .. => open_predicate_safety_case head
    | .E_Handle .. => open_predicate_safety_case head
    | .E_Resume .. => open_predicate_safety_case head
    | .E_Sub .. => open_predicate_safety_case head
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasTypesQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R expressions types ε}
      (typed : HasTypesQ D B ks op Q Δ C Γ Φ R expressions types ε) : SafeExprs expressions := by
    match typed with
    | .nil .. => open_predicate_safety_case True.intro
    | .cons .. => open_predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasEachQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R expressions a ε}
      (typed : HasEachQ D B ks op Q Δ C Γ Φ R expressions a ε) : SafeExprs expressions := by
    match typed with
    | .nil .. => open_predicate_safety_case True.intro
    | .cons .. => open_predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasFixedQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R arguments types ε}
      (typed : HasFixedQ D B ks op Q Δ C Γ Φ R arguments types ε) : SafeHoles arguments := by
    match typed with
    | .nil .. => open_predicate_safety_case True.intro
    | .expr .. => open_predicate_safety_case True.intro
    | .hole .. => open_predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasArmsQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R position arms a b ε}
      (typed : HasArmsQ D B ks op Q Δ C Γ Φ R position arms a b ε) : SafeArms arms := by
    match typed with
    | .nil .. => open_predicate_safety_case True.intro
    | .plain .. => open_predicate_safety_case True.intro
    | .guarded .. => open_predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasClausesQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R bodyEffect clauses a ε}
      (typed : HasClausesQ D B ks op Q Δ C Γ Φ R bodyEffect clauses a ε) : SafeClauses clauses := by
    match typed with
    | .nil .. => open_predicate_safety_case True.intro
    | .closed _ closed => exact Surface.HasClausesQ.predicate_pipe_safe closed
    | .cons .. => open_predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasBlockQ.predicate_pipe_safe {D B ks op Q Δ C Γ Φ R position body a ε}
      (typed : HasBlockQ D B ks op Q Δ C Γ Φ R position body a ε) : SafeBlock body := by
    match typed with
    | .B_BuilderBind .. => open_predicate_safety_case True.intro
    | .B_Empty .. => open_predicate_safety_case True.intro
    | .B_Last .. => open_predicate_safety_case True.intro
    | .B_LastBind .. => open_predicate_safety_case True.intro
    | .B_LastDiscard .. => open_predicate_safety_case True.intro
    | .B_Bind .. => open_predicate_safety_case True.intro
    | .B_Discard .. => open_predicate_safety_case True.intro
    | .B_Seq .. => open_predicate_safety_case True.intro
    | .B_LastPat .. => open_predicate_safety_case True.intro
    | .B_BindPat .. => open_predicate_safety_case True.intro
    | .B_Sub .. => open_predicate_safety_case True.intro
  termination_by structural typed

end

/-- 依存列の全パラメータの下で型付けた関数本体も、同じ形の条件を満たす。 -/
theorem BodyTy.predicate_pipe_safe {D B ks op Q C Γ Φ telescope body}
    (typed : BodyTy D B ks op Q C Γ Φ telescope body) : SafeBlock body := by
  induction typed with
  | done typed => exact typed.predicate_pipe_safe
  | param rest ih => exact ih

end
end Benitoite.Release.Refinement.Surface.OpenSurface

namespace Benitoite.Release.Refinement.Surface
open PredicateSimulation
/-- 空と非空の範囲文脈の両方で、関数本体の同じ構文条件を供給する。 -/
theorem BodyTyR.predicate_pipe_safe {D B op Q ks C Γ Φ telescope body}
    (typed : BodyTyR D B op Q ks C Γ Φ telescope body) : SafeBlock body := by
  unfold BodyTyR at typed
  split at typed
  · exact typed.predicate_pipe_safe
  · exact typed.predicate_pipe_safe
end Benitoite.Release.Refinement.Surface
