import Benitoite.Interval.BudgetPatterns
import Benitoite.Interval.RangeBorrowed

/-! # Range の固定個数の借用読出し

元の容器を一位置ずつ読み、可変長の一時Listへ変換しない。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface Benitoite.Release Budget

/-- 長さは指定数までだけ調べ、越えた列を最後まで数えない。 -/
def rangeLength (entries : List α) (count : Nat) : Scan Bool := frame fun _ => do
  tick .classification
  match entries, count with
  | [], 0 => pure true
  | [], _ + 1 | _ :: _, 0 => pure false
  | _ :: rest, count + 1 => rangeLength rest count

/-- 三位置は元の列を借用し、一項ずつ分類してから固定長の組にする。 -/
def rangeThree (entries : List α) : Scan (Option (α × α × α)) := frame fun _ => do
  tick .classification
  match entries with
  | [] => pure none
  | first :: rest => do
    tick .classification
    match rest with
    | [] => pure none
    | second :: rest => do
      tick .classification
      match rest with
      | [] => pure none
      | third :: rest => do
        tick .classification
        match rest with
        | [] => pure (some (first, second, third))
        | _ :: _ => pure none

/-- 一位置も元の列を借用し、二番目がないことを計上する。 -/
def rangeOne (entries : List α) : Scan (Option α) := frame fun _ => do
  tick .classification
  match entries with
  | [] => pure none
  | first :: rest => do
    tick .classification
    match rest with
    | [] => pure (some first)
    | _ :: _ => pure none

/-- Exprsの三引数もListへ変換せず、元の容器を一項ずつ借用する。 -/
def rangeThreeExprs (entries : Exprs) : Scan (Option (Expr × Expr × Expr)) := frame fun _ => do
  tick .classification
  match entries with
  | .nil => pure none
  | .cons first rest => do
    tick .classification
    match rest with
    | .nil => pure none
    | .cons second rest => do
      tick .classification
      match rest with
      | .nil => pure none
      | .cons third rest => do
        tick .classification
        match rest with
        | .nil => pure (some (first, second, third))
        | .cons _ _ => pure none

/-- 単一引数の認定もListを作らない。 -/
def rangeOneExprs (entries : Exprs) : Scan (Option Expr) := frame fun _ => do
  tick .classification
  match entries with
  | .nil => pure none
  | .cons first rest => do
    tick .classification
    match rest with
    | .nil => pure (some first)
    | .cons _ _ => pure none

/-- 借用した三位置の六通りだけを並べ替え、Permを実行しない。 -/
def rangeBorrowCheck (labels : List (Option String)) (positions : List Nat) (arguments : Exprs) :
    Scan (Option (Expr × Expr × Expr)) := do
  let count ← rangeLength labels 3
  if !count then pure none else do
    let arguments ← rangeThreeExprs arguments
    match arguments with
    | none => pure none
    | some (a, b, c) =>
      let positions ← rangeThree positions
      pure (positions.bind fun (p, q, r) => borrowRangeOrder p q r a b c)

/-- valueの一位置も、位置0と単一引数だけを借用する。 -/
def rangeBorrowValue (labels : List (Option String)) (positions : List Nat) (arguments : Exprs) :
    Scan (Option Expr) := do
  let count ← rangeLength labels 1
  if !count then pure none else do
    let position ← rangeOne positions
    match position with
    | some 0 => rangeOneExprs arguments
    | _ => pure none

/-- 固定三値の純粋な借用。成功値を述べるためだけの定義。 -/
def rangeThreeValue (entries : List α) : Option (α × α × α) :=
  match entries with | [a, b, c] => some (a, b, c) | _ => none

/-- 単一値の純粋な借用。成功値を述べるためだけの定義。 -/
def rangeOneValue (entries : List α) : Option α :=
  match entries with | [a] => some a | _ => none

def rangeThreeExprsValue (entries : Exprs) : Option (Expr × Expr × Expr) :=
  match entries with | .cons a (.cons b (.cons c .nil)) => some (a, b, c) | _ => none

def rangeOneExprsValue (entries : Exprs) : Option Expr :=
  match entries with | .cons a .nil => some a | _ => none

theorem rangeLength_agrees (entries : List α) (count : Nat) :
    Agrees (rangeLength entries count) (decide (entries.length = count)) := by
  rw [rangeLength.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => cases count <;> exact agrees_pure _
  | cons first rest =>
    cases count with
    | zero => exact agrees_pure _
    | succ count => simpa using rangeLength_agrees rest count

theorem rangeThree_agrees (entries : List α) :
    Agrees (rangeThree entries) (rangeThreeValue entries) := by
  unfold rangeThree
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons a rest =>
    apply agrees_bind (agrees_unit _)
    cases rest with
    | nil => exact agrees_pure _
    | cons b rest =>
      apply agrees_bind (agrees_unit _)
      cases rest with
      | nil => exact agrees_pure _
      | cons c rest =>
        apply agrees_bind (agrees_unit _)
        cases rest <;> exact agrees_pure _

theorem rangeOne_agrees (entries : List α) :
    Agrees (rangeOne entries) (rangeOneValue entries) := by
  unfold rangeOne
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons a rest =>
    apply agrees_bind (agrees_unit _)
    cases rest <;> exact agrees_pure _

theorem rangeThreeExprs_agrees (entries : Exprs) :
    Agrees (rangeThreeExprs entries) (rangeThreeExprsValue entries) := by
  unfold rangeThreeExprs
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons a rest =>
    apply agrees_bind (agrees_unit _)
    cases rest with
    | nil => exact agrees_pure _
    | cons b rest =>
      apply agrees_bind (agrees_unit _)
      cases rest with
      | nil => exact agrees_pure _
      | cons c rest =>
        apply agrees_bind (agrees_unit _)
        cases rest <;> exact agrees_pure _

theorem rangeOneExprs_agrees (entries : Exprs) :
    Agrees (rangeOneExprs entries) (rangeOneExprsValue entries) := by
  unfold rangeOneExprs
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons a rest =>
    apply agrees_bind (agrees_unit _)
    cases rest <;> exact agrees_pure _

private theorem check_recipe (labels : List (Option String)) (positions : List Nat) (arguments : Exprs) :
    borrowRangeArgs labels positions arguments =
      if labels.length = 3 then do
        let (a, b, c) ← rangeThreeExprsValue arguments
        let (p, q, r) ← rangeThreeValue positions
        borrowRangeOrder p q r a b c
      else none := by
  cases labels with
  | nil => rfl
  | cons l1 labels =>
    cases labels with
    | nil => rfl
    | cons l2 labels =>
      cases labels with
      | nil => rfl
      | cons l3 labels =>
        cases labels with
        | cons => simp [borrowRangeArgs]
        | nil =>
          cases arguments with
          | nil => rfl
          | cons a arguments =>
            cases arguments with
            | nil => rfl
            | cons b arguments =>
              cases arguments with
              | nil => rfl
              | cons c arguments =>
                cases arguments with
                | cons => rfl
                | nil =>
                  cases positions with
                  | nil => rfl
                  | cons p positions =>
                    cases positions with
                    | nil => rfl
                    | cons q positions =>
                      cases positions with
                      | nil => rfl
                      | cons r positions => cases positions <;> rfl

private theorem value_recipe (labels : List (Option String)) (positions : List Nat) (arguments : Exprs) :
    borrowValueArg labels positions arguments =
      if labels.length = 1 then do
        let position ← rangeOneValue positions
        if position = 0 then rangeOneExprsValue arguments else none
      else none := by
  cases labels with
  | nil => rfl
  | cons label labels =>
    cases labels with
    | cons => simp [borrowValueArg]
    | nil =>
      cases positions with
      | nil => rfl
      | cons position positions =>
        cases position <;> cases positions <;> cases arguments <;> try rfl
        all_goals rename_i first rest; cases rest <;> rfl

theorem rangeBorrowCheck_agrees (labels positions arguments) :
    Agrees (rangeBorrowCheck labels positions arguments) (borrowRangeArgs labels positions arguments) := by
  rw [check_recipe]
  unfold rangeBorrowCheck
  apply agrees_bind (rangeLength_agrees labels 3)
  by_cases h : labels.length = 3
  · simp only [h, decide_true, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
    apply agrees_bind (rangeThreeExprs_agrees arguments)
    cases found : rangeThreeExprsValue arguments with
    | none => exact agrees_pure _
    | some values =>
      rcases values with ⟨a, b, c⟩
      apply agrees_bind (rangeThree_agrees positions)
      exact agrees_pure _
  · simp only [h, decide_false, Bool.not_false, ↓reduceIte]
    exact agrees_pure _

theorem rangeBorrowValue_agrees (labels positions arguments) :
    Agrees (rangeBorrowValue labels positions arguments) (borrowValueArg labels positions arguments) := by
  rw [value_recipe]
  unfold rangeBorrowValue
  apply agrees_bind (rangeLength_agrees labels 1)
  by_cases h : labels.length = 1
  · simp only [h, decide_true, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
    apply agrees_bind (rangeOne_agrees positions)
    cases found : rangeOneValue positions with
    | none => exact agrees_pure _
    | some position =>
      cases position with
      | zero => exact rangeOneExprs_agrees arguments
      | succ => exact agrees_pure _
  · simp only [h, decide_false, Bool.not_false, ↓reduceIte]
    exact agrees_pure _

end Benitoite.Interval.BudgetScan
