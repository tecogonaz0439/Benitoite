import Benitoite.Release.Refinement.Surface.PredicateSimulationTyping

/-! # 型付けた本体の内部のパイプの形 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 穴のない非関数の内部呼出しを、パイプの右辺の関数として使わない。 -/
def PipeHeadSafe (rhs : Expr) : Prop :=
  ∀ key types effects ranges arguments result effect,
    rhs = .partialCall (.primName key types effects ranges) [] arguments result effect →
      arguments.holeTypes = [] → result.fnCore = none → False

mutual
  def SafeExpr : Expr → Prop
    | .builderOp _ _ args _ => SafeExprs args
    | .constE _ body | .paren body | .neg _ body | .not body | .returnE _ body
      | .tryResult _ _ _ body | .tryOption _ _ _ body | .resume _ body => SafeExpr body
    | .handleFail _ _ body clause => SafeBlock body ∧ SafeBlock clause
    | .block body | .lam _ _ _ _ body | .lazyE body => SafeBlock body
    | .conCall _ _ args | .record _ _ _ args | .list _ args => SafeExprs args
    | .recordUpdate _ _ _ _ base args => SafeExpr base ∧ SafeExprs args
    | .call head _ _ args => SafeExpr head ∧ SafeExprs args
    | .pipe lhs rhs => SafeExpr lhs ∧ SafeExpr rhs ∧ PipeHeadSafe rhs
    | .partialCall head _ args _ _ => SafeExpr head ∧ SafeHoles args
    | .partialCon _ _ args => SafeHoles args
    | .binary _ _ lhs rhs | .and lhs rhs | .or lhs rhs => SafeExpr lhs ∧ SafeExpr rhs
    | .listSpread _ concat before spread after =>
        SafeExpr concat ∧ SafeExprs before ∧ SafeExpr spread ∧ SafeExprs after
    | .interpolation _ args _ => SafeExprs args
    | .ite cond yes no => SafeExpr cond ∧ SafeBlock yes ∧ SafeBlock no
    | .elseIf cond yes no => SafeExpr cond ∧ SafeBlock yes ∧ SafeExpr no
    | .ifOnly cond yes => SafeExpr cond ∧ SafeBlock yes
    | .matchE _ scrutinee arms => SafeExpr scrutinee ∧ SafeArms arms
    | .tryResultDie _ _ _ _ _ _ body message | .tryOptionDie _ _ _ _ body message =>
        SafeExpr body ∧ (match message with | none => True | some e => SafeExpr e)
    | .withE _ resource body => SafeExpr resource ∧ SafeBlock body
    | .handleE body clauses => SafeBlock body ∧ SafeClauses clauses
    | _ => True
  def SafeExprs : Exprs → Prop
    | .nil => True
    | .cons e es => SafeExpr e ∧ SafeExprs es
  def SafeHoles : HoleArgs → Prop
    | .nil => True
    | .expr _ _ e rest => SafeExpr e ∧ SafeHoles rest
    | .hole _ _ _ rest => SafeHoles rest
  def SafeArms : Arms → Prop
    | .nil => True
    | .cons _ guard body rest =>
        (match guard with | none => True | some e => SafeExpr e) ∧ SafeBlock body ∧ SafeArms rest
  def SafeClauses : Clauses → Prop
    | .nil => True
    | .cons _ _ _ body rest _ => SafeBlock body ∧ SafeClauses rest
  def SafeBlock : Block → Prop
    | .empty => True
    | .builderBind _ rest => SafeBlock rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => SafeExpr e
    | .bind _ _ e rest | .discard e rest | .seq e rest | .bindPat _ _ _ e rest => SafeExpr e ∧ SafeBlock rest
end

theorem SafeExpr.of_value {expression value} (valued : expression.valueOf? = some value) :
    SafeExpr expression := by
  cases expression <;> simp_all only [Expr.valueOf?,SafeExpr,reduceCtorEq]

private theorem callHead_safe {D B Q C Γ expression telescope dictionaries}
    (typed : CallHeadTy D B Q C Γ expression telescope dictionaries) : SafeExpr expression := by
  cases typed <;> trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation

namespace Benitoite.Release.Refinement.Surface
open PredicateSimulation
noncomputable section

macro "predicate_safety_case" outer:term : tactic => do
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
  theorem HasTypeQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R position expression a ε}
      (typed : HasTypeQ D B op Q Δ C Γ Φ R position expression a ε) : SafeExpr expression := by
    have head : ∀ lhs rhs, expression = .pipe lhs rhs → PipeHeadSafe rhs := by
      intro lhs rhs same key types effects ranges arguments result effect shape holes nonFunction
      subst expression
      subst rhs
      exact predicate_pipe_untypable holes nonFunction typed
    match typed with
    | .E_BuilderOp .. => predicate_safety_case head
    | .E_Local .. => predicate_safety_case head
    | .E_Const .. => predicate_safety_case head
    | .E_Fun .. => predicate_safety_case head
    | .E_FunDicts .. => predicate_safety_case head
    | .E_MethName .. => predicate_safety_case head
    | .E_Prim .. => predicate_safety_case head
    | .E_Raise .. => predicate_safety_case head
    | .E_HandleFail .. => predicate_safety_case head
    | .E_Op .. => predicate_safety_case head
    | .E_OpDicts .. => predicate_safety_case head
    | .E_ExternalName .. => predicate_safety_case head
    | .E_NullCon .. => predicate_safety_case head
    | .E_ConValue .. => predicate_safety_case head
    | .E_Refine .. => predicate_safety_case head
    | .E_Literal .. => predicate_safety_case head
    | .E_NegInt .. => predicate_safety_case head
    | .E_NegFloat .. => predicate_safety_case head
    | .E_NegDecimal .. => predicate_safety_case head
    | .E_NegInteger8 .. => predicate_safety_case head
    | .E_NegInteger16 .. => predicate_safety_case head
    | .E_NegInteger32 .. => predicate_safety_case head
    | .E_NegFloat32 .. => predicate_safety_case head
    | .E_Unit .. => predicate_safety_case head
    | .E_Block .. => predicate_safety_case head
    | .E_Paren .. => predicate_safety_case head
    | .E_Record .. => predicate_safety_case head
    | .E_RecordUpdate .. => predicate_safety_case head
    | .E_RecordRefined .. => predicate_safety_case head
    | .E_RecordUpdateRefined .. => predicate_safety_case head
    | .E_ConCall .. => predicate_safety_case head
    | .E_CallDirect .. => predicate_safety_case head
    | .E_PredicateCall .. => predicate_safety_case head
    | .E_PredicateProject .. => predicate_safety_case head
    | .E_CallExternal .. => predicate_safety_case head
    | .E_Call .. => predicate_safety_case head
    | .E_PipeConCall .. => predicate_safety_case head
    | .E_PipeConValue .. => predicate_safety_case head
    | .E_PipeCallDirect .. => predicate_safety_case head
    | .E_PipeCall .. => predicate_safety_case head
    | .E_PipeApplyDirect .. => predicate_safety_case head
    | .E_PipeApply .. => predicate_safety_case head
    | .E_PartialCallDirect .. => predicate_safety_case head
    | .E_PartialCall .. => predicate_safety_case head
    | .E_PartialCallDirectDep .. => predicate_safety_case head
    | .E_PartialCallDep .. => predicate_safety_case head
    | .E_PartialCon .. => predicate_safety_case head
    | .E_Binary .. => predicate_safety_case head
    | .E_Neg .. => predicate_safety_case head
    | .E_Not .. => predicate_safety_case head
    | .E_And .. => predicate_safety_case head
    | .E_Or .. => predicate_safety_case head
    | .E_List .. => predicate_safety_case head
    | .E_ListRefined .. => predicate_safety_case head
    | .E_ListSpread .. => predicate_safety_case head
    | .E_Interpolation .. => predicate_safety_case head
    | .E_Lam .. => predicate_safety_case head
    | .E_If .. => predicate_safety_case head
    | .E_ElseIf .. => predicate_safety_case head
    | .E_IfOnly .. => predicate_safety_case head
    | .E_Match .. => predicate_safety_case head
    | .E_ReturnTail .. => predicate_safety_case head
    | .E_ReturnOther .. => predicate_safety_case head
    | .E_TryResult .. => predicate_safety_case head
    | .E_TryOption .. => predicate_safety_case head
    | .E_TryResultDie .. => predicate_safety_case head
    | .E_TryResultDieMessage .. => predicate_safety_case head
    | .E_TryOptionDie .. => predicate_safety_case head
    | .E_TryOptionDieMessage .. => predicate_safety_case head
    | .E_With .. => predicate_safety_case head
    | .E_Lazy .. => predicate_safety_case head
    | .E_Handle .. => predicate_safety_case head
    | .E_Resume .. => predicate_safety_case head
    | .E_Sub .. => predicate_safety_case head
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasTypesQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R expressions types ε}
      (typed : HasTypesQ D B op Q Δ C Γ Φ R expressions types ε) : SafeExprs expressions := by
    match typed with
    | .nil .. => predicate_safety_case True.intro
    | .cons .. => predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasEachQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R expressions a ε}
      (typed : HasEachQ D B op Q Δ C Γ Φ R expressions a ε) : SafeExprs expressions := by
    match typed with
    | .nil .. => predicate_safety_case True.intro
    | .cons .. => predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasFixedQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R arguments types ε}
      (typed : HasFixedQ D B op Q Δ C Γ Φ R arguments types ε) : SafeHoles arguments := by
    match typed with
    | .nil .. => predicate_safety_case True.intro
    | .expr .. => predicate_safety_case True.intro
    | .hole .. => predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasArmsQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R position arms a b ε}
      (typed : HasArmsQ D B op Q Δ C Γ Φ R position arms a b ε) : SafeArms arms := by
    match typed with
    | .nil .. => predicate_safety_case True.intro
    | .plain .. => predicate_safety_case True.intro
    | .guarded .. => predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasClausesQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R bodyEffect clauses a ε}
      (typed : HasClausesQ D B op Q Δ C Γ Φ R bodyEffect clauses a ε) : SafeClauses clauses := by
    match typed with
    | .nil .. => predicate_safety_case True.intro
    | .cons .. => predicate_safety_case True.intro
  termination_by structural typed

  /-- 型導出の全ての実行する子について、非関数の内部呼出しへのパイプを除く。 -/
  theorem HasBlockQ.predicate_pipe_safe {D B op Q Δ C Γ Φ R position body a ε}
      (typed : HasBlockQ D B op Q Δ C Γ Φ R position body a ε) : SafeBlock body := by
    match typed with
    | .B_BuilderBind .. => predicate_safety_case True.intro
    | .B_Empty .. => predicate_safety_case True.intro
    | .B_Last .. => predicate_safety_case True.intro
    | .B_LastBind .. => predicate_safety_case True.intro
    | .B_LastDiscard .. => predicate_safety_case True.intro
    | .B_Bind .. => predicate_safety_case True.intro
    | .B_Discard .. => predicate_safety_case True.intro
    | .B_Seq .. => predicate_safety_case True.intro
    | .B_LastPat .. => predicate_safety_case True.intro
    | .B_BindPat .. => predicate_safety_case True.intro
    | .B_Sub .. => predicate_safety_case True.intro
  termination_by structural typed

end

/-- 依存列の全パラメータの下で型付けた関数本体も、同じ形の条件を満たす。 -/
theorem BodyTy.predicate_pipe_safe {D B op Q C Γ Φ telescope body}
    (typed : BodyTy D B op Q C Γ Φ telescope body) : SafeBlock body := by
  induction typed with
  | done typed => exact typed.predicate_pipe_safe
  | param rest ih => exact ih

end
end Benitoite.Release.Refinement.Surface
