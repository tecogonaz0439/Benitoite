import Benitoite.Release.Refinement.ScopedTargetExamples
import Benitoite.Release.Refinement.AtErrorReaders
import Benitoite.Release.Refinement.LeafInputs
import Benitoite.Release.Refinement.StepLeafSelection

/-! # 実状態の入力から同じ応答と保存の葉へ -/
namespace Benitoite.Release.Refinement.ScopedTargetInputs
noncomputable section

private theorem adequate_member {σ vs} (h : adequateVals σ vs) : ∀ v ∈ vs, v.Adequate σ := by
  induction vs with
  | nil => intro v hv; cases hv
  | cons v vs ih =>
    intro w hw
    rcases List.mem_cons.mp hw with rfl | hw
    · exact h.1
    · exact ih h.2 w hw

/-- 閉じた実状態の元の依存列を正規化し、同じ実引数と適格性を供給する。 -/
theorem response_inputs {P B σ Eb q k μ b ts es rs ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws) :
    State.Inputs P B σ Eb (.run q k μ) ∧
    ∃ Ψ R a e sg r ef,
      StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e ∧ B.sig b = some sg ∧
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws r ef ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef ∧
      ∀ w ∈ ws, w.Adequate σ := by
  obtain ⟨Ψ,R,a,e,sg,r,ef,store,typed,hs,ranges,ad,signature,args,le,cov⟩ :=
    state.primitive_contract_inputs hP hPB hB view
  have original := state.inputs
  obtain ⟨_,_,_,_,_,_,_,_,_,_,adequate,closed,_⟩ := state
  have ground : ∀ w ∈ ws, w.Ground := fun w hw => typed.view_read_ground closed
    (by rw [view]; exact List.mem_cons_of_mem _ hw)
  have had := Closure.view_adequate adequate
  rw [view] at had
  exact ⟨original,Ψ,R,a,e,sg,r,ef,store,typed,hs,
    BuiltinArgs.normalized ad ranges signature args ground,le,cov,adequate_member had.2⟩

/-- 応答の三形は、同じ継続とストアへ戻す。 -/
def destination (out : Outcome) (k : Cont) (μ : Store) : State :=
  match out with
  | .val v => .run (Closure.pure (.ret v)) k μ
  | .err reason => .error [reason] k μ
  | .exit code => .exit code [] k μ

/-- 純粋な全入力は実 δ の応答を持ち、val/err の同じ保存葉へ進む。 -/
theorem pure_steps {P B σ Eb q k μ b ts es rs ws sg}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (kind : sg.kind = .pure) :
    ∃ Ψ a e out,
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e ∧
      B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      Step P B σ (.run q k μ) none (destination out k μ) ∧
      StateTyE P B σ Eb (destination out k μ) := by
  obtain ⟨_,Ψ,R,a,e,other,r,ef,_,_,hs',args,_,_,_⟩ := response_inputs hP hPB hB state view
  cases Option.some.inj (hs.symm.trans hs')
  obtain ⟨out,delta,nonexit,typed,adequate⟩ := hB.responses.delta_typed _ _ _ _ _ _ _ _ _ hs kind args
  refine ⟨Ψ,r,ef,out,args,delta,nonexit,typed,adequate,?_⟩
  cases out with
  | val v => exact state.primitive_value_all hP hPB hB valid view hs kind delta
  | err reason => exact state.primitive_error_all view hs kind delta
  | exit code => exact (nonexit code rfl).elim

/-- 同じ全 IO 応答を val/err/exit の既存葉へ渡し、同じ σ の観測上限を返す。 -/
theorem io_steps {P B σ Eb q k μ b ts es rs ws sg}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (targets : B.TargetAgreement P) (valid : σ.Valid)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (noHandler : NoHandler k (.prim b)) :
    ∃ Ψ a e,
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e ∧
      (∃ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs) ∧
      ∀ out obs, B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs →
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
        Step P B σ (.run q k μ) (some (.io b ws out obs)) (destination out k μ) ∧
        StateTyE P B σ Eb (destination out k μ) ∧
        ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t := by
  obtain ⟨_,Ψ,R,a,e,other,r,ef,_,_,hs',args,_,_,had⟩ := response_inputs hP hPB hB state view
  cases Option.some.inj (hs.symm.trans hs')
  refine ⟨Ψ,r,ef,args,hB.responses.io_exists _ _ _ _ _ _ _ _ _ hs kind args,?_⟩
  intro out obs reply
  have safe := hB.responses.io_typed _ _ _ _ _ _ _ _ _ _ _ hs kind args reply
  have allowed := targets.obs_allowed (hB.io_op b sg hs kind) hs kind
    (hB.sig_scoped b sg hs).namesWF args had reply
  refine ⟨safe.1,safe.2,?_,?_,allowed⟩
  all_goals
    have actualKind := hB.responses.io_kind _ _ _ _ _ _ _ _ _ _ _ hs args reply
    cases out with
    | val v =>
      have io : sg.kind = .io := by
        rcases actualKind with ⟨io,_⟩ | ⟨_,noval⟩
        · exact io
        · exact (noval v rfl).elim
      first
      | exact (state.io_value_all hP hPB hB valid view hs io noHandler reply).1
      | exact (state.io_value_all hP hPB hB valid view hs io noHandler reply).2
    | err reason =>
      first
      | exact (state.io_error_all view hs kind noHandler reply).1
      | exact (state.io_error_all view hs kind noHandler reply).2
    | exit code =>
      have exit : sg.kind = .exit := by
        rcases actualKind with ⟨_,noexit⟩ | ⟨exit,_⟩
        · exact (noexit code rfl).elim
        · exact exit
      first
      | exact (state.io_exit_all view hs exit noHandler reply).1
      | exact (state.io_exit_all view hs exit noHandler reply).2

/-- ハンドラで捕捉する葉は外部 IO を実行せず、同じ実引数と新しい継続セルを節へ渡す。 -/
theorem handled_step {P B σ Eb q b sg ts es rs ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (declared : P.EffectsOk B) (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (split : SplitAt (.prim b) k k1 hcap cs k2) (clause : findClause cs (.prim b) = some c)
    (fresh : μ l = none) :
    (∃ Ψ a e, BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e ∧
      ∀ w ∈ ws, w.Adequate σ) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
        (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs])))) ∧
    StateTyE P B σ Eb
      (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
        (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs])))) := by
  obtain ⟨_,Ψ,R,a,e,other,r,ef,_,_,hs',args,_,_,had⟩ := response_inputs hP hPB hB state view
  cases Option.some.inj (hs.symm.trans hs')
  exact ⟨⟨Ψ,r,ef,args,had⟩,.E_OpPrim view hs kind split clause fresh,
    state.operation_primitive hP hPB hB declared view hs kind split clause fresh⟩

private theorem at_declared {P B σ Eb q k μ kind name shape bases pattern input index}
    (state : StateTyE P B σ Eb (.run q k μ))
    (code : q.code = .checkAt kind name shape bases pattern input index) : shape.Declared P := by
  obtain ⟨_,_,_,_,_,_,_,typed,_⟩ := state
  obtain ⟨_,_,_,admissible,_⟩ := typed.at_inputs code
  cases admissible with | mk declared _ _ _ _ _ _ _ => exact declared | text declared _ _ _ _ _ _ _ => exact declared

/-- 準備の全失敗から、同じ生入力を保存した Error と既存保存葉へ進む。 -/
theorem at_prepare {P B σ Eb q k μ kind name shape bases pattern input index d}
    (state : StateTyE P B σ Eb (.run q k μ))
    (code : q.code = .checkAt kind name shape bases pattern input index)
    (failure : AtPrepare B q.capture kind name bases pattern input index = .error d) :
    d.originalPattern = closeVal q.capture pattern ∧ d.originalTarget = closeVal q.capture input ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind index,q.capture.closeTy shape.errorType] [.atError d]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind index,q.capture.closeTy shape.errorType] [.atError d]))) k μ) := by
  have reader := AtErrorReaders.prepare_reader (B := B) (Ψ := StoreTy.empty) (Q := Qempty)
    (C := []) (Γ := []) (Φ := []) (at_declared state code) failure
  exact ⟨reader.1,reader.2.1,(state.at_prepare_failure code failure).2⟩

/-- 検査失敗には同じ生入力を添え、同じ σ の snapshot と内部の七 String 観測を保つ。 -/
theorem at_error {P B σ Eb q k μ kind name shape bases pattern input index snapshot pat target bound d}
    (state : StateTyE P B σ Eb (.run q k μ))
    (code : q.code = .checkAt kind name shape bases pattern input index)
    (prepared : AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound)
    (failure : checkAt snapshot kind pat target bound = .error d) :
    let saved := AtError.fromCheck (closeVal q.capture pattern) (closeVal q.capture input) snapshot pat target d
    matchVal atErrorPattern (.atError saved) = some saved.values ∧
    (∀ ws, AdequateResult ws (.val (.atError saved))) ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType] [.atError saved]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType] [.atError saved]))) k μ) := by
  have reader := AtErrorReaders.check_reader (B := B) (Ψ := StoreTy.empty) (Q := Qempty)
    (C := []) (Γ := []) (Φ := []) (at_declared state code)
    (closeVal q.capture pattern) (closeVal q.capture input) snapshot pat target d
  have obs := reader.2.2.2.2.2.2.2.2.2.2.2
  exact ⟨obs.1,obs.2.2,state.at_error_all code prepared (state.at_current code prepared) failure⟩

/-- 成功値の保持対象と要求には、元状態から同じ snapshot の証拠を供給する。 -/
theorem at_ok {P B σ Eb q k μ kind name shape bases pattern input index snapshot pat target bound t}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P B σ Eb (.run q k μ))
    (code : q.code = .checkAt kind name shape bases pattern input index)
    (prepared : AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound)
    (success : checkAt snapshot kind pat target bound = .ok t) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ) :=
  state.at_ok_all hP hPB hB valid code prepared (state.at_current code prepared) success

/-- 三つの At 葉は、実状態から同じ snapshot の証拠を供給する。 -/
theorem at_steps {P B σ Eb q k μ kind name shape bases pattern input index}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P B σ Eb (.run q k μ))
    (code : q.code = .checkAt kind name shape bases pattern input index) :
    State.Inputs P B σ Eb (.run q k μ) ∧
    ∃ next, Step P B σ (.run q k μ) none next ∧ StateTyE P B σ Eb next := by
  exact ⟨state.inputs, state.at_step hP hPB hB valid code⟩

/-- 発行の呼出しは同じ空引数の契約から専用の発行状態へ進む。 -/
theorem path_bases_apply {P B σ Eb q b sg k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app (.prim b [] [] []) [])
    (hs : B.sig b = some sg) (kind : sg.kind = .pathBases) :
    (∃ Ψ a e, BuiltinArgs P B Ψ b sg [] [] [] [] a e) ∧
    Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ) ∧
    StateTyE P B σ Eb (.run (.mk q.capture (.issuePathBases b)) k μ) := by
  obtain ⟨_,Ψ,R,a,e,other,r,ef,_,_,hs',args,_⟩ := response_inputs (rs := []) hP hPB hB state view
  cases Option.some.inj (hs.symm.trans hs')
  exact ⟨⟨Ψ,r,ef,args⟩,state.path_bases_apply_all hP hPB hB view hs kind⟩

/-- 実際の発行は同じ環境・事象・効果表の所属と同じストアを保つ。 -/
theorem issue {P B σ Eb q b sg k μ}
    (hB : B.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .issuePathBases b)
    (hs : B.sig b = some sg) (kind : sg.kind = .pathBases) :
    State.Inputs P B σ Eb (.run q k μ) ∧
    (∃ bs, B.effects processEnvironmentEff = some bs ∧ b ∈ bs) ∧
    Step P B σ (.run q k μ) (some (.pathBases b σ))
      (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.pathBases σ))) k μ) := by
  have shape := hB.pathBases_shape b sg hs kind
  exact ⟨state.inputs,shape.membership,state.issue_path_bases_all view hs kind shape.operation valid⟩

/-- ModelTargets の全純粋行を、実際の δ と同じ保存状態へ接続する。 -/
example {P σ Eb q k μ b ts es rs ws sg}
    (hP : P.WellFormed) (hPB : P.WellTyped ModelTargets.builtins)
    (hB : ModelTargets.builtins.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P ModelTargets.builtins σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : ModelTargets.builtins.sig b = some sg) (kind : sg.kind = .pure) :
    ∃ out, ModelTargets.builtins.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some out ∧
      Step P ModelTargets.builtins σ (.run q k μ) none (destination out k μ) ∧
      StateTyE P ModelTargets.builtins σ Eb (destination out k μ) := by
  obtain ⟨Ψ,a,e,out,_,delta,_,_,_,step,preserved⟩ := pure_steps hP hPB hB valid state view hs kind
  exact ⟨out,delta,step,preserved⟩

/-- ModelTargets の全 IO 行は、同じ実応答・同じ環境と上限のまま保存される。 -/
example {P σ Eb q k μ b ts es rs ws sg}
    (hP : P.WellFormed) (hPB : P.WellTyped ModelTargets.builtins)
    (hB : ModelTargets.builtins.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P ModelTargets.builtins σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : ModelTargets.builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (noHandler : NoHandler k (.prim b)) :
    ∃ out obs, ModelTargets.builtins.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs ∧
      Step P ModelTargets.builtins σ (.run q k μ) (some (.io b ws out obs)) (destination out k μ) ∧
      StateTyE P ModelTargets.builtins σ Eb (destination out k μ) := by
  obtain ⟨Ψ,a,e,_,⟨out,obs,reply⟩,all⟩ :=
    io_steps hP hPB hB (ModelTargets.targetAgreement P) valid state view hs kind noHandler
  have result := all out obs reply
  exact ⟨out,obs,reply,result.2.2.1,result.2.2.2.1⟩

/-- ModelHttp の全純粋行を、実際の δ と同じ保存状態へ接続する。 -/
example {P σ Eb q k μ b ts es rs ws sg}
    (hP : P.WellFormed) (hPB : P.WellTyped ModelHttp.builtins)
    (hB : ModelHttp.builtins.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P ModelHttp.builtins σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : ModelHttp.builtins.sig b = some sg) (kind : sg.kind = .pure) :
    ∃ out, ModelHttp.builtins.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some out ∧
      Step P ModelHttp.builtins σ (.run q k μ) none (destination out k μ) ∧
      StateTyE P ModelHttp.builtins σ Eb (destination out k μ) := by
  obtain ⟨Ψ,a,e,out,_,delta,_,_,_,step,preserved⟩ := pure_steps hP hPB hB valid state view hs kind
  exact ⟨out,delta,step,preserved⟩

/-- ModelHttp の全 IO 行は、同じ実応答・同じ環境と上限のまま保存される。 -/
example {P σ Eb q k μ b ts es rs ws sg}
    (hP : P.WellFormed) (hPB : P.WellTyped ModelHttp.builtins)
    (hB : ModelHttp.builtins.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P ModelHttp.builtins σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : ModelHttp.builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (noHandler : NoHandler k (.prim b)) :
    ∃ out obs, ModelHttp.builtins.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs ∧
      Step P ModelHttp.builtins σ (.run q k μ) (some (.io b ws out obs)) (destination out k μ) ∧
      StateTyE P ModelHttp.builtins σ Eb (destination out k μ) := by
  obtain ⟨Ψ,a,e,_,⟨out,obs,reply⟩,all⟩ :=
    io_steps hP hPB hB (ModelHttp.targetAgreement P) valid state view hs kind noHandler
  have result := all out obs reply
  exact ⟨out,obs,reply,result.2.2.1,result.2.2.2.1⟩

/-- 選んだ oracle の実応答も、同じ全応答の保存定理で扱える。 -/
example {P B σ Eb q k μ b ts es rs ws sg externalOracle rel fresh}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (kind : sg.kind = .pure ∨ sg.kind = .io ∨ sg.kind = .exit)
    (noHandler : NoHandler k (.prim b)) :
    (∃ Ψ a e, BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e) ∧
    ∃ event next, step P B σ B.selectOracle externalOracle rel fresh (.run q k μ) = some (event,next) ∧
      Step P B σ (.run q k μ) event next := by
  obtain ⟨_,Ψ,R,a,e,other,r,ef,_,_,hs',args,_⟩ := response_inputs hP hPB hB state view
  cases Option.some.inj (hs.symm.trans hs')
  exact ⟨⟨Ψ,r,ef,args⟩,state.selected_primitive_step hP hPB hB view hs kind noHandler⟩

/-- 要求を受ける実送信のハンドラにも、同じ引数列と継続セルを渡す。 -/
example {P σ Eb q ts es rs ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped ModelHttp.builtins)
    (hB : ModelHttp.builtins.CoreAssumptions P) (declared : P.EffectsOk ModelHttp.builtins)
    (state : StateTyE P ModelHttp.builtins σ Eb (.run q k μ))
    (view : q.view = .app (.prim "Http.sendIn" ts es (List.map RangeIx.fixed rs)) ws)
    (split : SplitAt (.prim "Http.sendIn") k k1 hcap cs k2)
    (clause : findClause cs (.prim "Http.sendIn") = some c) (fresh : μ l = none) :
    Step P ModelHttp.builtins σ (.run q k μ) none
      (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
        (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs])))) ∧
    StateTyE P ModelHttp.builtins σ Eb
      (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
        (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs])))) :=
  (handled_step hP hPB hB declared state view (sg := ScopeSignatures.sendIn) rfl
    (Or.inl rfl) split clause fresh).2

/-- 発行二葉を連結しても、同じ σ と元のストアを保つ。 -/
example {P σ Eb q k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped Model.builtins)
    (hB : Model.builtins.CoreAssumptions P) (valid : σ.Valid)
    (state : StateTyE P Model.builtins σ Eb (.run q k μ))
    (view : q.view = .app (.prim ScopeSignatures.pathBasesName [] [] []) [])
    :
    ∃ mid, Step P Model.builtins σ (.run q k μ) none mid ∧
      Step P Model.builtins σ mid (some (.pathBases ScopeSignatures.pathBasesName σ))
        (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
      StateTyE P Model.builtins σ Eb (.run (Closure.pure (.ret (.pathBases σ))) k μ) := by
  obtain ⟨_,step,mid⟩ := path_bases_apply hP hPB hB state view
    (sg := ScopeSignatures.pathBases) rfl rfl
  have issued := issue hB valid mid (by rfl) (sg := ScopeSignatures.pathBases) rfl rfl
  exact ⟨_,step,issued.2.2⟩


end
end Benitoite.Release.Refinement.ScopedTargetInputs
