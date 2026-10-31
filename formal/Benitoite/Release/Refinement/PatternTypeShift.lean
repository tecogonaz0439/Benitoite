import Benitoite.Release.Refinement.PatternSemantics
import Benitoite.Release.Refinement.TypeShiftAlgebra

namespace Benitoite.Release.Refinement

mutual
  theorem PatTy.shift_types {P p a δ} (h : PatTy P p a δ) (k c : Nat) :
      PatTy P p (Refinement.shiftTypes k c a) (δ.map (Refinement.shiftTypes k c)) := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const (c := con) hc =>
      have he : Refinement.shiftTypes k c (embedConst con).type = (embedConst con).type := by
        cases con <;> rfl
      rw [he]; exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List (rest := rest) (a := a) hb ha hn =>
      simp only [List.map_append]
      rw [restTys_map (Refinement.shiftTypes k c) rest a rfl]
      exact .P_List (by simpa only [List.map_replicate] using hb.shift_types k c)
        (by simpa only [List.map_replicate] using ha.shift_types k c) hn
    | .P_Con (cd := cd) (ts := ts) hc hn hw hp =>
      have hh := hp.shift_types k c
      have he : (cd.args.map (Ty.subst ts [])).map (Refinement.shiftTypes k c) =
          cd.args.map (Ty.subst (ts.map (Refinement.shiftTypes k c)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a hm => Ty.subst_shiftTypes (hw a hm) ts [] (by omega) k c)
      rw [he] at hh
      simpa only [Refinement.shiftTypes, shiftTypesList_eq_map] using
        PatTy.P_Con hc (by simpa using hn) hw hh
  theorem PatTys.shift_types {P ps as δ} (h : PatTys P ps as δ) (k c : Nat) :
      PatTys P ps (as.map (Refinement.shiftTypes k c)) (δ.map (Refinement.shiftTypes k c)) := by
    match h with
    | .nil => exact .nil
    | .cons hp hs =>
      simpa only [List.map_append, List.map_cons] using PatTys.cons (hp.shift_types k c) (hs.shift_types k c)
end
mutual
  theorem Inhabits.of_shiftTypes {P b v} (k c : Nat) (h : Inhabits P b v) :
      ∀ a, b = Refinement.shiftTypes k c a → Inhabits P a v := by
    match h with
    | .const (c := c) =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map] at he
      case base => rw [←he]; exact .const
      case «opaque» => rw [←he]; exact .const
      all_goals cases c <;> simp [Const.type] at he
    | .con (cd := cd) hc hn hw hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map, Ty.data.injEq] at he
      all_goals try cases he

      rename_i d ts hd ht
      subst d
      subst ht
      have hn' : cd.ntys=ts.length := by simpa using hn
      refine .con hc hn' hw ?_
      apply hs.of_shiftTypes k c (cd.args.map (Ty.subst ts []))
      rw [List.map_map]
      exact List.map_congr_left (fun a hm => (Ty.subst_shiftTypes (hw a hm) ts [] (by omega) k c).symm)
    | .atError hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map] at he
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
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map, Ty.list.injEq] at he
      all_goals try cases he

      exact .list (hs.of_shiftTypes k c _ rfl)
    | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map] at he
      all_goals try cases he

    | .refined hs =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map, Ty.refined.injEq] at he
      all_goals try cases he

      rename_i a p ha hp
      exact .refined (hs.of_shiftTypes k c a ha)
    | .checked =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map] at he
      all_goals try cases he

      exact .checked
    | .checkedRequest =>
      intro a he
      cases a <;> try first | exact .fn | exact .dependentFn | exact .tvar | exact .reference | exact .lazy | exact .cont | exact .map | exact .set | exact .bytes | exact .dict | exact .tapp | exact .ctor | exact .external | exact .scoped | exact .pathBases | exact .scopePattern
      all_goals simp only [Refinement.shiftTypes, shiftTypesList_eq_map] at he
      all_goals try cases he

      exact .checkedRequest
  theorem InhabitsAll.of_shiftTypes {P bs vs} (k c : Nat) (h : InhabitsAll P bs vs) :
      ∀ as, bs = as.map (Refinement.shiftTypes k c) → InhabitsAll P as vs := by
    match h with
    | .nil => intro as he; cases as <;> simp_all; exact .nil
    | .cons h hs =>
      intro as he
      cases as with
      | nil => simp at he
      | cons a as =>
        simp only [List.map_cons, List.cons.injEq] at he
        exact .cons (h.of_shiftTypes k c a he.1) (hs.of_shiftTypes k c as he.2)
  theorem InhabitsEach.of_shiftTypes {P b vs} (k c : Nat) (h : InhabitsEach P b vs) :
      ∀ a, b = Refinement.shiftTypes k c a → InhabitsEach P a vs := by
    match h with
    | .nil => intro a _; exact .nil
    | .cons h hs => intro a he; exact .cons (h.of_shiftTypes k c a he) (hs.of_shiftTypes k c a he)
end


theorem AltsTy.shift_types {P alts a δ} (h : AltsTy P alts a δ) (k c : Nat) :
    AltsTy P alts (shiftTypes k c a) (δ.map (shiftTypes k c)) :=
  h.map _ (fun _ _ _ hp => hp.shift_types k c)

theorem Exhaustive.shift_types {P a ps} (h : Exhaustive P a ps) (k c : Nat) :
    Exhaustive P (shiftTypes k c a) ps := fun v hv => h v (hv.of_shiftTypes k c a rfl)

end Benitoite.Release.Refinement
