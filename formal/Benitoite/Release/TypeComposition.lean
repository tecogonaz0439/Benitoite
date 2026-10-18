import Benitoite.Release.TypeRows

/-!
# 一般の代入の一致と合成

有限列の外を恒等の行で補い、Fail の内部まで再帰する同時代入を扱う
（設計書 01-12「コア計算と脱糖」）。
-/

namespace Benitoite.Release

/-- 有限の置換列の外も含めた、代入後の原子の所属。 -/
theorem Eff.mem_rawBind_rowImage (θ : SubstEnv) (e : Eff) (a : Atom) :
    Eff.mem (Eff.rawBind θ e) a ↔
      (∃ l, a = .name l ∧ Eff.mem e (.name l)) ∨
      ∃ i, Eff.mem e (.rho i) ∧ Eff.mem (Eff.rowImage θ.rows i) a := by
  rw [Eff.mem_rawBind, Eff.mem_substAtoms]
  constructor
  · rintro (h | ⟨i, f, hf, hi, ha⟩)
    · cases a with
      | name l => exact Or.inl ⟨l, rfl, h⟩
      | rho i => exact Or.inr ⟨i, h.2, by simp [rowImage, List.getElem?_eq_none h.1, mem_row]⟩
    · exact Or.inr ⟨i, hi, by simpa [rowImage, hf] using ha⟩
  · rintro (⟨l, rfl, hl⟩ | ⟨i, hi, ha⟩)
    · exact Or.inl hl
    · cases hf : θ.rows[i]? with
      | none =>
        have ha : a = .rho i := by simpa [rowImage, hf, mem_row] using ha
        subst a
        exact Or.inl ⟨List.getElem?_eq_none_iff.mp hf, hi⟩
      | some f => exact Or.inr ⟨i, f, hf, hi, by simpa [rowImage, hf] using ha⟩

/-- 範囲外の恒等像は Fail 型を追加しない。 -/
theorem Eff.memFail_rawBind_rowImage (θ : SubstEnv) (e : Eff) (t : Ty) :
    Eff.memFail (Eff.rawBind θ e) t ↔
      (∃ x ∈ e.fails, (Ty.rawBind θ x).norm = t.norm) ∨
      ∃ i, Eff.mem e (.rho i) ∧ Eff.memFail (Eff.rowImage θ.rows i) t := by
  rw [Eff.memFail_rawBind]
  apply or_congr Iff.rfl
  constructor
  · rintro ⟨i, f, x, hf, hi, hx, ht⟩
    exact ⟨i, hi, by simpa only [rowImage, hf, Option.getD_some] using
      (show Eff.memFail f t from ⟨x, hx, ht⟩)⟩
  · rintro ⟨i, hi, ht⟩
    cases hf : θ.rows[i]? with
    | none => simp [rowImage, hf, Eff.row, Eff.ofAtoms, Eff.memFail, Eff.fails] at ht
    | some f =>
      obtain ⟨x, hx, hxt⟩ := (show Eff.memFail f t from by simpa [rowImage, hf] using ht)
      exact ⟨i, f, x, hf, hi, hx, hxt⟩

/-- 正規形の効果の一致を原子と Fail の意味上の所属へ分ける。 -/
theorem Eff.norm_ext {e f : Eff} (ha : ∀ a, Eff.mem e a ↔ Eff.mem f a)
    (ht : ∀ t, Eff.memFail e t ↔ Eff.memFail f t) : Eff.norm e = Eff.norm f := by
  apply Eff.eq_of_sub_of_sub (Eff.norm_idem e) (Eff.norm_idem f)
  · exact (Eff.sub_norm e f).mp ⟨fun a => (ha a).mp, fun t => (ht t).mp⟩
  · exact (Eff.sub_norm f e).mp ⟨fun a => (ha a).mpr, fun t => (ht t).mpr⟩

mutual
  /-- 型の像を保ち、再帰的に現れる行の像が一致すれば、型の代入結果も一致する。 -/
  theorem Ty.bind_congr_rows (θ φ : SubstEnv) (ht : θ.types = φ.types) (t : Ty)
      (h : t.RowsIn (fun i => Eff.rowImage θ.rows i = Eff.rowImage φ.rows i)) :
      Ty.bind θ t = Ty.bind φ t := by
    cases t <;> simp only [Ty.RowsIn] at h <;>
      simp only [Ty.bind, Ty.rawBind, Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.bind_congr_rows θ φ ht _ h)
      | exact congrArg _ (Ty.bindTys_congr_rows θ φ ht _ h)
      | skip
    case fn ns ps r e =>
      rw [show Ty.normTys (Ty.rawBindTys θ ps) = Ty.normTys (Ty.rawBindTys φ ps) from
        Ty.bindTys_congr_rows θ φ ht ps h.1,
        show (r.rawBind θ).norm = (r.rawBind φ).norm from Ty.bind_congr_rows θ φ ht r h.2.1,
        show Eff.norm (Eff.rawBind θ e) = Eff.norm (Eff.rawBind φ e) from Eff.bind_congr_rows θ φ ht e h.2.2]
    case tvar i => exact congrArg Ty.norm (congrFun ht i)
    case cont a b e =>
      rw [show (a.rawBind θ).norm = (a.rawBind φ).norm from Ty.bind_congr_rows θ φ ht a h.1,
        show (b.rawBind θ).norm = (b.rawBind φ).norm from Ty.bind_congr_rows θ φ ht b h.2.1,
        show Eff.norm (Eff.rawBind θ e) = Eff.norm (Eff.rawBind φ e) from Eff.bind_congr_rows θ φ ht e h.2.2]
    case map a b =>
      rw [show (a.rawBind θ).norm = (a.rawBind φ).norm from Ty.bind_congr_rows θ φ ht a h.1,
        show (b.rawBind θ).norm = (b.rawBind φ).norm from Ty.bind_congr_rows θ φ ht b h.2]
    case tapp i as =>
      apply Ty.rawApplyTo_norm_congr (congrArg Ty.norm (congrFun ht i))
      exact Ty.bindTys_congr_rows θ φ ht as h

  theorem Ty.bindTys_congr_rows (θ φ : SubstEnv) (ht : θ.types = φ.types) (ts : List Ty)
      (h : Ty.RowsInList (fun i => Eff.rowImage θ.rows i = Eff.rowImage φ.rows i) ts) :
      Ty.normTys (Ty.rawBindTys θ ts) = Ty.normTys (Ty.rawBindTys φ ts) := by
    cases ts with
    | nil => rfl
    | cons t ts =>
      simp only [Ty.rawBindTys, Ty.normTys]
      rw [show (t.rawBind θ).norm = (t.rawBind φ).norm from Ty.bind_congr_rows θ φ ht t h.1,
        Ty.bindTys_congr_rows θ φ ht ts h.2]

  theorem Eff.bind_congr_rows (θ φ : SubstEnv) (ht : θ.types = φ.types) (e : Eff)
      (h : Eff.RowsIn (fun i => Eff.rowImage θ.rows i = Eff.rowImage φ.rows i) e) :
      Eff.bind θ e = Eff.bind φ e := by
    cases e with
    | mk atoms fs =>
      have hfs := Ty.bindTys_congr_rows θ φ ht fs h.2
      apply Eff.norm_ext
      · intro a
        rw [Eff.mem_rawBind_rowImage, Eff.mem_rawBind_rowImage]
        apply or_congr Iff.rfl
        apply exists_congr
        intro i
        apply and_congr_right
        intro hi
        rw [h.1 i hi]
      · intro t
        rw [Eff.memFail_rawBind_rowImage, Eff.memFail_rawBind_rowImage]
        apply or_congr
        · have hm := Iff.of_eq (congrArg (fun xs => t.norm ∈ xs) hfs)
          simpa only [Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.map_map,
            Function.comp_apply, List.mem_map, Eff.fails] using hm
        · apply exists_congr
          intro i
          apply and_congr_right
          intro hi
          rw [h.1 i hi]
end

/-- 行の一致条件は Fail の型の内部に現れる行も含む。 -/
theorem Eff.substRho_congr_rows (es fs : List Eff) (e : Eff)
    (h : Eff.RowsIn (fun i => Eff.rowImage es i = Eff.rowImage fs i) e) :
    Eff.substRho es e = Eff.substRho fs e := by
  apply Eff.bind_congr_rows (SubstEnv.at 0 [] es) (SubstEnv.at 0 [] fs) rfl
  simpa only [SubstEnv.at, List.map_id, show Eff.rawShift 0 0 = id from funext (Eff.rawShift_zero 0)] using h

/-- 最上位の正規化は原子の所属を変えない。 -/
theorem Eff.mem_bind (θ : SubstEnv) (e : Eff) (a : Atom) :
    Eff.mem (Eff.bind θ e) a ↔
      (∃ l, a = .name l ∧ Eff.mem e (.name l)) ∨
      ∃ i, Eff.mem e (.rho i) ∧ Eff.mem (Eff.rowImage θ.rows i) a := by
  exact (Eff.mem_norm _ _).trans (Eff.mem_rawBind_rowImage θ e a)

/-- Fail の所属で入力を観察すれば、途中の正規化にも依存しない。 -/
theorem Eff.memFail_bind (θ : SubstEnv) (e : Eff) (t : Ty) :
    Eff.memFail (Eff.bind θ e) t ↔
      (∃ x, Eff.memFail e x ∧ Ty.bind θ x = t.norm) ∨
      ∃ i, Eff.mem e (.rho i) ∧ Eff.memFail (Eff.rowImage θ.rows i) t := by
  rw [Eff.bind, Eff.norm_memFail, Eff.memFail_rawBind_rowImage]
  apply or_congr _ Iff.rfl
  constructor
  · rintro ⟨x, hx, ht⟩
    exact ⟨x, ⟨x, hx, rfl⟩, ht⟩
  · rintro ⟨x, ⟨y, hy, hyx⟩, ht⟩
    exact ⟨y, hy, (Ty.rawBind_norm_congr θ hyx).trans ht⟩

/-- 行一つへの代入は、正規化した行の像である。 -/
theorem Eff.bind_row (θ : SubstEnv) (i : Nat) :
    Eff.bind θ (Eff.row i) = Eff.norm (Eff.rowImage θ.rows i) := by
  apply Eff.norm_ext
  · intro a
    rw [Eff.mem_rawBind_rowImage]
    simp only [Eff.mem_row, Atom.rho.injEq, reduceCtorEq, and_false, exists_false, false_or]
    exact exists_eq_left
  · intro t
    rw [Eff.memFail_rawBind_rowImage]
    simp only [Eff.mem_row, Atom.rho.injEq]
    simp only [Eff.row, Eff.ofAtoms, Eff.fails, List.not_mem_nil, false_and, exists_false, false_or]
    exact exists_eq_left

/-- 合成列の各行には、次の置換を施した像が入る。 -/
theorem Eff.rowImage_compose (θ φ : SubstEnv) (i : Nat) :
    Eff.rowImage (θ.compose φ).rows i = Eff.bind φ (Eff.rowImage θ.rows i) := by
  by_cases hi : i < max θ.rows.length φ.rows.length
  · simp [Eff.rowImage, SubstEnv.compose, List.getElem?_map, List.getElem?_range hi]
  · have he : θ.rows.length ≤ i := by omega
    have hf : φ.rows.length ≤ i := by omega
    have hc : (θ.compose φ).rows[i]? = none :=
      List.getElem?_eq_none (by simpa [SubstEnv.compose] using Nat.le_of_not_gt hi)
    rw [Eff.rowImage, hc, Option.getD_none, Eff.rowImage, List.getElem?_eq_none he,
      Option.getD_none, Eff.bind_row, Eff.rowImage, List.getElem?_eq_none hf, Option.getD_none]
    rfl

/-- 型構成子を一度適用した結果は、再適用で変わらない。 -/
theorem Ty.rawApplyTo_rawApplyTo (t : Ty) (as bs : List Ty) :
    (t.rawApplyTo as).rawApplyTo bs = t.rawApplyTo as := by
  cases t with
  | ctor c => cases c <;> rfl
  | _ => rfl

/-- 正規化前の代入も、型構成子への適用と可換である。 -/
theorem Ty.rawBind_rawApplyTo (θ : SubstEnv) (t : Ty) (as : List Ty) :
    (t.rawApplyTo as).rawBind θ = (t.rawBind θ).rawApplyTo (Ty.rawBindTys θ as) := by
  cases t with
  | ctor c =>
    cases c <;> cases as <;> simp [Ty.rawApplyTo, TyCon.rawApply, Ty.rawBind, Ty.rawBindTys]
    all_goals (rename_i a as; cases as <;> rfl)
  | tapp i bs => exact (Ty.rawApplyTo_rawApplyTo _ _ _).symm
  | _ => rfl

/-- 正規形への代入と適用の交換。 -/
theorem Ty.bind_applyTo (θ : SubstEnv) (t : Ty) (as : List Ty) :
    Ty.bind θ (t.applyTo as) = (Ty.bind θ t).applyTo (Ty.bindTys θ as) := by
  rw [Ty.applyTo_eq_raw_norm]
  unfold Ty.bind
  rw [Ty.norm_rawBind, Ty.rawBind_rawApplyTo, Ty.applyTo_eq_raw_norm]
  have hl : Ty.bindTys θ as = Ty.normTys (Ty.rawBindTys θ as) := by
    simp only [Ty.bindTys, Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.map_map]
    rfl
  rw [hl]
  exact (Ty.norm_rawApplyTo (t.rawBind θ) (Ty.rawBindTys θ as)).symm

/-- 正規化後の入力に対する代入は同じ正規形を返す。 -/
theorem Ty.bind_norm (θ : SubstEnv) (t : Ty) : Ty.bind θ t.norm = Ty.bind θ t :=
  Ty.norm_rawBind θ t

/-- Fail 型での合成が得られれば、効果の合成を所属から導ける。 -/
theorem Eff.bind_comp_of_types (θ φ : SubstEnv) (e : Eff)
    (h : ∀ x ∈ e.fails, Ty.bind φ (Ty.bind θ x) = Ty.bind (θ.compose φ) x) :
    Eff.bind φ (Eff.bind θ e) = Eff.bind (θ.compose φ) e := by
  have ht : ∀ x, Eff.memFail e x → Ty.bind φ (Ty.bind θ x) = Ty.bind (θ.compose φ) x := by
    rintro x ⟨y, hy, hyx⟩
    have hθ := Ty.rawBind_norm_congr θ hyx
    have hc := Ty.rawBind_norm_congr (θ.compose φ) hyx
    exact (congrArg (Ty.bind φ) hθ).symm.trans ((h y hy).trans hc)
  apply Eff.eq_of_sub_of_sub (e := Eff.bind φ (Eff.bind θ e)) (f := Eff.bind (θ.compose φ) e)
    (Eff.norm_idem _) (Eff.norm_idem _)
  all_goals constructor
  · intro a ha
    rw [Eff.mem_bind] at ha ⊢
    rcases ha with ⟨l, rfl, hl⟩ | ⟨j, hj, ha⟩
    · rcases (Eff.mem_bind θ e (.name l)).mp hl with ⟨l', he, hl'⟩ | ⟨i, hi, hia⟩
      · cases he; exact Or.inl ⟨l, rfl, hl'⟩
      · exact Or.inr ⟨i, hi, by rw [Eff.rowImage_compose, Eff.mem_bind]; exact Or.inl ⟨l, rfl, hia⟩⟩
    · rcases (Eff.mem_bind θ e (.rho j)).mp hj with ⟨l, he, _⟩ | ⟨i, hi, hij⟩
      · cases he
      · exact Or.inr ⟨i, hi, by rw [Eff.rowImage_compose, Eff.mem_bind]; exact Or.inr ⟨j, hij, ha⟩⟩
  · intro t ha
    rw [Eff.memFail_bind] at ha ⊢
    rcases ha with ⟨x, hx, hxt⟩ | ⟨j, hj, htj⟩
    · rcases (Eff.memFail_bind θ e x).mp hx with ⟨y, hy, hyx⟩ | ⟨i, hi, hix⟩
      · exact Or.inl ⟨y, hy, (ht y hy).symm.trans ((congrArg (Ty.bind φ) hyx).trans
          ((Ty.bind_norm φ x).trans hxt))⟩
      · exact Or.inr ⟨i, hi, by rw [Eff.rowImage_compose, Eff.memFail_bind]; exact Or.inl ⟨x, hix, hxt⟩⟩
    · rcases (Eff.mem_bind θ e (.rho j)).mp hj with ⟨l, he, _⟩ | ⟨i, hi, hij⟩
      · cases he
      · exact Or.inr ⟨i, hi, by rw [Eff.rowImage_compose, Eff.memFail_bind]; exact Or.inr ⟨j, hij, htj⟩⟩
  · intro a ha
    rw [Eff.mem_bind] at ha ⊢
    rcases ha with ⟨l, rfl, hl⟩ | ⟨i, hi, ha⟩
    · exact Or.inl ⟨l, rfl, (Eff.mem_bind θ e (.name l)).mpr (Or.inl ⟨l, rfl, hl⟩)⟩
    · rw [Eff.rowImage_compose, Eff.mem_bind] at ha
      rcases ha with ⟨l, rfl, hl⟩ | ⟨j, hij, hja⟩
      · exact Or.inl ⟨l, rfl, (Eff.mem_bind θ e (.name l)).mpr (Or.inr ⟨i, hi, hl⟩)⟩
      · exact Or.inr ⟨j, (Eff.mem_bind θ e (.rho j)).mpr (Or.inr ⟨i, hi, hij⟩), hja⟩
  · intro t ha
    rw [Eff.memFail_bind] at ha ⊢
    rcases ha with ⟨x, hx, hxt⟩ | ⟨i, hi, hit⟩
    · refine Or.inl ⟨Ty.bind θ x, ?_, ?_⟩
      · rw [Eff.memFail_bind]
        exact Or.inl ⟨x, hx, (Ty.norm_idem _).symm⟩
      · exact (ht x hx).trans hxt
    · rw [Eff.rowImage_compose, Eff.memFail_bind] at hit
      rcases hit with ⟨x, hx, hxt⟩ | ⟨j, hij, hjt⟩
      · exact Or.inl ⟨x, (Eff.memFail_bind θ e x).mpr (Or.inr ⟨i, hi, hx⟩), hxt⟩
      · exact Or.inr ⟨j, (Eff.mem_bind θ e (.rho j)).mpr (Or.inr ⟨i, hi, hij⟩), hjt⟩

mutual
  /-- 型と行の同時代入は、範囲外を含む一般の合成と一致する。 -/
  theorem Ty.bind_comp (θ φ : SubstEnv) (t : Ty) :
      Ty.bind φ (Ty.bind θ t) = Ty.bind (θ.compose φ) t := by
    unfold Ty.bind
    rw [Ty.norm_rawBind]
    cases t <;> simp only [Ty.rawBind, Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.bindTys_comp θ φ _)
      | skip
    case list a =>
      exact congrArg Ty.list (by simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a)
    case reference a =>
      exact congrArg Ty.reference (by simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a)
    case lazy a =>
      exact congrArg Ty.lazy (by simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a)
    case set a =>
      exact congrArg Ty.set (by simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a)
    case dict cl a =>
      exact congrArg (Ty.dict cl) (by simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a)
    case fn ns ps r e =>
      rw [Ty.bindTys_comp θ φ ps,
        show ((r.rawBind θ).rawBind φ).norm = (r.rawBind (θ.compose φ)).norm from by
          simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ r,
        show Eff.norm (Eff.rawBind φ (Eff.rawBind θ e)) = Eff.norm (Eff.rawBind (θ.compose φ) e) from by
          simpa only [Eff.bind, Eff.norm_rawBind] using Eff.bind_comp θ φ e]
    case tvar i => exact (Ty.norm_idem _).symm
    case cont a b e =>
      rw [show ((a.rawBind θ).rawBind φ).norm = (a.rawBind (θ.compose φ)).norm from by
          simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a,
        show ((b.rawBind θ).rawBind φ).norm = (b.rawBind (θ.compose φ)).norm from by
          simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ b,
        show Eff.norm (Eff.rawBind φ (Eff.rawBind θ e)) = Eff.norm (Eff.rawBind (θ.compose φ) e) from by
          simpa only [Eff.bind, Eff.norm_rawBind] using Eff.bind_comp θ φ e]
    case map a b =>
      rw [show ((a.rawBind θ).rawBind φ).norm = (a.rawBind (θ.compose φ)).norm from by
          simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ a,
        show ((b.rawBind θ).rawBind φ).norm = (b.rawBind (θ.compose φ)).norm from by
          simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ b]
    case tapp i as =>
      rw [Ty.rawBind_rawApplyTo]
      apply Ty.rawApplyTo_norm_congr (Ty.norm_idem _).symm
      exact Ty.bindTys_comp θ φ as

  theorem Ty.bindTys_comp (θ φ : SubstEnv) (ts : List Ty) :
      Ty.normTys (Ty.rawBindTys φ (Ty.rawBindTys θ ts)) =
        Ty.normTys (Ty.rawBindTys (θ.compose φ) ts) := by
    cases ts with
    | nil => rfl
    | cons t ts =>
      simp only [Ty.rawBindTys, Ty.normTys]
      rw [show ((t.rawBind θ).rawBind φ).norm = (t.rawBind (θ.compose φ)).norm from by
        simpa only [Ty.bind, Ty.norm_rawBind] using Ty.bind_comp θ φ t,
        Ty.bindTys_comp θ φ ts]

  theorem Eff.bind_comp (θ φ : SubstEnv) (e : Eff) :
      Eff.bind φ (Eff.bind θ e) = Eff.bind (θ.compose φ) e := by
    cases e with
    | mk a fs =>
      apply Eff.bind_comp_of_types
      have hl := Ty.bindTys_comp θ φ fs
      intro t ht
      have hm := List.map_eq_map_iff.mp (show fs.map (fun t => Ty.bind φ (Ty.bind θ t)) =
          fs.map (fun t => Ty.bind (θ.compose φ) t) from by
        simpa only [Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.map_map,
          Function.comp_def, Ty.bind, Ty.norm_rawBind] using hl)
      exact hm t ht
end

/-- 両辺が正規形なら、二種類の所属の同値から生の等号を導ける。 -/
theorem Eff.ext_canonical {e f : Eff} (he : Eff.Canonical e) (hf : Eff.Canonical f)
    (ha : ∀ a, Eff.mem e a ↔ Eff.mem f a) (ht : ∀ t, Eff.memFail e t ↔ Eff.memFail f t) : e = f :=
  Eff.eq_of_sub_of_sub he hf ⟨fun a => (ha a).mp, fun t => (ht t).mp⟩
    ⟨fun a => (ha a).mpr, fun t => (ht t).mpr⟩

/-- 一般の代入は、Fail 型の和を含めて和を保つ。 -/
theorem Eff.bind_union (θ : SubstEnv) (e f : Eff) :
    Eff.bind θ (Eff.union e f) = Eff.union (Eff.bind θ e) (Eff.bind θ f) := by
  apply Eff.ext_canonical (e := Eff.bind θ (Eff.union e f))
    (f := Eff.union (Eff.bind θ e) (Eff.bind θ f)) (Eff.norm_idem _) (Eff.norm_idem _)
  · intro a
    simp only [Eff.mem_bind, Eff.mem_union, and_or_left, or_and_right, exists_or]
    grind only
  · intro t
    simp only [Eff.memFail_bind, Eff.memFail_union, Eff.mem_union, or_and_right, exists_or]
    grind only

/-- 名前だけの効果は、型と行のどちらを置き換えても変わらない。 -/
theorem Eff.bind_ofAtoms_noRhos (θ : SubstEnv) (a : Atom → Bool) (h : ∀ i, a (.rho i) = false) :
    Eff.bind θ (Eff.ofAtoms a) = Eff.ofAtoms a := by
  apply Eff.ext
  · intro x
    rw [Eff.mem_bind]
    cases x with
    | name l => simp [Eff.mem, Eff.test, Eff.atoms, h]
    | rho i => simp [Eff.mem, Eff.test, Eff.atoms, h]
  · have hf : List.filter (fun i => a (.rho i)) (List.range θ.rows.length) = [] := by
      apply List.filter_eq_nil_iff.mpr
      simp [h]
    simp only [Eff.bind, Eff.rawBind, Eff.ofAtoms, Ty.rawBindTys, Eff.rowFails, hf,
      List.flatMap_nil, List.nil_append]
    rfl

end Benitoite.Release
