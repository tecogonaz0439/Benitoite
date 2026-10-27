import Benitoite.Interval.BudgetRangeBorrow

/-! # 固定域の認定で使う列の予算付き走査

読み取り専用の型列は借用し、置換の検査に作る列だけを一時項目として計上する。
-/
namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface Benitoite.Release Budget

/-- Exprs の容器だけを数え、式本体や変換した List を作らない。 -/
def domainExprsLength (sources : Exprs) : Scan Nat := frame fun _ => do
  tick .classification
  match sources with
  | .nil => pure 0
  | .cons _ rest => pure ((← domainExprsLength rest) + 1)

/-- 参照する型の位置までだけを読む。 -/
def domainEntry (entries : List α) (index : Nat) : Scan (Option α) := frame fun _ => do
  tick .environmentRead
  match entries, index with
  | [], _ => pure none
  | value :: _, 0 => pure (some value)
  | _ :: rest, index + 1 => domainEntry rest index

/-- 置換検査の基準列を、一項ずつ計上して作る。 -/
def domainRange (start count : Nat) : Scan (List Nat) := frame fun _ => do
  tick .classification
  match count with
  | 0 => pure []
  | count + 1 =>
    allocate .auxiliary
    let rest ← domainRange (start + 1) count
    pure (start :: rest)

/-- 最初の一致までを読み、削除する接頭辞の複写だけを計上する。 -/
def domainErase (value : Nat) (entries : List Nat) : Scan (List Nat) := frame fun _ => do
  tick .classification
  match entries with
  | [] => pure []
  | first :: rest =>
    if first == value then pure rest else do
      allocate .auxiliary
      pure (first :: (← domainErase value rest))

/-- 元の列を借用して一要素の所属を調べる。 -/
def domainContains (value : Nat) (entries : List Nat) : Scan Bool := frame fun _ => do
  tick .classification
  match entries with
  | [] => pure false
  | first :: rest => if value == first then pure true else domainContains value rest

/-- isPerm と同じ順に所属・削除・残りを調べる。 -/
def domainIsPerm (positions expected : List Nat) : Scan Bool := frame fun _ => do
  tick .classification
  match positions with
  | [] => pure expected.isEmpty
  | position :: rest =>
    if ← domainContains position expected then do
      let remaining ← domainErase position expected
      domainIsPerm rest remaining
    else pure false

/-- 検査にだけ使った可変長の列は、成否とも領域を閉じて返却する。 -/
def domainPermutation (positions : List Nat) (count : Nat) : Scan Bool := region fun _ => do
  let expected ← domainRange 0 count
  domainIsPerm positions expected

theorem domainExprsLength_agrees (sources : Exprs) :
    Agrees (domainExprsLength sources) (exprsChildren sources).length := by
  rw [domainExprsLength.eq_def]
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases sources with
  | nil => exact agrees_pure _
  | cons source rest =>
    apply agrees_bind (domainExprsLength_agrees rest)
    exact agrees_pure _

theorem domainEntry_agrees (entries : List α) (index : Nat) :
    Agrees (domainEntry entries index) entries[index]? := by
  rw [domainEntry.eq_def]
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons first rest => cases index with
    | zero => exact agrees_pure _
    | succ index => exact domainEntry_agrees rest index

theorem domainRange_agrees (start count : Nat) :
    Agrees (domainRange start count) (List.range' start count) := by
  rw [domainRange.eq_def]
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases count with
  | zero => exact agrees_pure _
  | succ count =>
    apply agrees_bind (agrees_unit _)
    apply agrees_bind (domainRange_agrees (start + 1) count)
    exact agrees_pure _

theorem domainErase_agrees (value : Nat) (entries : List Nat) :
    Agrees (domainErase value entries) (entries.erase value) := by
  rw [domainErase.eq_def]
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons first rest =>
    by_cases same : first = value
    · simp [same]
      exact agrees_pure _
    · simp only [beq_eq_false_iff_ne.mpr same, Bool.false_eq_true, ↓reduceIte]
      apply agrees_bind (agrees_unit _)
      apply agrees_bind (domainErase_agrees value rest)
      simpa [List.erase_cons, same] using agrees_pure (first :: rest.erase value)

theorem domainContains_agrees (value : Nat) (entries : List Nat) :
    Agrees (domainContains value entries) (entries.contains value) := by
  rw [domainContains.eq_def]
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons first rest =>
    by_cases same : value = first
    · simpa [same, List.contains_cons] using agrees_pure true
    · simpa [same, List.contains_cons] using domainContains_agrees value rest

theorem domainIsPerm_agrees (positions expected : List Nat) :
    Agrees (domainIsPerm positions expected) (positions.isPerm expected) := by
  rw [domainIsPerm.eq_def]
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases positions with
  | nil => exact agrees_pure _
  | cons position rest =>
    apply agrees_bind (domainContains_agrees position expected)
    cases found : expected.contains position <;> simp only [found, Bool.false_eq_true, ↓reduceIte, List.isPerm, Bool.false_and, Bool.true_and]
    · exact agrees_pure _
    · apply agrees_bind (domainErase_agrees position expected)
      exact domainIsPerm_agrees rest (expected.erase position)

theorem domainPermutation_agrees (positions : List Nat) (count : Nat) :
    Agrees (domainPermutation positions count) (decide (positions.Perm (List.range count))) := by
  unfold domainPermutation
  apply agrees_region
  apply agrees_bind (domainRange_agrees 0 count)
  have same : positions.isPerm (List.range count) = decide (positions.Perm (List.range count)) := by
    apply Bool.eq_iff_iff.mpr
    simp only [List.isPerm_iff, decide_eq_true_eq]
  rw [← same]
  simpa only [← List.range_eq_range'] using domainIsPerm_agrees positions (List.range count)

end Benitoite.Interval.BudgetScan
