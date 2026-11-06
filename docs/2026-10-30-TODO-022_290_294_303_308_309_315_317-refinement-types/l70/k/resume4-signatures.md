# 前段の署名の完全な差

理由と系の条件は [結果](results.md#前段の署名の差再開4) の表に置く。以下は開始時の入力と候補の本番の入力から写した完全な宣言である。`case_C_Match` の名前空間は `S02Internal`、`handle_case` は `LegacyCompCases`、他の共通の名前空間は `Benitoite.Release.Refinement` である。

## Def.WellTyped.inputs

元の署名:

```lean
theorem Def.WellTyped.inputs {P B d} (h : Def.WellTyped P B d) :
    Ctx.Regular P d.tparams (d.tel.context []) ∧
    d.body.Inputs P B StoreTy.empty (QTel d.tel) d.tparams
      (d.tel.context []) (liftMany d.tel.arity [])
      (some d.tel.result) d.tel.result d.tel.effect []
```

新しい署名:

```lean
theorem Def.WellTyped.inputs {P B d} (h : Def.WellTyped P B d) :
    ∀ rs : List RangeExpr, d.RangeAdmissible rs →
      Ctx.Regular P d.tparams ((d.instTel rs).context []) ∧
      (d.body.instR rs).Inputs P B StoreTy.empty (QTel d.tel) d.tparams
        ((d.instTel rs).context []) (liftMany (d.instTel rs).arity [])
        (some (d.instTel rs).result) (d.instTel rs).result (d.instTel rs).effect []
```

系の完全名: `Benitoite.Release.Refinement.Def.WellTyped.inputs_no_ranges`。

```lean
theorem Def.WellTyped.inputs_no_ranges {P B d} (h : Def.WellTyped P B d)
    (hk : d.rkinds = []) :
    Ctx.Regular P d.tparams (d.tel.context []) ∧
    d.body.Inputs P B StoreTy.empty (QTel d.tel) d.tparams
      (d.tel.context []) (liftMany d.tel.arity [])
      (some d.tel.result) d.tel.result d.tel.effect []
```

## HasTypeVQ.canonical_function

元の署名:

```lean
theorem HasTypeVQ.canonical_function {P B Ψ Q C Φ v T t}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.fnCore = some t) :
    (∃ f ts es, v = .fnRef f ts es) ∨
      (∃ b ts es rs, v = .prim b ts es rs) ∨
      (∃ o ts, v = .op o ts) ∨
      (∃ ns ps body, v = .lam ns ps body) ∨
      (∃ t body, v = .dependentLam t body) ∨
      (∃ runtime body, v = .closure runtime body) ∨
      (∃ t e, v = .raise t e) ∨ (∃ f ts, v = .externalRef f ts)
```

新しい署名:

```lean
theorem HasTypeVQ.canonical_function {P B Ψ Q C Φ v T t}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.fnCore = some t) :
    (∃ f ts es, ∃ rs : List RangeExpr, v = .fnRef f ts es (rs.map RangeIx.fixed)) ∨
      (∃ b ts es rs, v = .prim b ts es (List.map RangeIx.fixed rs)) ∨
      (∃ o ts, v = .op o ts) ∨
      (∃ ns ps body, v = .lam ns ps body) ∨
      (∃ t body, v = .dependentLam t body) ∨
      (∃ runtime body, v = .closure runtime body) ∨
      (∃ t e, v = .raise t e) ∨ (∃ f ts, v = .externalRef f ts)
```

系の完全名: `Benitoite.Release.Refinement.HasTypeVQ.canonical_function_no_ranges`。

```lean
theorem HasTypeVQ.canonical_function_no_ranges {P B Ψ Q C Φ v T t}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.fnCore = some t)
    (hempty : ∀ f ts es rs, v = .fnRef f ts es rs → rs = []) :
    (∃ f ts es, v = .fnRef f ts es) ∨
      (∃ b ts es rs, v = .prim b ts es rs) ∨
      (∃ o ts, v = .op o ts) ∨
      (∃ ns ps body, v = .lam ns ps body) ∨
      (∃ t body, v = .dependentLam t body) ∨
      (∃ runtime body, v = .closure runtime body) ∨
      (∃ t e, v = .raise t e) ∨ (∃ f ts, v = .externalRef f ts)
```

## HasTypeCQ.match_legacy

元の署名:

```lean
theorem HasTypeCQ.match_legacy {P B Ψ Q C Γ Φ R v arms a b e L}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R none arms a b e L)
    (hx : Exhaustive P a (unguardedPats arms)) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b e L
```

新しい署名:

```lean
theorem HasTypeCQ.match_legacy {P B Ψ Q C Γ Φ R v arms a b e L}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R none arms a b e L)
    (hd : Ty.Declared P C Γ a)
    (hx : Exhaustive P a (unguardedPats arms)) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b e L
```

系の完全名: `Benitoite.Release.Refinement.LegacyCompCases.match_case`。

```lean
theorem match_case {K P0 B0 B κ Ψ Q C Γ R v arms a b e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a))
    (coverage : Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a))
    (body : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.match v arms) b e L)
```

## case_C_Match

元の署名:

```lean
theorem case_C_Match :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a b : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    (∀ (t : Benitoite.Release.Refinement.Term), obs = some t → v.toTerm? = some t ∧ ∃ s, Term.HasSort Γ t s) →
      HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
        Exhaustive P a (unguardedPats arms) →
          VGoal P B Ψ Q C Γ Φ v a →
            ArmsGoal P B Ψ Q C Γ Φ R obs arms a b ε Δ → CGoal P B Ψ Q C Γ Φ R (Comp.match v arms) b ε Δ
```

新しい署名:

```lean
theorem case_C_Match :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a b : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    (∀ (t : Benitoite.Release.Refinement.Term), obs = some t → v.toTerm? = some t ∧ ∃ s, Term.HasSort Γ t s) →
      HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
        Ty.Declared P C Γ a →
        Exhaustive P a (unguardedPats arms) →
          VGoal P B Ψ Q C Γ Φ v a →
            ArmsGoal P B Ψ Q C Γ Φ R obs arms a b ε Δ → CGoal P B Ψ Q C Γ Φ R (Comp.match v arms) b ε Δ
```

系の完全名: `Benitoite.Release.Refinement.LegacyCompCases.match_type_subst`。

```lean
theorem match_type_subst {K P0 B0 B κ Ψ Q C Γ R v arms a b e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a))
    (coverage : Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a))
    (body : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    ∀ Φ, S02Internal.CGoal (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
      (embedComp (.match v arms)) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind))
```

## Program.ExtendsTypingStatement

元の署名:

```lean
def Program.ExtendsTypingStatement (P P' : Program) (B : Builtins) : Prop :=
  Program.Extends P P' → Program.FreshEffects P P' B → P.WellFormed →
    (∀ Ψ Q C Γ Φ v a, Ctx.Declared P C Γ → HasTypeVQ P B Ψ Q C Γ Φ v a → HasTypeVQ P' B Ψ Q C Γ Φ v a) ∧
    (∀ Ψ Q C Γ Φ R m a ε Δ, Ctx.Declared P C Γ → HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
      HasTypeCQ P' B Ψ Q C Γ Φ R m a ε Δ)

/-- 旧宣言の網羅性の移送。P で宣言済みの型について、網羅性は P と P' で同じである。 -/
```

新しい署名:

```lean
def Program.ExtendsTypingStatement (P P' : Program) (B : Builtins) : Prop :=
  Program.Extends P P' → Program.FreshEffects P P' B → P.WellFormed →
    (∀ Ψ Q C Γ Φ v a, HasTypeVQ P B Ψ Q C Γ Φ v a → HasTypeVQ P' B Ψ Q C Γ Φ v a) ∧
    (∀ Ψ Q C Γ Φ R m a ε Δ, HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
      HasTypeCQ P' B Ψ Q C Γ Φ R m a ε Δ)

/-- 旧宣言の網羅性の移送。P で宣言済みの型について、網羅性は P と P' で同じである。 -/
```

系の完全名: `Benitoite.Release.Refinement.Program.extends_typing_declared_context`。

```lean
theorem Program.extends_typing_declared_context {P P' : Program} {B : Builtins}
    (h : P.Extends P') (hf : Program.FreshEffects P P' B) (hwf : P.WellFormed) :
    (∀ Ψ Q C Γ Φ v a, Ctx.Declared P C Γ → HasTypeVQ P B Ψ Q C Γ Φ v a →
      HasTypeVQ P' B Ψ Q C Γ Φ v a) ∧
    (∀ Ψ Q C Γ Φ R m a ε Δ, Ctx.Declared P C Γ → HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
      HasTypeCQ P' B Ψ Q C Γ Φ R m a ε Δ)
```

## legacy_handled_sub

元の署名:

```lean
theorem legacy_handled_sub {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    (cs : List Benitoite.Release.Clause) :
    Eff.Sub (embedEff (Benitoite.Release.handled P0 B0 cs))
      (handled (embedProgramWithKinds K P0) B (embedClauses cs))
```

新しい署名:

```lean
theorem legacy_handled_sub {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    (cs : List Benitoite.Release.Clause) {Δ}
    (input : LegacyClausesInput K P0 B0 B Δ cs) :
    Eff.Sub (embedEff (Benitoite.Release.handled P0 B0 cs))
      (handled (embedProgramWithKinds K P0) B (embedClauses cs))
```

系の完全名: `Benitoite.Release.Refinement.embedHasTypeCQ`。

```lean
theorem embedHasTypeCQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.comp κ Ψ Q C Γ R m a e L) →
      ∀ Φ : List Pred, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))
```

## handle_case

元の署名:

```lean
theorem handle_case {K P0 B0 B κ Ψ Q C Γ R m cs t em e L}
    (tables : LegacyTables K P0 B0 B)
    (sub : Benitoite.Release.Eff.Sub em (Benitoite.Release.Eff.union e (Benitoite.Release.handled P0 B0 cs)))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m t em L))
    (clauses : LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R em cs t e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.handle m cs) t e L)
```

新しい署名:

```lean
theorem handle_case {K P0 B0 B κ Ψ Q C Γ R m cs t em e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyClausesInput K P0 B0 B ⟨κ,C,0,Γ.length⟩ cs)
    (sub : Benitoite.Release.Eff.Sub em (Benitoite.Release.Eff.union e (Benitoite.Release.handled P0 B0 cs)))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m t em L))
    (clauses : LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R em cs t e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.handle m cs) t e L)
```

系の完全名: `Benitoite.Release.Refinement.LegacyRule.embed_comp`。

```lean
theorem LegacyRule.embed_comp {K P0 B0 B κ Ψ Q C Γ R m a e L children}
    (rule : LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R m a e L) children)
    (kinds : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R m a e L))
    (inputs : ∀ child ∈ children, LegacyOutputInput K P0 B0 B child)
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L)
```

