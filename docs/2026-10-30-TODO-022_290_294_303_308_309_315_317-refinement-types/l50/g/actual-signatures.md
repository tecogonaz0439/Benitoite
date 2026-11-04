# 群 G の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.ScopedIOResponse.Operation.lookup :
∀ (op : Benitoite.Release.Refinement.ScopedIOResponse.Operation),
  List.lookup op.name Benitoite.Release.Refinement.ScopeSignatures.entries = some op.signature
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.ioResponse :
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.RequestSent :
Benitoite.Release.Refinement.ScopedIOResponse.Operation →
  List Benitoite.Release.Refinement.Val → Benitoite.Scope.Domain.Target → Prop
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.readTextIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.readBytesIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.writeTextIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.writeBytesIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.appendTextIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.appendBytesIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.sendIn :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        B.valKind "Http.Response" = none ∧ B.valContent "Http.Response" = none →
          B.valKind "NetworkError" = none ∧ B.valContent "NetworkError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.sent_request :
∀ {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopedIOResponse.ioResponse "Http.sendIn" ts es ws out obs →
    ∃ w req t,
      ws = [w] ∧
        Benitoite.Release.Refinement.ModelHttp.valueRun [w] = Benitoite.Release.Refinement.Outcome.val req ∧
          Benitoite.Release.Refinement.groundVal req = true ∧ req.reqTarget = some t ∧ w.target? = some t ∧ obs = [t]
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    List.lookup b Benitoite.Release.Refinement.ScopeSignatures.entries = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
          B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
            B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
              B.valKind "IOError" = none ∧ B.valContent "IOError" = none →
                B.valKind "Http.Response" = none ∧ B.valContent "Http.Response" = none →
                  B.valKind "NetworkError" = none ∧ B.valContent "NetworkError" = none →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.targets :
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  List.lookup b Benitoite.Release.Refinement.ScopeSignatures.entries = some sg →
    Benitoite.Release.Refinement.ScopedIOResponse.ioResponse b ts es ws out obs →
      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.targetAgreement :
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.target_member :
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
        some sg →
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
                      ws[0]?.bind Benitoite.Release.Refinement.Val.target? = some t ∧
                        Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                          sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k 0 ∧
                            sg.opEff = some l ∧
                              Benitoite.Release.Refinement.Eff.Allows σ
                                (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                                    Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).effKind
                                e l t
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.obs_allowed :
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
        some sg →
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
                sg.opEff = some l ∧
                  ∀ (t : Benitoite.Scope.Domain.Target),
                    t ∈ obs →
                      Benitoite.Release.Refinement.Eff.Allows σ
                        (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
                            Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).effKind
                        e l t
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.io_typed :
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
        some sg →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.io_kind :
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
      some sg →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins delta
            Benitoite.Release.Refinement.ScopedIOResponse.ioResponse).ioResponse
        b ts es ws out obs →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
        ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

```lean
Benitoite.Release.Refinement.ScopedIOResponse.io_exists :
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
        some sg →
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

```lean
Benitoite.Release.Refinement.ScopedIOResponse.responseAssumptions :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P
      (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta
        Benitoite.Release.Refinement.ScopedIOResponse.ioResponse)
```

