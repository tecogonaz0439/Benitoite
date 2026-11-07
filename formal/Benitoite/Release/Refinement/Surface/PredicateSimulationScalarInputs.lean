import Benitoite.Release.Refinement.Surface.PredicateCalls
import Benitoite.Release.Refinement.ValueRenameAlgebra
import Benitoite.Release.Refinement.Surface.OpenRangeRename
import Benitoite.Release.Refinement.Surface.PredicateSimulationTypeShift
import Benitoite.Release.Refinement.TypeShiftExchange
import Benitoite.Release.Refinement.Surface.PredicateSimulationValueShift

/-! # 公開判定の固定した条件と、ソース順の値引数 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

/-- 宣言順へ並べた公開引数と、内部行が直接読む同じ対象。 -/
inductive ScalarInputs : API → Entry → List Val → Val → Prop
  | path {text pattern value} : parseAtPattern .path (.const (.string text)) = some (.path pattern) →
      ScalarInputs .path (.path pattern) [.const (.string text), value] value
  | host {text pattern value} : parseAtPattern .host (.const (.string text)) = some (.host pattern) →
      ScalarInputs .host (.host pattern) [.const (.string text), value] value
  | characters (lo hi value) : ScalarInputs .characters (.characters lo hi)
      [value, .const (.character lo), .const (.character hi)] value
  | floating (width test value) : ScalarInputs (.floating width test) (.floating width test) [value] value

/-- 元の公開呼出しは、ソース順に値を束縛してから宣言順へ並べる。 -/
def scalarCall (api : API) (positions : List Nat) (values : List Val) : Comp :=
  letChain 0 (values.map Comp.ret)
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit)))

/-- 固定した条件の定数を保つ写像は、同じ公開判定と対象の関係を保つ。 -/
theorem ScalarInputs.map {api entry values value} (h : ScalarInputs api entry values value)
    (f : Val → Val) (constants : ∀ c, f (.const c) = .const c) :
    ScalarInputs api entry (values.map f) (f value) := by
  cases h with
  | path parsed => simpa only [List.map_cons, List.map_nil, constants] using ScalarInputs.path (value := f value) parsed
  | host parsed => simpa only [List.map_cons, List.map_nil, constants] using ScalarInputs.host (value := f value) parsed
  | characters lo hi value => simpa only [List.map_cons, List.map_nil, constants] using ScalarInputs.characters lo hi (f value)
  | floating width test value => exact ScalarInputs.floating width test (f value)

private theorem fieldAt_map {α β : Type} (f : α → β) (index : Nat) (positions : List Nat) (values : List α) :
    fieldAt index positions (values.map f) = (fieldAt index positions values).map f := by
  induction positions generalizing values with
  | nil => rfl
  | cons position positions ih =>
    cases values with
    | nil => rfl
    | cons value values =>
      simp only [List.map_cons, fieldAt]
      split <;> simp_all

/-- 引数を位置表で並べる操作は、値ごとの写像と可換である。 -/
theorem recordFields_map {α β : Type} (f : α → β) (count : Nat) (positions : List Nat)
    (values : List α) (fallback : α) :
    (recordFields count positions values fallback).map f =
      recordFields count positions (values.map f) (f fallback) := by
  simp only [recordFields, List.map_map, Function.comp_def, fieldAt_map]
  apply List.map_congr_left
  intro index member
  cases fieldAt index positions values <;> rfl

private theorem upRen_add (n m : Nat) (rename : Nat → Nat) :
    upRen n (upRen m rename) = upRen (m+n) rename := by
  funext index
  by_cases first : index < n
  · simp [upRen, first, show index < m+n by omega]
  · by_cases second : index-n < m
    · simp [upRen, first, second, show index < m+n by omega]
      omega
    · simp only [upRen, first, second, show ¬ index < m+n by omega, ite_false]
      rw [show index-n-m = index-(m+n) by omega]
      omega

private theorem rename_shift (m : Comp) (depth : Nat) (rename : Nat → Nat) :
    (m.rename (· + depth)).rename (upRen depth rename) = (m.rename rename).rename (· + depth) := by
  simp only [Comp.rename_compose]
  congr 1
  funext index
  simp [upRen, show ¬ index+depth < depth by omega]

private theorem letChain_rename (depth : Nat) (computations : List Comp) (body : Comp) (rename : Nat → Nat) :
    (letChain depth computations body).rename (upRen depth rename) =
      letChain depth (computations.map (Comp.rename rename))
        (body.rename (upRen (depth+computations.length) rename)) := by
  induction computations generalizing depth with
  | nil => simp only [letChain, List.map_nil, List.length_nil, Nat.add_zero]
  | cons head tail ih =>
    simp only [letChain, Comp.rename, List.map_cons, List.length_cons, rename_shift,
      upRen_add, ih, Nat.add_assoc, Nat.add_comm 1]

private theorem renameList_map (rename : Nat → Nat) (values : List Val) :
    Val.renameList rename values = values.map (Val.rename rename) := by
  induction values with
  | nil => rfl
  | cons value values ih => simp only [Val.renameList, List.map_cons, ih]

private theorem boundVars_rename (count : Nat) (rename : Nat → Nat) :
    Val.renameList (upRen count rename) (boundVars count) = boundVars count := by
  simp only [renameList_map, boundVars, List.map_map, Function.comp_def]
  apply List.map_congr_left
  intro index member
  have range : index < count := List.mem_range.mp (List.mem_reverse.mp member)
  simp [Val.rename, upRen, range]

/-- 公開呼出しの管理用の束縛は、外側の値の改名に追随する。 -/
theorem scalarCall_rename (api : API) (positions : List Nat) (values : List Val) (rename : Nat → Nat) :
    (scalarCall api positions values).rename rename = scalarCall api positions (Val.renameList rename values) := by
  have zero : upRen 0 rename = rename := by funext i; simp [upRen]
  have fields := recordFields_map (Val.rename (upRen values.length rename)) api.inputs.length positions
    (boundVars values.length) (.const .unit)
  have fixed : Val.renameList (upRen values.length rename)
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars values.length) (.const .unit) := by
    simpa only [← renameList_map, boundVars_rename, Val.rename] using fields
  have chain := letChain_rename 0 (values.map Comp.ret)
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))) rename
  simpa only [scalarCall, zero, Nat.zero_add, List.length_map, Comp.rename, Val.rename,
    List.map_nil, fixed, renameList_map, List.map_map, Function.comp_def] using chain


private theorem range_shift (m : Comp) (depth : Nat) (ranges : Nat → RangeIx) :
    (m.rename (· + depth)).mapRangesN ranges = (m.mapRangesN ranges).rename (· + depth) := by
  have shift : shiftIndex depth 0 = (· + depth) := by funext index; simp [shiftIndex]
  simpa only [shift] using OpenRangeRename.comp_mapRanges_shift m ranges depth 0

private theorem letChain_ranges (depth : Nat) (computations : List Comp) (body : Comp)
    (ranges : Nat → RangeIx) :
    (letChain depth computations body).mapRangesN ranges =
      letChain depth (computations.map (Comp.mapRangesN ranges)) (body.mapRangesN ranges) := by
  induction computations generalizing depth with
  | nil => rfl
  | cons head tail ih => simp only [letChain, Comp.mapRangesN, List.map_cons, range_shift, ih]

private theorem rangesList_map (ranges : Nat → RangeIx) (values : List Val) :
    Val.mapRangesListN ranges values = values.map (Val.mapRangesN ranges) := by
  induction values with
  | nil => rfl
  | cons value values ih => simp only [Val.mapRangesListN, List.map_cons, ih]

private theorem boundVars_ranges (count : Nat) (ranges : Nat → RangeIx) :
    Val.mapRangesListN ranges (boundVars count) = boundVars count := by
  simp only [rangesList_map, boundVars, List.map_map, Function.comp_def]
  rfl

/-- 範囲の具体化は、同じソース順の公開引数を具体化する。 -/
theorem scalarCall_mapRanges (api : API) (positions : List Nat) (values : List Val) (ranges : Nat → RangeIx) :
    (scalarCall api positions values).mapRangesN ranges =
      scalarCall api positions (Val.mapRangesListN ranges values) := by
  have fields := recordFields_map (Val.mapRangesN ranges) api.inputs.length positions
    (boundVars values.length) (.const .unit)
  have fixed : Val.mapRangesListN ranges
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars values.length) (.const .unit) := by
    simpa only [← rangesList_map, boundVars_ranges, Val.mapRangesN] using fields
  have chain := letChain_ranges 0 (values.map Comp.ret)
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))) ranges
  simpa only [scalarCall, List.length_map, Comp.mapRangesN, Val.mapRangesN, List.map_nil,
    fixed, rangesList_map, List.map_map, Function.comp_def] using chain

private theorem effect_shift_add (effect : Eff) (m n : Nat) :
    (effect.shiftV m 0).shiftV n 0 = effect.shiftV (m+n) 0 := by
  simp only [Eff.shiftV_eq_renameEff, renameEff_comp]
  congr 1
  funext index
  simp [shiftIndex, Nat.add_assoc]

private theorem letChain_type (depth : Nat) (computations : List Comp) (body : Comp)
    (index : Nat) (types : List Ty) (effects : List Eff) :
    (letChain depth computations body).substTyAt index
        (types.map (Ty.shiftV depth 0)) (effects.map (Eff.shiftV depth 0)) =
      letChain depth (computations.map (Comp.substTyAt index types effects))
        (body.substTyAt index (types.map (Ty.shiftV (depth+computations.length) 0))
          (effects.map (Eff.shiftV (depth+computations.length) 0))) := by
  induction computations generalizing depth with
  | nil => simp only [letChain, List.map_nil, List.length_nil, Nat.add_zero]
  | cons head tail ih =>
    have shift : shiftIndex depth 0 = (· + depth) := by funext i; simp [shiftIndex]
    simp only [letChain, Comp.substTyAt, List.map_cons, List.length_cons,
      ← shift, code_type_shift, List.map_map, Function.comp_def, Ty.shiftV_add, effect_shift_add]
    rw [ih]
    simp only [Nat.add_assoc, Nat.add_comm 1]

private theorem typeList_map (index : Nat) (types : List Ty) (effects : List Eff) (values : List Val) :
    Val.substTyAtList index types effects values = values.map (Val.substTyAt index types effects) := by
  induction values with
  | nil => rfl
  | cons value values ih => simp only [Val.substTyAtList, List.map_cons, ih]

private theorem boundVars_type (count index : Nat) (types : List Ty) (effects : List Eff) :
    Val.substTyAtList index types effects (boundVars count) = boundVars count := by
  simp only [typeList_map, boundVars, List.map_map, Function.comp_def]
  rfl

/-- 型の具体化は、同じソース順の公開引数の型注釈を具体化する。 -/
theorem scalarCall_substTy (api : API) (positions : List Nat) (values : List Val)
    (index : Nat) (types : List Ty) (effects : List Eff) :
    (scalarCall api positions values).substTyAt index types effects =
      scalarCall api positions (Val.substTyAtList index types effects values) := by
  have zeroTypes : types.map (Ty.shiftV 0 0) = types := by
    simpa only [show Ty.shiftV 0 0 = id from funext (fun a => a.shiftV_zero 0)] using List.map_id types
  have zeroEffects : effects.map (Eff.shiftV 0 0) = effects := by
    simpa only [show Eff.shiftV 0 0 = id from funext (fun e => e.shiftV_zero 0)] using List.map_id effects
  have fields := recordFields_map (Val.substTyAt index (types.map (Ty.shiftV values.length 0))
    (effects.map (Eff.shiftV values.length 0))) api.inputs.length positions (boundVars values.length) (.const .unit)
  have fixed : Val.substTyAtList index (types.map (Ty.shiftV values.length 0))
      (effects.map (Eff.shiftV values.length 0))
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars values.length) (.const .unit) := by
    simpa only [← typeList_map, boundVars_type, Val.substTyAt] using fields
  have chain := letChain_type 0 (values.map Comp.ret)
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))) index types effects
  simpa only [scalarCall, zeroTypes, zeroEffects, Nat.zero_add, List.length_map,
    Comp.substTyAt, Val.substTyAt, List.map_nil, fixed, typeList_map,
    List.map_map, Function.comp_def] using chain

private theorem letChain_shiftE (depth : Nat) (computations : List Comp) (body : Comp) (count cutoff : Nat) :
    (letChain depth computations body).shiftEAt count cutoff =
      letChain depth (computations.map (Comp.shiftEAt count cutoff)) (body.shiftEAt count cutoff) := by
  induction computations generalizing depth with
  | nil => rfl
  | cons head tail ih => simp only [letChain, Comp.shiftEAt, Comp.shiftEAt_rename, List.map_cons, ih]

private theorem shiftEList_map (count cutoff : Nat) (values : List Val) :
    Val.shiftEListAt count cutoff values = values.map (Val.shiftEAt count cutoff) := by
  induction values with
  | nil => rfl
  | cons value values ih => simp only [Val.shiftEListAt, List.map_cons, ih]

private theorem boundVars_shiftE (count typeCount cutoff : Nat) :
    Val.shiftEListAt typeCount cutoff (boundVars count) = boundVars count := by
  simp only [shiftEList_map, boundVars, List.map_map, Function.comp_def]
  rfl

/-- 型変数の追加は、公開引数にある型注釈へ同じ追加を行う。 -/
theorem scalarCall_shiftE (api : API) (positions : List Nat) (values : List Val) (count cutoff : Nat) :
    (scalarCall api positions values).shiftEAt count cutoff =
      scalarCall api positions (Val.shiftEListAt count cutoff values) := by
  have fields := recordFields_map (Val.shiftEAt count cutoff) api.inputs.length positions
    (boundVars values.length) (.const .unit)
  have fixed : Val.shiftEListAt count cutoff
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars values.length) (.const .unit) := by
    simpa only [← shiftEList_map, boundVars_shiftE, Val.shiftEAt] using fields
  have chain := letChain_shiftE 0 (values.map Comp.ret)
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))) count cutoff
  simpa only [scalarCall, List.length_map, Comp.shiftEAt, Val.shiftEAt, List.map_nil,
    fixed, shiftEList_map, List.map_map, Function.comp_def] using chain

private theorem shift_substitution (body : Comp) (depth : Nat) (values : Nat → Val) (locals : Nat → LocalRef) :
    (body.rename (· + depth)).subst (upSubst depth values) (upLocalSubst depth locals) =
      (body.subst values locals).rename (· + depth) := by
  have shift : shiftIndex depth 0 = (· + depth) := by funext index; simp [shiftIndex]
  have images : ∀ i, upSubst depth values (shiftIndex depth 0 i) = (values i).rename (shiftIndex depth 0) := by
    intro i
    simp [shift, upSubst, show ¬i+depth<depth by omega]
  have references : ∀ i, upLocalSubst depth locals (shiftIndex depth 0 i) =
      (locals i).rename (shiftIndex depth 0) := by
    intro i
    simp [shift, upLocalSubst, show ¬i+depth<depth by omega]
  simpa only [shift] using code_substitution_shift body depth 0 _ _ _ _ images references

private theorem letChain_substitution (depth : Nat) (computations : List Comp) (body : Comp)
    (values : Nat → Val) (locals : Nat → LocalRef) :
    (letChain depth computations body).subst (upSubst depth values) (upLocalSubst depth locals) =
      letChain depth (computations.map (fun computation => computation.subst values locals))
        (body.subst (upSubst (depth+computations.length) values) (upLocalSubst (depth+computations.length) locals)) := by
  induction computations generalizing depth with
  | nil => simp only [letChain, List.map_nil, List.length_nil, Nat.add_zero]
  | cons head tail ih =>
    simp only [letChain, Comp.subst, shift_substitution, upSubst_add, upLocalSubst_add,
      List.map_cons, List.length_cons, ih, Nat.add_assoc, Nat.add_comm 1]

private theorem substitutionList_map (values : List Val) (images : Nat → Val) (locals : Nat → LocalRef) :
    Val.substList images values locals = values.map (fun value => value.subst images locals) := by
  induction values with
  | nil => rfl
  | cons value values ih => simp only [Val.substList, List.map_cons, ih]

private theorem boundVars_substitution (count : Nat) (images : Nat → Val) (locals : Nat → LocalRef) :
    Val.substList (upSubst count images) (boundVars count) (upLocalSubst count locals) = boundVars count := by
  simp only [substitutionList_map, boundVars, List.map_map, Function.comp_def]
  apply List.map_congr_left
  intro index member
  have low : index<count := List.mem_range.mp (List.mem_reverse.mp member)
  simp only [Val.subst, upSubst, low, ite_true]

/-- 値置換は、公開呼出しの全引数へソース順で作用する。 -/
theorem scalarCall_subst (api : API) (positions : List Nat) (values : List Val)
    (images : Nat → Val) (locals : Nat → LocalRef) :
    (scalarCall api positions values).subst images locals =
      scalarCall api positions (Val.substList images values locals) := by
  have fields := recordFields_map (fun value : Val => value.subst (upSubst values.length images)
    (upLocalSubst values.length locals)) api.inputs.length positions (boundVars values.length) (.const .unit)
  have fixed : Val.substList (upSubst values.length images)
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))
      (upLocalSubst values.length locals) =
      recordFields api.inputs.length positions (boundVars values.length) (.const .unit) := by
    simpa only [← substitutionList_map, boundVars_substitution, Val.subst] using fields
  have chain := letChain_substitution 0 (values.map Comp.ret)
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))) images locals
  simpa only [scalarCall, upSubst_zero, upLocalSubst_zero, Nat.zero_add, List.length_map,
    Comp.subst, Val.subst, List.map_nil, fixed, substitutionList_map,
    List.map_map, Function.comp_def] using chain

/-- 改名後も、宣言順の固定した条件と判定対象は同じである。 -/
theorem ScalarInputs.rename {api entry positions values value}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (rename : Nat → Nat) :
    ScalarInputs api entry (recordFields api.inputs.length positions (Val.renameList rename values) (.const .unit))
      (value.rename rename) := by
  simpa only [recordFields_map, Val.rename, ← renameList_map] using
    inputs.map (Val.rename rename) (fun _ => rfl)

/-- 型具体化後も、固定した条件の定数は変わらない。 -/
theorem ScalarInputs.substTy {api entry positions values value}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (index : Nat) (types : List Ty) (effects : List Eff) :
    ScalarInputs api entry (recordFields api.inputs.length positions (Val.substTyAtList index types effects values) (.const .unit))
      (value.substTyAt index types effects) := by
  simpa only [recordFields_map, Val.substTyAt, ← typeList_map] using
    inputs.map (Val.substTyAt index types effects) (fun _ => rfl)

/-- 範囲具体化後も、固定した条件の定数は変わらない。 -/
theorem ScalarInputs.mapRanges {api entry positions values value}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (ranges : Nat → RangeIx) :
    ScalarInputs api entry (recordFields api.inputs.length positions (Val.mapRangesListN ranges values) (.const .unit))
      (value.mapRangesN ranges) := by
  simpa only [recordFields_map, Val.mapRangesN, ← rangesList_map] using
    inputs.map (Val.mapRangesN ranges) (fun _ => rfl)

/-- 型変数の追加後も、固定した条件の定数は変わらない。 -/
theorem ScalarInputs.shiftE {api entry positions values value}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (count cutoff : Nat) :
    ScalarInputs api entry (recordFields api.inputs.length positions (Val.shiftEListAt count cutoff values) (.const .unit))
      (value.shiftEAt count cutoff) := by
  simpa only [recordFields_map, Val.shiftEAt, ← shiftEList_map] using
    inputs.map (Val.shiftEAt count cutoff) (fun _ => rfl)

/-- 値置換後も、固定した条件を残して対象だけを同じ置換で読む。 -/
theorem ScalarInputs.subst {api entry positions values value}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (images : Nat → Val) (locals : Nat → LocalRef) :
    ScalarInputs api entry (recordFields api.inputs.length positions (Val.substList images values locals) (.const .unit))
      (value.subst images locals) := by
  simpa only [recordFields_map, Val.subst, ← substitutionList_map] using
    inputs.map (fun value => value.subst images locals) (fun _ => rfl)

/-- 一般のソース順の引数計算を束縛し、同じ公開判定の位置表で呼ぶ。 -/
def sourceCall (api : API) (positions : List Nat) (computations : List Comp) : Comp :=
  letChain 0 computations (.app (.prim api.name [] [] [])
    (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit)))

/-- 引数の計算を改名しても、公開呼出しの位置表と管理用の束縛を保つ。 -/
theorem sourceCall_rename (api : API) (positions : List Nat) (computations : List Comp) (rename : Nat → Nat) :
    (sourceCall api positions computations).rename rename =
      sourceCall api positions (computations.map (Comp.rename rename)) := by
  have zero : upRen 0 rename = rename := by funext i; simp [upRen]
  have fields := recordFields_map (Val.rename (upRen computations.length rename)) api.inputs.length positions
    (boundVars computations.length) (.const .unit)
  have fixed : Val.renameList (upRen computations.length rename)
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars computations.length) (.const .unit) := by
    simpa only [← renameList_map, boundVars_rename, Val.rename] using fields
  have chain := letChain_rename 0 computations
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))) rename
  simpa only [sourceCall, zero, Nat.zero_add, List.length_map, Comp.rename, Val.rename,
    List.map_nil, fixed] using chain

/-- 型具体化は、ソース順の全引数計算へ同じ具体化を行う。 -/
theorem sourceCall_substTy (api : API) (positions : List Nat) (computations : List Comp)
    (index : Nat) (types : List Ty) (effects : List Eff) :
    (sourceCall api positions computations).substTyAt index types effects =
      sourceCall api positions (computations.map (Comp.substTyAt index types effects)) := by
  have zeroTypes : types.map (Ty.shiftV 0 0) = types := by
    simpa only [show Ty.shiftV 0 0 = id from funext (fun a => a.shiftV_zero 0)] using List.map_id types
  have zeroEffects : effects.map (Eff.shiftV 0 0) = effects := by
    simpa only [show Eff.shiftV 0 0 = id from funext (fun e => e.shiftV_zero 0)] using List.map_id effects
  have fields := recordFields_map (Val.substTyAt index (types.map (Ty.shiftV computations.length 0))
    (effects.map (Eff.shiftV computations.length 0))) api.inputs.length positions (boundVars computations.length) (.const .unit)
  have fixed : Val.substTyAtList index (types.map (Ty.shiftV computations.length 0))
      (effects.map (Eff.shiftV computations.length 0))
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars computations.length) (.const .unit) := by
    simpa only [← typeList_map, boundVars_type, Val.substTyAt] using fields
  have chain := letChain_type 0 computations
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))) index types effects
  simpa only [sourceCall, zeroTypes, zeroEffects, Nat.zero_add, List.length_map,
    Comp.substTyAt, Val.substTyAt, List.map_nil, fixed] using chain

/-- 範囲具体化は、ソース順の全引数計算へ同じ具体化を行う。 -/
theorem sourceCall_mapRanges (api : API) (positions : List Nat) (computations : List Comp) (ranges : Nat → RangeIx) :
    (sourceCall api positions computations).mapRangesN ranges =
      sourceCall api positions (computations.map (Comp.mapRangesN ranges)) := by
  have fields := recordFields_map (Val.mapRangesN ranges) api.inputs.length positions
    (boundVars computations.length) (.const .unit)
  have fixed : Val.mapRangesListN ranges
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars computations.length) (.const .unit) := by
    simpa only [← rangesList_map, boundVars_ranges, Val.mapRangesN] using fields
  have chain := letChain_ranges 0 computations
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))) ranges
  simpa only [sourceCall, List.length_map, Comp.mapRangesN, Val.mapRangesN, List.map_nil, fixed] using chain

/-- 型変数の追加は、ソース順の全引数計算へ同じ追加を行う。 -/
theorem sourceCall_shiftE (api : API) (positions : List Nat) (computations : List Comp) (count cutoff : Nat) :
    (sourceCall api positions computations).shiftEAt count cutoff =
      sourceCall api positions (computations.map (Comp.shiftEAt count cutoff)) := by
  have fields := recordFields_map (Val.shiftEAt count cutoff) api.inputs.length positions
    (boundVars computations.length) (.const .unit)
  have fixed : Val.shiftEListAt count cutoff
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit)) =
      recordFields api.inputs.length positions (boundVars computations.length) (.const .unit) := by
    simpa only [← shiftEList_map, boundVars_shiftE, Val.shiftEAt] using fields
  have chain := letChain_shiftE 0 computations
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))) count cutoff
  simpa only [sourceCall, List.length_map, Comp.shiftEAt, Val.shiftEAt, List.map_nil, fixed] using chain

/-- 値置換は、ソース順の全引数計算へ同じ置換を行う。 -/
theorem sourceCall_subst (api : API) (positions : List Nat) (computations : List Comp)
    (images : Nat → Val) (locals : Nat → LocalRef) :
    (sourceCall api positions computations).subst images locals =
      sourceCall api positions (computations.map (fun computation => computation.subst images locals)) := by
  have fields := recordFields_map (fun value : Val => value.subst (upSubst computations.length images)
    (upLocalSubst computations.length locals)) api.inputs.length positions (boundVars computations.length) (.const .unit)
  have fixed : Val.substList (upSubst computations.length images)
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))
      (upLocalSubst computations.length locals) =
      recordFields api.inputs.length positions (boundVars computations.length) (.const .unit) := by
    simpa only [← substitutionList_map, boundVars_substitution, Val.subst] using fields
  have chain := letChain_substitution 0 computations
    (.app (.prim api.name [] [] [])
      (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))) images locals
  simpa only [sourceCall, upSubst_zero, upLocalSubst_zero, Nat.zero_add, List.length_map,
    Comp.subst, Val.subst, List.map_nil, fixed] using chain

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
