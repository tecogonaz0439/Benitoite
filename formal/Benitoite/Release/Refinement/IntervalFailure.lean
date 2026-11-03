import Benitoite.Interval.BudgetNormal
import Benitoite.Release.Refinement.IntervalConnection

/-! # 独立評価の失敗と予算付き解析の失敗成分 -/
namespace Benitoite.Release.Refinement.IntervalFailure
open Benitoite.Interval Benitoite.Interval.BudgetAnalysis Benitoite.Surface
open Benitoite.Release

/-- 未知の失敗を除き、同じ失敗の近似への所属を要求する。 -/
def FailureCovered (approx : BaseApprox) (outcome : EvalOutcome) : Prop :=
  ∀ reason, outcome = .failed reason → reason ≠ .unknown → approx.mayFail = true

theorem then_left {a b : BaseApprox} (h : a.mayFail = true) :
    (baseThen a b).mayFail = true := by
  simp only [baseThen]
  split <;> simp_all [BaseApprox.abrupt]

theorem then_right {a b : BaseApprox} (live : a.live = true) (h : b.mayFail = true) :
    (baseThen a b).mayFail = true := by simp [baseThen, live, h]

theorem merge_tested {a b c : BaseApprox} (h : a.mayFail = true) :
    (baseMerge a b c).mayFail = true := by simp [baseMerge, h]

theorem merge_yes {a b c : BaseApprox} (h : b.mayFail = true) :
    (baseMerge a b c).mayFail = true := by simp [baseMerge, baseJoin, h]

theorem merge_no {a b c : BaseApprox} (h : c.mayFail = true) :
    (baseMerge a b c).mayFail = true := by simp [baseMerge, baseJoin, h]

theorem join_left {a b : BaseApprox} (h : a.mayFail = true) :
    (baseJoin a b).mayFail = true := by simp [baseJoin, h]

theorem join_right {a b : BaseApprox} (h : b.mayFail = true) :
    (baseJoin a b).mayFail = true := by simp [baseJoin, h]

theorem success_vacuous (work : Analysis BaseApprox) {outcome : EvalOutcome}
    (h : ∀ a, FailureCovered a outcome) (key : OperationKey) :
    SuccessAt key work (fun a => FailureCovered a outcome) := by
  intro limits ctx start a ok
  exact h a

theorem result_rejected {result : OperationResult} {reason : Failure}
    (h : result.outcome = .failed reason) : result = .rejected reason := by
  cases result <;> cases h
  rfl

theorem own_success (key op type left right) :
    Success (own key op type left right)
      (fun a => a.mayFail = (baseOwn key op type left right).mayFail) := by
  unfold own
  exact success_before _ (fun _ => success_pure _ rfl)

theorem neg_success (key type child) :
    Success (negOwnTyped key type child)
      (fun a => a.mayFail = (baseNegOwnTyped key type child).mayFail) := by
  unfold negOwnTyped
  exact success_before _ (fun _ => success_pure _ rfl)

theorem fixed_success (binding key child) :
    Success (fixedOwn binding key child) (fun a => a.mayFail = true) := by
  unfold fixedOwn
  apply success_before
  intro u
  apply success_pure
  simp [selectedFixedOwn, baseFixedOwn, baseUnknown]
  split <;> rfl

/-- 幅付きの演算の拒否は、その正常な二入力の区間で失敗成分へ入る。 -/
theorem own_kind_failure {left right : BaseApprox} (key : OperationKey)
    (kind : IntKind) (op : WidthBinary) (a b : IntegerValue kind)
    (hl : left.Contains (.ofInteger kind a)) (hr : right.Contains (.ofInteger kind b)) :
    FailureCovered (baseOwnKind key op.op kind left right) (op.apply kind a b).outcome := by
  intro reason failed ne
  have rejected := result_rejected failed
  have l := BaseApprox.contains_rangeKind kind a hl
  have r := BaseApprox.contains_rangeKind kind b hr
  cases op with
  | add =>
    have overflow : kind.checkedAdd a b = .rejected .overflow := by
      dsimp only [WidthBinary.apply, IntKind.checkedAdd] at rejected ⊢
      split at rejected <;> cases rejected
      simp_all
    have possible := add_may_overflow_sound l r overflow
    cases kind <;> simpa [baseOwnKind, WidthBinary.op, baseIntegerKind, baseInteger] using possible
  | sub =>
    have overflow : kind.checkedSub a b = .rejected .overflow := by
      dsimp only [WidthBinary.apply, IntKind.checkedSub] at rejected ⊢
      split at rejected <;> cases rejected
      simp_all
    have possible := sub_may_overflow_sound l r overflow
    cases kind <;> simpa [baseOwnKind, WidthBinary.op, baseIntegerKind, baseInteger] using possible
  | mul =>
    have overflow : kind.checkedMul a b = .rejected .overflow := by
      dsimp only [WidthBinary.apply, IntKind.checkedMul] at rejected ⊢
      split at rejected <;> cases rejected
      simp_all
    have possible := mul_may_overflow_sound l r overflow
    cases kind <;> simpa [baseOwnKind, WidthBinary.op, baseIntegerKind, baseInteger] using possible
  | intDiv | mod =>
    cases kind <;> simp [baseOwnKind, WidthBinary.op, IntegerDivisionOp, baseIntegerKind, baseInteger]
  | compare op => cases rejected

theorem own_width_failure {left right : BaseApprox} (key : OperationKey)
    (kind : IntKind) (op : WidthBinary) (a b : IntegerValue kind)
    (hl : left.Contains (.ofInteger kind a)) (hr : right.Contains (.ofInteger kind b)) :
    FailureCovered (baseOwn key op.op kind.type left right) (op.apply kind a b).outcome := by
  by_cases different : kind ≠ .integer64
  · rw [baseOwn_atKind key op.op kind left right different]
    exact own_kind_failure key kind op a b hl hr
  · have same : kind = .integer64 := by simpa using different
    subst kind
    intro reason failed ne
    have h := own_kind_failure key .integer64 op a b hl hr reason failed ne
    cases op with
    | compare op => cases result_rejected failed
    | add | sub | mul | intDiv | mod =>
      first
      | exact rfl
      | simpa [baseOwn, baseOwnKind, WidthBinary.op, IntKind.type,
          BaseApprox.rangeKind, IntegerDivisionOp, baseIntegerKind, baseInteger] using h

theorem neg_kind_failure {child : BaseApprox} (key : OperationKey)
    (kind : IntKind) (signed : kind.min < 0) (a : IntegerValue kind)
    (hc : child.Contains (.ofInteger kind a)) :
    FailureCovered (baseNegOwnTyped key kind.type child) (kind.checkedNeg signed a).outcome := by
  intro reason failed ne
  have rejected := result_rejected failed
  have overflow : kind.checkedNeg signed a = .rejected .overflow := by
    dsimp only [IntKind.checkedNeg] at rejected ⊢
    split at rejected <;> cases rejected
    simp_all
  have possible := neg_may_overflow_sound signed (BaseApprox.contains_rangeKind kind a hc) overflow
  cases kind <;> simp_all [baseNegOwnTyped, baseNegOwn, baseNegOwnKind,
    IntKind.type, IntKind.ofType, IntKind.min, BaseApprox.rangeKind, baseIntegerKind, baseInteger]

/-- 二つの子が正常な場合だけ、演算自身の失敗を利用する。 -/
theorem binary_own_failure (fuel : Nat)
    {abstract concrete key op type leftSource rightSource a b lt rt outcome leftKey rightKey}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨leftSource, type, leftKey⟩ (.normal a) lt)
    (er : EvalPartial concrete ⟨rightSource, type, rightKey⟩ (.normal b) rt)
    (rightStart : rightKey = advanceKey leftKey (surfaceSize leftSource))
    (operation : ∀ left right, left.Contains a → right.Contains b →
      FailureCovered (baseOwn key op type left right) outcome) :
    SuccessAt leftKey (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt) else
          pure (baseThen lhs (baseThen rhs (← own key op type lhs rhs))))
      (fun approx => FailureCovered approx outcome) := by
  refine successAt_bind (expr_value_normal fuel models ranges el).rekey ?_
  intro left hl
  simp only [contains_live hl, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind ((expr_value_normal fuel models ranges er).rekey rightStart.symm) ?_
  intro right hr
  simp only [contains_live hr, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind ((own_success key op type left right).at _) ?_
  intro own same
  apply indexed_success_pure
  intro reason failed ne
  exact then_right (contains_live hl) (then_right (contains_live hr)
    (same.trans (operation left right hl hr reason failed ne)))

theorem binary_left_failure (fuel : Nat)
    {abstract key op type leftSource rightSource outcome leftKey}
    (child : SuccessAt leftKey (expr fuel abstract leftSource)
      (fun a => FailureCovered a outcome)) :
    SuccessAt leftKey (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt) else
          pure (baseThen lhs (baseThen rhs (← own key op type lhs rhs))))
      (fun a => FailureCovered a outcome) := by
  refine successAt_bind child ?_
  intro left covered
  split
  · refine successAt_before _ (fun _ => ?_)
    exact indexed_success_pure _ (fun r h ne => covered r h ne)
  · refine successAt_before _ (fun right => ?_)
    split
    · exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    · refine successAt_before _ (fun own => ?_)
      exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))

theorem binary_right_failure (fuel : Nat)
    {abstract concrete key op type leftSource rightSource a lt outcome leftKey rightKey}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨leftSource, type, leftKey⟩ (.normal a) lt)
    (rightStart : rightKey = advanceKey leftKey (surfaceSize leftSource))
    (child : SuccessAt rightKey (expr fuel abstract rightSource)
      (fun a => FailureCovered a outcome)) :
    SuccessAt leftKey (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt) else
          pure (baseThen lhs (baseThen rhs (← own key op type lhs rhs))))
      (fun a => FailureCovered a outcome) := by
  refine successAt_bind (expr_value_normal fuel models ranges el).rekey ?_
  intro left modeled
  simp only [contains_live modeled, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind (child.rekey rightStart.symm) ?_
  intro right covered
  split
  · exact indexed_success_pure _ (fun r h ne => then_right (contains_live modeled) (covered r h ne))
  · refine successAt_before _ (fun own => ?_)
    exact indexed_success_pure _ (fun r h ne =>
      then_right (contains_live modeled) (then_left (covered r h ne)))

private theorem walk_normal {work : Analysis α} {sources : List Expr}
    (h : Walk work sources) : NormalWalk work sources.length :=
  ⟨fun _ _ _ _ ok => (h.success ok).1⟩

theorem select_failure {run skip target positions env key sources types outcome trace}
    (he : ∀ source, Walk (run source) (surfacePreorder source))
    (hs : ∀ sources, Walk (skip sources) (preorderExprs sources))
    (normal : ∀ input value trace, EvalPartial env input (.normal value) trace →
      SuccessAt input.key (run input.source) (fun a => a.Contains value))
    (failed : ∀ input outcome trace, EvalPartial env input outcome trace →
      SuccessAt input.key (run input.source) (fun a => FailureCovered a outcome))
    (eval : EvalTypedArguments env key (exprsChildren sources) types (.abrupt outcome) trace) :
    SuccessAt key (selectArguments run skip target positions sources)
      (fun a => FailureCovered a outcome) := by
  haveI (source : Expr) : NormalWalk (run source) (surfaceSize source) := walk_normal (he source)
  haveI (sources : Exprs) : NormalWalk (skip sources) (preorderExprs sources).length := walk_normal (hs sources)
  haveI (sources : Exprs) (positions : List Nat) :
      NormalWalk (selectArguments run skip target positions sources) (preorderExprs sources).length :=
    walk_normal (walk_selectArguments run skip target positions sources he hs)
  rw [selectArguments.eq_def]
  apply successAt_scope
  refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
  simp only [advanceKey_zero]
  cases sources with
  | nil => cases eval
  | cons source rest =>
    cases eval with
    | headAbrupt _ _ _ _ _ _ _ _ head abrupt =>
      refine successAt_bind (failed _ _ _ head) ?_
      intro first covered
      split
      · refine successAt_before _ (fun _ => ?_)
        exact indexed_success_pure _ (fun r h ne => covered r h ne)
      · refine successAt_before _ (fun last => ?_)
        exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
      refine successAt_bind (normal _ _ _ head) ?_
      intro first modeled
      simp only [contains_live modeled, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (select_failure he hs normal failed tail).rekey ?_
      intro last covered
      exact indexed_success_pure _ (fun r h ne =>
        then_right (contains_live modeled) (then_left (covered r h ne)))
termination_by sources

namespace Representatives
private def env := AbstractEnv.ofLocals []
private def key : OperationKey := ⟨"Failure.example", 0⟩
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
private def overflow : Expr := .binary .add (.base .integer) maximum one
private def run (source : Expr) (fuel : Nat := 30) : Report :=
  analyzeExpr {} {} fuel env key source

/- 直接の桁あふれと短絡で到達しない右辺を区別する。 -/
#guard
    (run overflow).approx.mayFail = true ∧
    (run (.and (.literal (.boolean false))
      (.binary .lt (.base .integer) overflow one))).approx.mayFail = false ∧
    (run (.and (.literal (.boolean true))
      (.binary .lt (.base .integer) overflow one))).approx.mayFail = true

/- return の後の番兵は実解析の失敗成分へ加えない。 -/
#guard
    (run (.block (.seq (.returnE (.base .integer) one) (.last overflow)))).approx.mayFail = false


end Representatives

/-- 停止では正常値・失敗とも未知へ退き、消費済み状態も同じ入口で扱う。 -/
theorem stopped (ctx : Context) (halt : Halt) :
    (report (.error halt) ctx).approx.mayFail = true := rfl

/-- Range の拒否は Result.Error という正常値であり、failed とは異なる。 -/
theorem range_error (names : RangeNames) (key : OperationKey)
    (lo hi value : Integer64Value) :
    ∃ output, (StandardRule.rangeCheck names).finish
      (rangeCheck names key lo hi value) = .normal output := by
  unfold rangeCheck
  cases h : Checked.Range.make lo.toInt hi.toInt value.toInt with
  | ok v => exact ⟨_, rfl⟩
  | error error => cases error <;> exact ⟨_, rfl⟩



private instance skipExprs_normal (fuel : Nat) (sources : Exprs) :
    NormalWalk (skipExprs fuel sources) (preorderExprs sources).length :=
  walk_normal ((skip_walk fuel).2.2.1 sources)

private theorem standard_nonfixed {rule key args result}
    (eval : EvalStandard rule key args result) (fixed : rule.isFixed = false) :
    ∀ reason, rule.finish result = .failed reason → reason = .unknown := by
  cases eval with
  | rangeCheck names key lo hi value =>
    obtain ⟨output, normal⟩ := range_error names key lo hi value
    intro reason h
    rw [normal] at h
    cases h
  | rangeValue => intro reason h; cases h
  | rangeValueUnknown => intro reason h; cases h
  | rangeValueUnknownFailed => intro reason h; cases h; rfl
  | domainNormal | domainOtherFailure | domainRejected => cases fixed

private theorem fixedBinding_rule (binding : StandardBinding) :
    fixedBinding binding = binding.rule.isFixed := by cases binding with
  | mk declaration rule argumentTypes => cases rule <;> rfl

set_option maxRecDepth 4096 in
set_option maxHeartbeats 2000000 in
mutual
theorem expr_failure (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input outcome trace) :
    SuccessAt input.key (expr fuel abstract input.source)
      (fun a => FailureCovered a outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [expr]
    apply successAt_scope
    apply successAt_identify
    refine successAt_before (scan (BudgetScan.tick .expression)) (fun _ => ?_)
    simp only [advanceKey_zero]
    match eval with
    | .standardCall env root callee labels positions sources binding values orderedValues result trace recognized children ordered evaluated =>
      have atCall : rangeCallAt abstract root (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources,
          binding.rule.resultType, root⟩) models).trans recognized
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _)) ?_
      intro found same
      rw [same, atCall]
      refine successAt_before (skipExpr fuel callee) (fun _ => ?_)
      split
      · refine successAt_bind (selectArguments_normal ((analysis_walk fuel).1 abstract)
          ((skip_walk fuel).2.2.1)
          (fun input value trace child => expr_value_normal fuel models ranges child) children).rekey ?_
        intro selected modeled
        refine successAt_bind ((fixed_success binding root selected).at _) ?_
        intro own failed
        exact indexed_success_pure _ (fun r h ne => then_right modeled.1 failed)
      · apply success_vacuous
        intro a reason failed ne
        exact False.elim (ne (standard_nonfixed evaluated
          (by simpa only [fixedBinding_rule] using (Bool.eq_false_iff.mpr (by assumption))) reason failed))
    | .fixedCallFailed env root callee labels positions sources binding values arguments reason type trace recognized fixed children ordered evaluated =>
      have atCall : rangeCallAt abstract root (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, type, root⟩) models).trans recognized
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _)) ?_
      intro found same
      rw [same, atCall]
      dsimp only
      rw [fixedBinding_rule, fixed]
      refine successAt_before (skipExpr fuel callee) (fun _ => ?_)
      refine successAt_bind (selectArguments_normal ((analysis_walk fuel).1 abstract)
        ((skip_walk fuel).2.2.1)
        (fun input value trace child => expr_value_normal fuel models ranges child) children).rekey ?_
      intro selected modeled
      refine successAt_bind ((fixed_success binding root selected).at _) ?_
      intro own failed
      exact indexed_success_pure _ (fun r h ne => then_right modeled.1 failed)
    | .standardCallAbrupt env root callee labels positions sources binding outcome trace recognized children abrupt =>
      have atCall : rangeCallAt abstract root (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, binding.rule.resultType, root⟩) models).trans recognized
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _)) ?_
      intro found same
      rw [same, atCall]
      refine successAt_before (skipExpr fuel callee) (fun _ => ?_)
      split
      · refine successAt_bind (select_failure ((analysis_walk fuel).1 abstract)
          ((skip_walk fuel).2.2.1)
          (fun input value trace child => expr_value_normal fuel models ranges child)
          (fun input outcome trace child => expr_failure fuel models ranges child) children).rekey ?_
        intro selected covered
        refine successAt_before _ (fun own => ?_)
        exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
      · refine successAt_bind (typed_arguments_failure fuel models ranges children).rekey ?_
        intro values covered
        refine successAt_before _ (fun own => ?_)
        exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | .fixedCallAbrupt env root callee labels positions sources binding type outcome trace recognized fixed children abrupt =>
      have atCall : rangeCallAt abstract root (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, type, root⟩) models).trans recognized
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _)) ?_
      intro found same
      rw [same, atCall]
      dsimp only
      rw [fixedBinding_rule, fixed]
      refine successAt_before (skipExpr fuel callee) (fun _ => ?_)
      refine successAt_bind (select_failure ((analysis_walk fuel).1 abstract)
        ((skip_walk fuel).2.2.1)
        (fun input value trace child => expr_value_normal fuel models ranges child)
        (fun input outcome trace child => expr_failure fuel models ranges child) children).rekey ?_
      intro selected covered
      refine successAt_before _ (fun own => ?_)
      exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | .unknownNormal .. | .integer .. | .negInt .. | .integer8 .. | .integer16 ..
    | .integer32 .. | .unsignedInteger16 .. | .unsignedInteger32 .. | .unsignedInteger64 ..
    | .negInteger8 .. | .negInteger16 .. | .negInteger32 .. | .boolean .. | .unit .. | .local ..
    | .not .. | .andShort .. | .orShort .. | .ifOnlyFalse .. | .matchOtherNormal .. =>
      exact success_vacuous _ (by intro a r h ne; cases h) _
    | .unknownFailed .. | .matchOtherFailed .. =>
      exact success_vacuous _ (by intro a r h ne; cases h; exact False.elim (ne rfl)) _
    | .compare .. => exact success_vacuous _ (by intro a r h ne; cases h) _
    | .paren _ _ _ _ _ _ child => exact (expr_failure fuel models ranges child).rekey
    | .constE _ _ _ _ _ _ child =>
      exact (expr_failure fuel (models_clearLocals models) (ranges_clearLocals _ _) child).rekey
    | .returnE _ _ _ _ _ result _ child =>
      refine successAt_bind (expr_failure fuel models ranges child).rekey ?_
      intro tested covered
      exact indexed_success_pure _ (by
        intro r h ne
        cases result <;> cases h
        exact covered r rfl ne)
    | .add _ key _ _ a b _ _ el er =>
      exact (binary_own_failure fuel models ranges el er
        (by simp [childKey, advanceKey, Nat.add_assoc])
        (fun l r hl hr => own_width_failure key .integer64 .add a b hl hr)).rekey
    | .sub _ key _ _ a b _ _ el er =>
      exact (binary_own_failure fuel models ranges el er
        (by simp [childKey, advanceKey, Nat.add_assoc])
        (fun l r hl hr => own_width_failure key .integer64 .sub a b hl hr)).rekey
    | .mul _ key _ _ a b _ _ el er =>
      exact (binary_own_failure fuel models ranges el er
        (by simp [childKey, advanceKey, Nat.add_assoc])
        (fun l r hl hr => own_width_failure key .integer64 .mul a b hl hr)).rekey
    | .divMod _ key op _ _ a b _ _ target el er =>
      rcases target with rfl | rfl
      all_goals simp only [binarySupported, IntegerDivisionOp, or_true]
      · exact (binary_own_failure fuel models ranges el er
          (by simp [childKey, advanceKey, Nat.add_assoc])
          (fun l r hl hr => own_width_failure key .integer64 .intDiv a b hl hr)).rekey
      · exact (binary_own_failure fuel models ranges el er
          (by simp [childKey, advanceKey, Nat.add_assoc])
          (fun l r hl hr => own_width_failure key .integer64 .mod a b hl hr)).rekey
    | .widthBinary _ key kind op _ _ a b _ _ not64 el er =>
      simp only [binarySupported_kind, ↓reduceIte]
      exact (binary_own_failure fuel models ranges el er
        (by simp [childKey, advanceKey, Nat.add_assoc])
        (fun l r hl hr => own_width_failure key kind op a b hl hr)).rekey
    | .neg _ key _ value _ child =>
      simp only [negModeled_integer, ↓reduceIte]
      refine successAt_bind (expr_value_normal fuel models ranges child).rekey ?_
      intro tested modeled
      refine successAt_bind ((neg_success key (.base .integer) tested).at _) ?_
      intro own same
      exact indexed_success_pure _ (fun r h ne => then_right (contains_live modeled)
        (same.trans (neg_kind_failure key .integer64 (by decide) value modeled r h ne)))
    | .widthNeg _ key kind _ value _ not64 signed child =>
      simp only [negModeled_kind kind signed, ↓reduceIte]
      refine successAt_bind (expr_value_normal fuel models ranges child).rekey ?_
      intro tested modeled
      refine successAt_bind ((neg_success key kind.type tested).at _) ?_
      intro own same
      exact indexed_success_pure _ (fun r h ne => then_right (contains_live modeled)
        (same.trans (neg_kind_failure key kind signed value modeled r h ne)))
    | .addLeftAbrupt _ _ _ _ _ _ child _
    | .subLeftAbrupt _ _ _ _ _ _ child _
    | .mulLeftAbrupt _ _ _ _ _ _ child _ =>
      exact (binary_left_failure fuel (expr_failure fuel models ranges child)).rekey
    | .divModLeftAbrupt _ _ op _ _ _ _ target child _ =>
      have supported : binarySupported op (.base .integer) = true := by simp [binarySupported, target]
      simp only [supported, ↓reduceIte]
      exact (binary_left_failure fuel (expr_failure fuel models ranges child)).rekey
    | .compareLeftAbrupt _ _ op _ _ _ _ child _ =>
      have supported : binarySupported op.binOp (.base .integer) = true := by simp [binarySupported]
      simp only [supported, ↓reduceIte]
      exact (binary_left_failure fuel (expr_failure fuel models ranges child)).rekey
    | .widthBinaryLeftAbrupt _ _ kind op _ _ _ _ _ child _ =>
      simp only [binarySupported_kind, ↓reduceIte]
      exact (binary_left_failure fuel (expr_failure fuel models ranges child)).rekey
    | .addRightAbrupt _ _ _ _ _ _ _ _ left right _
    | .subRightAbrupt _ _ _ _ _ _ _ _ left right _
    | .mulRightAbrupt _ _ _ _ _ _ _ _ left right _ =>
      exact (binary_right_failure fuel models ranges left
        (by simp [childKey, advanceKey, Nat.add_assoc]) (expr_failure fuel models ranges right)).rekey
    | .divModRightAbrupt _ _ op _ _ _ _ _ _ target left right _ =>
      have supported : binarySupported op (.base .integer) = true := by simp [binarySupported, target]
      simp only [supported, ↓reduceIte]
      exact (binary_right_failure fuel models ranges left
        (by simp [childKey, advanceKey, Nat.add_assoc]) (expr_failure fuel models ranges right)).rekey
    | .compareRightAbrupt _ _ op _ _ _ _ _ _ left right _ =>
      have supported : binarySupported op.binOp (.base .integer) = true := by simp [binarySupported]
      simp only [supported, ↓reduceIte]
      exact (binary_right_failure fuel models ranges left
        (by simp [childKey, advanceKey, Nat.add_assoc]) (expr_failure fuel models ranges right)).rekey
    | .widthBinaryRightAbrupt _ _ kind op _ _ _ _ _ _ _ left right _ =>
      simp only [binarySupported_kind, ↓reduceIte]
      exact (binary_right_failure fuel models ranges left
        (by simp [childKey, advanceKey, Nat.add_assoc]) (expr_failure fuel models ranges right)).rekey
    | .negAbrupt _ _ _ _ _ child _ =>
      simp only [negModeled_integer, ↓reduceIte]
      refine successAt_bind (expr_failure fuel models ranges child).rekey ?_
      intro tested covered
      refine successAt_before _ (fun own => ?_)
      exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | .widthNegAbrupt _ _ kind _ _ _ not64 signed child _ =>
      simp only [negModeled_kind kind signed, ↓reduceIte]
      refine successAt_bind (expr_failure fuel models ranges child).rekey ?_
      intro tested covered
      refine successAt_before _ (fun own => ?_)
      exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | .notAbrupt _ _ _ _ _ child _ =>
      refine successAt_bind (expr_failure fuel models ranges child).rekey ?_
      intro tested covered
      exact indexed_success_pure _ covered
    | .block _ _ _ _ _ _ child => exact (block_failure fuel models ranges child).rekey
    | .andRight _ _ _ _ _ _ _ condition child
    | .orRight _ _ _ _ _ _ _ condition child =>
      exact (shortCircuit_right_failure fuel models ranges condition child
        (by simp [childKey, advanceKey, Nat.add_assoc])).rekey
    | .andAbrupt _ _ _ _ _ _ child _
    | .orAbrupt _ _ _ _ _ _ child _ =>
      exact (shortCircuit_abrupt_failure fuel models ranges child).rekey
    | .iteAbrupt _ _ _ _ _ _ _ _ condition _
    | .elseIfAbrupt _ _ _ _ _ _ _ _ condition _
    | .ifOnlyAbrupt _ _ _ _ _ _ condition _ =>
      refine successAt_bind (expr_failure fuel models ranges condition).rekey ?_
      intro tested covered
      refine successAt_before _ (fun yes => ?_)
      refine successAt_before _ (fun no => ?_)
      exact indexed_success_pure _ (fun r h ne => merge_tested (covered r h ne))
    | .matchAbrupt _ _ _ _ _ _ _ _ child _ =>
      refine successAt_bind (expr_failure fuel models ranges child).rekey ?_
      intro tested covered
      split
      · refine successAt_before _ (fun _ => ?_)
        exact indexed_success_pure _ covered
      · refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
        intro known same
        cases known
        · cases tested.matchKind
          · refine successAt_before _ (fun _ => ?_)
            refine successAt_before _ (fun own => ?_)
            exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
          · refine successAt_before _ (fun own => ?_)
            exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
        · refine successAt_before _ (fun own => ?_)
          exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | .matchInteger _ key source arms _ integer _ _ _ child selected =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro recognized same
      have absent := range_match_at_integer_none (kind := .integer64)
        (arms := arms) models ranges child
      rw [same, absent]
      cases choice : tested.matchKind with
      | some kind =>
        have same : kind = .integer64 := (matchKind_contains (actual := .integer64) inside choice).symm
        subst kind
        refine successAt_bind (armList_failure fuel models ranges child inside selected).rekey ?_
        intro approx covered
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) (covered r h ne))
      | none =>
        refine successAt_before _ (fun _ => ?_)
        refine successAt_bind indexed_success_unsupported ?_
        intro approx eq; subst approx
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) rfl)
    | .matchWidth _ key kind source arms _ integer _ _ _ not64 child selected =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro recognized same
      have absent := range_match_at_integer_none (kind := kind)
        (arms := arms) models ranges child
      rw [same, absent]
      cases choice : tested.matchKind with
      | some chosen =>
        have same : chosen = kind := (matchKind_contains inside choice).symm
        subst chosen
        refine successAt_bind (armListKind_failure fuel not64 models ranges child
          (BaseApprox.contains_rangeKind kind integer inside) selected).rekey ?_
        intro approx covered
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) (covered r h ne))
      | none =>
        refine successAt_before _ (fun _ => ?_)
        refine successAt_bind indexed_success_unsupported ?_
        intro approx eq; subst approx
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) rfl)
    | .matchResult env root source arms type sourceType result names tag payload outcome st armTrace recognized view child selected =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro known same
      rw [same]
      cases found : rangeMatchAt abstract ⟨source, .base .unit, childKey root []⟩ arms with
      | none =>
        simp only [noninteger_matchKind_none inside (range_result_view_noninteger view)]
        refine successAt_before _ (fun _ => ?_)
        refine successAt_bind indexed_success_unsupported ?_
        intro approx eq; subst approx
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) rfl)
      | some origin =>
        have actual : rangeMatchAt abstract ⟨source, sourceType, childKey root []⟩ arms = some origin := by
          simpa only [range_match_at_type] using
            (range_match_at_type abstract ⟨source, sourceType, childKey root []⟩ (.base .unit) arms).symm.trans found
        have matched := range_match_at_evaluated models ranges actual child
        have namesSame : origin.names = names := Option.some.inj (matched.symm.trans recognized)
        subst names
        refine successAt_bind
          (resultArmList_failure fuel models ranges found child matched view selected).rekey ?_
        intro result covered
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) (covered r h ne))
    | .iteTrue _ _ _ _ _ _ _ _ _ condition child
    | .elseIfTrue _ _ _ _ _ _ _ _ _ condition child
    | .ifOnlyTrue _ _ _ _ _ _ _ condition child =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_bind (successAt_branch_selected entry
        (block_failure fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
      intro positive covered
      refine successAt_before _ (fun negative => ?_)
      exact indexed_success_pure _ (fun r h ne => merge_yes (covered r h ne))
    | .iteFalse _ _ _ _ _ _ _ _ _ condition child =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_before _ (fun positive => ?_)
      refine successAt_bind (successAt_branch_selected entry
        (block_failure fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
      intro negative covered
      exact indexed_success_pure _ (fun r h ne => merge_no (covered r h ne))
    | .elseIfFalse _ _ _ _ _ _ _ _ _ condition child =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_before _ (fun positive => ?_)
      refine successAt_bind (successAt_branch_selected entry
        (expr_failure fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
      intro negative covered
      exact indexed_success_pure _ (fun r h ne => merge_no (covered r h ne))
termination_by 2 * fuel
decreasing_by all_goals omega

theorem shortCircuit_right_failure (fuel : Nat) {abstract concrete left right truth key rightKey trace outcome rt}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (child : EvalPartial concrete ⟨right, .base .boolean, rightKey⟩ outcome rt)
    (rightStart : rightKey = advanceKey key (surfaceSize left)) :
    SuccessAt key (shortCircuit fuel abstract left right truth)
      (fun approx => FailureCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [shortCircuit]
    refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
    intro tested covered
    obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
    refine successAt_bind (successAt_branch_selected entry
        ((expr_failure fuel related (ranges_branchEnv ranges entry) child).rekey rightStart.symm)) ?_
    intro continued covered
    refine successAt_before _ (fun short => ?_)
    exact indexed_success_pure _ (fun r h ne => merge_yes (covered r h ne))

termination_by 2 * fuel + 0
decreasing_by all_goals omega

theorem shortCircuit_abrupt_failure (fuel : Nat) {abstract concrete left right truth key outcome trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ outcome trace) :
    SuccessAt key (shortCircuit fuel abstract left right truth) (fun a => FailureCovered a outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [shortCircuit]
    refine successAt_bind (expr_failure fuel models ranges condition).rekey ?_
    intro tested covered
    refine successAt_before _ (fun continued => ?_)
    refine successAt_before _ (fun shorted => ?_)
    exact indexed_success_pure _ (fun r h ne => merge_tested (covered r h ne))
termination_by 2 * fuel

theorem block_failure (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace) :
    SuccessAt key (block fuel abstract body) (fun approx => FailureCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [block.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .empty .. => exact indexed_success_pure _ (by intro r h ne; cases h)
    | .builderBind _ _ kind _ _ _ _ child =>
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.push_agrees _ _)) ?_
      intro inner eq; subst inner
      exact (block_failure fuel (models_extend (slot := .builder kind) models (value := none) trivial)
        (ranges_extend (slot := .builder kind) ranges none) child).rekey
    | .last _ _ _ _ _ _ child => exact (expr_failure fuel models ranges child).rekey
    | .lastBind _ _ _ _ _ result _ child
    | .lastDiscard _ _ _ _ result _ child
    | .lastPat _ _ _ _ _ _ result _ child =>
      refine successAt_bind (expr_failure fuel models ranges child).rekey ?_
      intro approx covered
      apply indexed_success_pure
      intro r h ne
      cases result <;> cases h
      exact then_left (covered r rfl ne)
    | .bind _ _ kind _ _ _ _ _ _ _ _ head tail =>
      apply successAt_get
      intro start atKey
      simp only [atKey]
      refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
      intro approx modeled
      have inside := modeled
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeBind_agrees _ _ _ _ _)) ?_
      intro inner eq; subst inner
      refine successAt_bind (block_failure fuel
        (show Models (baseBindSource kind _ _ _ _) _ from
          bind_models kind models (eval_normal_typed head) inside)
        (range_save_result_of_eval models ranges head) tail).rekey ?_
      intro result covered
      exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) (covered r h ne))
    | .discard _ _ _ _ _ _ _ _ _ _ head tail
    | .seq _ _ _ _ _ _ _ _ _ head tail =>
      refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
      intro approx covered
      have inside := covered
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (block_failure fuel models ranges tail).rekey ?_
      intro result covered
      exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) (covered r h ne))
    | .bindPat _ _ _ _ _ _ _ _ _ _ _ _ _ head bindings tail =>
      refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
      intro approx covered
      have inside := covered
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.patternEnv_agrees _ _ _)) ?_
      intro inner eq; subst inner
      refine successAt_bind (block_failure fuel (pattern_models models (eval_normal_typed head) bindings)
        (pattern_ranges ranges bindings) tail).rekey ?_
      intro result covered
      exact indexed_success_pure _ (fun r h ne => then_right (contains_live inside) (covered r h ne))
    | .bindAbrupt _ _ _ _ _ _ _ _ _ head _ =>
      apply successAt_get
      intro start atKey
      simp only [atKey]
      refine successAt_bind (expr_failure fuel models ranges head).rekey ?_
      intro tested covered
      split
      · refine successAt_before _ (fun _ => ?_)
        exact indexed_success_pure _ covered
      · refine successAt_before _ (fun inner => ?_)
        refine successAt_before _ (fun tail => ?_)
        exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
    | .discardAbrupt _ _ _ _ _ _ _ _ head _
    | .seqAbrupt _ _ _ _ _ _ _ head _
    | .bindPatAbrupt _ _ _ _ _ _ _ _ _ _ head _ =>
      refine successAt_bind (expr_failure fuel models ranges head).rekey ?_
      intro tested covered
      split
      · refine successAt_before _ (fun _ => ?_)
        exact indexed_success_pure _ covered
      · first
        | (refine successAt_before _ (fun tail => ?_)
           exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne)))
        | (refine successAt_before _ (fun inner => ?_)
           refine successAt_before _ (fun tail => ?_)
           exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne)))

termination_by 2 * fuel + 0
decreasing_by all_goals omega

theorem armList_failure (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    SuccessAt key (armList fuel abstract source normal arms) (fun approx => FailureCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [armList, armListKind.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .nil .. => exact indexed_success_pure _ (by intro r h ne; cases h; exact False.elim (ne rfl))
    | .skip _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      refine successAt_before _ (fun first => ?_)
      refine successAt_bind (armList_failure fuel models ranges scrutinee inside tail).rekey ?_
      intro rest covered
      exact indexed_success_pure _ (fun r h ne => join_right (covered r h ne))
    | .body _ _ _ _ _ _ _ _ _ _ selection body =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models ranges scrutinee inside selection entry
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.arm_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        exact (block_failure fuel related innerRanges body).rekey
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models ranges scrutinee inside selection entry
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.arm_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        refine successAt_bind (expr_normal fuel related innerRanges condition).rekey ?_
        intro tested covered
        obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition (covered _ rfl)
        refine successAt_bind (successAt_branch_selected atEnv
          (block_failure fuel modeled (ranges_branchEnv innerRanges atEnv) body).rekey) ?_
        intro positive covered
        exact indexed_success_pure _ (fun r h ne => merge_yes (covered r h ne))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ selection condition abrupt =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models ranges scrutinee inside selection entry
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.arm_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        refine successAt_bind (expr_failure fuel related innerRanges condition).rekey ?_
        intro tested covered
        refine successAt_before _ (fun positive => ?_)
        exact indexed_success_pure _ (fun r h ne => merge_tested (covered r h ne))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
termination_by 2 * fuel + 0
decreasing_by all_goals omega


theorem armListKind_failure (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    SuccessAt key (armListKind fuel kind abstract source normal arms) (fun approx => FailureCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [armListKind.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .nil .. => exact indexed_success_pure _ (by intro r h ne; cases h; exact False.elim (ne rfl))
    | .skip _ _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      refine successAt_before _ (fun first => ?_)
      refine successAt_bind (armListKind_failure fuel not64 models ranges scrutinee inside tail).rekey ?_
      intro rest covered
      exact indexed_success_pure _ (fun r h ne => join_right (covered r h ne))
    | .body _ _ _ _ _ _ _ _ _ _ _ selection body =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models ranges scrutinee inside selection not64 entry
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.armKind_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        exact (block_failure fuel related innerRanges body).rekey
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models ranges scrutinee inside selection not64 entry
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.armKind_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        refine successAt_bind (expr_normal fuel related innerRanges condition).rekey ?_
        intro tested covered
        obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition (covered _ rfl)
        refine successAt_bind (successAt_branch_selected atEnv
          (block_failure fuel modeled (ranges_branchEnv innerRanges atEnv) body).rekey) ?_
        intro positive covered
        exact indexed_success_pure _ (fun r h ne => merge_yes (covered r h ne))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ selection condition abrupt =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models ranges scrutinee inside selection not64 entry
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.armKind_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        refine successAt_bind (expr_failure fuel related innerRanges condition).rekey ?_
        intro tested covered
        refine successAt_before _ (fun positive => ?_)
        exact indexed_success_pure _ (fun r h ne => merge_tested (covered r h ne))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
termination_by 2 * fuel + 0
decreasing_by all_goals omega

theorem resultArmList_failure (fuel : Nat)
    {abstract concrete input sourceType fullArms origin result tag payload key arms type outcome trace st}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (known : rangeMatchAt abstract input fullArms = some origin)
    (scrutinee : EvalPartial concrete { input with type := sourceType } (.normal result) st)
    (matched : rangeResultMatch concrete result fullArms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (eval : EvalResultArms concrete key origin.names result tag payload arms type outcome trace) :
    SuccessAt key (resultArmList fuel abstract input arms)
      (fun approx => FailureCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [resultArmList.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .nil .. => exact indexed_success_pure _ (by intro r h ne; cases h; exact False.elim (ne rfl))
    | .skip _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      refine successAt_before _ (fun first => ?_)
      refine successAt_bind
        (resultArmList_failure fuel models ranges known scrutinee matched view tail).rekey ?_
      intro rest covered
      exact indexed_success_pure _ (fun r h ne => join_right (covered r h ne))
    | .body _ _ _ _ _ _ _ _ _ _ _ _ _ selection body =>
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have actualKnown : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
        simpa only [range_match_at_type] using known
      have innerRanges := baseResultArmEnv_ranges models ranges actualKnown scrutinee matched view selection
      rw [baseResultArmEnv_type] at innerRanges
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeArm_agrees _ _ _)) ?_
        intro inner same; subst inner
        exact (block_failure fuel innerModels innerRanges body).rekey
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have actualKnown : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
        simpa only [range_match_at_type] using known
      have innerRanges := baseResultArmEnv_ranges models ranges actualKnown scrutinee matched view selection
      rw [baseResultArmEnv_type] at innerRanges
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeArm_agrees _ _ _)) ?_
        intro inner same; subst inner
        refine successAt_bind (expr_normal fuel innerModels innerRanges condition).rekey ?_
        intro tested covered
        obtain ⟨refined, entry, refinedModels⟩ := branch_models innerModels condition (covered _ rfl)
        refine successAt_bind (successAt_branch_selected entry
          (block_failure fuel refinedModels (ranges_branchEnv innerRanges entry) body).rekey) ?_
        intro positive covered
        exact indexed_success_pure _ (fun r h ne => merge_yes (covered r h ne))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition abrupt =>
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have actualKnown : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
        simpa only [range_match_at_type] using known
      have innerRanges := baseResultArmEnv_ranges models ranges actualKnown scrutinee matched view selection
      rw [baseResultArmEnv_type] at innerRanges
      refine successAt_bind (post := fun approx => FailureCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeArm_agrees _ _ _)) ?_
        intro inner same; subst inner
        refine successAt_bind (expr_failure fuel innerModels innerRanges condition).rekey ?_
        intro tested covered
        refine successAt_before _ (fun positive => ?_)
        exact indexed_success_pure _ (fun r h ne => merge_tested (covered r h ne))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun r h ne => join_left (covered r h ne))
termination_by 2 * fuel + 0
decreasing_by all_goals omega


theorem typed_arguments_failure (fuel : Nat)
    {abstract concrete key sources types outcome trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (eval : EvalTypedArguments concrete key (exprsChildren sources) types (.abrupt outcome) trace) :
    SuccessAt key (arguments fuel abstract sources) (fun a => FailureCovered a outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [arguments.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    cases sources with
    | nil => cases eval
    | cons source rest =>
      cases eval with
      | headAbrupt _ _ _ _ _ _ _ _ head abrupt =>
        refine successAt_bind (expr_failure fuel models ranges head).rekey ?_
        intro tested covered
        split
        · refine successAt_before _ (fun _ => ?_)
          exact indexed_success_pure _ covered
        · refine successAt_before _ (fun tail => ?_)
          exact indexed_success_pure _ (fun r h ne => then_left (covered r h ne))
      | tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
        refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
        intro tested modeled
        simp only [contains_live modeled, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
        refine successAt_bind (typed_arguments_failure fuel models ranges tail).rekey ?_
        intro rest covered
        exact indexed_success_pure _ (fun r h ne => then_right (contains_live modeled) (covered r h ne))
termination_by 2 * fuel

theorem arguments_failure (fuel : Nat) {abstract concrete key sources type outcome trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (eval : EvalArguments concrete key (exprsChildren sources) type (.abrupt outcome) trace) :
    SuccessAt key (arguments fuel abstract sources) (fun a => FailureCovered a outcome) :=
  typed_arguments_failure fuel models ranges (arguments_typed eval)

end

/-- 停止した結果にも、成功時と同じ射影で失敗成分を与える。 -/
theorem report_failure {result : Except Halt BaseApprox} (ctx : Context) {outcome : EvalOutcome}
    (success : ∀ a, result = .ok a → FailureCovered a outcome) :
    FailureCovered (report result ctx).approx outcome := by
  cases result with
  | error reason => intro r h ne; exact stopped ctx reason
  | ok a => exact success a rfl

/-- 上限・既消費・fuel に条件を追加せず、実入口の失敗成分へ上げる。 -/
theorem analyzeExpr_failure (limits : Budget.Limits) (state : Budget.State) (fuel : Nat)
    {abstract concrete input outcome trace}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace) :
    FailureCovered (analyzeExpr limits state fuel abstract input.key input.source).approx outcome := by
  unfold analyzeExpr
  cases run : expr fuel (resetRanges abstract) input.source limits { budget := state, next := input.key } with
  | mk result ctx =>
    apply report_failure
    intro a ok
    exact expr_failure fuel (models_resetRanges models) (ranges_reset_models _ _) eval limits
      { budget := state, next := input.key } rfl a (by simpa only [run] using ok)

end Benitoite.Release.Refinement.IntervalFailure

namespace Benitoite.Release.Refinement

/-- 同じ独立評価で記録した対象内の失敗は、実解析の失敗成分へ属する。 -/
theorem tracked_failure_sound
    (abstract : Benitoite.Interval.AbstractEnv)
    (concrete : Benitoite.Interval.ConcreteEnv)
    (input : Benitoite.Interval.EvalInput)
    (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace)
    (hm : Benitoite.Interval.Models abstract concrete)
    (he : Benitoite.Interval.EvalPartial concrete input (.failed reason) trace)
    (ht : IntervalConnection.TrackedFailure reason trace) :
    (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true :=
  IntervalFailure.analyzeExpr_failure parameters.limits parameters.state parameters.fuel hm he
    reason rfl ht.1

end Benitoite.Release.Refinement

namespace Benitoite.Release.Refinement.IntervalFailure.Representatives
open Benitoite.Interval Benitoite.Interval.BudgetAnalysis Benitoite.Surface Benitoite.Release

private def concrete : ConcreteEnv := ⟨[], [], fun _ => none⟩
private def overflowTrace : EvalTrace := [⟨key, .binary .add (.base .integer),
  [.integer (Integer64Literal.toValue (⟨9223372036854775807, by decide⟩ : Integer64Literal)),
    .integer (Integer64Literal.toValue (⟨1, by decide⟩ : Integer64Literal))], .rejected .overflow⟩]

set_option maxRecDepth 4096 in
private theorem overflow_eval :
    EvalPartial concrete ⟨overflow, .base .integer, key⟩ (.failed .overflow) overflowTrace := by
  let a : Integer64Literal := ⟨9223372036854775807, by decide⟩
  let b : Integer64Literal := ⟨1, by decide⟩
  have rejected : checkedAdd a.toValue b.toValue = .rejected .overflow := by
    apply (checkedAdd_overflow_iff (kind := .integer64) a.toValue b.toValue).mpr
    decide
  have h := EvalPartial.add concrete key maximum one a.toValue b.toValue [] []
    (.integer concrete (childKey key []) a) (.integer concrete (childKey key [maximum]) b)
  simpa only [overflow, maximum, one, overflowTrace, a, b, rejected,
    List.nil_append, OperationResult.outcome] using h

private theorem tracked : IntervalConnection.TrackedFailure .overflow overflowTrace :=
  ⟨by decide, _, List.mem_cons_self, rfl⟩

private theorem models : Models env concrete := ⟨.nil, rfl, rfl⟩

/-- 同じ実入力・traceに第一候補を適用する。予算は任意である。 -/
example (parameters : Parameters) :
    (analyze env ⟨overflow, .base .integer, key⟩ parameters).mayFail = true :=
  tracked_failure_sound env concrete _ parameters .overflow overflowTrace models overflow_eval tracked

/-- 型を一つずつ持たない引数列も、同じ子の失敗を伝播する。 -/
example (fuel : Nat) :
    SuccessAt key (arguments fuel env (.cons overflow .nil)) (fun a => a.mayFail = true) := by
  have eval : EvalArguments concrete key [overflow] (.base .integer)
      (.abrupt (.failed .overflow)) overflowTrace :=
    .headAbrupt concrete key overflow [] (.base .integer) (.failed .overflow) overflowTrace overflow_eval trivial
  exact (arguments_failure fuel models (ranges_reset_models env concrete) eval).mono
    (fun a covered => covered .overflow rfl (by decide))

/- 深さ0、操作数0、既消費の状態のどれも失敗を消さない。 -/
#guard
  (run one 0).approx.mayFail = true ∧
  (run (.funName "Example.unrecognized" [] [])).approx.mayFail = true ∧
  (analyzeExpr ⟨⟨0,0⟩,⟨0,0⟩⟩ {} 10 env key one).approx.mayFail = true ∧
  (analyzeExpr ⟨⟨1,1⟩,⟨1,1⟩⟩
    { whole := { operations := 1 } } 10 env key one).approx.mayFail = true

end Benitoite.Release.Refinement.IntervalFailure.Representatives
