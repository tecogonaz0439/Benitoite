import Benitoite.Release.Refinement.LegacyClauseTables

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_extend (Γ : List (Option Benitoite.Release.Ty)) (a : Benitoite.Release.Ty) :
    Ctx.extend (Γ.map (Option.map embedTy)) (embedTy a) =
      (some a :: Γ).map (Option.map embedTy) := by
  simp only [Ctx.extend,legacy_shiftVCtx,List.map_cons,Option.map_some,legacy_shiftV]

theorem legacy_extendMany (Γ : List (Option Benitoite.Release.Ty)) (ps : List Benitoite.Release.Ty) :
    Ctx.extendMany (Γ.map (Option.map embedTy)) (embedTys ps) =
      (Benitoite.Release.binds ps ++ Γ).map (Option.map embedTy) := by
  induction ps generalizing Γ with
  | nil => rfl
  | cons a as ih =>
    rw [embedTys,Ctx.extendMany,legacy_extend,ih]
    simp only [Benitoite.Release.binds,List.reverse_cons,List.map_append,List.map_cons,List.map_nil,
      List.append_assoc,List.singleton_append]

theorem LegacyNodeContext.shiftEnv {K P0 κ Ψ C Γ}
    (h : LegacyNodeContext K P0 κ Ψ C Γ) (k : Nat) :
    Ctx.shiftE (Γ.map (Option.map embedTy)) k =
      (Benitoite.Release.shiftEnv k Γ).map (Option.map embedTy) := by
  simp only [Ctx.shiftE,Ctx.shiftEAt,Benitoite.Release.shiftEnv,List.map_map]
  apply List.map_congr_left
  intro oa hm
  cases oa with
  | none => rfl
  | some a =>
    obtain ⟨i,hi⟩ := List.mem_iff_getElem?.mp hm
    have ha := (h.2.2.2.2 i a hi).2.wf
    simp only [Function.comp_def,Option.map_some,legacy_shift_types ha]

theorem legacy_opContext {K P0 κ Ψ C Γ sg t e}
    (ctx : LegacyNodeContext K P0 κ Ψ C Γ)
    (ht : (embedTy t).WF 0 κ.length Γ.length) (he : (embedEff e).Canonical) :
    (embedOpSig sg).context (Γ.map (Option.map embedTy)) (embedTy t) (embedEff e) =
      (some (.cont sg.ret (t.shift sg.tparams.length 0)
        (Benitoite.Release.Eff.shift sg.tparams.length 0 e)) ::
        (Benitoite.Release.binds sg.params ++ Benitoite.Release.shiftEnv sg.tparams.length Γ)).map
          (Option.map embedTy) := by
  simp only [OpSig.context,OpSig.continuation,embedOpSig,TypeCtx.values,List.length_map]
  rw [ctx.shiftEnv,legacy_extendMany]
  have hcont : Ty.cont (embedTy sg.ret)
      (Ty.shiftV (embedTys sg.params).length 0 (shiftTypes sg.tparams.length 0 (embedTy t)))
      (Eff.shiftV (embedTys sg.params).length 0 (shiftRowsTypes sg.tparams.length 0 (embedEff e))) =
      embedTy (.cont sg.ret (t.shift sg.tparams.length 0) (Benitoite.Release.Eff.shift sg.tparams.length 0 e)) := by
    rw [←legacy_shift_types ht,←legacy_shift_eff he,legacy_shiftV,legacy_shiftVEff]
    rfl
  rw [hcont,legacy_extend]

theorem legacy_failureContext {K P0 κ Ψ C Γ E}
    (ctx : LegacyNodeContext K P0 κ Ψ C Γ) (he : (embedTy E).WF 0 κ.length Γ.length) :
    failureContext (Γ.map (Option.map embedTy)) (embedTy E) =
      (none :: some (E.shift 1 0) :: Benitoite.Release.shiftEnv 1 Γ).map (Option.map embedTy) := by
  unfold failureContext
  rw [ctx.shiftEnv,←legacy_shift_types he,legacy_extend]
  simp only [Ctx.extendNone,legacy_shiftVCtx,List.map_cons,Option.map_none,Option.map_some,legacy_shiftV]

end
end Benitoite.Release.Refinement
