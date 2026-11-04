# 群 H の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.Model.entries :
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

```lean
Benitoite.Release.Refinement.Model.builtins :
Benitoite.Release.Refinement.Builtins
```

```lean
Benitoite.Release.Refinement.Model.sig_cases :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    b = "Reference.get" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refGet ∨
      b = "Reference.set" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refSet ∨
        b = Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∧
          s = Benitoite.Release.Refinement.ScopeSignatures.pathBases
```

```lean
Benitoite.Release.Refinement.Model.substitutionAssumptions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P Benitoite.Release.Refinement.Model.builtins
```

```lean
Benitoite.Release.Refinement.Model.sig_scoped :
∀ (P : Benitoite.Release.Refinement.Program) {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s → Benitoite.Release.Refinement.PrimSig.Scoped P s
```

```lean
Benitoite.Release.Refinement.Model.sat_unconstrained :
∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.Model.builtins.sat [] t.norm { }
```

```lean
Benitoite.Release.Refinement.Model.admits_sat :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : Benitoite.Release.Refinement.TypeCtx}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.Model.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

```lean
Benitoite.Release.Refinement.Model.pathBases_shape :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      s.PathBasesShape Benitoite.Release.Refinement.Model.builtins b
```

```lean
Benitoite.Release.Refinement.Model.io_op :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.Model.builtins.ShapeOk b s
```

```lean
Benitoite.Release.Refinement.Model.opEff_io :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.opEff = some l →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

```lean
Benitoite.Release.Refinement.Model.effect_ops :
∀ {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  Benitoite.Release.Refinement.Model.builtins.effects l = some bs →
    b ∈ bs →
      ∃ s,
        Benitoite.Release.Refinement.Model.builtins.sig b = some s ∧
          (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            s.opEff = some l
```

```lean
Benitoite.Release.Refinement.Model.state_effect :
Benitoite.Release.Refinement.Model.builtins.effects Benitoite.Release.stateEff = some []
```

```lean
Benitoite.Release.Refinement.Model.ref_get :
∃ s,
  Benitoite.Release.Refinement.Model.builtins.sig Benitoite.Release.Refinement.Model.builtins.refGet = some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

```lean
Benitoite.Release.Refinement.Model.ref_set :
∃ s,
  Benitoite.Release.Refinement.Model.builtins.sig Benitoite.Release.Refinement.Model.builtins.refSet = some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

```lean
Benitoite.Release.Refinement.Model.store_shape :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
```

```lean
Benitoite.Release.Refinement.Model.store_admits :
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Model.builtins.sig b = some s → ts.length = s.tparams.length → s.admits C ts
```

```lean
Benitoite.Release.Refinement.Model.delta_typed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
      Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        ∃ out,
          Benitoite.Release.Refinement.Model.builtins.delta b ts es rs ws = some out ∧
            (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
              Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.Model.builtins Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.Model.io_typed :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
          Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.Model.builtins Ψ out a ∧
            Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.Model.io_kind :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
      Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
        (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
            ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
          sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
            ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v
```

```lean
Benitoite.Release.Refinement.Model.io_exists :
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        ∃ out obs, Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs
```

```lean
Benitoite.Release.Refinement.Model.responseAssumptions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions P Benitoite.Release.Refinement.Model.builtins
```

```lean
Benitoite.Release.Refinement.Model.targetAgreement :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P Benitoite.Release.Refinement.Model.builtins
```

```lean
Benitoite.Release.Refinement.Model.scopeConditions :
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins
```

```lean
Benitoite.Release.Refinement.AtPrepared.of_path_bases :
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases pattern input : Benitoite.Release.Refinement.Val} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {σ : Benitoite.Release.Refinement.PathEnv},
  B.valKind name = some kind →
    B.valContent name = none →
      Benitoite.Release.Refinement.parseAtPattern kind (Benitoite.Release.Refinement.closeVal cap pattern) = some pat →
        Benitoite.Release.Refinement.parseAtInput kind (Benitoite.Release.Refinement.closeVal cap input) = some target →
          Benitoite.Release.Refinement.closeVal cap bases = Benitoite.Release.Refinement.Val.pathBases σ →
            σ.Valid →
              bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical →
                Benitoite.Release.Refinement.AtPrepared B cap kind name (some bases) pattern input
                  (Benitoite.Release.Refinement.RangeIx.fixed bound) (some σ) pat target bound
```

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.call_arguments :
∀ (P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ
    Benitoite.Release.Refinement.ScopeSignatures.pathBasesName Benitoite.Release.Refinement.ScopeSignatures.pathBases []
    [] [] [] Benitoite.Release.Refinement.Ty.pathBases
    (Benitoite.Release.Refinement.Eff.single Benitoite.Release.Refinement.processEnvironmentEff)
```

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.call_typed :
∀ (P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeCQ P Benitoite.Release.Refinement.Model.builtins Ψ Benitoite.Release.Qempty [] []
    [] none
    (Benitoite.Release.Refinement.Comp.app
      (Benitoite.Release.Refinement.Val.prim Benitoite.Release.Refinement.ScopeSignatures.pathBasesName [] [] []) [])
    Benitoite.Release.Refinement.Ty.pathBases
    (Benitoite.Release.Refinement.Eff.single Benitoite.Release.Refinement.processEnvironmentEff)
```

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.issue :
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
            (Benitoite.Release.Refinement.State.run q k μ) none
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
              (some
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
                    some bs ∧
                  Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∈ bs
```

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.issue_to_at :
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (kind : Benitoite.Scope.Domain.Kind) (name : Benitoite.Release.OpaqueName)
  (shape : Benitoite.Release.Refinement.ResultShape) (pattern input : Benitoite.Release.Refinement.Val)
  (index : Benitoite.Release.Refinement.RangeIx),
  σ.Valid →
    have body :=
      Benitoite.Release.Refinement.Comp.checkAt kind name shape (some (Benitoite.Release.Refinement.Val.var 0)) pattern
        input index;
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

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.issued_current :
∀ {σ : Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snap : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared Benitoite.Release.Refinement.Model.builtins
      (Benitoite.Release.Refinement.Capture.empty.extendMany [Benitoite.Release.Refinement.Val.pathBases σ]) kind name
      (some (Benitoite.Release.Refinement.Val.var 0)) pattern input index snap pat target bound →
    ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = some ρ → ρ = σ
```

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.required_base :
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (kind : Benitoite.Scope.Domain.Kind) (name : Benitoite.Release.OpaqueName)
  (shape : Benitoite.Release.Refinement.ResultShape) (pattern input : Benitoite.Release.Refinement.Val)
  (b : Benitoite.Release.Refinement.PathBase) (p : Benitoite.Scope.Domain.PathPattern),
  have s :=
    Benitoite.Release.Refinement.State.run
      ((Benitoite.Release.Refinement.Closure.pure
            (Benitoite.Release.Refinement.Comp.checkAt kind name shape (some (Benitoite.Release.Refinement.Val.var 0))
              pattern input
              (Benitoite.Release.Refinement.RangeIx.fixed (Benitoite.Release.Refinement.RangeExpr.based b p)))).apply
        [Benitoite.Release.Refinement.Val.pathBases σ])
      [] Benitoite.Release.Refinement.Store.empty;
  Benitoite.Release.Refinement.PathEnv.Required P Benitoite.Release.Refinement.Model.builtins s
      (Benitoite.Release.Refinement.PathRequirement.base b) ∧
    Benitoite.Release.Refinement.PreparationNode.Reachable P Benitoite.Release.Refinement.Model.builtins
      (Benitoite.Release.Refinement.PreparationNode.state s)
      (Benitoite.Release.Refinement.PreparationNode.range (Benitoite.Release.Refinement.RangeExpr.based b p))
```

```lean
Benitoite.Release.Refinement.ModelTargetsExamples.issued_at :
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (kind : Benitoite.Scope.Domain.Kind) (name : Benitoite.Release.OpaqueName)
  (shape : Benitoite.Release.Refinement.ResultShape) (pattern input : Benitoite.Release.Refinement.Val)
  (index : Benitoite.Release.Refinement.RangeIx),
  ∃ next,
    Benitoite.Release.Refinement.Step P Benitoite.Release.Refinement.Model.builtins σ
      (Benitoite.Release.Refinement.State.run
        ((Benitoite.Release.Refinement.Closure.pure
              (Benitoite.Release.Refinement.Comp.checkAt kind name shape (some (Benitoite.Release.Refinement.Val.var 0))
                pattern input index)).apply
          [Benitoite.Release.Refinement.Val.pathBases σ])
        [] Benitoite.Release.Refinement.Store.empty)
      none next
```

