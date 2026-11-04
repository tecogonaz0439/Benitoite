# 段末の実署名（続き）

## Benitoite.Release.Refinement.StateTyE.primitive_value_all

所在: `formal/Benitoite/Release/Refinement/ReplyState.lean`、行: 54。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {v : Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = Option.some s →
                s.kind = Benitoite.Release.Refinement.PrimKind.pure →
                  B.delta b (Benitoite.Release.Refinement.Ty.normTys ts)
                        (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws =
                      Option.some (Benitoite.Release.Refinement.Outcome.val v) →
                    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StateTyE.selected_primitive_step

所在: `formal/Benitoite/Release/Refinement/StepLeafSelection.lean`、行: 252。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {externalOracle : Benitoite.Release.Refinement.ExternalOracle}
  {rel : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {q : Benitoite.Release.Refinement.Closure}
  {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {sg : Benitoite.Release.Refinement.PrimSig},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
            B.sig b = Option.some sg →
              sg.kind = Benitoite.Release.Refinement.PrimKind.pure ∨
                  sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
                Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                  ∃ event dest,
                    Benitoite.Release.Refinement.step P B σ B.selectOracle externalOracle rel fresh
                          (Benitoite.Release.Refinement.State.run q k μ) =
                        Option.some (event, dest) ∧
                      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) event dest
```

## Benitoite.Release.Refinement.StateTyE.store_reply

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 111。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {s : Benitoite.Release.Refinement.State} {event : Option Benitoite.Release.Refinement.Event}
  {dest : Benitoite.Release.Refinement.State},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb s →
            Benitoite.Release.Refinement.StoreReplyInputs P B σ s event dest →
              Benitoite.Release.Refinement.Step P B σ s event dest ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb dest ∧
                  Benitoite.Release.Refinement.LocalStateInvariant P B σ dest
```

## Benitoite.Release.Refinement.Step

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 59。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.State →
        Option Benitoite.Release.Refinement.Event → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.Step.E_AtError

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 112。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {detail : Benitoite.Release.Refinement.AtCheckError} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
    Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
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
              k μ)
```

## Benitoite.Release.Refinement.Step.E_AtOk

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 104。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Scope.Domain.Target} {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
    Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
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
              k μ)
```

## Benitoite.Release.Refinement.Step.E_AtPrepareError

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 119。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {detail : Benitoite.Release.Refinement.AtError} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
    Benitoite.Release.Refinement.AtPrepare B q.capture kind name bases pattern input index = Except.error detail →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure
            (Benitoite.Release.Refinement.Comp.ret
              (Benitoite.Release.Refinement.Val.con shape.error
                [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                [Benitoite.Release.Refinement.Val.atError detail])))
          k μ)
```

## Benitoite.Release.Refinement.Step.E_BuilderErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 70。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Release.Refinement.BuilderKind}
  {op : Benitoite.Release.Refinement.BuilderOp} {l : Nat} {args : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {c : Benitoite.Release.Refinement.BuilderContents} {r : Benitoite.Release.ErrKind}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.builderOp kind op (Benitoite.Release.LocalRef.loc l) args →
    μ l = Option.some (Benitoite.Release.Refinement.Cell.builder c) →
      Benitoite.Release.Refinement.builderApply op c args =
          Option.some (Benitoite.Release.Refinement.BuilderReply.error r) →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.Step.E_BuilderNew

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 60。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Release.Refinement.BuilderKind}
  {body : Benitoite.Release.Refinement.Comp} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.builderLet kind body →
    μ l = Option.none →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.mk q.capture
            (Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.builderValueSubst body
              (Benitoite.Release.builderLocalSubst l)))
          k (μ.set l (Benitoite.Release.Refinement.Cell.builder kind.empty)))
```

## Benitoite.Release.Refinement.Step.E_BuilderOp

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 65。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Release.Refinement.BuilderKind}
  {op : Benitoite.Release.Refinement.BuilderOp} {l : Nat} {args : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {c c' : Benitoite.Release.Refinement.BuilderContents} {v : Benitoite.Release.Refinement.Val}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.builderOp kind op (Benitoite.Release.LocalRef.loc l) args →
    μ l = Option.some (Benitoite.Release.Refinement.Cell.builder c) →
      Benitoite.Release.Refinement.builderApply op c args =
          Option.some (Benitoite.Release.Refinement.BuilderReply.value c' v) →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.run
            (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k
            (μ.set l (Benitoite.Release.Refinement.Cell.builder c')))
```

## Benitoite.Release.Refinement.Step.E_Drop

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 327。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    μ κ = Option.some Benitoite.Release.Refinement.Cell.used →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_DropRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 331。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {k' : Benitoite.Release.Refinement.Cont} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    μ κ = Option.some (Benitoite.Release.Refinement.Cell.cont k') →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v))
          (Benitoite.Release.Refinement.releases k' ++ k) (μ.set κ Benitoite.Release.Refinement.Cell.used))
```

## Benitoite.Release.Refinement.Step.E_Err

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 179。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {r : Benitoite.Release.ErrKind} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.pure →
        B.delta b (Benitoite.Release.Refinement.Ty.normTys ts) (List.map Benitoite.Release.Refinement.Eff.norm es) rs
              ws =
            Option.some (Benitoite.Release.Refinement.Outcome.err r) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrDrop

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 346。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  μ κ = Option.some Benitoite.Release.Refinement.Cell.used →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrDropRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 348。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {k' : Benitoite.Release.Refinement.Cont},
  μ κ = Option.some (Benitoite.Release.Refinement.Cell.cont k') →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.releases k' ++ k)
        (μ.set κ Benitoite.Release.Refinement.Cell.used))
```

## Benitoite.Release.Refinement.Step.E_ErrPopGuard

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 171。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {arms : List Benitoite.Release.Refinement.Arm} {next : Nat}
  {body : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {cap : Benitoite.Release.Refinement.Capture},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.guardF v cap arms next body :: k)
      μ)
    Option.none (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrPopHandle

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 275。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind}
  {h : List Benitoite.Release.Refinement.Clause} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {hcap : Benitoite.Release.Refinement.Capture},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.handleF hcap h :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrPopLet

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 272。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind}
  {n : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.letF n :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrPopMark

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 273。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.mark :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrPopUpdate

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 274。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind} {l : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.update l :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 276。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  B.releaseResponse v Option.none →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
      (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
      (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ErrRelErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 279。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {r : Benitoite.Release.ErrKind},
  B.releaseResponse v (Option.some r) →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
      (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
      (Benitoite.Release.Refinement.State.error (rs ++ [r]) k μ)
```

## Benitoite.Release.Refinement.Step.E_EscDrop

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 337。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.escape v →
    μ κ = Option.some Benitoite.Release.Refinement.Cell.used →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_EscDropRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 341。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {k' : Benitoite.Release.Refinement.Cont} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.escape v →
    μ κ = Option.some (Benitoite.Release.Refinement.Cell.cont k') →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape v))
          (Benitoite.Release.Refinement.releases k' ++ k) (μ.set κ Benitoite.Release.Refinement.Cell.used))
```

## Benitoite.Release.Refinement.Step.E_EscHandle

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 245。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {h : List Benitoite.Release.Refinement.Clause} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure}
  {hcap : Benitoite.Release.Refinement.Capture},
  q.view = Benitoite.Release.Refinement.Comp.escape v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.handleF hcap h :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_EscLet

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 242。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {n : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.escape v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.letF n :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_EscMark

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 248。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.escape v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.mark :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_EscRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 263。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {w v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.escape w →
    B.releaseResponse v Option.none →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
        (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape w)) k μ)
```

## Benitoite.Release.Refinement.Step.E_EscRelErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 267。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {w v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store} {r : Benitoite.Release.ErrKind}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.escape w →
    B.releaseResponse v (Option.some r) →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
        (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
        (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.Step.E_Exit

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 196。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {n : Int} {obs : List Benitoite.Scope.Domain.Target}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
          B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
              (List.map Benitoite.Release.Refinement.Eff.norm es) ws (Benitoite.Release.Refinement.Outcome.exit n) obs →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.exit n) obs))
              (Benitoite.Release.Refinement.State.exit n [] k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitDrop

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 351。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  μ κ = Option.some Benitoite.Release.Refinement.Cell.used →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitDropRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 353。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind} {κ : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {k' : Benitoite.Release.Refinement.Cont},
  μ κ = Option.some (Benitoite.Release.Refinement.Cell.cont k') →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.drop κ :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.releases k' ++ k)
        (μ.set κ Benitoite.Release.Refinement.Cell.used))
```

## Benitoite.Release.Refinement.Step.E_ExitPopGuard

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 173。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {arms : List Benitoite.Release.Refinement.Arm} {next : Nat}
  {body : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {cap : Benitoite.Release.Refinement.Capture},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.guardF v cap arms next body :: k)
      μ)
    Option.none (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitPopHandle

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 286。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {h : List Benitoite.Release.Refinement.Clause} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {hcap : Benitoite.Release.Refinement.Capture},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.handleF hcap h :: k) μ)
    Option.none (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitPopLet

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 283。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {m : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.letF m :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitPopMark

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 284。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.mark :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitPopUpdate

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 285。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind} {l : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Step P B σ
    (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.update l :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitRel

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 287。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  B.releaseResponse v Option.none →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
      (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
      (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.Step.E_ExitRelErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 290。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {r : Benitoite.Release.ErrKind},
  B.releaseResponse v (Option.some r) →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
      (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
      (Benitoite.Release.Refinement.State.exit n (rs ++ [r]) k μ)
```

## Benitoite.Release.Refinement.Step.E_External

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 87。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {decl : Benitoite.Release.Refinement.ExternalSignature}
  {v : Benitoite.Release.Refinement.Val} {obs : List Benitoite.Scope.Domain.Target}
  {out : Benitoite.Release.Refinement.Outcome},
  q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
    P.externalFunction f = Option.some decl →
      B.externalResponse f ts ws out obs →
        Benitoite.Release.Refinement.externalReceive P decl ts ws out =
            Option.some (Benitoite.Release.Refinement.Outcome.val v) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_ExternalApply

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 84。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) ws →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts ws)) k μ)
```

## Benitoite.Release.Refinement.Step.E_ExternalErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 91。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {decl : Benitoite.Release.Refinement.ExternalSignature}
  {r : Benitoite.Release.ErrKind} {obs : List Benitoite.Scope.Domain.Target}
  {out : Benitoite.Release.Refinement.Outcome},
  q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
    P.externalFunction f = Option.some decl →
      B.externalResponse f ts ws out obs →
        Benitoite.Release.Refinement.externalReceive P decl ts ws out =
            Option.some (Benitoite.Release.Refinement.Outcome.err r) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.Step.E_Force

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 231。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {l : Nat} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {s : Benitoite.Release.Refinement.PrimSig}
  {m q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs)
        [Benitoite.Release.Refinement.Val.loc l] →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.force →
        μ l = Option.some (Benitoite.Release.Refinement.Cell.thunk m) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run m (Benitoite.Release.Refinement.Frame.update l :: k) μ)
```

## Benitoite.Release.Refinement.Step.E_ForceDone

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 227。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {l : Nat} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {s : Benitoite.Release.Refinement.PrimSig}
  {v : Benitoite.Release.Refinement.Val} {q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs)
        [Benitoite.Release.Refinement.Val.loc l] →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.force →
        μ l = Option.some (Benitoite.Release.Refinement.Cell.done v) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_Fun

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 125。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {f : Benitoite.Release.FunName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {d : Benitoite.Release.Refinement.Def} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.fnRef f ts es) ws →
    P.defs f = Option.some d →
      ws.length = d.params.length →
        ts.length = d.ntys →
          es.length = d.neffs →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.mk (Benitoite.Release.Refinement.Capture.empty.extendMany ws)
                  (Benitoite.Release.Refinement.Comp.substTy ts es d.body))
                (Benitoite.Release.Refinement.markPush k) μ)
```

## Benitoite.Release.Refinement.Step.E_GuardF

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 167。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {body : Benitoite.Release.Refinement.Closure}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure} {cap : Benitoite.Release.Refinement.Capture},
  q.view =
      Benitoite.Release.Refinement.Comp.ret
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean Bool.false)) →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.guardF v cap arms next body :: k) μ)
      Option.none (Benitoite.Release.Refinement.State.matchRun v cap arms next k μ)
```

## Benitoite.Release.Refinement.Step.E_GuardT

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 164。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {body : Benitoite.Release.Refinement.Closure}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure} {cap : Benitoite.Release.Refinement.Capture},
  q.view =
      Benitoite.Release.Refinement.Comp.ret
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean Bool.true)) →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.guardF v cap arms next body :: k) μ)
      Option.none (Benitoite.Release.Refinement.State.run body k μ)
```

## Benitoite.Release.Refinement.Step.E_HRet

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 297。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {h : List Benitoite.Release.Refinement.Clause} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure}
  {hcap : Benitoite.Release.Refinement.Capture},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.handleF hcap h :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_Handle

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 294。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m : Benitoite.Release.Refinement.Comp}
  {h : List Benitoite.Release.Refinement.Clause} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure},
  q.view = m.handle h →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture m)
        (Benitoite.Release.Refinement.Frame.handleF q.capture h :: k) μ)
```

## Benitoite.Release.Refinement.Step.E_IO

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 184。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.io →
        Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
          B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
              (List.map Benitoite.Release.Refinement.Eff.norm es) ws (Benitoite.Release.Refinement.Outcome.val v) obs →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.val v) obs))
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_IOErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 190。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {r : Benitoite.Release.ErrKind} {obs : List Benitoite.Scope.Domain.Target}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
          B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
              (List.map Benitoite.Release.Refinement.Eff.norm es) ws (Benitoite.Release.Refinement.Outcome.err r) obs →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.err r) obs))
              (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.Step.E_IfF

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 148。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m n : Benitoite.Release.Refinement.Comp}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.ite
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean Bool.false)) m n →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture n) k μ)
```

## Benitoite.Release.Refinement.Step.E_IfT

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 145。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m n : Benitoite.Release.Refinement.Comp}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.ite
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean Bool.true)) m n →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture m) k μ)
```

## Benitoite.Release.Refinement.Step.E_IssuePathBases

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 99。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.issuePathBases b →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
        sg.opEff = Option.some Benitoite.Release.Refinement.processEnvironmentEff →
          σ.Valid →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some (Benitoite.Release.Refinement.Event.pathBases b σ))
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                k μ)
```

## Benitoite.Release.Refinement.Step.E_Lam

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 80。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.Val} {signature : Benitoite.Release.Refinement.Tel}
  {body : Benitoite.Release.Refinement.Closure} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.app f ws →
    Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty f =
        Benitoite.Release.Refinement.Val.closure signature body →
      ws.length = signature.arity →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.run (body.apply ws) (Benitoite.Release.Refinement.markPush k) μ)
```

## Benitoite.Release.Refinement.Step.E_Lazy

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 223。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m : Benitoite.Release.Refinement.Comp}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store} {l : Nat}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = m.lazyC →
    μ l = Option.none →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure
            (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.loc l)))
          k (μ.set l (Benitoite.Release.Refinement.Cell.thunk (Benitoite.Release.Refinement.Closure.mk q.capture m))))
```

## Benitoite.Release.Refinement.Step.E_Let

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 74。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m n : Benitoite.Release.Refinement.Comp}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = m.letIn n →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture m)
        (Benitoite.Release.Refinement.Frame.letF (Benitoite.Release.Refinement.Closure.mk q.capture n) :: k) μ)
```

## Benitoite.Release.Refinement.Step.E_Mark

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 239。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.mark :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_Match

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 151。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {arms : List Benitoite.Release.Refinement.Arm} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.match v arms →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.matchRun v q.capture arms 0 k μ)
```

## Benitoite.Release.Refinement.Step.E_MatchBody

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 157。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {alts : List Benitoite.Release.Alt}
  {body : Benitoite.Release.Refinement.Comp} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {cap : Benitoite.Release.Refinement.Capture},
  arms[next]? = Option.some (Benitoite.Release.Refinement.Arm.mk alts Option.none body) →
    Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.matchRun v cap arms next k μ)
        Option.none
        (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk (cap.extendMany ws) body) k μ)
```

## Benitoite.Release.Refinement.Step.E_MatchGuard

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 160。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {alts : List Benitoite.Release.Alt}
  {guard body : Benitoite.Release.Refinement.Comp} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {cap : Benitoite.Release.Refinement.Capture},
  arms[next]? = Option.some (Benitoite.Release.Refinement.Arm.mk alts (Option.some guard) body) →
    Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.matchRun v cap arms next k μ)
        Option.none
        (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk (cap.extendMany ws) guard)
          (Benitoite.Release.Refinement.Frame.guardF v cap arms (next + 1)
              (Benitoite.Release.Refinement.Closure.mk (cap.extendMany ws) body) ::
            k)
          μ)
```

## Benitoite.Release.Refinement.Step.E_MatchSkip

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 154。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {alts : List Benitoite.Release.Alt}
  {guard : Option Benitoite.Release.Refinement.Comp} {body : Benitoite.Release.Refinement.Comp}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {cap : Benitoite.Release.Refinement.Capture},
  arms[next]? = Option.some (Benitoite.Release.Refinement.Arm.mk alts guard body) →
    Benitoite.Release.Refinement.firstAlt v alts = Option.none →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.matchRun v cap arms next k μ)
        Option.none (Benitoite.Release.Refinement.State.matchRun v cap arms (next + 1) k μ)
```

## Benitoite.Release.Refinement.Step.E_Meth

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 132。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {i : Benitoite.Release.ImplName}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {m : Benitoite.Release.MethName} {ss : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {id : Benitoite.Release.Refinement.ImplDecl} {body : Benitoite.Release.Refinement.Comp}
  {cd : Benitoite.Release.Refinement.ClassDecl} {ms : Benitoite.Release.Refinement.MethSig}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.meth (Benitoite.Release.Refinement.Val.dict i ts vs) m ss es ws →
    P.impls i = Option.some id →
      id.methods m = Option.some body →
        P.classes id.cls = Option.some cd →
          cd.methods m = Option.some ms →
            ws.length = ms.params.length →
              vs.length = id.dictTys.length →
                ts.length = id.tparams.length →
                  ss.length = ms.tparams.length →
                    es.length = ms.neffs →
                      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.mk
                            (Benitoite.Release.Refinement.Capture.empty.extendMany (vs ++ ws))
                            (Benitoite.Release.Refinement.Comp.substTy (ss ++ ts) es body))
                          (Benitoite.Release.Refinement.markPush k) μ)
```

## Benitoite.Release.Refinement.Step.E_Op

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 301。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {o : Benitoite.Release.OpName} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {k1 : Benitoite.Release.Refinement.Cont}
  {h : List Benitoite.Release.Refinement.Clause} {k2 : Benitoite.Release.Refinement.Cont}
  {c : Benitoite.Release.Refinement.Clause} {κ : Nat} {q : Benitoite.Release.Refinement.Closure}
  {hcap : Benitoite.Release.Refinement.Capture},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.op o ts) ws →
    Benitoite.Release.Refinement.SplitAt (Benitoite.Release.OpRef.user o) k k1 hcap h k2 →
      Benitoite.Release.Refinement.findClause h (Benitoite.Release.OpRef.user o) = Option.some c →
        μ κ = Option.none →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.mk
                (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc κ]))
                (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
              (Benitoite.Release.Refinement.Frame.drop κ :: k2)
              (μ.set κ
                (Benitoite.Release.Refinement.Cell.cont (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap h]))))
```

## Benitoite.Release.Refinement.Step.E_OpFail

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 307。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {T E' : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {k1 : Benitoite.Release.Refinement.Cont}
  {E : Benitoite.Release.Refinement.Ty} {body : Benitoite.Release.Refinement.Comp}
  {k2 : Benitoite.Release.Refinement.Cont} {κ : Nat} {q : Benitoite.Release.Refinement.Closure}
  {hcap : Benitoite.Release.Refinement.Capture},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.raise T E') [v] →
    Benitoite.Release.Refinement.SplitAt Benitoite.Release.OpRef.fail k k1 hcap
        [Benitoite.Release.Refinement.Clause.fail E body] k2 →
      μ κ = Option.none →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.run
            (Benitoite.Release.Refinement.Closure.mk (hcap.extendMany [v, Benitoite.Release.Refinement.Val.loc κ])
              (Benitoite.Release.Refinement.Comp.substTy [T] [] body))
            (Benitoite.Release.Refinement.Frame.drop κ :: k2)
            (μ.set κ
              (Benitoite.Release.Refinement.Cell.cont
                (k1 ++
                  [Benitoite.Release.Refinement.Frame.handleF hcap
                      [Benitoite.Release.Refinement.Clause.fail E body]]))))
```

## Benitoite.Release.Refinement.Step.E_OpPrim

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 313。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {k1 : Benitoite.Release.Refinement.Cont}
  {h : List Benitoite.Release.Refinement.Clause} {k2 : Benitoite.Release.Refinement.Cont}
  {c : Benitoite.Release.Refinement.Clause} {κ : Nat} {q : Benitoite.Release.Refinement.Closure}
  {hcap : Benitoite.Release.Refinement.Capture},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
          s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
        Benitoite.Release.Refinement.SplitAt (Benitoite.Release.OpRef.prim b) k k1 hcap h k2 →
          Benitoite.Release.Refinement.findClause h (Benitoite.Release.OpRef.prim b) = Option.some c →
            μ κ = Option.none →
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.mk
                    (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc κ]))
                    (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
                  (Benitoite.Release.Refinement.Frame.drop κ :: k2)
                  (μ.set κ
                    (Benitoite.Release.Refinement.Cell.cont
                      (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap h]))))
```

## Benitoite.Release.Refinement.Step.E_PathBasesApply

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 95。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b [] [] []) [] →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
        Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.mk q.capture (Benitoite.Release.Refinement.Comp.issuePathBases b)) k
              μ)
```

## Benitoite.Release.Refinement.Step.E_Prim

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 175。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {v : Benitoite.Release.Refinement.Val}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.pure →
        B.delta b (Benitoite.Release.Refinement.Ty.normTys ts) (List.map Benitoite.Release.Refinement.Eff.norm es) rs
              ws =
            Option.some (Benitoite.Release.Refinement.Outcome.val v) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_RefGet

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 206。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {l : Nat} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {s : Benitoite.Release.Refinement.PrimSig}
  {v : Benitoite.Release.Refinement.Val} {q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs)
        [Benitoite.Release.Refinement.Val.loc l] →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.refGet →
        μ l = Option.some (Benitoite.Release.Refinement.Cell.val v) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.Step.E_RefNew

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 202。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {v : Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {l : Nat} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) [v] →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.refNew →
        μ l = Option.none →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure
                (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.loc l)))
              k (μ.set l (Benitoite.Release.Refinement.Cell.val v)))
```

## Benitoite.Release.Refinement.Step.E_RefSet

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 210。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {l : Nat} {v : Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs)
        [Benitoite.Release.Refinement.Val.loc l, v] →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.refSet →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.run
            (Benitoite.Release.Refinement.Closure.pure
              (Benitoite.Release.Refinement.Comp.ret
                (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
            k (μ.set l (Benitoite.Release.Refinement.Cell.val v)))
```

## Benitoite.Release.Refinement.Step.E_RefUpdate

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 216。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {l : Nat} {f : Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {s : Benitoite.Release.Refinement.PrimSig} {q : Benitoite.Release.Refinement.Closure},
  q.view =
      Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs)
        [Benitoite.Release.Refinement.Val.loc l, f] →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.refUpdate →
        Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.run
            (Benitoite.Release.Refinement.Closure.pure
              ((Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim B.refGet ts [] [])
                    [Benitoite.Release.Refinement.Val.loc l]).letIn
                ((Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.rename (fun x => x + 1) f)
                      [Benitoite.Release.Refinement.Val.var 0]).letIn
                  (Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim B.refSet ts [] [])
                    [Benitoite.Release.Refinement.Val.loc l, Benitoite.Release.Refinement.Val.var 0]))))
            k μ)
```

## Benitoite.Release.Refinement.Step.E_RelErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 259。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {w v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store} {r : Benitoite.Release.ErrKind}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret w →
    B.releaseResponse v (Option.some r) →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
        (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
        (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.Step.E_Release

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 255。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {w v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret w →
    B.releaseResponse v Option.none →
      Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
        (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret w)) k μ)
```

## Benitoite.Release.Refinement.Step.E_Resume

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 319。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Nat} {v : Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {k' : Benitoite.Release.Refinement.Cont} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.resume (Benitoite.Release.Refinement.Val.loc κ) v →
    μ κ = Option.some (Benitoite.Release.Refinement.Cell.cont k') →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) (k' ++ k)
          (μ.set κ Benitoite.Release.Refinement.Cell.used))
```

## Benitoite.Release.Refinement.Step.E_ResumeErr

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 323。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Nat} {v : Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.resume (Benitoite.Release.Refinement.Val.loc κ) v →
    μ κ = Option.some Benitoite.Release.Refinement.Cell.used →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.error [Benitoite.Release.Refinement.rResume] k μ)
```

## Benitoite.Release.Refinement.Step.E_Return

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 77。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {n : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.letF n :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run (n.apply [v]) k μ)
```

## Benitoite.Release.Refinement.Step.E_Super

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 141。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v v' : Benitoite.Release.Refinement.Val} {m : Benitoite.Release.MethName}
  {ss : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.meth v m ss es ws →
    Benitoite.Release.Refinement.Val.superStep P v = Option.some v' →
      Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.meth v' m ss es ws)) k μ)
```

