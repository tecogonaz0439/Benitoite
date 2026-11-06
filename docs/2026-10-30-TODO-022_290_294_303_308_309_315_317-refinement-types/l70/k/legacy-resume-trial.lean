import Benitoite.Release.Refinement.LegacyEmbedding
import Benitoite.Release.Refinement.ScopeSignatures
import Benitoite.Release.Refinement.HandlerEffects

namespace Benitoite.Release.Refinement.LegacyResumeTrial
noncomputable section

def issuesIn (B : Builtins) (l : EffName) : Bool :=
  match B.effects l with
  | some bs => bs.any fun b => match B.sig b with
    | some s => decide (s.kind = .pathBases)
    | none => false
  | none => false

def handledD (P : Program) (B : Builtins) (cs : List Clause) : Eff :=
  .mk (fun a => match a with
    | .name l _ => match effOps P B l with
      | some (o::os) => (o::os).all (handles cs) && !issuesIn B l
      | _ => false
    | .rho _ => false) []

def K : DeclarationKinds := ⟨fun _ => .value,fun _ => [],fun _ _ => []⟩
def op0 : Benitoite.Release.OpDecl := ⟨"State",[],[],[],.base .unit,[]⟩
def P0 : Benitoite.Release.Program :=
  ⟨fun _ => none,fun _ => none,fun o => if o = "stateOp" then some op0 else none,
    fun l => if l = "State" then some ["stateOp"] else none,fun _ => none,fun _ => none⟩
def B0 : Benitoite.Release.Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun o => decide (o = "Resource")
  effects := fun l => if l = "State" then some ["ghost"] else none
  sat := fun _ _ _ => True
  refGet := "get"
  refSet := "set"
def B : Builtins where
  sig := fun b => if b = "ghost" then some ScopeSignatures.pathBases else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun o => decide (o = "Resource")
  effects := fun l => if l = "State" then some ["ghost"] else none
  sat := fun _ _ _ => True
  refGet := "get"
  refSet := "set"
def P : Program := embedProgramWithKinds K P0

theorem kinds_wf : K.WF P0 := by
  constructor
  · intro f d h; cases h
  · intro cl cd m ms h; cases h

theorem tables : LegacyTables K P0 B0 B := by
  constructor
  · intro b s hs; cases hs
  · intro C a p _; trivial
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · intro o; rfl
  · intro b rs h; cases h
  · intro c cd c' cd' hc; cases hc
  · intro c cd hc; cases hc
  · intro c cd hc; cases hc

def clauses0 : List Benitoite.Release.Clause :=
  [.mk (.user "stateOp") 0 0 (.ret (.const .unit))]
def clauses : List Clause := embedClauses clauses0

theorem old_handles_state : (Benitoite.Release.handled P0 B0 clauses0).mem (.nameTop "State") := by
  decide

theorem d_never_handles_state (cs : List Clause) (ix : RangeIx) :
    ¬ (handledD P B cs).mem (.name "State" ix) := by
  simp [handledD,issuesIn,B,ScopeSignatures.pathBases,Eff.mem,Eff.test,Eff.atoms,effOps,P,embedProgramWithKinds_effects,P0]

theorem legacy_handled_sub_false :
    ¬ Eff.Sub (embedEff (Benitoite.Release.handled P0 B0 clauses0)) (handledD P B clauses) := by
  intro sub
  exact d_never_handles_state clauses .top (sub.1 (.name "State" .top) (by decide))

end
end Benitoite.Release.Refinement.LegacyResumeTrial

namespace Benitoite.Release.Refinement.LegacyResumeTrial.DTyping
variable {P : Program}
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
    | V_Fun {Ψ Q C Γ Φ f d ts es} : P.defs f = some d → NamesWF d.names d.params →
        Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff →
        SignatureInstance P C Γ d.tel (TypeCtx.kinds d.tparams) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es) (.dependentFn (instantiatedTel d.tel ts es))
    | V_Prim {Ψ Q C Γ Φ b s ts es rs} : B.sig b = some s → B.RangeAdmissible b s rs →
        NamesWF s.names s.params → PrimitiveAdmissible C Γ.length s Q ts es →
        SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es →
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
        Eff.Sub εm (Eff.union ε (Benitoite.Release.Refinement.LegacyResumeTrial.handledD P B h)) →
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
end Benitoite.Release.Refinement.LegacyResumeTrial.DTyping

namespace Benitoite.Release.Refinement.LegacyResumeTrial.DTyping
noncomputable section
theorem HasTypeCQ.inv_use {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.use v m)) :
∃ o a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top))) ∧
      (B.isResource o = true) ∧
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (ε.test (.name stateEff (.fixed .top)) = true) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε := by
  match typed with
  | .C_Use h0 h1 h2 h3 => cases hm; exact ⟨_, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_use hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_use hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_use hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_handle {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {handlers} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.handle m handlers)) :
(∃ t εm ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ) ∧
      (Eff.Sub εm (Eff.union ε (Benitoite.Release.Refinement.LegacyResumeTrial.handledD P B handlers))) ∧
      (HasTypeClausesQ P B Ψ Q C Γ Φ R εm handlers t ε Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
    (∃ t E eb rest ec,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ) ∧
      (Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) ∧
      (NoFail Q rest) ∧
      (HasFailureClause P B Ψ Q C Γ Φ E R handlers t ec Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff (Eff.union rest ec)) := by
  match typed with
  | .C_Handle h0 h1 h2 => cases hm; exact Or.inl (⟨_, _, _, h0, h1, h2, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_Handle_Fail h0 h1 h2 h3 => cases hm; exact Or.inr (⟨_, _, _, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_Normal hh =>
    rcases hh.inv_handle hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
  | .C_Sub hh step cover .. =>
    rcases hh.inv_handle hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans step, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le.trans step, cover.trans cov⟩)
  | .C_Eff hh cover =>
    rcases hh.inv_handle hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cover.trans cov⟩)
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm


end
end Benitoite.Release.Refinement.LegacyResumeTrial.DTyping

namespace Benitoite.Release.Refinement.LegacyResumeTrial
noncomputable section

def body0 : Benitoite.Release.Comp := .use (.const (.opaque "Resource" 0)) (.ret (.const .unit))
def body : Comp := embedComp body0

theorem state_cover {Γ Φ outer inner} (h : Eff.Covers Γ Φ outer inner)
    (hi : ∃ ix, inner.mem (.name "State" ix)) : ∃ ix, outer.mem (.name "State" ix) := by
  obtain ⟨ix,hi⟩ := hi
  obtain ⟨a,ha,hc⟩ := h.1 _ hi
  obtain ⟨jx,rfl⟩ := hc.name_right
  exact ⟨jx,ha⟩

/-- 案 D の全型付け導出を量化し、規則を一つ選んだ場合だけの拒否にしない。 -/
theorem d_handler_rejected {Ψ Q C Γ Φ R a L} :
    ¬ DTyping.HasTypeCQ P B Ψ Q C Γ Φ R (.handle body clauses) a Eff.empty L := by
  intro h
  rcases h.inv_handle rfl with ⟨t,em,e,hm,sub,hs,le,cov⟩ | ⟨t,E,eb,rest,ec,hm,sub,nf,hf,le,cov⟩
  · obtain ⟨o,a0,e0,hv,hr,hret,hi,hl,hcov⟩ := hm.inv_use rfl
    obtain ⟨ix,hix⟩ := state_cover hcov ⟨.top,hi⟩
    rcases (Eff.mem_union_iff _ _ _).mp (sub.1 _ hix) with he | hh
    · obtain ⟨ix,hempty⟩ := state_cover cov ⟨ix,he⟩
      cases hempty
    · exact d_never_handles_state clauses ix hh
  · cases hf

end
end Benitoite.Release.Refinement.LegacyResumeTrial

namespace Benitoite.Release.Refinement.LegacyResumeTrial
noncomputable section
private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private abbrev S : Benitoite.Release.StoreTy := .empty

private theorem unit_type (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat) :
    LegacyTypeInput K P0 ⟨κ,C,0,nv⟩ U .value :=
  ⟨trivial,trivial,trivial,trivial,trivial⟩

private theorem context (κ : KindCtx) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) (count : κ.length = C.length)
    (hΓ : ∀ (i : Nat) a, Γ[i]? = some (some a) → a = U) :
    LegacyNodeContext K P0 κ S C Γ := by
  refine ⟨rfl,rfl,count,?_,?_⟩
  · intro l lt hl; cases hl
  · intro i a hi
    have ha := hΓ i a hi
    subst a
    exact ⟨unit_type κ C Γ.length,⟨trivial,trivial,trivial⟩⟩

private theorem rows (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat) :
    LegacyRowsInput K P0 ⟨κ,C,0,nv⟩ [E] := by
  intro e he
  obtain rfl := List.mem_singleton.mp he
  unfold LegacyTypeInput
  rw [show embedTy (.fn [] [] (.base .unit) E) = .fn [] [] (.base .unit) Eff.empty from
    congrArg (Ty.fn [] [] (.base .unit)) legacy_empty]
  simp [Ty.HasKind,kindsList,kindsEff,NamesWF,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,
    Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]

theorem clauses_input : LegacyOutputInput K P0 B0 B
    (.clauses [] S Benitoite.Release.Qempty [] [] none
      (Benitoite.Release.Eff.single "State") clauses0 U E []) := by
  let sg : Benitoite.Release.OpSig := ⟨[],[],[],U,"State"⟩
  have lookup : Benitoite.Release.opSig P0 B0 (.user "stateOp") = some sg := by
    simp [Benitoite.Release.opSig,P0,op0,sg]
  have signature : Benitoite.Release.ClauseSig P0 B0
      (Benitoite.Release.Eff.single "State") (.user "stateOp") sg :=
    ⟨.top,Or.inl rfl,by simpa only [Benitoite.Release.opSigAt_top] using lookup⟩
  have source : LegacyTypeInput K P0 ⟨[],[],0,0⟩
      (.fn [] [] U (Benitoite.Release.Eff.single "State")) .value := by
    unfold LegacyTypeInput
    rw [show embedTy (.fn [] [] U (Benitoite.Release.Eff.single "State")) =
      .fn [] [] (.base .unit) (Eff.single "State") from
      congrArg (Ty.fn [] [] (.base .unit)) (legacy_single "State")]
    simp [Ty.HasKind,kindsList,kindsEff,Ty.WF,NamesWF,Ty.WFList,Eff.WF,Eff.Canonical,
      Eff.norm,Eff.single,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
      declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]
    trivial
  have continuation : LegacyTypeInput K P0 ⟨[],[],0,1⟩ (.cont U U E) .value := by
    simp [LegacyTypeInput,embedTy,legacy_empty,Ty.HasKind,kindsList,kindsEff,Ty.WF,Ty.WFList,sortedTys,declaredTys,Eff.WF,Eff.Canonical,
      Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedEff,Ty.Declared,declaredEff,
      Ty.RangesScoped,Eff.RangesScoped,rangesScopedTypes]
  have ctx := context [] [] [] rfl (by simp)
  have bodyCtx : LegacyNodeContext K P0 [] S [] [some (.cont U U E)] := by
    refine ⟨rfl,rfl,rfl,?_,?_⟩
    · intro l lt hl; cases hl
    · intro i a hi
      cases i with
      | zero =>
        cases Option.some.inj (Option.some.inj hi)
        exact ⟨continuation,continuation.annotation_at rfl rfl _⟩
      | succ i => simp at hi
  have bodyValue : LegacyOutputInput K P0 B0 B
      (.value [] S Benitoite.Release.Qempty [] [some (.cont U U E)] (.const .unit) U) := by
    refine .node .V_Const ⟨bodyCtx,trivial,trivial,?_⟩ (by simp)
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 1
  have body : LegacyOutputInput K P0 B0 B
      (.comp [] S Benitoite.Release.Qempty [] [some (.cont U U E)] none (.ret (.const .unit)) U E []) := by
    refine .node .C_Return ⟨bodyCtx,trivial,?_,rows [] [] 1,by simp [LegacyNodeLocal]⟩ ?_
    · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 1
    · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact bodyValue
  have rowInputs : LegacyRowsInput K P0 ⟨[],[],0,0⟩
      [Benitoite.Release.Eff.single "State",E] := by
    intro e he
    rcases List.mem_cons.mp he with rfl | he
    · exact source
    · exact rows [] [] 0 e he
  have regular : ∀ cs, LegacyClausesInput K P0 B0 B ⟨[],[],0,0⟩ cs →
      LegacyNodeRegular K P0 B0 B
        (.clauses [] S Benitoite.Release.Qempty [] [] none
          (Benitoite.Release.Eff.single "State") cs U E []) := by
    intro cs input
    refine ⟨ctx,input,?_,rowInputs,by simp [LegacyNodeLocal]⟩
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0
  have input : LegacyOutputInput K P0 B0 B
      (.clauses [] S Benitoite.Release.Qempty [] [] none
        (Benitoite.Release.Eff.single "State") [.mk (.user "stateOp") 0 0 (.ret (.const .unit))] U E []) := by
    refine .node (.Clauses_cons signature (by simp [sg,Benitoite.Release.NamesWF]) rfl rfl trivial)
      (regular _ ⟨⟨sg,lookup,rfl,rfl,source,trivial⟩,trivial⟩) ?_
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · have hs : S.hideBuilders = S := by funext l; rfl
      have he : Benitoite.Release.Eff.shift 0 0 E = E := by
        simp [Benitoite.Release.Eff.shift,Benitoite.Release.Eff.rawShift,E,
          Benitoite.Release.Eff.empty,Benitoite.Release.Eff.norm,Benitoite.Release.Ty.rawShiftTys,
          Benitoite.Release.Ty.normTys]
      simpa only [sg,List.length_nil,List.replicate_zero,List.nil_append,List.append_nil,
        hs,Option.map_none,Benitoite.Release.Ty.shift,he,Benitoite.Release.binds,List.reverse_nil,
        List.map_nil,Benitoite.Release.shiftEnv] using body
    · obtain rfl := List.mem_singleton.mp hc
      exact .node .Clauses_nil (regular [] trivial) (by simp)
  exact input


end
end Benitoite.Release.Refinement.LegacyResumeTrial

namespace Benitoite.Release.Refinement.LegacyResumeTrial
noncomputable section

private theorem state_row (nv : Nat) :
    LegacyRowsInput K P0 ⟨[],[],0,nv⟩ [Benitoite.Release.Eff.single "State"] := by
  intro e he
  obtain rfl := List.mem_singleton.mp he
  unfold LegacyTypeInput
  rw [show embedTy (.fn [] [] U (Benitoite.Release.Eff.single "State")) =
    .fn [] [] (.base .unit) (Eff.single "State") from
    congrArg (Ty.fn [] [] (.base .unit)) (legacy_single "State")]
  simp [Ty.HasKind,kindsList,kindsEff,Ty.WF,NamesWF,Ty.WFList,Eff.WF,Eff.Canonical,
    Eff.norm,Eff.single,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]
  trivial

private theorem comp_regular {m e}
    (hm : LegacyCompInput K P0 B0 B ⟨[],[],0,0⟩ m)
    (he : LegacyRowsInput K P0 ⟨[],[],0,0⟩ [e]) :
    LegacyNodeRegular K P0 B0 B (.comp [] S Benitoite.Release.Qempty [] [] none m U e []) := by
  refine ⟨context [] [] [] rfl (by simp),hm,?_,he,by simp [LegacyNodeLocal]⟩
  intro a ha; obtain rfl := List.mem_singleton.mp ha
  exact unit_type [] [] 0

private theorem resource_value_input : LegacyOutputInput K P0 B0 B
    (.value [] S Benitoite.Release.Qempty [] [] (.const (.opaque "Resource" 0)) (.opaqueTop "Resource")) := by
  refine .node .V_Const ⟨context [] [] [] rfl (by simp),⟨rfl,rfl⟩,trivial,?_⟩ (by simp)
  intro a ha; obtain rfl := List.mem_singleton.mp ha
  exact ⟨trivial,trivial,trivial,trivial,trivial⟩

private theorem unit_value_input : LegacyOutputInput K P0 B0 B
    (.value [] S Benitoite.Release.Qempty [] [] (.const .unit) U) :=
  .node .V_Const ⟨context [] [] [] rfl (by simp),trivial,trivial,by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0⟩ (by simp)

private theorem ret_unit_input : LegacyOutputInput K P0 B0 B
    (.comp [] S Benitoite.Release.Qempty [] [] none (.ret (.const .unit)) U E []) := by
  refine .node .C_Return (comp_regular trivial (rows [] [] 0)) ?_
  intro c hc; obtain rfl := List.mem_singleton.mp hc
  exact unit_value_input

private theorem ret_state_input : LegacyOutputInput K P0 B0 B
    (.comp [] S Benitoite.Release.Qempty [] [] none (.ret (.const .unit)) U
      (Benitoite.Release.Eff.single "State") []) := by
  refine .node (.C_Eff (ε := E) ⟨?_,?_⟩) (comp_regular trivial (state_row 0)) ?_
  · intro a ha; cases ha
  · intro a ha; obtain ⟨b,hb,_⟩ := ha; cases hb
  · intro c hc; obtain rfl := List.mem_singleton.mp hc
    exact ret_unit_input

theorem body_input : LegacyOutputInput K P0 B0 B
    (.comp [] S Benitoite.Release.Qempty [] [] none body0 U (Benitoite.Release.Eff.single "State") []) := by
  refine .node (.C_Use (o := "Resource") rfl (by decide)) (comp_regular ⟨⟨rfl,rfl⟩,trivial⟩ (state_row 0)) ?_
  intro c hc
  rcases List.mem_cons.mp hc with rfl | hc
  · exact resource_value_input
  · obtain rfl := List.mem_singleton.mp hc
    exact ret_state_input

private theorem old_handle_sub : Benitoite.Release.Eff.Sub
    (Benitoite.Release.Eff.single "State")
    (Benitoite.Release.Eff.union E (Benitoite.Release.handled P0 B0 clauses0)) := by
  constructor
  · intro a ha
    have eq : a = .nameTop "State" := of_decide_eq_true ha
    subst a
    decide
  · intro a ha; obtain ⟨b,hb,_⟩ := ha; cases hb

theorem handler_input : LegacyOutputInput K P0 B0 B
    (.comp [] S Benitoite.Release.Qempty [] [] none (.handle body0 clauses0) U E []) := by
  have ci := clauses_input.regular.2.1
  refine .node (.C_Handle old_handle_sub) (comp_regular ⟨⟨⟨rfl,rfl⟩,trivial⟩,ci⟩ (rows [] [] 0)) ?_
  intro c hc
  rcases List.mem_cons.mp hc with rfl | hc
  · exact body_input
  · obtain rfl := List.mem_singleton.mp hc
    exact clauses_input

theorem old_handler_typed : Benitoite.Release.HasTypeCQ P0 B0 S Benitoite.Release.Qempty [] [] none
    (.handle body0 clauses0) U E [] := handler_input.old

/-- 旧埋め込みの固定された入力が実際にそろい、案 D の結論だけが成り立たない。 -/
theorem embedding_obstruction :
    K.WF P0 ∧ LegacyTables K P0 B0 B ∧
    LegacyOutputInput K P0 B0 B
      (.comp [] S Benitoite.Release.Qempty [] [] none (.handle body0 clauses0) U E []) ∧
    ¬ DTyping.HasTypeCQ P B (embedStoreTy S) Qempty [] [] [] none
      (embedComp (.handle body0 clauses0)) (.base .unit) Eff.empty [] :=
  ⟨kinds_wf,tables,handler_input,d_handler_rejected⟩

end
end Benitoite.Release.Refinement.LegacyResumeTrial

namespace Benitoite.Release.Refinement.LegacyResumeTrial
noncomputable section

/-- 比較用の代案。操作の一覧を選んだ表と、発行を調べる表を一致させる。 -/
def issuesSelected (P : Program) (B : Builtins) (l : EffName) : Bool :=
  match P.effects l with
  | some _ => false
  | none => issuesIn B l

def handledSelected (P : Program) (B : Builtins) (cs : List Clause) : Eff :=
  .mk (fun a => match a with
    | .name l _ => match effOps P B l with
      | some (o::os) => (o::os).all (handles cs) && !issuesSelected P B l
      | _ => false
    | .rho _ => false) []

/-- 主定理が要求する分離の下では、代案と案 D が全ラベル・全節で同じである。 -/
theorem selected_eq_d {P : Program} {B : Builtins} (h : P.EffectsOk B) (cs : List Clause) :
    handledSelected P B cs = handledD P B cs := by
  unfold handledSelected handledD
  congr 1
  funext a
  cases a with
  | rho i => rfl
  | name l ix =>
    cases hp : P.effects l with
    | none => simp [issuesSelected,hp]
    | some os =>
      have hb := h.2.2 l os hp
      simp [issuesSelected,hp,issuesIn,hb]

/-- この反例では代案が旧の包含を回復する。全埋め込みの証明ではない。 -/
theorem selected_repairs_inclusion :
    Eff.Sub (embedEff (Benitoite.Release.handled P0 B0 clauses0)) (handledSelected P B clauses) := by
  have hi : ∀ l, issuesSelected P B l = false := by
    intro l
    by_cases h : l = "State"
    · subst l; rfl
    · simp [issuesSelected,P,P0,embedProgramWithKinds_effects,h,issuesIn,B]
  have he : handledSelected P B clauses = handled P B clauses := by
    unfold handledSelected handled
    congr 1
    funext a
    cases a with
    | rho i => rfl
    | name l ix =>
      simp only [hi,Bool.not_false,Bool.and_true]
      rfl
  rw [he]
  exact legacy_handled_sub tables clauses0

end
end Benitoite.Release.Refinement.LegacyResumeTrial
