import Benitoite.Release.Refinement.IntervalConnection

/-! # 正常値と return の局所的な所属 -/
namespace Benitoite.Release.Refinement.IntervalFlowLeaves
open Benitoite.Interval
open IntervalConnection
open Shared

def joinV : ValueApprox → ValueApprox → ValueApprox
  | .bottom, b => b
  | a, .bottom => a
  | .integer k a, .integer l b =>
      if same : l = k then .integer k (Benitoite.Interval.join a (same ▸ b)) else .unknown
  | .boolean f t, .boolean g u => .boolean (f || g) (t || u)
  | _, _ => .unknown

def normalF (a : ValueApprox) : FlowApprox := ⟨a,.bottom,false⟩
def returnF (f : FlowApprox) : FlowApprox := ⟨.bottom,joinV f.normal f.returned,f.mayFail⟩
def joinF (f g : FlowApprox) : FlowApprox :=
  ⟨joinV f.normal g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩
def seqF (f g : FlowApprox) : FlowApprox :=
  ⟨g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩

private theorem joinV_mem {a b : ValueApprox} {v : ApproxValue}
    (h : a.Mem v ∨ b.Mem v) : (joinV a b).Mem v := by
  cases a with
  | bottom => simpa only [ValueApprox.Mem,joinV,false_or] using h
  | unknown => cases b <;> trivial
  | integer k a =>
    cases b with
    | bottom => simpa only [ValueApprox.Mem,or_false,joinV] using h
    | unknown | boolean => trivial
    | integer l b =>
      by_cases eq : l = k
      · subst l
        simp only [joinV]
        cases v with
        | integer m v =>
          simp only [ValueApprox.Mem] at h ⊢
          have same : m = k := h.elim And.left And.left
          exact ⟨same,Benitoite.Interval.mem_join (h.elim (fun h => .inl h.2) (fun h => .inr h.2))⟩
        | boolean | other => cases h <;> contradiction
      · simp only [joinV,dite_eq_right eq,ValueApprox.Mem]
  | boolean f t =>
    cases b with
    | bottom => simpa only [ValueApprox.Mem,or_false,joinV] using h
    | unknown | integer => trivial
    | boolean g u =>
      cases v with
      | boolean v => cases v <;> simpa [joinV,ValueApprox.Mem,Bool.or_eq_true] using h
      | integer | other => cases h <;> contradiction

theorem joinV_left {a b v} (h : a.Mem v) : (joinV a b).Mem v := joinV_mem (.inl h)
theorem joinV_right {a b v} (h : b.Mem v) : (joinV a b).Mem v := joinV_mem (.inr h)

theorem normal_mem {a v} (h : a.Mem v) : (normalF a).NormalMem v := h

theorem return_mem {f : FlowApprox} {outcome : EvalOutcome}
    (h : f.ResultMem outcome.toApprox) :
    (returnF f).ResultMem (returnOutcome outcome).toApprox := by
  cases outcome with
  | normal c => exact joinV_left h
  | returned c => exact joinV_right h
  | failed r => exact h

theorem join_left {f g : FlowApprox} {outcome : EvalOutcome}
    (h : f.ResultMem outcome.toApprox) : (joinF f g).ResultMem outcome.toApprox := by
  cases outcome with
  | normal c => exact joinV_left h
  | returned c => exact joinV_left h
  | failed r =>
    change f.mayFail = true at h
    change (f.mayFail || g.mayFail) = true
    simp only [h,Bool.true_or]

theorem join_right {f g : FlowApprox} {outcome : EvalOutcome}
    (h : g.ResultMem outcome.toApprox) : (joinF f g).ResultMem outcome.toApprox := by
  cases outcome with
  | normal c => exact joinV_right h
  | returned c => exact joinV_right h
  | failed r =>
    change g.mayFail = true at h
    change (f.mayFail || g.mayFail) = true
    simp only [h,Bool.or_true]

theorem seq_tail {f g : FlowApprox} {outcome : EvalOutcome}
    (h : g.ResultMem outcome.toApprox) : (seqF f g).ResultMem outcome.toApprox := by
  cases outcome with
  | normal c => exact h
  | returned c => exact joinV_right h
  | failed r =>
    change g.mayFail = true at h
    change (f.mayFail || g.mayFail) = true
    simp only [h,Bool.or_true]

theorem seq_abrupt {f g : FlowApprox} {outcome : EvalOutcome} (abrupt : outcome.Abrupt)
    (h : f.ResultMem outcome.toApprox) : (seqF f g).ResultMem outcome.toApprox := by
  cases outcome with
  | normal c => exact False.elim abrupt
  | returned c => exact joinV_left h
  | failed r =>
    change f.mayFail = true at h
    change (f.mayFail || g.mayFail) = true
    simp only [h,Bool.true_or]

theorem normal_mem_of_related {f : FlowApprox} {c v}
    (h : ValueRel c v) (hc : f.NormalMem c.toApprox) : f.NormalMem v.toApprox := by
  rw [←h.toApprox_eq]; exact hc

theorem returned_mem_of_related {f : FlowApprox} {c v}
    (h : ValueRel c v) (hc : f.ReturnedMem c.toApprox) : f.ReturnedMem v.toApprox := by
  rw [←h.toApprox_eq]; exact hc

/-- 同じ子の評価から return の評価と returned の所属を構成する。 -/
theorem return_leaf {env key resultType source type outcome trace f}
    (eval : EvalPartial env ⟨source,type,childKey key []⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalPartial env ⟨.returnE resultType source,resultType,key⟩ (returnOutcome outcome) trace ∧
      (returnF f).ResultMem (returnOutcome outcome).toApprox :=
  ⟨.returnE _ _ _ _ _ _ _ eval,return_mem mem⟩

/-- 真の枝の同じ本体の結果を、条件のフローに続く二枝の合流へ入れる。 -/
theorem if_true_leaf {h f g : FlowApprox} {env key cond yes no type outcome ct bt}
    (condition : EvalPartial env ⟨cond,.base .boolean,childKey key []⟩ (.normal (.boolean true)) ct)
    (branch : EvalBlock env (childKey key [cond]) yes type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalPartial env ⟨.ite cond yes no,type,key⟩ outcome (ct++bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.iteTrue _ _ _ _ _ _ _ _ _ condition branch,seq_tail (join_left mem)⟩

theorem if_false_leaf {h f g : FlowApprox} {env key cond yes no type outcome ct bt}
    (condition : EvalPartial env ⟨cond,.base .boolean,childKey key []⟩ (.normal (.boolean false)) ct)
    (branch : EvalBlock env (childKey key (cond :: blockChildren yes)) no type outcome bt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalPartial env ⟨.ite cond yes no,type,key⟩ outcome (ct++bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.iteFalse _ _ _ _ _ _ _ _ _ condition branch,seq_tail (join_right mem)⟩

/-- iteAbrupt の実構成から、同じ結果の局所所属を作る。 -/
theorem if_abrupt_leaf {h f g : FlowApprox} {env key cond yes no type outcome ct}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ outcome ct)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.ite cond yes no, type, key⟩ outcome ct ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.iteAbrupt env key cond yes no type outcome ct condition abrupt, seq_abrupt abrupt mem⟩

/-- elseIfTrue の実構成から、同じ結果の局所所属を作る。 -/
theorem else_if_true_leaf {h f g : FlowApprox} {env key cond yes no type outcome ct bt}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean true)) ct)
      (branch : EvalBlock env (childKey key [cond]) yes type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome (ct ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.elseIfTrue env key cond yes no type outcome ct bt condition branch, seq_tail (join_left mem)⟩

/-- elseIfFalse の実構成から、同じ結果の局所所属を作る。 -/
theorem else_if_false_leaf {h f g : FlowApprox} {env key cond yes no type outcome ct bt}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean false)) ct)
      (branch : EvalPartial env ⟨no, type, childKey key (cond :: blockChildren yes)⟩ outcome bt)
    (mem : g.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome (ct ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.elseIfFalse env key cond yes no type outcome ct bt condition branch, seq_tail (join_right mem)⟩

/-- elseIfAbrupt の実構成から、同じ結果の局所所属を作る。 -/
theorem else_if_abrupt_leaf {h f g : FlowApprox} {env key cond yes no type outcome ct}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ outcome ct)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome ct ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.elseIfAbrupt env key cond yes no type outcome ct condition abrupt, seq_abrupt abrupt mem⟩

/-- ifOnlyTrue の実構成から、同じ結果の局所所属を作る。 -/
theorem if_only_true_leaf {h f : FlowApprox} {env key cond yes outcome ct bt}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean true)) ct)
      (branch : EvalBlock env (childKey key [cond]) yes (.base .unit) outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ outcome (ct ++ bt) ∧
      (seqF h (joinF f (normalF .unknown))).ResultMem outcome.toApprox :=
  ⟨.ifOnlyTrue env key cond yes outcome ct bt condition branch, seq_tail (join_left mem)⟩

/-- ifOnlyFalse の実構成から、同じ結果の局所所属を作る。 -/
theorem if_only_false_leaf {h f : FlowApprox} {env key cond yes ct}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean false)) ct) :
      EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ (.normal .unit) ct ∧
      (seqF h (joinF f (normalF .unknown))).ResultMem (EvalOutcome.normal .unit).toApprox :=
  ⟨.ifOnlyFalse env key cond yes ct condition, seq_tail (join_right (show (normalF .unknown).ResultMem (EvalOutcome.normal .unit).toApprox from trivial))⟩

/-- ifOnlyAbrupt の実構成から、同じ結果の局所所属を作る。 -/
theorem if_only_abrupt_leaf {h f : FlowApprox} {env key cond yes outcome ct}
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ outcome ct)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ outcome ct ∧
      (seqF h (joinF f (normalF .unknown))).ResultMem outcome.toApprox :=
  ⟨.ifOnlyAbrupt env key cond yes outcome ct condition abrupt, seq_abrupt abrupt mem⟩

/-- block の実構成から、同じ結果の局所所属を作る。 -/
theorem expression_block_leaf {f : FlowApprox} {env key body type outcome trace}
      (eval : EvalBlock env (childKey key []) body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.block body, type, key⟩ outcome trace ∧
      (f).ResultMem outcome.toApprox :=
  ⟨.block env key body type outcome trace eval, mem⟩

/-- matchInteger の実構成から、同じ結果の局所所属を作る。 -/
theorem match_integer_leaf {h f : FlowApprox} {env key source arms type value outcome st armTrace}
      (scrutinee : EvalPartial env ⟨source, .base .integer, childKey key []⟩ (.normal (.integer value)) st)
      (selected : EvalArms env (childKey key [source]) value arms type outcome armTrace)
    (mem : f.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome (st ++ armTrace) ∧
      (seqF h f).ResultMem outcome.toApprox :=
  ⟨.matchInteger env key source arms type value outcome st armTrace scrutinee selected, seq_tail mem⟩

/-- matchWidth の実構成から、同じ結果の局所所属を作る。 -/
theorem match_width_leaf {h f : FlowApprox} {env key kind source arms type value outcome st armTrace}
      (not64 : kind ≠ .integer64)
      (scrutinee : EvalPartial env ⟨source, kind.type, childKey key []⟩
        (.normal (.ofInteger kind value)) st)
      (selected : EvalWidthArms env (childKey key [source]) kind value arms type outcome armTrace)
    (mem : f.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome (st ++ armTrace) ∧
      (seqF h f).ResultMem outcome.toApprox :=
  ⟨.matchWidth env key kind source arms type value outcome st armTrace not64 scrutinee selected, seq_tail mem⟩

/-- matchResult の実構成から、同じ結果の局所所属を作る。 -/
theorem match_result_leaf {h f : FlowApprox} {env key source arms type sourceType value names tag payload outcome st armTrace}
      (recognized : rangeResultMatch env value arms = some names)
      (view : names.ResultView value tag payload)
      (scrutinee : EvalPartial env ⟨source, sourceType, childKey key []⟩ (.normal value) st)
      (selected : EvalResultArms env (childKey key [source]) names value tag payload
        arms type outcome armTrace)
    (mem : f.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome (st ++ armTrace) ∧
      (seqF h f).ResultMem outcome.toApprox :=
  ⟨.matchResult env key source arms type sourceType value names tag payload outcome st armTrace recognized view scrutinee selected, seq_tail mem⟩

/-- matchAbrupt の実構成から、同じ結果の局所所属を作る。 -/
theorem match_abrupt_leaf {h f : FlowApprox} {env key source arms type sourceType outcome st}
      (scrutinee : EvalPartial env ⟨source, sourceType, childKey key []⟩ outcome st)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome st ∧
      (seqF h f).ResultMem outcome.toApprox :=
  ⟨.matchAbrupt env key source arms type sourceType outcome st scrutinee abrupt, seq_abrupt abrupt mem⟩

private theorem discard_mem {f : FlowApprox} {outcome : EvalOutcome}
    (mem : f.ResultMem outcome.toApprox) :
    (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox := by
  cases outcome with
  | normal c => exact normal_mem (by trivial)
  | returned c => exact seq_abrupt (by trivial) mem
  | failed r => exact seq_abrupt (by trivial) mem

/-- Block の empty の実構成と局所所属。 -/
theorem block_empty  (env key) :
    EvalBlock env key .empty (.base .unit) (.normal .unit) [] ∧
      (normalF .unknown).ResultMem (.normal ConcreteValue.unit : EvalOutcome).toApprox :=
  ⟨.empty env key, normal_mem (by trivial)⟩

example  (env key) :
    EvalBlock env key .empty (.base .unit) (.normal .unit) [] ∧
      (normalF .unknown).ResultMem (.normal ConcreteValue.unit : EvalOutcome).toApprox :=
  block_empty env key

/-- Block の builderBind の実構成と局所所属。 -/
theorem block_builderBind {f : FlowApprox} (env key kind rest type outcome trace)
      (eval : EvalBlock { env with locals := none :: env.locals } key rest type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.builderBind kind rest) type outcome trace ∧
      (f).ResultMem outcome.toApprox :=
  ⟨.builderBind env key kind rest type outcome trace eval, mem⟩

example {f : FlowApprox} (env key kind rest type outcome trace)
      (eval : EvalBlock { env with locals := none :: env.locals } key rest type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.builderBind kind rest) type outcome trace ∧
      (f).ResultMem outcome.toApprox :=
  block_builderBind env key kind rest type outcome trace eval mem

/-- Block の last の実構成と局所所属。 -/
theorem block_last {f : FlowApprox} (env key source type outcome trace)
      (eval : EvalPartial env ⟨source, type, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.last source) type outcome trace ∧
      (f).ResultMem outcome.toApprox :=
  ⟨.last env key source type outcome trace eval, mem⟩

example {f : FlowApprox} (env key source type outcome trace)
      (eval : EvalPartial env ⟨source, type, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.last source) type outcome trace ∧
      (f).ResultMem outcome.toApprox :=
  block_last env key source type outcome trace eval mem

/-- Block の lastBind の実構成と局所所属。 -/
theorem block_lastBind {f : FlowApprox} (env key kind boundType source outcome trace)
      (eval : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.lastBind kind boundType source) (.base .unit) (discardOutcome outcome) trace ∧
      (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox :=
  ⟨.lastBind env key kind boundType source outcome trace eval, discard_mem mem⟩

example {f : FlowApprox} (env key kind boundType source outcome trace)
      (eval : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.lastBind kind boundType source) (.base .unit) (discardOutcome outcome) trace ∧
      (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox :=
  block_lastBind env key kind boundType source outcome trace eval mem

/-- Block の lastDiscard の実構成と局所所属。 -/
theorem block_lastDiscard {f : FlowApprox} (env key source sourceType outcome trace)
      (eval : EvalPartial env ⟨source, sourceType, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.lastDiscard source) (.base .unit) (discardOutcome outcome) trace ∧
      (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox :=
  ⟨.lastDiscard env key source sourceType outcome trace eval, discard_mem mem⟩

example {f : FlowApprox} (env key source sourceType outcome trace)
      (eval : EvalPartial env ⟨source, sourceType, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.lastDiscard source) (.base .unit) (discardOutcome outcome) trace ∧
      (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox :=
  block_lastDiscard env key source sourceType outcome trace eval mem

/-- Block の lastPat の実構成と局所所属。 -/
theorem block_lastPat {f : FlowApprox} (env key kind pattern boundType source outcome trace)
      (eval : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.lastPat kind pattern boundType source) (.base .unit)
        (discardOutcome outcome) trace ∧
      (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox :=
  ⟨.lastPat env key kind pattern boundType source outcome trace eval, discard_mem mem⟩

example {f : FlowApprox} (env key kind pattern boundType source outcome trace)
      (eval : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.lastPat kind pattern boundType source) (.base .unit)
        (discardOutcome outcome) trace ∧
      (seqF f (normalF .unknown)).ResultMem (discardOutcome outcome).toApprox :=
  block_lastPat env key kind pattern boundType source outcome trace eval mem

/-- Block の bind の実構成と局所所属。 -/
theorem block_bind {f g : FlowApprox} (env key kind boundType source rest type value outcome et rt)
      (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
      (tail : EvalBlock { env with locals := some value :: env.locals } (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.bind kind boundType source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.bind env key kind boundType source rest type value outcome et rt head tail, seq_tail mem⟩

example {f g : FlowApprox} (env key kind boundType source rest type value outcome et rt)
      (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
      (tail : EvalBlock { env with locals := some value :: env.locals } (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.bind kind boundType source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_bind env key kind boundType source rest type value outcome et rt head tail mem

/-- Block の bindAbrupt の実構成と局所所属。 -/
theorem block_bindAbrupt {f g : FlowApprox} (env key kind boundType source rest type outcome trace)
      (head : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.bind kind boundType source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.bindAbrupt env key kind boundType source rest type outcome trace head abrupt, seq_abrupt abrupt mem⟩

example {f g : FlowApprox} (env key kind boundType source rest type outcome trace)
      (head : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.bind kind boundType source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_bindAbrupt env key kind boundType source rest type outcome trace head abrupt mem

/-- Block の discard の実構成と局所所属。 -/
theorem block_discard {f g : FlowApprox} (env key source rest sourceType type value outcome et rt)
      (head : EvalPartial env ⟨source, sourceType, key⟩ (.normal value) et)
      (tail : EvalBlock env (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.discard source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.discard env key source rest sourceType type value outcome et rt head tail, seq_tail mem⟩

example {f g : FlowApprox} (env key source rest sourceType type value outcome et rt)
      (head : EvalPartial env ⟨source, sourceType, key⟩ (.normal value) et)
      (tail : EvalBlock env (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.discard source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_discard env key source rest sourceType type value outcome et rt head tail mem

/-- Block の discardAbrupt の実構成と局所所属。 -/
theorem block_discardAbrupt {f g : FlowApprox} (env key source rest sourceType type outcome trace)
      (head : EvalPartial env ⟨source, sourceType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.discard source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.discardAbrupt env key source rest sourceType type outcome trace head abrupt, seq_abrupt abrupt mem⟩

example {f g : FlowApprox} (env key source rest sourceType type outcome trace)
      (head : EvalPartial env ⟨source, sourceType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.discard source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_discardAbrupt env key source rest sourceType type outcome trace head abrupt mem

/-- Block の seq の実構成と局所所属。 -/
theorem block_seq {f g : FlowApprox} (env key source rest type value outcome et rt)
      (head : EvalPartial env ⟨source, .base .unit, key⟩ (.normal value) et)
      (tail : EvalBlock env (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.seq source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.seq env key source rest type value outcome et rt head tail, seq_tail mem⟩

example {f g : FlowApprox} (env key source rest type value outcome et rt)
      (head : EvalPartial env ⟨source, .base .unit, key⟩ (.normal value) et)
      (tail : EvalBlock env (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.seq source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_seq env key source rest type value outcome et rt head tail mem

/-- Block の seqAbrupt の実構成と局所所属。 -/
theorem block_seqAbrupt {f g : FlowApprox} (env key source rest type outcome trace)
      (head : EvalPartial env ⟨source, .base .unit, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.seq source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.seqAbrupt env key source rest type outcome trace head abrupt, seq_abrupt abrupt mem⟩

example {f g : FlowApprox} (env key source rest type outcome trace)
      (head : EvalPartial env ⟨source, .base .unit, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.seq source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_seqAbrupt env key source rest type outcome trace head abrupt mem

/-- Block の bindPat の実構成と局所所属。 -/
theorem block_bindPat {f g : FlowApprox} (env key kind pattern boundType source rest type value outcome et rt values)
      (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
      (bindings : PatternLocals pattern value values)
      (tail : EvalBlock { env with locals := values.map some ++ env.locals } (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.bindPat kind pattern boundType source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.bindPat env key kind pattern boundType source rest type value outcome et rt values head bindings tail, seq_tail mem⟩

example {f g : FlowApprox} (env key kind pattern boundType source rest type value outcome et rt values)
      (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
      (bindings : PatternLocals pattern value values)
      (tail : EvalBlock { env with locals := values.map some ++ env.locals } (advanceKey key (surfaceSize source))
        rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalBlock env key (.bindPat kind pattern boundType source rest) type outcome (et ++ rt) ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_bindPat env key kind pattern boundType source rest type value outcome et rt values head bindings tail mem

/-- Block の bindPatAbrupt の実構成と局所所属。 -/
theorem block_bindPatAbrupt {f g : FlowApprox} (env key kind pattern boundType source rest type outcome trace)
      (head : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.bindPat kind pattern boundType source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  ⟨.bindPatAbrupt env key kind pattern boundType source rest type outcome trace head abrupt, seq_abrupt abrupt mem⟩

example {f g : FlowApprox} (env key kind pattern boundType source rest type outcome trace)
      (head : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalBlock env key (.bindPat kind pattern boundType source rest) type outcome trace ∧
      (seqF f g).ResultMem outcome.toApprox :=
  block_bindPatAbrupt env key kind pattern boundType source rest type outcome trace head abrupt mem

/-- EvalArms の nil の実構成と局所所属。 -/
theorem arms_nil  (env key value type) :
    EvalArms env key value .nil type (.failed .unknown) [] ∧
      ((⟨.bottom,.bottom,true⟩ : FlowApprox)).ResultMem (.failed Failure.unknown : EvalOutcome).toApprox :=
  ⟨.nil env key value type, rfl⟩

example  (env key value type) :
    EvalArms env key value .nil type (.failed .unknown) [] ∧
      ((⟨.bottom,.bottom,true⟩ : FlowApprox)).ResultMem (.failed Failure.unknown : EvalOutcome).toApprox :=
  arms_nil env key value type

/-- EvalArms の skip の実構成と局所所属。 -/
theorem arms_skip {f g : FlowApprox} (env key value alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, alt.pat.toCore.matchVal (.const (.integer value)) = none)
      (tail : EvalArms env (advanceKey key (guardSize guard + blockSize body)) value rest type outcome trace)
    (mem : g.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts guard body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  ⟨.skip env key value alts guard body rest type outcome trace miss tail, join_right mem⟩

example {f g : FlowApprox} (env key value alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, alt.pat.toCore.matchVal (.const (.integer value)) = none)
      (tail : EvalArms env (advanceKey key (guardSize guard + blockSize body)) value rest type outcome trace)
    (mem : g.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts guard body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  arms_skip env key value alts guard body rest type outcome trace miss tail mem

/-- EvalArms の body の実構成と局所所属。 -/
theorem arms_body {f g : FlowApprox} (env key value alts body rest type selected outcome trace)
      (selection : IntegerSelection alts value selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts none body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  ⟨.body env key value alts body rest type selected outcome trace selection branch, join_left mem⟩

example {f g : FlowApprox} (env key value alts body rest type selected outcome trace)
      (selection : IntegerSelection alts value selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts none body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  arms_body env key value alts body rest type selected outcome trace selection branch mem

/-- EvalArms の guardTrue の実構成と局所所属。 -/
theorem arms_guardTrue {h f g : FlowApprox} (env key value alts guard body rest type selected outcome gt bt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardTrue env key value alts guard body rest type selected outcome gt bt selection condition branch, seq_tail (join_left mem)⟩

example {h f g : FlowApprox} (env key value alts guard body rest type selected outcome gt bt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  arms_guardTrue env key value alts guard body rest type selected outcome gt bt selection condition branch mem

/-- EvalArms の guardFalse の実構成と局所所属。 -/
theorem arms_guardFalse {h f g : FlowApprox} (env key value alts guard body rest type selected outcome gt rt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalArms env (advanceKey key (surfaceSize guard + blockSize body)) value rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardFalse env key value alts guard body rest type selected outcome gt rt selection condition tail, seq_tail (join_right mem)⟩

example {h f g : FlowApprox} (env key value alts guard body rest type selected outcome gt rt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalArms env (advanceKey key (surfaceSize guard + blockSize body)) value rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  arms_guardFalse env key value alts guard body rest type selected outcome gt rt selection condition tail mem

/-- EvalArms の guardAbrupt の実構成と局所所属。 -/
theorem arms_guardAbrupt {h f g : FlowApprox} (env key value alts guard body rest type selected outcome gt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts (some guard) body rest) type outcome gt ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardAbrupt env key value alts guard body rest type selected outcome gt selection condition abrupt, seq_abrupt abrupt mem⟩

example {h f g : FlowApprox} (env key value alts guard body rest type selected outcome gt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
    EvalArms env key value (.cons alts (some guard) body rest) type outcome gt ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  arms_guardAbrupt env key value alts guard body rest type selected outcome gt selection condition abrupt mem

/-- EvalWidthArms の nil の実構成と局所所属。 -/
theorem width_arms_nil  (env key kind value type) :
    EvalWidthArms env key kind value .nil type (.failed .unknown) [] ∧
      ((⟨.bottom,.bottom,true⟩ : FlowApprox)).ResultMem (.failed Failure.unknown : EvalOutcome).toApprox :=
  ⟨.nil env key kind value type, rfl⟩

example  (env key kind value type) :
    EvalWidthArms env key kind value .nil type (.failed .unknown) [] ∧
      ((⟨.bottom,.bottom,true⟩ : FlowApprox)).ResultMem (.failed Failure.unknown : EvalOutcome).toApprox :=
  width_arms_nil env key kind value type

/-- EvalWidthArms の skip の実構成と局所所属。 -/
theorem width_arms_skip {f g : FlowApprox} (env key kind value alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, widthPatternMatch alt.pat kind value = none)
      (tail : EvalWidthArms env (advanceKey key (guardSize guard + blockSize body)) kind value rest type outcome trace)
    (mem : g.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts guard body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  ⟨.skip env key kind value alts guard body rest type outcome trace miss tail, join_right mem⟩

example {f g : FlowApprox} (env key kind value alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, widthPatternMatch alt.pat kind value = none)
      (tail : EvalWidthArms env (advanceKey key (guardSize guard + blockSize body)) kind value rest type outcome trace)
    (mem : g.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts guard body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  width_arms_skip env key kind value alts guard body rest type outcome trace miss tail mem

/-- EvalWidthArms の body の実構成と局所所属。 -/
theorem width_arms_body {f g : FlowApprox} (env key kind value alts body rest type selected outcome trace)
      (selection : WidthSelection alts kind value selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts none body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  ⟨.body env key kind value alts body rest type selected outcome trace selection branch, join_left mem⟩

example {f g : FlowApprox} (env key kind value alts body rest type selected outcome trace)
      (selection : WidthSelection alts kind value selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts none body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  width_arms_body env key kind value alts body rest type selected outcome trace selection branch mem

/-- EvalWidthArms の guardTrue の実構成と局所所属。 -/
theorem width_arms_guardTrue {h f g : FlowApprox} (env key kind value alts guard body rest type selected outcome gt bt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardTrue env key kind value alts guard body rest type selected outcome gt bt selection condition branch, seq_tail (join_left mem)⟩

example {h f g : FlowApprox} (env key kind value alts guard body rest type selected outcome gt bt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  width_arms_guardTrue env key kind value alts guard body rest type selected outcome gt bt selection condition branch mem

/-- EvalWidthArms の guardFalse の実構成と局所所属。 -/
theorem width_arms_guardFalse {h f g : FlowApprox} (env key kind value alts guard body rest type selected outcome gt rt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalWidthArms env (advanceKey key (surfaceSize guard + blockSize body)) kind value rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardFalse env key kind value alts guard body rest type selected outcome gt rt selection condition tail, seq_tail (join_right mem)⟩

example {h f g : FlowApprox} (env key kind value alts guard body rest type selected outcome gt rt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalWidthArms env (advanceKey key (surfaceSize guard + blockSize body)) kind value rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  width_arms_guardFalse env key kind value alts guard body rest type selected outcome gt rt selection condition tail mem

/-- EvalWidthArms の guardAbrupt の実構成と局所所属。 -/
theorem width_arms_guardAbrupt {h f g : FlowApprox} (env key kind value alts guard body rest type selected outcome gt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome gt ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardAbrupt env key kind value alts guard body rest type selected outcome gt selection condition abrupt, seq_abrupt abrupt mem⟩

example {h f g : FlowApprox} (env key kind value alts guard body rest type selected outcome gt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
    EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome gt ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  width_arms_guardAbrupt env key kind value alts guard body rest type selected outcome gt selection condition abrupt mem

/-- EvalResultArms の nil の実構成と局所所属。 -/
theorem result_arms_nil  (env key names value tag payload type) :
    EvalResultArms env key names value tag payload .nil type (.failed .unknown) [] ∧
      ((⟨.bottom,.bottom,true⟩ : FlowApprox)).ResultMem (.failed Failure.unknown : EvalOutcome).toApprox :=
  ⟨.nil env key names value tag payload type, rfl⟩

example  (env key names value tag payload type) :
    EvalResultArms env key names value tag payload .nil type (.failed .unknown) [] ∧
      ((⟨.bottom,.bottom,true⟩ : FlowApprox)).ResultMem (.failed Failure.unknown : EvalOutcome).toApprox :=
  result_arms_nil env key names value tag payload type

/-- EvalResultArms の skip の実構成と局所所属。 -/
theorem result_arms_skip {f g : FlowApprox} (env key names value tag payload alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, resultPatternMatch names value tag payload alt.pat = none)
      (tail : EvalResultArms env (advanceKey key (guardSize guard + blockSize body)) names value tag payload rest type outcome trace)
    (mem : g.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts guard body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  ⟨.skip env key names value tag payload alts guard body rest type outcome trace miss tail, join_right mem⟩

example {f g : FlowApprox} (env key names value tag payload alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, resultPatternMatch names value tag payload alt.pat = none)
      (tail : EvalResultArms env (advanceKey key (guardSize guard + blockSize body)) names value tag payload rest type outcome trace)
    (mem : g.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts guard body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  result_arms_skip env key names value tag payload alts guard body rest type outcome trace miss tail mem

/-- EvalResultArms の body の実構成と局所所属。 -/
theorem result_arms_body {f g : FlowApprox} (env key names value tag payload alts body rest type selected outcome trace)
      (selection : ResultSelection names value tag payload alts selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts none body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  ⟨.body env key names value tag payload alts body rest type selected outcome trace selection branch, join_left mem⟩

example {f g : FlowApprox} (env key names value tag payload alts body rest type selected outcome trace)
      (selection : ResultSelection names value tag payload alts selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace)
    (mem : f.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts none body rest) type outcome trace ∧
      (joinF f g).ResultMem outcome.toApprox :=
  result_arms_body env key names value tag payload alts body rest type selected outcome trace selection branch mem

/-- EvalResultArms の guardTrue の実構成と局所所属。 -/
theorem result_arms_guardTrue {h f g : FlowApprox} (env key names value tag payload alts guard body rest type selected outcome gt bt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardTrue env key names value tag payload alts guard body rest type selected outcome gt bt selection condition branch, seq_tail (join_left mem)⟩

example {h f g : FlowApprox} (env key names value tag payload alts guard body rest type selected outcome gt bt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt)
    (mem : f.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome (gt ++ bt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  result_arms_guardTrue env key names value tag payload alts guard body rest type selected outcome gt bt selection condition branch mem

/-- EvalResultArms の guardFalse の実構成と局所所属。 -/
theorem result_arms_guardFalse {h f g : FlowApprox} (env key names value tag payload alts guard body rest type selected outcome gt rt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalResultArms env (advanceKey key (surfaceSize guard + blockSize body)) names value tag payload rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardFalse env key names value tag payload alts guard body rest type selected outcome gt rt selection condition tail, seq_tail (join_right mem)⟩

example {h f g : FlowApprox} (env key names value tag payload alts guard body rest type selected outcome gt rt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalResultArms env (advanceKey key (surfaceSize guard + blockSize body)) names value tag payload rest type outcome rt)
    (mem : g.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome (gt ++ rt) ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  result_arms_guardFalse env key names value tag payload alts guard body rest type selected outcome gt rt selection condition tail mem

/-- EvalResultArms の guardAbrupt の実構成と局所所属。 -/
theorem result_arms_guardAbrupt {h f g : FlowApprox} (env key names value tag payload alts guard body rest type selected outcome gt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome gt ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  ⟨.guardAbrupt env key names value tag payload alts guard body rest type selected outcome gt selection condition abrupt, seq_abrupt abrupt mem⟩

example {h f g : FlowApprox} (env key names value tag payload alts guard body rest type selected outcome gt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt)
    (mem : h.ResultMem outcome.toApprox) :
    EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome gt ∧
      (seqF h (joinF f g)).ResultMem outcome.toApprox :=
  result_arms_guardAbrupt env key names value tag payload alts guard body rest type selected outcome gt selection condition abrupt mem

/-- Boolean の実 return から returned を作る。正常成分は空である。 -/
theorem boolean_return (env : ConcreteEnv) (key : OperationKey) (b : Bool) :
    EvalPartial env ⟨.returnE (.base .boolean) (.literal (.boolean b)),.base .boolean,key⟩
      (.returned (.boolean b)) [] ∧
    (returnF (normalF (.boolean (!b) b))).ReturnedMem (.boolean b) ∧
    ¬ (returnF (normalF (.boolean (!b) b))).NormalMem (.boolean b) := by
  have child : (normalF (.boolean (!b) b)).ResultMem (EvalOutcome.normal (.boolean b)).toApprox := by
    cases b <;> rfl
  obtain ⟨eval,mem⟩ := return_leaf (resultType := .base .boolean)
    (EvalPartial.boolean env (childKey key []) b) child
  exact ⟨eval,mem,fun h => h⟩

/-- 真の枝は return、偽の枝は通常値を返し、両成分の値を混同しない。 -/
theorem boolean_branches (env : ConcreteEnv) (key : OperationKey) :
    let returnedFlow := returnF (normalF (.boolean false true))
    let normalFlow := normalF (.boolean true false)
    let flow := seqF (normalF (.boolean true true)) (joinF returnedFlow normalFlow)
    let yes : Benitoite.Surface.Block := .last (.returnE (.base .boolean) (.literal (.boolean true)))
    let no : Benitoite.Surface.Block := .last (.literal (.boolean false))
    EvalPartial env ⟨.ite (.literal (.boolean true)) yes no,.base .boolean,key⟩
      (.returned (.boolean true)) [] ∧
    EvalPartial env ⟨.ite (.literal (.boolean false)) yes no,.base .boolean,key⟩
      (.normal (.boolean false)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ flow.NormalMem (.boolean false) ∧
    ¬ flow.NormalMem (.boolean true) ∧ ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  obtain ⟨er,mr,_⟩ := boolean_return env (childKey key [.literal (.boolean true)]) true
  obtain ⟨yes,my⟩ := block_last env _ _ _ _ _ er mr
  have normal : (normalF (.boolean true false)).ResultMem (EvalOutcome.normal (.boolean false)).toApprox := rfl
  obtain ⟨no,mn⟩ := block_last env _ _ _ _ _
    (EvalPartial.boolean env (childKey key (.literal (.boolean false) ::
      blockChildren (.last (.returnE (.base .boolean) (.literal (.boolean true)))))) false) normal
  obtain ⟨ey,hy⟩ := if_true_leaf (h := normalF (.boolean true true)) (g := normalF (.boolean true false))
    (EvalPartial.boolean env (childKey key []) true) yes my
  obtain ⟨en,hn⟩ := if_false_leaf (h := normalF (.boolean true true)) (f := returnF (normalF (.boolean false true)))
    (EvalPartial.boolean env (childKey key []) false) no mn
  exact ⟨ey,en,hy,hn,(by intro h; cases h),(by intro h; cases h)⟩

example (env : ConcreteEnv) (key : OperationKey) (b : Bool) := boolean_return env key b
example (env : ConcreteEnv) (key : OperationKey) := boolean_branches env key

/-- 選択した同じ腕の return から合流の returned を構成する。 -/
theorem wildcard_return_arm (env : ConcreteEnv) (key : OperationKey)
    (value : Benitoite.Release.Integer64Value) :
    EvalArms env key value
      (.cons [⟨.wild,[]⟩] none (.last (.returnE (.base .boolean) (.literal (.boolean true)))) .nil)
      (.base .boolean) (.returned (.boolean true)) [] ∧
    (joinF (returnF (normalF (.boolean false true))) (normalF .bottom)).ReturnedMem (.boolean true) := by
  have selected : IntegerSelection [⟨.wild,[]⟩] value [] := by
    exact ⟨[],⟨.wild,[]⟩,[],[],[],rfl,(by simp),rfl,rfl,rfl,rfl⟩
  obtain ⟨er,mr,_⟩ := boolean_return env key true
  obtain ⟨eb,mb⟩ := block_last env key _ _ _ _ er mr
  have result := arms_body (g := normalF .bottom) env key value [⟨.wild,[]⟩] _ .nil _ [] _ [] selected eb mb
  exact ⟨result.1,result.2⟩

example (env : ConcreteEnv) (key : OperationKey) (value : Benitoite.Release.Integer64Value) :=
  wildcard_return_arm env key value

private def trueReturnFlow := returnF (normalF (.boolean false true))
private def trueReturnBody : Benitoite.Surface.Block :=
  .last (.returnE (.base .boolean) (.literal (.boolean true)))

private theorem true_return_body (env : ConcreteEnv) (key : OperationKey) :
    EvalBlock env key trueReturnBody (.base .boolean) (.returned (.boolean true)) [] ∧
      trueReturnFlow.ReturnedMem (.boolean true) := by
  obtain ⟨eval,mem,_⟩ := boolean_return env key true
  exact block_last env key _ _ _ _ eval mem

/-- elseIf の本体と後続式は、それぞれ returned true と normal false を作る。 -/
theorem boolean_else_if (env : ConcreteEnv) (key : OperationKey) :
    let flow := seqF (normalF (.boolean true true)) (joinF trueReturnFlow (normalF (.boolean true false)))
    EvalPartial env ⟨.elseIf (.literal (.boolean true)) trueReturnBody (.literal (.boolean false)),
      .base .boolean,key⟩ (.returned (.boolean true)) [] ∧
    EvalPartial env ⟨.elseIf (.literal (.boolean false)) trueReturnBody (.literal (.boolean false)),
      .base .boolean,key⟩ (.normal (.boolean false)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ flow.NormalMem (.boolean false) ∧
    ¬ flow.NormalMem (.boolean true) ∧ ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  obtain ⟨body,mem⟩ := true_return_body env (childKey key [.literal (.boolean true)])
  obtain ⟨et,mt⟩ := else_if_true_leaf (h := normalF (.boolean true true)) (g := normalF (.boolean true false))
    (EvalPartial.boolean env _ true) body mem
  obtain ⟨ef,mf⟩ := else_if_false_leaf (h := normalF (.boolean true true)) (f := trueReturnFlow) (yes := trueReturnBody)
    (EvalPartial.boolean env _ false) (EvalPartial.boolean env _ false)
    (show (normalF (.boolean true false)).ResultMem (EvalOutcome.normal (.boolean false)).toApprox from rfl)
  exact ⟨et,ef,mt,mf,(by intro h; cases h),(by intro h; cases h)⟩

/-- ifOnly の空本体と偽の条件はともに通常の Unit であり、returned へ入らない。 -/
theorem unit_if_only (env : ConcreteEnv) (key : OperationKey) :
    let flow := seqF (normalF (.boolean true true)) (joinF (normalF .unknown) (normalF .unknown))
    EvalPartial env ⟨.ifOnly (.literal (.boolean true)) .empty,.base .unit,key⟩ (.normal .unit) [] ∧
    EvalPartial env ⟨.ifOnly (.literal (.boolean false)) .empty,.base .unit,key⟩ (.normal .unit) [] ∧
    flow.NormalMem .other ∧ ¬ flow.ReturnedMem .other := by
  dsimp only
  obtain ⟨body,mem⟩ := block_empty env (childKey key [.literal (.boolean true)])
  obtain ⟨et,mt⟩ := if_only_true_leaf (h := normalF (.boolean true true)) (EvalPartial.boolean env _ true) body mem
  obtain ⟨ef,mf⟩ := if_only_false_leaf (h := normalF (.boolean true true)) (f := normalF .unknown) (yes := .empty)
    (EvalPartial.boolean env _ false)
  exact ⟨et,ef,mt,(by intro h; cases h)⟩

/-- 条件又は照合値の return は本体・腕を評価せず、同じ returned 値を伝播する。 -/
theorem abrupt_conditions (env : ConcreteEnv) (key : OperationKey) :
    let cond : Benitoite.Surface.Expr := .returnE (.base .boolean) (.literal (.boolean true))
    let flow := seqF trueReturnFlow (joinF (normalF .bottom) (normalF .bottom))
    let unitFlow := seqF trueReturnFlow (joinF (normalF .bottom) (normalF .unknown))
    EvalPartial env ⟨.ite cond .empty .empty,.base .unit,key⟩ (.returned (.boolean true)) [] ∧
    EvalPartial env ⟨.elseIf cond .empty .unit,.base .unit,key⟩ (.returned (.boolean true)) [] ∧
    EvalPartial env ⟨.ifOnly cond .empty,.base .unit,key⟩ (.returned (.boolean true)) [] ∧
    EvalPartial env ⟨.matchE (.base .unit) cond .nil,.base .unit,key⟩ (.returned (.boolean true)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ ¬ flow.NormalMem (.boolean true) ∧
    ¬ flow.ReturnedMem (.boolean false) ∧ unitFlow.ReturnedMem (.boolean true) ∧
    ¬ unitFlow.ReturnedMem (.boolean false) := by
  dsimp only
  obtain ⟨cond,mem,_⟩ := boolean_return env (childKey key []) true
  obtain ⟨ei,mi⟩ := if_abrupt_leaf (f := normalF .bottom) (g := normalF .bottom)
    (yes := .empty) (no := .empty) (type := .base .unit) cond (by trivial) mem
  obtain ⟨ee,_⟩ := else_if_abrupt_leaf (f := normalF .bottom) (g := normalF .bottom)
    (yes := .empty) (no := .unit) (type := .base .unit) cond (by trivial) mem
  obtain ⟨eu,mu⟩ := if_only_abrupt_leaf (f := normalF .bottom) (yes := .empty) cond (by trivial) mem
  obtain ⟨em,_⟩ := match_abrupt_leaf (f := joinF (normalF .bottom) (normalF .bottom))
    (arms := .nil) (type := .base .unit) cond (by trivial) mem
  exact ⟨ei,ee,eu,em,mi,(by intro h; cases h),(by intro h; cases h),mu,(by intro h; cases h)⟩

/-- 正常な head の true を束縛して tail の local から return し、式 block へ上げる。 -/
theorem bound_boolean_return (env : ConcreteEnv) (key : OperationKey) :
    let body : Benitoite.Surface.Block := .bind .bind (.base .boolean) (.literal (.boolean true))
      (.last (.returnE (.base .boolean) (.local 0)))
    let flow := seqF (normalF (.boolean false true)) trueReturnFlow
    EvalPartial env ⟨.block body,.base .boolean,key⟩ (.returned (.boolean true)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ ¬ flow.NormalMem (.boolean true) ∧
    ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  let atHead := childKey key []
  let atTail := advanceKey atHead (surfaceSize (.literal (.boolean true)))
  let bound := {env with locals := some (.boolean true) :: env.locals}
  have read := EvalPartial.local bound (childKey atTail []) 0 (.boolean true) rfl
  obtain ⟨ret,mem⟩ := return_leaf (f := normalF (.boolean false true)) (resultType := .base .boolean)
    read (show (normalF (.boolean false true)).ResultMem (EvalOutcome.normal (.boolean true)).toApprox from rfl)
  obtain ⟨tail,mt⟩ := block_last bound atTail _ _ _ _ ret mem
  obtain ⟨body,mb⟩ := block_bind (f := normalF (.boolean false true)) env atHead .bind
    (.base .boolean) (.literal (.boolean true)) _ _ _ _ [] []
    (EvalPartial.boolean env atHead true) tail mt
  obtain ⟨eval,inside⟩ := expression_block_leaf body mb
  exact ⟨eval,inside,(by intro h; cases h),(by intro h; cases h)⟩

/-- guard の真は同じ本体の return、偽は次の腕の通常値を選ぶ。 -/
theorem guarded_boolean_branches (env : ConcreteEnv) (key : OperationKey)
    (value : Benitoite.Release.Integer64Value) :
    let rest : Benitoite.Surface.Arms := .cons [⟨.wild,[]⟩] none (.last (.literal (.boolean false))) .nil
    let flow := seqF (normalF (.boolean true true))
      (joinF trueReturnFlow (joinF (normalF (.boolean true false)) (normalF .bottom)))
    EvalArms env key value (.cons [⟨.wild,[]⟩] (some (.literal (.boolean true))) trueReturnBody rest)
      (.base .boolean) (.returned (.boolean true)) [] ∧
    EvalArms env key value (.cons [⟨.wild,[]⟩] (some (.literal (.boolean false))) trueReturnBody rest)
      (.base .boolean) (.normal (.boolean false)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ flow.NormalMem (.boolean false) ∧
    ¬ flow.NormalMem (.boolean true) ∧ ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  have selected : IntegerSelection [⟨.wild,[]⟩] value [] :=
    ⟨[],⟨.wild,[]⟩,[],[],[],rfl,(by simp),rfl,rfl,rfl,rfl⟩
  obtain ⟨body,mem⟩ := true_return_body env (advanceKey key (surfaceSize (.literal (.boolean true))))
  obtain ⟨et,mt⟩ := arms_guardTrue (h := normalF (.boolean true true))
    (g := joinF (normalF (.boolean true false)) (normalF .bottom)) env key value _ _ _ _ _ [] _ [] []
    selected (EvalPartial.boolean env _ true) body mem
  obtain ⟨tail,memTail⟩ := block_last env _ _ _ _ _ (EvalPartial.boolean env _ false)
    (show (normalF (.boolean true false)).ResultMem (EvalOutcome.normal (.boolean false)).toApprox from rfl)
  obtain ⟨rest,memRest⟩ := arms_body (g := normalF .bottom) env _ value _ _ .nil _ [] _ [] selected tail memTail
  obtain ⟨ef,mf⟩ := arms_guardFalse (h := normalF (.boolean true true)) (f := trueReturnFlow)
    env key value _ _ _ _ _ [] _ [] [] selected (EvalPartial.boolean env _ false) rest memRest
  exact ⟨et,ef,mt,mf,(by intro h; cases h),(by intro h; cases h)⟩

/-- 整数の腕の returned を、照合値の通常評価に続く match 式の所属へ上げる。 -/
theorem integer_match_return (env : ConcreteEnv) (key : OperationKey) :
    let flow := seqF (normalF .unknown) (joinF trueReturnFlow (normalF .bottom))
    EvalPartial env ⟨.matchE (.base .boolean) (.literal (.integer ⟨1,by decide⟩))
      (.cons [⟨.wild,[]⟩] none trueReturnBody .nil),.base .boolean,key⟩
      (.returned (.boolean true)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ ¬ flow.NormalMem (.boolean true) ∧
    ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  obtain ⟨arms,mem⟩ := wildcard_return_arm env (childKey key [.literal (.integer ⟨1,by decide⟩)]) (Benitoite.Release.Integer64Literal.toValue ⟨1,by decide⟩)
  obtain ⟨eval,inside⟩ := match_integer_leaf (h := normalF .unknown)
    (EvalPartial.integer env _ ⟨1,by decide⟩) arms mem
  exact ⟨eval,inside,(by intro h; cases h),(by intro h; cases h)⟩

/-- Integer8 の腕の body から match 式の returned を作る。 -/
theorem width_match_return (env : ConcreteEnv) (key : OperationKey) :
    let flow := seqF (normalF .unknown) (joinF trueReturnFlow (normalF .bottom))
    EvalPartial env ⟨.matchE (.base .boolean) (.literal (.integer8 1))
      (.cons [⟨.wild,[]⟩] none trueReturnBody .nil),.base .boolean,key⟩
      (.returned (.boolean true)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ ¬ flow.NormalMem (.boolean true) ∧
    ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  have selected : WidthSelection [⟨.wild,[]⟩] .integer8 ⟨1,by decide⟩ [] :=
    ⟨[],⟨.wild,[]⟩,[],[],[],rfl,(by simp),rfl,rfl,rfl,rfl⟩
  obtain ⟨body,mem⟩ := true_return_body env (childKey key [.literal (.integer8 1)])
  obtain ⟨arms,memArms⟩ := width_arms_body (g := normalF .bottom) env _ .integer8 ⟨1,by decide⟩
    _ _ .nil _ [] _ [] selected body mem
  obtain ⟨eval,inside⟩ := match_width_leaf (h := normalF .unknown) (by intro h; cases h)
    (EvalPartial.integer8 env _ 1 (by decide)) arms memArms
  exact ⟨eval,inside,(by intro h; cases h),(by intro h; cases h)⟩

private def resultNames : RangeNames :=
  ⟨"Std.Range.CheckedInteger", "Std.Range.CheckedInteger.record", "Std.Result.Result", "Std.Range.Error",
    "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
private def resultPayload : ConcreteValue :=
  rangePayload resultNames.record ⟨0,by decide⟩ ⟨2,by decide⟩ ⟨1,by decide⟩
private def okResult : ConcreteValue :=
  .con resultNames.result [.data resultNames.owner [],.data resultNames.error []] resultNames.ok [resultPayload]
private def resultEnv : ConcreteEnv :=
  ⟨[some okResult],[⟨"Std.Range.checkInteger",.rangeCheck resultNames,[]⟩],fun _ => none⟩

/-- 既知の Result.Ok の腕を選び、body の return を match 式へ上げる。 -/
theorem result_match_return (key : OperationKey) :
    let flow := seqF (normalF .unknown) (joinF trueReturnFlow (normalF .bottom))
    EvalPartial resultEnv ⟨.matchE (.base .boolean) (.local 0)
      (.cons [⟨.wild,[]⟩] none trueReturnBody .nil),.base .boolean,key⟩
      (.returned (.boolean true)) [] ∧
    flow.ReturnedMem (.boolean true) ∧ ¬ flow.NormalMem (.boolean true) ∧
    ¬ flow.ReturnedMem (.boolean false) := by
  dsimp only
  have selected : ResultSelection resultNames okResult resultNames.ok resultPayload [⟨.wild,[]⟩] [] :=
    ⟨[],⟨.wild,[]⟩,[],[],rfl,(by simp),rfl,rfl,rfl⟩
  obtain ⟨body,mem⟩ := true_return_body resultEnv (childKey key [.local 0])
  obtain ⟨arms,memArms⟩ := result_arms_body (g := normalF .bottom) resultEnv _ resultNames okResult
    resultNames.ok resultPayload _ _ .nil _ [] _ [] selected body mem
  obtain ⟨eval,inside⟩ := match_result_leaf (h := normalF .unknown)
    (show rangeResultMatch resultEnv okResult (.cons [⟨.wild,[]⟩] none trueReturnBody .nil) = some resultNames from rfl)
    (RangeNames.ResultView.ok resultPayload rfl) (EvalPartial.local resultEnv _ 0 okResult rfl) arms memArms
  exact ⟨eval,inside,(by intro h; cases h),(by intro h; cases h)⟩

example (env : ConcreteEnv) (key : OperationKey) := boolean_else_if env key
example (env : ConcreteEnv) (key : OperationKey) := unit_if_only env key
example (env : ConcreteEnv) (key : OperationKey) := abrupt_conditions env key
example (env : ConcreteEnv) (key : OperationKey) := bound_boolean_return env key
example (env : ConcreteEnv) (key : OperationKey) (value : Benitoite.Release.Integer64Value) :=
  guarded_boolean_branches env key value
example (env : ConcreteEnv) (key : OperationKey) := integer_match_return env key
example (env : ConcreteEnv) (key : OperationKey) := width_match_return env key
example (key : OperationKey) := result_match_return key

end Benitoite.Release.Refinement.IntervalFlowLeaves
