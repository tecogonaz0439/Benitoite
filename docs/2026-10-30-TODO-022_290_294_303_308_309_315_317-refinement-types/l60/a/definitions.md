# 追加した定義の実体

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

```lean
def Benitoite.Release.Refinement.ResourceRelease.response : (Benitoite.Release.OpaqueName → Bool) →
  Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop :=
fun isResource v _r =>
  ∃ o i,
    v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o i) ∧
      isResource o = Bool.true
```

```lean
def Benitoite.Release.Refinement.FunctionNames.rename : Bool → String → String :=
fun refined name =>
  List.foldl
    (fun n old =>
      Benitoite.Release.Refinement.FunctionNames.swap old
        ("%" ++ old ++ if refined = Bool.true then ".refined" else ".ordinary") n)
    name Benitoite.Release.Refinement.FunctionNames.collisionNames
```

```lean
def Benitoite.Release.Refinement.FunctionNames.definition : (String → String) →
  Benitoite.Release.Refinement.Def → Benitoite.Release.Refinement.Def :=
fun ρ d =>
  { tparams := d.tparams, neffs := d.neffs, names := d.names, params := d.params, ret := d.ret, eff := d.eff,
    body := Benitoite.Release.Refinement.FunctionNames.computation ρ d.body }
```

```lean
def Benitoite.Release.Refinement.StandardModel.Body.definition : Benitoite.Release.Refinement.StandardModel.Body →
  Benitoite.Release.Refinement.Def :=
fun body =>
  Benitoite.Release.Refinement.FunctionNames.definition (Benitoite.Release.Refinement.FunctionNames.rename body.refined)
    body.original
```

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

```lean
def Benitoite.Release.Refinement.StandardModel.builtins : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins :=
fun P =>
  Benitoite.Release.Refinement.ExternalModel.builtins P Benitoite.Release.Refinement.StandardModel.baseBuiltins
    (Benitoite.Release.Refinement.ResourceRelease.response
      Benitoite.Release.Refinement.StandardModel.baseBuiltins.isResource)
```

