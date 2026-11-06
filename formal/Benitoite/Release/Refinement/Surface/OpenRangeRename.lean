import Benitoite.Release.Refinement.RangeExchange
import Benitoite.Release.Refinement.RangeSourceProperties
import Benitoite.Release.Refinement.ValueBinding

/-! # 範囲の具体化と値変数の移動の交換 -/
namespace Benitoite.Release.Refinement.Surface.OpenRangeRename
noncomputable section

theorem ty_mapRanges_shift (a : Ty) (ρ : Nat → RangeIx) (k c : Nat) :
    (a.shiftV k c).mapRanges ρ = (a.mapRanges ρ).shiftV k c := by
  have h : (a.shiftV k c).rawMapRanges ρ = (a.rawMapRanges ρ).shiftV k c := by
    simp only [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
    exact (Ty.rawMapRanges_rawSubstV _ _ _).symm
  simp only [Ty.mapRanges, h, Ty.norm_shiftV]

theorem eff_mapRanges_shift (e : Eff) (ρ : Nat → RangeIx) (k c : Nat) :
    Eff.mapRanges ρ (Eff.shiftV k c e) = Eff.shiftV k c (Eff.mapRanges ρ e) := by
  have h : Eff.rawMapRanges ρ (Eff.shiftV k c e) = Eff.shiftV k c (Eff.rawMapRanges ρ e) := by
    simp only [Eff.shiftV_eq_renameEff, renameEff_eq_rawSubstV]
    exact (Eff.rawMapRanges_rawSubstV _ _ _).symm
  simp only [Eff.mapRanges, h, Eff.norm_shiftV]

theorem tel_mapRanges_shift (t : Tel) (ρ : Nat → RangeIx) (k c : Nat) :
    Tel.mapRanges ρ (Tel.shiftV k c t) = Tel.shiftV k c (Tel.mapRanges ρ t) := by
  cases t with
  | done a e =>
    change Tel.done ((a.shiftV k c).mapRanges ρ) (Eff.mapRanges ρ (Eff.shiftV k c e)) =
      Tel.done ((a.mapRanges ρ).shiftV k c) (Eff.shiftV k c (Eff.mapRanges ρ e))
    rw [ty_mapRanges_shift, eff_mapRanges_shift]
  | param n a t =>
    change Tel.param n ((a.shiftV k c).mapRanges ρ) (Tel.mapRanges ρ (Tel.shiftV k (c + 1) t)) =
      Tel.param n ((a.mapRanges ρ).shiftV k c) (Tel.shiftV k (c + 1) (Tel.mapRanges ρ t))
    rw [ty_mapRanges_shift, tel_mapRanges_shift]

theorem tel_mapRanges_binders (t : Tel) (ρ : Nat → RangeIx) :
    telBinders (Tel.mapRanges ρ t) = telBinders t := by
  cases t with
  | done => rfl
  | param n a t =>
    exact congrArg (· + 1) (tel_mapRanges_binders t ρ)

theorem kind_mapRanges_shift (b : BuilderKind) (ρ : Nat → RangeIx) (k c : Nat) :
    BuilderKind.mapRangesN ρ (renameKind (shiftIndex k c) b) =
      renameKind (shiftIndex k c) (BuilderKind.mapRangesN ρ b) := by
  cases b <;> simp only [BuilderKind.mapRangesN, renameKind, renameTy_shiftIndex,
    ty_mapRanges_shift]

mutual
  theorem val_mapRanges_shift (v : Val) (ρ : Nat → RangeIx) (k c : Nat) :
      (v.rename (shiftIndex k c)).mapRangesN ρ = (v.mapRangesN ρ).rename (shiftIndex k c) := by
    cases v <;> simp only [Val.rename, Val.mapRangesN, val_mapRanges_shift,
      vals_mapRanges_shift, comp_mapRanges_shift, List.map_map, List.length_map,
      Function.comp_def, renameTy_shiftIndex, renameEff_shiftIndex,
      ty_mapRanges_shift, eff_mapRanges_shift, upRen_shiftIndex]
    case dependentLam t body =>
      rw [← Tel.shiftV_eq_rawBind, tel_mapRanges_shift,
        ← Tel.shiftV_eq_rawBind, tel_mapRanges_binders]
  termination_by structural v

  theorem vals_mapRanges_shift (vs : List Val) (ρ : Nat → RangeIx) (k c : Nat) :
      Val.mapRangesListN ρ (Val.renameList (shiftIndex k c) vs) =
        Val.renameList (shiftIndex k c) (Val.mapRangesListN ρ vs) := by
    cases vs <;> simp only [Val.renameList, Val.mapRangesListN,
      val_mapRanges_shift, vals_mapRanges_shift]
  termination_by structural vs

  theorem comp_mapRanges_shift (m : Comp) (ρ : Nat → RangeIx) (k c : Nat) :
      (m.rename (shiftIndex k c)).mapRangesN ρ = (m.mapRangesN ρ).rename (shiftIndex k c) := by
    cases m with
    | checkAt kind o sh bs p v ix =>
      cases bs <;> simp only [Comp.rename, Comp.mapRangesN, val_mapRanges_shift,
        renameTy_shiftIndex, ty_mapRanges_shift]
    | _ =>
      simp only [Comp.rename, Comp.mapRangesN, val_mapRanges_shift,
        vals_mapRanges_shift, comp_mapRanges_shift, arms_mapRanges_shift,
        clauses_mapRanges_shift, kind_mapRanges_shift, List.map_map,
        Function.comp_def, renameTy_shiftIndex, renameEff_shiftIndex,
        ty_mapRanges_shift, eff_mapRanges_shift, upRen_shiftIndex]
  termination_by structural m

  theorem arms_mapRanges_shift (arms : List Arm) (ρ : Nat → RangeIx) (k c : Nat) :
      Arm.mapRangesListN ρ (Arm.renameList (shiftIndex k c) arms) =
        Arm.renameList (shiftIndex k c) (Arm.mapRangesListN ρ arms) := by
    cases arms with
    | nil => rfl
    | cons a arms =>
      cases a with
      | mk alts guard body =>
        cases guard <;> simp only [Arm.renameList, Arm.mapRangesListN,
          comp_mapRanges_shift, arms_mapRanges_shift, upRen_shiftIndex]
  termination_by structural arms

  theorem clauses_mapRanges_shift (cs : List Clause) (ρ : Nat → RangeIx) (k c : Nat) :
      Clause.mapRangesListN ρ (Clause.renameList (shiftIndex k c) cs) =
        Clause.renameList (shiftIndex k c) (Clause.mapRangesListN ρ cs) := by
    cases cs with
    | nil => rfl
    | cons cl cs =>
      cases cl <;> simp only [Clause.renameList, Clause.mapRangesListN,
        comp_mapRanges_shift, clauses_mapRanges_shift, upRen_shiftIndex,
        renameTy_shiftIndex, ty_mapRanges_shift]
  termination_by structural cs
end

theorem val_instR_shift (v : Val) (rs : List RangeExpr) (k c : Nat) :
    (v.rename (shiftIndex k c)).instR rs = (v.instR rs).rename (shiftIndex k c) := by
  cases rs <;> simp only [Val.instR, Val.substR, val_mapRanges_shift]

theorem comp_instR_shift (m : Comp) (rs : List RangeExpr) (k c : Nat) :
    (m.rename (shiftIndex k c)).instR rs = (m.instR rs).rename (shiftIndex k c) := by
  cases rs <;> simp only [Comp.instR, Comp.substR, comp_mapRanges_shift]

theorem vals_instR_shift (vs : List Val) (rs : List RangeExpr) (k c : Nat) :
    (Val.renameList (shiftIndex k c) vs).map (Val.instR rs) =
      Val.renameList (shiftIndex k c) (vs.map (Val.instR rs)) := by
  cases vs with
  | nil => rfl
  | cons v vs => simp only [Val.renameList, List.map_cons, val_instR_shift, vals_instR_shift]

theorem arms_instR_shift (arms : List Arm) (rs : List RangeExpr) (k c : Nat) :
    Arm.instRList rs (Arm.renameList (shiftIndex k c) arms) =
      Arm.renameList (shiftIndex k c) (Arm.instRList rs arms) := by
  cases rs <;> simp only [Arm.instRList, arms_mapRanges_shift]

theorem clauses_instR_shift (cs : List Clause) (rs : List RangeExpr) (k c : Nat) :
    Clause.instRList rs (Clause.renameList (shiftIndex k c) cs) =
      Clause.renameList (shiftIndex k c) (Clause.instRList rs cs) := by
  cases rs <;> simp only [Clause.instRList, clauses_mapRanges_shift]

end
end Benitoite.Release.Refinement.Surface.OpenRangeRename
