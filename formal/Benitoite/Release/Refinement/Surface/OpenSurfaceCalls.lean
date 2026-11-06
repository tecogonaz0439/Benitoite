import Benitoite.Release.Refinement.Surface.OpenRangeExchange
import Benitoite.Release.Refinement.Surface.OpenSignatureExchange
import Benitoite.Release.Refinement.Surface.OpenSurfaceFormation
import Benitoite.Release.Refinement.Surface.Property1Calls
import Benitoite.Release.Refinement.Surface.OpenSurfaceSequence
import Benitoite.Release.Refinement.Surface.OpenSurfaceValues

/-! # 開いた呼出しの頭の具体化

元の範囲引数を、呼出し元の一つの具体化で閉じる。署名の範囲の上限を使って依存列の添字をそろえる。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem ranges_close {ks xs kinds rs} (hx : RangeArguments ks xs kinds) (hr : RangesFit rs ks) :
    xs.map (fun ix => ix.inst rs) = (xs.map (closeRange rs)).map RangeIx.fixed := by
  induction xs generalizing kinds with
  | nil => rfl
  | cons x xs ih =>
    cases kinds with
    | nil => have hh := hx.1; simp at hh
    | cons k kinds =>
      have hh := hx.2 0 x k (by rfl) (by rfl)
      have ht : RangeArguments ks xs kinds := ⟨by simpa using hx.1,
        fun i ix k hi hk => hx.2 (i+1) ix k hi hk⟩
      simp only [List.map_cons]
      rw [RangeArgument.close hh hr, ih ht]

theorem ranges_fit_close {ks xs kinds rs} (hx : RangeArguments ks xs kinds) (hr : RangesFit rs ks) :
    RangesFit (xs.map (closeRange rs)) kinds := by
  refine ⟨by simpa using hx.1, ?_, ?_⟩
  · intro i r k hi hk
    rw [List.getElem?_map] at hi
    cases hix : xs[i]? with
    | none => simp [hix] at hi
    | some ix =>
      simp only [hix, Option.map_some, Option.some.injEq] at hi
      subst r
      have ha := hx.2 i ix k hix hk
      cases ix with
      | fixed r => exact ha.2.2
      | rvar j =>
        have hj : j < rs.length := hr.1 ▸ (List.getElem?_eq_some_iff.mp ha).1
        simpa only [closeRange, RangeIx.inst, List.getElem?_eq_getElem hj] using
          hr.2.1 j rs[j] k (List.getElem?_eq_getElem hj) ha
  · intro r hm
    obtain ⟨ix, hix, rfl⟩ := List.mem_map.mp hm
    obtain ⟨i, hi, he⟩ := List.getElem_of_mem hix
    have hk : i < kinds.length := hx.1 ▸ hi
    have ha := hx.2 i ix kinds[i] (by simpa [he] using List.getElem?_eq_getElem hi)
      (List.getElem?_eq_getElem hk)
    cases ix with
    | fixed r => exact ⟨ha.1, ha.2.1⟩
    | rvar j =>
      have hj : j < rs.length := hr.1 ▸ (List.getElem?_eq_some_iff.mp ha).1
      simpa only [closeRange, RangeIx.inst, List.getElem?_eq_getElem hj] using
        hr.2.2 rs[j] (List.getElem_mem hj)

theorem rangeTel_norm (rs : List RangeExpr) (t : Tel) : Tel.norm (rangeTel rs t) = Tel.instR rs t := by
  cases rs with
  | nil => simp [rangeTel, Tel.instR, Tel.substRAt, Tel.mapRanges]
  | cons r rs => exact Tel.norm_idem _

theorem rangeTel_normal_source (rs : List RangeExpr) (t : Tel) :
    rangeTel rs (Tel.norm t) = Tel.norm (rangeTel rs t) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    exact (Tel.norm_rawMapRanges t (rangeAt 0 (r :: rs))).trans (Tel.norm_idem _).symm

theorem instantiatedTel_norm_source (t : Tel) (ts : List Ty) (es : List Eff) :
    instantiatedTel (Tel.norm t) ts es = instantiatedTel t ts es := by
  exact Tel.norm_rawBind _ _

theorem signature_norm_source {P C Γ t kinds ts es} (h : SignatureInstance P C Γ t kinds ts es) :
    SignatureInstance P C Γ (Tel.norm t) kinds ts es := by
  refine ⟨Tel.wf_norm h.source, h.types, h.kinds, h.rows, h.rowKinds, ?_⟩
  simpa only [instantiatedTel_norm_source] using h.result

theorem signature_source_convert {P C Γ t u kinds ts es}
    (h : SignatureInstance P C Γ t kinds ts es) (hw : u.WF 0 kinds.length 0)
    (he : Tel.norm u = Tel.norm t) : SignatureInstance P C Γ u kinds ts es := by
  refine ⟨hw, h.types, h.kinds, h.rows, h.rowKinds, ?_⟩
  have he' : instantiatedTel u ts es = instantiatedTel t ts es := by
    rw [← instantiatedTel_norm_source u, he, instantiatedTel_norm_source]
  rw [he']
  exact h.result

theorem closedHeadTel {ks xs kinds rs t} (hx : RangeArguments ks xs kinds) (hr : RangesFit rs ks)
    (ht : t.RangesScoped kinds.length) :
    Tel.norm (rangeTel rs (openRangeTel xs t)) = Tel.instR (xs.map (closeRange rs)) t := by
  rw [rangeTel_norm]
  exact openRangeTel_instR hx hr ht

theorem closedTel_norm {ks t} (h : t.RangesScoped 0) (σ : Instance ks) :
    Tel.norm (rangeTel σ.val t) = Tel.norm t := by
  have hx : RangeArguments ks [] [] := ⟨rfl, by intro i ix k hi; cases hi⟩
  simpa only [openRangeTel, List.map_nil, Tel.instR, Tel.substRAt, Tel.mapRanges, rangeAt_nil,
    Tel.rawMapRanges_id] using closedHeadTel hx σ.property h

theorem prim_core {P B ks Q C Γ Φ b s ts es xs} {D : Declarations}
    (hb : B.sig b = some s) (hw : s.Scoped D.core) (hx : RangeArguments ks xs s.rkinds)
    (hr : RangesAdmit B ks b s xs) (hn : NamesWF s.names s.params)
    (ha : Primitive ks C Γ.length s Q ts es)
    (hs : Signature D.core ks C Γ (openRangeTel xs s.tel) (TypeCtx.kinds s.tparams) ts es)
    (hR : D.Realizes P) (σ : Instance ks) :
    HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ
      ((Val.prim b ts es xs).instR σ.val)
      (.dependentFn (rangeTel σ.val (instantiatedTel (openRangeTel xs s.tel) ts es))) := by
  have hsig := signature_norm_source ((hs σ).sameTypes hR.types)
  rw [closedHeadTel hx σ.property hw.source.2.2] at hsig
  have hv := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Q := Q) (Φ := Φ) hb (hr σ) hn
    (by simpa only [rangeCtx_length] using ha σ) hsig
  have ht : instantiatedTel (Tel.instR (xs.map (closeRange σ.val)) s.tel)
      (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val)) =
      rangeTel σ.val (instantiatedTel (openRangeTel xs s.tel) ts es) := by
    rw [OpenSignatureExchange.rangeTel_instantiated, ← closedHeadTel hx σ.property hw.source.2.2,
      instantiatedTel_norm_source]
  rw [ht] at hv
  have he : (Val.prim b ts es xs).instR σ.val =
      .prim b (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val))
        ((xs.map (closeRange σ.val)).map RangeIx.fixed) := by
    have hc := ranges_close hx σ.property
    cases hσ : σ.val with
    | nil =>
      have hc' : xs = (xs.map (closeRange [])).map RangeIx.fixed := by
        simpa [hσ] using hc
      simp only [Val.instR_nil]
      change Val.prim b ts es xs = Val.prim b (ts.map id) (es.map id) _
      rw [List.map_id, List.map_id]
      exact congrArg (Val.prim b ts es) hc'
    | cons r rs =>
      simpa [hσ, Val.instR, Val.substR, Val.mapRangesN, rangeTy, rangeEff, Ty.instR,
        Ty.substRAt, Eff.instR, Eff.substRAt, mapIx_rangeAt] using
        congrArg (Val.prim b (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val))) hc
  rw [he]
  exact hv

theorem op_core {P B ks Q C Γ Φ o od ts} {D : Declarations}
    (ho : D.ops o = some od) (hn : NamesWF od.names od.params)
    (hsc : od.tel.RangesScoped 0) (hw : od.tel.WF 0 od.tparams.length 0)
    (ha : Satisfies B ks C ts od.tparams)
    (hs : Signature D.core ks C Γ od.tel (List.replicate od.tparams.length .value) ts [])
    (hR : D.Realizes P) (σ : Instance ks) :
    HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ
      ((Val.op o ts).instR σ.val)
      (.dependentFn (rangeTel σ.val (instantiatedTel od.tel ts []))) := by
  have hsig := signature_source_convert ((hs σ).sameTypes hR.types)
    (by simpa only [List.length_replicate] using hw) (closedTel_norm hsc σ).symm
  have hv := HasTypeVQ.V_Op (Ψ := StoreTy.empty) (Q := Q) (Φ := Φ) (Γ := rangeCtx σ.val Γ)
    (hR.ops ▸ ho) hn (ha σ) (by simpa only [List.map_nil] using hsig)
  have ht : instantiatedTel od.tel (ts.map (rangeTy σ.val)) [] =
      rangeTel σ.val (instantiatedTel od.tel ts []) := by
    rw [OpenSignatureExchange.rangeTel_instantiated, List.map_nil,
      ← instantiatedTel_norm_source (rangeTel σ.val od.tel), closedTel_norm hsc σ,
      instantiatedTel_norm_source]
  rw [ht] at hv
  have he : (Val.op o ts).instR σ.val = .op o (ts.map (rangeTy σ.val)) := by
    cases rs : σ.val with
    | nil => change Val.op o ts = .op o (ts.map id); rw [List.map_id]
    | cons r rs => rfl
  rw [he]
  exact hv

theorem fn_core {P B ks Q C Γ Φ f fd ts es xs} {D : Declarations}
    (hf : D.funs f = some fd) (hn : NamesWF fd.coreNames fd.coreParams)
    (hx : RangeArguments ks xs fd.rangeParams) (hsc : fd.tel.RangesScoped fd.rangeParams.length)
    (hw : fd.tel.WF fd.rangeParams.length fd.tparams.length 0)
    (ha : Admits B ks C Γ.length (TypeCtx.constraints fd.tparams) fd.neffs
      (Qsig fd.coreParams fd.ret fd.eff) Q ts es fd.eff)
    (hs : Signature D.core ks C Γ (openRangeTel xs fd.tel) (TypeCtx.kinds fd.tparams) ts es)
    (hR : D.Realizes P) (σ : Instance ks) :
    HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ
      ((Val.fnRef f ts es xs).instR σ.val)
      (.dependentFn (rangeTel σ.val (instantiatedTel (openRangeTel xs fd.tel) ts es))) := by
  obtain ⟨d, hd, htp, hne, hnm, hpa, hre, hef⟩ := hR.funs _ _ hf
  have htel := FunDecl.tel_eq hnm hpa hre hef
  have hfit := ranges_fit_close hx σ.property
  have hactual : Tel.norm (d.instTel (xs.map (closeRange σ.val))) =
      Tel.instR (xs.map (closeRange σ.val)) fd.tel := by
    simp only [Refinement.Def.instTel, htel]
    exact rangeTel_norm _ _
  have hactualWF : (d.instTel (xs.map (closeRange σ.val))).WF 0 (TypeCtx.kinds d.tparams).length 0 := by
    rw [htp]
    simp only [TypeCtx.kinds, List.length_map]
    cases xs with
    | nil =>
      have hk : fd.rangeParams.length = 0 := hx.1.symm
      simpa only [List.map_nil, Refinement.Def.instTel, htel, hk] using hw
    | cons x xs =>
      simp only [List.map_cons, Refinement.Def.instTel, htel, Tel.instR_eq_bind]
      exact Tel.rawBind_norm_wf _ hw (SubstEnv.rangesOnly_wfImages hfit.1)
  have hsig := signature_source_convert ((hs σ).sameTypes hR.types) (by simpa [htp] using hactualWF)
    (hactual.trans (closedHeadTel hx σ.property hsc).symm)
  have hv := HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Q := Q) (Φ := Φ) (Γ := rangeCtx σ.val Γ) hd
    (by rw [hnm, hpa]; exact hn)
    (by change RangesFit _ d.rkinds; rw [hR.ranges _ _ hf _ hd]; exact hfit)
    (by rw [htp, hne, hpa, hre, hef]; simpa only [rangeCtx_length] using ha σ)
    (by simpa only [htp] using hsig)
  have ht : instantiatedTel (d.instTel (xs.map (closeRange σ.val)))
      (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val)) =
      rangeTel σ.val (instantiatedTel (openRangeTel xs fd.tel) ts es) := by
    rw [← instantiatedTel_norm_source, hactual, ← closedHeadTel hx σ.property hsc,
      instantiatedTel_norm_source, OpenSignatureExchange.rangeTel_instantiated]
  rw [ht] at hv
  have he : (Val.fnRef f ts es xs).instR σ.val =
      .fnRef f (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val))
        ((xs.map (closeRange σ.val)).map RangeIx.fixed) := by
    have hc := ranges_close hx σ.property
    cases hσ : σ.val with
    | nil =>
      have hc' : xs = (xs.map (closeRange [])).map RangeIx.fixed := by simpa [hσ] using hc
      simp only [Val.instR_nil]
      change Val.fnRef f ts es xs = Val.fnRef f (ts.map id) (es.map id) _
      rw [List.map_id, List.map_id]
      exact congrArg (fun xs => Val.fnRef f ts es xs) hc'
    | cons r rs =>
      simpa [hσ, Val.instR, Val.substR, Val.mapRangesN, rangeTy, rangeEff, Ty.instR,
        Ty.substRAt, Eff.instR, Eff.substRAt, mapIx_rangeAt] using
        congrArg (fun xs => Val.fnRef f (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val)) xs) hc
  rw [he]
  exact hv

theorem CallHeadTy.app_value {P B ks Q C Γ Φ f t ds v dl} {D : Declarations}
    (h : CallHeadTy D B ks Q C Γ f t ds) (hd : directCallee f = some (.app v dl))
    (hR : D.Realizes P) (σ : Instance ks) :
    HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (v.instR σ.val)
      (.dependentFn (rangeTel σ.val t)) ∧ dl = DictEv.toValList ds := by
  cases h with
  | fn hf _ hn hx hsc hw ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨fn_core hf hn hx hsc hw ha hs hR σ, rfl⟩
  | fnDicts hf _ hn hx hsc hw ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨fn_core hf hn hx hsc hw ha hs hR σ, rfl⟩
  | prim hb hw hx hr hn ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨prim_core hb hw hx hr hn ha hs hR σ, rfl⟩
  | op ho _ hn hsc hw ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨op_core ho hn hsc hw ha hs hR σ, rfl⟩
  | opDicts ho _ hn hsc hw ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨op_core ho hn hsc hw ha hs hR σ, rfl⟩
  | meth => simp [directCallee] at hd
  | external => simp [directCallee] at hd

theorem dependentFn_range_type {P B Ψ Q C Γ Φ v t rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v (.dependentFn (rangeTel rs t))) :
    HasTypeVQ P B Ψ Q C Γ Φ v (rangeTy rs (.dependentFn t)) := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    simpa only [rangeTy, rangeTel, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
      Ty.norm, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.norm_idem] using h.V_Normal

theorem dependentFn_range_norm (rs : List RangeExpr) (t : Tel) :
    (rangeTy rs (.dependentFn t)).norm = (Ty.dependentFn (rangeTel rs t)).norm := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeTy, rangeTel, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
      Ty.norm, Ty.norm_foldFn, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.norm_idem]

theorem head_expr_core {P B ks op Q Δ C Γ Φ R p e t v} {D : Declarations}
    (hh : CallHeadTy D B ks Q C Γ e t []) (hd : directCallee e = some (.app v []))
    (he : desugarExpr op p e = .ret v) (hR : D.Realizes P) (σ : Instance ks) :
    ExprCore P B op Q Δ C Γ Φ R p e (.dependentFn t) Eff.empty σ.val := by
  have hv := dependentFn_range_type (hh.app_value (Φ := Φ) hd hR σ).1
  have ht := HasTypeCQ.C_Return (R := R.map (rangeTy σ.val)) (Δ := rangeLocal σ.val Δ) hv
  change HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
    ((desugarExpr op p e).instR σ.val) (rangeTy σ.val (.dependentFn t)) (rangeEff σ.val Eff.empty) _
  rw [he, rangeEff_empty, comp_ret_instR]
  exact ht

theorem app_head_glue_core {P B ks Q C Γ Γ0 k0 Γ' Φ' L k f t ds v dl ws r e b ε}
    {D : Declarations} {R : Option Ty}
    (hh : CallHeadTy D B ks Q C Γ f t ds) (hd : directCallee f = some (.app v dl))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
    (hm : ShiftMap k 0 Γ Γ') (hm0 : ShiftMap k0 0 Γ0 Γ')
    (hv : ValsTel D B ks C Γ0 k0 Γ' Φ'
      (ds.map (fun d => d.toVal.rename (· + k)) ++ ws) (Tel.shiftV k 0 t) r e)
    (hle : Ty.LeQ D.core Γ' Φ' r b) (hc : Eff.Covers Γ' Φ' ε e)
    (hb : Ty.AnnotationR D.core ks C Γ' b) (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((((CallHead.app v dl).rename (· + k)).apply ws).instR σ.val)
      (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val L) := by
  have hb' := annotation (B := B) (annotation_sameTypes hb hR.types) σ
  have hargs := hv.core (Q := Q) hR hA hm0 σ
  rw [rangeTel_shiftV] at hargs
  obtain ⟨hv0, hdl⟩ := hh.app_value (Φ := []) hd hR σ
  have hcall := Surface.app_glue (R := R.map (rangeTy σ.val)) (L := rangeLocal σ.val L)
    hA storeEmpty_wf hv0 (rangeCtx_shiftMap hm σ.val) hargs
  have hres := HasTypeCQ.C_Sub hcall ((OpenBody.Le.source (hle.sameTypes hR.types)).at σ)
    ((OpenBody.Covers.source hc).at σ) hb'.wf hb'.sorted hb'.declared
  simp only [CallHead.rename, CallHead.apply, comp_app_instR, ← shiftIndex_add,
    OpenRangeRename.val_instR_shift]
  rw [hdl]
  simpa only [DictEv.toValList_map, Val.renameList_map, List.map_map, Function.comp_def,
    shiftIndex_add] using hres

theorem meth_head_glue_core {P B ks Q C Γ Γ0 k0 Γ' Φ' L k d cl τ cd m ms ss es us ws r e b ε}
    {D : Declarations} {R : Option Ty}
    (hd : DictEv.HasType D B ks C Γ d (.dict cl τ)) (hcl : D.classes cl = some cd)
    (hms : cd.methods m = some ms) (hn : NamesWF ms.names ms.params)
    (hsat : Satisfies B ks C ss (TypeCtx.constraints ms.tparams))
    (hsc : ms.tel.RangesScoped 0) (hw : ms.tel.WF 0 (ms.tparams.length + 1) 0)
    (hsi : Signature D.core ks C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es)
    (hrows : MethodRows ks C Γ.length Q ms es)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
    (hm : ShiftMap k 0 Γ Γ') (hm0 : ShiftMap k0 0 Γ0 Γ')
    (hv : ValsTel D B ks C Γ0 k0 Γ' Φ'
      (us.map (fun d => d.toVal.rename (· + k)) ++ ws)
      (Tel.shiftV k 0 (instantiatedTel ms.tel (ss ++ [τ]) es)) r e)
    (hle : Ty.LeQ D.core Γ' Φ' r b) (hc : Eff.Covers Γ' Φ' ε e)
    (hb : Ty.AnnotationR D.core ks C Γ' b) (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((((CallHead.meth d.toVal m ss es (DictEv.toValList us)).rename (· + k)).apply ws).instR σ.val)
      (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val L) := by
  have hm' := rangeCtx_shiftMap hm σ.val
  have hsi0 := signature_source_convert ((hsi σ).sameTypes hR.types)
    (by simpa only [List.length_append, List.length_cons, List.length_nil, TypeCtx.kinds, List.length_map] using hw)
    (closedTel_norm hsc σ).symm
  simp only [List.map_append, List.map_singleton] at hsi0
  have hdv := (hd.core (Q := Q) (Φ := []) hR σ).shift_values hA storeEmpty_wf
    (StoreTy.PreservesNormals.refl _) hm' (Ξ := Φ') (fun p hp => by cases hp)
  simp only [shiftIndex_add, rangeTy_dict, Ty.shiftV] at hdv
  have hargs := hv.core (Q := Q) hR hA hm0 σ
  have ht : rangeTel σ.val (instantiatedTel ms.tel (ss ++ [τ]) es) =
      instantiatedTel ms.tel (ss.map (rangeTy σ.val) ++ [rangeTy σ.val τ]) (es.map (rangeEff σ.val)) := by
    rw [OpenSignatureExchange.rangeTel_instantiated,
      ← instantiatedTel_norm_source (rangeTel σ.val ms.tel), closedTel_norm hsc σ,
      instantiatedTel_norm_source]
    simp only [List.map_append, List.map_singleton]
  rw [rangeTel_shiftV, ht, instantiatedTel_shift_eq hsi0.source] at hargs
  have hsi' := hm'.signature hsi0
  have hsat' := (hsat σ).map (Ty.shiftV k 0) (fun a ha p hp =>
    hA.sat_shiftV_norm (hsi0.types a (List.mem_append_left _ ha))
      (hm'.annotation (hsi0.types a (List.mem_append_left _ ha))) hp)
  have hrows0 : MethodRowsAdmissible C (rangeCtx σ.val Γ).length Q ms (es.map (rangeEff σ.val)) := by
    simpa only [rangeCtx_length] using hrows σ
  have hrows' := hm'.methodRows hsi0.rows hrows0
  obtain ⟨as, harg, hvs⟩ := hargs.arguments_norm
  have hrn := hargs.doneAnnotation.norm
  simp only [List.map_append, List.map_cons, List.map_nil] at hsi' harg hvs
  have hcall := HasTypeCQ.C_Meth (R := R.map (rangeTy σ.val)) (Δ := rangeLocal σ.val L)
    hdv (hR.classes ▸ hcl) hms hn hsat' hsi' hrows' harg hvs hrn
  have hb' := annotation (B := B) (annotation_sameTypes hb hR.types) σ
  have hres := HasTypeCQ.C_Sub hcall
    (.trans (.convert (Ty.norm_idem _)) ((OpenBody.Le.source (hle.sameTypes hR.types)).at σ))
    (Eff.covers_norm_right.mpr ((OpenBody.Covers.source hc).at σ)) hb'.wf hb'.sorted hb'.declared
  simp only [CallHead.rename, CallHead.apply, comp_meth_instR, Surface.renameTy_add, Surface.renameEff_add]
  have hdRename : (d.toVal.rename (· + k)).instR σ.val = (d.toVal.instR σ.val).rename (· + k) := by
    simpa only [shiftIndex_add] using OpenRangeRename.val_instR_shift d.toVal σ.val k 0
  rw [hdRename]
  simpa only [DictEv.toValList_map, Val.renameList_map, List.map_map, List.map_append,
    Function.comp_def, rangeTy_shiftV, rangeEff_shiftV] using hres

theorem external_head_glue_core {P B ks Q C Γ0 k0 Γ' Φ' L k f d ts ws r e b ε}
    {D : Declarations} {R : Option Ty}
    (hf : D.core.externalFunction f = some d) (hsc : d.parameters.RangesScoped 0)
    (had : ExternalAdmits D.core B ks C d ts) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm0 : ShiftMap k0 0 Γ0 Γ')
    (hv : ValsTel D B ks C Γ0 k0 Γ' Φ' ws (Tel.shiftV k 0 (Tel.bind (typeEnv ts) d.parameters)) r e)
    (hle : Ty.LeQ D.core Γ' Φ' r b) (hc : Eff.Covers Γ' Φ' ε e)
    (hb : Ty.AnnotationR D.core ks C Γ' b) (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((((CallHead.external f ts).rename (· + k)).apply ws).instR σ.val)
      (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val L) := by
  have hf' : P.externalFunction f = some d := (hR.externalFunction _).symm.trans hf
  have hwf := hR.externalWF.function_lookup hf'
  have hcount := (had σ).count
  simp only [List.length_map, hwf.monomorphic, List.length_nil] at hcount
  have hts : ts = [] := List.eq_nil_of_length_eq_zero hcount
  subst ts
  have hargs := hv.core (Q := Q) hR hA hm0 σ
  have he : Tel.bind (typeEnv []) d.parameters = Tel.norm d.parameters :=
    Tel.substAt_nil_of_wf [] d.parameters hwf.annotation.wf
  rw [external_tel_shift hwf k, he, rangeTel_normal_source, closedTel_norm hsc σ, ← he] at hargs
  have ha := had σ
  simp only [List.map_nil] at ha
  have hcall := HasTypeCQ.C_External (R := R.map (rangeTy σ.val)) (Δ := rangeLocal σ.val L)
    hf' hwf ⟨ha.count, ha.kinds.sameTypes hR.types, ha.constraints, ha.types.sameTypes hR.types⟩ hargs
  have hb' := annotation (B := B) (annotation_sameTypes hb hR.types) σ
  have hres := HasTypeCQ.C_Sub hcall ((OpenBody.Le.source (hle.sameTypes hR.types)).at σ)
    ((OpenBody.Covers.source hc).at σ) hb'.wf hb'.sorted hb'.declared
  simp only [CallHead.rename, CallHead.apply, List.map_nil]
  have hec : (Comp.externalCall f [] ws).instR σ.val = .externalCall f [] (ws.map (Val.instR σ.val)) := by
    cases rs : σ.val with
    | nil => change Comp.externalCall f [] ws = .externalCall f [] (ws.map id); rw [List.map_id]
    | cons r rs =>
      simp only [Comp.instR, Comp.substR, Comp.mapRangesN, List.map_nil, vals_mapRangesN_eq_map]
      rfl
  rw [hec]
  exact hres

theorem CallHeadTy.glue_core {P B ks Q C Γ Γ0 k0 Γ' Φ' L k f t ds h ws r e b ε}
    {D : Declarations} {R : Option Ty}
    (hh : CallHeadTy D B ks Q C Γ f t ds) (hd : directCallee f = some h)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
    (hm : ShiftMap k 0 Γ Γ') (hm0 : ShiftMap k0 0 Γ0 Γ')
    (hv : ValsTel D B ks C Γ0 k0 Γ' Φ'
      (ds.map (fun d => d.toVal.rename (· + k)) ++ ws) (Tel.shiftV k 0 t) r e)
    (hle : Ty.LeQ D.core Γ' Φ' r b) (hc : Eff.Covers Γ' Φ' ε e)
    (hb : Ty.AnnotationR D.core ks C Γ' b) (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      (((h.rename (· + k)).apply ws).instR σ.val) (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val L) := by
  have hh0 := hh
  cases hh with
  | meth hdict hcl hms hn hsat hsc hw hsi hrows =>
    simp only [directCallee, Option.some.injEq] at hd
    subst h
    exact meth_head_glue_core hdict hcl hms hn hsat hsc hw hsi hrows hR hA hm hm0 hv hle hc hb σ
  | external hf hsc had =>
    simp only [directCallee, Option.some.injEq] at hd
    subst h
    exact external_head_glue_core hf hsc had hR hA hm0 hv hle hc hb σ
  | _ =>
    simp only [directCallee, Option.some.injEq] at hd
    subst h
    exact app_head_glue_core hh0 rfl hR hA hm hm0 hv hle hc hb σ


end
end Benitoite.Release.Refinement.Surface.OpenSurface
