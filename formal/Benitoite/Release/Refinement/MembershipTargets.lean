import Benitoite.Release.Refinement.ScopeCoverage
import Benitoite.Release.Refinement.CanonicalValues

/-! # 型付きの保持値の対象と範囲への所属 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

private theorem holds_index {T : Ty} {o k ix o' k' ix'} (h : T.Holds o k ix)
    (h' : T.Holds o' k' ix') : ix = ix' := by
  rcases h with h | h <;> rcases h' with h' | h'
  all_goals have he := h.symm.trans h'
  all_goals cases he
  all_goals rfl

theorem HasTypeVQ.target_member {P B Ψ Q v T o k r σ}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (ha : v.Adequate σ) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t := by
  rcases hv.canonical_held ht with ⟨o',payload,rfl⟩ | ⟨t,rfl⟩ |
    ⟨t,req,rfl⟩ | ⟨s,snapshot,t,req,rfl⟩
  · obtain ⟨hc,he⟩ := hv.inv_const rfl
    have ht' : T.Holds o' k (.fixed .top) := Or.inr he
    cases Ty.Holds.unique_name ht' ht
    change B.valKind o = none ∧ _ at hc
    rw [hk] at hc
    cases hc.1
  · obtain ⟨o',k',s,ix,hk',_,hm,ht',hc⟩ := hv.inv_checked rfl
    cases Ty.Holds.unique_name ht' ht
    cases Option.some.inj (hk'.symm.trans hk)
    cases holds_index ht ht'
    exact ⟨t,rfl,hc.mem σ ⟨hm.1,by simpa [RangeExpr.resolve] using hm.2⟩⟩
  · obtain ⟨o',s,A,ix,hk',_,_,_,_,hm,ht',hc⟩ := hv.inv_checkedRequest rfl
    cases Ty.Holds.unique_name ht' ht
    cases Option.some.inj (hk'.symm.trans hk)
    cases holds_index ht ht'
    exact ⟨t,rfl,hc.mem σ ⟨hm.1,by simpa [RangeExpr.resolve] using hm.2⟩⟩
  · obtain ⟨o',k',ix,hw,ht',hc⟩ := hv.inv_checkedAt rfl
    cases Ty.Holds.unique_name ht' ht
    cases holds_index ht ht'
    cases hw with
    | plain hk' _ _ hm =>
      cases Option.some.inj (hk'.symm.trans hk)
      exact ⟨t,rfl,hc.mem σ (hm.current ha.1)⟩
    | request hk' _ _ _ _ hm =>
      cases Option.some.inj (hk'.symm.trans hk)
      exact ⟨t,rfl,hc.mem σ (hm.current ha.1)⟩
end Benitoite.Release.Refinement
