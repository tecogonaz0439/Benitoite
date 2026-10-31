import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.Le
import Benitoite.Release.Refinement.StoreTransport
import Benitoite.Release.Refinement.TelArguments
import Benitoite.Release.Refinement.External
import Benitoite.Release.Refinement.AtContracts
import Benitoite.Release.Refinement.AtInput
import Benitoite.Release.Refinement.HandlerContracts

/-!
# 有限の文脈と経路条件を持つ値・計算の型付け

捕捉時の文脈とパラメータの束縛は、置換の補題と同じ操作で構成する。
-/

namespace Benitoite.Release.Refinement

def hideConts (Γ : Ctx) : Ctx := Γ.map fun a => match a with
  | some (.cont _ _ _) => none
  | a => a

def hideBuilders (Ψ : StoreTy) : StoreTy := fun l => match Ψ l with
  | some (.builder _) => none
  | a => a

theorem StoreTy.WF.hide {Ψ : StoreTy} (h : Ψ.WF) : (hideBuilders Ψ).WF := by
  intro l t ht
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> try cases ht
              all_goals exact h _ _ hl

theorem StoreTy.PreservesNormals.hide {Ψ Ψ' : StoreTy} (h : Ψ.PreservesNormals Ψ') :
    (hideBuilders Ψ).Extends (hideBuilders Ψ') := by
  intro l t ht
  unfold hideBuilders at ht ⊢
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> try cases ht
              all_goals rw [h _ _ hl trivial]

theorem StoreTy.preserves_hide (Ψ : StoreTy) : Ψ.PreservesNormals (hideBuilders Ψ) := by
  intro l t ht hn
  cases t <;> try cases hn
  all_goals simp [hideBuilders, ht]

def bindParams (Γ : Ctx) (ps : List Ty) : Ctx :=
  (ps.reverse.map (fun a => some (a.shiftV ps.length 0))) ++
    Γ.map (Option.map (Ty.shiftV ps.length 0))

def liftMany (n : Nat) (Φ : List Pred) : List Pred :=
  Nat.rec Φ (fun _ Ξ => Ξ.map Pred.lift) n

def BuilderKind.contents : BuilderKind → Ty
  | .string => .base .string
  | .list a => .list a
  | .bytes => .bytes

def BuilderKind.item : BuilderKind → Ty
  | .string => .base .string
  | .list a => a
  | .bytes => .base .byte

def BuilderOp.parameters (op : BuilderOp) (kind : BuilderKind) : List Ty := match op with
  | .append => [kind.item]
  | .appendAll => [match kind with | .string => .list (.base .string) | _ => kind.contents]
  | .copy | .length => []

def BuilderOp.resultType (op : BuilderOp) (kind : BuilderKind) : Ty := match op with
  | .copy => kind.contents
  | .length => .base .integer
  | .append | .appendAll => .base .unit

def LocalCtx.extend (x : Option BuilderKind) (L : LocalCtx) : LocalCtx :=
  x :: L.map (Option.map (renameKind (shiftIndex 1 0)))

def localExtend : Nat → LocalCtx → LocalCtx
  | 0, L => L
  | n+1, L => LocalCtx.extend none (localExtend n L)

inductive LocalRef.HasKind (Ψ : StoreTy) (L : LocalCtx) : LocalRef → BuilderKind → Prop where
  | bound {i b} : L[i]? = some (some b) → LocalRef.HasKind Ψ L (.bound i) b
  | loc {l b} : Ψ l = some (.builder b) → LocalRef.HasKind Ψ L (.loc l) b

def LocalCtx.Shift (k c : Nat) (L L' : LocalCtx) : Prop :=
  ∀ i b, L[i]? = some (some b) →
    L'[shiftIndex k c i]? = some (some (renameKind (shiftIndex k c) b))

noncomputable def LocalSubstOk (Ψ : StoreTy) (L : LocalCtx) (ν : Nat → Val)
    (ρ : Nat → LocalRef) (L' : LocalCtx) : Prop :=
  ∀ i b, L[i]? = some (some b) → LocalRef.HasKind Ψ L' (ρ i) (substKind ν b)

mutual
  /-- 値の型付け。経路条件は通常の文脈の番号で読む。 -/
  inductive HasTypeVQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Val → Ty → Prop where
    | V_Var {Ψ Q C Γ Φ i a} : Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
        HasTypeVQ P B Ψ Q C Γ Φ (.var i) a
    | V_Const {Ψ Q C Γ Φ c} : ConstOK B c →
        HasTypeVQ P B Ψ Q C Γ Φ (.const c) (Const.type c)
    | V_Lam {Ψ Q C Γ Φ ns ps body r ε} : NamesWF ns ps →
        Ty.WF 0 C.length Γ.length (.fn ns ps r ε) → Ty.Sorted Γ (.fn ns ps r ε) →
        HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) [] →
        Ty.Declared P C Γ (.fn ns ps r ε) →
        HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) (.fn ns ps r ε)
    | V_Fun {Ψ Q C Γ Φ f d ts es} : P.defs f = some d → NamesWF d.names d.params →
        Admissible B C Γ.length (d.tparams.map TParamDecl.constraints) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff →
        SignatureInstance P C Γ d.tel (d.tparams.map TParamDecl.kind) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es) (.dependentFn (instantiatedTel d.tel ts es))
    | V_Prim {Ψ Q C Γ Φ b s ts es rs} : B.sig b = some s → B.RangeAdmissible b s rs →
        NamesWF s.names s.params → PrimitiveAdmissible C Γ.length s Q ts es →
        SignatureInstance P C Γ (Tel.instR rs s.tel) (s.tparams.map TParamDecl.kind) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es rs)
          (.dependentFn (instantiatedTel (Tel.instR rs s.tel) ts es))
    | V_Op {Ψ Q C Γ Φ o od ts} : P.ops o = some od → NamesWF od.names od.params →
        SatAll B C ts od.tparams →
        SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts [] →
        HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) (.dependentFn (instantiatedTel od.tel ts []))
    | V_ExternalRef {Ψ Q C Γ Φ f d ts} : P.externalFunction f = some d → d.WF P →
        ExternalCallAdmissible P B C d ts →
        SignatureInstance P C Γ d.parameters d.kinds ts [] →
        HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) (.dependentFn (instantiatedTel d.parameters ts []))
    | V_ExternalHandle {Ψ Q C Γ Φ ts} (h : ExternalHandle) (td : ExternalTypeDecl) :
        P.externalType h.typeId = some td → td.component = h.component → td.resource = h.resource →
        ts.length = td.arity → Ty.Annotation P C Γ (.external h.typeId ts) →
        HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) (.external h.typeId ts)
    | V_PathBases {Ψ Q C Γ Φ snapshot} : snapshot.Valid →
        HasTypeVQ P B Ψ Q C Γ Φ (.pathBases snapshot) .pathBases
    | V_ScopePattern {Ψ Q C Γ Φ range kind} : range.WF → range.Canonical → range.FitsKind kind →
        HasTypeVQ P B Ψ Q C Γ Φ (.scopePattern range) (.scopePattern kind)
    | V_Checked {Ψ Q C Γ Φ o k range target} : B.valKind o = some k → B.valContent o = none →
        Scope.Domain.Range.MemK k range target →
        HasTypeVQ P B Ψ Q C Γ Φ (.checked target) (.scoped o k (.fixed (.absolute range)))
    | V_CheckedRequest {Ψ Q C Γ Φ o range target req T} : B.valKind o = some .endpoint →
        B.valContent o = some T → HasTypeVQ P B Ψ Qempty [] [] [] req T →
        req.Ground → req.reqTarget = some target →
        Scope.Domain.Range.MemK .endpoint range target →
        HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req)
          (.scoped o .endpoint (.fixed (.absolute range)))
    | V_CheckedAt {Ψ Q C Γ Φ o k range snapshot target request} :
        CheckedWitness P B Ψ o k range snapshot target request →
        HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt range snapshot target request) (.scoped o k (.fixed range))
    | V_AtError {Ψ Q C Γ Φ} {shape : ResultShape} {detail : AtError} : shape.Declared P →
        HasTypeVQ P B Ψ Q C Γ Φ (.atError detail) shape.errorType
    | V_Map {Ψ Q C Γ Φ ks vs a b} :
        HasTypeEachQ P B Ψ Q C Γ Φ ks a → HasTypeEachQ P B Ψ Q C Γ Φ vs b →
        ks.length = vs.length → B.sat C a TParam.keyC →
        Ty.Annotation P C Γ a → Ty.Annotation P C Γ b →
        HasTypeVQ P B Ψ Q C Γ Φ (.mapV ks vs) (.map a b)
    | V_Set {Ψ Q C Γ Φ vs a} : HasTypeEachQ P B Ψ Q C Γ Φ vs a →
        B.sat C a TParam.keyC → Ty.Annotation P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.setV vs) (.set a)
    | V_Dict {Ψ Q C Γ Φ i id ts vs} : P.impls i = some id → SatAll B C ts id.tparams →
        TypeAnnotations P C Γ ts → TypeArgsKinded P C ts (List.replicate id.tparams.length .value) →
        (∀ a ∈ id.dictTys, a.WF 0 id.tparams.length 0) → id.target.WF 0 id.tparams.length 0 →
        HasTypeVsQ P B Ψ Q C Γ Φ vs (id.dictTys.map (Ty.subst ts [])) →
        Ty.Annotation P C Γ (.dict id.cls (id.target.subst ts [])) →
        HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))
    | V_Raise {Ψ Q C Γ Φ t e} :
        Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) →
        HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) (.fn ["error"] [e] t (Eff.singleFail e))
    | V_LocRef {Ψ Q C Γ Φ l a} : Ψ l = some (.ref a) → Ty.Declared P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.loc l) (.reference a)
    | V_LocLazy {Ψ Q C Γ Φ l a} : Ψ l = some (.lazy a) → Ty.Declared P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.loc l) (.lazy a)
    | V_Bytes {Ψ Q C Γ Φ bs} : (∀ b ∈ bs, b ≤ 255) →
        HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) .bytes
    | V_Con {Ψ Q C Γ Φ c cd ts vs} : P.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded P C ts (List.replicate cd.ntys .value) →
        (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) →
        Ty.Annotation P C Γ (.data cd.data ts) →
        HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) (.data cd.data ts)
    | V_Super {Ψ Q C Γ Φ v cl a cd super} :
        HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl a) → P.classes cl = some cd → super ∈ cd.supers →
        Ty.Declared P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.super v super) (.dict super a)
    | V_List {Ψ Q C Γ Φ vs a} : HasTypeEachQ P B Ψ Q C Γ Φ vs a →
        Ty.WF 0 C.length Γ.length a → Ty.Sorted Γ a → Ty.Declared P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.list vs) (.list a)
    | V_Sub {Ψ Q C Γ Φ v a b} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        Ty.LeQ Γ Φ a b → Ty.WF 0 C.length Γ.length b → Ty.Sorted Γ b → Ty.Declared P C Γ b →
        HasTypeVQ P B Ψ Q C Γ Φ v b
    | V_Refine {Ψ Q C Γ Φ v a t p sort} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        Ty.HasSort a sort → v.toTerm? = some t → Pred.Sorted Γ (some a) p →
        Pred.WF (Γ.length+1) p → Entails (Γ.facts ++ Φ) (p.open t) →
        Ty.Declared P C Γ a → Pred.Declared P C Γ (some a) p →
        HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p)

  inductive HasTypeVsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → List Val → List Ty → Prop where
    | nil {Ψ Q C Γ Φ} : HasTypeVsQ P B Ψ Q C Γ Φ [] []
    | cons {Ψ Q C Γ Φ v vs a as} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeVsQ P B Ψ Q C Γ Φ vs as → HasTypeVsQ P B Ψ Q C Γ Φ (v::vs) (a::as)

  inductive HasTypeEachQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → List Val → Ty → Prop where
    | nil {Ψ Q C Γ Φ a} : HasTypeEachQ P B Ψ Q C Γ Φ [] a
    | cons {Ψ Q C Γ Φ v vs a} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeEachQ P B Ψ Q C Γ Φ vs a → HasTypeEachQ P B Ψ Q C Γ Φ (v::vs) a

  inductive HasTypeCQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
      Comp → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | C_BuilderLet {Ψ Q C Γ Φ Δ R kind body a ε} :
        Ty.Annotation P C Γ kind.contents → TypeArgsKinded P C [kind.contents] [.value] →
        HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          body (a.shiftV 1 0) (ε.shiftV 1 0)
          (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ) →
        Ty.Declared P C Γ a →
        HasTypeCQ P B Ψ Q C Γ Φ R (.builderLet kind body) a ε Δ
    | C_BuilderOp {Ψ Q C Γ Φ Δ R kind op ref args} :
        Ty.Annotation P C Γ kind.contents → TypeArgsKinded P C [kind.contents] [.value] →
        LocalRef.HasKind Ψ Δ ref kind → HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind) →
        HasTypeCQ P B Ψ Q C Γ Φ R (.builderOp kind op ref args) (op.resultType kind) Eff.empty Δ
    | C_Return {Ψ Q C Γ Φ Δ R v a} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeCQ P B Ψ Q C Γ Φ R (.ret v) a Eff.empty Δ
    | C_Let {Ψ Q C Γ Φ Δ R m n a b ε} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 Δ) →
        Ty.Declared P C Γ b →
        HasTypeCQ P B Ψ Q C Γ Φ R (.letIn m n) b ε Δ
    | C_App {Ψ Q C Γ Φ Δ R f args ns as b ε} :
        HasTypeVQ P B Ψ Q C Γ Φ f (.fn ns as b ε) → HasTypeVsQ P B Ψ Q C Γ Φ args as →
        HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) b ε Δ
    | C_If {Ψ Q C Γ Φ Δ R v m n a ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean) →
        HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ → HasTypeCQ P B Ψ Q C Γ Φ R n a ε Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.ite v m n) a ε Δ
    | C_Match {Ψ Q C Γ Φ Δ R v arms a b ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b ε Δ →
        Exhaustive P a (unguardedPats arms) →
        HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b ε Δ
    | C_Lazy {Ψ Q C Γ Φ Δ R m a} :
        HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty [] →
        Ty.Annotation P C Γ a →
        HasTypeCQ P B Ψ Q C Γ Φ R (.lazyC m) (.lazy a) Eff.empty Δ
    | C_Escape {Ψ Q C Γ Φ Δ r v a ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v r → Ty.Annotation P C Γ a →
        HasTypeCQ P B Ψ Q C Γ Φ (some r) (.escape v) a ε Δ
    | C_Use {Ψ Q C Γ Φ Δ R v o m a ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top)) → B.isResource o = true →
        HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ → ε.test (.name stateEff (.fixed .top)) = true →
        HasTypeCQ P B Ψ Q C Γ Φ R (.use v m) a ε Δ
    | C_Handle {Ψ Q C Γ Φ Δ R m h t εm ε} : HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ →
        Eff.Covers Γ Φ (Eff.union ε (handled P B h)) εm →
        HasTypeClausesQ P B Ψ Q C Γ Φ R εm h t ε Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) t ε Δ
    | C_Handle_Fail {Ψ Q C Γ Φ Δ R m h t E eb rest ec} : HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ →
        Eff.Covers Γ Φ (Eff.union (Eff.singleFail E) rest) eb → NoFail Q rest →
        HasFailureClause P B Ψ Q C Γ Φ E R h t ec Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) t (Eff.union rest ec) Δ
    | C_Resume {Ψ Q C Γ Φ Δ R i v b t ε} :
        Γ[i]? = some (some (.cont b t ε)) → HasTypeVQ P B Ψ Q C Γ Φ v b →
        Ty.Declared P C Γ t →
        HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) t ε Δ
    | C_ResumeL {Ψ Q C Γ Φ Δ R l v b t ε} :
        Ψ l = some (.cont b t ε R) → HasTypeVQ P B Ψ Q C Γ Φ v b →
        Ty.Declared P C Γ t →
        HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) t ε Δ
    | C_Meth {Ψ Q C Γ Φ Δ R v cl τ cd m ms ss es ws as a ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl τ) → P.classes cl = some cd → cd.methods m = some ms →
        NamesWF ms.names ms.params → SatAll B C ss (ms.tparams.map TParamDecl.constraints) →
        SignatureInstance P C Γ ms.tel (ms.tparams.map TParamDecl.kind ++ [cd.argumentKind]) (ss ++ [τ]) es →
        MethodRowsAdmissible C Γ.length Q ms es →
        Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) es) ws = some (as, a, ε) →
        HasTypeVsQ P B Ψ Q C Γ Φ ws as → Ty.Annotation P C Γ a →
        HasTypeCQ P B Ψ Q C Γ Φ R (.meth v m ss es ws) a ε Δ
    | C_External {Ψ Q C Γ Φ Δ R f d ts vs a e} :
        P.externalFunction f = some d → d.WF P → ExternalCallAdmissible P B C d ts →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e →
        HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts vs) a e Δ
    | C_IssuePathBases {Ψ Q C Γ Φ Δ R} (b : PrimName) (sg : PrimSig) :
        B.sig b = some sg → sg.kind = .pathBases → sg.opEff = some processEnvironmentEff →
        sg.params = [] → sg.ret = .pathBases → sg.eff = Eff.single processEnvironmentEff →
        HasTypeCQ P B Ψ Q C Γ Φ R (.issuePathBases b) .pathBases (Eff.single processEnvironmentEff) Δ
    | C_CheckAt {Ψ Q C Γ Φ Δ R kind name shape bases pattern input index} :
        AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index →
        HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index)
          (.data shape.owner [.scoped name kind index, shape.errorType]) Eff.empty Δ
    | C_Sub {Ψ Q C Γ Φ Δ R m a b ε ε'} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        Ty.LeQ Γ Φ a b → Eff.Covers Γ Φ ε' ε → Ty.WF 0 C.length Γ.length b → Ty.Sorted Γ b → Ty.Declared P C Γ b →
        HasTypeCQ P B Ψ Q C Γ Φ R m b ε' Δ
    | C_Eff {Ψ Q C Γ Φ Δ R m a ε ε'} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        Eff.Covers Γ Φ ε' ε → HasTypeCQ P B Ψ Q C Γ Φ R m a ε' Δ
  /-- 実引数ごとに後続を具体化する。Rを持たず、各引数は同じΓ/Φで読む。 -/
  inductive HasTypeTelArgsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → List Val → Tel → Ty → Eff → Prop where
    | done {Ψ Q C Γ Φ a e} : Ty.Annotation P C Γ (.dependentFn (.done a e)) →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ [] (.done a e) a e
    | param {Ψ Q C Γ Φ name a rest v vs r e} : Ty.Annotation P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (Tel.argumentsEnv v) rest) r e →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ (v :: vs) (.param name a rest) r e

  inductive CheckedWitness (P : Program) (B : Builtins) :
      StoreTy → OpaqueName → Scope.Domain.Kind → RangeExpr → Option PathEnv →
        Scope.Domain.Target → Option Val → Prop where
    | plain {Ψ o k range snapshot target} : B.valKind o = some k → B.valContent o = none →
        target.kind = k → SnapshotMem snapshot k range target →
        CheckedWitness P B Ψ o k range snapshot target none
    | request {Ψ o range snapshot target req T} : B.valKind o = some .endpoint →
        B.valContent o = some T → HasTypeVQ P B Ψ Qempty [] [] [] req T →
        req.Ground → req.reqTarget = some target → SnapshotMem snapshot .endpoint range target →
        CheckedWitness P B Ψ o .endpoint range snapshot target (some req)

  inductive AtCallAdmissible (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Scope.Domain.Kind →
      OpaqueName → ResultShape → Option Val → Val → Val → RangeIx → Prop where
    | mk {Ψ Q C Γ Φ kind name shape bases pattern input index inputTy} :
        shape.Declared P → B.valKind name = some kind →
        (∀ v, bases = some v → HasTypeVQ P B Ψ Q C Γ Φ v .pathBases) →
        HasTypeVQ P B Ψ Q C Γ Φ pattern (.scopePattern kind) →
        (inputTy = .base .string ∧ B.valContent name = none ∨ B.valContent name = some inputTy ∧ inputTy.WF 0 0 0) →
        HasTypeVQ P B Ψ Q C Γ Φ input inputTy → index.WF 0 →
        (∀ r, index = .fixed r → r.WF ∧ r.Canonical ∧ r.FitsKind kind) →
        AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index

  /-- 通常値、継続の場所、継続変数の改名を分けた型付き像。 -/
  inductive HasTypeArmsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
      List Arm → Ty → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | nil {Ψ Q C Γ Φ Δ R a b ε} : Ty.Annotation P C Γ b →
        HasTypeArmsQ P B Ψ Q C Γ Φ R [] a b ε Δ
    | plain {Ψ Q C Γ Φ Δ R alts body arms a b ε δ} : AltsTy P alts a δ →
        HasTypeCQ P B Ψ Q C (bindParams Γ δ) (liftMany δ.length Φ)
          (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0)
          (localExtend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b ε Δ →
        HasTypeArmsQ P B Ψ Q C Γ Φ R (.mk alts none body :: arms) a b ε Δ
    | guarded {Ψ Q C Γ Φ Δ R alts guard body arms a b ε δ} : AltsTy P alts a δ →
        HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ)) (liftMany δ.length Φ)
          none guard (.base .boolean) Eff.empty (localExtend δ.length Δ) →
        HasTypeCQ P B Ψ Q C (bindParams Γ δ) (liftMany δ.length Φ)
          (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0)
          (localExtend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b ε Δ →
        HasTypeArmsQ P B Ψ Q C Γ Φ R (.mk alts (some guard) body :: arms) a b ε Δ

  inductive HasTypeClausesQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty → Eff →
      List Clause → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | nil {Ψ Q C Γ Φ Δ R eb t ε} : HasTypeClausesQ P B Ψ Q C Γ Φ R eb [] t ε Δ
    | cons {Ψ Q C Γ Φ Δ R eb o n k body cs t ε sg} : ClauseSig P B eb o sg →
        NamesWF sg.names sg.params → n=sg.params.length → k=sg.tparams.length → sg.WF →
        HasTypeCQ P B (hideBuilders Ψ) Q (sg.tparams++C) (sg.context Γ t ε)
          (liftMany (sg.params.length+1) Φ)
          (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0))
          body ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0)
          ((shiftRowsTypes sg.tparams.length 0 ε).shiftV (sg.params.length+1) 0) [] →
        HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ε Δ →
        HasTypeClausesQ P B Ψ Q C Γ Φ R eb (.mk o n k body::cs) t ε Δ

  inductive HasFailureClause (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Ty → Option Ty →
      List Clause → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | one {Ψ Q C Γ Φ Δ E R body t ec} : Ty.Annotation P C Γ E → Ty.Annotation P C Γ t →
        RowAnnotations P C Γ [ec] →
        HasTypeCQ P B (hideBuilders Ψ) Q (({} : TParam)::C) (failureContext Γ E) (liftMany 2 Φ)
          (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) body
          ((shiftTypes 1 0 t).shiftV 2 0) ((shiftRowsTypes 1 0 ec).shiftV 2 0) [] →
        HasFailureClause P B Ψ Q C Γ Φ E R [.fail E body] t ec Δ

  inductive ImageOk (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
      (Nat → Val) → Nat → Ty → Prop where
    | ordinary {Ψ Q C Δ Ξ R0 ν i a} : a.Ordinary →
        HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a) →
        ImageOk P B Ψ Q C Δ Ξ R0 ν i a
    | contLoc {Ψ Q C Δ Ξ R0 ν i a b t e b' t' e' l} :
        a = .cont b t e → substTyValues ν a = .cont b' t' e' →
        (substTyValues ν a).WF 0 0 0 → ν i = .loc l → Ψ l = some (.cont b' t' e' R0) →
        (∀ r, R0 = some r → r.WF 0 0 0) → ImageOk P B Ψ Q C Δ Ξ R0 ν i a
    | contVar {Ψ Q C Δ Ξ R0 ν i a b t e j} : a = .cont b t e → ν i = .var j →
        Δ[j]? = some (some (substTyValues ν a)) → ImageOk P B Ψ Q C Δ Ξ R0 ν i a

end

theorem HasTypeVQ.refine_integer {P B store Q C Γ Φ v a t p}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.IntegerCarrier) (ht : v.toTerm? = some t)
    (hda : Ty.Declared P C Γ a) (hdp : Pred.Declared P C Γ (some a) p)
    (hs : Pred.Sorted Γ (some a) p) (hw : p.WF (Γ.length+1))
    (he : Entails (Γ.facts ++ Φ) (p.open t)) : HasTypeVQ P B store Q C Γ Φ v (.refined a p) :=
  .V_Refine h hi ht hs hw he hda hdp

abbrev HasTypeTelArgs (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeTelArgsQ P B Ψ Qempty

abbrev HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVQ P B Ψ Qempty
abbrev HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVsQ P B Ψ Qempty
abbrev HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeEachQ P B Ψ Qempty
abbrev HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeCQ P B Ψ Qempty
abbrev HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeArmsQ P B Ψ Qempty
abbrev HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeClausesQ P B Ψ Qempty
abbrev HasTypeCL (P : Program) (B : Builtins) (Ψ : StoreTy) (C : List TParam)
    (Δ : LocalCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (ε : Eff) :=
  HasTypeCQ P B Ψ Qempty C Γ Φ R m a ε Δ

end Benitoite.Release.Refinement
