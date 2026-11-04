import Benitoite.Release.Refinement.ScopedCallContracts
import Benitoite.Release.Refinement.ScopeModels
import Benitoite.Release.Refinement.ModelHttpApplications
import Benitoite.Release.Refinement.HandlerGeneral

/-! # 同じ実引数と保持対象を使う呼出しと範囲の境界 -/
namespace Benitoite.Release.Refinement.ScopedTargetExamples
noncomputable section
open Scope.Domain

/-- 元の具体化済みの列から、同じ実引数・同じ範囲の全 IO 応答へ進む。 -/
theorem single_io {P B Ψ b sg ts es rs ws a e k p σ u}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (ad : PrimitiveAdmissible [] 0 sg Qempty ts es)
    (ranges : B.RangeAdmissible b sg rs)
    (signature : SignatureInstance P [] [] (Tel.instR rs sg.tel)
      (sg.tparams.map TParamDecl.kind) ts es)
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs sg.tel) ts es) u)
    (arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e)
    (ground : ∀ w ∈ ws, w.Ground) (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ a₀ e₀ r t,
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
      (ws[p]?).bind Val.target? = some t ∧ r.Mem σ k t ∧
      sg.shapeAt ws = .single k p ∧
      (∃ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs) ∧
      ∀ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs →
        obs = [t] ∧ Outcome.Typed P B Ψ out a₀ ∧ AdequateResult ws out ∧
        ∃ l, sg.opEff = some l ∧ ∀ target ∈ obs, Eff.Allows σ B.effKind e l target := by
  have sh := conditions.io_op b sg hs kind
  have names := (conditions.sig_scoped b sg hs).namesWF
  obtain ⟨a₀,e₀,r,t,_,args,le,cov,hr,ht,hm,hshape⟩ :=
    ScopedCallContracts.single_inputs ad ranges signature relation arguments ground sh shape names had
  refine ⟨a₀,e₀,r,t,args,le,cov,hr,ht,hm,hshape,
    conditions.io_exists _ _ _ _ _ _ _ _ _ hs kind args,?_⟩
  intro out obs reply
  have targets := conditions.io_target _ _ _ _ _ _ _ _ _ _ _ hs kind args reply
  rw [hshape] at targets
  obtain ⟨target,harg,hobs⟩ := targets
  cases Option.some.inj (ht.symm.trans harg)
  obtain ⟨typed,adequate⟩ := conditions.io_typed _ _ _ _ _ _ _ _ _ _ _ hs kind args reply
  obtain ⟨l,hl,allowed⟩ := conditions.toTargetAgreement.obs_allowed sh hs kind names args had reply
  exact ⟨hobs,typed,adequate,l,hl,fun target mem => cov.allows (allowed target mem)⟩

/-- 要求の保持二形から元の要求を読み、同じ列を全送信応答へ渡す。 -/
theorem request_io {P B Ψ b sg ts es rs ws a e p σ u A}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single .endpoint p)
    (ad : PrimitiveAdmissible [] 0 sg Qempty ts es)
    (ranges : B.RangeAdmissible b sg rs)
    (signature : SignatureInstance P [] [] (Tel.instR rs sg.tel)
      (sg.tparams.map TParamDecl.kind) ts es)
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs sg.tel) ts es) u)
    (arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e)
    (ground : ∀ w ∈ ws, w.Ground) (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A) :
    ∃ a₀ e₀ r w target req,
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧ ws[p]? = some w ∧
      (w = .checkedRequest target req ∨ ∃ s snapshot, w = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target ∧
      (∃ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs) ∧
      ∀ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs →
        obs = [target] ∧ Outcome.Typed P B Ψ out a₀ ∧ AdequateResult ws out := by
  have sh := conditions.io_op b sg hs kind
  have names := (conditions.sig_scoped b sg hs).namesWF
  obtain ⟨a₀,e₀,r,w,target,req,original,le,cov,hr,hw,_,form,run,typed,hg,hreq,mem⟩ :=
    ScopedCallContracts.request_inputs ad ranges signature relation arguments ground sh shape names had content
  have args := BuiltinArgs.normalized ad ranges signature original ground
  obtain ⟨a₁,e₁,r₁,t,args₁,_,_,_,ht,_,hshape,hexists,all⟩ :=
    single_io conditions hs kind shape ad ranges signature relation arguments ground had
  have he : w.target? = some target := by
    rcases form with rfl | ⟨s,snapshot,rfl⟩ <;> rfl
  rw [hw,Option.bind_some,he] at ht
  cases Option.some.inj ht
  -- 観測の等号は single_io から、型付けは同じ元列の args から得る。
  refine ⟨a₀,e₀,r,w,target,req,args,le,cov,hr,hw,form,run,typed,hg,hreq,mem,hexists,?_⟩
  intro out obs reply
  have safe := conditions.io_typed _ _ _ _ _ _ _ _ _ _ _ hs kind args reply
  exact ⟨(all out obs reply).1,safe⟩

/-- 同じ入力位置の値と応答の観測を照合する。格納元の形には依存しない。 -/
theorem selected_io {P B Ψ b sg ts es rs ws a e k p σ v}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) (selected : ws[p]? = some v) :
    ∃ r t, rs = [r] ∧ v.target? = some t ∧ r.Mem σ k t ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [t] := by
  have sh := conditions.io_op b sg hs kind
  obtain ⟨r,t,hr,ht,hm,hshape⟩ := sh.single_target shape
    (conditions.sig_scoped b sg hs).namesWF args had
  refine ⟨r,t,hr,by simpa only [selected,Option.bind_some] using ht,hm,
    conditions.io_exists _ _ _ _ _ _ _ _ _ hs kind args,?_⟩
  intro out obs reply
  have all := conditions.io_target _ _ _ _ _ _ _ _ _ _ _ hs kind args reply
  rw [hshape] at all
  obtain ⟨t',ht',hobs⟩ := all
  cases Option.some.inj (ht.symm.trans ht')
  exact hobs

/-- 任意の保持元から同じ値を選んだ送信は、同じ要求・端点と全観測を持つ。 -/
theorem selected_request {P B Ψ b sg ts es rs ws a e p σ v A}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single .endpoint p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) (selected : ws[p]? = some v)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A) :
    ∃ r target req, rs = [r] ∧
      (v = .checkedRequest target req ∨ ∃ s snapshot, v = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [v] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [target] := by
  have sh := conditions.io_op b sg hs kind
  obtain ⟨r,w,target,req,hr,hw,_,form,run,typed,hg,ht,hm⟩ :=
    sh.single_request shape (conditions.sig_scoped b sg hs).namesWF args had content
  cases Option.some.inj (selected.symm.trans hw)
  obtain ⟨r',target',_,held,_,hexists,all⟩ := selected_io conditions hs kind shape args had selected
  have he : v.target? = some target := by rcases form with rfl | ⟨s,snapshot,rfl⟩ <;> rfl
  cases Option.some.inj (he.symm.trans held)
  exact ⟨r,target,req,hr,form,run,typed,hg,ht,hm,hexists,all⟩

/-- callback の実際の app は、同じ値列の型付けと全応答を共有する。 -/
example {P B Ψ b sg ts es rs ws a e k p σ u f R}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (callback : HasTypeV P B Ψ [] [] [] f (.dependentFn u))
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs sg.tel) ts es) u)
    (passed : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.app f ws) a e [] ∧
      ∃ a₀ e₀ r t,
        BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a₀ e₀ ∧
        Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
        (ws[p]?).bind Val.target? = some t ∧ r.Mem σ k t ∧
        sg.shapeAt ws = .single k p ∧
        (∃ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs) ∧
        ∀ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs →
          obs = [t] ∧ Outcome.Typed P B Ψ out a₀ ∧ AdequateResult ws out ∧
          ∃ l, sg.opEff = some l ∧ ∀ target ∈ obs, Eff.Allows σ B.effKind e l target :=
  ⟨.C_DependentApp callback passed,
    single_io conditions hs kind shape args.admissible args.ranges args.signature relation passed args.ground had⟩

/-- List 又は ADT の実際の欄と同じ IO 引数を接続する。 -/
example {P B Ψ b sg ts es rs ws a e k p σ vs T v} {i : Nat}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (values : HasTypeEach P B Ψ [] [] [] vs T) (field : vs[i]? = some v)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (selected : ws[p]? = some v) (had : ∀ w ∈ ws, w.Adequate σ) :
    HasTypeV P B Ψ [] [] [] v T ∧ ∃ r t, rs = [r] ∧ v.target? = some t ∧ r.Mem σ k t ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [t] :=
  ⟨values.member (List.mem_of_getElem? field),selected_io conditions hs kind shape args had selected⟩

/-- Reference の実セルの値がそのまま入力位置にある場合を読む。 -/
example {P B σ Ψ μ l T b sg ts es rs ws a e k p}
    (store : StoreOk P B σ Ψ μ) (location : Ψ l = some (.ref T))
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (selected : ∀ v, μ l = some (.val v) → ws[p]? = some v) :
    ∃ v r t, μ l = some (.val v) ∧ HasTypeV P B Ψ [] [] [] v T.norm ∧
      v.Adequate σ ∧ rs = [r] ∧ v.target? = some t ∧ r.Mem σ k t ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [t] := by
  obtain ⟨v,hv,typed,adequate⟩ := store.ref_cell location
  obtain ⟨r,t,h⟩ := selected_io conditions hs kind shape args had (selected v hv)
  exact ⟨v,r,t,hv,typed,adequate,h⟩

/-- 実送信表にも、元の具体化済みの列から同じ要求を渡せる。 -/
example {P Ψ ts es rs ws a e σ u} (hp : ScopeDeclarations.HasHttp P)
    (args : BuiltinArgs P ModelHttp.builtins Ψ "Http.sendIn" ScopeSignatures.sendIn ts es rs ws a e)
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs ScopeSignatures.sendIn.tel) ts es) u)
    (passed : HasTypeTelArgsQ P ModelHttp.builtins Ψ Qempty [] [] [] ws u a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ a₀ e₀ r w target req,
      BuiltinArgs P ModelHttp.builtins Ψ "Http.sendIn" ScopeSignatures.sendIn
        (Ty.normTys ts) (es.map Eff.norm) rs ws a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧ ws[0]? = some w ∧
      (w = .checkedRequest target req ∨ ∃ s snapshot, w = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [w] = .val req ∧
      HasTypeV P ModelHttp.builtins Ψ [] [] [] req TargetTable.clientRequestTy.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target ∧
      (∃ out obs, ModelHttp.builtins.ioResponse "Http.sendIn" (Ty.normTys ts) (es.map Eff.norm) ws out obs) ∧
      ∀ out obs, ModelHttp.builtins.ioResponse "Http.sendIn" (Ty.normTys ts) (es.map Eff.norm) ws out obs →
        obs = [target] ∧ Outcome.Typed P ModelHttp.builtins Ψ out a₀ ∧ AdequateResult ws out :=
  request_io (ModelHttp.scopeConditions P hp) rfl (Or.inl rfl) rfl args.admissible args.ranges
    args.signature relation passed args.ground had (by intro o ho; cases ho; rfl)

/-- ADT の任意の型付き欄も、同じ値を IO の対象位置へ渡す。 -/
example {P B Ψ b sg ts es rs ws a e k p σ vs as T v} {i : Nat}
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (values : HasTypeVs P B Ψ [] [] [] vs as) (field : as[i]? = some T)
    (value : vs[i]? = some v) (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (selected : ws[p]? = some v) (had : ∀ w ∈ ws, w.Adequate σ) :
    HasTypeV P B Ψ [] [] [] v T ∧ ∃ r t, rs = [r] ∧ v.target? = some t ∧ r.Mem σ k t ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [t] := by
  obtain ⟨v',hv',typed⟩ := values.get field
  cases Option.some.inj (value.symm.trans hv')
  exact ⟨typed,selected_io conditions hs kind shape args had selected⟩

/-- Lazy の thunk と done を区別し、done の同じ値だけを IO へ渡す。 -/
example {P B σ Ψ μ l T b sg ts es rs ws a e k p}
    (store : StoreOk P B σ Ψ μ) (location : Ψ l = some (.lazy T))
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (selected : ∀ v, μ l = some (.done v) → ws[p]? = some v) :
    (∃ q, μ l = some (.thunk q) ∧ ClosureTy P B (hideBuilders Ψ) [] none q T Eff.empty ∧ q.Adequate σ) ∨
    ∃ v r t, μ l = some (.done v) ∧ HasTypeV P B Ψ [] [] [] v T ∧
      v.Adequate σ ∧ rs = [r] ∧ v.target? = some t ∧ r.Mem σ k t ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [t] := by
  rcases store.lazy_cell location with thunk | ⟨v,hv,typed,adequate⟩
  · exact Or.inl thunk
  · obtain ⟨r,t,h⟩ := selected_io conditions hs kind shape args had (selected v hv)
    exact Or.inr ⟨v,r,t,hv,typed,adequate,h⟩

/-- resume の直接入力と正規化した入力を、同じ実 IO の対象へ接続する。 -/
example {P B Ψ R Δ v T E l input result eff saved b sg ts es rs ws a e k p σ}
    (typed : HasTypeCQ P B Ψ Qempty [] [] [] R (.resume (.loc l) v) T E Δ)
    (location : Ψ l = some (.cont input result eff saved))
    (conditions : ModelScopeConditions P B) (hs : B.sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) (shape : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) (selected : ws[p]? = some v) :
    (HasTypeV P B Ψ [] [] [] v input ∨ HasTypeV P B Ψ [] [] [] v input.norm) ∧
    ∃ r t, rs = [r] ∧ v.target? = some t ∧ r.Mem σ k t ∧
      (∃ out obs, B.ioResponse b ts es ws out obs) ∧
      ∀ out obs, B.ioResponse b ts es ws out obs → obs = [t] := by
  constructor
  · rcases typed.inv_resumeL rfl with ⟨b,t,e,hl,hv,_⟩ | ⟨R',b,t,e,hl,_,hv,_⟩
    · cases Option.some.inj (location.symm.trans hl); exact Or.inl hv
    · cases Option.some.inj (location.symm.trans hl); exact Or.inr hv
  · exact selected_io conditions hs kind shape args had selected

/-- 明示拡大と Top の具体化でも、保持した同じ対象を読み、許す範囲だけを広げる。 -/
theorem widened_input {P B Ψ Q C Φ v o k r s σ}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v (.opaque o (.fixed r)))
    (closed : HasTypeVQ P B Ψ Q [] [] [] v (.opaque o (.fixed r)))
    (cover : s.Covers r) (hk : B.valKind o = some k) (had : v.Adequate σ) :
    HasTypeVQ P B Ψ Q C [] Φ v (.opaque o (.fixed s)) ∧
      ∃ t, v.target? = some t ∧ r.Mem σ k t ∧ s.Mem σ k t := by
  obtain ⟨t,ht,hm⟩ := closed.target_member (Or.inr rfl) hk had
  exact ⟨typed.widen_opaque cover,t,ht,hm,cover.mem σ hm⟩

/-- 閉じた同じ値は非 Top から Top へ渡せる。 -/
example {P B Ψ Q v o k r σ}
    (typed : HasTypeVQ P B Ψ Q [] [] [] v (.opaque o (.fixed r)))
    (hk : B.valKind o = some k) (had : v.Adequate σ) :
    HasTypeVQ P B Ψ Q [] [] [] v (.opaque o .top) ∧
      ∃ t, v.target? = some t ∧ r.Mem σ k t ∧ RangeExpr.top.Mem σ k t :=
  widened_input typed typed (RangeExpr.top_covers r) hk had

/-- 比較不能な範囲には、scoped の共変による具体化の受渡しがない。 -/
theorem incomparable {P Γ Φ o k r s} (h : ¬ s.Covers r) :
    ¬ Ty.LeQ P Γ Φ (.scoped o k (.fixed r)) (.scoped o k (.fixed s)) := by
  intro le
  obtain ⟨ix,ht,hc⟩ := le.holds (Or.inl rfl)
  rcases ht with ht | ht
  · cases ht; exact h hc
  · cases ht

example {P Γ Φ o k a b p q} (h : a ≠ b) :
    ¬ Ty.LeQ P Γ Φ (.scoped o k (.fixed (.based a p))) (.scoped o k (.fixed (.based b q))) :=
  incomparable (by simp [RangeExpr.Covers,Ne.symm h])

/-- 格納した要求の任意の要素を実送信へ渡すと、要求全体と端点が一致する。 -/
example {P Ψ σ v ts es rs ws a e} {vs : List Val} {i : Nat}
    (hp : ScopeDeclarations.HasHttp P)
    (stored : vs[i]? = some v)
    (args : BuiltinArgs P ModelHttp.builtins Ψ "Http.sendIn" ScopeSignatures.sendIn ts es rs ws a e)
    (selected : ws[0]? = some v) (had : ∀ w ∈ ws, w.Adequate σ) :
    v ∈ vs ∧ ∃ r target req, rs = [r] ∧
      (v = .checkedRequest target req ∨ ∃ s snapshot, v = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [v] = .val req ∧
      HasTypeV P ModelHttp.builtins Ψ [] [] [] req TargetTable.clientRequestTy.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target ∧
      (∃ out obs, ModelHttp.builtins.ioResponse "Http.sendIn" ts es ws out obs) ∧
      ∀ out obs, ModelHttp.builtins.ioResponse "Http.sendIn" ts es ws out obs → obs = [target] :=
  ⟨List.mem_of_getElem? stored,selected_request (ModelHttp.scopeConditions P hp) rfl (Or.inl rfl)
    rfl args had selected (by intro o ho; cases ho; rfl)⟩

/-- 解決先が一致しても、異なる起点の静的な被覆は成立しない。 -/
theorem equal_resolution_distinct_base (σ : PathEnv) (a b : PathBase) (ne : a ≠ b)
    (same : σ.lookup a = σ.lookup b) (p : PathPattern) :
    (∀ k t, (RangeExpr.based a p).Mem σ k t ↔ (RangeExpr.based b p).Mem σ k t) ∧
    (∀ q, ¬ (RangeExpr.based a p).Covers (.based b q)) := by
  constructor
  · intro k t; simp only [RangeExpr.Mem,RangeExpr.resolve,same]
  · intro q; simp [RangeExpr.Covers,ne]

example (σ : PathEnv) (same : σ.root = σ.cwd) (p q : PathPattern) :
    (∀ k t, (RangeExpr.based .root p).Mem σ k t ↔ (RangeExpr.based .cwd p).Mem σ k t) ∧
    ¬ (RangeExpr.based .root p).Covers (.based .cwd q) ∧
    ¬ (RangeExpr.path p).Covers (.based .root q) := by
  have h := equal_resolution_distinct_base σ .root .cwd (by decide)
    (by simpa only [PathEnv.lookup] using congrArg some same) p
  exact ⟨h.1,h.2 q,by simp [RangeExpr.Covers,RangeExpr.path,RangeExpr.top]⟩

/-- 一原子を複数原子へ分割して覆う判定は、効果の被覆から得られない。 -/
theorem no_collective_cover {Γ Φ e f a}
    (member : f.mem a) (individual : ∀ b, e.mem b → ¬ b.Covers a) :
    ¬ Eff.Covers Γ Φ e f := by
  intro covers
  obtain ⟨b,hb,hc⟩ := covers.1 a member
  exact individual b hb hc

/-- 指定した効果名と固定範囲だけを持つ一原子の効果。 -/
def one (l : EffName) (r : RangeExpr) : Eff :=
  .mk (fun a => decide (a = .name l (.fixed r))) []

/-- 二つのポート区間の和は意味上は全体を含むが、一原子の静的被覆にはならない。 -/
theorem split_endpoint (σ : PathEnv) (l : EffName) (host : HostPattern) (Γ : Ctx) (Φ : List Pred) :
    let whole : Range := .endpoint ⟨host,⟨0,9⟩⟩
    let left : Range := .endpoint ⟨host,⟨0,4⟩⟩
    let right : Range := .endpoint ⟨host,⟨5,9⟩⟩
    (∀ k t, (RangeExpr.absolute whole).Mem σ k t →
      (RangeExpr.absolute left).Mem σ k t ∨ (RangeExpr.absolute right).Mem σ k t) ∧
    ¬ Eff.Covers Γ Φ ((one l (.absolute left)).union (one l (.absolute right)))
      (one l (.absolute whole)) := by
  obtain ⟨semantic,notLeft,notRight⟩ := Range.endpoint_union_not_covers host
  constructor
  · intro k t hm
    have member : (Range.endpoint ⟨host,⟨0,9⟩⟩).Mem t := by
      simpa only [RangeExpr.Mem,RangeExpr.resolve,List.mem_singleton,exists_eq_left] using hm.2
    rcases semantic t member with left | right
    · exact Or.inl ⟨hm.1,by simpa only [RangeExpr.resolve,List.mem_singleton,exists_eq_left] using left⟩
    · exact Or.inr ⟨hm.1,by simpa only [RangeExpr.resolve,List.mem_singleton,exists_eq_left] using right⟩
  · apply no_collective_cover (a := .name l (.fixed (.absolute (.endpoint ⟨host,⟨0,9⟩⟩))))
      (by change decide (_ = _) = true; simp)
    intro atom hm hc
    rcases (Eff.mem_union_iff _ _ _).mp hm with hm | hm
    · have eq : atom = .name l (.fixed (.absolute (.endpoint ⟨host,⟨0,4⟩⟩))) := of_decide_eq_true hm
      subst atom
      exact notLeft ((RangeExpr.covers_absolute _ _).mp hc.2)
    · have eq : atom = .name l (.fixed (.absolute (.endpoint ⟨host,⟨5,9⟩⟩))) := of_decide_eq_true hm
      subst atom
      exact notRight ((RangeExpr.covers_absolute _ _).mp hc.2)

example (σ : PathEnv) (host : HostPattern) :
    let whole : Range := .endpoint ⟨host,⟨0,9⟩⟩
    let left : Range := .endpoint ⟨host,⟨0,4⟩⟩
    let right : Range := .endpoint ⟨host,⟨5,9⟩⟩
    (∀ k t, (RangeExpr.absolute whole).Mem σ k t →
      (RangeExpr.absolute left).Mem σ k t ∨ (RangeExpr.absolute right).Mem σ k t) ∧
    ¬ Eff.Covers [] [] ((one "Http.Connect" (.absolute left)).union
      (one "Http.Connect" (.absolute right))) (one "Http.Connect" (.absolute whole)) :=
  split_endpoint σ "Http.Connect" host [] []

/-- 一覧の未指定と解決済みの空一覧を区別し、任意の有限一覧の所属を返す。 -/
theorem secrets_members (σ : PathEnv) (ps : List PathPattern) (k : Kind) (t : Target) :
    RangeExpr.secrets.resolve {σ with secrets := none} = none ∧
    RangeExpr.secrets.resolve {σ with secrets := some []} = some [] ∧
    (RangeExpr.secrets.Mem {σ with secrets := some ps} k t ↔
      t.kind = k ∧ ∃ p ∈ ps, (Range.path p).Mem t) := by
  refine ⟨rfl,rfl,?_⟩
  simp only [RangeExpr.Mem,RangeExpr.resolve,Option.map_some]
  constructor
  · rintro ⟨hk,q,hq,hm⟩
    obtain ⟨p,hp,rfl⟩ := List.mem_map.mp hq
    exact ⟨hk,p,hp,hm⟩
  · rintro ⟨hk,p,hp,hm⟩
    exact ⟨hk,.path p,List.mem_map.mpr ⟨p,hp,rfl⟩,hm⟩

/-- 有限非空一覧のどの要素への所属も、同じ secrets と Top に含まれる。 -/
example (σ : PathEnv) (p : PathPattern) (ps : List PathPattern) {t : Target}
    (hm : (Range.path p).Mem t) (hk : t.kind = .path) :
    RangeExpr.secrets.Mem {σ with secrets := some (p :: ps)} .path t ∧
    RangeExpr.top.Mem {σ with secrets := some (p :: ps)} .path t := by
  have member := (secrets_members σ (p :: ps) .path t).2.2.mpr ⟨hk,p,List.mem_cons_self,hm⟩
  exact ⟨member,(RangeExpr.top_covers .secrets).mem _ member⟩

/-- 未指定と空一覧は、ともに所属を持たず、解決結果だけが異なる。 -/
example (σ : PathEnv) (k : Kind) (t : Target) :
    ¬ RangeExpr.secrets.Mem {σ with secrets := none} k t ∧
    ¬ RangeExpr.secrets.Mem {σ with secrets := some []} k t := by
  simp [RangeExpr.Mem,RangeExpr.resolve]

/-- Top への拡大後も同じ絶対対象を射影し、新しい環境で再解決しない。 -/
theorem absolute_projection (r s : RangeExpr) (snapshot : Option PathEnv) (w : Word) :
    ScopeDelta.widenRun [.checkedAt r snapshot (.path w) none] =
      .val (.checkedAt r snapshot (.path w) none) ∧
    ModelTargets.builtins.delta "Scope.pathInValue" [] [] [s] [.checkedAt r snapshot (.path w) none] =
      some (.val (.const (.string ("/" ++ String.intercalate "/" w)))) := by
  simp [ModelTargets.builtins,ScopeSignatures.builtins,ScopeResponse.delta,ScopeDelta.valueDelta,
    ScopeDelta.widenRun,ScopeDelta.pathValueRun,Val.target?]

example (r : RangeExpr) (σ : PathEnv) (w : Word) :
    ScopeDelta.widenRun [.checkedAt r (some σ) (.path w) none] =
      .val (.checkedAt r (some σ) (.path w) none) ∧
    ModelTargets.builtins.delta "Scope.pathInValue" [] [] [.top] [.checkedAt r (some σ) (.path w) none] =
      some (.val (.const (.string ("/" ++ String.intercalate "/" w)))) :=
  absolute_projection r .top (some σ) w

end
end Benitoite.Release.Refinement.ScopedTargetExamples
