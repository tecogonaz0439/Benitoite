import Benitoite.Release.Refinement.TypeShiftKinds
import Benitoite.Release.Refinement.TypeBounds

/-! 型と行の像の kind を、束縛の下でも同じ宣言に照らして保存する。 -/
namespace Benitoite.Release.Refinement

set_option maxHeartbeats 2000000

theorem TyCon.dataArity_of_arity {P : Program} {d : DataName} {n : Nat}
    (h : TyCon.arity P (.data d) = some n) : P.DataArity d n := by
  classical
  simp only [TyCon.arity] at h
  split at h
  · rename_i he
    have hn := Option.some.inj h
    rw [← hn]
    exact Classical.choose_spec he
  · contradiction

mutual
  theorem Ty.HasKind.closed_context {P K K'} {a : Ty} {k : TyKind} {nr nv : Nat}
      (hw : a.WF nr 0 nv) (h : a.HasKind P K k) : a.HasKind P K' k := by
    cases k with
    | constructor n =>
      cases a <;> simp only [Ty.HasKind] at h ⊢ <;> try contradiction
      · exact h
    | value =>
      cases a <;> simp only [Ty.HasKind] at h ⊢ <;> simp only [Ty.WF] at hw
      all_goals first | trivial | contradiction | exact Ty.HasKind.closed_context hw h | exact kindsList_closed_context hw h | exact kindsTel_closed_context hw h | skip
      case data d as => exact ⟨h.1, kindsList_closed_context hw h.2⟩
      case fn ns ps r e => exact ⟨h.1, kindsList_closed_context hw.2.1 h.2.1,
        Ty.HasKind.closed_context hw.2.2.1 h.2.2.1, kindsEff.closed_context hw.2.2.2.1 h.2.2.2⟩
      case cont b t e => exact ⟨Ty.HasKind.closed_context hw.1 h.1,
        Ty.HasKind.closed_context hw.2.1 h.2.1, kindsEff.closed_context hw.2.2.1 h.2.2⟩
      case map a b => exact ⟨Ty.HasKind.closed_context hw.1 h.1, Ty.HasKind.closed_context hw.2 h.2⟩
      case dict cl a => obtain ⟨cd, hc, ha⟩ := h; exact ⟨cd, hc, Ty.HasKind.closed_context hw ha⟩
      case tapp i as => omega
      case refined a p => exact ⟨Ty.HasKind.closed_context hw.1 h.1, h.2⟩
  private theorem kindsTel_closed_context {P K K'} {t : Tel} {nr nv : Nat}
      (hw : t.WF nr 0 nv) (h : kindsTel P K t) : kindsTel P K' t := by
    cases t with
    | done r e => exact ⟨Ty.HasKind.closed_context hw.1 h.1, kindsEff.closed_context hw.2.1 h.2⟩
    | param n a t => exact ⟨Ty.HasKind.closed_context hw.1 h.1, kindsTel_closed_context hw.2 h.2⟩
  private theorem kindsList_closed_context {P K K' as nr nv}
      (hw : Ty.WFList nr 0 nv as) (h : kindsList P K as) : kindsList P K' as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.HasKind.closed_context hw.1 h.1, kindsList_closed_context hw.2 h.2⟩
  theorem kindsEff.closed_context {P K K'} {e : Eff} {nr nv : Nat}
      (hw : e.WF nr 0 nv) (h : kindsEff P K e) : kindsEff P K' e := by
    cases e; exact kindsList_closed_context hw h
end

private theorem kindsList_iff {P K as} : kindsList P K as ↔ ∀ a ∈ as, a.HasKind P K .value := by
  induction as with
  | nil => simp [kindsList]
  | cons a as ih => simp [kindsList, ih]

private theorem kindsList_append {P K as bs} (ha : kindsList P K as) (hb : kindsList P K bs) :
    kindsList P K (as ++ bs) := kindsList_iff.mpr (by
  intro a h; rcases List.mem_append.mp h with h | h
  · exact kindsList_iff.mp ha a h
  · exact kindsList_iff.mp hb a h)

private theorem rowFails_kinded {P K es a} (h : ∀ e ∈ es, kindsEff P K e) :
    kindsList P K (rowFails es a) := by
  apply kindsList_iff.mpr
  intro t ht
  obtain ⟨i, hi, ht⟩ := List.mem_flatMap.mp ht
  cases he : es[i]? with
  | none => simp [he] at ht
  | some e =>
    cases e with
    | mk atoms fs => exact kindsList_iff.mp (h _ (List.mem_of_getElem? he)) t (by simpa [he, Eff.fails] using ht)

private theorem kindImages_up {P K L} {θ : SubstEnv} (h : TypeImagesKinded P K L θ.types) :
    TypeImagesKinded P K L θ.up.types := by
  intro i k hi
  exact ⟨(h i k hi).1.shift_values 1 0, fun he => (Ty.ordinary_shiftV _ _ _).mpr ((h i k hi).2 he)⟩

private theorem rowKinds_up {P K} {θ : SubstEnv} (h : ∀ e ∈ θ.rows, kindsEff P K e) :
    ∀ e ∈ θ.up.rows, kindsEff P K e := by
  intro e he
  obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
  exact (kindsEff_shiftV_iff f 1 0).mpr (h f hf)

mutual
  private theorem Ty.HasKind.rawBind {P K L} {a : Ty} {k : TyKind} {θ : SubstEnv} (h : a.HasKind P K k)
      (hi : TypeImagesKinded P K L θ.types)
      (hr : ∀ e ∈ θ.rows, kindsEff P L e) (ho : ∀ i, Ordinary (θ.types i)) :
      (a.rawBind θ).HasKind P L k := by
    cases k with
    | constructor n =>
      cases a <;> simp only [Ty.HasKind, Ty.rawBind] at h ⊢
      all_goals first | contradiction | exact h | exact (hi _ _ h).1
    | value =>
      cases a <;> simp only [Ty.HasKind] at h ⊢ <;> simp only [Ty.rawBind, Ty.HasKind]
      all_goals first | trivial | contradiction | exact Ty.HasKind.rawBind h hi hr ho | exact kindsList_rawBind h hi hr ho | exact kindsTel_rawBind h hi hr ho | skip
      case data d as => exact ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1, kindsList_rawBind h.2 hi hr ho⟩
      case fn ns ps r e =>
        exact ⟨by simpa only [NamesWF, rawBindTys_eq_map, List.length_map] using h.1,
          kindsList_rawBind h.2.1 hi hr ho, Ty.HasKind.rawBind h.2.2.1 hi hr ho, kindsEff_rawBind h.2.2.2 hi hr ho⟩
      case tvar i => exact (hi i _ h).1
      case cont b t e => exact ⟨Ty.HasKind.rawBind h.1 hi hr ho, Ty.HasKind.rawBind h.2.1 hi hr ho, kindsEff_rawBind h.2.2 hi hr ho⟩
      case map a b => exact ⟨Ty.HasKind.rawBind h.1 hi hr ho, Ty.HasKind.rawBind h.2 hi hr ho⟩
      case dict cl a => obtain ⟨cd, hc, ha⟩ := h; exact ⟨cd, hc, Ty.HasKind.rawBind ha hi hr ho⟩
      case tapp i as =>
        exact rawApply_valueKind (hi i _ h.1).1
          (by simp only [rawBindTys_eq_map, List.length_map]) (kindsList_rawBind h.2 hi hr ho)
      case refined a p => exact ⟨Ty.HasKind.rawBind h.1 hi hr ho, Ty.ordinary_rawBind h.2 θ ho⟩
  private theorem kindsTel_rawBind {P K L t} {θ : SubstEnv} (h : kindsTel P K t)
      (hi : TypeImagesKinded P K L θ.types)
      (hr : ∀ e ∈ θ.rows, kindsEff P L e) (ho : ∀ i, Ordinary (θ.types i)) :
      kindsTel P L (Tel.rawBind θ t) := by
    cases t with
    | done r e => exact ⟨Ty.HasKind.rawBind h.1 hi hr ho, kindsEff_rawBind h.2 hi hr ho⟩
    | param n a t => exact ⟨Ty.HasKind.rawBind h.1 hi hr ho,
        kindsTel_rawBind h.2 (kindImages_up hi) (rowKinds_up hr) (fun i => (Ty.ordinary_shiftV _ _ _).mpr (ho i))⟩
  private theorem kindsList_rawBind {P K L as} {θ : SubstEnv} (h : kindsList P K as)
      (hi : TypeImagesKinded P K L θ.types)
      (hr : ∀ e ∈ θ.rows, kindsEff P L e) (ho : ∀ i, Ordinary (θ.types i)) :
      kindsList P L (rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.HasKind.rawBind h.1 hi hr ho, kindsList_rawBind h.2 hi hr ho⟩
  private theorem kindsEff_rawBind {P K L e} {θ : SubstEnv} (h : kindsEff P K e)
      (hi : TypeImagesKinded P K L θ.types)
      (hr : ∀ e ∈ θ.rows, kindsEff P L e) (ho : ∀ i, Ordinary (θ.types i)) :
      kindsEff P L (Eff.rawBind θ e) := by
    cases e
    exact kindsList_append (kindsList_rawBind h hi hr ho) (rowFails_kinded hr)
end

theorem TypeArgsKinded.typeEnvAt {P C0 C1 ts es}
    (h : TypeArgsKinded P [] ts (TypeCtx.kinds C0)) :
    TypeImagesKinded P (TypeCtx.kinds (C1 ++ C0)) (TypeCtx.kinds C1)
      (Refinement.typeEnvAt C1.length ts es).types := by
  intro i k hi
  have hn : ts.length = C0.length := by simpa [TypeCtx.kinds] using h.1
  by_cases hlt : i < C1.length
  · have hk : (TypeCtx.kinds C1)[i]? = some k := by
      simpa only [TypeCtx.kinds, List.map_append, List.getElem?_append_left
        (show i < (List.map TParamDecl.kind C1).length by simpa using hlt)] using hi
    simp only [Refinement.typeEnvAt, hlt, ↓reduceIte]
    refine ⟨?_, ?_⟩
    · cases k <;> exact hk
    · intro _; simp [Ordinary, Ty.core]
  · have hk : (TypeCtx.kinds C0)[i-C1.length]? = some k := by
      simpa only [TypeCtx.kinds, List.map_append,
        List.getElem?_append_right (show (List.map TParamDecl.kind C1).length ≤ i by simpa using Nat.le_of_not_gt hlt), List.length_map] using hi
    have hb : i-C1.length < ts.length := by
      have := (List.getElem?_eq_some_iff.mp hk).1
      simpa [TypeCtx.kinds, hn] using this
    have ht := h.2 (i-C1.length) ts[i-C1.length] k (List.getElem?_eq_getElem hb) hk
    simp only [Refinement.typeEnvAt, hlt, ↓reduceIte, hb, List.getElem?_eq_getElem hb, Option.getD_some]
    refine ⟨?_, fun he => shiftTypes_ordinary (ht.2 he) _ _⟩
    rw [← Ty.rawRenameTypes_shift]
    exact ht.1.renameTypes (by intro i k hi; simp [TypeCtx.kinds] at hi)

private theorem typeEnvAt_rows_kinded {P C1 ts es} (h : ∀ e ∈ es, kindsEff P [] e) :
    ∀ e ∈ (Refinement.typeEnvAt C1.length ts es).rows, kindsEff P (TypeCtx.kinds C1) e := by
  intro e he
  obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
  rw [← rawRenameRowsTypes_shift]
  exact kindsEff_renameTypes (h f hf) (by intro i k hi; simp at hi)

theorem Ty.HasKind.substAt {P C0 C1 a k ts es}
    (h : Ty.HasKind P (TypeCtx.kinds (C1 ++ C0)) a k)
    (ht : TypeArgsKinded P [] ts (TypeCtx.kinds C0))
    (he : ∀ e ∈ es, kindsEff P [] e) :
    (a.substAt C1.length ts es).HasKind P (TypeCtx.kinds C1) k :=
  (h.rawBind (ht.typeEnvAt) (typeEnvAt_rows_kinded he)
    (typeEnvAt_ordinary _ _ _ ht.ordinary)).norm

theorem Tel.kinded_substAt {P C0 C1 t ts es}
    (h : kindsTel P (TypeCtx.kinds (C1 ++ C0)) t)
    (ht : TypeArgsKinded P [] ts (TypeCtx.kinds C0))
    (he : ∀ e ∈ es, kindsEff P [] e) :
    kindsTel P (TypeCtx.kinds C1) (t.substAt C1.length ts es) :=
  kindsTel_norm (kindsTel_rawBind h (ht.typeEnvAt) (typeEnvAt_rows_kinded he)
    (typeEnvAt_ordinary _ _ _ ht.ordinary))

theorem TypeArgsKinded.substAt {P C0 C1 as ks ts es}
    (h : TypeArgsKinded P (C1 ++ C0) as ks)
    (ht : TypeArgsKinded P [] ts (TypeCtx.kinds C0))
    (he : ∀ e ∈ es, kindsEff P [] e) :
    TypeArgsKinded P C1 (as.map (Ty.substAt C1.length ts es)) ks := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a k ha hk
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact ⟨(h.2 i b k hb hk).1.substAt ht he,
    fun hv => Ty.ordinary_bind ((h.2 i b k hb hk).2 hv) _ (typeEnvAt_ordinary _ _ _ ht.ordinary)⟩

end Benitoite.Release.Refinement
