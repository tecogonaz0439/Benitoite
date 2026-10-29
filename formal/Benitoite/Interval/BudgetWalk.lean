import Benitoite.Interval.BudgetPatterns
import Benitoite.Interval.Sound

/-!
# 解析の共有状態と有界の番号走査

部分木の大きさを先に求めず、解析しない部分も同じ予算で辿る。
本体名・本体の全列挙と元 AST との対応は、この部分木の走査と区別する。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 深さによる打ち切りと、拒否した予算の計上を区別する。 -/
inductive Halt where
  | depth
  | budget (reason : StopReason)
  deriving DecidableEq, Repr

/-- 独立入力の容器。Block 自身には合成した式や番号を加えない。 -/
inductive IndependentInput where
  | expr (source : Expr)
  | block (body : Block)

/-- 入力の保存枠は先に確保する。忘却前に止まった場合は initial がない。 -/
structure IndependentResult where
  input : IndependentInput
  key : OperationKey
  initial : Option AbstractEnv
  result : Except Halt BaseApprox
  warningsRev : List IntervalWarning
  unsupported : Bool

/-- 保存列は逆順で共有し、合成のたびに既得の列をコピーしない。 -/
structure Context where
  budget : Budget.State := {}
  next : OperationKey
  warningsRev : List IntervalWarning := []
  identitiesRev : List (OperationKey × Expr) := []
  independentRev : List IndependentResult := []
  unsupported : Bool := false

/-- 停止しても既に保存した警告と実消費を残す。 -/
abbrev Analysis := ReaderT Limits (ExceptT Halt (StateM Context))

/-- 局所走査を同じ本体・全体の状態に接続する。 -/
def scan (work : BudgetScan.Scan α) : Analysis α := fun limits ctx =>
  match work.run limits ctx.budget with
  | .ok value state => (.ok value, { ctx with budget := state })
  | .stopped reason state => (.error (.budget reason), { ctx with budget := state })

/-- 戻り値は環境を含まない。成功・停止とも、この呼び出しの作業領域を返す。 -/
def scope (work : Unit → Analysis α) : Analysis α := fun limits ctx =>
  let entered := scan (BudgetScan.allocate .stackFrame) limits ctx
  match entered.1 with
  | .error reason => (.error reason, entered.2)
  | .ok _ =>
    let (result, final) := work () limits entered.2
    let count := final.budget.body.temporary - ctx.budget.body.temporary
    (result, { final with budget := release final.budget .temporary count (Nat.sub_le _ _) })

/-- 番号走査中の枠・操作・保存の失敗を番号未取得へ分類する。 -/
def numbering (work : Unit → Analysis α) : Analysis α := fun limits ctx =>
  let (result, final) := work () limits ctx
  match result with
  | .error (.budget (.exceeded failure)) => (.error (.budget (.unidentified failure)), final)
  | _ => (result, final)

/-- 一出現のキーと式への参照を、確保に成功してから保存する。 -/
def identify (source : Expr) : Analysis OperationKey := do
  let ctx ← get
  let (key, next) ← scan (BudgetScan.identify ctx.next)
  modify fun ctx => { ctx with next := next, identitiesRev := (key, source) :: ctx.identitiesRev }
  pure key

/-- 局所走査の停止は、既得の警告・対応・次番号・未対応の記録を変更しない。 -/
theorem scan_preserves_saved (work : BudgetScan.Scan α) (limits : Limits) (ctx : Context) :
    (scan work limits ctx).2.warningsRev = ctx.warningsRev ∧
    (scan work limits ctx).2.identitiesRev = ctx.identitiesRev ∧
    (scan work limits ctx).2.next = ctx.next ∧
    (scan work limits ctx).2.unsupported = ctx.unsupported := by
  unfold scan
  cases work.run limits ctx.budget <;> exact ⟨rfl, rfl, rfl, rfl⟩

/-- 番号未取得への分類だけで、途中までの保存列と消費を失わない。 -/
theorem numbering_context (work : Unit → Analysis α) (limits : Limits) (ctx : Context) :
    (numbering work limits ctx).2 = (work () limits ctx).2 := by
  unfold numbering
  cases work () limits ctx with
  | mk result final =>
    cases result with
    | ok => rfl
    | error reason =>
      cases reason with
      | depth => rfl
      | budget reason => cases reason <;> rfl

mutual
/-- 未対応・未到達の部分木は値を解析せず番号だけを辿る。 -/
def skipExpr : Nat → Expr → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, source => numbering fun _ => scope fun _ => do
    let _ ← identify source
    skipChildren fuel source

/-- 容器の列を先に平坦化せず、宣言のフィールド順に読む。 -/
def skipChildren : Nat → Expr → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, source =>
    match source with
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit => pure ()
    | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es => skipExprs fuel es
    | .constE _ e | .paren e | .neg _ e | .not e | .returnE _ e
    | .tryResult _ _ _ e | .tryOption _ _ _ e | .resume _ e => skipExpr fuel e
    | .block body | .lam _ _ _ _ body | .lazyE body => skipBlock fuel body
    | .handleFail _ _ body clause => do skipBlock fuel body; skipBlock fuel clause
    | .recordUpdate _ _ _ _ base es => do skipExpr fuel base; skipExprs fuel es
    | .call callee _ _ es => do skipExpr fuel callee; skipExprs fuel es
    | .pipe left right | .binary _ _ left right | .and left right | .or left right => do
      skipExpr fuel left; skipExpr fuel right
    | .partialCall callee _ args _ _ => do skipExpr fuel callee; skipHoles fuel args
    | .partialCon _ _ args => skipHoles fuel args
    | .listSpread _ concat before spread after => do
      skipExpr fuel concat; skipExprs fuel before; skipExpr fuel spread; skipExprs fuel after
    | .interpolation _ es converters => do skipExprs fuel es; skipExprs fuel converters
    | .ite cond yes no => do skipExpr fuel cond; skipBlock fuel yes; skipBlock fuel no
    | .elseIf cond yes no => do skipExpr fuel cond; skipBlock fuel yes; skipExpr fuel no
    | .ifOnly cond yes => do skipExpr fuel cond; skipBlock fuel yes
    | .matchE _ source arms => do skipExpr fuel source; skipArms fuel arms
    | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message => do
      skipExpr fuel e; skipOptional fuel message
    | .withE _ e body => do skipExpr fuel e; skipBlock fuel body
    | .handleE body clauses => do skipBlock fuel body; skipClauses fuel clauses

def skipExprs : Nat → Exprs → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, es => numbering fun _ => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match es with
    | .nil => pure ()
    | .cons e rest => do skipExpr fuel e; skipExprs fuel rest

def skipHoles : Nat → HoleArgs → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, args => numbering fun _ => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match args with
    | .nil => pure ()
    | .expr _ _ e rest => do skipExpr fuel e; skipHoles fuel rest
    | .hole _ _ _ rest => skipHoles fuel rest

def skipBlock : Nat → Block → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, body => numbering fun _ => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match body with
    | .empty => pure ()
    | .builderBind _ rest => skipBlock fuel rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => skipExpr fuel e
    | .bind _ _ e rest | .discard e rest | .seq e rest | .bindPat _ _ _ e rest => do
      skipExpr fuel e; skipBlock fuel rest

def skipArms : Nat → Arms → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, arms => numbering fun _ => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match arms with
    | .nil => pure ()
    | .cons _ guard body rest => do
      skipOptional fuel guard; skipBlock fuel body; skipArms fuel rest

def skipClauses : Nat → Clauses → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, clauses => numbering fun _ => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match clauses with
    | .nil => pure ()
    | .cons _ _ _ body rest _ => do skipBlock fuel body; skipClauses fuel rest

def skipOptional : Nat → Option Expr → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, value =>
    match value with
    | none => pure ()
    | some e => skipExpr fuel e
end
end Benitoite.Interval.BudgetAnalysis
