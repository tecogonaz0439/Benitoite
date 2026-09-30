import Benitoite.Release.Lemmas.Basic
import Benitoite.Release.WellFormed

/-!
# 型の正しさ、ずらし、置き換えの補題（段階 B）
-/

namespace Benitoite.Release

/-! ## エフェクトの集合の置き換えの合成 -/

/-- `ε[Ē/ρ̄]` の要素の言い換え。 -/
theorem Eff.substRho_true {es : List Eff} {ε : Eff} {a : Atom} :
    Eff.substRho es ε a = true ↔
      ((match a with
        | .name l => ε (.name l) = true
        | .rho k => es.length ≤ k ∧ ε (.rho k) = true) ∨
       ∃ i e, es[i]? = some e ∧ ε (.rho i) = true ∧ e a = true) := by
  simp only [Eff.substRho, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
  apply or_congr
  · cases a with
    | name l => rfl
    | rho k =>
      by_cases hk : k < es.length
      · simp only [hk, ↓reduceIte, Bool.false_eq_true, false_iff, not_and]
        intro h; omega
      · simp only [hk, ↓reduceIte]
        constructor
        · intro h; exact ⟨by omega, h⟩
        · intro h; exact h.2
  · constructor
    · rintro ⟨i, hi, h1, h2⟩
      refine ⟨i, es[i], by simp [hi], h1, ?_⟩
      simpa [List.getElem?_eq_getElem hi] using h2
    · rintro ⟨i, e, he, h1, h2⟩
      have hi : i < es.length := (List.getElem?_eq_some_iff.mp he).1
      refine ⟨i, hi, h1, ?_⟩
      simp [List.getElem?_eq_getElem hi] at he ⊢
      rw [he]; exact h2

/-- 置き換えで残るのはエフェクトの名前だけであるときの、`ε[Ē/ρ̄]` の要素の言い換え。 -/
theorem Eff.substRho_true_scoped {es : List Eff} {ε : Eff} (h : Eff.RhosIn (· < es.length) ε)
    {a : Atom} :
    Eff.substRho es ε a = true ↔
      ((∃ l, a = .name l ∧ ε (.name l) = true) ∨
        ∃ i e, es[i]? = some e ∧ ε (.rho i) = true ∧ e a = true) := by
  rw [Eff.substRho_true]
  apply or_congr _ Iff.rfl
  cases a with
  | name l => simp
  | rho k =>
      simp only [reduceCtorEq, false_and, exists_false, iff_false, not_and]
      intro hk hε
      have := h k hε; omega

theorem Eff.substRho_comp {es es' : List Eff} {ε : Eff} (h : Eff.RhosIn (· < es.length) ε) :
    Eff.substRho es' (Eff.substRho es ε) = Eff.substRho (es.map (Eff.substRho es')) ε := by
  have h' : Eff.RhosIn (· < (es.map (Eff.substRho es')).length) ε := by
    intro i hi; simpa using h i hi
  funext a
  apply Bool.eq_iff_iff.mpr
  rw [Eff.substRho_true (es := es'), Eff.substRho_true_scoped h']
  constructor
  · rintro (hkeep | ⟨j, e', he', hj, ha⟩)
    · cases a with
      | name l =>
          simp only at hkeep
          rcases (Eff.substRho_true_scoped h).mp hkeep with ⟨l', hl, hε⟩ | ⟨i, e, he, hi, hea⟩
          · cases hl; exact Or.inl ⟨l, rfl, hε⟩
          · exact Or.inr ⟨i, Eff.substRho es' e, by simp [he], hi,
              Eff.substRho_true.mpr (Or.inl hea)⟩
      | rho k =>
          simp only at hkeep
          rcases (Eff.substRho_true_scoped h).mp hkeep.2 with ⟨l', hl, _⟩ | ⟨i, e, he, hi, hea⟩
          · cases hl
          · exact Or.inr ⟨i, Eff.substRho es' e, by simp [he], hi,
              Eff.substRho_true.mpr (Or.inl ⟨hkeep.1, hea⟩)⟩
    · rcases (Eff.substRho_true_scoped h).mp hj with ⟨l', hl, _⟩ | ⟨i, e, he, hi, hej⟩
      · cases hl
      · exact Or.inr ⟨i, Eff.substRho es' e, by simp [he], hi,
          Eff.substRho_true.mpr (Or.inr ⟨j, e', he', hej, ha⟩)⟩
  · rintro (⟨l, rfl, hε⟩ | ⟨i, e'', he'', hi, ha⟩)
    · left; simp only
      exact (Eff.substRho_true_scoped h).mpr (Or.inl ⟨l, rfl, hε⟩)
    · simp only [List.getElem?_map, Option.map_eq_some_iff] at he''
      obtain ⟨e, he, rfl⟩ := he''
      rcases Eff.substRho_true.mp ha with hkeep | ⟨j, e', he', hej, ha'⟩
      · left
        cases a with
        | name l =>
            simp only at hkeep ⊢
            exact (Eff.substRho_true_scoped h).mpr (Or.inr ⟨i, e, he, hi, hkeep⟩)
        | rho k =>
            simp only at hkeep ⊢
            exact ⟨hkeep.1, (Eff.substRho_true_scoped h).mpr (Or.inr ⟨i, e, he, hi, hkeep.2⟩)⟩
      · exact Or.inr ⟨j, e', he', (Eff.substRho_true_scoped h).mpr (Or.inr ⟨i, e, he, hi, hej⟩), ha'⟩

/-! ## 型構成子の適用 -/

/-- 型構成子か型の変数（`Ty.applyTo` が型引数を使う形）。 -/
def Ty.IsHead : Ty → Prop
  | .ctor _ => True
  | .tvar _ => True
  | _ => False

theorem Ty.applyTo_notHead (t : Ty) (as : List Ty) : ¬ (t.applyTo as).IsHead := by
  cases t with
  | ctor φ => cases φ <;> simp [Ty.applyTo, TyCon.apply, Ty.IsHead]
  | tvar j => simp [Ty.applyTo, Ty.IsHead]
  | _ => simp [Ty.applyTo, Ty.IsHead]

theorem Ty.applyTo_of_notHead {t : Ty} (h : ¬ t.IsHead) (as : List Ty) : t.applyTo as = t := by
  cases t <;> simp_all [Ty.applyTo, Ty.IsHead]

theorem Ty.substAt_notHead {c ts es} (t : Ty) (h : ¬ t.IsHead) : ¬ (t.substAt c ts es).IsHead := by
  cases t with
  | tapp i as =>
      simp only [Ty.substAt]
      split
      · simp [Ty.IsHead]
      · split
        · exact Ty.applyTo_notHead _ _
        · simp [Ty.IsHead]
  | _ => simp_all [Ty.substAt, Ty.IsHead]

theorem Ty.shift_notHead {k c} (t : Ty) (h : ¬ t.IsHead) : ¬ (t.shift k c).IsHead := by
  cases t <;> simp_all [Ty.shift, Ty.IsHead]

/-- 型の置き換えと、型構成子の適用の入れ替え（型の種類が合わないときも成り立つ）。 -/
theorem Ty.substAt_applyTo {c ts es} (t : Ty) (as : List Ty) :
    (t.applyTo as).substAt c ts es = (t.substAt c ts es).applyTo (as.map (Ty.substAt c ts es)) := by
  by_cases h : t.IsHead
  · cases t with
    | ctor φ =>
        cases φ <;> cases as <;> simp [Ty.applyTo, TyCon.apply, Ty.substAt]
        all_goals (rename_i a b; cases b <;> simp [Ty.substAt])
    | tvar j =>
        simp only [Ty.applyTo, Ty.substAt]
        split
        · simp
        · split
          · rfl
          · simp
    | _ => simp [Ty.IsHead] at h
  · rw [Ty.applyTo_of_notHead h, Ty.applyTo_of_notHead (Ty.substAt_notHead t h)]

theorem Ty.shift_applyTo {k c} (t : Ty) (as : List Ty) :
    (t.applyTo as).shift k c = (t.shift k c).applyTo (as.map (Ty.shift k c)) := by
  by_cases h : t.IsHead
  · cases t with
    | ctor φ =>
        cases φ <;> cases as <;> simp [Ty.applyTo, TyCon.apply, Ty.shift]
        all_goals (rename_i a b; cases b <;> simp [Ty.shift])
    | tvar j =>
        simp only [Ty.applyTo, Ty.shift]
        split <;> simp
    | _ => simp [Ty.IsHead] at h
  · rw [Ty.applyTo_of_notHead h, Ty.applyTo_of_notHead (Ty.shift_notHead t h)]

/-! ## 型の正しさ -/

mutual
  theorem Ty.WF.mono {n m : Nat} (h : n ≤ m) : (a : Ty) → Ty.WF n a → Ty.WF m a
    | .base _, _ => trivial
    | .opaque _, _ => trivial
    | .data _ args, w => by simp only [Ty.WF] at w ⊢; exact Ty.WFList.mono h args w
    | .list a, w => by simp only [Ty.WF] at w ⊢; exact Ty.WF.mono h a w
    | .fn ps r _, w => by
        simp only [Ty.WF] at w ⊢; exact ⟨Ty.WFList.mono h ps w.1, Ty.WF.mono h r w.2⟩
    | .tvar i, w => by simp only [Ty.WF] at w ⊢; omega
    | .reference a, w => by simp only [Ty.WF] at w ⊢; exact Ty.WF.mono h a w
    | .lazy a, w => by simp only [Ty.WF] at w ⊢; exact Ty.WF.mono h a w
    | .cont b t _, w => by
        simp only [Ty.WF] at w ⊢; exact ⟨Ty.WF.mono h b w.1, Ty.WF.mono h t w.2⟩
    | .map a b, w => by
        simp only [Ty.WF] at w ⊢; exact ⟨Ty.WF.mono h a w.1, Ty.WF.mono h b w.2⟩
    | .set a, w => by simp only [Ty.WF] at w ⊢; exact Ty.WF.mono h a w
    | .bytes, _ => by simp [Ty.WF]
    | .dict _ τ, w => by simp only [Ty.WF] at w ⊢; exact Ty.WF.mono h τ w
    | .tapp i args, w => by
        simp only [Ty.WF] at w ⊢; exact ⟨by omega, Ty.WFList.mono h args w.2⟩
    | .ctor _, _ => by simp [Ty.WF]

  theorem Ty.WFList.mono {n m : Nat} (h : n ≤ m) : (as : List Ty) → Ty.WFList n as → Ty.WFList m as
    | [], _ => trivial
    | a :: as, w => by
        simp only [Ty.WFList] at w ⊢; exact ⟨Ty.WF.mono h a w.1, Ty.WFList.mono h as w.2⟩
end

theorem Ty.applyTo_wf {n : Nat} {t : Ty} {as : List Ty} (ht : Ty.WF n t) (has : Ty.WFList n as) :
    Ty.WF n (t.applyTo as) := by
  cases t with
  | ctor φ =>
      cases φ <;> cases as <;> simp_all [Ty.applyTo, TyCon.apply, Ty.WF, Ty.WFList]
      all_goals (rename_i b; cases b <;> simp_all [Ty.WF, Ty.WFList])
  | tvar j => simp_all [Ty.applyTo, Ty.WF]
  | _ => simpa [Ty.applyTo] using ht

theorem Ty.WFList.iff {n : Nat} {as : List Ty} : Ty.WFList n as ↔ ∀ a ∈ as, Ty.WF n a := by
  induction as with
  | nil => simp [Ty.WFList]
  | cons a as ih => simp [Ty.WFList, ih]

mutual
  /-- 項の中に書ける型の変数の範囲は、型の正しさを含む。 -/
  theorem Ty.VarsIn.wf {n : Nat} {pe : Nat → Prop} : (a : Ty) → Ty.VarsIn n pe a → Ty.WF n a
    | .base _, _ => trivial
    | .opaque _, _ => trivial
    | .data _ args, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact Ty.VarsInList.wf args w
    | .list a, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact Ty.VarsIn.wf a w
    | .fn ps r _, w => by
        simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact ⟨Ty.VarsInList.wf ps w.1, Ty.VarsIn.wf r w.2.1⟩
    | .tvar i, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact w
    | .reference a, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact Ty.VarsIn.wf a w
    | .lazy a, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact Ty.VarsIn.wf a w
    | .cont _ _ _, w => by simp only [Ty.VarsIn] at w
    | .map a b, w => by
        simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact ⟨Ty.VarsIn.wf a w.1, Ty.VarsIn.wf b w.2⟩
    | .set a, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact Ty.VarsIn.wf a w
    | .bytes, _ => by simp [Ty.WF]
    | .dict _ τ, w => by simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact Ty.VarsIn.wf τ w
    | .tapp i args, w => by
        simp only [Ty.VarsIn, Ty.WF] at w ⊢; exact ⟨w.1, Ty.VarsInList.wf args w.2⟩
    | .ctor _, _ => by simp [Ty.WF]

  theorem Ty.VarsInList.wf {n : Nat} {pe : Nat → Prop} : (as : List Ty) → Ty.VarsInList n pe as →
      Ty.WFList n as
    | [], _ => trivial
    | a :: as, w => by
        simp only [Ty.VarsInList, Ty.WFList] at w ⊢; exact ⟨Ty.VarsIn.wf a w.1, Ty.VarsInList.wf as w.2⟩
end

/-! ## ずらし -/

mutual
  theorem Ty.shift_zero (c : Nat) : (a : Ty) → a.shift 0 c = a
    | .base _ => by simp [Ty.shift]
    | .opaque _ => by simp [Ty.shift]
    | .data d args => by simp only [Ty.shift]; rw [Ty.shiftList_zero c args]
    | .list a => by simp only [Ty.shift]; rw [Ty.shift_zero c a]
    | .fn ps r e => by simp only [Ty.shift]; rw [Ty.shiftList_zero c ps, Ty.shift_zero c r]
    | .tvar i => by simp [Ty.shift]
    | .reference a => by simp only [Ty.shift]; rw [Ty.shift_zero c a]
    | .lazy a => by simp only [Ty.shift]; rw [Ty.shift_zero c a]
    | .cont b t e => by simp only [Ty.shift]; rw [Ty.shift_zero c b, Ty.shift_zero c t]
    | .map a b => by simp only [Ty.shift]; rw [Ty.shift_zero c a, Ty.shift_zero c b]
    | .set a => by simp only [Ty.shift]; rw [Ty.shift_zero c a]
    | .bytes => by simp [Ty.shift]
    | .dict _ τ => by simp only [Ty.shift]; rw [Ty.shift_zero c τ]
    | .tapp i args => by simp only [Ty.shift]; rw [Ty.shiftList_zero c args]; simp
    | .ctor _ => by simp [Ty.shift]

  theorem Ty.shiftList_zero (c : Nat) : (as : List Ty) → as.map (Ty.shift 0 c) = as
    | [] => rfl
    | a :: as => by simp only [List.map_cons]; rw [Ty.shift_zero c a, Ty.shiftList_zero c as]
end

mutual
  /-- 番号が `c` より小さい型の変数だけを使う型は、`c` 以上の番号をずらしても変わらない。 -/
  theorem Ty.shift_of_wf {c : Nat} (k : Nat) : (a : Ty) → Ty.WF c a → a.shift k c = a
    | .base _, _ => by simp [Ty.shift]
    | .opaque _, _ => by simp [Ty.shift]
    | .data d args, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift]; rw [Ty.shiftList_of_wf k args w]
    | .list a, w => by simp only [Ty.WF] at w; simp only [Ty.shift]; rw [Ty.shift_of_wf k a w]
    | .fn ps r e, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift]
        rw [Ty.shiftList_of_wf k ps w.1, Ty.shift_of_wf k r w.2]
    | .tvar i, w => by simp only [Ty.WF] at w; simp [Ty.shift, w]
    | .reference a, w => by simp only [Ty.WF] at w; simp only [Ty.shift]; rw [Ty.shift_of_wf k a w]
    | .lazy a, w => by simp only [Ty.WF] at w; simp only [Ty.shift]; rw [Ty.shift_of_wf k a w]
    | .cont b t e, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift]
        rw [Ty.shift_of_wf k b w.1, Ty.shift_of_wf k t w.2]
    | .map a b, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift]
        rw [Ty.shift_of_wf k a w.1, Ty.shift_of_wf k b w.2]
    | .set a, w => by simp only [Ty.WF] at w; simp only [Ty.shift]; rw [Ty.shift_of_wf k a w]
    | .bytes, _ => by simp [Ty.shift]
    | .dict _ τ, w => by simp only [Ty.WF] at w; simp only [Ty.shift]; rw [Ty.shift_of_wf k τ w]
    | .tapp i args, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift, w.1, ↓reduceIte]; rw [Ty.shiftList_of_wf k args w.2]
    | .ctor _, _ => by simp [Ty.shift]

  theorem Ty.shiftList_of_wf {c : Nat} (k : Nat) : (as : List Ty) → Ty.WFList c as →
      as.map (Ty.shift k c) = as
    | [], _ => rfl
    | a :: as, w => by
        simp only [Ty.WFList] at w
        simp only [List.map_cons]; rw [Ty.shift_of_wf k a w.1, Ty.shiftList_of_wf k as w.2]
end

mutual
  theorem Ty.shift_wf {n : Nat} (k : Nat) : (a : Ty) → Ty.WF n a → Ty.WF (n + k) (a.shift k 0)
    | .base _, _ => by simp [Ty.shift, Ty.WF]
    | .opaque _, _ => by simp [Ty.shift, Ty.WF]
    | .data _ args, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]; exact Ty.shiftList_wf k args w
    | .list a, w => by simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]; exact Ty.shift_wf k a w
    | .fn ps r _, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]
        exact ⟨Ty.shiftList_wf k ps w.1, Ty.shift_wf k r w.2⟩
    | .tvar i, w => by simp only [Ty.WF] at w; simp [Ty.shift, Ty.WF]; omega
    | .reference a, w => by simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]; exact Ty.shift_wf k a w
    | .lazy a, w => by simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]; exact Ty.shift_wf k a w
    | .cont b t _, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]
        exact ⟨Ty.shift_wf k b w.1, Ty.shift_wf k t w.2⟩
    | .map a b, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]
        exact ⟨Ty.shift_wf k a w.1, Ty.shift_wf k b w.2⟩
    | .set a, w => by simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]; exact Ty.shift_wf k a w
    | .bytes, _ => by simp [Ty.shift, Ty.WF]
    | .dict _ τ, w => by simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF]; exact Ty.shift_wf k τ w
    | .tapp i args, w => by
        simp only [Ty.WF] at w; simp only [Ty.shift, Ty.WF, Nat.not_lt_zero, ↓reduceIte]
        exact ⟨by omega, Ty.shiftList_wf k args w.2⟩
    | .ctor _, _ => by simp [Ty.shift, Ty.WF]

  theorem Ty.shiftList_wf {n : Nat} (k : Nat) : (as : List Ty) → Ty.WFList n as →
      Ty.WFList (n + k) (as.map (Ty.shift k 0))
    | [], _ => trivial
    | a :: as, w => by
        simp only [Ty.WFList] at w
        simp only [List.map_cons, Ty.WFList]; exact ⟨Ty.shift_wf k a w.1, Ty.shiftList_wf k as w.2⟩
end

/-! ## 型の置き換え -/

mutual
  /-- 閉じた型で置き換えた結果の型の正しさ。 -/
  theorem Ty.substAt_wf {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ t ∈ ts, Ty.WF 0 t) :
      (a : Ty) → Ty.WF (c + ts.length) a → Ty.WF c (a.substAt c ts es)
    | .base _, _ => by simp [Ty.substAt, Ty.WF]
    | .opaque _, _ => by simp [Ty.substAt, Ty.WF]
    | .data _ args, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]; exact Ty.substAtList_wf es hts args w
    | .list a, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]; exact Ty.substAt_wf es hts a w
    | .fn ps r _, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]
        exact ⟨Ty.substAtList_wf es hts ps w.1, Ty.substAt_wf es hts r w.2⟩
    | .tvar i, w => by
        simp only [Ty.WF] at w
        simp only [Ty.substAt]
        by_cases h1 : i < c
        · simp [h1, Ty.WF]
        · have h2 : i - c < ts.length := by omega
          simp only [h1, ↓reduceIte, h2]
          have hmem : ts[i - c] ∈ ts := List.getElem_mem h2
          have hw := hts _ hmem
          rw [List.getElem?_eq_getElem h2, Option.getD_some, Ty.shift_of_wf c _ hw]
          exact Ty.WF.mono (Nat.zero_le _) _ hw
    | .reference a, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]; exact Ty.substAt_wf es hts a w
    | .lazy a, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]; exact Ty.substAt_wf es hts a w
    | .cont b t _, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]
        exact ⟨Ty.substAt_wf es hts b w.1, Ty.substAt_wf es hts t w.2⟩
    | .map a b, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]
        exact ⟨Ty.substAt_wf es hts a w.1, Ty.substAt_wf es hts b w.2⟩
    | .set a, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]; exact Ty.substAt_wf es hts a w
    | .bytes, _ => by simp [Ty.substAt, Ty.WF]
    | .dict _ τ, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, Ty.WF]; exact Ty.substAt_wf es hts τ w
    | .tapp i args, w => by
        simp only [Ty.WF] at w
        have hl := Ty.substAtList_wf es hts args w.2
        simp only [Ty.substAt]
        by_cases h1 : i < c
        · simp only [h1, ↓reduceIte, Ty.WF]; exact ⟨trivial, hl⟩
        · have h2 : i - c < ts.length := by omega
          simp only [h1, ↓reduceIte, h2]
          have hw := hts _ (List.getElem_mem h2)
          rw [List.getElem?_eq_getElem h2, Option.getD_some, Ty.shift_of_wf c _ hw]
          exact Ty.applyTo_wf (Ty.WF.mono (Nat.zero_le _) _ hw) hl
    | .ctor _, _ => by simp [Ty.substAt, Ty.WF]

  theorem Ty.substAtList_wf {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ t ∈ ts, Ty.WF 0 t) :
      (as : List Ty) → Ty.WFList (c + ts.length) as → Ty.WFList c (as.map (Ty.substAt c ts es))
    | [], _ => trivial
    | a :: as, w => by
        simp only [Ty.WFList] at w
        simp only [List.map_cons, Ty.WFList]
        exact ⟨Ty.substAt_wf es hts a w.1, Ty.substAtList_wf es hts as w.2⟩
end

mutual
  /-- 型の変数の番号が `c` より小さく、エフェクト変数を含まない型は、`c` の内側の置き換えで変わらない。 -/
  theorem Ty.substAt_of_closed {c : Nat} (ts : List Ty) (es : List Eff) :
      (a : Ty) → Ty.VarsIn c (fun _ => False) a → a.substAt c ts es = a
    | .base _, _ => by simp [Ty.substAt]
    | .opaque _, _ => by simp [Ty.substAt]
    | .data d args, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]; rw [Ty.substAtList_of_closed ts es args w]
    | .list a, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]; rw [Ty.substAt_of_closed ts es a w]
    | .fn ps r e, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]
        rw [Ty.substAtList_of_closed ts es ps w.1, Ty.substAt_of_closed ts es r w.2.1]
        have : Eff.substRho es e = e := by
          funext x
          cases x with
          | name l =>
              simp only [Eff.substRho]
              apply Bool.eq_iff_iff.mpr
              simp only [Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
              constructor
              · rintro (h | ⟨x, _, hx, _⟩)
                · exact h
                · exact absurd (w.2.2 x hx) id
              · intro h; exact Or.inl h
          | rho j =>
              have hj : e (.rho j) = false := by
                cases h : e (.rho j)
                · rfl
                · exact absurd (w.2.2 j h) id
              apply Bool.eq_iff_iff.mpr
              simp only [Eff.substRho, Bool.or_eq_true, List.any_eq_true, List.mem_range,
                Bool.and_eq_true, hj]
              constructor
              · rintro (h | ⟨x, _, hx, _⟩)
                · split at h <;> simp_all
                · exact absurd (w.2.2 x hx) id
              · intro h; cases h
        rw [this]
    | .tvar i, w => by simp only [Ty.VarsIn] at w; simp [Ty.substAt, w]
    | .reference a, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]; rw [Ty.substAt_of_closed ts es a w]
    | .lazy a, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]; rw [Ty.substAt_of_closed ts es a w]
    | .cont _ _ _, w => by simp only [Ty.VarsIn] at w
    | .map a b, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]
        rw [Ty.substAt_of_closed ts es a w.1, Ty.substAt_of_closed ts es b w.2]
    | .set a, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]; rw [Ty.substAt_of_closed ts es a w]
    | .bytes, _ => by simp [Ty.substAt]
    | .dict _ τ, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt]; rw [Ty.substAt_of_closed ts es τ w]
    | .tapp i args, w => by
        simp only [Ty.VarsIn] at w; simp only [Ty.substAt, w.1, ↓reduceIte]
        rw [Ty.substAtList_of_closed ts es args w.2]
    | .ctor _, _ => by simp [Ty.substAt]

  theorem Ty.substAtList_of_closed {c : Nat} (ts : List Ty) (es : List Eff) :
      (as : List Ty) → Ty.VarsInList c (fun _ => False) as → as.map (Ty.substAt c ts es) = as
    | [], _ => rfl
    | a :: as, w => by
        simp only [Ty.VarsInList] at w
        simp only [List.map_cons]; rw [Ty.substAt_of_closed ts es a w.1, Ty.substAtList_of_closed ts es as w.2]
end

mutual
  /-- ずらしと置き換えの入れ替え（置き換える型が閉じているとき）。節の内側に入るときに使う。 -/
  theorem Ty.shift_substAt {c k : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ t ∈ ts, Ty.WF 0 t) :
      (a : Ty) → (a.shift k 0).substAt (c + k) ts es = (a.substAt c ts es).shift k 0
    | .base _ => by simp [Ty.shift, Ty.substAt]
    | .opaque _ => by simp [Ty.shift, Ty.substAt]
    | .data d args => by
        simp only [Ty.shift, Ty.substAt]
        rw [Ty.shiftList_substAt es hts args]
    | .list a => by simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts a]
    | .fn ps r e => by
        simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_substAt es hts r]
        have := Ty.shiftList_substAt (c := c) (k := k) es hts ps
        simp only [List.map_map] at this ⊢
        rw [this]
    | .tvar i => by
        simp only [Ty.shift, Nat.not_lt_zero, ↓reduceIte, Ty.substAt]
        by_cases h1 : i < c
        · have : i + k < c + k := by omega
          simp [h1, this, Ty.shift]
        · have h1' : ¬ (i + k < c + k) := by omega
          by_cases h2 : i - c < ts.length
          · have h2' : i + k - (c + k) < ts.length := by omega
            have he : i + k - (c + k) = i - c := by omega
            simp only [h1, h1', ↓reduceIte, h2, he]
            have hw := hts _ (List.getElem_mem h2)
            simp only [List.getElem?_eq_getElem h2, Option.getD_some]
            rw [Ty.shift_of_wf _ _ hw, Ty.shift_of_wf _ _ hw]
            try exact (Ty.shift_of_wf k _ hw).symm
          · have h2' : ¬ (i + k - (c + k) < ts.length) := by omega
            simp only [h1, h1', ↓reduceIte, h2, h2', Ty.shift, Nat.not_lt_zero]
            congr 1; omega
    | .reference a => by simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts a]
    | .lazy a => by simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts a]
    | .cont b t e => by
        simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts b, Ty.shift_substAt es hts t]
    | .map a b => by
        simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts a, Ty.shift_substAt es hts b]
    | .set a => by simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts a]
    | .bytes => by simp [Ty.shift, Ty.substAt]
    | .dict _ τ => by simp only [Ty.shift, Ty.substAt]; rw [Ty.shift_substAt es hts τ]
    | .tapp i args => by
        have hl := Ty.shiftList_substAt (c := c) (k := k) es hts args
        simp only [Ty.shift, Nat.not_lt_zero, ↓reduceIte, Ty.substAt]
        by_cases h1 : i < c
        · have : i + k < c + k := by omega
          simp only [this, h1, ↓reduceIte, Ty.shift, hl, Nat.not_lt_zero]
        · have h1' : ¬ (i + k < c + k) := by omega
          by_cases h2 : i - c < ts.length
          · have h2' : i + k - (c + k) < ts.length := by omega
            have he : i + k - (c + k) = i - c := by omega
            simp only [h1, h1', ↓reduceIte, h2, he]
            have hw := hts _ (List.getElem_mem h2)
            simp only [List.getElem?_eq_getElem h2, Option.getD_some]
            rw [Ty.shift_applyTo, hl, Ty.shift_of_wf _ _ hw, Ty.shift_of_wf _ _ hw, Ty.shift_of_wf _ _ hw]
          · have h2' : ¬ (i + k - (c + k) < ts.length) := by omega
            simp only [h1, h1', ↓reduceIte, h2, h2', Ty.shift, Nat.not_lt_zero, hl]
            congr 1; omega
    | .ctor _ => by simp [Ty.shift, Ty.substAt]

  theorem Ty.shiftList_substAt {c k : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ t ∈ ts, Ty.WF 0 t) :
      (as : List Ty) →
      (as.map (Ty.shift k 0)).map (Ty.substAt (c + k) ts es) = (as.map (Ty.substAt c ts es)).map (Ty.shift k 0)
    | [] => rfl
    | a :: as => by
        simp only [List.map_cons]; rw [Ty.shift_substAt es hts a, Ty.shiftList_substAt es hts as]
end

mutual
  /-- 型の置き換えの合成。宣言が束縛した型パラメータだけを使う型に `[T̄/ᾱ, Ē/ρ̄]` を施し、さらに外側の
  置き換えを施したものは、`[T̄θ/ᾱ, Ēθ/ρ̄]` を施したものに等しい。 -/
  theorem Ty.subst_comp {ts : List Ty} {es : List Eff} (c : Nat) (ts' : List Ty) (es' : List Eff) :
      (a : Ty) → Ty.VarsIn ts.length (· < es.length) a →
      Ty.substAt c ts' es' (Ty.subst ts es a) =
        Ty.subst (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substRho es')) a
    | .base _, _ => by simp [Ty.subst, Ty.substAt]
    | .opaque _, _ => by simp [Ty.subst, Ty.substAt]
    | .data d args, h => by
        simp only [Ty.VarsIn] at h
        simp only [Ty.subst, Ty.substAt]
        have := Ty.subst_comp_list c ts' es' args h
        simp only [Ty.subst] at this
        rw [this]
    | .list a, h => by
        simp only [Ty.VarsIn] at h
        have := Ty.subst_comp c ts' es' a h
        simp only [Ty.subst] at this ⊢
        simp only [Ty.substAt]; rw [this]
    | .fn ps r ε, h => by
        simp only [Ty.VarsIn] at h
        have h1 := Ty.subst_comp_list c ts' es' ps h.1
        have h2 := Ty.subst_comp c ts' es' r h.2.1
        simp only [Ty.subst] at h1 h2 ⊢
        simp only [Ty.substAt]; rw [h1, h2, Eff.substRho_comp h.2.2]
    | .tvar i, h => by
        simp only [Ty.VarsIn] at h
        have h' : i < (ts.map (Ty.substAt c ts' es')).length := by simpa using h
        simp [Ty.subst, Ty.substAt, h, Ty.shift_zero, List.getElem_map]
    | .reference a, h => by
        simp only [Ty.VarsIn] at h
        have := Ty.subst_comp c ts' es' a h
        simp only [Ty.subst] at this ⊢
        simp only [Ty.substAt]; rw [this]
    | .lazy a, h => by
        simp only [Ty.VarsIn] at h
        have := Ty.subst_comp c ts' es' a h
        simp only [Ty.subst] at this ⊢
        simp only [Ty.substAt]; rw [this]
    | .cont _ _ _, h => by simp only [Ty.VarsIn] at h
    | .map a b, h => by
        simp only [Ty.VarsIn] at h
        have h1 := Ty.subst_comp c ts' es' a h.1
        have h2 := Ty.subst_comp c ts' es' b h.2
        simp only [Ty.subst] at h1 h2 ⊢
        simp only [Ty.substAt]; rw [h1, h2]
    | .set a, h => by
        simp only [Ty.VarsIn] at h
        have := Ty.subst_comp c ts' es' a h
        simp only [Ty.subst] at this ⊢
        simp only [Ty.substAt]; rw [this]
    | .bytes, _ => by simp [Ty.substAt, Ty.subst]
    | .dict _ τ, h => by
        simp only [Ty.VarsIn] at h
        have := Ty.subst_comp c ts' es' τ h
        simp only [Ty.subst] at this ⊢
        simp only [Ty.substAt]; rw [this]
    | .tapp i args, h => by
        simp only [Ty.VarsIn] at h
        have hl := Ty.subst_comp_list c ts' es' args h.2
        simp only [Ty.subst] at hl ⊢
        have h' : i < (ts.map (Ty.substAt c ts' es')).length := by simpa using h.1
        simp only [Ty.substAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, h.1, h', Ty.shift_zero,
          List.getElem?_eq_getElem h.1, List.getElem?_eq_getElem h', Option.getD_some, List.getElem_map]
        rw [Ty.substAt_applyTo, hl]
    | .ctor _, _ => by simp [Ty.substAt, Ty.subst]

  theorem Ty.subst_comp_list {ts : List Ty} {es : List Eff} (c : Nat) (ts' : List Ty) (es' : List Eff) :
      (as : List Ty) → Ty.VarsInList ts.length (· < es.length) as →
      (as.map (Ty.subst ts es)).map (Ty.substAt c ts' es') =
        as.map (Ty.subst (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substRho es')))
    | [], _ => rfl
    | a :: as, h => by
        simp only [Ty.VarsInList] at h
        simp only [List.map_cons]
        rw [Ty.subst_comp c ts' es' a h.1, Ty.subst_comp_list c ts' es' as h.2]
end


end Benitoite.Release
