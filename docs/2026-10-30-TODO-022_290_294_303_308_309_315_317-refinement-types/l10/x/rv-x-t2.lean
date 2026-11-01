import Benitoite.Release.Refinement.CoverageRefinement
namespace Benitoite.Release.Refinement
noncomputable section

/-! 変数パターンの束縛型は入力の述語列の接頭辞であり、core は等しい。 -/
theorem var_binding_prefix {P p a δ} (h : PatTy P p a δ) (hp : p = .var) :
    ∃ x, δ = [x] ∧ x.norm.core = a.norm.core ∧ x.refinementPredicates <+: a.refinementPredicates := by
  match h with
  | .P_Var => exact ⟨_,rfl,rfl,List.prefix_refl _⟩
  | .P_Wild | .P_Const _ | .P_RangeInt | .P_RangeChar => cases hp
  | .P_List _ _ _ => cases hp
  | .P_Con _ _ _ _ => cases hp
  | .P_Refined hr =>
    obtain ⟨x,rfl,hc,hq⟩ := var_binding_prefix hr hp
    refine ⟨x,rfl,?_,?_⟩
    · simpa only [Ty.norm,Ty.core_refineNorm] using hc
    · exact hq.trans (List.prefix_append _ _)
  | .P_Convert (a := a') (b := b') he hr =>
    obtain ⟨x,rfl,hc,hq⟩ := var_binding_prefix hr hp
    refine ⟨x.norm,rfl,?_,?_⟩
    · rw [Ty.norm_idem,hc,he]
    · have : a'.refinementPredicates = b'.refinementPredicates := by
        rw [←Ty.predicates_norm a',he,Ty.predicates_norm]
      rw [Ty.predicates_norm,←this]; exact hq
termination_by structural h

/-- 束縛の型は意味の上でも入力型より弱い。 -/
theorem var_binding_meaning {P a x v} {η : ObservationEnvModel} (h : PatTy P .var a [x])
    (hv : ValueMeaning P η a v) : ValueMeaning P η x v := by
  obtain ⟨y,hy,hc,hq⟩ := var_binding_prefix h rfl
  have hxy := List.head_eq_of_cons_eq hy
  subst hxy
  cases hv with
  | mk hs hp =>
    refine .mk (hc ▸ hs) ?_
    intro p hm
    apply hp
    rw [Ty.predicates_norm] at hm ⊢
    exact hq.subset hm

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.var_binding_meaning
