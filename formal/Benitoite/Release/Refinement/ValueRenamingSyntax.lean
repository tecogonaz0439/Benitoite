import Benitoite.Release.Refinement.ValueShiftOrder

namespace Benitoite.Release.Refinement

def valueUp (ξ : Nat → Nat) : Nat → Nat
  | 0 => 0
  | i+1 => ξ i + 1

@[simp] theorem valueUp_id : valueUp id = id := by funext i; cases i <;> rfl
theorem valueUp_comp (ξ ζ : Nat → Nat) :
    (fun i => valueUp ζ (valueUp ξ i)) = valueUp (fun i => ζ (ξ i)) := by
  funext i; cases i <;> rfl
theorem valueUp_shift (k c : Nat) : valueUp (shiftIndex k c) = shiftIndex k (c+1) := by
  funext i; cases i <;> simp only [valueUp, shiftIndex]
  · simp
  · split <;> split <;> simp_all <;> omega

mutual
  def Ty.renameValues (ξ : Nat → Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (renameValueTys ξ as)
    | .list a => .list (a.renameValues ξ)
    | .fn ns ps r e => .fn ns (renameValueTys ξ ps) (r.renameValues ξ) (Eff.renameValues ξ e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.renameValues ξ)
    | .lazy a => .lazy (a.renameValues ξ)
    | .cont b t e => .cont (b.renameValues ξ) (t.renameValues ξ) (Eff.renameValues ξ e)
    | .map a b => .map (a.renameValues ξ) (b.renameValues ξ)
    | .set a => .set (a.renameValues ξ)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.renameValues ξ)
    | .tapp i as => .tapp i (renameValueTys ξ as)
    | .ctor c => .ctor c
    | .refined a p => .refined (a.renameValues ξ) (predBind (fun i => some (.var (valueUp ξ i))) p)
    | .dependentFn t => .dependentFn (t.renameValues ξ)
    | .external id as => .external id (renameValueTys ξ as)
    | .scoped o k ix => .scoped o k ix
    | .pathBases => .pathBases
    | .scopePattern k => .scopePattern k
  def Tel.renameValues (ξ : Nat → Nat) : Tel → Tel
    | .done r e => .done (r.renameValues ξ) (Eff.renameValues ξ e)
    | .param n a t => .param n (a.renameValues ξ) (t.renameValues (valueUp ξ))
  def Eff.renameValues (ξ : Nat → Nat) : Eff → Eff
    | .mk a fs => .mk a (renameValueTys ξ fs)
  def renameValueTys (ξ : Nat → Nat) : List Ty → List Ty
    | [] => []
    | a :: as => a.renameValues ξ :: renameValueTys ξ as

end

mutual
  theorem Ty.renameValues_id (a : Ty) : a.renameValues id = a := by
    cases a <;> simp only [Ty.renameValues]
    all_goals simp only [Ty.renameValues_id, Tel.renameValues_id, Eff.renameValues_id,
      renameValueTys_id, valueUp_id, id_eq, predBind_id]
  theorem Tel.renameValues_id (t : Tel) : t.renameValues id = t := by
    cases t <;> simp only [Tel.renameValues]
    all_goals simp only [Ty.renameValues_id, Eff.renameValues_id, Tel.renameValues_id, valueUp_id]
  theorem Eff.renameValues_id (e : Eff) : Eff.renameValues id e = e := by
    cases e; simp only [Eff.renameValues, renameValueTys_id]
  private theorem renameValueTys_id (as : List Ty) : renameValueTys id as = as := by
    cases as <;> simp only [renameValueTys]
    all_goals simp only [Ty.renameValues_id, renameValueTys_id]
end

mutual
  theorem Ty.renameValues_comp (a : Ty) (ξ ζ : Nat → Nat) :
      (a.renameValues ξ).renameValues ζ = a.renameValues (fun i => ζ (ξ i)) := by
    cases a <;> simp only [Ty.renameValues]
    all_goals simp only [Ty.renameValues_comp, Eff.renameValues_comp, Tel.renameValues_comp, renameValueTys_comp]
    case refined a p =>
      congr 1
      simp only [predBind_comp, Option.bind_some, termBind?, ←valueUp_comp]
  theorem Tel.renameValues_comp (t : Tel) (ξ ζ : Nat → Nat) :
      (t.renameValues ξ).renameValues ζ = t.renameValues (fun i => ζ (ξ i)) := by
    cases t <;> simp only [Tel.renameValues, Ty.renameValues_comp, Eff.renameValues_comp,
      Tel.renameValues_comp, valueUp_comp]
  theorem Eff.renameValues_comp (e : Eff) (ξ ζ : Nat → Nat) :
      (Eff.renameValues ξ e).renameValues ζ = Eff.renameValues (fun i => ζ (ξ i)) e := by
    cases e; simp only [Eff.renameValues, renameValueTys_comp]
  private theorem renameValueTys_comp (as : List Ty) (ξ ζ : Nat → Nat) :
      renameValueTys ζ (renameValueTys ξ as) = renameValueTys (fun i => ζ (ξ i)) as := by
    cases as <;> simp only [renameValueTys]
    all_goals simp only [Ty.renameValues_comp, renameValueTys_comp]

end

mutual
  theorem Ty.shiftV_eq_renameValues (a : Ty) (k c : Nat) :
      a.shiftV k c = a.renameValues (shiftIndex k c) := by
    cases a <;> simp only [Ty.shiftV, Ty.renameValues, Ty.shiftV_eq_renameValues,
      Eff.shiftV_eq_renameValues, Tel.shiftV_eq_renameValues, shiftValuesList_eq]
    case refined a p => simp only [valueUp_shift, shiftIndex]
  theorem Tel.shiftV_eq_renameValues (t : Tel) (k c : Nat) :
      Tel.shiftV k c t = t.renameValues (shiftIndex k c) := by
    cases t <;> simp only [Tel.shiftV, Tel.renameValues, Ty.shiftV_eq_renameValues,
      Eff.shiftV_eq_renameValues, Tel.shiftV_eq_renameValues, valueUp_shift]
  theorem Eff.shiftV_eq_renameValues (e : Eff) (k c : Nat) :
      Eff.shiftV k c e = Eff.renameValues (shiftIndex k c) e := by
    cases e; simp only [Eff.shiftV, Eff.renameValues, shiftValuesList_eq]
  private theorem shiftValuesList_eq (as : List Ty) (k c : Nat) :
      shiftVTys k c as = renameValueTys (shiftIndex k c) as := by
    cases as <;> simp only [shiftVTys, renameValueTys, Ty.shiftV_eq_renameValues, shiftValuesList_eq]
end

def unshiftValue (k c i : Nat) : Nat := if i < c then i else i-k

theorem unshiftValue_shift (k c : Nat) : (fun i => unshiftValue k c (shiftIndex k c i)) = id := by
  funext i
  simp only [unshiftValue, shiftIndex, id_eq]
  repeat' split
  all_goals omega

theorem Ty.unshift_shift (a : Ty) (k c : Nat) :
    (a.shiftV k c).renameValues (unshiftValue k c) = a := by
  rw [Ty.shiftV_eq_renameValues, Ty.renameValues_comp, unshiftValue_shift, Ty.renameValues_id]

theorem Tel.unshift_shift (t : Tel) (k c : Nat) :
    (Tel.shiftV k c t).renameValues (unshiftValue k c) = t := by
  rw [Tel.shiftV_eq_renameValues, Tel.renameValues_comp, unshiftValue_shift, Tel.renameValues_id]

theorem Eff.unshift_shift (e : Eff) (k c : Nat) :
    Eff.renameValues (unshiftValue k c) (Eff.shiftV k c e) = e := by
  rw [Eff.shiftV_eq_renameValues, Eff.renameValues_comp, unshiftValue_shift, Eff.renameValues_id]

theorem Ty.shiftV_injective (k c : Nat) : Function.Injective (Ty.shiftV k c) := by
  intro a b h
  have hh := congrArg (Ty.renameValues (unshiftValue k c)) h
  simpa only [Ty.unshift_shift] using hh

theorem Eff.shiftV_injective (k c : Nat) : Function.Injective (Eff.shiftV k c) := by
  intro a b h
  have hh := congrArg (Eff.renameValues (unshiftValue k c)) h
  simpa only [Eff.unshift_shift] using hh

theorem Ty.renameValues_up_shift (a : Ty) (ξ : Nat → Nat) :
    (a.shiftV 1 0).renameValues (valueUp ξ) = (a.renameValues ξ).shiftV 1 0 := by
  simp only [Ty.shiftV_eq_renameValues, Ty.renameValues_comp]
  congr 1

theorem Eff.renameValues_up_shift (e : Eff) (ξ : Nat → Nat) :
    Eff.renameValues (valueUp ξ) (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.renameValues ξ e) := by
  simp only [Eff.shiftV_eq_renameValues, Eff.renameValues_comp]
  congr 1

@[simp] theorem renameValueTys_eq_map (ξ : Nat → Nat) (as : List Ty) :
    renameValueTys ξ as = as.map (Ty.renameValues ξ) := by
  induction as <;> simp_all [renameValueTys]

theorem Tel.renameValues_toTel (ns ps r e) (ξ : Nat → Nat) :
    (Ty.toTel ns ps r e).renameValues ξ =
      Ty.toTel ns (ps.map (Ty.renameValues ξ)) (r.renameValues ξ) (Eff.renameValues ξ e) := by
  induction ns generalizing ps r e ξ with
  | nil => simp only [Ty.toTel, Tel.renameValues]
  | cons n ns ih =>
    cases ps with
    | nil => simp only [Ty.toTel, Tel.renameValues, List.map_nil]
    | cons a ps =>
      simp only [Ty.toTel, List.map_cons, Tel.renameValues, ih,
        Ty.renameValues_up_shift, Eff.renameValues_up_shift]
      congr 2
      simp only [shiftVTys_eq_map, List.map_map, Function.comp_def, Ty.renameValues_up_shift]

end Benitoite.Release.Refinement
