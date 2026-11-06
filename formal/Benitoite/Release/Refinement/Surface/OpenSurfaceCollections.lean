import Benitoite.Release.Refinement.Surface.OpenSurfaceSequence
import Benitoite.Release.Refinement.Surface.OpenSurfaceValues

/-! # 開いたリストの脱糖の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem collection_list_instR (rs : List RangeExpr) (vs : List Val) :
    (Val.list vs).instR rs = .list (vs.map (Val.instR rs)) := by
  cases rs with
  | nil => change Val.list vs = .list (vs.map id); rw [List.map_id]
  | cons r rs =>
    change Val.list (Val.mapRangesListN _ vs) = .list _
    congr 1
    induction vs <;> simp_all [Val.mapRangesListN, Val.instR, Val.substR]

theorem collection_boundVars_instR (rs : List RangeExpr) (n : Nat) :
    (boundVars n).map (Val.instR rs) = boundVars n := by
  simp only [boundVars, List.map_map, Function.comp_def, val_var_instR]

/-- E-List の子の計算と、束縛した各要素の型付けからリストの計算を作る。 -/
theorem list_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p a es as ε}
    (ha : Ty.AnnotationR D.core ks C Γ a) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op es).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε))
    (hvs : HasTypeEachQ P B StoreTy.empty Q C (rangeCtx σ.val (bindParams Γ as))
      (liftMany as.length Φ) ((boundVars as.length).map (Val.instR σ.val))
      (rangeTy σ.val (a.shiftV as.length 0))) :
    ExprCore P B op Q Δ C Γ Φ R p (.list a es) (.list a) ε σ.val := by
  have hl : (desugarExprs op es).length = as.length := by
    simpa only [List.length_map] using hms.length
  have ha' := (annotation (B := B) (annotation_sameTypes ha hR.types) σ).under
    (as.map (rangeTy σ.val))
  have hau : Ty.Annotation P C (rangeCtx σ.val (bindParams Γ as))
      (rangeTy σ.val (a.shiftV as.length 0)) := by
    simpa only [rangeCtx_bindParams, List.length_map, rangeTy_shiftV] using ha'
  unfold ExprCore
  simp only [desugarExpr, sequence, hl]
  apply sequence_instR hA hms
  · rw [comp_ret_instR, collection_list_instR]
    simp only [rangeTy_shiftV, rangeTy_list, Ty.shiftV]
    simp only [rangeTy_shiftV] at hvs hau
    exact .C_Eff (.C_Return (.V_List hvs hau.wf hau.sorted hau.declared))
      (Eff.covers_empty _ _ _)
  · exact ha.declared.sameTypes hR.types

/-- E-ListRefined の元の述語の導出を保ち、具体化した各要素から篩付きリストを作る。 -/
theorem listRefined_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p a es as q ε}
    (ha : Ty.AnnotationR D.core ks C Γ (.refined (.list a) q))
    (hent : Entails ((bindParams Γ as).facts ++ liftMany as.length Φ)
      ((liftRef as.length q).open (.listValue (Val.toTermSlots (boundVars as.length)))))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op es).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε))
    (hvs : HasTypeEachQ P B StoreTy.empty Q C (rangeCtx σ.val (bindParams Γ as))
      (liftMany as.length Φ) ((boundVars as.length).map (Val.instR σ.val))
      (rangeTy σ.val (a.shiftV as.length 0))) :
    ExprCore P B op Q Δ C Γ Φ R p (.list a es) (.refined (.list a) q) ε σ.val := by
  have hl : (desugarExprs op es).length = as.length := by
    simpa only [List.length_map] using hms.length
  have hlist : Ty.AnnotationR D.core ks C Γ (.list a) :=
    ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩
  have hli := annotation (B := B) (annotation_sameTypes hlist hR.types) σ
  rw [rangeTy_list] at hli
  have hraw : Ty.Annotation P C (rangeCtx σ.val Γ) (.refined (.list (rangeTy σ.val a)) q) := by
    refine ⟨⟨hli.wf, ?_, by intro b t e h; cases h⟩, ⟨hli.sorted, ?_⟩, ⟨hli.declared, ?_⟩⟩
    · simpa only [rangeCtx_length] using ha.wf.2.1
    · simpa only [rangeTy_list] using rangeCtx_pred_sorted ha.sorted.2 σ.val
    · simpa only [rangeTy_list] using
        rangeCtx_pred_declared (B := B) (ha.declared.2.sameTypes hR.types) σ.val
  have hraw' := hraw.under (as.map (rangeTy σ.val))
  have hout := (annotation (B := B) (annotation_sameTypes ha hR.types) σ).under
    (as.map (rangeTy σ.val))
  rw [List.length_map, shiftV_refined] at hraw'
  have hc : rangeCtx σ.val (bindParams Γ as) =
      bindParams (rangeCtx σ.val Γ) (as.map (rangeTy σ.val)) := rangeCtx_bindParams _ _ _
  rw [← hc] at hraw' hout
  simp only [List.length_map] at hout
  have he : Entails ((rangeCtx σ.val (bindParams Γ as)).facts ++ liftMany as.length Φ)
      ((liftRef as.length q).open (.listValue (Val.toTermSlots (boundVars as.length)))) := by
    simpa only [rangeCtx_facts] using hent
  unfold ExprCore
  simp only [desugarExpr, sequence, hl]
  apply sequence_instR hA hms
  · rw [comp_ret_instR, collection_list_instR, collection_boundVars_instR]
    simp only [rangeTy_shiftV]
    simp only [collection_boundVars_instR, rangeTy_shiftV] at hvs
    have hv := HasTypeVQ.V_List hvs hraw'.wf.1 hraw'.sorted.1 hraw'.declared.1
    have href := HasTypeVQ.V_Refine (sort := .list) hv rfl rfl
      hraw'.sorted.2 hraw'.wf.2.1 he hraw'.declared.1 hraw'.declared.2
    have hnorm : (Ty.refined (.list (rangeTy σ.val a)) q).norm =
        (rangeTy σ.val (.refined (.list a) q)).norm := by
      simpa only [rangeTy_list] using rangeTy_refined σ.val (.list a) q
    apply HasTypeCQ.C_Eff (ε := Eff.empty)
    · apply HasTypeCQ.C_Return
      apply HasTypeVQ.V_Sub href (.convert ?_) hout.wf hout.sorted hout.declared
      have hs : (Ty.list (rangeTy σ.val a)).shiftV as.length 0 =
          .list ((rangeTy σ.val a).shiftV as.length 0) := rfl
      simpa only [← Ty.norm_shiftV, shiftV_refined, hs] using
        congrArg (Ty.shiftV as.length 0) hnorm
    · exact Eff.covers_empty _ _ _
  · exact ha.declared.sameTypes hR.types

theorem list_source_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p a es as ε}
    (ha : Ty.AnnotationR D.core ks C Γ a)
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (boundVars as.length) (List.replicate as.length (a.shiftV as.length 0)))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op es).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.list a es) (.list a) ε σ.val :=
  list_core ha hR hA σ hms (hvals.each hR hA (FullShiftMap.outer Γ as).values σ)

theorem listRefined_source_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p a es as q ε}
    (ha : Ty.AnnotationR D.core ks C Γ (.refined (.list a) q))
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (boundVars as.length) (List.replicate as.length (a.shiftV as.length 0)))
    (hent : Entails ((bindParams Γ as).facts ++ liftMany as.length Φ)
      ((liftRef as.length q).open (.listValue (Val.toTermSlots (boundVars as.length)))))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op es).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.list a es) (.refined (.list a) q) ε σ.val :=
  listRefined_core ha hent hR hA σ hms (hvals.each hR hA (FullShiftMap.outer Γ as).values σ)

end
end Benitoite.Release.Refinement.Surface.OpenSurface
