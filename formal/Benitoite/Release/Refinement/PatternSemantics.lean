import Benitoite.Release.Refinement.PatternTransport

namespace Benitoite.Release.Refinement

mutual
  theorem Inhabits.of_subst_values {P b v} (ν : Nat → Val) (h : Inhabits P b v) :
      ∀ a, b = substTyValues ν a → Inhabits P a v := by
    match h with
    | .const (c := c) =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      case base => rw [←he]; exact .const
      case «opaque» => rw [←he]; exact .const
      all_goals cases c <;> simp [Const.type] at he
    | .con (cd := cd) hc hn hw hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
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
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
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
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil, Ty.list.injEq] at he
      all_goals try cases he

      exact .list (hs.of_subst_values ν _ rfl)
    | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      all_goals try cases he

    | .refined hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil, Ty.refined.injEq] at he
      all_goals try cases he

      rename_i a p ha hp
      exact .refined (hs.of_subst_values ν a ha)
    | .checked =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
        Ty.normTys_eq_map, List.map_map, valEnv, RangeIx.inst_nil] at he
      all_goals try cases he

      exact .checked
    | .checkedRequest =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map,
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
        exact .cons (h.of_subst_values ν a he.1) (hs.of_subst_values ν as he.2)
  theorem InhabitsEach.of_subst_values {P b vs} (ν : Nat → Val) (h : InhabitsEach P b vs) :
      ∀ a, b = substTyValues ν a → InhabitsEach P a vs := by
    match h with
    | .nil => intro a _; exact .nil
    | .cons h hs => intro a he; exact .cons (h.of_subst_values ν a he) (hs.of_subst_values ν a he)
end
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
