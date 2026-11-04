# 群 C の実署名

任意の入力を量化する本番の実型。その他の追加宣言は declarations.json に記録する。

```lean
Benitoite.Release.Refinement.HasTypeVQ.target_member :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = some k →
        Benitoite.Release.Refinement.Val.Adequate σ v →
          ∃ t, v.target? = some t ∧ Benitoite.Release.Refinement.RangeExpr.Mem σ k r t
```

```lean
Benitoite.Release.Refinement.Builtins.ShapeOk.single_target :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {k : Benitoite.Scope.Domain.Kind} {p : Nat}
  {σ : Benitoite.Release.Refinement.PathEnv},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
      Benitoite.Release.Refinement.NamesWF sg.names sg.params →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            ∃ r t,
              rs = [r] ∧
                ws[p]?.bind Benitoite.Release.Refinement.Val.target? = some t ∧
                  Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                    sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k p
```

```lean
Benitoite.Release.Refinement.Builtins.TargetAgreement.obs_allowed :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  B.ShapeOk b sg →
    Benitoite.Release.Refinement.Builtins.TargetAgreement P B →
      B.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.NamesWF sg.names sg.params →
            Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
              (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
                B.ioResponse b ts es ws out obs →
                  ∃ l,
                    sg.opEff = some l ∧
                      ∀ (t : Benitoite.Scope.Domain.Target),
                        t ∈ obs → Benitoite.Release.Refinement.Eff.Allows σ B.effKind e l t
```

```lean
Benitoite.Release.Refinement.TelClosure.apply :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {t u : Benitoite.Release.Refinement.Tel}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Ctx.WF 0 (List.length C) Γ →
    Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.dependentFn t) →
      Benitoite.Release.Refinement.TelClosure P Γ Φ t u →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
          ∃ b f,
            Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ b a ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ e f
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.canonical_target :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = some k →
        Benitoite.Release.Refinement.Val.Adequate σ v →
          ∃ t,
            v.target? = some t ∧
              Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                (v = Benitoite.Release.Refinement.Val.checked t ∨
                  (∃ req, v = Benitoite.Release.Refinement.Val.checkedRequest t req) ∨
                    ∃ s snapshot req, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot t req)
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.target_member_interpret :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {r : Benitoite.Release.Refinement.RangeExpr} {σ : Benitoite.Release.Refinement.PathEnv}
  {η : Benitoite.Release.Refinement.ObservationEnvModel} {a : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = some k →
        Benitoite.Release.Refinement.Val.Adequate σ v →
          σ.Valid →
            (∀ (t : Benitoite.Scope.Domain.Target),
                v.target? = some t →
                  Benitoite.Release.Refinement.observeAs η (Benitoite.Release.Refinement.Sort.target k) a =
                    Benitoite.Release.Refinement.Observation.targetValue (some σ) t) →
              ∃ t,
                v.target? = some t ∧
                  Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                    Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a r) =
                      true
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.request_form :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {r : Benitoite.Release.Refinement.RangeExpr}
  {σ : Benitoite.Release.Refinement.PathEnv} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o Benitoite.Scope.Domain.Kind.endpoint (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = some Benitoite.Scope.Domain.Kind.endpoint →
        B.valContent o = some A →
          Benitoite.Release.Refinement.Val.Adequate σ v →
            ∃ target req,
              v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (some req)
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.request_target :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName} {r : Benitoite.Release.Refinement.RangeExpr}
  {σ : Benitoite.Release.Refinement.PathEnv} {A : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o Benitoite.Scope.Domain.Kind.endpoint (Benitoite.Release.Refinement.RangeIx.fixed r) →
      B.valKind o = some Benitoite.Scope.Domain.Kind.endpoint →
        B.valContent o = some A →
          Benitoite.Release.Refinement.Val.Adequate σ v →
            ∃ target req,
              (v = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                  ∃ s snapshot, v = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (some req)) ∧
                Benitoite.Release.Refinement.ModelHttp.valueRun [v] = Benitoite.Release.Refinement.Outcome.val req ∧
                  Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                    Benitoite.Release.Refinement.groundVal req = true ∧
                      req.reqTarget = some target ∧
                        Benitoite.Release.Refinement.RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.endpoint r target
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.canonical_opaque :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName} {ix : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v (Benitoite.Release.Refinement.Ty.opaque o ix) →
    (∃ n,
        v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o n) ∧
          ix = Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top) ∨
      ∃ k,
        B.valKind o = some k ∧
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v (Benitoite.Release.Refinement.Ty.scoped o k ix)
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.widen_opaque :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName}
  {r s : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
      (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) →
    s.Covers r →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
        (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed s))
```

```lean
Benitoite.Release.Refinement.HasTypeVQ.widen_instTarget_covers :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {p : Benitoite.Release.Refinement.Ty}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {n nv : Nat} {S : Benitoite.Release.Refinement.RangeExpr},
  rs.length = n →
    Benitoite.Release.Refinement.Ty.TargetWF n (List.length C) nv p →
      (∀ (r : Benitoite.Release.Refinement.RangeExpr), r ∈ rs → S.Covers r) →
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
            (Benitoite.Release.Refinement.Ty.subst ts es (Benitoite.Release.Refinement.Ty.instTarget rs p)) →
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
            (Benitoite.Release.Refinement.Ty.subst ts es
              (Benitoite.Release.Refinement.Ty.instTarget (List.replicate n S) p))
```

```lean
Benitoite.Release.Refinement.HasTypeVsQ.widen_covers :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {ws : List Benitoite.Release.Refinement.Val} {ps ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr} {n : Nat}
  {S : Benitoite.Release.Refinement.RangeExpr} {nv : Nat},
  rs.length = n →
    Benitoite.Release.Refinement.BinderTypes.TargetWF n (List.length C) nv ps →
      (∀ (r : Benitoite.Release.Refinement.RangeExpr), r ∈ rs → S.Covers r) →
        Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C [] Φ ws
            (List.map (Benitoite.Release.Refinement.Ty.subst ts es)
              (List.map (Benitoite.Release.Refinement.Ty.instTarget rs) ps)) →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C [] Φ ws
            (List.map (Benitoite.Release.Refinement.Ty.subst ts es)
              (List.map (Benitoite.Release.Refinement.Ty.instTarget (List.replicate n S)) ps))
```

```lean
Benitoite.Release.Refinement.Builtins.ShapeOk.common :
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig},
  B.ShapeOk b sg → ∃ l bs, sg.opEff = some l ∧ sg.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs
```

```lean
Benitoite.Release.Refinement.Builtins.ShapeOk.inst_eff_mem :
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig},
  B.ShapeOk b sg →
    ∀ (rs : List Benitoite.Release.Refinement.RangeExpr),
      ∃ l bs ix,
        sg.opEff = some l ∧
          B.effects l = some bs ∧
            b ∈ bs ∧
              (Benitoite.Release.Refinement.Eff.instR rs sg.eff).mem
                (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.inst rs ix))
```

```lean
Benitoite.Release.Refinement.Builtins.ShapeOk.single_inst :
∀ {B : Benitoite.Release.Refinement.Builtins} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {k : Benitoite.Scope.Domain.Kind} {p : Nat},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single k p →
      ∀ (r : Benitoite.Release.Refinement.RangeExpr),
        ∃ l o,
          sg.opEff = some l ∧
            B.effKind l = some k ∧
              (Benitoite.Release.Refinement.Eff.instR [r] sg.eff).mem
                  (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed r)) ∧
                (List.map (Benitoite.Release.Refinement.Ty.instR [r]) sg.params)[p]? =
                    some (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.fixed r)) ∧
                  B.valKind o = some k
```

```lean
Benitoite.Release.Refinement.Builtins.ShapeOk.single_request :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {p : Nat} {σ : Benitoite.Release.Refinement.PathEnv}
  {A : Benitoite.Release.Refinement.Ty},
  B.ShapeOk b sg →
    sg.shape = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p →
      Benitoite.Release.Refinement.NamesWF sg.names sg.params →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            (∀ (o : Benitoite.Release.OpaqueName),
                sg.params[p]? =
                    some (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                  B.valContent o = some A) →
              ∃ r w target req,
                rs = [r] ∧
                  ws[p]? = some w ∧
                    sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint p ∧
                      (w = Benitoite.Release.Refinement.Val.checkedRequest target req ∨
                          ∃ s snapshot, w = Benitoite.Release.Refinement.Val.checkedAt s snapshot target (some req)) ∧
                        Benitoite.Release.Refinement.ModelHttp.valueRun [w] =
                            Benitoite.Release.Refinement.Outcome.val req ∧
                          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] req A.norm ∧
                            Benitoite.Release.Refinement.groundVal req = true ∧
                              req.reqTarget = some target ∧
                                Benitoite.Release.Refinement.RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.endpoint r
                                  target
```

```lean
Benitoite.Release.Refinement.ScopedCallContracts.single_inputs :
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
                                  ws[p]?.bind Benitoite.Release.Refinement.Val.target? = some t ∧
                                    Benitoite.Release.Refinement.RangeExpr.Mem σ k r t ∧
                                      sg.shapeAt ws = Benitoite.Scope.Signature.IOShape.single k p
```

```lean
Benitoite.Release.Refinement.ScopedCallContracts.request_inputs :
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
                              some
                                (Benitoite.Release.Refinement.Ty.opaque o
                                  (Benitoite.Release.Refinement.RangeIx.rvar 0)) →
                            B.valContent o = some A) →
                        ∃ a₀ e₀ r w target req,
                          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                              (Benitoite.Release.Refinement.instantiatedTel
                                (Benitoite.Release.Refinement.Tel.instR rs sg.tel) ts es)
                              a₀ e₀ ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] a₀ a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]? = some w ∧
                                    sg.shapeAt ws =
                                        Benitoite.Scope.Signature.IOShape.single Benitoite.Scope.Domain.Kind.endpoint
                                          p ∧
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
                                                  Benitoite.Scope.Domain.Kind.endpoint r target
```

