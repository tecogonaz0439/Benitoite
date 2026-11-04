# 段末の実署名（続き）

## Benitoite.Release.Refinement.Program.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 344。

```lean
{P : Sort u} →
  {defs : Benitoite.Release.FunName → Option Benitoite.Release.Refinement.Def} →
    {cons : Benitoite.Release.ConName → Option Benitoite.Release.Refinement.ConDecl} →
      {ops : Benitoite.Release.OpName → Option Benitoite.Release.Refinement.OpDecl} →
        {effects : Benitoite.Release.EffName → Option (List Benitoite.Release.OpName)} →
          {classes : Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.ClassDecl} →
            {impls : Benitoite.Release.ImplName → Option Benitoite.Release.Refinement.ImplDecl} →
              {externals :
                  List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)} →
                {dataInfo : Benitoite.Release.DataName → Option Benitoite.Release.Refinement.DataVarianceDecl} →
                  {defs' : Benitoite.Release.FunName → Option Benitoite.Release.Refinement.Def} →
                    {cons' : Benitoite.Release.ConName → Option Benitoite.Release.Refinement.ConDecl} →
                      {ops' : Benitoite.Release.OpName → Option Benitoite.Release.Refinement.OpDecl} →
                        {effects' : Benitoite.Release.EffName → Option (List Benitoite.Release.OpName)} →
                          {classes' : Benitoite.Release.ClassName → Option Benitoite.Release.Refinement.ClassDecl} →
                            {impls' : Benitoite.Release.ImplName → Option Benitoite.Release.Refinement.ImplDecl} →
                              {externals' :
                                  List
                                    (Benitoite.Release.Refinement.ExternalKey ×
                                      Benitoite.Release.Refinement.ExternalDecl)} →
                                {dataInfo' :
                                    Benitoite.Release.DataName → Option Benitoite.Release.Refinement.DataVarianceDecl} →
                                  { defs := defs, cons := cons, ops := ops, effects := effects, classes := classes,
                                        impls := impls, externals := externals, dataInfo := dataInfo } =
                                      { defs := defs', cons := cons', ops := ops', effects := effects',
                                        classes := classes', impls := impls', externals := externals',
                                        dataInfo := dataInfo' } →
                                    (defs = defs' →
                                        cons = cons' →
                                          ops = ops' →
                                            effects = effects' →
                                              classes = classes' →
                                                impls = impls' → externals = externals' → dataInfo = dataInfo' → P) →
                                      P
```

## Benitoite.Release.Refinement.Program.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 343。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Program} → t = t' → Benitoite.Release.Refinement.Program.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Program.ops

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 347。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.OpName → Option Benitoite.Release.Refinement.OpDecl
```

## Benitoite.Release.Refinement.Program.varianceFor

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 355。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.DataName → Nat → List Benitoite.Release.Refinement.Variance
```

## Benitoite.Release.Refinement.Program.varianceFor_length

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 362。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (d : Benitoite.Release.DataName) (n : Nat), (P.varianceFor d n).length = n
```

## Benitoite.Release.Refinement.RangeExpr

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 23。

```lean
Type
```

## Benitoite.Release.Refinement.RangeExpr.Canonical

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 16。

```lean
Benitoite.Release.Refinement.RangeExpr → Prop
```

## Benitoite.Release.Refinement.RangeExpr.Covers

所在: `formal/Benitoite/Release/Refinement/Atoms.lean`、行: 5。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.RangeExpr → Prop
```

## Benitoite.Release.Refinement.RangeExpr.Covers.mem

所在: `formal/Benitoite/Release/Refinement/ScopeCoverage.lean`、行: 41。

```lean
∀ {outer inner : Benitoite.Release.Refinement.RangeExpr},
  outer.Covers inner →
    ∀ (σ : Benitoite.Release.Refinement.PathEnv) {k : Benitoite.Scope.Domain.Kind} {t : Benitoite.Scope.Domain.Target},
      Benitoite.Release.Refinement.RangeExpr.Mem σ k inner t → Benitoite.Release.Refinement.RangeExpr.Mem σ k outer t
```

## Benitoite.Release.Refinement.RangeExpr.FitsKind

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 7。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Scope.Domain.Kind → Prop
```

## Benitoite.Release.Refinement.RangeExpr.Mem

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 54。

```lean
Benitoite.Release.Refinement.PathEnv →
  Benitoite.Scope.Domain.Kind → Benitoite.Release.Refinement.RangeExpr → Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.RangeExpr.WF

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 11。

```lean
Benitoite.Release.Refinement.RangeExpr → Prop
```

## Benitoite.Release.Refinement.RangeExpr.absolute

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 24。

```lean
Benitoite.Scope.Domain.Range → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeExpr.absolute.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 24。

```lean
{motive : Benitoite.Release.Refinement.RangeExpr → Sort u} →
  (t : Benitoite.Release.Refinement.RangeExpr) →
    t.ctorIdx = 0 →
      ((range : Benitoite.Scope.Domain.Range) → motive (Benitoite.Release.Refinement.RangeExpr.absolute range)) →
        motive t
```

## Benitoite.Release.Refinement.RangeExpr.absolute.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 24。

```lean
{P : Sort u} →
  {range range' : Benitoite.Scope.Domain.Range} →
    Benitoite.Release.Refinement.RangeExpr.absolute range = Benitoite.Release.Refinement.RangeExpr.absolute range' →
      (range = range' → P) → P
```

## Benitoite.Release.Refinement.RangeExpr.base?

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 76。

```lean
Benitoite.Release.Refinement.RangeExpr → Option Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.RangeExpr.based

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 25。

```lean
Benitoite.Release.Refinement.PathBase → Benitoite.Scope.Domain.PathPattern → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeExpr.based.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 25。

```lean
{motive : Benitoite.Release.Refinement.RangeExpr → Sort u} →
  (t : Benitoite.Release.Refinement.RangeExpr) →
    t.ctorIdx = 1 →
      ((base : Benitoite.Release.Refinement.PathBase) →
          (pattern : Benitoite.Scope.Domain.PathPattern) →
            motive (Benitoite.Release.Refinement.RangeExpr.based base pattern)) →
        motive t
```

## Benitoite.Release.Refinement.RangeExpr.based.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 25。

```lean
{P : Sort u} →
  {base : Benitoite.Release.Refinement.PathBase} →
    {pattern : Benitoite.Scope.Domain.PathPattern} →
      {base' : Benitoite.Release.Refinement.PathBase} →
        {pattern' : Benitoite.Scope.Domain.PathPattern} →
          Benitoite.Release.Refinement.RangeExpr.based base pattern =
              Benitoite.Release.Refinement.RangeExpr.based base' pattern' →
            (base = base' → pattern = pattern' → P) → P
```

## Benitoite.Release.Refinement.RangeExpr.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 23。

```lean
{motive : Benitoite.Release.Refinement.RangeExpr → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.RangeExpr) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.RangeExpr.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.RangeExpr.endpoint

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 37。

```lean
Benitoite.Scope.Domain.EndpointPattern → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeExpr.host

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 36。

```lean
Benitoite.Scope.Domain.HostPattern → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeExpr.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 23。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.RangeExpr} →
    t = t' → Benitoite.Release.Refinement.RangeExpr.noConfusionType P t t'
```

## Benitoite.Release.Refinement.RangeExpr.path

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 35。

```lean
Benitoite.Scope.Domain.PathPattern → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeExpr.resolve

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 44。

```lean
Benitoite.Release.Refinement.PathEnv →
  Benitoite.Release.Refinement.RangeExpr → Option (List Benitoite.Scope.Domain.Range)
```

## Benitoite.Release.Refinement.RangeExpr.secrets

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 26。

```lean
Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeExpr.secrets.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 26。

```lean
{motive : Benitoite.Release.Refinement.RangeExpr → Sort u} →
  (t : Benitoite.Release.Refinement.RangeExpr) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.RangeExpr.secrets → motive t
```

## Benitoite.Release.Refinement.RangeExpr.top

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 34。

```lean
Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.RangeIx

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 29。

```lean
Type
```

## Benitoite.Release.Refinement.RangeIx.Covers.inst_mem

所在: `formal/Benitoite/Release/Refinement/ScopeCoverage.lean`、行: 143。

```lean
∀ {outer inner : Benitoite.Release.Refinement.RangeIx},
  outer.Covers inner →
    ∀ (rs : List Benitoite.Release.Refinement.RangeExpr) {r : Benitoite.Release.Refinement.RangeExpr},
      Benitoite.Release.Refinement.RangeIx.inst rs inner = Benitoite.Release.Refinement.RangeIx.fixed r →
        ∀ (σ : Benitoite.Release.Refinement.PathEnv) {k : Benitoite.Scope.Domain.Kind}
          {t : Benitoite.Scope.Domain.Target},
          Benitoite.Release.Refinement.RangeExpr.Mem σ k r t →
            ∃ s,
              Benitoite.Release.Refinement.RangeIx.inst rs outer = Benitoite.Release.Refinement.RangeIx.fixed s ∧
                Benitoite.Release.Refinement.RangeExpr.Mem σ k s t
```

## Benitoite.Release.Refinement.RangeIx.WF

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 90。

```lean
Nat → Benitoite.Release.Refinement.RangeIx → Prop
```

## Benitoite.Release.Refinement.RangeIx.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 29。

```lean
{motive : Benitoite.Release.Refinement.RangeIx → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.RangeIx) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.RangeIx.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.RangeIx.fixed

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 30。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.RangeIx
```

## Benitoite.Release.Refinement.RangeIx.fixed.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 30。

```lean
{motive : Benitoite.Release.Refinement.RangeIx → Sort u} →
  (t : Benitoite.Release.Refinement.RangeIx) →
    t.ctorIdx = 0 →
      ((range : Benitoite.Release.Refinement.RangeExpr) → motive (Benitoite.Release.Refinement.RangeIx.fixed range)) →
        motive t
```

## Benitoite.Release.Refinement.RangeIx.fixed.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 30。

```lean
{P : Sort u} →
  {range range' : Benitoite.Release.Refinement.RangeExpr} →
    Benitoite.Release.Refinement.RangeIx.fixed range = Benitoite.Release.Refinement.RangeIx.fixed range' →
      (range = range' → P) → P
```

## Benitoite.Release.Refinement.RangeIx.inst

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 84。

```lean
List Benitoite.Release.Refinement.RangeExpr →
  Benitoite.Release.Refinement.RangeIx → Benitoite.Release.Refinement.RangeIx
```

## Benitoite.Release.Refinement.RangeIx.inst_fixed

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 117。

```lean
∀ (rs : List Benitoite.Release.Refinement.RangeExpr) (r : Benitoite.Release.Refinement.RangeExpr),
  Benitoite.Release.Refinement.RangeIx.inst rs (Benitoite.Release.Refinement.RangeIx.fixed r) =
    Benitoite.Release.Refinement.RangeIx.fixed r
```

## Benitoite.Release.Refinement.RangeIx.inst_nil

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 114。

```lean
∀ (ix : Benitoite.Release.Refinement.RangeIx), Benitoite.Release.Refinement.RangeIx.inst [] ix = ix
```

## Benitoite.Release.Refinement.RangeIx.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 29。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.RangeIx} → t = t' → Benitoite.Release.Refinement.RangeIx.noConfusionType P t t'
```

## Benitoite.Release.Refinement.RangeIx.rvar

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 31。

```lean
Nat → Benitoite.Release.Refinement.RangeIx
```

## Benitoite.Release.Refinement.RangeIx.rvar.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 31。

```lean
{motive : Benitoite.Release.Refinement.RangeIx → Sort u} →
  (t : Benitoite.Release.Refinement.RangeIx) →
    t.ctorIdx = 1 → ((index : Nat) → motive (Benitoite.Release.Refinement.RangeIx.rvar index)) → motive t
```

## Benitoite.Release.Refinement.RangeIx.rvar.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 31。

```lean
{P : Sort u} →
  {index index' : Nat} →
    Benitoite.Release.Refinement.RangeIx.rvar index = Benitoite.Release.Refinement.RangeIx.rvar index' →
      (index = index' → P) → P
```

## Benitoite.Release.Refinement.RangeIx.toOld?

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 100。

```lean
Benitoite.Release.Refinement.RangeIx → Option Benitoite.Scope.Signature.Ix
```

## Benitoite.Release.Refinement.RangeIx.toOld?_embed

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 105。

```lean
∀ (ix : Benitoite.Scope.Signature.Ix), (Benitoite.Release.Refinement.embedIx ix).toOld? = Option.some ix
```

## Benitoite.Release.Refinement.RangeIx.toOld?_sound

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 108。

```lean
∀ {a : Benitoite.Release.Refinement.RangeIx} {b : Benitoite.Scope.Signature.Ix},
  a.toOld? = Option.some b → Benitoite.Release.Refinement.embedIx b = a
```

## Benitoite.Release.Refinement.RangeIx.top

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 38。

```lean
Benitoite.Release.Refinement.RangeIx
```

## Benitoite.Release.Refinement.RefutationExamples.combine_refutes_at

所在: `formal/Benitoite/Release/Refinement/RefutationExamples.lean`、行: 82。

```lean
∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.BranchRefutedAt Benitoite.Release.Refinement.RefutationExamples.x✝ []
    Benitoite.Release.Refinement.RefutationExamples.f✝ ν η
```

## Benitoite.Release.Refinement.RefutationExamples.consumed_refutes_at

所在: `formal/Benitoite/Release/Refinement/RefutationExamples.lean`、行: 102。

```lean
∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.BranchRefutedAt Benitoite.Release.Refinement.RefutationExamples.x✝
    [(Benitoite.Release.Refinement.NNF.linear { coefficients := [1], bound := 0 }).and
        (Benitoite.Release.Refinement.NNF.linear { coefficients := [-1], bound := -1 })]
    [] ν η
```

## Benitoite.Release.Refinement.RefutationExamples.normalized_refutes_at

所在: `formal/Benitoite/Release/Refinement/RefutationExamples.lean`、行: 114。

```lean
∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.Pred.interpret η
      (Benitoite.Release.Refinement.predBind ν
        ((Benitoite.Release.Refinement.Pred.le (Benitoite.Release.Refinement.Term.var 0)
              (Benitoite.Release.Refinement.Term.integer 0)).and
          (Benitoite.Release.Refinement.Pred.le (Benitoite.Release.Refinement.Term.integer 1)
            (Benitoite.Release.Refinement.Term.var 0)))) ≠
    Bool.true
```

## Benitoite.Release.Refinement.RefutationExamples.odd_refutes_at

所在: `formal/Benitoite/Release/Refinement/RefutationExamples.lean`、行: 87。

```lean
∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.BranchRefutedAt Benitoite.Release.Refinement.RefutationExamples.x✝ []
    [Benitoite.Release.Refinement.NNF.linear { coefficients := [2], bound := 1 },
      Benitoite.Release.Refinement.NNF.linear { coefficients := [-2], bound := -1 }]
    ν η
```

## Benitoite.Release.Refinement.RequestDelta.checkTys

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 84。

```lean
Benitoite.Release.Refinement.RangeExpr → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.RequestDelta.delta

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 125。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.RequestDelta.error

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 87。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.RequestDelta.invalidUrl

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 53。

```lean
Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.RequestDelta.invalidUrl_safe

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 56。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        Benitoite.Release.Refinement.RequestDelta.invalidUrl
        Benitoite.Release.Refinement.ScopeSignatures.requestCheckErrorTy ∧
      Benitoite.Release.Refinement.RequestDelta.invalidUrl.Ground ∧
        ∀ (σ : Benitoite.Release.Refinement.PathEnv),
          Benitoite.Release.Refinement.Val.Adequate σ Benitoite.Release.Refinement.RequestDelta.invalidUrl
```

## Benitoite.Release.Refinement.RequestDelta.ok

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 85。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.RequestDelta.parseHostPattern

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 10。

```lean
String → Option Benitoite.Scope.Domain.HostPattern
```

## Benitoite.Release.Refinement.RequestDelta.requestInValue_response

所在: `formal/Benitoite/Release/Refinement/RequestValueDelta.lean`、行: 70。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
    B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
      Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.requestInValue"
          Benitoite.Release.Refinement.ScopeSignatures.requestInValue ts es rs ws a e →
        ∃ out,
          Benitoite.Release.Refinement.RequestDelta.valueDelta "Http.requestInValue" ts es rs ws = Option.some out ∧
            (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.RequestDelta.response

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 217。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.checkRequestIn"
            Benitoite.Release.Refinement.ScopeSignatures.checkRequestIn ts es rs ws a e →
          ∃ out,
            Benitoite.Release.Refinement.RequestDelta.delta "Http.checkRequestIn" ts es rs ws = Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.RequestDelta.retained_request

所在: `formal/Benitoite/Release/Refinement/RequestValueDelta.lean`、行: 10。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v
      (Benitoite.Release.Refinement.Ty.opaque "Http.RequestIn" (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        ∃ target req,
          (v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
              ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (Option.some req)) ∧
            Benitoite.Release.Refinement.ModelHttp.valueRun [v] = Benitoite.Release.Refinement.Outcome.val req ∧
              Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req
                  Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy.norm ∧
                Benitoite.Release.Refinement.groundVal req = Bool.true ∧ req.reqTarget = Option.some target
```

## Benitoite.Release.Refinement.RequestDelta.run

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 101。

```lean
Benitoite.Release.Refinement.RangeExpr → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.RequestDelta.run_endpoint

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 269。

```lean
∀ {req : Benitoite.Release.Refinement.Val} {pattern : String} {endpoint : Benitoite.Scope.Domain.Endpoint}
  {p : Benitoite.Scope.Domain.HostPattern},
  Benitoite.Release.Refinement.groundVal req = Bool.true →
    (Benitoite.Release.Refinement.parseUrlShape (Benitoite.Release.Refinement.RequestDelta.urlText✝ req)).isSome =
        Bool.true →
      req.reqTarget = Option.some (Benitoite.Scope.Domain.Target.endpoint endpoint) →
        Benitoite.Release.Refinement.RequestDelta.parseHostPattern pattern = Option.some p →
          ∀ (r : Benitoite.Release.Refinement.RangeExpr) (lo hi : Benitoite.Release.Integer64Value),
            Benitoite.Release.Refinement.RequestDelta.run r
                [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern),
                  Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer lo),
                  Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer hi), req] =
              match
                Benitoite.Checked.Scope.makeEndpoint p endpoint.host lo.toInt hi.toInt
                  (Benitoite.Release.Refinement.RequestDelta.portValue✝ endpoint.port).toInt with
              | Except.error err =>
                Benitoite.Release.Refinement.RequestDelta.error r
                  (Benitoite.Release.Refinement.RequestDelta.scopeError
                    (Benitoite.Release.Refinement.ScopeDelta.errorValue pattern
                      (Benitoite.Release.Refinement.RequestDelta.hostText✝ req) lo hi
                      (Benitoite.Release.Refinement.RequestDelta.portValue✝ endpoint.port) err))
              | Except.ok checked =>
                match r with
                | Benitoite.Release.Refinement.RangeExpr.absolute bound =>
                  if
                      Benitoite.Scope.Domain.Range.MemK Benitoite.Scope.Domain.Kind.endpoint bound
                        (Benitoite.Scope.Domain.Target.endpoint endpoint) then
                    Benitoite.Release.Refinement.RequestDelta.ok r
                      (Benitoite.Release.Refinement.Val.checkedRequest (Benitoite.Scope.Domain.Target.endpoint endpoint)
                        req)
                  else
                    Benitoite.Release.Refinement.RequestDelta.error r
                      (Benitoite.Release.Refinement.RequestDelta.scopeError
                        (Benitoite.Release.Refinement.RequestDelta.staticError✝ pattern lo hi req checked))
                | Benitoite.Release.Refinement.RangeExpr.based base pattern_1 =>
                  Benitoite.Release.Refinement.RequestDelta.error r
                    (Benitoite.Release.Refinement.RequestDelta.scopeError
                      (Benitoite.Release.Refinement.RequestDelta.staticError✝ pattern lo hi req checked))
                | Benitoite.Release.Refinement.RangeExpr.secrets =>
                  Benitoite.Release.Refinement.RequestDelta.error r
                    (Benitoite.Release.Refinement.RequestDelta.scopeError
                      (Benitoite.Release.Refinement.RequestDelta.staticError✝ pattern lo hi req checked))
```

## Benitoite.Release.Refinement.RequestDelta.run_safe

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 152。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        ∀ (r : Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val),
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
              [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.string,
                Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer,
                Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer,
                Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy] →
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ (Benitoite.Release.Refinement.RequestDelta.run r ws)
                (Benitoite.Release.Refinement.Ty.data "Result" (Benitoite.Release.Refinement.RequestDelta.checkTys r)) ∧
              Benitoite.Release.Refinement.AdequateResult ws (Benitoite.Release.Refinement.RequestDelta.run r ws) ∧
                (∀ (v : Benitoite.Release.Refinement.Val),
                    Benitoite.Release.Refinement.RequestDelta.run r ws = Benitoite.Release.Refinement.Outcome.val v →
                      v.Ground) ∧
                  ∀ (n : Int),
                    Benitoite.Release.Refinement.RequestDelta.run r ws ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.RequestDelta.scopeError

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 54。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.RequestDelta.scopeError_safe

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 68。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v
        Benitoite.Release.Refinement.atErrorType →
      v.Ground →
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
            (Benitoite.Release.Refinement.RequestDelta.scopeError v)
            Benitoite.Release.Refinement.ScopeSignatures.requestCheckErrorTy ∧
          (Benitoite.Release.Refinement.RequestDelta.scopeError v).Ground ∧
            ∀ (σ : Benitoite.Release.Refinement.PathEnv),
              Benitoite.Release.Refinement.Val.Adequate σ v →
                Benitoite.Release.Refinement.Val.Adequate σ (Benitoite.Release.Refinement.RequestDelta.scopeError v)
```

## Benitoite.Release.Refinement.RequestDelta.text.INVALID_HOST

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 50。

```lean
String
```

## Benitoite.Release.Refinement.RequestDelta.text.INVALID_URL

所在: `formal/Benitoite/Release/Refinement/RequestDelta.lean`、行: 49。

```lean
String
```

## Benitoite.Release.Refinement.RequestDelta.valueDelta

所在: `formal/Benitoite/Release/Refinement/RequestValueDelta.lean`、行: 39。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.RequestDelta.widenRequestIn_response

所在: `formal/Benitoite/Release/Refinement/RequestValueDelta.lean`、行: 106。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  (∀ (r s : Benitoite.Release.Refinement.RangeExpr), B.admitsR "Http.widenRequestIn" [r, s] → s.Covers r) →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.widenRequestIn"
        Benitoite.Release.Refinement.ScopeSignatures.widenRequestIn ts es rs ws a e →
      ∃ out,
        Benitoite.Release.Refinement.RequestDelta.valueDelta "Http.widenRequestIn" ts es rs ws = Option.some out ∧
          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ResultShape

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 130。

```lean
Type
```

## Benitoite.Release.Refinement.ResultShape.Declared

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 16。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.ResultShape → Prop
```

## Benitoite.Release.Refinement.ResultShape.Declared.arity

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 18。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape → P.DataArity shape.owner 2
```

## Benitoite.Release.Refinement.ResultShape.Declared.distinct

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 19。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape → shape.ok ≠ shape.error
```

## Benitoite.Release.Refinement.ResultShape.Declared.errorDecl

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 22。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    ∃ cd,
      P.cons shape.error = Option.some cd ∧
        cd.data = shape.owner ∧ cd.ntys = 2 ∧ cd.args = [Benitoite.Release.Refinement.Ty.tvar 1]
```

## Benitoite.Release.Refinement.ResultShape.Declared.errorType_declared

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 28。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    Benitoite.Release.Refinement.Ty.Declared P C Γ shape.errorType
```

## Benitoite.Release.Refinement.ResultShape.Declared.errorType_eq

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 25。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape → shape.errorType = Benitoite.Release.Refinement.atErrorType
```

## Benitoite.Release.Refinement.ResultShape.Declared.error_data

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 31。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape}
  {Γ : Benitoite.Release.Refinement.Ctx} {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    Benitoite.Release.Refinement.Term.HasData P Γ
      (Benitoite.Release.Refinement.Term.dataValue "Scope.ScopeError.At"
        (List.map (fun s => Option.some (Benitoite.Release.Refinement.Term.string s))
          (Benitoite.Release.Refinement.Detail.textFields detail)))
      "Scope.ScopeError" []
```

## Benitoite.Release.Refinement.ResultShape.Declared.error_observation_declared

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 37。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    Benitoite.Release.Refinement.Term.Declared P C Γ
      (Benitoite.Release.Refinement.Term.dataValue "Scope.ScopeError.At"
        (List.map (fun s => Option.some (Benitoite.Release.Refinement.Term.string s))
          (Benitoite.Release.Refinement.Detail.textFields detail)))
```

## Benitoite.Release.Refinement.ResultShape.Declared.mk

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 16。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.StandardError P shape →
    P.DataArity shape.owner 2 →
      shape.ok ≠ shape.error →
        (∃ cd,
            P.cons shape.ok = Option.some cd ∧
              cd.data = shape.owner ∧ cd.ntys = 2 ∧ cd.args = [Benitoite.Release.Refinement.Ty.tvar 0]) →
          (∃ cd,
              P.cons shape.error = Option.some cd ∧
                cd.data = shape.owner ∧ cd.ntys = 2 ∧ cd.args = [Benitoite.Release.Refinement.Ty.tvar 1]) →
            Benitoite.Release.Refinement.ResultShape.Declared P shape
```

## Benitoite.Release.Refinement.ResultShape.Declared.okDecl

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 20。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    ∃ cd,
      P.cons shape.ok = Option.some cd ∧
        cd.data = shape.owner ∧ cd.ntys = 2 ∧ cd.args = [Benitoite.Release.Refinement.Ty.tvar 0]
```

## Benitoite.Release.Refinement.ResultShape.Declared.standard

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 17。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    Benitoite.Release.Refinement.ResultShape.StandardError P shape
```

## Benitoite.Release.Refinement.ResultShape.StandardError

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 11。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.ResultShape → Prop
```

## Benitoite.Release.Refinement.ResultShape.error

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 133。

```lean
Benitoite.Release.Refinement.ResultShape → Benitoite.Release.ConName
```

## Benitoite.Release.Refinement.ResultShape.errorType

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 134。

```lean
Benitoite.Release.Refinement.ResultShape → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ResultShape.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 130。

```lean
Benitoite.Release.DataName →
  Benitoite.Release.ConName →
    Benitoite.Release.ConName → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.ResultShape
```

## Benitoite.Release.Refinement.ResultShape.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 130。

```lean
{P : Sort u} →
  {owner : Benitoite.Release.DataName} →
    {ok error : Benitoite.Release.ConName} →
      {errorType : Benitoite.Release.Refinement.Ty} →
        {owner' : Benitoite.Release.DataName} →
          {ok' error' : Benitoite.Release.ConName} →
            {errorType' : Benitoite.Release.Refinement.Ty} →
              { owner := owner, ok := ok, error := error, errorType := errorType } =
                  { owner := owner', ok := ok', error := error', errorType := errorType' } →
                (owner = owner' → ok = ok' → error = error' → errorType = errorType' → P) → P
```

## Benitoite.Release.Refinement.ResultShape.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 130。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ResultShape} →
    t = t' → Benitoite.Release.Refinement.ResultShape.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ResultShape.ok

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 132。

```lean
Benitoite.Release.Refinement.ResultShape → Benitoite.Release.ConName
```

## Benitoite.Release.Refinement.ResultShape.owner

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 131。

```lean
Benitoite.Release.Refinement.ResultShape → Benitoite.Release.DataName
```

## Benitoite.Release.Refinement.SatAll

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 24。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.Refinement.TypeCtx → List Benitoite.Release.Refinement.Ty → List Benitoite.Release.TParam → Prop
```

## Benitoite.Release.Refinement.ScopeDeclarations.HasDeclarations

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 9。

```lean
Benitoite.Release.Refinement.Program → List Benitoite.Release.Refinement.StandardKeyTyping.DataDecl → Prop
```

## Benitoite.Release.Refinement.ScopeDeclarations.HasFile

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 28。

```lean
Benitoite.Release.Refinement.Program → Prop
```

## Benitoite.Release.Refinement.ScopeDeclarations.HasHttp

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 38。

```lean
Benitoite.Release.Refinement.Program → Prop
```

## Benitoite.Release.Refinement.ScopeDeclarations.HasHttp.file

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 40。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P → Benitoite.Release.Refinement.ScopeDeclarations.HasFile P
```

## Benitoite.Release.Refinement.ScopeDeclarations.clientRequest

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 31。

```lean
Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDeclarations.file

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 27。

```lean
List Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDeclarations.http

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 37。

```lean
List Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDeclarations.pair

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 30。

```lean
Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDeclarations.program

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 67。

```lean
Benitoite.Release.Refinement.Program
```

## Benitoite.Release.Refinement.ScopeDeclarations.program_arity

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 89。

```lean
∀ {d : Benitoite.Release.Refinement.StandardKeyTyping.DataDecl},
  d ∈ Benitoite.Release.Refinement.ScopeDeclarations.http →
    Benitoite.Release.Refinement.ScopeDeclarations.program.DataArity d.name d.ntys
```

## Benitoite.Release.Refinement.ScopeDeclarations.program_hasHttp

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 110。

```lean
Benitoite.Release.Refinement.ScopeDeclarations.HasHttp Benitoite.Release.Refinement.ScopeDeclarations.program
```

## Benitoite.Release.Refinement.ScopeDeclarations.program_wellFormed

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 122。

```lean
Benitoite.Release.Refinement.ScopeDeclarations.program.WellFormed
```

## Benitoite.Release.Refinement.ScopeDeclarations.requestCheckError

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 34。

```lean
Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDeclarations.result

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 14。

```lean
Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDeclarations.scopeError

所在: `formal/Benitoite/Release/Refinement/ScopeDeclarations.lean`、行: 17。

```lean
Benitoite.Release.Refinement.StandardKeyTyping.DataDecl
```

## Benitoite.Release.Refinement.ScopeDelta.checkTys

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 186。

```lean
Benitoite.Release.Refinement.RangeExpr → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeDelta.checked_annotation

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 31。

```lean
∀ {P : Benitoite.Release.Refinement.Program} (o : Benitoite.Release.OpaqueName)
  (r : Benitoite.Release.Refinement.RangeExpr),
  Benitoite.Release.Refinement.Ty.Annotation P [] []
      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) ∧
    Benitoite.Release.Refinement.Ty.HasKind P []
      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r))
      Benitoite.Release.Refinement.TyKind.value
```

## Benitoite.Release.Refinement.ScopeDelta.delta

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 214。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeDelta.error

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 188。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeDelta.errorValue

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 88。

```lean
String →
  String →
    Benitoite.Release.Integer64Value →
      Benitoite.Release.Integer64Value →
        Benitoite.Release.Integer64Value →
          Benitoite.Checked.Scope.ScopeError →
            optParam String Benitoite.Release.Refinement.ScopeDelta.text.PATH_PATTERN → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.ScopeDelta.error_safe

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 103。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ (pattern target : String) (lo hi port : Benitoite.Release.Integer64Value)
      (err : Benitoite.Checked.Scope.ScopeError)
      (patternReason : optParam String Benitoite.Release.Refinement.ScopeDelta.text.PATH_PATTERN),
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.ScopeDelta.errorValue pattern target lo hi port err patternReason)
          Benitoite.Release.Refinement.atErrorType ∧
        (Benitoite.Release.Refinement.ScopeDelta.errorValue pattern target lo hi port err patternReason).Ground ∧
          ∀ (σ : Benitoite.Release.Refinement.PathEnv),
            Benitoite.Release.Refinement.Val.Adequate σ
              (Benitoite.Release.Refinement.ScopeDelta.errorValue pattern target lo hi port err patternReason)
```

## Benitoite.Release.Refinement.ScopeDelta.input_errors

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 347。

```lean
∀ {pattern target : String} {p : Benitoite.Scope.Domain.PathPattern},
  Benitoite.Release.Refinement.ScopeDelta.parsePattern pattern = Option.some p →
    ∀ (r : Benitoite.Release.Refinement.RangeExpr),
      (∀ (w : Benitoite.Scope.Domain.Word),
          Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
                Option.some (Benitoite.Release.Refinement.TargetInput.relativePath w) ∨
              Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
                Option.some (Benitoite.Release.Refinement.TargetInput.homePath w) →
            Benitoite.Release.Refinement.ScopeDelta.run r
                [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern),
                  Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)] =
              Benitoite.Release.Refinement.ScopeDelta.error r
                (Benitoite.Release.Refinement.ScopeDelta.invalidTarget target
                  Benitoite.Release.Refinement.ScopeDelta.text.PATH)) ∧
        (Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
              (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
            Option.none →
          Benitoite.Release.Refinement.ScopeDelta.run r
              [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern),
                Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)] =
            Benitoite.Release.Refinement.ScopeDelta.error r
              (Benitoite.Release.Refinement.ScopeDelta.invalidTarget target
                Benitoite.Release.Refinement.ScopeDelta.text.PATH))
```

## Benitoite.Release.Refinement.ScopeDelta.invalidPattern

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 160。

```lean
String → optParam String Benitoite.Release.Refinement.ScopeDelta.text.PATH_PATTERN → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.ScopeDelta.invalidTarget

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 158。

```lean
String → String → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.ScopeDelta.invalidTarget_safe

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 163。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ (raw reason : String),
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.ScopeDelta.invalidTarget raw reason) Benitoite.Release.Refinement.atErrorType ∧
        (Benitoite.Release.Refinement.ScopeDelta.invalidTarget raw reason).Ground ∧
          ∀ (σ : Benitoite.Release.Refinement.PathEnv),
            Benitoite.Release.Refinement.Val.Adequate σ
              (Benitoite.Release.Refinement.ScopeDelta.invalidTarget raw reason)
```

## Benitoite.Release.Refinement.ScopeDelta.ok

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 187。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeDelta.parsePattern

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 174。

```lean
String → Option Benitoite.Scope.Domain.PathPattern
```

## Benitoite.Release.Refinement.ScopeDelta.pathInValue_response

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 103。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Scope.pathInValue"
        Benitoite.Release.Refinement.ScopeSignatures.pathInValue ts es rs ws a e →
      ∃ out,
        Benitoite.Release.Refinement.ScopeDelta.valueDelta "Scope.pathInValue" ts es rs ws = Option.some out ∧
          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ScopeDelta.pathValueRun

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 46。

```lean
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeDelta.pathValueRun_parseAtInput

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 54。

```lean
∀ {s : String} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s)) =
      Option.some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w)) →
    Benitoite.Release.Refinement.ScopeDelta.pathValueRun
        [Benitoite.Release.Refinement.Val.checked (Benitoite.Scope.Domain.Target.path w)] =
      Benitoite.Release.Refinement.Outcome.val
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s))
```

## Benitoite.Release.Refinement.ScopeDelta.path_target

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 15。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v
      (Benitoite.Release.Refinement.Ty.opaque "Scope.PathIn" (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      ∃ w, v.target? = Option.some (Benitoite.Scope.Domain.Target.path w)
```

## Benitoite.Release.Refinement.ScopeDelta.response

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 297。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valContent "Scope.PathIn" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Scope.checkPathIn"
            Benitoite.Release.Refinement.ScopeSignatures.checkPathIn ts es rs ws a e →
          ∃ out,
            Benitoite.Release.Refinement.ScopeDelta.delta "Scope.checkPathIn" ts es rs ws = Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ScopeDelta.resultShape

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 21。

```lean
Benitoite.Release.Refinement.ResultShape
```

## Benitoite.Release.Refinement.ScopeDelta.resultValue

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 37。

```lean
Bool →
  Benitoite.Release.Refinement.Ty →
    Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.ScopeDelta.result_declared

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 23。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ResultShape.Declared P Benitoite.Release.Refinement.ScopeDelta.resultShape
```

## Benitoite.Release.Refinement.ScopeDelta.result_safe

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 67。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {a e : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ (ok : Bool),
      Benitoite.Release.Refinement.Ty.Annotation P [] [] a →
        Benitoite.Release.Refinement.Ty.Annotation P [] [] e →
          Benitoite.Release.Refinement.Ty.HasKind P [] a Benitoite.Release.Refinement.TyKind.value →
            Benitoite.Release.Refinement.Ty.HasKind P [] e Benitoite.Release.Refinement.TyKind.value →
              a.norm = a →
                e.norm = e →
                  Benitoite.Release.Refinement.Ordinary a →
                    Benitoite.Release.Refinement.Ordinary e →
                      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v
                          (if ok = Bool.true then a else e) →
                        v.Ground →
                          Benitoite.Release.Refinement.AdequateResult ws (Benitoite.Release.Refinement.Outcome.val v) →
                            Benitoite.Release.Refinement.Outcome.Typed P B Ψ
                                (Benitoite.Release.Refinement.Outcome.val
                                  (Benitoite.Release.Refinement.ScopeDelta.resultValue ok a e v))
                                (Benitoite.Release.Refinement.Ty.data "Result" [a, e]) ∧
                              Benitoite.Release.Refinement.AdequateResult ws
                                  (Benitoite.Release.Refinement.Outcome.val
                                    (Benitoite.Release.Refinement.ScopeDelta.resultValue ok a e v)) ∧
                                (Benitoite.Release.Refinement.ScopeDelta.resultValue ok a e v).Ground ∧
                                  ∀ (n : Int),
                                    Benitoite.Release.Refinement.Outcome.val
                                        (Benitoite.Release.Refinement.ScopeDelta.resultValue ok a e v) ≠
                                      Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.ScopeDelta.result_typed

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 40。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {a e : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    ∀ (ok : Bool),
      Benitoite.Release.Refinement.Ty.Annotation P [] [] a →
        Benitoite.Release.Refinement.Ty.Annotation P [] [] e →
          Benitoite.Release.Refinement.Ty.HasKind P [] a Benitoite.Release.Refinement.TyKind.value →
            Benitoite.Release.Refinement.Ty.HasKind P [] e Benitoite.Release.Refinement.TyKind.value →
              a.norm = a →
                e.norm = e →
                  Benitoite.Release.Refinement.Ordinary a →
                    Benitoite.Release.Refinement.Ordinary e →
                      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v
                          (if ok = Bool.true then a else e) →
                        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
                          (Benitoite.Release.Refinement.ScopeDelta.resultValue ok a e v)
                          (Benitoite.Release.Refinement.Ty.data "Result" [a, e])
```

## Benitoite.Release.Refinement.ScopeDelta.run

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 195。

```lean
Benitoite.Release.Refinement.RangeExpr → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeDelta.run_absolute

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 334。

```lean
∀ {pattern target : String} {p : Benitoite.Scope.Domain.PathPattern} {t : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.ScopeDelta.parsePattern pattern = Option.some p →
    Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
        Option.some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path t)) →
      ∀ (r : Benitoite.Release.Refinement.RangeExpr),
        Benitoite.Release.Refinement.ScopeDelta.run r
            [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern),
              Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)] =
          match Benitoite.Checked.Scope.makePath p t with
          | Except.error err =>
            Benitoite.Release.Refinement.ScopeDelta.error r
              (Benitoite.Release.Refinement.ScopeDelta.errorValue pattern target
                Benitoite.Release.Refinement.ScopeDelta.zero✝ Benitoite.Release.Refinement.ScopeDelta.zero✝
                Benitoite.Release.Refinement.ScopeDelta.zero✝ err)
          | Except.ok a =>
            match r with
            | Benitoite.Release.Refinement.RangeExpr.absolute bound =>
              if
                  Benitoite.Scope.Domain.Range.MemK Benitoite.Scope.Domain.Kind.path bound
                    (Benitoite.Scope.Domain.Target.path t) then
                Benitoite.Release.Refinement.ScopeDelta.ok r
                  (Benitoite.Release.Refinement.Val.checked (Benitoite.Scope.Domain.Target.path t))
              else
                Benitoite.Release.Refinement.ScopeDelta.error r
                  (Benitoite.Release.Refinement.ScopeDelta.staticError
                    (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern))
                    (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) p t)
            | Benitoite.Release.Refinement.RangeExpr.based base pattern_1 =>
              Benitoite.Release.Refinement.ScopeDelta.error r
                (Benitoite.Release.Refinement.ScopeDelta.staticError
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern))
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) p t)
            | Benitoite.Release.Refinement.RangeExpr.secrets =>
              Benitoite.Release.Refinement.ScopeDelta.error r
                (Benitoite.Release.Refinement.ScopeDelta.staticError
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern))
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) p t)
```

## Benitoite.Release.Refinement.ScopeDelta.run_safe

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 238。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valContent "Scope.PathIn" = Option.none →
        ∀ (r : Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val),
          Benitoite.Release.Refinement.Outcome.Typed P B Ψ (Benitoite.Release.Refinement.ScopeDelta.run r ws)
              (Benitoite.Release.Refinement.Ty.data "Result" (Benitoite.Release.Refinement.ScopeDelta.checkTys r)) ∧
            Benitoite.Release.Refinement.AdequateResult ws (Benitoite.Release.Refinement.ScopeDelta.run r ws) ∧
              (∀ (v : Benitoite.Release.Refinement.Val),
                  Benitoite.Release.Refinement.ScopeDelta.run r ws = Benitoite.Release.Refinement.Outcome.val v →
                    v.Ground) ∧
                ∀ (n : Int),
                  Benitoite.Release.Refinement.ScopeDelta.run r ws ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.ScopeDelta.snapshot_kind

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 10。

```lean
∀ {snapshot : Option Benitoite.Release.Refinement.PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.SnapshotMem snapshot k r t → t.kind = k
```

## Benitoite.Release.Refinement.ScopeDelta.staticError

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 190。

```lean
Benitoite.Release.Refinement.Val →
  Benitoite.Release.Refinement.Val →
    Benitoite.Scope.Domain.PathPattern → Benitoite.Scope.Domain.Word → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.ScopeDelta.text.ENDPOINT_PATTERN

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 17。

```lean
String
```

## Benitoite.Release.Refinement.ScopeDelta.text.MAPPED_TARGET

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 18。

```lean
String
```

## Benitoite.Release.Refinement.ScopeDelta.text.PATH

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 15。

```lean
String
```

## Benitoite.Release.Refinement.ScopeDelta.text.PATH_PATTERN

所在: `formal/Benitoite/Release/Refinement/ScopeDelta.lean`、行: 16。

```lean
String
```

## Benitoite.Release.Refinement.ScopeDelta.valueDelta

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 72。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeDelta.widenPathIn_response

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 133。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  (∀ (r s : Benitoite.Release.Refinement.RangeExpr), B.admitsR "Scope.widenPathIn" [r, s] → s.Covers r) →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Scope.widenPathIn"
        Benitoite.Release.Refinement.ScopeSignatures.widenPathIn ts es rs ws a e →
      ∃ out,
        Benitoite.Release.Refinement.ScopeDelta.valueDelta "Scope.widenPathIn" ts es rs ws = Option.some out ∧
          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ScopeDelta.widenRun

所在: `formal/Benitoite/Release/Refinement/ScopeValueDelta.lean`、行: 67。

```lean
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeLegacyContracts.absolute_input

所在: `formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean`、行: 35。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path v =
      Option.some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w)) →
    ∀ (p : Benitoite.Scope.Domain.PathPattern) (r : Benitoite.Scope.Domain.Range),
      Benitoite.Release.Refinement.ScopeLegacyContracts.checkPath p v =
          Option.some (Benitoite.Checked.Scope.makePath p w) ∧
        Benitoite.Release.Refinement.ScopeLegacyContracts.checkPathIn p v
            (Benitoite.Release.Refinement.RangeExpr.absolute r) =
          Option.some
            (Benitoite.Release.Refinement.checkAt Option.none Benitoite.Scope.Domain.Kind.path
              (Benitoite.Release.Refinement.RangeExpr.path p)
              (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w))
              (Benitoite.Release.Refinement.RangeExpr.absolute r))
```

## Benitoite.Release.Refinement.ScopeLegacyContracts.checkPath

所在: `formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean`、行: 18。

```lean
Benitoite.Scope.Domain.PathPattern →
  Benitoite.Release.Refinement.Val →
    Option (Except Benitoite.Checked.Scope.ScopeError Benitoite.Checked.Scope.CheckedPath)
```

## Benitoite.Release.Refinement.ScopeLegacyContracts.checkPathIn

所在: `formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean`、行: 21。

```lean
Benitoite.Scope.Domain.PathPattern →
  Benitoite.Release.Refinement.Val →
    Benitoite.Release.Refinement.RangeExpr → Option Benitoite.Release.Refinement.AtResult
```

## Benitoite.Release.Refinement.ScopeLegacyContracts.pathInput

所在: `formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean`、行: 12。

```lean
Benitoite.Release.Refinement.Val → Option Benitoite.Scope.Domain.Word
```

## Benitoite.Release.Refinement.ScopeLegacyContracts.relative_rejected

所在: `formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean`、行: 27。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path v =
        Option.some (Benitoite.Release.Refinement.TargetInput.relativePath w) ∨
      Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path v =
        Option.some (Benitoite.Release.Refinement.TargetInput.homePath w) →
    ∀ (p : Benitoite.Scope.Domain.PathPattern) (bound : Benitoite.Release.Refinement.RangeExpr),
      Benitoite.Release.Refinement.ScopeLegacyContracts.pathInput v = Option.none ∧
        Benitoite.Release.Refinement.ScopeLegacyContracts.checkPath p v = Option.none ∧
          Benitoite.Release.Refinement.ScopeLegacyContracts.checkPathIn p v bound = Option.none
```

## Benitoite.Release.Refinement.ScopeModels.conditions

所在: `formal/Benitoite/Release/Refinement/ScopeModels.lean`、行: 9。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins ∧
      Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins ∧
        Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelHttp.builtins
```

## Benitoite.Release.Refinement.ScopeResponse.adequate_externalHandle

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 88。

```lean
∀ (h : Benitoite.Release.Refinement.ExternalHandle) (ts : List Benitoite.Release.Refinement.Ty)
  (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.externalHandle h ts))
```

## Benitoite.Release.Refinement.ScopeResponse.adequate_externalRef

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 84。

```lean
∀ (id : Benitoite.Release.Refinement.ExternalFunctionId) (ts : List Benitoite.Release.Refinement.Ty)
  (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.externalRef id ts))
```

## Benitoite.Release.Refinement.ScopeResponse.adequate_scopePattern

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 91。

```lean
∀ (r : Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.scopePattern r))
```

## Benitoite.Release.Refinement.ScopeResponse.delta

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 10。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ScopeResponse.delta_typed

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 47。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          ∃ out,
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta
                      io).delta
                  b ts es rs ws =
                Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P
                    (Benitoite.Release.Refinement.ScopeSignatures.builtins
                      Benitoite.Release.Refinement.ScopeResponse.delta io)
                    Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.ScopeResponse.ground

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 58。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws = Option.some out →
            out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ScopeResponse.leaves_unobserved

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 94。

```lean
∀ (id : Benitoite.Release.Refinement.ExternalFunctionId) (h : Benitoite.Release.Refinement.ExternalHandle)
  (ts : List Benitoite.Release.Refinement.Ty) (r : Benitoite.Release.Refinement.RangeExpr),
  (Benitoite.Release.Refinement.Val.externalRef id ts).toTerm? = Option.none ∧
    (Benitoite.Release.Refinement.Val.externalHandle h ts).toTerm? = Option.none ∧
      (Benitoite.Release.Refinement.Val.scopePattern r).toTerm? = Option.none ∧
        ∀ (pat : Benitoite.Release.Pat),
          Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.externalRef id ts)) =
              Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.externalHandle h ts)) ∧
            Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.externalHandle h ts)) =
              Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.scopePattern r))
```

## Benitoite.Release.Refinement.ScopeResponse.normal_facts

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 115。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws =
              Option.some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = Option.some t →
              ∀ (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

## Benitoite.Release.Refinement.ScopeResponse.outcome_typed

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 69。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws = Option.some out →
            Benitoite.Release.Refinement.Outcome.Typed P
                (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta
                  io)
                Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

