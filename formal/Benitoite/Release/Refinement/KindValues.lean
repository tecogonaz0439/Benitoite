import Benitoite.Release.Refinement.DeclaredTransport

/-!
# 値注釈の移送による kind の保存

型の引数数と宣言したkindは、篩の述語や値の番号を読まない。
-/
namespace Benitoite.Release.Refinement

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
      case dependentFn t => exact kindsTel_norm h
      case cont b t e => exact ⟨Ty.HasKind.norm h.1, Ty.HasKind.norm h.2.1, kindsEff_norm h.2.2⟩
      case map a b => exact ⟨Ty.HasKind.norm h.1, Ty.HasKind.norm h.2⟩
      case dict cl a => obtain ⟨cd,hc,ha⟩ := h; exact ⟨cd,hc,Ty.HasKind.norm ha⟩
      case tapp i as => exact ⟨by simpa only [Ty.normTys_eq_map, List.length_map] using h.1, kindsList_norm h.2⟩
      case refined a p => exact ⟨Ty.HasKind.norm h.1, (Ty.notContCore_norm _).mpr h.2⟩
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

/-- 呼出し先の宣言のkindと、同じ呼出し元のkind文脈で全型引数を照合する。 -/
def TypeArgsKinded (P : Program) (C : List TParam) (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∃ K : KindCtx, K.length = C.length ∧
    ∀ (i : Nat) (a : Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → a.HasKind P K k

theorem TypeArgsKinded.shift {P C ts ks} (h : TypeArgsKinded P C ts ks) (k c : Nat) :
    TypeArgsKinded P C (ts.map (Ty.shiftV k c)) ks := by
  obtain ⟨hn,K,hK,h⟩ := h
  refine ⟨by simpa only [List.length_map] using hn,K,hK,?_⟩
  intro i a t ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact (h i b t hb hk).shift_values k c

theorem TypeArgsKinded.subst {P C ts ks} (h : TypeArgsKinded P C ts ks) (ν : Nat → Val) :
    TypeArgsKinded P C (ts.map (substTyValues ν)) ks := by
  obtain ⟨hn,K,hK,h⟩ := h
  refine ⟨by simpa only [List.length_map] using hn,K,hK,?_⟩
  intro i a t ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact (h i b t hb hk).bind_values ν

end Benitoite.Release.Refinement
