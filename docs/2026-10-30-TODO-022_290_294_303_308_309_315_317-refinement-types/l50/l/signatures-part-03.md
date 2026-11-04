# 段末の実署名（続き）

## Benitoite.Release.Refinement.Comp.ret.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 181。

```lean
{P : Sort u} →
  {v v' : Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Comp.ret v = Benitoite.Release.Refinement.Comp.ret v' → (v = v' → P) → P
```

## Benitoite.Release.Refinement.Comp.substTy

所在: `formal/Benitoite/Release/Refinement/Capture.lean`、行: 102。

```lean
List Benitoite.Release.Refinement.Ty →
  List Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.use

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 191。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.use.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 191。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 9 →
      ((v : Benitoite.Release.Refinement.Val) →
          (m : Benitoite.Release.Refinement.Comp) → motive_2 (Benitoite.Release.Refinement.Comp.use v m)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.use.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 191。

```lean
{P : Sort u} →
  {v : Benitoite.Release.Refinement.Val} →
    {m : Benitoite.Release.Refinement.Comp} →
      {v' : Benitoite.Release.Refinement.Val} →
        {m' : Benitoite.Release.Refinement.Comp} →
          Benitoite.Release.Refinement.Comp.use v m = Benitoite.Release.Refinement.Comp.use v' m' →
            (v = v' → m = m' → P) → P
```

## Benitoite.Release.Refinement.Comparison

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 221。

```lean
Type
```

## Benitoite.Release.Refinement.Comparison.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 221。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Comparison) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Comparison.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Comparison.eq

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.Comparison.eq.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (t : Benitoite.Release.Refinement.Comparison) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.Comparison.eq → motive t
```

## Benitoite.Release.Refinement.Comparison.ge

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.Comparison.ge.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (t : Benitoite.Release.Refinement.Comparison) →
    t.ctorIdx = 5 → motive Benitoite.Release.Refinement.Comparison.ge → motive t
```

## Benitoite.Release.Refinement.Comparison.gt

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.Comparison.gt.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (t : Benitoite.Release.Refinement.Comparison) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.Comparison.gt → motive t
```

## Benitoite.Release.Refinement.Comparison.le

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.Comparison.le.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (t : Benitoite.Release.Refinement.Comparison) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.Comparison.le → motive t
```

## Benitoite.Release.Refinement.Comparison.lt

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.Comparison.lt.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (t : Benitoite.Release.Refinement.Comparison) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.Comparison.lt → motive t
```

## Benitoite.Release.Refinement.Comparison.ne

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.Comparison.ne.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 222。

```lean
{motive : Benitoite.Release.Refinement.Comparison → Sort u} →
  (t : Benitoite.Release.Refinement.Comparison) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.Comparison.ne → motive t
```

## Benitoite.Release.Refinement.Comparison.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 221。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.Comparison} →
    x = y → Benitoite.Release.Refinement.Comparison.noConfusionType P x y
```

## Benitoite.Release.Refinement.ComponentId

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 186。

```lean
Type
```

## Benitoite.Release.Refinement.ComponentId.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 187。

```lean
Nat → Benitoite.Release.Refinement.ComponentId
```

## Benitoite.Release.Refinement.ComponentId.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 187。

```lean
{P : Sort u} →
  {declaration declaration' : Nat} →
    Benitoite.Release.Refinement.ComponentId.mk declaration = Benitoite.Release.Refinement.ComponentId.mk declaration' →
      (declaration = declaration' → P) → P
```

## Benitoite.Release.Refinement.ComponentId.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 186。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ComponentId} →
    t = t' → Benitoite.Release.Refinement.ComponentId.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ConDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 263。

```lean
Type
```

## Benitoite.Release.Refinement.ConDecl.args

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 266。

```lean
Benitoite.Release.Refinement.ConDecl → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ConDecl.data

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 264。

```lean
Benitoite.Release.Refinement.ConDecl → Benitoite.Release.DataName
```

## Benitoite.Release.Refinement.ConDecl.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 263。

```lean
Benitoite.Release.DataName → Nat → List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.ConDecl
```

## Benitoite.Release.Refinement.ConDecl.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 263。

```lean
{P : Sort u} →
  {data : Benitoite.Release.DataName} →
    {ntys : Nat} →
      {args : List Benitoite.Release.Refinement.Ty} →
        {data' : Benitoite.Release.DataName} →
          {ntys' : Nat} →
            {args' : List Benitoite.Release.Refinement.Ty} →
              { data := data, ntys := ntys, args := args } = { data := data', ntys := ntys', args := args' } →
                (data = data' → ntys = ntys' → args = args' → P) → P
```

## Benitoite.Release.Refinement.ConDecl.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 263。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ConDecl} → t = t' → Benitoite.Release.Refinement.ConDecl.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ConDecl.ntys

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 265。

```lean
Benitoite.Release.Refinement.ConDecl → Nat
```

## Benitoite.Release.Refinement.Const

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 7。

```lean
Type
```

## Benitoite.Release.Refinement.Const.NumericRepresented.assume

所在: `formal/Benitoite/Release/Refinement/TypedFacts.lean`、行: 209。

```lean
∀ {c : Benitoite.Release.Refinement.Const},
  c.NumericRepresented →
    ∀ (Ξ : List Benitoite.Release.Refinement.Pred) (p : Benitoite.Release.Refinement.Pred),
      p ∈ c.type.assume →
        Benitoite.Release.Refinement.Entails Ξ (p.openOptional (Benitoite.Release.Refinement.Val.const c).toTerm?)
```

## Benitoite.Release.Refinement.Const.boolean

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 12。

```lean
Bool → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.boolean.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 12。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 4 → ((b : Bool) → motive (Benitoite.Release.Refinement.Const.boolean b)) → motive t
```

## Benitoite.Release.Refinement.Const.boolean.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 12。

```lean
{P : Sort u} →
  {b b' : Bool} →
    Benitoite.Release.Refinement.Const.boolean b = Benitoite.Release.Refinement.Const.boolean b' → (b = b' → P) → P
```

## Benitoite.Release.Refinement.Const.byte

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 14。

```lean
Nat → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.byte.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 14。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 6 → ((n : Nat) → motive (Benitoite.Release.Refinement.Const.byte n)) → motive t
```

## Benitoite.Release.Refinement.Const.byte.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 14。

```lean
{P : Sort u} →
  {n n' : Nat} →
    Benitoite.Release.Refinement.Const.byte n = Benitoite.Release.Refinement.Const.byte n' → (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.character

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 11。

```lean
Char → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.character.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 3 → ((c : Char) → motive (Benitoite.Release.Refinement.Const.character c)) → motive t
```

## Benitoite.Release.Refinement.Const.character.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 11。

```lean
{P : Sort u} →
  {c c' : Char} →
    Benitoite.Release.Refinement.Const.character c = Benitoite.Release.Refinement.Const.character c' → (c = c' → P) → P
```

## Benitoite.Release.Refinement.Const.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 7。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Const) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Const.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Const.decimal

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 15。

```lean
Int → Nat → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.decimal.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 15。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 7 → ((n : Int) → (scale : Nat) → motive (Benitoite.Release.Refinement.Const.decimal n scale)) → motive t
```

## Benitoite.Release.Refinement.Const.decimal.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 15。

```lean
{P : Sort u} →
  {n : Int} →
    {scale : Nat} →
      {n' : Int} →
        {scale' : Nat} →
          Benitoite.Release.Refinement.Const.decimal n scale = Benitoite.Release.Refinement.Const.decimal n' scale' →
            (n = n' → scale = scale' → P) → P
```

## Benitoite.Release.Refinement.Const.float32

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 25。

```lean
UInt32 → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.float32.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 25。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 15 → ((bits : UInt32) → motive (Benitoite.Release.Refinement.Const.float32 bits)) → motive t
```

## Benitoite.Release.Refinement.Const.float32.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 25。

```lean
{P : Sort u} →
  {bits bits' : UInt32} →
    Benitoite.Release.Refinement.Const.float32 bits = Benitoite.Release.Refinement.Const.float32 bits' →
      (bits = bits' → P) → P
```

## Benitoite.Release.Refinement.Const.float64

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 9。

```lean
UInt64 → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.float64.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 9。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 1 → ((bits : UInt64) → motive (Benitoite.Release.Refinement.Const.float64 bits)) → motive t
```

## Benitoite.Release.Refinement.Const.float64.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 9。

```lean
{P : Sort u} →
  {bits bits' : UInt64} →
    Benitoite.Release.Refinement.Const.float64 bits = Benitoite.Release.Refinement.Const.float64 bits' →
      (bits = bits' → P) → P
```

## Benitoite.Release.Refinement.Const.integer

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 8。

```lean
Benitoite.Release.Integer64Value → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.integer.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 8。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 0 →
      ((n : Benitoite.Release.Integer64Value) → motive (Benitoite.Release.Refinement.Const.integer n)) → motive t
```

## Benitoite.Release.Refinement.Const.integer.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 8。

```lean
{P : Sort u} →
  {n n' : Benitoite.Release.Integer64Value} →
    Benitoite.Release.Refinement.Const.integer n = Benitoite.Release.Refinement.Const.integer n' → (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.integer16

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 20。

```lean
Int → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.integer16.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 20。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 10 → ((n : Int) → motive (Benitoite.Release.Refinement.Const.integer16 n)) → motive t
```

## Benitoite.Release.Refinement.Const.integer16.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 20。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Const.integer16 n = Benitoite.Release.Refinement.Const.integer16 n' → (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.integer32

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 21。

```lean
Int → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.integer32.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 21。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 11 → ((n : Int) → motive (Benitoite.Release.Refinement.Const.integer32 n)) → motive t
```

## Benitoite.Release.Refinement.Const.integer32.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 21。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Const.integer32 n = Benitoite.Release.Refinement.Const.integer32 n' → (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.integer8

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 17。

```lean
Int → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.integer8.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 17。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 9 → ((n : Int) → motive (Benitoite.Release.Refinement.Const.integer8 n)) → motive t
```

## Benitoite.Release.Refinement.Const.integer8.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 17。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Const.integer8 n = Benitoite.Release.Refinement.Const.integer8 n' → (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 7。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Const} → t = t' → Benitoite.Release.Refinement.Const.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Const.opaque

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 16。

```lean
Benitoite.Release.OpaqueName → Nat → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.opaque.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 16。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 8 →
      ((o : Benitoite.Release.OpaqueName) → (id : Nat) → motive (Benitoite.Release.Refinement.Const.opaque o id)) →
        motive t
```

## Benitoite.Release.Refinement.Const.opaque.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 16。

```lean
{P : Sort u} →
  {o : Benitoite.Release.OpaqueName} →
    {id : Nat} →
      {o' : Benitoite.Release.OpaqueName} →
        {id' : Nat} →
          Benitoite.Release.Refinement.Const.opaque o id = Benitoite.Release.Refinement.Const.opaque o' id' →
            (o = o' → id = id' → P) → P
```

## Benitoite.Release.Refinement.Const.string

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 10。

```lean
String → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.string.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 10。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 2 → ((s : String) → motive (Benitoite.Release.Refinement.Const.string s)) → motive t
```

## Benitoite.Release.Refinement.Const.string.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 10。

```lean
{P : Sort u} →
  {s s' : String} →
    Benitoite.Release.Refinement.Const.string s = Benitoite.Release.Refinement.Const.string s' → (s = s' → P) → P
```

## Benitoite.Release.Refinement.Const.type

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 28。

```lean
Benitoite.Release.Refinement.Const → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Const.type_embed

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 64。

```lean
∀ (c : Benitoite.Release.Const),
  (Benitoite.Release.Refinement.embedConst c).type = Benitoite.Release.Refinement.embedTy c.type
```

## Benitoite.Release.Refinement.Const.unit

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 13。

```lean
Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.unit.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 13。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) → t.ctorIdx = 5 → motive Benitoite.Release.Refinement.Const.unit → motive t
```

## Benitoite.Release.Refinement.Const.unsignedInteger16

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 22。

```lean
Int → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.unsignedInteger16.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 22。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 12 → ((n : Int) → motive (Benitoite.Release.Refinement.Const.unsignedInteger16 n)) → motive t
```

## Benitoite.Release.Refinement.Const.unsignedInteger16.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 22。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Const.unsignedInteger16 n = Benitoite.Release.Refinement.Const.unsignedInteger16 n' →
      (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.unsignedInteger32

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 23。

```lean
Int → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.unsignedInteger32.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 23。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 13 → ((n : Int) → motive (Benitoite.Release.Refinement.Const.unsignedInteger32 n)) → motive t
```

## Benitoite.Release.Refinement.Const.unsignedInteger32.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 23。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Const.unsignedInteger32 n = Benitoite.Release.Refinement.Const.unsignedInteger32 n' →
      (n = n' → P) → P
```

## Benitoite.Release.Refinement.Const.unsignedInteger64

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 24。

```lean
Int → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.Const.unsignedInteger64.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 24。

```lean
{motive : Benitoite.Release.Refinement.Const → Sort u} →
  (t : Benitoite.Release.Refinement.Const) →
    t.ctorIdx = 14 → ((n : Int) → motive (Benitoite.Release.Refinement.Const.unsignedInteger64 n)) → motive t
```

## Benitoite.Release.Refinement.Const.unsignedInteger64.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 24。

```lean
{P : Sort u} →
  {n n' : Int} →
    Benitoite.Release.Refinement.Const.unsignedInteger64 n = Benitoite.Release.Refinement.Const.unsignedInteger64 n' →
      (n = n' → P) → P
```

## Benitoite.Release.Refinement.ConstOK

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 478。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.Const → Prop
```

## Benitoite.Release.Refinement.Cont

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 15。

```lean
Type
```

## Benitoite.Release.Refinement.Ctx

所在: `formal/Benitoite/Release/Refinement/Context.lean`、行: 11。

```lean
Type
```

## Benitoite.Release.Refinement.Ctx.NormEq.declaration

所在: `formal/Benitoite/Release/Refinement/ContextNormEq.lean`、行: 73。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ Δ : Benitoite.Release.Refinement.Ctx} {B : Benitoite.Release.Refinement.Builtins},
  Γ.NormEq Δ →
    Benitoite.Release.Refinement.DeclarationImages P C Γ Δ fun i =>
      Option.some (Benitoite.Release.Refinement.Term.var i)
```

## Benitoite.Release.Refinement.Ctx.WF

所在: `formal/Benitoite/Release/Refinement/Admissible.lean`、行: 12。

```lean
Nat → Nat → Benitoite.Release.Refinement.Ctx → Prop
```

## Benitoite.Release.Refinement.Def

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 252。

```lean
Type
```

## Benitoite.Release.Refinement.Def.body

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 259。

```lean
Benitoite.Release.Refinement.Def → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Def.eff

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 258。

```lean
Benitoite.Release.Refinement.Def → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.Def.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 252。

```lean
List Benitoite.Release.Refinement.TParamDecl →
  Nat →
    List String →
      List Benitoite.Release.Refinement.Ty →
        Benitoite.Release.Refinement.Ty →
          Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Def
```

## Benitoite.Release.Refinement.Def.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 252。

```lean
{P : Sort u} →
  {tparams : List Benitoite.Release.Refinement.TParamDecl} →
    {neffs : Nat} →
      {names : List String} →
        {params : List Benitoite.Release.Refinement.Ty} →
          {ret : Benitoite.Release.Refinement.Ty} →
            {eff : Benitoite.Release.Refinement.Eff} →
              {body : Benitoite.Release.Refinement.Comp} →
                {tparams' : List Benitoite.Release.Refinement.TParamDecl} →
                  {neffs' : Nat} →
                    {names' : List String} →
                      {params' : List Benitoite.Release.Refinement.Ty} →
                        {ret' : Benitoite.Release.Refinement.Ty} →
                          {eff' : Benitoite.Release.Refinement.Eff} →
                            {body' : Benitoite.Release.Refinement.Comp} →
                              { tparams := tparams, neffs := neffs, names := names, params := params, ret := ret,
                                    eff := eff, body := body } =
                                  { tparams := tparams', neffs := neffs', names := names', params := params',
                                    ret := ret', eff := eff', body := body' } →
                                (tparams = tparams' →
                                    neffs = neffs' →
                                      names = names' → params = params' → ret = ret' → eff = eff' → body = body' → P) →
                                  P
```

## Benitoite.Release.Refinement.Def.names

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 255。

```lean
Benitoite.Release.Refinement.Def → List String
```

## Benitoite.Release.Refinement.Def.neffs

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 254。

```lean
Benitoite.Release.Refinement.Def → Nat
```

## Benitoite.Release.Refinement.Def.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 252。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Def} → t = t' → Benitoite.Release.Refinement.Def.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Def.ntys

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 261。

```lean
Benitoite.Release.Refinement.Def → Nat
```

## Benitoite.Release.Refinement.Def.params

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 256。

```lean
Benitoite.Release.Refinement.Def → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Def.ret

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 257。

```lean
Benitoite.Release.Refinement.Def → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Def.tel

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 460。

```lean
Benitoite.Release.Refinement.Def → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.Def.tparams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 253。

```lean
Benitoite.Release.Refinement.Def → List Benitoite.Release.Refinement.TParamDecl
```

## Benitoite.Release.Refinement.Detail

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 164。

```lean
Type → Type
```

## Benitoite.Release.Refinement.Detail.failure

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 166。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.Detail.match_pattern

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 49。

```lean
∀ (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
      (Benitoite.Release.Refinement.Val.atError detail) =
    Option.some (Benitoite.Release.Refinement.Detail.values detail)
```

## Benitoite.Release.Refinement.Detail.match_pattern_typed

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 54。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
  (C : Benitoite.Release.Refinement.TypeCtx) (Γ : Benitoite.Release.Refinement.Ctx)
  (Φ : List Benitoite.Release.Refinement.Pred) (detail : Benitoite.Release.Refinement.AtError),
  ∃ vs,
    Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
          (Benitoite.Release.Refinement.Val.atError detail) =
        Option.some vs ∧
      Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs Benitoite.Release.Refinement.atErrorFields
```

## Benitoite.Release.Refinement.Detail.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 165。

```lean
{Raw : Type} →
  Benitoite.Release.Refinement.AtFailure →
    Raw →
      Raw →
        Option Benitoite.Release.Refinement.RangeExpr →
          Option Benitoite.Release.Refinement.TargetInput →
            Option (List Benitoite.Scope.Domain.Range) →
              Option Benitoite.Scope.Domain.Target →
                Option Benitoite.Release.Refinement.PathBase →
                  Option Benitoite.Release.Refinement.PathBase → Benitoite.Release.Refinement.Detail Raw
```

## Benitoite.Release.Refinement.Detail.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 165。

```lean
{Raw : Type} →
  {P : Sort u} →
    {failure : Benitoite.Release.Refinement.AtFailure} →
      {originalPattern originalTarget : Raw} →
        {parsedPattern : Option Benitoite.Release.Refinement.RangeExpr} →
          {parsedTarget : Option Benitoite.Release.Refinement.TargetInput} →
            {resolvedPatterns : Option (List Benitoite.Scope.Domain.Range)} →
              {resolvedTarget : Option Benitoite.Scope.Domain.Target} →
                {patternBase targetBase : Option Benitoite.Release.Refinement.PathBase} →
                  {failure' : Benitoite.Release.Refinement.AtFailure} →
                    {originalPattern' originalTarget' : Raw} →
                      {parsedPattern' : Option Benitoite.Release.Refinement.RangeExpr} →
                        {parsedTarget' : Option Benitoite.Release.Refinement.TargetInput} →
                          {resolvedPatterns' : Option (List Benitoite.Scope.Domain.Range)} →
                            {resolvedTarget' : Option Benitoite.Scope.Domain.Target} →
                              {patternBase' targetBase' : Option Benitoite.Release.Refinement.PathBase} →
                                { failure := failure, originalPattern := originalPattern,
                                      originalTarget := originalTarget, parsedPattern := parsedPattern,
                                      parsedTarget := parsedTarget, resolvedPatterns := resolvedPatterns,
                                      resolvedTarget := resolvedTarget, patternBase := patternBase,
                                      targetBase := targetBase } =
                                    { failure := failure', originalPattern := originalPattern',
                                      originalTarget := originalTarget', parsedPattern := parsedPattern',
                                      parsedTarget := parsedTarget', resolvedPatterns := resolvedPatterns',
                                      resolvedTarget := resolvedTarget', patternBase := patternBase',
                                      targetBase := targetBase' } →
                                  (failure = failure' →
                                      originalPattern ≍ originalPattern' →
                                        originalTarget ≍ originalTarget' →
                                          parsedPattern = parsedPattern' →
                                            parsedTarget = parsedTarget' →
                                              resolvedPatterns = resolvedPatterns' →
                                                resolvedTarget = resolvedTarget' →
                                                  patternBase = patternBase' → targetBase = targetBase' → P) →
                                    P
```

## Benitoite.Release.Refinement.Detail.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 164。

```lean
{P : Sort u} →
  {Raw : Type} →
    {t : Benitoite.Release.Refinement.Detail Raw} →
      {Raw' : Type} →
        {t' : Benitoite.Release.Refinement.Detail Raw'} →
          Raw = Raw' → t ≍ t' → Benitoite.Release.Refinement.Detail.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Detail.originalPattern

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 167。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Raw
```

## Benitoite.Release.Refinement.Detail.originalTarget

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 168。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Raw
```

## Benitoite.Release.Refinement.Detail.originals_unobserved

所在: `formal/Benitoite/Release/Refinement/AtTargets.lean`、行: 79。

```lean
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

## Benitoite.Release.Refinement.Detail.parsedPattern

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 169。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Option Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.Detail.parsedTarget

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 170。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Option Benitoite.Release.Refinement.TargetInput
```

## Benitoite.Release.Refinement.Detail.patternBase

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 173。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Option Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.Detail.resolvedPatterns

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 171。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Option (List Benitoite.Scope.Domain.Range)
```

## Benitoite.Release.Refinement.Detail.resolvedTarget

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 172。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Option Benitoite.Scope.Domain.Target
```

## Benitoite.Release.Refinement.Detail.targetBase

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 174。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → Option Benitoite.Release.Refinement.PathBase
```

## Benitoite.Release.Refinement.Detail.textFields

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 177。

```lean
{Raw : Type} → Benitoite.Release.Refinement.Detail Raw → List String
```

## Benitoite.Release.Refinement.Detail.values

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 498。

```lean
Benitoite.Release.Refinement.AtError → List Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Detail.values_typed

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 9。

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
  (C : Benitoite.Release.Refinement.TypeCtx) (Γ : Benitoite.Release.Refinement.Ctx)
  (Φ : List Benitoite.Release.Refinement.Pred) (detail : Benitoite.Release.Refinement.AtError),
  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Detail.values detail)
    Benitoite.Release.Refinement.atErrorFields
```

## Benitoite.Release.Refinement.Eff

所在: `formal/Benitoite/Release/Refinement/Types.lean`、行: 88。

```lean
Type
```

## Benitoite.Release.Refinement.Eff.Allows

所在: `formal/Benitoite/Release/Refinement/EffectFacts.lean`、行: 9。

```lean
Benitoite.Release.Refinement.PathEnv →
  (Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind) →
    Benitoite.Release.Refinement.Eff → Benitoite.Release.EffName → Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.Eff.Allows.kind

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 24。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ e l t → κ l = Option.some t.kind
```

## Benitoite.Release.Refinement.Eff.Allows.mono

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 51。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e f : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ e l t → e.Sub f → Benitoite.Release.Refinement.Eff.Allows σ κ f l t
```

## Benitoite.Release.Refinement.Eff.Covers

所在: `formal/Benitoite/Release/Refinement/Le.lean`、行: 16。

```lean
Benitoite.Release.Refinement.Ctx →
  List Benitoite.Release.Refinement.Pred → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.Eff.Covers.allows

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 75。

```lean
∀ {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {e f : Benitoite.Release.Refinement.Eff} {σ : Benitoite.Release.Refinement.PathEnv}
  {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
  {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Covers Γ Φ e f →
    Benitoite.Release.Refinement.Eff.Allows σ κ f l t → Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.allows_bind

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 90。

```lean
∀ (θ : Benitoite.Release.Refinement.SubstEnv) (e : Benitoite.Release.Refinement.Eff)
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind θ e) l t ↔
    (∃ k ix r,
        κ l = Option.some k ∧
          e.mem (Benitoite.Release.Refinement.Atom.name l ix) ∧
            Benitoite.Release.Refinement.RangeIx.inst θ.ranges ix = Benitoite.Release.Refinement.RangeIx.fixed r ∧
              Benitoite.Release.Refinement.RangeExpr.Mem σ k r t) ∨
      ∃ i f,
        θ.rows[i]? = Option.some f ∧
          e.mem (Benitoite.Release.Refinement.Atom.rho i) ∧ Benitoite.Release.Refinement.Eff.Allows σ κ f l t
```

## Benitoite.Release.Refinement.Eff.allows_bind_comp

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 324。

```lean
∀ (θ φ : Benitoite.Release.Refinement.SubstEnv) (e : Benitoite.Release.Refinement.Eff)
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ
      (Benitoite.Release.Refinement.Eff.bind φ (Benitoite.Release.Refinement.Eff.bind θ e)) l t ↔
    (∃ k ix r,
        κ l = Option.some k ∧
          e.mem (Benitoite.Release.Refinement.Atom.name l ix) ∧
            Benitoite.Release.Refinement.RangeIx.inst φ.ranges (Benitoite.Release.Refinement.RangeIx.inst θ.ranges ix) =
                Benitoite.Release.Refinement.RangeIx.fixed r ∧
              Benitoite.Release.Refinement.RangeExpr.Mem σ k r t) ∨
      (∃ i f,
          θ.rows[i]? = Option.some f ∧
            e.mem (Benitoite.Release.Refinement.Atom.rho i) ∧
              Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind φ f) l t) ∨
        ∃ i f,
          θ.rows.length ≤ i ∧
            e.mem (Benitoite.Release.Refinement.Atom.rho i) ∧
              φ.rows[i]? = Option.some f ∧ Benitoite.Release.Refinement.Eff.Allows σ κ f l t
```

## Benitoite.Release.Refinement.Eff.allows_bind_of_rows_nil

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 114。

```lean
∀ {θ : Benitoite.Release.Refinement.SubstEnv},
  θ.rows = [] →
    ∀ (e : Benitoite.Release.Refinement.Eff) {σ : Benitoite.Release.Refinement.PathEnv}
      {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
      {t : Benitoite.Scope.Domain.Target},
      Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind θ e) l t ↔
        ∃ k ix r,
          κ l = Option.some k ∧
            e.mem (Benitoite.Release.Refinement.Atom.name l ix) ∧
              Benitoite.Release.Refinement.RangeIx.inst θ.ranges ix = Benitoite.Release.Refinement.RangeIx.fixed r ∧
                Benitoite.Release.Refinement.RangeExpr.Mem σ k r t
```

## Benitoite.Release.Refinement.Eff.allows_bind_of_rows_ranges_nil

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 122。

```lean
∀ {θ : Benitoite.Release.Refinement.SubstEnv},
  θ.rows = [] →
    θ.ranges = [] →
      ∀ (e : Benitoite.Release.Refinement.Eff) {σ : Benitoite.Release.Refinement.PathEnv}
        {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
        {t : Benitoite.Scope.Domain.Target},
        Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind θ e) l t ↔
          Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.allows_of_mem

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 20。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  κ l = Option.some k →
    e.mem (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed r)) →
      Benitoite.Release.Refinement.RangeExpr.Mem σ k r t → Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.allows_of_mem_covers

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 83。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {ix : Benitoite.Release.Refinement.RangeIx}
  {r : Benitoite.Release.Refinement.RangeExpr} {k : Benitoite.Scope.Domain.Kind} {t : Benitoite.Scope.Domain.Target},
  κ l = Option.some k →
    e.mem (Benitoite.Release.Refinement.Atom.name l ix) →
      (Benitoite.Release.Refinement.Atom.name l ix).Covers
          (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed r)) →
        Benitoite.Release.Refinement.RangeExpr.Mem σ k r t → Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.allows_of_nameTop

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 35。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  e.mem (Benitoite.Release.Refinement.Atom.nameTop l) →
    κ l = Option.some t.kind → Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.allows_single_iff

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 39。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l m : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.single l) m t ↔
    m = l ∧ κ l = Option.some t.kind
```

## Benitoite.Release.Refinement.Eff.allows_substAt_nil

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 132。

```lean
∀ (c : Nat) (ts : List Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.substAt c ts [] e) l t ↔
    Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.allows_union

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 56。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e f : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ (e.union f) l t ↔
    Benitoite.Release.Refinement.Eff.Allows σ κ e l t ∨ Benitoite.Release.Refinement.Eff.Allows σ κ f l t
```

## Benitoite.Release.Refinement.Eff.bind

所在: `formal/Benitoite/Release/Refinement/Context.lean`、行: 441。

```lean
Benitoite.Release.Refinement.SubstEnv → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.Eff.instR

所在: `formal/Benitoite/Release/Refinement/RangeSubst.lean`、行: 328。

```lean
List Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.Eff.norm

所在: `formal/Benitoite/Release/Refinement/Normalize.lean`、行: 51。

```lean
Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.Eff.not_allows_empty

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 67。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  ¬Benitoite.Release.Refinement.Eff.Allows σ κ Benitoite.Release.Refinement.Eff.empty l t
```

## Benitoite.Release.Refinement.Eff.not_allows_of_kind_none

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 29。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {e : Benitoite.Release.Refinement.Eff} {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  κ l = Option.none → ¬Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

## Benitoite.Release.Refinement.Eff.not_allows_row

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 71。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {i : Nat} {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  ¬Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.row i) l t
```

## Benitoite.Release.Refinement.Eff.single

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 6。

```lean
Benitoite.Release.EffName → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.Eff.substAt

所在: `formal/Benitoite/Release/Refinement/TypeSubst.lean`、行: 50。

```lean
Nat →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.Entails

所在: `formal/Benitoite/Release/Refinement/Logic.lean`、行: 5。

```lean
List Benitoite.Release.Refinement.Pred → Benitoite.Release.Refinement.Pred → Prop
```

## Benitoite.Release.Refinement.Event.Covered

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 9。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.Refinement.Ctx →
    List Benitoite.Release.Refinement.Pred →
      Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Event → Prop
```

## Benitoite.Release.Refinement.Event.covered_pathBases

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 17。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {ε : Benitoite.Release.Refinement.Eff} {b : Benitoite.Release.PrimName}
  {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.Event.Covered B Γ Φ ε (Benitoite.Release.Refinement.Event.pathBases b σ) ↔
    Benitoite.Release.Refinement.Eff.Covers Γ Φ ε
      (Benitoite.Release.Refinement.Eff.single Benitoite.Release.Refinement.processEnvironmentEff)
```

## Benitoite.Release.Refinement.Event.io

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 37。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Val →
    Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Benitoite.Release.Refinement.Event
```

## Benitoite.Release.Refinement.Event.pathBases

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 39。

```lean
Benitoite.Release.PrimName → Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.Event
```

## Benitoite.Release.Refinement.Exhaustive.atError

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 78。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape}
  {cs : List (Benitoite.Release.ConName × Benitoite.Release.Refinement.ConDecl)},
  Benitoite.Release.Refinement.ResultShape.StandardError P shape →
    P.StandardErrorComplete cs →
      Benitoite.Release.Refinement.Exhaustive P Benitoite.Release.Refinement.atErrorType
        (Benitoite.Release.Refinement.atErrorPatterns cs)
```

## Benitoite.Release.Refinement.ExternalArgs

所在: `formal/Benitoite/Release/Refinement/ExternalResponse.lean`、行: 14。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.Refinement.ExternalSignature →
        List Benitoite.Release.Refinement.Ty →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.ExternalDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 114。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalDecl.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 114。

```lean
{motive : Benitoite.Release.Refinement.ExternalDecl → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ExternalDecl) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ExternalDecl.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ExternalDecl.function

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 116。

```lean
Benitoite.Release.Refinement.ExternalFunctionId →
  Benitoite.Release.Refinement.ExternalSignature → Benitoite.Release.Refinement.ExternalDecl
```

## Benitoite.Release.Refinement.ExternalDecl.function.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 116。

```lean
{motive : Benitoite.Release.Refinement.ExternalDecl → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalDecl) →
    t.ctorIdx = 1 →
      ((id : Benitoite.Release.Refinement.ExternalFunctionId) →
          (signature : Benitoite.Release.Refinement.ExternalSignature) →
            motive (Benitoite.Release.Refinement.ExternalDecl.function id signature)) →
        motive t
```

## Benitoite.Release.Refinement.ExternalDecl.function.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 116。

```lean
{P : Sort u} →
  {id : Benitoite.Release.Refinement.ExternalFunctionId} →
    {signature : Benitoite.Release.Refinement.ExternalSignature} →
      {id' : Benitoite.Release.Refinement.ExternalFunctionId} →
        {signature' : Benitoite.Release.Refinement.ExternalSignature} →
          Benitoite.Release.Refinement.ExternalDecl.function id signature =
              Benitoite.Release.Refinement.ExternalDecl.function id' signature' →
            (id = id' → signature = signature' → P) → P
```

## Benitoite.Release.Refinement.ExternalDecl.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 114。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalDecl} →
    t = t' → Benitoite.Release.Refinement.ExternalDecl.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalDecl.type

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 115。

```lean
Benitoite.Release.Refinement.ExternalTypeDecl → Benitoite.Release.Refinement.ExternalDecl
```

## Benitoite.Release.Refinement.ExternalDecl.type.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 115。

```lean
{motive : Benitoite.Release.Refinement.ExternalDecl → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalDecl) →
    t.ctorIdx = 0 →
      ((declaration : Benitoite.Release.Refinement.ExternalTypeDecl) →
          motive (Benitoite.Release.Refinement.ExternalDecl.type declaration)) →
        motive t
```

## Benitoite.Release.Refinement.ExternalDecl.type.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 115。

```lean
{P : Sort u} →
  {declaration declaration' : Benitoite.Release.Refinement.ExternalTypeDecl} →
    Benitoite.Release.Refinement.ExternalDecl.type declaration =
        Benitoite.Release.Refinement.ExternalDecl.type declaration' →
      (declaration = declaration' → P) → P
```

## Benitoite.Release.Refinement.ExternalFunctionId

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 189。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalFunctionId.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 190。

```lean
Nat → Benitoite.Release.Refinement.ExternalFunctionId
```

## Benitoite.Release.Refinement.ExternalFunctionId.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 190。

```lean
{P : Sort u} →
  {declaration declaration' : Nat} →
    Benitoite.Release.Refinement.ExternalFunctionId.mk declaration =
        Benitoite.Release.Refinement.ExternalFunctionId.mk declaration' →
      (declaration = declaration' → P) → P
```

## Benitoite.Release.Refinement.ExternalFunctionId.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 189。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalFunctionId} →
    t = t' → Benitoite.Release.Refinement.ExternalFunctionId.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalHandle

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 123。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalHandle.component

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 125。

```lean
Benitoite.Release.Refinement.ExternalHandle → Benitoite.Release.Refinement.ComponentId
```

## Benitoite.Release.Refinement.ExternalHandle.identity

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 127。

```lean
Benitoite.Release.Refinement.ExternalHandle → Nat
```

## Benitoite.Release.Refinement.ExternalHandle.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 123。

```lean
Benitoite.Release.Refinement.ExternalId →
  Benitoite.Release.Refinement.ComponentId → Nat → Nat → Benitoite.Release.Refinement.ExternalHandle
```

## Benitoite.Release.Refinement.ExternalHandle.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 123。

```lean
{P : Sort u} →
  {typeId : Benitoite.Release.Refinement.ExternalId} →
    {component : Benitoite.Release.Refinement.ComponentId} →
      {resource identity : Nat} →
        {typeId' : Benitoite.Release.Refinement.ExternalId} →
          {component' : Benitoite.Release.Refinement.ComponentId} →
            {resource' identity' : Nat} →
              { typeId := typeId, component := component, resource := resource, identity := identity } =
                  { typeId := typeId', component := component', resource := resource', identity := identity' } →
                (typeId = typeId' → component = component' → resource = resource' → identity = identity' → P) → P
```

## Benitoite.Release.Refinement.ExternalHandle.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 123。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalHandle} →
    t = t' → Benitoite.Release.Refinement.ExternalHandle.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalHandle.resource

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 126。

```lean
Benitoite.Release.Refinement.ExternalHandle → Nat
```

## Benitoite.Release.Refinement.ExternalHandle.typeId

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 124。

```lean
Benitoite.Release.Refinement.ExternalHandle → Benitoite.Release.Refinement.ExternalId
```

## Benitoite.Release.Refinement.ExternalId

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 183。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalId.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 184。

```lean
Nat → Benitoite.Release.Refinement.ExternalId
```

## Benitoite.Release.Refinement.ExternalId.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 184。

```lean
{P : Sort u} →
  {declaration declaration' : Nat} →
    Benitoite.Release.Refinement.ExternalId.mk declaration = Benitoite.Release.Refinement.ExternalId.mk declaration' →
      (declaration = declaration' → P) → P
```

## Benitoite.Release.Refinement.ExternalId.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 183。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalId} →
    t = t' → Benitoite.Release.Refinement.ExternalId.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalKey

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 118。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalKey.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 118。

```lean
{motive : Benitoite.Release.Refinement.ExternalKey → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ExternalKey) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ExternalKey.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ExternalKey.function

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 120。

```lean
Benitoite.Release.Refinement.ExternalFunctionId → Benitoite.Release.Refinement.ExternalKey
```

## Benitoite.Release.Refinement.ExternalKey.function.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 120。

```lean
{motive : Benitoite.Release.Refinement.ExternalKey → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalKey) →
    t.ctorIdx = 1 →
      ((id : Benitoite.Release.Refinement.ExternalFunctionId) →
          motive (Benitoite.Release.Refinement.ExternalKey.function id)) →
        motive t
```

## Benitoite.Release.Refinement.ExternalKey.function.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 120。

```lean
{P : Sort u} →
  {id id' : Benitoite.Release.Refinement.ExternalFunctionId} →
    Benitoite.Release.Refinement.ExternalKey.function id = Benitoite.Release.Refinement.ExternalKey.function id' →
      (id = id' → P) → P
```

## Benitoite.Release.Refinement.ExternalKey.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 118。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalKey} →
    t = t' → Benitoite.Release.Refinement.ExternalKey.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalKey.type

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 119。

```lean
Benitoite.Release.Refinement.ExternalId → Benitoite.Release.Refinement.ExternalKey
```

## Benitoite.Release.Refinement.ExternalKey.type.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 119。

```lean
{motive : Benitoite.Release.Refinement.ExternalKey → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalKey) →
    t.ctorIdx = 0 →
      ((id : Benitoite.Release.Refinement.ExternalId) → motive (Benitoite.Release.Refinement.ExternalKey.type id)) →
        motive t
```

## Benitoite.Release.Refinement.ExternalKey.type.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 119。

```lean
{P : Sort u} →
  {id id' : Benitoite.Release.Refinement.ExternalId} →
    Benitoite.Release.Refinement.ExternalKey.type id = Benitoite.Release.Refinement.ExternalKey.type id' →
      (id = id' → P) → P
```

## Benitoite.Release.Refinement.ExternalMode

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 73。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalMode.borrow

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 74。

```lean
Benitoite.Release.Refinement.ExternalMode
```

## Benitoite.Release.Refinement.ExternalMode.borrow.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 74。

```lean
{motive : Benitoite.Release.Refinement.ExternalMode → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalMode) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.ExternalMode.borrow → motive t
```

## Benitoite.Release.Refinement.ExternalMode.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 73。

```lean
{motive : Benitoite.Release.Refinement.ExternalMode → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ExternalMode) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ExternalMode.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ExternalMode.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 73。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.ExternalMode} →
    x = y → Benitoite.Release.Refinement.ExternalMode.noConfusionType P x y
```

## Benitoite.Release.Refinement.ExternalMode.own

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 74。

```lean
Benitoite.Release.Refinement.ExternalMode
```

## Benitoite.Release.Refinement.ExternalMode.own.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 74。

```lean
{motive : Benitoite.Release.Refinement.ExternalMode → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalMode) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.ExternalMode.own → motive t
```

## Benitoite.Release.Refinement.ExternalOracle

所在: `formal/Benitoite/Release/Refinement/Step.lean`、行: 7。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalPathStep

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 94。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalPathStep.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 94。

```lean
{motive : Benitoite.Release.Refinement.ExternalPathStep → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ExternalPathStep) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ExternalPathStep.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ExternalPathStep.element

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 95。

```lean
Benitoite.Release.Refinement.ExternalPathStep
```

## Benitoite.Release.Refinement.ExternalPathStep.element.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 95。

```lean
{motive : Benitoite.Release.Refinement.ExternalPathStep → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalPathStep) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.ExternalPathStep.element → motive t
```

## Benitoite.Release.Refinement.ExternalPathStep.field

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 96。

```lean
Benitoite.Release.ConName → Nat → Benitoite.Release.Refinement.ExternalPathStep
```

## Benitoite.Release.Refinement.ExternalPathStep.field.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 96。

```lean
{motive : Benitoite.Release.Refinement.ExternalPathStep → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalPathStep) →
    t.ctorIdx = 3 →
      ((constructor : Benitoite.Release.ConName) →
          (index : Nat) → motive (Benitoite.Release.Refinement.ExternalPathStep.field constructor index)) →
        motive t
```

## Benitoite.Release.Refinement.ExternalPathStep.field.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 96。

```lean
{P : Sort u} →
  {constructor : Benitoite.Release.ConName} →
    {index : Nat} →
      {constructor' : Benitoite.Release.ConName} →
        {index' : Nat} →
          Benitoite.Release.Refinement.ExternalPathStep.field constructor index =
              Benitoite.Release.Refinement.ExternalPathStep.field constructor' index' →
            (constructor = constructor' → index = index' → P) → P
```

## Benitoite.Release.Refinement.ExternalPathStep.key

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 95。

```lean
Benitoite.Release.Refinement.ExternalPathStep
```

## Benitoite.Release.Refinement.ExternalPathStep.key.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 95。

```lean
{motive : Benitoite.Release.Refinement.ExternalPathStep → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalPathStep) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.ExternalPathStep.key → motive t
```

## Benitoite.Release.Refinement.ExternalPathStep.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 94。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalPathStep} →
    t = t' → Benitoite.Release.Refinement.ExternalPathStep.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalPathStep.value

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 95。

```lean
Benitoite.Release.Refinement.ExternalPathStep
```

## Benitoite.Release.Refinement.ExternalPathStep.value.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 95。

```lean
{motive : Benitoite.Release.Refinement.ExternalPathStep → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalPathStep) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.ExternalPathStep.value → motive t
```

## Benitoite.Release.Refinement.ExternalPosition

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 89。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalPosition.argument

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 90。

```lean
Nat → Benitoite.Release.Refinement.ExternalPosition
```

## Benitoite.Release.Refinement.ExternalPosition.argument.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 90。

```lean
{motive : Benitoite.Release.Refinement.ExternalPosition → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalPosition) →
    t.ctorIdx = 0 → ((index : Nat) → motive (Benitoite.Release.Refinement.ExternalPosition.argument index)) → motive t
```

## Benitoite.Release.Refinement.ExternalPosition.argument.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 90。

```lean
{P : Sort u} →
  {index index' : Nat} →
    Benitoite.Release.Refinement.ExternalPosition.argument index =
        Benitoite.Release.Refinement.ExternalPosition.argument index' →
      (index = index' → P) → P
```

## Benitoite.Release.Refinement.ExternalPosition.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 89。

```lean
{motive : Benitoite.Release.Refinement.ExternalPosition → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ExternalPosition) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ExternalPosition.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ExternalPosition.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 89。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalPosition} →
    t = t' → Benitoite.Release.Refinement.ExternalPosition.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalPosition.result

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 91。

```lean
Benitoite.Release.Refinement.ExternalPosition
```

## Benitoite.Release.Refinement.ExternalPosition.result.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 91。

```lean
{motive : Benitoite.Release.Refinement.ExternalPosition → Sort u} →
  (t : Benitoite.Release.Refinement.ExternalPosition) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.ExternalPosition.result → motive t
```

## Benitoite.Release.Refinement.ExternalSignature

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 106。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalSignature.component

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 107。

```lean
Benitoite.Release.Refinement.ExternalSignature → Benitoite.Release.Refinement.ComponentId
```

## Benitoite.Release.Refinement.ExternalSignature.displayName

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 108。

```lean
Benitoite.Release.Refinement.ExternalSignature → String
```

## Benitoite.Release.Refinement.ExternalSignature.kinds

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 110。

```lean
Benitoite.Release.Refinement.ExternalSignature → Benitoite.Release.Refinement.KindCtx
```

## Benitoite.Release.Refinement.ExternalSignature.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 106。

```lean
Benitoite.Release.Refinement.ComponentId →
  String →
    List Benitoite.Release.TParam →
      Benitoite.Release.Refinement.KindCtx →
        Benitoite.Release.Refinement.Tel →
          List Benitoite.Release.Refinement.ExternalUse → Benitoite.Release.Refinement.ExternalSignature
```

## Benitoite.Release.Refinement.ExternalSignature.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 106。

```lean
{P : Sort u} →
  {component : Benitoite.Release.Refinement.ComponentId} →
    {displayName : String} →
      {tparams : List Benitoite.Release.TParam} →
        {kinds : Benitoite.Release.Refinement.KindCtx} →
          {parameters : Benitoite.Release.Refinement.Tel} →
            {uses : List Benitoite.Release.Refinement.ExternalUse} →
              {component' : Benitoite.Release.Refinement.ComponentId} →
                {displayName' : String} →
                  {tparams' : List Benitoite.Release.TParam} →
                    {kinds' : Benitoite.Release.Refinement.KindCtx} →
                      {parameters' : Benitoite.Release.Refinement.Tel} →
                        {uses' : List Benitoite.Release.Refinement.ExternalUse} →
                          { component := component, displayName := displayName, tparams := tparams, kinds := kinds,
                                parameters := parameters, uses := uses } =
                              { component := component', displayName := displayName', tparams := tparams',
                                kinds := kinds', parameters := parameters', uses := uses' } →
                            (component = component' →
                                displayName = displayName' →
                                  tparams = tparams' → kinds = kinds' → parameters = parameters' → uses = uses' → P) →
                              P
```

## Benitoite.Release.Refinement.ExternalSignature.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 106。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalSignature} →
    t = t' → Benitoite.Release.Refinement.ExternalSignature.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalSignature.parameters

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 111。

```lean
Benitoite.Release.Refinement.ExternalSignature → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.ExternalSignature.tparams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 109。

```lean
Benitoite.Release.Refinement.ExternalSignature → List Benitoite.Release.TParam
```

## Benitoite.Release.Refinement.ExternalSignature.uses

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 112。

```lean
Benitoite.Release.Refinement.ExternalSignature → List Benitoite.Release.Refinement.ExternalUse
```

## Benitoite.Release.Refinement.ExternalTypeDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 82。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalTypeDecl.arity

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 86。

```lean
Benitoite.Release.Refinement.ExternalTypeDecl → Nat
```

## Benitoite.Release.Refinement.ExternalTypeDecl.component

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 84。

```lean
Benitoite.Release.Refinement.ExternalTypeDecl → Benitoite.Release.Refinement.ComponentId
```

## Benitoite.Release.Refinement.ExternalTypeDecl.displayName

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 85。

```lean
Benitoite.Release.Refinement.ExternalTypeDecl → String
```

## Benitoite.Release.Refinement.ExternalTypeDecl.id

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 83。

```lean
Benitoite.Release.Refinement.ExternalTypeDecl → Benitoite.Release.Refinement.ExternalId
```

## Benitoite.Release.Refinement.ExternalTypeDecl.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 82。

```lean
Benitoite.Release.Refinement.ExternalId →
  Benitoite.Release.Refinement.ComponentId → String → Nat → Nat → Benitoite.Release.Refinement.ExternalTypeDecl
```

## Benitoite.Release.Refinement.ExternalTypeDecl.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 82。

```lean
{P : Sort u} →
  {id : Benitoite.Release.Refinement.ExternalId} →
    {component : Benitoite.Release.Refinement.ComponentId} →
      {displayName : String} →
        {arity resource : Nat} →
          {id' : Benitoite.Release.Refinement.ExternalId} →
            {component' : Benitoite.Release.Refinement.ComponentId} →
              {displayName' : String} →
                {arity' resource' : Nat} →
                  { id := id, component := component, displayName := displayName, arity := arity,
                        resource := resource } =
                      { id := id', component := component', displayName := displayName', arity := arity',
                        resource := resource' } →
                    (id = id' →
                        component = component' →
                          displayName = displayName' → arity = arity' → resource = resource' → P) →
                      P
```

## Benitoite.Release.Refinement.ExternalTypeDecl.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 82。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalTypeDecl} →
    t = t' → Benitoite.Release.Refinement.ExternalTypeDecl.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalTypeDecl.resource

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 87。

```lean
Benitoite.Release.Refinement.ExternalTypeDecl → Nat
```

## Benitoite.Release.Refinement.ExternalUse

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 99。

```lean
Type
```

## Benitoite.Release.Refinement.ExternalUse.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 99。

```lean
Benitoite.Release.Refinement.ExternalPosition →
  List Benitoite.Release.Refinement.ExternalPathStep →
    Benitoite.Release.Refinement.ExternalMode →
      Benitoite.Release.Refinement.ExternalId → Benitoite.Release.Refinement.ExternalUse
```

## Benitoite.Release.Refinement.ExternalUse.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 99。

```lean
{P : Sort u} →
  {position : Benitoite.Release.Refinement.ExternalPosition} →
    {path : List Benitoite.Release.Refinement.ExternalPathStep} →
      {mode : Benitoite.Release.Refinement.ExternalMode} →
        {typeId : Benitoite.Release.Refinement.ExternalId} →
          {position' : Benitoite.Release.Refinement.ExternalPosition} →
            {path' : List Benitoite.Release.Refinement.ExternalPathStep} →
              {mode' : Benitoite.Release.Refinement.ExternalMode} →
                {typeId' : Benitoite.Release.Refinement.ExternalId} →
                  { position := position, path := path, mode := mode, typeId := typeId } =
                      { position := position', path := path', mode := mode', typeId := typeId' } →
                    (position = position' → path = path' → mode = mode' → typeId = typeId' → P) → P
```

## Benitoite.Release.Refinement.ExternalUse.mode

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 102。

```lean
Benitoite.Release.Refinement.ExternalUse → Benitoite.Release.Refinement.ExternalMode
```

## Benitoite.Release.Refinement.ExternalUse.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 99。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ExternalUse} →
    t = t' → Benitoite.Release.Refinement.ExternalUse.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ExternalUse.path

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 101。

```lean
Benitoite.Release.Refinement.ExternalUse → List Benitoite.Release.Refinement.ExternalPathStep
```

## Benitoite.Release.Refinement.ExternalUse.position

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 100。

```lean
Benitoite.Release.Refinement.ExternalUse → Benitoite.Release.Refinement.ExternalPosition
```

## Benitoite.Release.Refinement.ExternalUse.typeId

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 103。

```lean
Benitoite.Release.Refinement.ExternalUse → Benitoite.Release.Refinement.ExternalId
```

## Benitoite.Release.Refinement.FieldRef

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 199。

```lean
Type
```

## Benitoite.Release.Refinement.FieldRef.constructor

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 201。

```lean
Benitoite.Release.Refinement.FieldRef → Benitoite.Release.ConName
```

## Benitoite.Release.Refinement.FieldRef.mk

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 199。

```lean
Benitoite.Release.DataName →
  Benitoite.Release.ConName → Nat → Benitoite.Release.Refinement.Sort → Benitoite.Release.Refinement.FieldRef
```

## Benitoite.Release.Refinement.FieldRef.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 199。

```lean
{P : Sort u} →
  {owner : Benitoite.Release.DataName} →
    {constructor : Benitoite.Release.ConName} →
      {position : Nat} →
        {result : Benitoite.Release.Refinement.Sort} →
          {owner' : Benitoite.Release.DataName} →
            {constructor' : Benitoite.Release.ConName} →
              {position' : Nat} →
                {result' : Benitoite.Release.Refinement.Sort} →
                  { owner := owner, constructor := constructor, position := position, result := result } =
                      { owner := owner', constructor := constructor', position := position', result := result' } →
                    (owner = owner' → constructor = constructor' → position = position' → result = result' → P) → P
```

## Benitoite.Release.Refinement.FieldRef.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 199。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.FieldRef} → t = t' → Benitoite.Release.Refinement.FieldRef.noConfusionType P t t'
```

