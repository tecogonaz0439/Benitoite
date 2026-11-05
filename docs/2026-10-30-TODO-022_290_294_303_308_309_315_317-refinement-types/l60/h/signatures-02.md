# 段末の実署名（2/3）

生成物（[audit.py](audit.py)）。段の公理監査（[../axioms.lean](../axioms.lean)）の型の印字であり、接頭辞 `Benitoite.Release.Refinement.` を見出しでだけ省く。

### `ExternalModels.ModelCase.release_premise_false`（F06）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase),
  m ≠ Benitoite.Release.Refinement.ExternalModels.ModelCase.targets →
    ∀ (P : Benitoite.Release.Refinement.Program) (o : Benitoite.Release.OpaqueName),
      (m.table P).isResource o ≠ Bool.true
```

### `ExternalModels.targets_resource_input`（F06）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy) (i : Nat),
  Benitoite.Release.Refinement.HasTypeV P (Benitoite.Release.Refinement.ExternalModels.targets P) Ψ [] [] []
      (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque "File.Handle" i))
      (Benitoite.Release.Refinement.Ty.opaque "File.Handle"
        (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) ∧
    (Benitoite.Release.Refinement.ExternalModels.targets P).isResource "File.Handle" = Bool.true
```

### `FunctionNames.rename`（F07）

```lean
Bool → String → String
```

### `FunctionNames.collisionNames`（F07）

```lean
List String
```

### `StandardModel.Body.all`（F07）

```lean
List Benitoite.Release.Refinement.StandardModel.Body
```

### `StandardModel.Body.definition`（F07）

```lean
Benitoite.Release.Refinement.StandardModel.Body → Benitoite.Release.Refinement.Def
```

### `StandardModel.Primitive.all`（F07）

```lean
List Benitoite.Release.Refinement.StandardModel.Primitive
```

### `StandardModel.program`（F07）

```lean
List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl) →
  Benitoite.Release.Refinement.Program
```

### `StandardModel.builtins`（F07）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins
```

### `StandardModel.body_lookup`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (body : Benitoite.Release.Refinement.StandardModel.Body),
  (Benitoite.Release.Refinement.StandardModel.program externals).defs body.key = Option.some body.definition
```

### `StandardModel.lookup_body`（F07）

```lean
∀ {externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)}
  {f : Benitoite.Release.FunName} {d : Benitoite.Release.Refinement.Def},
  (Benitoite.Release.Refinement.StandardModel.program externals).defs f = Option.some d →
    ∃ body, body ∈ Benitoite.Release.Refinement.StandardModel.Body.all ∧ f = body.key ∧ d = body.definition
```

### `StandardModel.definitions_iff`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)) (f : String)
  (d : Benitoite.Release.Refinement.Def),
  (Benitoite.Release.Refinement.StandardModel.program externals).defs f = Option.some d ↔
    ∃ body, body ∈ Benitoite.Release.Refinement.StandardModel.Body.all ∧ f = body.key ∧ d = body.definition
```

### `StandardModel.builtins_lookup_iff`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (name : String) (s : Benitoite.Release.Refinement.PrimSig),
  (Benitoite.Release.Refinement.StandardModel.builtins P).sig name = Option.some s ↔
    ∃ row, row ∈ Benitoite.Release.Refinement.StandardModel.Primitive.all ∧ name = row.name ∧ s = row.signature
```

### `StandardModel.row_lookup`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  (Benitoite.Release.Refinement.StandardModel.builtins P).sig row.name = Option.some row.signature
```

### `StandardModel.PureRow`（F07）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.PrimName → Prop
```

### `StandardModel.PureRow.Satisfiable`（F07）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.PrimName → Prop
```

### `StandardModel.IORow.Satisfiable`（F07）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.PrimName → Prop
```

### `StandardModel.first_sixteen`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (entry : Benitoite.Release.Refinement.StandardOperatorResponse.Entry),
  entry ∈ List.take 16 Benitoite.Release.Refinement.StandardOperatorResponse.entries →
    Benitoite.Release.Refinement.StandardModel.PureRow P entry.name
```

### `StandardModel.numeric_rows`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.numeric = Bool.true →
    Benitoite.Release.Refinement.StandardModel.PureRow (Benitoite.Release.Refinement.StandardModel.program externals)
      row.name
```

### `StandardModel.operator_rows`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.operator = Bool.true → Benitoite.Release.Refinement.StandardModel.PureRow P row.name
```

### `StandardModel.collection_rows`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.collection = Bool.true →
    Benitoite.Release.Refinement.StandardModel.PureRow (Benitoite.Release.Refinement.StandardModel.program externals)
      row.name
```

### `StandardModel.scope_rows`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.scopePure = Bool.true →
    Benitoite.Release.Refinement.StandardModel.PureRow (Benitoite.Release.Refinement.StandardModel.program externals)
      row.name
```

### `StandardModel.pure_rows`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.signature.kind = Benitoite.Release.Refinement.PrimKind.pure →
    Benitoite.Release.Refinement.StandardModel.PureRow (Benitoite.Release.Refinement.StandardModel.program externals)
      row.name
```

### `StandardModel.io_rows`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.io = Bool.true →
    Benitoite.Release.Refinement.StandardModel.IORow (Benitoite.Release.Refinement.StandardModel.program externals)
      row.name
```

### `StandardModel.body_typed`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (body : Benitoite.Release.Refinement.StandardModel.Body),
  Benitoite.Release.Refinement.Def.WellTyped (Benitoite.Release.Refinement.StandardModel.program externals)
    (Benitoite.Release.Refinement.StandardModel.builtins (Benitoite.Release.Refinement.StandardModel.program externals))
    body.definition
```

### `StandardModel.definition_typed`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (f : Benitoite.Release.FunName) (d : Benitoite.Release.Refinement.Def),
  (Benitoite.Release.Refinement.StandardModel.program externals).defs f = Option.some d →
    Benitoite.Release.Refinement.Def.WellTyped (Benitoite.Release.Refinement.StandardModel.program externals)
      (Benitoite.Release.Refinement.StandardModel.builtins
        (Benitoite.Release.Refinement.StandardModel.program externals))
      d
```

### `StandardModel.program_typed`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  (Benitoite.Release.Refinement.StandardModel.program externals).ExternalWF →
    (Benitoite.Release.Refinement.StandardModel.program externals).WellTyped
      (Benitoite.Release.Refinement.StandardModel.builtins
        (Benitoite.Release.Refinement.StandardModel.program externals))
```

### `StandardModel.body_scoped`（F07）

```lean
∀ (body : Benitoite.Release.Refinement.StandardModel.Body),
  Benitoite.Release.Refinement.StandardModel.BodyScoped body.definition
```

### `StandardModel.cons_scoped`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (c : Benitoite.Release.ConName) (cd : Benitoite.Release.Refinement.ConDecl),
  (Benitoite.Release.Refinement.StandardModel.program externals).cons c = Option.some cd →
    (Benitoite.Release.Refinement.StandardModel.program externals).DataArity cd.data cd.ntys ∧
      Benitoite.Release.Refinement.ConDecl.Scoped (Benitoite.Release.Refinement.StandardModel.program externals) cd
```

### `StandardModel.program_wellFormed`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  (Benitoite.Release.Refinement.StandardModel.program externals).ExternalWF →
    (Benitoite.Release.Refinement.StandardModel.program externals).WellFormed
```

### `StandardModel.sig_scoped`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
  (Benitoite.Release.Refinement.StandardModel.builtins
            (Benitoite.Release.Refinement.StandardModel.program externals)).sig
        b =
      Option.some s →
    Benitoite.Release.Refinement.PrimSig.Scoped (Benitoite.Release.Refinement.StandardModel.program externals) s
```

### `StandardModel.substitution_assumptions`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P
    (Benitoite.Release.Refinement.StandardModel.builtins P)
```

### `StandardModel.external_assumptions`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P (Benitoite.Release.Refinement.StandardModel.builtins P)
```

### `StandardModel.response_assumptions`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions
    (Benitoite.Release.Refinement.StandardModel.program externals)
    (Benitoite.Release.Refinement.StandardModel.builtins (Benitoite.Release.Refinement.StandardModel.program externals))
```

### `StandardModel.release_exists`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy)
  (v : Benitoite.Release.Refinement.Val) (o : Benitoite.Release.OpaqueName),
  Benitoite.Release.Refinement.HasTypeV P (Benitoite.Release.Refinement.StandardModel.builtins P) Ψ [] [] [] v
      (Benitoite.Release.Refinement.Ty.opaque o
        (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
    (Benitoite.Release.Refinement.StandardModel.builtins P).isResource o = Bool.true →
      ∃ r, (Benitoite.Release.Refinement.StandardModel.builtins P).releaseResponse v r
```

### `StandardModel.resource_table`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ResourceRelease.Table (Benitoite.Release.Refinement.StandardModel.builtins P)
```

### `StandardModel.store_shape`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (s : Benitoite.Release.Refinement.PrimSig),
  (Benitoite.Release.Refinement.StandardModel.builtins P).sig b = Option.some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
```

### `StandardModel.ref_get`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  ∃ s,
    (Benitoite.Release.Refinement.StandardModel.builtins P).sig
          (Benitoite.Release.Refinement.StandardModel.builtins P).refGet =
        Option.some s ∧
      s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

### `StandardModel.ref_set`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  ∃ s,
    (Benitoite.Release.Refinement.StandardModel.builtins P).sig
          (Benitoite.Release.Refinement.StandardModel.builtins P).refSet =
        Option.some s ∧
      s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

### `StandardModel.reference_rows`（F07）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig},
  (Benitoite.Release.Refinement.StandardModel.builtins P).sig b = Option.some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.refNew ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.refGet ∨
          s.kind = Benitoite.Release.Refinement.PrimKind.refSet ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.refUpdate ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.force →
      s.StoreShape ∧
        List.map Benitoite.Release.Refinement.TParamDecl.kind s.tparams = [Benitoite.Release.Refinement.TyKind.value] ∧
          Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < s.neffs) s.tel ∧ s.opEff = Option.none
```

### `StandardModel.store_transitions`（F07）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig},
  (Benitoite.Release.Refinement.StandardModel.builtins P).sig b = Option.some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.refNew ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.refUpdate ∨
          s.kind = Benitoite.Release.Refinement.PrimKind.force →
      b = "Reference.new" ∧ s = Benitoite.Release.Refinement.StandardModel.refNewSig ∨
        b = "Reference.update" ∧ s = Benitoite.Release.Refinement.StandardModel.refUpdateSig ∨
          b = "Lazy.force" ∧ s = Benitoite.Release.Refinement.StandardModel.forceSig
```

### `StandardModel.core`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  Benitoite.Release.Refinement.Builtins.CoreAssumptions (Benitoite.Release.Refinement.StandardModel.program externals)
    (Benitoite.Release.Refinement.StandardModel.builtins (Benitoite.Release.Refinement.StandardModel.program externals))
```

### `StandardModel.targets`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  Benitoite.Release.Refinement.Builtins.TargetAgreement (Benitoite.Release.Refinement.StandardModel.program externals)
    (Benitoite.Release.Refinement.StandardModel.builtins (Benitoite.Release.Refinement.StandardModel.program externals))
```

### `StandardModel.numeric_inputs`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.numeric = Bool.true →
    Benitoite.Release.Refinement.StandardModel.PureRow.Satisfiable
      (Benitoite.Release.Refinement.StandardModel.program externals) row.name
```

### `StandardModel.operator_inputs`（F07）

```lean
∀ (P : Benitoite.Release.Refinement.Program) (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.operator = Bool.true → Benitoite.Release.Refinement.StandardModel.PureRow.Satisfiable P row.name
```

### `StandardModel.collection_inputs`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  (Benitoite.Release.Refinement.StandardModel.program externals).ExternalWF →
    ∀ (row : Benitoite.Release.Refinement.StandardModel.Primitive),
      row.collection = Bool.true →
        Benitoite.Release.Refinement.StandardModel.PureRow.Satisfiable
          (Benitoite.Release.Refinement.StandardModel.program externals) row.name
```

### `StandardModel.scope_inputs`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.scopePure = Bool.true →
    Benitoite.Release.Refinement.StandardModel.PureRow.Satisfiable
      (Benitoite.Release.Refinement.StandardModel.program externals) row.name
```

### `StandardModel.io_inputs`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl))
  (row : Benitoite.Release.Refinement.StandardModel.Primitive),
  row.io = Bool.true →
    Benitoite.Release.Refinement.StandardModel.IORow.Satisfiable
      (Benitoite.Release.Refinement.StandardModel.program externals) row.name
```

### `StandardModel.substitution_inputs`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  have P := Benitoite.Release.Refinement.StandardModel.program externals;
  have B := Benitoite.Release.Refinement.StandardModel.builtins P;
  (∃ C Γ Δ a p ξ,
      (∀ (i j : Nat), i < j → ξ i < ξ j) ∧
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a ∧
          Benitoite.Release.Refinement.Ty.Annotation P C Δ (Benitoite.Release.Refinement.renameTy ξ a) ∧
            B.sat C.constraints a p) ∧
    (∃ b sg C Γ Δ ts ξ,
        B.sig b = Option.some sg ∧
          (∀ (i j : Nat), i < j → ξ i < ξ j) ∧
            Benitoite.Release.Refinement.TypeAnnotations P C Γ ts ∧
              Benitoite.Release.Refinement.TypeAnnotations P C Δ
                  (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) ∧
                sg.admits C.constraints ts) ∧
      (∃ Ψ Q C Γ Δ Ξ ν a p,
          Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Ξ ν ∧
            Benitoite.Release.Refinement.Ty.Annotation P C Γ a ∧ B.sat C.constraints a p) ∧
        (∃ b sg Ψ Q C Γ Δ Ξ ν ts,
            B.sig b = Option.some sg ∧
              Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Ξ ν ∧
                Benitoite.Release.Refinement.TypeAnnotations P C Γ ts ∧ sg.admits C.constraints ts) ∧
          (∃ C C' Γ Δ a p ρ,
              Benitoite.Release.Refinement.TypeParamRenaming C C' ρ ∧
                Benitoite.Release.Refinement.Ty.Annotation P C Γ a ∧
                  Benitoite.Release.Refinement.Ty.Annotation P C' Δ (a.renameTypes ρ) ∧ B.sat C.constraints a p) ∧
            (∃ b sg C C' Γ Δ ts ρ,
                B.sig b = Option.some sg ∧
                  Benitoite.Release.Refinement.TypeParamRenaming C C' ρ ∧
                    Benitoite.Release.Refinement.TypeAnnotations P C Γ ts ∧
                      Benitoite.Release.Refinement.TypeAnnotations P C' Δ (List.map (fun a => a.renameTypes ρ) ts) ∧
                        sg.admits C.constraints ts) ∧
              (∃ C0 C1 a p ts,
                  B.sat (C1 ++ C0).constraints a p ∧
                    (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) ∧
                      Benitoite.Release.Refinement.SatAll B C1 ts C0.constraints ∧ ts.length = List.length C0) ∧
                ∃ b sg C0 C1 ts ts',
                  B.sig b = Option.some sg ∧
                    sg.admits (C1 ++ C0).constraints ts ∧
                      (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts' → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) ∧
                        Benitoite.Release.Refinement.SatAll B C1 ts' C0.constraints ∧ ts'.length = List.length C0
```

### `StandardModel.admits_sat_input`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  (∃ b s C ts,
      (Benitoite.Release.Refinement.StandardModel.builtins
                (Benitoite.Release.Refinement.StandardModel.program externals)).sig
            b =
          Option.some s ∧
        s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts)) ∧
    ¬(Benitoite.Release.Refinement.StandardModel.builtins
            (Benitoite.Release.Refinement.StandardModel.program externals)).sat
        [] (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.float) Benitoite.Release.TParam.keyC
```

### `StandardModel.positive_inputs`（F07）

```lean
have P :=
  Benitoite.Release.Refinement.StandardModel.program Benitoite.Release.Refinement.StandardModel.positiveExternals;
have B := Benitoite.Release.Refinement.StandardModel.builtins P;
(∃ Ψ f d ts vs a e out obs,
    P.ExternalWF ∧
      P.externalFunction f = Option.some d ∧
        Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e ∧
          B.externalResponse f ts vs out obs ∧ ∃ v, out = Benitoite.Release.Refinement.Outcome.val v) ∧
  B.externalResponse (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) [] []
      (Benitoite.Release.Refinement.Outcome.err "ExternalError") [] ∧
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy),
      Benitoite.Release.Refinement.Outcome.Carrier P B Ψ
        (Benitoite.Release.Refinement.Outcome.val
          (Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.Const.integer ⟨1, of_decide_eq_true (id (Eq.refl Bool.true))⟩)))
        Benitoite.Release.Refinement.ExternalModelExamples.positiveType
```

### `StandardModel.io_field_inputs`（F07）

```lean
∀ (externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)),
  have P := Benitoite.Release.Refinement.StandardModel.program externals;
  have B := Benitoite.Release.Refinement.StandardModel.builtins P;
  ∃ Ψ b sg ts es rs ws a e,
    B.sig b = Option.some sg ∧
      (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit) ∧
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e ∧ ∃ out obs, B.ioResponse b ts es ws out obs
```

### `StandardModel.normal_facts`（F07）

```lean
∀ {externals : List (Benitoite.Release.Refinement.ExternalKey × Benitoite.Release.Refinement.ExternalDecl)}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  (Benitoite.Release.Refinement.StandardModel.builtins
            (Benitoite.Release.Refinement.StandardModel.program externals)).sig
        b =
      Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
      Benitoite.Release.Refinement.BuiltinArgs (Benitoite.Release.Refinement.StandardModel.program externals)
          (Benitoite.Release.Refinement.StandardModel.builtins
            (Benitoite.Release.Refinement.StandardModel.program externals))
          Ψ b sg ts es rs ws a e →
        (Benitoite.Release.Refinement.StandardModel.builtins
                  (Benitoite.Release.Refinement.StandardModel.program externals)).delta
              b ts es rs ws =
            Option.some (Benitoite.Release.Refinement.Outcome.val v) →
          v.toTerm? = Option.some t →
            ∀ (r : Benitoite.Release.Refinement.Pred), r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

### `ExternalSurface.ref_typed`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty},
  P.externalFunction f = Option.some d →
    Benitoite.Release.Refinement.ExternalSignature.WF P d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] →
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalRef f ts)
            (Benitoite.Release.Refinement.Ty.dependentFn
              (Benitoite.Release.Refinement.instantiatedTel d.parameters ts []))
```

### `ExternalSurface.call_typed`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  P.externalFunction f = Option.some d →
    Benitoite.Release.Refinement.ExternalSignature.WF P d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
            (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) a e →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
            (Benitoite.Release.Refinement.Comp.externalCall f ts ws) a e Δ
```

### `ExternalSurface.type_declared_iff`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx} {id : Benitoite.Release.Refinement.ExternalId}
  {args : List Benitoite.Release.Refinement.Ty},
  P.ExternalWF →
    (Benitoite.Release.Refinement.Ty.Declared P C Γ (Benitoite.Release.Refinement.Ty.external id args) ↔
      args = [] ∧ ∃ td, P.externalType id = Option.some td)
```

### `ExternalSurface.ref_of_lookup`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty},
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] →
          ts = [] ∧
            Benitoite.Release.Refinement.instantiatedTel d.parameters ts [] = d.parameters.norm ∧
              d.parameters.norm.effect = Benitoite.Release.Refinement.ExternalSurface.callEffect d ∧
                Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalRef f ts)
                  (Benitoite.Release.Refinement.Ty.dependentFn d.parameters.norm)
```

### `ExternalSurface.ref_inputs`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {T : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalRef f ts) T →
    ∃ d u,
      P.externalFunction f = Option.some d ∧
        Benitoite.Release.Refinement.ExternalSignature.WF P d ∧
          ts = [] ∧ T.fnCore = Option.some u ∧ Benitoite.Release.Refinement.TelClosure P Γ Φ d.parameters.norm u
```

### `ExternalSurface.ref_arguments`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {T : Benitoite.Release.Refinement.Ty}
  {u : Benitoite.Release.Refinement.Tel} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Ctx.WF 0 (List.length C) Γ →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalRef f ts) T →
      T.fnCore = Option.some u →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
          ∃ d b g,
            P.externalFunction f = Option.some d ∧
              Benitoite.Release.Refinement.ExternalSignature.WF P d ∧
                Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts ∧
                  Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
                      (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) b
                      g ∧
                    Benitoite.Release.Refinement.Ty.LeQ P Γ Φ b a ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ e g
```

### `ExternalSurface.call_of_lookup`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
            (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) a e →
          ts = [] ∧
            ws.length = d.parameters.arity ∧
              e = Benitoite.Release.Refinement.ExternalSurface.callEffect d ∧
                Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
                  (Benitoite.Release.Refinement.Comp.externalCall f ts ws) a e Δ
```

### `ExternalSurface.apply_typed`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  P.externalFunction f = Option.some d →
    Benitoite.Release.Refinement.ExternalSignature.WF P d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] →
          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
              (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) a e →
            Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
              (Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) ws) a e Δ
```

### `ExternalSurface.named_call`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {positions : List Nat} {labels : List (Option String)}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  (fallback : Benitoite.Release.Refinement.Val),
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        positions.Perm (List.range d.parameters.arity) →
          ∀ (count : vs.length = positions.length),
            labels = List.map (fun i => d.parameters.names[i]?) positions →
              Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ
                  (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)
                  (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) a e →
                (∀ (k : Nat) (hk : k < positions.length),
                    (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)[positions[k]]? =
                        Option.some vs[k] ∧
                      labels[k]? =
                        Option.some
                          (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts)
                                d.parameters).names[positions[k]]?) ∧
                  (∀ (i : Nat), i < d.parameters.arity → ∃ k hk, positions[k] = i) ∧
                    e = Benitoite.Release.Refinement.ExternalSurface.callEffect d ∧
                      Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
                        (Benitoite.Release.Refinement.Comp.externalCall f ts
                          (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback))
                        a e Δ
```

### `ExternalSurface.partial_call`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {Δ : Benitoite.Release.Refinement.LocalCtx} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {positions : List Nat} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (fallback : Benitoite.Release.Refinement.Val),
  P.ExternalWF →
    P.externalFunction f = Option.some d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] →
          positions.Perm (List.range d.parameters.arity) →
            ∀ (count : vs.length = positions.length),
              Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ
                  (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)
                  (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) a e →
                (∀ (k : Nat) (hk : k < positions.length),
                    (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)[positions[k]]? =
                      Option.some vs[k]) ∧
                  e = Benitoite.Release.Refinement.ExternalSurface.callEffect d ∧
                    Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
                      (Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts)
                        (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback))
                      a e Δ
```

### `ExternalSurface.callEffect`（F08）

```lean
Benitoite.Release.Refinement.ExternalSignature → Benitoite.Release.Refinement.Eff
```

### `ExternalSurface.args_effect`（F08）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {ws : List Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Tel} {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {atoms : Benitoite.Release.Refinement.Atom → Bool},
  Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e →
    t.effect = Benitoite.Release.Refinement.EffR.mk atoms [] → e = Benitoite.Release.Refinement.EffR.mk atoms []
```

### `ExternalModels.ModelCase.composition`（合成）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (P : Benitoite.Release.Refinement.Program),
  m.Declarations P →
    Benitoite.Release.Refinement.ModelScopeConditions P (m.table P) ∧
      Benitoite.Release.Refinement.Builtins.ExternalAssumptions P (m.table P) ∧
        (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
            (o : Benitoite.Release.OpaqueName),
            Benitoite.Release.Refinement.HasTypeV P (m.table P) Ψ [] [] [] v
                (Benitoite.Release.Refinement.Ty.opaque o
                  (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
              (m.table P).isResource o = Bool.true →
                ∀ (r : Option Benitoite.Release.ErrKind), (m.table P).releaseResponse v r) ∧
          Benitoite.Release.Refinement.Builtins.CoreAssumptions P (m.table P) ∧
            Benitoite.Release.Refinement.Builtins.TargetAgreement P (m.table P)
```

### `ExternalModels.ModelCase.external_constant`（合成）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase) (P : Benitoite.Release.Refinement.Program)
  (f : Benitoite.Release.Refinement.ExternalFunctionId) (ts : List Benitoite.Release.Refinement.Ty)
  (vs : List Benitoite.Release.Refinement.Val),
  (m.table P).externalResponse f ts vs (Benitoite.Release.Refinement.Outcome.err "External") []
```

### `ExternalModels.ModelCase.new_field_inputs`（合成）

```lean
∀ (m : Benitoite.Release.Refinement.ExternalModels.ModelCase)
  (s : Benitoite.Release.Refinement.ExternalModelExamples.Shape) (Ψ : Benitoite.Release.Refinement.StoreTy),
  (m.Declarations (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true) ∧
      (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true).ExternalWF ∧
        Benitoite.Release.Refinement.ExternalArgs
            (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)
            (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)) Ψ
            (Benitoite.Release.Refinement.ExternalModelExamples.signature s Bool.true) [] [] (s.type Bool.true)
            Benitoite.Release.Refinement.Eff.empty ∧
          (m.table (Benitoite.Release.Refinement.ExternalModelExamples.program s Bool.true)).externalResponse
            (Benitoite.Release.Refinement.ExternalFunctionId.mk 0) [] []
            (Benitoite.Release.Refinement.Outcome.val (s.raw Bool.true)) []) ∧
    ∀ (P : Benitoite.Release.Refinement.Program),
      (m = Benitoite.Release.Refinement.ExternalModels.ModelCase.targets →
          ∃ v o,
            Benitoite.Release.Refinement.HasTypeV P (m.table P) Ψ [] [] [] v
                (Benitoite.Release.Refinement.Ty.opaque o
                  (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) ∧
              (m.table P).isResource o = Bool.true) ∧
        (m ≠ Benitoite.Release.Refinement.ExternalModels.ModelCase.targets →
          ∀ (o : Benitoite.Release.OpaqueName), (m.table P).isResource o ≠ Bool.true)
```

### `ExternalModels.model_vacuous_premises`（合成）

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.ExternalModels.model P) Ψ b sg ts es
              rs ws a e →
            False) ∧
    (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
        (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
        (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
        (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
        (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some sg →
          sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
            Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.ExternalModels.model P) Ψ b sg ts
                es rs ws a e →
              (Benitoite.Release.Refinement.ExternalModels.model P).ioResponse b ts es ws out obs → False) ∧
      (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
          (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
          (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
          (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
          (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
          (obs : List Benitoite.Scope.Domain.Target),
          (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some sg →
            Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.ExternalModels.model P) Ψ b sg ts
                es rs ws a e →
              (Benitoite.Release.Refinement.ExternalModels.model P).ioResponse b ts es ws out obs → False) ∧
        (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
            (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
            (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
            (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
            (e : Benitoite.Release.Refinement.Eff),
            (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some sg →
              sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                  sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
                Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.ExternalModels.model P) Ψ b sg
                    ts es rs ws a e →
                  False) ∧
          (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
              (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some s →
                s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.exit →
                  False) ∧
            ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
              (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
              (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
              (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
              (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
              (obs : List Benitoite.Scope.Domain.Target),
              (Benitoite.Release.Refinement.ExternalModels.model P).sig b = Option.some sg →
                sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
                  Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.ExternalModels.model P) Ψ b
                      sg ts es rs ws a e →
                    (Benitoite.Release.Refinement.ExternalModels.model P).ioResponse b ts es ws out obs → False
```

### `Benitoite.Release.progress`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellTyped B →
    P.EffectsOk B →
      Benitoite.Release.Builtins.CoreAssumptions P B →
        ∀ {s : Benitoite.Release.State},
          Benitoite.Release.StateTy P B s → s.Final ∨ ∃ l s', Benitoite.Release.Step P B s l s'
```

### `Benitoite.Release.preservation`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellFormed →
    P.WellTyped B →
      P.EffectsOk B →
        Benitoite.Release.Builtins.CoreAssumptions P B →
          ∀ {s : Benitoite.Release.State} {l : Option Benitoite.Release.Event} {s' : Benitoite.Release.State},
            Benitoite.Release.StateTy P B s → Benitoite.Release.Step P B s l s' → Benitoite.Release.StateTy P B s'
```

### `Benitoite.Release.step_sound`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  Benitoite.Release.Builtins.CoreAssumptions P B →
    ∀ (oracle : Benitoite.Release.Oracle) (rel : Benitoite.Release.Val → Option Benitoite.Release.ErrKind)
      (fresh : Benitoite.Release.Store → Nat),
      (∀ (b : Benitoite.Release.PrimName) (ts : List Benitoite.Release.Ty) (es : List Benitoite.Release.Eff)
          (ws : List Benitoite.Release.Val) (o : Benitoite.Release.Outcome) (obs : List Benitoite.Scope.Domain.Target),
          B.ioResponse b ts es ws o obs → B.ioResponse b ts es ws (oracle b ts es ws).fst (oracle b ts es ws).snd) →
        (∀ (v : Benitoite.Release.Val) (r : Option Benitoite.Release.ErrKind),
            B.releaseResponse v r → B.releaseResponse v (rel v)) →
          (∀ (σ : Benitoite.Release.Store), (∃ n, ∀ (l : Nat), n ≤ l → σ l = Option.none) → σ (fresh σ) = Option.none) →
            ∀ {s : Benitoite.Release.State} {l : Option Benitoite.Release.Event} {s' : Benitoite.Release.State},
              Benitoite.Release.StateTy P B s →
                Benitoite.Release.step P B oracle rel fresh s = Option.some (l, s') → Benitoite.Release.Step P B s l s'
```

### `Benitoite.Release.effect_soundness`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellFormed →
    P.WellTyped B →
      P.EffectsOk B →
        Benitoite.Release.Builtins.CoreAssumptions P B →
          ∀ {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty},
            Benitoite.Release.HasTypeC P B Benitoite.Release.StoreTy.empty [] [] Option.none m a
                Benitoite.Release.Eff.empty →
              m.ClosedNoEffVars →
                ∀ (s : Benitoite.Release.State),
                  Benitoite.Release.Steps P B (Benitoite.Release.State.run m [] Benitoite.Release.Store.empty) s →
                    (∀ (ev : Benitoite.Release.Event) (s' : Benitoite.Release.State),
                        ¬Benitoite.Release.Step P B s (Option.some ev) s') ∧
                      ¬Benitoite.Release.UnhandledOp s
```

### `Benitoite.Release.effect_soundness_noLamNames`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellFormed →
    P.WellTyped B →
      P.EffectsOk B →
        Benitoite.Release.Builtins.CoreAssumptions P B →
          ∀ {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty},
            Benitoite.Release.HasTypeC P B Benitoite.Release.StoreTy.empty [] [] Option.none m a
                Benitoite.Release.Eff.empty →
              Benitoite.Release.Comp.VarsInNoLamNames 0 (fun x => False) m →
                ∀ (s : Benitoite.Release.State),
                  Benitoite.Release.Steps P B (Benitoite.Release.State.run m [] Benitoite.Release.Store.empty) s →
                    (∀ (ev : Benitoite.Release.Event) (s' : Benitoite.Release.State),
                        ¬Benitoite.Release.Step P B s (Option.some ev) s') ∧
                      ¬Benitoite.Release.UnhandledOp s
```

### `Benitoite.Release.reachable_target_sound`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellFormed →
    P.WellTyped B →
      P.EffectsOk B →
        Benitoite.Release.Builtins.CoreAssumptions P B →
          Benitoite.Release.Builtins.TargetAgreement P B →
            ∀ {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty} {ε : Benitoite.Release.Eff},
              Benitoite.Release.HasTypeC P B Benitoite.Release.StoreTy.empty [] [] Option.none m a ε →
                m.ClosedNoEffVars →
                  ∀ {s s' : Benitoite.Release.State} {b : Benitoite.Release.PrimName} {ws : List Benitoite.Release.Val}
                    {o : Benitoite.Release.Outcome} {obs : List Benitoite.Scope.Domain.Target},
                    Benitoite.Release.Steps P B (Benitoite.Release.State.run m [] Benitoite.Release.Store.empty) s →
                      Benitoite.Release.Step P B s (Option.some (Benitoite.Release.Event.io b ws o obs)) s' →
                        ∃ e l,
                          B.sig b = Option.some e ∧
                            e.opEff = Option.some l ∧ ∀ (t : Benitoite.Scope.Domain.Target), t ∈ obs → B.Allows ε l t
```

### `Benitoite.Release.reachable_target_sound_event`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellFormed →
    P.WellTyped B →
      P.EffectsOk B →
        Benitoite.Release.Builtins.CoreAssumptions P B →
          Benitoite.Release.Builtins.TargetAgreement P B →
            ∀ {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty} {ε : Benitoite.Release.Eff},
              Benitoite.Release.HasTypeC P B Benitoite.Release.StoreTy.empty [] [] Option.none m a ε →
                m.ClosedNoEffVars →
                  ∀ {s s' : Benitoite.Release.State} {ev : Benitoite.Release.Event},
                    Benitoite.Release.Steps P B (Benitoite.Release.State.run m [] Benitoite.Release.Store.empty) s →
                      Benitoite.Release.Step P B s (Option.some ev) s' →
                        ∀ (t : Benitoite.Scope.Domain.Target),
                          t ∈ ev.obs →
                            ∃ b ws o obs e l,
                              ev = Benitoite.Release.Event.io b ws o obs ∧
                                B.sig b = Option.some e ∧ e.opEff = Option.some l ∧ B.Allows ε l t
```

### `Benitoite.Release.reachable_target_sound_of_assumptions`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.WellFormed →
    P.WellTyped B →
      P.EffectsOk B →
        Benitoite.Release.Builtins.Assumptions P B →
          ∀ {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty} {ε : Benitoite.Release.Eff},
            Benitoite.Release.HasTypeC P B Benitoite.Release.StoreTy.empty [] [] Option.none m a ε →
              m.ClosedNoEffVars →
                ∀ {s s' : Benitoite.Release.State} {b : Benitoite.Release.PrimName} {ws : List Benitoite.Release.Val}
                  {o : Benitoite.Release.Outcome} {obs : List Benitoite.Scope.Domain.Target},
                  Benitoite.Release.Steps P B (Benitoite.Release.State.run m [] Benitoite.Release.Store.empty) s →
                    Benitoite.Release.Step P B s (Option.some (Benitoite.Release.Event.io b ws o obs)) s' →
                      ∃ e l,
                        B.sig b = Option.some e ∧
                          e.opEff = Option.some l ∧ ∀ (t : Benitoite.Scope.Domain.Target), t ∈ obs → B.Allows ε l t
```

### `Benitoite.Release.step_target_sound`（旧主定理）

```lean
∀ {P : Benitoite.Release.Program} {B : Benitoite.Release.Builtins},
  P.EffectsOk B →
    Benitoite.Release.Builtins.CoreAssumptions P B →
      Benitoite.Release.Builtins.TargetAgreement P B →
        ∀ {Eb : Benitoite.Release.Eff} {s s' : Benitoite.Release.State} {b : Benitoite.Release.PrimName}
          {ws : List Benitoite.Release.Val} {o : Benitoite.Release.Outcome} {obs : List Benitoite.Scope.Domain.Target},
          Benitoite.Release.StateTyE P B Eb s →
            Benitoite.Release.Step P B s (Option.some (Benitoite.Release.Event.io b ws o obs)) s' →
              ∃ e l,
                B.sig b = Option.some e ∧
                  e.opEff = Option.some l ∧ ∀ (t : Benitoite.Scope.Domain.Target), t ∈ obs → B.Allows Eb l t
```

### `Benitoite.Release.Model.assumptions`（旧主定理）

```lean
∀ (P : Benitoite.Release.Program), Benitoite.Release.Builtins.Assumptions P Benitoite.Release.Model.builtins
```

### `Benitoite.Release.ModelTargets.assumptions`（旧主定理）

```lean
∀ (pat : String → Option Benitoite.Scope.Domain.Range) (tgt : String → Option Benitoite.Scope.Domain.Target)
  (P : Benitoite.Release.Program),
  Benitoite.Release.ModelTargets.HasResult P →
    Benitoite.Release.Builtins.Assumptions P (Benitoite.Release.ModelTargets.builtins pat tgt)
```

### `Benitoite.Release.ModelHttp.assumptions`（旧主定理）

```lean
∀ (hostPat : String → Int → Int → Option Benitoite.Scope.Domain.Range)
  (reqTarget : Benitoite.Release.Val → Option Benitoite.Scope.Domain.Target) (P : Benitoite.Release.Program),
  Benitoite.Release.ModelHttp.HasHttp P →
    Benitoite.Release.Builtins.Assumptions P (Benitoite.Release.ModelHttp.builtins hostPat reqTarget)
```

### `ExternalId`（C01）

```lean
Type
```

### `ComponentId`（C01）

```lean
Type
```

### `ExternalFunctionId`（C01）

```lean
Type
```

### `Ty.external`（C01）

```lean
Benitoite.Release.Refinement.ExternalId → List Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty
```

### `ExternalKey`（C01）

```lean
Type
```

### `ExternalDecl`（C01）

```lean
Type
```

### `ExternalTypeDecl`（C01）

```lean
Type
```

### `ExternalHandle`（C01）

```lean
Type
```

### `Program.externalType`（C02）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ExternalId → Option Benitoite.Release.Refinement.ExternalTypeDecl
```

### `Program.externalFunction`（C02）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ExternalFunctionId → Option Benitoite.Release.Refinement.ExternalSignature
```

### `Program.ExternalWF`（C02）

```lean
Benitoite.Release.Refinement.Program → Prop
```

### `Program.ExternalWF.type_lookup`（C02）

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  P.ExternalWF →
    ∀ {id : Benitoite.Release.Refinement.ExternalId} {td : Benitoite.Release.Refinement.ExternalTypeDecl},
      P.externalType id = Option.some td → td.id = id ∧ td.arity = 0
```

### `Program.ExternalWF.function_lookup`（C02）

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  P.ExternalWF →
    ∀ {f : Benitoite.Release.Refinement.ExternalFunctionId} {d : Benitoite.Release.Refinement.ExternalSignature},
      P.externalFunction f = Option.some d → Benitoite.Release.Refinement.ExternalSignature.WF P d
```

### `ExternalValueType`（C03）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ComponentId → Bool → Benitoite.Release.Refinement.Ty → Prop
```

### `ExternalOccurrence`（C03）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.ExternalPathStep → Benitoite.Release.Refinement.ExternalId → Prop
```

### `ExternalUseAt`（C03）

```lean
Benitoite.Release.Refinement.Program →
  Nat → Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.ExternalUse → Prop
```

### `ExternalTelWF`（C03）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ComponentId → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Tel → Prop
```

### `ExternalSignature.WF`（C03）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.ExternalSignature → Prop
```

### `ExternalCallAdmissible.types_nil`（C03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {C : Benitoite.Release.Refinement.TypeCtx} {d : Benitoite.Release.Refinement.ExternalSignature}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
    Benitoite.Release.Refinement.ExternalSignature.WF P d → ts = []
```

### `ExternalCallAdmissible.map`（C03）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {C : Benitoite.Release.Refinement.TypeCtx} {d : Benitoite.Release.Refinement.ExternalSignature}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
    Benitoite.Release.Refinement.ExternalSignature.WF P d →
      ∀ (g : Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty),
        Benitoite.Release.Refinement.ExternalCallAdmissible P B C d (List.map g ts)
```

### `HasTypeVQ.V_ExternalRef`（C04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty},
  P.externalFunction f = Option.some d →
    Benitoite.Release.Refinement.ExternalSignature.WF P d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] →
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalRef f ts)
            (Benitoite.Release.Refinement.Ty.dependentFn
              (Benitoite.Release.Refinement.instantiatedTel d.parameters ts []))
```

### `HasTypeVQ.V_ExternalHandle`（C04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {ts : List Benitoite.Release.Refinement.Ty}
  (h : Benitoite.Release.Refinement.ExternalHandle) (td : Benitoite.Release.Refinement.ExternalTypeDecl),
  P.externalType h.typeId = Option.some td →
    td.component = h.component →
      td.resource = h.resource →
        ts.length = td.arity →
          Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.external h.typeId ts) →
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.externalHandle h ts)
              (Benitoite.Release.Refinement.Ty.external h.typeId ts)
```

### `HasTypeCQ.C_External`（C04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {R : Option Benitoite.Release.Refinement.Ty} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  P.externalFunction f = Option.some d →
    Benitoite.Release.Refinement.ExternalSignature.WF P d →
      Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ vs
            (Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.typeEnv ts) d.parameters) a e →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
            (Benitoite.Release.Refinement.Comp.externalCall f ts vs) a e Δ
```

### `HasTypeCQ.C_Use`（C04）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {R : Option Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val} {o : Benitoite.Release.OpaqueName}
  {m : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty} {ε : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v
      (Benitoite.Release.Refinement.Ty.opaque o
        (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
    B.isResource o = Bool.true →
      Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        ε.test
              (Benitoite.Release.Refinement.Atom.name Benitoite.Release.stateEff
                (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) =
            Bool.true →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R (Benitoite.Release.Refinement.Comp.use v m) a ε Δ
```

### `Ty.bind_external`（C05）

```lean
∀ (id : Benitoite.Release.Refinement.ExternalId) (ts : List Benitoite.Release.Refinement.Ty)
  (θ : Benitoite.Release.Refinement.SubstEnv),
  Benitoite.Release.Refinement.Ty.bind θ (Benitoite.Release.Refinement.Ty.external id ts) =
    Benitoite.Release.Refinement.Ty.external id (List.map (Benitoite.Release.Refinement.Ty.bind θ) ts)
```

### `HasTypeVQ.inv_externalRef`（C06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.externalRef f ts →
      ∃ d u,
        P.externalFunction f = Option.some d ∧
          Benitoite.Release.Refinement.ExternalSignature.WF P d ∧
            Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts ∧
              Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] ∧
                T.fnCore = Option.some u ∧
                  Benitoite.Release.Refinement.TelClosure P Γ Φ
                    (Benitoite.Release.Refinement.instantiatedTel d.parameters ts []) u
```

### `HasTypeVQ.inv_externalHandle`（C06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {handle : Benitoite.Release.Refinement.ExternalHandle}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.externalHandle handle ts →
      ∃ td,
        P.externalType handle.typeId = Option.some td ∧
          td.component = handle.component ∧
            td.resource = handle.resource ∧
              ts.length = td.arity ∧
                Benitoite.Release.Refinement.Ty.Annotation P C Γ
                    (Benitoite.Release.Refinement.Ty.external handle.typeId ts) ∧
                  Benitoite.Release.Refinement.Ty.LeQ P Γ Φ (Benitoite.Release.Refinement.Ty.external handle.typeId ts)
                    T
```

### `HasTypeVQ.canonical_external`（C06）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty}
  {id : Benitoite.Release.Refinement.ExternalId} {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.norm.core = Benitoite.Release.Refinement.Ty.external id ts →
      ∃ handle us, v = Benitoite.Release.Refinement.Val.externalHandle handle us
```

### `ExternalCarrier`（C07）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Ty → Prop
```

### `ExternalPredicates`（C07）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Ty → Prop
```

### `ExternalCarrier.accepted`（C07）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ExternalCarrier P B Ψ v a →
    Benitoite.Release.Refinement.ExternalPredicates P v a → Benitoite.Release.Refinement.externalCheck P v a = Bool.true
```

### `ExternalCarrier.checked_typed`（C07）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ExternalCarrier P B Ψ v a →
    Benitoite.Release.Refinement.externalCheck P v a = Bool.true →
      Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v a
```

### `ExternalArgs`（C08）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.Refinement.ExternalSignature →
        List Benitoite.Release.Refinement.Ty →
          List Benitoite.Release.Refinement.Val →
            Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

### `Builtins.ExternalAssumptions`（C08）

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

### `externalReceive`（C08）

```lean
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.ExternalSignature →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → Option Benitoite.Release.Refinement.Outcome
```

### `Builtins.ExternalAssumptions.receive`（C09）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    P.ExternalWF →
      P.externalFunction f = Option.some d →
        Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
          B.externalResponse f ts vs out obs →
            ∃ checked,
              Benitoite.Release.Refinement.externalReceive P d ts vs out = Option.some checked ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ checked a ∧
                  (∀ (n : Int), checked ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧ obs = []
```

### `Builtins.ExternalAssumptions.external_adequate`（C09）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    P.ExternalWF →
      P.externalFunction f = Option.some d →
        Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
          B.externalResponse f ts vs out obs →
            ∀ (σ : Benitoite.Release.Refinement.PathEnv), Benitoite.Release.Refinement.Outcome.Adequate σ out
```

### `Builtins.ExternalAssumptions.received_value`（C09）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    P.ExternalWF →
      P.externalFunction f = Option.some d →
        Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
          B.externalResponse f ts vs out obs →
            Benitoite.Release.Refinement.externalReceive P d ts vs out =
                Option.some (Benitoite.Release.Refinement.Outcome.val v) →
              ∀ (σ : Benitoite.Release.Refinement.PathEnv),
                Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v a ∧
                  v.Ground ∧ Benitoite.Release.Refinement.Val.Adequate σ v
```

### `Builtins.ExternalAssumptions.receive_no_exit`（C09）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {d : Benitoite.Release.Refinement.ExternalSignature} {ts : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {n : Int},
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
    P.ExternalWF →
      P.externalFunction f = Option.some d →
        Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
          B.externalResponse f ts vs out obs →
            Benitoite.Release.Refinement.externalReceive P d ts vs out ≠
              Option.some (Benitoite.Release.Refinement.Outcome.exit n)
```

### `Step.external_accept`（C09）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {d : Benitoite.Release.Refinement.ExternalSignature}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
    q.view = Benitoite.Release.Refinement.Comp.externalCall f ts vs →
      P.externalFunction f = Option.some d →
        B.externalResponse f ts vs (Benitoite.Release.Refinement.Outcome.val v) obs →
          Benitoite.Release.Refinement.externalCheck P v a = Bool.true →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

### `Step.external_reject`（C09）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {d : Benitoite.Release.Refinement.ExternalSignature}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {obs : List Benitoite.Scope.Domain.Target} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
    q.view = Benitoite.Release.Refinement.Comp.externalCall f ts vs →
      P.externalFunction f = Option.some d →
        B.externalResponse f ts vs (Benitoite.Release.Refinement.Outcome.val v) obs →
          Benitoite.Release.Refinement.externalCheck P v a = Bool.false →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
              (Benitoite.Release.Refinement.State.error ["ExternalRefinement"] k μ)
```

### `Step.E_ExternalApply`（C10）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) ws →
    Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts ws)) k μ)
```

### `Step.E_External`（C10）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {decl : Benitoite.Release.Refinement.ExternalSignature}
  {v : Benitoite.Release.Refinement.Val} {obs : List Benitoite.Scope.Domain.Target}
  {out : Benitoite.Release.Refinement.Outcome},
  q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
    P.externalFunction f = Option.some decl →
      B.externalResponse f ts ws out obs →
        Benitoite.Release.Refinement.externalReceive P decl ts ws out =
            Option.some (Benitoite.Release.Refinement.Outcome.val v) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

### `Step.E_ExternalErr`（C10）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {f : Benitoite.Release.Refinement.ExternalFunctionId} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {decl : Benitoite.Release.Refinement.ExternalSignature}
  {r : Benitoite.Release.ErrKind} {obs : List Benitoite.Scope.Domain.Target}
  {out : Benitoite.Release.Refinement.Outcome},
  q.view = Benitoite.Release.Refinement.Comp.externalCall f ts ws →
    P.externalFunction f = Option.some decl →
      B.externalResponse f ts ws out obs →
        Benitoite.Release.Refinement.externalReceive P decl ts ws out =
            Option.some (Benitoite.Release.Refinement.Outcome.err r) →
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
            (Benitoite.Release.Refinement.State.error [r] k μ)
```

### `ClosureTy.external_view_typed`（C11）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {R : Option Benitoite.Release.Refinement.Ty}
  {q : Benitoite.Release.Refinement.Closure} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Ψ.WF →
          Ψ.Sorted →
            Benitoite.Release.Refinement.StoreTy.Declared P Ψ →
              Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e →
                q.view = Benitoite.Release.Refinement.Comp.externalCall f ts vs →
                  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty [] [] [] R
                    (Benitoite.Release.Refinement.Comp.externalCall f ts vs) a e
```

### `ClosureTy.external_view_inputs`（C11）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {R : Option Benitoite.Release.Refinement.Ty}
  {q : Benitoite.Release.Refinement.Closure} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {d : Benitoite.Release.Refinement.ExternalSignature},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Ψ.WF →
          Ψ.Sorted →
            Benitoite.Release.Refinement.StoreTy.Declared P Ψ →
              Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e →
                Benitoite.Release.Refinement.Closure.ClosedAt 0 q →
                  q.view = Benitoite.Release.Refinement.Comp.externalCall f ts vs →
                    P.externalFunction f = Option.some d →
                      ∃ r ef,
                        Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs r ef ∧
                          Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                            Benitoite.Release.Refinement.Eff.Covers [] [] e ef
```

### `StateTyE.external_apply_all`（C11）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) vs →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts vs)) k
                  μ) ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb
                (Benitoite.Release.Refinement.State.run
                  (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.externalCall f ts vs)) k
                  μ)
```

### `StateTyE.external_value_all`（C11）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {d : Benitoite.Release.Refinement.ExternalSignature} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {v : Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.externalCall f ts vs →
            P.externalFunction f = Option.some d →
              B.externalResponse f ts vs out obs →
                Benitoite.Release.Refinement.externalReceive P d ts vs out =
                    Option.some (Benitoite.Release.Refinement.Outcome.val v) →
                  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                    Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ)
```

### `StateTyE.external_error_all`（C11）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {d : Benitoite.Release.Refinement.ExternalSignature} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {r : Benitoite.Release.ErrKind},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    q.view = Benitoite.Release.Refinement.Comp.externalCall f ts vs →
      P.externalFunction f = Option.some d →
        B.externalResponse f ts vs out obs →
          Benitoite.Release.Refinement.externalReceive P d ts vs out =
              Option.some (Benitoite.Release.Refinement.Outcome.err r) →
            Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) Option.none
                (Benitoite.Release.Refinement.State.error [r] k μ) ∧
              Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error [r] k μ)
```

### `StateTyE.externalRef_contract_inputs`（C12）

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {f : Benitoite.Release.Refinement.ExternalFunctionId}
  {ts : List Benitoite.Release.Refinement.Ty} {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.externalRef f ts) ws →
            ∃ Ψ R a ec d result effects,
              Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a ec ∧
                  P.externalFunction f = Option.some d ∧
                    Benitoite.Release.Refinement.ExternalSignature.WF P d ∧
                      Benitoite.Release.Refinement.ExternalCallAdmissible P B [] d ts ∧
                        Benitoite.Release.Refinement.SignatureInstance P [] [] d.parameters d.kinds ts [] ∧
                          Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                              (Benitoite.Release.Refinement.instantiatedTel d.parameters ts []) result effects ∧
                            Benitoite.Release.Refinement.Ty.LeQ P [] [] result a ∧
                              Benitoite.Release.Refinement.Eff.Covers [] [] ec effects
```

### `TelClosure.apply`（C12）

```lean
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

