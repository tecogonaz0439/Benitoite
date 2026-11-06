# 消去の実署名

既定環境の型を印字し、具体値を評価していない。

## Benitoite.Release.Refinement.CheckErasure.Execution

`Benitoite.Release.Refinement.CheckErasure`、行 107。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.State →
        List (Option Benitoite.Release.Refinement.Event) → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.CheckErasure.Execution.steps

`Benitoite.Release.Refinement.CheckErasure`、行 113。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s : Benitoite.Release.Refinement.State}
  {labels : List (Option Benitoite.Release.Refinement.Event)} {z : Benitoite.Release.Refinement.State},
  Benitoite.Release.Refinement.CheckErasure.Execution P B σ s labels z →
    Benitoite.Release.Refinement.Steps P B σ s (List.filterMap id labels) z
```

## Benitoite.Release.Refinement.CheckErasure.InfiniteExecution

`Benitoite.Release.Refinement.CheckErasure`、行 122。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.State → (Nat → Option Benitoite.Release.Refinement.Event) → Prop
```

## Benitoite.Release.Refinement.CheckErasure.call

`Benitoite.Release.Refinement.CheckErasure`、行 9。

```lean
Benitoite.Release.Refinement.Ty →
  Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.CheckErasure.call_typed

`Benitoite.Release.Refinement.CheckErasure`、行 60。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {t u : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx},
  B.sig Benitoite.Release.Refinement.PublicNames.checkName =
      Option.some Benitoite.Release.Refinement.RefinementCheck.signature →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ Benitoite.Release.Refinement.PublicNames.checkName
        Benitoite.Release.Refinement.RefinementCheck.signature [t, u] [] [] [v]
        (Benitoite.Release.Refinement.RefinementCheck.result u) Benitoite.Release.Refinement.Eff.empty →
      Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty [] [] [] R
        (Benitoite.Release.Refinement.CheckErasure.call t u v) (Benitoite.Release.Refinement.RefinementCheck.result u)
        Benitoite.Release.Refinement.Eff.empty Δ
```

## Benitoite.Release.Refinement.CheckErasure.erase

`Benitoite.Release.Refinement.CheckErasure`、行 13。

```lean
Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.CheckErasure.erase_check

`Benitoite.Release.Refinement.CheckErasure`、行 25。

```lean
∀ {t u : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.CheckErasure.call t u v)).view =
      Benitoite.Release.Refinement.CheckErasure.call t u v →
    t.norm = t →
      u.norm = u →
        t.core = u.core →
          Benitoite.Release.Refinement.RefinementCheck.accepts v u = Bool.true →
            Benitoite.Release.Refinement.CheckErasure.erase (Benitoite.Release.Refinement.CheckErasure.call t u v) =
              Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.RefinementCheck.ok u v)
```

## Benitoite.Release.Refinement.CheckErasure.erase_refined_rejected

`Benitoite.Release.Refinement.CheckErasure`、行 37。

```lean
∀ {t a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {sort : Benitoite.Release.Refinement.Sort} {term : Benitoite.Release.Refinement.Term},
  a.sort? = Option.some sort →
    v.toTerm? = Option.some term →
      (p.open term).evalClosed = Option.some Bool.false ∨ (p.open term).evalClosed = Option.none →
        Benitoite.Release.Refinement.CheckErasure.erase
            (Benitoite.Release.Refinement.CheckErasure.call t (a.refined p) v) =
          Benitoite.Release.Refinement.CheckErasure.call t (a.refined p) v
```

## Benitoite.Release.Refinement.CheckErasure.erase_rejected

`Benitoite.Release.Refinement.CheckErasure`、行 33。

```lean
∀ {t u : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.RefinementCheck.accepts v u = Bool.false →
    Benitoite.Release.Refinement.CheckErasure.erase (Benitoite.Release.Refinement.CheckErasure.call t u v) =
      Benitoite.Release.Refinement.CheckErasure.call t u v
```

## Benitoite.Release.Refinement.CheckErasure.erase_typed

`Benitoite.Release.Refinement.CheckErasure`、行 70。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {t u : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx},
  Benitoite.Release.Refinement.RefinementCheck.Declarations P →
    ∀ (render : Benitoite.Release.Refinement.Ty → String),
      B.sig Benitoite.Release.Refinement.PublicNames.checkName =
          Option.some Benitoite.Release.Refinement.RefinementCheck.signature →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ Benitoite.Release.Refinement.PublicNames.checkName
            Benitoite.Release.Refinement.RefinementCheck.signature [t, u] [] [] [v]
            (Benitoite.Release.Refinement.RefinementCheck.result u) Benitoite.Release.Refinement.Eff.empty →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty [] [] [] R
              (Benitoite.Release.Refinement.CheckErasure.call t u v)
              (Benitoite.Release.Refinement.RefinementCheck.result u) Benitoite.Release.Refinement.Eff.empty Δ ∧
            Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty [] [] [] R
              (Benitoite.Release.Refinement.CheckErasure.erase (Benitoite.Release.Refinement.CheckErasure.call t u v))
              (Benitoite.Release.Refinement.RefinementCheck.result u) Benitoite.Release.Refinement.Eff.empty Δ
```

## Benitoite.Release.Refinement.CheckErasure.erased_step

`Benitoite.Release.Refinement.CheckErasure`、行 46。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {t u : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {render : Benitoite.Release.Refinement.Ty → String},
  q.view = Benitoite.Release.Refinement.CheckErasure.call t u v →
    B.sig Benitoite.Release.Refinement.PublicNames.checkName =
        Option.some Benitoite.Release.Refinement.RefinementCheck.signature →
      B.delta Benitoite.Release.Refinement.PublicNames.checkName [t, u] [] [] [v] =
          Benitoite.Release.Refinement.RefinementCheck.delta render Benitoite.Release.Refinement.PublicNames.checkName
            [t, u] [] [] [v] →
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.CheckErasure.call t u v)).view =
            Benitoite.Release.Refinement.CheckErasure.call t u v →
          t.norm = t →
            u.norm = u →
              t.core = u.core →
                Benitoite.Release.Refinement.RefinementCheck.accepts v u = Bool.true →
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure
                        (Benitoite.Release.Refinement.CheckErasure.erase
                          (Benitoite.Release.Refinement.CheckErasure.call t u v)))
                      k μ)
```

## Benitoite.Release.Refinement.CheckErasure.integer_observations

`Benitoite.Release.Refinement.CheckErasureExamples`、行 70。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (σ : Benitoite.Release.Refinement.PathEnv)
  (k : Benitoite.Release.Refinement.Cont) (μ : Benitoite.Release.Refinement.Store),
  have v :=
    Benitoite.Release.Refinement.Val.const
      (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩);
  have source :=
    Benitoite.Release.Refinement.State.run
      (Benitoite.Release.Refinement.Closure.pure
        (Benitoite.Release.Refinement.CheckErasure.call
          (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
          Benitoite.Release.Refinement.RefinementCheck.nonnegative v))
      k μ;
  have target :=
    Benitoite.Release.Refinement.State.run
      (Benitoite.Release.Refinement.Closure.pure
        (Benitoite.Release.Refinement.Comp.ret
          (Benitoite.Release.Refinement.RefinementCheck.ok Benitoite.Release.Refinement.RefinementCheck.nonnegative v)))
      k μ;
  (∀ (events : List Benitoite.Release.Refinement.Event) (z : Benitoite.Release.Refinement.State),
      z.Final →
        (Benitoite.Release.Refinement.Steps P (Benitoite.Release.Refinement.StandardModel.builtins P) σ source events
            z ↔
          Benitoite.Release.Refinement.Steps P (Benitoite.Release.Refinement.StandardModel.builtins P) σ target events
            z)) ∧
    Benitoite.Release.Refinement.Steps P (Benitoite.Release.Refinement.StandardModel.builtins P) σ source [] target
```

## Benitoite.Release.Refinement.CheckErasure.integer_witnesses

`Benitoite.Release.Refinement.CheckErasureExamples`、行 20。

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  have P := Benitoite.Release.Refinement.StandardModel.program externals;
  have B := Benitoite.Release.Refinement.StandardModel.builtins P;
  have yes :=
    Benitoite.Release.Refinement.Val.const
      (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩);
  have no :=
    Benitoite.Release.Refinement.Val.const
      (Benitoite.Release.Refinement.Const.integer ⟨-1, of_decide_eq_true (id (Eq.refl Bool.true))⟩);
  Benitoite.Release.Refinement.BuiltinArgs P B Benitoite.Release.Refinement.StoreTy.empty
      Benitoite.Release.Refinement.PublicNames.checkName Benitoite.Release.Refinement.RefinementCheck.signature
      [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer,
        Benitoite.Release.Refinement.RefinementCheck.nonnegative]
      [] [] [yes]
      (Benitoite.Release.Refinement.RefinementCheck.result Benitoite.Release.Refinement.RefinementCheck.nonnegative)
      Benitoite.Release.Refinement.Eff.empty ∧
    Benitoite.Release.Refinement.BuiltinArgs P B Benitoite.Release.Refinement.StoreTy.empty
        Benitoite.Release.Refinement.PublicNames.checkName Benitoite.Release.Refinement.RefinementCheck.signature
        [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer,
          Benitoite.Release.Refinement.RefinementCheck.nonnegative]
        [] [] [no]
        (Benitoite.Release.Refinement.RefinementCheck.result Benitoite.Release.Refinement.RefinementCheck.nonnegative)
        Benitoite.Release.Refinement.Eff.empty ∧
      Benitoite.Release.Refinement.CheckErasure.erase
            (Benitoite.Release.Refinement.CheckErasure.call
              (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
              Benitoite.Release.Refinement.RefinementCheck.nonnegative yes) =
          Benitoite.Release.Refinement.Comp.ret
            (Benitoite.Release.Refinement.RefinementCheck.ok Benitoite.Release.Refinement.RefinementCheck.nonnegative
              yes) ∧
        Benitoite.Release.Refinement.CheckErasure.erase
              (Benitoite.Release.Refinement.CheckErasure.call
                (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
                Benitoite.Release.Refinement.RefinementCheck.nonnegative no) =
            Benitoite.Release.Refinement.CheckErasure.call
              (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
              Benitoite.Release.Refinement.RefinementCheck.nonnegative no ∧
          Benitoite.Release.Refinement.HasTypeCQ P B Benitoite.Release.Refinement.StoreTy.empty Benitoite.Release.Qempty
              [] [] [] Option.none
              (Benitoite.Release.Refinement.CheckErasure.erase
                (Benitoite.Release.Refinement.CheckErasure.call
                  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
                  Benitoite.Release.Refinement.RefinementCheck.nonnegative yes))
              (Benitoite.Release.Refinement.RefinementCheck.result
                Benitoite.Release.Refinement.RefinementCheck.nonnegative)
              Benitoite.Release.Refinement.Eff.empty ∧
            Benitoite.Release.Refinement.HasTypeCQ P B Benitoite.Release.Refinement.StoreTy.empty
                Benitoite.Release.Qempty [] [] [] Option.none
                (Benitoite.Release.Refinement.CheckErasure.erase
                  (Benitoite.Release.Refinement.CheckErasure.call
                    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer)
                    Benitoite.Release.Refinement.RefinementCheck.nonnegative no))
                (Benitoite.Release.Refinement.RefinementCheck.result
                  Benitoite.Release.Refinement.RefinementCheck.nonnegative)
                Benitoite.Release.Refinement.Eff.empty ∧
              Benitoite.Release.Refinement.RefinementCheck.delta
                  Benitoite.Release.Refinement.StandardModel.checkExpectedText
                  Benitoite.Release.Refinement.PublicNames.checkName
                  [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer,
                    Benitoite.Release.Refinement.RefinementCheck.nonnegative]
                  [] [] [no] =
                Option.some
                  (Benitoite.Release.Refinement.Outcome.val
                    (Benitoite.Release.Refinement.RefinementCheck.rejected
                      Benitoite.Release.Refinement.RefinementCheck.nonnegative
                      (Benitoite.Release.Refinement.StandardModel.checkExpectedText
                        Benitoite.Release.Refinement.RefinementCheck.nonnegative)))
```

## Benitoite.Release.Refinement.CheckErasure.observations_preserved

`Benitoite.Release.Refinement.CheckErasure`、行 127。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {t u : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {render : Benitoite.Release.Refinement.Ty → String},
  q.view = Benitoite.Release.Refinement.CheckErasure.call t u v →
    B.sig Benitoite.Release.Refinement.PublicNames.checkName =
        Option.some Benitoite.Release.Refinement.RefinementCheck.signature →
      B.delta Benitoite.Release.Refinement.PublicNames.checkName [t, u] [] [] [v] =
          Benitoite.Release.Refinement.RefinementCheck.delta render Benitoite.Release.Refinement.PublicNames.checkName
            [t, u] [] [] [v] →
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.CheckErasure.call t u v)).view =
            Benitoite.Release.Refinement.CheckErasure.call t u v →
          t.norm = t →
            u.norm = u →
              t.core = u.core →
                Benitoite.Release.Refinement.RefinementCheck.accepts v u = Bool.true →
                  have source := Benitoite.Release.Refinement.State.run q k μ;
                  have target :=
                    Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure
                        (Benitoite.Release.Refinement.CheckErasure.erase
                          (Benitoite.Release.Refinement.CheckErasure.call t u v)))
                      k μ;
                  (∀ (labels : List (Option Benitoite.Release.Refinement.Event))
                      (z : Benitoite.Release.Refinement.State),
                      Benitoite.Release.Refinement.CheckErasure.Execution P B σ source (Option.none :: labels) z ↔
                        Benitoite.Release.Refinement.CheckErasure.Execution P B σ target labels z) ∧
                    (∀ (events : List Benitoite.Release.Refinement.Event) (z : Benitoite.Release.Refinement.State),
                        z.Final →
                          (Benitoite.Release.Refinement.Steps P B σ source events z ↔
                            Benitoite.Release.Refinement.Steps P B σ target events z)) ∧
                      ∀ (labels : Nat → Option Benitoite.Release.Refinement.Event),
                        (Benitoite.Release.Refinement.CheckErasure.InfiniteExecution P B σ source fun n =>
                            match n with
                            | 0 => Option.none
                            | n.succ => labels n) ↔
                          Benitoite.Release.Refinement.CheckErasure.InfiniteExecution P B σ target labels
```

## Benitoite.Release.Refinement.CheckErasure.standard_agreement

`Benitoite.Release.Refinement.CheckErasureExamples`、行 9。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (t u : Benitoite.Release.Refinement.Ty)
  (v : Benitoite.Release.Refinement.Val),
  (Benitoite.Release.Refinement.StandardModel.builtins P).sig Benitoite.Release.Refinement.PublicNames.checkName =
      Option.some Benitoite.Release.Refinement.RefinementCheck.signature ∧
    (Benitoite.Release.Refinement.StandardModel.builtins P).delta Benitoite.Release.Refinement.PublicNames.checkName
        [t, u] [] [] [v] =
      Benitoite.Release.Refinement.RefinementCheck.delta Benitoite.Release.Refinement.StandardModel.checkExpectedText
        Benitoite.Release.Refinement.PublicNames.checkName [t, u] [] [] [v]
```

## Benitoite.Release.Refinement.CheckErasure.step_unique

`Benitoite.Release.Refinement.CheckErasure`、行 89。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {t u : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {render : Benitoite.Release.Refinement.Ty → String} {label : Option Benitoite.Release.Refinement.Event}
  {dest : Benitoite.Release.Refinement.State},
  q.view = Benitoite.Release.Refinement.CheckErasure.call t u v →
    B.sig Benitoite.Release.Refinement.PublicNames.checkName =
        Option.some Benitoite.Release.Refinement.RefinementCheck.signature →
      B.delta Benitoite.Release.Refinement.PublicNames.checkName [t, u] [] [] [v] =
          Benitoite.Release.Refinement.RefinementCheck.delta render Benitoite.Release.Refinement.PublicNames.checkName
            [t, u] [] [] [v] →
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.CheckErasure.call t u v)).view =
            Benitoite.Release.Refinement.CheckErasure.call t u v →
          t.norm = t →
            u.norm = u →
              t.core = u.core →
                Benitoite.Release.Refinement.RefinementCheck.accepts v u = Bool.true →
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) label dest →
                    label = Option.none ∧
                      dest =
                        Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.pure
                            (Benitoite.Release.Refinement.CheckErasure.erase
                              (Benitoite.Release.Refinement.CheckErasure.call t u v)))
                          k μ
```

## Benitoite.Release.Refinement.CheckErasure.undecided_witness

`Benitoite.Release.Refinement.CheckErasureExamples`、行 48。

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  have P := Benitoite.Release.Refinement.StandardModel.program externals;
  have B := Benitoite.Release.Refinement.StandardModel.builtins P;
  Benitoite.Release.Refinement.BuiltinArgs P B Benitoite.Release.Refinement.StoreTy.empty
      Benitoite.Release.Refinement.PublicNames.checkName Benitoite.Release.Refinement.RefinementCheck.signature
      [Benitoite.Release.Refinement.RefinementCheck.OptionField.carrier,
        Benitoite.Release.Refinement.RefinementCheck.OptionField.expected]
      [] [] [Benitoite.Release.Refinement.RefinementCheck.OptionField.absent]
      (Benitoite.Release.Refinement.RefinementCheck.result
        Benitoite.Release.Refinement.RefinementCheck.OptionField.expected)
      Benitoite.Release.Refinement.Eff.empty ∧
    (Benitoite.Release.Refinement.RefinementCheck.OptionField.predicate.open
            (Benitoite.Release.Refinement.Term.dataValue "Option.None" [])).evalClosed =
        Option.none ∧
      Benitoite.Release.Refinement.CheckErasure.erase
            (Benitoite.Release.Refinement.CheckErasure.call
              Benitoite.Release.Refinement.RefinementCheck.OptionField.carrier
              Benitoite.Release.Refinement.RefinementCheck.OptionField.expected
              Benitoite.Release.Refinement.RefinementCheck.OptionField.absent) =
          Benitoite.Release.Refinement.CheckErasure.call
            Benitoite.Release.Refinement.RefinementCheck.OptionField.carrier
            Benitoite.Release.Refinement.RefinementCheck.OptionField.expected
            Benitoite.Release.Refinement.RefinementCheck.OptionField.absent ∧
        Benitoite.Release.Refinement.HasTypeCQ P B Benitoite.Release.Refinement.StoreTy.empty Benitoite.Release.Qempty
            [] [] [] Option.none
            (Benitoite.Release.Refinement.CheckErasure.erase
              (Benitoite.Release.Refinement.CheckErasure.call
                Benitoite.Release.Refinement.RefinementCheck.OptionField.carrier
                Benitoite.Release.Refinement.RefinementCheck.OptionField.expected
                Benitoite.Release.Refinement.RefinementCheck.OptionField.absent))
            (Benitoite.Release.Refinement.RefinementCheck.result
              Benitoite.Release.Refinement.RefinementCheck.OptionField.expected)
            Benitoite.Release.Refinement.Eff.empty ∧
          Benitoite.Release.Refinement.RefinementCheck.delta
              Benitoite.Release.Refinement.StandardModel.checkExpectedText
              Benitoite.Release.Refinement.PublicNames.checkName
              [Benitoite.Release.Refinement.RefinementCheck.OptionField.carrier,
                Benitoite.Release.Refinement.RefinementCheck.OptionField.expected]
              [] [] [Benitoite.Release.Refinement.RefinementCheck.OptionField.absent] =
            Option.some
              (Benitoite.Release.Refinement.Outcome.val
                (Benitoite.Release.Refinement.RefinementCheck.rejected
                  Benitoite.Release.Refinement.RefinementCheck.OptionField.expected
                  (Benitoite.Release.Refinement.StandardModel.checkExpectedText
                    Benitoite.Release.Refinement.RefinementCheck.OptionField.expected)))
```

