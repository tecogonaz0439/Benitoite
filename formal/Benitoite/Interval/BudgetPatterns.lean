import Benitoite.Interval.BudgetEnvironment

/-!
# パターンと選択肢の予算付きの走査

束縛数・欄・slots を無制限に事前走査せず、既存の腕入口の規則と対応させる。
（設計書 01-12「区間解析の予算付きの局所走査」）。
-/

namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface
open Benitoite.Release (Ty selectSlots)
open Budget

/-- 列の長さも走査しながら求め、予算外の length を使わない。 -/
def countList (xs : List α) : Scan Nat := frame fun _ => do
  tick .classification
  match xs with
  | [] => pure 0
  | _ :: rest =>
      let count ← countList rest
      pure (count + 1)

/-- レコードパターンの欄を、positions と値の列を同時に辿って読む。 -/
def field (index : Nat) (positions : List Nat) (values : List Nat) : Scan (Option Nat) :=
  frame fun _ => do
    tick .classification
    match positions, values with
    | position :: positions, value :: values =>
        if index = position then pure (some value) else field index positions values
    | _, _ => pure none

/-- 欄を宣言順に分類する。反復前に range の列を作らない。 -/
def fieldsSum (index remaining : Nat) (positions values : List Nat) : Scan Nat := frame fun _ => do
  tick .classification
  match remaining with
  | 0 => pure 0
  | remaining + 1 =>
      let value ← field index positions values
      let rest ← fieldsSum (index + 1) remaining positions values
      pure (value.getD 0 + rest)

mutual
  /-- toCore・binders の無制限の走査を呼ばず、構造を予算付きで分類する。 -/
  def patternBinders (pattern : Pattern) : Scan Nat := frame fun _ => do
    tick .classification
    match pattern with
    | .var => pure 1
    | .con _ _ patterns => patternSum patterns
    | .list before rest after =>
        let front ← patternSum before
        let back ← patternSum after
        pure (front + (rest.map Release.ListRest.binders).getD 0 + back)
    | .record _ count positions patterns => region fun _ => do
        let counts ← patternCounts patterns
        fieldsSum 0 count positions counts
    | _ => pure 0

  /-- 構造の内部の束縛数も、予算外の toCore の呼び出しで求めない。 -/
  def patternSum (patterns : List Pattern) : Scan Nat := frame fun _ => do
    tick .classification
    match patterns with
    | [] => pure 0
    | pattern :: rest =>
        let first ← patternBinders pattern
        let tail ← patternSum rest
        pure (first + tail)

  /-- 欄ごとの束縛数を保持する間は一欄一項とし、recordの分類終了で返す。 -/
  def patternCounts (patterns : List Pattern) : Scan (List Nat) := frame fun _ => do
    tick .classification
    match patterns with
    | [] => pure []
    | pattern :: rest =>
        let first ← patternBinders pattern
        let tail ← patternCounts rest
        allocate .recordField
        pure (first :: tail)
end

/-- 同じ項を必要数だけ追加する。作成した位置だけを環境の保持数に加える。 -/
def replicateOnto (count : Nat) (slot : AbstractSlot) (tail : List AbstractSlot) :
    Scan (List AbstractSlot) := frame fun _ => do
  tick .classification
  match count with
  | 0 => pure tail
  | count + 1 =>
      let rest ← replicateOnto count slot tail
      consSlot slot rest

/-- 通常位置とその固定長の束縛番号欄を、同じ一項の追加で構成する。 -/
def replicateEnv (count : Nat) (slot : AbstractSlot) (env : AbstractEnv) : Scan AbstractEnv :=
  frame fun _ => do
    tick .classification
    match count with
    | 0 => pure env
    | count + 1 => do
      let inner ← replicateEnv count slot env
      push inner slot

/-- 引数を宣言順に読み、追加のたびに先頭へ置く。 -/
def values (env : AbstractEnv) (types : List (Option Ty)) : Scan AbstractEnv := frame fun _ => do
  tick .classification
  match types with
  | [] => pure env
  | type :: rest =>
      let next ← push env (topSlot type)
      values next rest

/-- パターンの内部の型を推測せず、既存の位置の規則を保つ。 -/
def patternSlotsScan (pattern : Pattern) (type : Ty) (range : Interval) : Scan (List AbstractSlot) := do
  tick .classification
  match pattern with
  | .var => consSlot (match type with
      | .base .integer => .integer range
      | _ => topSlot (some type)) []
  | _ => do
      let count ← patternBinders pattern
      replicateOnto count (.unknown none) []

/-- 選択と反転を一度の走査で行う。元の局所列の接尾辞は共有する。 -/
def selectReverse (slots : List AbstractSlot) (positions : List Nat) (tail : List AbstractSlot)
    (ranges : RangeState) : Scan (Option (List AbstractSlot × RangeState)) := frame fun _ => do
  tick .classification
  match positions with
  | [] => pure (some (tail, ranges))
  | position :: rest =>
      let slot ← readSlots slots position
      match slot with
      | none => pure none
      | some slot =>
          let next ← consSlot slot tail
          selectReverse slots rest next (ranges.extend none)

/-- 範囲外の slots を正常な腕入口にせず、同定表を保つ。 -/
def extendSelected (env : AbstractEnv) (slots : List AbstractSlot) (positions : List Nat) :
    Scan (Option AbstractEnv) := do
  let result ← selectReverse slots positions env.locals env.ranges
  pure (result.map fun (locals, ranges) =>
    { env with locals := locals, ranges := ranges })

/-- 照合した直接参照だけを絞り、式の逆算による伝播を加えない。 -/
def scrutinee (env : AbstractEnv) (source : Expr) (type : Ty) (range : Interval) : Scan AbstractEnv :=
  match type with
  | .base .integer => do
      let index ← indexOf source
      match index with
      | none => pure env
      | some index => update env index range
  | _ => pure env

/-- 空の整数の交差では束縛を作らず、正常な到達不能を返す。 -/
def alternative (env : AbstractEnv) (source : Expr) (type : Ty) (normal : Interval)
    (alt : Alternative) : Scan (Option AbstractEnv) := frame fun _ => do
  tick .classification
  let range := matchRange type normal alt.pat
  match type with
  | .base .integer =>
      if range = .bottom then pure none
      else do
        let refined ← scrutinee env source type range
        let slots ← patternSlotsScan alt.pat type range
        extendSelected refined slots alt.slots
  | _ => do
      let refined ← scrutinee env source type range
      let slots ← patternSlotsScan alt.pat type range
      extendSelected refined slots alt.slots

/-- 先の選択肢を完走してから次を走査し、両結果を合流する。 -/
def alternatives (template env : AbstractEnv) (source : Expr) (type : Ty) (normal : Interval)
    (alts : List Alternative) : Scan (Option AbstractEnv) := frame fun _ => do
  tick .classification
  match alts with
  | [] => pure none
  | alt :: rest =>
      let first ← alternative env source type normal alt
      let tail ← alternatives template env source type normal rest
      joinEnvs? template first tail

/-- 腕の共通位置も一項ずつ確保し、大きな replicate を先に作らない。 -/
def armTemplate (env : AbstractEnv) (type : Ty) (count : Nat) : Scan AbstractEnv := do
  let slot := match type with
    | .base .integer => AbstractSlot.integer top
    | _ => .unknown none
  replicateEnv count slot env

private def armCount (alts : List Alternative) : Scan Nat :=
  match alts with
  | [] => pure 0
  | alt :: _ => countList alt.slots

/-- 共通の位置数の取得から選択肢の合流まで、同じ状態を引き継ぐ。 -/
def arm (env : AbstractEnv) (source : Expr) (type : Ty) (normal : Interval)
    (alts : List Alternative) : Scan (Option AbstractEnv) := do
  let count ← armCount alts
  let template ← armTemplate env type count
  alternatives template env source type normal alts

/-- 任意の上限・初期状態について、countList の完走した値は既存の局所規則と一致する。 -/
theorem countList_agrees (xs : List α) : Agrees (countList xs) xs.length := by
  rw [countList.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases xs with
  | nil => exact agrees_pure _
  | cons x rest =>
    apply agrees_bind (countList_agrees rest)
    exact agrees_pure _

/-- 任意の上限・初期状態について、field の完走した値は既存の局所規則と一致する。 -/
theorem field_agrees (index : Nat) (positions values : List Nat) :
    Agrees (field index positions values) (fieldAt index positions values) := by
  rw [field.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases positions with
  | nil => cases values <;> exact agrees_pure _
  | cons position positions =>
    cases values with
    | nil => exact agrees_pure _
    | cons value values =>
      by_cases h : index = position
      · simpa [fieldAt, h] using agrees_pure (some value)
      · simpa [fieldAt, h] using field_agrees index positions values

/-- 任意の上限・初期状態について、fieldsSum の完走した値は既存の局所規則と一致する。 -/
theorem fieldsSum_agrees (index remaining : Nat) (positions values : List Nat) :
    Agrees (fieldsSum index remaining positions values)
      (((List.range' index remaining).map fun i => (fieldAt i positions values).getD 0).sum) := by
  rw [fieldsSum.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases remaining with
  | zero => exact agrees_pure _
  | succ remaining =>
    apply agrees_bind (field_agrees index positions values)
    apply agrees_bind (fieldsSum_agrees (index + 1) remaining positions values)
    simpa only [List.range'_succ, List.map_cons, List.sum_cons] using
      (agrees_pure ((fieldAt index positions values).getD 0 +
        ((List.range' (index + 1) remaining).map fun i => (fieldAt i positions values).getD 0).sum))

private theorem fieldAt_map (index : Nat) (positions : List Nat) (values : List α) (f : α → β) :
    fieldAt index positions (values.map f) = (fieldAt index positions values).map f := by
  cases positions with
  | nil => cases values <;> rfl
  | cons position positions =>
    cases values with
    | nil => rfl
    | cons value values =>
      simp only [List.map_cons, fieldAt]
      split
      · rfl
      · exact fieldAt_map _ _ _ _

private theorem bindersList_sum (patterns : List Release.Pat) :
    Release.Pat.bindersList patterns = (patterns.map Release.Pat.binders).sum := by
  induction patterns with
  | nil => rfl
  | cons p ps ih => simp [Release.Pat.bindersList, ih]

private theorem toCoreList_map (patterns : List Pattern) :
    (Pattern.toCoreList patterns).map Release.Pat.binders =
      patterns.map (fun p => p.toCore.binders) := by
  induction patterns with
  | nil => rfl
  | cons p ps ih => simp [Pattern.toCoreList, ih]

private theorem record_binders (count : Nat) (positions : List Nat) (patterns : List Pattern) :
    Release.Pat.bindersList (recordFields count positions (Pattern.toCoreList patterns) .wild) =
      (((List.range' 0 count).map fun i =>
        (fieldAt i positions (patterns.map fun p => p.toCore.binders)).getD 0).sum) := by
  rw [bindersList_sum]
  simp only [recordFields, List.map_map, Function.comp_def]
  congr 1
  rw [← List.range_eq_range']
  apply List.map_congr_left
  intro index member
  rw [← toCoreList_map, fieldAt_map]
  cases fieldAt index positions (Pattern.toCoreList patterns) <;> rfl

mutual
  /-- 任意の上限・初期状態について、patternBinders の完走した値は既存の局所規則と一致する。 -/
  theorem patternBinders_agrees (pattern : Pattern) :
      Agrees (patternBinders pattern) pattern.binders := by
    rw [patternBinders.eq_def]
    apply agrees_frame
    apply agrees_bind (agrees_unit _)
    cases pattern <;> try exact agrees_pure _
    case con qualifier name patterns =>
      simpa only [Pattern.binders, Pattern.toCore, Release.Pat.binders, bindersList_sum, toCoreList_map] using
        patternSum_agrees patterns
    case list before rest after =>
      apply agrees_bind (patternSum_agrees before)
      apply agrees_bind (patternSum_agrees after)
      simpa only [Pattern.binders, Pattern.toCore, Release.Pat.binders, bindersList_sum,
        toCoreList_map] using
        (agrees_pure ((before.map fun p => p.toCore.binders).sum +
          (rest.map Release.ListRest.binders).getD 0 + (after.map fun p => p.toCore.binders).sum))
    case record name count positions patterns =>
      apply agrees_region
      apply agrees_bind (patternCounts_agrees patterns)
      simpa only [Pattern.binders, Pattern.toCore, Release.Pat.binders, record_binders] using
        fieldsSum_agrees 0 count positions (patterns.map fun p => p.toCore.binders)

  /-- 任意の上限・初期状態について、patternSum の完走した値は既存の局所規則と一致する。 -/
  theorem patternSum_agrees (patterns : List Pattern) :
      Agrees (patternSum patterns) ((patterns.map fun p => p.toCore.binders).sum) := by
    rw [patternSum.eq_def]
    apply agrees_frame
    apply agrees_bind (agrees_unit _)
    cases patterns with
    | nil => exact agrees_pure _
    | cons pattern rest =>
      apply agrees_bind (patternBinders_agrees pattern)
      apply agrees_bind (patternSum_agrees rest)
      exact agrees_pure _

  /-- 任意の上限・初期状態について、patternCounts の完走した値は既存の局所規則と一致する。 -/
  theorem patternCounts_agrees (patterns : List Pattern) :
      Agrees (patternCounts patterns) (patterns.map fun p => p.toCore.binders) := by
    rw [patternCounts.eq_def]
    apply agrees_frame
    apply agrees_bind (agrees_unit _)
    cases patterns with
    | nil => exact agrees_pure _
    | cons pattern rest =>
      apply agrees_bind (patternBinders_agrees pattern)
      apply agrees_bind (patternCounts_agrees rest)
      apply agrees_bind (agrees_unit _)
      exact agrees_pure _
end

/-- 任意の上限・初期状態について、replicateOnto の完走した値は既存の局所規則と一致する。 -/
theorem replicateOnto_agrees (count : Nat) (slot : AbstractSlot) (tail : List AbstractSlot) :
    Agrees (replicateOnto count slot tail) (List.replicate count slot ++ tail) := by
  rw [replicateOnto.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases count with
  | zero => exact agrees_pure _
  | succ count =>
    apply agrees_bind (replicateOnto_agrees count slot tail)
    exact consSlot_agrees _ _

/-- 範囲の未知欄の構成も、環境を一項ずつ増やす既存の走査に含める。 -/
theorem replicateEnv_agrees (count : Nat) (slot : AbstractSlot) (env : AbstractEnv) :
    Agrees (replicateEnv count slot env)
      { env with locals := List.replicate count slot ++ env.locals, ranges := env.ranges.extendUnknown count } := by
  rw [replicateEnv.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases count with
  | zero => exact agrees_pure _
  | succ count =>
      simpa only [List.replicate_succ, List.cons_append, extend, RangeState.extendUnknown] using
        agrees_bind (replicateEnv_agrees count slot env) (push_agrees _ slot)

/-- 任意の上限・初期状態について、values の完走した値は既存の局所規則と一致する。 -/
theorem values_agrees (env : AbstractEnv) (types : List (Option Ty)) :
    Agrees (values env types) (extendValues env types) := by
  rw [values.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases types with
  | nil => exact agrees_pure _
  | cons type rest =>
    apply agrees_bind (push_agrees env (topSlot type))
    simpa [extendValues, extend, List.reverse_cons, List.map_append, List.append_assoc,
      RangeState.extendUnknown, RangeState.extendUnknown_extend] using
      values_agrees (extend env (topSlot type)) rest

/-- 任意の上限・初期状態について、patternSlotsScan の完走した値は既存の局所規則と一致する。 -/
theorem patternSlotsScan_agrees (pattern : Pattern) (type : Ty) (range : Interval) :
    Agrees (patternSlotsScan pattern type range) (matchPatternSlots pattern type range) := by
  apply agrees_bind (agrees_unit _)
  cases pattern <;> try exact consSlot_agrees _ _
  all_goals
    apply agrees_bind (patternBinders_agrees _)
    simpa only [List.append_nil, matchPatternSlots] using
      replicateOnto_agrees _ (.unknown none) []

/-- 任意の上限・初期状態について、selectReverse の完走した値は既存の局所規則と一致する。 -/
theorem selectReverse_agrees (slots : List AbstractSlot) (positions : List Nat)
    (tail : List AbstractSlot) (ranges : RangeState) :
    Agrees (selectReverse slots positions tail ranges)
      ((selectSlots slots positions).map fun selected =>
        (selected.reverse ++ tail, ranges.extendUnknown selected.length)) := by
  rw [selectReverse.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases positions with
  | nil => exact agrees_pure _
  | cons position rest =>
    apply agrees_bind (readSlots_agrees slots position)
    cases h : slots[position]? with
    | none => simpa [selectSlots, h] using
        (agrees_pure (α := Option (List AbstractSlot × RangeState)) none)
    | some slot =>
      apply agrees_bind (consSlot_agrees slot tail)
      have ih := selectReverse_agrees slots rest (slot :: tail) (ranges.extend none)
      cases hr : selectSlots slots rest <;>
        simpa [selectSlots, h, hr, List.reverse_cons, List.append_assoc,
          RangeState.extendUnknown, RangeState.extendUnknown_extend] using ih

/-- 選んだ位置の束縛番号欄も、既存の一回の走査で追加する。 -/
theorem extendSelected_agrees (env : AbstractEnv) (slots : List AbstractSlot) (positions : List Nat) :
    Agrees (extendSelected env slots positions) (extendMatchSlots env slots positions) := by
  apply agrees_bind (selectReverse_agrees slots positions env.locals env.ranges)
  cases h : selectSlots slots positions <;> simp only [extendMatchSlots, h] <;> exact agrees_pure _

/-- 任意の上限・初期状態について、scrutinee の完走した値は既存の局所規則と一致する。 -/
theorem scrutinee_agrees (env : AbstractEnv) (source : Expr) (type : Ty) (range : Interval) :
    Agrees (scrutinee env source type range) (matchScrutineeEnv env source type range) := by
  cases type <;> try exact agrees_pure _
  rename_i base
  cases base <;> try exact agrees_pure _
  apply agrees_bind (indexOf_agrees source)
  cases h : localIndex source with
  | none => simpa only [matchScrutineeEnv, h] using agrees_pure env
  | some index => simpa only [matchScrutineeEnv, h] using update_agrees env index range

private theorem alternative_nonempty_agrees (env : AbstractEnv) (source : Expr) (type : Ty)
    (range : Interval) (alt : Alternative) :
    Agrees (do
      let refined ← scrutinee env source type range
      let slots ← patternSlotsScan alt.pat type range
      extendSelected refined slots alt.slots)
      (extendMatchSlots (matchScrutineeEnv env source type range)
        (matchPatternSlots alt.pat type range) alt.slots) := by
  apply agrees_bind (scrutinee_agrees _ _ _ _)
  apply agrees_bind (patternSlotsScan_agrees _ _ _)
  exact extendSelected_agrees _ _ _

/-- 任意の上限・初期状態について、alternative の完走した値は既存の局所規則と一致する。 -/
theorem alternative_agrees (env : AbstractEnv) (source : Expr) (type : Ty) (normal : Interval)
    (alt : Alternative) :
    Agrees (alternative env source type normal alt) (matchAlternativeEnv env source type normal alt) := by
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases type <;> try exact alternative_nonempty_agrees _ _ _ _ alt
  rename_i base
  cases base <;> try exact alternative_nonempty_agrees _ _ _ _ alt
  by_cases h : matchRange (.base .integer) normal alt.pat = .bottom
  · simpa [matchAlternativeEnv, h] using (agrees_pure (α := Option AbstractEnv) none)
  · simpa only [matchAlternativeEnv, h, ite_false] using
      alternative_nonempty_agrees env source (.base .integer)
        (matchRange (.base .integer) normal alt.pat) alt

/-- 任意の上限・初期状態について、alternatives の完走した値は既存の局所規則と一致する。 -/
theorem alternatives_agrees (template env : AbstractEnv) (source : Expr) (type : Ty)
    (normal : Interval) (alts : List Alternative) :
    Agrees (alternatives template env source type normal alts)
      (matchAlternativesEnv template env source type normal alts) := by
  rw [alternatives.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases alts with
  | nil => exact agrees_pure _
  | cons alt rest =>
    apply agrees_bind (alternative_agrees env source type normal alt)
    apply agrees_bind (alternatives_agrees template env source type normal rest)
    exact joinEnvs?_agrees _ _ _

/-- 任意の上限・初期状態について、armTemplate の完走した値は既存の局所規則と一致する。 -/
theorem armTemplate_agrees (env : AbstractEnv) (type : Ty) (count : Nat) :
    Agrees (armTemplate env type count) (matchArmTemplate env type count) := by
  exact replicateEnv_agrees count _ env

/-- 任意の上限・初期状態について、arm の完走した値は既存の局所規則と一致する。 -/
theorem arm_agrees (env : AbstractEnv) (source : Expr) (type : Ty) (normal : Interval)
    (alts : List Alternative) :
    Agrees (arm env source type normal alts) (matchArmEnv env source type normal alts) := by
  have count : Agrees (armCount alts) (matchArmBinders alts) := by
    cases alts with
    | nil => exact agrees_pure _
    | cons alt rest => exact countList_agrees alt.slots
  apply agrees_bind count
  apply agrees_bind (armTemplate_agrees _ _ _)
  exact alternatives_agrees _ _ _ _ _ _

/-- bind と shadow の局所位置を、既存の範囲保存の規則で追加する。 -/
def bindEnv (_kind : BindKind) (env : AbstractEnv) (type : Ty) (range : Interval) : Scan AbstractEnv :=
  push env (match type with
    | .base .integer => .integer range
    | _ => topSlot (some type))

/-- パターンの内部の型を推測せず、既存の通常の束縛追加に合わせる。 -/
def patternEnv (env : AbstractEnv) (pattern : Pattern) (type : Ty) : Scan AbstractEnv := do
  tick .classification
  match pattern with
  | .var => push env (topSlot (some type))
  | _ => do
      let count ← patternBinders pattern
      replicateEnv count (.unknown none) env

/-- 正常値のない条件の構文は追加走査せず、成功した到達不能を返す。 -/
def branch (env : AbstractEnv) (source : Expr) (normal : NormalRange (.base .boolean))
    (truth : Bool) : Scan (Option AbstractEnv) :=
  if (if truth then normal.2 else normal.1) then condition env source truth else pure none

/-- 任意の上限・初期状態について、bindEnv の完走した値は既存の局所規則と一致する。 -/
theorem bindEnv_agrees (kind : BindKind) (env : AbstractEnv) (type : Ty) (range : Interval) :
    Agrees (bindEnv kind env type range) (bindRange kind env type range) := push_agrees _ _

/-- 任意の上限・初期状態について、patternEnv の完走した値は既存の局所規則と一致する。 -/
theorem patternEnv_agrees (env : AbstractEnv) (pattern : Pattern) (type : Ty) :
    Agrees (patternEnv env pattern type) (extendPattern env pattern type) := by
  apply agrees_bind (agrees_unit _)
  cases pattern <;> try exact push_agrees _ _
  all_goals
    apply agrees_bind (patternBinders_agrees _)
    exact replicateEnv_agrees _ _ _

/-- 任意の上限・初期状態について、branch の完走した値は既存の局所規則と一致する。 -/
theorem branch_agrees (env : AbstractEnv) (source : Expr)
    (normal : NormalRange (.base .boolean)) (truth : Bool) :
    Agrees (branch env source normal truth) (branchEnv env source normal truth) := by
  unfold branch branchEnv
  cases truth <;> simp only [Bool.false_eq_true, ite_false, ite_true]
  all_goals split
  all_goals first | exact condition_agrees _ _ _ | exact agrees_pure _

/-- 幅付きのパターン変数だけに正常区間を保存し、位置の確保を計上する。 -/
def patternSlotsKindScan (pattern : Pattern) (kind : IntKind) (range : Interval kind) :
    Scan (List AbstractSlot) := do
  tick .classification
  match pattern with
  | .var => consSlot (integerKindSlot kind range) []
  | _ => do
      let count ← patternBinders pattern
      replicateOnto count (.unknown none) []

/-- 同じ種類の直接参照だけを絞り、元の位置までの読出しと再構成を計上する。 -/
def scrutineeKind (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (range : Interval kind) : Scan AbstractEnv := do
  let index ← indexOf source
  match index with
  | none => pure env
  | some index => updateKind env kind index range

/-- 種類付きの空の交差は束縛追加前に停止し、到達不能を返す。 -/
def alternativeKind (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alt : Alternative) : Scan (Option AbstractEnv) := frame fun _ => do
  tick .classification
  let range := meet normal (integerKindPatternRange kind alt.pat)
  if range = .bottom then pure none else do
    let refined ← scrutineeKind env source kind range
    let slots ← patternSlotsKindScan alt.pat kind range
    extendSelected refined slots alt.slots

/-- 幅付きの選択肢を先頭から走査し、完走した二結果を合流する。 -/
def alternativesKind (template env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alts : List Alternative) : Scan (Option AbstractEnv) := frame fun _ => do
  tick .classification
  match alts with
  | [] => pure none
  | alt :: rest =>
      let first ← alternativeKind env source kind normal alt
      let tail ← alternativesKind template env source kind normal rest
      joinEnvs? template first tail

/-- 腕の基準位置も、同じ整数幅の Top を一項ずつ確保する。 -/
def armTemplateKind (env : AbstractEnv) (kind : IntKind) (count : Nat) : Scan AbstractEnv := do
  replicateEnv count (topKindSlot kind) env

/-- 共通位置数・基準環境・選択肢を同じ予算状態で順に走査する。 -/
def armKindCore (env : AbstractEnv) (source : Expr) (kind : IntKind) (normal : Interval kind)
    (alts : List Alternative) : Scan (Option AbstractEnv) := do
  let count ← armCount alts
  let template ← armTemplateKind env kind count
  alternativesKind template env source kind normal alts

/-- 種類付きのパターン位置も、完走時には予算なしの入口と一致する。 -/
theorem patternSlotsKindScan_agrees (pattern : Pattern) (kind : IntKind) (range : Interval kind) :
    Agrees (patternSlotsKindScan pattern kind range) (matchKindPatternSlots pattern kind range) := by
  apply agrees_bind (agrees_unit _)
  cases pattern <;> try exact consSlot_agrees _ _
  all_goals
    apply agrees_bind (patternBinders_agrees _)
    simpa only [List.append_nil, matchKindPatternSlots] using
      replicateOnto_agrees _ (.unknown none) []

/-- 種類付きの照合値の更新は、完走時には同じ一位置の更新になる。 -/
theorem scrutineeKind_agrees (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (range : Interval kind) :
    Agrees (scrutineeKind env source kind range) (matchKindScrutineeEnv env source kind range) := by
  apply agrees_bind (indexOf_agrees source)
  cases h : localIndex source with
  | none => simpa only [matchKindScrutineeEnv, h] using agrees_pure env
  | some index => simpa only [matchKindScrutineeEnv, h] using updateKind_agrees env kind index range

/-- 種類付きの選択肢の完走結果は、空の交差と slots の不一致も含めて一致する。 -/
theorem alternativeKind_agrees (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alt : Alternative) :
    Agrees (alternativeKind env source kind normal alt)
      (matchKindAlternativeEnv env source kind normal alt) := by
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  unfold matchKindAlternativeEnv
  dsimp only
  split
  · exact agrees_pure _
  · apply agrees_bind (scrutineeKind_agrees _ _ _ _)
    apply agrees_bind (patternSlotsKindScan_agrees _ _ _)
    exact extendSelected_agrees _ _ _

/-- 種類付きの選択肢全体を完走すると、同じ基準環境での凸包合流になる。 -/
theorem alternativesKind_agrees (template env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alts : List Alternative) :
    Agrees (alternativesKind template env source kind normal alts)
      (matchKindAlternativesEnv template env source kind normal alts) := by
  rw [alternativesKind.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases alts with
  | nil => exact agrees_pure _
  | cons alt rest =>
    apply agrees_bind (alternativeKind_agrees env source kind normal alt)
    apply agrees_bind (alternativesKind_agrees template env source kind normal rest)
    exact joinEnvs?_agrees _ _ _

/-- 種類付きの基準環境の完走結果は、位置数と種類を保つ。 -/
theorem armTemplateKind_agrees (env : AbstractEnv) (kind : IntKind) (count : Nat) :
    Agrees (armTemplateKind env kind count) (matchKindArmTemplate env kind count) := by
  exact replicateEnv_agrees count _ env

/-- 幅付きの腕入口全体も、任意の予算で完走した結果は元の規則と一致する。 -/
theorem armKindCore_agrees (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alts : List Alternative) :
    Agrees (armKindCore env source kind normal alts) (matchKindArmEnvCore env source kind normal alts) := by
  have count : Agrees (armCount alts) (matchArmBinders alts) := by
    cases alts with
    | nil => exact agrees_pure _
    | cons alt rest => exact countList_agrees alt.slots
  apply agrees_bind count
  apply agrees_bind (armTemplateKind_agrees _ _ _)
  exact alternativesKind_agrees _ _ _ _ _ _

/-- Integer64 の既存の計上を保ち、六幅だけを種類付きの走査へ渡す。 -/
def armKind (env : AbstractEnv) (source : Expr) (kind : IntKind) (normal : Interval kind)
    (alts : List Alternative) : Scan (Option AbstractEnv) :=
  match kind with
  | .integer64 => arm env source (.base .integer) normal alts
  | kind => armKindCore env source kind normal alts

/-- Integer64 の既存の腕の計上は種類付き入口でも同じである。 -/
@[simp] theorem armKind_integer64 (env : AbstractEnv) (source : Expr)
    (normal : Interval .integer64) (alts : List Alternative) :
    armKind env source .integer64 normal alts = arm env source (.base .integer) normal alts := rfl

/-- 種類を選ぶ入口は、任意の予算の完走結果を同じ腕入口へ対応させる。 -/
theorem armKind_agrees (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alts : List Alternative) :
    Agrees (armKind env source kind normal alts) (matchKindArmEnv env source kind normal alts) := by
  cases kind with
  | integer64 => exact arm_agrees _ _ _ _ _
  | integer8 | integer16 | integer32 | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 =>
      exact armKindCore_agrees _ _ _ _ _

end Benitoite.Interval.BudgetScan
