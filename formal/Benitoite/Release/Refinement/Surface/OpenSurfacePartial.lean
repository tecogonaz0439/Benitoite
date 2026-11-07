import Benitoite.Release.Refinement.Surface.OpenSurfaceNamedValues
import Benitoite.Release.Refinement.Surface.OpenSurfaceConstructors
import Benitoite.Release.Refinement.Surface.Property1Partial

/-! # 開いた部分適用の脱糖の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

abbrev FixedCore (P : Refinement.Program) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (args : HoleArgs)
    (as : List Ty) (ε : Eff) (rs : List RangeExpr) : Prop :=
  Surface.CompsTy P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) []
    ((fixedComps op args).map (Comp.instR rs)) (as.map (rangeTy rs)) (rangeEff rs ε)

theorem partial_fixed_length {P B op Q C Γ Φ R args as ε rs}
    (h : FixedCore P B op Q C Γ Φ R args as ε rs) : (fixedComps op args).length = as.length := by
  simpa only [List.length_map] using h.length

theorem partial_fixed_shift {P B Q C Γ Φ ε rs} {R : Option Ty} {ms : List Comp} {as ps : List Ty}
    (hA : Builtins.ValueAssumptions P B)
    (h : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) []
      (ms.map (Comp.instR rs)) (as.map (rangeTy rs)) (rangeEff rs ε)) :
    Surface.CompsTy P B StoreTy.empty Q C (rangeCtx rs (bindParams Γ ps)) (liftMany ps.length Φ)
      ((R.map (Ty.shiftV ps.length 0)).map (rangeTy rs)) []
      ((ms.map (Comp.rename (· + ps.length))).map (Comp.instR rs))
      ((as.map (Ty.shiftV ps.length 0)).map (rangeTy rs)) (rangeEff rs (Eff.shiftV ps.length 0 ε)) := by
  have hh := h.shiftParams hA (ps.map (rangeTy rs))
  simpa only [rangeCtx_bindParams, List.length_map, rangeTy_shiftV, rangeEff_shiftV,
    List.map_map, Function.comp_def, Option.map_map, ← shiftIndex_add,
    OpenRangeRename.comp_instR_shift] using hh

theorem partialCallDirect_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p f names args r ε t ds as r' e'}
    (hholes : args.holeTypes ≠ [])
    (hh : CallHeadTy D B ks Q C Γ f t ds)
    (hn : NamesWF (args.holeNames names) args.holeTypes)
    (ha : Ty.AnnotationR D.core ks C Γ (.fn (args.holeNames names) args.holeTypes r ε))
    (hv : ValsTel D B ks C Γ (args.holeTypes.length + as.length)
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ))
      (ds.map (fun d => d.toVal.rename (· + (args.holeTypes.length + as.length))) ++
        recordFields args.positions.length args.positions (args.argVals as.length) (.const .unit))
      (Tel.shiftV (args.holeTypes.length + as.length) 0 t) r' e')
    (hle : Ty.LeQ D.core
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ)) r' (r.shiftV (args.holeTypes.length + as.length) 0))
    (hc : Eff.Covers
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ))
      (Eff.shiftV (args.holeTypes.length + as.length) 0 ε) e')
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hfx : FixedCore P B op Q C (hideConts Γ) Φ (some r) args as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p
      (.partialCall f names args (r.shiftV args.holeTypes.length 0) (Eff.shiftV args.holeTypes.length 0 ε))
      (.fn (args.holeNames names) args.holeTypes r ε) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_fn] at ha'
  obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
  have hcs := partial_fixed_shift (ps := args.holeTypes) hA hfx
  have hl := partial_fixed_length hfx
  have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
    (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
  rw [List.length_map] at hm
  have hrA := annotation_shift (annotation_fn_result ha) hm
  have hg := hh.glue_core
    (R := some ((r.shiftV args.holeTypes.length 0).shiftV as.length 0))
    (L := localExtend as.length []) hd hR hA hm hm hv hle hc hrA σ
  have hnil : rangeLocal σ.val [] = [] := by cases σ.val <;> rfl
  rw [rangeLocal_extend, hnil] at hg
  have hr0 := annotation_shift (annotation_fn_result ha) (ShiftMap.hideOuter Γ args.holeTypes)
  have hbody : HasTypeCQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (hideConts Γ) args.holeTypes))
      (liftMany args.holeTypes.length Φ) (some (rangeTy σ.val (r.shiftV args.holeTypes.length 0)))
      ((callArgs args.holeTypes.length f (desugarExpr op .other f) args.positions
        (desugarHoleArgs op args.holeTypes.length args)).instR σ.val)
      (rangeTy σ.val (r.shiftV args.holeTypes.length 0))
      (rangeEff σ.val (Eff.shiftV args.holeTypes.length 0 ε)) [] := by
    simp only [callArgs, hd, sequenceArgs, argEvals_desugarHoleArgs,
      argValues_desugarHoleArgs, List.length_map, hl, Nat.zero_add]
    rw [← hnil] at hcs ⊢
    apply sequence_instR hA hcs
    · simpa only [List.length_map, Ty.shiftV_add, Eff.shiftV_add, Option.map_some, hnil] using hg
    · exact hr0.declared.sameTypes hR.types
  simp only [rangeCtx_bindParams, rangeCtx_hideConts, rangeTy_shiftV, rangeEff_shiftV] at hbody
  simp only [ExprCore, desugarExpr, hholes, ite_false, holeLam_shift, comp_ret_instR, lam_instR,
    rangeTy_fn, rangeEff_empty]
  refine .C_Return (.V_Lam ⟨by simpa only [List.length_map] using hn.1, hn.2⟩
    ha'.wf ha'.sorted ?_ ha'.declared)
  rw [hideBuilders_empty]
  simpa only [List.length_map] using hbody

theorem dependent_annotation {P ks C Γ t} {B : Builtins}
    (h : Ty.AnnotationR P ks C Γ (.dependentFn t)) (σ : Instance ks) :
    Ty.Annotation P C (rangeCtx σ.val Γ) (.dependentFn (rangeTel σ.val t)) := by
  cases t with
  | done r e =>
    have hh : Ty.AnnotationR P ks C Γ (.fn [] [] r e) :=
      ⟨⟨⟨rfl, by simp⟩, trivial, h.wf⟩, ⟨trivial, h.sorted⟩, ⟨trivial, h.declared⟩⟩
    have hx := annotation (B := B) hh σ
    rw [rangeTy_fn] at hx
    rw [rangeTel_done]
    exact ⟨hx.wf.2.2, hx.sorted.2, hx.declared.2⟩
  | param n a t =>
    have ha : Ty.AnnotationR P ks C Γ a := ⟨h.wf.1, h.sorted.1, h.declared.1⟩
    have ht : Ty.AnnotationR P ks C (Γ.extend a) (.dependentFn t) :=
      ⟨by simpa only [Ty.WF, Ctx.extend, List.length_cons, List.length_map] using h.wf.2, h.sorted.2, h.declared.2⟩
    have ha' := annotation (B := B) ha σ
    have ht' := dependent_annotation (B := B) ht σ
    rw [rangeCtx_extend] at ht'
    rw [rangeTel_param]
    exact ⟨⟨ha'.wf, by simpa only [Ty.WF, rangeCtx_length, Ctx.extend, List.length_cons, List.length_map] using ht'.wf⟩,
      ⟨ha'.sorted, ht'.sorted⟩, ⟨ha'.declared, ht'.declared⟩⟩

termination_by t

theorem rangeTel_holeTel (rs : List RangeExpr) (ns : List String) (ps : List Ty)
    (i : Nat) (r : Ty) (e : Eff) :
    rangeTel rs (holeTel ns ps i r e) = holeTel ns (ps.map (rangeTy rs)) i (rangeTy rs r) (rangeEff rs e) := by
  induction ns generalizing ps i with
  | nil => simp only [holeTel, rangeTel_done]
  | cons n ns ih =>
    cases ps with
    | nil => simp only [holeTel, List.map_nil, rangeTel_done]
    | cons a ps => simp only [holeTel, List.map_cons, rangeTel_param, rangeTy_shiftV, ih]

theorem dependentLam_instR (rs : List RangeExpr) (t : Tel) (body : Comp) :
    (Val.dependentLam t body).instR rs = .dependentLam (rangeTel rs t) (body.instR rs) := by
  cases rs <;> rfl

theorem partialCallDirectDep_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p f names args ret eff εf t ds as r' e'}
    (hholes : args.holeTypes ≠ [])
    (hh : CallHeadTy D B ks Q C Γ f t ds)
    (hn : NamesWF (args.holeNames names) args.holeTypes)
    (hdep : ¬ ∃ (r0 : Ty) (e0 : Eff), ret = r0.shiftV args.holeTypes.length 0 ∧
      eff = Eff.shiftV args.holeTypes.length 0 e0)
    (ha : Ty.AnnotationR D.core ks C Γ (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)))
    (hret : Ty.AnnotationR D.core ks C (bindParams (hideConts Γ) args.holeTypes) ret)
    (hcov : Eff.Covers (bindParams (hideConts Γ) args.holeTypes) (liftMany args.holeTypes.length Φ)
      eff (Eff.shiftV args.holeTypes.length 0 εf))
    (hv : ValsTel D B ks C Γ (args.holeTypes.length + as.length)
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ))
      (ds.map (fun d => d.toVal.rename (· + (args.holeTypes.length + as.length))) ++
        recordFields args.positions.length args.positions (args.argVals as.length) (.const .unit))
      (Tel.shiftV (args.holeTypes.length + as.length) 0 t) r' e')
    (hle : Ty.LeQ D.core
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ)) r' (ret.shiftV as.length 0))
    (hc : Eff.Covers
      (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany as.length (liftMany args.holeTypes.length Φ))
      (Eff.shiftV as.length 0 eff) e')
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hfx : FixedCore P B op Q C (hideConts Γ) Φ none args as εf σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p
      (.partialCall f names args ret eff)
      (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) Eff.empty σ.val := by
  have ha' := dependent_annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hret' := annotation (B := B) (annotation_sameTypes hret hR.types) σ
  obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
  have hcs := (partial_fixed_shift (ps := args.holeTypes) hA hfx).retarget
    ((OpenBody.Covers.source hcov).at σ) (some (rangeTy σ.val ret))
  have hl := partial_fixed_length hfx
  have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
    (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
  rw [List.length_map] at hm
  have hrA := annotation_under hret (as.map (Ty.shiftV args.holeTypes.length 0))
  rw [List.length_map] at hrA
  have hg := hh.glue_core (R := some (ret.shiftV as.length 0))
    (L := localExtend as.length []) hd hR hA hm hm hv hle hc hrA σ
  rw [rangeLocal_extend, rangeLocal_nil] at hg
  have hbody : HasTypeCQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (hideConts Γ) args.holeTypes))
      (liftMany args.holeTypes.length Φ) (some (rangeTy σ.val ret))
      ((callArgs args.holeTypes.length f (desugarExpr op .other f) args.positions
        (desugarHoleArgs op args.holeTypes.length args)).instR σ.val)
      (rangeTy σ.val ret) (rangeEff σ.val eff) [] := by
    simp only [callArgs, hd, sequenceArgs, argEvals_desugarHoleArgs,
      argValues_desugarHoleArgs, List.length_map, hl, Nat.zero_add]
    rw [← rangeLocal_nil σ.val] at hcs ⊢
    apply sequence_instR (R := some ret) hA hcs
    · simpa only [List.length_map, Option.map_some, rangeLocal_nil] using hg
    · exact hret.declared.sameTypes hR.types
  simp only [ExprCore, desugarExpr, hholes, ite_false, holeLam_dependent hdep, comp_ret_instR, rangeEff_empty]
  apply HasTypeCQ.C_Return
  rw [dependentLam_instR]
  apply dependentFn_range_type
  refine .V_DependentLam ha' ?_
  rw [hideBuilders_empty, rangeTel_holeTel]
  have ht := holeTel_body (Γ0 := hideConts (rangeCtx σ.val Γ)) (Φ := Φ) []
    (args.holeNames names) (args.holeTypes.map (rangeTy σ.val))
    (by simpa only [List.length_map] using hn.1)
    (r := rangeTy σ.val ret) (e := rangeEff σ.val eff) (by
      simpa only [rangeCtx_bindParams, rangeCtx_hideConts, List.length_map, bindParams_nil, List.nil_append,
        List.length_nil, Nat.zero_add] using hbody)
  simpa only [bindParams_nil, List.length_nil, (show liftMany 0 Φ = Φ from rfl)] using ht

theorem partial_indirect_body_core {D : Declarations} {P B ks op Q C Γ Φ f args b ε t as r' e'}
    (hnd : directCallee f = none)
    (ha : Ty.AnnotationR D.core ks C (bindParams (hideConts Γ) args.holeTypes) b)
    (hv : ValsTel D B ks C Γ (args.holeTypes.length + (as.length + 1))
      (bindParams (bindParams (hideConts Γ) args.holeTypes)
        ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
      (recordFields args.positions.length args.positions (args.argVals (as.length + 1)) (.const .unit))
      (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t) r' e')
    (hle : Ty.LeQ D.core
      (bindParams (bindParams (hideConts Γ) args.holeTypes)
        ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) r' (b.shiftV (as.length + 1) 0))
    (hc : Eff.Covers
      (bindParams (bindParams (hideConts Γ) args.holeTypes)
        ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) (Eff.shiftV (as.length + 1) 0 ε) e')
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hff : HasTypeCQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (hideConts Γ) args.holeTypes)) (liftMany args.holeTypes.length Φ)
      (some (rangeTy σ.val b))
      (((desugarExpr op .other f).rename (· + args.holeTypes.length)).instR σ.val)
      (rangeTy σ.val ((Ty.dependentFn t).shiftV args.holeTypes.length 0)) (rangeEff σ.val ε) [])
    (hcs : Surface.CompsTy P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (hideConts Γ) args.holeTypes)) (liftMany args.holeTypes.length Φ)
      (some (rangeTy σ.val b)) []
      (((fixedComps op args).map (Comp.rename (· + args.holeTypes.length))).map (Comp.instR σ.val))
      ((as.map (Ty.shiftV args.holeTypes.length 0)).map (rangeTy σ.val)) (rangeEff σ.val ε)) :
    HasTypeCQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (hideConts Γ) args.holeTypes)) (liftMany args.holeTypes.length Φ)
      (some (rangeTy σ.val b))
      ((callArgs args.holeTypes.length f (desugarExpr op .other f) args.positions
        (desugarHoleArgs op args.holeTypes.length args)).instR σ.val)
      (rangeTy σ.val b) (rangeEff σ.val ε) [] := by
  have hl : (fixedComps op args).length = as.length := by
    simpa only [List.length_map] using hcs.length
  have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
    (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes)
      ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
  simp only [List.length_map, List.length_cons] at hm
  have hr := annotation (B := B) (annotation_sameTypes
    (annotation_under ha ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0))) hR.types) σ
  simp only [List.length_map, List.length_cons] at hr
  have hk := bindParams_lookup_head (bindParams (hideConts Γ) args.holeTypes)
    ((Ty.dependentFn t).shiftV args.holeTypes.length 0) (as.map (Ty.shiftV args.holeTypes.length 0))
  rw [Ty.shiftV_add, List.length_map] at hk
  have hj : (bindParams (bindParams (hideConts Γ) args.holeTypes)
      ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))[as.length]? =
      some (some (.dependentFn (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t))) := by
    simpa only [List.map_cons, Ty.shiftV] using hk
  have hvar : HasTypeVQ P B StoreTy.empty Q C
      (rangeCtx σ.val (bindParams (bindParams (hideConts Γ) args.holeTypes)
        ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0))))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) (.var as.length)
      (rangeTy σ.val (.dependentFn (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t))) :=
    .V_Var (rangeCtx_lookup hj σ.val) (rangeTy_ordinary (by intro x y z; simp [Ty.core]) σ.val)
  have hvn := hvar.V_Normal
  rw [dependentFn_range_norm] at hvn
  have hargs := hv.core (Q := Q) hR hA hm σ
  have hrapp := HasTypeCQ.C_Sub
    (HasTypeCQ.dependentApp_normalized (R := some (rangeTy σ.val (b.shiftV (as.length + 1) 0)))
      (Δ := localExtend (as.length + 1) []) hvn hargs)
    (le_core hR hle σ.val) ((OpenBody.Covers.source hc).at σ) hr.wf hr.sorted hr.declared
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  simp only [callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
    List.length_map, hl, comp_let_instR, letChain_instR]
  refine .C_Let hff ?_ ha'.declared
  have hch := letChain_typed hA storeEmpty_wf
    _ [rangeTy σ.val ((Ty.dependentFn t).shiftV args.holeTypes.length 0)]
    ((as.map (Ty.shiftV args.holeTypes.length 0)).map (rangeTy σ.val))
    ((Comp.app (.var as.length) (recordFields args.positions.length args.positions
      (args.argVals (1 + as.length)) (.const .unit))).instR σ.val)
    (rangeTy σ.val b) (rangeEff σ.val ε) hcs ?_ ha'.declared
  · simpa only [List.length_cons, List.length_nil, Nat.zero_add, Nat.add_zero, bindParams_single,
      Option.map_some, (show liftMany 1 (liftMany args.holeTypes.length Φ) = (liftMany args.holeTypes.length Φ).map Pred.lift from rfl)] using hch
  · simpa only [rangeCtx_bindParams, List.map_cons, List.length_map, List.length_cons, List.length_nil,
      List.singleton_append, Nat.add_comm 1, comp_app_instR, val_var_instR,
      rangeTy_shiftV, rangeEff_shiftV, Option.map_some] using hrapp

theorem partial_callee_shift {P B op Q C Γ Φ f t ε rs} {R : Option Ty} {ps : List Ty}
    (hA : Builtins.ValueAssumptions P B)
    (hf : ExprCore P B op Q [] C Γ Φ R .other f (.dependentFn t) ε rs) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs (bindParams Γ ps)) (liftMany ps.length Φ)
      ((R.map (Ty.shiftV ps.length 0)).map (rangeTy rs))
      (((desugarExpr op .other f).rename (· + ps.length)).instR rs)
      (rangeTy rs ((Ty.dependentFn t).shiftV ps.length 0)) (rangeEff rs (Eff.shiftV ps.length 0 ε)) [] := by
  have hh := hf.under_params hA storeEmpty_wf (ps.map (rangeTy rs))
  simp only [rangeLocal_nil] at hh
  have hh' := HasTypeCQ.local_zero hh (localExtend_nil_shift _)
  simpa only [rangeCtx_bindParams, List.length_map, rangeTy_shiftV, rangeEff_shiftV,
    Option.map_map, Function.comp_def, rangeLocal_nil, ← shiftIndex_add,
    OpenRangeRename.comp_instR_shift] using hh'

theorem partialCall_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p f names args r ε t as r' e'}
    (hholes : args.holeTypes ≠ [])
    (hnd : directCallee f = none)
    (hn : NamesWF (args.holeNames names) args.holeTypes)
    (ha : Ty.AnnotationR D.core ks C Γ (.fn (args.holeNames names) args.holeTypes r ε))
    (hv : ValsTel D B ks C Γ (args.holeTypes.length + (as.length + 1))
      (bindParams (bindParams (hideConts Γ) args.holeTypes) ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
      (recordFields args.positions.length args.positions (args.argVals (as.length + 1)) (.const .unit))
      (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t) r' e')
    (hle : Ty.LeQ D.core
      (bindParams (bindParams (hideConts Γ) args.holeTypes) ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) r' (r.shiftV (args.holeTypes.length + (as.length + 1)) 0))
    (hc : Eff.Covers
      (bindParams (bindParams (hideConts Γ) args.holeTypes) ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
      (Eff.shiftV (args.holeTypes.length + (as.length + 1)) 0 ε) e')
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hfx : FixedCore P B op Q C (hideConts Γ) Φ (some r) args as ε σ.val)
    (hf : ExprCore P B op Q [] C (hideConts Γ) Φ (some r) .other f (.dependentFn t) ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p
      (.partialCall f names args (r.shiftV args.holeTypes.length 0) (Eff.shiftV args.holeTypes.length 0 ε))
      (.fn (args.holeNames names) args.holeTypes r ε) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_fn] at ha'
  have hcs := partial_fixed_shift (ps := args.holeTypes) hA hfx
  have hff := partial_callee_shift (ps := args.holeTypes) hA hf
  have hr0 := annotation_shift (annotation_fn_result ha) (ShiftMap.hideOuter Γ args.holeTypes)
  have hbody := partial_indirect_body_core (ε := Eff.shiftV args.holeTypes.length 0 ε) hnd hr0
    (by simpa only [Ty.shiftV_add] using hv) (by simpa only [Ty.shiftV_add] using hle)
    (by simpa only [Eff.shiftV_add] using hc) hR hA σ
    (by simpa only [Option.map_some] using hff) (by simpa only [Option.map_some] using hcs)
  simp only [rangeCtx_bindParams, rangeCtx_hideConts, rangeTy_shiftV, rangeEff_shiftV] at hbody
  simp only [ExprCore, desugarExpr, hholes, ite_false, holeLam_shift, comp_ret_instR, lam_instR,
    rangeTy_fn, rangeEff_empty]
  refine .C_Return (.V_Lam ⟨by simpa only [List.length_map] using hn.1, hn.2⟩
    ha'.wf ha'.sorted ?_ ha'.declared)
  rw [hideBuilders_empty]
  simpa only [List.length_map] using hbody

theorem partialCallDep_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p f names args ret eff εf t as r' e'}
    (hholes : args.holeTypes ≠ [])
    (hnd : directCallee f = none)
    (hn : NamesWF (args.holeNames names) args.holeTypes)
    (hdep : ¬ ∃ (r0 : Ty) (e0 : Eff), ret = r0.shiftV args.holeTypes.length 0 ∧
      eff = Eff.shiftV args.holeTypes.length 0 e0)
    (ha : Ty.AnnotationR D.core ks C Γ (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)))
    (hret : Ty.AnnotationR D.core ks C (bindParams (hideConts Γ) args.holeTypes) ret)
    (hcov : Eff.Covers (bindParams (hideConts Γ) args.holeTypes) (liftMany args.holeTypes.length Φ)
      eff (Eff.shiftV args.holeTypes.length 0 εf))
    (hv : ValsTel D B ks C Γ (args.holeTypes.length + (as.length + 1))
      (bindParams (bindParams (hideConts Γ) args.holeTypes) ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
      (recordFields args.positions.length args.positions (args.argVals (as.length + 1)) (.const .unit))
      (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t) r' e')
    (hle : Ty.LeQ D.core
      (bindParams (bindParams (hideConts Γ) args.holeTypes) ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) r' (ret.shiftV (as.length + 1) 0))
    (hc : Eff.Covers
      (bindParams (bindParams (hideConts Γ) args.holeTypes) ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
      (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
      (Eff.shiftV (as.length + 1) 0 eff) e')
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hfx : FixedCore P B op Q C (hideConts Γ) Φ none args as εf σ.val)
    (hf : ExprCore P B op Q [] C (hideConts Γ) Φ none .other f (.dependentFn t) εf σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p
      (.partialCall f names args ret eff)
      (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) Eff.empty σ.val := by
  have ha' := dependent_annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hcs := (partial_fixed_shift (ps := args.holeTypes) hA hfx).retarget
    ((OpenBody.Covers.source hcov).at σ) (some (rangeTy σ.val ret))
  have hff := partial_callee_shift (ps := args.holeTypes) hA hf
  have hff' := HasTypeCQ.C_Eff (HasTypeCQ.withReturn hff rfl rfl (some (rangeTy σ.val ret)))
    ((OpenBody.Covers.source hcov).at σ)
  have hbody := partial_indirect_body_core hnd hret hv hle hc hR hA σ hff' hcs
  simp only [ExprCore, desugarExpr, hholes, ite_false, holeLam_dependent hdep, comp_ret_instR, rangeEff_empty]
  apply HasTypeCQ.C_Return
  rw [dependentLam_instR]
  apply dependentFn_range_type
  refine .V_DependentLam ha' ?_
  rw [hideBuilders_empty, rangeTel_holeTel]
  have ht := holeTel_body (Γ0 := hideConts (rangeCtx σ.val Γ)) (Φ := Φ) []
    (args.holeNames names) (args.holeTypes.map (rangeTy σ.val))
    (by simpa only [List.length_map] using hn.1)
    (r := rangeTy σ.val ret) (e := rangeEff σ.val eff) (by
      simpa only [rangeCtx_bindParams, rangeCtx_hideConts, List.length_map, bindParams_nil, List.nil_append,
        List.length_nil, Nat.zero_add] using hbody)
  simpa only [bindParams_nil, List.length_nil, (show liftMany 0 Φ = Φ from rfl)] using ht

end
end Benitoite.Release.Refinement.Surface.OpenSurface
