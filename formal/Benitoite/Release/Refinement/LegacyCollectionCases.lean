import Benitoite.Release.Refinement.LegacyCallInputs

namespace Benitoite.Release.Refinement
noncomputable section

namespace LegacyValueCases

theorem con_case {K P0 B0 B κ Ψ Q C Γ c ts vs cd}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.con c ts vs) (.data cd.data ts)))
    (lookup : P0.cons c = some cd) (arity : ts.length = cd.ntys)
    (ih : LegacyJudgment.Embedded K P0 B
      (.values κ Ψ Q C Γ vs (cd.args.map (Benitoite.Release.Ty.subst ts [])))) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.con c ts vs) (.data cd.data ts)) := by
  intro Φ
  obtain ⟨⟨cd',hc,args⟩,_⟩ := reg.2.1
  have hc' : cd' = cd := Option.some.inj (hc.symm.trans lookup)
  subst cd'
  have ha := legacy_value_annotation reg
  apply HasTypeVQ.V_Con (cd := embedConDecl cd)
    (by simp only [embedProgramWithKinds_cons,lookup,Option.map_some])
    (by simpa only [embedTys_eq_map,List.length_map,embedConDecl] using arity)
    (args.kindArgs.kinded (legacyTypeCtx_kinds reg.1.2.2.1)) _ _ ha
  · intro a ha
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [embedConDecl,embedTys_eq_map] using ha)
    simpa only [embedConDecl,List.length_replicate,List.length_nil] using (tables.constructorFields c cd lookup old ho).1.wf
  · simpa only [embedConDecl,embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst] using ih Φ

theorem list_case {K P0 B0 B κ Ψ Q C Γ vs a}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.list vs) (.list a)))
    (ih : LegacyJudgment.Embedded K P0 B (.each κ Ψ Q C Γ vs a)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.list vs) (.list a)) := by
  intro Φ
  have ha := legacy_value_annotation reg
  exact .V_List (ih Φ) ha.wf ha.sorted ha.declared

theorem map_case {K P0 B0 B κ Ψ Q C Γ keys vs a b}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.mapV keys vs) (.map a b)))
    (count : keys.length = vs.length) (key : B0.sat C a Benitoite.Release.TParam.keyC)
    (ihkeys : LegacyJudgment.Embedded K P0 B (.each κ Ψ Q C Γ keys a))
    (ihvalues : LegacyJudgment.Embedded K P0 B (.each κ Ψ Q C Γ vs b)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.mapV keys vs) (.map a b)) := by
  intro Φ
  have ha := legacy_value_annotation reg
  apply HasTypeVQ.V_Map (ihkeys Φ) (ihvalues Φ) (by simpa only [embedVals_length] using count)
  · rw [legacyTypeCtx_constraints reg.1.2.2.1]
    exact tables.sat C a _ key
  · exact ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
  · exact ⟨ha.wf.2,ha.sorted.2,ha.declared.2⟩

theorem set_case {K P0 B0 B κ Ψ Q C Γ vs a}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.setV vs) (.set a)))
    (key : B0.sat C a Benitoite.Release.TParam.keyC)
    (ih : LegacyJudgment.Embedded K P0 B (.each κ Ψ Q C Γ vs a)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.setV vs) (.set a)) := by
  intro Φ
  have ha := legacy_value_annotation reg
  apply HasTypeVQ.V_Set (ih Φ)
  · rw [legacyTypeCtx_constraints reg.1.2.2.1]
    exact tables.sat C a _ key
  · exact ⟨ha.wf,ha.sorted,ha.declared⟩

theorem dict_case {K P0 B0 B κ Ψ Q C Γ i ts vs id}
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))))
    (lookup : P0.impls i = some id) (sat : Benitoite.Release.SatAll B0 C ts id.tparams)
    (ih : LegacyJudgment.Embedded K P0 B
      (.values κ Ψ Q C Γ vs (id.dictTys.map (Benitoite.Release.Ty.subst ts [])))) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))) := by
  intro Φ
  obtain ⟨⟨id',hid,target,fields,args⟩,_⟩ := reg.2.1
  have hid' : id' = id := Option.some.inj (hid.symm.trans lookup)
  subst id'
  have count := reg.1.2.2.1
  have ha := legacy_value_annotation reg
  have hfields : (embedImplDecl id).dictTys = embedTys id.dictTys := by
    simp only [ImplDecl.dictTys,Benitoite.Release.ImplDecl.dictTys,embedImplDecl,embedTys_eq_map,
      List.map_map,Function.comp_def,embedTy]
  have hv := HasTypeVQ.V_Dict (Ψ := embedStoreTy Ψ) (Q := Q) (Φ := Φ)
    (show (embedProgramWithKinds K P0).impls i = some (embedImplDecl id) from by
      simp only [embedProgramWithKinds_impls,lookup,Option.map_some])
    (legacy_SatAll tables count sat) (args.annotations rfl count _)
    (args.kindArgs.kinded (legacyTypeCtx_kinds count))
    (by
      intro a hm
      obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [hfields,embedTys_eq_map] using hm)
      simpa only [embedImplDecl,List.length_replicate] using (fields old ho).2.1)
    (by simpa only [embedImplDecl,List.length_replicate] using target.2.1)
    (by simpa only [hfields,embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst] using ih Φ)
    (by simpa only [embedTy,legacy_subst,embedImplDecl] using ha)
  simpa only [embedVal,embedTy,embedImplDecl,legacy_subst] using hv

end LegacyValueCases

end
end Benitoite.Release.Refinement
