import Benitoite.Release.Refinement.ShiftOrder
import Benitoite.Release.Refinement.Bind

namespace Benitoite.Release.Refinement

private theorem rawApply_shiftV (t : Ty) (as : List Ty) (k c : Nat) :
    (rawApply t as).shiftV k c = rawApply (t.shiftV k c) (shiftVTys k c as) := by
  cases t <;> simp only [rawApply, Ty.shiftV]
  case ctor t =>
    cases t <;> cases as <;> simp only [Ty.shiftV, shiftVTys,
      List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
    rename_i a as
    cases as <;> rfl

private theorem rowFails_shiftV (es : List Eff) (a : Atom → Bool) (k c : Nat) :
    shiftVTys k c (rowFails es a) = rowFails (es.map (Eff.shiftV k c)) a := by
  simp only [shiftVTys_eq_map, rowFails, List.length_map, List.map_flatMap, List.getElem?_map]
  congr 1
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; simp only [Option.map_some, Eff.shiftV, Eff.fails, shiftVTys_eq_map]

private theorem substAtoms_shiftV (es : List Eff) (a : Atom → Bool) (k c : Nat) :
    substAtoms (es.map (Eff.shiftV k c)) a = substAtoms es a := by
  funext x
  simp only [substAtoms, List.length_map, List.getElem?_map]
  congr 1
  apply congrArg (fun f => (List.range es.length).any f)
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; rfl

private structure BindShift (k c : Nat) (θ τ : SubstEnv) : Prop where
  types : ∀ i, τ.types i = (θ.types i).shiftV k c
  rows : τ.rows = θ.rows.map (Eff.shiftV k c)
  ranges : τ.ranges = θ.ranges
  values : ∀ i, τ.values (shiftIndex k c i) =
    (θ.values i).map (termBind (fun j => some (.var (shiftIndex k c j))))

private theorem index_succ (k c i : Nat) :
    shiftIndex k (c+1) (i+1) = shiftIndex k c i + 1 := by
  unfold shiftIndex
  split <;> split <;> omega

private theorem term_shift_lift (k c : Nat) (t : Term) :
    termBind (fun i => some (.var (shiftIndex k (c+1) i)))
        (termBind (fun i => some (.var (i+1))) t) =
      termBind (fun i => some (.var (i+1)))
        (termBind (fun i => some (.var (shiftIndex k c i))) t) := by
  simp only [termBind_comp]
  congr 1
  funext i
  simp only [Option.bind_some, termBind?, index_succ]

private theorem BindShift.up {k c θ τ} (h : BindShift k c θ τ) :
    BindShift k (c+1) θ.up τ.up := by
  constructor
  · intro i
    simp only [SubstEnv.up_types, h.types]
    exact (Ty.shiftV_comm _ 1 k c).symm
  · simp only [SubstEnv.up_rows, h.rows, List.map_map]
    congr 1
    funext e
    exact (Eff.shiftV_comm e 1 k c).symm
  · exact h.ranges
  · intro i
    cases i with
    | zero => simp [upValues, shiftIndex, SubstEnv.up_values]
    | succ i =>
      simp only [index_succ, SubstEnv.up_values, upValues, h.values, Option.map_map]
      congr 1
      funext t
      exact (term_shift_lift k c t).symm

private theorem BindShift.predicate {k c θ τ} (h : BindShift k c θ τ) (p : Pred) :
    predBind τ.values (p.shiftV k c) = (predBind θ.values p).shiftV k c := by
  simp only [Pred.shiftV, predBind_comp]
  congr 1
  funext i
  simpa only [Option.bind_some, termBind?, ← map_rename_eq_bind] using h.values i

mutual
  private theorem bind_shift {k c θ τ} (h : BindShift k c θ τ) (a : Ty) :
      (a.shiftV k c).rawBind τ = (a.rawBind θ).shiftV k c := by
    cases a <;> simp only [Ty.shiftV, Ty.rawBind, h.types, h.ranges,
      bind_shift h, bind_tys_shift h, bind_eff_shift h, bind_tel_shift h]
    case tapp i as => exact (rawApply_shiftV _ _ _ _).symm
    case refined a p => exact congrArg (Ty.refined _) (h.up.predicate p)
  private theorem bind_tel_shift {k c θ τ} (h : BindShift k c θ τ) (t : Tel) :
      Tel.rawBind τ (Tel.shiftV k c t) = Tel.shiftV k c (Tel.rawBind θ t) := by
    cases t <;> simp only [Tel.shiftV, Tel.rawBind, bind_shift h, bind_eff_shift h,
      bind_tel_shift h.up]
  private theorem bind_tys_shift {k c θ τ} (h : BindShift k c θ τ) (as : List Ty) :
      rawBindTys τ (shiftVTys k c as) = shiftVTys k c (rawBindTys θ as) := by
    cases as <;> simp only [shiftVTys, rawBindTys, bind_shift h, bind_tys_shift h]
  private theorem bind_eff_shift {k c θ τ} (h : BindShift k c θ τ) (e : Eff) :
      Eff.rawBind τ (Eff.shiftV k c e) = Eff.shiftV k c (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.shiftV, Eff.rawBind, h.ranges, h.rows, bind_tys_shift h, substAtoms_shiftV]
      congr 1
      simp only [shiftVTys_eq_map, List.map_append]
      congr 1
      simpa only [shiftVTys_eq_map] using (rowFails_shiftV θ.rows a k c).symm
end

private theorem shift_up (θ : SubstEnv) : BindShift 1 0 θ θ.up := by
  refine ⟨fun _ => rfl, rfl, rfl, ?_⟩
  intro i
  simp only [SubstEnv.up_values, shiftIndex, Nat.not_lt_zero, ↓reduceIte, upValues]

theorem Ty.rawBind_up (a : Ty) (θ : SubstEnv) :
    (a.shiftV 1 0).rawBind θ.up = (a.rawBind θ).shiftV 1 0 := bind_shift (shift_up θ) a
theorem Tel.rawBind_up (t : Tel) (θ : SubstEnv) :
    Tel.rawBind θ.up (Tel.shiftV 1 0 t) = Tel.shiftV 1 0 (Tel.rawBind θ t) := bind_tel_shift (shift_up θ) t
theorem rawBindTys_up (as : List Ty) (θ : SubstEnv) :
    rawBindTys θ.up (shiftVTys 1 0 as) = shiftVTys 1 0 (rawBindTys θ as) := bind_tys_shift (shift_up θ) as
theorem Eff.rawBind_up (e : Eff) (θ : SubstEnv) :
    Eff.rawBind θ.up (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.rawBind θ e) := bind_eff_shift (shift_up θ) e

theorem Ty.bind_up (a : Ty) (θ : SubstEnv) :
    (a.shiftV 1 0).bind θ.up = (a.bind θ).shiftV 1 0 := by
  simp only [Ty.bind, Ty.rawBind_up, Ty.norm_shiftV]
theorem Tel.bind_up (t : Tel) (θ : SubstEnv) :
    Tel.bind θ.up (Tel.shiftV 1 0 t) = Tel.shiftV 1 0 (Tel.bind θ t) := by
  simp only [Tel.bind, Tel.rawBind_up, Tel.norm_shiftV]
theorem Eff.bind_up (e : Eff) (θ : SubstEnv) :
    Eff.bind θ.up (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.bind θ e) := by
  simp only [Eff.bind, Eff.rawBind_up, Eff.norm_shiftV]

end Benitoite.Release.Refinement
