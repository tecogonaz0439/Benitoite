# L20 群 B・C の完全署名

2026-11-02。B_WORK は `da0049469694b2f26fd14173336bfe0c18aa5b11`、指定ブランチは `m014/l20.bc` である。各単位の署名を本体の前に記し、下記を最終の一覧とした。名前空間は `Benitoite.Release.Refinement`、S02Internal の補題だけは同名の入れ子に属する。定理は証明の本体を省き、定義と構造体は全欄を記す。

公開 S02 の十四署名と主な十の移送の言明は変えない。内部入力は Γ と context を持たない TypeSubstInput である。型又は行の新しい独立の保存則を入力にしない。範囲・型・行・値の上限は別々に扱う。

## L20.28: 宣言の形成

SourceScoped と SignatureScoped は ProgramWellFormed から SourceScope へそのまま移した。PrimSig.Scoped は s.tel と同じ s.tparams を読み、範囲深さを s.rkinds.length とする。operation は、旧 sig_scoped の位置の条件のうち、引数の最上位だけを具体化する opSigAt が読む部分である。非操作の項目には旧の引数の位置の条件を課さず、最上位の scoped も対象として認める。Scoped は kind を検査し、同じ s.tparams から得る制約は検査しない。型付けの規則に前提は足していない。

CoreAssumptions の承認済みの残り一欄は次のとおりである。

```lean
sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s
```

実表・三モデルの充足は L50/L60、主定理の接続は L70 の担当である。LegacyTables にこの欄を足していない。



### PrimitiveScoped.lean

```lean
def Ty.TargetWF (nr nt nv : Nat) : Ty → Prop
  | .opaque _ (.rvar i) | .scoped _ _ (.rvar i) => i < nr
  | a => a.WF 0 nt nv

def BinderTypes.TargetWF (nr nt : Nat) : Nat → List Ty → Prop
  | _, [] => True
  | n, a :: as => a.TargetWF nr nt n ∧ BinderTypes.TargetWF nr nt (n+1) as

def PrimSig.OperationWF (s : PrimSig) : Prop :=
  BinderTypes.TargetWF s.rkinds.length s.tparams.length 0 s.params ∧
    s.ret.WF 0 s.tparams.length s.params.length

structure PrimSig.Scoped (P : Program) (s : PrimSig) : Prop where
  names : NamesWF s.names s.params
  source : (Ty.dependentFn s.tel).SourceScoped
    s.rkinds.length s.tparams.length s.neffs 0
  kinds : Ty.HasKind P (TypeCtx.kinds s.tparams) (.dependentFn s.tel) .value
  sorted : Tel.Sorted [] s.tel
  declared : Tel.Declared P s.tparams [] s.tel
  operation : s.opEff ≠ none → s.OperationWF ∧
    (∀ a ∈ s.params, (∃ o ix, a = .opaque o ix) ∨
      (∃ o k ix, a = .scoped o k ix) ∨ a.RangesScoped 0) ∧
    s.ret.RangesScoped 0
```

## L20.28・.31: 範囲の形成

WFImages と行・範囲の SupportTransport を使い、旧 WF/VarsIn/RawWF の同値には依存しない。範囲を変える文脈でも、欄の観測に用いる型引数の対応を保つ。

### RangeFormation.lean

```lean
theorem RangeIx.wf_inst {nr : Nat} {ix : RangeIx} {rs : List RangeExpr}
    (h : ix.WF nr) (hn : rs.length = nr) : (ix.inst rs).WF 0

theorem Ty.SourceScoped.bind {nr nt ne nv mr mt me mv : Nat} {a : Ty} {θ : SubstEnv}
    (h : a.SourceScoped nr nt ne nv) (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (a.bind θ).SourceScoped mr mt me mv

private theorem obs_ranges (a : Ty) (ρ : Nat → RangeIx) :
      (a.rawMapRanges ρ).observationType = a.observationType

private theorem obs_ranges_tys (as : List Ty) (ρ : Nat → RangeIx) :
      observationTypes (mapRangesTys ρ as) = observationTypes as

private theorem data_core_ranges {a : Ty} {d ts} (h : a.norm.core = .data d ts)
    (ρ : Nat → RangeIx) :
    (a.rawMapRanges ρ).norm.core = .data d (Ty.normTys (mapRangesTys ρ ts))

private theorem data_ranges {P Γ t d ts} (h : Term.HasData P Γ t d ts)
    (ρ : Nat → RangeIx) : Term.HasData P (Γ.rawMapRanges ρ) t d ts

private theorem field_ranges {P C Γ t ref} (h : FieldRef.Declared P C Γ t ref)
    (ρ : Nat → RangeIx) : FieldRef.Declared P C (Γ.rawMapRanges ρ) t ref

private theorem term_ranges {P C Γ t} (h : Term.Declared P C Γ t)
      (ρ : Nat → RangeIx) : Term.Declared P C (Γ.rawMapRanges ρ) t

private theorem slots_ranges {P C Γ xs} (h : declaredSlots P C Γ xs)
      (ρ : Nat → RangeIx) : declaredSlots P C (Γ.rawMapRanges ρ) xs

private theorem pred_ranges {P C Γ self p} (h : Pred.Declared P C Γ self p)
    (ρ : Nat → RangeIx) :
    Pred.Declared P C (Γ.rawMapRanges ρ) (self.map (Ty.rawMapRanges ρ)) p

theorem Ty.Declared.rawMapRanges {P C Γ a} (h : Ty.Declared P C Γ a)
      (ρ : Nat → RangeIx) : Ty.Declared P C (Γ.rawMapRanges ρ) (a.rawMapRanges ρ)

theorem Tel.Declared.rawMapRanges {P C Γ t} (h : Tel.Declared P C Γ t)
      (ρ : Nat → RangeIx) : Tel.Declared P C (Γ.rawMapRanges ρ) (t.rawMapRanges ρ)

private theorem declaredTys_ranges {P C Γ as} (h : declaredTys P C Γ as)
      (ρ : Nat → RangeIx) : declaredTys P C (Γ.rawMapRanges ρ) (mapRangesTys ρ as)

private theorem declaredEff_ranges {P C Γ e} (h : declaredEff P C Γ e)
      (ρ : Nat → RangeIx) : declaredEff P C (Γ.rawMapRanges ρ) (Eff.rawMapRanges ρ e)

private theorem pred_sorted_ranges {Γ : Ctx} {a : Ty} {p : Pred}
    (h : p.Sorted Γ (some a)) (ρ : Nat → RangeIx) :
    p.Sorted (Γ.rawMapRanges ρ) (some (a.rawMapRanges ρ))

theorem Ty.Sorted.rawMapRanges {Γ a} (h : Ty.Sorted Γ a) (ρ : Nat → RangeIx) :
      Ty.Sorted (Γ.rawMapRanges ρ) (a.rawMapRanges ρ)

theorem Tel.Sorted.rawMapRanges {Γ t} (h : Tel.Sorted Γ t) (ρ : Nat → RangeIx) :
      Tel.Sorted (Γ.rawMapRanges ρ) (t.rawMapRanges ρ)

private theorem sortedTys_ranges {Γ as} (h : sortedTys Γ as) (ρ : Nat → RangeIx) :
      sortedTys (Γ.rawMapRanges ρ) (mapRangesTys ρ as)

private theorem sortedEff_ranges {Γ e} (h : sortedEff Γ e) (ρ : Nat → RangeIx) :
      sortedEff (Γ.rawMapRanges ρ) (Eff.rawMapRanges ρ e)

theorem Ty.HasKind.rawMapRanges {P K a k} (h : Ty.HasKind P K a k) (ρ : Nat → RangeIx) :
      Ty.HasKind P K (a.rawMapRanges ρ) k

private theorem kindsList_ranges {P K as} (h : kindsList P K as) (ρ : Nat → RangeIx) :
      kindsList P K (mapRangesTys ρ as)

private theorem kindsEff_ranges {P K e} (h : kindsEff P K e) (ρ : Nat → RangeIx) :
      kindsEff P K (Eff.rawMapRanges ρ e)

private theorem kindsTel_ranges {P K t} (h : kindsTel P K t) (ρ : Nat → RangeIx) :
      kindsTel P K (t.rawMapRanges ρ)

theorem SupportTransport.rangesOnly {p q : Atom → Prop} (rs : List RangeExpr)
    (h : ∀ a, p a → q (a.instR rs)) : SupportTransport p q (.rangesOnly rs)

theorem SubstEnv.rangesOnly_wfImages {nr nt nv : Nat} {rs : List RangeExpr}
    (hn : rs.length = nr) : (SubstEnv.rangesOnly rs).WFImages nr nt nv 0 nt nv

theorem Tel.sourceScoped_bind {nr nt ne nv mr mt me mv : Nat} {t : Tel} {θ : SubstEnv}
    (h : (Ty.dependentFn t).SourceScoped nr nt ne nv)
    (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (Ty.dependentFn (Tel.bind θ t)).SourceScoped mr mt me mv

theorem PrimSig.Scoped.inst_source {P : Program} {s : PrimSig} (h : s.Scoped P)
    {rs : List RangeExpr} (hn : rs.length = s.rkinds.length) :
    (Ty.dependentFn (Tel.instR rs s.tel)).SourceScoped 0 s.tparams.length s.neffs 0

theorem PrimSig.Scoped.inst {P : Program} {s : PrimSig} (h : s.Scoped P)
    {rs : List RangeExpr} (hn : rs.length = s.rkinds.length) :
    SignatureScoped P s.tparams s.neffs (Tel.instR rs s.tel)

theorem Builtins.CoreAssumptions.opSignaturesWF {P B} (h : Builtins.CoreAssumptions P B) :
    B.OpSignaturesWF

theorem Eff.SourceScoped.bind {nr nt ne nv mr mt me mv : Nat} {e : Eff} {θ : SubstEnv}
    (h : e.SourceScoped nr nt ne nv) (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (Eff.bind θ e).SourceScoped mr mt me mv

theorem Ty.SourceScoped.instR {nr nt ne nv : Nat} {a : Ty} {rs : List RangeExpr}
    (h : a.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (a.instR rs).SourceScoped 0 nt ne nv

theorem Eff.SourceScoped.instR {nr nt ne nv : Nat} {e : Eff} {rs : List RangeExpr}
    (h : e.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (Eff.instR rs e).SourceScoped 0 nt ne nv
```

## L20.29: 宣言本体の入力

三つの本体入力は L10F の受渡しの字面である。関数・メソッド・上位辞書の SourceScoped と旧の導出全体の LegacyOutputInput を読む。メソッドの Q は代入前の Qsig であり、新 WellTyped を入力の欄にしない。辞書の二供給元は既存の op_dictionaryInputs と impl_dictionaryKinds である。

### LegacyDeclarationInputs.lean

```lean
def functionBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (f : FunName) (d : Benitoite.Release.Def) : Prop :=
  LegacyOutputInput K P0 B0 B (.comp (K.functionParams f) Benitoite.Release.StoreTy.empty
    (Benitoite.Release.Qsig d.params d.ret d.eff) d.tparams (Benitoite.Release.binds d.params)
    (some d.ret) d.body d.ret d.eff [])

def methodBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (m : MethName) (ms : Benitoite.Release.MethSig) (body : Benitoite.Release.Comp) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.comp (K.methodParams id.cls m ++ List.replicate id.tparams.length .value)
      Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig ms.params ms.ret ms.eff)
      (ms.tparams ++ id.tparams)
      (Benitoite.Release.binds (id.dictTys.map (Benitoite.Release.Ty.shift ms.tparams.length 0) ++
        ms.params.map (id.methTy ms)))
      (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret)
      (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff) [])

def superBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (s : ClassName) (value : Benitoite.Release.Val) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.value (List.replicate id.tparams.length .value) Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty
      id.tparams (Benitoite.Release.binds id.dictTys) value (.dict s id.target))

def declarationBodyInputs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f d, P0.defs f = some d → functionBodyInput K P0 B0 B f d) ∧
  (∀ i id cd m ms body, P0.impls i = some id → P0.classes id.cls = some cd →
    cd.methods m = some ms → id.methods m = some body →
    methodBodyInput K P0 B0 B id m ms body) ∧
  (∀ i id cd s value, P0.impls i = some id → P0.classes id.cls = some cd →
    s ∈ cd.supers → id.supers s = some value → superBodyInput K P0 B0 B id s value)

structure LegacyDeclarationInputs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop where
  declarations : LegacyDeclarationsInput K P0 B0 B
  bodies : declarationBodyInputs K P0 B0 B
  functions : ∀ f d, P0.defs f = some d →
    (embedComp d.body).SourceScoped 0 d.tparams.length d.neffs d.params.length
  methods : ∀ i id cd m ms body, P0.impls i = some id → P0.classes id.cls = some cd →
    cd.methods m = some ms → id.methods m = some body →
    (embedComp body).SourceScoped 0 (ms.tparams.length + id.tparams.length)
      ms.neffs (id.dictTys.length + ms.params.length)
  supers : ∀ i id s value, P0.impls i = some id → id.supers s = some value →
    (embedVal value).SourceScoped 0 id.tparams.length 0 id.dictTys.length

theorem LegacyDeclarationInputs.function_body {K P0 B0 B f d}
    (h : LegacyDeclarationInputs K P0 B0 B) (hd : P0.defs f = some d) :
    functionBodyInput K P0 B0 B f d ∧
      (embedComp d.body).SourceScoped 0 d.tparams.length d.neffs d.params.length

theorem LegacyDeclarationInputs.method_body {K P0 B0 B i id cd m ms body}
    (h : LegacyDeclarationInputs K P0 B0 B) (hi : P0.impls i = some id)
    (hc : P0.classes id.cls = some cd) (hm : cd.methods m = some ms)
    (hb : id.methods m = some body) :
    methodBodyInput K P0 B0 B id m ms body ∧
      (embedComp body).SourceScoped 0 (ms.tparams.length + id.tparams.length)
        ms.neffs (id.dictTys.length + ms.params.length)

theorem LegacyDeclarationInputs.super_body {K P0 B0 B i id cd s value}
    (h : LegacyDeclarationInputs K P0 B0 B) (hi : P0.impls i = some id)
    (hc : P0.classes id.cls = some cd) (hs : s ∈ cd.supers)
    (hv : id.supers s = some value) :
    superBodyInput K P0 B0 B id s value ∧
      (embedVal value).SourceScoped 0 id.tparams.length 0 id.dictTys.length
```

## L20.30: 全形成と具体化

既存の Ty.Annotation.substAt・Tel.annotation_substAt・Ty.Declared.typeSubst・Tel.Declared.typeSubst を、NoTapp の制限なしで使う。拒否例は、WF000 だけでは像の sort を保証しない境界である。既存の gate_annotation_lam と gate_fun_list が正しい kind と Annotation の受理側を担当する。

### TypeSubstFormation.lean

```lean
theorem Ty.subst_substAt {nt : Nat} {a : Ty} (hw : a.WF 0 nt 0)
    (ts : List Ty) (es : List Eff) (hn : nt ≤ ts.length)
    (hr : a.RowsIn (· < es.length)) (c : Nat) (us : List Ty) (fs : List Eff) :
    (a.subst ts es).substAt c us fs =
      a.subst (ts.map (Ty.substAt c us fs)) (es.map (Eff.substAt c us fs))

theorem reject_unsorted_tapp_image :
    let image := Ty.refined (.base .string) (.eq (.var 0) (.integer 0))
    image.WF 0 0 0 ∧ (Ty.tapp 0 []).Sorted [] ∧
      ¬ ((Ty.tapp 0 []).substAt 0 [image] []).Sorted [] ∧
      ∀ P : Program, ¬ Ty.Annotation P [] [] image ∧
        ¬ image.HasKind P [] (.constructor 0)
```

## L20.32: 開いた像と値像の交換

型像・行像の外側の値依存を保つ。二つの lambda の閉じた値は、同じ cap と型置換した body を持つ閉包であり、環境を捨てない。BuilderKind.substAt は構文操作内の private な substBuilderAt と同じ式である。

### TypeValueExchange.lean

```lean
private theorem normImages (c : Nat) (ts : List Ty) (es : List Eff) :
    SubstEnv.SameTypes (typeEnvAt c (ts.map Ty.norm) (es.map Eff.norm))
      (typeEnvAt c ts es).normRows

theorem Ty.substAt_norm_images_all (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    a.substAt c (ts.map Ty.norm) (es.map Eff.norm) = a.substAt c ts es

theorem Eff.substAt_norm_images_all (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c (ts.map Ty.norm) (es.map Eff.norm) e = Eff.substAt c ts es e

theorem Tel.substAt_norm_images_all (t : Tel) (c : Nat) (ts : List Ty) (es : List Eff) :
    Tel.substAt c (ts.map Ty.norm) (es.map Eff.norm) t = Tel.substAt c ts es t

theorem Ty.substAt_substV_images (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : ObservationEnv) :
    (a.substAt c ts es).substV σ =
      (a.substV σ).substAt c (ts.map (Ty.substV σ)) (es.map (Eff.substV σ))

theorem Eff.substAt_substV_images (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : ObservationEnv) :
    Eff.substV σ (Eff.substAt c ts es e) =
      Eff.substAt c (ts.map (Ty.substV σ)) (es.map (Eff.substV σ)) (Eff.substV σ e)

theorem Tel.substAt_substV_images (t : Tel) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : ObservationEnv) :
    Tel.substV σ (Tel.substAt c ts es t) =
      Tel.substAt c (ts.map (Ty.substV σ)) (es.map (Eff.substV σ)) (Tel.substV σ t)

theorem Capture.closeTyAt_typeSubst (cap : Capture) (n c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) :
    cap.closeTyAt n (a.substAt c ts es) =
      (cap.closeTyAt n a).substAt c (ts.map (cap.closeTyAt n)) (es.map (cap.closeEffAt n))

theorem Capture.closeEffAt_typeSubst (cap : Capture) (n c : Nat) (ts : List Ty) (es : List Eff)
    (e : Eff) :
    cap.closeEffAt n (Eff.substAt c ts es e) =
      Eff.substAt c (ts.map (cap.closeTyAt n)) (es.map (cap.closeEffAt n)) (cap.closeEffAt n e)

theorem Capture.closeTel_typeSubst (cap : Capture) (c : Nat) (ts : List Ty) (es : List Eff)
    (t : Tel) :
    cap.closeTel (Tel.substAt c ts es t) =
      Tel.substAt c (ts.map cap.closeTy) (es.map cap.closeEff) (cap.closeTel t)

theorem Capture.closeRAt_typeSubst (cap : Capture) (n c : Nat) (ts : List Ty) (es : List Eff)
    (R : Option Ty) :
    cap.closeRAt n (R.map (Ty.substAt c ts es)) =
      (cap.closeRAt n R).map (Ty.substAt c (ts.map (cap.closeTyAt n)) (es.map (cap.closeEffAt n)))

theorem Val.toTerm_substTyAt (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      (v.substTyAt c ts es).toTerm? = v.toTerm?

theorem Val.toTermSlots_substTyAt (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      Val.toTermSlots (Val.substTyAtList c ts es vs) = Val.toTermSlots vs

noncomputable def BuilderKind.substAt (c : Nat) (ts : List Ty) (es : List Eff) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (a.substAt c ts es)

theorem substKind_typeSubst (ν : Nat → Val) (b : BuilderKind) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    substKind ν (BuilderKind.substAt c ts es b) =
      BuilderKind.substAt c (ts.map (substTyValues ν)) (es.map (substEffValues ν)) (substKind ν b)

theorem LocalCtx.typeSubst_values (L : LocalCtx) (ν : Nat → Val) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    (L.map (Option.map (BuilderKind.substAt c ts es))).map (Option.map (substKind ν)) =
      (L.map (Option.map (substKind ν))).map
        (Option.map (BuilderKind.substAt c (ts.map (substTyValues ν)) (es.map (substEffValues ν))))

theorem lambdaShape_typeSubst (ns : List String) (ps : List Ty) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    Tel.substAt c ts es (lambdaShape ns ps) =
      lambdaShape ns (ps.map (Ty.substAt c ts es))

theorem closeVal_dependentLam_typeSubst (cap : Capture) (t : Tel) (body : Comp)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    closeVal cap ((Val.dependentLam t body).substTyAt c ts es) =
      .closure (Tel.substAt c (ts.map cap.closeTy) (es.map cap.closeEff) (cap.closeTel t))
        (.mk cap (body.substTyAt c (ts.map (Ty.shiftV (telBinders t) 0))
          (es.map (Eff.shiftV (telBinders t) 0))))

theorem closeVal_lam_typeSubst (cap : Capture) (ns : List String) (ps : List Ty) (body : Comp)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    closeVal cap ((Val.lam ns ps body).substTyAt c ts es) =
      .closure (Tel.substAt c (ts.map cap.closeTy) (es.map cap.closeEff) (cap.closeTel (lambdaShape ns ps)))
        (.mk cap (body.substTyAt c (ts.map (Ty.shiftV ps.length 0))
          (es.map (Eff.shiftV ps.length 0))))
```

## L20.33〜.36: パターン・所属・網羅性

S03 の候補どおり、P.WellFormed だけを取る。型像の kind や新しい行支持の前提を足さない。構成子の欄の行支持は Program.WellFormed.cons から供給する。所属の反映は、値の大きさの外側の帰納と、篩の基底へ進む型の大きさの内側の帰納で証明する。

### PatternTypeSubst.lean

```lean
private theorem data_image (d : DataName) (xs : List Ty) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    (Ty.data d xs).substAt c ts es = .data d (xs.map (Ty.substAt c ts es))

theorem PatTy.substAt {P p a δ} (h : PatTy P p a δ) (hp : P.WellFormed)
      (c : Nat) (ts : List Ty) (es : List Eff) :
      PatTy P p (a.substAt c ts es) (δ.map (Ty.substAt c ts es))

theorem PatTys.substAt {P ps as δ} (h : PatTys P ps as δ) (hp : P.WellFormed)
      (c : Nat) (ts : List Ty) (es : List Eff) :
      PatTys P ps (as.map (Ty.substAt c ts es)) (δ.map (Ty.substAt c ts es))

theorem AltsTy.substAt {P alts a δ} (h : AltsTy P alts a δ) (hp : P.WellFormed)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    AltsTy P alts (a.substAt c ts es) (δ.map (Ty.substAt c ts es))

private theorem all_reflect {P as vs} (f : Ty → Ty)
    (h : InhabitsAll P (as.map f) vs)
    (ih : ∀ a v, v ∈ vs → Inhabits P (f a) v → Inhabits P a v) :
    InhabitsAll P as vs

private theorem each_reflect {P a vs} (f : Ty → Ty)
    (h : InhabitsEach P (f a) vs)
    (ih : ∀ v, v ∈ vs → Inhabits P (f a) v → Inhabits P a v) :
    InhabitsEach P a vs

private theorem reflect_type {P} (hp : P.WellFormed) (c : Nat)
    (ts : List Ty) (es : List Eff) (v : Val)
    (ih : ∀ w, sizeOf w < sizeOf v → ∀ a, Inhabits P (a.substAt c ts es) w → Inhabits P a w)
    (a : Ty) (h : Inhabits P (a.substAt c ts es) v) : Inhabits P a v

private theorem reflect_value {P} (hp : P.WellFormed) (c : Nat)
    (ts : List Ty) (es : List Eff) (v : Val) :
    ∀ a, Inhabits P (a.substAt c ts es) v → Inhabits P a v

theorem Inhabits.of_substAt {P : Program} {a : Ty} {v : Val} (c : Nat) (ts : List Ty) (es : List Eff)
    (hp : P.WellFormed) (h : Inhabits P (a.substAt c ts es) v) :
    Inhabits P a.norm v

theorem InhabitsAll.of_substAt {P as vs} (c : Nat) (ts : List Ty) (es : List Eff)
    (hp : P.WellFormed) (h : InhabitsAll P (as.map (Ty.substAt c ts es)) vs) :
    InhabitsAll P as vs

theorem InhabitsEach.of_substAt {P : Program} {a : Ty} {vs : List Val} (c : Nat) (ts : List Ty) (es : List Eff)
    (hp : P.WellFormed) (h : InhabitsEach P (a.substAt c ts es) vs) :
    InhabitsEach P a vs

theorem unguardedPats_substTy (arms : List Arm) (c : Nat) (ts : List Ty) (es : List Eff) :
    unguardedPats (Arm.substTyAtList c ts es arms) = unguardedPats arms

theorem Exhaustive.substAt {P a ps} (h : Exhaustive P a ps) (hp : P.WellFormed)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    Exhaustive P (a.substAt c ts es) ps
```

既存の data の逆転を再作成せず、次の名前で公開した。命題と証明は同じである。

### PatternNormalForm.lean

```lean
theorem Inhabits.data_inv {P a v} (h : Inhabits P a v) :
    ∀ d ts, a = .data d ts →
      (∃ c tys args cd, v = .con c tys args ∧ P.cons c = some cd ∧ cd.data = d ∧
        cd.ntys = ts.length ∧ (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) ∧
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args) ∨
      (d = "Scope.ScopeError" ∧ ts = [] ∧ ∃ detail, v = .atError detail ∧
        ResultShape.StandardError P ⟨"Result","Ok","Error",atErrorType⟩)
```

## L20.37: 呼出しの入力と許容

既存の typeScope・method_body_typeScope・raise_typeScope と fail_input を使う。SatAll.substAt、NoFail.substAt、SignatureInstance.substAt、TypeSubstInput.under は既存の同じ補題を再利用する。以下の許容の移送は、既存の sat_subst/admits_subst と sourceQ の上限を使う。

### TypeSubstCalls.lean

```lean
theorem SignatureInstance.closedInput {P B C0 C1 t ts es}
    (h : SignatureInstance P [] [] t (TypeCtx.kinds C0) ts es)
    (hs : SatAll B C1 ts (TypeCtx.constraints C0)) :
    TypeSubstInput P B C0 C1 ts es

theorem RowTransport.substAt {Qs Q Q' fs es} (h : RowTransport Qs Q fs)
    (hb : ∀ i, Qs i → i < fs.length) (hq : RowTransport Q Q' es)
    (c : Nat) (ts : List Ty) :
    RowTransport Qs Q' (fs.map (Eff.substAt c ts es))

theorem Admissible.substAt {P B} {Ψ : StoreTy}
    {C0 C1 Γ tps ne Qs Q Q' as fs e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (h : Admissible B (C1 ++ C0) Γ.length tps ne Qs Q as fs e)
    (ht : TypeAnnotations P (C1 ++ C0) Γ as)
    (hr : RowAnnotations P (C1 ++ C0) Γ fs)
    (hq : RowTransport Q Q' es) :
    Admissible B C1 (Γ.bindTypes (typeEnvAt C1.length ts es)).length tps ne Qs Q'
      (as.map (Ty.substAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es)) e

theorem PrimitiveAdmissible.substAt {P B} {Ψ : StoreTy}
    {C0 C1 Γ b s Q Q' as fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es) (hb : B.sig b = some s)
    (h : PrimitiveAdmissible (C1 ++ C0) Γ.length s Q as fs)
    (ht : TypeAnnotations P (C1 ++ C0) Γ as)
    (hr : RowAnnotations P (C1 ++ C0) Γ fs)
    (hq : RowTransport Q Q' es) :
    PrimitiveAdmissible C1 (Γ.bindTypes (typeEnvAt C1.length ts es)).length s Q'
      (as.map (Ty.substAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es))

theorem MethodRowsAdmissible.substAt {P B} {Ψ : StoreTy}
    {C0 C1 Γ Q Q' ms fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (h : MethodRowsAdmissible (C1 ++ C0) Γ.length Q ms fs)
    (hr : RowAnnotations P (C1 ++ C0) Γ fs) (hq : RowTransport Q Q' es) :
    MethodRowsAdmissible C1 (Γ.bindTypes (typeEnvAt C1.length ts es)).length Q' ms
      (fs.map (Eff.substAt C1.length ts es))

theorem TypeArgsKinded.append {P C as bs ks ls}
    (h : TypeArgsKinded P C as ks) (g : TypeArgsKinded P C bs ls) :
    TypeArgsKinded P C (as++bs) (ks++ls)

theorem SatAll.append {B C as bs ps qs} (h : SatAll B C as ps) (g : SatAll B C bs qs) :
    SatAll B C (as++bs) (ps++qs)

private theorem dict_core_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    ∀ cl τ, a.norm.core = .dict cl τ → b.norm.core = .dict cl τ

theorem HasTypeVQ.dict_callInputs {P B Ψ Q C Γ Φ v a i ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .dict i ts vs) :
    ∃ id, P.impls i = some id ∧
      a.norm.core = .dict id.cls (id.target.subst ts []).norm ∧
      SatAll B C ts id.tparams ∧ TypeAnnotations P C Γ ts ∧
      TypeArgsKinded P C ts (List.replicate id.tparams.length .value) ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (id.dictTys.map (Ty.subst ts []))

theorem dict_call_link {P B Ψ Q C Γ Φ i ts vs cl τ}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) (.dict cl τ)) :
    ∃ id, P.impls i = some id ∧ id.cls = cl ∧ τ.norm = (id.target.subst ts []).norm

theorem method_body_input {P B Ψ Q Φ i us vs cl τ t ss es ks} {ms : MethSig}
    (hdict : HasTypeVQ P B Ψ Q [] [] Φ (.dict i us vs) (.dict cl τ))
    (hs : SatAll B [] ss (TypeCtx.constraints ms.tparams))
    (hi : SignatureInstance P [] [] t (TypeCtx.kinds ms.tparams ++ [ks]) (ss++[τ]) es) :
    ∃ id, P.impls i = some id ∧ id.cls = cl ∧
      τ.norm = (id.target.subst us []).norm ∧
      HasTypeVsQ P B Ψ Q [] [] Φ vs (id.dictTys.map (Ty.subst us [])) ∧
      TypeSubstInput P B (ms.tparams ++ TypeCtx.values id.tparams) [] (ss++us) es

private theorem method_input_aux {P B Ψ Q C Γ Φ R m a e L i us vs name ss fs ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    C = [] → Γ = [] → m = .meth (.dict i us vs) name ss fs ws →
    ∃ id cl cd ms, ∃ τ : Ty, P.impls i = some id ∧ P.classes cl = some cd ∧
      cd.methods name = some ms ∧ id.cls = cl ∧
      τ.norm = (id.target.subst us []).norm ∧
      HasTypeVsQ P B Ψ Q [] [] Φ vs (id.dictTys.map (Ty.subst us [])) ∧
      TypeSubstInput P B (ms.tparams ++ TypeCtx.values id.tparams) [] (ss++us) fs ∧
      fs.length = ms.neffs ∧ RowTransport (QTel ms.tel) Q fs

theorem HasTypeCQ.method_body_input {P B Ψ Q Φ R m a e L i us vs name ss fs ws}
    (h : HasTypeCQ P B Ψ Q [] [] Φ R m a e L)
    (hm : m = .meth (.dict i us vs) name ss fs ws) :
    ∃ id cl cd ms, ∃ τ : Ty, P.impls i = some id ∧ P.classes cl = some cd ∧
      cd.methods name = some ms ∧ id.cls = cl ∧
      τ.norm = (id.target.subst us []).norm ∧
      HasTypeVsQ P B Ψ Q [] [] Φ vs (id.dictTys.map (Ty.subst us [])) ∧
      TypeSubstInput P B (ms.tparams ++ TypeCtx.values id.tparams) [] (ss++us) fs ∧
      fs.length = ms.neffs ∧ RowTransport (QTel ms.tel) Q fs
```

## L20.38: 全束縛の写像

値束縛1・n・n+1・2と型束縛k・1を、同じ内部入力へ渡す。OpSig の文脈の像は、写像した params/ret を持つ署名の文脈である。原文へ戻す橋は L20.54 が担当する。31位置の対応は results.md に記す。

### TypeSubstBindings.lean

```lean
theorem map_typeImages_shiftV_closed {ts : List Ty} (h : ∀ t ∈ ts, t.WF 0 0 0) (n : Nat) :
    ts.map (Ty.shiftV n 0) = ts

theorem map_rowImages_shiftV_closed {es : List Eff} (h : ∀ t ∈ es, t.WF 0 0 0) (n : Nat) :
    es.map (Eff.shiftV n 0) = es

theorem substAt_shiftV_closed {ts : List Ty} {es : List Eff} (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (he : ∀ t ∈ es, t.WF 0 0 0) (a : Ty) (c n : Nat) :
    (a.shiftV n 0).substAt c ts es = (a.substAt c ts es).shiftV n 0

theorem eff_substAt_shiftV_closed {ts : List Ty} {es : List Eff} (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (he : ∀ t ∈ es, t.WF 0 0 0) (a : Eff) (c n : Nat) :
    Eff.substAt c ts es (Eff.shiftV n 0 a) = Eff.shiftV n 0 (Eff.substAt c ts es a)

theorem cont_rawBind {a : Ty} {b t e} (h : a.core = .cont b t e) (θ : SubstEnv) :
    ∃ b' t' e', (a.rawBind θ).core = .cont b' t' e'

theorem not_ord {a : Ty} (h : ¬ Ordinary a) : ∃ b t e, a.core = .cont b t e

theorem cont_bind {a : Ty} (h : ¬ Ordinary a) (θ : SubstEnv) : ¬ Ordinary (a.bind θ)

theorem hide_entry (x : Option Ty) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    Option.map (Ty.bind θ) (match x with
      | some t => match t.core with
        | .cont _ _ _ => none
        | _ => some t
      | none => none) =
    (match Option.map (Ty.bind θ) x with
      | some t => match t.core with
        | .cont _ _ _ => none
        | _ => some t
      | none => none)

theorem Ctx.bindTypes_hideConts (Γ : Ctx) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    (hideConts Γ).bindTypes θ = hideConts (Γ.bindTypes θ)

theorem Ctx.bindTypes_params {ts es} (ht : ∀ t ∈ ts, t.WF 0 0 0) (he : ∀ t ∈ es, t.WF 0 0 0)
    (Γ : Ctx) (ps : List Ty) (c : Nat) :
    (bindParams Γ ps).bindTypes (typeEnvAt c ts es) =
      bindParams (Γ.bindTypes (typeEnvAt c ts es)) (ps.map (Ty.substAt c ts es))

private theorem bind_shift_source (a : Ty) (θ : SubstEnv) (k : Nat) :
      (shiftTypes k 0 a).rawBind θ =
        a.rawBind {θ with types := fun i => θ.types (i+k)}

private theorem bind_shift_source_tys (as : List Ty) (θ : SubstEnv) (k : Nat) :
      rawBindTys θ (shiftTypesList k 0 as) =
        rawBindTys {θ with types := fun i => θ.types (i+k)} as

private theorem bind_shift_source_eff (e : Eff) (θ : SubstEnv) (k : Nat) :
      Eff.rawBind θ (shiftRowsTypes k 0 e) =
        Eff.rawBind {θ with types := fun i => θ.types (i+k)} e

private theorem bind_shift_source_tel (t : Tel) (θ : SubstEnv) (k : Nat) :
      Tel.rawBind θ (shiftTelTypes k 0 t) =
        Tel.rawBind {θ with types := fun i => θ.types (i+k)} t

private theorem typeEnv_prefix {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (c k : Nat) :
    {typeEnvAt (c+k) ts es with types := fun i => (typeEnvAt (c+k) ts es).types (i+k)} =
      (typeEnvAt c ts es).mapTypeIndices k 0

theorem Ty.substAt_shift_types {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (a : Ty) (c k : Nat) :
    (shiftTypes k 0 a).substAt (c+k) ts es = shiftTypes k 0 (a.substAt c ts es)

theorem Eff.substAt_shift_types {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (e : Eff) (c k : Nat) :
    Eff.substAt (c+k) ts es (shiftRowsTypes k 0 e) = shiftRowsTypes k 0 (Eff.substAt c ts es e)

theorem Ctx.bindTypes_extend {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (a : Ty) (c : Nat) :
    (Γ.extend a).bindTypes (typeEnvAt c ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).extend (a.substAt c ts es)

theorem Ctx.bindTypes_extendNone {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (c : Nat) :
    Γ.extendNone.bindTypes (typeEnvAt c ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).extendNone

theorem Ctx.bindTypes_extendMany {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (as : List Ty) (c : Nat) :
    (Γ.extendMany as).bindTypes (typeEnvAt c ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).extendMany (as.map (Ty.substAt c ts es))

theorem Ctx.bindTypes_shiftE {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (c k : Nat) :
    (Γ.shiftE k).bindTypes (typeEnvAt (c+k) ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).shiftE k

noncomputable def OpSig.substAt (c : Nat) (ts : List Ty) (es : List Eff) (sg : OpSig) : OpSig :=
  {sg with params := sg.params.map (Ty.substAt c ts es),ret := sg.ret.substAt c ts es}

theorem OpSig.context_typeSubst {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff) (c : Nat) :
    (sg.context Γ t e).bindTypes (typeEnvAt (c+sg.tparams.length) ts es) =
      (sg.substAt (c+sg.tparams.length) ts es).context
        (Γ.bindTypes (typeEnvAt c ts es)) (t.substAt c ts es) (Eff.substAt c ts es e)

theorem failureContext_typeSubst {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (E : Ty) (c : Nat) :
    (failureContext Γ E).bindTypes (typeEnvAt (c+1) ts es) =
      failureContext (Γ.bindTypes (typeEnvAt c ts es)) (E.substAt c ts es)

theorem BuilderKind.substAt_rename_shift {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (b : BuilderKind) (c n : Nat) :
    BuilderKind.substAt c ts es (renameKind (shiftIndex n 0) b) =
      renameKind (shiftIndex n 0) (BuilderKind.substAt c ts es b)

theorem LocalCtx.typeSubst_extend {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (L : LocalCtx) (b : Option BuilderKind) (c : Nat) :
    (LocalCtx.extend b L).map (Option.map (BuilderKind.substAt c ts es)) =
      LocalCtx.extend (b.map (BuilderKind.substAt c ts es))
        (L.map (Option.map (BuilderKind.substAt c ts es)))

theorem LocalCtx.typeSubst_localExtend {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (L : LocalCtx) (c n : Nat) :
    (localExtend n L).map (Option.map (BuilderKind.substAt c ts es)) =
      localExtend n (L.map (Option.map (BuilderKind.substAt c ts es)))

theorem return_typeSubst_shiftV {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (R : Option Ty) (c n : Nat) :
    (R.map (Ty.shiftV n 0)).map (Ty.substAt c ts es) =
      (R.map (Ty.substAt c ts es)).map (Ty.shiftV n 0)

theorem TypeSubstCode.binders {es : List Eff} {source child : Nat → Nat → Nat → Nat → Prop}
    (h : TypeSubstCode es source) (k n : Nat)
    (hc : ∀ nr nt ne nv, source nr nt ne nv → child nr (nt+k) ne (nv+n)) :
    TypeSubstCode es child

theorem S02Internal.C.under_types (ih : S02Internal.C) {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ R m a e L ts es} (extra : TypeCtx)
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (ht : HasTypeCQ P B Ψ Q (extra ++ C1 ++ C0) Γ Φ R m a e L) :
    HasTypeCQ P B Ψ Q' (extra ++ C1)
      (Γ.bindTypes (typeEnvAt (extra ++ C1).length ts es)) Φ
      (R.map (Ty.substAt (extra ++ C1).length ts es))
      (m.substTyAt (extra ++ C1).length ts es) (a.substAt (extra ++ C1).length ts es)
      (Eff.substAt (extra ++ C1).length ts es e)
      (L.map (Option.map (BuilderKind.substAt (extra ++ C1).length ts es)))
```
