import Benitoite.Release.Refinement.ScopeConstraintInstances
import Benitoite.Release.Refinement.TargetModelConditions
import Benitoite.Release.Refinement.ScopedIOResponse

/-! # 保持した要求の検査・射影・送信と起点発行のモデル -/
namespace Benitoite.Release.Refinement.ModelHttp
noncomputable section
open ScopeSignatures ScopeDeclarations

/-- 参照二行、要求の純粋三行、送信、起点発行を同じ表へ登録する。 -/
def entries : List (PrimName × PrimSig) := [
  ("Reference.get",refGet),("Reference.set",refSet),
  ("Http.checkRequestIn",checkRequestIn),("Http.requestInValue",requestInValue),
  ("Http.sendIn",sendIn),("Http.widenRequestIn",widenRequestIn),(pathBasesName,pathBases)]

def effects : EffName → Option (List PrimName)
  | "State" => some []
  | "Http.Connect" => some ["Http.sendIn"]
  | "Process.Environment" => some [pathBasesName]
  | _ => none

/-- 送信だけを共通の具体応答関係から選ぶ。型付けを定義に含めない。 -/
def ioResponse (b : PrimName) (ts : List Ty) (es : List Eff) (ws : List Val)
    (out : Outcome) (obs : List Scope.Domain.Target) : Prop :=
  b = "Http.sendIn" ∧ ScopedIOResponse.ioResponse b ts es ws out obs

/-- 同じ内容型、固定の reqTarget、有限宣言の骨格による制約判定を使う。 -/
def builtins : Builtins :=
  { ScopeSignatures.builtins ScopeResponse.delta ioResponse with
    sig := fun b => entries.lookup b
    effects := effects
    ioResponse := ioResponse }

/-- 成功する全 lookup を名前と署名の七場合に戻す。 -/
theorem sig_cases {b s} (h : builtins.sig b = some s) :
    (b = "Reference.get" ∧ s = refGet) ∨ (b = "Reference.set" ∧ s = refSet) ∨
    (b = "Http.checkRequestIn" ∧ s = checkRequestIn) ∨
    (b = "Http.requestInValue" ∧ s = requestInValue) ∨
    (b = "Http.sendIn" ∧ s = sendIn) ∨
    (b = "Http.widenRequestIn" ∧ s = widenRequestIn) ∨
    (b = pathBasesName ∧ s = pathBases) := by
  have hm := ScopeSignatures.lookup_mem h
  simpa only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] using hm

private theorem common_lookup {b s} (h : builtins.sig b = some s) :
    (ScopeSignatures.builtins ScopeResponse.delta ioResponse).sig b = some s := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> rfl

/-- 型・行・値の全入力について、同じ七行の八つの保存則を構成する。 -/
theorem substitutionAssumptions (P : Program) : builtins.SubstitutionAssumptions P where
  sat_rename := (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).sat_rename
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs hi ha hb h
    exact (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).admits_rename
      b sg C Γ Δ ts ξ (common_lookup hs) hi ha hb h
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ h
    exact (ScopeSignatures.admits_iff_count (common_lookup hs)).mpr
      (by simpa using (ScopeSignatures.admits_iff_count (common_lookup hs)).mp h)
  sat_renameTypes := (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).sat_renameTypes
  admits_renameTypes := by
    intro b sg C D Γ Δ ts ρ hs ren ha hb h
    exact (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).admits_renameTypes
      b sg C D Γ Δ ts ρ (common_lookup hs) ren ha hb h
  sat_subst := (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).sat_subst
  admits_subst := by
    intro b sg C0 C1 ts ts' es' hs ha wf images count
    exact (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).admits_subst
      b sg C0 C1 ts ts' es' (common_lookup hs) ha wf images count


/-- 七署名の形成は、同じ P の有限宣言の lookup と全 arity から得る。 -/
theorem sig_scoped {P : Program} (hp : HasHttp P) {b sg}
    (hs : builtins.sig b = some sg) : PrimSig.Scoped P sg :=
  ScopeSignatures.sig_scoped hp (common_lookup hs)

/-- 元の依存列の行支持を、同じ署名の形成から供給する。 -/
theorem sourceTelRows {P : Program} (hp : HasHttp P) {b sg}
    (hs : builtins.sig b = some sg) : sg.tel.RowsIn (· < sg.neffs) :=
  (sig_scoped hp hs).source.2.1

theorem sat_unconstrained (t : Ty) : builtins.sat [] t.norm ({} : TParam) :=
  ModelConstraints.sat_unconstrained _ _ _

theorem admits_sat {b s C ts} (h : builtins.sig b = some s)
    (ha : s.admits C.constraints (Ty.normTys ts)) :
    SatAll builtins C ts (s.tparams.map TParamDecl.constraints) :=
  ScopeSignatures.admits_sat (common_lookup h) ha

/-- 発行の八欄と同じ Environment の表の所属。 -/
theorem pathBases_shape {b sg} (hs : builtins.sig b = some sg) (hk : sg.kind = .pathBases) :
    sg.PathBasesShape builtins b := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve | cases hk | exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,[pathBasesName],rfl,by simp⟩

/-- 送信の対象位置は要求の endpoint 一つである。 -/
theorem io_op {b sg} (hs : builtins.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit) :
    builtins.ShapeOk b sg := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | (cases hk with | inl h => cases h | inr h => cases h)
    | exact ⟨"Http.Connect",["Http.sendIn"],rfl,rfl,rfl,by simp,rfl,rfl,rfl,"Http.RequestIn",rfl,rfl⟩

theorem opEff_io {b sg l} (hs : builtins.sig b = some sg) (hl : sg.opEff = some l) :
    sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve | cases hl | decide

theorem effect_ops {l bs b} (hl : builtins.effects l = some bs) (hb : b ∈ bs) :
    ∃ sg, builtins.sig b = some sg ∧ (sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases) ∧
      sg.opEff = some l := by
  change effects l = some bs at hl
  unfold effects at hl
  split at hl <;> cases hl
  all_goals simp only [List.mem_cons,List.not_mem_nil,or_false] at hb
  all_goals subst b; exact ⟨_,rfl,by decide,rfl⟩

theorem state_effect : builtins.effects stateEff = some [] := rfl

theorem ref_get : ∃ s, builtins.sig builtins.refGet = some s ∧ s.kind = .refGet :=
  ⟨refGet,rfl,rfl⟩

theorem ref_set : ∃ s, builtins.sig builtins.refSet = some s ∧ s.kind = .refSet :=
  ⟨refSet,rfl,rfl⟩

theorem store_shape {b sg} (hs : builtins.sig b = some sg) (hk : sg.kind ≠ .pathBases) :
    sg.StoreShape := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first
    | exact (hk rfl).elim
    | simp [PrimSig.StoreShape,refGet,refSet,TypeCtx.valueParam,checkRequestIn,requestInValue,
        sendIn,widenRequestIn,pureIn,ioIn]

theorem store_admits {b sg C ts} (hs : builtins.sig b = some sg)
    (count : ts.length = sg.tparams.length) : sg.admits C ts :=
  (ScopeSignatures.admits_iff_count (common_lookup hs)).mpr count

example {b sg} (hs : builtins.sig b = some sg) :
    PrimSig.Scoped program sg ∧ sg.tel.RowsIn (· < sg.neffs) :=
  ⟨sig_scoped program_hasHttp hs,sourceTelRows program_hasHttp hs⟩

/-- 全三純粋行の実 δ、型、閉性、全有効環境での適格性。 -/
theorem pure_response {P Ψ b sg ts es rs ws a e} (hp : HasHttp P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out, builtins.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  change ∃ out, ScopeResponse.delta b ts es rs ws = some out ∧ _
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | cases kind
    | simpa [ScopeResponse.delta] using (RequestDelta.response hp (by rfl) (by rfl) args)
    | simpa [ScopeResponse.delta] using (RequestDelta.requestInValue_response (by rfl) (by rfl) args)
    | simpa [ScopeResponse.delta] using (RequestDelta.widenRequestIn_response
        (fun _ _ h => ScopeResponse.widen_admitted (Or.inr rfl) h) args)

/-- 同じ決定的 δ の応答存在。未定義の枝を存在の根拠にしない。 -/
theorem delta_typed {P Ψ b sg ts es rs ws a e} (hp : HasHttp P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out, builtins.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out := by
  obtain ⟨out,hd,hn,ht,ha,_⟩ := pure_response hp hs kind args
  exact ⟨out,hd,hn,ht,ha⟩

/-- 全ての実結果を、同じ入力で存在定理の決定的な結果へ照合する。 -/
theorem pure_outcome {P Ψ b sg ts es rs ws a e out} (hp : HasHttp P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hd : builtins.delta b ts es rs ws = some out) :
    Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out ∧
      (∀ n, out ≠ .exit n) ∧ ∀ v, out = .val v → v.Ground := by
  obtain ⟨other,ho,hn,ht,ha,hg⟩ := pure_response hp hs kind args
  cases Option.some.inj (ho.symm.trans hd)
  exact ⟨ht,ha,hn,hg⟩

/-- 正常応答の篩の事実も、同じ実値の型付けから供給する。 -/
theorem normal_facts {P Ψ b sg ts es rs ws a e v t} (hp : HasHttp P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hd : builtins.delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) :=
  (pure_outcome hp hs kind args hd).1.1.facts ht

example {P Ψ b sg ts es rs ws a e v t} (hp : HasHttp P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hd : builtins.delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t) :
    v.Ground ∧ ∀ r ∈ a.assume, Entails [] (r.open t) :=
  ⟨(pure_outcome hp hs kind args hd).2.2.2 v rfl,normal_facts hp hs kind args hd ht⟩



/-- 全 IO 署名は同じ sendIn 一行である。 -/
private theorem io_signature {b sg} (hs : builtins.sig b = some sg)
    (hk : sg.kind = .io ∨ sg.kind = .exit) : b = "Http.sendIn" ∧ sg = sendIn := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve | exact ⟨rfl,rfl⟩ | cases hk with | inl h => cases h | inr h => cases h

/-- 型付き送信の全応答の型・適格性・非 exit・対象一致と、同じ関係の応答存在。 -/
theorem send_response {P Ψ ts es rs ws a e} (hp : HasFile P)
    (args : BuiltinArgs P builtins Ψ "Http.sendIn" sendIn ts es rs ws a e) :
    (∀ out obs, builtins.ioResponse "Http.sendIn" ts es ws out obs →
      Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (sendIn.shapeAt ws) ws obs) ∧
    ∃ out obs, builtins.ioResponse "Http.sendIn" ts es ws out obs := by
  have safe := ScopedIOResponse.sendIn hp (by rfl) (by rfl) ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ args
  exact ⟨fun out obs hr => safe.1 out obs hr.2,
    by obtain ⟨out,obs,hr⟩ := safe.2; exact ⟨out,obs,rfl,hr⟩⟩

theorem io_typed {P Ψ b sg ts es rs ws a e out obs} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hr : builtins.ioResponse b ts es ws out obs) :
    Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out := by
  obtain ⟨rfl,rfl⟩ := io_signature hs kind
  have safe := (send_response hp args).1 out obs hr
  exact ⟨safe.1,safe.2.1⟩

/-- 全実応答は送信であり、成功値・Error・err のいずれも exit にならない。 -/
theorem io_kind {b sg ts es ws out obs} (hs : builtins.sig b = some sg)
    (hr : builtins.ioResponse b ts es ws out obs) :
    sg.kind = .io ∧ ∀ n, out ≠ .exit n := by
  obtain ⟨rfl,op,hn,_,_,reply,_⟩ := hr
  have unique : op = .send := by
    cases op <;> simp only [ScopedIOResponse.Operation.name] at hn <;> first | rfl | contradiction
  subst op
  cases Option.some.inj hs
  refine ⟨rfl,?_⟩
  cases reply <;> intro n <;> simp

theorem io_exists {P Ψ b sg ts es rs ws a e} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out obs, builtins.ioResponse b ts es ws out obs := by
  obtain ⟨rfl,rfl⟩ := io_signature hs kind
  exact (send_response hp args).2

/-- 全応答で、同じ要求全体の射影と固定 reqTarget の端点が観測に一致する。 -/
theorem sent_request {b ts es ws out obs} (hr : builtins.ioResponse b ts es ws out obs) :
    b = "Http.sendIn" ∧ ∃ w req t, ws = [w] ∧ valueRun [w] = .val req ∧
      groundVal req = true ∧ req.reqTarget = some t ∧ w.target? = some t ∧ obs = [t] := by
  obtain ⟨rfl,hr⟩ := hr
  exact ⟨rfl,ScopedIOResponse.sent_request hr⟩

/-- 対象は同じ署名の shapeAt と保持要求一つから得る。 -/
theorem targetAgreement (P : Program) : builtins.TargetAgreement P where
  io_target := by
    intro Ψ b sg ts es rs ws a e out obs hs _ _ hr
    exact ScopedIOResponse.targets (common_lookup hs) hr.2

/-- 全適格環境で、同じ送信応答の観測は同じ効果の上限に属する。 -/
theorem obs_allowed {P Ψ b sg ts es rs ws a e out obs σ} (hp : HasHttp P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : builtins.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ builtins.effKind e l t :=
  Builtins.TargetAgreement.obs_allowed (io_op hs kind) (targetAgreement P)
    hs kind (sig_scoped hp hs).namesWF args had hr

/-- 発行は専用の種類であり、全ての入力・応答について IO 関係に含まれない。 -/
theorem pathBases_no_io {b sg} (hs : builtins.sig b = some sg) (kind : sg.kind = .pathBases)
    (ts es ws out obs) : ¬ builtins.ioResponse b ts es ws out obs := by
  rintro ⟨rfl,_⟩
  cases Option.some.inj hs
  cases kind


/-- 成功・Error・err の全応答について、両保持形は同じ要求と端点を使う。 -/
theorem send_held {req t out} (hg : groundVal req = true) (ht : req.reqTarget = some t)
    (reply : ScopedIOResponse.Reply .http out) (r : RangeExpr) (snap : Option PathEnv) :
    builtins.ioResponse "Http.sendIn" [] [] [.checkedRequest t req] out [t] ∧
    builtins.ioResponse "Http.sendIn" [] [] [.checkedAt r snap t (some req)] out [t] := by
  have kind := Val.reqTarget_kind ht
  exact ⟨⟨rfl,.send,rfl,rfl,rfl,reply,t,rfl,kind,rfl,
      fun _ => ⟨_,req,rfl,Or.inl rfl,valueRun_checkedRequest hg,hg,ht⟩⟩,
    ⟨rfl,.send,rfl,rfl,rfl,reply,t,rfl,kind,rfl,
      fun _ => ⟨_,req,rfl,Or.inr ⟨r,snap,rfl⟩,valueRun_checkedAt hg,hg,ht⟩⟩⟩

/-- 要求なしの checked と checkedAt は、全入力・全応答で送信関係から排除する。 -/
theorem send_without_request (t : Scope.Domain.Target) (r : RangeExpr) (snap : Option PathEnv)
    (ts es out obs) :
    ¬ builtins.ioResponse "Http.sendIn" ts es [.checked t] out obs ∧
    ¬ builtins.ioResponse "Http.sendIn" ts es [.checkedAt r snap t none] out obs := by
  constructor
  all_goals
    rintro ⟨_,op,hn,_,_,_,u,_,_,_,sent⟩
    have eq : op = .send := by
      cases op <;> simp only [ScopedIOResponse.Operation.name] at hn <;> first | rfl | contradiction
    subst op
    obtain ⟨w,req,hw,form,_⟩ := sent rfl
    cases List.singleton_inj.mp hw
    rcases form with form | ⟨r,snap,form⟩ <;> cases form

/-- 要求の固定端点と保持対象が異なる両形は、同じ送信関係から排除する。 -/
theorem send_mismatch {req t other} (hg : groundVal req = true)
    (ht : req.reqTarget = some t) (hne : t ≠ other) (r : RangeExpr) (snap : Option PathEnv)
    (ts es out obs) :
    ¬ builtins.ioResponse "Http.sendIn" ts es [.checkedRequest other req] out obs ∧
    ¬ builtins.ioResponse "Http.sendIn" ts es [.checkedAt r snap other (some req)] out obs := by
  constructor
  all_goals
    intro hr
    obtain ⟨_,w,q,u,hw,hq,_,hu,held,_⟩ := sent_request hr
    cases List.singleton_inj.mp hw
    have he : u = other := Option.some.inj held.symm
    subst u
    first
      | rw [valueRun_checkedRequest hg] at hq
      | rw [valueRun_checkedAt hg] at hq
    cases Outcome.val.inj hq
    exact hne (Option.some.inj (ht.symm.trans hu))


/-- 純粋三行と送信一行の実応答から四つの応答条件を構成する。 -/
theorem responseAssumptions (P : Program) (hp : HasHttp P) : builtins.ResponseAssumptions P where
  delta_typed := fun _ _ _ _ _ _ _ _ _ => delta_typed hp
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ => io_typed hp.file
  io_kind := fun _ _ _ _ _ _ _ _ _ _ _ hs _ hr => Or.inl (io_kind hs hr)
  io_exists := fun _ _ _ _ _ _ _ _ _ => io_exists hp.file

/-- 同じ P と全七行から、担当する二十五条件を構成する。 -/
theorem scopeConditions (P : Program) (hp : HasHttp P) : ModelScopeConditions P builtins where
  toSubstitutionAssumptions := substitutionAssumptions P
  toResponseAssumptions := responseAssumptions P hp
  toTargetAgreement := targetAgreement P
  sig_scoped := fun _ _ => sig_scoped hp
  sat_unconstrained := fun t _ => sat_unconstrained t
  admits_sat := fun _ _ _ _ => admits_sat
  pathBases_shape := fun _ _ => pathBases_shape
  io_op := fun _ _ => io_op
  opEff_io := fun _ _ _ => opEff_io
  effect_ops := fun _ _ _ => effect_ops
  state_effect := state_effect
  ref_get := ref_get
  ref_set := ref_set
  store_shape := fun _ _ => store_shape
  store_admits := fun _ _ _ _ hs _ _ _ _ => store_admits hs

/-- 外部三条件と通常資源の解放は、同じ P/B の別の入力として保持する。 -/
example (P : Program) (hp : HasHttp P) (external : builtins.ExternalAssumptions P)
    (release : ∀ Ψ v o, HasTypeV P builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      builtins.isResource o = true → ∃ r, builtins.releaseResponse v r) :
    builtins.CoreAssumptions P ∧ builtins.TargetAgreement P :=
  ⟨(scopeConditions P hp).core external release,(scopeConditions P hp).toTargetAgreement⟩

/-- 非空の鍵制約は束縛位置で判定し、空制約では同じ型変数を拒否する。 -/
example : builtins.sat [⟨false,true⟩] (.tvar 0) ⟨false,true⟩ ∧
    ¬ builtins.sat [({} : TParam)] (.tvar 0) ⟨false,true⟩ := by
  simp [builtins,ScopeSignatures.builtins,ModelConstraints.sat,StandardKeyTyping.carrier,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

end
end Benitoite.Release.Refinement.ModelHttp
