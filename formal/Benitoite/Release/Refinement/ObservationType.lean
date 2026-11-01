import Benitoite.Release.Refinement.ValueClosed

namespace Benitoite.Release.Refinement

/- 欄の宣言照合が読む data の構造と sort。篩の事実はここから取り出さない。 -/
mutual
  def Ty.observationType : Ty → Ty
    | .data d as => .data d (observationTypes as)
    | .refined a _ => a.observationType
    | .list _ => .list (.base .unit)
    | .lazy _ => .lazy (.base .unit)
    | .map _ _ => .map (.base .unit) (.base .unit)
    | .set _ => .set (.base .unit)
    | .reference _ => .reference (.base .unit)
    | .dict cl _ => .dict cl (.base .unit)
    | .external id _ => .external id []
    | .fn _ _ _ _ | .dependentFn _ => .fn [] [] (.base .unit) (.mk (fun _ => false) [])
    | .cont _ _ _ => .cont (.base .unit) (.base .unit) (.mk (fun _ => false) [])
    | .opaque o _ => .opaque o .top
    | .scoped o k _ => .scoped o k .top
    | .tapp i as => .tapp i (observationTypes as)
    | a => a
  def observationTypes : List Ty → List Ty
    | [] => []
    | a :: as => a.observationType :: observationTypes as
end

@[simp] theorem observationTypes_eq_map (as : List Ty) : observationTypes as = as.map Ty.observationType := by
  induction as <;> simp_all [observationTypes]

@[simp] theorem observationTypes_length (as : List Ty) : (observationTypes as).length = as.length := by
  simp only [observationTypes_eq_map, List.length_map]

@[simp] theorem Ty.observationType_core (a : Ty) : a.core.observationType = a.observationType := by
  cases a <;> try rfl
  case refined a p => exact Ty.observationType_core a

@[simp] theorem Ty.observationType_refineNorm (a : Ty) (p : Pred) :
    (a.refineNorm p).observationType = a.observationType := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [Ty.observationType, Ty.observationType_core]

private theorem observationType_foldFn (t : Tel) :
    (Ty.foldFn t).observationType = Ty.observationType (.dependentFn t) := by
  unfold Ty.foldFn
  split <;> rfl

mutual
  @[simp] theorem Ty.observationType_norm (a : Ty) : a.norm.observationType = a.observationType := by
    cases a <;> simp only [Ty.norm, Ty.observationType, Ty.observationType_refineNorm,
      Ty.observationType_norm, observationTypes_norm, observationType_foldFn]
  @[simp] theorem observationTypes_norm (as : List Ty) : observationTypes (Ty.normTys as) = observationTypes as := by
    cases as <;> simp only [Ty.normTys, observationTypes, Ty.observationType_norm, observationTypes_norm]
end

mutual
  @[simp] theorem Ty.observationType_rawSubstV (a : Ty) (ν : ObservationEnv) :
      (a.rawSubstV ν).observationType = a.observationType := by
    cases a <;> simp only [Ty.rawSubstV, Ty.observationType, Ty.observationType_rawSubstV, observationTypes_rawSubstV]
  @[simp] theorem observationTypes_rawSubstV (as : List Ty) (ν : ObservationEnv) :
      observationTypes (substVTys ν as) = observationTypes as := by
    cases as <;> simp only [substVTys, observationTypes, Ty.observationType_rawSubstV, observationTypes_rawSubstV]
end

mutual
  theorem Ty.LeQ.observationType {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
      Ty.LeQ P [] [] a.observationType b.observationType := by
    match h with
    | .refl => exact .refl
    | .convert he => exact .convert (congrArg Ty.norm
        (by simpa only [Ty.observationType_norm] using congrArg Ty.observationType he))
    | .trans h g => exact .trans h.observationType g.observationType
    | .data hs =>
      apply Ty.LeQ.data
      simpa only [observationTypes_length] using hs.observationType
    | .fn_effect _ | .dependentFn _ | .list _ | .lazy _ | .map_value _ _ => exact .refl
    | .forget | .introduce .. => exact .refl
    | .refine h .. => exact h.observationType
    | .scoped _ => exact .refl
    | .scoped_forget => exact .scoped_forget
  theorem TypeArgsLe.observationType {P Γ Φ vs as bs} (h : TypeArgsLe P Γ Φ vs as bs) :
      TypeArgsLe P [] [] vs (observationTypes as) (observationTypes bs) := by
    match h with
    | .nil => exact .nil
    | .covariant_cons h t => exact .covariant_cons h.observationType t.observationType
    | .contravariant_cons h t => exact .contravariant_cons h.observationType t.observationType
    | .invariant_cons h t => exact .invariant_cons (congrArg Ty.norm
        (by simpa only [Ty.observationType_norm] using congrArg Ty.observationType h)) t.observationType
end

/-- 観測に用いる型引数の対応。Γ/Φ と篩の事実を持ち込まない。 -/
def DataObservationLe (P : Program) (d : DataName) (as bs : List Ty) : Prop :=
  TypeArgsLe P [] [] (P.varianceFor d as.length) (observationTypes as) (observationTypes bs)

theorem DataObservationLe.refl (P : Program) (d : DataName) (as : List Ty) : DataObservationLe P d as as :=
  TypeArgsLe.refl _ _ (by simp)

theorem DataObservationLe.length {P d as bs} (h : DataObservationLe P d as bs) : as.length = bs.length := by
  have hh := TypeArgsLe.length h
  simpa only [observationTypes_length] using hh.1.trans hh.2.symm

theorem DataObservationLe.of_args {P Γ Φ d as bs}
    (h : TypeArgsLe P Γ Φ (P.varianceFor d as.length) as bs) : DataObservationLe P d as bs :=
  h.observationType

mutual
  @[simp] theorem Ty.observationType_shiftV (a : Ty) (k c : Nat) :
      (a.shiftV k c).observationType = a.observationType := by
    cases a <;> simp only [Ty.shiftV, Ty.observationType, Ty.observationType_shiftV, observationTypes_shiftV]
  @[simp] theorem observationTypes_shiftV (as : List Ty) (k c : Nat) :
      observationTypes (shiftVTys k c as) = observationTypes as := by
    cases as <;> simp only [shiftVTys, observationTypes, Ty.observationType_shiftV, observationTypes_shiftV]
end

theorem DataObservationLe.shiftV {P d as bs} (h : DataObservationLe P d as bs) (k c : Nat) :
    DataObservationLe P d (shiftVTys k c as) (shiftVTys k c bs) := by
  simpa only [DataObservationLe, shiftVTys_eq_map, observationTypes_eq_map, List.length_map, List.map_map, Function.comp_def, Ty.observationType_shiftV] using h

mutual
  theorem Ty.observationType_shiftTypes (a : Ty) (k c : Nat) :
      (shiftTypes k c a).observationType = shiftTypes k c a.observationType := by
    cases a <;> simp only [shiftTypes, Ty.observationType, Ty.observationType_shiftTypes,
      observationTypes_shiftTypes, shiftTypesList, shiftRowsTypes]
    all_goals split <;> rfl
  theorem observationTypes_shiftTypes (as : List Ty) (k c : Nat) :
      observationTypes (shiftTypesList k c as) = shiftTypesList k c (observationTypes as) := by
    cases as <;> simp only [shiftTypesList, observationTypes, Ty.observationType_shiftTypes, observationTypes_shiftTypes]
end

theorem DataObservationLe.shiftTypes {P d as bs} (h : DataObservationLe P d as bs) (k c : Nat) :
    DataObservationLe P d (as.map (shiftTypes k c)) (bs.map (shiftTypes k c)) := by
  have hh := TypeArgsLe.rawBind h (SubstEnv.shiftTypes k c)
    (Transport.types [] [] (SubstEnv.shiftTypes k c) rfl (by intro i; simp [SubstEnv.shiftTypes, Ordinary, Ty.core]))
  simpa only [DataObservationLe, rawBindTys_eq_map, Ty.rawBind_shiftTypes, Ctx.bindTypes,
    List.map_nil, List.length_map, observationTypes_eq_map, List.map_map, Function.comp_def,
    Ty.observationType_shiftTypes] using hh

end Benitoite.Release.Refinement