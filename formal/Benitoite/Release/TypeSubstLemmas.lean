import Benitoite.Release.TypeSubst

/-!
# 正規化と同時代入の接続

生の入力の順序と重複を変えても、代入後の正規形は変わらない。
型と効果の等号に使う正規形の保存を示す（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release

open Order

@[simp] theorem Ty.normTys_append (as bs : List Ty) :
    Ty.normTys (as ++ bs) = Ty.normTys as ++ Ty.normTys bs := by
  simp only [Ty.normTys_eq_map, List.map_append]

/-- 型構成子への適用は、引数の正規化と可換である。 -/
theorem TyCon.norm_rawApply (c : TyCon) (as : List Ty) :
    (c.rawApply as).norm = c.rawApply (Ty.normTys as) := by
  cases c <;> cases as <;> simp only [TyCon.rawApply, Ty.norm, Ty.normTys,
    List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
  rename_i a as
  cases as <;> rfl

/-- 型の種類が合わない場合も、入力の正規化で結果の正規形は変わらない。 -/
theorem Ty.norm_rawApplyTo (t : Ty) (as : List Ty) :
    (t.norm.rawApplyTo (Ty.normTys as)).norm = (t.rawApplyTo as).norm := by
  cases t <;> simp only [Ty.norm, Ty.rawApplyTo, Ty.norm_idem, Ty.normTys_idem, Eff.norm_idem]
  case ctor c => rw [← TyCon.norm_rawApply c as, Ty.norm_idem]

mutual
  /-- 正規化してから生の代入を行っても、結果の型の正規形は同じになる。 -/
  theorem Ty.norm_rawBind (θ : SubstEnv) (t : Ty) :
      (t.norm.rawBind θ).norm = (t.rawBind θ).norm := by
    cases t <;>
      simp only [Ty.norm, Ty.rawBind, Ty.norm_rawBind, Ty.normTys_rawBind, Eff.norm_rawBind]
    case tapp i as =>
      have h := Ty.normTys_rawBind θ as
      have h' := Ty.norm_rawApplyTo (θ.types i) (Ty.rawBindTys θ as)
      have h'' := Ty.norm_rawApplyTo (θ.types i) (Ty.rawBindTys θ (Ty.normTys as))
      rw [h] at h''
      exact h''.symm.trans h'

  theorem Ty.normTys_rawBind (θ : SubstEnv) (as : List Ty) :
      Ty.normTys (Ty.rawBindTys θ (Ty.normTys as)) = Ty.normTys (Ty.rawBindTys θ as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.normTys, Ty.rawBindTys, Ty.norm_rawBind, Ty.normTys_rawBind]

  theorem Eff.norm_rawBind (θ : SubstEnv) (e : Eff) :
      Eff.norm (Eff.rawBind θ (Eff.norm e)) = Eff.norm (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.norm, Eff.rawBind, Ty.normTys_append]
      congr 1
      apply sortUnique_append_congr (hb := rfl)
      simp only [Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.map_map]
      rw [sortUnique_map_sortUnique (cmp := tyCompare) (cmp' := tyCompare)]
      exact congrArg (sortUnique tyCompare) (by
        simpa only [Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.map_map, Function.comp_def] using Ty.normTys_rawBind θ fs)
end

/-- 正規形が等しい二つの型には、生の代入後も同じ正規形が得られる。 -/
theorem Ty.rawBind_norm_congr (θ : SubstEnv) {a b : Ty} (h : a.norm = b.norm) :
    (a.rawBind θ).norm = (b.rawBind θ).norm := by
  rw [← Ty.norm_rawBind θ a, ← Ty.norm_rawBind θ b, h]

/-- 生の Fail の型が、代入の後にどの正規形になるか。 -/
theorem Eff.memFail_rawBind (θ : SubstEnv) (e : Eff) (t : Ty) :
    Eff.memFail (Eff.rawBind θ e) t ↔
      (∃ x ∈ e.fails, (Ty.rawBind θ x).norm = t.norm) ∨
      ∃ i f x, θ.rows[i]? = some f ∧ Eff.mem e (.rho i) ∧ x ∈ f.fails ∧ x.norm = t.norm := by
  cases e with
  | mk a fs =>
    simp only [Eff.rawBind, Eff.memFail, Eff.fails, List.mem_append, or_and_right,
      exists_or, Ty.rawBindTys_eq_map, List.mem_map, Eff.mem_rowFails]
    constructor
    · rintro (⟨x, ⟨y, hy, rfl⟩, hx⟩ | ⟨x, ⟨i, f, hf, ha, hx⟩, ht⟩)
      · exact Or.inl ⟨y, hy, hx⟩
      · exact Or.inr ⟨i, f, x, hf, ha, hx, ht⟩
    · rintro (⟨x, hx, ht⟩ | ⟨i, f, x, hf, ha, hx, ht⟩)
      · exact Or.inl ⟨Ty.rawBind θ x, ⟨x, hx, rfl⟩, ht⟩
      · exact Or.inr ⟨x, ⟨i, f, hf, ha, hx⟩, ht⟩

/-- 行の置換の原子の所属。 -/
theorem Eff.mem_substAtoms (es : List Eff) (e : Eff) (a : Atom) :
    Eff.substAtoms es e.atoms a = true ↔
      (match a with
        | .name l => Eff.mem e (.name l)
        | .rho i => es.length ≤ i ∧ Eff.mem e (.rho i)) ∨
      ∃ i f, es[i]? = some f ∧ Eff.mem e (.rho i) ∧ Eff.mem f a := by
  simp only [Eff.substAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
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

theorem Eff.mem_rawBind (θ : SubstEnv) (e : Eff) (a : Atom) :
    Eff.mem (Eff.rawBind θ e) a ↔ Eff.substAtoms θ.rows e.atoms a = true := by
  cases e; rfl

/-- 行の像と型の像を固定した代入は、効果の意味上の包含を保つ。 -/
theorem Eff.bind_mono (θ : SubstEnv) {e f : Eff} (h : Eff.Sub e f) :
    Eff.Sub (Eff.bind θ e) (Eff.bind θ f) := by
  constructor
  · intro a ha
    change Eff.mem (Eff.norm (Eff.rawBind θ e)) a at ha
    change Eff.mem (Eff.norm (Eff.rawBind θ f)) a
    rw [Eff.mem_norm] at ha ⊢
    rw [Eff.mem_rawBind, Eff.mem_substAtoms] at ha ⊢
    rcases ha with ha | ⟨i, g, hg, hi, hga⟩
    · left
      cases a with
      | name _ => exact h.1 _ ha
      | rho _ => exact ⟨ha.1, h.1 _ ha.2⟩
    · exact Or.inr ⟨i, g, hg, h.1 _ hi, hga⟩
  · intro t ht
    change Eff.memFail (Eff.norm (Eff.rawBind θ e)) t at ht
    change Eff.memFail (Eff.norm (Eff.rawBind θ f)) t
    rw [Eff.norm_memFail, Eff.memFail_rawBind] at ht ⊢
    rcases ht with ⟨x, hx, hxt⟩ | ⟨i, g, x, hg, hi, hx, hxt⟩
    · obtain ⟨y, hy, hyx⟩ := h.2 x ⟨x, hx, rfl⟩
      exact Or.inl ⟨y, hy, (Ty.rawBind_norm_congr θ hyx).trans hxt⟩
    · exact Or.inr ⟨i, g, x, hg, h.1 _ hi, hx, hxt⟩

/-- 有限列による代入も、最上位の効果の Canonical を求めずに包含を保つ。 -/
theorem Eff.substAt_mono (c : Nat) (ts : List Ty) (es : List Eff) {e f : Eff} (h : Eff.Sub e f) :
    Eff.Sub (Eff.substAt c ts es e) (Eff.substAt c ts es f) := Eff.bind_mono (SubstEnv.at c ts es) h

@[simp] theorem Eff.test_norm (e : Eff) (a : Atom) : Eff.test (Eff.norm e) a = Eff.test e a := by
  cases e; rfl

/-- 行の像を正規化しても、原子の所属の置換は変わらない。 -/
theorem Eff.substAtoms_map_norm (es : List Eff) (a : Atom → Bool) :
    Eff.substAtoms (es.map Eff.norm) a = Eff.substAtoms es a := by
  funext x
  simp only [Eff.substAtoms, List.length_map, List.getElem?_map]
  congr 1
  apply congrArg (fun f => (List.range es.length).any f)
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => simp only [Option.map_some, Eff.test_norm]

/-- 行の像の正規化で、合流する Fail の型の集合は変わらない。 -/
theorem Eff.rowFails_map_norm (es : List Eff) (a : Atom → Bool) :
    sortUnique tyCompare (Ty.normTys (Eff.rowFails (es.map Eff.norm) a)) =
      sortUnique tyCompare (Ty.normTys (Eff.rowFails es a)) := by
  apply sortUnique_eq_iff_mem.mpr
  intro t
  simp only [Ty.normTys_eq_map, List.mem_map]
  constructor
  · rintro ⟨x, hx, hxt⟩
    obtain ⟨i, f, hi, ha, hxf⟩ := Eff.mem_rowFails.mp hx
    rw [List.getElem?_map] at hi
    obtain ⟨e, he, rfl⟩ := Option.map_eq_some_iff.mp hi
    have hx' : x ∈ sortUnique tyCompare (Ty.normTys e.fails) := by cases e; exact hxf
    obtain ⟨y, hy, rfl⟩ := List.mem_map.mp (by
      simpa only [Ty.normTys_eq_map] using mem_sortUnique.mp hx')
    exact ⟨y, Eff.mem_rowFails.mpr ⟨i, e, he, ha, hy⟩, (Ty.norm_idem y).symm.trans hxt⟩
  · rintro ⟨x, hx, hxt⟩
    obtain ⟨i, e, he, ha, hxe⟩ := Eff.mem_rowFails.mp hx
    refine ⟨x.norm, Eff.mem_rowFails.mpr ⟨i, Eff.norm e, ?_, ha, ?_⟩, (Ty.norm_idem x).trans hxt⟩
    · simp only [List.getElem?_map, he, Option.map_some]
    · have hx' : x.norm ∈ sortUnique tyCompare (Ty.normTys e.fails) :=
        mem_sortUnique.mpr (by rw [Ty.normTys_eq_map]; exact List.mem_map.mpr ⟨x, hxe, rfl⟩)
      cases e; exact hx'

/-- 型と行の代入の像も、正規形によって代表を選ぶ。 -/
noncomputable def SubstEnv.norm (θ : SubstEnv) : SubstEnv :=
  ⟨fun i => (θ.types i).norm, θ.rows.map Eff.norm⟩

/-- 生の適用の正規形は、頭と引数の正規形だけで決まる。 -/
theorem Ty.rawApplyTo_norm_congr {a b : Ty} {as bs : List Ty}
    (ha : a.norm = b.norm) (has : Ty.normTys as = Ty.normTys bs) :
    (a.rawApplyTo as).norm = (b.rawApplyTo bs).norm := by
  rw [← Ty.norm_rawApplyTo a as, ← Ty.norm_rawApplyTo b bs, ha, has]

mutual
  /-- 置換像を正規化しても、代入結果の正規形は変わらない。 -/
  theorem Ty.norm_rawBind_normEnv (θ : SubstEnv) (t : Ty) :
      (t.rawBind θ.norm).norm = (t.rawBind θ).norm := by
    cases t <;> simp only [Ty.rawBind, Ty.norm,
      Ty.norm_rawBind_normEnv, Ty.normTys_rawBind_normEnv, Eff.norm_rawBind_normEnv]
    case tvar i => exact Ty.norm_idem _
    case tapp i as =>
      apply Ty.rawApplyTo_norm_congr
      · exact Ty.norm_idem _
      · exact Ty.normTys_rawBind_normEnv θ as

  theorem Ty.normTys_rawBind_normEnv (θ : SubstEnv) (as : List Ty) :
      Ty.normTys (Ty.rawBindTys θ.norm as) = Ty.normTys (Ty.rawBindTys θ as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawBindTys, Ty.normTys, Ty.norm_rawBind_normEnv, Ty.normTys_rawBind_normEnv]

  theorem Eff.norm_rawBind_normEnv (θ : SubstEnv) (e : Eff) :
      Eff.norm (Eff.rawBind θ.norm e) = Eff.norm (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, Eff.norm, Ty.normTys_append]
      rw [Ty.normTys_rawBind_normEnv]
      change EffR.mk (Eff.substAtoms (θ.rows.map Eff.norm) a)
          (sortUnique tyCompare (Ty.normTys (Ty.rawBindTys θ fs) ++
            Ty.normTys (Eff.rowFails (θ.rows.map Eff.norm) a))) = _
      rw [Eff.substAtoms_map_norm]
      congr 1
      exact sortUnique_append_congr rfl (Eff.rowFails_map_norm θ.rows a)
end

/-- cutoff を越える像の移動も、型と行の像の正規化と交換できる。 -/
theorem SubstEnv.at_norm (c : Nat) (ts : List Ty) (es : List Eff) :
    SubstEnv.at c (ts.map Ty.norm) (es.map Eff.norm) = (SubstEnv.at c ts es).norm := by
  unfold SubstEnv.at SubstEnv.norm
  simp only [List.length_map]
  congr 1
  · funext i
    by_cases hi : i < c
    · simp only [hi, ↓reduceIte, Ty.norm]
    · simp only [hi, ↓reduceIte]
      by_cases hj : i - c < ts.length
      · simp only [hj, ↓reduceIte, List.getElem?_map, List.getElem?_eq_getElem hj,
          Option.map_some, Option.getD_some]
        exact (Ty.norm_rawShift c 0 (ts[i - c])).symm
      · simp only [hj, ↓reduceIte, Ty.norm]
  · simp only [List.map_map]
    apply List.map_congr_left
    intro e _
    exact (Eff.norm_rawShift c 0 e).symm

/-- 入力と型・行の置換像を先に正規化しても、代入後の型の正規形は変わらない。 -/
theorem Ty.norm_substAt (t : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    (t.rawSubstAt c ts es).norm =
      (t.norm.rawSubstAt c (ts.map Ty.norm) (es.map Eff.norm)).norm := by
  simp only [Ty.rawSubstAt, SubstEnv.at_norm]
  rw [Ty.norm_rawBind, Ty.norm_rawBind_normEnv]

/-- 効果の代入でも、内部の型と置換像の双方の正規化を吸収する。 -/
theorem Eff.norm_substAt (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.norm (Eff.rawSubstAt c ts es e) =
      Eff.norm (Eff.rawSubstAt c (ts.map Ty.norm) (es.map Eff.norm) (Eff.norm e)) := by
  simp only [Eff.rawSubstAt, SubstEnv.at_norm]
  rw [Eff.norm_rawBind, Eff.norm_rawBind_normEnv]

/-- 公開する適用は、正規化前の適用後に正規化したものに等しい。 -/
theorem Ty.applyTo_eq_raw_norm (t : Ty) (as : List Ty) : t.applyTo as = (t.rawApplyTo as).norm := by
  cases t <;> try rfl
  case ctor c => exact (TyCon.norm_rawApply c as).symm

mutual
  /-- 公開する代入の構造再帰を、一般の代入と結果の正規化へ接続する。 -/
  theorem Ty.substAt_eq_rawBind (c : Nat) (ts : List Ty) (es : List Eff) (t : Ty) :
      t.substAt c ts es = (t.rawBind (SubstEnv.at c ts es)).norm := by
    cases t <;> simp only [Ty.substAt, Ty.rawBind, Ty.norm, Ty.substAt_eq_rawBind,
      Ty.substTysAt_eq_rawBindTys, Eff.substAt, Eff.rawSubstAt]
    case tvar i =>
      simp only [SubstEnv.at]
      split
      · rfl
      · split
        · exact Ty.shift_eq_norm_rawShift _ _ _
        · rfl
    case tapp i as =>
      simp only [SubstEnv.at]
      split
      · rfl
      · split
        · rw [Ty.applyTo_eq_raw_norm, Ty.shift_eq_norm_rawShift, Ty.norm_rawApplyTo]
        · rfl

  theorem Ty.substTysAt_eq_rawBindTys (c : Nat) (ts : List Ty) (es : List Eff) (as : List Ty) :
      Ty.substTysAt c ts es as = Ty.normTys (Ty.rawBindTys (SubstEnv.at c ts es) as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.substTysAt, Ty.rawBindTys, Ty.normTys, Ty.substAt_eq_rawBind,
        Ty.substTysAt_eq_rawBindTys]
end

/-- 有限列で与えた公開する代入は、一般の代入の特例である。 -/
theorem Ty.substAt_eq_bind (c : Nat) (ts : List Ty) (es : List Eff) (t : Ty) :
    t.substAt c ts es = Ty.bind (SubstEnv.at c ts es) t := Ty.substAt_eq_rawBind c ts es t

/-- 旧型の列の構造的な条件は、所属するすべての型の条件と同じである。 -/
theorem Ty.LegacyTys.iff {as : List Ty} : Ty.LegacyTys as ↔ ∀ a ∈ as, a.Legacy := by
  induction as with
  | nil => simp [Ty.LegacyTys]
  | cons a as ih => simp [Ty.LegacyTys, ih]

/-- 型構成子に旧型だけを適用しても旧型である。 -/
theorem TyCon.rawApply_legacy (c : TyCon) (as : List Ty) (h : Ty.LegacyTys as) :
    (c.rawApply as).Legacy := by
  cases c <;> cases as <;> simp only [TyCon.rawApply, Ty.Legacy, List.headD_nil,
    List.headD_cons, List.tail_nil, List.tail_cons] at *
  all_goals first | trivial | exact h | exact h.1 | skip
  case map.cons a as =>
    cases as with
    | nil => exact ⟨h.1, trivial⟩
    | cons b bs => exact ⟨h.1, h.2.1⟩

/-- 型の種類が合わない場合も、旧型の範囲を保つ。 -/
theorem Ty.rawApplyTo_legacy (t : Ty) (as : List Ty) (ht : t.Legacy) (has : Ty.LegacyTys as) :
    (t.rawApplyTo as).Legacy := by
  cases t with
  | ctor c => exact TyCon.rawApply_legacy c as has
  | tvar i => exact has
  | _ => exact ht

mutual
  /-- 生の移動は Fail を作らない。 -/
  theorem Ty.rawShift_legacy (k c : Nat) (t : Ty) (h : t.Legacy) : (t.rawShift k c).Legacy := by
    cases t <;> simp only [Ty.Legacy] at h <;> simp only [Ty.rawShift, Ty.Legacy]
    all_goals first
      | trivial
      | exact Ty.rawShift_legacy k c _ h
      | exact Ty.rawShiftTys_legacy k c _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.rawShiftTys_legacy k c ps h.1,
      Ty.rawShift_legacy k c r h.2.1, Eff.rawShift_legacy k c e h.2.2⟩
    case cont b t e => exact ⟨Ty.rawShift_legacy k c b h.1,
      Ty.rawShift_legacy k c t h.2.1, Eff.rawShift_legacy k c e h.2.2⟩
    case map a b => exact ⟨Ty.rawShift_legacy k c a h.1, Ty.rawShift_legacy k c b h.2⟩

  theorem Ty.rawShiftTys_legacy (k c : Nat) (as : List Ty) (h : Ty.LegacyTys as) :
      Ty.LegacyTys (Ty.rawShiftTys k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawShift_legacy k c a h.1, Ty.rawShiftTys_legacy k c as h.2⟩

  theorem Eff.rawShift_legacy (k c : Nat) (e : Eff) (h : Eff.Legacy e) : Eff.Legacy (Eff.rawShift k c e) := by
    cases e with
    | mk a fs => cases h; rfl
end

/-- Fail のない行の像からは、Fail の型は合流しない。 -/
theorem Eff.rowFails_legacy (es : List Eff) (h : ∀ e ∈ es, Eff.Legacy e) (a : Atom → Bool) :
    Eff.rowFails es a = [] := by
  apply List.eq_nil_iff_forall_not_mem.mpr
  intro t ht
  obtain ⟨i, e, he, _, hte⟩ := Eff.mem_rowFails.mp ht
  have hf := h e (List.mem_of_getElem? he)
  rw [hf] at hte
  exact List.not_mem_nil hte

mutual
  /-- 旧型と旧型の像の同時代入は、すべての深さで旧型を保つ。 -/
  theorem Ty.rawBind_legacy (θ : SubstEnv) (hts : ∀ i, (θ.types i).Legacy)
      (hes : ∀ e ∈ θ.rows, Eff.Legacy e) (t : Ty) (h : t.Legacy) : (t.rawBind θ).Legacy := by
    cases t <;> simp only [Ty.Legacy] at h <;> simp only [Ty.rawBind, Ty.Legacy]
    all_goals first
      | trivial
      | exact Ty.rawBind_legacy θ hts hes _ h
      | exact Ty.rawBindTys_legacy θ hts hes _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.rawBindTys_legacy θ hts hes ps h.1,
      Ty.rawBind_legacy θ hts hes r h.2.1, Eff.rawBind_legacy θ hts hes e h.2.2⟩
    case tvar i => exact hts i
    case cont b t e => exact ⟨Ty.rawBind_legacy θ hts hes b h.1,
      Ty.rawBind_legacy θ hts hes t h.2.1, Eff.rawBind_legacy θ hts hes e h.2.2⟩
    case map a b => exact ⟨Ty.rawBind_legacy θ hts hes a h.1, Ty.rawBind_legacy θ hts hes b h.2⟩
    case tapp i as => exact Ty.rawApplyTo_legacy _ _ (hts i) (Ty.rawBindTys_legacy θ hts hes as h)

  theorem Ty.rawBindTys_legacy (θ : SubstEnv) (hts : ∀ i, (θ.types i).Legacy)
      (hes : ∀ e ∈ θ.rows, Eff.Legacy e) (as : List Ty) (h : Ty.LegacyTys as) :
      Ty.LegacyTys (Ty.rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawBind_legacy θ hts hes a h.1, Ty.rawBindTys_legacy θ hts hes as h.2⟩

  theorem Eff.rawBind_legacy (θ : SubstEnv) (_hts : ∀ i, (θ.types i).Legacy)
      (hes : ∀ e ∈ θ.rows, Eff.Legacy e) (e : Eff) (h : Eff.Legacy e) : Eff.Legacy (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      cases h
      simp only [Eff.Legacy, Eff.rawBind, Eff.fails, Ty.rawBindTys, List.nil_append, Eff.rowFails_legacy θ.rows hes]
end

/-- 旧型に限れば、公開する移動は計算できる生の移動に等しい。 -/
theorem Ty.shift_eq_raw_of_legacy (k c : Nat) (t : Ty) (h : t.Legacy) : t.shift k c = t.rawShift k c := by
  rw [Ty.shift_eq_norm_rawShift, Ty.norm_legacy _ (Ty.rawShift_legacy k c t h)]

theorem Eff.shift_eq_raw_of_legacy (k c : Nat) (e : Eff) (h : Eff.Legacy e) :
    Eff.shift k c e = Eff.rawShift k c e := Eff.norm_legacy _ (Eff.rawShift_legacy k c e h)

/-- 旧型の置換像の生の構築は、旧型の範囲に収まる。 -/
theorem SubstEnv.at_legacy (c : Nat) (ts : List Ty) (es : List Eff)
    (hts : ∀ t ∈ ts, t.Legacy) (hes : ∀ e ∈ es, Eff.Legacy e) :
    (∀ i, ((SubstEnv.at c ts es).types i).Legacy) ∧
      (∀ e ∈ (SubstEnv.at c ts es).rows, Eff.Legacy e) := by
  constructor
  · intro i
    simp only [SubstEnv.at]
    split
    · trivial
    · split
      · rename_i _ hi
        simp only [List.getElem?_eq_getElem hi, Option.getD_some]
        exact Ty.rawShift_legacy c 0 _ (hts _ (List.getElem_mem hi))
      · trivial
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    exact Eff.rawShift_legacy c 0 f (hes f hf)

/-- 旧型と旧型の像では、公開する代入が計算できる生の代入と等しい。 -/
theorem Ty.substAt_eq_raw_of_legacy (c : Nat) (ts : List Ty) (es : List Eff)
    (hts : ∀ t ∈ ts, t.Legacy) (hes : ∀ e ∈ es, Eff.Legacy e) (t : Ty) (h : t.Legacy) :
    t.substAt c ts es = t.rawSubstAt c ts es := by
  have hw := SubstEnv.at_legacy c ts es hts hes
  rw [Ty.substAt_eq_rawBind, Ty.norm_legacy _ (Ty.rawBind_legacy _ hw.1 hw.2 t h)]
  rfl

theorem Eff.substAt_eq_raw_of_legacy (c : Nat) (ts : List Ty) (es : List Eff)
    (hts : ∀ t ∈ ts, t.Legacy) (hes : ∀ e ∈ es, Eff.Legacy e) (e : Eff) (h : Eff.Legacy e) :
    Eff.substAt c ts es e = Eff.rawSubstAt c ts es e := by
  have hw := SubstEnv.at_legacy c ts es hts hes
  exact Eff.norm_legacy _ (Eff.rawBind_legacy _ hw.1 hw.2 e h)

/-- 行を置き換えないとき、Failのない効果は型代入の影響を受けない。 -/
@[simp] theorem Eff.substAt_ofAtoms (c : Nat) (ts : List Ty) (a : Atom → Bool) :
    Eff.substAt c ts [] (Eff.ofAtoms a) = Eff.ofAtoms a := by
  change Eff.norm (.mk (Eff.substAtoms [] a) []) = _
  rw [Eff.substAtoms_nil]
  rfl

end Benitoite.Release
