import Benitoite.Release.Refinement.LegacyCompCases

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_types_annotations {K P0 κ C nv as}
    (h : LegacyNodeTypes K P0 κ C nv as) (count : κ.length = C.length) (Γ : Ctx) :
    TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys as) := by
  intro a ha
  obtain ⟨old,hm,rfl⟩ := List.mem_map.mp (by simpa only [embedTys_eq_map] using ha)
  exact (h old hm).annotation_at rfl count Γ

theorem legacy_fn_annotation {K P0 κ C Γ ns ps r e}
    (names : Benitoite.Release.NamesWF ns ps)
    (params : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ps))
    (ret : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTy r))
    (row : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (embedTy (.fn [] [] (.base .unit) e))) :
    Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTy (.fn ns ps r e)) := by
  have hn : NamesWF ns (embedTys ps) := ⟨by simpa [embedTys_eq_map] using names.1,names.2⟩
  have hw : Ty.WFList 0 (legacyTypeCtx C κ).length Γ.length (embedTys ps) := by
    rw [Ty.wfList_iff]
    intro a ha
    exact (params a ha).wf
  have hd : declaredTys (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ps) := by
    generalize embedTys ps = xs at params ⊢
    induction xs with
    | nil => trivial
    | cons a xs ih => exact ⟨(params a (by simp)).declared,ih (by intro b hb; exact params b (by simp [hb]))⟩
  exact ⟨⟨hn,hw,ret.wf,row.wf.2.2.2.1,row.wf.2.2.2.2⟩,
    embedTy_sorted _ Γ,⟨hd,ret.declared,row.declared.2.2⟩⟩

theorem legacy_signature_arguments (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (vs : List Val)
    (hn : Benitoite.Release.NamesWF ns ps) (hlen : vs.length = ps.length) :
    Tel.arguments (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)) vs =
      some (Ty.normTys (embedTys ps), (embedTy r).norm, (embedEff e).norm) := by
  induction ns generalizing ps vs with
  | nil =>
    have hp : ps = [] := List.length_eq_zero_iff.mp hn.1.symm
    subst ps
    have hv : vs = [] := List.length_eq_zero_iff.mp hlen
    subst vs
    simp only [signatureTel,embedTys,Tel.arguments,Ty.normTys]
  | cons n ns ih =>
    cases ps with
    | nil => have h := hn.1; simp at h
    | cons p ps =>
      cases vs with
      | nil => simp at hlen
      | cons v vs =>
        simp only [signatureTel,embedTys,Tel.arguments]
        have hbind : Tel.bind (Tel.argumentsEnv v)
            (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)) =
            (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)).norm := by
          rw [legacy_signatureTel,Tel.bind_toTel]
          have hb (a : Benitoite.Release.Ty) : (embedTy a).bind (Tel.argumentsEnv v) = (embedTy a).norm := by
            have h : (Ty.shiftV 1 0 (embedTy a)).bind (Tel.argumentsEnv v) = (embedTy a).norm := by
              rw [argumentsEnv_eq]
              unfold Ty.bind SubstEnv.valuesOnly
              rw [←Ty.rawSubstV_eq_rawBind,Ty.substV_shift_cancel _ (by intro i; rfl)]
            simpa only [legacy_shiftV] using h
          have he : Eff.bind (Tel.argumentsEnv v) (embedEff e) = (embedEff e).norm := by
            have h : Eff.bind (Tel.argumentsEnv v) (Eff.shiftV 1 0 (embedEff e)) = (embedEff e).norm := by
              rw [argumentsEnv_eq]
              unfold Eff.bind SubstEnv.valuesOnly
              rw [←Eff.rawSubstV_eq_rawBind,Eff.substV_shift_cancel _ (by intro i; rfl)]
            simpa only [legacy_shiftVEff] using h
          simp only [hb,he,Tel.norm_toTel,Ty.normTys_eq_map,embedTys_eq_map,List.map_map,Function.comp_def]
        rw [hbind,Tel.arguments_norm]
        rw [ih ps vs ⟨Nat.succ.inj hn.1,hn.2.of_cons⟩ (Nat.succ.inj hlen)]
        rfl

theorem HasTypeVsQ.normal_types {P B Ψ Q C Γ Φ vs as}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (Ty.normTys as) := by
  match h with
  | .nil => exact .nil
  | .cons hv hs => exact .cons hv.V_Normal hs.normal_types

namespace LegacyCompCases

theorem meth_case {K P0 B0 B κ Ψ Q C Γ R v cl τ cd m ms ss es ws L}
    (kinds : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.meth v m ss es ws)
      (ms.ret.subst (ss ++ [τ]) es) (Benitoite.Release.Eff.substAt 0 (ss ++ [τ]) es ms.eff) L))
    (lookup : P0.classes cl = some cd) (method : cd.methods m = some ms)
    (names : Benitoite.Release.NamesWF ms.names ms.params)
    (sat : Benitoite.Release.SatAll B0 C ss ms.tparams)
    (scope : ∀ t ∈ ss ++ [τ], Benitoite.Release.Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e)
    (admissible : Benitoite.Release.MethodRowsAdmissible C Q ms es)
    (source : LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl],
      ms.tparams ++ [({} : Benitoite.Release.TParam)],0,0⟩
      (.fn ms.names ms.params ms.ret ms.eff) .value)
    (ssInput : LegacyTypesInput K P0 ⟨κ,C,0,Γ.length⟩ ss (K.methodParams cl m))
    (vInput : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v (.dict cl τ)))
    (wsInput : LegacyNodeRegular K P0 B0 B (.values κ Ψ Q C Γ ws
      (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es))))
    (iv : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v (.dict cl τ)))
    (iws : LegacyJudgment.Embedded K P0 B (.values κ Ψ Q C Γ ws
      (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es)))) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.meth v m ss es ws)
      (ms.ret.subst (ss ++ [τ]) es) (Benitoite.Release.Eff.substAt 0 (ss ++ [τ]) es ms.eff) L) := by
  intro Φ
  have count := reg.1.2.2.1
  have ret := legacy_comp_annotation reg
  have rows : LegacyRowsInput K P0 ⟨κ,C,0,Γ.length⟩ es := reg.2.1.2.2.1
  have tInput := vInput.2.2.2 (.dict cl τ) (by simp)
  obtain ⟨cd',hcd',htKind⟩ := tInput.1
  have hcd : cd' = embedClassDeclWithKinds K cl cd :=
    Option.some.inj (hcd'.symm.trans (embedProgramWithKinds_class lookup))
  subst cd'
  have tau : LegacyTypeInput K P0 ⟨κ,C,0,Γ.length⟩ τ (K.classArgument cl) :=
    ⟨htKind,tInput.2.1,tInput.2.2.1,tInput.2.2.2.1,tInput.2.2.2.2⟩
  have args : LegacyKindArgs K P0 κ (ss ++ [τ]) (K.methodParams cl m ++ [K.classArgument cl]) := by
    have hs := ssInput.kindArgs
    refine ⟨by simp only [List.length_append,List.length_singleton,hs.1],?_⟩
    intro i a k ha hk
    by_cases hi : i < ss.length
    · have hklen : i < (K.methodParams cl m).length := by have hlen := ssInput.1; omega
      exact hs.2 i a k (by simpa only [List.getElem?_append_left hi] using ha)
        (by simpa only [List.getElem?_append_left hklen] using hk)
    · have hidx : i = ss.length := by
        have hl := (List.getElem?_eq_some_iff.mp ha).1
        simp only [List.length_append,List.length_singleton] at hl
        omega
      subst i
      simp only [List.getElem?_append_right (Nat.le_refl _),Nat.sub_self,List.getElem?_cons_zero] at ha
      have hk' : k = K.classArgument cl := by
        simpa only [hs.1,List.getElem?_append_right (Nat.le_refl _),Nat.sub_self,List.getElem?_cons_zero,Option.some.injEq] using hk.symm
      cases ha
      subst k
      exact ⟨tau.1,fun _ => legacy_ordinary τ (scope τ (by simp)).2⟩
  have allTypes : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      (Γ.map (Option.map embedTy)) (embedTys (ss ++ [τ])) := by
    simp only [embedTys_eq_map,List.map_append,List.map_cons,List.map_nil]
    intro a ha
    rcases List.mem_append.mp ha with ha | ha
    · exact ssInput.annotations rfl count _ a (by simpa only [embedTys_eq_map] using ha)
    · obtain rfl := List.mem_singleton.mp ha
      exact tau.annotation_at rfl count _
  have row := (reg.2.2.2.1 (Benitoite.Release.Eff.substAt 0 (ss ++ [τ]) es ms.eff) (by simp)).annotation_at rfl count (Γ.map (Option.map embedTy))
  have namesInst : Benitoite.Release.NamesWF ms.names (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es)) :=
    ⟨by simpa using names.1,names.2⟩
  have fnAnn := legacy_fn_annotation namesInst
    (legacy_types_annotations wsInput.2.2 count _) ret row
  have sourceCount : (K.methodParams cl m ++ [K.classArgument cl]).length =
      (ms.tparams ++ [({} : Benitoite.Release.TParam)]).length := by
    simp only [List.length_append,List.length_singleton,kinds.2 cl cd m ms lookup method]
  have src := legacy_signatureTel_annotation ms.names ms.params ms.ret ms.eff
    (source.annotation_at rfl sourceCount [])
  have sig := embedMethSigWithKinds_signatureInstance kinds lookup method count
    (by simpa only [embedMethSigWithKinds,embedMethSig,MethSig.tel,legacy_embedParameters,
      legacy_shiftV,legacy_shiftVEff,legacyTypeCtx_length sourceCount,
      List.length_nil,List.length_append,List.length_singleton,kinds.2 cl cd m ms lookup method] using src.wf)
    allTypes args (rows.annotations rfl count _) rows.rowKinds
    (by simpa only [embedMethSigWithKinds,embedMethSig,MethSig.tel,legacy_embedParameters,
      legacy_shiftV,legacy_shiftVEff,embedTys_eq_map,List.map_append,List.map_cons,List.map_nil] using
      legacy_instantiated_annotation ms.names ms.params ms.ret ms.eff (ss ++ [τ]) es (by simpa only [Benitoite.Release.fnTy,Benitoite.Release.Ty.subst,
        Benitoite.Release.Ty.substAt,Benitoite.Release.Ty.substTysAt_eq_map] using fnAnn))
  have admissible' : MethodRowsAdmissible (legacyTypeCtx C κ) Γ.length Q
      (embedMethSigWithKinds (K.methodParams cl m) ms) (es.map embedEff) := by
    refine ⟨by simpa only [List.length_map,embedMethSigWithKinds,embedMethSig] using admissible.1,?_,?_,?_,?_⟩
    · intro e he
      obtain ⟨old,hm,rfl⟩ := List.mem_map.mp he
      simpa only [List.length_map] using ((rows old hm).annotation_at rfl count (Γ.map (Option.map embedTy))).wf.2.2.2.1
    · simpa only [embedMethSigWithKinds,embedMethSig,legacy_shiftVEff,List.length_map,legacy_rowsEff] using admissible.2.2.1
    · simpa only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,
        legacy_Qsig,List.length_map] using admissible.2.2.2.1
    · simpa only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,
        legacy_Qsig] using legacy_RowTransport admissible.2.2.2.2
  have argsEq := legacy_signature_arguments ms.names
    (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es))
    (ms.ret.subst (ss ++ [τ]) es) (Benitoite.Release.Eff.substAt 0 (ss ++ [τ]) es ms.eff)
    (embedVals ws) ⟨by simpa using names.1,names.2⟩
    (by simpa only [embedTys_eq_map,List.length_map] using (iws Φ).length)
  have hcall := HasTypeCQ.C_Meth (ss := embedTys ss) (es := es.map embedEff) (R := R.map embedTy) (Δ := L.map (Option.map embedBuilderKind))
    (iv Φ) (embedProgramWithKinds_method lookup method).1 (embedProgramWithKinds_method lookup method).2
    (by simpa only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,NamesWF,
      Benitoite.Release.NamesWF,embedTys_eq_map,List.length_map] using names)
    (by simpa only [embedMethSigWithKinds,embedMethSig,
      TypeCtx.constraints,embedTParamsWithKinds_constraints _ _ (kinds.2 cl cd m ms lookup method)] using legacy_SatAll tables count sat)
    (by simpa only [embedTys_eq_map,List.map_append,List.map_cons,List.map_nil,TypeCtx.kinds] using sig) (by simpa only [List.length_map] using admissible')
    (by
      simp only [embedMethSigWithKinds,embedMethSig,MethSig.tel,legacy_embedParameters,
        legacy_shiftV,legacy_shiftVEff]
      change Tel.arguments (instantiatedTel (signatureTel ms.names (embedTys ms.params)
        (embedTy ms.ret) (embedEff ms.eff)) (embedTys ss ++ [embedTy τ]) (es.map embedEff)) _ = _
      rw [show embedTys ss ++ [embedTy τ] = embedTys (ss ++ [τ]) from by simp [embedTys_eq_map]]
      rw [legacy_instantiatedTel]
      exact argsEq)
    (iws Φ).normal_types
    ret.norm
  exact .C_Sub hcall (.convert (Ty.norm_idem _))
    (Eff.covers_norm_right.mpr (.refl _ _ _)) ret.wf ret.sorted ret.declared

end LegacyCompCases

end
end Benitoite.Release.Refinement
