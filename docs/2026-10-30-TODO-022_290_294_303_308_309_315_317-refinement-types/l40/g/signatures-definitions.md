# 入口と定義の実型

```lean
@Benitoite.Release.Refinement.normal_reply_facts : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {out : Benitoite.Release.Refinement.Outcome} {v : Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          B.delta b ts es rs ws = some out →
            out = Benitoite.Release.Refinement.Outcome.val v →
              v.toTerm? = some t →
                ∀ (r : Benitoite.Release.Refinement.Pred),
                  r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
@Benitoite.Release.Refinement.normal_reply_facts_at : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          B.delta b ts es rs ws = some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = some t →
              ∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume →
                  Benitoite.Release.Refinement.Entails [] (Benitoite.Release.Refinement.predBind ν (r.open t))
Benitoite.Release.Refinement.StandardContracts.Row : Type
Benitoite.Release.Refinement.StandardContracts.Row.BodyTyped : Benitoite.Release.Refinement.StandardContracts.Row →
  Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
Benitoite.Release.Refinement.StandardKeyTyping.Table : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Type
Benitoite.Release.Refinement.StandardKeyTyping.KeyObservation : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.Ty → Prop
@Benitoite.Release.Refinement.HasTypeVQ.inv_lam_wf : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {ns : List String} {ps : List Benitoite.Release.Refinement.Ty}
  {body : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.lam ns ps body →
      ∃ r e,
        Benitoite.Release.Refinement.NamesWF ns ps ∧
          Benitoite.Release.Refinement.Ty.WF 0 (List.length C) (List.length Γ)
              (Benitoite.Release.Refinement.Ty.fn ns ps r e) ∧
            Benitoite.Release.Refinement.Ty.Sorted Γ (Benitoite.Release.Refinement.Ty.fn ns ps r e) ∧
              Benitoite.Release.Refinement.Ty.Declared P C Γ (Benitoite.Release.Refinement.Ty.fn ns ps r e)
@Benitoite.Release.Refinement.HasTypeVQ.canonical_function : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {t : Benitoite.Release.Refinement.Tel},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.fnCore = some t →
      (∃ f ts es, v = Benitoite.Release.Refinement.Val.fnRef f ts es) ∨
        (∃ b ts es rs, v = Benitoite.Release.Refinement.Val.prim b ts es rs) ∨
          (∃ o ts, v = Benitoite.Release.Refinement.Val.op o ts) ∨
            (∃ ns ps body, v = Benitoite.Release.Refinement.Val.lam ns ps body) ∨
              (∃ t body, v = Benitoite.Release.Refinement.Val.dependentLam t body) ∨
                (∃ runtime body, v = Benitoite.Release.Refinement.Val.closure runtime body) ∨
                  (∃ t e, v = Benitoite.Release.Refinement.Val.raise t e) ∨
                    ∃ f ts, v = Benitoite.Release.Refinement.Val.externalRef f ts
Benitoite.Release.Refinement.StandardMapReplaceValues.signature : (List Benitoite.Release.TParam →
    Benitoite.Release.Refinement.Ty → Benitoite.Release.TParam → Prop) →
  Benitoite.Release.Refinement.PrimSig
Benitoite.Release.Refinement.StandardMapReplaceValues.delta : List Benitoite.Release.ConName →
  Benitoite.Release.PrimName →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Eff →
        List Benitoite.Release.Refinement.RangeExpr →
          List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
Benitoite.Release.Refinement.Builtins.CoreAssumptions : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Prop
Benitoite.Release.Refinement.Builtins.ResponseAssumptions : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Prop
Benitoite.Release.Refinement.Program.WellTyped : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Prop
@Benitoite.Release.Refinement.HasTypeArmsQ.plain : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {R : Option Benitoite.Release.Refinement.Ty} {obs : Option Benitoite.Release.Refinement.Term}
  {alts : List Benitoite.Release.Alt} {body : Benitoite.Release.Refinement.Comp}
  {arms : List Benitoite.Release.Refinement.Arm} {a b : Benitoite.Release.Refinement.Ty}
  {ε : Benitoite.Release.Refinement.Eff} {δ : List Benitoite.Release.Refinement.Ty}
  {links : List Benitoite.Release.Refinement.FieldLink},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.LinksValid alts δ.length links →
      Benitoite.Release.Refinement.FactsWF P C (Benitoite.Release.Refinement.bindParams Γ δ)
          (Benitoite.Release.Refinement.fieldFacts δ.length obs links) →
        Benitoite.Release.Refinement.FactsWF P C Γ
            (Benitoite.Release.Refinement.pathFacts obs
              (Benitoite.Release.Refinement.matchedTests alts ++ Benitoite.Release.Refinement.excludedTests alts)) →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C (Benitoite.Release.Refinement.bindParams Γ δ)
              (Benitoite.Release.Refinement.fieldFacts δ.length obs links ++
                Benitoite.Release.Refinement.liftMany δ.length
                  (Benitoite.Release.Refinement.pathFacts obs (Benitoite.Release.Refinement.matchedTests alts) ++ Φ))
              (Option.map (Benitoite.Release.Refinement.Ty.shiftV δ.length 0) R) body
              (Benitoite.Release.Refinement.Ty.shiftV δ.length 0 b)
              (Benitoite.Release.Refinement.Eff.shiftV δ.length 0 ε)
              (Benitoite.Release.Refinement.localExtend δ.length Δ) →
            Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Q C Γ
                (Benitoite.Release.Refinement.pathFacts obs (Benitoite.Release.Refinement.excludedTests alts) ++ Φ) R
                obs arms a b ε Δ →
              Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Q C Γ Φ R obs
                (Benitoite.Release.Refinement.Arm.mk alts none body :: arms) a b ε Δ
@Benitoite.Release.Refinement.HasTypeArmsQ.guarded : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {R : Option Benitoite.Release.Refinement.Ty} {obs : Option Benitoite.Release.Refinement.Term}
  {alts : List Benitoite.Release.Alt} {guard body : Benitoite.Release.Refinement.Comp}
  {arms : List Benitoite.Release.Refinement.Arm} {a b : Benitoite.Release.Refinement.Ty}
  {ε : Benitoite.Release.Refinement.Eff} {δ : List Benitoite.Release.Refinement.Ty}
  {p : Benitoite.Release.Refinement.Pred} {links : List Benitoite.Release.Refinement.FieldLink},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.LinksValid alts δ.length links →
      Benitoite.Release.Refinement.FactsWF P C (Benitoite.Release.Refinement.bindParams Γ δ)
          (Benitoite.Release.Refinement.fieldFacts δ.length obs links) →
        Benitoite.Release.Refinement.FactsWF P C Γ
            (Benitoite.Release.Refinement.pathFacts obs
              (Benitoite.Release.Refinement.matchedTests alts ++ Benitoite.Release.Refinement.excludedTests alts)) →
          Benitoite.Release.Refinement.Ty.Annotation P C
              (Benitoite.Release.Refinement.hideConts (Benitoite.Release.Refinement.bindParams Γ δ))
              ((Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean).refined p) →
            Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C
                (Benitoite.Release.Refinement.hideConts (Benitoite.Release.Refinement.bindParams Γ δ))
                (Benitoite.Release.Refinement.fieldFacts δ.length obs links ++
                  Benitoite.Release.Refinement.liftMany δ.length
                    (Benitoite.Release.Refinement.pathFacts obs (Benitoite.Release.Refinement.matchedTests alts) ++ Φ))
                none guard ((Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean).refined p)
                Benitoite.Release.Refinement.Eff.empty (Benitoite.Release.Refinement.localExtend δ.length Δ) →
              Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C (Benitoite.Release.Refinement.bindParams Γ δ)
                  (p.open (Benitoite.Release.Refinement.Term.boolean true) ::
                    (Benitoite.Release.Refinement.fieldFacts δ.length obs links ++
                      Benitoite.Release.Refinement.liftMany δ.length
                        (Benitoite.Release.Refinement.pathFacts obs (Benitoite.Release.Refinement.matchedTests alts) ++
                          Φ)))
                  (Option.map (Benitoite.Release.Refinement.Ty.shiftV δ.length 0) R) body
                  (Benitoite.Release.Refinement.Ty.shiftV δ.length 0 b)
                  (Benitoite.Release.Refinement.Eff.shiftV δ.length 0 ε)
                  (Benitoite.Release.Refinement.localExtend δ.length Δ) →
                Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
                  Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Q C Γ Φ R obs
                    (Benitoite.Release.Refinement.Arm.mk alts (some guard) body :: arms) a b ε Δ
```
