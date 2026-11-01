import Benitoite.Release.Refinement.CoverageRefinement
namespace Benitoite.Release.Refinement
noncomputable section

def emptyP : Program := ⟨fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩
theorem emptyP_valid : emptyP.VarianceValid := by simp [Program.VarianceValid, emptyP]

/-- 同じ上側近似でも所属の opaque は閉じている。 -/
theorem opaque_rejects_unit (P : Program) (o ix) : ¬ Inhabits P (.opaque o ix) (.const .unit) := by
  intro h
  generalize ha : Ty.opaque o ix = a at h
  generalize hv : Val.const Const.unit = v at h
  cases h <;> (try cases ha) <;> (try cases hv) <;> (try simp [Const.type] at ha)

/-- G09 へ残した valueMeaning_sub の言明は scoped_forget で偽である。 -/
theorem valueMeaning_sub_statement_false :
    ¬ (∀ {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty} {v : Val} {η : ObservationEnvModel},
      P.VarianceValid → Ty.LeQ P Γ Φ a b →
      (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
      ValueMeaning P η a v → ValueMeaning P η b v) := by
  intro h
  have hs : ValueMeaning emptyP (fun _ => none) (.scoped "o" .path (.fixed .top)) (.const .unit) :=
    .mk .scoped (by intro p hp; cases hp)
  have hb := h (P := emptyP) (Γ := []) (Φ := []) (η := fun _ => none) emptyP_valid
    (.scoped_forget (o := "o") (k := .path) (ix := .fixed .top))
    (by intro p hp; cases hp) hs
  exact opaque_rejects_unit _ _ _ (valueMeaning_inhabits_normal hb)

/-- 型付き値でない .const .unit の意味が .scoped で成り立つことが原因である。 -/
theorem scoped_meaning_any (P η o k ix v) : ValueMeaning P η (.scoped o k ix) v :=
  .mk .scoped (by intro p hp; cases hp)

/-- 修正案の形: scoped の意味を成功値の形へ絞れば、Covers と scoped_forget の両方で閉じる。 -/
inductive ScopedValue : RangeIx → Val → Prop where
  | checked {r t} : ScopedValue (.fixed r) (.checked t)
  | checkedRequest {r t req} : ScopedValue (.fixed r) (.checkedRequest t req)
  | checkedAt {ix r snapshot t req} : ScopedValue ix (.checkedAt r snapshot t req)

theorem ScopedValue.covers {outer inner v} (hc : RangeIx.Covers outer inner)
    (h : ScopedValue inner v) : ScopedValue outer v := by
  cases outer <;> cases inner <;> simp only [RangeIx.Covers] at hc
  · cases h <;> first | exact .checked | exact .checkedRequest | exact .checkedAt
  · subst hc; exact h

theorem ScopedValue.forget {ix v} (P : Program) (o) (h : ScopedValue ix v) :
    Inhabits P (.opaque o ix) v := by
  cases h <;> first | exact .checked | exact .checkedRequest | exact .checkedAtOpaque

/-- 値依存の等号だけなら空 List は残り、頭と残りの腕だけでは網羅でない。 -/
def lenEq : Pred := .eq (.measure .listLength (.var 0)) (.var 1)
theorem length_equality_not_exhaustive (P a) :
    ¬ Exhaustive P (.refined (.list a) lenEq) [headRestPattern] := by
  intro h
  have hi : Inhabits P (.refined (.list a) lenEq) (.list []) :=
    .refined (.list .nil) (by intro h; simp [lenEq,Pred.evalWith,Pred.atomReady,termReady,Term.observe,selfModel] at h)
  obtain ⟨p,hp,hm⟩ := h (.list []) ((Inhabits.norm_all_iff _ _).mpr hi)
  have he : p = headRestPattern := List.mem_singleton.mp hp
  subst p; cases hm

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.valueMeaning_sub_statement_false
#print axioms Benitoite.Release.Refinement.length_equality_not_exhaustive
