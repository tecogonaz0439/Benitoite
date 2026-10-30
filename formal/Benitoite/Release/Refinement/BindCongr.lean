import Benitoite.Release.Refinement.RangeExchange

namespace Benitoite.Release.Refinement

structure SubstEnv.SameTypes (θ τ : SubstEnv) : Prop where
  types : ∀ i, (θ.types i).norm = (τ.types i).norm
  rows : θ.rows = τ.rows
  ranges : θ.ranges = τ.ranges
  values : θ.values = τ.values

theorem SubstEnv.SameTypes.up {θ τ} (h : SubstEnv.SameTypes θ τ) : SubstEnv.SameTypes θ.up τ.up := by
  refine ⟨?_, congrArg (List.map (Eff.shiftV 1 0)) h.rows, h.ranges, congrArg upValues h.values⟩
  intro i
  simp only [SubstEnv.up_types, Ty.norm_shiftV, h.types]

private theorem rawApply_norm_congr {a b : Ty} {as bs : List Ty}
    (ha : a.norm = b.norm) (hs : Ty.normTys as = Ty.normTys bs) :
    (rawApply a as).norm = (rawApply b bs).norm := by
  rw [← rawApply_norm, ← rawApply_norm b bs, ha, hs]

mutual
  theorem Ty.bind_sameTypes (a : Ty) {θ τ} (h : SubstEnv.SameTypes θ τ) : (a.rawBind θ).norm = (a.rawBind τ).norm := by
    cases a <;> simp only [Ty.rawBind, Ty.norm, Ty.bind_sameTypes _ h, Tel.bind_sameTypes _ h,
      normBindTys_sameTypes _ h, Eff.bind_sameTypes _ h, h.ranges, h.values]
    case tvar i => exact h.types i
    case tapp i as => exact rawApply_norm_congr (h.types i) (normBindTys_sameTypes as h)
  theorem Tel.bind_sameTypes (t : Tel) {θ τ} (h : SubstEnv.SameTypes θ τ) : Tel.norm (Tel.rawBind θ t) = Tel.norm (Tel.rawBind τ t) := by
    cases t with
    | done r e => simp only [Tel.rawBind, Tel.norm, Ty.bind_sameTypes r h, Eff.bind_sameTypes e h]
    | param n a t => simp only [Tel.rawBind, Tel.norm, Ty.bind_sameTypes a h, Tel.bind_sameTypes t h.up]
  theorem normBindTys_sameTypes (as : List Ty) {θ τ} (h : SubstEnv.SameTypes θ τ) :
      Ty.normTys (rawBindTys θ as) = Ty.normTys (rawBindTys τ as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys, Ty.normTys, Ty.bind_sameTypes a h, normBindTys_sameTypes as h]
  theorem Eff.bind_sameTypes (e : Eff) {θ τ} (h : SubstEnv.SameTypes θ τ) : Eff.norm (Eff.rawBind θ e) = Eff.norm (Eff.rawBind τ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, Eff.norm, h.rows, h.ranges, Ty.normTys_append, normBindTys_sameTypes fs h]
end

theorem Ty.subst_norm_images (a : Ty) (ts : List Ty) : a.subst (Ty.normTys ts) [] = a.subst ts [] := by
  apply Ty.bind_sameTypes
  refine ⟨?_, rfl, rfl, rfl⟩
  intro i
  simp only [typeEnvAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, Ty.normTys_eq_map,
    List.length_map, List.getElem?_map]
  split
  · cases ht : ts[i]? with
    | none => rfl
    | some a => simp only [Option.map_some, Option.getD_some, shiftTypes_zero, Ty.norm_idem]
  · rfl

end Benitoite.Release.Refinement
