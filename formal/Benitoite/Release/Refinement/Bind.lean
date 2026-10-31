import Benitoite.Release.Refinement.RawBindingShift

/-!
# 同時置換と正規化

入力の子だけを再帰的に置換し、篩や外側の値参照を持つ像をそのまま挿入する。
-/
namespace Benitoite.Release.Refinement
open Order

@[simp] theorem Ty.normTys_append (as bs : List Ty) :
    Ty.normTys (as ++ bs) = Ty.normTys as ++ Ty.normTys bs := by
  simp only [Ty.normTys_eq_map, List.map_append]

/-- 適用の頭を変えず、型引数だけを正規化する交換。 -/
theorem rawApply_norm_args (t : Ty) (as : List Ty) :
    (rawApply t (Ty.normTys as)).norm = (rawApply t as).norm := by
  cases t <;> try rfl
  case refined a p => simp only [rawApply, Ty.norm, rawApply_norm_args a as]
  case tvar i => simp only [rawApply, Ty.norm, Ty.normTys_idem]
  case ctor c =>
    cases c <;> cases as <;> simp only [rawApply, Ty.norm, Ty.normTys, Ty.normTys_idem,
      List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons, Ty.norm_idem]
    rename_i a as
    cases as <;> simp [Ty.norm, Ty.normTys, Ty.norm_idem]

theorem rawApply_packRefinements (a : Ty) (ps : List Pred) (as : List Ty) :
    rawApply (Ty.packRefinements a ps) as = Ty.packRefinements (rawApply a as) ps := by
  cases ps <;> rfl

theorem rawApply_core (a : Ty) (as : List Ty) :
    (rawApply a as).core = rawApply a.core as := by
  cases a <;> try rfl
  case refined a p => exact rawApply_core a as
  case ctor c => cases c <;> rfl

theorem rawApply_predicates (a : Ty) (as : List Ty) :
    (rawApply a as).refinementPredicates = a.refinementPredicates := by
  cases a <;> try rfl
  case refined a p => simp only [rawApply, Ty.refinementPredicates, rawApply_predicates]
  case ctor c => cases c <;> rfl

theorem rawApply_refineNorm_norm (a : Ty) (p : Pred) (as : List Ty) :
    (rawApply (a.refineNorm p) as).norm = (rawApply a as).norm.refineNorm p := by
  unfold Ty.refineNorm
  rw [rawApply_packRefinements, Ty.norm_packRefinements]
  · rw [Ty.core_norm, rawApply_core, Ty.predicates_norm, rawApply_predicates]
  · rw [rawApply_core, Ty.core_idem]
  · intro q hq
    rcases List.mem_append.mp hq with hq | hq
    · exact Ty.refinementPredicates_atoms a q hq
    · exact Pred.conjuncts_atoms p q hq

theorem rawApply_foldFn (t : Tel) (as : List Ty) : rawApply (Ty.foldFn t) as = Ty.foldFn t := by
  unfold Ty.foldFn
  split <;> rfl

/-- 篩の下への適用を含む、頭と引数の正規化の交換。 -/
theorem rawApply_norm (t : Ty) (as : List Ty) :
    (rawApply t.norm (Ty.normTys as)).norm = (rawApply t as).norm := by
  cases t <;> first | exact rawApply_norm_args _ _ | exact Ty.norm_idem _ | skip
  case refined a p =>
    simp only [Ty.norm, rawApply, rawApply_refineNorm_norm, rawApply_norm a as]
  case dependentFn t =>
    change (rawApply (Ty.foldFn (Tel.norm t)) (Ty.normTys as)).norm = Ty.foldFn (Tel.norm t)
    rw [rawApply_foldFn, Ty.norm_foldFn, Tel.norm_idem]

theorem rawApply_norm_args_congr (t : Ty) {as bs : List Ty}
    (h : Ty.normTys as = Ty.normTys bs) :
    (rawApply t as).norm = (rawApply t bs).norm := by
  rw [←rawApply_norm_args, ←rawApply_norm_args t bs, h]

noncomputable def FnView.rawBind (f : FnView) (θ : SubstEnv) : FnView :=
  ⟨f.names, rawBindTys θ f.params, f.result.rawBind θ, Eff.rawBind θ f.effect,
    ⟨by simpa only [rawBindTys_eq_map, List.length_map] using f.names_wf.1, f.names_wf.2⟩⟩

theorem FnView.toTel_rawBind (f : FnView) (θ : SubstEnv) :
    (f.rawBind θ).toTel = Tel.rawBind θ f.toTel :=
  (Tel.rawBind_toTel _ _ _ _ _).symm

theorem Ty.rawBind_foldFn_norm (t : Tel) (θ : SubstEnv) :
    (Ty.rawBind θ (Ty.foldFn t)).norm = Ty.foldFn (Tel.norm (Tel.rawBind θ t)) := by
  classical
  by_cases h : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := h
    rw [Ty.foldFn_toTel, ←FnView.toTel_rawBind, ←FnView.norm_toTel, Ty.foldFn_toTel]
    rfl
  · rw [Ty.foldFn_no_view h]
    rfl

private theorem rawBind_refineNorm_core (θ : SubstEnv) (a : Ty) (p : Pred)
    (hc : a.core = a) (hz : a.refinementPredicates = []) :
    (Ty.rawBind θ (Ty.refineNorm a p)).norm =
      Ty.refineNorm (a.rawBind θ).norm (predBind (upValues θ.values) p) := by
  unfold Ty.refineNorm
  rw [hc, hz, List.nil_append]
  cases hp : p.conjuncts with
  | nil =>
    change (a.rawBind θ).norm = Ty.packRefinements (a.rawBind θ).norm.core
      ((a.rawBind θ).norm.refinementPredicates ++ (predBind (upValues θ.values) p).conjuncts)
    rw [Pred.conjuncts_bind, hp, List.map_nil, List.append_nil]
    exact (Ty.pack_parts_norm _).symm
  | cons q qs =>
    have hps : ∀ r ∈ q :: qs, r.ConjAtom := by rw [←hp]; exact Pred.conjuncts_atoms p
    simp only [Ty.packRefinements, Ty.rawBind, Ty.norm]
    unfold Ty.refineNorm
    rw [Pred.conjuncts_bind, Pred.conjuncts_ofConjuncts hps, Pred.conjuncts_bind, hp]
    rfl

theorem Ty.rawBind_refineNorm_norm (a : Ty) (p : Pred) (θ : SubstEnv) :
    (Ty.rawBind θ (Ty.refineNorm a p)).norm =
      Ty.refineNorm (a.rawBind θ).norm (predBind (upValues θ.values) p) := by
  cases a with
  | refined a q =>
    rw [Ty.refineNorm_refined, Ty.rawBind_refineNorm_norm]
    simp only [Ty.rawBind, Ty.norm, predBind]
    exact (Ty.refineNorm_assoc _ _ _).symm
  | _ => exact rawBind_refineNorm_core θ _ p rfl rfl

mutual
  /-- 正規化してから生の代入を行っても、結果の型の正規形は同じになる。 -/
  theorem Ty.norm_rawBind (θ : SubstEnv) (t : Ty) :
      (t.norm.rawBind θ).norm = (t.rawBind θ).norm := by
    cases t <;>
      simp only [Ty.norm, Ty.rawBind, Ty.norm_rawBind, Ty.normTys_rawBind, Eff.norm_rawBind, Tel.norm_rawBind, Ty.rawBind_refineNorm_norm, Ty.rawBind_foldFn_norm]
    case tapp i as =>
      exact rawApply_norm_args_congr _ (Ty.normTys_rawBind θ as)


  theorem Tel.norm_rawBind (θ : SubstEnv) (t : Tel) :
      Tel.norm (Tel.rawBind θ (Tel.norm t)) = Tel.norm (Tel.rawBind θ t) := by
    cases t <;> simp only [Tel.norm, Tel.rawBind, Ty.norm_rawBind, Eff.norm_rawBind, Tel.norm_rawBind]
  theorem Ty.normTys_rawBind (θ : SubstEnv) (as : List Ty) :
      Ty.normTys (rawBindTys θ (Ty.normTys as)) = Ty.normTys (rawBindTys θ as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.normTys, rawBindTys, Ty.norm_rawBind, Ty.normTys_rawBind]

  theorem Eff.norm_rawBind (θ : SubstEnv) (e : Eff) :
      Eff.norm (Eff.rawBind θ (Eff.norm e)) = Eff.norm (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.norm, Eff.rawBind, Ty.normTys_append]
      congr 1
      apply sortUnique_append_congr (hb := rfl)
      simp only [Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map]
      rw [sortUnique_map_sortUnique (cmp := tyCompare) (cmp' := tyCompare)]
      exact congrArg (sortUnique tyCompare) (by
        simpa only [Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map, Function.comp_def] using Ty.normTys_rawBind θ fs)
end

/-- 正規形が等しい二つの型には、生の代入後も同じ正規形が得られる。 -/
theorem Ty.rawBind_norm_congr (θ : SubstEnv) {a b : Ty} (h : a.norm = b.norm) :
    (a.rawBind θ).norm = (b.rawBind θ).norm := by
  rw [← Ty.norm_rawBind θ a, ← Ty.norm_rawBind θ b, h]


/-- 生の行の像の連結の所属を、元の行の所属と選んだ像で特徴付ける。 -/
theorem Eff.mem_rowFails {es : List Eff} {a : Atom → Bool} {t : Ty} :
    t ∈ rowFails es a ↔ ∃ i e, es[i]? = some e ∧ a (.rho i) = true ∧ t ∈ e.fails := by
  simp only [rowFails, List.mem_flatMap, List.mem_filter, List.mem_range]
  constructor
  · rintro ⟨i, ⟨hi, ha⟩, ht⟩
    refine ⟨i, es[i], List.getElem?_eq_getElem hi, ha, ?_⟩
    simpa only [List.getElem?_eq_getElem hi] using ht
  · rintro ⟨i, e, he, ha, ht⟩
    exact ⟨i, ⟨(List.getElem?_eq_some_iff.mp he).1, ha⟩, by simpa only [he] using ht⟩
/-- 生の Fail の型が、代入の後にどの正規形になるか。 -/
theorem Eff.memFail_rawBind (θ : SubstEnv) (e : Eff) (t : Ty) :
    Eff.memFail (Eff.rawBind θ e) t ↔
      (∃ x ∈ e.fails, (Ty.rawBind θ x).norm = t.norm) ∨
      ∃ i f x, θ.rows[i]? = some f ∧ Eff.mem e (.rho i) ∧ x ∈ f.fails ∧ x.norm = t.norm := by
  cases e with
  | mk a fs =>
    simp only [Eff.rawBind, Eff.memFail, Eff.fails, List.mem_append, or_and_right,
      exists_or, rawBindTys_eq_map, List.mem_map, Eff.mem_rowFails]
    constructor
    · rintro (⟨x, ⟨y, hy, rfl⟩, hx⟩ | ⟨x, ⟨i, f, hf, ha, hx⟩, ht⟩)
      · exact Or.inl ⟨y, hy, hx⟩
      · exact Or.inr ⟨i, f, x, hf, ha, hx, ht⟩
    · rintro (⟨x, hx, ht⟩ | ⟨i, f, x, hf, ha, hx, ht⟩)
      · exact Or.inl ⟨Ty.rawBind θ x, ⟨x, hx, rfl⟩, ht⟩
      · exact Or.inr ⟨x, ⟨i, f, hf, ha, hx⟩, ht⟩

/-- 行の置換の原子の所属。 -/
theorem Eff.mem_substAtoms (es : List Eff) (e : Eff) (a : Atom) :
    substAtoms es e.atoms a = true ↔
      (match a with
        | .name l r => Eff.mem e (.name l r)
        | .rho i => es.length ≤ i ∧ Eff.mem e (.rho i)) ∨
      ∃ i f, es[i]? = some f ∧ Eff.mem e (.rho i) ∧ Eff.mem f a := by
  simp only [substAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
  apply or_congr
  · cases a with
    | name _ => rfl
    | rho i =>
      by_cases hi : i < es.length
      · simp only [hi, ↓reduceIte, Bool.false_eq_true, false_iff, not_and]
        intro h; omega
      · simp only [hi, ↓reduceIte]
        constructor
        · intro h; exact ⟨by omega, h⟩
        · intro h; exact h.2
  · constructor
    · rintro ⟨i, hi, h1, h2⟩
      refine ⟨i, es[i], by simp [hi], h1, ?_⟩
      simpa [List.getElem?_eq_getElem hi] using h2
    · rintro ⟨i, f, hf, h1, h2⟩
      have hi : i < es.length := (List.getElem?_eq_some_iff.mp hf).1
      refine ⟨i, hi, h1, ?_⟩
      simp [List.getElem?_eq_getElem hi] at hf ⊢
      rw [hf]; exact h2


mutual
  theorem Ty.rawBind_id (a : Ty) : a.rawBind (renEnv id) = a := by
    cases a <;> simp only [Ty.rawBind, renEnv_types, renEnv_ranges, renEnv_values, id_eq, rawApply, Ty.rawBind_id, rawBindTys_id,
      Eff.rawBind_id, RangeIx.inst_nil, upValues_id, predBind_id, Tel.rawBind_id]
  theorem Tel.rawBind_id (t : Tel) : Tel.rawBind (renEnv id) t = t := by
    cases t <;> simp only [Tel.rawBind, Ty.rawBind_id, Eff.rawBind_id, Tel.rawBind_id, renEnv_up_id]
  theorem rawBindTys_id (as : List Ty) : rawBindTys (renEnv id) as = as := by
    cases as <;> simp only [rawBindTys, Ty.rawBind_id, rawBindTys_id]
  theorem Eff.rawBind_id (e : Eff) : Eff.rawBind (renEnv id) e = e := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, renEnv_ranges, renEnv_rows, instAtoms_nil, substAtoms_nil,
        rawBindTys_id, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil]

end

end Benitoite.Release.Refinement
