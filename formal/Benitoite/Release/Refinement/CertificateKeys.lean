import Benitoite.Release.Refinement.Certificate

/-! # 入れ子の証明書で再計算する鍵の検査 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem ofConjuncts_keys (Φ : List Pred) :
    (Pred.ofConjuncts Φ).linearKeys = Φ.flatMap Pred.linearKeys := by
  induction Φ with
  | nil => rfl
  | cons p ps ih => cases ps <;> simp_all [Pred.ofConjuncts, Pred.linearKeys]

private theorem conjuncts_keys (p : Pred) :
    p.conjuncts.flatMap Pred.linearKeys = p.linearKeys := by
  induction p <;> simp_all [Pred.conjuncts, Pred.linearKeys, List.flatMap_append]

/-- refute が使う平坦化した仮定と、上層の仮定の鍵列は同じである。 -/
theorem Certificate.refute_keys_same (Φ : List Pred) (goal : Pred) (r : Refutation) :
    (Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal =
      (Certificate.refute r).keys (Pred.ofConjuncts Φ) goal := by
  simp only [Certificate.keys, ofConjuncts_keys, List.flatMap_assoc]
  simp only [conjuncts_keys]

/-- 各位置の鍵列と、refute が仮定の連言を平坦化して読む鍵列の検査。 -/
def Certificate.AllKeysChecked (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (goal : Pred) (c : Certificate) : Prop :=
  KeyTable.checkIn P C Γ (c.keys (Pred.ofConjuncts Φ) goal) = true ∧
    match c with
    | .consume next => match Φ with
      | .and p q :: rest => next.AllKeysChecked P C Γ (p::q::rest) goal
      | _ => True
    | .cases l r => match Φ with
      | .or p q :: rest => l.AllKeysChecked P C Γ (p::rest) goal ∧ r.AllKeysChecked P C Γ (q::rest) goal
      | _ => True
    | .discard next => match Φ with
      | _::rest => next.AllKeysChecked P C Γ rest goal
      | [] => True
    | .substitute p t _ _ next _ => next.AllKeysChecked P C Γ Φ (p.open t)
    | .refute r => KeyTable.checkIn P C Γ
        ((Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal) = true
    | _ => True

private theorem key_subset {P C Γ keys children}
    (h : KeyTable.checkIn P C Γ keys = true)
    (sub : ∀ t ∈ children, t ∈ keys) : KeyTable.checkIn P C Γ children = true := by
  classical
  obtain ⟨valid, hs⟩ := KeyTable.checkIn_sound h
  simp only [KeyTable.checkIn, decide_eq_true_eq]
  exact ⟨valid, fun t ht => hs t (sub t ht)⟩

/-- 子の鍵は、その位置の仮定・結論または証明書の extraKeys から来る。 -/
theorem Certificate.keys_checked_all {P C Γ Φ goal} {c : Certificate}
    (h : KeyTable.checkIn P C Γ (c.keys (Pred.ofConjuncts Φ) goal) = true) :
    c.AllKeysChecked P C Γ Φ goal := by
  induction c generalizing Φ goal with
  | use | leaf => exact ⟨h,trivial⟩
  | refute r => exact ⟨h, by simpa only [Certificate.refute_keys_same] using h⟩
  | substitute p t u eq c mode ih =>
    refine ⟨h, ih (key_subset h ?_)⟩
    intro a ha
    simp only [Certificate.keys, Certificate.extraKeys, List.mem_append] at ha ⊢
    grind
  | consume c ih =>
    refine ⟨h, ?_⟩
    cases Φ with
    | nil => trivial
    | cons p rest =>
      cases p <;> try trivial
      rename_i p q
      apply ih (key_subset h ?_)
      intro a ha
      simp only [Certificate.keys, Certificate.extraKeys, ofConjuncts_keys,
        List.flatMap_cons, Pred.linearKeys, List.mem_append] at ha ⊢
      grind
  | cases l r ihl ihr =>
    refine ⟨h, ?_⟩
    cases Φ with
    | nil => trivial
    | cons p rest =>
      cases p <;> try trivial
      rename_i p q
      constructor
      · apply ihl (key_subset h ?_)
        intro a ha
        simp only [Certificate.keys, Certificate.extraKeys, ofConjuncts_keys,
          List.flatMap_cons, Pred.linearKeys, List.mem_append] at ha ⊢
        grind
      · apply ihr (key_subset h ?_)
        intro a ha
        simp only [Certificate.keys, Certificate.extraKeys, ofConjuncts_keys,
          List.flatMap_cons, Pred.linearKeys, List.mem_append] at ha ⊢
        grind
  | discard c ih =>
    refine ⟨h, ?_⟩
    cases Φ with
    | nil => trivial
    | cons p rest =>
      apply ih (key_subset h ?_)
      intro a ha
      simp only [Certificate.keys, Certificate.extraKeys, ofConjuncts_keys,
        List.flatMap_cons, List.mem_append] at ha ⊢
      grind

/-- 上層の成功から、全位置とrefuteの平坦化した仮定の実際の鍵列の検査を得る。 -/
theorem Certificate.checkIn_all_keys {P C Γ Φ goal} {c : Certificate}
    (h : Certificate.checkIn P C Γ Φ goal c = true) :
    c.AllKeysChecked P C Γ Φ goal :=
  Certificate.keys_checked_all (Certificate.checkIn_sound h).1

end
end Benitoite.Release.Refinement
