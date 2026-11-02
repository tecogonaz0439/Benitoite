# 群 Q・R の完全署名（補助）

再開1の既定 import から `#check @宣言名` で全引数・証拠の添字を印字した。型検査の入力は [signatures-aux.lean](signatures-aux.lean)。主入口の前提は `DeclarationKinds.WF`・`LegacyTables`・`LegacyOutputInput` である。表現可能性・対象保持は node の入力、宣言の kind と表の対応は先の二前提で検査する。旧状態の入力には新しい型付け・遷移の結論を置かない。

```lean
@Benitoite.Release.Refinement.LegacyRule.embed_values : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {vs : List.{0} Benitoite.Release.Val} {ts : List.{0} Benitoite.Release.Ty}
  {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0 (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs ts)
      children →
    (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
        @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
            (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
            (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs ts)
@Benitoite.Release.Refinement.LegacyRule.embed_each : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {vs : List.{0} Benitoite.Release.Val} {a : Benitoite.Release.Ty}
  {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0 (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs a)
      children →
    (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
        @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
            (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
            (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs a)
@Benitoite.Release.Refinement.legacy_comp_annotation : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
    Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
      (Benitoite.Release.Refinement.legacyTypeCtx C κ)
      (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
        (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
        Γ)
      (Benitoite.Release.Refinement.embedTy a)
Benitoite.Release.Refinement.legacy_shiftVCtx : ∀ (Γ : List.{0} (Option.{0} Benitoite.Release.Ty)) (n c : Nat),
  @Eq.{1} (List.{0} (Option.{0} Benitoite.Release.Refinement.Ty))
    (@List.map.{0, 0} (Option.{0} Benitoite.Release.Refinement.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
      (@Option.map.{0, 0} Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.Ty
        (Benitoite.Release.Refinement.Ty.shiftV n c))
      (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
        (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
        Γ))
    (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
      (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy) Γ)
Benitoite.Release.Refinement.legacy_shiftVR : ∀ (R : Option.{0} Benitoite.Release.Ty) (n c : Nat),
  @Eq.{1} (Option.{0} Benitoite.Release.Refinement.Ty)
    (@Option.map.{0, 0} Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.Ty
      (Benitoite.Release.Refinement.Ty.shiftV n c)
      (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy R))
    (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy R)
Benitoite.Release.Refinement.legacy_empty : @Eq.{1} Benitoite.Release.Refinement.Eff
  (Benitoite.Release.Refinement.embedEff Benitoite.Release.Eff.empty) Benitoite.Release.Refinement.Eff.empty
@Benitoite.Release.Refinement.LegacyCompCases.return_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty}
  {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.ret v) a
        Benitoite.Release.Eff.empty L)
@Benitoite.Release.Refinement.LegacyCompCases.let_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m n : Benitoite.Release.Comp} {a b : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (m.letIn n) b e L) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C
            (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.some.{0} Benitoite.Release.Ty a) Γ) R n b e
            (Benitoite.Release.LocalCtx.extend (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1))) L)) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (m.letIn n) b e L)
@Benitoite.Release.Refinement.LegacyCompCases.app_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {f : Benitoite.Release.Val} {args : List.{0} Benitoite.Release.Val}
  {ns : List.{0} String} {as : List.{0} Benitoite.Release.Ty} {b : Benitoite.Release.Ty} {e : Benitoite.Release.EffR}
  {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ f (Benitoite.Release.Ty.fn ns as b e)) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ args as) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.app f args) b e L)
@Benitoite.Release.Refinement.legacy_types_annotations : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {C : List.{0} Benitoite.Release.TParam}
  {nv : Nat} {as : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeTypes K P0 κ C nv as →
    @Eq.{1} Nat (@List.length.{0} Benitoite.Release.Refinement.TyKind κ) (@List.length.{0} Benitoite.Release.TParam C) →
      ∀ (Γ : Benitoite.Release.Refinement.Ctx),
        Benitoite.Release.Refinement.TypeAnnotations (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
          (Benitoite.Release.Refinement.legacyTypeCtx C κ) Γ (Benitoite.Release.Refinement.embedTys as)
@Benitoite.Release.Refinement.legacy_fn_annotation : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : Benitoite.Release.Refinement.Ctx} {ns : List.{0} String} {ps : List.{0} Benitoite.Release.Ty}
  {r : Benitoite.Release.Ty} {e : Benitoite.Release.EffR},
  Benitoite.Release.NamesWF ns ps →
    Benitoite.Release.Refinement.TypeAnnotations (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
        (Benitoite.Release.Refinement.legacyTypeCtx C κ) Γ (Benitoite.Release.Refinement.embedTys ps) →
      Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
          (Benitoite.Release.Refinement.legacyTypeCtx C κ) Γ (Benitoite.Release.Refinement.embedTy r) →
        Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
            (Benitoite.Release.Refinement.legacyTypeCtx C κ) Γ
            (Benitoite.Release.Refinement.embedTy
              (Benitoite.Release.Ty.fn (@List.nil.{0} String) (@List.nil.{0} Benitoite.Release.Ty)
                (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.unit) e)) →
          Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
            (Benitoite.Release.Refinement.legacyTypeCtx C κ) Γ
            (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e))
Benitoite.Release.Refinement.legacy_signature_arguments : ∀ (ns : List.{0} String) (ps : List.{0} Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (vs : List.{0} Benitoite.Release.Refinement.Val),
  Benitoite.Release.NamesWF ns ps →
    @Eq.{1} Nat (@List.length.{0} Benitoite.Release.Refinement.Val vs) (@List.length.{0} Benitoite.Release.Ty ps) →
      @Eq.{1}
        (Option.{0}
          (Prod.{0, 0} (List.{0} Benitoite.Release.Refinement.Ty)
            (Prod.{0, 0} Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.Eff)))
        ((Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
              (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e)).arguments
          vs)
        (@Option.some.{0}
          (Prod.{0, 0} (List.{0} Benitoite.Release.Refinement.Ty)
            (Prod.{0, 0} Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.Eff))
          (@Prod.mk.{0, 0} (List.{0} Benitoite.Release.Refinement.Ty)
            (Prod.{0, 0} Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.Eff)
            (Benitoite.Release.Refinement.Ty.normTys (Benitoite.Release.Refinement.embedTys ps))
            (@Prod.mk.{0, 0} Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.Eff
              (Benitoite.Release.Refinement.embedTy r).norm (Benitoite.Release.Refinement.embedEff e).norm)))
@Benitoite.Release.Refinement.HasTypeVsQ.normal_types : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List.{0} Benitoite.Release.Refinement.Pred} {vs : List.{0} Benitoite.Release.Refinement.Val}
  {as : List.{0} Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as →
    Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs (Benitoite.Release.Refinement.Ty.normTys as)
@Benitoite.Release.Refinement.LegacyCompCases.meth_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {v : Benitoite.Release.Val} {cl : Benitoite.Release.ClassName}
  {τ : Benitoite.Release.Ty} {cd : Benitoite.Release.ClassDecl} {m : Benitoite.Release.MethName}
  {ms : Benitoite.Release.MethSig} {ss : List.{0} Benitoite.Release.Ty} {es : List.{0} Benitoite.Release.Eff}
  {ws : List.{0} Benitoite.Release.Val} {L : Benitoite.Release.LocalCtx},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.meth v m ss es ws)
            (Benitoite.Release.Ty.subst
              (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                (List.{0} Benitoite.Release.Ty)
                (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty) (@List.instAppend.{0} Benitoite.Release.Ty))
                ss (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
              es ms.ret)
            (Benitoite.Release.Eff.substAt (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
              (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                (List.{0} Benitoite.Release.Ty)
                (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty) (@List.instAppend.{0} Benitoite.Release.Ty))
                ss (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
              es ms.eff)
            L) →
        @Eq.{1} (Option.{0} Benitoite.Release.ClassDecl) (P0.classes cl)
            (@Option.some.{0} Benitoite.Release.ClassDecl cd) →
          @Eq.{1} (Option.{0} Benitoite.Release.MethSig) (cd.methods m)
              (@Option.some.{0} Benitoite.Release.MethSig ms) →
            Benitoite.Release.NamesWF ms.names ms.params →
              Benitoite.Release.SatAll B0 C ss ms.tparams →
                (∀ (t : Benitoite.Release.Ty),
                    @Membership.mem.{0, 0} Benitoite.Release.Ty (List.{0} Benitoite.Release.Ty)
                        (@List.instMembership.{0} Benitoite.Release.Ty)
                        (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                          (List.{0} Benitoite.Release.Ty)
                          (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty)
                            (@List.instAppend.{0} Benitoite.Release.Ty))
                          ss (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
                        t →
                      And
                        (Benitoite.Release.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
                          (@List.length.{0} Benitoite.Release.TParam C) t)
                        (∀ (b r : Benitoite.Release.Ty) (e : Benitoite.Release.EffR),
                          @Ne.{1} Benitoite.Release.Ty t (b.cont r e))) →
                  Benitoite.Release.MethodRowsAdmissible C Q ms es →
                    Benitoite.Release.Refinement.LegacyTypeInput K P0
                        {
                          kinds :=
                            @HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Refinement.TyKind)
                              (List.{0} Benitoite.Release.Refinement.TyKind)
                              (List.{0} Benitoite.Release.Refinement.TyKind)
                              (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Refinement.TyKind)
                                (@List.instAppend.{0} Benitoite.Release.Refinement.TyKind))
                              (K.methodParams cl m)
                              (@List.cons.{0} Benitoite.Release.Refinement.TyKind (K.classArgument cl)
                                (@List.nil.{0} Benitoite.Release.Refinement.TyKind)),
                          constraints :=
                            @HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.TParam)
                              (List.{0} Benitoite.Release.TParam) (List.{0} Benitoite.Release.TParam)
                              (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.TParam)
                                (@List.instAppend.{0} Benitoite.Release.TParam))
                              ms.tparams
                              (@List.cons.{0} Benitoite.Release.TParam { } (@List.nil.{0} Benitoite.Release.TParam)),
                          nr := @OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)),
                          nv := @OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)) }
                        (Benitoite.Release.Ty.fn ms.names ms.params ms.ret ms.eff)
                        Benitoite.Release.Refinement.TyKind.value →
                      Benitoite.Release.Refinement.LegacyTypesInput K P0
                          { kinds := κ, constraints := C,
                            nr := @OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)),
                            nv := @List.length.{0} (Option.{0} Benitoite.Release.Ty) Γ }
                          ss (K.methodParams cl m) →
                        Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
                            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v
                              (Benitoite.Release.Ty.dict cl τ)) →
                          Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
                              (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ ws
                                (@List.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Ty
                                  (Benitoite.Release.Ty.subst
                                    (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty)
                                      (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                                      (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty)
                                        (@List.instAppend.{0} Benitoite.Release.Ty))
                                      ss (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
                                    es)
                                  ms.params)) →
                            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                                (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v
                                  (Benitoite.Release.Ty.dict cl τ)) →
                              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                                  (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ ws
                                    (@List.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Ty
                                      (Benitoite.Release.Ty.subst
                                        (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty)
                                          (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                                          (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty)
                                            (@List.instAppend.{0} Benitoite.Release.Ty))
                                          ss
                                          (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
                                        es)
                                      ms.params)) →
                                Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                                  (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R
                                    (Benitoite.Release.Comp.meth v m ss es ws)
                                    (Benitoite.Release.Ty.subst
                                      (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty)
                                        (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                                        (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty)
                                          (@List.instAppend.{0} Benitoite.Release.Ty))
                                        ss (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
                                      es ms.ret)
                                    (Benitoite.Release.Eff.substAt
                                      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
                                      (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Ty)
                                        (List.{0} Benitoite.Release.Ty) (List.{0} Benitoite.Release.Ty)
                                        (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Ty)
                                          (@List.instAppend.{0} Benitoite.Release.Ty))
                                        ss (@List.cons.{0} Benitoite.Release.Ty τ (@List.nil.{0} Benitoite.Release.Ty)))
                                      es ms.eff)
                                    L)
Benitoite.Release.Refinement.legacy_unguarded : ∀ (xs : List.{0} Benitoite.Release.Arm),
  @Eq.{1} (List.{0} Benitoite.Release.Pat)
    (Benitoite.Release.Refinement.unguardedPats (Benitoite.Release.Refinement.embedArms xs))
    (Benitoite.Release.unguardedPats xs)
@Benitoite.Release.Refinement.LegacyCompCases.if_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {v : Benitoite.Release.Val} {m n : Benitoite.Release.Comp}
  {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v
        (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean)) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R n a e L) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.ite v m n) a e L)
@Benitoite.Release.Refinement.LegacyCompCases.match_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {v : Benitoite.Release.Val} {arms : List.{0} Benitoite.Release.Arm}
  {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
      Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R arms a b e L) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.match v arms) b e L)
@Benitoite.Release.Refinement.LegacyCompCases.lazy_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty}
  {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m.lazyC a.lazy Benitoite.Release.Eff.empty L) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ.hideBuilders Q C (Benitoite.Release.hideConts Γ)
          (@Option.none.{0} Benitoite.Release.Ty) m a Benitoite.Release.Eff.empty
          (@List.nil.{0} (Option.{0} Benitoite.Release.BuilderKind))) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m.lazyC a.lazy Benitoite.Release.Eff.empty L)
@Benitoite.Release.Refinement.LegacyCompCases.escape_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {r : Benitoite.Release.Ty}
  {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ (@Option.some.{0} Benitoite.Release.Ty r)
        (Benitoite.Release.Comp.escape v) a e L) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v r) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ (@Option.some.{0} Benitoite.Release.Ty r)
          (Benitoite.Release.Comp.escape v) a e L)
@Benitoite.Release.Refinement.LegacyCompCases.use_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {v : Benitoite.Release.Val} {o : Benitoite.Release.OpaqueName}
  {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    @Eq.{1} Bool (B0.isResource o) Bool.true →
      e.mem (Benitoite.Release.Atom.nameTop Benitoite.Release.stateEff) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v (Benitoite.Release.Ty.opaqueTop o)) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.use v m) a e L)
@Benitoite.Release.Refinement.LegacyCompCases.resume_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {i : Nat} {v : Benitoite.Release.Val} {b t : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R
        (Benitoite.Release.Comp.resume (Benitoite.Release.Val.var i) v) t e L) →
    @Eq.{1} (Option.{0} (Option.{0} Benitoite.Release.Ty))
        (@GetElem?.getElem?.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty)) Nat (Option.{0} Benitoite.Release.Ty)
          (fun as i => @LT.lt.{0} Nat instLTNat i (@List.length.{0} (Option.{0} Benitoite.Release.Ty) as))
          (@List.instGetElem?NatLtLength.{0} (Option.{0} Benitoite.Release.Ty)) Γ i)
        (@Option.some.{0} (Option.{0} Benitoite.Release.Ty) (@Option.some.{0} Benitoite.Release.Ty (b.cont t e))) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v b) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R
            (Benitoite.Release.Comp.resume (Benitoite.Release.Val.var i) v) t e L)
@Benitoite.Release.Refinement.LegacyCompCases.resumeL_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {l : Nat} {v : Benitoite.Release.Val} {b t : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R
        (Benitoite.Release.Comp.resume (Benitoite.Release.Val.loc l) v) t e L) →
    @Eq.{1} (Option.{0} Benitoite.Release.LocTy) (Ψ l)
        (@Option.some.{0} Benitoite.Release.LocTy (Benitoite.Release.LocTy.cont b t e R)) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v b) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R
            (Benitoite.Release.Comp.resume (Benitoite.Release.Val.loc l) v) t e L)
@Benitoite.Release.Refinement.LegacyCompCases.sub_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {a b : Benitoite.Release.Ty}
  {e f : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m b f L) →
    a.Le b →
      f.Covers e →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m b f L)
@Benitoite.Release.Refinement.LegacyCompCases.eff_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty}
  {e f : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  f.Covers e →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a f L)
Benitoite.Release.Refinement.legacy_builder_contents : ∀ (kind : Benitoite.Release.BuilderKind),
  @Eq.{1} Benitoite.Release.Refinement.Ty (Benitoite.Release.Refinement.embedBuilderKind kind).contents
    (Benitoite.Release.Refinement.embedTy kind.contents)
Benitoite.Release.Refinement.legacy_builder_parameters : ∀ (op : Benitoite.Release.Refinement.BuilderOp)
  (kind : Benitoite.Release.BuilderKind),
  @Eq.{1} (List.{0} Benitoite.Release.Refinement.Ty)
    (op.parameters (Benitoite.Release.Refinement.embedBuilderKind kind))
    (Benitoite.Release.Refinement.embedTys (Benitoite.Release.BuilderOp.params op kind))
Benitoite.Release.Refinement.legacy_builder_result : ∀ (op : Benitoite.Release.Refinement.BuilderOp)
  (kind : Benitoite.Release.BuilderKind),
  @Eq.{1} Benitoite.Release.Refinement.Ty (op.resultType (Benitoite.Release.Refinement.embedBuilderKind kind))
    (Benitoite.Release.Refinement.embedTy (Benitoite.Release.BuilderOp.result op kind))
@Benitoite.Release.Refinement.LegacyBuilderInput.kinded : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : List.{0} Benitoite.Release.Refinement.TyKind}
  {C : List.{0} Benitoite.Release.TParam} {nv : Nat} {kind : Benitoite.Release.BuilderKind},
  Benitoite.Release.Refinement.LegacyBuilderInput K P0
      { kinds := κ, constraints := C, nr := @OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)), nv := nv }
      kind →
    @Eq.{1} Nat (@List.length.{0} Benitoite.Release.Refinement.TyKind κ) (@List.length.{0} Benitoite.Release.TParam C) →
      Benitoite.Release.Refinement.TypeArgsKinded (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
        (Benitoite.Release.Refinement.legacyTypeCtx C κ)
        (@List.cons.{0} Benitoite.Release.Refinement.Ty (Benitoite.Release.Refinement.embedBuilderKind kind).contents
          (@List.nil.{0} Benitoite.Release.Refinement.Ty))
        (@List.cons.{0} Benitoite.Release.Refinement.TyKind Benitoite.Release.Refinement.TyKind.value
          (@List.nil.{0} Benitoite.Release.Refinement.TyKind))
@Benitoite.Release.Refinement.legacy_localRef : ∀ {Ψ : Benitoite.Release.StoreTy} {L : Benitoite.Release.LocalCtx}
  {ref : Benitoite.Release.LocalRef} {kind : Benitoite.Release.BuilderKind},
  Benitoite.Release.LocalRef.HasKind Ψ L ref kind →
    Benitoite.Release.Refinement.LocalRef.HasKind (Benitoite.Release.Refinement.embedStoreTy Ψ)
      (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind) (Option.{0} Benitoite.Release.Refinement.BuilderKind)
        (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
          Benitoite.Release.Refinement.embedBuilderKind)
        L)
      ref (Benitoite.Release.Refinement.embedBuilderKind kind)
@Benitoite.Release.Refinement.LegacyCompCases.builderLet_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {kind : Benitoite.Release.BuilderKind} {m : Benitoite.Release.Comp}
  {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.builderLet kind m) a e L) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C
          (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.none.{0} Benitoite.Release.Ty) Γ) R m a e
          (@List.cons.{0} (Option.{0} Benitoite.Release.BuilderKind)
            (@Option.some.{0} Benitoite.Release.BuilderKind kind) L)) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.builderLet kind m) a e L)
@Benitoite.Release.Refinement.LegacyCompCases.builderOp_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {kind : Benitoite.Release.BuilderKind} {op : Benitoite.Release.BuilderOp}
  {ref : Benitoite.Release.LocalRef} {vs : List.{0} Benitoite.Release.Val} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (Benitoite.Release.Comp.builderOp kind op ref vs)
        (op.result kind) Benitoite.Release.Eff.empty L) →
    Benitoite.Release.LocalRef.HasKind Ψ L ref kind →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs (op.params kind)) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R
            (Benitoite.Release.Comp.builderOp kind op ref vs) (op.result kind) Benitoite.Release.Eff.empty L)
@Benitoite.Release.Refinement.legacy_eff_sub : ∀ {e f : Benitoite.Release.Eff},
  e.Sub f → (Benitoite.Release.Refinement.embedEff e).Sub (Benitoite.Release.Refinement.embedEff f)
Benitoite.Release.Refinement.legacy_union : ∀ (e f : Benitoite.Release.Eff),
  @Eq.{1} Benitoite.Release.Refinement.Eff (Benitoite.Release.Refinement.embedEff (e.union f))
    ((Benitoite.Release.Refinement.embedEff e).union (Benitoite.Release.Refinement.embedEff f))
Benitoite.Release.Refinement.legacy_handles : ∀ (cs : List.{0} Benitoite.Release.Clause) (o : Benitoite.Release.OpRef),
  @Eq.{1} Bool (Benitoite.Release.Refinement.handles (Benitoite.Release.Refinement.embedClauses cs) o)
    (Benitoite.Release.handles cs o)
@Benitoite.Release.Refinement.legacy_handled_sub : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    ∀ (cs : List.{0} Benitoite.Release.Clause),
      (Benitoite.Release.Refinement.embedEff (Benitoite.Release.handled P0 B0 cs)).Sub
        (Benitoite.Release.Refinement.handled (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedClauses cs))
@Benitoite.Release.Refinement.LegacyCompCases.handle_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {cs : List.{0} Benitoite.Release.Clause}
  {t : Benitoite.Release.Ty} {em e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    em.Sub (e.union (Benitoite.Release.handled P0 B0 cs)) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m t em L) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R em cs t e L) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (m.handle cs) t e L)
@Benitoite.Release.Refinement.LegacyCompCases.handleFail_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {cs : List.{0} Benitoite.Release.Clause}
  {t E : Benitoite.Release.Ty} {eb rest ec : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  eb.Sub ((Benitoite.Release.Eff.singleFail E).union rest) →
    Benitoite.Release.NoFail Q rest →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m t eb L) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R cs t ec L) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R (m.handle cs) t (rest.union ec) L)
@Benitoite.Release.Refinement.LegacyArmCases.nil_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R (@List.nil.{0} Benitoite.Release.Arm) a b e L) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
      (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R (@List.nil.{0} Benitoite.Release.Arm) a b e L)
@Benitoite.Release.Refinement.LegacyArmCases.plain_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {alts : List.{0} Benitoite.Release.Alt} {m : Benitoite.Release.Comp}
  {arms : List.{0} Benitoite.Release.Arm} {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {δ : List.{0} Benitoite.Release.Ty} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.AltsTy P0 alts a δ →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C
            (@HAppend.hAppend.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty))
              (List.{0} (Option.{0} Benitoite.Release.Ty)) (List.{0} (Option.{0} Benitoite.Release.Ty))
              (@instHAppendOfAppend.{0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                (@List.instAppend.{0} (Option.{0} Benitoite.Release.Ty)))
              (Benitoite.Release.binds δ) Γ)
            R m b e (Benitoite.Release.LocalCtx.extend (@List.length.{0} Benitoite.Release.Ty δ) L)) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R arms a b e L) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R
              (@List.cons.{0} Benitoite.Release.Arm
                (Benitoite.Release.Arm.mk alts (@Option.none.{0} Benitoite.Release.Comp) m) arms)
              a b e L)
@Benitoite.Release.Refinement.LegacyArmCases.guarded_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {alts : List.{0} Benitoite.Release.Alt} {g m : Benitoite.Release.Comp}
  {arms : List.{0} Benitoite.Release.Arm} {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {δ : List.{0} Benitoite.Release.Ty} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.AltsTy P0 alts a δ →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C
            (Benitoite.Release.hideConts
              (@HAppend.hAppend.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                (List.{0} (Option.{0} Benitoite.Release.Ty)) (List.{0} (Option.{0} Benitoite.Release.Ty))
                (@instHAppendOfAppend.{0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                  (@List.instAppend.{0} (Option.{0} Benitoite.Release.Ty)))
                (Benitoite.Release.binds δ) Γ))
            (@Option.none.{0} Benitoite.Release.Ty) g (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean)
            Benitoite.Release.Eff.empty
            (Benitoite.Release.LocalCtx.extend (@List.length.{0} Benitoite.Release.Ty δ) L)) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C
              (@HAppend.hAppend.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                (List.{0} (Option.{0} Benitoite.Release.Ty)) (List.{0} (Option.{0} Benitoite.Release.Ty))
                (@instHAppendOfAppend.{0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                  (@List.instAppend.{0} (Option.{0} Benitoite.Release.Ty)))
                (Benitoite.Release.binds δ) Γ)
              R m b e (Benitoite.Release.LocalCtx.extend (@List.length.{0} Benitoite.Release.Ty δ) L)) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R arms a b e L) →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
              (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R
                (@List.cons.{0} Benitoite.Release.Arm
                  (Benitoite.Release.Arm.mk alts (@Option.some.{0} Benitoite.Release.Comp g) m) arms)
                a b e L)
@Benitoite.Release.Refinement.legacy_normal : ∀ {a : Benitoite.Release.Ty} {nr nt nv : Nat},
  Benitoite.Release.Refinement.Ty.WF nr nt nv (Benitoite.Release.Refinement.embedTy a) →
    @Eq.{1} Benitoite.Release.Refinement.Ty (Benitoite.Release.Refinement.embedTy a).norm
      (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.legacy_shift_types : ∀ {a : Benitoite.Release.Ty} {nr nt nv : Nat},
  Benitoite.Release.Refinement.Ty.WF nr nt nv (Benitoite.Release.Refinement.embedTy a) →
    ∀ (k c : Nat),
      @Eq.{1} Benitoite.Release.Refinement.Ty (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.shift k c a))
        (Benitoite.Release.Refinement.shiftTypes k c (Benitoite.Release.Refinement.embedTy a))
@Benitoite.Release.Refinement.legacy_shift_eff : ∀ {e : Benitoite.Release.Eff},
  (Benitoite.Release.Refinement.embedEff e).Canonical →
    ∀ (k c : Nat),
      @Eq.{1} Benitoite.Release.Refinement.Eff
        (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.shift k c e))
        (Benitoite.Release.Refinement.shiftRowsTypes k c (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.legacy_typeCtx_append : ∀ (C D : List.{0} Benitoite.Release.TParam)
  (κ ks : Benitoite.Release.Refinement.KindCtx),
  @Eq.{1} Nat (@List.length.{0} Benitoite.Release.Refinement.TyKind ks) (@List.length.{0} Benitoite.Release.TParam D) →
    @Eq.{1} Benitoite.Release.Refinement.TypeCtx
      (Benitoite.Release.Refinement.legacyTypeCtx
        (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.TParam) (List.{0} Benitoite.Release.TParam)
          (List.{0} Benitoite.Release.TParam)
          (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.TParam) (@List.instAppend.{0} Benitoite.Release.TParam))
          D C)
        (@HAppend.hAppend.{0, 0, 0} Benitoite.Release.Refinement.KindCtx Benitoite.Release.Refinement.KindCtx
          Benitoite.Release.Refinement.KindCtx
          (@instHAppendOfAppend.{0} Benitoite.Release.Refinement.KindCtx
            (@List.instAppend.{0} Benitoite.Release.Refinement.TyKind))
          ks κ))
      (@HAppend.hAppend.{0, 0, 0} Benitoite.Release.Refinement.TypeCtx Benitoite.Release.Refinement.TypeCtx
        Benitoite.Release.Refinement.TypeCtx
        (@instHAppendOfAppend.{0} Benitoite.Release.Refinement.TypeCtx
          (@List.instAppend.{0} Benitoite.Release.Refinement.TParamDecl))
        (Benitoite.Release.Refinement.legacyTypeCtx D ks) (Benitoite.Release.Refinement.legacyTypeCtx C κ))
Benitoite.Release.Refinement.legacy_typeCtx_values : ∀ (C : List.{0} Benitoite.Release.TParam),
  @Eq.{1} Benitoite.Release.Refinement.TypeCtx
    (Benitoite.Release.Refinement.legacyTypeCtx C
      (@List.replicate.{0} Benitoite.Release.Refinement.TyKind (@List.length.{0} Benitoite.Release.TParam C)
        Benitoite.Release.Refinement.TyKind.value))
    (Benitoite.Release.Refinement.TypeCtx.values C)
Benitoite.Release.Refinement.embedOpSig : Benitoite.Release.OpSig → Benitoite.Release.Refinement.OpSig
Benitoite.Release.Refinement.legacy_instTarget : ∀ (a : Benitoite.Release.Ty)
  (rs : List.{0} Benitoite.Scope.Domain.Range),
  @Eq.{1} Benitoite.Release.Refinement.Ty (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.instTarget rs a))
    (Benitoite.Release.Refinement.Ty.instTarget
      (@List.map.{0, 0} Benitoite.Scope.Domain.Range Benitoite.Release.Refinement.RangeExpr
        Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.embedTy a))
@Benitoite.Release.Refinement.LegacyTables.opSigAt : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    ∀ {o : Benitoite.Release.OpRef} {S : Benitoite.Scope.Domain.Range} {sg : Benitoite.Release.OpSig},
      @Eq.{1} (Option.{0} Benitoite.Release.OpSig) (Benitoite.Release.opSigAt P0 B0 S o)
          (@Option.some.{0} Benitoite.Release.OpSig sg) →
        @Eq.{1} (Option.{0} Benitoite.Release.Refinement.OpSig)
          (Benitoite.Release.Refinement.opSigAt (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedRange S) o)
          (@Option.some.{0} Benitoite.Release.Refinement.OpSig (Benitoite.Release.Refinement.embedOpSig sg))
@Benitoite.Release.Refinement.legacy_clauseRange : ∀ {e : Benitoite.Release.Eff} {l : Benitoite.Release.EffName}
  {S : Benitoite.Scope.Domain.Range},
  e.ClauseRangeIs l S →
    (Benitoite.Release.Refinement.embedEff e).ClauseRangeIs l (Benitoite.Release.Refinement.embedRange S)
@Benitoite.Release.Refinement.LegacyTables.clauseSig : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    ∀ {eb : Benitoite.Release.Eff} {o : Benitoite.Release.OpRef} {sg : Benitoite.Release.OpSig},
      Benitoite.Release.ClauseSig P0 B0 eb o sg →
        Benitoite.Release.Refinement.ClauseSig (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedEff eb) o (Benitoite.Release.Refinement.embedOpSig sg)
@Benitoite.Release.Refinement.legacy_opSig_wf : ∀ {sg : Benitoite.Release.OpSig},
  Benitoite.Release.Refinement.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (@List.length.{0} Benitoite.Release.TParam sg.tparams)
      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (Benitoite.Release.Refinement.embedTy
        (Benitoite.Release.Ty.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff))) →
    (Benitoite.Release.Refinement.embedOpSig sg).WF
Benitoite.Release.Refinement.legacy_extend : ∀ (Γ : List.{0} (Option.{0} Benitoite.Release.Ty))
  (a : Benitoite.Release.Ty),
  @Eq.{1} Benitoite.Release.Refinement.Ctx
    (Benitoite.Release.Refinement.Ctx.extend
      (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
        (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
        Γ)
      (Benitoite.Release.Refinement.embedTy a))
    (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
      (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
      (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.some.{0} Benitoite.Release.Ty a) Γ))
Benitoite.Release.Refinement.legacy_extendMany : ∀ (Γ : List.{0} (Option.{0} Benitoite.Release.Ty))
  (ps : List.{0} Benitoite.Release.Ty),
  @Eq.{1} Benitoite.Release.Refinement.Ctx
    (Benitoite.Release.Refinement.Ctx.extendMany
      (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
        (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
        Γ)
      (Benitoite.Release.Refinement.embedTys ps))
    (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
      (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
      (@HAppend.hAppend.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty))
        (List.{0} (Option.{0} Benitoite.Release.Ty)) (List.{0} (Option.{0} Benitoite.Release.Ty))
        (@instHAppendOfAppend.{0} (List.{0} (Option.{0} Benitoite.Release.Ty))
          (@List.instAppend.{0} (Option.{0} Benitoite.Release.Ty)))
        (Benitoite.Release.binds ps) Γ))
@Benitoite.Release.Refinement.LegacyNodeContext.shiftEnv : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)},
  Benitoite.Release.Refinement.LegacyNodeContext K P0 κ Ψ C Γ →
    ∀ (k : Nat),
      @Eq.{1} Benitoite.Release.Refinement.Ctx
        (Benitoite.Release.Refinement.Ctx.shiftE
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          k)
        (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
          (Benitoite.Release.shiftEnv k Γ))
@Benitoite.Release.Refinement.legacy_opContext : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {sg : Benitoite.Release.OpSig} {t : Benitoite.Release.Ty} {e : Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyNodeContext K P0 κ Ψ C Γ →
    Benitoite.Release.Refinement.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
        (@List.length.{0} Benitoite.Release.Refinement.TyKind κ) (@List.length.{0} (Option.{0} Benitoite.Release.Ty) Γ)
        (Benitoite.Release.Refinement.embedTy t) →
      (Benitoite.Release.Refinement.embedEff e).Canonical →
        @Eq.{1} Benitoite.Release.Refinement.Ctx
          ((Benitoite.Release.Refinement.embedOpSig sg).context
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            (Benitoite.Release.Refinement.embedTy t) (Benitoite.Release.Refinement.embedEff e))
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            (@List.cons.{0} (Option.{0} Benitoite.Release.Ty)
              (@Option.some.{0} Benitoite.Release.Ty
                (sg.ret.cont
                  (Benitoite.Release.Ty.shift (@List.length.{0} Benitoite.Release.TParam sg.tparams)
                    (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t)
                  (Benitoite.Release.Eff.shift (@List.length.{0} Benitoite.Release.TParam sg.tparams)
                    (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) e)))
              (@HAppend.hAppend.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                (List.{0} (Option.{0} Benitoite.Release.Ty)) (List.{0} (Option.{0} Benitoite.Release.Ty))
                (@instHAppendOfAppend.{0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                  (@List.instAppend.{0} (Option.{0} Benitoite.Release.Ty)))
                (Benitoite.Release.binds sg.params)
                (Benitoite.Release.shiftEnv (@List.length.{0} Benitoite.Release.TParam sg.tparams) Γ))))
@Benitoite.Release.Refinement.legacy_failureContext : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {E : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeContext K P0 κ Ψ C Γ →
    Benitoite.Release.Refinement.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
        (@List.length.{0} Benitoite.Release.Refinement.TyKind κ) (@List.length.{0} (Option.{0} Benitoite.Release.Ty) Γ)
        (Benitoite.Release.Refinement.embedTy E) →
      @Eq.{1} Benitoite.Release.Refinement.Ctx
        (Benitoite.Release.Refinement.failureContext
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (Benitoite.Release.Refinement.embedTy E))
        (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy)
          (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.none.{0} Benitoite.Release.Ty)
            (@List.cons.{0} (Option.{0} Benitoite.Release.Ty)
              (@Option.some.{0} Benitoite.Release.Ty
                (Benitoite.Release.Ty.shift (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
                  (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) E))
              (Benitoite.Release.shiftEnv (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1))) Γ))))
@Benitoite.Release.Refinement.LegacyClauseCases.nil_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {eb : Benitoite.Release.Eff} {a : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
    (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb (@List.nil.{0} Benitoite.Release.Clause) a e L)
@Benitoite.Release.Refinement.LegacyClauseCases.cons_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {eb : Benitoite.Release.Eff} {o : Benitoite.Release.OpRef} {n k : Nat}
  {m : Benitoite.Release.Comp} {cs : List.{0} Benitoite.Release.Clause} {t : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {sg : Benitoite.Release.OpSig} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb
          (@List.cons.{0} Benitoite.Release.Clause (Benitoite.Release.Clause.mk o n k m) cs) t e L) →
      Benitoite.Release.ClauseSig P0 B0 eb o sg →
        Benitoite.Release.NamesWF sg.names sg.params →
          @Eq.{1} Nat n (@List.length.{0} Benitoite.Release.Ty sg.params) →
            @Eq.{1} Nat k (@List.length.{0} Benitoite.Release.TParam sg.tparams) →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                  (Benitoite.Release.Refinement.LegacyJudgment.comp
                    (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.Refinement.TyKind)
                      Benitoite.Release.Refinement.KindCtx Benitoite.Release.Refinement.KindCtx
                      (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.Refinement.TyKind)
                        (@List.instAppend.{0} Benitoite.Release.Refinement.TyKind))
                      (@List.replicate.{0} Benitoite.Release.Refinement.TyKind
                        (@List.length.{0} Benitoite.Release.TParam sg.tparams)
                        Benitoite.Release.Refinement.TyKind.value)
                      κ)
                    Ψ.hideBuilders Q
                    (@HAppend.hAppend.{0, 0, 0} (List.{0} Benitoite.Release.TParam) (List.{0} Benitoite.Release.TParam)
                      (List.{0} Benitoite.Release.TParam)
                      (@instHAppendOfAppend.{0} (List.{0} Benitoite.Release.TParam)
                        (@List.instAppend.{0} Benitoite.Release.TParam))
                      sg.tparams C)
                    (@List.cons.{0} (Option.{0} Benitoite.Release.Ty)
                      (@Option.some.{0} Benitoite.Release.Ty
                        (sg.ret.cont
                          (Benitoite.Release.Ty.shift k (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t)
                          (Benitoite.Release.Eff.shift k (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
                            e)))
                      (@HAppend.hAppend.{0, 0, 0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                        (List.{0} (Option.{0} Benitoite.Release.Ty)) (List.{0} (Option.{0} Benitoite.Release.Ty))
                        (@instHAppendOfAppend.{0} (List.{0} (Option.{0} Benitoite.Release.Ty))
                          (@List.instAppend.{0} (Option.{0} Benitoite.Release.Ty)))
                        (Benitoite.Release.binds sg.params) (Benitoite.Release.shiftEnv k Γ)))
                    (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Ty
                      (Benitoite.Release.Ty.shift k (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))) R)
                    m (Benitoite.Release.Ty.shift k (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t)
                    (Benitoite.Release.Eff.shift k (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) e)
                    (@List.nil.{0} (Option.{0} Benitoite.Release.BuilderKind))) →
                Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                    (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb cs t e L) →
                  Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                    (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb
                      (@List.cons.{0} Benitoite.Release.Clause (Benitoite.Release.Clause.mk o n k m) cs) t e L)
@Benitoite.Release.Refinement.LegacyClauseCases.failure_case : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {E : Benitoite.Release.Ty}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {t : Benitoite.Release.Ty}
  {ec : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
      (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R
        (@List.cons.{0} Benitoite.Release.Clause (Benitoite.Release.Clause.fail E m)
          (@List.nil.{0} Benitoite.Release.Clause))
        t ec L) →
    Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.comp
          (@List.cons.{0} Benitoite.Release.Refinement.TyKind Benitoite.Release.Refinement.TyKind.value κ)
          Ψ.hideBuilders Q (@List.cons.{0} Benitoite.Release.TParam { } C)
          (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.none.{0} Benitoite.Release.Ty)
            (@List.cons.{0} (Option.{0} Benitoite.Release.Ty)
              (@Option.some.{0} Benitoite.Release.Ty
                (Benitoite.Release.Ty.shift (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
                  (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) E))
              (Benitoite.Release.shiftEnv (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1))) Γ)))
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Ty
            (Benitoite.Release.Ty.shift (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
              (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))))
            R)
          m
          (Benitoite.Release.Ty.shift (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
            (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t)
          (Benitoite.Release.Eff.shift (@OfNat.ofNat.{0} Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
            (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) ec)
          (@List.nil.{0} (Option.{0} Benitoite.Release.BuilderKind))) →
      Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
        (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R
          (@List.cons.{0} Benitoite.Release.Clause (Benitoite.Release.Clause.fail E m)
            (@List.nil.{0} Benitoite.Release.Clause))
          t ec L)
Benitoite.Release.Refinement.legacy_frame_adequate : ∀ (f : Benitoite.Release.Frame)
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.Frame.Adequate σ (Benitoite.Release.Refinement.embedFrame f)
Benitoite.Release.Refinement.legacy_cont_adequate : ∀ (k : Benitoite.Release.Cont)
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.Cont.Adequate σ (Benitoite.Release.Refinement.embedCont k)
Benitoite.Release.Refinement.legacy_cell_adequate : ∀ (c : Benitoite.Release.Cell)
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.Cell.Adequate σ (Benitoite.Release.Refinement.embedCell c)
Benitoite.Release.Refinement.legacy_store_adequate : ∀ (μ : Benitoite.Release.Store)
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.Store.Adequate σ (Benitoite.Release.Refinement.embedStore μ)
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.seven_empty_entries : And
  (Benitoite.Release.Refinement.HasTypeVQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy
      _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
    Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
    (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty)) (@List.nil.{0} Benitoite.Release.Refinement.Pred)
    (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit))
  (And
    (Benitoite.Release.Refinement.HasTypeVsQ
      (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
        Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins
      (Benitoite.Release.Refinement.embedStoreTy
        _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
      Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
      (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty)) (@List.nil.{0} Benitoite.Release.Refinement.Pred)
      (@List.cons.{0} Benitoite.Release.Refinement.Val
        (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
        (@List.nil.{0} Benitoite.Release.Refinement.Val))
      (@List.cons.{0} Benitoite.Release.Refinement.Ty
        (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
        (@List.nil.{0} Benitoite.Release.Refinement.Ty)))
    (And
      (Benitoite.Release.Refinement.HasTypeEachQ
        (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
          Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
        Benitoite.Release.Refinement.LegacyPatternExamples.builtins
        (Benitoite.Release.Refinement.embedStoreTy
          _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
        Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
        (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty)) (@List.nil.{0} Benitoite.Release.Refinement.Pred)
        (@List.cons.{0} Benitoite.Release.Refinement.Val
          (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
          (@List.nil.{0} Benitoite.Release.Refinement.Val))
        (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit))
      (And
        (Benitoite.Release.Refinement.HasTypeCQ
          (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
            Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
          Benitoite.Release.Refinement.LegacyPatternExamples.builtins
          (Benitoite.Release.Refinement.embedStoreTy
            _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
          Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
          (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty)) (@List.nil.{0} Benitoite.Release.Refinement.Pred)
          (@Option.none.{0} Benitoite.Release.Refinement.Ty)
          (Benitoite.Release.Refinement.Comp.ret
            (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit))
          (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
          (Benitoite.Release.Refinement.embedEff
            _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
          (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind)))
        (And
          (Benitoite.Release.Refinement.HasTypeArmsQ
            (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
              Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
            Benitoite.Release.Refinement.LegacyPatternExamples.builtins
            (Benitoite.Release.Refinement.embedStoreTy
              _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
            Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
            (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty))
            (@List.nil.{0} Benitoite.Release.Refinement.Pred) (@Option.none.{0} Benitoite.Release.Refinement.Ty)
            (@Option.none.{0} Benitoite.Release.Refinement.Term) (@List.nil.{0} Benitoite.Release.Refinement.Arm)
            (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
            (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
            (Benitoite.Release.Refinement.embedEff
              _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
            (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind)))
          (And
            (Benitoite.Release.Refinement.HasTypeClausesQ
              (Benitoite.Release.Refinement.embedProgramWithKinds
                Benitoite.Release.Refinement.LegacyPatternExamples.kinds
                Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
              Benitoite.Release.Refinement.LegacyPatternExamples.builtins
              (Benitoite.Release.Refinement.embedStoreTy
                _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
              Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
              (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty))
              (@List.nil.{0} Benitoite.Release.Refinement.Pred) (@Option.none.{0} Benitoite.Release.Refinement.Ty)
              (Benitoite.Release.Refinement.embedEff
                _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
              (@List.nil.{0} Benitoite.Release.Refinement.Clause)
              (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
              (Benitoite.Release.Refinement.embedEff
                _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
              (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind)))
            (Benitoite.Release.Refinement.HasFailureClause
              (Benitoite.Release.Refinement.embedProgramWithKinds
                Benitoite.Release.Refinement.LegacyPatternExamples.kinds
                Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
              Benitoite.Release.Refinement.LegacyPatternExamples.builtins
              (Benitoite.Release.Refinement.embedStoreTy
                _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
              Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
              (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty))
              (@List.nil.{0} Benitoite.Release.Refinement.Pred)
              (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
              (@Option.none.{0} Benitoite.Release.Refinement.Ty)
              (@List.cons.{0} Benitoite.Release.Refinement.Clause
                (Benitoite.Release.Refinement.Clause.fail
                  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
                  (Benitoite.Release.Refinement.Comp.ret
                    (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
                (@List.nil.{0} Benitoite.Release.Refinement.Clause))
              (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
              (Benitoite.Release.Refinement.embedEff
                _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
              (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind))))))))
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.match_with_truth : Benitoite.Release.Refinement.HasTypeCQ
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  (Benitoite.Release.Refinement.embedStoreTy
    _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
  Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
  (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty))
  (@List.cons.{0} Benitoite.Release.Refinement.Pred Benitoite.Release.Refinement.Pred.truth
    (@List.nil.{0} Benitoite.Release.Refinement.Pred))
  (@Option.none.{0} Benitoite.Release.Refinement.Ty)
  (Benitoite.Release.Refinement.Comp.match
    (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
    (@List.cons.{0} Benitoite.Release.Refinement.Arm
      (Benitoite.Release.Refinement.Arm.mk
        (@List.cons.{0} Benitoite.Release.Alt { pat := Benitoite.Release.Pat.wild, slots := @List.nil.{0} Nat }
          (@List.nil.{0} Benitoite.Release.Alt))
        (@Option.none.{0} Benitoite.Release.Refinement.Comp)
        (Benitoite.Release.Refinement.Comp.ret
          (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
      (@List.nil.{0} Benitoite.Release.Refinement.Arm)))
  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
  (Benitoite.Release.Refinement.embedEff
    _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
  (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind))
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.if_true_embedded : ∀
  (Φ : List.{0} Benitoite.Release.Refinement.Pred),
  Benitoite.Release.Refinement.HasTypeCQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy
      _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
    Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
    (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty)) Φ (@Option.none.{0} Benitoite.Release.Refinement.Ty)
    (Benitoite.Release.Refinement.Comp.ite
      (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean Bool.true))
      (Benitoite.Release.Refinement.Comp.ret
        (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit))
      (Benitoite.Release.Refinement.Comp.ret
        (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
    (Benitoite.Release.Refinement.embedEff
      _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
    (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind))
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.unit_operation_clause_embedded : ∀
  (Φ : List.{0} Benitoite.Release.Refinement.Pred),
  Benitoite.Release.Refinement.HasTypeClausesQ
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    (Benitoite.Release.Refinement.embedStoreTy
      _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S)
    Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.Refinement.TParamDecl)
    (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.Ty)) Φ (@Option.none.{0} Benitoite.Release.Refinement.Ty)
    (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.single "UnitEffect"))
    (@List.cons.{0} Benitoite.Release.Refinement.Clause
      (Benitoite.Release.Refinement.Clause.mk (Benitoite.Release.OpRef.user "unitOp")
        (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
        (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
        (Benitoite.Release.Refinement.Comp.ret
          (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
      (@List.nil.{0} Benitoite.Release.Refinement.Clause))
    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit)
    (Benitoite.Release.Refinement.embedEff
      _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E)
    (@List.nil.{0} (Option.{0} Benitoite.Release.Refinement.BuilderKind))
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.run_input : Benitoite.Release.Refinement.LegacyStateInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E
  (Benitoite.Release.State.run (Benitoite.Release.Comp.ret (Benitoite.Release.Val.const Benitoite.Release.Const.unit))
    (@List.nil.{0} Benitoite.Release.Frame) Benitoite.Release.Store.empty)
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.run_inputs_used : ∀ (σ : Benitoite.Release.Refinement.PathEnv),
  And
    (Benitoite.Release.StateTyE Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
      Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
      _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E
      (Benitoite.Release.State.run
        (Benitoite.Release.Comp.ret (Benitoite.Release.Val.const Benitoite.Release.Const.unit))
        (@List.nil.{0} Benitoite.Release.Frame) Benitoite.Release.Store.empty))
    (And
      (Benitoite.Release.Refinement.Closure.Adequate σ
        (Benitoite.Release.Refinement.Closure.pure
          (Benitoite.Release.Refinement.embedComp
            (Benitoite.Release.Comp.ret (Benitoite.Release.Val.const Benitoite.Release.Const.unit)))))
      (And
        (Benitoite.Release.Refinement.Cont.Adequate σ
          (Benitoite.Release.Refinement.embedCont (@List.nil.{0} Benitoite.Release.Frame)))
        (Benitoite.Release.Refinement.Store.Adequate σ
          (Benitoite.Release.Refinement.embedStore Benitoite.Release.Store.empty))))
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.byte_rejected : Not
  (Benitoite.Release.Refinement.LegacyStateInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
    Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins
    _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.E
    (Benitoite.Release.State.run
      (Benitoite.Release.Comp.ret
        (Benitoite.Release.Val.const
          (Benitoite.Release.Const.integer8 (@OfNat.ofNat.{0} Int (nat_lit 128) (@instOfNat (nat_lit 128))))))
      (@List.nil.{0} Benitoite.Release.Frame) Benitoite.Release.Store.empty))
Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.old_byte_accepted : Benitoite.Release.HasTypeV
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  _private.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.0.Benitoite.Release.Refinement.LegacyFullEmbeddingExamples.S
  (@List.nil.{0} Benitoite.Release.TParam) (@List.nil.{0} (Option.{0} Benitoite.Release.Ty))
  (Benitoite.Release.Val.const
    (Benitoite.Release.Const.integer8 (@OfNat.ofNat.{0} Int (nat_lit 128) (@instOfNat (nat_lit 128)))))
  (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.integer8)
```
