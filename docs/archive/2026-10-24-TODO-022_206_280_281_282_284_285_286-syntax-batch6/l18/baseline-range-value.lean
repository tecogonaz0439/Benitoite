import Benitoite.Interval.Range
open Benitoite.Interval Benitoite.Release
namespace L18Baseline
inductive EvalStandard : StandardRule → OperationKey → List ConcreteValue →
    OperationResult → Prop where
  | rangeCheck (names key lo hi value) :
      EvalStandard (.rangeCheck names) key [.integer lo, .integer hi, .integer value]
        (rangeCheck names key lo hi value)
  | rangeValue (owner key origin value) (bounded :
      min64 ≤ value.value ∧ value.value ≤ max64) :
      EvalStandard (.rangeValue owner) key [.checkedRange owner origin value]
        (.normal (.integer ⟨value.value, bounded⟩))
  | domainNormal (position lo hi result key args value output)
      (atPosition : args[position]? = some (.integer value))
      (inside : lo ≤ value.toInt ∧ value.toInt ≤ hi)
      (typed : output.type = result) :
      EvalStandard (.fixedDomain position lo hi result) key args (.normal output)
  | domainOtherFailure (position lo hi result key args value)
      (atPosition : args[position]? = some (.integer value))
      (inside : lo ≤ value.toInt ∧ value.toInt ≤ hi) :
      EvalStandard (.fixedDomain position lo hi result) key args (.rejected .unknown)
  | domainRejected (position lo hi result key args value)
      (atPosition : args[position]? = some (.integer value))
      (outside : ¬ (lo ≤ value.toInt ∧ value.toInt ≤ hi)) :
      EvalStandard (.fixedDomain position lo hi result) key args (.rejected .outsideDomain)


example (owner : OpaqueName) (key : OperationKey) (value : Integer64Value) :
    ¬ EvalStandard (.rangeValue owner) key [.other (.opaque owner) rfl (by simp) (by simp)]
      (.normal (.integer value)) := by
  intro evaluated
  cases evaluated
end L18Baseline

example (owner : OpaqueName) (key : OperationKey) (value : Integer64Value) :
    Benitoite.Interval.EvalStandard (.rangeValue owner) key
      [.other (.opaque owner) rfl (by simp) (by simp)] (.normal (.integer value)) :=
  range_other_possible owner key value
