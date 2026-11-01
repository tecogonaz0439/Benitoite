import Benitoite.Release.Refinement.ValueFacts
open Benitoite Benitoite.Release.Refinement
namespace RV
/-! widen で読む sort が、検証済みの宣言の下で実の型引数へ戻ること。 -/
theorem sort_obs (a : Ty) : a.observationType.sort? = a.sort? := by
  cases a <;> try rfl
  case refined a p => exact sort_obs a

theorem env_get (as : List Ty) (i) (a) (h : as[i]? = some a) :
    (typeEnvAt 0 as []).types i = a := by
  have hl := (List.getElem?_eq_some_iff.mp h).1
  have he := (List.getElem?_eq_some_iff.mp h).2
  simp [typeEnvAt, hl, shiftTypes_zero, he]

theorem sort_reflect_aux {P vs as bs} (hl : TypeArgsLe P [] [] vs (observationTypes as) (observationTypes bs))
    {s} : (a : Ty) → a.VarianceOK P vs .positive → a.HasKind P (List.replicate vs.length .value) .value →
    (a.rawBind (typeEnvAt 0 bs [])).HasSort s → (a.rawBind (typeEnvAt 0 as [])).HasSort s := by
  intro a hv hk hs
  cases a <;> try exact hs
  case tvar i =>
    obtain ⟨v, hgv, ha⟩ := hv
    obtain ⟨x, y, hx, hy, hr⟩ := hl.get i v hgv
    have hx' := hx; have hy' := hy
    simp only [observationTypes_eq_map, List.getElem?_map, Option.map_eq_some_iff] at hx' hy'
    obtain ⟨x', hx1, rfl⟩ := hx'
    obtain ⟨y', hy1, rfl⟩ := hy'
    simp only [Ty.rawBind, env_get _ _ _ hx1, env_get _ _ _ hy1] at hs ⊢
    have ho : y'.observationType.HasSort s := by simpa only [Ty.HasSort, sort_obs] using hs
    have : x'.observationType.HasSort s := by
      cases v <;> simp only [Variance.accepts] at ha
      · exact Ty.LeQ.hasSort_source hr ho
      · apply (Ty.hasSort_norm _ s).mp
        have hr' : x'.observationType.norm = y'.observationType.norm := hr
        rw [hr']
        exact (Ty.hasSort_norm _ s).mpr ho
    simpa only [Ty.HasSort, sort_obs] using this
  case tapp i xs =>
    simp only [Ty.HasKind] at hk
    obtain ⟨hk, _⟩ := hk
    have hi := (List.getElem?_eq_some_iff.mp hk)
    obtain ⟨hlt, he⟩ := hi
    simp at he
  case refined a p => exact sort_reflect_aux hl a hv hk.1 hs
#print axioms sort_reflect_aux
end RV
