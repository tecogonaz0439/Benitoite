import Benitoite.Release.Refinement.Surface.OpenSurfaceBlocks
import Benitoite.Release.Refinement.Surface.OpenSurfaceCollections

/-! # 開いた表層の構築器の局所宣言 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

/-- 構築器の要素の型を、呼出し元の範囲で具体化する。 -/
def rangeBuilder (rs : List RangeExpr) (k : BuilderKind) : BuilderKind :=
  match rs with | [] => k | _ => BuilderKind.mapRangesN (rangeAt 0 rs) k

theorem rangeBuilder_contents (rs : List RangeExpr) (k : BuilderKind) :
    (rangeBuilder rs k).contents = rangeTy rs k.contents := by
  cases rs <;> cases k <;> rfl

theorem rangeCtx_extendNone (rs : List RangeExpr) (Γ : Ctx) :
    rangeCtx rs Γ.extendNone = (rangeCtx rs Γ).extendNone := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeCtx, Ctx.extendNone, Ctx.mapRanges, List.map_cons, Option.map_none,
      List.map_map, Option.map_map, Function.comp_def]
    congr 2
    funext x
    cases x with
    | none => rfl
    | some a => exact congrArg some (rangeTy_shiftV (r :: rs) a 1 0)

theorem rangeLocal_kind (rs : List RangeExpr) (Δ : LocalCtx) (k : BuilderKind) :
    rangeLocal rs (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) Δ) =
      LocalCtx.extend (some (renameKind (shiftIndex 1 0) (rangeBuilder rs k))) (rangeLocal rs Δ) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeLocal, LocalCtx.extend, List.map_cons, Option.map_some, List.map_map,
      Option.map_map, Function.comp_def, rangeBuilder]
    rw [OpenRangeRename.kind_mapRanges_shift]
    congr 1
    apply List.map_congr_left
    intro x _
    cases x with
    | none => rfl
    | some b => exact congrArg some (OpenRangeRename.kind_mapRanges_shift b _ 1 0)

/-- 構築器を束縛して隠した通常値の位置も、同じ範囲の具体化で保つ。 -/
theorem builderBind_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p k rest a ε}
    (hR : D.Realizes P) (σ : Instance ks)
    (ha : Ty.AnnotationR D.core ks C Γ k.contents)
    (hk : TypeArgsKinded D.core C [k.contents] [.value])
    (hr : BlockCore P B op Q (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) Δ) C Γ.extendNone
      (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p rest (a.shiftV 1 0) (Eff.shiftV 1 0 ε) σ.val)
    (hd : Ty.Declared D.core C Γ a) :
    BlockCore P B op Q Δ C Γ Φ R p (.builderBind k rest) a ε σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hk' : TypeArgsKinded P C [(rangeBuilder σ.val k).contents] [.value] := by
    rw [rangeBuilder_contents]
    cases hs : σ.val with
    | nil => exact hk.sameTypes hR.types
    | cons r rs =>
      have h0 := (hk.sameTypes hR.types).2 0 k.contents .value rfl rfl
      refine ⟨rfl, ?_⟩
      intro i a kind hi hj
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at hi hj
        subst a; subst kind
        exact ⟨(h0.1.rawMapRanges (rangeAt 0 (r :: rs))).norm,
          fun _ => rangeTy_ordinary (h0.2 rfl) (r :: rs)⟩
      | succ i => simp at hi
  have hr' := hr
  simp only [BlockCore, rangeCtx_extendNone, rangeLocal_kind, rangeTy_shiftV, rangeEff_shiftV,
    Option.map_map, Function.comp_def] at hr'
  have hm : (desugarBlock op p (.builderBind k rest)).instR σ.val =
      .builderLet (rangeBuilder σ.val k) ((desugarBlock op p rest).instR σ.val) := by
    cases σ.val <;> rfl
  simp only [BlockCore, hm]
  exact .C_BuilderLet (by simpa only [rangeBuilder_contents] using ha') hk'
    (by simpa only [Option.map_map, Function.comp_def] using hr')
    (rangeCtx_declared (B := B) (hd.sameTypes hR.types) σ.val)

theorem rangeBuilder_rename (rs : List RangeExpr) (k : BuilderKind) (n c : Nat) :
    rangeBuilder rs (renameKind (shiftIndex n c) k) =
      renameKind (shiftIndex n c) (rangeBuilder rs k) := by
  cases rs with
  | nil => rfl
  | cons r rs => exact OpenRangeRename.kind_mapRanges_shift k _ n c

theorem rangeBuilder_parameters (rs : List RangeExpr) (op : BuilderOp) (k : BuilderKind) :
    (op.parameters k).map (rangeTy rs) = op.parameters (rangeBuilder rs k) := by
  cases rs <;> cases op <;> cases k <;> rfl

theorem rangeBuilder_result (rs : List RangeExpr) (op : BuilderOp) (k : BuilderKind) :
    rangeTy rs (op.resultType k) = op.resultType (rangeBuilder rs k) := by
  cases rs <;> cases op <;> cases k <;> rfl

theorem rangeLocal_lookup {Δ : LocalCtx} {i : Nat} {k : BuilderKind} (hi : Δ[i]? = some (some k))
    (rs : List RangeExpr) : (rangeLocal rs Δ)[i]? = some (some (rangeBuilder rs k)) := by
  cases rs with
  | nil => exact hi
  | cons r rs => simp only [rangeLocal, List.getElem?_map, hi, Option.map_some, rangeBuilder]

private theorem builderOp_instR (rs : List RangeExpr) (op : BuilderOp) (k : BuilderKind)
    (i : Nat) (vs : List Val) :
    (Comp.builderOp k op (.bound i) vs).instR rs =
      .builderOp (rangeBuilder rs k) op (.bound i) (vs.map (Val.instR rs)) := by
  cases rs with
  | nil => change Comp.builderOp k op (.bound i) vs = .builderOp k op (.bound i) (vs.map id); rw [List.map_id]
  | cons r rs =>
    change Comp.builderOp _ op (.bound i) (Val.mapRangesListN _ vs) = _
    congr 1
    induction vs <;> simp_all [Val.mapRangesListN, Val.instR, Val.substR]

/-- 構築器の操作の通常引数を具体化してから、同じ専用位置の操作へ渡す。 -/
theorem builderOp_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p bop i args kind as ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hi : Δ[i]? = some (some kind)) (ha : Ty.AnnotationR D.core ks C Γ kind.contents)
    (hk : TypeArgsKinded D.core C [kind.contents] [.value])
    (hvals : ValsTys D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (boundVars as.length) (bop.parameters (renameKind (· + as.length) kind)))
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ) ((desugarExprs op args).map (Comp.instR σ.val))
      (as.map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    ExprCore P B op Q Δ C Γ Φ R p (.builderOp bop i args kind) (bop.resultType kind) ε σ.val := by
  have hl : (desugarExprs op args).length = as.length := by simpa only [List.length_map] using hms.length
  simp only [ExprCore, desugarExpr, sequence, hl]
  apply sequence_instR hA hms
  · have hren : renameKind (fun x => x + as.length) kind = renameKind (shiftIndex as.length 0) kind := by rw [shiftIndex_add]
    rw [hren, builderOp_instR, collection_boundVars_instR, rangeBuilder_rename, rangeTy_shiftV,
      rangeBuilder_result, ← BuilderOp.resultType_rename]
    have ha' := (annotation (B := B) (annotation_sameTypes ha hR.types) σ).under (as.map (rangeTy σ.val))
    have hk' := (range_types_kinded (hk.sameTypes hR.types) σ.val).shift as.length 0
    have hv := hvals.core (Q := Q) hR hA (FullShiftMap.outer Γ as).values σ
    rw [collection_boundVars_instR, rangeBuilder_parameters, hren, rangeBuilder_rename] at hv
    refine .C_Eff (.C_BuilderOp ?_ ?_ ?_ hv) (Eff.covers_empty _ _ _)
    · simpa only [rangeCtx_bindParams, BuilderKind.contents_rename, rangeBuilder_contents, List.length_map] using ha'
    · simpa only [List.map_cons, List.map_nil, BuilderKind.contents_rename, rangeBuilder_contents] using hk'
    · exact .bound (LocalCtx.Shift.outer as.length (rangeLocal σ.val Δ) i (rangeBuilder σ.val kind)
        (rangeLocal_lookup hi σ.val) |>.trans (by simp))
  · cases bop <;> simp only [BuilderOp.resultType, Ty.Declared] <;> exact ha.declared.sameTypes hR.types

end
end Benitoite.Release.Refinement.Surface.OpenSurface
