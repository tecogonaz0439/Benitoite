# 段末の実署名（続き）

## Benitoite.Release.Refinement.ScopeResponse.response

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 18。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    List.lookup b Benitoite.Release.Refinement.ScopeSignatures.entries = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
          B.valContent "Scope.PathIn" = Option.none →
            B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
              B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
                (∀ (r s : Benitoite.Release.Refinement.RangeExpr), B.admitsR "Scope.widenPathIn" [r, s] → s.Covers r) →
                  (∀ (r s : Benitoite.Release.Refinement.RangeExpr),
                      B.admitsR "Http.widenRequestIn" [r, s] → s.Covers r) →
                    Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
                      ∃ out,
                        Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws = Option.some out ∧
                          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                              Benitoite.Release.Refinement.AdequateResult ws out ∧
                                ∀ (v : Benitoite.Release.Refinement.Val),
                                  out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ScopeResponse.widen_admitted

所在: `formal/Benitoite/Release/Refinement/ScopeResponse.lean`、行: 41。

```lean
∀ {b : Benitoite.Release.PrimName},
  b = "Scope.widenPathIn" ∨ b = "Http.widenRequestIn" →
    ∀ {r s : Benitoite.Release.Refinement.RangeExpr},
      Benitoite.Release.Refinement.ScopeSignatures.admitsR b [r, s] → s.Covers r
```

## Benitoite.Release.Refinement.ScopeSignatures.admitsR

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 82。

```lean
Benitoite.Release.PrimName → List Benitoite.Release.Refinement.RangeExpr → Prop
```

## Benitoite.Release.Refinement.ScopeSignatures.admits_iff_count

所在: `formal/Benitoite/Release/Refinement/ScopeConstraintInstances.lean`、行: 7。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
    (sg.admits C ts ↔ ts.length = sg.tparams.length)
```

## Benitoite.Release.Refinement.ScopeSignatures.admits_sat

所在: `formal/Benitoite/Release/Refinement/ScopeConstraintInstances.lean`、行: 51。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {C : Benitoite.Release.Refinement.TypeCtx} {ts : List Benitoite.Release.Refinement.Ty},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
    sg.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io) C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints sg.tparams)
```

## Benitoite.Release.Refinement.ScopeSignatures.appendBytesIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 34。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.appendTextIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 30。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.builtins

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 90。

```lean
(Benitoite.Release.PrimName →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Eff →
        List Benitoite.Release.Refinement.RangeExpr →
          List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome) →
  (Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop) →
    Benitoite.Release.Refinement.Builtins
```

## Benitoite.Release.Refinement.ScopeSignatures.checkPathIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 40。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.checkRequestIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 42。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 15。

```lean
Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeSignatures.effKind

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 80。

```lean
Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind
```

## Benitoite.Release.Refinement.ScopeSignatures.effect_ops

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 154。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).effects l = Option.some bs →
    b ∈ bs →
      ∃ sg,
        (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg ∧
          (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            sg.opEff = Option.some l
```

## Benitoite.Release.Refinement.ScopeSignatures.effects

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 72。

```lean
Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

## Benitoite.Release.Refinement.ScopeSignatures.entries

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 63。

```lean
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

## Benitoite.Release.Refinement.ScopeSignatures.entries_scoped

所在: `formal/Benitoite/Release/Refinement/ScopeSignatureFormation.lean`、行: 10。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀ (row : Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig),
      row ∈ Benitoite.Release.Refinement.ScopeSignatures.entries → Benitoite.Release.Refinement.PrimSig.Scoped P row.snd
```

## Benitoite.Release.Refinement.ScopeSignatures.ioIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 20。

```lean
List String →
  List Benitoite.Release.Refinement.Ty →
    Benitoite.Release.Refinement.Ty →
      Benitoite.Release.EffName → Benitoite.Scope.Domain.Kind → Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.io_op

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 126。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).ShapeOk b sg
```

## Benitoite.Release.Refinement.ScopeSignatures.lookup_mem

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 110。

```lean
∀ {α : Type} {xs : List (Benitoite.Release.PrimName × α)} {b : Benitoite.Release.PrimName} {s : α},
  List.lookup b xs = Option.some s → (b, s) ∈ xs
```

## Benitoite.Release.Refinement.ScopeSignatures.opEff_io

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 175。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
    sg.opEff = Option.some l →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

## Benitoite.Release.Refinement.ScopeSignatures.pathBases

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 59。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.pathBasesName

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 57。

```lean
Benitoite.Release.PrimName
```

## Benitoite.Release.Refinement.ScopeSignatures.pathBases_no_io

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 165。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      ∀ (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
        (ws : List Benitoite.Release.Refinement.Val) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        ¬(Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.ScopeSignatures.pathBases_shape

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 144。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      sg.PathBasesShape (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io) b
```

## Benitoite.Release.Refinement.ScopeSignatures.pathIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 10。

```lean
Nat → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeSignatures.pathInValue

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 45。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.pureIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 17。

```lean
List String →
  List Benitoite.Release.Refinement.Ty →
    Benitoite.Release.Refinement.Ty → List Benitoite.Scope.Domain.Kind → Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.readBytesIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 26。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.readTextIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 24。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.refGet

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 50。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.refSet

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 53。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.requestCheckErrorTy

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 14。

```lean
Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeSignatures.requestIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 11。

```lean
Nat → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeSignatures.requestInValue

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 46。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.resultTy

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 12。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeSignatures.sat_unconstrained

所在: `formal/Benitoite/Release/Refinement/ScopeConstraintInstances.lean`、行: 46。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  (a : Benitoite.Release.Refinement.Ty),
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sat [] a.norm { }
```

## Benitoite.Release.Refinement.ScopeSignatures.scopeErrorTy

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 13。

```lean
Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopeSignatures.sendIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 36。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.sig_scoped

所在: `formal/Benitoite/Release/Refinement/ScopeSignatureFormation.lean`、行: 44。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀
      {delta :
        Benitoite.Release.PrimName →
          List Benitoite.Release.Refinement.Ty →
            List Benitoite.Release.Refinement.Eff →
              List Benitoite.Release.Refinement.RangeExpr →
                List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
      {io :
        Benitoite.Release.PrimName →
          List Benitoite.Release.Refinement.Ty →
            List Benitoite.Release.Refinement.Eff →
              List Benitoite.Release.Refinement.Val →
                Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
      {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
      (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
        Benitoite.Release.Refinement.PrimSig.Scoped P sg
```

## Benitoite.Release.Refinement.ScopeSignatures.sourceTelRows

所在: `formal/Benitoite/Release/Refinement/ScopeSignatureFormation.lean`、行: 49。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀
      {delta :
        Benitoite.Release.PrimName →
          List Benitoite.Release.Refinement.Ty →
            List Benitoite.Release.Refinement.Eff →
              List Benitoite.Release.Refinement.RangeExpr →
                List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
      {io :
        Benitoite.Release.PrimName →
          List Benitoite.Release.Refinement.Ty →
            List Benitoite.Release.Refinement.Eff →
              List Benitoite.Release.Refinement.Val →
                Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
      {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
      (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = Option.some sg →
        Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < sg.neffs) sg.tel
```

## Benitoite.Release.Refinement.ScopeSignatures.substitutionAssumptions

所在: `formal/Benitoite/Release/Refinement/ScopeConstraintInstances.lean`、行: 18。

```lean
∀ (P : Benitoite.Release.Refinement.Program)
  (delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome)
  (io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io)
```

## Benitoite.Release.Refinement.ScopeSignatures.unscopedIO

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 215。

```lean
List String →
  List Benitoite.Release.Refinement.Ty →
    Benitoite.Release.Refinement.Ty →
      Benitoite.Release.EffName →
        Benitoite.Scope.Signature.IOShape →
          optParam Benitoite.Release.Refinement.PrimKind Benitoite.Release.Refinement.PrimKind.io →
            Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.unscopedIO_shape

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 220。

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName} {l : Benitoite.Release.EffName}
  {names : List String} {params : List Benitoite.Release.Refinement.Ty} {ret : Benitoite.Release.Refinement.Ty}
  {shape : Benitoite.Scope.Signature.IOShape} {kind : Benitoite.Release.Refinement.PrimKind}
  {bs : List Benitoite.Release.PrimName},
  B.effects l = Option.some bs →
    b ∈ bs →
      (shape = Benitoite.Scope.Signature.IOShape.untargeted ∧ B.effKind l = Option.none ∨
          ∃ k, shape = Benitoite.Scope.Signature.IOShape.topTargeted k ∧ B.effKind l = Option.some k) →
        B.ShapeOk b (Benitoite.Release.Refinement.ScopeSignatures.unscopedIO names params ret l shape kind)
```

## Benitoite.Release.Refinement.ScopeSignatures.widenPathIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 47。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.widenRequestIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 48。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.writeBytesIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 32。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopeSignatures.writeTextIn

所在: `formal/Benitoite/Release/Refinement/ScopeSignatures.lean`、行: 28。

```lean
Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopedCallContracts.request_inputs

所在: `formal/Benitoite/Release/Refinement/ScopedCallContracts.lean`、行: 36。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {u : Benitoite.Release.Refinement.Tel} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es →
    B.RangeAdmissible b sg rs →
      Benitoite.Release.Refinement.SignatureInstance P [] [] (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
          (List.map Benitoite.Release.Refinement.TParamDecl.kind sg.tparams) ts es →
        Benitoite.Release.Refinement.TelClosure P [] []
            (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es) u →
          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws u a e →
            (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground) →
              B.ShapeOk b sg →
                sg.shape = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p →
                  Benitoite.Release.Refinement.NamesWF sg.names sg.params →
                    (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
                      (∀ (o : Benitoite.Release.OpaqueName),
                          sg.params[p]? =
                              Option.some
                                (Benitoite.Release.Refinement.Ty.opaque o
                                  (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                            B.valContent o = Option.some A) →
                        ∃ a₀ e₀ r w target req,
                          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                              (Benitoite.Release.Refinement.instantiatedTel
                                (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es)
                              a₀ e₀ ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]? = Option.some w ∧
                                    sg.shapeAt ws =
                                        Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint
                                          p ∧
                                      (w = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                                          ∃ s snapshot,
                                            w =
                                              Benitoite.Release.Refinement.Val.checkedAt s snapshot target
                                                (Option.some req)) ∧
                                        Benitoite.Release.Refinement.ModelHttp.valueRun [w] =
                                            Benitoite.Release.Refinement.Outcome.val req ∧
                                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                                            Benitoite.Release.Refinement.groundVal req = Bool.true ∧
                                              req.reqTarget = Option.some target ∧
                                                Benitoite.Release.Refinement.RangeExpr.Mem σ
                                                  Benitoite.Scope.Domain.Kind.endpoint r target
```

## Benitoite.Release.Refinement.ScopedCallContracts.single_inputs

所在: `formal/Benitoite/Release/Refinement/ScopedCallContracts.lean`、行: 11。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv} {u : Benitoite.Release.Refinement.Tel},
  Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es →
    B.RangeAdmissible b sg rs →
      Benitoite.Release.Refinement.SignatureInstance P [] [] (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
          (List.map Benitoite.Release.Refinement.TParamDecl.kind sg.tparams) ts es →
        Benitoite.Release.Refinement.TelClosure P [] []
            (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es) u →
          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws u a e →
            (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground) →
              B.ShapeOk b sg →
                sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
                  Benitoite.Release.Refinement.NamesWF sg.names sg.params →
                    (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
                      ∃ a₀ e₀ r t,
                        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                            (Benitoite.Release.Refinement.instantiatedTel
                              (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es)
                            a₀ e₀ ∧
                          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                              (Benitoite.Release.Refinement.Ty.normTys ts)
                              (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a₀ e₀ ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]?.bind Benitoite.Release.Refinement.Val.target? = Option.some t ∧
                                    Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                                      sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k p
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 77。

```lean
Type
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.appendBytes

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.appendBytes.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 5 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.appendBytes → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.appendText

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.appendText.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.appendText → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 77。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ScopedIOResponse.Operation.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.kind

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 106。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation → Benitoite.Scope.Domain.Kind
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.lookup

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 328。

```lean
∀ (op : Benitoite.Release.Refinement.ScopedIOResponse.Operation),
  List.lookup op.name Benitoite.Release.Refinement.ScopeSignatures.entries = Option.some op.signature
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.name

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 82。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation → Benitoite.Release.PrimName
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 77。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.ScopedIOResponse.Operation} →
    x = y → Benitoite.Release.Refinement.ScopedIOResponse.Operation.noConfusionType P x y
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.output

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 100。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation → Benitoite.Release.Refinement.ScopedIOResponse.ResultKind
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.params

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 110。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation →
  Benitoite.Release.Refinement.RangeExpr → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.readBytes

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.readBytes.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.readBytes → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.readText

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.readText.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.readText → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.send

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.send.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 6 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.send → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.signature

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 91。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation → Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.writeBytes

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.writeBytes.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.writeBytes → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.writeText

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.Operation.writeText.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 79。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.Operation → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.Operation) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.ScopedIOResponse.Operation.writeText → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.Payload

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 28。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Benitoite.Release.Refinement.Val → Prop
```

## Benitoite.Release.Refinement.ScopedIOResponse.Payload.bytes

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 31。

```lean
∀ (bs : List Nat),
  (∀ (b : Nat), b ∈ bs → b ≤ 255) →
    Benitoite.Release.Refinement.ScopedIOResponse.Payload Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.bytes
      (Benitoite.Release.Refinement.Val.bytesV bs)
```

## Benitoite.Release.Refinement.ScopedIOResponse.Payload.http

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 33。

```lean
∀ (id : Nat),
  Benitoite.Release.Refinement.ScopedIOResponse.Payload Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.http
    (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque "Http.Response" id))
```

## Benitoite.Release.Refinement.ScopedIOResponse.Payload.text

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 30。

```lean
∀ (s : String),
  Benitoite.Release.Refinement.ScopedIOResponse.Payload Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.text
    (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s))
```

## Benitoite.Release.Refinement.ScopedIOResponse.Payload.unit

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 32。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Payload Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.unit
  (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)
```

## Benitoite.Release.Refinement.ScopedIOResponse.Reply

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 35。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Benitoite.Release.Refinement.Outcome → Prop
```

## Benitoite.Release.Refinement.ScopedIOResponse.Reply.err

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 40。

```lean
∀ {k : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind} (reason : String),
  Benitoite.Release.Refinement.ScopedIOResponse.Reply k (Benitoite.Release.Refinement.Outcome.err reason)
```

## Benitoite.Release.Refinement.ScopedIOResponse.Reply.error

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 38。

```lean
∀ {k : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind} (id : Nat),
  Benitoite.Release.Refinement.ScopedIOResponse.Reply k
    (Benitoite.Release.Refinement.Outcome.val
      (Benitoite.Release.Refinement.ScopeDelta.resultValue Bool.false k.type
        (Benitoite.Release.Refinement.Ty.opaque k.errorName Benitoite.Release.Refinement.RangeIx.top)
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque k.errorName id))))
```

## Benitoite.Release.Refinement.ScopedIOResponse.Reply.ok

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 37。

```lean
∀ {k : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ScopedIOResponse.Payload k v →
    Benitoite.Release.Refinement.ScopedIOResponse.Reply k
      (Benitoite.Release.Refinement.Outcome.val
        (Benitoite.Release.Refinement.ScopeDelta.resultValue Bool.true k.type
          (Benitoite.Release.Refinement.Ty.opaque k.errorName Benitoite.Release.Refinement.RangeIx.top) v))
```

## Benitoite.Release.Refinement.ScopedIOResponse.RequestSent

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 121。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation →
  List Benitoite.Release.Refinement.Val → Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 10。

```lean
Type
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.Constants

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 42。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.bytes

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.bytes.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.bytes → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 10。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.errorName

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 21。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Benitoite.Release.OpaqueName
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.http

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.http.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.http → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 10。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind} →
    x = y → Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.noConfusionType P x y
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.result

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 25。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.text

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.text.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.text → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.type

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 15。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.unit

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ResultKind
```

## Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.unit.elim

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 12。

```lean
{motive : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind → Sort u} →
  (t : Benitoite.Release.Refinement.ScopedIOResponse.ResultKind) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.unit → motive t
```

## Benitoite.Release.Refinement.ScopedIOResponse.appendBytesIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 268。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "File.appendBytesIn"
            Benitoite.Release.Refinement.ScopeSignatures.appendBytesIn ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.appendBytesIn" ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                        (Benitoite.Release.Refinement.ScopeSignatures.appendBytesIn.shapeAt ws) ws obs) ∧
            ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.appendBytesIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.appendTextIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 257。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "File.appendTextIn"
            Benitoite.Release.Refinement.ScopeSignatures.appendTextIn ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.appendTextIn" ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                        (Benitoite.Release.Refinement.ScopeSignatures.appendTextIn.shapeAt ws) ws obs) ∧
            ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.appendTextIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.instDecidableEqOperation

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 80。

```lean
DecidableEq Benitoite.Release.Refinement.ScopedIOResponse.Operation
```

## Benitoite.Release.Refinement.ScopedIOResponse.instDecidableEqResultKind

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 13。

```lean
DecidableEq Benitoite.Release.Refinement.ScopedIOResponse.ResultKind
```

## Benitoite.Release.Refinement.ScopedIOResponse.ioResponse

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 128。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.ScopedIOResponse.io_exists

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 438。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).sig
          b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
            Ψ b sg ts es rs ws a e →
          ∃ out obs,
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                  Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).ioResponse
              b ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.io_kind

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 447。

```lean
∀
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
            Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).sig
        b =
      Option.some sg →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
            Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).ioResponse
        b ts es ws out obs →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
        ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.ScopedIOResponse.io_typed

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 427。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).sig
          b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
            Ψ b sg ts es rs ws a e →
          (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                  Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).ioResponse
              b ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P
                (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                  Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
                Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.ScopedIOResponse.obs_allowed

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 392。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).sig
          b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
            Ψ b sg ts es rs ws a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                    Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).ioResponse
                b ts es ws out obs →
              ∃ l,
                sg.opEff = Option.some l ∧
                  ∀ (t : Benitoite.Scope.Domain.Target),
                    t ∈ obs →
                      Benitoite.Release.Refinement.Eff.Allows σ
                        (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                            Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).effKind
                        e l t
```

## Benitoite.Release.Refinement.ScopedIOResponse.readBytesIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 224。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "File.readBytesIn"
            Benitoite.Release.Refinement.ScopeSignatures.readBytesIn ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.readBytesIn" ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                        (Benitoite.Release.Refinement.ScopeSignatures.readBytesIn.shapeAt ws) ws obs) ∧
            ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.readBytesIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.readTextIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 213。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "File.readTextIn"
            Benitoite.Release.Refinement.ScopeSignatures.readTextIn ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.readTextIn" ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                        (Benitoite.Release.Refinement.ScopeSignatures.readTextIn.shapeAt ws) ws obs) ∧
            ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.readTextIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.response

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 348。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    List.lookup b Benitoite.Release.Refinement.ScopeSignatures.entries = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
          B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
            B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
              B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
                B.valKind "Http.Response" = Option.none ∧ B.valContent "Http.Response" = Option.none →
                  B.valKind "NetworkError" = Option.none ∧ B.valContent "NetworkError" = Option.none →
                    Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
                      (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
                          Benitoite.Release.Refinement.ScopedIOResponse.ioResponse b ts es ws out obs →
                            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                              Benitoite.Release.Refinement.AdequateResult ws out ∧
                                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                                  Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                                    (sg.shapeAt ws) ws obs) ∧
                        ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.responseAssumptions

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 461。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P
      (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta
        Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
```

## Benitoite.Release.Refinement.ScopedIOResponse.sendIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 294。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Http.RequestIn" = Option.some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = Option.some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        B.valKind "Http.Response" = Option.none ∧ B.valContent "Http.Response" = Option.none →
          B.valKind "NetworkError" = Option.none ∧ B.valContent "NetworkError" = Option.none →
            Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.sendIn"
                Benitoite.Release.Refinement.ScopeSignatures.sendIn ts es rs ws a e →
              (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
                  Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "Http.sendIn" ts es ws out obs →
                    Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                      Benitoite.Release.Refinement.AdequateResult ws out ∧
                        (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                          Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                            (Benitoite.Release.Refinement.ScopeSignatures.sendIn.shapeAt ws) ws obs) ∧
                ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "Http.sendIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.sent_request

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 317。

```lean
∀ {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "Http.sendIn" ts es ws out obs →
    ∃ w req t,
      ws = [w] ∧
        Benitoite.Release.Refinement.ModelHttp.valueRun [w] = Benitoite.Release.Refinement.Outcome.val req ∧
          Benitoite.Release.Refinement.groundVal req = Bool.true ∧
            req.reqTarget = Option.some t ∧ w.target? = Option.some t ∧ obs = [t]
```

## Benitoite.Release.Refinement.ScopedIOResponse.targetAgreement

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 383。

```lean
∀ (P : Benitoite.Release.Refinement.Program)
  (delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
      Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
```

## Benitoite.Release.Refinement.ScopedIOResponse.target_member

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 403。

```lean
∀ {P : Benitoite.Release.Refinement.Program}
  {delta :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.RangeExpr →
            List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).sig
          b =
        Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
            Ψ b sg ts es rs ws a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                    Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).ioResponse
                b ts es ws out obs →
              ∃ k r t l,
                sg.shape = Benitoite.Scope.Signature.IOShape.single k 0 ∧
                  rs = [r] ∧
                    obs = [t] ∧
                      ws[0]?.bind Benitoite.Release.Refinement.Val.target? = Option.some t ∧
                        Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                          sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k 0 ∧
                            sg.opEff = Option.some l ∧
                              Benitoite.Release.Refinement.Eff.Allows σ
                                (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                                    Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).effKind
                                e l t
```

## Benitoite.Release.Refinement.ScopedIOResponse.targets

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 372。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  List.lookup b Benitoite.Release.Refinement.ScopeSignatures.entries = Option.some sg →
    Benitoite.Release.Refinement.ScopedIOResponse.ioResponse b ts es ws out obs →
      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.writeBytesIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 246。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "File.writeBytesIn"
            Benitoite.Release.Refinement.ScopeSignatures.writeBytesIn ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.writeBytesIn" ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                        (Benitoite.Release.Refinement.ScopeSignatures.writeBytesIn.shapeAt ws) ws obs) ∧
            ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.writeBytesIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedIOResponse.writeTextIn

所在: `formal/Benitoite/Release/Refinement/ScopedIOResponse.lean`、行: 235。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = Option.some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "File.writeTextIn"
            Benitoite.Release.Refinement.ScopeSignatures.writeTextIn ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.writeTextIn" ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                        (Benitoite.Release.Refinement.ScopeSignatures.writeTextIn.shapeAt ws) ws obs) ∧
            ∃ out obs, Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "File.writeTextIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ScopedTargetExamples.absolute_projection

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 390。

```lean
∀ (r s : Benitoite.Release.Refinement.RangeExpr) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (w : Benitoite.Scope.Domain.Word),
  Benitoite.Release.Refinement.ScopeDelta.widenRun
        [Benitoite.Release.Refinement.Val.checkedAt r snapshot (Benitoite.Scope.Domain.Target.path w) Option.none] =
      Benitoite.Release.Refinement.Outcome.val
        (Benitoite.Release.Refinement.Val.checkedAt r snapshot (Benitoite.Scope.Domain.Target.path w) Option.none) ∧
    Benitoite.Release.Refinement.ModelTargets.builtins.delta "Scope.pathInValue" [] [] [s]
        [Benitoite.Release.Refinement.Val.checkedAt r snapshot (Benitoite.Scope.Domain.Target.path w) Option.none] =
      Option.some
        (Benitoite.Release.Refinement.Outcome.val
          (Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.Const.string ("/" ++ "/".intercalate w))))
```

## Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 294。

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv) (a b : Benitoite.Release.Refinement.PathBase),
  a ≠ b →
    σ.lookup a = σ.lookup b →
      ∀ (p : Benitoite.Scope.Domain.PathPattern),
        (∀ (k : Benitoite.Scope.Domain.Kind) (t : Benitoite.Scope.Domain.Target),
            Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.based a p) t ↔
              Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.based b p) t) ∧
          ∀ (q : Benitoite.Scope.Domain.PathPattern),
            ¬(Benitoite.Release.Refinement.RangeExpr.based a p).Covers
                (Benitoite.Release.Refinement.RangeExpr.based b q)
```

## Benitoite.Release.Refinement.ScopedTargetExamples.incomparable

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 265。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr},
  ¬s.Covers r →
    ¬Benitoite.Release.Refinement.Ty.LeQ P Γ Φ
        (Benitoite.Release.Refinement.Ty.scoped o k (Benitoite.Release.Refinement.RangeIx.fixed r))
        (Benitoite.Release.Refinement.Ty.scoped o k (Benitoite.Release.Refinement.RangeIx.fixed s))
```

## Benitoite.Release.Refinement.ScopedTargetExamples.no_collective_cover

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 311。

```lean
∀ {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {e f : Benitoite.Release.Refinement.Eff} {a : Benitoite.Release.Refinement.Atom},
  f.mem a →
    (∀ (b : Benitoite.Release.Refinement.Atom), e.mem b → ¬b.Covers a) →
      ¬Benitoite.Release.Refinement.Eff.Covers Γ Φ e f
```

## Benitoite.Release.Refinement.ScopedTargetExamples.one

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 319。

```lean
Benitoite.Release.EffName → Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.ScopedTargetExamples.request_io

所在: `formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean`、行: 46。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {u : Benitoite.Release.Refinement.Tel} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p →
          Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es →
            B.RangeAdmissible b sg rs →
              Benitoite.Release.Refinement.SignatureInstance P [] [] (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
                  (List.map Benitoite.Release.Refinement.TParamDecl.kind sg.tparams) ts es →
                Benitoite.Release.Refinement.TelClosure P [] []
                    (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts
                      es)
                    u →
                  Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws u a e →
                    (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground) →
                      (∀ (w : Benitoite.Release.Refinement.Val),
                          w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
                        (∀ (o : Benitoite.Release.OpaqueName),
                            sg.params[p]? =
                                Option.some
                                  (Benitoite.Release.Refinement.Ty.opaque o
                                    (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                              B.valContent o = Option.some A) →
                          ∃ a₀ e₀ r w target req,
                            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                                (Benitoite.Release.Refinement.Ty.normTys ts)
                                (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a₀ e₀ ∧
                              Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                                Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                  rs = [r] ∧
                                    ws[p]? = Option.some w ∧
                                      (w = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                                          ∃ s snapshot,
                                            w =
                                              Benitoite.Release.Refinement.Val.checkedAt s snapshot target
                                                (Option.some req)) ∧
                                        Benitoite.Release.Refinement.ModelHttp.valueRun [w] =
                                            Benitoite.Release.Refinement.Outcome.val req ∧
                                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                                            Benitoite.Release.Refinement.groundVal req = Bool.true ∧
                                              req.reqTarget = Option.some target ∧
                                                Benitoite.Release.Refinement.RangeExpr.Mem σ
                                                    Benitoite.Scope.Domain.Kind.endpoint r target ∧
                                                  (∃ out obs,
                                                      B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                                        (List.map Benitoite.Release.Refinement.Eff.norm es) ws out
                                                        obs) ∧
                                                    ∀ (out : Benitoite.Release.Refinement.Outcome)
                                                      (obs : List Benitoite.Scope.Domain.Target),
                                                      B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                                          (List.map Benitoite.Release.Refinement.Eff.norm es) ws out
                                                          obs →
                                                        obs = [target] ∧
                                                          Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a₀ ∧
                                                            Benitoite.Release.Refinement.AdequateResult ws out
```

