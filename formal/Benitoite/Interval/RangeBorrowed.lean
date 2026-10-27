import Benitoite.Interval.Range

/-!
# Range の固定個数の借用認定

実行する認定は固定個数の構文を借用し、列の変換・長さ・置換・欄の再走査を行わない。
純規則との対応に使う列の走査は、このファイルの証明の中だけに置く。
-/
namespace Benitoite.Interval
open Benitoite.Surface Benitoite.Release

/-- 三位置の置換は六通りに限る。任意の長さの位置列について述べる。 -/
theorem range_positions_three_iff (positions : List Nat) :
    positions.Perm [0, 1, 2] ↔
      positions = [0, 1, 2] ∨ positions = [0, 2, 1] ∨ positions = [1, 0, 2] ∨
      positions = [1, 2, 0] ∨ positions = [2, 0, 1] ∨ positions = [2, 1, 0] := by
  constructor
  · intro perm
    have length : positions.length = 3 := by simpa using perm.length_eq
    obtain ⟨a, b, c, shape⟩ : ∃ a b c, positions = [a, b, c] :=
      ⟨_, _, _, List.eq_getElem_of_length_eq_three positions length⟩
    subst positions
    have ha : a = 0 ∨ a = 1 ∨ a = 2 := by
      simpa using perm.subset (by simp : a ∈ [a, b, c])
    have hb : b = 0 ∨ b = 1 ∨ b = 2 := by
      simpa using perm.subset (by simp : b ∈ [a, b, c])
    have hc : c = 0 ∨ c = 1 ∨ c = 2 := by
      simpa using perm.subset (by simp : c ∈ [a, b, c])
    rcases ha with rfl | rfl | rfl <;>
      rcases hb with rfl | rfl | rfl <;>
      rcases hc with rfl | rfl | rfl
    all_goals first | decide +kernel | exact False.elim (by revert perm; decide +kernel)
  · intro shape
    rcases shape with rfl | rfl | rfl | rfl | rfl | rfl <;> decide +kernel

/-- 一引数の列は変換後の長さ1と同値である。 -/
theorem range_arguments_one_iff (sources : Exprs) :
    (exprsChildren sources).length = 1 ↔ ∃ source, sources = .cons source .nil := by
  cases sources with
  | nil => simp [exprsChildren]
  | cons source rest =>
    cases rest with
    | nil => simp [exprsChildren]
    | cons next rest => simp [exprsChildren]

/-- 三引数の列は変換後の長さ3と同値である。 -/
theorem range_arguments_three_iff (sources : Exprs) :
    (exprsChildren sources).length = 3 ↔
      ∃ first second third, sources = .cons first (.cons second (.cons third .nil)) := by
  cases sources with
  | nil => simp [exprsChildren]
  | cons first rest =>
    cases rest with
    | nil => simp [exprsChildren]
    | cons second rest =>
      cases rest with
      | nil => simp [exprsChildren]
      | cons third rest =>
        cases rest with
        | nil => simp [exprsChildren]
        | cons fourth rest => simp [exprsChildren]

/-- 三つの契約位置と式だけを受け取り、元の列を読み直さずに並べ替える。 -/
def borrowRangeOrder (p q r : Nat) (first second third : Expr) : Option (Expr × Expr × Expr) :=
  match p, q, r with
  | 0, 1, 2 => some (first, second, third)
  | 0, 2, 1 => some (first, third, second)
  | 1, 0, 2 => some (second, first, third)
  | 1, 2, 0 => some (third, first, second)
  | 2, 0, 1 => some (second, third, first)
  | 2, 1, 0 => some (third, second, first)
  | _, _, _ => none

/-- 三つの正常入力を契約順の lower・upper・value として借用する。 -/
def borrowRangeArgs (labels : List (Option String)) (positions : List Nat)
    (sources : Exprs) : Option (Expr × Expr × Expr) :=
  match labels, sources with
  | [_, _, _], .cons first (.cons second (.cons third .nil)) =>
    match positions with
    | [p, q, r] => borrowRangeOrder p q r first second third
    | _ => none
  | _, _ => none

/-- 直接射影の一引数だけを借用する。 -/
def borrowValueArg (labels : List (Option String)) (positions : List Nat)
    (sources : Exprs) : Option Expr :=
  match labels, positions, sources with
  | [_], [0], .cons source .nil => some source
  | _, _, _ => none

/-- 借用に成功した三値は、純規則の認定と三つの欄に一致する。 -/
theorem borrowRangeArgs_spec {labels positions sources lower upper value}
    (found : borrowRangeArgs labels positions sources = some (lower, upper, value)) :
    labels.length = 3 ∧ positions.Perm [0, 1, 2] ∧ (exprsChildren sources).length = 3 ∧
      fieldAt 0 positions (exprsChildren sources) = some lower ∧
      fieldAt 1 positions (exprsChildren sources) = some upper ∧
      fieldAt 2 positions (exprsChildren sources) = some value := by
  unfold borrowRangeArgs at found
  split at found
  · split at found
    · unfold borrowRangeOrder at found
      split at found <;> simp_all [exprsChildren, fieldAt, List.cons_perm_iff_perm_erase]
    · simp at found
  · simp at found

/-- 借用の有無は、既存の認定の三条件と一致する。 -/
theorem borrowRangeArgs_isSome (labels positions sources) :
    (borrowRangeArgs labels positions sources).isSome = true ↔
      labels.length = 3 ∧ positions.Perm [0, 1, 2] ∧ (exprsChildren sources).length = 3 := by
  constructor
  · intro found
    cases known : borrowRangeArgs labels positions sources with
    | none => simp [known] at found
    | some result =>
      rcases result with ⟨lower, upper, value⟩
      have spec := borrowRangeArgs_spec known
      exact ⟨spec.1, spec.2.1, spec.2.2.1⟩
  · rintro ⟨labelsLength, positionsKnown, argsLength⟩
    obtain ⟨l1, l2, l3, rfl⟩ : ∃ l1 l2 l3, labels = [l1, l2, l3] :=
      ⟨_, _, _, List.eq_getElem_of_length_eq_three labels labelsLength⟩
    obtain ⟨first, second, third, rfl⟩ := (range_arguments_three_iff sources).mp argsLength
    rcases (range_positions_three_iff positions).mp positionsKnown with
      rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- 借用した結果と純規則の欄の三値は同じである。 -/
theorem borrowRangeArgs_eq (labels positions sources lower upper value) :
    borrowRangeArgs labels positions sources = some (lower, upper, value) ↔
    labels.length = 3 ∧ positions.Perm [0, 1, 2] ∧ (exprsChildren sources).length = 3 ∧
      fieldAt 0 positions (exprsChildren sources) = some lower ∧
      fieldAt 1 positions (exprsChildren sources) = some upper ∧
      fieldAt 2 positions (exprsChildren sources) = some value := by
  constructor
  · exact borrowRangeArgs_spec
  · rintro ⟨labelsLength, positionsKnown, argsLength, lowerAt, upperAt, valueAt⟩
    obtain ⟨l1, l2, l3, rfl⟩ : ∃ l1 l2 l3, labels = [l1, l2, l3] :=
      ⟨_, _, _, List.eq_getElem_of_length_eq_three labels labelsLength⟩
    obtain ⟨first, second, third, rfl⟩ := (range_arguments_three_iff sources).mp argsLength
    rcases (range_positions_three_iff positions).mp positionsKnown with
      rfl | rfl | rfl | rfl | rfl | rfl <;>
      simp_all [borrowRangeArgs, borrowRangeOrder, exprsChildren, fieldAt]

/-- 一引数の借用は、既存の個数と契約位置の条件に一致する。 -/
theorem borrowValueArg_isSome (labels positions sources) :
    (borrowValueArg labels positions sources).isSome = true ↔
      labels.length = 1 ∧ positions = [0] ∧ (exprsChildren sources).length = 1 := by
  constructor
  · intro found
    unfold borrowValueArg at found
    split at found <;> simp_all [exprsChildren]
  · rintro ⟨labelsLength, rfl, argsLength⟩
    obtain ⟨label, rfl⟩ := List.length_eq_one_iff.mp labelsLength
    obtain ⟨source, rfl⟩ := (range_arguments_one_iff sources).mp argsLength
    rfl

/-- Range の固定個数は借用し、固定域の追加規則は共通の認定を使う。 -/
def borrowRangeCall (env : AbstractEnv) (key : OperationKey) (source : Expr) :
    Option StandardBinding := rangeCallAt env key source

/-- 借用認定の結果は、表層評価と同じ標準呼び出しの認定である。 -/
theorem borrow_range_call_eq (env key source) :
    borrowRangeCall env key source = rangeCallAt env key source := rfl

/-- 固定個数の引数を借用してから、同じ標準宣言と二端点を認定する。 -/
def borrowRangeOrigin (env : AbstractEnv) (input : EvalInput) : Option RangeOrigin := do
  match input.source with
  | .call (.funName declaration [] []) labels positions sources =>
    let (lower, upper, _) ← borrowRangeArgs labels positions sources
    let binding ← env.standardAt input.key
    if declaration ≠ binding.declaration then none else
      match binding.rule with
      | .rangeCheck names => do
        let minimum ← rangeFixedInteger lower
        let maximum ← rangeFixedInteger upper
        some ⟨names, input.key, minimum, maximum⟩
      | _ => none
  | _ => none

/-- 固定個数の借用による由来の認定は、既存の認定と同じである。 -/
theorem borrow_range_origin_eq (env : AbstractEnv) (input : EvalInput) :
    borrowRangeOrigin env input = rangeCallOrigin env input := by
  unfold borrowRangeOrigin rangeCallOrigin
  cases sourceEq : input.source <;> try rfl
  rename_i callee labels positions sources
  cases callee <;> try rfl
  rename_i declaration types effects
  cases types <;> try rfl
  cases effects <;> try rfl
  by_cases hl : labels.length = 3
  · by_cases hp : positions.Perm [0, 1, 2]
    · by_cases ha : (exprsChildren sources).length = 3
      · obtain ⟨l1, l2, l3, rfl⟩ : ∃ l1 l2 l3, labels = [l1, l2, l3] :=
          ⟨_, _, _, List.eq_getElem_of_length_eq_three labels hl⟩
        obtain ⟨first, second, third, rfl⟩ := (range_arguments_three_iff sources).mp ha
        rcases (range_positions_three_iff positions).mp hp with
          rfl | rfl | rfl | rfl | rfl | rfl <;>
          simp [borrowRangeArgs, borrowRangeOrder, exprsChildren, fieldAt,
            List.cons_perm_iff_perm_erase] <;> rfl
      · have noArgs : borrowRangeArgs labels positions sources = none := by
          cases found : borrowRangeArgs labels positions sources with
          | none => rfl
          | some result =>
            have present : (borrowRangeArgs labels positions sources).isSome = true := by simp [found]
            exact False.elim (ha ((borrowRangeArgs_isSome labels positions sources).mp present).2.2)
        simp only [noArgs, Option.bind_none, hl, hp, ne_eq, not_true_eq_false,
          false_or, ↓reduceIte]
        cases found : env.standardAt input.key with
        | none => simp [found]
        | some binding => cases rule : binding.rule <;> simp [found, rule, ha]
    · have noArgs : borrowRangeArgs labels positions sources = none := by
        cases found : borrowRangeArgs labels positions sources with
        | none => rfl
        | some result =>
          have present : (borrowRangeArgs labels positions sources).isSome = true := by simp [found]
          exact False.elim (hp ((borrowRangeArgs_isSome labels positions sources).mp present).2.1)
      simp [noArgs, hp]
  · have noArgs : borrowRangeArgs labels positions sources = none := by
      cases found : borrowRangeArgs labels positions sources with
      | none => rfl
      | some result =>
        have present : (borrowRangeArgs labels positions sources).isSome = true := by simp [found]
        exact False.elim (hl ((borrowRangeArgs_isSome labels positions sources).mp present).1)
    simp [noArgs, hl]

/-- 直接射影の一引数を借用し、同じ標準宣言の所有元と局所位置を得る。 -/
def borrowRangeValueCall (env : AbstractEnv) (input : EvalInput) : Option (RangeRecord × Nat) := do
  match input.type, input.source with
  | .base .integer, .call (.funName declaration [] []) labels positions sources =>
    let source ← borrowValueArg labels positions sources
    match source with
    | .local index =>
      let binding ← env.standardAt input.key
      if declaration ≠ binding.declaration then none else
        match binding.rule with
        | .rangeValue owner => some (owner, index)
        | _ => none
    | _ => none
  | _, _ => none

/-- 一引数の借用による射影の認定は、既存の認定と同じである。 -/
theorem borrow_range_value_call_eq (env : AbstractEnv) (input : EvalInput) :
    borrowRangeValueCall env input = rangeValueCall env input := by
  unfold borrowRangeValueCall rangeValueCall
  cases input with
  | mk source type key =>
    cases type <;> try rfl
    rename_i base
    cases base <;> try rfl
    cases source <;> try rfl
    rename_i callee labels positions sources
    cases callee <;> try rfl
    rename_i declaration types effects
    cases types <;> try rfl
    cases effects <;> try rfl
    cases labels with
    | nil => rfl
    | cons label rest =>
      cases rest with
      | cons => rfl
      | nil =>
        cases positions with
        | nil => rfl
        | cons position rest =>
          cases rest with
          | cons => cases position <;> rfl
          | nil =>
            cases position with
            | succ => rfl
            | zero =>
              cases sources with
              | nil => rfl
              | cons argument rest =>
                cases rest with
                | cons => cases argument <;> rfl
                | nil => cases argument <;> rfl

end Benitoite.Interval
