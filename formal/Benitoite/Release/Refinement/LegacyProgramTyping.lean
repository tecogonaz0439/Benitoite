import Benitoite.Release.Refinement.LegacyStateTyping
import Benitoite.Release.Refinement.LegacyDeclarationInputs

/-! # 旧宣言本体から親の型付けへ（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem kind_toTel {P K ns ps r e}
    (h : (Ty.fn ns ps r e).HasKind P K .value) : kindsTel P K (Ty.toTel ns ps r e) := by
  induction ns generalizing ps r e with
  | nil => cases ps with
    | nil => exact h.2.2
    | cons a ps => have hn := h.1.1; simp at hn
  | cons n ns ih => cases ps with
    | nil => have hn := h.1.1; simp at hn
    | cons a ps =>
      have ht : (Ty.fn ns ps r e).HasKind P K .value :=
        ⟨⟨by simpa using h.1.1,h.1.2.tail⟩,h.2.1.2,h.2.2⟩
      exact ⟨h.2.1.1,ih ((Ty.hasKind_shiftV_iff _ _ 1 0).mpr ht)⟩

theorem embedDefWellTyped {K P0 B0 B f d}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (declarations : LegacyDeclarationsInput K P0 B0 B)
    (lookup : P0.defs f = some d) (body : functionBodyInput K P0 B0 B f d) :
    Def.WellTyped (embedProgramWithKinds K P0) B (embedDefWithKinds (K.functionParams f) d) := by
  have input := (declarations.1 f d lookup).1
  have ha := input.annotation_at rfl (wf.1 f d lookup) []
  have hk := kind_toTel input.1
  have hb := embedHasTypeCQ K (K.functionParams f) wf tables body []
  have hstore : embedStoreTy Benitoite.Release.StoreTy.empty = StoreTy.empty := by funext l; rfl
  rw [hstore] at hb
  have hn : NamesWF d.names (embedTys d.params) := ha.wf.1
  have ht : TelBodyTy (embedProgramWithKinds K P0) B StoreTy.empty (Benitoite.Release.Qsig d.params d.ret d.eff)
      (legacyTypeCtx d.tparams (K.functionParams f)) [] []
      (Ty.toTel d.names (embedTys d.params) (embedTy d.ret) (embedEff d.eff)) (embedComp d.body) := by
    apply (TelBodyTy.toTel_iff hn).mpr
    simpa only [bindParams,Benitoite.Release.binds,embedTys_eq_map,←List.map_reverse,
      List.map_map,List.map_append,List.map_nil,List.append_nil,List.length_map,liftMany_eq,
      Function.comp_def,Option.map_some,legacy_shiftV,legacy_shiftVEff,embedStoreTy,
      Benitoite.Release.StoreTy.empty,StoreTy.empty,Option.map_none] using hb
  have htel : (embedDefWithKinds (K.functionParams f) d).tel = Ty.toTel d.names (embedTys d.params) (embedTy d.ret) (embedEff d.eff) := by
    simp only [Def.tel,embedDefWithKinds,embedDef,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,legacy_signatureTel]
  refine ⟨by simpa only [embedDefWithKinds,embedDef,legacy_embedParameters] using hn,?_,?_,?_⟩
  · rw [htel]
    change kindsTel _ (TypeCtx.kinds (legacyTypeCtx d.tparams (K.functionParams f))) _
    rw [legacyTypeCtx_kinds (wf.1 f d lookup)]
    exact hk
  · rw [htel]
    exact ⟨ha.toTel.wf,ha.toTel.sorted,ha.toTel.declared⟩
  · rw [htel,←legacy_signatureTel,QTel_signatureTel _ _ _ _ hn,legacy_Qsig]
    simpa only [TelBodyTyR, ↓reduceIte, legacy_signatureTel,embedDefWithKinds,embedDef,legacyTypeCtx] using ht

private theorem legacy_substAt (a : Benitoite.Release.Ty) (c : Nat)
    (ts : List Benitoite.Release.Ty) (es : List Benitoite.Release.Eff) :
    embedTy (a.substAt c ts es) = (embedTy a).substAt c (embedTys ts) (es.map embedEff) := by
  simp only [Benitoite.Release.Ty.substAt_eq_bind,Benitoite.Release.Ty.bind,
    Ty.substAt,substTypeAt,Ty.bind,embedTy_norm]
  congr 1
  apply legacy_rawBind _ _ _ _ rfl
  · intro i
    simp only [Benitoite.Release.SubstEnv.at,typeEnvAt,embedTys_eq_map,List.length_map,List.getElem?_map]
    split
    · rfl
    · split
      · cases ts[i-c]? <;> simp only [Option.map_none,Option.map_some,Option.getD_none,Option.getD_some,legacy_rawShift,embedTy]
      · rfl
  · simp only [typeEnvAt,Benitoite.Release.SubstEnv.at,List.map_map,Function.comp_def,legacy_rawShiftEff]

private theorem legacy_substEffAt (e : Benitoite.Release.Eff) (c : Nat)
    (ts : List Benitoite.Release.Ty) (es : List Benitoite.Release.Eff) :
    embedEff (Benitoite.Release.Eff.substAt c ts es e) = Eff.substAt c (embedTys ts) (es.map embedEff) (embedEff e) := by
  simp only [Benitoite.Release.Eff.substAt,Benitoite.Release.Eff.rawSubstAt,
    Eff.substAt,substRowAt,Eff.bind,embedEff_norm]
  congr 1
  apply legacy_rawBindEff _ _ _ _ rfl
  · intro i
    simp only [Benitoite.Release.SubstEnv.at,typeEnvAt,embedTys_eq_map,List.length_map,List.getElem?_map]
    split
    · rfl
    · split
      · cases ts[i-c]? <;> simp only [Option.map_none,Option.map_some,Option.getD_none,Option.getD_some,legacy_rawShift,embedTy]
      · rfl
  · simp only [typeEnvAt,Benitoite.Release.SubstEnv.at,List.map_map,Function.comp_def,legacy_rawShiftEff]

private theorem legacy_method_tel (ks : KindCtx) (id : Benitoite.Release.ImplDecl) (ms : Benitoite.Release.MethSig) :
    Tel.bind (typeEnvAt ms.tparams.length [embedTy id.target] []) (embedMethSigWithKinds ks ms).tel =
      Ty.toTel ms.names (embedTys (ms.params.map (id.methTy ms))) (embedTy (id.methTy ms ms.ret))
        (embedEff (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff)) := by
  change Tel.bind _ (signatureTel ms.names (embedParameters ms.params)
    ((embedTy ms.ret).shiftV ms.params.length 0) ((embedEff ms.eff).shiftV ms.params.length 0)) = _
  simp only [legacy_embedParameters,legacy_shiftV,legacy_shiftVEff]
  rw [legacy_signatureTel,Tel.bind_toTel]
  simp only [Benitoite.Release.ImplDecl.methTy,legacy_substAt,legacy_substEffAt,
    embedTys_eq_map,List.map_map,Function.comp_def,Ty.substAt,substTypeAt,Eff.substAt,substRowAt,
    embedTys,List.map_nil]

private theorem legacy_public_shift (a : Benitoite.Release.Ty) (k c : Nat) :
    embedTy (a.shift k c) = (embedTy a).shift k c := by
  rw [Benitoite.Release.Ty.shift_eq_norm_rawShift,embedTy_norm,legacy_rawShift,
    Ty.shift,Ty.bind,Ty.rawBind_shiftTypes]


theorem embedImplWellTyped {K P0 B0 B i id}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (inputs : LegacyDeclarationInputs K P0 B0 B)
    (lookup : P0.impls i = some id) (old : Benitoite.Release.ImplDecl.WellTyped P0 B0 id) :
    ImplDecl.WellTyped (embedProgramWithKinds K P0) B (embedImplDecl id) := by
  obtain ⟨cd,hcd,hm,hs,hmethod,hsuper⟩ := old
  have hd := inputs.declarations.2.2.2 i id lookup
  have hfields : (embedImplDecl id).dictTys = embedTys id.dictTys := by
    simp only [ImplDecl.dictTys,Benitoite.Release.ImplDecl.dictTys,embedImplDecl,embedTys_eq_map,List.map_map,Function.comp_def,embedTy]
  refine ⟨embedClassDeclWithKinds K id.cls cd,embedProgramWithKinds_class hcd,?_,?_,?_,?_,?_,?_⟩
  · intro m; simpa [embedImplDecl,embedClassDeclWithKinds] using hm m
  · intro s
    have hh := hs s
    simp only [embedImplDecl,embedClassDeclWithKinds,Option.isSome_map]
    apply Bool.eq_iff_iff.mpr
    constructor
    · intro h
      exact decide_eq_true (of_decide_eq_true ((Bool.eq_iff_iff.mp hh).mp h))
    · intro h
      exact (Bool.eq_iff_iff.mp hh).mpr (decide_eq_true (of_decide_eq_true h))
  · simpa [embedImplDecl,TypeCtx.values,TypeCtx.kinds,embedClassDeclWithKinds,Function.comp_def,embedTParam,List.map_const'] using hd.1.1
  · rw [hfields]
    intro a ha
    obtain ⟨old,ho,rfl⟩ := List.mem_map.mp (by simpa only [embedTys_eq_map] using ha)
    simpa only [legacy_typeCtx_values,embedImplDecl] using (hd.2.1 old ho).annotation_at rfl (by simp) []
  · intro m ms hms
    obtain ⟨ms0,hms0,rfl⟩ := Option.map_eq_some_iff.mp hms
    obtain ⟨body,hbody,names,typed⟩ := hmethod m ms0 hms0
    refine ⟨embedComp body,by simp only [embedImplDecl,hbody,Option.map_some],?_,?_⟩
    · simpa only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,NamesWF,embedTys_eq_map,List.length_map]
        using (show ms0.names.length = ms0.params.length ∧ ms0.names.Nodup from names)
    · have hb := embedHasTypeCQ K _ wf tables (inputs.bodies.2.1 i id cd m ms0 body lookup hcd hms0 hbody) []
      have ht := hd.1
      have hdict := hd.2.1
      have hmscount := wf.2 id.cls cd m ms0 hcd hms0
      have hC : legacyTypeCtx (ms0.tparams ++ id.tparams)
          (K.methodParams id.cls m ++ List.replicate id.tparams.length .value) =
          (embedMethSigWithKinds (K.methodParams id.cls m) ms0).tparams ++ TypeCtx.values id.tparams := by
        rw [legacy_typeCtx_append _ _ _ _ hmscount,legacy_typeCtx_values]
        rfl
      have hn : NamesWF ms0.names (embedTys (ms0.params.map (id.methTy ms0))) :=
        ⟨by simpa only [embedTys_eq_map,List.length_map] using names.1,names.2⟩
      have hlen : (embedMethSigWithKinds (K.methodParams id.cls m) ms0).tparams.length = ms0.tparams.length :=
        legacyTypeCtx_length hmscount
      have hdictshift : ((embedImplDecl id).dictTys.map (Ty.shift ms0.tparams.length 0)) =
          embedTys (id.dictTys.map (Benitoite.Release.Ty.shift ms0.tparams.length 0)) := by
        rw [hfields]
        simp only [embedTys_eq_map,List.map_map,Function.comp_def,legacy_public_shift]
      have hnames : NamesWF (embedMethSigWithKinds (K.methodParams id.cls m) ms0).names
          (embedMethSigWithKinds (K.methodParams id.cls m) ms0).params := by
        simpa only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,NamesWF,embedTys_eq_map,List.length_map]
          using (show ms0.names.length = ms0.params.length ∧ ms0.names.Nodup from names)
      change TelBodyTy (embedProgramWithKinds K P0) B StoreTy.empty
        (QTel (embedMethSigWithKinds (K.methodParams id.cls m) ms0).tel)
        ((embedMethSigWithKinds (K.methodParams id.cls m) ms0).tparams ++ TypeCtx.values id.tparams)
        (bindParams [] ((embedImplDecl id).dictTys.map
          (Ty.shift (embedMethSigWithKinds (K.methodParams id.cls m) ms0).tparams.length 0))) []
        (Tel.shiftV (embedImplDecl id).dictTys.length 0
          (Tel.bind (typeEnvAt (embedMethSigWithKinds (K.methodParams id.cls m) ms0).tparams.length [embedTy id.target] [])
            (embedMethSigWithKinds (K.methodParams id.cls m) ms0).tel)) (embedComp body)
      rw [hlen,legacy_method_tel,MethSig.QTel_eq_Qsig _ hnames,hdictshift]
      simp only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,legacy_Qsig]
      simp only [Tel.shiftV_toTel,legacy_shiftVTys,legacy_shiftV,legacy_shiftVEff]
      apply (TelBodyTy.toTel_iff hn).mpr
      rw [hC] at hb
      have hstore : embedStoreTy Benitoite.Release.StoreTy.empty = StoreTy.empty := by funext l; rfl
      rw [hstore] at hb
      simpa only [bindParams,Benitoite.Release.binds,embedTys_eq_map,←List.map_reverse,List.reverse_append,
        List.map_map,List.map_append,List.map_nil,List.append_nil,List.length_map,liftMany_eq,
        Function.comp_def,Option.map_some,legacy_shiftV,legacy_shiftVEff,legacy_embedParameters,
        hfields,embedImplDecl,embedMethSigWithKinds,embedMethSig,legacy_Qsig,legacyTypeCtx] using hb

  · intro s hsupermem
    obtain ⟨value,hvalue,hval⟩ := hsuper s hsupermem
    refine ⟨embedVal value,by simp only [embedImplDecl,hvalue,Option.map_some],?_⟩
    have hv := embedHasTypeVQ K _ wf tables (inputs.bodies.2.2 i id cd s value lookup hcd hsupermem hvalue) []
    have hstore : embedStoreTy Benitoite.Release.StoreTy.empty = StoreTy.empty := by funext l; rfl
    rw [hstore] at hv
    rw [hfields]
    simpa only [legacy_typeCtx_values,bindParams,Benitoite.Release.binds,embedTys_eq_map,←List.map_reverse,
      List.map_map,List.map_nil,List.append_nil,Function.comp_def,Option.map_some,legacy_shiftV,embedImplDecl,embedTy] using hv

theorem embedProgramWellTyped {K P0 B0 B}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (inputs : LegacyDeclarationInputs K P0 B0 B) (old : Benitoite.Release.Program.WellTyped P0 B0) :
    Program.WellTyped (embedProgramWithKinds K P0) B := by
  refine ⟨tables.varianceValid,⟨by simp,by intro key decl hm; simp at hm⟩,?_,?_⟩
  · intro f d hd
    obtain ⟨oldD,ho,rfl⟩ := Option.map_eq_some_iff.mp hd
    exact embedDefWellTyped wf tables inputs.declarations ho (inputs.bodies.1 f oldD ho)
  · intro i id hid
    obtain ⟨oldI,ho,rfl⟩ := Option.map_eq_some_iff.mp hid
    exact embedImplWellTyped wf tables inputs ho (old.2 i oldI ho)

private theorem signature_rows (ns : List String) (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty)
    (e : Benitoite.Release.Eff) (pe : Nat → Prop)
    (h : (embedTy (.fn ns ps r e)).RowsIn pe) :
    (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)).RowsIn pe := by
  induction ns generalizing ps with
  | nil => exact h.2
  | cons n ns ih => cases ps with
    | nil => exact h.2
    | cons a ps =>
      simpa only [signatureTel,embedTys,legacy_shiftVTys,legacy_shiftV,legacy_shiftVEff] using
        (show Tel.RowsIn pe (.param n (embedTy a) (signatureTel ns (embedTys ps) (embedTy r) (embedEff e))) from
          ⟨h.1.1,ih ps ⟨h.1.2,h.2⟩⟩)

private theorem signature_ranges (ns : List String) (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty)
    (e : Benitoite.Release.Eff) (nr : Nat)
    (h : (embedTy (.fn ns ps r e)).RangesScoped nr) :
    (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)).RangesScoped nr := by
  induction ns generalizing ps with
  | nil => exact h.2
  | cons n ns ih => cases ps with
    | nil => exact h.2
    | cons a ps =>
      simpa only [signatureTel,embedTys,legacy_shiftVTys,legacy_shiftV,legacy_shiftVEff] using
        (show Tel.RangesScoped nr (.param n (embedTy a) (signatureTel ns (embedTys ps) (embedTy r) (embedEff e))) from
          ⟨h.1.1,ih ps ⟨h.1.2,h.2⟩⟩)

private theorem signature_scoped {K P0 κ C ns ps r e ne}
    (count : κ.length = C.length)
    (input : LegacyTypeInput K P0 ⟨κ,C,0,0⟩ (.fn ns ps r e) .value)
    (rows : (embedTy (.fn ns ps r e)).RowsIn (· < ne)) :
    SignatureScoped (embedProgramWithKinds K P0) (legacyTypeCtx C κ) ne
      (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)) := by
  have ann := input.annotation_at rfl count []
  have ha := legacy_signatureTel_annotation ns ps r e ann
  refine ⟨⟨ha.wf,signature_rows _ _ _ _ _ rows,signature_ranges _ _ _ _ _ input.2.2.2.2⟩,
    signature_rows _ _ _ _ _ rows,?_,ha⟩
  change kindsTel _ (TypeCtx.kinds (legacyTypeCtx C κ)) _
  rw [legacyTypeCtx_kinds count,legacy_signatureTel]
  exact kind_toTel input.1

theorem embedProgramWellFormed {K P0 B0 B}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (inputs : LegacyDeclarationInputs K P0 B0 B) (old : Benitoite.Release.Program.WellFormed P0) :
    Program.WellFormed (embedProgramWithKinds K P0) := by
  refine ⟨?_,?_,?_,?_,?_,?_,?_⟩
  · intro f d hd
    obtain ⟨d0,hd0,rfl⟩ := Option.map_eq_some_iff.mp hd
    have hi := (inputs.declarations.1 f d0 hd0).1
    have ho := old.1 f d0 hd0
    have hsig := signature_scoped (wf.1 f d0 hd0) hi (ne := d0.neffs)
      ⟨(legacy_rowsTys _ _).mpr (Benitoite.Release.Ty.VarsInList.rows _ ho.2.1),
        (legacy_rowsTy _ _).mpr (Benitoite.Release.Ty.VarsIn.rows _ ho.2.2.1),
        (legacy_rowsEff _ _).mpr (Benitoite.Release.Eff.VarsIn.rows _ ho.2.2.2.1)⟩
    refine ⟨?_,?_,?_⟩
    · simpa only [embedDefWithKinds,embedDef,legacy_embedParameters,NamesWF,embedTys_eq_map,List.length_map]
        using (show d0.names.length = d0.params.length ∧ d0.names.Nodup from ho.1)
    · simpa only [embedDefWithKinds,embedDef,Def.tel,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,legacyTypeCtx] using (show SignatureScopedR _ [] _ _ _ from ⟨hsig.1,hsig.2.1,hsig.2.2.1,⟨hsig.2.2.2.wf,hsig.2.2.2.sorted,hsig.2.2.2.declared⟩⟩)
    · have hcount : (embedTParamsWithKinds d0.tparams (K.functionParams f)).length = d0.tparams.length := legacyTypeCtx_length (wf.1 f d0 hd0)
      simpa only [embedDefWithKinds,embedDef,Def.ntys,legacy_embedParameters,embedTys_eq_map,List.length_map,
        hcount, List.length_nil] using inputs.functions f d0 hd0
  · intro c cd hc
    obtain ⟨cd0,hc0,rfl⟩ := Option.map_eq_some_iff.mp hc
    exact ⟨tables.dataArity hc0,tables.constructor_scoped hc0⟩
  · intro o od hod
    obtain ⟨od0,ho,rfl⟩ := Option.map_eq_some_iff.mp hod
    have hi := (inputs.declarations.2.1 o od0 ho).1
    have hdict := inputs.declarations.op_dictionaryInputs ho
    have hold := old.2.2.1 o od0 ho
    refine ⟨?_,hdict.1,hdict.2,?_⟩
    · simpa only [embedOpDecl,legacy_embedParameters,NamesWF,embedTys_eq_map,List.length_map]
        using (show od0.names.length = od0.params.length ∧ od0.names.Nodup from hold.1)
    · have hs := signature_scoped (by simp) hi (ne := 0)
        ⟨by simpa only [Nat.not_lt_zero] using (legacy_rowsTys _ (fun _ => False)).mpr (Benitoite.Release.Ty.VarsInList.rows _ hold.2.1),
          by simpa only [Nat.not_lt_zero] using (legacy_rowsTy _ (fun _ => False)).mpr (Benitoite.Release.Ty.VarsIn.rows _ hold.2.2),
          by simp [legacy_single,Eff.RowsIn,Eff.single,Ty.RowsInList]⟩
      rw [legacy_opTel]
      simpa only [embedOpDecl,legacy_typeCtx_values] using hs

  · intro cl cd hc m ms hm
    obtain ⟨cd0,hcd,rfl⟩ := Option.map_eq_some_iff.mp hc
    obtain ⟨ms0,hms,rfl⟩ := Option.map_eq_some_iff.mp hm
    have hi := inputs.declarations.2.2.1 cl cd0 m ms0 hcd hms
    have ho := old.2.2.2.1 cl cd0 hcd m ms0 hms
    have hsig := signature_scoped (by simp [wf.2 cl cd0 m ms0 hcd hms]) hi (ne := ms0.neffs)
      ⟨(legacy_rowsTys _ _).mpr (Benitoite.Release.Ty.VarsInList.rows _ ho.2.1),
        (legacy_rowsTy _ _).mpr (Benitoite.Release.Ty.VarsIn.rows _ ho.2.2.1),
        (legacy_rowsEff _ _).mpr (Benitoite.Release.Eff.VarsIn.rows _ ho.2.2.2)⟩
    refine ⟨?_,?_⟩
    · simpa only [embedMethSigWithKinds,embedMethSig,legacy_embedParameters,NamesWF,embedTys_eq_map,List.length_map]
        using (show ms0.names.length = ms0.params.length ∧ ms0.names.Nodup from ho.1)
    · rw [legacy_typeCtx_append _ _ _ _ (wf.2 cl cd0 m ms0 hcd hms)] at hsig
      simpa only [embedMethSigWithKinds,embedMethSig,MethSig.tel,legacy_embedParameters,legacy_shiftV,legacy_shiftVEff,
        legacy_typeCtx_append _ _ _ _ (wf.2 cl cd0 m ms0 hcd hms),legacyTypeCtx,embedTParamsWithKinds,
        List.zip_cons_cons,List.zip_nil_left,List.map_cons,List.map_nil,embedClassDeclWithKinds] using hsig
  · intro i id hid
    obtain ⟨id0,hi,rfl⟩ := Option.map_eq_some_iff.mp hid
    have hd := inputs.declarations.2.2.2 i id0 hi
    have ho := old.2.2.2.2 i id0 hi
    refine ⟨ho.1,?_,?_,?_,inputs.declarations.impl_dictionaryKinds hi,?_,?_⟩
    · refine ⟨?_,?_,hd.1.2.2.2.2⟩
      · simpa only [embedImplDecl,List.length_replicate] using hd.1.2.1
      · simpa only [embedImplDecl,Nat.not_lt_zero] using
          (legacy_rowsTy _ (fun _ => False)).mpr (Benitoite.Release.Ty.VarsIn.rows _ ho.2.1)
    · simpa only [legacy_typeCtx_values,embedImplDecl] using hd.1.annotation_at rfl (by simp) []
    · intro a ha
      obtain ⟨p,hp,rfl⟩ := List.mem_map.mp ha
      have h := hd.2.1 (.dict p.1 (.tvar p.2)) (List.mem_map.mpr ⟨p,hp,rfl⟩)
      simpa only [legacy_typeCtx_values,embedTy,embedImplDecl] using h.annotation_at rfl (by simp) []
    · intro s u hu
      obtain ⟨u0,hu0,rfl⟩ := Option.map_eq_some_iff.mp hu
      simpa only [embedImplDecl,ImplDecl.dictTys,Benitoite.Release.ImplDecl.dictTys,List.length_map] using inputs.supers i id0 s u0 hi hu0
    · intro cd m ms body hc hm hb
      obtain ⟨cd0,hc0,rfl⟩ := Option.map_eq_some_iff.mp hc
      obtain ⟨ms0,hm0,rfl⟩ := Option.map_eq_some_iff.mp hm
      obtain ⟨body0,hb0,rfl⟩ := Option.map_eq_some_iff.mp hb
      have hcount : (embedTParamsWithKinds ms0.tparams (K.methodParams id0.cls m)).length = ms0.tparams.length :=
        legacyTypeCtx_length (wf.2 id0.cls cd0 m ms0 hc0 hm0)
      simpa only [embedImplDecl,embedMethSigWithKinds,embedMethSig,legacy_embedParameters,embedTys_eq_map,List.length_map,
        ImplDecl.dictTys,Benitoite.Release.ImplDecl.dictTys,hcount] using inputs.methods i id0 cd0 m ms0 body0 hi hc0 hm0 hb0
  · intro d info hd; cases hd
  · exact ⟨by simp,by intro key decl hm; simp at hm⟩

end
end Benitoite.Release.Refinement
