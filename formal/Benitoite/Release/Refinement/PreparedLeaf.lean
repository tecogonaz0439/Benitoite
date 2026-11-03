import Benitoite.Release.Refinement.Certificate
import Benitoite.Release.Refinement.Basic
import Benitoite.Release.Refinement.Transport
import Benitoite.Release.Refinement.MeasureContracts
import Benitoite.Release.Refinement.ExternalObservation

/-! # 型付きの葉と本番の部分型への接続 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 生の規則、文脈と経路、全引数の sort と宣言を同じ入口で照合する。 -/
def PreparedLeaf.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (l : PreparedLeaf) : Bool := by
  classical
  exact (Certificate.leaf l).checkIn P C Γ (Γ.facts ++ Φ) l.predicate &&
    decide (∀ t ∈ l.arguments, ∃ s, t.AdmissibleIn P C Γ s)

theorem PreparedLeaf.entailsIn {P : Program} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred} {l : PreparedLeaf} (h : l.checkIn P C Γ Φ = true) :
    Entails (Γ.facts ++ Φ) l.predicate := by
  simp only [PreparedLeaf.checkIn, Bool.and_eq_true] at h
  exact (Certificate.checkIn_sound h.1).2.2.2.2.2

theorem PreparedLeaf.bind_entails {P : Program} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred} {l : PreparedLeaf} (h : l.checkIn P C Γ Φ = true) (ν : ObservationEnv) :
    Entails ((Γ.facts ++ Φ).map (predBind ν)) (predBind ν l.predicate) :=
  (PreparedLeaf.entailsIn h).bind ν

theorem checked_refinement {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {p q : Pred} {c : Certificate}
    (hab : Ty.LeQ P Γ Φ a b)
    (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
    (hc : CertificateKernel.check (Pred.ofConjuncts (p :: assumptions Γ Φ a)) q c = true) :
    Ty.LeQ P Γ Φ (.refined a p) (.refined b q) :=
  .refine hab hp hq (Certificate.refutation_entails hc)

/-- 値から得た閉じた項は、snapshot の None を保ったまま観測できる。 -/
theorem Val.toTerm_observed {v : Val} {t : Term} {s : «Sort»}
    (ht : v.toTerm? = some t) (hs : t.HasSort [] s) (η : ObservationEnvModel) :
    ∃ o, t.observe η = some o ∧ o.sort = s := by
  cases v with
  | const c =>
    cases c <;> simp only [Val.toTerm?, Option.some.injEq] at ht <;> cases ht
    all_goals exact ⟨_, rfl, hs.2.symm⟩
  | var i =>
    cases ht
    obtain ⟨a, hi, _⟩ := hs.1
    simp at hi
  | _ =>
    simp only [Val.toTerm?, Option.some.injEq] at ht
    cases ht <;> exact ⟨_, rfl, hs.2.symm⟩

/-- 閉じた型付きの値の実観測から、正常 measure の三条件を構成する。 -/
theorem HasTypeVQ.observed_measure {P B Ψ Q C Φ v a m o n}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v a) (sort : a.carrier.HasSort m.input)
    (η : ObservationEnvModel)
    (observed : v.toTerm?.bind (Term.observe η) = some o)
    (normal : Observation.measure m o = some (.integer n)) :
    ∃ t, v.toTerm? = some t ∧ t.HasSort [] m.input ∧ t.Closed ∧
      (Term.measure m t).observe η = some (.integer n) ∧
      (Term.measure m t).interpret η = some (.integer n) ∧ 0 ≤ n ∧
      ∀ (ν : ObservationEnv) (ξ : ObservationEnvModel),
        (∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) →
        (Term.measure m (termBind ν t)).observe ξ = some (.integer n) := by
  obtain ⟨t, ht, hs, closed⟩ := typed.represented sort
  rw [ht, Option.bind_some] at observed
  obtain ⟨ho, hi, nonnegative⟩ := measure_machine_exact normal η t observed
  exact ⟨t, ht, hs, closed, ho, hi, nonnegative, fun ν ξ info => measure_stable ν η ξ info ho⟩

end
end Benitoite.Release.Refinement
