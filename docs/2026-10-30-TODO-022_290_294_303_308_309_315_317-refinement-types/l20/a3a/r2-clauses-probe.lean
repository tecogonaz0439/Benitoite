import Benitoite.Release.Refinement.LegacyTables
namespace Benitoite.Release.Refinement.A3aR2
noncomputable section

private theorem all_value (ps : TypeCtx)
    (h : TypeCtx.kinds ps = List.replicate ps.length .value) :
    ps = TypeCtx.values (TypeCtx.constraints ps) := by
  induction ps with
  | nil => rfl
  | cons p ps ih =>
    have hx : p.kind = .value ∧ TypeCtx.kinds ps = List.replicate ps.length .value := by
      simpa only [TypeCtx.kinds, List.map_cons, List.length_cons, List.replicate_succ,
        List.cons.injEq] using h
    change p :: ps = embedTParam p.constraints :: TypeCtx.values (TypeCtx.constraints ps)
    have hp : p = embedTParam p.constraints := by
      have hk := hx.1
      cases p with
      | mk constraints kind =>
        change kind = .value at hk
        cases hk
        rfl
    exact (congrArg (· :: ps) hp).trans (congrArg (embedTParam p.constraints :: ·) (ih hx.2))

private theorem value_prefix (ps C : List Benitoite.Release.TParam) (κ : KindCtx) :
    legacyTypeCtx (ps ++ C) (List.replicate ps.length .value ++ κ) =
      TypeCtx.values ps ++ legacyTypeCtx C κ := by
  induction ps with
  | nil => rfl
  | cons p ps ih =>
    simpa only [legacyTypeCtx, embedTParamsWithKinds, List.cons_append,
      List.length_cons, List.replicate_succ, List.zip_cons_cons, List.map_cons,
      TypeCtx.values, embedTParam] using congrArg (embedTParam p :: ·) ih

theorem primitive_prefix {s0 s} (hs : LegacyPrimSignature s0 s) (he : s.opEff ≠ none)
    (C : List Benitoite.Release.TParam) (κ : KindCtx) :
    legacyTypeCtx (s0.tparams ++ C) (List.replicate s0.tparams.length .value ++ κ) =
      s.tparams ++ legacyTypeCtx C κ := by
  rw [value_prefix]
  have hp := all_value s.tparams (hs.operationKinds he)
  have hp' : TypeCtx.values s0.tparams = s.tparams := by
    simpa only [TypeCtx.constraints, hs.constraints] using hp.symm
  rw [hp']

theorem lookup_prefix {K P0 B0 B b S0 S sg0 sg}
    (tables : LegacyTables K P0 B0 B)
    (oldLookup : Benitoite.Release.opSigAt P0 B0 S0 (.prim b) = some sg0)
    (newLookup : opSigAt (embedProgramWithKinds K P0) B S (.prim b) = some sg)
    (C : List Benitoite.Release.TParam) (κ : KindCtx) :
    legacyTypeCtx (sg0.tparams ++ C) (List.replicate sg0.tparams.length .value ++ κ) =
      sg.tparams ++ legacyTypeCtx C κ := by
  cases h0 : B0.sig b with
  | none => simp [Benitoite.Release.opSigAt, h0] at oldLookup
  | some s0 =>
    obtain ⟨s, hs, hrel⟩ := tables.primitives b s0 h0
    cases he : s0.opEff with
    | none => simp [Benitoite.Release.opSigAt, h0, he] at oldLookup
    | some l =>
      have he' : s.opEff = some l := hrel.opEff.trans he
      simp only [Benitoite.Release.opSigAt, h0, he, Option.some.injEq] at oldLookup
      cases oldLookup
      simp only [opSigAt, hs, he', Option.map_some, Option.some.injEq] at newLookup
      cases newLookup
      exact primitive_prefix hrel (by rw [he']; intro h; cases h) C κ

/-- 子のIHを旧のvalue接頭辞で受け、表から得る等号で新consへ渡す。 -/
theorem clauses_cons_primitive_case {K P0 B0 B b S0 S sg0 sg Ψ Q C κ Γ Φ Δ R eb n k body cs t e}
    (tables : LegacyTables K P0 B0 B)
    (oldLookup : Benitoite.Release.opSigAt P0 B0 S0 (.prim b) = some sg0)
    (newLookup : opSigAt (embedProgramWithKinds K P0) B S (.prim b) = some sg)
    (hc : ClauseSig (embedProgramWithKinds K P0) B eb (.prim b) sg)
    (hnames : NamesWF sg.names sg.params) (hn : n = sg.params.length)
    (hk0 : k = sg0.tparams.length) (hw : sg.WF)
    (bodyIH : HasTypeCQ (embedProgramWithKinds K P0) B (hideBuilders Ψ) Q
      (legacyTypeCtx (sg0.tparams ++ C) (List.replicate sg0.tparams.length .value ++ κ))
      (sg.context Γ t e) (liftMany (sg.params.length + 1) Φ)
      (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length + 1) 0))
      body ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length + 1) 0)
      ((shiftRowsTypes sg.tparams.length 0 e).shiftV (sg.params.length + 1) 0) [])
    (tailIH : HasTypeClausesQ (embedProgramWithKinds K P0) B Ψ Q (legacyTypeCtx C κ)
      Γ Φ R eb cs t e Δ) :
    HasTypeClausesQ (embedProgramWithKinds K P0) B Ψ Q (legacyTypeCtx C κ)
      Γ Φ R eb (.mk (.prim b) n k body :: cs) t e Δ := by
  have hp := lookup_prefix tables oldLookup newLookup C κ
  have hcount := lookup_prefix tables oldLookup newLookup [] []
  rw [value_prefix] at hcount
  simp only [show legacyTypeCtx [] [] = [] from rfl, List.append_nil] at hcount
  have hl : sg.tparams.length = sg0.tparams.length := by
    simpa only [TypeCtx.length_values] using (congrArg List.length hcount).symm
  exact .cons hc hnames hn (hk0.trans hl.symm) hw (by simpa only [hp] using bodyIH) tailIH

end
end Benitoite.Release.Refinement.A3aR2
#print axioms Benitoite.Release.Refinement.A3aR2.primitive_prefix

#print axioms Benitoite.Release.Refinement.A3aR2.lookup_prefix
#print axioms Benitoite.Release.Refinement.A3aR2.clauses_cons_primitive_case
