import Benitoite.Release.Refinement.Surface.OpenRangeRename
import Benitoite.Release.Refinement.Surface.OpenRangeCode

/-! # 開いた実引数の列と脱糖の let

具体化した子の計算の列から、元の脱糖の let の列を具体化した計算の型付けを構成する。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem rangeCtx_bindParams (rs : List RangeExpr) (Γ : Ctx) (as : List Ty) :
    rangeCtx rs (bindParams Γ as) = bindParams (rangeCtx rs Γ) (as.map (rangeTy rs)) := by
  cases rs with
  | nil => change bindParams Γ as = bindParams Γ (as.map id); rw [List.map_id]
  | cons r rs =>
    simp only [rangeCtx, Ctx.mapRanges, bindParams, List.map_append, List.map_map, List.map_reverse,
      List.length_map, Option.map_some, Option.map_map, Function.comp_def]
    congr 1
    · congr 1
      apply List.map_congr_left
      intro a _
      exact congrArg some (rangeTy_shiftV (r :: rs) a as.length 0)
    · congr 1
      funext a
      cases a with
      | none => rfl
      | some a => exact congrArg some (rangeTy_shiftV (r :: rs) a as.length 0)

theorem comp_let_instR (rs : List RangeExpr) (m n : Comp) :
    (Comp.letIn m n).instR rs = .letIn (m.instR rs) (n.instR rs) := by
  cases rs <;> rfl

theorem comp_ret_instR (rs : List RangeExpr) (v : Val) :
    (Comp.ret v).instR rs = .ret (v.instR rs) := by
  cases rs <;> rfl

theorem comp_app_instR (rs : List RangeExpr) (v : Val) (vs : List Val) :
    (Comp.app v vs).instR rs = .app (v.instR rs) (vs.map (Val.instR rs)) := by
  cases rs with
  | nil => change Comp.app v vs = .app v (vs.map id); rw [List.map_id]
  | cons r rs =>
    change Comp.app (v.mapRangesN _) (Val.mapRangesListN _ vs) = Comp.app (v.mapRangesN _) _
    congr 1
    induction vs <;> simp_all [Val.mapRangesListN, Val.instR, Val.substR]

theorem comp_meth_instR (rs : List RangeExpr) (d : Val) (m : MethName) (ts : List Ty)
    (es : List Eff) (vs : List Val) :
    (Comp.meth d m ts es vs).instR rs =
      .meth (d.instR rs) m (ts.map (rangeTy rs)) (es.map (rangeEff rs)) (vs.map (Val.instR rs)) := by
  cases rs with
  | nil =>
    change Comp.meth d m ts es vs = .meth d m (ts.map id) (es.map id) (vs.map id)
    simp only [List.map_id]
  | cons r rs =>
    simp only [Comp.instR, Comp.substR, Comp.mapRangesN, vals_mapRangesN_eq_map]
    rfl

theorem letChain_instR (rs : List RangeExpr) (depth : Nat) (ms : List Comp) (body : Comp) :
    (letChain depth ms body).instR rs = letChain depth (ms.map (Comp.instR rs)) (body.instR rs) := by
  induction ms generalizing depth with
  | nil => rfl
  | cons m ms ih =>
    simp only [letChain, List.map_cons, comp_let_instR, ih, ← shiftIndex_add,
      OpenRangeRename.comp_instR_shift]

theorem sequence_instR {P B Q C Γ Φ L ms as body b ε rs} {R : Option Ty}
    (hA : Builtins.ValueAssumptions P B)
    (hms : Surface.CompsTy P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
      (rangeLocal rs L) (ms.map (Comp.instR rs)) (as.map (rangeTy rs)) (rangeEff rs ε))
    (hb : HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs (bindParams Γ as)) (liftMany as.length Φ)
      ((R.map (Ty.shiftV as.length 0)).map (rangeTy rs)) (body.instR rs)
      (rangeTy rs (b.shiftV as.length 0)) (rangeEff rs (Eff.shiftV as.length 0 ε))
      (localExtend as.length (rangeLocal rs L)))
    (hd : Ty.Declared P C Γ b) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
      ((letChain 0 ms body).instR rs) (rangeTy rs b) (rangeEff rs ε) (rangeLocal rs L) := by
  rw [letChain_instR]
  apply sequence_typed hA storeEmpty_wf hms
  · simpa only [rangeCtx_bindParams, List.length_map, rangeTy_shiftV, rangeEff_shiftV,
      Option.map_map, Function.comp_def] using hb
  · exact rangeCtx_declared (B := B) hd rs

theorem let_source_core {P B Q C Γ Φ L m n a b ε rs} {R : Option Ty}
    (hm : HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
      (m.instR rs) (rangeTy rs a) (rangeEff rs ε) (rangeLocal rs L))
    (hn : HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs (Γ.extend a)) (Φ.map Pred.lift)
      ((R.map (Ty.shiftV 1 0)).map (rangeTy rs)) (n.instR rs) (rangeTy rs (b.shiftV 1 0))
      (rangeEff rs (Eff.shiftV 1 0 ε)) (localExtend 1 (rangeLocal rs L)))
    (hd : Ty.Declared P C Γ b) :
    HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
      ((Comp.letIn m n).instR rs) (rangeTy rs b) (rangeEff rs ε) (rangeLocal rs L) := by
  rw [comp_let_instR]
  refine .C_Let hm ?_ (rangeCtx_declared (B := B) hd rs)
  simpa only [rangeCtx_extend, rangeTy_shiftV, rangeEff_shiftV, Option.map_map, Function.comp_def] using hn

end
end Benitoite.Release.Refinement.Surface.OpenSurface
