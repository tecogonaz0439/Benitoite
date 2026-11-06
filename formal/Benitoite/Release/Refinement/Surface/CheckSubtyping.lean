import Benitoite.Release.Refinement.Surface.CheckCompare
import Benitoite.Release.Refinement.ProofContract
import Benitoite.Release.Refinement.Patterns

/-! 部分型の有限な証明書を、構文の部分型判断へ接続する（設計書 01-12「部分型と被覆」）。 -/
namespace Benitoite.Release.Refinement.Surface.CheckSubtyping
open CheckCompare

/-- 論理の証明書と、関数ごとに選んだ上限で検査する基本操作の列。 -/
structure LogicCertificate where
  certificate : Certificate
  actions : List StepAccounting.Action

/-- 不正な証明書の拒否と、予算又は係数の表現による打ち切りを区別する。 -/
inductive Decision where
  | proved
  | unknown (reason : Option ProofStop)
  | rejected
  deriving DecidableEq, Repr

def Decision.isProved : Decision → Bool
  | .proved => true
  | .unknown _ | .rejected => false

private def classify : ProofResult → Decision
  | .proved _ => .proved
  | .unproved => .unknown none
  | .stopped .malformed => .rejected
  | .stopped reason => .unknown (some reason)

private theorem classify_proved (r : ProofResult) : (classify r).isProved = r.isProved := by
  cases r with
  | proved _ | unproved => rfl
  | stopped reason => cases reason <;> rfl

def LogicCertificate.result (limit : Nat) (Φ : List Pred) (goal : Pred) (c : LogicCertificate) : Decision :=
  classify (checkAccounted limit c.actions (Pred.ofConjuncts Φ) goal c.certificate)

/-- unknown は成功の証拠に変えない。 -/
def LogicCertificate.check (limit : Nat) (Φ : List Pred) (goal : Pred) (c : LogicCertificate) : Bool :=
  (c.result limit Φ goal).isProved

theorem LogicCertificate.sound {limit : Nat} {Φ : List Pred} {goal : Pred} {c : LogicCertificate} (h : c.check limit Φ goal = true) : Entails Φ goal := by
  simp only [check, result, classify_proved] at h
  obtain ⟨final, hf⟩ := checkAccounted_proved h
  exact Certificate.refutation_entails hf.checked

mutual
  /-- 部分型の導出の有限な案。型・論理の証明そのものは格納しない。 -/
  inductive LeCertificate where
    | refl (a : Ty)
    | convert (a b : Ty)
    | trans (first second : LeCertificate)
    | fnEffect (names : List String) (params : List Ty) (result : Ty) (inner outer : Eff)
    | list (element : LeCertificate)
    | lazy (element : LeCertificate)
    | mapValue (key : Ty) (value : LeCertificate)
    | forget (a : Ty) (predicate : Pred)
    | introduce (a : Ty) (predicate : Pred) (proof : LogicCertificate)
    | refine (base : LeCertificate) (premise goal : Pred) (proof : LogicCertificate)
    | dependentFn (signature : TelClosureCertificate)
    | scoped (name : OpaqueName) (kind : Scope.Domain.Kind) (inner outer : RangeIx)
    | scopedForget (name : OpaqueName) (kind : Scope.Domain.Kind) (index : RangeIx)
    | data (name : DataName) (args : TypeArgsCertificate)
  inductive TelCertificate where
    | done (result : LeCertificate) (inner outer : Eff)
    | param (name : String) (argument : LeCertificate) (rest : TelCertificate)
  inductive TelClosureCertificate where
    | refl (t : Tel)
    | tail (first : TelClosureCertificate) (last : TelCertificate)
  inductive TypeArgsCertificate where
    | nil
    | covariant (head : LeCertificate) (tail : TypeArgsCertificate)
    | contravariant (head : LeCertificate) (tail : TypeArgsCertificate)
    | invariant (left right : Ty) (tail : TypeArgsCertificate)
end

mutual
  def LeCertificate.source : LeCertificate → Ty
    | .refl a | .convert a _ | .introduce a _ _ => a
    | .forget a p => .refined a p
    | .trans c _ => c.source
    | .fnEffect ns ps r e _ => .fn ns ps r e
    | .list c => .list c.source
    | .lazy c => .lazy c.source
    | .mapValue k c => .map k c.source
    | .refine c p _ _ => .refined c.source p
    | .dependentFn c => .dependentFn c.source
    | .scoped o k i _ => .scoped o k i
    | .scopedForget o k i => .scoped o k i
    | .data d c => .data d c.source
  def LeCertificate.target : LeCertificate → Ty
    | .refl a => a
    | .convert _ b => b
    | .trans _ c => c.target
    | .fnEffect ns ps r _ e => .fn ns ps r e
    | .list c => .list c.target
    | .lazy c => .lazy c.target
    | .mapValue k c => .map k c.target
    | .forget a _ => a
    | .introduce a p _ => .refined a p
    | .refine c _ q _ => .refined c.target q
    | .dependentFn c => .dependentFn c.target
    | .scoped o k _ i => .scoped o k i
    | .scopedForget o _ i => .opaque o i
    | .data d c => .data d c.target
  def TelCertificate.source : TelCertificate → Tel
    | .done c e _ => .done c.source e
    | .param n c t => .param n c.target t.source
  def TelCertificate.target : TelCertificate → Tel
    | .done c _ e => .done c.target e
    | .param n c t => .param n c.source t.target
  def TelClosureCertificate.source : TelClosureCertificate → Tel
    | .refl t => t
    | .tail c _ => c.source
  def TelClosureCertificate.target : TelClosureCertificate → Tel
    | .refl t => t
    | .tail _ c => c.target
  def TypeArgsCertificate.source : TypeArgsCertificate → List Ty
    | .nil => []
    | .covariant c cs => c.source :: cs.source
    | .contravariant c cs => c.target :: cs.source
    | .invariant a _ cs => a :: cs.source
  def TypeArgsCertificate.target : TypeArgsCertificate → List Ty
    | .nil => []
    | .covariant c cs => c.target :: cs.target
    | .contravariant c cs => c.source :: cs.target
    | .invariant _ b cs => b :: cs.target
end


def TypeArgsCertificate.variances : TypeArgsCertificate → List Variance
  | .nil => []
  | .covariant _ cs => .covariant :: cs.variances
  | .contravariant _ cs => .contravariant :: cs.variances
  | .invariant _ _ cs => .invariant :: cs.variances

mutual
  /-- 比較で読む全ての注釈の有限支持。論理の証明の健全性は含まない。 -/
  def LeCertificate.Supported (s : List Atom) (c : LeCertificate) : Prop :=
    c.source.Support (· ∈ s) ∧ c.target.Support (· ∈ s) ∧ match c with
    | .trans a b => a.Supported s ∧ b.Supported s
    | .list a | .lazy a | .mapValue _ a | .refine a _ _ _ => a.Supported s
    | .dependentFn a => a.Supported s
    | .data _ a => a.Supported s
    | _ => True
  def TelCertificate.Supported (s : List Atom) (c : TelCertificate) : Prop :=
    c.source.Support (· ∈ s) ∧ c.target.Support (· ∈ s) ∧ match c with
    | .done c _ _ => c.Supported s
    | .param _ c t => c.Supported s ∧ t.Supported s
  def TelClosureCertificate.Supported (s : List Atom) (c : TelClosureCertificate) : Prop :=
    c.source.Support (· ∈ s) ∧ c.target.Support (· ∈ s) ∧ match c with
    | .refl _ => True
    | .tail c t => c.Supported s ∧ t.Supported s
  def TypeArgsCertificate.Supported (s : List Atom) (c : TypeArgsCertificate) : Prop :=
    Ty.SupportList (· ∈ s) c.source ∧ Ty.SupportList (· ∈ s) c.target ∧ match c with
    | .nil => True
    | .covariant c cs | .contravariant c cs => c.Supported s ∧ cs.Supported s
    | .invariant _ _ cs => cs.Supported s
end

mutual
  def LeCertificate.check (s : List Atom) (P : Refinement.Program) (Γ : Ctx) (Φ : List Pred)
      (limit : Nat) : LeCertificate → Bool
    | .refl _ | .forget _ _ | .scopedForget _ _ _ => true
    | .convert a b => normTyEq s a b
    | .trans c d => rawTyEq s c.target d.source && c.check s P Γ Φ limit && d.check s P Γ Φ limit
    | .fnEffect _ _ _ e f => effCovers s f e
    | .list c | .lazy c | .mapValue _ c => c.check s P Γ Φ limit
    | .introduce a p proof => decide (p.Sorted Γ (some a)) && proof.check limit (assumptions Γ Φ a) p
    | .refine c p q proof => c.check s P Γ Φ limit && decide (p.Sorted Γ (some c.source)) &&
        decide (q.Sorted Γ (some c.target)) && proof.check limit (p :: assumptions Γ Φ c.source) q
    | .dependentFn c => c.check s P Γ Φ limit
    | .scoped _ _ i j => decide (j.Covers i)
    | .data d cs => decide (cs.variances = P.varianceFor d cs.source.length) && cs.check s P Γ Φ limit
  def TelCertificate.check (s : List Atom) (P : Refinement.Program) (Γ : Ctx) (Φ : List Pred)
      (limit : Nat) : TelCertificate → Bool
    | .done c e f => c.check s P Γ Φ limit && effCovers s f e
    | .param _ c t => c.check s P Γ Φ limit && t.check s P (Γ.extend c.source) (Φ.map Pred.lift) limit
  def TelClosureCertificate.check (s : List Atom) (P : Refinement.Program) (Γ : Ctx) (Φ : List Pred)
      (limit : Nat) : TelClosureCertificate → Bool
    | .refl _ => true
    | .tail c t => rawTelEq s c.target t.source && c.check s P Γ Φ limit && t.check s P Γ Φ limit
  def TypeArgsCertificate.check (s : List Atom) (P : Refinement.Program) (Γ : Ctx) (Φ : List Pred)
      (limit : Nat) : TypeArgsCertificate → Bool
    | .nil => true
    | .covariant c cs | .contravariant c cs => c.check s P Γ Φ limit && cs.check s P Γ Φ limit
    | .invariant a b cs => normTyEq s a b && cs.check s P Γ Φ limit
end

theorem LeCertificate.source_supported {s : List Atom} {c : LeCertificate} (h : c.Supported s) :
    (c.source).Support (· ∈ s) := by
  cases c <;> exact h.1

theorem LeCertificate.target_supported {s : List Atom} {c : LeCertificate} (h : c.Supported s) :
    (c.target).Support (· ∈ s) := by
  cases c <;> exact h.2.1

theorem TelCertificate.source_supported {s : List Atom} {c : TelCertificate} (h : c.Supported s) :
    (c.source).Support (· ∈ s) := by
  cases c <;> exact h.1



theorem TelClosureCertificate.target_supported {s : List Atom} {c : TelClosureCertificate} (h : c.Supported s) :
    (c.target).Support (· ∈ s) := by
  cases c <;> exact h.2.1




mutual
  theorem LeCertificate.sound {s : List Atom} {P : Refinement.Program} {Γ : Ctx} {Φ : List Pred} {limit : Nat} {c : LeCertificate} (hs : c.Supported s)
      (h : c.check s P Γ Φ limit = true) : Ty.LeQ P Γ Φ c.source c.target := by
    cases c with
    | refl a => exact .refl
    | convert a b => exact .convert ((normTyEq_spec hs.1 hs.2.1).mp h)
    | trans c d =>
      simp only [LeCertificate.check, Bool.and_eq_true] at h
      have eq := (rawTyEq_spec (LeCertificate.target_supported hs.2.2.1) (LeCertificate.source_supported hs.2.2.2)).mp h.1.1
      have hd := LeCertificate.sound hs.2.2.2 h.2
      rw [← eq] at hd
      exact .trans (LeCertificate.sound (c := c) hs.2.2.1 h.1.2) hd
    | fnEffect ns ps r e f => exact .fn_effect (effCovers_sound hs.1.2.2 ((Eff.support_iff _).mp hs.2.1.2.2).2 h)
    | list c => exact .list (LeCertificate.sound hs.2.2 h)
    | lazy c => exact .lazy (LeCertificate.sound hs.2.2 h)
    | mapValue k c => exact .map_value rfl (LeCertificate.sound hs.2.2 h)
    | forget a p => exact .forget
    | introduce a p proof =>
      simp only [LeCertificate.check, Bool.and_eq_true, decide_eq_true_eq] at h
      exact .introduce h.1 (LogicCertificate.sound h.2)
    | refine c p q proof =>
      simp only [LeCertificate.check, Bool.and_eq_true, decide_eq_true_eq] at h
      exact .refine (LeCertificate.sound hs.2.2 h.1.1.1) h.1.1.2 h.1.2 (LogicCertificate.sound h.2)
    | dependentFn c => exact .dependentFn (TelClosureCertificate.sound hs.2.2 h)
    | «scoped» o k i j => exact .scoped (of_decide_eq_true h)
    | scopedForget o k i => exact .scoped_forget
    | data d cs =>
      simp only [LeCertificate.check, Bool.and_eq_true, decide_eq_true_eq] at h
      have hc := TypeArgsCertificate.sound hs.2.2 h.2
      rw [h.1] at hc
      exact .data hc
  theorem TelCertificate.sound {s : List Atom} {P : Refinement.Program} {Γ : Ctx} {Φ : List Pred} {limit : Nat} {c : TelCertificate} (hs : c.Supported s)
      (h : c.check s P Γ Φ limit = true) : TelLe P Γ Φ c.source c.target := by
    cases c with
    | done c e f =>
      simp only [TelCertificate.check, Bool.and_eq_true] at h
      exact .done (LeCertificate.sound hs.2.2 h.1) (effCovers_sound hs.1.2 ((Eff.support_iff _).mp hs.2.1.2).2 h.2)
    | param n c t =>
      simp only [TelCertificate.check, Bool.and_eq_true] at h
      exact .param (LeCertificate.sound hs.2.2.1 h.1) (TelCertificate.sound hs.2.2.2 h.2)
  theorem TelClosureCertificate.sound {s : List Atom} {P : Refinement.Program} {Γ : Ctx} {Φ : List Pred} {limit : Nat} {c : TelClosureCertificate} (hs : c.Supported s)
      (h : c.check s P Γ Φ limit = true) : TelClosure P Γ Φ c.source c.target := by
    cases c with
    | refl t => exact .refl
    | tail c t =>
      simp only [TelClosureCertificate.check, Bool.and_eq_true] at h
      have eq := (rawTelEq_spec (TelClosureCertificate.target_supported hs.2.2.1) (TelCertificate.source_supported hs.2.2.2)).mp h.1.1
      have ht := TelCertificate.sound hs.2.2.2 h.2
      rw [← eq] at ht
      exact .tail (TelClosureCertificate.sound (c := c) hs.2.2.1 h.1.2) ht
  theorem TypeArgsCertificate.sound {s : List Atom} {P : Refinement.Program} {Γ : Ctx} {Φ : List Pred} {limit : Nat} {c : TypeArgsCertificate} (hs : c.Supported s)
      (h : c.check s P Γ Φ limit = true) : TypeArgsLe P Γ Φ c.variances c.source c.target := by
    cases c with
    | nil => exact .nil
    | covariant c cs =>
      simp only [TypeArgsCertificate.check, Bool.and_eq_true] at h
      exact .covariant_cons (LeCertificate.sound hs.2.2.1 h.1) (TypeArgsCertificate.sound hs.2.2.2 h.2)
    | contravariant c cs =>
      simp only [TypeArgsCertificate.check, Bool.and_eq_true] at h
      exact .contravariant_cons (LeCertificate.sound hs.2.2.1 h.1) (TypeArgsCertificate.sound hs.2.2.2 h.2)
    | invariant a b cs =>
      simp only [TypeArgsCertificate.check, Bool.and_eq_true] at h
      exact .invariant_cons ((normTyEq_spec hs.1.1 hs.2.1.1).mp h.1)
        (TypeArgsCertificate.sound hs.2.2 h.2)
end

/-- 型の両端を照合し、別の型に対する証明書を流用しない。 -/
def LeCertificate.checkAs (s : List Atom) (P : Refinement.Program) (Γ : Ctx) (Φ : List Pred)
    (limit : Nat) (a b : Ty) (c : LeCertificate) : Bool :=
  rawTyEq s a c.source && rawTyEq s b c.target && c.check s P Γ Φ limit

theorem LeCertificate.checkAs_sound {s : List Atom} {P : Refinement.Program} {Γ : Ctx} {Φ : List Pred}
    {limit : Nat} {a b : Ty} {c : LeCertificate}
    (ha : a.Support (· ∈ s)) (hb : b.Support (· ∈ s)) (hs : c.Supported s)
    (h : c.checkAs s P Γ Φ limit a b = true) : Ty.LeQ P Γ Φ a b := by
  simp only [checkAs, Bool.and_eq_true] at h
  have hca := (rawTyEq_spec ha (LeCertificate.source_supported hs)).mp h.1.1
  have hcb := (rawTyEq_spec hb (LeCertificate.target_supported hs)).mp h.1.2
  rw [hca, hcb]
  exact LeCertificate.sound hs h.2

namespace Examples

private def singletonPredicate : Pred := .eq (.var 0) (.integer 1)
private def hypothesisCertificate : LogicCertificate := ⟨.use 0, [.work .checkCertificate .node]⟩

example : hypothesisCertificate.result 1 [singletonPredicate] singletonPredicate = .proved ∧
    hypothesisCertificate.result 0 [singletonPredicate] singletonPredicate = .unknown (some .stepsExhausted) ∧
    hypothesisCertificate.result 1 [singletonPredicate] .falsity = .rejected := by
  exact ⟨rfl, rfl, rfl⟩
private def identityCertificate : LeCertificate :=
  .refine (.refl (.base .integer)) singletonPredicate singletonPredicate
    ⟨.use 0, [.work .checkCertificate .node]⟩

/-- 同じ含意の証明書でも、関数で選んだ上限を使い切れば成功しない。 -/
example (P : Refinement.Program) :
    identityCertificate.check [] P [] [] 1 = true ∧
      identityCertificate.check [] P [] [] 0 = false := by
  constructor <;> rfl

example (P : Refinement.Program) :
    Ty.LeQ P [] [] (.refined (.base .integer) singletonPredicate)
      (.refined (.base .integer) singletonPredicate) :=
  identityCertificate.sound (s := []) (limit := 1) (by exact ⟨trivial, trivial, ⟨trivial, trivial, trivial⟩⟩) (by rfl)

/-- 正常な整数 1 は、証明書の始域の篩を満たす。 -/
example (P : Refinement.Program) :
    Inhabits P (.refined (.base .integer) singletonPredicate) (.const (.integer ⟨1, by decide⟩)) := by
  refine Inhabits.refined (Inhabits.const (c := .integer ⟨1, by decide⟩)) ?_
  intro h
  simp [singletonPredicate, Pred.evalWith, Pred.atomReady, Pred.atomValue,
    termReady, integerAs, observeAs, selfModel, selfObservation, Val.toTerm?, Term.observe,
    Term.interpret, Observation.sort, Integer64Value.toInt] at h

end Examples

end Benitoite.Release.Refinement.Surface.CheckSubtyping
