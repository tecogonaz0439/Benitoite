# 群 E の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.ScopeDeclarations.program :
Benitoite.Release.Refinement.Program
```

```lean
Benitoite.Release.Refinement.ScopeDeclarations.program_arity :
∀ {d : Benitoite.Release.Refinement.StandardKeyTyping.DataDecl},
  d ∈ Benitoite.Release.Refinement.ScopeDeclarations.http →
    Benitoite.Release.Refinement.ScopeDeclarations.program.DataArity d.name d.ntys
```

```lean
Benitoite.Release.Refinement.ScopeDeclarations.program_hasHttp :
Benitoite.Release.Refinement.ScopeDeclarations.HasHttp Benitoite.Release.Refinement.ScopeDeclarations.program
```

```lean
Benitoite.Release.Refinement.ScopeDeclarations.program_wellFormed :
Benitoite.Release.Refinement.ScopeDeclarations.program.WellFormed
```

```lean
Benitoite.Release.Refinement.TargetTable.valKind :
Benitoite.Release.OpaqueName → Option Benitoite.Scope.Domain.Kind
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.entries :
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.builtins :
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

```lean
Benitoite.Release.Refinement.ScopeSignatures.entries_scoped :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀ (row : Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig),
      row ∈ Benitoite.Release.Refinement.ScopeSignatures.entries → Benitoite.Release.Refinement.PrimSig.Scoped P row.snd
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.sig_scoped :
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
      (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg →
        Benitoite.Release.Refinement.PrimSig.Scoped P sg
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.sourceTelRows :
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
      (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg →
        Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < sg.neffs) sg.tel
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.io_op :
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
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).ShapeOk b sg
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.pathBases_shape :
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
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      sg.PathBasesShape (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io) b
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.pathBases_no_io :
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
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      ∀ (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
        (ws : List Benitoite.Release.Refinement.Val) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        ¬(Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).ioResponse b ts es ws out obs
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.effect_ops :
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
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).effects l = some bs →
    b ∈ bs →
      ∃ sg,
        (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg ∧
          (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            sg.opEff = some l
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.unscopedIO_shape :
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName} {l : Benitoite.Release.EffName}
  {names : List String} {params : List Benitoite.Release.Refinement.Ty} {ret : Benitoite.Release.Refinement.Ty}
  {shape : Benitoite.Scope.Signature.IOShape} {kind : Benitoite.Release.Refinement.PrimKind}
  {bs : List Benitoite.Release.PrimName},
  B.effects l = some bs →
    b ∈ bs →
      (shape = Benitoite.Scope.Signature.IOShape.untargeted ∧ B.effKind l = none ∨
          ∃ k, shape = Benitoite.Scope.Signature.IOShape.topTargeted k ∧ B.effKind l = some k) →
        B.ShapeOk b (Benitoite.Release.Refinement.ScopeSignatures.unscopedIO names params ret l shape kind)
```

```lean
Benitoite.Release.Refinement.ScopeDelta.run_safe :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valContent "Scope.PathIn" = none →
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

```lean
Benitoite.Release.Refinement.ScopeDelta.response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valContent "Scope.PathIn" = none →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Scope.checkPathIn"
            Benitoite.Release.Refinement.ScopeSignatures.checkPathIn ts es rs ws a e →
          ∃ out,
            Benitoite.Release.Refinement.ScopeDelta.delta "Scope.checkPathIn" ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ScopeDelta.run_absolute :
∀ {pattern target : String} {p : Benitoite.Scope.Domain.PathPattern} {t : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.ScopeDelta.parsePattern pattern = some p →
    Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
        some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path t)) →
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

```lean
Benitoite.Release.Refinement.ScopeDelta.input_errors :
∀ {pattern target : String} {p : Benitoite.Scope.Domain.PathPattern},
  Benitoite.Release.Refinement.ScopeDelta.parsePattern pattern = some p →
    ∀ (r : Benitoite.Release.Refinement.RangeExpr),
      (∀ (w : Benitoite.Scope.Domain.Word),
          Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
                some (Benitoite.Release.Refinement.TargetInput.relativePath w) ∨
              Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
                  (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
                some (Benitoite.Release.Refinement.TargetInput.homePath w) →
            Benitoite.Release.Refinement.ScopeDelta.run r
                [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern),
                  Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)] =
              Benitoite.Release.Refinement.ScopeDelta.error r
                (Benitoite.Release.Refinement.ScopeDelta.invalidTarget target
                  Benitoite.Release.Refinement.ScopeDelta.text.PATH)) ∧
        (Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
              (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)) =
            none →
          Benitoite.Release.Refinement.ScopeDelta.run r
              [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string pattern),
                Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string target)] =
            Benitoite.Release.Refinement.ScopeDelta.error r
              (Benitoite.Release.Refinement.ScopeDelta.invalidTarget target
                Benitoite.Release.Refinement.ScopeDelta.text.PATH))
```

```lean
Benitoite.Release.Refinement.ScopeDelta.error_safe :
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

```lean
Benitoite.Release.Refinement.RequestDelta.run_safe :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
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

```lean
Benitoite.Release.Refinement.RequestDelta.response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.checkRequestIn"
            Benitoite.Release.Refinement.ScopeSignatures.checkRequestIn ts es rs ws a e →
          ∃ out,
            Benitoite.Release.Refinement.RequestDelta.delta "Http.checkRequestIn" ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.RequestDelta.run_endpoint :
∀ {req : Benitoite.Release.Refinement.Val} {pattern : String} {endpoint : Benitoite.Scope.Domain.Endpoint}
  {p : Benitoite.Scope.Domain.HostPattern},
  Benitoite.Release.Refinement.groundVal req = true →
    (Benitoite.Release.Refinement.parseUrlShape (Benitoite.Release.Refinement.RequestDelta.urlText✝ req)).isSome =
        true →
      req.reqTarget = some (Benitoite.Scope.Domain.Target.endpoint endpoint) →
        Benitoite.Release.Refinement.RequestDelta.parseHostPattern pattern = some p →
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

```lean
Benitoite.Release.Refinement.RequestDelta.parseHostPattern :
String → Option Benitoite.Scope.Domain.HostPattern
```

