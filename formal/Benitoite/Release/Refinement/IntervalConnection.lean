import Benitoite.Release.Refinement.ControlLeafSelection
import Benitoite.Release.Refinement.FunctionViewGeneral
import Benitoite.Release.Refinement.ApproxAdapter
import Benitoite.Interval.ApproxAdapter
import Benitoite.Interval.BudgetAnalyze
import Benitoite.Interval.Environment
import Benitoite.Surface.Desugar

/-! # 独立評価の値・捕捉・制御と実行の対応 -/
namespace Benitoite.Release.Refinement.IntervalConnection
noncomputable section

/-- 範囲の拒否に含まれる数学上の整数を、宣言順に取り出す。 -/
def rangeErrorFields : Benitoite.Checked.Range.RangeError → List Int
  | .invalidBounds lo hi => [lo,hi]
  | .outOfRange lo hi value => [lo,hi,value]

mutual
/-- Unit・構成子名・引数を区別し、数値は同じ幅の同じ定数へ対応付ける。 -/
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
end

/-- 読まれる some の位置だけ実値を照合する。 -/
inductive EnvValuesRel : List (Option Benitoite.Interval.ConcreteValue) → List (Option Val) → Prop
  | nil : EnvValuesRel [] []
  | hidden {slot cs vs} : EnvValuesRel cs vs → EnvValuesRel (none :: cs) (slot :: vs)
  | value {c v cs vs} : ValueRel c v → EnvValuesRel cs vs → EnvValuesRel (some c :: cs) (some v :: vs)

/-- None の位置は読まず、実際にある局所値を同じ番号の捕捉へ対応付ける。 -/
def EnvRel (env : Benitoite.Interval.ConcreteEnv) (cap : Capture) : Prop :=
  EnvValuesRel env.locals cap.values

def ExprCode (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (source : Benitoite.Surface.Expr) (code : Comp) : Prop :=
  code = embedComp (Benitoite.Surface.desugarExpr op position source)

def BlockCode (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (source : Benitoite.Surface.Block) (code : Comp) : Prop :=
  code = embedComp (Benitoite.Surface.desugarBlock op position source)

def ArmsCode (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (source : Benitoite.Surface.Arms) (arms : List Arm) : Prop :=
  arms = embedArms (Benitoite.Surface.desugarArms op position source)

/-- 失敗理由と実際の理由列の対応は算術・δの葉が具体化する。 -/
def ResultRel (failures : Benitoite.Interval.Failure → List ErrKind → Prop) :
    Benitoite.Interval.EvalOutcome → Shared.EvalResult Val (List ErrKind) → Prop
  | .normal value, .normal v => ValueRel value v
  | .returned value, .returned v => ValueRel value v
  | .failed reason, .failed rs => failures reason rs
  | _, _ => False

/-- 通常の ret と、mark に向かう escape を別の終状態とする。 -/
def EndState (failures : Benitoite.Interval.Failure → List ErrKind → Prop) (outcome : Benitoite.Interval.EvalOutcome)
    (k : Cont) (state : State) : Prop :=
  match outcome with
  | .normal value => ∃ q μ v, state = .run q k μ ∧ q.view = .ret v ∧ ValueRel value v
  | .returned value => ∃ q μ v, state = .run q k μ ∧ q.view = .escape v ∧ ValueRel value v
  | .failed reason => ∃ μ rs, state = .error rs k μ ∧ failures reason rs

/-- 具体の有限な実行だけを受け、全体系の保存や進行を仮定しない。 -/
def Runs (P : Program) (B : Builtins) (σ : PathEnv) (failures : Benitoite.Interval.Failure → List ErrKind → Prop)
    (q : Closure) (k : Cont) (μ : Store) (outcome : Benitoite.Interval.EvalOutcome) (resultCont : Cont := k) : Prop :=
  ∃ events state, Steps P B σ (.run q k μ) events state ∧ EndState failures outcome resultCont state

theorem ValueRel.integer (kind : Benitoite.Interval.IntKind) (n : Benitoite.Interval.IntegerValue kind) :
    ValueRel (.ofInteger kind n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst kind n))) := by
  cases kind with
  | integer64 => exact .integer64 n
  | integer8 => exact .integer8 n
  | integer16 => exact .integer16 n
  | integer32 => exact .integer32 n
  | unsignedInteger16 => exact .unsignedInteger16 n
  | unsignedInteger32 => exact .unsignedInteger32 n
  | unsignedInteger64 => exact .unsignedInteger64 n

/-- 強い関係から観測の一致だけを取り出す。近似から値を構成しない。 -/
theorem ValueRel.toApprox_eq {c v} (h : ValueRel c v) : c.toApprox = v.toApprox := by
  cases h with
  | unit => rfl
  | boolean => rfl
  | integer64 n => rfl
  | integer8 n => exact (Shared.ApproxValue.ofInt_bounded _ n).symm
  | integer16 n => exact (Shared.ApproxValue.ofInt_bounded _ n).symm
  | integer32 n => exact (Shared.ApproxValue.ofInt_bounded _ n).symm
  | unsignedInteger16 n => exact (Shared.ApproxValue.ofInt_bounded _ n).symm
  | unsignedInteger32 n => exact (Shared.ApproxValue.ofInt_bounded _ n).symm
  | unsignedInteger64 n => exact (Shared.ApproxValue.ofInt_bounded _ n).symm
  | other ho _ => exact ho.symm
  | rangeError => rfl
  | con => rfl

/-- 関係にある構造値は同じ tag と再帰的な引数列を持つ。 -/
theorem ValueRel.con_inv {owner types name cs v}
    (h : ValueRel (.con owner types name cs) v) :
    ∃ ts vs, v = .con name ts vs ∧ ValuesRel cs vs := by
  cases h with
  | con hs => exact ⟨_,_,rfl,hs⟩

mutual
theorem ValueRel.close {c v} (h : ValueRel c v) (cap : Capture) : ValueRel c (closeVal cap v) := by
  cases h with
  | unit => exact .unit
  | boolean b => exact .boolean b
  | integer64 n => exact .integer64 n
  | integer8 n => exact .integer8 n
  | integer16 n => exact .integer16 n
  | integer32 n => exact .integer32 n
  | unsignedInteger16 n => exact .unsignedInteger16 n
  | unsignedInteger32 n => exact .unsignedInteger32 n
  | unsignedInteger64 n => exact .unsignedInteger64 n
  | @other t ni nb nu v ho hn =>
    apply ValueRel.other
    · cases v <;> try exact ho
      exact False.elim (hn _ rfl)
    · intro i he
      cases v <;> try cases he
      exact hn _ rfl
  | rangeError values he =>
    simpa only [closeVal,closeVals_eq_map,List.map_map,Function.comp_def] using
      (ValueRel.rangeError (ts := _) values he)
  | con hs => exact .con (hs.close cap)

theorem ValuesRel.close {cs vs} (h : ValuesRel cs vs) (cap : Capture) : ValuesRel cs (closeVals cap vs) := by
  cases h with
  | nil => exact .nil
  | cons hc hs => exact .cons (hc.close cap) (hs.close cap)
end

theorem EnvRel.extend {env cap c v} (h : EnvRel env cap) (hv : ValueRel c v) :
    EnvRel { env with locals := some c :: env.locals } (cap.extend v) :=
  .value hv h

theorem EnvRel.extendMany {env cap cs vs} (h : EnvRel env cap) (hv : ValuesRel cs vs) :
    EnvRel { env with locals := cs.reverse.map some ++ env.locals } (cap.extendMany vs) := by
  cases hv with
  | nil => exact h
  | @cons c v cs vs hc hcs =>
    have hh := EnvRel.extendMany (h.extend hc) hcs
    simpa only [Capture.extendMany,List.foldl_cons,List.reverse_cons,List.map_append,List.map_cons,
      List.map_nil,List.append_assoc,List.singleton_append] using hh

theorem EnvRel.length {env cap} (h : EnvRel env cap) : env.locals.length = cap.values.length :=
by
  cases env with
  | mk locals standards api =>
    cases cap with
    | mk values =>
      change EnvValuesRel locals values at h
      change locals.length = values.length
      induction h with
      | nil => rfl
      | hidden _ ih | value _ _ ih => exact congrArg Nat.succ ih

theorem EndState.result {failures outcome k state} (h : EndState failures outcome k state) :
    ∃ result, ResultRel failures outcome result := by
  cases outcome with
  | normal c => obtain ⟨q,μ,v,_,_,hv⟩ := h; exact ⟨.normal v,hv⟩
  | returned c => obtain ⟨q,μ,v,_,_,hv⟩ := h; exact ⟨.returned v,hv⟩
  | failed reason => obtain ⟨μ,rs,_,hr⟩ := h; exact ⟨.failed rs,hr⟩

theorem steps_trans {P B σ s t u xs ys}
    (h : Steps P B σ s xs t) (g : Steps P B σ t ys u) : Steps P B σ s (xs ++ ys) u := by
  induction h with
  | nil => exact g
  | cons h _ ih => simpa only [List.append_assoc] using Steps.cons h (ih g)

private theorem single {P B σ s event t} (h : Step P B σ s event t) :
    Steps P B σ s event.toList t := by simpa using Steps.cons h (.nil (s := t))

/-- 通常値だけを後続へ束縛し、実行の値で捕捉を延長する。 -/
theorem Runs.let_normal {P B σ failures cap m n k μ c outcome}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.normal c))
    (tail : ∀ v μ', ValueRel c v → Runs P B σ failures (.mk (cap.extend v) n) k μ' outcome) :
    Runs P B σ failures (.mk cap (.letIn m n)) k μ outcome := by
  obtain ⟨events,state,hs,q,μ',v,rfl,hv,hrel⟩ := head
  obtain ⟨rest,last,ht,he⟩ := tail v μ' hrel
  refine ⟨events ++ rest,last,?_,he⟩
  exact .cons (.E_Let rfl) (steps_trans hs (.cons (.E_Return hv) ht))

/-- return は後続の環境を作らず、そのまま let を飛ばす。 -/
theorem Runs.let_returned {P B σ failures cap m n k μ c}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.returned c)) :
    Runs P B σ failures (.mk cap (.letIn m n)) k μ (.returned c) := by
  obtain ⟨events,state,hs,q,μ',v,rfl,hv,hrel⟩ := head
  refine ⟨events,.run (Closure.pure (.escape v)) k μ',?_,
    Closure.pure (.escape v),μ',closeVal Capture.empty v,rfl,rfl,hrel.close _⟩
  simpa using Steps.cons (.E_Let rfl) (steps_trans hs (single (.E_EscLet hv)))

theorem Runs.let_failed {P B σ failures cap m n k μ reason}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.failed reason)) :
    Runs P B σ failures (.mk cap (.letIn m n)) k μ (.failed reason) := by
  obtain ⟨events,state,hs,μ',rs,rfl,hrel⟩ := head
  refine ⟨events,.error rs k μ',?_,μ',rs,rfl,hrel⟩
  simpa using Steps.cons (.E_Let rfl) (steps_trans hs (single .E_ErrPopLet))

/-- return のオペランドの normal は escape になり、returned/failed は同じまま伝播する。 -/
theorem Runs.return_operand {P B σ failures cap m k μ outcome}
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap (.escape (.var 0))) :: k) μ outcome) :
    Runs P B σ failures (.mk cap (.letIn m (.escape (.var 0)))) k μ (Benitoite.Interval.returnOutcome outcome) := by
  cases outcome with
  | normal c =>
    apply head.let_normal
    intro v μ' hv
    exact ⟨[],.run (.mk (cap.extend v) (.escape (.var 0))) k μ',.nil,
      .mk (cap.extend v) (.escape (.var 0)),μ',v,rfl,rfl,hv⟩
  | returned c => exact head.let_returned
  | failed reason => exact head.let_failed

/-- mark は returned の値を通常の ret に戻し、同じ値の観測を保つ。 -/
theorem Runs.returned_mark {P B σ failures q k μ c}
    (h : Runs P B σ failures q (.mark :: k) μ (.returned c)) :
    Runs P B σ failures q (.mark :: k) μ (.normal c) k := by
  obtain ⟨events,state,hs,r,μ',v,rfl,hv,hrel⟩ := h
  exact ⟨events,.run (Closure.pure (.ret v)) k μ',
    by simpa using steps_trans hs (single (.E_EscMark hv)),
    Closure.pure (.ret v),μ',closeVal Capture.empty v,rfl,rfl,hrel.close _⟩

/-- 同じ独立の return 導出と、実際の非末尾コードを結ぶ。 -/
theorem connect_return {P B σ failures env cap op key resultType source type outcome trace m k μ}
    (henv : EnvRel env cap) (hcode : ExprCode op .other source m)
    (eval : Benitoite.Interval.EvalPartial env ⟨source,type,Benitoite.Interval.childKey key []⟩ outcome trace)
    (run : Runs P B σ failures (.mk cap m) (.letF (.mk cap (.escape (.var 0))) :: k) μ outcome) :
    ExprCode op .other (.returnE resultType source) (.letIn m (.escape (.var 0))) ∧
    Benitoite.Interval.EvalPartial env ⟨.returnE resultType source,resultType,key⟩ (Benitoite.Interval.returnOutcome outcome) trace ∧
    EnvRel env cap ∧ Runs P B σ failures (.mk cap (.letIn m (.escape (.var 0)))) k μ (Benitoite.Interval.returnOutcome outcome) := by
  refine ⟨?_,.returnE _ _ _ _ _ _ _ eval,henv,run.return_operand⟩
  exact congrArg (fun code => Comp.letIn code (.escape (.var 0))) hcode

/-- let の独立評価は同じ値を前置し、実行はその値に対応する実値を捕捉へ前置する。 -/
theorem connect_bind {P B σ failures env cap op position key kind boundType source rest type c outcome et rt m n k μ}
    (henv : EnvRel env cap) (hm : ExprCode op .other source m) (hn : BlockCode op position rest n)
    (heval : Benitoite.Interval.EvalPartial env ⟨source,boundType,key⟩ (.normal c) et)
    (teval : Benitoite.Interval.EvalBlock {env with locals := some c :: env.locals} (Benitoite.Interval.advanceKey key (Benitoite.Interval.surfaceSize source)) rest type outcome rt)
    (head : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.normal c))
    (tail : ∀ v μ', ValueRel c v → EnvRel {env with locals := some c :: env.locals} (cap.extend v) →
      Runs P B σ failures (.mk (cap.extend v) n) k μ' outcome) :
    BlockCode op position (.bind kind boundType source rest) (.letIn m n) ∧
    Benitoite.Interval.EvalBlock env key (.bind kind boundType source rest) type outcome (et ++ rt) ∧
    Runs P B σ failures (.mk cap (.letIn m n)) k μ outcome := by
  refine ⟨(by cases hm; cases hn; rfl),.bind _ _ _ _ _ _ _ _ _ _ _ heval teval,?_⟩
  exact head.let_normal (fun v μ' hv => tail v μ' hv (henv.extend hv))

/-- 実際に選んだ束縛列で、元の環境と捕捉を同じ順序に延長する。 -/
theorem runs_match_body {P B σ failures env cap v arms next alts body ws cs k μ outcome}
    (henv : EnvRel env cap) (hvs : ValuesRel cs ws)
    (hi : arms[next]? = some (.mk alts none body)) (hm : firstAlt v alts = some ws)
    (tail : Runs P B σ failures (.mk (cap.extendMany ws) body) k μ outcome) :
    EnvRel {env with locals := cs.reverse.map some ++ env.locals} (cap.extendMany ws) ∧
    ∃ events state, Steps P B σ (.matchRun v cap arms next k μ) events state ∧ EndState failures outcome k state := by
  obtain ⟨events,state,hs,he⟩ := tail
  exact ⟨henv.extendMany hvs,events,state,.cons (.E_MatchBody hi hm) hs,he⟩

/-- guard の真は保存した本体へ戻る。 -/
theorem runs_guard_true {P B σ failures q v cap arms next body k μ outcome}
    (guard : Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.normal (.boolean true)))
    (tail : ∀ μ', Runs P B σ failures body k μ' outcome) :
    Runs P B σ failures q (.guardF v cap arms next body :: k) μ outcome k := by
  obtain ⟨events,state,hs,r,μ',value,rfl,hv,hrel⟩ := guard
  have heq : value = .const (.boolean true) := by
    have he := hrel.toApprox_eq
    simp only [Benitoite.Interval.ConcreteValue.toApprox] at he
    cases value <;> try cases he
    rename_i c
    cases c <;> simp_all [Val.toApprox,Const.toApprox,Shared.ApproxValue.ofInt]
    all_goals split at he <;> cases he
  subst value
  obtain ⟨rest,last,ht,he⟩ := tail μ'
  exact ⟨events ++ rest,last,steps_trans hs (.cons (.E_GuardT hv) ht),he⟩

/-- guard の偽は束縛を追加しない元の照合状態へ戻る。 -/
theorem runs_guard_false {P B σ failures q v cap arms next body k μ}
    (guard : Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.normal (.boolean false))) :
    ∃ events μ', Steps P B σ (.run q (.guardF v cap arms next body :: k) μ) events
      (.matchRun v cap arms next k μ') := by
  obtain ⟨events,state,hs,r,μ',value,rfl,hv,hrel⟩ := guard
  have heq : value = .const (.boolean false) := by
    have he := hrel.toApprox_eq
    simp only [Benitoite.Interval.ConcreteValue.toApprox] at he
    cases value <;> try cases he
    rename_i c
    cases c <;> simp_all [Val.toApprox,Const.toApprox,Shared.ApproxValue.ofInt]
    all_goals split at he <;> cases he
  subst value
  exact ⟨events,μ',by simpa using steps_trans hs (single (.E_GuardF hv))⟩

/-- guard の失敗理由は同じまま外へ伝播する。 -/
theorem runs_guard_failed {P B σ failures q v cap arms next body k μ reason}
    (guard : Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.failed reason)) :
    Runs P B σ failures q (.guardF v cap arms next body :: k) μ (.failed reason) k := by
  obtain ⟨events,state,hs,μ',rs,rfl,hrel⟩ := guard
  exact ⟨events,.error rs k μ',by simpa using steps_trans hs (single .E_ErrPopGuard),μ',rs,rfl,hrel⟩

/-- normalToShared の同値を、実行中の同じ値の観測へ移す。 -/
theorem normal_shared_iff {type range c v} (h : ValueRel c v) (ht : c.type = type) :
    (Benitoite.Interval.normalToShared type range).Mem v.toApprox ↔ Benitoite.Interval.NormalMem type range c := by
  rw [←h.toApprox_eq]
  exact Benitoite.Interval.normalToShared_iff ht

/-- 七幅それぞれで、近似だけでなく元の定数そのものを再構成する。 -/
theorem const_integer_exact {B : Builtins} {c : Const} {kind : Benitoite.Interval.IntKind}
    (hc : ConstOK B c) (hk : Benitoite.Interval.IntKind.ofRefinementType c.type = some kind) :
    ∃ n : Benitoite.Interval.IntegerValue kind,
      c = embedConst (Benitoite.Interval.IntegerValue.toConst kind n) ∧ c.toApprox = .integer kind n := by
  cases c <;> simp [Const.type,Benitoite.Interval.IntKind.ofRefinementType] at hk <;> subst hk
  case integer n => exact ⟨n,rfl,rfl⟩
  case integer8 n => exact ⟨⟨n,hc⟩,rfl,Shared.ApproxValue.ofInt_bounded .integer8 ⟨n,hc⟩⟩
  case integer16 n => exact ⟨⟨n,hc⟩,rfl,Shared.ApproxValue.ofInt_bounded .integer16 ⟨n,hc⟩⟩
  case integer32 n => exact ⟨⟨n,hc⟩,rfl,Shared.ApproxValue.ofInt_bounded .integer32 ⟨n,hc⟩⟩
  case unsignedInteger16 n => exact ⟨⟨n,hc⟩,rfl,Shared.ApproxValue.ofInt_bounded .unsignedInteger16 ⟨n,hc⟩⟩
  case unsignedInteger32 n => exact ⟨⟨n,hc⟩,rfl,Shared.ApproxValue.ofInt_bounded .unsignedInteger32 ⟨n,hc⟩⟩
  case unsignedInteger64 n => exact ⟨⟨n,hc⟩,rfl,Shared.ApproxValue.ofInt_bounded .unsignedInteger64 ⟨n,hc⟩⟩

theorem const_integer_same_value {B : Builtins} {c : Const} {kind : Benitoite.Interval.IntKind}
    (hc : ConstOK B c) (hk : Benitoite.Interval.IntKind.ofRefinementType c.type = some kind)
    (n : Benitoite.Interval.IntegerValue kind) (he : c.toApprox = .integer kind n) :
    c = embedConst (Benitoite.Interval.IntegerValue.toConst kind n) := by
  obtain ⟨m,hm,ha⟩ := const_integer_exact hc hk
  have hmn : m = n := by
    have hh := ha.symm.trans he
    cases hh
    rfl
  exact hmn ▸ hm


/-- 脱糖が加える位置を含め、ソースの通常変数の読取り先を指定する。 -/
def EnvRelAt (env : Benitoite.Interval.ConcreteEnv) (cap : Capture) (ξ : Nat → Nat) : Prop :=
  ∀ i c, env.locals[i]? = some (some c) →
    ∃ v, cap.values[ξ i]? = some (some v) ∧ ValueRel c v

private theorem envValues_lookup {cs vs} {i : Nat} {c : Benitoite.Interval.ConcreteValue} (h : EnvValuesRel cs vs) (hi : cs[i]? = some (some c)) :
    ∃ v, vs[i]? = some (some v) ∧ ValueRel c v := by
  induction h generalizing i with
  | nil => cases hi
  | hidden _ ih => cases i with
    | zero => cases hi
    | succ i => exact ih hi
  | @value c0 v cs vs hv _ ih => cases i with
    | zero => cases hi; exact ⟨v,rfl,hv⟩
    | succ i => exact ih hi

theorem EnvRel.at {env cap} (h : EnvRel env cap) : EnvRelAt env cap id :=
  fun i c hi => envValues_lookup (i := i) (c := c) h hi

/-- 照合値の追加位置はソースから直接読まず、元の全変数を一つずらす。 -/
theorem EnvRelAt.insert {env cap ξ} (h : EnvRelAt env cap ξ) (v : Val) :
    EnvRelAt env (cap.extend v) (fun i => ξ i+1) := by
  intro i c hi
  obtain ⟨w,hw,hr⟩ := h i c hi
  exact ⟨w,hw,hr⟩

theorem EnvRelAt.extend {env cap ξ c v} (h : EnvRelAt env cap ξ) (hv : ValueRel c v) :
    EnvRelAt {env with locals := some c :: env.locals} (cap.extend v) (Benitoite.Release.upRen 1 ξ) := by
  intro i c0 hi
  cases i with
  | zero => cases hi; exact ⟨v,rfl,hv⟩
  | succ i =>
    obtain ⟨w,hw,hr⟩ := h i c0 hi
    exact ⟨w,by simpa [Benitoite.Release.upRen,Nat.add_comm,Capture.extend,Capture.values] using hw,hr⟩

private theorem upRen_zero (ξ : Nat → Nat) : Benitoite.Release.upRen 0 ξ = ξ := by
  funext i; simp [Benitoite.Release.upRen]

private theorem upRen_nested (n m : Nat) (ξ : Nat → Nat) :
    Benitoite.Release.upRen n (Benitoite.Release.upRen m ξ) = Benitoite.Release.upRen (n+m) ξ := by
  funext i
  by_cases hi : i<n
  · simp [Benitoite.Release.upRen,hi,show i<n+m by omega]
  · by_cases hj : i-n<m
    · simp only [Benitoite.Release.upRen,hi,hj,show i<n+m by omega,ite_false,ite_true]
      omega
    · simp only [Benitoite.Release.upRen,hi,hj,show ¬i<n+m by omega,ite_false]
      rw [show i-n-m = i-(n+m) by omega]
      omega

theorem EnvRelAt.extendMany {env cap ξ cs vs} (h : EnvRelAt env cap ξ) (hv : ValuesRel cs vs) :
    EnvRelAt {env with locals := cs.reverse.map some ++ env.locals} (cap.extendMany vs)
      (Benitoite.Release.upRen vs.length ξ) := by
  cases hv with
  | nil => simpa only [List.reverse_nil,List.map_nil,List.nil_append,Capture.extendMany,List.foldl_nil,
      List.length_nil,upRen_zero] using h
  | @cons c v cs vs hc hcs =>
    have hh := EnvRelAt.extendMany (h.extend hc) hcs
    simpa only [Capture.extendMany,List.foldl_cons,List.reverse_cons,List.map_append,List.map_cons,
      List.map_nil,List.append_assoc,List.singleton_append,List.length_cons,upRen_nested,
      Nat.add_comm] using hh

/-- 腕の本体のコードと、その自由変数が指す捕捉を同じ改名で対応付ける。 -/
def ArmBodyConnection (env : Benitoite.Interval.ConcreteEnv) (cap : Capture) (ξ : Nat → Nat)
    (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (body : Benitoite.Surface.Block)
    (code : Comp) (cs : List Benitoite.Interval.ConcreteValue) (vs : List Val) : Prop :=
  EnvRelAt {env with locals := cs.reverse.map some ++ env.locals} (cap.extendMany vs) (Benitoite.Release.upRen vs.length ξ) ∧
    code = embedComp ((Benitoite.Surface.desugarBlock op position body).rename (Benitoite.Release.upRen vs.length ξ))

/-- パターンの失敗を区別し、成功時には束縛列を再帰的に対応付ける。 -/
def MatchRel : Option (List Benitoite.Interval.ConcreteValue) → Option (List Val) → Prop
  | none, none => True
  | some cs, some vs => ValuesRel cs vs
  | _, _ => False

private theorem values_lookup {cs vs} (h : ValuesRel cs vs) (i : Nat) :
    match cs[i]?,vs[i]? with
    | none,none => True
    | some c,some v => ValueRel c v
    | _,_ => False := by
  cases h with
  | nil => simp
  | cons hc hs => cases i with
    | zero => exact hc
    | succ i => exact values_lookup hs i

private theorem slots_related {cs vs} (h : ValuesRel cs vs) (slots : List Nat) :
    MatchRel (Benitoite.Release.selectSlots cs slots) (selectSlots vs slots) := by
  induction slots with
  | nil => exact ValuesRel.nil
  | cons i slots ih =>
    have hi := values_lookup h i
    cases hc : cs[i]? <;> cases hv : vs[i]? <;> simp only [hc,hv] at hi
    · simp [Benitoite.Release.selectSlots,selectSlots,hc,hv,MatchRel]
    · cases ht : Benitoite.Release.selectSlots cs slots <;> cases hw : selectSlots vs slots <;>
        simp only [ht,hw,MatchRel] at ih
      · simp [Benitoite.Release.selectSlots,selectSlots,hc,hv,ht,hw,MatchRel]
      · simpa [Benitoite.Release.selectSlots,selectSlots,hc,hv,ht,hw,MatchRel] using ValuesRel.cons hi ih

/-- 具体の Result の tag と payload が関係すれば、許されるパターンの成否も一致する。 -/
theorem result_pattern_related {names types tag payload runtime pattern}
    (h : ValueRel (.con names.result types tag [payload]) runtime)
    (hp : Benitoite.Interval.rangeResultPattern names pattern = true) :
    MatchRel (Benitoite.Interval.resultPatternMatch names (.con names.result types tag [payload]) tag payload pattern)
      (matchVal pattern.toCore runtime) := by
  obtain ⟨ts,vs,rfl,hvs⟩ := h.con_inv
  cases hvs with
  | cons hv ht =>
    cases ht
    cases pattern <;> simp [Benitoite.Interval.rangeResultPattern] at hp
    case wild => exact ValuesRel.nil
    case var => exact ValuesRel.cons (.con (.cons hv .nil)) .nil
    case con qualifier expected args =>
      cases args with
      | nil => cases hp
      | cons p ps =>
        cases ps with
        | cons p2 ps => cases p <;> simp at hp
        | nil =>
          cases p <;> simp at hp
          all_goals
            have hqual : (qualifier.isNone || qualifier == some names.result) = true := by simpa using hp.1
            simp only [Benitoite.Interval.resultPatternMatch,hqual,Bool.true_and,
              Benitoite.Surface.Pattern.toCore,Benitoite.Surface.Pattern.toCoreList,matchVal,matchList]
            split <;> rename_i he
            · simp only [beq_iff_eq] at he
              subst expected
              simp [MatchRel,ValuesRel.nil,ValuesRel.cons,hv]
            · have hn : expected ≠ tag := by simpa using he
              simp [hn,MatchRel]

/-- 独立評価の選択と同じ順序・同じ slots を使う補助の計算。 -/
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
      (firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts)) := by
  induction alts with
  | nil => trivial
  | cons alt rest ih =>
    have hr := result_pattern_related h (hp alt List.mem_cons_self)
    have ih := ih (fun a ha => hp a (List.mem_cons_of_mem _ ha))
    cases hc : Benitoite.Interval.resultPatternMatch names (.con names.result types tag [payload]) tag payload alt.pat <;>
      cases hv : matchVal alt.pat.toCore runtime <;> simp only [hc,hv,MatchRel] at hr
    · simpa [firstResultAlt,firstAlt,Benitoite.Surface.Alternative.toCoreList,Benitoite.Surface.Alternative.toCore,hc,hv] using ih
    · simpa [firstResultAlt,firstAlt,Benitoite.Surface.Alternative.toCoreList,Benitoite.Surface.Alternative.toCore,hc,hv] using slots_related hr alt.slots

private theorem result_selection_first {names value tag payload alts selected}
    (h : Benitoite.Interval.ResultSelection names value tag payload alts selected) :
    firstResultAlt names value tag payload alts = some selected := by
  obtain ⟨before,alt,after,raw,rfl,miss,hm,hs,hlen⟩ := h
  clear hlen
  induction before with
  | nil => simp [firstResultAlt,hm,hs]
  | cons prior before ih =>
    simp only [List.cons_append,firstResultAlt,List.foldr_cons,miss prior List.mem_cons_self]
    exact ih (fun a ha => miss a (List.mem_cons_of_mem _ ha))

/-- 独立評価の選択から実際の最初の照合と、その同じ束縛列を得る。 -/
theorem result_selection_related {names types tag payload runtime alts selected}
    (h : ValueRel (.con names.result types tag [payload]) runtime)
    (hp : ∀ alt ∈ alts, Benitoite.Interval.rangeResultPattern names alt.pat = true)
    (selection : Benitoite.Interval.ResultSelection names (.con names.result types tag [payload]) tag payload alts selected) :
    ∃ ws, firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) = some ws ∧ ValuesRel selected ws := by
  have hr := first_result_related h hp
  rw [result_selection_first selection] at hr
  cases hm : firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) with
  | none => simp [hm,MatchRel] at hr
  | some ws => exact ⟨ws,rfl,by simpa [hm,MatchRel] using hr⟩

/-- 同じ独立評価の三つの腕を、実際の照合成功・束縛列・実行へ接続する。 -/
theorem connect_integer_arm {P B σ failures env cap key value alternatives sourceBody sourceRest type selected outcome trace
    runtimeValue arms next code ws k μ ξ op position}
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : Benitoite.Interval.IntegerSelection alternatives value selected)
    (eval : Benitoite.Interval.EvalBlock {env with locals := selected.reverse.map some ++ env.locals}
      key sourceBody type outcome trace)
    (hvalue : ValueRel (.integer value) runtimeValue)
    (hcode : code = embedComp ((Benitoite.Surface.desugarBlock op position sourceBody).rename (Benitoite.Release.upRen ws.length ξ)))
    (hi : arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alternatives) none code))
    (hm : firstAlt runtimeValue (Benitoite.Surface.Alternative.toCoreList alternatives) = some ws)
    (run : Runs P B σ failures (.mk (cap.extendMany ws) code) k μ outcome) :
    Benitoite.Interval.EvalArms env key value (.cons alternatives none sourceBody sourceRest) type outcome trace ∧
    ValueRel (.integer value) runtimeValue ∧ ArmBodyConnection env cap ξ op position sourceBody code selected ws ∧
    ∃ events state, Steps P B σ (.matchRun runtimeValue cap arms next k μ) events state ∧ EndState failures outcome k state := by
  obtain ⟨events,state,hs,he⟩ := run
  exact ⟨.body _ _ _ _ _ _ _ _ _ _ selection eval,hvalue,⟨henv.extendMany hvs,hcode⟩,events,state,.cons (.E_MatchBody hi hm) hs,he⟩

theorem connect_width_arm {P B σ failures env cap key kind value alternatives sourceBody sourceRest type selected outcome trace
    runtimeValue arms next code ws k μ ξ op position}
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : Benitoite.Interval.WidthSelection alternatives kind value selected)
    (eval : Benitoite.Interval.EvalBlock {env with locals := selected.reverse.map some ++ env.locals}
      key sourceBody type outcome trace)
    (hvalue : ValueRel (.ofInteger kind value) runtimeValue)
    (hcode : code = embedComp ((Benitoite.Surface.desugarBlock op position sourceBody).rename (Benitoite.Release.upRen ws.length ξ)))
    (hi : arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alternatives) none code))
    (hm : firstAlt runtimeValue (Benitoite.Surface.Alternative.toCoreList alternatives) = some ws)
    (run : Runs P B σ failures (.mk (cap.extendMany ws) code) k μ outcome) :
    Benitoite.Interval.EvalWidthArms env key kind value (.cons alternatives none sourceBody sourceRest) type outcome trace ∧
    ValueRel (.ofInteger kind value) runtimeValue ∧ ArmBodyConnection env cap ξ op position sourceBody code selected ws ∧
    ∃ events state, Steps P B σ (.matchRun runtimeValue cap arms next k μ) events state ∧ EndState failures outcome k state := by
  obtain ⟨events,state,hs,he⟩ := run
  exact ⟨.body _ _ _ _ _ _ _ _ _ _ _ selection eval,hvalue,⟨henv.extendMany hvs,hcode⟩,events,state,.cons (.E_MatchBody hi hm) hs,he⟩

theorem connect_result_arm {P B σ failures env cap key names types tag payload alternatives sourceBody sourceRest type selected outcome trace
    runtimeValue arms next k μ ξ op position}
    (henv : EnvRelAt env cap ξ)
    (patterns : ∀ alt ∈ alternatives, Benitoite.Interval.rangeResultPattern names alt.pat = true)
    (selection : Benitoite.Interval.ResultSelection names (.con names.result types tag [payload]) tag payload alternatives selected)
    (eval : Benitoite.Interval.EvalBlock {env with locals := selected.reverse.map some ++ env.locals}
      key sourceBody type outcome trace)
    (hvalue : ValueRel (.con names.result types tag [payload]) runtimeValue)
    (branch : ∀ ws, firstAlt runtimeValue (Benitoite.Surface.Alternative.toCoreList alternatives) = some ws →
      ValuesRel selected ws → ∃ code,
        code = embedComp ((Benitoite.Surface.desugarBlock op position sourceBody).rename (Benitoite.Release.upRen ws.length ξ)) ∧
        arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alternatives) none code) ∧
        Runs P B σ failures (.mk (cap.extendMany ws) code) k μ outcome) :
    Benitoite.Interval.EvalResultArms env key names (.con names.result types tag [payload]) tag payload (.cons alternatives none sourceBody sourceRest) type outcome trace ∧
    ValueRel (.con names.result types tag [payload]) runtimeValue ∧
    (∃ code ws, ArmBodyConnection env cap ξ op position sourceBody code selected ws) ∧
    ∃ events state, Steps P B σ (.matchRun runtimeValue cap arms next k μ) events state ∧ EndState failures outcome k state := by
  obtain ⟨ws,hm,hvs⟩ := result_selection_related hvalue patterns selection
  obtain ⟨code,hcode,hi,run⟩ := branch ws hm hvs
  obtain ⟨events,state,hs,he⟩ := run
  exact ⟨.body _ _ _ _ _ _ _ _ _ _ _ _ _ selection eval,hvalue,⟨code,ws,henv.extendMany hvs,hcode⟩,
    events,state,.cons (.E_MatchBody hi hm) hs,he⟩

/-- 照合失敗は束縛を増やさず、次の腕の実行へ進む。 -/
theorem runs_match_skip {P B σ failures v cap arms next alts guard body k μ outcome}
    (hi : arms[next]? = some (.mk alts guard body)) (hm : firstAlt v alts = none)
    (tail : ∃ events state, Steps P B σ (.matchRun v cap arms (next+1) k μ) events state ∧ EndState failures outcome k state) :
    ∃ events state, Steps P B σ (.matchRun v cap arms next k μ) events state ∧ EndState failures outcome k state := by
  obtain ⟨events,state,hs,he⟩ := tail
  exact ⟨events,state,.cons (.E_MatchSkip hi hm) hs,he⟩

/-- guard を評価する状態は、同じ実束縛を持つ。 -/
theorem runs_match_guard {P B σ failures v cap arms next alts guard body ws k μ outcome}
    (hi : arms[next]? = some (.mk alts (some guard) body)) (hm : firstAlt v alts = some ws)
    (tail : Runs P B σ failures (.mk (cap.extendMany ws) guard)
      (.guardF v cap arms (next+1) (.mk (cap.extendMany ws) body) :: k) μ outcome k) :
    ∃ events state, Steps P B σ (.matchRun v cap arms next k μ) events state ∧ EndState failures outcome k state := by
  obtain ⟨events,state,hs,he⟩ := tail
  exact ⟨events,state,.cons (.E_MatchGuard hi hm) hs,he⟩

/-- 既存の三つの独立した腕の評価を区別する入力。 -/
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

/-- 三種類の skip の独立評価と、次の実際の腕への遷移をともに構成する。 -/
theorem connect_arm_skip {P B σ failures env key alts guard body rest type outcome trace
    runtime cap arms next codeGuard codeBody k μ} (input : ArmInput)
    (miss : input.Miss alts)
    (eval : input.Eval env (Benitoite.Interval.advanceKey key (Benitoite.Interval.guardSize guard + Benitoite.Interval.blockSize body)) rest type outcome trace)
    (hi : arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alts) codeGuard codeBody))
    (hm : firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) = none)
    (tail : ∃ events state, Steps P B σ (.matchRun runtime cap arms (next+1) k μ) events state ∧ EndState failures outcome k state) :
    input.Eval env key (.cons alts guard body rest) type outcome trace ∧
    ∃ events state, Steps P B σ (.matchRun runtime cap arms next k μ) events state ∧ EndState failures outcome k state := by
  constructor
  · cases input with
    | integer => exact .skip _ _ _ _ _ _ _ _ _ _ miss eval
    | width => exact .skip _ _ _ _ _ _ _ _ _ _ _ miss eval
    | result => exact .skip _ _ _ _ _ _ _ _ _ _ _ _ _ miss eval
  · exact runs_match_skip hi hm tail

/-- 同じ束縛列の guard が真なら、三種類とも本体へ接続する。 -/
theorem connect_arm_guard_true {P B σ failures env cap ξ key alts guard body rest type selected outcome gt bt
    runtime arms next codeGuard codeBody ws k μ} (input : ArmInput)
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : input.Selection alts selected)
    (condition : Benitoite.Interval.EvalPartial {env with locals := selected.reverse.map some ++ env.locals}
      ⟨guard,.base .boolean,key⟩ (.normal (.boolean true)) gt)
    (eval : Benitoite.Interval.EvalBlock {env with locals := selected.reverse.map some ++ env.locals}
      (Benitoite.Interval.advanceKey key (Benitoite.Interval.surfaceSize guard)) body type outcome bt)
    (hi : arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alts) (some codeGuard) codeBody))
    (hm : firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) = some ws)
    (guardRun : Runs P B σ failures (.mk (cap.extendMany ws) codeGuard)
      (.guardF runtime cap arms (next+1) (.mk (cap.extendMany ws) codeBody) :: k) μ (.normal (.boolean true)))
    (bodyRun : ∀ μ', Runs P B σ failures (.mk (cap.extendMany ws) codeBody) k μ' outcome) :
    input.Eval env key (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
    EnvRelAt {env with locals := selected.reverse.map some ++ env.locals} (cap.extendMany ws) (Benitoite.Release.upRen ws.length ξ) ∧
    ∃ events state, Steps P B σ (.matchRun runtime cap arms next k μ) events state ∧ EndState failures outcome k state := by
  refine ⟨?_,henv.extendMany hvs,runs_match_guard hi hm (runs_guard_true guardRun bodyRun)⟩
  cases input with
  | integer => exact .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ selection condition eval
  | width => exact .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition eval
  | result => exact .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition eval

/-- guard が偽なら、元の環境の次の腕の独立評価と実行へ接続する。 -/
theorem connect_arm_guard_false {P B σ failures env cap ξ key alts guard body rest type selected outcome gt rt
    runtime arms next codeGuard codeBody ws k μ} (input : ArmInput)
    (henv : EnvRelAt env cap ξ) (hvs : ValuesRel selected ws)
    (selection : input.Selection alts selected)
    (condition : Benitoite.Interval.EvalPartial {env with locals := selected.reverse.map some ++ env.locals}
      ⟨guard,.base .boolean,key⟩ (.normal (.boolean false)) gt)
    (eval : input.Eval env (Benitoite.Interval.advanceKey key (Benitoite.Interval.surfaceSize guard + Benitoite.Interval.blockSize body)) rest type outcome rt)
    (hi : arms[next]? = some (.mk (Benitoite.Surface.Alternative.toCoreList alts) (some codeGuard) codeBody))
    (hm : firstAlt runtime (Benitoite.Surface.Alternative.toCoreList alts) = some ws)
    (guardRun : Runs P B σ failures (.mk (cap.extendMany ws) codeGuard)
      (.guardF runtime cap arms (next+1) (.mk (cap.extendMany ws) codeBody) :: k) μ (.normal (.boolean false)))
    (tail : ∀ μ', ∃ events state, Steps P B σ (.matchRun runtime cap arms (next+1) k μ') events state ∧ EndState failures outcome k state) :
    input.Eval env key (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
    EnvRelAt {env with locals := selected.reverse.map some ++ env.locals} (cap.extendMany ws) (Benitoite.Release.upRen ws.length ξ) ∧
    ∃ events state, Steps P B σ (.matchRun runtime cap arms next k μ) events state ∧ EndState failures outcome k state := by
  refine ⟨?_,henv.extendMany hvs,?_⟩
  · cases input with
    | integer => exact .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ selection condition eval
    | width => exact .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition eval
    | result => exact .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition eval
  · obtain ⟨events,μ',hs⟩ := runs_guard_false guardRun
    obtain ⟨rest,state,ht,he⟩ := tail μ'
    exact runs_match_guard hi hm ⟨events ++ rest,state,steps_trans hs ht,he⟩

/-- 実際の trace に記録された同じ失敗理由だけを候補の対象にする。 -/
def TrackedFailure (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace) : Prop :=
  reason ≠ .unknown ∧ ∃ event ∈ trace, event.result = .rejected reason

/-- 子で得た失敗の対応は、同じ独立評価の let の外でも維持される。 -/
theorem connect_bind_failed {P B σ failures env cap key kind boundType source rest type reason trace m n k μ}
    (eval : Benitoite.Interval.EvalPartial env ⟨source,boundType,key⟩ (.failed reason) trace)
    (run : Runs P B σ failures (.mk cap m) (.letF (.mk cap n) :: k) μ (.failed reason)) :
    Benitoite.Interval.EvalBlock env key (.bind kind boundType source rest) type (.failed reason) trace ∧
      Runs P B σ failures (.mk cap (.letIn m n)) k μ (.failed reason) :=
  ⟨.bindAbrupt _ _ _ _ _ _ _ _ _ eval trivial,run.let_failed⟩

/-- guard を持つ場合も、脱糖で追加した照合値の一位置を残す。 -/
theorem arms_code_cons {op position alternatives guard body rest arms}
    (h : ArmsCode op position (.cons alternatives guard body rest) arms) :
    arms = .mk (Benitoite.Surface.Alternative.toCoreList alternatives)
      (guard.map (fun g => embedComp ((Benitoite.Surface.desugarExpr op .other g).rename
        (Benitoite.Release.upRen (Benitoite.Release.Arm.bindersOf (Benitoite.Surface.Alternative.toCoreList alternatives)) (·+1)))))
      (embedComp ((Benitoite.Surface.desugarBlock op position body).rename
        (Benitoite.Release.upRen (Benitoite.Release.Arm.bindersOf (Benitoite.Surface.Alternative.toCoreList alternatives)) (·+1)))) ::
      embedArms (Benitoite.Surface.desugarArms op position rest) := by
  cases guard <;> exact h

/-- 型付きの source の戻り先は、既存の escape の葉で検査される。 -/
theorem typed_returned_mark {P B σ Eb q k μ c v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.mark :: k) μ))
    (hv : q.view = .escape v) (hrel : ValueRel c v) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) ∧
    EndState (fun _ _ => False) (.normal c) k (.run (Closure.pure (.ret v)) k μ) := by
  have hdest := (source.escape_mark hP hPB hB hv).2
  exact ⟨hdest,Closure.pure (.ret v),μ,closeVal Capture.empty v,rfl,rfl,hrel.close _⟩

end
end Benitoite.Release.Refinement.IntervalConnection
