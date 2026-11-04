# 群 K の実署名

全入力を量化する本番の実型である。

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.one :
Benitoite.Release.EffName → Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Eff
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.single_io :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv} {u : Benitoite.Release.Refinement.Tel},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
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
                        ∃ a₀ e₀ r t,
                          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                              (Benitoite.Release.Refinement.Ty.normTys ts)
                              (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a₀ e₀ ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]?.bind Benitoite.Release.Refinement.Val.target? = some t ∧
                                    Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                                      sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k p ∧
                                        (∃ out obs,
                                            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                              (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs) ∧
                                          ∀ (out : Benitoite.Release.Refinement.Outcome)
                                            (obs : List Benitoite.Scope.Domain.Target),
                                            B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                                (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs →
                                              obs = [t] ∧
                                                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a₀ ∧
                                                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                                                    ∃ l,
                                                      sg.opEff = some l ∧
                                                        ∀ (target : Benitoite.Scope.Domain.Target),
                                                          target ∈ obs →
                                                            Benitoite.Release.Refinement.Eff.Allows σ B.effKind e l
                                                              target
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.request_io :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {u : Benitoite.Release.Refinement.Tel} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = some sg →
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
                                some
                                  (Benitoite.Release.Refinement.Ty.opaque o
                                    (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                              B.valContent o = some A) →
                          ∃ a₀ e₀ r w target req,
                            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                                (Benitoite.Release.Refinement.Ty.normTys ts)
                                (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a₀ e₀ ∧
                              Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                                Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                  rs = [r] ∧
                                    ws[p]? = some w ∧
                                      (w = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                                          ∃ s snapshot,
                                            w =
                                              Benitoite.Release.Refinement.Val.checkedAt s snapshot target (some req)) ∧
                                        Benitoite.Release.Refinement.ModelHttp.valueRun [w] =
                                            Benitoite.Release.Refinement.Outcome.val req ∧
                                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                                            Benitoite.Release.Refinement.groundVal req = true ∧
                                              req.reqTarget = some target ∧
                                                Benitoite.Release.Refinement.RangeExpr.Mem σ
                                                    Benitoite.Scope.Domain.Kind.endpoint r target ∧
                                                  ⋯ ∧
                                                    ∀ (out : Benitoite.Release.Refinement.Outcome)
                                                      (obs : List Benitoite.Scope.Domain.Target),
                                                      B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                                          (List.map Benitoite.Release.Refinement.Eff.norm es) ws out
                                                          obs →
                                                        obs = [target] ∧
                                                          Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a₀ ∧
                                                            Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.selected_io :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
              ws[p]? = some v →
                ∃ r t,
                  rs = [r] ∧
                    v.target? = some t ∧
                      Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                        (∃ out obs, B.ioResponse b ts es ws out obs) ∧
                          ∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
                            B.ioResponse b ts es ws out obs → obs = [t]
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.selected_request :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {v : Benitoite.Release.Refinement.Val} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        sg.shape = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
              ws[p]? = some v →
                (∀ (o : Benitoite.Release.OpaqueName),
                    sg.params[p]? =
                        some (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                      B.valContent o = some A) →
                  ∃ r target req,
                    rs = [r] ∧
                      (v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                          ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (some req)) ∧
                        Benitoite.Release.Refinement.ModelHttp.valueRun [v] =
                            Benitoite.Release.Refinement.Outcome.val req ∧
                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                            Benitoite.Release.Refinement.groundVal req = true ∧
                              req.reqTarget = some target ∧
                                Benitoite.Release.Refinement.RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.endpoint r
                                    target ∧
                                  (∃ out obs, B.ioResponse b ts es ws out obs) ∧
                                    ∀ (out : Benitoite.Release.Refinement.Outcome)
                                      (obs : List Benitoite.Scope.Domain.Target),
                                      B.ioResponse b ts es ws out obs → obs = [target]
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.widened_input :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v
        (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) →
      s.Covers r →
        B.valKind o = some k →
          Benitoite.Release.Refinement.Val.Adequate σ v →
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
                (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed s)) ∧
              ∃ t,
                v.target? = some t ∧
                  Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                    Benitoite.Release.Refinement.RangeExpr.Mem σ k s t
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.incomparable :
∀ {P : Benitoite.Release.Refinement.Program} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr},
  ¬s.Covers r →
    ¬Benitoite.Release.Refinement.Ty.LeQ P Γ Φ
        (Benitoite.Release.Refinement.Ty.scoped o k (Benitoite.Release.Refinement.RangeIx.fixed r))
        (Benitoite.Release.Refinement.Ty.scoped o k (Benitoite.Release.Refinement.RangeIx.fixed s))
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base :
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

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.no_collective_cover :
∀ {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {e f : Benitoite.Release.Refinement.Eff} {a : Benitoite.Release.Refinement.Atom},
  f.mem a →
    (∀ (b : Benitoite.Release.Refinement.Atom), e.mem b → ¬b.Covers a) →
      ¬Benitoite.Release.Refinement.Eff.Covers Γ Φ e f
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.split_endpoint :
∀ (σ : Benitoite.Release.Refinement.PathEnv) (l : Benitoite.Release.EffName) (host : Benitoite.Scope.Domain.HostPattern)
  (Γ : Benitoite.Release.Refinement.Ctx) (Φ : List Benitoite.Release.Refinement.Pred),
  have whole := Benitoite.Scope.Domain.Range.endpoint { host := host, ports := { lo := 0, hi := 9 } };
  have left := Benitoite.Scope.Domain.Range.endpoint { host := host, ports := { lo := 0, hi := 4 } };
  have right := Benitoite.Scope.Domain.Range.endpoint { host := host, ports := { lo := 5, hi := 9 } };
  (∀ (k : Benitoite.Scope.Domain.Kind) (t : Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.absolute whole) t →
        Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.absolute left) t ∨
          Benitoite.Release.Refinement.RangeExpr.Mem σ k (Benitoite.Release.Refinement.RangeExpr.absolute right) t) ∧
    ¬Benitoite.Release.Refinement.Eff.Covers Γ Φ
        ((Benitoite.Release.Refinement.ScopedTargetExamples.one l
              (Benitoite.Release.Refinement.RangeExpr.absolute left)).union
          (Benitoite.Release.Refinement.ScopedTargetExamples.one l
            (Benitoite.Release.Refinement.RangeExpr.absolute right)))
        (Benitoite.Release.Refinement.ScopedTargetExamples.one l
          (Benitoite.Release.Refinement.RangeExpr.absolute whole))
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members :
∀ (σ : Benitoite.Release.Refinement.PathEnv) (ps : List Benitoite.Scope.Domain.PathPattern)
  (k : Benitoite.Scope.Domain.Kind) (t : Benitoite.Scope.Domain.Target),
  Benitoite.Release.Refinement.RangeExpr.resolve
        { root := σ.root, cwd := σ.cwd, home := σ.home, work := σ.work, tmp := σ.tmp, secrets := none }
        Benitoite.Release.Refinement.RangeExpr.secrets =
      none ∧
    Benitoite.Release.Refinement.RangeExpr.resolve
          { root := σ.root, cwd := σ.cwd, home := σ.home, work := σ.work, tmp := σ.tmp, secrets := some [] }
          Benitoite.Release.Refinement.RangeExpr.secrets =
        some [] ∧
      (Benitoite.Release.Refinement.RangeExpr.Mem
          { root := σ.root, cwd := σ.cwd, home := σ.home, work := σ.work, tmp := σ.tmp, secrets := some ps } k
          Benitoite.Release.Refinement.RangeExpr.secrets t ↔
        t.kind = k ∧ ∃ p, p ∈ ps ∧ (Benitoite.Scope.Domain.Range.path p).Mem t)
```

```lean
Benitoite.Release.Refinement.ScopedTargetExamples.absolute_projection :
∀ (r s : Benitoite.Release.Refinement.RangeExpr) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (w : Benitoite.Scope.Domain.Word),
  Benitoite.Release.Refinement.ScopeDelta.widenRun
        [Benitoite.Release.Refinement.Val.checkedAt r snapshot (Benitoite.Scope.Domain.Target.path w) none] =
      Benitoite.Release.Refinement.Outcome.val
        (Benitoite.Release.Refinement.Val.checkedAt r snapshot (Benitoite.Scope.Domain.Target.path w) none) ∧
    Benitoite.Release.Refinement.ModelTargets.builtins.delta "Scope.pathInValue" [] [] [s]
        [Benitoite.Release.Refinement.Val.checkedAt r snapshot (Benitoite.Scope.Domain.Target.path w) none] =
      some
        (Benitoite.Release.Refinement.Outcome.val
          (Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.Const.string ("/" ++ "/".intercalate w))))
```

```lean
Benitoite.Release.Refinement.AtErrorReaders.observed :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    ∀ (d : Benitoite.Release.Refinement.AtError),
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.atError d)
          Benitoite.Release.Refinement.atErrorType ∧
        (∀ (t : Benitoite.Release.Refinement.Term),
            (Benitoite.Release.Refinement.Val.atError d).toTerm? = some t →
              Benitoite.Release.Refinement.Term.Declared P C Γ t) ∧
          Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                (Benitoite.Release.Refinement.Val.atError d) =
              some (Benitoite.Release.Refinement.Detail.values d) ∧
            Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Detail.values d)
                Benitoite.Release.Refinement.atErrorFields ∧
              ∀ (ws : List Benitoite.Release.Refinement.Val),
                Benitoite.Release.Refinement.AdequateResult ws
                  (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError d))
```

```lean
Benitoite.Release.Refinement.AtErrorReaders.prepare_reader :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {shape : Benitoite.Release.Refinement.ResultShape}
  {cap : Benitoite.Release.Refinement.Capture} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {d : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    Benitoite.Release.Refinement.AtPrepare B cap kind name bases pattern input index = Except.error d →
      d.originalPattern = Benitoite.Release.Refinement.closeVal cap pattern ∧
        d.originalTarget = Benitoite.Release.Refinement.closeVal cap input ∧
          (∃ snapshot pp pt,
              d =
                  Benitoite.Release.Refinement.AtError.save (Benitoite.Release.Refinement.closeVal cap pattern)
                    (Benitoite.Release.Refinement.closeVal cap input) snapshot pp pt d.failure ∧
                d.parsedPattern = pp ∧
                  d.parsedTarget = pt ∧
                    d.resolvedPatterns = pp.bind (Benitoite.Release.Refinement.resolveSnapshot snapshot) ∧
                      d.resolvedTarget = pt.bind (Benitoite.Release.Refinement.resolveTargetSnapshot snapshot) ∧
                        d.patternBase = pp.bind Benitoite.Release.Refinement.RangeExpr.base? ∧
                          d.targetBase = pt.bind Benitoite.Release.Refinement.TargetInput.base?) ∧
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.atError d)
                Benitoite.Release.Refinement.atErrorType ∧
              (∀ (t : Benitoite.Release.Refinement.Term),
                  (Benitoite.Release.Refinement.Val.atError d).toTerm? = some t →
                    Benitoite.Release.Refinement.Term.Declared P C Γ t) ∧
                Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                      (Benitoite.Release.Refinement.Val.atError d) =
                    some (Benitoite.Release.Refinement.Detail.values d) ∧
                  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Detail.values d)
                      Benitoite.Release.Refinement.atErrorFields ∧
                    ∀ (ws : List Benitoite.Release.Refinement.Val),
                      Benitoite.Release.Refinement.AdequateResult ws
                        (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError d))
```

```lean
Benitoite.Release.Refinement.AtErrorReaders.check_reader :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.Declared P shape →
    ∀ (p t : Benitoite.Release.Refinement.Val) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
      (pat : Benitoite.Release.Refinement.RangeExpr) (target : Benitoite.Release.Refinement.TargetInput)
      (d : Benitoite.Release.Refinement.AtCheckError),
      have saved := Benitoite.Release.Refinement.AtError.fromCheck p t snapshot pat target d;
      saved.originalPattern = p ∧
        saved.originalTarget = t ∧
          saved.failure = d.failure ∧
            saved.parsedPattern = some pat ∧
              saved.parsedTarget = some target ∧
                saved.resolvedPatterns = Benitoite.Release.Refinement.resolveSnapshot snapshot pat ∧
                  saved.resolvedTarget = Benitoite.Release.Refinement.resolveTargetSnapshot snapshot target ∧
                    saved.patternBase = pat.base? ∧
                      saved.targetBase = target.base? ∧
                        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ
                            (Benitoite.Release.Refinement.Val.atError saved) Benitoite.Release.Refinement.atErrorType ∧
                          (∀ (term : Benitoite.Release.Refinement.Term),
                              (Benitoite.Release.Refinement.Val.atError saved).toTerm? = some term →
                                Benitoite.Release.Refinement.Term.Declared P C Γ term) ∧
                            Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                                  (Benitoite.Release.Refinement.Val.atError saved) =
                                some (Benitoite.Release.Refinement.Detail.values saved) ∧
                              Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ
                                  (Benitoite.Release.Refinement.Detail.values saved)
                                  Benitoite.Release.Refinement.atErrorFields ∧
                                ∀ (ws : List Benitoite.Release.Refinement.Val),
                                  Benitoite.Release.Refinement.AdequateResult ws
                                    (Benitoite.Release.Refinement.Outcome.val
                                      (Benitoite.Release.Refinement.Val.atError saved))
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
            Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
              ∃ Ψ R a e sg r ef,
                Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                  Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                    B.sig b = some sg ∧
                      Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
                          (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws r ef ∧
                        Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                          Benitoite.Release.Refinement.Eff.Covers [] [] e ef ∧
                            ∀ (w : Benitoite.Release.Refinement.Val),
                              w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.destination :
Benitoite.Release.Refinement.Outcome →
  Benitoite.Release.Refinement.Cont → Benitoite.Release.Refinement.Store → Benitoite.Release.Refinement.State
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.pure_steps :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {sg : Benitoite.Release.Refinement.PrimSig},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = some sg →
                sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
                  ∃ Ψ a e out,
                    Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
                        (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e ∧
                      B.delta b (Benitoite.Release.Refinement.Ty.normTys ts)
                            (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws =
                          some out ∧
                        (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                          Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                            Benitoite.Release.Refinement.AdequateResult ws out ∧
                              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                                  none (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ) ∧
                                Benitoite.Release.Refinement.StateTyE P B σ Eb
                                  (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ)
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.io_steps :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {sg : Benitoite.Release.Refinement.PrimSig},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.Builtins.TargetAgreement P B →
          σ.Valid →
            Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
              q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
                B.sig b = some sg →
                  sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                      sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
                    Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                      ∃ Ψ a e,
                        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
                            (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e ∧
                          (∃ out obs,
                              B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs) ∧
                            ∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
                              B.ioResponse b (Benitoite.Release.Refinement.Ty.normTys ts)
                                  (List.map Benitoite.Release.Refinement.Eff.norm es) ws out obs →
                                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                                    Benitoite.Release.Refinement.Step P B σ
                                        (Benitoite.Release.Refinement.State.run q k μ)
                                        (some (Benitoite.Release.Refinement.Event.io b ws out obs))
                                        (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ) ∧
                                      Benitoite.Release.Refinement.StateTyE P B σ Eb
                                          (Benitoite.Release.Refinement.ScopedTargetInputs.destination out k μ) ∧
                                        ∃ l,
                                          sg.opEff = some l ∧
                                            ∀ (t : Benitoite.Scope.Domain.Target),
                                              t ∈ obs → Benitoite.Release.Refinement.Eff.Allows σ B.effKind e l t
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.handled_step :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {k1 : Benitoite.Release.Refinement.Cont}
  {cs : List Benitoite.Release.Refinement.Clause} {k2 : Benitoite.Release.Refinement.Cont}
  {c : Benitoite.Release.Refinement.Clause} {l : Nat} {hcap : Benitoite.Release.Refinement.Capture},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        P.EffectsOk B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
              B.sig b = some sg →
                sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                      sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
                  Benitoite.Release.Refinement.SplitAt (Benitoite.Release.OpRef.prim b) k k1 hcap cs k2 →
                    Benitoite.Release.Refinement.findClause cs (Benitoite.Release.OpRef.prim b) = some c →
                      μ l = none →
                        (∃ Ψ a e,
                            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg
                                (Benitoite.Release.Refinement.Ty.normTys ts)
                                (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e ∧
                              ∀ (w : Benitoite.Release.Refinement.Val),
                                w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) ∧
                          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                              (Benitoite.Release.Refinement.State.run
                                (Benitoite.Release.Refinement.Closure.mk
                                  (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc l]))
                                  (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
                                (Benitoite.Release.Refinement.Frame.drop l :: k2)
                                (μ.set l
                                  (Benitoite.Release.Refinement.Cell.cont
                                    (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap cs])))) ∧
                            Benitoite.Release.Refinement.StateTyE P B σ Eb
                              (Benitoite.Release.Refinement.State.run
                                (Benitoite.Release.Refinement.Closure.mk
                                  (hcap.extendMany (ws ++ [Benitoite.Release.Refinement.Val.loc l]))
                                  (Benitoite.Release.Refinement.Comp.substTy ts [] c.body))
                                (Benitoite.Release.Refinement.Frame.drop l :: k2)
                                (μ.set l
                                  (Benitoite.Release.Refinement.Cell.cont
                                    (k1 ++ [Benitoite.Release.Refinement.Frame.handleF hcap cs]))))
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.at_prepare :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {d : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepare B q.capture kind name bases pattern input index = Except.error d →
        d.originalPattern = Benitoite.Release.Refinement.closeVal q.capture pattern ∧
          d.originalTarget = Benitoite.Release.Refinement.closeVal q.capture input ∧
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.con shape.error
                        [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                        [Benitoite.Release.Refinement.Val.atError d])))
                  k μ) ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure
                    (Benitoite.Release.Refinement.Comp.ret
                      (Benitoite.Release.Refinement.Val.con shape.error
                        [Benitoite.Release.Refinement.Ty.scoped name kind index, q.capture.closeTy shape.errorType]
                        [Benitoite.Release.Refinement.Val.atError d])))
                  k μ)
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.at_error :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {d : Benitoite.Release.Refinement.AtCheckError},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat target
          bound →
        Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
            Benitoite.Release.Refinement.AtResult.error d →
          have saved :=
            Benitoite.Release.Refinement.AtError.fromCheck (Benitoite.Release.Refinement.closeVal q.capture pattern)
              (Benitoite.Release.Refinement.closeVal q.capture input) snapshot pat target d;
          Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.atErrorPattern
                (Benitoite.Release.Refinement.Val.atError saved) =
              some (Benitoite.Release.Refinement.Detail.values saved) ∧
            (∀ (ws : List Benitoite.Release.Refinement.Val),
                Benitoite.Release.Refinement.AdequateResult ws
                  (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError saved))) ∧
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.Comp.ret
                        (Benitoite.Release.Refinement.Val.con shape.error
                          [Benitoite.Release.Refinement.Ty.scoped name kind
                              (Benitoite.Release.Refinement.RangeIx.fixed bound),
                            q.capture.closeTy shape.errorType]
                          [Benitoite.Release.Refinement.Val.atError saved])))
                    k μ) ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure
                      (Benitoite.Release.Refinement.Comp.ret
                        (Benitoite.Release.Refinement.Val.con shape.error
                          [Benitoite.Release.Refinement.Ty.scoped name kind
                              (Benitoite.Release.Refinement.RangeIx.fixed bound),
                            q.capture.closeTy shape.errorType]
                          [Benitoite.Release.Refinement.Val.atError saved])))
                    k μ)
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.at_ok :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx}
  {snapshot : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {target : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Scope.Domain.Target},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
              Benitoite.Release.Refinement.AtPrepared B q.capture kind name bases pattern input index snapshot pat
                  target bound →
                Benitoite.Release.Refinement.checkAt snapshot kind pat target bound =
                    Benitoite.Release.Refinement.AtResult.ok t →
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret
                            (Benitoite.Release.Refinement.Val.con shape.ok
                              [Benitoite.Release.Refinement.Ty.scoped name kind
                                  (Benitoite.Release.Refinement.RangeIx.fixed bound),
                                q.capture.closeTy shape.errorType]
                              [Benitoite.Release.Refinement.Val.checkedAt bound snapshot t
                                  (Benitoite.Release.Refinement.AtRequest B name
                                    (Benitoite.Release.Refinement.closeVal q.capture input))])))
                        k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret
                            (Benitoite.Release.Refinement.Val.con shape.ok
                              [Benitoite.Release.Refinement.Ty.scoped name kind
                                  (Benitoite.Release.Refinement.RangeIx.fixed bound),
                                q.capture.closeTy shape.errorType]
                              [Benitoite.Release.Refinement.Val.checkedAt bound snapshot t
                                  (Benitoite.Release.Refinement.AtRequest B name
                                    (Benitoite.Release.Refinement.closeVal q.capture input))])))
                        k μ)
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.at_steps :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {shape : Benitoite.Release.Refinement.ResultShape} {bases : Option Benitoite.Release.Refinement.Val}
  {pattern input : Benitoite.Release.Refinement.Val} {index : Benitoite.Release.Refinement.RangeIx},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        σ.Valid →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.code = Benitoite.Release.Refinement.Comp.checkAt kind name shape bases pattern input index →
              Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
                ∃ next,
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none next ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb next
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.path_bases_apply :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b [] [] []) [] →
            B.sig b = some sg →
              sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
                Benitoite.Release.Refinement.NoHandler k (Benitoite.Release.OpRef.prim b) →
                  (∃ Ψ a e, Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg [] [] [] [] a e) ∧
                    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.mk q.capture
                            (Benitoite.Release.Refinement.Comp.issuePathBases b))
                          k μ) ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.mk q.capture
                            (Benitoite.Release.Refinement.Comp.issuePathBases b))
                          k μ)
```

```lean
Benitoite.Release.Refinement.ScopedTargetInputs.issue :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    σ.Valid →
      Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
        q.view = Benitoite.Release.Refinement.Comp.issuePathBases b →
          B.sig b = some sg →
            sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
              Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
                (∃ bs, B.effects Benitoite.Release.Refinement.processEnvironmentEff = some bs ∧ b ∈ bs) ∧
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ)
                      (some (Benitoite.Release.Refinement.Event.pathBases b σ))
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                        k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure
                          (Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.Val.pathBases σ)))
                        k μ)
```

```lean
Benitoite.Release.Refinement.StateTyE.inputs :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {s : Benitoite.Release.Refinement.State},
  Benitoite.Release.Refinement.StateTyE P B σ Eb s → Benitoite.Release.Refinement.State.Inputs P B σ Eb s
```

```lean
Benitoite.Release.Refinement.StateTyE.primitive_contract_inputs :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es rs) ws →
            ∃ Ψ R a e sg r ef,
              Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                  B.sig b = some sg ∧
                    B.RangeAdmissible b sg rs ∧
                      Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es ∧
                        Benitoite.Release.Refinement.SignatureInstance P [] []
                            (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
                            (Benitoite.Release.Refinement.TypeCtx.kinds sg.tparams) ts es ∧
                          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                              (Benitoite.Release.Refinement.instantiatedTel
                                (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es)
                              r ef ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e ef
```

```lean
Benitoite.Release.Refinement.BuiltinArgs.normalized :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es →
    B.RangeAdmissible b sg rs →
      Benitoite.Release.Refinement.SignatureInstance P [] [] (Benitoite.Release.Refinement.Tel.instR rs sg.tel)
          (List.map Benitoite.Release.Refinement.TParamDecl.kind sg.tparams) ts es →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es) a
            e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground) →
            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg (Benitoite.Release.Refinement.Ty.normTys ts)
              (List.map Benitoite.Release.Refinement.Eff.norm es) rs ws a e
```

```lean
Benitoite.Release.Refinement.AtError.save_exact :
∀ (p t : Benitoite.Release.Refinement.Val) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (pp : Option Benitoite.Release.Refinement.RangeExpr) (pt : Option Benitoite.Release.Refinement.TargetInput)
  (f : Benitoite.Release.Refinement.AtFailure),
  have d := Benitoite.Release.Refinement.AtError.save p t snapshot pp pt f;
  d.originalPattern = p ∧
    d.originalTarget = t ∧
      d.failure = f ∧
        d.parsedPattern = pp ∧
          d.parsedTarget = pt ∧
            d.resolvedPatterns = pp.bind (Benitoite.Release.Refinement.resolveSnapshot snapshot) ∧
              d.resolvedTarget = pt.bind (Benitoite.Release.Refinement.resolveTargetSnapshot snapshot) ∧
                d.patternBase = pp.bind Benitoite.Release.Refinement.RangeExpr.base? ∧
                  d.targetBase = pt.bind Benitoite.Release.Refinement.TargetInput.base?
```

```lean
Benitoite.Release.Refinement.AtPrepare.error_saved :
∀ {B : Benitoite.Release.Refinement.Builtins} {cap : Benitoite.Release.Refinement.Capture}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.AtPrepare B cap kind name bases pattern input index = Except.error detail →
    ∃ snapshot pp pt,
      detail =
        Benitoite.Release.Refinement.AtError.save (Benitoite.Release.Refinement.closeVal cap pattern)
          (Benitoite.Release.Refinement.closeVal cap input) snapshot pp pt detail.failure
```

```lean
Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_typed :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
            B.externalResponse f ts vs out obs →
              Benitoite.Release.Refinement.Outcome.Carrier P B Ψ out a ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

```lean
Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      P.ExternalWF →
        P.externalFunction f = some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → ∃ out obs, B.externalResponse f ts vs out obs
```

```lean
Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_no_targets :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → B.externalResponse f ts vs out obs → obs = []
```

```lean
Benitoite.Release.Refinement.Builtins.CoreAssumptions.release_exists :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
      (o : Benitoite.Release.OpaqueName),
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
          (Benitoite.Release.Refinement.Ty.opaque o
            (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
        B.isResource o = true → ∃ r, B.releaseResponse v r
```

```lean
Benitoite.Release.Refinement.ModelScopeConditions.core :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
      (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
          (o : Benitoite.Release.OpaqueName),
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
              (Benitoite.Release.Refinement.Ty.opaque o
                (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
            B.isResource o = true → ∃ r, B.releaseResponse v r) →
        Benitoite.Release.Refinement.Builtins.CoreAssumptions P B
```

