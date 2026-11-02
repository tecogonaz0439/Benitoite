# 群 P の完全署名

[signatures-p.lean](signatures-p.lean) の `#check @宣言名` の出力である。値19規則の各枝は親の入力と子の `Embedded` から同じ旧型の像の型付けを構成する。七判断の全合成は後続群の対象である。内部の署名の変更と再開1の具体例は [results.md](results.md) を参照する。

```lean
@Benitoite.Release.Refinement.LegacyValueCases.var_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {i : Nat}
  {a : Benitoite.Release.Ty},
  Eq.{1} (getElem?.{0, 0, 0} Γ i) (some.{0} (some.{0} a)) →
    (∀ (b t : Benitoite.Release.Ty) (e : Benitoite.Release.EffR), Ne.{1} a (b.cont t e)) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.var i) a)
@Benitoite.Release.Refinement.LegacyValueCases.const_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  (c : Benitoite.Release.Const),
  Benitoite.Release.Refinement.ConstOK B (Benitoite.Release.Refinement.embedConst c) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.const c) c.type)
@Benitoite.Release.Refinement.LegacyValueCases.bytes_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} (bs : List.{0} Nat),
  (∀ (b : Nat), Membership.mem.{0, 0} bs b → LE.le.{0} b 255) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.bytesV bs)
        Benitoite.Release.Ty.bytes)
Benitoite.Release.Refinement.legacy_qTy : ∀ (a : Benitoite.Release.Ty) (i : Nat),
  Benitoite.Release.Refinement.QTy (Benitoite.Release.Refinement.embedTy a) i ↔ Benitoite.Release.QTy a i
Benitoite.Release.Refinement.legacy_qTys : ∀ (as : List.{0} Benitoite.Release.Ty) (i : Nat),
  Benitoite.Release.Refinement.QTys (Benitoite.Release.Refinement.embedTys as) i ↔ Benitoite.Release.QTys as i
Benitoite.Release.Refinement.legacy_qEff : ∀ (e : Benitoite.Release.Eff) (i : Nat),
  Benitoite.Release.Refinement.QEff (Benitoite.Release.Refinement.embedEff e) i ↔ Benitoite.Release.QEff e i
Benitoite.Release.Refinement.legacy_Qsig : ∀ (ps : List.{0} Benitoite.Release.Ty) (r : Benitoite.Release.Ty)
  (e : Benitoite.Release.Eff),
  Eq.{1}
    (Benitoite.Release.Refinement.Qsig (Benitoite.Release.Refinement.embedTys ps)
      (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
    (Benitoite.Release.Qsig ps r e)
Benitoite.Release.Refinement.legacy_rowsTy : ∀ (a : Benitoite.Release.Ty) (pe : Nat → Prop),
  Benitoite.Release.Refinement.Ty.RowsIn pe (Benitoite.Release.Refinement.embedTy a) ↔ Benitoite.Release.Ty.RowsIn pe a
Benitoite.Release.Refinement.legacy_rowsTys : ∀ (as : List.{0} Benitoite.Release.Ty) (pe : Nat → Prop),
  Benitoite.Release.Refinement.Ty.RowsInList pe (Benitoite.Release.Refinement.embedTys as) ↔
    Benitoite.Release.Ty.RowsInList pe as
Benitoite.Release.Refinement.legacy_rowsEff : ∀ (e : Benitoite.Release.Eff) (pe : Nat → Prop),
  Benitoite.Release.Refinement.Eff.RowsIn pe (Benitoite.Release.Refinement.embedEff e) ↔
    Benitoite.Release.Eff.RowsIn pe e
@Benitoite.Release.Refinement.legacy_NoFail : ∀ {Q : Benitoite.Release.NoFailCtx} {e : Benitoite.Release.Eff},
  Benitoite.Release.NoFail Q e → Benitoite.Release.Refinement.NoFail Q (Benitoite.Release.Refinement.embedEff e)
Benitoite.Release.Refinement.legacy_row : ∀ (i : Nat),
  Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.row i)) (Benitoite.Release.Refinement.Eff.row i)
@Benitoite.Release.Refinement.legacy_RowTransport : ∀ {Qs Qt : Benitoite.Release.NoFailCtx}
  {es : List.{0} Benitoite.Release.Eff},
  Benitoite.Release.RowTransport Qs Qt es →
    Benitoite.Release.Refinement.RowTransport Qs Qt (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)
@Benitoite.Release.Refinement.legacy_SatAll : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {C : List.{0} Benitoite.Release.TParam}
  {ts : List.{0} Benitoite.Release.Ty} {tps : List.{0} Benitoite.Release.TParam},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Eq.{1} (List.length.{0} κ) (List.length.{0} C) →
      Benitoite.Release.SatAll B0 C ts tps →
        Benitoite.Release.Refinement.SatAll B (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (Benitoite.Release.Refinement.embedTys ts) tps
@Benitoite.Release.Refinement.legacy_Admissible : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : List.{0} Benitoite.Release.Refinement.TyKind} {C : List.{0} Benitoite.Release.TParam} {nv : Nat}
  {tps : List.{0} Benitoite.Release.TParam} {ne : Nat} {Qs Qt : Benitoite.Release.NoFailCtx}
  {ts : List.{0} Benitoite.Release.Ty} {es : List.{0} Benitoite.Release.Eff} {e : Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Eq.{1} (List.length.{0} κ) (List.length.{0} C) →
      Benitoite.Release.Admissible B0 C tps ne Qs Qt ts es e →
        Benitoite.Release.Refinement.LegacyRowsInput K P0 { kinds := κ, constraints := C, nr := 0, nv := nv } es →
          Benitoite.Release.Refinement.Admissible B (Benitoite.Release.Refinement.legacyTypeCtx C κ) nv tps ne Qs Qt
            (Benitoite.Release.Refinement.embedTys ts) (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)
            (Benitoite.Release.Refinement.embedEff e)
@Benitoite.Release.Refinement.LegacyTypesInput.annotations : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx}
  {ts : List.{0} Benitoite.Release.Ty} {ks : List.{0} Benitoite.Release.Refinement.TyKind},
  Benitoite.Release.Refinement.LegacyTypesInput K P0 Δ ts ks →
    Eq.{1} Δ.nr 0 →
      Eq.{1} (List.length.{0} Δ.kinds) (List.length.{0} Δ.constraints) →
        ∀ (Γ : Benitoite.Release.Refinement.Ctx),
          Benitoite.Release.Refinement.TypeAnnotations (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
            (Benitoite.Release.Refinement.legacyTypeCtx Δ.constraints Δ.kinds) Γ
            (Benitoite.Release.Refinement.embedTys ts)
@Benitoite.Release.Refinement.LegacyRowsInput.annotations : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx}
  {es : List.{0} Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyRowsInput K P0 Δ es →
    Eq.{1} Δ.nr 0 →
      Eq.{1} (List.length.{0} Δ.kinds) (List.length.{0} Δ.constraints) →
        ∀ (Γ : Benitoite.Release.Refinement.Ctx),
          Benitoite.Release.Refinement.RowAnnotations (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
            (Benitoite.Release.Refinement.legacyTypeCtx Δ.constraints Δ.kinds) Γ
            (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)
@Benitoite.Release.Refinement.legacy_value_annotation : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {v : Benitoite.Release.Val}
  {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
    Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
      (Benitoite.Release.Refinement.legacyTypeCtx C κ)
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedTy) Γ)
      (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.LegacyValueCases.fun_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {f : Benitoite.Release.FunName} {d : Benitoite.Release.Def} {ts : List.{0} Benitoite.Release.Ty}
  {es : List.{0} Benitoite.Release.Eff},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.fnRef f ts es)
            (Benitoite.Release.fnTy d.names d.params d.ret d.eff ts es)) →
        Eq.{1} (P0.defs f) (some.{0} d) →
          Benitoite.Release.NamesWF d.names d.params →
            Benitoite.Release.Admissible B0 C d.tparams d.neffs (Benitoite.Release.Qsig d.params d.ret d.eff) Q ts es
                d.eff →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.fnRef f ts es)
                  (Benitoite.Release.fnTy d.names d.params d.ret d.eff ts es))
Benitoite.Release.Refinement.legacy_atom_instR : ∀ (a : Benitoite.Release.Atom)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedAtom (Benitoite.Release.Atom.instR rs a))
    (Benitoite.Release.Refinement.Atom.instR (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.embedAtom a))
Benitoite.Release.Refinement.legacy_instAtoms : ∀ (a : Benitoite.Release.Atom → Bool)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedAtoms (Benitoite.Release.Eff.instAtoms rs a))
    (Benitoite.Release.Refinement.instAtoms (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.embedAtoms a))
Benitoite.Release.Refinement.legacy_rawInstR : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.rawInstR rs a))
    (Benitoite.Release.Refinement.Ty.rawMapRanges
      (Benitoite.Release.Refinement.rangeAt 0 (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs))
      (Benitoite.Release.Refinement.embedTy a))
Benitoite.Release.Refinement.legacy_rawInstRTys : ∀ (as : List.{0} Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedTys (Benitoite.Release.Ty.rawInstRTys rs as))
    (Benitoite.Release.Refinement.mapRangesTys
      (Benitoite.Release.Refinement.rangeAt 0 (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs))
      (Benitoite.Release.Refinement.embedTys as))
Benitoite.Release.Refinement.legacy_rawInstREff : ∀ (e : Benitoite.Release.Eff)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.rawInstR rs e))
    (Benitoite.Release.Refinement.Eff.rawMapRanges
      (Benitoite.Release.Refinement.rangeAt 0 (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs))
      (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.legacy_instR : ∀ (a : Benitoite.Release.Ty) (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.instR rs a))
    (Benitoite.Release.Refinement.Ty.instR (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.embedTy a))
Benitoite.Release.Refinement.legacy_instREff : ∀ (e : Benitoite.Release.Eff)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.instR rs e)).norm
    (Benitoite.Release.Refinement.Eff.instR (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.legacy_rangesTy : ∀ (a : Benitoite.Release.Ty) (nr : Nat),
  Benitoite.Release.Refinement.Ty.RangesScoped nr (Benitoite.Release.Refinement.embedTy a) ↔
    Benitoite.Release.Ty.RangesIn nr a
Benitoite.Release.Refinement.legacy_rangesTys : ∀ (as : List.{0} Benitoite.Release.Ty) (nr : Nat),
  Benitoite.Release.Refinement.rangesScopedTypes nr (Benitoite.Release.Refinement.embedTys as) ↔
    Benitoite.Release.Ty.RangesInList nr as
Benitoite.Release.Refinement.legacy_rangesEff : ∀ (e : Benitoite.Release.Eff) (nr : Nat),
  Benitoite.Release.Refinement.Eff.RangesScoped nr (Benitoite.Release.Refinement.embedEff e) ↔
    Benitoite.Release.Eff.RangesIn nr e
Benitoite.Release.Refinement.legacy_old_rawInstR_idem : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Ty.rawInstR rs (Benitoite.Release.Ty.rawInstR rs a)) (Benitoite.Release.Ty.rawInstR rs a)
Benitoite.Release.Refinement.legacy_old_rawInstRTys_idem : ∀ (as : List.{0} Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Ty.rawInstRTys rs (Benitoite.Release.Ty.rawInstRTys rs as))
    (Benitoite.Release.Ty.rawInstRTys rs as)
Benitoite.Release.Refinement.legacy_old_rawInstREff_idem : ∀ (e : Benitoite.Release.Eff)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Eff.rawInstR rs (Benitoite.Release.Eff.rawInstR rs e)) (Benitoite.Release.Eff.rawInstR rs e)
Benitoite.Release.Refinement.legacy_old_instR_idem : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Ty.instR rs (Benitoite.Release.Ty.instR rs a)) (Benitoite.Release.Ty.instR rs a)
Benitoite.Release.Refinement.legacy_old_instR_instTarget : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Ty.instR rs (Benitoite.Release.Ty.instTarget rs a)) (Benitoite.Release.Ty.instR rs a)
Benitoite.Release.Refinement.legacy_old_eff_instR_idem : ∀ (e : Benitoite.Release.Eff)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Eff.instR rs (Benitoite.Release.Eff.instR rs e)).norm
    (Benitoite.Release.Eff.instR rs e).norm
Benitoite.Release.Refinement.legacy_old_instR_fn : ∀ (ns : List.{0} String) (ps : List.{0} Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1} (Benitoite.Release.Ty.instR rs (Benitoite.Release.Ty.fn ns ps r e))
    (Benitoite.Release.Ty.fn ns (List.map.{0, 0} (Benitoite.Release.Ty.instR rs) ps) (Benitoite.Release.Ty.instR rs r)
      (Benitoite.Release.Eff.instR rs e).norm)
Benitoite.Release.Refinement.legacy_old_primitive_source : ∀ (s : Benitoite.Release.PrimSig)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1}
    (Benitoite.Release.Ty.instR rs
      (Benitoite.Release.Ty.fn (Benitoite.Release.PrimSig.inst rs s).names (Benitoite.Release.PrimSig.inst rs s).params
        (Benitoite.Release.PrimSig.inst rs s).ret (Benitoite.Release.PrimSig.inst rs s).eff))
    (Benitoite.Release.Ty.instR rs (Benitoite.Release.Ty.fn s.names s.params s.ret s.eff))
@Benitoite.Release.Refinement.legacy_primitive_type : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx}
  {ts : List.{0} Benitoite.Release.Ty} {es : List.{0} Benitoite.Release.Eff}
  {rs : List.{0} Benitoite.Scope.Domain.Range} {ks : List.{0} Benitoite.Release.Refinement.TyKind}
  {s0 : Benitoite.Release.PrimSig},
  Benitoite.Release.Refinement.LegacyTypeInput K P0 Δ
      (Benitoite.Release.fnTy (Benitoite.Release.PrimSig.inst rs s0).names (Benitoite.Release.PrimSig.inst rs s0).params
        (Benitoite.Release.PrimSig.inst rs s0).ret (Benitoite.Release.PrimSig.inst rs s0).eff ts es)
      Benitoite.Release.Refinement.TyKind.value →
    Eq.{1} Δ.nr 0 →
      Benitoite.Release.Refinement.LegacyTypesInput K P0 Δ ts ks →
        Benitoite.Release.Refinement.LegacyRowsInput K P0 Δ es →
          Eq.{1}
            (Benitoite.Release.fnTy (Benitoite.Release.PrimSig.inst rs s0).names
              (Benitoite.Release.PrimSig.inst rs s0).params (Benitoite.Release.PrimSig.inst rs s0).ret
              (Benitoite.Release.PrimSig.inst rs s0).eff ts es)
            (Benitoite.Release.Ty.subst ts es
              (Benitoite.Release.Ty.instR rs (Benitoite.Release.Ty.fn s0.names s0.params s0.ret s0.eff)))
Benitoite.Release.Refinement.legacy_old_qRawInstR : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QTy (Benitoite.Release.Ty.rawInstR rs a) i ↔ Benitoite.Release.QTy a i
Benitoite.Release.Refinement.legacy_old_qRawInstRTys : ∀ (as : List.{0} Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QTys (Benitoite.Release.Ty.rawInstRTys rs as) i ↔ Benitoite.Release.QTys as i
Benitoite.Release.Refinement.legacy_old_qRawInstREff : ∀ (e : Benitoite.Release.Eff)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QEff (Benitoite.Release.Eff.rawInstR rs e) i ↔ Benitoite.Release.QEff e i
Benitoite.Release.Refinement.legacy_old_qInstR : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QTy (Benitoite.Release.Ty.instR rs a) i ↔ Benitoite.Release.QTy a i
Benitoite.Release.Refinement.legacy_old_qInstRTys : ∀ (as : List.{0} Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QTys (List.map.{0, 0} (Benitoite.Release.Ty.instR rs) as) i ↔ Benitoite.Release.QTys as i
Benitoite.Release.Refinement.legacy_old_qInstREff : ∀ (e : Benitoite.Release.Eff)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QEff (Benitoite.Release.Eff.instR rs e) i ↔ Benitoite.Release.QEff e i
Benitoite.Release.Refinement.legacy_old_qInstTarget : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QTy (Benitoite.Release.Ty.instTarget rs a) i ↔ Benitoite.Release.QTy a i
Benitoite.Release.Refinement.legacy_old_qInstTargetTys : ∀ (as : List.{0} Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range) (i : Nat),
  Benitoite.Release.QTys (List.map.{0, 0} (Benitoite.Release.Ty.instTarget rs) as) i ↔ Benitoite.Release.QTys as i
Benitoite.Release.Refinement.legacy_old_Qsig_inst : ∀ (s : Benitoite.Release.PrimSig)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1}
    (Benitoite.Release.Qsig (Benitoite.Release.PrimSig.inst rs s).params (Benitoite.Release.PrimSig.inst rs s).ret
      (Benitoite.Release.PrimSig.inst rs s).eff)
    (Benitoite.Release.Qsig s.params s.ret s.eff)
Benitoite.Release.Refinement.signatureTel_effect_rows : ∀ (ns : List.{0} String)
  (ps : List.{0} Benitoite.Release.Refinement.Ty) (r : Benitoite.Release.Refinement.Ty)
  (e : Benitoite.Release.Refinement.Eff) (pe : Nat → Prop),
  Benitoite.Release.Refinement.Tel.RowsIn pe (Benitoite.Release.Refinement.signatureTel ns ps r e) →
    Benitoite.Release.Refinement.Eff.RowsIn pe e
Benitoite.Release.Refinement.legacy_range_signatureTel : ∀ (ns : List.{0} String) (ps : List.{0} Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (rs : List.{0} Benitoite.Scope.Domain.Range),
  Eq.{1}
    (Benitoite.Release.Refinement.Tel.instR (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
        (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e)))
    (Benitoite.Release.Refinement.signatureTel ns
      (Benitoite.Release.Refinement.embedTys (List.map.{0, 0} (Benitoite.Release.Ty.instR rs) ps))
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.instR rs r))
      (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.instR rs e).norm))
Benitoite.Release.Refinement.legacy_range_signatureTel_wf : ∀ (ns : List.{0} String)
  (ps : List.{0} Benitoite.Release.Ty) (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) {nr nt : Nat}
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  Benitoite.Release.Refinement.Ty.WF nr nt 0
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e)) →
    Eq.{1} (List.length.{0} rs) nr →
      Benitoite.Release.Refinement.Ty.WF 0 nt 0
        (Benitoite.Release.Refinement.Ty.dependentFn
          (Benitoite.Release.Refinement.Tel.instR (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
            (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
              (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))))
@Benitoite.Release.Refinement.LegacyPrimSignature.qsig : ∀ {s0 : Benitoite.Release.PrimSig}
  {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.LegacyPrimSignature s0 s →
    Eq.{1} (Benitoite.Release.Refinement.Qsig s.params s.ret s.eff) (Benitoite.Release.Qsig s0.params s0.ret s0.eff)
@Benitoite.Release.Refinement.legacy_RangeAdmissible : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {b : Benitoite.Release.PrimName} {s0 : Benitoite.Release.PrimSig} {s : Benitoite.Release.Refinement.PrimSig}
  {rs : List.{0} Benitoite.Scope.Domain.Range},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyPrimSignature s0 s →
      B0.RangeAdmissible b s0 rs → B.RangeAdmissible b s (List.map.{0, 0} Benitoite.Release.Refinement.embedRange rs)
@Benitoite.Release.Refinement.legacy_PrimitiveAdmissible : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : List.{0} Benitoite.Release.Refinement.TyKind}
  {C : List.{0} Benitoite.Release.TParam} {nv : Nat} {s0 : Benitoite.Release.PrimSig}
  {s : Benitoite.Release.Refinement.PrimSig} {Q : Benitoite.Release.NoFailCtx} {ts : List.{0} Benitoite.Release.Ty}
  {es : List.{0} Benitoite.Release.Eff} {rs : List.{0} Benitoite.Scope.Domain.Range},
  Benitoite.Release.Refinement.LegacyPrimSignature s0 s →
    Eq.{1} (List.length.{0} κ) (List.length.{0} C) →
      Benitoite.Release.PrimitiveAdmissible C (Benitoite.Release.PrimSig.inst rs s0) Q ts es →
        Benitoite.Release.Refinement.LegacyRowsInput K P0 { kinds := κ, constraints := C, nr := 0, nv := nv } es →
          Benitoite.Release.Refinement.PrimitiveAdmissible (Benitoite.Release.Refinement.legacyTypeCtx C κ) nv s Q
            (Benitoite.Release.Refinement.embedTys ts) (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)
@Benitoite.Release.Refinement.LegacyValueCases.prim_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {b : Benitoite.Release.PrimName} {s0 : Benitoite.Release.PrimSig} {rs : List.{0} Benitoite.Scope.Domain.Range}
  {ts : List.{0} Benitoite.Release.Ty} {es : List.{0} Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.prim b ts es rs)
          (Benitoite.Release.fnTy (Benitoite.Release.PrimSig.inst rs s0).names
            (Benitoite.Release.PrimSig.inst rs s0).params (Benitoite.Release.PrimSig.inst rs s0).ret
            (Benitoite.Release.PrimSig.inst rs s0).eff ts es)) →
      Eq.{1} (B0.sig b) (some.{0} s0) →
        B0.RangeAdmissible b s0 rs →
          Benitoite.Release.NamesWF (Benitoite.Release.PrimSig.inst rs s0).names
              (Benitoite.Release.PrimSig.inst rs s0).params →
            Benitoite.Release.PrimitiveAdmissible C (Benitoite.Release.PrimSig.inst rs s0) Q ts es →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.prim b ts es rs)
                  (Benitoite.Release.fnTy (Benitoite.Release.PrimSig.inst rs s0).names
                    (Benitoite.Release.PrimSig.inst rs s0).params (Benitoite.Release.PrimSig.inst rs s0).ret
                    (Benitoite.Release.PrimSig.inst rs s0).eff ts es))
Benitoite.Release.Refinement.legacy_single : ∀ (name : Benitoite.Release.EffName),
  Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.single name))
    (Benitoite.Release.Refinement.Eff.single name)
Benitoite.Release.Refinement.legacy_opEffect : ∀ (name : Benitoite.Release.EffName),
  Eq.{1}
    (Benitoite.Release.Refinement.EffR.mk
      (fun a =>
        match a with
        |
        Benitoite.Release.Refinement.Atom.name n
            (Benitoite.Release.Refinement.RangeIx.fixed
              (Benitoite.Release.Refinement.RangeExpr.absolute Benitoite.Scope.Domain.Range.top)) =>
          decide (Eq.{1} n name)
        | x => false)
      List.nil.{0})
    (Benitoite.Release.Refinement.Eff.single name)
Benitoite.Release.Refinement.legacy_opTel : ∀ (od : Benitoite.Release.OpDecl),
  Eq.{1} (Benitoite.Release.Refinement.embedOpDecl od).tel
    (Benitoite.Release.Refinement.signatureTel od.names (Benitoite.Release.Refinement.embedTys od.params)
      (Benitoite.Release.Refinement.embedTy od.ret)
      (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.single od.eff)))
@Benitoite.Release.Refinement.LegacyValueCases.op_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {o : Benitoite.Release.OpName} {od : Benitoite.Release.OpDecl} {ts : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.op o ts)
          (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts List.nil.{0})) →
      Eq.{1} (P0.ops o) (some.{0} od) →
        Benitoite.Release.NamesWF od.names od.params →
          Benitoite.Release.SatAll B0 C ts od.tparams →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.op o ts)
                (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts
                  List.nil.{0}))
Benitoite.Release.Refinement.legacy_hideConts : ∀ (Γ : List.{0} (Option.{0} Benitoite.Release.Ty)),
  Eq.{1}
    (Benitoite.Release.Refinement.hideConts
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedTy) Γ))
    (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedTy) (Benitoite.Release.hideConts Γ))
Benitoite.Release.Refinement.legacy_bindParams : ∀ (Γ : List.{0} (Option.{0} Benitoite.Release.Ty))
  (ps : List.{0} Benitoite.Release.Ty),
  Eq.{1}
    (Benitoite.Release.Refinement.bindParams
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedTy) Γ)
      (Benitoite.Release.Refinement.embedTys ps))
    (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedTy)
      (HAppend.hAppend.{0, 0, 0} (Benitoite.Release.binds ps) Γ))
Benitoite.Release.Refinement.legacy_hideBuilders : ∀ (Ψ : Benitoite.Release.StoreTy),
  Eq.{1} (Benitoite.Release.Refinement.hideBuilders (Benitoite.Release.Refinement.embedStoreTy Ψ))
    (Benitoite.Release.Refinement.embedStoreTy Ψ.hideBuilders)
@Benitoite.Release.Refinement.LegacyValueCases.lam_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {ns : List.{0} String}
  {ps : List.{0} Benitoite.Release.Ty} {body : Benitoite.Release.Comp} {r : Benitoite.Release.Ty}
  {e : Benitoite.Release.EffR},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.lam ns ps body)
        (Benitoite.Release.Ty.fn ns ps r e)) →
    Benitoite.Release.NamesWF ns ps →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ.hideBuilders Q C
            (HAppend.hAppend.{0, 0, 0} (Benitoite.Release.binds ps) (Benitoite.Release.hideConts Γ)) (some.{0} r) body r
            e List.nil.{0}) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.lam ns ps body)
            (Benitoite.Release.Ty.fn ns ps r e))
@Benitoite.Release.Refinement.LegacyValueCases.con_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {c : Benitoite.Release.ConName} {ts : List.{0} Benitoite.Release.Ty} {vs : List.{0} Benitoite.Release.Val}
  {cd : Benitoite.Release.ConDecl},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.con c ts vs)
          (Benitoite.Release.Ty.data cd.data ts)) →
      Eq.{1} (P0.cons c) (some.{0} cd) →
        Eq.{1} (List.length.{0} ts) cd.ntys →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs
                (List.map.{0, 0} (Benitoite.Release.Ty.subst ts List.nil.{0}) cd.args)) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.con c ts vs)
                (Benitoite.Release.Ty.data cd.data ts))
@Benitoite.Release.Refinement.LegacyValueCases.list_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {vs : List.{0} Benitoite.Release.Val} {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.list vs) a.list) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs a) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.list vs) a.list)
@Benitoite.Release.Refinement.LegacyValueCases.map_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {keys vs : List.{0} Benitoite.Release.Val} {a b : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.mapV keys vs) (a.map b)) →
      Eq.{1} (List.length.{0} keys) (List.length.{0} vs) →
        B0.sat C a Benitoite.Release.TParam.keyC →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ keys a) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs b) →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.mapV keys vs)
                  (a.map b))
@Benitoite.Release.Refinement.LegacyValueCases.set_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {vs : List.{0} Benitoite.Release.Val} {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.setV vs) a.set) →
      B0.sat C a Benitoite.Release.TParam.keyC →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs a) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.setV vs) a.set)
@Benitoite.Release.Refinement.LegacyValueCases.dict_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {i : Benitoite.Release.ImplName} {ts : List.{0} Benitoite.Release.Ty} {vs : List.{0} Benitoite.Release.Val}
  {id : Benitoite.Release.ImplDecl},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.dict i ts vs)
          (Benitoite.Release.Ty.dict id.cls (Benitoite.Release.Ty.subst ts List.nil.{0} id.target))) →
      Eq.{1} (P0.impls i) (some.{0} id) →
        Benitoite.Release.SatAll B0 C ts id.tparams →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs
                (List.map.{0, 0} (Benitoite.Release.Ty.subst ts List.nil.{0}) id.dictTys)) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.dict i ts vs)
                (Benitoite.Release.Ty.dict id.cls (Benitoite.Release.Ty.subst ts List.nil.{0} id.target)))
Benitoite.Release.Refinement.legacy_singleFail : ∀ (a : Benitoite.Release.Ty),
  Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.singleFail a))
    (Benitoite.Release.Refinement.Eff.singleFail (Benitoite.Release.Refinement.embedTy a))
@Benitoite.Release.Refinement.LegacyValueCases.locRef_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {l : Nat}
  {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.loc l) a.reference) →
    Eq.{1} (Ψ l) (some.{0} (Benitoite.Release.LocTy.ref a)) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.loc l) a.reference)
@Benitoite.Release.Refinement.LegacyValueCases.locLazy_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {l : Nat}
  {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.loc l) a.lazy) →
    Eq.{1} (Ψ l) (some.{0} (Benitoite.Release.LocTy.lazy a)) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.loc l) a.lazy)
@Benitoite.Release.Refinement.LegacyValueCases.checked_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {target : Benitoite.Scope.Domain.Target} {o : Benitoite.Release.OpaqueName} {range : Benitoite.Scope.Domain.Range},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.checked target)
        (Benitoite.Release.Ty.opaque o (Benitoite.Scope.Signature.Ix.fixed range))) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.checked target)
        (Benitoite.Release.Ty.opaque o (Benitoite.Scope.Signature.Ix.fixed range)))
@Benitoite.Release.Refinement.LegacyValueCases.checkedRequest_case : ∀
  {K : Benitoite.Release.Refinement.DeclarationKinds} {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {target : Benitoite.Scope.Domain.Target}
  {req : Benitoite.Release.Val} {o : Benitoite.Release.OpaqueName} {range : Benitoite.Scope.Domain.Range}
  {T : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.checkedRequest target req)
        (Benitoite.Release.Ty.opaque o (Benitoite.Scope.Signature.Ix.fixed range))) →
    Eq.{1} (B0.valContent o) (some.{0} T) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value List.nil.{0} Ψ Benitoite.Release.Qempty List.nil.{0}
            List.nil.{0} req T) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.checkedRequest target req)
            (Benitoite.Release.Ty.opaque o (Benitoite.Scope.Signature.Ix.fixed range)))
@Benitoite.Release.Refinement.LegacyValueCases.raise_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {T E : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.raise T E)
        (Benitoite.Release.Ty.fn (List.cons.{0} "error" List.nil.{0}) (List.cons.{0} E List.nil.{0}) T
          (Benitoite.Release.Eff.singleFail E))) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (Benitoite.Release.Val.raise T E)
        (Benitoite.Release.Ty.fn (List.cons.{0} "error" List.nil.{0}) (List.cons.{0} E List.nil.{0}) T
          (Benitoite.Release.Eff.singleFail E)))
@Benitoite.Release.Refinement.LegacyValueCases.super_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {v : Benitoite.Release.Val}
  {cl : Benitoite.Release.ClassName} {a : Benitoite.Release.Ty} {cd : Benitoite.Release.ClassDecl}
  {s : Benitoite.Release.ClassName},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (v.super s) (Benitoite.Release.Ty.dict s a)) →
    Eq.{1} (P0.classes cl) (some.{0} cd) →
      Membership.mem.{0, 0} cd.supers s →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v (Benitoite.Release.Ty.dict cl a)) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ (v.super s) (Benitoite.Release.Ty.dict s a))
@Benitoite.Release.Refinement.LegacyValueCases.sub_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {v : Benitoite.Release.Val}
  {a b : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v b) →
    a.Le b →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v b)
@Benitoite.Release.Refinement.LegacyRule.embed_value : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {v : Benitoite.Release.Val}
  {a : Benitoite.Release.Ty} {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0 (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a)
      children →
    K.WF P0 →
      Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
        Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
          (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
              Membership.mem.{0, 0} children child →
                Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a)
Benitoite.Release.Refinement.LegacyJudgment.ConstantEmbedded : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program → Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.LegacyJudgment → Prop
@Benitoite.Release.Refinement.LegacyOutputInput.embed_constants : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {j : Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B j →
    Benitoite.Release.Refinement.LegacyJudgment.ConstantEmbedded K P0 B j
Benitoite.Release.Refinement.LegacyEmbeddingExamples.unit_input : Benitoite.Release.Refinement.LegacyOutputInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  (Benitoite.Release.Refinement.LegacyJudgment.value List.nil.{0} Benitoite.Release.StoreTy.empty
    Benitoite.Release.Qempty List.nil.{0} List.nil.{0} (Benitoite.Release.Val.const Benitoite.Release.Const.unit)
    (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.unit))
Benitoite.Release.Refinement.LegacyEmbeddingExamples.unit_from_induction : ∀
  (Φ : List.{0} Benitoite.Release.Refinement.Pred),
  Benitoite.Release.Refinement.HasTypeVQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty List.nil.{0}
    List.nil.{0} Φ (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
Benitoite.Release.Refinement.LegacyEmbeddingExamples.unit_from_value_rule : ∀
  (Φ : List.{0} Benitoite.Release.Refinement.Pred),
  Benitoite.Release.Refinement.HasTypeVQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty List.nil.{0}
    List.nil.{0} Φ (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
Benitoite.Release.Refinement.LegacyEmbeddingExamples.list_from_value_rule : ∀
  (Φ : List.{0} Benitoite.Release.Refinement.Pred),
  Benitoite.Release.Refinement.HasTypeVQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty List.nil.{0}
    List.nil.{0} Φ
    (Benitoite.Release.Refinement.Val.list
      (List.cons.{0} (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit) List.nil.{0}))
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit).list
Benitoite.Release.Refinement.LegacyEmbeddingExamples.operation_from_value_rule : ∀
  (Φ : List.{0} Benitoite.Release.Refinement.Pred),
  Benitoite.Release.Refinement.HasTypeVQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty List.nil.{0}
    List.nil.{0} Φ (Benitoite.Release.Refinement.Val.op "unitOp" List.nil.{0})
    (Benitoite.Release.Refinement.embedTy
      (Benitoite.Release.fnTy List.nil.{0} List.nil.{0} (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.unit)
        (Benitoite.Release.Eff.single "UnitEffect") List.nil.{0} List.nil.{0}))
Benitoite.Release.Refinement.LegacyEmbeddingExamples.local_let : Benitoite.Release.Refinement.HasTypeCQ
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins Benitoite.Release.Refinement.StoreTy.empty
  Benitoite.Release.Qempty List.nil.{0} List.nil.{0} List.nil.{0} none.{0}
  ((Benitoite.Release.Refinement.Comp.ret
        (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)).letIn
    (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.var 0)))
  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit) Benitoite.Release.Refinement.Eff.empty
Benitoite.Release.Refinement.LegacyEmbeddingExamples.local_arm : Benitoite.Release.Refinement.HasTypeArmsQ
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins Benitoite.Release.Refinement.StoreTy.empty
  Benitoite.Release.Qempty List.nil.{0} List.nil.{0} List.nil.{0} none.{0} none.{0}
  (List.cons.{0}
    (Benitoite.Release.Refinement.Arm.mk
      (List.cons.{0} { pat := Benitoite.Release.Pat.var, slots := List.cons.{0} 0 List.nil.{0} } List.nil.{0}) none.{0}
      (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.var 0)))
    List.nil.{0})
  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit) Benitoite.Release.Refinement.Eff.empty
Benitoite.Release.Refinement.LegacyEmbeddingExamples.nonempty_local_bound : Benitoite.Release.Refinement.LocalRef.HasKind
  Benitoite.Release.Refinement.StoreTy.empty
  (Benitoite.Release.Refinement.localExtend 2
    (List.cons.{0} (some.{0} Benitoite.Release.Refinement.BuilderKind.string) List.nil.{0}))
  (Benitoite.Release.LocalRef.bound 2) Benitoite.Release.Refinement.BuilderKind.string
Benitoite.Release.Refinement.LegacyEmbeddingExamples.bindings_from_child : Benitoite.Release.Refinement.LegacyNodeTypes
    Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram List.nil.{0} List.nil.{0} 0
    (List.cons.{0} (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.integer) List.nil.{0}) ∧
  Benitoite.Release.Refinement.PatTy
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Pat.var (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
    (List.cons.{0} (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer) List.nil.{0})
Benitoite.Release.Refinement.LegacyEmbeddingExamples.at_shape : Benitoite.Release.Refinement.ResultShape.StandardError
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  { owner := "Result", ok := "Ok", error := "Error", errorType := Benitoite.Release.Refinement.atErrorType }
Benitoite.Release.Refinement.LegacyEmbeddingExamples.at_legacy_inhabits : ∀
  (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Inhabits Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
    (Benitoite.Release.Ty.data "Scope.ScopeError" List.nil.{0})
    (Benitoite.Release.Refinement.legacyPatternVal (Benitoite.Release.Refinement.Val.atError detail))
Benitoite.Release.Refinement.LegacyEmbeddingExamples.at_pattern_typed : Benitoite.Release.Refinement.PatTy
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  Benitoite.Release.Refinement.LegacyPatternExamples.atPattern Benitoite.Release.Refinement.atErrorType
  (Benitoite.Release.Refinement.embedTys
    (List.replicate.{0} 7 (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.string)))
Benitoite.Release.Refinement.LegacyEmbeddingExamples.at_type_argument_rejected : ¬Benitoite.Release.Refinement.LegacyNodeTypes
    Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram List.nil.{0} List.nil.{0} 0
    (List.cons.{0}
      (Benitoite.Release.Ty.data "Scope.ScopeError"
        (List.cons.{0} (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.unit) List.nil.{0}))
      List.nil.{0})
Benitoite.Release.Refinement.LegacyEmbeddingExamples.nested_at_correspondence : ∀
  (detail : Benitoite.Release.Refinement.AtError),
  Eq.{1}
    ((Benitoite.Release.Pat.list
          (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.atPattern List.nil.{0}) none.{0}
          List.nil.{0}).matchVal
      (Benitoite.Release.Refinement.legacyPatternVal
        (Benitoite.Release.Refinement.Val.list
          (List.cons.{0} (Benitoite.Release.Refinement.Val.atError detail) List.nil.{0}))))
    (Option.map.{0, 0} Benitoite.Release.Refinement.legacyPatternVals
      (Benitoite.Release.Refinement.matchVal
        (Benitoite.Release.Pat.list
          (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.atPattern List.nil.{0}) none.{0}
          List.nil.{0})
        (Benitoite.Release.Refinement.Val.list
          (List.cons.{0} (Benitoite.Release.Refinement.Val.atError detail) List.nil.{0}))))
Benitoite.Release.Refinement.LegacyEmbeddingExamples.match_node_coverage : Benitoite.Release.Refinement.LegacyOutputInput
    Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
    Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.LegacyJudgment.comp List.nil.{0} Benitoite.Release.StoreTy.empty
      Benitoite.Release.Qempty List.nil.{0} List.nil.{0} none.{0}
      (Benitoite.Release.Comp.match (Benitoite.Release.Val.const Benitoite.Release.Const.unit)
        (List.cons.{0}
          (Benitoite.Release.Arm.mk
            (List.cons.{0} { pat := Benitoite.Release.Pat.wild, slots := List.nil.{0} } List.nil.{0}) none.{0}
            (Benitoite.Release.Comp.ret (Benitoite.Release.Val.const Benitoite.Release.Const.unit)))
          List.nil.{0}))
      (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.unit) Benitoite.Release.Eff.empty List.nil.{0}) ∧
  Benitoite.Release.Refinement.Exhaustive
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
    (List.cons.{0} Benitoite.Release.Pat.wild List.nil.{0})
```
