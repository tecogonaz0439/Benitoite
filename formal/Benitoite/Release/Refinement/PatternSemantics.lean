import Benitoite.Release.Refinement.PatternTransport

namespace Benitoite.Release.Refinement

theorem Inhabits.core {P a v} (h : Inhabits P a v) : Inhabits P a.core v := by
  match h with
  | .refined hs => exact hs.core
  | .const (c := c) => cases c <;> exact .const
  | .con hc hn hw hs => exact .con hc hn hw hs
  | .atError hs => exact .atError hs
  | .list hs => exact .list hs
  | .fn => exact .fn
  | .dependentFn => exact .dependentFn
  | .tvar => exact .tvar
  | .reference => exact .reference
  | .lazy => exact .lazy
  | .cont => exact .cont
  | .map => exact .map
  | .set => exact .set
  | .bytes => exact .bytes
  | .dict => exact .dict
  | .tapp => exact .tapp
  | .ctor => exact .ctor
  | .external => exact .external
  | .scoped => exact .scoped
  | .pathBases => exact .pathBases
  | .scopePattern => exact .scopePattern
  | .checked => exact .checked
  | .checkedRequest => exact .checkedRequest

theorem Inhabits.of_core {P a v} (h : Inhabits P a.core v) : Inhabits P a v := by
  cases a with
  | refined a p => exact .refined (Inhabits.of_core (a := a) h)
  | _ => exact h

private theorem Const.type_core (c : Const) : c.type.core = c.type := by cases c <;> rfl

private theorem core_subst_values (ν : Nat → Val) (a : Ty) :
    (substTyValues ν a).core = substTyValues ν a.core := by
  simp only [substTyValues, Ty.bind, valEnv, Ty.core_norm, ←Ty.rawSubstV_eq_rawBind, Ty.core_rawSubstV]

mutual
  private theorem Inhabits.of_subst_values_core {P b v} (ν : Nat → Val) (h : Inhabits P b v) :
      ∀ a, b.core = (substTyValues ν a).core → Inhabits P a v := by
    match h with
    | .const (c := c) =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      case base => rw [←he]; exact .const
      case «opaque» => rw [←he]; exact .const
      all_goals cases c <;> simp [Const.type] at he
    | .con (cd := cd) hc hn hw hs =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil, Ty.data.injEq] at he
      all_goals try cases he

      rename_i d ts hd ht
      subst d
      subst ht
      refine .con hc (by simpa using hn) hw ?_
      apply hs.of_subst_values ν (cd.args.map (Ty.subst ts []))
      rw [List.map_map]
      exact List.map_congr_left (fun a hm => (Ty.substV_subst_closed (hw a hm) ts (valEnv ν).values).symm)
    | .atError hs =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      all_goals try cases he

      rename_i d ts he
      simp only [atErrorType, Ty.core, Ty.data.injEq] at he
      rcases he with ⟨rfl, he⟩
      have hl := congrArg List.length he
      simp only [List.length_nil, List.length_map] at hl
      have ht := List.length_eq_zero_iff.mp hl.symm
      subst ht
      exact .atError hs
    | .list hs =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil, Ty.list.injEq] at he
      all_goals try cases he

      exact .list (hs.of_subst_values ν _ rfl)
    | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      all_goals try cases he

    | .refined hs =>
      intro a he
      exact hs.of_subst_values_core ν a he
    | .checked =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      all_goals try cases he

      exact .checked
    | .checkedRequest =>
      intro a he
      apply Inhabits.of_core
      rw [core_subst_values] at he
      cases hca : a.core <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals try exact False.elim (Ty.core_not_refined a _ _ hca)
      all_goals simp only [hca, Ty.core, Const.type_core, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      all_goals try cases he

      exact .checkedRequest
  theorem InhabitsAll.of_subst_values {P bs vs} (ν : Nat → Val) (h : InhabitsAll P bs vs) :
      ∀ as, bs = as.map (substTyValues ν) → InhabitsAll P as vs := by
    match h with
    | .nil => intro as he; cases as <;> simp_all; exact .nil
    | .cons h hs =>
      intro as he
      cases as with
      | nil => simp at he
      | cons a as =>
        simp only [List.map_cons, List.cons.injEq] at he
        exact .cons (h.of_subst_values_core ν a (congrArg Ty.core he.1)) (hs.of_subst_values ν as he.2)
  theorem InhabitsEach.of_subst_values {P b vs} (ν : Nat → Val) (h : InhabitsEach P b vs) :
      ∀ a, b = substTyValues ν a → InhabitsEach P a vs := by
    match h with
    | .nil => intro a _; exact .nil
    | .cons h hs => intro a he; exact .cons (h.of_subst_values_core ν a (congrArg Ty.core he)) (hs.of_subst_values ν a he)
end
theorem Inhabits.of_subst_values {P b v} (ν : Nat → Val) (h : Inhabits P b v) :
    ∀ a, b = substTyValues ν a → Inhabits P a v := by
  intro a he
  exact h.of_subst_values_core ν a (congrArg Ty.core he)

mutual
  theorem Inhabits.of_shift_values {P b v} (k c : Nat) (h : Inhabits P b v) :
      ∀ a, b = Ty.shiftV k c a → Inhabits P a v := by
    match h with
    | .const (c := c) =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map] at he
      case base => rw [←he]; exact .const
      case «opaque» => rw [←he]; exact .const
      all_goals cases c <;> simp [Const.type] at he
    | .con (cd := cd) hc hn hw hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map, Ty.data.injEq] at he
      all_goals try cases he

      rename_i d ts hd ht
      subst d
      subst ht
      refine .con hc (by simpa using hn) hw ?_
      apply hs.of_shift_values k c (cd.args.map (Ty.subst ts []))
      rw [List.map_map]
      exact List.map_congr_left (fun a hm => (Ty.subst_shiftV_closed (hw a hm) ts k c).symm)
    | .atError hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map] at he
      all_goals try cases he

      rename_i d ts he
      simp only [atErrorType, Ty.data.injEq] at he
      rcases he with ⟨rfl, he⟩
      have hl := congrArg List.length he
      simp only [List.length_nil, List.length_map] at hl
      have ht := List.length_eq_zero_iff.mp hl.symm
      subst ht
      exact .atError hs
    | .list hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map, Ty.list.injEq] at he
      all_goals try cases he

      exact .list (hs.of_shift_values k c _ rfl)
    | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map] at he
      all_goals try cases he

    | .refined hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map, Ty.refined.injEq] at he
      all_goals try cases he

      rename_i a p ha hp
      exact .refined (hs.of_shift_values k c a ha)
    | .checked =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map] at he
      all_goals try cases he

      exact .checked
    | .checkedRequest =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Ty.shiftV, shiftVTys_eq_map] at he
      all_goals try cases he

      exact .checkedRequest
  theorem InhabitsAll.of_shift_values {P bs vs} (k c : Nat) (h : InhabitsAll P bs vs) :
      ∀ as, bs = as.map (Ty.shiftV k c) → InhabitsAll P as vs := by
    match h with
    | .nil => intro as he; cases as <;> simp_all; exact .nil
    | .cons h hs =>
      intro as he
      cases as with
      | nil => simp at he
      | cons a as =>
        simp only [List.map_cons, List.cons.injEq] at he
        exact .cons (h.of_shift_values k c a he.1) (hs.of_shift_values k c as he.2)
  theorem InhabitsEach.of_shift_values {P b vs} (k c : Nat) (h : InhabitsEach P b vs) :
      ∀ a, b = Ty.shiftV k c a → InhabitsEach P a vs := by
    match h with
    | .nil => intro a _; exact .nil
    | .cons h hs => intro a he; exact .cons (h.of_shift_values k c a he) (hs.of_shift_values k c a he)
end

theorem Exhaustive.subst_values {P a ps} (h : Exhaustive P a ps) (ν : Nat → Val) :
    Exhaustive P (substTyValues ν a) ps :=
  fun v hv => h v (hv.of_subst_values ν a rfl)

theorem Exhaustive.shift_values {P a ps} (h : Exhaustive P a ps) (k c : Nat) :
    Exhaustive P (a.shiftV k c) ps :=
  fun v hv => h v (hv.of_shift_values k c a rfl)

theorem unguardedPats_rename (arms : List Arm) (ξ : Nat → Nat) :
    unguardedPats (Arm.renameList ξ arms) = unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih => cases arm with
    | mk alts guard body => cases guard <;> simp [Arm.renameList, unguardedPats, ih]

theorem unguardedPats_subst (arms : List Arm) (ν : Nat → Val) (ρ : Nat → LocalRef) :
    unguardedPats (Arm.substList ν arms ρ) = unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih => cases arm with
    | mk alts guard body => cases guard <;> simp [Arm.substList, unguardedPats, ih]

end Benitoite.Release.Refinement
