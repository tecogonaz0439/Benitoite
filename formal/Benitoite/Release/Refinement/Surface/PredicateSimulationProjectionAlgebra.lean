import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationSimpleValues

/-! # getterの呼出し列と、型・範囲・値の具体化 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- getterの宣言と欄の参照を保ち、呼出し元の型引数だけへ写像する。 -/
def mapStepTypes (f : Ty → Ty) (step : PredicateAccessorTargets.Step) : PredicateAccessorTargets.Step :=
  {step with types := step.types.map f}

/-- getterの型引数の具体化は、同じ欄の参照を保つ。 -/
theorem step_references (f : Ty → Ty) (steps : List PredicateAccessorTargets.Step) :
    (steps.map (mapStepTypes f)).map PredicateAccessorTargets.Step.reference =
      steps.map PredicateAccessorTargets.Step.reference := by
  simp only [List.map_map]
  rfl

private theorem getter_rename (step : PredicateAccessorTargets.Step) (rename : Nat → Nat) :
    (getterCall step).rename (upRen 1 rename) = getterCall (mapStepTypes (renameTy rename) step) := by
  simp only [getterCall, Comp.rename, Val.rename, Val.renameList, List.map_nil,
    mapStepTypes, shiftTs, List.map_map, Function.comp_def, upRen, Nat.zero_lt_succ, ite_true]
  congr 2
  apply List.map_congr_left
  intro type member
  simp only [Ty.shiftV_eq_renameTy, renameTy_comp]
  congr 1

private theorem getter_type (step : PredicateAccessorTargets.Step) (index : Nat) (types : List Ty) (effects : List Eff) :
    (getterCall step).substTyAt index (types.map (Ty.shiftV 1 0)) (effects.map (Eff.shiftV 1 0)) =
      getterCall (mapStepTypes (substTypeAt index types effects) step) := by
  simp only [getterCall, Comp.substTyAt, Val.substTyAt, Val.substTyAtList, List.map_nil, mapStepTypes,
    shiftTs, List.map_map, Function.comp_def]
  congr 2
  apply List.map_congr_left
  intro type member
  simpa only [Ty.shiftV_eq_renameTy] using type_subst_shift type index types effects 1 0

private theorem getter_ranges (step : PredicateAccessorTargets.Step) (ranges : Nat → RangeIx) :
    (getterCall step).mapRangesN ranges = getterCall (mapStepTypes (Ty.mapRanges ranges) step) := by
  simp only [getterCall, Comp.mapRangesN, Val.mapRangesN, Val.mapRangesListN, List.map_nil, mapStepTypes,
    shiftTs, List.map_map, Function.comp_def]
  congr 2
  apply List.map_congr_left
  intro type member
  exact OpenRangeRename.ty_mapRanges_shift type ranges 1 0

private theorem getter_shiftE (step : PredicateAccessorTargets.Step) (count cutoff : Nat) :
    (getterCall step).shiftEAt count cutoff = getterCall (mapStepTypes (shiftTypes count cutoff) step) := by
  simp only [getterCall, Comp.shiftEAt, Val.shiftEAt, Val.shiftEListAt, List.map_nil, mapStepTypes,
    shiftTs, List.map_map, Function.comp_def]
  congr 2
  apply List.map_congr_left
  intro type member
  simpa only [Ty.shiftV_eq_renameTy] using shiftTypes_renameTy type count cutoff (shiftIndex 1 0)

private theorem getter_subst (step : PredicateAccessorTargets.Step) (images : Nat → Val) (locals : Nat → LocalRef) :
    (getterCall step).subst (upSubst 1 images) (upLocalSubst 1 locals) =
      getterCall (mapStepTypes (substTyValues images) step) := by
  simp only [getterCall, Comp.subst, Val.subst, Val.substList, List.map_nil, mapStepTypes,
    shiftTs, List.map_map, Function.comp_def, upSubst, Nat.zero_lt_succ, ite_true]
  congr 2
  apply List.map_congr_left
  intro type member
  exact Ty.bind_shiftV_values type 1 images

/-- 改名は、同じ元の宣言へ照合されたgetterの列を保つ。 -/
theorem GetterCode.rename {source body root steps} (getters : GetterCode source body root steps) (rename : Nat → Nat) :
    GetterCode source (body.rename rename) (root.rename rename) (steps.map (mapStepTypes (renameTy rename))) := by
  induction getters with
  | value value => exact .value _
  | @accessor step body root steps field missing accessor found selected sort count child ih =>
    simp only [Comp.rename, getter_rename]
    simpa only [List.map_append, List.map_cons, List.map_nil] using
      GetterCode.accessor (step := mapStepTypes (renameTy rename) step) missing accessor found selected sort
        (by simpa only [mapStepTypes, List.length_map] using count) ih

/-- 型具体化は、同じ元の宣言へ照合されたgetterの列を保つ。 -/
theorem GetterCode.substTy {source body root steps} (getters : GetterCode source body root steps)
    (index : Nat) (types : List Ty) (effects : List Eff) :
    GetterCode source (body.substTyAt index types effects) (root.substTyAt index types effects)
      (steps.map (mapStepTypes (substTypeAt index types effects))) := by
  induction getters with
  | value value => exact .value _
  | @accessor step body root steps field missing accessor found selected sort count child ih =>
    simp only [Comp.substTyAt, getter_type]
    simpa only [List.map_append, List.map_cons, List.map_nil] using
      GetterCode.accessor (step := mapStepTypes (substTypeAt index types effects) step) missing accessor found selected sort
        (by simpa only [mapStepTypes, List.length_map] using count) ih

/-- 範囲具体化は、同じ元の宣言へ照合されたgetterの列を保つ。 -/
theorem GetterCode.mapRanges {source body root steps} (getters : GetterCode source body root steps) (ranges : Nat → RangeIx) :
    GetterCode source (body.mapRangesN ranges) (root.mapRangesN ranges)
      (steps.map (mapStepTypes (Ty.mapRanges ranges))) := by
  induction getters with
  | value value => exact .value _
  | @accessor step body root steps field missing accessor found selected sort count child ih =>
    simp only [Comp.mapRangesN, getter_ranges]
    simpa only [List.map_append, List.map_cons, List.map_nil] using
      GetterCode.accessor (step := mapStepTypes (Ty.mapRanges ranges) step) missing accessor found selected sort
        (by simpa only [mapStepTypes, List.length_map] using count) ih

/-- 型変数の追加は、同じ元の宣言へ照合されたgetterの列を保つ。 -/
theorem GetterCode.shiftE {source body root steps} (getters : GetterCode source body root steps) (count cutoff : Nat) :
    GetterCode source (body.shiftEAt count cutoff) (root.shiftEAt count cutoff)
      (steps.map (mapStepTypes (shiftTypes count cutoff))) := by
  induction getters with
  | value value => exact .value _
  | @accessor step body root steps field missing accessor found selected sort arity child ih =>
    simp only [Comp.shiftEAt, getter_shiftE]
    simpa only [List.map_append, List.map_cons, List.map_nil] using
      GetterCode.accessor (step := mapStepTypes (shiftTypes count cutoff) step) missing accessor found selected sort
        (by simpa only [mapStepTypes, List.length_map] using arity) ih

/-- 値置換は、同じ元の宣言へ照合されたgetterの列を保つ。 -/
theorem GetterCode.subst {source body root steps} (getters : GetterCode source body root steps)
    (images : Nat → Val) (locals : Nat → LocalRef) :
    GetterCode source (body.subst images locals) (root.subst images locals)
      (steps.map (mapStepTypes (substTyValues images))) := by
  induction getters with
  | value value => exact .value _
  | @accessor step body root steps field missing accessor found selected sort count child ih =>
    simp only [Comp.subst, getter_subst]
    simpa only [List.map_append, List.map_cons, List.map_nil] using
      GetterCode.accessor (step := mapStepTypes (substTyValues images) step) missing accessor found selected sort
        (by simpa only [mapStepTypes, List.length_map] using count) ih

/-- 固定の定数と、同じ受け手の同じ欄を読む引数のソース順の列。var0は欄の葉を示す記号である。 -/
inductive ProjectionArguments (source : Program) (root : Val) (steps : List PredicateAccessorTargets.Step) :
    List Comp → List Val → Prop
  | nil : ProjectionArguments source root steps [] []
  | constant {rest values} (value : Const) : ProjectionArguments source root steps rest values →
      ProjectionArguments source root steps (.ret (.const value) :: rest) (.const value :: values)
  | target {body rest values} : GetterCode source body root steps → ProjectionArguments source root steps rest values →
      ProjectionArguments source root steps (body :: rest) (.var 0 :: values)

/-- 投影引数の改名は、同じ固定条件と欄の対象を残す。 -/
theorem ProjectionArguments.rename {source root steps computations values}
    (arguments : ProjectionArguments source root steps computations values) (rename : Nat → Nat) :
    ProjectionArguments source (root.rename rename) (steps.map (mapStepTypes (renameTy rename)))
      (computations.map (Comp.rename rename)) values := by
  induction arguments with
  | nil => exact .nil
  | constant value tail ih => exact .constant value ih
  | target head tail ih => exact .target (head.rename rename) ih

/-- 投影引数の型具体化は、同じ固定条件と欄の対象を残す。 -/
theorem ProjectionArguments.substTy {source root steps computations values}
    (arguments : ProjectionArguments source root steps computations values) (index : Nat) (types : List Ty) (effects : List Eff) :
    ProjectionArguments source (root.substTyAt index types effects)
      (steps.map (mapStepTypes (substTypeAt index types effects)))
      (computations.map (Comp.substTyAt index types effects)) values := by
  induction arguments with
  | nil => exact .nil
  | constant value tail ih => exact .constant value ih
  | target head tail ih => exact .target (head.substTy index types effects) ih

/-- 投影引数の範囲具体化は、同じ固定条件と欄の対象を残す。 -/
theorem ProjectionArguments.mapRanges {source root steps computations values}
    (arguments : ProjectionArguments source root steps computations values) (ranges : Nat → RangeIx) :
    ProjectionArguments source (root.mapRangesN ranges) (steps.map (mapStepTypes (Ty.mapRanges ranges)))
      (computations.map (Comp.mapRangesN ranges)) values := by
  induction arguments with
  | nil => exact .nil
  | constant value tail ih => exact .constant value ih
  | target head tail ih => exact .target (head.mapRanges ranges) ih

/-- 投影引数への型変数の追加は、同じ固定条件と欄の対象を残す。 -/
theorem ProjectionArguments.shiftE {source root steps computations values}
    (arguments : ProjectionArguments source root steps computations values) (count cutoff : Nat) :
    ProjectionArguments source (root.shiftEAt count cutoff) (steps.map (mapStepTypes (shiftTypes count cutoff)))
      (computations.map (Comp.shiftEAt count cutoff)) values := by
  induction arguments with
  | nil => exact .nil
  | constant value tail ih => exact .constant value ih
  | target head tail ih => exact .target (head.shiftE count cutoff) ih

/-- 投影引数の値置換は、同じ固定条件と欄の対象を残す。 -/
theorem ProjectionArguments.subst {source root steps computations values}
    (arguments : ProjectionArguments source root steps computations values) (images : Nat → Val) (locals : Nat → LocalRef) :
    ProjectionArguments source (root.subst images locals) (steps.map (mapStepTypes (substTyValues images)))
      (computations.map (fun computation => computation.subst images locals)) values := by
  induction arguments with
  | nil => exact .nil
  | constant value tail ih => exact .constant value ih
  | target head tail ih => exact .target (head.subst images locals) ih

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
