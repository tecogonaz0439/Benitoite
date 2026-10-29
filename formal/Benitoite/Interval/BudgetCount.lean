import Benitoite.Interval.BudgetPatterns

/-!
# 別本体の開始位置を求める予算付きの先読み

節の開始位置は保護本体と先行する節の式数から求める。
番号の対応表を作らず、各出現と容器の走査を同じ予算に計上する。
（設計書 01-12「区間解析の予算付きの別本体の発見」）。
-/
namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface

private def plus (left right : Scan Nat) : Scan Nat := do
  let a ← left
  let b ← right
  pure (a + b)

mutual
def countExpr (source : Expr) : Scan Nat := forNumbering fun _ => frame fun _ => do
  tick .numbering
  let count ← match source with
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit => pure 0
    | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es => countExprs es
    | .constE _ e | .paren e | .neg _ e | .not e | .returnE _ e
    | .tryResult _ _ _ e | .tryOption _ _ _ e | .resume _ e => countExpr e
    | .block body | .lam _ _ _ _ body | .lazyE body => countBlock body
    | .handleFail _ _ body clause => plus (countBlock body) (countBlock clause)
    | .recordUpdate _ _ _ _ base es | .call base _ _ es => plus (countExpr base) (countExprs es)
    | .pipe lhs rhs | .binary _ _ lhs rhs | .and lhs rhs | .or lhs rhs =>
        plus (countExpr lhs) (countExpr rhs)
    | .partialCall callee _ args _ _ => plus (countExpr callee) (countHoles args)
    | .partialCon _ _ args => countHoles args
    | .listSpread _ concat before spread after =>
        plus (countExpr concat) (plus (countExprs before) (plus (countExpr spread) (countExprs after)))
    | .interpolation _ es converters => plus (countExprs es) (countExprs converters)
    | .ite cond yes no => plus (countExpr cond) (plus (countBlock yes) (countBlock no))
    | .elseIf cond yes no => plus (countExpr cond) (plus (countBlock yes) (countExpr no))
    | .ifOnly cond yes => plus (countExpr cond) (countBlock yes)
    | .matchE _ scrutinee arms => plus (countExpr scrutinee) (countArms arms)
    | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message =>
        plus (countExpr e) (countOptional message)
    | .withE _ e body => plus (countExpr e) (countBlock body)
    | .handleE body clauses => plus (countBlock body) (countClauses clauses)
  pure (1 + count)

def countExprs (sources : Exprs) : Scan Nat := forNumbering fun _ => frame fun _ => do
  tick .classification
  match sources with
  | .nil => pure 0
  | .cons source rest => plus (countExpr source) (countExprs rest)

def countHoles (args : HoleArgs) : Scan Nat := forNumbering fun _ => frame fun _ => do
  tick .classification
  match args with
  | .nil => pure 0
  | .expr _ _ source rest => plus (countExpr source) (countHoles rest)
  | .hole _ _ _ rest => countHoles rest

def countBlock (body : Block) : Scan Nat := forNumbering fun _ => frame fun _ => do
  tick .classification
  match body with
  | .empty => pure 0
  | .builderBind _ rest => countBlock rest
  | .last source | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source => countExpr source
  | .bind _ _ source rest | .discard source rest | .seq source rest | .bindPat _ _ _ source rest =>
      plus (countExpr source) (countBlock rest)

def countArms (arms : Arms) : Scan Nat := forNumbering fun _ => frame fun _ => do
  tick .classification
  match arms with
  | .nil => pure 0
  | .cons _ guard body rest => plus (countOptional guard) (plus (countBlock body) (countArms rest))

def countClauses (clauses : Clauses) : Scan Nat := forNumbering fun _ => frame fun _ => do
  tick .classification
  match clauses with
  | .nil => pure 0
  | .cons _ _ _ body rest _ => plus (countBlock body) (countClauses rest)

def countOptional (source : Option Expr) : Scan Nat :=
  match source with
  | none => pure 0
  | some source => countExpr source
end

private theorem plus_agrees {left right : Scan Nat} {a b : Nat}
    (hl : Agrees left a) (hr : Agrees right b) : Agrees (plus left right) (a + b) := by
  apply agrees_bind hl
  apply agrees_bind hr
  exact agrees_pure _

mutual
theorem countExpr_agrees (source : Expr) : Agrees (countExpr source) (surfaceSize source) := by
  rw [countExpr.eq_def]
  apply agrees_forNumbering; apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases source <;>
    simp only [surfaceSize, surfacePreorder, List.length_cons, List.length_append, List.length_nil]
  all_goals
    apply agrees_bind
    · first
      | exact agrees_pure 0
      | exact countExpr_agrees _
      | exact countExprs_agrees _
      | exact countHoles_agrees _
      | exact countBlock_agrees _
      | exact plus_agrees (countExpr_agrees _) (countExpr_agrees _)
      | exact plus_agrees (countExpr_agrees _) (countExprs_agrees _)
      | exact plus_agrees (countExpr_agrees _) (countHoles_agrees _)
      | exact plus_agrees (countExprs_agrees _) (countExprs_agrees _)
      | exact plus_agrees (countExpr_agrees _) (countBlock_agrees _)
      | exact plus_agrees (countExpr_agrees _) (countArms_agrees _)
      | exact plus_agrees (countExpr_agrees _) (countOptional_agrees _)
      | exact plus_agrees (countBlock_agrees _) (countBlock_agrees _)
      | exact plus_agrees (countBlock_agrees _) (countClauses_agrees _)
      | exact plus_agrees (countExpr_agrees _) (plus_agrees (countBlock_agrees _) (countBlock_agrees _))
      | exact plus_agrees (countExpr_agrees _) (plus_agrees (countBlock_agrees _) (countExpr_agrees _))
      | exact plus_agrees (countExpr_agrees _) (plus_agrees (countExprs_agrees _)
          (plus_agrees (countExpr_agrees _) (countExprs_agrees _)))
    · first
      | simpa only [surfacePreorder, List.length_cons, List.length_append, List.length_nil, surfaceSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using (agrees_pure _)
      | rename_i message; cases message <;>
          simpa only [surfacePreorder, List.length_cons, List.length_append, List.length_nil, surfaceSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using (agrees_pure _)

theorem countExprs_agrees (sources : Exprs) :
    Agrees (countExprs sources) (preorderExprs sources).length := by
  rw [countExprs.eq_def]
  apply agrees_forNumbering; apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases sources with
  | nil => exact agrees_pure _
  | cons source rest =>
    simpa only [preorderExprs, List.length_append, surfaceSize] using
      (plus_agrees (countExpr_agrees source) (countExprs_agrees rest))

theorem countHoles_agrees (args : HoleArgs) : Agrees (countHoles args) (preorderHoles args).length := by
  rw [countHoles.eq_def]
  apply agrees_forNumbering; apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases args with
  | nil => exact agrees_pure _
  | expr _ _ source rest =>
    simpa only [preorderHoles, List.length_append, surfaceSize] using
      (plus_agrees (countExpr_agrees source) (countHoles_agrees rest))
  | hole _ _ _ rest => exact countHoles_agrees rest

theorem countBlock_agrees (body : Block) : Agrees (countBlock body) (preorderBlock body).length := by
  rw [countBlock.eq_def]
  apply agrees_forNumbering; apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases body <;> first
    | exact agrees_pure _
    | exact countExpr_agrees _
    | exact countBlock_agrees _
    | simpa only [preorderBlock, List.length_append, surfaceSize] using
        (plus_agrees (countExpr_agrees _) (countBlock_agrees _))

theorem countArms_agrees (arms : Arms) : Agrees (countArms arms) (preorderArms arms).length := by
  rw [countArms.eq_def]
  apply agrees_forNumbering; apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases arms with
  | nil => exact agrees_pure _
  | cons alts guard body rest =>
    cases guard with
    | none =>
      simpa only [preorderArms, List.length_append, List.length_nil, Nat.zero_add, surfaceSize, Nat.add_assoc] using
        (plus_agrees (countOptional_agrees none) (plus_agrees (countBlock_agrees body) (countArms_agrees rest)))
    | some g =>
      simpa only [preorderArms, List.length_append, surfaceSize, Nat.add_assoc] using
        (plus_agrees (countOptional_agrees (some g)) (plus_agrees (countBlock_agrees body) (countArms_agrees rest)))

theorem countClauses_agrees (clauses : Clauses) :
    Agrees (countClauses clauses) (preorderClauses clauses).length := by
  rw [countClauses.eq_def]
  apply agrees_forNumbering; apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases clauses with
  | nil => exact agrees_pure _
  | cons _ _ _ body rest _ =>
    simpa only [preorderClauses, List.length_append] using
      (plus_agrees (countBlock_agrees body) (countClauses_agrees rest))

theorem countOptional_agrees (source : Option Expr) :
    Agrees (countOptional source) (match source with | none => 0 | some e => surfaceSize e) := by
  cases source with
  | none => exact agrees_pure _
  | some e => exact countExpr_agrees e
end
end Benitoite.Interval.BudgetScan
