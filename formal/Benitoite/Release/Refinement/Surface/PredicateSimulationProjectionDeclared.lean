import Benitoite.Release.Refinement.Surface.PredicateProjectionSpec
import Benitoite.Release.Refinement.ConstraintAssumptions

/-! # 内部署名が保持する欄の経路の宣言 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse PredicateProjection
noncomputable section

private theorem entry_term_declared {P C Γ self term} {entry : Entry}
    (declared : Pred.Declared P C Γ self (entry.predicate term)) :
    Term.Declared P C (Γ.declarationSelf self) term := by
  cases entry with
  | floating width test =>
    cases test <;> simp only [Entry.predicate,FloatTest.predicate,Pred.Declared] at declared
    all_goals first | exact declared | exact declared.1 | exact declared.2
  | path pattern => exact declared
  | host pattern => exact declared
  | characters minimum maximum => exact declared

private theorem input_shift (projection : Projection) (amount cutoff : Nat) :
    projection.input.shiftV amount cutoff = projection.input := by
  simp only [Projection.input,Ty.shiftV,shiftVTys_eq_map,List.map_map]
  rfl

/-- 形成された内部署名は、Booleanの自己値と受け手の文脈で同じ欄の経路を宣言する。 -/
theorem projection_route_declared {P} (projection : Projection)
    (formed : PrimSig.Scoped P projection.signature) :
    Term.Declared P projection.signature.tparams [some (.base .boolean),some projection.input]
      (routeTerm (.var 1) projection.route) := by
  have declared := formed.declared
  change Ty.Declared P projection.signature.tparams [] projection.input ∧
    (Ty.Declared P projection.signature.tparams (Ctx.extend [] projection.input)
      (projection.entry.result (routeTerm (.var 1) projection.route)) ∧ _) at declared
  have predicate : Pred.Declared P projection.signature.tparams (Ctx.extend [] projection.input)
      (some (.base .boolean)) (agreement (projection.entry.predicate (routeTerm (.var 1) projection.route))) :=
    declared.2.1.2
  have target := entry_term_declared predicate.1.2
  simpa only [Ctx.declarationSelf,Ctx.extend,List.map_nil,List.map_cons,Option.map_some,
    input_shift,Ty.shiftV] using target

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
