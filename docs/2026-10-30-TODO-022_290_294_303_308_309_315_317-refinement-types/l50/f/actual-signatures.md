# 群 F の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.parseAtInput_path_text :
∀ {s : String} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s)) =
      some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w)) →
    "/" ++ "/".intercalate w = s
```

```lean
Benitoite.Release.Refinement.ScopeDelta.pathValueRun_parseAtInput :
∀ {s : String} {w : Benitoite.Scope.Domain.Word},
  Benitoite.Release.Refinement.parseAtInput Benitoite.Scope.Domain.Kind.path
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s)) =
      some (Benitoite.Release.Refinement.TargetInput.absolute (Benitoite.Scope.Domain.Target.path w)) →
    Benitoite.Release.Refinement.ScopeDelta.pathValueRun
        [Benitoite.Release.Refinement.Val.checked (Benitoite.Scope.Domain.Target.path w)] =
      Benitoite.Release.Refinement.Outcome.val
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s))
```

```lean
Benitoite.Release.Refinement.ScopeDelta.path_target :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v
      (Benitoite.Release.Refinement.Ty.opaque "Scope.PathIn" (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
      ∃ w, v.target? = some (Benitoite.Scope.Domain.Target.path w)
```

```lean
Benitoite.Release.Refinement.ScopeDelta.pathValueRun :
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

```lean
Benitoite.Release.Refinement.ScopeDelta.widenRun :
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

```lean
Benitoite.Release.Refinement.ScopeDelta.valueDelta :
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

```lean
Benitoite.Release.Refinement.ScopeDelta.pathInValue_response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Scope.pathInValue"
        Benitoite.Release.Refinement.ScopeSignatures.pathInValue ts es rs ws a e →
      ∃ out,
        Benitoite.Release.Refinement.ScopeDelta.valueDelta "Scope.pathInValue" ts es rs ws = some out ∧
          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ScopeDelta.widenPathIn_response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  (∀ (r s : Benitoite.Release.Refinement.RangeExpr), B.admitsR "Scope.widenPathIn" [r, s] → s.Covers r) →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Scope.widenPathIn"
        Benitoite.Release.Refinement.ScopeSignatures.widenPathIn ts es rs ws a e →
      ∃ out,
        Benitoite.Release.Refinement.ScopeDelta.valueDelta "Scope.widenPathIn" ts es rs ws = some out ∧
          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.RequestDelta.retained_request :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v
      (Benitoite.Release.Refinement.Ty.opaque "Http.RequestIn" (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
      B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
        ∃ target req,
          (v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
              ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (some req)) ∧
            Benitoite.Release.Refinement.ModelHttp.valueRun [v] = Benitoite.Release.Refinement.Outcome.val req ∧
              Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req
                  Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy.norm ∧
                Benitoite.Release.Refinement.groundVal req = true ∧ req.reqTarget = some target
```

```lean
Benitoite.Release.Refinement.RequestDelta.valueDelta :
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

```lean
Benitoite.Release.Refinement.RequestDelta.requestInValue_response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
    B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
      Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.requestInValue"
          Benitoite.Release.Refinement.ScopeSignatures.requestInValue ts es rs ws a e →
        ∃ out,
          Benitoite.Release.Refinement.RequestDelta.valueDelta "Http.requestInValue" ts es rs ws = some out ∧
            (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.RequestDelta.widenRequestIn_response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  (∀ (r s : Benitoite.Release.Refinement.RangeExpr), B.admitsR "Http.widenRequestIn" [r, s] → s.Covers r) →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Http.widenRequestIn"
        Benitoite.Release.Refinement.ScopeSignatures.widenRequestIn ts es rs ws a e →
      ∃ out,
        Benitoite.Release.Refinement.RequestDelta.valueDelta "Http.widenRequestIn" ts es rs ws = some out ∧
          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ScopeResponse.delta :
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

```lean
Benitoite.Release.Refinement.ScopeResponse.response :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    List.lookup b Benitoite.Release.Refinement.ScopeSignatures.entries = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        B.valKind "Scope.PathIn" = some Benitoite.Scope.Domain.Kind.path →
          B.valContent "Scope.PathIn" = none →
            B.valKind "Http.RequestIn" = some Benitoite.Scope.Domain.Kind.endpoint →
              B.valContent "Http.RequestIn" = some Benitoite.Release.Refinement.ScopeSignatures.clientRequestTy →
                (∀ (r s : Benitoite.Release.Refinement.RangeExpr), B.admitsR "Scope.widenPathIn" [r, s] → s.Covers r) →
                  (∀ (r s : Benitoite.Release.Refinement.RangeExpr),
                      B.admitsR "Http.widenRequestIn" [r, s] → s.Covers r) →
                    Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
                      ∃ out,
                        Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws = some out ∧
                          (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                              Benitoite.Release.Refinement.AdequateResult ws out ∧
                                ∀ (v : Benitoite.Release.Refinement.Val),
                                  out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ScopeResponse.delta_typed :
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          ∃ out,
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta
                      io).delta
                  b ts es rs ws =
                some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P
                    (Benitoite.Release.Refinement.ScopeSignatures.builtins
                      Benitoite.Release.Refinement.ScopeResponse.delta io)
                    Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.ScopeResponse.outcome_typed :
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws = some out →
            Benitoite.Release.Refinement.Outcome.Typed P
                (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta
                  io)
                Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

```lean
Benitoite.Release.Refinement.ScopeResponse.ground :
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws = some out →
            out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
Benitoite.Release.Refinement.ScopeResponse.normal_facts :
∀ {P : Benitoite.Release.Refinement.Program}
  {io :
    Benitoite.Release.PrimName →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Eff →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io).sig b =
        some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P
            (Benitoite.Release.Refinement.ScopeSignatures.builtins Benitoite.Release.Refinement.ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          Benitoite.Release.Refinement.ScopeResponse.delta b ts es rs ws =
              some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = some t →
              ∀ (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

```lean
Benitoite.Release.Refinement.ScopeResponse.adequate_externalRef :
∀ (id : Benitoite.Release.Refinement.ExternalFunctionId) (ts : List Benitoite.Release.Refinement.Ty)
  (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.externalRef id ts))
```

```lean
Benitoite.Release.Refinement.ScopeResponse.adequate_externalHandle :
∀ (h : Benitoite.Release.Refinement.ExternalHandle) (ts : List Benitoite.Release.Refinement.Ty)
  (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.externalHandle h ts))
```

```lean
Benitoite.Release.Refinement.ScopeResponse.adequate_scopePattern :
∀ (r : Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.scopePattern r))
```

```lean
Benitoite.Release.Refinement.ScopeResponse.leaves_unobserved :
∀ (id : Benitoite.Release.Refinement.ExternalFunctionId) (h : Benitoite.Release.Refinement.ExternalHandle)
  (ts : List Benitoite.Release.Refinement.Ty) (r : Benitoite.Release.Refinement.RangeExpr),
  (Benitoite.Release.Refinement.Val.externalRef id ts).toTerm? = none ∧
    (Benitoite.Release.Refinement.Val.externalHandle h ts).toTerm? = none ∧
      (Benitoite.Release.Refinement.Val.scopePattern r).toTerm? = none ∧
        ∀ (pat : Benitoite.Release.Pat),
          Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.externalRef id ts)) =
              Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.externalHandle h ts)) ∧
            Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.externalHandle h ts)) =
              Option.map (List.map Benitoite.Release.Refinement.Val.toTerm?)
                (Benitoite.Release.Refinement.matchVal pat (Benitoite.Release.Refinement.Val.scopePattern r))
```

```lean
Benitoite.Release.Refinement.ModelConstraints.sat_rename :
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam) (ξ : Nat → Nat),
  Benitoite.Release.Refinement.ModelConstraints.sat S C (Benitoite.Release.Refinement.renameTy ξ a) p ↔
    Benitoite.Release.Refinement.ModelConstraints.sat S C a p
```

```lean
Benitoite.Release.Refinement.ModelConstraints.sat_values :
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam) (ν : Nat → Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.ModelConstraints.sat S C (Benitoite.Release.Refinement.substTyValues ν a) p ↔
    Benitoite.Release.Refinement.ModelConstraints.sat S C a p
```

```lean
Benitoite.Release.Refinement.ModelConstraints.admits_rename :
∀ (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
  (as : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
  Benitoite.Release.Refinement.ModelConstraints.admits S ps C as →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C (List.map (Benitoite.Release.Refinement.renameTy ξ) as)
```

```lean
Benitoite.Release.Refinement.ModelConstraints.admits_values :
∀ (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
  (as : List Benitoite.Release.Refinement.Ty) (ν : Nat → Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.ModelConstraints.admits S ps C as →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C
      (List.map (Benitoite.Release.Refinement.substTyValues ν) as)
```

```lean
Benitoite.Release.Refinement.ModelConstraints.sat_renameTypes :
∀ {S : Benitoite.Release.SummaryTable} {C D : Benitoite.Release.Refinement.TypeCtx} {ρ : Nat → Nat}
  {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.TParam},
  Benitoite.Release.Refinement.TypeParamRenaming C D ρ →
    Benitoite.Release.Refinement.ModelConstraints.sat S C.constraints a p →
      Benitoite.Release.Refinement.ModelConstraints.sat S D.constraints (a.renameTypes ρ) p
```

```lean
Benitoite.Release.Refinement.ModelConstraints.admits_renameTypes :
∀ {S : Benitoite.Release.SummaryTable} {ps : List Benitoite.Release.TParam} {C D : Benitoite.Release.Refinement.TypeCtx}
  {ρ : Nat → Nat} {as : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.TypeParamRenaming C D ρ →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C.constraints as →
      Benitoite.Release.Refinement.ModelConstraints.admits S ps D.constraints (List.map (fun a => a.renameTypes ρ) as)
```

```lean
Benitoite.Release.Refinement.ModelConstraints.sat_subst :
∀ {S : Benitoite.Release.SummaryTable} {C0 C1 : Benitoite.Release.Refinement.TypeCtx}
  {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.TParam} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ModelConstraints.sat S (C1 ++ C0).constraints a p →
    (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
      (ts.length = C0.constraints.length ∧
          ∀ (i : Nat) (t : Benitoite.Release.Refinement.Ty) (q : Benitoite.Release.TParam),
            ts[i]? = some t →
              C0.constraints[i]? = some q →
                Benitoite.Release.Refinement.ModelConstraints.sat S C1.constraints t.norm q) →
        ts.length = List.length C0 →
          Benitoite.Release.Refinement.ModelConstraints.sat S C1.constraints
            (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p
```

```lean
Benitoite.Release.Refinement.ModelConstraints.admits_subst :
∀ {S : Benitoite.Release.SummaryTable} {ps : List Benitoite.Release.TParam}
  {C0 C1 : Benitoite.Release.Refinement.TypeCtx} {as ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ModelConstraints.admits S ps (C1 ++ C0).constraints as →
    (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
      (ts.length = C0.constraints.length ∧
          ∀ (i : Nat) (t : Benitoite.Release.Refinement.Ty) (q : Benitoite.Release.TParam),
            ts[i]? = some t →
              C0.constraints[i]? = some q →
                Benitoite.Release.Refinement.ModelConstraints.sat S C1.constraints t.norm q) →
        ts.length = List.length C0 →
          Benitoite.Release.Refinement.ModelConstraints.admits S ps C1.constraints
            (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es) as)
```

```lean
Benitoite.Release.Refinement.ModelConstraints.sat_unconstrained :
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.ModelConstraints.sat S C a { }
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.substitutionAssumptions :
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

```lean
Benitoite.Release.Refinement.ScopeSignatures.admits_sat :
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
  (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io).sig b = some sg →
    sg.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll (Benitoite.Release.Refinement.ScopeSignatures.builtins delta io) C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints sg.tparams)
```

```lean
Benitoite.Release.Refinement.ScopeSignatures.sat_unconstrained :
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

```lean
Benitoite.Release.Refinement.Eff.allows_bind_comp :
∀ (θ φ : Benitoite.Release.Refinement.SubstEnv) (e : Benitoite.Release.Refinement.Eff)
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ
      (Benitoite.Release.Refinement.Eff.bind φ (Benitoite.Release.Refinement.Eff.bind θ e)) l t ↔
    (∃ k ix r,
        κ l = some k ∧
          e.mem (Benitoite.Release.Refinement.Atom.name l ix) ∧
            Benitoite.Release.Refinement.RangeIx.inst φ.ranges (Benitoite.Release.Refinement.RangeIx.inst θ.ranges ix) =
                Benitoite.Release.Refinement.RangeIx.fixed r ∧
              Benitoite.Release.Refinement.RangeExpr.Mem σ k r t) ∨
      (∃ i f,
          θ.rows[i]? = some f ∧
            e.mem (Benitoite.Release.Refinement.Atom.rho i) ∧
              Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind φ f) l t) ∨
        ∃ i f,
          θ.rows.length ≤ i ∧
            e.mem (Benitoite.Release.Refinement.Atom.rho i) ∧
              φ.rows[i]? = some f ∧ Benitoite.Release.Refinement.Eff.Allows σ κ f l t
```

