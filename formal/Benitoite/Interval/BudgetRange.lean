import Benitoite.Interval.BudgetRangeBorrow
import Benitoite.Interval.BudgetDomainScan
import Benitoite.Interval.Sound
import Benitoite.Interval.RangeBorrowed

/-!
# Range の補助記録の予算付きの認定と保存

固定個数の引数は元の構文を借用し、表と局所位置は一項ずつ読む。
成功値の由来は保存の直前に auxiliary 一項を確保する。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface Benitoite.Release Budget

/-- 参照した位置までだけを読む。読み取り専用の列は複写しない。 -/
def rangeEntry (entries : List α) (index : Nat) : Scan (Option α) := frame fun _ => do
  tick .environmentRead
  match entries, index with
  | [], _ => pure none
  | entry :: _, 0 => pure (some entry)
  | _ :: rest, index + 1 => rangeEntry rest index

/-- 解決済み宣言の一致までを走査し、後ろの表を読まない。 -/
def rangeStandard (entries : List StandardBinding) (declaration : FunName) :
    Scan (Option StandardBinding) := frame fun _ => do
  tick .environmentRead
  match entries with
  | [] => pure none
  | entry :: rest =>
    if entry.declaration == declaration then pure (some entry)
    else rangeStandard rest declaration

/-- 出現表の一参照と、標準表の実際の探索を計上する。 -/
def rangeStandardAt (env : AbstractEnv) (key : OperationKey) : Scan (Option StandardBinding) := do
  tick .environmentRead
  match env.apiAt key with
  | none => pure none
  | some declaration => rangeStandard env.standards declaration

/-- 固定端点の認定で読む括弧と整数constだけを既存の定数走査で調べる。 -/
def rangeFixed (source : Expr) : Scan (Option Integer64Value) := do
  let found ← constant source
  pure (found.bind fun value =>
    if bounded : min64 ≤ value ∧ value ≤ max64 then some ⟨value, bounded⟩ else none)

/-- 型列・ラベル・置換・引数容器を、その順に一要素ずつ確認する。 -/
def domainCallShape (types : List Ty) (labels : List (Option String))
    (positions : List Nat) (sources : Exprs) : Scan Bool := do
  let count ← countList types
  let labelsValid ← rangeLength labels count
  if !labelsValid then pure false else do
    let positionsValid ← domainPermutation positions count
    if !positionsValid then pure false else do
      let actual ← domainExprsLength sources
      let expected ← countList positions
      pure (decide (actual = expected))

/-- 直接呼び出しの標準規則と、ソース順とは別の契約位置を認定する。 -/
def rangeCall (env : AbstractEnv) (key : OperationKey) (source : Expr) :
    Scan (Option StandardBinding) := frame fun _ => do
  tick .classification
  match source with
  | .call callee labels positions arguments =>
    match standardCallHead callee with
    | none => pure none
    | some declaration =>
      let binding ← rangeStandardAt env key
      match binding with
      | none => pure none
      | some binding =>
        if declaration ≠ binding.declaration then pure none else
          match binding.rule with
          | .rangeCheck _ =>
            if (match callee with | .funName _ [] [] => true | _ => false : Bool) then do
              let found ← rangeBorrowCheck labels positions arguments
              pure (if found.isSome then some binding else none)
            else pure none
          | .rangeValue _ =>
            if (match callee with | .funName _ [] [] => true | _ => false : Bool) then do
              let found ← rangeBorrowValue labels positions arguments
              pure (if found.isSome then some binding else none)
            else pure none
          | .fixedDomain argument _ _ _ => do
            let target ← domainEntry binding.argumentTypes argument
            if (match target with | some (.base .integer) => true | _ => false : Bool) then do
              let valid ← domainCallShape binding.argumentTypes labels positions arguments
              pure (if valid then some binding else none)
            else pure none
  | _ => pure none

/-- 固定端点の構文だけを読み、一時的な引数Listを作らない。 -/
def rangeOrigin (env : AbstractEnv) (input : EvalInput) : Scan (Option RangeOrigin) := frame fun _ => do
  tick .classification
  match input.source with
  | .call (.funName declaration [] []) labels positions arguments =>
    let arguments ← rangeBorrowCheck labels positions arguments
    match arguments with
    | none => pure none
    | some (lower, upper, _) =>
      let binding ← rangeStandardAt env input.key
      match binding with
      | none => pure none
      | some binding =>
        if declaration ≠ binding.declaration then pure none else
          match binding.rule with
          | .rangeCheck names => do
            let minimum ← rangeFixed lower
            match minimum with
            | none => pure none
            | some minimum =>
              let maximum ← rangeFixed upper
              pure (maximum.map fun maximum => ⟨names, input.key, minimum, maximum⟩)
          | _ => pure none
  | _ => pure none

/-- 直接検査または一保存のResultだけを読み、他の子には進まない。 -/
def rangeResultSource (env : AbstractEnv) (input : EvalInput) : Scan (Option RangeOrigin) :=
  match input.source with
  | .local index => do
    let fact ← rangeEntry env.ranges.facts index
    pure (match fact with | some (some (.result origin)) => some origin | _ => none)
  | _ => rangeOrigin env input

/-- Result所有元の最初の一致までを読み、型の内部を推測しない。 -/
def rangeNames (entries : List StandardBinding) (type : Ty) : Scan (Option RangeNames) :=
  frame fun _ => do
    tick .environmentRead
    match entries with
    | [] => pure none
    | entry :: rest =>
      let found := match entry.rule, type with
        | .rangeCheck names, .data result [.data owner [], .data error []] =>
          if result = names.result ∧ owner = names.owner ∧ error = names.error ∧ names.ok ≠ names.err
          then some names else none
        | _, _ => none
      match found with
      | some names => pure (some names)
      | none => rangeNames rest type

/-- パターンの一引数も元の列を借用し、子の分類を別に計上する。 -/
def rangePattern (names : RangeNames) (pattern : Pattern) : Scan Bool := frame fun _ => do
  tick .classification
  match pattern with
  | .wild | .var => pure true
  | .con qualifier tag patterns =>
    let child ← rangeOne patterns
    match child with
    | none => pure false
    | some child => do
      tick .classification
      pure (match child with
        | .wild | .var => (qualifier.isNone || qualifier == some names.result) &&
            (tag == names.ok || tag == names.err)
        | _ => false)
  | _ => pure false

/-- Okの成功値を束縛できる一変数だけを認める。 -/
def rangeOk (names : RangeNames) (pattern : Pattern) : Scan Bool := frame fun _ => do
  tick .classification
  match pattern with
  | .con qualifier tag patterns =>
    let child ← rangeOne patterns
    match child with
    | none => pure false
    | some child => do
      tick .classification
      pure (match child with
        | .var => (qualifier.isNone || qualifier == some names.result) && tag == names.ok
        | _ => false)
  | _ => pure false

/-- パターンの根と固定一引数だけを分類し、slots・guard・bodyは読まない。 -/
def rangePatterns (names : RangeNames) (alts : List Alternative) : Scan Bool := frame fun _ => do
  tick .classification
  match alts with
  | [] => pure true
  | alt :: rest =>
    let found ← rangePattern names alt.pat
    if found then rangePatterns names rest else pure false

/-- 全腕のパターンが対応する場合だけResultの具体規則へ接続する。 -/
def rangeArms (names : RangeNames) (arms : Arms) : Scan Bool := frame fun _ => do
  tick .classification
  match arms with
  | .nil => pure true
  | .cons alts _ _ rest =>
    let found ← rangePatterns names alts
    if found then rangeArms names rest else pure false

/-- 直接または一保存のResultの認定で、必要な表とパターンだけを読む。 -/
def rangeMatch (env : AbstractEnv) (input : EvalInput) (arms : Arms) : Scan (Option RangeOrigin) := do
  let origin ← rangeResultSource env input
  match origin with
  | none => pure none
  | some origin =>
    let names ← rangeNames env.standards
      (.data origin.names.result [.data origin.names.owner [], .data origin.names.error []])
    match names with
    | none => pure none
    | some names =>
      if names ≠ origin.names then pure none else do
        let compatible ← rangeArms names arms
        pure (if compatible then some origin else none)

/-- 読み出した同じ束縛番号に付いたcheckedの記録だけを認める。 -/
def rangeChecked (state : RangeState) (index : Nat) : Scan (Option RangeOrigin) := do
  let id ← rangeEntry state.scope.positions index
  match id with
  | none => pure none
  | some id =>
    let fact ← rangeEntry state.facts index
    pure (match fact with
      | some (some (.checked origin successId)) => if successId = id then some origin else none
      | _ => none)

/-- 直接のvalue(local)の標準規則だけを読む。 -/
def rangeValueSource (env : AbstractEnv) (input : EvalInput) : Scan (Option (RangeRecord × Nat)) :=
  frame fun _ => do
    tick .classification
    match input.type, input.source with
    | .base .integer, .call (.funName declaration [] []) labels positions arguments =>
      let source ← rangeBorrowValue labels positions arguments
      match source with
      | none => pure none
      | some source => do
        tick .classification
        match source with
        | .local index =>
          let binding ← rangeStandardAt env input.key
          match binding with
          | none => pure none
          | some binding =>
            if declaration ≠ binding.declaration then pure none else
              pure (match binding.rule with | .rangeValue owner => some (owner, index) | _ => none)
        | _ => pure none
    | _, _ => pure none

/-- 別の所有元の射影には端点を使わず、同じcheckedの記録だけを射影する。 -/
def rangeValue (env : AbstractEnv) (input : EvalInput) : Scan BaseApprox := do
  let source ← rangeValueSource env input
  match source with
  | none => pure baseUnknown
  | some (owner, index) =>
    let origin ← rangeChecked env.ranges index
    pure (match origin with
      | some origin => if origin.names.record = owner then
          baseInteger (normalize origin.minimum.toInt origin.maximum.toInt) true else baseUnknown
      | none => baseUnknown)

/-- 補助記録の追加前に一項を確保する。Noneは環境行の固定長欄だけである。 -/
def reserveRangeFact (fact : Option RangeLocalFact) : Scan Unit :=
  match fact with
  | none => pure ()
  | some _ => allocate .auxiliary

/-- 直接検査のResultだけを一度保存し、originを再計算しない。 -/
def rangeBind (kind : BindKind) (env : AbstractEnv) (type : Ty)
    (value : BaseApprox) (input : EvalInput) : Scan AbstractEnv := do
  let origin ← rangeOrigin env input
  let locals ← match IntKind.ofType type with
    | some width => push env (integerKindSlot width (value.rangeKind width))
    | none => bindEnv kind env type value.integer
  let fact := origin.map RangeLocalFact.result
  reserveRangeFact fact
  pure { locals with ranges := env.ranges.extend fact }

/-- 単独のOk(var)だけで同じ成功値の新位置を認める。 -/
def readRangeArm (env : AbstractEnv) (input : EvalInput) (alts : List Alternative) :
    Scan (Option RangeState) := do
  let alt ← rangeOne alts
  match alt with
  | none => pure none
  | some alt =>
    let position ← rangeOne alt.slots
    match position with
    | some 0 =>
      let origin ← rangeResultSource env input
      match origin with
      | none => pure none
      | some origin =>
        let matched ← rangeOk origin.names alt.pat
        pure (if matched then some (rangeBindOk env.ranges origin) else none)
    | _ => pure none

/-- 通常位置の固定長欄はenvironment一項、既知の由来の本体はauxiliary一項とする。 -/
def rangeArm (env : AbstractEnv) (input : EvalInput) (alts : List Alternative) : Scan AbstractEnv := do
  let count ← countList (alts.head?.map (·.slots) |>.getD [])
  let initial ← replicateEnv count (.unknown none) env
  let known ← readRangeArm env input alts
  match known with
  | some ranges => do
    allocate .auxiliary
    pure { initial with ranges := ranges }
  | none => pure initial

theorem rangeEntry_agrees (entries : List α) (index : Nat) :
    Agrees (rangeEntry entries index) entries[index]? := by
  rw [rangeEntry.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons entry rest =>
    cases index with
    | zero => exact agrees_pure _
    | succ index => exact rangeEntry_agrees rest index

theorem rangeStandard_agrees (entries : List StandardBinding) (declaration : FunName) :
    Agrees (rangeStandard entries declaration)
      (entries.find? fun entry => entry.declaration == declaration) := by
  rw [rangeStandard.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons entry rest =>
    cases h : entry.declaration == declaration <;>
      simp only [h, List.find?, Bool.false_eq_true, ↓reduceIte]
    · exact rangeStandard_agrees rest declaration
    · exact agrees_pure _

theorem rangeStandardAt_agrees (env : AbstractEnv) (key : OperationKey) :
    Agrees (rangeStandardAt env key) (env.standardAt key) := by
  unfold rangeStandardAt
  apply agrees_bind (agrees_unit _)
  cases h : env.apiAt key with
  | none => simpa only [AbstractEnv.standardAt, h, bind, Option.bind] using agrees_pure (none : Option StandardBinding)
  | some declaration => simpa only [AbstractEnv.standardAt, h, bind, Option.bind] using rangeStandard_agrees env.standards declaration

theorem rangeFixed_agrees (source : Expr) : Agrees (rangeFixed source) (rangeFixedInteger source) := by
  unfold rangeFixed rangeFixedInteger
  apply agrees_bind (constant_agrees source)
  exact agrees_pure _

theorem domainCallShape_agrees (types labels positions sources) :
    Agrees (domainCallShape types labels positions sources)
      (decide (labels.length = types.length ∧ positions.Perm (List.range types.length) ∧
        (exprsChildren sources).length = positions.length)) := by
  unfold domainCallShape
  apply agrees_bind (countList_agrees types)
  apply agrees_bind (rangeLength_agrees labels types.length)
  by_cases hl : labels.length = types.length
  · simp only [hl, decide_true, Bool.not_true, Bool.false_eq_true, ↓reduceIte, true_and]
    apply agrees_bind (domainPermutation_agrees positions types.length)
    by_cases hp : positions.Perm (List.range types.length)
    · simp only [hp, decide_true, Bool.not_true, Bool.false_eq_true, ↓reduceIte, true_and]
      apply agrees_bind (domainExprsLength_agrees sources)
      apply agrees_bind (countList_agrees positions)
      exact agrees_pure _
    · simpa [hp] using agrees_pure false
  · simpa [hl] using agrees_pure false

theorem rangeCall_agrees (env key source) : Agrees (rangeCall env key source) (rangeCallAt env key source) := by
  unfold rangeCall rangeCallAt rangeCallBinding
  apply agrees_frame; apply agrees_bind (agrees_unit _)
  cases source <;> try exact agrees_pure _
  case call callee labels positions arguments =>
    cases head : standardCallHead callee with
    | none => simp [head]; exact agrees_pure _
    | some declaration =>
      simp only [head, bind, Option.bind]
      apply agrees_bind (rangeStandardAt_agrees env key)
      have tables : (rangeTables env).standardAt key = env.standardAt key := rfl
      rw [tables]
      cases found : env.standardAt key with
      | none => simp only [found, Option.bind_none]; exact agrees_pure _
      | some binding =>
        simp only [found, Option.bind_some]
        by_cases different : declaration ≠ binding.declaration
        · simpa [different] using agrees_pure (none : Option _)
        · simp only [different, ↓reduceIte]
          cases rule : binding.rule <;> simp only [rule]
          case rangeCheck names =>
            split
            · apply agrees_bind (rangeBorrowCheck_agrees labels positions arguments)
              simp only [borrowRangeArgs_isSome, true_and]
              exact agrees_pure _
            · simp_all only [false_and, ↓reduceIte]; exact agrees_pure _
          case rangeValue owner =>
            split
            · apply agrees_bind (rangeBorrowValue_agrees labels positions arguments)
              simp_all only [borrowValueArg_isSome, true_and]
              exact agrees_pure _
            · simp_all only [false_and, ↓reduceIte]; exact agrees_pure _
          case fixedDomain argument lo hi result =>
            apply agrees_bind (domainEntry_agrees binding.argumentTypes argument)
            split
            · apply agrees_bind (domainCallShape_agrees binding.argumentTypes labels positions arguments)
              simp_all only [true_and, decide_eq_true_eq]
              exact agrees_pure _
            · simp_all only [false_and, ↓reduceIte]; exact agrees_pure _
theorem rangeOrigin_agrees (env input) : Agrees (rangeOrigin env input) (rangeCallOrigin env input) := by
  rw [← borrow_range_origin_eq]
  rcases input with ⟨source, type, key⟩
  unfold rangeOrigin borrowRangeOrigin
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> try exact agrees_pure _
  case call callee labels positions arguments =>
    cases callee <;> try exact agrees_pure _
    case funName declaration types effects =>
      cases types <;> try exact agrees_pure _
      cases effects <;> try exact agrees_pure _
      apply agrees_bind (rangeBorrowCheck_agrees labels positions arguments)
      cases found : borrowRangeArgs labels positions arguments with
      | none => simp only [found, bind, Option.bind]; exact agrees_pure _
      | some values =>
        rcases values with ⟨lower, upper, value⟩
        simp only [found, bind, Option.bind]
        apply agrees_bind (rangeStandardAt_agrees env key)
        cases known : env.standardAt key with
        | none => simp only [known, bind, Option.bind]; exact agrees_pure _
        | some binding =>
          simp only [known, bind, Option.bind]
          by_cases different : declaration ≠ binding.declaration
          · simpa [different] using agrees_pure (none : Option _)
          · simp only [different, ↓reduceIte]
            cases rule : binding.rule <;> simp only [rule] <;> try exact agrees_pure _
            case rangeCheck names =>
              apply agrees_bind (rangeFixed_agrees lower)
              cases hMinimum : rangeFixedInteger lower with
              | none => simp only [hMinimum, bind, Option.bind]; exact agrees_pure _
              | some minimum =>
                simp only [hMinimum, bind, Option.bind]
                apply agrees_bind (rangeFixed_agrees upper)
                cases hMaximum : rangeFixedInteger upper <;> simp only [hMaximum] <;> exact agrees_pure _

theorem rangeResultSource_agrees (env input) :
    Agrees (rangeResultSource env input) (rangeResultOrigin env env.ranges input) := by
  rcases input with ⟨source, type, key⟩
  unfold rangeResultSource rangeResultOrigin
  cases source <;> try exact rangeOrigin_agrees env _
  case «local» index =>
    apply agrees_bind (rangeEntry_agrees _ _)
    exact agrees_pure _

private def rangeNameResult (entry : StandardBinding) (type : Ty) : Option RangeNames :=
  match entry.rule, type with
  | .rangeCheck names, .data result [.data owner [], .data error []] =>
    if result = names.result ∧ owner = names.owner ∧ error = names.error ∧ names.ok ≠ names.err
    then some names else none
  | _, _ => none

theorem rangeNames_agrees (entries : List StandardBinding) (type : Ty) :
    Agrees (rangeNames entries type) (entries.findSome? fun entry => rangeNameResult entry type) := by
  rw [rangeNames.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases entries with
  | nil => exact agrees_pure _
  | cons entry rest =>
    change Agrees
      (match rangeNameResult entry type with
      | some names => pure (some names)
      | none => rangeNames rest type)
      ((entry :: rest).findSome? fun binding => rangeNameResult binding type)
    cases found : rangeNameResult entry type with
    | none => simpa [List.findSome?, found] using rangeNames_agrees rest type
    | some names => simpa [List.findSome?, found] using agrees_pure (some names)

theorem rangePattern_agrees (names : RangeNames) (pattern : Pattern) :
    Agrees (rangePattern names pattern) (rangeResultPattern names pattern) := by
  rw [rangePattern.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases pattern <;> try exact agrees_pure _
  case con qualifier tag patterns =>
    apply agrees_bind (rangeOne_agrees patterns)
    simp only [rangeOneValue]
    cases patterns with
    | nil => exact agrees_pure _
    | cons child rest =>
      cases rest with
      | cons => cases child <;> exact agrees_pure _
      | nil =>
        apply agrees_bind (agrees_unit _)
        cases child <;> exact agrees_pure _

theorem rangeOk_agrees (names : RangeNames) (pattern : Pattern) :
    Agrees (rangeOk names pattern) (rangeOkPattern names pattern) := by
  rw [rangeOk.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases pattern <;> try exact agrees_pure _
  case con qualifier tag patterns =>
    apply agrees_bind (rangeOne_agrees patterns)
    simp only [rangeOneValue]
    cases patterns with
    | nil => exact agrees_pure _
    | cons child rest =>
      cases rest with
      | cons => cases child <;> exact agrees_pure _
      | nil =>
        apply agrees_bind (agrees_unit _)
        cases child <;> exact agrees_pure _

theorem rangePatterns_agrees (names : RangeNames) (alts : List Alternative) :
    Agrees (rangePatterns names alts) (alts.all fun alt => rangeResultPattern names alt.pat) := by
  rw [rangePatterns.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases alts with
  | nil => exact agrees_pure _
  | cons alt rest =>
    apply agrees_bind (rangePattern_agrees names alt.pat)
    cases h : rangeResultPattern names alt.pat <;>
      simp only [h, List.all_cons, Bool.false_eq_true, ↓reduceIte, Bool.false_and, Bool.true_and]
    · exact agrees_pure _
    · exact rangePatterns_agrees names rest

theorem rangeArms_agrees (names : RangeNames) (arms : Arms) :
    Agrees (rangeArms names arms) (rangeResultArms names arms) := by
  rw [rangeArms.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases arms with
  | nil => exact agrees_pure _
  | cons alts guard body rest =>
    apply agrees_bind (rangePatterns_agrees names alts)
    cases h : alts.all (fun alt => rangeResultPattern names alt.pat) <;>
      simp only [h, rangeResultArms, Bool.false_eq_true, ↓reduceIte, Bool.false_and, Bool.true_and]
    · exact agrees_pure _
    · exact rangeArms_agrees names rest

theorem rangeMatch_agrees (env input arms) : Agrees (rangeMatch env input arms) (rangeMatchAt env input arms) := by
  unfold rangeMatch rangeMatchAt
  apply agrees_bind (rangeResultSource_agrees env input)
  cases hOrigin : rangeResultOrigin env env.ranges input with
  | none => simp only [hOrigin, bind, Option.bind]; exact agrees_pure _
  | some origin =>
    simp only [hOrigin, bind, Option.bind]
    apply agrees_bind (rangeNames_agrees _ _)
    change Agrees _ (do
      let names ← env.standards.findSome? fun entry => rangeNameResult entry
        (.data origin.names.result [.data origin.names.owner [], .data origin.names.error []])
      if names = origin.names ∧ rangeResultArms names arms = true then some origin else none)
    cases found : env.standards.findSome? (fun entry => rangeNameResult entry
        (.data origin.names.result [.data origin.names.owner [], .data origin.names.error []])) with
    | none => simpa only [bind, Option.bind] using agrees_pure (none : Option RangeOrigin)
    | some names =>
      simp only [bind, Option.bind]
      by_cases same : names = origin.names
      · simp only [same, ne_eq, not_true_eq_false, ↓reduceIte, true_and]
        apply agrees_bind (rangeArms_agrees _ _)
        exact agrees_pure _
      · simp only [same, ne_eq, not_false_eq_true, ↓reduceIte, false_and]
        exact agrees_pure _

theorem rangeChecked_agrees (state : RangeState) (index : Nat) :
    Agrees (rangeChecked state index) (rangeCheckedOrigin state index) := by
  unfold rangeChecked rangeCheckedOrigin BindingScope.idAt
  apply agrees_bind (rangeEntry_agrees state.scope.positions index)
  cases found : state.scope.positions[index]? with
  | none => exact agrees_pure _
  | some id =>
    apply agrees_bind (rangeEntry_agrees state.facts index)
    exact agrees_pure _

theorem rangeValueSource_agrees (env input) :
    Agrees (rangeValueSource env input) (rangeValueCall env input) := by
  rw [← borrow_range_value_call_eq]
  rcases input with ⟨source, type, key⟩
  unfold rangeValueSource borrowRangeValueCall
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases type <;> try exact agrees_pure _
  case base base =>
    cases base <;> try exact agrees_pure _
    case integer =>
      cases source <;> try exact agrees_pure _
      case call callee labels positions arguments =>
        cases callee <;> try exact agrees_pure _
        case funName declaration types effects =>
          cases types <;> try exact agrees_pure _
          cases effects <;> try exact agrees_pure _
          apply agrees_bind (rangeBorrowValue_agrees labels positions arguments)
          cases found : borrowValueArg labels positions arguments with
          | none => simp only [found, bind, Option.bind]; exact agrees_pure _
          | some argument =>
            simp only [found, bind, Option.bind]
            apply agrees_bind (agrees_unit _)
            cases argument <;> try exact agrees_pure _
            case «local» index =>
              apply agrees_bind (rangeStandardAt_agrees env key)
              cases known : env.standardAt key with
              | none => simp only [known, bind, Option.bind]; exact agrees_pure _
              | some binding =>
                simp only [known, bind, Option.bind]
                split <;> exact agrees_pure _

theorem rangeValue_agrees (env input) : Agrees (rangeValue env input) (baseRangeCall env input) := by
  unfold rangeValue baseRangeCall rangeValueOrigin
  apply agrees_bind (rangeValueSource_agrees env input)
  cases found : rangeValueCall env input with
  | none => simp only [found, bind, Option.bind]; exact agrees_pure _
  | some source =>
    rcases source with ⟨owner, index⟩
    simp only [found, bind, Option.bind]
    apply agrees_bind (rangeChecked_agrees env.ranges index)
    cases hKnown : rangeCheckedOrigin env.ranges index with
    | none => simp only [hKnown, bind, Option.bind]; exact agrees_pure _
    | some origin =>
      simp only [hKnown, bind, Option.bind]
      by_cases same : origin.names.record = owner <;>
        simp only [same, ↓reduceIte] <;> exact agrees_pure _

theorem rangeBind_agrees (kind env type value input) :
    Agrees (rangeBind kind env type value input) (baseBindSource kind env type value input) := by
  unfold rangeBind
  apply agrees_bind (rangeOrigin_agrees env input)
  cases found : IntKind.ofType type with
  | none =>
    simp only [found]
    apply agrees_bind (bindEnv_agrees kind env type value.integer)
    apply agrees_bind (agrees_unit _)
    simpa only [baseBindSource, baseBind, found, rangeSaveResult] using
      agrees_pure ({ bindRange kind env type value.integer with
        ranges := env.ranges.extend ((rangeCallOrigin env input).map RangeLocalFact.result) } : AbstractEnv)
  | some width =>
    simp only [found]
    apply agrees_bind (push_agrees env (integerKindSlot width (value.rangeKind width)))
    apply agrees_bind (agrees_unit _)
    simpa only [baseBindSource, baseBind, found, bindRangeKind, rangeSaveResult] using
      agrees_pure ({ extend env (integerKindSlot width (value.rangeKind width)) with
        ranges := env.ranges.extend ((rangeCallOrigin env input).map RangeLocalFact.result) } : AbstractEnv)

theorem readRangeArm_agrees (env input alts) :
    Agrees (readRangeArm env input alts)
      (match alts with
      | [⟨pattern, [0]⟩] => rangeMatchOk env env.ranges input pattern
      | _ => none) := by
  unfold readRangeArm
  apply agrees_bind (rangeOne_agrees alts)
  cases alts with
  | nil => exact agrees_pure _
  | cons alt rest =>
    cases rest with
    | cons =>
      cases alt with
      | mk pattern slots =>
        cases slots with
        | nil => exact agrees_pure _
        | cons position tail =>
          cases position with
          | succ => exact agrees_pure _
          | zero => cases tail <;> exact agrees_pure _
    | nil =>
      apply agrees_bind (rangeOne_agrees alt.slots)
      cases alt with
      | mk pattern slots =>
        cases slots with
        | nil => exact agrees_pure _
        | cons position tail =>
          cases tail with
          | cons => cases position <;> exact agrees_pure _
          | nil =>
            cases position with
            | succ => exact agrees_pure _
            | zero =>
              unfold rangeMatchOk
              apply agrees_bind (rangeResultSource_agrees env input)
              cases hOrigin : rangeResultOrigin env env.ranges input with
              | none => simp only [hOrigin, bind, Option.bind]; exact agrees_pure _
              | some origin =>
                simp only [hOrigin, bind, Option.bind]
                apply agrees_bind (rangeOk_agrees origin.names pattern)
                exact agrees_pure _

theorem rangeArm_agrees (env input alts) :
    Agrees (rangeArm env input alts) (baseResultArmEnv env input alts) := by
  have count : ((alts.head?.map (·.slots)).getD []).length = matchArmBinders alts := by
    cases alts <;> rfl
  have shape : baseResultArmEnv env input alts =
      match (match alts with
        | [⟨pattern, [0]⟩] => rangeMatchOk env env.ranges input pattern
        | _ => none) with
      | some ranges => { env with
          locals := List.replicate (matchArmBinders alts) (.unknown none) ++ env.locals,
          ranges := ranges }
      | none => { env with
          locals := List.replicate (matchArmBinders alts) (.unknown none) ++ env.locals,
          ranges := env.ranges.extendUnknown (matchArmBinders alts) } := by
    unfold baseResultArmEnv
    split
    · split <;> simp_all
    · split <;> simp_all
  unfold rangeArm
  apply agrees_bind (countList_agrees _)
  apply agrees_bind (replicateEnv_agrees _ _ _)
  apply agrees_bind (readRangeArm_agrees env input alts)
  rw [count, shape]
  cases (match alts with
      | [⟨pattern, [0]⟩] => rangeMatchOk env env.ranges input pattern
      | _ => none) with
  | none => exact agrees_pure _
  | some ranges =>
      apply agrees_bind (agrees_unit _)
      exact agrees_pure _

end Benitoite.Interval.BudgetScan
