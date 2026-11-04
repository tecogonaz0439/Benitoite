# 段末の実署名（続き）

## Benitoite.Release.Refinement.ModelScopeConditions.opEff_io

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 18。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
      B.sig b = Option.some s →
        s.opEff = Option.some l →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

## Benitoite.Release.Refinement.ModelScopeConditions.pathBases_shape

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 14。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s → s.kind = Benitoite.Release.Refinement.PrimKind.pathBases → s.PathBasesShape B b
```

## Benitoite.Release.Refinement.ModelScopeConditions.ref_get

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 24。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∃ s, B.sig B.refGet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

## Benitoite.Release.Refinement.ModelScopeConditions.ref_set

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 25。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∃ s, B.sig B.refSet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

## Benitoite.Release.Refinement.ModelScopeConditions.sat_unconstrained

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 10。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.Ty.WF 0 0 0 t → B.sat [] t.norm { }
```

## Benitoite.Release.Refinement.ModelScopeConditions.sig_scoped

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 9。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s → Benitoite.Release.Refinement.PrimSig.Scoped P s
```

## Benitoite.Release.Refinement.ModelScopeConditions.state_effect

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 23。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B → B.effects Benitoite.Release.stateEff = Option.some []
```

## Benitoite.Release.Refinement.ModelScopeConditions.store_admits

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 27。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
      (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = Option.some s →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
            s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
              s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → ts.length = s.tparams.length → s.admits C ts
```

## Benitoite.Release.Refinement.ModelScopeConditions.store_shape

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 26。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s → s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
```

## Benitoite.Release.Refinement.ModelScopeConditions.toResponseAssumptions

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 5。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B → Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B
```

## Benitoite.Release.Refinement.ModelScopeConditions.toSubstitutionAssumptions

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 5。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B
```

## Benitoite.Release.Refinement.ModelScopeConditions.toTargetAgreement

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 5。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B → Benitoite.Release.Refinement.Builtins.TargetAgreement P B
```

## Benitoite.Release.Refinement.ModelTargets.admits_sat

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 140。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : Benitoite.Release.Refinement.TypeCtx}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelTargets.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

## Benitoite.Release.Refinement.ModelTargets.builtins

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 55。

```lean
Benitoite.Release.Refinement.Builtins
```

## Benitoite.Release.Refinement.ModelTargets.delta_typed

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 232。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          ∃ out,
            Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out
                    a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.ModelTargets.effect_ops

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 182。

```lean
∀ {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  Benitoite.Release.Refinement.ModelTargets.builtins.effects l = Option.some bs →
    b ∈ bs →
      ∃ s,
        Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s ∧
          (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            s.opEff = Option.some l
```

## Benitoite.Release.Refinement.ModelTargets.effects

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 25。

```lean
Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

## Benitoite.Release.Refinement.ModelTargets.entries

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 16。

```lean
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

## Benitoite.Release.Refinement.ModelTargets.exitCode

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 42。

```lean
List Benitoite.Release.Refinement.Val → Int
```

## Benitoite.Release.Refinement.ModelTargets.exitSig

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ModelTargets.ioResponse

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 46。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.ModelTargets.io_exists

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 369。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          ∃ out obs, Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.ModelTargets.io_kind

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 346。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
    Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws a
        e →
      Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
        (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
            ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
          sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
            ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v
```

## Benitoite.Release.Refinement.ModelTargets.io_op

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 164。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.ModelTargets.builtins.ShapeOk b s
```

## Benitoite.Release.Refinement.ModelTargets.io_typed

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 326。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.ModelTargets.normal_facts

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 252。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws =
              Option.some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = Option.some t →
              ∀ (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

## Benitoite.Release.Refinement.ModelTargets.obs_allowed

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 432。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
              ∃ l,
                sg.opEff = Option.some l ∧
                  ∀ (t : Benitoite.Scope.Domain.Target),
                    t ∈ obs →
                      Benitoite.Release.Refinement.Eff.Allows σ
                        Benitoite.Release.Refinement.ModelTargets.builtins.effKind e l t
```

## Benitoite.Release.Refinement.ModelTargets.opEff_io

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 177。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
    s.opEff = Option.some l →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

## Benitoite.Release.Refinement.ModelTargets.pathBases_shape

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 156。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      s.PathBasesShape Benitoite.Release.Refinement.ModelTargets.builtins b
```

## Benitoite.Release.Refinement.ModelTargets.printSig

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 9。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ModelTargets.pure_outcome

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 241。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = Option.some out →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ModelTargets.pure_response

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 216。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          ∃ out,
            Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out
                    a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ModelTargets.readObs

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 34。

```lean
List Benitoite.Release.Refinement.Val → List Benitoite.Scope.Domain.Target
```

## Benitoite.Release.Refinement.ModelTargets.readTextSig

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 13。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ModelTargets.ref_get

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 194。

```lean
∃ s,
  Benitoite.Release.Refinement.ModelTargets.builtins.sig Benitoite.Release.Refinement.ModelTargets.builtins.refGet =
      Option.some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

## Benitoite.Release.Refinement.ModelTargets.ref_set

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 196。

```lean
∃ s,
  Benitoite.Release.Refinement.ModelTargets.builtins.sig Benitoite.Release.Refinement.ModelTargets.builtins.refSet =
      Option.some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

## Benitoite.Release.Refinement.ModelTargets.responseAssumptions

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 401。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P Benitoite.Release.Refinement.ModelTargets.builtins
```

## Benitoite.Release.Refinement.ModelTargets.sat_unconstrained

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 137。

```lean
∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.ModelTargets.builtins.sat [] t.norm { }
```

## Benitoite.Release.Refinement.ModelTargets.scopeConditions

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 442。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins
```

## Benitoite.Release.Refinement.ModelTargets.sig_cases

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 63。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
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

## Benitoite.Release.Refinement.ModelTargets.sig_scoped

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 108。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
        Benitoite.Release.Refinement.PrimSig.Scoped P s
```

## Benitoite.Release.Refinement.ModelTargets.sourceTelRows

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 133。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
        Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < s.neffs) s.tel
```

## Benitoite.Release.Refinement.ModelTargets.state_effect

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 192。

```lean
Benitoite.Release.Refinement.ModelTargets.builtins.effects Benitoite.Release.stateEff = Option.some []
```

## Benitoite.Release.Refinement.ModelTargets.store_admits

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 208。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
    ts.length = s.tparams.length → s.admits C ts
```

## Benitoite.Release.Refinement.ModelTargets.store_shape

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 199。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelTargets.builtins.sig b = Option.some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
```

## Benitoite.Release.Refinement.ModelTargets.substitutionAssumptions

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 87。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P Benitoite.Release.Refinement.ModelTargets.builtins
```

## Benitoite.Release.Refinement.ModelTargets.targetAgreement

所在: `formal/Benitoite/Release/Refinement/ModelTargets.lean`、行: 419。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P Benitoite.Release.Refinement.ModelTargets.builtins
```

## Benitoite.Release.Refinement.ModelTargetsExamples.call_arguments

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 22。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ
    Benitoite.Release.Refinement.ScopeSignatures.pathBasesName Benitoite.Release.Refinement.ScopeSignatures.pathBases []
    [] [] [] Benitoite.Release.Refinement.Ty.pathBases
    (Benitoite.Release.Refinement.Eff.single Benitoite.Release.Refinement.processEnvironmentEff)
```

## Benitoite.Release.Refinement.ModelTargetsExamples.call_typed

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 44。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeCQ P Benitoite.Release.Refinement.Model.builtins Ψ Benitoite.Release.Qempty [] []
    [] Option.none
    (Benitoite.Release.Refinement.Comp.app
      (Benitoite.Release.Refinement.Val.prim Benitoite.Release.Refinement.ScopeSignatures.pathBasesName [] [] []) [])
    Benitoite.Release.Refinement.Ty.pathBases
    (Benitoite.Release.Refinement.Eff.single Benitoite.Release.Refinement.processEnvironmentEff)
```

## Benitoite.Release.Refinement.ModelTargetsExamples.issue

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 52。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {σ : Benitoite.Release.Refinement.PathEnv}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view =
      Benitoite.Release.Refinement.Comp.app
        (Benitoite.Release.Refinement.Val.prim Benitoite.Release.Refinement.ScopeSignatures.pathBasesName [] [] []) [] →
    Benitoite.Release.Refinement.NoHandler k
        (Benitoite.Release.OpRef.prim Benitoite.Release.Refinement.ScopeSignatures.pathBasesName) →
      σ.Valid →
        Benitoite.Release.Refinement.Step P Benitoite.Release.Refinement.Model.builtins σ
            (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.mk q.capture
                (Benitoite.Release.Refinement.Comp.issuePathBases
                  Benitoite.Release.Refinement.ScopeSignatures.pathBasesName))
              k μ) ∧
          Benitoite.Release.Refinement.Step P Benitoite.Release.Refinement.Model.builtins σ
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.mk q.capture
                  (Benitoite.Release.Refinement.Comp.issuePathBases
                    Benitoite.Release.Refinement.ScopeSignatures.pathBasesName))
                k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.pathBases Benitoite.Release.Refinement.ScopeSignatures.pathBasesName
                  σ))
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                k μ) ∧
            Benitoite.Release.Refinement.Event.Covered Benitoite.Release.Refinement.Model.builtins [] []
                Benitoite.Release.Refinement.ScopeSignatures.pathBases.eff
                (Benitoite.Release.Refinement.Event.pathBases Benitoite.Release.Refinement.ScopeSignatures.pathBasesName
                  σ) ∧
              ∃ bs,
                Benitoite.Release.Refinement.Model.builtins.effects Benitoite.Release.Refinement.processEnvironmentEff =
                    Option.some bs ∧
                  Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∈ bs
```

## Benitoite.Release.Refinement.ModelTargetsExamples.issue_to_at

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 65。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (kind : Benitoite.Scope.Domain.Kind) (name : Benitoite.Release.OpaqueName)
  (shape : Benitoite.Release.Refinement.ResultShape) (pattern input : Benitoite.Release.Refinement.Val)
  (index : Benitoite.Release.Refinement.RangeIx),
  σ.Valid →
    have body :=
      Benitoite.Release.Refinement.Comp.checkAt kind name shape (Option.some (Benitoite.Release.Refinement.Val.var 0))
        pattern input index;
    Benitoite.Release.Refinement.Steps P Benitoite.Release.Refinement.Model.builtins σ
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure
          ((Benitoite.Release.Refinement.Comp.app
                (Benitoite.Release.Refinement.Val.prim Benitoite.Release.Refinement.ScopeSignatures.pathBasesName [] []
                  [])
                []).letIn
            body))
        [] Benitoite.Release.Refinement.Store.empty)
      [Benitoite.Release.Refinement.Event.pathBases Benitoite.Release.Refinement.ScopeSignatures.pathBasesName σ]
      (Benitoite.Release.Refinement.State.run
        ((Benitoite.Release.Refinement.Closure.pure body).apply [Benitoite.Release.Refinement.Val.pathBases σ]) []
        Benitoite.Release.Refinement.Store.empty)
```

## Benitoite.Release.Refinement.ModelTargetsExamples.issued_at

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 111。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (kind : Benitoite.Scope.Domain.Kind) (name : Benitoite.Release.OpaqueName)
  (shape : Benitoite.Release.Refinement.ResultShape) (pattern input : Benitoite.Release.Refinement.Val)
  (index : Benitoite.Release.Refinement.RangeIx),
  ∃ next,
    Benitoite.Release.Refinement.Step P Benitoite.Release.Refinement.Model.builtins σ
      (Benitoite.Release.Refinement.State.run
        ((Benitoite.Release.Refinement.Closure.pure
              (Benitoite.Release.Refinement.Comp.checkAt kind name shape
                (Option.some (Benitoite.Release.Refinement.Val.var 0)) pattern input index)).apply
          [Benitoite.Release.Refinement.Val.pathBases σ])
        [] Benitoite.Release.Refinement.Store.empty)
      Option.none next
```

## Benitoite.Release.Refinement.ModelTargetsExamples.issued_current

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 80。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snap : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared Benitoite.Release.Refinement.Model.builtins
      (Benitoite.Release.Refinement.Capture.empty.extendMany [Benitoite.Release.Refinement.Val.pathBases σ]) kind name
      (Option.some (Benitoite.Release.Refinement.Val.var 0)) pattern input index snap pat target bound →
    ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = Option.some ρ → ρ = σ
```

## Benitoite.Release.Refinement.ModelTargetsExamples.required_base

所在: `formal/Benitoite/Release/Refinement/ModelTargetsExamples.lean`、行: 89。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (kind : Benitoite.Scope.Domain.Kind) (name : Benitoite.Release.OpaqueName)
  (shape : Benitoite.Release.Refinement.ResultShape) (pattern input : Benitoite.Release.Refinement.Val)
  (b : Benitoite.Release.Refinement.PathBase) (p : Benitoite.Scope.Domain.PathPattern),
  have s :=
    Benitoite.Release.Refinement.State.run
      ((Benitoite.Release.Refinement.Closure.pure
            (Benitoite.Release.Refinement.Comp.checkAt kind name shape
              (Option.some (Benitoite.Release.Refinement.Val.var 0)) pattern input
              (Benitoite.Release.Refinement.RangeIx.fixed (Benitoite.Release.Refinement.RangeExpr.based b p)))).apply
        [Benitoite.Release.Refinement.Val.pathBases σ])
      [] Benitoite.Release.Refinement.Store.empty;
  Benitoite.Release.Refinement.PathEnv.Required P Benitoite.Release.Refinement.Model.builtins s
      (Benitoite.Release.Refinement.PathRequirement.base b) ∧
    Benitoite.Release.Refinement.PreparationNode.Reachable P Benitoite.Release.Refinement.Model.builtins
      (Benitoite.Release.Refinement.PreparationNode.state s)
      (Benitoite.Release.Refinement.PreparationNode.range (Benitoite.Release.Refinement.RangeExpr.based b p))
```

## Benitoite.Release.Refinement.NamesWF

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 105。

```lean
List String → List Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.NoHandler

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 33。

```lean
Benitoite.Release.Refinement.Cont → Benitoite.Release.OpRef → Prop
```

## Benitoite.Release.Refinement.NoHandler.splitHandler_none

所在: `formal/Benitoite/Release/Refinement/Step.lean`、行: 16。

```lean
∀ {k : Benitoite.Release.Refinement.Cont} {o : Benitoite.Release.OpRef},
  Benitoite.Release.Refinement.NoHandler k o → Benitoite.Release.Refinement.splitHandler o k = Option.none
```

## Benitoite.Release.Refinement.NormalReplyExamples.concrete_step_selections

所在: `formal/Benitoite/Release/Refinement/NormalReplyExamples.lean`、行: 488。

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv),
  (∀ (b : String),
      b ∈ ["Example.unit", "Example.ioUnit"] →
        ∃ event dest,
          Benitoite.Release.Refinement.step Benitoite.Release.Refinement.NormalReplyExamples.modelProgram✝
                Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝ σ
                Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝.selectOracle
                (fun x x_1 x_2 => (Benitoite.Release.Refinement.Outcome.err "Unused", []))
                Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝.selectRelease
                Benitoite.Release.Refinement.Store.selectFresh
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.NormalReplyExamples.call✝ b))
                  [] Benitoite.Release.Refinement.Store.empty) =
              Option.some (event, dest) ∧
            Benitoite.Release.Refinement.Step Benitoite.Release.Refinement.NormalReplyExamples.modelProgram✝
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝ σ
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.NormalReplyExamples.call✝ b))
                [] Benitoite.Release.Refinement.Store.empty)
              event dest) ∧
    (∃ event dest,
        Benitoite.Release.Refinement.step Benitoite.Release.Refinement.NormalReplyExamples.modelProgram✝
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝ σ
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝.selectOracle
              (fun x x_1 x_2 => (Benitoite.Release.Refinement.Outcome.err "Unused", []))
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝.selectRelease
              Benitoite.Release.Refinement.Store.selectFresh
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.builderLet Benitoite.Release.Refinement.BuilderKind.string
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit))))
                [] Benitoite.Release.Refinement.Store.empty) =
            Option.some (event, dest) ∧
          Benitoite.Release.Refinement.Step Benitoite.Release.Refinement.NormalReplyExamples.modelProgram✝
            Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝ σ
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure
                (Benitoite.Release.Refinement.Comp.builderLet Benitoite.Release.Refinement.BuilderKind.string
                  (Benitoite.Release.Refinement.Comp.ret
                    (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit))))
              [] Benitoite.Release.Refinement.Store.empty)
            event dest) ∧
      ∃ event dest,
        Benitoite.Release.Refinement.step Benitoite.Release.Refinement.NormalReplyExamples.modelProgram✝
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝ σ
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝.selectOracle
              (fun x x_1 x_2 => (Benitoite.Release.Refinement.Outcome.err "Unused", []))
              Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝.selectRelease
              Benitoite.Release.Refinement.Store.selectFresh
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)).lazyC)
                [] Benitoite.Release.Refinement.Store.empty) =
            Option.some (event, dest) ∧
          Benitoite.Release.Refinement.Step Benitoite.Release.Refinement.NormalReplyExamples.modelProgram✝
            Benitoite.Release.Refinement.NormalReplyExamples.modelBuiltins✝ σ
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure
                (Benitoite.Release.Refinement.Comp.ret
                    (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)).lazyC)
              [] Benitoite.Release.Refinement.Store.empty)
            event dest
```

## Benitoite.Release.Refinement.Observation.targetValue

所在: `formal/Benitoite/Release/Refinement/Observation.lean`、行: 21。

```lean
Option Benitoite.Release.Refinement.PathEnv → Benitoite.Scope.Domain.Target → Benitoite.Release.Refinement.Observation
```

## Benitoite.Release.Refinement.ObservationEnvModel

所在: `formal/Benitoite/Release/Refinement/Observation.lean`、行: 23。

```lean
Type
```

## Benitoite.Release.Refinement.OpDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 268。

```lean
Type
```

## Benitoite.Release.Refinement.OpDecl.dictParams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 277。

```lean
Benitoite.Release.Refinement.OpDecl → List (Benitoite.Release.ClassName × Nat)
```

## Benitoite.Release.Refinement.OpDecl.eff

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 271。

```lean
Benitoite.Release.Refinement.OpDecl → Benitoite.Release.EffName
```

## Benitoite.Release.Refinement.OpDecl.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 270。

```lean
Benitoite.Release.EffName →
  List Benitoite.Release.TParam →
    List String →
      List Benitoite.Release.Refinement.Ty →
        Benitoite.Release.Refinement.Ty → List (Benitoite.Release.ClassName × Nat) → Benitoite.Release.Refinement.OpDecl
```

## Benitoite.Release.Refinement.OpDecl.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 270。

```lean
{P : Sort u} →
  {eff : Benitoite.Release.EffName} →
    {tparams : List Benitoite.Release.TParam} →
      {names : List String} →
        {params : List Benitoite.Release.Refinement.Ty} →
          {ret : Benitoite.Release.Refinement.Ty} →
            {dictParams : List (Benitoite.Release.ClassName × Nat)} →
              {eff' : Benitoite.Release.EffName} →
                {tparams' : List Benitoite.Release.TParam} →
                  {names' : List String} →
                    {params' : List Benitoite.Release.Refinement.Ty} →
                      {ret' : Benitoite.Release.Refinement.Ty} →
                        {dictParams' : List (Benitoite.Release.ClassName × Nat)} →
                          { eff := eff, tparams := tparams, names := names, params := params, ret := ret,
                                dictParams := dictParams } =
                              { eff := eff', tparams := tparams', names := names', params := params', ret := ret',
                                dictParams := dictParams' } →
                            (eff = eff' →
                                tparams = tparams' →
                                  names = names' → params = params' → ret = ret' → dictParams = dictParams' → P) →
                              P
```

## Benitoite.Release.Refinement.OpDecl.names

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 273。

```lean
Benitoite.Release.Refinement.OpDecl → List String
```

## Benitoite.Release.Refinement.OpDecl.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 268。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.OpDecl} → t = t' → Benitoite.Release.Refinement.OpDecl.noConfusionType P t t'
```

## Benitoite.Release.Refinement.OpDecl.params

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 274。

```lean
Benitoite.Release.Refinement.OpDecl → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.OpDecl.ret

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 275。

```lean
Benitoite.Release.Refinement.OpDecl → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.OpDecl.tel

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 462。

```lean
Benitoite.Release.Refinement.OpDecl → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.OpDecl.tparams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 272。

```lean
Benitoite.Release.Refinement.OpDecl → List Benitoite.Release.TParam
```

## Benitoite.Release.Refinement.Oracle

所在: `formal/Benitoite/Release/Refinement/Step.lean`、行: 6。

```lean
Type
```

## Benitoite.Release.Refinement.Outcome

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 383。

```lean
Type
```

## Benitoite.Release.Refinement.Outcome.Carrier

所在: `formal/Benitoite/Release/Refinement/ExternalCheck.lean`、行: 328。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy → Benitoite.Release.Refinement.Outcome → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.Outcome.Typed

所在: `formal/Benitoite/Release/Refinement/ExternalCheck.lean`、行: 16。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy → Benitoite.Release.Refinement.Outcome → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.Outcome.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 383。

```lean
{motive : Benitoite.Release.Refinement.Outcome → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Outcome) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Outcome.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Outcome.err

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 385。

```lean
Benitoite.Release.ErrKind → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.Outcome.err.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 385。

```lean
{motive : Benitoite.Release.Refinement.Outcome → Sort u} →
  (t : Benitoite.Release.Refinement.Outcome) →
    t.ctorIdx = 1 → ((r : Benitoite.Release.ErrKind) → motive (Benitoite.Release.Refinement.Outcome.err r)) → motive t
```

## Benitoite.Release.Refinement.Outcome.err.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 385。

```lean
{P : Sort u} →
  {r r' : Benitoite.Release.ErrKind} →
    Benitoite.Release.Refinement.Outcome.err r = Benitoite.Release.Refinement.Outcome.err r' → (r = r' → P) → P
```

## Benitoite.Release.Refinement.Outcome.exit

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 386。

```lean
Int → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.Outcome.exit.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 386。

```lean
{motive : Benitoite.Release.Refinement.Outcome → Sort u} →
  (t : Benitoite.Release.Refinement.Outcome) →
    t.ctorIdx = 2 → ((n : Int) → motive (Benitoite.Release.Refinement.Outcome.exit n)) → motive t
```

## Benitoite.Release.Refinement.Outcome.exit.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 386。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Outcome.exit n = Benitoite.Release.Refinement.Outcome.exit n' → (n = n' → P) → P
```

## Benitoite.Release.Refinement.Outcome.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 383。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Outcome} → t = t' → Benitoite.Release.Refinement.Outcome.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Outcome.val

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 384。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.Outcome.val.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 384。

```lean
{motive : Benitoite.Release.Refinement.Outcome → Sort u} →
  (t : Benitoite.Release.Refinement.Outcome) →
    t.ctorIdx = 0 →
      ((v : Benitoite.Release.Refinement.Val) → motive (Benitoite.Release.Refinement.Outcome.val v)) → motive t
```

## Benitoite.Release.Refinement.Outcome.val.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 384。

```lean
{P : Sort u} →
  {v v' : Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Outcome.val v = Benitoite.Release.Refinement.Outcome.val v' → (v = v' → P) → P
```

## Benitoite.Release.Refinement.PatTys.variables

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 24。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (as : List Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.PatTys P (List.replicate as.length Benitoite.Release.Pat.var) as as
```

## Benitoite.Release.Refinement.PathBase

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 10。

```lean
Type
```

## Benitoite.Release.Refinement.PathBase.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 10。

```lean
{motive : Benitoite.Release.Refinement.PathBase → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.PathBase) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.PathBase.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.PathBase.cwd

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.PathBase.cwd.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.PathBase → Sort u} →
  (t : Benitoite.Release.Refinement.PathBase) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.PathBase.cwd → motive t
```

## Benitoite.Release.Refinement.PathBase.home

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.PathBase.home.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.PathBase → Sort u} →
  (t : Benitoite.Release.Refinement.PathBase) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.PathBase.home → motive t
```

## Benitoite.Release.Refinement.PathBase.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 10。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.PathBase} → x = y → Benitoite.Release.Refinement.PathBase.noConfusionType P x y
```

## Benitoite.Release.Refinement.PathBase.root

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.PathBase.root.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.PathBase → Sort u} →
  (t : Benitoite.Release.Refinement.PathBase) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.PathBase.root → motive t
```

## Benitoite.Release.Refinement.PathBase.tmp

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.PathBase.tmp.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.PathBase → Sort u} →
  (t : Benitoite.Release.Refinement.PathBase) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.PathBase.tmp → motive t
```

## Benitoite.Release.Refinement.PathBase.work

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.PathBase.work.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.PathBase → Sort u} →
  (t : Benitoite.Release.Refinement.PathBase) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.PathBase.work → motive t
```

## Benitoite.Release.Refinement.PathEnv

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 14。

```lean
Type
```

## Benitoite.Release.Refinement.PathEnv.Binds

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 38。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.PathBase → Benitoite.Scope.Domain.Word → Prop
```

## Benitoite.Release.Refinement.PathEnv.Ready

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 138。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.PathEnv.Ready.resolve_required

所在: `formal/Benitoite/Release/Refinement/PreparationTargets.lean`、行: 7。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s : Benitoite.Release.Refinement.State}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.PathEnv.Ready P B σ s →
    Benitoite.Release.Refinement.PreparationNode.Reachable P B (Benitoite.Release.Refinement.PreparationNode.state s)
        (Benitoite.Release.Refinement.PreparationNode.range r) →
      ∃ rs, Benitoite.Release.Refinement.RangeExpr.resolve σ r = Option.some rs
```

## Benitoite.Release.Refinement.PathEnv.Required

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 134。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.State → Benitoite.Release.Refinement.PathRequirement → Prop
```

## Benitoite.Release.Refinement.PathEnv.Valid

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 28。

```lean
Benitoite.Release.Refinement.PathEnv → Prop
```

## Benitoite.Release.Refinement.PathEnv.cwd

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 16。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.PathEnv.home

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 17。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.PathEnv.lookup

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 34。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.PathBase → Option Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.PathEnv.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 14。

```lean
Benitoite.Scope.Domain.Word →
  Benitoite.Scope.Domain.Word →
    Benitoite.Scope.Domain.Word →
      Option Benitoite.Scope.Domain.Word →
        Option Benitoite.Scope.Domain.Word →
          Option (List Benitoite.Scope.Domain.PathPattern) → Benitoite.Release.Refinement.PathEnv
```

## Benitoite.Release.Refinement.PathEnv.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 14。

```lean
{P : Sort u} →
  {root cwd home : Benitoite.Scope.Domain.Word} →
    {work tmp : Option Benitoite.Scope.Domain.Word} →
      {secrets : Option (List Benitoite.Scope.Domain.PathPattern)} →
        {root' cwd' home' : Benitoite.Scope.Domain.Word} →
          {work' tmp' : Option Benitoite.Scope.Domain.Word} →
            {secrets' : Option (List Benitoite.Scope.Domain.PathPattern)} →
              { root := root, cwd := cwd, home := home, work := work, tmp := tmp, secrets := secrets } =
                  { root := root', cwd := cwd', home := home', work := work', tmp := tmp', secrets := secrets' } →
                (root = root' → cwd = cwd' → home = home' → work = work' → tmp = tmp' → secrets = secrets' → P) → P
```

## Benitoite.Release.Refinement.PathEnv.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 14。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.PathEnv} → t = t' → Benitoite.Release.Refinement.PathEnv.noConfusionType P t t'
```

## Benitoite.Release.Refinement.PathEnv.root

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 15。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.PathEnv.secrets

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 20。

```lean
Benitoite.Release.Refinement.PathEnv → Option (List Benitoite.Scope.Domain.PathPattern)
```

## Benitoite.Release.Refinement.PathEnv.tmp

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 19。

```lean
Benitoite.Release.Refinement.PathEnv → Option Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.PathEnv.work

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 18。

```lean
Benitoite.Release.Refinement.PathEnv → Option Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.PathPattern.Covers.mem_atBase

所在: `formal/Benitoite/Release/Refinement/ScopeCoverage.lean`、行: 18。

```lean
∀ {p q : Benitoite.Scope.Domain.PathPattern},
  p.Covers q →
    ∀ (w : Benitoite.Scope.Domain.Word) {t : Benitoite.Scope.Domain.Target},
      (Benitoite.Scope.Domain.Range.path (Benitoite.Release.Refinement.PathPattern.atBase w q)).Mem t →
        (Benitoite.Scope.Domain.Range.path (Benitoite.Release.Refinement.PathPattern.atBase w p)).Mem t
```

## Benitoite.Release.Refinement.PathPattern.atBase

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 40。

```lean
Benitoite.Scope.Domain.Word → Benitoite.Scope.Domain.PathPattern → Benitoite.Scope.Domain.PathPattern
```

## Benitoite.Release.Refinement.PathPattern.covers_atBase

所在: `formal/Benitoite/Release/Refinement/ScopeCoverage.lean`、行: 9。

```lean
∀ (w : Benitoite.Scope.Domain.Word) {p q : Benitoite.Scope.Domain.PathPattern},
  p.Covers q →
    (Benitoite.Release.Refinement.PathPattern.atBase w p).Covers (Benitoite.Release.Refinement.PathPattern.atBase w q)
```

## Benitoite.Release.Refinement.PathRequirement.base

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 11。

```lean
Benitoite.Release.Refinement.PathBase → Benitoite.Release.Refinement.PathRequirement
```

## Benitoite.Release.Refinement.Pred

所在: `formal/Benitoite/Release/Refinement/TermSyntax.lean`、行: 35。

```lean
Type
```

## Benitoite.Release.Refinement.Pred.interpret

所在: `formal/Benitoite/Release/Refinement/ClosedEvaluation.lean`、行: 78。

```lean
Benitoite.Release.Refinement.ObservationEnvModel → Benitoite.Release.Refinement.Pred → Bool
```

## Benitoite.Release.Refinement.Pred.member

所在: `formal/Benitoite/Release/Refinement/TermSyntax.lean`、行: 44。

```lean
Benitoite.Scope.Domain.Kind →
  Benitoite.Release.Refinement.Term → Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.Pred.member_bind

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 87。

```lean
∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (kind : Benitoite.Scope.Domain.Kind)
  (t : Benitoite.Release.Refinement.Term) (r : Benitoite.Release.Refinement.RangeExpr),
  Benitoite.Release.Refinement.predBind ν (Benitoite.Release.Refinement.Pred.member kind t r) =
    Benitoite.Release.Refinement.Pred.member kind (Benitoite.Release.Refinement.termBind ν t) r
```

## Benitoite.Release.Refinement.Pred.member_inst_mono

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 69。

```lean
∀ {η : Benitoite.Release.Refinement.ObservationEnvModel} {k : Benitoite.Scope.Domain.Kind}
  {a : Benitoite.Release.Refinement.Term} {outer inner : Benitoite.Release.Refinement.RangeIx},
  outer.Covers inner →
    ∀ (rs : List Benitoite.Release.Refinement.RangeExpr) {r : Benitoite.Release.Refinement.RangeExpr},
      Benitoite.Release.Refinement.RangeIx.inst rs inner = Benitoite.Release.Refinement.RangeIx.fixed r →
        Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a r) = Bool.true →
          ∃ s,
            Benitoite.Release.Refinement.RangeIx.inst rs outer = Benitoite.Release.Refinement.RangeIx.fixed s ∧
              Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a s) = Bool.true
```

## Benitoite.Release.Refinement.Pred.member_mono

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 52。

```lean
∀ {η : Benitoite.Release.Refinement.ObservationEnvModel} {k : Benitoite.Scope.Domain.Kind}
  {a : Benitoite.Release.Refinement.Term} {r s : Benitoite.Release.Refinement.RangeExpr},
  s.Covers r →
    Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a r) = Bool.true →
      Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a s) = Bool.true
```

## Benitoite.Release.Refinement.Pred.open_lift

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 205。

```lean
∀ (p : Benitoite.Release.Refinement.Pred) (t : Benitoite.Release.Refinement.Term), p.lift.open t = p
```

## Benitoite.Release.Refinement.PreparationNode.Reachable

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 130。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PreparationNode → Benitoite.Release.Refinement.PreparationNode → Prop
```

## Benitoite.Release.Refinement.PreparationNode.range

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 18。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.PreparationNode
```

## Benitoite.Release.Refinement.PreparationNode.state

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 16。

```lean
Benitoite.Release.Refinement.State → Benitoite.Release.Refinement.PreparationNode
```

## Benitoite.Release.Refinement.PreparedLeaf.check

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 217。

```lean
Benitoite.Release.Refinement.PreparedLeaf → Bool
```

## Benitoite.Release.Refinement.PreparedLeaf.checkRaw

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 171。

```lean
List Benitoite.Release.Refinement.Pred → Benitoite.Release.Refinement.PreparedLeaf → Bool
```

## Benitoite.Release.Refinement.PreparedLeaf.raw_of_check

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 38。

```lean
∀ {l : Benitoite.Release.Refinement.PreparedLeaf},
  l.check = Bool.true →
    ∀ (Φ : List Benitoite.Release.Refinement.Pred), Benitoite.Release.Refinement.PreparedLeaf.checkRaw Φ l = Bool.true
```

## Benitoite.Release.Refinement.PreparedLeaf.raw_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 189。

```lean
∀ {Φ : List Benitoite.Release.Refinement.Pred} {l : Benitoite.Release.Refinement.PreparedLeaf},
  Benitoite.Release.Refinement.PreparedLeaf.checkRaw Φ l = Bool.true →
    ∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
      (∀ (p : Benitoite.Release.Refinement.Pred),
          p ∈ Φ →
            Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.predBind ν p) = Bool.true) →
        Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.predBind ν l.predicate) = Bool.true
```

## Benitoite.Release.Refinement.PrimKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 388。

```lean
Type
```

## Benitoite.Release.Refinement.PrimKind.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 388。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.PrimKind) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.PrimKind.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.PrimKind.exit

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.exit.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.PrimKind.exit → motive t
```

## Benitoite.Release.Refinement.PrimKind.force

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.force.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 7 → motive Benitoite.Release.Refinement.PrimKind.force → motive t
```

## Benitoite.Release.Refinement.PrimKind.io

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.io.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.PrimKind.io → motive t
```

## Benitoite.Release.Refinement.PrimKind.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 388。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.PrimKind} → x = y → Benitoite.Release.Refinement.PrimKind.noConfusionType P x y
```

## Benitoite.Release.Refinement.PrimKind.pathBases

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.pathBases.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 8 → motive Benitoite.Release.Refinement.PrimKind.pathBases → motive t
```

## Benitoite.Release.Refinement.PrimKind.pure

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.pure.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.PrimKind.pure → motive t
```

## Benitoite.Release.Refinement.PrimKind.refGet

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.refGet.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.PrimKind.refGet → motive t
```

## Benitoite.Release.Refinement.PrimKind.refNew

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.refNew.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.PrimKind.refNew → motive t
```

## Benitoite.Release.Refinement.PrimKind.refSet

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.refSet.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 5 → motive Benitoite.Release.Refinement.PrimKind.refSet → motive t
```

## Benitoite.Release.Refinement.PrimKind.refUpdate

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimKind.refUpdate.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 389。

```lean
{motive : Benitoite.Release.Refinement.PrimKind → Sort u} →
  (t : Benitoite.Release.Refinement.PrimKind) →
    t.ctorIdx = 6 → motive Benitoite.Release.Refinement.PrimKind.refUpdate → motive t
```

## Benitoite.Release.Refinement.PrimSig

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 398。

```lean
Type
```

## Benitoite.Release.Refinement.PrimSig.Scoped

所在: `formal/Benitoite/Release/Refinement/PrimitiveScoped.lean`、行: 22。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.PrimSig → Prop
```

## Benitoite.Release.Refinement.PrimSig.Scoped.namesWF

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 55。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.PrimSig.Scoped P sg → Benitoite.Release.Refinement.NamesWF sg.names sg.params
```

## Benitoite.Release.Refinement.PrimSig.admits

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 406。

```lean
Benitoite.Release.Refinement.PrimSig → List Benitoite.Release.TParam → List Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.PrimSig.eff

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 404。

```lean
Benitoite.Release.Refinement.PrimSig → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.PrimSig.kind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 407。

```lean
Benitoite.Release.Refinement.PrimSig → Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.PrimSig.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 398。

```lean
List Benitoite.Release.Refinement.TParamDecl →
  Nat →
    List String →
      List Benitoite.Release.Refinement.Ty →
        Benitoite.Release.Refinement.Ty →
          Benitoite.Release.Refinement.Eff →
            (List Benitoite.Release.TParam → List Benitoite.Release.Refinement.Ty → Prop) →
              Benitoite.Release.Refinement.PrimKind →
                Option Benitoite.Release.EffName →
                  List Benitoite.Scope.Domain.Kind →
                    Benitoite.Scope.Signature.IOShape → Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.PrimSig.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 398。

```lean
{P : Sort u} →
  {tparams : List Benitoite.Release.Refinement.TParamDecl} →
    {neffs : Nat} →
      {names : List String} →
        {params : List Benitoite.Release.Refinement.Ty} →
          {ret : Benitoite.Release.Refinement.Ty} →
            {eff : Benitoite.Release.Refinement.Eff} →
              {admits : List Benitoite.Release.TParam → List Benitoite.Release.Refinement.Ty → Prop} →
                {kind : Benitoite.Release.Refinement.PrimKind} →
                  {opEff : Option Benitoite.Release.EffName} →
                    {rkinds : List Benitoite.Scope.Domain.Kind} →
                      {shape : Benitoite.Scope.Signature.IOShape} →
                        {tparams' : List Benitoite.Release.Refinement.TParamDecl} →
                          {neffs' : Nat} →
                            {names' : List String} →
                              {params' : List Benitoite.Release.Refinement.Ty} →
                                {ret' : Benitoite.Release.Refinement.Ty} →
                                  {eff' : Benitoite.Release.Refinement.Eff} →
                                    {admits' :
                                        List Benitoite.Release.TParam → List Benitoite.Release.Refinement.Ty → Prop} →
                                      {kind' : Benitoite.Release.Refinement.PrimKind} →
                                        {opEff' : Option Benitoite.Release.EffName} →
                                          {rkinds' : List Benitoite.Scope.Domain.Kind} →
                                            {shape' : Benitoite.Scope.Signature.IOShape} →
                                              { tparams := tparams, neffs := neffs, names := names, params := params,
                                                    ret := ret, eff := eff, admits := admits, kind := kind,
                                                    opEff := opEff, rkinds := rkinds, shape := shape } =
                                                  { tparams := tparams', neffs := neffs', names := names',
                                                    params := params', ret := ret', eff := eff', admits := admits',
                                                    kind := kind', opEff := opEff', rkinds := rkinds',
                                                    shape := shape' } →
                                                (tparams = tparams' →
                                                    neffs = neffs' →
                                                      names = names' →
                                                        params = params' →
                                                          ret = ret' →
                                                            eff = eff' →
                                                              admits = admits' →
                                                                kind = kind' →
                                                                  opEff = opEff' →
                                                                    rkinds = rkinds' → shape = shape' → P) →
                                                  P
```

## Benitoite.Release.Refinement.PrimSig.names

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 401。

```lean
Benitoite.Release.Refinement.PrimSig → List String
```

## Benitoite.Release.Refinement.PrimSig.neffs

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 400。

```lean
Benitoite.Release.Refinement.PrimSig → Nat
```

## Benitoite.Release.Refinement.PrimSig.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 398。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.PrimSig} → t = t' → Benitoite.Release.Refinement.PrimSig.noConfusionType P t t'
```

## Benitoite.Release.Refinement.PrimSig.opEff

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 409。

```lean
Benitoite.Release.Refinement.PrimSig → Option Benitoite.Release.EffName
```

## Benitoite.Release.Refinement.PrimSig.params

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 402。

```lean
Benitoite.Release.Refinement.PrimSig → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.PrimSig.ret

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 403。

```lean
Benitoite.Release.Refinement.PrimSig → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.PrimSig.rkinds

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 413。

```lean
Benitoite.Release.Refinement.PrimSig → List Benitoite.Scope.Domain.Kind
```

## Benitoite.Release.Refinement.PrimSig.shape

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 418。

```lean
Benitoite.Release.Refinement.PrimSig → Benitoite.Scope.Signature.IOShape
```

## Benitoite.Release.Refinement.PrimSig.tel

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 461。

```lean
Benitoite.Release.Refinement.PrimSig → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.PrimSig.tparams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 399。

```lean
Benitoite.Release.Refinement.PrimSig → List Benitoite.Release.Refinement.TParamDecl
```

## Benitoite.Release.Refinement.PrimitiveAdmissible

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 90。

```lean
Benitoite.Release.Refinement.TypeCtx →
  Nat →
    Benitoite.Release.Refinement.PrimSig →
      Benitoite.Release.NoFailCtx → List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.Program

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 343。

```lean
Type
```

## Benitoite.Release.Refinement.Program.StandardErrorComplete

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 6。

```lean
Benitoite.Release.Refinement.Program → List (Benitoite.Release.ConName × Benitoite.Release.Refinement.ConDecl) → Prop
```

## Benitoite.Release.Refinement.Program.classes

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 350。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.ClassDecl
```

## Benitoite.Release.Refinement.Program.cons

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 346。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.ConName → Option Benitoite.Release.Refinement.ConDecl
```

## Benitoite.Release.Refinement.Program.dataInfo

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 353。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.DataName → Option Benitoite.Release.Refinement.DataVarianceDecl
```

## Benitoite.Release.Refinement.Program.defs

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 345。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.FunName → Option Benitoite.Release.Refinement.Def
```

## Benitoite.Release.Refinement.Program.effects

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 349。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.EffName → Option (List Benitoite.Release.OpName)
```

## Benitoite.Release.Refinement.Program.externalFunction

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 377。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ExternalFunctionId → Option Benitoite.Release.Refinement.ExternalSignature
```

## Benitoite.Release.Refinement.Program.externalType

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 372。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ExternalId → Option Benitoite.Release.Refinement.ExternalTypeDecl
```

## Benitoite.Release.Refinement.Program.externals

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 352。

```lean
Benitoite.Release.Refinement.Program →
  List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)
```

## Benitoite.Release.Refinement.Program.impls

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 351。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.ImplName → Option Benitoite.Release.Refinement.ImplDecl
```

## Benitoite.Release.Refinement.Program.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 344。

```lean
(Benitoite.Release.FunName → Option Benitoite.Release.Refinement.Def) →
  (Benitoite.Release.ConName → Option Benitoite.Release.Refinement.ConDecl) →
    (Benitoite.Release.OpName → Option Benitoite.Release.Refinement.OpDecl) →
      (Benitoite.Release.EffName → Option (List Benitoite.Release.OpName)) →
        (Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.ClassDecl) →
          (Benitoite.Release.ImplName → Option Benitoite.Release.Refinement.ImplDecl) →
            List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl) →
              (Benitoite.Release.DataName → Option Benitoite.Release.Refinement.DataVarianceDecl) →
                Benitoite.Release.Refinement.Program
```

