import Benitoite.Interval.Domain
import Benitoite.Interval.Identity
import Benitoite.Checked.Range

/-!
# 対象構文の評価関係

正常値・失敗・return と演算への到達を分ける。未対応の境界の内側は評価せず、
型内の任意値と失敗を許す。Release の δ との一致を仮定しない
（設計書 01-12「区間解析の対象構文の評価関係」）。
-/
namespace Benitoite.Interval

open Benitoite.Release Benitoite.Surface

/-- 対象に加える区切りと、常に外の事実を捨てる境界の分類。 -/
inductive FragmentClass where
  | base | flow | width | api | unknownValue | boundary
  deriving DecidableEq, Repr

/-- 全53構成子の分類。分類は子の評価や番号付けを意味しない。 -/
def classify : Expr → FragmentClass
  | .local _ | .constE _ _ | .literal _ | .negInt _ | .unit | .paren _
  | .block _ | .binary _ _ _ _ | .not _ | .ite _ _ _ | .elseIf _ _ _
  | .ifOnly _ _ | .returnE _ _ => .base
  | .and _ _ | .or _ _ | .matchE _ _ _ => .flow
  | .negInteger8 _ | .negInteger16 _ | .negInteger32 _ | .neg _ _ => .width
  | .call _ _ _ _ | .record _ _ _ _ | .recordUpdate _ _ _ _ _ _ => .api
  | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
  | .primName _ _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
  | .nullCon _ _ | .conValue _ _ _ _ => .unknownValue
  | .builderOp _ _ _ _ | .handleFail _ _ _ _ | .negFloat _ | .negDecimal _ _
  | .negFloat32 _ | .conCall _ _ _ | .pipe _ _ | .partialCall _ _ _ _ _
  | .partialCon _ _ _ | .list _ _ | .listSpread _ _ _ _ _
  | .interpolation _ _ _ | .lam _ _ _ _ _ | .tryResult _ _ _ _
  | .tryOption _ _ _ _ | .tryResultDie _ _ _ _ _ _ _ _
  | .tryOptionDie _ _ _ _ _ _ | .withE _ _ _ | .lazyE _
  | .handleE _ _ | .resume _ _ => .boundary

/-- 型検査済みの一つの式の出現。型とキーは元の表層との対応で供給する。 -/
structure EvalInput where
  source : Expr
  type : Ty
  key : OperationKey

/-- 対象の整数・Boolean・Unitと、内部を読まない値。Rangeの三欄も保存する。 -/
inductive ConcreteValue where
  | integer (value : Integer64Value)
  | integer8 (value : IntegerValue .integer8)
  | integer16 (value : IntegerValue .integer16)
  | integer32 (value : IntegerValue .integer32)
  | unsignedInteger16 (value : IntegerValue .unsignedInteger16)
  | unsignedInteger32 (value : IntegerValue .unsignedInteger32)
  | unsignedInteger64 (value : IntegerValue .unsignedInteger64)
  | boolean (value : Bool)
  | unit
  | other (type : Ty) (notInteger : IntKind.ofType type = none)
      (notBoolean : type ≠ .base .boolean) (notUnit : type ≠ .base .unit)
  | rangeError (owner : DataName) (name : ConName) (error : Checked.Range.RangeError)
  | con (owner : DataName) (types : List Ty) (name : ConName) (args : List ConcreteValue)

/-- 型内の任意の対象整数は必ずその幅の有界な具体整数で表す。 -/
def ConcreteValue.type : ConcreteValue → Ty
  | .integer _ => .base .integer
  | .integer8 _ => .base .integer8
  | .integer16 _ => .base .integer16
  | .integer32 _ => .base .integer32
  | .unsignedInteger16 _ => .base .unsignedInteger16
  | .unsignedInteger32 _ => .base .unsignedInteger32
  | .unsignedInteger64 _ => .base .unsignedInteger64
  | .boolean _ => .base .boolean
  | .unit => .base .unit
  | .other t _ _ _ => t
  | .rangeError owner _ _ => .data owner []
  | .con owner ts _ _ => .data owner ts

/-- 幅ごとの有界な整数を、対応する具体値の構成子へ写す。 -/
def ConcreteValue.ofInteger : (kind : IntKind) → IntegerValue kind → ConcreteValue
  | .integer64, value => .integer value
  | .integer8, value => .integer8 value
  | .integer16, value => .integer16 value
  | .integer32, value => .integer32 value
  | .unsignedInteger16, value => .unsignedInteger16 value
  | .unsignedInteger32, value => .unsignedInteger32 value
  | .unsignedInteger64, value => .unsignedInteger64 value

/-- 具体整数を作っても整数の幅は変わらない。 -/
@[simp] theorem ConcreteValue.ofInteger_type (kind : IntKind) (value : IntegerValue kind) :
    (ofInteger kind value).type = kind.type := by cases kind <;> rfl

/-- 同じ幅の具体整数の等しさは、数学上の整数の等しさに一致する。 -/
@[simp] theorem ConcreteValue.ofInteger_inj (kind : IntKind) (a b : IntegerValue kind) :
    ofInteger kind a = ofInteger kind b ↔ a = b := by
  cases kind <;> simp only [ofInteger] <;> constructor <;> intro h <;> cases h <;> rfl

/-- 幅と数学上の整数を保って、既存のパターン照合の定数へ写す。 -/
def IntegerValue.toConst : (kind : IntKind) → IntegerValue kind → Const
  | .integer64, value => .integer value
  | .integer8, value => .integer8 value.toInt
  | .integer16, value => .integer16 value.toInt
  | .integer32, value => .integer32 value.toInt
  | .unsignedInteger16, value => .unsignedInteger16 value.toInt
  | .unsignedInteger32, value => .unsignedInteger32 value.toInt
  | .unsignedInteger64, value => .unsignedInteger64 value.toInt

/-- パターン照合に渡す値にも、元の整数の幅を残す。 -/
def integerPatternValue (kind : IntKind) (value : IntegerValue kind) : Val :=
  .const (IntegerValue.toConst kind value)

/-- Integer64以外の整数に認めるパターンは、変数とワイルドカードである。
定数・範囲・構造のパターンからは照合成功を作らない。 -/
def widthPatternMatch (pattern : Pattern) (kind : IntKind) (value : IntegerValue kind) :
    Option (List Val) :=
  match pattern with
  | .wild => some []
  | .var => some [integerPatternValue kind value]
  | _ => none

/-- 実行時の失敗とAPIが返すErrorの原因。 -/
inductive Failure where
  | unknown | overflow | zeroDivisor | outsideDomain
  | invalidBounds (lo hi : Int)
  | outOfRange (lo hi value : Int)
  deriving DecidableEq, Repr

/-- returnは正常な式の値と区別し、以後の式を評価しない。 -/
inductive EvalOutcome where
  | normal (value : ConcreteValue)
  | failed (reason : Failure)
  | returned (value : ConcreteValue)

/-- 実交換の宣言から得る、成功値の所有元とレコード構成子。 -/
structure RangeRecord where
  owner : DataName
  constructor : ConName
  deriving DecidableEq, BEq

/-- RangeとResultの名前は解決済みの標準宣言の同一性を表す。 -/
structure RangeNames where
  owner : DataName
  checkedConstructor : ConName
  result : DataName
  error : DataName
  ok : ConName
  err : ConName
  invalidBounds : ConName
  outOfRange : ConName

/-- 表示名から構成子を推測せず、交換された二つの同一性を渡す。 -/
def RangeNames.record (names : RangeNames) : RangeRecord :=
  ⟨names.owner, names.checkedConstructor⟩

/-- 三欄には実値だけを置く。検査キーと束縛番号は由来の関係で扱う。 -/
def rangePayload (record : RangeRecord) (lo hi value : Integer64Value) : ConcreteValue :=
  .con record.owner [] record.constructor [.integer lo, .integer hi, .integer value]

/-- 所有元・構成子・型引数・三欄の型を認定できる場合だけ value を読む。 -/
def rangeStoredValue (record : RangeRecord) : ConcreteValue → Option Integer64Value
  | .con owner [] constructor [.integer _, .integer _, .integer value] =>
      if owner = record.owner ∧ constructor = record.constructor then some value else none
  | _ => none

/-- 認定した三欄の射影は保存した整数そのものである。 -/
@[simp] theorem range_payload_stored (record : RangeRecord) (lo hi value : Integer64Value) :
    rangeStoredValue record (rangePayload record lo hi value) = some value := by
  simp [rangeStoredValue, rangePayload]

/-- 標準束縛に付ける評価規則。固定域の位置はソース順ではなく契約上の位置。 -/
inductive StandardRule where
  | rangeCheck (names : RangeNames)
  | rangeValue (record : RangeRecord)
  | fixedDomain (argument : Nat) (lo hi : Int) (result : Ty)
/-- 親の結果型に依存しない失敗・return を接続する固定域の規則。 -/
def StandardRule.isFixed : StandardRule → Bool
  | .fixedDomain .. => true
  | _ => false

/-- 呼び出し名の字面から評価規則を推測せず、解決済みの表を使う。 -/
structure StandardBinding where
  declaration : FunName
  rule : StandardRule
  argumentTypes : List Ty := []

/-- APIの拒否は、そのAPIに応じてResult.Errorか実行時の失敗へ移す。 -/
inductive OperationResult where
  | normal (value : ConcreteValue)
  | rejected (reason : Failure)

/-- 数学上の和を検査し、値域内のときだけ言語の正常値を作る。 -/
def IntKind.checkedAdd (kind : IntKind) (left right : IntegerValue kind) : OperationResult :=
  let sum := left.toInt + right.toInt
  if bounded : kind.min ≤ sum ∧ sum ≤ kind.max then
    .normal (.ofInteger kind ⟨sum, bounded⟩)
  else .rejected .overflow

/-- 既存のInteger64の評価は、共通の検査付き加算を特殊化する。 -/
def checkedAdd (left right : Integer64Value) : OperationResult :=
  let sum := left.toInt + right.toInt
  if bounded : min64 ≤ sum ∧ sum ≤ max64 then
    .normal (.integer ⟨sum, bounded⟩)
  else .rejected .overflow

/-- 数学上の差を型の値域で検査する。符号なしの下限も0として検査する。 -/
def IntKind.checkedSub (kind : IntKind) (left right : IntegerValue kind) : OperationResult :=
  let difference := left.toInt - right.toInt
  if bounded : kind.min ≤ difference ∧ difference ≤ kind.max then
    .normal (.ofInteger kind ⟨difference, bounded⟩)
  else .rejected .overflow

/-- 数学上の積を検査する。最大u64同士の積もIntのまま比較する。 -/
def IntKind.checkedMul (kind : IntKind) (left right : IntegerValue kind) : OperationResult :=
  let product := left.toInt * right.toInt
  if bounded : kind.min ≤ product ∧ product ≤ kind.max then
    .normal (.ofInteger kind ⟨product, bounded⟩)
  else .rejected .overflow

/-- Integer64 の減算を共通の検査付き演算へ接続する。 -/
def checkedSub (left right : Integer64Value) : OperationResult :=
  IntKind.checkedSub .integer64 left right

/-- Integer64 の積を共通の検査付き演算へ接続する。 -/
def checkedMul (left right : Integer64Value) : OperationResult :=
  IntKind.checkedMul .integer64 left right

/-- 負号は符号付き四種だけに定義する。最小値の負号も値域で検査する。 -/
def IntKind.checkedNeg (kind : IntKind) (_signed : kind.min < 0)
    (value : IntegerValue kind) : OperationResult :=
  let negative := -value.toInt
  if bounded : kind.min ≤ negative ∧ negative ≤ kind.max then
    .normal (.ofInteger kind ⟨negative, bounded⟩)
  else .rejected .overflow

/-- Integer64 の負号を共通の検査付き演算へ接続する。 -/
def checkedNeg (value : Integer64Value) : OperationResult :=
  IntKind.checkedNeg .integer64 (by decide) value

/-- 実数の `/` を除き、整数の商と剰余だけを除数0の対象にする。 -/
def IntegerDivisionOp (op : BinOp) : Prop := op = .intDiv ∨ op = .mod

instance (op : BinOp) : Decidable (IntegerDivisionOp op) :=
  inferInstanceAs (Decidable (op = .intDiv ∨ op = .mod))

/-- 非零の除数の剰余は、商が表現できない場合も同じ整数型に収まる。 -/
theorem IntKind.tmod_bounds (kind : IntKind) (left right : IntegerValue kind)
    (nonzero : right.toInt ≠ 0) :
    kind.min ≤ left.toInt.tmod right.toInt ∧
      left.toInt.tmod right.toInt ≤ kind.max := by
  have bounds := right.toInt_bounds
  have leftBounds := left.toInt_bounds
  have nonneg : 0 ≤ left.toInt → 0 ≤ left.toInt.tmod right.toInt :=
    Int.tmod_nonneg _
  by_cases positive : 0 < right.toInt
  · have low := Int.lt_tmod_of_pos left.toInt positive
    have high := Int.tmod_lt_of_pos left.toInt positive
    cases kind <;> simp only [IntKind.min, IntKind.max, min64, max64] at * <;> omega
  · have low := Int.lt_tmod_of_pos left.toInt (b := -right.toInt) (by omega)
    have high := Int.tmod_lt_of_pos left.toInt (b := -right.toInt) (by omega)
    rw [Int.tmod_neg] at low high
    cases kind <;> simp only [IntKind.min, IntKind.max, min64, max64] at * <;> omega

/-- Integer64の剰余の表現可能性は共通の補題から得る。 -/
theorem tmod_bounds (left right : Integer64Value) (nonzero : right.toInt ≠ 0) :
    min64 ≤ left.toInt.tmod right.toInt ∧ left.toInt.tmod right.toInt ≤ max64 :=
  IntKind.tmod_bounds .integer64 left right nonzero

/-- 商は0方向へ切り捨て、剰余は数学上の商から求める。0を先に拒否する。 -/
def IntKind.checkedDivMod (kind : IntKind) (op : BinOp)
    (left right : IntegerValue kind) : OperationResult :=
  if IntegerDivisionOp op then
    if zero : right.toInt = 0 then .rejected .zeroDivisor
    else if op = .mod then
      .normal (.ofInteger kind ⟨left.toInt.tmod right.toInt,
        kind.tmod_bounds left right zero⟩)
    else
      let quotient := left.toInt.tdiv right.toInt
      if bounded : kind.min ≤ quotient ∧ quotient ≤ kind.max then
        .normal (.ofInteger kind ⟨quotient, bounded⟩)
      else .rejected .overflow
  else .rejected .unknown

/-- 既存のInteger64の評価は、共通の検査付き除算・剰余を特殊化する。 -/
def checkedDivMod (op : BinOp) (left right : Integer64Value) : OperationResult :=
  if IntegerDivisionOp op then
    if zero : right.toInt = 0 then .rejected .zeroDivisor
    else if op = .mod then
      .normal (.integer ⟨left.toInt.tmod right.toInt, tmod_bounds left right zero⟩)
    else
      let quotient := left.toInt.tdiv right.toInt
      if bounded : min64 ≤ quotient ∧ quotient ≤ max64 then
        .normal (.integer ⟨quotient, bounded⟩)
      else .rejected .overflow
  else .rejected .unknown

/-- 算術の拒否はResult値に包まず、その式の失敗にする。 -/
def OperationResult.outcome : OperationResult → EvalOutcome
  | .normal value => .normal value
  | .rejected reason => .failed reason

/-- 子の失敗とreturnは親の演算へ進まない。 -/
def EvalOutcome.Abrupt : EvalOutcome → Prop
  | .normal _ => False
  | .failed _ | .returned _ => True

/-- Rangeの入力は最初からInteger64であり、逆転を所属より先に調べる。 -/
def rangeCheck (names : RangeNames) (_key : OperationKey)
    (lo hi value : Integer64Value) : OperationResult :=
  match Checked.Range.make lo.toInt hi.toInt value.toInt with
  | .ok _ => .normal (rangePayload names.record lo hi value)
  | .error (.invalidBounds l h) => .rejected (.invalidBounds l h)
  | .error (.outOfRange l h n) => .rejected (.outOfRange l h n)

/-- 標準束縛の評価。固定域内でもIOなど他の失敗を許し、成功までは主張しない。 -/
inductive EvalStandard : StandardRule → OperationKey → List ConcreteValue →
    OperationResult → Prop where
  | rangeCheck (names key lo hi value) :
      EvalStandard (.rangeCheck names) key [.integer lo, .integer hi, .integer value]
        (rangeCheck names key lo hi value)
  | rangeValue (record key input value)
      (stored : rangeStoredValue record input = some value) :
      EvalStandard (.rangeValue record) key [input] (.normal (.integer value))
  -- 未認定の表現は任意の正常整数と失敗を許す。some の正確な射影とは排他的である。
  | rangeValueUnknown (record key input value)
      (unknown : rangeStoredValue record input = none) :
      EvalStandard (.rangeValue record) key [input] (.normal (.integer value))
  | rangeValueUnknownFailed (record key input)
      (unknown : rangeStoredValue record input = none) :
      EvalStandard (.rangeValue record) key [input] (.rejected .unknown)
  | domainNormal (position lo hi result key args value output)
      (atPosition : args[position]? = some (.integer value))
      (inside : lo ≤ value.toInt ∧ value.toInt ≤ hi)
      (typed : output.type = result) :
      EvalStandard (.fixedDomain position lo hi result) key args (.normal output)
  | domainOtherFailure (position lo hi result key args value)
      (atPosition : args[position]? = some (.integer value))
      (inside : lo ≤ value.toInt ∧ value.toInt ≤ hi) :
      EvalStandard (.fixedDomain position lo hi result) key args (.rejected .unknown)
  | domainRejected (position lo hi result key args value)
      (atPosition : args[position]? = some (.integer value))
      (outside : ¬ (lo ≤ value.toInt ∧ value.toInt ≤ hi)) :
      EvalStandard (.fixedDomain position lo hi result) key args (.rejected .outsideDomain)

/-- RangeのAPIの成否を通常のResult値として保持する。 -/
def StandardRule.finish : StandardRule → OperationResult → EvalOutcome
  | .rangeCheck names, .normal value =>
      .normal (.con names.result [.data names.owner [], .data names.error []] names.ok [value])
  | .rangeCheck names, .rejected (.invalidBounds lo hi) =>
      .normal (.con names.result [.data names.owner [], .data names.error []] names.err
        [.rangeError names.error names.invalidBounds (.invalidBounds lo hi)])
  | .rangeCheck names, .rejected (.outOfRange lo hi value) =>
      .normal (.con names.result [.data names.owner [], .data names.error []] names.err
        [.rangeError names.error names.outOfRange (.outOfRange lo hi value)])
  | _, .normal value => .normal value
  | _, .rejected reason => .failed reason

/-- 正常に得た引数を持つ対象演算。 -/
inductive TargetOperation where
  | binary (op : BinOp) (operandType : Ty)
  | neg (operandType : Ty)
  | standard (binding : StandardBinding)

/-- traceは演算のキー・正常引数・その演算の結果を保存する。 -/
structure EvalEvent where
  key : OperationKey
  operation : TargetOperation
  arguments : List ConcreteValue
  result : OperationResult

/-- 実行順に並ぶ到達記録。未対応式の部分木には記録を作らない。 -/
abbrev EvalTrace := List EvalEvent

/-- 通常の局所値と解決済みの標準束縛表。専用builder位置は値なしで保持する。 -/
structure ConcreteEnv where
  locals : List (Option ConcreteValue)
  standards : List StandardBinding
  apiAt : OperationKey → Option FunName

/-- 出現位置の同定結果を標準束縛表で引く。表にない宣言には規則を付けない。 -/
def ConcreteEnv.standardAt (env : ConcreteEnv) (key : OperationKey) : Option StandardBinding := do
  let declaration ← env.apiAt key
  env.standards.find? (fun binding => binding.declaration == declaration)

/-- 型引数・エフェクト引数のない標準関数と組み込み関数の直接 call の頭だけを読む。 -/
def standardCallHead : Expr → Option FunName
  | .funName declaration [] [] | .primName declaration [] [] [] => some declaration
  | _ => none

/-- Range と固定域の標準宣言を、元のキー・宣言・引数位置で認定する。 -/
def rangeCallBinding (env : ConcreteEnv) (input : EvalInput) : Option StandardBinding := do
  match input.source with
  | .call callee labels positions arguments =>
    let declaration ← standardCallHead callee
    let binding ← env.standardAt input.key
    if declaration ≠ binding.declaration then none else
      match binding.rule with
      | .rangeCheck _ =>
        if (match callee with | .funName _ [] [] => true | _ => false : Bool) = true ∧ labels.length = 3 ∧ positions.Perm [0, 1, 2] ∧
            (exprsChildren arguments).length = 3 then some binding else none
      | .rangeValue _ =>
        if (match callee with | .funName _ [] [] => true | _ => false : Bool) = true ∧ labels.length = 1 ∧ positions = [0] ∧
            (exprsChildren arguments).length = 1 then some binding else none
      | .fixedDomain argument _ _ _ =>
        if (match binding.argumentTypes[argument]? with | some (.base .integer) => true | _ => false : Bool) = true ∧
            labels.length = binding.argumentTypes.length ∧
            positions.Perm (List.range binding.argumentTypes.length) ∧
            (exprsChildren arguments).length = positions.length then some binding else none
  | _ => none

/-- 認定した呼び出しの引数型をソース順にする。check の三位置は同じ整数型である。 -/
def StandardRule.argumentType : StandardRule → Ty
  | .rangeValue record => .data record.owner []
  | _ => .base .integer

/-- 標準規則の正常な戻り値の型。API の拒否を包む Result も通常の値である。 -/
def StandardRule.resultType : StandardRule → Ty
  | .rangeCheck names => .data names.result [.data names.owner [], .data names.error []]
  | .rangeValue _ => .base .integer
  | .fixedDomain _ _ _ result => result

/-- 契約上の引数型をソース順の位置へ写す。 -/
def StandardBinding.sourceTypes (binding : StandardBinding) (positions : List Nat) : List Ty :=
  match binding.rule with
  | .rangeCheck _ | .rangeValue _ => List.replicate positions.length binding.rule.argumentType
  | _ => positions.map fun position => binding.argumentTypes[position]?.getD (.base .unit)

/-- 正常終了した場合だけ、値の型が評価の入力型と一致することを要求する。 -/
def NormalTyped (type : Ty) : EvalOutcome → Prop
  | .normal value => value.type = type
  | _ => True


/-- 標準規則の正常結果は、Result の包装を含め、その規則の戻り値の型を持つ。 -/
theorem standard_result_typed {rule key arguments result}
    (evaluated : EvalStandard rule key arguments result) :
    NormalTyped rule.resultType (rule.finish result) := by
  cases evaluated with
  | rangeCheck names key lo hi value =>
      cases made : Checked.Range.make lo.toInt hi.toInt value.toInt with
      | ok checked => simp [NormalTyped, rangeCheck, made, StandardRule.finish,
          StandardRule.resultType, ConcreteValue.type]
      | error error =>
        cases error <;> simp [NormalTyped, rangeCheck, made, StandardRule.finish,
          StandardRule.resultType, ConcreteValue.type]
  | rangeValue => rfl
  | rangeValueUnknown => rfl
  | rangeValueUnknownFailed => trivial
  | domainOtherFailure => trivial
  | domainRejected => trivial
  | domainNormal _ _ _ _ _ _ _ _ _ _ typed => exact typed
/-- 正常に得た値だけを契約上の位置へ並べ直す。欠落・重複のある位置は認定しない。 -/
def orderArguments (positions : List Nat) (values : List ConcreteValue) :
    Option (List ConcreteValue) :=
  (List.range positions.length).mapM fun position => fieldAt position positions values

/-- 引数列の途中の失敗・return を、正常な値の列と区別する。 -/
inductive ArgumentOutcome where
  | normal (values : List ConcreteValue)
  | abrupt (outcome : EvalOutcome)

/-- 境界の式と未知の値・名前には、外の事実を持ち込まない。 -/
def Unsupported (e : Expr) : Prop :=
  classify e = .boundary ∨ classify e = .unknownValue

/-- returnはオペランドの正常終了だけをreturnedへ変える。 -/
def returnOutcome : EvalOutcome → EvalOutcome
  | .normal value => .returned value
  | .failed reason => .failed reason
  | .returned value => .returned value

/-- 六比較だけを表し、算術演算子と混同しない。 -/
inductive Comparison where
  | eq | ne | lt | le | gt | ge
  deriving DecidableEq, Repr

/-- 数学上の整数の単一比較。 -/
def Comparison.Holds : Comparison → Int → Int → Prop
  | .eq, x, k => x = k
  | .ne, x, k => x ≠ k
  | .lt, x, k => x < k
  | .le, x, k => x ≤ k
  | .gt, x, k => x > k
  | .ge, x, k => x ≥ k

instance (op : Comparison) (x k : Int) : Decidable (op.Holds x k) := by
  cases op <;> unfold Comparison.Holds <;> infer_instance

/-- 表層の六比較を認定する。型の照合は comparisonAt で行う。 -/
def Comparison.ofBinOp : BinOp → Option Comparison
  | .eq => some .eq | .ne => some .ne | .lt => some .lt
  | .le => some .le | .gt => some .gt | .ge => some .ge
  | _ => none

/-- 比較の構文上の演算子。認定と評価で同じ六種類を使う。 -/
def Comparison.binOp : Comparison → BinOp
  | .eq => .eq | .ne => .ne | .lt => .lt
  | .le => .le | .gt => .gt | .ge => .ge

@[simp] theorem Comparison.ofBinOp_binOp (op : Comparison) :
    Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl

/-- 既存のInteger64の型も、幅付き型と同じ種類の認定へ接続する。 -/
@[simp] theorem IntKind.ofType_integer64 :
    IntKind.ofType (.base .integer) = some .integer64 := rfl

/-- 現 profile に具体規則のない形。後の profile で規則を接続するときに外す。 -/
def Unmodeled : Expr → Prop
  | .literal (.integer _) | .literal (.boolean _) => False
  | .literal (.integer8 value) => ¬ (IntKind.min .integer8 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .integer8)
  | .literal (.integer16 value) => ¬ (IntKind.min .integer16 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .integer16)
  | .literal (.integer32 value) => ¬ (IntKind.min .integer32 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .integer32)
  | .literal (.unsignedInteger16 value) => ¬ (IntKind.min .unsignedInteger16 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .unsignedInteger16)
  | .literal (.unsignedInteger32 value) => ¬ (IntKind.min .unsignedInteger32 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .unsignedInteger32)
  | .literal (.unsignedInteger64 value) => ¬ (IntKind.min .unsignedInteger64 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .unsignedInteger64)
  | .literal _ => True
  | .binary op type _ _ => ¬ ((IntKind.ofType type).isSome = true ∧
      (op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨
        (Comparison.ofBinOp op).isSome = true))
  | .neg type _ => match IntKind.ofType type with
      | some kind => ¬ kind.min < 0
      | none => True
  | .negInteger8 value => ¬ (IntKind.min .integer8 ≤ -(value : Int) ∧
      -(value : Int) ≤ IntKind.max .integer8)
  | .negInteger16 value => ¬ (IntKind.min .integer16 ≤ -(value : Int) ∧
      -(value : Int) ≤ IntKind.max .integer16)
  | .negInteger32 value => ¬ (IntKind.min .integer32 ≤ -(value : Int) ∧
      -(value : Int) ≤ IntKind.max .integer32)
  | .record .. | .recordUpdate .. => True
  | _ => False

/-- 現 profile の未対応形と、表に同定がない API を未知として扱う。 -/
def UnknownAt (env : ConcreteEnv) (input : EvalInput) : Prop :=
  Unsupported input.source ∨ Unmodeled input.source ∨
    (match input.source with
     | .call .. => rangeCallBinding env input = none
     | _ => classify input.source = .api ∧ env.standardAt input.key = none)

/-- 比較は有界整数を数学上の整数として比べ、正常なBooleanを返す。 -/
def checkedCompare (op : Comparison) (a b : Integer64Value) : OperationResult :=
  .normal (.boolean (decide (op.Holds a.toInt b.toInt)))

/-- 幅付き整数の比較も数学上の整数で行う。 -/
def IntKind.checkedCompare (kind : IntKind) (op : Comparison)
    (a b : IntegerValue kind) : OperationResult :=
  .normal (.boolean (decide (op.Holds a.toInt b.toInt)))

/-- 六幅に共通する整数二項演算。比較の結果型だけを区別する。 -/
inductive WidthBinary where
  | add | sub | mul | intDiv | mod | compare (op : Comparison)

/-- 共通演算が表す表層の演算子。 -/
def WidthBinary.op : WidthBinary → BinOp
  | .add => .add | .sub => .sub | .mul => .mul
  | .intDiv => .intDiv | .mod => .mod | .compare op => op.binOp

/-- 算術は元の幅、比較はBooleanを返す。 -/
def WidthBinary.type : WidthBinary → IntKind → Ty
  | .compare _, _ => .base .boolean | _, kind => kind.type

/-- 同じ幅の二値に共通の検査付き演算を適用する。 -/
def WidthBinary.apply : (op : WidthBinary) → (kind : IntKind) →
    IntegerValue kind → IntegerValue kind → OperationResult
  | .add, kind => kind.checkedAdd | .sub, kind => kind.checkedSub
  | .mul, kind => kind.checkedMul | .intDiv, kind => kind.checkedDivMod .intDiv
  | .mod, kind => kind.checkedDivMod .mod | .compare op, kind => kind.checkedCompare op

/-- 共通演算の各構成子は、対象として列挙した演算子に限られる。 -/
@[simp] theorem WidthBinary.supported (op : WidthBinary) :
    op.op = .add ∨ op.op = .sub ∨ op.op = .mul ∨ IntegerDivisionOp op.op ∨
      (Comparison.ofBinOp op.op).isSome = true := by
  cases op <;> simp [WidthBinary.op, IntegerDivisionOp]

/-- 共通演算に接続した形は、未知の二項演算として扱わない。 -/
@[simp] theorem WidthBinary.modeled (op : WidthBinary) (kind : IntKind) (left right : Expr) :
    ¬ Unmodeled (.binary op.op kind.type left right) := by
  cases op <;> simp [Unmodeled, WidthBinary.op, IntegerDivisionOp]

/-- Integer64以外の整数の型がInteger64と一致することはない。 -/
theorem IntKind.type_ne_integer {kind : IntKind} (not64 : kind ≠ .integer64) :
    kind.type ≠ .base .integer := by
  cases kind <;> simp_all [IntKind.type]

/-- Blockの先頭の式から、評価し終えた部分木の個数だけ番号を進める。 -/
def advanceKey (key : OperationKey) (size : Nat) : OperationKey :=
  ⟨key.definition, key.surfacePreorder + size⟩

/-- Blockが占める番号の個数。容器自身は数えない。 -/
def blockSize (body : Block) : Nat := ((blockChildren body).map surfaceSize).sum

/-- 束縛・discardの末尾は正常値だけをUnitにし、失敗とreturnを保つ。 -/
def discardOutcome : EvalOutcome → EvalOutcome
  | .normal _ => .normal .unit
  | outcome => outcome

/-- パターン位置の具体値。構造の照合は抽象化し、通常値の位置と個数を保つ。
valuesはde Bruijn順。単独の変数は右辺そのもの、wildは位置を増やさない。 -/
def PatternLocals (pattern : Pattern) (value : ConcreteValue)
    (values : List ConcreteValue) : Prop :=
  match pattern with
  | .var => values = [value]
  | .wild => values = []
  | _ => values.length = pattern.binders

/-- パターン束縛で増える通常位置は、表層の束縛数と一致する。 -/
theorem patternLocals_length {pattern value values}
    (bindings : PatternLocals pattern value values) : values.length = pattern.binders := by
  cases pattern <;> simp_all [PatternLocals, Pattern.binders, Pattern.toCore, Release.Pat.binders]

/-- Blockの大きさと、式の子の列の大きさを結ぶ。 -/
@[simp] theorem surfaceSize_block (body : Block) :
    surfaceSize (.block body) = 1 + blockSize body := by
  simp [surfaceSize_children, children, blockSize]

/-- guard と腕本体の番号範囲。容器は番号を使わない。 -/
def guardSize (guard : Option Expr) : Nat :=
  (guard.map surfaceSize).getD 0

/-- 腕の全ての出現の個数。 -/
def armsSize (arms : Arms) : Nat := (preorderArms arms).length

/-- 各腕は guard、本体、残りの腕の順に番号範囲を占める。 -/
@[simp] theorem armsSize_cons (alts guard body rest) :
    armsSize (.cons alts guard body rest) = guardSize guard + blockSize body + armsSize rest := by
  have length : (preorderBlock body).length = blockSize body := by
    have h := surfaceSize_block body
    simpa [surfaceSize, surfacePreorder, Nat.add_comm] using h
  cases guard <;> simp [length, armsSize, guardSize, preorderArms, blockSize,
    surfaceSize, Nat.add_assoc]

/-- match の根と照合値に、容器を数えない腕の大きさを続ける。 -/
@[simp] theorem surfaceSize_matchE (type source arms) :
    surfaceSize (.matchE type source arms) = 1 + surfaceSize source + armsSize arms := by
  simp [surfaceSize, surfacePreorder, armsSize, Nat.add_comm, Nat.add_left_comm]

/-- 整数の最初の照合成功。型検査済みの共通束縛数と slots の成功も保持する。
raw は左からの束縛順、selected は腕の宣言順である。 -/
def IntegerSelection (alts : List Alternative) (value : Integer64Value)
    (selected : List ConcreteValue) : Prop :=
  ∃ before alt after raw bindings,
    alts = before ++ alt :: after ∧
    (∀ prior ∈ before, prior.pat.toCore.matchVal (.const (.integer value)) = none) ∧
    alt.pat.toCore.matchVal (.const (.integer value)) = some bindings ∧
    PatternLocals alt.pat (.integer value) raw.reverse ∧
    selectSlots raw alt.slots = some selected ∧
    alt.slots.length = (alts.head?.map fun first => first.slots.length).getD 0

/-- 整数の最初の照合成功。型検査済みの共通束縛数と slots の成功も保持する。
raw は左からの束縛順、selected は腕の宣言順である。 -/
def WidthSelection (alts : List Alternative) (kind : IntKind) (value : IntegerValue kind)
    (selected : List ConcreteValue) : Prop :=
  ∃ before alt after raw bindings,
    alts = before ++ alt :: after ∧
    (∀ prior ∈ before, widthPatternMatch prior.pat kind value = none) ∧
    widthPatternMatch alt.pat kind value = some bindings ∧
    PatternLocals alt.pat (.ofInteger kind value) raw.reverse ∧
    selectSlots raw alt.slots = some selected ∧
    alt.slots.length = (alts.head?.map fun first => first.slots.length).getD 0

/-- Range と組になる Result.Ok の所有元・型引数・構成子を全て照合する。
同じ表示名だけの構成子や、内部を読まない other を成功値に変えない。 -/
inductive RangeNames.IsOk (names : RangeNames) : ConcreteValue → ConcreteValue → Prop where
  | intro (value : ConcreteValue) (typed : value.type = .data names.owner []) :
      names.IsOk (.con names.result [.data names.owner [], .data names.error []]
        names.ok [value]) value

/-- 内部を読まない other の Result からの Ok 抽出にも導出を残すが、三欄を仮定しない。
既知の Result の場合は IsOk そのものを使い、任意値を混ぜない。 -/
inductive RangeNames.OkPayload (names : RangeNames) : ConcreteValue → ConcreteValue → Prop where
  | known {result payload} (matched : names.IsOk result payload) : names.OkPayload result payload
  | other (notInteger notBoolean notUnit) (payload : ConcreteValue)
      (typed : payload.type = .data names.owner []) :
      names.OkPayload (.other (.data names.result [.data names.owner [], .data names.error []])
        notInteger notBoolean notUnit) payload

/-- 解決済みの標準表から、Result の所有元と二つの型引数を照合する。 -/
def rangeResultNames (env : ConcreteEnv) (type : Ty) : Option RangeNames :=
  env.standards.findSome? fun binding =>
    match binding.rule, type with
    | .rangeCheck names, .data result [.data owner [], .data error []] =>
      if result = names.result ∧ owner = names.owner ∧ error = names.error ∧ names.ok ≠ names.err
      then some names else none
    | _, _ => none

/-- 既知の構成子は同じ中身を取り出す。other の Result は両構成子を許す。 -/
inductive RangeNames.ResultView (names : RangeNames) :
    ConcreteValue → ConName → ConcreteValue → Prop where
  | ok (payload : ConcreteValue) (typed : payload.type = .data names.owner []) :
      names.ResultView (.con names.result [.data names.owner [], .data names.error []]
        names.ok [payload]) names.ok payload
  | error (payload : ConcreteValue) (typed : payload.type = .data names.error []) :
      names.ResultView (.con names.result [.data names.owner [], .data names.error []]
        names.err [payload]) names.err payload
  | otherOk (notInteger notBoolean notUnit) (payload : ConcreteValue)
      (typed : payload.type = .data names.owner []) :
      names.ResultView (.other (.data names.result [.data names.owner [], .data names.error []])
        notInteger notBoolean notUnit) names.ok payload
  | otherError (notInteger notBoolean notUnit) (payload : ConcreteValue)
      (typed : payload.type = .data names.error []) :
      names.ResultView (.other (.data names.result [.data names.owner [], .data names.error []])
        notInteger notBoolean notUnit) names.err payload

/-- Result の具体規則と整数の具体規則は重ならない。 -/
theorem range_result_view_noninteger {names result tag payload}
    (view : RangeNames.ResultView names result tag payload) :
    ∀ kind integer, result ≠ .ofInteger kind integer := by
  intro kind integer
  cases view <;> cases kind <;> intro h <;> cases h

/-- 任意の con は Result の型でも不正な内部表現を取り得るため、未知を残す。
型の合う一引数の Ok/Error と other だけを具体化する。 -/
def rangeResultViewable (names : RangeNames) : ConcreteValue → Bool
  | .other .. => true
  | .con _ _ tag [payload] =>
    if tag = names.ok then
      match payload.type with | .data owner [] => owner == names.owner | _ => false
    else if tag = names.err then
      match payload.type with | .data error [] => error == names.error | _ => false
    else false
  | _ => false

/-- この profile で中身を同定できる Result のパターン。 -/
def rangeResultPattern (names : RangeNames) : Pattern → Bool
  | .wild | .var => true
  | .con qualifier tag [.var] | .con qualifier tag [.wild] =>
      (qualifier.isNone || qualifier == some names.result) &&
        (tag == names.ok || tag == names.err)
  | _ => false

/-- 一部だけ具体化して他の腕の導出を失わないよう、全腕のパターンを照合する。 -/
def rangeResultArms (names : RangeNames) : Arms → Bool
  | .nil => true
  | .cons alts _ _ rest => alts.all (fun alt => rangeResultPattern names alt.pat) &&
      rangeResultArms names rest

/-- 具体化する Result の match。未対応のパターン・表現は従来の近似に残す。 -/
def rangeResultMatch (env : ConcreteEnv) (value : ConcreteValue) (arms : Arms) : Option RangeNames := do
  let names ← rangeResultNames env value.type
  if rangeResultViewable names value && rangeResultArms names arms then some names else none

/-- 束縛する実値を返す。構造パターンの束縛数だけから中身を推測しない。 -/
def resultPatternMatch (names : RangeNames) (result : ConcreteValue)
    (tag : ConName) (payload : ConcreteValue) : Pattern → Option (List ConcreteValue)
  | .wild => some []
  | .var => some [result]
  | .con qualifier expected [.var] =>
      if (qualifier.isNone || qualifier == some names.result) && expected == tag
      then some [payload] else none
  | .con qualifier expected [.wild] =>
      if (qualifier.isNone || qualifier == some names.result) && expected == tag
      then some [] else none
  | _ => none

/-- 左から最初に成功した選択肢を選び、slots を腕の宣言順へ並べる。 -/
def ResultSelection (names : RangeNames) (result : ConcreteValue) (tag : ConName)
    (payload : ConcreteValue) (alts : List Alternative) (selected : List ConcreteValue) : Prop :=
  ∃ before alt after raw,
    alts = before ++ alt :: after ∧
    (∀ prior ∈ before, resultPatternMatch names result tag payload prior.pat = none) ∧
    resultPatternMatch names result tag payload alt.pat = some raw ∧
    selectSlots raw alt.slots = some selected ∧
    alt.slots.length = (alts.head?.map fun first => first.slots.length).getD 0

mutual
/-- 対象構文の評価関係。未対応の規則は子を前提に持たない。 -/
inductive EvalPartial : ConcreteEnv → EvalInput → EvalOutcome → EvalTrace → Prop where
  | standardCall (env key callee labels positions sources binding values arguments result trace)
      (recognized : rangeCallBinding env
        ⟨.call callee labels positions sources, binding.rule.resultType, key⟩ = some binding)
      (children : EvalTypedArguments env (childKey key [callee]) (exprsChildren sources)
        (binding.sourceTypes positions) (.normal values) trace)
      (ordered : orderArguments positions values = some arguments)
      (evaluated : EvalStandard binding.rule key arguments result) :
      EvalPartial env ⟨.call callee labels positions sources, binding.rule.resultType, key⟩
        (binding.rule.finish result)
        (trace ++ [⟨key, .standard binding, arguments, result⟩])
  | standardCallAbrupt (env key callee labels positions sources binding outcome trace)
      (recognized : rangeCallBinding env
        ⟨.call callee labels positions sources, binding.rule.resultType, key⟩ = some binding)
      (children : EvalTypedArguments env (childKey key [callee]) (exprsChildren sources)
        (binding.sourceTypes positions) (.abrupt outcome) trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.call callee labels positions sources, binding.rule.resultType, key⟩
        outcome trace
  | fixedCallFailed (env key callee labels positions sources binding values arguments reason type trace)
      (recognized : rangeCallBinding env ⟨.call callee labels positions sources, type, key⟩ = some binding)
      (fixed : binding.rule.isFixed = true)
      (children : EvalTypedArguments env (childKey key [callee]) (exprsChildren sources)
        (binding.sourceTypes positions) (.normal values) trace)
      (ordered : orderArguments positions values = some arguments)
      (evaluated : EvalStandard binding.rule key arguments (.rejected reason)) :
      EvalPartial env ⟨.call callee labels positions sources, type, key⟩ (.failed reason)
        (trace ++ [⟨key, .standard binding, arguments, .rejected reason⟩])
  | fixedCallAbrupt (env key callee labels positions sources binding type outcome trace)
      (recognized : rangeCallBinding env ⟨.call callee labels positions sources, type, key⟩ = some binding)
      (fixed : binding.rule.isFixed = true)
      (children : EvalTypedArguments env (childKey key [callee]) (exprsChildren sources)
        (binding.sourceTypes positions) (.abrupt outcome) trace) (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.call callee labels positions sources, type, key⟩ outcome trace
  | unknownNormal (env input value) (unsupported : UnknownAt env input)
      (typed : value.type = input.type) :
      EvalPartial env input (.normal value) []
  | unknownFailed (env input) (unsupported : UnknownAt env input) :
      EvalPartial env input (.failed .unknown) []
  | integer (env key value) :
      EvalPartial env ⟨.literal (.integer value), .base .integer, key⟩
        (.normal (.integer value.toValue)) []
  | negInt (env key value) :
      EvalPartial env ⟨.negInt value, .base .integer, key⟩
        (.normal (.integer value.negValue)) []
  -- 表層の幅付き数値は任意のNatを保持するため、値域の証拠を評価規則で要求する。
  | integer8 (env key) (value : Nat)
      (bounded : IntKind.min .integer8 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .integer8) :
      EvalPartial env ⟨.literal (.integer8 value), .base .integer8, key⟩
        (.normal (.integer8 ⟨(value : Int), bounded⟩)) []
  | integer16 (env key) (value : Nat)
      (bounded : IntKind.min .integer16 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .integer16) :
      EvalPartial env ⟨.literal (.integer16 value), .base .integer16, key⟩
        (.normal (.integer16 ⟨(value : Int), bounded⟩)) []
  | integer32 (env key) (value : Nat)
      (bounded : IntKind.min .integer32 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .integer32) :
      EvalPartial env ⟨.literal (.integer32 value), .base .integer32, key⟩
        (.normal (.integer32 ⟨(value : Int), bounded⟩)) []
  | unsignedInteger16 (env key) (value : Nat)
      (bounded : IntKind.min .unsignedInteger16 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .unsignedInteger16) :
      EvalPartial env ⟨.literal (.unsignedInteger16 value), .base .unsignedInteger16, key⟩
        (.normal (.unsignedInteger16 ⟨(value : Int), bounded⟩)) []
  | unsignedInteger32 (env key) (value : Nat)
      (bounded : IntKind.min .unsignedInteger32 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .unsignedInteger32) :
      EvalPartial env ⟨.literal (.unsignedInteger32 value), .base .unsignedInteger32, key⟩
        (.normal (.unsignedInteger32 ⟨(value : Int), bounded⟩)) []
  | unsignedInteger64 (env key) (value : Nat)
      (bounded : IntKind.min .unsignedInteger64 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .unsignedInteger64) :
      EvalPartial env ⟨.literal (.unsignedInteger64 value), .base .unsignedInteger64, key⟩
        (.normal (.unsignedInteger64 ⟨(value : Int), bounded⟩)) []
  | negInteger8 (env key) (value : Nat)
      (bounded : IntKind.min .integer8 ≤ -(value : Int) ∧ -(value : Int) ≤ IntKind.max .integer8) :
      EvalPartial env ⟨.negInteger8 value, .base .integer8, key⟩
        (.normal (.integer8 ⟨-(value : Int), bounded⟩)) []
  | negInteger16 (env key) (value : Nat)
      (bounded : IntKind.min .integer16 ≤ -(value : Int) ∧ -(value : Int) ≤ IntKind.max .integer16) :
      EvalPartial env ⟨.negInteger16 value, .base .integer16, key⟩
        (.normal (.integer16 ⟨-(value : Int), bounded⟩)) []
  | negInteger32 (env key) (value : Nat)
      (bounded : IntKind.min .integer32 ≤ -(value : Int) ∧ -(value : Int) ≤ IntKind.max .integer32) :
      EvalPartial env ⟨.negInteger32 value, .base .integer32, key⟩
        (.normal (.integer32 ⟨-(value : Int), bounded⟩)) []
  | boolean (env key value) :
      EvalPartial env ⟨.literal (.boolean value), .base .boolean, key⟩
        (.normal (.boolean value)) []
  | unit (env key) : EvalPartial env ⟨.unit, .base .unit, key⟩ (.normal .unit) []
  | local (env key index value)
      (atIndex : env.locals[index]? = some (some value)) :
      EvalPartial env ⟨.local index, value.type, key⟩ (.normal value) []
  | paren (env key source type outcome trace)
      (eval : EvalPartial env ⟨source, type, childKey key []⟩ outcome trace) :
      EvalPartial env ⟨.paren source, type, key⟩ outcome trace
  | constE (env key source type outcome trace)
      (eval : EvalPartial { env with locals := [] } ⟨source, type, childKey key []⟩ outcome trace) :
      EvalPartial env ⟨.constE type source, type, key⟩ outcome trace
  | returnE (env key resultType source type outcome trace)
      (eval : EvalPartial env ⟨source, type, childKey key []⟩ outcome trace) :
      EvalPartial env ⟨.returnE resultType source, resultType, key⟩
        (returnOutcome outcome) trace
  | neg (env key source value trace)
      (eval : EvalPartial env ⟨source, .base .integer, childKey key []⟩
        (.normal (.integer value)) trace) :
      EvalPartial env ⟨.neg (.base .integer) source, .base .integer, key⟩
        (checkedNeg value).outcome
        (trace ++ [⟨key, .neg (.base .integer), [.integer value], checkedNeg value⟩])
  | negAbrupt (env key source outcome trace)
      (eval : EvalPartial env ⟨source, .base .integer, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.neg (.base .integer) source, .base .integer, key⟩ outcome trace
  | add (env key left right a b leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩
        (.normal (.integer b)) rightTrace) :
      EvalPartial env ⟨.binary .add (.base .integer) left right, .base .integer, key⟩
        (checkedAdd a b).outcome
        (leftTrace ++ rightTrace ++
          [⟨key, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩])
  | addLeftAbrupt (env key left right outcome trace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary .add (.base .integer) left right, .base .integer, key⟩
        outcome trace
  | addRightAbrupt (env key left right a outcome leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ outcome rightTrace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary .add (.base .integer) left right, .base .integer, key⟩
        outcome (leftTrace ++ rightTrace)
  | sub (env key left right a b leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩
        (.normal (.integer b)) rightTrace) :
      EvalPartial env ⟨.binary .sub (.base .integer) left right, .base .integer, key⟩
        (checkedSub a b).outcome
        (leftTrace ++ rightTrace ++
          [⟨key, .binary .sub (.base .integer), [.integer a, .integer b], checkedSub a b⟩])
  | subLeftAbrupt (env key left right outcome trace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary .sub (.base .integer) left right, .base .integer, key⟩
        outcome trace
  | subRightAbrupt (env key left right a outcome leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ outcome rightTrace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary .sub (.base .integer) left right, .base .integer, key⟩
        outcome (leftTrace ++ rightTrace)
  | mul (env key left right a b leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩
        (.normal (.integer b)) rightTrace) :
      EvalPartial env ⟨.binary .mul (.base .integer) left right, .base .integer, key⟩
        (checkedMul a b).outcome
        (leftTrace ++ rightTrace ++
          [⟨key, .binary .mul (.base .integer), [.integer a, .integer b], checkedMul a b⟩])
  | mulLeftAbrupt (env key left right outcome trace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary .mul (.base .integer) left right, .base .integer, key⟩
        outcome trace
  | mulRightAbrupt (env key left right a outcome leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ outcome rightTrace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary .mul (.base .integer) left right, .base .integer, key⟩
        outcome (leftTrace ++ rightTrace)
  | divMod (env key op left right a b leftTrace rightTrace)
      (target : IntegerDivisionOp op)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩
        (.normal (.integer b)) rightTrace) :
      EvalPartial env ⟨.binary op (.base .integer) left right, .base .integer, key⟩
        (checkedDivMod op a b).outcome
        (leftTrace ++ rightTrace ++
          [⟨key, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩])
  | divModLeftAbrupt (env key op left right outcome trace)
      (target : IntegerDivisionOp op)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary op (.base .integer) left right, .base .integer, key⟩
        outcome trace
  | divModRightAbrupt (env key op left right a outcome leftTrace rightTrace)
      (target : IntegerDivisionOp op)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ outcome rightTrace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary op (.base .integer) left right, .base .integer, key⟩
        outcome (leftTrace ++ rightTrace)

  | compare (env key) (op : Comparison) (left right a b leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩
        (.normal (.integer b)) rightTrace) :
      EvalPartial env ⟨.binary op.binOp (.base .integer) left right, .base .boolean, key⟩
        (checkedCompare op a b).outcome
        (leftTrace ++ rightTrace ++
          [⟨key, .binary op.binOp (.base .integer), [.integer a, .integer b], checkedCompare op a b⟩])
  | compareLeftAbrupt (env key) (op : Comparison) (left right outcome trace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary op.binOp (.base .integer) left right, .base .boolean, key⟩
        outcome trace
  | compareRightAbrupt (env key) (op : Comparison) (left right a outcome leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .integer, childKey key []⟩
        (.normal (.integer a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ outcome rightTrace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary op.binOp (.base .integer) left right, .base .boolean, key⟩
        outcome (leftTrace ++ rightTrace)
  | widthBinary (env key) (kind : IntKind) (op : WidthBinary) (left right a b leftTrace rightTrace)
      (not64 : kind ≠ .integer64)
      (evalLeft : EvalPartial env ⟨left, kind.type, childKey key []⟩
        (.normal (.ofInteger kind a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, kind.type, childKey key [left]⟩
        (.normal (.ofInteger kind b)) rightTrace) :
      EvalPartial env ⟨.binary op.op kind.type left right, op.type kind, key⟩
        (op.apply kind a b).outcome
        (leftTrace ++ rightTrace ++ [⟨key, .binary op.op kind.type,
          [.ofInteger kind a, .ofInteger kind b], op.apply kind a b⟩])
  | widthBinaryLeftAbrupt (env key) (kind : IntKind) (op : WidthBinary) (left right outcome trace)
      (not64 : kind ≠ .integer64)
      (evalLeft : EvalPartial env ⟨left, kind.type, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary op.op kind.type left right, op.type kind, key⟩ outcome trace
  | widthBinaryRightAbrupt (env key) (kind : IntKind) (op : WidthBinary) (left right a outcome leftTrace rightTrace)
      (not64 : kind ≠ .integer64)
      (evalLeft : EvalPartial env ⟨left, kind.type, childKey key []⟩
        (.normal (.ofInteger kind a)) leftTrace)
      (evalRight : EvalPartial env ⟨right, kind.type, childKey key [left]⟩ outcome rightTrace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.binary op.op kind.type left right, op.type kind, key⟩
        outcome (leftTrace ++ rightTrace)
  | widthNeg (env key) (kind : IntKind) (source value trace)
      (not64 : kind ≠ .integer64) (signed : kind.min < 0)
      (eval : EvalPartial env ⟨source, kind.type, childKey key []⟩
        (.normal (.ofInteger kind value)) trace) :
      EvalPartial env ⟨.neg kind.type source, kind.type, key⟩
        (kind.checkedNeg signed value).outcome
        (trace ++ [⟨key, .neg kind.type, [.ofInteger kind value], kind.checkedNeg signed value⟩])
  | widthNegAbrupt (env key) (kind : IntKind) (source outcome trace)
      (not64 : kind ≠ .integer64) (signed : kind.min < 0)
      (eval : EvalPartial env ⟨source, kind.type, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.neg kind.type source, kind.type, key⟩ outcome trace
  | not (env key source value trace)
      (eval : EvalPartial env ⟨source, .base .boolean, childKey key []⟩
        (.normal (.boolean value)) trace) :
      EvalPartial env ⟨.not source, .base .boolean, key⟩ (.normal (.boolean (!value))) trace
  | notAbrupt (env key source outcome trace)
      (eval : EvalPartial env ⟨source, .base .boolean, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.not source, .base .boolean, key⟩ outcome trace
  | andShort (env key left right trace)
      (evalLeft : EvalPartial env ⟨left, .base .boolean, childKey key []⟩
        (.normal (.boolean false)) trace) :
      EvalPartial env ⟨.and left right, .base .boolean, key⟩
        (.normal (.boolean false)) trace
  | andRight (env key left right outcome leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .boolean, childKey key []⟩
        (.normal (.boolean true)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .boolean, childKey key [left]⟩
        outcome rightTrace) :
      EvalPartial env ⟨.and left right, .base .boolean, key⟩ outcome (leftTrace ++ rightTrace)
  | andAbrupt (env key left right outcome trace)
      (evalLeft : EvalPartial env ⟨left, .base .boolean, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.and left right, .base .boolean, key⟩ outcome trace
  | orShort (env key left right trace)
      (evalLeft : EvalPartial env ⟨left, .base .boolean, childKey key []⟩
        (.normal (.boolean true)) trace) :
      EvalPartial env ⟨.or left right, .base .boolean, key⟩
        (.normal (.boolean true)) trace
  | orRight (env key left right outcome leftTrace rightTrace)
      (evalLeft : EvalPartial env ⟨left, .base .boolean, childKey key []⟩
        (.normal (.boolean false)) leftTrace)
      (evalRight : EvalPartial env ⟨right, .base .boolean, childKey key [left]⟩
        outcome rightTrace) :
      EvalPartial env ⟨.or left right, .base .boolean, key⟩ outcome (leftTrace ++ rightTrace)
  | orAbrupt (env key left right outcome trace)
      (evalLeft : EvalPartial env ⟨left, .base .boolean, childKey key []⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.or left right, .base .boolean, key⟩ outcome trace
  | block (env key body type outcome trace)
      (eval : EvalBlock env (childKey key []) body type outcome trace) :
      EvalPartial env ⟨.block body, type, key⟩ outcome trace
  | iteTrue (env key cond yes no type outcome ct bt)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean true)) ct)
      (branch : EvalBlock env (childKey key [cond]) yes type outcome bt) :
      EvalPartial env ⟨.ite cond yes no, type, key⟩ outcome (ct ++ bt)
  | iteFalse (env key cond yes no type outcome ct bt)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean false)) ct)
      (branch : EvalBlock env (childKey key (cond :: blockChildren yes)) no type outcome bt) :
      EvalPartial env ⟨.ite cond yes no, type, key⟩ outcome (ct ++ bt)
  | iteAbrupt (env key cond yes no type outcome ct)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ outcome ct)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.ite cond yes no, type, key⟩ outcome ct
  | elseIfTrue (env key cond yes no type outcome ct bt)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean true)) ct)
      (branch : EvalBlock env (childKey key [cond]) yes type outcome bt) :
      EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome (ct ++ bt)
  | elseIfFalse (env key cond yes no type outcome ct bt)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean false)) ct)
      (branch : EvalPartial env ⟨no, type, childKey key (cond :: blockChildren yes)⟩ outcome bt) :
      EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome (ct ++ bt)
  | elseIfAbrupt (env key cond yes no type outcome ct)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ outcome ct)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome ct
  | ifOnlyTrue (env key cond yes outcome ct bt)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean true)) ct)
      (branch : EvalBlock env (childKey key [cond]) yes (.base .unit) outcome bt) :
      EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ outcome (ct ++ bt)
  | ifOnlyFalse (env key cond yes ct)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ (.normal (.boolean false)) ct) :
      EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ (.normal .unit) ct
  | ifOnlyAbrupt (env key cond yes outcome ct)
      (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩ outcome ct)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ outcome ct

  | matchInteger (env key source arms type value outcome st armTrace)
      (scrutinee : EvalPartial env ⟨source, .base .integer, childKey key []⟩ (.normal (.integer value)) st)
      (selected : EvalArms env (childKey key [source]) value arms type outcome armTrace) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome (st ++ armTrace)
  | matchWidth (env key kind source arms type value outcome st armTrace)
      (not64 : kind ≠ .integer64)
      (scrutinee : EvalPartial env ⟨source, kind.type, childKey key []⟩
        (.normal (.ofInteger kind value)) st)
      (selected : EvalWidthArms env (childKey key [source]) kind value arms type outcome armTrace) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome (st ++ armTrace)
  | matchResult (env key source arms type sourceType value names tag payload outcome st armTrace)
      (recognized : rangeResultMatch env value arms = some names)
      (view : names.ResultView value tag payload)
      (scrutinee : EvalPartial env ⟨source, sourceType, childKey key []⟩ (.normal value) st)
      (selected : EvalResultArms env (childKey key [source]) names value tag payload
        arms type outcome armTrace) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome (st ++ armTrace)
  | matchAbrupt (env key source arms type sourceType outcome st)
      (scrutinee : EvalPartial env ⟨source, sourceType, childKey key []⟩ outcome st)
      (abrupt : outcome.Abrupt) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ outcome st
  | matchOtherNormal (env key source arms type sourceType value result st)
      (scrutinee : EvalPartial env ⟨source, sourceType, childKey key []⟩ (.normal value) st)
      (noninteger : ∀ kind integer, value ≠ .ofInteger kind integer) (typed : result.type = type)
      (unmodeledResult : rangeResultMatch env value arms = none) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ (.normal result) st
  | matchOtherFailed (env key source arms type sourceType value st)
      (scrutinee : EvalPartial env ⟨source, sourceType, childKey key []⟩ (.normal value) st)
      (noninteger : ∀ kind integer, value ≠ .ofInteger kind integer)
      (unmodeledResult : rangeResultMatch env value arms = none) :
      EvalPartial env ⟨.matchE type source arms, type, key⟩ (.failed .unknown) st

/-- 引数をソース順に評価し、異常終了した後の引数は評価しない。
callee は認定した標準の名前であり、その部分木へ未知の評価を適用しない。 -/
inductive EvalArguments : ConcreteEnv → OperationKey → List Expr → Ty →
    ArgumentOutcome → EvalTrace → Prop where
  | nil (env key type) : EvalArguments env key [] type (.normal []) []
  | cons (env key source rest type value values ht rt)
      (head : EvalPartial env ⟨source, type, key⟩ (.normal value) ht)
      (tail : EvalArguments env (advanceKey key (surfaceSize source)) rest type
        (.normal values) rt) :
      EvalArguments env key (source :: rest) type (.normal (value :: values)) (ht ++ rt)
  | headAbrupt (env key source rest type outcome trace)
      (head : EvalPartial env ⟨source, type, key⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalArguments env key (source :: rest) type (.abrupt outcome) trace
  | tailAbrupt (env key source rest type value outcome ht rt)
      (head : EvalPartial env ⟨source, type, key⟩ (.normal value) ht)
      (tail : EvalArguments env (advanceKey key (surfaceSize source)) rest type
        (.abrupt outcome) rt) :
      EvalArguments env key (source :: rest) type (.abrupt outcome) (ht ++ rt)

/-- 各引数をソース順でそれぞれの型として評価する。後続の失敗・return を保つ。 -/
inductive EvalTypedArguments : ConcreteEnv → OperationKey → List Expr → List Ty →
    ArgumentOutcome → EvalTrace → Prop where
  | nil (env key) : EvalTypedArguments env key [] [] (.normal []) []
  | cons (env key source rest type types value values ht rt)
      (head : EvalPartial env ⟨source, type, key⟩ (.normal value) ht)
      (tail : EvalTypedArguments env (advanceKey key (surfaceSize source)) rest types
        (.normal values) rt) :
      EvalTypedArguments env key (source :: rest) (type :: types)
        (.normal (value :: values)) (ht ++ rt)
  | headAbrupt (env key source rest type types outcome trace)
      (head : EvalPartial env ⟨source, type, key⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalTypedArguments env key (source :: rest) (type :: types) (.abrupt outcome) trace
  | tailAbrupt (env key source rest type types value outcome ht rt)
      (head : EvalPartial env ⟨source, type, key⟩ (.normal value) ht)
      (tail : EvalTypedArguments env (advanceKey key (surfaceSize source)) rest types
        (.abrupt outcome) rt) :
      EvalTypedArguments env key (source :: rest) (type :: types) (.abrupt outcome) (ht ++ rt)

/-- 整数の腕をソース順に選ぶ。guard の偽は元環境で次へ進む。 -/
inductive EvalArms : ConcreteEnv → OperationKey → Integer64Value → Arms → Ty → EvalOutcome → EvalTrace → Prop where
  | nil (env key value type) : EvalArms env key value .nil type (.failed .unknown) []
  | skip (env key value alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, alt.pat.toCore.matchVal (.const (.integer value)) = none)
      (tail : EvalArms env (advanceKey key (guardSize guard + blockSize body)) value rest type outcome trace) :
      EvalArms env key value (.cons alts guard body rest) type outcome trace
  | body (env key value alts body rest type selected outcome trace)
      (selection : IntegerSelection alts value selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace) :
      EvalArms env key value (.cons alts none body rest) type outcome trace
  | guardTrue (env key value alts guard body rest type selected outcome gt bt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt) :
      EvalArms env key value (.cons alts (some guard) body rest) type outcome (gt ++ bt)
  | guardFalse (env key value alts guard body rest type selected outcome gt rt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalArms env (advanceKey key (surfaceSize guard + blockSize body)) value rest type outcome rt) :
      EvalArms env key value (.cons alts (some guard) body rest) type outcome (gt ++ rt)
  | guardAbrupt (env key value alts guard body rest type selected outcome gt)
      (selection : IntegerSelection alts value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt) :
      EvalArms env key value (.cons alts (some guard) body rest) type outcome gt

/-- 整数の腕をソース順に選ぶ。guard の偽は元環境で次へ進む。 -/
inductive EvalWidthArms : ConcreteEnv → OperationKey → (kind : IntKind) → IntegerValue kind → Arms → Ty → EvalOutcome → EvalTrace → Prop where
  | nil (env key kind value type) : EvalWidthArms env key kind value .nil type (.failed .unknown) []
  | skip (env key kind value alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, widthPatternMatch alt.pat kind value = none)
      (tail : EvalWidthArms env (advanceKey key (guardSize guard + blockSize body)) kind value rest type outcome trace) :
      EvalWidthArms env key kind value (.cons alts guard body rest) type outcome trace
  | body (env key kind value alts body rest type selected outcome trace)
      (selection : WidthSelection alts kind value selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace) :
      EvalWidthArms env key kind value (.cons alts none body rest) type outcome trace
  | guardTrue (env key kind value alts guard body rest type selected outcome gt bt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt) :
      EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome (gt ++ bt)
  | guardFalse (env key kind value alts guard body rest type selected outcome gt rt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalWidthArms env (advanceKey key (surfaceSize guard + blockSize body)) kind value rest type outcome rt) :
      EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome (gt ++ rt)
  | guardAbrupt (env key kind value alts guard body rest type selected outcome gt)
      (selection : WidthSelection alts kind value selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt) :
      EvalWidthArms env key kind value (.cons alts (some guard) body rest) type outcome gt

/-- Result の腕も guard が偽なら元環境で次へ進む。 -/
inductive EvalResultArms : ConcreteEnv → OperationKey → RangeNames → ConcreteValue → ConName → ConcreteValue → Arms → Ty → EvalOutcome → EvalTrace → Prop where
  | nil (env key names value tag payload type) : EvalResultArms env key names value tag payload .nil type (.failed .unknown) []
  | skip (env key names value tag payload alts guard body rest type outcome trace)
      (miss : ∀ alt ∈ alts, resultPatternMatch names value tag payload alt.pat = none)
      (tail : EvalResultArms env (advanceKey key (guardSize guard + blockSize body)) names value tag payload rest type outcome trace) :
      EvalResultArms env key names value tag payload (.cons alts guard body rest) type outcome trace
  | body (env key names value tag payload alts body rest type selected outcome trace)
      (selection : ResultSelection names value tag payload alts selected)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        key body type outcome trace) :
      EvalResultArms env key names value tag payload (.cons alts none body rest) type outcome trace
  | guardTrue (env key names value tag payload alts guard body rest type selected outcome gt bt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean true)) gt)
      (branch : EvalBlock { env with locals := selected.reverse.map some ++ env.locals }
        (advanceKey key (surfaceSize guard)) body type outcome bt) :
      EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome (gt ++ bt)
  | guardFalse (env key names value tag payload alts guard body rest type selected outcome gt rt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ (.normal (.boolean false)) gt)
      (tail : EvalResultArms env (advanceKey key (surfaceSize guard + blockSize body)) names value tag payload rest type outcome rt) :
      EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome (gt ++ rt)
  | guardAbrupt (env key names value tag payload alts guard body rest type selected outcome gt)
      (selection : ResultSelection names value tag payload alts selected)
      (condition : EvalPartial { env with locals := selected.reverse.map some ++ env.locals }
        ⟨guard, .base .boolean, key⟩ outcome gt)
      (abrupt : outcome.Abrupt) :
      EvalResultArms env key names value tag payload (.cons alts (some guard) body rest) type outcome gt

/-- Blockのkeyは最初の式の番号であり、Block自体の番号ではない。 -/
inductive EvalBlock : ConcreteEnv → OperationKey → Block → Ty → EvalOutcome → EvalTrace → Prop where
  | empty (env key) : EvalBlock env key .empty (.base .unit) (.normal .unit) []
  | builderBind (env key kind rest type outcome trace)
      (eval : EvalBlock { env with locals := none :: env.locals } key rest type outcome trace) :
      EvalBlock env key (.builderBind kind rest) type outcome trace
  | last (env key source type outcome trace)
      (eval : EvalPartial env ⟨source, type, key⟩ outcome trace) :
      EvalBlock env key (.last source) type outcome trace
  | lastBind (env key kind boundType source outcome trace)
      (eval : EvalPartial env ⟨source, boundType, key⟩ outcome trace) :
      EvalBlock env key (.lastBind kind boundType source) (.base .unit) (discardOutcome outcome) trace
  | lastDiscard (env key source sourceType outcome trace)
      (eval : EvalPartial env ⟨source, sourceType, key⟩ outcome trace) :
      EvalBlock env key (.lastDiscard source) (.base .unit) (discardOutcome outcome) trace
  | lastPat (env key kind pattern boundType source outcome trace)
      (eval : EvalPartial env ⟨source, boundType, key⟩ outcome trace) :
      EvalBlock env key (.lastPat kind pattern boundType source) (.base .unit)
        (discardOutcome outcome) trace
  | bind (env key kind boundType source rest type value outcome et rt)
      (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
      (tail : EvalBlock { env with locals := some value :: env.locals } (advanceKey key (surfaceSize source))
        rest type outcome rt) :
      EvalBlock env key (.bind kind boundType source rest) type outcome (et ++ rt)
  | bindAbrupt (env key kind boundType source rest type outcome trace)
      (head : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalBlock env key (.bind kind boundType source rest) type outcome trace
  | discard (env key source rest sourceType type value outcome et rt)
      (head : EvalPartial env ⟨source, sourceType, key⟩ (.normal value) et)
      (tail : EvalBlock env (advanceKey key (surfaceSize source))
        rest type outcome rt) :
      EvalBlock env key (.discard source rest) type outcome (et ++ rt)
  | discardAbrupt (env key source rest sourceType type outcome trace)
      (head : EvalPartial env ⟨source, sourceType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalBlock env key (.discard source rest) type outcome trace
  | seq (env key source rest type value outcome et rt)
      (head : EvalPartial env ⟨source, .base .unit, key⟩ (.normal value) et)
      (tail : EvalBlock env (advanceKey key (surfaceSize source))
        rest type outcome rt) :
      EvalBlock env key (.seq source rest) type outcome (et ++ rt)
  | seqAbrupt (env key source rest type outcome trace)
      (head : EvalPartial env ⟨source, .base .unit, key⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalBlock env key (.seq source rest) type outcome trace
  | bindPat (env key kind pattern boundType source rest type value outcome et rt values)
      (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
      (bindings : PatternLocals pattern value values)
      (tail : EvalBlock { env with locals := values.map some ++ env.locals } (advanceKey key (surfaceSize source))
        rest type outcome rt) :
      EvalBlock env key (.bindPat kind pattern boundType source rest) type outcome (et ++ rt)
  | bindPatAbrupt (env key kind pattern boundType source rest type outcome trace)
      (head : EvalPartial env ⟨source, boundType, key⟩ outcome trace)
      (abrupt : outcome.Abrupt) :
      EvalBlock env key (.bindPat kind pattern boundType source rest) type outcome trace
end

/-- 同じ型の旧引数列は、同じ長さの型列を持つ評価へそのまま移せる。 -/
theorem arguments_typed {env key sources type outcome trace}
    (evaluated : EvalArguments env key sources type outcome trace) :
    EvalTypedArguments env key sources (List.replicate sources.length type) outcome trace := by
  match evaluated with
  | .nil .. => exact .nil _ _
  | .cons _ _ _ _ _ _ _ _ _ head tail => exact .cons _ _ _ _ _ _ _ _ _ _ head (arguments_typed tail)
  | .headAbrupt _ _ _ _ _ _ _ head abrupt => exact .headAbrupt _ _ _ _ _ _ _ _ head abrupt
  | .tailAbrupt _ _ _ _ _ _ _ _ _ head tail => exact .tailAbrupt _ _ _ _ _ _ _ _ _ _ head (arguments_typed tail)

/-- 全引数の正常評価では、式・型・値の列の長さが一致する。 -/
theorem typed_arguments_normal_length {env key sources types values trace}
    (evaluated : EvalTypedArguments env key sources types (.normal values) trace) :
    sources.length = types.length ∧ values.length = sources.length := by
  match evaluated with
  | .nil .. => exact ⟨rfl, rfl⟩
  | .cons _ _ _ _ _ _ _ _ _ _ _ tail =>
    obtain ⟨types, values⟩ := typed_arguments_normal_length tail
    simp only [List.length_cons, types, values, and_self]

/-- 一律の型列を持つ異種評価は、旧引数列の評価にもなる。 -/
theorem typed_arguments_uniform {env key sources types outcome trace}
    (evaluated : EvalTypedArguments env key sources types outcome trace)
    (type : Ty) (uniform : types = List.replicate sources.length type) :
    EvalArguments env key sources type outcome trace := by
  match evaluated with
  | .nil .. => exact .nil _ _ _
  | .cons _ _ _ _ _ _ _ _ _ _ head tail =>
    simp only [List.length_cons, List.replicate_succ, List.cons.injEq] at uniform
    cases uniform.1
    exact .cons _ _ _ _ _ _ _ _ _ head (typed_arguments_uniform tail type uniform.2)
  | .headAbrupt _ _ _ _ _ _ _ _ head abrupt =>
    simp only [List.length_cons, List.replicate_succ, List.cons.injEq] at uniform
    cases uniform.1
    exact .headAbrupt _ _ _ _ _ _ _ head abrupt
  | .tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
    simp only [List.length_cons, List.replicate_succ, List.cons.injEq] at uniform
    cases uniform.1
    exact .tailAbrupt _ _ _ _ _ _ _ _ _ head (typed_arguments_uniform tail type uniform.2)

mutual
/-- 対象構文の正常評価は、評価の入力型と一致する値を返す。 -/
theorem eval_normal_typed {env input outcome trace}
    (eval : EvalPartial env input outcome trace) : NormalTyped input.type outcome := by
  match eval with
  | .standardCall _ _ _ _ _ _ _ _ _ _ _ _ _ _ evaluated =>
      exact standard_result_typed evaluated
  | .standardCallAbrupt _ _ _ _ _ _ _ outcome _ _ _ abrupt =>
      cases outcome <;> trivial
  | .fixedCallFailed .. => trivial
  | .fixedCallAbrupt _ _ _ _ _ _ _ _ outcome _ _ _ _ abrupt => cases outcome <;> trivial
  | .unknownNormal _ _ _ _ typed => exact typed
  | .unknownFailed .. | .integer .. | .negInt .. | .boolean .. | .unit .. | .local ..
  | .integer8 .. | .integer16 .. | .integer32 ..
  | .unsignedInteger16 .. | .unsignedInteger32 .. | .unsignedInteger64 ..
  | .negInteger8 .. | .negInteger16 .. | .negInteger32 .. => trivial
  | .paren _ _ _ _ _ _ e | .constE _ _ _ _ _ _ e => have h := eval_normal_typed e; exact h
  | .returnE _ _ _ _ _ result _ _ => cases result <;> trivial
  | .add _ _ _ _ a b _ _ _ _ =>
      simp only [checkedAdd]; split <;> trivial
  | .sub _ _ _ _ a b _ _ _ _ =>
      simp only [checkedSub, IntKind.checkedSub, ConcreteValue.ofInteger]; split <;> trivial
  | .mul _ _ _ _ a b _ _ _ _ =>
      simp only [checkedMul, IntKind.checkedMul, ConcreteValue.ofInteger]; split <;> trivial
  | .neg _ _ _ value _ _ =>
      simp only [checkedNeg, IntKind.checkedNeg]; split <;> trivial
  | .divMod _ _ op _ _ a b _ _ _ _ _ =>
      simp only [checkedDivMod]; split <;> try trivial
      split <;> try trivial
      split <;> try trivial
      split <;> trivial
  | .widthBinary _ _ kind op _ _ a b _ _ _ _ _ =>
      cases op <;> simp only [WidthBinary.apply, WidthBinary.type, IntKind.checkedAdd,
        IntKind.checkedSub, IntKind.checkedMul, IntKind.checkedDivMod, IntKind.checkedCompare]
      all_goals repeat' split
      all_goals simp only [NormalTyped, OperationResult.outcome, ConcreteValue.ofInteger_type]
      all_goals rfl
  | .widthNeg _ _ kind _ a _ _ signed _ =>
      simp only [IntKind.checkedNeg]
      split <;> simp [NormalTyped, OperationResult.outcome]
  | .widthBinaryLeftAbrupt _ _ _ _ _ _ result _ _ _ abrupt
  | .widthBinaryRightAbrupt _ _ _ _ _ _ _ result _ _ _ _ _ abrupt
  | .widthNegAbrupt _ _ _ _ result _ _ _ _ abrupt => cases result <;> trivial
  | .compare .. | .not .. | .ifOnlyFalse .. | .andShort .. | .orShort .. => trivial
  | .andRight _ _ _ _ _ _ _ _ child | .orRight _ _ _ _ _ _ _ _ child =>
      have h := eval_normal_typed child; exact h
  | .addLeftAbrupt _ _ _ _ result _ _ abrupt | .subLeftAbrupt _ _ _ _ result _ _ abrupt | .mulLeftAbrupt _ _ _ _ result _ _ abrupt
  | .addRightAbrupt _ _ _ _ _ result _ _ _ _ abrupt | .subRightAbrupt _ _ _ _ _ result _ _ _ _ abrupt | .mulRightAbrupt _ _ _ _ _ result _ _ _ _ abrupt
  | .divModLeftAbrupt _ _ _ _ _ result _ _ _ abrupt
  | .divModRightAbrupt _ _ _ _ _ _ result _ _ _ _ _ abrupt
  | .compareLeftAbrupt _ _ _ _ _ result _ _ abrupt
  | .compareRightAbrupt _ _ _ _ _ _ result _ _ _ _ abrupt
  | .andAbrupt _ _ _ _ result _ _ abrupt
  | .orAbrupt _ _ _ _ result _ _ abrupt
  | .negAbrupt _ _ _ result _ _ abrupt
  | .notAbrupt _ _ _ result _ _ abrupt
  | .iteAbrupt _ _ _ _ _ _ result _ _ abrupt
  | .elseIfAbrupt _ _ _ _ _ _ result _ _ abrupt
  | .ifOnlyAbrupt _ _ _ _ result _ _ abrupt => cases result <;> trivial
  | .block _ _ _ _ _ _ e => exact block_normal_typed e
  | .iteTrue _ _ _ _ _ _ _ _ _ _ b | .iteFalse _ _ _ _ _ _ _ _ _ _ b
  | .elseIfTrue _ _ _ _ _ _ _ _ _ _ b | .ifOnlyTrue _ _ _ _ _ _ _ _ b =>
      exact block_normal_typed b
  | .elseIfFalse _ _ _ _ _ _ _ _ _ _ e => have h := eval_normal_typed e; exact h

  | .matchInteger _ _ _ _ _ _ _ _ _ _ selected => exact arms_normal_typed selected
  | .matchWidth _ _ _ _ _ _ _ _ _ _ _ _ selected => exact widthArms_normal_typed selected
  | .matchResult _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ selected => exact resultArms_normal_typed selected
  | .matchAbrupt _ _ _ _ _ _ result _ _ abrupt => cases result <;> trivial
  | .matchOtherNormal _ _ _ _ _ _ _ _ _ _ _ typed _ => exact typed
  | .matchOtherFailed .. => trivial

private theorem arms_normal_typed {env key value arms type outcome trace}
    (eval : EvalArms env key value arms type outcome trace) : NormalTyped type outcome := by
  match eval with
  | .nil .. => trivial
  | .skip _ _ _ _ _ _ _ _ _ _ _ tail
  | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail => exact arms_normal_typed tail
  | .body _ _ _ _ _ _ _ _ _ _ _ body
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ body => exact block_normal_typed body
  | .guardAbrupt _ _ _ _ _ _ _ _ _ result _ _ _ abrupt => cases result <;> trivial

private theorem resultArms_normal_typed {env key names value tag payload arms type outcome trace}
    (eval : EvalResultArms env key names value tag payload arms type outcome trace) : NormalTyped type outcome := by
  match eval with
  | .nil .. => trivial
  | .skip _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail
  | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail => exact resultArms_normal_typed tail
  | .body _ _ _ _ _ _ _ _ _ _ _ _ _ _ body
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ body => exact block_normal_typed body
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ result _ _ _ abrupt => cases result <;> trivial

private theorem widthArms_normal_typed {env key kind value arms type outcome trace}
    (eval : EvalWidthArms env key kind value arms type outcome trace) : NormalTyped type outcome := by
  match eval with
  | .nil .. => trivial
  | .skip _ _ _ _ _ _ _ _ _ _ _ _ tail
  | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail => exact widthArms_normal_typed tail
  | .body _ _ _ _ _ _ _ _ _ _ _ _ body
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ body => exact block_normal_typed body
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ result _ _ _ abrupt => cases result <;> trivial

private theorem block_normal_typed {env key body type outcome trace}
    (eval : EvalBlock env key body type outcome trace) : NormalTyped type outcome := by
  match eval with
  | .empty .. => rfl
  | .builderBind _ _ _ _ _ _ _ e => exact block_normal_typed e
  | .last _ _ _ _ _ _ e => have h := eval_normal_typed e; exact h
  | .lastBind _ _ _ _ _ result _ _ | .lastDiscard _ _ _ _ result _ _
  | .lastPat _ _ _ _ _ _ result _ _ => cases result <;> trivial
  | .bind _ _ _ _ _ _ _ _ _ _ _ _ r
  | .discard _ _ _ _ _ _ _ _ _ _ _ r
  | .seq _ _ _ _ _ _ _ _ _ _ r
  | .bindPat _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ r => exact block_normal_typed r
  | .bindAbrupt _ _ _ _ _ _ _ result _ _ abrupt
  | .discardAbrupt _ _ _ _ _ _ result _ _ abrupt
  | .seqAbrupt _ _ _ _ _ result _ _ abrupt
  | .bindPatAbrupt _ _ _ _ _ _ _ _ result _ _ abrupt => cases result <;> trivial
end

/-- 契約位置への並べ替えは、位置列と同じ数の正常値を返す。 -/
theorem order_arguments_length {positions values arguments}
    (ordered : orderArguments positions values = some arguments) :
    arguments.length = positions.length := by
  have length {indices : List Nat} {output : List ConcreteValue}
      (mapped : indices.mapM (fun i => fieldAt i positions values) = some output) :
      output.length = indices.length := by
    induction indices generalizing output with
    | nil => cases mapped; rfl
    | cons index rest ih =>
      rw [List.mapM_cons] at mapped
      obtain ⟨head, _, mapped⟩ := Option.bind_eq_some_iff.mp mapped
      obtain ⟨tail, selected, same⟩ := Option.bind_eq_some_iff.mp mapped
      cases same
      simp only [List.length_cons, ih selected]
  simpa only [List.length_range] using length ordered

/-- 正常に揃った引数列の各実値の型は、ソース順の型列に一致する。 -/
theorem typed_arguments_normal_types {env key sources types values trace}
    (evaluated : EvalTypedArguments env key sources types (.normal values) trace) :
    values.map ConcreteValue.type = types := by
  match evaluated with
  | .nil .. => rfl
  | .cons _ _ _ _ _ _ _ _ _ _ head tail =>
      have typed := eval_normal_typed head
      simp only [NormalTyped] at typed
      simp only [List.map_cons, typed, typed_arguments_normal_types tail]

/-- 引数のソース位置と、その正常評価値の位置を対応させる。契約位置へ先に並べない。 -/
theorem arguments_normal_field {env key sources type values trace}
    (evaluated : EvalArguments env key sources type (.normal values) trace)
    {positions : List Nat} {position : Nat} {source : Expr}
    (found : fieldAt position positions sources = some source) :
    ∃ value child trace, fieldAt position positions values = some value ∧
      EvalPartial env ⟨source, type, child⟩ (.normal value) trace := by
  induction sources generalizing key values trace positions with
  | nil => simp [fieldAt] at found
  | cons head rest ih =>
    cases evaluated with
    | cons _ _ _ _ _ value values ht rt first tail =>
      cases positions with
      | nil => simp [fieldAt] at found
      | cons actual positions =>
        by_cases same : position = actual
        · simp only [fieldAt, same, ↓reduceIte, Option.some.injEq] at found
          subst source
          exact ⟨value, key, ht, by simp [fieldAt, same], first⟩
        · simp only [fieldAt, same, ↓reduceIte] at found ⊢
          exact ih tail found

/-- 並べ替えが成功すれば、契約位置の値はソース列の同じ位置から得られる。 -/
theorem order_arguments_field {positions values arguments position}
    (ordered : orderArguments positions values = some arguments)
    (inside : position < positions.length) :
    fieldAt position positions values = arguments[position]? := by
  have lookup {indices : List Nat} {output : List ConcreteValue}
      (mapped : indices.mapM (fun i => fieldAt i positions values) = some output)
      {index item : Nat} (atIndex : indices[index]? = some item) :
      fieldAt item positions values = output[index]? := by
    induction indices generalizing output index with
    | nil => simp at atIndex
    | cons current rest ih =>
      rw [List.mapM_cons] at mapped
      change ((fieldAt current positions values).bind _) = some output at mapped
      obtain ⟨value, atValue, continuation⟩ := Option.bind_eq_some_iff.mp mapped
      change ((rest.mapM (fun i => fieldAt i positions values)).bind _) = some output at continuation
      obtain ⟨tailOutput, tailMapped, same⟩ := Option.bind_eq_some_iff.mp continuation
      have outputEq : value :: tailOutput = output := Option.some.inj same
      subst output
      cases index with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at atIndex
        subst item
        exact atValue
      | succ index => exact ih tailMapped atIndex
  apply lookup (index := position) (item := position) ordered
  simp [inside]


/-- 子が正常整数を返せば、加算自体の事象を含む導出を構成できる。
環境について追加の仮定を要しないので、型どおりの任意の環境にも適用できる。 -/
theorem add_derivation_exists {env key left right a b lt rt}
    (el : EvalPartial env ⟨left, .base .integer, childKey key []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ (.normal (.integer b)) rt) :
    ∃ trace, EvalPartial env ⟨.binary .add (.base .integer) left right, .base .integer, key⟩
      (checkedAdd a b).outcome trace ∧
      ⟨key, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩ ∈ trace := by
  exact ⟨_, .add env key left right a b lt rt el er, by simp⟩

/-- 除数0やあふれによる拒否も含め、正常な子から対象除算の事象へ到達する。 -/
theorem divMod_derivation_exists {env key op left right a b lt rt}
    (target : IntegerDivisionOp op)
    (el : EvalPartial env ⟨left, .base .integer, childKey key []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ (.normal (.integer b)) rt) :
    ∃ trace, EvalPartial env ⟨.binary op (.base .integer) left right, .base .integer, key⟩
      (checkedDivMod op a b).outcome trace ∧
      ⟨key, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩ ∈ trace := by
  exact ⟨_, .divMod env key op left right a b lt rt target el er, by simp⟩

/-- 六比較は正常な子から、数学上の比較結果と比較自体の事象を得る。 -/
theorem compare_derivation_exists {env key left right a b lt rt} (op : Comparison)
    (el : EvalPartial env ⟨left, .base .integer, childKey key []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ (.normal (.integer b)) rt) :
    ∃ trace, EvalPartial env ⟨.binary op.binOp (.base .integer) left right, .base .boolean, key⟩
      (.normal (.boolean (decide (op.Holds a.toInt b.toInt)))) trace ∧
      ⟨key, .binary op.binOp (.base .integer), [.integer a, .integer b], checkedCompare op a b⟩ ∈ trace := by
  exact ⟨_, .compare env key op left right a b lt rt el er, by simp⟩

/-- notは正常なBooleanの子があれば、同じtraceを持つ正常評価を構成できる。 -/
theorem not_derivation_exists {env key source value trace}
    (child : EvalPartial env ⟨source, .base .boolean, childKey key []⟩
      (.normal (.boolean value)) trace) :
    EvalPartial env ⟨.not source, .base .boolean, key⟩ (.normal (.boolean (!value))) trace :=
  .not env key source value trace child

/-- 左辺がtrueのときだけ右辺の導出を要求し、短絡時はそのtraceを空にする。 -/
theorem and_derivation_exists {env key left right truth lt outcome rt}
    (el : EvalPartial env ⟨left, .base .boolean, childKey key []⟩
      (.normal (.boolean truth)) lt)
    (branch : if truth = true then
        EvalPartial env ⟨right, .base .boolean, childKey key [left]⟩ outcome rt
      else outcome = .normal (.boolean false) ∧ rt = []) :
    EvalPartial env ⟨.and left right, .base .boolean, key⟩ outcome (lt ++ rt) := by
  cases truth <;> simp only [Bool.false_eq_true, ↓reduceIte] at branch
  · rcases branch with ⟨rfl, rfl⟩
    simpa using EvalPartial.andShort env key left right lt el
  · exact .andRight env key left right outcome lt rt el branch

/-- 左辺がfalseのときだけ右辺の導出を要求し、短絡時はそのtraceを空にする。 -/
theorem or_derivation_exists {env key left right truth lt outcome rt}
    (el : EvalPartial env ⟨left, .base .boolean, childKey key []⟩
      (.normal (.boolean truth)) lt)
    (branch : if truth = false then
        EvalPartial env ⟨right, .base .boolean, childKey key [left]⟩ outcome rt
      else outcome = .normal (.boolean true) ∧ rt = []) :
    EvalPartial env ⟨.or left right, .base .boolean, key⟩ outcome (lt ++ rt) := by
  cases truth <;> simp only [Bool.true_eq_false, ↓reduceIte] at branch
  · exact .orRight env key left right outcome lt rt el branch
  · rcases branch with ⟨rfl, rfl⟩
    simpa using EvalPartial.orShort env key left right lt el

/-- 選ばれた枝の導出だけからif全体を構成し、未選択の枝の評価を要しない。 -/
theorem ite_derivation_exists {env key cond yes no type truth ct outcome bt}
    (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩
      (.normal (.boolean truth)) ct)
    (branch : if truth then EvalBlock env (childKey key [cond]) yes type outcome bt
      else EvalBlock env (childKey key (cond :: blockChildren yes)) no type outcome bt) :
    ∃ trace, EvalPartial env ⟨.ite cond yes no, type, key⟩ outcome trace ∧ trace = ct ++ bt := by
  cases truth with
  | true => exact ⟨_, .iteTrue env key cond yes no type outcome ct bt condition branch, rfl⟩
  | false => exact ⟨_, .iteFalse env key cond yes no type outcome ct bt condition branch, rfl⟩

/-- else ifの偽枝はBlockを合成せず、元の式のキーで評価する。 -/
theorem elseIf_derivation_exists {env key cond yes no type truth ct outcome bt}
    (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩
      (.normal (.boolean truth)) ct)
    (branch : if truth then EvalBlock env (childKey key [cond]) yes type outcome bt
      else EvalPartial env ⟨no, type, childKey key (cond :: blockChildren yes)⟩ outcome bt) :
    ∃ trace, EvalPartial env ⟨.elseIf cond yes no, type, key⟩ outcome trace ∧ trace = ct ++ bt := by
  cases truth with
  | true => exact ⟨_, .elseIfTrue env key cond yes no type outcome ct bt condition branch, rfl⟩
  | false => exact ⟨_, .elseIfFalse env key cond yes no type outcome ct bt condition branch, rfl⟩

/-- elseなしの偽枝はUnitとなる。真のときだけ本体の導出を要する。 -/
theorem ifOnly_derivation_exists {env key cond yes truth ct outcome bt}
    (condition : EvalPartial env ⟨cond, .base .boolean, childKey key []⟩
      (.normal (.boolean truth)) ct)
    (branch : if truth then EvalBlock env (childKey key [cond]) yes (.base .unit) outcome bt
      else outcome = .normal .unit ∧ bt = []) :
    ∃ trace, EvalPartial env ⟨.ifOnly cond yes, .base .unit, key⟩ outcome trace ∧ trace = ct ++ bt := by
  cases truth with
  | true => exact ⟨_, .ifOnlyTrue env key cond yes outcome ct bt condition branch, rfl⟩
  | false =>
      obtain ⟨rfl, rfl⟩ := branch
      exact ⟨_, .ifOnlyFalse env key cond yes ct condition, by simp⟩

/-- bindとshadowの正常な右辺を保存し、後続の導出をつなぐ。 -/
theorem bind_derivation_exists {env key kind boundType source rest type value outcome et rt}
    (head : EvalPartial env ⟨source, boundType, key⟩ (.normal value) et)
    (tail : EvalBlock { env with locals := some value :: env.locals }
      (advanceKey key (surfaceSize source)) rest type outcome rt) :
    ∃ trace, EvalBlock env key (.bind kind boundType source rest) type outcome trace ∧
      trace = et ++ rt :=
  ⟨_, .bind env key kind boundType source rest type value outcome et rt head tail, rfl⟩

/-- 一つの部分木の到達記録。キーは重複せず、その部分木の番号範囲に収まる。 -/
def TraceKeys (key : OperationKey) (size : Nat) (trace : EvalTrace) : Prop :=
  trace.Pairwise (fun a b => a.key ≠ b.key) ∧
    ∀ event ∈ trace, event.key.definition = key.definition ∧
      key.surfacePreorder ≤ event.key.surfacePreorder ∧
      event.key.surfacePreorder < key.surfacePreorder + size

private theorem TraceKeys.empty (key : OperationKey) (size : Nat) :
    TraceKeys key size [] := by simp [TraceKeys]

private theorem TraceKeys.widen {key key' size size' trace}
    (h : TraceKeys key size trace) (same : key.definition = key'.definition)
    (low : key'.surfacePreorder ≤ key.surfacePreorder)
    (high : key.surfacePreorder + size ≤ key'.surfacePreorder + size') :
    TraceKeys key' size' trace := by
  refine ⟨h.1, ?_⟩
  intro event found
  obtain ⟨d, lo, hi⟩ := h.2 event found
  exact ⟨d.trans same, by omega, by omega⟩

private theorem TraceKeys.append {leftKey rightKey leftSize rightSize left right}
    (hl : TraceKeys leftKey leftSize left) (hr : TraceKeys rightKey rightSize right)
    (same : rightKey.definition = leftKey.definition)
    (separate : leftKey.surfacePreorder + leftSize ≤ rightKey.surfacePreorder) :
    TraceKeys leftKey (rightKey.surfacePreorder + rightSize - leftKey.surfacePreorder)
      (left ++ right) := by
  have endOrder : leftKey.surfacePreorder ≤ rightKey.surfacePreorder + rightSize := by omega
  refine ⟨List.pairwise_append.mpr ⟨hl.1, hr.1, ?_⟩, ?_⟩
  · intro a ha b hb eq
    have al := hl.2 a ha
    have br := hr.2 b hb
    have equal := congrArg OperationKey.surfacePreorder eq
    omega
  · intro event found
    rcases List.mem_append.mp found with found | found
    · obtain ⟨d, lo, hi⟩ := hl.2 event found
      exact ⟨d, lo, by omega⟩
    · obtain ⟨d, lo, hi⟩ := hr.2 event found
      exact ⟨d.trans same, by omega, by omega⟩

private theorem TraceKeys.parent {key size trace} (h : TraceKeys (childKey key []) size trace) :
    TraceKeys key (1 + size) trace := by
  apply TraceKeys.widen (key' := key) h rfl <;> simp [childKey] <;> omega

private theorem TraceKeys.children {key left right leftTrace rightTrace}
    (hl : TraceKeys (childKey key []) (surfaceSize left) leftTrace)
    (hr : TraceKeys (childKey key [left]) (surfaceSize right) rightTrace) :
    TraceKeys (childKey key []) (surfaceSize left + surfaceSize right)
      (leftTrace ++ rightTrace) := by
  have joined := hl.append hr rfl (by simp [childKey])
  have sizes : (childKey key [left]).surfacePreorder + surfaceSize right -
      (childKey key []).surfacePreorder = surfaceSize left + surfaceSize right := by
    simp only [childKey, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
    omega
  rw [sizes] at joined
  exact joined

private theorem TraceKeys.withRoot {key size trace} (event : EvalEvent)
    (eventKey : event.key = key) (h : TraceKeys (childKey key []) size trace) :
    TraceKeys key (1 + size) (trace ++ [event]) := by
  refine ⟨List.pairwise_append.mpr ⟨h.1, by simp, ?_⟩, ?_⟩
  · intro a ha b hb eq
    simp only [List.mem_singleton] at hb
    subst b
    have bounds := h.2 a ha
    have equal := congrArg OperationKey.surfacePreorder (eq.trans eventKey)
    simp only [childKey] at bounds
    omega
  · intro e found
    rcases List.mem_append.mp found with found | found
    · exact h.parent.2 e found
    · simp only [List.mem_singleton] at found
      subst e
      rw [eventKey]
      exact ⟨rfl, Nat.le_refl _, by omega⟩

@[simp] theorem surfaceSize_not (source : Expr) :
    surfaceSize (.not source) = 1 + surfaceSize source := by
  simp [surfaceSize_children, children]

@[simp] theorem surfaceSize_neg (type : Ty) (source : Expr) :
    surfaceSize (.neg type source) = 1 + surfaceSize source := by
  simp [surfaceSize_children, children]

@[simp] theorem surfaceSize_and (left right : Expr) :
    surfaceSize (.and left right) = 1 + surfaceSize left + surfaceSize right := by
  simp [surfaceSize_children, children, Nat.add_assoc]

@[simp] theorem surfaceSize_or (left right : Expr) :
    surfaceSize (.or left right) = 1 + surfaceSize left + surfaceSize right := by
  simp [surfaceSize_children, children, Nat.add_assoc]

@[simp] theorem surfaceSize_ite (cond : Expr) (yes no : Block) :
    surfaceSize (.ite cond yes no) = 1 + surfaceSize cond + blockSize yes + blockSize no := by
  simp [surfaceSize_children, children, blockSize, List.map_append, List.sum_append, Nat.add_assoc]

@[simp] theorem surfaceSize_elseIf (cond : Expr) (yes : Block) (no : Expr) :
    surfaceSize (.elseIf cond yes no) = 1 + surfaceSize cond + blockSize yes + surfaceSize no := by
  simp [surfaceSize_children, children, blockSize, List.map_append, List.sum_append, Nat.add_assoc]

@[simp] theorem surfaceSize_ifOnly (cond : Expr) (yes : Block) :
    surfaceSize (.ifOnly cond yes) = 1 + surfaceSize cond + blockSize yes := by
  simp [surfaceSize_children, children, blockSize, Nat.add_assoc]

private theorem TraceKeys.follow {key first second left right}
    (hl : TraceKeys key first left)
    (hr : TraceKeys (advanceKey key first) second right) :
    TraceKeys key (first + second) (left ++ right) := by
  have h := hl.append hr rfl (by simp [advanceKey])
  simpa [advanceKey, Nat.add_assoc] using h

private theorem TraceKeys.selected {key condSize gap branchSize total ct bt}
    (hc : TraceKeys (childKey key []) condSize ct)
    (hb : TraceKeys (advanceKey (childKey key []) (condSize + gap)) branchSize bt)
    (fits : 1 + condSize + gap + branchSize ≤ total) :
    TraceKeys key total (ct ++ bt) := by
  have h := hc.append hb rfl (by simp [advanceKey])
  apply h.widen (key' := key) rfl (by simp [childKey] <;> omega)
  simp only [childKey, advanceKey, List.map_nil, List.sum_nil] at *
  omega

mutual
/-- 任意の評価の事象は、その出現の部分木の範囲にあり、キーを重複させない。 -/
theorem eval_trace_keys {env input outcome trace}
    (eval : EvalPartial env input outcome trace) :
    TraceKeys input.key (surfaceSize input.source) trace := by
  match eval with
  | .fixedCallFailed env key callee labels positions sources binding values arguments reason type trace recognized fixed children ordered evaluated =>
      have widened : TraceKeys (childKey key [])
          (surfaceSize callee + ((exprsChildren sources).map surfaceSize).sum) trace := by
        apply (typed_arguments_trace_keys children).widen (key' := childKey key []) rfl
        · simp [childKey]
        · simp [childKey, Nat.add_assoc]
      simpa only [surfaceSize_children, Interval.children, List.map_cons, List.sum_cons, List.append_nil] using
        TraceKeys.withRoot ⟨key, .standard binding, arguments, .rejected reason⟩ rfl widened
  | .fixedCallAbrupt env key callee labels positions sources binding type outcome trace recognized fixed children abrupt =>
      apply (typed_arguments_trace_keys children).widen (key' := key) rfl (by simp [childKey]; omega)
      simp [surfaceSize_children, Interval.children, childKey, Nat.add_assoc]
  | .standardCall env key callee labels positions sources binding values arguments result trace _ children _ _ =>
      have h := typed_arguments_trace_keys children
      have widened : TraceKeys (childKey key [])
          (surfaceSize callee + ((exprsChildren sources).map surfaceSize).sum) trace := by
        apply h.widen (key' := childKey key []) rfl (by simp [childKey] <;> omega)
        simp [childKey, Nat.add_assoc]
      simpa only [surfaceSize_children, Interval.children, List.map_cons, List.sum_cons] using
        TraceKeys.withRoot ⟨key, .standard binding, arguments, result⟩ rfl widened
  | .standardCallAbrupt env key callee labels positions sources binding outcome trace _ children _ =>
      apply (typed_arguments_trace_keys children).widen (key' := key) rfl (by simp [childKey] <;> omega)
      simp [surfaceSize_children, Interval.children, childKey, Nat.add_assoc]
  | .unknownNormal .. | .unknownFailed .. | .integer .. | .negInt ..
  | .integer8 .. | .integer16 .. | .integer32 .. | .unsignedInteger16 .. | .unsignedInteger32 .. | .unsignedInteger64 ..
  | .negInteger8 .. | .negInteger16 .. | .negInteger32 ..
  | .boolean .. | .unit .. | .local .. => exact TraceKeys.empty _ _
  | .paren _ _ _ _ _ _ e | .constE _ _ _ _ _ _ e | .returnE _ _ _ _ _ _ _ e
  | .negAbrupt _ _ _ _ _ e _
  | .widthNegAbrupt _ _ _ _ _ _ _ _ e _
  | .not _ _ _ _ _ e | .notAbrupt _ _ _ _ _ e _ =>
      simpa using (eval_trace_keys e).parent
  | .block _ _ _ _ _ _ e => simpa using (block_trace_keys e).parent
  | .neg env key source value trace e =>
      simpa only [surfaceSize_neg] using
        TraceKeys.withRoot ⟨key, .neg (.base .integer), [.integer value], checkedNeg value⟩
          rfl (eval_trace_keys e)
  | .widthNeg env key kind source value trace _ signed e =>
      simpa only [surfaceSize_neg] using
        TraceKeys.withRoot ⟨key, .neg kind.type, [.ofInteger kind value], kind.checkedNeg signed value⟩
          rfl (eval_trace_keys e)
  | .widthBinary env key kind op left right a b lt rt _ el er =>
      simpa only [surfaceSize_binary, Nat.add_assoc] using
        TraceKeys.withRoot ⟨key, .binary op.op kind.type,
          [.ofInteger kind a, .ofInteger kind b], op.apply kind a b⟩ rfl
          ((eval_trace_keys el).children (eval_trace_keys er))
  | .add env key left right a b lt rt el er =>
      simpa only [surfaceSize_binary, Nat.add_assoc] using
        TraceKeys.withRoot ⟨key, .binary .add (.base .integer),
          [.integer a, .integer b], checkedAdd a b⟩ rfl
          ((eval_trace_keys el).children (eval_trace_keys er))
  | .sub env key left right a b lt rt el er =>
      simpa only [surfaceSize_binary, Nat.add_assoc] using
        TraceKeys.withRoot ⟨key, .binary .sub (.base .integer),
          [.integer a, .integer b], checkedSub a b⟩ rfl
          ((eval_trace_keys el).children (eval_trace_keys er))
  | .mul env key left right a b lt rt el er =>
      simpa only [surfaceSize_binary, Nat.add_assoc] using
        TraceKeys.withRoot ⟨key, .binary .mul (.base .integer),
          [.integer a, .integer b], checkedMul a b⟩ rfl
          ((eval_trace_keys el).children (eval_trace_keys er))
  | .divMod env key op left right a b lt rt _ el er =>
      simpa only [surfaceSize_binary, Nat.add_assoc] using
        TraceKeys.withRoot ⟨key, .binary op (.base .integer),
          [.integer a, .integer b], checkedDivMod op a b⟩ rfl
          ((eval_trace_keys el).children (eval_trace_keys er))
  | .compare env key op left right a b lt rt el er =>
      simpa only [surfaceSize_binary, Nat.add_assoc] using
        TraceKeys.withRoot ⟨key, .binary op.binOp (.base .integer),
          [.integer a, .integer b], checkedCompare op a b⟩ rfl
          ((eval_trace_keys el).children (eval_trace_keys er))
  | .andShort _ _ _ _ _ e | .orShort _ _ _ _ _ e
  | .andAbrupt _ _ _ _ _ _ e _ | .orAbrupt _ _ _ _ _ _ e _
  | .addLeftAbrupt _ _ _ _ _ _ e _ | .subLeftAbrupt _ _ _ _ _ _ e _ | .mulLeftAbrupt _ _ _ _ _ _ e _ | .divModLeftAbrupt _ _ _ _ _ _ _ _ e _
  | .widthBinaryLeftAbrupt _ _ _ _ _ _ _ _ _ e _
  | .compareLeftAbrupt _ _ _ _ _ _ _ e _ =>
      apply (eval_trace_keys e).parent.widen rfl (Nat.le_refl _)
      simp only [surfaceSize_binary, surfaceSize_and, surfaceSize_or]; omega
  | .andRight _ _ _ _ _ _ _ el er | .orRight _ _ _ _ _ _ _ el er
  | .addRightAbrupt _ _ _ _ _ _ _ _ el er _ | .subRightAbrupt _ _ _ _ _ _ _ _ el er _ | .mulRightAbrupt _ _ _ _ _ _ _ _ el er _
  | .divModRightAbrupt _ _ _ _ _ _ _ _ _ _ el er _
  | .widthBinaryRightAbrupt _ _ _ _ _ _ _ _ _ _ _ el er _
  | .compareRightAbrupt _ _ _ _ _ _ _ _ _ el er _ =>
      simpa only [surfaceSize_binary, surfaceSize_and, surfaceSize_or, Nat.add_assoc] using
        ((eval_trace_keys el).children (eval_trace_keys er)).parent
  | .iteAbrupt _ _ _ _ _ _ _ _ c _ | .elseIfAbrupt _ _ _ _ _ _ _ _ c _
  | .ifOnlyAbrupt _ _ _ _ _ _ c _ | .ifOnlyFalse _ _ _ _ _ c =>
      apply (eval_trace_keys c).parent.widen rfl (Nat.le_refl _)
      simp only [surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly]; omega
  | .iteTrue _ _ _ _ _ _ _ _ _ c b | .elseIfTrue _ _ _ _ _ _ _ _ _ c b
  | .ifOnlyTrue _ _ _ _ _ _ _ c b =>
      apply TraceKeys.selected (gap := 0) (eval_trace_keys c)
        (by simpa [advanceKey, childKey] using block_trace_keys b)
      simp only [surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly]; omega
  | .iteFalse _ _ _ yes _ _ _ _ _ c b =>
      apply TraceKeys.selected (gap := blockSize yes) (eval_trace_keys c)
        (by simpa [advanceKey, childKey, blockSize, Nat.add_assoc] using block_trace_keys b)
      simp [surfaceSize_ite, blockSize]
  | .elseIfFalse _ _ _ yes _ _ _ _ _ c b =>
      apply TraceKeys.selected (gap := blockSize yes) (eval_trace_keys c)
        (by simpa [advanceKey, childKey, blockSize, Nat.add_assoc] using eval_trace_keys b)
      simp only [surfaceSize_elseIf]; omega

  | .matchInteger _ _ _ _ _ _ _ _ _ child selected =>
      simpa only [surfaceSize_matchE, Nat.add_assoc] using
        ((eval_trace_keys child).follow (by
          simpa [advanceKey, childKey] using arms_trace_keys selected)).parent
  | .matchWidth _ _ _ _ _ _ _ _ _ _ _ child selected =>
      simpa only [surfaceSize_matchE, Nat.add_assoc] using
        ((eval_trace_keys child).follow (by
          simpa [advanceKey, childKey] using widthArms_trace_keys selected)).parent
  | .matchResult _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ child selected =>
      simpa only [surfaceSize_matchE, Nat.add_assoc] using
        ((eval_trace_keys child).follow (by
          simpa [advanceKey, childKey] using resultArms_trace_keys selected)).parent
  | .matchAbrupt _ _ _ _ _ _ _ _ child _
  | .matchOtherNormal _ _ _ _ _ _ _ _ _ child _ _ _
  | .matchOtherFailed _ _ _ _ _ _ _ _ child _ _ =>
      apply (eval_trace_keys child).parent.widen rfl (Nat.le_refl _)
      simp only [surfaceSize_matchE]; omega

/-- 引数列の記録は、ソース順の連続した番号範囲に収まる。 -/
theorem arguments_trace_keys {env key sources type outcome trace}
    (eval : EvalArguments env key sources type outcome trace) :
    TraceKeys key ((sources.map surfaceSize).sum) trace := by
  match eval with
  | .nil .. => exact TraceKeys.empty _ _
  | .cons _ _ _ _ _ _ _ _ _ head tail
  | .tailAbrupt _ _ _ _ _ _ _ _ _ head tail =>
      simpa only [List.map_cons, List.sum_cons] using
        (eval_trace_keys head).follow (arguments_trace_keys tail)
  | .headAbrupt _ _ _ _ _ _ _ head _ =>
      apply (eval_trace_keys head).widen rfl (Nat.le_refl _)
      simp

theorem typed_arguments_trace_keys {env key sources types outcome trace}
    (eval : EvalTypedArguments env key sources types outcome trace) :
    TraceKeys key ((sources.map surfaceSize).sum) trace := by
  match eval with
  | .nil .. => exact TraceKeys.empty _ _
  | .cons _ _ _ _ _ _ _ _ _ _ head tail
  | .tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
      simpa only [List.map_cons, List.sum_cons] using
        (eval_trace_keys head).follow (typed_arguments_trace_keys tail)
  | .headAbrupt _ _ _ _ _ _ _ _ head _ =>
      apply (eval_trace_keys head).widen rfl (Nat.le_refl _)
      simp

/-- 容器は番号を使わず、右辺と続きを合わせた範囲にtraceを保つ。 -/
theorem block_trace_keys {env key body type outcome trace}
    (eval : EvalBlock env key body type outcome trace) :
    TraceKeys key (blockSize body) trace := by
  match eval with
  | .empty .. => exact TraceKeys.empty _ _
  | .builderBind _ _ _ _ _ _ _ e =>
      simpa [blockSize, blockChildren] using block_trace_keys e
  | .last _ _ _ _ _ _ e | .lastBind _ _ _ _ _ _ _ e
  | .lastDiscard _ _ _ _ _ _ e | .lastPat _ _ _ _ _ _ _ _ e =>
      simpa [blockSize, blockChildren] using eval_trace_keys e
  | .bind _ _ _ _ _ _ _ _ _ _ _ e r
  | .discard _ _ _ _ _ _ _ _ _ _ e r
  | .seq _ _ _ _ _ _ _ _ _ e r
  | .bindPat _ _ _ _ _ _ _ _ _ _ _ _ _ e _ r =>
      simpa [blockSize, blockChildren] using (eval_trace_keys e).follow (block_trace_keys r)
  | .bindAbrupt _ _ _ _ _ _ _ _ _ e _
  | .discardAbrupt _ _ _ _ _ _ _ _ e _
  | .seqAbrupt _ _ _ _ _ _ _ e _
  | .bindPatAbrupt _ _ _ _ _ _ _ _ _ _ e _ =>
      apply (eval_trace_keys e).widen rfl (Nat.le_refl _)
      simp [blockSize, blockChildren]
/-- 整数の腕の trace は guard・本体・次の腕の順の範囲を保つ。 -/
theorem arms_trace_keys {env key value arms type outcome trace}
    (eval : EvalArms env key value arms type outcome trace) :
    TraceKeys key (armsSize arms) trace := by
  match eval with
  | .nil .. => exact TraceKeys.empty _ _
  | .skip _ _ _ _ _ _ _ _ _ _ _ tail =>
      apply (arms_trace_keys tail).widen (key' := key) rfl (by simp [advanceKey])
      simp [advanceKey, armsSize_cons, Nat.add_assoc]
  | .body _ _ _ _ _ _ _ _ _ _ _ body =>
      apply (block_trace_keys body).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize]
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ condition body =>
      apply ((eval_trace_keys condition).follow (block_trace_keys body)).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize, Nat.add_assoc]
  | .guardFalse _ _ _ _ guard body _ _ _ _ _ _ _ condition tail =>
      have head := (eval_trace_keys condition).widen (size' := surfaceSize guard + blockSize body) rfl (Nat.le_refl _) (by dsimp; omega)
      apply (head.follow (arms_trace_keys tail)).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize, Nat.add_assoc]
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ condition _ =>
      apply (eval_trace_keys condition).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize]; omega

/-- Result の腕の記録も、guard と本体の元の番号範囲を保つ。 -/
theorem resultArms_trace_keys {env key names value tag payload arms type outcome trace}
    (eval : EvalResultArms env key names value tag payload arms type outcome trace) :
    TraceKeys key (armsSize arms) trace := by
  match eval with
  | .nil .. => exact TraceKeys.empty _ _
  | .skip _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      apply (resultArms_trace_keys tail).widen (key' := key) rfl (by simp [advanceKey])
      simp [advanceKey, armsSize_cons, Nat.add_assoc]
  | .body _ _ _ _ _ _ _ _ _ _ _ _ _ _ body =>
      apply (block_trace_keys body).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize]
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition body =>
      apply ((eval_trace_keys condition).follow (block_trace_keys body)).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize, Nat.add_assoc]
  | .guardFalse _ _ _ _ _ _ _ guard body _ _ _ _ _ _ _ condition tail =>
      have head := (eval_trace_keys condition).widen (size' := surfaceSize guard + blockSize body) rfl (Nat.le_refl _) (by dsimp; omega)
      apply (head.follow (resultArms_trace_keys tail)).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize, Nat.add_assoc]
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition _ =>
      apply (eval_trace_keys condition).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize]; omega

/-- 整数の腕の trace は guard・本体・次の腕の順の範囲を保つ。 -/
theorem widthArms_trace_keys {env key kind value arms type outcome trace}
    (eval : EvalWidthArms env key kind value arms type outcome trace) :
    TraceKeys key (armsSize arms) trace := by
  match eval with
  | .nil .. => exact TraceKeys.empty _ _
  | .skip _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      apply (widthArms_trace_keys tail).widen (key' := key) rfl (by simp [advanceKey])
      simp [advanceKey, armsSize_cons, Nat.add_assoc]
  | .body _ _ _ _ _ _ _ _ _ _ _ _ body =>
      apply (block_trace_keys body).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize]
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition body =>
      apply ((eval_trace_keys condition).follow (block_trace_keys body)).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize, Nat.add_assoc]
  | .guardFalse _ _ _ _ _ guard body _ _ _ _ _ _ _ condition tail =>
      have head := (eval_trace_keys condition).widen (size' := surfaceSize guard + blockSize body) rfl (Nat.le_refl _) (by dsimp; omega)
      apply (head.follow (widthArms_trace_keys tail)).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize, Nat.add_assoc]
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ condition _ =>
      apply (eval_trace_keys condition).widen rfl (Nat.le_refl _)
      simp [armsSize_cons, guardSize]; omega

end

/-- 同じキーを持つ二事象を trace に重複して含む評価の導出はない。 -/
theorem eval_trace_keys_nodup {env input outcome trace}
    (eval : EvalPartial env input outcome trace) : (trace.map EvalEvent.key).Nodup := by
  exact List.pairwise_map.mpr (eval_trace_keys eval).1

/-- 未対応式の正常な整数結果は必ずInteger64のTopに所属する。 -/
theorem unknown_integer_mem_top {env input value trace}
    (_unsupported : UnknownAt env input)
    (_eval : EvalPartial env input (.normal (.integer value)) trace) :
    Mem value.toInt top := (mem_top _).mpr value.toInt_bounds

/-- 接続した符号付き負号の根を、未知の親として扱う導出はない。 -/
theorem widthNeg_known (env : ConcreteEnv) (key : OperationKey) (kind : IntKind)
    (source : Expr) (signed : kind.min < 0) :
    ¬ UnknownAt env ⟨.neg kind.type source, kind.type, key⟩ := by
  simp [UnknownAt, Unsupported, classify, Unmodeled, signed]

/-- 未対応式は子の到達や警告の根拠となるtraceを作らない。 -/
theorem unsupported_trace_empty {env input outcome trace}
    (unsupported : UnknownAt env input)
    (eval : EvalPartial env input outcome trace) : trace = [] := by
  cases eval with
  | widthNeg _ _ _ _ _ _ _ signed _
  | widthNegAbrupt _ _ _ _ _ _ _ signed _ _ =>
      exact False.elim (widthNeg_known _ _ _ _ signed unsupported)
  | _ => first | rfl | simp_all [UnknownAt, Unsupported, Unmodeled, classify, IntKind.min, min64]


/-- 七種それぞれの型内の値は、その幅の具体整数の形とTop所属を持つ。 -/
theorem integerKind_value_in_top {kind : IntKind} {value : ConcreteValue}
    (typed : value.type = kind.type) :
    ∃ integer : IntegerValue kind,
      value = .ofInteger kind integer ∧ Mem integer.toInt (top kind) := by
  cases kind <;> cases value <;>
    simp only [ConcreteValue.type, IntKind.type] at typed
  all_goals first
    | cases typed; exact ⟨_, rfl, (mem_top _ _).mpr (IntegerValue.toInt_bounds _)⟩
    | (rename_i t notInteger _ _;
       have impossible := notInteger;
       rw [typed] at impossible;
       contradiction)
    | simp_all

/-- 型がInteger64なら、未知の正常値でも整数の形とTop所属を取り出せる。 -/
theorem integer_value_in_top {value : ConcreteValue}
    (typed : value.type = .base .integer) :
    ∃ integer, value = .integer integer ∧ Mem integer.toInt top :=
  integerKind_value_in_top (kind := .integer64) typed

/-- 未対応式では型の全値域を許し、正常値のないBottomに退かない。 -/
theorem unknown_integer_possible (env : ConcreteEnv) (input : EvalInput)
    (unsupported : UnknownAt env input) (typed : input.type = .base .integer)
    (value : Integer64Value) :
    EvalPartial env input (.normal (.integer value)) [] ∧ Mem value.toInt top := by
  exact ⟨.unknownNormal env input (.integer value) unsupported typed.symm,
    (mem_top _).mpr value.toInt_bounds⟩

/-- 成功値は三入力の実値だけを保ち、指定した区間に所属する。 -/
theorem range_success_fields {names key lo hi value output}
    (success : rangeCheck names key lo hi value = .normal output) :
    output = rangePayload names.record lo hi value ∧
      Checked.Range.InRange lo.toInt hi.toInt value.toInt := by
  cases made : Checked.Range.make lo.toInt hi.toInt value.toInt with
  | ok checked =>
      simp only [rangeCheck, made, OperationResult.normal.injEq] at success
      exact ⟨success.symm, (Checked.Range.make_ok _ _ _ _ made).2.2.2⟩
  | error error =>
      cases error <;> simp [rangeCheck, made] at success

/-- 固定域の外からAPIの正常結果を得る規則はない。 -/
theorem domain_outside_no_normal {position lo hi result key args value output}
    (atPosition : args[position]? = some (.integer value))
    (outside : ¬ (lo ≤ value.toInt ∧ value.toInt ≤ hi)) :
    ¬ EvalStandard (.fixedDomain position lo hi result) key args (.normal output) := by
  intro eval
  cases eval with
  | domainNormal _ _ _ _ _ _ other _ atOther inside _ =>
      have same : other = value := by simpa [atPosition] using atOther.symm
      subst other
      exact outside inside

/-- 警告が述べる原因。未知の失敗やRangeのErrorは警告の原因に含めない。 -/
inductive WarningCause where
  | zeroDivisor | overflow | outsideDomain
  deriving DecidableEq, Repr

/-- W0401・W0402・W0404の原因を、それぞれ対応する拒否理由へ写す。 -/
def WarningCause.toFailure : WarningCause → Failure
  | .zeroDivisor => .zeroDivisor
  | .overflow => .overflow
  | .outsideDomain => .outsideDomain

/-- 警告は対象演算のキー・種類と、拒否を主張する原因を持つ。 -/
structure IntervalWarning where
  key : OperationKey
  operation : TargetOperation
  cause : WarningCause

/-- 正常値の近似と失敗可能性を分ける。具体的な区間表現は解析側が与える。 -/
structure AnalysisResult where
  normal : ConcreteValue → Prop
  mayFail : Bool
  warnings : List IntervalWarning

/-- 未対応の共通解析規則。正常値は型の全値域、失敗可能、警告なしとする。 -/
def unknownAnalysis (type : Ty) : AnalysisResult :=
  ⟨fun value => value.type = type, true, []⟩

/-- 未対応の正常評価は、共通解析規則の正常値集合に入る。 -/
theorem unknown_analysis_sound {env input value trace}
    (unknown : UnknownAt env input)
    (eval : EvalPartial env input (.normal value) trace) :
    (unknownAnalysis input.type).normal value := by
  generalize resultEq : EvalOutcome.normal value = outcome at eval
  cases eval with
  | unknownNormal _ _ _ _ typed => cases resultEq; exact typed
  | unknownFailed => contradiction
  | returnE _ _ _ _ _ child _ _ => cases child <;> cases resultEq
  | widthNeg _ _ _ _ _ _ _ signed _
  | widthNegAbrupt _ _ _ _ _ _ _ signed _ _ =>
      exact False.elim (widthNeg_known _ _ _ _ signed unknown)
  | _ => simp_all [UnknownAt, Unsupported, Unmodeled, classify, IntKind.min, min64]
  all_goals rename_i op _ _ _ _ _ _; cases op <;> simp_all [Comparison.binOp, Comparison.ofBinOp]

/-- 警告位置に到達し、正常引数を得た実行の記録。 -/
def Reached (trace : EvalTrace) (warning : IntervalWarning) (event : EvalEvent) : Prop :=
  event ∈ trace ∧ event.key = warning.key ∧ event.operation = warning.operation

private theorem comparison_not_division (comparison : Comparison) :
    ¬ IntegerDivisionOp comparison.binOp := by
  cases comparison <;> simp [IntegerDivisionOp, Comparison.binOp]

mutual
/-- 整数除算の到達記録は、正常な二引数と実際の検査結果からだけ作られる。 -/
theorem eval_divMod_event {env input outcome trace event op}
    (eval : EvalPartial env input outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧
      event.result = checkedDivMod op a b := by
  match eval with
  | .fixedCallFailed _ _ _ _ _ _ _ _ _ _ _ _ _ _ children _ _ =>
      rcases List.mem_append.mp found with child | own
      · exact typed_arguments_divMod_event children child operation target
      · obtain rfl := List.mem_singleton.mp own; contradiction
  | .fixedCallAbrupt _ _ _ _ _ _ _ _ _ _ _ _ children _ =>
      exact typed_arguments_divMod_event children found operation target
  | .standardCall _ _ _ _ _ _ _ _ _ _ _ _ children _ _ =>
      rcases List.mem_append.mp found with child | own
      · exact typed_arguments_divMod_event children child operation target
      · obtain rfl := List.mem_singleton.mp own
        contradiction
  | .standardCallAbrupt _ _ _ _ _ _ _ _ _ _ children _ =>
      exact typed_arguments_divMod_event children found operation target
  | .unknownNormal .. | .unknownFailed .. | .integer .. | .negInt ..
  | .integer8 .. | .integer16 .. | .integer32 .. | .unsignedInteger16 .. | .unsignedInteger32 .. | .unsignedInteger64 ..
  | .negInteger8 .. | .negInteger16 .. | .negInteger32 ..
  | .boolean .. | .unit .. | .local .. => simp at found
  | .paren _ _ _ _ _ _ e | .constE _ _ _ _ _ _ e | .returnE _ _ _ _ _ _ _ e
  | .negAbrupt _ _ _ _ _ e _
  | .widthNegAbrupt _ _ _ _ _ _ _ _ e _
  | .not _ _ _ _ _ e | .notAbrupt _ _ _ _ _ e _
  | .addLeftAbrupt _ _ _ _ _ _ e _ | .subLeftAbrupt _ _ _ _ _ _ e _ | .mulLeftAbrupt _ _ _ _ _ _ e _ | .divModLeftAbrupt _ _ _ _ _ _ _ _ e _
  | .andShort _ _ _ _ _ e | .orShort _ _ _ _ _ e
  | .andAbrupt _ _ _ _ _ _ e _ | .orAbrupt _ _ _ _ _ _ e _
  | .widthBinaryLeftAbrupt _ _ _ _ _ _ _ _ _ e _
  | .compareLeftAbrupt _ _ _ _ _ _ _ e _
  | .iteAbrupt _ _ _ _ _ _ _ _ e _ | .elseIfAbrupt _ _ _ _ _ _ _ _ e _
  | .ifOnlyAbrupt _ _ _ _ _ _ e _ | .ifOnlyFalse _ _ _ _ _ e =>
      exact eval_divMod_event e found operation target
  | .neg _ _ _ _ _ e =>
      rcases List.mem_append.mp found with child | own
      · exact eval_divMod_event e child operation target
      · obtain rfl := List.mem_singleton.mp own
        contradiction
  | .widthNeg _ _ _ _ _ _ _ _ e =>
      rcases List.mem_append.mp found with child | own
      · exact eval_divMod_event e child operation target
      · obtain rfl := List.mem_singleton.mp own
        contradiction
  | .widthBinary _ _ kind _ _ _ _ _ _ _ not64 el er =>
      rcases List.mem_append.mp found with children | own
      · rcases List.mem_append.mp children with child | child
        · exact eval_divMod_event el child operation target
        · exact eval_divMod_event er child operation target
      · obtain rfl := List.mem_singleton.mp own
        have typed := (TargetOperation.binary.inj operation).2
        exact False.elim (IntKind.type_ne_integer not64 typed)
  | .block _ _ _ _ _ _ e => exact block_divMod_event e found operation target
  | .andRight _ _ _ _ _ _ _ el er | .orRight _ _ _ _ _ _ _ el er
  | .addRightAbrupt _ _ _ _ _ _ _ _ el er _ | .subRightAbrupt _ _ _ _ _ _ _ _ el er _ | .mulRightAbrupt _ _ _ _ _ _ _ _ el er _
  | .divModRightAbrupt _ _ _ _ _ _ _ _ _ _ el er _
  | .widthBinaryRightAbrupt _ _ _ _ _ _ _ _ _ _ _ el er _
  | .compareRightAbrupt _ _ _ _ _ _ _ _ _ el er _
  | .elseIfFalse _ _ _ _ _ _ _ _ _ el er =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event el h operation target
      · exact eval_divMod_event er h operation target
  | .iteTrue _ _ _ _ _ _ _ _ _ c b | .elseIfTrue _ _ _ _ _ _ _ _ _ c b
  | .ifOnlyTrue _ _ _ _ _ _ _ c b | .iteFalse _ _ _ _ _ _ _ _ _ c b =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event c h operation target
      · exact block_divMod_event b h operation target
  | .add _ _ _ _ a b _ _ el er | .sub _ _ _ _ a b _ _ el er | .mul _ _ _ _ a b _ _ el er | .divMod _ _ _ _ _ a b _ _ _ el er
  | .compare _ _ _ _ _ a b _ _ el er =>
      simp only [List.mem_append, List.mem_singleton] at found
      rcases found with (h | h) | h
      · exact eval_divMod_event el h operation target
      · exact eval_divMod_event er h operation target
      · subst event
        simp only [TargetOperation.binary.injEq] at operation
        cases operation.1
        first
        | exact ⟨a, b, rfl, rfl⟩
        | exact False.elim (comparison_not_division _ target)
        | simp [IntegerDivisionOp] at target

  | .matchInteger _ _ _ _ _ _ _ _ _ child selected =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event child h operation target
      · exact arms_divMod_event selected h operation target
  | .matchWidth _ _ _ _ _ _ _ _ _ _ _ child selected =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event child h operation target
      · exact widthArms_divMod_event selected h operation target
  | .matchResult _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ child selected =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event child h operation target
      · exact resultArms_divMod_event selected h operation target
  | .matchAbrupt _ _ _ _ _ _ _ _ child _
  | .matchOtherNormal _ _ _ _ _ _ _ _ _ child _ _ _
  | .matchOtherFailed _ _ _ _ _ _ _ _ child _ _ =>
      exact eval_divMod_event child found operation target

/-- 引数内の事象も、実際に評価した対象演算に由来する。 -/
theorem arguments_divMod_event {env key sources type outcome trace event op}
    (eval : EvalArguments env key sources type outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧
      event.result = checkedDivMod op a b := by
  match eval with
  | .nil .. => simp at found
  | .cons _ _ _ _ _ _ _ _ _ head tail
  | .tailAbrupt _ _ _ _ _ _ _ _ _ head tail =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event head h operation target
      · exact arguments_divMod_event tail h operation target
  | .headAbrupt _ _ _ _ _ _ _ head _ =>
      exact eval_divMod_event head found operation target

theorem typed_arguments_divMod_event {env key sources types outcome trace event op}
    (eval : EvalTypedArguments env key sources types outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧
      event.result = checkedDivMod op a b := by
  match eval with
  | .nil .. => simp at found
  | .cons _ _ _ _ _ _ _ _ _ _ head tail
  | .tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event head h operation target
      · exact typed_arguments_divMod_event tail h operation target
  | .headAbrupt _ _ _ _ _ _ _ _ head _ =>
      exact eval_divMod_event head found operation target

/-- Blockの各事象も、実際に評価した式の除算の規則に由来する。 -/
theorem block_divMod_event {env key body type outcome trace event op}
    (eval : EvalBlock env key body type outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧
      event.result = checkedDivMod op a b := by
  match eval with
  | .empty .. => simp at found
  | .builderBind _ _ _ _ _ _ _ e => exact block_divMod_event e found operation target
  | .last _ _ _ _ _ _ e | .lastBind _ _ _ _ _ _ _ e
  | .lastDiscard _ _ _ _ _ _ e | .lastPat _ _ _ _ _ _ _ _ e
  | .bindAbrupt _ _ _ _ _ _ _ _ _ e _
  | .discardAbrupt _ _ _ _ _ _ _ _ e _
  | .seqAbrupt _ _ _ _ _ _ _ e _
  | .bindPatAbrupt _ _ _ _ _ _ _ _ _ _ e _ =>
      exact eval_divMod_event e found operation target
  | .bind _ _ _ _ _ _ _ _ _ _ _ e r
  | .discard _ _ _ _ _ _ _ _ _ _ e r
  | .seq _ _ _ _ _ _ _ _ _ e r
  | .bindPat _ _ _ _ _ _ _ _ _ _ _ _ _ e _ r =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event e h operation target
      · exact block_divMod_event r h operation target
/-- 腕で実行した除算も、実引数と実検査結果を持つ。 -/
theorem arms_divMod_event {env key value arms type outcome trace event op}
    (eval : EvalArms env key value arms type outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧ event.result = checkedDivMod op a b := by
  match eval with
  | .nil .. => simp at found
  | .skip _ _ _ _ _ _ _ _ _ _ _ tail => exact arms_divMod_event tail found operation target
  | .body _ _ _ _ _ _ _ _ _ _ _ body => exact block_divMod_event body found operation target
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ condition body =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event condition h operation target
      · exact block_divMod_event body h operation target
  | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ condition tail =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event condition h operation target
      · exact arms_divMod_event tail h operation target
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ condition _ =>
      exact eval_divMod_event condition found operation target

/-- Result の腕の事象も、実際の子の評価導出から得る。 -/
theorem resultArms_divMod_event {env key names value tag payload arms type outcome trace event op}
    (eval : EvalResultArms env key names value tag payload arms type outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧ event.result = checkedDivMod op a b := by
  match eval with
  | .nil .. => simp at found
  | .skip _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail => exact resultArms_divMod_event tail found operation target
  | .body _ _ _ _ _ _ _ _ _ _ _ _ _ _ body => exact block_divMod_event body found operation target
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition body =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event condition h operation target
      · exact block_divMod_event body h operation target
  | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition tail =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event condition h operation target
      · exact resultArms_divMod_event tail h operation target
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition _ =>
      exact eval_divMod_event condition found operation target

/-- 腕で実行した除算も、実引数と実検査結果を持つ。 -/
theorem widthArms_divMod_event {env key kind value arms type outcome trace event op}
    (eval : EvalWidthArms env key kind value arms type outcome trace) (found : event ∈ trace)
    (operation : event.operation = .binary op (.base .integer))
    (target : IntegerDivisionOp op) :
    ∃ a b, event.arguments = [.integer a, .integer b] ∧ event.result = checkedDivMod op a b := by
  match eval with
  | .nil .. => simp at found
  | .skip _ _ _ _ _ _ _ _ _ _ _ _ tail => exact widthArms_divMod_event tail found operation target
  | .body _ _ _ _ _ _ _ _ _ _ _ _ body => exact block_divMod_event body found operation target
  | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition body =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event condition h operation target
      · exact block_divMod_event body h operation target
  | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ condition tail =>
      rcases List.mem_append.mp found with h | h
      · exact eval_divMod_event condition h operation target
      · exact widthArms_divMod_event tail h operation target
  | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ condition _ =>
      exact eval_divMod_event condition found operation target

end

/-- 正常値の中心定理の言明。任意の環境・予算・正常評価を量化する。 -/
def NormalSoundness {AbstractEnv Budget : Type}
    (Models : AbstractEnv → ConcreteEnv → Prop)
    (analyze : AbstractEnv → EvalInput → Budget → AnalysisResult) : Prop :=
  ∀ abstract concrete input budget value trace,
    Models abstract concrete → EvalPartial concrete input (.normal value) trace →
      (analyze abstract input budget).normal value

/-- 警告の中心定理の言明。到達した演算の拒否理由は警告の原因と一致する。 -/
def WarningSoundness {AbstractEnv Budget : Type}
    (Models : AbstractEnv → ConcreteEnv → Prop)
    (analyze : AbstractEnv → EvalInput → Budget → AnalysisResult) : Prop :=
  ∀ abstract concrete input budget outcome trace,
    Models abstract concrete → EvalPartial concrete input outcome trace →
      ∀ warning ∈ (analyze abstract input budget).warnings,
        ∀ event, Reached trace warning event →
          event.result = .rejected warning.cause.toFailure

-- (1 intDiv 1) intDiv 0 は、内側の正常終了と外側の拒否を異なるキーに記録する。
-- 同じ入力・同じ二演算でも、親のキーを内側へ再利用した trace の導出はない。
example (env : ConcreteEnv) (key : OperationKey) :
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let input : EvalInput := ⟨.binary .intDiv (.base .integer)
      (.binary .intDiv (.base .integer) one one) zero, .base .integer, key⟩
    let successful : EvalEvent := ⟨childKey key [], .binary .intDiv (.base .integer),
      [.integer ⟨1, by decide⟩, .integer ⟨1, by decide⟩], .normal (.integer ⟨1, by decide⟩)⟩
    let rejected : EvalEvent := ⟨key, .binary .intDiv (.base .integer),
      [.integer ⟨1, by decide⟩, .integer ⟨0, by decide⟩], .rejected .zeroDivisor⟩
    EvalPartial env input (.failed .zeroDivisor) [successful, rejected] ∧
    ∀ outcome, ¬ EvalPartial env input outcome [{ successful with key := key }, rejected] := by
  dsimp only
  constructor
  · exact .divMod env key .intDiv _ _ _ _ [_] [] (Or.inl rfl)
      (.divMod env (childKey key []) .intDiv _ _ _ _ [] [] (Or.inl rfl)
        (.integer _ _ _) (.integer _ _ _)) (.integer _ _ _)
  · intro outcome eval
    have distinct := eval_trace_keys_nodup eval
    simp at distinct

-- 未同定の呼び出しの引数に除数0があっても、境界の内部の実行順は主張しない。
example (key : OperationKey) :
    let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
    let input : EvalInput := ⟨.call (.funName "Example.f" [] []) [none] [0]
      (.cons (.binary .intDiv (.base .integer)
        (.literal (.integer ⟨1, by decide⟩)) (.literal (.integer ⟨0, by decide⟩))) .nil),
      .base .integer, key⟩
    EvalPartial env input (.normal (.integer ⟨min64, by constructor <;> decide⟩)) [] ∧
    EvalPartial env input (.normal (.integer ⟨max64, by constructor <;> decide⟩)) [] ∧
    EvalPartial env input (.failed .unknown) [] := by
  refine ⟨.unknownNormal _ _ _ ?_ rfl, .unknownNormal _ _ _ ?_ rfl, .unknownFailed _ _ ?_⟩
  all_goals exact Or.inr (Or.inr (by simp [rangeCallBinding, ConcreteEnv.standardAt]))

-- APIの拒否をプロセスの失敗と取り違えず、Result.Errorと元の三入力を残す。
example (names : RangeNames) (key : OperationKey) :
    (StandardRule.rangeCheck names).finish
      (rangeCheck names key ⟨10, by decide⟩ ⟨0, by decide⟩ ⟨5, by decide⟩) =
      .normal (.con names.result [.data names.owner [], .data names.error []] names.err
        [.rangeError names.error names.invalidBounds (.invalidBounds 10 0)]) ∧
    (StandardRule.rangeCheck names).finish
      (rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨11, by decide⟩) =
      .normal (.con names.result [.data names.owner [], .data names.error []] names.err
        [.rangeError names.error names.outOfRange (.outOfRange 0 10 11)]) := by
  constructor <;> rfl

-- 固定域の外ではW0404の原因で拒否し、正常結果やW0401の原因での拒否を許さない。
example (key : OperationKey) :
    EvalStandard (.fixedDomain 0 0 255 (.base .unit)) key
      [.integer ⟨256, by decide⟩] (.rejected WarningCause.outsideDomain.toFailure) ∧
    ¬ EvalStandard (.fixedDomain 0 0 255 (.base .unit)) key
      [.integer ⟨256, by decide⟩] (.normal .unit) ∧
    ¬ EvalStandard (.fixedDomain 0 0 255 (.base .unit)) key
      [.integer ⟨256, by decide⟩] (.rejected WarningCause.zeroDivisor.toFailure) := by
  refine ⟨?_, ?_, ?_⟩
  · exact .domainRejected _ _ _ _ _ _ _ rfl (by decide)
  · exact domain_outside_no_normal rfl (by decide)
  · intro eval
    cases eval

-- 六比較を実際の評価関係につなぐ。期待する真偽の列は独立に固定する。
example (env : ConcreteEnv) (key : OperationKey) :
    let left : Expr := .negInt ⟨1, by decide⟩
    let right : Expr := .literal (.integer ⟨1, by decide⟩)
    ∀ pair ∈ [(Comparison.eq, false), (.ne, true), (.lt, true),
      (.le, true), (.gt, false), (.ge, false)],
      ∃ trace, EvalPartial env
        ⟨.binary pair.1.binOp (.base .integer) left right, .base .boolean, key⟩
        (.normal (.boolean pair.2)) trace ∧ (trace.map EvalEvent.key) = [key] := by
  dsimp
  have run (op : Comparison) : ∃ trace,
      EvalPartial env ⟨.binary op.binOp (.base .integer) (.negInt ⟨1, by decide⟩)
        (.literal (.integer ⟨1, by decide⟩)), .base .boolean, key⟩
        (checkedCompare op (Integer64Magnitude.negValue ⟨1, by decide⟩)
          (Integer64Literal.toValue ⟨1, by decide⟩)).outcome trace ∧
        trace.map EvalEvent.key = [key] :=
    ⟨_, .compare env key op _ _ _ _ [] [] (.negInt env _ _) (.integer env _ _), rfl⟩
  intro pair member
  simp only [List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl | rfl | rfl | rfl
  all_goals first
    | simpa [checkedCompare, Comparison.Holds, OperationResult.outcome,
        Integer64Literal.toValue, Integer64Magnitude.negValue, Integer64Value.toInt] using run .eq
    | simpa [checkedCompare, Comparison.Holds, OperationResult.outcome,
        Integer64Literal.toValue, Integer64Magnitude.negValue, Integer64Value.toInt] using run .ne
    | simpa [checkedCompare, Comparison.Holds, OperationResult.outcome,
        Integer64Literal.toValue, Integer64Magnitude.negValue, Integer64Value.toInt] using run .lt
    | simpa [checkedCompare, Comparison.Holds, OperationResult.outcome,
        Integer64Literal.toValue, Integer64Magnitude.negValue, Integer64Value.toInt] using run .le
    | simpa [checkedCompare, Comparison.Holds, OperationResult.outcome,
        Integer64Literal.toValue, Integer64Magnitude.negValue, Integer64Value.toInt] using run .gt
    | simpa [checkedCompare, Comparison.Holds, OperationResult.outcome,
        Integer64Literal.toValue, Integer64Magnitude.negValue, Integer64Value.toInt] using run .ge

-- 右辺→新しいshadow位置→専用位置→discard→式文→パターン→末尾の順。
-- builderは番号を使わず、discardとunitのパターンは通常位置を追加しない。
example (env : ConcreteEnv) (key : OperationKey) :
    let seven : Expr := .literal (.integer ⟨7, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let source : Expr := .block (.bind .bind (.base .integer) seven
      (.bind .shadow (.base .integer) zero (.builderBind .string
        (.discard (.local 2) (.seq (.block (.lastDiscard (.local 1)))
          (.bindPat .bind .unit (.base .unit) .unit
            (.last (.binary .add (.base .integer) (.local 1) (.local 2)))))))))
    EvalPartial env ⟨source, .base .integer, key⟩ (.normal (.integer ⟨7, by decide⟩))
      [⟨⟨key.definition, key.surfacePreorder + 7⟩, .binary .add (.base .integer),
        [.integer ⟨0, by decide⟩, .integer ⟨7, by decide⟩], .normal (.integer ⟨7, by decide⟩)⟩] := by
  dsimp
  apply EvalPartial.block
  apply EvalBlock.bind (value := .integer ⟨7, by decide⟩) (et := [])
  · exact .integer _ _ _
  apply EvalBlock.bind (value := .integer ⟨0, by decide⟩) (et := [])
  · exact .integer _ _ _
  apply EvalBlock.builderBind
  apply EvalBlock.discard (sourceType := .base .integer)
    (value := .integer ⟨7, by decide⟩) (et := [])
  · exact .local _ _ 2 (.integer ⟨7, by decide⟩) rfl
  apply EvalBlock.seq (value := .unit) (et := [])
  · apply EvalPartial.block
    exact .lastDiscard _ _ (.local 1) (.base .integer) (.normal (.integer ⟨0, by decide⟩)) []
      (.local _ _ 1 (.integer ⟨0, by decide⟩) rfl)
  apply EvalBlock.bindPat (value := .unit) (values := []) (et := [])
  · exact .unit _ _
  · rfl
  apply EvalBlock.last
  let inner : ConcreteEnv := { env with locals :=
    [none, some (.integer ⟨0, by decide⟩), some (.integer ⟨7, by decide⟩)] ++ env.locals }
  have h := EvalPartial.add inner ⟨key.definition, key.surfacePreorder + 7⟩ (.local 1) (.local 2)
    ⟨0, by decide⟩ ⟨7, by decide⟩ [] []
    (.local inner _ 1 (.integer ⟨0, by decide⟩) rfl)
    (.local inner _ 2 (.integer ⟨7, by decide⟩) rfl)
  simpa [childKey, advanceKey, surfaceSize, surfacePreorder, preorderBlock, checkedAdd,
    Integer64Value.toInt, min64, max64, OperationResult.outcome, Nat.add_assoc, inner] using h

-- falseのifOnlyは、除数0を含む本体を評価せずUnitを返す。
-- 導出の存在と、任意の導出の空traceを組にし、空虚な否定を避ける。
example (env : ConcreteEnv) (key : OperationKey) (yes : Block) :
    EvalPartial env ⟨.ifOnly (.literal (.boolean false)) yes, .base .unit, key⟩
      (.normal .unit) [] ∧
    ∀ outcome trace,
      EvalPartial env ⟨.ifOnly (.literal (.boolean false)) yes, .base .unit, key⟩
        outcome trace → outcome = .normal .unit ∧ trace = [] := by
  refine ⟨.ifOnlyFalse _ _ _ _ _ (.boolean _ _ _), ?_⟩
  intro outcome trace eval
  match eval with
  | .unknownNormal _ _ _ h _ | .unknownFailed _ _ h =>
      simp [UnknownAt, Unsupported, Unmodeled, classify] at h
  | .ifOnlyTrue _ _ _ _ _ _ _ condition _ =>
      cases condition <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify]
  | .ifOnlyFalse _ _ _ _ _ condition =>
      cases condition <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify]
  | .ifOnlyAbrupt _ _ _ _ _ _ condition abrupt =>
      cases condition <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify, EvalOutcome.Abrupt]

-- returnは末尾の束縛でもUnitに変わらず、Blockの後続とifの未選択枝を飛ばす。
example (env : ConcreteEnv) (key : OperationKey) (rest : Block) (no : Block) :
    let yes : Block := .bind .bind (.base .unit) (.returnE (.base .unit) .unit) rest
    EvalPartial env ⟨.ite (.not (.literal (.boolean false))) yes no, .base .unit, key⟩
      (.returned .unit) [] ∧
    EvalBlock env key (.lastBind .shadow (.base .unit) (.returnE (.base .unit) .unit))
      (.base .unit) (.returned .unit) [] ∧
    EvalBlock env key (.lastPat .bind .unit (.base .unit) .unit)
      (.base .unit) (.normal .unit) [] := by
  refine ⟨?_, ?_, ?_⟩
  · simpa using EvalPartial.iteTrue env key _ _ no (.base .unit) (.returned .unit) [] []
      (.not _ _ _ _ _ (.boolean _ _ false))
      (.bindAbrupt _ _ _ _ _ _ _ _ _ (.returnE _ _ _ _ _ _ _ (.unit _ _)) trivial)
  · exact .lastBind _ _ _ _ _ _ _ (.returnE _ _ _ _ _ _ _ (.unit _ _))
  · exact .lastPat _ _ _ _ _ _ _ _ (.unit _ _)

-- elseIfの偽枝の番号は、実行しなかったyes全体の番号を飛ばす。
-- 選ばれなかった除数0の事象は作らず、選んだ枝の加算だけを番号7に記録する。
example (env : ConcreteEnv) (key : OperationKey) :
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let yes : Block := .last (.binary .intDiv (.base .integer) one (.literal (.integer ⟨0, by decide⟩)))
    let no : Expr := .ite (.literal (.boolean true))
      (.last (.binary .add (.base .integer) one one)) (.last one)
    EvalPartial env ⟨.elseIf (.literal (.boolean false)) yes no, .base .integer, key⟩
      (.normal (.integer ⟨2, by decide⟩))
      [⟨⟨key.definition, key.surfacePreorder + 7⟩, .binary .add (.base .integer),
        [.integer ⟨1, by decide⟩, .integer ⟨1, by decide⟩], .normal (.integer ⟨2, by decide⟩)⟩] := by
  dsimp
  apply EvalPartial.elseIfFalse (ct := [])
  · exact .boolean _ _ _
  apply EvalPartial.iteTrue (ct := [])
  · exact .boolean _ _ _
  apply EvalBlock.last
  have h := EvalPartial.add env ⟨key.definition, key.surfacePreorder + 7⟩
    (.literal (.integer ⟨1, by decide⟩)) (.literal (.integer ⟨1, by decide⟩))
    (Integer64Literal.toValue ⟨1, by decide⟩) (Integer64Literal.toValue ⟨1, by decide⟩)
    [] [] (.integer _ _ _) (.integer _ _ _)
  simpa [childKey, surfaceSize, surfacePreorder, preorderBlock, blockChildren, checkedAdd,
    Integer64Literal.toValue, Integer64Value.toInt, min64, max64, OperationResult.outcome,
    Nat.add_assoc] using h

-- 条件内の除数0はdiscard、block、notを抜け、ifの両枝を評価せず伝播する。
example (env : ConcreteEnv) (key : OperationKey) (yes no : Block) :
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let cond : Expr := .not (.block (.discard (.binary .intDiv (.base .integer) one zero)
      (.last (.literal (.boolean true)))))
    EvalPartial env ⟨.ite cond yes no, .base .unit, key⟩ (.failed .zeroDivisor)
      [⟨⟨key.definition, key.surfacePreorder + 3⟩, .binary .intDiv (.base .integer),
        [.integer ⟨1, by decide⟩, .integer ⟨0, by decide⟩], .rejected .zeroDivisor⟩] := by
  dsimp
  apply EvalPartial.iteAbrupt
  · apply EvalPartial.notAbrupt
    · apply EvalPartial.block
      apply EvalBlock.discardAbrupt (sourceType := .base .integer)
      · have h := EvalPartial.divMod env ⟨key.definition, key.surfacePreorder + 3⟩ .intDiv
          (.literal (.integer ⟨1, by decide⟩)) (.literal (.integer ⟨0, by decide⟩))
          (Integer64Literal.toValue ⟨1, by decide⟩) (Integer64Literal.toValue ⟨0, by decide⟩)
          [] [] (Or.inl rfl) (.integer _ _ _) (.integer _ _ _)
        simpa [childKey, checkedDivMod, IntegerDivisionOp, Integer64Literal.toValue,
          Integer64Value.toInt, OperationResult.outcome, Nat.add_assoc] using h
      · trivial
    · trivial
  · trivial

-- 右辺に導出があることを前提にせず、短絡した値と空traceを構成する。
example (env : ConcreteEnv) (key : OperationKey) (right : Expr) :
    EvalPartial env ⟨.and (.literal (.boolean false)) right, .base .boolean, key⟩
      (.normal (.boolean false)) [] ∧
    EvalPartial env ⟨.or (.literal (.boolean true)) right, .base .boolean, key⟩
      (.normal (.boolean true)) [] := by
  exact ⟨.andShort _ _ _ _ [] (.boolean _ _ _), .orShort _ _ _ _ [] (.boolean _ _ _)⟩

-- 到達した右辺の除数0は同じキーで記録し、左辺・右辺のreturnはその場で伝播する。
example (env : ConcreteEnv) :
    let key : OperationKey := ⟨"Example.shortCircuitEvaluation", 0⟩
    let yes : Expr := .literal (.boolean true)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let bad : Expr := .binary .eq (.base .integer)
      (.binary .intDiv (.base .integer) (.literal (.integer ⟨1, by decide⟩)) zero) zero
    EvalPartial env ⟨.and yes bad, .base .boolean, key⟩ (.failed .zeroDivisor)
      [⟨⟨"Example.shortCircuitEvaluation", 3⟩, .binary .intDiv (.base .integer),
        [.integer ⟨1, by decide⟩, .integer ⟨0, by decide⟩], .rejected .zeroDivisor⟩] ∧
    EvalPartial env ⟨.and (.returnE (.base .boolean) yes) bad, .base .boolean, key⟩
      (.returned (.boolean true)) [] ∧
    EvalPartial env ⟨.or (.literal (.boolean false)) (.returnE (.base .boolean) yes),
      .base .boolean, key⟩ (.returned (.boolean true)) [] := by
  dsimp only
  refine ⟨?_, ?_, ?_⟩
  · apply EvalPartial.andRight (leftTrace := [])
    · exact .boolean _ _ _
    · apply EvalPartial.compareLeftAbrupt (op := .eq)
      · exact EvalPartial.divMod env ⟨"Example.shortCircuitEvaluation", 3⟩ .intDiv
          _ _ _ _ [] [] (Or.inl rfl) (.integer _ _ _) (.integer _ _ _)
      · trivial
  · exact .andAbrupt _ _ _ _ _ []
      (.returnE _ _ _ _ _ _ [] (.boolean _ _ _)) trivial
  · exact .orRight _ _ _ _ _ [] [] (.boolean _ _ _)
      (.returnE _ _ _ _ _ _ [] (.boolean _ _ _))

end Benitoite.Interval
