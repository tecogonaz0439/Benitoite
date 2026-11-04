# 段末の実署名（続き）

## Benitoite.Release.Refinement.FieldRef.owner

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 200。

```lean
Benitoite.Release.Refinement.FieldRef → Benitoite.Release.DataName
```

## Benitoite.Release.Refinement.FieldRef.position

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 202。

```lean
Benitoite.Release.Refinement.FieldRef → Nat
```

## Benitoite.Release.Refinement.FieldRef.result

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 203。

```lean
Benitoite.Release.Refinement.FieldRef → Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.FloatClass

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 224。

```lean
Type
```

## Benitoite.Release.Refinement.FloatClass.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 224。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.FloatClass) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.FloatClass.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.FloatClass.finite

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
Benitoite.Release.Refinement.FloatClass
```

## Benitoite.Release.Refinement.FloatClass.finite.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (t : Benitoite.Release.Refinement.FloatClass) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.FloatClass.finite → motive t
```

## Benitoite.Release.Refinement.FloatClass.nan

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
Benitoite.Release.Refinement.FloatClass
```

## Benitoite.Release.Refinement.FloatClass.nan.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (t : Benitoite.Release.Refinement.FloatClass) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.FloatClass.nan → motive t
```

## Benitoite.Release.Refinement.FloatClass.negativeInfinity

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
Benitoite.Release.Refinement.FloatClass
```

## Benitoite.Release.Refinement.FloatClass.negativeInfinity.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (t : Benitoite.Release.Refinement.FloatClass) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.FloatClass.negativeInfinity → motive t
```

## Benitoite.Release.Refinement.FloatClass.negativeZero

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
Benitoite.Release.Refinement.FloatClass
```

## Benitoite.Release.Refinement.FloatClass.negativeZero.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (t : Benitoite.Release.Refinement.FloatClass) →
    t.ctorIdx = 5 → motive Benitoite.Release.Refinement.FloatClass.negativeZero → motive t
```

## Benitoite.Release.Refinement.FloatClass.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 224。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.FloatClass} →
    x = y → Benitoite.Release.Refinement.FloatClass.noConfusionType P x y
```

## Benitoite.Release.Refinement.FloatClass.positiveInfinity

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
Benitoite.Release.Refinement.FloatClass
```

## Benitoite.Release.Refinement.FloatClass.positiveInfinity.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (t : Benitoite.Release.Refinement.FloatClass) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.FloatClass.positiveInfinity → motive t
```

## Benitoite.Release.Refinement.FloatClass.positiveZero

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
Benitoite.Release.Refinement.FloatClass
```

## Benitoite.Release.Refinement.FloatClass.positiveZero.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 225。

```lean
{motive : Benitoite.Release.Refinement.FloatClass → Sort u} →
  (t : Benitoite.Release.Refinement.FloatClass) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.FloatClass.positiveZero → motive t
```

## Benitoite.Release.Refinement.FloatWidth

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 227。

```lean
Type
```

## Benitoite.Release.Refinement.FloatWidth.binary32

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 228。

```lean
Benitoite.Release.Refinement.FloatWidth
```

## Benitoite.Release.Refinement.FloatWidth.binary32.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 228。

```lean
{motive : Benitoite.Release.Refinement.FloatWidth → Sort u} →
  (t : Benitoite.Release.Refinement.FloatWidth) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.FloatWidth.binary32 → motive t
```

## Benitoite.Release.Refinement.FloatWidth.binary64

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 228。

```lean
Benitoite.Release.Refinement.FloatWidth
```

## Benitoite.Release.Refinement.FloatWidth.binary64.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 228。

```lean
{motive : Benitoite.Release.Refinement.FloatWidth → Sort u} →
  (t : Benitoite.Release.Refinement.FloatWidth) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.FloatWidth.binary64 → motive t
```

## Benitoite.Release.Refinement.FloatWidth.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 227。

```lean
{motive : Benitoite.Release.Refinement.FloatWidth → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.FloatWidth) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.FloatWidth.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.FloatWidth.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 227。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.FloatWidth} →
    x = y → Benitoite.Release.Refinement.FloatWidth.noConfusionType P x y
```

## Benitoite.Release.Refinement.Frame.drop

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 12。

```lean
Nat → Benitoite.Release.Refinement.Frame
```

## Benitoite.Release.Refinement.Frame.handleF

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 11。

```lean
Benitoite.Release.Refinement.Capture → List Benitoite.Release.Refinement.Clause → Benitoite.Release.Refinement.Frame
```

## Benitoite.Release.Refinement.HasTypeC

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 589。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.Refinement.TypeCtx →
        Benitoite.Release.Refinement.Ctx →
          List Benitoite.Release.Refinement.Pred →
            Option Benitoite.Release.Refinement.Ty →
              Benitoite.Release.Refinement.Comp →
                Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.HasTypeCQ

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 266。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Option Benitoite.Release.Refinement.Ty →
                Benitoite.Release.Refinement.Comp →
                  Benitoite.Release.Refinement.Ty →
                    Benitoite.Release.Refinement.Eff → optParam Benitoite.Release.Refinement.LocalCtx [] → Prop
```

## Benitoite.Release.Refinement.HasTypeCQ.inv_resumeL

所在: `formal/Benitoite/Release/Refinement/ComputationInputs.lean`、行: 171。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {R : Option Benitoite.Release.Refinement.Ty} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {outEff : Benitoite.Release.Refinement.Eff} {l : Nat} {v : Benitoite.Release.Refinement.Val}
  {code : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ →
    code = Benitoite.Release.Refinement.Comp.resume (Benitoite.Release.Refinement.Val.loc l) v →
      (∃ b t ε,
          Ψ l = Option.some (Benitoite.Release.Refinement.LocTy.cont b t ε R) ∧
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v b ∧
              Benitoite.Release.Refinement.Ty.Declared P C Γ t ∧
                Benitoite.Release.Refinement.Ty.LeQ P Γ Φ t T ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ outEff ε) ∨
        ∃ R' b t ε,
          Ψ l = Option.some (Benitoite.Release.Refinement.LocTy.cont b t ε R') ∧
            Option.map Benitoite.Release.Refinement.Ty.norm R' = Option.map Benitoite.Release.Refinement.Ty.norm R ∧
              Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v b.norm ∧
                Benitoite.Release.Refinement.Ty.Declared P C Γ t.norm ∧
                  Benitoite.Release.Refinement.Ty.LeQ P Γ Φ t.norm T ∧
                    Benitoite.Release.Refinement.Eff.Covers Γ Φ outEff ε.norm
```

## Benitoite.Release.Refinement.HasTypeEachQ.member

所在: `formal/Benitoite/Release/Refinement/ValueFacts.lean`、行: 80。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a →
    v ∈ vs → Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a
```

## Benitoite.Release.Refinement.HasTypeEachQ.observation_declared

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 99。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeEachQ P B store Q C Γ Φ vs a →
    Benitoite.Release.Refinement.declaredSlots P C Γ (Benitoite.Release.Refinement.Val.toTermSlots vs)
```

## Benitoite.Release.Refinement.HasTypeEachQ.observation_references

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 143。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeEachQ P B store Q C Γ Φ vs a →
    Benitoite.Release.Refinement.varsInSlots Γ.Readable (Benitoite.Release.Refinement.Val.toTermSlots vs)
```

## Benitoite.Release.Refinement.HasTypeTelArgsQ

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 369。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              List Benitoite.Release.Refinement.Val →
                Benitoite.Release.Refinement.Tel →
                  Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.HasTypeV

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 586。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.Refinement.TypeCtx →
        Benitoite.Release.Refinement.Ctx →
          List Benitoite.Release.Refinement.Pred →
            Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.HasTypeVQ

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 146。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.HasTypeVQ.assume

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 249。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    ∀ (p : Benitoite.Release.Refinement.Pred),
      p ∈ a.assume →
        Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ)
          (p.open (v.toTerm?.getD (Benitoite.Release.Refinement.Term.integer 0)))
```

## Benitoite.Release.Refinement.HasTypeVQ.assume_optional

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 291。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    ∀ (p : Benitoite.Release.Refinement.Pred),
      p ∈ a.assume → Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ) (p.openOptional v.toTerm?)
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_held

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`、行: 435。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName}
  {kind : Benitoite.Scope.Domain.Kind} {ix : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.Holds o kind ix →
      (∃ o payload, v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o payload)) ∨
        (∃ target, v = Benitoite.Release.Refinement.Val.checked target) ∨
          (∃ target req, v = Benitoite.Release.Refinement.Val.checkedRequest target req) ∨
            ∃ r snapshot target req, v = Benitoite.Release.Refinement.Val.checkedAt r snapshot target req
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_opaque

所在: `formal/Benitoite/Release/Refinement/MembershipWiden.lean`、行: 19。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName} {ix : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v (Benitoite.Release.Refinement.Ty.opaque o ix) →
    (∃ n,
        v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o n) ∧
          ix = Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top) ∨
      ∃ k,
        B.valKind o = Option.some k ∧
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v (Benitoite.Release.Refinement.Ty.scoped o k ix)
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_target

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 92。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = Option.some k →
        Benitoite.Release.Refinement.Val.Adequate σ v →
          ∃ t,
            v.target? = Option.some t ∧
              Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                (v = Benitoite.Release.Refinement.Val.checked t ∨
                  (∃ req, v = Benitoite.Release.Refinement.Val.checkedRequest t req) ∨
                    ∃ s snapshot req, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot t req)
```

## Benitoite.Release.Refinement.HasTypeVQ.carrierFacts

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 334。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    ∀ (p : Benitoite.Release.Refinement.Pred),
      p ∈ a.carrierFacts →
        Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ)
          (p.open (v.toTerm?.getD (Benitoite.Release.Refinement.Term.integer 0)))
```

## Benitoite.Release.Refinement.HasTypeVQ.checkedAt_subst

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 71。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {t : Benitoite.Scope.Domain.Target} {req : Option Benitoite.Release.Refinement.Val}
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ : Nat → Benitoite.Release.LocalRef),
  Benitoite.Release.Refinement.CheckedWitness P B Ψ o k r snapshot t req →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ
      (Benitoite.Release.Refinement.Val.subst ν (Benitoite.Release.Refinement.Val.checkedAt r snapshot t req) ρ)
      (Benitoite.Release.Refinement.substTyValues ν
        (Benitoite.Release.Refinement.Ty.scoped o k (Benitoite.Release.Refinement.RangeIx.fixed r)))
```

## Benitoite.Release.Refinement.HasTypeVQ.checkedRequest_opaque

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 33。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {o : Benitoite.Release.OpaqueName} {r : Benitoite.Scope.Domain.Range}
  {t : Benitoite.Scope.Domain.Target} {req : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty},
  B.valKind o = Option.some Benitoite.Scope.Domain.Kind.endpoint →
    B.valContent o = Option.some T →
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req T →
        Benitoite.Release.Refinement.groundVal req = Bool.true →
          req.reqTarget = Option.some t →
            Benitoite.Scope.Domain.Range.MemK Benitoite.Scope.Domain.Kind.endpoint r t →
              Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ
                (Benitoite.Release.Refinement.Val.checkedRequest t req)
                (Benitoite.Release.Refinement.Ty.opaque o
                  (Benitoite.Release.Refinement.RangeIx.fixed (Benitoite.Release.Refinement.RangeExpr.absolute r)))
```

## Benitoite.Release.Refinement.HasTypeVQ.checked_opaque

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 27。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Scope.Domain.Range} {t : Benitoite.Scope.Domain.Target},
  B.valKind o = Option.some k →
    B.valContent o = Option.none →
      Benitoite.Scope.Domain.Range.MemK k r t →
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.checked t)
          (Benitoite.Release.Refinement.Ty.opaque o
            (Benitoite.Release.Refinement.RangeIx.fixed (Benitoite.Release.Refinement.RangeExpr.absolute r)))
```

## Benitoite.Release.Refinement.HasTypeVQ.con_field

所在: `formal/Benitoite/Release/Refinement/ValueFacts.lean`、行: 140。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {c : Benitoite.Release.ConName}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {cd : Benitoite.Release.Refinement.ConDecl} {i : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.con c ts vs) T →
    P.cons c = Option.some cd →
      cd.args[i]? = Option.some a →
        ∃ v,
          vs[i]? = Option.some v ∧
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v (Benitoite.Release.Refinement.Ty.subst ts [] a)
```

## Benitoite.Release.Refinement.HasTypeVQ.data_observation

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 34。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {d : Benitoite.Release.DataName} {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    a.norm.core = Benitoite.Release.Refinement.Ty.data d ts →
      ∀ {t : Benitoite.Release.Refinement.Term},
        v.toTerm? = Option.some t → Benitoite.Release.Refinement.Term.HasData P Γ t d ts
```

## Benitoite.Release.Refinement.HasTypeVQ.integer_observation

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 195。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    a.IntegerCarrier → ∃ t, v.toTerm? = Option.some t ∧ Benitoite.Release.Refinement.termSorted Γ t
```

## Benitoite.Release.Refinement.HasTypeVQ.list_element_facts

所在: `formal/Benitoite/Release/Refinement/ValueFacts.lean`、行: 160。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {b : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.list vs) T →
    T.listCore = Option.some b →
      v ∈ vs →
        v.toTerm? = Option.some t →
          ∀ (p : Benitoite.Release.Refinement.Pred),
            p ∈ b.assume → Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ) (p.open t)
```

## Benitoite.Release.Refinement.HasTypeVQ.observation

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 160。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {sort : Benitoite.Release.Refinement.Sort},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    a.HasSort sort → ∃ t, v.toTerm? = Option.some t ∧ Benitoite.Release.Refinement.Term.HasSort Γ t sort
```

## Benitoite.Release.Refinement.HasTypeVQ.observation_declared

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 66。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    ∀ {t : Benitoite.Release.Refinement.Term},
      v.toTerm? = Option.some t → Benitoite.Release.Refinement.Term.Declared P C Γ t
```

## Benitoite.Release.Refinement.HasTypeVQ.observation_references

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 113。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a →
    ∀ {t : Benitoite.Release.Refinement.Term},
      v.toTerm? = Option.some t → Benitoite.Release.Refinement.Term.References Γ t
```

## Benitoite.Release.Refinement.HasTypeVQ.reference_cell_inputs

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`、行: 71。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.refCore = Option.some a →
      Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
        ∃ l b w,
          v = Benitoite.Release.Refinement.Val.loc l ∧
            Ψ l = Option.some (Benitoite.Release.Refinement.LocTy.ref b) ∧
              b.norm = a.norm ∧
                μ l = Option.some (Benitoite.Release.Refinement.Cell.val w) ∧
                  Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] w a.norm ∧
                    Benitoite.Release.Refinement.Val.Adequate σ w
```

## Benitoite.Release.Refinement.HasTypeVQ.request_form

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 136。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {r : Benitoite.Release.Refinement.RangeExpr}
  {σ : Benitoite.Release.Refinement.PathEnv} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o Benitoite.Scope.Domain.Kind.endpoint (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = Option.some Benitoite.Scope.Domain.Kind.endpoint →
        B.valContent o = Option.some A →
          Benitoite.Release.Refinement.Val.Adequate σ v →
            ∃ target req,
              v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (Option.some req)
```

## Benitoite.Release.Refinement.HasTypeVQ.request_target

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 152。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {r : Benitoite.Release.Refinement.RangeExpr}
  {σ : Benitoite.Release.Refinement.PathEnv} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o Benitoite.Scope.Domain.Kind.endpoint (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = Option.some Benitoite.Scope.Domain.Kind.endpoint →
        B.valContent o = Option.some A →
          Benitoite.Release.Refinement.Val.Adequate σ v →
            ∃ target req,
              (v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                  ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (Option.some req)) ∧
                Benitoite.Release.Refinement.ModelHttp.valueRun [v] = Benitoite.Release.Refinement.Outcome.val req ∧
                  Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                    Benitoite.Release.Refinement.groundVal req = Bool.true ∧
                      req.reqTarget = Option.some target ∧
                        Benitoite.Release.Refinement.RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.endpoint r target
```

## Benitoite.Release.Refinement.HasTypeVQ.target_member

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 18。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = Option.some k →
        Benitoite.Release.Refinement.Val.Adequate σ v →
          ∃ t, v.target? = Option.some t ∧ Benitoite.Release.Refinement.RangeExpr.Mem σ k r t
```

## Benitoite.Release.Refinement.HasTypeVQ.target_member_interpret

所在: `formal/Benitoite/Release/Refinement/MembershipTargets.lean`、行: 109。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv}
  {η : Benitoite.Release.Refinement.ObservationEnvModel} {a : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = Option.some k →
        Benitoite.Release.Refinement.Val.Adequate σ v →
          σ.Valid →
            (∀ (t : Benitoite.Scope.Domain.Target),
                v.target? = Option.some t →
                  Benitoite.Release.Refinement.observeAs η (Benitoite.Release.Refinement.Sort.target k) a =
                    Benitoite.Release.Refinement.Observation.targetValue (Option.some σ) t) →
              ∃ t,
                v.target? = Option.some t ∧
                  Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                    Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a r) =
                      Bool.true
```

## Benitoite.Release.Refinement.HasTypeVQ.toTerm_of_integerCarrier

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 199。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B store Q C Γ Φ v a → a.IntegerCarrier → ∃ t, v.toTerm? = Option.some t
```

## Benitoite.Release.Refinement.HasTypeVQ.widen_instTarget_covers

所在: `formal/Benitoite/Release/Refinement/MembershipWiden.lean`、行: 65。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {p : Benitoite.Release.Refinement.Ty}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {n nv : Nat} {S : Benitoite.Release.Refinement.RangeExpr},
  rs.length = n →
    Benitoite.Release.Refinement.Ty.TargetWF n (List.length C) nv p →
      (∀ (r : Benitoite.Release.Refinement.RangeExpr), r ∈ rs → S.Covers r) →
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
            (Benitoite.Release.Refinement.Ty.subst ts es (Benitoite.Release.Refinement.Ty.instTarget rs p)) →
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
            (Benitoite.Release.Refinement.Ty.subst ts es
              (Benitoite.Release.Refinement.Ty.instTarget (List.replicate n S) p))
```

## Benitoite.Release.Refinement.HasTypeVQ.widen_opaque

所在: `formal/Benitoite/Release/Refinement/MembershipWiden.lean`、行: 43。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName}
  {r s : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    s.Covers r →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
        (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed s))
```

## Benitoite.Release.Refinement.HasTypeVsQ

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 254。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              List Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.HasTypeVsQ.get

所在: `formal/Benitoite/Release/Refinement/ValueFacts.lean`、行: 90。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty} {i : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as →
    as[i]? = Option.some a → ∃ v, vs[i]? = Option.some v ∧ Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a
```

## Benitoite.Release.Refinement.HasTypeVsQ.length

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 28。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B store Q C Γ Φ vs as → vs.length = as.length
```

## Benitoite.Release.Refinement.HasTypeVsQ.observation_declared

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 90。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B store Q C Γ Φ vs as →
    Benitoite.Release.Refinement.declaredSlots P C Γ (Benitoite.Release.Refinement.Val.toTermSlots vs)
```

## Benitoite.Release.Refinement.HasTypeVsQ.observation_references

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 134。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {store : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B store Q C Γ Φ vs as →
    Benitoite.Release.Refinement.varsInSlots Γ.Readable (Benitoite.Release.Refinement.Val.toTermSlots vs)
```

## Benitoite.Release.Refinement.HasTypeVsQ.widen_covers

所在: `formal/Benitoite/Release/Refinement/MembershipWiden.lean`、行: 94。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {ws : List Benitoite.Release.Refinement.Val} {ps ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr} {n : Nat}
  {S : Benitoite.Release.Refinement.RangeExpr} {nv : Nat},
  rs.length = n →
    Benitoite.Release.Refinement.BinderTypes.TargetWF n (List.length C) nv ps →
      (∀ (r : Benitoite.Release.Refinement.RangeExpr), r ∈ rs → S.Covers r) →
        Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C [] Φ ws
            (List.map (Benitoite.Release.Refinement.Ty.subst ts es)
              (List.map (Benitoite.Release.Refinement.Ty.instTarget rs) ps)) →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C [] Φ ws
            (List.map (Benitoite.Release.Refinement.Ty.subst ts es)
              (List.map (Benitoite.Release.Refinement.Ty.instTarget (List.replicate n S)) ps))
```

## Benitoite.Release.Refinement.ImplDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 324。

```lean
Type
```

## Benitoite.Release.Refinement.ImplDecl.cls

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 334。

```lean
Benitoite.Release.Refinement.ImplDecl → Benitoite.Release.ClassName
```

## Benitoite.Release.Refinement.ImplDecl.dictParams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 333。

```lean
Benitoite.Release.Refinement.ImplDecl → List (Benitoite.Release.ClassName × Nat)
```

## Benitoite.Release.Refinement.ImplDecl.dictTys

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 339。

```lean
Benitoite.Release.Refinement.ImplDecl → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ImplDecl.methods

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 337。

```lean
Benitoite.Release.Refinement.ImplDecl → Benitoite.Release.MethName → Option Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.ImplDecl.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 331。

```lean
List Benitoite.Release.TParam →
  List (Benitoite.Release.ClassName × Nat) →
    Benitoite.Release.ClassName →
      Benitoite.Release.Refinement.Ty →
        (Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.Val) →
          (Benitoite.Release.MethName → Option Benitoite.Release.Refinement.Comp) →
            Benitoite.Release.Refinement.ImplDecl
```

## Benitoite.Release.Refinement.ImplDecl.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 331。

```lean
{P : Sort u} →
  {tparams : List Benitoite.Release.TParam} →
    {dictParams : List (Benitoite.Release.ClassName × Nat)} →
      {cls : Benitoite.Release.ClassName} →
        {target : Benitoite.Release.Refinement.Ty} →
          {supers : Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.Val} →
            {methods : Benitoite.Release.MethName → Option Benitoite.Release.Refinement.Comp} →
              {tparams' : List Benitoite.Release.TParam} →
                {dictParams' : List (Benitoite.Release.ClassName × Nat)} →
                  {cls' : Benitoite.Release.ClassName} →
                    {target' : Benitoite.Release.Refinement.Ty} →
                      {supers' : Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.Val} →
                        {methods' : Benitoite.Release.MethName → Option Benitoite.Release.Refinement.Comp} →
                          { tparams := tparams, dictParams := dictParams, cls := cls, target := target,
                                supers := supers, methods := methods } =
                              { tparams := tparams', dictParams := dictParams', cls := cls', target := target',
                                supers := supers', methods := methods' } →
                            (tparams = tparams' →
                                dictParams = dictParams' →
                                  cls = cls' → target = target' → supers = supers' → methods = methods' → P) →
                              P
```

## Benitoite.Release.Refinement.ImplDecl.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 324。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ImplDecl} → t = t' → Benitoite.Release.Refinement.ImplDecl.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ImplDecl.supers

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 336。

```lean
Benitoite.Release.Refinement.ImplDecl → Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.ImplDecl.target

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 335。

```lean
Benitoite.Release.Refinement.ImplDecl → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ImplDecl.tparams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 332。

```lean
Benitoite.Release.Refinement.ImplDecl → List Benitoite.Release.TParam
```

## Benitoite.Release.Refinement.InhabitsAll.length

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 19。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {as : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val}, Benitoite.Release.Refinement.InhabitsAll P as vs → vs.length = as.length
```

## Benitoite.Release.Refinement.InitialPrepared

所在: `formal/Benitoite/Release/Refinement/Preparation.lean`、行: 143。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.State → Prop
```

## Benitoite.Release.Refinement.InitialPrepared.source_state_of_source

所在: `formal/Benitoite/Release/Refinement/PreparationTargets.lean`、行: 89。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {m : Benitoite.Release.Refinement.Comp}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.InitialPrepared P B σ
      (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.pure m) []
        Benitoite.Release.Refinement.Store.empty) →
    P.ExternalWF →
      Benitoite.Release.Refinement.HasTypeC P B Benitoite.Release.Refinement.StoreTy.empty [] [] [] Option.none m a e →
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

## Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.ValueRel.shape

所在: `formal/Benitoite/Release/Refinement/IntervalRelationBoundary.lean`、行: 14。

```lean
∀ {c : Benitoite.Interval.ConcreteValue} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.IntervalConnection.ValueRel c v →
    Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.ValueShape c v
```

## Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.ValueShape

所在: `formal/Benitoite/Release/Refinement/IntervalRelationBoundary.lean`、行: 7。

```lean
Benitoite.Interval.ConcreteValue → Benitoite.Release.Refinement.Val → Prop
```

## Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.ground_signature_obstruction

所在: `formal/Benitoite/Release/Refinement/IntervalRelationBoundary.lean`、行: 18。

```lean
Benitoite.Interval.ConcreteValue.unit.toApprox = (Benitoite.Release.Refinement.Val.con "Result.Error" [] []).toApprox ∧
  ¬Benitoite.Release.Refinement.IntervalConnection.ValueRel Benitoite.Interval.ConcreteValue.unit
        (Benitoite.Release.Refinement.Val.con "Result.Error" [] []) ∧
    ¬∀ (c : Benitoite.Interval.ConcreteValue) (v : Benitoite.Release.Refinement.Val),
        c.toApprox = v.toApprox →
          v.Ground → Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.ValueShape c v
```

## Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.marked_signature_obstruction

所在: `formal/Benitoite/Release/Refinement/IntervalRelationBoundary.lean`、行: 42。

```lean
∃ P B σ,
  P.WellFormed ∧
    P.WellTyped B ∧
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧
        σ.Valid ∧
          Benitoite.Release.Refinement.StateTyE P B σ Benitoite.Release.Refinement.Eff.empty
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure
                  (Benitoite.Release.Refinement.Comp.escape
                    (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
                [Benitoite.Release.Refinement.Frame.mark] Benitoite.Release.Refinement.Store.empty) ∧
            (Benitoite.Interval.ConcreteValue.con "Result" [] "Result.Ok"
                    [Benitoite.Interval.ConcreteValue.unit]).toApprox =
                (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit).toApprox ∧
              ¬∃ q μ v,
                  Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret
                            (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))
                        [] Benitoite.Release.Refinement.Store.empty =
                      Benitoite.Release.Refinement.State.run q [] μ ∧
                    q.view = Benitoite.Release.Refinement.Comp.ret v ∧
                      Benitoite.Release.Refinement.IntervalConnection.RelationBoundary.ValueShape
                        (Benitoite.Interval.ConcreteValue.con "Result" [] "Result.Ok"
                          [Benitoite.Interval.ConcreteValue.unit])
                        v
```

## Benitoite.Release.Refinement.LegacyPatternExamples.allList

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 64。

```lean
Benitoite.Release.Pat
```

## Benitoite.Release.Refinement.LegacyPatternExamples.atDecl

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 9。

```lean
Benitoite.Release.ConDecl
```

## Benitoite.Release.Refinement.LegacyPatternExamples.atPattern

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 108。

```lean
Benitoite.Release.Pat
```

## Benitoite.Release.Refinement.LegacyPatternExamples.at_old_correspondence

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 114。

```lean
∀ (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Refinement.LegacyPatternExamples.atPattern.matchVal
      (Benitoite.Release.Refinement.legacyPatternVal (Benitoite.Release.Refinement.Val.atError detail)) =
    Option.some
      (List.map (fun s => Benitoite.Release.Val.const (Benitoite.Release.Const.string s))
        (Benitoite.Release.Refinement.Detail.textFields detail))
```

## Benitoite.Release.Refinement.LegacyPatternExamples.at_seven_bindings

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 110。

```lean
∀ (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.LegacyPatternExamples.atPattern
      (Benitoite.Release.Refinement.Val.atError detail) =
    Option.some (Benitoite.Release.Refinement.Detail.values detail)
```

## Benitoite.Release.Refinement.LegacyPatternExamples.at_wrong_arity

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 125。

```lean
∀ (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Refinement.matchVal
      (Benitoite.Release.Pat.con "Scope.ScopeError.At" (List.replicate 6 Benitoite.Release.Pat.var))
      (Benitoite.Release.Refinement.Val.atError detail) =
    Option.none
```

## Benitoite.Release.Refinement.LegacyPatternExamples.at_wrong_name

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 121。

```lean
∀ (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.con "Other" (List.replicate 7 Benitoite.Release.Pat.var))
      (Benitoite.Release.Refinement.Val.atError detail) =
    Option.none
```

## Benitoite.Release.Refinement.LegacyPatternExamples.builtins

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 22。

```lean
Benitoite.Release.Refinement.Builtins
```

## Benitoite.Release.Refinement.LegacyPatternExamples.checkedAt_in_list

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 88。

```lean
∀ (r : Benitoite.Release.Refinement.RangeExpr) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (target : Benitoite.Scope.Domain.Target) (request : Option Benitoite.Release.Refinement.Val),
  ∃ p,
    p ∈ [Benitoite.Release.Refinement.LegacyPatternExamples.allList] ∧
      (Benitoite.Release.Refinement.matchVal p
            (Benitoite.Release.Refinement.Val.list
              [Benitoite.Release.Refinement.Val.checkedAt r snapshot target request])).isSome =
        Bool.true
```

## Benitoite.Release.Refinement.LegacyPatternExamples.kinds

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 8。

```lean
Benitoite.Release.Refinement.DeclarationKinds
```

## Benitoite.Release.Refinement.LegacyPatternExamples.kinds_wf

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 58。

```lean
Benitoite.Release.Refinement.LegacyPatternExamples.kinds.WF
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
```

## Benitoite.Release.Refinement.LegacyPatternExamples.list_coverage

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 84。

```lean
Benitoite.Release.Refinement.Exhaustive
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list)
  [Benitoite.Release.Refinement.LegacyPatternExamples.allList]
```

## Benitoite.Release.Refinement.LegacyPatternExamples.list_input

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 79。

```lean
Benitoite.Release.Refinement.LegacyNodeTypes Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram [] [] 0
  [Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list]
```

## Benitoite.Release.Refinement.LegacyPatternExamples.nested_alts

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 98。

```lean
Benitoite.Release.Refinement.AltsTy
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  [{ pat := Benitoite.Release.Pat.list [Benitoite.Release.Pat.var] (Option.some Benitoite.Release.ListRest.bind) [],
      slots := [0, 1] }]
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list)
  (Benitoite.Release.Refinement.embedTys
    [Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType,
      Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list])
```

## Benitoite.Release.Refinement.LegacyPatternExamples.nested_pattern

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 93。

```lean
Benitoite.Release.Refinement.PatTy
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  (Benitoite.Release.Pat.list [Benitoite.Release.Pat.var] (Option.some Benitoite.Release.ListRest.bind) [])
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list)
  (Benitoite.Release.Refinement.embedTys
    [Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType,
      Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list])
```

## Benitoite.Release.Refinement.LegacyPatternExamples.new_range_not_exhaustive

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 141。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  ¬Benitoite.Release.Refinement.Exhaustive P
      (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque) []
```

## Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 17。

```lean
Benitoite.Release.Builtins
```

## Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 12。

```lean
Benitoite.Release.Program
```

## Benitoite.Release.Refinement.LegacyPatternExamples.old_range_exhaustive

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 131。

```lean
∀ (P0 : Benitoite.Release.Program),
  Benitoite.Release.Exhaustive P0 Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque []
```

## Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 63。

```lean
Benitoite.Release.Ty
```

## Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 129。

```lean
Benitoite.Release.Ty
```

## Benitoite.Release.Refinement.LegacyPatternExamples.range_input_rejected

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 152。

```lean
∀ (K : Benitoite.Release.Refinement.DeclarationKinds) (P0 : Benitoite.Release.Program)
  (κ : Benitoite.Release.Refinement.KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat),
  ¬Benitoite.Release.Refinement.LegacyNodeTypes K P0 κ C nv
      [Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque]
```

## Benitoite.Release.Refinement.LegacyPatternExamples.range_wf_rejected

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 149。

```lean
∀ (nt : Nat), ¬Benitoite.Release.Ty.WF 0 nt Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque
```

## Benitoite.Release.Refinement.LegacyPatternExamples.tables

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 28。

```lean
Benitoite.Release.Refinement.LegacyTables Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
```

## Benitoite.Release.Refinement.LegacyPatternExamples.unitOperation

所在: `formal/Benitoite/Release/Refinement/LegacyPatternExamples.lean`、行: 10。

```lean
Benitoite.Release.OpDecl
```

## Benitoite.Release.Refinement.LocTy

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 466。

```lean
Type
```

## Benitoite.Release.Refinement.LocTy.builder

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 467。

```lean
Benitoite.Release.Refinement.BuilderKind → Benitoite.Release.Refinement.LocTy
```

## Benitoite.Release.Refinement.LocTy.builder.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 467。

```lean
{motive : Benitoite.Release.Refinement.LocTy → Sort u} →
  (t : Benitoite.Release.Refinement.LocTy) →
    t.ctorIdx = 0 →
      ((kind : Benitoite.Release.Refinement.BuilderKind) → motive (Benitoite.Release.Refinement.LocTy.builder kind)) →
        motive t
```

## Benitoite.Release.Refinement.LocTy.builder.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 467。

```lean
{P : Sort u} →
  {kind kind' : Benitoite.Release.Refinement.BuilderKind} →
    Benitoite.Release.Refinement.LocTy.builder kind = Benitoite.Release.Refinement.LocTy.builder kind' →
      (kind = kind' → P) → P
```

## Benitoite.Release.Refinement.LocTy.cont

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 470。

```lean
Benitoite.Release.Refinement.Ty →
  Benitoite.Release.Refinement.Ty →
    Benitoite.Release.Refinement.Eff → Option Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.LocTy
```

## Benitoite.Release.Refinement.LocTy.cont.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 470。

```lean
{motive : Benitoite.Release.Refinement.LocTy → Sort u} →
  (t : Benitoite.Release.Refinement.LocTy) →
    t.ctorIdx = 3 →
      ((b t : Benitoite.Release.Refinement.Ty) →
          (ε : Benitoite.Release.Refinement.Eff) →
            (r : Option Benitoite.Release.Refinement.Ty) → motive (Benitoite.Release.Refinement.LocTy.cont b t ε r)) →
        motive t
```

## Benitoite.Release.Refinement.LocTy.cont.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 470。

```lean
{P : Sort u} →
  {b t : Benitoite.Release.Refinement.Ty} →
    {ε : Benitoite.Release.Refinement.Eff} →
      {r : Option Benitoite.Release.Refinement.Ty} →
        {b' t' : Benitoite.Release.Refinement.Ty} →
          {ε' : Benitoite.Release.Refinement.Eff} →
            {r' : Option Benitoite.Release.Refinement.Ty} →
              Benitoite.Release.Refinement.LocTy.cont b t ε r = Benitoite.Release.Refinement.LocTy.cont b' t' ε' r' →
                (b = b' → t = t' → ε = ε' → r = r' → P) → P
```

## Benitoite.Release.Refinement.LocTy.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 466。

```lean
{motive : Benitoite.Release.Refinement.LocTy → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.LocTy) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.LocTy.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.LocTy.lazy

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 469。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.LocTy
```

## Benitoite.Release.Refinement.LocTy.lazy.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 469。

```lean
{motive : Benitoite.Release.Refinement.LocTy → Sort u} →
  (t : Benitoite.Release.Refinement.LocTy) →
    t.ctorIdx = 2 →
      ((a : Benitoite.Release.Refinement.Ty) → motive (Benitoite.Release.Refinement.LocTy.lazy a)) → motive t
```

## Benitoite.Release.Refinement.LocTy.lazy.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 469。

```lean
{P : Sort u} →
  {a a' : Benitoite.Release.Refinement.Ty} →
    Benitoite.Release.Refinement.LocTy.lazy a = Benitoite.Release.Refinement.LocTy.lazy a' → (a = a' → P) → P
```

## Benitoite.Release.Refinement.LocTy.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 466。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.LocTy} → t = t' → Benitoite.Release.Refinement.LocTy.noConfusionType P t t'
```

## Benitoite.Release.Refinement.LocTy.ref

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 468。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.LocTy
```

## Benitoite.Release.Refinement.LocTy.ref.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 468。

```lean
{motive : Benitoite.Release.Refinement.LocTy → Sort u} →
  (t : Benitoite.Release.Refinement.LocTy) →
    t.ctorIdx = 1 →
      ((a : Benitoite.Release.Refinement.Ty) → motive (Benitoite.Release.Refinement.LocTy.ref a)) → motive t
```

## Benitoite.Release.Refinement.LocTy.ref.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 468。

```lean
{P : Sort u} →
  {a a' : Benitoite.Release.Refinement.Ty} →
    Benitoite.Release.Refinement.LocTy.ref a = Benitoite.Release.Refinement.LocTy.ref a' → (a = a' → P) → P
```

## Benitoite.Release.Refinement.LocalCtx

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 476。

```lean
Type
```

## Benitoite.Release.Refinement.MatchFacts.BinderPath.matched

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 753。

```lean
∀ {pat : Benitoite.Release.Pat} {i : Nat} {rs : List Benitoite.Release.Refinement.FieldRef},
  Benitoite.Release.Refinement.BinderPath pat i rs →
    ∀ {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
      Benitoite.Release.Refinement.matchVal pat v = Option.some ws →
        ∃ w, ws[i]? = Option.some w ∧ Benitoite.Release.Refinement.MatchFacts.readPath v rs = Option.some w
```

## Benitoite.Release.Refinement.MatchFacts.FieldLink.matched

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 900。

```lean
∀ {alts : List Benitoite.Release.Alt} {n : Nat} {link : Benitoite.Release.Refinement.FieldLink}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.FieldLink.Valid alts n link →
    Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
      ∃ w,
        ws[link.slot]? = Option.some w ∧ Benitoite.Release.Refinement.MatchFacts.readPath v link.route = Option.some w
```

## Benitoite.Release.Refinement.MatchFacts.PatTy.binders_length

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 10。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {p : Benitoite.Release.Pat} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty}, Benitoite.Release.Refinement.PatTy P p a δ → δ.length = p.binders
```

## Benitoite.Release.Refinement.MatchFacts.PatTys.arity_length

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 514。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {ps : List Benitoite.Release.Pat}
  {as δ : List Benitoite.Release.Refinement.Ty}, Benitoite.Release.Refinement.PatTys P ps as δ → ps.length = as.length
```

## Benitoite.Release.Refinement.MatchFacts.PatTys.binders_length

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 22。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {ps : List Benitoite.Release.Pat}
  {as δ : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.PatTys P ps as δ → δ.length = Benitoite.Release.Pat.bindersList ps
```

## Benitoite.Release.Refinement.MatchFacts.RootShape

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 346。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val → Prop
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.core

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 357。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.MatchFacts.RootShape P a.core v ↔ Benitoite.Release.Refinement.MatchFacts.RootShape P a v
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.data

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 418。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {d : Benitoite.Release.DataName} {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
    a = Benitoite.Release.Refinement.Ty.data d ts →
      (∃ c tys args cd,
          v = Benitoite.Release.Refinement.Val.con c tys args ∧
            P.cons c = Option.some cd ∧ args.length = cd.args.length) ∨
        ∃ detail cd,
          v = Benitoite.Release.Refinement.Val.atError detail ∧
            P.cons "Scope.ScopeError.At" = Option.some cd ∧ cd.args.length = detail.values.length
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.list

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 415。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {element : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
    a = element.list → ∃ elems, v = Benitoite.Release.Refinement.Val.list elems
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.norm

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 366。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.MatchFacts.RootShape P a.norm v ↔ Benitoite.Release.Refinement.MatchFacts.RootShape P a v
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.refineNorm

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 362。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {p : Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.MatchFacts.RootShape P (a.refineNorm p) v ↔
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.scalar

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 412。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {base : Benitoite.Release.BaseTy},
  Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
    a = Benitoite.Release.Refinement.Ty.base base →
      ∃ c, v = Benitoite.Release.Refinement.Val.const c ∧ c.type = Benitoite.Release.Refinement.Ty.base base
```

## Benitoite.Release.Refinement.MatchFacts.RootShape.subtype

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 372。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {a b : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Ty.LeQ P Γ Φ a b →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v → Benitoite.Release.Refinement.MatchFacts.RootShape P b v
```

## Benitoite.Release.Refinement.MatchFacts._aux_Benitoite_Release_Refinement_MatchFacts___macroRules_Benitoite_Release_Refinement_MatchFacts_tacticMatch_eval_simp_1

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 175。

```lean
Lean.Macro
```

## Benitoite.Release.Refinement.MatchFacts.allowed_boolean_eq

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 171。

```lean
Decidable.decide
    (Benitoite.Release.Refinement.Comparison.Allowed Benitoite.Release.Refinement.Sort.boolean
      Benitoite.Release.Refinement.Comparison.eq) =
  Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.allowed_character

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 169。

```lean
∀ (op : Benitoite.Release.Refinement.Comparison),
  Decidable.decide (Benitoite.Release.Refinement.Comparison.Allowed Benitoite.Release.Refinement.Sort.character op) =
    Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.allowed_string_eq

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 172。

```lean
Decidable.decide
    (Benitoite.Release.Refinement.Comparison.Allowed Benitoite.Release.Refinement.Sort.string
      Benitoite.Release.Refinement.Comparison.eq) =
  Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.allowed_unit_eq

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 173。

```lean
Decidable.decide
    (Benitoite.Release.Refinement.Comparison.Allowed Benitoite.Release.Refinement.Sort.unit
      Benitoite.Release.Refinement.Comparison.eq) =
  Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.alternatives_test_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 284。

```lean
∀ {alts : List Benitoite.Release.Alt} {test : Benitoite.Release.Refinement.PathTest} {alt : Benitoite.Release.Alt}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.alternativesTest alts = Option.some test →
    alt ∈ alts →
      Benitoite.Release.Refinement.matchVal alt.pat v = Option.some ws →
        v.toTerm? = Option.some t →
          Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.character_le_decide

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 443。

```lean
∀ (a b : Char), (Decidable.decide (a.toNat < b.toNat) || a == b) = Decidable.decide (a.toNat ≤ b.toNat)
```

## Benitoite.Release.Refinement.MatchFacts.conFields?

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 702。

```lean
Benitoite.Release.Refinement.Val → Option (Benitoite.Release.ConName × List Benitoite.Release.Refinement.Val)
```

## Benitoite.Release.Refinement.MatchFacts.con_root

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 129。

```lean
∀ {c : Benitoite.Release.ConName} {ps : List Benitoite.Release.Pat} {v : Benitoite.Release.Refinement.Val}
  {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.con c ps) v = Option.some ws →
    ∃ slots, v.toTerm? = Option.some (Benitoite.Release.Refinement.Term.dataValue c slots)
```

## Benitoite.Release.Refinement.MatchFacts.const_match_false

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 423。

```lean
∀ {c : Benitoite.Release.Const} {c' : Benitoite.Release.Refinement.Const},
  Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.const c) (Benitoite.Release.Refinement.Val.const c') =
      Option.none →
    Benitoite.Release.Refinement.patternMatches c c' = Bool.false
```

## Benitoite.Release.Refinement.MatchFacts.constructor_test_false

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 534。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {c : Benitoite.Release.ConName} {ps : List Benitoite.Release.Pat}
  {cd : Benitoite.Release.Refinement.ConDecl} {ts δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  P.cons c = Option.some cd →
    Benitoite.Release.Refinement.PatTys P ps (List.map (Benitoite.Release.Refinement.Ty.subst ts []) cd.args) δ →
      ps.all Benitoite.Release.Refinement.irrefutableField = Bool.true →
        Benitoite.Release.Refinement.MatchFacts.RootShape P (Benitoite.Release.Refinement.Ty.data cd.data ts) v →
          Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.con c ps) v = Option.none →
            v.toTerm? = Option.some t →
              Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
                  (Benitoite.Release.Refinement.Pred.constructorIs t c) =
                Option.some Bool.false
```

## Benitoite.Release.Refinement.MatchFacts.empty_root

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 246。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.list [] Option.none []) v = Option.some ws →
    ∃ slots, v.toTerm? = Option.some (Benitoite.Release.Refinement.Term.listValue slots) ∧ slots.length = 0
```

## Benitoite.Release.Refinement.MatchFacts.empty_test_excluded

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 580。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.PatTy P (Benitoite.Release.Pat.list [] Option.none []) a δ →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
      Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.list [] Option.none []) v = Option.none →
        v.toTerm? = Option.some t →
          Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
              (Benitoite.Release.Refinement.PathTest.nonempty.predicate t) =
            Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.eval_character_range

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 460。

```lean
∀ (lo hi n : Char),
  Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
      ((Benitoite.Release.Refinement.PathTest.characterRange lo hi).predicate
        (Benitoite.Release.Refinement.Term.character n)) =
    Option.some
      (Benitoite.Release.Refinement.patternRange (Benitoite.Release.Const.character lo)
        (Benitoite.Release.Const.character hi) (Benitoite.Release.Refinement.Const.character n))
```

## Benitoite.Release.Refinement.MatchFacts.eval_constructor

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 180。

```lean
∀ (c d : Benitoite.Release.ConName) (slots : List (Option Benitoite.Release.Refinement.Term)),
  Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
      (Benitoite.Release.Refinement.Pred.constructorIs (Benitoite.Release.Refinement.Term.dataValue d slots) c) =
    Option.some (Decidable.decide (d = c))
```

## Benitoite.Release.Refinement.MatchFacts.eval_empty

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 188。

```lean
∀ (slots : List (Option Benitoite.Release.Refinement.Term)),
  Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
      (Benitoite.Release.Refinement.PathTest.empty.predicate (Benitoite.Release.Refinement.Term.listValue slots)) =
    Option.some (Decidable.decide (slots.length = 0))
```

## Benitoite.Release.Refinement.MatchFacts.eval_integer_range

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 453。

```lean
∀ (lo hi n : Benitoite.Release.Integer64Value),
  Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
      ((Benitoite.Release.Refinement.PathTest.integerRange lo.val hi.val).predicate
        (Benitoite.Release.Refinement.Term.integer n.val)) =
    Option.some
      (Benitoite.Release.Refinement.patternRange (Benitoite.Release.Const.integer lo)
        (Benitoite.Release.Const.integer hi) (Benitoite.Release.Refinement.Const.integer n))
```

## Benitoite.Release.Refinement.MatchFacts.eval_nonempty

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 184。

```lean
∀ (slots : List (Option Benitoite.Release.Refinement.Term)),
  Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
      (Benitoite.Release.Refinement.PathTest.nonempty.predicate (Benitoite.Release.Refinement.Term.listValue slots)) =
    Option.some (Decidable.decide (0 < slots.length))
```

## Benitoite.Release.Refinement.MatchFacts.eval_not_of_false

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 591。

```lean
∀ {p : Benitoite.Release.Refinement.Pred} {η : Benitoite.Release.Refinement.ObservationEnvModel},
  Benitoite.Release.Refinement.Pred.evalWith η p = Option.some Bool.false →
    Benitoite.Release.Refinement.Pred.evalWith η p.not = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.excluded_evalClosed_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 648。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {test : Benitoite.Release.Refinement.PathTest} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
      Benitoite.Release.Refinement.firstAlt v alts = Option.none →
        test ∈ Benitoite.Release.Refinement.excludedTests alts →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.WF 0 (test.predicate t) →
              Benitoite.Release.Refinement.Pred.Sorted [] Option.none (test.predicate t) →
                (test.predicate t).evalClosed = Option.some Bool.true
```

