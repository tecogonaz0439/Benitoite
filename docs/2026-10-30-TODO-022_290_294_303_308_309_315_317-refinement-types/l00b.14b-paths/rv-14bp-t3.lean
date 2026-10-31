import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.LogicSound
/-! 短絡 `if a && b` の真の枝で a を読む代表。脱糖 `let c = if a then b else false; if c ...`。
    結果型を self=false ではなく not(self=true) で書けば、apart なしで閉じる。 -/
namespace Benitoite.Release.Refinement.RV
noncomputable section
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
abbrev BoolTy : Ty := .base .boolean
def tt (t : Term) := boolCond t true
/-- Γ = [b, a]（var 0 = b, var 1 = a）の下の self の述語。self は var 0、b は var 1、a は var 2。 -/
def q : Pred := .or (.and (tt (.var 0)) (.and (tt (.var 2)) (tt (.var 1)))) (.not (tt (.var 0)))
def Inner : Ty := .refined BoolTy q
def Γ2 : Ctx := Ctx.extend (Ctx.extend [] BoolTy) BoolTy
def Out : Ty := .refined BoolTy (tt (.var 0))

macro "ann" : tactic => `(tactic|
  (refine ⟨?_,?_,?_⟩ <;>
    simp [Out,Inner,q,tt,boolCond,Γ2,Ctx.extend,BoolTy,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Ty.shiftV,
      Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Eff.WF,Eff.Canonical,Eff.empty,Tel.Sorted,Ty.Sorted,
      Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Tel.Declared,
      Ty.Declared,declaredEff,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,
      Comparison.Allowed,sortedEff,sortedTys,declaredTys,Eff.norm,Ty.normTys]))

theorem inner_ann : Ty.Annotation P [] Γ2 Inner := by ann

/-- 排中律と `not_not_elim` で、b の真偽に分ける。 -/
theorem em (Ξ : List Pred) (p : Pred) : Entails Ξ (.or p (.not p)) := by
  apply Entails.not_not_elim
  apply Entails.not_intro
  have hh : Entails (Pred.not (.or p (.not p)) :: Ξ) (.not p) := by
    apply Entails.not_intro
    exact .not_elim (.or_left (.hyp List.mem_cons_self)) (.hyp (List.mem_cons_of_mem _ List.mem_cons_self))
  exact .not_elim (.or_right hh) (.hyp List.mem_cons_self)



theorem bool_var {Γ : Ctx} {Φ} {i} (hi : Γ[i]? = some (some BoolTy)) :
    HasTypeV P B StoreTy.empty [] Γ Φ (.var i) BoolTy := .V_Var hi (by simp [BoolTy,Ty.Ordinary,Ordinary,Ty.core])

theorem bool_var' {Γ : Ctx} {Φ} {i} {a : Ty} (hi : Γ[i]? = some (some a)) (hb : a = BoolTy) :
    HasTypeV P B StoreTy.empty [] Γ Φ (.var i) BoolTy := by subst hb; exact bool_var hi

theorem then_branch : HasTypeC P B StoreTy.empty [] Γ2 [tt (.var 1)] none (.ret (.var 0)) Inner Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (bool_var rfl) rfl rfl inner_ann.sorted.2 inner_ann.wf.2.1 ?_ inner_ann.declared.1 inner_ann.declared.2
  have hg : Entails (Γ2.facts ++ [tt (.var 1)]) (tt (.var 1)) := .hyp (by simp)
  have goal : Entails (Γ2.facts ++ [tt (.var 1)])
      (.or (.and (tt (.var 0)) (.and (tt (.var 1)) (tt (.var 0)))) (.not (tt (.var 0)))) := by
    apply Entails.or_elim (em _ (tt (.var 0)))
    · exact .or_left (.and_intro (.hyp List.mem_cons_self)
        (.and_intro (hg.weaken (fun _ h => List.mem_cons_of_mem _ h)) (.hyp List.mem_cons_self)))
    · exact .or_right (.hyp List.mem_cons_self)
  simpa [q,tt,boolCond,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex] using goal

theorem else_branch : HasTypeC P B StoreTy.empty [] Γ2 [boolCond (.var 1) false] none
    (.ret (.const (.boolean false))) Inner Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Const trivial) rfl rfl inner_ann.sorted.2 inner_ann.wf.2.1 ?_ inner_ann.declared.1 inner_ann.declared.2
  have goal : Entails (Γ2.facts ++ [boolCond (.var 1) false])
      (.not (tt (.boolean false))) := (CaptureOk.evaluated_fact (by decide)).weaken (by simp)
  have g2 := Entails.or_right (p := .and (tt (.boolean false)) (.and (tt (.var 1)) (tt (.var 0)))) goal
  simpa [q,tt,boolCond,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex] using g2

def condition : Comp := .ite (.var 1) (.ret (.var 0)) (.ret (.const (.boolean false)))
def whole : Comp := .letIn condition (.ite (.var 0) (.ret (.var 2)) (.ret (.const (.boolean true))))

theorem condition_typed : HasTypeCQ P B StoreTy.empty Qempty [] Γ2 [] none condition Inner Eff.empty [] :=
  HasTypeCQ.C_If (bool_var (Γ := Γ2) (Φ := []) (i := 1) rfl) rfl then_branch else_branch

/-- 実際の脱糖の形で、`if a && b` の真の枝が a の真を読む。apart を仮定しない。 -/
theorem short_circuit_reads_left : HasTypeC P B StoreTy.empty [] Γ2 [] none whole Out Eff.empty := by
  let Δ := Γ2.extend Inner
  have ha : Ty.Annotation P [] Δ Out := by
    refine ⟨?_,?_,?_⟩ <;> simp [Δ,Out,Inner,q,tt,boolCond,Γ2,Ctx.extend,BoolTy,Ty.WF,Ty.NotContCore,Ty.core,Ty.shiftV,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Comparison.Allowed]
  have hb : Ty.Annotation P [] Δ BoolTy := ⟨trivial,trivial,trivial⟩
  have hc : HasTypeV P B StoreTy.empty [] Δ [] (.var 0) BoolTy :=
    .V_Sub (.V_Var rfl (by simp [Inner,Ty.Ordinary,Ordinary,Ty.shiftV,Ty.core])) .forget hb.wf hb.sorted hb.declared
  have ht : HasTypeCQ P B StoreTy.empty Qempty [] Δ [boolCond (.var 0) true] none
      (.ret (.var 2)) Out Eff.empty (localExtend 1 []) := by
    have hvc : HasTypeV P B StoreTy.empty [] Δ [boolCond (.var 0) true] (.var 0)
        (.refined BoolTy (q.shiftV 1 1)) :=
      .V_Var rfl (by simp [Inner,Ty.Ordinary,Ordinary,Ty.shiftV,Ty.core])
    have hf := hvc.facts rfl (q.shiftV 1 1) (by
      rw [Ty.assume_refined (by simp [BoolTy,Ty.Ordinary,Ordinary,Ty.core])]
      change _ ∈ [q.shiftV 1 1]
      exact List.mem_cons_self)
    have hf' : Entails (Δ.facts ++ [boolCond (.var 0) true])
        (.or (.and (tt (.var 0)) (.and (tt (.var 2)) (tt (.var 1)))) (.not (tt (.var 0)))) := by
      simpa [q,tt,Pred.shiftV,Pred.open,predBind,termBind,termBind?,upValues,boolCond,openingEnv,shiftIndex] using hf
    have hcond : Entails (Δ.facts ++ [boolCond (.var 0) true]) (tt (.var 0)) := .hyp (by simp [tt])
    have hx : Entails (Δ.facts ++ [boolCond (.var 0) true]) (tt (.var 2)) := by
      apply Entails.or_elim hf'
      · exact .and_left (.and_right (.hyp List.mem_cons_self))
      · exact .false_elim (.not_elim (hcond.weaken (fun _ h => List.mem_cons_of_mem _ h)) (.hyp List.mem_cons_self))
    exact .C_Return (.V_Refine (bool_var' (a := BoolTy) (by rfl) rfl) rfl rfl ha.sorted.2 ha.wf.2.1
      (by simpa [tt,boolCond,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex] using hx) ha.declared.1 ha.declared.2)
  have hff : HasTypeCQ P B StoreTy.empty Qempty [] Δ [boolCond (.var 0) false] none
      (.ret (.const (.boolean true))) Out Eff.empty (localExtend 1 []) :=
    .C_Return (.V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1
      ((CaptureOk.evaluated_fact (p := tt (.boolean true)) (by decide)).weaken (by simp))
      ha.declared.1 ha.declared.2)
  refine .C_Let condition_typed ?_ (by
    simp [Out,tt,boolCond,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,BoolTy]
    exact ⟨_,rfl,by simp [Ty.shiftV,Ty.core]⟩)
  simpa [liftMany_eq,Out,tt,boolCond,BoolTy,Ty.shiftV,Pred.shiftV,predBind,termBind,termBind?,Eff.shiftV,Eff.empty,shiftVTys] using
    (HasTypeCQ.C_If hc rfl ht hff)
end
end Benitoite.Release.Refinement.RV
#print axioms Benitoite.Release.Refinement.RV.short_circuit_reads_left
