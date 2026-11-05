# 段末の主な定義の本体

生成物（[audit.py](audit.py)）。`#print` の出力。

## `Builtins.TypingFieldsEq`

```lean
structure Benitoite.Release.Refinement.Builtins.TypingFieldsEq (B B' : Benitoite.Release.Refinement.Builtins) : Prop
number of parameters: 2
fields:
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.sig : B.sig = B'.sig
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.sat : B.sat = B'.sat
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.ranges : B.admitsR = B'.admitsR
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.resources : B.isResource = B'.isResource
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.kinds : B.valKind = B'.valKind
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.content : B.valContent = B'.valContent
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.effects : B.effects = B'.effects
constructor:
  Benitoite.Release.Refinement.Builtins.TypingFieldsEq.mk {B B' : Benitoite.Release.Refinement.Builtins}
    (sig : B.sig = B'.sig) (sat : B.sat = B'.sat) (ranges : B.admitsR = B'.admitsR)
    (resources : B.isResource = B'.isResource) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
    (effects : B.effects = B'.effects) : B.TypingFieldsEq B'
```

## `ExternalNominal.Preserves`

```lean
def Benitoite.Release.Refinement.ExternalNominal.Preserves : (Benitoite.Release.Refinement.Ty →
    Benitoite.Release.Refinement.Ty) →
  Prop :=
fun transform =>
  ∀ (id : Benitoite.Release.Refinement.ExternalId) (args : List Benitoite.Release.Refinement.Ty),
    ∃ resultArgs,
      (transform (Benitoite.Release.Refinement.Ty.external id args)).core =
        Benitoite.Release.Refinement.Ty.external id resultArgs
```

## `ExternalModel.response`

```lean
def Benitoite.Release.Refinement.ExternalModel.response : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.ExternalFunctionId →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Val →
          Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop :=
fun P base f ts vs out obs =>
  obs = [] ∧
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (d : Benitoite.Release.Refinement.ExternalSignature)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
      P.externalFunction f = Option.some d →
        Benitoite.Release.Refinement.ExternalArgs P base Ψ d ts vs a e →
          Benitoite.Release.Refinement.Outcome.Carrier P base Ψ out a ∧
            ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## `ExternalModel.builtins`

```lean
def Benitoite.Release.Refinement.ExternalModel.builtins : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    (Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop) →
      Benitoite.Release.Refinement.Builtins :=
fun P base release =>
  { sig := base.sig, delta := base.delta, ioResponse := base.ioResponse, releaseResponse := release,
    isResource := base.isResource, effects := base.effects, sat := base.sat, refGet := base.refGet,
    refSet := base.refSet, effKind := base.effKind, valKind := base.valKind, admitsR := base.admitsR,
    valContent := base.valContent, externalResponse := Benitoite.Release.Refinement.ExternalModel.response P base }
```

## `Builtins.selectExternal`

```lean
def Benitoite.Release.Refinement.Builtins.selectExternal : Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.Refinement.ExternalOracle :=
fun B f ts vs =>
  if h : ∃ out obs, B.externalResponse f ts vs out obs then
    (Classical.choose h, Classical.choose (Benitoite.Release.Refinement.Builtins.selectExternal._proof_1 B f ts vs h))
  else (Benitoite.Release.Refinement.Outcome.err "External", [])
```

## `ResourceRelease.response`

```lean
def Benitoite.Release.Refinement.ResourceRelease.response : (Benitoite.Release.OpaqueName → Bool) →
  Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop :=
fun isResource v _r =>
  ∃ o i,
    v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o i) ∧
      isResource o = Bool.true
```

## `ResourceRelease.Table`

```lean
structure Benitoite.Release.Refinement.ResourceRelease.Table (B : Benitoite.Release.Refinement.Builtins) : Prop
number of parameters: 1
fields:
  Benitoite.Release.Refinement.ResourceRelease.Table.release : B.releaseResponse =
      Benitoite.Release.Refinement.ResourceRelease.response B.isResource
  Benitoite.Release.Refinement.ResourceRelease.Table.classification : ∀ (name : Benitoite.Release.OpaqueName),
      B.isResource name = Bool.true → B.valKind name = Option.none
constructor:
  Benitoite.Release.Refinement.ResourceRelease.Table.mk {B : Benitoite.Release.Refinement.Builtins}
    (release : B.releaseResponse = Benitoite.Release.Refinement.ResourceRelease.response B.isResource)
    (classification :
      ∀ (name : Benitoite.Release.OpaqueName), B.isResource name = Bool.true → B.valKind name = Option.none) :
    Benitoite.Release.Refinement.ResourceRelease.Table B
```

## `ExternalSurface.callEffect`

```lean
def Benitoite.Release.Refinement.ExternalSurface.callEffect : Benitoite.Release.Refinement.ExternalSignature →
  Benitoite.Release.Refinement.Eff :=
fun d =>
  if d.uses = [] then Benitoite.Release.Refinement.Eff.empty
  else
    Benitoite.Release.Refinement.EffR.mk
      (fun a =>
        match a with
        |
        Benitoite.Release.Refinement.Atom.name n
            (Benitoite.Release.Refinement.RangeIx.fixed
              (Benitoite.Release.Refinement.RangeExpr.absolute Benitoite.Scope.Domain.Range.top)) =>
          Decidable.decide (n = Benitoite.Release.stateEff)
        | x => Bool.false)
      []
```

## `ExternalModels.model`

```lean
def Benitoite.Release.Refinement.ExternalModels.model : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins :=
fun P =>
  Benitoite.Release.Refinement.ExternalModel.builtins P Benitoite.Release.Refinement.Model.builtins
    (Benitoite.Release.Refinement.ResourceRelease.response Benitoite.Release.Refinement.Model.builtins.isResource)
```

## `ExternalModels.targets`

```lean
def Benitoite.Release.Refinement.ExternalModels.targets : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins :=
fun P =>
  Benitoite.Release.Refinement.ExternalModel.builtins P Benitoite.Release.Refinement.ModelTargets.builtins
    (Benitoite.Release.Refinement.ResourceRelease.response
      Benitoite.Release.Refinement.ModelTargets.builtins.isResource)
```

## `ExternalModels.http`

```lean
def Benitoite.Release.Refinement.ExternalModels.http : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins :=
fun P =>
  Benitoite.Release.Refinement.ExternalModel.builtins P Benitoite.Release.Refinement.ModelHttp.builtins
    (Benitoite.Release.Refinement.ResourceRelease.response Benitoite.Release.Refinement.ModelHttp.builtins.isResource)
```

## `StandardModel.program`

```lean
def Benitoite.Release.Refinement.StandardModel.program : List
    (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl) →
  Benitoite.Release.Refinement.Program :=
fun externals =>
  have __src := Benitoite.Release.Refinement.StandardOrdinaryCoreProgram.program;
  {
    defs := fun n =>
      Option.map Benitoite.Release.Refinement.StandardModel.Body.definition
        (List.find? (fun body => Decidable.decide (body.key = n)) Benitoite.Release.Refinement.StandardModel.Body.all),
    cons := fun n => List.lookup n Benitoite.Release.Refinement.StandardModel.constructors, ops := __src.ops,
    effects := __src.effects, classes := __src.classes, impls := __src.impls, externals := externals,
    dataInfo := __src.dataInfo }
```

## `StandardModel.builtins`

```lean
def Benitoite.Release.Refinement.StandardModel.builtins : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins :=
fun P =>
  Benitoite.Release.Refinement.ExternalModel.builtins P Benitoite.Release.Refinement.StandardModel.baseBuiltins
    (Benitoite.Release.Refinement.ResourceRelease.response
      Benitoite.Release.Refinement.StandardModel.baseBuiltins.isResource)
```

## `StandardModel.PureRow`

```lean
def Benitoite.Release.Refinement.StandardModel.PureRow : Benitoite.Release.Refinement.Program →
  Benitoite.Release.PrimName → Prop :=
fun P b =>
  ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (sg : Benitoite.Release.Refinement.PrimSig)
    (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
    (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
    (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
    (Benitoite.Release.Refinement.StandardModel.builtins P).sig b = Option.some sg →
      Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.StandardModel.builtins P) Ψ b sg ts es rs
          ws a e →
        ∃ out,
          (Benitoite.Release.Refinement.StandardModel.builtins P).delta b ts es rs ws = Option.some out ∧
            (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
              Benitoite.Release.Refinement.Outcome.Typed P (Benitoite.Release.Refinement.StandardModel.builtins P) Ψ out
                  a ∧
                Benitoite.Release.Refinement.AdequateResult ws out
```

## `StandardModel.PureRow.Satisfiable`

```lean
def Benitoite.Release.Refinement.StandardModel.PureRow.Satisfiable : Benitoite.Release.Refinement.Program →
  Benitoite.Release.PrimName → Prop :=
fun P b =>
  ∃ Ψ sg ts es rs ws a e,
    (Benitoite.Release.Refinement.StandardModel.builtins P).sig b = Option.some sg ∧
      Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.StandardModel.builtins P) Ψ b sg ts es rs
        ws a e
```

## `StandardModel.IORow.Satisfiable`

```lean
def Benitoite.Release.Refinement.StandardModel.IORow.Satisfiable : Benitoite.Release.Refinement.Program →
  Benitoite.Release.PrimName → Prop :=
fun P b =>
  ∃ Ψ sg ts es rs ws a e,
    (Benitoite.Release.Refinement.StandardModel.builtins P).sig b = Option.some sg ∧
      Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.StandardModel.builtins P) Ψ b sg ts es rs
        ws a e
```

## `FunctionNames.rename`

```lean
def Benitoite.Release.Refinement.FunctionNames.rename : Bool → String → String :=
fun refined name =>
  List.foldl
    (fun n old =>
      Benitoite.Release.Refinement.FunctionNames.swap old
        ("%" ++ old ++ if refined = Bool.true then ".refined" else ".ordinary") n)
    name Benitoite.Release.Refinement.FunctionNames.collisionNames
```

