import Benitoite.Release.Refinement.Surface.OpenSurfaceCalls
import Benitoite.Release.Refinement.Surface.OpenSurfaceControl
import Benitoite.Release.Refinement.NormalizedApplication

/-! # 開いた呼出しの式の型の保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

abbrev ExprsCore (P : Refinement.Program) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
    (args : Exprs) (as : List Ty) (ε : Eff) (rs : List RangeExpr) : Prop :=
  Surface.CompsTy P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
    (rangeLocal rs Δ) ((desugarExprs op args).map (Comp.instR rs)) (as.map (rangeTy rs)) (rangeEff rs ε)

theorem exprs_length {P B op Q Δ C Γ Φ R args as ε rs}
    (h : ExprsCore P B op Q Δ C Γ Φ R args as ε rs) : args.length = as.length := by
  have hl : (desugarExprs op args).length = as.length := by
    simpa only [List.length_map] using h.length
  exact (desugarExprs_length op args).symm.trans hl

theorem direct_sequence_core {P B ks Q C Γ Φ Δ ms as body f t ds h ws r e b ε}
    {D : Declarations} {R : Option Ty} (hh : CallHeadTy D B ks Q C Γ f t ds) (hd : directCallee f = some h)
    (hv : ValsTel D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (ds.map (fun d => d.toVal.rename (· + as.length)) ++ ws) (Tel.shiftV as.length 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ as) (liftMany as.length Φ) r (b.shiftV as.length 0))
    (hc : Eff.Covers (bindParams Γ as) (liftMany as.length Φ) (Eff.shiftV as.length 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hbody : body = (h.rename (· + as.length)).apply ws)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) (ms.map (Comp.instR σ.val)) (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      ((letChain 0 ms body).instR σ.val) (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val Δ) := by
  subst body
  have hg := hh.glue_core (R := R.map (Ty.shiftV as.length 0)) (L := localExtend as.length Δ)
    hd hR hA (FullShiftMap.outer Γ as).values (FullShiftMap.outer Γ as).values hv hle hc
    (annotation_under hb as) σ
  rw [rangeLocal_extend] at hg
  exact sequence_instR hA hms hg (hb.declared.sameTypes hR.types)

theorem indirect_sequence_core {P B ks Q C Γ Φ Δ ms as j t ws r e b ε}
    {D : Declarations} {R : Option Ty}
    (hj : (bindParams Γ as)[j]? = some (some (.dependentFn (Tel.shiftV as.length 0 t))))
    (hv : ValsTel D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ) ws
      (Tel.shiftV as.length 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ as) (liftMany as.length Φ) r (b.shiftV as.length 0))
    (hc : Eff.Covers (bindParams Γ as) (liftMany as.length Φ) (Eff.shiftV as.length 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) (ms.map (Comp.instR σ.val)) (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      ((letChain 0 ms (.app (.var j) ws)).instR σ.val) (rangeTy σ.val b)
      (rangeEff σ.val ε) (rangeLocal σ.val Δ) := by
  have hvar : HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val (bindParams Γ as)) (liftMany as.length Φ)
      (.var j) (rangeTy σ.val (.dependentFn (Tel.shiftV as.length 0 t))) :=
    .V_Var (rangeCtx_lookup hj σ.val) (rangeTy_ordinary (by intro b t e; simp [Ty.core]) σ.val)
  have hvarn := hvar.V_Normal
  rw [dependentFn_range_norm] at hvarn
  have hargs := hv.core (Q := Q) hR hA (FullShiftMap.outer Γ as).values σ
  have happ := HasTypeCQ.dependentApp_normalized
    (R := (R.map (Ty.shiftV as.length 0)).map (rangeTy σ.val))
    (Δ := localExtend as.length (rangeLocal σ.val Δ)) hvarn hargs
  have hb' := annotation (B := B) (annotation_sameTypes (annotation_under hb as) hR.types) σ
  have hfinish := HasTypeCQ.C_Sub happ (le_core hR hle σ.val)
    ((OpenBody.Covers.source hc).at σ) hb'.wf hb'.sorted hb'.declared
  apply sequence_instR hA hms ?_ (hb.declared.sameTypes hR.types)
  rw [comp_app_instR, val_var_instR]
  exact hfinish

theorem callDirect_core {P B ks op Q Δ C Γ Φ R p f labels positions args t ds as r e b ε}
    {D : Declarations} (hh : CallHeadTy D B ks Q C Γ f t ds)
    (hv : ValsTel D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (ds.map (fun d => d.toVal.rename (· + as.length)) ++
        recordFields as.length positions (boundVars as.length) (.const .unit))
      (Tel.shiftV as.length 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ as) (liftMany as.length Φ) r (b.shiftV as.length 0))
    (hc : Eff.Covers (bindParams Γ as) (liftMany as.length Φ) (Eff.shiftV as.length 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : ExprsCore P B op Q Δ C Γ Φ R args as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.call f labels positions args) b ε σ.val := by
  have hl := exprs_length hms
  obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
  have hg := hh.glue_core (R := R.map (Ty.shiftV as.length 0)) (L := localExtend as.length Δ)
    hd hR hA (FullShiftMap.outer Γ as).values (FullShiftMap.outer Γ as).values
    hv hle hc (annotation_under hb as) σ
  rw [rangeLocal_extend] at hg
  change HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
    ((desugarExpr op p (.call f labels positions args)).instR σ.val)
    (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val Δ)
  simp only [desugarExpr, callComp, hd, desugarExprs_length, hl, Nat.zero_add, List.length_nil,
    List.range_zero, List.nil_append, Val.renameList]
  exact sequence_instR hA hms hg (hb.declared.sameTypes hR.types)

theorem call_core {P B ks op Q Δ C Γ Φ R p f labels positions args t as r e b ε}
    {D : Declarations} (hnd : directCallee f = none)
    (hv : ValsTel D B ks C Γ (as.length + 1) (bindParams Γ (.dependentFn t :: as))
      (liftMany (as.length + 1) Φ) (recordFields as.length positions (boundVars as.length) (.const .unit))
      (Tel.shiftV (as.length + 1) 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ (.dependentFn t :: as)) (liftMany (as.length + 1) Φ) r
      (b.shiftV (as.length + 1) 0))
    (hc : Eff.Covers (bindParams Γ (.dependentFn t :: as)) (liftMany (as.length + 1) Φ)
      (Eff.shiftV (as.length + 1) 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hf : ExprCore P B op Q Δ C Γ Φ R .other f (.dependentFn t) ε σ.val)
    (hms : ExprsCore P B op Q Δ C Γ Φ R args as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.call f labels positions args) b ε σ.val := by
  have hl := exprs_length hms
  have hlookup := rangeCtx_lookup (bindParams_lookup_head Γ (.dependentFn t) as) σ.val
  have hvar : HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val (bindParams Γ (.dependentFn t :: as)))
      (liftMany (as.length + 1) Φ) (.var as.length)
      (rangeTy σ.val (.dependentFn (Tel.shiftV (as.length + 1) 0 t))) :=
    .V_Var hlookup (rangeTy_ordinary (by intro b t e; simp [Ty.core]) σ.val)
  have hvarn := hvar.V_Normal
  rw [dependentFn_range_norm] at hvarn
  have hargs := hv.core (Q := Q) hR hA (FullShiftMap.outer Γ (.dependentFn t :: as)).values σ
  have happ := HasTypeCQ.dependentApp_normalized
    (R := (R.map (Ty.shiftV (as.length + 1) 0)).map (rangeTy σ.val))
    (Δ := localExtend (as.length + 1) (rangeLocal σ.val Δ)) hvarn hargs
  have hb' := annotation (B := B) (annotation_sameTypes (annotation_under hb (.dependentFn t :: as)) hR.types) σ
  have hfinish := HasTypeCQ.C_Sub happ (le_core hR hle σ.val)
    ((OpenBody.Covers.source hc).at σ) hb'.wf hb'.sorted hb'.declared
  have hsource : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) (((desugarExpr op .other f) :: desugarExprs op args).map (Comp.instR σ.val))
      ((.dependentFn t :: as).map (rangeTy σ.val)) (rangeEff σ.val ε) := .cons hf hms
  have hh := sequence_instR (body := .app (.var as.length)
      (recordFields as.length positions (boundVars as.length) (.const .unit))) hA hsource (by
      rw [comp_app_instR, val_var_instR]
      simpa only [List.length_cons, Nat.add_comm 1] using hfinish) (hb.declared.sameTypes hR.types)
  change HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
    ((desugarExpr op p (.call f labels positions args)).instR σ.val)
    (rangeTy σ.val b) (rangeEff σ.val ε) (rangeLocal σ.val Δ)
  simpa only [desugarExpr, callComp, hnd, desugarExprs_length, hl, Nat.zero_add, List.length_nil,
    List.range_zero, List.nil_append, Val.renameList, letChain,
    show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity] using hh

theorem binary_core {P B ks op Q Δ C Γ Φ R p o t b s ts lhs rhs r e a ε}
    {D : Declarations} (hop : op (.binary o) t = some (b, ts))
    (hh : CallHeadTy D B ks Q C Γ (.primName b ts [] []) s [])
    (hv : ValsTel D B ks C Γ 2 (bindParams Γ [t, t]) (liftMany 2 Φ) [.var 1, .var 0]
      (Tel.shiftV 2 0 s) r e)
    (hle : Ty.LeQ D.core (bindParams Γ [t, t]) (liftMany 2 Φ) r (a.shiftV 2 0))
    (hc : Eff.Covers (bindParams Γ [t, t]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) e)
    (ha : Ty.AnnotationR D.core ks C Γ a) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs t ε σ.val)
    (hr : ExprCore P B op Q Δ C Γ Φ R .other rhs t ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.binary o t lhs rhs) a ε σ.val := by
  have hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ([desugarExpr op .other lhs, desugarExpr op .other rhs].map (Comp.instR σ.val))
      ([t, t].map (rangeTy σ.val)) (rangeEff σ.val ε) := .cons hl (.cons hr .nil)
  have hseq := direct_sequence_core (as := [t, t]) (ws := [.var 1, .var 0]) hh rfl hv hle hc ha rfl hR hA σ hms
  simpa [ExprCore, desugarExpr, hop, sequence, CallHead.rename, CallHead.apply,
    Val.rename, Val.renameList, Surface.renameTy_add, shiftTs, boundVars,
    List.range_succ] using hseq

theorem neg_core {P B ks op Q Δ C Γ Φ R p t b s ts e0 r e ε}
    {D : Declarations} (hop : op .neg t = some (b, ts))
    (hh : CallHeadTy D B ks Q C Γ (.primName b ts [] []) s [])
    (hv : ValsTel D B ks C Γ 1 (bindParams Γ [t]) (liftMany 1 Φ) [.var 0] (Tel.shiftV 1 0 s) r e)
    (hle : Ty.LeQ D.core (bindParams Γ [t]) (liftMany 1 Φ) r (t.shiftV 1 0))
    (hc : Eff.Covers (bindParams Γ [t]) (liftMany 1 Φ) (Eff.shiftV 1 0 ε) e)
    (ha : Ty.AnnotationR D.core ks C Γ t) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e0 t ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.neg t e0) t ε σ.val := by
  have hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ([desugarExpr op .other e0].map (Comp.instR σ.val))
      ([t].map (rangeTy σ.val)) (rangeEff σ.val ε) := .cons he .nil
  have hseq := direct_sequence_core (as := [t]) (ws := [.var 0]) hh rfl hv hle hc ha rfl hR hA σ hms
  simp only [letChain] at hseq
  rw [show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity] at hseq
  simpa [ExprCore, desugarExpr, hop, sequence, CallHead.rename, CallHead.apply,
    Val.rename, Val.renameList, Surface.renameTy_add, shiftTs, boundVars] using hseq

end
end Benitoite.Release.Refinement.Surface.OpenSurface
