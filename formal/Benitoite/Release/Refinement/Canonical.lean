import Benitoite.Release.Refinement.InversionCore
import Benitoite.Release.Refinement.Typing

/-!
# 型付き値からの構文情報の取り出し

V_Sub の鎖では要素の LeQ と TelClosure を合成する。
受信前の carrier ではなく、元の型の値の導出を入力にする。
-/
namespace Benitoite.Release.Refinement

theorem HasTypeVQ.inv_list {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
    ∃ a, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
      ∃ b, T.listCore = some b ∧ Ty.LeQ Γ Φ a b := by
  match h with
  | .V_List hs _ _ _ => cases hv; exact ⟨_, hs, _, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨a, hs, b, hb, hab⟩ := h.inv_list hv
    have hl : Ty.LeQ Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨c, hc, hbc⟩ := hl.listCore hb
    exact ⟨a, hs, c, hc, .trans hab hbc⟩
  | .V_Sub h hl _ _ _ =>
    obtain ⟨a, hs, b, hb, hab⟩ := h.inv_list hv
    obtain ⟨c, hc, hbc⟩ := hl.listCore hb
    exact ⟨a, hs, c, hc, .trans hab hbc⟩
  | .V_Refine h .. =>
    obtain ⟨a, hs, b, hb, hab⟩ := h.inv_list hv
    exact ⟨a, hs, b, hb, hab⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam ..
  | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op ..
  | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern ..
  | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError ..
  | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise ..
  | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con ..
  | .V_Super .. => cases hv

theorem HasTypeVQ.inv_closure {P B Ψ Q C Γ Φ v T runtime body}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .closure runtime body) :
    ∃ t u, Ty.Annotation P C Γ (.dependentFn t) ∧
      Tel.RuntimeShape runtime t ∧ DependentClosureTy P B Ψ body t ∧
      T.fnCore = some u ∧ TelClosure Γ Φ t u := by
  match h with
  | .V_Closure ha hr hb => cases hv; exact ⟨_, _, ha, hr, hb, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨t, u, ha, hr, hb, hu, htu⟩ := h.inv_closure hv
    have hl : Ty.LeQ Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, huw⟩ := hl.fnCore hu
    exact ⟨t, w, ha, hr, hb, hw, htu.trans huw⟩
  | .V_Sub h hl _ _ _ =>
    obtain ⟨t, u, ha, hr, hb, hu, htu⟩ := h.inv_closure hv
    obtain ⟨w, hw, huw⟩ := hl.fnCore hu
    exact ⟨t, w, ha, hr, hb, hw, htu.trans huw⟩
  | .V_Refine h .. =>
    obtain ⟨t, u, ha, hr, hb, hu, htu⟩ := h.inv_closure hv
    exact ⟨t, u, ha, hr, hb, hu, htu⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam ..
  | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef ..
  | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked ..
  | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map ..
  | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef ..
  | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super ..
  | .V_List .. => cases hv

private theorem canonical_ref_aux {P B Ψ Q C Γ Φ v T a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = []) (ha : T.refCore = some a) :
    ∃ l b, v = .loc l ∧ Ψ l = some (.ref b) ∧ b.norm = a.norm := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Const (c := c) _ => cases c <;> simp [Const.type, Ty.refCore] at ha
  | .V_LocRef hi _ => cases ha; exact ⟨_, _, rfl, hi, rfl⟩
  | .V_Normal (a := T0) h =>
    have hl : Ty.LeQ Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨b, hb, he⟩ := hl.refCore_right ha
    obtain ⟨l, c, hv, hc, hcb⟩ := canonical_ref_aux h hΓ hb
    exact ⟨l, c, hv, hc, hcb.trans he⟩
  | .V_Sub h hl _ _ _ =>
    obtain ⟨b, hb, he⟩ := hl.refCore_right ha
    obtain ⟨l, c, hv, hc, hcb⟩ := canonical_ref_aux h hΓ hb
    exact ⟨l, c, hv, hc, hcb.trans he⟩
  | .V_Refine h .. => exact canonical_ref_aux h hΓ ha
  | .V_AtError hs => rw [hs.errorType_eq] at ha; cases ha
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
    .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
    .V_Super .. | .V_List .. => cases ha

theorem HasTypeVQ.canonical_ref {P B Ψ Q C Φ v T a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ha : T.refCore = some a) :
    ∃ l b, v = .loc l ∧ Ψ l = some (.ref b) ∧ b.norm = a.norm :=
  canonical_ref_aux h rfl ha

end Benitoite.Release.Refinement
