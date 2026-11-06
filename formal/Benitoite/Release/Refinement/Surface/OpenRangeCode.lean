import Benitoite.Release.Refinement.Surface.OpenSurfaceFormation

/-! # 観測と範囲の具体化

範囲の型注釈を具体化しても、値の有限の観測は変わらない。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

mutual
  theorem toTerm_mapRangesN (v : Val) (ρ : Nat → RangeIx) :
      (v.mapRangesN ρ).toTerm? = v.toTerm? := by
    cases v <;> first | rfl | simp only [Val.mapRangesN, Val.toTerm?, toTermSlots_mapRangesN]
  theorem toTermSlots_mapRangesN (vs : List Val) (ρ : Nat → RangeIx) :
      Val.toTermSlots (Val.mapRangesListN ρ vs) = Val.toTermSlots vs := by
    cases vs <;> simp only [Val.mapRangesListN, Val.toTermSlots, toTerm_mapRangesN, toTermSlots_mapRangesN]
end

theorem toTerm_instR (v : Val) (rs : List RangeExpr) : (v.instR rs).toTerm? = v.toTerm? := by
  cases rs with
  | nil => rfl
  | cons r rs => exact toTerm_mapRangesN v (rangeAt 0 (r :: rs))

theorem vals_mapRangesN_eq_map (vs : List Val) (ρ : Nat → RangeIx) :
    Val.mapRangesListN ρ vs = vs.map (Val.mapRangesN ρ) := by
  induction vs <;> simp_all [Val.mapRangesListN]

theorem val_list_instR (vs : List Val) (rs : List RangeExpr) :
    (Val.list vs).instR rs = .list (vs.map (Val.instR rs)) := by
  cases rs with
  | nil => change Val.list vs = Val.list (vs.map id); rw [List.map_id]
  | cons r rs =>
    simp only [Val.instR, Val.substR, Val.mapRangesN]
    congr 1
    induction vs <;> simp_all [Val.mapRangesListN, Val.instR, Val.substR]

theorem rangeTy_hasSort {a : Ty} {s : «Sort»} (h : a.HasSort s) (rs : List RangeExpr) :
    (rangeTy rs a).HasSort s := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    exact (Ty.hasSort_norm _ _).mpr ((Ty.hasSort_rawMapRanges _ _ _).mpr h)

theorem rangeCtx_typeMap (Γ : Ctx) (rs : List RangeExpr) : Ctx.TypeMap Γ (rangeCtx rs Γ) := by
  cases rs with
  | nil => exact Ctx.TypeMap.id Γ
  | cons r rs =>
    apply Ctx.TypeMap.of_map Γ (Ty.mapRanges (rangeAt 0 (r :: rs)))
    · intro a s hs; exact rangeTy_hasSort hs (r :: rs)
    · intro a ho; exact rangeTy_ordinary ho (r :: rs)
    · intro a p hp
      simpa only [Ty.mapRanges, Ty.assume_norm, Ty.assume_rawMapRanges] using hp

theorem rangeCtx_normEq (Γ : Ctx) (ρ : Nat → RangeIx) :
    (Γ.rawMapRanges ρ).NormEq (Γ.mapRanges ρ) := by
  simp only [Ctx.NormEq, Ctx.rawMapRanges, Ctx.mapRanges, List.map_map, Option.map_map,
    Function.comp_def, Ty.mapRanges, Ty.norm_idem]

theorem rangeCtx_declared {P C Γ a} {B : Builtins} (h : Ty.Declared P C Γ a)
    (rs : List RangeExpr) : Ty.Declared P C (rangeCtx rs Γ) (rangeTy rs a) := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    exact (h.rawMapRanges (rangeAt 0 (r :: rs))).norm.context
      ((rangeCtx_normEq Γ _).declaration (B := B))

end
end Benitoite.Release.Refinement.Surface.OpenSurface
