import Benitoite.Release.Refinement.CertificateEntails
import Benitoite.Release.Refinement.EqCertificateTyping
import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.LogicSound

/-! # 型と宣言を照合する証明書の上層の入口 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem PreparedLeaf.entails {l : PreparedLeaf} (h : l.check = true) : Entails Φ l.predicate := by
  have hc : l.predicate.closedTrue = true := by
    simp only [PreparedLeaf.check, Bool.and_eq_true] at h; exact h.1
  exact (Pred.closedTrue_entails hc).2.2.weaken (by simp)

/-- 機械評価が成功した葉は、全域モデルでも真となる。 -/
theorem PreparedLeaf.machine_exact {l : PreparedLeaf} (h : l.check = true) (η : ObservationEnvModel) :
    l.predicate.interpret η = true := (l.entails (Φ := []) h).sound η (by simp)

/-- 閉じた葉は任意の値置換で変わらない。 -/
theorem PreparedLeaf.stable {l : PreparedLeaf} (h : l.check = true) (ν : ObservationEnv) :
    predBind ν l.predicate = l.predicate := by
  have hc : l.predicate.closedTrue = true := by
    simp only [PreparedLeaf.check, Bool.and_eq_true] at h; exact h.1
  exact Pred.bind_closed (Pred.closedTrue_entails hc).1 ν

/-- 宣言側が選んだ文脈とsortを検査し、等号の証拠と分離しない。 -/
def EqProof.checkSorted (Γ : Ctx) (s : «Sort») (t u : Term) (c : EqProof) : Bool :=
  decide (t.HasSort Γ s ∧ u.HasSort Γ s) && c.check t u

theorem EqProof.checkSorted_sound {Γ s t u c} (h : EqProof.checkSorted Γ s t u c = true) :
    t.HasSort Γ s ∧ u.HasSort Γ s ∧ t = u := by
  simp only [checkSorted,Bool.and_eq_true,decide_eq_true_eq] at h
  exact ⟨h.1.1,h.1.2,EqProof.sound h.2⟩

/-- 論理の再生とsortの入口を一つにし、不適格な仮定も拒否する。 -/
def Certificate.checkSorted (Γ : Ctx) (Φ : List Pred) (goal : Pred) (c : Certificate) : Bool :=
  decide (goal.Sorted Γ none ∧ ∀ p ∈ Φ, p.Sorted Γ none) && c.check Φ goal

theorem Certificate.checkSorted_sound {Γ Φ goal c} (h : Certificate.checkSorted Γ Φ goal c = true) :
    goal.Sorted Γ none ∧ (∀ p ∈ Φ, p.Sorted Γ none) ∧ Entails Φ goal := by
  simp only [checkSorted,Bool.and_eq_true,decide_eq_true_eq] at h
  exact ⟨h.1.1,h.1.2,Certificate.sound h.2⟩


def Refutation.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx) : Refutation → Prop
  | .consume c | .derive _ c | .discardTodo c | .discardFact _ c => c.AdmissibleIn P C Γ
  | .cases l r | .split _ _ l r => l.AdmissibleIn P C Γ ∧ r.AdmissibleIn P C Γ
  | .builtin l c => l.predicate.Sorted Γ none ∧ l.predicate.Declared P C Γ none ∧ c.AdmissibleIn P C Γ
  | .closeLinear _ | .closeAtom _ _ => True

def Certificate.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (goal : Pred) : Certificate → Prop
  | .use _ => True
  | .leaf l => l.predicate.Sorted Γ none ∧ l.predicate.Declared P C Γ none
  | .substitute p t u eq c mode =>
      (∃ s, EqProof.substituteIn P C Γ Φ s mode p t u eq = true) ∧
        c.AdmissibleIn P C Γ Φ (p.open t)
  | .consume c => match Φ with
    | .and p q :: rest => c.AdmissibleIn P C Γ (p::q::rest) goal | _ => False
  | .cases l r => match Φ with
    | .or p q :: rest => l.AdmissibleIn P C Γ (p::rest) goal ∧ r.AdmissibleIn P C Γ (q::rest) goal
    | _ => False
  | .discard c => match Φ with
    | _::rest => c.AdmissibleIn P C Γ rest goal | [] => False
  | .refute r => r.AdmissibleIn P C Γ

/-- rawの成功と、全鍵の整数sort・宣言、途中の等号の適格性を分離しない。 -/
def Certificate.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (goal : Pred) (c : Certificate) : Bool := by
  classical
  exact c.check Φ goal && KeyTable.checkIn P C Γ (c.keys (Pred.ofConjuncts Φ) goal) &&
    decide (goal.Sorted Γ none ∧ goal.Declared P C Γ none ∧
      (∀ p ∈ Φ, p.Sorted Γ none ∧ p.Declared P C Γ none) ∧ c.AdmissibleIn P C Γ Φ goal)

theorem Certificate.checkIn_sound {P C Γ Φ goal c}
    (h : Certificate.checkIn P C Γ Φ goal c = true) :
    KeyTable.checkIn P C Γ (c.keys (Pred.ofConjuncts Φ) goal) = true ∧
      goal.Sorted Γ none ∧ goal.Declared P C Γ none ∧
      (∀ p ∈ Φ, p.Sorted Γ none ∧ p.Declared P C Γ none) ∧
      c.AdmissibleIn P C Γ Φ goal ∧ Entails Φ goal := by
  classical
  simp only [Certificate.checkIn, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨h.1.2,h.2.1,h.2.2.1,h.2.2.2.1,h.2.2.2.2,Certificate.sound h.1.1⟩

end
end Benitoite.Release.Refinement
