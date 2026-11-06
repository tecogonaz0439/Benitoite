import Benitoite.Release.Refinement.LegacyBuilderEmbedding
import Benitoite.Release.Refinement.TypeSubstAux

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_eff_sub {e f : Benitoite.Release.Eff} (h : Benitoite.Release.Eff.Sub e f) :
    Eff.Sub (embedEff e) (embedEff f) := by
  refine ⟨?_,?_⟩
  · intro a ha
    change (embedEff e).test a = true at ha
    change (embedEff f).test a = true
    rw [legacy_eff_test] at ha ⊢
    unfold embedAtoms at ha ⊢
    cases ho : a.toOld? with
    | none => simp [ho] at ha
    | some x =>
      simpa only [ho,Option.map_some,Option.getD_some] using
        (h.1 x (by simpa only [ho,Option.map_some,Option.getD_some] using ha))
  · cases e; cases f
    intro t ht
    obtain ⟨u,hu,he⟩ := ht
    obtain ⟨old,hm,rfl⟩ := List.mem_map.mp (by simpa only [embedEff,Eff.fails,embedTys_eq_map] using hu)
    obtain ⟨target,hmem,heq⟩ := h.2 old ⟨old,hm,rfl⟩
    refine ⟨embedTy target,?_,?_⟩
    · simpa only [embedEff,Eff.fails,Benitoite.Release.Eff.fails,embedTys_eq_map] using List.mem_map.mpr ⟨target,hmem,rfl⟩
    · rw [←embedTy_norm,heq,embedTy_norm]; exact he

theorem legacy_union (e f : Benitoite.Release.Eff) :
    embedEff (Benitoite.Release.Eff.union e f) = Eff.union (embedEff e) (embedEff f) := by
  unfold Benitoite.Release.Eff.union Eff.union
  rw [embedEff_norm]
  congr 1
  cases e; cases f
  simp only [embedEff,embedTys_eq_map,List.map_append]
  congr 1
  funext a
  simp only [Eff.test,Eff.atoms,Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms]
  unfold embedAtoms
  cases a.toOld? <;> rfl

theorem legacy_handles (cs : List Benitoite.Release.Clause) (o : OpRef) :
    handles (embedClauses cs) o = Benitoite.Release.handles cs o := by
  induction cs with
  | nil => rfl
  | cons c cs ih => cases c <;> simp only [handles,Benitoite.Release.handles,embedClauses,
      embedClause,List.any_cons,Clause.op,Benitoite.Release.Clause.op] at ih ⊢ <;> rw [ih]

/-- 旧節の署名の対応先は、起点の発行を行う新しい kind にはならない。 -/
theorem LegacyClausesInput.primitive_not_issue {K P0 B0 B Δ cs}
    (input : LegacyClausesInput K P0 B0 B Δ cs) (tables : LegacyTables K P0 B0 B)
    {b s} (hh : Benitoite.Release.handles cs (.prim b) = true) (hs : B.sig b = some s) :
    s.kind ≠ .pathBases := by
  induction cs with
  | nil => cases hh
  | cons c cs ih =>
    cases c with
    | fail e body =>
      exact ih input.2.2 (by simpa [Benitoite.Release.handles,Benitoite.Release.Clause.op] using hh)
    | mk o n k body =>
      simp only [Benitoite.Release.handles,List.any_cons,Bool.or_eq_true,
        Benitoite.Release.Clause.op,beq_iff_eq] at hh
      rcases hh with rfl | hh
      · obtain ⟨sg,lookup,_⟩ := input.1
        cases hb : B0.sig b with
        | none => simp [Benitoite.Release.opSig,Benitoite.Release.opSigAt,hb] at lookup
        | some s0 =>
          obtain ⟨s',hs',corr⟩ := tables.primitives b s0 hb
          cases Option.some.inj (hs.symm.trans hs')
          rw [corr.kind]
          cases s0.kind <;> simp [embedPrimKind]
      · exact ih input.2 hh

theorem legacy_handled_sub {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    (cs : List Benitoite.Release.Clause) {Δ}
    (input : LegacyClausesInput K P0 B0 B Δ cs) :
    Eff.Sub (embedEff (Benitoite.Release.handled P0 B0 cs))
      (handled (embedProgramWithKinds K P0) B (embedClauses cs)) := by
  refine ⟨?_,?_⟩
  · intro a ha
    change (embedEff (Benitoite.Release.handled P0 B0 cs)).test a = true at ha
    rw [legacy_eff_test] at ha
    unfold embedAtoms at ha
    cases a with
    | rho i => cases ha
    | name l ix =>
      have he : effOps (embedProgramWithKinds K P0) B l = Benitoite.Release.effOps P0 B0 l := by
        simp only [effOps,Benitoite.Release.effOps,embedProgramWithKinds_effects,tables.effects]
        rfl
      simp only [handled,Eff.mem,Eff.test,Eff.atoms,he]
      cases hx : Benitoite.Release.effOps P0 B0 l with
      | none =>
        cases ix with
        | rvar i => simp [Atom.toOld?,Benitoite.Release.handled,Benitoite.Release.Eff.ofAtoms,
            Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms,hx] at ha
        | fixed r => cases r <;> simp [Atom.toOld?,Benitoite.Release.handled,Benitoite.Release.Eff.ofAtoms,
            Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms,hx] at ha
      | some os =>
        cases os with
        | nil =>
          cases ix with
          | rvar i => simp [Atom.toOld?,Benitoite.Release.handled,Benitoite.Release.Eff.ofAtoms,
              Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms,hx] at ha
          | fixed r => cases r <;> simp [Atom.toOld?,Benitoite.Release.handled,Benitoite.Release.Eff.ofAtoms,
              Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms,hx] at ha
        | cons o os =>
          have hall : (o :: os).all (Benitoite.Release.handles cs) = true := by
            cases ix with
            | rvar i => simpa [Atom.toOld?,Benitoite.Release.handled,Benitoite.Release.Eff.ofAtoms,
                Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms,hx] using ha
            | fixed r => cases r <;> simpa [Atom.toOld?,Benitoite.Release.handled,Benitoite.Release.Eff.ofAtoms,
                Benitoite.Release.Eff.test,Benitoite.Release.Eff.atoms,hx] using ha
          have hh : handles (embedClauses cs) = Benitoite.Release.handles cs :=
            funext (legacy_handles cs)
          have hn : issuesSelected (embedProgramWithKinds K P0) B l = false := by
            cases hp : P0.effects l with
            | some users => simp [issuesSelected,embedProgramWithKinds_effects,hp]
            | none =>
              have hx' := hx
              simp only [Benitoite.Release.effOps,hp,Option.map_eq_some_iff] at hx'
              obtain ⟨bs,hbs,hmap⟩ := hx'
              simp only [issuesSelected,embedProgramWithKinds_effects,hp,Builtins.issuesIn,tables.effects,hbs]
              apply List.any_eq_false.mpr
              intro b hb
              cases hs : B.sig b with
              | none => simp
              | some s =>
                simp only [decide_eq_true_eq]
                apply input.primitive_not_issue tables _ hs
                apply List.all_eq_true.mp hall (.prim b)
                rw [←hmap]
                exact List.mem_map.mpr ⟨b,hb,rfl⟩
          simpa only [hh,hall,hn,Bool.not_false,Bool.and_true]
  · intro t ht
    obtain ⟨u,hu,_⟩ := ht
    cases hu

namespace LegacyCompCases

theorem handle_case {K P0 B0 B κ Ψ Q C Γ R m cs t em e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyClausesInput K P0 B0 B ⟨κ,C,0,Γ.length⟩ cs)
    (sub : Benitoite.Release.Eff.Sub em (Benitoite.Release.Eff.union e (Benitoite.Release.handled P0 B0 cs)))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m t em L))
    (clauses : LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R em cs t e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.handle m cs) t e L) := by
  intro Φ
  apply HasTypeCQ.C_Handle (body Φ) _ (clauses Φ)
  have hs := legacy_eff_sub sub
  rw [legacy_union] at hs
  have hh := legacy_handled_sub tables cs input
  refine ⟨?_,?_⟩
  · intro a ha
    rcases (Eff.mem_union_iff _ _ _).mp (hs.1 a ha) with ha | ha
    · exact (Eff.mem_union_iff _ _ _).mpr (Or.inl ha)
    · exact (Eff.mem_union_iff _ _ _).mpr (Or.inr (hh.1 a ha))
  · intro u hu
    rcases (Eff.memFail_union_iff _ _ _).mp (hs.2 u hu) with hu | hu
    · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inl hu)
    · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inr (hh.2 u hu))

theorem handleFail_case {K P0 B κ Ψ Q C Γ R m cs t E eb rest ec L}
    (sub : Benitoite.Release.Eff.Sub eb (Benitoite.Release.Eff.union (Benitoite.Release.Eff.singleFail E) rest))
    (noFail : Benitoite.Release.NoFail Q rest)
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m t eb L))
    (clause : LegacyJudgment.Embedded K P0 B (.failure κ Ψ Q C Γ E R cs t ec L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.handle m cs) t
      (Benitoite.Release.Eff.union rest ec) L) := by
  intro Φ
  rw [legacy_union]
  exact .C_Handle_Fail (body Φ)
    (by simpa only [legacy_union,legacy_singleFail] using legacy_eff_sub sub)
    (legacy_NoFail noFail) (clause Φ)

end LegacyCompCases
end
end Benitoite.Release.Refinement
