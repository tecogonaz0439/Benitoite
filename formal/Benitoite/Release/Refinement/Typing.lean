import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.RangeCode
import Benitoite.Release.Refinement.FieldFacts
import Benitoite.Release.Refinement.LocalResolve
import Benitoite.Release.Refinement.Le
import Benitoite.Release.Refinement.StoreTransport
import Benitoite.Release.Refinement.TelArguments
import Benitoite.Release.Refinement.External
import Benitoite.Release.Refinement.AtContracts
import Benitoite.Release.Refinement.AtInput
import Benitoite.Release.Refinement.HandlerContracts
import Benitoite.Release.Refinement.Capture
import Benitoite.Release.Refinement.Ground
import Benitoite.Release.Refinement.AtPrepare

/-!
# 有限の文脈と経路条件を持つ値・計算の型付け

捕捉時の文脈とパラメータの束縛は、置換の補題と同じ操作で構成する。
-/

namespace Benitoite.Release.Refinement

variable {P : Program}

def hideConts (Γ : Ctx) : Ctx := Γ.map fun a => match a with
  | some t => match t.core with
    | .cont _ _ _ => none
    | _ => some t
  | none => none

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
  | normal {r b} : LocalRef.HasKind Ψ L r b → LocalRef.HasKind Ψ L r b.norm

def LocalCtx.Shift (k c : Nat) (L L' : LocalCtx) : Prop :=
  ∀ i b, L[i]? = some (some b) →
    L'[shiftIndex k c i]? = some (some (renameKind (shiftIndex k c) b))

noncomputable def LocalSubstOk (Ψ : StoreTy) (L : LocalCtx) (ν : Nat → Val)
    (ρ : Nat → LocalRef) (L' : LocalCtx) : Prop :=
  ∀ i b, L[i]? = some (some b) → LocalRef.HasKind Ψ L' (ρ i) (substKind ν b)

/-- 局所の構築器の参照を、捕捉によるkindの像を持つ場所へ対応させる。 -/
def CaptureLocals (Ψ : StoreTy) (ν : Nat → Val) (L : LocalCtx) (ρ : Nat → LocalRef) : Prop :=
  ∀ i kind, L[i]? = some (some kind) →
    ∃ l, ρ i = .loc l ∧ Ψ l = some (.builder (substKind ν kind))


/-- 捕捉した継続のソースの行は読まず、入力と結果の型を検査する。 -/
def Ty.CaptureWF (nr nt nv : Nat) : Ty → Prop
  | .cont b t _ => b.WF nr nt nv ∧ t.WF nr nt nv
  | a => a.WF nr nt nv

def Ty.CaptureSorted (Γ : Ctx) : Ty → Prop
  | .cont b t _ => b.Sorted Γ ∧ t.Sorted Γ
  | a => a.Sorted Γ

def Ty.CaptureDeclared (P : Program) (C : TypeCtx) (Γ : Ctx) : Ty → Prop
  | .cont b t _ => b.Declared P C Γ ∧ t.Declared P C Γ
  | a => a.Declared P C Γ

def Ctx.CaptureWF (nr nt : Nat) (Γ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.CaptureWF nr nt Γ.length


/-- 条件値の真偽を表す、通常の文脈の述語。 -/
def boolCond (t : Term) (b : Bool) : Pred :=
  .compare .boolean .eq t (.boolean b)

/-- 既存の条件の移しを、新しい一条件の下へ延長する。 -/
theorem Entails.conditions_cons {Γ : Ctx} {Φ Ξ : List Pred} {p q : Pred}
    (hf : ∀ r ∈ Φ, Entails (Γ.facts ++ Ξ) r)
    (hq : Entails (Γ.facts ++ q :: Ξ) p) :
    ∀ r ∈ p :: Φ, Entails (Γ.facts ++ q :: Ξ) r := by
  intro r hr
  rcases List.mem_cons.mp hr with rfl | hr
  · exact hq
  · exact (hf r hr).weaken (by
      intro s hs
      rcases List.mem_append.mp hs with hs | hs
      · exact List.mem_append_left _ hs
      · exact List.mem_append_right _ (List.mem_cons_of_mem _ hs))

mutual
  /-- 値の型付け。経路条件は通常の文脈の番号で読む。 -/
  inductive HasTypeVQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Val → Ty → Prop where
    | V_Var {Ψ Q C Γ Φ i a} : Γ[i]? = some (some a) → Ordinary a →
        HasTypeVQ P B Ψ Q C Γ Φ (.var i) a
    | V_Const {Ψ Q C Γ Φ c} : ConstOK B c →
        HasTypeVQ P B Ψ Q C Γ Φ (.const c) (Const.type c)
    | V_Lam {Ψ Q C Γ Φ ns ps body r ε} : NamesWF ns ps →
        Ty.WF 0 C.length Γ.length (.fn ns ps r ε) → Ty.Sorted Γ (.fn ns ps r ε) →
        HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) [] →
        Ty.Declared P C Γ (.fn ns ps r ε) →
        HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) (.fn ns ps r ε)
    | V_DependentLam {Ψ Q C Γ Φ t body} : Ty.Annotation P C Γ (.dependentFn t) →
        TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body →
        HasTypeVQ P B Ψ Q C Γ Φ (.dependentLam t body) (.dependentFn t)
    | V_Closure {Ψ Q C Γ Φ runtime t body} : Ty.Annotation P C Γ (.dependentFn t) →
        Tel.RuntimeShape runtime t → DependentClosureTy P B Ψ body t →
        HasTypeVQ P B Ψ Q C Γ Φ (.closure runtime body) (.dependentFn t)
    | V_Fun {Ψ Q C Γ Φ f d ts es rs} : P.defs f = some d → NamesWF d.names d.params →
        Def.RangeAdmissible d rs →
        Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff →
        SignatureInstance P C Γ (d.instTel rs) (TypeCtx.kinds d.tparams) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es (rs.map RangeIx.fixed))
          (.dependentFn (instantiatedTel (d.instTel rs) ts es))
    | V_Prim {Ψ Q C Γ Φ b s ts es rs} : B.sig b = some s → B.RangeAdmissible b s rs →
        NamesWF s.names s.params → PrimitiveAdmissible C Γ.length s Q ts es →
        SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es (rs.map RangeIx.fixed))
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
    /-- 保持要求の判定成功と、固定した解析による端点一致を保持する。閉性は groundVal_ground で得る。 -/
    | V_CheckedRequest {Ψ Q C Γ Φ o range target req T} : B.valKind o = some .endpoint →
        B.valContent o = some T → HasTypeVQ P B Ψ Qempty [] [] [] req T.norm →
        groundVal req = true → req.reqTarget = some target →
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
        ks.length = vs.length → B.sat (TypeCtx.constraints C) a.norm TParam.keyC →
        Ty.Annotation P C Γ a → Ty.Annotation P C Γ b →
        HasTypeVQ P B Ψ Q C Γ Φ (.mapV ks vs) (.map a b)
    | V_Set {Ψ Q C Γ Φ vs a} : HasTypeEachQ P B Ψ Q C Γ Φ vs a →
        B.sat (TypeCtx.constraints C) a.norm TParam.keyC → Ty.Annotation P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.setV vs) (.set a)
    | V_Dict {Ψ Q C Γ Φ i id ts vs} : P.impls i = some id → SatAll B C ts id.tparams →
        TypeAnnotations P C Γ ts → TypeArgsKinded P C ts (List.replicate id.tparams.length .value) →
        (∀ a ∈ id.dictTys, a.WF 0 id.tparams.length 0) → id.target.WF 0 id.tparams.length 0 →
        HasTypeVsQ P B Ψ Q C Γ Φ vs (id.dictTys.map (Ty.subst ts [])) →
        Ty.Annotation P C Γ (.dict id.cls (id.target.subst ts [])) →
        HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))
    | V_Raise {Ψ Q C Γ Φ t e} :
        Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) →
        Ordinary t → Ordinary e → t.HasKind P (TypeCtx.kinds C) .value →
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
        Ty.LeQ P Γ Φ a b → Ty.WF 0 C.length Γ.length b → Ty.Sorted Γ b → Ty.Declared P C Γ b →
        HasTypeVQ P B Ψ Q C Γ Φ v b
    | V_Normal {Ψ Q C Γ Φ v a} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeVQ P B Ψ Q C Γ Φ v a.norm
    | V_Refine {Ψ Q C Γ Φ v a t p sort} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        Ty.HasSort a sort → v.toTerm? = some t → Pred.Sorted Γ (some a) p →
        Pred.WF (Γ.length+1) p → Entails (Γ.facts ++ Φ) (p.open t) →
        Ty.Declared P C Γ a → Pred.Declared P C Γ (some a) p →
        HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p)

  inductive HasTypeVsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → List Val → List Ty → Prop where
    | nil {Ψ Q C Γ Φ} : HasTypeVsQ P B Ψ Q C Γ Φ [] []
    | cons {Ψ Q C Γ Φ v vs a as} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeVsQ P B Ψ Q C Γ Φ vs as → HasTypeVsQ P B Ψ Q C Γ Φ (v::vs) (a::as)

  inductive HasTypeEachQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → List Val → Ty → Prop where
    | nil {Ψ Q C Γ Φ a} : HasTypeEachQ P B Ψ Q C Γ Φ [] a
    | cons {Ψ Q C Γ Φ v vs a} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeEachQ P B Ψ Q C Γ Φ vs a → HasTypeEachQ P B Ψ Q C Γ Φ (v::vs) a

  inductive HasTypeCQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Option Ty →
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
    | C_DependentApp {Ψ Q C Γ Φ Δ R f args t a e} :
        HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t) →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e →
        HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) a e Δ
    | C_If {Ψ Q C Γ Φ Δ R v t m n a ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean) →
        v.toTerm? = some t →
        HasTypeCQ P B Ψ Q C Γ (boolCond t true :: Φ) R m a ε Δ →
        HasTypeCQ P B Ψ Q C Γ (boolCond t false :: Φ) R n a ε Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.ite v m n) a ε Δ
    | C_Match {Ψ Q C Γ Φ Δ R v obs arms a b ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v a →
        (∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s) →
        HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
        Ty.Declared P C Γ a →
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
        Eff.Sub εm (Eff.union ε (handled P B h)) →
        HasTypeClausesQ P B Ψ Q C Γ Φ R εm h t ε Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) t ε Δ
    | C_Handle_Fail {Ψ Q C Γ Φ Δ R m h t E eb rest ec} : HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ →
        Eff.Sub eb (Eff.union (Eff.singleFail E) rest) → NoFail Q rest →
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
    | C_ResumeNorm {Ψ Q C Γ Φ Δ R i v b t ε} :
        Γ[i]? = some (some (.cont b t ε)) → HasTypeVQ P B Ψ Q C Γ Φ v b.norm →
        Ty.Declared P C Γ t.norm →
        HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) t.norm (Eff.norm ε) Δ
    | C_ResumeLNorm {Ψ Q C Γ Φ Δ R R' l v b t ε} :
        Ψ l = some (.cont b t ε R') → R'.map Ty.norm = R.map Ty.norm →
        HasTypeVQ P B Ψ Q C Γ Φ v b.norm → Ty.Declared P C Γ t.norm →
        HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) t.norm (Eff.norm ε) Δ
    | C_Normal {Ψ Q C Γ Φ Δ R m a ε} :
        HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R m a.norm ε Δ
    | C_Meth {Ψ Q C Γ Φ Δ R v cl τ cd m ms ss es ws as a ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl τ) → P.classes cl = some cd → cd.methods m = some ms →
        NamesWF ms.names ms.params → SatAll B C ss (TypeCtx.constraints ms.tparams) →
        SignatureInstance P C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es →
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
        Ty.LeQ P Γ Φ a b → Eff.Covers Γ Φ ε' ε → Ty.WF 0 C.length Γ.length b → Ty.Sorted Γ b → Ty.Declared P C Γ b →
        HasTypeCQ P B Ψ Q C Γ Φ R m b ε' Δ
    | C_Eff {Ψ Q C Γ Φ Δ R m a ε ε'} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        Eff.Covers Γ Φ ε' ε → HasTypeCQ P B Ψ Q C Γ Φ R m a ε' Δ
  /-- 実引数ごとに後続を具体化する。Rを持たず、各引数は同じΓ/Φで読む。 -/
  inductive HasTypeTelArgsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → List Val → Tel → Ty → Eff → Prop where
    | done {Ψ Q C Γ Φ a e} : Ty.Annotation P C Γ (.dependentFn (.done a e)) →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ [] (.done a e) a e
    | param {Ψ Q C Γ Φ name a rest v vs r e} : Ty.Annotation P C Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (Tel.argumentsEnv v) rest) r e →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ (v :: vs) (.param name a rest) r e

  /-- 本体は全引数を束縛した位置で検査し、doneの結果を自分のreturn契約とする。 -/
  inductive TelBodyTy (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Tel → Comp → Prop where
    | done {Ψ Q C Γ Φ a e body} :
        HasTypeCQ P B Ψ Q C Γ Φ (some a) body a e [] →
        TelBodyTy P B Ψ Q C Γ Φ (.done a e) body
    | param {Ψ Q C Γ Φ name a rest body} :
        TelBodyTy P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) rest body →
        TelBodyTy P B Ψ Q C Γ Φ (.param name a rest) body

  /-- 捕捉時の文脈と有限環境の型付き像を同時に保持する。 -/
  inductive CaptureOk (P : Program) (B : Builtins) :
      StoreTy → Option Ty → Ctx → List Pred → Capture → Prop where
    | mk {Ψ R Γ Φ cap} : Ctx.CaptureWF 0 0 Γ →
        cap.values.length = Γ.length →
        (∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ∃ v, cap.values[i]? = some (some v)) →
        (∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.CaptureSorted Γ ∧ a.CaptureDeclared P [] Γ) →
        (∀ p ∈ Φ, p.WF Γ.length ∧ Pred.Sorted Γ none p ∧ Pred.Declared P [] Γ none p) →
        (∀ ov ∈ cap.values, ∀ v, ov = some v → v.Ground) →
        (∀ i a, Γ[i]? = some (some a) → ImageOk P B Ψ Qempty [] [] [] R cap.env i a) →
        (∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p)) →
        CaptureOk P B Ψ R Γ Φ cap

  inductive DependentClosureTy (P : Program) (B : Builtins) : StoreTy → Closure → Tel → Prop where
    | mk {Ψ cap code Γ Φ t} :
        CaptureOk P B (hideBuilders Ψ) none Γ Φ cap →
        TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ t code →
        Ty.Annotation P [] (hideConts Γ) (.dependentFn t) →
        Ty.Annotation P [] [] (.dependentFn (cap.closeTel t)) →
        DependentClosureTy P B Ψ (.mk cap code) (cap.closeTel t)

  inductive CheckedWitness (P : Program) (B : Builtins) :
      StoreTy → OpaqueName → Scope.Domain.Kind → RangeExpr → Option PathEnv →
        Scope.Domain.Target → Option Val → Prop where
    | plain {Ψ o k range snapshot target} : B.valKind o = some k → B.valContent o = none →
        target.kind = k → SnapshotMem snapshot k range target →
        CheckedWitness P B Ψ o k range snapshot target none
    | request {Ψ o range snapshot target req T} : B.valKind o = some .endpoint →
        B.valContent o = some T → HasTypeVQ P B Ψ Qempty [] [] [] req T.norm →
        groundVal req = true → req.reqTarget = some target → SnapshotMem snapshot .endpoint range target →
        CheckedWitness P B Ψ o .endpoint range snapshot target (some req)

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
    /-- pattern に動的な文字列を渡す呼出し。文字列は実行時に `parseAtPattern` が範囲の式へ読む。 -/
    | text {Ψ Q C Γ Φ kind name shape bases pattern input index inputTy} :
        shape.Declared P → B.valKind name = some kind →
        (∀ v, bases = some v → HasTypeVQ P B Ψ Q C Γ Φ v .pathBases) →
        HasTypeVQ P B Ψ Q C Γ Φ pattern (.base .string) →
        (inputTy = .base .string ∧ B.valContent name = none ∨ B.valContent name = some inputTy ∧ inputTy.WF 0 0 0 ∧ inputTy.RowsIn (· < 0)) →
        HasTypeVQ P B Ψ Q C Γ Φ input inputTy.norm → index.WF 0 →
        (∀ r, index = .fixed r → r.WF ∧ r.Canonical ∧ r.FitsKind kind) →
        AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index

  /-- 被検査値の観測を共有し、各腕で確かめた条件を本体へ渡す。 -/
  inductive HasTypeArmsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Option Ty → Option Term →
      List Arm → Ty → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | nil {Ψ Q C Γ Φ Δ R obs a b ε} : Ty.Annotation P C Γ b →
        HasTypeArmsQ P B Ψ Q C Γ Φ R obs [] a b ε Δ
    | plain {Ψ Q C Γ Φ Δ R obs alts body arms a b ε δ links} : AltsTy P alts a δ →
        LinksValid alts δ.length links →
        FactsWF P C (bindParams Γ δ) (fieldFacts δ.length obs links) →
        FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)) →
        HasTypeCQ P B Ψ Q C (bindParams Γ δ)
          (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
          (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0)
          (localExtend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ (pathFacts obs (excludedTests alts) ++ Φ) R obs arms a b ε Δ →
        HasTypeArmsQ P B Ψ Q C Γ Φ R obs (.mk alts none body :: arms) a b ε Δ
    | guarded {Ψ Q C Γ Φ Δ R obs alts guard body arms a b ε δ p links} : AltsTy P alts a δ →
        LinksValid alts δ.length links →
        FactsWF P C (bindParams Γ δ) (fieldFacts δ.length obs links) →
        FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)) →
        Ty.Annotation P C (hideConts (bindParams Γ δ)) (.refined (.base .boolean) p) →
        HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ))
          (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
          none guard (.refined (.base .boolean) p) Eff.empty (localExtend δ.length Δ) →
        HasTypeCQ P B Ψ Q C (bindParams Γ δ)
          (p.open (.boolean true) :: (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ)))
          (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0)
          (localExtend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
        HasTypeArmsQ P B Ψ Q C Γ Φ R obs (.mk alts (some guard) body :: arms) a b ε Δ

  inductive HasTypeClausesQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Option Ty → Eff →
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
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Ty → Option Ty →
      List Clause → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | one {Ψ Q C Γ Φ Δ E R body t ec} : Ty.Annotation P C Γ E → Ty.Annotation P C Γ t →
        RowAnnotations P C Γ [ec] →
        HasTypeCQ P B (hideBuilders Ψ) Q (TypeCtx.valueParam::C) (failureContext Γ E) (liftMany 2 Φ)
          (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) body
          ((shiftTypes 1 0 t).shiftV 2 0) ((shiftRowsTypes 1 0 ec).shiftV 2 0) [] →
        HasFailureClause P B Ψ Q C Γ Φ E R [.fail E body] t ec Δ

  inductive ImageOk (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Option Ty →
      (Nat → Val) → Nat → Ty → Prop where
    | ordinary {Ψ Q C Δ Ξ R0 ν i a} : a.Ordinary →
        HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a) →
        ImageOk P B Ψ Q C Δ Ξ R0 ν i a
    | hidden {Ψ Q C Δ Ξ R0 ν i a} : ¬ a.Ordinary →
        (∀ b t e, a ≠ .cont b t e) → ImageOk P B Ψ Q C Δ Ξ R0 ν i a
    | contLoc {Ψ Q C Δ Ξ R0 ν i a b t e b' t' e' l} :
        a = .cont b t e → substTyValues ν a = .cont b' t' e' →
        (substTyValues ν a).WF 0 0 0 → ν i = .loc l → Ψ l = some (.cont b' t' e' R0) →
        (∀ r, R0 = some r → r.WF 0 0 0) → ImageOk P B Ψ Q C Δ Ξ R0 ν i a
    | contVar {Ψ Q C Δ Ξ R0 ν i a b t e j} : a = .cont b t e → ν i = .var j →
        (∃ b' t' e', Δ[j]? = some (some (.cont b' t' e')) ∧
          (Ty.cont b' t' e').norm = substTyValues ν a) → ImageOk P B Ψ Q C Δ Ξ R0 ν i a

end

/-- 本体の局所参照はcode0とLで検査し、実行用codeとの対応をρで保持する。 -/
inductive ClosureTy (P : Program) (B : Builtins) :
    StoreTy → List Ty → Option Ty → Closure → Ty → Eff → Prop where
  | mk {Ψ ss R cap code0 code Γ Φ Rs a e L ρ} :
      CaptureOk P B Ψ R Γ Φ cap →
      HasTypeCQ P B Ψ Qempty [] (bindParams Γ ss) (liftMany ss.length Φ) Rs code0 a e L →
      CaptureLocals Ψ (upSubst ss.length cap.env) L ρ →
      code = code0.resolveLocals ρ → TypeAnnotations P [] Γ ss →
      TypeAnnotations P [] [] (ss.map cap.closeTy) → cap.closeRAt ss.length Rs = R →
      Ty.Annotation P [] (bindParams [] (ss.map cap.closeTy)) (cap.closeTyAt ss.length a) →
      Ty.Annotation P [] (bindParams [] (ss.map cap.closeTy))
        (.dependentFn (.done (cap.closeTyAt ss.length a) (cap.closeEffAt ss.length e))) →
      (∀ r, Rs = some r → Ty.Declared P [] (bindParams Γ ss) r) →
      (∀ r, R = some r → Ty.Declared P [] (bindParams [] (ss.map cap.closeTy)) r) →
      ClosureTy P B Ψ (ss.map cap.closeTy) R (.mk cap code)
        (cap.closeTyAt ss.length a) (cap.closeEffAt ss.length e)

theorem HasTypeVQ.refine_integer {P B store Q C Γ Φ v a t p}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.IntegerCarrier) (ht : v.toTerm? = some t)
    (hda : Ty.Declared P C Γ a) (hdp : Pred.Declared P C Γ (some a) p)
    (hs : Pred.Sorted Γ (some a) p) (hw : p.WF (Γ.length+1))
    (he : Entails (Γ.facts ++ Φ) (p.open t)) : HasTypeVQ P B store Q C Γ Φ v (.refined a p) :=
  .V_Refine h hi ht hs hw he hda hdp

theorem HasTypeVQ.convert {P B Ψ Q C Γ Φ v a b}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (he : a.norm = b.norm)
    (hb : Ty.Annotation P C Γ b) : HasTypeVQ P B Ψ Q C Γ Φ v b :=
  .V_Sub h (.convert he) hb.wf hb.sorted hb.declared

theorem HasTypeCQ.convert {P B Ψ Q C Γ Φ R m a b e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (he : a.norm = b.norm)
    (hb : Ty.Annotation P C Γ b) : HasTypeCQ P B Ψ Q C Γ Φ R m b e L :=
  .C_Sub h (.convert he) (Eff.Covers.refl Γ Φ e) hb.wf hb.sorted hb.declared

theorem CaptureOk.empty (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty) :
    CaptureOk P B Ψ R [] [] Capture.empty := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; cases hi
  · intro i a hi; cases hi
  · intro i a hi; cases hi
  · intro p hp; cases hp
  · intro ov ho; cases ho
  · intro i a hi; cases hi
  · intro p hp; cases hp

abbrev HasTypeTelArgs (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeTelArgsQ P B Ψ Qempty

/-- 欄の事実を使わない腕は空の経路列で導出できる。 -/
theorem HasTypeArmsQ.plainEmpty {P B Ψ Q C Γ Φ Δ R obs alts body arms a b ε δ}
    (hp : AltsTy P alts a δ)
    (hw : FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)))
    (hb : HasTypeCQ P B Ψ Q C (bindParams Γ δ)
      (liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
      (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0)
      (localExtend δ.length Δ))
    (hs : HasTypeArmsQ P B Ψ Q C Γ (pathFacts obs (excludedTests alts) ++ Φ) R obs arms a b ε Δ) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs (.mk alts none body :: arms) a b ε Δ := by
  apply HasTypeArmsQ.plain (links := []) hp (by intro l hl; cases hl) _ hw _ hs
  · cases obs <;> intro p hp <;> cases hp
  · cases obs <;> exact hb

/-- guard と本体の双方で欄の事実を使わない腕。 -/
theorem HasTypeArmsQ.guardedEmpty {P B Ψ Q C Γ Φ Δ R obs alts guard body arms a b ε δ p}
    (hp : AltsTy P alts a δ)
    (hw : FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)))
    (ha : Ty.Annotation P C (hideConts (bindParams Γ δ)) (.refined (.base .boolean) p))
    (hg : HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ))
      (liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
      none guard (.refined (.base .boolean) p) Eff.empty (localExtend δ.length Δ))
    (hb : HasTypeCQ P B Ψ Q C (bindParams Γ δ)
      (p.open (.boolean true) :: liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
      (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0)
      (localExtend δ.length Δ))
    (hs : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs (.mk alts (some guard) body :: arms) a b ε Δ := by
  apply HasTypeArmsQ.guarded (links := []) hp (by intro l hl; cases hl) _ hw ha _ _ hs
  · cases obs <;> intro p hp <;> cases hp
  · cases obs <;> exact hg
  · cases obs <;> exact hb

abbrev HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVQ P B Ψ Qempty
abbrev HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVsQ P B Ψ Qempty
abbrev HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeEachQ P B Ψ Qempty
abbrev HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeCQ P B Ψ Qempty
abbrev HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeArmsQ P B Ψ Qempty
abbrev HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeClausesQ P B Ψ Qempty
abbrev HasTypeCL (P : Program) (B : Builtins) (Ψ : StoreTy) (C : TypeCtx)
    (Δ : LocalCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (ε : Eff) :=
  HasTypeCQ P B Ψ Qempty C Γ Φ R m a ε Δ

/-- 範囲パラメータを持たない関数参照。 -/
theorem HasTypeVQ.fun_empty {P B Ψ Q C Γ Φ f d ts es}
    (hd : P.defs f = some d) (hn : NamesWF d.names d.params) (hr : d.rkinds = [])
    (ha : Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
      (Qsig d.params d.ret d.eff) Q ts es d.eff)
    (hi : SignatureInstance P C Γ d.tel (TypeCtx.kinds d.tparams) ts es) :
    HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es)
      (.dependentFn (instantiatedTel d.tel ts es)) := by
  have had : d.RangeAdmissible [] := by
    simp [Def.RangeAdmissible, RangesFit, hr]
  simpa only [List.map_nil, Def.instTel_nil] using
    HasTypeVQ.V_Fun hd hn had ha (by simpa only [Def.instTel_nil] using hi)

end Benitoite.Release.Refinement
