import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs

/-! # 実際の解決が保つ、呼出しの頭と直接値の構文 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem projected_no_head {rows source entry expression output}
    (resolved : PredicateProjectionCalls.resolve rows source entry expression = some output) :
    directCallee output = none ∧ output.valueOf? = none := by
  unfold PredicateProjectionCalls.resolve at resolved
  obtain ⟨parsed, parse, resolved⟩ := Option.bind_eq_some_iff.mp resolved
  obtain ⟨pair, candidate, resolved⟩ := Option.bind_eq_some_iff.mp resolved
  rcases pair with ⟨projection, types⟩
  obtain ⟨key, lookup, resolved⟩ := Option.bind_eq_some_iff.mp resolved
  obtain ⟨term, observed, resolved⟩ := Option.bind_eq_some_iff.mp resolved
  cases resolved
  exact ⟨rfl, rfl⟩

private theorem scalar_no_head {key entry expression output}
    (resolved : PredicateCalls.resolvedCall key entry expression = some output) :
    directCallee output = none ∧ output.valueOf? = none := by
  obtain ⟨value, term, parsed, observed, encoded, rest⟩ := PredicateCalls.resolvedCall_desugar resolved (fun _ _ => none) .other
  cases encoded
  exact ⟨rfl, rfl⟩

/-- 元の公開呼出しを解決しても、裸の頭や直接値の構文は新しく作らない。 -/
theorem resolveCall_no_head (rows : PredicateProjection.Table.Rows) (source : Program) (name : PrimName)
    (labels : List (Option String)) (positions : List Nat) (arguments : Exprs) :
    directCallee (PredicateProjectionCalls.resolveCall rows source name labels positions arguments) = none ∧
      (PredicateProjectionCalls.resolveCall rows source name labels positions arguments).valueOf? = none := by
  unfold PredicateProjectionCalls.resolveCall
  split
  · exact ⟨rfl, rfl⟩
  · split
    · split
      · exact ⟨rfl, rfl⟩
      · rename_i entry target identified
        cases projected : PredicateProjectionCalls.resolve rows source entry target with
        | some output =>
          simpa only [Option.orElse, Option.getD] using projected_no_head projected
        | none =>
          cases selectedKey : PredicateProjectionCalls.scalarName rows entry with
          | none => simp only [Option.orElse, Option.bind, Option.getD]; exact ⟨rfl, rfl⟩
          | some key =>
            cases scalar : PredicateCalls.resolvedCall key entry target with
            | none => simp only [Option.orElse, Option.bind, Option.getD, scalar]; exact ⟨rfl, rfl⟩
            | some output => simpa only [Option.orElse, Option.bind, Option.getD, scalar] using scalar_no_head scalar
    · exact ⟨rfl, rfl⟩

/-- 再帰的な解決は、通常の脱糖が選ぶ直接の呼出しの頭を保つ。 -/
theorem resolveExpr_directCallee (rows : PredicateProjection.Table.Rows) (source : Program) (expression : Expr) :
    directCallee (PredicateProjectionCalls.resolveExpr rows source expression) = directCallee expression := by
  cases expression <;> try rfl
  case tryResultDie type ok err dict showMethod exit inner message => cases message <;> rfl
  case tryOptionDie type someCon noneCon exit inner message => cases message <;> rfl
  case call head labels positions arguments =>
    cases head <;> try rfl
    case primName name types effects ranges =>
      cases types <;> cases effects <;> cases ranges <;> try rfl
      exact (resolveCall_no_head rows source name labels positions _).1

/-- 再帰的な解決は、valueOf?が直接読む元の値を保つ。 -/
theorem resolveExpr_valueOf (rows : PredicateProjection.Table.Rows) (source : Program) (expression : Expr) :
    (PredicateProjectionCalls.resolveExpr rows source expression).valueOf? = expression.valueOf? := by
  cases expression <;> try rfl
  case tryResultDie type ok err dict showMethod exit inner message => cases message <;> rfl
  case tryOptionDie type someCon noneCon exit inner message => cases message <;> rfl
  case call head labels positions arguments =>
    cases head <;> try rfl
    case primName name types effects ranges =>
      cases types <;> cases effects <;> cases ranges <;> try rfl
      exact (resolveCall_no_head rows source name labels positions _).2

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
