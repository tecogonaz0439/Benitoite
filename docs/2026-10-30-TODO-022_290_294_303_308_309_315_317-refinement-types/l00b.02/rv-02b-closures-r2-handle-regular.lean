import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section
/-- C_Handle は結果の行 ε に Annotation を要求しない。 -/
theorem handle_any_row (P : Program) (B : Builtins) (Ψ : StoreTy) (ε : Eff) :
    HasTypeC P B Ψ [] [] [] none (.handle (.ret (.const .unit)) []) (.base .unit) ε := by
  refine .C_Handle (εm := Eff.empty) (.C_Return (.V_Const trivial)) ?_ .nil
  exact ⟨fun a ha => (by cases ha), fun t ht => (by obtain ⟨x,hx,_⟩ := ht; cases hx)⟩
def junkRow : Eff := .mk (fun _ => false) [.tvar 3]
theorem junk_not_annotated (P : Program) :
    ¬ Ty.Annotation P [] [] (.dependentFn (.done (.base .unit) junkRow)) := by
  intro h
  have hw := h.wf.2.1
  simp [junkRow,Eff.WF,Ty.WFList,Ty.WF] at hw
#print axioms handle_any_row
end
end Benitoite.Release.Refinement
