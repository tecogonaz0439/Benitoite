# 段末の実際の署名

既定環境の宣言の型を印字した。証明本体の評価ではない。

## Benitoite.Release.Refinement.StateTyE.app_inputs

所在: `formal/Benitoite/Release/Refinement/ApplicationInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {f : Benitoite.Release.Refinement.Val}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app f ws →
            ∃ Ψ R a e t r ef,
              Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] f
                      (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
                    Benitoite.Release.Refinement.Ty.Annotation P [] [] (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
                      Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws t r ef ∧
                        Benitoite.Release.Refinement.Ty.LeQ P [] [] r a ∧
                          Benitoite.Release.Refinement.Eff.Covers [] [] e ef
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_loc

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {l : Nat},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.loc l →
      (∃ a,
          Ψ l = some (Benitoite.Release.Refinement.LocTy.ref a) ∧
            Benitoite.Release.Refinement.Ty.Declared P C Γ a ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ a.reference T) ∨
        ∃ a,
          Ψ l = some (Benitoite.Release.Refinement.LocTy.lazy a) ∧
            Benitoite.Release.Refinement.Ty.Declared P C Γ a ∧ Benitoite.Release.Refinement.Ty.LeQ P Γ Φ a.lazy T
```

## Benitoite.Release.Refinement.StoreOk.builder_cell

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {kind : Benitoite.Release.Refinement.BuilderKind},
  Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
    Ψ l = some (Benitoite.Release.Refinement.LocTy.builder kind) →
      ∃ c,
        μ l = some (Benitoite.Release.Refinement.Cell.builder c) ∧
          Benitoite.Release.Refinement.BuilderCellOk P B Ψ kind c ∧
            Benitoite.Release.Refinement.Cell.Adequate σ (Benitoite.Release.Refinement.Cell.builder c)
```

## Benitoite.Release.Refinement.StoreOk.cont_cell

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {b t : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {r : Option Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
    Ψ l = some (Benitoite.Release.Refinement.LocTy.cont b t e r) →
      (∃ k,
          μ l = some (Benitoite.Release.Refinement.Cell.cont k) ∧
            Benitoite.Release.Refinement.EndsWithHandle k ∧
              ∃ R' e', Benitoite.Release.Refinement.ContTy P B σ Ψ R' e' k b t e r) ∨
        μ l = some Benitoite.Release.Refinement.Cell.used
```

## Benitoite.Release.Refinement.StoreOk.lazy_cell

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
    Ψ l = some (Benitoite.Release.Refinement.LocTy.lazy a) →
      (∃ q,
          μ l = some (Benitoite.Release.Refinement.Cell.thunk q) ∧
            Benitoite.Release.Refinement.ClosureTy P B (Benitoite.Release.Refinement.hideBuilders Ψ) [] none q a
                Benitoite.Release.Refinement.Eff.empty ∧
              Benitoite.Release.Refinement.Closure.Adequate σ q) ∨
        ∃ v,
          μ l = some (Benitoite.Release.Refinement.Cell.done v) ∧
            Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v a ∧ Benitoite.Release.Refinement.Val.Adequate σ v
```

## Benitoite.Release.Refinement.StoreOk.ref_cell

所在: `formal/Benitoite/Release/Refinement/CanonicalCells.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {μ : Benitoite.Release.Refinement.Store} {l : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.StoreOk P B σ Ψ μ →
    Ψ l = some (Benitoite.Release.Refinement.LocTy.ref a) →
      ∃ v,
        μ l = some (Benitoite.Release.Refinement.Cell.val v) ∧
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v a.norm ∧ Benitoite.Release.Refinement.Val.Adequate σ v
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_boolean

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.norm.core = Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean →
      ∃ b, v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean b)
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_data

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty} {d : Benitoite.Release.DataName}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.norm.core = Benitoite.Release.Refinement.Ty.data d ts →
      (∃ c us vs, v = Benitoite.Release.Refinement.Val.con c us vs) ∨
        ∃ detail, v = Benitoite.Release.Refinement.Val.atError detail
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_held

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpaqueName}
  {kind : Benitoite.Scope.Domain.Kind} {ix : Benitoite.Release.Refinement.RangeIx},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.Holds o kind ix →
      (∃ o payload, v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.opaque o payload)) ∨
        (∃ target, v = Benitoite.Release.Refinement.Val.checked target) ∨
          (∃ target req, v = Benitoite.Release.Refinement.Val.checkedRequest target req) ∨
            ∃ r snapshot target req, v = Benitoite.Release.Refinement.Val.checkedAt r snapshot target req
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_list

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.listCore = some a →
      ∃ vs b,
        v = Benitoite.Release.Refinement.Val.list vs ∧
          Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C [] Φ vs b ∧ Benitoite.Release.Refinement.Ty.LeQ P [] Φ b a
```

## Benitoite.Release.Refinement.HasTypeVQ.canonical_scalar

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {T : Benitoite.Release.Refinement.Ty} {tag : Benitoite.Release.BaseTy},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v T →
    T.norm.core = Benitoite.Release.Refinement.Ty.base tag →
      ∃ c,
        v = Benitoite.Release.Refinement.Val.const c ∧
          Benitoite.Release.Refinement.ConstOK B c ∧ c.type.norm.core = Benitoite.Release.Refinement.Ty.base tag
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_atError

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {detail : Benitoite.Release.Refinement.AtError},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.atError detail →
      ∃ shape, Benitoite.Release.Refinement.ResultShape.Declared P shape ∧ T.norm.core = shape.errorType.norm.core
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_externalHandle

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

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
        P.externalType handle.typeId = some td ∧
          td.component = handle.component ∧
            td.resource = handle.resource ∧
              ts.length = td.arity ∧
                Benitoite.Release.Refinement.Ty.Annotation P C Γ
                    (Benitoite.Release.Refinement.Ty.external handle.typeId ts) ∧
                  Benitoite.Release.Refinement.Ty.LeQ P Γ Φ (Benitoite.Release.Refinement.Ty.external handle.typeId ts)
                    T
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_externalRef

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

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
        P.externalFunction f = some d ∧
          Benitoite.Release.Refinement.ExternalSignature.WF P d ∧
            Benitoite.Release.Refinement.ExternalCallAdmissible P B C d ts ∧
              Benitoite.Release.Refinement.SignatureInstance P C Γ d.parameters d.kinds ts [] ∧
                T.fnCore = some u ∧
                  Benitoite.Release.Refinement.TelClosure P Γ Φ
                    (Benitoite.Release.Refinement.instantiatedTel d.parameters ts []) u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_pathBases

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {snapshot : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.pathBases snapshot →
      snapshot.Valid ∧ Benitoite.Release.Refinement.Ty.LeQ P Γ Φ Benitoite.Release.Refinement.Ty.pathBases T
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_scopePattern

所在: `formal/Benitoite/Release/Refinement/CanonicalValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {range : Benitoite.Release.Refinement.RangeExpr},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.scopePattern range →
      ∃ kind,
        range.WF ∧
          range.Canonical ∧
            range.FitsKind kind ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ (Benitoite.Release.Refinement.Ty.scopePattern kind) T
```

## Benitoite.Release.Refinement.StateTyE.lambda_beta_all

所在: `formal/Benitoite/Release/Refinement/ClosureStateLeaves.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {f : Benitoite.Release.Refinement.Val}
  {runtime : Benitoite.Release.Refinement.Tel} {body : Benitoite.Release.Refinement.Closure}
  {vs : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app f vs →
            Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty f =
                Benitoite.Release.Refinement.Val.closure runtime body →
              vs.length = runtime.arity →
                Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                    (Benitoite.Release.Refinement.State.run (body.apply vs) (Benitoite.Release.Refinement.markPush k)
                      μ) ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb
                    (Benitoite.Release.Refinement.State.run (body.apply vs) (Benitoite.Release.Refinement.markPush k) μ)
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_bytesV

所在: `formal/Benitoite/Release/Refinement/CollectionInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {bs : List Nat}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.bytesV bs →
      (∀ (b : Nat), b ∈ bs → b ≤ 255) ∧ T.norm.core = Benitoite.Release.Refinement.Ty.bytes
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_mapV

所在: `formal/Benitoite/Release/Refinement/CollectionInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {ks vs : List Benitoite.Release.Refinement.Val} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.mapV ks vs →
      ∃ a b k w,
        Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ ks a ∧
          Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs b ∧
            ks.length = vs.length ∧
              B.sat C.constraints a.norm Benitoite.Release.TParam.keyC ∧
                Benitoite.Release.Refinement.Ty.Annotation P C Γ a ∧
                  Benitoite.Release.Refinement.Ty.Annotation P C Γ b ∧
                    T.norm.core = k.map w ∧ a.norm = k.norm ∧ Benitoite.Release.Refinement.Ty.LeQ P Γ Φ b w
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_setV

所在: `formal/Benitoite/Release/Refinement/CollectionInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.setV vs →
      ∃ a w,
        Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
          B.sat C.constraints a.norm Benitoite.Release.TParam.keyC ∧
            Benitoite.Release.Refinement.Ty.Annotation P C Γ a ∧ T.norm.core = w.set ∧ a.norm = w.norm
```

## Benitoite.Release.Refinement.HasTypeCQ.inputs

所在: `formal/Benitoite/Release/Refinement/ComputationInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {code : Benitoite.Release.Refinement.Comp} {T : Benitoite.Release.Refinement.Ty}
  {E : Benitoite.Release.Refinement.Eff} {L : Benitoite.Release.Refinement.LocalCtx},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R code T E L →
    Benitoite.Release.Refinement.Comp.Inputs P B Ψ Q C Γ Φ R T E L code
```

## Benitoite.Release.Refinement.HasTypeCQ.app_tel

所在: `formal/Benitoite/Release/Refinement/ComputationInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {code : Benitoite.Release.Refinement.Comp} {T : Benitoite.Release.Refinement.Ty}
  {E : Benitoite.Release.Refinement.Eff} {L : Benitoite.Release.Refinement.LocalCtx}
  {f : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R code T E L →
    code = Benitoite.Release.Refinement.Comp.app f ws →
      Ψ.WF →
        Ψ.Sorted →
          Benitoite.Release.Refinement.StoreTy.Declared P Ψ →
            Benitoite.Release.Refinement.CaptureContextRegular P C Γ →
              ∃ t r e,
                Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ f (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
                  Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t r e ∧
                    Benitoite.Release.Refinement.Ty.LeQ P Γ Φ r T ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ E e
```

## Benitoite.Release.Refinement.HasTypeCQ.inv_app

所在: `formal/Benitoite/Release/Refinement/ComputationInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {code : Benitoite.Release.Refinement.Comp} {T : Benitoite.Release.Refinement.Ty}
  {E : Benitoite.Release.Refinement.Eff} {L : Benitoite.Release.Refinement.LocalCtx}
  {f : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R code T E L →
    code = Benitoite.Release.Refinement.Comp.app f ws →
      (∃ ns ps r e,
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ f (Benitoite.Release.Refinement.Ty.fn ns ps r e) ∧
            Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ ws ps ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ r T ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ E e) ∨
        ∃ t r e,
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ f (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
            Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t r e ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ r T ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ E e
```

## Benitoite.Release.Refinement.HasTypeCQ.inv_escape

所在: `formal/Benitoite/Release/Refinement/ComputationInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {R : Option Benitoite.Release.Refinement.Ty} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {outEff : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {code : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ →
    code = Benitoite.Release.Refinement.Comp.escape v →
      ∃ r a ε,
        R = some r ∧
          Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v r ∧
            Benitoite.Release.Refinement.Ty.Annotation P C Γ a ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ a T ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ outEff ε
```

## Benitoite.Release.Refinement.HasTypeCQ.inv_let

所在: `formal/Benitoite/Release/Refinement/ComputationInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {R : Option Benitoite.Release.Refinement.Ty} {Δ : Benitoite.Release.Refinement.LocalCtx}
  {outEff : Benitoite.Release.Refinement.Eff} {m n code : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ →
    code = m.letIn n →
      ∃ a b ε,
        Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ ∧
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C (Γ.extend a)
              (List.map Benitoite.Release.Refinement.Pred.lift Φ)
              (Option.map (Benitoite.Release.Refinement.Ty.shiftV 1 0) R) n
              (Benitoite.Release.Refinement.Ty.shiftV 1 0 b) (Benitoite.Release.Refinement.Eff.shiftV 1 0 ε)
              (Benitoite.Release.Refinement.localExtend 1 Δ) ∧
            Benitoite.Release.Refinement.Ty.Declared P C Γ b ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ b T ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ outEff ε
```

## Benitoite.Release.Refinement.IntervalConnection.H04.first_error

所在: `formal/Benitoite/Release/Refinement/FirstFailure.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {s target : Benitoite.Release.Refinement.State}
  {events : List Benitoite.Release.Refinement.Event},
  Benitoite.Release.Refinement.Steps P B σ s events target →
    Benitoite.Release.Refinement.IntervalConnection.H04.BeforeError s →
      ∀ (errors : List Benitoite.Release.ErrKind) (lastK : Benitoite.Release.Refinement.Cont)
        (lastStore : Benitoite.Release.Refinement.Store),
        target = Benitoite.Release.Refinement.State.error errors lastK lastStore →
          ∃ preEvents before event firstErrors firstK firstStore suffix,
            Benitoite.Release.Refinement.IntervalConnection.H04.BeforeErrorSteps P B σ s preEvents before ∧
              Benitoite.Release.Refinement.Step P B σ before event
                  (Benitoite.Release.Refinement.State.error firstErrors firstK firstStore) ∧
                Benitoite.Release.Refinement.Steps P B σ
                    (Benitoite.Release.Refinement.State.error firstErrors firstK firstStore) suffix
                    (Benitoite.Release.Refinement.State.error errors lastK lastStore) ∧
                  events = preEvents ++ event.toList ++ suffix
```

## Benitoite.Release.Refinement.IntervalConnection.H04.first_failure_handoff

所在: `formal/Benitoite/Release/Refinement/FirstFailure.lean`

```lean
Benitoite.Release.Refinement.IntervalConnection.H04.FirstFailureHandoff
```

## Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.old_candidate_false

所在: `formal/Benitoite/Release/Refinement/FirstFailure.lean`

```lean
¬Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.OldH04
```

## Benitoite.Release.Refinement.IntervalConnection.H04.pure_failure

所在: `formal/Benitoite/Release/Refinement/FirstFailure.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {event : Option Benitoite.Release.Refinement.Event} {errors : List Benitoite.Release.ErrKind}
  {firstK : Benitoite.Release.Refinement.Cont} {firstStore : Benitoite.Release.Refinement.Store}
  {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {ranges : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) event
      (Benitoite.Release.Refinement.State.error errors firstK firstStore) →
    q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es ranges) ws →
      B.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          event = none ∧
            ∃ r,
              errors = [r] ∧
                B.delta b (Benitoite.Release.Refinement.Ty.normTys ts)
                    (List.map Benitoite.Release.Refinement.Eff.norm es) ranges ws =
                  some (Benitoite.Release.Refinement.Outcome.err r)
```

## Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.revised_counterexample_accepted

所在: `formal/Benitoite/Release/Refinement/FirstFailure.lean`

```lean
∀ (σ : Benitoite.Release.Refinement.PathEnv),
  ∃ preEvents before firstErrors firstK firstStore suffix,
    Benitoite.Release.Refinement.IntervalConnection.H04.BeforeErrorSteps
        Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.P✝
        Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.B✝ σ
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.mk
            Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.cap✝
            Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.code✝)
          [] Benitoite.Release.Refinement.Store.empty)
        preEvents before ∧
      Benitoite.Release.Refinement.Step Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.P✝
          Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.B✝ σ before none
          (Benitoite.Release.Refinement.State.error firstErrors firstK firstStore) ∧
        Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.P✝
            Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.B✝ σ
            (Benitoite.Release.Refinement.State.error firstErrors firstK firstStore) suffix
            (Benitoite.Release.Refinement.State.error ["LeftError"] [] Benitoite.Release.Refinement.Store.empty) ∧
          (∃ q k μ,
              before = Benitoite.Release.Refinement.State.run q k μ ∧
                q.view =
                  Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim "neg" [] [] [])
                    [Benitoite.Release.Refinement.Val.const
                        (Benitoite.Release.Refinement.Const.integer
                          Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.one✝)]) ∧
            Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.B✝.delta "neg" [] [] []
                [Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.Const.integer
                      Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.one✝)] =
              some (Benitoite.Release.Refinement.Outcome.err "LeftError")
```

## Benitoite.Release.Refinement.IntervalControlLeaves.error_let_typed

所在: `formal/Benitoite/Release/Refinement/IntervalControlLeaves.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {errors : List Benitoite.Release.ErrKind} {n : Benitoite.Release.Refinement.Closure}
  {k : List Benitoite.Release.Refinement.Frame} {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb
      (Benitoite.Release.Refinement.State.error errors (Benitoite.Release.Refinement.Frame.letF n :: k) μ) →
    Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.error errors (Benitoite.Release.Refinement.Frame.letF n :: k) μ) none
        (Benitoite.Release.Refinement.State.error errors k μ) ∧
      Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error errors k μ)
```

## Benitoite.Release.Refinement.IntervalControlLeaves.error_mark_typed

所在: `formal/Benitoite/Release/Refinement/IntervalControlLeaves.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {errors : List Benitoite.Release.ErrKind} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb
      (Benitoite.Release.Refinement.State.error errors (Benitoite.Release.Refinement.Frame.mark :: k) μ) →
    Benitoite.Release.Refinement.Step P B σ
        (Benitoite.Release.Refinement.State.error errors (Benitoite.Release.Refinement.Frame.mark :: k) μ) none
        (Benitoite.Release.Refinement.State.error errors k μ) ∧
      Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.error errors k μ)
```

## Benitoite.Release.Refinement.IntervalControlLeaves.escape_mark_member

所在: `formal/Benitoite/Release/Refinement/IntervalControlLeaves.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {c : Benitoite.Interval.ConcreteValue} {v : Benitoite.Release.Refinement.Val}
  {f : Benitoite.Shared.FlowApprox},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb
            (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.mark :: k) μ) →
          q.view = Benitoite.Release.Refinement.Comp.escape v →
            Benitoite.Release.Refinement.IntervalConnection.ValueRel c v →
              f.ReturnedMem c.toApprox →
                Benitoite.Release.Refinement.Step P B σ
                    (Benitoite.Release.Refinement.State.run q (Benitoite.Release.Refinement.Frame.mark :: k) μ) none
                    (Benitoite.Release.Refinement.State.run
                      (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                  Benitoite.Release.Refinement.StateTyE P B σ Eb
                      (Benitoite.Release.Refinement.State.run
                        (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                    Benitoite.Release.Refinement.IntervalConnection.EndState (fun x x_1 => False)
                        (Benitoite.Interval.EvalOutcome.normal c) k
                        (Benitoite.Release.Refinement.State.run
                          (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) k μ) ∧
                      (Benitoite.Release.Refinement.IntervalFlowLeaves.normalF f.returned).NormalMem
                          (Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty
                              v).toApprox ∧
                        ∃ Ψ R a e,
                          Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                            Benitoite.Release.Refinement.ClosureTy P B Ψ [] R
                                (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.Comp.ret v)) a
                                e ∧
                              Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
                                (Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty v) a
```

## Benitoite.Release.Refinement.IntervalControlLeaves.normal_state_member

所在: `formal/Benitoite/Release/Refinement/IntervalControlLeaves.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {c : Benitoite.Interval.ConcreteValue} {v : Benitoite.Release.Refinement.Val}
  {f : Benitoite.Shared.FlowApprox},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.ret v →
            Benitoite.Release.Refinement.IntervalConnection.ValueRel c v →
              f.NormalMem c.toApprox →
                (∃ Ψ R a e,
                    Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
                      Benitoite.Release.Refinement.ClosureTy P B Ψ [] R q a e ∧
                        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a) ∧
                  f.NormalMem v.toApprox
```

## Benitoite.Release.Refinement.IntervalControlLeaves.typed_first_failure

所在: `formal/Benitoite/Release/Refinement/IntervalControlLeaves.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {events : List Benitoite.Release.Refinement.Event}
  {errors : List Benitoite.Release.ErrKind} {lastK : Benitoite.Release.Refinement.Cont}
  {lastStore : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
    Benitoite.Release.Refinement.Steps P B σ (Benitoite.Release.Refinement.State.run q k μ) events
        (Benitoite.Release.Refinement.State.error errors lastK lastStore) →
      Benitoite.Release.Refinement.State.Inputs P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) ∧
        ∃ preEvents before event firstErrors firstK firstStore suffix,
          Benitoite.Release.Refinement.IntervalConnection.H04.BeforeErrorSteps P B σ
              (Benitoite.Release.Refinement.State.run q k μ) preEvents before ∧
            Benitoite.Release.Refinement.Step P B σ before event
                (Benitoite.Release.Refinement.State.error firstErrors firstK firstStore) ∧
              Benitoite.Release.Refinement.Steps P B σ
                  (Benitoite.Release.Refinement.State.error firstErrors firstK firstStore) suffix
                  (Benitoite.Release.Refinement.State.error errors lastK lastStore) ∧
                events = preEvents ++ event.toList ++ suffix ∧
                  ∀ (focus : Benitoite.Release.Refinement.Closure) (atK : Benitoite.Release.Refinement.Cont)
                    (atStore : Benitoite.Release.Refinement.Store) (b : Benitoite.Release.PrimName)
                    (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
                    (ranges : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
                    (sg : Benitoite.Release.Refinement.PrimSig),
                    before = Benitoite.Release.Refinement.State.run focus atK atStore →
                      focus.view =
                          Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.prim b ts es ranges)
                            ws →
                        B.sig b = some sg →
                          sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
                            event = none ∧
                              ∃ r,
                                firstErrors = [r] ∧
                                  B.delta b (Benitoite.Release.Refinement.Ty.normTys ts)
                                      (List.map Benitoite.Release.Refinement.Eff.norm es) ranges ws =
                                    some (Benitoite.Release.Refinement.Outcome.err r)
```

## Benitoite.Release.Refinement.IntervalFailure.analyzeExpr_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (limits : Benitoite.Interval.Budget.Limits) (state : Benitoite.Interval.Budget.State) (fuel : Nat)
  {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {input : Benitoite.Interval.EvalInput} {outcome : Benitoite.Interval.EvalOutcome}
  {trace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    Benitoite.Interval.EvalPartial concrete input outcome trace →
      Benitoite.Release.Refinement.IntervalFailure.FailureCovered
        (Benitoite.Interval.BudgetAnalysis.analyzeExpr limits state fuel abstract input.key input.source).approx outcome
```

## Benitoite.Release.Refinement.IntervalFailure.arguments_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {key : Benitoite.Interval.OperationKey} {sources : Benitoite.Surface.Exprs} {type : Benitoite.Release.Ty}
  {outcome : Benitoite.Interval.EvalOutcome} {trace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    abstract.ranges.Models concrete →
      Benitoite.Interval.EvalArguments concrete key (Benitoite.Interval.exprsChildren sources) type
          (Benitoite.Interval.ArgumentOutcome.abrupt outcome) trace →
        Benitoite.Interval.BudgetAnalysis.SuccessAt key
          (Benitoite.Interval.BudgetAnalysis.arguments fuel abstract sources) fun a =>
          Benitoite.Release.Refinement.IntervalFailure.FailureCovered a outcome
```

## Benitoite.Release.Refinement.IntervalFailure.armListKind_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {source : Benitoite.Surface.Expr} {key scrutineeKey : Benitoite.Interval.OperationKey} {arms : Benitoite.Surface.Arms}
  {type : Benitoite.Release.Ty} {outcome : Benitoite.Interval.EvalOutcome} {trace st : Benitoite.Interval.EvalTrace}
  {kind : Benitoite.Interval.IntKind} {normal : Benitoite.Interval.Interval kind}
  {integer : Benitoite.Interval.IntegerValue kind},
  kind ≠ Benitoite.Interval.IntKind.integer64 →
    Benitoite.Interval.Models abstract concrete →
      abstract.ranges.Models concrete →
        Benitoite.Interval.EvalPartial concrete { source := source, type := kind.type, key := scrutineeKey }
            (Benitoite.Interval.EvalOutcome.normal (Benitoite.Interval.ConcreteValue.ofInteger kind integer)) st →
          Benitoite.Interval.Mem integer.toInt normal →
            Benitoite.Interval.EvalWidthArms concrete key kind integer arms type outcome trace →
              Benitoite.Interval.BudgetAnalysis.SuccessAt key
                (Benitoite.Interval.BudgetAnalysis.armListKind fuel kind abstract source normal arms) fun approx =>
                Benitoite.Release.Refinement.IntervalFailure.FailureCovered approx outcome
```

## Benitoite.Release.Refinement.IntervalFailure.armList_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {source : Benitoite.Surface.Expr} {normal : Benitoite.Interval.Interval}
  {key scrutineeKey : Benitoite.Interval.OperationKey} {integer : Benitoite.Release.Integer64Value}
  {arms : Benitoite.Surface.Arms} {type : Benitoite.Release.Ty} {outcome : Benitoite.Interval.EvalOutcome}
  {trace st : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    abstract.ranges.Models concrete →
      Benitoite.Interval.EvalPartial concrete
          { source := source, type := Benitoite.Release.Ty.base Benitoite.Release.BaseTy.integer, key := scrutineeKey }
          (Benitoite.Interval.EvalOutcome.normal (Benitoite.Interval.ConcreteValue.integer integer)) st →
        Benitoite.Interval.Mem integer.toInt normal →
          Benitoite.Interval.EvalArms concrete key integer arms type outcome trace →
            Benitoite.Interval.BudgetAnalysis.SuccessAt key
              (Benitoite.Interval.BudgetAnalysis.armList fuel abstract source normal arms) fun approx =>
              Benitoite.Release.Refinement.IntervalFailure.FailureCovered approx outcome
```

## Benitoite.Release.Refinement.IntervalFailure.block_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {key : Benitoite.Interval.OperationKey} {body : Benitoite.Surface.Block} {type : Benitoite.Release.Ty}
  {outcome : Benitoite.Interval.EvalOutcome} {trace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    abstract.ranges.Models concrete →
      Benitoite.Interval.EvalBlock concrete key body type outcome trace →
        Benitoite.Interval.BudgetAnalysis.SuccessAt key (Benitoite.Interval.BudgetAnalysis.block fuel abstract body)
          fun approx => Benitoite.Release.Refinement.IntervalFailure.FailureCovered approx outcome
```

## Benitoite.Release.Refinement.IntervalFailure.expr_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {input : Benitoite.Interval.EvalInput} {outcome : Benitoite.Interval.EvalOutcome}
  {trace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    abstract.ranges.Models concrete →
      Benitoite.Interval.EvalPartial concrete input outcome trace →
        Benitoite.Interval.BudgetAnalysis.SuccessAt input.key
          (Benitoite.Interval.BudgetAnalysis.expr fuel abstract input.source) fun a =>
          Benitoite.Release.Refinement.IntervalFailure.FailureCovered a outcome
```

## Benitoite.Release.Refinement.IntervalFailure.report_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ {result : Except Benitoite.Interval.BudgetAnalysis.Halt Benitoite.Interval.BaseApprox}
  (ctx : Benitoite.Interval.BudgetAnalysis.Context) {outcome : Benitoite.Interval.EvalOutcome},
  (∀ (a : Benitoite.Interval.BaseApprox),
      result = Except.ok a → Benitoite.Release.Refinement.IntervalFailure.FailureCovered a outcome) →
    Benitoite.Release.Refinement.IntervalFailure.FailureCovered
      (Benitoite.Interval.BudgetAnalysis.report result ctx).approx outcome
```

## Benitoite.Release.Refinement.IntervalFailure.resultArmList_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {input : Benitoite.Interval.EvalInput} {sourceType : Benitoite.Release.Ty} {fullArms : Benitoite.Surface.Arms}
  {origin : Benitoite.Interval.RangeOrigin} {result : Benitoite.Interval.ConcreteValue}
  {tag : Benitoite.Release.ConName} {payload : Benitoite.Interval.ConcreteValue} {key : Benitoite.Interval.OperationKey}
  {arms : Benitoite.Surface.Arms} {type : Benitoite.Release.Ty} {outcome : Benitoite.Interval.EvalOutcome}
  {trace st : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    abstract.ranges.Models concrete →
      Benitoite.Interval.rangeMatchAt abstract input fullArms = some origin →
        Benitoite.Interval.EvalPartial concrete { source := input.source, type := sourceType, key := input.key }
            (Benitoite.Interval.EvalOutcome.normal result) st →
          Benitoite.Interval.rangeResultMatch concrete result fullArms = some origin.names →
            origin.names.ResultView result tag payload →
              Benitoite.Interval.EvalResultArms concrete key origin.names result tag payload arms type outcome trace →
                Benitoite.Interval.BudgetAnalysis.SuccessAt key
                  (Benitoite.Interval.BudgetAnalysis.resultArmList fuel abstract input arms) fun approx =>
                  Benitoite.Release.Refinement.IntervalFailure.FailureCovered approx outcome
```

## Benitoite.Release.Refinement.tracked_failure_sound

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (abstract : Benitoite.Interval.AbstractEnv) (concrete : Benitoite.Interval.ConcreteEnv)
  (input : Benitoite.Interval.EvalInput) (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
  (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace),
  Benitoite.Interval.Models abstract concrete →
    Benitoite.Interval.EvalPartial concrete input (Benitoite.Interval.EvalOutcome.failed reason) trace →
      Benitoite.Release.Refinement.IntervalConnection.TrackedFailure reason trace →
        (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true
```

## Benitoite.Release.Refinement.IntervalFailure.typed_arguments_failure

所在: `formal/Benitoite/Release/Refinement/IntervalFailure.lean`

```lean
∀ (fuel : Nat) {abstract : Benitoite.Interval.AbstractEnv} {concrete : Benitoite.Interval.ConcreteEnv}
  {key : Benitoite.Interval.OperationKey} {sources : Benitoite.Surface.Exprs} {types : List Benitoite.Release.Ty}
  {outcome : Benitoite.Interval.EvalOutcome} {trace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.Models abstract concrete →
    abstract.ranges.Models concrete →
      Benitoite.Interval.EvalTypedArguments concrete key (Benitoite.Interval.exprsChildren sources) types
          (Benitoite.Interval.ArgumentOutcome.abrupt outcome) trace →
        Benitoite.Interval.BudgetAnalysis.SuccessAt key
          (Benitoite.Interval.BudgetAnalysis.arguments fuel abstract sources) fun a =>
          Benitoite.Release.Refinement.IntervalFailure.FailureCovered a outcome
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.expression_block_leaf

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {f : Benitoite.Shared.FlowApprox} {env : Benitoite.Interval.ConcreteEnv} {key : Benitoite.Interval.OperationKey}
  {body : Benitoite.Surface.Block} {type : Benitoite.Release.Ty} {outcome : Benitoite.Interval.EvalOutcome}
  {trace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.EvalBlock env (Benitoite.Interval.childKey key []) body type outcome trace →
    f.ResultMem outcome.toApprox →
      Benitoite.Interval.EvalPartial env { source := Benitoite.Surface.Expr.block body, type := type, key := key }
          outcome trace ∧
        f.ResultMem outcome.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.joinF

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
Benitoite.Shared.FlowApprox → Benitoite.Shared.FlowApprox → Benitoite.Shared.FlowApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.joinV

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
Benitoite.Shared.ValueApprox → Benitoite.Shared.ValueApprox → Benitoite.Shared.ValueApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.match_abrupt_leaf

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {h f : Benitoite.Shared.FlowApprox} {env : Benitoite.Interval.ConcreteEnv} {key : Benitoite.Interval.OperationKey}
  {source : Benitoite.Surface.Expr} {arms : Benitoite.Surface.Arms} {type sourceType : Benitoite.Release.Ty}
  {outcome : Benitoite.Interval.EvalOutcome} {st : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.EvalPartial env { source := source, type := sourceType, key := Benitoite.Interval.childKey key [] }
      outcome st →
    outcome.Abrupt →
      h.ResultMem outcome.toApprox →
        Benitoite.Interval.EvalPartial env
            { source := Benitoite.Surface.Expr.matchE type source arms, type := type, key := key } outcome st ∧
          (Benitoite.Release.Refinement.IntervalFlowLeaves.seqF h f).ResultMem outcome.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.match_integer_leaf

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {h f : Benitoite.Shared.FlowApprox} {env : Benitoite.Interval.ConcreteEnv} {key : Benitoite.Interval.OperationKey}
  {source : Benitoite.Surface.Expr} {arms : Benitoite.Surface.Arms} {type : Benitoite.Release.Ty}
  {value : Benitoite.Release.Integer64Value} {outcome : Benitoite.Interval.EvalOutcome}
  {st armTrace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.EvalPartial env
      { source := source, type := Benitoite.Release.Ty.base Benitoite.Release.BaseTy.integer,
        key := Benitoite.Interval.childKey key [] }
      (Benitoite.Interval.EvalOutcome.normal (Benitoite.Interval.ConcreteValue.integer value)) st →
    Benitoite.Interval.EvalArms env (Benitoite.Interval.childKey key [source]) value arms type outcome armTrace →
      f.ResultMem outcome.toApprox →
        Benitoite.Interval.EvalPartial env
            { source := Benitoite.Surface.Expr.matchE type source arms, type := type, key := key } outcome
            (st ++ armTrace) ∧
          (Benitoite.Release.Refinement.IntervalFlowLeaves.seqF h f).ResultMem outcome.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.match_result_leaf

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {h f : Benitoite.Shared.FlowApprox} {env : Benitoite.Interval.ConcreteEnv} {key : Benitoite.Interval.OperationKey}
  {source : Benitoite.Surface.Expr} {arms : Benitoite.Surface.Arms} {type sourceType : Benitoite.Release.Ty}
  {value : Benitoite.Interval.ConcreteValue} {names : Benitoite.Interval.RangeNames} {tag : Benitoite.Release.ConName}
  {payload : Benitoite.Interval.ConcreteValue} {outcome : Benitoite.Interval.EvalOutcome}
  {st armTrace : Benitoite.Interval.EvalTrace},
  Benitoite.Interval.rangeResultMatch env value arms = some names →
    names.ResultView value tag payload →
      Benitoite.Interval.EvalPartial env
          { source := source, type := sourceType, key := Benitoite.Interval.childKey key [] }
          (Benitoite.Interval.EvalOutcome.normal value) st →
        Benitoite.Interval.EvalResultArms env (Benitoite.Interval.childKey key [source]) names value tag payload arms
            type outcome armTrace →
          f.ResultMem outcome.toApprox →
            Benitoite.Interval.EvalPartial env
                { source := Benitoite.Surface.Expr.matchE type source arms, type := type, key := key } outcome
                (st ++ armTrace) ∧
              (Benitoite.Release.Refinement.IntervalFlowLeaves.seqF h f).ResultMem outcome.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.match_width_leaf

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {h f : Benitoite.Shared.FlowApprox} {env : Benitoite.Interval.ConcreteEnv} {key : Benitoite.Interval.OperationKey}
  {kind : Benitoite.Interval.IntKind} {source : Benitoite.Surface.Expr} {arms : Benitoite.Surface.Arms}
  {type : Benitoite.Release.Ty} {value : Benitoite.Interval.IntegerValue kind}
  {outcome : Benitoite.Interval.EvalOutcome} {st armTrace : Benitoite.Interval.EvalTrace},
  kind ≠ Benitoite.Interval.IntKind.integer64 →
    Benitoite.Interval.EvalPartial env
        { source := source, type := kind.type, key := Benitoite.Interval.childKey key [] }
        (Benitoite.Interval.EvalOutcome.normal (Benitoite.Interval.ConcreteValue.ofInteger kind value)) st →
      Benitoite.Interval.EvalWidthArms env (Benitoite.Interval.childKey key [source]) kind value arms type outcome
          armTrace →
        f.ResultMem outcome.toApprox →
          Benitoite.Interval.EvalPartial env
              { source := Benitoite.Surface.Expr.matchE type source arms, type := type, key := key } outcome
              (st ++ armTrace) ∧
            (Benitoite.Release.Refinement.IntervalFlowLeaves.seqF h f).ResultMem outcome.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.normalF

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
Benitoite.Shared.ValueApprox → Benitoite.Shared.FlowApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.normal_mem_of_related

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {f : Benitoite.Shared.FlowApprox} {c : Benitoite.Interval.ConcreteValue} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.IntervalConnection.ValueRel c v → f.NormalMem c.toApprox → f.NormalMem v.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.returnF

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
Benitoite.Shared.FlowApprox → Benitoite.Shared.FlowApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.return_leaf

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {env : Benitoite.Interval.ConcreteEnv} {key : Benitoite.Interval.OperationKey} {resultType : Benitoite.Release.Ty}
  {source : Benitoite.Surface.Expr} {type : Benitoite.Release.Ty} {outcome : Benitoite.Interval.EvalOutcome}
  {trace : Benitoite.Interval.EvalTrace} {f : Benitoite.Shared.FlowApprox},
  Benitoite.Interval.EvalPartial env { source := source, type := type, key := Benitoite.Interval.childKey key [] }
      outcome trace →
    f.ResultMem outcome.toApprox →
      Benitoite.Interval.EvalPartial env
          { source := Benitoite.Surface.Expr.returnE resultType source, type := resultType, key := key }
          (Benitoite.Interval.returnOutcome outcome) trace ∧
        (Benitoite.Release.Refinement.IntervalFlowLeaves.returnF f).ResultMem
          (Benitoite.Interval.returnOutcome outcome).toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.returned_mem_of_related

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
∀ {f : Benitoite.Shared.FlowApprox} {c : Benitoite.Interval.ConcreteValue} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.IntervalConnection.ValueRel c v → f.ReturnedMem c.toApprox → f.ReturnedMem v.toApprox
```

## Benitoite.Release.Refinement.IntervalFlowLeaves.seqF

所在: `formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean`

```lean
Benitoite.Shared.FlowApprox → Benitoite.Shared.FlowApprox → Benitoite.Shared.FlowApprox
```

## Benitoite.Release.Refinement.StateTyE.guard_op_inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : List Benitoite.Release.Refinement.Frame}
  {μ : Benitoite.Release.Refinement.Store} {o : Benitoite.Release.OpName} {ts : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val} {v : Benitoite.Release.Refinement.Val}
  {cap : Benitoite.Release.Refinement.Capture} {arms : List Benitoite.Release.Refinement.Arm} {next : Nat}
  {body : Benitoite.Release.Refinement.Closure},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb
            (Benitoite.Release.Refinement.State.run q
              (Benitoite.Release.Refinement.Frame.guardF v cap arms next body :: k) μ) →
          q.view = Benitoite.Release.Refinement.Comp.app (Benitoite.Release.Refinement.Val.op o ts) ws →
            ∃ Ψ od result effects,
              P.ops o = some od ∧
                Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                    (Benitoite.Release.Refinement.instantiatedTel od.tel ts []) result effects ∧
                  Benitoite.Release.Refinement.Eff.Covers [] [] Benitoite.Release.Refinement.Eff.empty effects
```

## Benitoite.Release.Refinement.StateTyE.if_inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {v : Benitoite.Release.Refinement.Val}
  {m n : Benitoite.Release.Refinement.Comp},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.ite v m n →
            ∃ b,
              v = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean b) ∧
                Benitoite.Release.Refinement.State.Inputs P B σ Eb
                  (Benitoite.Release.Refinement.State.run
                    (Benitoite.Release.Refinement.Closure.mk q.capture (if b = true then m else n)) k μ)
```

## Benitoite.Release.Refinement.StateTyE.inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {s : Benitoite.Release.Refinement.State},
  Benitoite.Release.Refinement.StateTyE P B σ Eb s → Benitoite.Release.Refinement.State.Inputs P B σ Eb s
```

## Benitoite.Release.Refinement.StateTyE.lambda_inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {q : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store} {f : Benitoite.Release.Refinement.Val}
  {runtime : Benitoite.Release.Refinement.Tel} {body : Benitoite.Release.Refinement.Closure}
  {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed →
    P.WellTyped B →
      Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
        Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.run q k μ) →
          q.view = Benitoite.Release.Refinement.Comp.app f ws →
            Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty f =
                Benitoite.Release.Refinement.Val.closure runtime body →
              Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
                  (Benitoite.Release.Refinement.State.run (body.apply ws) (Benitoite.Release.Refinement.markPush k) μ) ∧
                Benitoite.Release.Refinement.State.Inputs P B σ Eb
                  (Benitoite.Release.Refinement.State.run (body.apply ws) (Benitoite.Release.Refinement.markPush k) μ)
```

## Benitoite.Release.Refinement.StateTyE.match_inputs

所在: `formal/Benitoite/Release/Refinement/LeafInputs.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Refinement.Eff}
  {v : Benitoite.Release.Refinement.Val} {cap : Benitoite.Release.Refinement.Capture}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {k : Benitoite.Release.Refinement.Cont}
  {μ : Benitoite.Release.Refinement.Store},
  Benitoite.Release.Refinement.StateTyE P B σ Eb (Benitoite.Release.Refinement.State.matchRun v cap arms next k μ) →
    ∃ Ψ R Γ Φ Rs root obs arms0 input result effects L ρ,
      Benitoite.Release.Refinement.StoreOk P B σ Ψ μ ∧
        Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap ∧
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] Γ Φ root input ∧
            (∀ (t : Benitoite.Release.Refinement.Term),
                obs = some t → root.toTerm? = some t ∧ ∃ sort, Benitoite.Release.Refinement.Term.HasSort Γ t sort) ∧
              Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs obs arms0 input result
                  effects L ∧
                Benitoite.Release.Refinement.Exhaustive P input (Benitoite.Release.Refinement.unguardedPats arms0) ∧
                  Benitoite.Release.Refinement.CaptureLocals Ψ cap.env L ρ ∧
                    arms = Benitoite.Release.Refinement.Arm.resolveLocalsList ρ arms0 ∧
                      v = Benitoite.Release.Refinement.closeVal cap root ∧ cap.closeR Rs = R
```

## Benitoite.Release.Refinement.StandardArithmeticResponse.response_math

所在: `formal/Benitoite/Release/Refinement/StandardArithmeticResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (k : Benitoite.Interval.IntKind)
  (api : Benitoite.Release.Refinement.StandardArithmeticResponse.API),
  Benitoite.Release.Refinement.StandardArithmeticResponse.API.available k api →
    Benitoite.Release.Refinement.BuiltinArgs P B Ψ
        (Benitoite.Release.Refinement.StandardArithmeticResponse.API.name k api)
        (Benitoite.Release.Refinement.StandardArithmeticResponse.API.signature k api) ts es rs ws a e →
      ∃ left right,
        (ws =
            if api = Benitoite.Release.Refinement.StandardArithmeticResponse.API.negate then
              [Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k left))]
            else
              [Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k left)),
                Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k right))]) ∧
          ∃ out,
            Benitoite.Release.Refinement.StandardScalar.integerDelta
                  (Benitoite.Release.Refinement.StandardArithmeticResponse.API.name k api) ts es rs ws =
                some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  (∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i) ∧
                    out =
                        Benitoite.Release.Refinement.StandardScalar.integerOutcome
                          (Benitoite.Release.Refinement.StandardScalar.integerChecked k
                            (api.number left.toInt right.toInt)) ∧
                      (out = Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ↔
                          api.number left.toInt right.toInt < k.min ∨ k.max < api.number left.toInt right.toInt) ∧
                        ∀ (value : Benitoite.Release.Refinement.Val),
                          out = Benitoite.Release.Refinement.Outcome.val value →
                            ∃ target,
                              value =
                                  Benitoite.Release.Refinement.Val.const
                                    (Benitoite.Release.Refinement.embedConst
                                      (Benitoite.Interval.IntegerValue.toConst k target)) ∧
                                target.toInt = api.number left.toInt right.toInt
```

## Benitoite.Release.Refinement.StandardScalar.byteConvert_some

所在: `formal/Benitoite/Release/Refinement/StandardByteCharacter.lean`

```lean
∀ (n : Int) (v : UInt8), Benitoite.Release.Refinement.StandardScalar.byteConvert n = some v ↔ ↑v.toNat = n
```

## Benitoite.Release.Refinement.StandardScalar.byte_compare

所在: `formal/Benitoite/Release/Refinement/StandardByteCharacter.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (η : Benitoite.Release.Refinement.ObservationEnvModel) (a b : UInt8)
  (op : Benitoite.Release.Refinement.Comparison),
  ∃ value,
    Benitoite.Release.Refinement.StandardScalar.byteDelta
          (Benitoite.Release.Refinement.StandardScalar.byteCompareName op)
          (Benitoite.Release.Refinement.StandardScalar.comparisonTypes Benitoite.Release.BaseTy.byte op) [] []
          [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.byte a.toNat),
            Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.byte b.toNat)] =
        some
          (Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean value))) ∧
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean value))
          (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean) ∧
        Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.StandardScalar.integerComparePred op
              (Benitoite.Release.Refinement.Term.integer ↑a.toNat)
              (Benitoite.Release.Refinement.Term.integer ↑b.toNat)) =
          value
```

## Benitoite.Release.Refinement.StandardScalar.characterConvert_some

所在: `formal/Benitoite/Release/Refinement/StandardByteCharacter.lean`

```lean
∀ (n : Int) (c : Char), Benitoite.Release.Refinement.StandardScalar.characterConvert n = some c ↔ ↑c.toNat = n
```

## Benitoite.Release.Refinement.StandardScalar.character_code

所在: `formal/Benitoite/Release/Refinement/StandardByteCharacter.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (c : Char) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.StandardScalar.characterDelta "Character.toInteger" [] [] []
        [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.character c)] =
      some
        (Benitoite.Release.Refinement.Outcome.val
          (Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.Const.integer
              (Benitoite.Release.Refinement.StandardScalar.characterToInteger c)))) ∧
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        (Benitoite.Release.Refinement.Val.const
          (Benitoite.Release.Refinement.Const.integer
            (Benitoite.Release.Refinement.StandardScalar.characterToInteger c)))
        (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer) ∧
      Benitoite.Release.Refinement.Term.observe η
          (Benitoite.Release.Refinement.Term.measure Benitoite.Release.Refinement.Measure.characterCode
            (Benitoite.Release.Refinement.Term.character c)) =
        some (Benitoite.Release.Refinement.Observation.integer ↑c.toNat)
```

## Benitoite.Release.Refinement.StandardByteStringResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardByteStringResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ "Byte.toString"
      Benitoite.Release.Refinement.StandardByteStringResponse.signature ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardByteStringResponse.delta "Byte.toString" ts es rs ws = some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardBytesOrdinaryResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardBytesOrdinaryResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardBytesOrdinaryResponse.API),
  P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
    P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
      P.DataArity "Option" 1 →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e →
          ∃ out,
            api.delta api.name ts es rs ws = some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardBytesResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardBytesResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardBytesResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e →
    ∃ out,
      api.delta api.name ts es rs ws = some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardCharacterResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardCharacterResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardCharacterResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e →
    ∃ out,
      api.delta api.name ts es rs ws = some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program_typed

所在: `formal/Benitoite/Release/Refinement/StandardCollectionRefinedBodies.lean`

```lean
Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program.WellTyped
  Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins
```

## Benitoite.Release.Refinement.StandardCollectionRefinedBodies.response_assumptions

所在: `formal/Benitoite/Release/Refinement/StandardCollectionRefinedBodies.lean`

```lean
Benitoite.Release.Refinement.Builtins.ResponseAssumptions
  Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program
  Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins
```

## Benitoite.Release.Refinement.StandardCollectionRefinedBodies.seven_public_rows

所在: `formal/Benitoite/Release/Refinement/StandardCollectionRefinedBodies.lean`

```lean
(Benitoite.Release.Refinement.StandardHeadTail.publicRow false).BodyTyped
    Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program
    Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins ∧
  (Benitoite.Release.Refinement.StandardHeadTail.publicRow true).BodyTyped
      Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program
      Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins ∧
    Benitoite.Release.Refinement.StandardHeadTail.nonemptyPublicRow.BodyTyped
        Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program
        Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins ∧
      ∀ (api : Benitoite.Release.Refinement.StandardCollectionRefinedBodies.API),
        api ∈ Benitoite.Release.Refinement.StandardCollectionRefinedBodies.API.all →
          api.row.BodyTyped Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program
            Benitoite.Release.Refinement.StandardCollectionRefinedBodies.builtins
```

## Benitoite.Release.Refinement.StandardCollections.bytes_length

所在: `formal/Benitoite/Release/Refinement/StandardCollections.lean`

```lean
∀ (bs : List Nat),
  (bs.all fun x => decide (x ≤ 255)) = true →
    ∀ (η : Benitoite.Release.Refinement.ObservationEnvModel),
      Benitoite.Release.Refinement.StandardCollections.lengthDelta "Bytes.length" [] [] []
            [Benitoite.Release.Refinement.Val.bytesV bs] =
          some (Benitoite.Release.Refinement.StandardCollections.countReply bs.length) ∧
        Benitoite.Release.Refinement.Term.observe η
            (Benitoite.Release.Refinement.Term.measure Benitoite.Release.Refinement.Measure.bytesLength
              (Benitoite.Release.Refinement.Term.bytesValue bs)) =
          some (Benitoite.Release.Refinement.Observation.integer ↑bs.length)
```

## Benitoite.Release.Refinement.StandardCollections.list_length

所在: `formal/Benitoite/Release/Refinement/StandardCollections.lean`

```lean
∀ (a : Benitoite.Release.Refinement.Ty) (xs : List Benitoite.Release.Refinement.Val)
  (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.StandardCollections.lengthDelta "List.length" [a] [] []
        [Benitoite.Release.Refinement.Val.list xs] =
      some (Benitoite.Release.Refinement.StandardCollections.countReply xs.length) ∧
    Benitoite.Release.Refinement.Term.observe η
        (Benitoite.Release.Refinement.Term.measure Benitoite.Release.Refinement.Measure.listLength
          (Benitoite.Release.Refinement.Term.listValue (Benitoite.Release.Refinement.Val.toTermSlots xs))) =
      some (Benitoite.Release.Refinement.Observation.integer ↑xs.length)
```

## Benitoite.Release.Refinement.StandardCollections.string_lengths

所在: `formal/Benitoite/Release/Refinement/StandardCollections.lean`

```lean
∀ (s : String) (η : Benitoite.Release.Refinement.ObservationEnvModel),
  Benitoite.Release.Refinement.StandardCollections.lengthDelta "String.byteLength" [] [] []
        [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s)] =
      some (Benitoite.Release.Refinement.StandardCollections.countReply s.utf8ByteSize) ∧
    Benitoite.Release.Refinement.StandardCollections.lengthDelta "String.characterCount" [] [] []
          [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.string s)] =
        some (Benitoite.Release.Refinement.StandardCollections.countReply s.toList.length) ∧
      Benitoite.Release.Refinement.Term.observe η
            (Benitoite.Release.Refinement.Term.measure Benitoite.Release.Refinement.Measure.stringBytes
              (Benitoite.Release.Refinement.Term.string s)) =
          some (Benitoite.Release.Refinement.Observation.integer ↑s.utf8ByteSize) ∧
        Benitoite.Release.Refinement.Term.observe η
            (Benitoite.Release.Refinement.Term.measure Benitoite.Release.Refinement.Measure.stringCharacters
              (Benitoite.Release.Refinement.Term.string s)) =
          some (Benitoite.Release.Refinement.Observation.integer ↑s.toList.length)
```

## Benitoite.Release.Refinement.StandardConversionResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardConversionResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (k : Benitoite.Interval.IntKind) (fromInteger : Bool),
  k ≠ Benitoite.Interval.IntKind.integer64 →
    P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
      P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
        P.DataArity "Option" 1 →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ
              (Benitoite.Release.Refinement.StandardConversionResponse.name k fromInteger)
              (Benitoite.Release.Refinement.StandardConversionResponse.signature k fromInteger) ts es rs ws a e →
            ∃ out,
              Benitoite.Release.Refinement.StandardScalar.integerDelta
                    (Benitoite.Release.Refinement.StandardConversionResponse.name k fromInteger) ts es rs ws =
                  some out ∧
                Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardScalar.decimalDelta_round

所在: `formal/Benitoite/Release/Refinement/StandardDecimal.lean`

```lean
∀ (c : Int) (s : Nat),
  Benitoite.Release.Refinement.StandardScalar.decimalRepresentable c s →
    ∀ (places : Benitoite.Release.Integer64Value) (mode : Benitoite.Release.Refinement.StandardScalar.DecimalRounding),
      Benitoite.Release.Refinement.StandardScalar.decimalDelta "Decimal.round" [] [] []
          [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.decimal c s),
            Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer places),
            Benitoite.Release.Refinement.StandardScalar.roundingValue✝ mode] =
        some (Benitoite.Release.Refinement.StandardScalar.decimalRoundReply c s places.toInt mode)
```

## Benitoite.Release.Refinement.StandardScalar.decimalFromFloatDelta

所在: `formal/Benitoite/Release/Refinement/StandardDecimal.lean`

```lean
Option (Int × Nat) →
  Benitoite.Release.PrimName →
    List Benitoite.Release.Refinement.Ty →
      List Benitoite.Release.Refinement.Eff →
        List Benitoite.Release.Refinement.RangeExpr →
          List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.StandardScalar.decimalRound_represented

所在: `formal/Benitoite/Release/Refinement/StandardDecimal.lean`

```lean
∀ (c : Int) (s : Nat) (places : Int) (mode : Benitoite.Release.Refinement.StandardScalar.DecimalRounding) (d : Int)
  (t : Nat),
  Benitoite.Release.Refinement.StandardScalar.decimalRound c s places mode =
      Benitoite.Release.Refinement.StandardScalar.DecimalRoundResult.normal d t →
    Benitoite.Release.Refinement.StandardScalar.decimalRepresentable d t
```

## Benitoite.Release.Refinement.StandardScalar.decimalRound_typed

所在: `formal/Benitoite/Release/Refinement/StandardDecimal.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (c : Int) (s : Nat) (places : Int)
  (mode : Benitoite.Release.Refinement.StandardScalar.DecimalRounding) (d : Int) (t : Nat),
  Benitoite.Release.Refinement.StandardScalar.decimalRound c s places mode =
      Benitoite.Release.Refinement.StandardScalar.DecimalRoundResult.normal d t →
    Benitoite.Release.Refinement.StandardScalar.decimalRoundReply c s places mode =
        Benitoite.Release.Refinement.Outcome.val
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.decimal d t)) ∧
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.decimal d t))
          (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.decimal) ∧
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.decimal d t)).toTerm? =
            some (Benitoite.Release.Refinement.Term.decimal d t) ∧
          (Benitoite.Release.Refinement.Const.decimal d t).NumericRepresented
```

## Benitoite.Release.Refinement.StandardDecimalResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardDecimalResponse.lean`

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  (api : Benitoite.Release.Refinement.StandardDecimalResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs Benitoite.Release.Refinement.StandardDecimalResponse.program B Ψ api.name
      api.signature ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardScalar.decimalDelta api.name ts es rs ws = some out ∧
        Benitoite.Release.Refinement.Outcome.Typed Benitoite.Release.Refinement.StandardDecimalResponse.program B Ψ out
            a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardDecode.postprocess_error_steps

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} (payload : Benitoite.Release.Refinement.Val)
  (k : Benitoite.Release.Refinement.Cont) (μ : Benitoite.Release.Refinement.Store),
  ∃ q,
    Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
        Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.mk
            (Benitoite.Release.Refinement.Capture.empty.extend
              (Benitoite.Release.Refinement.Val.con "Result.Error"
                [Benitoite.Release.Refinement.StandardDecode.rawType✝,
                  Benitoite.Release.Refinement.StandardDecode.errorType✝]
                [payload]))
            Benitoite.Release.Refinement.StandardDecode.postprocessBody)
          k μ)
        [] (Benitoite.Release.Refinement.State.run q k μ) ∧
      q.view =
        Benitoite.Release.Refinement.Comp.ret
          (Benitoite.Release.Refinement.Val.con "Result.Error"
            [Benitoite.Release.Refinement.StandardDecode.wholeType,
              Benitoite.Release.Refinement.StandardDecode.errorType✝]
            [payload])
```

