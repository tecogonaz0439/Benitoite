import Benitoite.Release.Refinement.CertificateKernelBind
import Benitoite.Release.Refinement.EqProofSyntax
import Benitoite.Release.Refinement.ClosedDecidable

/-! # 整数の等号を使える置換位置

構造の一致は全ての項位置に使える。整数射影の等値で変える自己は、
整数の比較と add/neg/scale の下に限る。
-/
namespace Benitoite.Release.Refinement

def Term.IntegerRewritePosition : Term → Prop
  | .var _ | .integer _ => True
  | .add a b => a.IntegerRewritePosition ∧ b.IntegerRewritePosition
  | .neg a | .scale _ a => a.IntegerRewritePosition
  | t => t.VarsIn (fun i => i ≠ 0)

def RewritePosition (p : Pred) (mode : EqualityMode) : Prop :=
  match mode with
  | .structural => True
  | .integer => match p with
    | .eq a b | .le a b | .lt a b => a.IntegerRewritePosition ∧ b.IntegerRewritePosition
    | .and p q | .or p q => RewritePosition p .integer ∧ RewritePosition q .integer
    | .not p => RewritePosition p .integer
    | p => p.VarsIn (fun i => i ≠ 0)

theorem Term.IntegerRewritePosition.sound {t : Term} (h : t.IntegerRewritePosition)
    (σ τ : ObservationEnv) (η : ObservationEnvModel)
    (zero : integerAs η ((σ 0).getD (.integer 0)) = integerAs η ((τ 0).getD (.integer 0)))
    (rest : ∀ i, i ≠ 0 → σ i = τ i) : integerAs η (termBind σ t) = integerAs η (termBind τ t) := by
  cases t with
  | var i => cases i with
    | zero => exact zero
    | succ i => simp only [termBind_var, rest (i+1) (by omega)]
  | integer _ => rfl
  | add a b =>
    rw [integerAs_bind_add, integerAs_bind_add, h.1.sound σ τ η zero rest, h.2.sound σ τ η zero rest]
  | neg a => rw [integerAs_bind_neg, integerAs_bind_neg, Term.IntegerRewritePosition.sound (t := a) h σ τ η zero rest]
  | scale c a => rw [integerAs_bind_scale, integerAs_bind_scale, Term.IntegerRewritePosition.sound (t := a) h σ τ η zero rest]
  | _ =>
    have he := Term.bind_congr (Term.varsIn_mono h rest)
    simp only [termBind, he]

theorem RewritePosition.integer_sound {p : Pred} (h : RewritePosition p .integer)
    (σ τ : ObservationEnv) (η : ObservationEnvModel)
    (zero : integerAs η ((σ 0).getD (.integer 0)) = integerAs η ((τ 0).getD (.integer 0)))
    (rest : ∀ i, i ≠ 0 → σ i = τ i) :
    (predBind σ p).interpret η = (predBind τ p).interpret η := by
  cases p with
  | eq a b | le a b | lt a b =>
    simp only [predBind, Pred.interpret, Pred.atomValue,
      h.1.sound σ τ η zero rest, h.2.sound σ τ η zero rest]
  | and p q | or p q =>
    simp only [predBind, Pred.interpret,
      h.1.integer_sound σ τ η zero rest, h.2.integer_sound σ τ η zero rest]
  | not p => simp only [predBind, Pred.interpret, RewritePosition.integer_sound (p := p) h σ τ η zero rest]
  | _ =>
    have he := Pred.bind_congr (Pred.varsIn_mono h rest)
    rw [he]

theorem RewritePosition.structural_sound (p : Pred) {t u : Term} (h : t = u) :
    p.open t = p.open u := congrArg p.open h

instance Term.integerRewritePositionDecidable (t : Term) : Decidable t.IntegerRewritePosition := by
  cases t <;> simp only [Term.IntegerRewritePosition]
  all_goals first
    | infer_instance
    | exact Term.integerRewritePositionDecidable _
    | exact @instDecidableAnd _ _ (Term.integerRewritePositionDecidable _) (Term.integerRewritePositionDecidable _)

instance rewritePositionDecidable (p : Pred) (mode : EqualityMode) : Decidable (RewritePosition p mode) := by
  cases mode with
  | structural => cases p <;> exact isTrue trivial
  | integer =>
    cases p <;> simp only [RewritePosition]
    all_goals first
      | infer_instance
      | exact rewritePositionDecidable _ .integer
      | exact @instDecidableAnd _ _ (rewritePositionDecidable _ .integer) (rewritePositionDecidable _ .integer)

def rewritePosition (p : Pred) (mode : EqualityMode) : Bool := decide (RewritePosition p mode)

theorem rewritePosition_spec (p : Pred) (mode : EqualityMode) :
    rewritePosition p mode = true ↔ RewritePosition p mode := decide_eq_true_iff

/-- 開いた述語の意味を、外側のνの上で等号に沿って移す。 -/
theorem EqProof.substitute_sound_at {Φ : List Pred} {mode : EqualityMode} {t u : Term} {c : EqProof}
    (h : c.checkRaw Φ mode t u = true) {p : Pred} (hp : rewritePosition p mode = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ q ∈ Φ, (predBind ν q).interpret η = true) :
    (predBind ν (p.open t)).interpret η = (predBind ν (p.open u)).interpret η := by
  cases mode with
  | structural => rw [EqProof.structural_sound h]
  | integer =>
    simp only [Pred.open, predBind_comp]
    apply RewritePosition.integer_sound ((rewritePosition_spec p .integer).mp hp)
    · exact EqProof.integer_sound_at h ν η facts
    · intro i hi
      cases i with
      | zero => contradiction
      | succ i => rfl

end Benitoite.Release.Refinement
