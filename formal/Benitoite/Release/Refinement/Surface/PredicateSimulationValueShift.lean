import Benitoite.Release.Refinement.TypeShiftExchange
import Benitoite.Release.Refinement.TypeValueExchange

/-! # 管理用の束縛を越える値置換 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem shift_before (count cutoff binders : Nat) :
    (fun i => shiftIndex count cutoff i + binders) =
      (fun i => shiftIndex count (cutoff+binders) (i+binders)) := by
  funext i
  simp only [shiftIndex]
  split <;> split <;> omega

private theorem values_shift_up {count cutoff : Nat} {left right : Nat → Val}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) (n : Nat) :
    ∀ i, upSubst n left (shiftIndex count (cutoff+n) i) =
      (upSubst n right i).rename (shiftIndex count (cutoff+n)) := by
  intro i
  by_cases low : i<n
  · simp [upSubst, low, Val.rename, shiftIndex, show i<cutoff+n by omega]
  · have moved : shiftIndex count (cutoff+n) i = shiftIndex count cutoff (i-n)+n := by
      simp only [shiftIndex]
      split <;> split <;> omega
    simp only [moved, upSubst, low, show ¬ shiftIndex count cutoff (i-n)+n<n by omega,
      ite_false, Nat.add_sub_cancel, same, Val.rename_compose, shift_before]

private theorem locals_shift_up {count cutoff : Nat} {left right : Nat → LocalRef}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) (n : Nat) :
    ∀ i, upLocalSubst n left (shiftIndex count (cutoff+n) i) =
      (upLocalSubst n right i).rename (shiftIndex count (cutoff+n)) := by
  intro i
  by_cases low : i<n
  · simp [upLocalSubst, low, shiftIndex, show i<cutoff+n by omega, LocalRef.rename]
  · have moved : shiftIndex count (cutoff+n) i = shiftIndex count cutoff (i-n)+n := by
      simp only [shiftIndex]
      split <;> split <;> omega
    simp only [moved, upLocalSubst, low, show ¬ shiftIndex count cutoff (i-n)+n<n by omega,
      ite_false, Nat.add_sub_cancel, same]
    cases right (i-n) with
    | loc location => rfl
    | bound index => exact congrArg LocalRef.bound (congrFun (shift_before count cutoff n) index)

private theorem environments_shift {count cutoff : Nat} {left right : Nat → Val}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) :
    (fun i => ((some (.var (shiftIndex count cutoff i)) : Option Term).bind (termBind? (valEnv left).values))) =
      (fun i => ((valEnv right).values i).bind (termBind? (fun j => some (.var (shiftIndex count cutoff j))))) := by
  funext i
  simp only [Option.bind_some, termBind?, valEnv, same, Val.toTerm_rename, map_rename_eq_bind]

private theorem type_value_shift (a : Ty) {count cutoff : Nat} {left right : Nat → Val}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) :
    substTyValues left (renameTy (shiftIndex count cutoff) a) =
      renameTy (shiftIndex count cutoff) (substTyValues right a) := by
  unfold substTyValues Ty.bind
  change (Ty.rawBind (SubstEnv.valuesOnly (valEnv left).values) (renameTy (shiftIndex count cutoff) a)).norm =
    renameTy (shiftIndex count cutoff) (Ty.rawBind (SubstEnv.valuesOnly (valEnv right).values) a).norm
  simp only [SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind]
  rw [renameTy_eq_rawSubstV]
  change ((a.rawSubstV (fun i => some (.var (shiftIndex count cutoff i)))).rawSubstV
      (valEnv left).values).norm = renameTy (shiftIndex count cutoff) (a.rawSubstV (valEnv right).values).norm
  rw [← Ty.shiftV_eq_renameTy, ← Ty.norm_shiftV, Ty.shiftV_eq_renameTy,
    renameTy_eq_rawSubstV, Ty.rawSubstV_comp, Ty.rawSubstV_comp, environments_shift same]

private theorem effect_value_shift (effect : Eff) {count cutoff : Nat} {left right : Nat → Val}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) :
    substEffValues left (renameEff (shiftIndex count cutoff) effect) =
      renameEff (shiftIndex count cutoff) (substEffValues right effect) := by
  unfold substEffValues Eff.bind
  change (Eff.rawBind (SubstEnv.valuesOnly (valEnv left).values) (renameEff (shiftIndex count cutoff) effect)).norm =
    renameEff (shiftIndex count cutoff) (Eff.rawBind (SubstEnv.valuesOnly (valEnv right).values) effect).norm
  simp only [SubstEnv.valuesOnly, ← Eff.rawSubstV_eq_rawBind]
  rw [renameEff_eq_rawSubstV]
  change (Eff.rawSubstV (valEnv left).values
      (Eff.rawSubstV (fun i => some (.var (shiftIndex count cutoff i))) effect)).norm =
    renameEff (shiftIndex count cutoff) (Eff.rawSubstV (valEnv right).values effect).norm
  rw [← Eff.shiftV_eq_renameEff, ← Eff.norm_shiftV, Eff.shiftV_eq_renameEff,
    renameEff_eq_rawSubstV, Eff.rawSubstV_comp, Eff.rawSubstV_comp, environments_shift same]

private theorem telescope_value_shift (telescope : Tel) {count cutoff : Nat} {left right : Nat → Val}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) :
    Tel.bind (valEnv left) (Tel.rawBind (renEnv (shiftIndex count cutoff)) telescope) =
      Tel.rawBind (renEnv (shiftIndex count cutoff)) (Tel.bind (valEnv right) telescope) := by
  have normalized (t : Tel) :
      (Tel.rawSubstV (fun i => some (.var (shiftIndex count cutoff i))) t).norm =
        Tel.rawSubstV (fun i => some (.var (shiftIndex count cutoff i))) t.norm := by
    simpa only [Tel.shiftV_eq_rawBind, renEnv, ← Tel.rawSubstV_eq_rawBind] using Tel.norm_shiftV t count cutoff
  unfold Tel.bind
  simp only [valEnv, renEnv, ← Tel.rawSubstV_eq_rawBind]
  rw [← normalized]
  simp only [Tel.rawSubstV_comp]
  exact congrArg (fun values => (Tel.rawSubstV values telescope).norm) (environments_shift same)

private theorem kind_value_shift (kind : BuilderKind) {count cutoff : Nat} {left right : Nat → Val}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) :
    substKind left (renameKind (shiftIndex count cutoff) kind) =
      renameKind (shiftIndex count cutoff) (substKind right kind) := by
  cases kind <;> simp only [substKind, renameKind, type_value_shift _ same]

private theorem local_value_shift (reference : LocalRef) {count cutoff : Nat} {left right : Nat → LocalRef}
    (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff)) :
    (reference.rename (shiftIndex count cutoff)).subst left =
      (reference.subst right).rename (shiftIndex count cutoff) := by
  cases reference <;> first | rfl | exact same _

mutual
  /-- 値置換の像を同じシフトで比較すると、値全体の型注釈と本体も一致する。 -/
  theorem value_substitution_shift (value : Val) (count cutoff : Nat) (left right : Nat → Val)
      (localLeft localRight : Nat → LocalRef)
      (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff))
      (locals : ∀ i, localLeft (shiftIndex count cutoff i) = (localRight i).rename (shiftIndex count cutoff)) :
      (value.rename (shiftIndex count cutoff)).subst left localLeft =
        (value.subst right localRight).rename (shiftIndex count cutoff) := by
    cases value
    case var i => exact same i
    case lam names parameters body =>
      simp only [Val.rename, Val.subst, List.map_map, Function.comp_def, type_value_shift _ same,
        List.length_map, upRen_shiftIndex]
      rw [code_substitution_shift body _ _ _ _ _ _ (values_shift_up same _) (locals_shift_up locals _)]
    case dependentLam telescope body =>
      simp only [Val.rename, Val.subst, telescope_value_shift _ same, telBinders_rawBind, telBinders_bind,
        upRen_shiftIndex]
      rw [code_substitution_shift body _ _ _ _ _ _ (values_shift_up same _) (locals_shift_up locals _)]
    all_goals simp only [Val.rename, Val.subst, List.map_map, Function.comp_def,
      type_value_shift _ same, effect_value_shift _ same,
      value_substitution_shift _ _ _ _ _ _ _ same locals,
      values_substitution_shift _ _ _ _ _ _ _ same locals]
  termination_by structural value
  theorem values_substitution_shift (values : List Val) (count cutoff : Nat) (left right : Nat → Val)
      (localLeft localRight : Nat → LocalRef)
      (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff))
      (locals : ∀ i, localLeft (shiftIndex count cutoff i) = (localRight i).rename (shiftIndex count cutoff)) :
      Val.substList left (Val.renameList (shiftIndex count cutoff) values) localLeft =
        Val.renameList (shiftIndex count cutoff) (Val.substList right values localRight) := by
    cases values <;> simp only [Val.renameList, Val.substList,
      value_substitution_shift _ _ _ _ _ _ _ same locals,
      values_substitution_shift _ _ _ _ _ _ _ same locals]
  termination_by structural values
  theorem code_substitution_shift (computation : Comp) (count cutoff : Nat) (left right : Nat → Val)
      (localLeft localRight : Nat → LocalRef)
      (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff))
      (locals : ∀ i, localLeft (shiftIndex count cutoff i) = (localRight i).rename (shiftIndex count cutoff)) :
      (computation.rename (shiftIndex count cutoff)).subst left localLeft =
        (computation.subst right localRight).rename (shiftIndex count cutoff) := by
    cases computation
    case builderLet kind body =>
      simp only [Comp.rename, Comp.subst, kind_value_shift _ same, upRen_shiftIndex]
      rw [code_substitution_shift body _ _ _ _ _ _ (values_shift_up same _) (locals_shift_up locals _)]
    case letIn body rest =>
      simp only [Comp.rename, Comp.subst, code_substitution_shift body _ _ _ _ _ _ same locals, upRen_shiftIndex]
      rw [code_substitution_shift rest _ _ _ _ _ _ (values_shift_up same _) (locals_shift_up locals _)]
    case checkAt kind name shape bases pattern input range =>
      cases bases <;> simp only [Comp.rename, Comp.subst, type_value_shift _ same,
        value_substitution_shift _ _ _ _ _ _ _ same locals]
    all_goals simp only [Comp.rename, Comp.subst, List.map_map, Function.comp_def,
      kind_value_shift _ same, local_value_shift _ locals, type_value_shift _ same, effect_value_shift _ same,
      value_substitution_shift _ _ _ _ _ _ _ same locals, values_substitution_shift _ _ _ _ _ _ _ same locals,
      code_substitution_shift _ _ _ _ _ _ _ same locals, arms_substitution_shift _ _ _ _ _ _ _ same locals,
      clauses_substitution_shift _ _ _ _ _ _ _ same locals]
  termination_by structural computation
  theorem arms_substitution_shift (arms : List Arm) (count cutoff : Nat) (left right : Nat → Val)
      (localLeft localRight : Nat → LocalRef)
      (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff))
      (locals : ∀ i, localLeft (shiftIndex count cutoff i) = (localRight i).rename (shiftIndex count cutoff)) :
      Arm.substList left (Arm.renameList (shiftIndex count cutoff) arms) localLeft =
        Arm.renameList (shiftIndex count cutoff) (Arm.substList right arms localRight) := by
    cases arms with
    | nil => rfl
    | cons arm rest =>
      cases arm with
      | mk alternatives guard body =>
        cases guard <;> simp only [Arm.renameList, Arm.substList, upRen_shiftIndex,
          arms_substitution_shift rest _ _ _ _ _ _ same locals,
          code_substitution_shift _ _ _ _ _ _ _ (values_shift_up same _) (locals_shift_up locals _)]
  termination_by structural arms
  theorem clauses_substitution_shift (clauses : List Clause) (count cutoff : Nat) (left right : Nat → Val)
      (localLeft localRight : Nat → LocalRef)
      (same : ∀ i, left (shiftIndex count cutoff i) = (right i).rename (shiftIndex count cutoff))
      (locals : ∀ i, localLeft (shiftIndex count cutoff i) = (localRight i).rename (shiftIndex count cutoff)) :
      Clause.substList left (Clause.renameList (shiftIndex count cutoff) clauses) localLeft =
        Clause.renameList (shiftIndex count cutoff) (Clause.substList right clauses localRight) := by
    cases clauses with
    | nil => rfl
    | cons clause rest =>
      cases clause with
      | mk operation arity ntys body =>
        have lifted : ∀ i, (left (shiftIndex count cutoff i)).shiftEAt ntys 0 =
            ((right i).shiftEAt ntys 0).rename (shiftIndex count cutoff) := by
          intro i; rw [same, Val.shiftEAt_rename]
        simp only [Clause.renameList, Clause.substList, upRen_shiftIndex,
          clauses_substitution_shift rest _ _ _ _ _ _ same locals,
          code_substitution_shift body _ _ _ _ _ _ (values_shift_up (left := fun i => (left i).shiftEAt ntys 0) (right := fun i => (right i).shiftEAt ntys 0) lifted _) (locals_shift_up locals _)]
      | fail error body =>
        have lifted : ∀ i, (left (shiftIndex count cutoff i)).shiftEAt 1 0 =
            ((right i).shiftEAt 1 0).rename (shiftIndex count cutoff) := by
          intro i; rw [same, Val.shiftEAt_rename]
        simp only [Clause.renameList, Clause.substList, upRen_shiftIndex, type_value_shift _ same,
          clauses_substitution_shift rest _ _ _ _ _ _ same locals,
          code_substitution_shift body _ _ _ _ _ _ (values_shift_up (left := fun i => (left i).shiftEAt 1 0) (right := fun i => (right i).shiftEAt 1 0) lifted _) (locals_shift_up locals _)]
  termination_by structural clauses
end

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
