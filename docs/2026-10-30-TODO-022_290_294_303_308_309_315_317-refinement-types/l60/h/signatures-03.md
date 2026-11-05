# 段末の実署名（3/3）

生成物（[audit.py](audit.py)）。段の公理監査（[../axioms.lean](../axioms.lean)）の型の印字であり、接頭辞 `Benitoite.Release.Refinement.` を見出しでだけ省く。

### `ContTy.release_response_exists`（C13）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {k : List Benitoite.Release.Refinement.Frame} {a b : Benitoite.Release.Refinement.Ty}
  {Eb : Benitoite.Release.Refinement.Eff} {Re : Option Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    Benitoite.Release.Refinement.ContTy P B σ Ψ R e (Benitoite.Release.Refinement.Frame.release v :: k) a b Eb Re →
      ∃ r, B.releaseResponse v r
```

### `ContTy.selected_release`（C13）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {k : List Benitoite.Release.Refinement.Frame} {a b : Benitoite.Release.Refinement.Ty}
  {Eb : Benitoite.Release.Refinement.Eff} {Re : Option Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    Benitoite.Release.Refinement.ContTy P B σ Ψ R e (Benitoite.Release.Refinement.Frame.release v :: k) a b Eb Re →
      B.releaseResponse v (B.selectRelease v)
```

### `step_release_selected`（C13）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {oracle : Benitoite.Release.Refinement.Oracle}
  {externalOracle : Benitoite.Release.Refinement.ExternalOracle} {fresh : Benitoite.Release.Refinement.Store → Nat}
  {q : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {w v : Benitoite.Release.Refinement.Val} {escape : Bool},
  (q.view =
      if escape = Bool.true then Benitoite.Release.Refinement.Comp.escape w
      else Benitoite.Release.Refinement.Comp.ret w) →
    (∃ result, B.releaseResponse v result) →
      have dest :=
        match B.selectRelease v with
        | Option.none =>
          Benitoite.Release.Refinement.State.run
            (Benitoite.Release.Refinement.Closure.pure
              (if escape = Bool.true then Benitoite.Release.Refinement.Comp.escape w
              else Benitoite.Release.Refinement.Comp.ret w))
            k μ
        | Option.some r => Benitoite.Release.Refinement.State.error [r] k μ;
      Benitoite.Release.Refinement.step P B σ oracle externalOracle B.selectRelease fresh
            (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ) =
          Option.some (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v)), dest) ∧
        Benitoite.Release.Refinement.Step P B σ
          (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
          (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v))) dest
```

### `ScopeResponse.response`（C14）

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

### `ScopedIOResponse.response`（C14）

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

### `Model.scopeConditions`（C15）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins
```

### `ModelTargets.scopeConditions`（C15）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins
```

### `ModelHttp.scopeConditions`（C15）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelHttp.builtins
```

### `ScopeModels.conditions`（C15）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins ∧
      Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelTargets.builtins ∧
        Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelHttp.builtins
```

### `ModelScopeConditions.core`（C16）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
      (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
          (o : Benitoite.Release.OpaqueName),
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
              (Benitoite.Release.Refinement.Ty.opaque o
                (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
            B.isResource o = Bool.true → ∃ r, B.releaseResponse v r) →
        Benitoite.Release.Refinement.Builtins.CoreAssumptions P B
```

### `Builtins.CoreAssumptions`（C16）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

### `Builtins.TargetAgreement`（C16）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

### `StandardOperatorResponse.response`（C17）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (entry : Benitoite.Release.Refinement.StandardOperatorResponse.Entry),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ entry.name entry.signature ts es rs ws a e →
    ∃ out,
      entry.delta entry.name ts es rs ws = Option.some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

### `StandardStructuralEqualityResponse.response`（C17）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (equal : Bool),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ (if equal = Bool.true then "%eq" else "%ne")
      (Benitoite.Release.Refinement.StandardEqualityResponse.fullSignature B.sat) ts es rs ws a e →
    ∃ T,
      ts = [T] ∧
        Benitoite.Release.Refinement.Ty.Annotation P [] [] T ∧
          Benitoite.Release.Refinement.Ordinary T ∧
            B.sat [] T.norm { equality := Bool.true } ∧
              ∃ out,
                Benitoite.Release.Refinement.StandardStructuralEqualityResponse.delta
                      (if equal = Bool.true then "%eq" else "%ne") ts es rs ws =
                    Option.some out ∧
                  Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                    Benitoite.Release.Refinement.AdequateResult ws out ∧
                      ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

### `StandardCollectionRefinedBodies.program_typed`（C17）

```lean
Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program.WellTyped
  Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins
```

### `TargetTable.content_rows`（C18）

```lean
∀ {name : Benitoite.Release.OpaqueName} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.TargetTable.valContent name = Option.some a →
    Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) a
```

### `AtPrepared.request`（C18）

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

### `Val.reqTarget_kind`（C18）

```lean
∀ {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Scope.Domain.Target},
  v.reqTarget = Option.some t → t.kind = Benitoite.Scope.Domain.Kind.endpoint
```

### `checkAt.absolute`（C18）

```lean
∀ {snapshot : Option Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Scope.Domain.Kind}
  {pat : Benitoite.Release.Refinement.RangeExpr} {t0 : Benitoite.Scope.Domain.Target}
  {bound : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.checkAt snapshot kind pat (Benitoite.Release.Refinement.TargetInput.absolute t0) bound =
      Benitoite.Release.Refinement.AtResult.ok t →
    t = t0
```

