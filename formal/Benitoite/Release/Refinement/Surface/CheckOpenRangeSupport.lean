import Benitoite.Release.Refinement.Surface.CheckArguments
import Benitoite.Release.Refinement.Surface.OpenSurface

/-! # 範囲引数の像と有限支持 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenArguments
open CheckArguments CheckCompare

/-- 実際の範囲引数の写像について、原子の有限一覧が像を含む。 -/
def rangeSupport (atoms : List Atom) (xs : List RangeIx) : Bool :=
  atoms.all (fun a => decide (mapAtomRanges (aliasRangeEnv xs) a ∈ atoms))

private theorem rangeSupport_sound {atoms xs} (h : rangeSupport atoms xs = true) :
    ∀ a ∈ atoms, mapAtomRanges (aliasRangeEnv xs) a ∈ atoms := by
  intro a ha
  exact of_decide_eq_true (List.all_eq_true.mp h a ha)

mutual
  private theorem type_ranges_support {atoms : List Atom} {ρ : Nat → RangeIx} (a : Ty)
      (h : a.Support (· ∈ atoms)) (hm : ∀ a ∈ atoms, mapAtomRanges ρ a ∈ atoms) :
      (a.rawMapRanges ρ).Support (· ∈ atoms) := by
    cases a <;> simp only [Ty.rawMapRanges, Ty.Support] at h ⊢
    all_goals first | trivial | exact types_ranges_support _ h hm | exact type_ranges_support _ h hm | skip
    case dependentFn t => exact telescope_ranges_support t h hm
    case fn ns ps r e => exact ⟨types_ranges_support ps h.1 hm,
      type_ranges_support r h.2.1 hm, effect_ranges_support e h.2.2 hm⟩
    case cont a b e => exact ⟨type_ranges_support a h.1 hm,
      type_ranges_support b h.2.1 hm, effect_ranges_support e h.2.2 hm⟩
    case map a b => exact ⟨type_ranges_support a h.1 hm, type_ranges_support b h.2 hm⟩
  private theorem types_ranges_support {atoms : List Atom} {ρ : Nat → RangeIx} (as : List Ty)
      (h : Ty.SupportList (· ∈ atoms) as) (hm : ∀ a ∈ atoms, mapAtomRanges ρ a ∈ atoms) :
      Ty.SupportList (· ∈ atoms) (mapRangesTys ρ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨type_ranges_support a h.1 hm, types_ranges_support as h.2 hm⟩
  private theorem telescope_ranges_support {atoms : List Atom} {ρ : Nat → RangeIx} (t : Tel)
      (h : t.Support (· ∈ atoms)) (hm : ∀ a ∈ atoms, mapAtomRanges ρ a ∈ atoms) :
      (Tel.rawMapRanges ρ t).Support (· ∈ atoms) := by
    cases t with
    | done r e => exact ⟨type_ranges_support r h.1 hm, effect_ranges_support e h.2 hm⟩
    | param n a t => exact ⟨type_ranges_support a h.1 hm, telescope_ranges_support t h.2 hm⟩
  private theorem effect_ranges_support {atoms : List Atom} {ρ : Nat → RangeIx} (e : Eff)
      (h : e.Support (· ∈ atoms)) (hm : ∀ a ∈ atoms, mapAtomRanges ρ a ∈ atoms) :
      (Eff.rawMapRanges ρ e).Support (· ∈ atoms) := by
    cases e with
    | mk test fails =>
      refine ⟨?_, types_ranges_support fails h.2 hm⟩
      intro a ha
      obtain ⟨b, hb, rfl⟩ := (mapRangeAtoms_spec _ _ _).mp ha
      exact hm b (h.1 b hb)
end

mutual
  private def mapTypeRanges (atoms : List Atom) (ρ : Nat → RangeIx) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o (mapIx ρ ix)
    | .data d as => .data d (mapTypeRangesList atoms ρ as)
    | .list a => .list (mapTypeRanges atoms ρ a)
    | .fn ns ps r e => .fn ns (mapTypeRangesList atoms ρ ps) (mapTypeRanges atoms ρ r) (mapEffectRanges atoms ρ e)
    | .tvar i => .tvar i
    | .reference a => .reference (mapTypeRanges atoms ρ a)
    | .lazy a => .lazy (mapTypeRanges atoms ρ a)
    | .cont b t e => .cont (mapTypeRanges atoms ρ b) (mapTypeRanges atoms ρ t) (mapEffectRanges atoms ρ e)
    | .map a b => .map (mapTypeRanges atoms ρ a) (mapTypeRanges atoms ρ b)
    | .set a => .set (mapTypeRanges atoms ρ a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (mapTypeRanges atoms ρ a)
    | .tapp i as => .tapp i (mapTypeRangesList atoms ρ as)
    | .ctor c => .ctor c
    | .refined a p => .refined (mapTypeRanges atoms ρ a) p
    | .dependentFn t => .dependentFn (mapTelRanges atoms ρ t)
    | .external id as => .external id (mapTypeRangesList atoms ρ as)
    | .scoped o kind ix => .scoped o kind (mapIx ρ ix)
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  private def mapTelRanges (atoms : List Atom) (ρ : Nat → RangeIx) : Tel → Tel
    | .done r e => .done (mapTypeRanges atoms ρ r) (mapEffectRanges atoms ρ e)
    | .param n a t => .param n (mapTypeRanges atoms ρ a) (mapTelRanges atoms ρ t)
  private def mapTypeRangesList (atoms : List Atom) (ρ : Nat → RangeIx) : List Ty → List Ty
    | [] => []
    | a :: as => mapTypeRanges atoms ρ a :: mapTypeRangesList atoms ρ as
  private def mapEffectRanges (atoms : List Atom) (ρ : Nat → RangeIx) : Eff → Eff
    | .mk test fs => .mk (fun a => atoms.any (fun b => test b && decide (mapAtomRanges ρ b = a)))
        (mapTypeRangesList atoms ρ fs)
end

mutual
  private theorem mapTypeRanges_eq {atoms : List Atom} {ρ : Nat → RangeIx} (a : Ty)
      (h : a.Support (· ∈ atoms)) : mapTypeRanges atoms ρ a = a.rawMapRanges ρ := by
    cases a <;> simp only [mapTypeRanges, Ty.rawMapRanges, Ty.Support] at h ⊢
    all_goals first | rfl | exact congrArg _ (mapTypeRangesList_eq _ h) | exact congrArg _ (mapTypeRanges_eq _ h) | skip
    case refined a p => rw [mapTypeRanges_eq a h]
    case dependentFn t => exact congrArg Ty.dependentFn (mapTelRanges_eq t h)
    case fn ns ps r e => rw [mapTypeRangesList_eq ps h.1, mapTypeRanges_eq r h.2.1, mapEffectRanges_eq e h.2.2]
    case cont a b e => rw [mapTypeRanges_eq a h.1, mapTypeRanges_eq b h.2.1, mapEffectRanges_eq e h.2.2]
    case map a b => rw [mapTypeRanges_eq a h.1, mapTypeRanges_eq b h.2]
  private theorem mapTypeRangesList_eq {atoms : List Atom} {ρ : Nat → RangeIx} (as : List Ty)
      (h : Ty.SupportList (· ∈ atoms) as) : mapTypeRangesList atoms ρ as = mapRangesTys ρ as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [mapTypeRangesList, mapRangesTys, mapTypeRanges_eq a h.1, mapTypeRangesList_eq as h.2]
  private theorem mapTelRanges_eq {atoms : List Atom} {ρ : Nat → RangeIx} (t : Tel)
      (h : t.Support (· ∈ atoms)) : mapTelRanges atoms ρ t = Tel.rawMapRanges ρ t := by
    cases t with
    | done r e => simp only [mapTelRanges, Tel.rawMapRanges, mapTypeRanges_eq r h.1, mapEffectRanges_eq e h.2]
    | param n a t => simp only [mapTelRanges, Tel.rawMapRanges, mapTypeRanges_eq a h.1, mapTelRanges_eq t h.2]
  private theorem mapEffectRanges_eq {atoms : List Atom} {ρ : Nat → RangeIx} (e : Eff)
      (h : e.Support (· ∈ atoms)) : mapEffectRanges atoms ρ e = Eff.rawMapRanges ρ e := by
    cases e with
    | mk test fs =>
      simp only [mapEffectRanges, Eff.rawMapRanges, mapTypeRangesList_eq fs h.2]
      congr 1
      funext a
      apply Bool.eq_iff_iff.mpr
      constructor
      · intro ha
        obtain ⟨b, hb, hp⟩ := List.any_eq_true.mp ha
        obtain ⟨ht, he⟩ := Bool.and_eq_true_iff.mp hp
        exact (mapRangeAtoms_spec _ _ _).mpr ⟨b, ht, of_decide_eq_true he⟩
      · intro ha
        obtain ⟨b, hb, he⟩ := (mapRangeAtoms_spec _ _ _).mp ha
        exact List.any_eq_true.mpr ⟨b, h.1 b hb, Bool.and_eq_true_iff.mpr ⟨hb, decide_eq_true he⟩⟩
end

/-- 範囲引数が空なら元の依存列を保ち、非空なら有限支持上で範囲を具体化する。 -/
def openRangeTel (q : CheckFormation.Input) (xs : List RangeIx) (t : Tel) : Tel :=
  match xs with
  | [] => t
  | _ => Tel.normWith q.atoms (mapTelRanges q.atoms (aliasRangeEnv xs) t)

/-- 範囲写像の有限な検査は、具体化した依存列の支持を供給する。 -/
theorem openRangeTel_checked {q : CheckFormation.Input} {xs : List RangeIx} {t : Tel}
    (ht : t.Support (· ∈ q.atoms)) (hr : rangeSupport q.atoms xs = true) :
    openRangeTel q xs t = OpenSurface.openRangeTel xs t ∧
      (openRangeTel q xs t).Support (· ∈ q.atoms) := by
  cases xs with
  | nil => exact ⟨rfl, ht⟩
  | cons x xs =>
    have hs := telescope_ranges_support t ht (rangeSupport_sound hr)
    have he := Tel.normWith_eq_norm q.atoms _ hs
    have hm := mapTelRanges_eq (ρ := aliasRangeEnv (x :: xs)) t ht
    dsimp only [openRangeTel, OpenSurface.openRangeTel]
    rw [hm, he]
    exact ⟨rfl, Tel.norm_support _ hs⟩

end Benitoite.Release.Refinement.Surface.CheckOpenArguments
