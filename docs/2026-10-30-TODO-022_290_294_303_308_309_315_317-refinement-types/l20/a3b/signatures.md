# L20 A3b の完全署名

2026-11-02。B_WORK: `98188437a88c6b70a76735d24764753b6a645f37`。ブランチは起動依頼の `m014/l20.a3b` を正とし、git では照合しない。

L20.14 と四移送の既済み分は A3a の実装を照合する。以下は実装前に固定した契約であり、未証明の言明を本番の定理として置くものではない。

# A3a の完全署名

B_WORK: `14492156debe5f6b8925963e55c2d9aecdc6923c`。ブランチの操作は行わない。実装前に固定する。

S12.1〜.5/.7/.11 の定義・署名を次に展開する。`rowKinds` の追加と kind 像の四族の証明は A3b とする。既定ビルドの依存として、Declared の型 shift の七補助と既存の読者への hC の供給を同じ変更で追随する。四本の主な移送の入口の字面は変えない。V_Raise の結果型の kind 前提と八つの明示 arity は今回扱う。旧 Release は変えない。

```lean
abbrev TypeCtx := List TParamDecl
namespace TypeCtx
  def constraints (C : TypeCtx) : List Benitoite.Release.TParam :=
    C.map TParamDecl.constraints
  def kinds (C : TypeCtx) : KindCtx := C.map TParamDecl.kind
  def values (ps : List Benitoite.Release.TParam) : TypeCtx := ps.map embedTParam
  def valueParam : TParamDecl := ⟨{}, .value⟩
end TypeCtx

def TypeArgsKinded (P : Program) (C : TypeCtx)
    (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k →
      a.HasKind P (TypeCtx.kinds C) k ∧ (k = .value → Ordinary a)
```

```lean
-- Builtins/PrimSig の既存の二欄は型を維持する。
Builtins.sat : List Benitoite.Release.TParam → Ty → Benitoite.Release.TParam → Prop
PrimSig.admits : List Benitoite.Release.TParam → List Ty → Prop

def SatAll (B : Builtins) (C : TypeCtx) (ts : List Ty)
    (ps : List Benitoite.Release.TParam) : Prop :=
  ts.length = ps.length ∧ ∀ (i : Nat) (t : Ty) (p : Benitoite.Release.TParam),
    ts[i]? = some t → ps[i]? = some p → B.sat (TypeCtx.constraints C) t.norm p

structure Admissible (B : Builtins) (C : TypeCtx) (nv : Nat)
    (ps : List Benitoite.Release.TParam) (ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : SatAll B C ts ps
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length nv t ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es
```

```lean
def SignatureScoped (P : Program) (C : TypeCtx) (ne : Nat) (t : Tel) : Prop :=
  (Ty.dependentFn t).SourceScoped 0 C.length ne 0 ∧ t.RowsIn (· < ne) ∧
    Ty.HasKind P (TypeCtx.kinds C) (.dependentFn t) .value ∧ Ty.Annotation P C [] (.dependentFn t)

def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (TypeCtx.kinds d.tparams) (.dependentFn d.tel) .value ∧
  Ty.Annotation P d.tparams [] (.dependentFn d.tel) ∧
  TelBodyTy P B StoreTy.empty (QTel d.tel) d.tparams [] [] d.tel d.body

def Def.Scoped (P : Program) (d : Def) : Prop :=
  NamesWF d.names d.params ∧ SignatureScoped P d.tparams d.neffs d.tel ∧
    d.body.SourceScoped 0 d.ntys d.neffs d.params.length

def MethSig.Scoped (P : Program) (argumentKind : TyKind) (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    SignatureScoped P (ms.tparams ++ [⟨{}, argumentKind⟩]) ms.neffs ms.tel

def ConDecl.Scoped (P : Program) (cd : ConDecl) : Prop :=
  ∀ a ∈ cd.args, a.SourceScoped 0 cd.ntys 0 0 ∧
    Ty.Annotation P (List.replicate cd.ntys TypeCtx.valueParam) [] a ∧
    a.HasKind P (List.replicate cd.ntys .value) .value

def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (TypeCtx.kinds (TypeCtx.values id.tparams)) id.target cd.argumentKind ∧
    TypeAnnotations P (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams ++ TypeCtx.values id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty (TypeCtx.values id.tparams) (bindParams [] id.dictTys) []
        u (.dict s id.target))
```

```lean
| V_Raise {Ψ Q C Γ Φ T E} :
    Ty.Annotation P C Γ (.fn ["error"] [E] T (Eff.singleFail E)) →
    Ordinary T → Ordinary E → T.HasKind P (TypeCtx.kinds C) .value →
    HasTypeVQ P B Ψ Q C Γ Φ (.raise T E) (.fn ["error"] [E] T (Eff.singleFail E))
```

```lean
def KindRenaming (K L : KindCtx) (ρ : Nat → Nat) : Prop :=
  ∀ (i : Nat) (ki : TyKind), K[i]? = some ki → L[ρ i]? = some ki

def TypeParamRenaming (C C' : TypeCtx) (ρ : Nat → Nat) : Prop :=
  ∀ (i : Nat) (p : TParamDecl), C[i]? = some p →
    ∃ q, C'[ρ i]? = some q ∧ q.kind = p.kind ∧
      TParam.Contains q.constraints p.constraints

TypeParamRenaming.kindRenaming : ∀ {C C' ρ},
  TypeParamRenaming C C' ρ → KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') ρ
TypeArgsKinded.shiftTypes : ∀ {P C C' ts ks k c},
  TypeArgsKinded P C ts ks → TypeParamRenaming C C' (shiftIndex k c) →
  TypeArgsKinded P C' (ts.map (shiftTypes k c)) ks
```

```lean
def legacyTypeCtx (C : List Benitoite.Release.TParam) (κ : KindCtx) : TypeCtx :=
  embedTParamsWithKinds C κ
legacyTypeCtx_constraints : ∀ {C κ}, κ.length = C.length →
  (TypeCtx.constraints (legacyTypeCtx C κ)) = C
legacyTypeCtx_kinds : ∀ {C κ}, κ.length = C.length →
  (TypeCtx.kinds (legacyTypeCtx C κ)) = κ
```

```lean
Ty.HasKind.closed_context : ∀ {P K K' a k nr nv},
  a.WF nr 0 nv → a.HasKind P K k → a.HasKind P K' k
kindsEff.closed_context : ∀ {P K K' e nr nv},
  e.WF nr 0 nv → kindsEff P K e → kindsEff P K' e
Ty.HasKind.substAt : ∀ {P C0 C1 a k ts es},
  a.HasKind P (TypeCtx.kinds (C1 ++ C0)) k →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) →
  (a.substAt C1.length ts es).HasKind P (TypeCtx.kinds C1) k
Tel.kinded_substAt : ∀ {P C0 C1 t ts es},
  kindsTel P (TypeCtx.kinds (C1 ++ C0)) t → TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) → kindsTel P (TypeCtx.kinds C1) (t.substAt C1.length ts es)
TypeArgsKinded.substAt : ∀ {P C0 C1 as ks ts es},
  TypeArgsKinded P (C1 ++ C0) as ks →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) → (∀ e ∈ es, kindsEff P [] e) →
  TypeArgsKinded P C1 (as.map (Ty.substAt C1.length ts es)) ks
```

```lean
structure ClosedTypeSubstInput (P : Program) (B : Builtins)
    (C0 C1 : TypeCtx) (Γ : Ctx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = C0.length
  typeWF : ∀ t ∈ ts, t.WF 0 0 0
  typeKinds : TypeArgsKinded P [] ts (TypeCtx.kinds C0)
  typeAnnotations : TypeAnnotations P [] [] ts
  constraints : SatAll B C1 ts (TypeCtx.constraints C0)
  rowWF : ∀ e ∈ es, e.WF 0 0 0
  rowAnnotations : RowAnnotations P [] [] es
  rowKinds : ∀ e ∈ es, kindsEff P [] e
  context : CaptureContextRegular P (C1 ++ C0) Γ
```

```lean
structure SignatureInstance (P : Program) (C : TypeCtx) (Γ : Ctx)
    (t : Tel) (ks : List TyKind) (ts : List Ty) (es : List Eff) : Prop where
  source : (Ty.dependentFn t).WF 0 ks.length 0
  types : TypeAnnotations P C Γ ts
  kinds : TypeArgsKinded P C ts ks
  rows : RowAnnotations P C Γ es
  rowKinds : ∀ e ∈ es, kindsEff P (TypeCtx.kinds C) e
  result : Ty.Annotation P C Γ (.dependentFn (instantiatedTel t ts es))
```

```lean
gate_op_case : ∀ {P B Ψ Q Q' C0 C1 Γ Φ o us a ts es},
  F → ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.op o us) a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V (.op o us)) (A a)
gate_fun_case : ∀ {P B Ψ Q Q' C0 C1 Γ Φ f us fs a ts es},
  F → ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.fnRef f us fs) a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V (.fnRef f us fs)) (A a)
gate_meth_case : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R v m ss fs ws a e L ts es},
  F → ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R (.meth v m ss fs ws) a e L →
  HasTypeCQ P B Ψ Q' C1 (G Γ) Φ (RR R)
    ((Comp.meth v m ss fs ws).substTyAt c ts es) (A a) (E e) (Lθ L)
```

```lean
gate_annotation_escape : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R v a e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R (.escape v) a e L →
  HasTypeCQ P B Ψ Q' C1 (G Γ) Φ (RR R) (.escape (V v)) (A a) (E e) (Lθ L)
gate_annotation_lam : ∀ {P B Ψ Q Q' C0 C1 Γ Φ ns ps body a ts es},
  F → I → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.lam ns ps body) a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V (.lam ns ps body)) (A a)
```

```lean
mutual
  def Ty.Declared (P : Program) (C : TypeCtx) (Γ : Ctx) : Ty → Prop
    | .base _ | .bytes | .opaque _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ | .tvar _ => True
    | .data d as => (∃ n, P.DataArity d n ∧ as.length = n) ∧ declaredTys P C Γ as
    | .external id as => (∃ td, P.externalType id = some td ∧ td.id = id ∧ as.length = td.arity) ∧
        declaredTys P C Γ as
    | .tapp i as => (TypeCtx.kinds C)[i]? = some (.constructor as.length) ∧ declaredTys P C Γ as
    | .ctor (.data d) => ∃ n, P.DataArity d n
    | .ctor _ => True
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.Declared P C Γ a
    | .fn _ ps r e => declaredTys P C Γ ps ∧ Ty.Declared P C Γ r ∧ declaredEff P C Γ e
    | .dependentFn t => Tel.Declared P C Γ t
    | .cont b t e => Ty.Declared P C Γ b ∧ Ty.Declared P C Γ t ∧ declaredEff P C Γ e
    | .map a b => Ty.Declared P C Γ a ∧ Ty.Declared P C Γ b
    | .refined a p => Ty.Declared P C Γ a ∧ Pred.Declared P C Γ (some a) p
  def Tel.Declared (P : Program) (C : TypeCtx) (Γ : Ctx) : Tel → Prop
    | .done r e => Ty.Declared P C Γ r ∧ declaredEff P C Γ e
    | .param _ a t => Ty.Declared P C Γ a ∧ Tel.Declared P C (Γ.extend a) t
  def declaredTys (P : Program) (C : TypeCtx) (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => Ty.Declared P C Γ a ∧ declaredTys P C Γ as
  def declaredEff (P : Program) (C : TypeCtx) (Γ : Ctx) : Eff → Prop
    | .mk _ fs => declaredTys P C Γ fs
end
```

```lean
Ty.Declared.rename_tapp : ∀ {P C C' Γ Δ i as ρ},
  Ty.Declared P C Γ (.tapp i as) →
  KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') ρ →
  declaredTys P C' Δ (rawRenameTypesList ρ as) →
  Ty.Declared P C' Δ ((Ty.tapp i as).rawRenameTypes ρ)
Ty.Declared.shiftTypes : ∀ {P C C' Γ Δ a k c},
  Ty.Declared P C Γ a → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  Ty.Declared P C' Δ (shiftTypes k c a)
Tel.Declared.shiftTypes : ∀ {P C C' Γ Δ t k c},
  Tel.Declared P C Γ t → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  Tel.Declared P C' Δ (shiftTelTypes k c t)
declaredTys_shiftTypes : ∀ {P C C' Γ Δ as k c},
  declaredTys P C Γ as → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  declaredTys P C' Δ (shiftTypesList k c as)
declaredEff_shiftTypes : ∀ {P C C' Γ Δ e k c},
  declaredEff P C Γ e → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  declaredEff P C' Δ (shiftRowsTypes k c e)
TypeCtxMap.annotation : ∀ {P C C' Γ Δ a k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → Ty.Annotation P C Γ a →
  TypeParamRenaming C C' (shiftIndex k c) → Ty.Annotation P C' Δ (shiftTypes k c a)
TypeCtxMap.annotations : ∀ {P C C' Γ Δ as k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → TypeAnnotations P C Γ as →
  TypeParamRenaming C C' (shiftIndex k c) →
  TypeAnnotations P C' Δ (as.map (shiftTypes k c))
TypeCtxMap.rows : ∀ {P C C' Γ Δ es k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → RowAnnotations P C Γ es →
  TypeParamRenaming C C' (shiftIndex k c) →
  RowAnnotations P C' Δ (es.map (shiftRowsTypes k c))
TypeCtxMap.methodRows : ∀ {P C C' Γ Δ ms Q es k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → RowAnnotations P C Γ es →
  MethodRowsAdmissible C Γ.length Q ms es →
  MethodRowsAdmissible C' Δ.length Q ms (es.map (shiftRowsTypes k c))
```

```lean
embedTy_declared_context : ∀ (a : Benitoite.Release.Ty) (P : Program)
    (C D : TypeCtx) (Γ Δ : Ctx), TypeCtx.kinds C = TypeCtx.kinds D →
  ((embedTy a).Declared P C Γ ↔ (embedTy a).Declared P D Δ)
embedTys_declared_context : ∀ (as : List Benitoite.Release.Ty) (P : Program)
    (C D : TypeCtx) (Γ Δ : Ctx), TypeCtx.kinds C = TypeCtx.kinds D →
  (declaredTys P C Γ (embedTys as) ↔ declaredTys P D Δ (embedTys as))
embedEff_declared_context : ∀ (e : Benitoite.Release.Eff) (P : Program)
    (C D : TypeCtx) (Γ Δ : Ctx), TypeCtx.kinds C = TypeCtx.kinds D →
  (declaredEff P C Γ (embedEff e) ↔ declaredEff P D Δ (embedEff e))
```

```lean
Ty.Declared.substAt : ∀ {P B Ψ C0 C1 Γ a ts es},
  F → I → Ty.Annotation P (C1 ++ C0) Γ a →
  Ty.Declared P C1 (G Γ) (A a)
Tel.Declared.substAt : ∀ {P B Ψ C0 C1 Γ t ts es},
  F → I → Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t) →
  Tel.Declared P C1 (G Γ) (T t)
declaredTys_substAt : ∀ {P B Ψ C0 C1 Γ as ts es},
  F → I → TypeAnnotations P (C1 ++ C0) Γ as →
  declaredTys P C1 (G Γ) (as.map A)
declaredEff_substAt : ∀ {P B Ψ C0 C1 Γ e ts es},
  F → I → RowAnnotations P (C1 ++ C0) Γ [e] →
  declaredEff P C1 (G Γ) (E e)
```

## 型置換の motive の式

次は後続の証明が対象とする契約であり、A3a では証明済みとしない。

`θ := typeEnvAt c ts es`、`A a := a.substAt c ts es`、`E e := Eff.substAt c ts es e`、`G Γ := Γ.bindTypes θ`、`Lθ L := L.map (Option.map Kθ)`、`Kθ (.list a) := .list (A a)`、他の BuilderKind は恒等、と定める。これは既存 Comp.substTyAt が使う型・行の写しそのものである。

```lean
-- 予定する閉じた型像の入口。行の WF・RowsIn・Q の条件も下の入力形で渡す。
type_subst_comp : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R m a e L ts es},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P → Ψ.WF →
  ClosedTypeSubstInput P B C0 C1 Γ ts es →
  RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
    (R.map (Ty.substAt C1.length ts es))
    (m.substTyAt C1.length ts es) (a.substAt C1.length ts es)
    (Eff.substAt C1.length ts es e) (L.map (Option.map Kθ))
```

`ClosedTypeSubstInput`の完全な定義はS12.7に置く。C0/C1はTypeCtx、SatAllの相手は(TypeCtx.constraints C0)、型像のkindは(TypeCtx.kinds C0)から固定して読む。閉じた型/行像のWF000、Annotation、kindと元ΓのCaptureContextRegularを持ち、RowTransportは公開署名の別入力とする。元コードのRowsIn/行数は実際のAdmissibleと元の型付けから維持する。型付け・形成・移送の結論を入力欄にしない。C1は残す型束縛であり、一般のcutoffでは同じ入力を接頭辞に分解する。

十四成分の完全署名を次に固定する。ここで `c := C1.length`、`I := ClosedTypeSubstInput P B C0 C1 Γ ts es` とし、`A/E/G/Kθ/Lθ` は上記の式、`V v := v.substTyAt c ts es`、`Vs := List.map V`、`T := Tel.substAt c ts es`、`AR := Arm.substTyAtList c ts es`、`CL := Clause.substTyAtList c ts es`、`RR := Option.map A` という**引数を省略しない式の略記**を使う。各行の `I` は形成の結論そのものを含まない入力である。共通前提 `F := P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF` を一度だけ略記する。実装前にはこの略記を展開した `#check/#print` を results に保存する。

```lean
S02_V : ∀ {P B Ψ Q Q' C0 C1 Γ Φ v a ts es},
  F → I → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V v) (A a)
S02_Vs : ∀ {P B Ψ Q Q' C0 C1 Γ Φ vs as ts es},
  F → I → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ vs as →
  HasTypeVsQ P B Ψ Q' C1 (G Γ) Φ (Vs vs) (as.map A)
S02_Each : ∀ {P B Ψ Q Q' C0 C1 Γ Φ vs a ts es},
  F → I → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ Φ vs a →
  HasTypeEachQ P B Ψ Q' C1 (G Γ) Φ (Vs vs) (A a)
S02_C : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R m a e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 (G Γ) Φ (RR R) (m.substTyAt c ts es) (A a) (E e) (Lθ L)
S02_Args : ∀ {P B Ψ Q Q' C0 C1 Γ Φ vs t a e ts es},
  F → I → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q (C1 ++ C0) Γ Φ vs t a e →
  HasTypeTelArgsQ P B Ψ Q' C1 (G Γ) Φ (Vs vs) (T t) (A a) (E e)
S02_Body : ∀ {P B Ψ Q Q' C0 C1 Γ Φ t m ts es},
  F → I → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q (C1 ++ C0) Γ Φ t m →
  TelBodyTy P B Ψ Q' C1 (G Γ) Φ (T t) (m.substTyAt c ts es)
S02_Capture : ∀ {P B Ψ R Γ Φ cap},
  CaptureOk P B Ψ R Γ Φ cap → CaptureOk P B Ψ R Γ Φ cap
S02_Closure : ∀ {P B Ψ q t},
  DependentClosureTy P B Ψ q t → DependentClosureTy P B Ψ q t
S02_Witness : ∀ {P B Ψ o k r snapshot target req},
  CheckedWitness P B Ψ o k r snapshot target req →
  CheckedWitness P B Ψ o k r snapshot target req
S02_At : ∀ {P B Ψ Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es},
  F → I → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix →
  AtCallAdmissible P B Ψ Q' C1 (G Γ) Φ k o shape (bases.map V) (V pattern) (V input) ix
S02_Arms : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R obs arms a b e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L →
  HasTypeArmsQ P B Ψ Q' C1 (G Γ) Φ (RR R) obs (AR arms) (A a) (A b) (E e) (Lθ L)
S02_Clauses : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R eb clauses t e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L →
  HasTypeClausesQ P B Ψ Q' C1 (G Γ) Φ (RR R) (E eb) (CL clauses) (A t) (E e) (Lθ L)
S02_Failure : ∀ {P B Ψ Q Q' C0 C1 Γ Φ err R clauses t e L ts es},
  F → I → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L →
  HasFailureClause P B Ψ Q' C1 (G Γ) Φ (A err) (RR R) (CL clauses) (A t) (E e) (Lθ L)
S02_Image : ∀ {P B Ψ Q C Γ Φ R ν i a},
  ImageOk P B Ψ Q C Γ Φ R ν i a → True
```

Qを移す成分はV/Vs/Each/CQ/TelArgs/TelBody/At/Arms/Clauses/Failureの**10件**である。CaptureOk/DependentClosureTy/CheckedWitnessは恒等の**3件**、ImageOkはTrueの**1件**で、恒等又はTrueは計4件である。恒等の三署名から使わないQ/Q'/RowTransportを除いた。ImageOk.contLocのR0は格納した非正規形のままなので、RR Rへの型置換を主張しない。CaptureOkの恒等は元の証拠をそのまま返し、ImageのIHを使わない。q_monoは別の族であり、ImageOkを含む11成分を移せる。

**固定した入力と未確認の成立**: S12.7の入力の全欄、S12.9の三caseの完全署名を固定した。新定義の断片でkindの反例を除けることは確認したが、全既存読者の移行と全caseの本体は未実装である。案4の波及の見込みが外れた場合の案1への切替条件はS12.6へ置く。入力の欄を供給するだけで関門(b)の通過としない。

**E_OpFail**: r1のFail用別入口を撤回する。V_RaiseにTのvalue kindを保持し、失敗節のfresh TはTypeCtx.valueParamにする。Annotation/Ordinaryからkindを推定せず、V_Raiseの新しい前提から型像[T]のkindを得て、E_Fun/Meth/Opと同じS02を使う。エラー型Eに新しいkind前提は追加しない。この規則の前提の中身の変更もS12としてレビューする。

E_Fun は元 `Def.WellTyped` の QTel と Admissible.noFailRows を `Def.QTel_eq_Qsig` で合わせて Q'=Qempty とする。E_Meth は `method_body` と MethodRowsAdmissible の代入前 Qsig、E_Op は節の Q と `sg.WF` の行境界、E_OpFail は型像[T]・行像[]を使う。4例とも元 cap で像を閉じた形と C1 の型束縛下の形を単位 .08〜.22/.37 の完了条件にする。q_mono で QTel を Qempty へ落とす経路は使わない。ここで「閉じた」は型・値・範囲の自由変数がない WF000 を意味し、行変数の支持を無条件に空へ制限する意味ではない。行支持は元宣言の sourceRows と Q/Q' の RowTransport をそのまま使う。型像と行像が WF000 なので `typeEnvAt` の `shiftRowsTypes c 0` は残す C1 の深さ c へ一度だけ移す。

開いた値依存像については、`ts.map cap.closeTy`・`es.map cap.closeEff` を用いた S02 と、`closeVal/closeTel/closeR` と `substTyAt` の交換を別の族として証明する。値束縛 n の下では `ts.map (Ty.shiftV n 0)` と `es.map (Eff.shiftV n 0)`、通常節ではさらに cutoff+k、Fail では cutoff+1 を使う。捕捉済みのコード・型注釈・R・局所 kind の交換を結論し、閉包の環境を捨てた `instantiate` との等号へ替えない。O006 の既存の開いた LeQ/Covers の入口は維持する。



## A3b で加える補助の完全署名

```lean
TyCon.dataArity_of_arity : ∀ {P : Program} {d : DataName} {n : Nat},
  TyCon.arity P (.data d) = some n → P.DataArity d n
```

`SignatureInstance` と `SignatureInstanceAt` に置く `rowKinds` は S12.8 と同じである。他の五欄、公開の九構成の前提・結論の字面を維持する。

S02 の十四署名は下記の contracts.lean で略記なしに印字する。本群では型付けの全十四成分を証明済みとは扱わず、L20.20 以降の接続へ渡す。

## 形成の公開補助（実装前の追加）

kind の対応だけを取り出す補助と、Tel の束縛下の同じ入力を明示する補助を置く。S02 の入力欄と十言明は変えない。

```lean
TypeArgsKinded.typeEnvAt : ∀ {P : Program} {C0 C1 : TypeCtx} {ts : List Ty} {es : List Eff},
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  TypeImagesKinded P (TypeCtx.kinds (C1 ++ C0)) (TypeCtx.kinds C1)
    (typeEnvAt C1.length ts es).types
ClosedTypeSubstInput.extend : ∀ {P B C0 C1 Γ ts es a},
  ClosedTypeSubstInput P B C0 C1 Γ ts es →
  Ty.Annotation P (C1 ++ C0) Γ a →
  ClosedTypeSubstInput P B C0 C1 (Γ.extend a) ts es
```

## Annotation の合成入口

```lean
Ty.Annotation.substAt : ∀ {P B Ψ C0 C1 Γ a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
  ClosedTypeSubstInput P B C0 C1 Γ ts es →
  Ty.Annotation P (C1 ++ C0) Γ a →
  Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es)
TypeAnnotations.substAt : ∀ {P B Ψ C0 C1 Γ as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
  ClosedTypeSubstInput P B C0 C1 Γ ts es → TypeAnnotations P (C1 ++ C0) Γ as →
  TypeAnnotations P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es))
RowAnnotations.substAt : ∀ {P B Ψ C0 C1 Γ fs ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
  ClosedTypeSubstInput P B C0 C1 Γ ts es → RowAnnotations P (C1 ++ C0) Γ fs →
  RowAnnotations P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es))
```

## rowKinds の構成で必要な kind 対応の追加

旧署名の三包装は行の Annotation だけを受けていた。S12.8 の kind を渡すため、同じ呼出し元 κ における行の kind を受ける引数を一つ足す。新しい信頼条件ではなく、既存の LegacyRowsInput の HasKind.value から得る。これは起動依頼で許可された kind の対応だけの公開署名の変更である。

```lean
theorem legacy_signatureInstance {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {κ : KindCtx} {C : List Benitoite.Release.TParam} {Γ : Ctx} {t : Tel}
    {ts : List Benitoite.Release.Ty} {es : List Benitoite.Release.Eff} {ks : List TyKind}
    (hc : κ.length = C.length)
    (source : (Ty.dependentFn t).WF 0 ks.length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts ks)
    (rows : RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (es.map embedEff))
    (rowKinds : ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) κ (embedEff e))
    (result : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (.dependentFn (instantiatedTel t (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ t ks (embedTys ts) (es.map embedEff)

theorem embedDefWithKinds_signatureInstance {K P0 κ C Γ f d ts}
    {es : List Benitoite.Release.Eff}
    (wf : K.WF P0) (hd : P0.defs f = some d) (hc : κ.length = C.length)
    (source : (Ty.dependentFn (embedDefWithKinds (K.functionParams f) d).tel).WF 0 (K.functionParams f).length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts (K.functionParams f))
    (rows : RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (es.map embedEff))
    (rowKinds : ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) κ (embedEff e))
    (result : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (.dependentFn (instantiatedTel (embedDefWithKinds (K.functionParams f) d).tel (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedDefWithKinds (K.functionParams f) d).tel
      ((embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.kind) (embedTys ts) (es.map embedEff)

theorem embedMethSigWithKinds_signatureInstance {K P0 κ C Γ cl cd m ms ts}
    {es : List Benitoite.Release.Eff}
    (wf : K.WF P0) (hcl : P0.classes cl = some cd) (hm : cd.methods m = some ms)
    (hc : κ.length = C.length)
    (source : (Ty.dependentFn (embedMethSigWithKinds (K.methodParams cl m) ms).tel).WF 0
      (K.methodParams cl m ++ [K.classArgument cl]).length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts (K.methodParams cl m ++ [K.classArgument cl]))
    (rows : RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (es.map embedEff))
    (rowKinds : ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) κ (embedEff e))
    (result : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (.dependentFn (instantiatedTel (embedMethSigWithKinds (K.methodParams cl m) ms).tel (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedMethSigWithKinds (K.methodParams cl m) ms).tel
      ((embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.kind ++
        [(embedClassDeclWithKinds K cl cd).argumentKind]) (embedTys ts) (es.map embedEff)

LegacyRowsInput.rowKinds : ∀ {K P0 Δ es}, LegacyRowsInput K P0 Δ es →
  ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) Δ.kinds (embedEff e)
```

## r1: S02 の源コードの条件と既定ビルド内の契約

レビュー重1への取りまとめの判断に従う。十の移送へ共通の TypeSubstCode を渡し、三つの恒等と一つの True の成分はそのままとする。SourceScoped の深さは存在量化する。この条件の役割は実行時専用構文を除くことであり、型・行像の形成は従来の九欄と RowTransport が受け持つ。ClosedTypeSubstInput の欄は増やさない。主な十言明と型付けの規則は変えない。以下を本体の証明より先に TypeSubstContracts へ Prop の定義として置く。

```lean
/-- 行像が空か、コードが実行時専用の構文を含まないソースである。 -/
def TypeSubstCode (es : List Eff) (source : Nat → Nat → Nat → Nat → Prop) : Prop :=
  es = [] ∨ ∃ nr nt ne nv, source nr nt ne nv

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_V : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ v a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => v.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
  HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Vs : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ vs as →
  HasTypeVsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) (as.map (Ty.substAt C1.length ts es))

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Each : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ Φ vs a →
  HasTypeEachQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Ty.substAt C1.length ts es) a)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_C : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R m a e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) (m.substTyAt C1.length ts es) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Args : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs t a e ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q (C1 ++ C0) Γ Φ vs t a e →
  HasTypeTelArgsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Tel.substAt C1.length ts es) t) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Body : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ t m ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q (C1 ++ C0) Γ Φ t m →
  TelBodyTy P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Tel.substAt C1.length ts es) t) (m.substTyAt C1.length ts es)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Capture : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {R Γ Φ cap},
  CaptureOk P B Ψ R Γ Φ cap → CaptureOk P B Ψ R Γ Φ cap

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Closure : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {q t},
  DependentClosureTy P B Ψ q t → DependentClosureTy P B Ψ q t

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Witness : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {o k r snapshot target req},
  CheckedWitness P B Ψ o k r snapshot target req →
  CheckedWitness P B Ψ o k r snapshot target req

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_At : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => (match bases with | none => True | some b => b.SourceScoped nr nt ne nv) ∧ pattern.SourceScoped nr nt ne nv ∧ input.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix →
  AtCallAdmissible P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ k o shape (bases.map (Val.substTyAt C1.length ts es)) ((Val.substTyAt C1.length ts es) pattern) ((Val.substTyAt C1.length ts es) input) ix

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Arms : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R obs arms a b e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedArms nr nt ne nv arms) → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L →
  HasTypeArmsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) obs ((Arm.substTyAtList C1.length ts es) arms) ((Ty.substAt C1.length ts es) a) ((Ty.substAt C1.length ts es) b) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Clauses : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R eb clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L →
  HasTypeClausesQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) ((Eff.substAt C1.length ts es) eb) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Failure : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ err R clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L →
  HasFailureClause P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Ty.substAt C1.length ts es) err) ((Option.map (Ty.substAt C1.length ts es)) R) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Image : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q C Γ Φ R ν i a},
  ImageOk P B Ψ Q C Γ Φ R ν i a → True

```

### r1 の四つの構成子の case 補題

値の子の帰納仮定を受ける ResumeL を除き、元の実構成子の前提を直接受ける。

```lean
theorem HasTypeVQ.type_subst_locRef {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ l a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.loc l).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.ref a)) (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.loc l)
      ((Ty.reference a).substAt C1.length ts es)

theorem HasTypeVQ.type_subst_locLazy {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ l a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.loc l).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.lazy a)) (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.loc l)
      ((Ty.lazy a).substAt C1.length ts es)

theorem HasTypeCQ.type_subst_resumeL {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ R L l v b t e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Comp.resume (.loc l) v).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.cont b t e R)) (hd : Ty.Declared P (C1 ++ C0) Γ t)
    (hv : HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (b.substAt C1.length ts es)) :
    HasTypeCQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es)) (.resume (.loc l) (v.substTyAt C1.length ts es))
      (t.substAt C1.length ts es) (Eff.substAt C1.length ts es e) L

theorem HasTypeVQ.type_subst_closure {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ runtime body t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.closure runtime body).SourceScoped nr nt ne nv))
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t))
    (hr : Tel.RuntimeShape runtime t) (hb : DependentClosureTy P B Ψ body t) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.closure runtime body)
      ((Ty.dependentFn t).substAt C1.length ts es)
```

### 中1について取りまとめへ返す欄の候補（未採用・未実装）

```lean
-- 既存の八欄を保ち、次の構造条件を PrimitiveAdmissible の欄に加える案。
sourceTelRows : s.tel.RowsIn (· < es.length)
-- その場合の射影の完全な型。現在この定理又は欄があることを意味しない。
PrimitiveAdmissible.sourceTelRows :
  ∀ {C : TypeCtx} {nv : Nat} {s : PrimSig} {Q : NoFailCtx}
    {ts : List Ty} {es : List Eff},
    PrimitiveAdmissible C nv s Q ts es → s.tel.RowsIn (· < es.length)
```

この候補は kind の対応だけの変更ではない。V_Prim と BuiltinArgs が読む入力の中身を強めるため、担当は本番へ追加していない。CoreAssumptions の新しい欄、ShapeOk/StoreShape の強化、独立した信頼条件も追加していない。供給元と波及は r1-detail-handoff.md に記した。

## r2: sourceTelRows の採用（実装前の完全署名）

r1 の未採用候補は r2 の指定で採用する。既存の署名は保ち、次の二欄を末尾に加える。

```lean
PrimitiveAdmissible.sourceTelRows :
  ∀ {C : TypeCtx} {nv : Nat} {s : PrimSig} {Q : NoFailCtx}
    {ts : List Ty} {es : List Eff},
    PrimitiveAdmissible C nv s Q ts es → s.tel.RowsIn (· < es.length)
LegacyPrimSignature.sourceTelRows :
  ∀ {s0 : Benitoite.Release.PrimSig} {s : PrimSig},
    LegacyPrimSignature s0 s → s.tel.RowsIn (· < s.neffs)
```

norm/map、型 shift、参照の具体化がこの欄を構成する。値 shift・値置換・文脈変更は既存の map 又は構造の保持で追随する。V_Prim と BuiltinArgs は同じ PrimitiveAdmissible を読む。旧導出の表の入力は LegacyPrimSignature の欄で受け、実表の全件照合は L60 に申し送る。CoreAssumptions と旧 Release は変えない。

### r2: Tel の交換と行の範囲具体化（実装前）

```lean
theorem instantiatedTel_substAt {nt : Nat} {t : Tel}
    (hw : (Ty.dependentFn t).WF 0 nt 0)
    (ts : List Ty) (es : List Eff) (hn : nt ≤ ts.length)
    (hr : t.RowsIn (· < es.length)) (c : Nat) (us : List Ty) (fs : List Eff) :
    Tel.substAt c us fs (instantiatedTel t ts es) =
      instantiatedTel t (ts.map (Ty.substAt c us fs)) (es.map (Eff.substAt c us fs))

theorem Tel.rowsIn_instR {pe : Nat → Prop} {t : Tel}
    (h : t.RowsIn pe) (rs : List RangeExpr) :
    (Tel.instR rs t).RowsIn pe
```

前者は V_Prim が持つ SignatureInstance.source と typeCount・sourceTelRows を使う。範囲具体化後の RowsIn は後者で得る。交換補題は kind の制限や NoTapp を要求しない。

```lean
theorem LegacyPrimSignature.sourceTelRowsAt
    {s0 : Benitoite.Release.PrimSig} {s : PrimSig}
    {C : List Benitoite.Release.TParam} {Q : Benitoite.Release.NoFailCtx}
    {ts : List Benitoite.Release.Ty} {es : List Benitoite.Release.Eff}
    {rs : List Scope.Domain.Range}
    (h : LegacyPrimSignature s0 s)
    (ha : Benitoite.Release.PrimitiveAdmissible C (s0.inst rs) Q ts es)
    (ranges : List RangeExpr) :
    (Tel.instR ranges s.tel).RowsIn (· < (es.map embedEff).length)
```

旧の呼び出しの rowCount と表の neffs の対応から、実際の行引数列の長さに対する欄を返す。

```lean
theorem PrimSig.StoreShape.sourceTelRows {s : PrimSig}
    (h : s.StoreShape)
    (hk : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨
      s.kind = .refUpdate ∨ s.kind = .force) :
    s.tel.RowsIn (· < s.neffs)
```

現行の参照四形と force の実際の StoreShape から署名全体の行の上限を返す。pure/io/exit の StoreShape はこの条件を含まないので、これらに対する一般化はしない。
