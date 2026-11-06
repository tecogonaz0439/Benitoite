import Benitoite.Release.Refinement.RangeTyping
import Benitoite.Release.Refinement.TypeValueExchange

/-! # 署名の型・行の具体化と範囲の具体化の交換 -/
namespace Benitoite.Release.Refinement.Surface.OpenSignatureExchange
noncomputable section

/-- 型・行の像も同じ範囲写像で置き換えると、署名の具体化と交換する。 -/
theorem instantiatedTel_mapRanges (ρ : Nat → RangeIx) (t : Tel)
    (ts : List Ty) (es : List Eff) :
    Tel.mapRanges ρ (instantiatedTel t ts es) =
      instantiatedTel (Tel.mapRanges ρ t) (ts.map (Ty.mapRanges ρ))
        (es.map (Eff.mapRanges ρ)) := by
  have raw : Tel.mapRanges ρ (instantiatedTel t ts es) =
      instantiatedTel (Tel.mapRanges ρ t) (ts.map (Ty.rawMapRanges ρ))
        (es.map (Eff.rawMapRanges ρ)) := by
    simp only [instantiatedTel, Tel.mapRanges, Tel.bind,
      Tel.norm_rawMapRanges, Tel.norm_rawBind]
    rw [Tel.rawBind_mapRanges t _ rfl rfl ρ, typeEnvAt_mapRanges]
  rw [raw]
  have ht : Ty.mapRanges ρ = fun a => (a.rawMapRanges ρ).norm := rfl
  have he : Eff.mapRanges ρ = fun e => (Eff.rawMapRanges ρ e).norm := rfl
  rw [ht, he]
  have h := Tel.substAt_norm_images_all (Tel.mapRanges ρ t) 0
    (ts.map (Ty.rawMapRanges ρ)) (es.map (Eff.rawMapRanges ρ))
  simpa only [Tel.substAt, instantiatedTel, List.map_map, Function.comp_def] using h.symm

/-- 空の具体化は元の署名を保ち、非空の具体化は正規化した型・行の像と交換する。 -/
theorem rangeTel_instantiated (rs : List RangeExpr) (t : Tel)
    (ts : List Ty) (es : List Eff) :
    rangeTel rs (instantiatedTel t ts es) =
      instantiatedTel (rangeTel rs t) (ts.map (rangeTy rs)) (es.map (rangeEff rs)) := by
  cases rs with
  | nil =>
    have ht : rangeTy [] = id := rfl
    have he : rangeEff [] = id := rfl
    simp only [rangeTel, ht, he, List.map_id]
  | cons r rs =>
    have ht : rangeTy (r :: rs) = Ty.mapRanges (rangeAt 0 (r :: rs)) := rfl
    have he : rangeEff (r :: rs) = Eff.mapRanges (rangeAt 0 (r :: rs)) := rfl
    rw [ht, he]
    simpa only [rangeTel, Tel.instR, Tel.substRAt] using
      instantiatedTel_mapRanges (rangeAt 0 (r :: rs)) t ts es

end
end Benitoite.Release.Refinement.Surface.OpenSignatureExchange
