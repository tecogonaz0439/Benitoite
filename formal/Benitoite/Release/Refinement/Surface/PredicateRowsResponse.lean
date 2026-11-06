import Benitoite.Release.Refinement.Surface.PredicateRows

/-! # 特殊化した判定の依存する応答の型付け -/
namespace Benitoite.Release.Refinement.Surface.PredicateRows
open Scope.Domain PredicateResponse
noncomputable section

private theorem input_eval (entry : Entry) (valid : entry.Valid) (c : Const)
    (hc : c.type.norm.core = .base entry.input) :
    ∃ t, (Val.const c).toTerm? = some t ∧
      (entry.predicate t).evalClosed = some (entry.run [.const c]) := by
  cases entry with
  | path p =>
    cases c <;> cases hc
    refine ⟨_, rfl, ?_⟩
    exact Pred.evalClosed_stringMember (r := .path p) (Or.inl rfl) valid
      (by simp [RangeExpr.FitsKind, Range.FitsKind, Range.kind?]) rfl _
  | host p =>
    cases c <;> cases hc
    refine ⟨_, rfl, ?_⟩
    exact Pred.evalClosed_stringMember (r := .host p) (Or.inr rfl) valid
      (by simp [RangeExpr.FitsKind, Range.FitsKind, Range.kind?]) rfl _
  | characters lo hi =>
    cases c <;> cases hc
    exact ⟨_, rfl, characters_eval _ lo hi⟩
  | floating w test =>
    cases w <;> cases c <;> cases hc
    · exact ⟨_, rfl, float32_eval test _⟩
    · exact ⟨_, rfl, float64_eval test _⟩

private theorem argument_result {P B Ψ b ts es rs ws a e} (entry : Entry)
    (args : BuiltinArgs P B Ψ b entry.signature ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ e = Eff.empty ∧
      ∃ c t, ws = [.const c] ∧ c.type.norm.core = .base entry.input ∧
        (Val.const c).toTerm? = some t ∧ a = entry.result t := by
  have ht : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have he : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have hr : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [instantiated] at values
  cases values with
  | param ha hv tail =>
    obtain ⟨c, rfl, _, hc⟩ := hv.canonical_scalar rfl
    have ht : ∃ t, (Val.const c).toTerm? = some t := by
      cases entry <;> try (rename_i w test; cases w using FloatWidth.casesOn)
      all_goals cases c <;> cases hc
      all_goals exact ⟨_, rfl⟩
    obtain ⟨t, ht⟩ := ht
    have closed : t.Closed := Val.observation_wf (by trivial : (Val.const c).Ground) ht
    have htail : Tel.bind (Tel.argumentsEnv (.const c))
        (.done (entry.result (.var 1)) Eff.empty) = .done (entry.result t) Eff.empty := by
      change Tel.done (Ty.bind _ (entry.result (.var 1))) (Eff.bind _ Eff.empty) = _
      rw [result_bind]
      simp [Tel.argumentsEnv, valEnv, upValues, termBind, termBind?, ht,
        Term.bind_closed closed, Eff.bind, Eff.rawBind, Eff.norm, Eff.empty,
        substAtoms_nil, instAtoms_nil, rowFails]
    rw [htail] at tail
    cases tail with
    | done ha => exact ⟨rfl, rfl, rfl, rfl, c, t, rfl, hc, ht, rfl⟩

/-- 型付きの全入力で、結果の真偽は、同じ対象の述語と一致する篩を持つ。 -/
theorem response {P B Ψ b ts es rs ws a e} (entry : Entry) (valid : entry.Valid)
    (args : BuiltinArgs P B Ψ b entry.signature ts es rs ws a e) :
    ∃ out, entry.delta ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ ∀ n, out ≠ .exit n := by
  obtain ⟨rfl, rfl, rfl, rfl, c, t, rfl, hc, ht, rfl⟩ := argument_result entry args
  obtain ⟨u, hu, he⟩ := input_eval entry valid c hc
  cases ht.symm.trans hu
  have typed := BooleanResult.typed (B := B) (Ψ := Ψ) args.arguments.resultAnnotation (result_accepts entry he)
  exact ⟨.val (.const (.boolean (entry.run [.const c]))), by simp [Entry.delta],
    ⟨typed, trivial⟩, by intro σ _ _; trivial, by intro n; simp⟩

end
end Benitoite.Release.Refinement.Surface.PredicateRows
