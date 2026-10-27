import Benitoite.Interval.Flow

/-!
# Range の評価規則と独立した小モデルの対応

解決済みの標準束縛に付く規則を具体環境から選び、成功値の三欄・表現可能性・
射影の所属を証明する。表層の呼び出しと Result の腕の評価から局所の
前提を構成し、解析の駆動への接続とは区別する
（設計書 01-12「区間解析のRangeの評価規則と小モデル」
「区間解析の同じ成功値の直接射影」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- 型を使わず、抽象環境と共有する解決済みの二表だけを借りる。 -/
def rangeTables (env : AbstractEnv) : ConcreteEnv := ⟨[], env.standards, env.apiAt⟩

/-- 表層の直接呼び出しの認定は具体評価と同じ規則を使う。 -/
def rangeCallAt (env : AbstractEnv) (key : OperationKey) (source : Expr) : Option StandardBinding :=
  rangeCallBinding (rangeTables env) ⟨source, .base .unit, key⟩

/-- 呼び出しの認定は局所値や戻り値型を参照しない。 -/
theorem range_call_at_agrees {abstract concrete input} (models : Models abstract concrete) :
    rangeCallAt abstract input.key input.source = rangeCallBinding concrete input := by
  rcases input with ⟨source, type, key⟩
  simp only [rangeCallAt, rangeCallBinding, rangeTables, ConcreteEnv.standardAt,
    models.2.1, models.2.2]

/-- 標準束縛の規則は、出現の同定表と標準宣言の表が選ぶものだけを適用する。 -/
inductive EvalStandardAt (env : ConcreteEnv) (key : OperationKey)
    (arguments : List ConcreteValue) : EvalOutcome → Prop where
  | apply (binding result)
      (identified : env.standardAt key = some binding)
      (evaluated : EvalStandard binding.rule key arguments result) :
      EvalStandardAt env key arguments (binding.rule.finish result)

/-- 同名の利用者関数や未同定の出現へ標準規則を適用する導出はない。 -/
theorem standardAt_unidentified {env key arguments outcome}
    (missing : env.standardAt key = none) :
    ¬ EvalStandardAt env key arguments outcome := by
  intro evaluated
  cases evaluated with
  | apply binding result identified _ => simp [missing] at identified

/-- 成功値を包むときの型と構成子は、解決済みの Range/Result の組から選ぶ。 -/
theorem range_finish_ok {names key lo hi value output}
    (success : rangeCheck names key lo hi value = .normal output) :
    (StandardRule.rangeCheck names).finish (rangeCheck names key lo hi value) =
      .normal (.con names.result [.data names.owner [], .data names.error []]
        names.ok [output]) ∧ names.IsOk
          (.con names.result [.data names.owner [], .data names.error []]
            names.ok [output]) output := by
  rcases range_success_fields success with ⟨rfl, _⟩
  exact ⟨by rw [success]; rfl, .intro _ rfl⟩

/-- Result.Ok の認定から、所有元・型引数・構成子・同じ成功値を取り出す。 -/
theorem range_ok_identity {names result payload}
    (recognized : RangeNames.IsOk names result payload) :
    result = .con names.result [.data names.owner [], .data names.error []]
      names.ok [payload] ∧ payload.type = .data names.owner [] := by
  cases recognized with
  | intro value typed => exact ⟨rfl, typed⟩

/-- 三入力の表現可能性は評価の引数の型から得る。追加のAPI仮定ではない。 -/
theorem range_inputs_representable (lo hi value : Integer64Value) :
    Checked.Range.IntegerRepresentable lo.toInt ∧
      Checked.Range.IntegerRepresentable hi.toInt ∧
      Checked.Range.IntegerRepresentable value.toInt :=
  ⟨lo.toInt_bounds, hi.toInt_bounds, value.toInt_bounds⟩

/-- 検査規則の実際の導出は、検査付きの関数が返した成否だけを持つ。 -/
theorem range_check_result_iff {names key lo hi value result} :
    EvalStandard (.rangeCheck names) key [.integer lo, .integer hi, .integer value] result ↔
      result = rangeCheck names key lo hi value := by
  constructor
  · intro evaluated
    cases evaluated
    rfl
  · intro same
    rw [same]
    exact .rangeCheck ..

/-- 成功した三欄は全て Integer64 に収まり、元の入力を保つ。 -/
theorem range_success_representable {names key lo hi value output}
    (success : rangeCheck names key lo hi value = .normal output) :
    output = rangePayload names.record lo hi value ∧
      Checked.Range.IntegerRepresentable lo.toInt ∧
      Checked.Range.IntegerRepresentable hi.toInt ∧
      Checked.Range.IntegerRepresentable value.toInt ∧
      Checked.Range.InRange lo.toInt hi.toInt value.toInt :=
  ⟨(range_success_fields success).1, lo.toInt_bounds, hi.toInt_bounds,
    value.toInt_bounds, (range_success_fields success).2⟩

/-- 証拠を消した小モデルの成否・三欄・失敗優先が、標準の検査規則と一致する。 -/
theorem range_check_small_model (names : RangeNames) (key : OperationKey)
    (lo hi value : Integer64Value) :
    match Checked.Range.rawMake lo.toInt hi.toInt value.toInt with
    | .ok raw =>
        rangeCheck names key lo hi value = .normal (rangePayload names.record lo hi value) ∧
        raw = ⟨lo.toInt, hi.toInt, value.toInt⟩
    | .error (.invalidBounds l h) =>
        rangeCheck names key lo hi value = .rejected (.invalidBounds l h)
    | .error (.outOfRange l h n) =>
        rangeCheck names key lo hi value = .rejected (.outOfRange l h n) := by
  have erased := Checked.Range.erase_make lo.toInt hi.toInt value.toInt
  cases made : Checked.Range.make lo.toInt hi.toInt value.toInt with
  | ok checked =>
    rw [made] at erased
    rw [← erased]
    obtain ⟨minimum, maximum, number, _⟩ := Checked.Range.make_ok _ _ _ checked made
    exact ⟨by simp [rangeCheck, made], by
      simp [Checked.Range.erase, minimum, maximum, number]⟩
  | error error =>
    rw [made] at erased
    cases error <;> rw [← erased] <;> simp [Except.map, rangeCheck, made]

/-- 逆転は所属の検査より先に返り、三入力のうち value の位置に依存しない。 -/
theorem range_invalid_bounds (names : RangeNames) (key : OperationKey)
    (lo hi value : Integer64Value) (inverted : hi.toInt < lo.toInt) :
    rangeCheck names key lo hi value = .rejected (.invalidBounds lo.toInt hi.toInt) := by
  have made := (Checked.Range.make_invalidBounds_iff lo.toInt hi.toInt value.toInt).mpr inverted
  simp [rangeCheck, made]

/-- 正順の範囲外は元の三入力を保った拒否になる。 -/
theorem range_out_of_range (names : RangeNames) (key : OperationKey)
    (lo hi value : Integer64Value) (ordered : lo.toInt ≤ hi.toInt)
    (outside : ¬ Checked.Range.InRange lo.toInt hi.toInt value.toInt) :
    rangeCheck names key lo hi value = .rejected (.outOfRange lo.toInt hi.toInt value.toInt) := by
  have made := (Checked.Range.make_outOfRange_iff _ _ _).mpr ⟨ordered, outside⟩
  simp [rangeCheck, made]

/-- 認定した三欄は保存した value だけを返し、未知の結果と重ならない。 -/
theorem range_value_exact {record key input value result}
    (stored : rangeStoredValue record input = some value)
    (evaluated : EvalStandard (.rangeValue record) key [input] result) :
    result = .normal (.integer value) := by
  cases evaluated with
  | rangeValue _ _ _ actual known =>
      have same := Option.some.inj (known.symm.trans stored)
      subst actual
      rfl
  | rangeValueUnknown _ _ _ _ unknown => simp [stored] at unknown
  | rangeValueUnknownFailed _ _ _ unknown => simp [stored] at unknown

/-- checkInteger の成功値を射影すれば元の入力値を返し、指定した区間に所属する。 -/
theorem range_success_projection {names checkKey valueKey lo hi value output}
    (success : rangeCheck names checkKey lo hi value = .normal output) :
    output = rangePayload names.record lo hi value ∧
      EvalStandard (.rangeValue names.record) valueKey [output] (.normal (.integer value)) ∧
      Mem value.toInt (normalize lo.toInt hi.toInt) := by
  obtain ⟨same, inside⟩ := range_success_fields success
  refine ⟨same, ?_, (mem_normalize _ _ _).mpr
    ⟨value.toInt_bounds.1, value.toInt_bounds.2, inside⟩⟩
  rw [same]
  exact .rangeValue _ _ _ _ (range_payload_stored ..)

/-- 実際の検査導出から、同じ三欄への射影と元の閉区間への所属を得る。 -/
theorem range_evaluated_projection {names checkKey valueKey lo hi value output}
    (evaluated : EvalStandard (.rangeCheck names) checkKey
      [.integer lo, .integer hi, .integer value] (.normal output)) :
    output = rangePayload names.record lo hi value ∧
      EvalStandard (.rangeValue names.record) valueKey [output] (.normal (.integer value)) ∧
      Mem value.toInt (normalize lo.toInt hi.toInt) :=
  range_success_projection ((range_check_result_iff.mp evaluated).symm)

/-- 三欄を知らない CheckedInteger にも、任意の正常 Integer64 の導出がある。 -/
theorem range_other_possible (record : RangeRecord) (key : OperationKey)
    (value : Integer64Value) :
    EvalStandard (.rangeValue record) key
      [.other (.data record.owner []) rfl (by simp) (by simp)]
      (.normal (.integer value)) := .rangeValueUnknown _ _ _ _ rfl

/-- 同じ data 型の全表現で導出を残す。未知の入力を Models から除外しない。 -/
theorem range_value_total {input : ConcreteValue} {record : RangeRecord}
    (_typed : input.type = .data record.owner []) (key : OperationKey) :
    ∃ result, EvalStandard (.rangeValue record) key [input] result := by
  cases stored : rangeStoredValue record input with
  | some value => exact ⟨_, .rangeValue record key input value stored⟩
  | none => exact ⟨_, .rangeValueUnknown record key input ⟨0, by decide⟩ stored⟩

/-- checkInteger の解決済み規則は正常な Result を返し、APIの拒否を異常終了にしない。 -/
theorem range_check_at_total {env key names binding}
    (identified : ConcreteEnv.standardAt env key = some binding)
    (rule : binding.rule = .rangeCheck names) (lo hi value : Integer64Value) :
    ∃ result, EvalStandardAt env key [.integer lo, .integer hi, .integer value]
      (.normal result) ∧ result.type = .data names.result [.data names.owner [], .data names.error []] := by
  have evaluated : EvalStandard binding.rule key [.integer lo, .integer hi, .integer value]
      (rangeCheck names key lo hi value) := by rw [rule]; exact .rangeCheck ..
  have lifted := EvalStandardAt.apply binding _ identified evaluated
  rw [rule] at lifted
  cases made : Checked.Range.make lo.toInt hi.toInt value.toInt with
  | ok checked =>
    exact ⟨_, by simpa [rangeCheck, made, StandardRule.finish] using lifted, rfl⟩
  | error error =>
    cases error <;> exact ⟨_, by simpa [rangeCheck, made, StandardRule.finish] using lifted, rfl⟩

/-- 内部を読まない引数にも、解決済みの value 規則から任意の正常値への導出がある。 -/
theorem range_other_at_possible {env key owner binding}
    (identified : ConcreteEnv.standardAt env key = some binding)
    (rule : binding.rule = .rangeValue owner) (value : Integer64Value) :
    EvalStandardAt env key [.other (.data owner.owner []) rfl (by simp) (by simp)]
      (.normal (.integer value)) := by
  have evaluated : EvalStandard binding.rule key
      [.other (.data owner.owner []) rfl (by simp) (by simp)] (.normal (.integer value)) := by
    rw [rule]
    exact range_other_possible owner key value
  have lifted := EvalStandardAt.apply binding _ identified evaluated
  simpa [rule, StandardRule.finish] using lifted

-- other の射影は、局所引数と未知の式の両方から来る。両端の任意値にも導出を作り、
-- 具体表現を知らないことを理由に正常評価の集合を空にしない。
example (owner : RangeRecord) (key : OperationKey) (number : Integer64Value) :
    let value : ConcreteValue := .other (.data owner.owner []) rfl (by simp) (by simp)
    let env : ConcreteEnv := ⟨[some value], [], fun _ => none⟩
    EvalPartial env ⟨.local 0, .data owner.owner [], key⟩ (.normal value) [] ∧
      EvalPartial env ⟨.call (.funName "Example.unknown" [] []) [none] [0]
        (.cons .unit .nil), .data owner.owner [], key⟩
        (.normal value) [] ∧
      EvalStandard (.rangeValue owner) key [value] (.normal (.integer number)) := by
  dsimp only
  refine ⟨?_, .unknownNormal _ _ _ (Or.inr (Or.inr (by simp [rangeCallBinding, standardCallHead, ConcreteEnv.standardAt]))) rfl,
    range_other_possible owner key number⟩
  exact .local _ _ 0 (.other (.data owner.owner []) rfl (by simp) (by simp)) rfl

-- 同じ Ok の表示でも所有元が違う値を認めない。正しい所有元の導出も組にする。
example (names : RangeNames) (other : DataName) (different : other ≠ names.result)
    (value : ConcreteValue) (typed : value.type = .data names.owner []) :
    names.IsOk (.con names.result [.data names.owner [], .data names.error []] names.ok [value]) value ∧
      ¬ names.IsOk (.con other [.data names.owner [], .data names.error []] names.ok [value]) value := by
  refine ⟨.intro value typed, ?_⟩
  intro recognized
  have identity := (range_ok_identity recognized).1
  exact different (ConcreteValue.con.inj identity).1

/-- 表の同定と標準規則の実際の導出から Result の由来を作る。 -/
theorem range_result_at_models {env : ConcreteEnv} {origin : RangeOrigin} {binding : StandardBinding}
    {value : Integer64Value} {result : ConcreteValue}
    (identified : env.standardAt origin.checkKey = some binding)
    (rule : binding.rule = .rangeCheck origin.names)
    (evaluated : EvalStandardAt env origin.checkKey
      [.integer origin.minimum, .integer origin.maximum, .integer value] (.normal result)) :
    origin.ResultModels result := by
  generalize outcomeEq : EvalOutcome.normal result = outcome at evaluated
  cases evaluated with
  | apply actual output found evaluated =>
    have same := Option.some.inj (found.symm.trans identified)
    subst actual
    rw [rule] at evaluated
    have exactResult := range_check_result_iff.mp evaluated
    subst output
    exact ⟨value, by simpa only [rule] using outcomeEq.symm⟩

/-- 検査由来と Ok の中身の同定を合わせて初めて三欄を使える。
Error と Ok の区別は Result の認定が確認した非等号を使う。
成功値とエラー値は、ともに data 型なので型の頭だけでは区別しない。 -/
theorem range_result_ok_models {origin : RangeOrigin} {result payload : ConcreteValue}
    (different : origin.names.ok ≠ origin.names.err)
    (fromCheck : origin.ResultModels result)
    (matched : origin.names.IsOk result payload) : origin.CheckedModels payload := by
  obtain ⟨number, output⟩ := fromCheck
  obtain ⟨same, typed⟩ := range_ok_identity matched
  rw [same] at output
  cases made : Checked.Range.make origin.minimum.toInt origin.maximum.toInt number.toInt with
  | ok checked =>
    have fields := Checked.Range.make_ok _ _ _ _ made
    simp only [rangeCheck, made, StandardRule.finish, EvalOutcome.normal.injEq,
      ConcreteValue.con.injEq, List.cons.injEq] at output
    have payloadEq : rangePayload origin.names.record origin.minimum origin.maximum number =
        payload := output.2.2.2.1
    exact ⟨number, payloadEq.symm, fields.2.2.2⟩
  | error error =>
    cases error <;>
      simp only [rangeCheck, made, StandardRule.finish, EvalOutcome.normal.injEq,
        ConcreteValue.con.injEq, List.cons.injEq] at output
    all_goals exact False.elim (different output.2.2.1.symm)

/-- 保存した実三欄の value は、由来に記録した端点に所属する。 -/
theorem range_checked_models_mem {origin : RangeOrigin} {value : ConcreteValue}
    (related : origin.CheckedModels value) :
    ∃ number : Integer64Value,
      value = rangePayload origin.names.record origin.minimum origin.maximum number ∧
      Mem number.toInt (normalize origin.minimum.toInt origin.maximum.toInt) := by
  obtain ⟨number, same, inside⟩ := related
  exact ⟨number, same, (mem_normalize _ _ _).mpr
    ⟨number.toInt_bounds.1, number.toInt_bounds.2, inside⟩⟩

/-- 型内で表現できる固定端点だけを認める。局所値は定数として扱わない。 -/
def rangeFixedInteger (source : Expr) : Option Integer64Value := do
  let value ← integerConstant source
  if bounded : min64 ≤ value ∧ value ≤ max64 then some ⟨value, bounded⟩ else none

/-- 固定端点の認定は、その式の正常評価と一致する。局所区間から逆算しない。 -/
theorem range_fixed_integer_sound {env : ConcreteEnv} {input : EvalInput}
    {value fixed : Integer64Value} {trace : EvalTrace}
    (evaluated : EvalPartial env input (.normal (.integer value)) trace)
    (recognized : rangeFixedInteger input.source = some fixed) : value = fixed := by
  unfold rangeFixedInteger at recognized
  change ((integerConstant input.source).bind _) = some fixed at recognized
  obtain ⟨number, known, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  split at recognized
  · have same := Option.some.inj recognized
    rw [← same]
    exact Subtype.ext (integerConstant_sound evaluated known)
  · contradiction

/-- 解決済みの直接 call の固定端点を契約上の位置で読む。
ソース順の評価はこの関数では行わず、holes・pipe・関数値は認定しない。 -/
def rangeCallOrigin (env : AbstractEnv) (input : EvalInput) : Option RangeOrigin := do
  match input.source with
  | .call (.funName declaration [] []) labels positions arguments =>
    if labels.length ≠ 3 ∨ ¬ positions.Perm [0, 1, 2] then none else do
      let binding ← env.standardAt input.key
      if declaration ≠ binding.declaration then none else do
        match binding.rule with
        | .rangeCheck names =>
          let args := exprsChildren arguments
          if args.length ≠ 3 then none else do
            let lower ← fieldAt 0 positions args
            let upper ← fieldAt 1 positions args
            let minimum ← rangeFixedInteger lower
            let maximum ← rangeFixedInteger upper
            some ⟨names, input.key, minimum, maximum⟩
        | _ => none
  | _ => none

/-- 認定した由来は同じ呼び出しキーと解決済み標準規則を持つ。 -/
theorem range_call_origin_table {env : AbstractEnv} {input : EvalInput} {origin : RangeOrigin}
    (recognized : rangeCallOrigin env input = some origin) :
    origin.checkKey = input.key ∧ ∃ binding, env.standardAt input.key = some binding ∧
      binding.rule = .rangeCheck origin.names := by
  unfold rangeCallOrigin at recognized
  split at recognized
  next =>
    split at recognized
    · contradiction
    · change ((env.standardAt input.key).bind _) = some origin at recognized
      simp only [Option.bind_eq_some_iff] at recognized
      obtain ⟨binding, found, recognized⟩ := recognized
      split at recognized
      · contradiction
      · split at recognized
        next names rule =>
          split at recognized
          · contradiction
          · change ((fieldAt 0 _ _).bind _) = some origin at recognized
            simp only [Option.bind_eq_some_iff] at recognized
            obtain ⟨lower, _, recognized⟩ := recognized
            change ((fieldAt 1 _ _).bind _) = some origin at recognized
            obtain ⟨upper, _, recognized⟩ := Option.bind_eq_some_iff.mp recognized
            change ((rangeFixedInteger lower).bind _) = some origin at recognized
            obtain ⟨minimum, _, recognized⟩ := Option.bind_eq_some_iff.mp recognized
            change ((rangeFixedInteger upper).bind _) = some origin at recognized
            obtain ⟨maximum, _, same⟩ := Option.bind_eq_some_iff.mp recognized
            have same := Option.some.inj same
            cases same
            exact ⟨rfl, binding, found, rule⟩
        next => contradiction
  next => contradiction

/-- 固定端点の認定から、具体評価が使う同じ標準束縛と二つの引数式を得る。 -/
theorem range_call_origin_arguments {abstract : AbstractEnv} {env : ConcreteEnv}
    {input : EvalInput} {origin : RangeOrigin}
    (models : Models abstract env)
    (recognized : rangeCallOrigin abstract input = some origin) :
    ∃ declaration labels positions sources binding lower upper,
      input.source = .call (.funName declaration [] []) labels positions sources ∧
      positions.Perm [0, 1, 2] ∧ env.standardAt input.key = some binding ∧ binding.rule = .rangeCheck origin.names ∧
      rangeCallBinding env input = some binding ∧
      fieldAt 0 positions (exprsChildren sources) = some lower ∧
      fieldAt 1 positions (exprsChildren sources) = some upper ∧
      rangeFixedInteger lower = some origin.minimum ∧
      rangeFixedInteger upper = some origin.maximum := by
  unfold rangeCallOrigin at recognized
  split at recognized
  next declaration labels positions sources source =>
    split at recognized
    · contradiction
    next shape =>
      have shape : labels.length = 3 ∧ positions.Perm [0, 1, 2] := by
        simpa using shape
      change ((abstract.standardAt input.key).bind _) = some origin at recognized
      obtain ⟨binding, found, recognized⟩ := Option.bind_eq_some_iff.mp recognized
      have concreteFound : env.standardAt input.key = some binding := by
        rw [models_standardAt models]; exact found
      split at recognized
      · contradiction
      next declarationEq =>
        have declarationEq : declaration = binding.declaration := by simpa using declarationEq
        split at recognized
        next names rule =>
          dsimp only at recognized
          split at recognized
          · contradiction
          next count =>
            have count : (exprsChildren sources).length = 3 := by simpa using count
            change ((fieldAt 0 positions (exprsChildren sources)).bind _) = some origin at recognized
            obtain ⟨lower, lowerAt, recognized⟩ := Option.bind_eq_some_iff.mp recognized
            change ((fieldAt 1 positions (exprsChildren sources)).bind _) = some origin at recognized
            obtain ⟨upper, upperAt, recognized⟩ := Option.bind_eq_some_iff.mp recognized
            change ((rangeFixedInteger lower).bind _) = some origin at recognized
            obtain ⟨minimum, minimumAt, recognized⟩ := Option.bind_eq_some_iff.mp recognized
            change ((rangeFixedInteger upper).bind _) = some origin at recognized
            obtain ⟨maximum, maximumAt, same⟩ := Option.bind_eq_some_iff.mp recognized
            cases same
            refine ⟨declaration, labels, positions, sources, binding, lower, upper,
              source, shape.2, concreteFound, rule, ?_, lowerAt, upperAt, minimumAt, maximumAt⟩
            simp [rangeCallBinding, standardCallHead, source, concreteFound, declarationEq, rule,
              shape.1, shape.2, count]
        next => contradiction
  next => contradiction

/-- 直接 call、または一度保存した Result だけを照合元にする。
checked の記録・Result の別名・任意の容器から由来を推測しない。 -/
def rangeResultOrigin (env : AbstractEnv) (state : RangeState)
    (input : EvalInput) : Option RangeOrigin :=
  match input.source with
  | .local index => match state.facts[index]? with
    | some (some (.result origin)) => some origin
    | _ => none
  | _ => rangeCallOrigin env input

/-- 保存できるのは直接 call の記録だけである。保存済み Result の複写は未知にする。 -/
def rangeSaveResult (env : AbstractEnv) (state : RangeState) (input : EvalInput) : RangeState :=
  state.extend ((rangeCallOrigin env input).map RangeLocalFact.result)

/-- Ok の一つの変数を解決済み構成子と照合する。wild には束縛番号を作らない。 -/
def rangeOkPattern (names : RangeNames) : Pattern → Bool
  | .con qualifier name [.var] =>
    (qualifier.isNone || qualifier == some names.result) && name == names.ok
  | _ => false

/-- 照合した成功値を新しい通常位置へ結び付ける。後のコピーへは記録を渡さない。 -/
def rangeBindOk (state : RangeState) (origin : RangeOrigin) : RangeState :=
  state.extend (some (.checked origin state.scope.nextId))

/-- 同じ成功値の局所参照だけが、保存した端点を使える。番号も再照合する。 -/
def rangeCheckedOrigin (state : RangeState) (index : Nat) : Option RangeOrigin := do
  let id ← state.scope.idAt index
  match state.facts[index]? with
  | some (some (.checked origin successId)) => if successId = id then some origin else none
  | _ => none

/-- 認定した照合元の正常結果。call の引数の評価順は表層への接続が担い、
ここでは正常に得た三引数に対する標準規則、または保存済み局所値を使う。 -/
def RangeSourceNormal (env : ConcreteEnv) (input : EvalInput)
    (origin : RangeOrigin) (result : ConcreteValue) : Prop :=
  match input.source with
  | .local index => env.locals[index]? = some (some result)
  | _ => ∃ value : Integer64Value, EvalStandardAt env origin.checkKey
      [.integer origin.minimum, .integer origin.maximum, .integer value] (.normal result)

/-- 表層の実際の正常評価から、直接検査または一度保存した Result の局所の前提を作る。
固定端点とソース順の引数評価を照合し、中心命題の前提を増やさない。 -/
theorem range_source_normal_of_eval {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {origin : RangeOrigin} {result : ConcreteValue}
    {trace : EvalTrace}
    (models : Models abstract env)
    (recognized : rangeResultOrigin abstract state input = some origin)
    (evaluated : EvalPartial env input (.normal result) trace) :
    RangeSourceNormal env input origin result := by
  by_cases isLocal : ∃ index, input.source = .local index
  · obtain ⟨index, sourceEq⟩ := isLocal
    rcases input with ⟨source, type, key⟩
    dsimp only at sourceEq
    subst source
    change env.locals[index]? = some (some result)
    cases evaluated <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify]
  · have direct : rangeCallOrigin abstract input = some origin := by
      cases input with
      | mk source type key =>
        cases source <;> first | exact recognized | exact False.elim (isLocal ⟨_, rfl⟩)
    have checkKey := (range_call_origin_table direct).1
    obtain ⟨declaration, labels, positions, sources, binding, lower, upper,
      sourceEq, permutation, atBinding, rule, callKnown, lowerAt, upperAt, lowerFixed, upperFixed⟩ :=
      range_call_origin_arguments models direct
    rcases input with ⟨source, type, key⟩
    dsimp only at sourceEq checkKey
    subst source
    have count : positions.length = 3 := by simpa using permutation.length_eq
    change ∃ value : Integer64Value, EvalStandardAt env origin.checkKey
      [.integer origin.minimum, .integer origin.maximum, .integer value] (.normal result)
    generalize normal : EvalOutcome.normal result = outcome at evaluated
    cases evaluated with
    | unknownNormal _ _ _ unknown _ =>
      simp [UnknownAt, Unsupported, Unmodeled, classify, callKnown] at unknown
    | unknownFailed => cases normal
    | standardCall _ _ _ _ _ _ actual values arguments output trace actualKnown children ordered standard =>
      have same : actual = binding := Option.some.inj (actualKnown.symm.trans callKnown)
      subst actual
      have standard : EvalStandard (.rangeCheck origin.names) key arguments output := by
        simpa only [rule] using standard
      have sourceCount := (typed_arguments_normal_length children).1
      simp only [StandardBinding.sourceTypes, rule, StandardRule.argumentType, List.length_replicate] at sourceCount
      have children := typed_arguments_uniform children (.base .integer) (by
        simp only [StandardBinding.sourceTypes, rule, StandardRule.argumentType, sourceCount])
      cases standard with
      | rangeCheck names key lo hi value =>
        obtain ⟨lowValue, lowKey, lowTrace, lowField, lowEval⟩ :=
          arguments_normal_field children lowerAt
        obtain ⟨highValue, highKey, highTrace, highField, highEval⟩ :=
          arguments_normal_field children upperAt
        have lowOrder := order_arguments_field (position := 0) ordered (by omega)
        have highOrder := order_arguments_field (position := 1) ordered (by omega)
        have lowSame : lowValue = .integer lo := Option.some.inj (lowField.symm.trans lowOrder)
        have highSame : highValue = .integer hi := Option.some.inj (highField.symm.trans highOrder)
        rw [lowSame] at lowEval
        rw [highSame] at highEval
        have loEq := range_fixed_integer_sound lowEval lowerFixed
        have hiEq := range_fixed_integer_sound highEval upperFixed
        refine ⟨value, ?_⟩
        rw [checkKey, ← loEq, ← hiEq]
        exact .apply binding _ atBinding (by rw [rule]; exact .rangeCheck ..)
    | fixedCallFailed => cases normal
    | fixedCallAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      rw [← normal] at abrupt; contradiction
    | standardCallAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      rw [← normal] at abrupt
      contradiction

/-- 直接 call と一度の局所保存を、同じ検査由来の契約へまとめる。 -/
theorem range_result_source_models {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {origin : RangeOrigin} {result : ConcreteValue}
    (models : Models abstract env) (related : state.Models env)
    (recognized : rangeResultOrigin abstract state input = some origin)
    (evaluated : RangeSourceNormal env input origin result) : origin.ResultModels result := by
  by_cases isLocal : ∃ index, input.source = .local index
  · obtain ⟨index, source⟩ := isLocal
    simp only [RangeSourceNormal, source] at evaluated
    simp only [rangeResultOrigin, source] at recognized
    cases found : state.facts[index]? with
    | none => simp [found] at recognized
    | some fact =>
      cases fact with
      | none => simp [found] at recognized
      | some fact =>
        cases fact with
        | checked => simp [found] at recognized
        | result stored =>
          simp only [found, Option.some.injEq] at recognized
          subst stored
          obtain ⟨id, value, _, atValue, modeled⟩ := related index (.result origin) found
          have same := Option.some.inj (Option.some.inj (atValue.symm.trans evaluated))
          subst result
          exact modeled
  · have direct : rangeCallOrigin abstract input = some origin := by
      cases input with
      | mk source type key =>
        cases source <;> first | exact recognized | exact False.elim (isLocal ⟨_, rfl⟩)
    have ⟨key, binding, found, rule⟩ := range_call_origin_table direct
    have found : env.standardAt origin.checkKey = some binding := by
      rw [key, models_standardAt models]
      exact found
    have evaluated : ∃ value : Integer64Value, EvalStandardAt env origin.checkKey
        [.integer origin.minimum, .integer origin.maximum, .integer value] (.normal result) := by
      cases input with
      | mk source type key =>
        cases source <;> first | exact evaluated | exact False.elim (isLocal ⟨_, rfl⟩)
    obtain ⟨value, evaluated⟩ := evaluated
    exact range_result_at_models found rule evaluated

/-- 一度保存した Result の局所参照は、同じ具体 Result と対応する。 -/
theorem range_saved_result_models {state : RangeState} {env : ConcreteEnv} {index : Nat}
    {origin : RangeOrigin} {result : ConcreteValue}
    (related : state.Models env)
    (known : state.facts[index]? = some (some (.result origin)))
    (read : env.locals[index]? = some (some result)) : origin.ResultModels result := by
  obtain ⟨id, value, _, found, modeled⟩ := related index (.result origin) known
  have same := Option.some.inj (Option.some.inj (found.symm.trans read))
  subst result
  exact modeled

/-- Result を通常の bind/shadow に一度保存しても由来を保つ。
direct は呼び出しの標準規則の導出から得る局所の契約である。 -/
theorem range_save_result_models {abstract state env input result}
    (related : state.Models env)
    (direct : ∀ origin, rangeCallOrigin abstract input = some origin →
      origin.ResultModels result) :
    (rangeSaveResult abstract state input).Models
      { env with locals := some result :: env.locals } := by
  apply range_extend_models related
  intro known found
  cases recognized : rangeCallOrigin abstract input with
  | none => simp [recognized] at found
  | some origin =>
    simp only [recognized, Option.map_some, Option.some.injEq] at found
    subst known
    exact direct origin recognized

/-- 一度の保存の不変条件を、表層の正常評価から構成する。 -/
theorem range_save_result_of_eval {abstract state env input result trace}
    (models : Models abstract env) (related : state.Models env)
    (evaluated : EvalPartial env input (.normal result) trace) :
    (rangeSaveResult abstract state input).Models
      { env with locals := some result :: env.locals } := by
  apply range_save_result_models related
  intro origin direct
  have recognized : rangeResultOrigin abstract state input = some origin := by
    cases input with
    | mk source type key =>
      cases source <;> first
      | exact direct
      | simp [rangeCallOrigin] at direct
  exact range_result_source_models models related recognized
    (range_source_normal_of_eval models recognized evaluated)

/-- 検査由来の Result の Ok を選んだときだけ、新しい番号へ三欄を渡す。 -/
theorem range_bind_ok_models {state env origin result payload}
    (different : origin.names.ok ≠ origin.names.err)
    (related : state.Models env) (fromCheck : origin.ResultModels result)
    (matched : origin.names.IsOk result payload) :
    (rangeBindOk state origin).Models { env with locals := some payload :: env.locals } := by
  apply range_extend_models related
  intro known found
  cases found
  exact ⟨rfl, range_result_ok_models different fromCheck matched⟩

/-- 読み取れた記録は同じ番号の同じ成功値だけを表す。 -/
theorem range_checked_origin_models {state env index origin payload}
    (related : state.Models env)
    (known : rangeCheckedOrigin state index = some origin)
    (read : env.locals[index]? = some (some payload)) : origin.CheckedModels payload := by
  unfold rangeCheckedOrigin at known
  cases atId : state.scope.idAt index with
  | none => simp [atId] at known
  | some id =>
    simp only [atId] at known
    cases atFact : state.facts[index]? with
    | none => simp [atFact] at known
    | some fact =>
      cases fact with
      | none => simp [atFact] at known
      | some fact =>
        cases fact with
        | result old => simp [atFact] at known
        | checked old successId =>
          simp only [atFact] at known
          change (if successId = id then some old else none) = some origin at known
          split at known
          · cases known
            obtain ⟨_, value, _, found, modeled⟩ := related index (.checked origin successId) atFact
            have same := Option.some.inj (Option.some.inj (found.symm.trans read))
            subst payload
            exact modeled.2
          · contradiction

/-- 型が同じ other の Result は、検査由来の記録を持てない。 -/
theorem range_result_not_other (origin : RangeOrigin) (type notInteger notBoolean notUnit) :
    ¬ origin.ResultModels (.other type notInteger notBoolean notUnit) := by
  rintro ⟨number, output⟩
  cases made : Checked.Range.make origin.minimum.toInt origin.maximum.toInt number.toInt with
  | ok checked => simp [rangeCheck, made, StandardRule.finish] at output
  | error error => cases error <;> simp [rangeCheck, made, StandardRule.finish] at output

/-- Result の二表現を許したままでも、検査由来なら同じ既知の成功値に限られる。 -/
theorem range_ok_payload_models {origin : RangeOrigin} {result payload : ConcreteValue}
    (different : origin.names.ok ≠ origin.names.err)
    (fromCheck : origin.ResultModels result)
    (matched : origin.names.OkPayload result payload) : origin.CheckedModels payload := by
  cases matched with
  | known matched => exact range_result_ok_models different fromCheck matched
  | other => exact False.elim (range_result_not_other origin _ _ _ _ fromCheck)

/-- 直接または一度保存した Result の Ok(var) だけへ成功値の由来を付ける。 -/
def rangeMatchOk (env : AbstractEnv) (state : RangeState) (input : EvalInput)
    (pattern : Pattern) : Option RangeState := do
  let origin ← rangeResultOrigin env state input
  if rangeOkPattern origin.names pattern then some (rangeBindOk state origin) else none

/-- 認定した Ok の一変数を、同じ具体成功値の新しい番号へ対応させる。 -/
theorem range_match_ok_models {abstract : AbstractEnv} {state inner : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {pattern : Pattern}
    {result payload : ConcreteValue}
    (models : Models abstract env) (related : state.Models env)
    (matched : rangeMatchOk abstract state input pattern = some inner)
    (evaluated : ∀ origin, rangeResultOrigin abstract state input = some origin →
      RangeSourceNormal env input origin result ∧ origin.names.OkPayload result payload ∧
        origin.names.ok ≠ origin.names.err) :
    inner.Models { env with locals := some payload :: env.locals } := by
  unfold rangeMatchOk at matched
  change ((rangeResultOrigin abstract state input).bind _) = some inner at matched
  obtain ⟨origin, recognized, matched⟩ := Option.bind_eq_some_iff.mp matched
  split at matched
  · cases matched
    obtain ⟨normal, selected, different⟩ := evaluated origin recognized
    have fromCheck := range_result_source_models models related recognized normal
    apply range_extend_models related
    intro known found
    cases found
    exact ⟨rfl, range_ok_payload_models different fromCheck selected⟩
  · contradiction

/-- Ok の束縛も通常束縛と同じ新しい番号を一つだけ使う。 -/
theorem range_bind_ok_valid {state : RangeState} (valid : state.Valid) (origin : RangeOrigin) :
    (rangeBindOk state origin).Valid := range_extend_valid valid _

/-- 別の束縛番号に同じ記録を貼り付けても、成功値の根拠としては読めない。 -/
theorem range_checked_wrong_id {state : RangeState} {index stored actual : Nat}
    {origin : RangeOrigin} (atId : state.scope.idAt index = some actual)
    (atFact : state.facts[index]? = some (some (.checked origin stored)))
    (different : stored ≠ actual) : rangeCheckedOrigin state index = none := by
  simp [rangeCheckedOrigin, atId, atFact, different]

/-- 新しい未知の束縛で shadow しても、外の成功値の番号は変わらない。 -/
theorem range_checked_shift (state : RangeState) (fact : Option RangeLocalFact) (index : Nat) :
    rangeCheckedOrigin (state.extend fact) (index + 1) = rangeCheckedOrigin state index := rfl

/-- 初期化と忘却は位置の数と番号の非再利用を保つ。 -/
theorem range_empty_valid (scope : BindingScope)
    (valid : ∀ id ∈ scope.positions, id < scope.nextId) : (RangeState.empty scope).Valid :=
  ⟨List.length_replicate, valid⟩

/-- 一度の保存も、他の bind/shadow と同じ一位置だけを増やす。 -/
theorem range_save_result_valid {state : RangeState} (valid : state.Valid)
    (env : AbstractEnv) (input : EvalInput) : (rangeSaveResult env state input).Valid :=
  range_extend_valid valid _

/-- 解決済みの直接 value(local) だけを認める。型引数・穴・関数値・pipe は含めない。 -/
def rangeValueCall (env : AbstractEnv) (input : EvalInput) : Option (RangeRecord × Nat) := do
  match input.type, input.source with
  | .base .integer, .call (.funName declaration [] []) [_] [0] (.cons (.local index) .nil) =>
    let binding ← env.standardAt input.key
    if declaration ≠ binding.declaration then none else
      match binding.rule with
      | .rangeValue owner => some (owner, index)
      | _ => none
  | _, _ => none

/-- 呼び出しの認定には、同じ出現の標準束縛表と射影規則が必要である。 -/
theorem range_value_call_table {env : AbstractEnv} {input : EvalInput} {owner index}
    (recognized : rangeValueCall env input = some (owner, index)) :
    input.type = .base .integer ∧ ∃ binding, env.standardAt input.key = some binding ∧
      binding.rule = .rangeValue owner := by
  unfold rangeValueCall at recognized
  split at recognized
  next =>
    change ((env.standardAt input.key).bind _) = some (owner, index) at recognized
    obtain ⟨binding, found, recognized⟩ := Option.bind_eq_some_iff.mp recognized
    split at recognized
    · contradiction
    · split at recognized
      next actual rule =>
        cases recognized
        exact ⟨by assumption, binding, found, rule⟩
      next => contradiction
  next => contradiction

/-- 認定から元の直接呼び出しと同じ局所位置を取り出す。
ソースの見た目を、評価の呼び出し側で改めて仮定する必要をなくす。 -/
theorem range_value_call_source {env : AbstractEnv} {input : EvalInput} {owner index}
    (recognized : rangeValueCall env input = some (owner, index)) :
    ∃ declaration label, input.source = .call (.funName declaration [] []) [label] [0]
      (.cons (.local index) .nil) := by
  unfold rangeValueCall at recognized
  split at recognized
  next =>
    change ((env.standardAt input.key).bind _) = some (owner, index) at recognized
    obtain ⟨binding, _, recognized⟩ := Option.bind_eq_some_iff.mp recognized
    split at recognized
    · contradiction
    · split at recognized
      next =>
        cases recognized
        exact ⟨_, _, by assumption⟩
      next => contradiction
  next => contradiction

/-- value が読む位置と同じ番号の成功値だけを使い、データ型の所有元も再照合する。 -/
def rangeValueOrigin (env : AbstractEnv) (state : RangeState)
    (input : EvalInput) : Option RangeOrigin := do
  let (owner, index) ← rangeValueCall env input
  let origin ← rangeCheckedOrigin state index
  if origin.names.record = owner then some origin else none

/-- 射影の構文認定は、具体評価と共通の呼び出し認定も含む。 -/
theorem range_value_call_at {env input owner index}
    (recognized : rangeValueCall env input = some (owner, index)) :
    ∃ binding, rangeCallAt env input.key input.source = some binding ∧
      binding.rule = .rangeValue owner := by
  unfold rangeValueCall at recognized
  split at recognized
  next =>
    obtain ⟨binding, found, recognized⟩ := Option.bind_eq_some_iff.mp recognized
    split at recognized
    · contradiction
    next different =>
      split at recognized
      next actual rule =>
        cases recognized
        refine ⟨binding, ?_, rule⟩
        simp_all [rangeCallAt, rangeCallBinding, standardCallHead, rangeTables, ConcreteEnv.standardAt,
          AbstractEnv.standardAt, exprsChildren]
      next => contradiction
  next => contradiction

/-- 正常な同定済み射影の評価導出は、実際に Integer64 の戻り値型を持つ。 -/
theorem range_value_normal_input_type {abstract concrete input owner index value trace}
    (models : Models abstract concrete)
    (recognized : rangeValueCall abstract { input with type := .base .integer } = some (owner, index))
    (evaluated : EvalPartial concrete input (.normal value) trace) : input.type = .base .integer := by
  obtain ⟨declaration, label, sourceEq⟩ := range_value_call_source recognized
  obtain ⟨binding, callAt, rule⟩ := range_value_call_at recognized
  have concreteCall : rangeCallBinding concrete input = some binding := by
    rw [← range_call_at_agrees models]
    exact callAt
  rcases input with ⟨source, type, key⟩
  dsimp only at sourceEq concreteCall
  subst source
  generalize normal : EvalOutcome.normal value = outcome at evaluated
  cases evaluated with
  | unknownNormal _ _ _ unknown _ =>
    simp [UnknownAt, Unsupported, Unmodeled, classify, concreteCall] at unknown
  | unknownFailed => cases normal
  | standardCall _ _ _ _ _ _ actual _ _ _ _ actualAt _ _ _ =>
    have same : actual = binding := Option.some.inj (actualAt.symm.trans concreteCall)
    subst actual
    simp only [rule, StandardRule.resultType]
  | fixedCallFailed => cases normal
  | fixedCallAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
    rw [← normal] at abrupt; contradiction
  | standardCallAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt =>
    rw [← normal] at abrupt
    contradiction

/-- 認定した射影の由来は、同じ局所位置と同じ所有元の標準規則に対応する。 -/
theorem range_value_origin_source {env : AbstractEnv} {state : RangeState}
    {input : EvalInput} {origin : RangeOrigin}
    (recognized : rangeValueOrigin env state input = some origin) :
    ∃ index, rangeValueCall env input = some (origin.names.record, index) ∧
      rangeCheckedOrigin state index = some origin := by
  unfold rangeValueOrigin at recognized
  change ((rangeValueCall env input).bind _) = some origin at recognized
  obtain ⟨⟨owner, index⟩, call, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  change ((rangeCheckedOrigin state index).bind _) = some origin at recognized
  obtain ⟨actual, checked, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  split at recognized
  next same =>
    cases recognized
    exact ⟨index, by simpa only [same] using call, checked⟩
  next => contradiction

/-- 認定できない射影は型内 Top に退く。失敗や Range.Error の候補は作らない。 -/
def rangeValueInterval (env : AbstractEnv) (state : RangeState) (input : EvalInput) : Interval :=
  match rangeValueOrigin env state input with
  | some origin => normalize origin.minimum.toInt origin.maximum.toInt
  | none => top

/-- 実際の標準評価で正常に得た整数は、同じ成功値の保存端点に所属する。
表層の call の評価や Result の腕を評価する規則は、この局所補題の前提から別に構成する。 -/
theorem range_value_origin_mem {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {origin : RangeOrigin} {index : Nat}
    {payload : ConcreteValue} {number : Integer64Value}
    (models : Models abstract env) (related : state.Models env)
    (call : rangeValueCall abstract input = some (origin.names.record, index))
    (known : rangeCheckedOrigin state index = some origin)
    (read : env.locals[index]? = some (some payload))
    (evaluated : EvalStandardAt env input.key [payload] (.normal (.integer number))) :
    Mem number.toInt (normalize origin.minimum.toInt origin.maximum.toInt) := by
  obtain ⟨_, binding, found, rule⟩ := range_value_call_table call
  have foundConcrete : env.standardAt input.key = some binding := by
    rw [models_standardAt models]; exact found
  have checked := range_checked_origin_models related known read
  obtain ⟨value, same, inRange⟩ := checked
  have inside := (mem_normalize value.toInt origin.minimum.toInt origin.maximum.toInt).mpr
    ⟨value.toInt_bounds.1, value.toInt_bounds.2, inRange⟩
  subst payload
  generalize outcomeEq : EvalOutcome.normal (.integer number) = outcome at evaluated
  cases evaluated with
  | apply actual output identified standard =>
    have sameBinding := Option.some.inj (identified.symm.trans foundConcrete)
    subst actual
    rw [rule] at standard
    have exactValue := range_value_exact (range_payload_stored ..) standard
    rw [rule, exactValue] at outcomeEq
    have numberEq : number = value :=
      ConcreteValue.integer.inj (EvalOutcome.normal.inj outcomeEq)
    simpa only [numberEq] using inside

/-- 未認定の場合も含め、正常な射影値を失わない。記録のない位置は追加条件を要求しない。 -/
theorem range_value_interval_mem {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {number : Integer64Value}
    (models : Models abstract env) (related : state.Models env)
    (evaluated : ∀ origin, rangeValueOrigin abstract state input = some origin →
      ∃ index payload, rangeValueCall abstract input = some (origin.names.record, index) ∧
        env.locals[index]? = some (some payload) ∧
        EvalStandardAt env input.key [payload] (.normal (.integer number))) :
    Mem number.toInt (rangeValueInterval abstract state input) := by
  unfold rangeValueInterval
  split
  next origin recognized =>
    obtain ⟨index, call, known⟩ := range_value_origin_source recognized
    obtain ⟨actual, payload, actualCall, read, standard⟩ := evaluated origin recognized
    have sameIndex : actual = index := (Prod.mk.inj (Option.some.inj (actualCall.symm.trans call))).2
    subst actual
    exact range_value_origin_mem models related call known read standard
  next => exact (mem_top _).mpr number.toInt_bounds

/-- 記録と具体環境が対応すれば、認定した射影には所属する正常値の導出がある。
所属の補題を、実際の評価導出が一つもない場合だけの保証にしない。 -/
theorem range_value_origin_total {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {origin : RangeOrigin}
    (models : Models abstract env) (related : state.Models env)
    (recognized : rangeValueOrigin abstract state input = some origin) :
    ∃ index payload number, rangeValueCall abstract input = some (origin.names.record, index) ∧
      env.locals[index]? = some (some payload) ∧
      EvalStandardAt env input.key [payload] (.normal (.integer number)) ∧
      Mem number.toInt (rangeValueInterval abstract state input) := by
  obtain ⟨index, call, known⟩ := range_value_origin_source recognized
  obtain ⟨_, binding, found, rule⟩ := range_value_call_table call
  have atId : ∃ id, state.scope.idAt index = some id := by
    unfold rangeCheckedOrigin at known
    obtain ⟨id, found, _⟩ := Option.bind_eq_some_iff.mp known
    exact ⟨id, found⟩
  obtain ⟨id, atId⟩ := atId
  obtain ⟨payload, read⟩ : ∃ payload, env.locals[index]? = some (some payload) := by
    unfold rangeCheckedOrigin at known
    simp only [atId] at known
    split at known
    next old successId atFact =>
      obtain ⟨_, payload, _, read, _⟩ := related index (.checked old successId) atFact
      exact ⟨payload, read⟩
    next => contradiction
  obtain ⟨number, same, _⟩ := range_checked_origin_models related known read
  have normal : EvalStandardAt env input.key [payload] (.normal (.integer number)) := by
    have foundConcrete : env.standardAt input.key = some binding := by
      rw [models_standardAt models]; exact found
    have standard : EvalStandard binding.rule input.key [payload] (.normal (.integer number)) := by
      rw [rule, same]
      exact .rangeValue _ _ _ _ (range_payload_stored ..)
    have evaluated := EvalStandardAt.apply binding (.normal (.integer number)) foundConcrete standard
    simpa only [rule, StandardRule.finish] using evaluated
  refine ⟨index, payload, number, call, read, normal, ?_⟩
  unfold rangeValueInterval
  rw [recognized]
  exact range_value_origin_mem models related call known read normal

/-- 内部を読まない未知の値も含め、value の標準規則が正常に返す値は Integer64 である。
正常値の種類を呼び出し側の仮定にせず、実際の評価導出から得る。 -/
theorem range_value_at_normal_integer {env : ConcreteEnv} {key owner binding arguments value}
    (identified : env.standardAt key = some binding)
    (rule : binding.rule = .rangeValue owner)
    (evaluated : EvalStandardAt env key arguments (.normal value)) :
    ∃ number : Integer64Value, value = .integer number := by
  generalize outcomeEq : EvalOutcome.normal value = outcome at evaluated
  cases evaluated with
  | apply actual result found standard =>
    have same := Option.some.inj (found.symm.trans identified)
    subst actual
    rw [rule] at standard
    cases standard <;> simp only [rule, StandardRule.finish] at outcomeEq
    all_goals first
      | cases outcomeEq; exact ⟨_, rfl⟩
      | contradiction

/-- 直接 value(local) の正常結果から、整数であることと射影区間への所属を得る。
記録のない値にも適用し、その場合は型内 Top を返す。 -/
theorem range_value_call_normal_mem {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {owner index payload value}
    (models : Models abstract env) (related : state.Models env)
    (call : rangeValueCall abstract input = some (owner, index))
    (read : env.locals[index]? = some (some payload))
    (evaluated : EvalStandardAt env input.key [payload] (.normal value)) :
    ∃ number : Integer64Value, value = .integer number ∧
      Mem number.toInt (rangeValueInterval abstract state input) := by
  obtain ⟨_, binding, found, rule⟩ := range_value_call_table call
  have foundConcrete : env.standardAt input.key = some binding := by
    rw [models_standardAt models]; exact found
  obtain ⟨number, rfl⟩ := range_value_at_normal_integer foundConcrete rule evaluated
  refine ⟨number, rfl, range_value_interval_mem models related ?_⟩
  intro origin recognized
  obtain ⟨actual, actualCall, _⟩ := range_value_origin_source recognized
  have same := Prod.mk.inj (Option.some.inj (actualCall.symm.trans call))
  exact ⟨index, payload, by simpa only [same.1] using call, read, evaluated⟩

/-- 同じ局所値への表層の射影導出から、既存の標準射影の導出を取り出す。 -/
theorem range_value_standard_of_eval {abstract : AbstractEnv} {env : ConcreteEnv}
    {input : EvalInput} {owner index result trace}
    (models : Models abstract env)
    (recognized : rangeValueCall abstract input = some (owner, index))
    (evaluated : EvalPartial env input (.normal result) trace) :
    ∃ payload, env.locals[index]? = some (some payload) ∧
      EvalStandardAt env input.key [payload] (.normal result) := by
  obtain ⟨declaration, label, sourceEq⟩ := range_value_call_source recognized
  obtain ⟨typed, binding, found, rule⟩ := range_value_call_table recognized
  have atBinding : env.standardAt input.key = some binding := by
    rw [models_standardAt models]; exact found
  rcases input with ⟨source, type, key⟩
  dsimp only at sourceEq typed atBinding
  subst source
  have concreteCall : rangeCallBinding env
      ⟨.call (.funName declaration [] []) [label] [0] (.cons (.local index) .nil),
        type, key⟩ = some binding := by
    rw [typed] at recognized
    unfold rangeValueCall at recognized
    change ((abstract.standardAt key).bind _) = some (owner, index) at recognized
    obtain ⟨actual, actualAt, recognized⟩ := Option.bind_eq_some_iff.mp recognized
    have same : actual = binding := Option.some.inj (actualAt.symm.trans found)
    subst actual
    split at recognized
    · contradiction
    next declarationEq =>
      have declarationEq : declaration = binding.declaration := by simpa using declarationEq
      simp [rangeCallBinding, standardCallHead, atBinding, declarationEq, rule, exprsChildren]
  generalize normal : EvalOutcome.normal result = outcome at evaluated
  cases evaluated with
  | unknownNormal _ _ _ unknown _ =>
    simp [UnknownAt, Unsupported, Unmodeled, classify, concreteCall] at unknown
  | unknownFailed => cases normal
  | standardCall _ _ _ _ _ _ actual values arguments output trace actualKnown children ordered standard =>
    have same : actual = binding := Option.some.inj (actualKnown.symm.trans concreteCall)
    subst actual
    have children := typed_arguments_uniform children (.data owner.owner []) (by
      simp only [StandardBinding.sourceTypes, rule, StandardRule.argumentType, exprsChildren, List.length_cons, List.length_nil])
    cases children with
    | cons _ _ _ _ _ value rest ht rt head tail =>
      cases tail with
      | nil =>
        change some [value] = some arguments at ordered
        cases ordered
        have read : env.locals[index]? = some (some value) := by
          generalize childType : (.data owner.owner [] : Ty) = argumentType at head
          cases head <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify]
        refine ⟨value, read, ?_⟩
        exact .apply binding output atBinding standard
  | fixedCallFailed => cases normal
  | fixedCallAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
    rw [← normal] at abrupt; contradiction
  | standardCallAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt =>
    rw [← normal] at abrupt
    contradiction

/-- 同じ成功値への表層の正常射影も、保存した端点の区間に所属する。 -/
theorem range_value_surface_mem {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {owner index result trace}
    (models : Models abstract env) (related : state.Models env)
    (recognized : rangeValueCall abstract input = some (owner, index))
    (evaluated : EvalPartial env input (.normal result) trace) :
    ∃ number : Integer64Value, result = .integer number ∧
      Mem number.toInt (rangeValueInterval abstract state input) := by
  obtain ⟨payload, read, standard⟩ := range_value_standard_of_eval models recognized evaluated
  exact range_value_call_normal_mem models related recognized read standard

/-- 記録に対応する成功値を射影した実際の結果は、失敗や return にならない。
任意の outcome を受け取り、正常性と所属を評価規則から導く局所の補題である。 -/
theorem range_value_origin_evaluated {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {origin : RangeOrigin} {owner index payload outcome}
    (models : Models abstract env) (related : state.Models env)
    (recognized : rangeValueOrigin abstract state input = some origin)
    (call : rangeValueCall abstract input = some (owner, index))
    (read : env.locals[index]? = some (some payload))
    (evaluated : EvalStandardAt env input.key [payload] outcome) :
    ∃ number : Integer64Value, outcome = .normal (.integer number) ∧
      Mem number.toInt (rangeValueInterval abstract state input) := by
  obtain ⟨actualIndex, actualCall, known⟩ := range_value_origin_source recognized
  have same := Prod.mk.inj (Option.some.inj (actualCall.symm.trans call))
  cases same.1
  cases same.2
  obtain ⟨number, payloadEq, _⟩ :=
    range_checked_origin_models related known read
  obtain ⟨_, binding, found, rule⟩ := range_value_call_table call
  have foundConcrete : env.standardAt input.key = some binding := by
    rw [models_standardAt models]; exact found
  have outcomeEq : outcome = .normal (.integer number) := by
    cases evaluated with
    | apply actual result identified standard =>
      have sameBinding := Option.some.inj (identified.symm.trans foundConcrete)
      subst actual
      rw [rule, payloadEq] at standard
      rw [rule, range_value_exact (range_payload_stored ..) standard]
      rfl
  rw [outcomeEq] at evaluated ⊢
  obtain ⟨number, sameValue, inside⟩ := range_value_call_normal_mem models related call read evaluated
  exact ⟨number, congrArg EvalOutcome.normal sameValue, inside⟩

/-- 忘却した由来から狭い区間を復元しない。標準表の同定はそのまま残る。 -/
theorem range_value_forget_top (env : AbstractEnv) (state : RangeState) (input : EvalInput) :
    rangeValueInterval env state.forget input = top := by
  unfold rangeValueInterval rangeValueOrigin
  cases call : rangeValueCall env input with
  | none => rfl
  | some pair =>
    obtain ⟨owner, index⟩ := pair
    have missing : rangeCheckedOrigin state.forget index = none := by
      simp [rangeCheckedOrigin, RangeState.forget, RangeState.empty, BindingScope.idAt]
    simp [missing]

/-- Result の同定は、所有元と成功・失敗の型引数を同時に保つ。 -/
theorem range_result_names_type {env type names}
    (recognized : rangeResultNames env type = some names) :
    type = .data names.result [.data names.owner [], .data names.error []] := by
  unfold rangeResultNames at recognized
  obtain ⟨binding, _, candidate⟩ := List.exists_of_findSome?_eq_some recognized
  split at candidate
  next stored result owner error _ _ =>
    split at candidate
    next shape =>
      cases candidate
      obtain ⟨rfl, rfl, rfl, _⟩ := shape
      rfl
    next => contradiction
  next => contradiction

/-- 具体化すると決めた全表現に、実際に構成子と中身を取り出す導出がある。 -/
theorem range_result_match_view {env value arms names}
    (recognized : rangeResultMatch env value arms = some names) :
    ∃ tag payload, names.ResultView value tag payload := by
  unfold rangeResultMatch at recognized
  change ((rangeResultNames env value.type).bind _) = some names at recognized
  obtain ⟨selected, found, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  split at recognized
  next condition =>
    cases recognized
    have typed := range_result_names_type found
    simp only [Bool.and_eq_true] at condition
    have viewable := condition.1
    cases value with
    | other type ni nb nu =>
      change type = _ at typed
      subst type
      exact ⟨names.ok, .other (.data names.owner []) rfl (by simp) (by simp),
        .otherOk ni nb nu _ rfl⟩
    | con owner types tag args =>
      simp only [ConcreteValue.type, Ty.data.injEq] at typed
      obtain ⟨rfl, rfl⟩ := typed
      cases args with
      | nil => simp [rangeResultViewable] at viewable
      | cons payload rest =>
        cases rest with
        | cons => simp [rangeResultViewable] at viewable
        | nil =>
          simp only [rangeResultViewable] at viewable
          split at viewable
          next same =>
            subst tag
            cases payloadType : payload.type <;> simp only [payloadType] at viewable <;> try contradiction
            rename_i owner types
            cases types with
            | cons => contradiction
            | nil =>
                simp only [beq_iff_eq] at viewable
                subst owner
                exact ⟨names.ok, payload, .ok payload payloadType⟩
          next =>
            split at viewable
            next same =>
              subst tag
              cases payloadType : payload.type <;> simp only [payloadType] at viewable <;> try contradiction
              rename_i error types
              cases types with
              | cons => contradiction
              | nil =>
                simp only [beq_iff_eq] at viewable
                subst error
                exact ⟨names.err, payload, .error payload payloadType⟩
            next => contradiction
    | _ => simp [ConcreteValue.type] at typed
  next => contradiction

/-- 具体化した Result の二つの構成子は、同定した標準表の上で区別される。 -/
theorem range_result_match_distinct {env value arms names}
    (recognized : rangeResultMatch env value arms = some names) : names.ok ≠ names.err := by
  unfold rangeResultMatch at recognized
  change ((rangeResultNames env value.type).bind _) = some names at recognized
  obtain ⟨selected, found, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  split at recognized
  · cases recognized
    unfold rangeResultNames at found
    obtain ⟨binding, _, candidate⟩ := List.exists_of_findSome?_eq_some found
    split at candidate
    next stored result owner error _ _ =>
      split at candidate
      next shape => cases candidate; exact shape.2.2.2
      next => contradiction
    next => contradiction
  · contradiction

/-- Ok の腕を選んだ Result の見方は、同じ成功値の抽出に対応する。
other には固定端点を作らず、既存の OkPayload の未知の規則を使う。 -/
theorem range_result_view_ok_payload {names result tag payload}
    (different : names.ok ≠ names.err)
    (view : RangeNames.ResultView names result tag payload)
    (selected : tag = names.ok) : names.OkPayload result payload := by
  cases view with
  | ok value typed => exact .known (.intro payload typed)
  | error value typed => exact False.elim (different selected.symm)
  | otherOk ni nb nu value typed => exact .other ni nb nu payload typed
  | otherError ni nb nu value typed => exact False.elim (different selected.symm)

/-- 一変数の Ok の選択肢が得る値は、Result が実際に包んだ同じ成功値である。 -/
theorem result_selection_ok {names result tag payload selected qualifier}
    (selection : ResultSelection names result tag payload
      [⟨.con qualifier names.ok [.var], [0]⟩] selected) :
    tag = names.ok ∧ selected = [payload] := by
  obtain ⟨before, alt, after, raw, alts, _, matched, chosen, _⟩ := selection
  have length := congrArg List.length alts
  simp only [List.length_append, List.length_cons, List.length_nil] at length
  have beforeEmpty : before = [] := List.length_eq_zero_iff.mp (by omega)
  have afterEmpty : after = [] := List.length_eq_zero_iff.mp (by omega)
  subst before after
  simp only [List.nil_append, List.cons.injEq, and_true] at alts
  subst alt
  simp only [resultPatternMatch] at matched
  split at matched
  next condition =>
    simp only [Bool.and_eq_true] at condition
    have tagEq : names.ok = tag := by simpa using condition.2
    have rawEq : [payload] = raw := Option.some.inj matched
    subst raw
    simp [selectSlots] at chosen
    exact ⟨tagEq.symm, chosen.symm⟩
  next => contradiction

/-- 実際の照合元の正常評価と Ok の選択から、新しい束縛番号への対応を作る。
由来の保存・腕の選択を中央の Models の新しい仮定にはしない。 -/
theorem range_match_selected_ok_models {abstract : AbstractEnv} {state : RangeState}
    {env : ConcreteEnv} {input : EvalInput} {origin : RangeOrigin} {result payload : ConcreteValue}
    {trace : EvalTrace} {arms : Arms} {tag qualifier selected}
    (models : Models abstract env) (related : state.Models env)
    (recognized : rangeResultOrigin abstract state input = some origin)
    (evaluated : EvalPartial env input (.normal result) trace)
    (matched : rangeResultMatch env result arms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (selection : ResultSelection origin.names result tag payload
      [⟨.con qualifier origin.names.ok [.var], [0]⟩] selected) :
    selected = [payload] ∧
      (rangeBindOk state origin).Models
        { env with locals := selected.reverse.map some ++ env.locals } := by
  have ⟨tagEq, same⟩ := result_selection_ok selection
  have normal := range_source_normal_of_eval models recognized evaluated
  have fromCheck := range_result_source_models models related recognized normal
  have payloadRelated := range_result_view_ok_payload (range_result_match_distinct matched) view tagEq
  refine ⟨same, ?_⟩
  rw [same]
  apply range_extend_models related
  intro known found
  cases found
  exact ⟨rfl, range_ok_payload_models (range_result_match_distinct matched) fromCheck payloadRelated⟩


deriving instance DecidableEq for RangeNames

/-- 検査由来と、評価が使う Result の所有元・全腕の対応を同時に認定する。 -/
def rangeMatchAt (env : AbstractEnv) (input : EvalInput) (arms : Arms) : Option RangeOrigin := do
  let origin ← rangeResultOrigin env env.ranges input
  let names ← rangeResultNames (rangeTables env)
    (.data origin.names.result [.data origin.names.owner [], .data origin.names.error []])
  if names = origin.names ∧ rangeResultArms names arms = true then some origin else none

/-- 腕の通常位置は未知で作り、単独の Ok(var) にだけ同じ成功値を保存する。 -/
def baseResultArmEnv (env : AbstractEnv) (input : EvalInput)
    (alts : List Alternative) : AbstractEnv :=
  let count := matchArmBinders alts
  let initial : AbstractEnv := { env with
    locals := List.replicate count (.unknown none) ++ env.locals
    ranges := env.ranges.extendUnknown count }
  match alts with
  | [⟨pattern, [0]⟩] =>
    match rangeMatchOk env env.ranges input pattern with
    | some ranges => { initial with ranges := ranges }
    | none => initial
  | _ => initial

/-- 戻り値型の注記を替えても、構文・出現と由来の認定は同じである。 -/
theorem range_result_origin_type (env : AbstractEnv) (state : RangeState)
    (input : EvalInput) (type : Ty) :
    rangeResultOrigin env state { input with type := type } = rangeResultOrigin env state input := by
  cases input with
  | mk source type key => cases source <;> rfl

/-- Result の入口認定も戻り値型の注記には依存しない。 -/
theorem range_match_at_type (env : AbstractEnv) (input : EvalInput) (type : Ty) (arms : Arms) :
    rangeMatchAt env { input with type := type } arms = rangeMatchAt env input arms := by
  simp only [rangeMatchAt, range_result_origin_type]

/-- 認定した Result の入口が参照する、直接または保存された同じ由来。 -/
theorem range_match_at_origin {env input arms origin}
    (recognized : rangeMatchAt env input arms = some origin) :
    rangeResultOrigin env env.ranges input = some origin := by
  unfold rangeMatchAt at recognized
  obtain ⟨selected, found, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  obtain ⟨names, _, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  split at recognized
  · cases recognized; exact found
  · contradiction

/-- 検査の正常な Result の型は、解決済みの所有元と型引数を保つ。 -/
theorem range_result_models_type {origin : RangeOrigin} {value : ConcreteValue}
    (related : origin.ResultModels value) :
    value.type = .data origin.names.result [.data origin.names.owner [], .data origin.names.error []] := by
  obtain ⟨number, evaluated⟩ := related
  have typed := standard_result_typed (EvalStandard.rangeCheck origin.names origin.checkKey
    origin.minimum origin.maximum number)
  rw [evaluated] at typed
  exact typed

/-- 固定端点の検査が返した Result は、具体規則が扱う構造を持つ。 -/
theorem range_result_models_viewable {origin : RangeOrigin} {value : ConcreteValue}
    (different : origin.names.ok ≠ origin.names.err)
    (related : origin.ResultModels value) : rangeResultViewable origin.names value = true := by
  obtain ⟨number, evaluated⟩ := related
  cases made : Checked.Range.make origin.minimum.toInt origin.maximum.toInt number.toInt with
  | ok checked =>
    simp only [rangeCheck, made, StandardRule.finish, EvalOutcome.normal.injEq] at evaluated
    subst value
    simp [rangeResultViewable, ConcreteValue.type, rangePayload, RangeNames.record]
  | error error =>
    cases error <;>
      simp only [rangeCheck, made, StandardRule.finish, EvalOutcome.normal.injEq] at evaluated <;>
      subst value <;> simp [rangeResultViewable, ConcreteValue.type, different.symm]

/-- 解析で認定した由来の正常値は、評価側でも同じ Result の規則を選ぶ。 -/
theorem range_match_at_evaluated {abstract concrete input arms origin value trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (recognized : rangeMatchAt abstract input arms = some origin)
    (evaluated : EvalPartial concrete input (.normal value) trace) :
    rangeResultMatch concrete value arms = some origin.names := by
  have fromCheck := range_result_source_models models related
    (range_match_at_origin recognized) (range_source_normal_of_eval models
      (range_match_at_origin recognized) evaluated)
  unfold rangeMatchAt at recognized
  obtain ⟨selected, atOrigin, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  obtain ⟨names, atNames, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  split at recognized
  next condition =>
    cases recognized
    obtain ⟨rfl, armsKnown⟩ := condition
    have atConcrete : rangeResultNames concrete
        (.data origin.names.result [.data origin.names.owner [], .data origin.names.error []]) =
        some origin.names := by
      simpa only [rangeResultNames, rangeTables, models.2.1] using atNames
    have different : origin.names.ok ≠ origin.names.err := by
      unfold rangeResultNames at atConcrete
      obtain ⟨binding, _, candidate⟩ := List.exists_of_findSome?_eq_some atConcrete
      split at candidate
      next names result owner error _ _ =>
        split at candidate
        next shape => cases candidate; exact shape.2.2.2
        next => contradiction
      next => contradiction
    simp [rangeResultMatch, range_result_models_type fromCheck, atConcrete,
      range_result_models_viewable different fromCheck, armsKnown]
  next => contradiction

/-- 認定した全腕の先頭を除いても、残る腕は同じ由来で認定される。 -/
theorem range_match_at_tail {env input alts guard body rest origin}
    (recognized : rangeMatchAt env input (.cons alts guard body rest) = some origin) :
    rangeMatchAt env input rest = some origin := by
  have originAt := range_match_at_origin recognized
  unfold rangeMatchAt at recognized ⊢
  rw [originAt] at recognized ⊢
  dsimp only [bind, Option.bind] at recognized ⊢
  obtain ⟨names, atNames, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  rw [atNames]
  dsimp only [bind, Option.bind]
  split at recognized
  next condition =>
    cases recognized
    have allArms := condition.2
    simp only [rangeResultArms, Bool.and_eq_true] at allArms
    have tail : rangeResultArms origin.names rest = true := by
      simpa only [condition.1] using allArms.2
    simp only [condition.1, tail, and_self, ↓reduceIte]
  next => contradiction

/-- 検査由来から認定した正常値は整数の照合規則とは重ならない。 -/
theorem range_match_at_not_integer {abstract concrete input arms origin kind integer trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (recognized : rangeMatchAt abstract input arms = some origin)
    (evaluated : EvalPartial concrete input (.normal (.ofInteger kind integer)) trace) : False := by
  have fromCheck := range_result_source_models models related
    (range_match_at_origin recognized) (range_source_normal_of_eval models
      (range_match_at_origin recognized) evaluated)
  have typed := range_result_models_type fromCheck
  cases kind <;> contradiction

/-- 整数の正常評価から、Result 専用の入口は認定されない。 -/
theorem range_match_at_integer_none {abstract concrete input arms kind integer trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (evaluated : EvalPartial concrete input (.normal (.ofInteger kind integer)) trace) :
    rangeMatchAt abstract { input with type := .base .unit } arms = none := by
  cases known : rangeMatchAt abstract { input with type := .base .unit } arms with
  | none => rfl
  | some origin =>
    have actual : rangeMatchAt abstract input arms = some origin := by
      simpa only [range_match_at_type] using known
    exact False.elim (range_match_at_not_integer models related actual evaluated)

/-- 評価が未知の Result とする値を、解析で具体的な腕へ狭めない。 -/
theorem range_match_at_none_of_unmodeled {abstract concrete input arms result trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (evaluated : EvalPartial concrete input (.normal result) trace)
    (unmodeled : rangeResultMatch concrete result arms = none) :
    rangeMatchAt abstract { input with type := .base .unit } arms = none := by
  cases known : rangeMatchAt abstract { input with type := .base .unit } arms with
  | none => rfl
  | some origin =>
    have actual : rangeMatchAt abstract input arms = some origin := by
      simpa only [range_match_at_type] using known
    have matched := range_match_at_evaluated models related actual evaluated
    simp only [unmodeled] at matched
    contradiction

/-- 解析で認定した由来と評価が使う Result の名前は同じである。 -/
theorem range_match_at_names {abstract concrete input arms origin result names trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (recognized : rangeMatchAt abstract { input with type := .base .unit } arms = some origin)
    (evaluated : EvalPartial concrete input (.normal result) trace)
    (matched : rangeResultMatch concrete result arms = some names) : names = origin.names := by
  have actual : rangeMatchAt abstract input arms = some origin := by
    simpa only [range_match_at_type] using recognized
  exact Option.some.inj (matched.symm.trans (range_match_at_evaluated models related actual evaluated))

/-- 腕の補助環境も、照合元の型注記には依存しない。 -/
theorem baseResultArmEnv_type (env : AbstractEnv) (input : EvalInput) (type : Ty)
    (alts : List Alternative) :
    baseResultArmEnv env { input with type := type } alts = baseResultArmEnv env input alts := by
  simp only [baseResultArmEnv, rangeMatchOk, range_result_origin_type]

/-- Result の選択が増やす位置数は、腕の共通の slots の数である。 -/
theorem result_selection_length {names result tag payload alts selected}
    (selection : ResultSelection names result tag payload alts selected) :
    selected.length = matchArmBinders alts := by
  obtain ⟨_, _, _, _, _, _, _, chosen, count⟩ := selection
  exact (selectSlots_length chosen).trans count

/-- Result の腕の型の対応は、成功由来を参照せず未知位置だけで構成する。 -/
theorem baseResultArmEnv_models {abstract concrete input names result tag payload alts selected}
    (models : Models abstract concrete)
    (selection : ResultSelection names result tag payload alts selected) :
    Models (baseResultArmEnv abstract input alts)
      { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  have unknowns : LocalsModels (List.replicate selected.length (.unknown none))
      (selected.reverse.map some) := by
    have mapped : ∀ values : List ConcreteValue,
        LocalsModels (List.replicate values.length (.unknown none)) (values.map some) := by
      intro values
      induction values with
      | nil => exact .nil
      | cons value rest ih => exact .cons (by simp [SlotModels]) ih
    simpa only [List.length_reverse] using mapped selected.reverse
  have length := result_selection_length selection
  unfold baseResultArmEnv
  dsimp only
  split <;> try split
  all_goals exact ⟨by simpa only [← length] using unknowns.append models.1, models.2⟩

/-- 認定した Ok のパターンは成功構成子の一変数に限る。 -/
theorem range_ok_pattern_shape {names : RangeNames} {pattern : Pattern}
    (known : rangeOkPattern names pattern = true) :
    ∃ qualifier, pattern = .con qualifier names.ok [.var] := by
  cases pattern <;> simp only [rangeOkPattern] at known <;> try contradiction
  rename_i qualifier name patterns
  cases patterns with
  | nil => contradiction
  | cons first rest =>
    cases first <;> try contradiction
    cases rest with
    | cons => contradiction
    | nil =>
      change ((qualifier.isNone || qualifier == some names.result) && name == names.ok) = true at known
      simp only [Bool.and_eq_true] at known
      have same : name = names.ok := by simpa using known.2
      subst name
      exact ⟨qualifier, rfl⟩

/-- 単独の Ok(var) 以外では、新位置を全て未知にして元の対応だけを保つ。 -/
theorem baseResultArmEnv_ranges {abstract concrete input arms origin result tag payload alts selected trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (recognized : rangeMatchAt abstract input arms = some origin)
    (evaluated : EvalPartial concrete input (.normal result) trace)
    (matched : rangeResultMatch concrete result arms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (selection : ResultSelection origin.names result tag payload alts selected) :
    (baseResultArmEnv abstract input alts).ranges.Models
      { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  have originAt := range_match_at_origin recognized
  have length := result_selection_length selection
  unfold baseResultArmEnv
  dsimp only
  split
  next _ pattern =>
    split
    next ranges found =>
      have patKnown : rangeOkPattern origin.names pattern = true := by
        unfold rangeMatchOk at found
        rw [originAt] at found
        dsimp only [bind, Option.bind] at found
        split at found
        · assumption
        · contradiction
      obtain ⟨qualifier, patternEq⟩ := range_ok_pattern_shape patKnown
      have singleton : ResultSelection origin.names result tag payload
          [⟨.con qualifier origin.names.ok [.var], [0]⟩] selected := by
        simpa only [patternEq] using selection
      have selectedOk := result_selection_ok singleton
      rw [selectedOk.2]
      apply range_match_ok_models models related found
      intro known knownAt
      have same : known = origin := Option.some.inj (knownAt.symm.trans originAt)
      subst known
      exact ⟨range_source_normal_of_eval models originAt evaluated,
        range_result_view_ok_payload (range_result_match_distinct matched) view selectedOk.1,
        range_result_match_distinct matched⟩
    next =>
      simpa only [← length, List.length_map, List.length_reverse] using
        range_extend_unknowns_models related (selected.reverse.map some)
  next =>
    simpa only [← length, List.length_map, List.length_reverse] using
      range_extend_unknowns_models related (selected.reverse.map some)

-- 一つの成功値にだけ [0,10] を付ける。未知の位置・別名・間接呼び出し・
-- 偽の宣言・別の所有元・合流の忘却は同じ表で型内 Top に退くことを確かめる。
example :
    let names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Range.CheckedInteger.record", "Std.Result.Result", "Std.Range.Error",
      "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
    let key : OperationKey := ⟨"Example.project", 3⟩
    let origin : RangeOrigin := ⟨names, ⟨"Example.project", 0⟩, ⟨0, by decide⟩, ⟨10, by decide⟩⟩
    let env : AbstractEnv := ⟨[], [⟨"Std.Range.value", .rangeValue names.record, []⟩],
      (fun k => if k = key then some "Std.Range.value" else none), .empty ⟨[], 0⟩⟩
    let state := rangeBindOk (RangeState.empty ⟨[], 0⟩) origin
    let call : EvalInput := ⟨.call (.funName "Std.Range.value" [] []) [some "checked"] [0]
      (.cons (.local 0) .nil), .base .integer, key⟩
    let otherOwner := { env with standards := [⟨"Std.Range.value", .rangeValue ⟨"User.CheckedInteger", "User.record"⟩, []⟩] }
    let snapshot := fun (range : Interval) => match range with
      | .bottom => none
      | .closed lo hi _ => some (lo, hi)
    (snapshot (rangeValueInterval env state call),
      snapshot (rangeValueInterval env (state.extend none) {call with source :=
        (.call (.funName "Std.Range.value" [] []) [none] [0] (.cons (.local 1) .nil))})) =
        (some (0, 10), some (0, 10)) ∧
    ([rangeValueInterval env state.forget call,
      rangeValueInterval env (state.extend none) call,
      rangeValueInterval otherOwner state call,
      rangeValueInterval env state {call with key := ⟨"Example.project", 9⟩},
      rangeValueInterval env state {call with source :=
        (.call (.funName "User.value" [] []) [none] [0] (.cons (.local 0) .nil))},
      rangeValueInterval env state {call with source :=
        (.call (.local 0) [none] [0] (.cons (.local 0) .nil))},
      rangeValueInterval env state {call with source :=
        (.call (.funName "Std.Range.value" [] []) [none] [0] (.cons (.paren (.local 0)) .nil))},
      rangeValueInterval env state {call with source :=
        (.call (.funName "Std.Range.value" [] []) [none] [1] (.cons (.local 0) .nil))},
      rangeValueInterval env state {call with source :=
        (.call (.funName "Std.Range.value" [] []) [] [0] (.cons (.local 0) .nil))}].map snapshot) =
      List.replicate 9 (some (-9223372036854775808, 9223372036854775807)) := by
  dsimp only
  constructor <;> decide +kernel

-- 固定端点を持つ標準呼び出しから、一度の保存と Ok の束縛を経て同じ成功値を読む。
-- source 順は value, maximum, minimum とし、契約の位置と取り違える退行も検出する。
example :
    let names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Range.CheckedInteger.record", "Std.Result.Result", "Std.Range.Error",
      "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
    let key : OperationKey := ⟨"Example.run", 7⟩
    let env : AbstractEnv := ⟨[.integer top], [⟨"Std.Range.checkInteger", .rangeCheck names, []⟩],
      (fun k => if k = key then some "Std.Range.checkInteger" else none), .empty ⟨[], 0⟩⟩
    let call : EvalInput := ⟨.call (.funName "Std.Range.checkInteger" [] [])
      [some "value", some "maximum", some "minimum"] [2, 1, 0]
      (.cons (.local 0) (.cons (.literal (.integer ⟨10, by decide⟩))
        (.cons (.literal (.integer ⟨0, by decide⟩)) .nil))),
      .data names.result [.data names.owner [], .data names.error []], key⟩
    let start := RangeState.empty ⟨[3], 4⟩
    let saved := rangeSaveResult env start call
    let savedEnv := extend env (topSlot (some call.type))
    let localResult : EvalInput := ⟨.local 0, call.type, ⟨"Example.run", 20⟩⟩
    let ok := Pattern.con (some names.result) names.ok [.var]
    let snapshot := fun (inner : RangeState) (i : Nat) =>
      (rangeCheckedOrigin inner i).map fun o =>
        (o.checkKey.surfacePreorder, o.minimum.toInt, o.maximum.toInt)
    ((rangeMatchOk env start call ok).map fun inner => snapshot inner 0) =
        some (some (7, 0, 10)) ∧
      ((rangeMatchOk savedEnv saved localResult ok).map fun inner =>
        (snapshot inner 0, snapshot (inner.extend none) 1,
          (rangeCheckedOrigin (inner.extend none) 0).isSome, inner.scope.idAt 0)) =
        some (some (7, 0, 10), some (7, 0, 10), false, some 5) ∧
      (rangeResultOrigin savedEnv (rangeSaveResult savedEnv saved localResult) localResult).isNone ∧
      (rangeMatchOk savedEnv saved localResult (.con (some names.result) names.err [.var])).isNone ∧
      (rangeMatchOk savedEnv saved localResult (.con (some names.result) names.ok [.wild])).isNone := by
  dsimp only
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> decide +kernel

-- 同じデータ型だけでは成功由来にならない。動的端点・偽名・再包装・境界・合流は未知。
example :
    let names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Range.CheckedInteger.record", "Std.Result.Result", "Std.Range.Error",
      "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
    let key : OperationKey := ⟨"Example.run", 7⟩
    let env : AbstractEnv := ⟨[.integer top, .integer top],
      [⟨"Std.Range.checkInteger", .rangeCheck names, []⟩],
      (fun _ => some "Std.Range.checkInteger"), .empty ⟨[], 0⟩⟩
    let dynamic : EvalInput := ⟨.call (.funName "Std.Range.checkInteger" [] [])
      [none, none, none] [0, 1, 2]
      (.cons (.local 0) (.cons (.literal (.integer ⟨10, by decide⟩)) (.cons (.local 1) .nil))),
      .data names.result [.data names.owner [], .data names.error []], key⟩
    let fake : EvalInput := { dynamic with source := (.call (.funName "User.checkInteger" [] [])
      [none, none, none] [0, 1, 2]
      (.cons (.literal (.integer ⟨0, by decide⟩))
        (.cons (.literal (.integer ⟨10, by decide⟩)) (.cons (.local 0) .nil)))) }
    let origin : RangeOrigin := ⟨names, key, ⟨0, by decide⟩, ⟨10, by decide⟩⟩
    let state := rangeBindOk (RangeState.empty ⟨[1, 0], 2⟩) origin
    let checkedEnv := extend env (topSlot (some (.data names.owner [])))
    let wrapped : EvalInput := { dynamic with source := (.conCall names.ok
      [.data names.owner [], .data names.error []] (.cons (.local 0) .nil)) }
    (rangeCallOrigin env dynamic).isNone ∧ (rangeCallOrigin env fake).isNone ∧
      (rangeResultOrigin checkedEnv state wrapped).isNone ∧
      (rangeCheckedOrigin state 0).isSome ∧
      (rangeCheckedOrigin state.forget 0).isNone ∧
      (rangeCheckedOrigin (RangeState.empty ⟨[0], 1⟩) 0).isNone ∧
      (rangeCheckedOrigin (state.extend none) 0).isNone := by
  dsimp only
  decide +kernel

-- other の Result にも Ok の正常な成功値を取り出す導出を作る。
-- その値は元の検査の記録を持たず、射影も任意の Integer64 を許す。
example (names : RangeNames) (key : OperationKey) (number : Integer64Value) :
    let result : ConcreteValue := .other
      (.data names.result [.data names.owner [], .data names.error []]) rfl (by simp) (by simp)
    let payload : ConcreteValue := .other (.data names.owner []) rfl (by simp) (by simp)
    names.OkPayload result payload ∧
      EvalStandard (.rangeValue names.record) key [payload] (.normal (.integer number)) ∧
      ∀ origin : RangeOrigin, ¬ origin.ResultModels result := by
  exact ⟨.other _ _ _ _ rfl, range_other_possible names.record key number,
    fun origin => range_result_not_other origin _ _ _ _⟩

-- 実際の成功値 5 と三欄を使い、Result の保存・Ok の束縛・直接射影を合成する。
-- 端点の記録だけでなく、同じ具体値の正常結果と全射影結果への所属を確かめる。
example (names : RangeNames) (key : OperationKey) (different : names.ok ≠ names.err) :
    let origin : RangeOrigin := ⟨names, key, ⟨0, by decide⟩, ⟨10, by decide⟩⟩
    let payload := rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
    let result := ConcreteValue.con names.result [.data names.owner [], .data names.error []]
      names.ok [payload]
    let empty : RangeState := .empty ⟨[], 0⟩
    let saved := empty.extend (some (.result origin))
    let env : ConcreteEnv := ⟨[], [⟨"Std.Range.value", .rangeValue names.record, []⟩],
      fun _ => some "Std.Range.value"⟩
    let concrete := {env with locals := [some payload, some result]}
    let abstract : AbstractEnv := ⟨[.unknown (some (.data names.owner [])),
      .unknown (some (.data names.result [.data names.owner [], .data names.error []]))],
      env.standards, env.apiAt, .empty ⟨[], 0⟩⟩
    let projection : EvalInput := ⟨.call (.funName "Std.Range.value" [] []) [none] [0]
      (.cons (.local 0) .nil), .base .integer, key⟩
    saved.Models {env with locals := [some result]} ∧
      (rangeBindOk saved origin).Models concrete ∧ origin.CheckedModels payload ∧
      EvalStandardAt concrete key [payload] (.normal (.integer ⟨5, by decide⟩)) ∧
      ∀ outcome, EvalStandardAt concrete key [payload] outcome →
        ∃ number, outcome = .normal (.integer number) ∧
          Mem number.toInt (rangeValueInterval abstract (rangeBindOk saved origin) projection) := by
  dsimp only
  let origin : RangeOrigin := ⟨names, key, ⟨0, by decide⟩, ⟨10, by decide⟩⟩
  let payload := rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
  let result := ConcreteValue.con names.result [.data names.owner [], .data names.error []]
    names.ok [payload]
  have success : rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩ =
      .normal payload := by
    simp [rangeCheck, Checked.Range.make, Checked.Range.InRange, Integer64Value.toInt,
      payload]
  have fromCheck : origin.ResultModels result := ⟨⟨5, by decide⟩, by
    change (StandardRule.rangeCheck names).finish
      (rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩) = .normal result
    rw [success]; rfl⟩
  have known : names.IsOk result payload := .intro _ rfl
  let env : ConcreteEnv := ⟨[], [⟨"Std.Range.value", .rangeValue names.record, []⟩],
    fun _ => some "Std.Range.value"⟩
  let concrete := {env with locals := [some payload, some result]}
  let abstract : AbstractEnv := ⟨[.unknown (some (.data names.owner [])),
    .unknown (some (.data names.result [.data names.owner [], .data names.error []]))],
    env.standards, env.apiAt, .empty ⟨[], 0⟩⟩
  let projection : EvalInput := ⟨.call (.funName "Std.Range.value" [] []) [none] [0]
    (.cons (.local 0) .nil), .base .integer, key⟩
  have saved := range_extend_models (range_empty_models ⟨[], 0⟩ env)
    (value := result) (fact := some (.result origin)) (by
      intro fact same; cases same; exact fromCheck)
  have checkedModels : origin.CheckedModels payload :=
    range_result_ok_models different fromCheck known
  have bound : (rangeBindOk ((RangeState.empty ⟨[], 0⟩).extend
      (some (.result origin))) origin).Models concrete := by
    exact range_bind_ok_models different saved fromCheck known
  have models : Models abstract concrete := by
    refine ⟨.cons ?_ (.cons ?_ .nil), rfl, rfl⟩
    all_goals intro type same; cases same; rfl
  have projected : EvalStandardAt concrete key [payload] (.normal (.integer ⟨5, by decide⟩)) := by
    exact .apply ⟨"Std.Range.value", .rangeValue names.record, []⟩ _ rfl
      (.rangeValue names.record key payload ⟨5, by decide⟩ (range_payload_stored ..))
  refine ⟨saved, bound, checkedModels, projected, ?_⟩
  intro outcome evaluated
  apply range_value_origin_evaluated (input := projection) (origin := origin) models bound
    (by simp [rangeValueOrigin, rangeValueCall, abstract, env, projection,
      AbstractEnv.standardAt, rangeCheckedOrigin, rangeBindOk, RangeState.extend,
      RangeState.empty, BindingScope.fresh, BindingScope.idAt, origin])
    (owner := names.record) (index := 0) (by rfl) (by rfl) evaluated

-- 境界の early return は未知の失敗へ近似し、正常結果は型内の全値を許す。
-- returned の中身は NormalSoundness の量化対象ではない。
example (env : ConcreteEnv) (key : OperationKey) (ok err : ConName) (source : Expr)
    (number : Integer64Value) :
    EvalPartial env ⟨.tryResult [.base .integer, .base .unit] ok err source,
      .base .integer, key⟩ (.normal (.integer number)) [] ∧
    EvalPartial env ⟨.tryResult [.base .integer, .base .unit] ok err source,
      .base .integer, key⟩ (.failed .unknown) [] := by
  exact ⟨.unknownNormal _ _ _ (Or.inl (Or.inl rfl)) rfl, .unknownFailed _ _ (Or.inl (Or.inl rfl))⟩

end Benitoite.Interval
