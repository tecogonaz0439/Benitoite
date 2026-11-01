import Benitoite.Release.Refinement.Declared

/-!
# 値注釈の移送による kind の保存

型の引数数と宣言したkindは、篩の述語や値の番号を読まない。
-/
namespace Benitoite.Release.Refinement

mutual
  theorem Ty.hasKind_shiftV_iff (a : Ty) (kind : TyKind) (k c : Nat) {P K} :
      (a.shiftV k c).HasKind P K kind ↔ a.HasKind P K kind := by
    cases kind with
    | constructor n => cases a <;> rfl
    | value =>
      cases a <;> simp only [Ty.shiftV, Ty.HasKind, Ty.hasKind_shiftV_iff,
        kindsList_shiftV_iff, kindsTel_shiftV_iff, kindsEff_shiftV_iff,
        Ty.notContCore_shiftV]
      all_goals simp only [NamesWF, shiftVTys_eq_map, List.length_map]
  theorem kindsList_shiftV_iff (as : List Ty) (k c : Nat) {P K} :
      kindsList P K (shiftVTys k c as) ↔ kindsList P K as := by
    cases as <;> simp only [shiftVTys, kindsList, Ty.hasKind_shiftV_iff, kindsList_shiftV_iff]
  theorem kindsTel_shiftV_iff (t : Tel) (k c : Nat) {P K} :
      kindsTel P K (t.shiftV k c) ↔ kindsTel P K t := by
    cases t <;> simp only [Tel.shiftV, kindsTel, Ty.hasKind_shiftV_iff, kindsTel_shiftV_iff, kindsEff_shiftV_iff]
  theorem kindsEff_shiftV_iff (e : Eff) (k c : Nat) {P K} :
      kindsEff P K (e.shiftV k c) ↔ kindsEff P K e := by
    cases e; exact kindsList_shiftV_iff _ _ _
end

theorem Ty.kind_of_toTel {P K ns ps r e} (hn : NamesWF ns ps)
    (h : kindsTel P K (Ty.toTel ns ps r e)) : (Ty.fn ns ps r e).HasKind P K .value := by
  induction ns generalizing ps r e with
  | nil =>
    cases ps with
    | nil => exact ⟨hn, trivial, h.1, h.2⟩
    | cons => simp [NamesWF] at hn
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      have ht := ih hn' h.2
      exact ⟨hn, ⟨h.1, (kindsList_shiftV_iff _ _ _).mp ht.2.1⟩,
        (Ty.hasKind_shiftV_iff _ _ _ _).mp ht.2.2.1,
        (kindsEff_shiftV_iff _ _ _).mp ht.2.2.2⟩

theorem Ty.kind_foldFn {P K t} (h : kindsTel P K t) : (Ty.foldFn t).HasKind P K .value := by
  classical
  by_cases he : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := he
    rw [Ty.foldFn_toTel]
    exact Ty.kind_of_toTel f.names_wf h
  · rw [Ty.foldFn_no_view he]
    exact h

theorem Ty.HasKind.core {P K a} (h : Ty.HasKind P K a .value) : a.core.HasKind P K .value := by
  cases a with
  | refined a _ => exact Ty.HasKind.core (a := a) h.1
  | _ => exact h

theorem Ty.kind_refineNorm {P K p} {a : Ty} (h : a.HasKind P K .value) (hc : a.NotContCore) :
    (a.refineNorm p).HasKind P K .value := by
  unfold Ty.refineNorm Ty.packRefinements
  split
  · exact h.core
  · exact ⟨h.core, by simpa only [Ty.NotContCore, Ty.core_idem] using hc⟩

mutual
  theorem Ty.HasKind.rawSubstV {P K a k} (h : Ty.HasKind P K a k) (ν : ObservationEnv) :
      Ty.HasKind P K (a.rawSubstV ν) k := by
    cases k with
    | constructor n => cases a <;> simp_all [Ty.HasKind, Ty.rawSubstV]
    | value =>
      cases a <;> simp only [Ty.HasKind] at h ⊢ <;> simp only [Ty.rawSubstV, Ty.HasKind]
      all_goals first | exact h | trivial | exact Ty.HasKind.rawSubstV h ν | exact kindsList_rawSubstV h ν | skip
      case data d as => exact ⟨by simpa only [substVTys_eq_map, List.length_map] using h.1, kindsList_rawSubstV h.2 ν⟩
      case fn ns ps r e => exact ⟨by simpa only [NamesWF, substVTys_eq_map, List.length_map] using h.1,
        kindsList_rawSubstV h.2.1 ν, Ty.HasKind.rawSubstV h.2.2.1 ν, kindsEff_rawSubstV h.2.2.2 ν⟩
      case dependentFn t => exact kindsTel_rawSubstV h ν
      case cont b t e => exact ⟨Ty.HasKind.rawSubstV h.1 ν, Ty.HasKind.rawSubstV h.2.1 ν, kindsEff_rawSubstV h.2.2 ν⟩
      case map a b => exact ⟨Ty.HasKind.rawSubstV h.1 ν, Ty.HasKind.rawSubstV h.2 ν⟩
      case dict cl a => obtain ⟨cd,hc,ha⟩ := h; exact ⟨cd,hc,Ty.HasKind.rawSubstV ha ν⟩
      case tapp i as => exact ⟨by simpa only [substVTys_eq_map, List.length_map] using h.1, kindsList_rawSubstV h.2 ν⟩
      case refined a p => exact ⟨Ty.HasKind.rawSubstV h.1 ν, (Ty.notContCore_rawSubstV _ _).mpr h.2⟩
  theorem kindsTel_rawSubstV {P K t} (h : kindsTel P K t) (ν : ObservationEnv) :
      kindsTel P K (Tel.rawSubstV ν t) := by
    cases t with
    | done r e => exact ⟨Ty.HasKind.rawSubstV h.1 ν, kindsEff_rawSubstV h.2 ν⟩
    | param n a t => exact ⟨Ty.HasKind.rawSubstV h.1 ν, kindsTel_rawSubstV h.2 (upValues ν)⟩
  theorem kindsList_rawSubstV {P K as} (h : kindsList P K as) (ν : ObservationEnv) :
      kindsList P K (substVTys ν as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.HasKind.rawSubstV h.1 ν, kindsList_rawSubstV h.2 ν⟩
  theorem kindsEff_rawSubstV {P K e} (h : kindsEff P K e) (ν : ObservationEnv) :
      kindsEff P K (Eff.rawSubstV ν e) := by
    cases e; exact kindsList_rawSubstV h ν
end

private theorem kindsList_iff {P K as} : kindsList P K as ↔ ∀ a ∈ as, Ty.HasKind P K a .value := by
  induction as with
  | nil => simp [kindsList]
  | cons a as ih => simp [kindsList, ih]

mutual
  theorem Ty.HasKind.norm {P K a k} (h : Ty.HasKind P K a k) : Ty.HasKind P K a.norm k := by
    cases k with
    | constructor n => cases a <;> simp_all [Ty.HasKind, Ty.norm]
    | value =>
      cases a <;> simp only [Ty.HasKind] at h ⊢ <;> simp only [Ty.norm, Ty.HasKind]
      all_goals first | exact h | trivial | exact Ty.HasKind.norm h | exact kindsList_norm h | skip
      case data d as => exact ⟨by simpa only [Ty.normTys_eq_map, List.length_map] using h.1, kindsList_norm h.2⟩
      case fn ns ps r e => exact ⟨by simpa only [NamesWF, Ty.normTys_eq_map, List.length_map] using h.1,
        kindsList_norm h.2.1, Ty.HasKind.norm h.2.2.1, kindsEff_norm h.2.2.2⟩
      case dependentFn t => exact Ty.kind_foldFn (kindsTel_norm h)
      case cont b t e => exact ⟨Ty.HasKind.norm h.1, Ty.HasKind.norm h.2.1, kindsEff_norm h.2.2⟩
      case map a b => exact ⟨Ty.HasKind.norm h.1, Ty.HasKind.norm h.2⟩
      case dict cl a => obtain ⟨cd,hc,ha⟩ := h; exact ⟨cd,hc,Ty.HasKind.norm ha⟩
      case tapp i as => exact ⟨by simpa only [Ty.normTys_eq_map, List.length_map] using h.1, kindsList_norm h.2⟩
      case refined a p => exact Ty.kind_refineNorm (Ty.HasKind.norm h.1) ((Ty.notContCore_norm _).mpr h.2)
  theorem kindsTel_norm {P K t} (h : kindsTel P K t) : kindsTel P K (Tel.norm t) := by
    cases t with
    | done r e => exact ⟨Ty.HasKind.norm h.1, kindsEff_norm h.2⟩
    | param n a t => exact ⟨Ty.HasKind.norm h.1, kindsTel_norm h.2⟩
  theorem kindsList_norm {P K as} (h : kindsList P K as) : kindsList P K (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.HasKind.norm h.1, kindsList_norm h.2⟩
  theorem kindsEff_norm {P K e} (h : kindsEff P K e) : kindsEff P K e.norm := by
    cases e with
    | mk a fs => exact kindsList_iff.mpr (fun t ht => kindsList_iff.mp (kindsList_norm h) t (Order.mem_sortUnique.mp ht))
end

theorem Ty.HasKind.bind_values {P K a k} (h : Ty.HasKind P K a k) (ν : Nat → Val) :
    Ty.HasKind P K (substTyValues ν a) k := by
  simp only [substTyValues, Ty.bind, valEnv, ← Ty.rawSubstV_eq_rawBind]
  exact (h.rawSubstV _).norm

theorem Ty.HasKind.shift_values {P K a t} (h : Ty.HasKind P K a t) (k c : Nat) :
    Ty.HasKind P K (a.shiftV k c) t := by
  rw [Ty.shiftV_eq_renameTy, renameTy, renEnv, ← Ty.rawSubstV_eq_rawBind]
  exact h.rawSubstV _

theorem Ty.ordinary_bind_values (a : Ty) (σ : Nat → Val) :
    (substTyValues σ a).Ordinary ↔ a.Ordinary := by
  unfold substTyValues Ty.bind valEnv
  rw [Ty.ordinary_norm, ← Ty.rawSubstV_eq_rawBind]
  exact Ty.ordinary_rawSubstV a _

/-- 呼出し先の宣言のkindと、同じ呼出し元のkind文脈で全型引数を照合する。 -/
def TypeArgsKinded (P : Program) (C : List TParam) (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∃ K : KindCtx, K.length = C.length ∧
    ∀ (i : Nat) (a : Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → a.HasKind P K k ∧ (k = .value → Ordinary a)

/-- 型構成子kindの像はctor又はtvarであり、継続型にはならない。 -/
theorem Ty.HasKind.constructor_ordinary {P K a n} (h : Ty.HasKind P K a (.constructor n)) :
    Ordinary a := by
  rcases h.constructor_shape with ⟨c, rfl, _⟩ | ⟨i, rfl, _⟩ <;> simp [Ordinary, Ty.core]

/-- valueの明示の条件とconstructorの形から、全型引数の非継続を得る。 -/
theorem TypeArgsKinded.ordinary {P C ts ks} (h : TypeArgsKinded P C ts ks) :
    ∀ a ∈ ts, Ordinary a := by
  intro a ha
  obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp ha
  have hn := h.1
  have hil : i < ks.length := by have := (List.getElem?_eq_some_iff.mp hi).1; omega
  obtain ⟨K, _, hargs⟩ := h.2
  have hk := hargs i a ks[i] hi (List.getElem?_eq_getElem hil)
  cases he : ks[i] with
  | value => exact hk.2 he
  | constructor n => rw [he] at hk; exact hk.1.constructor_ordinary

theorem TypeArgsKinded.shift {P C ts ks} (h : TypeArgsKinded P C ts ks) (k c : Nat) :
    TypeArgsKinded P C (ts.map (Ty.shiftV k c)) ks := by
  obtain ⟨hn,K,hK,h⟩ := h
  refine ⟨by simpa only [List.length_map] using hn,K,hK,?_⟩
  intro i a t ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact ⟨(h i b t hb hk).1.shift_values k c, fun hv =>
    (Ty.ordinary_shiftV _ _ _).mpr ((h i b t hb hk).2 hv)⟩

theorem TypeArgsKinded.subst {P C ts ks} (h : TypeArgsKinded P C ts ks) (ν : Nat → Val) :
    TypeArgsKinded P C (ts.map (substTyValues ν)) ks := by
  obtain ⟨hn,K,hK,h⟩ := h
  refine ⟨by simpa only [List.length_map] using hn,K,hK,?_⟩
  intro i a t ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact ⟨(h i b t hb hk).1.bind_values ν, fun hv =>
    (Ty.ordinary_bind_values _ _).mpr ((h i b t hb hk).2 hv)⟩

end Benitoite.Release.Refinement
