import Benitoite.Release.Refinement.Surface.OpenSurfaceValues
import Benitoite.Release.Refinement.Surface.OpenSurfaceControl
import Benitoite.Release.Refinement.Surface.OpenSurfaceSequence

/-! # 開いた範囲文脈の基本式の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

private theorem basic_bool (rs : List RangeExpr) : rangeTy rs (.base .boolean) = .base .boolean := by cases rs <;> rfl
private theorem basic_resource (rs : List RangeExpr) (o : OpaqueName) :
    rangeTy rs (.opaque o (.fixed .top)) = .opaque o (.fixed .top) := by cases rs <;> rfl

theorem rangeTy_fn (rs : List RangeExpr) (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    rangeTy rs (.fn ns ps r e) = .fn ns (ps.map (rangeTy rs)) (rangeTy rs r) (rangeEff rs e) := by
  cases rs with
  | nil => have h : rangeTy [] = id := rfl; simp only [rangeTy, rangeEff, h, List.map_id]
  | cons r rs =>
    simp only [rangeTy, rangeEff, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
      Ty.norm, Ty.normTys_eq_map, mapRangesTys_eq_map, List.map_map]
    rfl

theorem rangeTy_lazy (rs : List RangeExpr) (a : Ty) : rangeTy rs (.lazy a) = .lazy (rangeTy rs a) := by cases rs <;> rfl

theorem rangeTy_cont (rs : List RangeExpr) (b t : Ty) (e : Eff) :
    rangeTy rs (.cont b t e) = .cont (rangeTy rs b) (rangeTy rs t) (rangeEff rs e) := by cases rs <;> rfl

private theorem hideConts_if (Γ : Ctx) : hideConts Γ =
    Γ.map (fun | none => none | some a => if Ordinary a then some a else none) := by
  unfold hideConts
  apply List.map_congr_left
  intro oa _
  cases oa with
  | none => rfl
  | some a => cases ha : a.core <;> simp [Ordinary, ha]

theorem rangeCtx_hideConts (rs : List RangeExpr) (Γ : Ctx) :
    rangeCtx rs (hideConts Γ) = hideConts (rangeCtx rs Γ) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeCtx, hideConts_if, Ctx.mapRanges, List.map_map, Function.comp_def]
    apply List.map_congr_left
    intro oa _
    cases oa with
    | none => rfl
    | some a =>
      by_cases ho : Ordinary a
      · have hn := rangeTy_ordinary ho (r :: rs)
        change Ordinary (a.mapRanges (rangeAt 0 (r :: rs))) at hn
        simp only [ho, hn, ↓reduceIte, Option.map_some]
      · have hn : ¬ Ordinary (rangeTy (r :: rs) a) := by
          intro hn
          exact ho ((Ty.ordinary_rawMapRanges _ _).mp ((Ty.ordinary_norm _).mp hn))
        change ¬ Ordinary (a.mapRanges (rangeAt 0 (r :: rs))) at hn
        simp only [ho, hn, ↓reduceIte, Option.map_some, Option.map_none]

private theorem basic_constant_block {P B op Q Δ C Γ Φ R p ε} (rs : List RangeExpr) (b : Bool) :
    BlockCore P B op Q Δ C Γ Φ R p (.last (.literal (.boolean b))) (.base .boolean) ε rs := by
  unfold BlockCore
  have he : (desugarBlock op p (.last (.literal (.boolean b)))).instR rs = .ret (.const (.boolean b)) := by cases rs <;> rfl
  rw [he, basic_bool]
  exact .C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)

theorem not_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p e a ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e a ε σ.val) (ho : Ordinary a)
    (hle : Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean)) :
    ExprCore P B op Q Δ C Γ Φ R p (.not e) (.base .boolean) ε σ.val := by
  have hh := if_core (p := p) (yes := .last (.literal (.boolean false))) (no := .last (.literal (.boolean true)))
    (Φy := []) (Φn := []) hR hA σ he ho hle (by intro q h; cases h) (by intro q h; cases h)
    (basic_constant_block σ.val false) (basic_constant_block σ.val true) trivial
  simpa only [ExprCore, desugarExpr, desugarBlock, Comp.rename, Val.rename, Literal.toConst] using hh

theorem and_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p lhs rhs a Φr ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs a ε σ.val) (ho : Ordinary a)
    (hle : Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean))
    (hf : ∀ q ∈ Φr, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hr : ExprCore P B op Q Δ C Γ Φr R p rhs (.base .boolean) ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.and lhs rhs) (.base .boolean) ε σ.val := by
  have hh := if_core (p := p) (yes := .last rhs) (no := .last (.literal (.boolean false))) (Φn := [])
    hR hA σ hl ho hle hf (by intro q h; cases h) hr (basic_constant_block σ.val false) trivial
  simpa only [ExprCore, desugarExpr, desugarBlock, Comp.rename, Val.rename, Literal.toConst] using hh

theorem or_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p lhs rhs a Φr ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs a ε σ.val) (ho : Ordinary a)
    (hle : Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean))
    (hf : ∀ q ∈ Φr, Entails ((Γ.extend a).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hr : ExprCore P B op Q Δ C Γ Φr R p rhs (.base .boolean) ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.or lhs rhs) (.base .boolean) ε σ.val := by
  have hh := if_core (p := p) (yes := .last (.literal (.boolean true))) (no := .last rhs) (Φy := [])
    hR hA σ hl ho hle (by intro q h; cases h) hf (basic_constant_block σ.val true) hr trivial
  simpa only [ExprCore, desugarExpr, desugarBlock, Comp.rename, Val.rename, Literal.toConst] using hh

theorem refine_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p e a q v t s ε}
    (hR : D.Realizes P) (σ : Instance ks)
    (he : ExprCore P B op Q Δ C Γ Φ R p e a ε σ.val) (hv : e.valueOf? = some v)
    (ht : v.toTerm? = some t) (hs : a.HasSort s) (hp : Pred.Sorted Γ (some a) q)
    (hw : Pred.WF (Γ.length + 1) q) (hent : Entails (Γ.facts ++ Φ) (q.open t))
    (ha : Ty.AnnotationR D.core ks C Γ a) (hpd : Pred.Declared D.core C Γ (some a) q) :
    ExprCore P B op Q Δ C Γ Φ R p e (.refined a q) ε σ.val := by
  have hra : Ty.AnnotationR D.core ks C Γ (.refined a q) :=
    ⟨⟨ha.wf, hw, Ty.notContCore_of_wf_ordinary ha.wf hs.ordinary⟩,
      ⟨ha.sorted, hp⟩, ⟨ha.declared, hpd⟩⟩
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hra' := annotation (B := B) (annotation_sameTypes hra hR.types) σ
  unfold ExprCore at he ⊢
  rw [desugar_valueOf hv, comp_ret_instR] at he ⊢
  have hv' := HasTypeVQ.V_Refine (he.ret_value rfl) (rangeTy_hasSort hs σ.val)
    ((toTerm_instR v σ.val).trans ht) (rangeCtx_pred_sorted hp σ.val)
    (by simpa only [rangeCtx_length] using hw)
    (by simpa only [rangeCtx_facts] using hent)
    ha'.declared (rangeCtx_pred_declared (B := B) (hpd.sameTypes hR.types) σ.val)
  exact .C_Eff (.C_Return (.V_Sub hv' (.convert (rangeTy_refined σ.val a q)) hra'.wf hra'.sorted hra'.declared))
    (Eff.covers_empty _ _ _)

theorem resume_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p k e b t ε}
    (hR : D.Realizes P) (σ : Instance ks)
    (hk : Γ[k]? = some (some (.cont b t ε))) (ho : Ordinary b)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e b ε σ.val) (ht : Ty.Declared D.core C Γ t) :
    ExprCore P B op Q Δ C Γ Φ R p (.resume k e) t ε σ.val := by
  have hk' := rangeCtx_lookup hk σ.val
  rw [rangeTy_cont] at hk'
  have hcont : ((rangeCtx σ.val Γ).extend (rangeTy σ.val b))[k + 1]? =
      some (some (.cont ((rangeTy σ.val b).shiftV 1 0) ((rangeTy σ.val t).shiftV 1 0)
        (Eff.shiftV 1 0 (rangeEff σ.val ε)))) := by
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, hk', Option.map_some, Ty.shiftV]
  have ht' := rangeCtx_declared (B := B) (ht.sameTypes hR.types) σ.val
  have hret : Ty.Declared P C ((rangeCtx σ.val Γ).extend (rangeTy σ.val b)) ((rangeTy σ.val t).shiftV 1 0) := by
    simpa only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] using (FullShiftMap.outer (rangeCtx σ.val Γ) [rangeTy σ.val b]).values.declared ht'
  have hh := HasTypeCQ.C_Let he (.C_Resume hcont (.V_Var (i := 0) (by simp [Ctx.extend])
    ((Ty.ordinary_shiftV _ _ _).mpr (rangeTy_ordinary ho σ.val))) hret) ht'
  have hcode : (Comp.resume (.var (k + 1)) (.var 0)).instR σ.val = .resume (.var (k + 1)) (.var 0) := by cases σ.val <;> rfl
  simpa only [ExprCore, desugarExpr, comp_let_instR, hcode] using hh

private theorem basic_rangeLocal_nil (rs : List RangeExpr) : rangeLocal rs [] = [] := by cases rs <;> rfl

private theorem basic_rangeCtx_none (rs : List RangeExpr) (Γ : Ctx) :
    rangeCtx rs (Γ.map fun _ => none) = (rangeCtx rs Γ).map (fun _ => none) := by
  cases rs <;> simp [rangeCtx, Ctx.mapRanges, List.map_map]

theorem const_core {P B ks op Q Δ C Γ Φ R p a body}
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hb : ExprCore P B op Q [] C (Γ.map fun _ => none) [] R .other body a Eff.empty σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.constE a body) a Eff.empty σ.val := by
  have hh := hb.shift_values (k := 0) (c := 0) (Δ := rangeCtx σ.val Γ) (Ξ := Φ)
    (L' := rangeLocal σ.val Δ) hA storeEmpty_wf (StoreTy.Extends.refl _)
    (show FullShiftMap 0 0 (rangeCtx σ.val (Γ.map fun _ => none)) (rangeCtx σ.val Γ) from ⟨by simp [rangeCtx_length], by
      intro i a hi
      rw [basic_rangeCtx_none] at hi
      simp only [List.getElem?_map] at hi
      cases hx : (rangeCtx σ.val Γ)[i]? <;> simp [hx] at hi⟩)
    (by simpa only [basic_rangeLocal_nil] using LocalCtx.Shift.empty 0 0 (rangeLocal σ.val Δ))
    (fun q hq => by cases hq)
  have hR0 : (R.map (rangeTy σ.val)).map (Ty.shiftV 0 0) = R.map (rangeTy σ.val) := by
    cases R <;> simp [Ty.shiftV_zero]
  simpa only [ExprCore, desugarExpr, shiftIndex_zero, Comp.rename_identity, Ty.shiftV_zero,
    Eff.shiftV_zero, hR0] using hh

private theorem basic_val_lam_instR (rs : List RangeExpr) (ns : List String) (ps : List Ty) (m : Comp) :
    (Val.lam ns ps m).instR rs = .lam ns (ps.map (rangeTy rs)) (m.instR rs) := by
  cases rs with
  | nil => have h : rangeTy [] = id := rfl; simp only [Val.instR_nil, Comp.instR_nil, h, List.map_id]
  | cons r rs => rfl

theorem lam_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p names ps r ε body}
    (hR : D.Realizes P) (σ : Instance ks) (hn : NamesWF names ps)
    (ha : Ty.AnnotationR D.core ks C Γ (.fn names ps r ε))
    (hb : BlockCore P B op Q [] C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
      (some (r.shiftV ps.length 0)) .tail body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.lam names ps r ε body) (.fn names ps r ε) Eff.empty σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  rw [rangeTy_fn] at ha'
  have hn' : NamesWF names (ps.map (rangeTy σ.val)) := ⟨by simpa only [List.length_map] using hn.1, hn.2⟩
  have hb' := hb
  simp only [BlockCore, rangeCtx_bindParams, rangeCtx_hideConts, rangeTy_shiftV, rangeEff_shiftV,
    Option.map_some, basic_rangeLocal_nil] at hb'
  rw [← hideBuilders_empty] at hb'
  unfold ExprCore
  rw [desugarExpr, comp_ret_instR, basic_val_lam_instR, rangeTy_fn, rangeEff_empty]
  exact .C_Return (.V_Lam hn' ha'.wf ha'.sorted (by simpa only [List.length_map] using hb') ha'.declared)

theorem lazy_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p body a}
    (hR : D.Realizes P) (σ : Instance ks)
    (hb : BlockCore P B op Q [] C (hideConts Γ) Φ none .other body a Eff.empty σ.val)
    (ha : Ty.AnnotationR D.core ks C Γ a) :
    ExprCore P B op Q Δ C Γ Φ R p (.lazyE body) (.lazy a) Eff.empty σ.val := by
  have hb' := hb
  simp only [BlockCore, rangeCtx_hideConts, Option.map_none, basic_rangeLocal_nil, rangeEff_empty] at hb'
  rw [← hideBuilders_empty] at hb'
  have hm : (Comp.lazyC (desugarBlock op .other body)).instR σ.val =
      .lazyC ((desugarBlock op .other body).instR σ.val) := by cases σ.val <;> rfl
  unfold ExprCore
  rw [desugarExpr, hm, rangeTy_lazy, rangeEff_empty]
  exact .C_Lazy hb' (annotation (B := B) (annotation_sameTypes ha hR.types) σ)

private theorem basic_rangeEff_top {e : Eff} {name : EffName} (h : e.test (.name name (.fixed .top)) = true)
    (rs : List RangeExpr) : (rangeEff rs e).test (.name name (.fixed .top)) = true := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    change (Eff.rawMapRanges (rangeAt 0 (r :: rs)) e).norm.mem (.name name (.fixed .top))
    rw [Eff.mem_norm]
    cases e with
    | mk atoms fails =>
      exact (mapRangeAtoms_spec _ _ _).mpr ⟨.name name (.fixed .top), h, rfl⟩

theorem with_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p o e body a ε}
    (hR : D.Realizes P) (σ : Instance ks) (hres : B.isResource o = true)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.opaque o (.fixed .top)) ε σ.val)
    (hb : BlockCore P B op Q (localExtend 1 Δ) C (Γ.extend (.opaque o (.fixed .top))) (Φ.map Pred.lift)
      (R.map (Ty.shiftV 1 0)) .other body (a.shiftV 1 0) (Eff.shiftV 1 0 ε) σ.val)
    (htest : (Eff.shiftV 1 0 ε).test (.name stateEff (.fixed .top)) = true)
    (hd : Ty.Declared D.core C Γ a) :
    ExprCore P B op Q Δ C Γ Φ R p (.withE o e body) a ε σ.val := by
  have he' := he
  simp only [ExprCore, basic_resource] at he'
  have hb' := hb
  simp only [BlockCore, rangeCtx_extend, basic_resource, rangeTy_shiftV, rangeEff_shiftV,
    rangeLocal_extend, Option.map_map, Function.comp_def] at hb'
  have htest' := basic_rangeEff_top htest σ.val
  rw [rangeEff_shiftV] at htest'
  have hh := HasTypeCQ.C_Let (b := rangeTy σ.val a) he' (.C_Use (.V_Var (i := 0) (by simp [Ctx.extend, Ty.shiftV])
    (by intro b t e; simp [Ty.core])) hres (by simpa only [Option.map_map, Function.comp_def] using hb') htest')
    (rangeCtx_declared (B := B) (hd.sameTypes hR.types) σ.val)
  have hm : (Comp.use (.var 0) (desugarBlock op .other body)).instR σ.val =
      .use (.var 0) ((desugarBlock op .other body).instR σ.val) := by cases σ.val <;> rfl
  simpa only [ExprCore, desugarExpr, comp_let_instR, hm] using hh

end
end Benitoite.Release.Refinement.Surface.OpenSurface
