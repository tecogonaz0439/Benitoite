# 群 I の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.ModelTargets.entries :
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

```lean
Benitoite.Release.Refinement.ModelTargets.effects :
Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

```lean
Benitoite.Release.Refinement.ModelTargets.readObs :
List Benitoite.Release.Refinement.Val → List Benitoite.Scope.Domain.Target
```

```lean
Benitoite.Release.Refinement.ModelTargets.exitCode :
List Benitoite.Release.Refinement.Val → Int
```

```lean
Benitoite.Release.Refinement.ModelTargets.ioResponse :
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

```lean
Benitoite.Release.Refinement.ModelTargets.builtins :
Benitoite.Release.Refinement.Builtins
```

```lean
Benitoite.Release.Refinement.ModelTargets.sig_cases :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
    b = "Reference.get" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refGet ∨
      b = "Reference.set" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refSet ∨
        b = "print" ∧ s = Benitoite.Release.Refinement.ModelTargets.printSig ∨
          b = "exit" ∧ s = Benitoite.Release.Refinement.ModelTargets.exitSig ∨
            b = "File.readText" ∧ s = Benitoite.Release.Refinement.ModelTargets.readTextSig ∨
              b = "Scope.checkPathIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.checkPathIn ∨
                b = "Scope.pathInValue" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.pathInValue ∨
                  b = "Scope.widenPathIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.widenPathIn ∨
                    b = "File.readTextIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.readTextIn ∨
                      b = "File.readBytesIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.readBytesIn ∨
                        b = "File.writeTextIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.writeTextIn ∨
                          b = "File.writeBytesIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.writeBytesIn ∨
                            b = "File.appendTextIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.appendTextIn ∨
                              b = "File.appendBytesIn" ∧
                                  s = Benitoite.Release.Refinement.ScopeSignatures.appendBytesIn ∨
                                b = Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∧
                                  s = Benitoite.Release.Refinement.ScopeSignatures.pathBases
```

```lean
Benitoite.Release.Refinement.ModelTargets.substitutionAssumptions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P Benitoite.Release.Refinement.ModelTargets.builtins
```

```lean
Benitoite.Release.Refinement.ModelTargets.sig_scoped :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        Benitoite.Release.Refinement.PrimSig.Scoped P s
```

```lean
Benitoite.Release.Refinement.ModelTargets.sourceTelRows :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < s.neffs) s.tel
```

```lean
Benitoite.Release.Refinement.ModelTargets.sat_unconstrained :
∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.ModelTargets.builtins.sat [] t.norm { }
```

```lean
Benitoite.Release.Refinement.ModelTargets.admits_sat :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : Benitoite.Release.Refinement.TypeCtx}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelTargets.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

```lean
Benitoite.Release.Refinement.ModelTargets.pathBases_shape :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      s.PathBasesShape Benitoite.Release.Refinement.ModelTargets.builtins b
```

```lean
Benitoite.Release.Refinement.ModelTargets.io_op :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.ModelTargets.builtins.ShapeOk b s
```

```lean
Benitoite.Release.Refinement.ModelTargets.opEff_io :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
    s.opEff = some l →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

```lean
Benitoite.Release.Refinement.ModelTargets.effect_ops :
∀ {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  Benitoite.Release.Refinement.ModelTargets.builtins.effects l = some bs →
    b ∈ bs →
      ∃ s,
        Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s ∧
          (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            s.opEff = some l
```

```lean
Benitoite.Release.Refinement.ModelTargets.state_effect :
Benitoite.Release.Refinement.ModelTargets.builtins.effects Benitoite.Release.stateEff = some []
```

```lean
Benitoite.Release.Refinement.ModelTargets.ref_get :
∃ s,
  Benitoite.Release.Refinement.ModelTargets.builtins.sig Benitoite.Release.Refinement.ModelTargets.builtins.refGet =
      some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

```lean
Benitoite.Release.Refinement.ModelTargets.ref_set :
∃ s,
  Benitoite.Release.Refinement.ModelTargets.builtins.sig Benitoite.Release.Refinement.ModelTargets.builtins.refSet =
      some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

```lean
Benitoite.Release.Refinement.ModelTargets.store_shape :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
```

```lean
Benitoite.Release.Refinement.ModelTargets.store_admits :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s → ts.length = s.tparams.length → s.admits C ts
```

```lean
Benitoite.Release.Refinement.ModelTargets.pure_response :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          ∃ out,
            Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out
                    a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ModelTargets.delta_typed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          ∃ out,
            Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out
                    a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.ModelTargets.pure_outcome :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = some out →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ModelTargets.normal_facts :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws =
              some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = some t →
              ∀ (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

```lean
Benitoite.Release.Refinement.ModelTargets.io_typed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.ModelTargets.io_kind :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
    Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws a
        e →
      Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
        (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
            ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
          sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
            ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v
```

```lean
Benitoite.Release.Refinement.ModelTargets.io_exists :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          ∃ out obs, Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs
```

```lean
Benitoite.Release.Refinement.ModelTargets.responseAssumptions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P Benitoite.Release.Refinement.ModelTargets.builtins
```

```lean
Benitoite.Release.Refinement.ModelTargets.targetAgreement :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P Benitoite.Release.Refinement.ModelTargets.builtins
```

```lean
Benitoite.Release.Refinement.ModelTargets.obs_allowed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
              ∃ l,
                sg.opEff = some l ∧
                  ∀ (t : Benitoite.Scope.Domain.Target),
                    t ∈ obs →
                      Benitoite.Release.Refinement.Eff.Allows σ
                        Benitoite.Release.Refinement.ModelTargets.builtins.effKind e l t
```

```lean
Benitoite.Release.Refinement.ModelTargets.scopeConditions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins
```

