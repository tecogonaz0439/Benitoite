# 使用する定義の本体と欄

具体値を評価せず、既定環境の定義を印字した。

## Benitoite.Release.Refinement.Detail

```lean
structure Benitoite.Release.Refinement.Detail (Raw : Type) : Type
number of parameters: 1
fields:
  Benitoite.Release.Refinement.Detail.failure : Benitoite.Release.Refinement.AtFailure
  Benitoite.Release.Refinement.Detail.originalPattern : Raw
  Benitoite.Release.Refinement.Detail.originalTarget : Raw
  Benitoite.Release.Refinement.Detail.parsedPattern : Option Benitoite.Release.Refinement.RangeExpr
  Benitoite.Release.Refinement.Detail.parsedTarget : Option Benitoite.Release.Refinement.TargetInput
  Benitoite.Release.Refinement.Detail.resolvedPatterns : Option (List Benitoite.Scope.Domain.Range)
  Benitoite.Release.Refinement.Detail.resolvedTarget : Option Benitoite.Scope.Domain.Target
  Benitoite.Release.Refinement.Detail.patternBase : Option Benitoite.Release.Refinement.PathBase
  Benitoite.Release.Refinement.Detail.targetBase : Option Benitoite.Release.Refinement.PathBase
constructor:
  Benitoite.Release.Refinement.Detail.mk {Raw : Type} (failure : Benitoite.Release.Refinement.AtFailure)
    (originalPattern originalTarget : Raw) (parsedPattern : Option Benitoite.Release.Refinement.RangeExpr)
    (parsedTarget : Option Benitoite.Release.Refinement.TargetInput)
    (resolvedPatterns : Option (List Benitoite.Scope.Domain.Range))
    (resolvedTarget : Option Benitoite.Scope.Domain.Target)
    (patternBase targetBase : Option Benitoite.Release.Refinement.PathBase) : Benitoite.Release.Refinement.Detail Raw
```

## Benitoite.Release.Refinement.ModelScopeConditions

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
      B.sig b = Option.some sg →
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
      B.sig b = Option.some sg →
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
      B.sig b = Option.some sg →
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
      B.sig b = Option.some sg →
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
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            ∃ out,
              B.delta b ts es rs ws = Option.some out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                    Benitoite.Release.Refinement.AdequateResult ws out
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions.io_typed : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
      (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = Option.some sg →
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
      B.sig b = Option.some sg →
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
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            ∃ out obs, B.ioResponse b ts es ws out obs
  Benitoite.Release.Refinement.Builtins.TargetAgreement.io_target : ∀ (Ψ : Benitoite.Release.Refinement.StoreTy)
      (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
      (rs : List Benitoite.Release.Refinement.RangeExpr) (ws : List Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
      (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
      B.sig b = Option.some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs P B Ψ b sg ts es rs ws a e →
            B.ioResponse b ts es ws out obs →
              Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs
  Benitoite.Release.Refinement.ModelScopeConditions.sig_scoped : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s → Benitoite.Release.Refinement.PrimSig.Scoped P s
  Benitoite.Release.Refinement.ModelScopeConditions.sat_unconstrained : ∀ (t : Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.Ty.WF 0 0 0 t → B.sat [] t.norm { }
  Benitoite.Release.Refinement.ModelScopeConditions.admits_sat : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig) (C : Benitoite.Release.Refinement.TypeCtx)
      (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = Option.some s →
        s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
          Benitoite.Release.Refinement.SatAll B C ts
            (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
  Benitoite.Release.Refinement.ModelScopeConditions.pathBases_shape : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s → s.kind = Benitoite.Release.Refinement.PrimKind.pathBases → s.PathBasesShape B b
  Benitoite.Release.Refinement.ModelScopeConditions.io_op : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          B.ShapeOk b s
  Benitoite.Release.Refinement.ModelScopeConditions.opEff_io : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
      B.sig b = Option.some s →
        s.opEff = Option.some l →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
  Benitoite.Release.Refinement.ModelScopeConditions.effect_ops : ∀ (l : Benitoite.Release.EffName)
      (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
      B.effects l = Option.some bs →
        b ∈ bs →
          ∃ s,
            B.sig b = Option.some s ∧
              (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                  s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                s.opEff = Option.some l
  Benitoite.Release.Refinement.ModelScopeConditions.state_effect : B.effects Benitoite.Release.stateEff = Option.some []
  Benitoite.Release.Refinement.ModelScopeConditions.ref_get : ∃ s,
      B.sig B.refGet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refGet
  Benitoite.Release.Refinement.ModelScopeConditions.ref_set : ∃ s,
      B.sig B.refSet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refSet
  Benitoite.Release.Refinement.ModelScopeConditions.store_shape : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s → s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
  Benitoite.Release.Refinement.ModelScopeConditions.store_admits : ∀ (b : Benitoite.Release.PrimName)
      (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
      (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = Option.some s →
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
        B.sig b = Option.some s → Benitoite.Release.Refinement.PrimSig.Scoped P s)
    (sat_unconstrained :
      ∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.Ty.WF 0 0 0 t → B.sat [] t.norm { })
    (admits_sat :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
        (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
        B.sig b = Option.some s →
          s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
            Benitoite.Release.Refinement.SatAll B C ts
              (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams))
    (pathBases_shape :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = Option.some s → s.kind = Benitoite.Release.Refinement.PrimKind.pathBases → s.PathBasesShape B b)
    (io_op :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = Option.some s →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
            B.ShapeOk b s)
    (opEff_io :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
        B.sig b = Option.some s →
          s.opEff = Option.some l →
            s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases)
    (effect_ops :
      ∀ (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
        B.effects l = Option.some bs →
          b ∈ bs →
            ∃ s,
              B.sig b = Option.some s ∧
                (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                      s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                  s.opEff = Option.some l)
    (state_effect : B.effects Benitoite.Release.stateEff = Option.some [])
    (ref_get : ∃ s, B.sig B.refGet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refGet)
    (ref_set : ∃ s, B.sig B.refSet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refSet)
    (store_shape :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
        B.sig b = Option.some s → s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape)
    (store_admits :
      ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
        (ts : List Benitoite.Release.Refinement.Ty),
        B.sig b = Option.some s →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
            s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
              s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
                s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases →
                  ts.length = s.tparams.length → s.admits C ts) :
    Benitoite.Release.Refinement.ModelScopeConditions P B
field notation resolution order:
  Benitoite.Release.Refinement.ModelScopeConditions, Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions, Benitoite.Release.Refinement.Builtins.ResponseAssumptions, Benitoite.Release.Refinement.Builtins.TargetAgreement, Benitoite.Release.Refinement.Builtins.ValueAssumptions, Benitoite.Release.Refinement.Builtins.TypeAssumptions
```

## Benitoite.Release.Refinement.Builtins.ShapeOk

```lean
def Benitoite.Release.Refinement.Builtins.ShapeOk : Benitoite.Release.Refinement.Builtins →
  Benitoite.Release.PrimName → Benitoite.Release.Refinement.PrimSig → Prop :=
fun B b s =>
  ∃ l bs,
    s.opEff = Option.some l ∧
      s.neffs = 0 ∧
        B.effects l = Option.some bs ∧
          b ∈ bs ∧
            match s.shape with
            | Benitoite.Scope.Signature.IOShape.untargeted =>
              B.effKind l = Option.none ∧ s.rkinds = [] ∧ s.eff = Benitoite.Release.Refinement.Eff.single l
            | Benitoite.Scope.Signature.IOShape.topTargeted k =>
              B.effKind l = Option.some k ∧ s.rkinds = [] ∧ s.eff = Benitoite.Release.Refinement.Eff.single l
            | Benitoite.Scope.Signature.IOShape.single k p =>
              B.effKind l = Option.some k ∧
                s.rkinds = [k] ∧
                  s.eff =
                      Benitoite.Release.Refinement.EffR.mk
                        (fun a =>
                          Decidable.decide
                            (a =
                              Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.rvar 0)))
                        [] ∧
                    ∃ o,
                      s.params[p]? =
                          Option.some
                            (Benitoite.Release.Refinement.Ty.opaque o (Benitoite.Release.Refinement.RangeIx.rvar 0)) ∧
                        B.valKind o = Option.some k
```

## Benitoite.Release.Refinement.Eff.Allows

```lean
def Benitoite.Release.Refinement.Eff.Allows : Benitoite.Release.Refinement.PathEnv →
  (Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind) →
    Benitoite.Release.Refinement.Eff → Benitoite.Release.EffName → Benitoite.Scope.Domain.Target → Prop :=
fun σ κ e l t =>
  ∃ k r,
    κ l = Option.some k ∧
      e.mem (Benitoite.Release.Refinement.Atom.name l (Benitoite.Release.Refinement.RangeIx.fixed r)) ∧
        Benitoite.Release.Refinement.RangeExpr.Mem σ k r t
```

## Benitoite.Release.Refinement.Val.Source

```lean
def Benitoite.Release.Refinement.Val.Source : Benitoite.Release.Refinement.Val → Prop :=
fun x =>
  x.brecOn Benitoite.Release.Refinement.Val.Source._f Benitoite.Release.Refinement.Comp.Source._f
    (fun t f => PUnit.unit) (fun t f => PUnit.unit) (fun t f => PUnit.unit) (fun t f => PUnit.unit)
    Benitoite.Release.Refinement.sourceVals._f (fun t f => PUnit.unit) (fun t f => PUnit.unit)
    Benitoite.Release.Refinement.sourceArms._f Benitoite.Release.Refinement.sourceClauses._f (fun t f => PUnit.unit)
    fun t f => PUnit.unit
```

## Benitoite.Release.Refinement.Comp.Source

```lean
def Benitoite.Release.Refinement.Comp.Source : Benitoite.Release.Refinement.Comp → Prop :=
fun x =>
  x.brecOn Benitoite.Release.Refinement.Val.Source._f Benitoite.Release.Refinement.Comp.Source._f
    (fun t f => PUnit.unit) (fun t f => PUnit.unit) (fun t f => PUnit.unit) (fun t f => PUnit.unit)
    Benitoite.Release.Refinement.sourceVals._f (fun t f => PUnit.unit) (fun t f => PUnit.unit)
    Benitoite.Release.Refinement.sourceArms._f Benitoite.Release.Refinement.sourceClauses._f (fun t f => PUnit.unit)
    fun t f => PUnit.unit
```

## Benitoite.Release.Refinement.ScopeResponse.delta

```lean
def Benitoite.Release.Refinement.ScopeResponse.delta : Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.RangeExpr →
        List Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Outcome :=
fun b ts es rs ws =>
  if b = "Scope.checkPathIn" then Benitoite.Release.Refinement.ScopeDelta.delta b ts es rs ws
  else
    if b = "Http.checkRequestIn" then Benitoite.Release.Refinement.RequestDelta.delta b ts es rs ws
    else
      if b = "Scope.pathInValue" ∨ b = "Scope.widenPathIn" then
        Benitoite.Release.Refinement.ScopeDelta.valueDelta b ts es rs ws
      else
        if b = "Http.requestInValue" ∨ b = "Http.widenRequestIn" then
          Benitoite.Release.Refinement.RequestDelta.valueDelta b ts es rs ws
        else Option.none
```

## Benitoite.Release.Refinement.ScopedIOResponse.ioResponse

```lean
def Benitoite.Release.Refinement.ScopedIOResponse.ioResponse : Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop :=
fun b ts es ws out obs =>
  ∃ op,
    b = op.name ∧
      ts = [] ∧
        es = [] ∧
          Benitoite.Release.Refinement.ScopedIOResponse.Reply op.output out ∧
            ∃ t,
              ws[0]?.bind Benitoite.Release.Refinement.Val.target? = Option.some t ∧
                t.kind = op.kind ∧ obs = [t] ∧ Benitoite.Release.Refinement.ScopedIOResponse.RequestSent op ws t
```

## Benitoite.Release.Refinement.Builtins.ExternalAssumptions

```lean
structure Benitoite.Release.Refinement.Builtins.ExternalAssumptions (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) : Prop
number of parameters: 2
fields:
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_typed : ∀
      (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = Option.some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
            B.externalResponse f ts vs out obs →
              Benitoite.Release.Refinement.Outcome.Carrier P B Ψ out a ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists : ∀
      (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      P.ExternalWF →
        P.externalFunction f = Option.some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → ∃ out obs, B.externalResponse f ts vs out obs
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_no_targets : ∀
      (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
      (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
      (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      P.ExternalWF →
        P.externalFunction f = Option.some d →
          Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → B.externalResponse f ts vs out obs → obs = []
constructor:
  Benitoite.Release.Refinement.Builtins.ExternalAssumptions.mk {P : Benitoite.Release.Refinement.Program}
    {B : Benitoite.Release.Refinement.Builtins}
    (external_typed :
      ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
        (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
        (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
        (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        P.ExternalWF →
          P.externalFunction f = Option.some d →
            Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
              B.externalResponse f ts vs out obs →
                Benitoite.Release.Refinement.Outcome.Carrier P B Ψ out a ∧
                  ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n)
    (external_exists :
      ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
        (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
        (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
        (e : Benitoite.Release.Refinement.Eff),
        P.ExternalWF →
          P.externalFunction f = Option.some d →
            Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e → ∃ out obs, B.externalResponse f ts vs out obs)
    (external_no_targets :
      ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (f : Benitoite.Release.Refinement.ExternalFunctionId)
        (d : Benitoite.Release.Refinement.ExternalSignature) (ts : List Benitoite.Release.Refinement.Ty)
        (vs : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
        (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        P.ExternalWF →
          P.externalFunction f = Option.some d →
            Benitoite.Release.Refinement.ExternalArgs P B Ψ d ts vs a e →
              B.externalResponse f ts vs out obs → obs = []) :
    Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B
```

