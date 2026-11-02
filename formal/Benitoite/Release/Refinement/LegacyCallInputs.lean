import Benitoite.Release.Refinement.LegacyTypeAlgebra
import Benitoite.Release.Refinement.LegacyTyping

namespace Benitoite.Release.Refinement
noncomputable section

mutual
  theorem legacy_qTy (a : Benitoite.Release.Ty) (i : Nat) :
      QTy (embedTy a) i ↔ Benitoite.Release.QTy a i := by
    cases a <;> simp only [embedTy,QTy,Benitoite.Release.QTy,legacy_qTy,legacy_qTys,legacy_qEff]
  theorem legacy_qTys (as : List Benitoite.Release.Ty) (i : Nat) :
      QTys (embedTys as) i ↔ Benitoite.Release.QTys as i := by
    cases as <;> simp only [embedTys,QTys,Benitoite.Release.QTys,legacy_qTy,legacy_qTys]
  theorem legacy_qEff (e : Benitoite.Release.Eff) (i : Nat) :
      QEff (embedEff e) i ↔ Benitoite.Release.QEff e i := by
    cases e with
    | mk atoms fs =>
      simp only [embedEff,QEff,Benitoite.Release.QEff,legacy_qTys,
      show ∀ a, embedAtoms a (.rho i) = a (.rho i) from fun _ => rfl]
      cases fs <;> simp [embedTys_eq_map]
end

theorem legacy_Qsig (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty)
    (e : Benitoite.Release.Eff) :
    Qsig (embedTys ps) (embedTy r) (embedEff e) = Benitoite.Release.Qsig ps r e := by
  funext i
  exact propext (by simp only [Qsig,Benitoite.Release.Qsig,legacy_qTys,legacy_qTy,legacy_qEff])

mutual
  theorem legacy_rowsTy (a : Benitoite.Release.Ty) (pe : Nat → Prop) :
      (embedTy a).RowsIn pe ↔ a.RowsIn pe := by
    cases a <;> simp only [embedTy,Ty.RowsIn,Benitoite.Release.Ty.RowsIn,
      legacy_rowsTy,legacy_rowsTys,legacy_rowsEff]
  theorem legacy_rowsTys (as : List Benitoite.Release.Ty) (pe : Nat → Prop) :
      Ty.RowsInList pe (embedTys as) ↔ Benitoite.Release.Ty.RowsInList pe as := by
    cases as <;> simp only [embedTys,Ty.RowsInList,Benitoite.Release.Ty.RowsInList,legacy_rowsTy,legacy_rowsTys]
  theorem legacy_rowsEff (e : Benitoite.Release.Eff) (pe : Nat → Prop) :
      Eff.RowsIn pe (embedEff e) ↔ Benitoite.Release.Eff.RowsIn pe e := by
    cases e
    simp only [embedEff,Eff.RowsIn,Benitoite.Release.Eff.RowsIn,legacy_rowsTys,
      show ∀ a i, embedAtoms a (.rho i) = a (.rho i) from fun _ _ => rfl]
end

theorem legacy_NoFail {Q e} (h : Benitoite.Release.NoFail Q e) : NoFail Q (embedEff e) := by
  cases e with
  | mk atoms fs =>
    exact ⟨by have hf : fs = [] := h.1; change embedTys fs = []; rw [hf]; rfl, h.2⟩

theorem legacy_row (i : Nat) : embedEff (Benitoite.Release.Eff.row i) = Eff.row i := by
  unfold Benitoite.Release.Eff.row Benitoite.Release.Eff.ofAtoms embedEff Eff.row
  congr 1
  funext a
  cases a with
  | rho j =>
    simp only [embedAtoms,Atom.toOld?,Option.map_some,Option.getD_some]
    apply Bool.eq_iff_iff.mpr
    simp only [beq_iff_eq,decide_eq_true_eq,Benitoite.Release.Atom.rho.injEq]
  | name l ix => cases ix with
    | rvar j => simp [embedAtoms,Atom.toOld?]
    | fixed r => cases r <;> simp [embedAtoms,Atom.toOld?]

theorem legacy_RowTransport {Qs Qt es} (h : Benitoite.Release.RowTransport Qs Qt es) :
    RowTransport Qs Qt (es.map embedEff) := by
  intro i hi
  have hh := legacy_NoFail (h i hi)
  simp only [Benitoite.Release.Eff.rowImage] at hh
  cases he : es[i]? with
  | none => simpa only [List.getElem?_map,he,Option.map_none,Option.getD_none,
      legacy_row] using hh
  | some e => simpa only [List.getElem?_map,he,Option.map_some,Option.getD_some] using hh

theorem legacy_SatAll {K P0 B0 B κ C ts tps}
    (tables : LegacyTables K P0 B0 B) (count : κ.length = C.length)
    (h : Benitoite.Release.SatAll B0 C ts tps) :
    SatAll B (legacyTypeCtx C κ) (embedTys ts) tps := by
  refine ⟨by simpa only [embedTys_eq_map,List.length_map] using h.1,?_⟩
  intro i a p ha hp
  obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [embedTys_eq_map,List.getElem?_map] using ha)
  rw [legacyTypeCtx_constraints count]
  exact tables.sat C old p (h.2 i old p ho hp)

theorem legacy_Admissible {K P0 B0 B κ C nv tps ne Qs Qt ts es e}
    (tables : LegacyTables K P0 B0 B) (count : κ.length = C.length)
    (h : Benitoite.Release.Admissible B0 C tps ne Qs Qt ts es e)
    (rows : LegacyRowsInput K P0 ⟨κ,C,0,nv⟩ es) :
    Admissible B (legacyTypeCtx C κ) nv tps ne Qs Qt (embedTys ts) (es.map embedEff) (embedEff e) := by
  refine ⟨legacy_SatAll tables count h.types,?_,by simpa using h.rowCount,?_,?_,?_,legacy_RowTransport h.noFailRows⟩
  · intro a ha
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [embedTys_eq_map] using ha)
    exact ⟨by simpa only [legacyTypeCtx_length count] using (embed_wf (nv := nv) (h.typeScope old ho).1),
      legacy_ordinary old (h.typeScope old ho).2⟩
  · intro f hf
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp hf
    simpa only [List.length_replicate] using ((rows old ho).annotation_at rfl count (List.replicate nv none)).wf.2.2.2.1
  · simpa only [List.length_map] using (legacy_rowsEff e _).mpr h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

theorem LegacyTypesInput.annotations {K P0 Δ ts ks} (h : LegacyTypesInput K P0 Δ ts ks)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) (Γ : Ctx) :
    TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx Δ.constraints Δ.kinds) Γ (embedTys ts) := by
  intro a ha
  obtain ⟨old,hm,rfl⟩ := List.mem_map.mp (by simpa only [embedTys_eq_map] using ha)
  obtain ⟨i,hi⟩ := List.mem_iff_getElem?.mp hm
  have ilt : i < ks.length := h.1 ▸ (List.getElem?_eq_some_iff.mp hi).1
  have hk : ks[i]? = some ks[i] := List.getElem?_eq_getElem ilt
  exact (h.2 i old ks[i] hi hk).1.annotation_at nr count Γ

theorem LegacyRowsInput.annotations {K P0 Δ es} (h : LegacyRowsInput K P0 Δ es)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) (Γ : Ctx) :
    RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx Δ.constraints Δ.kinds) Γ (es.map embedEff) := by
  intro e he
  obtain ⟨old,hm,rfl⟩ := List.mem_map.mp he
  exact (h old hm).annotation_at nr count Γ

theorem legacy_value_annotation {K P0 B0 B κ Ψ Q C Γ v a}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a)) :
    Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) (embedTy a) :=
  (reg.2.2.2).annotation (a := a) (by simp) reg.1.2.2.1 _

namespace LegacyValueCases

theorem fun_case {K P0 B0 B κ Ψ Q C Γ f d ts es}
    (kinds : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.fnRef f ts es) (Benitoite.Release.fnTy d.names d.params d.ret d.eff ts es)))
    (lookup : P0.defs f = some d) (names : Benitoite.Release.NamesWF d.names d.params)
    (admissible : Benitoite.Release.Admissible B0 C d.tparams d.neffs
      (Benitoite.Release.Qsig d.params d.ret d.eff) Q ts es d.eff) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.fnRef f ts es) (Benitoite.Release.fnTy d.names d.params d.ret d.eff ts es)) := by
  intro Φ
  obtain ⟨d',hd',source,args,rows⟩ := reg.2.1
  have hd : d' = d := Option.some.inj (hd'.symm.trans lookup)
  subst d'
  have count := reg.1.2.2.1
  have ha := legacy_value_annotation reg
  have hs := legacy_signatureTel_annotation d.names d.params d.ret d.eff
    (source.annotation_at rfl (kinds.1 f d lookup) [])
  have hn : NamesWF d.names (embedParameters d.params) := by
    simpa only [legacy_embedParameters,NamesWF,Benitoite.Release.NamesWF,embedTys_eq_map,List.length_map] using names
  have ha' := legacy_Admissible tables count admissible rows
  rw [←legacy_Qsig] at ha'
  have si := embedDefWithKinds_signatureInstance kinds lookup count
    (by simpa only [embedDefWithKinds,embedDef,Def.tel,legacy_embedParameters,
      legacy_shiftV,legacy_shiftVEff,legacyTypeCtx_length (kinds.1 f d lookup),kinds.1 f d lookup,List.length_nil] using hs.wf)
    (args.annotations rfl count _) args.kindArgs (rows.annotations rfl count _) rows.rowKinds
    (by simpa only [embedDefWithKinds,embedDef,Def.tel,legacy_embedParameters,
      legacy_shiftV,legacy_shiftVEff] using legacy_instantiated_annotation d.names d.params d.ret d.eff ts es ha)
  have hv := HasTypeVQ.V_Fun (Ψ := embedStoreTy Ψ) (Φ := Φ) (embedProgramWithKinds_def lookup)
    hn (by simpa only [embedDefWithKinds,embedDef,TypeCtx.constraints,
      embedTParamsWithKinds_constraints _ _ (kinds.1 f d lookup),List.length_map,legacy_embedParameters,
      legacy_shiftV,legacy_shiftVEff] using ha') si
  exact .V_Sub hv (.convert (by
    simpa only [embedDefWithKinds,embedDef,Def.tel,legacy_embedParameters,
      legacy_shiftV,legacy_shiftVEff] using legacy_instantiated_norm d.names d.params d.ret d.eff ts es names))
    ha.wf ha.sorted ha.declared

end LegacyValueCases

end
end Benitoite.Release.Refinement
