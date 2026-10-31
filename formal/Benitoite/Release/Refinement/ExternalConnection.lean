import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ExternalObservation

namespace Benitoite.Release.Refinement
noncomputable section

theorem externalReceive_of_args {P B Ψ d ts vs a e out}
    (h : ExternalArgs P B Ψ d ts vs a e) :
    externalReceive P d ts vs out = some (externalCheckedOutcome P a out) := by
  simp [externalReceive,h.instantiate]

/-- 三条件から受信後の型付け・no-exit・無対象を一緒に取り出す。 -/
theorem Builtins.ExternalAssumptions.receive {P B Ψ f d ts vs a e out obs}
    (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
    (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
    (hr : B.externalResponse f ts vs out obs) :
    ∃ checked, externalReceive P d ts vs out = some checked ∧ Outcome.Typed P B Ψ checked a ∧
      (∀ n : Int, checked ≠ .exit n) ∧ obs = [] :=
  ⟨_,externalReceive_of_args ha,h.checked_typed hw hd ha hr⟩

/-- 第四の信頼条件を置かず、carrierの値構造から全σで適格性を得る。 -/
theorem Builtins.ExternalAssumptions.external_adequate {P B Ψ f d ts vs a e out obs}
    (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
    (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
    (hr : B.externalResponse f ts vs out obs) (σ : PathEnv) : Outcome.Adequate σ out := by
  have hc := (h.external_typed Ψ f d ts vs a e out obs hw hd ha hr).1
  cases out with
  | val v => exact hc.1.adequate σ
  | err _ | exit _ => trivial

/-- 受信が正常値を返したとき、元の結果型と閉性・適格性を三条件から得る。 -/
theorem Builtins.ExternalAssumptions.received_value {P B Ψ f d ts vs a e out obs v}
    (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
    (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
    (hr : B.externalResponse f ts vs out obs)
    (hrec : externalReceive P d ts vs out = some (.val v)) (σ : PathEnv) :
    HasTypeV P B Ψ [] [] [] v a ∧ v.Ground ∧ v.Adequate σ := by
  obtain ⟨c,hc,ht,_,_⟩ := h.receive hw hd ha hr
  rw [hc] at hrec
  cases hrec
  have hadq := h.external_adequate hw hd ha hr σ
  rw [externalReceive_of_args ha] at hc
  have hce := Option.some.inj hc
  cases out with
  | val w =>
    by_cases hx : externalCheck P w a = true
    · simp only [externalCheckedOutcome,hx,↓reduceIte] at hce
      cases hce
      exact ⟨ht.1,ht.2,hadq⟩
    · simp [externalCheckedOutcome,hx] at hce
  | err r => simp [externalCheckedOutcome] at hce
  | exit n => simp [externalCheckedOutcome] at hce

/-- 生の応答のno-exitを受信後の結果にも適用する。 -/
theorem Builtins.ExternalAssumptions.receive_no_exit {P B Ψ f d ts vs a e out obs n}
    (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
    (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
    (hr : B.externalResponse f ts vs out obs) :
    externalReceive P d ts vs out ≠ some (.exit n) := by
  obtain ⟨c,hc,_,hn,_⟩ := h.receive hw hd ha hr
  rw [hc]
  intro he
  exact hn n (Option.some.inj he)

theorem Step.external_accept {P B σ Ψ f d ts vs a e v obs q k μ}
    (ha : ExternalArgs P B Ψ d ts vs a e)
    (hq : q.view = .externalCall f ts vs) (hd : P.externalFunction f = some d)
    (hr : B.externalResponse f ts vs (.val v) obs) (hc : externalCheck P v a = true) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) := by
  apply Step.E_External hq hd hr
  rw [externalReceive_of_args ha]
  simp [externalCheckedOutcome,hc]

theorem Step.external_reject {P B σ Ψ f d ts vs a e v obs q k μ}
    (ha : ExternalArgs P B Ψ d ts vs a e)
    (hq : q.view = .externalCall f ts vs) (hd : P.externalFunction f = some d)
    (hr : B.externalResponse f ts vs (.val v) obs) (hc : externalCheck P v a = false) :
    Step P B σ (.run q k μ) none (.error ["ExternalRefinement"] k μ) := by
  apply Step.E_ExternalErr hq hd hr
  rw [externalReceive_of_args ha,externalCheckedOutcome_reject hc]

end
end Benitoite.Release.Refinement
