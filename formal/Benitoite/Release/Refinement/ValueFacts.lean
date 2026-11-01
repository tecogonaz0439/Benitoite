import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.TypedFacts
import Benitoite.Release.Refinement.TypeFormation

/-!
# 値の観測と、要素・構成子の欄の事実

部分型の推移と篩の正規化は既存の assume の導出を使う。
欄の型は、値に保持された構成子とその型引数で具体化する。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}

theorem HasTypeVQ.facts {P B Ψ Q C Γ Φ v a t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (ht : v.toTerm? = some t) :
    ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  simpa only [ht, Option.getD_some] using h.assume

theorem HasTypeVQ.subtype_facts {P B Ψ Q C Γ Φ v a b t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hl : Ty.LeQ P Γ Φ a b)
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

theorem Ty.LeQ.constCore {Γ Φ a b} {c : Const} (h : Ty.LeQ P Γ Φ a b)
    (ha : a.norm.core = c.type.norm.core) : b.norm.core = c.type.norm.core := by
  match h with
  | .refl => exact ha
  | .convert he => rwa [←he]
  | .trans h g => exact g.constCore (h.constCore ha)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using ha
  | .refine h .. => simpa only [Ty.refined_norm_core] using
      (h.constCore (by simpa only [Ty.refined_norm_core] using ha))
  | .data _ | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ |
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
      T.listCore = some b ∧ Ty.LeQ P Γ Φ a b) ∧
    ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.listValue (Val.toTermSlots vs))) := by
  obtain ⟨a, ha, b, hb, hl⟩ := h.inv_list hv
  refine ⟨⟨a,b,ha,hb,hl⟩, ?_⟩
  exact h.facts (by rw [hv]; rfl)

theorem HasTypeVQ.inv_con {P B Ψ Q C Γ Φ v T c ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      TypeArgsKinded P C ts (List.replicate cd.ntys .value) ∧
      Ty.Annotation P C Γ (.data cd.data ts) ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
      ∃ us, T.norm.core = .data cd.data us ∧
        TypeArgsLe P Γ Φ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us := by
  match h with
  | .V_Con hc hn hk _ hs ha =>
    cases hv
    exact ⟨_,hc,hn,hk,ha,hs,_,rfl,TypeArgsLe.refl _ _ (by simp)⟩
  | .V_Normal h =>
    obtain ⟨cd,hc,hn,hk,ha,hs,us,ht,hu⟩ := h.inv_con hv
    exact ⟨cd,hc,hn,hk,ha,hs,us,by simpa only [Ty.norm_idem] using ht,hu⟩
  | .V_Sub h hl .. =>
    obtain ⟨cd,hc,hn,hk,ha,hs,us,ht,hu⟩ := h.inv_con hv
    obtain ⟨bs,hb,hr⟩ := hl.dataCore ht
    have hlen : us.length = ts.length := by
      simpa only [Program.varianceFor_length] using hu.length.2
    rw [hlen] at hr
    exact ⟨cd,hc,hn,hk,ha,hs,bs,hb,hu.trans hr⟩
  | .V_Refine h .. =>
    obtain ⟨cd,hc,hn,hk,ha,hs,us,ht,hu⟩ := h.inv_con hv
    exact ⟨cd,hc,hn,hk,ha,hs,us,by simpa only [Ty.refined_norm_core] using ht,hu⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.con_field {P B Ψ Q C Γ Φ T c ts vs cd} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst ts []) := by
  obtain ⟨cd',hc',_,_,_,hs,_⟩ := h.inv_con rfl
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

theorem Ty.Annotation.data_args {P C Γ d ts} (h : Ty.Annotation P C Γ (.data d ts)) :
    TypeAnnotations P C Γ ts := by
  have hw : Ty.WFList 0 C.length Γ.length ts := h.wf
  have hs : sortedTys Γ ts := h.sorted
  have hd : declaredTys P C Γ ts := h.declared.2
  clear h
  intro a ha
  induction ts with
  | nil => cases ha
  | cons t ts ih =>
    rcases List.mem_cons.mp ha with rfl | ha
    · exact ⟨hw.1, hs.1, hd.1⟩
    · exact ih hw.2 hs.2 hd.2 ha

/-- 元の V_Con の注釈から、両側の欄の形成と型引数の入力を供給する。 -/
theorem HasTypeVQ.constructor_field_inputs {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t) :
    Ty.Annotation P C Γ (a.subst ts []) ∧ Ty.Annotation P C Γ (a.subst us []) ∧
      VarianceSubstInput P C Γ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us := by
  obtain ⟨cd', hc', hn, hk, hat, _, xs, ht, hr⟩ := h.inv_con rfl
  have sourceOrd := hk.ordinary
  have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  have hx : xs = us := (Ty.data.inj (ht.symm.trans hT)).2
  subst xs
  have hu : us.length = cd.ntys := by simpa only [Program.varianceFor_length, hn] using hr.length.2
  refine ⟨valid.field_annotation hc (List.mem_of_getElem? ha) hn hat.data_args sourceOrd,
    valid.field_annotation hc (List.mem_of_getElem? ha) hu targetTypes targetOrd, ?_⟩
  refine ⟨by simp, by simpa only [Program.varianceFor_length, hn] using hu, ?_⟩
  intro t ht
  rcases List.mem_append.mp ht with ht | ht
  · exact hat.data_args.norm t ht
  · exact targetTypes t ht

/-- 総称の欄の検査と型引数から、行き先の欄の型付けを得る。 -/
theorem HasTypeVQ.con_field_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst us []) := by
  obtain ⟨_, targetField, _⟩ := h.constructor_field_inputs hc hT ha valid targetTypes targetOrd
  obtain ⟨cd',hc',hn,hk,_,_,xs,ht,hr⟩ := h.inv_con rfl
  have sourceOrd := hk.ordinary
  have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  have hx : xs = us := (Ty.data.inj (ht.symm.trans hT)).2
  subst xs
  have field := (valid.2 c cd hc).2 a (List.mem_of_getElem? ha)
  have hl := variance_field_mono P Γ Φ (P.varianceFor cd.data ts.length) a (Ty.normTys ts) us
    (by simpa only [hn] using field.2.2)
    (by simpa only [Program.varianceFor_length, hn, List.length_replicate, List.length_nil] using field.1.wf)
    field.1.sorted (by
      intro t ht
      obtain ⟨s, hs, rfl⟩ := List.mem_map.mp (show t ∈ ts.map Ty.norm from (by simpa only [Ty.normTys_eq_map] using ht))
      exact (Ty.ordinary_norm _).mpr (sourceOrd s hs)) targetOrd hr
  rw [Ty.subst_norm_images] at hl
  obtain ⟨v,hv,hvty⟩ := h.con_field hc ha
  exact ⟨v,hv,HasTypeVQ.V_Sub hvty hl targetField.wf targetField.sorted targetField.declared⟩

theorem HasTypeVQ.field_facts_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t)
    (hs : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  obtain ⟨v,hv,hvty⟩ := h.con_field_by_type hc hT ha valid targetTypes targetOrd
  have he : v.toTerm? = some t := by
    simpa only [Val.toTermSlots_eq_map, List.getElem?_map, hv, Option.map_some,
      Option.some.injEq] using hs
  exact hvty.facts he

end Benitoite.Release.Refinement
