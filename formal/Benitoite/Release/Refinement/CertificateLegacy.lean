import Benitoite.Release.Refinement.CertificateKernel
import Benitoite.Release.Refinement.EqProofTransport

/-! # 構造等号を使う旧六場合の成功の保存 -/
namespace Benitoite.Release.Refinement
noncomputable section

inductive Certificate.Legacy where
  | use (index : Nat)
  | leaf (value : PreparedLeaf)
  | substitute (predicate : Pred) (left right : Term) (eq : EqProof) (proof : Certificate.Legacy)
  | consume (next : Certificate.Legacy)
  | cases (left right : Certificate.Legacy)
  | discard (next : Certificate.Legacy)

def Certificate.Legacy.check (Φ : List Pred) (goal : Pred) : Certificate.Legacy → Bool
  | .use i => Φ[i]? == some goal
  | .leaf l => decide (l.predicate = goal) && l.check
  | .substitute p t u eq c => decide (goal = p.open u) && eq.check t u && c.check Φ (p.open t)
  | .consume c => match Φ with
    | .and p q :: rest => c.check (p::q::rest) goal
    | _ => false
  | .cases l r => match Φ with
    | .or p q :: rest => l.check (p::rest) goal && r.check (q::rest) goal
    | _ => false
  | .discard c => match Φ with
    | _::rest => c.check rest goal
    | [] => false

def Certificate.Legacy.embed : Certificate.Legacy → Certificate
  | .use i => .use i
  | .leaf l => .leaf l
  | .substitute p t u eq c => .substitute p t u eq c.embed .structural
  | .consume c => .consume c.embed
  | .cases l r => .cases l.embed r.embed
  | .discard c => .discard c.embed

theorem PreparedLeaf.raw_of_check {l : PreparedLeaf} (h : l.check = true) (Φ : List Pred) :
    l.checkRaw Φ = true := by
  cases he : l.lemma <;> simp_all [PreparedLeaf.check, PreparedLeaf.checkRaw]
  have hh := h.2
  split at hh <;> simp_all

theorem Certificate.Legacy.success_preserved {c : Certificate.Legacy} {Φ : List Pred} {goal : Pred}
    (h : c.check Φ goal = true) : c.embed.check Φ goal = true := by
  induction c generalizing Φ goal with
  | use i =>
    have hi : Φ[i]? = some goal := by simpa only [check, beq_iff_eq] using h
    simp only [embed, Certificate.check, hi, predEq_spec]
  | leaf l =>
    simp only [check, Bool.and_eq_true, decide_eq_true_eq] at h
    simp only [embed, Certificate.check, Bool.and_eq_true, predEq_spec]
    exact ⟨h.1, PreparedLeaf.raw_of_check h.2 Φ⟩
  | substitute p t u eq c ih =>
    simp only [check, Bool.and_eq_true, decide_eq_true_eq] at h
    simp only [embed, Certificate.check, Bool.and_eq_true, predEq_spec]
    refine ⟨⟨⟨h.1.1, ?_⟩, ?_⟩, ih h.2⟩
    · rw [EqProof.structural_check_context Φ []]
      exact h.1.2
    · exact (rewritePosition_spec p .structural).mpr (by cases p <;> trivial)
  | consume c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check, Bool.false_eq_true] at h
      exact ih h
  | cases l r ihl ihr =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check, Bool.false_eq_true] at h
      simp only [Bool.and_eq_true] at h
      simp only [embed, Certificate.check, Bool.and_eq_true]
      exact ⟨ihl h.1,ihr h.2⟩
  | discard c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest => exact ih h

end
end Benitoite.Release.Refinement
