import Benitoite.Release.Refinement.Surface.OpenSurfaceCallExpr
import Benitoite.Release.Refinement.Surface.Property1Interp

/-! # 開いたリスト展開と文字列補間の導出 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem SpreadTy.typed_core {P B ks Q C Γ f t ds k Γ' Φ' before s after b e h}
    {D : Declarations} {R : Option Ty} {L : LocalCtx}
    (hs : SpreadTy D B ks C Γ t ds k Γ' Φ' before s after b e)
    (hh : CallHeadTy D B ks Q C Γ f t ds) (hd : directCallee f = some h) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ Γ') (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((spreadFinish (h.rename (· + k)) before s after).instR σ.val)
      (rangeTy σ.val b) (rangeEff σ.val e) (rangeLocal σ.val L) := by
  cases hs with
  | only hv hle hb =>
    have hb' := annotation (B := B) (annotation_sameTypes hb hR.types) σ
    rw [spreadFinish, comp_ret_instR]
    exact .C_Eff (.C_Return (.V_Sub (hv.core hR hA hm σ) (le_core hR hle σ.val)
      hb'.wf hb'.sorted hb'.declared)) (Eff.covers_empty _ _ _)
  | front hv hle hc hb => exact hh.glue_core hd hR hA hm hm hv hle hc hb σ
  | back hv hle hc hb => exact hh.glue_core hd hR hA hm hm hv hle hc hb σ
  | @middle y ys s x xs r1 e1 r2 e2 b e hv1 ho1 ha1 hc1 hv2 hle2 hc2 hb =>
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r1) := by simpa [bindParams_single] using ShiftMap.outer Γ' [r1]
    have hm2 := ShiftMap.comp hm hm1
    have hfirst := hh.glue_core (R := R) (L := L) hd hR hA hm hm hv1 .refl hc1 ha1 σ
    have hb1 : Ty.AnnotationR D.core ks C (Γ'.extend r1) (b.shiftV 1 0) := by
      simpa only [bindParams_single, List.length_singleton] using annotation_under hb [r1]
    have hsecond := hh.glue_core (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L)
      hd hR hA hm2 hm2 hv2 hle2 hc2 hb1 σ
    rw [rangeLocal_extend] at hsecond
    have hcomp : (h.rename (· + k)).rename (· + 1) = h.rename (· + (k + 1)) := by
      rw [CallHead.rename_compose]; rfl
    simp only [spreadFinish, hcomp]
    exact let_source_core hfirst hsecond (hb.declared.sameTypes hR.types)

theorem string_annotationR (P : Refinement.Program) (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx) :
    Ty.AnnotationR P ks C Γ (.base .string) := ⟨trivial, trivial, trivial⟩

theorem rangeTy_string (rs : List RangeExpr) : rangeTy rs (.base .string) = .base .string := by
  cases rs <;> rfl

theorem JoinTy.typed_core {P B ks Q C Γ0 tadd k Γ' Φ' depth left rest e b op}
    {D : Declarations} {R : Option Ty} {L : LocalCtx}
    (h : JoinTy D B ks C Γ0 tadd k Γ' Φ' depth left rest e)
    (hop : op (.binary .add) (.base .string) = some (b, []))
    (hh : CallHeadTy D B ks Q C Γ0 (.primName b [] [] []) tadd []) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ') (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((joinStringFrom op depth left rest).instR σ.val) (.base .string) (rangeEff σ.val e) (rangeLocal σ.val L) := by
  induction h generalizing R L with
  | last hv hle hc =>
    have hg := hh.glue_core (R := R) (L := L) rfl hR hA hm hm hv hle hc (string_annotationR _ _ _ _) σ
    rw [addHead_apply] at hg
    simpa only [joinStringFrom, hop, rangeTy_string] using hg
  | @step k Γ' Φ' depth left right x xs r e' e hv ho ha hc _ ih =>
    have hg := hh.glue_core (R := R) (L := L) rfl hR hA hm hm hv .refl hc ha σ
    rw [addHead_apply] at hg
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r) := by simpa [bindParams_single] using ShiftMap.outer Γ' [r]
    have hrest := ih (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) (ShiftMap.comp hm hm1)
    rw [rangeLocal_extend] at hrest
    rw [joinStringFrom, hop]
    have hh' := let_source_core (b := .base .string) hg (by
      simpa only [string_shiftV, rangeTy_string] using hrest) (by trivial)
    simpa only [rangeTy_string] using hh'

theorem JoinPartsTy.typed_core {P B ks Q C Γ0 op k Γ' Φ' acc e}
    {D : Declarations} {R : Option Ty} {L : LocalCtx}
    (h : JoinPartsTy D B ks Q C Γ0 op k Γ' Φ' acc e) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ') (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((joinStringParts op acc).instR σ.val) (.base .string) (rangeEff σ.val e) (rangeLocal σ.val L) := by
  cases h with
  | empty =>
    rw [joinStringParts, comp_ret_instR]
    have hv : (Val.const (.string "")).instR σ.val = .const (.string "") := by cases σ.val <;> rfl
    rw [hv]
    exact .C_Eff (.C_Return (.V_Const (c := .string "") trivial)) (Eff.covers_empty _ _ _)
  | single hv hle =>
    rw [joinStringParts, joinStringFrom, comp_ret_instR]
    have hl := le_core hR hle σ.val
    rw [rangeTy_string] at hl
    exact .C_Eff (.C_Return (.V_Sub (hv.core hR hA hm σ) hl trivial trivial trivial)) (Eff.covers_empty _ _ _)
  | many hop hh hj => exact hj.typed_core hop hh hR hA hm σ

theorem InterpTy.typed_core {P B ks Q C Γ0 op k Γ' Φ' ps vs fs acc e}
    {D : Declarations} {R : Option Ty} {L : LocalCtx}
    (h : InterpTy D B ks Q C Γ0 op k Γ' Φ' ps vs fs acc e) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ') (σ : Instance ks) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx σ.val Γ') Φ' (R.map (rangeTy σ.val))
      ((interpolate op ps vs ((directHeads fs).map (CallHead.rename (· + k))) acc).instR σ.val)
      (.base .string) (rangeEff σ.val e) (rangeLocal σ.val L) := by
  induction h generalizing R L with
  | done hj => exact hj.typed_core hR hA hm σ
  | text _ ih => exact ih hm
  | stringExpr _ ih => exact ih hm
  | @converted k Γ' Φ' c ps v vs f fs acc t ds r e' e hh hv ho ha hc _ ih =>
    obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
    have hg := hh.glue_core (R := R) (L := L) hd hR hA hm hm hv .refl hc ha σ
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r) := by simpa [bindParams_single] using ShiftMap.outer Γ' [r]
    have hrest := ih (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) (ShiftMap.comp hm hm1)
    rw [rangeLocal_extend] at hrest
    simp only [directHeads, hd, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    have hh' := let_source_core (b := .base .string) hg (by
      simpa only [string_shiftV, rangeTy_string] using hrest) (by trivial)
    simpa only [rangeTy_string] using hh'

  | @formatted k Γ' Φ' c spec ps v vs f fs acc t ds r e' e hh hv ho ha hc _ ih =>
    obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
    have hg := hh.glue_core (R := R) (L := L) hd hR hA hm hm hv .refl hc ha σ
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r) := by simpa [bindParams_single] using ShiftMap.outer Γ' [r]
    have hrest := ih (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) (ShiftMap.comp hm hm1)
    rw [rangeLocal_extend] at hrest
    simp only [directHeads, hd, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    have hh' := let_source_core (b := .base .string) hg (by
      simpa only [string_shiftV, rangeTy_string] using hrest) (by trivial)
    simpa only [rangeTy_string] using hh'

theorem interpolation_core {P B ks op Q Δ C Γ Φ R p parts es fs as ε} {D : Declarations}
    (hi : InterpTy D B ks Q C Γ op as.length (bindParams Γ as) (liftMany as.length Φ)
      parts (boundVars as.length) fs [] (Eff.shiftV as.length 0 ε))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hms : ExprsCore P B op Q Δ C Γ Φ R es as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.interpolation parts es fs) (.base .string) ε σ.val := by
  have hlen : (desugarExprs op es).length = as.length := by simpa only [List.length_map] using hms.length
  have hg := hi.typed_core (R := R.map (Ty.shiftV as.length 0)) (L := localExtend as.length Δ)
    hR hA (ShiftMap.outer Γ as) σ
  rw [rangeLocal_extend] at hg
  unfold ExprCore
  simp only [desugarExpr, sequence, hlen]
  apply sequence_instR hA hms ?_ (by trivial)
  simpa only [string_shiftV, rangeTy_string] using hg

theorem listSpread_core {P B ks op Q Δ C Γ Φ R p a f before s after bs ts as t ds ε}
    {D : Declarations} (hh : CallHeadTy D B ks Q C Γ f t ds)
    (ha : Ty.AnnotationR D.core ks C Γ (.list a))
    (hsp : SpreadTy D B ks C Γ t ds (bs.length + (as.length + 1)) (bindParams Γ (bs ++ ts :: as))
      (liftMany (bs.length + (as.length + 1)) Φ)
      (Val.renameList (· + (as.length + 1)) (boundVars bs.length)) (.var as.length) (boundVars as.length)
      ((Ty.list a).shiftV (bs.length + (as.length + 1)) 0) (Eff.shiftV (bs.length + (as.length + 1)) 0 ε))
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hmb : ExprsCore P B op Q Δ C Γ Φ R before bs ε σ.val)
    (hms : ExprCore P B op Q Δ C Γ Φ R .other s ts ε σ.val)
    (hma : ExprsCore P B op Q Δ C Γ Φ R after as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.listSpread a f before s after) (.list a) ε σ.val := by
  have hall := hmb.append (.cons hms hma)
  have hsource : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeLocal σ.val Δ)
      ((desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after).map (Comp.instR σ.val))
      ((bs ++ ts :: as).map (rangeTy σ.val)) (rangeEff σ.val ε) := by
    simpa only [List.map_append, List.map_cons] using hall
  obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
  have hlb : (desugarExprs op before).length = bs.length := by simpa only [List.length_map] using hmb.length
  have hla : (desugarExprs op after).length = as.length := by simpa only [List.length_map] using hma.length
  have hbl : before.length = bs.length := (desugarExprs_length op before).symm.trans hlb
  have hn : (desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after).length =
      bs.length + (as.length + 1) := by simp [hlb, hla]
  have hn' : (bs ++ ts :: as).length = bs.length + (as.length + 1) := by simp
  have hg := hsp.typed_core (R := R.map (Ty.shiftV (bs.length + (as.length + 1)) 0))
    (L := localExtend (bs.length + (as.length + 1)) Δ) hh hd hR hA
    (by simpa only [hn'] using ShiftMap.outer Γ (bs ++ ts :: as)) σ
  rw [rangeLocal_extend] at hg
  unfold ExprCore
  simp only [desugarExpr, sequence, hd]
  apply sequence_instR hA hsource ?_ (ha.declared.sameTypes hR.types)
  rw [hn, hn', hbl, spreadValues_boundVars]
  exact hg

end
end Benitoite.Release.Refinement.Surface.OpenSurface
