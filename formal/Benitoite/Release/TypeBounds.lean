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
  def Ty.RawWF (n : Nat) : Ty → Prop
    | .base _ | .opaque _ | .bytes | .ctor _ => True
    | .data _ as => Ty.RawWFList n as
    | .tapp i as => i < n ∧ Ty.RawWFList n as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.RawWF n
    | .fn ns ps r e => NamesWF ns ps ∧ Ty.RawWFList n ps ∧ r.RawWF n ∧ Eff.RawWF n e
    | .tvar i => i < n
    | .cont b t e => b.RawWF n ∧ t.RawWF n ∧ Eff.RawWF n e
    | .map a b => a.RawWF n ∧ b.RawWF n

  def Ty.RawWFList (n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.RawWF n ∧ Ty.RawWFList n as

  def Eff.RawWF (n : Nat) : Eff → Prop
    | .mk _ fs => Ty.RawWFList n fs
end

theorem Ty.RawWFList.iff {n : Nat} {as : List Ty} : Ty.RawWFList n as ↔ ∀ a ∈ as, a.RawWF n := by
  induction as with
  | nil => simp [Ty.RawWFList]
  | cons a as ih => simp [Ty.RawWFList, ih]

mutual
  theorem Ty.WF.raw {n : Nat} (t : Ty) (h : Ty.WF n t) : t.RawWF n := by
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

  theorem Ty.WFList.raw {n : Nat} (as : List Ty) (h : Ty.WFList n as) : Ty.RawWFList n as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.WF.raw a h.1, Ty.WFList.raw as h.2⟩

  theorem Eff.WF.raw {n : Nat} (e : Eff) (h : Eff.WF n e) : Eff.RawWF n e := by
    cases e with
    | mk a fs => exact Ty.WFList.raw fs h
end

mutual
  /-- 正規化は、生の型の範囲と契約名から正規形を含む整形式を構築する。 -/
  theorem Ty.norm_rawWF {n : Nat} (t : Ty) (h : t.RawWF n) : Ty.WF n t.norm := by
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

  theorem Ty.normTys_rawWF {n : Nat} (as : List Ty) (h : Ty.RawWFList n as) : Ty.WFList n (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.norm_rawWF a h.1, Ty.normTys_rawWF as h.2⟩

  theorem Eff.norm_rawWF {n : Nat} (e : Eff) (h : Eff.RawWF n e) : Eff.WF n (Eff.norm e) := by
    cases e with
    | mk a fs =>
      apply Ty.WFList.iff.mpr
      intro t ht
      exact Ty.WFList.iff.mp (Ty.normTys_rawWF fs h) t (mem_sortUnique.mp ht)
end

/-- 生の型構成子への適用も、型変数の範囲と契約名を保つ。 -/
theorem TyCon.rawApply_rawWF {n : Nat} (c : TyCon) (as : List Ty) (h : Ty.RawWFList n as) :
    (c.rawApply as).RawWF n := by
  cases c <;> cases as <;> simp only [TyCon.rawApply, Ty.RawWF, List.headD_nil,
    List.headD_cons, List.tail_nil, List.tail_cons] at *
  all_goals first | trivial | exact h | exact h.1 | skip
  case map.cons a as =>
    cases as with
    | nil => exact ⟨h.1, trivial⟩
    | cons b bs => exact ⟨h.1, h.2.1⟩

theorem Ty.rawApplyTo_rawWF {n : Nat} (t : Ty) (as : List Ty) (ht : t.RawWF n) (has : Ty.RawWFList n as) :
    (t.rawApplyTo as).RawWF n := by
  cases t with
  | ctor c => exact TyCon.rawApply_rawWF c as has
  | tvar i => exact ⟨ht, has⟩
  | _ => exact ht

mutual
  /-- 生の同時代入は、範囲内の型の像と行の像が満たす範囲を保つ。 -/
  theorem Ty.rawBind_rawWF {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, (θ.types i).RawWF n)
      (hes : ∀ e ∈ θ.rows, Eff.RawWF n e) (t : Ty) (h : t.RawWF m) : (t.rawBind θ).RawWF n := by
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

  theorem Ty.rawBindTys_rawWF {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, (θ.types i).RawWF n)
      (hes : ∀ e ∈ θ.rows, Eff.RawWF n e) (as : List Ty) (h : Ty.RawWFList m as) :
      Ty.RawWFList n (Ty.rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawBind_rawWF θ hts hes a h.1, Ty.rawBindTys_rawWF θ hts hes as h.2⟩

  theorem Eff.rawBind_rawWF {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, (θ.types i).RawWF n)
      (hes : ∀ e ∈ θ.rows, Eff.RawWF n e) (e : Eff) (h : Eff.RawWF m e) : Eff.RawWF n (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      apply Ty.RawWFList.iff.mpr
      intro t ht
      rcases List.mem_append.mp ht with ht | ht
      · exact Ty.RawWFList.iff.mp (Ty.rawBindTys_rawWF θ hts hes fs h) t ht
      · obtain ⟨i, e, he, _, hte⟩ := Eff.mem_rowFails.mp ht
        have hfe : Ty.RawWFList n e.fails := by cases e; exact hes _ (List.mem_of_getElem? he)
        exact Ty.RawWFList.iff.mp hfe t hte
end

/-- 正規化した一般の代入は、整形式の型と整形式の置換像から整形式を得る。 -/
theorem Ty.bind_wf {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, Ty.WF n (θ.types i))
    (hes : ∀ e ∈ θ.rows, Eff.WF n e) (t : Ty) (h : Ty.WF m t) : Ty.WF n (Ty.bind θ t) := by
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
theorem Ty.shift_wf {n : Nat} (k : Nat) (t : Ty) (h : Ty.WF n t) : Ty.WF (n + k) (t.shift k 0) := by
  rw [Ty.shift_eq_norm_rawShift, Ty.rawShift_eq_rawBind]
  apply Ty.bind_wf (SubstEnv.shift k 0) (hes := by simp [SubstEnv.shift]) (t := t) (h := h)
  intro i hi
  simp only [SubstEnv.shift, Nat.not_lt_zero, ↓reduceIte, Ty.WF]
  omega

/-- 有限列の代入は、閉じた型と行の像から、残った束縛の範囲で整形式を得る。 -/
theorem Ty.substAt_wf {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (hes : ∀ e ∈ es, Eff.WF 0 e)
    (t : Ty) (h : Ty.WF (c + ts.length) t) : Ty.WF c (t.substAt c ts es) := by
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
theorem Ty.subst_wf {n : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF n t) (hes : ∀ e ∈ es, Eff.WF n e)
    (t : Ty) (h : Ty.WF ts.length t) : Ty.WF n (t.subst ts es) := by
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
theorem Eff.bind_wf {m n : Nat} (θ : SubstEnv) (hts : ∀ i < m, Ty.WF n (θ.types i))
    (hes : ∀ e ∈ θ.rows, Eff.WF n e) (e : Eff) (h : Eff.WF m e) : Eff.WF n (Eff.bind θ e) := by
  exact Eff.norm_rawWF _ (Eff.rawBind_rawWF θ (fun i hi => Ty.WF.raw _ (hts i hi))
    (fun e he => Eff.WF.raw _ (hes e he)) e (Eff.WF.raw e h))

/-- 束縛の外側での型と行の同時代入は、Fail 型の整形式を保つ。 -/
theorem Eff.subst_wf {n : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF n t) (hes : ∀ e ∈ es, Eff.WF n e)
    (e : Eff) (h : Eff.WF ts.length e) : Eff.WF n (Eff.substAt 0 ts es e) := by
  apply Eff.bind_wf (SubstEnv.at 0 ts es) (e := e) (h := h)
  · intro i hi
    simp only [SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hi,
      List.getElem?_eq_getElem hi, Option.getD_some, Ty.rawShift_zero]
    exact hts _ (List.getElem_mem hi)
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    simpa only [Eff.rawShift_zero] using hes f hf

theorem Ty.substList_wf {n : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF n t) (hes : ∀ e ∈ es, Eff.WF n e)
    (as : List Ty) (h : Ty.WFList ts.length as) :
    Ty.WFList n (as.map (Ty.subst ts es)) := by
  apply Ty.WFList.iff.mpr
  rintro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact Ty.subst_wf es hts hes a (Ty.WFList.iff.mp h a ha)

/-- 有限列の代入は、閉じた型と行の像から、残った束縛の範囲で整形式を得る。 -/
theorem Eff.substAt_wf {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (hes : ∀ e ∈ es, Eff.WF 0 e)
    (t : Eff) (h : Eff.WF (c + ts.length) t) : Eff.WF c (Eff.substAt c ts es t) := by
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
