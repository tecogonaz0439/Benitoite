import Benitoite.Release.Refinement.SurfaceTargetStepExamples
import Benitoite.Release.Refinement.FailureExamples
import Benitoite.Release.Refinement.CoverageExamples
import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.CoverageRuntime

/-!
# Result の二構成子の値と、Fail を Result へ変換する handle の型付け

標準の型の宣言（`Result` を含む）を収集した表層のプログラムを脱糖した核のプログラムで、`Result.Ok`・`Result.Error` の
値がそれぞれ成功の型とエラーの型の値から `Result` の型を持ち、取り違えないこと（`result_values_typed`）、Fail を
処理して Result を返す通常の handle が空の効果で型付くこと（`toResult_typed`）を確かめる。変換の有限遷移は
`FailureExamples` が示す（設計書 01-12「実行の規則」）。
-/
namespace Benitoite.Release.Refinement.FailureTypingExamples
noncomputable section
open StandardModel Surface.TargetObservedExamples Surface.TargetStepExamples

abbrev intTy : Ty := .base .integer
abbrev strTy : Ty := .base .string
abbrev resultTy : Ty := .data "Result" [intTy, strTy]
def okValue (v : Val) : Val := .con "Result.Ok" [intTy, strTy] [v]
def errorValue (v : Val) : Val := .con "Result.Error" [intTy, strTy] [v]

def failClause : List Clause := [.fail strTy (.ret (errorValue (.var 1)))]
def toResult (body : Comp) : Comp := .handle (.letIn body (.ret (okValue (.var 0)))) failClause

private theorem result_annotation_at (p : String) (C : TypeCtx) (Γ : Ctx) : Ty.Annotation (core p) C Γ resultTy := by
  have hr := (hasFile p) ScopeDeclarations.result (by simp [ScopeDeclarations.file])
  exact ⟨⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩, ⟨⟨2, hr.1, rfl⟩, trivial, trivial, trivial⟩⟩

private theorem kinds (p : String) (C : TypeCtx) :
    TypeArgsKinded (core p) C [intTy, strTy] [.value, .value] := by
  refine ⟨rfl, ?_⟩
  rintro (_|(_|i)) t k ht hk
  · cases ht; cases hk; exact ⟨by trivial, fun _ => by simp [Ordinary]⟩
  · cases ht; cases hk; exact ⟨by trivial, fun _ => by simp [Ordinary]⟩
  · simp at ht

/-- Result の二構成子は同じ宣言を使い、成功値とエラー値を取り違えない。 -/
theorem result_values_typed (p : String) {B Ψ Q C Γ Φ v} :
    (HasTypeVQ (core p) B Ψ Q C Γ Φ v intTy → HasTypeVQ (core p) B Ψ Q C Γ Φ (okValue v) resultTy) ∧
    (HasTypeVQ (core p) B Ψ Q C Γ Φ v strTy → HasTypeVQ (core p) B Ψ Q C Γ Φ (errorValue v) resultTy) := by
  have hr := (hasFile p) ScopeDeclarations.result (by simp [ScopeDeclarations.file])
  constructor
  · intro hv
    refine .V_Con (hr.2 ("Result.Ok", ⟨"Result", 2, [.tvar 0]⟩)
      (by simp [ScopeDeclarations.result, StandardKeyTyping.DataDecl.entries])) rfl (kinds p C) ?_ ?_
      (result_annotation_at p C Γ)
    · intro t ht; cases List.mem_singleton.mp ht; change 0 < 2; omega
    · simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm] using (HasTypeVsQ.cons hv HasTypeVsQ.nil)
  · intro hv
    refine .V_Con (hr.2 ("Result.Error", ⟨"Result", 2, [.tvar 1]⟩)
      (by simp [ScopeDeclarations.result, StandardKeyTyping.DataDecl.entries])) rfl (kinds p C) ?_ ?_
      (result_annotation_at p C Γ)
    · intro t ht; cases List.mem_singleton.mp ht; change 1 < 2; omega
    · simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm] using (HasTypeVsQ.cons hv HasTypeVsQ.nil)


/-- 型付きの本体の Fail を処理し、Result を返す通常の handle（`toResult`）は、成功の値を `Result.Ok`、捕捉した
エラー値を `Result.Error` に包み、空の効果で型付く。 -/
theorem toResult_typed (p : String) {B Ψ body}
    (hb : HasTypeCQ (core p) B Ψ Qempty [] [] [] none body intTy (Eff.singleFail strTy) []) :
    HasTypeCQ (core p) B Ψ Qempty [] [] [] none (toResult body) resultTy (Eff.union Eff.empty Eff.empty) [] := by
  have hv0 : HasTypeVQ (core p) B Ψ Qempty [] (Ctx.extend [] intTy) [] (.var 0) intTy :=
    .V_Var (by simp [Ctx.extend, Ty.shiftV]) (by simp [Ordinary])
  have hret : HasTypeCQ (core p) B Ψ Qempty [] (Ctx.extend [] intTy) [] none (.ret (okValue (.var 0)))
      (resultTy.shiftV 1 0) ((Eff.singleFail strTy).shiftV 1 0) (localExtend 1 []) := by
    have h := HasTypeCQ.C_Eff (Δ := localExtend 1 []) (R := none)
      (HasTypeCQ.C_Return ((result_values_typed p).1 hv0)) (ε' := (Eff.singleFail strTy).shiftV 1 0)
      ⟨fun a ha => by simp [Eff.empty, Eff.mem, Eff.test, Eff.atoms] at ha,
        fun t ht => by simp [Eff.empty, Eff.memFail, Eff.fails] at ht⟩
    simpa [Ty.shiftV] using h
  have hlet := HasTypeCQ.C_Let (Φ := []) hb (by simpa using hret) (result_annotation_at p [] []).declared
  have hv1 : HasTypeVQ (core p) B (hideBuilders Ψ) Qempty [TypeCtx.valueParam] (failureContext [] strTy)
      (liftMany 2 []) (.var 1) strTy :=
    .V_Var (by simp [failureContext, Ctx.extend, Ctx.extendNone, Ctx.shiftE, Ctx.shiftEAt, shiftTypes, Ty.shiftV])
      (by simp [Ordinary])
  have hclause : HasFailureClause (core p) B Ψ Qempty [] [] [] strTy none failClause resultTy Eff.empty [] := by
    refine .one ⟨trivial, trivial, trivial⟩ (result_annotation_at p [] [])
      (by
        intro e he
        simp only [List.mem_singleton] at he
        subst he
        exact ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm, NamesWF],
          by simp [Ty.Sorted, sortedEff, sortedTys, Eff.empty], by simp [Ty.Declared, declaredEff, declaredTys, Eff.empty]⟩) ?_
    simpa [shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV, Eff.empty] using
      (HasTypeCQ.C_Return (Δ := []) (R := none) ((result_values_typed p).2 hv1))
  exact .C_Handle_Fail hlet
    ⟨fun a ha => by simp [Eff.singleFail, Eff.mem, Eff.test, Eff.atoms] at ha,
      fun t ht => by simp [Eff.union, Eff.memFail, Eff.fails, Eff.norm] at ht ⊢; exact ht⟩
    ⟨rfl, by intro i hi; simp [Eff.empty, Eff.test, Eff.atoms] at hi⟩ hclause


/-! ## Result の値の照合 -/

/-- Result の二つの構成子だけを持つ宣言表。 -/
def resultProgram : Program := { CoverageExamples.program with
  cons := fun c => if c = "Result.Ok" then some ⟨"Result", 2, [.tvar 0]⟩
    else if c = "Result.Error" then some ⟨"Result", 2, [.tvar 1]⟩ else none }

def resultCtors : DataName → List ConName := fun d => if d = "Result" then ["Result.Ok", "Result.Error"] else []

theorem resultCtors_complete : CtorsComplete resultProgram resultCtors := by
  intro c cd h
  simp only [resultProgram] at h
  split at h
  · next he => cases h; simp [resultCtors, he]
  · split at h
    · next he => cases h; simp [resultCtors, he]
    · cases h

def fromResult (v : Val) : Comp :=
  .match v
    [.mk [⟨.con "Result.Ok" [.var], [0]⟩] none (.ret (.var 0)),
     .mk [⟨.con "Result.Error" [.var], [0]⟩] none (.app (.raise intTy strTy) [.var 0])]

private theorem resultProgram_arity : resultProgram.DataArity "Result" 2 := by
  refine ⟨⟨"Result.Ok", ⟨"Result", 2, [.tvar 0]⟩, rfl, rfl⟩, ?_⟩
  intro c cd h hd
  simp only [resultProgram] at h
  split at h
  · cases h; rfl
  · split at h
    · cases h; rfl
    · cases h

/-- 二構成子の宣言の両方を照合する照合は、成功の値を取り出し、エラーの値を raise する。 -/
theorem fromResult_typed {B Ψ v} (hv : HasTypeVQ resultProgram B Ψ Qempty [] [] [] v resultTy) :
    HasTypeCQ resultProgram B Ψ Qempty [] [] [] none (fromResult v) intTy (Eff.singleFail strTy) [] := by
  have hpatOk : PatTy resultProgram (.con "Result.Ok" [.var]) resultTy [intTy] := by
    have h := PatTy.P_Con (P := resultProgram) (c := "Result.Ok") (cd := ⟨"Result", 2, [.tvar 0]⟩) (ts := [intTy, strTy])
      rfl rfl (by intro a ha; simp at ha; subst ha; simp [Ty.WF]) (.cons .P_Var .nil)
    simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm] using h
  have hpatErr : PatTy resultProgram (.con "Result.Error" [.var]) resultTy [strTy] := by
    have h := PatTy.P_Con (P := resultProgram) (c := "Result.Error") (cd := ⟨"Result", 2, [.tvar 1]⟩)
      (ts := [intTy, strTy]) rfl rfl (by intro a ha; simp at ha; subst ha; simp [Ty.WF]) (.cons .P_Var .nil)
    simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm] using h
  have alt {p x} (hp : PatTy resultProgram p resultTy [x]) (hn : p.binders = 1) :
      AltsTy resultProgram [⟨p, [0]⟩] resultTy [x] := by
    refine ⟨by simp, by simp [Benitoite.Release.Arm.bindersOf, hn], ?_, ?_⟩
    · intro a ha; simp at ha; subst a; simp [hn]
    · intro a ha; simp at ha; subst a; exact ⟨[x], hp, .refl _, rfl⟩
  have hok : HasTypeCQ resultProgram B Ψ Qempty [] (bindParams [] [intTy]) (liftMany 1 []) none (.ret (.var 0))
      (intTy.shiftV 1 0) ((Eff.singleFail strTy).shiftV 1 0) (localExtend 1 []) := by
    have h := HasTypeCQ.C_Eff (Δ := localExtend 1 []) (R := none)
      (HasTypeCQ.C_Return (P := resultProgram) (B := B) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := bindParams [] [intTy])
        (Φ := liftMany 1 []) (.V_Var (i := 0) (a := intTy) (by simp [bindParams, Ty.shiftV])
          (by simp [Ordinary]))) (ε' := (Eff.singleFail strTy).shiftV 1 0)
      ⟨fun a ha => by simp [Eff.empty, Eff.mem, Eff.test, Eff.atoms] at ha,
        fun t ht => by simp [Eff.empty, Eff.memFail, Eff.fails] at ht⟩
    simpa [Ty.shiftV] using h
  have herr : HasTypeCQ resultProgram B Ψ Qempty [] (bindParams [] [strTy]) (liftMany 1 []) none
      (.app (.raise intTy strTy) [.var 0]) (intTy.shiftV 1 0) ((Eff.singleFail strTy).shiftV 1 0) (localExtend 1 []) := by
    have hr : HasTypeVQ resultProgram B Ψ Qempty [] (bindParams [] [strTy]) (liftMany 1 []) (.raise intTy strTy)
        (.fn ["error"] [strTy] intTy (Eff.singleFail strTy)) :=
      .V_Raise ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.singleFail, Eff.Canonical, Eff.norm, NamesWF, Ty.norm],
        by simp [Ty.Sorted, sortedEff, sortedTys, Eff.singleFail, Ty.norm], by simp [Ty.Declared, declaredEff,
          declaredTys, Eff.singleFail, Ty.norm]⟩ (by simp [Ordinary]) (by simp [Ordinary]) (by trivial)
    have h := HasTypeCQ.C_App (Δ := localExtend 1 []) (R := none) hr
      (.cons (.V_Var (i := 0) (a := strTy) (by simp [bindParams, Ty.shiftV]) (by simp [Ordinary])) .nil)
    simpa [Ty.shiftV, Eff.shiftV, Eff.singleFail, Ty.norm] using h
  refine HasTypeCQ.match_legacy hv
    (HasTypeArmsQ.plain_legacy (alt hpatOk rfl) hok
      (HasTypeArmsQ.plain_legacy (alt hpatErr rfl) herr (.nil ⟨trivial, trivial, trivial⟩)))
    ⟨⟨2, resultProgram_arity, rfl⟩, trivial, trivial, trivial⟩
    (Coverage.coverage_sound _ _ closedView _ _ resultCtors_complete (by rfl))


/-- 型付いた照合の計算から照合の型を取り出し、到達しないと報告される選択肢は実行時に選ばれない（ここでは到達しない
選択肢はない）。 -/
theorem fromResult_runtime {B Ψ v} (hv : HasTypeVQ resultProgram B Ψ Qempty [] [] [] v resultTy) :
    ∃ a, HasTypeVQ resultProgram B Ψ Qempty [] [] [] v a ∧ ∀ i j,
      (i, j) ∈ (checkMatch resultProgram resultCtors a (match fromResult v with | .match _ arms => arms | _ => [])).unreachable →
      ∀ w, Inhabits resultProgram a w →
        ¬ RuntimeSelected (match fromResult v with | .match _ arms => arms | _ => []) i j w :=
  checkMatch_unreachable_runtime_of_C_Match resultCtors (fromResult_typed hv) resultCtors_complete

end
end Benitoite.Release.Refinement.FailureTypingExamples
