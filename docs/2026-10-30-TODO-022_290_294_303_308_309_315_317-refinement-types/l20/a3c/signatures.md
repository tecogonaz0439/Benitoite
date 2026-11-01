# L20 A3c r1 の完全署名

2026-11-02。B_WORK: `f7e3222a5bf9327c0acc1a1553aa1d49b36b103d`。ブランチ: `m014/l20.a3c`。

実装前に固定した署名を、採用した行支持の条件と局所の型注記に合わせて整理した。以下は証明を除いた現行の完全署名である。F・A・G などの略記を使わない。private の補助も含める。既存の主な10言明、CoreAssumptions、Ordinary、S02 の14定義は変えない。

## 入口の定義・欄と供給

### External.lean

```lean

structure ExternalSignature.WF (P : Program) (d : ExternalSignature) : Prop where
  monomorphic : d.tparams = []
  kinds : d.kinds = []
  annotation : Ty.Annotation P [] [] (.dependentFn d.parameters)
  kinded : Ty.HasKind P [] (.dependentFn d.parameters) .value
  uses_exact : ∀ use, use ∈ d.uses ↔ ExternalUseAt P 0 d.parameters use
  uses_unique : d.uses.Nodup
  shape : ExternalTelWF P d.component (if d.uses = [] then Eff.empty else (EffR.mk (fun a => match a with | .name n (.fixed .top) => decide (n = stateEff) | _ => false) [])) d.parameters
  sourceTelRows : d.parameters.RowsIn (· < 0)

```

### Typing.lean

```lean

  inductive AtCallAdmissible (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Scope.Domain.Kind →
      OpaqueName → ResultShape → Option Val → Val → Val → RangeIx → Prop where
    | mk {Ψ Q C Γ Φ kind name shape bases pattern input index inputTy} :
        shape.Declared P → B.valKind name = some kind →
        (∀ v, bases = some v → HasTypeVQ P B Ψ Q C Γ Φ v .pathBases) →
        HasTypeVQ P B Ψ Q C Γ Φ pattern (.scopePattern kind) →
        (inputTy = .base .string ∧ B.valContent name = none ∨ B.valContent name = some inputTy ∧ inputTy.WF 0 0 0 ∧ inputTy.RowsIn (· < 0)) →
        HasTypeVQ P B Ψ Q C Γ Φ input inputTy.norm → index.WF 0 →
        (∀ r, index = .fixed r → r.WF ∧ r.Canonical ∧ r.FitsKind kind) →
        AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index

  /-- 被検査値の観測を共有し、各腕で確かめた条件を本体へ渡す。 -/

```

### HandlerContracts.lean

```lean

def ClauseSig (P : Program) (B : Builtins) (e : Eff) (o : OpRef) (sg : OpSig) : Prop :=
  ∃ S,ClauseIxOk B e o S ∧ opSigAt P B S o=some sg ∧
    ∀ (b : PrimName) (s : PrimSig), o = .prim b → B.sig b = some s →
      s.tel.RowsIn (· < s.neffs)

theorem ClauseSig.ne_fail {P B e o sg} (h : ClauseSig P B e o sg) : o≠.fail

theorem ClauseSig.sourceTelRows {P B e o sg b s}
    (h : ClauseSig P B e o sg) (ho : o = .prim b) (hs : B.sig b = some s) :
    s.tel.RowsIn (· < s.neffs)

theorem ClauseSig.of_opSig {P B e o sg} (h : opSig P B o=some sg)
    (hr : ∀ (b : PrimName) (s : PrimSig), o = .prim b → B.sig b = some s →
      s.tel.RowsIn (· < s.neffs)) : ClauseSig P B e o sg

```

### LegacyTables.lean

```lean

theorem LegacyPrimSignature.sourceTelRowsAt
    {s0 : Benitoite.Release.PrimSig} {s : PrimSig}
    {C : List Benitoite.Release.TParam} {Q : Benitoite.Release.NoFailCtx}
    {ts : List Benitoite.Release.Ty} {es : List Benitoite.Release.Eff}
    {rs : List Scope.Domain.Range}
    (h : LegacyPrimSignature s0 s)
    (ha : Benitoite.Release.PrimitiveAdmissible C (s0.inst rs) Q ts es) :
    s.tel.RowsIn (· < (es.map embedEff).length)

theorem LegacyPrimSignature.clauseSig {P B e b s0 s S sg}
    (h : LegacyPrimSignature s0 s) (hb : B.sig b = some s)
    (hi : ClauseIxOk B e (.prim b) S) (hl : opSigAt P B S (.prim b) = some sg) :
    ClauseSig P B e (.prim b) sg

```

### TargetTable.lean

```lean

theorem content_rows {name a} (h : valContent name = some a) : a.RowsIn (· < 0)

```

### TypeSubstFormation.lean

```lean

theorem Tel.annotation_substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t)) :
    Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts es))
      (.dependentFn (t.substAt C1.length ts es))

```

## CurrentSignatureRows.lean

各署名の名前空間と import は同名の本番ファイルを正とする。宣言の束縛変数と型はすべて記す。

```lean

  theorem embed_rows {nr nt pe} (a : Benitoite.Release.Ty) (h : a.VarsIn nr nt pe) :
      (embedTy a).RowsIn pe

  theorem embed_rows_list {nr nt pe} (as : List Benitoite.Release.Ty) (h : Benitoite.Release.Ty.VarsInList nr nt pe as) :
      Ty.RowsInList pe (embedTys as)

  theorem embed_rows_eff {nr nt pe} (e : Benitoite.Release.Eff) (h : e.VarsIn nr nt pe) :
      (embedEff e).RowsIn pe

theorem rows_shift {pe : Nat → Prop} {a : Ty} (h : a.RowsIn pe) (k c : Nat) : (a.shiftV k c).RowsIn pe

theorem signature_rows {pe} (ns : List String) (as : List Ty) (r : Ty) (e : Eff)
    (hs : Ty.RowsInList pe as) (hr : r.RowsIn pe) (he : e.RowsIn pe) :
    (signatureTel ns as r e).RowsIn pe

def copiedTel (s : Benitoite.Release.PrimSig) : Tel :=
  signatureTel s.names (embedParameters s.params)
    ((embedTy s.ret).shiftV s.params.length 0) ((embedEff s.eff).shiftV s.params.length 0)

theorem scoped_signature {s : Benitoite.Release.PrimSig} (h : s.Scoped) :
    (copiedTel s).RowsIn (· < s.neffs)

theorem model_rows {P : Benitoite.Release.Program} {b s} (h : (Benitoite.Release.Model.builtins).sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs)

theorem target_entries_rows : ∀ entry ∈ Benitoite.Release.TargetTable.entries,
    (copiedTel entry.2).RowsIn (· < entry.2.neffs)

theorem model_targets_rows
    {pat : String → Option Scope.Domain.Range} {tgt : String → Option Scope.Domain.Target}
    {P : Benitoite.Release.Program} (hp : Benitoite.Release.ModelTargets.HasResult P) {b s}
    (h : (Benitoite.Release.ModelTargets.builtins pat tgt).sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs)

theorem model_http_rows
    {hostPat : String → Int → Int → Option Scope.Domain.Range}
    {reqTarget : Benitoite.Release.Val → Option Scope.Domain.Target}
    {P : Benitoite.Release.Program} (hp : Benitoite.Release.ModelHttp.HasHttp P) {b s}
    (h : (Benitoite.Release.ModelHttp.builtins hostPat reqTarget).sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs)

theorem examples_scoped {b s} (h : Benitoite.Release.Examples.builtins.sig b = some s) :
    s.Scoped

theorem examples_rows {b s} (h : Benitoite.Release.Examples.builtins.sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs)

```

## TypeSubstRowObstruction.lean

各署名の名前空間と import は同名の本番ファイルを正とする。宣言の束縛変数と型はすべて記す。

```lean

def inner : Ty := .fn [] [] (.base .unit) (Eff.row 0)

def ioSig : PrimSig := {
  tparams := [], neffs := 0, names := ["f"], params := [inner],
  ret := .base .unit, eff := Eff.single "IO", admits := fun _ _ => True,
  kind := .io, opEff := some "IO" }

theorem no_rows : ¬ ioSig.tel.RowsIn (· < ioSig.neffs)

theorem clause_sig_rejects_row {P B e sg} (hs : B.sig "bad" = some ioSig) :
    ¬ ClauseSig P B e (.prim "bad") sg

def inputTy : Ty := .reference inner

def rows : List Eff := [Eff.empty]

def sourceCtx : Ctx := [some inputTy, some (.scopePattern .endpoint)]

def targetCtx : Ctx := sourceCtx.bindTypes (typeEnvAt 0 [] rows)

theorem input_wf : inputTy.WF 0 0 0

theorem input_not_rowfree : ¬ inputTy.RowsIn (· < 0)

theorem input_changes : inputTy.substAt 0 [] rows ≠ inputTy.norm

theorem at_rejects_row {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (hc : B.valContent name = some inputTy) :
    ¬ AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index

def tokenCon : ConDecl := ⟨"Token", 1, []⟩

def externalProgram : Program := {
  defs := fun _ => none, cons := fun c => if c = "Token" then some tokenCon else none,
  ops := fun _ => none, effects := fun _ => none,
  classes := fun _ => none, impls := fun _ => none }

def phantomTy : Ty := .data "Token" [inner]

def externalSignature : ExternalSignature := {
  component := .mk 0, displayName := "phantom", tparams := [], kinds := [],
  parameters := .done phantomTy Eff.empty, uses := [] }

theorem external_not_rowfree : ¬ externalSignature.parameters.RowsIn (· < 0)

theorem external_rejects_row : ¬ externalSignature.WF externalProgram

```

## TypeSubstCalls.lean

各署名の名前空間と import は同名の本番ファイルを正とする。宣言の束縛変数と型はすべて記す。

```lean

private theorem row_kinds_subst {P C0 C1 e ts es}
    (h : kindsEff P (TypeCtx.kinds (C1 ++ C0)) e)
    (ht : TypeArgsKinded P [] ts (TypeCtx.kinds C0))
    (he : ∀ e ∈ es, kindsEff P [] e) :
    kindsEff P (TypeCtx.kinds C1) (Eff.substAt C1.length ts es e)

theorem SignatureInstance.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ks as fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (h : SignatureInstance P (C1 ++ C0) Γ t ks as fs)
    (hr : t.RowsIn (· < fs.length)) :
    SignatureInstance P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) t ks
      (as.map (Ty.substAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es))

theorem SatAll.substAt {P B C0 C1 Γ as ps ts es}
    (hf : B.CoreAssumptions P)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (h : SatAll B (C1 ++ C0) as ps) :
    SatAll B C1 (as.map (Ty.substAt C1.length ts es)) ps

theorem NoFail.substAt {Q Q' e} (h : NoFail Q e) (c : Nat) (ts : List Ty)
    (es : List Eff) (hq : RowTransport Q Q' es) :
    NoFail Q' (Eff.substAt c ts es e)

private theorem op_subst {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ {C0 C1 o us ts es Q'}, C = C1 ++ C0 → v = .op o us →
    (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
    ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.op o us).substTyAt C1.length ts es) (a.substAt C1.length ts es)

theorem gate_op_case {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ o us a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (_hc : TypeSubstCode es (fun nr nt ne nv => (Val.op o us).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.op o us) a) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.op o us).substTyAt C1.length ts es) (a.substAt C1.length ts es)

private theorem fun_subst {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ {C0 C1 f us fs ts es Q'}, C = C1 ++ C0 → v = .fnRef f us fs →
    (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
    ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.fnRef f us fs).substTyAt C1.length ts es) (a.substAt C1.length ts es)

theorem gate_fun_case {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ f us fs a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (_hc : TypeSubstCode es (fun nr nt ne nv => (Val.fnRef f us fs).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.fnRef f us fs) a) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.fnRef f us fs).substTyAt C1.length ts es) (a.substAt C1.length ts es)

  theorem Val.toTerm_typeSubst (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      (v.substTyAt c ts es).toTerm? = v.toTerm?

  private theorem slots_typeSubst (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      Val.toTermSlots (Val.substTyAtList c ts es vs) = Val.toTermSlots vs

private theorem typeEnv_open (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
    (typeEnvAt c ts es).up.mapValues (openingEnv v.toTerm?) = typeEnvAt c ts es

theorem Tel.open_typeSubst (t : Tel) (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
    Tel.bind (Tel.argumentsEnv (v.substTyAt c ts es))
      (Tel.bind (typeEnvAt c ts es).up t) =
    (Tel.bind (Tel.argumentsEnv v) t).substAt c ts es

theorem Tel.arguments_typeSubst (t : Tel) (vs : List Val) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    Tel.arguments (t.substAt c ts es) (vs.map (Val.substTyAt c ts es)) =
      (Tel.arguments t vs).map (fun (as, r, e) =>
        (as.map (Ty.substAt c ts es), r.substAt c ts es, Eff.substAt c ts es e))

theorem Val.substTyAtList_eq_map (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
    Val.substTyAtList c ts es vs = vs.map (Val.substTyAt c ts es)

theorem HasTypeCQ.type_subst_meth {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ} {R : Option Ty} {L : LocalCtx}
    {v cl τ cd m ms ss fs ws as a e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es) (hq : RowTransport Q Q' es)
    (hc : P.classes cl = some cd) (hm : cd.methods m = some ms)
    (hn : NamesWF ms.names ms.params)
    (hs : SatAll B (C1 ++ C0) ss (TypeCtx.constraints ms.tparams))
    (hsi : SignatureInstance P (C1 ++ C0) Γ ms.tel
      (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) fs)
    (hr : MethodRowsAdmissible (C1 ++ C0) Γ.length Q ms fs)
    (ha : Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) fs) ws = some (as, a, e))
    (hann : Ty.Annotation P (C1 ++ C0) Γ a)
    (ihv : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) ((Ty.dict cl τ).substAt C1.length ts es))
    (ihws : HasTypeVsQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (ws.map (Val.substTyAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es))) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es))
      ((Comp.meth v m ss fs ws).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes)))

theorem Eff.substAt_singleFail (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es (Eff.singleFail a) = Eff.singleFail (a.substAt c ts es)

private theorem raise_type_image (T E : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    (Ty.fn ["error"] [E] T (Eff.singleFail E)).substAt c ts es =
      .fn ["error"] [E.substAt c ts es] (T.substAt c ts es)
        (Eff.singleFail (E.substAt c ts es))

theorem HasTypeVQ.type_subst_raise {P B} {Ψ : StoreTy} {Q' C0 C1 Γ Φ T E ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ["error"] [E] T (Eff.singleFail E)))
    (ht : Ordinary T) (he : Ordinary E) (hk : T.HasKind P (TypeCtx.kinds (C1 ++ C0)) .value) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.raise T E).substTyAt C1.length ts es)
      ((Ty.fn ["error"] [E] T (Eff.singleFail E)).substAt C1.length ts es)

theorem HasTypeCQ.type_subst_escape {P B} {Ψ : StoreTy}
    {Q' C0 C1 Γ Φ r v a e ts es} {L : LocalCtx}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a)
    (ih : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (r.substAt C1.length ts es)) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((some r).map (Ty.substAt C1.length ts es))
      ((Comp.escape v).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes)))

theorem HasTypeVQ.raise_annotation_kind {P B Ψ Q C Γ Φ v t e a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) ∧
      t.HasKind P (TypeCtx.kinds C) .value

theorem HasTypeVQ.type_subst_lam {P B} {Ψ : StoreTy}
    {Q' C0 C1 Γ Φ ns ps body r ε ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hn : NamesWF ns ps)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ns ps r ε))
    (ih : HasTypeCQ P B (hideBuilders Ψ) Q' C1
      (bindParams (hideConts (Γ.bindTypes (typeEnvAt C1.length ts es)))
        (ps.map (Ty.substAt C1.length ts es)))
      (liftMany (ps.map (Ty.substAt C1.length ts es)).length Φ)
      (some ((r.substAt C1.length ts es).shiftV
        (ps.map (Ty.substAt C1.length ts es)).length 0))
      (body.substTyAt C1.length (ts.map (Ty.shiftV ps.length 0))
        (es.map (Eff.shiftV ps.length 0)))
      ((r.substAt C1.length ts es).shiftV (ps.map (Ty.substAt C1.length ts es)).length 0)
      (Eff.shiftV (ps.map (Ty.substAt C1.length ts es)).length 0
        (Eff.substAt C1.length ts es ε)) []) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.lam ns ps body).substTyAt C1.length ts es)
      ((Ty.fn ns ps r ε).substAt C1.length ts es)

theorem Eff.substAt_empty (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es Eff.empty = Eff.empty

theorem Ty.substAt_fn (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    (Ty.fn ns ps r e).substAt c ts es = .fn ns (ps.map (Ty.substAt c ts es))
      (r.substAt c ts es) (Eff.substAt c ts es e)

```

## TypeSubstGateExamples.lean

各署名の名前空間と import は同名の本番ファイルを正とする。宣言の束縛変数と型はすべて記す。

```lean

private theorem singleton_kinded {P : Program} {C : TypeCtx} {a : Ty} {k : TyKind} (hk : a.HasKind P (TypeCtx.kinds C) k)
    (ho : k = .value → Ordinary a) : TypeArgsKinded P C [a] [k]

private theorem single_input {P : Program} {B : Builtins} {p : TParamDecl} {a : Ty} (hf : B.CoreAssumptions P)
    (hp : p.constraints = ({} : TParam)) (hw : a.WF 0 0 0)
    (hk : a.HasKind P [] p.kind) (ho : Ordinary a) (ha : Ty.Annotation P [] [] a) :
    ClosedTypeSubstInput P B [p] [] [] [a] []

def opDecl : OpDecl := ⟨"Gate.Ask", [{}], [], [], .tvar 0, []⟩

def ctorParam : TParamDecl := ⟨{}, .constructor 1⟩

def funDecl : Def := {
  tparams := [ctorParam], neffs := 0, names := [], params := [], ret := .base .unit,
  eff := Eff.empty, body := .ret (.const .unit) }

macro "gate_simp" : tactic => `(tactic|
  simp [opDecl, funDecl, ctorParam, TypeCtx.valueParam, TypeCtx.kinds, TypeCtx.constraints,
    OpDecl.tel, Def.tel, signatureTel, instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm,
    Ty.WF, Ty.WFList, Tel.WF, Ty.Sorted, Tel.Sorted, sortedTys, sortedEff,
    Ty.Declared, Tel.Declared, declaredTys, declaredEff, Ty.HasKind, kindsList, kindsEff,
    Ty.bind, Ty.rawBind, Ty.norm, Ty.normTys, rawBindTys, Ty.shiftV,
    Eff.WF, Eff.Canonical, Eff.norm, Eff.empty, Eff.rawBind, Eff.shiftV,
    Qsig, QTys, QTy, QEff, Qempty, Eff.singleFail, Eff.single, Eff.row, Eff.RowsIn, Ty.RowsInList, NamesWF, typeEnvAt, TypeAnnotations, RowAnnotations,
    substAtoms, instAtoms, rowFails, Ordinary, Ty.core])

theorem gate_op_bytes {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hop : P.ops "gateOp" = some opDecl)
    (hsat : B.sat (TypeCtx.constraints [TypeCtx.valueParam]) (.tvar 0) {}) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.op "gateOp" [.bytes])
      ((Ty.dependentFn (instantiatedTel opDecl.tel [.tvar 0] [])).substAt 0 [.bytes] [])

theorem op_rejects_constructor {P Γ} :
    ¬ SignatureInstance P [ctorParam] Γ opDecl.tel [.value] [.tvar 0] []

theorem gate_fun_list {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hfun : P.defs "gateFun" = some funDecl)
    (hsat : B.sat (TypeCtx.constraints [ctorParam]) (.tvar 0) {}) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.fnRef "gateFun" [.ctor .list] [])
      ((Ty.dependentFn (instantiatedTel funDecl.tel [.tvar 0] [])).substAt 0 [.ctor .list] [])

def methodSig : MethSig := {
  tparams := [TypeCtx.valueParam], neffs := 0, names := ["xs"],
  params := [.list (.tvar 0)], ret := .list (.tvar 0), eff := Eff.empty }

def methodClass : ClassDecl := {
  supers := [], methods := fun m => if m = "m" then some methodSig else none }

def methodCtx : Ctx := [some (.dict "GateClass" .bytes)]

theorem gate_meth_tvar {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hc : P.classes "GateClass" = some methodClass)
    (hsat : B.sat (TypeCtx.constraints [TypeCtx.valueParam]) (.tvar 0) {}) :
    HasTypeCQ P B Ψ Qempty [TypeCtx.valueParam] methodCtx [] none
      (.meth (.var 0) "m" [.tvar 0] [] [.list []]) (.list (.tvar 0)) Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] methodCtx [] none
      (.meth (.var 0) "m" [.bytes] [] [.list []]) (.list .bytes) Eff.empty []

def appTy : Ty := .tapp 0 [.bytes]

theorem gate_annotation_escape {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hd : P.DataArity "GateData" 1) :
    HasTypeCQ P B Ψ Qempty [ctorParam] [] [] (some (.base .unit))
      (.escape (.const .unit)) appTy Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] [] [] (some (.base .unit))
      (.escape (.const .unit)) (.data "GateData" [.bytes]) Eff.empty []

theorem gate_annotation_lam {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hd : P.DataArity "GateData" 1) :
    HasTypeVQ P B Ψ Qempty [ctorParam] [] []
      (.lam ["x"] [appTy] (.ret (.var 0))) (.fn ["x"] [appTy] appTy Eff.empty) ∧
    HasTypeVQ P B Ψ Qempty [] [] []
      (.lam ["x"] [.data "GateData" [.bytes]] (.ret (.var 0)))
      (.fn ["x"] [.data "GateData" [.bytes]] (.data "GateData" [.bytes]) Eff.empty)

theorem tapp_rejects_wrong_arity {P Γ} :
    ¬ Ty.Declared P [ctorParam] Γ (.tapp 0 [.bytes, .bytes])

theorem gate_list_constructor {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) :
    HasTypeVQ P B Ψ Qempty [ctorParam] [] [] (.list []) (.list (.tvar 0)) ∧
    HasTypeVQ P B Ψ Qempty [] [] []
      ((Val.list []).substTyAt 0 [.ctor .list] [])
      ((Ty.list (.tvar 0)).substAt 0 [.ctor .list] [])

def failBody (t : Ty) : Comp :=
  .letIn (.app (.raise t .bytes) [.bytesV []]) (.ret (.const .unit))

private theorem fail_body_typed {P B Ψ Q C Γ t}
    (hr : HasTypeVQ P B Ψ Q C Γ [] (.raise t .bytes)
      (.fn ["error"] [.bytes] t (Eff.singleFail .bytes))) :
    HasTypeCQ P B Ψ Q C Γ [] none (failBody t) (.base .unit) (Eff.singleFail .bytes) []

theorem gate_fail_body {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) :
    HasTypeCQ P B (hideBuilders Ψ) Qempty [TypeCtx.valueParam]
      (failureContext [] .bytes) [] none (failBody (.tvar 0))
      (.base .unit) (Eff.singleFail .bytes) [] ∧
    HasTypeCQ P B (hideBuilders Ψ) Qempty []
      ((failureContext [] .bytes).bindTypes (typeEnvAt 0 [.bytes] [])) [] none
      ((failBody (.tvar 0)).substTy [.bytes] [])
      ((Ty.base .unit).substAt 0 [.bytes] [])
      (Eff.substAt 0 [.bytes] [] (Eff.singleFail .bytes)) []

theorem fun_rejects_value {P Γ} :
    ¬ SignatureInstance P [TypeCtx.valueParam] Γ funDecl.tel [.constructor 1] [.tvar 0] []

theorem gate_fail_clause {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) :
    HasFailureClause P B Ψ Qempty [] [] [] .bytes none
      [.fail .bytes (failBody (.tvar 0))] (.base .unit) (Eff.singleFail .bytes) []

def nestedTy : Ty := .list (.cont (.base .unit) (.base .unit) Eff.empty)

theorem nested_empty_accepted {P B Ψ Q C Φ} :
    HasTypeVQ P B Ψ Q C [] Φ (.list []) nestedTy

theorem nested_op_accepted {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hop : P.ops "gateOp" = some opDecl) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.op "gateOp" [nestedTy])
      (.dependentFn (instantiatedTel opDecl.tel [nestedTy] []))

```

## NestedContinuation.lean

各署名の名前空間と import は同名の本番ファイルを正とする。宣言の束縛変数と型はすべて記す。

```lean

private theorem list_cont_aux {P B Ψ Q C Γ Φ v T a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = [])
    (ht : T.listCore = some a) (ha : ¬ a.NotContCore) : v = .list []

theorem list_cont_empty {P B Ψ Q C Φ v b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.list (.cont b t e))) : v = .list []

theorem singleton_no_match {P B Ψ Q C Φ v b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.list (.cont b t e))) :
    matchVal (.list [.var] none []) v = none

theorem reject_cont_value {P B Ψ Q C Φ v b t e} :
    ¬ HasTypeVQ P B Ψ Q C [] Φ v (.cont b t e)

theorem reject_nested_cont_value {P B Ψ Q C Φ v vs b t e} :
    ¬ HasTypeVQ P B Ψ Q C [] Φ (.list (v :: vs)) (.list (.cont b t e))

theorem HasTypeVQ.con_list_cont_field_empty {P : Program} {B : Builtins}
    {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Φ : List Pred}
    {T : Ty} {c : ConName} {ts : List Ty} {vs : List Val} {cd : ConDecl} {i : Nat}
    {a b t : Ty} {e : Eff}
    (h : HasTypeVQ P B Ψ Q C [] Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a)
    (hi : a.subst ts [] = .list (.cont b t e)) :
    vs[i]? = some (Val.list [])

theorem CaptureOk.list_cont_empty {P B Ψ R Γ Φ cap i a b t e}
    (h : CaptureOk P B Ψ R Γ Φ cap)
    (hi : Γ[i]? = some (some (.list a)))
    (ha : substTyValues cap.env (.list a) = .list (.cont b t e)) :
    cap.env i = .list []

```

## r2: context を分けた内部入力と公開入口

公開 S02 の字面は保つ。形成と case の既存署名では `ClosedTypeSubstInput P B C0 C1 Γ ts es` を `TypeSubstInput P B C0 C1 ts es` へ替える。Γ は移送する判断から読む。

```lean
structure TypeSubstInput (P : Program) (B : Builtins)
    (C0 C1 : TypeCtx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = C0.length
  typeWF : ∀ t ∈ ts, t.WF 0 0 0
  typeKinds : TypeArgsKinded P [] ts (TypeCtx.kinds C0)
  typeAnnotations : TypeAnnotations P [] [] ts
  constraints : SatAll B C1 ts (TypeCtx.constraints C0)
  rowWF : ∀ e ∈ es, e.WF 0 0 0
  rowAnnotations : RowAnnotations P [] [] es
  rowKinds : ∀ e ∈ es, kindsEff P [] e

structure ClosedTypeSubstInput (P : Program) (B : Builtins)
    (C0 C1 : TypeCtx) (Γ : Ctx) (ts : List Ty) (es : List Eff)
    : Prop extends TypeSubstInput P B C0 C1 ts es where
  context : CaptureContextRegular P (C1 ++ C0) Γ

namespace S02Internal

def C : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R m a e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) (m.substTyAt C1.length ts es) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)


def Body : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ t m ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q (C1 ++ C0) Γ Φ t m →
  TelBodyTy P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Tel.substAt C1.length ts es) t) (m.substTyAt C1.length ts es)


def Arms : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R obs arms a b e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedArms nr nt ne nv arms) → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L →
  HasTypeArmsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) obs ((Arm.substTyAtList C1.length ts es) arms) ((Ty.substAt C1.length ts es) a) ((Ty.substAt C1.length ts es) b) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)


def Clauses : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R eb clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L →
  HasTypeClausesQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) ((Eff.substAt C1.length ts es) eb) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)


end S02Internal
```

```lean
theorem HasTypeVQ.raise_annotation_kind {P B Ψ Q C Γ Φ v t e a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) ∧ Ordinary t ∧
      t.HasKind P (TypeCtx.kinds C) .value

theorem SatAll.weaken_closed {P B C1 ts ps} (hf : B.CoreAssumptions P)
    (extra : TypeCtx) (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (ha : TypeAnnotations P [] [] ts) (h : SatAll B C1 ts ps) :
    SatAll B (extra ++ C1) ts ps

theorem TypeSubstInput.under {P B C0 C1 ts es}
    (h : TypeSubstInput P B C0 C1 ts es) (hf : B.CoreAssumptions P) (extra : TypeCtx) :
    TypeSubstInput P B C0 (extra ++ C1) ts es

theorem fail_input {P B Ψ Q Φ T E a} (hf : B.CoreAssumptions P)
    (h : HasTypeVQ P B Ψ Q [] [] Φ (.raise T E) a) :
    ClosedTypeSubstInput P B [TypeCtx.valueParam] [] [] [T] []

theorem clause_prim_rowfree {P B e sg b s} (hc : B.CoreAssumptions P)
    (h : ClauseSig P B e (.prim b) sg) (hs : B.sig b = some s) :
    s.tel.RowsIn (· < 0)
```

```lean
namespace S02Internal

theorem C.toPublic (h : C) : S02_C

theorem Body.toPublic (h : Body) : S02_Body

theorem Arms.toPublic (h : Arms) : S02_Arms

theorem Clauses.toPublic (h : Clauses) : S02_Clauses

end S02Internal
```

C_Let 等の Declared だけを持つ前提から、S01 を使わず移送する。

```lean
theorem Ty.Declared.typeSubst {P B} {Ψ : StoreTy} {C0 C1 Γ a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Declared P (C1 ++ C0) Γ a) :
    Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es)

theorem Tel.Declared.typeSubst {P B} {Ψ : StoreTy} {C0 C1 Γ t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Tel.Declared P (C1 ++ C0) Γ t) :
    Tel.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (t.substAt C1.length ts es)
```

## r2: 正則でない子への入力（全帰納を前提にした接続の検査）

```lean
theorem body_param_no_context {P B Ψ Q Φ} :
    TelBodyTy P B Ψ Q [] [] Φ (.param "x" (.tvar 0) (.done (.base .unit) Eff.empty))
      (.ret (.const .unit)) ∧
    ¬ CaptureContextRegular P [] (Ctx.extend [] (.tvar 0))

theorem body_param_input (hB : S02Internal.Body) {P B} {Ψ : StoreTy} {Φ}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B [] [] [] [] []) :
    TelBodyTy P B Ψ Qempty [] ((Ctx.extend [] (.tvar 0)).bindTypes (typeEnvAt 0 [] [])) Φ
      ((Tel.done (.base .unit) Eff.empty).substAt 0 [] [])
      ((Comp.ret (.const .unit)).substTyAt 0 [] []) ∧
    ¬ CaptureContextRegular P [] (Ctx.extend [] (.tvar 0))

theorem arms_child_input (hC : S02Internal.C) {P B} {Ψ : StoreTy}
    {C0 C1 Γ ts es} (δ : List Ty)
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    HasTypeCQ P B Ψ Qempty C1 ((bindParams Γ δ).bindTypes (typeEnvAt C1.length ts es)) [] none
      ((Comp.ret (.const .unit)).substTyAt C1.length ts es)
      ((Ty.base .unit).substAt C1.length ts es) (Eff.substAt C1.length ts es Eff.empty) []

theorem clauses_child_input (hC : S02Internal.C) {P B} {Ψ : StoreTy}
    {C0 C1 Γ ts es} (sg : OpSig)
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    HasTypeCQ P B (hideBuilders Ψ) Qempty (sg.tparams ++ C1)
      ((sg.context Γ (.base .unit) Eff.empty).bindTypes (typeEnvAt (sg.tparams ++ C1).length ts es))
      [] none ((Comp.ret (.const .unit)).substTyAt (sg.tparams ++ C1).length ts es)
      ((Ty.base .unit).substAt (sg.tparams ++ C1).length ts es)
      (Eff.substAt (sg.tparams ++ C1).length ts es Eff.empty) []
```

## r2: 内部入力での形成・case の完全署名

r1 の同名の署名に対し、この節を優先する。公開 S02 は変えない。

```lean
private theorem closed_type_decl {P B C0 C1 ts es} {Γ : Ctx}
    (h : TypeSubstInput P B C0 C1 ts es) :
    ∀ i, Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es))
      ((typeEnvAt C1.length ts es).types i)

private theorem closed_row_decl {P B C0 C1 ts es} {Γ : Ctx}
    (h : TypeSubstInput P B C0 C1 ts es) :
    ∀ e ∈ (typeEnvAt C1.length ts es).rows,
      declaredEff P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) e

theorem Ty.Declared.typeSubst {P B} {Ψ : StoreTy} {C0 C1 Γ a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Declared P (C1 ++ C0) Γ a) :
    Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es)

theorem Tel.Declared.typeSubst {P B} {Ψ : StoreTy} {C0 C1 Γ t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Tel.Declared P (C1 ++ C0) Γ t) :
    Tel.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (t.substAt C1.length ts es)

theorem Ty.Declared.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a) :
    Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es)

theorem Tel.Declared.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t)) :
    Tel.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (t.substAt C1.length ts es)

theorem declaredTys_substAt {P B} {Ψ : StoreTy} {C0 C1 Γ as ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : TypeAnnotations P (C1 ++ C0) Γ as) :
    declaredTys P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es))

theorem declaredEff_substAt {P B} {Ψ : StoreTy} {C0 C1 Γ e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : RowAnnotations P (C1 ++ C0) Γ [e]) :
    declaredEff P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (Eff.substAt C1.length ts es e)

private theorem closed_type_sorted {P B C0 C1 ts es} {Γ : Ctx}
    (h : TypeSubstInput P B C0 C1 ts es) :
    ∀ i, Ty.Sorted (Γ.bindTypes (typeEnvAt C1.length ts es))
      ((typeEnvAt C1.length ts es).types i)

private theorem closed_row_sorted {P B C0 C1 ts es} {Γ : Ctx}
    (h : TypeSubstInput P B C0 C1 ts es) :
    ∀ e ∈ (typeEnvAt C1.length ts es).rows,
      sortedEff (Γ.bindTypes (typeEnvAt C1.length ts es)) e

theorem Ty.Annotation.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a) :
    Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es)

theorem Tel.annotation_substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t)) :
    Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts es))
      (.dependentFn (t.substAt C1.length ts es))

theorem TypeAnnotations.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ as ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : TypeAnnotations P (C1 ++ C0) Γ as) :
    TypeAnnotations P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es))

theorem RowAnnotations.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : RowAnnotations P (C1 ++ C0) Γ fs) :
    RowAnnotations P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es))

private theorem declared_closed_nil {P B} {Ψ : StoreTy} {C0 C1 Γ a ts}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts []) (hw : a.WF 0 0 0)
    (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts [])) a

theorem HasTypeVQ.type_subst_locRef {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ l a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.loc l).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.ref a)) (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.loc l)
      ((Ty.reference a).substAt C1.length ts es)

theorem HasTypeVQ.type_subst_locLazy {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ l a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.loc l).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.lazy a)) (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.loc l)
      ((Ty.lazy a).substAt C1.length ts es)

theorem HasTypeCQ.type_subst_resumeL {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ R L l v b t e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Comp.resume (.loc l) v).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.cont b t e R)) (hd : Ty.Declared P (C1 ++ C0) Γ t)
    (hv : HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (b.substAt C1.length ts es)) :
    HasTypeCQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es)) (.resume (.loc l) (v.substTyAt C1.length ts es))
      (t.substAt C1.length ts es) (Eff.substAt C1.length ts es e) L

theorem HasTypeVQ.type_subst_closure {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ runtime body t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.closure runtime body).SourceScoped nr nt ne nv))
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t))
    (hr : Tel.RuntimeShape runtime t) (hb : DependentClosureTy P B Ψ body t) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.closure runtime body)
      ((Ty.dependentFn t).substAt C1.length ts es)

theorem SignatureInstance.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ks as fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (h : SignatureInstance P (C1 ++ C0) Γ t ks as fs)
    (hr : t.RowsIn (· < fs.length)) :
    SignatureInstance P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) t ks
      (as.map (Ty.substAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es))

theorem SatAll.substAt {P B C0 C1 as ps ts es}
    (hf : B.CoreAssumptions P)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (h : SatAll B (C1 ++ C0) as ps) :
    SatAll B C1 (as.map (Ty.substAt C1.length ts es)) ps

private theorem op_subst {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ {C0 C1 o us ts es Q'}, C = C1 ++ C0 → v = .op o us →
    (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
    TypeSubstInput P B C0 C1 ts es → RowTransport Q Q' es →
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.op o us).substTyAt C1.length ts es) (a.substAt C1.length ts es)

theorem gate_op_case {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ o us a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (_hc : TypeSubstCode es (fun nr nt ne nv => (Val.op o us).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.op o us) a) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.op o us).substTyAt C1.length ts es) (a.substAt C1.length ts es)

private theorem fun_subst {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ {C0 C1 f us fs ts es Q'}, C = C1 ++ C0 → v = .fnRef f us fs →
    (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
    TypeSubstInput P B C0 C1 ts es → RowTransport Q Q' es →
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.fnRef f us fs).substTyAt C1.length ts es) (a.substAt C1.length ts es)

theorem gate_fun_case {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ f us fs a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (_hc : TypeSubstCode es (fun nr nt ne nv => (Val.fnRef f us fs).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.fnRef f us fs) a) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.fnRef f us fs).substTyAt C1.length ts es) (a.substAt C1.length ts es)

theorem HasTypeCQ.type_subst_meth {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ} {R : Option Ty} {L : LocalCtx}
    {v cl τ cd m ms ss fs ws as a e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es) (hq : RowTransport Q Q' es)
    (hc : P.classes cl = some cd) (hm : cd.methods m = some ms)
    (hn : NamesWF ms.names ms.params)
    (hs : SatAll B (C1 ++ C0) ss (TypeCtx.constraints ms.tparams))
    (hsi : SignatureInstance P (C1 ++ C0) Γ ms.tel
      (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) fs)
    (hr : MethodRowsAdmissible (C1 ++ C0) Γ.length Q ms fs)
    (ha : Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) fs) ws = some (as, a, e))
    (hann : Ty.Annotation P (C1 ++ C0) Γ a)
    (ihv : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) ((Ty.dict cl τ).substAt C1.length ts es))
    (ihws : HasTypeVsQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (ws.map (Val.substTyAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es))) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es))
      ((Comp.meth v m ss fs ws).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes)))

theorem HasTypeVQ.type_subst_raise {P B} {Ψ : StoreTy} {Q' C0 C1 Γ Φ T E ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ["error"] [E] T (Eff.singleFail E)))
    (ht : Ordinary T) (he : Ordinary E) (hk : T.HasKind P (TypeCtx.kinds (C1 ++ C0)) .value) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.raise T E).substTyAt C1.length ts es)
      ((Ty.fn ["error"] [E] T (Eff.singleFail E)).substAt C1.length ts es)

theorem HasTypeCQ.type_subst_escape {P B} {Ψ : StoreTy}
    {Q' C0 C1 Γ Φ r v a e ts es} {L : LocalCtx}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a)
    (ih : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (r.substAt C1.length ts es)) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((some r).map (Ty.substAt C1.length ts es))
      ((Comp.escape v).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes)))

theorem HasTypeVQ.type_subst_lam {P B} {Ψ : StoreTy}
    {Q' C0 C1 Γ Φ ns ps body r ε ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hn : NamesWF ns ps)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ns ps r ε))
    (ih : HasTypeCQ P B (hideBuilders Ψ) Q' C1
      (bindParams (hideConts (Γ.bindTypes (typeEnvAt C1.length ts es)))
        (ps.map (Ty.substAt C1.length ts es)))
      (liftMany (ps.map (Ty.substAt C1.length ts es)).length Φ)
      (some ((r.substAt C1.length ts es).shiftV
        (ps.map (Ty.substAt C1.length ts es)).length 0))
      (body.substTyAt C1.length (ts.map (Ty.shiftV ps.length 0))
        (es.map (Eff.shiftV ps.length 0)))
      ((r.substAt C1.length ts es).shiftV (ps.map (Ty.substAt C1.length ts es)).length 0)
      (Eff.shiftV (ps.map (Ty.substAt C1.length ts es)).length 0
        (Eff.substAt C1.length ts es ε)) []) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.lam ns ps body).substTyAt C1.length ts es)
      ((Ty.fn ns ps r ε).substAt C1.length ts es)

theorem TypeSubstInput.under {P B C0 C1 ts es}
    (h : TypeSubstInput P B C0 C1 ts es) (hf : B.CoreAssumptions P) (extra : TypeCtx) :
    TypeSubstInput P B C0 (extra ++ C1) ts es
```
