import Benitoite.Release.Refinement.LegacyCallInputs
import Benitoite.Release.Refinement.RangeFormation

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_atom_instR (a : Benitoite.Release.Atom) (rs : List Scope.Domain.Range) :
    embedAtom (a.instR rs) = (embedAtom a).instR (rs.map embedRange) := by
  cases a with
  | rho i => rfl
  | name l ix =>
    cases ix <;> simp only [Benitoite.Release.Atom.instR,embedAtom,Atom.instR]
    case fixed r => rfl
    case rvar i => cases h : rs[i]? <;> simp [Scope.Signature.Ix.inst,RangeIx.inst,List.getElem?_map,h,embedRange]

theorem legacy_instAtoms (a : Benitoite.Release.Atom → Bool) (rs : List Scope.Domain.Range) :
    embedAtoms (Benitoite.Release.Eff.instAtoms rs a) = instAtoms (rs.map embedRange) (embedAtoms a) := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [embedAtoms_true,instAtoms_spec]
  constructor
  · rintro ⟨b,hb,rfl⟩
    obtain ⟨c,hc,rfl⟩ := (Benitoite.Release.Eff.instAtoms_spec rs a b).mp hb
    exact ⟨embedAtom c,by rw [embedAtoms_embed]; exact hc,(legacy_atom_instR c rs).symm⟩
  · rintro ⟨b,hb,he⟩
    obtain ⟨c,hc,rfl⟩ := (embedAtoms_true a b).mp hb
    refine ⟨c.instR rs,(Benitoite.Release.Eff.instAtoms_spec rs a _).mpr ⟨c,hc,rfl⟩,?_⟩
    exact (legacy_atom_instR c rs).trans he

mutual
  theorem legacy_rawInstR (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
      embedTy (a.rawInstR rs) = (embedTy a).rawMapRanges (rangeAt 0 (rs.map embedRange)) := by
    cases a <;> simp only [Benitoite.Release.Ty.rawInstR,embedTy,Ty.rawMapRanges,
      legacy_rawInstR,legacy_rawInstRTys,legacy_rawInstREff]
    case «opaque» o ix =>
      cases ix with
      | fixed r => rfl
      | rvar i =>
        cases h : rs[i]? <;> simp [Scope.Signature.Ix.inst,List.getElem?_map,h,embedRange,embedIx,mapIx,rangeAt]
  theorem legacy_rawInstRTys (as : List Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
      embedTys (Benitoite.Release.Ty.rawInstRTys rs as) = mapRangesTys (rangeAt 0 (rs.map embedRange)) (embedTys as) := by
    cases as <;> simp only [Benitoite.Release.Ty.rawInstRTys,embedTys,mapRangesTys,
      legacy_rawInstR,legacy_rawInstRTys]
  theorem legacy_rawInstREff (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) :
      embedEff (Benitoite.Release.Eff.rawInstR rs e) = Eff.rawMapRanges (rangeAt 0 (rs.map embedRange)) (embedEff e) := by
    cases e with
    | mk a fs =>
      simp only [Benitoite.Release.Eff.rawInstR,embedEff,Eff.rawMapRanges,legacy_rawInstRTys]
      rw [legacy_instAtoms]
      congr 1
      funext x
      apply Bool.eq_iff_iff.mpr
      rw [instAtoms_spec,mapRangeAtoms_spec]
      have hi : ∀ y : Atom, y.instR (rs.map embedRange) = mapAtomRanges (rangeAt 0 (rs.map embedRange)) y := by
        intro y
        cases y with
        | rho i => rfl
        | name l ix => cases ix with
          | fixed r => rfl
          | rvar i =>
            simp only [Atom.instR,mapAtomRanges,mapIx,rangeAt,RangeIx.inst,Nat.not_lt_zero,ite_false,Nat.sub_zero]
            rfl
      simp only [←hi]
end

theorem legacy_instR (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
    embedTy (a.instR rs) = (embedTy a).instR (rs.map embedRange) := by
  simp only [Benitoite.Release.Ty.instR,Ty.instR,Ty.substRAt,Ty.mapRanges,embedTy_norm,legacy_rawInstR]

theorem legacy_instREff (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) :
    (embedEff (Benitoite.Release.Eff.instR rs e)).norm = Eff.instR (rs.map embedRange) (embedEff e) := by
  rw [←embedEff_norm,Benitoite.Release.Eff.norm_instR,embedEff_norm,legacy_rawInstREff]
  rfl

mutual
  theorem legacy_rangesTy (a : Benitoite.Release.Ty) (nr : Nat) :
      (embedTy a).RangesScoped nr ↔ a.RangesIn nr := by
    cases a <;> simp only [embedTy,Ty.RangesScoped,Benitoite.Release.Ty.RangesIn,
      legacy_rangesTy,legacy_rangesTys,legacy_rangesEff]
    case «opaque» o ix => cases ix <;> rfl
  theorem legacy_rangesTys (as : List Benitoite.Release.Ty) (nr : Nat) :
      rangesScopedTypes nr (embedTys as) ↔ Benitoite.Release.Ty.RangesInList nr as := by
    cases as <;> simp only [embedTys,rangesScopedTypes,Benitoite.Release.Ty.RangesInList,
      legacy_rangesTy,legacy_rangesTys]
  theorem legacy_rangesEff (e : Benitoite.Release.Eff) (nr : Nat) :
      Eff.RangesScoped nr (embedEff e) ↔ Benitoite.Release.Eff.RangesIn nr e := by
    cases e with
    | mk atoms fs =>
      simp only [embedEff,Eff.RangesScoped,Benitoite.Release.Eff.RangesIn,legacy_rangesTys]
      apply and_congr_left
      intro _
      constructor
      · intro h x hx
        cases x with
        | rho i => trivial
        | name l ix =>
          cases ix with
          | fixed r => trivial
          | rvar i => exact h l (.rvar i) hx
      · intro h l ix hx
        obtain ⟨x,hx,he⟩ := (embedAtoms_true atoms (.name l ix)).mp hx
        cases x with
        | rho i => cases he
        | name l' ix' =>
          cases ix' with
          | fixed r => cases he; trivial
          | rvar i => cases he; exact h _ hx
end

private theorem legacy_atom_instR_idem (a : Benitoite.Release.Atom) (rs : List Scope.Domain.Range) :
    (a.instR rs).instR rs = a.instR rs := by
  cases a with
  | rho i => rfl
  | name l ix =>
    cases ix with
    | fixed r => rfl
    | rvar i => cases h : rs[i]? <;> simp [Benitoite.Release.Atom.instR,Scope.Signature.Ix.inst,h]

private theorem legacy_instAtoms_idem (a : Benitoite.Release.Atom → Bool) (rs : List Scope.Domain.Range) :
    Benitoite.Release.Eff.instAtoms rs (Benitoite.Release.Eff.instAtoms rs a) =
      Benitoite.Release.Eff.instAtoms rs a := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [Benitoite.Release.Eff.instAtoms_spec,Benitoite.Release.Eff.instAtoms_spec]
  constructor
  · rintro ⟨y,hy,rfl⟩
    obtain ⟨z,hz,rfl⟩ := (Benitoite.Release.Eff.instAtoms_spec rs a y).mp hy
    exact ⟨z,hz,(legacy_atom_instR_idem z rs).symm⟩
  · rintro ⟨y,hy,rfl⟩
    exact ⟨y.instR rs,(Benitoite.Release.Eff.instAtoms_spec rs a _).mpr ⟨y,hy,rfl⟩,
      legacy_atom_instR_idem y rs⟩

mutual
  theorem legacy_old_rawInstR_idem (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
      (a.rawInstR rs).rawInstR rs = a.rawInstR rs := by
    cases a <;> simp only [Benitoite.Release.Ty.rawInstR,legacy_old_rawInstR_idem,
      legacy_old_rawInstRTys_idem,legacy_old_rawInstREff_idem]
    case «opaque» o ix =>
      cases ix with
      | fixed r => rfl
      | rvar i => cases h : rs[i]? <;> simp [Scope.Signature.Ix.inst,h]
  theorem legacy_old_rawInstRTys_idem (as : List Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
      Benitoite.Release.Ty.rawInstRTys rs (Benitoite.Release.Ty.rawInstRTys rs as) =
        Benitoite.Release.Ty.rawInstRTys rs as := by
    cases as <;> simp only [Benitoite.Release.Ty.rawInstRTys,legacy_old_rawInstR_idem,legacy_old_rawInstRTys_idem]
  theorem legacy_old_rawInstREff_idem (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) :
      Benitoite.Release.Eff.rawInstR rs (Benitoite.Release.Eff.rawInstR rs e) =
        Benitoite.Release.Eff.rawInstR rs e := by
    cases e
    simp only [Benitoite.Release.Eff.rawInstR,legacy_instAtoms_idem,legacy_old_rawInstRTys_idem]
end

theorem legacy_old_instR_idem (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
    (a.instR rs).instR rs = a.instR rs := by
  change ((a.rawInstR rs).norm).instR rs = a.instR rs
  rw [Benitoite.Release.Ty.instR_norm]
  change ((a.rawInstR rs).rawInstR rs).norm = (a.rawInstR rs).norm
  rw [legacy_old_rawInstR_idem]

theorem legacy_old_instR_instTarget (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) :
    (a.instTarget rs).instR rs = a.instR rs := by
  cases a <;> try rfl
  case «opaque» o ix =>
    cases ix with
    | fixed r => rfl
    | rvar i => cases h : rs[i]? <;> simp [Benitoite.Release.Ty.instTarget,
        Benitoite.Release.Ty.instR,Benitoite.Release.Ty.rawInstR,Benitoite.Release.Ty.norm,Scope.Signature.Ix.inst,h]

theorem legacy_old_eff_instR_idem (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) :
    (Benitoite.Release.Eff.instR rs (Benitoite.Release.Eff.instR rs e)).norm =
      (Benitoite.Release.Eff.instR rs e).norm := by
  rw [Benitoite.Release.Eff.norm_instR]
  rw [←Benitoite.Release.Eff.norm_rawInstR rs (Benitoite.Release.Eff.instR rs e)]
  rw [Benitoite.Release.Eff.norm_instR,Benitoite.Release.Eff.norm_rawInstR,legacy_old_rawInstREff_idem]

theorem legacy_old_instR_fn (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) :
    (Benitoite.Release.Ty.fn ns ps r e).instR rs =
      .fn ns (ps.map (Benitoite.Release.Ty.instR rs)) (r.instR rs) (Benitoite.Release.Eff.instR rs e).norm := by
  rw [Benitoite.Release.Eff.norm_instR]
  simp only [Benitoite.Release.Ty.instR,Benitoite.Release.Ty.rawInstR,Benitoite.Release.Ty.norm,
    Benitoite.Release.Ty.rawInstRTys_eq_map,Benitoite.Release.Ty.normTys_eq_map,List.map_map,Function.comp_def]
  rfl

theorem legacy_old_primitive_source (s : Benitoite.Release.PrimSig) (rs : List Scope.Domain.Range) :
    (Benitoite.Release.Ty.fn (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff).instR rs =
      (Benitoite.Release.Ty.fn s.names s.params s.ret s.eff).instR rs := by
  simp only [Benitoite.Release.PrimSig.inst,legacy_old_instR_fn,List.map_map,Function.comp_def,
    legacy_old_instR_instTarget,legacy_old_instR_idem,legacy_old_eff_instR_idem]

theorem legacy_primitive_type {K P0 Δ ts es rs ks} {s0 : Benitoite.Release.PrimSig}
    (result : LegacyTypeInput K P0 Δ
      (Benitoite.Release.fnTy (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff ts es) .value)
    (nr : Δ.nr = 0) (args : LegacyTypesInput K P0 Δ ts ks) (rows : LegacyRowsInput K P0 Δ es) :
    Benitoite.Release.fnTy (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff ts es =
      ((Benitoite.Release.Ty.fn s0.names s0.params s0.ret s0.eff).instR rs).subst ts es := by
  let a := Benitoite.Release.fnTy (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff ts es
  have wf : a.WF 0 Δ.kinds.length := legacy_wf (by simpa only [nr] using result.2.1)
  have range : a.RangesIn 0 := (legacy_rangesTy a 0).mp (by simpa only [nr] using result.2.2.2.2)
  have htypes : ∀ u ∈ ts, u.RangesIn 0 ∧ u.Canonical := by
    intro u hu
    obtain ⟨i,hi⟩ := List.mem_iff_getElem?.mp hu
    have ilt : i < ks.length := args.1 ▸ (List.getElem?_eq_some_iff.mp hi).1
    have hx := (args.2 i u ks[i] hi (List.getElem?_eq_getElem ilt)).1
    exact ⟨(legacy_rangesTy u 0).mp (by simpa only [nr] using hx.2.2.2.2),
      Benitoite.Release.Ty.WF.canonical u (legacy_wf (by simpa only [nr] using hx.2.1))⟩
  have hrows : ∀ e ∈ es, Benitoite.Release.Eff.RangesIn 0 e := by
    intro e he
    exact (legacy_rangesEff e 0).mp (by simpa only [nr] using (rows e he).2.2.2.2.2.2)
  have h1 := Benitoite.Release.Ty.instR_of_rangesIn range (Benitoite.Release.Ty.WF.canonical a wf) rs
  have h2 := Benitoite.Release.Ty.instR_substAt_of_rangeFree rs (c := 0) htypes hrows
    (.fn (s0.inst rs).names (s0.inst rs).params (s0.inst rs).ret (s0.inst rs).eff)
  rw [legacy_old_primitive_source] at h2
  exact h1.symm.trans h2

mutual
  theorem legacy_old_qRawInstR (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) (i : Nat) :
      Benitoite.Release.QTy (a.rawInstR rs) i ↔ Benitoite.Release.QTy a i := by
    cases a <;> simp only [Benitoite.Release.Ty.rawInstR,Benitoite.Release.QTy,
      legacy_old_qRawInstR,legacy_old_qRawInstRTys,legacy_old_qRawInstREff]
  theorem legacy_old_qRawInstRTys (as : List Benitoite.Release.Ty) (rs : List Scope.Domain.Range) (i : Nat) :
      Benitoite.Release.QTys (Benitoite.Release.Ty.rawInstRTys rs as) i ↔ Benitoite.Release.QTys as i := by
    cases as <;> simp only [Benitoite.Release.Ty.rawInstRTys,Benitoite.Release.QTys,
      legacy_old_qRawInstR,legacy_old_qRawInstRTys]
  theorem legacy_old_qRawInstREff (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) (i : Nat) :
      Benitoite.Release.QEff (Benitoite.Release.Eff.rawInstR rs e) i ↔ Benitoite.Release.QEff e i := by
    cases e with
    | mk atoms fs =>
      simp only [Benitoite.Release.Eff.rawInstR,Benitoite.Release.QEff,legacy_old_qRawInstRTys,
        Benitoite.Release.Eff.instAtoms_rho]
      cases fs <;> simp [Benitoite.Release.Ty.rawInstRTys]
end

theorem legacy_old_qInstR (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) (i : Nat) :
    Benitoite.Release.QTy (a.instR rs) i ↔ Benitoite.Release.QTy a i := by
  rw [Benitoite.Release.Ty.instR,Benitoite.Release.QTy.norm_iff,legacy_old_qRawInstR]

theorem legacy_old_qInstRTys (as : List Benitoite.Release.Ty) (rs : List Scope.Domain.Range) (i : Nat) :
    Benitoite.Release.QTys (as.map (Benitoite.Release.Ty.instR rs)) i ↔ Benitoite.Release.QTys as i := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [List.map_cons,Benitoite.Release.QTys,legacy_old_qInstR,ih]

theorem legacy_old_qInstREff (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) (i : Nat) :
    Benitoite.Release.QEff (Benitoite.Release.Eff.instR rs e) i ↔ Benitoite.Release.QEff e i := by
  cases e with
  | mk atoms fs =>
    simp only [Benitoite.Release.Eff.instR,Benitoite.Release.QEff,legacy_old_qInstRTys,
      Benitoite.Release.Eff.instAtoms_rho]
    cases fs <;> simp

theorem legacy_old_qInstTarget (a : Benitoite.Release.Ty) (rs : List Scope.Domain.Range) (i : Nat) :
    Benitoite.Release.QTy (a.instTarget rs) i ↔ Benitoite.Release.QTy a i := by
  cases a <;> rfl

theorem legacy_old_qInstTargetTys (as : List Benitoite.Release.Ty) (rs : List Scope.Domain.Range) (i : Nat) :
    Benitoite.Release.QTys (as.map (Benitoite.Release.Ty.instTarget rs)) i ↔ Benitoite.Release.QTys as i := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [List.map_cons,Benitoite.Release.QTys,legacy_old_qInstTarget,ih]

theorem legacy_old_Qsig_inst (s : Benitoite.Release.PrimSig) (rs : List Scope.Domain.Range) :
    Benitoite.Release.Qsig (s.inst rs).params (s.inst rs).ret (s.inst rs).eff =
      Benitoite.Release.Qsig s.params s.ret s.eff := by
  funext i
  apply propext
  simp only [Benitoite.Release.PrimSig.inst,Benitoite.Release.Qsig,
    legacy_old_qInstTargetTys,legacy_old_qInstR,legacy_old_qInstREff]

theorem signatureTel_effect_rows (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (pe : Nat → Prop) (h : (signatureTel ns ps r e).RowsIn pe) : e.RowsIn pe := by
  induction ns generalizing ps with
  | nil => exact h.2
  | cons n ns ih =>
    cases ps with
    | nil => exact h.2
    | cons a ps => exact ih ps h.2

theorem legacy_range_signatureTel (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (rs : List Scope.Domain.Range) :
    Tel.instR (rs.map embedRange) (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)) =
      signatureTel ns (embedTys (ps.map (Benitoite.Release.Ty.instR rs)))
        (embedTy (r.instR rs)) (embedEff (Benitoite.Release.Eff.instR rs e).norm) := by
  rw [legacy_signatureTel,Tel.instR_eq_bind,Tel.bind_toTel,legacy_signatureTel]
  congr 1
  · simp only [embedTys_eq_map,List.map_map,Function.comp_def,←Ty.instR_eq_bind,←legacy_instR]
  · exact (Ty.instR_eq_bind _ _).symm.trans (legacy_instR r rs).symm
  · rw [←Eff.instR_eq_bind,←legacy_instREff,←embedEff_norm]

theorem legacy_range_signatureTel_wf (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) {nr nt : Nat} (rs : List Scope.Domain.Range)
    (source : (embedTy (.fn ns ps r e)).WF nr nt 0) (count : rs.length = nr) :
    (Ty.dependentFn (Tel.instR (rs.map embedRange)
      (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)))).WF 0 nt 0 := by
  rw [legacy_signatureTel,Tel.instR_eq_bind]
  exact Tel.bind_wf _ (Tel.wf_toTel source.1 source.2.1 source.2.2.1 source.2.2.2.1 source.2.2.2.2)
    (SubstEnv.rangesOnly_wfImages (by simpa only [List.length_map] using count))

end
end Benitoite.Release.Refinement
