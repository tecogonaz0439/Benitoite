import Benitoite.Release.Refinement.Context

namespace Benitoite.Release.Refinement

mutual
  instance Term.varsDecidable (P : Nat → Prop) [DecidablePred P] (t : Term) : Decidable (t.VarsIn P) := by
    cases t <;> simp only [Term.VarsIn]
    all_goals first
      | infer_instance
      | exact Term.varsDecidable P _
      | exact slotsVarsDecidable P _
      | exact @instDecidableAnd _ _ (Term.varsDecidable P _) (Term.varsDecidable P _)
      | exact @instDecidableAnd _ _ (slotsVarsDecidable P _) (slotsVarsDecidable P _)
  instance slotVarsDecidable (P : Nat → Prop) [DecidablePred P] (t : Option Term) : Decidable (varsInSlot P t) := by
    cases t <;> simp only [varsInSlot]
    · infer_instance
    · exact Term.varsDecidable P _
  instance slotsVarsDecidable (P : Nat → Prop) [DecidablePred P] (ts : List (Option Term)) : Decidable (varsInSlots P ts) := by
    cases ts <;> simp only [varsInSlots]
    · infer_instance
    · exact @instDecidableAnd _ _ (slotVarsDecidable P _) (slotsVarsDecidable P _)
end
instance Pred.varsDecidable (P : Nat → Prop) [DecidablePred P] (p : Pred) : Decidable (p.VarsIn P) := by
  cases p <;> simp only [Pred.VarsIn]
  all_goals first
    | infer_instance
    | exact Pred.varsDecidable P _
    | exact @instDecidableAnd _ _ (Pred.varsDecidable P _) (Pred.varsDecidable P _)
instance Term.closedDecidable (t : Term) : Decidable t.Closed := Term.varsDecidable _ _
instance Pred.wfDecidable (n : Nat) (p : Pred) : Decidable (p.WF n) := Pred.varsDecidable _ _
instance Ty.hasSortDecidable (a : Ty) (s : «Sort») : Decidable (a.HasSort s) := inferInstanceAs (Decidable (a.sort? = some s))
instance Ctx.readableDecidable (Γ : Ctx) (i : Nat) : Decidable (Γ.Readable i) := by
  unfold Ctx.Readable
  cases Γ[i]? with
  | none => exact isFalse (by simp)
  | some x =>
    cases x with
    | none => exact isFalse (by simp)
    | some a =>
      have hi : Decidable (Ordinary a) := by
        cases a <;> simp [Ordinary] <;> infer_instance
      exact decidable_of_iff (Ordinary a) (by simp)
instance Term.referencesDecidable (Γ : Ctx) (t : Term) : Decidable (t.References Γ) := Term.varsDecidable _ _
instance Term.shapeDecidable (Γ : Ctx) (t : Term) (s : «Sort») : Decidable (t.Shape Γ s) := by
  cases t <;> simp only [Term.Shape] <;> try infer_instance
  all_goals first
    | exact @instDecidableAnd _ _ (Term.shapeDecidable Γ _ _) inferInstance
    | exact @instDecidableAnd _ _ (Term.shapeDecidable Γ _ _)
        (@instDecidableAnd _ _ (Term.shapeDecidable Γ _ _) inferInstance)
    | skip
  case var i =>
    cases Γ[i]? with
    | none => exact isFalse (by simp)
    | some x =>
      cases x with
      | none => exact isFalse (by simp)
      | some a => exact decidable_of_iff (a.HasSort s) (by simp)
instance Term.hasSortDecidable (Γ : Ctx) (t : Term) (s : «Sort») : Decidable (t.HasSort Γ s) := by
  unfold Term.HasSort; infer_instance
instance Comparison.allowedDecidable (s : «Sort») (o : Comparison) : Decidable (Comparison.Allowed s o) := by
  cases s <;> cases o <;> simp [Comparison.Allowed] <;> infer_instance
instance Pred.sortedDecidable (Γ : Ctx) (self : Option Ty) (p : Pred) : Decidable (p.Sorted Γ self) := by
  cases p <;> simp only [Pred.Sorted]
  all_goals first
    | infer_instance
    | exact Pred.sortedDecidable Γ self _
    | exact @instDecidableAnd _ _ (Pred.sortedDecidable Γ self _) (Pred.sortedDecidable Γ self _)

end Benitoite.Release.Refinement
