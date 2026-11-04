# 段末の実署名（続き）

## Benitoite.Release.Refinement.Val.brecOn_6

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
                          (t : Option Benitoite.Release.Refinement.Comp) →
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
                                                      motive_12 t
```

## Benitoite.Release.Refinement.Val.brecOn_7

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
                          (t : List (Option Benitoite.Release.Refinement.Val)) →
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
                                                      motive_13 t
```

## Benitoite.Release.Refinement.Val.bytesV

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 159。

```lean
List Nat → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.bytesV.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 159。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 14 → ((bs : List Nat) → motive_1 (Benitoite.Release.Refinement.Val.bytesV bs)) → motive_1 t
```

## Benitoite.Release.Refinement.Val.bytesV.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 159。

```lean
{P : Sort u} →
  {bs bs' : List Nat} →
    Benitoite.Release.Refinement.Val.bytesV bs = Benitoite.Release.Refinement.Val.bytesV bs' → (bs = bs' → P) → P
```

## Benitoite.Release.Refinement.Val.checked

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 173。

```lean
Benitoite.Scope.Domain.Target → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.checked.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 173。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 23 →
      ((t : Benitoite.Scope.Domain.Target) → motive_1 (Benitoite.Release.Refinement.Val.checked t)) → motive_1 t
```

## Benitoite.Release.Refinement.Val.checked.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 173。

```lean
{P : Sort u} →
  {t t' : Benitoite.Scope.Domain.Target} →
    Benitoite.Release.Refinement.Val.checked t = Benitoite.Release.Refinement.Val.checked t' → (t = t' → P) → P
```

## Benitoite.Release.Refinement.Val.checkedAt

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 170。

```lean
Benitoite.Release.Refinement.RangeExpr →
  Option Benitoite.Release.Refinement.PathEnv →
    Benitoite.Scope.Domain.Target → Option Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.checkedAt.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 170。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 21 →
      ((range : Benitoite.Release.Refinement.RangeExpr) →
          (snapshot : Option Benitoite.Release.Refinement.PathEnv) →
            (target : Benitoite.Scope.Domain.Target) →
              (request : Option Benitoite.Release.Refinement.Val) →
                motive_1 (Benitoite.Release.Refinement.Val.checkedAt range snapshot target request)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.checkedAt.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 170。

```lean
{P : Sort u} →
  {range : Benitoite.Release.Refinement.RangeExpr} →
    {snapshot : Option Benitoite.Release.Refinement.PathEnv} →
      {target : Benitoite.Scope.Domain.Target} →
        {request : Option Benitoite.Release.Refinement.Val} →
          {range' : Benitoite.Release.Refinement.RangeExpr} →
            {snapshot' : Option Benitoite.Release.Refinement.PathEnv} →
              {target' : Benitoite.Scope.Domain.Target} →
                {request' : Option Benitoite.Release.Refinement.Val} →
                  Benitoite.Release.Refinement.Val.checkedAt range snapshot target request =
                      Benitoite.Release.Refinement.Val.checkedAt range' snapshot' target' request' →
                    (range = range' → snapshot = snapshot' → target = target' → request = request' → P) → P
```

## Benitoite.Release.Refinement.Val.checkedAt_snapshot_subst

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 93。

```lean
∀ (ν : Nat → Benitoite.Release.Refinement.Val) (ρ : Nat → Benitoite.Release.LocalRef)
  (r : Benitoite.Release.Refinement.RangeExpr) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (t : Benitoite.Scope.Domain.Target) (req : Option Benitoite.Release.Refinement.Val),
  (Benitoite.Release.Refinement.Val.subst ν (Benitoite.Release.Refinement.Val.checkedAt r snapshot t req) ρ).toTerm? =
    Option.some (Benitoite.Release.Refinement.Term.targetValue snapshot t)
```

## Benitoite.Release.Refinement.Val.checkedRequest

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 174。

```lean
Benitoite.Scope.Domain.Target → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.checkedRequest.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 174。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 24 →
      ((t : Benitoite.Scope.Domain.Target) →
          (req : Benitoite.Release.Refinement.Val) → motive_1 (Benitoite.Release.Refinement.Val.checkedRequest t req)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.checkedRequest.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 174。

```lean
{P : Sort u} →
  {t : Benitoite.Scope.Domain.Target} →
    {req : Benitoite.Release.Refinement.Val} →
      {t' : Benitoite.Scope.Domain.Target} →
        {req' : Benitoite.Release.Refinement.Val} →
          Benitoite.Release.Refinement.Val.checkedRequest t req =
              Benitoite.Release.Refinement.Val.checkedRequest t' req' →
            (t = t' → req = req' → P) → P
```

## Benitoite.Release.Refinement.Val.closure

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 146。

```lean
Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.Closure → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.closure.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 146。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 6 →
      ((signature : Benitoite.Release.Refinement.Tel) →
          (body : Benitoite.Release.Refinement.Closure) →
            motive_1 (Benitoite.Release.Refinement.Val.closure signature body)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.closure.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 146。

```lean
{P : Sort u} →
  {signature : Benitoite.Release.Refinement.Tel} →
    {body : Benitoite.Release.Refinement.Closure} →
      {signature' : Benitoite.Release.Refinement.Tel} →
        {body' : Benitoite.Release.Refinement.Closure} →
          Benitoite.Release.Refinement.Val.closure signature body =
              Benitoite.Release.Refinement.Val.closure signature' body' →
            (signature = signature' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Val.con

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 147。

```lean
Benitoite.Release.ConName →
  List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.con.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 147。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 7 →
      ((c : Benitoite.Release.ConName) →
          (tys : List Benitoite.Release.Refinement.Ty) →
            (args : List Benitoite.Release.Refinement.Val) →
              motive_1 (Benitoite.Release.Refinement.Val.con c tys args)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.con.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 147。

```lean
{P : Sort u} →
  {c : Benitoite.Release.ConName} →
    {tys : List Benitoite.Release.Refinement.Ty} →
      {args : List Benitoite.Release.Refinement.Val} →
        {c' : Benitoite.Release.ConName} →
          {tys' : List Benitoite.Release.Refinement.Ty} →
            {args' : List Benitoite.Release.Refinement.Val} →
              Benitoite.Release.Refinement.Val.con c tys args = Benitoite.Release.Refinement.Val.con c' tys' args' →
                (c = c' → tys = tys' → args = args' → P) → P
```

## Benitoite.Release.Refinement.Val.const

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 140。

```lean
Benitoite.Release.Refinement.Const → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.const.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 140。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 1 →
      ((c : Benitoite.Release.Refinement.Const) → motive_1 (Benitoite.Release.Refinement.Val.const c)) → motive_1 t
```

## Benitoite.Release.Refinement.Val.const.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 140。

```lean
{P : Sort u} →
  {c c' : Benitoite.Release.Refinement.Const} →
    Benitoite.Release.Refinement.Val.const c = Benitoite.Release.Refinement.Val.const c' → (c = c' → P) → P
```

## Benitoite.Release.Refinement.Val.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Val) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Val.ctorElimType ctorIdx → motive_1 t
```

## Benitoite.Release.Refinement.Val.dependentLam

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 145。

```lean
Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.dependentLam.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 145。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 5 →
      ((signature : Benitoite.Release.Refinement.Tel) →
          (body : Benitoite.Release.Refinement.Comp) →
            motive_1 (Benitoite.Release.Refinement.Val.dependentLam signature body)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.dependentLam.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 145。

```lean
{P : Sort u} →
  {signature : Benitoite.Release.Refinement.Tel} →
    {body : Benitoite.Release.Refinement.Comp} →
      {signature' : Benitoite.Release.Refinement.Tel} →
        {body' : Benitoite.Release.Refinement.Comp} →
          Benitoite.Release.Refinement.Val.dependentLam signature body =
              Benitoite.Release.Refinement.Val.dependentLam signature' body' →
            (signature = signature' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Val.dict

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 161。

```lean
Benitoite.Release.ImplName →
  List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.dict.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 161。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 15 →
      ((i : Benitoite.Release.ImplName) →
          (tys : List Benitoite.Release.Refinement.Ty) →
            (args : List Benitoite.Release.Refinement.Val) →
              motive_1 (Benitoite.Release.Refinement.Val.dict i tys args)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.dict.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 161。

```lean
{P : Sort u} →
  {i : Benitoite.Release.ImplName} →
    {tys : List Benitoite.Release.Refinement.Ty} →
      {args : List Benitoite.Release.Refinement.Val} →
        {i' : Benitoite.Release.ImplName} →
          {tys' : List Benitoite.Release.Refinement.Ty} →
            {args' : List Benitoite.Release.Refinement.Val} →
              Benitoite.Release.Refinement.Val.dict i tys args = Benitoite.Release.Refinement.Val.dict i' tys' args' →
                (i = i' → tys = tys' → args = args' → P) → P
```

## Benitoite.Release.Refinement.Val.externalHandle

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 167。

```lean
Benitoite.Release.Refinement.ExternalHandle → List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.externalHandle.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 167。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 18 →
      ((handle : Benitoite.Release.Refinement.ExternalHandle) →
          (types : List Benitoite.Release.Refinement.Ty) →
            motive_1 (Benitoite.Release.Refinement.Val.externalHandle handle types)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.externalHandle.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 167。

```lean
{P : Sort u} →
  {handle : Benitoite.Release.Refinement.ExternalHandle} →
    {types : List Benitoite.Release.Refinement.Ty} →
      {handle' : Benitoite.Release.Refinement.ExternalHandle} →
        {types' : List Benitoite.Release.Refinement.Ty} →
          Benitoite.Release.Refinement.Val.externalHandle handle types =
              Benitoite.Release.Refinement.Val.externalHandle handle' types' →
            (handle = handle' → types = types' → P) → P
```

## Benitoite.Release.Refinement.Val.externalRef

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 165。

```lean
Benitoite.Release.Refinement.ExternalFunctionId →
  List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.externalRef.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 165。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 17 →
      ((id : Benitoite.Release.Refinement.ExternalFunctionId) →
          (types : List Benitoite.Release.Refinement.Ty) →
            motive_1 (Benitoite.Release.Refinement.Val.externalRef id types)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.externalRef.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 165。

```lean
{P : Sort u} →
  {id : Benitoite.Release.Refinement.ExternalFunctionId} →
    {types : List Benitoite.Release.Refinement.Ty} →
      {id' : Benitoite.Release.Refinement.ExternalFunctionId} →
        {types' : List Benitoite.Release.Refinement.Ty} →
          Benitoite.Release.Refinement.Val.externalRef id types =
              Benitoite.Release.Refinement.Val.externalRef id' types' →
            (id = id' → types = types' → P) → P
```

## Benitoite.Release.Refinement.Val.fnRef

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 141。

```lean
Benitoite.Release.FunName →
  List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.fnRef.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 141。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 2 →
      ((f : Benitoite.Release.FunName) →
          (tys : List Benitoite.Release.Refinement.Ty) →
            (effs : List Benitoite.Release.Refinement.Eff) →
              motive_1 (Benitoite.Release.Refinement.Val.fnRef f tys effs)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.fnRef.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 141。

```lean
{P : Sort u} →
  {f : Benitoite.Release.FunName} →
    {tys : List Benitoite.Release.Refinement.Ty} →
      {effs : List Benitoite.Release.Refinement.Eff} →
        {f' : Benitoite.Release.FunName} →
          {tys' : List Benitoite.Release.Refinement.Ty} →
            {effs' : List Benitoite.Release.Refinement.Eff} →
              Benitoite.Release.Refinement.Val.fnRef f tys effs = Benitoite.Release.Refinement.Val.fnRef f' tys' effs' →
                (f = f' → tys = tys' → effs = effs' → P) → P
```

## Benitoite.Release.Refinement.Val.lam

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 144。

```lean
List String →
  List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.lam.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 144。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 4 →
      ((names : List String) →
          (params : List Benitoite.Release.Refinement.Ty) →
            (body : Benitoite.Release.Refinement.Comp) →
              motive_1 (Benitoite.Release.Refinement.Val.lam names params body)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.lam.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 144。

```lean
{P : Sort u} →
  {names : List String} →
    {params : List Benitoite.Release.Refinement.Ty} →
      {body : Benitoite.Release.Refinement.Comp} →
        {names' : List String} →
          {params' : List Benitoite.Release.Refinement.Ty} →
            {body' : Benitoite.Release.Refinement.Comp} →
              Benitoite.Release.Refinement.Val.lam names params body =
                  Benitoite.Release.Refinement.Val.lam names' params' body' →
                (names = names' → params = params' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Val.list

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 148。

```lean
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.list.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 148。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 8 →
      ((elems : List Benitoite.Release.Refinement.Val) → motive_1 (Benitoite.Release.Refinement.Val.list elems)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.list.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 148。

```lean
{P : Sort u} →
  {elems elems' : List Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Val.list elems = Benitoite.Release.Refinement.Val.list elems' →
      (elems = elems' → P) → P
```

## Benitoite.Release.Refinement.Val.loc

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 153。

```lean
Nat → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.loc.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 153。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 11 → ((l : Nat) → motive_1 (Benitoite.Release.Refinement.Val.loc l)) → motive_1 t
```

## Benitoite.Release.Refinement.Val.loc.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 153。

```lean
{P : Sort u} →
  {l l' : Nat} → Benitoite.Release.Refinement.Val.loc l = Benitoite.Release.Refinement.Val.loc l' → (l = l' → P) → P
```

## Benitoite.Release.Refinement.Val.mapV

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 155。

```lean
List Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.mapV.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 155。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 12 →
      ((keys vals : List Benitoite.Release.Refinement.Val) →
          motive_1 (Benitoite.Release.Refinement.Val.mapV keys vals)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.mapV.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 155。

```lean
{P : Sort u} →
  {keys vals keys' vals' : List Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Val.mapV keys vals = Benitoite.Release.Refinement.Val.mapV keys' vals' →
      (keys = keys' → vals = vals' → P) → P
```

## Benitoite.Release.Refinement.Val.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Val} → t = t' → Benitoite.Release.Refinement.Val.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Val.op

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 149。

```lean
Benitoite.Release.OpName → List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.op.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 149。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 9 →
      ((o : Benitoite.Release.OpName) →
          (tys : List Benitoite.Release.Refinement.Ty) → motive_1 (Benitoite.Release.Refinement.Val.op o tys)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.op.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 149。

```lean
{P : Sort u} →
  {o : Benitoite.Release.OpName} →
    {tys : List Benitoite.Release.Refinement.Ty} →
      {o' : Benitoite.Release.OpName} →
        {tys' : List Benitoite.Release.Refinement.Ty} →
          Benitoite.Release.Refinement.Val.op o tys = Benitoite.Release.Refinement.Val.op o' tys' →
            (o = o' → tys = tys' → P) → P
```

## Benitoite.Release.Refinement.Val.pathBases

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 168。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.pathBases.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 168。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 19 →
      ((snapshot : Benitoite.Release.Refinement.PathEnv) →
          motive_1 (Benitoite.Release.Refinement.Val.pathBases snapshot)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.pathBases.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 168。

```lean
{P : Sort u} →
  {snapshot snapshot' : Benitoite.Release.Refinement.PathEnv} →
    Benitoite.Release.Refinement.Val.pathBases snapshot = Benitoite.Release.Refinement.Val.pathBases snapshot' →
      (snapshot = snapshot' → P) → P
```

## Benitoite.Release.Refinement.Val.prim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 142。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.prim.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 142。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 3 →
      ((b : Benitoite.Release.PrimName) →
          (tys : List Benitoite.Release.Refinement.Ty) →
            (effs : List Benitoite.Release.Refinement.Eff) →
              (rs : List Benitoite.Release.Refinement.RangeExpr) →
                motive_1 (Benitoite.Release.Refinement.Val.prim b tys effs rs)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.prim.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 142。

```lean
{P : Sort u} →
  {b : Benitoite.Release.PrimName} →
    {tys : List Benitoite.Release.Refinement.Ty} →
      {effs : List Benitoite.Release.Refinement.Eff} →
        {rs : List Benitoite.Release.Refinement.RangeExpr} →
          {b' : Benitoite.Release.PrimName} →
            {tys' : List Benitoite.Release.Refinement.Ty} →
              {effs' : List Benitoite.Release.Refinement.Eff} →
                {rs' : List Benitoite.Release.Refinement.RangeExpr} →
                  Benitoite.Release.Refinement.Val.prim b tys effs rs =
                      Benitoite.Release.Refinement.Val.prim b' tys' effs' rs' →
                    (b = b' → tys = tys' → effs = effs' → rs = rs' → P) → P
```

## Benitoite.Release.Refinement.Val.raise

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 151。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.raise.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 151。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 10 →
      ((result error : Benitoite.Release.Refinement.Ty) →
          motive_1 (Benitoite.Release.Refinement.Val.raise result error)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.raise.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 151。

```lean
{P : Sort u} →
  {result error result' error' : Benitoite.Release.Refinement.Ty} →
    Benitoite.Release.Refinement.Val.raise result error = Benitoite.Release.Refinement.Val.raise result' error' →
      (result = result' → error = error' → P) → P
```

