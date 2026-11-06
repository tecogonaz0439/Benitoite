import Benitoite.Release.Refinement.Surface.OpenSurface
import Benitoite.Release.Refinement.RangeExchange

/-! # 開いた範囲引数と呼出し元の具体化の交換

範囲の二つの写像を合成し、宣言した上限より下で像が同じときに依存列の像が等しいことを示す。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

private theorem ix_comp (ρ τ : Nat → RangeIx) (ix : RangeIx) :
    mapIx τ (mapIx ρ ix) = mapIx (fun i => mapIx τ (ρ i)) ix := by
  cases ix <;> rfl

private theorem atom_comp (ρ τ : Nat → RangeIx) (a : Atom) :
    mapAtomRanges τ (mapAtomRanges ρ a) = mapAtomRanges (fun i => mapIx τ (ρ i)) a := by
  cases a <;> simp [mapAtomRanges, ix_comp]

private theorem atoms_comp (ρ τ : Nat → RangeIx) (a : Atom → Bool) :
    mapRangeAtoms τ (mapRangeAtoms ρ a) = mapRangeAtoms (fun i => mapIx τ (ρ i)) a := by
  funext x
  apply Bool.eq_iff_iff.mpr
  simp only [mapRangeAtoms_spec]
  constructor
  · rintro ⟨y, ⟨z, hz, rfl⟩, rfl⟩
    exact ⟨z, hz, (atom_comp ρ τ z).symm⟩
  · rintro ⟨z, hz, rfl⟩
    exact ⟨mapAtomRanges ρ z, ⟨z, hz, rfl⟩, atom_comp ρ τ z⟩

mutual
  private theorem ty_comp (a : Ty) (ρ τ : Nat → RangeIx) :
      (a.rawMapRanges ρ).rawMapRanges τ = a.rawMapRanges (fun i => mapIx τ (ρ i)) := by
    cases a <;> simp only [Ty.rawMapRanges, ix_comp, ty_comp, tys_comp, eff_comp, tel_comp]
  private theorem tys_comp (as : List Ty) (ρ τ : Nat → RangeIx) :
      mapRangesTys τ (mapRangesTys ρ as) = mapRangesTys (fun i => mapIx τ (ρ i)) as := by
    cases as <;> simp only [mapRangesTys, ty_comp, tys_comp]
  private theorem eff_comp (e : Eff) (ρ τ : Nat → RangeIx) :
      Eff.rawMapRanges τ (Eff.rawMapRanges ρ e) = Eff.rawMapRanges (fun i => mapIx τ (ρ i)) e := by
    cases e <;> simp only [Eff.rawMapRanges, atoms_comp, tys_comp]
  private theorem tel_comp (t : Tel) (ρ τ : Nat → RangeIx) :
      Tel.rawMapRanges τ (Tel.rawMapRanges ρ t) = Tel.rawMapRanges (fun i => mapIx τ (ρ i)) t := by
    cases t <;> simp only [Tel.rawMapRanges, ty_comp, eff_comp, tel_comp]
end

private theorem ix_congr {nr} {ρ τ : Nat → RangeIx}
    (h : ∀ i, i < nr → ρ i = τ i) {ix : RangeIx} (hw : ix.WF nr) : mapIx ρ ix = mapIx τ ix := by
  cases ix with
  | fixed r => rfl
  | rvar i => exact h i hw

private theorem atoms_congr {nr} {ρ τ : Nat → RangeIx} {atoms : Atom → Bool}
    (h : ∀ i, i < nr → ρ i = τ i)
    (hw : ∀ name ix, atoms (.name name ix) = true → ix.WF nr) :
    mapRangeAtoms ρ atoms = mapRangeAtoms τ atoms := by
  have hm : ∀ a, atoms a = true → mapAtomRanges ρ a = mapAtomRanges τ a := by
    intro a ha
    cases a with
    | rho _ => rfl
    | name name ix => exact congrArg (Atom.name name) (ix_congr h (hw name ix ha))
  funext x
  apply Bool.eq_iff_iff.mpr
  simp only [mapRangeAtoms_spec]
  constructor
  · rintro ⟨a, ha, he⟩; exact ⟨a, ha, (hm a ha).symm.trans he⟩
  · rintro ⟨a, ha, he⟩; exact ⟨a, ha, (hm a ha).trans he⟩

mutual
  private theorem ty_congr {nr ρ τ} (a : Ty) (hw : a.RangesScoped nr)
      (h : ∀ i, i < nr → ρ i = τ i) : a.rawMapRanges ρ = a.rawMapRanges τ := by
    cases a <;> simp only [Ty.rawMapRanges]
    all_goals first | rfl | exact congrArg _ (ix_congr h hw) | exact congrArg _ (ty_congr _ hw h) |
      exact congrArg _ (tys_congr _ hw h) | exact congrArg _ (tel_congr _ hw h) | skip
    case fn ns ps r e => rw [tys_congr ps hw.1 h, ty_congr r hw.2.1 h, eff_congr e hw.2.2 h]
    case cont a b e => rw [ty_congr a hw.1 h, ty_congr b hw.2.1 h, eff_congr e hw.2.2 h]
    case map a b => rw [ty_congr a hw.1 h, ty_congr b hw.2 h]
    case refined a p => rw [ty_congr a hw h]
  private theorem tys_congr {nr ρ τ} (as : List Ty) (hw : rangesScopedTypes nr as)
      (h : ∀ i, i < nr → ρ i = τ i) : mapRangesTys ρ as = mapRangesTys τ as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [mapRangesTys, ty_congr a hw.1 h, tys_congr as hw.2 h]
  private theorem eff_congr {nr ρ τ} (e : Eff) (hw : Eff.RangesScoped nr e)
      (h : ∀ i, i < nr → ρ i = τ i) : Eff.rawMapRanges ρ e = Eff.rawMapRanges τ e := by
    cases e with
    | mk atoms fs => simp only [Eff.rawMapRanges, atoms_congr h hw.1, tys_congr fs hw.2 h]
  private theorem tel_congr {nr ρ τ} (t : Tel) (hw : t.RangesScoped nr)
      (h : ∀ i, i < nr → ρ i = τ i) : Tel.rawMapRanges ρ t = Tel.rawMapRanges τ t := by
    cases t with
    | done a e => simp only [Tel.rawMapRanges, ty_congr a hw.1 h, eff_congr e hw.2 h]
    | param n a t => simp only [Tel.rawMapRanges, ty_congr a hw.1 h, tel_congr t hw.2 h]
end

/-- 種類の合う開いた範囲引数は、呼出し元の適格な具体化で固定範囲になる。 -/
theorem RangeArgument.close {ks ix k rs} (h : RangeArgument ks ix k) (hr : RangesFit rs ks) :
    ix.inst rs = .fixed (closeRange rs ix) := by
  cases ix with
  | fixed r => rfl
  | rvar i =>
    have hi : i < ks.length := (List.getElem?_eq_some_iff.mp h).1
    have hj : i < rs.length := hr.1 ▸ hi
    simp [RangeIx.inst, closeRange, List.getElem?_eq_getElem hj]

/-- 範囲の宣言の置換と、呼出し元の範囲の具体化は、宣言した上限の下で交換する。 -/
theorem openRangeTel_instR {ks xs kinds rs t}
    (hx : RangeArguments ks xs kinds) (hr : RangesFit rs ks)
    (ht : t.RangesScoped kinds.length) :
    Tel.instR rs (openRangeTel xs t) = Tel.instR (xs.map (closeRange rs)) t := by
  have hm : ∀ i, i < kinds.length →
      mapIx (rangeAt 0 rs) (aliasRangeEnv xs i) = rangeAt 0 (xs.map (closeRange rs)) i := by
    intro i hi
    have hxi : i < xs.length := hx.1 ▸ hi
    have hk := List.getElem?_eq_getElem hi
    have hix := List.getElem?_eq_getElem hxi
    have hc := RangeArgument.close (hx.2 i _ _ hix hk) hr
    have he : mapIx (rangeAt 0 rs) xs[i] = xs[i].inst rs := mapIx_rangeAt _ _
    simp only [aliasRangeEnv, List.getElem?_eq_getElem hxi, Option.getD_some]
    rw [he, hc]
    simp [rangeAt, hxi]
  cases xs with
  | nil =>
    have hn : kinds.length = 0 := hx.1.symm
    simp only [openRangeTel, Tel.instR, Tel.substRAt, Tel.mapRanges, List.map_nil, rangeAt_nil]
    rw [tel_congr t ht (ρ := rangeAt 0 rs) (τ := RangeIx.rvar) (by intros; omega), Tel.rawMapRanges_id]
  | cons x xs =>
    simp only [openRangeTel, Tel.instR, Tel.substRAt, Tel.mapRanges]
    rw [Tel.norm_rawMapRanges, tel_comp]
    exact congrArg Tel.norm (tel_congr t ht hm)

end
end Benitoite.Release.Refinement.Surface.OpenSurface
