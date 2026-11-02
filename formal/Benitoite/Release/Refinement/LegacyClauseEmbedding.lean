import Benitoite.Release.Refinement.LegacyClauseContexts

namespace Benitoite.Release.Refinement
noncomputable section
namespace LegacyClauseCases

theorem nil_case {K P0 B κ Ψ Q C Γ R eb a e L} :
    LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R eb [] a e L) := by
  intro Φ
  exact .nil

theorem cons_case {K P0 B0 B κ Ψ Q C Γ R eb o n k m cs t e sg L}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.clauses κ Ψ Q C Γ R eb (.mk o n k m :: cs) t e L))
    (signature : Benitoite.Release.ClauseSig P0 B0 eb o sg)
    (names : Benitoite.Release.NamesWF sg.names sg.params)
    (arity : n = sg.params.length) (ntys : k = sg.tparams.length)
    (body : LegacyJudgment.Embedded K P0 B
      (.comp (List.replicate sg.tparams.length .value ++ κ) Ψ.hideBuilders Q (sg.tparams ++ C)
      (some (.cont sg.ret (t.shift k 0) (Benitoite.Release.Eff.shift k 0 e)) ::
        (Benitoite.Release.binds sg.params ++ Benitoite.Release.shiftEnv k Γ))
      (R.map (Benitoite.Release.Ty.shift k 0)) m (t.shift k 0)
      (Benitoite.Release.Eff.shift k 0 e) []))
    (tail : LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R eb cs t e L)) :
    LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R eb (.mk o n k m :: cs) t e L) := by
  intro Φ
  obtain ⟨S,ix,lookup⟩ := signature
  have wf := legacy_opSig_wf (reg.2.1.signature_wf lookup)
  have ht := (reg.2.2.1 t (by simp)).2.1
  have he := (reg.2.2.2.1 e (by simp)).2.1.2.2.2.2
  apply HasTypeClausesQ.cons (tables.clauseSig ⟨S,ix,lookup⟩)
    (by simpa only [embedOpSig,NamesWF,Benitoite.Release.NamesWF,embedTys_eq_map,List.length_map] using names)
    (by simpa only [embedOpSig,embedTys_eq_map,List.length_map] using arity)
    (by simpa only [embedOpSig,TypeCtx.values,List.length_map] using ntys) wf _ (tail Φ)
  have hbody := body (liftMany (sg.params.length+1) Φ)
  subst k
  have hparams : (embedOpSig sg).params.length = sg.params.length := by simp [embedOpSig,embedTys_eq_map]
  have htypes : (embedOpSig sg).tparams.length = sg.tparams.length := by simp [embedOpSig,TypeCtx.values]
  have hctx : (embedOpSig sg).tparams ++ legacyTypeCtx C κ =
      legacyTypeCtx (sg.tparams ++ C) (List.replicate sg.tparams.length .value ++ κ) := by
    rw [legacy_typeCtx_append C sg.tparams κ (List.replicate sg.tparams.length .value) (by simp),legacy_typeCtx_values]
    rfl
  have hR : R.map (fun r => Ty.shiftV (sg.params.length+1) 0 (shiftTypes sg.tparams.length 0 (embedTy r))) =
      R.map (fun r => embedTy (r.shift sg.tparams.length 0)) := by
    cases R with
    | none => rfl
    | some r =>
      have hr := (reg.2.2.1 r (by simp)).2.1
      simp only [Option.map_some,←legacy_shift_types hr,legacy_shiftV]
  rw [legacy_opContext reg.1 ht he]
  simpa only [hparams,htypes,hctx,legacy_hideBuilders,←legacy_shift_types ht,
    ←legacy_shift_eff he,legacy_shiftV,legacy_shiftVEff,Option.map_map,Function.comp_def,hR,List.map_nil]
    using hbody

theorem failure_case {K P0 B0 B κ Ψ Q C Γ E R m t ec L}
    (reg : LegacyNodeRegular K P0 B0 B (.failure κ Ψ Q C Γ E R [.fail E m] t ec L))
    (body : LegacyJudgment.Embedded K P0 B (.comp (.value :: κ) Ψ.hideBuilders Q
      (({} : Benitoite.Release.TParam) :: C)
      (none :: some (E.shift 1 0) :: Benitoite.Release.shiftEnv 1 Γ)
      (R.map (Benitoite.Release.Ty.shift 1 0)) m (t.shift 1 0)
      (Benitoite.Release.Eff.shift 1 0 ec) [])) :
    LegacyJudgment.Embedded K P0 B (.failure κ Ψ Q C Γ E R [.fail E m] t ec L) := by
  intro Φ
  have err := reg.2.2.1.annotation (a := E) (by simp) reg.1.2.2.1 (Γ.map (Option.map embedTy))
  have ret := reg.2.2.1.annotation (a := t) (by simp) reg.1.2.2.1 (Γ.map (Option.map embedTy))
  have he := (reg.2.2.2.1 ec (by simp)).2.1.2.2.2.2
  apply HasFailureClause.one err ret
    (by simpa only [List.map_cons,List.map_nil] using reg.2.2.2.1.annotations rfl reg.1.2.2.1 (Γ.map (Option.map embedTy)))
  have hR : R.map (fun r => Ty.shiftV 2 0 (shiftTypes 1 0 (embedTy r))) =
      R.map (fun r => embedTy (r.shift 1 0)) := by
    cases R with
    | none => rfl
    | some r =>
      have hr := (reg.2.2.1 r (by simp)).2.1
      simp only [Option.map_some,←legacy_shift_types hr,legacy_shiftV]
  have hc : TypeCtx.valueParam :: legacyTypeCtx C κ =
      legacyTypeCtx (({} : Benitoite.Release.TParam) :: C) (.value :: κ) := rfl
  rw [legacy_failureContext reg.1 (reg.2.2.1 E (by simp)).2.1]
  simpa only [hc,legacy_hideBuilders,←legacy_shift_types ret.wf,←legacy_shift_eff he,
    legacy_shiftV,legacy_shiftVEff,Option.map_map,Function.comp_def,hR,List.map_nil]
    using body (liftMany 2 Φ)

end LegacyClauseCases
end
end Benitoite.Release.Refinement
