import Benitoite.Exchange.Convert
import Benitoite.Interval.BudgetWhole
import Benitoite.Interval.EvalClosed

/-!
# interval-corpus 初版1の読者

Surface 14の読者と変換を再利用するが、旧corpus・sidecarの入口は変更しない。
受理済みprofileはbase/flow/width/range/domain。標準表は明示した宣言と規則を照合する。
交換の検証は解析予算の外側で行う。番号の全列挙を解析の事前走査には使わない
（設計書07-04「区間解析の独立交換の読者」）。
-/
namespace Benitoite.Interval.Exchange
open Lean
open Benitoite.Release Benitoite.Surface

/- Json.parseは同じ欄の後の値を残す。重複を消す前に拒否するため、文字列と数値の
トークンは既存のJSON読者を使い、容器の読み取りだけをここで定める。 -/
namespace UniqueJson
open Std.Internal.Parsec Std.Internal.Parsec.String

mutual
  private partial def value : Parser Json := do
    let c ← peek!
    if c == '{' then
      skip; ws
      if (← peek!) == '}' then
        skip; ws
        return Json.mkObj []
      object []
    else if c == '[' then
      skip; ws
      if (← peek!) == ']' then
        skip; ws
        return .arr #[]
      array #[]
    else
      Json.Parser.anyCore

  private partial def object (fields : List (String × Json)) : Parser Json := do
    Json.Parser.lookahead (· == '"') "object key"
    skip
    let key ← Json.Parser.str
    if fields.any (·.1 == key) then fail s!"duplicate JSON field: {key}"
    ws
    Json.Parser.lookahead (· == ':') ":"
    skip; ws
    let item ← value
    let fields := (key, item) :: fields
    let c ← any
    if c == '}' then
      ws
      return Json.mkObj fields.reverse
    else if c == ',' then
      ws
      object fields
    else fail "expected ',' or '}'"

  private partial def array (items : Array Json) : Parser Json := do
    let item ← value
    let c ← any
    if c == ']' then
      ws
      return .arr (items.push item)
    else if c == ',' then
      ws
      array (items.push item)
    else fail "expected ',' or ']'"
end

/-- 生のJSONのすべての容器で重複欄を検査する入口。 -/
def parse (raw : String) : Except String Json :=
  (do ws; let j ← value; eof; pure j : Parser Json).run raw
end UniqueJson

/-- 必須欄を補完せず、すべての階層で余剰欄を拒否する。 -/
private def fields (label : String) (keys : List String) (j : Json) : Except String Unit := do
  let obj ← j.getObj?
  for (key, _) in obj.toArray do
    if !keys.contains key then throw s!"unexpected {label} field: {key}"
  for key in keys do
    if !obj.contains key then throw s!"missing {label} field: {key}"

/-- 後続段で追加した任意欄も、未知欄の許可には使わない。 -/
private def fieldsOptional (label : String) (required optional : List String) (j : Json) : Except String Unit := do
  let obj ← j.getObj?
  for (key, _) in obj.toArray do
    if !(required ++ optional).contains key then throw s!"unexpected {label} field: {key}"
  for key in required do
    if !obj.contains key then throw s!"missing {label} field: {key}"

/-- Surfaceの復号器が読まなかった欄・曖昧な構成子も、深い位置で拒否する。 -/
private def surface [FromJson α] [ToJson α] (j : Json) : Except String α := do
  -- 埋め込みの Surface は版14（範囲のない旧版）か版15である。版14は `decodeCorpus` が範囲の欄を全て拒否してあり、
  -- 欠けた欄に明示の Top と空の範囲の列を加えてから読む。版15は欠けた欄がないことを `decodeCorpus` が確かめてあり、
  -- この変換は何も変えない（`Exchange.legacyRangesMissing`。設計書 07-04「交換の形式の版」）。
  let j := Benitoite.Exchange.legacyRangesMissing j
  let value : α ← fromJson? j
  if toJson value != j then throw "noncanonical Surface fields or constructor"
  pure value

/-- 十進文字列を数学上のNatで読む。符号・指数・小数・空白・先頭0を認めない。 -/
def decimalNat (j : Json) : Except String Nat := do
  let s ← j.getStr?
  let some n := s.toNat? | throw "expected decimal natural string"
  if toString n != s then throw "noncanonical decimal natural string"
  pure n

/-- 端点をFloatやホストの機械語整数へ変換しない。負の0も拒否する。 -/
def decimalInt (j : Json) : Except String Int := do
  let s ← j.getStr?
  let some n := s.toInt? | throw "expected decimal integer string"
  if toString n != s then throw "noncanonical decimal integer string"
  pure n

/-- 定義名と正規の十進番号の二要素配列を読む。 -/
def readKey (j : Json) : Except String OperationKey := do
  let pair ← j.getArr?
  if pair.size != 2 then throw "key must be [definition, decimal preorder]"
  pure ⟨← pair[0]!.getStr?, ← decimalNat pair[1]!⟩

/-- 指定した整数型の閉区間・bottom・topを読む。 -/
def readInterval (j : Json) (kind : IntKind := .integer64) : Except String (Interval kind) := do
  if j == toJson "bottom" then return .bottom
  if j == toJson "top" then return top kind
  fields "interval" ["closed"] j
  let pair ← (← j.getObjVal? "closed").getArr?
  if pair.size != 2 then throw "closed interval must have two endpoints"
  let lo ← decimalInt pair[0]!
  let hi ← decimalInt pair[1]!
  if valid : kind.min ≤ lo ∧ lo ≤ hi ∧ hi ≤ kind.max then
    return .closed lo hi valid
  else throw "invalid integer interval endpoints"

private def unique [BEq α] (label : String) (xs : List α) : Except String Unit := do
  if xs.eraseDups.length != xs.length then throw s!"duplicate {label}"

private def readType (j : Json) : Except String Ty := do
  let ty : Benitoite.Exchange.Ty ← surface j
  ty.toRelease

private def readCap (j : Json) : Except String Budget.Cap := do
  fields "cap" ["operations", "items"] j
  pure ⟨← decimalNat (← j.getObjVal? "operations"), ← decimalNat (← j.getObjVal? "items")⟩

/-- 本体と全体の二資源の上限を読む。 -/
def readLimits (j : Json) : Except String Budget.Limits := do
  fields "limits" ["body", "whole"] j
  pure ⟨← readCap (← j.getObjVal? "body"), ← readCap (← j.getObjVal? "whole")⟩

/-- 実消費と最大保持の整合する予算状態を読む。 -/
def readState (j : Json) : Except String Budget.State := do
  fields "state" ["body", "whole"] j
  let b ← j.getObjVal? "body"
  fields "body state" ["operations", "temporary", "saved", "peak"] b
  let w ← j.getObjVal? "whole"
  fields "whole state" ["operations", "saved", "peak"] w
  let body : Budget.BodyState := ⟨← decimalNat (← b.getObjVal? "operations"),
    ← decimalNat (← b.getObjVal? "temporary"), ← decimalNat (← b.getObjVal? "saved"),
    ← decimalNat (← b.getObjVal? "peak")⟩
  let whole : Budget.WholeState := ⟨← decimalNat (← w.getObjVal? "operations"),
    ← decimalNat (← w.getObjVal? "saved"), ← decimalNat (← w.getObjVal? "peak")⟩
  if body.peak < body.temporary + body.saved || whole.peak < whole.saved + body.temporary + body.saved ||
      whole.operations < body.operations then
    throw "invalid budget state"
  pure ⟨body, whole⟩

private def readHalt (j : Json) : Except String BudgetAnalysis.Halt := do
  if j == toJson "depth" then return .depth
  fields "halt" ["kind", "scope", "resource"] j
  let scope ← match ← j.getObjValAs? String "scope" with
    | "body" => pure Budget.Scope.body | "whole" => pure .whole
    | _ => throw "unknown budget scope"
  let resource ← match ← j.getObjValAs? String "resource" with
    | "operations" => pure Budget.Resource.operations | "items" => pure .items
    | _ => throw "unknown budget resource"
  match ← j.getObjValAs? String "kind" with
  | "exceeded" => pure (.budget (.exceeded ⟨scope, resource⟩))
  | "unidentified" => pure (.budget (.unidentified ⟨scope, resource⟩))
  | _ => throw "unknown halt constructor"

private def readCoverage (j : Json) : Except String BudgetAnalysis.Coverage := do
  if j == toJson "complete" then return .complete
  if j == toJson "unsupported" then return .unsupported
  fields "coverage" ["stopped"] j
  return .stopped (← readHalt (← j.getObjVal? "stopped"))

/-- 幅の表は六種を必須とし、Integer64 は既存の integer 欄に置く。 -/
def widthKinds : List IntKind := [.integer8, .integer16, .integer32,
  .unsignedInteger16, .unsignedInteger32, .unsignedInteger64]

private def kindName (kind : IntKind) : String := match kind with
  | .integer8 => "Integer8" | .integer16 => "Integer16" | .integer32 => "Integer32"
  | .integer64 => "Integer" | .unsignedInteger16 => "UnsignedInteger16"
  | .unsignedInteger32 => "UnsignedInteger32" | .unsignedInteger64 => "UnsignedInteger64"

private def readOperation (standards : List StandardBinding) (j : Json) : Except String TargetOperation := do
  if (j.getObjVal? "standard").isOk then
    fields "operation" ["standard"] j
    let name ← j.getObjValAs? String "standard"
    let some binding := standards.find? (·.declaration == name) | throw "unknown standard operation"
    return .standard binding
  if (j.getObjVal? "neg").isOk then
    fields "operation" ["neg"] j
    let type ← readType (← j.getObjVal? "neg")
    if (IntKind.ofType type).isNone then throw "warning requires integer type"
    return .neg type
  fields "operation" ["binary", "type"] j
  let op ← Benitoite.Exchange.binOp (← j.getObjValAs? String "binary")
  let type ← readType (← j.getObjVal? "type")
  if (IntKind.ofType type).isNone then throw "warning requires integer type"
  return .binary op type

private def readWarning (standards : List StandardBinding) (j : Json) : Except String IntervalWarning := do
  fields "warning" ["key", "operation", "cause"] j
  let operation ← readOperation standards (← j.getObjVal? "operation")
  let cause ← match ← j.getObjValAs? String "cause" with
    | "zeroDivisor" => pure WarningCause.zeroDivisor | "overflow" => pure .overflow
    | "outsideDomain" => pure .outsideDomain | _ => throw "unknown warning cause"
  pure ⟨← readKey (← j.getObjVal? "key"), operation, cause⟩

/-- 正常値の直積・失敗可能性・候補・停止・実消費。解析結果から期待値を作らない。 -/
structure Expected where
  integer : Interval
  boolean : Bool × Bool
  other : Bool
  mayFail : Bool
  warnings : List IntervalWarning
  coverage : BudgetAnalysis.Coverage
  after : Budget.State
  independent : List Json := []
  context : Option Json := none
  widths : Option Json := none
  nonIntegerOther : Option Bool := none

/-- 正常範囲の期待と、解析を始めなかったことの期待を区別する。 -/
inductive BodyExpected where
  | analyzed (value : Expected)
  | notAnalyzed (stop : Json)

/-- 正常範囲の正規な交換表現。型の全域は必ずtopに揃える。 -/
def intervalJson {kind : IntKind} (range : Interval kind) : Json := match range with
  | .bottom => toJson "bottom"
  | .closed lo hi _ => if range == top kind then toJson "top" else
      Json.mkObj [("closed", toJson [toString lo, toString hi])]

def keyJson (key : OperationKey) : Json := toJson [key.definition, toString key.surfacePreorder]

def haltJson : BudgetAnalysis.Halt → Json
  | .depth => toJson "depth"
  | .budget reason =>
    let (kind, failure) := match reason with
      | .exceeded f => ("exceeded", f) | .unidentified f => ("unidentified", f)
    Json.mkObj [("kind", toJson kind),
      ("scope", toJson (match failure.scope with | .body => "body" | .whole => "whole")),
      ("resource", toJson (match failure.resource with | .operations => "operations" | .items => "items"))]

def coverageJson : BudgetAnalysis.Coverage → Json
  | .complete => toJson "complete" | .unsupported => toJson "unsupported"
  | .stopped reason => Json.mkObj [("stopped", haltJson reason)]

def typeJson (type : Ty) : Json :=
  match Benitoite.Exchange.fromTy [] type with
  | .ok value => toJson value
  | .error reason => Json.mkObj [("unavailableType", toJson reason)]

def operationJson : TargetOperation → Json
  | .binary op type => Json.mkObj [("binary", toJson (Benitoite.Exchange.operatorName (.binary op))), ("type", typeJson type)]
  | .neg type => Json.mkObj [("neg", typeJson type)]
  | .standard binding => Json.mkObj [("standard", toJson binding.declaration)]

def warningJson (warning : IntervalWarning) : Json := Json.mkObj [
  ("key", keyJson warning.key), ("operation", operationJson warning.operation),
  ("cause", toJson (match warning.cause with
    | .zeroDivisor => "zeroDivisor" | .overflow => "overflow" | .outsideDomain => "outsideDomain"))]

/-- 本体終了前と終了後を混ぜず、全資源を十進文字列で交換する。 -/
def stateJson (state : Budget.State) : Json := Json.mkObj [
  ("body", Json.mkObj [("operations", toJson (toString state.body.operations)),
    ("temporary", toJson (toString state.body.temporary)), ("saved", toJson (toString state.body.saved)),
    ("peak", toJson (toString state.body.peak))]),
  ("whole", Json.mkObj [("operations", toJson (toString state.whole.operations)),
    ("saved", toJson (toString state.whole.saved)), ("peak", toJson (toString state.whole.peak))])]

private def readWidths (j : Json) : Except String Json := do
  fields "widths" (widthKinds.map kindName) j
  let values ← widthKinds.mapM fun kind => do
    pure (kindName kind, intervalJson (← readInterval (← j.getObjVal? (kindName kind)) kind))
  pure (Json.mkObj values)

private def readWidthFields (profile : String) (j : Json) : Except String (Option Json × Option Bool) := do
  if ["base", "flow"].contains profile then
    if (j.getObjVal? "widths").isOk || (j.getObjVal? "nonIntegerOther").isOk then
      throw "width fields require width/range/domain profile"
    return (none, none)
  return (some (← readWidths (← j.getObjVal? "widths")),
    some (← j.getObjValAs? Bool "nonIntegerOther"))

private def readContextExpected (j : Json) : Except String Json := do
  fields "analysis context" ["budget", "next", "identities", "unsupported"] j
  let keys ← (← (← j.getObjVal? "identities").getArr?).toList.mapM readKey
  pure (Json.mkObj [("budget", stateJson (← readState (← j.getObjVal? "budget"))),
    ("next", keyJson (← readKey (← j.getObjVal? "next"))),
    ("identities", toJson (keys.map keyJson)),
    ("unsupported", toJson (← j.getObjValAs? Bool "unsupported"))])

/-- 独立入力は親の出力から区別し、保存順・元キー・未知理由を照合する。 -/
private def readIndependentExpected (profile : String) (standards : List StandardBinding) (j : Json) : Except String Json := do
  fieldsOptional "independent expected" ["key", "integer", "boolean", "other", "warnings", "coverage"] ["widths", "nonIntegerOther"] j
  let (widths, nonIntegerOther) ← readWidthFields profile j
  let boolean ← (← j.getObjVal? "boolean").getArr?
  if boolean.size != 2 then throw "boolean range must have two flags"
  let flags : List Bool ← boolean.toList.mapM fromJson?
  let warnings ← (← (← j.getObjVal? "warnings").getArr?).toList.mapM (readWarning standards)
  pure (Json.mkObj ([("key", keyJson (← readKey (← j.getObjVal? "key"))),
    ("integer", intervalJson (← readInterval (← j.getObjVal? "integer"))),
    ("boolean", toJson flags), ("other", toJson (← j.getObjValAs? Bool "other")),
    ("warnings", toJson (warnings.map warningJson)),
    ("coverage", coverageJson (← readCoverage (← j.getObjVal? "coverage")))] ++
      (widths.toList.map fun w => ("widths", w)) ++
      (nonIntegerOther.toList.map fun b => ("nonIntegerOther", toJson b))))

/-- 具体値の期待は整数の幅と、構造値の所有元・構成子・型引数を保持する。 -/
private def readConcreteExpected : Nat → Json → Except String Json
  | 0, _ => throw "concrete value nesting too deep"
  | fuel + 1, j => do
    if j == toJson "unit" then return j
    for kind in .integer64 :: widthKinds do
      let key := if kind == .integer64 then "integer" else kindName kind
      if (j.getObjVal? key).isOk then
        fields "concrete value" [key] j
        let n ← decimalInt (← j.getObjVal? key)
        if n < kind.min || kind.max < n then throw "concrete integer outside range"
        return Json.mkObj [(key, toJson (toString n))]
    if (j.getObjVal? "boolean").isOk then
      fields "concrete value" ["boolean"] j
      return Json.mkObj [("boolean", toJson (← j.getObjValAs? Bool "boolean"))]
    if (j.getObjVal? "con").isOk then
      fields "concrete value" ["con"] j
      let c ← j.getObjVal? "con"
      fields "concrete constructor" ["owner", "types", "name", "args"] c
      let _ ← (← (← c.getObjVal? "types").getArr?).toList.mapM readType
      let _ ← c.getObjValAs? String "owner"
      let _ ← c.getObjValAs? String "name"
      let _ ← (← (← c.getObjVal? "args").getArr?).toList.mapM (readConcreteExpected fuel)
      return j
    if (j.getObjVal? "rangeError").isOk then
      fields "concrete value" ["rangeError"] j
      let e ← j.getObjVal? "rangeError"
      fields "range error" ["owner", "name", "error"] e
      let _ ← e.getObjValAs? String "owner"
      let _ ← e.getObjValAs? String "name"
      let error ← e.getObjVal? "error"
      if (error.getObjVal? "invalidBounds").isOk then
        fields "range error payload" ["invalidBounds"] error
        let ns ← (← error.getObjVal? "invalidBounds").getArr?
        if ns.size != 2 then throw "invalid bounds arity"
        let _ ← ns.toList.mapM decimalInt
      else
        fields "range error payload" ["outOfRange"] error
        let ns ← (← error.getObjVal? "outOfRange").getArr?
        if ns.size != 3 then throw "out of range arity"
        let _ ← ns.toList.mapM decimalInt
      return j
    fields "concrete value" ["other"] j
    let type ← readType (← j.getObjVal? "other")
    if (IntKind.ofType type).isSome || typeJson type == typeJson (.base .boolean) || typeJson type == typeJson (.base .unit) then
      throw "other must be noninteger nonboolean nonunit"
    return j

private def readFailureExpected (j : Json) : Except String Json := do
  if let .ok reason := j.getStr? then
    if !["unknown", "zeroDivisor", "overflow", "outsideDomain"].contains reason then throw "unknown failure"
    return j
  let key := if (j.getObjVal? "invalidBounds").isOk then "invalidBounds" else "outOfRange"
  fields "failure" [key] j
  let values ← (← j.getObjVal? key).getArr?
  if values.size != (if key == "invalidBounds" then 2 else 3) then throw "failure arity"
  let _ ← values.toList.mapM decimalInt
  return j

private def concreteExpected (j : Json) : Except String Json :=
  readConcreteExpected (j.compress.length + 1) j

private def readOutcomeExpected (j : Json) : Except String Json := do
  for kind in ["normal", "returned"] do
    if (j.getObjVal? kind).isOk then
      fields "outcome" [kind] j
      return Json.mkObj [(kind, ← concreteExpected (← j.getObjVal? kind))]
  fields "outcome" ["failed"] j
  pure (Json.mkObj [("failed", ← readFailureExpected (← j.getObjVal? "failed"))])

private def readEventExpected (standards : List StandardBinding) (j : Json) : Except String Json := do
  fields "event" ["key", "operation", "arguments", "result"] j
  let key ← readKey (← j.getObjVal? "key")
  let operation ← readOperation standards (← j.getObjVal? "operation")
  let args ← (← (← j.getObjVal? "arguments").getArr?).toList.mapM concreteExpected
  let result ← readOutcomeExpected (← j.getObjVal? "result")
  if (result.getObjVal? "returned").isOk then throw "event cannot return"
  pure (Json.mkObj [("key", keyJson key), ("operation", operationJson operation),
    ("arguments", toJson args), ("result", result)])

private def readEvaluationExpected (standards : List StandardBinding) (j : Json) : Except String Json := do
  if (j.getObjVal? "excluded").isOk then
    fields "evaluation" ["excluded"] j
    let reason ← j.getObjValAs? String "excluded"
    if !["unknownFailure", "notClosedOrFuel", "parameters"].contains reason then
      throw "unknown evaluation exclusion"
    return j
  fields "evaluation" ["outcome", "trace"] j
  pure (Json.mkObj [("outcome", ← readOutcomeExpected (← j.getObjVal? "outcome")),
    ("trace", toJson (← (← (← j.getObjVal? "trace").getArr?).toList.mapM (readEventExpected standards)))])

/-- 解析を実行せず、独立に指定した期待結果を読む。 -/
def readExpected (j : Json) (profile : String := "base") (standards : List StandardBinding := []) : Except String Expected := do
  fieldsOptional "expected" ["integer", "boolean", "other", "mayFail", "warnings", "coverage", "after"] ["independent", "context", "widths", "nonIntegerOther"] j
  let (widths, nonIntegerOther) ← readWidthFields profile j
  let boolean ← (← j.getObjVal? "boolean").getArr?
  if boolean.size != 2 then throw "boolean range must have two flags"
  pure ⟨← readInterval (← j.getObjVal? "integer"),
    (← fromJson? boolean[0]!, ← fromJson? boolean[1]!),
    ← j.getObjValAs? Bool "other", ← j.getObjValAs? Bool "mayFail",
    ← (← (← j.getObjVal? "warnings").getArr?).toList.mapM (readWarning standards),
    ← readCoverage (← j.getObjVal? "coverage"), ← readState (← j.getObjVal? "after"),
    ← match j.getObjVal? "independent" with
      | .error _ => pure []
      | .ok value => (← value.getArr?).toList.mapM (readIndependentExpected profile standards),
    ← match j.getObjVal? "context" with
      | .error _ => pure none
      | .ok value => some <$> readContextExpected value, widths, nonIntegerOther⟩

private def readBodyExpected (profile : String) (standards : List StandardBinding) (j : Json) : Except String BodyExpected := do
  if let .ok stop := j.getObjVal? "notAnalyzed" then
    fields "not analyzed expectation" ["notAnalyzed"] j
    if stop == toJson "entryUnavailable" then return .notAnalyzed stop
    return .notAnalyzed (haltJson (← readHalt stop))
  return .analyzed (← readExpected j profile standards)

/-- 入力全体の停止列も、深い欄を読み捨てずに検査する。 -/
private def readPhaseExpected (j : Json) : Except String Json := do
  let phase ← j.getObjValAs? String "phase"
  if phase == "whole" then
    fields "whole phase" ["phase", "reason"] j
  else
    if !["entry", "discovery", "queue", "embedded"].contains phase then throw "unknown stop phase"
    fields "definition phase" ["definition", "phase", "reason", "next",
      if phase == "discovery" then "context" else "afterDefinition"] j
    let _ ← j.getObjValAs? String "definition"
    let next ← j.getObjVal? "next"
    if phase == "discovery" || next != Json.null then
      let _ ← readKey next
    if phase == "discovery" then
      let _ ← readContextExpected (← j.getObjVal? "context")
    else
      let _ ← readState (← j.getObjVal? "afterDefinition")
  let _ ← readHalt (← j.getObjVal? "reason")
  return j

private def countFields : List String := ["inputDefinitions", "unsupportedBodies",
  "bodyBudgetExceeded", "unidentifiedBodies", "wholeBudgetSkipped"]

private def readInputExpected (j : Json) : Except String Json := do
  fieldsOptional "input expectation" [] ["after", "phaseStops", "counts"] j
  if let .ok value := j.getObjVal? "after" then
    let _ ← readState value
  if let .ok value := j.getObjVal? "phaseStops" then
    let _ ← (← value.getArr?).toList.mapM readPhaseExpected
  if let .ok value := j.getObjVal? "counts" then
    fields "counts" countFields value
    for field in countFields do
      let _ ← decimalNat (← value.getObjVal? field)
  return j

/-- 根の本体と、その元の全出現の型・対象演算の対応。 -/
structure Definition where
  input : BudgetWhole.Definition
  type : Ty
  types : List (OperationKey × Ty)
  sourceKeys : List OperationKey
  expected : BodyExpected
  evaluation : Option Json := none

/-- ソース順の定義を持つモジュール。 -/
structure Module where
  name : String
  definitions : List Definition

/-- 一つの検査に渡す独立したモジュール列と共有予算。 -/
structure Input where
  name : String
  fuel : Nat
  limits : Budget.Limits
  initial : Budget.State
  constants : List Benitoite.Exchange.ConstantEntry
  modules : List Module
  expectedBodies : List (String × BodyExpected) := []
  expected : Option Json := none

/-- profileごとに復号した独立入力の列。 -/
structure Corpus where
  inputs : List Input
  profile : String := "base"

private def readTypedKey (j : Json) : Except String (OperationKey × Ty) := do
  fields "typed key" ["key", "type"] j
  pure (← readKey (← j.getObjVal? "key"), ← readType (← j.getObjVal? "type"))

private def keyId (k : OperationKey) : String × Nat := (k.definition, k.surfacePreorder)

/-- 標準宣言の役割と解決済みIDを別々に受け取る。名前解決自体はA1の信頼範囲。 -/
private def readStandard (profile : String) (j : Json) : Except String StandardBinding := do
  fields "standard" ["declaration", "name", "rule", "argumentTypes"] j
  let declaration ← j.getObjValAs? String "declaration"
  if declaration.isEmpty then throw "empty standard declaration"
  let name ← j.getObjValAs? String "name"
  let args ← (← (← j.getObjVal? "argumentTypes").getArr?).toList.mapM readType
  let rule ← j.getObjVal? "rule"
  if (rule.getObjVal? "fixedDomain").isOk then
    if profile != "domain" then throw "fixed domain requires domain profile"
    fields "standard rule" ["fixedDomain"] rule
    let r ← rule.getObjVal? "fixedDomain"
    fields "fixed domain" ["operand", "direction"] r
    let type ← readType (← r.getObjVal? "operand")
    let operand ← if typeJson type == typeJson (.base .byte) then pure ShiftOperand.byte else do
      let some kind := IntKind.ofType type | throw "invalid shift operand"
      pure (.integer kind)
    let direction ← match ← r.getObjValAs? String "direction" with
      | "left" => pure ShiftOperation.left | "right" => pure .right
      | "rightUnsigned" => pure .rightUnsigned | _ => throw "unknown shift direction"
    let modules := match operand with
      | .byte => ["Byte", "UnsignedInteger8"]
      | .integer .integer64 => ["Integer", "Integer64"]
      | .integer .unsignedInteger64 => ["UnsignedInteger", "UnsignedInteger64"]
      | .integer kind => [kindName kind]
    let suffix := match direction with
      | .left => "shiftLeft" | .right => "shiftRight" | .rightUnsigned => "shiftRightUnsigned"
    if !(modules.map (fun m => "Benitoite." ++ m ++ "." ++ suffix)).contains name then
      throw "false standard shift declaration"
    let some binding := (FixedDomainApi.shift operand direction).binding declaration
      | throw "nonexistent shift declaration"
    if args.map typeJson != binding.argumentTypes.map typeJson then throw "standard argument type mismatch"
    return binding
  if !["range", "domain"].contains profile then throw "Range rule requires range/domain profile"
  if (rule.getObjVal? "rangeCheck").isOk then
    fields "standard rule" ["rangeCheck"] rule
    if name != "Benitoite.Range.checkInteger" then throw "false standard Range declaration"
    let n ← rule.getObjVal? "rangeCheck"
    fields "Range names" ["owner", "checkedConstructor", "result", "error", "ok", "err", "invalidBounds", "outOfRange", "record"] n
    let names : RangeNames := ⟨← n.getObjValAs? String "owner", ← n.getObjValAs? String "checkedConstructor",
      ← n.getObjValAs? String "result", ← n.getObjValAs? String "error", ← n.getObjValAs? String "ok",
      ← n.getObjValAs? String "err", ← n.getObjValAs? String "invalidBounds", ← n.getObjValAs? String "outOfRange"⟩
    if [names.owner, names.checkedConstructor, names.result, names.error, names.ok, names.err,
        names.invalidBounds, names.outOfRange].any String.isEmpty then throw "empty Range identity"
    let record : Benitoite.Exchange.RecordConDecl ← surface (← n.getObjVal? "record")
    let recordArgs ← record.args.mapM Benitoite.Exchange.Ty.toRelease
    if record.data != names.owner || record.ntys != 0 ||
        record.fields != ["minimum", "maximum", "value"] || recordArgs.map typeJson != (List.replicate 3 (.base .integer)).map typeJson then
      throw "invalid Range record declaration"
    if args.map typeJson != (List.replicate 3 (.base .integer)).map typeJson then throw "standard argument type mismatch"
    return ⟨declaration, .rangeCheck names, args⟩
  fields "standard rule" ["rangeValue"] rule
  if name != "Benitoite.Range.value" then throw "false standard Range declaration"
  let r ← rule.getObjVal? "rangeValue"
  fields "Range record" ["owner", "constructor", "record"] r
  let owner ← r.getObjValAs? String "owner"
  let constructor ← r.getObjValAs? String "constructor"
  let record : Benitoite.Exchange.RecordConDecl ← surface (← r.getObjVal? "record")
  let recordArgs ← record.args.mapM Benitoite.Exchange.Ty.toRelease
  if owner.isEmpty || constructor.isEmpty || record.data != owner || record.ntys != 0 ||
      record.fields != ["minimum", "maximum", "value"] || recordArgs.map typeJson != (List.replicate 3 (.base .integer)).map typeJson then
    throw "invalid Range record declaration"
  if args.map typeJson != [typeJson (.data owner [])] then throw "standard argument type mismatch"
  return ⟨declaration, .rangeValue ⟨owner, constructor⟩, args⟩

private def readApiAt (j : Json) : Except String (OperationKey × String) := do
  fields "api occurrence" ["key", "declaration"] j
  pure (← readKey (← j.getObjVal? "key"), ← j.getObjValAs? String "declaration")

/-- 親・独立入力・別本体の期待でも、元の出現と演算の一致を失わない。 -/
private def validateExpected (env : AbstractEnv) (occurrences : List (OperationKey × Benitoite.Surface.Expr))
    (bodyExpected : BodyExpected) : Except String Unit := do
  let .analyzed expected := bodyExpected | return ()
  let validateWarnings := fun (warnings : List IntervalWarning) => do
    unique "warning key and cause" (warnings.map fun w =>
      (keyId w.key, match w.cause with | .zeroDivisor => 0 | .overflow => 1 | .outsideDomain => 2))
    for warning in warnings do
      let some source := occurrences.find? (fun p => p.1 == warning.key)
        | throw "warning key outside definition"
      let agrees := match targetOperationAt env warning.key source.2 with
        | some operation => operationJson operation == operationJson warning.operation
        | none => false
      if !agrees then throw "warning operation mismatch"
  validateWarnings expected.warnings
  let independentKeys ← expected.independent.mapM fun child => do readKey (← child.getObjVal? "key")
  unique "independent input key" (independentKeys.map keyId)
  for child in expected.independent do
    let key ← readKey (← child.getObjVal? "key")
    if !occurrences.any (·.1 == key) then throw "independent input key outside definition"
    validateWarnings (← (← (← child.getObjVal? "warnings").getArr?).toList.mapM (readWarning env.standards))

private def readDefinition (profile : String) (env : AbstractEnv) (module : String) (constants : List (String × Benitoite.Surface.Expr)) (j : Json) :
    Except String Definition := do
  fieldsOptional "definition" ["name", "kind", "params", "type", "body", "types", "sourceKeys", "expected"] ["evaluation"] j
  let name ← j.getObjValAs? String "name"
  let ordinary := name.startsWith (module ++ ".") && name != module ++ "." && !name.contains '%'
  let method := match name.splitOn ":" with
    | [owner, decl, index, method] => owner == module ++ "%impl" && !method.isEmpty &&
        !method.contains '%' && (decimalNat (toJson decl)).isOk && (decimalNat (toJson index)).isOk
    | _ => false
  if !ordinary && !method then throw "definition name does not match module"
  let kind ← match ← j.getObjValAs? String "kind" with
    | "function" => pure BodyKind.function | "constant" => pure .constant
    | _ => throw "unknown root body kind"
  let params ← (← (← j.getObjVal? "params").getArr?).toList.mapM readType
  if kind == .constant && !params.isEmpty then throw "constant cannot have parameters"
  let type ← readType (← j.getObjVal? "type")
  let body : Benitoite.Exchange.Block ← surface (← j.getObjVal? "body")
  Benitoite.Exchange.validateIntegerConstants (toJson body)
  let body ← body.toSurface constants
  let rawTypes ← (← j.getObjVal? "types").getArr?
  let types ← rawTypes.toList.mapM readTypedKey
  unique "type key" (types.map (keyId ∘ Prod.fst))
  let occurrences := numbered (bodyRootKey name) (bodyRoot body)
  let keys := occurrences.map Prod.fst
  if types.map (keyId ∘ Prod.fst) != keys.map keyId then throw "missing or out-of-order type correspondence"
  if !(rawTypes[0]?.any fun p => (p.getObjVal? "type").toOption == (j.getObjVal? "type").toOption) then
    throw "root type mismatch"
  let sourceKeys ← (← (← j.getObjVal? "sourceKeys").getArr?).toList.mapM readKey
  unique "source key" (sourceKeys.map keyId)
  let targets := occurrences.filterMap fun (k,e) =>
    if (targetOperationAt env k e).isSome then some k else none
  if sourceKeys.map keyId != targets.map keyId then throw "missing or invalid target correspondence"
  let expected ← readBodyExpected profile env.standards (← j.getObjVal? "expected")
  validateExpected env occurrences expected
  pure ⟨⟨name, kind, params, body, env⟩, type, types, sourceKeys, expected,
    ← match j.getObjVal? "evaluation" with
      | .error _ => pure none
      | .ok value => some <$> readEvaluationExpected env.standards value⟩

private def readModule (profile : String) (env : AbstractEnv) (constants : List (String × Benitoite.Surface.Expr))
    (entry : Bool) (j : Json) : Except String Module := do
  fields "module" ["name", "definitions"] j
  let name ← j.getObjValAs? String "name"
  if (name.isEmpty && !entry) || name.contains '%' then throw "invalid module name"
  let definitions ← (← (← j.getObjVal? "definitions").getArr?).toList.mapM (readDefinition profile env name constants)
  unique "definition" (definitions.map (·.input.name))
  pure ⟨name, definitions⟩

private def readInput (profile : String) (j : Json) : Except String Input := do
  fieldsOptional "input" ["name", "fuel", "limits", "initial", "constants", "standards", "apiAt", "modules"] ["expectedBodies", "expected"] j
  let name ← j.getObjValAs? String "name"
  if name.isEmpty then throw "empty input name"
  let standards ← (← (← j.getObjVal? "standards").getArr?).toList.mapM (readStandard profile)
  unique "standard declaration" (standards.map (·.declaration))
  unique "standard role" (← (← (← j.getObjVal? "standards").getArr?).toList.mapM
    (fun row => row.getObjValAs? String "name"))
  for check in standards do
    match check.rule with
    | .rangeCheck names =>
      if names.ok == names.err || names.invalidBounds == names.outOfRange then throw "conflicting Range identities"
      for value in standards do
        match value.rule with
        | .rangeValue record =>
          if record != names.record then throw "inconsistent Range record identities"
        | _ => pure ()
    | _ => pure ()
  let apiAt ← (← (← j.getObjVal? "apiAt").getArr?).toList.mapM readApiAt
  unique "API key" (apiAt.map (keyId ∘ Prod.fst))
  let env : AbstractEnv :=
    { (AbstractEnv.ofLocals []) with
      standards := standards
      apiAt := fun key => (apiAt.find? (fun row => row.1 == key)).map Prod.snd }
  let constants ← (← (← j.getObjVal? "constants").getArr?).toList.mapM fun raw => do
    let c : Benitoite.Exchange.ConstantEntry ← surface raw
    Benitoite.Exchange.validateIntegerConstants raw
    let _ ← c.ty.toRelease
    pure c
  unique "constant" (constants.map (·.name))
  let (_, expanded) ← (constants.forM fun c => Benitoite.Exchange.expandConstant constants c.name).run {}
  -- 実行開始のモジュールだけが空名を持つ。元の定義キーの先頭の . を保つ。
  -- （設計書 07-04「区間解析の独立交換の読者」）。
  let modules ← (← (← j.getObjVal? "modules").getArr?).toList.zipIdx.mapM fun (raw, index) =>
    readModule profile env expanded.cache (index == 0) raw
  unique "module" (modules.map (·.name))
  unique "definition" (modules.flatMap fun m => m.definitions.map (·.input.name))
  let occurrences := modules.flatMap fun m => m.definitions.flatMap fun d =>
    numbered (bodyRootKey d.input.name) (bodyRoot d.input.body)
  for (key, declaration) in apiAt do
    if !standards.any (·.declaration == declaration) then throw "API refers to absent standard declaration"
    let some occurrence := occurrences.find? (·.1 == key) | throw "API key outside definition"
    let head := match occurrence.2 with
      | .call callee _ _ _ => standardCallHead callee | _ => none
    if head != some declaration then throw "API declaration does not match call head"
  -- 認定する直接callの出現は全て渡す。未認定の頭・別名の文字列から補わない。
  for (key, expression) in occurrences do
    match expression with
    | .call callee _ _ _ =>
      if (standardCallHead callee).any (fun name => standards.any (·.declaration == name)) &&
          !(apiAt.any (·.1 == key)) then throw "missing standard call occurrence"
    | _ => pure ()
  let expectedBodies ← match j.getObjVal? "expectedBodies" with
    | .error _ => pure []
    | .ok value => (← value.getArr?).toList.mapM fun row => do
        fields "expected body" ["definition", "expected"] row
        pure (← row.getObjValAs? String "definition", ← readBodyExpected profile standards (← row.getObjVal? "expected"))
  unique "expected body" (expectedBodies.map Prod.fst)
  let embedded := modules.flatMap fun m => m.definitions.flatMap fun d =>
    bodyManifest d.input.name d.input.body
  for (definition, expected) in expectedBodies do
    let some entry := embedded.find? (·.definition == definition)
      | throw "expected body outside embedded manifest"
    validateExpected (BudgetWhole.entryEnv entry env)
      (numbered (bodyRootKey definition) (bodyRoot entry.body)) expected
  pure ⟨name, ← decimalNat (← j.getObjVal? "fuel"), ← readLimits (← j.getObjVal? "limits"),
    ← readState (← j.getObjVal? "initial"), constants, modules, expectedBodies,
    ← match j.getObjVal? "expected" with
      | .error _ => pure none
      | .ok value => some <$> readInputExpected value⟩

/-- JSONからの復号。生の入力には重複欄を失わないreadCorpusを使う。 -/
def decodeCorpus (j : Json) : Except String Corpus := do
  fields "interval corpus" ["kind", "version", "surfaceVersion", "traversalVersion", "profile", "inputs"] j
  if (← j.getObjValAs? String "kind") != "interval-corpus" then throw "unknown corpus kind"
  if (← j.getObjValAs? Nat "version") != 1 then throw "unsupported interval corpus version"
  let surfaceVersion ← j.getObjValAs? Nat "surfaceVersion"
  if surfaceVersion != 14 && surfaceVersion != 15 then throw "unsupported Surface version"
  if surfaceVersion == 14 then
    -- 範囲のない旧版。埋め込みの Surface に範囲の欄を置かせない。
    Benitoite.Exchange.rejectFields Benitoite.Exchange.rangeFields j
  else
    -- 版15は範囲の欄を必須とし、範囲の変数を置かせず、範囲の正規形を確かめる（L50.2）。
    Benitoite.Exchange.rejectFields ["rvar"] j
    Benitoite.Exchange.validateRanges 0 j
    if Benitoite.Exchange.legacyRangesMissing j != j then throw "missing range fields in Surface 15"
  if (← j.getObjValAs? Nat "traversalVersion") != 1 then throw "unsupported traversal version"
  let profile ← j.getObjValAs? String "profile"
  if !["base", "flow", "width", "range", "domain"].contains profile then throw "unsupported interval profile"
  let inputs ← (← (← j.getObjVal? "inputs").getArr?).toList.mapM (readInput profile)
  unique "input" (inputs.map (·.name))
  pure ⟨inputs, profile⟩

/-- 生のinterval-corpus初版1を、重複欄を失わずに読む。 -/
def readCorpus (raw : String) : Except String Corpus := do
  decodeCorpus (← UniqueJson.parse raw)

/-- 比較の結果と、比較以外の受け入れ条件を分ける。 -/
structure Comparison where
  report : Json
  matched : Bool
  accepted : Bool

private def countJson (n : Nat) : Json := toJson (toString n)

private def widthsJson (value : BaseApprox) : Json :=
  Json.mkObj (widthKinds.map fun kind => (kindName kind, intervalJson (value.rangeKind kind)))

private def approximationJson (value : BaseApprox) : List (String × Json) := [
  ("integer", intervalJson value.integer), ("boolean", toJson [value.boolean.1, value.boolean.2]),
  ("other", toJson value.other), ("widths", widthsJson value),
  ("nonIntegerOther", toJson value.nonIntegerOther)]

private def contextJson (ctx : BudgetAnalysis.Context) : Json := Json.mkObj [
  ("budget", stateJson ctx.budget), ("next", keyJson ctx.next),
  ("identities", toJson (ctx.identitiesRev.reverse.map (keyJson ∘ Prod.fst))),
  ("unsupported", toJson ctx.unsupported)]

private def independentJson (extended : Bool) (value : BudgetAnalysis.IndependentResult) : Json :=
  let approx := match value.result with | .ok approx => approx | .error _ => baseUnknown
  let coverage := match value.result with
    | .error reason => BudgetAnalysis.Coverage.stopped reason
    | .ok _ => if value.unsupported then .unsupported else .complete
  Json.mkObj ((approximationJson approx).filter (fun p => extended || !["widths", "nonIntegerOther"].contains p.1) ++ [("key", keyJson value.key),
    ("warnings", toJson (value.warningsRev.reverse.map warningJson)),
    ("coverage", coverageJson coverage)])

private def actualJson (extended : Bool) (output : BudgetAnalysis.Report) : Json :=
  Json.mkObj (approximationJson output.approx ++ [
    ("mayFail", toJson output.approx.mayFail),
    ("warnings", toJson (output.context.warningsRev.reverse.map warningJson)),
    ("coverage", coverageJson output.coverage), ("after", stateJson output.after),
    ("independent", toJson (output.context.independentRev.reverse.map (independentJson extended))),
    ("context", contextJson output.context)])

private def expectedJson (expected : Expected) : Json := Json.mkObj ([
  ("integer", intervalJson expected.integer), ("boolean", toJson [expected.boolean.1, expected.boolean.2]),
  ("other", toJson expected.other), ("warnings", toJson (expected.warnings.map warningJson)),
  ("coverage", coverageJson expected.coverage), ("after", stateJson expected.after),
  ("independent", toJson expected.independent), ("context", expected.context.getD Json.null)] ++
    (expected.widths.toList.map fun w => ("widths", w)) ++
    (expected.nonIntegerOther.toList.map fun b => ("nonIntegerOther", toJson b)))

/-- mayFailは評価失敗との逆向きの保証を持たず、一致の判定から除く。 -/
private def differences (actual : Json) (expected : Expected) : List String :=
  let wanted := expectedJson expected
  (["integer", "boolean", "other", "warnings", "coverage", "after", "independent", "context"] ++
    (if expected.widths.isSome then ["widths", "nonIntegerOther"] else [])).filter fun field =>
      (actual.getObjVal? field).toOption != (wanted.getObjVal? field).toOption

private def expectedFor (input : Input) (name : String) : Option BodyExpected :=
  let roots := input.modules.flatMap (·.definitions)
  match roots.find? (fun d => d.input.name == name) with
  | some d => some d.expected
  | none => (input.expectedBodies.find? (fun d => d.1 == name)).map Prod.snd

private def unknownReasons (output : BudgetAnalysis.Report) : List Json :=
  (if output.context.unsupported then [Json.mkObj [("reason", toJson "unsupported")]] else []) ++
  (match output.coverage with
    | .stopped reason => [Json.mkObj [("reason", haltJson reason), ("next", keyJson output.context.next)]]
    | _ => []) ++
  output.context.independentRev.reverse.filterMap fun child =>
    match child.result with
    | .error reason => some (Json.mkObj [("key", keyJson child.key), ("reason", haltJson reason)])
    | .ok _ => if child.unsupported then
        some (Json.mkObj [("key", keyJson child.key), ("reason", toJson "unsupported")]) else none

private def bodyComparison (input : Input) (body : BudgetWhole.BodyOutput) : Json × Bool :=
  let actual := actualJson ((expectedFor input body.definition).any fun e =>
    match e with | .analyzed value => value.widths.isSome | .notAnalyzed _ => false) body.output
  let eligible := BudgetWhole.comparisonEligible body
  let mismatch := match expectedFor input body.definition with
    | some (.notAnalyzed _) => ["notAnalyzed"]
    | some (.analyzed expected) => if eligible then differences actual expected else []
    | none => if eligible then ["missing body expectation"] else []
  (Json.mkObj [("definition", toJson body.definition), ("comparisonEligible", toJson eligible),
    ("excluded", toJson (if eligible then ([] : List String) else ["depth"])),
    ("actual", actual), ("unknownReasons", toJson (unknownReasons body.output)),
    ("mismatches", toJson mismatch)], mismatch.isEmpty)

/-- 別本体の型は元の全型表から読む。評価器の型推測や期待値から補わない。 -/
private def blockResultType (types : List (OperationKey × Ty)) : OperationKey → Block → Option Ty
  | key, .last _ => (types.find? (·.1 == key)).map Prod.snd
  | _, .empty | _, .lastBind .. | _, .lastDiscard .. | _, .lastPat .. => some (.base .unit)
  | key, .builderBind _ rest => blockResultType types key rest
  | key, .bind _ _ source rest | key, .bindPat _ _ _ source rest
  | key, .discard source rest | key, .seq source rest =>
    blockResultType types (advanceKey key (surfaceSize source)) rest

private def reportedBodyType (input : Input) (name : String) : Option Ty := do
  let definitions := input.modules.flatMap (·.definitions)
  if let some root := definitions.find? (·.input.name == name) then return root.type
  let owner ← definitions.find? fun d => (bodyManifest d.input.name d.input.body).any (·.definition == name)
  let entry ← (bodyManifest owner.input.name owner.input.body).find? (·.definition == name)
  blockResultType owner.types ⟨owner.input.name, entry.parentStart⟩ entry.body

/-- Topかどうかは根の型の正常成分で判定する。BottomはTopに数えない。 -/
private def informative (input : Input) (body : BudgetWhole.BodyOutput) : Bool :=
  match reportedBodyType input body.definition with
  | some (.base .integer) => body.output.approx.integer != top
  | some (.base .boolean) => body.output.approx.boolean != (true, true)
  | some ty => match IntKind.ofType ty with
    | some kind => body.output.approx.rangeKind kind != top kind
    | none => !body.output.approx.nonIntegerOther
  | none => false

/-- 数学的な全列挙は検証用であり、予算付き駆動への先行入力にはしない。 -/
private def inputManifest (input : Input) : List String :=
  input.modules.flatMap fun m => m.definitions.flatMap fun d =>
    d.input.name :: (bodyManifest d.input.name d.input.body).map (·.definition)

/-- C1R2の最初のfuel。列の長さを含むsurfaceSizeの総和から選ぶ。 -/
def initialFuel (corpus : Corpus) : Nat :=
  4 * (corpus.inputs.flatMap (·.modules) |>.flatMap (·.definitions) |>.map
    (fun d => surfaceSize (bodyRoot d.input.body)) |>.foldl (· + ·) 0) + 32

private def phaseDetails (r : BudgetWhole.Report) : List Json :=
  (r.stopped.toList.map fun reason => Json.mkObj [("phase", toJson "whole"), ("reason", haltJson reason)]) ++
  r.definitionsRev.reverse.flatMap fun d =>
    let row := fun phase reason next => Json.mkObj [("definition", toJson d.input.name),
      ("phase", toJson phase), ("reason", haltJson reason),
      ("next", (next : Option OperationKey).map keyJson |>.getD Json.null),
      ("afterDefinition", stateJson d.embedded.after)]
    (match d.prepared with | .error reason => [row "entry" reason (some (bodyRootKey d.input.name))] | _ => []) ++
    (match d.discovery with
      | some discovery => match discovery.result with
        | .error reason => [Json.mkObj [("definition", toJson d.input.name),
            ("phase", toJson "discovery"), ("reason", haltJson reason),
            ("next", keyJson discovery.context.walk.next),
            ("context", contextJson discovery.context.walk)]]
        | _ => []
      | none => []) ++
    (match d.queue with
      | some (.error reason) => [row "queue" reason (d.discovery.map (·.context.walk.next))]
      | _ => []) ++
    (d.embedded.stopped.toList.map fun reason => row "embedded" reason
      (d.embedded.pending.head?.map fun e => bodyRootKey e.embedded.definition))

private def definitionProgress (d : BudgetWhole.DefinitionOutput) : Json := Json.mkObj [
  ("definition", toJson d.input.name), ("entryPrepared", toJson d.prepared.isOk),
  ("discoveryStarted", toJson d.discovery.isSome),
  ("discoveryComplete", toJson (d.discovery.any fun r => r.result.isOk)),
  ("queuePrepared", toJson (d.queue.any Except.isOk)),
  ("pending", toJson (d.embedded.pending.map (fun e => e.embedded.definition)))]

private def unproducedComparison (input : Input) (result : BudgetWhole.Report) (name : String) : Json × Bool :=
  let owner := result.definitionsRev.find? fun d => d.input.name == name ||
    (bodyManifest d.input.name d.input.body).any (fun e => e.definition == name)
  let reason := match owner with
    | none => result.stopped
    | some d => (match d.prepared with | .error why => some why | _ => none).orElse fun _ =>
        (d.discovery.bind fun r => match r.result with | .error why => some why | _ => none).orElse fun _ =>
        (d.queue.bind fun r => match r with | .error why => some why | _ => none).orElse fun _ =>
        d.embedded.stopped
  let stop := reason.map haltJson |>.getD (toJson "entryUnavailable")
  let mismatch := match expectedFor input name with
    | none => []
    | some (.notAnalyzed expected) => if expected == stop then [] else ["notAnalyzed"]
    | some (.analyzed _) => ["notAnalyzed"]
  (Json.mkObj [("definition", toJson name), ("comparisonEligible", toJson false),
    ("reason", toJson "notAnalyzed"),
    ("stop", stop), ("mismatches", toJson mismatch)], mismatch.isEmpty)

private def analyzeInput (input : Input) : Json × Bool × Nat × Nat × Nat × Nat := Id.run do
  let modules := input.modules.map fun m => BudgetWhole.Module.mk (m.definitions.map (·.input))
  let result := BudgetWhole.analyze input.limits input.initial input.fuel modules
  let bodies := BudgetWhole.bodyOutputs result
  let compared := bodies.map (bodyComparison input)
  let eligible := bodies.filter BudgetWhole.comparisonEligible
  let exclusions := BudgetWhole.excludedBodies result
  let phaseDepth := (BudgetWhole.phaseStops result).filter (· == .depth)
  let independentDepth := bodies.flatMap fun b => b.output.context.independentRev.filterMap fun c =>
    match c.result with | .error .depth => some c.key | _ => none
  let progress := result.definitionsRev.reverse.map definitionProgress
  let manifest := inputManifest input
  let unproduced := (manifest.filter fun name => !bodies.any (fun b => b.definition == name)).map
    (unproducedComparison input result)
  let extraExpected := input.expectedBodies.filter fun (name, _) => !manifest.contains name
  let after := stateJson result.after
  let phases := toJson (phaseDetails result)
  let counts := Json.mkObj [("inputDefinitions", countJson (BudgetWhole.inputDefinitionCount result)),
      ("unsupportedBodies", countJson (BudgetWhole.unsupportedBodies result)),
      ("bodyBudgetExceeded", countJson (BudgetWhole.bodyBudgetExceeded result)),
      ("unidentifiedBodies", countJson (BudgetWhole.unidentifiedBodies result)),
      ("wholeBudgetSkipped", countJson (BudgetWhole.wholeBudgetSkipped result))]
  let final := Json.mkObj [("after", after), ("phaseStops", phases), ("counts", counts)]
  let inputMismatch := match input.expected with
    | none => []
    | some expected => ["after", "phaseStops", "counts"].filter fun field =>
        (expected.getObjVal? field).isOk &&
        (expected.getObjVal? field).toOption != (final.getObjVal? field).toOption
  let good := compared.all Prod.snd && unproduced.all Prod.snd && extraExpected.isEmpty && inputMismatch.isEmpty
  let excluded := exclusions.length
  let nonTop := (eligible.filter (informative input)).length
  return (Json.mkObj [("name", toJson input.name), ("fuel", countJson input.fuel),
    ("manifest", toJson manifest), ("bodies", toJson (compared.map Prod.fst)),
    ("phaseStops", phases), ("progress", toJson progress),
    ("remainingDefinitions", toJson (result.remainingDefinitions.map (·.name))),
    ("remainingModules", toJson (result.remainingModules.map fun m => m.definitions.map (·.name))),
    ("unproducedBodies", toJson (unproduced.map Prod.fst)),
    ("mismatches", toJson inputMismatch),
    ("extraExpectations", toJson (extraExpected.map Prod.fst)),
    ("excludedBodies", toJson (exclusions.map (·.definition))),
    ("independentDepth", toJson (independentDepth.map keyJson)),
    ("independentDepthCount", countJson independentDepth.length),
    ("excludedCount", countJson excluded), ("phaseDepthCount", countJson phaseDepth.length),
    ("comparedCount", countJson eligible.length), ("informativeCount", countJson nonTop),
    ("counts", counts),
    ("bodyStops", toJson ((BudgetWhole.bodyStops result).map haltJson)),
    ("after", after), ("matched", toJson good)],
    good, eligible.length, nonTop, excluded, phaseDepth.length)

/-- 必須profileの集合と、今回の呼び出しが実際に比較した範囲を区別する。 -/
def requiredProfiles : List String := ["base", "flow", "width", "range", "domain"]

private def profileManifest (corpus : Corpus) (compared excluded : Nat) : Json := Json.mkObj [
  ("requiredProfiles", toJson requiredProfiles), ("profile", toJson corpus.profile),
  ("inputCount", countJson corpus.inputs.length),
  ("definitionCount", countJson (corpus.inputs.flatMap (·.modules) |>.flatMap (·.definitions) |>.length)),
  ("bodyCount", countJson (corpus.inputs.flatMap inputManifest |>.length)),
  ("comparedCount", countJson compared), ("excludedCount", countJson excluded)]

/-- 解析と独立期待値の比較。空・全Top・深さ除外を受け入れ成功に数えない。 -/
def analyzeCorpus (corpus : Corpus) : Comparison := Id.run do
  let results := corpus.inputs.map analyzeInput
  let matched := results.all (fun row => row.2.1)
  let count := (results.map (fun row => row.2.2.1)).foldl (· + ·) 0
  let informative := (results.map (fun row => row.2.2.2.1)).foldl (· + ·) 0
  let excluded := (results.map (fun row => row.2.2.2.2.1)).foldl (· + ·) 0
  let phaseDepth := (results.map (fun row => row.2.2.2.2.2)).foldl (· + ·) 0
  let reasons := (if count == 0 then ["emptyComparison"] else []) ++
    (if informative == 0 then ["allTop"] else []) ++
    (if excluded + phaseDepth != 0 then ["depthExclusions"] else [])
  let accepted := matched && reasons.isEmpty
  return ⟨Json.mkObj [("kind", toJson "interval-report"), ("version", toJson (1 : Nat)),
    ("mode", toJson "analyze"), ("profile", toJson corpus.profile),
    ("profileManifest", profileManifest corpus count excluded),
    ("initialFuel", countJson (initialFuel corpus)), ("inputs", toJson (results.map Prod.fst)),
    ("comparedCount", countJson count), ("informativeCount", countJson informative),
    ("excludedCount", countJson excluded), ("phaseDepthCount", countJson phaseDepth), ("matched", toJson matched),
    ("accepted", toJson accepted), ("acceptanceReasons", toJson reasons)], matched, accepted⟩

/-- 具体値の整数幅・構造値の所有元と三欄を保つ。 -/
private def concreteJson : ConcreteValue → Json
  | .integer n => Json.mkObj [("integer", toJson (toString n.toInt))]
  | .integer8 n => Json.mkObj [("Integer8", toJson (toString n.toInt))]
  | .integer16 n => Json.mkObj [("Integer16", toJson (toString n.toInt))]
  | .integer32 n => Json.mkObj [("Integer32", toJson (toString n.toInt))]
  | .unsignedInteger16 n => Json.mkObj [("UnsignedInteger16", toJson (toString n.toInt))]
  | .unsignedInteger32 n => Json.mkObj [("UnsignedInteger32", toJson (toString n.toInt))]
  | .unsignedInteger64 n => Json.mkObj [("UnsignedInteger64", toJson (toString n.toInt))]
  | .con owner types name args => Json.mkObj [("con", Json.mkObj [("owner", toJson owner),
      ("types", toJson (types.map typeJson)), ("name", toJson name), ("args", toJson (args.map concreteJson))])]
  | .rangeError owner name error => Json.mkObj [("rangeError", Json.mkObj [("owner", toJson owner),
      ("name", toJson name), ("error", match error with
        | .invalidBounds lo hi => Json.mkObj [("invalidBounds", toJson [toString lo, toString hi])]
        | .outOfRange lo hi value => Json.mkObj [("outOfRange", toJson [toString lo, toString hi, toString value])])])]
  | .boolean b => Json.mkObj [("boolean", toJson b)]
  | .unit => toJson "unit"
  | .other type _ _ _ => Json.mkObj [("other", typeJson type)]

private def failureJson : Failure → Json
  | .unknown => toJson "unknown" | .zeroDivisor => toJson "zeroDivisor"
  | .overflow => toJson "overflow" | .outsideDomain => toJson "outsideDomain"
  | .invalidBounds lo hi => Json.mkObj [("invalidBounds", toJson [toString lo, toString hi])]
  | .outOfRange lo hi value => Json.mkObj [("outOfRange", toJson [toString lo, toString hi, toString value])]

private def outcomeJson : EvalOutcome → Json
  | .normal value => Json.mkObj [("normal", concreteJson value)]
  | .returned value => Json.mkObj [("returned", concreteJson value)]
  | .failed reason => Json.mkObj [("failed", failureJson reason)]

private def eventJson (event : EvalEvent) : Json := Json.mkObj [
  ("key", keyJson event.key), ("operation", operationJson event.operation),
  ("arguments", toJson (event.arguments.map concreteJson)),
  ("result", outcomeJson event.result.outcome)]

private def evalDefinition (fuel : Nat) (d : Definition) : Json × Bool × Bool :=
  let env : ConcreteEnv := ⟨[], d.input.metadata.standards, d.input.metadata.apiAt⟩
  let run := if d.input.params.isEmpty then
    evalClosed env ⟨bodyRoot d.input.body, d.type, bodyRootKey d.input.name⟩ fuel else none
  let reason := if !d.input.params.isEmpty then some "parameters" else match run with
    | none => some "notClosedOrFuel"
    | some run => match run.outcome with
      | .failed .unknown => some "unknownFailure" | _ => none
  let actual := match reason with
    | some why => Json.mkObj [("excluded", toJson why)]
    | none => match run with
      | some value => Json.mkObj [("outcome", outcomeJson value.outcome),
          ("trace", toJson (value.trace.map eventJson))]
      | none => Json.null
  let agrees := d.evaluation == some actual
  (Json.mkObj [("definition", toJson d.input.name), ("comparisonEligible", toJson reason.isNone),
    ("actual", actual), ("matched", toJson agrees),
    ("mismatches", toJson (if agrees then ([] : List String) else
      if d.evaluation.isNone then ["missing evaluation expectation"] else ["evaluation"])),
    ("observed", match run with
      | none => Json.null
      | some value => Json.mkObj [("outcome", outcomeJson value.outcome), ("trace", toJson (value.trace.map eventJson))])],
    agrees, reason.isNone)

/-- 評価器の値・失敗種・到達順序を解析の近似から独立して比較する。 -/
def evalCorpus (corpus : Corpus) : Comparison := Id.run do
  let results := corpus.inputs.map fun input =>
    let rows := input.modules.flatMap (·.definitions) |>.map (evalDefinition input.fuel)
    let embedded := input.modules.flatMap (·.definitions) |>.flatMap fun d =>
      (bodyManifest d.input.name d.input.body).map fun e => Json.mkObj [
        ("definition", toJson e.definition), ("comparisonEligible", toJson false),
        ("reason", toJson "embeddedEnvironment")]
    (Json.mkObj [("name", toJson input.name), ("fuel", countJson input.fuel),
      ("bodies", toJson (rows.map Prod.fst)),
      ("manifest", toJson (inputManifest input)),
      ("embeddedExcluded", toJson embedded),
      ("comparedCount", countJson ((rows.filter (fun row => row.2.2)).length)),
      ("excludedCount", countJson ((rows.filter (fun row => !row.2.2)).length + embedded.length))],
      rows.all (fun row => row.2.1), (rows.filter (fun row => row.2.2)).length,
      (rows.filter (fun row => !row.2.2)).length + embedded.length)
  let matched := results.all (fun row => row.2.1)
  let count := (results.map (fun row => row.2.2.1)).foldl (· + ·) 0
  let excluded := (results.map (fun row => row.2.2.2)).foldl (· + ·) 0
  let reasons := if count == 0 then ["emptyComparison"] else []
  let accepted := matched && reasons.isEmpty
  return ⟨Json.mkObj [("kind", toJson "interval-report"), ("version", toJson (1 : Nat)),
    ("mode", toJson "eval"), ("profile", toJson corpus.profile),
    ("profileManifest", profileManifest corpus count excluded),
    ("initialFuel", countJson (initialFuel corpus)), ("inputs", toJson (results.map Prod.fst)),
    ("comparedCount", countJson count), ("excludedCount", countJson excluded),
    ("matched", toJson matched), ("accepted", toJson accepted),
    ("acceptanceReasons", toJson reasons)], matched, accepted⟩

end Benitoite.Interval.Exchange
