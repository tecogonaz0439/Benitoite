import Benitoite.Release.Refinement.EqCertificate
import Benitoite.Release.Refinement.CertificateSyntax
import Benitoite.Release.Refinement.VarianceValidation
import Benitoite.Release.Refinement.ClosedDecidable

/-! # 等号の端点と途中のsort・宣言の照合

宣言の適格性の判断は上層に置く。下層の有限検査と意味の健全性は、
宣言の検査結果を独立の信頼条件として使わない。
-/
namespace Benitoite.Release.Refinement

/-- すべてのsortで同じHasSortと宣言表を照合する。 -/
def Term.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx) (s : «Sort») (t : Term) : Prop :=
  t.HasSort Γ s ∧ t.Declared P C Γ

/-- 線形化の鍵の型付きの入口。rawの整数射影の入口とは区別する。 -/
noncomputable def KeyTable.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx) (keys : KeyTable) : Bool := by
  classical
  exact decide (P.VarianceValid ∧ ∀ t ∈ keys, t.AdmissibleIn P C Γ .integer)

theorem KeyTable.checkIn_sound {P C Γ keys} (h : KeyTable.checkIn P C Γ keys = true) :
    P.VarianceValid ∧ ∀ t ∈ keys, t.HasSort Γ .integer ∧ t.Declared P C Γ := by
  classical
  have hh : P.VarianceValid ∧ ∀ t ∈ keys, t.AdmissibleIn P C Γ .integer := of_decide_eq_true h
  exact hh

/-- 子のmodeとsortを固定し、transの中間を端点と同じ条件で検査する。 -/
def EqProof.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (s : «Sort») (mode : EqualityMode) (t u : Term) (c : EqProof) : Prop :=
  t.AdmissibleIn P C Γ s ∧ u.AdmissibleIn P C Γ s ∧
  (mode = .integer → s = .integer) ∧
  match c with
  | .refl | .hyp _ => True
  | .symm c => c.AdmissibleIn P C Γ s mode u t
  | .trans m l r => l.AdmissibleIn P C Γ s mode t m ∧ r.AdmissibleIn P C Γ s mode m u
  | .add l r => match t,u with
    | .add a b, .add c d => l.AdmissibleIn P C Γ .integer mode a c ∧ r.AdmissibleIn P C Γ .integer mode b d
    | _,_ => False
  | .neg c => match t,u with
    | .neg a, .neg b => c.AdmissibleIn P C Γ .integer .integer a b
    | _,_ => False
  | .scale _ c => match t,u with
    | .scale _ a, .scale _ b => c.AdmissibleIn P C Γ .integer .integer a b
    | _,_ => False
  | .field c => match t,u with
    | .field _ a, .field _ b => c.AdmissibleIn P C Γ .data .structural a b
    | _,_ => False
  | .measure c => match t,u with
    | .measure m a, .measure _ b => c.AdmissibleIn P C Γ m.input .structural a b
    | _,_ => False
termination_by structural c

noncomputable def EqProof.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (s : «Sort») (mode : EqualityMode) (t u : Term) (c : EqProof) : Bool := by
  classical
  exact c.checkRaw Φ mode t u && decide (c.AdmissibleIn P C Γ s mode t u ∧
    P.VarianceValid ∧ ∀ p ∈ Φ, p.Sorted Γ none ∧ p.Declared P C Γ none)

theorem EqProof.checkIn_sound {P C Γ Φ s mode t u c}
    (h : EqProof.checkIn P C Γ Φ s mode t u c = true) :
    EqProof.checkRaw Φ mode t u c = true ∧ EqProof.AdmissibleIn P C Γ s mode t u c ∧
      P.VarianceValid ∧ ∀ p ∈ Φ, p.Sorted Γ none ∧ p.Declared P C Γ none := by
  classical
  simpa only [checkIn, Bool.and_eq_true, decide_eq_true_eq, and_assoc] using h

theorem EqProof.integer_sound {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t u : Term} {c : EqProof}
    (h : EqProof.checkIn P C Γ Φ .integer .integer t u c = true) :
    ∀ η : ObservationEnvModel, (∀ p ∈ Φ, p.interpret η = true) → integerAs η t = integerAs η u := by
  intro η hf
  simpa only [termBind_id, predBind_id] using
    EqProof.integer_sound_at (EqProof.checkIn_sound h).1 (fun i => some (.var i)) η
      (by simpa only [predBind_id] using hf)

/-- substituteの前後の述語も同じ文脈・宣言表で検査する。 -/
noncomputable def EqProof.substituteIn (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (s : «Sort») (mode : EqualityMode) (p : Pred) (t u : Term) (c : EqProof) : Bool := by
  classical
  exact c.checkIn P C Γ Φ s mode t u && rewritePosition p mode &&
    decide ((p.open t).Sorted Γ none ∧ (p.open t).Declared P C Γ none ∧
      (p.open u).Sorted Γ none ∧ (p.open u).Declared P C Γ none)

theorem EqProof.substituteIn_sound_at {P C Γ Φ s mode p t u c}
    (h : EqProof.substituteIn P C Γ Φ s mode p t u c = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ q ∈ Φ, (predBind ν q).interpret η = true) :
    ((p.open t).Sorted Γ none ∧ (p.open t).Declared P C Γ none ∧
      (p.open u).Sorted Γ none ∧ (p.open u).Declared P C Γ none) ∧
      (predBind ν (p.open t)).interpret η = (predBind ν (p.open u)).interpret η := by
  classical
  simp only [substituteIn, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨h.2, EqProof.substitute_sound_at (EqProof.checkIn_sound h.1.1).1 h.1.2 ν η facts⟩

end Benitoite.Release.Refinement
