import Benitoite.Release.Refinement.Surface.OpenSurfaceSequence
import Benitoite.Release.Refinement.Surface.OpenRangeRename
import Benitoite.Release.Refinement.Surface.OpenPatterns
import Benitoite.Release.Refinement.Surface.Property1Match

/-! # 開いた表層の条件分岐と照合の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem rangeLocal_extend (rs : List RangeExpr) (Δ : LocalCtx) (n : Nat) :
    rangeLocal rs (localExtend n Δ) = localExtend n (rangeLocal rs Δ) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    have he (L : LocalCtx) :
        rangeLocal (r :: rs) (LocalCtx.extend none L) =
          LocalCtx.extend none (rangeLocal (r :: rs) L) := by
      simp only [rangeLocal, LocalCtx.extend, List.map_cons, Option.map_none,
        List.map_map, Option.map_map, Function.comp_def]
      congr 1
      apply List.map_congr_left
      intro x _
      cases x with
      | none => rfl
      | some b => exact congrArg some (OpenRangeRename.kind_mapRanges_shift b _ 1 0)
    induction n with
    | zero => rfl
    | succ n ih => rw [localExtend, he, ih]; rfl

theorem le_core {D : Declarations} {P Γ Φ a b} (hR : D.Realizes P)
    (h : Ty.LeQ D.core Γ Φ a b) (rs : List RangeExpr) :
    Ty.LeQ P (rangeCtx rs Γ) Φ (rangeTy rs a) (rangeTy rs b) := by
  cases rs with
  | nil => exact h.sameTypes hR.types
  | cons r rs => exact (h.sameTypes hR.types).instR (r :: rs)

private theorem control_facts {Γ : Ctx} {a : Ty} {Ξ Φ : List Pred} (h : ∀ q ∈ Ξ,
    Entails ((Γ.extend a).facts ++ Φ) (q.shiftV 1 0)) (rs : List RangeExpr) :
    ∀ q ∈ Ξ, Entails (((rangeCtx rs Γ).extend (rangeTy rs a)).facts ++ Φ) (q.shiftV 1 0) := by
  simpa only [← rangeCtx_extend, rangeCtx_facts] using h

theorem ite_instR (m n : Comp) (rs : List RangeExpr) :
    (Comp.ite (.var 0) m n).instR rs = .ite (.var 0) (m.instR rs) (n.instR rs) := by cases rs <;> rfl

theorem block_shift_core {P B op Q Δ C Γ Φ R p body a ε}
    (hA : Builtins.ValueAssumptions P B) (h : BlockCore P B op Q Δ C Γ Φ R p body a ε rs)
    {t : Ty} {Ξ : List Pred} (hf : ∀ q ∈ Φ,
      Entails ((Γ.extend t).facts ++ Ξ) (q.shiftV 1 0)) :
    HasTypeCQ P B StoreTy.empty Q C ((rangeCtx rs Γ).extend (rangeTy rs t)) Ξ
      ((R.map (rangeTy rs)).map (Ty.shiftV 1 0))
      (((desugarBlock op p body).rename (· + 1)).instR rs)
      ((rangeTy rs a).shiftV 1 0) (Eff.shiftV 1 0 (rangeEff rs ε))
      (localExtend 1 (rangeLocal rs Δ)) := by
  have hh := shift_one hA h (control_facts hf rs)
  simpa only [← shiftIndex_add, OpenRangeRename.comp_instR_shift] using hh

/-- 同じ範囲の具体化の下で、条件と二つの枝の帰納仮定を条件分岐へ接続する。 -/
theorem if_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p cond yes no a b Φy Φn ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc : ExprCore P B op Q Δ C Γ Φ R .other cond a ε σ.val)
    (ho : Ordinary a)
    (hle : Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean))
    (hfy : ∀ q ∈ Φy, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hfn : ∀ q ∈ Φn, Entails ((Γ.extend a).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hy : BlockCore P B op Q Δ C Γ Φy R p yes b ε σ.val)
    (hn : BlockCore P B op Q Δ C Γ Φn R p no b ε σ.val)
    (hb : Ty.Declared D.core C Γ b) :
    ExprCore P B op Q Δ C Γ Φ R p (.ite cond yes no) b ε σ.val := by
  have hh := ite_typed hc (rangeTy_ordinary ho σ.val)
    (by
      have hl := le_core hR hle σ.val
      rw [rangeCtx_extend, rangeTy_shiftV] at hl
      have hbool : rangeTy σ.val (.base .boolean) = .base .boolean := by cases σ.val <;> rfl
      simpa only [hbool] using hl)
    (block_shift_core hA hy hfy) (block_shift_core hA hn hfn)
    (rangeCtx_declared (B := B) (hb.sameTypes hR.types) σ.val)
  simpa only [ExprCore, desugarExpr, comp_let_instR, ite_instR] using hh

/-- else if の後続の式にも、同じ条件分岐の保存を適用する。 -/
theorem elseIf_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p cond yes no a b Φy Φn ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc : ExprCore P B op Q Δ C Γ Φ R .other cond a ε σ.val)
    (ho : Ordinary a)
    (hle : Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean))
    (hfy : ∀ q ∈ Φy, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hfn : ∀ q ∈ Φn, Entails ((Γ.extend a).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hy : BlockCore P B op Q Δ C Γ Φy R p yes b ε σ.val)
    (hn : ExprCore P B op Q Δ C Γ Φn R p no b ε σ.val)
    (hb : Ty.Declared D.core C Γ b) :
    ExprCore P B op Q Δ C Γ Φ R p (.elseIf cond yes no) b ε σ.val := by
  have hh := if_core (no := .last no) hR hA σ hc ho hle hfy hfn hy hn hb
  simpa only [ExprCore, desugarExpr, desugarBlock] using hh

/-- else のない分岐の偽側は、同じ具体化の下で単位値を返す。 -/
theorem ifOnly_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p cond yes a Φy ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc : ExprCore P B op Q Δ C Γ Φ R .other cond a ε σ.val)
    (ho : Ordinary a)
    (hle : Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean))
    (hfy : ∀ q ∈ Φy, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0))
    (hy : BlockCore P B op Q Δ C Γ Φy R p yes (.base .unit) ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.ifOnly cond yes) (.base .unit) ε σ.val := by
  have hu : rangeTy σ.val (.base .unit) = .base .unit := by cases σ.val <;> rfl
  have hn : BlockCore P B op Q Δ C Γ [] R p (.last .unit) (.base .unit) ε σ.val := by
    change HasTypeCQ _ _ _ _ _ _ _ _ _ (rangeTy σ.val (.base .unit)) _ _
    rw [hu]
    have hm : (desugarBlock op p (.last .unit)).instR σ.val = .ret (.const .unit) := by cases σ.val <;> rfl
    rw [hm]
    exact .C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)
  have hh := if_core (Φn := []) hR hA σ hc ho hle hfy (by intro q h; cases h) hy hn trivial
  simpa only [ExprCore, desugarExpr, desugarBlock, Comp.rename, Val.rename] using hh

private theorem variable_sort_ranges {Γ : Ctx} {i s} (h : (Term.var i).HasSort Γ s)
    (rs : List RangeExpr) : (Term.var i).HasSort (rangeCtx rs Γ) s := by
  obtain ⟨a, ha, hs⟩ := h.2
  have hi := rangeCtx_lookup ha rs
  have hs' := rangeTy_hasSort hs rs
  exact ⟨⟨rangeTy rs a, hi, hs'.ordinary⟩, rangeTy rs a, hi, hs'⟩

private theorem unguarded_instR (arms : List Arm) (rs : List RangeExpr) :
    unguardedPats (Arm.instRList rs arms) = unguardedPats arms := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    induction arms with
    | nil => rfl
    | cons arm arms ih =>
      cases arm with
      | mk alts guard body =>
        cases guard <;> simp only [Arm.instRList, Arm.mapRangesListN, unguardedPats] at ih ⊢
        all_goals rw [ih]

private theorem match_instR (arms : List Arm) (rs : List RangeExpr) :
    (Comp.match (.var 0) arms).instR rs = .match (.var 0) (Arm.instRList rs arms) := by
  cases rs <;> rfl

/-- 元のview付きの網羅性を具体化し、同じ具体化の腕の帰納仮定へ接続する。 -/
theorem match_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p e arms a b ε}
    (hR : D.Realizes P) (σ : Instance ks) (hp : PatternRangesClosed D.core)
    (ho : Ordinary a)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e a ε σ.val)
    (harms : HasTypeArmsQ P B StoreTy.empty Q C (rangeCtx σ.val (Γ.extend a)) (Φ.map Pred.lift)
      ((R.map (Ty.shiftV 1 0)).map (rangeTy σ.val)) (scrutObs (Γ.extend a))
      (Arm.instRList σ.val (desugarArms op p arms)) (rangeTy σ.val (a.shiftV 1 0))
      (rangeTy σ.val (b.shiftV 1 0)) (rangeEff σ.val (Eff.shiftV 1 0 ε))
      (rangeLocal σ.val (localExtend 1 Δ)))
    (hex : ViewExhaustive D D.view a arms.unguardedPatterns)
    (ha : Ty.AnnotationR D.core ks C Γ a) (hb : Ty.AnnotationR D.core ks C Γ b) :
    ExprCore P B op Q Δ C Γ Φ R p (.matchE b e arms) b ε σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hb' := annotation (B := B) (annotation_sameTypes hb hR.types) σ
  have harms' : HasTypeArmsQ P B StoreTy.empty Q C ((rangeCtx σ.val Γ).extend (rangeTy σ.val a))
      (Φ.map Pred.lift) ((R.map (rangeTy σ.val)).map (Ty.shiftV 1 0)) (scrutObs (Γ.extend a))
      (Arm.instRList σ.val (desugarArms op p arms)) ((rangeTy σ.val a).shiftV 1 0)
      ((rangeTy σ.val b).shiftV 1 0) (Eff.shiftV 1 0 (rangeEff σ.val ε))
      (localExtend 1 (rangeLocal σ.val Δ)) := by
    simpa only [rangeCtx_extend, rangeTy_shiftV, rangeEff_shiftV, rangeLocal_extend,
      Option.map_map, Function.comp_def] using harms
  have hxr : Exhaustive P (rangeTy σ.val a) arms.unguardedPatterns := by
    cases hr : σ.val with
    | nil => exact hex.exhaustive.sameTypes hR.types
    | cons r rs => exact ((hex.instR hp (r :: rs)).exhaustive.sameTypes hR.types)
  have hx : Exhaustive P ((rangeTy σ.val a).shiftV 1 0)
      (unguardedPats (Arm.instRList σ.val (desugarArms op p arms))) := by
    rw [unguarded_instR, unguardedPats_desugarArms]
    exact hxr.shiftV 1 0
  have hm := HasTypeCQ.C_Match (P := P) (B := B) (Ψ := StoreTy.empty) (Q := Q) (C := C)
    (Γ := (rangeCtx σ.val Γ).extend (rangeTy σ.val a)) (Φ := Φ.map Pred.lift)
    (R := (R.map (rangeTy σ.val)).map (Ty.shiftV 1 0))
    (a := (rangeTy σ.val a).shiftV 1 0) (v := .var 0) (obs := scrutObs (Γ.extend a))
    (.V_Var (by simp only [Ctx.extend, List.getElem?_cons_zero])
      ((Ty.ordinary_shiftV _ _ _).mpr (rangeTy_ordinary ho σ.val)))
    (by
      intro t ht
      unfold scrutObs at ht
      split at ht
      · cases ht
        refine ⟨rfl, ?_⟩
        obtain ⟨s, hs⟩ := (by assumption : ∃ s, (Term.var 0).HasSort (Γ.extend a) s)
        exact ⟨s, by simpa only [rangeCtx_extend] using variable_sort_ranges hs σ.val⟩
      · cases ht)
    harms' (by simpa only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] using (ha'.under [rangeTy σ.val a]).declared) hx
  have hh := HasTypeCQ.C_Let he hm hb'.declared
  simpa only [ExprCore, desugarExpr, comp_let_instR, match_instR] using hh

end
end Benitoite.Release.Refinement.Surface.OpenSurface
