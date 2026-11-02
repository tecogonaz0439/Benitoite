import Benitoite.Release.Refinement.LegacyArmEmbedding

namespace Benitoite.Release.Refinement
noncomputable section

mutual
  theorem legacy_rawShift (a : Benitoite.Release.Ty) (k c : Nat) :
      embedTy (a.rawShift k c) = shiftTypes k c (embedTy a) := by
    cases a <;> simp only [Benitoite.Release.Ty.rawShift,embedTy,shiftTypes,legacy_rawShift,
      legacy_rawShiftTys,legacy_rawShiftEff]
  theorem legacy_rawShiftTys (as : List Benitoite.Release.Ty) (k c : Nat) :
      embedTys (Benitoite.Release.Ty.rawShiftTys k c as) = shiftTypesList k c (embedTys as) := by
    cases as <;> simp only [Benitoite.Release.Ty.rawShiftTys,embedTys,shiftTypesList,
      legacy_rawShift,legacy_rawShiftTys]
  theorem legacy_rawShiftEff (e : Benitoite.Release.Eff) (k c : Nat) :
      embedEff (Benitoite.Release.Eff.rawShift k c e) = shiftRowsTypes k c (embedEff e) := by
    cases e; simp only [Benitoite.Release.Eff.rawShift,embedEff,shiftRowsTypes,legacy_rawShiftTys]
end

theorem legacy_normal {a : Benitoite.Release.Ty} {nr nt nv}
    (h : (embedTy a).WF nr nt nv) : (embedTy a).norm = embedTy a := by
  rw [←embedTy_norm,Benitoite.Release.Ty.WF.canonical a (legacy_wf h)]

theorem legacy_shift_types {a : Benitoite.Release.Ty} {nr nt nv}
    (h : (embedTy a).WF nr nt nv) (k c : Nat) :
    embedTy (a.shift k c) = shiftTypes k c (embedTy a) := by
  rw [Benitoite.Release.Ty.shift_eq_norm_rawShift,embedTy_norm,legacy_rawShift,
    Ty.norm_shiftTypes,legacy_normal h]

theorem legacy_shift_eff {e : Benitoite.Release.Eff} (h : (embedEff e).Canonical) (k c : Nat) :
    embedEff (Benitoite.Release.Eff.shift k c e) = shiftRowsTypes k c (embedEff e) := by
  rw [Benitoite.Release.Eff.shift,embedEff_norm,legacy_rawShiftEff,Eff.norm_shiftTypes,h]

theorem legacy_typeCtx_append (C D : List Benitoite.Release.TParam) (κ ks : KindCtx)
    (count : ks.length = D.length) :
    legacyTypeCtx (D ++ C) (ks ++ κ) = legacyTypeCtx D ks ++ legacyTypeCtx C κ := by
  unfold legacyTypeCtx embedTParamsWithKinds
  rw [List.zip_append (by omega),List.map_append]

theorem legacy_typeCtx_values (C : List Benitoite.Release.TParam) :
    legacyTypeCtx C (List.replicate C.length .value) = TypeCtx.values C := by
  induction C with
  | nil => rfl
  | cons p ps ih => simpa only [legacyTypeCtx,embedTParamsWithKinds,List.length_cons,
      List.replicate_succ,List.zip_cons_cons,List.map_cons,TypeCtx.values,List.map_cons,embedTParam] using congrArg (embedTParam p :: ·) ih

end
end Benitoite.Release.Refinement
