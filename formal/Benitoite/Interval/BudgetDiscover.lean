import Benitoite.Interval.BudgetCount
import Benitoite.Interval.BudgetWalk

/-!
# 元の定義からの別本体の予算付き発見

値の到達可能性によらず全構文を辿る。constE は親で解析し、その内側の境界だけを残す。
本体名は常に元の定義の番号を使い、別本体の番号から再発見しない。
（設計書 01-12「区間解析の予算付きの別本体の発見」）。
-/
namespace Benitoite.Interval.BudgetDiscovery
open Benitoite.Surface Benitoite.Release Budget
open BudgetAnalysis (Halt)

/-- 発見枠を保存した後、環境の構築中に止まった場合も入口を失わない。 -/
structure Entry where
  embedded : EmbeddedBody
  initial : Option AbstractEnv

structure Context where
  walk : BudgetAnalysis.Context
  entriesRev : List Entry := []

abbrev Discovery := ReaderT Limits (ExceptT Halt (StateM Context))

/-- 番号と予算の既存の処理をそのまま使い、発見列を変えない。 -/
def lift (work : BudgetAnalysis.Analysis α) : Discovery α := fun limits ctx =>
  let (result, final) := work limits ctx.walk
  (result, { ctx with walk := final })

def scan (work : BudgetScan.Scan α) : Discovery α := lift (BudgetAnalysis.scan work)

/-- 発見は次番号だけを使う。親の解析の対応表を二重に保存しない。
番号付けの操作は計上するが、identity項目の確保は行わない。 -/
def reidentify (_source : Expr) : BudgetAnalysis.Analysis OperationKey := fun limits ctx =>
  match (BudgetScan.forNumbering fun _ => BudgetScan.tick .numbering).run limits ctx.budget with
  | .stopped reason state => (.error (.budget reason), { ctx with budget := state })
  | .ok _ state => (.ok ctx.next, { ctx with budget := state, next := advanceKey ctx.next 1 })

theorem reidentify_success (source : Expr) (limits : Limits) (ctx : BudgetAnalysis.Context)
    {value final} (ok : reidentify source limits ctx = (.ok value, final)) :
    value = ctx.next ∧ final.next = advanceKey ctx.next 1 ∧
    final.warningsRev = ctx.warningsRev ∧ final.identitiesRev = ctx.identitiesRev ∧
    final.unsupported = ctx.unsupported := by
  unfold reidentify at ok
  split at ok
  · cases ok
  · cases ok
    exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- 復帰時にこの呼び出しの一時項目だけを返す。保存したseedは返却しない。 -/
def scope (work : Unit → Discovery α) : Discovery α := fun limits ctx =>
  let entered := scan (BudgetScan.allocate .stackFrame) limits ctx
  match entered.1 with
  | .error reason => (.error reason, entered.2)
  | .ok _ =>
    let (result, final) := work () limits entered.2
    let count := final.walk.budget.body.temporary - ctx.walk.budget.body.temporary
    (result, { final with walk := { final.walk with budget := release final.walk.budget .temporary count (Nat.sub_le _ _) } })

/-- 引数の型の列を先にmapせず、ソース順に位置を追加する。 -/
def typedValues (env : AbstractEnv) (types : List Ty) : BudgetScan.Scan AbstractEnv :=
  BudgetScan.frame fun _ => do
    BudgetScan.tick .classification
    match types with
    | [] => pure env
    | type :: rest =>
      let inner ← BudgetScan.push env (topSlot (some type))
      typedValues inner rest

/-- 節の型パラメータを越える捕捉位置は、型の同一性も推測しない。 -/
def untypedSlots (slots : List AbstractSlot) : BudgetScan.Scan (List AbstractSlot) :=
  BudgetScan.frame fun _ => do
    match slots with
    | [] => pure []
    | slot :: rest =>
      BudgetScan.tick .environmentRead
      let tail ← untypedSlots rest
      BudgetScan.consSlot (match slot with
        | .integer _ => .integer top
        | .integerKind kind _ => .integerKind kind (top kind)
        | .unknown _ => .unknown none
        | .builder kind => .builder kind
        | .unavailable => .unavailable) tail

def untypedEnv (env : AbstractEnv) : BudgetScan.Scan AbstractEnv := do
  let locals ← untypedSlots env.locals
  pure { env with locals := locals }

def clauseEnv (env : AbstractEnv) (arity dictCount : Nat) : BudgetScan.Scan AbstractEnv := do
  let inner ← untypedEnv env
  let locals ← BudgetScan.replicateOnto (dictCount + arity + 1) (.unknown none) inner.locals
  pure { inner with locals := locals }

def failureEnv (env : AbstractEnv) : BudgetScan.Scan AbstractEnv := do
  let inner ← untypedEnv env
  let error ← BudgetScan.push inner (.unknown none)
  BudgetScan.push error .unavailable

/-- 一枠を先に確保する。忘却して新しく作った環境だけを保存へ移す。
引数などの構築の一時項目は呼び出し側のscopeが返す。 -/
def saveEntry (entry : EmbeddedBody) (prepare : BudgetScan.Scan AbstractEnv) :
    Discovery AbstractEnv := do
  scan (BudgetScan.allocate .auxiliary .saved)
  fun limits ctx =>
    let (prepared, middle) := scan prepare limits ctx
    let (result, final) : Except Halt AbstractEnv × Context := match prepared with
      | .error reason => (.error reason, middle)
      | .ok env =>
        let (forgotten, last) := scan (BudgetScan.forgetEnv env) limits middle
        match forgotten with
        | .error reason => (.error reason, last)
        | .ok initial =>
          let count := last.walk.budget.body.temporary - middle.walk.budget.body.temporary
          (.ok initial, { last with walk := { last.walk with budget := save last.walk.budget count (Nat.sub_le _ _) } })
    (result, { final with entriesRev := ⟨entry, result.toOption⟩ :: final.entriesRev })

/-- 同じhandleの全節を、内側の境界より先に保存する。
開始位置の先読みも同じ本体・全体予算を使う。 -/
def saveClauses (env : AbstractEnv) (owner : OperationKey) (start ordinal : Nat)
    (clauses : Clauses) : Discovery Unit := scope fun _ => do
  scan (BudgetScan.tick .classification)
  match clauses with
  | .nil => pure ()
  | .cons _ arity _ body rest dictCount =>
    let _ ← scope fun _ => saveEntry ⟨owner, ordinal, .handler, body, start⟩
      (clauseEnv env arity dictCount)
    let count ← scan (BudgetScan.countBlock body)
    saveClauses env owner (start + count) (ordinal + 1) rest

mutual
def expr : Nat → AbstractEnv → Expr → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, source => scope fun _ => do
    let owner ← lift (reidentify source)
    scan (BudgetScan.tick .classification)
    match source with
    | .lam _ params _ _ body =>
      let initial ← saveEntry ⟨owner, 0, .lambda, body, owner.surfacePreorder + 1⟩
        (typedValues env params)
      block fuel initial body
    | .lazyE body =>
      let initial ← saveEntry ⟨owner, 0, .lazy, body, owner.surfacePreorder + 1⟩ (pure env)
      block fuel initial body
    | .handleFail _ _ body clause =>
      let count ← scan (BudgetScan.countBlock body)
      let initial ← saveEntry ⟨owner, 0, .failure, clause, owner.surfacePreorder + 1 + count⟩
        (failureEnv env)
      block fuel env body
      block fuel initial clause
    | .handleE body clauses =>
      let count ← scan (BudgetScan.countBlock body)
      saveClauses env owner (owner.surfacePreorder + 1 + count) 0 clauses
      block fuel env body
      clauseList fuel env clauses
    | .constE _ child => expr fuel (clearLocals env) child
    | .withE owner child body =>
      expr fuel env child
      let inner ← scan (BudgetScan.push env (topSlot (some (.opaque owner))))
      block fuel inner body
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit => pure ()
    | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es => exprs fuel env es
    | .paren e | .neg _ e | .not e | .returnE _ e
    | .tryResult _ _ _ e | .tryOption _ _ _ e | .resume _ e => expr fuel env e
    | .block body => block fuel env body
    | .recordUpdate _ _ _ _ base es | .call base _ _ es => do expr fuel env base; exprs fuel env es
    | .pipe lhs rhs | .binary _ _ lhs rhs | .and lhs rhs | .or lhs rhs => do
      expr fuel env lhs; expr fuel env rhs
    | .partialCall callee _ args _ _ => do expr fuel env callee; holes fuel env args
    | .partialCon _ _ args => holes fuel env args
    | .listSpread _ concat before spread after => do
      expr fuel env concat; exprs fuel env before; expr fuel env spread; exprs fuel env after
    | .interpolation _ es converters => do exprs fuel env es; exprs fuel env converters
    | .ite cond yes no => do expr fuel env cond; block fuel env yes; block fuel env no
    | .elseIf cond yes no => do expr fuel env cond; block fuel env yes; expr fuel env no
    | .ifOnly cond yes => do expr fuel env cond; block fuel env yes
    | .matchE _ scrutinee arms => do expr fuel env scrutinee; armList fuel env arms
    | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message => do
      expr fuel env e; optional fuel env message

def exprs : Nat → AbstractEnv → Exprs → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, sources => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match sources with
    | .nil => pure ()
    | .cons source rest => do expr fuel env source; exprs fuel env rest

def holes : Nat → AbstractEnv → HoleArgs → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, args => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match args with
    | .nil => pure ()
    | .expr _ _ source rest => do expr fuel env source; holes fuel env rest
    | .hole _ _ _ rest => holes fuel env rest

def block : Nat → AbstractEnv → Block → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, body => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match body with
    | .empty => pure ()
    | .builderBind kind rest =>
      let inner ← scan (BudgetScan.push env (.builder kind))
      block fuel inner rest
    | .last source | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source =>
      expr fuel env source
    | .bind _ type source rest =>
      expr fuel env source
      let inner ← scan (BudgetScan.push env (topSlot (some type)))
      block fuel inner rest
    | .discard source rest | .seq source rest => do expr fuel env source; block fuel env rest
    | .bindPat _ pattern type source rest =>
      expr fuel env source
      let inner ← scan (BudgetScan.patternEnv env pattern type)
      block fuel inner rest

def armList : Nat → AbstractEnv → Arms → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, arms => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match arms with
    | .nil => pure ()
    | .cons alts guard body rest =>
      let _ ← scope fun _ => do
        let count ← scan (match alts with | [] => pure 0 | alt :: _ => BudgetScan.countList alt.slots)
        let locals ← scan (BudgetScan.replicateOnto count (.unknown none) env.locals)
        let inner := { env with locals := locals }
        optional fuel inner guard
        block fuel inner body
      armList fuel env rest

def clauseList : Nat → AbstractEnv → Clauses → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, clauses => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match clauses with
    | .nil => pure ()
    | .cons _ arity _ body rest dictCount =>
      let _ ← scope fun _ => do
        let inner ← scan (clauseEnv env arity dictCount)
        block fuel inner body
      clauseList fuel env rest

def optional : Nat → AbstractEnv → Option Expr → Discovery Unit
  | 0, _, _ => throw .depth
  | fuel + 1, env, source => match source with
    | none => pure ()
    | some source => expr fuel env source
end

structure Report where
  result : Except Halt Unit
  context : Context
  after : Budget.State

/-- 発見の費用は元の定義に属する独立した予算区間とする。
全体消費は渡された状態を引き継ぎ、本体消費だけを終了時に閉じる。 -/
def discover (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) : Report :=
  let ctx : Context := ⟨{ budget := state, next := bodyRootKey definition }, []⟩
  let work := scope fun _ => do
    let initial ← scan (BudgetScan.forgetEnv seed.initial)
    expr fuel initial (bodyRoot seed.body)
  let (result, final) := work limits ctx
  ⟨result, final, finishBody final.walk.budget⟩

end Benitoite.Interval.BudgetDiscovery
