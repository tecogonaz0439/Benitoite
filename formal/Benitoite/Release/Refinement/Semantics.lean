import Benitoite.Release.Refinement.RuntimeSyntax
import Benitoite.Release.Refinement.RuntimeMatch
import Benitoite.Release.Refinement.AtPrepare
import Benitoite.Release.Refinement.ExternalResponse

namespace Benitoite.Release.Refinement
noncomputable section

/-- 事象が要求する効果名の被覆。IOの範囲は存在量化し、対象の許可は後続の対象健全性で扱う。
σの発行と解放は範囲なし（Top）のProcess.EnvironmentとStateをそれぞれ要求する。 -/
def Event.Covered (B : Builtins) (Γ : Ctx) (Φ : List Pred) (ε : Eff) : Event → Prop
  | .io b _ _ _ => ∃ s l r, B.sig b = some s ∧ s.opEff = some l ∧
      ε.Covers Γ Φ (.mk (fun a => decide (a = .name l r)) [])
  | .release _ _ => ε.Covers Γ Φ (Eff.single stateEff)
  | .pathBases _ _ => ε.Covers Γ Φ (Eff.single processEnvironmentEff)

/-- σ発行の被覆はProcess.Environmentの被覆そのものであり、組込み名やsnapshotに依存しない。 -/
theorem Event.covered_pathBases {B Γ Φ ε b σ} :
    (Event.pathBases b σ).Covered B Γ Φ ε ↔ ε.Covers Γ Φ (Eff.single processEnvironmentEff) := Iff.rfl

def markPush : Cont → Cont
  | .mark :: k => .mark :: k
  | k => .mark :: k

def releases : Cont → Cont
  | [] => []
  | .release v :: k => .release v :: releases k
  | .drop κ :: k => .drop κ :: releases k
  | _ :: k => releases k

def findClause (h : List Clause) (o : OpRef) : Option Clause := h.find? (fun c => c.op == o)

def NoHandler (k : Cont) (o : OpRef) : Prop :=
  ∀ cap h, Frame.handleF cap h ∈ k → handles h o = false

def UnhandledOp : State → Prop
  | .run q k _ => match q.view with
      | .app (.raise _ _) _ => NoHandler k .fail
      | .app (.op o _) _ => NoHandler k (.user o)
      | _ => False
  | _ => False

def SplitAt (o : OpRef) (k k1 : Cont) (cap : Capture) (h : List Clause) (k2 : Cont) : Prop :=
  k = k1 ++ .handleF cap h :: k2 ∧ handles h o = true ∧ NoHandler k1 o

def Val.superStep (P : Program) : Val → Option Val
  | .super (.dict i ts vs) s =>
      match P.impls i with
      | some id => (id.supers s).map fun u => (u.substTy ts []).instantiate vs
      | none => none
  | .super v s => (Val.superStep P v).map fun v' => .super v' s
  | _ => none

def rResume : ErrKind := "ResumeTwice"

def MatchPrefix (v : Val) (arms : List Arm) (next : Nat) : Prop :=
  ∀ arm ∈ arms.take next, arm.guard = none → firstAlt v arm.alts = none

inductive Step (P : Program) (B : Builtins) (σ : PathEnv) : State → Option Event → State → Prop
  | E_BuilderNew {kind body k μ l} {q : Closure} :
      q.view = (.builderLet kind body) →
      μ l = none →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty)))
  | E_BuilderOp {kind op l args k μ c c' v} {q : Closure} :
      q.view = (.builderOp kind op (.loc l) args) →
      μ l = some (.builder c) → builderApply op c args = some (.value c' v) →
      Step P B σ (.run q k μ) none
        (.run (Closure.pure (.ret v)) k (μ.set l (.builder c')))
  | E_BuilderErr {kind op l args k μ c r} {q : Closure} :
      q.view = (.builderOp kind op (.loc l) args) →
      μ l = some (.builder c) → builderApply op c args = some (.error r) →
      Step P B σ (.run q k μ) none (.error [r] k μ)
  | E_Let {m n k μ} {q : Closure} :
      q.view = (.letIn m n) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture m) (.letF (Closure.mk q.capture n) :: k) μ)
  | E_Return {v n k μ} {q : Closure} :
      q.view = (.ret v) →
      Step P B σ (.run q (.letF n :: k) μ) none (.run (n.apply [v]) k μ)
  | E_Lam {q : Closure} {signature body ws k μ} :
      q.view = .app (.closure signature body) ws → ws.length = signature.arity →
      Step P B σ (.run q k μ) none (.run (body.apply ws) (markPush k) μ)
  | E_ExternalApply {q : Closure} {f ts ws k μ} :
      q.view = .app (.externalRef f ts) ws →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.externalCall f ts ws)) k μ)
  | E_External {q : Closure} {f ts ws k μ decl v obs out} :
      q.view = .externalCall f ts ws → P.externalFunction f = some decl →
      B.externalResponse f ts ws out obs → externalReceive P decl ts ws out = some (.val v) →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_ExternalErr {q : Closure} {f ts ws k μ decl r obs out} :
      q.view = .externalCall f ts ws → P.externalFunction f = some decl →
      B.externalResponse f ts ws out obs → externalReceive P decl ts ws out = some (.err r) →
      Step P B σ (.run q k μ) none (.error [r] k μ)
  | E_PathBasesApply {q : Closure} {b sg k μ} :
      q.view = .app (.prim b [] [] []) [] → B.sig b = some sg → sg.kind = .pathBases →
      NoHandler k (.prim b) →
      Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ)
  | E_IssuePathBases {q : Closure} {b sg k μ} :
      q.view = .issuePathBases b → B.sig b = some sg → sg.kind = .pathBases →
      sg.opEff = some processEnvironmentEff → σ.Valid →
      Step P B σ (.run q k μ) (some (.pathBases b σ))
        (.run (Closure.pure (.ret (.pathBases σ))) k μ)
  | E_AtOk {q : Closure} {kind name shape bases pattern input index snapshot pat target bound t k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
      (∀ ρ, snapshot = some ρ → ρ = σ) → checkAt snapshot kind pat target bound = .ok t →
      Step P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.ok
          [.scoped name kind (.fixed bound), q.capture.closeTy shape.errorType]
          [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ)
  | E_AtError {q : Closure} {kind name shape bases pattern input index snapshot pat target bound detail k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
      (∀ ρ, snapshot = some ρ → ρ = σ) → checkAt snapshot kind pat target bound = .error detail →
      Step P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.error
          [.scoped name kind (.fixed bound), q.capture.closeTy shape.errorType] [.atError detail]))) k μ)
  | E_AtPrepareError {q : Closure} {kind name shape bases pattern input index detail k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepare B q.capture kind name bases pattern input index = .error detail →
      Step P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.error
          [.scoped name kind index, q.capture.closeTy shape.errorType] [.atError detail]))) k μ)
  | E_Fun {f ts es ws k μ d} {q : Closure} :
      q.view = (.app (.fnRef f ts es) ws) →
      P.defs f = some d →
      ws.length = d.params.length → ts.length = d.ntys → es.length = d.neffs →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)
  
  | E_Meth {i ts vs m ss es ws k μ id body cd ms} {q : Closure} :
      q.view = (.meth (.dict i ts vs) m ss es ws) →
      P.impls i = some id → id.methods m = some body → P.classes id.cls = some cd →
      cd.methods m = some ms →
      ws.length = ms.params.length → vs.length = id.dictTys.length → ts.length = id.tparams.length →
      ss.length = ms.tparams.length → es.length = ms.neffs →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (Capture.empty.extendMany (vs ++ ws)) (body.substTy (ss ++ ts) es)) (markPush k) μ)
  
  | E_Super {v v' m ss es ws k μ} {q : Closure} :
      q.view = (.meth v m ss es ws) →
      v.superStep P = some v' →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.meth v' m ss es ws)) k μ)
  | E_IfT {m n k μ} {q : Closure} :
      q.view = (.ite (.const (.boolean true)) m n) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture m) k μ)
  | E_IfF {m n k μ} {q : Closure} :
      q.view = (.ite (.const (.boolean false)) m n) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture n) k μ)
  | E_Match {v arms k μ} {q : Closure} :
      q.view = (.match v arms) →
      Step P B σ (.run q k μ) none (.matchRun v q.capture arms 0 k μ)
  | E_MatchSkip {v arms next alts guard body k μ} {cap : Capture} :
      arms[next]? = some (.mk alts guard body) → firstAlt v alts = none →
      Step P B σ (.matchRun v cap arms next k μ) none (.matchRun v cap arms (next + 1) k μ)
  | E_MatchBody {v arms next alts body ws k μ} {cap : Capture} :
      arms[next]? = some (.mk alts none body) → firstAlt v alts = some ws →
      Step P B σ (.matchRun v cap arms next k μ) none (.run (Closure.mk (cap.extendMany ws) body) k μ)
  | E_MatchGuard {v arms next alts guard body ws k μ} {cap : Capture} :
      arms[next]? = some (.mk alts (some guard) body) → firstAlt v alts = some ws →
      Step P B σ (.matchRun v cap arms next k μ) none
        (.run (Closure.mk (cap.extendMany ws) guard) (.guardF v cap arms (next + 1) (Closure.mk (cap.extendMany ws) body) :: k) μ)
  | E_GuardT {v arms next body k μ} {q : Closure} {cap : Capture} :
      q.view = (.ret (.const (.boolean true))) →
      Step P B σ (.run q (.guardF v cap arms next body :: k) μ) none (.run body k μ)
  | E_GuardF {v arms next body k μ} {q : Closure} {cap : Capture} :
      q.view = (.ret (.const (.boolean false))) →
      Step P B σ (.run q (.guardF v cap arms next body :: k) μ) none
        (.matchRun v cap arms next k μ)
  | E_ErrPopGuard {rs v arms next body k μ} {cap : Capture} :
      Step P B σ (.error rs (.guardF v cap arms next body :: k) μ) none (.error rs k μ)
  | E_ExitPopGuard {n rs v arms next body k μ} {cap : Capture} :
      Step P B σ (.exit n rs (.guardF v cap arms next body :: k) μ) none (.exit n rs k μ)
  | E_Prim {b ts es rs ws k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .pure → B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.val v) →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_Err {b ts es rs ws k μ s r} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .pure → B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.err r) →
      Step P B σ (.run q k μ) none (.error [r] k μ)
  
  | E_IO {b ts es rs ws k μ s v obs} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .io → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.val v) obs →
      Step P B σ (.run q k μ) (some (.io b ws (.val v) obs)) (.run (Closure.pure (.ret v)) k μ)
  
  | E_IOErr {b ts es rs ws k μ s r obs} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.err r) obs →
      Step P B σ (.run q k μ) (some (.io b ws (.err r) obs)) (.error [r] k μ)
  
  | E_Exit {b ts es rs ws k μ s n obs} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .exit → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.exit n) obs →
      Step P B σ (.run q k μ) (some (.io b ws (.exit n) obs)) (.exit n [] k μ)
  
  | E_RefNew {b ts es rs v k μ s l} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [v]) →
      B.sig b = some s → s.kind = .refNew → μ l = none →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))
  | E_RefGet {b ts es rs l k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l]) →
      B.sig b = some s → s.kind = .refGet → μ l = some (.val v) →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_RefSet {b ts es rs l v k μ s} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l, v]) →
      B.sig b = some s → s.kind = .refSet →
      Step P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))
  
  | E_RefUpdate {b ts es rs l f k μ s} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l, f]) →
      B.sig b = some s → s.kind = .refUpdate →
      Step P B σ (.run q k μ) none
        (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
                (.letIn (.app (f.rename (· + 1)) [.var 0])
                  (.app (.prim B.refSet ts [] []) [.loc l, .var 0])))) k μ)
  | E_Lazy {m k μ l} {q : Closure} :
      q.view = (.lazyC m) →
      μ l = none →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (Closure.mk q.capture m))))
  | E_ForceDone {b ts es rs l k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l]) →
      B.sig b = some s → s.kind = .force → μ l = some (.done v) →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_Force {b ts es rs l k μ s m} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l]) →
      B.sig b = some s → s.kind = .force → μ l = some (.thunk m) →
      Step P B σ (.run q k μ) none (.run m (.update l :: k) μ)
  | E_Update {v l k μ} {q : Closure} :
      q.view = (.ret v) →
      Step P B σ (.run q (.update l :: k) μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.done v)))
  
  | E_Mark {v k μ} {q : Closure} :
      q.view = (.ret v) →
      Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_EscLet {v n k μ} {q : Closure} :
      q.view = (.escape v) →
      Step P B σ (.run q (.letF n :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscHandle {v h k μ} {q : Closure} {hcap : Capture} :
      q.view = (.escape v) →
      Step P B σ (.run q (.handleF hcap h :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscMark {v k μ} {q : Closure} :
      q.view = (.escape v) →
      Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ)
  
  | E_Use {v m k μ} {q : Closure} :
      q.view = (.use v m) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture m) (.release v :: k) μ)
  | E_Release {w v k μ} {q : Closure} :
      q.view = (.ret w) →
      B.releaseResponse v none →
      Step P B σ (.run q (.release v :: k) μ) (some (.release v none)) (.run (Closure.pure (.ret w)) k μ)
  | E_RelErr {w v k μ r} {q : Closure} :
      q.view = (.ret w) →
      B.releaseResponse v (some r) →
      Step P B σ (.run q (.release v :: k) μ) (some (.release v (some r))) (.error [r] k μ)
  | E_EscRel {w v k μ} {q : Closure} :
      q.view = (.escape w) →
      B.releaseResponse v none →
      Step P B σ (.run q (.release v :: k) μ) (some (.release v none)) (.run (Closure.pure (.escape w)) k μ)
  | E_EscRelErr {w v k μ r} {q : Closure} :
      q.view = (.escape w) →
      B.releaseResponse v (some r) →
      Step P B σ (.run q (.release v :: k) μ) (some (.release v (some r))) (.error [r] k μ)
  
  | E_ErrPopLet {rs n k μ} : Step P B σ (.error rs (.letF n :: k) μ) none (.error rs k μ)
  | E_ErrPopMark {rs k μ} : Step P B σ (.error rs (.mark :: k) μ) none (.error rs k μ)
  | E_ErrPopUpdate {rs l k μ} : Step P B σ (.error rs (.update l :: k) μ) none (.error rs k μ)
  | E_ErrPopHandle {rs h k μ} {hcap : Capture} : Step P B σ (.error rs (.handleF hcap h :: k) μ) none (.error rs k μ)
  | E_ErrRel {rs v k μ} :
      B.releaseResponse v none →
      Step P B σ (.error rs (.release v :: k) μ) (some (.release v none)) (.error rs k μ)
  | E_ErrRelErr {rs v k μ r} :
      B.releaseResponse v (some r) →
      Step P B σ (.error rs (.release v :: k) μ) (some (.release v (some r))) (.error (rs ++ [r]) k μ)
  
  | E_ExitPopLet {n rs m k μ} : Step P B σ (.exit n rs (.letF m :: k) μ) none (.exit n rs k μ)
  | E_ExitPopMark {n rs k μ} : Step P B σ (.exit n rs (.mark :: k) μ) none (.exit n rs k μ)
  | E_ExitPopUpdate {n rs l k μ} : Step P B σ (.exit n rs (.update l :: k) μ) none (.exit n rs k μ)
  | E_ExitPopHandle {n rs h k μ} {hcap : Capture} : Step P B σ (.exit n rs (.handleF hcap h :: k) μ) none (.exit n rs k μ)
  | E_ExitRel {n rs v k μ} :
      B.releaseResponse v none →
      Step P B σ (.exit n rs (.release v :: k) μ) (some (.release v none)) (.exit n rs k μ)
  | E_ExitRelErr {n rs v k μ r} :
      B.releaseResponse v (some r) →
      Step P B σ (.exit n rs (.release v :: k) μ) (some (.release v (some r))) (.exit n (rs ++ [r]) k μ)
  
  | E_Handle {m h k μ} {q : Closure} :
      q.view = (.handle m h) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture m) (.handleF q.capture h :: k) μ)
  | E_HRet {v h k μ} {q : Closure} {hcap : Capture} :
      q.view = (.ret v) →
      Step P B σ (.run q (.handleF hcap h :: k) μ) none (.run (Closure.pure (.ret v)) k μ)
  
  | E_Op {o ts ws k μ k1 h k2 c κ} {q : Closure} {hcap : Capture} :
      q.view = (.app (.op o ts) ws) →
      SplitAt (.user o) k k1 hcap h k2 → findClause h (.user o) = some c → μ κ = none →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts [])) (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
  
  | E_OpFail {T E' v k μ k1 E body k2 κ} {q : Closure} {hcap : Capture} :
      q.view = (.app (.raise T E') [v]) →
      SplitAt .fail k k1 hcap [.fail E body] k2 → μ κ = none →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (hcap.extendMany [v, .loc κ]) (body.substTy [T] [])) (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap [.fail E body]]))))
  
  | E_OpPrim {b ts es rs ws k μ s k1 h k2 c κ} {q : Closure} {hcap : Capture} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) →
      SplitAt (.prim b) k k1 hcap h k2 → findClause h (.prim b) = some c → μ κ = none →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts [])) (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
  | E_Resume {κ v k μ k'} {q : Closure} :
      q.view = (.resume (.loc κ) v) →
      μ κ = some (.cont k') →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) (k' ++ k) (μ.set κ .used))
  | E_ResumeErr {κ v k μ} {q : Closure} :
      q.view = (.resume (.loc κ) v) →
      μ κ = some .used →
      Step P B σ (.run q k μ) none (.error [rResume] k μ)
  | E_Drop {v κ k μ} {q : Closure} :
      q.view = (.ret v) →
      μ κ = some .used →
      Step P B σ (.run q (.drop κ :: k) μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_DropRel {v κ k μ k'} {q : Closure} :
      q.view = (.ret v) →
      μ κ = some (.cont k') →
      Step P B σ (.run q (.drop κ :: k) μ) none
        (.run (Closure.pure (.ret v)) (releases k' ++ k) (μ.set κ .used))
  
  | E_EscDrop {v κ k μ} {q : Closure} :
      q.view = (.escape v) →
      μ κ = some .used →
      Step P B σ (.run q (.drop κ :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscDropRel {v κ k μ k'} {q : Closure} :
      q.view = (.escape v) →
      μ κ = some (.cont k') →
      Step P B σ (.run q (.drop κ :: k) μ) none
        (.run (Closure.pure (.escape v)) (releases k' ++ k) (μ.set κ .used))
  | E_ErrDrop {rs κ k μ} :
      μ κ = some .used → Step P B σ (.error rs (.drop κ :: k) μ) none (.error rs k μ)
  | E_ErrDropRel {rs κ k μ k'} :
      μ κ = some (.cont k') →
      Step P B σ (.error rs (.drop κ :: k) μ) none (.error rs (releases k' ++ k) (μ.set κ .used))
  | E_ExitDrop {n rs κ k μ} :
      μ κ = some .used → Step P B σ (.exit n rs (.drop κ :: k) μ) none (.exit n rs k μ)
  | E_ExitDropRel {n rs κ k μ k'} :
      μ κ = some (.cont k') →
      Step P B σ (.exit n rs (.drop κ :: k) μ) none (.exit n rs (releases k' ++ k) (μ.set κ .used))

inductive Steps (P : Program) (B : Builtins) (σ : PathEnv) : State → List Event → State → Prop
  | nil {s} : Steps P B σ s [] s
  | cons {s t u label events} : Step P B σ s label t → Steps P B σ t events u →
      Steps P B σ s (label.toList ++ events) u

end
end Benitoite.Release.Refinement
