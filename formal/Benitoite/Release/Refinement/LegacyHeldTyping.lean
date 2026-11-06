import Benitoite.Release.Refinement.LegacyAdequate
import Benitoite.Release.Refinement.TypedCoverage

/-! # 空捕捉で閉じた旧値の型付け（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

private def HeldTyped (K : DeclarationKinds) (P0 : Benitoite.Release.Program) (B : Builtins) : LegacyJudgment → Prop
  | .value κ Ψ Q C Γ v a => κ = [] → Q = Qempty → C = [] → Γ = [] →
      HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] [] (embedHeldVal v) (embedTy a)
  | .values κ Ψ Q C Γ vs ts => κ = [] → Q = Qempty → C = [] → Γ = [] →
      HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] []
        (closeVals Capture.empty (embedVals vs)) (embedTys ts)
  | .each κ Ψ Q C Γ vs a => κ = [] → Q = Qempty → C = [] → Γ = [] →
      HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] []
        (closeVals Capture.empty (embedVals vs)) (embedTy a)
  | _ => True

private theorem held_lambda {K P0 B0 B Ψ ns ps body r e}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.value [] Ψ Qempty [] [] (.lam ns ps body) (.fn ns ps r e)))
    (child : LegacyOutputInput K P0 B0 B (.comp [] Ψ.hideBuilders Qempty [] (Benitoite.Release.binds ps)
      (some r) body r e [])) :
    HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] []
      (embedHeldVal (.lam ns ps body)) (embedTy (.fn ns ps r e)) := by
  have ha : Ty.Annotation (embedProgramWithKinds K P0) [] [] (.fn ns (embedTys ps) (embedTy r) (embedEff e)) :=
    legacy_value_annotation reg
  have hc := CaptureOk.empty (embedProgramWithKinds K P0) B (hideBuilders (embedStoreTy Ψ)) none
  have hat := hc.substOk.telAnnotation ha.toTel
  have hb := embedHasTypeCQ K [] wf tables child []
  have hbody : HasTypeCQ (embedProgramWithKinds K P0) B (hideBuilders (embedStoreTy Ψ)) Qempty []
      (bindParams [] (embedTys ps)) (liftMany (embedTys ps).length [])
      (some ((embedTy r).shiftV (embedTys ps).length 0)) (embedComp body)
      ((embedTy r).shiftV (embedTys ps).length 0) ((embedEff e).shiftV (embedTys ps).length 0) [] := by
    simpa only [bindParams,Benitoite.Release.binds,embedTys_eq_map,←List.map_reverse,
      List.map_map,List.map_append,List.map_nil,List.append_nil,List.length_map,liftMany_eq,List.map_nil,
      Function.comp_def,Option.map_some,legacy_hideBuilders,
      legacy_shiftV,legacy_shiftVEff,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left] using hb
  have hh : DependentClosureTy (embedProgramWithKinds K P0) B (embedStoreTy Ψ)
      (.mk Capture.empty (embedComp body)) (Capture.empty.closeTel (Ty.toTel ns (embedTys ps) (embedTy r) (embedEff e))) :=
    .mk hc ((TelBodyTy.toTel_iff ha.wf.1).mpr hbody) ha.toTel hat
  have hrt : Ty.Annotation (embedProgramWithKinds K P0) [] []
      (.fn ns (embedTys ps) (.base .unit) Eff.empty) :=
    ⟨⟨ha.wf.1,ha.wf.2.1,trivial,trivial,rfl⟩,⟨ha.sorted.1,trivial,trivial⟩,⟨ha.declared.1,trivial,trivial⟩⟩
  have hrt' := hc.substOk.telAnnotation hrt.toTel
  have hv := HasTypeVQ.V_Closure (Ψ := embedStoreTy Ψ) (Q := Qempty) (Φ := []) hat
    (Tel.RuntimeShape.mk hrt'.wf hat.wf ((Tel.SameInputs.toTel ns (embedTys ps) _ _ _ _).bind _)) hh
  apply hv.convert _ ha
  rw [Tel.bind_toTel,Ty.norm_toTel]
  · rw [←Ty.bind_fn]
    change (Capture.empty.closeTy (embedTy (.fn ns ps r e))).norm = (embedTy (.fn ns ps r e)).norm
    change (substTyValues Capture.empty.env (embedTy (.fn ns ps r e))).norm = _
    rw [substTyValues_embed,embedTy_norm,Ty.norm_idem]
  · exact ⟨by simpa using ha.wf.1.1,ha.wf.1.2⟩

private theorem close_type {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k) :
    Capture.empty.closeTy (embedTy a) = embedTy a := by
  rw [Capture.closeTy,substTyValues_embed,embedTy_norm,legacy_normal h.2.1]

private theorem close_types {K P0 Δ ts ks} (h : LegacyTypesInput K P0 Δ ts ks) :
    (embedTys ts).map Capture.empty.closeTy = embedTys ts := by
  rw [embedTys_eq_map,List.map_map]
  apply List.map_congr_left
  intro a ha
  have count := h.1
  obtain ⟨i,hi⟩ := List.mem_iff_getElem?.mp ha
  obtain ⟨k,hk⟩ : ∃ k, ks[i]? = some k := by
    obtain ⟨bound,_⟩ := List.getElem?_eq_some_iff.mp hi
    exact ⟨ks[i]'(by omega),List.getElem?_eq_getElem (by omega)⟩
  exact close_type (h.2 i a k hi hk).1

private theorem close_rows {K P0 Δ es} (h : LegacyRowsInput K P0 Δ es) :
    (es.map embedEff).map Capture.empty.closeEff = es.map embedEff := by
  rw [List.map_map]
  apply List.map_congr_left
  intro e he
  have ha := h e he
  have hw := (embedEff_wf_values e Δ.nr Δ.kinds.length Δ.nv 0).mp ha.2.1.2.2.2.1
  exact Eff.subst_values_of_wf_zero hw ha.2.1.2.2.2.2 _

private theorem held_induct {K P0 B0 B j} (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyOutputInput K P0 B0 B j) : HeldTyped K P0 B j := by
  apply input.induct_regular
  intro j children rule reg kids ih
  have parent := LegacyOutputInput.node rule reg kids
  cases rule <;> try trivial
  all_goals intro hκ hQ hC hΓ; subst_vars
  case V_Var => simp_all
  case V_Const => simpa only [embedHeldVal,embedVal,closeVal,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using embedHasTypeVQ K [] wf tables parent []
  case V_Bytes => simpa only [embedHeldVal,embedVal,closeVal,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using embedHasTypeVQ K [] wf tables parent []
  case V_LocRef => simpa only [embedHeldVal,embedVal,closeVal,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using embedHasTypeVQ K [] wf tables parent []
  case V_LocLazy => simpa only [embedHeldVal,embedVal,closeVal,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using embedHasTypeVQ K [] wf tables parent []
  case V_Checked => simpa only [embedHeldVal,embedVal,closeVal,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using embedHasTypeVQ K [] wf tables parent []
  case V_CheckedRequest => simpa only [embedHeldVal,embedVal,closeVal,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using embedHasTypeVQ K [] wf tables parent []
  case V_Fun =>
    obtain ⟨fd,hfd,ha,args,rows⟩ := reg.2.1
    simpa only [embedHeldVal,embedVal,closeVal_fnRef,close_types args,close_rows rows,
      legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil]
      using embedHasTypeVQ K [] wf tables parent []
  case V_Prim =>
    obtain ⟨s0,s,hs0,hs,count,ha,args,rows,ranges⟩ := reg.2.1
    simpa only [embedHeldVal,embedVal,closeVal,close_types args,close_rows rows,
      legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil]
      using embedHasTypeVQ K [] wf tables parent []
  case V_Op =>
    obtain ⟨od,hod,ha,args⟩ := reg.2.1
    simpa only [embedHeldVal,embedVal,closeVal,close_types args,
      legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil]
      using embedHasTypeVQ K [] wf tables parent []
  case V_Raise =>
    simpa only [embedHeldVal,embedVal,closeVal,close_type reg.2.1.1.1,close_type reg.2.1.2.1,
      legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil]
      using embedHasTypeVQ K [] wf tables parent []
  case V_Lam => exact held_lambda wf tables reg (by
    have hk := kids _ List.mem_cons_self
    simpa [Benitoite.Release.hideConts] using hk)
  case V_Sub sub hw =>
    have ha := legacy_value_annotation reg
    exact .V_Sub (ih _ (List.mem_cons_self) rfl rfl rfl rfl) (embedLe sub) ha.wf ha.sorted ha.declared
  case V_List =>
    have ha := legacy_value_annotation reg
    exact .V_List (ih _ (List.mem_cons_self) rfl rfl rfl rfl) ha.wf ha.sorted ha.declared
  case V_Map count key _ _ =>
    have ha := legacy_value_annotation reg
    exact .V_Map (ih _ (List.mem_cons_self) rfl rfl rfl rfl) (ih _ (List.mem_cons_of_mem _ List.mem_cons_self) rfl rfl rfl rfl)
      (by simpa only [closeVals_length,embedVals_length] using count) (tables.sat _ _ _ key)
      ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩ ⟨ha.wf.2,ha.sorted.2,ha.declared.2⟩
  case V_Set key _ =>
    have ha := legacy_value_annotation reg
    exact .V_Set (ih _ (List.mem_cons_self) rfl rfl rfl rfl) (tables.sat _ _ _ key) ⟨ha.wf,ha.sorted,ha.declared⟩
  case V_Super lookup member =>
    exact .V_Super (ih _ (List.mem_cons_self) rfl rfl rfl rfl) (embedProgramWithKinds_class lookup) member
      (legacy_value_annotation reg).declared
  case V_Con c ts vs cd lookup arity =>
    obtain ⟨⟨cd',hc,args⟩,_⟩ := reg.2.1
    have hc' : cd' = cd := Option.some.inj (hc.symm.trans lookup)
    subst cd'
    have ha := legacy_value_annotation reg
    simp only [embedHeldVal,embedVal,closeVal,close_types args]
    apply HasTypeVQ.V_Con (cd := embedConDecl cd)
      (by simp only [embedProgramWithKinds_cons,lookup,Option.map_some])
      (by simpa only [embedTys_eq_map,List.length_map,embedConDecl] using arity)
      (args.kindArgs.kinded (legacyTypeCtx_kinds reg.1.2.2.1)) _ _ ha
    · intro a ha
      obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [embedConDecl,embedTys_eq_map] using ha)
      simpa only [embedConDecl,List.length_replicate,List.length_nil] using (tables.constructorFields c cd lookup old ho).1.wf
    · simpa only [embedConDecl,embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using
        ih _ (List.mem_cons_self) rfl rfl rfl rfl
  case V_Dict i ts vs id lookup sat =>
    obtain ⟨⟨id',hid,target,fields,args⟩,_⟩ := reg.2.1
    have hid' : id' = id := Option.some.inj (hid.symm.trans lookup)
    subst id'
    have ha := legacy_value_annotation reg
    have hfields : (embedImplDecl id).dictTys = embedTys id.dictTys := by
      simp only [ImplDecl.dictTys,Benitoite.Release.ImplDecl.dictTys,embedImplDecl,embedTys_eq_map,
        List.map_map,Function.comp_def,embedTy]
    simp only [embedHeldVal,embedVal,closeVal,close_types args]
    have hv := HasTypeVQ.V_Dict (Ψ := embedStoreTy _) (Q := Qempty) (Φ := [])
      (show (embedProgramWithKinds K P0).impls i = some (embedImplDecl id) from by
        simp only [embedProgramWithKinds_impls,lookup,Option.map_some])
      (legacy_SatAll tables reg.1.2.2.1 sat) (args.annotations rfl reg.1.2.2.1 _)
      (args.kindArgs.kinded (legacyTypeCtx_kinds reg.1.2.2.1))
      (by intro a hm
          obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [hfields,embedTys_eq_map] using hm)
          simpa only [embedImplDecl,List.length_replicate] using (fields old ho).2.1)
      (by simpa only [embedImplDecl,List.length_replicate] using target.2.1)
      (by simpa only [hfields,embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using
        ih _ (List.mem_cons_self) rfl rfl rfl rfl)
      (by simpa only [embedTy,legacy_subst,embedImplDecl,List.map_nil] using ha)
    simpa only [embedTy,embedImplDecl,legacy_subst,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using hv
  case Vs_nil => exact .nil
  case Vs_cons => exact .cons (ih _ (List.mem_cons_self) rfl rfl rfl rfl) (ih _ (List.mem_cons_of_mem _ List.mem_cons_self) rfl rfl rfl rfl)
  case Each_nil => exact .nil
  case Each_cons => exact .cons (ih _ (List.mem_cons_self) rfl rfl rfl rfl) (ih _ (List.mem_cons_of_mem _ List.mem_cons_self) rfl rfl rfl rfl)

theorem embedHeldVal_typed {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {Ψ : Benitoite.Release.StoreTy}
    {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyOutputInput K P0 B0 B (.value [] Ψ Qempty [] [] v a)) :
    HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] [] (embedHeldVal v) (embedTy a) :=
  held_induct wf tables input rfl rfl rfl rfl

end
end Benitoite.Release.Refinement
