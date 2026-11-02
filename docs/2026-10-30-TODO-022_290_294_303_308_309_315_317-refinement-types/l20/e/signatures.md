# 群 E の完全署名

2026-11-02。実装前に固定する署名である。内部補題は必要に応じて追記する。

B_WORK: `f5a9edabcab0e785ada937bd35bb793b2f4ddca8`。

## Q の移送

以下の文脈・項・契約の引数は、本番の判断の順序と型をすべて明示する。三つの `q_fixed` は閉じた Qempty を保持する。

```lean
theorem HasTypeVQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeVQ P B Ψ Q' C Γ Φ v a

theorem HasTypeVsQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {as : List Ty} (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeVsQ P B Ψ Q' C Γ Φ vs as

theorem HasTypeEachQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {a : Ty} (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeEachQ P B Ψ Q' C Γ Φ vs a

theorem HasTypeCQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeCQ P B Ψ Q' C Γ Φ R m a e L

theorem HasTypeTelArgsQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {t : Tel} {a : Ty} {e : Eff} (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeTelArgsQ P B Ψ Q' C Γ Φ vs t a e

theorem TelBodyTy.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t : Tel} {body : Comp} (h : TelBodyTy P B Ψ Q C Γ Φ t body) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    TelBodyTy P B Ψ Q' C Γ Φ t body

theorem CaptureOk.q_fixed {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R Γ Φ cap

theorem DependentClosureTy.q_fixed {P : Program} {B : Builtins} {Ψ : StoreTy} {q : Closure} {t : Tel} (h : DependentClosureTy P B Ψ q t) :
    DependentClosureTy P B Ψ q t

theorem CheckedWitness.q_fixed {P : Program} {B : Builtins} {Ψ : StoreTy} {o : Benitoite.Release.OpaqueName} {kind : Benitoite.Scope.Domain.Kind} {range : RangeExpr} {snapshot : Option PathEnv} {target : Benitoite.Scope.Domain.Target} {request : Option Val} (h : CheckedWitness P B Ψ o kind range snapshot target request) :
    CheckedWitness P B Ψ o kind range snapshot target request

theorem AtCallAdmissible.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName} {shape : ResultShape} {bases : Option Val} {pattern : Val} {input : Val} {index : RangeIx} (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    AtCallAdmissible P B Ψ Q' C Γ Φ kind name shape bases pattern input index

theorem HasTypeArmsQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a : Ty} {b : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeArmsQ P B Ψ Q' C Γ Φ R obs arms a b e L

theorem HasTypeClausesQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {eb : Eff} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeClausesQ P B Ψ Q' C Γ Φ R eb cs t e L

theorem HasFailureClause.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {E : Ty} {R : Option Ty} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasFailureClause P B Ψ Q' C Γ Φ E R cs t e L

theorem ImageOk.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {ν : Nat → Val} {i : Nat} {a : Ty} (h : ImageOk P B Ψ Q C Γ Φ R ν i a) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    ImageOk P B Ψ Q' C Γ Φ R ν i a
```

## 行の補助

```lean

theorem NoFail.q_mono {Q Q' e} (h : NoFail Q e) (hq : ∀ i, Q i → Q' i) : NoFail Q' e
theorem RowTransport.q_mono {Qs Q Q' es} (h : RowTransport Qs Q es)
    (hq : ∀ i, Q i → Q' i) : RowTransport Qs Q' es
theorem Admissible.q_mono {B C nv tps ne Qs Q Q' ts es e}
    (h : Admissible B C nv tps ne Qs Q ts es e) (hq : ∀ i, Q i → Q' i) :
    Admissible B C nv tps ne Qs Q' ts es e
theorem PrimitiveAdmissible.q_mono {C nv s Q Q' ts es}
    (h : PrimitiveAdmissible C nv s Q ts es) (hq : ∀ i, Q i → Q' i) :
    PrimitiveAdmissible C nv s Q' ts es
theorem MethodRowsAdmissible.q_mono {C nv Q Q' ms es}
    (h : MethodRowsAdmissible C nv Q ms es) (hq : ∀ i, Q i → Q' i) :
    MethodRowsAdmissible C nv Q' ms es
```

## local_zero

```lean
theorem HasTypeCQ.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasTypeCQ P B Ψ Q C Γ Φ R m a e L'

theorem HasTypeArmsQ.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a : Ty} {b : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L'

theorem HasTypeClausesQ.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {eb : Eff} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L'

theorem HasFailureClause.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {E : Ty} {R : Option Ty} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasFailureClause P B Ψ Q C Γ Φ E R cs t e L'

```

## withReturn

```lean
theorem HasTypeCQ.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasTypeCQ P B Ψ Q C Γ Φ R' m a e L

theorem HasTypeArmsQ.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a : Ty} {b : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R' obs arms a b e L

theorem HasTypeClausesQ.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {eb : Eff} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasTypeClausesQ P B Ψ Q C Γ Φ R' eb cs t e L

theorem HasFailureClause.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {E : Ty} {R : Option Ty} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasFailureClause P B Ψ Q C Γ Φ E R' cs t e L

```

## 局所文脈の補助

```lean

theorem renameKind_zero (b : BuilderKind) (c : Nat) : renameKind (shiftIndex 0 c) b = b
theorem LocalCtx.Shift.zero_extend {L L'} (h : LocalCtx.Shift 0 0 L L') (x : Option BuilderKind) :
    LocalCtx.Shift 0 0 (LocalCtx.extend x L) (LocalCtx.extend x L')
theorem LocalCtx.Shift.zero_localExtend {L L'} (h : LocalCtx.Shift 0 0 L L') (n : Nat) :
    LocalCtx.Shift 0 0 (Refinement.localExtend n L) (Refinement.localExtend n L')
theorem LocalRef.HasKind.local_zero {Ψ L L' r b} (h : LocalRef.HasKind Ψ L r b)
    (hL : LocalCtx.Shift 0 0 L L') : LocalRef.HasKind Ψ L' r b
```

```lean
theorem renameKind_id (b : BuilderKind) : renameKind id b = b
```

## 捕捉の正規化

```lean
def normContTy : Ty → Ty
  | .cont b t e => .cont b.norm t.norm (Eff.norm e)
  | a => a

def normConts (Γ : Ctx) : Ctx := Γ.map (Option.map normContTy)

theorem normContTy_norm (a : Ty) : (normContTy a).norm = a.norm

theorem normConts_normEq (Γ : Ctx) : Γ.NormEq (normConts Γ)

theorem normConts_typeMap (Γ : Ctx) : Ctx.TypeMap Γ (normConts Γ)

theorem normConts_lookup {Γ : Ctx} {i : Nat} {a : Ty} (hi : (normConts Γ)[i]? = some (some a)) :
    ∃ b, Γ[i]? = some (some b) ∧ normContTy b = a

theorem builderBody_image_norm {P B Ψ Q C Γ Φ R ν i a}
    (h : ImageOk P B Ψ Q C Γ Φ R ν i a) :
    ImageOk P B Ψ Q C Γ Φ R ν i (normContTy a)
```

```lean
theorem normContTy_subst (a : Ty) (ν : Nat → Val) :
    substTyValues ν (normContTy a) = substTyValues ν a
```

```lean
theorem Ty.CaptureWF.normContTy {nr nt nv a} (h : Ty.CaptureWF nr nt nv a) :
    (normContTy a).CaptureWF nr nt nv

theorem Ty.CaptureSorted.normContTy {Γ a} (h : Ty.CaptureSorted Γ a) :
    (normContTy a).CaptureSorted (normConts Γ)

theorem Ty.CaptureDeclared.normContTy {P C Γ a} {B : Builtins}
    (h : Ty.CaptureDeclared P C Γ a) :
    (normContTy a).CaptureDeclared P C (normConts Γ)

theorem CaptureContextRegular.normConts {P C Γ} {B : Builtins}
    (h : CaptureContextRegular P C Γ) : CaptureContextRegular P C (normConts Γ)

theorem CaptureOk.normConts {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R (normConts Γ) Φ cap
```

## 正則性

```lean
  theorem Ty.References.shiftTypes {Γ Δ a k c} (h : Ty.References Γ a)
      (hm : TypeCtxMap k c Γ Δ) : Ty.References Δ (shiftTypes k c a)

  theorem Tel.References.shiftTypes {Γ Δ t k c} (h : Tel.References Γ t)
      (hm : TypeCtxMap k c Γ Δ) : Tel.References Δ (shiftTelTypes k c t)

  theorem referencesTys_shiftTypes {Γ Δ as k c} (h : referencesTys Γ as)
      (hm : TypeCtxMap k c Γ Δ) : referencesTys Δ (shiftTypesList k c as)

  theorem referencesEff_shiftTypes {Γ Δ e k c} (h : Eff.References Γ e)
      (hm : TypeCtxMap k c Γ Δ) : Eff.References Δ (shiftRowsTypes k c e)

theorem Ctx.Ordered.shiftE {Γ : Ctx} (h : Γ.Ordered) (k : Nat) : (Γ.shiftE k).Ordered

theorem Ctx.Regular.shiftE {P C Γ} (h : Ctx.Regular P C Γ) (extra : TypeCtx) :
    Ctx.Regular P (extra ++ C) (Γ.shiftE extra.length)

theorem OpSig.regular_context {P C Γ t e} (sg : OpSig) (h : Ctx.Regular P C Γ)
    (hp : BinderTypes.Annotations P (sg.tparams ++ C) (Γ.shiftE sg.tparams.length) sg.params)
    (hc : Ty.Annotation P (sg.tparams ++ C) ((Γ.shiftE sg.tparams.length).extendMany sg.params)
      (sg.continuation t e)) : Ctx.Regular P (sg.tparams ++ C) (sg.context Γ t e)

theorem failureContext_regular {P C Γ E} (h : Ctx.Regular P C Γ) (he : Ty.Annotation P C Γ E) :
    Ctx.Regular P (TypeCtx.valueParam :: C) (failureContext Γ E)

theorem reject_forward_or_cyclic_context {Γ : Ctx}
    (h : (∃ i j, Γ.Depends i j ∧ j ≤ i) ∨ ∃ i, Relation.TransGen Γ.Depends i i) :
    ¬ Γ.Ordered
```

## 合同の前提と型の合同

```lean
def SubstAgree (Γ : Ctx) (σ τ : Nat → Val) : Prop

def LocalSubstAgree (L : LocalCtx) (ρ η : Nat → LocalRef) : Prop

def ObservationAgree (Γ : Ctx) (ν μ : ObservationEnv) : Prop

theorem SubstAgree.map {Γ σ τ} (h : SubstAgree Γ σ τ) (f : Ty → Ty) :
    SubstAgree (Γ.map (Option.map f)) σ τ

theorem SubstAgree.hide {Γ σ τ} (h : SubstAgree Γ σ τ) : SubstAgree (hideConts Γ) σ τ

theorem SubstAgree.extendOption {Γ σ τ} (h : SubstAgree Γ σ τ) (x : Option Ty) :
    SubstAgree (x :: Γ.map (Option.map (Ty.shiftV 1 0))) (upSubst 1 σ) (upSubst 1 τ)

theorem SubstAgree.params {Γ σ τ} (h : SubstAgree Γ σ τ) (ps : List Ty) :
    SubstAgree (bindParams Γ ps) (upSubst ps.length σ) (upSubst ps.length τ)

theorem SubstAgree.extendMany {Γ σ τ} (h : SubstAgree Γ σ τ) (ps : List Ty) :
    SubstAgree (Γ.extendMany ps) (upSubst ps.length σ) (upSubst ps.length τ)

theorem SubstAgree.shiftE {Γ σ τ} (h : SubstAgree Γ σ τ) (k : Nat) :
    SubstAgree (Γ.shiftE k) (fun i => (σ i).shiftEAt k 0) (fun i => (τ i).shiftEAt k 0)

theorem SubstAgree.observation {Γ σ τ} (h : SubstAgree Γ σ τ) :
    ObservationAgree Γ (valEnv σ).values (valEnv τ).values

theorem ObservationAgree.self {Γ ν μ} (h : ObservationAgree Γ ν μ) (a : Ty) :
    ObservationAgree (some a :: Γ) (upValues ν) (upValues μ)

theorem ObservationAgree.extend {Γ ν μ} (h : ObservationAgree Γ ν μ) (a : Ty) :
    ObservationAgree (Γ.extend a) (upValues ν) (upValues μ)

  theorem Ty.rawSubstV_congr {Γ ν μ a} (h : Ty.References Γ a) (hs : ObservationAgree Γ ν μ) :
      a.rawSubstV ν = a.rawSubstV μ

  theorem Tel.rawSubstV_congr {Γ ν μ t} (h : Tel.References Γ t) (hs : ObservationAgree Γ ν μ) :
      Tel.rawSubstV ν t = Tel.rawSubstV μ t

  theorem substVTys_congr {Γ ν μ as} (h : referencesTys Γ as) (hs : ObservationAgree Γ ν μ) :
      substVTys ν as = substVTys μ as

  theorem Eff.rawSubstV_congr {Γ ν μ e} (h : Eff.References Γ e) (hs : ObservationAgree Γ ν μ) :
      Eff.rawSubstV ν e = Eff.rawSubstV μ e

theorem substTyValues_congr {Γ σ τ a} (h : Ty.References Γ a) (hs : SubstAgree Γ σ τ) :
    substTyValues σ a = substTyValues τ a

theorem substEffValues_congr {Γ σ τ e} (h : Eff.References Γ e) (hs : SubstAgree Γ σ τ) :
    substEffValues σ e = substEffValues τ e

theorem telBindValues_congr {Γ σ τ t} (h : Tel.References Γ t) (hs : SubstAgree Γ σ τ) :
    Tel.bind (valEnv σ) t = Tel.bind (valEnv τ) t

theorem LocalSubstAgree.empty (ρ η : Nat → LocalRef) : LocalSubstAgree [] ρ η

theorem LocalSubstAgree.extend {L ρ η} (h : LocalSubstAgree L ρ η) (x : Option BuilderKind) :
    LocalSubstAgree (LocalCtx.extend x L) (upLocalSubst 1 ρ) (upLocalSubst 1 η)

theorem LocalSubstAgree.localExtend {L ρ η} (h : LocalSubstAgree L ρ η) (n : Nat) :
    LocalSubstAgree (Refinement.localExtend n L) (upLocalSubst n ρ) (upLocalSubst n η)

theorem LocalRef.HasKind.subst_congr {Ψ L r b ρ η} (h : LocalRef.HasKind Ψ L r b)
    (hs : LocalSubstAgree L ρ η) : r.subst ρ = r.subst η
```

## 型付きコードの合同

```lean
theorem substTypes_congr {Γ σ τ as} (h : referencesTys Γ as) (hs : SubstAgree Γ σ τ) :
    as.map (substTyValues σ) = as.map (substTyValues τ)

theorem TypeAnnotations.subst_congr {P C Γ ts σ τ} (h : TypeAnnotations P C Γ ts)
    (hs : SubstAgree Γ σ τ) : ts.map (substTyValues σ) = ts.map (substTyValues τ)

theorem RowAnnotations.subst_congr {P C Γ es σ τ} (h : RowAnnotations P C Γ es)
    (hs : SubstAgree Γ σ τ) : es.map (substEffValues σ) = es.map (substEffValues τ)

theorem substKind_congr {Γ σ τ kind} (h : Ty.References Γ kind.contents) (hs : SubstAgree Γ σ τ) :
    substKind σ kind = substKind τ kind

  theorem HasTypeVQ.subst_congr {P B Ψ Q C Γ Φ v a σ τ ρ η}
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hs : SubstAgree Γ σ τ) :
      v.subst σ ρ = v.subst τ η

  theorem HasTypeVsQ.subst_congr {P B Ψ Q C Γ Φ vs as σ τ ρ η}
      (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η

  theorem HasTypeEachQ.subst_congr {P B Ψ Q C Γ Φ vs a σ τ ρ η}
      (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η

  theorem HasTypeCQ.subst_congr {P B Ψ Q C Γ Φ R m a e L σ τ ρ η}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree L ρ η) : m.subst σ ρ = m.subst τ η

  theorem HasTypeTelArgsQ.subst_congr {P B Ψ Q C Γ Φ vs t a e σ τ ρ η}
      (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η

  theorem TelBodyTy.subst_congr {P B Ψ Q C Γ Φ t body σ τ ρ η}
      (h : TelBodyTy P B Ψ Q C Γ Φ t body) (hs : SubstAgree Γ σ τ) :
      body.subst (upSubst (telBinders t) σ) (upLocalSubst (telBinders t) ρ) =
        body.subst (upSubst (telBinders t) τ) (upLocalSubst (telBinders t) η)

  theorem AtCallAdmissible.subst_congr {P B Ψ Q C Γ Φ kind name shape bases pattern input index σ τ ρ η}
      (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index)
      (hs : SubstAgree Γ σ τ) :
      bases.map (fun v => v.subst σ ρ) = bases.map (fun v => v.subst τ η) ∧
      pattern.subst σ ρ = pattern.subst τ η ∧ input.subst σ ρ = input.subst τ η

  theorem HasTypeArmsQ.subst_congr {P B Ψ Q C Γ Φ R obs arms a b e L σ τ ρ η}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree L ρ η) : Arm.substList σ arms ρ = Arm.substList τ arms η

  theorem HasTypeClausesQ.subst_congr {P B Ψ Q C Γ Φ R eb cs t e L σ τ ρ η}
      (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree L ρ η) : Clause.substList σ cs ρ = Clause.substList τ cs η

  theorem HasFailureClause.subst_congr {P B Ψ Q C Γ Φ E R cs t e L σ τ ρ η}
      (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) (hs : SubstAgree Γ σ τ)
      (_hL : LocalSubstAgree L ρ η) : Clause.substList σ cs ρ = Clause.substList τ cs η
```

```lean
private theorem option_map_congr {α β : Type} (o : Option α) {f g : α → β}
    (h : ∀ v, o = some v → f v = g v) : o.map f = o.map g
```

```lean
private theorem checkAt_subst_congr {kind name shape bases pattern input index σ τ ρ η}
    (he : substTyValues σ shape.errorType = substTyValues τ shape.errorType)
    (hb : bases.map (fun v => v.subst σ ρ) = bases.map (fun v => v.subst τ η))
    (hp : pattern.subst σ ρ = pattern.subst τ η) (hv : input.subst σ ρ = input.subst τ η) :
    (Comp.checkAt kind name shape bases pattern input index).subst σ ρ =
      (Comp.checkAt kind name shape bases pattern input index).subst τ η
```

## 正規化した捕捉と結果形成の接続

```lean
theorem capture_normConts_value_annotation {P B Ψ R Γ Φ cap v a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hv : HasTypeVQ P B Ψ Qempty [] (normConts Γ) Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a)

theorem capture_normConts_comp_annotation {P B Ψ R Γ Φ cap Rs m a e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hm : HasTypeCQ P B Ψ Qempty [] (normConts Γ) Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a)
```

## r1 の捕捉の移送と具体の境界

```lean
theorem CaptureOk.hideBuilders_hideConts {P B Ψ R R' Γ Φ cap}
    (h : CaptureOk P B Ψ R Γ Φ cap) (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    CaptureOk P B (hideBuilders Ψ) R' (hideConts Γ) Φ cap

theorem normConts_cont {Γ : Ctx} {i : Nat} {b t : Ty} {e : Eff}
    (hi : Γ[i]? = some (some (Ty.cont b t e))) :
    ∃ b' t' e', (normConts Γ)[i]? = some (some (Ty.cont b' t' e'))

theorem HasTypeCQ.normConts {P B Ψ Q C Γ Φ R m a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeCQ P B Ψ Q C (Refinement.normConts Γ) Φ (R.map Ty.norm)
      (m.subst Val.var LocalRef.bound) a.norm (Eff.norm e)
      (L.map (Option.map BuilderKind.norm))

theorem HasTypeVQ.normConts {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeVQ P B Ψ Q C (Refinement.normConts Γ) Φ (v.subst Val.var LocalRef.bound) a.norm

theorem capture_value_annotation_via_normConts {P B Ψ R Γ Φ cap v a}
    (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a.norm)

theorem capture_comp_annotation_via_normConts {P B Ψ R Γ Φ cap Rs m a e L}
    (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a.norm)

namespace ContextOrderExamples
def selfRef : Ty := .refined (.base .integer) (.eq (.var 0) (.var 1))

def okTy : Ty := .base .integer

def bwdRef : Ty := .refined (.base .integer) (.eq (.var 0) (.var 2))

def fwd : Ctx := [some selfRef]

def back : Ctx := [some bwdRef,some okTy]

theorem fwd_dep : fwd.Depends 0 0

theorem fwd_rejected : ¬ fwd.Ordered

theorem back_ordered : back.Ordered

end ContextOrderExamples
```
