# 段末の実署名（続き）

## Benitoite.Release.Refinement.Builtins.TargetAgreement

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 70。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.Builtins.TargetAgreement.io_target

所在: `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`、行: 71。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.TargetAgreement P B →
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
              Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs
```

## Benitoite.Release.Refinement.Builtins.TargetAgreement.obs_allowed

所在: `formal/Benitoite/Release/Refinement/EffectTargets.lean`、行: 265。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  B.ShapeOk b sg →
    Benitoite.Release.Refinement.Builtins.TargetAgreement P B →
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.NamesWF sg.names sg.params →
            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
              (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
                B.ioResponse b ts es ws out obs →
                  ∃ l,
                    sg.opEff = Option.some l ∧
                      ∀ (t : Benitoite.Scope.Domain.Target),
                        t ∈ obs → Benitoite.Release.Refinement.Eff.Allows σ B.effKind e l t
```

## Benitoite.Release.Refinement.Builtins.TypeAssumptions

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 26。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.Builtins.TypeAssumptions.admits_renameTypes

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 31。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.TypeAssumptions P B →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (ts : List Benitoite.Release.Refinement.Ty) (ρ : Nat → Nat),
      B.sig b = Option.some sg →
        Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
          Benitoite.Release.Refinement.TypeAnnotations P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations P C' Δ (List.map (fun a => a.renameTypes ρ) ts) →
              sg.admits C.constraints ts → sg.admits C'.constraints (List.map (fun a => a.renameTypes ρ) ts)
```

## Benitoite.Release.Refinement.Builtins.TypeAssumptions.admits_subst

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 38。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.TypeAssumptions P B →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C0 C1 : Benitoite.Release.Refinement.TypeCtx) (ts ts' : List Benitoite.Release.Refinement.Ty)
      (es' : List Benitoite.Release.Refinement.Eff),
      B.sig b = Option.some sg →
        sg.admits (C1 ++ C0).constraints ts →
          (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts' → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
            Benitoite.Release.Refinement.SatAll B C1 ts' C0.constraints →
              ts'.length = List.length C0 →
                sg.admits C1.constraints
                  (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts' es') ts)
```

## Benitoite.Release.Refinement.Builtins.TypeAssumptions.sat_renameTypes

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 28。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.TypeAssumptions P B →
    ∀ (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ρ : Nat → Nat),
      Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation P C' Δ (a.renameTypes ρ) →
            B.sat C.constraints a p → B.sat C'.constraints (a.renameTypes ρ) p
```

## Benitoite.Release.Refinement.Builtins.TypeAssumptions.sat_subst

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 34。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.TypeAssumptions P B →
    ∀ (C0 C1 : Benitoite.Release.Refinement.TypeCtx) (a : Benitoite.Release.Refinement.Ty)
      (p : Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff),
      B.sat (C1 ++ C0).constraints a p →
        (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
          Benitoite.Release.Refinement.SatAll B C1 ts C0.constraints →
            ts.length = List.length C0 →
              B.sat C1.constraints (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p
```

## Benitoite.Release.Refinement.Builtins.ValueAssumptions

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 12。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.Builtins.ValueAssumptions.admits_rename

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 16。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ValueAssumptions P B →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (ts : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
      B.sig b = Option.some sg →
        (∀ (i j : Nat), i < j → ξ i < ξ j) →
          Benitoite.Release.Refinement.TypeAnnotations P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations P C Δ (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) →
              sg.admits C.constraints ts →
                sg.admits C.constraints (List.map (Benitoite.Release.Refinement.renameTy ξ) ts)
```

## Benitoite.Release.Refinement.Builtins.ValueAssumptions.admits_values

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 22。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ValueAssumptions P B →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
      (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = Option.some sg →
        Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
          Benitoite.Release.Refinement.TypeAnnotations P C Γ ts →
            sg.admits C.constraints ts →
              sg.admits C.constraints (List.map (Benitoite.Release.Refinement.substTyValues ν) ts)
```

## Benitoite.Release.Refinement.Builtins.ValueAssumptions.sat_rename

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 13。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ValueAssumptions P B →
    ∀ (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ξ : Nat → Nat),
      (∀ (i j : Nat), i < j → ξ i < ξ j) →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation P C Δ (Benitoite.Release.Refinement.renameTy ξ a) →
            B.sat C.constraints a p → B.sat C.constraints (Benitoite.Release.Refinement.renameTy ξ a) p
```

## Benitoite.Release.Refinement.Builtins.ValueAssumptions.sat_values

所在: `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`、行: 20。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ValueAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam),
      Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
          B.sat C.constraints a p → B.sat C.constraints (Benitoite.Release.Refinement.substTyValues ν a) p
```

## Benitoite.Release.Refinement.Builtins.admitsR

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 448。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName → List Benitoite.Release.Refinement.RangeExpr → Prop
```

## Benitoite.Release.Refinement.Builtins.delta

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 423。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.PrimName →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Eff →
        List Benitoite.Release.Refinement.RangeExpr →
          List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.Builtins.effKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 441。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind
```

## Benitoite.Release.Refinement.Builtins.effects

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 432。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

## Benitoite.Release.Refinement.Builtins.externalResponse

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 452。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.Refinement.ExternalFunctionId →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.Builtins.ioResponse

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 426。

```lean
Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.PrimName →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Eff →
        List Benitoite.Release.Refinement.Val →
          Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.Builtins.isResource

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 430。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.OpaqueName → Bool
```

## Benitoite.Release.Refinement.Builtins.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 420。

```lean
(Benitoite.Release.PrimName → Option Benitoite.Release.Refinement.PrimSig) →
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
      (Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop) →
        (Benitoite.Release.OpaqueName → Bool) →
          (Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)) →
            (List Benitoite.Release.TParam → Benitoite.Release.Refinement.Ty → Benitoite.Release.TParam → Prop) →
              Benitoite.Release.PrimName →
                Benitoite.Release.PrimName →
                  (Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind) →
                    (Benitoite.Release.OpaqueName → Option Benitoite.Scope.Domain.Kind) →
                      (Benitoite.Release.PrimName → List Benitoite.Release.Refinement.RangeExpr → Prop) →
                        (Benitoite.Release.OpaqueName → Option Benitoite.Release.Refinement.Ty) →
                          (Benitoite.Release.Refinement.ExternalFunctionId →
                              List Benitoite.Release.Refinement.Ty →
                                List Benitoite.Release.Refinement.Val →
                                  Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop) →
                            Benitoite.Release.Refinement.Builtins
```

## Benitoite.Release.Refinement.Builtins.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 420。

```lean
{P : Sort u} →
  {sig : Benitoite.Release.PrimName → Option Benitoite.Release.Refinement.PrimSig} →
    {delta :
        Benitoite.Release.PrimName →
          List Benitoite.Release.Refinement.Ty →
            List Benitoite.Release.Refinement.Eff →
              List Benitoite.Release.Refinement.RangeExpr →
                List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome} →
      {ioResponse :
          Benitoite.Release.PrimName →
            List Benitoite.Release.Refinement.Ty →
              List Benitoite.Release.Refinement.Eff →
                List Benitoite.Release.Refinement.Val →
                  Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop} →
        {releaseResponse : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop} →
          {isResource : Benitoite.Release.OpaqueName → Bool} →
            {effects : Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)} →
              {sat :
                  List Benitoite.Release.TParam → Benitoite.Release.Refinement.Ty → Benitoite.Release.TParam → Prop} →
                {refGet refSet : Benitoite.Release.PrimName} →
                  {effKind : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} →
                    {valKind : Benitoite.Release.OpaqueName → Option Benitoite.Scope.Domain.Kind} →
                      {admitsR : Benitoite.Release.PrimName → List Benitoite.Release.Refinement.RangeExpr → Prop} →
                        {valContent : Benitoite.Release.OpaqueName → Option Benitoite.Release.Refinement.Ty} →
                          {externalResponse :
                              Benitoite.Release.Refinement.ExternalFunctionId →
                                List Benitoite.Release.Refinement.Ty →
                                  List Benitoite.Release.Refinement.Val →
                                    Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop} →
                            {sig' : Benitoite.Release.PrimName → Option Benitoite.Release.Refinement.PrimSig} →
                              {delta' :
                                  Benitoite.Release.PrimName →
                                    List Benitoite.Release.Refinement.Ty →
                                      List Benitoite.Release.Refinement.Eff →
                                        List Benitoite.Release.Refinement.RangeExpr →
                                          List Benitoite.Release.Refinement.Val →
                                            Option Benitoite.Release.Refinement.Outcome} →
                                {ioResponse' :
                                    Benitoite.Release.PrimName →
                                      List Benitoite.Release.Refinement.Ty →
                                        List Benitoite.Release.Refinement.Eff →
                                          List Benitoite.Release.Refinement.Val →
                                            Benitoite.Release.Refinement.Outcome →
                                              List Benitoite.Scope.Domain.Target → Prop} →
                                  {releaseResponse' :
                                      Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop} →
                                    {isResource' : Benitoite.Release.OpaqueName → Bool} →
                                      {effects' :
                                          Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)} →
                                        {sat' :
                                            List Benitoite.Release.TParam →
                                              Benitoite.Release.Refinement.Ty → Benitoite.Release.TParam → Prop} →
                                          {refGet' refSet' : Benitoite.Release.PrimName} →
                                            {effKind' :
                                                Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} →
                                              {valKind' :
                                                  Benitoite.Release.OpaqueName → Option Benitoite.Scope.Domain.Kind} →
                                                {admitsR' :
                                                    Benitoite.Release.PrimName →
                                                      List Benitoite.Release.Refinement.RangeExpr → Prop} →
                                                  {valContent' :
                                                      Benitoite.Release.OpaqueName →
                                                        Option Benitoite.Release.Refinement.Ty} →
                                                    {externalResponse' :
                                                        Benitoite.Release.Refinement.ExternalFunctionId →
                                                          List Benitoite.Release.Refinement.Ty →
                                                            List Benitoite.Release.Refinement.Val →
                                                              Benitoite.Release.Refinement.Outcome →
                                                                List Benitoite.Scope.Domain.Target → Prop} →
                                                      { sig := sig, delta := delta, ioResponse := ioResponse,
                                                            releaseResponse := releaseResponse,
                                                            isResource := isResource, effects := effects, sat := sat,
                                                            refGet := refGet, refSet := refSet, effKind := effKind,
                                                            valKind := valKind, admitsR := admitsR,
                                                            valContent := valContent,
                                                            externalResponse := externalResponse } =
                                                          { sig := sig', delta := delta', ioResponse := ioResponse',
                                                            releaseResponse := releaseResponse',
                                                            isResource := isResource', effects := effects', sat := sat',
                                                            refGet := refGet', refSet := refSet', effKind := effKind',
                                                            valKind := valKind', admitsR := admitsR',
                                                            valContent := valContent',
                                                            externalResponse := externalResponse' } →
                                                        (sig = sig' →
                                                            delta = delta' →
                                                              ioResponse = ioResponse' →
                                                                releaseResponse = releaseResponse' →
                                                                  isResource = isResource' →
                                                                    effects = effects' →
                                                                      sat = sat' →
                                                                        refGet = refGet' →
                                                                          refSet = refSet' →
                                                                            effKind = effKind' →
                                                                              valKind = valKind' →
                                                                                admitsR = admitsR' →
                                                                                  valContent = valContent' →
                                                                                    externalResponse =
                                                                                        externalResponse' →
                                                                                      P) →
                                                          P
```

## Benitoite.Release.Refinement.Builtins.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 420。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Builtins} → t = t' → Benitoite.Release.Refinement.Builtins.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Builtins.refGet

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 436。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName
```

## Benitoite.Release.Refinement.Builtins.refSet

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 437。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName
```

## Benitoite.Release.Refinement.Builtins.releaseResponse

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 428。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop
```

## Benitoite.Release.Refinement.Builtins.sat

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 434。

```lean
Benitoite.Release.Refinement.Builtins →
  List Benitoite.Release.TParam → Benitoite.Release.Refinement.Ty → Benitoite.Release.TParam → Prop
```

## Benitoite.Release.Refinement.Builtins.sig

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 421。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName → Option Benitoite.Release.Refinement.PrimSig
```

## Benitoite.Release.Refinement.Builtins.valContent

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 451。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.OpaqueName → Option Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.Builtins.valKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 444。

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.OpaqueName → Option Benitoite.Scope.Domain.Kind
```

## Benitoite.Release.Refinement.Capture

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 214。

```lean
Type
```

## Benitoite.Release.Refinement.Capture.Adequate

所在: `formal/Benitoite/Release/Refinement/Adequate.lean`、行: 50。

```lean
Benitoite.Release.Refinement.PathEnv → Benitoite.Release.Refinement.Capture → Prop
```

## Benitoite.Release.Refinement.Capture.empty

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 250。

```lean
Benitoite.Release.Refinement.Capture
```

## Benitoite.Release.Refinement.Capture.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 215。

```lean
List (Option Benitoite.Release.Refinement.Val) → Benitoite.Release.Refinement.Capture
```

## Benitoite.Release.Refinement.Capture.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 215。

```lean
{P : Sort u} →
  {values values' : List (Option Benitoite.Release.Refinement.Val)} →
    Benitoite.Release.Refinement.Capture.mk values = Benitoite.Release.Refinement.Capture.mk values' →
      (values = values' → P) → P
```

## Benitoite.Release.Refinement.Capture.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 214。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Capture} → t = t' → Benitoite.Release.Refinement.Capture.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Capture.values

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 241。

```lean
Benitoite.Release.Refinement.Capture → List (Option Benitoite.Release.Refinement.Val)
```

## Benitoite.Release.Refinement.CaptureReadBoundary.hidden_capture_reply_states

所在: `formal/Benitoite/Release/Refinement/CaptureReadBoundary.lean`、行: 297。

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv),
  σ.Valid →
    (Benitoite.Release.Refinement.StateTyE Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
          Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ Benitoite.Release.Refinement.Eff.empty
          (Benitoite.Release.Refinement.State.error ["HiddenBuilder7"] [] Benitoite.Release.Refinement.Store.empty) ∧
        Benitoite.Release.Refinement.LocalStateInvariant Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
          Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ
          (Benitoite.Release.Refinement.State.error ["HiddenBuilder7"] [] Benitoite.Release.Refinement.Store.empty)) ∧
      Benitoite.Release.Refinement.StateTyE Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
          Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ Benitoite.Release.Refinement.Eff.empty
          (Benitoite.Release.Refinement.State.error ["HiddenBuilderOther"] []
            Benitoite.Release.Refinement.Store.empty) ∧
        Benitoite.Release.Refinement.LocalStateInvariant Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
          Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ
          (Benitoite.Release.Refinement.State.error ["HiddenBuilderOther"] [] Benitoite.Release.Refinement.Store.empty)
```

## Benitoite.Release.Refinement.CaptureReadBoundary.primitive_reads_hidden_capture

所在: `formal/Benitoite/Release/Refinement/CaptureReadBoundary.lean`、行: 276。

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝.WellFormed ∧
    Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝.WellTyped
        Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ ∧
      Benitoite.Release.Refinement.Builtins.CoreAssumptions
          Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
          Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ ∧
        Benitoite.Release.Refinement.CaptureOk Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
            Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ Benitoite.Release.Refinement.StoreTy.empty
            Option.none [Option.none] [] (Benitoite.Release.Refinement.CaptureReadBoundary.unreadCapture✝ 7) ∧
          Benitoite.Release.Refinement.CaptureOk Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
              Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ Benitoite.Release.Refinement.StoreTy.empty
              Option.none [Option.none] [] (Benitoite.Release.Refinement.CaptureReadBoundary.unreadCapture✝ 8) ∧
            Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝.delta "Example.inspect" [] [] []
                  [Benitoite.Release.Refinement.CaptureReadBoundary.argument✝ 7] ≠
                Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝.delta "Example.inspect" [] [] []
                  [Benitoite.Release.Refinement.CaptureReadBoundary.argument✝ 8] ∧
              Benitoite.Release.Refinement.StateTyE Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
                  Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ
                  Benitoite.Release.Refinement.Eff.empty
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.CaptureReadBoundary.call✝ 7))
                    [] Benitoite.Release.Refinement.Store.empty) ∧
                Benitoite.Release.Refinement.StateTyE Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
                    Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ
                    Benitoite.Release.Refinement.Eff.empty
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure
                        (Benitoite.Release.Refinement.CaptureReadBoundary.call✝ 8))
                      [] Benitoite.Release.Refinement.Store.empty) ∧
                  Benitoite.Release.Refinement.Step Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
                      Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.CaptureReadBoundary.call✝ 7))
                        [] Benitoite.Release.Refinement.Store.empty)
                      Option.none
                      (Benitoite.Release.Refinement.State.error ["HiddenBuilder7"] []
                        Benitoite.Release.Refinement.Store.empty) ∧
                    Benitoite.Release.Refinement.Step Benitoite.Release.Refinement.CaptureReadBoundary.modelProgram✝
                      Benitoite.Release.Refinement.CaptureReadBoundary.modelBuiltins✝ σ
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.CaptureReadBoundary.call✝ 8))
                        [] Benitoite.Release.Refinement.Store.empty)
                      Option.none
                      (Benitoite.Release.Refinement.State.error ["HiddenBuilderOther"] []
                        Benitoite.Release.Refinement.Store.empty)
```

## Benitoite.Release.Refinement.Cell.cont

所在: `formal/Benitoite/Release/Refinement/RuntimeSyntax.lean`、行: 22。

```lean
Benitoite.Release.Refinement.Cont → Benitoite.Release.Refinement.Cell
```

## Benitoite.Release.Refinement.Certificate.Legacy

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 8。

```lean
Type
```

## Benitoite.Release.Refinement.Certificate.Legacy.cases

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 13。

```lean
Benitoite.Release.Refinement.Certificate.Legacy →
  Benitoite.Release.Refinement.Certificate.Legacy → Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.Certificate.Legacy.cases.elim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 13。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (t : Benitoite.Release.Refinement.Certificate.Legacy) →
    t.ctorIdx = 4 →
      ((left right : Benitoite.Release.Refinement.Certificate.Legacy) → motive (left.cases right)) → motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.cases.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 13。

```lean
{P : Sort u} →
  {left right left' right' : Benitoite.Release.Refinement.Certificate.Legacy} →
    left.cases right = left'.cases right' → (left = left' → right = right' → P) → P
```

## Benitoite.Release.Refinement.Certificate.Legacy.check

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 16。

```lean
List Benitoite.Release.Refinement.Pred →
  Benitoite.Release.Refinement.Pred → Benitoite.Release.Refinement.Certificate.Legacy → Bool
```

## Benitoite.Release.Refinement.Certificate.Legacy.consume

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 12。

```lean
Benitoite.Release.Refinement.Certificate.Legacy → Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.Certificate.Legacy.consume.elim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 12。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (t : Benitoite.Release.Refinement.Certificate.Legacy) →
    t.ctorIdx = 3 → ((next : Benitoite.Release.Refinement.Certificate.Legacy) → motive next.consume) → motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.consume.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 12。

```lean
{P : Sort u} →
  {next next' : Benitoite.Release.Refinement.Certificate.Legacy} → next.consume = next'.consume → (next = next' → P) → P
```

## Benitoite.Release.Refinement.Certificate.Legacy.ctorElim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 8。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Certificate.Legacy) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Certificate.Legacy.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.discard

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 14。

```lean
Benitoite.Release.Refinement.Certificate.Legacy → Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.Certificate.Legacy.discard.elim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 14。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (t : Benitoite.Release.Refinement.Certificate.Legacy) →
    t.ctorIdx = 5 → ((next : Benitoite.Release.Refinement.Certificate.Legacy) → motive next.discard) → motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.discard.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 14。

```lean
{P : Sort u} →
  {next next' : Benitoite.Release.Refinement.Certificate.Legacy} → next.discard = next'.discard → (next = next' → P) → P
```

## Benitoite.Release.Refinement.Certificate.Legacy.embed

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 30。

```lean
Benitoite.Release.Refinement.Certificate.Legacy → Benitoite.Release.Refinement.Certificate
```

## Benitoite.Release.Refinement.Certificate.Legacy.leaf

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 10。

```lean
Benitoite.Release.Refinement.PreparedLeaf → Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.Certificate.Legacy.leaf.elim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 10。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (t : Benitoite.Release.Refinement.Certificate.Legacy) →
    t.ctorIdx = 1 →
      ((value : Benitoite.Release.Refinement.PreparedLeaf) →
          motive (Benitoite.Release.Refinement.Certificate.Legacy.leaf value)) →
        motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.leaf.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 10。

```lean
{P : Sort u} →
  {value value' : Benitoite.Release.Refinement.PreparedLeaf} →
    Benitoite.Release.Refinement.Certificate.Legacy.leaf value =
        Benitoite.Release.Refinement.Certificate.Legacy.leaf value' →
      (value = value' → P) → P
```

## Benitoite.Release.Refinement.Certificate.Legacy.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 8。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Certificate.Legacy} →
    t = t' → Benitoite.Release.Refinement.Certificate.Legacy.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Certificate.Legacy.substitute

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 11。

```lean
Benitoite.Release.Refinement.Pred →
  Benitoite.Release.Refinement.Term →
    Benitoite.Release.Refinement.Term →
      Benitoite.Release.Refinement.EqProof →
        Benitoite.Release.Refinement.Certificate.Legacy → Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.Certificate.Legacy.substitute.elim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 11。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (t : Benitoite.Release.Refinement.Certificate.Legacy) →
    t.ctorIdx = 2 →
      ((predicate : Benitoite.Release.Refinement.Pred) →
          (left right : Benitoite.Release.Refinement.Term) →
            (eq : Benitoite.Release.Refinement.EqProof) →
              (proof : Benitoite.Release.Refinement.Certificate.Legacy) →
                motive (Benitoite.Release.Refinement.Certificate.Legacy.substitute predicate left right eq proof)) →
        motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.substitute.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 11。

```lean
{P : Sort u} →
  {predicate : Benitoite.Release.Refinement.Pred} →
    {left right : Benitoite.Release.Refinement.Term} →
      {eq : Benitoite.Release.Refinement.EqProof} →
        {proof : Benitoite.Release.Refinement.Certificate.Legacy} →
          {predicate' : Benitoite.Release.Refinement.Pred} →
            {left' right' : Benitoite.Release.Refinement.Term} →
              {eq' : Benitoite.Release.Refinement.EqProof} →
                {proof' : Benitoite.Release.Refinement.Certificate.Legacy} →
                  Benitoite.Release.Refinement.Certificate.Legacy.substitute predicate left right eq proof =
                      Benitoite.Release.Refinement.Certificate.Legacy.substitute predicate' left' right' eq' proof' →
                    (predicate = predicate' → left = left' → right = right' → eq = eq' → proof = proof' → P) → P
```

## Benitoite.Release.Refinement.Certificate.Legacy.success_preserved

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 44。

```lean
∀ {c : Benitoite.Release.Refinement.Certificate.Legacy} {Φ : List Benitoite.Release.Refinement.Pred}
  {goal : Benitoite.Release.Refinement.Pred},
  Benitoite.Release.Refinement.Certificate.Legacy.check Φ goal c = Bool.true →
    Benitoite.Release.Refinement.Certificate.check Φ goal c.embed = Bool.true
```

## Benitoite.Release.Refinement.Certificate.Legacy.use

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 9。

```lean
Nat → Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.Certificate.Legacy.use.elim

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 9。

```lean
{motive : Benitoite.Release.Refinement.Certificate.Legacy → Sort u} →
  (t : Benitoite.Release.Refinement.Certificate.Legacy) →
    t.ctorIdx = 0 → ((index : Nat) → motive (Benitoite.Release.Refinement.Certificate.Legacy.use index)) → motive t
```

## Benitoite.Release.Refinement.Certificate.Legacy.use.noConfusion

所在: `formal/Benitoite/Release/Refinement/CertificateLegacy.lean`、行: 9。

```lean
{P : Sort u} →
  {index index' : Nat} →
    Benitoite.Release.Refinement.Certificate.Legacy.use index =
        Benitoite.Release.Refinement.Certificate.Legacy.use index' →
      (index = index' → P) → P
```

## Benitoite.Release.Refinement.CertificateKernelExamples.badTwice

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 54。

```lean
Benitoite.Release.Refinement.Certificate
```

## Benitoite.Release.Refinement.CertificateKernelExamples.bad_twice_rejected

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 56。

```lean
Benitoite.Release.Refinement.CertificateKernel.check Benitoite.Release.Refinement.CertificateKernelExamples.premise
    Benitoite.Release.Refinement.CertificateKernelExamples.goal
    Benitoite.Release.Refinement.CertificateKernelExamples.badTwice =
  Bool.false
```

## Benitoite.Release.Refinement.CertificateKernelExamples.booleanApart

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 68。

```lean
Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.CertificateKernelExamples.booleanLeaf

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 71。

```lean
Benitoite.Release.Refinement.Certificate
```

## Benitoite.Release.Refinement.CertificateKernelExamples.float_between

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 154。

```lean
∀ (w : Benitoite.Release.Refinement.FloatWidth) (a lo hi : Benitoite.Release.Refinement.Term),
  Benitoite.Release.Refinement.Entails
    [Benitoite.Release.Refinement.Pred.floatClass w Benitoite.Release.Refinement.FloatClass.finite lo,
      Benitoite.Release.Refinement.Pred.floatClass w Benitoite.Release.Refinement.FloatClass.finite hi,
      Benitoite.Release.Refinement.Pred.compare (Benitoite.Release.Refinement.BuiltinSchema.floatSort w)
        Benitoite.Release.Refinement.Comparison.ge a lo,
      Benitoite.Release.Refinement.Pred.compare (Benitoite.Release.Refinement.BuiltinSchema.floatSort w)
        Benitoite.Release.Refinement.Comparison.le a hi]
    (Benitoite.Release.Refinement.Pred.floatClass w Benitoite.Release.Refinement.FloatClass.finite a)
```

## Benitoite.Release.Refinement.CertificateKernelExamples.goal

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 9。

```lean
Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.CertificateKernelExamples.images

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 23。

```lean
List Benitoite.Release.Refinement.ObservationEnv
```

## Benitoite.Release.Refinement.CertificateKernelExamples.legacySix

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 91。

```lean
Benitoite.Release.Refinement.Certificate.Legacy
```

## Benitoite.Release.Refinement.CertificateKernelExamples.negativeLength

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 60。

```lean
Benitoite.Release.Refinement.Certificate
```

## Benitoite.Release.Refinement.CertificateKernelExamples.negative_length_checked

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 63。

```lean
Benitoite.Release.Refinement.CertificateKernel.check
    (Benitoite.Release.Refinement.Pred.lt
      (Benitoite.Release.Refinement.Term.measure Benitoite.Release.Refinement.Measure.listLength
        (Benitoite.Release.Refinement.Term.var 0))
      (Benitoite.Release.Refinement.Term.integer 0))
    Benitoite.Release.Refinement.Pred.falsity Benitoite.Release.Refinement.CertificateKernelExamples.negativeLength =
  Bool.true
```

## Benitoite.Release.Refinement.CertificateKernelExamples.nonnegative

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 58。

```lean
Benitoite.Release.Refinement.PreparedLeaf
```

## Benitoite.Release.Refinement.CertificateKernelExamples.premise

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 8。

```lean
Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.CertificateKernelExamples.replacing

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 80。

```lean
Benitoite.Release.Refinement.Certificate
```

## Benitoite.Release.Refinement.CertificateKernelExamples.source

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 78。

```lean
Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.CertificateKernelExamples.target

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 79。

```lean
Benitoite.Release.Refinement.Pred
```

## Benitoite.Release.Refinement.CertificateKernelExamples.twice

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 10。

```lean
Benitoite.Release.Refinement.Certificate
```

## Benitoite.Release.Refinement.CertificateKernelExamples.twice_checked

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 13。

```lean
Benitoite.Release.Refinement.CertificateKernel.check Benitoite.Release.Refinement.CertificateKernelExamples.premise
    Benitoite.Release.Refinement.CertificateKernelExamples.goal
    Benitoite.Release.Refinement.CertificateKernelExamples.twice =
  Bool.true
```

## Benitoite.Release.Refinement.CertificateKernelExamples.twice_entails

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 15。

```lean
Benitoite.Release.Refinement.Entails [Benitoite.Release.Refinement.CertificateKernelExamples.premise]
  Benitoite.Release.Refinement.CertificateKernelExamples.goal
```

## Benitoite.Release.Refinement.CertificateKernelExamples.twice_entails_at

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 18。

```lean
∀ (ν : Benitoite.Release.Refinement.ObservationEnv),
  Benitoite.Release.Refinement.Entails
    [Benitoite.Release.Refinement.predBind ν Benitoite.Release.Refinement.CertificateKernelExamples.premise]
    (Benitoite.Release.Refinement.predBind ν Benitoite.Release.Refinement.CertificateKernelExamples.goal)
```

## Benitoite.Release.Refinement.CertificateKernelExamples.typed_twice

所在: `formal/Benitoite/Release/Refinement/CertificateKernelExamples.lean`、行: 110。

```lean
Benitoite.Release.Refinement.Certificate.checkIn Benitoite.Release.Refinement.CertificateKernelExamples.P✝ []
    Benitoite.Release.Refinement.CertificateKernelExamples.Γ✝
    [Benitoite.Release.Refinement.CertificateKernelExamples.premise]
    Benitoite.Release.Refinement.CertificateKernelExamples.goal
    Benitoite.Release.Refinement.CertificateKernelExamples.twice =
  Bool.true
```

## Benitoite.Release.Refinement.CheckedWitness.absolute_plain

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 40。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Scope.Domain.Range} {t : Benitoite.Scope.Domain.Target},
  B.valKind o = Option.some k →
    B.valContent o = Option.none →
      Benitoite.Scope.Domain.Range.MemK k r t →
        Benitoite.Release.Refinement.CheckedWitness P B Ψ o k (Benitoite.Release.Refinement.RangeExpr.absolute r)
          Option.none t Option.none
```

## Benitoite.Release.Refinement.CheckedWitness.absolute_request

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 45。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {o : Benitoite.Release.OpaqueName} {r : Benitoite.Scope.Domain.Range}
  {t : Benitoite.Scope.Domain.Target} {req : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty},
  B.valKind o = Option.some Benitoite.Scope.Domain.Kind.endpoint →
    B.valContent o = Option.some T →
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req T →
        Benitoite.Release.Refinement.groundVal req = Bool.true →
          req.reqTarget = Option.some t →
            Benitoite.Scope.Domain.Range.MemK Benitoite.Scope.Domain.Kind.endpoint r t →
              Benitoite.Release.Refinement.CheckedWitness P B Ψ o Benitoite.Scope.Domain.Kind.endpoint
                (Benitoite.Release.Refinement.RangeExpr.absolute r) Option.none t (Option.some req)
```

## Benitoite.Release.Refinement.CheckedWitness.kind

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 15。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {target : Benitoite.Scope.Domain.Target} {req : Option Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.CheckedWitness P B Ψ o k r snapshot target req → target.kind = k
```

## Benitoite.Release.Refinement.CheckedWitness.membership

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 21。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {target : Benitoite.Scope.Domain.Target} {req : Option Benitoite.Release.Refinement.Val}
  {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.CheckedWitness P B Ψ o k r snapshot target req →
    Benitoite.Release.Refinement.SnapshotAdequate σ snapshot r → Benitoite.Release.Refinement.RangeExpr.Mem σ k r target
```

## Benitoite.Release.Refinement.CheckedWitness.of_prepared_request

所在: `formal/Benitoite/Release/Refinement/AtTyping.lean`、行: 51。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {cap : Benitoite.Release.Refinement.Capture}
  {name : Benitoite.Release.OpaqueName} {kind : Benitoite.Scope.Domain.Kind} {T : Benitoite.Release.Refinement.Ty}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {pat : Benitoite.Release.Refinement.RangeExpr} {target : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  B.valKind name = Option.some kind →
    B.valContent name = Option.some T →
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] (Benitoite.Release.Refinement.closeVal cap input) T.norm →
        Benitoite.Release.Refinement.AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
          (∀ (σ : Benitoite.Release.Refinement.PathEnv), snapshot = Option.some σ → σ.Valid) →
            Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
                Benitoite.Release.Refinement.AtResult.ok t →
              Benitoite.Release.Refinement.CheckedWitness P B Ψ name kind bound snapshot t
                (Benitoite.Release.Refinement.AtRequest B name (Benitoite.Release.Refinement.closeVal cap input))
```

## Benitoite.Release.Refinement.ClassDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 300。

```lean
Type
```

## Benitoite.Release.Refinement.ClassDecl.argumentKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 302。

```lean
Benitoite.Release.Refinement.ClassDecl → Benitoite.Release.Refinement.TyKind
```

## Benitoite.Release.Refinement.ClassDecl.methods

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 304。

```lean
Benitoite.Release.Refinement.ClassDecl → Benitoite.Release.MethName → Option Benitoite.Release.Refinement.MethSig
```

## Benitoite.Release.Refinement.ClassDecl.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 301。

```lean
Benitoite.Release.Refinement.TyKind →
  List Benitoite.Release.ClassName →
    (Benitoite.Release.MethName → Option Benitoite.Release.Refinement.MethSig) → Benitoite.Release.Refinement.ClassDecl
```

## Benitoite.Release.Refinement.ClassDecl.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 301。

```lean
{P : Sort u} →
  {argumentKind : Benitoite.Release.Refinement.TyKind} →
    {supers : List Benitoite.Release.ClassName} →
      {methods : Benitoite.Release.MethName → Option Benitoite.Release.Refinement.MethSig} →
        {argumentKind' : Benitoite.Release.Refinement.TyKind} →
          {supers' : List Benitoite.Release.ClassName} →
            {methods' : Benitoite.Release.MethName → Option Benitoite.Release.Refinement.MethSig} →
              { argumentKind := argumentKind, supers := supers, methods := methods } =
                  { argumentKind := argumentKind', supers := supers', methods := methods' } →
                (argumentKind = argumentKind' → supers = supers' → methods = methods' → P) → P
```

## Benitoite.Release.Refinement.ClassDecl.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 300。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.ClassDecl} →
    t = t' → Benitoite.Release.Refinement.ClassDecl.noConfusionType P t t'
```

## Benitoite.Release.Refinement.ClassDecl.supers

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 303。

```lean
Benitoite.Release.Refinement.ClassDecl → List Benitoite.Release.ClassName
```

## Benitoite.Release.Refinement.Clause

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 204。

```lean
Type
```

## Benitoite.Release.Refinement.Clause.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 204。

```lean
{motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Clause) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Clause.ctorElimType ctorIdx → motive_3 t
```

## Benitoite.Release.Refinement.Clause.fail

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 208。

```lean
Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Clause
```

## Benitoite.Release.Refinement.Clause.fail.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 208。

```lean
{motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
  (t : Benitoite.Release.Refinement.Clause) →
    t.ctorIdx = 1 →
      ((error : Benitoite.Release.Refinement.Ty) →
          (body : Benitoite.Release.Refinement.Comp) → motive_3 (Benitoite.Release.Refinement.Clause.fail error body)) →
        motive_3 t
```

## Benitoite.Release.Refinement.Clause.fail.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 208。

```lean
{P : Sort u} →
  {error : Benitoite.Release.Refinement.Ty} →
    {body : Benitoite.Release.Refinement.Comp} →
      {error' : Benitoite.Release.Refinement.Ty} →
        {body' : Benitoite.Release.Refinement.Comp} →
          Benitoite.Release.Refinement.Clause.fail error body = Benitoite.Release.Refinement.Clause.fail error' body' →
            (error = error' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Clause.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 207。

```lean
Benitoite.Release.OpRef → Nat → Nat → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Clause
```

## Benitoite.Release.Refinement.Clause.mk.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 207。

```lean
{motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
  (t : Benitoite.Release.Refinement.Clause) →
    t.ctorIdx = 0 →
      ((op : Benitoite.Release.OpRef) →
          (arity ntys : Nat) →
            (body : Benitoite.Release.Refinement.Comp) →
              motive_3 (Benitoite.Release.Refinement.Clause.mk op arity ntys body)) →
        motive_3 t
```

## Benitoite.Release.Refinement.Clause.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 207。

```lean
{P : Sort u} →
  {op : Benitoite.Release.OpRef} →
    {arity ntys : Nat} →
      {body : Benitoite.Release.Refinement.Comp} →
        {op' : Benitoite.Release.OpRef} →
          {arity' ntys' : Nat} →
            {body' : Benitoite.Release.Refinement.Comp} →
              Benitoite.Release.Refinement.Clause.mk op arity ntys body =
                  Benitoite.Release.Refinement.Clause.mk op' arity' ntys' body' →
                (op = op' → arity = arity' → ntys = ntys' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Clause.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 204。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Clause} → t = t' → Benitoite.Release.Refinement.Clause.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Closure

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 217。

```lean
Type
```

## Benitoite.Release.Refinement.Closure.capture

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 244。

```lean
Benitoite.Release.Refinement.Closure → Benitoite.Release.Refinement.Capture
```

## Benitoite.Release.Refinement.Closure.code

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 247。

```lean
Benitoite.Release.Refinement.Closure → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Closure.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 218。

```lean
Benitoite.Release.Refinement.Capture → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Closure
```

## Benitoite.Release.Refinement.Closure.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 218。

```lean
{P : Sort u} →
  {capture : Benitoite.Release.Refinement.Capture} →
    {code : Benitoite.Release.Refinement.Comp} →
      {capture' : Benitoite.Release.Refinement.Capture} →
        {code' : Benitoite.Release.Refinement.Comp} →
          Benitoite.Release.Refinement.Closure.mk capture code =
              Benitoite.Release.Refinement.Closure.mk capture' code' →
            (capture = capture' → code = code' → P) → P
```

## Benitoite.Release.Refinement.Closure.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 217。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Closure} → t = t' → Benitoite.Release.Refinement.Closure.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Closure.pure

所在: `formal/Benitoite/Release/Refinement/Capture.lean`、行: 31。

```lean
Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Closure
```

## Benitoite.Release.Refinement.ClosureTy

所在: `formal/Benitoite/Release/Refinement/Typing.lean`、行: 506。

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      List Benitoite.Release.Refinement.Ty →
        Option Benitoite.Release.Refinement.Ty →
          Benitoite.Release.Refinement.Closure →
            Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

## Benitoite.Release.Refinement.Comp

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 178。

```lean
Type
```

## Benitoite.Release.Refinement.Comp.ClosedAt

所在: `formal/Benitoite/Release/Refinement/Ground.lean`、行: 40。

```lean
Nat → Nat → Benitoite.Release.Refinement.Comp → Prop
```

## Benitoite.Release.Refinement.Comp.Source

所在: `formal/Benitoite/Release/Refinement/Source.lean`、行: 17。

```lean
Benitoite.Release.Refinement.Comp → Prop
```

## Benitoite.Release.Refinement.Comp.Source.adequate

所在: `formal/Benitoite/Release/Refinement/PreparationTargets.lean`、行: 41。

```lean
∀ {m : Benitoite.Release.Refinement.Comp},
  m.Source → ∀ (σ : Benitoite.Release.Refinement.PathEnv), Benitoite.Release.Refinement.Comp.Adequate σ m
```

## Benitoite.Release.Refinement.Comp.SourceScoped.runtime_inst

所在: `formal/Benitoite/Release/Refinement/CallBodyScope.lean`、行: 126。

```lean
∀ {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff} {c ne nv : Nat}
  {m : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.Comp.SourceScoped 0 (c + ts.length) ne nv m →
    (∀ (a : Benitoite.Release.Refinement.Ty), a ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 a) →
      (∀ (e : Benitoite.Release.Refinement.Eff), e ∈ es → Benitoite.Release.Refinement.Eff.WF 0 0 0 e) →
        (∀ (a : Benitoite.Release.Refinement.Ty), a ∈ ts → Benitoite.Release.Refinement.Ordinary a) →
          ∀ (σ : Benitoite.Release.Refinement.PathEnv),
            Benitoite.Release.Refinement.Comp.ClosedAt c nv (Benitoite.Release.Refinement.Comp.substTyAt c ts es m) ∧
              Benitoite.Release.Refinement.Comp.Adequate σ (Benitoite.Release.Refinement.Comp.substTyAt c ts es m)
```

## Benitoite.Release.Refinement.Comp.app

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 183。

```lean
Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.app.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 183。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 4 →
      ((f : Benitoite.Release.Refinement.Val) →
          (args : List Benitoite.Release.Refinement.Val) → motive_2 (Benitoite.Release.Refinement.Comp.app f args)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.app.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 183。

```lean
{P : Sort u} →
  {f : Benitoite.Release.Refinement.Val} →
    {args : List Benitoite.Release.Refinement.Val} →
      {f' : Benitoite.Release.Refinement.Val} →
        {args' : List Benitoite.Release.Refinement.Val} →
          Benitoite.Release.Refinement.Comp.app f args = Benitoite.Release.Refinement.Comp.app f' args' →
            (f = f' → args = args' → P) → P
```

## Benitoite.Release.Refinement.Comp.builderLet

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 179。

```lean
Benitoite.Release.Refinement.BuilderKind → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.builderLet.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 179。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 0 →
      ((kind : Benitoite.Release.Refinement.BuilderKind) →
          (body : Benitoite.Release.Refinement.Comp) →
            motive_2 (Benitoite.Release.Refinement.Comp.builderLet kind body)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.builderLet.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 179。

```lean
{P : Sort u} →
  {kind : Benitoite.Release.Refinement.BuilderKind} →
    {body : Benitoite.Release.Refinement.Comp} →
      {kind' : Benitoite.Release.Refinement.BuilderKind} →
        {body' : Benitoite.Release.Refinement.Comp} →
          Benitoite.Release.Refinement.Comp.builderLet kind body =
              Benitoite.Release.Refinement.Comp.builderLet kind' body' →
            (kind = kind' → body = body' → P) → P
```

## Benitoite.Release.Refinement.Comp.builderOp

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 180。

```lean
Benitoite.Release.Refinement.BuilderKind →
  Benitoite.Release.Refinement.BuilderOp →
    Benitoite.Release.LocalRef → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.builderOp.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 180。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 1 →
      ((kind : Benitoite.Release.Refinement.BuilderKind) →
          (op : Benitoite.Release.Refinement.BuilderOp) →
            (ref : Benitoite.Release.LocalRef) →
              (args : List Benitoite.Release.Refinement.Val) →
                motive_2 (Benitoite.Release.Refinement.Comp.builderOp kind op ref args)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.builderOp.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 180。

```lean
{P : Sort u} →
  {kind : Benitoite.Release.Refinement.BuilderKind} →
    {op : Benitoite.Release.Refinement.BuilderOp} →
      {ref : Benitoite.Release.LocalRef} →
        {args : List Benitoite.Release.Refinement.Val} →
          {kind' : Benitoite.Release.Refinement.BuilderKind} →
            {op' : Benitoite.Release.Refinement.BuilderOp} →
              {ref' : Benitoite.Release.LocalRef} →
                {args' : List Benitoite.Release.Refinement.Val} →
                  Benitoite.Release.Refinement.Comp.builderOp kind op ref args =
                      Benitoite.Release.Refinement.Comp.builderOp kind' op' ref' args' →
                    (kind = kind' → op = op' → ref = ref' → args = args' → P) → P
```

## Benitoite.Release.Refinement.Comp.checkAt

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 200。

```lean
Benitoite.Scope.Domain.Kind →
  Benitoite.Release.OpaqueName →
    Benitoite.Release.Refinement.ResultShape →
      Option Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Val →
          Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.RangeIx → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.checkAt.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 200。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 14 →
      ((kind : Benitoite.Scope.Domain.Kind) →
          (name : Benitoite.Release.OpaqueName) →
            (result : Benitoite.Release.Refinement.ResultShape) →
              (bases : Option Benitoite.Release.Refinement.Val) →
                (pattern input : Benitoite.Release.Refinement.Val) →
                  (index : Benitoite.Release.Refinement.RangeIx) →
                    motive_2 (Benitoite.Release.Refinement.Comp.checkAt kind name result bases pattern input index)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.checkAt.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 200。

```lean
{P : Sort u} →
  {kind : Benitoite.Scope.Domain.Kind} →
    {name : Benitoite.Release.OpaqueName} →
      {result : Benitoite.Release.Refinement.ResultShape} →
        {bases : Option Benitoite.Release.Refinement.Val} →
          {pattern input : Benitoite.Release.Refinement.Val} →
            {index : Benitoite.Release.Refinement.RangeIx} →
              {kind' : Benitoite.Scope.Domain.Kind} →
                {name' : Benitoite.Release.OpaqueName} →
                  {result' : Benitoite.Release.Refinement.ResultShape} →
                    {bases' : Option Benitoite.Release.Refinement.Val} →
                      {pattern' input' : Benitoite.Release.Refinement.Val} →
                        {index' : Benitoite.Release.Refinement.RangeIx} →
                          Benitoite.Release.Refinement.Comp.checkAt kind name result bases pattern input index =
                              Benitoite.Release.Refinement.Comp.checkAt kind' name' result' bases' pattern' input'
                                index' →
                            (kind = kind' →
                                name = name' →
                                  result = result' →
                                    bases = bases' → pattern = pattern' → input = input' → index = index' → P) →
                              P
```

## Benitoite.Release.Refinement.Comp.ctorElim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 178。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Comp) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Comp.ctorElimType ctorIdx → motive_2 t
```

## Benitoite.Release.Refinement.Comp.escape

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 189。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.escape.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 189。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 8 →
      ((v : Benitoite.Release.Refinement.Val) → motive_2 (Benitoite.Release.Refinement.Comp.escape v)) → motive_2 t
```

## Benitoite.Release.Refinement.Comp.escape.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 189。

```lean
{P : Sort u} →
  {v v' : Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Comp.escape v = Benitoite.Release.Refinement.Comp.escape v' → (v = v' → P) → P
```

## Benitoite.Release.Refinement.Comp.externalCall

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 197。

```lean
Benitoite.Release.Refinement.ExternalFunctionId →
  List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.externalCall.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 197。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 12 →
      ((id : Benitoite.Release.Refinement.ExternalFunctionId) →
          (types : List Benitoite.Release.Refinement.Ty) →
            (arguments : List Benitoite.Release.Refinement.Val) →
              motive_2 (Benitoite.Release.Refinement.Comp.externalCall id types arguments)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.externalCall.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 197。

```lean
{P : Sort u} →
  {id : Benitoite.Release.Refinement.ExternalFunctionId} →
    {types : List Benitoite.Release.Refinement.Ty} →
      {arguments : List Benitoite.Release.Refinement.Val} →
        {id' : Benitoite.Release.Refinement.ExternalFunctionId} →
          {types' : List Benitoite.Release.Refinement.Ty} →
            {arguments' : List Benitoite.Release.Refinement.Val} →
              Benitoite.Release.Refinement.Comp.externalCall id types arguments =
                  Benitoite.Release.Refinement.Comp.externalCall id' types' arguments' →
                (id = id' → types = types' → arguments = arguments' → P) → P
```

## Benitoite.Release.Refinement.Comp.handle

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 193。

```lean
Benitoite.Release.Refinement.Comp → List Benitoite.Release.Refinement.Clause → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.handle.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 193。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 10 →
      ((m : Benitoite.Release.Refinement.Comp) →
          (h : List Benitoite.Release.Refinement.Clause) → motive_2 (m.handle h)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.handle.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 193。

```lean
{P : Sort u} →
  {m : Benitoite.Release.Refinement.Comp} →
    {h : List Benitoite.Release.Refinement.Clause} →
      {m' : Benitoite.Release.Refinement.Comp} →
        {h' : List Benitoite.Release.Refinement.Clause} → m.handle h = m'.handle h' → (m = m' → h = h' → P) → P
```

## Benitoite.Release.Refinement.Comp.issuePathBases

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 199。

```lean
Benitoite.Release.PrimName → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.issuePathBases.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 199。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 13 →
      ((primitive : Benitoite.Release.PrimName) →
          motive_2 (Benitoite.Release.Refinement.Comp.issuePathBases primitive)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.issuePathBases.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 199。

```lean
{P : Sort u} →
  {primitive primitive' : Benitoite.Release.PrimName} →
    Benitoite.Release.Refinement.Comp.issuePathBases primitive =
        Benitoite.Release.Refinement.Comp.issuePathBases primitive' →
      (primitive = primitive' → P) → P
```

## Benitoite.Release.Refinement.Comp.ite

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 184。

```lean
Benitoite.Release.Refinement.Val →
  Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.ite.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 184。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 5 →
      ((v : Benitoite.Release.Refinement.Val) →
          (m n : Benitoite.Release.Refinement.Comp) → motive_2 (Benitoite.Release.Refinement.Comp.ite v m n)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.ite.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 184。

```lean
{P : Sort u} →
  {v : Benitoite.Release.Refinement.Val} →
    {m n : Benitoite.Release.Refinement.Comp} →
      {v' : Benitoite.Release.Refinement.Val} →
        {m' n' : Benitoite.Release.Refinement.Comp} →
          Benitoite.Release.Refinement.Comp.ite v m n = Benitoite.Release.Refinement.Comp.ite v' m' n' →
            (v = v' → m = m' → n = n' → P) → P
```

## Benitoite.Release.Refinement.Comp.lazyC

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 187。

```lean
Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.lazyC.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 187。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 7 → ((m : Benitoite.Release.Refinement.Comp) → motive_2 m.lazyC) → motive_2 t
```

## Benitoite.Release.Refinement.Comp.lazyC.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 187。

```lean
{P : Sort u} → {m m' : Benitoite.Release.Refinement.Comp} → m.lazyC = m'.lazyC → (m = m' → P) → P
```

## Benitoite.Release.Refinement.Comp.letIn

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 182。

```lean
Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.letIn.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 182。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 3 → ((m n : Benitoite.Release.Refinement.Comp) → motive_2 (m.letIn n)) → motive_2 t
```

## Benitoite.Release.Refinement.Comp.letIn.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 182。

```lean
{P : Sort u} → {m n m' n' : Benitoite.Release.Refinement.Comp} → m.letIn n = m'.letIn n' → (m = m' → n = n' → P) → P
```

## Benitoite.Release.Refinement.Comp.match

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 185。

```lean
Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Arm → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.match.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 185。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 6 →
      ((v : Benitoite.Release.Refinement.Val) →
          (arms : List Benitoite.Release.Refinement.Arm) → motive_2 (Benitoite.Release.Refinement.Comp.match v arms)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.match.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 185。

```lean
{P : Sort u} →
  {v : Benitoite.Release.Refinement.Val} →
    {arms : List Benitoite.Release.Refinement.Arm} →
      {v' : Benitoite.Release.Refinement.Val} →
        {arms' : List Benitoite.Release.Refinement.Arm} →
          Benitoite.Release.Refinement.Comp.match v arms = Benitoite.Release.Refinement.Comp.match v' arms' →
            (v = v' → arms = arms' → P) → P
```

## Benitoite.Release.Refinement.Comp.meth

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 202。

```lean
Benitoite.Release.Refinement.Val →
  Benitoite.Release.MethName →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Eff → List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.meth.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 202。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 15 →
      ((d : Benitoite.Release.Refinement.Val) →
          (m : Benitoite.Release.MethName) →
            (tys : List Benitoite.Release.Refinement.Ty) →
              (effs : List Benitoite.Release.Refinement.Eff) →
                (args : List Benitoite.Release.Refinement.Val) →
                  motive_2 (Benitoite.Release.Refinement.Comp.meth d m tys effs args)) →
        motive_2 t
```

## Benitoite.Release.Refinement.Comp.meth.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 202。

```lean
{P : Sort u} →
  {d : Benitoite.Release.Refinement.Val} →
    {m : Benitoite.Release.MethName} →
      {tys : List Benitoite.Release.Refinement.Ty} →
        {effs : List Benitoite.Release.Refinement.Eff} →
          {args : List Benitoite.Release.Refinement.Val} →
            {d' : Benitoite.Release.Refinement.Val} →
              {m' : Benitoite.Release.MethName} →
                {tys' : List Benitoite.Release.Refinement.Ty} →
                  {effs' : List Benitoite.Release.Refinement.Eff} →
                    {args' : List Benitoite.Release.Refinement.Val} →
                      Benitoite.Release.Refinement.Comp.meth d m tys effs args =
                          Benitoite.Release.Refinement.Comp.meth d' m' tys' effs' args' →
                        (d = d' → m = m' → tys = tys' → effs = effs' → args = args' → P) → P
```

## Benitoite.Release.Refinement.Comp.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 178。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.Comp} → t = t' → Benitoite.Release.Refinement.Comp.noConfusionType P t t'
```

## Benitoite.Release.Refinement.Comp.resume

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 195。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.resume.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 195。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 11 →
      ((k v : Benitoite.Release.Refinement.Val) → motive_2 (Benitoite.Release.Refinement.Comp.resume k v)) → motive_2 t
```

## Benitoite.Release.Refinement.Comp.resume.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 195。

```lean
{P : Sort u} →
  {k v k' v' : Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Comp.resume k v = Benitoite.Release.Refinement.Comp.resume k' v' →
      (k = k' → v = v' → P) → P
```

## Benitoite.Release.Refinement.Comp.ret

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 181。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Comp
```

## Benitoite.Release.Refinement.Comp.ret.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 181。

```lean
{motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
  (t : Benitoite.Release.Refinement.Comp) →
    t.ctorIdx = 2 →
      ((v : Benitoite.Release.Refinement.Val) → motive_2 (Benitoite.Release.Refinement.Comp.ret v)) → motive_2 t
```

