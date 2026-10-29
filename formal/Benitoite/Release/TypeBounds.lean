import Benitoite.Release.TypeRegularity
import Benitoite.Release.TypeSubstLemmas

/-!
# 正規化前の型の範囲と整形式

生の代入で列が未整列になる段階と、正規化後の型の整形式を分けて証明する。
同じ共有型上の補助述語であり、型付けの整形式を弱めるものではない
（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

open Order

mutual
  /-- 正規形の条件を除いた、型変数の範囲と契約名の条件。 -/
  def Ty.RawWF (nr n : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ as => Ty.RawWFList nr n as
    | .tapp i as => i < n ∧ Ty.RawWFList nr n as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.RawWF nr n
    | .fn ns ps r e => NamesWF ns ps ∧ Ty.RawWFList nr n ps ∧ r.RawWF nr n ∧ Eff.RawWF nr n e
    | .tvar i => i < n
    | .cont b t e => b.RawWF nr n ∧ t.RawWF nr n ∧ Eff.RawWF nr n e
    | .map a b => a.RawWF nr n ∧ b.RawWF nr n

  def Ty.RawWFList (nr n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.RawWF nr n ∧ Ty.RawWFList nr n as

  def Eff.RawWF (nr n : Nat) : Eff → Prop
    | .mk _ fs => Ty.RawWFList nr n fs
end

theorem Ty.RawWFList.iff {nr : Nat} {n : Nat} {as : List Ty} : Ty.RawWFList nr n as ↔ ∀ a ∈ as, a.RawWF nr n := by
  induction as with
  | nil => simp [Ty.RawWFList]
  | cons a as ih => simp [Ty.RawWFList, ih]

/-- 行の置換は、元の原子と行の像の原子の範囲の条件から、結果の原子の範囲の条件を得る（範囲の位置は代入で
変わらない）。 -/
theorem Eff.substAtoms_wf {nr : Nat} {es : List Eff} {a : Atom → Bool} (ha : ∀ x, a x = true → x.WF nr)
    (hes : ∀ e ∈ es, ∀ x, e.atoms x = true → x.WF nr) : ∀ x, Eff.substAtoms es a x = true → x.WF nr := by
  intro x hx
  cases x with
  | rho i => trivial
  | name l r =>
    simp only [Eff.substAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true] at hx
    rcases hx with hx | ⟨i, hi, _, hx⟩
    · exact ha _ hx
    · cases he : es[i]? with
      | none => simp [he] at hx
      | some e =>
        simp only [he] at hx
        exact hes e (List.mem_of_getElem? he) _ hx

mutual
  theorem Ty.WF.raw {nr : Nat} {n : Nat} (t : Ty) (h : Ty.WF nr n t) : t.RawWF nr n := by
    cases t <;> simp only [Ty.WF] at h <;> simp only [Ty.RawWF]
    all_goals first
      | trivial
      | exact h
      | exact Ty.WF.raw _ h
      | exact Ty.WFList.raw _ h
      | skip
    case fn ns ps r e => exact ⟨h.1, Ty.WFList.raw ps h.2.1, Ty.WF.raw r h.2.2.1, Eff.WF.raw e h.2.2.2.1⟩
    case cont b t e => exact ⟨Ty.WF.raw b h.1, Ty.WF.raw t h.2.1, Eff.WF.raw e h.2.2.1⟩
    case map a b => exact ⟨Ty.WF.raw a h.1, Ty.WF.raw b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.WFList.raw as h.2⟩

  theorem Ty.WFList.raw {nr : Nat} {n : Nat} (as : List Ty) (h : Ty.WFList nr n as) : Ty.RawWFList nr n as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.WF.raw a h.1, Ty.WFList.raw as h.2⟩

  theorem Eff.WF.raw {nr : Nat} {n : Nat} (e : Eff) (h : Eff.WF nr n e) : Eff.RawWF nr n e := by
    cases e with
    | mk a fs => exact Ty.WFList.raw fs h
end

mutual
  /-- 正規化は、生の型の範囲と契約名から正規形を含む整形式を構築する。 -/
  theorem Ty.norm_rawWF {nr : Nat} {n : Nat} (t : Ty) (h : t.RawWF nr n) : Ty.WF nr n t.norm := by
    cases t <;> simp only [Ty.RawWF] at h <;> simp only [Ty.norm, Ty.WF]
    all_goals first
      | trivial
      | exact h
      | exact Ty.norm_rawWF _ h
      | exact Ty.normTys_rawWF _ h
      | skip
    case fn ns ps r e => exact ⟨by simpa only [NamesWF, Ty.normTys_eq_map, List.length_map] using h.1,
      Ty.normTys_rawWF ps h.2.1, Ty.norm_rawWF r h.2.2.1, Eff.norm_rawWF e h.2.2.2, Eff.norm_idem e⟩
    case cont b t e => exact ⟨Ty.norm_rawWF b h.1, Ty.norm_rawWF t h.2.1,
      Eff.norm_rawWF e h.2.2, Eff.norm_idem e⟩
    case map a b => exact ⟨Ty.norm_rawWF a h.1, Ty.norm_rawWF b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.normTys_rawWF as h.2⟩

  theorem Ty.normTys_rawWF {nr : Nat} {n : Nat} (as : List Ty) (h : Ty.RawWFList nr n as) : Ty.WFList nr n (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.norm_rawWF a h.1, Ty.normTys_rawWF as h.2⟩

  theorem Eff.norm_rawWF {nr : Nat} {n : Nat} (e : Eff) (h : Eff.RawWF nr n e) : Eff.WF nr n (Eff.norm e) := by
    cases e with
    | mk a fs =>
      apply Ty.WFList.iff.mpr
      intro t ht
      exact Ty.WFList.iff.mp (Ty.normTys_rawWF fs h) t (mem_sortUnique.mp ht)
end

/-- 生の型構成子への適用も、型変数の範囲と契約名を保つ。 -/
theorem TyCon.rawApply_rawWF {nr : Nat} {n : Nat} (c : TyCon) (as : List Ty) (h : Ty.RawWFList nr n as) :
    (c.rawApply as).RawWF nr n := by
  cases c <;> cases as <;> simp only [TyCon.rawApply, Ty.RawWF, List.headD_nil,
    List.headD_cons, List.tail_nil, List.tail_cons] at *
  all_goals first | trivial | exact h | exact h.1 | skip
  case map.cons a as =>
    cases as with
    | nil => exact ⟨h.1, trivial⟩
    | cons b bs => exact ⟨h.1, h.2.1⟩

theorem Ty.rawApplyTo_rawWF {nr : Nat} {n : Nat} (t : Ty) (as : List Ty) (ht : t.RawWF nr n) (has : Ty.RawWFList nr n as) :
    (t.rawApplyTo as).RawWF nr n := by
  cases t with
  | ctor c => exact TyCon.rawApply_rawWF c as has
  | tvar i => exact ⟨ht, has⟩
  | _ => exact ht

mutual
  /-- 生の同時代入は、範囲内の型の像と行の像が満たす範囲を保つ。 -/
  theorem Ty.rawBind_rawWF {nr : Nat} {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, (θ.types i).RawWF nr n)
      (hes : ∀ e ∈ θ.rows, Eff.RawWF nr n e) (t : Ty) (h : t.RawWF nr m) : (t.rawBind θ).RawWF nr n := by
    cases t <;> simp only [Ty.RawWF] at h <;> simp only [Ty.rawBind, Ty.RawWF]
    all_goals first
      | trivial
      | exact Ty.rawBind_rawWF θ hts hes _ h
      | exact Ty.rawBindTys_rawWF θ hts hes _ h
      | skip
    case fn ns ps r e => exact ⟨by simpa only [NamesWF, Ty.rawBindTys_eq_map, List.length_map] using h.1,
      Ty.rawBindTys_rawWF θ hts hes ps h.2.1, Ty.rawBind_rawWF θ hts hes r h.2.2.1,
      Eff.rawBind_rawWF θ hts hes e h.2.2.2⟩
    case tvar i => exact hts i h
    case cont b t e => exact ⟨Ty.rawBind_rawWF θ hts hes b h.1,
      Ty.rawBind_rawWF θ hts hes t h.2.1, Eff.rawBind_rawWF θ hts hes e h.2.2⟩
    case map a b => exact ⟨Ty.rawBind_rawWF θ hts hes a h.1, Ty.rawBind_rawWF θ hts hes b h.2⟩
    case tapp i as => exact Ty.rawApplyTo_rawWF _ _ (hts i h.1) (Ty.rawBindTys_rawWF θ hts hes as h.2)

  theorem Ty.rawBindTys_rawWF {nr : Nat} {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, (θ.types i).RawWF nr n)
      (hes : ∀ e ∈ θ.rows, Eff.RawWF nr n e) (as : List Ty) (h : Ty.RawWFList nr m as) :
      Ty.RawWFList nr n (Ty.rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawBind_rawWF θ hts hes a h.1, Ty.rawBindTys_rawWF θ hts hes as h.2⟩

  theorem Eff.rawBind_rawWF {nr : Nat} {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, (θ.types i).RawWF nr n)
      (hes : ∀ e ∈ θ.rows, Eff.RawWF nr n e) (e : Eff) (h : Eff.RawWF nr m e) : Eff.RawWF nr n (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      apply Ty.RawWFList.iff.mpr
      intro t ht
      rcases List.mem_append.mp ht with ht | ht
      · exact Ty.RawWFList.iff.mp (Ty.rawBindTys_rawWF θ hts hes fs h) t ht
      · obtain ⟨i, e, he, _, hte⟩ := Eff.mem_rowFails.mp ht
        have hfe : Ty.RawWFList nr n e.fails := by cases e; exact hes _ (List.mem_of_getElem? he)
        exact Ty.RawWFList.iff.mp hfe t hte
end

/-- 変数の移動は効果の原子を変えない。 -/
@[simp] theorem Eff.rawShift_atoms (k c : Nat) (e : Eff) : (Eff.rawShift k c e).atoms = e.atoms := by
  cases e; rfl

/-- 有限列の代入の結果の原子は、元の原子と行の像の原子の範囲の条件を受け継ぐ。 -/
theorem Eff.substAt_atoms_wf {nr c : Nat} {ts : List Ty} {es : List Eff} {e : Eff}
    (he : ∀ x, e.atoms x = true → x.WF nr) (hes : ∀ f ∈ es, ∀ x, f.atoms x = true → x.WF nr) :
    ∀ x, (Eff.substAt c ts es e).atoms x = true → x.WF nr := by
  cases e with
  | mk a fs =>
    intro x hx
    change Eff.substAtoms (es.map (Eff.rawShift c 0)) a x = true at hx
    refine Eff.substAtoms_wf he (fun f hf => ?_) x hx
    obtain ⟨g, hg, rfl⟩ := List.mem_map.mp hf
    rw [Eff.rawShift_atoms]
    exact hes g hg

/-- 正規化した一般の代入は、整形式の型と整形式の置換像から整形式を得る。 -/
theorem Ty.bind_wf {nr : Nat} {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, Ty.WF nr n (θ.types i))
    (hes : ∀ e ∈ θ.rows, Eff.WF nr n e) (t : Ty) (h : Ty.WF nr m t) : Ty.WF nr n (Ty.bind θ t) := by
  exact Ty.norm_rawWF _ (Ty.rawBind_rawWF θ (fun i hi => Ty.WF.raw _ (hts i hi))
    (fun e he => Eff.WF.raw _ (hes e he)) t (Ty.WF.raw t h))

mutual
  /-- 生の変数移動は、恒等の行置換を持つ生の一般代入である。 -/
  theorem Ty.rawShift_eq_rawBind (k c : Nat) (t : Ty) : t.rawShift k c = t.rawBind (SubstEnv.shift k c) := by
    cases t <;> simp only [Ty.rawShift, Ty.rawBind, Ty.rawShift_eq_rawBind,
      Ty.rawShiftTys_eq_rawBindTys, Eff.rawShift_eq_rawBind]
    case tvar i => rfl
    case tapp i as => rfl

  theorem Ty.rawShiftTys_eq_rawBindTys (k c : Nat) (as : List Ty) :
      Ty.rawShiftTys k c as = Ty.rawBindTys (SubstEnv.shift k c) as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawShiftTys, Ty.rawBindTys, Ty.rawShift_eq_rawBind, Ty.rawShiftTys_eq_rawBindTys]

  theorem Eff.rawShift_eq_rawBind (k c : Nat) (e : Eff) :
      Eff.rawShift k c e = Eff.rawBind (SubstEnv.shift k c) e := by
    cases e with
    | mk a fs => simp only [Eff.rawShift, Eff.rawBind, SubstEnv.shift, Eff.substAtoms_nil,
      Eff.rowFails_nil, List.append_nil, Ty.rawShiftTys_eq_rawBindTys]
end

/-- 移動後の型は、移動前の範囲に移動量を加えた範囲で整形式である。 -/
theorem Ty.shift_wf {nr : Nat} {n : Nat} (k : Nat) (t : Ty) (h : Ty.WF nr n t) : Ty.WF nr (n + k) (t.shift k 0) := by
  rw [Ty.shift_eq_norm_rawShift, Ty.rawShift_eq_rawBind]
  apply Ty.bind_wf (SubstEnv.shift k 0) (hes := by simp [SubstEnv.shift]) (t := t) (h := h)
  intro i hi
  simp only [SubstEnv.shift, Nat.not_lt_zero, ↓reduceIte, Ty.WF]
  omega

/-- 有限列の代入は、閉じた型と行の像から、残った束縛の範囲で整形式を得る。 -/
theorem Ty.substAt_wf {nr : Nat} {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF nr 0 t) (hes : ∀ e ∈ es, Eff.WF nr 0 e)
    (t : Ty) (h : Ty.WF nr (c + ts.length) t) : Ty.WF nr c (t.substAt c ts es) := by
  rw [Ty.substAt_eq_bind]
  apply Ty.bind_wf (SubstEnv.at c ts es) (t := t) (h := h)
  · intro i hi
    simp only [SubstEnv.at]
    split
    · assumption
    · rename_i hc
      have hj : i - c < ts.length := by omega
      simp only [hj, ↓reduceIte, List.getElem?_eq_getElem hj, Option.getD_some]
      have ht := hts _ (List.getElem_mem hj)
      rw [Ty.rawShift_of_wf c _ ht]
      exact Ty.WF.mono (Nat.zero_le c) _ ht
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    have hw := hes f hf
    rw [Eff.rawShift_of_wf c f hw]
    exact Eff.WF.mono (Nat.zero_le c) f hw

/-- 宣言の外側での代入では、型と行の像が結果の束縛の範囲に収まればよい。 -/
theorem Ty.subst_wf {nr : Nat} {n : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF nr n t) (hes : ∀ e ∈ es, Eff.WF nr n e)
    (t : Ty) (h : Ty.WF nr ts.length t) : Ty.WF nr n (t.subst ts es) := by
  unfold Ty.subst
  rw [Ty.substAt_eq_bind]
  apply Ty.bind_wf (SubstEnv.at 0 ts es) (t := t) (h := h)
  · intro i hi
    simp only [SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hi,
      List.getElem?_eq_getElem hi, Option.getD_some, Ty.rawShift_zero]
    exact hts _ (List.getElem_mem hi)
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    simpa only [Eff.rawShift_zero] using hes f hf

/-- 効果の中の Fail 型についても、一般の代入は整形式を保つ。 -/
theorem Eff.bind_wf {nr : Nat} {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, Ty.WF nr n (θ.types i))
    (hes : ∀ e ∈ θ.rows, Eff.WF nr n e) (e : Eff) (h : Eff.WF nr m e) : Eff.WF nr n (Eff.bind θ e) := by
  exact Eff.norm_rawWF _ (Eff.rawBind_rawWF θ (fun i hi => Ty.WF.raw _ (hts i hi))
    (fun e he => Eff.WF.raw _ (hes e he)) e (Eff.WF.raw e h))

/-- 束縛の外側での型と行の同時代入は、Fail 型の整形式を保つ。 -/
theorem Eff.subst_wf {nr : Nat} {n : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF nr n t) (hes : ∀ e ∈ es, Eff.WF nr n e)
    (e : Eff) (h : Eff.WF nr ts.length e) : Eff.WF nr n (Eff.substAt 0 ts es e) := by
  apply Eff.bind_wf (SubstEnv.at 0 ts es) (e := e) (h := h)
  · intro i hi
    simp only [SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hi,
      List.getElem?_eq_getElem hi, Option.getD_some, Ty.rawShift_zero]
    exact hts _ (List.getElem_mem hi)
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    simpa only [Eff.rawShift_zero] using hes f hf

theorem Ty.substList_wf {nr : Nat} {n : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF nr n t) (hes : ∀ e ∈ es, Eff.WF nr n e)
    (as : List Ty) (h : Ty.WFList nr ts.length as) :
    Ty.WFList nr n (as.map (Ty.subst ts es)) := by
  apply Ty.WFList.iff.mpr
  rintro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact Ty.subst_wf es hts hes a (Ty.WFList.iff.mp h a ha)

/-- 有限列の代入は、閉じた型と行の像から、残った束縛の範囲で整形式を得る。 -/
theorem Eff.substAt_wf {nr : Nat} {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF nr 0 t) (hes : ∀ e ∈ es, Eff.WF nr 0 e)
    (t : Eff) (h : Eff.WF nr (c + ts.length) t) : Eff.WF nr c (Eff.substAt c ts es t) := by
  apply Eff.bind_wf (SubstEnv.at c ts es) (e := t) (h := h)
  · intro i hi
    simp only [SubstEnv.at]
    split
    · assumption
    · rename_i hc
      have hj : i - c < ts.length := by omega
      simp only [hj, ↓reduceIte, List.getElem?_eq_getElem hj, Option.getD_some]
      have ht := hts _ (List.getElem_mem hj)
      rw [Ty.rawShift_of_wf c _ ht]
      exact Ty.WF.mono (Nat.zero_le c) _ ht
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    have hw := hes f hf
    rw [Eff.rawShift_of_wf c f hw]
    exact Eff.WF.mono (Nat.zero_le c) f hw


end Benitoite.Release
