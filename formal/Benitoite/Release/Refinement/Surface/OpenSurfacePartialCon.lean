import Benitoite.Release.Refinement.Surface.OpenSurfacePartial

/-! # 開いた構成子の部分適用の型の保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem partialCon_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p c cd ts args r ε as}
    (hc : D.cons c = some cd) (hn : ts.length = cd.ntys)
    (hnames : NamesWF (args.holeNames (positionalNames args.positions.length)) args.holeTypes)
    (hk : TypeArgsKinded D.core C ts (List.replicate cd.ntys .value))
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0) (hclosed : ∀ a ∈ cd.args, a.RangesScoped 0)
    (hda : Ty.AnnotationR D.core ks C Γ (.data cd.data ts))
    (ha : Ty.AnnotationR D.core ks C Γ
      (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r ε))
    (hvals : ValsTys D B ks C Γ (args.holeTypes.length + as.length)
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ)) (args.argVals as.length)
      (cd.args.map (Ty.subst (shiftTs (args.holeTypes.length + as.length) ts) [])))
    (hle : Ty.LeQ D.core
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ))
      (.data cd.data (shiftTs (args.holeTypes.length + as.length) ts))
      (r.shiftV (args.holeTypes.length + as.length) 0))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hfx : FixedCore P B op Q C (hideConts Γ) Φ (some r) args as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.partialCon c ts args)
      (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r ε) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_fn] at ha'
  have hcs := partial_fixed_shift (ps := args.holeTypes) hA hfx
  have hl := partial_fixed_length hfx
  have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
    (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
  rw [List.length_map] at hm
  have hrA := annotation (B := B) (annotation_sameTypes (annotation_shift (annotation_fn_result ha) hm) hR.types) σ
  have hdA := annotation (B := B) (annotation_sameTypes (annotation_shift hda hm) hR.types) σ
  have hdata : (.data cd.data ts : Ty).shiftV (args.holeTypes.length + as.length) 0 =
      .data cd.data (shiftTs (args.holeTypes.length + as.length) ts) := by
    simp only [Ty.shiftV, shiftVTys_eq_map, shiftTs]
  rw [hdata] at hdA
  have hcon := constructor_at_core (Q := Q) hc (by simpa only [shiftTs, List.length_map] using hn)
    (hk.shift (args.holeTypes.length + as.length) 0) hw hclosed hvals hR hA hm σ hdA
  have hfinish := HasTypeCQ.C_Eff
    (R := some (rangeTy σ.val ((r.shiftV args.holeTypes.length 0).shiftV as.length 0)))
    (Δ := localExtend as.length [])
    (ε' := rangeEff σ.val (Eff.shiftV as.length 0 (Eff.shiftV args.holeTypes.length 0 ε)))
    (.C_Return (.V_Sub hcon (le_core hR hle σ.val) hrA.wf hrA.sorted hrA.declared)) (Eff.covers_empty _ _ _)
  have hr0 := annotation_shift (annotation_fn_result ha) (ShiftMap.hideOuter Γ args.holeTypes)
  have hbody : HasTypeCQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (hideConts Γ) args.holeTypes))
      (liftMany args.holeTypes.length Φ) (some (rangeTy σ.val (r.shiftV args.holeTypes.length 0)))
      ((sequenceArgs 0 (desugarHoleArgs op args.holeTypes.length args)
        (fun vs => .ret (.con c
          (shiftTs (args.holeTypes.length + (argEvals (desugarHoleArgs op args.holeTypes.length args)).length) ts) vs))).instR σ.val)
      (rangeTy σ.val (r.shiftV args.holeTypes.length 0))
      (rangeEff σ.val (Eff.shiftV args.holeTypes.length 0 ε)) [] := by
    simp only [sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs, List.length_map, hl, Nat.zero_add]
    rw [← rangeLocal_nil σ.val] at hcs ⊢
    apply sequence_instR hA hcs
    · rw [comp_ret_instR]
      simpa only [List.length_map, Ty.shiftV_add, Eff.shiftV_add, Option.map_some, rangeLocal_nil, shiftTs] using hfinish
    · exact hr0.declared.sameTypes hR.types
  simp only [rangeCtx_bindParams, rangeCtx_hideConts, rangeTy_shiftV, rangeEff_shiftV] at hbody
  simp only [ExprCore, desugarExpr, comp_ret_instR, lam_instR, rangeTy_fn, rangeEff_empty]
  refine .C_Return (.V_Lam ⟨by simpa only [List.length_map] using hnames.1, hnames.2⟩
    ha'.wf ha'.sorted ?_ ha'.declared)
  rw [hideBuilders_empty]
  simpa only [List.length_map] using hbody

end
end Benitoite.Release.Refinement.Surface.OpenSurface
