import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.TypedFacts

/-!
# 値の観測と、要素・構成子の欄の事実

部分型の推移と篩の正規化は既存の assume の導出を使う。
欄の型は、値に保持された構成子とその型引数で具体化する。
-/
namespace Benitoite.Release.Refinement

theorem HasTypeVQ.facts {P B Ψ Q C Γ Φ v a t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (ht : v.toTerm? = some t) :
    ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  simpa only [ht, Option.getD_some] using h.assume

theorem HasTypeVQ.subtype_facts {P B Ψ Q C Γ Φ v a b t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hl : Ty.LeQ Γ Φ a b)
    (ht : v.toTerm? = some t) :
    ∀ p ∈ b.assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  intro p hp
  apply ((hl.assume p hp).bind (fun i => match i with
    | 0 => some t | j+1 => some (.var j))).cut
  intro q hq
  obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
  rcases List.mem_append.mp hr with hr | hr
  · exact h.facts ht r hr
  · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hr
    change Entails _ (s.lift.open t)
    rw [Pred.open_lift]
    exact .hyp hs

theorem Ty.LeQ.dataCore {Γ Φ a b d ts} (h : Ty.LeQ Γ Φ a b)
    (hd : a.norm.core = .data d ts) : b.norm.core = .data d ts := by
  match h with
  | .refl => exact hd
  | .convert he => rwa [←he]
  | .trans h g => exact g.dataCore (h.dataCore hd)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using hd
  | .refine h .. => simpa only [Ty.refined_norm_core] using
      (h.dataCore (by simpa only [Ty.refined_norm_core] using hd))
  | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ |
      .scoped _ | .scoped_forget =>
    first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd

theorem Ty.LeQ.constCore {Γ Φ a b} {c : Const} (h : Ty.LeQ Γ Φ a b)
    (ha : a.norm.core = c.type.norm.core) : b.norm.core = c.type.norm.core := by
  match h with
  | .refl => exact ha
  | .convert he => rwa [←he]
  | .trans h g => exact g.constCore (h.constCore ha)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using ha
  | .refine h .. => simpa only [Ty.refined_norm_core] using
      (h.constCore (by simpa only [Ty.refined_norm_core] using ha))
  | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ |
      .scoped _ | .scoped_forget =>
    cases c <;> simp only [Const.type, Ty.norm, Ty.core] at ha
    all_goals try cases ha
    all_goals simp only [Ty.core_foldFn] at ha
    all_goals unfold Ty.foldFn at ha
    all_goals split at ha <;> cases ha

theorem HasTypeVQ.inv_const {P B Ψ Q C Γ Φ v T c}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .const c) :
    ConstOK B c ∧ T.norm.core = c.type.norm.core := by
  match h with
  | .V_Const hc => cases hv; exact ⟨hc, rfl⟩
  | .V_Normal h =>
    obtain ⟨hc, ht⟩ := h.inv_const hv
    exact ⟨hc, by simpa only [Ty.norm_idem] using ht⟩
  | .V_Sub h hl .. =>
    obtain ⟨hc, ht⟩ := h.inv_const hv
    exact ⟨hc, hl.constCore ht⟩
  | .V_Refine h .. =>
    obtain ⟨hc, ht⟩ := h.inv_const hv
    exact ⟨hc, by simpa only [Ty.refined_norm_core] using ht⟩
  | .V_Var .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
      .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.integer_facts {P B Ψ Q C Γ Φ T n}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.const (.integer n)) T) :
    ConstOK B (.integer n) ∧ T.norm.core = .base .integer ∧
    ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.integer n.toInt)) :=
  ⟨(h.inv_const rfl).1, (h.inv_const rfl).2, h.facts rfl⟩

theorem HasTypeEachQ.member {P B Ψ Q C Γ Φ vs a v}
    (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hv : v ∈ vs) :
    HasTypeVQ P B Ψ Q C Γ Φ v a := by
  match h with
  | .nil => cases hv
  | .cons hh hs =>
    rcases List.mem_cons.mp hv with rfl | hv
    · exact hh
    · exact hs.member hv

theorem HasTypeVsQ.get {P B Ψ Q C Γ Φ vs as} {i : Nat} {a : Ty}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (ha : as[i]? = some a) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v a := by
  match h with
  | .nil => simp at ha
  | .cons hh hs =>
    cases i with
    | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at ha; subst a; exact ⟨_, rfl, hh⟩
    | succ i => exact hs.get ha

theorem HasTypeVQ.list_facts {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
    (∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
      T.listCore = some b ∧ Ty.LeQ Γ Φ a b) ∧
    ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.listValue (Val.toTermSlots vs))) := by
  obtain ⟨a, ha, b, hb, hl⟩ := h.inv_list hv
  refine ⟨⟨a,b,ha,hb,hl⟩, ?_⟩
  exact h.facts (by rw [hv]; rfl)

theorem HasTypeVQ.inv_con {P B Ψ Q C Γ Φ v T c ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
      T.norm.core = .data cd.data (Ty.normTys ts) := by
  match h with
  | .V_Con hc hn _ _ hs _ => cases hv; exact ⟨_,hc,hn,hs,rfl⟩
  | .V_Normal h =>
    obtain ⟨cd,hc,hn,hs,ht⟩ := h.inv_con hv
    exact ⟨cd,hc,hn,hs,by simpa only [Ty.norm_idem] using ht⟩
  | .V_Sub h hl .. =>
    obtain ⟨cd,hc,hn,hs,ht⟩ := h.inv_con hv
    exact ⟨cd,hc,hn,hs,hl.dataCore ht⟩
  | .V_Refine h .. =>
    obtain ⟨cd,hc,hn,hs,ht⟩ := h.inv_con hv
    exact ⟨cd,hc,hn,hs,by simpa only [Ty.refined_norm_core] using ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.con_field {P B Ψ Q C Γ Φ T c ts vs cd} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst ts []) := by
  obtain ⟨cd',hc',_,hs,_⟩ := h.inv_con rfl
  have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  exact hs.get (by simp only [List.getElem?_map, ha, Option.map_some])

theorem HasTypeVQ.field_facts {P B Ψ Q C Γ Φ T c ts vs cd} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a)
    (ht : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst ts []).assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  obtain ⟨v,hv,hvty⟩ := h.con_field hc ha
  have he : v.toTerm? = some t := by
    simpa only [Val.toTermSlots_eq_map, List.getElem?_map, hv, Option.map_some,
      Option.some.injEq] using ht
  exact hvty.facts he

theorem HasTypeVQ.list_element_facts {P B Ψ Q C Γ Φ T vs b v t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.list vs) T) (hb : T.listCore = some b) (hv : v ∈ vs)
    (ht : v.toTerm? = some t) : ∀ p ∈ b.assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  obtain ⟨⟨a,b',hs,hb',hl⟩,_⟩ := h.list_facts rfl
  have : b' = b := Option.some.inj (hb'.symm.trans hb)
  subst this
  exact (hs.member hv).subtype_facts hl ht

-- data の欄を型の側の引数で読む
theorem HasTypeVQ.field_facts_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (hs : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  obtain ⟨cd',hc',_,_,ht⟩ := h.inv_con rfl
  have : cd' = cd := Option.some.inj (hc'.symm.trans hc); subst this
  have : us = Ty.normTys ts := by rw [hT] at ht; cases ht; rfl
  subst this
  rw [Ty.subst_norm_images]
  exact h.field_facts hc ha hs

end Benitoite.Release.Refinement
