# 群 D の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.PathEnv.Ready.resolve_required :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s : Benitoite.Release.Refinement.State}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.PathEnv.Ready P B σ s →
    Benitoite.Release.Refinement.PreparationNode.Reachable P B (Benitoite.Release.Refinement.PreparationNode.state s)
        (Benitoite.Release.Refinement.PreparationNode.range r) →
      ∃ rs, Benitoite.Release.Refinement.RangeExpr.resolve σ r = some rs
```

```lean
Benitoite.Release.Refinement.InitialPrepared.source_state_of_source :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m : Benitoite.Release.Refinement.Comp}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.InitialPrepared P B σ
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.pure m) []
        Benitoite.Release.Refinement.Store.empty) →
    P.ExternalWF →
      Benitoite.Release.Refinement.HasTypeC P B Benitoite.Release.Refinement.StoreTy.empty [] [] [] none m a e →
        Benitoite.Release.Refinement.Ty.Annotation P [] []
            (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e)) →
          Benitoite.Release.Refinement.Comp.ClosedAt 0 0 m →
            m.Source →
              Benitoite.Release.Refinement.BuiltinOnly P B e →
                Benitoite.Release.Refinement.StateTy P B σ
                    (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.pure m) []
                      Benitoite.Release.Refinement.Store.empty) ∧
                  Benitoite.Release.Refinement.PathEnv.Ready P B σ
                      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.pure m) []
                        Benitoite.Release.Refinement.Store.empty) ∧
                    P.ExternalWF
```

```lean
Benitoite.Release.Refinement.AtPrepared.current :
∀ {B : Benitoite.Release.Refinement.Builtins} {σ : Benitoite.Release.Refinement.PathEnv}
  {cap : Benitoite.Release.Refinement.Capture} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {bs : Option Benitoite.Release.Refinement.Val}
  {p v : Benitoite.Release.Refinement.Val} {ix : Benitoite.Release.Refinement.RangeIx}
  {snap : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.Capture.Adequate σ cap →
    (∀ (b : Benitoite.Release.Refinement.Val), bs = some b → Benitoite.Release.Refinement.Val.Adequate σ b) →
      Benitoite.Release.Refinement.AtPrepared B cap kind name bs p v ix snap pat t bound →
        ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = some ρ → ρ = σ
```

```lean
Benitoite.Release.Refinement.AtPrepared.formed :
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    (pat.FitsKind kind ∧ pat.WF ∧ pat.Canonical) ∧
      (bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical) ∧
        (snapshot = none →
          ∃ p t b,
            pat = Benitoite.Release.Refinement.RangeExpr.absolute p ∧
              target = Benitoite.Release.Refinement.TargetInput.absolute t ∧
                bound = Benitoite.Release.Refinement.RangeExpr.absolute b)
```

```lean
Benitoite.Release.Refinement.AtPrepared.origins :
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    (B.valContent name = none ∧
          Benitoite.Release.Refinement.parseAtInput kind (Benitoite.Release.Refinement.closeVal cap input) =
            some target ∨
        ∃ T t,
          B.valContent name = some T ∧
            Benitoite.Release.Refinement.groundVal (Benitoite.Release.Refinement.closeVal cap input) = true ∧
              (Benitoite.Release.Refinement.closeVal cap input).reqTarget = some t ∧
                target = Benitoite.Release.Refinement.TargetInput.absolute t) ∧
      (bases = none ∧ snapshot = none ∨
        ∃ b σ,
          bases = some b ∧
            Benitoite.Release.Refinement.closeVal cap b = Benitoite.Release.Refinement.Val.pathBases σ ∧
              σ.Valid ∧ snapshot = some σ)
```

```lean
Benitoite.Release.Refinement.AtPrepared.resolution :
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    (∃ t, Benitoite.Release.Refinement.resolveTargetSnapshot snapshot target = some t) ∧
      (snapshot = none →
        (∃ ps, Benitoite.Release.Refinement.resolveSnapshot snapshot pat = some ps) ∧
          ∃ bs, Benitoite.Release.Refinement.resolveSnapshot snapshot bound = some bs)
```

```lean
Benitoite.Release.Refinement.StateTyE.at_current :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bs : Option Benitoite.Release.Refinement.Val}
  {p v : Benitoite.Release.Refinement.Val} {ix : Benitoite.Release.Refinement.RangeIx}
  {snap : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bs p v ix →
      Benitoite.Release.Refinement.AtPrepared B q.capture kind name bs p v ix snap pat t bound →
        ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = some ρ → ρ = σ
```

```lean
Benitoite.Release.Refinement.StateTyE.at_index :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.RangeIx.WF 0 index
```

```lean
Benitoite.Release.Refinement.StateTyE.at_prepare_failure :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepare B q.capture kind name bases pattern input index = Except.error detail →
        detail.failure ≠ Benitoite.Release.Refinement.AtFailure.staticIndex ∧
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.ret
                    (Benitoite.Release.Refinement.Val.con shape.error
                      [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                      [Benitoite.Release.Refinement.Val.atError detail])))
                k μ) ∧
            Benitoite.Release.Refinement.StateTyE P B σ Eb
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.ret
                    (Benitoite.Release.Refinement.Val.con shape.error
                      [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                      [Benitoite.Release.Refinement.Val.atError detail])))
                k μ)
```

```lean
Benitoite.Release.Refinement.StateTyE.at_step :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
              ∃ next,
                Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none next ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb next
```

```lean
Benitoite.Release.Refinement.AtTargets.adequate_atError :
∀ (detail : Benitoite.Release.Refinement.AtError) (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError detail))
```

```lean
Benitoite.Release.Refinement.ScopeLegacyContracts.relative_rejected :
∀ {v : Benitoite.Release.Refinement.Val} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path v =
        some (Benitoite.Release.Refinement.TargetInput.relativePath w) ∨
      Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path v =
        some (Benitoite.Release.Refinement.TargetInput.homePath w) →
    ∀ (p : Benitoite.Scope.Domain.PathPattern) (bound : Benitoite.Release.Refinement.RangeExpr),
      Benitoite.Release.Refinement.ScopeLegacyContracts.pathInput v = none ∧
        Benitoite.Release.Refinement.ScopeLegacyContracts.checkPath p v = none ∧
          Benitoite.Release.Refinement.ScopeLegacyContracts.checkPathIn p v bound = none
```

```lean
Benitoite.Release.Refinement.ScopeLegacyContracts.absolute_input :
∀ {v : Benitoite.Release.Refinement.Val} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path v =
      some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w)) →
    ∀ (p : Benitoite.Scope.Domain.PathPattern) (r : Benitoite.Scope.Domain.Range),
      Benitoite.Release.Refinement.ScopeLegacyContracts.checkPath p v = some (Benitoite.Checked.Scope.makePath p w) ∧
        Benitoite.Release.Refinement.ScopeLegacyContracts.checkPathIn p v
            (Benitoite.Release.Refinement.RangeExpr.absolute r) =
          some
            (Benitoite.Release.Refinement.checkAt none Benitoite.Scope.Domain.Kind.path
              (Benitoite.Release.Refinement.RangeExpr.path p)
              (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w))
              (Benitoite.Release.Refinement.RangeExpr.absolute r))
```

```lean
Benitoite.Release.Refinement.AtError.save :
Benitoite.Release.Refinement.Val →
  Benitoite.Release.Refinement.Val →
    Option Benitoite.Release.Refinement.PathEnv →
      Option Benitoite.Release.Refinement.RangeExpr →
        Option Benitoite.Release.Refinement.TargetInput →
          Benitoite.Release.Refinement.AtFailure → Benitoite.Release.Refinement.AtError
```

```lean
Benitoite.Release.Refinement.AtError.fromCheck :
Benitoite.Release.Refinement.Val →
  Benitoite.Release.Refinement.Val →
    Option Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.RangeExpr →
        Benitoite.Release.Refinement.TargetInput →
          Benitoite.Release.Refinement.AtCheckError → Benitoite.Release.Refinement.AtError
```

```lean
Benitoite.Release.Refinement.AtError.save_exact :
∀ (p t : Benitoite.Release.Refinement.Val) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (pp : Option Benitoite.Release.Refinement.RangeExpr) (pt : Option Benitoite.Release.Refinement.TargetInput)
  (f : Benitoite.Release.Refinement.AtFailure),
  have d := Benitoite.Release.Refinement.AtError.save p t snapshot pp pt f;
  d.originalPattern = p ∧
    d.originalTarget = t ∧
      d.failure = f ∧
        d.parsedPattern = pp ∧
          d.parsedTarget = pt ∧
            d.resolvedPatterns = pp.bind (Benitoite.Release.Refinement.resolveSnapshot snapshot) ∧
              d.resolvedTarget = pt.bind (Benitoite.Release.Refinement.resolveTargetSnapshot snapshot) ∧
                d.patternBase = pp.bind Benitoite.Release.Refinement.RangeExpr.base? ∧
                  d.targetBase = pt.bind Benitoite.Release.Refinement.TargetInput.base?
```

```lean
Benitoite.Release.Refinement.AtPrepare.error_saved :
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.AtPrepare B cap kind name bases pattern input index = Except.error detail →
    ∃ snapshot pp pt,
      detail =
        Benitoite.Release.Refinement.AtError.save (Benitoite.Release.Refinement.closeVal cap pattern)
          (Benitoite.Release.Refinement.closeVal cap input) snapshot pp pt detail.failure
```

```lean
Benitoite.Release.Refinement.Detail.originals_unobserved :
∀ (d : Benitoite.Release.Refinement.AtError) (p t : Benitoite.Release.Refinement.Val),
  have d' :=
    { failure := d.failure, originalPattern := p, originalTarget := t, parsedPattern := d.parsedPattern,
      parsedTarget := d.parsedTarget, resolvedPatterns := d.resolvedPatterns, resolvedTarget := d.resolvedTarget,
      patternBase := d.patternBase, targetBase := d.targetBase };
  Benitoite.Release.Refinement.Detail.textFields d' = Benitoite.Release.Refinement.Detail.textFields d ∧
    Benitoite.Release.Refinement.Detail.values d' = Benitoite.Release.Refinement.Detail.values d ∧
      (Benitoite.Release.Refinement.Val.atError d').toTerm? = (Benitoite.Release.Refinement.Val.atError d).toTerm? ∧
        ∀ (pat : Benitoite.Release.Pat),
          Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
              (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.atError d')) =
            Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
              (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.atError d))
```

```lean
Benitoite.Release.Refinement.checkAt.no_invalidPattern :
∀ {σ : Option Benitoite.Release.Refinement.PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {p : Benitoite.Release.Refinement.RangeExpr} {input : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr} {detail : Benitoite.Release.Refinement.AtCheckError},
  p.WF ∧ p.FitsKind k →
    bound.WF ∧ bound.FitsKind k →
      Benitoite.Release.Refinement.checkAt σ k p input bound = Benitoite.Release.Refinement.AtResult.error detail →
        detail.failure ≠ Benitoite.Release.Refinement.AtFailure.invalidPattern
```

```lean
Benitoite.Release.Refinement.ScopeLegacyContracts.checkPathIn :
Benitoite.Scope.Domain.PathPattern →
  Benitoite.Release.Refinement.Val →
    Benitoite.Release.Refinement.RangeExpr → Option Benitoite.Release.Refinement.AtResult
```

