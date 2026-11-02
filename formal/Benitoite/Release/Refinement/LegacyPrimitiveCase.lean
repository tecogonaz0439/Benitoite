import Benitoite.Release.Refinement.LegacyRangeAlgebra

namespace Benitoite.Release.Refinement
noncomputable section

theorem LegacyPrimSignature.qsig {s0 s} (h : LegacyPrimSignature s0 s) :
    Qsig s.params s.ret s.eff = Benitoite.Release.Qsig s0.params s0.ret s0.eff := by
  rw [h.params,h.ret,h.eff,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,legacy_Qsig]

theorem legacy_RangeAdmissible {K P0 B0 B b s0 s rs}
    (tables : LegacyTables K P0 B0 B) (corr : LegacyPrimSignature s0 s)
    (h : B0.RangeAdmissible b s0 rs) : B.RangeAdmissible b s (rs.map embedRange) := by
  refine ⟨by simpa only [List.length_map,corr.rkinds] using h.1.length,?_,?_,?_⟩
  · intro i r k hr hk
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using hr)
    exact h.1.1.getElem? ho (by simpa only [corr.rkinds] using hk)
  · intro r hr
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp hr
    exact ⟨h.1.2.1 old ho,h.2 old ho⟩
  · rcases h.1.2.2 with top | admits
    · left
      intro r hr
      obtain ⟨old,ho,rfl⟩ := List.mem_map.mp hr
      rw [top old ho]
      rfl
    · exact .inr (tables.ranges b rs admits)

theorem legacy_PrimitiveAdmissible {K P0 κ C nv s0 s Q ts es rs}
    (corr : LegacyPrimSignature s0 s) (count : κ.length = C.length)
    (h : Benitoite.Release.PrimitiveAdmissible C (s0.inst rs) Q ts es)
    (rows : LegacyRowsInput K P0 ⟨κ,C,0,nv⟩ es) :
    PrimitiveAdmissible (legacyTypeCtx C κ) nv s Q (embedTys ts) (es.map embedEff) := by
  have ht : s.tparams.length = s0.tparams.length := by
    have hh := congrArg List.length corr.constraints
    simpa only [List.length_map] using hh
  have telRows := corr.sourceTelRowsAt h
  have qeq : Qsig s.params s.ret s.eff =
      Benitoite.Release.Qsig (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff :=
    corr.qsig.trans (legacy_old_Qsig_inst s0 rs).symm
  refine ⟨by simpa only [embedTys_eq_map,List.length_map,ht,Benitoite.Release.PrimSig.inst,Benitoite.Release.PrimSig.ntys] using h.typeCount,?_,?_,?_,?_,?_,?_,?_,telRows⟩
  · rw [legacyTypeCtx_constraints count]
    exact corr.admits C ts h.admits
  · intro a ha
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [embedTys_eq_map] using ha)
    exact ⟨by simpa only [legacyTypeCtx_length count] using (embed_wf (nv := nv) (h.typeScope old ho).1),
      legacy_ordinary old (h.typeScope old ho).2⟩
  · simpa only [List.length_map,corr.neffs,Benitoite.Release.PrimSig.inst] using h.rowCount
  · intro e he
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp he
    simpa only [List.length_replicate] using ((rows old ho).annotation_at rfl count (List.replicate nv none)).wf.2.2.2.1
  · exact signatureTel_effect_rows s.names s.params s.ret s.eff _ telRows
  · rw [qeq]
    simpa only [List.length_map] using h.sourceQ
  · rw [qeq]
    exact legacy_RowTransport h.noFailRows

namespace LegacyValueCases

theorem prim_case {K P0 B0 B κ Ψ Q C Γ b s0 rs ts es}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.prim b ts es rs)
        (Benitoite.Release.fnTy (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff ts es)))
    (lookup : B0.sig b = some s0) (range : B0.RangeAdmissible b s0 rs)
    (names : Benitoite.Release.NamesWF (s0.inst rs).names (s0.inst rs).params)
    (admissible : Benitoite.Release.PrimitiveAdmissible C (s0.inst rs) Q ts es) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.prim b ts es rs)
        (Benitoite.Release.fnTy (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff ts es)) := by
  intro Φ
  obtain ⟨s,hs,corr⟩ := tables.primitives b s0 lookup
  obtain ⟨old,new,hold,hnew,hcount,source,args,rows,_ranges⟩ := reg.2.1
  have hold' : old = s0 := Option.some.inj (hold.symm.trans lookup)
  have hnew' : new = s := Option.some.inj (hnew.symm.trans hs)
  subst old; subst new
  have count := reg.1.2.2.1
  have ha := legacy_value_annotation reg
  let oldTy := Benitoite.Release.fnTy (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff ts es
  have ti := reg.2.2.2 oldTy (List.mem_cons_self)
  have type_eq := legacy_primitive_type ti rfl args rows
  have tel_eq := legacy_range_signatureTel s0.names s0.params s0.ret s0.eff rs
  have ht : s.tel = signatureTel s0.names (embedTys s0.params) (embedTy s0.ret) (embedEff s0.eff) := by
    simp only [PrimSig.tel,corr.names,corr.params,corr.ret,corr.eff,
      legacy_embedParameters,legacy_shiftV,legacy_shiftVEff]
  have full_annotation : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      (Γ.map (Option.map embedTy))
      (embedTy (Benitoite.Release.fnTy s0.names (s0.params.map (Benitoite.Release.Ty.instR rs))
        (s0.ret.instR rs) (Benitoite.Release.Eff.instR rs s0.eff).norm ts es)) := by
    rw [type_eq,legacy_old_instR_fn] at ha
    exact ha
  have result := legacy_instantiated_annotation s0.names (s0.params.map (Benitoite.Release.Ty.instR rs))
    (s0.ret.instR rs) (Benitoite.Release.Eff.instR rs s0.eff).norm ts es full_annotation
  have source_wf := legacy_range_signatureTel_wf s0.names s0.params s0.ret s0.eff rs
    source.2.1 range.1.length
  have source_wf' : (Ty.dependentFn (Tel.instR (rs.map embedRange) s.tel)).WF 0 (TypeCtx.kinds s.tparams).length 0 := by
    simpa only [ht,TypeCtx.kinds,List.length_map,←hcount] using source_wf
  have si : SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      (Γ.map (Option.map embedTy)) (Tel.instR (rs.map embedRange) s.tel)
      (TypeCtx.kinds s.tparams) (embedTys ts) (es.map embedEff) := by
    apply legacy_signatureInstance count source_wf' (args.annotations rfl count _) args.kindArgs
      (rows.annotations rfl count _) rows.rowKinds
    simpa only [ht,tel_eq] using result
  have hn : NamesWF s.names s.params := by
    simpa only [corr.names,corr.params,legacy_embedParameters,NamesWF,Benitoite.Release.NamesWF,
      Benitoite.Release.PrimSig.inst,embedTys_eq_map,List.length_map] using names
  have hv := HasTypeVQ.V_Prim (Ψ := embedStoreTy Ψ) (Φ := Φ) hs (legacy_RangeAdmissible tables corr range)
    hn (legacy_PrimitiveAdmissible (K := K) (P0 := P0) corr count admissible
      (by simpa only [List.length_map] using rows)) si
  have hn' : Benitoite.Release.NamesWF s0.names s0.params := by
    simpa only [Benitoite.Release.PrimSig.inst,Benitoite.Release.NamesWF,List.length_map] using names
  have he := legacy_instantiated_norm s0.names (s0.params.map (Benitoite.Release.Ty.instR rs))
    (s0.ret.instR rs) (Benitoite.Release.Eff.instR rs s0.eff).norm ts es
    (show Benitoite.Release.NamesWF s0.names (s0.params.map (Benitoite.Release.Ty.instR rs)) from
      ⟨by simpa only [List.length_map] using hn'.1,hn'.2⟩)
  have type_eq' : oldTy = Benitoite.Release.fnTy s0.names
      (s0.params.map (Benitoite.Release.Ty.instR rs)) (s0.ret.instR rs)
      (Benitoite.Release.Eff.instR rs s0.eff).norm ts es := by
    simpa only [oldTy,legacy_old_instR_fn,Benitoite.Release.fnTy] using type_eq
  rw [←type_eq'] at he
  exact .V_Sub hv (.convert (by
    simpa only [ht,tel_eq] using he))
    (legacy_value_annotation reg).wf (legacy_value_annotation reg).sorted (legacy_value_annotation reg).declared

end LegacyValueCases

end
end Benitoite.Release.Refinement
