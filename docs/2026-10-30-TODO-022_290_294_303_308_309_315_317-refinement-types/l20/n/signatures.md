# 群 N の完全署名

B_WORK: `14dc5648d5c8cb866268ecd3f29020d8e43436b9`。変更する署名を先に記す。定義は本体を含め、定理は証明を除いた完全署名を記す。内部の署名の変更は承認済みである。暗黙引数の型は使用する判断から決まる Lean の記法による。

## StepLeafSelection

```lean
def Builtins.selectOracle (B : Builtins) : Oracle := by
  classical
  exact fun b ts es ws =>
  if h : ∃ out obs, B.ioResponse b ts es ws out obs then
    ⟨Classical.choose h,Classical.choose (Classical.choose_spec h)⟩
  else ⟨.err "NoResponse",[]⟩

def Builtins.selectRelease (B : Builtins) (v : Val) : Option ErrKind := by
  classical
  exact if h : ∃ r, B.releaseResponse v r then Classical.choose h else none

def Store.selectFresh (μ : Store) : Nat := by
  classical
  exact if h : ∃ l, μ l = none then Classical.choose h else 0

theorem Builtins.selectOracle_response {B : Builtins} {b ts es ws}
    (h : ∃ out obs, B.ioResponse b ts es ws out obs) :
    B.ioResponse b ts es ws (B.selectOracle b ts es ws).1 (B.selectOracle b ts es ws).2

theorem Builtins.selectRelease_response {B : Builtins} {v} (h : ∃ r, B.releaseResponse v r) :
    B.releaseResponse v (B.selectRelease v)

theorem StoreOk.selectFresh_empty {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    μ μ.selectFresh = none ∧ Ψ μ.selectFresh = none

theorem step_pure_selected {P B σ oracle externalOracle rel fresh q b ts es rs ws k μ sg Ψ a e}
    (hB : B.CoreAssumptions P) (hq : q.view = .app (.prim b ts es rs) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (ha : BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e) :
    ∃ event dest, step P B σ oracle externalOracle rel fresh (.run q k μ) = some (event,dest) ∧
      Step P B σ (.run q k μ) event dest

theorem step_io_selected {P B σ externalOracle rel fresh q b ts es rs ws k μ sg Ψ a e}
    (hB : B.CoreAssumptions P) (hq : q.view = .app (.prim b ts es rs) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (hn : NoHandler k (.prim b))
    (ha : BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e) :
    ∃ event dest, step P B σ B.selectOracle externalOracle rel fresh (.run q k μ) = some (event,dest) ∧
      Step P B σ (.run q k μ) event dest

theorem ContTy.selected_release {P B σ Ψ R e k a b Eb Re v}
    (hB : B.CoreAssumptions P)
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    B.releaseResponse v (B.selectRelease v)

theorem step_builder_new_selected {P B σ oracle externalOracle rel q kind body k μ Ψ}
    (h : StoreOk P B σ Ψ μ) (hv : q.view = .builderLet kind body) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst μ.selectFresh))) k
        (μ.set μ.selectFresh (.builder kind.empty))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst μ.selectFresh))) k
        (μ.set μ.selectFresh (.builder kind.empty)))

theorem step_lazy_selected {P B σ oracle externalOracle rel q body k μ Ψ}
    (h : StoreOk P B σ Ψ μ) (hv : q.view = .lazyC body) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (Closure.pure (.ret (.loc μ.selectFresh))) k
        (μ.set μ.selectFresh (.thunk (.mk q.capture body)))) ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.loc μ.selectFresh))) k
        (μ.set μ.selectFresh (.thunk (.mk q.capture body))))

private theorem SplitAt.splitHandler_some {o k k1 cap h k2} (hs : SplitAt o k k1 cap h k2) :
    splitHandler o k = some (k1,cap,h,k2)

theorem step_ref_new_selected {P B σ oracle externalOracle rel q b ts es rs v k μ Ψ sg}
    (h : StoreOk P B σ Ψ μ) (hv : q.view = .app (.prim b ts es rs) [v])
    (hs : B.sig b = some sg) (hk : sg.kind = .refNew) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (Closure.pure (.ret (.loc μ.selectFresh))) k (μ.set μ.selectFresh (.val v))) ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.loc μ.selectFresh))) k (μ.set μ.selectFresh (.val v)))

theorem step_op_selected {P B σ oracle externalOracle rel q o ts ws k μ Ψ k1 hcap h k2 c}
    (hμ : StoreOk P B σ Ψ μ) (hv : q.view = .app (.op o ts) ws)
    (hs : SplitAt (.user o) k k1 hcap h k2) (hc : findClause h (.user o) = some c) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h])))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h]))))

theorem step_raise_selected {P B σ oracle externalOracle rel q t e v k μ Ψ k1 hcap err body k2}
    (hμ : StoreOk P B σ Ψ μ) (hv : q.view = .app (.raise t e) [v])
    (hs : SplitAt .fail k k1 hcap [.fail err body] k2) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk (hcap.extendMany [v,.loc μ.selectFresh]) (body.substTy [t] []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap [.fail err body]])))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany [v,.loc μ.selectFresh]) (body.substTy [t] []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap [.fail err body]]))))

theorem step_prim_handler_selected {P B σ oracle externalOracle rel q b ts es rs ws k μ Ψ sg k1 hcap h k2 c}
    (hμ : StoreOk P B σ Ψ μ) (hv : q.view = .app (.prim b ts es rs) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases)
    (hh : SplitAt (.prim b) k k1 hcap h k2) (hc : findClause h (.prim b) = some c) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h])))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h]))))

inductive FreshStepInputs (B : Builtins) (q : Closure) (k : Cont) (μ : Store) : State → Prop where
  | reference {b ts es rs v sg} : q.view = .app (.prim b ts es rs) [v] →
      B.sig b = some sg → sg.kind = .refNew →
      FreshStepInputs B q k μ (.run (Closure.pure (.ret (.loc μ.selectFresh))) k (μ.set μ.selectFresh (.val v)))
  | operation {o ts ws k1 hcap h k2 c} : q.view = .app (.op o ts) ws →
      SplitAt (.user o) k k1 hcap h k2 → findClause h (.user o) = some c →
      FreshStepInputs B q k μ
        (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
          (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h]))))
  | failure {t e v k1 hcap err body k2} : q.view = .app (.raise t e) [v] →
      SplitAt .fail k k1 hcap [.fail err body] k2 →
      FreshStepInputs B q k μ
        (.run (.mk (hcap.extendMany [v,.loc μ.selectFresh]) (body.substTy [t] []))
          (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap [.fail err body]]))))
  | primitive {b ts es rs ws sg k1 hcap h k2 c} : q.view = .app (.prim b ts es rs) ws →
      B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases) →
      SplitAt (.prim b) k k1 hcap h k2 → findClause h (.prim b) = some c →
      FreshStepInputs B q k μ
        (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
          (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h]))))

theorem step_fresh_selected {P B σ oracle externalOracle rel q k μ Ψ dest}
    (hμ : StoreOk P B σ Ψ μ) (input : FreshStepInputs B q k μ dest) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) = some (none,dest) ∧
      Step P B σ (.run q k μ) none dest

theorem step_release_selected {P B σ oracle externalOracle fresh q k μ w v} {escape : Bool}
    (hv : q.view = if escape then .escape w else .ret w)
    (hr : ∃ result, B.releaseResponse v result) :
    let dest

theorem StateTyE.selected_primitive_step {P B σ Eb externalOracle rel fresh q b ts es rs ws k μ sg}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure ∨ sg.kind = .io ∨ sg.kind = .exit)
    (hn : NoHandler k (.prim b)) :
    ∃ event dest, step P B σ B.selectOracle
      externalOracle rel fresh (.run q k μ) = some (event,dest) ∧ Step P B σ (.run q k μ) event dest

theorem ContTy.selected_release_step {P B σ Ψ R e k a b Eb Re v ok err}
    (hB : B.CoreAssumptions P)
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    releaseStep B.selectRelease v ok err =
      some (some (.release v (B.selectRelease v)), match B.selectRelease v with | none => ok | some r => err r) ∧
      B.releaseResponse v (B.selectRelease v)
```

## FunctionViewGeneral

```lean
theorem Tel.function_view_contract {s : List Atom} {t : Tel} {f : FnView}
    (hs : t.Support (· ∈ s)) (hv : t.fnViewWith? s = some f) :
    f.toTel = t ∧ f.names = t.names ∧ NamesWF t.names f.params ∧
      t.names.Nodup ∧ Ty.foldFnWith s t = .fn f.names f.params f.result f.effect

theorem CaptureOk.termBind_success {P B Ψ R Γ Φ cap} {t : Term} {sort : «Sort»}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ht : t.HasSort Γ sort) :
    ∃ u, termBind? (valEnv cap.env).values t = some u ∧
      termBind (valEnv cap.env).values t = u ∧ u.HasSort [] sort

theorem HasTypeVQ.captured_observation {P B Ψ R Γ Φ cap v a t sort}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeV P B Ψ [] Γ Φ v a)
    (ho : v.toTerm? = some t) (ht : t.HasSort Γ sort) :
    ∃ u, (closeVal cap v).toTerm? = some u ∧
      termBind (valEnv cap.env).values t = u ∧ u.HasSort [] sort ∧
      HasTypeV P B Ψ [] [] [] (closeVal cap v) (cap.closeTy a)
```

## ControlLeafSelection

```lean
inductive ControlLeafInputs (P : Program) (B : Builtins) (σ : PathEnv) :
    State → Option Event → State → Prop where
  | E_EscLet {v n k μ} {q : Closure} :
      q.view = (.escape v) →
      ControlLeafInputs P B σ (.run q (.letF n :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscHandle {v h k μ} {q : Closure} {hcap : Capture} :
      q.view = (.escape v) →
      ControlLeafInputs P B σ (.run q (.handleF hcap h :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscMark {v k μ} {q : Closure} :
      q.view = (.escape v) →
      ControlLeafInputs P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ)
  
  | E_ErrPopLet {rs n k μ} : ControlLeafInputs P B σ (.error rs (.letF n :: k) μ) none (.error rs k μ)
  | E_ErrPopMark {rs k μ} : ControlLeafInputs P B σ (.error rs (.mark :: k) μ) none (.error rs k μ)
  | E_ExitPopLet {n rs m k μ} : ControlLeafInputs P B σ (.exit n rs (.letF m :: k) μ) none (.exit n rs k μ)
  | E_ExitPopMark {n rs k μ} : ControlLeafInputs P B σ (.exit n rs (.mark :: k) μ) none (.exit n rs k μ)

theorem StateTyE.control_leaf {P B σ Eb s event dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb s) (hi : ControlLeafInputs P B σ s event dest) :
    Step P B σ s event dest ∧ StateTyE P B σ Eb dest ∧ LocalStateInvariant P B σ dest

private theorem control_for_model {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) none
        (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)

private theorem other_control_for_model {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    (Step P B σ (.error [rResume] [.mark] Store.empty) none (.error [rResume] [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.error [rResume] [] Store.empty)) ∧
    (Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.handleF Capture.empty [],.mark] Store.empty) none
        (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty))

theorem concrete_other_control_leaves :
    ∃ P B σ, P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      (Step P B σ (.error [rResume] [.mark] Store.empty) none (.error [rResume] [] Store.empty) ∧
        StateTyE P B σ Eff.empty (.error [rResume] [] Store.empty)) ∧
      (Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.handleF Capture.empty [],.mark] Store.empty) none
          (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) ∧
        StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty))

theorem concrete_control_leaf :
    ∃ P B σ, P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) none
        (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)
```

## IntervalConnection

```lean
def rangeErrorFields : Benitoite.Checked.Range.RangeError → List Int
  | .invalidBounds lo hi => [lo,hi]
  | .outOfRange lo hi value => [lo,hi,value]

inductive ValueRel : Benitoite.Interval.ConcreteValue → Val → Prop
  | unit : ValueRel .unit (.const .unit)
  | boolean (b : Bool) : ValueRel (.boolean b) (.const (.boolean b))
  | integer64 (n : Benitoite.Interval.IntegerValue .integer64) : ValueRel (.integer n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .integer64 n)))
  | integer8 (n : Benitoite.Interval.IntegerValue .integer8) : ValueRel (.integer8 n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .integer8 n)))
  | integer16 (n : Benitoite.Interval.IntegerValue .integer16) : ValueRel (.integer16 n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .integer16 n)))
  | integer32 (n : Benitoite.Interval.IntegerValue .integer32) : ValueRel (.integer32 n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .integer32 n)))
  | unsignedInteger16 (n : Benitoite.Interval.IntegerValue .unsignedInteger16) : ValueRel (.unsignedInteger16 n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .unsignedInteger16 n)))
  | unsignedInteger32 (n : Benitoite.Interval.IntegerValue .unsignedInteger32) : ValueRel (.unsignedInteger32 n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .unsignedInteger32 n)))
  | unsignedInteger64 (n : Benitoite.Interval.IntegerValue .unsignedInteger64) : ValueRel (.unsignedInteger64 n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst .unsignedInteger64 n)))
  | other {t ni nb nu v} :
      v.toApprox = .other → (∀ i, v ≠ .var i) → ValueRel (.other t ni nb nu) v
  | rangeError {owner name error ts} (values : List Benitoite.Release.Integer64Value) :
      values.map Benitoite.Release.Integer64Value.toInt = rangeErrorFields error →
      ValueRel (.rangeError owner name error) (.con name ts (values.map (fun n => .const (.integer n))))
  | con {owner types name cs ts vs} : ValuesRel cs vs → ValueRel (.con owner types name cs) (.con name ts vs)

inductive ValuesRel : List Benitoite.Interval.ConcreteValue → List Val → Prop
  | nil : ValuesRel [] []
  | cons {c v cs vs} : ValueRel c v → ValuesRel cs vs → ValuesRel (c :: cs) (v :: vs)

inductive EnvValuesRel : List (Option Benitoite.Interval.ConcreteValue) → List (Option Val) → Prop
  | nil : EnvValuesRel [] []
  | hidden {slot cs vs} : EnvValuesRel cs vs → EnvValuesRel (none :: cs) (slot :: vs)
  | value {c v cs vs} : ValueRel c v → EnvValuesRel cs vs → EnvValuesRel (some c :: cs) (some v :: vs)

def EnvRel (env : Benitoite.Interval.ConcreteEnv) (cap : Capture) : Prop :=
  EnvValuesRel env.locals cap.values

def ExprCode (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (source : Benitoite.Surface.Expr) (code : Comp) : Prop :=
  code = embedComp (Benitoite.Surface.desugarExpr op position source)

def BlockCode (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (source : Benitoite.Surface.Block) (code : Comp) : Prop :=
  code = embedComp (Benitoite.Surface.desugarBlock op position source)

def ArmsCode (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (source : Benitoite.Surface.Arms) (arms : List Arm) : Prop :=
  arms = embedArms (Benitoite.Surface.desugarArms op position source)

def ResultRel (failures : Benitoite.Interval.Failure → List ErrKind → Prop) :
    Benitoite.Interval.EvalOutcome → Shared.EvalResult Val (List ErrKind) → Prop
  | .normal value, .normal v => ValueRel value v
  | .returned value, .returned v => ValueRel value v
  | .failed reason, .failed rs => failures reason rs
  | _, _ => False

def EndState (failures : Benitoite.Interval.Failure → List ErrKind → Prop) (outcome : Benitoite.Interval.EvalOutcome)
    (k : Cont) (state : State) : Prop :=
  match outcome with
  | .normal value => ∃ q μ v, state = .run q k μ ∧ q.view = .ret v ∧ ValueRel value v
  | .returned value => ∃ q μ v, state = .run q k μ ∧ q.view = .escape v ∧ ValueRel value v
  | .failed reason => ∃ μ rs, state = .error rs k μ ∧ failures reason rs

def Runs (P : Program) (B : Builtins) (σ : PathEnv) (failures : Benitoite.Interval.Failure → List ErrKind → Prop)
    (q : Closure) (k : Cont) (μ : Store) (outcome : Benitoite.Interval.EvalOutcome) (resultCont : Cont := k) : Prop :=
  ∃ events state, Steps P B σ (.run q k μ) events state ∧ EndState failures outcome resultCont state

theorem ValueRel.integer (kind : Benitoite.Interval.IntKind) (n : Benitoite.Interval.IntegerValue kind) :
    ValueRel (.ofInteger kind n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst kind n)))

theorem ValueRel.toApprox_eq {c v} (h : ValueRel c v) : c.toApprox = v.toApprox

theorem ValueRel.con_inv {owner types name cs v}
    (h : ValueRel (.con owner types name cs) v) :
    ∃ ts vs, v = .con name ts vs ∧ ValuesRel cs vs

theorem ValueRel.close {c v} (h : ValueRel c v) (cap : Capture) : ValueRel c (closeVal cap v)

theorem ValuesRel.close {cs vs} (h : ValuesRel cs vs) (cap : Capture) : ValuesRel cs (closeVals cap vs)

theorem EnvRel.extend {env cap c v} (h : EnvRel env cap) (hv : ValueRel c v) :
    EnvRel { env with locals

theorem EnvRel.extendMany {env cap cs vs} (h : EnvRel env cap) (hv : ValuesRel cs vs) :
    EnvRel { env with locals

theorem EnvRel.length {env cap} (h : EnvRel env cap) : env.locals.length = cap.values.length

theorem EndState.result {failures outcome k state} (h : EndState failures outcome k state) :
    ∃ result, ResultRel failures outcome result

theorem steps_trans {P B σ s t u xs ys}
    (h : Steps P B σ s xs t) (g : Steps P B σ t ys u) : Steps P B σ s (xs ++ ys) u

private theorem single {P B σ s event t} (h : Step P B σ s event t) :
    Steps P B σ s event.toList t

theorem Runs.let_normal {P B σ failures cap m n k μ c outcome}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.normal c))
    (tail : ∀ v μ', ValueRel c v → Runs P B σ failures (.mk (cap.extend v) n) k μ' outcome) :
    Runs P B σ failures (.mk cap (.letIn m n)) k μ outcome

theorem Runs.let_returned {P B σ failures cap m n k μ c}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.returned c)) :
    Runs P B σ failures (.mk cap (.letIn m n)) k μ (.returned c)

theorem Runs.let_failed {P B σ failures cap m n k μ reason}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.failed reason)) :
    Runs P B σ failures (.mk cap (.letIn m n)) k μ (.failed reason)

theorem Runs.return_operand {P B σ failures cap m k μ outcome}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap (.escape (.var 0))) :: k) μ outcome) :
    Runs P B σ failures (.mk cap (.letIn m (.escape (.var 0)))) k μ (Benitoite.Interval.returnOutcome outcome)

theorem Runs.returned_mark {P B σ failures q k μ c}
    (h : Runs P B σ failures q (.mark :: k) μ (.returned c)) :
    Runs P B σ failures q (.mark :: k) μ (.normal c) k

theorem connect_return {P B σ failures env cap op key resultType source type outcome trace m k μ}
    (henv : EnvRel env cap) (hcode : ExprCode op .other source m)
    (eval : Benitoite.Interval.EvalPartial env ⟨source,type,Benitoite.Interval.childKey key []⟩ outcome trace)
    (run : Runs P B σ failures (.mk cap m) (.letF (.mk cap (.escape (.var 0))) :: k) μ outcome) :
    ExprCode op .other (.returnE resultType source) (.letIn m (.escape (.var 0))) ∧
    Benitoite.Interval.EvalPartial env ⟨.returnE resultType source,resultType,key⟩ (Benitoite.Interval.returnOutcome outcome) trace ∧
    EnvRel env cap ∧ Runs P B σ failures (.mk cap (.letIn m (.escape (.var 0)))) k μ (Benitoite.Interval.returnOutcome outcome)

theorem connect_bind {P B σ failures env cap op position key kind boundType source rest type c outcome et rt m n k μ}
    (henv : EnvRel env cap) (hm : ExprCode op .other source m) (hn : BlockCode op position rest n)
    (heval : Benitoite.Interval.EvalPartial env ⟨source,boundType,key⟩ (.normal c) et)
    (teval : Benitoite.Interval.EvalBlock {env with locals

theorem runs_match_body {P B σ failures env cap v arms next alts body ws cs k μ outcome}
    (henv : EnvRel env cap) (hvs : ValuesRel cs ws)
    (hi : arms[next]? = some (.mk alts none body)) (hm : firstAlt v alts = some ws)
    (tail : Runs P B σ failures (.mk (cap.extendMany ws) body) k μ outcome) :
    EnvRel {env with locals

theorem runs_guard_true {P B σ failures q v cap arms next body k μ outcome}
    (guard : Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.normal (.boolean true)))
    (tail : ∀ μ', Runs P B σ failures body k μ' outcome) :
    Runs P B σ failures q (.guardF v cap arms next body :: k) μ outcome k

theorem runs_guard_false {P B σ failures q v cap arms next body k μ}
    (guard : Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.normal (.boolean false))) :
    ∃ events μ', Steps P B σ (.run q (.guardF v cap arms next body :: k) μ) events
      (.matchRun v cap arms next k μ')

theorem runs_guard_failed {P B σ failures q v cap arms next body k μ reason}
    (guard : Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.failed reason)) :
    Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.failed reason) k

theorem normal_shared_iff {type range c v} (h : ValueRel c v) (ht : c.type = type) :
    (Benitoite.Interval.normalToShared type range).Mem v.toApprox ↔ Benitoite.Interval.NormalMem type range c

theorem const_integer_exact {B : Builtins} {c : Const} {kind : Benitoite.Interval.IntKind}
    (hc : ConstOK B c) (hk : Benitoite.Interval.IntKind.ofRefinementType c.type = some kind) :
    ∃ n : Benitoite.Interval.IntegerValue kind,
      c = embedConst (Benitoite.Interval.IntegerValue.toConst kind n) ∧ c.toApprox = .integer kind n

theorem const_integer_same_value {B : Builtins} {c : Const} {kind : Benitoite.Interval.IntKind}
    (hc : ConstOK B c) (hk : Benitoite.Interval.IntKind.ofRefinementType c.type = some kind)
    (n : Benitoite.Interval.IntegerValue kind) (he : c.toApprox = .integer kind n) :
    c = embedConst (Benitoite.Interval.IntegerValue.toConst kind n)

def EnvRelAt (env : Benitoite.Interval.ConcreteEnv) (cap : Capture) (ξ : Nat → Nat) : Prop :=
  ∀ i c, env.locals[i]? = some (some c) →
    ∃ v, cap.values[ξ i]? = some (some v) ∧ ValueRel c v

private theorem envValues_lookup {cs vs} {i : Nat} {c : Benitoite.Interval.ConcreteValue} (h : EnvValuesRel cs vs) (hi : cs[i]? = some (some c)) :
    ∃ v, vs[i]? = some (some v) ∧ ValueRel c v

theorem EnvRel.at {env cap} (h : EnvRel env cap) : EnvRelAt env cap id

theorem EnvRelAt.insert {env cap ξ} (h : EnvRelAt env cap ξ) (v : Val) :
    EnvRelAt env (cap.extend v) (fun i => ξ i+1)

theorem EnvRelAt.extend {env cap ξ c v} (h : EnvRelAt env cap ξ) (hv : ValueRel c v) :
    EnvRelAt {env with locals

private theorem upRen_zero (ξ : Nat → Nat) : Benitoite.Release.upRen 0 ξ = ξ

private theorem upRen_nested (n m : Nat) (ξ : Nat → Nat) :
    Benitoite.Release.upRen n (Benitoite.Release.upRen m ξ) = Benitoite.Release.upRen (n+m) ξ

theorem EnvRelAt.extendMany {env cap ξ cs vs} (h : EnvRelAt env cap ξ) (hv : ValuesRel cs vs) :
    EnvRelAt {env with locals

def ArmBodyConnection (env : Benitoite.Interval.ConcreteEnv) (cap : Capture) (ξ : Nat → Nat)
    (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (body : Benitoite.Surface.Block)
    (code : Comp) (cs : List Benitoite.Interval.ConcreteValue) (vs : List Val) : Prop :=
  EnvRelAt {env with locals := cs.reverse.map some ++ env.locals} (cap.extendMany vs) (Benitoite.Release.upRen vs.length ξ) ∧
    code = embedComp ((Benitoite.Surface.desugarBlock op position body).rename (Benitoite.Release.upRen vs.length ξ))

def MatchRel : Option (List Benitoite.Interval.ConcreteValue) → Option (List Val) → Prop
  | none, none => True
  | some cs, some vs => ValuesRel cs vs
  | _, _ => False

private theorem values_lookup {cs vs} (h : ValuesRel cs vs) (i : Nat) :
    match cs[i]?,vs[i]? with
    | none,none => True
    | some c,some v => ValueRel c v
    | _,_ => False

private theorem slots_related {cs vs} (h : ValuesRel cs vs) (slots : List Nat) :
    MatchRel (Benitoite.Release.selectSlots cs slots) (selectSlots vs slots)

theorem result_pattern_related {names types tag payload runtime pattern}
    (h : ValueRel (.con names.result types tag [payload]) runtime)
    (hp : Benitoite.Interval.rangeResultPattern names pattern = true) :
    MatchRel (Benitoite.Interval.resultPatternMatch names (.con names.result types tag [payload]) tag payload pattern)
      (matchVal pattern.toCore runtime)

def firstResultAlt (names : Benitoite.Interval.RangeNames) (value : Benitoite.Interval.ConcreteValue)
    (tag : Benitoite.Release.ConName) (payload : Benitoite.Interval.ConcreteValue) :
    List Benitoite.Surface.Alternative → Option (List Benitoite.Interval.ConcreteValue) :=
  List.foldr (fun alt tail => match Benitoite.Interval.resultPatternMatch names value tag payload alt.pat with
    | none => tail
    | some raw => Benitoite.Release.selectSlots raw alt.slots) none

private theorem first_result_related {names types tag payload runtime alts}
    (h : ValueRel (.con names.result types tag [payload]) runtime)
    (hp : ∀ alt ∈ alts, Benitoite.Interval.rangeResultPattern names alt.pat = true) :
    MatchRel (firstResultAlt names (.con names.result types tag [payload]) tag payload alts)
      (firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts))

private theorem result_selection_first {names value tag payload alts selected}
    (h : Benitoite.Interval.ResultSelection names value tag payload alts selected) :
    firstResultAlt names value tag payload alts = some selected

theorem result_selection_related {names types tag payload runtime alts selected}
    (h : ValueRel (.con names.result types tag [payload]) runtime)
    (hp : ∀ alt ∈ alts, Benitoite.Interval.rangeResultPattern names alt.pat = true)
    (selection : Benitoite.Interval.ResultSelection names (.con names.result types tag [payload]) tag payload alts selected) :
    ∃ ws, firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) = some ws ∧ ValuesRel selected ws

theorem connect_integer_arm {P B σ failures env cap key value alternatives sourceBody sourceRest type selected outcome trace
    runtimeValue arms next code ws k μ ξ op position}
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : Benitoite.Interval.IntegerSelection alternatives value selected)
    (eval : Benitoite.Interval.EvalBlock {env with locals

theorem connect_width_arm {P B σ failures env cap key kind value alternatives sourceBody sourceRest type selected outcome trace
    runtimeValue arms next code ws k μ ξ op position}
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : Benitoite.Interval.WidthSelection alternatives kind value selected)
    (eval : Benitoite.Interval.EvalBlock {env with locals

theorem connect_result_arm {P B σ failures env cap key names types tag payload alternatives sourceBody sourceRest type selected outcome trace
    runtimeValue arms next k μ ξ op position}
    (henv : EnvRelAt env cap ξ)
    (patterns : ∀ alt ∈ alternatives, Benitoite.Interval.rangeResultPattern names alt.pat = true)
    (selection : Benitoite.Interval.ResultSelection names (.con names.result types tag [payload]) tag payload alternatives selected)
    (eval : Benitoite.Interval.EvalBlock {env with locals

theorem runs_match_skip {P B σ failures v cap arms next alts guard body k μ outcome}
    (hi : arms[next]? = some (.mk alts guard body)) (hm : firstAlt v alts = none)
    (tail : ∃ events state, Steps P B σ (.matchRun v cap arms (next+1) k μ) events state ∧ EndState failures outcome k state) :
    ∃ events state, Steps P B σ (.matchRun v cap arms next k μ) events state ∧ EndState failures outcome k state

theorem runs_match_guard {P B σ failures v cap arms next alts guard body ws k μ outcome}
    (hi : arms[next]? = some (.mk alts (some guard) body)) (hm : firstAlt v alts = some ws)
    (tail : Runs P B σ failures (.mk (cap.extendMany ws) guard)
      (.guardF v cap arms (next+1) (.mk (cap.extendMany ws) body) :: k) μ outcome k) :
    ∃ events state, Steps P B σ (.matchRun v cap arms next k μ) events state ∧ EndState failures outcome k state

inductive ArmInput where
  | integer (value : Benitoite.Release.Integer64Value)
  | width (kind : Benitoite.Interval.IntKind) (value : Benitoite.Interval.IntegerValue kind)
  | result (names : Benitoite.Interval.RangeNames) (value : Benitoite.Interval.ConcreteValue)
      (tag : Benitoite.Release.ConName) (payload : Benitoite.Interval.ConcreteValue)

def ArmInput.Eval (input : ArmInput) (env : Benitoite.Interval.ConcreteEnv) (key : Benitoite.Interval.OperationKey)
    (arms : Benitoite.Surface.Arms) (type : Benitoite.Release.Ty) (outcome : Benitoite.Interval.EvalOutcome)
    (trace : Benitoite.Interval.EvalTrace) : Prop :=
  match input with
  | .integer value => Benitoite.Interval.EvalArms env key value arms type outcome trace
  | .width kind value => Benitoite.Interval.EvalWidthArms env key kind value arms type outcome trace
  | .result names value tag payload => Benitoite.Interval.EvalResultArms env key names value tag payload arms type outcome trace

def ArmInput.Selection (input : ArmInput) (alts : List Benitoite.Surface.Alternative)
    (selected : List Benitoite.Interval.ConcreteValue) : Prop :=
  match input with
  | .integer value => Benitoite.Interval.IntegerSelection alts value selected
  | .width kind value => Benitoite.Interval.WidthSelection alts kind value selected
  | .result names value tag payload => Benitoite.Interval.ResultSelection names value tag payload alts selected

def ArmInput.Miss (input : ArmInput) (alts : List Benitoite.Surface.Alternative) : Prop :=
  match input with
  | .integer value => ∀ alt ∈ alts, alt.pat.toCore.matchVal (.const (.integer value)) = none
  | .width kind value => ∀ alt ∈ alts, Benitoite.Interval.widthPatternMatch alt.pat kind value = none
  | .result names value tag payload => ∀ alt ∈ alts, Benitoite.Interval.resultPatternMatch names value tag payload alt.pat = none

theorem connect_arm_skip {P B σ failures env key alts guard body rest type outcome trace
    runtime cap arms next codeGuard codeBody k μ} (input : ArmInput)
    (miss : input.Miss alts)
    (eval : input.Eval env (Benitoite.Interval.advanceKey key (Benitoite.Interval.guardSize guard + Benitoite.Interval.blockSize body)) rest type outcome trace)
    (hi : arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alts) codeGuard codeBody))
    (hm : firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) = none)
    (tail : ∃ events state, Steps P B σ (.matchRun runtime cap arms (next+1) k μ) events state ∧ EndState failures outcome k state) :
    input.Eval env key (.cons alts guard body rest) type outcome trace ∧
    ∃ events state, Steps P B σ (.matchRun runtime cap arms next k μ) events state ∧ EndState failures outcome k state

theorem connect_arm_guard_true {P B σ failures env cap ξ key alts guard body rest type selected outcome gt bt
    runtime arms next codeGuard codeBody ws k μ} (input : ArmInput)
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : input.Selection alts selected)
    (condition : Benitoite.Interval.EvalPartial {env with locals

theorem connect_arm_guard_false {P B σ failures env cap ξ key alts guard body rest type selected outcome gt rt
    runtime arms next codeGuard codeBody ws k μ} (input : ArmInput)
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : input.Selection alts selected)
    (condition : Benitoite.Interval.EvalPartial {env with locals

def TrackedFailure (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace) : Prop :=
  reason ≠ .unknown ∧ ∃ event ∈ trace, event.result = .rejected reason

theorem connect_bind_failed {P B σ failures env cap key kind boundType source rest type reason trace m n k μ}
    (eval : Benitoite.Interval.EvalPartial env ⟨source,boundType,key⟩ (.failed reason) trace)
    (run : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.failed reason)) :
    Benitoite.Interval.EvalBlock env key (.bind kind boundType source rest) type (.failed reason) trace ∧
      Runs P B σ failures (.mk cap (.letIn m n)) k μ (.failed reason)

theorem arms_code_cons {op position alternatives guard body rest arms}
    (h : ArmsCode op position (.cons alternatives guard body rest) arms) :
    arms = .mk (Benitoite.Surface.Alternative.toCoreList alternatives)
      (guard.map (fun g => embedComp ((Benitoite.Surface.desugarExpr op .other g).rename
        (Benitoite.Release.upRen (Benitoite.Release.Arm.bindersOf (Benitoite.Surface.Alternative.toCoreList alternatives)) (·+1)))))
      (embedComp ((Benitoite.Surface.desugarBlock op position body).rename
        (Benitoite.Release.upRen (Benitoite.Release.Arm.bindersOf (Benitoite.Surface.Alternative.toCoreList alternatives)) (·+1)))) ::
      embedArms (Benitoite.Surface.desugarArms op position rest)

theorem typed_returned_mark {P B σ Eb q k μ c v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.mark :: k) μ))
    (hv : q.view = .escape v) (hrel : ValueRel c v) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) ∧
    EndState (fun _ _ => False) (.normal c) k (.run (Closure.pure (.ret v)) k μ)
```

## IntervalConnectionExamples

```lean
private def env : Benitoite.Interval.ConcreteEnv := ⟨[],[],fun _ => none⟩

private def key : Benitoite.Interval.OperationKey := ⟨"control",0⟩

private def op : Benitoite.Surface.OpPrim := fun _ _ => none

private def failures : Benitoite.Interval.Failure → List ErrKind → Prop := fun reason rs =>
  reason = .unknown ∧ rs = [rResume]

private def body : Comp := .letIn (.ret (.var 0)) (.escape (.var 0))

private def source : Benitoite.Surface.Block := .bind .bind (.base .unit) .unit
  (.last (.returnE (.base .unit) (.local 0)))

private def code : Comp := .letIn (.ret (.const .unit)) body

private theorem unitRel : ValueRel .unit (.const .unit)

private theorem atom {P B σ q k μ c v}
    (hv : q.view = .ret v) (hrel : ValueRel c v) : Runs P B σ failures q k μ (.normal c)

theorem binding_and_return (P : Program) (B : Builtins) (σ : PathEnv) :
    BlockCode op .other source code ∧
    EvalBlock env key source (.base .unit) (.returned .unit) [] ∧
    Runs P B σ failures (.mk Capture.empty code) [.mark] Store.empty (.returned .unit) ∧
    Runs P B σ failures (.mk Capture.empty code) [.mark] Store.empty (.normal .unit) []

theorem integer_values (B : Builtins) (kind : Benitoite.Interval.IntKind) (n : Benitoite.Interval.IntegerValue kind) :
    let c

private def alternative : Benitoite.Surface.Alternative := ⟨.var,[0]⟩

private def alts : List Alt := [alternative.toCore]

private def integer : Benitoite.Release.Integer64Value := ⟨7,by decide⟩

private def integerVal : Val := .const (.integer integer)

private def integerCore : Benitoite.Release.Val := .const (.integer integer)

private theorem integerRel : ValueRel (.integer integer) integerVal

theorem integer_arm (P : Program) (B : Builtins) (σ : PathEnv) :
    EvalArms env key integer (.cons [alternative] none (.last (.local 0)) .nil) (.base .integer)
      (.normal (.integer integer)) [] ∧
    ValueRel (.integer integer) integerVal ∧
    ArmBodyConnection env Capture.empty id op .other (.last (.local 0)) (.ret (.var 0)) [.integer integer] [integerVal] ∧
    ∃ events state, Steps P B σ (.matchRun integerVal Capture.empty [.mk alts none (.ret (.var 0))] 0 [] Store.empty)
      events state ∧ EndState failures (.normal (.integer integer)) [] state

theorem width_arm (P : Program) (B : Builtins) (σ : PathEnv) (kind : Benitoite.Interval.IntKind)
    (n : Benitoite.Interval.IntegerValue kind) :
    let v

private def names : Benitoite.Interval.RangeNames := ⟨"Range","Range.Checked","Result","RangeError","Result.Ok","Result.Error","InvalidBounds","OutOfRange"⟩

private def result : ConcreteValue := .con names.result [.base .unit,.data names.error []] names.ok [.unit]

theorem result_arm (P : Program) (B : Builtins) (σ : PathEnv) :
    EvalResultArms env key names result names.ok .unit (.cons [alternative] none (.last .unit) .nil) (.base .unit)
      (.normal .unit) [] ∧
    ValueRel result (.con names.ok [.base .unit,.data names.error []] [.const .unit]) ∧
    (∃ code ws, ArmBodyConnection env Capture.empty id op .other (.last .unit) code [result] ws) ∧
    ∃ events state, Steps P B σ (.matchRun (.con names.ok [.base .unit,.data names.error []] [.const .unit]) Capture.empty
      [.mk alts none (.ret (.const .unit))] 0 [] Store.empty) events state ∧ EndState failures (.normal .unit) [] state

theorem result_tag_contrast :
    ¬ ValueRel result (.con names.err [] [.const .unit]) ∧
    ¬ ValueRel .unit (.con names.ok [] []) ∧
    ¬ ValueRel (.con names.result [] names.ok [.unit]) (.con names.ok [] [.con names.err [] []]) ∧
    (∃ ws, firstAlt (.con names.ok [] [.const .unit])
      (Benitoite.Surface.Alternative.toCoreList
        [⟨.con none names.err [.var],[0]⟩,⟨.con none names.ok [.var],[0]⟩]) = some ws ∧
      ValuesRel [.unit] ws)

private def guardArms (truth : Bool) : List Arm :=
  [.mk [.mk .wild []] (some (.ret (.const (.boolean truth)))) (.ret (.const .unit)),
   .mk [.mk .wild []] none (.ret (.const .unit))]

private def guardFrame (truth : Bool) : Frame :=
  .guardF (.const .unit) Capture.empty (guardArms truth) 1 (.mk Capture.empty (.ret (.const .unit)))

theorem guards (P : Program) (B : Builtins) (σ : PathEnv) :
    ∀ truth, ∃ events state, Steps P B σ (.matchRun (.const .unit) Capture.empty (guardArms truth) 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state

private def sampleInput : Nat → ArmInput
  | 0 => .integer integer
  | 1 => .width .integer8 ⟨7,by decide⟩
  | _ => .result names result names.ok .unit

private def sampleValue : Nat → ConcreteValue
  | 0 => .integer integer
  | 1 => .integer8 ⟨7,by decide⟩
  | _ => result

private def sampleRuntime : Nat → Val
  | 0 => integerVal
  | 1 => .const (.integer8 7)
  | _ => .con names.ok [] [.const .unit]

private def fallback : Benitoite.Surface.Arms := .cons [⟨.wild,[]⟩] none (.last .unit) .nil

private def guardedRuntime (truth : Bool) : List Arm :=
  [.mk alts (some (.ret (.const (.boolean truth)))) (.ret (.const .unit)),
   .mk [.mk .wild []] none (.ret (.const .unit))]

private theorem sample_selection (i : Nat) : (sampleInput i).Selection [alternative] [sampleValue i]

private theorem sample_relation (i : Nat) : ValueRel (sampleValue i) (sampleRuntime i)

private theorem fallback_eval (i : Nat) (key : Benitoite.Interval.OperationKey) :
    (sampleInput i).Eval env key fallback (.base .unit) (.normal .unit) []

theorem independent_arm_guards (P : Program) (B : Builtins) (σ : PathEnv) (i : Nat) (truth : Bool) :
    (sampleInput i).Eval env key (.cons [alternative] (some (.literal (.boolean truth))) (.last .unit) fallback)
      (.base .unit) (.normal .unit) [] ∧
    ∃ events state, Steps P B σ (.matchRun (sampleRuntime i) Capture.empty (guardedRuntime truth) 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state

private def missed : Benitoite.Surface.Alternative := ⟨.con none "Missing" [.var],[0]⟩

theorem independent_arm_skip (P : Program) (B : Builtins) (σ : PathEnv) (i : Nat) :
    (sampleInput i).Eval env key (.cons [missed] none (.last .unit) fallback) (.base .unit) (.normal .unit) [] ∧
    ∃ events state, Steps P B σ (.matchRun (sampleRuntime i) Capture.empty
      [.mk (Benitoite.Surface.Alternative.toCoreList [missed]) none (.ret (.const .unit)),
       .mk [.mk .wild []] none (.ret (.const .unit))] 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state

private def minimum : Benitoite.Release.Integer64Value := ⟨Benitoite.Release.min64,by decide⟩

private def overflowEnv : Benitoite.Interval.ConcreteEnv := {env with locals := [some (.integer minimum)]}

private def overflowTrace : Benitoite.Interval.EvalTrace :=
  [⟨key,.neg (.base .integer),[.integer minimum],.rejected .overflow⟩]

theorem tracked_failure_contrast :
    EvalPartial overflowEnv ⟨.neg (.base .integer) (.local 0),.base .integer,key⟩ (.failed .overflow) overflowTrace ∧
    TrackedFailure .overflow overflowTrace ∧ ¬ TrackedFailure .unknown []

private def failedSource : Benitoite.Surface.Expr := .resume 0 .unit

private def failedCode : Comp := .resume (.loc 0) (.const .unit)

private def used : Store := Store.empty.set 0 .used

private theorem failed_eval : EvalPartial env ⟨failedSource,.base .unit,key⟩ (.failed .unknown) []

private theorem failed_run (P : Program) (B : Builtins) (σ : PathEnv) (k : Cont) :
    Runs P B σ failures (.mk Capture.empty failedCode) k used (.failed .unknown)

theorem failure_propagation (P : Program) (B : Builtins) (σ : PathEnv) :
    EvalBlock env key (.bind .bind (.base .unit) failedSource (.last .unit)) (.base .unit) (.failed .unknown) [] ∧
    Runs P B σ failures (.mk Capture.empty (.letIn failedCode (.ret (.const .unit)))) [] used (.failed .unknown) ∧
    Runs P B σ failures (.mk Capture.empty failedCode) [guardFrame true] used (.failed .unknown) []

theorem skipped_arm (P : Program) (B : Builtins) (σ : PathEnv) :
    let arms : List Arm

theorem arm_code_and_environment :
    let arms

theorem inserted_scrutinee :
    EnvRelAt {env with locals

theorem result_constructors (P : Program) (B : Builtins) (σ : PathEnv) :
    (∃ result, ResultRel failures (.normal .unit) result) ∧
    ¬ ResultRel failures (.normal .unit) (.returned (.const .unit))

private theorem unit_escape {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
    EndState (fun _ _ => False) (.normal .unit) [] (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)

theorem concrete_interval_control :
    ∃ (P : Program) (B : Builtins) (σ : PathEnv), P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      ∃ events state, Steps P B σ (.run (.mk Capture.empty code) [.mark] Store.empty) events state ∧
        EndState (fun _ _ => False) (.normal .unit) [] state ∧ StateTyE P B σ Eff.empty state

private theorem view_observation_model {P B}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    (∃ f : FnView, f.names = ["value"] ∧ f.names.Nodup ∧
      f.toTel.fnViewWith? [] = some f ∧ Ty.foldFnWith [] f.toTel = .fn f.names f.params f.result f.effect) ∧
    (∃ u, (closeVal Capture.empty integerVal).toTerm? = some u ∧
      termBind (valEnv Capture.empty.env).values (.integer 7) = u ∧ u.HasSort [] .integer ∧
      HasTypeV P B StoreTy.empty [] [] [] (closeVal Capture.empty integerVal) (Capture.empty.closeTy (.base .integer)))

theorem concrete_view_observation :
    ∃ (P : Program) (B : Builtins) (σ : PathEnv), P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      (∃ f : FnView, f.names = ["value"] ∧ f.names.Nodup ∧
        f.toTel.fnViewWith? [] = some f ∧ Ty.foldFnWith [] f.toTel = .fn f.names f.params f.result f.effect) ∧
      (∃ u, (closeVal Capture.empty integerVal).toTerm? = some u ∧
        termBind (valEnv Capture.empty.env).values (.integer 7) = u ∧ u.HasSort [] .integer ∧
        HasTypeV P B StoreTy.empty [] [] [] (closeVal Capture.empty integerVal) (Capture.empty.closeTy (.base .integer)))
```

## IntervalRelationBoundary

```lean
def ValueShape (c : Benitoite.Interval.ConcreteValue) (v : Val) : Prop :=
  match c with
  | .unit => v = .const .unit
  | .con _ _ tag _ => ∃ ts vs, v = .con tag ts vs
  | _ => True

theorem ValueRel.shape {c v} (h : ValueRel c v) : ValueShape c v

theorem ground_signature_obstruction :
    (.unit : Benitoite.Interval.ConcreteValue).toApprox = (Val.con "Result.Error" [] []).toApprox ∧
    ¬ ValueRel .unit (.con "Result.Error" [] []) ∧
    ¬ (∀ (c : Benitoite.Interval.ConcreteValue) (v : Val),
      c.toApprox = v.toApprox → v.Ground → ValueShape c v)

private theorem escape_source (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty)

theorem marked_signature_obstruction :
    ∃ (P : Program) (B : Builtins) (σ : PathEnv),
      P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) ∧
      (Benitoite.Interval.ConcreteValue.con "Result" [] "Result.Ok" [.unit]).toApprox = (Val.const .unit).toApprox ∧
      ¬ (∃ (q : Closure) (μ : Store) (v : Val),
        State.run (Closure.pure (.ret (.const .unit))) [] Store.empty = .run q [] μ ∧
        q.view = .ret v ∧ ValueShape (.con "Result" [] "Result.Ok" [.unit]) v)
```

## HandlerGeneral

```lean
private theorem escape_value {P B Ψ Q C Γ Φ R m a e L v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : m = .escape v) :
    ∃ r, R = some r ∧ HasTypeVQ P B Ψ Q C Γ Φ v r

theorem ClosureTy.escape_view_value {P B Ψ R q a e v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (h : ClosureTy P B Ψ [] R q a e) (hv : q.view = .escape v)
    : ∃ r, R = some r ∧ HasTypeV P B Ψ [] [] [] v r

theorem ContTy.handler_tail_annotated {P B σ Ψ R e k a b Eb Re cap cs}
    (h : ContTy P B σ Ψ R e (.handleF cap cs :: k) a b Eb Re) :
    ∃ t et, Ty.LeQ P [] [] a t ∧ Ty.Annotation P [] [] t ∧
      ContTy P B σ Ψ R et k t b Eb Re
```

## StateLeaves

```lean
private theorem let_result_annotation {P B Ψ x c n} {R : Option Ty} {e : Eff}
    (h : ClosureTy P B Ψ [x] (R.map (Ty.shiftV 1 0)) n (c.shiftV 1 0) (e.shiftV 1 0))
    (hx : Ty.Annotation P [] [] x) : Ty.Annotation P [] [] c

theorem StateTyE.escape_let {P B σ Eb q v n k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (hv : q.view = .escape v) :
    Step P B σ (.run q (.letF n :: k) μ) none (.run (Closure.pure (.escape v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape v)) k μ)

theorem StateTyE.escape_handler {P B σ Eb q v cap cs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ)) (hv : q.view = .escape v) :
    Step P B σ (.run q (.handleF cap cs :: k) μ) none (.run (Closure.pure (.escape v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape v)) k μ)

theorem StateTyE.escape_mark {P B σ Eb q v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (hv : q.view = .escape v) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.error_let {P B σ Eb rs n k μ}
    (h : StateTyE P B σ Eb (.error rs (.letF n :: k) μ)) :
    Step P B σ (.error rs (.letF n :: k) μ) none (.error rs k μ) ∧
    StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.exit_let {P B σ Eb rs n k μ code}
    (h : StateTyE P B σ Eb (.exit code rs (.letF n :: k) μ)) :
    Step P B σ (.exit code rs (.letF n :: k) μ) none (.exit code rs k μ) ∧
    StateTyE P B σ Eb (.exit code rs k μ)

theorem StateTyE.error_mark {P B σ Eb rs k μ}
    (h : StateTyE P B σ Eb (.error rs (.mark :: k) μ)) :
    Step P B σ (.error rs (.mark :: k) μ) none (.error rs k μ) ∧
    StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.exit_mark {P B σ Eb rs k μ code}
    (h : StateTyE P B σ Eb (.exit code rs (.mark :: k) μ)) :
    Step P B σ (.exit code rs (.mark :: k) μ) none (.exit code rs k μ) ∧
    StateTyE P B σ Eb (.exit code rs k μ)
```

## NormalReplyExamples

```lean
theorem concrete_step_selections (σ : PathEnv) :
    (∀ b∈["Example.unit","Example.ioUnit"], ∃ event dest,
      step modelProgram modelBuiltins σ modelBuiltins.selectOracle (fun _ _ _ => (.err "Unused",[]))
        modelBuiltins.selectRelease Store.selectFresh (.run (Closure.pure (call b)) [] Store.empty) = some (event,dest) ∧
      Step modelProgram modelBuiltins σ (.run (Closure.pure (call b)) [] Store.empty) event dest) ∧
    (∃ event dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle (fun _ _ _ => (.err "Unused",[]))
        modelBuiltins.selectRelease Store.selectFresh
        (.run (Closure.pure (.builderLet .string (.ret (.const .unit)))) [] Store.empty) = some (event,dest) ∧
      Step modelProgram modelBuiltins σ (.run (Closure.pure (.builderLet .string (.ret (.const .unit)))) [] Store.empty) event dest) ∧
    (∃ event dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle (fun _ _ _ => (.err "Unused",[]))
        modelBuiltins.selectRelease Store.selectFresh
        (.run (Closure.pure (.lazyC (.ret (.const .unit)))) [] Store.empty) = some (event,dest) ∧
      Step modelProgram modelBuiltins σ (.run (Closure.pure (.lazyC (.ret (.const .unit)))) [] Store.empty) event dest)
```

## HandlerStoreExamples

```lean
theorem concrete_release_selection (σ : PathEnv) :
    releaseStep modelBuiltins.selectRelease resource
      (.error [] [] Store.empty) (fun r => .error [r] [] Store.empty) =
      some (some (.release resource (modelBuiltins.selectRelease resource)),
        match modelBuiltins.selectRelease resource with
        | none => .error [] [] Store.empty | some r => .error [r] [] Store.empty) ∧
      modelBuiltins.releaseResponse resource (modelBuiltins.selectRelease resource)

theorem concrete_fresh_operation (σ : PathEnv) :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧ modelBuiltins.CoreAssumptions modelProgram ∧
    ∃ events dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle
      (fun _ _ _ => (.err "Unused",[])) modelBuiltins.selectRelease Store.selectFresh
      (.run (Closure.pure (.app (.op "Example.identity" [.base .unit]) [.const .unit]))
        [.handleF Capture.empty [.mk (.user "Example.identity") 1 1 (.ret (.var 1))]] Store.empty) = some (events,dest) ∧
      Step modelProgram modelBuiltins σ
        (.run (Closure.pure (.app (.op "Example.identity" [.base .unit]) [.const .unit]))
          [.handleF Capture.empty [.mk (.user "Example.identity") 1 1 (.ret (.var 1))]] Store.empty) events dest

theorem concrete_release_frames (σ : PathEnv) (escape : Bool) :
    ∃ event dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle
      (fun _ _ _ => (.err "Unused",[])) modelBuiltins.selectRelease Store.selectFresh
      (.run (Closure.pure (if escape then .escape (.const .unit) else .ret (.const .unit))) [.release resource] Store.empty) =
        some (event,dest) ∧
      Step modelProgram modelBuiltins σ
        (.run (Closure.pure (if escape then .escape (.const .unit) else .ret (.const .unit))) [.release resource] Store.empty) event dest
```

## H04 の候補

未証明の義務。公理・本番の仮定ではない。

```lean
import Benitoite

open Benitoite.Release.Refinement
open Benitoite.Release.Refinement.IntervalConnection

-- L40 H04 が証明する候補の完全な型。宣言・公理・定理の仮置きではない。
-- 同じ入力・同じ独立評価・同じ trace の拒否理由から mayFail を導く。
#check (∀ (abstract : Benitoite.Interval.AbstractEnv) (concrete : Benitoite.Interval.ConcreteEnv)
    (input : Benitoite.Interval.EvalInput) (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace),
    Benitoite.Interval.Models abstract concrete →
    Benitoite.Interval.EvalPartial concrete input (.failed reason) trace →
    TrackedFailure reason trace →
    (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true : Prop)

namespace Benitoite.Release.Refinement.IntervalConnection.H04

/-- 選んだ同じ実行経路について、まだ error に入っていないことを示す。 -/
def BeforeError : State → Prop
  | .error .. => False
  | _ => True

inductive BeforeErrorSteps (P : Program) (B : Builtins) (σ : PathEnv) :
    State → List Event → State → Prop where
  | nil {s} : BeforeError s → BeforeErrorSteps P B σ s [] s
  | cons {s t u event events} : BeforeError s → Step P B σ s event t →
      BeforeErrorSteps P B σ t events u →
      BeforeErrorSteps P B σ s (event.toList ++ events) u

/-- 最初の失敗の位置と、その位置で実際に拒否した pure の δ だけを観測する。 -/
def FirstFailureHandoff : Prop :=
  ∀ (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) (k : Cont) (μ : Store)
    (events : List Event) (errors : List ErrKind) (lastK : Cont) (lastStore : Store),
    Steps P B σ (.run q k μ) events (.error errors lastK lastStore) →
    ∃ (preEvents : List Event) (before : State) (event : Option Event)
      (firstErrors : List ErrKind) (firstK : Cont) (firstStore : Store) (suffix : List Event),
      BeforeErrorSteps P B σ (.run q k μ) preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix ∧
      ∀ (focus : Closure) (atK : Cont) (atStore : Store) (b : PrimName)
        (ts : List Ty) (es : List Eff) (ranges : List RangeExpr) (ws : List Val) (sg : PrimSig),
        before = .run focus atK atStore → focus.view = .app (.prim b ts es ranges) ws →
        B.sig b = some sg → sg.kind = .pure →
        event = none ∧ ∃ r, firstErrors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r)

end Benitoite.Release.Refinement.IntervalConnection.H04

-- 第二候補は同じ有限な実行の最初の失敗の位置を特定する。
#check (H04.FirstFailureHandoff : Prop)

#print H04.FirstFailureHandoff
```

## H04 の反例と改めた候補の補助（既定ビルドの外）

名前空間 H04 と H04Counterexample は IntervalConnection の下に置く。OldH04 は変更前の候補の保存であり、現行の候補ではない。

```lean
def BeforeError : State → Prop
  | .error .. => False
  | _ => True

inductive BeforeErrorSteps (P : Program) (B : Builtins) (σ : PathEnv) :
    State → List Event → State → Prop where
  | nil {s} : BeforeError s → BeforeErrorSteps P B σ s [] s
  | cons {s t u event events} : BeforeError s → Step P B σ s event t →
      BeforeErrorSteps P B σ t events u →
      BeforeErrorSteps P B σ s (event.toList ++ events) u

def FirstFailureHandoff : Prop :=
  ∀ (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) (k : Cont) (μ : Store)
    (events : List Event) (errors : List ErrKind) (lastK : Cont) (lastStore : Store),
    Steps P B σ (.run q k μ) events (.error errors lastK lastStore) →
    ∃ (preEvents : List Event) (before : State) (event : Option Event)
      (firstErrors : List ErrKind) (firstK : Cont) (firstStore : Store) (suffix : List Event),
      BeforeErrorSteps P B σ (.run q k μ) preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix ∧
      ∀ (focus : Closure) (atK : Cont) (atStore : Store) (b : PrimName)
        (ts : List Ty) (es : List Eff) (ranges : List RangeExpr) (ws : List Val) (sg : PrimSig),
        before = .run focus atK atStore → focus.view = .app (.prim b ts es ranges) ws →
        B.sig b = some sg → sg.kind = .pure →
        event = none ∧ ∃ r, firstErrors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r)

def OldH04 : Prop := (∀ (P : Program) (B : Builtins) (σ : PathEnv)
    (concrete : Benitoite.Interval.ConcreteEnv) (input : Benitoite.Interval.EvalInput)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace)
    (op : Benitoite.Surface.OpPrim) (ξ : Nat → Nat) (cap : Capture) (code : Comp) (k : Cont) (μ : Store),
    EnvRelAt concrete cap ξ →
    code = embedComp ((Benitoite.Surface.desugarExpr op .other input.source).rename ξ) →
    Benitoite.Interval.EvalPartial concrete input (.failed reason) trace →
    TrackedFailure reason trace →
    Runs P B σ (fun _ _ => True) (.mk cap code) k μ (.failed reason) →
    let failures : Benitoite.Interval.Failure → List Benitoite.Release.ErrKind → Prop := fun rejected rs =>
      ∃ event ∈ trace, event.result = .rejected rejected ∧
        match event.operation with
        | .binary bin type => ∃ b ts ws r,
            op (.binary bin) type = some (b,ts) ∧ ValuesRel event.arguments ws ∧
            B.delta b (Ty.normTys (embedTys ts)) [] [] ws = some (.err r) ∧ r ∈ rs
        | .neg type => ∃ b ts ws r,
            op .neg type = some (b,ts) ∧ ValuesRel event.arguments ws ∧
            B.delta b (Ty.normTys (embedTys ts)) [] [] ws = some (.err r) ∧ r ∈ rs
        | .standard binding => ∃ ws events μ' rejectedErrors,
            ValuesRel event.arguments ws ∧ rejectedErrors ≠ [] ∧
            Steps P B σ (.run (Closure.pure (.app (.fnRef binding.declaration [] []) ws)) [] Store.empty)
              events (.error rejectedErrors [] μ') ∧ ∀ r ∈ rejectedErrors, r ∈ rs
    ∃ (events : List Event) (μ' : Store) (rs : List Benitoite.Release.ErrKind),
      Steps P B σ (.run (.mk cap code) k μ) events (.error rs k μ') ∧ failures reason rs : Prop)

private def one : Benitoite.Release.Integer64Value := ⟨1,by decide⟩

private def minusOne : Benitoite.Release.Integer64Value := ⟨-1,by decide⟩

private def minimum : Benitoite.Release.Integer64Value := ⟨Benitoite.Release.min64,by decide⟩

private def env : Benitoite.Interval.ConcreteEnv := ⟨[some (.integer one),some (.integer minimum)],[],fun _ => none⟩

private def cap : Capture := (Capture.empty.extend (.const (.integer minimum))).extend (.const (.integer one))

private def key : Benitoite.Interval.OperationKey := ⟨"counterexample",0⟩

private def left : Benitoite.Surface.Expr := .neg (.base .integer) (.local 0)

private def right : Benitoite.Surface.Expr := .neg (.base .integer) (.local 1)

private def input : Benitoite.Interval.EvalInput := ⟨.binary .add (.base .integer) left right,.base .integer,key⟩

private def op : Benitoite.Surface.OpPrim := fun operator _ => match operator with
  | .neg => some ("neg",[])
  | .binary .add => some ("add",[])
  | _ => none

private def sig : PrimSig := ⟨[],0,["value"],[.base .integer],.base .integer,Eff.empty,fun _ _ => True,.pure,none,[],.untargeted⟩

private def B : Builtins where
  sig := fun _ => some sig
  delta := fun _ _ _ _ args => match args with
    | [.const (.integer n)] => if n.toInt = 1 then some (.err "LeftError") else some (.val (.const (.integer n)))
    | _ => some (.val (.const .unit))
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

private def P : Program := ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,fun _ => none,fun _ => none,[],fun _ => none⟩

private def leftEvent : Benitoite.Interval.EvalEvent := ⟨Benitoite.Interval.childKey key [],.neg (.base .integer),[.integer one],.normal (.integer minusOne)⟩

private def rightEvent : Benitoite.Interval.EvalEvent := ⟨Benitoite.Interval.childKey key [left],.neg (.base .integer),[.integer minimum],.rejected .overflow⟩

private def trace : Benitoite.Interval.EvalTrace := [leftEvent,rightEvent]

private def code : Comp := embedComp ((Benitoite.Surface.desugarExpr op .other input.source).rename id)

private theorem independent : Benitoite.Interval.EvalPartial env input (.failed .overflow) trace

private theorem environment : EnvRelAt env cap id

private theorem tracked : TrackedFailure .overflow trace

private theorem runtime (σ : PathEnv) : Runs P B σ (fun _ _ => True) (.mk cap code) [] Store.empty (.failed .overflow)

private theorem no_later_delta (ws : List Val) (h : ValuesRel [.integer minimum] ws) :
    ∀ ts r, B.delta "neg" (Ty.normTys (embedTys ts)) [] [] ws ≠ some (.err r)

theorem old_candidate_false : ¬ OldH04

private theorem first_error {P B σ s target events}
    (run : Steps P B σ s events target) :
    H04.BeforeError s → ∀ errors lastK lastStore, target = .error errors lastK lastStore →
    ∃ preEvents before event firstErrors firstK firstStore suffix,
      H04.BeforeErrorSteps P B σ s preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix

private theorem pure_failure {P B σ q k μ event errors firstK firstStore b ts es ranges ws sg}
    (step : Step P B σ (.run q k μ) event (.error errors firstK firstStore))
    (view : q.view = .app (.prim b ts es ranges) ws)
    (signature : B.sig b = some sg) (pure : sg.kind = .pure) :
    event = none ∧ ∃ r, errors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r)

theorem revised_candidate_valid : H04.FirstFailureHandoff

theorem revised_counterexample_accepted (σ : PathEnv) :
    ∃ preEvents before firstErrors firstK firstStore suffix,
      H04.BeforeErrorSteps P B σ (.run (.mk cap code) [] Store.empty) preEvents before ∧
      Step P B σ before none (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error ["LeftError"] [] Store.empty) ∧
      (∃ q k μ, before = .run q k μ ∧ q.view = .app (.prim "neg" [] [] []) [.const (.integer one)]) ∧
      B.delta "neg" [] [] [] [.const (.integer one)] = some (.err "LeftError")
```
