# 段末の実署名（1/3）

生成物（[audit.py](audit.py)）。段の公理監査（[../axioms.lean](../axioms.lean)）の型の印字であり、接頭辞 `Benitoite.Release.Refinement.` を見出しでだけ省く。

### `Builtins.TypingFieldsEq`（F01）

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.Builtins → Prop
```

### `HasTypeVQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a → Benitoite.Release.Refinement.HasTypeVQ P B' Ψ Q C Γ Φ v a
```

### `HasTypeVsQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as →
      Benitoite.Release.Refinement.HasTypeVsQ P B' Ψ Q C Γ Φ vs as
```

### `HasTypeEachQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a →
      Benitoite.Release.Refinement.HasTypeEachQ P B' Ψ Q C Γ Φ vs a
```

### `HasTypeCQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {m : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty} {ε : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
      Benitoite.Release.Refinement.HasTypeCQ P B' Ψ Q C Γ Φ R m a ε Δ
```

### `HasTypeTelArgsQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {ws : List Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Tel} {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e →
      Benitoite.Release.Refinement.HasTypeTelArgsQ P B' Ψ Q C Γ Φ ws t a e
```

### `TelBodyTy.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {t : Benitoite.Release.Refinement.Tel}
  {body : Benitoite.Release.Refinement.Comp},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.TelBodyTy P B Ψ Q C Γ Φ t body →
      Benitoite.Release.Refinement.TelBodyTy P B' Ψ Q C Γ Φ t body
```

### `CaptureOk.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {R : Option Benitoite.Release.Refinement.Ty}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {cap : Benitoite.Release.Refinement.Capture},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap → Benitoite.Release.Refinement.CaptureOk P B' Ψ R Γ Φ cap
```

### `DependentClosureTy.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {body : Benitoite.Release.Refinement.Closure}
  {t : Benitoite.Release.Refinement.Tel},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.DependentClosureTy P B Ψ body t →
      Benitoite.Release.Refinement.DependentClosureTy P B' Ψ body t
```

### `CheckedWitness.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind}
  {range : Benitoite.Release.Refinement.RangeExpr} {snapshot : Option Benitoite.Release.Refinement.PathEnv}
  {target : Benitoite.Scope.Domain.Target} {request : Option Benitoite.Release.Refinement.Val},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.CheckedWitness P B Ψ o k range snapshot target request →
      Benitoite.Release.Refinement.CheckedWitness P B' Ψ o k range snapshot target request
```

### `AtCallAdmissible.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {shape : Benitoite.Release.Refinement.ResultShape}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index →
      Benitoite.Release.Refinement.AtCallAdmissible P B' Ψ Q C Γ Φ kind name shape bases pattern input index
```

### `HasTypeArmsQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {obs : Option Benitoite.Release.Refinement.Term} {arms : List Benitoite.Release.Refinement.Arm}
  {a b : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e Δ →
      Benitoite.Release.Refinement.HasTypeArmsQ P B' Ψ Q C Γ Φ R obs arms a b e Δ
```

### `HasTypeClausesQ.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {eb : Benitoite.Release.Refinement.Eff} {cs : List Benitoite.Release.Refinement.Clause}
  {t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e Δ →
      Benitoite.Release.Refinement.HasTypeClausesQ P B' Ψ Q C Γ Φ R eb cs t e Δ
```

### `HasFailureClause.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {E : Benitoite.Release.Refinement.Ty}
  {R : Option Benitoite.Release.Refinement.Ty} {cs : List Benitoite.Release.Refinement.Clause}
  {t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.HasFailureClause P B Ψ Q C Γ Φ E R cs t e Δ →
      Benitoite.Release.Refinement.HasFailureClause P B' Ψ Q C Γ Φ E R cs t e Δ
```

### `ImageOk.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {env : Nat → Benitoite.Release.Refinement.Val} {i : Nat} {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.ImageOk P B Ψ Q C Γ Φ R env i a →
      Benitoite.Release.Refinement.ImageOk P B' Ψ Q C Γ Φ R env i a
```

### `ExternalArgs.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {d : Benitoite.Release.Refinement.ExternalSignature}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
      Benitoite.Release.Refinement.ExternalArgs P B' Ψ d ts vs a e
```

### `BuiltinArgs.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ b s ts es rs vs a e →
      Benitoite.Release.Refinement.BuiltinArgs P B' Ψ b s ts es rs vs a e
```

### `ExternalCarrier.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.ExternalCarrier P B Ψ v a → Benitoite.Release.Refinement.ExternalCarrier P B' Ψ v a
```

### `ExternalCarrierEach.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.ExternalCarrierEach P B Ψ vs a →
      Benitoite.Release.Refinement.ExternalCarrierEach P B' Ψ vs a
```

### `ExternalCarrierFields.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.ExternalCarrierFields P B Ψ vs as →
      Benitoite.Release.Refinement.ExternalCarrierFields P B' Ψ vs as
```

### `Outcome.Typed.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {out : Benitoite.Release.Refinement.Outcome}
  {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a → Benitoite.Release.Refinement.Outcome.Typed P B' Ψ out a
```

### `Outcome.Carrier.of_fields`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {out : Benitoite.Release.Refinement.Outcome}
  {a : Benitoite.Release.Refinement.Ty},
  B.TypingFieldsEq B' →
    Benitoite.Release.Refinement.Outcome.Carrier P B Ψ out a → Benitoite.Release.Refinement.Outcome.Carrier P B' Ψ out a
```

### `ModelScopeConditions.of_responses`（F01）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B B' : Benitoite.Release.Refinement.Builtins},
  B.TypingFieldsEq B' →
    B.delta = B'.delta →
      B.ioResponse = B'.ioResponse →
        B.refGet = B'.refGet →
          B.refSet = B'.refSet →
            B.effKind = B'.effKind →
              Benitoite.Release.Refinement.ModelScopeConditions P B →
                Benitoite.Release.Refinement.ModelScopeConditions P B'
```

### `ExternalNominal.Preserves`（F02）

```lean
(Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty) → Prop
```

### `ExternalNominal.transformations`（F02）

```lean
∀ (support : List Benitoite.Release.Refinement.Atom) (θ : Benitoite.Release.Refinement.SubstEnv) (k c : Nat)
  (types : Nat → Nat) (ranges : Nat → Benitoite.Release.Refinement.RangeIx)
  (values : Benitoite.Release.Refinement.ObservationEnv) (rs : List Benitoite.Release.Refinement.RangeExpr)
  (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
  (runtimeValues : Nat → Benitoite.Release.Refinement.Val) (cap : Benitoite.Release.Refinement.Capture)
  (ps : List Benitoite.Release.Refinement.Pred) (p : Benitoite.Release.Refinement.Pred)
  (transform : Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty),
  transform ∈
      [Benitoite.Release.Refinement.Ty.norm, Benitoite.Release.Refinement.Ty.normWith support,
        Benitoite.Release.Refinement.Ty.shiftV k c, Benitoite.Release.Refinement.Ty.rawMapRanges ranges, fun a =>
        Benitoite.Release.Refinement.Ty.rawRenameTypes types a, Benitoite.Release.Refinement.Ty.rawBind θ,
        Benitoite.Release.Refinement.shiftTypes k c, Benitoite.Release.Refinement.Ty.rawSubstV values,
        Benitoite.Release.Refinement.Ty.renameValues types, Benitoite.Release.Refinement.Ty.carrier,
        Benitoite.Release.Refinement.Ty.observationType, Benitoite.Release.Refinement.Ty.bind θ, fun a =>
        a.renameTypes types, Benitoite.Release.Refinement.Ty.mapRanges ranges,
        Benitoite.Release.Refinement.Ty.substRAt c rs, Benitoite.Release.Refinement.Ty.instR rs,
        Benitoite.Release.Refinement.Ty.shiftR k c, Benitoite.Release.Refinement.Ty.substAt c ts es,
        Benitoite.Release.Refinement.Ty.subst ts es, Benitoite.Release.Refinement.Ty.shift k c,
        Benitoite.Release.Refinement.Ty.substV values, Benitoite.Release.Refinement.Ty.substVAt c values,
        Benitoite.Release.Refinement.renameTy types, Benitoite.Release.Refinement.substTyValues runtimeValues,
        Benitoite.Release.Refinement.substTypeAt c ts es, cap.closeTy, cap.closeTyAt c, fun a => a.packRefinements ps,
        fun a => a.refineNorm p] →
    Benitoite.Release.Refinement.ExternalNominal.Preserves transform
```

### `ExternalNominal.transformed_distinct`（F02）

```lean
∀ {transform : Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ExternalNominal.Preserves transform →
    ∀ {id other : Benitoite.Release.Refinement.ExternalId},
      id ≠ other →
        ∀ (as bs : List Benitoite.Release.Refinement.Ty),
          transform (Benitoite.Release.Refinement.Ty.external id as) ≠
            transform (Benitoite.Release.Refinement.Ty.external other bs)
```

### `ExternalNominal.table_wf_iff`（F02）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  P.ExternalWF ↔
    (List.map Prod.fst P.externals).Nodup ∧
      (∀ (id : Benitoite.Release.Refinement.ExternalId) (td : Benitoite.Release.Refinement.ExternalTypeDecl),
          (Benitoite.Release.Refinement.ExternalKey.type id, Benitoite.Release.Refinement.ExternalDecl.type td) ∈
              P.externals →
            td.id = id ∧ td.arity = 0) ∧
        (∀ (f g : Benitoite.Release.Refinement.ExternalFunctionId) (d : Benitoite.Release.Refinement.ExternalSignature),
            (Benitoite.Release.Refinement.ExternalKey.function f,
                  Benitoite.Release.Refinement.ExternalDecl.function g d) ∈
                P.externals →
              f = g ∧ Benitoite.Release.Refinement.ExternalSignature.WF P d) ∧
          (∀ (id : Benitoite.Release.Refinement.ExternalId) (f : Benitoite.Release.Refinement.ExternalFunctionId)
              (d : Benitoite.Release.Refinement.ExternalSignature),
              ¬(Benitoite.Release.Refinement.ExternalKey.type id,
                    Benitoite.Release.Refinement.ExternalDecl.function f d) ∈
                  P.externals) ∧
            ∀ (f : Benitoite.Release.Refinement.ExternalFunctionId)
              (td : Benitoite.Release.Refinement.ExternalTypeDecl),
              ¬(Benitoite.Release.Refinement.ExternalKey.function f,
                    Benitoite.Release.Refinement.ExternalDecl.type td) ∈
                  P.externals
```

### `ExternalNominal.declared_arity`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx} {id : Benitoite.Release.Refinement.ExternalId}
  {args : List Benitoite.Release.Refinement.Ty},
  P.ExternalWF →
    Benitoite.Release.Refinement.Ty.Declared P C Γ (Benitoite.Release.Refinement.Ty.external id args) → args = []
```

### `ExternalNominal.unknown`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx} {id : Benitoite.Release.Refinement.ExternalId}
  {args : List Benitoite.Release.Refinement.Ty},
  P.externalType id = Option.none →
    ¬Benitoite.Release.Refinement.Ty.Declared P C Γ (Benitoite.Release.Refinement.Ty.external id args)
```

### `ExternalNominal.unknown_handle`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {h : Benitoite.Release.Refinement.ExternalHandle} {ts : List Benitoite.Release.Refinement.Ty},
  P.externalType h.typeId = Option.none →
    ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalHandle h ts) T
```

### `ExternalNominal.type_entry`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {id : Benitoite.Release.Refinement.ExternalId}
  {td : Benitoite.Release.Refinement.ExternalTypeDecl},
  (Benitoite.Release.Refinement.ExternalKey.type id, Benitoite.Release.Refinement.ExternalDecl.type td) ∈ P.externals →
    td.id ≠ id ∨ td.arity ≠ 0 → ¬P.ExternalWF
```

### `ExternalNominal.function_entry`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {f g : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature},
  (Benitoite.Release.Refinement.ExternalKey.function f, Benitoite.Release.Refinement.ExternalDecl.function g d) ∈
      P.externals →
    f ≠ g → ¬P.ExternalWF
```

### `ExternalNominal.handle_declaration`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {h : Benitoite.Release.Refinement.ExternalHandle} {ts : List Benitoite.Release.Refinement.Ty},
  P.ExternalWF →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalHandle h ts) T →
      ∃ td,
        P.externalType h.typeId = Option.some td ∧
          td.id = h.typeId ∧ td.component = h.component ∧ td.resource = h.resource ∧ td.arity = 0 ∧ ts = []
```

### `ExternalNominal.duplicate`（F02）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {key : Benitoite.Release.Refinement.ExternalKey}
  {a b : Benitoite.Release.Refinement.ExternalDecl}
  {rest : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)},
  P.externals = (key, a) :: (key, b) :: rest → ¬P.ExternalWF
```

### `ExternalNominal.distinct`（F02）

```lean
∀ {id other : Benitoite.Release.Refinement.ExternalId},
  id ≠ other →
    ∀ (as bs : List Benitoite.Release.Refinement.Ty),
      (Benitoite.Release.Refinement.Ty.external id as).norm ≠ (Benitoite.Release.Refinement.Ty.external other bs).norm
```

### `ExternalUseAt.mode`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {n : Nat} {tel : Benitoite.Release.Refinement.Tel}
  {use : Benitoite.Release.Refinement.ExternalUse},
  Benitoite.Release.Refinement.ExternalUseAt P n tel use →
    (∀ (i : Nat),
        use.position = Benitoite.Release.Refinement.ExternalPosition.argument i →
          use.mode = Benitoite.Release.Refinement.ExternalMode.borrow) ∧
      (use.position = Benitoite.Release.Refinement.ExternalPosition.result →
        use.mode = Benitoite.Release.Refinement.ExternalMode.own)
```

### `ExternalSignatureLeaves.occurrence_declaration`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {component : Benitoite.Release.Refinement.ComponentId} {unit : Bool}
  {a : Benitoite.Release.Refinement.Ty} {path : List Benitoite.Release.Refinement.ExternalPathStep}
  {id : Benitoite.Release.Refinement.ExternalId},
  Benitoite.Release.Refinement.ExternalValueType P component unit a →
    Benitoite.Release.Refinement.ExternalOccurrence P a path id →
      ∃ td, P.externalType id = Option.some td ∧ td.component = component ∧ td.id = id ∧ td.arity = 0
```

### `ExternalSignatureLeaves.use_declaration`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {component : Benitoite.Release.Refinement.ComponentId}
  {effect : Benitoite.Release.Refinement.Eff} {tel : Benitoite.Release.Refinement.Tel} {n : Nat}
  {use : Benitoite.Release.Refinement.ExternalUse},
  Benitoite.Release.Refinement.ExternalTelWF P component effect tel →
    Benitoite.Release.Refinement.ExternalUseAt P n tel use →
      ∃ td, P.externalType use.typeId = Option.some td ∧ td.component = component ∧ td.id = use.typeId ∧ td.arity = 0
```

### `ExternalSignatureLeaves.declared_use`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {d : Benitoite.Release.Refinement.ExternalSignature}
  {use : Benitoite.Release.Refinement.ExternalUse},
  Benitoite.Release.Refinement.ExternalSignature.WF P d →
    use ∈ d.uses →
      (∀ (i : Nat),
          use.position = Benitoite.Release.Refinement.ExternalPosition.argument i →
            use.mode = Benitoite.Release.Refinement.ExternalMode.borrow) ∧
        (use.position = Benitoite.Release.Refinement.ExternalPosition.result →
            use.mode = Benitoite.Release.Refinement.ExternalMode.own) ∧
          ∃ td,
            P.externalType use.typeId = Option.some td ∧ td.component = d.component ∧ td.id = use.typeId ∧ td.arity = 0
```

### `ExternalSignatureLeaves.collected_contract`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature},
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      d.tparams = [] ∧
        d.kinds = [] ∧
          Benitoite.Release.Refinement.Ty.Annotation P [] []
              (Benitoite.Release.Refinement.Ty.dependentFn d.parameters) ∧
            Benitoite.Release.Refinement.Ty.HasKind P [] (Benitoite.Release.Refinement.Ty.dependentFn d.parameters)
                Benitoite.Release.Refinement.TyKind.value ∧
              d.uses.Nodup ∧
                Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < 0) d.parameters ∧
                  (∀ (use : Benitoite.Release.Refinement.ExternalUse),
                      use ∈ d.uses ↔ Benitoite.Release.Refinement.ExternalUseAt P 0 d.parameters use) ∧
                    ∀ (use : Benitoite.Release.Refinement.ExternalUse),
                      use ∈ d.uses →
                        (∀ (i : Nat),
                            use.position = Benitoite.Release.Refinement.ExternalPosition.argument i →
                              use.mode = Benitoite.Release.Refinement.ExternalMode.borrow) ∧
                          (use.position = Benitoite.Release.Refinement.ExternalPosition.result →
                              use.mode = Benitoite.Release.Refinement.ExternalMode.own) ∧
                            ∃ td,
                              P.externalType use.typeId = Option.some td ∧
                                td.component = d.component ∧ td.id = use.typeId ∧ td.arity = 0
```

### `ExternalSignatureLeaves.handle_arguments`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (td : Benitoite.Release.Refinement.ExternalTypeDecl),
  P.externalType td.id = Option.some td →
    td.arity = 0 →
      ∀ (identity : Nat),
        Benitoite.Release.Refinement.ExternalArgs P B Ψ
          (Benitoite.Release.Refinement.ExternalSignatureLeaves.handleSignature td.component "state" td.id) []
          [Benitoite.Release.Refinement.Val.externalHandle
              { typeId := td.id, component := td.component, resource := td.resource, identity := identity } []]
          (Benitoite.Release.Refinement.Ty.external td.id [])
          Benitoite.Release.Refinement.ExternalSignatureLeaves.stateEffect
```

### `ExternalSignatureLeaves.handle_call_typed`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (td : Benitoite.Release.Refinement.ExternalTypeDecl),
  P.externalType td.id = Option.some td →
    td.arity = 0 →
      ∀ (identity : Nat) (f : Benitoite.Release.Refinement.ExternalFunctionId),
        P.externalFunction f =
            Option.some
              (Benitoite.Release.Refinement.ExternalSignatureLeaves.handleSignature td.component "state" td.id) →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty [] [] [] Option.none
            (Benitoite.Release.Refinement.Comp.externalCall f []
              [Benitoite.Release.Refinement.Val.externalHandle
                  { typeId := td.id, component := td.component, resource := td.resource, identity := identity } []])
            (Benitoite.Release.Refinement.Ty.external td.id [])
            Benitoite.Release.Refinement.ExternalSignatureLeaves.stateEffect
```

### `ExternalSignatureLeaves.handle_typed_iff`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} (h : Benitoite.Release.Refinement.ExternalHandle)
  (td : Benitoite.Release.Refinement.ExternalTypeDecl),
  P.externalType h.typeId = Option.some td →
    td.arity = 0 →
      Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.external h.typeId []) →
        (Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalHandle h [])
            (Benitoite.Release.Refinement.Ty.external h.typeId []) ↔
          td.component = h.component ∧ td.resource = h.resource)
```

### `ExternalSignatureLeaves.mismatched_handle`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {h : Benitoite.Release.Refinement.ExternalHandle}
  {ts : List Benitoite.Release.Refinement.Ty} {T : Benitoite.Release.Refinement.Ty}
  {td : Benitoite.Release.Refinement.ExternalTypeDecl},
  P.externalType h.typeId = Option.some td →
    td.component ≠ h.component ∨ td.resource ≠ h.resource →
      ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalHandle h ts) T
```

### `ExternalSignatureLeaves.handle_not_source`（F03）

```lean
∀ (h : Benitoite.Release.Refinement.ExternalHandle) (ts : List Benitoite.Release.Refinement.Ty) (nr nt ne nv : Nat),
  ¬(Benitoite.Release.Refinement.Val.externalHandle h ts).Source ∧
    ¬Benitoite.Release.Refinement.Val.SourceScoped nr nt ne nv (Benitoite.Release.Refinement.Val.externalHandle h ts)
```

### `ExternalSignatureLeaves.non_binding_pattern_rejected`（F03）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (p : Benitoite.Release.Pat),
  p ≠ Benitoite.Release.Pat.wild →
    p ≠ Benitoite.Release.Pat.var →
      ∀ (id : Benitoite.Release.Refinement.ExternalId) (args δ : List Benitoite.Release.Refinement.Ty),
        ¬Benitoite.Release.Refinement.PatTy P p (Benitoite.Release.Refinement.Ty.external id args) δ
```

### `ExternalSignatureLeaves.constructor_value_rejected`（F03）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
  (C : Benitoite.Release.Refinement.TypeCtx) (Φ : List Benitoite.Release.Refinement.Pred)
  (c : Benitoite.Release.ConName) (ts : List Benitoite.Release.Refinement.Ty)
  (vs : List Benitoite.Release.Refinement.Val) (id : Benitoite.Release.Refinement.ExternalId)
  (args : List Benitoite.Release.Refinement.Ty),
  ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ (Benitoite.Release.Refinement.Val.con c ts vs)
      (Benitoite.Release.Refinement.Ty.external id args)
```

### `ExternalSignatureLeaves.handle_not_release`（F03）

```lean
∀ (h : Benitoite.Release.Refinement.ExternalHandle) (ts : List Benitoite.Release.Refinement.Ty)
  (isResource : Benitoite.Release.OpaqueName → Bool) (r : Option Benitoite.Release.ErrKind),
  ¬Benitoite.Release.Refinement.ResourceRelease.response isResource
      (Benitoite.Release.Refinement.Val.externalHandle h ts) r
```

### `ExternalSignatureLeaves.key_no_occurrence`（F03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {a : Benitoite.Release.Refinement.Ty}
  {path : List Benitoite.Release.Refinement.ExternalPathStep} {id : Benitoite.Release.Refinement.ExternalId},
  Benitoite.Release.Refinement.ExternalMapKey a → ¬Benitoite.Release.Refinement.ExternalOccurrence P a path id
```

### `ExternalSignatureLeaves.declarations_wf`（F03）

```lean
∀ (td : Benitoite.Release.Refinement.ExternalTypeDecl),
  td.arity = 0 →
    ∀ (pure state : Benitoite.Release.Refinement.ExternalFunctionId),
      pure ≠ state → (Benitoite.Release.Refinement.ExternalSignatureLeaves.declarations td pure state).ExternalWF
```

### `ExternalModel.response`（F04）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.ExternalFunctionId →
      List Benitoite.Release.Refinement.Ty →
        List Benitoite.Release.Refinement.Val →
          Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

### `ExternalModel.builtins`（F04）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    (Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop) → Benitoite.Release.Refinement.Builtins
```

### `ExternalModel.response_err`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (base : Benitoite.Release.Refinement.Builtins)
  (f : Benitoite.Release.Refinement.ExternalFunctionId) (ts : List Benitoite.Release.Refinement.Ty)
  (vs : List Benitoite.Release.Refinement.Val) (r : Benitoite.Release.ErrKind),
  Benitoite.Release.Refinement.ExternalModel.response P base f ts vs (Benitoite.Release.Refinement.Outcome.err r) []
```

### `ExternalModel.response_exists`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (base : Benitoite.Release.Refinement.Builtins)
  (f : Benitoite.Release.Refinement.ExternalFunctionId) (ts : List Benitoite.Release.Refinement.Ty)
  (vs : List Benitoite.Release.Refinement.Val),
  ∃ out obs, Benitoite.Release.Refinement.ExternalModel.response P base f ts vs out obs
```

### `ExternalModel.typing_fields`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (base : Benitoite.Release.Refinement.Builtins)
  (release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop),
  base.TypingFieldsEq (Benitoite.Release.Refinement.ExternalModel.builtins P base release)
```

### `ExternalModel.external_assumptions`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (base : Benitoite.Release.Refinement.Builtins)
  (release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop),
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P
    (Benitoite.Release.Refinement.ExternalModel.builtins P base release)
```

### `Builtins.selectExternal`（F04）

```lean
Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.ExternalOracle
```

### `Builtins.selectExternal_response`（F04）

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val},
  (∃ out obs, B.externalResponse f ts vs out obs) →
    B.externalResponse f ts vs (B.selectExternal f ts vs).fst (B.selectExternal f ts vs).snd
```

### `ExternalModel.response_value`（F04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {base : Benitoite.Release.Refinement.Builtins}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {d : Benitoite.Release.Refinement.ExternalSignature}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val},
  P.externalFunction f = Option.some d →
    d.instantiate ts vs = Option.some (a, e) →
      (∀ (Ψ : Benitoite.Release.Refinement.StoreTy), Benitoite.Release.Refinement.ExternalCarrier P base Ψ v a) →
        v.Ground →
          Benitoite.Release.Refinement.ExternalModel.response P base f ts vs
            (Benitoite.Release.Refinement.Outcome.val v) []
```

### `ExternalModel.receive_value`（F04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {base : Benitoite.Release.Refinement.Builtins}
  {release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target},
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      Benitoite.Release.Refinement.ExternalArgs P (Benitoite.Release.Refinement.ExternalModel.builtins P base release) Ψ
          d ts vs a e →
        Benitoite.Release.Refinement.ExternalModel.response P base f ts vs (Benitoite.Release.Refinement.Outcome.val v)
            obs →
          Benitoite.Release.Refinement.externalCheck P v a = Bool.true →
            ∀ (σ : Benitoite.Release.Refinement.PathEnv),
              Benitoite.Release.Refinement.externalReceive P d ts vs (Benitoite.Release.Refinement.Outcome.val v) =
                  Option.some (Benitoite.Release.Refinement.Outcome.val v) ∧
                Benitoite.Release.Refinement.HasTypeV P
                    (Benitoite.Release.Refinement.ExternalModel.builtins P base release) Ψ [] [] [] v a ∧
                  v.Ground ∧ Benitoite.Release.Refinement.Val.Adequate σ v
```

### `ExternalModel.receive_reject`（F04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {base : Benitoite.Release.Refinement.Builtins}
  {release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target},
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      Benitoite.Release.Refinement.ExternalArgs P (Benitoite.Release.Refinement.ExternalModel.builtins P base release) Ψ
          d ts vs a e →
        Benitoite.Release.Refinement.ExternalModel.response P base f ts vs (Benitoite.Release.Refinement.Outcome.val v)
            obs →
          Benitoite.Release.Refinement.externalCheck P v a = Bool.false →
            Benitoite.Release.Refinement.externalReceive P d ts vs (Benitoite.Release.Refinement.Outcome.val v) =
                Option.some (Benitoite.Release.Refinement.Outcome.err "ExternalRefinement") ∧
              (∀ (σ : Benitoite.Release.Refinement.PathEnv), Benitoite.Release.Refinement.Val.Adequate σ v) ∧ obs = []
```

### `ExternalModel.receive_error_no_exit`（F04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {base : Benitoite.Release.Refinement.Builtins}
  {release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ExternalArgs P (Benitoite.Release.Refinement.ExternalModel.builtins P base release) Ψ d
      ts vs a e →
    P.externalFunction f = Option.some d →
      ∀ (r : Benitoite.Release.ErrKind),
        Benitoite.Release.Refinement.ExternalModel.response P base f ts vs (Benitoite.Release.Refinement.Outcome.err r)
            [] ∧
          Benitoite.Release.Refinement.externalReceive P d ts vs (Benitoite.Release.Refinement.Outcome.err r) =
              Option.some (Benitoite.Release.Refinement.Outcome.err r) ∧
            ∀ (n : Int) (obs : List Benitoite.Scope.Domain.Target),
              ¬Benitoite.Release.Refinement.ExternalModel.response P base f ts vs
                  (Benitoite.Release.Refinement.Outcome.exit n) obs
```

### `ExternalModels.model`（F04）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins
```

### `ExternalModels.targets`（F04）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins
```

### `ExternalModels.http`（F04）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins
```

### `ExternalModels.model_core`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.CoreAssumptions P (Benitoite.Release.Refinement.ExternalModels.model P)
```

### `ExternalModels.targets_core`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.Builtins.CoreAssumptions P (Benitoite.Release.Refinement.ExternalModels.targets P)
```

### `ExternalModels.http_core`（F04）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.Builtins.CoreAssumptions P (Benitoite.Release.Refinement.ExternalModels.http P)
```

### `ExternalModels.conditions`（F04）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (P : Benitoite.Release.Refinement.Program),
  m.Declarations P →
    Benitoite.Release.Refinement.ModelScopeConditions P (m.table P) ∧
      Benitoite.Release.Refinement.Builtins.ExternalAssumptions P (m.table P)
```

### `ExternalModels.shape_inputs`（F04）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase)
  (s : Benitoite.Release.Refinement.ExternalModelExamples.Shape) (b : Bool) (Ψ : Benitoite.Release.Refinement.StoreTy),
  m.Declarations (Benitoite.Release.Refinement.ExternalModelExamples.program s b) ∧
    (Benitoite.Release.Refinement.ExternalModelExamples.program s b).ExternalWF ∧
      Benitoite.Release.Refinement.ExternalArgs (Benitoite.Release.Refinement.ExternalModelExamples.program s b)
          (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s b)) Ψ
          (Benitoite.Release.Refinement.ExternalModelExamples.signature s b) [] [] (s.type b)
          Benitoite.Release.Refinement.Eff.empty ∧
        (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s b)).externalResponse
            (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) [] []
            (Benitoite.Release.Refinement.Outcome.val (s.raw b)) [] ∧
          Benitoite.Release.Refinement.externalCheck (Benitoite.Release.Refinement.ExternalModelExamples.program s b)
              (s.raw b) (s.type b) =
            b
```

### `ExternalModels.handle_inputs`（F04）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (b : Bool) (Ψ : Benitoite.Release.Refinement.StoreTy)
  (identity : Nat),
  m.Declarations (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b) ∧
    (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b).ExternalWF ∧
      Benitoite.Release.Refinement.ExternalArgs (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)
          (m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)) Ψ
          (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature b) []
          [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
          (Benitoite.Release.Refinement.ExternalModelExamples.handleType b)
          Benitoite.Release.Refinement.ExternalSignatureLeaves.stateEffect ∧
        (m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)).externalResponse
            (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) []
            [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
            (Benitoite.Release.Refinement.Outcome.val
              (Benitoite.Release.Refinement.ExternalModelExamples.handle identity))
            [] ∧
          Benitoite.Release.Refinement.externalCheck
              (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)
              (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)
              (Benitoite.Release.Refinement.ExternalModelExamples.handleType b) =
            b
```

### `ExternalModels.responses`（F04）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (Ψ : Benitoite.Release.Refinement.StoreTy)
  (σ : Benitoite.Release.Refinement.PathEnv) (identity : Nat),
  (∀ (s : Benitoite.Release.Refinement.ExternalModelExamples.Shape),
      (∀ (b : Bool),
          Benitoite.Release.Refinement.ModelScopeConditions
              (Benitoite.Release.Refinement.ExternalModelExamples.program s b)
              (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s b)) ∧
            Benitoite.Release.Refinement.Builtins.ExternalAssumptions
              (Benitoite.Release.Refinement.ExternalModelExamples.program s b)
              (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s b))) ∧
        (Benitoite.Release.Refinement.externalReceive
                (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)
                (Benitoite.Release.Refinement.ExternalModelExamples.signature s Bool.true) [] []
                (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.true)) =
              Option.some (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.true)) ∧
            Benitoite.Release.Refinement.HasTypeV
                (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)
                (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)) Ψ [] [] []
                (s.raw Bool.true) (s.type Bool.true) ∧
              (s.raw Bool.true).Ground ∧ Benitoite.Release.Refinement.Val.Adequate σ (s.raw Bool.true)) ∧
          Benitoite.Release.Refinement.externalReceive
                (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.false)
                (Benitoite.Release.Refinement.ExternalModelExamples.signature s Bool.false) [] []
                (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.false)) =
              Option.some (Benitoite.Release.Refinement.Outcome.err "ExternalRefinement") ∧
            Benitoite.Release.Refinement.Val.Adequate σ (s.raw Bool.false)) ∧
    (∀ (b : Bool),
        Benitoite.Release.Refinement.ModelScopeConditions
            (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)
            (m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)) ∧
          Benitoite.Release.Refinement.Builtins.ExternalAssumptions
            (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)
            (m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b))) ∧
      (Benitoite.Release.Refinement.externalReceive
              (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.true)
              (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature Bool.true) []
              [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
              (Benitoite.Release.Refinement.Outcome.val
                (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) =
            Option.some
              (Benitoite.Release.Refinement.Outcome.val
                (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) ∧
          Benitoite.Release.Refinement.HasTypeV
              (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.true)
              (m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.true)) Ψ [] [] []
              (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)
              (Benitoite.Release.Refinement.ExternalModelExamples.handleType Bool.true) ∧
            (Benitoite.Release.Refinement.ExternalModelExamples.handle identity).Ground ∧
              Benitoite.Release.Refinement.Val.Adequate σ
                (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) ∧
        (Benitoite.Release.Refinement.externalReceive
                (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.false)
                (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature Bool.false) []
                [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
                (Benitoite.Release.Refinement.Outcome.val
                  (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) =
              Option.some (Benitoite.Release.Refinement.Outcome.err "ExternalRefinement") ∧
            Benitoite.Release.Refinement.Val.Adequate σ
              (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) ∧
          ∀ (b : Bool) (r : Benitoite.Release.ErrKind),
            (m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)).externalResponse
                (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) []
                [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
                (Benitoite.Release.Refinement.Outcome.err r) [] ∧
              Benitoite.Release.Refinement.externalReceive
                    (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)
                    (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature b) []
                    [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
                    (Benitoite.Release.Refinement.Outcome.err r) =
                  Option.some (Benitoite.Release.Refinement.Outcome.err r) ∧
                ∀ (n : Int) (obs : List Benitoite.Scope.Domain.Target),
                  ¬(m.table (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)).externalResponse
                      (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) []
                      [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
                      (Benitoite.Release.Refinement.Outcome.exit n) obs
```

### `ExternalModels.model_no_response_kind`（F04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig},
  (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure ∧
      s.kind ≠ Benitoite.Release.Refinement.PrimKind.io ∧ s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit
```

### `ExternalModelExamples.receive_pair`（F04）

```lean
∀ (s : Benitoite.Release.Refinement.ExternalModelExamples.Shape) (base : Benitoite.Release.Refinement.Builtins),
  (∀ (b : Bool),
      base.sat []
        (Benitoite.Release.Refinement.ExternalModelExamples.filtered
            (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer) b).norm
        Benitoite.Release.TParam.keyC) →
    ∀ (release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop)
      (Ψ : Benitoite.Release.Refinement.StoreTy) (σ : Benitoite.Release.Refinement.PathEnv),
      (Benitoite.Release.Refinement.externalReceive
              (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)
              (Benitoite.Release.Refinement.ExternalModelExamples.signature s Bool.true) [] []
              (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.true)) =
            Option.some (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.true)) ∧
          Benitoite.Release.Refinement.HasTypeV (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)
              (Benitoite.Release.Refinement.ExternalModel.builtins
                (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true) base release)
              Ψ [] [] [] (s.raw Bool.true) (s.type Bool.true) ∧
            (s.raw Bool.true).Ground ∧ Benitoite.Release.Refinement.Val.Adequate σ (s.raw Bool.true)) ∧
        Benitoite.Release.Refinement.externalReceive
              (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.false)
              (Benitoite.Release.Refinement.ExternalModelExamples.signature s Bool.false) [] []
              (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.false)) =
            Option.some (Benitoite.Release.Refinement.Outcome.err "ExternalRefinement") ∧
          Benitoite.Release.Refinement.Val.Adequate σ (s.raw Bool.false)
```

### `ExternalModelExamples.handle_receive_pair`（F04）

```lean
∀ (base : Benitoite.Release.Refinement.Builtins)
  (release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (σ : Benitoite.Release.Refinement.PathEnv) (identity : Nat),
  (Benitoite.Release.Refinement.externalReceive
          (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.true)
          (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature Bool.true) []
          [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
          (Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) =
        Option.some
          (Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) ∧
      Benitoite.Release.Refinement.HasTypeV (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.true)
          (Benitoite.Release.Refinement.ExternalModel.builtins
            (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.true) base release)
          Ψ [] [] [] (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)
          (Benitoite.Release.Refinement.ExternalModelExamples.handleType Bool.true) ∧
        (Benitoite.Release.Refinement.ExternalModelExamples.handle identity).Ground ∧
          Benitoite.Release.Refinement.Val.Adequate σ
            (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) ∧
    (Benitoite.Release.Refinement.externalReceive
            (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram Bool.false)
            (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature Bool.false) []
            [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
            (Benitoite.Release.Refinement.Outcome.val
              (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) =
          Option.some (Benitoite.Release.Refinement.Outcome.err "ExternalRefinement") ∧
        Benitoite.Release.Refinement.Val.Adequate σ
          (Benitoite.Release.Refinement.ExternalModelExamples.handle identity)) ∧
      ∀ (b : Bool) (r : Benitoite.Release.ErrKind),
        (Benitoite.Release.Refinement.ExternalModel.builtins
                (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b) base release).externalResponse
            (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) []
            [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
            (Benitoite.Release.Refinement.Outcome.err r) [] ∧
          Benitoite.Release.Refinement.externalReceive
                (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b)
                (Benitoite.Release.Refinement.ExternalModelExamples.handleSignature b) []
                [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
                (Benitoite.Release.Refinement.Outcome.err r) =
              Option.some (Benitoite.Release.Refinement.Outcome.err r) ∧
            ∀ (n : Int) (obs : List Benitoite.Scope.Domain.Target),
              ¬(Benitoite.Release.Refinement.ExternalModel.builtins
                      (Benitoite.Release.Refinement.ExternalModelExamples.handleProgram b) base
                      release).externalResponse
                  (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) []
                  [Benitoite.Release.Refinement.ExternalModelExamples.handle identity]
                  (Benitoite.Release.Refinement.Outcome.exit n) obs
```

### `ExternalModelExamples.positive_receive_pair`（F04）

```lean
∀ (base : Benitoite.Release.Refinement.Builtins)
  (release : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram.ExternalWF ∧
    Benitoite.Release.Refinement.ExternalArgs Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram
        (Benitoite.Release.Refinement.ExternalModel.builtins
          Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram base release)
        Ψ Benitoite.Release.Refinement.ExternalModelExamples.positiveSignature [] []
        Benitoite.Release.Refinement.ExternalModelExamples.positiveType Benitoite.Release.Refinement.Eff.empty ∧
      (Benitoite.Release.Refinement.ExternalModel.builtins
              Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram base release).externalResponse
          (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) [] []
          (Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.Val.const
              (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩)))
          [] ∧
        (Benitoite.Release.Refinement.ExternalModel.builtins
                Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram base release).externalResponse
            (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) [] []
            (Benitoite.Release.Refinement.Outcome.val
              (Benitoite.Release.Refinement.Val.const
                (Benitoite.Release.Refinement.Const.integer ⟨0, of_decide_eq_true (id (Eq.refl Bool.true))⟩)))
            [] ∧
          (Benitoite.Release.Refinement.externalReceive
                  Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram
                  Benitoite.Release.Refinement.ExternalModelExamples.positiveSignature [] []
                  (Benitoite.Release.Refinement.Outcome.val
                    (Benitoite.Release.Refinement.Val.const
                      (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩))) =
                Option.some
                  (Benitoite.Release.Refinement.Outcome.val
                    (Benitoite.Release.Refinement.Val.const
                      (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩))) ∧
              Benitoite.Release.Refinement.HasTypeV Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram
                  (Benitoite.Release.Refinement.ExternalModel.builtins
                    Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram base release)
                  Ψ [] [] []
                  (Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩))
                  Benitoite.Release.Refinement.ExternalModelExamples.positiveType ∧
                (Benitoite.Release.Refinement.Val.const
                      (Benitoite.Release.Refinement.Const.integer
                        ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩)).Ground ∧
                  Benitoite.Release.Refinement.Val.Adequate σ
                    (Benitoite.Release.Refinement.Val.const
                      (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩))) ∧
            Benitoite.Release.Refinement.externalReceive
                  Benitoite.Release.Refinement.ExternalModelExamples.positiveProgram
                  Benitoite.Release.Refinement.ExternalModelExamples.positiveSignature [] []
                  (Benitoite.Release.Refinement.Outcome.val
                    (Benitoite.Release.Refinement.Val.const
                      (Benitoite.Release.Refinement.Const.integer ⟨0, of_decide_eq_true (id (Eq.refl Bool.true))⟩))) =
                Option.some (Benitoite.Release.Refinement.Outcome.err "ExternalRefinement") ∧
              Benitoite.Release.Refinement.Val.Adequate σ
                (Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.Const.integer ⟨0, of_decide_eq_true (id (Eq.refl Bool.true))⟩))
```

### `StateTyE.external_args`（F05）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
            ∃ Ψ d a e,
              P.externalFunction f = Option.some d ∧ Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts ws a e
```

### `StateTyE.external_receive`（F05）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {out : Benitoite.Release.Refinement.Outcome} {obs : List Benitoite.Scope.Domain.Target},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
            B.externalResponse f ts ws out obs →
              ∃ d c,
                P.externalFunction f = Option.some d ∧
                  Benitoite.Release.Refinement.externalReceive P d ts ws out = Option.some c ∧
                    (∀ (n : Int), c ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧ obs = []
```

### `StateTyE.external_step_of_response`（F05）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {out : Benitoite.Release.Refinement.Outcome} {obs : List Benitoite.Scope.Domain.Target},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
            B.externalResponse f ts ws out obs →
              ∃ d dest,
                P.externalFunction f = Option.some d ∧
                  ((∃ v,
                        Benitoite.Release.Refinement.externalReceive P d ts ws out =
                            Option.some (Benitoite.Release.Refinement.Outcome.val v) ∧
                          dest =
                            Benitoite.Release.Refinement.State.run
                              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k
                              μ) ∨
                      ∃ r,
                        Benitoite.Release.Refinement.externalReceive P d ts ws out =
                            Option.some (Benitoite.Release.Refinement.Outcome.err r) ∧
                          dest = Benitoite.Release.Refinement.State.error [r] k μ) ∧
                    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                        dest ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb dest
```

### `StateTyE.external_response_step`（F05）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {ws : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
            ∃ out obs dest,
              B.externalResponse f ts ws out obs ∧
                obs = [] ∧
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                      dest ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb dest
```

### `step_external_selected`（F05）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {oracle : Benitoite.Release.Refinement.Oracle}
  {rel : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
            B.externalResponse f ts ws (B.selectExternal f ts ws).fst (B.selectExternal f ts ws).snd ∧
              (B.selectExternal f ts ws).snd = [] ∧
                ∃ dest,
                  Benitoite.Release.Refinement.step P B σ oracle B.selectExternal rel fresh
                        (Benitoite.Release.Refinement.State.run q k μ) =
                      Option.some (Option.none, dest) ∧
                    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                        dest ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb dest
```

### `step_external_apply`（F05）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {oracle : Benitoite.Release.Refinement.Oracle} {externalOracle : Benitoite.Release.Refinement.ExternalOracle}
  {rel : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) ws →
            Benitoite.Release.Refinement.step P B σ oracle externalOracle rel fresh
                  (Benitoite.Release.Refinement.State.run q k μ) =
                Option.some
                  (Option.none,
                    Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure
                        (Benitoite.Release.Refinement.Comp.externalCall f ts ws))
                      k μ) ∧
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts ws))
                    k μ) ∧
                Benitoite.Release.Refinement.StateTyE P B σ Eb
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts ws))
                    k μ)
```

### `ResourceRelease.response`（F06）

```lean
(Benitoite.Release.OpaqueName → Bool) → Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind → Prop
```

### `ResourceRelease.canonical`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
      (Benitoite.Release.Refinement.Ty.opaque o
        (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
    B.valKind o = Option.none →
      ∃ i, v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o i)
```

### `ResourceRelease.typed_response`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName},
  (∀ (name : Benitoite.Release.OpaqueName), B.isResource name = Bool.true → B.valKind name = Option.none) →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v
        (Benitoite.Release.Refinement.Ty.opaque o
          (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
      B.isResource o = Bool.true →
        ∀ (r : Option Benitoite.Release.ErrKind), Benitoite.Release.Refinement.ResourceRelease.response B.isResource v r
```

### `ResourceRelease.targets_classification`（F06）

```lean
∀ (o : Benitoite.Release.OpaqueName),
  Benitoite.Release.Refinement.ModelTargets.builtins.isResource o = Bool.true →
    Benitoite.Release.Refinement.ModelTargets.builtins.valKind o = Option.none
```

### `ResourceRelease.Table`（F06）

```lean
Benitoite.Release.Refinement.Builtins → Prop
```

### `ResourceRelease.Table.release_all`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
        (Benitoite.Release.Refinement.Ty.opaque o
          (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
      B.isResource o = Bool.true → ∀ (r : Option Benitoite.Release.ErrKind), B.releaseResponse v r
```

### `ResourceRelease.Table.release_value`（F06）

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {v : Benitoite.Release.Refinement.Val}
  {r : Option Benitoite.Release.ErrKind},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    B.releaseResponse v r →
      ∃ o i,
        v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o i) ∧
          B.isResource o = Bool.true
```

### `ContTy.release_resource`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {k : List Benitoite.Release.Refinement.Frame} {a b : Benitoite.Release.Refinement.Ty}
  {Eb : Benitoite.Release.Refinement.Eff} {Re : Option Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.ContTy P B σ Ψ R e (Benitoite.Release.Refinement.Frame.release v :: k) a b Eb Re →
    ∃ o,
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
          (Benitoite.Release.Refinement.Ty.opaque o
            (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) ∧
        B.isResource o = Bool.true
```

### `ContTy.release_not_external`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {k : List Benitoite.Release.Refinement.Frame} {a b : Benitoite.Release.Refinement.Ty}
  {Eb : Benitoite.Release.Refinement.Eff} {Re : Option Benitoite.Release.Refinement.Ty}
  {h : Benitoite.Release.Refinement.ExternalHandle} {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    Benitoite.Release.Refinement.ContTy P B σ Ψ R e
        (Benitoite.Release.Refinement.Frame.release (Benitoite.Release.Refinement.Val.externalHandle h ts) :: k) a b Eb
        Re →
      False
```

### `StateTyE.release_return_all`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {w v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.ResourceRelease.Table B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb
              (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
            q.view = Benitoite.Release.Refinement.Comp.ret w →
              (Benitoite.Release.Refinement.Step P B σ
                    (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                    (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret w)) k μ) ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret w)) k μ)) ∧
                ∀ (r : Benitoite.Release.ErrKind),
                  Benitoite.Release.Refinement.Step P B σ
                      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                      (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
                      (Benitoite.Release.Refinement.State.error [r] k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error [r] k μ)
```

### `StateTyE.release_escape_all`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {w v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.ResourceRelease.Table B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb
              (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
            q.view = Benitoite.Release.Refinement.Comp.escape w →
              (Benitoite.Release.Refinement.Step P B σ
                    (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                    (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape w)) k μ) ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.escape w)) k μ)) ∧
                ∀ (r : Benitoite.Release.ErrKind),
                  Benitoite.Release.Refinement.Step P B σ
                      (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                      (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
                      (Benitoite.Release.Refinement.State.error [r] k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error [r] k μ)
```

### `StateTyE.release_error_all`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.ErrKind} {v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    Benitoite.Release.Refinement.StateTyE P B σ Eb
        (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
      (Benitoite.Release.Refinement.Step P B σ
            (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
            (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
            (Benitoite.Release.Refinement.State.error rs k μ) ∧
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error rs k μ)) ∧
        ∀ (r : Benitoite.Release.ErrKind),
          Benitoite.Release.Refinement.Step P B σ
              (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
              (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
              (Benitoite.Release.Refinement.State.error (rs ++ [r]) k μ) ∧
            Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error (rs ++ [r]) k μ)
```

### `StateTyE.release_exit_all`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff} {n : Int}
  {rs : List Benitoite.Release.ErrKind} {v : Benitoite.Release.Refinement.Val}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    Benitoite.Release.Refinement.StateTyE P B σ Eb
        (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
      (Benitoite.Release.Refinement.Step P B σ
            (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
            (Option.some (Benitoite.Release.Refinement.Event.release v Option.none))
            (Benitoite.Release.Refinement.State.exit n rs k μ) ∧
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.exit n rs k μ)) ∧
        ∀ (r : Benitoite.Release.ErrKind),
          Benitoite.Release.Refinement.Step P B σ
              (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
              (Option.some (Benitoite.Release.Refinement.Event.release v (Option.some r)))
              (Benitoite.Release.Refinement.State.exit n (rs ++ [r]) k μ) ∧
            Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.exit n (rs ++ [r]) k μ)
```

### `StateTyE.use_release_all`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {v : Benitoite.Release.Refinement.Val}
  {m : Benitoite.Release.Refinement.Comp} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.ResourceRelease.Table B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
            q.view = Benitoite.Release.Refinement.Comp.use v m →
              (Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                    (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture m)
                      (Benitoite.Release.Refinement.Frame.release v :: k) μ) ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb
                    (Benitoite.Release.Refinement.State.run (Benitoite.Release.Refinement.Closure.mk q.capture m)
                      (Benitoite.Release.Refinement.Frame.release v :: k) μ)) ∧
                ∀ (r : Option Benitoite.Release.ErrKind), B.releaseResponse v r
```

### `StateTyE.release_selected_run`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {oracle : Benitoite.Release.Refinement.Oracle} {externalOracle : Benitoite.Release.Refinement.ExternalOracle}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {q : Benitoite.Release.Refinement.Closure}
  {w v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {escape : Bool},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.ResourceRelease.Table B →
          Benitoite.Release.Refinement.StateTyE P B σ Eb
              (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
            (q.view =
                if escape = Bool.true then Benitoite.Release.Refinement.Comp.escape w
                else Benitoite.Release.Refinement.Comp.ret w) →
              B.releaseResponse v (B.selectRelease v) ∧
                ∃ dest,
                  Benitoite.Release.Refinement.step P B σ oracle externalOracle B.selectRelease fresh
                        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k)
                          μ) =
                      Option.some
                        (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v)), dest) ∧
                    Benitoite.Release.Refinement.Step P B σ
                        (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                        (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v))) dest ∧
                      Benitoite.Release.Refinement.StateTyE P B σ Eb dest
```

### `StateTyE.release_selected_error`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {oracle : Benitoite.Release.Refinement.Oracle} {externalOracle : Benitoite.Release.Refinement.ExternalOracle}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    Benitoite.Release.Refinement.StateTyE P B σ Eb
        (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
      B.releaseResponse v (B.selectRelease v) ∧
        ∃ dest,
          Benitoite.Release.Refinement.step P B σ oracle externalOracle B.selectRelease fresh
                (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ) =
              Option.some (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v)), dest) ∧
            Benitoite.Release.Refinement.Step P B σ
                (Benitoite.Release.Refinement.State.error rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v))) dest ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb dest
```

### `StateTyE.release_selected_exit`（F06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {oracle : Benitoite.Release.Refinement.Oracle} {externalOracle : Benitoite.Release.Refinement.ExternalOracle}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {n : Int} {rs : List Benitoite.Release.ErrKind}
  {v : Benitoite.Release.Refinement.Val} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.ResourceRelease.Table B →
    Benitoite.Release.Refinement.StateTyE P B σ Eb
        (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ) →
      B.releaseResponse v (B.selectRelease v) ∧
        ∃ dest,
          Benitoite.Release.Refinement.step P B σ oracle externalOracle B.selectRelease fresh
                (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ) =
              Option.some (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v)), dest) ∧
            Benitoite.Release.Refinement.Step P B σ
                (Benitoite.Release.Refinement.State.exit n rs (Benitoite.Release.Refinement.Frame.release v :: k) μ)
                (Option.some (Benitoite.Release.Refinement.Event.release v (B.selectRelease v))) dest ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb dest
```

### `ExternalModels.ModelCase.release_all`（F06）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (P : Benitoite.Release.Refinement.Program)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val) (o : Benitoite.Release.OpaqueName),
  Benitoite.Release.Refinement.HasTypeV P (m.table P) Ψ [] [] [] v
      (Benitoite.Release.Refinement.Ty.opaque o
        (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
    (m.table P).isResource o = Bool.true → ∀ (r : Option Benitoite.Release.ErrKind), (m.table P).releaseResponse v r
```

### `ExternalModels.ModelCase.resource_table`（F06）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ResourceRelease.Table (m.table P)
```

