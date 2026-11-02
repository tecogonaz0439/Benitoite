import Benitoite.Release.Refinement.LegacyShiftAlgebra

namespace Benitoite.Release.Refinement
noncomputable section

def embedOpSig (sg : Benitoite.Release.OpSig) : OpSig :=
  ⟨TypeCtx.values sg.tparams,sg.names,embedTys sg.params,embedTy sg.ret,sg.eff⟩

theorem legacy_instTarget (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
    embedTy (a.instTarget rs) = (embedTy a).instTarget (rs.map embedRange) := by
  cases a <;> try rfl
  rename_i o ix
  cases ix with
  | fixed r => rfl
  | rvar i => cases h : rs[i]? <;> simp [Benitoite.Release.Ty.instTarget,Ty.instTarget,
      embedTy,embedIx,Scope.Signature.Ix.inst,RangeIx.inst,List.getElem?_map,h,embedRange]

theorem LegacyTables.opSigAt {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    {o S sg} (lookup : Benitoite.Release.opSigAt P0 B0 S o = some sg) :
    opSigAt (embedProgramWithKinds K P0) B (embedRange S) o = some (embedOpSig sg) := by
  cases o with
  | fail => cases lookup
  | user o =>
    cases ho : P0.ops o with
    | none => simp [Benitoite.Release.opSigAt,ho] at lookup
    | some od =>
      simp only [Benitoite.Release.opSigAt,ho,Option.map_some,Option.some.injEq] at lookup
      subst sg
      simp only [Refinement.opSigAt,embedProgramWithKinds_ops,ho,Option.map_some,embedOpSig,
        embedOpDecl,legacy_embedParameters,legacy_shiftV]
  | prim b =>
    cases hb : B0.sig b with
    | none => simp [Benitoite.Release.opSigAt,hb] at lookup
    | some s0 =>
      obtain ⟨s,hs,corr⟩ := tables.primitives b s0 hb
      cases he : s0.opEff with
      | none => simp [Benitoite.Release.opSigAt,hb,he] at lookup
      | some l =>
        simp only [Benitoite.Release.opSigAt,hb,he,Option.some.injEq] at lookup
        subst sg
        have ckind : TypeCtx.kinds s.tparams = List.replicate s.tparams.length .value :=
          corr.operationKinds (by rw [corr.opEff,he]; simp)
        have values (C : TypeCtx) (h : TypeCtx.kinds C = List.replicate C.length .value) :
            C = TypeCtx.values (TypeCtx.constraints C) := by
          induction C with
          | nil => rfl
          | cons p ps ih =>
            have hp : p.kind = .value := (List.cons.inj h).1
            have ht : TypeCtx.kinds ps = List.replicate ps.length .value := (List.cons.inj h).2
            cases p
            simp only at hp
            subst_vars
            exact congrArg (_ :: ·) (ih ht)
        have ctparam : s.tparams = TypeCtx.values s0.tparams := by
          rw [values s.tparams ckind,TypeCtx.constraints,corr.constraints]
        simp only [Refinement.opSigAt,hs,corr.opEff,he,Option.map_some,embedOpSig,ctparam,
          corr.names,corr.params,corr.ret,legacy_embedParameters,legacy_shiftV,corr.rkinds]
        congr 2
        simp only [embedTys_eq_map,List.map_map,Function.comp_def]
        apply List.map_congr_left
        intro a _
        simpa only [List.map_replicate,Benitoite.Release.PrimSig.nranges] using
          (legacy_instTarget a (List.replicate s0.nranges S)).symm

theorem legacy_clauseRange {e : Benitoite.Release.Eff} {l S}
    (h : e.ClauseRangeIs l S) : (embedEff e).ClauseRangeIs l (embedRange S) := by
  refine ⟨?_,?_,?_⟩
  · intro i hi
    exact h.1 i (by simpa only [Eff.mem,legacy_eff_test,embedAtoms,Atom.toOld?,Option.map_some,
      Option.getD_some] using hi)
  · change (embedEff e).test (embedAtom (.name l (.fixed S))) = true
    rw [legacy_eff_test,embedAtoms_embed]
    exact h.2.1
  · intro ix hi
    obtain ⟨old,ho,he⟩ := (embedAtoms_true e.atoms (.name l ix)).mp
      (by simpa only [Eff.mem,legacy_eff_test] using hi)
    cases old with
    | rho i => cases he
    | name name r =>
      have hx : embedAtom (.name name r) = Atom.name name (embedIx r) := by cases r <;> rfl
      rw [hx] at he
      have hn : name = l := (Atom.name.inj he).1
      subst name
      have hr := h.2.2 r ho
      subst r
      exact (Atom.name.inj he).2.symm

theorem LegacyTables.clauseSig {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    {eb o sg} (sig : Benitoite.Release.ClauseSig P0 B0 eb o sg) :
    ClauseSig (embedProgramWithKinds K P0) B (embedEff eb) o (embedOpSig sg) := by
  obtain ⟨S,ix,lookup⟩ := sig
  refine ⟨embedRange S,?_,tables.opSigAt lookup,?_⟩
  · rcases ix with rfl | ⟨b,s,l,ho,hb,he,hr⟩
    · exact Or.inl rfl
    · obtain ⟨s',hs',corr⟩ := tables.primitives b s hb
      exact Or.inr ⟨b,s',l,ho,hs',corr.opEff.trans he,legacy_clauseRange hr⟩
  · intro b s ho hs
    subst o
    cases hb : B0.sig b with
    | none => simp [Benitoite.Release.opSigAt,hb] at lookup
    | some s0 =>
      obtain ⟨s',hs',corr⟩ := tables.primitives b s0 hb
      cases Option.some.inj (hs.symm.trans hs')
      exact corr.sourceTelRows

theorem legacy_opSig_wf {sg : Benitoite.Release.OpSig}
    (h : (embedTy (.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff))).WF 0 sg.tparams.length 0) :
    (embedOpSig sg).WF := by
  have aux (ps : List Benitoite.Release.Ty)
      (hw : Ty.WFList 0 sg.tparams.length 0 (embedTys ps)) :
      ∀ n, BinderTypes.LocalWF sg.tparams.length n (embedTys ps) := by
    induction ps with
    | nil => intro n; trivial
    | cons a as ih =>
      intro n
      exact ⟨(embedTy_wf_values a 0 sg.tparams.length 0 n).mp hw.1,ih hw.2 (n+1)⟩
  have hp := aux sg.params h.2.1 0
  exact ⟨by simpa [embedOpSig,TypeCtx.values] using hp,
    by simpa only [embedOpSig,TypeCtx.values,List.length_map,embedTys_eq_map] using
      (embedTy_wf_values sg.ret 0 sg.tparams.length 0 (embedTys sg.params).length).mp h.2.2.1⟩

end
end Benitoite.Release.Refinement
