import Benitoite.Release.Refinement.CoverageRefinement
namespace Benitoite.Release.Refinement
noncomputable section

/-- 開いた入口は、経路条件に非空の述語がある実際の変数で働く。Lean の算術の証明書は要らない形の代表。 -/
theorem open_nonempty_instance (P : Program) (B : Builtins) (Ψ : StoreTy) :
    let T : Ty := .base .unit
    let Γ : Ctx := [some (.list T)]
    let Φ : List Pred := [nonemptyPredicate.open (.var 0)]
    HasTypeVQ P B Ψ Qempty [] Γ Φ (.var 0) (nonemptyType T) ∧
      Exhaustive P (nonemptyType T) [headRestPattern] := by
  intro T Γ Φ
  have self : (Term.var 0).HasSort [some (.list T), some (.list T)] .list :=
    ⟨⟨.list T,rfl,by intro b t e he; cases he⟩,⟨.list T,rfl,rfl⟩⟩
  have hv : HasTypeVQ P B Ψ Qempty [] Γ Φ (.var 0) (.list T) :=
    .V_Var rfl (by intro b t e he; cases he)
  have ha : Ty.Annotation P [] Γ (.list T) := by
    refine ⟨?_,?_,?_⟩ <;> simp [T,Ty.WF,Ty.Sorted,Ty.Declared]
  have sint : ∀ k : Int, (Term.integer k).HasSort (some (.list T) :: Γ) .integer := fun _ => ⟨trivial,rfl⟩
  have hp : nonemptyPredicate.Sorted Γ (some (.list T)) :=
    ⟨sint 0,⟨self.1,⟨self.2,rfl⟩⟩⟩
  have hd : nonemptyPredicate.Declared P [] Γ (some (.list T)) :=
    ⟨trivial,⟨_,rfl,by intro b t e he; cases he⟩⟩
  exact hv.nonempty_from_entails rfl ha hp hd (.hyp (by simp [Φ]))

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.open_nonempty_instance
