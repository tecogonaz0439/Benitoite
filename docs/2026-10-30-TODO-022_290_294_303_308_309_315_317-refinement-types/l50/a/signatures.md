# 群Aの完全署名と定義形

既定環境の本番11宣言と、F01〜F10の受け口・内部保存候補を印字した。Propの型だけでなく定義本体を含む。将来の実表の証明を構成した意味ではない。供給元と残る単位は results.md を正とする。

```lean
Benitoite.Release.Refinement.PathPattern.covers_atBase :
∀ (w : Benitoite.Scope.Domain.Word) {p q : Benitoite.Scope.Domain.PathPattern},
  p.Covers q →
    (Benitoite.Release.Refinement.PathPattern.atBase w p).Covers (Benitoite.Release.Refinement.PathPattern.atBase w q)
```

```lean
Benitoite.Release.Refinement.RangeExpr.Covers.mem :
∀ {outer inner : Benitoite.Release.Refinement.RangeExpr},
  outer.Covers inner →
    ∀ (σ : Benitoite.Release.Refinement.PathEnv) {k : Benitoite.Scope.Domain.Kind} {t : Benitoite.Scope.Domain.Target},
      Benitoite.Release.Refinement.RangeExpr.Mem σ k inner t → Benitoite.Release.Refinement.RangeExpr.Mem σ k outer t
```

```lean
Benitoite.Release.Refinement.SnapshotMem.mono :
∀ {snapshot : Option Benitoite.Release.Refinement.PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.SnapshotMem snapshot k r t →
    s.Covers r → Benitoite.Release.Refinement.SnapshotMem snapshot k s t
```

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
Benitoite.Release.Refinement.PrimSig.Scoped.namesWF :
∀ {P : Benitoite.Release.Refinement.Program} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.PrimSig.Scoped P sg → Benitoite.Release.Refinement.NamesWF sg.names sg.params
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
Benitoite.Release.Refinement.ModelConstraints.sat_bind_values :
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam) (θ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), θ.types i = Benitoite.Release.Refinement.Ty.tvar i) →
    (Benitoite.Release.Refinement.ModelConstraints.sat S C (Benitoite.Release.Refinement.Ty.bind θ a) p ↔
      Benitoite.Release.Refinement.ModelConstraints.sat S C a p)
```

```lean
Benitoite.Release.Refinement.ModelConstraints.admits_bind_values :
∀ (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
  (as : List Benitoite.Release.Refinement.Ty) (θ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), θ.types i = Benitoite.Release.Refinement.Ty.tvar i) →
    (Benitoite.Release.Refinement.ModelConstraints.admits S ps C
        (List.map (fun a => Benitoite.Release.Refinement.Ty.bind θ a) as) ↔
      Benitoite.Release.Refinement.ModelConstraints.admits S ps C as)
```

```lean
Benitoite.Release.Refinement.ScopeDeclarations.HasHttp.file :
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P → Benitoite.Release.Refinement.ScopeDeclarations.HasFile P
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

```lean
def L50Contracts.F01Path : Prop :=
∀ (w : Benitoite.Scope.Domain.Word) {p q : Benitoite.Scope.Domain.PathPattern},
  p.Covers q →
    (Benitoite.Release.Refinement.PathPattern.atBase w p).Covers (Benitoite.Release.Refinement.PathPattern.atBase w q)
```

```lean
def L50Contracts.F01Range : Prop :=
∀ {outer inner : Benitoite.Release.Refinement.RangeExpr},
  outer.Covers inner →
    ∀ (σ : Benitoite.Release.Refinement.PathEnv) {k : Benitoite.Scope.Domain.Kind} {t : Benitoite.Scope.Domain.Target},
      Benitoite.Release.Refinement.RangeExpr.Mem σ k inner t → Benitoite.Release.Refinement.RangeExpr.Mem σ k outer t
```

```lean
def L50Contracts.F01Snapshot : Prop :=
∀ {snapshot : Option Benitoite.Release.Refinement.PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {r s : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.SnapshotMem snapshot k r t →
    s.Covers r → Benitoite.Release.Refinement.SnapshotMem snapshot k s t
```

```lean
def L50Contracts.F02 : Prop :=
∀ {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {e f : Benitoite.Release.Refinement.Eff} {σ : Benitoite.Release.Refinement.PathEnv}
  {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
  {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Covers Γ Φ e f →
    Benitoite.Release.Refinement.Eff.Allows σ κ f l t → Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

```lean
def L50Contracts.F03 : Prop :=
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
def L50Contracts.F04 : Prop :=
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
def L50Contracts.F05 : Prop :=
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
def L50Contracts.F06Current : Prop :=
∀ {B : Benitoite.Release.Refinement.Builtins} {σ : Benitoite.Release.Refinement.PathEnv}
  {cap : Benitoite.Release.Refinement.Capture} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {bs : Option Benitoite.Release.Refinement.Val}
  {p v : Benitoite.Release.Refinement.Val} {ix : Benitoite.Release.Refinement.RangeIx}
  {snap : Option Benitoite.Release.Refinement.PathEnv} {pat : Benitoite.Release.Refinement.RangeExpr}
  {t : Benitoite.Release.Refinement.TargetInput} {bound : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.Capture.Adequate σ cap →
    (∀ (b : Benitoite.Release.Refinement.Val), bs = some b → Benitoite.Release.Refinement.Val.Adequate σ b) →
      Benitoite.Release.Refinement.AtPrepared B cap kind name bs p v ix snap pat t bound →
        ∀ (ρ : Benitoite.Release.Refinement.PathEnv), snap = some ρ → ρ = σ
```

```lean
def L50Contracts.F06Resolve : Prop :=
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s : Benitoite.Release.Refinement.State}
  {r : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.PathEnv.Ready P B σ s →
    Benitoite.Release.Refinement.PreparationNode.Reachable P B (Benitoite.Release.Refinement.PreparationNode.state s)
        (Benitoite.Release.Refinement.PreparationNode.range r) →
      ∃ rs, Benitoite.Release.Refinement.RangeExpr.resolve σ r = some rs
```

```lean
def L50Contracts.F07Pure : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName → Prop :=
fun P B b =>
  ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (sg : Benitoite.Release.Refinement.PrimSig)
    (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
    (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
    (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          ∃ out,
            B.delta b ts es rs ws = some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

```lean
def L50Contracts.F07IO : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName → Prop :=
fun P B b =>
  ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (sg : Benitoite.Release.Refinement.PrimSig)
    (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
    (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
    (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
              B.ioResponse b ts es ws out obs →
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                      Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws
                        obs) ∧
            ∃ out obs, B.ioResponse b ts es ws out obs
```

```lean
def L50Contracts.F07Ground : Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins → Benitoite.Release.PrimName → Prop :=
fun P B b =>
  ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (sg : Benitoite.Release.Refinement.PrimSig)
    (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
    (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
    (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
    (out : Benitoite.Release.Refinement.Outcome) (v : Benitoite.Release.Refinement.Val),
    B.sig b = some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          B.delta b ts es rs ws = some out → out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

```lean
def L50Contracts.F07ExternalRef : Prop :=
∀ (id : Benitoite.Release.Refinement.ExternalFunctionId) (ts : List Benitoite.Release.Refinement.Ty)
  (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.externalRef id ts))
```

```lean
def L50Contracts.F07ExternalHandle : Prop :=
∀ (h : Benitoite.Release.Refinement.ExternalHandle) (ts : List Benitoite.Release.Refinement.Ty)
  (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.externalHandle h ts))
```

```lean
def L50Contracts.F07ScopePattern : Prop :=
∀ (r : Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.scopePattern r))
```

```lean
def L50Contracts.F07AtError : Prop :=
∀ (d : Benitoite.Release.Refinement.AtError) (ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.AdequateResult ws
    (Benitoite.Release.Refinement.Outcome.val (Benitoite.Release.Refinement.Val.atError d))
```

```lean
def L50Contracts.F08 : Prop :=
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
def L50Contracts.F09Model : Benitoite.Release.Refinement.Builtins → Prop :=
fun B => ∀ (P : Benitoite.Release.Refinement.Program), Benitoite.Release.Refinement.ModelScopeConditions P B
```

```lean
def L50Contracts.F09File : Benitoite.Release.Refinement.Builtins → Prop :=
fun B =>
  ∀ (P : Benitoite.Release.Refinement.Program),
    Benitoite.Release.Refinement.ScopeDeclarations.HasFile P → Benitoite.Release.Refinement.ModelScopeConditions P B
```

```lean
def L50Contracts.F09Http : Benitoite.Release.Refinement.Builtins → Prop :=
fun B =>
  ∀ (P : Benitoite.Release.Refinement.Program),
    Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P → Benitoite.Release.Refinement.ModelScopeConditions P B
```

```lean
structure L50InternalSave.Detail (Raw : Type) : Type
number of parameters: 1
fields:
  L50InternalSave.Detail.failure : Benitoite.Release.Refinement.AtFailure
  L50InternalSave.Detail.originalPattern : Raw
  L50InternalSave.Detail.originalTarget : Raw
  L50InternalSave.Detail.parsedPattern : Option Benitoite.Release.Refinement.RangeExpr
  L50InternalSave.Detail.parsedTarget : Option Benitoite.Release.Refinement.TargetInput
  L50InternalSave.Detail.resolvedPatterns : Option (List Benitoite.Scope.Domain.Range)
  L50InternalSave.Detail.resolvedTarget : Option Benitoite.Scope.Domain.Target
  L50InternalSave.Detail.patternBase : Option Benitoite.Release.Refinement.PathBase
  L50InternalSave.Detail.targetBase : Option Benitoite.Release.Refinement.PathBase
constructor:
  L50InternalSave.Detail.mk {Raw : Type} (failure : Benitoite.Release.Refinement.AtFailure)
    (originalPattern originalTarget : Raw) (parsedPattern : Option Benitoite.Release.Refinement.RangeExpr)
    (parsedTarget : Option Benitoite.Release.Refinement.TargetInput)
    (resolvedPatterns : Option (List Benitoite.Scope.Domain.Range))
    (resolvedTarget : Option Benitoite.Scope.Domain.Target)
    (patternBase targetBase : Option Benitoite.Release.Refinement.PathBase) : L50InternalSave.Detail Raw
```

```lean
def L50InternalSave.save : {Raw : Type} →
  Raw →
    Raw →
      Option Benitoite.Release.Refinement.PathEnv →
        Option Benitoite.Release.Refinement.RangeExpr →
          Option Benitoite.Release.Refinement.TargetInput →
            Benitoite.Release.Refinement.AtFailure → L50InternalSave.Detail Raw :=
fun {Raw} rawPattern rawTarget snapshot parsedPattern parsedTarget failure =>
  { failure := failure, originalPattern := rawPattern, originalTarget := rawTarget, parsedPattern := parsedPattern,
    parsedTarget := parsedTarget,
    resolvedPatterns := parsedPattern.bind (Benitoite.Release.Refinement.resolveSnapshot snapshot),
    resolvedTarget := parsedTarget.bind (Benitoite.Release.Refinement.resolveTargetSnapshot snapshot),
    patternBase := parsedPattern.bind Benitoite.Release.Refinement.RangeExpr.base?,
    targetBase := parsedTarget.bind Benitoite.Release.Refinement.TargetInput.base? }
```

```lean
theorem L50InternalSave.save_exact : ∀ {Raw : Type} (p t : Raw) (snapshot : Option Benitoite.Release.Refinement.PathEnv)
  (pp : Option Benitoite.Release.Refinement.RangeExpr) (pt : Option Benitoite.Release.Refinement.TargetInput)
  (f : Benitoite.Release.Refinement.AtFailure),
  have d := L50InternalSave.save p t snapshot pp pt f;
  d.originalPattern = p ∧
    d.originalTarget = t ∧
      d.failure = f ∧
        d.parsedPattern = pp ∧
          d.parsedTarget = pt ∧
            d.resolvedPatterns = pp.bind (Benitoite.Release.Refinement.resolveSnapshot snapshot) ∧
              d.resolvedTarget = pt.bind (Benitoite.Release.Refinement.resolveTargetSnapshot snapshot) ∧
                d.patternBase = pp.bind Benitoite.Release.Refinement.RangeExpr.base? ∧
                  d.targetBase = pt.bind Benitoite.Release.Refinement.TargetInput.base? :=
fun {Raw} p t snapshot pp pt f => ⟨rfl, ⟨rfl, ⟨rfl, ⟨rfl, ⟨rfl, ⟨rfl, ⟨rfl, ⟨rfl, rfl⟩⟩⟩⟩⟩⟩⟩⟩
```

```lean
structure Benitoite.Release.Refinement.ModelScopeConditions (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) : Prop
number of parameters: 2
parents:
  Benitoite.Release.Refinement.ModelScopeConditions.toSubstitutionAssumptions : Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions
    P B
  Benitoite.Release.Refinement.ModelScopeConditions.toResponseAssumptions : Benitoite.Release.Refinement.Builtins.ResponseAssumptions
    P B
  Benitoite.Release.Refinement.ModelScopeConditions.toTargetAgreement : Benitoite.Release.Refinement.Builtins.TargetAgreement
    P B
fields:
  Benitoite.Release.Refinement.Builtins.ValueAssumptions.sat_rename : ∀ (C : Benitoite.Release.Refinement.TypeCtx)
      (Γ Δ : Benitoite.Release.Refinement.Ctx) (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam)
      (ξ : Nat → Nat),
      (∀ (i j : Nat), i < j → ξ i < ξ j) →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation P C Δ (Benitoite.Release.Refinement.renameTy ξ a) →
            B.sat C.constraints a p → B.sat C.constraints (Benitoite.Release.Refinement.renameTy ξ a) p
  Benitoite.Release.Refinement.Builtins.ValueAssumptions.admits_rename : ∀ (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (C : Benitoite.Release.Refinement.TypeCtx)
      (Γ Δ : Benitoite.Release.Refinement.Ctx) (ts : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
      B.sig b = some sg →
        (∀ (i j : Nat), i < j → ξ i < ξ j) →
          Benitoite.Release.Refinement.TypeAnnotations P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations P C Δ (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) →
              sg.admits C.constraints ts →
                sg.admits C.constraints (List.map (Benitoite.Release.Refinement.renameTy ξ) ts)
  Benitoite.Release.Refinement.Builtins.ValueAssumptions.sat_values : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (Q : Benitoite.Release.NoFailCtx) (C : Benitoite.Release.Refinement.TypeCtx)
      (Γ Δ : Benitoite.Release.Refinement.Ctx) (Ξ : List Benitoite.Release.Refinement.Pred)
      (ν : Nat → Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam),
      Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
          B.sat C.constraints a p → B.sat C.constraints (Benitoite.Release.Refinement.substTyValues ν a) p
  Benitoite.Release.Refinement.Builtins.ValueAssumptions.admits_values : ∀ (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (Ψ : Benitoite.Release.Refinement.StoreTy)
      (Q : Benitoite.Release.NoFailCtx) (C : Benitoite.Release.Refinement.TypeCtx)
      (Γ Δ : Benitoite.Release.Refinement.Ctx) (Ξ : List Benitoite.Release.Refinement.Pred)
      (ν : Nat → Benitoite.Release.Refinement.Val) (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = some sg →
        Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
          Benitoite.Release.Refinement.TypeAnnotations P C Γ ts →
            sg.admits C.constraints ts →
              sg.admits C.constraints (List.map (Benitoite.Release.Refinement.substTyValues ν) ts)
  Benitoite.Release.Refinement.Builtins.TypeAssumptions.sat_renameTypes : ∀
      (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ρ : Nat → Nat),
      Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation P C' Δ (a.renameTypes ρ) →
            B.sat C.constraints a p → B.sat C'.constraints (a.renameTypes ρ) p
  Benitoite.Release.Refinement.Builtins.TypeAssumptions.admits_renameTypes : ∀ (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (C C' : Benitoite.Release.Refinement.TypeCtx)
      (Γ Δ : Benitoite.Release.Refinement.Ctx) (ts : List Benitoite.Release.Refinement.Ty) (ρ : Nat → Nat),
      B.sig b = some sg →
        Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
          Benitoite.Release.Refinement.TypeAnnotations P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations P C' Δ (List.map (fun a => a.renameTypes ρ) ts) →
              sg.admits C.constraints ts → sg.admits C'.constraints (List.map (fun a => a.renameTypes ρ) ts)
  Benitoite.Release.Refinement.Builtins.TypeAssumptions.sat_subst : ∀ (C0 C1 : Benitoite.Release.Refinement.TypeCtx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff),
      B.sat (C1 ++ C0).constraints a p →
        (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
          Benitoite.Release.Refinement.SatAll B C1 ts C0.constraints →
            ts.length = List.length C0 →
              B.sat C1.constraints (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p
  Benitoite.Release.Refinement.Builtins.TypeAssumptions.admits_subst : ∀ (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (C0 C1 : Benitoite.Release.Refinement.TypeCtx)
      (ts ts' : List Benitoite.Release.Refinement.Ty) (es' : List Benitoite.Release.Refinement.Eff),
      B.sig b = some sg →
        sg.admits (C1 ++ C0).constraints ts →
          (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts' → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
            Benitoite.Release.Refinement.SatAll B C1 ts' C0.constraints →
              ts'.length = List.length C0 →
                sg.admits C1.constraints
                  (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts' es') ts)
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions.delta_typed : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
      B.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            ∃ out,
              B.delta b ts es rs ws = some out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                    Benitoite.Release.Refinement.AdequateResult ws out
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_typed : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
      (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            B.ioResponse b ts es ws out obs →
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_kind : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
      (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = some sg →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
          B.ioResponse b ts es ws out obs →
            (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_exists : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
      B.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            ∃ out obs, B.ioResponse b ts es ws out obs
  Benitoite.Release.Refinement.Builtins.TargetAgreement.io_target : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
      (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            B.ioResponse b ts es ws out obs →
              Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs
  Benitoite.Release.Refinement.ModelScopeConditions.sig_scoped : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig), B.sig b = some s → Benitoite.Release.Refinement.PrimSig.Scoped P s
  Benitoite.Release.Refinement.ModelScopeConditions.sat_unconstrained : ∀ (t : Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.Ty.WF 0 0 0 t → B.sat [] t.norm { }
  Benitoite.Release.Refinement.ModelScopeConditions.admits_sat : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig) (C : Benitoite.Release.Refinement.TypeCtx)
      (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = some s →
        s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
          Benitoite.Release.Refinement.SatAll B C ts
            (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
  Benitoite.Release.Refinement.ModelScopeConditions.pathBases_shape : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = some s → s.kind = Benitoite.Release.Refinement.PrimKind.pathBases → s.PathBasesShape B b
  Benitoite.Release.Refinement.ModelScopeConditions.io_op : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          B.ShapeOk b s
  Benitoite.Release.Refinement.ModelScopeConditions.opEff_io : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
      B.sig b = some s →
        s.opEff = some l →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
  Benitoite.Release.Refinement.ModelScopeConditions.effect_ops : ∀ (l : Benitoite.Release.EffName)
      (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
      B.effects l = some bs →
        b ∈ bs →
          ∃ s,
            B.sig b = some s ∧
              (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                  s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                s.opEff = some l
  Benitoite.Release.Refinement.ModelScopeConditions.state_effect : B.effects Benitoite.Release.stateEff = some []
  Benitoite.Release.Refinement.ModelScopeConditions.ref_get : ∃ s,
      B.sig B.refGet = some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refGet
  Benitoite.Release.Refinement.ModelScopeConditions.ref_set : ∃ s,
      B.sig B.refSet = some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refSet
  Benitoite.Release.Refinement.ModelScopeConditions.store_shape : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = some s → s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
  Benitoite.Release.Refinement.ModelScopeConditions.store_admits : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
      (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = some s →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
            s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
              s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → ts.length = s.tparams.length → s.admits C ts
constructor:
  Benitoite.Release.Refinement.ModelScopeConditions.mk {P : Benitoite.Release.Refinement.Program}
    {B : Benitoite.Release.Refinement.Builtins}
    (toSubstitutionAssumptions : Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B)
    (toResponseAssumptions : Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B)
    (toTargetAgreement : Benitoite.Release.Refinement.Builtins.TargetAgreement P B)
    (sig_scoped :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = some s → Benitoite.Release.Refinement.PrimSig.Scoped P s)
    (sat_unconstrained :
      ∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.Ty.WF 0 0 0 t → B.sat [] t.norm { })
    (admits_sat :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
        (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
        B.sig b = some s →
          s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
            Benitoite.Release.Refinement.SatAll B C ts
              (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams))
    (pathBases_shape :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = some s → s.kind = Benitoite.Release.Refinement.PrimKind.pathBases → s.PathBasesShape B b)
    (io_op :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = some s →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
            B.ShapeOk b s)
    (opEff_io :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
        B.sig b = some s →
          s.opEff = some l →
            s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases)
    (effect_ops :
      ∀ (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
        B.effects l = some bs →
          b ∈ bs →
            ∃ s,
              B.sig b = some s ∧
                (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                      s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                  s.opEff = some l)
    (state_effect : B.effects Benitoite.Release.stateEff = some [])
    (ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refGet)
    (ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refSet)
    (store_shape :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = some s → s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape)
    (store_admits :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
        (ts : List Benitoite.Release.Refinement.Ty),
        B.sig b = some s →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
            s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
              s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
                s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases →
                  ts.length = s.tparams.length → s.admits C ts) :
    Benitoite.Release.Refinement.ModelScopeConditions P B
field notation resolution order:
  Benitoite.Release.Refinement.ModelScopeConditions, Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions, Benitoite.Release.Refinement.Builtins.ResponseAssumptions, Benitoite.Release.Refinement.Builtins.TargetAgreement, Benitoite.Release.Refinement.Builtins.ValueAssumptions, Benitoite.Release.Refinement.Builtins.TypeAssumptions
```

