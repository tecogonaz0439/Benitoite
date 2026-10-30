import Benitoite.Release.Refinement.ValueExchange

/-!
# 型・行の置換と範囲の置換の交換

範囲変数の像は開いた範囲位置でもよい。型・行の像も同時に写す。
-/
namespace Benitoite.Release.Refinement

@[simp] theorem mapRangeAtoms_spec (ρ : Nat → Scope.Signature.Ix) (a : Atom → Bool) (x : Atom) :
    mapRangeAtoms ρ a x = true ↔ ∃ y, a y = true ∧ mapAtomRanges ρ y = x := by
  classical
  exact decide_eq_true_iff

@[simp] theorem mapRangeAtoms_rho (ρ : Nat → Scope.Signature.Ix) (a : Atom → Bool) (i : Nat) :
    mapRangeAtoms ρ a (.rho i) = a (.rho i) := by
  apply Bool.eq_iff_iff.mpr
  rw [mapRangeAtoms_spec]
  constructor
  · rintro ⟨y, hy, he⟩
    cases y with
    | name l ix => cases he
    | rho j => cases he; exact hy
  · intro h; exact ⟨.rho i, h, rfl⟩

private theorem substAtoms_spec (es : List Eff) (a : Atom → Bool) (x : Atom) :
    substAtoms es a x = true ↔
      (match x with | .name l r => a (.name l r) = true | .rho i => es.length ≤ i ∧ a (.rho i) = true) ∨
      ∃ i f, es[i]? = some f ∧ a (.rho i) = true ∧ f.mem x :=
  Eff.mem_substAtoms es (.mk a []) x

private theorem mapRangeAtoms_substAtoms (ρ : Nat → Scope.Signature.Ix) (es : List Eff) (a : Atom → Bool) :
    mapRangeAtoms ρ (substAtoms es a) = substAtoms (es.map (Eff.rawMapRanges ρ)) (mapRangeAtoms ρ a) := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [mapRangeAtoms_spec, substAtoms_spec]
  constructor
  · rintro ⟨y, hy, rfl⟩
    rcases (substAtoms_spec es a y).mp hy with hk | ⟨i, f, hf, hi, hfy⟩
    · left
      cases y with
      | name l ix => exact (mapRangeAtoms_spec ρ a _).mpr ⟨_, hk, rfl⟩
      | rho i => exact ⟨by simpa only [List.length_map] using hk.1,
          by simpa only [mapRangeAtoms_rho] using hk.2⟩
    · right
      refine ⟨i, Eff.rawMapRanges ρ f, by simp only [List.getElem?_map, hf, Option.map_some],
        by simpa only [mapRangeAtoms_rho] using hi, ?_⟩
      cases f with
      | mk fa fs => exact (mapRangeAtoms_spec ρ fa _).mpr ⟨_, hfy, rfl⟩
  · rintro (hk | ⟨i, g, hg, hi, hgx⟩)
    · cases x with
      | name l ix =>
        obtain ⟨y, hy, he⟩ := (mapRangeAtoms_spec ρ a _).mp hk
        refine ⟨y, (substAtoms_spec es a y).mpr (Or.inl ?_), he⟩
        cases y with
        | name _ _ => exact hy
        | rho i => cases he
      | rho i =>
        refine ⟨.rho i, (substAtoms_spec es a _).mpr (Or.inl ⟨?_, ?_⟩), rfl⟩
        · simpa only [List.length_map] using hk.1
        · simpa only [mapRangeAtoms_rho] using hk.2
    · cases hf : es[i]? with
      | none => simp [List.getElem?_map, hf] at hg
      | some f =>
        simp only [List.getElem?_map, hf, Option.map_some, Option.some.injEq] at hg
        cases hg
        cases f with
        | mk fa fs =>
          obtain ⟨y, hy, he⟩ := (mapRangeAtoms_spec ρ fa x).mp hgx
          refine ⟨y, (substAtoms_spec es a y).mpr (Or.inr ⟨i, _, hf, ?_, hy⟩), he⟩
          simpa only [mapRangeAtoms_rho] using hi

noncomputable def SubstEnv.mapRanges (θ : SubstEnv) (ρ : Nat → Scope.Signature.Ix) : SubstEnv :=
  ⟨fun i => (θ.types i).rawMapRanges ρ, θ.rows.map (Eff.rawMapRanges ρ), [], Term.var⟩

@[simp] theorem SubstEnv.mapRanges_types (θ : SubstEnv) (ρ : Nat → Scope.Signature.Ix) (i : Nat) :
    (θ.mapRanges ρ).types i = (θ.types i).rawMapRanges ρ := rfl
@[simp] theorem SubstEnv.mapRanges_rows (θ : SubstEnv) (ρ : Nat → Scope.Signature.Ix) :
    (θ.mapRanges ρ).rows = θ.rows.map (Eff.rawMapRanges ρ) := rfl
@[simp] theorem SubstEnv.mapRanges_ranges (θ : SubstEnv) (ρ : Nat → Scope.Signature.Ix) :
    (θ.mapRanges ρ).ranges = [] := rfl
@[simp] theorem SubstEnv.mapRanges_values (θ : SubstEnv) (ρ : Nat → Scope.Signature.Ix) :
    (θ.mapRanges ρ).values = Term.var := rfl

private theorem rawApply_mapRanges (t : Ty) (as : List Ty) (ρ : Nat → Scope.Signature.Ix) :
    (rawApply t as).rawMapRanges ρ = rawApply (t.rawMapRanges ρ) (mapRangesTys ρ as) := by
  cases t <;> simp only [rawApply, Ty.rawMapRanges]
  case ctor t =>
    cases t <;> cases as <;> simp only [Ty.rawMapRanges, mapRangesTys,
      List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
    rename_i a as
    cases as <;> rfl

private theorem rowFails_mapRanges (es : List Eff) (a : Atom → Bool) (ρ : Nat → Scope.Signature.Ix) :
    mapRangesTys ρ (rowFails es a) = rowFails (es.map (Eff.rawMapRanges ρ)) (mapRangeAtoms ρ a) := by
  simp only [mapRangesTys_eq_map, rowFails, List.length_map, List.map_flatMap,
    List.getElem?_map, mapRangeAtoms_rho]
  congr 1
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; simp only [Option.map_some, Eff.rawMapRanges, Eff.fails, mapRangesTys_eq_map]

mutual
  theorem Ty.rawBind_mapRanges (a : Ty) (θ : SubstEnv) (hv : θ.values = Term.var)
      (hr : θ.ranges = []) (ρ : Nat → Scope.Signature.Ix) :
      (a.rawBind θ).rawMapRanges ρ = (a.rawMapRanges ρ).rawBind (θ.mapRanges ρ) := by
    cases a <;> simp only [Ty.rawBind, Ty.rawMapRanges, SubstEnv.mapRanges_types,
      SubstEnv.mapRanges_ranges, SubstEnv.mapRanges_values, hv, hr, Scope.Signature.Ix.inst_nil,
      upValues_id, predBind_id, Ty.rawBind_mapRanges _ θ hv hr,
      ← rawBindTys_mapRanges _ θ hv hr, Eff.rawBind_mapRanges _ θ hv hr]
    case tapp i as => exact rawApply_mapRanges _ _ _
  theorem rawBindTys_mapRanges (as : List Ty) (θ : SubstEnv) (hv : θ.values = Term.var)
      (hr : θ.ranges = []) (ρ : Nat → Scope.Signature.Ix) :
      mapRangesTys ρ (rawBindTys θ as) = rawBindTys (θ.mapRanges ρ) (mapRangesTys ρ as) := by
    cases as <;> simp only [mapRangesTys, rawBindTys, Ty.rawBind_mapRanges _ θ hv hr, rawBindTys_mapRanges _ θ hv hr]
  theorem Eff.rawBind_mapRanges (e : Eff) (θ : SubstEnv) (hv : θ.values = Term.var)
      (hr : θ.ranges = []) (ρ : Nat → Scope.Signature.Ix) :
      Eff.rawMapRanges ρ (Eff.rawBind θ e) = Eff.rawBind (θ.mapRanges ρ) (Eff.rawMapRanges ρ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, Eff.rawMapRanges, SubstEnv.mapRanges_rows, SubstEnv.mapRanges_ranges,
        hr, instAtoms_nil, mapRangeAtoms_substAtoms, ← rawBindTys_mapRanges _ θ hv hr]
      congr 1
      simp only [mapRangesTys_eq_map, List.map_append]
      congr 1
      simpa only [mapRangesTys_eq_map] using rowFails_mapRanges θ.rows a ρ
end

theorem Ty.bind_mapRanges (a : Ty) (θ : SubstEnv) (hv : θ.values = Term.var)
    (hr : θ.ranges = []) (ρ : Nat → Scope.Signature.Ix) :
    (a.bind θ).mapRanges ρ = (a.mapRanges ρ).bind (θ.mapRanges ρ) := by
  simp only [Ty.mapRanges, Ty.bind, Ty.norm_rawMapRanges, Ty.norm_rawBind]
  rw [Ty.rawBind_mapRanges a θ hv hr ρ]

theorem Eff.bind_mapRanges (e : Eff) (θ : SubstEnv) (hv : θ.values = Term.var)
    (hr : θ.ranges = []) (ρ : Nat → Scope.Signature.Ix) :
    Eff.mapRanges ρ (Eff.bind θ e) = Eff.bind (θ.mapRanges ρ) (Eff.mapRanges ρ e) := by
  simp only [Eff.mapRanges, Eff.bind, Eff.norm_rawMapRanges, Eff.norm_rawBind]
  rw [Eff.rawBind_mapRanges e θ hv hr ρ]

mutual
  theorem shiftTypes_mapRanges (a : Ty) (k c : Nat) (ρ : Nat → Scope.Signature.Ix) :
      (shiftTypes k c a).rawMapRanges ρ = shiftTypes k c (a.rawMapRanges ρ) := by
    cases a <;> simp only [shiftTypes, Ty.rawMapRanges, shiftTypes_mapRanges,
      shiftTypesList_mapRanges, shiftRowsTypes_mapRanges]
  theorem shiftTypesList_mapRanges (as : List Ty) (k c : Nat) (ρ : Nat → Scope.Signature.Ix) :
      mapRangesTys ρ (shiftTypesList k c as) = shiftTypesList k c (mapRangesTys ρ as) := by
    cases as <;> simp only [shiftTypesList, mapRangesTys, shiftTypes_mapRanges, shiftTypesList_mapRanges]
  theorem shiftRowsTypes_mapRanges (e : Eff) (k c : Nat) (ρ : Nat → Scope.Signature.Ix) :
      Eff.rawMapRanges ρ (shiftRowsTypes k c e) = shiftRowsTypes k c (Eff.rawMapRanges ρ e) := by
    cases e
    simp only [shiftRowsTypes, Eff.rawMapRanges, shiftTypesList_mapRanges]
end

theorem typeEnvAt_mapRanges (c : Nat) (ts : List Ty) (es : List Eff) (ρ : Nat → Scope.Signature.Ix) :
    (typeEnvAt c ts es).mapRanges ρ =
      typeEnvAt c (ts.map (Ty.rawMapRanges ρ)) (es.map (Eff.rawMapRanges ρ)) := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i
    simp only [typeEnvAt, List.length_map, List.getElem?_map]
    split
    · rfl
    · split
      · cases hi : ts[i-c]? with
        | none => rfl
        | some a => exact shiftTypes_mapRanges a c 0 ρ
      · rfl
  · simp only [typeEnvAt, List.map_map]
    congr 1
    funext e
    exact shiftRowsTypes_mapRanges e c 0 ρ

theorem Ty.substAt_mapRanges (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) (ρ : Nat → Scope.Signature.Ix) :
    (a.substAt c ts es).mapRanges ρ =
      (a.mapRanges ρ).substAt c (ts.map (Ty.rawMapRanges ρ)) (es.map (Eff.rawMapRanges ρ)) := by
  change (a.bind _).mapRanges ρ = (a.mapRanges ρ).bind _
  rw [Ty.bind_mapRanges a _ rfl rfl, typeEnvAt_mapRanges]

theorem Eff.substAt_mapRanges (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) (ρ : Nat → Scope.Signature.Ix) :
    Eff.mapRanges ρ (Eff.substAt c ts es e) =
      Eff.substAt c (ts.map (Ty.rawMapRanges ρ)) (es.map (Eff.rawMapRanges ρ)) (Eff.mapRanges ρ e) := by
  change Eff.mapRanges ρ (Eff.bind _ e) = Eff.bind _ (Eff.mapRanges ρ e)
  rw [Eff.bind_mapRanges e _ rfl rfl, typeEnvAt_mapRanges]

mutual
  theorem Ty.rawMapRanges_rawSubstV (a : Ty) (ρ : Nat → Scope.Signature.Ix) (σ : Nat → Term) :
      (a.rawMapRanges ρ).rawSubstV σ = (a.rawSubstV σ).rawMapRanges ρ := by
    cases a <;> simp only [Ty.rawMapRanges, Ty.rawSubstV, Ty.rawMapRanges_rawSubstV,
      mapRangesTys_substVTys, Eff.rawMapRanges_rawSubstV]
  theorem mapRangesTys_substVTys (as : List Ty) (ρ : Nat → Scope.Signature.Ix) (σ : Nat → Term) :
      substVTys σ (mapRangesTys ρ as) = mapRangesTys ρ (substVTys σ as) := by
    cases as <;> simp only [mapRangesTys, substVTys, Ty.rawMapRanges_rawSubstV, mapRangesTys_substVTys]
  theorem Eff.rawMapRanges_rawSubstV (e : Eff) (ρ : Nat → Scope.Signature.Ix) (σ : Nat → Term) :
      Eff.rawSubstV σ (Eff.rawMapRanges ρ e) = Eff.rawMapRanges ρ (Eff.rawSubstV σ e) := by
    cases e
    simp only [Eff.rawMapRanges, Eff.rawSubstV, mapRangesTys_substVTys]
end

theorem Ty.mapRanges_substV (a : Ty) (ρ : Nat → Scope.Signature.Ix) (σ : Nat → Term) :
    (a.mapRanges ρ).substV σ = (a.substV σ).mapRanges ρ := by
  simp only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, Ty.mapRanges, Ty.norm_rawBind, Ty.norm_rawMapRanges]
  rw [← Ty.rawSubstV_eq_rawBind, ← Ty.rawSubstV_eq_rawBind, Ty.rawMapRanges_rawSubstV]

theorem Eff.mapRanges_substV (e : Eff) (ρ : Nat → Scope.Signature.Ix) (σ : Nat → Term) :
    Eff.substV σ (Eff.mapRanges ρ e) = Eff.mapRanges ρ (Eff.substV σ e) := by
  simp only [Eff.substV, Eff.bind, SubstEnv.valuesOnly, Eff.mapRanges, Eff.norm_rawBind, Eff.norm_rawMapRanges]
  rw [← Eff.rawSubstV_eq_rawBind, ← Eff.rawSubstV_eq_rawBind, Eff.rawMapRanges_rawSubstV]

end Benitoite.Release.Refinement
