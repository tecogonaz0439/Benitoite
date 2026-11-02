import Benitoite.Release.Refinement.LegacyCallInputs

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_single (name : EffName) : embedEff (Benitoite.Release.Eff.single name) = Eff.single name := by
  unfold Benitoite.Release.Eff.single Benitoite.Release.Eff.ofAtoms Eff.single embedEff
  congr 1
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [embedAtoms_true]
  simp only [beq_iff_eq,decide_eq_true_eq]
  constructor
  · rintro ⟨a,rfl,he⟩; exact he.symm
  · intro he; subst x; exact ⟨_,rfl,rfl⟩

theorem legacy_opEffect (name : EffName) :
    EffR.mk (fun a => match a with | .name n (.fixed .top) => decide (n = name) | _ => false) [] = Eff.single name := by
  unfold Eff.single
  congr 1
  funext a
  cases a with
  | rho i => rfl
  | name n ix =>
    cases ix with
    | rvar i => simp
    | fixed r =>
      cases r with
      | based b p => simp
      | secrets => simp
      | absolute r => cases r <;> simp

theorem legacy_opTel (od : Benitoite.Release.OpDecl) :
    (embedOpDecl od).tel = signatureTel od.names (embedTys od.params) (embedTy od.ret)
      (embedEff (Benitoite.Release.Eff.single od.eff)) := by
  unfold OpDecl.tel embedOpDecl
  dsimp only
  rw [legacy_embedParameters,legacy_shiftV]
  apply congrArg (signatureTel od.names (embedTys od.params) (embedTy od.ret))
  rw [legacy_single]
  exact legacy_opEffect od.eff

namespace LegacyValueCases

theorem op_case {K P0 B0 B κ Ψ Q C Γ o od ts}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.op o ts)
        (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts [])))
    (lookup : P0.ops o = some od) (names : Benitoite.Release.NamesWF od.names od.params)
    (sat : Benitoite.Release.SatAll B0 C ts od.tparams) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.op o ts)
        (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts [])) := by
  intro Φ
  obtain ⟨od',hd,source,args⟩ := reg.2.1
  have hd' : od' = od := Option.some.inj (hd.symm.trans lookup)
  subst od'
  have count := reg.1.2.2.1
  have ha := legacy_value_annotation reg
  have hs := legacy_signatureTel_annotation od.names od.params od.ret (Benitoite.Release.Eff.single od.eff)
    (source.annotation_at rfl (by simp) [])
  have si : SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) (Γ.map (Option.map embedTy))
      (embedOpDecl od).tel (List.replicate od.tparams.length .value) (embedTys ts) [] := by
    apply legacy_signatureInstance (es := []) (t := (embedOpDecl od).tel) count
      (by simpa only [legacy_opTel,
        List.length_replicate,legacyTypeCtx_length (C := od.tparams) (κ := List.replicate od.tparams.length .value) (by simp),List.length_nil] using hs.wf)
      (args.annotations rfl count _) args.kindArgs (by simp [RowAnnotations]) (by simp)
    simpa only [legacy_opTel] using
      legacy_instantiated_annotation od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts [] ha
  have hn : NamesWF (embedOpDecl od).names (embedOpDecl od).params := by
    simpa only [embedOpDecl,legacy_embedParameters,NamesWF,Benitoite.Release.NamesWF,embedTys_eq_map,List.length_map] using names
  have hv := HasTypeVQ.V_Op (Ψ := embedStoreTy Ψ) (Q := Q) (Φ := Φ)
    (show (embedProgramWithKinds K P0).ops o = some (embedOpDecl od) from by simp only [embedProgramWithKinds_ops,lookup,Option.map_some])
    hn (legacy_SatAll tables count sat) si
  exact .V_Sub hv (.convert (by
    simpa only [legacy_opTel,List.map_nil] using
      legacy_instantiated_norm od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts [] names))
    ha.wf ha.sorted ha.declared

end LegacyValueCases

end
end Benitoite.Release.Refinement
