# 群 J の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.ModelHttp.entries :
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

```lean
Benitoite.Release.Refinement.ModelHttp.effects :
Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

```lean
Benitoite.Release.Refinement.ModelHttp.ioResponse :
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

```lean
Benitoite.Release.Refinement.ModelHttp.builtins :
Benitoite.Release.Refinement.Builtins
```

```lean
Benitoite.Release.Refinement.ModelHttp.sig_cases :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
    b = "Reference.get" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refGet ∨
      b = "Reference.set" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refSet ∨
        b = "Http.checkRequestIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.checkRequestIn ∨
          b = "Http.requestInValue" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.requestInValue ∨
            b = "Http.sendIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.sendIn ∨
              b = "Http.widenRequestIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.widenRequestIn ∨
                b = Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∧
                  s = Benitoite.Release.Refinement.ScopeSignatures.pathBases
```

```lean
Benitoite.Release.Refinement.ModelHttp.substitutionAssumptions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P Benitoite.Release.Refinement.ModelHttp.builtins
```

```lean
Benitoite.Release.Refinement.ModelHttp.sig_scoped :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg → Benitoite.Release.Refinement.PrimSig.Scoped P sg
```

```lean
Benitoite.Release.Refinement.ModelHttp.sourceTelRows :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < sg.neffs) sg.tel
```

```lean
Benitoite.Release.Refinement.ModelHttp.sat_unconstrained :
∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.ModelHttp.builtins.sat [] t.norm { }
```

```lean
Benitoite.Release.Refinement.ModelHttp.admits_sat :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : Benitoite.Release.Refinement.TypeCtx}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelHttp.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

```lean
Benitoite.Release.Refinement.ModelHttp.pathBases_shape :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      sg.PathBasesShape Benitoite.Release.Refinement.ModelHttp.builtins b
```

```lean
Benitoite.Release.Refinement.ModelHttp.io_op :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.ModelHttp.builtins.ShapeOk b sg
```

```lean
Benitoite.Release.Refinement.ModelHttp.opEff_io :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
    sg.opEff = some l →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

```lean
Benitoite.Release.Refinement.ModelHttp.effect_ops :
∀ {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  Benitoite.Release.Refinement.ModelHttp.builtins.effects l = some bs →
    b ∈ bs →
      ∃ sg,
        Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg ∧
          (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            sg.opEff = some l
```

```lean
Benitoite.Release.Refinement.ModelHttp.state_effect :
Benitoite.Release.Refinement.ModelHttp.builtins.effects Benitoite.Release.stateEff = some []
```

```lean
Benitoite.Release.Refinement.ModelHttp.ref_get :
∃ s,
  Benitoite.Release.Refinement.ModelHttp.builtins.sig Benitoite.Release.Refinement.ModelHttp.builtins.refGet = some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

```lean
Benitoite.Release.Refinement.ModelHttp.ref_set :
∃ s,
  Benitoite.Release.Refinement.ModelHttp.builtins.sig Benitoite.Release.Refinement.ModelHttp.builtins.refSet = some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

```lean
Benitoite.Release.Refinement.ModelHttp.store_shape :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
    sg.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → sg.StoreShape
```

```lean
Benitoite.Release.Refinement.ModelHttp.store_admits :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg → ts.length = sg.tparams.length → sg.admits C ts
```

```lean
Benitoite.Release.Refinement.ModelHttp.pure_response :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          ∃ out,
            Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ModelHttp.delta_typed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          ∃ out,
            Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.ModelHttp.pure_outcome :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = some out →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ModelHttp.normal_facts :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws =
              some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = some t →
              ∀ (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

```lean
Benitoite.Release.Refinement.ModelHttp.send_response :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ "Http.sendIn"
        Benitoite.Release.Refinement.ScopeSignatures.sendIn ts es rs ws a e →
      (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                    (Benitoite.Release.Refinement.ScopeSignatures.sendIn.shapeAt ws) ws obs) ∧
        ∃ out obs, Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es ws out obs
```

```lean
Benitoite.Release.Refinement.ModelHttp.io_typed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.ModelHttp.io_kind :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
    Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
        ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

```lean
Benitoite.Release.Refinement.ModelHttp.io_exists :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          ∃ out obs, Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs
```

```lean
Benitoite.Release.Refinement.ModelHttp.sent_request :
∀ {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {ws : List Benitoite.Release.Refinement.Val}
  {out : Benitoite.Release.Refinement.Outcome} {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
    b = "Http.sendIn" ∧
      ∃ w req t,
        ws = [w] ∧
          Benitoite.Release.Refinement.ModelHttp.valueRun [w] = Benitoite.Release.Refinement.Outcome.val req ∧
            Benitoite.Release.Refinement.groundVal req = true ∧ req.reqTarget = some t ∧ w.target? = some t ∧ obs = [t]
```

```lean
Benitoite.Release.Refinement.ModelHttp.targetAgreement :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P Benitoite.Release.Refinement.ModelHttp.builtins
```

```lean
Benitoite.Release.Refinement.ModelHttp.obs_allowed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
              ∃ l,
                sg.opEff = some l ∧
                  ∀ (t : Benitoite.Scope.Domain.Target),
                    t ∈ obs →
                      Benitoite.Release.Refinement.Eff.Allows σ Benitoite.Release.Refinement.ModelHttp.builtins.effKind
                        e l t
```

```lean
Benitoite.Release.Refinement.ModelHttp.pathBases_no_io :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      ∀ (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
        (ws : List Benitoite.Release.Refinement.Val) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs
```

```lean
Benitoite.Release.Refinement.ModelHttp.send_held :
∀ {req : Benitoite.Release.Refinement.Val} {t : Benitoite.Scope.Domain.Target}
  {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.groundVal req = true →
    req.reqTarget = some t →
      Benitoite.Release.Refinement.ScopedIOResponse.Reply Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.http
          out →
        ∀ (r : Benitoite.Release.Refinement.RangeExpr) (snap : Option Benitoite.Release.Refinement.PathEnv),
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" [] []
              [Benitoite.Release.Refinement.Val.checkedRequest t req] out [t] ∧
            Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" [] []
              [Benitoite.Release.Refinement.Val.checkedAt r snap t (some req)] out [t]
```

```lean
Benitoite.Release.Refinement.ModelHttp.send_without_request :
∀ (t : Benitoite.Scope.Domain.Target) (r : Benitoite.Release.Refinement.RangeExpr)
  (snap : Option Benitoite.Release.Refinement.PathEnv) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
  (obs : List Benitoite.Scope.Domain.Target),
  ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
        [Benitoite.Release.Refinement.Val.checked t] out obs ∧
    ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
        [Benitoite.Release.Refinement.Val.checkedAt r snap t none] out obs
```

```lean
Benitoite.Release.Refinement.ModelHttp.send_mismatch :
∀ {req : Benitoite.Release.Refinement.Val} {t other : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.groundVal req = true →
    req.reqTarget = some t →
      t ≠ other →
        ∀ (r : Benitoite.Release.Refinement.RangeExpr) (snap : Option Benitoite.Release.Refinement.PathEnv)
          (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
          (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
          ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
                [Benitoite.Release.Refinement.Val.checkedRequest other req] out obs ∧
            ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
                [Benitoite.Release.Refinement.Val.checkedAt r snap other (some req)] out obs
```

```lean
Benitoite.Release.Refinement.ModelHttp.responseAssumptions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P Benitoite.Release.Refinement.ModelHttp.builtins
```

```lean
Benitoite.Release.Refinement.ModelHttp.scopeConditions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelHttp.builtins
```

```lean
Benitoite.Release.Refinement.ScopeModels.conditions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins ∧
      Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins ∧
        Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelHttp.builtins
```

```lean
Benitoite.Release.Refinement.Model.scopeConditions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins
```

```lean
Benitoite.Release.Refinement.ModelTargets.scopeConditions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins
```

```lean
Benitoite.Release.Refinement.ModelScopeConditions.core :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
      (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
          (o : Benitoite.Release.OpaqueName),
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
              (Benitoite.Release.Refinement.Ty.opaque o
                (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
            B.isResource o = true → ∃ r, B.releaseResponse v r) →
        Benitoite.Release.Refinement.Builtins.CoreAssumptions P B
```

```lean
Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_typed :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
            B.externalResponse f ts vs out obs →
              Benitoite.Release.Refinement.Outcome.Carrier P B Ψ out a ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

```lean
Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      P.ExternalWF →
        P.externalFunction f = some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → ∃ out obs, B.externalResponse f ts vs out obs
```

```lean
Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_no_targets :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → B.externalResponse f ts vs out obs → obs = []
```

```lean
Benitoite.Release.Refinement.Builtins.CoreAssumptions.release_exists :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
      (o : Benitoite.Release.OpaqueName),
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
          (Benitoite.Release.Refinement.Ty.opaque o
            (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
        B.isResource o = true → ∃ r, B.releaseResponse v r
```

