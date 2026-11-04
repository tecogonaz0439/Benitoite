# 段末の実署名

既定環境の完全な型を印字した。証明本体の評価ではない。

## Benitoite.Release.Model.assumptions

所在: `formal/Benitoite/Release/Model.lean`、行: 81。

```lean
∀ (P : Benitoite.Release.Program), Benitoite.Release.Builtins.Assumptions P Benitoite.Release.Model.builtins
```

## Benitoite.Release.ModelHttp.assumptions

所在: `formal/Benitoite/Release/ModelHttp.lean`、行: 442。

```lean
∀ (hostPat : String → Int → Int → Option Benitoite.Scope.Domain.Range)
  (reqTarget : Benitoite.Release.Val → Option Benitoite.Scope.Domain.Target) (P : Benitoite.Release.Program),
  Benitoite.Release.ModelHttp.HasHttp P →
    Benitoite.Release.Builtins.Assumptions P (Benitoite.Release.ModelHttp.builtins hostPat reqTarget)
```

## Benitoite.Release.ModelTargets.assumptions

所在: `formal/Benitoite/Release/ModelTargets.lean`、行: 345。

```lean
∀ (pat : String → Option Benitoite.Scope.Domain.Range) (tgt : String → Option Benitoite.Scope.Domain.Target)
  (P : Benitoite.Release.Program),
  Benitoite.Release.ModelTargets.HasResult P →
    Benitoite.Release.Builtins.Assumptions P (Benitoite.Release.ModelTargets.builtins pat tgt)
```

## Benitoite.Release.Refinement.AdequateResult

所在: `formal/Benitoite/Release/Refinement/Adequate.lean`、行: 85。

```lean
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome → Prop
```

## Benitoite.Release.Refinement.Arm

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 211。

```lean
Type
```

## Benitoite.Release.Refinement.Arm.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 213。

```lean
List Benitoite.Release.Alt →
  Option Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Arm
```

## Benitoite.Release.Refinement.Arm.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 213。

```lean
{P : Sort u} →
  {alts : List Benitoite.Release.Alt} →
    {guard : Option Benitoite.Release.Refinement.Comp} →
      {body : Benitoite.Release.Refinement.Comp} →
        {alts' : List Benitoite.Release.Alt} →
          {guard' : Option Benitoite.Release.Refinement.Comp} →
            {body' : Benitoite.Release.Refinement.Comp} →
              Benitoite.Release.Refinement.Arm.mk alts guard body =
                  Benitoite.Release.Refinement.Arm.mk alts' guard' body' →
                (alts = alts' → guard = guard' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Arm.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 211。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Arm} → t = t' → Benitoite.Release.Refinement.Arm.noConfusionType P t t'
```

## Benitoite.Release.Refinement.AtCallAdmissible.fixed_index

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 76。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {shape : Benitoite.Release.Refinement.ResultShape}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index →
    ∃ r, index = Benitoite.Release.Refinement.RangeIx.fixed r
```

## Benitoite.Release.Refinement.AtCallAdmissible.no_staticIndex

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 81。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {shape : Benitoite.Release.Refinement.ResultShape}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {cap : Benitoite.Release.Refinement.Capture}
  {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index →
    Benitoite.Release.Refinement.AtPrepare B cap kind name bases pattern input index = Except.error detail →
      detail.failure ≠ Benitoite.Release.Refinement.AtFailure.staticIndex
```

## Benitoite.Release.Refinement.AtCheckError

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 152。

```lean
Type
```

## Benitoite.Release.Refinement.AtCheckError.failure

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 154。

```lean
Benitoite.Release.Refinement.AtCheckError → Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtCheckError.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 153。

```lean
Benitoite.Release.Refinement.AtFailure →
  Benitoite.Release.Refinement.RangeExpr →
    Benitoite.Release.Refinement.TargetInput →
      Option (List Benitoite.Scope.Domain.Range) →
        Option Benitoite.Scope.Domain.Target →
          Option Benitoite.Release.Refinement.PathBase →
            Option Benitoite.Release.Refinement.PathBase → Benitoite.Release.Refinement.AtCheckError
```

## Benitoite.Release.Refinement.AtCheckError.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 153。

```lean
{P : Sort u} →
  {failure : Benitoite.Release.Refinement.AtFailure} →
    {parsedPattern : Benitoite.Release.Refinement.RangeExpr} →
      {parsedTarget : Benitoite.Release.Refinement.TargetInput} →
        {resolvedPatterns : Option (List Benitoite.Scope.Domain.Range)} →
          {resolvedTarget : Option Benitoite.Scope.Domain.Target} →
            {patternBase targetBase : Option Benitoite.Release.Refinement.PathBase} →
              {failure' : Benitoite.Release.Refinement.AtFailure} →
                {parsedPattern' : Benitoite.Release.Refinement.RangeExpr} →
                  {parsedTarget' : Benitoite.Release.Refinement.TargetInput} →
                    {resolvedPatterns' : Option (List Benitoite.Scope.Domain.Range)} →
                      {resolvedTarget' : Option Benitoite.Scope.Domain.Target} →
                        {patternBase' targetBase' : Option Benitoite.Release.Refinement.PathBase} →
                          { failure := failure, parsedPattern := parsedPattern, parsedTarget := parsedTarget,
                                resolvedPatterns := resolvedPatterns, resolvedTarget := resolvedTarget,
                                patternBase := patternBase, targetBase := targetBase } =
                              { failure := failure', parsedPattern := parsedPattern', parsedTarget := parsedTarget',
                                resolvedPatterns := resolvedPatterns', resolvedTarget := resolvedTarget',
                                patternBase := patternBase', targetBase := targetBase' } →
                            (failure = failure' →
                                parsedPattern = parsedPattern' →
                                  parsedTarget = parsedTarget' →
                                    resolvedPatterns = resolvedPatterns' →
                                      resolvedTarget = resolvedTarget' →
                                        patternBase = patternBase' → targetBase = targetBase' → P) →
                              P
```

## Benitoite.Release.Refinement.AtCheckError.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 152。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.AtCheckError} →
    t = t' → Benitoite.Release.Refinement.AtCheckError.noConfusionType P t t'
```

## Benitoite.Release.Refinement.AtCheckError.parsedPattern

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 155。

```lean
Benitoite.Release.Refinement.AtCheckError → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.AtCheckError.parsedTarget

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 156。

```lean
Benitoite.Release.Refinement.AtCheckError → Benitoite.Release.Refinement.TargetInput
```

## Benitoite.Release.Refinement.AtCheckError.patternBase

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 159。

```lean
Benitoite.Release.Refinement.AtCheckError → Option Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.AtCheckError.resolvedPatterns

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 157。

```lean
Benitoite.Release.Refinement.AtCheckError → Option (List Benitoite.Scope.Domain.Range)
```

## Benitoite.Release.Refinement.AtCheckError.resolvedTarget

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 158。

```lean
Benitoite.Release.Refinement.AtCheckError → Option Benitoite.Scope.Domain.Target
```

## Benitoite.Release.Refinement.AtCheckError.targetBase

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 160。

```lean
Benitoite.Release.Refinement.AtCheckError → Option Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.AtError

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 221。

```lean
Type
```

## Benitoite.Release.Refinement.AtError.fromCheck

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 235。

```lean
Benitoite.Release.Refinement.Val →
  Benitoite.Release.Refinement.Val →
    Option Benitoite.Release.Refinement.PathEnv →
      Benitoite.Release.Refinement.RangeExpr →
        Benitoite.Release.Refinement.TargetInput →
          Benitoite.Release.Refinement.AtCheckError → Benitoite.Release.Refinement.AtError
```

## Benitoite.Release.Refinement.AtError.save

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 223。

```lean
Benitoite.Release.Refinement.Val →
  Benitoite.Release.Refinement.Val →
    Option Benitoite.Release.Refinement.PathEnv →
      Option Benitoite.Release.Refinement.RangeExpr →
        Option Benitoite.Release.Refinement.TargetInput →
          Benitoite.Release.Refinement.AtFailure → Benitoite.Release.Refinement.AtError
```

## Benitoite.Release.Refinement.AtError.save_exact

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 361。

```lean
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

## Benitoite.Release.Refinement.AtErrorReaders.check_reader

所在: `formal/Benitoite/Release/Refinement/AtErrorReaders.lean`、行: 42。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    ∀ (p t : Benitoite.Release.Refinement.Val) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
      (pat : Benitoite.Release.Refinement.RangeExpr) (target : Benitoite.Release.Refinement.TargetInput)
      (d : Benitoite.Release.Refinement.AtCheckError),
      have saved := Benitoite.Release.Refinement.AtError.fromCheck p t snapshot pat target d;
      saved.originalPattern = p ∧
        saved.originalTarget = t ∧
          saved.failure = d.failure ∧
            saved.parsedPattern = Option.some pat ∧
              saved.parsedTarget = Option.some target ∧
                saved.resolvedPatterns = Benitoite.Release.Refinement.resolveSnapshot snapshot pat ∧
                  saved.resolvedTarget = Benitoite.Release.Refinement.resolveTargetSnapshot snapshot target ∧
                    saved.patternBase = pat.base? ∧
                      saved.targetBase = target.base? ∧
                        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ
                            (Benitoite.Release.Refinement.Val.atError saved) Benitoite.Release.Refinement.atErrorType ∧
                          (∀ (term : Benitoite.Release.Refinement.Term),
                              (Benitoite.Release.Refinement.Val.atError saved).toTerm? = Option.some term →
                                Benitoite.Release.Refinement.Term.Declared P C Γ term) ∧
                            Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                                  (Benitoite.Release.Refinement.Val.atError saved) =
                                Option.some (Benitoite.Release.Refinement.Detail.values saved) ∧
                              Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ
                                  (Benitoite.Release.Refinement.Detail.values saved)
                                  Benitoite.Release.Refinement.atErrorFields ∧
                                ∀ (ws : List Benitoite.Release.Refinement.Val),
                                  Benitoite.Release.Refinement.AdequateResult ws
                                    (Benitoite.Release.Refinement.Outcome.val
                                      (Benitoite.Release.Refinement.Val.atError saved))
```

## Benitoite.Release.Refinement.AtErrorReaders.observed

所在: `formal/Benitoite/Release/Refinement/AtErrorReaders.lean`、行: 9。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    ∀ (d : Benitoite.Release.Refinement.AtError),
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.atError d)
          Benitoite.Release.Refinement.atErrorType ∧
        (∀ (t : Benitoite.Release.Refinement.Term),
            (Benitoite.Release.Refinement.Val.atError d).toTerm? = Option.some t →
              Benitoite.Release.Refinement.Term.Declared P C Γ t) ∧
          Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                (Benitoite.Release.Refinement.Val.atError d) =
              Option.some (Benitoite.Release.Refinement.Detail.values d) ∧
            Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Detail.values d)
                Benitoite.Release.Refinement.atErrorFields ∧
              ∀ (ws : List Benitoite.Release.Refinement.Val),
                Benitoite.Release.Refinement.AdequateResult ws
                  (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError d))
```

## Benitoite.Release.Refinement.AtErrorReaders.prepare_reader

所在: `formal/Benitoite/Release/Refinement/AtErrorReaders.lean`、行: 21。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {shape : Benitoite.Release.Refinement.ResultShape}
  {cap : Benitoite.Release.Refinement.Capture} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {d : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    Benitoite.Release.Refinement.AtPrepare B cap kind name bases pattern input index = Except.error d →
      d.originalPattern = Benitoite.Release.Refinement.closeVal cap pattern ∧
        d.originalTarget = Benitoite.Release.Refinement.closeVal cap input ∧
          (∃ snapshot pp pt,
              d =
                  Benitoite.Release.Refinement.AtError.save (Benitoite.Release.Refinement.closeVal cap pattern)
                    (Benitoite.Release.Refinement.closeVal cap input) snapshot pp pt d.failure ∧
                d.parsedPattern = pp ∧
                  d.parsedTarget = pt ∧
                    d.resolvedPatterns = pp.bind (Benitoite.Release.Refinement.resolveSnapshot snapshot) ∧
                      d.resolvedTarget = pt.bind (Benitoite.Release.Refinement.resolveTargetSnapshot snapshot) ∧
                        d.patternBase = pp.bind Benitoite.Release.Refinement.RangeExpr.base? ∧
                          d.targetBase = pt.bind Benitoite.Release.Refinement.TargetInput.base?) ∧
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.atError d)
                Benitoite.Release.Refinement.atErrorType ∧
              (∀ (t : Benitoite.Release.Refinement.Term),
                  (Benitoite.Release.Refinement.Val.atError d).toTerm? = Option.some t →
                    Benitoite.Release.Refinement.Term.Declared P C Γ t) ∧
                Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                      (Benitoite.Release.Refinement.Val.atError d) =
                    Option.some (Benitoite.Release.Refinement.Detail.values d) ∧
                  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Detail.values d)
                      Benitoite.Release.Refinement.atErrorFields ∧
                    ∀ (ws : List Benitoite.Release.Refinement.Val),
                      Benitoite.Release.Refinement.AdequateResult ws
                        (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError d))
```

## Benitoite.Release.Refinement.AtFailure

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 142。

```lean
Type
```

## Benitoite.Release.Refinement.AtFailure.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 142。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.AtFailure) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.AtFailure.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.AtFailure.dynamicCondition

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 148。

```lean
Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.dynamicCondition.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 148。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 5 → motive Benitoite.Release.Refinement.AtFailure.dynamicCondition → motive t
```

## Benitoite.Release.Refinement.AtFailure.invalidPattern

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 146。

```lean
Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.invalidPattern.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 146。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.AtFailure.invalidPattern → motive t
```

## Benitoite.Release.Refinement.AtFailure.invalidTarget

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 147。

```lean
Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.invalidTarget.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 147。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.AtFailure.invalidTarget → motive t
```

## Benitoite.Release.Refinement.AtFailure.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 142。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.AtFailure} →
    t = t' → Benitoite.Release.Refinement.AtFailure.noConfusionType P t t'
```

## Benitoite.Release.Refinement.AtFailure.outsideScope

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 143。

```lean
Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.outsideScope.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 143。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.AtFailure.outsideScope → motive t
```

## Benitoite.Release.Refinement.AtFailure.secretsUnbound

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 145。

```lean
Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.secretsUnbound.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 145。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.AtFailure.secretsUnbound → motive t
```

## Benitoite.Release.Refinement.AtFailure.staticIndex

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 149。

```lean
Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.staticIndex.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 149。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 6 → motive Benitoite.Release.Refinement.AtFailure.staticIndex → motive t
```

## Benitoite.Release.Refinement.AtFailure.unbound

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 144。

```lean
Benitoite.Release.Refinement.PathBase → Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.AtFailure.unbound.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 144。

```lean
{motive : Benitoite.Release.Refinement.AtFailure → Sort u} →
  (t : Benitoite.Release.Refinement.AtFailure) →
    t.ctorIdx = 1 →
      ((base : Benitoite.Release.Refinement.PathBase) → motive (Benitoite.Release.Refinement.AtFailure.unbound base)) →
        motive t
```

## Benitoite.Release.Refinement.AtFailure.unbound.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 144。

```lean
{P : Sort u} →
  {base base' : Benitoite.Release.Refinement.PathBase} →
    Benitoite.Release.Refinement.AtFailure.unbound base = Benitoite.Release.Refinement.AtFailure.unbound base' →
      (base = base' → P) → P
```

## Benitoite.Release.Refinement.AtPrepare

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 148。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.Refinement.Capture →
    Benitoite.Scope.Domain.Kind →
      Benitoite.Release.OpaqueName →
        Option Benitoite.Release.Refinement.Val →
          Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Val →
              Benitoite.Release.Refinement.RangeIx →
                Except Benitoite.Release.Refinement.AtError
                  (Option Benitoite.Release.Refinement.PathEnv ×
                    Benitoite.Release.Refinement.RangeExpr ×
                      Benitoite.Release.Refinement.TargetInput × Benitoite.Release.Refinement.RangeExpr)
```

## Benitoite.Release.Refinement.AtPrepare.error_saved

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 424。

```lean
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

## Benitoite.Release.Refinement.AtPrepare.fixed_index

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 347。

```lean
∀ {index : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.RangeIx.WF 0 index → ∃ bound, index = Benitoite.Release.Refinement.RangeIx.fixed bound
```

## Benitoite.Release.Refinement.AtPrepare.no_staticIndex

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 352。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.RangeIx.WF 0 index →
    Benitoite.Release.Refinement.AtPrepare B cap kind name bases pattern input index = Except.error detail →
      detail.failure ≠ Benitoite.Release.Refinement.AtFailure.staticIndex
```

## Benitoite.Release.Refinement.AtPrepared

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 157。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.Refinement.Capture →
    Benitoite.Scope.Domain.Kind →
      Benitoite.Release.OpaqueName →
        Option Benitoite.Release.Refinement.Val →
          Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Val →
              Benitoite.Release.Refinement.RangeIx →
                Option Benitoite.Release.Refinement.PathEnv →
                  Benitoite.Release.Refinement.RangeExpr →
                    Benitoite.Release.Refinement.TargetInput → Benitoite.Release.Refinement.RangeExpr → Prop
```

## Benitoite.Release.Refinement.AtPrepared.current

所在: `formal/Benitoite/Release/Refinement/PathBasesTargets.lean`、行: 7。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {σ : Benitoite.Release.Refinement.PathEnv}
  {cap : Benitoite.Release.Refinement.Capture} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {bs : Option Benitoite.Release.Refinement.Val}
  {p v : Benitoite.Release.Refinement.Val} {ix : Benitoite.Release.Refinement.RangeIx}
  {snap : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.Capture.Adequate σ cap →
    (∀ (b : Benitoite.Release.Refinement.Val), bs = Option.some b → Benitoite.Release.Refinement.Val.Adequate σ b) →
      Benitoite.Release.Refinement.AtPrepared B cap kind name bs p v ix snap pat t bound →
        ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = Option.some ρ → ρ = σ
```

## Benitoite.Release.Refinement.AtPrepared.fixed_index

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 173。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    index = Benitoite.Release.Refinement.RangeIx.fixed bound
```

## Benitoite.Release.Refinement.AtPrepared.formed

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 255。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    (pat.FitsKind kind ∧ pat.WF ∧ pat.Canonical) ∧
      (bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical) ∧
        (snapshot = Option.none →
          ∃ p t b,
            pat = Benitoite.Release.Refinement.RangeExpr.absolute p ∧
              target = Benitoite.Release.Refinement.TargetInput.absolute t ∧
                bound = Benitoite.Release.Refinement.RangeExpr.absolute b)
```

## Benitoite.Release.Refinement.AtPrepared.no_invalidPattern

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 22。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr} {detail : Benitoite.Release.Refinement.AtCheckError},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
        Benitoite.Release.Refinement.AtResult.error detail →
      detail.failure ≠ Benitoite.Release.Refinement.AtFailure.invalidPattern
```

## Benitoite.Release.Refinement.AtPrepared.of_path_bases

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 162。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases pattern input : Benitoite.Release.Refinement.Val} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {σ : Benitoite.Release.Refinement.PathEnv},
  B.valKind name = Option.some kind →
    B.valContent name = Option.none →
      Benitoite.Release.Refinement.parseAtPattern kind (Benitoite.Release.Refinement.closeVal cap pattern) =
          Option.some pat →
        Benitoite.Release.Refinement.parseAtInput kind (Benitoite.Release.Refinement.closeVal cap input) =
            Option.some target →
          Benitoite.Release.Refinement.closeVal cap bases = Benitoite.Release.Refinement.Val.pathBases σ →
            σ.Valid →
              bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical →
                Benitoite.Release.Refinement.AtPrepared B cap kind name (Option.some bases) pattern input
                  (Benitoite.Release.Refinement.RangeIx.fixed bound) (Option.some σ) pat target bound
```

## Benitoite.Release.Refinement.AtPrepared.origins

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 294。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    (B.valContent name = Option.none ∧
          Benitoite.Release.Refinement.parseAtInput kind (Benitoite.Release.Refinement.closeVal cap input) =
            Option.some target ∨
        ∃ T t,
          B.valContent name = Option.some T ∧
            Benitoite.Release.Refinement.groundVal (Benitoite.Release.Refinement.closeVal cap input) = Bool.true ∧
              (Benitoite.Release.Refinement.closeVal cap input).reqTarget = Option.some t ∧
                target = Benitoite.Release.Refinement.TargetInput.absolute t) ∧
      (bases = Option.none ∧ snapshot = Option.none ∨
        ∃ b σ,
          bases = Option.some b ∧
            Benitoite.Release.Refinement.closeVal cap b = Benitoite.Release.Refinement.Val.pathBases σ ∧
              σ.Valid ∧ snapshot = Option.some σ)
```

## Benitoite.Release.Refinement.AtPrepared.request

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 184。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr} {T : Benitoite.Release.Refinement.Ty},
  B.valContent name = Option.some T →
    Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
      Benitoite.Release.Refinement.groundVal (Benitoite.Release.Refinement.closeVal cap input) = Bool.true ∧
        ∃ t,
          (Benitoite.Release.Refinement.closeVal cap input).reqTarget = Option.some t ∧
            target = Benitoite.Release.Refinement.TargetInput.absolute t
```

## Benitoite.Release.Refinement.AtPrepared.resolution

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 7。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    (∃ t, Benitoite.Release.Refinement.resolveTargetSnapshot snapshot target = Option.some t) ∧
      (snapshot = Option.none →
        (∃ ps, Benitoite.Release.Refinement.resolveSnapshot snapshot pat = Option.some ps) ∧
          ∃ bs, Benitoite.Release.Refinement.resolveSnapshot snapshot bound = Option.some bs)
```

## Benitoite.Release.Refinement.AtPrepared.snapshot_source

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 217。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr} {ρ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
    snapshot = Option.some ρ →
      ∃ b,
        bases = Option.some b ∧
          Benitoite.Release.Refinement.closeVal cap b = Benitoite.Release.Refinement.Val.pathBases ρ
```

## Benitoite.Release.Refinement.AtRequest

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 78。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.OpaqueName → Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.AtResult

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 71。

```lean
Type
```

## Benitoite.Release.Refinement.AtResult.ctorElim

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 71。

```lean
{motive : Benitoite.Release.Refinement.AtResult → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.AtResult) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.AtResult.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.AtResult.error

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 73。

```lean
Benitoite.Release.Refinement.AtCheckError → Benitoite.Release.Refinement.AtResult
```

## Benitoite.Release.Refinement.AtResult.error.elim

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 73。

```lean
{motive : Benitoite.Release.Refinement.AtResult → Sort u} →
  (t : Benitoite.Release.Refinement.AtResult) →
    t.ctorIdx = 1 →
      ((detail : Benitoite.Release.Refinement.AtCheckError) →
          motive (Benitoite.Release.Refinement.AtResult.error detail)) →
        motive t
```

## Benitoite.Release.Refinement.AtResult.error.noConfusion

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 73。

```lean
{P : Sort u} →
  {detail detail' : Benitoite.Release.Refinement.AtCheckError} →
    Benitoite.Release.Refinement.AtResult.error detail = Benitoite.Release.Refinement.AtResult.error detail' →
      (detail = detail' → P) → P
```

## Benitoite.Release.Refinement.AtResult.noConfusion

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 71。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.AtResult} → t = t' → Benitoite.Release.Refinement.AtResult.noConfusionType P t t'
```

## Benitoite.Release.Refinement.AtResult.ok

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 72。

```lean
Benitoite.Scope.Domain.Target → Benitoite.Release.Refinement.AtResult
```

## Benitoite.Release.Refinement.AtResult.ok.elim

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 72。

```lean
{motive : Benitoite.Release.Refinement.AtResult → Sort u} →
  (t : Benitoite.Release.Refinement.AtResult) →
    t.ctorIdx = 0 →
      ((target : Benitoite.Scope.Domain.Target) → motive (Benitoite.Release.Refinement.AtResult.ok target)) → motive t
```

## Benitoite.Release.Refinement.AtResult.ok.noConfusion

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 72。

```lean
{P : Sort u} →
  {target target' : Benitoite.Scope.Domain.Target} →
    Benitoite.Release.Refinement.AtResult.ok target = Benitoite.Release.Refinement.AtResult.ok target' →
      (target = target' → P) → P
```

## Benitoite.Release.Refinement.AtTargets.adequate_atError

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 71。

```lean
∀ (detail : Benitoite.Release.Refinement.AtError) (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError detail))
```

## Benitoite.Release.Refinement.Atom

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 40。

```lean
Type
```

## Benitoite.Release.Refinement.Atom.covers_fixed_iff

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 9。

```lean
∀ {a : Benitoite.Release.Refinement.Atom} {l : Benitoite.Release.EffName} {r : Benitoite.Release.Refinement.RangeExpr},
  a.Covers (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed r)) ↔
    ∃ s, a = Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed s) ∧ s.Covers r
```

## Benitoite.Release.Refinement.Atom.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 40。

```lean
{motive : Benitoite.Release.Refinement.Atom → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Atom) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Atom.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Atom.name

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 41。

```lean
Benitoite.Release.EffName → Benitoite.Release.Refinement.RangeIx → Benitoite.Release.Refinement.Atom
```

## Benitoite.Release.Refinement.Atom.name.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 41。

```lean
{motive : Benitoite.Release.Refinement.Atom → Sort u} →
  (t : Benitoite.Release.Refinement.Atom) →
    t.ctorIdx = 0 →
      ((effect : Benitoite.Release.EffName) →
          (index : Benitoite.Release.Refinement.RangeIx) →
            motive (Benitoite.Release.Refinement.Atom.name effect index)) →
        motive t
```

## Benitoite.Release.Refinement.Atom.name.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 41。

```lean
{P : Sort u} →
  {effect : Benitoite.Release.EffName} →
    {index : Benitoite.Release.Refinement.RangeIx} →
      {effect' : Benitoite.Release.EffName} →
        {index' : Benitoite.Release.Refinement.RangeIx} →
          Benitoite.Release.Refinement.Atom.name effect index = Benitoite.Release.Refinement.Atom.name effect' index' →
            (effect = effect' → index = index' → P) → P
```

## Benitoite.Release.Refinement.Atom.nameTop

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 45。

```lean
Benitoite.Release.EffName → Benitoite.Release.Refinement.Atom
```

## Benitoite.Release.Refinement.Atom.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 40。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Atom} → t = t' → Benitoite.Release.Refinement.Atom.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Atom.rho

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 42。

```lean
Nat → Benitoite.Release.Refinement.Atom
```

## Benitoite.Release.Refinement.Atom.rho.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 42。

```lean
{motive : Benitoite.Release.Refinement.Atom → Sort u} →
  (t : Benitoite.Release.Refinement.Atom) →
    t.ctorIdx = 1 → ((index : Nat) → motive (Benitoite.Release.Refinement.Atom.rho index)) → motive t
```

## Benitoite.Release.Refinement.Atom.rho.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 42。

```lean
{P : Sort u} →
  {index index' : Nat} →
    Benitoite.Release.Refinement.Atom.rho index = Benitoite.Release.Refinement.Atom.rho index' →
      (index = index' → P) → P
```

## Benitoite.Release.Refinement.Atom.toOld?

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 52。

```lean
Benitoite.Release.Refinement.Atom → Option Benitoite.Release.Atom
```

## Benitoite.Release.Refinement.Atom.toOld?_embed

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 58。

```lean
∀ (a : Benitoite.Release.Atom), (Benitoite.Release.Refinement.embedAtom a).toOld? = Option.some a
```

## Benitoite.Release.Refinement.Atom.toOld?_sound

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 61。

```lean
∀ {a : Benitoite.Release.Refinement.Atom} {b : Benitoite.Release.Atom},
  a.toOld? = Option.some b → Benitoite.Release.Refinement.embedAtom b = a
```

## Benitoite.Release.Refinement.BinderTypes.TargetWF

所在: `formal/Benitoite/Release/Refinement/PrimitiveScoped.lean`、行: 12。

```lean
Nat → Nat → Nat → List Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.BuilderKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 70。

```lean
Type
```

## Benitoite.Release.Refinement.BuilderKind.bytes

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
Benitoite.Release.Refinement.BuilderKind
```

## Benitoite.Release.Refinement.BuilderKind.bytes.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
{motive : Benitoite.Release.Refinement.BuilderKind → Sort u} →
  (t : Benitoite.Release.Refinement.BuilderKind) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.BuilderKind.bytes → motive t
```

## Benitoite.Release.Refinement.BuilderKind.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 70。

```lean
{motive : Benitoite.Release.Refinement.BuilderKind → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.BuilderKind) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.BuilderKind.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.BuilderKind.list

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.BuilderKind
```

## Benitoite.Release.Refinement.BuilderKind.list.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
{motive : Benitoite.Release.Refinement.BuilderKind → Sort u} →
  (t : Benitoite.Release.Refinement.BuilderKind) →
    t.ctorIdx = 1 →
      ((element : Benitoite.Release.Refinement.Ty) → motive (Benitoite.Release.Refinement.BuilderKind.list element)) →
        motive t
```

## Benitoite.Release.Refinement.BuilderKind.list.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
{P : Sort u} →
  {element element' : Benitoite.Release.Refinement.Ty} →
    Benitoite.Release.Refinement.BuilderKind.list element = Benitoite.Release.Refinement.BuilderKind.list element' →
      (element = element' → P) → P
```

## Benitoite.Release.Refinement.BuilderKind.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 70。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.BuilderKind} →
    t = t' → Benitoite.Release.Refinement.BuilderKind.noConfusionType P t t'
```

## Benitoite.Release.Refinement.BuilderKind.norm

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 77。

```lean
Benitoite.Release.Refinement.BuilderKind → Benitoite.Release.Refinement.BuilderKind
```

## Benitoite.Release.Refinement.BuilderKind.string

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
Benitoite.Release.Refinement.BuilderKind
```

## Benitoite.Release.Refinement.BuilderKind.string.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 71。

```lean
{motive : Benitoite.Release.Refinement.BuilderKind → Sort u} →
  (t : Benitoite.Release.Refinement.BuilderKind) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.BuilderKind.string → motive t
```

## Benitoite.Release.Refinement.BuilderOp

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 68。

```lean
Type
```

## Benitoite.Release.Refinement.BuiltinArgs

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 9。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.PrimName →
        Benitoite.Release.Refinement.PrimSig →
          List Benitoite.Release.Refinement.Ty →
            List Benitoite.Release.Refinement.Eff →
              List Benitoite.Release.Refinement.RangeExpr →
                List Benitoite.Release.Refinement.Val →
                  Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.BuiltinArgs.normalized

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 29。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es →
    B.RangeAdmissible b sg rs →
      Benitoite.Release.Refinement.SignatureInstance P [] [] (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
          (List.map Benitoite.Release.Refinement.TParamDecl.kind sg.tparams) ts es →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es) a
            e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground) →
            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
              (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.alteredLeaves

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 68。

```lean
List (List Benitoite.Release.Refinement.Pred × Benitoite.Release.Refinement.PreparedLeaf)
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.altered_leaves_rejected

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 83。

```lean
Benitoite.Release.Refinement.BuiltinLogicExamples.alteredLeaves.length = 6 ∧
  (Benitoite.Release.Refinement.BuiltinLogicExamples.alteredLeaves.all fun x =>
      match x with
      | (Φ, l) => !Benitoite.Release.Refinement.PreparedLeaf.checkRaw Φ l) =
    Bool.true
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.classes_12

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 40。

```lean
Benitoite.Release.Refinement.BuiltinLogicExamples.closedClasses.length = 12 ∧
  (Benitoite.Release.Refinement.BuiltinLogicExamples.closedClasses.all fun p => p.evalClosed == Option.some Bool.true) =
    Bool.true
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.closedClasses

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 27。

```lean
List Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.closedComparisonBoundaries

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 21。

```lean
List (Benitoite.Release.Refinement.Pred × Bool)
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.closedComparisons

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 11。

```lean
List (Benitoite.Release.Refinement.Pred × Bool)
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.comparison_boundaries_48

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 37。

```lean
Benitoite.Release.Refinement.BuiltinLogicExamples.closedComparisonBoundaries.length = 48 ∧
  (Benitoite.Release.Refinement.BuiltinLogicExamples.closedComparisonBoundaries.all fun x =>
      match x with
      | (p, b) => p.evalClosed == Option.some b) =
    Bool.true
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.comparisons_30

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 34。

```lean
Benitoite.Release.Refinement.BuiltinLogicExamples.closedComparisons.length = 30 ∧
  (Benitoite.Release.Refinement.BuiltinLogicExamples.closedComparisons.all fun x =>
      match x with
      | (p, b) => p.evalClosed == Option.some b) =
    Bool.true
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.registered_samples

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 64。

```lean
Benitoite.Release.Refinement.BuiltinLogicExamples.samples.length = 12 ∧
  (Benitoite.Release.Refinement.BuiltinLogicExamples.samples.all fun x =>
        match x with
        | (Φ, l) => Benitoite.Release.Refinement.PreparedLeaf.checkRaw Φ l) =
      Bool.true ∧
    (Benitoite.Release.Refinement.BuiltinLogicExamples.samples.all fun x =>
        match x with
        | (Φ, l) =>
          !Benitoite.Release.Refinement.PreparedLeaf.checkRaw Φ
              { predicate := Benitoite.Release.Refinement.Pred.falsity, lemma := l.lemma, arguments := l.arguments,
                references := l.references }) =
      Bool.true
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.registry

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 86。

```lean
List (List Benitoite.Release.Refinement.PreparedLeaf)
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.registry_100

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 92。

```lean
List.map List.length Benitoite.Release.Refinement.BuiltinLogicExamples.registry =
    [1, 1, 7, 2, 22, 1, 1, 16, 30, 1, 6, 12] ∧
  Benitoite.Release.Refinement.BuiltinLogicExamples.registry.flatten.length = 100 ∧
    Benitoite.Release.Refinement.BuiltinLogicExamples.registry.flatten.all
        (Benitoite.Release.Refinement.PreparedLeaf.checkRaw []) =
      Bool.true
```

## Benitoite.Release.Refinement.BuiltinLogicExamples.samples

所在: `formal/Benitoite/Release/Refinement/BuiltinLogicExamples.lean`、行: 43。

```lean
List (List Benitoite.Release.Refinement.Pred × Benitoite.Release.Refinement.PreparedLeaf)
```

## Benitoite.Release.Refinement.BuiltinOnly

所在: `formal/Benitoite/Release/Refinement/StateTyping.lean`、行: 155。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.BuiltinSchema.candidates_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 93。

```lean
∀ {lemma : Benitoite.Release.Refinement.BuiltinLemma} {args : List Benitoite.Release.Refinement.Term}
  {p : Benitoite.Release.Refinement.Pred},
  p ∈ Benitoite.Release.Refinement.BuiltinSchema.candidates lemma args →
    ∀ (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
      Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.predBind ν p) = Bool.true
```

## Benitoite.Release.Refinement.BuiltinSchema.characterCompare_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 24。

```lean
∀ (o : Benitoite.Release.Refinement.Comparison) (a b : Benitoite.Release.Refinement.Term)
  (ν : Benitoite.Release.Refinement.ObservationEnv) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.Pred.interpret η
      (Benitoite.Release.Refinement.predBind ν (Benitoite.Release.Refinement.BuiltinSchema.characterCompare o a b)) =
    Bool.true
```

## Benitoite.Release.Refinement.BuiltinSchema.eqComplement_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 79。

```lean
∀ {s : Benitoite.Release.Refinement.Sort},
  s ∈ Benitoite.Release.Refinement.scalarSorts →
    ∀ (a b : Benitoite.Release.Refinement.Term) (ν : Benitoite.Release.Refinement.ObservationEnv)
      (η : Benitoite.Release.Refinement.ObservationEnvModel),
      Benitoite.Release.Refinement.Pred.interpret η
          (Benitoite.Release.Refinement.predBind ν
            (Benitoite.Release.Refinement.Pred.compare s Benitoite.Release.Refinement.Comparison.ne a b)) =
        Benitoite.Release.Refinement.Pred.interpret η
          (Benitoite.Release.Refinement.predBind ν
            (Benitoite.Release.Refinement.Pred.compare s Benitoite.Release.Refinement.Comparison.eq a b).not)
```

## Benitoite.Release.Refinement.BuiltinSchema.floatClass_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 38。

```lean
∀ (w : Benitoite.Release.Refinement.FloatWidth) (c : Benitoite.Release.Refinement.FloatClass)
  (a b : Benitoite.Release.Refinement.Term) (ν : Benitoite.Release.Refinement.ObservationEnv)
  (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.Pred.interpret η
      (Benitoite.Release.Refinement.predBind ν (Benitoite.Release.Refinement.BuiltinSchema.floatClass w c a b)) =
    Bool.true
```

## Benitoite.Release.Refinement.BuiltinSchema.implies_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 73。

```lean
∀ {p q : Benitoite.Release.Refinement.Pred} (ν : Benitoite.Release.Refinement.ObservationEnv)
  (η : Benitoite.Release.Refinement.ObservationEnvModel),
  (Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.predBind ν p) = Bool.true →
      Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.predBind ν q) = Bool.true) →
    Benitoite.Release.Refinement.Pred.interpret η
        (Benitoite.Release.Refinement.predBind ν (Benitoite.Release.Refinement.BuiltinSchema.implies p q)) =
      Bool.true
```

## Benitoite.Release.Refinement.BuiltinSchema.orderComplement_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 85。

```lean
∀ {s : Benitoite.Release.Refinement.Sort},
  s = Benitoite.Release.Refinement.Sort.character ∨ s = Benitoite.Release.Refinement.Sort.decimal →
    ∀ (a b : Benitoite.Release.Refinement.Term) (ν : Benitoite.Release.Refinement.ObservationEnv)
      (η : Benitoite.Release.Refinement.ObservationEnvModel),
      Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.predBind ν
              (Benitoite.Release.Refinement.Pred.compare s Benitoite.Release.Refinement.Comparison.ge a b)) =
          Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.predBind ν
              (Benitoite.Release.Refinement.Pred.compare s Benitoite.Release.Refinement.Comparison.lt a b).not) ∧
        Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.predBind ν
              (Benitoite.Release.Refinement.Pred.compare s Benitoite.Release.Refinement.Comparison.gt a b)) =
          Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.predBind ν
              (Benitoite.Release.Refinement.Pred.compare s Benitoite.Release.Refinement.Comparison.le a b).not)
```

## Benitoite.Release.Refinement.BuiltinSchema.scalarOrder_sound_at

所在: `formal/Benitoite/Release/Refinement/BuiltinLogic.lean`、行: 7。

```lean
∀ {s : Benitoite.Release.Refinement.Sort},
  s ∈ Benitoite.Release.Refinement.scalarSorts →
    ∀ (r : Benitoite.Release.Refinement.ScalarRule),
      s ∈ Benitoite.Release.Refinement.orderedScalarSorts ∨
          r ∈ Benitoite.Release.Refinement.BuiltinSchema.equalityRules →
        ∀ (a b c : Benitoite.Release.Refinement.Term) (ν : Benitoite.Release.Refinement.ObservationEnv)
          (η : Benitoite.Release.Refinement.ObservationEnvModel),
          Benitoite.Release.Refinement.Pred.interpret η
              (Benitoite.Release.Refinement.predBind ν
                (Benitoite.Release.Refinement.BuiltinSchema.scalarOrder s r a b c)) =
            Bool.true
```

## Benitoite.Release.Refinement.Builtins

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 420。

```lean
Type
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions

所在: `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean`、行: 107。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions.io_event_covered

所在: `formal/Benitoite/Release/Refinement/BuiltinEffects.lean`、行: 18。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {ws : List Benitoite.Release.Refinement.Val}
  {out : Benitoite.Release.Refinement.Outcome} {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.Event.Covered B Γ Φ s.eff (Benitoite.Release.Refinement.Event.io b ws out obs)
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions.io_transition_covered

所在: `formal/Benitoite/Release/Refinement/BuiltinEffects.lean`、行: 26。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io →
          Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                (List.map Benitoite.Release.Refinement.Eff.norm es) ws (Benitoite.Release.Refinement.Outcome.val v)
                obs →
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                  (Option.some
                    (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.val v) obs))
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                Benitoite.Release.Refinement.Event.Covered B Γ Φ s.eff
                  (Benitoite.Release.Refinement.Event.io b ws (Benitoite.Release.Refinement.Outcome.val v) obs)
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions.pathBases_event_covered

所在: `formal/Benitoite/Release/Refinement/BuiltinEffects.lean`、行: 37。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {σ : Benitoite.Release.Refinement.PathEnv}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
        Benitoite.Release.Refinement.Event.Covered B Γ Φ s.eff (Benitoite.Release.Refinement.Event.pathBases b σ)
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions.pathBases_membership

所在: `formal/Benitoite/Release/Refinement/PathBasesTargets.lean`、行: 33。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    B.sig b = Option.some s →
      s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
        s.opEff = Option.some Benitoite.Release.Refinement.processEnvironmentEff ∧
          ∃ bs, B.effects Benitoite.Release.Refinement.processEnvironmentEff = Option.some bs ∧ b ∈ bs
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions.pathBases_transition_covered

所在: `formal/Benitoite/Release/Refinement/BuiltinEffects.lean`、行: 45。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    q.view = Benitoite.Release.Refinement.Comp.issuePathBases b →
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
          σ.Valid →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                (Option.some (Benitoite.Release.Refinement.Event.pathBases b σ))
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                  k μ) ∧
              Benitoite.Release.Refinement.Event.Covered B Γ Φ s.eff (Benitoite.Release.Refinement.Event.pathBases b σ)
```

## Benitoite.Release.Refinement.Builtins.CoreAssumptions.release_exists

所在: `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean`、行: 117。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
      (o : Benitoite.Release.OpaqueName),
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
          (Benitoite.Release.Refinement.Ty.opaque o
            (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
        B.isResource o = Bool.true → ∃ r, B.releaseResponse v r
```

## Benitoite.Release.Refinement.Builtins.ExternalAssumptions

所在: `formal/Benitoite/Release/Refinement/ExternalResponse.lean`、行: 23。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists

所在: `formal/Benitoite/Release/Refinement/ExternalResponse.lean`、行: 27。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      P.ExternalWF →
        P.externalFunction f = Option.some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → ∃ out obs, B.externalResponse f ts vs out obs
```

## Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_no_targets

所在: `formal/Benitoite/Release/Refinement/ExternalResponse.lean`、行: 30。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = Option.some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → B.externalResponse f ts vs out obs → obs = []
```

## Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_typed

所在: `formal/Benitoite/Release/Refinement/ExternalResponse.lean`、行: 24。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = Option.some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
            B.externalResponse f ts vs out obs →
              Benitoite.Release.Refinement.Outcome.Carrier P B Ψ out a ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.Builtins.ResponseAssumptions

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 47。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.Builtins.ResponseAssumptions.delta_typed

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 48。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            ∃ out,
              B.delta b ts es rs ws = Option.some out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                    Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_exists

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 60。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            ∃ out obs, B.ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_kind

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 56。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = Option.some sg →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          B.ioResponse b ts es ws out obs →
            (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v
```

## Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_typed

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 52。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            B.ioResponse b ts es ws out obs →
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.common

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 59。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig},
  B.ShapeOk b sg → ∃ l bs, sg.opEff = Option.some l ∧ sg.neffs = 0 ∧ B.effects l = Option.some bs ∧ b ∈ bs
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.eff_eq

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 65。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig},
  B.ShapeOk b sg →
    ∃ l bs ix,
      sg.opEff = Option.some l ∧
        B.effects l = Option.some bs ∧
          b ∈ bs ∧
            sg.eff =
              Benitoite.Release.Refinement.EffR.mk
                (fun a => Decidable.decide (a = Benitoite.Release.Refinement.Atom.name l ix)) []
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.inst_eff_mem

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 81。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig},
  B.ShapeOk b sg →
    ∀ (rs : List Benitoite.Release.Refinement.RangeExpr),
      ∃ l bs ix,
        sg.opEff = Option.some l ∧
          B.effects l = Option.some bs ∧
            b ∈ bs ∧
              (Benitoite.Release.Refinement.Eff.instR rs sg.eff).mem
                (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.inst rs ix))
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.single

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 93。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Scope.Domain.Kind} {p : Nat},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
      ∃ l o,
        sg.opEff = Option.some l ∧
          B.effKind l = Option.some k ∧
            sg.rkinds = [k] ∧
              sg.eff =
                  Benitoite.Release.Refinement.EffR.mk
                    (fun a =>
                      Decidable.decide
                        (a = Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.rvar 0)))
                    [] ∧
                sg.params[p]? =
                    Option.some
                      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.rvar 0)) ∧
                  B.valKind o = Option.some k
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.single_inst

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 104。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Scope.Domain.Kind} {p : Nat},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
      ∀ (r : Benitoite.Release.Refinement.RangeExpr),
        ∃ l o,
          sg.opEff = Option.some l ∧
            B.effKind l = Option.some k ∧
              (Benitoite.Release.Refinement.Eff.instR [r] sg.eff).mem
                  (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed r)) ∧
                (List.map (Benitoite.Release.Refinement.Ty.instR [r]) sg.params)[p]? =
                    Option.some
                      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) ∧
                  B.valKind o = Option.some k
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.single_request

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 162。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {A : Benitoite.Release.Refinement.Ty},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p →
      Benitoite.Release.Refinement.NamesWF sg.names sg.params →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            (∀ (o : Benitoite.Release.OpaqueName),
                sg.params[p]? =
                    Option.some
                      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                  B.valContent o = Option.some A) →
              ∃ r w target req,
                rs = [r] ∧
                  ws[p]? = Option.some w ∧
                    sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p ∧
                      (w = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                          ∃ s snapshot,
                            w = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (Option.some req)) ∧
                        Benitoite.Release.Refinement.ModelHttp.valueRun [w] =
                            Benitoite.Release.Refinement.Outcome.val req ∧
                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                            Benitoite.Release.Refinement.groundVal req = Bool.true ∧
                              req.reqTarget = Option.some target ∧
                                Benitoite.Release.Refinement.RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.endpoint r
                                  target
```

## Benitoite.Release.Refinement.Builtins.ShapeOk.single_target

所在: `formal/Benitoite/Release/Refinement/ShapeTargets.lean`、行: 145。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
      Benitoite.Release.Refinement.NamesWF sg.names sg.params →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            ∃ r t,
              rs = [r] ∧
                ws[p]?.bind Benitoite.Release.Refinement.Val.target? = Option.some t ∧
                  Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                    sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k p
```

## Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 42。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

