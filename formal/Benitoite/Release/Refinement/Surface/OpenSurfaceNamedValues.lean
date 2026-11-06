import Benitoite.Release.Refinement.Surface.OpenSurfaceBasicExpr
import Benitoite.Release.Refinement.Surface.OpenSurfaceCallExpr

/-! # 辞書を伴う名前を値として使う脱糖 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem lam_instR (rs : List RangeExpr) (ns : List String) (ps : List Ty) (body : Comp) :
    (Val.lam ns ps body).instR rs = .lam ns (ps.map (rangeTy rs)) (body.instR rs) := by
  cases rs with
  | nil =>
    change Val.lam ns ps body = .lam ns (ps.map id) body
    rw [List.map_id]
  | cons r rs => rfl

theorem named_lambda_core {P B ks op Q Δ C Γ Φ R p f t ds h names ps r ε r' e'}
    {D : Declarations} (hh : CallHeadTy D B ks Q C Γ f t ds)
    (hd : directCallee f = some h) (hn : NamesWF names ps)
    (ha : Ty.AnnotationR D.core ks C Γ (.fn names ps r ε))
    (hv : ValsTel D B ks C (hideConts Γ) ps.length (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
      (ds.map (fun d => d.toVal.rename (· + ps.length)) ++ boundVars ps.length)
      (Tel.shiftV ps.length 0 t) r' e')
    (hle : Ty.LeQ D.core (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) r' (r.shiftV ps.length 0))
    (hc : Eff.Covers (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) (Eff.shiftV ps.length 0 ε) e')
    (he : desugarExpr op p f = .ret (.lam names ps ((h.rename (· + ps.length)).apply (boundVars ps.length))))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
    ExprCore P B op Q Δ C Γ Φ R p f (.fn names ps r ε) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_fn] at ha'
  have hn' : NamesWF names (ps.map (rangeTy σ.val)) := ⟨by simpa only [List.length_map] using hn.1, hn.2⟩
  have hg := hh.glue_core (R := some (r.shiftV ps.length 0)) (L := []) hd hR hA
    (ShiftMap.hideOuter Γ ps) (ShiftMap.outer (hideConts Γ) ps) hv hle hc
    (annotation_shift (annotation_fn_result ha) (ShiftMap.hideOuter Γ ps)) σ
  simp only [rangeCtx_bindParams, rangeCtx_hideConts, rangeTy_shiftV, rangeEff_shiftV,
    Option.map_some] at hg
  have hnil : rangeLocal σ.val [] = [] := by cases σ.val <;> rfl
  rw [hnil, ← hideBuilders_empty] at hg
  unfold ExprCore
  rw [he, comp_ret_instR, lam_instR, rangeTy_fn, rangeEff_empty]
  exact .C_Return (.V_Lam hn' ha'.wf ha'.sorted (by simpa only [List.length_map] using hg) ha'.declared)

theorem raise_core {P B ks op Q Δ C Γ Φ R p t e} {D : Declarations}
    (ha : Ty.AnnotationR D.core ks C Γ (.fn ["error"] [e] t (Eff.singleFail e)))
    (ht : Ordinary t) (he : Ordinary e) (hk : Ty.HasKind D.core (TypeCtx.kinds C) t .value)
    (hR : D.Realizes P) (σ : Instance ks) :
    ExprCore P B op Q Δ C Γ Φ R p (.raise t e) (.fn ["error"] [e] t (Eff.singleFail e)) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hsingle : rangeEff σ.val (Eff.singleFail e) = Eff.singleFail (rangeTy σ.val e) := by
    cases rs : σ.val with
    | nil => rfl
    | cons r rs =>
      simp only [rangeEff, rangeTy, Eff.singleFail, Eff.instR, Eff.substRAt, Eff.mapRanges,
        Eff.rawMapRanges, mapRangesTys, Eff.norm, Ty.normTys, Ty.instR, Ty.substRAt, Ty.mapRanges]
      congr 1
      · funext a; simp [mapRangeAtoms]
      · simp only [Ty.norm_rawMapRanges, Ty.norm_idem, Order.sortUnique_singleton]
  rw [rangeTy_fn, hsingle] at ha'
  have hk' : Ty.HasKind P (TypeCtx.kinds C) (rangeTy σ.val t) .value := by
    cases σ.val with
    | nil => exact hk.sameTypes hR.types
    | cons r rs => exact ((hk.sameTypes hR.types).rawMapRanges _).norm
  have hv := HasTypeVQ.V_Raise (B := B) (Ψ := StoreTy.empty) (Q := Q) (Φ := Φ) ha'
    (rangeTy_ordinary ht σ.val) (rangeTy_ordinary he σ.val) hk'
  have hm : (Val.raise t e).instR σ.val = .raise (rangeTy σ.val t) (rangeTy σ.val e) := by
    cases σ.val <;> rfl
  unfold ExprCore
  rw [desugarExpr, comp_ret_instR, hm, rangeTy_fn, hsingle, rangeEff_empty]
  exact .C_Return hv

end
end Benitoite.Release.Refinement.Surface.OpenSurface
