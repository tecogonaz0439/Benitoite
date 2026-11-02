import Benitoite.Release.Refinement.LinearSyntax

/-! # 置換の像の上で読む有限な算術規則

設計書 01-12「篩を含むコア計算の形式化」に対応する。
snapshot 内の部分観測を、モデルの整数射影との交換で代用しない。
-/
namespace Benitoite.Release.Refinement

theorem integerAs_eq_integerD (η : ObservationEnvModel) (t : Term) :
    integerAs η t = Observation.integerD (t.interpret η) := by
  unfold integerAs observeAs
  cases h : t.interpret η with
  | none => simp [Observation.default, Observation.integerD]
  | some o => cases o <;> simp [Observation.sort, Observation.default, Observation.integerD]

theorem integerAs_bind_add (η : ObservationEnvModel) (ν : ObservationEnv) (a b : Term) :
    integerAs η (termBind ν (.add a b)) =
      integerAs η (termBind ν a) + integerAs η (termBind ν b) := by
  simp only [termBind_add, integerAs_eq_integerD, Term.interpret, Observation.integerD]

theorem integerAs_bind_neg (η : ObservationEnvModel) (ν : ObservationEnv) (a : Term) :
    integerAs η (termBind ν (.neg a)) = -integerAs η (termBind ν a) := by
  simp only [termBind_neg, integerAs_eq_integerD, Term.interpret, Observation.integerD]

theorem integerAs_bind_scale (η : ObservationEnvModel) (ν : ObservationEnv) (c : Int) (a : Term) :
    integerAs η (termBind ν (.scale c a)) = c * integerAs η (termBind ν a) := by
  simp only [termBind_scale, integerAs_eq_integerD, Term.interpret, Observation.integerD]

theorem Pred.scaled_le_at (t : Term) {b k : Int} (hk : 0 ≤ k)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.le t (.integer b))).interpret η = true →
    (predBind ν (.le (.scale k t) (.integer (k*b)))).interpret η = true := by
  simp only [predBind, Pred.interpret, Pred.atomValue, decide_eq_true_eq]
  rw [integerAs_bind_scale]
  simp only [termBind_integer, integerAs_eq_integerD, Term.interpret, Observation.integerD]
  exact fun h => Int.mul_le_mul_of_nonneg_left h hk

theorem Pred.eq_positive_at (t n : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.and (.eq t n) (.lt (.integer 0) n))).interpret η = true →
    (predBind ν (.lt (.integer 0) t)).interpret η = true := by
  simp only [predBind, Pred.interpret, Pred.atomValue, Bool.and_eq_true, decide_eq_true_eq]
  intro h
  rw [h.1]
  exact h.2

theorem Pred.closed_sound_at {p : Pred} (hw : p.WF 0) (hs : p.Sorted [] none)
    (he : p.evalClosed = some true) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true := by
  rw [Pred.bind_closed hw ν, Pred.interpret_closed hw η]
  exact Pred.evalClosed_sound hw hs he

theorem Pred.opposite_at (p : Pred) (ν : ObservationEnv) (η : ObservationEnvModel) :
    ¬ ((predBind ν p).interpret η = true ∧ (predBind ν (.not p)).interpret η = true) := by
  simp [predBind, Pred.interpret]

theorem Pred.bind_implication_comp {p q : Pred}
    (h : ∀ (ν : ObservationEnv) (η : ObservationEnvModel),
      (predBind ν p).interpret η = true → (predBind ν q).interpret η = true)
    (σ τ : ObservationEnv) (η : ObservationEnvModel) :
    (predBind τ (predBind σ p)).interpret η = true →
      (predBind τ (predBind σ q)).interpret η = true := by
  simp only [predBind_comp]
  exact h _ η

end Benitoite.Release.Refinement
