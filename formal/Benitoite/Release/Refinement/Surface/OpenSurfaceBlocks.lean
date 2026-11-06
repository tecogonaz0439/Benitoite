import Benitoite.Release.Refinement.Surface.OpenSurfaceControl

/-! # 開いた表層のブロックとreturnの型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

private theorem range_unit (rs : List RangeExpr) : rangeTy rs (.base .unit) = .base .unit := by
  cases rs <;> rfl

theorem pattern_core {D : Declarations} {P pat t δ} (hR : D.Realizes P)
    (hp : PatternRangesClosed D.core) (h : PatTy D.core pat t δ) (rs : List RangeExpr) :
    PatTy P pat (rangeTy rs t) (δ.map (rangeTy rs)) := by
  cases rs with
  | nil =>
    change PatTy P pat t (δ.map id)
    rw [List.map_id]
    exact h.sameTypes hR.types
  | cons r rs => exact (h.instR hp (r :: rs)).sameTypes hR.types

theorem view_exhaustive_core {D : Declarations} {P view a ps} (hR : D.Realizes P)
    (hp : PatternRangesClosed D.core) (h : ViewExhaustive D view a ps) (rs : List RangeExpr) :
    Exhaustive P (rangeTy rs a) ps := by
  cases rs with
  | nil => exact h.exhaustive.sameTypes hR.types
  | cons r rs => exact ((h.instR hp (r :: rs)).exhaustive.sameTypes hR.types)

/-- 必ず照合する末尾のパターン束縛を、具体化後の同じパターンで照合する。 -/
theorem lastPat_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p k pat t e ε δ}
    (hR : D.Realizes P) (σ : Instance ks) (hc : PatternRangesClosed D.core)
    (hp : PatTy D.core pat.toCore t δ) (hex : ViewExhaustive D D.view t [pat.toCore])
    (ht : Ty.AnnotationR D.core ks C Γ t) (ho : Ordinary t)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e t ε σ.val) :
    BlockCore P B op Q Δ C Γ Φ R p (.lastPat k pat t e) (.base .unit) ε σ.val := by
  have ht' := annotation (B := B) (annotation_sameTypes ht hR.types) σ
  have hp' := pattern_core hR hc hp σ.val
  have hx := (view_exhaustive_core hR hc hex σ.val).shiftV 1 0
  have hm : (desugarBlock op p (.lastPat k pat t e)).instR σ.val =
      .letIn ((desugarExpr op .other e).instR σ.val)
        (.match (.var 0) [mkArm pat.toCore (.ret (.const .unit))]) := by
    cases σ.val <;> rfl
  simp only [BlockCore, hm, range_unit]
  refine .C_Let he ?_ trivial
  simp only [mkArm]
  refine .C_Match (obs := none) (.V_Var (a := (rangeTy σ.val t).shiftV 1 0)
    (by simp only [Ctx.extend, List.getElem?_cons_zero])
    ((Ty.ordinary_shiftV _ _ _).mpr (rangeTy_ordinary ho σ.val))) (fun _ h => by cases h) ?_
    (by simpa [bindParams_single] using (ht'.under [rangeTy σ.val t]).declared) hx
  refine HasTypeArmsQ.plainEmpty (AltsTy.single (hp'.shift_values 1 0))
    (by intro q hq; cases hq) (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _))
    (.nil ⟨trivial, trivial, trivial⟩)

/-- 空のブロックは、どの範囲の具体化でも単位値を返す。 -/
theorem empty_core {P B op Q Δ C Γ Φ R p rs} :
    BlockCore P B op Q Δ C Γ Φ R p .empty (.base .unit) Eff.empty rs := by
  have he : (desugarBlock op p .empty).instR rs = .ret (.const .unit) := by cases rs <;> rfl
  simp only [BlockCore, he, range_unit, rangeEff_empty]
  exact .C_Return (.V_Const trivial)

/-- 最後の式の帰納仮定は、そのままブロックの帰納仮定になる。 -/
theorem last_core {P B op Q Δ C Γ Φ R p e a ε rs}
    (h : ExprCore P B op Q Δ C Γ Φ R p e a ε rs) :
    BlockCore P B op Q Δ C Γ Φ R p (.last e) a ε rs := h

/-- 末尾の束縛は、右辺を一度計算した後に単位値を返す。 -/
theorem lastBind_core {P B op Q Δ C Γ Φ R p k t e ε rs}
    (h : ExprCore P B op Q Δ C Γ Φ R .other e t ε rs) :
    BlockCore P B op Q Δ C Γ Φ R p (.lastBind k t e) (.base .unit) ε rs := by
  have he : (desugarBlock op p (.lastBind k t e)).instR rs =
      .letIn ((desugarExpr op .other e).instR rs) (.ret (.const .unit)) := by
    simp only [desugarBlock, comp_let_instR]
    cases rs <;> rfl
  simp only [BlockCore, he, range_unit]
  exact .C_Let h (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) trivial

/-- 末尾の破棄も、同じ右辺の計算と単位値の返却へ写す。 -/
theorem lastDiscard_core {P B op Q Δ C Γ Φ R p e t ε rs}
    (h : ExprCore P B op Q Δ C Γ Φ R .other e t ε rs) :
    BlockCore P B op Q Δ C Γ Φ R p (.lastDiscard e) (.base .unit) ε rs := by
  have hh := lastBind_core (k := BindKind.bind) (p := p) h
  simpa only [BlockCore, desugarBlock] using hh

/-- 束縛で増やした元の文脈を、同じ具体化後の値の型で増やす。 -/
theorem bind_core {D : Declarations} {P B op Q Δ C Γ Φ R p k t e rest a ε rs}
    (hR : D.Realizes P)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e t ε rs)
    (hr : BlockCore P B op Q (localExtend 1 Δ) C (Γ.extend t) (Φ.map Pred.lift)
      (R.map (Ty.shiftV 1 0)) p rest (a.shiftV 1 0) (Eff.shiftV 1 0 ε) rs)
    (hd : Ty.Declared D.core C Γ a) :
    BlockCore P B op Q Δ C Γ Φ R p (.bind k t e rest) a ε rs := by
  have hr' := hr
  simp only [BlockCore, rangeCtx_extend, rangeLocal_extend, rangeTy_shiftV, rangeEff_shiftV,
    Option.map_map, Function.comp_def] at hr'
  simp only [BlockCore, desugarBlock, comp_let_instR]
  exact .C_Let he (by simpa only [Option.map_map, Function.comp_def] using hr') (rangeCtx_declared (B := B) (hd.sameTypes hR.types) rs)

/-- 破棄する右辺の値の下へ、後続の本体を改名して移す。 -/
theorem discard_core {D : Declarations} {P B op Q Δ C Γ Φ R p e rest t a ε rs}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e t ε rs)
    (hr : BlockCore P B op Q Δ C Γ Φ R p rest a ε rs)
    (hd : Ty.Declared D.core C Γ a) :
    BlockCore P B op Q Δ C Γ Φ R p (.discard e rest) a ε rs := by
  have hr' := block_shift_core (t := t) hA hr (by simpa using facts_lift Γ Φ t [])
  simp only [BlockCore, desugarBlock, comp_let_instR]
  exact .C_Let he hr' (rangeCtx_declared (B := B) (hd.sameTypes hR.types) rs)

/-- 終了しない式文の後続を、一つ増えた核の束縛の下へ移す。 -/
theorem seq_core {D : Declarations} {P B op Q Δ C Γ Φ R p e rest a ε rs}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.base .unit) ε rs)
    (_hx : ¬ e.Exits) (hr : BlockCore P B op Q Δ C Γ Φ R p rest a ε rs)
    (hd : Ty.Declared D.core C Γ a) :
    BlockCore P B op Q Δ C Γ Φ R p (.seq e rest) a ε rs := by
  have hh := discard_core hR hA he hr hd
  simpa only [BlockCore, desugarBlock] using hh

/-- 元の部分型と被覆を、具体化したブロックの結果へ適用する。 -/
theorem block_sub_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p body a b ε ε'}
    (hR : D.Realizes P) (σ : Instance ks)
    (h : BlockCore P B op Q Δ C Γ Φ R p body a ε σ.val)
    (hle : Ty.LeQ D.core Γ Φ a b) (hc : Eff.Covers Γ Φ ε' ε)
    (ha : Ty.AnnotationR D.core ks C Γ b) :
    BlockCore P B op Q Δ C Γ Φ R p body b ε' σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hc' : Eff.Covers (rangeCtx σ.val Γ) Φ (rangeEff σ.val ε') (rangeEff σ.val ε) := by
    cases σ.val with
    | nil => exact hc
    | cons r rs => exact hc.instR (r :: rs)
  exact .C_Sub h (le_core hR hle σ.val) hc' ha'.wf ha'.sorted ha'.declared

/-- 末尾のreturnは、同じ結果型の式の帰納仮定を使う。 -/
theorem returnTail_core {P B op Q Δ C Γ Φ r a e ε rs}
    (h : ExprCore P B op Q Δ C Γ Φ (some r) .tail e r ε rs) :
    ExprCore P B op Q Δ C Γ Φ (some r) .tail (.returnE a e) r ε rs := h

/-- 末尾以外のreturnは、具体化した結果型でescapeを型付ける。 -/
theorem returnOther_core {D : Declarations} {P B ks op Q Δ C Γ Φ r a e ε}
    (hR : D.Realizes P) (σ : Instance ks) (ha : Ty.AnnotationR D.core ks C Γ a)
    (ho : Ordinary r) (he : ExprCore P B op Q Δ C Γ Φ (some r) .other e r ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ (some r) .other (.returnE a e) a ε σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hm : (Comp.escape (.var 0)).instR σ.val = .escape (.var 0) := by cases σ.val <;> rfl
  simp only [ExprCore, desugarExpr, comp_let_instR, hm]
  exact .C_Let he (.C_Escape (.V_Var (by simp [Ctx.extend])
    ((Ty.ordinary_shiftV _ _ _).mpr (rangeTy_ordinary ho σ.val)))
    (by simpa [bindParams_single] using ha'.under [rangeTy σ.val r])) ha'.declared

theorem bindPat_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p k pat t e rest a ε δ}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc : PatternRangesClosed D.core) (hp : PatTy D.core pat.toCore t δ)
    (hex : ViewExhaustive D D.view t [pat.toCore])
    (ht : Ty.AnnotationR D.core ks C Γ t) (ho : Ordinary t)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e t ε σ.val)
    (hrest : BlockCore P B op Q (localExtend δ.length Δ) C (bindParams Γ δ)
      (liftMany δ.length Φ) (R.map (Ty.shiftV δ.length 0)) p rest
      (a.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) σ.val)
    (ha : Ty.AnnotationR D.core ks C Γ a) :
    BlockCore P B op Q Δ C Γ Φ R p (.bindPat k pat t e rest) a ε σ.val := by
  have ht' := annotation (B := B) (annotation_sameTypes ht hR.types) σ
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hp' := pattern_core hR hc hp σ.val
  have hx := (view_exhaustive_core hR hc hex σ.val).shiftV 1 0
  have hbn : pat.toCore.binders = δ.length := (MatchFacts.PatTy.binders_length hp).symm
  have hm : (desugarBlock op p (.bindPat k pat t e rest)).instR σ.val =
      .letIn ((desugarExpr op .other e).instR σ.val)
        (.match (.var 0) [mkArm pat.toCore
          (((desugarBlock op p rest).instR σ.val).rename (upRen pat.toCore.binders (· + 1)))]) := by
    cases σ.val with
    | nil => rfl
    | cons r rs =>
      simp only [desugarBlock, Comp.instR, Comp.substR, Comp.mapRangesN,
        Val.mapRangesN, Arm.mapRangesListN, mkArm, ← shiftIndex_add,
        upRen_shiftIndex, OpenRangeRename.comp_mapRanges_shift]
  simp only [BlockCore, hm]
  refine .C_Let he ?_ ha'.declared
  simp only [mkArm, hbn]
  refine .C_Match (obs := none) (.V_Var (a := (rangeTy σ.val t).shiftV 1 0)
    (by simp only [Ctx.extend, List.getElem?_cons_zero])
    ((Ty.ordinary_shiftV _ _ _).mpr (rangeTy_ordinary ho σ.val))) (fun _ h => by cases h) ?_
    (by simpa [bindParams_single] using (ht'.under [rangeTy σ.val t]).declared) hx
  have hrest' := hrest
  simp only [BlockCore, rangeCtx_bindParams, rangeLocal_extend, rangeTy_shiftV,
    rangeEff_shiftV, Option.map_map, Function.comp_def] at hrest'
  have hbd := shift_arm (a := rangeTy σ.val t) (Γ := rangeCtx σ.val Γ) (Φ := Φ)
    (R := R.map (rangeTy σ.val)) (L := rangeLocal σ.val Δ)
    (b := rangeTy σ.val a) (ε := rangeEff σ.val ε) (δ := δ.map (rangeTy σ.val)) hA (by
      simpa only [List.length_map, Option.map_map, Function.comp_def] using hrest')
  have hal := AltsTy.single (hp'.shift_values 1 0)
  rw [hbn] at hal
  refine HasTypeArmsQ.plainEmpty hal (by intro q hq; cases hq) ?_
    (.nil (by simpa [bindParams_single] using ha'.under [rangeTy σ.val t]))
  simpa only [List.length_map, pathFacts, List.nil_append] using hbd

end
end Benitoite.Release.Refinement.Surface.OpenSurface
