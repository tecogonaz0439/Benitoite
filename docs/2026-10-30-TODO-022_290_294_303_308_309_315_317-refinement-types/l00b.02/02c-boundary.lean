import Benitoite

namespace SharedBoundary
open Benitoite

/-- 共有近似を使う後続段は、同じ数でも整数の幅を混同できない。 -/
theorem distinct_widths :
    ¬ (Shared.ValueApprox.integer .integer8 (Interval.top .integer8)).Mem
      (.integer .integer16 ⟨7, by decide⟩) ∧
    (Shared.ValueApprox.integer .integer8 (Interval.top .integer8)).Mem
      (.integer .integer8 ⟨127, by decide⟩) ∧
    (Shared.ValueApprox.integer .unsignedInteger64 (Interval.top .unsignedInteger64)).Mem
      (.integer .unsignedInteger64 ⟨18446744073709551615, by decide⟩) := by
  constructor
  · intro h; cases h.1
  · constructor <;> exact ⟨rfl, by decide⟩

/-- 旧構文の不正な幅の値は新しい有界整数の証拠へ化けない。 -/
theorem legacy_width_boundary :
    (Release.Val.const (.integer8 128)).toApprox = .other ∧
    (Release.Val.const (.unsignedInteger16 (-1))).toApprox = .other ∧
    (Release.Refinement.embedVal (.const (.integer8 127))).toApprox =
      .integer .integer8 ⟨127, by decide⟩ := by
  repeat constructor
  all_goals simp

/-- 共有の二成分に異なる種類の値を置き、結果の種別を入れ替えたら所属しない。 -/
theorem separate_results :
    let flow : Shared.FlowApprox :=
      ⟨.boolean false true, .integer .integer8 (Interval.normalize 7 7 .integer8), false⟩
    flow.ResultMem (E := Interval.Failure) (.normal (.boolean true)) ∧
    flow.ResultMem (E := Interval.Failure) (.returned (.integer .integer8 ⟨7, by decide⟩)) ∧
    ¬ flow.ResultMem (E := Interval.Failure) (.normal (.integer .integer8 ⟨7, by decide⟩)) ∧
    ¬ flow.ResultMem (E := Interval.Failure) (.returned (.boolean true)) ∧
    ¬ flow.ResultMem (.failed Interval.Failure.overflow) := by
  dsimp [Shared.FlowApprox.ResultMem, Shared.FlowApprox.NormalMem,
    Shared.FlowApprox.ReturnedMem, Shared.ValueApprox.Mem]
  repeat constructor
  all_goals simp

/-- 独立評価からの三つの結果は、失敗の理由も含めて別々に写る。 -/
theorem evaluator_bridge :
    (Interval.EvalOutcome.normal (.boolean true)).toApprox = .normal (.boolean true) ∧
    (Interval.EvalOutcome.returned (.integer8 ⟨7, by decide⟩)).toApprox =
      .returned (.integer .integer8 ⟨7, by decide⟩) ∧
    (Interval.EvalOutcome.failed (.outOfRange 1 9 10)).toApprox =
      .failed (.outOfRange 1 9 10) := by
  repeat constructor
  all_goals simp

/-- 元の解析は Boolean、戻り値は整数の近似を渡し、両者を別々に所属させる。 -/
theorem old_flow_bridge :
    let old : Interval.FlowApprox (.base .boolean) := ⟨(false, true), false, []⟩
    let returned := Shared.ValueApprox.integer .integer8 (Interval.normalize 7 7 .integer8)
    (old.toShared returned).NormalMem (.boolean true) ∧
    (old.toShared returned).ReturnedMem (.integer .integer8 ⟨7, by decide⟩) ∧
    ¬ (old.toShared returned).NormalMem (.integer .integer8 ⟨7, by decide⟩) := by
  dsimp [Interval.FlowApprox.toShared, Interval.normalToShared,
    Shared.FlowApprox.NormalMem, Shared.FlowApprox.ReturnedMem, Shared.ValueApprox.Mem]
  repeat constructor
  all_goals simp

/-- 値と構文の写しの観測は一致する。篩の所属はここでは主張しない。 -/
theorem concrete_release_bridge (kind : Interval.IntKind) (value : Interval.IntegerValue kind) :
    (Interval.ConcreteValue.ofInteger kind value).toApprox =
      (Interval.integerPatternValue kind value).toApprox := by
  cases kind <;> simp [Interval.ConcreteValue.ofInteger, Interval.ConcreteValue.toApprox,
    Interval.integerPatternValue, Interval.IntegerValue.toConst, Release.Val.toApprox,
    Release.Const.toApprox, Shared.ApproxValue.ofInt_bounded]

end SharedBoundary

#print axioms SharedBoundary.distinct_widths
#print axioms SharedBoundary.legacy_width_boundary
#print axioms SharedBoundary.separate_results
#print axioms SharedBoundary.evaluator_bridge
#print axioms SharedBoundary.old_flow_bridge
#print axioms SharedBoundary.concrete_release_bridge
