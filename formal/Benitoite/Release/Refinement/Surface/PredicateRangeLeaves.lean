import Benitoite.Release.Refinement.Surface.RangeStandard
import Benitoite.Release.Refinement.Surface.PredicateProjectionSpec

/-! # 判定の内部行と標準行の範囲の具体化

制約を読む標準行はプログラムの宣言の要約を参照する。判定の内部行の許容は型引数の個数から定まり、型引数の範囲を
除外しない。いずれも開いた構文の一度の検査から、全ての適格な範囲の具体化の葉を供給する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateRangeLeaves
noncomputable section

/-- 宣言の要約による制約の照合は、範囲の具体化で同値である。 -/
private theorem sat_instR (S : Benitoite.Release.SummaryTable) (C : List TParam) (a : Ty) (p : TParam)
    (rs : List RangeExpr) :
    ModelConstraints.sat S C (a.instR rs) p ↔ ModelConstraints.sat S C a p := by
  rw [Ty.instR_eq_bind]
  exact ModelConstraints.sat_bind_values _ _ _ _ _ (fun _ => rfl)

private theorem scalar_core (a : Ty) :
    StandardScalar.scalarTypeCore a.core = StandardScalar.scalarTypeCore a := by
  cases a <;> try rfl
  case refined a _ => exact scalar_core a

private theorem scalar_refine (a : Ty) (p : Pred) :
    StandardScalar.scalarTypeCore (a.refineNorm p) = StandardScalar.scalarTypeCore a := by
  unfold Ty.refineNorm
  cases (a.refinementPredicates ++ p.conjuncts) <;>
    simpa only [Ty.packRefinements, StandardScalar.scalarTypeCore] using scalar_core a

private theorem scalar_fold (t : Tel) : StandardScalar.scalarTypeCore (Ty.foldFn t) = none := by
  unfold Ty.foldFn
  split <;> rfl

private theorem scalar_ranges (a : Ty) (rs : List RangeExpr) :
    StandardScalar.scalarTypeCore (a.instR rs) = StandardScalar.scalarTypeCore a := by
  cases a <;> simp only [Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, Ty.norm,
    StandardScalar.scalarTypeCore]
  case refined a p =>
    rw [scalar_refine]
    exact scalar_ranges a rs
  case dependentFn t => exact scalar_fold _

/-- 全ての標準行の許容は、その行が読む宣言の要約にかかわらず範囲の具体化で保つ。 -/
theorem standard_admits_instR (S : Benitoite.Release.SummaryTable) (row : StandardModel.Primitive)
    {C ts} (h : (row.signatureWith (ModelConstraints.sat S)).admits C ts) (rs : List RangeExpr) :
    (row.signatureWith (ModelConstraints.sat S)).admits C (ts.map (Ty.instR rs)) := by
  rcases StandardModel.admits_formWith S row with form | rfl | rfl
  · apply (form _ _).mpr
    apply ModelConstraints.admits_map (S := S) (f := Ty.instR rs) _ ((form _ _).mp h)
    intro a p ha
    exact (sat_instR S C a p rs).mpr ha
  · change (_ ∧ _ ∧ _) at h ⊢
    refine ⟨by simpa using h.1, ?_, ?_⟩
    · intro z
      cases z
    · intro _ a ha
      obtain ⟨t, ht, rfl⟩ := List.mem_map.mp ha
      have ordered := h.2.2 rfl t ht
      simpa only [StandardListRemainingResponse.orderedType, scalar_ranges] using ordered
  · change PublicNames.checkAdmits C (ts.map (Ty.instR rs))
    rw [show Ty.instR rs = Ty.bind (.rangesOnly rs) from funext fun a => Ty.instR_eq_bind a rs]
    exact RefinementCheck.admits_bind (C := C) (D := C) (.rangesOnly rs) h

private theorem normalized_range_types (rs : List RangeExpr) (ts : List Ty) :
    (Ty.normTys ts).map (Ty.instR rs) = Ty.normTys (ts.map (fun a => a.instR rs)) := by
  simp only [Ty.normTys_eq_map, List.map_map]
  exact List.map_congr_left (fun a _ => by
    simp only [Function.comp_apply, Ty.instR, Ty.substRAt, Ty.mapRanges,
      Ty.norm_rawMapRanges, Ty.norm_idem])

/-- 標準行の全具体化の葉を、開いた構文の検査と実際の行の許容から作る。 -/
theorem primitive_standard {S : Benitoite.Release.SummaryTable} {row : StandardModel.Primitive}
    {ks C nv Q ts es}
    (h : OpenLeafFormation.PrimitiveCheck ks C nv (row.signatureWith (ModelConstraints.sat S)) Q ts es) :
    OpenSurface.Primitive ks C nv (row.signatureWith (ModelConstraints.sat S)) Q ts es := by
  intro σ
  apply OpenLeafFormation.primitive_at h σ
  cases hr : σ.val with
  | nil =>
    simpa only [show rangeTy [] = id from rfl, List.map_id] using h.admits
  | cons r rs =>
    have ha := standard_admits_instR S row h.admits (r :: rs)
    rw [normalized_range_types] at ha
    simpa only [show rangeTy (r :: rs) = Ty.instR (r :: rs) from rfl] using ha

private theorem internal_count (row : PredicateProjection.Row) (C : List TParam) (ts : List Ty)
    (h : ts.length = row.signature.tparams.length) : row.signature.admits C ts := by
  cases row with
  | scalar entry =>
    change ts = []
    exact List.eq_nil_of_length_eq_zero (by simpa only [PredicateProjection.Row.signature,
      PredicateRows.Entry.signature, List.length_nil] using h)
  | projected projection =>
    change ts.length = projection.ntys
    simpa only [PredicateProjection.Row.signature, PredicateProjection.Projection.signature,
      List.length_replicate] using h

/-- scalarと投影の内部行は、既存の型引数の個数の条件だけで全具体化の許容を満たす。 -/
theorem primitive_internal {row : PredicateProjection.Row} {ks C nv Q ts es}
    (h : OpenLeafFormation.PrimitiveCheck ks C nv row.signature Q ts es) :
    OpenSurface.Primitive ks C nv row.signature Q ts es := by
  intro σ
  apply OpenLeafFormation.primitive_at h σ
  apply internal_count
  simpa only [Ty.normTys_eq_map, List.length_map] using h.typeCount

private theorem sat_range_norm {B : Builtins} {S : Benitoite.Release.SummaryTable}
    (hs : B.sat = ModelConstraints.sat S) (C : List TParam) (a : Ty) (p : TParam) (rs : List RangeExpr) :
    B.sat C (rangeTy rs a).norm p ↔ B.sat C a.norm p := by
  rw [hs]
  cases rs with
  | nil => rfl
  | cons r rs =>
    have he : a.norm.instR (r :: rs) = (rangeTy (r :: rs) a).norm := by
      simp only [rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.norm_rawMapRanges, Ty.norm_idem]
    rw [← he]
    exact sat_instR S C a.norm p (r :: rs)

/-- 完成した表がその宣言の要約を読むことの等式から、制約の照合の全具体化を得る。 -/
theorem satisfies_of_check {B : Builtins} {S : Benitoite.Release.SummaryTable} {ks C ts ps}
    (hs : B.sat = ModelConstraints.sat S) (h : SatAll B C ts ps) :
    OpenSurface.Satisfies B ks C ts ps := by
  intro σ
  apply h.map (rangeTy σ.val)
  intro a ha p hp
  exact (sat_range_norm hs (TypeCtx.constraints C) a p σ.val).mpr hp

/-- 関数の許容の全欄も、同じ表の制約の照合から全具体化へ写る。 -/
theorem admits_of_check {B : Builtins} {S : Benitoite.Release.SummaryTable}
    {ks C nv ps ne Qs Q ts es e} (hs : B.sat = ModelConstraints.sat S)
    (h : OpenLeafFormation.AdmitsCheck B ks C nv ps ne Qs Q ts es e) :
    OpenSurface.Admits B ks C nv ps ne Qs Q ts es e :=
  fun σ => OpenLeafFormation.admits_at h σ (satisfies_of_check hs h.types σ)

end
end Benitoite.Release.Refinement.Surface.PredicateRangeLeaves
