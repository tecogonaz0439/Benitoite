# 群 B の一般署名

任意の入力を量化する本番の実型。その他の追加宣言は declarations.json に記録する。

```lean
Benitoite.Release.Refinement.PathPattern.Covers.mem_atBase :
∀ {p q : Benitoite.Scope.Domain.PathPattern},
  p.Covers q →
    ∀ (w : Benitoite.Scope.Domain.Word) {t : Benitoite.Scope.Domain.Target},
      (Benitoite.Scope.Domain.Range.path (Benitoite.Release.Refinement.PathPattern.atBase w q)).Mem t →
        (Benitoite.Scope.Domain.Range.path (Benitoite.Release.Refinement.PathPattern.atBase w p)).Mem t
```

```lean
Benitoite.Release.Refinement.RangeIx.Covers.inst_mem :
∀ {outer inner : Benitoite.Release.Refinement.RangeIx},
  outer.Covers inner →
    ∀ (rs : List Benitoite.Release.Refinement.RangeExpr) {r : Benitoite.Release.Refinement.RangeExpr},
      Benitoite.Release.Refinement.RangeIx.inst rs inner = Benitoite.Release.Refinement.RangeIx.fixed r →
        ∀ (σ : Benitoite.Release.Refinement.PathEnv) {k : Benitoite.Scope.Domain.Kind}
          {t : Benitoite.Scope.Domain.Target},
          Benitoite.Release.Refinement.RangeExpr.Mem σ k r t →
            ∃ s,
              Benitoite.Release.Refinement.RangeIx.inst rs outer = Benitoite.Release.Refinement.RangeIx.fixed s ∧
                Benitoite.Release.Refinement.RangeExpr.Mem σ k s t
```

```lean
Benitoite.Release.Refinement.Pred.member_mono :
∀ {η : Benitoite.Release.Refinement.ObservationEnvModel} {k : Benitoite.Scope.Domain.Kind}
  {a : Benitoite.Release.Refinement.Term} {r s : Benitoite.Release.Refinement.RangeExpr},
  s.Covers r →
    Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a r) = true →
      Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a s) = true
```

```lean
Benitoite.Release.Refinement.Pred.member_inst_mono :
∀ {η : Benitoite.Release.Refinement.ObservationEnvModel} {k : Benitoite.Scope.Domain.Kind}
  {a : Benitoite.Release.Refinement.Term} {outer inner : Benitoite.Release.Refinement.RangeIx},
  outer.Covers inner →
    ∀ (rs : List Benitoite.Release.Refinement.RangeExpr) {r : Benitoite.Release.Refinement.RangeExpr},
      Benitoite.Release.Refinement.RangeIx.inst rs inner = Benitoite.Release.Refinement.RangeIx.fixed r →
        Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a r) = true →
          ∃ s,
            Benitoite.Release.Refinement.RangeIx.inst rs outer = Benitoite.Release.Refinement.RangeIx.fixed s ∧
              Benitoite.Release.Refinement.Pred.interpret η (Benitoite.Release.Refinement.Pred.member k a s) = true
```

```lean
Benitoite.Release.Refinement.Eff.Covers.allows :
∀ {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {e f : Benitoite.Release.Refinement.Eff} {σ : Benitoite.Release.Refinement.PathEnv}
  {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
  {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Covers Γ Φ e f →
    Benitoite.Release.Refinement.Eff.Allows σ κ f l t → Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

```lean
Benitoite.Release.Refinement.Eff.allows_bind :
∀ (θ : Benitoite.Release.Refinement.SubstEnv) (e : Benitoite.Release.Refinement.Eff)
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind θ e) l t ↔
    (∃ k ix r,
        κ l = some k ∧
          e.mem (Benitoite.Release.Refinement.Atom.name l ix) ∧
            Benitoite.Release.Refinement.RangeIx.inst θ.ranges ix = Benitoite.Release.Refinement.RangeIx.fixed r ∧
              Benitoite.Release.Refinement.RangeExpr.Mem σ k r t) ∨
      ∃ i f,
        θ.rows[i]? = some f ∧
          e.mem (Benitoite.Release.Refinement.Atom.rho i) ∧ Benitoite.Release.Refinement.Eff.Allows σ κ f l t
```

```lean
Benitoite.Release.Refinement.Eff.allows_bind_of_rows_nil :
∀ {θ : Benitoite.Release.Refinement.SubstEnv},
  θ.rows = [] →
    ∀ (e : Benitoite.Release.Refinement.Eff) {σ : Benitoite.Release.Refinement.PathEnv}
      {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
      {t : Benitoite.Scope.Domain.Target},
      Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind θ e) l t ↔
        ∃ k ix r,
          κ l = some k ∧
            e.mem (Benitoite.Release.Refinement.Atom.name l ix) ∧
              Benitoite.Release.Refinement.RangeIx.inst θ.ranges ix = Benitoite.Release.Refinement.RangeIx.fixed r ∧
                Benitoite.Release.Refinement.RangeExpr.Mem σ k r t
```

```lean
Benitoite.Release.Refinement.Eff.allows_bind_of_rows_ranges_nil :
∀ {θ : Benitoite.Release.Refinement.SubstEnv},
  θ.rows = [] →
    θ.ranges = [] →
      ∀ (e : Benitoite.Release.Refinement.Eff) {σ : Benitoite.Release.Refinement.PathEnv}
        {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind} {l : Benitoite.Release.EffName}
        {t : Benitoite.Scope.Domain.Target},
        Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.bind θ e) l t ↔
          Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

```lean
Benitoite.Release.Refinement.Eff.allows_substAt_nil :
∀ (c : Nat) (ts : List Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff)
  {σ : Benitoite.Release.Refinement.PathEnv} {κ : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind}
  {l : Benitoite.Release.EffName} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Eff.Allows σ κ (Benitoite.Release.Refinement.Eff.substAt c ts [] e) l t ↔
    Benitoite.Release.Refinement.Eff.Allows σ κ e l t
```

