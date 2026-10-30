import Benitoite.Release.Refinement.SubstTypingObstruction

/-!
# 篩付きの継続の変数と narrowing

継続を担い手とする篩は WF を満たさず、narrowing の前提から除かれる。
-/
namespace Benitoite.Release.Refinement

private theorem variable_origin_aux {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) :
    ∀ i, v = .var i → ∃ b, Γ[i]? = some (some b) ∧ b.Ordinary := by
  match h with
  | .V_Var hi ho => intro i he; cases he; exact ⟨_, hi, ho⟩
  | .V_Const _ | .V_Lam _ _ _ _ _ | .V_List _ _ _ _ | .V_Raise _ | .V_LocRef _ _ | .V_LocLazy _ _
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Map _ _ _ _ _ _ | .V_Set _ _ _ | .V_Dict _ _ _ _ _ _ _ _
  | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _
  | .V_Bytes _ | .V_Con _ _ _ _ _ _ | .V_Super _ _ _ _ => intro i he; cases he
  | .V_Sub hv _ _ _ _ | .V_Refine hv _ _ _ _ _ _ _ => exact variable_origin_aux hv

theorem HasTypeVQ.variable_origin {P B store Q C Γ Φ i a}
    (h : HasTypeVQ P B store Q C Γ Φ (.var i) a) :
    ∃ b, Γ[i]? = some (some b) ∧ b.Ordinary := variable_origin_aux h i rfl

namespace ContinuationNarrowingObstruction

def a : Ty := .cont (.base .unit) (.base .unit) Eff.empty
def b : Ty := .refined a .truth
def Γ : Ctx := Ctx.extend [] b
def Δ : Ctx := Ctx.extend [] a

theorem a_wf : a.WF 0 0 0 := ⟨trivial, trivial, trivial, rfl⟩
theorem b_not_wf {nr nt nv : Nat} : ¬ b.WF nr nt nv := by
  intro h
  exact h.2.2 _ _ _ rfl

theorem nested_not_wf {nr nt nv : Nat} : ¬ (Ty.refined b .truth).WF nr nt nv := by
  intro h
  exact h.2.2 _ _ _ rfl
theorem a_sorted : a.Sorted [] := ⟨trivial, trivial, trivial⟩
theorem b_sorted : b.Sorted [] := ⟨a_sorted, trivial⟩

theorem subtype_outside : Ty.LeQ [] [] a b := .introduce trivial .truth

theorem context_facts : Γ.facts = [.truth] ∧ Δ.facts = [] := ⟨rfl, rfl⟩

theorem facts_preserved : ∀ p ∈ Γ.facts, Entails Δ.facts p := by
  intro p hp
  rw [context_facts.1] at hp
  have he : p = .truth := List.mem_singleton.mp hp
  subst p
  exact .truth

theorem source_variable {P B store Q C} :
    HasTypeVQ P B store Q C Γ [] (.var 0) b :=
  .V_Var rfl (by intro u t e he; cases he)

theorem target_variable_untypable {P B store Q C Φ t} :
    ¬ HasTypeVQ P B store Q C Δ Φ (.var 0) t := by
  intro h
  obtain ⟨u, hu, ho⟩ := h.variable_origin
  have he : u = a := by simpa [Δ, Ctx.extend, a, Ty.shiftV, Eff.shiftV, Eff.empty, shiftVTys] using hu.symm
  subst u
  exact ho _ _ _ rfl

theorem source_return {P B store Q C R L} :
    HasTypeCQ P B store Q C Γ [] R (.ret (.var 0)) b Eff.empty L := .C_Return source_variable

theorem target_return_untypable {P B store Q C Φ R t e L} :
    ¬ HasTypeCQ P B store Q C Δ Φ R (.ret (.var 0)) t e L := by
  intro h
  obtain ⟨u, hu⟩ := h.return_value_typable
  exact target_variable_untypable hu

end ContinuationNarrowingObstruction
end Benitoite.Release.Refinement
