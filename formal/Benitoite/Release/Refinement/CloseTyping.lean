import Benitoite.Release.Refinement.CaptureTransport
import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.VarianceFormation
import Benitoite.Release.Refinement.ProgramWellFormed

/-! # 値を閉じる型保存（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Ty.Annotation.toTel {P C Γ ns ps r e}
    (h : Ty.Annotation P C Γ (.fn ns ps r e)) :
    Ty.Annotation P C Γ (.dependentFn (Ty.toTel ns ps r e)) := by
  refine ⟨Tel.wf_toTel h.wf.1 h.wf.2.1 h.wf.2.2.1 h.wf.2.2.2.1 h.wf.2.2.2.2,
    Ty.sorted_toTel h.sorted, ?_⟩
  have hd := h.declared
  clear h
  induction ns generalizing Γ ps r e with
  | nil => exact hd.2
  | cons n ns ih =>
    cases ps with
    | nil => exact hd.2
    | cons a ps =>
      refine ⟨hd.1.1, ?_⟩
      have hm : ShiftMap 1 0 Γ (Γ.extend a) := by
        simpa [bindParams, Ctx.extend] using ShiftMap.outer Γ [a]
      exact ih (hm.declared (a := .fn ns ps r e) ⟨hd.1.2, hd.2⟩)

theorem hideConts_idempotent (Γ : Ctx) : hideConts (hideConts Γ) = hideConts Γ := by
  simp only [hideConts, List.map_map]
  apply List.map_congr_left
  intro x _
  cases x with
  | none => rfl
  | some a =>
    simp only [Function.comp_apply]
    cases ha : a.core <;> simp only [ha]

theorem close_dependent_lambda {P B Ψ R Γ Φ cap t body}
    (hB : B.CoreAssumptions P) (hw : Ψ.WF)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ha : Ty.Annotation P [] Γ (.dependentFn t))
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ t body) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal cap (.dependentLam t body)) (cap.closeTy (.dependentFn t)) := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    refine ⟨by simp [hideConts], ?_⟩
    intro i a hi ho
    simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩
  have hah : Ty.Annotation P [] (hideConts Γ) (.dependentFn t) := by
    simpa only [Ty.shiftV_zero] using hm.annotation ha
  have hch := hc.hideBuilders_hideConts (R' := none) hB.values hw
  have hat := hch.substOk.telAnnotation hah
  have hh : DependentClosureTy P B Ψ (.mk cap body) (cap.closeTel t) :=
    .mk hch (by simpa only [hideConts_idempotent] using hb)
      (by simpa only [hideConts_idempotent] using hah) hat
  have hv := HasTypeVQ.V_Closure (Q := Qempty) (Φ := []) hat
    (Tel.RuntimeShape.mk hat.wf hat.wf (Tel.SameInputs.refl _)) hh
  simpa only [closeVal, Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind,
    Ty.norm, Capture.closeTel, Tel.bind, Ty.norm_foldFn, Tel.norm_idem] using hv.V_Normal

theorem close_lambda {P B Ψ R Γ Φ cap ns ps r e body}
    (hB : B.CoreAssumptions P) (hw : Ψ.WF)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ha : Ty.Annotation P [] Γ (.fn ns ps r e))
    (hb : HasTypeCQ P B (hideBuilders Ψ) Qempty []
      (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
      (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0)
      (Eff.shiftV ps.length 0 e) []) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal cap (.lam ns ps body)) (cap.closeTy (.fn ns ps r e)) := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    refine ⟨by simp [hideConts], ?_⟩
    intro i a hi ho
    simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩
  have hah : Ty.Annotation P [] (hideConts Γ) (.fn ns ps r e) := by
    simpa only [Ty.shiftV_zero] using hm.annotation ha
  have hch := hc.hideBuilders_hideConts (R' := none) hB.values hw
  have hat := hch.substOk.telAnnotation hah.toTel
  have hh : DependentClosureTy P B Ψ (.mk cap body) (cap.closeTel (Ty.toTel ns ps r e)) :=
    .mk hch
      (by simpa only [hideConts_idempotent] using
        (TelBodyTy.toTel_iff ha.wf.1).mpr hb)
      (by simpa only [hideConts_idempotent] using hah.toTel) hat
  have hrt : Ty.Annotation P [] (hideConts Γ) (.fn ns ps (.base .unit) Eff.empty) :=
    ⟨⟨hah.wf.1, hah.wf.2.1, trivial, trivial, rfl⟩,
      ⟨hah.sorted.1, trivial, trivial⟩, ⟨hah.declared.1, trivial, trivial⟩⟩
  have hrt' := hch.substOk.telAnnotation hrt.toTel
  have hshape : Tel.RuntimeShape (cap.closeTel (lambdaShape ns ps))
      (cap.closeTel (Ty.toTel ns ps r e)) :=
    ⟨hrt'.wf, hat.wf, (Tel.SameInputs.toTel ns ps _ _ _ _).bind _⟩
  have hv := HasTypeVQ.V_Closure (Q := Qempty) (Φ := []) hat hshape hh
  apply hv.convert _ (hc.substOk.annotation ha)
  change (Ty.dependentFn (Tel.bind (valEnv cap.env) (Ty.toTel ns ps r e))).norm = _
  rw [Tel.bind_toTel, Ty.norm_toTel]
  · simp only [substTyValues, Ty.bind_fn]
  · exact ⟨by simpa using ha.wf.1.1, ha.wf.1.2⟩

theorem CaptureOk.close_sat {P B Ψ R Γ Φ cap a p}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hB : B.CoreAssumptions P)
    (ha : Ty.Annotation P [] Γ a) (hs : B.sat [] a.norm p) :
    B.sat [] (cap.closeTy a).norm p := by
  have hh := hB.values.sat_values Ψ Qempty [] Γ [] [] cap.env a.norm p
    (fun i b hi ho => by
      cases hc.substOk i b hi with
      | ordinary _ hv => exact hv
      | hidden hn _ => exact False.elim (hn ho)
      | contLoc he _ _ _ _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))
      | contVar he _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))) ha.norm hs
  simpa only [Capture.closeTy, substTyValues, Ty.bind, Ty.norm_rawBind, Ty.norm_idem, TypeCtx.constraints, List.map_nil] using hh

mutual
  theorem close_value_aux
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {v : Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVQ P B Ψ Q C Γ Φ v a) (hQ : Q = Qempty) (hC : C = []) :
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy a) := by
    match hv with
    | .V_Lam hn hwf hsort hb hdecl =>
      subst Q C
      exact close_lambda hB hw hc ⟨hwf,hsort,hdecl⟩ hb
    | .V_DependentLam ha hb =>
      subst Q C
      exact close_dependent_lambda hB hw hc ha hb
    | .V_List he hwf hsort hdecl =>
      have ih0 := close_each_aux hP hPB hB hw hs hd hc he hQ hC
      subst Q C
      have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
      exact .V_List (ih0) ht.wf ht.sorted ht.declared
    | .V_Map hk hv hn hsat ha hb =>
      have ih0 := close_each_aux hP hPB hB hw hs hd hc hk hQ hC
      have ih1 := close_each_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      exact .V_Map (ih0)
        (ih1)
        (by simpa using hn) (hc.close_sat hB ha hsat)
        (hc.substOk.annotation ha) (hc.substOk.annotation hb)
    | .V_Set hv hsat ha =>
      have ih0 := close_each_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      exact .V_Set (ih0)
        (hc.close_sat hB ha hsat) (hc.substOk.annotation ha)
    | .V_Con (cd := cd) (ts := ts) hcon hn hk hargs hv ha =>
      have ih0 := close_values_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      have hh := ih0
      have he : (cd.args.map (Ty.subst ts [])).map cap.closeTy =
          cd.args.map (Ty.subst (ts.map cap.closeTy) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.substV_subst_closed (hargs a ha) ts (valEnv cap.env).values)
      rw [he] at hh
      simp only [closeVal, Capture.closeTy, substTyValues, Ty.bind_data]
      exact .V_Con hcon (by simpa only [List.length_map] using hn) (hk.subst cap.env) hargs hh
        (by simpa only [substTyValues_eq_bind, Capture.closeTy, substTyValues, Ty.bind_data]
          using hc.substOk.annotation ha)
    | .V_Dict (id := id) (ts := ts) hi hsat hts hk hargs htarget hv ha =>
      have ih0 := close_values_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      have hv' := ih0
      have he : (id.dictTys.map (Ty.subst ts [])).map cap.closeTy =
          id.dictTys.map (Ty.subst (ts.map cap.closeTy) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.substV_subst_closed (hargs a ha) ts (valEnv cap.env).values)
      rw [he] at hv'
      have hsat' := hsat.map cap.closeTy (fun a hm p hp => hc.close_sat hB (hts a hm) hp)
      have ha' := hc.substOk.annotation ha
      simp only [Capture.closeTy, Ty.bind_dict, Ty.subst_values_closed htarget] at ha' ⊢
      exact .V_Dict hi hsat'
        (by intro a ha; obtain ⟨b,hb,rfl⟩ := List.mem_map.mp ha; exact hc.substOk.annotation (hts b hb))
        (hk.subst cap.env) hargs htarget hv' ha'
    | .V_Super hv hclass hmem hdecl =>
      have ih0 := close_value_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      exact .V_Super (ih0) hclass hmem
        (hdecl.bind_values hc.substOk.declaration)
    | .V_Sub hv hl hwf hsort hdecl =>
      have ih0 := close_value_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
      exact .V_Sub (ih0)
        (hl.bind (valEnv cap.env) hc.transport) ht.wf ht.sorted ht.declared
    | .V_Normal hv =>
      have ih0 := close_value_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      simpa only [Capture.closeTy, substTyValues_norm_source] using
        ih0
    | .V_Refine (a := a) (t := t) (p := p) hv hi ht hsort hwf he hda hdp =>
      have ih0 := close_value_aux hP hPB hB hw hs hd hc hv hQ hC
      subst Q C
      have tr := hc.transport
      have hsort' := Pred.sorted_bind hsort (valEnv cap.env).values
        (fun _ h => Ty.hasSort_bind h (valEnv cap.env))
        (fun h => Ty.ordinary_bind h (valEnv cap.env) tr.typeImages) tr.values tr.references
      rw [show cap.closeTy (.refined a p) =
        (Ty.refined (cap.closeTy a) (predBind (upValues (valEnv cap.env).values) p)).norm from by
          simp only [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Ty.norm_idem]]
      apply HasTypeVQ.V_Normal
      refine .V_Refine (t := termBind (valEnv cap.env).values t) (ih0)
        (Ty.hasSort_bind hi (valEnv cap.env)) ?_ hsort' (Pred.wf_of_sorted hsort') ?_
        (hda.bind_values hc.substOk.declaration) (hdp.bind_values hc.substOk.declaration)
      · rw [closeVal_observation]
        exact hc.substOk.observation hv hi ht LocalRef.bound
      · obtain ⟨u,hu,hus⟩ := hv.observation hi
        cases hu.symm.trans ht
        obtain ⟨u,hu,_⟩ := Term.hasSort_bind hus _ tr.values tr.references
        have hsuccess : termBind? (valEnv cap.env).values t = some (termBind (valEnv cap.env).values t) := by
          simp only [termBind, hu, Option.getD_some]
        rw [←predBind_open_of_some _ p t _ hsuccess]
        exact tr.entails he
    | hleaf@(.V_Var ..) | hleaf@(.V_Const ..) | hleaf@(.V_Closure ..) | hleaf@(.V_Fun ..) | hleaf@(.V_Prim ..) | hleaf@(.V_Op ..) |
      hleaf@(.V_ExternalRef ..) | hleaf@(.V_ExternalHandle ..) | hleaf@(.V_PathBases ..) | hleaf@(.V_ScopePattern ..) |
      hleaf@(.V_Checked ..) | hleaf@(.V_CheckedRequest ..) | hleaf@(.V_CheckedAt ..) | hleaf@(.V_AtError ..) |
      hleaf@(.V_Raise ..) | hleaf@(.V_LocRef ..) | hleaf@(.V_LocLazy ..) | hleaf@(.V_Bytes ..) =>
      subst Q C
      simpa only [closeVal, Val.subst, Capture.closeTy, Capture.closeEff] using
        hleaf.subst hB.substitutions hw hc.substOk
          (fun p hp => hc.conditions p (List.mem_append_right _ hp))
  termination_by structural hv
  theorem close_values_aux
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {as : List Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (hQ : Q = Qempty) (hC : C = []) :
      HasTypeVsQ P B Ψ Qempty [] [] [] (closeVals cap vs) (as.map cap.closeTy) := by
    match hv with
    | .nil =>
      subst Q C
      exact .nil
    | .cons hv hvs =>
      have ih0 := close_value_aux hP hPB hB hw hs hd hc hv hQ hC
      have ih1 := close_values_aux hP hPB hB hw hs hd hc hvs hQ hC
      subst Q C
      exact .cons (ih0)
          (ih1)
  termination_by structural hv
  theorem close_each_aux
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hQ : Q = Qempty) (hC : C = []) :
      HasTypeEachQ P B Ψ Qempty [] [] [] (closeVals cap vs) (cap.closeTy a) := by
    match hv with
    | .nil =>
      subst Q C
      exact .nil
    | .cons hv hvs =>
      have ih0 := close_value_aux hP hPB hB hw hs hd hc hv hQ hC
      have ih1 := close_each_aux hP hPB hB hw hs hd hc hvs hQ hC
      subst Q C
      exact .cons (ih0)
          (ih1)
  termination_by structural hv
end

  theorem close_value_typed
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Γ : Ctx} {Φ : List Pred} {cap : Capture} {v : Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy a) :=
    close_value_aux hP hPB hB hw hs hd hc hv rfl rfl

  theorem close_values_typed
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {as : List Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVsQ P B Ψ Qempty [] Γ Φ vs as) :
      HasTypeVsQ P B Ψ Qempty [] [] [] (closeVals cap vs) (as.map cap.closeTy) :=
    close_values_aux hP hPB hB hw hs hd hc hv rfl rfl

  theorem close_each_typed
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeEachQ P B Ψ Qempty [] Γ Φ vs a) :
      HasTypeEachQ P B Ψ Qempty [] [] [] (closeVals cap vs) (cap.closeTy a) :=
    close_each_aux hP hPB hB hw hs hd hc hv rfl rfl

end
end Benitoite.Release.Refinement
