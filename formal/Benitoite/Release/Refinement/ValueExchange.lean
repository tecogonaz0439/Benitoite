import Benitoite.Release.Refinement.ValueSubst

/-!
# 値に依存する型・行の像と値置換の交換

交換先の像には値置換を一度だけ適用する。
-/
namespace Benitoite.Release.Refinement

mutual
  def Ty.rawSubstV (σ : ObservationEnv) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (substVTys σ as)
    | .list a => .list (a.rawSubstV σ)
    | .fn ns ps r e => .fn ns (substVTys σ ps) (r.rawSubstV σ) (Eff.rawSubstV σ e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.rawSubstV σ)
    | .lazy a => .lazy (a.rawSubstV σ)
    | .cont b t e => .cont (b.rawSubstV σ) (t.rawSubstV σ) (Eff.rawSubstV σ e)
    | .map a b => .map (a.rawSubstV σ) (b.rawSubstV σ)
    | .set a => .set (a.rawSubstV σ)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.rawSubstV σ)
    | .tapp i as => .tapp i (substVTys σ as)
    | .ctor c => .ctor c
    | .refined a p => .refined (a.rawSubstV σ) (predBind (upValues σ) p)
    | .dependentFn t => .dependentFn (Tel.rawSubstV σ t)
    | .external id as => .external id (substVTys σ as)
    | .scoped o kind ix => .scoped o kind ix
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  def Tel.rawSubstV (σ : ObservationEnv) : Tel → Tel
    | .done r e => .done (r.rawSubstV σ) (Eff.rawSubstV σ e)
    | .param n a t => .param n (a.rawSubstV σ) (Tel.rawSubstV (upValues σ) t)
  def substVTys (σ : ObservationEnv) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawSubstV σ :: substVTys σ as
  def Eff.rawSubstV (σ : ObservationEnv) : Eff → Eff
    | .mk a fs => .mk a (substVTys σ fs)
end

@[simp] theorem substVTys_eq_map (σ : ObservationEnv) (as : List Ty) :
    substVTys σ as = as.map (Ty.rawSubstV σ) := by
  induction as <;> simp_all [substVTys]

@[simp] theorem SubstEnv.valuesOnly_up (σ : ObservationEnv) :
    (SubstEnv.valuesOnly σ).up = SubstEnv.valuesOnly (upValues σ) := rfl

mutual
  theorem Ty.rawSubstV_eq_rawBind (a : Ty) (σ : ObservationEnv) :
      a.rawSubstV σ = a.rawBind ⟨Ty.tvar, [], [], σ⟩ := by
    cases a <;> simp only [Ty.rawSubstV, Ty.rawBind, Ty.rawSubstV_eq_rawBind,
      substVTys_eq_rawBind, Eff.rawSubstV_eq_rawBind, RangeIx.inst_nil, rawApply, Tel.rawSubstV_eq_rawBind]
    all_goals simp [SubstEnv.valuesOnly, rawApply]
  theorem Tel.rawSubstV_eq_rawBind (t : Tel) (σ : ObservationEnv) :
      Tel.rawSubstV σ t = Tel.rawBind ⟨Ty.tvar, [], [], σ⟩ t := by
    cases t <;> simp only [Tel.rawSubstV, Tel.rawBind, SubstEnv.up,
      Ty.rawSubstV_eq_rawBind, Eff.rawSubstV_eq_rawBind, Tel.rawSubstV_eq_rawBind, Ty.shiftV, List.map_nil]
  theorem substVTys_eq_rawBind (as : List Ty) (σ : ObservationEnv) :
      substVTys σ as = rawBindTys ⟨Ty.tvar, [], [], σ⟩ as := by
    cases as <;> simp only [substVTys, rawBindTys, Ty.rawSubstV_eq_rawBind, substVTys_eq_rawBind]
  theorem Eff.rawSubstV_eq_rawBind (e : Eff) (σ : ObservationEnv) :
      Eff.rawSubstV σ e = Eff.rawBind ⟨Ty.tvar, [], [], σ⟩ e := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawSubstV, Eff.rawBind, substVTys_eq_rawBind, instAtoms_nil,
        substAtoms_nil, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil]
end

theorem Ty.rawSubstV_up (a : Ty) (σ : ObservationEnv) :
    (a.shiftV 1 0).rawSubstV (upValues σ) = (a.rawSubstV σ).shiftV 1 0 := by
  simpa only [Ty.rawSubstV_eq_rawBind, SubstEnv.up, Ty.shiftV, List.map_nil] using a.rawBind_up ⟨Ty.tvar, [], [], σ⟩
theorem Eff.rawSubstV_up (e : Eff) (σ : ObservationEnv) :
    Eff.rawSubstV (upValues σ) (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.rawSubstV σ e) := by
  simpa only [Eff.rawSubstV_eq_rawBind, SubstEnv.up, Ty.shiftV, List.map_nil] using e.rawBind_up ⟨Ty.tvar, [], [], σ⟩

def SubstEnv.mapValues (θ : SubstEnv) (σ : ObservationEnv) : SubstEnv :=
  ⟨fun i => (θ.types i).rawSubstV σ, θ.rows.map (Eff.rawSubstV σ), θ.ranges, (fun i => some (.var i))⟩

@[simp] theorem SubstEnv.mapValues_types (θ : SubstEnv) (σ : ObservationEnv) (i : Nat) :
    (θ.mapValues σ).types i = (θ.types i).rawSubstV σ := rfl
@[simp] theorem SubstEnv.mapValues_rows (θ : SubstEnv) (σ : ObservationEnv) :
    (θ.mapValues σ).rows = θ.rows.map (Eff.rawSubstV σ) := rfl
@[simp] theorem SubstEnv.mapValues_ranges (θ : SubstEnv) (σ : ObservationEnv) :
    (θ.mapValues σ).ranges = θ.ranges := rfl
@[simp] theorem SubstEnv.mapValues_values (θ : SubstEnv) (σ : ObservationEnv) :
    (θ.mapValues σ).values = (fun i => some (.var i)) := rfl

@[simp] theorem SubstEnv.mapValues_up (θ : SubstEnv) (σ : ObservationEnv) :
    θ.up.mapValues (upValues σ) = (θ.mapValues σ).up := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i; exact Ty.rawSubstV_up (θ.types i) σ
  · change (θ.rows.map (Eff.shiftV 1 0)).map (Eff.rawSubstV (upValues σ)) =
      (θ.rows.map (Eff.rawSubstV σ)).map (Eff.shiftV 1 0)
    simp only [List.map_map]; congr 1; funext e; exact Eff.rawSubstV_up e σ
  · exact upValues_id.symm

private theorem rawApply_substV (t : Ty) (as : List Ty) (σ : ObservationEnv) :
    (rawApply t as).rawSubstV σ = rawApply (t.rawSubstV σ) (substVTys σ as) := by
  cases t <;> simp only [rawApply, Ty.rawSubstV]
  case ctor t =>
    cases t <;> cases as <;> simp only [Ty.rawSubstV, substVTys,
      List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
    rename_i a as
    cases as <;> rfl

private theorem substAtoms_substV (es : List Eff) (a : Atom → Bool) (σ : ObservationEnv) :
    substAtoms (es.map (Eff.rawSubstV σ)) a = substAtoms es a := by
  funext x
  simp only [substAtoms, List.length_map, List.getElem?_map]
  congr 1
  apply congrArg (fun f => (List.range es.length).any f)
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; rfl

private theorem rowFails_substV (es : List Eff) (a : Atom → Bool) (σ : ObservationEnv) :
    substVTys σ (rowFails es a) = rowFails (es.map (Eff.rawSubstV σ)) a := by
  simp only [substVTys_eq_map, rowFails, List.length_map, List.map_flatMap, List.getElem?_map]
  congr 1
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; simp only [Option.map_some, Eff.rawSubstV, Eff.fails, substVTys_eq_map]

mutual
  theorem Ty.rawBind_substV (a : Ty) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i))) (σ : ObservationEnv) :
      (a.rawBind θ).rawSubstV σ = (a.rawSubstV σ).rawBind (θ.mapValues σ) := by
    cases a <;> simp only [Ty.rawBind, Ty.rawSubstV, SubstEnv.mapValues_types,
      SubstEnv.mapValues_ranges, SubstEnv.mapValues_values, hv, upValues_id, predBind_id,
      Ty.rawBind_substV, ← rawBindTys_substV, Eff.rawBind_substV, Tel.rawBind_substV]
    case tapp i as => exact rawApply_substV _ _ _
  theorem Tel.rawBind_substV (t : Tel) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i))) (σ : ObservationEnv) :
      Tel.rawSubstV σ (Tel.rawBind θ t) = Tel.rawBind (θ.mapValues σ) (Tel.rawSubstV σ t) := by
    have hu : θ.up.values = (fun i => some (.var i)) := by simp [hv]
    cases t <;> simp only [Tel.rawBind, Tel.rawSubstV, Ty.rawBind_substV _ θ hv,
      Eff.rawBind_substV _ θ hv, Tel.rawBind_substV _ θ.up hu, SubstEnv.mapValues_up]
  theorem rawBindTys_substV (as : List Ty) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i))) (σ : ObservationEnv) :
      substVTys σ (rawBindTys θ as) = rawBindTys (θ.mapValues σ) (substVTys σ as) := by
    cases as <;> simp only [substVTys, rawBindTys, Ty.rawBind_substV _ θ hv, rawBindTys_substV _ θ hv]
  theorem Eff.rawBind_substV (e : Eff) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i))) (σ : ObservationEnv) :
      Eff.rawSubstV σ (Eff.rawBind θ e) = Eff.rawBind (θ.mapValues σ) (Eff.rawSubstV σ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, Eff.rawSubstV, SubstEnv.mapValues_rows, SubstEnv.mapValues_ranges,
        substAtoms_substV, ← rawBindTys_substV _ θ hv]
      congr 1
      simp only [substVTys_eq_map, List.map_append]
      congr 1
      simpa only [substVTys_eq_map] using rowFails_substV θ.rows a σ
end

/-- 正規化を含めて型・行・範囲の置換と値置換を交換する。 -/
theorem Ty.bind_substV (a : Ty) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i))) (σ : ObservationEnv) :
    (a.bind θ).substV σ = (a.substV σ).bind (θ.mapValues σ) := by
  simp only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, Ty.norm_rawBind]
  rw [← Ty.rawSubstV_eq_rawBind, ← Ty.rawSubstV_eq_rawBind, Ty.rawBind_substV a θ hv σ]

theorem Eff.bind_substV (e : Eff) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i))) (σ : ObservationEnv) :
    Eff.substV σ (Eff.bind θ e) = Eff.bind (θ.mapValues σ) (Eff.substV σ e) := by
  simp only [Eff.substV, Eff.bind, SubstEnv.valuesOnly, Eff.norm_rawBind]
  rw [← Eff.rawSubstV_eq_rawBind, ← Eff.rawSubstV_eq_rawBind, Eff.rawBind_substV e θ hv σ]

mutual
  theorem shiftTypes_substV (a : Ty) (k c : Nat) (σ : ObservationEnv) :
      (shiftTypes k c a).rawSubstV σ = shiftTypes k c (a.rawSubstV σ) := by
    cases a <;> simp only [shiftTypes, Ty.rawSubstV, shiftTypes_substV,
      shiftTypesList_substV, shiftRowsTypes_substV, shiftTelTypes_substV]
  theorem shiftTelTypes_substV (t : Tel) (k c : Nat) (σ : ObservationEnv) :
      Tel.rawSubstV σ (shiftTelTypes k c t) = shiftTelTypes k c (Tel.rawSubstV σ t) := by
    cases t <;> simp only [shiftTelTypes, Tel.rawSubstV, shiftTypes_substV, shiftRowsTypes_substV, shiftTelTypes_substV]
  theorem shiftTypesList_substV (as : List Ty) (k c : Nat) (σ : ObservationEnv) :
      substVTys σ (shiftTypesList k c as) = shiftTypesList k c (substVTys σ as) := by
    cases as <;> simp only [shiftTypesList, substVTys, shiftTypes_substV, shiftTypesList_substV]
  theorem shiftRowsTypes_substV (e : Eff) (k c : Nat) (σ : ObservationEnv) :
      Eff.rawSubstV σ (shiftRowsTypes k c e) = shiftRowsTypes k c (Eff.rawSubstV σ e) := by
    cases e
    simp only [shiftRowsTypes, Eff.rawSubstV, shiftTypesList_substV]
end

theorem typeEnvAt_mapValues (c : Nat) (ts : List Ty) (es : List Eff) (σ : ObservationEnv) :
    (typeEnvAt c ts es).mapValues σ =
      typeEnvAt c (ts.map (Ty.rawSubstV σ)) (es.map (Eff.rawSubstV σ)) := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i
    simp only [typeEnvAt, List.length_map, List.getElem?_map]
    split
    · rfl
    · split
      · cases hi : ts[i-c]? with
        | none => rfl
        | some a => exact shiftTypes_substV a c 0 σ
      · rfl
  · simp only [typeEnvAt, List.map_map]
    congr 1
    funext e
    exact shiftRowsTypes_substV e c 0 σ

theorem Ty.substAt_substV (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) (σ : ObservationEnv) :
    (a.substAt c ts es).substV σ =
      (a.substV σ).substAt c (ts.map (Ty.rawSubstV σ)) (es.map (Eff.rawSubstV σ)) := by
  change (a.bind _).substV σ = (a.substV σ).bind _
  rw [Ty.bind_substV a _ rfl, typeEnvAt_mapValues]

theorem Eff.substAt_substV (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) (σ : ObservationEnv) :
    Eff.substV σ (Eff.substAt c ts es e) =
      Eff.substAt c (ts.map (Ty.rawSubstV σ)) (es.map (Eff.rawSubstV σ)) (Eff.substV σ e) := by
  change Eff.substV σ (Eff.bind _ e) = Eff.bind _ (Eff.substV σ e)
  rw [Eff.bind_substV e _ rfl, typeEnvAt_mapValues]

end Benitoite.Release.Refinement
