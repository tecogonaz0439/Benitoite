import Benitoite.Release.Refinement.ContextNormEq
import Benitoite.Release.Refinement.TypeSubstCodeNormal
import Benitoite.Release.Refinement.TypeSubstMain

namespace Benitoite.Release.Refinement.S02Internal.NormEqCheck

noncomputable section

def signature : OpSig := {
  tparams := [], names := [], params := [],
  ret := .dependentFn (.done (.base .unit) Eff.empty), eff := "Ask" }
def result : Ty := .tvar 0
def argument : Val := .dependentLam (.done (.base .unit) Eff.empty) (.ret (.const .unit))
def body : Comp := .resume (.var 0) argument

def normalizedContext : Ctx := [some (.cont signature.ret.norm result Eff.empty)]
def originalContext : Ctx := [some (.cont signature.ret result Eff.empty)]

theorem bridge_normEq : normalizedContext.NormEq originalContext := by
  simp only [Ctx.NormEq,normalizedContext,originalContext,List.map_cons,List.map_nil,
    Option.map_some,Ty.norm,Ty.norm_idem]

theorem bridge_continuations (i : Nat) (b t : Ty) (e : Eff)
    (hi : normalizedContext[i]? = some (some (.cont b t e))) :
    ∃ (b' t' : Ty) (e' : Eff), originalContext[i]? = some (some (.cont b' t' e')) := by
  cases i with
  | zero => exact ⟨signature.ret,result,Eff.empty,rfl⟩
  | succ i => simp [normalizedContext] at hi

theorem normalized_body_typed {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {Φ : List Pred} :
    HasTypeCQ P B Ψ Q [] normalizedContext Φ none body result Eff.empty [] := by
  refine .C_Resume rfl (.V_Normal ?_) trivial
  refine .V_DependentLam ?_ (.done (.C_Return (.V_Const trivial)))
  refine ⟨?_,?_,?_⟩
  · simp [Ty.WF,Tel.WF,Eff.WF,Eff.empty,Ty.WFList,Eff.Canonical,Eff.norm,Ty.normTys]
  · simp [Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Eff.empty]
  · simp [Ty.Declared,Tel.Declared,declaredEff,declaredTys,Eff.empty]

theorem bridge_tvar0 {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {Φ : List Pred} (ha : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeCQ P B Ψ Q [] originalContext Φ none body result Eff.empty [] := by
  have ht := bridge_normEq.comp bridge_continuations ha hw
    (normalized_body_typed (P := P) (Q := Q) (Φ := Φ))
  simpa only [body,argument,result,Comp.subst,Val.subst,Tel.bind_var,Tel.norm,Ty.norm,
    Eff.norm,Eff.empty,Ty.normTys,Option.map_none,List.map_nil,Order.sortUnique_nil] using ht

theorem clauses_tvar0 {P B Ψ Q eb o}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hs : ClauseSig P B eb o signature) :
    HasTypeClausesQ P B Ψ Q [] [] [] none (Eff.substAt 0 [] [] eb)
      (Clause.substTyAtList 0 [] [] [.mk o 0 0 body]) (result.substAt 0 [] [])
      (Eff.substAt 0 [] [] Eff.empty) [] := by
  have hw : signature.WF := by
    simp [signature,OpSig.WF,BinderTypes.LocalWF,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
      Ty.WFList,Eff.Canonical,Eff.norm,Ty.normTys]
  have hb := bridge_tvar0 (P := P) (B := B) (Ψ := hideBuilders Ψ) (Q := Q) (Φ := [])
    hf.2.2.1.substitutions hf.2.2.2.hide
  have cs : HasTypeClausesQ P B Ψ Q [] [] [] none eb [.mk o 0 0 body] result Eff.empty [] := by
    refine .cons hs (by simp [NamesWF,signature]) rfl rfl hw ?_ .nil
    simpa [signature,OpSig.context,OpSig.continuation,originalContext,Ctx.shiftE,Ctx.shiftEAt,
      Ctx.extendMany,Ctx.extend,shiftTypes,shiftRowsTypes,result,Ty.shift,Ty.bind,Ty.norm,Ty.shiftV,Tel.shiftV,
      Eff.shiftV,Eff.norm,Eff.empty,Ty.normTys] using hb
  have hi : TypeSubstInput P B [] [] [] [] :=
    ⟨rfl,by simp,⟨rfl,by simp⟩,by simp [TypeAnnotations],⟨rfl,by simp⟩,by simp,by simp [RowAnnotations],by simp⟩
  exact S02Internal.substClauses (C0 := []) (C1 := []) hf hi (Or.inl rfl)
    (by intro i hi; exact ⟨rfl,fun j hj => by
          have he : j = i := by simpa [Eff.row,Eff.mem,Eff.test,Eff.atoms] using hj
          exact he ▸ hi⟩) cs

theorem captureWF_not_invariant :
    Ctx.NormEq [some (.cont (.base .unit) (.base .unit) Eff.empty)]
      [some (.refined (.cont (.base .unit) (.base .unit) Eff.empty) .truth)] ∧
    Ctx.CaptureWF 0 0 [some (.cont (.base .unit) (.base .unit) Eff.empty)] ∧
    ¬ Ctx.CaptureWF 0 0 [some (.refined (.cont (.base .unit) (.base .unit) Eff.empty) .truth)] := by
  refine ⟨?_,?_,?_⟩
  · simp [Ctx.NormEq,Ty.norm,Ty.refineNorm,Ty.core,Ty.refinementPredicates,
      Ty.packRefinements,Pred.conjuncts,Eff.norm,Eff.empty,Ty.normTys]
  · intro i a hi
    cases i with
    | zero => cases hi; trivial
    | succ i => simp at hi
  · intro h
    have hh := h 0 _ rfl
    simp [Ty.CaptureWF,Ty.WF,Ty.NotContCore,Ty.core] at hh

end
end Benitoite.Release.Refinement.S02Internal.NormEqCheck

#print axioms Benitoite.Release.Refinement.S02Internal.NormEqCheck.bridge_tvar0

#print axioms Benitoite.Release.Refinement.S02Internal.NormEqCheck.captureWF_not_invariant

#print axioms Benitoite.Release.Refinement.S02Internal.NormEqCheck.clauses_tvar0
