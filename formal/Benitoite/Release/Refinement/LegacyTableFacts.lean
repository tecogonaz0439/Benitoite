import Benitoite.Release.Refinement.LegacyTables

/-! # 旧表から構成子の形成と不変の変性を導く -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem legacy_varianceArgs_iff (P : Program) (vs : List Variance) (p : Polarity) (as : List Ty) :
    varianceArgsOK P vs p (List.replicate as.length .invariant) as ↔ varianceTysOK P vs .both as := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [List.length_cons, List.replicate_succ, varianceArgsOK,
      Polarity.compose, varianceTysOK, ih]

mutual
  theorem embedTy_invariantVariance {K P0 n} (a : Benitoite.Release.Ty)
      (h : (embedTy a).WF 0 n 0) (p : Polarity) :
      Ty.VarianceOK (embedProgramWithKinds K P0) (List.replicate n .invariant) p (embedTy a) := by
    cases a with
    | base _ | «opaque» _ _ | bytes | ctor _ => trivial
    | tvar i => exact ⟨.invariant, by simp [show i < n from h], by cases p <;> trivial⟩
    | list a | reference a | lazy a | set a | dict _ a => exact embedTy_invariantVariance a h _
    | data d as =>
      simp only [embedTy, Ty.VarianceOK, embedProgramWithKinds_varianceFor]
      rw [legacy_varianceArgs_iff]
      exact embedTys_invariantVariance as h .both
    | fn ns ps r e =>
      exact ⟨embedTys_invariantVariance ps h.2.1 _, embedTy_invariantVariance r h.2.2.1 _,
        embedEff_invariantVariance e h.2.2.2.1 _⟩
    | cont a b e => exact ⟨embedTy_invariantVariance a h.1 _, embedTy_invariantVariance b h.2.1 _,
        embedEff_invariantVariance e h.2.2.1 _⟩
    | map a b => exact ⟨embedTy_invariantVariance a h.1 _, embedTy_invariantVariance b h.2 _⟩
    | tapp i as => exact ⟨⟨.invariant, by simp [h.1], trivial⟩,
        embedTys_invariantVariance as h.2 .both⟩
  theorem embedTys_invariantVariance {K P0 n} (as : List Benitoite.Release.Ty)
      (h : Ty.WFList 0 n 0 (embedTys as)) (p : Polarity) :
      varianceTysOK (embedProgramWithKinds K P0) (List.replicate n .invariant) p (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embedTy_invariantVariance a h.1 p, embedTys_invariantVariance as h.2 p⟩
  theorem embedEff_invariantVariance {K P0 n} (e : Benitoite.Release.Eff)
      (h : (embedEff e).WF 0 n 0) (p : Polarity) :
      Eff.VarianceOK (embedProgramWithKinds K P0) (List.replicate n .invariant) p (embedEff e) := by
    cases e; exact embedTys_invariantVariance _ h .both
end

theorem LegacyTables.dataArity {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    {c cd} (hc : P0.cons c = some cd) :
    (embedProgramWithKinds K P0).DataArity cd.data cd.ntys := by
  refine ⟨⟨c, embedConDecl cd, by simp only [embedProgramWithKinds_cons, hc, Option.map_some], rfl⟩, ?_⟩
  intro c' cd' hc' hd
  obtain ⟨old, ho, rfl⟩ := Option.map_eq_some_iff.mp hc'
  exact tables.constructorArity c' old c cd ho hc hd

theorem LegacyTables.constructor_scoped {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    {c cd} (hc : P0.cons c = some cd) :
    (embedConDecl cd).Scoped (embedProgramWithKinds K P0) := by
  intro a ha
  obtain ⟨old, hold, rfl⟩ := List.mem_map.mp (by simpa [embedConDecl] using ha)
  exact ⟨tables.constructorScope c cd hc old hold, tables.constructorFields c cd hc old hold⟩

theorem LegacyTables.varianceValid {K P0 B0 B} (tables : LegacyTables K P0 B0 B) :
    (embedProgramWithKinds K P0).VarianceValid := by
  constructor
  · intro d info h; cases h
  · intro c cd hc
    obtain ⟨old, ho, rfl⟩ := Option.map_eq_some_iff.mp hc
    refine ⟨?_, ?_⟩
    · intro info h; cases h
    · intro a ha
      obtain ⟨oldA, hA, rfl⟩ := List.mem_map.mp (by simpa [embedConDecl] using ha)
      obtain ⟨annotation, kind⟩ := tables.constructorFields c old ho oldA hA
      refine ⟨annotation, kind, ?_⟩
      exact embedTy_invariantVariance oldA
        (by simpa only [List.length_replicate, List.length_nil, embedConDecl] using annotation.wf) .positive

end
end Benitoite.Release.Refinement
