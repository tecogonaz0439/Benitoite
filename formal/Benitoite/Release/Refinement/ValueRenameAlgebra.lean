import Benitoite.Release.Refinement.ValueBinding

namespace Benitoite.Release.Refinement

theorem renameTy_comp (a : Ty) (ξ ζ : Nat → Nat) :
    renameTy ζ (renameTy ξ a) = renameTy (fun i => ζ (ξ i)) a := by
  simp only [renameTy_eq_rawSubstV, Ty.rawSubstV_comp, Option.bind_some, termBind?]

theorem renameEff_comp (e : Eff) (ξ ζ : Nat → Nat) :
    renameEff ζ (renameEff ξ e) = renameEff (fun i => ζ (ξ i)) e := by
  simp only [renameEff_eq_rawSubstV, Eff.rawSubstV_comp, Option.bind_some, termBind?]

theorem upRen_compose (n : Nat) (ξ ζ : Nat → Nat) :
    (fun i => upRen n ζ (upRen n ξ i)) = upRen n (fun i => ζ (ξ i)) := by
  funext i
  by_cases hi : i<n
  · simp [upRen, hi]
  · simp [upRen, hi, show ¬ ξ (i-n)+n < n by omega]

theorem telBinders_rawBind (t : Tel) (θ : SubstEnv) : telBinders (Tel.rawBind θ t) = telBinders t := by
  cases t <;> simp only [Tel.rawBind, telBinders, telBinders_rawBind]

theorem Tel.rawBind_ren_comp (t : Tel) (ξ ζ : Nat → Nat) :
    Tel.rawBind (renEnv ζ) (Tel.rawBind (renEnv ξ) t) =
      Tel.rawBind (renEnv (fun i => ζ (ξ i))) t := by
  simp only [← Tel.rawSubstV_eq_rawBind, renEnv]
  rw [Tel.rawSubstV_comp]
  rfl

theorem renameKind_comp (b : BuilderKind) (ξ ζ : Nat → Nat) :
    renameKind ζ (renameKind ξ b) = renameKind (fun i => ζ (ξ i)) b := by
  cases b <;> simp [renameKind, renameTy_comp]

theorem LocalRef.rename_compose (r : LocalRef) (ξ ζ : Nat → Nat) :
    (r.rename ξ).rename ζ = r.rename (fun i => ζ (ξ i)) := by cases r <;> rfl

mutual
  theorem Val.rename_compose (v : Val) (ξ ζ : Nat → Nat) :
      (v.rename ξ).rename ζ = v.rename (fun i => ζ (ξ i)) := by
    cases v <;> simp only [Val.rename, List.map_map, Function.comp_def, renameTy_comp, renameEff_comp,
      Val.rename_compose, Val.renameList_compose, Comp.rename_compose, List.length_map,
      upRen_compose, Tel.rawBind_ren_comp, telBinders_rawBind]
  theorem Val.renameList_compose (vs : List Val) (ξ ζ : Nat → Nat) :
      Val.renameList ζ (Val.renameList ξ vs) = Val.renameList (fun i => ζ (ξ i)) vs := by
    cases vs <;> simp only [Val.renameList, Val.rename_compose, Val.renameList_compose]
  theorem Comp.rename_compose (m : Comp) (ξ ζ : Nat → Nat) :
      (m.rename ξ).rename ζ = m.rename (fun i => ζ (ξ i)) := by
    cases m
    case checkAt _ _ _ bs _ _ _ =>
      cases bs <;> simp only [Comp.rename, Val.rename_compose, renameTy_comp]
    all_goals simp only [Comp.rename, Val.rename_compose, Val.renameList_compose, Comp.rename_compose,
      Arm.renameList_compose, Clause.renameList_compose, List.map_map, Function.comp_def,
      renameKind_comp, LocalRef.rename_compose, renameTy_comp, renameEff_comp, upRen_compose]
  theorem Arm.renameList_compose (arms : List Arm) (ξ ζ : Nat → Nat) :
      Arm.renameList ζ (Arm.renameList ξ arms) = Arm.renameList (fun i => ζ (ξ i)) arms := by
    cases arms with
    | nil => rfl
    | cons arm arms =>
      cases arm with
      | mk alts guard body =>
        cases guard <;> simp only [Arm.renameList, Comp.rename_compose, Arm.renameList_compose, upRen_compose]
  theorem Clause.renameList_compose (cs : List Clause) (ξ ζ : Nat → Nat) :
      Clause.renameList ζ (Clause.renameList ξ cs) = Clause.renameList (fun i => ζ (ξ i)) cs := by
    cases cs with
    | nil => rfl
    | cons cl cs =>
      cases cl <;> simp only [Clause.renameList, Comp.rename_compose, Clause.renameList_compose, upRen_compose, renameTy_comp]
end

theorem upSubst_add (n m : Nat) (ν : Nat → Val) :
    upSubst n (upSubst m ν) = upSubst (m+n) ν := by
  funext i
  by_cases hn : i<n
  · simp [upSubst, hn, show i<m+n by omega]
  · by_cases hm : i-n<m
    · simp [upSubst, hn, hm, show i<m+n by omega, Val.rename]; congr 1; omega
    · simp only [upSubst, hn, hm, show ¬i<m+n by omega, ↓reduceIte, Val.rename_compose]
      rw [show i-n-m = i-(m+n) by omega]
      congr 1
      funext j; omega

theorem upLocalSubst_zero (ρ : Nat → LocalRef) : upLocalSubst 0 ρ = ρ := by
  funext i; cases h : ρ i <;> simp [upLocalSubst, LocalRef.rename, h]

theorem upLocalSubst_add (n m : Nat) (ρ : Nat → LocalRef) :
    upLocalSubst n (upLocalSubst m ρ) = upLocalSubst (m+n) ρ := by
  funext i
  by_cases hn : i<n
  · simp [upLocalSubst, hn, show i<m+n by omega]
  · by_cases hm : i-n<m
    · simp [upLocalSubst, hn, hm, show i<m+n by omega, LocalRef.rename]; congr 1; omega
    · simp only [upLocalSubst, hn, hm, show ¬i<m+n by omega, ↓reduceIte, LocalRef.rename_compose]
      rw [show i-n-m = i-(m+n) by omega]
      congr 1
      funext j; omega

theorem Ty.shiftV_add (a : Ty) (m n : Nat) :
    (a.shiftV m 0).shiftV n 0 = a.shiftV (m+n) 0 := by
  simp only [Ty.shiftV_eq_renameTy, renameTy_comp]
  congr 1
  funext i
  simp [shiftIndex, Nat.add_assoc]

theorem Pred.shiftV_add (p : Pred) (m n : Nat) :
    (p.shiftV m 0).shiftV n 0 = p.shiftV (m+n) 0 := by
  simp only [Pred.shiftV, predBind_comp]
  congr 1
  funext i
  simp [shiftIndex, termBind?, Nat.add_assoc]

end Benitoite.Release.Refinement
