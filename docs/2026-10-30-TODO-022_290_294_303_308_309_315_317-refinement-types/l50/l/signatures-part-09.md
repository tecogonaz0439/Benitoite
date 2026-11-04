# 段末の実署名（続き）

## Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 361。

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv) (ps : List Benitoite.Scope.Domain.PathPattern)
  (k : Benitoite.Scope.Domain.Kind) (t : Benitoite.Scope.Domain.Target),
  Benitoite.Release.Refinement.RangeExpr.resolve
        { root := σ.root, cwd := σ.cwd, home := σ.home, work := σ.work, tmp := σ.tmp, secrets := Option.none }
        Benitoite.Release.Refinement.RangeExpr.secrets =
      Option.none ∧
    Benitoite.Release.Refinement.RangeExpr.resolve
          { root := σ.root, cwd := σ.cwd, home := σ.home, work := σ.work, tmp := σ.tmp, secrets := Option.some [] }
          Benitoite.Release.Refinement.RangeExpr.secrets =
        Option.some [] ∧
      (Benitoite.Release.Refinement.RangeExpr.Mem
          { root := σ.root, cwd := σ.cwd, home := σ.home, work := σ.work, tmp := σ.tmp, secrets := Option.some ps } k
          Benitoite.Release.Refinement.RangeExpr.secrets t ↔
        t.kind = k ∧ ∃ p, p ∈ ps ∧ (Benitoite.Scope.Domain.Range.path p).Mem t)
```

## Benitoite.Release.Refinement.ScopedTargetExamples.selected_io

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 84。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
              ws[p]? = Option.some v →
                ∃ r t,
                  rs = [r] ∧
                    v.target? = Option.some t ∧
                      Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                        (∃ out obs, B.ioResponse b ts es ws out obs) ∧
                          ∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
                            B.ioResponse b ts es ws out obs → obs = [t]
```

## Benitoite.Release.Refinement.ScopedTargetExamples.selected_request

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 105。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {v : Benitoite.Release.Refinement.Val} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
              ws[p]? = Option.some v →
                (∀ (o : Benitoite.Release.OpaqueName),
                    sg.params[p]? =
                        Option.some
                          (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                      B.valContent o = Option.some A) →
                  ∃ r target req,
                    rs = [r] ∧
                      (v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                          ∃ s snapshot,
                            v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (Option.some req)) ∧
                        Benitoite.Release.Refinement.ModelHttp.valueRun [v] =
                            Benitoite.Release.Refinement.Outcome.val req ∧
                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                            Benitoite.Release.Refinement.groundVal req = Bool.true ∧
                              req.reqTarget = Option.some target ∧
                                Benitoite.Release.Refinement.RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.endpoint r
                                    target ∧
                                  (∃ out obs, B.ioResponse b ts es ws out obs) ∧
                                    ∀ (out : Benitoite.Release.Refinement.Outcome)
                                      (obs : List Benitoite.Scope.Domain.Target),
                                      B.ioResponse b ts es ws out obs → obs = [target]
```

## Benitoite.Release.Refinement.ScopedTargetExamples.single_io

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 11。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv} {u : Benitoite.Release.Refinement.Tel},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
          Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es →
            B.RangeAdmissible b sg rs →
              Benitoite.Release.Refinement.SignatureInstance P [] [] (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
                  (List.map Benitoite.Release.Refinement.TParamDecl.kind sg.tparams) ts es →
                Benitoite.Release.Refinement.TelClosure P [] []
                    (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts
                      es)
                    u →
                  Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws u a e →
                    (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground) →
                      (∀ (w : Benitoite.Release.Refinement.Val),
                          w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
                        ∃ a₀ e₀ r t,
                          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                              (Benitoite.Release.Refinement.Ty.normTys ts)
                              (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a₀ e₀ ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]?.bind Benitoite.Release.Refinement.Val.target? = Option.some t ∧
                                    Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                                      sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k p ∧
                                        (∃ out obs,
                                            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                              (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs) ∧
                                          ∀ (out : Benitoite.Release.Refinement.Outcome)
                                            (obs : List Benitoite.Scope.Domain.Target),
                                            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                                (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs →
                                              obs = [t] ∧
                                                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a₀ ∧
                                                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                                                    ∃ l,
                                                      sg.opEff = Option.some l ∧
                                                        ∀ (target : Benitoite.Scope.Domain.Target),
                                                          target ∈ obs →
                                                            Benitoite.Release.Refinement.Eff.Allows σ B.effKind e l
                                                              target
```

## Benitoite.Release.Refinement.ScopedTargetExamples.split_endpoint

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 323。

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv) (l : Benitoite.Release.EffName) (host : Benitoite.Scope.Domain.HostPattern)
  (Γ : Benitoite.Release.Refinement.Ctx) (Φ : List Benitoite.Release.Refinement.Pred),
  have whole := Benitoite.Scope.Domain.Range.endpoint { host := host, ports := { lo := 0, hi := 9 } };
  have left := Benitoite.Scope.Domain.Range.endpoint { host := host, ports := { lo := 0, hi := 4 } };
  have right := Benitoite.Scope.Domain.Range.endpoint { host := host, ports := { lo := 5, hi := 9 } };
  (∀ (k : Benitoite.Scope.Domain.Kind) (t : Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.absolute whole) t →
        Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.absolute left) t ∨
          Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.absolute right) t) ∧
    ¬Benitoite.Release.Refinement.Eff.Covers Γ Φ
        ((Benitoite.Release.Refinement.ScopedTargetExamples.one l
              (Benitoite.Release.Refinement.RangeExpr.absolute left)).union
          (Benitoite.Release.Refinement.ScopedTargetExamples.one l
            (Benitoite.Release.Refinement.RangeExpr.absolute right)))
        (Benitoite.Release.Refinement.ScopedTargetExamples.one l
          (Benitoite.Release.Refinement.RangeExpr.absolute whole))
```

## Benitoite.Release.Refinement.ScopedTargetExamples.widened_input

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 247。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v
        (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) →
      s.Covers r →
        B.valKind o = Option.some k →
          Benitoite.Release.Refinement.Val.Adequate σ v →
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
                (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed s)) ∧
              ∃ t,
                v.target? = Option.some t ∧
                  Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                    Benitoite.Release.Refinement.RangeExpr.Mem σ k s t
```

## Benitoite.Release.Refinement.ScopedTargetInputs.at_error

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 161。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {d : Benitoite.Release.Refinement.AtCheckError},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat target
          bound →
        Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
            Benitoite.Release.Refinement.AtResult.error d →
          have saved :=
            Benitoite.Release.Refinement.AtError.fromCheck (Benitoite.Release.Refinement.closeVal q.capture pattern)
              (Benitoite.Release.Refinement.closeVal q.capture input) snapshot pat target d;
          Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                (Benitoite.Release.Refinement.Val.atError saved) =
              Option.some (Benitoite.Release.Refinement.Detail.values saved) ∧
            (∀ (ws : List Benitoite.Release.Refinement.Val),
                Benitoite.Release.Refinement.AdequateResult ws
                  (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError saved))) ∧
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.Comp.ret
                        (Benitoite.Release.Refinement.Val.con shape.error
                          [Benitoite.Release.Refinement.Ty.scoped name kind
                              (Benitoite.Release.Refinement.RangeIx.fixed bound),
                            q.capture.closeTy shape.errorType]
                          [Benitoite.Release.Refinement.Val.atError saved])))
                    k μ) ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.Comp.ret
                        (Benitoite.Release.Refinement.Val.con shape.error
                          [Benitoite.Release.Refinement.Ty.scoped name kind
                              (Benitoite.Release.Refinement.RangeIx.fixed bound),
                            q.capture.closeTy shape.errorType]
                          [Benitoite.Release.Refinement.Val.atError saved])))
                    k μ)
```

## Benitoite.Release.Refinement.ScopedTargetInputs.at_ok

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 182。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Scope.Domain.Target},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
              Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat
                  target bound →
                Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
                    Benitoite.Release.Refinement.AtResult.ok t →
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret
                            (Benitoite.Release.Refinement.Val.con shape.ok
                              [Benitoite.Release.Refinement.Ty.scoped name kind
                                  (Benitoite.Release.Refinement.RangeIx.fixed bound),
                                q.capture.closeTy shape.errorType]
                              [Benitoite.Release.Refinement.Val.checkedAt bound snapshot t
                                  (Benitoite.Release.Refinement.AtRequest B name
                                    (Benitoite.Release.Refinement.closeVal q.capture input))])))
                        k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret
                            (Benitoite.Release.Refinement.Val.con shape.ok
                              [Benitoite.Release.Refinement.Ty.scoped name kind
                                  (Benitoite.Release.Refinement.RangeIx.fixed bound),
                                q.capture.closeTy shape.errorType]
                              [Benitoite.Release.Refinement.Val.checkedAt bound snapshot t
                                  (Benitoite.Release.Refinement.AtRequest B name
                                    (Benitoite.Release.Refinement.closeVal q.capture input))])))
                        k μ)
```

## Benitoite.Release.Refinement.ScopedTargetInputs.at_prepare

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 145。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {d : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepare B q.capture kind name bases pattern input index = Except.error d →
        d.originalPattern = Benitoite.Release.Refinement.closeVal q.capture pattern ∧
          d.originalTarget = Benitoite.Release.Refinement.closeVal q.capture input ∧
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.con shape.error
                        [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                        [Benitoite.Release.Refinement.Val.atError d])))
                  k μ) ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.con shape.error
                        [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                        [Benitoite.Release.Refinement.Val.atError d])))
                  k μ)
```

## Benitoite.Release.Refinement.ScopedTargetInputs.at_steps

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 197。

```lean
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
              Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
                ∃ next,
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                      next ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb next
```

## Benitoite.Release.Refinement.ScopedTargetInputs.destination

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 41。

```lean
Benitoite.Release.Refinement.Outcome →
  Benitoite.Release.Refinement.Cont → Benitoite.Release.Refinement.Store → Benitoite.Release.Refinement.State
```

## Benitoite.Release.Refinement.ScopedTargetInputs.handled_step

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 117。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {k1 : Benitoite.Release.Refinement.Cont}
  {cs : List Benitoite.Release.Refinement.Clause} {k2 : Benitoite.Release.Refinement.Cont}
  {c : Benitoite.Release.Refinement.Clause} {l : Nat} {hcap : Benitoite.Release.Refinement.Capture},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        P.EffectsOk B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = Option.some sg →
                sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                      sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
                  Benitoite.Release.Refinement.SplitAt (Benitoite.Release.OpRef.prim b) k k1 hcap cs k2 →
                    Benitoite.Release.Refinement.findClause cs (Benitoite.Release.OpRef.prim b) = Option.some c →
                      μ l = Option.none →
                        (∃ Ψ a e,
                            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                                (Benitoite.Release.Refinement.Ty.normTys ts)
                                (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e ∧
                              ∀ (w : Benitoite.Release.Refinement.Val),
                                w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) ∧
                          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                              Option.none
                              (Benitoite.Release.Refinement.State.run
                                (Benitoite.Release.Refinement.Closure.mk
                                  (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc l]))
                                  (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
                                (Benitoite.Release.Refinement.Frame.drop l :: k2)
                                (μ.set l
                                  (Benitoite.Release.Refinement.Cell.cont
                                    (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap cs])))) ∧
                            Benitoite.Release.Refinement.StateTyE P B σ Eb
                              (Benitoite.Release.Refinement.State.run
                                (Benitoite.Release.Refinement.Closure.mk
                                  (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc l]))
                                  (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
                                (Benitoite.Release.Refinement.Frame.drop l :: k2)
                                (μ.set l
                                  (Benitoite.Release.Refinement.Cell.cont
                                    (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap cs]))))
```

## Benitoite.Release.Refinement.ScopedTargetInputs.io_steps

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 69。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {sg : Benitoite.Release.Refinement.PrimSig},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.Builtins.TargetAgreement P B →
          σ.Valid →
            Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
              q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
                B.sig b = Option.some sg →
                  sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                      sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
                    Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                      ∃ Ψ a e,
                        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
                            (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e ∧
                          (∃ out obs,
                              B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs) ∧
                            ∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
                              B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                  (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs →
                                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                                    Benitoite.Release.Refinement.Step P B σ
                                        (Benitoite.Release.Refinement.State.run q k μ)
                                        (Option.some (Benitoite.Release.Refinement.Event.io b ws out obs))
                                        (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ) ∧
                                      Benitoite.Release.Refinement.StateTyE P B σ Eb
                                          (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ) ∧
                                        ∃ l,
                                          sg.opEff = Option.some l ∧
                                            ∀ (t : Benitoite.Scope.Domain.Target),
                                              t ∈ obs → Benitoite.Release.Refinement.Eff.Allows σ B.effKind e l t
```

## Benitoite.Release.Refinement.ScopedTargetInputs.issue

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 218。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    σ.Valid →
      Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
        q.view = Benitoite.Release.Refinement.Comp.issuePathBases b →
          B.sig b = Option.some sg →
            sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
              Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
                (∃ bs, B.effects Benitoite.Release.Refinement.processEnvironmentEff = Option.some bs ∧ b ∈ bs) ∧
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                      (Option.some (Benitoite.Release.Refinement.Event.pathBases b σ))
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                        k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                        k μ)
```

## Benitoite.Release.Refinement.ScopedTargetInputs.path_bases_apply

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 206。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b [] [] []) [] →
            B.sig b = Option.some sg →
              sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
                Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                  (∃ Ψ a e, Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg [] [] [] [] a e) ∧
                    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.mk q.capture
                            (Benitoite.Release.Refinement.Comp.issuePathBases b))
                          k μ) ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.mk q.capture
                            (Benitoite.Release.Refinement.Comp.issuePathBases b))
                          k μ)
```

## Benitoite.Release.Refinement.ScopedTargetInputs.pure_steps

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 48。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {sg : Benitoite.Release.Refinement.PrimSig},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = Option.some sg →
                sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
                  ∃ Ψ a e out,
                    Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
                        (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e ∧
                      B.delta b (Benitoite.Release.Refinement.Ty.normTys ts)
                            (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws =
                          Option.some out ∧
                        (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                          Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                            Benitoite.Release.Refinement.AdequateResult ws out ∧
                              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                                  Option.none (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ) ∧
                                Benitoite.Release.Refinement.StateTyE P B σ Eb
                                  (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ)
```

## Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs

所在: `formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean`、行: 19。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
            Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
              ∃ Ψ R a e sg r ef,
                Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                  Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                    B.sig b = Option.some sg ∧
                      Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
                          (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws r ef ∧
                        Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                          Benitoite.Release.Refinement.Eff.Covers [] [] e ef ∧
                            ∀ (w : Benitoite.Release.Refinement.Val),
                              w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w
```

## Benitoite.Release.Refinement.SignatureInstance

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 116。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.TypeCtx →
    Benitoite.Release.Refinement.Ctx →
      Benitoite.Release.Refinement.Tel →
        List Benitoite.Release.Refinement.TyKind →
          List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.SnapshotMem

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 62。

```lean
Option Benitoite.Release.Refinement.PathEnv →
  Benitoite.Scope.Domain.Kind → Benitoite.Release.Refinement.RangeExpr → Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.SnapshotMem.mono

所在: `formal/Benitoite/Release/Refinement/ScopeCoverage.lean`、行: 71。

```lean
∀ {snapshot : Option Benitoite.Release.Refinement.PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.SnapshotMem snapshot k r t →
    s.Covers r → Benitoite.Release.Refinement.SnapshotMem snapshot k s t
```

## Benitoite.Release.Refinement.Sort

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 193。

```lean
Type
```

## Benitoite.Release.Refinement.Sort.boolean

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.boolean.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 5 → motive Benitoite.Release.Refinement.Sort.boolean → motive t
```

## Benitoite.Release.Refinement.Sort.bytes

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.bytes.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 9 → motive Benitoite.Release.Refinement.Sort.bytes → motive t
```

## Benitoite.Release.Refinement.Sort.character

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.character.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.Sort.character → motive t
```

## Benitoite.Release.Refinement.Sort.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 193。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Sort) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Sort.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Sort.data

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.data.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 12 → motive Benitoite.Release.Refinement.Sort.data → motive t
```

## Benitoite.Release.Refinement.Sort.decimal

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.decimal.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 4 → motive Benitoite.Release.Refinement.Sort.decimal → motive t
```

## Benitoite.Release.Refinement.Sort.float32

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.float32.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 3 → motive Benitoite.Release.Refinement.Sort.float32 → motive t
```

## Benitoite.Release.Refinement.Sort.float64

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.float64.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 2 → motive Benitoite.Release.Refinement.Sort.float64 → motive t
```

## Benitoite.Release.Refinement.Sort.integer

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.integer.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 0 → motive Benitoite.Release.Refinement.Sort.integer → motive t
```

## Benitoite.Release.Refinement.Sort.list

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.list.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 8 → motive Benitoite.Release.Refinement.Sort.list → motive t
```

## Benitoite.Release.Refinement.Sort.map

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.map.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 10 → motive Benitoite.Release.Refinement.Sort.map → motive t
```

## Benitoite.Release.Refinement.Sort.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 193。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Sort} → t = t' → Benitoite.Release.Refinement.Sort.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Sort.set

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.set.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 195。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 11 → motive Benitoite.Release.Refinement.Sort.set → motive t
```

## Benitoite.Release.Refinement.Sort.string

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.string.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 7 → motive Benitoite.Release.Refinement.Sort.string → motive t
```

## Benitoite.Release.Refinement.Sort.target

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 196。

```lean
Benitoite.Scope.Domain.Kind → Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.target.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 196。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) →
    t.ctorIdx = 13 →
      ((kind : Benitoite.Scope.Domain.Kind) → motive (Benitoite.Release.Refinement.Sort.target kind)) → motive t
```

## Benitoite.Release.Refinement.Sort.target.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 196。

```lean
{P : Sort u} →
  {kind kind' : Benitoite.Scope.Domain.Kind} →
    Benitoite.Release.Refinement.Sort.target kind = Benitoite.Release.Refinement.Sort.target kind' →
      (kind = kind' → P) → P
```

## Benitoite.Release.Refinement.Sort.unit

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Sort.unit.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 194。

```lean
{motive : Benitoite.Release.Refinement.Sort → Sort u} →
  (t : Benitoite.Release.Refinement.Sort) → t.ctorIdx = 6 → motive Benitoite.Release.Refinement.Sort.unit → motive t
```

## Benitoite.Release.Refinement.SplitAt

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 43。

```lean
Benitoite.Release.OpRef →
  Benitoite.Release.Refinement.Cont →
    Benitoite.Release.Refinement.Cont →
      Benitoite.Release.Refinement.Capture →
        List Benitoite.Release.Refinement.Clause → Benitoite.Release.Refinement.Cont → Prop
```

## Benitoite.Release.Refinement.StandardKeyTyping.DataDecl

所在: `formal/Benitoite/Release/Refinement/StandardKeyTyping.lean`、行: 28。

```lean
Type
```

## Benitoite.Release.Refinement.State

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 30。

```lean
Type
```

## Benitoite.Release.Refinement.State.Inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`、行: 279。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.State.run

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 31。

```lean
Benitoite.Release.Refinement.Closure →
  Benitoite.Release.Refinement.Cont → Benitoite.Release.Refinement.Store → Benitoite.Release.Refinement.State
```

## Benitoite.Release.Refinement.StateTy

所在: `formal/Benitoite/Release/Refinement/StateTyping.lean`、行: 168。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.StateTyE

所在: `formal/Benitoite/Release/Refinement/StateTyping.lean`、行: 158。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.StateTyE.app_inputs

所在: `formal/Benitoite/Release/Refinement/ApplicationInputs.lean`、行: 43。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {f : Benitoite.Release.Refinement.Val}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app f ws →
            ∃ Ψ R a e t r ef,
              Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] f
                      (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
                    Benitoite.Release.Refinement.Ty.Annotation P [] [] (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
                      Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws t r ef ∧
                        Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                          Benitoite.Release.Refinement.Eff.Covers [] [] e ef
```

## Benitoite.Release.Refinement.StateTyE.at_current

所在: `formal/Benitoite/Release/Refinement/PathBasesTargets.lean`、行: 18。

```lean
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
        ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = Option.some ρ → ρ = σ
```

## Benitoite.Release.Refinement.StateTyE.at_error_all

所在: `formal/Benitoite/Release/Refinement/AtStateLeaves.lean`、行: 116。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {detail : Benitoite.Release.Refinement.AtCheckError} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat target
          bound →
        (∀ (ρ : Benitoite.Release.Refinement.PathEnv), snapshot = Option.some ρ → ρ = σ) →
          Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
              Benitoite.Release.Refinement.AtResult.error detail →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.con shape.error
                        [Benitoite.Release.Refinement.Ty.scoped name kind
                            (Benitoite.Release.Refinement.RangeIx.fixed bound),
                          q.capture.closeTy shape.errorType]
                        [Benitoite.Release.Refinement.Val.atError
                            (Benitoite.Release.Refinement.AtError.fromCheck
                              (Benitoite.Release.Refinement.closeVal q.capture pattern)
                              (Benitoite.Release.Refinement.closeVal q.capture input) snapshot pat target detail)])))
                  k μ) ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.con shape.error
                        [Benitoite.Release.Refinement.Ty.scoped name kind
                            (Benitoite.Release.Refinement.RangeIx.fixed bound),
                          q.capture.closeTy shape.errorType]
                        [Benitoite.Release.Refinement.Val.atError
                            (Benitoite.Release.Refinement.AtError.fromCheck
                              (Benitoite.Release.Refinement.closeVal q.capture pattern)
                              (Benitoite.Release.Refinement.closeVal q.capture input) snapshot pat target detail)])))
                  k μ)
```

## Benitoite.Release.Refinement.StateTyE.at_index

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 29。

```lean
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

## Benitoite.Release.Refinement.StateTyE.at_ok_all

所在: `formal/Benitoite/Release/Refinement/AtStateLeaves.lean`、行: 57。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Scope.Domain.Target} {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
              Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat
                  target bound →
                (∀ (ρ : Benitoite.Release.Refinement.PathEnv), snapshot = Option.some ρ → ρ = σ) →
                  Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
                      Benitoite.Release.Refinement.AtResult.ok t →
                    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.pure
                            (Benitoite.Release.Refinement.Comp.ret
                              (Benitoite.Release.Refinement.Val.con shape.ok
                                [Benitoite.Release.Refinement.Ty.scoped name kind
                                    (Benitoite.Release.Refinement.RangeIx.fixed bound),
                                  q.capture.closeTy shape.errorType]
                                [Benitoite.Release.Refinement.Val.checkedAt bound snapshot t
                                    (Benitoite.Release.Refinement.AtRequest B name
                                      (Benitoite.Release.Refinement.closeVal q.capture input))])))
                          k μ) ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.pure
                            (Benitoite.Release.Refinement.Comp.ret
                              (Benitoite.Release.Refinement.Val.con shape.ok
                                [Benitoite.Release.Refinement.Ty.scoped name kind
                                    (Benitoite.Release.Refinement.RangeIx.fixed bound),
                                  q.capture.closeTy shape.errorType]
                                [Benitoite.Release.Refinement.Val.checkedAt bound snapshot t
                                    (Benitoite.Release.Refinement.AtRequest B name
                                      (Benitoite.Release.Refinement.closeVal q.capture input))])))
                          k μ)
```

## Benitoite.Release.Refinement.StateTyE.at_prepare_error_all

所在: `formal/Benitoite/Release/Refinement/AtStateLeaves.lean`、行: 141。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {detail : Benitoite.Release.Refinement.AtError} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepare B q.capture kind name bases pattern input index = Except.error detail →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
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

## Benitoite.Release.Refinement.StateTyE.at_prepare_failure

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 37。

```lean
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
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
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

## Benitoite.Release.Refinement.StateTyE.at_step

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 51。

```lean
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
                Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                    next ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb next
```

## Benitoite.Release.Refinement.StateTyE.inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`、行: 294。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {s : Benitoite.Release.Refinement.State},
  Benitoite.Release.Refinement.StateTyE P B σ Eb s → Benitoite.Release.Refinement.State.Inputs P B σ Eb s
```

## Benitoite.Release.Refinement.StateTyE.io_error_all

所在: `formal/Benitoite/Release/Refinement/ReplyState.lean`、行: 95。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {r : Benitoite.Release.ErrKind} {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                (List.map Benitoite.Release.Refinement.Eff.norm es) ws (Benitoite.Release.Refinement.Outcome.err r)
                obs →
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                  (Option.some
                    (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.err r) obs))
                  (Benitoite.Release.Refinement.State.error [r] k μ) ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.StateTyE.io_exit_all

所在: `formal/Benitoite/Release/Refinement/ReplyState.lean`、行: 103。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {n : Int} {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                (List.map Benitoite.Release.Refinement.Eff.norm es) ws (Benitoite.Release.Refinement.Outcome.exit n)
                obs →
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                  (Option.some
                    (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.exit n) obs))
                  (Benitoite.Release.Refinement.State.exit n [] k μ) ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.exit n [] k μ)
```

## Benitoite.Release.Refinement.StateTyE.io_value_all

所在: `formal/Benitoite/Release/Refinement/ReplyState.lean`、行: 79。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = Option.some s →
                s.kind = Benitoite.Release.Refinement.PrimKind.io →
                  Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                    B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                        (List.map Benitoite.Release.Refinement.Eff.norm es) ws
                        (Benitoite.Release.Refinement.Outcome.val v) obs →
                      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                          (Option.some
                            (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.val v)
                              obs))
                          (Benitoite.Release.Refinement.State.run
                            (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                        Benitoite.Release.Refinement.StateTyE P B σ Eb
                          (Benitoite.Release.Refinement.State.run
                            (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StateTyE.issue_path_bases_all

所在: `formal/Benitoite/Release/Refinement/PathBasesLeaves.lean`、行: 84。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.view = Benitoite.Release.Refinement.Comp.issuePathBases b →
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
          s.opEff = Option.some Benitoite.Release.Refinement.processEnvironmentEff →
            σ.Valid →
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                  (Option.some (Benitoite.Release.Refinement.Event.pathBases b σ))
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                    k μ) ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                    k μ)
```

## Benitoite.Release.Refinement.StateTyE.operation_primitive

所在: `formal/Benitoite/Release/Refinement/HandlerGeneral.lean`、行: 1371。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {k1 : Benitoite.Release.Refinement.Cont} {cs : List Benitoite.Release.Refinement.Clause}
  {k2 : Benitoite.Release.Refinement.Cont} {c : Benitoite.Release.Refinement.Clause} {l : Nat}
  {hcap : Benitoite.Release.Refinement.Capture},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        P.EffectsOk B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = Option.some s →
                s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                      s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
                  Benitoite.Release.Refinement.SplitAt (Benitoite.Release.OpRef.prim b) k k1 hcap cs k2 →
                    Benitoite.Release.Refinement.findClause cs (Benitoite.Release.OpRef.prim b) = Option.some c →
                      μ l = Option.none →
                        Benitoite.Release.Refinement.StateTyE P B σ Eb
                          (Benitoite.Release.Refinement.State.run
                            (Benitoite.Release.Refinement.Closure.mk
                              (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc l]))
                              (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
                            (Benitoite.Release.Refinement.Frame.drop l :: k2)
                            (μ.set l
                              (Benitoite.Release.Refinement.Cell.cont
                                (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap cs]))))
```

## Benitoite.Release.Refinement.StateTyE.path_bases_apply_all

所在: `formal/Benitoite/Release/Refinement/PathBasesLeaves.lean`、行: 30。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b [] [] []) [] →
            B.sig b = Option.some s →
              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
                Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.mk q.capture
                          (Benitoite.Release.Refinement.Comp.issuePathBases b))
                        k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.mk q.capture
                          (Benitoite.Release.Refinement.Comp.issuePathBases b))
                        k μ)
```

## Benitoite.Release.Refinement.StateTyE.primitive_contract_inputs

所在: `formal/Benitoite/Release/Refinement/ApplicationInputs.lean`、行: 61。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
            ∃ Ψ R a e sg r ef,
              Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                  B.sig b = Option.some sg ∧
                    B.RangeAdmissible b sg rs ∧
                      Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es ∧
                        Benitoite.Release.Refinement.SignatureInstance P [] []
                            (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
                            (Benitoite.Release.Refinement.TypeCtx.kinds sg.tparams) ts es ∧
                          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                              (Benitoite.Release.Refinement.instantiatedTel
                                (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es)
                              r ef ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e ef
```

## Benitoite.Release.Refinement.StateTyE.primitive_error_all

所在: `formal/Benitoite/Release/Refinement/ReplyState.lean`、行: 72。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {r : Benitoite.Release.ErrKind},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.pure →
          B.delta b (Benitoite.Release.Refinement.Ty.normTys ts) (List.map Benitoite.Release.Refinement.Eff.norm es) rs
                ws =
              Option.some (Benitoite.Release.Refinement.Outcome.err r) →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                (Benitoite.Release.Refinement.State.error [r] k μ) ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error [r] k μ)
```

