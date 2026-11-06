import Benitoite.Release.Refinement.Surface.OpenSurfaceBasicExpr
import Benitoite.Release.Refinement.Surface.OpenPatterns

/-! # 開いた範囲文脈の match の腕の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

abbrev ArmsCore (P : Refinement.Program) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (arms : Arms) (a b : Ty) (ε : Eff) (rs : List RangeExpr) : Prop :=
  HasTypeArmsQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (scrutObs Γ)
    (Arm.instRList rs (desugarArms op p arms)) (rangeTy rs a) (rangeTy rs b) (rangeEff rs ε) (rangeLocal rs Δ)

theorem rangeCtx_pred_sorted_none {Γ p} (h : Pred.Sorted Γ none p) (rs : List RangeExpr) :
    Pred.Sorted (rangeCtx rs Γ) none p := by
  have hm := rangeCtx_typeMap Γ rs
  have hp := h.map (self := none) (other := none) (ν := fun i => some (.var i)) hm.values hm.references
  simpa only [rangeCtx, predBind_id] using hp

theorem rangeCtx_pred_declared_none {P C Γ p} {B : Builtins} (h : Pred.Declared P C Γ none p)
    (rs : List RangeExpr) : Pred.Declared P C (rangeCtx rs Γ) none p := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    have hp := pred_ranges h (rangeAt 0 (r :: rs))
    have hp' := hp.map (Δ := rangeCtx (r :: rs) Γ) (other := none)
      (by simpa only [Ctx.declarationSelf, Option.map_none, rangeCtx] using
        (rangeCtx_normEq Γ (rangeAt 0 (r :: rs))).declaration (B := B))
    simpa only [predBind_id] using hp'

theorem rangeCtx_factsWF {P C Γ Φ} {B : Builtins} (h : FactsWF P C Γ Φ) (rs : List RangeExpr) :
    FactsWF P C (rangeCtx rs Γ) Φ := by
  intro p hp
  have hw := h p hp
  exact ⟨by simpa only [rangeCtx_length] using hw.wf,
    rangeCtx_pred_sorted_none hw.sorted rs, rangeCtx_pred_declared_none (B := B) hw.declared rs⟩

private theorem arms_range_alts {P alts a δ} (h : AltsTy P alts a δ) (hp : PatternRangesClosed P)
    (rs : List RangeExpr) : AltsTy P alts (rangeTy rs a) (δ.map (rangeTy rs)) := by
  cases rs with
  | nil => change AltsTy P alts a (δ.map id); simpa only [List.map_id] using h
  | cons r rs => exact h.instR hp (r :: rs)

private theorem arms_plain_instR (rs : List RangeExpr) (alts : List Alt) (m : Comp) (arms : List Arm) :
    Arm.instRList rs (.mk alts none m :: arms) = .mk alts none (m.instR rs) :: Arm.instRList rs arms := by cases rs <;> rfl

private theorem arms_guarded_instR (rs : List RangeExpr) (alts : List Alt) (g m : Comp) (arms : List Arm) :
    Arm.instRList rs (.mk alts (some g) m :: arms) =
      .mk alts (some (g.instR rs)) (m.instR rs) :: Arm.instRList rs arms := by cases rs <;> rfl

theorem arms_nil_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p a b ε}
    (hR : D.Realizes P) (σ : Instance ks) (hb : Ty.AnnotationR D.core ks C Γ b) :
    ArmsCore P B op Q Δ C Γ Φ R p .nil a b ε σ.val := by
  have hn : Arm.instRList σ.val [] = [] := by cases σ.val <;> rfl
  unfold ArmsCore
  rw [desugarArms, hn]
  exact .nil (annotation (B := B) (annotation_sameTypes hb hR.types) σ)

theorem arms_plain_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p alts body rest a b ε δ links}
    (hR : D.Realizes P) (σ : Instance ks) (hp : PatternRangesClosed D.core)
    (_hvalid : Alternative.Valid alts) (hal : AltsTy D.core (Alternative.toCoreList alts) a δ)
    (hlv : LinksValid (Alternative.toCoreList alts) δ.length links)
    (hfw : FactsWF D.core C (bindParams Γ δ) (fieldFacts δ.length (scrutObs Γ) links))
    (hpw : FactsWF D.core C Γ (pathFacts (scrutObs Γ)
      (matchedTests (Alternative.toCoreList alts) ++ excludedTests (Alternative.toCoreList alts))))
    (hb : BlockCore P B op Q (localExtend δ.length Δ) C (bindParams Γ δ)
      (fieldFacts δ.length (scrutObs Γ) links ++
        liftMany δ.length (pathFacts (scrutObs Γ) (matchedTests (Alternative.toCoreList alts)) ++ Φ))
      (R.map (Ty.shiftV δ.length 0)) p body (b.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) σ.val)
    (hrest : ArmsCore P B op Q Δ C Γ
      (pathFacts (scrutObs Γ) (excludedTests (Alternative.toCoreList alts)) ++ Φ) R p rest a b ε σ.val) :
    ArmsCore P B op Q Δ C Γ Φ R p (.cons alts none body rest) a b ε σ.val := by
  have hal' := (arms_range_alts hal hp σ.val).sameTypes hR.types
  have hfw' := rangeCtx_factsWF (B := B) (hfw.sameTypes hR.types) σ.val
  rw [rangeCtx_bindParams] at hfw'
  have hb' := hb
  simp only [BlockCore, rangeCtx_bindParams, rangeTy_shiftV, rangeEff_shiftV,
    rangeLocal_extend, Option.map_map, Function.comp_def] at hb'
  unfold ArmsCore
  rw [desugarArms, arms_plain_instR]
  exact .plain hal' (by simpa only [List.length_map] using hlv)
    (by simpa only [List.length_map] using hfw')
    (rangeCtx_factsWF (B := B) (hpw.sameTypes hR.types) σ.val)
    (by simpa only [List.length_map, Option.map_map, Function.comp_def] using hb') hrest

private theorem arms_bool (rs : List RangeExpr) : rangeTy rs (.base .boolean) = .base .boolean := by cases rs <;> rfl

private theorem arms_guard_annotation {D : Declarations} {P ks C Γ q} {B : Builtins}
    (hR : D.Realizes P) (hq : Ty.AnnotationR D.core ks C Γ (.refined (.base .boolean) q))
    (rs : List RangeExpr) : Ty.Annotation P C (rangeCtx rs Γ) (.refined (.base .boolean) q) := by
  refine ⟨?_, ⟨trivial, ?_⟩, ⟨trivial, ?_⟩⟩
  · simpa only [Ty.WF, rangeCtx_length] using hq.wf
  · simpa only [arms_bool] using rangeCtx_pred_sorted hq.sorted.2 rs
  · simpa only [arms_bool] using rangeCtx_pred_declared (B := B) (hq.declared.2.sameTypes hR.types) rs

theorem arms_guarded_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p alts guard body rest a b ε δ links q}
    (hR : D.Realizes P) (σ : Instance ks) (hp : PatternRangesClosed D.core)
    (_hvalid : Alternative.Valid alts) (hal : AltsTy D.core (Alternative.toCoreList alts) a δ)
    (hlv : LinksValid (Alternative.toCoreList alts) δ.length links)
    (hfw : FactsWF D.core C (bindParams Γ δ) (fieldFacts δ.length (scrutObs Γ) links))
    (hpw : FactsWF D.core C Γ (pathFacts (scrutObs Γ)
      (matchedTests (Alternative.toCoreList alts) ++ excludedTests (Alternative.toCoreList alts))))
    (hq : Ty.AnnotationR D.core ks C (hideConts (bindParams Γ δ)) (.refined (.base .boolean) q))
    (hg : ExprCore P B op Q (localExtend δ.length Δ) C (hideConts (bindParams Γ δ))
      (fieldFacts δ.length (scrutObs Γ) links ++
        liftMany δ.length (pathFacts (scrutObs Γ) (matchedTests (Alternative.toCoreList alts)) ++ Φ))
      none .other guard (.refined (.base .boolean) q) Eff.empty σ.val)
    (hb : BlockCore P B op Q (localExtend δ.length Δ) C (bindParams Γ δ)
      (q.open (.boolean true) :: (fieldFacts δ.length (scrutObs Γ) links ++
        liftMany δ.length (pathFacts (scrutObs Γ) (matchedTests (Alternative.toCoreList alts)) ++ Φ)))
      (R.map (Ty.shiftV δ.length 0)) p body (b.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) σ.val)
    (hrest : ArmsCore P B op Q Δ C Γ Φ R p rest a b ε σ.val) :
    ArmsCore P B op Q Δ C Γ Φ R p (.cons alts (some guard) body rest) a b ε σ.val := by
  have hal' := (arms_range_alts hal hp σ.val).sameTypes hR.types
  have hfw' := rangeCtx_factsWF (B := B) (hfw.sameTypes hR.types) σ.val
  rw [rangeCtx_bindParams] at hfw'
  have hq' := arms_guard_annotation (B := B) hR hq σ.val
  simp only [rangeCtx_hideConts, rangeCtx_bindParams] at hq'
  have hg' := hg
  simp only [ExprCore, rangeCtx_hideConts, rangeCtx_bindParams, rangeLocal_extend,
    Option.map_none, rangeEff_empty] at hg'
  have hg'' := HasTypeCQ.C_Sub hg' (Ty.LeQ.convert (by
    simpa only [arms_bool] using (rangeTy_refined σ.val (.base .boolean) q).symm))
    (Eff.Covers.refl _ _ _) hq'.wf hq'.sorted hq'.declared
  have hb' := hb
  simp only [BlockCore, rangeCtx_bindParams, rangeTy_shiftV, rangeEff_shiftV,
    rangeLocal_extend, Option.map_map, Function.comp_def] at hb'
  unfold ArmsCore
  rw [desugarArms, arms_guarded_instR]
  exact .guarded hal' (by simpa only [List.length_map] using hlv)
    (by simpa only [List.length_map] using hfw')
    (rangeCtx_factsWF (B := B) (hpw.sameTypes hR.types) σ.val) hq'
    (by simpa only [List.length_map] using hg'')
    (by simpa only [List.length_map, Option.map_map, Function.comp_def] using hb') hrest

end
end Benitoite.Release.Refinement.Surface.OpenSurface
