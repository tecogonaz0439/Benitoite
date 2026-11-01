import Benitoite.Release.Refinement.ValueFacts
import Benitoite.Release.Refinement.AtTyping

/-!
# 保持値の逆転と範囲の共変

保持要求は部分型や正規化を通しても同じ値である。
型の芯だけを比較する補助判断は、元の範囲からの被覆を別に返す。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}

def Ty.Holds (a : Ty) (o : OpaqueName) (k : Scope.Domain.Kind) (ix : RangeIx) : Prop :=
  a.norm.core = .scoped o k ix ∨ a.norm.core = .opaque o ix

theorem RangeIx.Covers.refl (ix : RangeIx) : ix.Covers ix := by
  cases ix <;> simp [RangeIx.Covers, RangeExpr.Covers.refl]

theorem RangeIx.Covers.trans {a b c : RangeIx} (h : a.Covers b) (g : b.Covers c) : a.Covers c := by
  cases a <;> cases b <;> cases c <;> simp only [RangeIx.Covers] at *
  all_goals first | contradiction | exact h.trans g

@[simp] theorem Ty.holds_norm (a : Ty) (o k ix) : a.norm.Holds o k ix ↔ a.Holds o k ix := by
  simp only [Ty.Holds, Ty.norm_idem]

@[simp] theorem Ty.holds_refined (a : Ty) (p : Pred) (o k ix) :
    (Ty.refined a p).Holds o k ix ↔ a.Holds o k ix := by
  simp only [Ty.Holds, Ty.refined_norm_core]

theorem Ty.Holds.unique_name {a : Ty} {o k ix o' k' ix'} (h : a.Holds o k ix)
    (g : a.Holds o' k' ix') : o = o' := by
  rcases h with h | h <;> rcases g with g | g
  all_goals have he := h.symm.trans g
  all_goals cases he
  all_goals rfl

theorem Ty.LeQ.holds {Γ Φ a b o k ix}
    (h : Ty.LeQ P Γ Φ a b) (ha : a.Holds o k ix) :
    ∃ jx, b.Holds o k jx ∧ jx.Covers ix := by
  match h with
  | .refl => exact ⟨ix,ha,.refl _⟩
  | .convert he => exact ⟨ix,by simpa only [Ty.Holds, ←he] using ha,.refl _⟩
  | .trans h g =>
    obtain ⟨jx,hb,hji⟩ := h.holds ha
    obtain ⟨kx,hc,hkj⟩ := g.holds hb
    exact ⟨kx,hc,hkj.trans hji⟩
  | .forget | .introduce .. => exact ⟨ix,by simpa only [Ty.holds_refined] using ha,.refl _⟩
  | .refine h .. => simpa only [Ty.holds_refined] using h.holds (by simpa only [Ty.holds_refined] using ha)
  | .scoped hc =>
    rcases ha with ha | ha
    · simp only [Ty.norm, Ty.core, Ty.scoped.injEq] at ha
      obtain ⟨rfl,rfl,rfl⟩ := ha
      exact ⟨_,Or.inl rfl,hc⟩
    · cases ha
  | .scoped_forget =>
    rcases ha with ha | ha
    · simp only [Ty.norm, Ty.core, Ty.scoped.injEq] at ha
      obtain ⟨rfl,rfl,rfl⟩ := ha
      exact ⟨_,Or.inr rfl,.refl _⟩
    · cases ha
  | .data _ | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ => rcases ha with ha | ha <;> cases ha
  | .dependentFn _ =>
    rcases ha with ha | ha
    all_goals simp only [Ty.norm, Ty.core_foldFn] at ha
    all_goals unfold Ty.foldFn at ha
    all_goals split at ha <;> cases ha

theorem HasTypeVQ.inv_checked {P B Ψ Q C Γ Φ v T target}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checked target) :
    ∃ o k range ix, B.valKind o = some k ∧ B.valContent o = none ∧
      Scope.Domain.Range.MemK k range target ∧ T.Holds o k ix ∧
      ix.Covers (.fixed (.absolute range)) := by
  match h with
  | .V_Checked hk hc hm => cases hv; exact ⟨_,_,_,_,hk,hc,hm,Or.inl rfl,.refl _⟩
  | .V_Normal h =>
    obtain ⟨o,k,r,ix,hk,hc,hm,ht,hi⟩ := h.inv_checked hv
    exact ⟨o,k,r,ix,hk,hc,hm,(Ty.holds_norm ..).mpr ht,hi⟩
  | .V_Sub h hl .. =>
    obtain ⟨o,k,r,ix,hk,hc,hm,ht,hi⟩ := h.inv_checked hv
    obtain ⟨jx,hj,hji⟩ := hl.holds ht
    exact ⟨o,k,r,jx,hk,hc,hm,hj,hji.trans hi⟩
  | .V_Refine h .. =>
    obtain ⟨o,k,r,ix,hk,hc,hm,ht,hi⟩ := h.inv_checked hv
    exact ⟨o,k,r,ix,hk,hc,hm,(Ty.holds_refined ..).mpr ht,hi⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_CheckedRequest .. | .V_CheckedAt .. |
      .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.inv_checkedRequest {P B Ψ Q C Γ Φ v T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedRequest target req) :
    ∃ o range A ix, B.valKind o = some .endpoint ∧ B.valContent o = some A ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧ Scope.Domain.Range.MemK .endpoint range target ∧
      T.Holds o .endpoint ix ∧ ix.Covers (.fixed (.absolute range)) := by
  match h with
  | .V_CheckedRequest hk hc hh hg ht hm =>
    cases hv; exact ⟨_,_,_,_,hk,hc,hh,hg,ht,hm,Or.inl rfl,.refl _⟩
  | .V_Normal h =>
    obtain ⟨o,r,A,ix,hk,hc,hh,hg,ht,hm,ha,hi⟩ := h.inv_checkedRequest hv
    exact ⟨o,r,A,ix,hk,hc,hh,hg,ht,hm,(Ty.holds_norm ..).mpr ha,hi⟩
  | .V_Sub h hl .. =>
    obtain ⟨o,r,A,ix,hk,hc,hh,hg,ht,hm,ha,hi⟩ := h.inv_checkedRequest hv
    obtain ⟨jx,hj,hji⟩ := hl.holds ha
    exact ⟨o,r,A,jx,hk,hc,hh,hg,ht,hm,hj,hji.trans hi⟩
  | .V_Refine h .. =>
    obtain ⟨o,r,A,ix,hk,hc,hh,hg,ht,hm,ha,hi⟩ := h.inv_checkedRequest hv
    exact ⟨o,r,A,ix,hk,hc,hh,hg,ht,hm,(Ty.holds_refined ..).mpr ha,hi⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedAt .. |
      .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.checkedRequest_facts {P B Ψ Q C Γ Φ T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T) :
    ∃ A : Ty, HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧
      ∀ t, req.toTerm? = some t → ∀ p ∈ A.assume, Entails [] (p.open t) := by
  obtain ⟨_,_,A,_,_,_,hh,hg,ht,_,_,_⟩ := h.inv_checkedRequest rfl
  exact ⟨A,hh,hg,ht,fun t he p hp => hh.facts he p (by simpa only [Ty.assume_norm] using hp)⟩

theorem HasTypeVQ.checkedRequest_content {P B Ψ Q C Γ Φ T target req o ix A}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T)
    (ht : T.Holds o .endpoint ix) (hc : B.valContent o = some A) :
    HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧ req.reqTarget = some target := by
  obtain ⟨o',_,A',_,_,hc',hh,hg,he,_,ht',_⟩ := h.inv_checkedRequest rfl
  have hn := Ty.Holds.unique_name ht' ht
  subst o'
  have ha : A' = A := Option.some.inj (hc'.symm.trans hc)
  subst A'
  exact ⟨hh,hg,he⟩

theorem HasTypeVQ.checkedRequest_mismatch {P B Ψ Q C Γ Φ T target req}
    (ht : req.reqTarget ≠ some target) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T := by
  intro h
  obtain ⟨_,_,_,_,_,_,_,_,he,_,_,_⟩ := h.inv_checkedRequest rfl
  exact ht he

theorem HasTypeVQ.checked_without_request {P B Ψ Q C Γ Φ T target o k ix}
    (hc : B.valContent o ≠ none) (ht : T.Holds o k ix) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checked target) T := by
  intro h
  obtain ⟨o',_,_,_,_,hc',_,ht',_⟩ := h.inv_checked rfl
  have he := Ty.Holds.unique_name ht' ht
  subst o'
  exact hc hc'

theorem HasTypeVQ.checked_widen {P B Ψ Q C Γ Φ o k r t outer}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k r t) (hw : outer.Covers (.absolute r)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checked t) (.scoped o k (.fixed outer)) :=
  .V_Sub (.V_Checked hk hc hm) (.scoped hw) trivial trivial trivial

theorem HasTypeVQ.checkedRequest_widen {P B Ψ Q C Γ Φ o r t req A outer}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some A)
    (hh : HasTypeV P B Ψ [] [] [] req A.norm) (hg : groundVal req = true)
    (ht : req.reqTarget = some t) (hm : Scope.Domain.Range.MemK .endpoint r t)
    (hw : outer.Covers (.absolute r)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest t req) (.scoped o .endpoint (.fixed outer)) :=
  .V_Sub (.V_CheckedRequest hk hc hh hg ht hm) (.scoped hw) trivial trivial trivial

theorem HasTypeVQ.inv_checkedAt {P B Ψ Q C Γ Φ v T r snapshot target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedAt r snapshot target req) :
    ∃ o k ix, CheckedWitness P B Ψ o k r snapshot target req ∧
      T.Holds o k ix ∧ ix.Covers (.fixed r) := by
  match h with
  | .V_CheckedAt hw => cases hv; exact ⟨_,_,_,hw,Or.inl rfl,.refl _⟩
  | .V_Normal h =>
    obtain ⟨o,k,ix,hw,ht,hi⟩ := h.inv_checkedAt hv
    exact ⟨o,k,ix,hw,(Ty.holds_norm ..).mpr ht,hi⟩
  | .V_Sub h hl .. =>
    obtain ⟨o,k,ix,hw,ht,hi⟩ := h.inv_checkedAt hv
    obtain ⟨jx,hj,hji⟩ := hl.holds ht
    exact ⟨o,k,jx,hw,hj,hji.trans hi⟩
  | .V_Refine h .. =>
    obtain ⟨o,k,ix,hw,ht,hi⟩ := h.inv_checkedAt hv
    exact ⟨o,k,ix,hw,(Ty.holds_refined ..).mpr ht,hi⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

theorem CheckedWitness.request_content {P B Ψ o k r snapshot target req}
    (h : CheckedWitness P B Ψ o k r snapshot target (some req)) :
    k = .endpoint ∧ ∃ A, B.valContent o = some A ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧ req.reqTarget = some target := by
  cases h with
  | request _ hc hh hg ht _ => exact ⟨rfl,_,hc,hh,hg,ht⟩

theorem HasTypeVQ.checkedAt_request_mismatch {P B Ψ Q C Γ Φ T r snapshot target req}
    (ht : req.reqTarget ≠ some target) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target (some req)) T := by
  intro h
  obtain ⟨_,_,_,hw,_,_⟩ := h.inv_checkedAt rfl
  obtain ⟨_,_,_,_,_,he⟩ := hw.request_content
  exact ht he

theorem HasTypeVQ.checkedAt_without_request {P B Ψ Q C Γ Φ T r snapshot target o k ix}
    (hc : B.valContent o ≠ none) (ht : T.Holds o k ix) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target none) T := by
  intro h
  obtain ⟨o',_,_,hw,ht',_⟩ := h.inv_checkedAt rfl
  have he := Ty.Holds.unique_name ht' ht
  subst o'
  cases hw with
  | plain _ hc' _ _ => exact hc hc'

end Benitoite.Release.Refinement
