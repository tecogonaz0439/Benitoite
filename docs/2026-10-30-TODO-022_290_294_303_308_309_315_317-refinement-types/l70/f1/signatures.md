# 群 F1 の必須の宣言の署名

公理監査（axioms.lean）の生の出力から verify.py が書き出した。名前の接頭辞 `Benitoite.Release.Refinement.` を省く。

## `RangeExpr.fitsKind_host_iff`

Benitoite.Release.Refinement.HostRangeParams、23行。

```lean
∀ (r : RangeExpr),
  r.FitsKind Benitoite.Scope.Domain.Kind.host ↔
    r = RangeExpr.absolute Benitoite.Scope.Domain.Range.top ∨
      ∃ p, r = RangeExpr.host p
```

## `RangeExpr.host_absolute`

Benitoite.Release.Refinement.HostRangeParams、29行。

```lean
∀ {r : RangeExpr},
  r.FitsKind Benitoite.Scope.Domain.Kind.host →
    ∃ q,
      r = RangeExpr.absolute q ∧
        q.FitsKind Benitoite.Scope.Domain.Kind.host ∧
          ∀ (σ : PathEnv),
            RangeExpr.resolve σ r = Option.some [q]
```

## `RangeExpr.mem_host_env`

Benitoite.Release.Refinement.HostRangeParams、36行。

```lean
∀ {r : RangeExpr},
  r.FitsKind Benitoite.Scope.Domain.Kind.host →
    ∀ (σ σ' : PathEnv) (k : Benitoite.Scope.Domain.Kind)
      (t : Benitoite.Scope.Domain.Target),
      RangeExpr.Mem σ k r t ↔ RangeExpr.Mem σ' k r t
```

## `RangeExpr.snapshotMem_host`

Benitoite.Release.Refinement.HostRangeParams、42行。

```lean
∀ {r : RangeExpr},
  r.FitsKind Benitoite.Scope.Domain.Kind.host →
    ∀ (σ : PathEnv) (t : Benitoite.Scope.Domain.Target),
      SnapshotMem (Option.some σ) Benitoite.Scope.Domain.Kind.host r t ↔
        σ.Valid ∧ SnapshotMem Option.none Benitoite.Scope.Domain.Kind.host r t
```

## `RangeExpr.covers_host_iff`

Benitoite.Release.Refinement.HostRangeParams、51行。

```lean
∀ {r s : RangeExpr},
  r.FitsKind Benitoite.Scope.Domain.Kind.host →
    s.FitsKind Benitoite.Scope.Domain.Kind.host →
      s.WF →
        (r.Covers s ↔
          ∀ (σ : PathEnv) (t : Benitoite.Scope.Domain.Target),
            RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.host s t →
              RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.host r t)
```

## `Builtins.RangeAdmissible.host_image`

Benitoite.Release.Refinement.HostRangeParams、80行。

```lean
∀ {B : Builtins} {b : Benitoite.Release.PrimName}
  {s : PrimSig} {rs : List RangeExpr},
  B.RangeAdmissible b s rs →
    ∀ {i : Nat} {r : RangeExpr},
      s.rkinds[i]? = Option.some Benitoite.Scope.Domain.Kind.host →
        rs[i]? = Option.some r →
          r = RangeExpr.absolute Benitoite.Scope.Domain.Range.top ∨
            ∃ p, r = RangeExpr.host p ∧ p.WF ∧ p.Canonical
```

## `Builtins.RangeAdmissible.single_host_iff`

Benitoite.Release.Refinement.HostRangeParams、91行。

```lean
∀ {B : Builtins} {b : Benitoite.Release.PrimName}
  {s : PrimSig},
  s.rkinds = [Benitoite.Scope.Domain.Kind.host] →
    ∀ (r : RangeExpr),
      B.RangeAdmissible b s [r] ↔
        r = RangeExpr.absolute Benitoite.Scope.Domain.Range.top ∨
          ∃ p, r = RangeExpr.host p ∧ p.WF ∧ p.Canonical ∧ B.admitsR b [r]
```

## `Ty.instR_scoped_rvar`

Benitoite.Release.Refinement.HostRangeParams、124行。

```lean
∀ (rs : List RangeExpr) (o : Benitoite.Release.OpaqueName)
  (k : Benitoite.Scope.Domain.Kind) {i : Nat} {r : RangeExpr},
  rs[i]? = Option.some r →
    Ty.instR rs
        (Ty.scoped o k (RangeIx.rvar i)) =
      Ty.scoped o k (RangeIx.fixed r)
```

## `Ty.LeQ.scoped_host_of_mem`

Benitoite.Release.Refinement.HostRangeParams、129行。

```lean
∀ {P : Program} {Γ : Ctx}
  {Φ : List Pred} {o : Benitoite.Release.OpaqueName}
  {r s : RangeExpr},
  r.FitsKind Benitoite.Scope.Domain.Kind.host →
    s.FitsKind Benitoite.Scope.Domain.Kind.host →
      s.WF →
        (∀ (σ : PathEnv) (t : Benitoite.Scope.Domain.Target),
            RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.host s t →
              RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.host r t) →
          Ty.LeQ P Γ Φ
            (Ty.scoped o Benitoite.Scope.Domain.Kind.host
              (RangeIx.fixed s))
            (Ty.scoped o Benitoite.Scope.Domain.Kind.host
              (RangeIx.fixed r))
```

## `mappedBlock`

Benitoite.Release.Refinement.MappedHostPatterns、26行。

```lean
Benitoite.Scope.Domain.IPPattern
```

## `mappedBlock_matches_iff`

Benitoite.Release.Refinement.MappedHostPatterns、29行。

```lean
∀ (a : Benitoite.Scope.Domain.IPAddr),
  mappedBlock.Matches a ↔
    isIPv4MappedHost (Benitoite.Scope.Domain.HostTarget.ip a) = Bool.true
```

## `IPPattern.MappedOnly`

Benitoite.Release.Refinement.MappedHostPatterns、40行。

```lean
Benitoite.Scope.Domain.IPPattern → Prop
```

## `IPPattern.mappedOnly_iff`

Benitoite.Release.Refinement.MappedHostPatterns、46行。

```lean
∀ (p : Benitoite.Scope.Domain.IPPattern),
  IPPattern.MappedOnly p ↔
    p.WF ∧
      p.Canonical ∧
        ∀ (a : Benitoite.Scope.Domain.IPAddr),
          p.Matches a →
            isIPv4MappedHost (Benitoite.Scope.Domain.HostTarget.ip a) = Bool.true
```

## `IPPattern.mappedOnly_exact_iff`

Benitoite.Release.Refinement.MappedHostPatterns、56行。

```lean
∀ (a : Benitoite.Scope.Domain.IPAddr),
  IPPattern.MappedOnly (Benitoite.Scope.Domain.IPPattern.exact a) ↔
    isIPv4MappedHost (Benitoite.Scope.Domain.HostTarget.ip a) = Bool.true
```

## `IPPattern.mappedOnly_cidr_iff`

Benitoite.Release.Refinement.MappedHostPatterns、69行。

```lean
∀ (c : Benitoite.Scope.Domain.CIDR),
  IPPattern.MappedOnly (Benitoite.Scope.Domain.IPPattern.cidr c) ↔
    c.WF ∧
      c.prefixLen < c.family.width ∧
        c.family = Benitoite.Scope.Domain.Family.v6 ∧ 96 ≤ c.prefixLen ∧ ↑c.network / 2 ^ 32 = 65535
```

## `HostPattern.MappedOnly`

Benitoite.Release.Refinement.MappedHostPatterns、96行。

```lean
Benitoite.Scope.Domain.HostPattern → Prop
```

## `HostPattern.mappedOnly_iff`

Benitoite.Release.Refinement.MappedHostPatterns、104行。

```lean
∀ (p : Benitoite.Scope.Domain.HostPattern),
  HostPattern.MappedOnly p ↔
    p.WF ∧
      p.Canonical ∧
        ∀ (t : Benitoite.Scope.Domain.HostTarget),
          p.Matches t → isIPv4MappedHost t = Bool.true
```

## `RangeExpr.hostPattern?`

Benitoite.Release.Refinement.MappedHostPatterns、124行。

```lean
RangeExpr → Option Benitoite.Scope.Domain.HostPattern
```

## `RangeExpr.MappedHostOnly`

Benitoite.Release.Refinement.MappedHostPatterns、130行。

```lean
RangeExpr → Prop
```

## `RangeExpr.MappedHostOnly.cases`

Benitoite.Release.Refinement.MappedHostPatterns、140行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    (∃ p,
        r = RangeExpr.absolute (Benitoite.Scope.Domain.Range.host p) ∧
          HostPattern.MappedOnly p) ∨
      ∃ e,
        r = RangeExpr.absolute (Benitoite.Scope.Domain.Range.endpoint e) ∧
          e.WF ∧ HostPattern.MappedOnly e.host
```

## `RangeExpr.MappedHostOnly.target_mapped`

Benitoite.Release.Refinement.MappedHostPatterns、150行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {σ : PathEnv} {k : Benitoite.Scope.Domain.Kind} {t : Benitoite.Scope.Domain.Target},
      RangeExpr.Mem σ k r t →
        ∃ host,
          (t = Benitoite.Scope.Domain.Target.host host ∨
              ∃ port, t = Benitoite.Scope.Domain.Target.endpoint { host := host, port := port }) ∧
            isIPv4MappedHost host = Bool.true
```

## `parseUrlTarget_not_mapped`

Benitoite.Release.Refinement.MappedHostPatterns、164行。

```lean
∀ {s : String} {e : Benitoite.Scope.Domain.Endpoint},
  parseUrlTarget s = Option.some (Benitoite.Scope.Domain.Target.endpoint e) →
    isIPv4MappedHost e.host = Bool.false
```

## `RangeExpr.MappedHostOnly.not_url_target`

Benitoite.Release.Refinement.MappedHostPatterns、179行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {σ : PathEnv} {k : Benitoite.Scope.Domain.Kind} {s : String}
      {t : Benitoite.Scope.Domain.Target},
      parseUrlTarget s = Option.some t →
        ¬RangeExpr.Mem σ k r t
```

## `RangeExpr.MappedHostOnly.not_request_target`

Benitoite.Release.Refinement.MappedHostPatterns、190行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {σ : PathEnv} {k : Benitoite.Scope.Domain.Kind}
      {v : Val} {t : Benitoite.Scope.Domain.Target},
      v.reqTarget = Option.some t → ¬RangeExpr.Mem σ k r t
```

## `RangeExpr.MappedHostOnly.witness`

Benitoite.Release.Refinement.MappedHostPatterns、198行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {k : Benitoite.Scope.Domain.Kind},
      r.FitsKind k → ∃ t, t.kind = k ∧ t.WF ∧ SnapshotMem Option.none k r t
```

## `RangeExpr.MappedHostOnly.member_true`

Benitoite.Release.Refinement.MappedHostPatterns、220行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {k : Benitoite.Scope.Domain.Kind},
      r.FitsKind k →
        ∃ t,
          Pred.evalWith
              (selfModel (fun x => Option.none)
                (Val.checked t))
              (Pred.member k (Term.var 0) r) =
            Option.some Bool.true
```

## `RangeExpr.MappedHostOnly.not_refuted`

Benitoite.Release.Refinement.MappedHostPatterns、232行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {k : Benitoite.Scope.Domain.Kind},
      r.FitsKind k →
        ¬Entails
            [Pred.member k (Term.var 0) r]
            Pred.falsity
```

## `RangeExpr.MappedHostOnly.not_exhaustive_nil`

Benitoite.Release.Refinement.MappedHostPatterns、244行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {k : Benitoite.Scope.Domain.Kind},
      r.FitsKind k →
        ∀ (P : Program) (o : Benitoite.Release.OpaqueName)
          (ix : RangeIx),
          ¬Exhaustive P
              ((Ty.scoped o k ix).refined
                (Pred.member k (Term.var 0) r))
              []
```

## `RangeExpr.MappedHostOnly.scopePattern_typed`

Benitoite.Release.Refinement.MappedHostPatterns、255行。

```lean
∀ {r : RangeExpr},
  r.MappedHostOnly →
    ∀ {k : Benitoite.Scope.Domain.Kind},
      r.FitsKind k →
        ∀ {P : Program} {B : Builtins}
          {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx}
          {C : TypeCtx} {Γ : Ctx}
          {Φ : List Pred},
          HasTypeVQ P B Ψ Q C Γ Φ (Val.scopePattern r)
            (Ty.scopePattern k)
```

## `PathBasesDiffer`

Benitoite.Release.Refinement.PathBaseDifference、22行。

```lean
RangeExpr → TargetInput → Prop
```

## `OutsideAllEnvs`

Benitoite.Release.Refinement.PathBaseDifference、32行。

```lean
RangeExpr → TargetInput → Prop
```

## `TargetInput.basedPath?`

Benitoite.Release.Refinement.PathBaseDifference、36行。

```lean
TargetInput → Option (PathBase × Benitoite.Scope.Domain.Word)
```

## `TargetInput.base?_eq_basedPath?`

Benitoite.Release.Refinement.PathBaseDifference、42行。

```lean
∀ (t : TargetInput), t.base? = Option.map Prod.fst t.basedPath?
```

## `PathBasesDiffer.based`

Benitoite.Release.Refinement.PathBaseDifference、46行。

```lean
∀ {p : RangeExpr} {t : TargetInput},
  PathBasesDiffer p t →
    ∃ b pat c w, p = RangeExpr.based b pat ∧ t.basedPath? = Option.some (c, w) ∧ b ≠ c
```

## `TargetInput.resolve_of_basedPath?`

Benitoite.Release.Refinement.PathBaseDifference、55行。

```lean
∀ {t : TargetInput} {c : PathBase}
  {w : Benitoite.Scope.Domain.Word},
  t.basedPath? = Option.some (c, w) →
    ∀ (σ : PathEnv),
      TargetInput.resolve σ t =
        Option.map (fun X => Benitoite.Scope.Domain.Target.path (X ++ w)) (σ.lookup c)
```

## `outsideAllEnvs_based_iff`

Benitoite.Release.Refinement.PathBaseDifference、127行。

```lean
∀ {b c : PathBase} {pat : Benitoite.Scope.Domain.PathPattern}
  {t : TargetInput} {w : Benitoite.Scope.Domain.Word},
  pat.WF →
    Benitoite.Scope.Domain.PathWordWF w →
      t.basedPath? = Option.some (c, w) →
        (OutsideAllEnvs (RangeExpr.based b pat) t ↔
          if b = c then ¬pat.Matches w
          else ∃ s, pat = Benitoite.Scope.Domain.PathPattern.exact s ∧ ¬(s <:+ w ∨ w <:+ s))
```

## `PathBasesDiffer.tree_not_outside`

Benitoite.Release.Refinement.PathBaseDifference、186行。

```lean
∀ {b : PathBase} {s : Benitoite.Scope.Domain.Word}
  {t : TargetInput} {c : PathBase}
  {w : Benitoite.Scope.Domain.Word},
  (Benitoite.Scope.Domain.PathPattern.tree s).WF →
    Benitoite.Scope.Domain.PathWordWF w →
      t.basedPath? = Option.some (c, w) →
        PathBasesDiffer
            (RangeExpr.based b (Benitoite.Scope.Domain.PathPattern.tree s)) t →
          ¬OutsideAllEnvs
              (RangeExpr.based b (Benitoite.Scope.Domain.PathPattern.tree s)) t
```

## `PathBasesDiffer.exists_outside`

Benitoite.Release.Refinement.PathBaseDifference、197行。

```lean
∀ {p : RangeExpr} {t : TargetInput},
  PathBasesDiffer p t →
    ∃ σ,
      σ.Valid ∧
        ∃ target,
          TargetInput.resolve σ t = Option.some target ∧
            ¬RangeExpr.Mem σ Benitoite.Scope.Domain.Kind.path p target
```

## `checkAt_ok_mem`

Benitoite.Release.Refinement.PathBaseDifference、223行。

```lean
∀ {σ : PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {p : RangeExpr} {input : TargetInput}
  {bound : RangeExpr} {target : Benitoite.Scope.Domain.Target},
  checkAt (Option.some σ) k p input bound =
      AtResult.ok target →
    TargetInput.resolve σ input = Option.some target ∧
      RangeExpr.Mem σ k p target
```

## `OutsideAllEnvs.checkAt_not_ok`

Benitoite.Release.Refinement.PathBaseDifference、249行。

```lean
∀ {p : RangeExpr} {t : TargetInput},
  OutsideAllEnvs p t →
    ∀ {σ : PathEnv},
      σ.Valid →
        ∀ (bound : RangeExpr) (target : Benitoite.Scope.Domain.Target),
          checkAt (Option.some σ) Benitoite.Scope.Domain.Kind.path p t bound ≠
            AtResult.ok target
```

## `TargetInput.resolve_wf_of_basedPath?`

Benitoite.Release.Refinement.PathBaseDifference、257行。

```lean
∀ {t : TargetInput} {c : PathBase}
  {w : Benitoite.Scope.Domain.Word},
  t.basedPath? = Option.some (c, w) →
    Benitoite.Scope.Domain.PathWordWF w →
      ∀ {σ : PathEnv},
        σ.Valid →
          ∀ {target : Benitoite.Scope.Domain.Target},
            TargetInput.resolve σ t = Option.some target → target.WF
```

## `checkAt_ok_of_not_outside`

Benitoite.Release.Refinement.PathBaseDifference、273行。

```lean
∀ {p : RangeExpr} {t : TargetInput},
  p.WF →
    p.FitsKind Benitoite.Scope.Domain.Kind.path →
      (∀ (σ : PathEnv),
          σ.Valid →
            ∀ (target : Benitoite.Scope.Domain.Target),
              TargetInput.resolve σ t = Option.some target → target.WF) →
        ¬OutsideAllEnvs p t →
          ∃ σ,
            σ.Valid ∧
              ∃ target,
                checkAt (Option.some σ) Benitoite.Scope.Domain.Kind.path p t
                    (RangeExpr.absolute Benitoite.Scope.Domain.Range.top) =
                  AtResult.ok target
```

## `outsideAllEnvs_iff_checkAt`

Benitoite.Release.Refinement.PathBaseDifference、294行。

```lean
∀ {p : RangeExpr} {t : TargetInput},
  p.WF →
    p.FitsKind Benitoite.Scope.Domain.Kind.path →
      (∀ (σ : PathEnv),
          σ.Valid →
            ∀ (target : Benitoite.Scope.Domain.Target),
              TargetInput.resolve σ t = Option.some target → target.WF) →
        (OutsideAllEnvs p t ↔
          ∀ (σ : PathEnv),
            σ.Valid →
              ∀ (target : Benitoite.Scope.Domain.Target),
                checkAt (Option.some σ) Benitoite.Scope.Domain.Kind.path p t
                    (RangeExpr.absolute Benitoite.Scope.Domain.Range.top) ≠
                  AtResult.ok target)
```
