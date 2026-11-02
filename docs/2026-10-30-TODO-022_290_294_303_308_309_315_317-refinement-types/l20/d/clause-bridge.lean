import Benitoite.Release.Refinement.TypeSubstTyping

namespace Benitoite.Release.Refinement.S02Internal.ClauseBridge

-- 継続の結果の WF は、HasTypeClausesQ.cons の入力からは得られない。
def signature : OpSig := {
  tparams := [], names := [], params := [],
  ret := .dependentFn (.done (.base .unit) Eff.empty), eff := "Ask" }

def result : Ty := .tvar 0

def argument : Val := .dependentLam (.done (.base .unit) Eff.empty) (.ret (.const .unit))

def body : Comp := .resume (.var 0) argument

theorem body_typed {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {Φ : List Pred} :
    HasTypeCQ P B Ψ Q [] (signature.context [] result Eff.empty) Φ none body
      ((shiftTypes 0 0 result).shiftV 1 0) (Eff.shiftV 1 0 (shiftRowsTypes 0 0 Eff.empty)) [] := by
  change HasTypeCQ P B Ψ Q []
    [some (.cont (.dependentFn (.done (.base .unit) Eff.empty)) (.tvar 0) Eff.empty)] Φ none
    (.resume (.var 0) argument) (.tvar 0) Eff.empty []
  refine .C_Resume rfl (.V_DependentLam ?_ (.done (.C_Return (.V_Const trivial)))) trivial
  refine ⟨?_,?_,?_⟩
  · simp [Ty.WF,Tel.WF,Eff.WF,Eff.empty,Ty.WFList,Eff.Canonical,Eff.norm,Ty.normTys]
  · simp [Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Eff.empty]
  · simp [Ty.Declared,Tel.Declared,declaredEff,declaredTys,Eff.empty]

theorem clauses_typed {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {Φ : List Pred} {o : OpRef} (h : ClauseSig P B Eff.empty o signature) :
    HasTypeClausesQ P B Ψ Q [] [] Φ none Eff.empty [.mk o 0 0 body] result Eff.empty [] := by
  refine .cons h ⟨rfl,by simp [signature]⟩ rfl rfl ?_ body_typed .nil
  simp [signature,OpSig.WF,BinderTypes.LocalWF,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
    Ty.WFList,Eff.Canonical,Eff.norm,Ty.normTys]

theorem result_not_wf : ¬ result.WF 0 0 0 := by
  simp [result,Ty.WF]

theorem continuation_not_wf : ¬ (signature.continuation result Eff.empty).WF 0 0 0 := by
  simp [signature,OpSig.continuation,result,Ty.WF,Ty.shiftV]

theorem continuation_input_changes :
    signature.ret.norm ≠ signature.ret := by
  have h := Ty.foldFn_toTel (⟨[],[],.base .unit,Eff.empty,⟨rfl,by simp⟩⟩ : FnView)
  change Ty.foldFn (Tel.done (.base .unit) Eff.empty) ≠ Ty.dependentFn (.done (.base .unit) Eff.empty)
  rw [show Tel.done (.base .unit) Eff.empty =
    (⟨[],[],.base .unit,Eff.empty,⟨rfl,by simp⟩⟩ : FnView).toTel from rfl,h]
  intro he
  cases he

theorem narrows_nonempty {P : Program} {C : TypeCtx} {Γ Δ : Ctx} {Φ Ξ : List Pred}
    (h : Ctx.Narrows P C Γ Φ Δ Ξ) : 0 < Γ.length := by
  cases h <;> simp [Ctx.extend,Ctx.extendNone]

theorem narrows_singleton_wf {P : Program} {C : TypeCtx} {Γ Δ : Ctx} {Φ Ξ : List Pred}
    (h : Ctx.Narrows P C Γ Φ Δ Ξ) (hl : Γ.length = 1) {a : Ty}
    (ha : Γ[0]? = some (some a)) : a.WF 0 C.length 1 := by
  cases h with
  | @here Γ Φ x b hle hx hb hs hd =>
    have he : Γ.length = 0 := by
      simp only [Ctx.extend,List.length_cons,List.length_map] at hl
      omega
    simp only [Ctx.extend,List.getElem?_cons_zero,Option.some.injEq] at ha
    cases ha
    have hh := Ty.wf_shiftV hb 1 0
    simpa only [he,Nat.zero_add] using hh
  | under h a =>
    have hp := narrows_nonempty h
    simp only [Ctx.extend,List.length_cons,List.length_map] at hl
    omega
  | underNone h =>
    have hp := narrows_nonempty h
    simp only [Ctx.extendNone,List.length_cons,List.length_map] at hl
    omega

theorem no_narrow_from_mapped_continuation {P : Program} {Δ : Ctx} {Φ Ξ : List Pred} :
    ¬ Ctx.Narrows P [] [some (.cont signature.ret.norm result Eff.empty)] Φ Δ Ξ := by
  intro h
  have hw := narrows_singleton_wf h rfl rfl
  have ht := hw.2.1
  simp [result,Ty.WF] at ht

end Benitoite.Release.Refinement.S02Internal.ClauseBridge

#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.body_typed
#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.clauses_typed
#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.result_not_wf
#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.continuation_not_wf
#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.continuation_input_changes

#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.narrows_nonempty
#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.narrows_singleton_wf
#print axioms Benitoite.Release.Refinement.S02Internal.ClauseBridge.no_narrow_from_mapped_continuation
