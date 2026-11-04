import Benitoite.Release.Refinement.ScopeCoverage
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.ClosedEvaluation

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

/-- 対象の所属の解釈は、同じ snapshot のまま被覆で広げられる。 -/
theorem Pred.member_mono {η : ObservationEnvModel} {k : Kind} {a : Term}
    {r s : RangeExpr} (hc : s.Covers r)
    (hm : (Pred.member k a r).interpret η = true) :
    (Pred.member k a s).interpret η = true := by
  change (Pred.member k a r).atomValue η = true at hm
  change (Pred.member k a s).atomValue η = true
  unfold Pred.atomValue at hm ⊢
  cases ho : observeAs η (.target k) a <;> simp only [ho] at hm ⊢ <;> try cases hm
  exact of_decide_eq_true hm |>.mono hc |> decide_eq_true

example {η : ObservationEnvModel} {a : Term} {r s : RangeExpr} (hc : s.Covers r) :
    ((Pred.member .path a r).interpret η = true → (Pred.member .path a s).interpret η = true) ∧
    ((Pred.member .host a r).interpret η = true → (Pred.member .host a s).interpret η = true) ∧
    ((Pred.member .endpoint a r).interpret η = true → (Pred.member .endpoint a s).interpret η = true) :=
  ⟨Pred.member_mono hc, Pred.member_mono hc, Pred.member_mono hc⟩

/-- 範囲の具体化で固定範囲を得た所属を、同時に具体化した被覆側へ渡す。 -/
theorem Pred.member_inst_mono {η : ObservationEnvModel} {k : Kind} {a : Term}
    {outer inner : RangeIx} (hc : outer.Covers inner) (rs : List RangeExpr)
    {r : RangeExpr} (hi : inner.inst rs = .fixed r)
    (hm : (Pred.member k a r).interpret η = true) :
    ∃ s, outer.inst rs = .fixed s ∧ (Pred.member k a s).interpret η = true := by
  have hh := hc.inst rs
  rw [hi] at hh
  cases ho : outer.inst rs with
  | rvar i => rw [ho] at hh; cases hh
  | fixed s => rw [ho] at hh; exact ⟨s, rfl, Pred.member_mono hh hm⟩

example {η : ObservationEnvModel} (k : Kind) (a : Term) (rs : List RangeExpr)
    (i : Nat) {r : RangeExpr} (hi : rs[i]? = some r)
    (hm : (Pred.member k a r).interpret η = true) :
    ∃ s, (RangeIx.rvar i).inst rs = .fixed s ∧ (Pred.member k a s).interpret η = true :=
  Pred.member_inst_mono (outer := .rvar i) (inner := .rvar i) rfl rs
    (by simp [RangeIx.inst, hi]) hm

example (η : ObservationEnvModel) (k : Kind) (a : Term) (b : PathBase) (p : PathPattern)
    (t : Target) (ho : a.observe η = some (.targetValue none t)) :
    (Pred.member k a (.based b p)).evalWith η = none := by
  simp [Pred.evalWith, Pred.atomReady, memberReady, ho, resolveSnapshot]
end Benitoite.Release.Refinement
