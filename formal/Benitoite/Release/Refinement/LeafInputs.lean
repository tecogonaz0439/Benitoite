import Benitoite.Release.Refinement.StoreReplyLeaves
import Benitoite.Release.Refinement.ComputationInputs
import Benitoite.Release.Refinement.ApplicationInputs
import Benitoite.Release.Refinement.CanonicalCells
import Benitoite.Release.Refinement.ClosureStateLeaves
import Benitoite.Release.Refinement.ControlLeafSelection

/-! # 元の状態・捕捉・宣言から実行葉へ渡す入力 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- fnRefの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.fnRef_contract_inputs {P B σ Eb q k μ f ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.fnRef f ts es) ws) :
    ∃ Ψ R a ec d result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      (P.defs f = some d) ∧
      (NamesWF d.names d.params) ∧
      (Admissible B [] 0 (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Qempty ts es d.eff) ∧
      (SignatureInstance P [] [] d.tel (TypeCtx.kinds d.tparams) ts es) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel d.tel ts es) result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨d,u,h0,h1,h2,h3,core,relation⟩ := hf.inv_fnRef rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) (h3.result) args
  exact ⟨Ψ,R,a,ec,d,result,effects,store,typed,h0,h1,h2,h3,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ f ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.fnRef f ts es) ws) :
    ∃ Ψ, ∃ d : Def, ∃ result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel d.tel ts es) result effects ∧
      ws.length = (instantiatedTel d.tel ts es).arity := by
  obtain ⟨Ψ,R,a,ec,d,result,effects,_,_,_,_,_,_,args,_,_⟩ :=
    state.fnRef_contract_inputs hP hPB hB view
  exact ⟨Ψ,d,result,effects,args,args.length⟩

/-- opの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.op_contract_inputs {P B σ Eb q k μ o ts ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.op o ts) ws) :
    ∃ Ψ R a ec od result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      (P.ops o = some od) ∧
      (NamesWF od.names od.params) ∧
      (SatAll B [] ts od.tparams) ∧
      (SignatureInstance P [] [] od.tel (List.replicate od.tparams.length .value) ts []) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel od.tel ts []) result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨od,u,h0,h1,h2,h3,core,relation⟩ := hf.inv_op rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) (h3.result) args
  exact ⟨Ψ,R,a,ec,od,result,effects,store,typed,h0,h1,h2,h3,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ o ts ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.op o ts) ws) :
    ∃ Ψ, ∃ od : OpDecl, ∃ result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel od.tel ts []) result effects ∧
      ws.length = (instantiatedTel od.tel ts []).arity := by
  obtain ⟨Ψ,R,a,ec,od,result,effects,_,_,_,_,_,_,args,_,_⟩ :=
    state.op_contract_inputs hP hPB hB view
  exact ⟨Ψ,od,result,effects,args,args.length⟩

/-- lamの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.lam_contract_inputs {P B σ Eb q k μ ns ps body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.lam ns ps body) ws) :
    ∃ Ψ R a ec r ε result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      (NamesWF ns ps) ∧
      (Ty.WF 0 0 0 (.fn ns ps r ε)) ∧
      (Ty.Sorted [] (.fn ns ps r ε)) ∧
      (HasTypeCQ P B (hideBuilders Ψ) Qempty [] (bindParams (hideConts []) ps) (liftMany ps.length [])
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) []) ∧
      (Ty.Declared P [] [] (.fn ns ps r ε)) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (Ty.toTel ns ps r ε) result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨r,ε,u,h0,h1,h2,h3,h4,core,relation⟩ := hf.inv_lam rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) ((show Ty.Annotation P [] [] (.fn ns ps r ε) from ⟨h1,h2,h4⟩).toTel) args
  exact ⟨Ψ,R,a,ec,r,ε,result,effects,store,typed,h0,h1,h2,h3,h4,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ ns ps body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.lam ns ps body) ws) :
    ∃ Ψ r ε result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (Ty.toTel ns ps r ε) result effects ∧
      ws.length = (Ty.toTel ns ps r ε).arity := by
  obtain ⟨Ψ,R,a,ec,r,ε,result,effects,_,_,_,_,_,_,_,args,_,_⟩ :=
    state.lam_contract_inputs hP hPB hB view
  exact ⟨Ψ,r,ε,result,effects,args,args.length⟩

/-- dependentLamの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.dependentLam_contract_inputs {P B σ Eb q k μ t body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.dependentLam t body) ws) :
    ∃ Ψ R a ec result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      (Ty.Annotation P [] [] (.dependentFn t)) ∧
      (TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts []) [] t body) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨u,h0,h1,core,relation⟩ := hf.inv_dependentLam rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) (h0) args
  exact ⟨Ψ,R,a,ec,result,effects,store,typed,h0,h1,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ t body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.dependentLam t body) ws) :
    ∃ Ψ result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t result effects ∧
      ws.length = t.arity := by
  obtain ⟨Ψ,R,a,ec,result,effects,_,_,_,_,args,_,_⟩ :=
    state.dependentLam_contract_inputs hP hPB hB view
  exact ⟨Ψ,result,effects,args,args.length⟩

/-- closureの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.closure_contract_inputs {P B σ Eb q k μ runtime body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.closure runtime body) ws) :
    ∃ Ψ R a ec t result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      Ty.Annotation P [] [] (.dependentFn t) ∧
      Tel.RuntimeShape runtime t ∧
      DependentClosureTy P B Ψ body t ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨t,u,h0,h1,h2,core,relation⟩ := hf.inv_closure rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) (h0) args
  exact ⟨Ψ,R,a,ec,t,result,effects,store,typed,h0,h1,h2,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ runtime body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.closure runtime body) ws) :
    ∃ Ψ t result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t result effects ∧
      ws.length = t.arity := by
  obtain ⟨Ψ,R,a,ec,t,result,effects,_,_,_,_,_,args,_,_⟩ :=
    state.closure_contract_inputs hP hPB hB view
  exact ⟨Ψ,t,result,effects,args,args.length⟩

/-- raiseの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.raise_contract_inputs {P B σ Eb q k μ t e ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.raise t e) ws) :
    ∃ Ψ R a ec result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      (Ty.Annotation P [] [] (.fn ["error"] [e] t (Eff.singleFail e))) ∧
      (Ordinary t) ∧
      (Ordinary e) ∧
      (t.HasKind P (TypeCtx.kinds []) .value) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (Ty.toTel ["error"] [e] t (Eff.singleFail e)) result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨u,h0,h1,h2,h3,core,relation⟩ := hf.inv_raise rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) (h0.toTel) args
  exact ⟨Ψ,R,a,ec,result,effects,store,typed,h0,h1,h2,h3,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ t e ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.raise t e) ws) :
    ∃ Ψ result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (Ty.toTel ["error"] [e] t (Eff.singleFail e)) result effects ∧
      ws.length = (Ty.toTel ["error"] [e] t (Eff.singleFail e)).arity := by
  obtain ⟨Ψ,R,a,ec,result,effects,_,_,_,_,_,_,args,_,_⟩ :=
    state.raise_contract_inputs hP hPB hB view
  exact ⟨Ψ,result,effects,args,args.length⟩

/-- externalRefの同じ実開始から、元契約へ実引数を戻す。 -/
theorem StateTyE.externalRef_contract_inputs {P B σ Eb q k μ f ts ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.externalRef f ts) ws) :
    ∃ Ψ R a ec d result effects, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a ec ∧
      P.externalFunction f = some d ∧
      d.WF P ∧
      ExternalCallAdmissible P B [] d ts ∧
      SignatureInstance P [] [] d.parameters d.kinds ts [] ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel d.parameters ts []) result effects ∧
      Ty.LeQ P [] [] result a ∧ Eff.Covers [] [] ec effects := by
  obtain ⟨Ψ,R,a,ec,target,r0,e0,store,typed,hf,_,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨d,u,h0,h1,h2,h3,core,relation⟩ := hf.inv_externalRef rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) (h3.result) args
  exact ⟨Ψ,R,a,ec,d,result,effects,store,typed,h0,h1,h2,h3,original,step.trans le,cov.trans cover⟩

example {P B σ Eb q k μ f ts ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.externalRef f ts) ws) :
    ∃ Ψ, ∃ d : ExternalSignature, ∃ result effects,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel d.parameters ts []) result effects ∧
      ws.length = (instantiatedTel d.parameters ts []).arity := by
  obtain ⟨Ψ,R,a,ec,d,result,effects,_,_,_,_,_,_,args,_,_⟩ :=
    state.externalRef_contract_inputs hP hPB hB view
  exact ⟨Ψ,d,result,effects,args,args.length⟩

/-- 依存列の引数を順に束縛した元本体の、直接の開始入力。 -/
theorem TelBodyTy.inputs {P B Ψ Q C Γ Φ t body}
    (h : TelBodyTy P B Ψ Q C Γ Φ t body) :
    body.Inputs P B Ψ Q C (t.context Γ) (liftMany t.arity Φ)
      (some t.result) t.result t.effect [] := by
  match h with
  | .done hb => exact hb.inputs
  | .param (rest := rest) hb =>
    have hi := hb.inputs
    simpa only [Tel.context,Tel.arity,Tel.names,List.length_cons,Tel.result,Tel.effect,
      ←liftMany_one,liftMany_add,Nat.add_comm 1] using hi

/-- 宣言の注釈から得た文脈の形成と、同じ元本体の入力。 -/
theorem Def.WellTyped.inputs {P B d} (h : Def.WellTyped P B d) :
    Ctx.Regular P d.tparams (d.tel.context []) ∧
    d.body.Inputs P B StoreTy.empty (QTel d.tel) d.tparams
      (d.tel.context []) (liftMany d.tel.arity [])
      (some d.tel.result) d.tel.result d.tel.effect [] :=
  ⟨Tel.regular_context (Ctx.Regular.empty P d.tparams) h.2.2.1,h.2.2.2.inputs⟩

/-- 実装宣言の同じメソッドを取り出し、辞書と引数を束縛した入力を返す。 -/
theorem ImplDecl.WellTyped.method_inputs {P B id}
    (h : ImplDecl.WellTyped P B id) {cd m ms}
    (hc : P.classes id.cls = some cd) (hm : cd.methods m = some ms) :
    let C := ms.tparams ++ TypeCtx.values id.tparams
    let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
    let t := Tel.shiftV id.dictTys.length 0
      (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)
    ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      body.Inputs P B StoreTy.empty (Qsig ms.params ms.ret ms.eff) C
        (t.context Γ) (liftMany t.arity []) (some t.result) t.result t.effect [] := by
  obtain ⟨body,hbody,names,hb⟩ := h.method_body hc hm
  exact ⟨body,hbody,names,hb.inputs⟩

/-- 元コードの各構文の直接前提と、実行用の局所参照の解決を同じ証人で保つ。 -/
def Closure.Inputs (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty)
    (q : Closure) (a : Ty) (e : Eff) : Prop :=
  ∃ cap Γ Φ Rs, ∃ source : Comp, ∃ as es L ρ,
    q = .mk cap (source.resolveLocals ρ) ∧ CaptureOk P B Ψ R Γ Φ cap ∧
    CaptureContextRegular P [] Γ ∧ source.Inputs P B Ψ Qempty [] Γ Φ Rs as es L ∧
    CaptureLocals Ψ cap.env L ρ ∧ cap.closeR Rs = R ∧
    cap.closeTy as = a ∧ cap.closeEff es = e ∧
    (∀ r, Rs = some r → r.Declared P [] Γ)

/-- 完全なCtx.WFを捕捉元に仮定せず、元のClosureTyから直接前提を取り出す。 -/
theorem ClosureTy.inputs {P B Ψ R q a e} (h : ClosureTy P B Ψ [] R q a e) :
    q.Inputs P B Ψ R a e := by
  obtain ⟨cap,Γ,Φ,Rs,source,as,es,L,ρ,hq,hc,hb,hl,hr,ha,he,hd⟩ := h.open_zero
  exact ⟨cap,Γ,Φ,Rs,source,as,es,L,ρ,hq,hc,hc.contextRegular,hb.inputs,hl,hr,ha,he,hd⟩

/-- 四つの状態の入力。現在の本体は各構文の直接前提へ分解する。 -/
def State.Inputs (P : Program) (B : Builtins) (σ : PathEnv) (Eb : Eff) : State → Prop
  | .run q k μ => ∃ Ψ R a b e ec,
      StoreOk P B σ Ψ μ ∧ q.Inputs P B Ψ R a ec ∧ Eff.Sub ec e ∧
      ContTy P B σ Ψ R e k a b Eb none ∧ q.Adequate σ ∧ q.ClosedAt 0 ∧ k.Closed ∧ μ.Closed
  | .matchRun v cap arms next k μ => ∃ Ψ R a b e ec,
      StoreOk P B σ Ψ μ ∧
      (∃ source, v = closeVal cap source ∧
        (Closure.mk cap (.match source arms)).Inputs P B Ψ R a ec) ∧
      Eff.Sub ec e ∧ ContTy P B σ Ψ R e k a b Eb none ∧ v.Adequate σ ∧
      cap.Adequate σ ∧ MatchPrefix v arms next ∧ v.Ground ∧ adequateArms σ arms ∧
      (cap.Closed ∧ Arm.ClosedList 0 cap.values.length arms) ∧ k.Closed ∧ μ.Closed
  | .error _ k μ | .exit _ _ k μ => ∃ Ψ R a b e,
      StoreOk P B σ Ψ μ ∧ ContTy P B σ Ψ R e k a b Eb none ∧ k.Closed ∧ μ.Closed

/-- 同じ全状態から、保存している捕捉・継続・セルと各構文の入力を供給する。 -/
theorem StateTyE.inputs {P B σ Eb s} (h : StateTyE P B σ Eb s) :
    s.Inputs P B σ Eb := by
  cases s with
  | run q k μ =>
    obtain ⟨Ψ,R,a,b,e,ec,store,hq,sub,hk,ha,hc,hkc,hμ⟩ := h
    exact ⟨Ψ,R,a,b,e,ec,store,hq.inputs,sub,hk,ha,hc,hkc,hμ⟩
  | matchRun v cap arms next k μ =>
    obtain ⟨Ψ,R,a,b,e,ec,store,⟨source,hv,hq⟩,sub,hk,ha,hcap,hp,hg,har,hc,hkc,hμ⟩ := h
    exact ⟨Ψ,R,a,b,e,ec,store,⟨source,hv,hq.inputs⟩,sub,hk,ha,hcap,hp,hg,har,hc,hkc,hμ⟩
  | error => exact h
  | exit => exact h

/-- 通常の宣言本体のappも、元本体と文脈の形成を同時に読む。 -/
example {P B d} (h : Def.WellTyped P B d) :
    Ctx.WF 0 d.tparams.length (d.tel.context []) ∧
    d.body.Inputs P B StoreTy.empty (QTel d.tel) d.tparams
      (d.tel.context []) (liftMany d.tel.arity [])
      (some d.tel.result) d.tel.result d.tel.effect [] :=
  ⟨h.inputs.1.wf,h.inputs.2⟩

example {P B id cd m ms} (h : ImplDecl.WellTyped P B id)
    (hc : P.classes id.cls = some cd) (hm : cd.methods m = some ms) :
    let C := ms.tparams ++ TypeCtx.values id.tparams
    let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
    let t := Tel.shiftV id.dictTys.length 0
      (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)
    ∃ body, id.methods m = some body ∧
      body.Inputs P B StoreTy.empty (Qsig ms.params ms.ret ms.eff) C
        (t.context Γ) (liftMany t.arity []) (some t.result) t.result t.effect [] := by
  obtain ⟨body,hbody,_,input⟩ := h.method_inputs hc hm
  exact ⟨body,hbody,input⟩

/-- 全開始の入力は、同じ状態の実ストアを保持する。 -/
example {P B σ Eb q k μ} (h : StateTyE P B σ Eb (.run q k μ)) :
    ∃ Ψ R a e, StoreOk P B σ Ψ μ ∧ q.Inputs P B Ψ R a e := by
  obtain ⟨Ψ,R,a,_,_,ec,store,input,_⟩ := h.inputs
  exact ⟨Ψ,R,a,ec,store,input⟩

/-- matchRunが保持する同じ値・元の腕・観測・網羅性を返す。 -/
theorem StateTyE.match_inputs {P B σ Eb v cap arms next k μ}
    (h : StateTyE P B σ Eb (.matchRun v cap arms next k μ)) :
    ∃ Ψ R Γ Φ Rs root obs arms0 input result effects L ρ,
      StoreOk P B σ Ψ μ ∧ CaptureOk P B Ψ R Γ Φ cap ∧
      HasTypeV P B Ψ [] Γ Φ root input ∧
      (∀ t, obs = some t → Val.toTerm? root = some t ∧ ∃ sort, t.HasSort Γ sort) ∧
      HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms0 input result effects L ∧
      Exhaustive P input (unguardedPats arms0) ∧ CaptureLocals Ψ cap.env L ρ ∧
      arms = Arm.resolveLocalsList ρ arms0 ∧ v = closeVal cap root ∧ cap.closeR Rs = R := by
  obtain ⟨Ψ,R,a,b,e,ec,store,⟨vs,hv,hq⟩,_⟩ := h
  obtain ⟨Γ,Φ,Rs,root,obs,arms0,input,result,effects,L,ρ,hcap,ht,ho,hars,hL,hea,hroot,hR,_,_,_,hx⟩ :=
    hq.match_source
  rw [hroot] at hv
  exact ⟨Ψ,R,Γ,Φ,Rs,root,obs,arms0,input,result,effects,L,ρ,
    store,hcap,ht,ho,hars,hx,hL,hea,hv,hR⟩

example {P B σ Eb v cap arms next k μ}
    (h : StateTyE P B σ Eb (.matchRun v cap arms next k μ)) :
    ∃ Ψ R Γ Φ Rs root obs arms0 input result effects L,
      CaptureOk P B Ψ R Γ Φ cap ∧
      (∀ t, obs = some t → Val.toTerm? root = some t ∧ ∃ sort, t.HasSort Γ sort) ∧
      HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms0 input result effects L ∧
      Exhaustive P input (unguardedPats arms0) := by
  obtain ⟨Ψ,R,Γ,Φ,Rs,root,obs,arms0,input,result,effects,L,_,_,hc,_,ho,ha,hx,_⟩ := h.match_inputs
  exact ⟨Ψ,R,Γ,Φ,Rs,root,obs,arms0,input,result,effects,L,hc,ho,ha,hx⟩

private theorem ClosureTy.ite_value {P B Ψ R q a e v m n}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (h : ClosureTy P B Ψ [] R q a e) (view : q.view = .ite v m n) :
    ∃ b, v = .const (.boolean b) := by
  obtain ⟨cap,Γ,Φ,Rs,source,as,es,L,ρ,rfl,hc,hb,_,_,_,_,_⟩ := h.open_zero
  cases source
  case ite v0 m0 n0 =>
    obtain ⟨_,hv,_,_⟩ := hb.ite_branch rfl true
    have typed := close_value_typed hP hPB hB hw hs hd hc hv
    obtain ⟨b,he⟩ := typed.canonical_boolean rfl
    simp only [Comp.resolveLocals,Closure.view,HasTypeVQ.resolve_id hv ρ] at view
    obtain ⟨hv,_,_⟩ := Comp.ite.inj view
    exact ⟨b,hv.symm.trans he⟩
  case checkAt k o sh bs p v ix =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view] at view; injection view)
  all_goals (simp only [Comp.resolveLocals,Closure.view] at view; injection view)

/-- 任意の型付きifからBooleanの実形を得て、同じ捕捉の選択枝へ供給する。 -/
theorem StateTyE.if_inputs {P B σ Eb q k μ v m n}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .ite v m n) :
    ∃ b, v = .const (.boolean b) ∧
      (State.run (.mk q.capture (if b then m else n)) k μ).Inputs P B σ Eb := by
  have start := h
  obtain ⟨Ψ,R,a,c,e,ec,store,hq,_⟩ := start
  obtain ⟨b,hv⟩ := hq.ite_value hP hPB hB store.wf store.sorted store.declared view
  refine ⟨b,hv,?_⟩
  rw [hv] at view
  exact (h.if_selected b view).inputs

example {P B σ Eb q k μ v m n}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .ite v m n) :
    (v = .const (.boolean true) ∧ (State.run (.mk q.capture m) k μ).Inputs P B σ Eb) ∨
    (v = .const (.boolean false) ∧ (State.run (.mk q.capture n) k μ).Inputs P B σ Eb) := by
  obtain ⟨b,hv,hs⟩ := h.if_inputs hP hPB hB view
  cases b
  · exact Or.inr ⟨hv,hs⟩
  · exact Or.inl ⟨hv,hs⟩

private theorem Tel.SameInputs.arity_eq {t u : Tel} (h : t.SameInputs u) : t.arity = u.arity := by
  cases t with
  | done => cases u <;> simp_all [Tel.SameInputs,Tel.arity,Tel.names]
  | param n a t =>
    cases u with
    | done => cases h
    | param m b u =>
      obtain ⟨rfl,rfl,tail⟩ := h
      simpa only [Tel.arity,Tel.names,List.length_cons] using congrArg Nat.succ (arity_eq tail)
termination_by structural t

/-- 型付き実開始から閉じたlambdaの個数を導き、同じ行先の入力を供給する。 -/
theorem StateTyE.lambda_inputs {P B σ Eb q k μ f runtime body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app f ws)
    (closed : closeVal Capture.empty f = .closure runtime body) :
    Step P B σ (.run q k μ) none (.run (body.apply ws) (markPush k) μ) ∧
      (State.run (body.apply ws) (markPush k) μ).Inputs P B σ Eb := by
  obtain ⟨Ψ,R,a,ec,t,r,e,store,_,hf,_,args,_,_⟩ := state.app_inputs hP hPB hB view
  have typed := hf.close_empty_typed hP hPB hB store.wf store.sorted store.declared
  obtain ⟨u,target,ha,shape,_,core,relation⟩ := typed.inv_closure closed
  cases Option.some.inj core
  obtain ⟨_,_,original,_⟩ := relation.apply (by intro i a hi; cases hi) ha args
  have hlen := original.length.trans shape.inputs.arity_eq.symm
  obtain ⟨step,next⟩ := state.lambda_beta_all hP hPB hB view closed hlen
  exact ⟨step,next.inputs⟩

example {P B σ Eb q k μ ns ps body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.lam ns ps body) ws) :
    ∃ dest, Step P B σ (.run q k μ) none dest ∧ dest.Inputs P B σ Eb := by
  exact ⟨_,state.lambda_inputs hP hPB hB view rfl⟩

example {P B σ Eb q k μ t body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.dependentLam t body) ws) :
    ∃ dest, Step P B σ (.run q k μ) none dest ∧ dest.Inputs P B σ Eb := by
  exact ⟨_,state.lambda_inputs hP hPB hB view rfl⟩

example {P B σ Eb q k μ t body ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.closure t body) ws) :
    Step P B σ (.run q k μ) none (.run (body.apply ws) (markPush k) μ) ∧
      (State.run (body.apply ws) (markPush k) μ).Inputs P B σ Eb :=
  state.lambda_inputs hP hPB hB view rfl

/-- guard枠の先頭では、同じopの元実引数列の効果が空行に被覆される。 -/
theorem StateTyE.guard_op_inputs {P B σ Eb q k μ o ts ws v cap arms next body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q (.guardF v cap arms next body :: k) μ))
    (view : q.view = .app (.op o ts) ws) :
    ∃ Ψ od result effects, P.ops o = some od ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel od.tel ts []) result effects ∧
      Eff.Covers [] [] Eff.empty effects := by
  obtain ⟨Ψ,R,a,b,e,ec,store,typed,sub,hk,_⟩ := state
  obtain ⟨_,rfl⟩ := hk.guard_effect rfl
  have closed := typed.app_view_typed hP hPB hB store.wf store.sorted store.declared view
  have reg : CaptureContextRegular P [] [] := by
    constructor <;> (intro i a hi; cases hi)
  obtain ⟨t,r,ef,hf,args,le,cov⟩ := closed.app_tel rfl store.wf store.sorted store.declared reg
  obtain ⟨od,u,hd,_,_,inst,core,relation⟩ := hf.inv_op rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,_,cover⟩ := relation.apply
    (by intro i a hi; cases hi) inst.result args
  exact ⟨Ψ,od,result,effects,hd,original,(sub.covers.trans cov).trans cover⟩

example {P B σ Eb q k μ o ts ws v cap arms next body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q (.guardF v cap arms next body :: k) μ))
    (view : q.view = .app (.op o ts) ws) :
    ∃ Ψ od result effects, P.ops o = some od ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel od.tel ts []) result effects ∧
      ∀ atom, ¬ Eff.mem effects atom := by
  obtain ⟨Ψ,od,result,effects,hd,args,cov⟩ := state.guard_op_inputs hP hPB hB view
  refine ⟨Ψ,od,result,effects,hd,args,?_⟩
  intro atom hm
  obtain ⟨other,ho,_⟩ := cov.1 atom hm
  cases other <;> simp [Eff.mem,Eff.test,Eff.empty,Eff.atoms] at ho

private def CallInputs (P : Program) (B : Builtins) (f : Val) (ws : List Val) : Prop :=
  ∃ Ψ t r e, HasTypeVQ P B Ψ Qempty [] [] [] f (.dependentFn t) ∧
    Ty.Annotation P [] [] (.dependentFn t) ∧ HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t r e

private theorem call_inputs {P B σ Eb q k μ f ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app f ws) :
    CallInputs P B f ws := by
  obtain ⟨Ψ,_,_,_,t,r,e,_,_,hf,ha,args,_,_⟩ := h.app_inputs hP hPB hB view
  exact ⟨Ψ,t,r,e,hf,ha,args⟩

/-- let_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ m n}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .letIn m n) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ)).Inputs P B σ Eb := by
  have next := (StateTyE.let_step h hv).2
  exact ⟨h.inputs,next.inputs⟩

/-- return_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ n v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (hview : q.view = .ret v) :
    ((State.run q (.letF n :: k) μ)).Inputs P B σ Eb ∧ ((State.run (n.apply [v]) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((n.apply [v])).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.return_step hP hPB hB h hview).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- mark_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (hview : q.view = .ret v) :
    ((State.run q (.mark :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.ret v))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.mark_step hP hPB hB h hview).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- fun_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hws : ws.length = d.params.length) (hts : ts.length = d.ntys) (hes : es.length = d.neffs) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk (Capture.empty.extendMany ws) (d.body.substTy ts es))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.fun_step hP hPB hB h hv hd hws hts hes).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- method_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ i us vs name ss es ws id cd ms body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .meth (.dict i us vs) name ss es ws)
    (hid : P.impls i = some id) (hbody : id.methods name = some body)
    (hcl : P.classes id.cls = some cd) (hm : cd.methods name = some ms)
    (hws : ws.length = ms.params.length) (hvs : vs.length = id.dictTys.length)
    (hus : us.length = id.tparams.length) (hss : ss.length = ms.tparams.length)
    (hes : es.length = ms.neffs) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.method_step hP hPB hB h hv hid hbody hcl hm hws hvs hus hss hes).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- super_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ v w name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .meth v name ss es ws) (hstep : v.superStep P = some w) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.meth w name ss es ws)) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.meth w name ss es ws))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.super_step hP hPB hB h hv hstep).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- if_selectedが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ m n} (b : Bool)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .ite (.const (.boolean b)) m n) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk q.capture (if b then m else n)) k μ)).Inputs P B σ Eb := by
  have next := StateTyE.if_selected b h hv
  exact ⟨h.inputs,next.inputs⟩

/-- match_startが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ v arms}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .match v arms) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.matchRun v q.capture arms 0 k μ)).Inputs P B σ Eb := by
  have next := StateTyE.match_start h hv
  exact ⟨h.inputs,next.inputs⟩

/-- match_skipが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb v cap arms n alts guard body k μ}
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts guard body)) (hf : firstAlt v alts = none) :
    ((State.matchRun v cap arms n k μ)).Inputs P B σ Eb ∧ ((State.matchRun v cap arms (n+1) k μ)).Inputs P B σ Eb := by
  have next := StateTyE.match_skip h hi hf
  exact ⟨h.inputs,next.inputs⟩

/-- guard_trueが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q v cap arms next body k μ}
    (hA : Builtins.SubstitutionAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.guardF v cap arms next body :: k) μ))
    (hv : q.view = .ret (.const (.boolean true))) :
    ((State.run q (.guardF v cap arms next body :: k) μ)).Inputs P B σ Eb ∧ ((State.run body k μ)).Inputs P B σ Eb := by
  have next := StateTyE.guard_true hA h hv
  exact ⟨h.inputs,next.inputs⟩

/-- guard_falseが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q v cap arms next body k μ}
    (h : StateTyE P B σ Eb (.run q (.guardF v cap arms next body :: k) μ))
    (_hv : q.view = .ret (.const (.boolean false))) :
    ((State.run q (.guardF v cap arms next body :: k) μ)).Inputs P B σ Eb ∧ ((State.matchRun v cap arms next k μ)).Inputs P B σ Eb := by
  have next := StateTyE.guard_false h _hv
  exact ⟨h.inputs,next.inputs⟩

/-- match_bodyが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb v cap arms n alts body ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts none body)) (hm : firstAlt v alts = some ws) :
    ((State.matchRun v cap arms n k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (cap.extendMany ws) body) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk (cap.extendMany ws) body)).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := StateTyE.match_body hP hPB hB h hi hm
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- match_guardが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb v cap arms n alts guard body ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts (some guard) body)) (hm : firstAlt v alts = some ws) :
    ((State.matchRun v cap arms n k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (cap.extendMany ws) guard)
      (.guardF v cap arms (n+1) (.mk (cap.extendMany ws) body) :: k) μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk (cap.extendMany ws) guard)).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := StateTyE.match_guard hP hPB hB h hi hm
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- err_pop_guardが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb rs v cap arms n body k μ}
    (h : StateTyE P B σ Eb (.error rs (.guardF v cap arms n body :: k) μ)) :
    ((State.error rs (.guardF v cap arms n body :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := StateTyE.err_pop_guard h
  exact ⟨h.inputs,next.inputs⟩

/-- exit_pop_guardが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb code rs v cap arms n body k μ}
    (h : StateTyE P B σ Eb (.exit code rs (.guardF v cap arms n body :: k) μ)) :
    ((State.exit code rs (.guardF v cap arms n body :: k) μ)).Inputs P B σ Eb ∧ ((State.exit code rs k μ)).Inputs P B σ Eb := by
  have next := StateTyE.exit_pop_guard h
  exact ⟨h.inputs,next.inputs⟩

/-- lazy_transitionが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q m k μ l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .lazyC m) (hl : μ l = none) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (.mk q.capture m))))).Inputs P B σ Eb := by
  have next := (StateTyE.lazy_transition hA h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- force_thunk_allが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q b ts es rs l k μ s m}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.thunk m)) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run m (.update l::k) μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, (m).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.force_thunk_all hP hPB hB h hv hs hk hl).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- force_done_allが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q b ts es rs l k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.done v)) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.ret v))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.force_done_all hP hPB hB h hv hs hk hl).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- lazy_update_allが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.update l::k) μ)) (hv : q.view = .ret v) :
    ((State.run q (.update l::k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k (μ.set l (.done v)))).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.ret v))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.lazy_update_all hP hPB hB h hv).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- escape_markが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (hv : q.view = .escape v) :
    ((State.run q (.mark :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.ret v))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.escape_mark hP hPB hB h hv).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- handle_stepが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q k μ m cs}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .handle m cs) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk q.capture m) (.handleF q.capture cs :: k) μ)).Inputs P B σ Eb := by
  have next := StateTyE.handle_step hB h hv
  exact ⟨h.inputs,next.inputs⟩

/-- use_allが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q v m k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .use v m) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk q.capture m) (.release v :: k) μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk q.capture m)).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := (StateTyE.use_all hP hPB hB h hv).2
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- resume_allが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q l v k μ saved}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .resume (.loc l) v)
    (hl : μ l = some (.cont saved)) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) (saved ++ k) (μ.set l .used))).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.ret v))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := StateTyE.resume_all hP hPB hB h hv hl
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- handler_returnが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q v cap cs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ)) (hv : q.view = .ret v) :
    ((State.run q (.handleF cap cs :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k μ)).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.pure (.ret v))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := StateTyE.handler_return hP hPB hB h hv
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- operation_allが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q o ts ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.op o ts) ws)
    (hsp : SplitAt (.user o) k k1 hcap cs k2) (hc : findClause cs (.user o) = some c)
    (hf : μ l = none) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs]))))).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := StateTyE.operation_all hP hPB hB h hv hsp hc hf
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- operation_failureが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q T E0 v k μ k1 E body k2 l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.raise T E0) [v])
    (hsp : SplitAt .fail k k1 hcap [.fail E body] k2) (hf : μ l = none) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (hcap.extendMany [v,.loc l]) (body.substTy [T] []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap [.fail E body]]))))).Inputs P B σ Eb ∧ (∀ callee callArgs, ((Closure.mk (hcap.extendMany [v,.loc l]) (body.substTy [T] []))).view = .app callee callArgs → CallInputs P B callee callArgs) := by
  have next := StateTyE.operation_failure hP hPB hB h hv hsp hf
  exact ⟨h.inputs,next.inputs,fun callee callArgs view => call_inputs hP hPB hB next view⟩

/-- builder_newが選んだ同じ開始に、構文ごとの入力を供給する。 -/
example {P B σ Eb q kind body k μ l}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderLet kind body) (hl : μ l = none) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty)))).Inputs P B σ Eb := by
  have next := (StateTyE.builder_new hB h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- builder_operationの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q kind op l args k μ c c' v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op (.loc l) args)
    (hl : μ l = some (.builder c)) (hr : builderApply op c args = some (.value c' v)) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k (μ.set l (.builder c')))).Inputs P B σ Eb := by
  have next := (StateTyE.builder_operation hP hPB hB h hv hl hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- builder_errorの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q kind op l args k μ c r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op (.loc l) args)
    (hl : μ l = some (.builder c)) (hr : builderApply op c args = some (.error r)) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.error [r] k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.builder_error h hv hl hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- store_replyの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb s event dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb s) (inputs : StoreReplyInputs P B σ s event dest) :
    (s).Inputs P B σ Eb ∧ (dest).Inputs P B σ Eb := by
  have next := (StateTyE.store_reply hP hPB hB hσ h inputs).2.1
  exact ⟨h.inputs,next.inputs⟩

/-- reference_new_allの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q b ts es rs v k μ s l}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [v])
    (hs : B.sig b = some s) (hk : s.kind = .refNew) (hl : μ l = none) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))).Inputs P B σ Eb := by
  have next := (StateTyE.reference_new_all hP hPB hB h hv hs hk hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- reference_get_allの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q b ts es rs l k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .refGet) (hl : μ l = some (.val v)) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.reference_get_all hP hPB hB h hv hs hk hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- reference_set_allの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q b ts es rs l v k μ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l,v])
    (hs : B.sig b = some s) (hk : s.kind = .refSet) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))).Inputs P B σ Eb := by
  have next := (StateTyE.reference_set_all hP hPB hB h hv hs hk).2
  exact ⟨h.inputs,next.inputs⟩

/-- reference_update_allの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q b ts es rs l f k μ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l,f])
    (hsig : B.sig b = some s) (hkind : s.kind = .refUpdate) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (·+1)) [.var 0]) (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.reference_update_all hP hPB hB h hv hsig hkind).2
  exact ⟨h.inputs,next.inputs⟩

/-- escape_letの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q v n k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (hv : q.view = .escape v) :
    ((State.run q (.letF n :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.escape v)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.escape_let hP hPB hB h hv).2
  exact ⟨h.inputs,next.inputs⟩

/-- escape_handlerの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q v cap cs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ)) (hv : q.view = .escape v) :
    ((State.run q (.handleF cap cs :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.escape v)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.escape_handler hP hPB hB h hv).2
  exact ⟨h.inputs,next.inputs⟩

/-- return_releaseの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q w v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .ret w) (hr : B.releaseResponse v none) :
    ((State.run q (.release v :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret w)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.return_release hP hPB hB h hv hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- return_release_failureの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q w v k μ r}
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .ret w) (hr : B.releaseResponse v (some r)) :
    ((State.run q (.release v :: k) μ)).Inputs P B σ Eb ∧ ((State.error [r] k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.return_release_failure h hv hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- escape_releaseの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q w v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .escape w) (hr : B.releaseResponse v none) :
    ((State.run q (.release v :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.escape w)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.escape_release hP hPB hB h hv hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- escape_release_failureの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q w v k μ r}
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .escape w) (hr : B.releaseResponse v (some r)) :
    ((State.run q (.release v :: k) μ)).Inputs P B σ Eb ∧ ((State.error [r] k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.escape_release_failure h hv hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- error_letの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs n k μ}
    (h : StateTyE P B σ Eb (.error rs (.letF n :: k) μ)) :
    ((State.error rs (.letF n :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.error_let h).2
  exact ⟨h.inputs,next.inputs⟩

/-- error_markの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs k μ}
    (h : StateTyE P B σ Eb (.error rs (.mark :: k) μ)) :
    ((State.error rs (.mark :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.error_mark h).2
  exact ⟨h.inputs,next.inputs⟩

/-- lazy_update_pop_errorの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs l k μ}
    (h : StateTyE P B σ Eb (.error rs (.update l :: k) μ)) :
    ((State.error rs (.update l :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.lazy_update_pop_error h).2
  exact ⟨h.inputs,next.inputs⟩

/-- error_handlerの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs cap cs k μ}
    (h : StateTyE P B σ Eb (.error rs ((.handleF cap cs) :: k) μ)) :
    ((State.error rs ((.handleF cap cs) :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.error_handler h).2
  exact ⟨h.inputs,next.inputs⟩

/-- error_releaseの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs v k μ}
    (h : StateTyE P B σ Eb (.error rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v none) :
    ((State.error rs ((.release v) :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.error_release h hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- error_release_failureの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs v r k μ}
    (h : StateTyE P B σ Eb (.error rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v (some r)) :
    ((State.error rs ((.release v) :: k) μ)).Inputs P B σ Eb ∧ ((State.error (rs ++ [r]) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.error_release_failure h hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_letの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs n k μ code}
    (h : StateTyE P B σ Eb (.exit code rs (.letF n :: k) μ)) :
    ((State.exit code rs (.letF n :: k) μ)).Inputs P B σ Eb ∧ ((State.exit code rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.exit_let h).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_markの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs k μ code}
    (h : StateTyE P B σ Eb (.exit code rs (.mark :: k) μ)) :
    ((State.exit code rs (.mark :: k) μ)).Inputs P B σ Eb ∧ ((State.exit code rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.exit_mark h).2
  exact ⟨h.inputs,next.inputs⟩

/-- lazy_update_pop_exitの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb n rs l k μ}
    (h : StateTyE P B σ Eb (.exit n rs (.update l :: k) μ)) :
    ((State.exit n rs (.update l :: k) μ)).Inputs P B σ Eb ∧ ((State.exit n rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.lazy_update_pop_exit h).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_handlerの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb n rs cap cs k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.handleF cap cs) :: k) μ)) :
    ((State.exit n rs ((.handleF cap cs) :: k) μ)).Inputs P B σ Eb ∧ ((State.exit n rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.exit_handler h).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_releaseの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb n rs v k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v none) :
    ((State.exit n rs ((.release v) :: k) μ)).Inputs P B σ Eb ∧ ((State.exit n rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.exit_release h hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_release_failureの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb n rs v r k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v (some r)) :
    ((State.exit n rs ((.release v) :: k) μ)).Inputs P B σ Eb ∧ ((State.exit n (rs ++ [r]) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.exit_release_failure h hr).2
  exact ⟨h.inputs,next.inputs⟩

/-- operation_primitiveの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q b s ts es rs ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hdecl : P.EffectsOk B)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases)
    (hsp : SplitAt (.prim b) k k1 hcap cs k2) (hc : findClause cs (.prim b) = some c)
    (hf : μ l = none) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs]))))).Inputs P B σ Eb := by
  have next := (StateTyE.operation_primitive hP hPB hB hdecl h hv hsig hkind hsp hc hf)
  exact ⟨h.inputs,next.inputs⟩

/-- resume_usedの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q l v k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) v) (hl : μ l = some .used) :
    ((State.run q k μ)).Inputs P B σ Eb ∧ ((State.error [rResume] k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.resume_used h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- drop_used_allの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret v) (hl : μ l = some .used) :
    ((State.run q (.drop l :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.drop_used_all hP hPB hB h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- drop_release_allの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q v l k μ saved}
    (hdecl : P.EffectsOk B)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret v) (hl : μ l = some (.cont saved)) :
    ((State.run q (.drop l :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.ret v)) (releases saved ++ k) (μ.set l .used))).Inputs P B σ Eb := by
  have next := (StateTyE.drop_release_all hdecl hP hPB hB h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- escape_drop_usedの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .escape v) (hl : μ l = some .used) :
    ((State.run q (.drop l :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.escape v)) k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.escape_drop_used hP hPB hB h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- escape_drop_releaseの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb q v l k μ saved}
    (hdecl : P.EffectsOk B)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .escape v) (hl : μ l = some (.cont saved)) :
    ((State.run q (.drop l :: k) μ)).Inputs P B σ Eb ∧ ((State.run (Closure.pure (.escape v)) (releases saved ++ k) (μ.set l .used))).Inputs P B σ Eb := by
  have next := (StateTyE.escape_drop_release hdecl hP hPB hB h hv hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- error_dropの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs l k μ}
    (h : StateTyE P B σ Eb (.error rs ((.drop l) :: k) μ))
    (hl : μ l = some .used) :
    ((State.error rs ((.drop l) :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.error_drop h hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- err_drop_relの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb rs l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.error rs (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    ((State.error rs (.drop l :: k) μ)).Inputs P B σ Eb ∧ ((State.error rs (releases saved ++ k) (μ.set l .used))).Inputs P B σ Eb := by
  have next := (StateTyE.err_drop_rel hdecl hA h hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_dropの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb n rs l k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.drop l) :: k) μ))
    (hl : μ l = some .used) :
    ((State.exit n rs ((.drop l) :: k) μ)).Inputs P B σ Eb ∧ ((State.exit n rs k μ)).Inputs P B σ Eb := by
  have next := (StateTyE.exit_drop h hl).2
  exact ⟨h.inputs,next.inputs⟩

/-- exit_drop_relの実開始と同じ行先について、構文ごとの入力を保持する。 -/
example {P B σ Eb n rs l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.exit n rs (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    ((State.exit n rs (.drop l :: k) μ)).Inputs P B σ Eb ∧ ((State.exit n rs (releases saved ++ k) (μ.set l .used))).Inputs P B σ Eb := by
  have next := (StateTyE.exit_drop_rel hdecl hA h hl).2
  exact ⟨h.inputs,next.inputs⟩

end
end Benitoite.Release.Refinement
