# 段末の実署名（続き）

## Benitoite.Release.Refinement.Step.E_Update

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 235。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val} {l : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    Benitoite.Release.Refinement.Step P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.update l :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k
        (μ.set l (Benitoite.Release.Refinement.Cell.done v)))
```

## Benitoite.Release.Refinement.Step.E_Use

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 252。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val}
  {m : Benitoite.Release.Refinement.Comp} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.use v m →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture m)
        (Benitoite.Release.Refinement.Frame.release v :: k) μ)
```

## Benitoite.Release.Refinement.Steps

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 357。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.State →
        List Benitoite.Release.Refinement.Event → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.Steps.cons

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 359。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s t u : Benitoite.Release.Refinement.State}
  {label : Option Benitoite.Release.Refinement.Event} {events : List Benitoite.Release.Refinement.Event},
  Benitoite.Release.Refinement.Step P B σ s label t →
    Benitoite.Release.Refinement.Steps P B σ t events u →
      Benitoite.Release.Refinement.Steps P B σ s (label.toList ++ events) u
```

## Benitoite.Release.Refinement.Steps.nil

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 358。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s : Benitoite.Release.Refinement.State},
  Benitoite.Release.Refinement.Steps P B σ s [] s
```

## Benitoite.Release.Refinement.Store

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 25。

```lean
Type
```

## Benitoite.Release.Refinement.Store.empty

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 27。

```lean
Benitoite.Release.Refinement.Store
```

## Benitoite.Release.Refinement.StoreOk

所在: `formal/Benitoite/Release/Refinement/StateTyping.lean`、行: 151。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.StoreTy → Benitoite.Release.Refinement.Store → Prop
```

## Benitoite.Release.Refinement.StoreOk.lazy_cell

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`、行: 24。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
    Ψ l = Option.some (Benitoite.Release.Refinement.LocTy.lazy a) →
      (∃ q,
          μ l = Option.some (Benitoite.Release.Refinement.Cell.thunk q) ∧
            Benitoite.Release.Refinement.ClosureTy P B (Benitoite.Release.Refinement.hideBuilders Ψ) [] Option.none q a
                Benitoite.Release.Refinement.Eff.empty ∧
              Benitoite.Release.Refinement.Closure.Adequate σ q) ∨
        ∃ v,
          μ l = Option.some (Benitoite.Release.Refinement.Cell.done v) ∧
            Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v a ∧ Benitoite.Release.Refinement.Val.Adequate σ v
```

## Benitoite.Release.Refinement.StoreOk.ref_cell

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`、行: 17。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
    Ψ l = Option.some (Benitoite.Release.Refinement.LocTy.ref a) →
      ∃ v,
        μ l = Option.some (Benitoite.Release.Refinement.Cell.val v) ∧
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v a.norm ∧ Benitoite.Release.Refinement.Val.Adequate σ v
```

## Benitoite.Release.Refinement.StoreReplyInputs

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 6。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.State →
        Option Benitoite.Release.Refinement.Event → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_AtError

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 97。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
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

## Benitoite.Release.Refinement.StoreReplyInputs.E_AtOk

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 89。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
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

## Benitoite.Release.Refinement.StoreReplyInputs.E_AtPrepareError

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 104。

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
      Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure
            (Benitoite.Release.Refinement.Comp.ret
              (Benitoite.Release.Refinement.Val.con shape.error
                [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                [Benitoite.Release.Refinement.Val.atError detail])))
          k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_Err

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 50。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_ErrPopUpdate

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 44。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {rs : List Benitoite.Release.ErrKind} {l : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StoreReplyInputs P B σ
    (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.update l :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.error rs k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_Exit

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 64。

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
            Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.exit n) obs))
              (Benitoite.Release.Refinement.State.exit n [] k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_ExitPopUpdate

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 45。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {n : Int} {rs : List Benitoite.Release.ErrKind} {l : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StoreReplyInputs P B σ
    (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.update l :: k) μ) Option.none
    (Benitoite.Release.Refinement.State.exit n rs k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_External

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 72。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_ExternalApply

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 69。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) ws →
    Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts ws)) k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_ExternalErr

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 76。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_Force

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 37。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run m (Benitoite.Release.Refinement.Frame.update l :: k) μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_ForceDone

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 33。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_IO

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 54。

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
            Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.val v) obs))
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_IOErr

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 59。

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
            Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some
                (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.err r) obs))
              (Benitoite.Release.Refinement.State.error [r] k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_IssuePathBases

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 84。

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
            Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ)
              (Option.some (Benitoite.Release.Refinement.Event.pathBases b σ))
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_Lazy

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 29。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m : Benitoite.Release.Refinement.Comp}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store} {l : Nat}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = m.lazyC →
    μ l = Option.none →
      Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.pure
            (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.loc l)))
          k (μ.set l (Benitoite.Release.Refinement.Cell.thunk (Benitoite.Release.Refinement.Closure.mk q.capture m))))
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_PathBasesApply

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 80。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b [] [] []) [] →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
        Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.mk q.capture (Benitoite.Release.Refinement.Comp.issuePathBases b)) k
              μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_Prim

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 46。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_RefGet

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 13。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_RefNew

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 9。

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
          Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure
                (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.loc l)))
              k (μ.set l (Benitoite.Release.Refinement.Cell.val v)))
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_RefSet

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 17。

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
        Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
          (Benitoite.Release.Refinement.State.run
            (Benitoite.Release.Refinement.Closure.pure
              (Benitoite.Release.Refinement.Comp.ret
                (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
            k (μ.set l (Benitoite.Release.Refinement.Cell.val v)))
```

## Benitoite.Release.Refinement.StoreReplyInputs.E_RefUpdate

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 22。

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
        Benitoite.Release.Refinement.StoreReplyInputs P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
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

## Benitoite.Release.Refinement.StoreReplyInputs.E_Update

所在: `formal/Benitoite/Release/Refinement/StoreReplyLeaves.lean`、行: 41。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val} {l : Nat}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store}
  {q : Benitoite.Release.Refinement.Closure},
  q.view = Benitoite.Release.Refinement.Comp.ret v →
    Benitoite.Release.Refinement.StoreReplyInputs P B σ
      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.update l :: k) μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k
        (μ.set l (Benitoite.Release.Refinement.Cell.done v)))
```

## Benitoite.Release.Refinement.StoreTy

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 472。

```lean
Type
```

## Benitoite.Release.Refinement.StoreTy.empty

所在: `formal/Benitoite/Release/Refinement/StoreTransport.lean`、行: 48。

```lean
Benitoite.Release.Refinement.StoreTy
```

## Benitoite.Release.Refinement.SubstEnv

所在: `formal/Benitoite/Release/Refinement/Context.lean`、行: 357。

```lean
Type
```

## Benitoite.Release.Refinement.TParamDecl.constraints

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 15。

```lean
Benitoite.Release.Refinement.TParamDecl → Benitoite.Release.TParam
```

## Benitoite.Release.Refinement.TParamDecl.kind

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 16。

```lean
Benitoite.Release.Refinement.TParamDecl → Benitoite.Release.Refinement.TyKind
```

## Benitoite.Release.Refinement.TargetInput

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 136。

```lean
Type
```

## Benitoite.Release.Refinement.TargetInput.absolute

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 137。

```lean
Benitoite.Scope.Domain.Target → Benitoite.Release.Refinement.TargetInput
```

## Benitoite.Release.Refinement.TargetInput.absolute.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 137。

```lean
{motive : Benitoite.Release.Refinement.TargetInput → Sort u} →
  (t : Benitoite.Release.Refinement.TargetInput) →
    t.ctorIdx = 0 →
      ((target : Benitoite.Scope.Domain.Target) → motive (Benitoite.Release.Refinement.TargetInput.absolute target)) →
        motive t
```

## Benitoite.Release.Refinement.TargetInput.absolute.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 137。

```lean
{P : Sort u} →
  {target target' : Benitoite.Scope.Domain.Target} →
    Benitoite.Release.Refinement.TargetInput.absolute target =
        Benitoite.Release.Refinement.TargetInput.absolute target' →
      (target = target' → P) → P
```

## Benitoite.Release.Refinement.TargetInput.base?

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 79。

```lean
Benitoite.Release.Refinement.TargetInput → Option Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.TargetInput.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 136。

```lean
{motive : Benitoite.Release.Refinement.TargetInput → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.TargetInput) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.TargetInput.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.TargetInput.homePath

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 139。

```lean
Benitoite.Scope.Domain.Word → Benitoite.Release.Refinement.TargetInput
```

## Benitoite.Release.Refinement.TargetInput.homePath.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 139。

```lean
{motive : Benitoite.Release.Refinement.TargetInput → Sort u} →
  (t : Benitoite.Release.Refinement.TargetInput) →
    t.ctorIdx = 2 →
      ((segments : Benitoite.Scope.Domain.Word) → motive (Benitoite.Release.Refinement.TargetInput.homePath segments)) →
        motive t
```

## Benitoite.Release.Refinement.TargetInput.homePath.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 139。

```lean
{P : Sort u} →
  {segments segments' : Benitoite.Scope.Domain.Word} →
    Benitoite.Release.Refinement.TargetInput.homePath segments =
        Benitoite.Release.Refinement.TargetInput.homePath segments' →
      (segments = segments' → P) → P
```

## Benitoite.Release.Refinement.TargetInput.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 136。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.TargetInput} →
    t = t' → Benitoite.Release.Refinement.TargetInput.noConfusionType P t t'
```

## Benitoite.Release.Refinement.TargetInput.relativePath

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 138。

```lean
Benitoite.Scope.Domain.Word → Benitoite.Release.Refinement.TargetInput
```

## Benitoite.Release.Refinement.TargetInput.relativePath.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 138。

```lean
{motive : Benitoite.Release.Refinement.TargetInput → Sort u} →
  (t : Benitoite.Release.Refinement.TargetInput) →
    t.ctorIdx = 1 →
      ((segments : Benitoite.Scope.Domain.Word) →
          motive (Benitoite.Release.Refinement.TargetInput.relativePath segments)) →
        motive t
```

## Benitoite.Release.Refinement.TargetInput.relativePath.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 138。

```lean
{P : Sort u} →
  {segments segments' : Benitoite.Scope.Domain.Word} →
    Benitoite.Release.Refinement.TargetInput.relativePath segments =
        Benitoite.Release.Refinement.TargetInput.relativePath segments' →
      (segments = segments' → P) → P
```

## Benitoite.Release.Refinement.TargetInput.resolve

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 49。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.TargetInput → Option Benitoite.Scope.Domain.Target
```

## Benitoite.Release.Refinement.TargetTable.clientRequestTy

所在: `formal/Benitoite/Release/Refinement/TargetTable.lean`、行: 11。

```lean
Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.TargetTable.content_rows

所在: `formal/Benitoite/Release/Refinement/TargetTable.lean`、行: 20。

```lean
∀ {name : Benitoite.Release.OpaqueName} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.TargetTable.valContent name = Option.some a →
    Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) a
```

## Benitoite.Release.Refinement.TargetTable.path_content

所在: `formal/Benitoite/Release/Refinement/TargetTable.lean`、行: 18。

```lean
Benitoite.Release.Refinement.TargetTable.valContent "Scope.PathIn" = Option.none
```

## Benitoite.Release.Refinement.TargetTable.request_content

所在: `formal/Benitoite/Release/Refinement/TargetTable.lean`、行: 16。

```lean
Benitoite.Release.Refinement.TargetTable.valContent "Http.RequestIn" =
  Option.some Benitoite.Release.Refinement.TargetTable.clientRequestTy
```

## Benitoite.Release.Refinement.TargetTable.valContent

所在: `formal/Benitoite/Release/Refinement/TargetTable.lean`、行: 13。

```lean
Benitoite.Release.OpaqueName → Option Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.TargetTable.valKind

所在: `formal/Benitoite/Release/Refinement/TargetTable.lean`、行: 27。

```lean
Benitoite.Release.OpaqueName → Option Benitoite.Scope.Domain.Kind
```

## Benitoite.Release.Refinement.Tel

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 83。

```lean
Type
```

## Benitoite.Release.Refinement.Tel.RowsIn

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 58。

```lean
(Nat → Prop) → Benitoite.Release.Refinement.Tel → Prop
```

## Benitoite.Release.Refinement.Tel.done

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 84。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.EffR → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.Tel.instR

所在: `formal/Benitoite/Release/Refinement/Telescope.lean`、行: 86。

```lean
List Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.TelClosure

所在: `formal/Benitoite/Release/Refinement/Le.lean`、行: 56。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Ctx →
    List Benitoite.Release.Refinement.Pred → Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.Tel → Prop
```

## Benitoite.Release.Refinement.TelClosure.apply

所在: `formal/Benitoite/Release/Refinement/TelApplication.lean`、行: 96。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {t u : Benitoite.Release.Refinement.Tel}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Ctx.WF 0 (List.length C) Γ →
    Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.dependentFn t) →
      Benitoite.Release.Refinement.TelClosure P Γ Φ t u →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
          ∃ b f,
            Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ b a ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ e f
```

## Benitoite.Release.Refinement.Term

所在: `formal/Benitoite/Release/Refinement/TermSyntax.lean`、行: 10。

```lean
Type
```

## Benitoite.Release.Refinement.Term.Declared

所在: `formal/Benitoite/Release/Refinement/Declared.lean`、行: 44。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.TypeCtx → Benitoite.Release.Refinement.Ctx → Benitoite.Release.Refinement.Term → Prop
```

## Benitoite.Release.Refinement.Term.targetValue_wf

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 90。

```lean
∀ (snapshot : Option Benitoite.Release.Refinement.PathEnv) (t : Benitoite.Scope.Domain.Target) (nv : Nat),
  Benitoite.Release.Refinement.termWF nv (Benitoite.Release.Refinement.Term.targetValue snapshot t)
```

## Benitoite.Release.Refinement.Ty

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 52。

```lean
Type
```

## Benitoite.Release.Refinement.Ty.Annotation

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 16。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.TypeCtx → Benitoite.Release.Refinement.Ctx → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.Ty.LeQ

所在: `formal/Benitoite/Release/Refinement/Le.lean`、行: 25。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Ctx →
    List Benitoite.Release.Refinement.Pred → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.Ty.LeQ.integerCarrier

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 14。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {a b : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Ty.LeQ P Γ Φ a b → (a.IntegerCarrier ↔ b.IntegerCarrier)
```

## Benitoite.Release.Refinement.Ty.TargetWF

所在: `formal/Benitoite/Release/Refinement/PrimitiveScoped.lean`、行: 6。

```lean
Nat → Nat → Nat → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.Ty.WF

所在: `formal/Benitoite/Release/Refinement/Context.lean`、行: 239。

```lean
Nat → Nat → Nat → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.Ty.base

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 56。

```lean
Benitoite.Release.BaseTy → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.bind

所在: `formal/Benitoite/Release/Refinement/Context.lean`、行: 440。

```lean
Benitoite.Release.Refinement.SubstEnv → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.data

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 58。

```lean
Benitoite.Release.DataName → List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.dependentFn

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 72。

```lean
Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.instR

所在: `formal/Benitoite/Release/Refinement/RangeSubst.lean`、行: 327。

```lean
List Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.instTarget

所在: `formal/Benitoite/Release/Refinement/HandlerContracts.lean`、行: 6。

```lean
List Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.normTys

所在: `formal/Benitoite/Release/Refinement/Normalize.lean`、行: 45。

```lean
List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.opaque

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 57。

```lean
Benitoite.Release.OpaqueName → Benitoite.Release.Refinement.RangeIx → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.pathBases

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 75。

```lean
Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.scoped

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 74。

```lean
Benitoite.Release.OpaqueName →
  Benitoite.Scope.Domain.Kind → Benitoite.Release.Refinement.RangeIx → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.subst

所在: `formal/Benitoite/Release/Refinement/TypeSubst.lean`、行: 52。

```lean
List Benitoite.Release.Refinement.Ty →
  List Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.substAt

所在: `formal/Benitoite/Release/Refinement/TypeSubst.lean`、行: 48。

```lean
Nat →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Ty.tvar

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 61。

```lean
Nat → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.TypeAnnotations

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 21。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.TypeCtx → Benitoite.Release.Refinement.Ctx → List Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.TypeCtx

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 25。

```lean
Type
```

## Benitoite.Release.Refinement.TypeCtx.kinds

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 31。

```lean
Benitoite.Release.Refinement.TypeCtx → Benitoite.Release.Refinement.KindCtx
```

## Benitoite.Release.Refinement.TypeParamRenaming

所在: `formal/Benitoite/Release/Refinement/TypeRenaming.lean`、行: 53。

```lean
Benitoite.Release.Refinement.TypeCtx → Benitoite.Release.Refinement.TypeCtx → (Nat → Nat) → Prop
```

## Benitoite.Release.Refinement.TypedValueImages

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 7。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            Benitoite.Release.Refinement.Ctx →
              List Benitoite.Release.Refinement.Pred → (Nat → Benitoite.Release.Refinement.Val) → Prop
```

## Benitoite.Release.Refinement.UnhandledOp

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 36。

```lean
Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.Val

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
Type
```

## Benitoite.Release.Refinement.Val.Adequate

所在: `formal/Benitoite/Release/Refinement/Adequate.lean`、行: 14。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.Val → Prop
```

## Benitoite.Release.Refinement.Val.Source

所在: `formal/Benitoite/Release/Refinement/Source.lean`、行: 6。

```lean
Benitoite.Release.Refinement.Val → Prop
```

## Benitoite.Release.Refinement.Val.Source.adequate

所在: `formal/Benitoite/Release/Refinement/PreparationTargets.lean`、行: 23。

```lean
∀ {v : Benitoite.Release.Refinement.Val},
  v.Source → ∀ (σ : Benitoite.Release.Refinement.PathEnv), Benitoite.Release.Refinement.Val.Adequate σ v
```

## Benitoite.Release.Refinement.Val.SourceScoped

所在: `formal/Benitoite/Release/Refinement/SourceScope.lean`、行: 41。

```lean
Nat → Nat → Nat → Nat → Benitoite.Release.Refinement.Val → Prop
```

## Benitoite.Release.Refinement.Val.atError

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 172。

```lean
Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.atError.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 172。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 22 →
      ((detail : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val) →
          motive_1 (Benitoite.Release.Refinement.Val.atError detail)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.atError.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 172。

```lean
{P : Sort u} →
  {detail detail' : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Val.atError detail = Benitoite.Release.Refinement.Val.atError detail' →
      (detail = detail' → P) → P
```

## Benitoite.Release.Refinement.Val.below_1

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          List Benitoite.Release.Refinement.Val → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.below_2

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          Option Benitoite.Release.Refinement.Val → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.below_3

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.below_4

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          List Benitoite.Release.Refinement.Arm → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.below_5

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          List Benitoite.Release.Refinement.Clause → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.below_6

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          Option Benitoite.Release.Refinement.Comp → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.below_7

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          List (Option Benitoite.Release.Refinement.Val) → Sort (max 1 u)
```

## Benitoite.Release.Refinement.Val.brecOn_1

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          (t : List Benitoite.Release.Refinement.Val) →
                            ((t : Benitoite.Release.Refinement.Val) → t.below → motive_1 t) →
                              ((t : Benitoite.Release.Refinement.Comp) → t.below → motive_2 t) →
                                ((t : Benitoite.Release.Refinement.Clause) → t.below → motive_3 t) →
                                  ((t : Benitoite.Release.Refinement.Arm) → t.below → motive_4 t) →
                                    ((t : Benitoite.Release.Refinement.Capture) → t.below → motive_5 t) →
                                      ((t : Benitoite.Release.Refinement.Closure) → t.below → motive_6 t) →
                                        ((t : List Benitoite.Release.Refinement.Val) →
                                            Benitoite.Release.Refinement.Val.below_1 t → motive_7 t) →
                                          ((t : Option Benitoite.Release.Refinement.Val) →
                                              Benitoite.Release.Refinement.Val.below_2 t → motive_8 t) →
                                            ((t :
                                                  Benitoite.Release.Refinement.Detail
                                                    Benitoite.Release.Refinement.Val) →
                                                Benitoite.Release.Refinement.Val.below_3 t → motive_9 t) →
                                              ((t : List Benitoite.Release.Refinement.Arm) →
                                                  Benitoite.Release.Refinement.Val.below_4 t → motive_10 t) →
                                                ((t : List Benitoite.Release.Refinement.Clause) →
                                                    Benitoite.Release.Refinement.Val.below_5 t → motive_11 t) →
                                                  ((t : Option Benitoite.Release.Refinement.Comp) →
                                                      Benitoite.Release.Refinement.Val.below_6 t → motive_12 t) →
                                                    ((t : List (Option Benitoite.Release.Refinement.Val)) →
                                                        Benitoite.Release.Refinement.Val.below_7 t → motive_13 t) →
                                                      motive_7 t
```

## Benitoite.Release.Refinement.Val.brecOn_2

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          (t : Option Benitoite.Release.Refinement.Val) →
                            ((t : Benitoite.Release.Refinement.Val) → t.below → motive_1 t) →
                              ((t : Benitoite.Release.Refinement.Comp) → t.below → motive_2 t) →
                                ((t : Benitoite.Release.Refinement.Clause) → t.below → motive_3 t) →
                                  ((t : Benitoite.Release.Refinement.Arm) → t.below → motive_4 t) →
                                    ((t : Benitoite.Release.Refinement.Capture) → t.below → motive_5 t) →
                                      ((t : Benitoite.Release.Refinement.Closure) → t.below → motive_6 t) →
                                        ((t : List Benitoite.Release.Refinement.Val) →
                                            Benitoite.Release.Refinement.Val.below_1 t → motive_7 t) →
                                          ((t : Option Benitoite.Release.Refinement.Val) →
                                              Benitoite.Release.Refinement.Val.below_2 t → motive_8 t) →
                                            ((t :
                                                  Benitoite.Release.Refinement.Detail
                                                    Benitoite.Release.Refinement.Val) →
                                                Benitoite.Release.Refinement.Val.below_3 t → motive_9 t) →
                                              ((t : List Benitoite.Release.Refinement.Arm) →
                                                  Benitoite.Release.Refinement.Val.below_4 t → motive_10 t) →
                                                ((t : List Benitoite.Release.Refinement.Clause) →
                                                    Benitoite.Release.Refinement.Val.below_5 t → motive_11 t) →
                                                  ((t : Option Benitoite.Release.Refinement.Comp) →
                                                      Benitoite.Release.Refinement.Val.below_6 t → motive_12 t) →
                                                    ((t : List (Option Benitoite.Release.Refinement.Val)) →
                                                        Benitoite.Release.Refinement.Val.below_7 t → motive_13 t) →
                                                      motive_8 t
```

## Benitoite.Release.Refinement.Val.brecOn_3

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          (t : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val) →
                            ((t : Benitoite.Release.Refinement.Val) → t.below → motive_1 t) →
                              ((t : Benitoite.Release.Refinement.Comp) → t.below → motive_2 t) →
                                ((t : Benitoite.Release.Refinement.Clause) → t.below → motive_3 t) →
                                  ((t : Benitoite.Release.Refinement.Arm) → t.below → motive_4 t) →
                                    ((t : Benitoite.Release.Refinement.Capture) → t.below → motive_5 t) →
                                      ((t : Benitoite.Release.Refinement.Closure) → t.below → motive_6 t) →
                                        ((t : List Benitoite.Release.Refinement.Val) →
                                            Benitoite.Release.Refinement.Val.below_1 t → motive_7 t) →
                                          ((t : Option Benitoite.Release.Refinement.Val) →
                                              Benitoite.Release.Refinement.Val.below_2 t → motive_8 t) →
                                            ((t :
                                                  Benitoite.Release.Refinement.Detail
                                                    Benitoite.Release.Refinement.Val) →
                                                Benitoite.Release.Refinement.Val.below_3 t → motive_9 t) →
                                              ((t : List Benitoite.Release.Refinement.Arm) →
                                                  Benitoite.Release.Refinement.Val.below_4 t → motive_10 t) →
                                                ((t : List Benitoite.Release.Refinement.Clause) →
                                                    Benitoite.Release.Refinement.Val.below_5 t → motive_11 t) →
                                                  ((t : Option Benitoite.Release.Refinement.Comp) →
                                                      Benitoite.Release.Refinement.Val.below_6 t → motive_12 t) →
                                                    ((t : List (Option Benitoite.Release.Refinement.Val)) →
                                                        Benitoite.Release.Refinement.Val.below_7 t → motive_13 t) →
                                                      motive_9 t
```

## Benitoite.Release.Refinement.Val.brecOn_4

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          (t : List Benitoite.Release.Refinement.Arm) →
                            ((t : Benitoite.Release.Refinement.Val) → t.below → motive_1 t) →
                              ((t : Benitoite.Release.Refinement.Comp) → t.below → motive_2 t) →
                                ((t : Benitoite.Release.Refinement.Clause) → t.below → motive_3 t) →
                                  ((t : Benitoite.Release.Refinement.Arm) → t.below → motive_4 t) →
                                    ((t : Benitoite.Release.Refinement.Capture) → t.below → motive_5 t) →
                                      ((t : Benitoite.Release.Refinement.Closure) → t.below → motive_6 t) →
                                        ((t : List Benitoite.Release.Refinement.Val) →
                                            Benitoite.Release.Refinement.Val.below_1 t → motive_7 t) →
                                          ((t : Option Benitoite.Release.Refinement.Val) →
                                              Benitoite.Release.Refinement.Val.below_2 t → motive_8 t) →
                                            ((t :
                                                  Benitoite.Release.Refinement.Detail
                                                    Benitoite.Release.Refinement.Val) →
                                                Benitoite.Release.Refinement.Val.below_3 t → motive_9 t) →
                                              ((t : List Benitoite.Release.Refinement.Arm) →
                                                  Benitoite.Release.Refinement.Val.below_4 t → motive_10 t) →
                                                ((t : List Benitoite.Release.Refinement.Clause) →
                                                    Benitoite.Release.Refinement.Val.below_5 t → motive_11 t) →
                                                  ((t : Option Benitoite.Release.Refinement.Comp) →
                                                      Benitoite.Release.Refinement.Val.below_6 t → motive_12 t) →
                                                    ((t : List (Option Benitoite.Release.Refinement.Val)) →
                                                        Benitoite.Release.Refinement.Val.below_7 t → motive_13 t) →
                                                      motive_10 t
```

## Benitoite.Release.Refinement.Val.brecOn_5

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          (t : List Benitoite.Release.Refinement.Clause) →
                            ((t : Benitoite.Release.Refinement.Val) → t.below → motive_1 t) →
                              ((t : Benitoite.Release.Refinement.Comp) → t.below → motive_2 t) →
                                ((t : Benitoite.Release.Refinement.Clause) → t.below → motive_3 t) →
                                  ((t : Benitoite.Release.Refinement.Arm) → t.below → motive_4 t) →
                                    ((t : Benitoite.Release.Refinement.Capture) → t.below → motive_5 t) →
                                      ((t : Benitoite.Release.Refinement.Closure) → t.below → motive_6 t) →
                                        ((t : List Benitoite.Release.Refinement.Val) →
                                            Benitoite.Release.Refinement.Val.below_1 t → motive_7 t) →
                                          ((t : Option Benitoite.Release.Refinement.Val) →
                                              Benitoite.Release.Refinement.Val.below_2 t → motive_8 t) →
                                            ((t :
                                                  Benitoite.Release.Refinement.Detail
                                                    Benitoite.Release.Refinement.Val) →
                                                Benitoite.Release.Refinement.Val.below_3 t → motive_9 t) →
                                              ((t : List Benitoite.Release.Refinement.Arm) →
                                                  Benitoite.Release.Refinement.Val.below_4 t → motive_10 t) →
                                                ((t : List Benitoite.Release.Refinement.Clause) →
                                                    Benitoite.Release.Refinement.Val.below_5 t → motive_11 t) →
                                                  ((t : Option Benitoite.Release.Refinement.Comp) →
                                                      Benitoite.Release.Refinement.Val.below_6 t → motive_12 t) →
                                                    ((t : List (Option Benitoite.Release.Refinement.Val)) →
                                                        Benitoite.Release.Refinement.Val.below_7 t → motive_13 t) →
                                                      motive_11 t
```

