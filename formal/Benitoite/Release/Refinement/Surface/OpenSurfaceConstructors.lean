import Benitoite.Release.Refinement.Surface.OpenSurfaceCollections
import Benitoite.Release.Refinement.Surface.OpenSurfaceBasicExpr

/-! # 開いた構成子とレコードの脱糖の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem rangeTy_data (rs : List RangeExpr) (d : DataName) (ts : List Ty) :
    rangeTy rs (.data d ts) = .data d (ts.map (rangeTy rs)) := by
  cases rs with
  | nil => change Ty.data d ts = .data d (ts.map id); rw [List.map_id]
  | cons r rs =>
    change Ty.data d (Ty.normTys (mapRangesTys (rangeAt 0 (r :: rs)) ts)) = _
    simp only [Ty.normTys_eq_map, mapRangesTys_eq_map, List.map_map, Function.comp_def]
    rfl

theorem constructor_instR (rs : List RangeExpr) (c : ConName) (ts : List Ty) (vs : List Val) :
    (Val.con c ts vs).instR rs = .con c (ts.map (rangeTy rs)) (vs.map (Val.instR rs)) := by
  cases rs with
  | nil => change Val.con c ts vs = .con c (ts.map id) (vs.map id); rw [List.map_id, List.map_id]
  | cons r rs =>
    change Val.con c _ (Val.mapRangesListN _ vs) = .con c _ _
    congr 1
    induction vs <;> simp_all [Val.mapRangesListN, Val.instR, Val.substR]

theorem nullCon_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys) (he : cd.args = [])
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hR : D.Realizes P) (σ : Instance ks) :
    ExprCore P B op Q Δ C Γ Φ R p (.nullCon c ts) (.data cd.data ts) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_data] at ha'
  simp only [ExprCore, desugarExpr, comp_ret_instR, constructor_instR,
    rangeTy_data, List.map_nil, rangeEff_empty]
  refine .C_Return (.V_Con (hR.cons ▸ hc) (by simpa only [List.length_map] using hn)
    (range_types_kinded (hk.sameTypes hR.types) σ.val) (by simp [he]) ?_ ha')
  simpa only [he, List.map_nil] using (HasTypeVsQ.nil (P := P) (B := B)
    (Ψ := StoreTy.empty) (Q := Q) (C := C) (Γ := rangeCtx σ.val Γ) (Φ := Φ))

theorem shiftTs_rangeTy (rs : List RangeExpr) (n : Nat) (ts : List Ty) :
    (shiftTs n ts).map (rangeTy rs) = shiftTs n (ts.map (rangeTy rs)) := by
  simp only [shiftTs, List.map_map, Function.comp_def, rangeTy_shiftV]

theorem constructor_subst_ranges (rs : List RangeExpr) (ts args : List Ty) (n : Nat)
    (hc : ∀ a ∈ args, a.RangesScoped 0) :
    (args.map (Ty.subst (shiftTs n ts) [])).map (rangeTy rs) =
      args.map (Ty.subst (shiftTs n (ts.map (rangeTy rs))) []) := by
  rw [List.map_map]
  apply List.map_congr_left
  intro a ha
  rw [Function.comp_apply, rangeTy_subst_closed rs a (hc a ha), shiftTs_rangeTy]

theorem constructor_value_core {D : Declarations} {P B ks Q C Γ Φ c cd ts as vs}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ) vs
      (cd.args.map (Ty.subst (shiftTs as.length ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
    HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val (bindParams Γ as)) (liftMany as.length Φ)
      ((Val.con c (shiftTs as.length ts) vs).instR σ.val)
      (rangeTy σ.val ((Ty.data cd.data ts).shiftV as.length 0)) := by
  have ha' := (annotation (B := B) (annotation_sameTypes ha hR.types) σ).under
    (as.map (rangeTy σ.val))
  rw [rangeTy_data] at ha'
  simp only [Ty.shiftV, shiftVTys_eq_map, List.length_map, List.map_map, Function.comp_def] at ha'
  have hvs := hvals.core (Q := Q) hR hA (FullShiftMap.outer Γ as).values σ
  rw [constructor_subst_ranges σ.val ts cd.args as.length hclosed] at hvs
  simp only [shiftTs, List.map_map, Function.comp_def] at hvs
  rw [constructor_instR, shiftTs_rangeTy]
  simp only [rangeTy_data, Ty.shiftV, shiftVTys_eq_map, shiftTs,
    List.map_map, Function.comp_def, rangeTy_shiftV]
  refine .V_Con (hR.cons ▸ hc) (by simpa only [List.length_map] using hn)
    (by simpa only [List.map_map, Function.comp_def] using
      (range_types_kinded (hk.sameTypes hR.types) σ.val).shift as.length 0) hw hvs ?_
  simpa only [rangeCtx_bindParams] using ha'

theorem constructor_sequence_core {D : Declarations} {P B ks Q Δ C Γ Φ c cd ts ms as vs ε}
    {R : Option Ty}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ) vs
      (cd.args.map (Ty.subst (shiftTs as.length ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) (ms.map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      ((letChain 0 ms (.ret (.con c (shiftTs as.length ts) vs))).instR σ.val)
      (rangeTy σ.val (.data cd.data ts)) (rangeEff σ.val ε) (rangeLocal σ.val Δ) := by
  apply sequence_instR hA hms
  · rw [comp_ret_instR]
    exact .C_Eff (.C_Return (constructor_value_core hc hn hk hw hclosed ha hvals hR hA σ))
      (Eff.covers_empty _ _ _)
  · exact ha.declared.sameTypes hR.types

theorem conCall_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts args as ε}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (boundVars as.length) (cd.args.map (Ty.subst (shiftTs as.length ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.conCall c ts args) (.data cd.data ts) ε σ.val := by
  have hl : (desugarExprs op args).length = as.length := by
    simpa only [List.length_map] using hms.length
  have hal : args.length = as.length := (desugarExprs_length op args).symm.trans hl
  simp only [ExprCore, desugarExpr, sequence, hl, hal]
  exact constructor_sequence_core hc hn hk hw hclosed ha hvals hR hA σ hms

theorem record_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts positions args as ε}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (recordFields positions.length positions (boundVars as.length) (.const .unit))
      (cd.args.map (Ty.subst (shiftTs as.length ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.record c ts positions args) (.data cd.data ts) ε σ.val := by
  have hl : (desugarExprs op args).length = as.length := by
    simpa only [List.length_map] using hms.length
  have hal : args.length = as.length := (desugarExprs_length op args).symm.trans hl
  simp only [ExprCore, desugarExpr, sequence, hl, hal]
  exact constructor_sequence_core hc hn hk hw hclosed ha hvals hR hA σ hms

theorem conValue_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts names ps}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys) (hnm : NamesWF names ps)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.fn names ps (.data cd.data ts) Eff.empty))
    (hvals : ValsTys D B ks C Γ ps.length (bindParams (hideConts Γ) ps)
      (liftMany ps.length Φ) (boundVars ps.length) (cd.args.map (Ty.subst (shiftTs ps.length ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
    ExprCore P B op Q Δ C Γ Φ R p (.conValue c ts names ps)
      (.fn names ps (.data cd.data ts) Eff.empty) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_fn, rangeTy_data, rangeEff_empty] at ha'
  have hd := (ShiftMap.hideOuter (rangeCtx σ.val Γ) (ps.map (rangeTy σ.val))).annotation ha'.fn_result
  simp only [List.length_map, Ty.shiftV, shiftVTys_eq_map, List.map_map, Function.comp_def] at hd
  have hvs := hvals.core (Q := Q) hR hA (ShiftMap.hideOuter Γ ps) σ
  rw [constructor_subst_ranges σ.val ts cd.args ps.length hclosed] at hvs
  simp only [rangeCtx_bindParams, rangeCtx_hideConts, shiftTs, List.map_map, Function.comp_def] at hvs
  have hm : (desugarExpr op p (.conValue c ts names ps)).instR σ.val =
      .ret (.lam names (ps.map (rangeTy σ.val))
        ((Comp.ret (.con c (shiftTs ps.length ts) (boundVars ps.length))).instR σ.val)) := by
    cases σ.val with
    | nil =>
      have hr : rangeTy [] = id := rfl
      simp only [desugarExpr, Comp.instR_nil, hr, List.map_id]
    | cons r rs => rfl
  simp only [ExprCore, hm, rangeTy_fn, rangeTy_data, rangeEff_empty]
  refine .C_Return (.V_Lam ⟨by simpa only [List.length_map] using hnm.1, hnm.2⟩
    ha'.wf ha'.sorted ?_ ha'.declared)
  rw [hideBuilders_empty, comp_ret_instR, constructor_instR, shiftTs_rangeTy]
  simp only [List.length_map, Ty.shiftV, shiftVTys_eq_map, shiftTs, List.map_map,
    Function.comp_def]
  exact .C_Return (.V_Con (hR.cons ▸ hc) (by simpa [List.length_map] using hn)
    (by simpa only [List.map_map, Function.comp_def] using
      (range_types_kinded (hk.sameTypes hR.types) σ.val).shift ps.length 0)
    hw hvs hd)

theorem recordRefined_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts positions args as q ε}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.refined (.data cd.data ts) q))
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (recordFields positions.length positions (boundVars as.length) (.const .unit))
      (cd.args.map (Ty.subst (shiftTs as.length ts) [])))
    (hent : Entails ((bindParams Γ as).facts ++ liftMany as.length Φ)
      ((liftRef as.length q).open (.dataValue c
        (Val.toTermSlots (recordFields positions.length positions (boundVars as.length) (.const .unit))))))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.record c ts positions args)
      (.refined (.data cd.data ts) q) ε σ.val := by
  have hl : (desugarExprs op args).length = as.length := by
    simpa only [List.length_map] using hms.length
  have hal : args.length = as.length := (desugarExprs_length op args).symm.trans hl
  have hdata : Ty.AnnotationR D.core ks C Γ (.data cd.data ts) :=
    ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩
  have hdi := annotation (B := B) (annotation_sameTypes hdata hR.types) σ
  have hraw : Ty.Annotation P C (rangeCtx σ.val Γ)
      (.refined (rangeTy σ.val (.data cd.data ts)) q) := by
    refine ⟨⟨hdi.wf, ?_, ?_⟩, ⟨hdi.sorted, ?_⟩, ⟨hdi.declared, ?_⟩⟩
    · simpa only [rangeCtx_length] using ha.wf.2.1
    · rw [rangeTy_data]; intro b t e h; cases h
    · exact rangeCtx_pred_sorted ha.sorted.2 σ.val
    · exact rangeCtx_pred_declared (B := B) (ha.declared.2.sameTypes hR.types) σ.val
  have hraw' := hraw.under (as.map (rangeTy σ.val))
  have hout := (annotation (B := B) (annotation_sameTypes ha hR.types) σ).under
    (as.map (rangeTy σ.val))
  rw [List.length_map, shiftV_refined] at hraw'
  have heq := rangeCtx_bindParams σ.val Γ as
  rw [← heq] at hraw' hout
  simp only [List.length_map] at hout
  have hcon := constructor_value_core (Q := Q) hc hn hk hw hclosed hdata hvals hR hA σ
  rw [rangeTy_shiftV] at hcon
  have hproof : Entails ((rangeCtx σ.val (bindParams Γ as)).facts ++ liftMany as.length Φ)
      ((liftRef as.length q).open (.dataValue c
        (Val.toTermSlots (recordFields positions.length positions (boundVars as.length) (.const .unit))))) := by
    simpa only [rangeCtx_facts] using hent
  have hto := toTerm_instR
    (.con c (shiftTs as.length ts)
      (recordFields positions.length positions (boundVars as.length) (.const .unit))) σ.val
  have href := HasTypeVQ.V_Refine (sort := .data) hcon
    (by rw [rangeTy_data]; rfl) hto hraw'.sorted.2 hraw'.wf.2.1 hproof
    hraw'.declared.1 hraw'.declared.2
  simp only [ExprCore, desugarExpr, sequence, hl, hal]
  apply sequence_instR hA hms
  · rw [comp_ret_instR, rangeTy_shiftV]
    apply HasTypeCQ.C_Eff (ε := Eff.empty)
    · apply HasTypeCQ.C_Return
      apply HasTypeVQ.V_Sub href (.convert ?_) hout.wf hout.sorted hout.declared
      simpa only [← Ty.norm_shiftV, shiftV_refined] using
        congrArg (Ty.shiftV as.length 0) (rangeTy_refined σ.val (.data cd.data ts) q)
    · exact Eff.covers_empty _ _ _
  · exact ha.declared.sameTypes hR.types

theorem constructor_at_core {D : Declarations} {P B ks Q C Γ0 k Γ Φ c cd ts vs}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (hvals : ValsTys D B ks C Γ0 k Γ Φ vs (cd.args.map (Ty.subst ts [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ)
    (σ : Instance ks) (ha : Ty.Annotation P C (rangeCtx σ.val Γ) (rangeTy σ.val (.data cd.data ts))) :
    HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ
      ((Val.con c ts vs).instR σ.val) (rangeTy σ.val (.data cd.data ts)) := by
  have hvs := hvals.core (Q := Q) hR hA hm σ
  have hargs : (cd.args.map (Ty.subst ts [])).map (rangeTy σ.val) =
      cd.args.map (Ty.subst (ts.map (rangeTy σ.val)) []) := by
    rw [List.map_map]
    exact List.map_congr_left (fun a ha => rangeTy_subst_closed σ.val a (hclosed a ha) ts)
  rw [hargs] at hvs
  rw [rangeTy_data] at ha
  rw [constructor_instR, rangeTy_data]
  exact .V_Con (hR.cons ▸ hc) (by simpa only [List.length_map] using hn)
    (range_types_kinded (hk.sameTypes hR.types) σ.val) hw hvs ha

private theorem constructor_alts_core {D : Declarations} {P alts a δ}
    (hR : D.Realizes P) (hp : PatternRangesClosed D.core) (h : AltsTy D.core alts a δ)
    (rs : List RangeExpr) : AltsTy P alts (rangeTy rs a) (δ.map (rangeTy rs)) := by
  cases rs with
  | nil =>
    change AltsTy P alts a (δ.map id)
    rw [List.map_id]
    exact h.sameTypes hR.types
  | cons r rs => exact (h.instR hp (r :: rs)).sameTypes hR.types

private theorem constructor_exhaustive_core {D : Declarations} {P a ps}
    (hR : D.Realizes P) (hp : PatternRangesClosed D.core) (h : Exhaustive D.core a ps)
    (rs : List RangeExpr) : Exhaustive P (rangeTy rs a) ps := by
  cases rs with
  | nil => exact h.sameTypes hR.types
  | cons r rs => exact (h.instR hp (r :: rs)).sameTypes hR.types

theorem recordUpdate_shape_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c ts n positions base args as δ b ε}
    {cd : ConDecl}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hp : PatternRangesClosed D.core)
    (ha : Ty.AnnotationR D.core ks C Γ b)
    (hd : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hal : AltsTy D.core [⟨recordUpdatePattern c n positions,
      List.range (recordUpdatePattern c n positions).binders⟩]
      ((Ty.data cd.data ts).shiftV (as.length + 1) 0) δ)
    (hex : Exhaustive D.core (.data cd.data ts) [recordUpdatePattern c n positions])
    (he : ExprCore P B op Q Δ C Γ Φ R .other base (.data cd.data ts) ε σ.val)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε))
    (hbuild : HasTypeVQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (bindParams Γ (.data cd.data ts :: as)) δ))
      (liftMany δ.length (liftMany (as.length + 1) Φ))
      ((Val.con c (shiftTs (as.length + 1 + δ.length) ts)
        (recordUpdateValues c n positions (boundVars as.length))).instR σ.val)
      (rangeTy σ.val (b.shiftV (as.length + 1 + δ.length) 0))) :
    ExprCore P B op Q Δ C Γ Φ R p (.recordUpdate c ts n positions base args) b ε σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hd' := annotation (B := B) (annotation_sameTypes hd hR.types) σ
  have hl : (desugarExprs op args).length = as.length := by
    simpa only [List.length_map] using hms.length
  have hlen : args.length = as.length := (desugarExprs_length op args).symm.trans hl
  have hbn : (recordUpdatePattern c n positions).binders = δ.length := hal.2.1.symm
  have hal' := constructor_alts_core hR hp hal σ.val
  rw [rangeTy_shiftV] at hal'
  have hx := (constructor_exhaustive_core hR hp hex σ.val).shiftV (as.length + 1) 0
  have hshape : (Comp.match (.var as.length)
      [mkArm (recordUpdatePattern c n positions)
        (.ret (.con c (shiftTs (as.length + 1 + δ.length) ts)
          (recordUpdateValues c n positions (boundVars as.length))))]).instR σ.val =
      .match (.var as.length) [mkArm (recordUpdatePattern c n positions)
        (.ret ((Val.con c (shiftTs (as.length + 1 + δ.length) ts)
          (recordUpdateValues c n positions (boundVars as.length))).instR σ.val))] := by
    cases σ.val <;> rfl
  simp only [ExprCore, desugarExpr, hlen, hbn, comp_let_instR, letChain_instR, hshape]
  refine .C_Let he ?_ ha'.declared
  have hchain := letChain_typed hA storeEmpty_wf _ [rangeTy σ.val (.data cd.data ts)]
    (as.map (rangeTy σ.val))
    (.match (.var as.length) [mkArm (recordUpdatePattern c n positions)
      (.ret ((Val.con c (shiftTs (as.length + 1 + δ.length) ts)
        (recordUpdateValues c n positions (boundVars as.length))).instR σ.val))])
    (rangeTy σ.val b) (rangeEff σ.val ε) hms ?_ ha'.declared
  · simpa only [List.length_cons, List.length_nil, Nat.zero_add, bindParams_single,
      liftMany_one] using hchain
  simp only [List.singleton_append, List.length_cons, List.length_nil, Nat.zero_add,
    Nat.add_comm 1, List.length_map]
  have hX := ha'.under (rangeTy σ.val (.data cd.data ts) :: as.map (rangeTy σ.val))
  have hX0 := hd'.under (rangeTy σ.val (.data cd.data ts) :: as.map (rangeTy σ.val))
  simp only [List.length_cons, List.length_map] at hX hX0
  refine .C_Match (obs := none) (.V_Var (by
    simpa only [List.length_map] using
      (bindParams_lookup_head (rangeCtx σ.val Γ) (rangeTy σ.val (.data cd.data ts)) (as.map (rangeTy σ.val))))
    (by rw [rangeTy_data]; intro b t e; simp [Ty.core, Ty.shiftV]))
    (fun _ h => by cases h) ?_ hX0.declared hx
  refine HasTypeArmsQ.plainEmpty hal' (by intro q hq; cases hq) ?_ (.nil hX)
  simp only [pathFacts, List.nil_append]
  refine .C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _)
  simpa only [rangeCtx_bindParams, List.map_cons, List.length_map, rangeTy_shiftV,
    Ty.shiftV_add, Nat.add_assoc] using hbuild

theorem recordUpdate_annotation {D : Declarations} {P ks C Γ a b as δ} {B : Builtins}
    (ha : Ty.AnnotationR D.core ks C Γ a) (hR : D.Realizes P) (σ : Instance ks) :
    Ty.Annotation P C (rangeCtx σ.val (bindParams (bindParams Γ (b :: as)) δ))
      (rangeTy σ.val (a.shiftV (as.length + 1 + δ.length) 0)) := by
  have hy := ((annotation (B := B) (annotation_sameTypes ha hR.types) σ).under
    ((b :: as).map (rangeTy σ.val))).under (δ.map (rangeTy σ.val))
  simpa only [rangeCtx_bindParams, List.map_cons, List.length_map, List.length_cons,
    rangeTy_shiftV, Ty.shiftV_add] using hy

theorem recordUpdate_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts n positions base args as δ ε}
    (hp : PatternRangesClosed D.core) (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hal : AltsTy D.core [⟨recordUpdatePattern c n positions,
      List.range (recordUpdatePattern c n positions).binders⟩]
      ((Ty.data cd.data ts).shiftV (as.length + 1) 0) δ)
    (hvals : ValsTys D B ks C (bindParams (bindParams Γ (.data cd.data ts :: as)) δ) 0
      (bindParams (bindParams Γ (.data cd.data ts :: as)) δ)
      (liftMany δ.length (liftMany (as.length + 1) Φ))
      (recordUpdateValues c n positions (boundVars as.length))
      (cd.args.map (Ty.subst (shiftTs (as.length + 1 + δ.length) ts) [])))
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0)
    (hex : Exhaustive D.core (.data cd.data ts) [recordUpdatePattern c n positions])
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R .other base (.data cd.data ts) ε σ.val)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.recordUpdate c ts n positions base args)
      (.data cd.data ts) ε σ.val := by
  apply recordUpdate_shape_core hR hA σ hp ha ha hal hex he hms
  have han := recordUpdate_annotation (b := .data cd.data ts) (as := as) (δ := δ) (B := B) ha hR σ
  have hdat : (Ty.data cd.data ts).shiftV (as.length + 1 + δ.length) 0 =
      .data cd.data (shiftTs (as.length + 1 + δ.length) ts) := by
    simp only [Ty.shiftV, shiftVTys_eq_map, shiftTs]
  rw [hdat] at han ⊢
  exact constructor_at_core hc (by simpa only [shiftTs, List.length_map] using hn)
    (hk.shift (as.length + 1 + δ.length) 0) hw (hp c cd hc) hvals hR hA
    (ShiftMap.self _) σ han

theorem recordUpdateRefined_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts n positions base args as δ q ε}
    (hp : PatternRangesClosed D.core) (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (ha : Ty.AnnotationR D.core ks C Γ (.refined (.data cd.data ts) q))
    (hal : AltsTy D.core [⟨recordUpdatePattern c n positions,
      List.range (recordUpdatePattern c n positions).binders⟩]
      ((Ty.data cd.data ts).shiftV (as.length + 1) 0) δ)
    (hvals : ValsTys D B ks C (bindParams (bindParams Γ (.data cd.data ts :: as)) δ) 0
      (bindParams (bindParams Γ (.data cd.data ts :: as)) δ)
      (liftMany δ.length (liftMany (as.length + 1) Φ))
      (recordUpdateValues c n positions (boundVars as.length))
      (cd.args.map (Ty.subst (shiftTs (as.length + 1 + δ.length) ts) [])))
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0)
    (hex : Exhaustive D.core (.data cd.data ts) [recordUpdatePattern c n positions])
    (hent : Entails ((bindParams (bindParams Γ (.data cd.data ts :: as)) δ).facts ++
      liftMany δ.length (liftMany (as.length + 1) Φ))
      ((liftRef (as.length + 1 + δ.length) q).open
        (.dataValue c (Val.toTermSlots (recordUpdateValues c n positions (boundVars as.length))))))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R .other base (.data cd.data ts) ε σ.val)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.recordUpdate c ts n positions base args)
      (.refined (.data cd.data ts) q) ε σ.val := by
  have hdata : Ty.AnnotationR D.core ks C Γ (.data cd.data ts) :=
    ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩
  apply recordUpdate_shape_core hR hA σ hp ha hdata hal hex he hms
  have han := recordUpdate_annotation (b := .data cd.data ts) (as := as) (δ := δ) (B := B) hdata hR σ
  have hout := recordUpdate_annotation (b := .data cd.data ts) (as := as) (δ := δ) (B := B) ha hR σ
  have hdat : (Ty.data cd.data ts).shiftV (as.length + 1 + δ.length) 0 =
      .data cd.data (shiftTs (as.length + 1 + δ.length) ts) := by
    simp only [Ty.shiftV, shiftVTys_eq_map, shiftTs]
  rw [hdat] at han
  have hcon0 := constructor_at_core (Q := Q) hc
    (by simpa only [shiftTs, List.length_map] using hn)
    (hk.shift (as.length + 1 + δ.length) 0) hw (hp c cd hc) hvals hR hA (ShiftMap.self _) σ han
  have hcon : HasTypeVQ P B StoreTy.empty Q C
    (rangeCtx σ.val (bindParams (bindParams Γ (.data cd.data ts :: as)) δ))
    (liftMany δ.length (liftMany (as.length + 1) Φ))
    ((Val.con c (shiftTs (as.length + 1 + δ.length) ts)
      (recordUpdateValues c n positions (boundVars as.length))).instR σ.val)
    (rangeTy σ.val ((Ty.data cd.data ts).shiftV (as.length + 1 + δ.length) 0)) := by
    simpa only [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hcon0
  rw [rangeTy_shiftV] at hcon
  have hdi := annotation (B := B) (annotation_sameTypes hdata hR.types) σ
  have hraw : Ty.Annotation P C (rangeCtx σ.val Γ)
      (.refined (rangeTy σ.val (.data cd.data ts)) q) := by
    refine ⟨⟨hdi.wf, ?_, ?_⟩, ⟨hdi.sorted, ?_⟩, ⟨hdi.declared, ?_⟩⟩
    · simpa only [rangeCtx_length] using ha.wf.2.1
    · rw [rangeTy_data]; intro b t e h; cases h
    · exact rangeCtx_pred_sorted ha.sorted.2 σ.val
    · exact rangeCtx_pred_declared (B := B) (ha.declared.2.sameTypes hR.types) σ.val
  have hrawY : Ty.Annotation P C
      (rangeCtx σ.val (bindParams (bindParams Γ (.data cd.data ts :: as)) δ))
      ((Ty.refined (rangeTy σ.val (.data cd.data ts)) q).shiftV (as.length + 1 + δ.length) 0) := by
    simpa only [rangeCtx_bindParams, List.map_cons, List.length_map, List.length_cons,
      Ty.shiftV_add] using
      ((hraw.under ((Ty.data cd.data ts :: as).map (rangeTy σ.val))).under (δ.map (rangeTy σ.val)))
  rw [shiftV_refined] at hrawY
  have hproof : Entails
      ((rangeCtx σ.val (bindParams (bindParams Γ (.data cd.data ts :: as)) δ)).facts ++
        liftMany δ.length (liftMany (as.length + 1) Φ))
      ((liftRef (as.length + 1 + δ.length) q).open
        (.dataValue c (Val.toTermSlots (recordUpdateValues c n positions (boundVars as.length))))) := by
    simpa only [rangeCtx_facts] using hent
  have hto := toTerm_instR
    (.con c (shiftTs (as.length + 1 + δ.length) ts)
      (recordUpdateValues c n positions (boundVars as.length))) σ.val
  have href := HasTypeVQ.V_Refine (sort := .data) hcon
    (by rw [rangeTy_data]; rfl) hto hrawY.sorted.2 hrawY.wf.2.1 hproof
    hrawY.declared.1 hrawY.declared.2
  rw [rangeTy_shiftV] at hout ⊢
  apply HasTypeVQ.V_Sub href (.convert ?_) hout.wf hout.sorted hout.declared
  simpa only [← Ty.norm_shiftV, shiftV_refined] using congrArg
    (Ty.shiftV (as.length + 1 + δ.length) 0) (rangeTy_refined σ.val (.data cd.data ts) q)

theorem pipeConCall_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p lhs c cd ts args tl as ε}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hvals : ValsTys D B ks C Γ (as.length + 1) (bindParams Γ (tl :: as))
      (liftMany (as.length + 1) Φ) (.var as.length :: boundVars as.length)
      (cd.args.map (Ty.subst (shiftTs (as.length + 1) ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R .other lhs tl ε σ.val)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.pipe lhs (.conCall c ts args)) (.data cd.data ts) ε σ.val := by
  have hl : (desugarExprs op args).length = as.length := by
    simpa only [List.length_map] using hms.length
  have hh := constructor_sequence_core (as := tl :: as)
    (ms := desugarExpr op .other lhs :: desugarExprs op args)
    hc hn hk hw hclosed ha hvals hR hA σ (.cons he hms)
  simp only [letChain] at hh
  rw [show (fun x : Nat => x + 0) = id from rfl, Comp.rename_identity] at hh
  simpa only [ExprCore, desugarExpr, hl, List.length_cons, Nat.zero_add] using hh

theorem pipeConValue_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p lhs c cd ts names ps tl ε}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (ha : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (hvals : ValsTys D B ks C Γ 1 (bindParams Γ [tl]) (liftMany 1 Φ) [.var 0]
      (cd.args.map (Ty.subst (shiftTs 1 ts) [])))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R .other lhs tl ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.pipe lhs (.conValue c ts names ps))
      (.data cd.data ts) ε σ.val := by
  have hh := constructor_sequence_core (as := [tl]) (ms := [desugarExpr op .other lhs])
    hc hn hk hw hclosed ha hvals hR hA σ (.cons he .nil)
  simp only [letChain] at hh
  rw [show (fun x : Nat => x + 0) = id from rfl, Comp.rename_identity] at hh
  simpa only [ExprCore, desugarExpr, List.length_cons, List.length_nil, Nat.zero_add] using hh

end
end Benitoite.Release.Refinement.Surface.OpenSurface
