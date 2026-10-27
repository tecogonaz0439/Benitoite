import Benitoite.Interval.Analyze
import Benitoite.Interval.FixedDomain
import Benitoite.Interval.TablePreservation

/-!
# 土台の解析と健全性

子の正常値の所属と、出現の番号範囲を併せて警告を合成する
（設計書 01-12「区間解析の土台の解析と健全性」）。
短絡で評価する右辺へだけ、左辺の真偽環境を渡す
（設計書 01-12「区間解析の短絡と複合条件」）。
整数の腕と guard の真の環境を接続し、return のオペランドの後で正常値を消す
（設計書 01-12「区間解析のguardとreturnの局所規則」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- 型の注記のないdiscardとreturnの子も読む、正常値の直積の近似。 -/
structure BaseApprox where
  integer : Interval
  boolean : Bool × Bool
  other : Bool
  mayFail : Bool
  warnings : List IntervalWarning
  widths : (kind : IntKind) → Interval kind := fun kind => top kind
  nonIntegerOther : Bool := true

/-- 正常値のない近似。 -/
def baseEmpty : BaseApprox := ⟨.bottom, (false, false), false, false, [], fun _ => .bottom, false⟩
/-- 未対応では型内の正常値を失わず、新警告を作らない。 -/
def baseUnknown : BaseApprox := ⟨top, (true, true), true, true, [], fun kind => top kind, true⟩
/-- 値の形に対応する正常範囲への所属。 -/
def BaseApprox.Contains (approx : BaseApprox) : ConcreteValue → Prop
  | .integer value => Mem value.toInt approx.integer
  | .integer8 value => approx.other = true ∧ Mem value.toInt (approx.widths .integer8)
  | .integer16 value => approx.other = true ∧ Mem value.toInt (approx.widths .integer16)
  | .integer32 value => approx.other = true ∧ Mem value.toInt (approx.widths .integer32)
  | .unsignedInteger16 value => approx.other = true ∧ Mem value.toInt (approx.widths .unsignedInteger16)
  | .unsignedInteger32 value => approx.other = true ∧ Mem value.toInt (approx.widths .unsignedInteger32)
  | .unsignedInteger64 value => approx.other = true ∧ Mem value.toInt (approx.widths .unsignedInteger64)
  | .boolean false => approx.boolean.1 = true
  | .boolean true => approx.boolean.2 = true
  | _ => approx.other = true ∧ approx.nonIntegerOther = true
/-- いずれかの型の正常値が存在しうるか。 -/
def BaseApprox.live (approx : BaseApprox) : Bool :=
  approx.integer != .bottom || approx.boolean.1 || approx.boolean.2 || approx.other
/-- 正常値だけを消し、訪問した子の警告と失敗可能性を残す。 -/
def BaseApprox.abrupt (approx : BaseApprox) : BaseApprox :=
  { baseEmpty with mayFail := approx.mayFail, warnings := approx.warnings }
/-- 整数だけの正常値。 -/
def baseInteger (range : Interval) (mayFail : Bool := false) : BaseApprox :=
  { baseEmpty with integer := range, mayFail := mayFail }
/-- Integer64 は既存の欄、六幅は種類付きの区間から読む。 -/
def BaseApprox.rangeKind (approx : BaseApprox) (kind : IntKind) : Interval kind :=
  match kind with
  | .integer64 => approx.integer
  | kind => approx.widths kind

/-- 種類を指定した正常区間。他の幅の正常値を作らない。 -/
def baseIntegerKind (kind : IntKind) (range : Interval kind)
    (mayFail : Bool := false) : BaseApprox :=
  match kind with
  | .integer64 => baseInteger range mayFail
  | kind => { baseEmpty with
      widths := fun requested => if same : kind = requested then same ▸ range else .bottom
      other := range != .bottom
      mayFail := mayFail }

/-- Surface の幅付きの Nat は有界な場合だけ整数値と認める。 -/
def baseWidthLiteral (kind : IntKind) (value : Int) : BaseApprox :=
  if kind.min ≤ value ∧ value ≤ kind.max then
    baseIntegerKind kind (normalize value value kind)
  else baseUnknown

@[simp] theorem baseWidthLiteral_warnings (kind value) :
    (baseWidthLiteral kind value).warnings = [] := by
  unfold baseWidthLiteral
  split <;> cases kind <;> rfl

/-- 正常に評価された幅付きの葉は、その型の一点区間に入る。 -/
theorem baseWidthLiteral_contains (kind : IntKind) (value : Int)
    (bounded : kind.min ≤ value ∧ value ≤ kind.max) :
    (baseWidthLiteral kind value).Contains (.ofInteger kind ⟨value, bounded⟩) := by
  have inside : Mem value (normalize (kind := kind) value value) :=
    (mem_normalize _ _ _ kind).mpr ⟨bounded.1, bounded.2, Int.le_refl _, Int.le_refl _⟩
  have nonempty : normalize (kind := kind) value value ≠ .bottom := by
    intro empty; rw [empty] at inside; exact inside
  cases kind <;> simp_all [baseWidthLiteral, baseIntegerKind, baseInteger, baseEmpty,
    BaseApprox.Contains, ConcreteValue.ofInteger, IntegerValue.toInt, Integer64Value.toInt]

/-- 種類付きの一点以外の区間も、正常な所属値を失わない。 -/
theorem baseIntegerKind_contains (kind : IntKind) (range : Interval kind)
    (value : IntegerValue kind) (inside : Mem value.toInt range) (mayFail : Bool) :
    (baseIntegerKind kind range mayFail).Contains (.ofInteger kind value) := by
  have nonempty : range ≠ .bottom := by intro empty; rw [empty] at inside; exact inside
  cases kind <;> simp_all [baseIntegerKind, baseInteger, baseEmpty,
    BaseApprox.Contains, ConcreteValue.ofInteger, IntegerValue.toInt, Integer64Value.toInt]

/-- 同じ種類の正常値の所属から、整数の区間だけを取り出す。 -/
theorem BaseApprox.contains_rangeKind {approx : BaseApprox} (kind : IntKind)
    (value : IntegerValue kind) (inside : approx.Contains (.ofInteger kind value)) :
    Mem value.toInt (approx.rangeKind kind) := by
  cases kind <;> simp_all [BaseApprox.Contains, BaseApprox.rangeKind, ConcreteValue.ofInteger,
    IntegerValue.toInt, Integer64Value.toInt]

/-- 真偽値だけの正常値。 -/
def baseBoolean (range : Bool × Bool) : BaseApprox := { baseEmpty with boolean := range }
/-- Unitの正常終了。 -/
def baseUnit : BaseApprox := { baseEmpty with other := true, nonIntegerOther := true }
/-- 枝からの正常値を合流する。 -/
def baseJoin (left right : BaseApprox) : BaseApprox :=
  ⟨join left.integer right.integer,
    (left.boolean.1 || right.boolean.1, left.boolean.2 || right.boolean.2),
    left.other || right.other, left.mayFail || right.mayFail, left.warnings ++ right.warnings,
    fun kind => join (left.widths kind) (right.widths kind), left.nonIntegerOther || right.nonIntegerOther⟩
/-- 左に正常値がなければ右の結果を使わない。 -/
def baseThen (left right : BaseApprox) : BaseApprox :=
  if left.live then
    { right with
      mayFail := left.mayFail || right.mayFail
      warnings := left.warnings ++ right.warnings }
  else left.abrupt
/-- 末尾の文は正常値だけをUnitに変える。 -/
def baseDiscard (value : BaseApprox) : BaseApprox := baseThen value baseUnit
/-- 整数の束縛は右辺の正常区間を新位置へコピーする。 -/
def baseBind (kind : BindKind) (env : AbstractEnv) (type : Ty) (value : BaseApprox) : AbstractEnv :=
  match IntKind.ofType type with
  | some width => bindRangeKind kind env width (value.rangeKind width)
  | none => bindRange kind env type value.integer
/-- 直接検査の Result だけを一度保存し、通常位置の型と整数区間を保つ。 -/
def baseBindSource (kind : BindKind) (env : AbstractEnv) (type : Ty)
    (value : BaseApprox) (input : EvalInput) : AbstractEnv :=
  { baseBind kind env type value with ranges := rangeSaveResult env env.ranges input }

namespace BudgetAnalysis.CallReach

@[simp] theorem tables_bind (kind env type value input) :
    rangeTables (baseBindSource kind env type value input) = rangeTables env := by
  simp only [baseBindSource, tables_ranges, baseBind]
  split <;> rfl

end BudgetAnalysis.CallReach

/-- 同じ局所成功値への直接射影だけを狭め、他の正常値は未知に保つ。 -/
def baseRangeCall (env : AbstractEnv) (input : EvalInput) : BaseApprox :=
  match rangeValueOrigin env env.ranges input with
  | some origin => baseInteger (normalize origin.minimum.toInt origin.maximum.toInt) true
  | none => baseUnknown

@[simp] theorem baseRangeCall_warnings (env input) : (baseRangeCall env input).warnings = [] := by
  unfold baseRangeCall
  split <;> rfl

/-- 整数の種類を保ち、七種に共通する局所演算だけを計算する。 -/
def baseOwnKind (key : OperationKey) (op : BinOp) (kind : IntKind)
    (left right : BaseApprox) : BaseApprox :=
  let l := left.rangeKind kind
  let r := right.rangeKind kind
  if op = .add then
    { baseIntegerKind kind (addNormal l r) (addMayOverflow l r) with
      warnings := if addAlwaysOverflows l r then [⟨key, .binary op kind.type, .overflow⟩] else [] }
  else if op = .sub then
    { baseIntegerKind kind (subNormal l r) (subMayOverflow l r) with
      warnings := if subAlwaysOverflows l r then [⟨key, .binary op kind.type, .overflow⟩] else [] }
  else if op = .mul then
    { baseIntegerKind kind (mulNormal l r) (mulMayOverflow l r) with
      warnings := if mulAlwaysOverflows l r then [⟨key, .binary op kind.type, .overflow⟩] else [] }
  else if IntegerDivisionOp op then
    { baseIntegerKind kind (divModNormal l r) true with
      warnings := if divModAlwaysZero op l r then [⟨key, .binary op kind.type, .zeroDivisor⟩] else [] }
  else if (Comparison.ofBinOp op).isSome then baseBoolean (true, true) else baseUnknown

/-- 符号付きの種類だけへ負号の端点計算を適用する。 -/
def baseNegOwnKind (key : OperationKey) (kind : IntKind) (signed : kind.min < 0)
    (child : BaseApprox) : BaseApprox :=
  { baseIntegerKind kind (negNormal signed (child.rangeKind kind))
      (negMayOverflow signed (child.rangeKind kind)) with
    warnings := if negAlwaysOverflows signed (child.rangeKind kind) then
      [⟨key, .neg kind.type, .overflow⟩] else [] }

/-- 正常な二引数を得た後の演算自身の近似。 -/
def baseOwn (key : OperationKey) (op : BinOp) (type : Ty)
    (left right : BaseApprox) : BaseApprox :=
  match type with
  | .base .integer =>
    if op = .add then
      { baseInteger (addNormal left.integer right.integer)
          (addMayOverflow left.integer right.integer) with
        warnings := if addAlwaysOverflows left.integer right.integer then
          [⟨key, .binary .add (.base .integer), .overflow⟩] else [] }
    else if op = .sub then
      { baseInteger (subNormal left.integer right.integer)
          (subMayOverflow left.integer right.integer) with
        warnings := if subAlwaysOverflows left.integer right.integer then
          [⟨key, .binary .sub (.base .integer), .overflow⟩] else [] }
    else if op = .mul then
      { baseInteger (mulNormal left.integer right.integer)
          (mulMayOverflow left.integer right.integer) with
        warnings := if mulAlwaysOverflows left.integer right.integer then
          [⟨key, .binary .mul (.base .integer), .overflow⟩] else [] }
    else if IntegerDivisionOp op then
      { baseInteger (divModNormal left.integer right.integer) true with
        warnings := (analyzeDivMod key op ⟨left.integer, left.mayFail⟩
          ⟨right.integer, right.mayFail⟩).warnings }
    else if (Comparison.ofBinOp op).isSome then baseBoolean (true, true) else baseUnknown
  | type => match IntKind.ofType type with
    | some kind => baseOwnKind key op kind left right
    | none => baseUnknown
/-- 正常な一引数を得た後の Integer64 の負号。 -/
def baseNegOwn (key : OperationKey) (child : BaseApprox) : BaseApprox :=
  { baseInteger (negNormal (by decide) child.integer)
      (negMayOverflow (by decide) child.integer) with
    warnings := if negAlwaysOverflows (by decide) child.integer then
      [⟨key, .neg (.base .integer), .overflow⟩] else [] }

/-- 注記された整数型に対応する負号自身の近似。 -/
def baseNegOwnTyped (key : OperationKey) (type : Ty) (child : BaseApprox) : BaseApprox :=
  match type with
  | .base .integer => baseNegOwn key child
  | type => match IntKind.ofType type with
    | some kind => if signed : kind.min < 0 then baseNegOwnKind key kind signed child else baseUnknown
    | none => baseUnknown

/-- 符号付きの負号は子の異常終了を先に保つ。他の型は未知に退く。 -/
def baseNeg (key : OperationKey) (type : Ty) (child : BaseApprox) : BaseApprox :=
  match type with
  | .base .integer => baseThen child (baseNegOwn key child)
  | type => match IntKind.ofType type with
    | some kind => if signed : kind.min < 0 then baseThen child (baseNegOwnKind key kind signed child) else baseUnknown
    | none => baseUnknown

/-- 整数の局所演算。子の正常値がなければ後続の結果を使わない。 -/
def baseBinary (key : OperationKey) (op : BinOp) (type : Ty)
    (left right : BaseApprox) : BaseApprox :=
  match type with
  | .base .integer =>
    if op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true then
      baseThen left (baseThen right (baseOwn key op type left right))
    else baseUnknown
  | type => match IntKind.ofType type with
    | some kind =>
      if op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true then
        baseThen left (baseThen right (baseOwnKind key op kind left right))
      else baseUnknown
    | none => baseUnknown
@[simp] theorem baseOwn_atKind (key op kind left right) (not64 : kind ≠ .integer64) :
    baseOwn key op kind.type left right = baseOwnKind key op kind left right := by
  cases kind <;> simp_all [baseOwn, IntKind.type, IntKind.ofType]

@[simp] theorem baseBinary_atKind (key op kind left right) (not64 : kind ≠ .integer64) :
    baseBinary key op kind.type left right =
      (if op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true then
        baseThen left (baseThen right (baseOwnKind key op kind left right)) else baseUnknown) := by
  cases kind <;> simp_all [baseBinary, IntKind.type, IntKind.ofType]

@[simp] theorem baseNeg_atKind (key kind signed child) (not64 : kind ≠ .integer64) :
    baseNeg key kind.type child = baseThen child (baseNegOwnKind key kind signed child) := by
  cases kind <;> simp_all [baseNeg, IntKind.type, IntKind.ofType, IntKind.min]

@[simp] theorem baseNegOwnTyped_atKind (key kind signed child) (not64 : kind ≠ .integer64) :
    baseNegOwnTyped key kind.type child = baseNegOwnKind key kind signed child := by
  cases kind <;> simp_all [baseNegOwnTyped, IntKind.type, IntKind.ofType, IntKind.min]

/-- 条件の正常な真偽と複合条件の環境で枝入口を決める。 -/
def baseBranch (env : AbstractEnv) (condition : Expr) (tested : BaseApprox)
    (truth : Bool) (run : AbstractEnv → BaseApprox) : BaseApprox :=
  match branchEnv env condition tested.boolean truth with
  | none => baseEmpty
  | some refined => run refined
/-- 条件自身の警告を先に残し、正常値は枝から得る。 -/
def baseMerge (tested yes no : BaseApprox) : BaseApprox :=
  let merged := baseJoin yes no
  { merged with
    mayFail := tested.mayFail || merged.mayFail
    warnings := tested.warnings ++ merged.warnings }

/-- 左辺が継続する真偽だけで右辺を読み、短絡した正常値と合流する。 -/
def baseShortCircuit (env : AbstractEnv) (left : Expr) (tested : BaseApprox)
    (continueTruth : Bool) (run : AbstractEnv → BaseApprox) : BaseApprox :=
  baseMerge tested
    (baseBranch env left tested continueTruth run)
    (baseBranch env left tested (!continueTruth) (fun _ => baseBoolean (continueTruth, !continueTruth)))

/-- 短絡した正常値自身には警告がなく、警告順は左辺・到達可能な右辺である。 -/
theorem baseShortCircuit_warnings (env left tested continueTruth run) :
    (baseShortCircuit env left tested continueTruth run).warnings =
      tested.warnings ++ (baseBranch env left tested continueTruth run).warnings := by
  simp only [baseShortCircuit, baseMerge, baseJoin, baseBranch]
  split <;> split <;> simp [baseBoolean, baseEmpty]

/-- 通常の局所整数は他種の正常値を含めず、未知の位置は従来の全値域に退く。 -/
def baseLocal (env : AbstractEnv) (index : Nat) : BaseApprox :=
  match lookup env index with
  | some (.integer range) => baseInteger range true
  | some (.integerKind kind range) => baseIntegerKind kind range true
  | _ => { baseUnknown with integer := integerAt env index }

/-- 位置の種類を区別しても、局所参照自身は警告を作らない。 -/
@[simp] theorem baseLocal_warnings (env index) : (baseLocal env index).warnings = [] := by
  unfold baseLocal
  split <;> try rfl
  rename_i kind range _
  cases kind <;> rfl

/-- 全ての正常値が整数である場合だけ、整数パターンの事実を利用する。 -/
def BaseApprox.onlyInteger (tested : BaseApprox) : Bool :=
  !(tested.boolean.1 || tested.boolean.2 || tested.other)

/-- 一種類の整数だけを含む近似を認定する。整数・Boolean 以外の値は nonIntegerOther で区別する。 -/
def BaseApprox.onlyWidth (tested : BaseApprox) (kind : IntKind) : Bool :=
  !(tested.boolean.1 || tested.boolean.2 || tested.nonIntegerOther) &&
  (if kind = .integer64 then true else tested.integer == .bottom) &&
  (if kind = .integer8 then true else tested.widths .integer8 == .bottom) &&
  (if kind = .integer16 then true else tested.widths .integer16 == .bottom) &&
  (if kind = .integer32 then true else tested.widths .integer32 == .bottom) &&
  (if kind = .unsignedInteger16 then true else tested.widths .unsignedInteger16 == .bottom) &&
  (if kind = .unsignedInteger32 then true else tested.widths .unsignedInteger32 == .bottom) &&
  (if kind = .unsignedInteger64 then true else tested.widths .unsignedInteger64 == .bottom)

/-- Integer64 の既存の認定を保ち、六幅は他の正常値を含まない場合だけ認定する。 -/
def BaseApprox.matchKind (tested : BaseApprox) : Option IntKind :=
  if tested.onlyInteger then some .integer64
  else if tested.onlyWidth .integer8 then some .integer8
  else if tested.onlyWidth .integer16 then some .integer16
  else if tested.onlyWidth .integer32 then some .integer32
  else if tested.onlyWidth .unsignedInteger16 then some .unsignedInteger16
  else if tested.onlyWidth .unsignedInteger32 then some .unsignedInteger32
  else if tested.onlyWidth .unsignedInteger64 then some .unsignedInteger64
  else none

@[simp] theorem matchKind_some_integer64_iff (tested : BaseApprox) :
    tested.matchKind = some .integer64 ↔ tested.onlyInteger = true := by
  simp only [BaseApprox.matchKind]
  split <;> simp_all
  repeat' split <;> simp_all

theorem matchKind_integer64 {tested : BaseApprox} (only : tested.onlyInteger = true) :
    tested.matchKind = some .integer64 := (matchKind_some_integer64_iff tested).mpr only

private theorem onlyWidth_contains {tested : BaseApprox} {actual selected : IntKind}
    {value : IntegerValue actual} (inside : tested.Contains (.ofInteger actual value))
    (known : tested.onlyWidth selected = true) : actual = selected := by
  have member := tested.contains_rangeKind actual value inside
  cases actual <;> cases selected <;>
    simp_all [BaseApprox.onlyWidth, BaseApprox.Contains, BaseApprox.rangeKind,
      ConcreteValue.ofInteger, Mem]

/-- 認定した幅と正常な具体整数の幅は一致する。 -/
theorem matchKind_contains {tested : BaseApprox} {actual selected : IntKind}
    {value : IntegerValue actual} (inside : tested.Contains (.ofInteger actual value))
    (known : tested.matchKind = some selected) : actual = selected := by
  unfold BaseApprox.matchKind at known
  split at known
  · cases known
    cases actual <;> simp_all [BaseApprox.onlyInteger, BaseApprox.Contains, ConcreteValue.ofInteger]
  · repeat' split at known
    all_goals first
      | cases known; exact onlyWidth_contains inside (by assumption)
      | contradiction

/-- 整数以外の正常値があれば、種類付きの腕入口を選ばない。 -/
theorem noninteger_matchKind_none {tested value}
    (inside : BaseApprox.Contains tested value)
    (noninteger : ∀ kind integer, value ≠ .ofInteger kind integer) : tested.matchKind = none := by
  cases value with
  | integer v => exact (noninteger .integer64 v rfl).elim
  | integer8 v => exact (noninteger .integer8 v rfl).elim
  | integer16 v => exact (noninteger .integer16 v rfl).elim
  | integer32 v => exact (noninteger .integer32 v rfl).elim
  | unsignedInteger16 v => exact (noninteger .unsignedInteger16 v rfl).elim
  | unsignedInteger32 v => exact (noninteger .unsignedInteger32 v rfl).elim
  | unsignedInteger64 v => exact (noninteger .unsignedInteger64 v rfl).elim
  | boolean b =>
    cases b <;> simp_all [BaseApprox.Contains, BaseApprox.matchKind,
      BaseApprox.onlyInteger, BaseApprox.onlyWidth]
  | _ =>
    simp only [BaseApprox.Contains] at inside
    simp [BaseApprox.matchKind, BaseApprox.onlyInteger, BaseApprox.onlyWidth, inside.1, inside.2]

/-- 非整数の可能性が残る照合は、腕内部の事実を推測せず全値域に退く。 -/
def baseMatch (tested arms : BaseApprox) : BaseApprox :=
  baseThen tested (if tested.onlyInteger then arms else baseUnknown)

/-- 認定した整数の種類の腕だけを解析する。未知なら正常値を推測しない。 -/
def baseMatchKind (tested : BaseApprox) (run : IntKind → BaseApprox) : BaseApprox :=
  baseThen tested (match tested.matchKind with
    | some kind => run kind
    | none => baseUnknown)

/-- 腕の束縛位置に照合対象の整数の種類を保つ。 -/
def baseKindArm (kind : IntKind) (env : AbstractEnv) (source : Expr) (normal : Interval kind)
    (alts : List Alternative) (run : AbstractEnv → BaseApprox) : BaseApprox :=
  match matchKindArmEnv env source kind normal alts with
  | none => baseEmpty
  | some inner => run inner

/-- 全選択肢を合流した一つの腕入口。各腕には同じ元環境を渡す。 -/
def baseArm (env : AbstractEnv) (source : Expr) (normal : Interval)
    (alts : List Alternative) (run : AbstractEnv → BaseApprox) : BaseApprox :=
  match matchArmEnv env source (.base .integer) normal alts with
  | none => baseEmpty
  | some inner => run inner

/-- 正常な引数の合成と、ソース順の各値。子Bottomの後の値は使わない。 -/
structure BaseValues where
  aggregate : BaseApprox
  values : List BaseApprox

/-- 親へ返す子の結果を、評価順を変えずに一度ずつ集める。 -/
def baseValuesWith (run : OperationKey → Expr → BaseApprox) (key : OperationKey) :
    List Expr → BaseValues
  | [] => ⟨baseUnit, []⟩
  | source :: rest =>
    let head := run key source
    if head.live then
      let tail := baseValuesWith run (advanceKey key (surfaceSize source)) rest
      ⟨baseThen head tail.aggregate, head :: tail.values⟩
    else ⟨head.abrupt, []⟩

/-- 正常域との不交差。Bottomと交差する区間には候補を作らない。 -/
def baseDomainDisjoint (lo hi : Int) : Interval → Bool
  | .bottom => false
  | .closed lower upper _ => decide (upper < lo ∨ hi < lower)

/-- シフト自身は不交差だけを拒否とし、域内の結果の値を特定しない。 -/
def baseFixedOutside (binding : StandardBinding) (positions : List Nat)
    (values : List BaseApprox) : Bool :=
  match binding.rule with
    | .fixedDomain argument lo hi _ =>
        match fieldAt argument positions values with
        | some value => baseDomainDisjoint lo hi value.integer
        | none => false
    | _ => false
/-- 固定域から外れる場合だけ、同じ標準 call の拒否候補を作る。 -/
def baseFixedOwn (binding : StandardBinding) (key : OperationKey) (positions : List Nat)
    (values : List BaseApprox) : BaseApprox :=
  if baseFixedOutside binding positions values then
    { baseEmpty with
      mayFail := true
      warnings := [⟨key, .standard binding, .outsideDomain⟩] }
  else baseUnknown

/-- Range は既存の経路を使い、固定域の API だけに各引数の結果を保持する。 -/
def fixedBinding (binding : StandardBinding) : Bool :=
  match binding.rule with | .fixedDomain .. => true | _ => false

mutual
/-- 式を一度ずつ読む。fuelは深さの打ち切りであり操作数の予算ではない。 -/
def analyzeBaseExpr : Nat → AbstractEnv → OperationKey → Expr → BaseApprox
  | 0, _, _, _ => baseUnknown
  | fuel + 1, env, key, source =>
    match source with
    | .literal (.integer value) => baseInteger (normalize value.toValue.toInt value.toValue.toInt)
    | .negInt value => baseInteger (normalize value.negValue.toInt value.negValue.toInt)
    | .literal (.integer8 value) => baseWidthLiteral .integer8 (value : Int)
    | .literal (.integer16 value) => baseWidthLiteral .integer16 (value : Int)
    | .literal (.integer32 value) => baseWidthLiteral .integer32 (value : Int)
    | .literal (.unsignedInteger16 value) => baseWidthLiteral .unsignedInteger16 (value : Int)
    | .literal (.unsignedInteger32 value) => baseWidthLiteral .unsignedInteger32 (value : Int)
    | .literal (.unsignedInteger64 value) => baseWidthLiteral .unsignedInteger64 (value : Int)
    | .negInteger8 value => baseWidthLiteral .integer8 (-(value : Int))
    | .negInteger16 value => baseWidthLiteral .integer16 (-(value : Int))
    | .negInteger32 value => baseWidthLiteral .integer32 (-(value : Int))
    | .literal (.boolean value) => baseBoolean (!value, value)
    | .unit => baseUnit
    | .local index => baseLocal env index
    | .paren child => analyzeBaseExpr fuel env (childKey key []) child
    | .constE _ child => analyzeBaseExpr fuel (clearLocals env) (childKey key []) child
    | .returnE _ child => (analyzeBaseExpr fuel env (childKey key []) child).abrupt
    | .neg type child => baseNeg key type (analyzeBaseExpr fuel env (childKey key []) child)
    | .binary op type left right => baseBinary key op type
        (analyzeBaseExpr fuel env (childKey key []) left)
        (analyzeBaseExpr fuel env (childKey key [left]) right)
    | .and left right =>
        let tested := analyzeBaseExpr fuel env (childKey key []) left
        baseShortCircuit env left tested true (fun refined =>
          analyzeBaseExpr fuel refined (childKey key [left]) right)
    | .or left right =>
        let tested := analyzeBaseExpr fuel env (childKey key []) left
        baseShortCircuit env left tested false (fun refined =>
          analyzeBaseExpr fuel refined (childKey key [left]) right)
    | .matchE _ source arms =>
        let tested := analyzeBaseExpr fuel env (childKey key []) source
        let input : EvalInput := ⟨source, .base .unit, childKey key []⟩
        match rangeMatchAt env input arms with
        | some _ => baseThen tested (analyzeBaseResultArms fuel env input (childKey key [source]) arms)
        | none => baseMatchKind tested (fun kind => analyzeBaseKindArms fuel kind env source
            (tested.rangeKind kind) (childKey key [source]) arms)
    | .not child =>
        let value := analyzeBaseExpr fuel env (childKey key []) child
        { baseBoolean (value.boolean.2, value.boolean.1) with
          mayFail := value.mayFail, warnings := value.warnings }
    | .block body => analyzeBaseBlock fuel env (childKey key []) body
    | .call callee labels positions arguments =>
      let input : EvalInput := ⟨.call callee labels positions arguments, .base .integer, key⟩
      match rangeCallAt env key input.source with
      | none => baseUnknown
      | some binding =>
        if fixedBinding binding then
          let values := baseValuesWith (analyzeBaseExpr fuel env) (childKey key [callee]) (exprsChildren arguments)
          baseThen values.aggregate (baseFixedOwn binding key positions values.values)
        else baseThen
          (analyzeBaseArguments fuel env (childKey key [callee]) (exprsChildren arguments))
          (baseRangeCall env input)
    | .ite condition yes no =>
        let tested := analyzeBaseExpr fuel env (childKey key []) condition
        baseMerge tested
          (baseBranch env condition tested true (fun refined =>
            analyzeBaseBlock fuel refined (childKey key [condition]) yes))
          (baseBranch env condition tested false (fun refined =>
            analyzeBaseBlock fuel refined (childKey key (condition :: blockChildren yes)) no))
    | .elseIf condition yes no =>
        let tested := analyzeBaseExpr fuel env (childKey key []) condition
        baseMerge tested
          (baseBranch env condition tested true (fun refined =>
            analyzeBaseBlock fuel refined (childKey key [condition]) yes))
          (baseBranch env condition tested false (fun refined =>
            analyzeBaseExpr fuel refined (childKey key (condition :: blockChildren yes)) no))
    | .ifOnly condition yes =>
        let tested := analyzeBaseExpr fuel env (childKey key []) condition
        baseMerge tested
          (baseBranch env condition tested true (fun refined =>
            analyzeBaseBlock fuel refined (childKey key [condition]) yes))
          (baseBranch env condition tested false (fun _ => baseUnit))
    | _ => baseUnknown
/-- Blockは番号を消費せず、通常・専用・パターン位置を区別する。 -/
def analyzeBaseBlock : Nat → AbstractEnv → OperationKey → Block → BaseApprox
  | 0, _, _, _ => baseUnknown
  | fuel + 1, env, key, body =>
    match body with
    | .empty => baseUnit
    | .builderBind kind rest => analyzeBaseBlock fuel (extend env (.builder kind)) key rest
    | .last source => analyzeBaseExpr fuel env key source
    | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source =>
        baseDiscard (analyzeBaseExpr fuel env key source)
    | .bind kind type source rest =>
        let head := analyzeBaseExpr fuel env key source
        baseThen head (analyzeBaseBlock fuel (baseBindSource kind env type head ⟨source, type, key⟩)
          (advanceKey key (surfaceSize source)) rest)
    | .discard source rest | .seq source rest =>
        baseThen (analyzeBaseExpr fuel env key source)
          (analyzeBaseBlock fuel env (advanceKey key (surfaceSize source)) rest)
    | .bindPat _ pattern type source rest =>
        baseThen (analyzeBaseExpr fuel env key source)
          (analyzeBaseBlock fuel (extendPattern env pattern type)
            (advanceKey key (surfaceSize source)) rest)
/-- 腕を一度ずつ解析する。前の不一致や guard の偽は次の腕へ渡さない。 -/
def analyzeBaseKindArms : (fuel : Nat) → (kind : IntKind) → AbstractEnv → Expr → Interval kind → OperationKey → Arms → BaseApprox
  | 0, _, _, _, _, _, _ => baseUnknown
  | fuel + 1, kind, env, source, normal, key, arms =>
    match arms with
    | .nil => baseEmpty
    | .cons alts guard body rest =>
      let arm := baseKindArm kind env source normal alts (fun inner =>
        match guard with
        | none => analyzeBaseBlock fuel inner key body
        | some condition =>
          let tested := analyzeBaseExpr fuel inner key condition
          baseMerge tested
            (baseBranch inner condition tested true (fun refined =>
              analyzeBaseBlock fuel refined (advanceKey key (surfaceSize condition)) body)) baseEmpty)
      baseJoin arm (analyzeBaseKindArms fuel kind env source normal
        (advanceKey key (guardSize guard + blockSize body)) rest)

/-- 認定済み呼び出しの引数はソース順に同じ親環境で解析する。 -/
def analyzeBaseArguments : Nat → AbstractEnv → OperationKey → List Expr → BaseApprox
  | 0, _, _, _ => baseUnknown
  | fuel + 1, env, key, sources =>
    match sources with
    | [] => baseUnit
    | source :: rest => baseThen (analyzeBaseExpr fuel env key source)
        (analyzeBaseArguments fuel env (advanceKey key (surfaceSize source)) rest)

/-- Result の全腕は同じ検査由来から入り、前の失敗・guard の偽を渡さない。 -/
def analyzeBaseResultArms : Nat → AbstractEnv → EvalInput → OperationKey → Arms → BaseApprox
  | 0, _, _, _, _ => baseUnknown
  | fuel + 1, env, input, key, arms =>
    match arms with
    | .nil => baseEmpty
    | .cons alts guard body rest =>
      let inner := baseResultArmEnv env input alts
      let first := match guard with
        | none => analyzeBaseBlock fuel inner key body
        | some condition =>
          let tested := analyzeBaseExpr fuel inner key condition
          baseMerge tested
            (baseBranch inner condition tested true (fun refined =>
              analyzeBaseBlock fuel refined (advanceKey key (surfaceSize condition)) body)) baseEmpty
      baseJoin first (analyzeBaseResultArms fuel env input
        (advanceKey key (guardSize guard + blockSize body)) rest)

end
/-- 既存の Integer64 の腕入口は同じ走査の特殊化である。 -/
abbrev analyzeBaseArms (fuel : Nat) (env : AbstractEnv) (source : Expr)
    (normal : Interval) (key : OperationKey) (arms : Arms) : BaseApprox :=
  analyzeBaseKindArms fuel .integer64 env source normal key arms

/-- Result の腕の駆動も照合元の型注記を参照しない。 -/
theorem analyzeBaseResultArms_type (fuel : Nat) (env : AbstractEnv) (input : EvalInput)
    (type : Ty) (key : OperationKey) (arms : Arms) :
    analyzeBaseResultArms fuel env { input with type := type } key arms =
      analyzeBaseResultArms fuel env input key arms := by
  cases fuel with
  | zero => rfl
  | succ fuel =>
    cases arms with
    | nil => rfl
    | cons alts guard body rest =>
      simp only [analyzeBaseResultArms, baseResultArmEnv_type,
        analyzeBaseResultArms_type fuel]

/-- 中心命題への入口。 -/
def analyzeBase (env : AbstractEnv) (input : EvalInput) (fuel : Nat) : AnalysisResult :=
  let result := analyzeBaseExpr fuel (resetRanges env) input.key input.source
  ⟨fun value => value.type = input.type ∧ result.Contains value, result.mayFail, result.warnings⟩




/-- 未知の近似は、型で制限する前の全ての具体値を含む。 -/
theorem unknown_contains (value : ConcreteValue) : baseUnknown.Contains value := by
  cases value <;> simp [BaseApprox.Contains, baseUnknown]
  all_goals first
    | exact (mem_top _ _).mpr (Integer64Value.toInt_bounds _)
    | exact (mem_top _ _).mpr (IntegerValue.toInt_bounds _)
    | rename_i value; cases value <;> trivial

/-- 正常値を含む近似は、正常値のない状態ではない。 -/
theorem contains_live {approx value} (inside : BaseApprox.Contains approx value) :
    approx.live = true := by
  cases value <;> simp_all [BaseApprox.Contains, BaseApprox.live]
  case integer value =>
    have nonempty : approx.integer ≠ .bottom := by intro h; rw [h] at inside; exact inside
    simp [nonempty]
  case boolean truth => cases truth <;> simp_all

/-- 先行に正常値があれば、後続の正常値を保持する。 -/
theorem then_contains {left right value}
    (live : left.live = true) (inside : BaseApprox.Contains right value) :
    BaseApprox.Contains (baseThen left right) value := by
  cases value <;> simp_all [baseThen, BaseApprox.Contains]

/-- いずれかの枝の正常値は合流後も含まれる。 -/
theorem join_contains {left right value}
    (inside : BaseApprox.Contains left value ∨ BaseApprox.Contains right value) :
    BaseApprox.Contains (baseJoin left right) value := by
  cases value <;> simp_all [BaseApprox.Contains, baseJoin, Bool.or_eq_true]
  all_goals first
    | exact mem_join inside
    | rcases inside with ⟨flag, member⟩ | ⟨flag, member⟩
      · exact ⟨Or.inl flag, mem_join (Or.inl member)⟩
      · exact ⟨Or.inr flag, mem_join (Or.inr member)⟩
    | rcases inside with ⟨a, b⟩ | ⟨a, b⟩
      · exact ⟨Or.inl a, Or.inl b⟩
      · exact ⟨Or.inr a, Or.inr b⟩
    | rename_i truth; cases truth <;> exact inside

/-- 条件の失敗可能性や警告の合成は、枝の正常値を消さない。 -/
theorem merge_contains {tested yes no value}
    (inside : BaseApprox.Contains yes value ∨ BaseApprox.Contains no value) :
    BaseApprox.Contains (baseMerge tested yes no) value := by
  have h := join_contains inside
  cases value <;> exact h

private theorem localIndex_sound {concrete input value trace index}
    (eval : EvalPartial concrete input (.normal (.integer value)) trace)
    (known : localIndex input.source = some index) :
    concrete.locals[index]? = some (some (.integer value)) := by
  generalize outcomeEq : EvalOutcome.normal (.integer value) = outcome at eval
  cases eval <;> simp_all [localIndex]
  case unknownNormal unsupported typed =>
    cases input with
    | mk source type key =>
      cases source <;> simp_all [localIndex, UnknownAt, Unsupported, Unmodeled, classify]
  case paren key source type child =>
    cases outcomeEq
    exact localIndex_sound child known
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

private theorem localValueIndex_sound {concrete input value trace index}
    (eval : EvalPartial concrete input (.normal value) trace)
    (known : localIndex input.source = some index) :
    concrete.locals[index]? = some (some value) := by
  generalize outcomeEq : EvalOutcome.normal value = outcome at eval
  cases eval <;> simp_all [localIndex]
  case unknownNormal unsupported typed =>
    cases input with
    | mk source type key =>
      cases source <;> simp_all [localIndex, UnknownAt, Unsupported, Unmodeled, classify]
  case paren key source type child =>
    cases outcomeEq
    exact localValueIndex_sound child known
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

/-- 認定した単一比較の正常評価から、局所値と実際の真偽を取り出す。 -/
theorem comparisonAt_sound {concrete input truth trace comparison}
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace)
    (known : comparisonAt input.source = some comparison) :
    ∃ value, concrete.locals[comparison.index]? = some (some (.integer value)) ∧
      (comparison.op.Holds value.toInt comparison.constant ↔ truth = true) := by
  generalize outcomeEq : EvalOutcome.normal (.boolean truth) = outcome at eval
  cases eval <;>
    try simp only [comparisonAt, Comparison.ofBinOp] at known
  all_goals
    try contradiction
  all_goals try (cases outcomeEq; contradiction)
  case unknownNormal unsupported typed =>
    cases input with
    | mk source type key =>
      cases source <;> simp_all [comparisonAt, UnknownAt, Unsupported, Unmodeled, classify]
      rename_i op operand left right
      cases operand <;> try simp_all [comparisonAt]
      rename_i base
      cases base <;> simp_all [comparisonAt]
  case paren key source type child =>
    cases outcomeEq
    exact comparisonAt_sound child known
  case divMod target _ _ =>
    rcases target with rfl | rfl <;> simp at known
  case compare key op left right a b lt rt el er =>
    have recognized : Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl
    have tr : truth = decide (op.Holds a.toInt b.toInt) := by
      simpa [checkedCompare, OperationResult.outcome] using outcomeEq
    change ((Comparison.ofBinOp op.binOp).bind _) = some comparison at known
    rw [recognized] at known
    dsimp only [Option.bind] at known
    cases li : localIndex left <;> cases rc : integerConstant right <;>
      simp only [li, rc] at known
    case some.some index constant =>
      cases Option.some.inj known
      refine ⟨a, localIndex_sound el li, ?_⟩
      change op.Holds a.toInt constant ↔ truth = true
      rw [← integerConstant_sound er rc, tr, decide_eq_true_eq]
    all_goals
      cases ri : localIndex right <;> cases lc : integerConstant left <;>
        simp only [ri, lc] at known <;> try contradiction
      cases Option.some.inj known
      refine ⟨b, localIndex_sound er ri, ?_⟩
      change op.reverse.Holds b.toInt _ ↔ truth = true
      rw [Comparison.reverse_holds, ← integerConstant_sound el lc, tr, decide_eq_true_eq]

  case widthBinary key kind op left right a b lt rt not64 el er =>
    cases kind <;> simp_all [comparisonAt, IntKind.type]

termination_by surfaceSize input.source
decreasing_by all_goals simp_all

private theorem localIndex_kind_sound {concrete input value trace index}
    (eval : EvalPartial concrete input (.normal value) trace)
    (known : localIndex input.source = some index) :
    concrete.locals[index]? = some (some value) := by
  generalize outcomeEq : EvalOutcome.normal value = outcome at eval
  cases eval <;> simp_all [localIndex]
  case unknownNormal unsupported typed =>
    cases input with
    | mk source type key =>
        cases source <;> simp_all [localIndex, UnknownAt, Unsupported, Unmodeled, classify]
  case paren key source type child =>
    cases outcomeEq
    exact localIndex_kind_sound child known
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

/-- 六幅の単一比較の正常評価から、同じ種類の局所値と実際の真偽を得る。 -/
theorem comparisonKindAt_sound {concrete input truth trace comparison}
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace)
    (known : comparisonKindAt input.source = some comparison) :
    ∃ value : IntegerValue comparison.kind,
      concrete.locals[comparison.index]? = some (some (.ofInteger comparison.kind value)) ∧
      (comparison.op.Holds value.toInt comparison.constant ↔ truth = true) := by
  generalize outcomeEq : EvalOutcome.normal (.boolean truth) = outcome at eval
  cases eval <;> try simp only [comparisonKindAt] at known
  all_goals try contradiction
  all_goals try (cases outcomeEq; contradiction)
  case unknownNormal unsupported typed =>
    cases input with
    | mk source type key =>
      cases source <;> simp_all [comparisonKindAt, UnknownAt, Unsupported, Unmodeled, classify]
      rename_i op operand left right
      cases operand <;> simp_all [comparisonKindAt, IntKind.ofType]
      rename_i base
      cases base <;> simp_all [comparisonKindAt, IntKind.ofType]
      all_goals cases op <;> simp_all [Comparison.ofBinOp]
  case paren key source type child =>
    cases outcomeEq
    exact comparisonKindAt_sound child known
  case widthBinary key kind operation left right a b lt rt not64 el er =>
    cases operation with
    | add | sub | mul | intDiv | mod =>
        simp_all [WidthBinary.op, comparisonKindAt, Comparison.ofBinOp]
    | compare op =>
        simp only [IntKind.ofType_type, WidthBinary.op, Comparison.ofBinOp_binOp] at known
        change (if kind = .integer64 then none else
          match localIndex left, integerKindConstant kind right with
          | some index, some constant => some ⟨kind, index, op, constant⟩
          | _, _ => do
              let index ← localIndex right
              let constant ← integerKindConstant kind left
              some ⟨kind, index, op.reverse, constant⟩) = some comparison at known
        rw [ite_eq_right not64] at known
        have tr : truth = decide (op.Holds a.toInt b.toInt) := by
          simpa [WidthBinary.apply, IntKind.checkedCompare, OperationResult.outcome] using outcomeEq
        cases li : localIndex left <;> cases rc : integerKindConstant kind right <;>
          simp only [li, rc] at known
        case some.some index constant =>
          cases Option.some.inj known
          refine ⟨a, localIndex_kind_sound el li, ?_⟩
          change op.Holds a.toInt constant ↔ truth = true
          rw [← integerKindConstant_sound er rc, tr, decide_eq_true_eq]
        all_goals
          cases ri : localIndex right <;> cases lc : integerKindConstant kind left <;>
            simp only [ri, lc] at known <;> try contradiction
          cases Option.some.inj known
          refine ⟨b, localIndex_kind_sound er ri, ?_⟩
          change op.reverse.Holds b.toInt _ ↔ truth = true
          rw [Comparison.reverse_holds, ← integerKindConstant_sound el lc, tr, decide_eq_true_eq]
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

private theorem atomic_condition_models {abstract concrete input truth trace}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace) :
    ∃ refined, atomicConditionEnv abstract input.source truth = some refined ∧
      Models refined concrete := by
  cases recognized : comparisonAt input.source with
  | none =>
      cases widthRecognized : comparisonKindAt input.source with
      | none => exact ⟨abstract,
          by simp [atomicConditionEnv, recognized, kindAtomicConditionEnv, widthRecognized], models⟩
      | some comparison =>
          obtain ⟨value, atIndex, holds⟩ := comparisonKindAt_sound eval widthRecognized
          have inside := refineKindRange_sound (integerKindAt_sound models atIndex) holds
          have nonempty : refineKindRange comparison.op
              (integerKindAt abstract comparison.kind comparison.index)
              comparison.constant truth ≠ .bottom := by
            intro empty; rw [empty] at inside; exact inside
          exact ⟨refineKindEnv abstract comparison truth,
            by simp [atomicConditionEnv, recognized, kindAtomicConditionEnv, widthRecognized, nonempty],
            models_refineKindEnv models atIndex holds⟩
  | some comparison =>
    obtain ⟨value, atIndex, holds⟩ := comparisonAt_sound eval recognized
    have inside := refineRange_sound (integerAt_sound models atIndex) holds
    have nonempty : refineRange comparison.op (integerAt abstract comparison.index)
        comparison.constant truth ≠ .bottom := by
      intro empty; rw [empty] at inside; exact inside
    exact ⟨refineEnv abstract comparison truth,
      by simp [atomicConditionEnv, recognized, nonempty], models_refineEnv models atIndex holds⟩

/-- 正常な論理式の実評価は、否定・短絡・凸包のどの段でも具体環境を失わない。 -/
theorem conditionEnv_sound {abstract concrete input truth trace}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace) :
    ∃ refined, conditionEnv abstract input.source truth = some refined ∧ Models refined concrete := by
  cases input with
  | mk source type key =>
    cases source <;> try exact atomic_condition_models models eval
    case literal value =>
      cases value <;> try exact atomic_condition_models models eval
      case boolean value =>
        cases eval <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify, conditionEnv]
    case paren child =>
      cases eval <;> try simp_all [UnknownAt, Unsupported, Unmodeled, classify]
      exact conditionEnv_sound models (by assumption)
    case not child =>
      cases eval <;> try simp_all [UnknownAt, Unsupported, Unmodeled, classify, EvalOutcome.Abrupt]
      rename_i value childEval
      simpa [conditionEnv] using conditionEnv_sound models childEval
    case and left right =>
      cases eval <;> try simp_all [UnknownAt, Unsupported, Unmodeled, classify, EvalOutcome.Abrupt]
      case andShort child =>
        exact joinConditionEnvs_models models (Or.inl (conditionEnv_sound models child))
      case andRight lt rt el er =>
        obtain ⟨inner, atInner, related⟩ := conditionEnv_sound models el
        have h := conditionEnv_sound related er
        cases truth with
        | true => simpa [conditionEnv, atInner] using h
        | false =>
          apply joinConditionEnvs_models models (Or.inr ?_)
          simpa [atInner] using h
    case or left right =>
      cases eval <;> try simp_all [UnknownAt, Unsupported, Unmodeled, classify, EvalOutcome.Abrupt]
      case orShort child =>
        exact joinConditionEnvs_models models (Or.inl (conditionEnv_sound models child))
      case orRight lt rt el er =>
        obtain ⟨inner, atInner, related⟩ := conditionEnv_sound models el
        have h := conditionEnv_sound related er
        cases truth with
        | false => simpa [conditionEnv, atInner] using h
        | true =>
          apply joinConditionEnvs_models models (Or.inr ?_)
          simpa [atInner] using h
termination_by surfaceSize input.source

/-- 具体評価で選ばれる真偽に、対応する絞った抽象環境が存在する。 -/
theorem branch_models {abstract concrete input truth trace tested}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace)
    (possible : BaseApprox.Contains tested (.boolean truth)) :
    ∃ refined, branchEnv abstract input.source tested.boolean truth = some refined ∧
      Models refined concrete := by
  have h : (if truth then tested.boolean.2 else tested.boolean.1) = true := by
    cases truth <;> exact possible
  simpa only [branchEnv, h, ↓reduceIte] using conditionEnv_sound models eval

private theorem unknown_base (fuel : Nat) {concrete input}
    (unknown : UnknownAt concrete input) (env : AbstractEnv) (models : Models env concrete) :
    analyzeBaseExpr fuel env input.key input.source = baseUnknown := by
  cases fuel with
  | zero => rfl
  | succ fuel =>
    cases input with
    | mk source type key =>
      cases source <;> simp_all [UnknownAt, Unsupported, Unmodeled, classify, analyzeBaseExpr, baseNeg, baseWidthLiteral, IntKind.ofType]
      case call callee labels positions arguments =>
        have unrecognized : rangeCallBinding concrete ⟨.call callee labels positions arguments, type, key⟩ = none := by
          simpa [UnknownAt, Unsupported, Unmodeled, classify] using unknown
        have absent : rangeCallAt env key (.call callee labels positions arguments) = none := by
          rw [range_call_at_agrees (input := ⟨.call callee labels positions arguments, type, key⟩) models]
          exact unrecognized
        simp only [absent]
      case literal value => cases value <;> simp_all <;> try omega
      case neg operand child =>
        cases operand <;> try rfl
        rename_i base
        cases base <;> simp_all [baseNeg, IntKind.ofType, IntKind.min, min64]
      all_goals try omega
      case binary op operand left right =>
        cases operand <;> simp_all [baseBinary, IntKind.ofType]
        rename_i base
        cases base <;> try rfl
        all_goals simp_all

/-- 束縛の正常値を追加した抽象環境と具体環境は対応する。 -/
theorem bind_models {abstract concrete type value approx} (kind : BindKind)
    (models : Models abstract concrete) (typed : value.type = type)
    (inside : BaseApprox.Contains approx value) :
    Models (baseBind kind abstract type approx)
      { concrete with locals := some value :: concrete.locals } := by
  cases found : IntKind.ofType type with
  | none =>
    have noninteger : type ≠ .base .integer := by intro same; simp [same, IntKind.ofType] at found
    simpa only [baseBind, found] using models_bindRange_typed kind models typed noninteger
  | some width =>
    have same : type = width.type := by
      cases type <;> try contradiction
      rename_i base
      cases base <;> cases width <;> simp_all [IntKind.ofType, IntKind.type]
    obtain ⟨integer, rfl, _⟩ := integerKind_value_in_top (typed.trans same)
    simpa only [baseBind, found] using models_bindRangeKind kind integer models
      (BaseApprox.contains_rangeKind width integer inside)

private theorem unknowns_models {abstract concrete} (models : Models abstract concrete)
    (values : List ConcreteValue) :
    Models { abstract with locals := List.replicate values.length (.unknown none) ++ abstract.locals }
      { concrete with locals := values.map some ++ concrete.locals } := by
  induction values with
  | nil => exact models
  | cons value values ih => exact ⟨.cons (by simp [SlotModels]) ih.1, ih.2⟩

/-- パターンが導入した値と、型から作った抽象の位置が対応する。 -/
theorem pattern_models {abstract concrete pattern type value values}
    (models : Models abstract concrete) (typed : value.type = type)
    (bindings : PatternLocals pattern value values) :
    Models (extendPattern abstract pattern type)
      { concrete with locals := values.map some ++ concrete.locals } := by
  cases pattern <;> simp only [PatternLocals] at bindings
  case var => subst values; exact models_extend models (topSlot_models typed)
  case wild => subst values; exact models
  all_goals simpa [extendPattern, patternSlots, ← bindings, Models] using unknowns_models models values

/-- 対応する環境からの局所参照は具体値を近似に含む。 -/
theorem baseLocal_contains {abstract concrete index value}
    (models : Models abstract concrete)
    (atIndex : concrete.locals[index]? = some (some value)) :
    (baseLocal abstract index).Contains value := by
  obtain ⟨slot, atSlot, related⟩ := models.1.get atIndex
  change lookup abstract index = some slot at atSlot
  simp only [baseLocal, atSlot]
  cases slot with
  | integer range =>
    cases value <;> try contradiction
    exact related
  | integerKind kind range =>
    obtain ⟨integer, rfl, inside⟩ := related
    exact baseIntegerKind_contains kind range integer inside true
  | _ =>
    cases value with
    | integer v => exact integerAt_sound models atIndex
    | boolean truth => cases truth <;> simp [baseUnknown, BaseApprox.Contains]
    | _ =>
      simp [BaseApprox.Contains, baseUnknown]
      all_goals exact (mem_top _ _).mpr (IntegerValue.toInt_bounds _)

/-- 整数以外の正常値を含む近似を、整数専用とは判定しない。 -/
theorem noninteger_not_onlyInteger {tested value}
    (inside : BaseApprox.Contains tested value) (noninteger : ∀ integer, value ≠ .integer integer) :
    tested.onlyInteger = false := by
  cases value <;> simp_all [BaseApprox.Contains, BaseApprox.onlyInteger]
  rename_i truth
  cases truth <;> simp_all

/-- 選択された整数の腕に対応する抽象環境が存在する。 -/
theorem match_selection_models {abstract concrete source normal alts value selected trace key}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete ⟨source, .base .integer, key⟩ (.normal (.integer value)) trace)
    (inside : Mem value.toInt normal) (selection : IntegerSelection alts value selected) :
    ∃ inner, matchArmEnv abstract source (.base .integer) normal alts = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  obtain ⟨before, alt, after, raw, bindings, same, _, matched, locals, chosen, count⟩ := selection
  apply models_matchIntegerArmEnv models inside (by rw [same]; simp) count matched
    (fun index known => localIndex_sound eval known) locals chosen

/-- 六幅の選択も、同じ元位置・slots・逆順の対応を保存する。 -/
theorem match_width_selection_models {abstract concrete source alts selected trace key} {kind : IntKind}
    {normal : Interval kind} {value : IntegerValue kind}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete ⟨source, kind.type, key⟩ (.normal (.ofInteger kind value)) trace)
    (inside : Mem value.toInt normal) (selection : WidthSelection alts kind value selected)
    (_not64 : kind ≠ .integer64) :
    ∃ inner, matchKindArmEnv abstract source kind normal alts = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  obtain ⟨before, alt, after, raw, bindings, same, _, matched, locals, chosen, count⟩ := selection
  apply models_matchKindArmEnv (source := source) models inside (by rw [same]; simp) count matched
    (fun index known => localValueIndex_sound eval known) locals chosen

/-- 選択した Integer64 の腕にも、外の成功値の由来を同じ位置で渡す。 -/
theorem match_selection_ranges {abstract concrete source normal alts value selected trace key inner}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete ⟨source, .base .integer, key⟩ (.normal (.integer value)) trace)
    (inside : Mem value.toInt normal) (selection : IntegerSelection alts value selected)
    (found : matchArmEnv abstract source (.base .integer) normal alts = some inner) :
    inner.ranges.Models { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  obtain ⟨before, alt, after, raw, bindings, same, _, matched, locals, chosen, count⟩ := selection
  obtain ⟨candidate, entry, _⟩ := models_matchAlternativeEnv models inside matched
    (fun index known => localIndex_sound eval known) locals chosen
  have ranged := ranges_matchAlternativeEnv related entry (selected.reverse.map some)
    (by simp only [List.length_map, List.length_reverse]; exact selectSlots_length chosen)
  obtain ⟨joined, joinedAt, modeled⟩ := ranges_matchAlternativesEnv (alternatives := alts)
    (template := matchArmTemplate abstract (.base .integer) (matchArmBinders alts))
    (by rw [same]; simp) entry ranged
  have sameInner := Option.some.inj (joinedAt.symm.trans found)
  subst joined; exact modeled

/-- 六幅の腕も同じ選択・合流の順で成功由来の対応を保存する。 -/
theorem match_width_selection_ranges {abstract concrete source alts selected trace key inner} {kind : IntKind}
    {normal : Interval kind} {value : IntegerValue kind}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete ⟨source, kind.type, key⟩ (.normal (.ofInteger kind value)) trace)
    (inside : Mem value.toInt normal) (selection : WidthSelection alts kind value selected)
    (not64 : kind ≠ .integer64)
    (found : matchKindArmEnv abstract source kind normal alts = some inner) :
    inner.ranges.Models { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  obtain ⟨before, alt, after, raw, bindings, same, _, matched, locals, chosen, count⟩ := selection
  have core : matchKindArmEnvCore abstract source kind normal alts = some inner := by
    cases kind <;> first | contradiction | exact found
  obtain ⟨candidate, entry, _⟩ := models_matchKindAlternativeEnv models inside matched
    (fun index known => localValueIndex_sound eval known) locals chosen
  have ranged := ranges_matchKindAlternativeEnv related entry (selected.reverse.map some)
    (by simp only [List.length_map, List.length_reverse]; exact selectSlots_length chosen)
  obtain ⟨joined, joinedAt, modeled⟩ := ranges_matchKindAlternativesEnv (alternatives := alts)
    (template := matchKindArmTemplate abstract kind (matchArmBinders alts))
    (by rw [same]; simp) entry ranged
  have sameInner := Option.some.inj (joinedAt.symm.trans core)
  subst joined; exact modeled

/-- 非構造のパターン束縛も、増えた位置には成功由来を仮定しない。 -/
theorem pattern_ranges {abstract concrete pattern type value values}
    (related : abstract.ranges.Models concrete) (bindings : PatternLocals pattern value values) :
    (extendPattern abstract pattern type).ranges.Models
      { concrete with locals := values.map some ++ concrete.locals } :=
  ranges_extendPattern related (values.map some) (by simpa using patternLocals_length bindings)

/-- 正常に得た整数の加算結果は、局所演算の近似に含まれる。 -/
theorem checkedAdd_contains {left right a b outcome}
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b))
    (normal : (checkedAdd a b).outcome = .normal outcome) :
    BaseApprox.Contains (baseBinary key .add (.base .integer) left right) outcome := by
  have hl := contains_live ha
  have hr := contains_live hb
  simp only [checkedAdd] at normal
  split at normal
  · cases normal
    change Mem _ (baseBinary key .add (.base .integer) left right).integer
    simp only [baseBinary, baseOwn, baseThen, hl, hr, true_or, ↓reduceIte]
    apply add_normal_sound ha hb
    change checkedAdd a b = _
    simp only [checkedAdd, ConcreteValue.ofInteger]
    split <;> simp_all
  · cases normal

theorem checkedSub_contains {left right a b outcome}
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b))
    (normal : (checkedSub a b).outcome = .normal outcome) :
    BaseApprox.Contains (baseBinary key .sub (.base .integer) left right) outcome := by
  have hl := contains_live ha
  have hr := contains_live hb
  simp only [checkedSub, IntKind.checkedSub, ConcreteValue.ofInteger] at normal
  split at normal
  · cases normal
    change Mem _ (baseBinary key .sub (.base .integer) left right).integer
    simp only [baseBinary, baseOwn, baseThen, hl, hr, true_or, ↓reduceIte]
    apply sub_normal_sound ha hb
    change checkedSub a b = _
    simp only [checkedSub, IntKind.checkedSub, ConcreteValue.ofInteger]
    split <;> simp_all
  · cases normal

theorem checkedMul_contains {left right a b outcome}
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b))
    (normal : (checkedMul a b).outcome = .normal outcome) :
    BaseApprox.Contains (baseBinary key .mul (.base .integer) left right) outcome := by
  have hl := contains_live ha
  have hr := contains_live hb
  simp only [checkedMul, IntKind.checkedMul, ConcreteValue.ofInteger] at normal
  split at normal
  · cases normal
    change Mem _ (baseBinary key .mul (.base .integer) left right).integer
    simp only [baseBinary, baseOwn, baseThen, hl, hr, true_or, ↓reduceIte]
    apply mul_normal_sound ha hb
    change checkedMul a b = _
    simp only [checkedMul, IntKind.checkedMul, ConcreteValue.ofInteger]
    split <;> simp_all
  · cases normal

/-- 正常な負号の結果は、子の区間の端点を交換した近似に含まれる。 -/
theorem checkedNeg_contains {child a outcome key}
    (ha : BaseApprox.Contains child (.integer a))
    (normal : (checkedNeg a).outcome = .normal outcome) :
    BaseApprox.Contains (baseNeg key (.base .integer) child) outcome := by
  have live := contains_live ha
  simp only [checkedNeg, IntKind.checkedNeg, ConcreteValue.ofInteger] at normal
  split at normal
  · cases normal
    change Mem _ (baseNeg key (.base .integer) child).integer
    simp only [baseNeg, baseThen, live, ↓reduceIte, baseNegOwn, baseInteger]
    apply neg_normal_sound (by decide) ha
    simp only [IntKind.checkedNeg, ConcreteValue.ofInteger]
    split <;> simp_all
  · cases normal

/-- 正常に得た整数の除算・剰余の結果は、局所演算の近似に含まれる。 -/
theorem checkedDiv_contains {left right a b outcome op key}
    (target : IntegerDivisionOp op)
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b))
    (normal : (checkedDivMod op a b).outcome = .normal outcome) :
    BaseApprox.Contains (baseBinary key op (.base .integer) left right) outcome := by
  have hl := contains_live ha
  have hr := contains_live hb
  have notAdd : op ≠ .add := by rcases target with rfl | rfl <;> decide
  have notSub : op ≠ .sub := by rcases target with rfl | rfl <;> decide
  have notMul : op ≠ .mul := by rcases target with rfl | rfl <;> decide
  have typed : outcome.type = .base .integer := by
    simp only [checkedDivMod, ite_eq_left target] at normal
    split at normal <;> try cases normal
    split at normal <;> try (cases normal; rfl)
    split at normal <;> cases normal <;> rfl
  obtain ⟨v, rfl, _⟩ := integer_value_in_top typed
  change Mem v.toInt (baseBinary key op (.base .integer) left right).integer
  simp only [baseBinary, baseOwn, notAdd, notSub, notMul, target, baseThen, hl, hr, ↓reduceIte]
  exact divMod_normal_sound ha hb


/-- 幅付き二項演算の正常値は、同じ種類の区間に所属する。 -/
theorem checkedWidthBinary_contains {key kind op left right a b outcome}
    (not64 : kind ≠ .integer64)
    (ha : left.Contains (.ofInteger kind a)) (hb : right.Contains (.ofInteger kind b))
    (normal : (WidthBinary.apply op kind a b).outcome = .normal outcome) :
    (baseBinary key op.op kind.type left right).Contains outcome := by
  have hl := contains_live ha
  have hr := contains_live hb
  have la := BaseApprox.contains_rangeKind kind a ha
  have rb := BaseApprox.contains_rangeKind kind b hb
  rw [baseBinary_atKind _ _ _ _ _ not64]
  cases op with
  | add =>
    simp only [WidthBinary.op, true_or, ↓reduceIte, baseThen, hl, hr, baseOwnKind]
    simp only [WidthBinary.apply, IntKind.checkedAdd] at normal
    split at normal
    · cases normal
      apply baseIntegerKind_contains
      apply add_normal_sound la rb
      simp only [IntKind.checkedAdd]
      split <;> simp_all
    · cases normal
  | sub =>
    simp only [WidthBinary.op, true_or, ↓reduceIte, baseThen, hl, hr, baseOwnKind]
    simp only [WidthBinary.apply, IntKind.checkedSub] at normal
    split at normal
    · cases normal
      apply baseIntegerKind_contains
      apply sub_normal_sound la rb
      simp only [IntKind.checkedSub]
      split <;> simp_all
    · cases normal
  | mul =>
    simp only [WidthBinary.op, true_or, ↓reduceIte, baseThen, hl, hr, baseOwnKind]
    simp only [WidthBinary.apply, IntKind.checkedMul] at normal
    split at normal
    · cases normal
      apply baseIntegerKind_contains
      apply mul_normal_sound la rb
      simp only [IntKind.checkedMul]
      split <;> simp_all
    · cases normal
  | intDiv =>
    have target : IntegerDivisionOp .intDiv := by simp [IntegerDivisionOp]
    simp only [WidthBinary.op, Bool.false_eq_true, false_or, target, or_true, ↓reduceIte,
      baseThen, hl, hr, baseOwnKind]
    have typed : outcome.type = kind.type := by
      simp only [WidthBinary.apply, IntKind.checkedDivMod, ite_eq_left target] at normal
      repeat' split at normal
      all_goals cases normal <;> simp [ConcreteValue.ofInteger_type]
    obtain ⟨v, rfl, _⟩ := integerKind_value_in_top typed
    apply baseIntegerKind_contains
    exact divMod_normal_sound la rb
  | mod =>
    have target : IntegerDivisionOp .mod := by simp [IntegerDivisionOp]
    simp only [WidthBinary.op, Bool.false_eq_true, false_or, target, or_true, ↓reduceIte,
      baseThen, hl, hr, baseOwnKind]
    have typed : outcome.type = kind.type := by
      simp only [WidthBinary.apply, IntKind.checkedDivMod, ite_eq_left target] at normal
      repeat' split at normal
      all_goals cases normal <;> simp [ConcreteValue.ofInteger_type]
    obtain ⟨v, rfl, _⟩ := integerKind_value_in_top typed
    apply baseIntegerKind_contains
    exact divMod_normal_sound la rb
  | compare op =>
    have recognized : Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl
    have notAdd : op.binOp ≠ .add := by cases op <;> decide
    have notSub : op.binOp ≠ .sub := by cases op <;> decide
    have notMul : op.binOp ≠ .mul := by cases op <;> decide
    have notDiv : ¬ IntegerDivisionOp op.binOp := by cases op <;> simp [Comparison.binOp, IntegerDivisionOp]
    simp only [WidthBinary.apply, IntKind.checkedCompare, OperationResult.outcome] at normal
    cases normal
    cases truth : decide (op.Holds a.toInt b.toInt) <;>
      simp [WidthBinary.op, recognized, notAdd, notSub, notMul, notDiv,
        baseThen, hl, hr, baseOwnKind, baseBoolean, baseEmpty, BaseApprox.Contains, truth]

/-- 幅付き負号の正常値は、端点を交換した同じ種類の区間に所属する。 -/
theorem checkedWidthNeg_contains {key kind child a outcome}
    (not64 : kind ≠ .integer64) (signed : kind.min < 0)
    (ha : child.Contains (.ofInteger kind a))
    (normal : (kind.checkedNeg signed a).outcome = .normal outcome) :
    (baseNeg key kind.type child).Contains outcome := by
  have live := contains_live ha
  have inside := BaseApprox.contains_rangeKind kind a ha
  rw [baseNeg_atKind _ _ signed _ not64]
  simp only [baseThen, live, ↓reduceIte, baseNegOwnKind]
  simp only [IntKind.checkedNeg] at normal
  split at normal
  · cases normal
    apply baseIntegerKind_contains
    apply neg_normal_sound signed inside
    simp only [IntKind.checkedNeg]
    split <;> simp_all
  · cases normal

/-- 正常引数の後の二項演算自身にも、同じ正常値の保証を使える。 -/
theorem checkedWidthBinaryOwn_contains {key kind op left right a b outcome}
    (not64 : kind ≠ .integer64)
    (ha : left.Contains (.ofInteger kind a)) (hb : right.Contains (.ofInteger kind b))
    (normal : (WidthBinary.apply op kind a b).outcome = .normal outcome) :
    (baseOwn key op.op kind.type left right).Contains outcome := by
  have inside := checkedWidthBinary_contains (key := key) not64 ha hb normal
  rw [baseOwn_atKind _ _ _ _ _ not64]
  cases outcome <;> simpa only [baseBinary_atKind _ _ _ _ _ not64, ite_eq_left op.supported,
    baseThen, contains_live ha, contains_live hb, ↓reduceIte, BaseApprox.Contains] using inside

/-- 正常引数の後の負号自身にも、同じ正常値の保証を使える。 -/
theorem checkedWidthNegOwn_contains {key kind child a outcome}
    (not64 : kind ≠ .integer64) (signed : kind.min < 0)
    (ha : child.Contains (.ofInteger kind a))
    (normal : (kind.checkedNeg signed a).outcome = .normal outcome) :
    (baseNegOwnTyped key kind.type child).Contains outcome := by
  have inside := checkedWidthNeg_contains (key := key) not64 signed ha normal
  rw [baseNegOwnTyped_atKind _ _ signed _ not64]
  cases outcome <;> simpa only [baseNeg_atKind _ _ signed _ not64, baseThen,
    contains_live ha, ↓reduceIte, BaseApprox.Contains] using inside

/-- 正常終了した場合だけ、値が近似に含まれることを要求する。 -/
def NormalCovered (approx : BaseApprox) (outcome : EvalOutcome) : Prop :=
  ∀ value, outcome = .normal value → approx.Contains value

/-- ソース順の各引数について、正常な具体値と区間を対応させる。 -/
inductive ValuesModels : List BaseApprox → List ConcreteValue → Prop where
  | nil : ValuesModels [] []
  | cons {approx value approxs values} : approx.Contains value →
      ValuesModels approxs values → ValuesModels (approx :: approxs) (value :: values)

/-- 正常に揃ったソース順の引数列だけに対応する。 -/
def BaseValues.Models (approx : BaseValues) (values : List ConcreteValue) : Prop :=
  approx.aggregate.Contains .unit ∧ ValuesModels approx.values values

/-- 子に正常値がある場合、同じ順序で集めた全ての値の対応を保つ。 -/
theorem baseValuesWith_models {run : OperationKey → Expr → BaseApprox}
    {concrete key sources types values trace}
    (evaluated : EvalTypedArguments concrete key sources types (.normal values) trace)
    (children : ∀ input value trace, EvalPartial concrete input (.normal value) trace →
      (run input.key input.source).Contains value) :
    (baseValuesWith run key sources).Models values := by
  match evaluated with
  | .nil .. => exact ⟨⟨rfl, rfl⟩, .nil⟩
  | .cons _ key source rest _ _ value values _ _ head tail =>
    have headModels := children _ _ _ head
    have tailModels := baseValuesWith_models tail children
    simp only [baseValuesWith, contains_live headModels, ↓reduceIte, BaseValues.Models]
    exact ⟨then_contains (contains_live headModels) tailModels.1, .cons headModels tailModels.2⟩

/-- 二列の対応は、同じ契約位置を選んだ後も保たれる。 -/
theorem baseValues_field {approxs values}
    (models : ValuesModels approxs values)
    {position positions approx} (selected : fieldAt position positions approxs = some approx) :
    ∃ value, fieldAt position positions values = some value ∧ approx.Contains value := by
  induction models generalizing positions with
  | nil => cases positions <;> simp [fieldAt] at selected
  | cons head tail ih =>
    cases positions with
    | nil => simp [fieldAt] at selected
    | cons p ps =>
      by_cases same : position = p
      · simp only [fieldAt, same, ↓reduceIte, Option.some.injEq] at selected
        subst approx; exact ⟨_, by simp [fieldAt, same], head⟩
      · simp only [fieldAt, same, ↓reduceIte] at selected ⊢
        exact ih selected

/-- 契約位置の整数は、ソース順の同じ引数の区間に属する。 -/
theorem baseValues_integer {approxs values positions arguments position approx integer}
    (models : ValuesModels approxs values)
    (ordered : orderArguments positions values = some arguments)
    (selected : fieldAt position positions approxs = some approx)
    (atInteger : arguments[position]? = some (.integer integer)) :
    Mem integer.toInt approx.integer := by
  obtain ⟨value, field, modeled⟩ := baseValues_field models selected
  have bound : position < positions.length := by
    rw [← order_arguments_length ordered]
    exact (List.getElem?_eq_some_iff.mp atInteger).1
  have same : value = .integer integer := Option.some.inj
    (field.symm.trans ((order_arguments_field ordered bound).trans atInteger))
  subst value; exact modeled

/-- 不交差な正常区間の各値は、固定域の外にある。 -/
theorem baseDomainDisjoint_outside {lo hi normal value}
    (outside : baseDomainDisjoint lo hi normal = true) (inside : Mem value normal) :
    ¬ (lo ≤ value ∧ value ≤ hi) := by
  cases normal with
  | bottom => contradiction
  | closed lower upper valid =>
    simp only [baseDomainDisjoint, decide_eq_true_eq] at outside
    simp only [Mem] at inside
    omega

/-- 直接引数の不交差から、実際に揃った同じ整数の域外を得る。 -/
theorem baseDirectOutside {lo hi position positions approxs values arguments integer}
    (outside : (match fieldAt position positions approxs with
      | some value => baseDomainDisjoint lo hi value.integer | none => false) = true)
    (models : ValuesModels approxs values)
    (ordered : orderArguments positions values = some arguments)
    (atInteger : arguments[position]? = some (.integer integer)) :
    ¬ (lo ≤ integer.toInt ∧ integer.toInt ≤ hi) := by
  cases selected : fieldAt position positions approxs with
  | none => simp [selected] at outside
  | some approx =>
    simp only [selected] at outside
    exact baseDomainDisjoint_outside outside (baseValues_integer models ordered selected atInteger)

/-- 正常引数の対応があれば、固定域の全域外は評価規則そのものから拒否する。 -/
theorem baseFixedOutside_reject {binding : StandardBinding} {positions approxs values arguments key result}
    (outside : baseFixedOutside binding positions approxs = true)
    (models : ValuesModels approxs values)
    (ordered : orderArguments positions values = some arguments)
    (evaluated : EvalStandard binding.rule key arguments result) :
    result = .rejected .outsideDomain := by
  rcases binding with ⟨declaration, rule, types⟩
  cases evaluated with
  | rangeCheck | rangeValue | rangeValueUnknown | rangeValueUnknownFailed =>
      simp [baseFixedOutside] at outside
  | domainNormal position lo hi result key args integer output atInteger inside typed =>
      exact False.elim ((baseDirectOutside (by simpa only [baseFixedOutside] using outside)
        models ordered atInteger) inside)
  | domainOtherFailure position lo hi result key args integer atInteger inside =>
      exact False.elim ((baseDirectOutside (by simpa only [baseFixedOutside] using outside)
        models ordered atInteger) inside)
  | domainRejected => rfl
/-- 定義域の警告の候補は、同じキーと標準束縛を持つ拒否一件だけである。 -/
theorem baseFixedOwn_warning {binding key positions values warning}
    (member : warning ∈ (baseFixedOwn binding key positions values).warnings) :
    warning = ⟨key, .standard binding, .outsideDomain⟩ ∧
      baseFixedOutside binding positions values = true := by
  unfold baseFixedOwn at member
  split at member
  · rename_i outside
    exact ⟨by simpa only [List.mem_singleton] using member, outside⟩
  · contradiction

/-- API が正常終了したときの値は失わない。全域外の枝には正常評価がない。 -/
theorem baseFixedOwn_normal {binding : StandardBinding} {positions approxs values arguments key result}
    (models : ValuesModels approxs values)
    (ordered : orderArguments positions values = some arguments)
    (evaluated : EvalStandard binding.rule key arguments result) :
    NormalCovered (baseFixedOwn binding key positions approxs) (binding.rule.finish result) := by
  intro value normal
  unfold baseFixedOwn
  split
  · rename_i outside
    have rejected := baseFixedOutside_reject outside models ordered evaluated
    rw [rejected] at normal
    have failed : binding.rule.finish (.rejected .outsideDomain) = .failed .outsideDomain := by
      cases binding.rule <;> rfl
    rw [failed] at normal
    cases normal
  · exact unknown_contains value

/-- 同定済みの同じ成功値への射影は、任意の正常評価値を保存する。 -/
theorem baseRangeCall_normal {abstract concrete input outcome trace}
    (models : Models abstract concrete) (related : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input outcome trace) :
    NormalCovered (baseRangeCall abstract { input with type := .base .integer }) outcome := by
  intro value normal
  rw [normal] at eval
  cases known : rangeValueOrigin abstract abstract.ranges { input with type := .base .integer } with
  | none => simpa only [baseRangeCall, known] using unknown_contains value
  | some origin =>
    obtain ⟨index, call, _⟩ := range_value_origin_source known
    have typeEq := range_value_normal_input_type models call eval
    have sameInput : { input with type := .base .integer } = input := by
      cases input with
      | mk source type key => dsimp only at typeEq; subst type; rfl
    rw [sameInput] at known call
    obtain ⟨number, valueEq, inside⟩ := range_value_surface_mem models related call eval
    subst value
    simpa only [baseRangeCall, sameInput, known, BaseApprox.Contains,
      baseInteger, rangeValueInterval] using inside

set_option maxHeartbeats 800000 in
mutual
/-- 任意の深さ・対応する環境で、土台の正常評価値を失わない。 -/
private theorem base_normal_sound (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input outcome trace) :
    NormalCovered (analyzeBaseExpr fuel abstract input.key input.source) outcome := by
  cases fuel with
  | zero => exact fun value _ => unknown_contains value
  | succ fuel =>
    match eval with
    | .standardCall env key callee labels positions sources binding values arguments result trace recognized children ordered evaluated =>
      intro value normal
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding := by
        rw [range_call_at_agrees (input := ⟨.call callee labels positions sources, binding.rule.resultType, key⟩) models]
        exact recognized
      simp only [analyzeBaseExpr, atCall]
      split
      · have all := baseValuesWith_models children (run := analyzeBaseExpr fuel abstract)
          (fun input value trace child => base_normal_sound fuel models rangeRelated child value rfl)
        exact then_contains (contains_live all.1) (baseFixedOwn_normal all.2 ordered evaluated value normal)
      · apply then_contains (contains_live (base_typed_arguments_normal_sound fuel models rangeRelated children _ rfl))
        exact baseRangeCall_normal models rangeRelated
          (.standardCall env key callee labels positions sources binding values arguments result trace recognized children ordered evaluated) value normal
    | .standardCallAbrupt _ _ _ _ _ _ _ outcome _ _ _ abrupt =>
      intro value normal
      rw [normal] at abrupt
      contradiction
    | .fixedCallFailed .. => intro value normal; cases normal
    | .fixedCallAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      intro value normal; rw [normal] at abrupt; contradiction
    | .unknownNormal _ _ _ unsupported _ =>
      rw [unknown_base (fuel + 1) unsupported abstract models]
      exact fun value _ => unknown_contains value
    | .unknownFailed .. => intro value h; cases h
    | .integer .. | .negInt .. =>
      intro value h; cases h
      apply (mem_normalize _ _ _).mpr
      exact ⟨(Integer64Value.toInt_bounds _).1, (Integer64Value.toInt_bounds _).2,
        Int.le_refl _, Int.le_refl _⟩
    | .integer8 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .integer16 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .integer32 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .unsignedInteger16 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .unsignedInteger32 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .unsignedInteger64 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .negInteger8 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .negInteger16 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .negInteger32 _ _ value bounded =>
      intro output same; cases same
      exact baseWidthLiteral_contains _ _ bounded
    | .boolean _ _ truth => intro value h; cases h; cases truth <;> rfl
    | .unit .. => intro value h; cases h; exact ⟨rfl, rfl⟩
    | .local _ _ index v atIndex =>
      intro value h; cases h
      exact baseLocal_contains models atIndex
    | .paren _ _ _ _ _ _ child => exact base_normal_sound fuel models rangeRelated child
    | .constE _ _ _ _ _ _ child =>
      exact base_normal_sound fuel (abstract := clearLocals abstract)
        (concrete := { concrete with locals := [] }) (models_clearLocals models) (ranges_clearLocals abstract concrete) child
    | .returnE _ _ _ _ _ result _ _ =>
      intro value h; cases result <;> cases h
    | .widthBinary _ _ kind op _ _ a b _ _ not64 el er =>
      intro value normal
      exact checkedWidthBinary_contains not64 ((base_normal_sound fuel models rangeRelated el) _ rfl)
        ((base_normal_sound fuel models rangeRelated er) _ rfl) normal
    | .widthNeg _ _ kind _ a _ not64 signed child =>
      intro value normal
      exact checkedWidthNeg_contains not64 signed ((base_normal_sound fuel models rangeRelated child) _ rfl) normal
    | .widthBinaryLeftAbrupt _ _ _ _ _ _ result _ _ _ abrupt
    | .widthBinaryRightAbrupt _ _ _ _ _ _ _ result _ _ _ _ _ abrupt
    | .widthNegAbrupt _ _ _ _ result _ _ _ _ abrupt =>
      intro value same; cases same; exact False.elim abrupt
    | .add _ _ _ _ _ _ _ _ el er =>
      intro value h
      exact checkedAdd_contains ((base_normal_sound fuel models rangeRelated el) _ rfl)
        ((base_normal_sound fuel models rangeRelated er) _ rfl) h
    | .sub _ _ _ _ _ _ _ _ el er =>
      intro value h
      exact checkedSub_contains ((base_normal_sound fuel models rangeRelated el) _ rfl)
        ((base_normal_sound fuel models rangeRelated er) _ rfl) h
    | .mul _ _ _ _ _ _ _ _ el er =>
      intro value h
      exact checkedMul_contains ((base_normal_sound fuel models rangeRelated el) _ rfl)
        ((base_normal_sound fuel models rangeRelated er) _ rfl) h
    | .neg _ _ _ _ _ child =>
      intro value h
      exact checkedNeg_contains ((base_normal_sound fuel models rangeRelated child) _ rfl) h
    | .divMod _ _ _ _ _ _ _ _ _ target el er =>
      intro value h
      exact checkedDiv_contains target ((base_normal_sound fuel models rangeRelated el) _ rfl)
        ((base_normal_sound fuel models rangeRelated er) _ rfl) h
    | .compare _ _ op _ _ a b _ _ el er =>
      intro value h; cases h
      have hl := contains_live ((base_normal_sound fuel models rangeRelated el) _ rfl)
      have hr := contains_live ((base_normal_sound fuel models rangeRelated er) _ rfl)
      have notAdd : op.binOp ≠ .add := by cases op <;> decide
      have notSub : op.binOp ≠ .sub := by cases op <;> decide
      have notMul : op.binOp ≠ .mul := by cases op <;> decide
      have notDiv : ¬ IntegerDivisionOp op.binOp := by cases op <;> simp [IntegerDivisionOp, Comparison.binOp]
      have recognized : Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl
      simp [analyzeBaseExpr, baseBinary, baseOwn, notAdd, notSub, notMul, notDiv, recognized, baseThen, hl, hr,
        BaseApprox.Contains, baseBoolean]
      cases decide (op.Holds a.toInt b.toInt) <;> trivial
    | .not _ _ _ truth _ child =>
      intro value h; cases h
      have h := (base_normal_sound fuel models rangeRelated child) _ rfl
      cases truth <;> exact h
    | .andShort _ _ _ _ _ condition | .orShort _ _ _ _ _ condition =>
      intro value h; cases h
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      apply merge_contains (Or.inr ?_)
      simp only [baseBranch, Bool.not_true, Bool.not_false, atEnv]
      rfl
    | .andRight _ _ _ _ _ _ _ condition branch
    | .orRight _ _ _ _ _ _ _ condition branch =>
      intro value h
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      apply merge_contains (Or.inl ?_)
      simp only [baseBranch, atEnv]
      exact (base_normal_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch) value h
    | .matchInteger _ key source arms _ integer _ _ _ child selected =>
      intro value h
      have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
      have rangeAbsent := range_match_at_integer_none (kind := .integer64) models rangeRelated child (arms := arms)
      simp only [analyzeBaseExpr, rangeAbsent]
      change (baseMatchKind _ _).Contains value
      unfold baseMatchKind
      apply then_contains (contains_live inside)
      cases known : (analyzeBaseExpr fuel abstract (childKey key []) source).matchKind with
      | none => exact unknown_contains value
      | some kind =>
        have same := matchKind_contains (actual := .integer64) inside known
        subst kind
        exact (base_arms_normal_sound fuel models rangeRelated child inside selected) value h
    | .matchWidth _ key kind source arms _ integer _ _ _ not64 child selected =>
      intro value h
      have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
      have rangeAbsent := range_match_at_integer_none models rangeRelated child (arms := arms)
      simp only [analyzeBaseExpr, rangeAbsent]
      change (baseMatchKind _ _).Contains value
      unfold baseMatchKind
      apply then_contains (contains_live inside)
      cases known : (analyzeBaseExpr fuel abstract (childKey key []) source).matchKind with
      | none => exact unknown_contains value
      | some chosen =>
        have same := matchKind_contains inside known
        subst chosen
        exact (base_widthArms_normal_sound fuel kind not64 models rangeRelated child
          (BaseApprox.contains_rangeKind kind integer inside) selected) value h
    | .matchResult _ key source arms type sourceType result names tag payload outcome st armTrace matched view child selected =>
      intro value normal
      have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
      cases recognized : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms with
      | none =>
        have fallback := noninteger_matchKind_none inside (range_result_view_noninteger view)
        simp only [analyzeBaseExpr, recognized, baseMatchKind, fallback]
        exact then_contains (contains_live inside) (unknown_contains value)
      | some origin =>
        have recognizedActual : rangeMatchAt abstract ⟨source, sourceType, childKey key []⟩ arms = some origin := by
          exact (range_match_at_type abstract ⟨source, sourceType, childKey key []⟩ (.base .unit) arms).symm.trans recognized
        have actual := range_match_at_evaluated models rangeRelated recognizedActual child
        have namesEq : names = origin.names := Option.some.inj (matched.symm.trans actual)
        subst names
        simp only [analyzeBaseExpr, recognized]
        apply then_contains (contains_live inside)
        have resultCovered := base_resultArms_normal_sound fuel models rangeRelated recognizedActual child actual view selected
        rw [← analyzeBaseResultArms_type fuel abstract ⟨source, sourceType, childKey key []⟩
          (.base .unit) (childKey key [source]) arms] at resultCovered
        exact resultCovered value normal
    | .matchOtherNormal _ key source arms type sourceType result _ _ child noninteger _ unmodeled =>
      intro value h; cases h
      have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
      have fallback := noninteger_matchKind_none inside noninteger
      have rangeAbsent : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms = none := by
        cases recognized : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms with
        | none => rfl
        | some origin =>
          have recognizedActual : rangeMatchAt abstract ⟨source, sourceType, childKey key []⟩ arms = some origin := by
            exact (range_match_at_type abstract ⟨source, sourceType, childKey key []⟩ (.base .unit) arms).symm.trans recognized
          have actual := range_match_at_evaluated models rangeRelated recognizedActual child
          simp only [unmodeled] at actual
          contradiction
      simp only [analyzeBaseExpr, rangeAbsent]
      change (baseMatchKind _ _).Contains _
      unfold baseMatchKind
      apply then_contains (contains_live inside)
      simpa only [fallback] using unknown_contains _
    | .matchOtherFailed .. => intro value h; cases h
    | .matchAbrupt _ _ _ _ _ _ _ _ _ abrupt =>
      intro value h; rw [h] at abrupt; contradiction
    | .block _ _ _ _ _ _ child => exact base_block_normal_sound fuel models rangeRelated child
    | .iteTrue _ _ _ _ _ _ _ _ _ condition branch
    | .elseIfTrue _ _ _ _ _ _ _ _ _ condition branch
    | .ifOnlyTrue _ _ _ _ _ _ _ condition branch =>
      intro value h
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      apply merge_contains (Or.inl ?_)
      simp only [baseBranch, atEnv]
      exact (base_block_normal_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch) value h
    | .iteFalse _ _ _ _ _ _ _ _ _ condition branch =>
      intro value h
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      apply merge_contains (Or.inr ?_)
      simp only [baseBranch, atEnv]
      exact (base_block_normal_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch) value h
    | .elseIfFalse _ _ _ _ _ _ _ _ _ condition branch =>
      intro value h
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      apply merge_contains (Or.inr ?_)
      simp only [baseBranch, atEnv]
      exact (base_normal_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch) value h
    | .ifOnlyFalse _ _ _ _ _ condition =>
      intro value h; cases h
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      apply merge_contains (Or.inr ?_)
      simp only [baseBranch, atEnv]
      exact ⟨rfl, rfl⟩
    | .addLeftAbrupt _ _ _ _ _ _ _ abrupt | .subLeftAbrupt _ _ _ _ _ _ _ abrupt | .mulLeftAbrupt _ _ _ _ _ _ _ abrupt
    | .addRightAbrupt _ _ _ _ _ _ _ _ _ _ abrupt | .subRightAbrupt _ _ _ _ _ _ _ _ _ _ abrupt | .mulRightAbrupt _ _ _ _ _ _ _ _ _ _ abrupt
    | .divModLeftAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .divModRightAbrupt _ _ _ _ _ _ _ _ _ _ _ _ abrupt
    | .compareLeftAbrupt _ _ _ _ _ _ _ _ abrupt
    | .compareRightAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt
    | .andAbrupt _ _ _ _ _ _ _ abrupt
    | .orAbrupt _ _ _ _ _ _ _ abrupt
    | .negAbrupt _ _ _ _ _ _ abrupt
    | .notAbrupt _ _ _ _ _ _ abrupt
    | .iteAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .elseIfAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .ifOnlyAbrupt _ _ _ _ _ _ _ abrupt =>
      intro value h; rw [h] at abrupt; contradiction

/-- Blockは右辺の正常値を保存した環境で、後続の正常値を失わない。 -/
private theorem base_block_normal_sound (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalBlock concrete key body type outcome trace) :
    NormalCovered (analyzeBaseBlock fuel abstract key body) outcome := by
  cases fuel with
  | zero => exact fun value _ => unknown_contains value
  | succ fuel =>
    match eval with
    | .empty .. => intro value h; cases h; exact ⟨rfl, rfl⟩
    | .builderBind _ _ _ _ _ _ _ child =>
      exact base_block_normal_sound fuel (models_extend models (value := none) trivial) (ranges_extend rangeRelated none) child
    | .last _ _ _ _ _ _ child => exact base_normal_sound fuel models rangeRelated child
    | .lastBind _ _ _ _ _ result _ child
    | .lastDiscard _ _ _ _ result _ child
    | .lastPat _ _ _ _ _ _ result _ child =>
      intro value h
      cases result <;> try cases h
      exact then_contains (contains_live ((base_normal_sound fuel models rangeRelated child) _ rfl)) (by constructor <;> rfl)
    | .bind _ _ kind _ _ _ _ _ _ _ _ head tail =>
      intro value h
      have inside := (base_normal_sound fuel models rangeRelated head) _ rfl
      have typed := eval_normal_typed head
      exact then_contains (contains_live inside)
        ((base_block_normal_sound fuel (by exact bind_models kind models typed inside) (range_save_result_of_eval models rangeRelated head) tail) value h)
    | .discard _ _ _ _ _ _ _ _ _ _ head tail
    | .seq _ _ _ _ _ _ _ _ _ head tail =>
      intro value h
      exact then_contains (contains_live ((base_normal_sound fuel models rangeRelated head) _ rfl))
        ((base_block_normal_sound fuel models rangeRelated tail) value h)
    | .bindPat _ _ _ _ _ _ _ _ _ _ _ _ _ head bindings tail =>
      intro value h
      have typed := eval_normal_typed head
      exact then_contains (contains_live ((base_normal_sound fuel models rangeRelated head) _ rfl))
        ((base_block_normal_sound fuel (pattern_models models typed bindings) (pattern_ranges rangeRelated bindings) tail) value h)
    | .bindAbrupt _ _ _ _ _ _ _ _ _ _ abrupt
    | .discardAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .seqAbrupt _ _ _ _ _ _ _ _ abrupt
    | .bindPatAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      intro value h; rw [h] at abrupt; contradiction
/-- 選ばれた腕の正常値は、同じ元環境から解析した全腕の合流に入る。 -/
private theorem base_arms_normal_sound (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    NormalCovered (analyzeBaseArms fuel abstract source normal key arms) outcome := by
  cases fuel with
  | zero => exact fun value _ => unknown_contains value
  | succ fuel =>
    match eval with
    | .nil .. => intro value h; cases h
    | .skip _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      intro value h
      apply join_contains (Or.inr ?_)
      exact (base_arms_normal_sound fuel models rangeRelated scrutinee inside tail) value h
    | .body _ _ _ _ _ _ _ _ _ _ selection body =>
      intro value h
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models rangeRelated scrutinee inside selection entry
      apply join_contains (Or.inl ?_)
      simp only [baseKindArm, matchKindArmEnv, baseArm, entry]
      exact (base_block_normal_sound fuel related innerRanges body) value h
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      intro value h
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models rangeRelated scrutinee inside selection entry
      apply join_contains (Or.inl ?_)
      simp only [baseKindArm, matchKindArmEnv, baseArm, entry]
      obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition
        ((base_normal_sound fuel related innerRanges condition) _ rfl)
      apply merge_contains (Or.inl ?_)
      simp only [baseBranch, atEnv]
      exact (base_block_normal_sound fuel modeled (ranges_branchEnv innerRanges atEnv) body) value h
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      intro value h; rw [h] at abrupt; contradiction

private theorem base_widthArms_normal_sound (fuel : Nat) (kind : IntKind)
    {abstract concrete source key scrutineeKey arms type outcome trace st}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64) (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    NormalCovered (analyzeBaseKindArms fuel kind abstract source normal key arms) outcome := by
  cases fuel with
  | zero => exact fun value _ => unknown_contains value
  | succ fuel =>
    match eval with
    | .nil .. => intro value h; cases h
    | .skip _ _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      intro value h
      apply join_contains (Or.inr ?_)
      exact (base_widthArms_normal_sound fuel kind not64 models rangeRelated scrutinee inside tail) value h
    | .body _ _ _ _ _ _ _ _ _ _ _ selection body =>
      intro value h
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models rangeRelated scrutinee inside selection not64 entry
      apply join_contains (Or.inl ?_)
      simp only [baseKindArm, entry]
      exact (base_block_normal_sound fuel related innerRanges body) value h
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      intro value h
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models rangeRelated scrutinee inside selection not64 entry
      apply join_contains (Or.inl ?_)
      simp only [baseKindArm, entry]
      obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition
        ((base_normal_sound fuel related innerRanges condition) _ rfl)
      apply merge_contains (Or.inl ?_)
      simp only [baseBranch, atEnv]
      exact (base_block_normal_sound fuel modeled (ranges_branchEnv innerRanges atEnv) body) value h
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      intro value h; rw [h] at abrupt; contradiction

/-- 正常な引数列の代表 Unit を、左からの正常値の合成で保存する。 -/
private theorem base_typed_arguments_normal_sound (fuel : Nat) {abstract concrete key sources types outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalTypedArguments concrete key sources types outcome trace) :
    ∀ values, outcome = .normal values → (analyzeBaseArguments fuel abstract key sources).Contains .unit := by
  cases fuel with
  | zero => exact fun _ _ => unknown_contains .unit
  | succ fuel =>
    cases eval with
    | nil => intro _ _; exact ⟨rfl, rfl⟩
    | cons _ _ _ _ _ _ _ _ _ _ head tail =>
      intro _ _
      exact then_contains (contains_live (base_normal_sound fuel models rangeRelated head _ rfl))
        (base_typed_arguments_normal_sound fuel models rangeRelated tail _ rfl)
    | headAbrupt => intro _ same; cases same
    | tailAbrupt => intro _ same; cases same

/-- Result の正常な腕本体を、由来を共有する全腕の合流に含める。 -/
private theorem base_resultArms_normal_sound (fuel : Nat)
    {abstract concrete input arms origin result tag payload key type outcome trace st}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (recognized : rangeMatchAt abstract input arms = some origin)
    (scrutinee : EvalPartial concrete input (.normal result) st)
    (matched : rangeResultMatch concrete result arms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (eval : EvalResultArms concrete key origin.names result tag payload arms type outcome trace) :
    NormalCovered (analyzeBaseResultArms fuel abstract input key arms) outcome := by
  cases fuel with
  | zero => exact fun value _ => unknown_contains value
  | succ fuel =>
    match eval with
    | .nil .. => intro value normal; cases normal
    | .skip _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      intro value normal
      apply join_contains (Or.inr ?_)
      have nextRecognized := range_match_at_tail recognized
      have nextMatched := range_match_at_evaluated models rangeRelated nextRecognized scrutinee
      exact base_resultArms_normal_sound fuel models rangeRelated nextRecognized scrutinee nextMatched view tail value normal
    | .body _ _ _ _ _ _ _ _ _ _ _ _ _ selection body =>
      intro value normal
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have innerRanges := baseResultArmEnv_ranges models rangeRelated recognized scrutinee matched view selection
      apply join_contains (Or.inl ?_)
      exact base_block_normal_sound fuel innerModels innerRanges body value normal
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      intro value normal
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have innerRanges := baseResultArmEnv_ranges models rangeRelated recognized scrutinee matched view selection
      obtain ⟨refined, atEnv, modeled⟩ := branch_models innerModels condition
        (base_normal_sound fuel innerModels innerRanges condition _ rfl)
      apply join_contains (Or.inl ?_)
      apply merge_contains (Or.inl ?_)
      simp only [baseBranch, atEnv]
      exact base_block_normal_sound fuel modeled (ranges_branchEnv innerRanges atEnv) body value normal
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      intro value normal; rw [normal] at abrupt; contradiction

end

private theorem base_arguments_normal_sound (fuel : Nat) {abstract concrete key sources type outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalArguments concrete key sources type outcome trace) :
    ∀ values, outcome = .normal values → (analyzeBaseArguments fuel abstract key sources).Contains .unit := by
  exact base_typed_arguments_normal_sound fuel models rangeRelated (arguments_typed eval)

/-- 出現の部分木が占める半開区間。 -/
def KeyWithin (start : OperationKey) (size : Nat) (key : OperationKey) : Prop :=
  key.definition = start.definition ∧ start.surfacePreorder ≤ key.surfacePreorder ∧
    key.surfacePreorder < start.surfacePreorder + size

private theorem then_warning {left right warning}
    (member : warning ∈ (baseThen left right).warnings) :
    warning ∈ left.warnings ∨ warning ∈ right.warnings := by
  unfold baseThen at member
  split at member
  · exact List.mem_append.mp member
  · exact Or.inl member

theorem baseOwnKind_warning_origin {key op kind left right warning}
    (member : warning ∈ (baseOwnKind key op kind left right).warnings) :
    warning.key = key ∧ warning.operation = .binary op kind.type := by
  simp only [baseOwnKind] at member
  repeat' split at member
  all_goals simp_all [baseBoolean, baseEmpty, baseUnknown]

/-- 局所二項演算の候補は、注記された型と演算の位置を保持する。 -/
theorem baseOwn_warning_origin {key op type left right warning}
    (member : warning ∈ (baseOwn key op type left right).warnings) :
    warning.key = key ∧ warning.operation = .binary op type := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseOwn, baseOwnKind, IntKind.ofType, analyzeDivMod] at member
  all_goals repeat' split at member
  all_goals simp_all [baseBoolean, baseEmpty, baseUnknown, IntKind.type]

private theorem binary_warning {key op type left right warning}
    (member : warning ∈ (baseBinary key op type left right).warnings) :
    warning ∈ left.warnings ∨ warning ∈ right.warnings ∨ warning.key = key := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseBinary, IntKind.ofType] at member
  all_goals try contradiction
  all_goals split at member <;> try contradiction
  all_goals
    rcases then_warning member with h | h
    · exact Or.inl h
    rcases then_warning h with h | h
    · exact Or.inr (Or.inl h)
    right; right
    first | exact (baseOwn_warning_origin h).1 | exact (baseOwnKind_warning_origin h).1

/-- 負号自身の候補は、一引数の演算の位置だけを指す。 -/
theorem negOwn_warning {key child warning}
    (member : warning ∈ (baseNegOwn key child).warnings) :
    warning = ⟨key, .neg (.base .integer), .overflow⟩ := by
  simp only [baseNegOwn] at member
  split at member
  · exact List.mem_singleton.mp member
  · contradiction

/-- 負号自身の候補は幅と原因を保持する。 -/
theorem negOwnTyped_warning {key type child warning}
    (member : warning ∈ (baseNegOwnTyped key type child).warnings) :
    warning = ⟨key, .neg type, .overflow⟩ := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseNegOwnTyped, baseNegOwn, baseNegOwnKind,
    IntKind.ofType, IntKind.min] at member
  all_goals repeat' split at member
  all_goals simp_all [baseUnknown, IntKind.type]

private theorem neg_warning {key type child warning}
    (member : warning ∈ (baseNeg key type child).warnings) :
    warning ∈ child.warnings ∨ warning = ⟨key, .neg type, .overflow⟩ := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseNeg, IntKind.ofType, IntKind.min] at member
  all_goals try contradiction
  all_goals try (split at member <;> try contradiction)
  all_goals
    rcases then_warning member with h | h
    · exact Or.inl h
    · right
      exact negOwnTyped_warning h

private theorem branch_warning {env condition tested truth run warning}
    (member : warning ∈ (baseBranch env condition tested truth run).warnings) :
    ∃ refined, warning ∈ (run refined).warnings := by
  unfold baseBranch at member
  split at member
  · contradiction
  · exact ⟨_, member⟩

private theorem merge_warning {tested yes no warning}
    (member : warning ∈ (baseMerge tested yes no).warnings) :
    warning ∈ tested.warnings ∨ warning ∈ yes.warnings ∨ warning ∈ no.warnings := by
  simpa only [baseMerge, baseJoin, List.mem_append, or_assoc] using member

private theorem arm_warning {env source normal alts run warning}
    (member : warning ∈ (baseArm env source normal alts run).warnings) :
    ∃ inner, warning ∈ (run inner).warnings := by
  unfold baseArm at member
  split at member
  · contradiction
  · exact ⟨_, member⟩

private theorem match_warning {tested arms warning}
    (member : warning ∈ (baseMatch tested arms).warnings) :
    warning ∈ tested.warnings ∨ warning ∈ arms.warnings := by
  rcases then_warning member with h | h
  · exact Or.inl h
  · split at h
    · exact Or.inr h
    · contradiction

private theorem kindArm_warning {kind env source normal alts run warning}
    (member : warning ∈ (baseKindArm kind env source normal alts run).warnings) :
    ∃ inner, warning ∈ (run inner).warnings := by
  unfold baseKindArm at member
  split at member
  · contradiction
  · exact ⟨_, member⟩

private theorem matchKind_warning {tested run warning}
    (member : warning ∈ (baseMatchKind tested run).warnings) :
    warning ∈ tested.warnings ∨ ∃ kind, warning ∈ (run kind).warnings := by
  rcases then_warning member with h | h
  · exact Or.inl h
  · right
    cases known : tested.matchKind with
    | none => simp [known, baseUnknown] at h
    | some kind => exact ⟨kind, by simpa only [known] using h⟩



/-- 現 profile で事象を作る構文上の演算。 -/
def arithmeticOperationAt : Expr → Option TargetOperation
  | .neg type _ => match IntKind.ofType type with
    | some kind => if kind.min < 0 then some (.neg type) else none
    | none => none
  | .binary op type _ _ =>
      if (IntKind.ofType type).isSome ∧
        (op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true)
      then some (.binary op type) else none
  | _ => none

/-- 標準呼び出しは二つの解決済みの表と出現のキーから認定する。
算術だけの認定は環境に依存しない（設計書 01-12「区間解析の土台の解析と健全性」）。 -/
def targetOperationAt (env : AbstractEnv) (key : OperationKey) (source : Expr) :
    Option TargetOperation :=
  match source with
  | .call (.funName declaration [] []) _ _ _
  | .call (.primName declaration [] []) _ _ _ => do
    let binding ← env.standardAt key
    if declaration = binding.declaration then some (.standard binding) else none
  | _ => arithmeticOperationAt source

/-- 算術の位置についての従来の保証は、任意の標準束縛表の下でそのまま使える。 -/
theorem arithmetic_target_at {source operation}
    (known : arithmeticOperationAt source = some operation) (env : AbstractEnv) (key : OperationKey) :
    targetOperationAt env key source = some operation := by
  cases source <;> first | exact known | contradiction

/-- 局所区間や Range の由来を変えても、二表が同じなら演算の同定は変わらない。 -/
theorem target_at_tables {left right : AbstractEnv}
    (standards : left.standards = right.standards) (apiAt : left.apiAt = right.apiAt)
    (key : OperationKey) (source : Expr) :
    targetOperationAt left key source = targetOperationAt right key source := by
  cases source <;> simp only [targetOperationAt]
  rename_i callee labels positions arguments
  cases callee <;> simp only [targetOperationAt, AbstractEnv.standardAt, standards, apiAt]
  all_goals rename_i declaration types effects
  all_goals cases types <;> cases effects <;> simp [targetOperationAt, AbstractEnv.standardAt, standards, apiAt]

/-- 標準関数の位置は、同定表と表層の宣言の両方を照合する。 -/
theorem target_at_function (env : AbstractEnv) (key : OperationKey)
    (declaration : FunName) (labels positions arguments) :
    targetOperationAt env key (.call (.funName declaration [] []) labels positions arguments) =
      (env.standardAt key).bind (fun binding =>
        if declaration = binding.declaration then some (.standard binding) else none) := rfl

/-- 組み込み関数の位置も、標準関数と同じ二表と宣言を照合する。 -/
theorem target_at_primitive (env : AbstractEnv) (key : OperationKey)
    (declaration : PrimName) (labels positions arguments) :
    targetOperationAt env key (.call (.primName declaration [] []) labels positions arguments) =
      (env.standardAt key).bind (fun binding =>
        if declaration = binding.declaration then some (.standard binding) else none) := rfl

/-- 認定した標準 call は、元のキーの二表と同じ宣言を持つ。 -/
theorem call_binding_identity {env : AbstractEnv} {key source binding}
    (recognized : rangeCallAt env key source = some binding) :
    env.standardAt key = some binding ∧
      (match source with | .call callee _ _ _ => standardCallHead callee = some binding.declaration | _ => False) := by
  cases source <;> simp only [rangeCallAt, rangeCallBinding] at recognized <;> try contradiction
  rename_i callee labels positions arguments
  obtain ⟨declaration, head, recognized⟩ := Option.bind_eq_some_iff.mp recognized
  obtain ⟨other, found, result⟩ := Option.bind_eq_some_iff.mp recognized
  by_cases different : declaration ≠ other.declaration
  · simp [different] at result
  · simp only [different, ↓reduceIte] at result
    have same : declaration = other.declaration := by simpa using different
    have bindingEq : other = binding := by
      cases rule : other.rule <;> try simp only [rule] at result
      all_goals split at result <;> simp_all
    subst binding
    exact ⟨found, by simpa only [same] using head⟩

/-- 元の同定表から得た標準 call は、その出現の対象演算にも一致する。 -/
theorem call_binding_target {env : AbstractEnv} {key source binding}
    (recognized : rangeCallAt env key source = some binding) :
    targetOperationAt env key source = some (.standard binding) := by
  obtain ⟨found, head⟩ := call_binding_identity recognized
  cases source <;> simp only at head <;> try contradiction
  rename_i callee labels positions arguments
  cases callee <;> simp only [standardCallHead] at head <;> try contradiction
  all_goals rename_i declaration types effects
  all_goals cases types <;> cases effects <;> simp_all [standardCallHead, targetOperationAt]

/-- 算術の構文との一致は保ち、固定域の標準 call の構文だけを追加する。 -/
def WarningOperationSyntax (source : Expr) (operation : TargetOperation) : Prop :=
  match operation with
  | .standard binding => binding.rule.isFixed = true ∧
      (match source with | .call callee _ _ _ => standardCallHead callee = some binding.declaration | _ => False)
  | _ => arithmeticOperationAt source = some operation

/-- 算術の警告について、演算の認定は従来の arithmeticOperationAt のままである。 -/
theorem warning_syntax_binary {source op type}
    (recognized : WarningOperationSyntax source (.binary op type)) :
    arithmeticOperationAt source = some (.binary op type) := recognized

theorem warning_syntax_neg {source type}
    (recognized : WarningOperationSyntax source (.neg type)) :
    arithmeticOperationAt source = some (.neg type) := recognized

/-- 負号の候補がある型は、番号付けでも同じ演算として認定される。 -/
theorem negOwnTyped_warning_located {key type child warning source}
    (member : warning ∈ (baseNegOwnTyped key type child).warnings) :
    arithmeticOperationAt (.neg type source) = some warning.operation := by
  have origin := negOwnTyped_warning member
  subst warning
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp_all [baseNegOwnTyped, baseNegOwn, baseNegOwnKind,
    baseUnknown, IntKind.ofType, IntKind.min, IntKind.type, arithmeticOperationAt, min64]

private theorem neg_warning_located {key type child warning source}
    (member : warning ∈ (baseNeg key type child).warnings) :
    warning ∈ child.warnings ∨
      (warning.key = key ∧ arithmeticOperationAt (.neg type source) = some warning.operation) := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseNeg, IntKind.ofType, IntKind.min] at member
  all_goals try contradiction
  all_goals try (split at member <;> try contradiction)
  all_goals
    rcases then_warning member with h | h
    · exact Or.inl h
    · right
      first
      | have origin : warning = ⟨key, .neg (.base .integer), .overflow⟩ := negOwnTyped_warning h
        exact ⟨by cases origin; rfl, negOwnTyped_warning_located (type := .base .integer) h⟩
      | have origin : warning = ⟨key, .neg (.base .integer8), .overflow⟩ := negOwnTyped_warning h
        exact ⟨by cases origin; rfl, negOwnTyped_warning_located (type := .base .integer8) h⟩
      | have origin : warning = ⟨key, .neg (.base .integer16), .overflow⟩ := negOwnTyped_warning h
        exact ⟨by cases origin; rfl, negOwnTyped_warning_located (type := .base .integer16) h⟩
      | have origin : warning = ⟨key, .neg (.base .integer32), .overflow⟩ := negOwnTyped_warning h
        exact ⟨by cases origin; rfl, negOwnTyped_warning_located (type := .base .integer32) h⟩

/-- 既に先行順に平坦化した式列の番号付け。 -/
private def numberSources (key : OperationKey) (sources : List Expr) : List (OperationKey × Expr) :=
  (sources.zipIdx key.surfacePreorder).map fun (source, index) =>
    (⟨key.definition, index⟩, source)

private def LocatedList (env : AbstractEnv) (key : OperationKey) (sources : List Expr) (warning : IntervalWarning) : Prop :=
  ∃ source, (warning.key, source) ∈ numberSources key sources ∧
    targetOperationAt env warning.key source = some warning.operation

/-- 警告のキーにある実際の構文が、その警告の演算に一致する。 -/
def WarningLocated {Budget : Type}
    (analyze : AbstractEnv → EvalInput → Budget → AnalysisResult) : Prop :=
  ∀ env input budget warning, warning ∈ (analyze env input budget).warnings →
    ∃ source, (warning.key, source) ∈ numbered input.key input.source ∧
      targetOperationAt env warning.key source = some warning.operation

private theorem preorderBlock_length (body : Block) : (preorderBlock body).length = blockSize body := by
  have h := surfaceSize_block body
  simpa [surfaceSize, surfacePreorder, Nat.add_comm] using h

private theorem located_context {env : AbstractEnv} {key sources warning} (before after : List Expr)
    (located : LocatedList env (advanceKey key before.length) sources warning) :
    LocatedList env key (before ++ sources ++ after) warning := by
  obtain ⟨source, member, operation⟩ := located
  refine ⟨source, ?_, operation⟩
  simp only [numberSources, List.zipIdx_append, List.map_append, List.mem_append] at *
  exact Or.inl (Or.inr member)

private theorem target_tables {left right : AbstractEnv} (same : rangeTables left = rangeTables right)
    (key source) : targetOperationAt left key source = targetOperationAt right key source :=
  target_at_tables (congrArg ConcreteEnv.standards same) (congrArg ConcreteEnv.apiAt same) key source

private theorem located_tables {left right key sources warning}
    (same : rangeTables left = rangeTables right) (h : LocatedList left key sources warning) :
    LocatedList right key sources warning := by
  obtain ⟨source, member, target⟩ := h
  exact ⟨source, member, (target_tables same warning.key source).symm.trans target⟩

@[simp] private theorem target_clear (env key source) :
    targetOperationAt (clearLocals env) key source = targetOperationAt env key source := target_tables rfl _ _
@[simp] private theorem target_extend (env slot key source) :
    targetOperationAt (extend env slot) key source = targetOperationAt env key source := target_tables rfl _ _
@[simp] private theorem target_bind (kind env type value input key source) :
    targetOperationAt (baseBindSource kind env type value input) key source = targetOperationAt env key source :=
  target_tables (BudgetAnalysis.CallReach.tables_bind kind env type value input) _ _
@[simp] private theorem target_pattern (env pattern type key source) :
    targetOperationAt (extendPattern env pattern type) key source = targetOperationAt env key source :=
  target_tables (BudgetAnalysis.CallReach.tables_pattern env pattern type) _ _
@[simp] private theorem target_resultArm (env input alts key source) :
    targetOperationAt (baseResultArmEnv env input alts) key source = targetOperationAt env key source :=
  target_tables (BudgetAnalysis.CallReach.tables_resultArm env input alts) _ _

private theorem branch_warning_tables {env condition tested truth run warning}
    (member : warning ∈ (baseBranch env condition tested truth run).warnings) :
    ∃ refined, rangeTables refined = rangeTables env ∧ warning ∈ (run refined).warnings := by
  cases found : branchEnv env condition tested.boolean truth with
  | none => simp [baseBranch, found, baseEmpty] at member
  | some inner => exact ⟨inner, BudgetAnalysis.CallReach.tables_branch env condition tested.boolean truth inner found,
      by simpa only [baseBranch, found] using member⟩

private theorem arm_warning_tables {env source normal alts run warning}
    (member : warning ∈ (baseArm env source normal alts run).warnings) :
    ∃ inner, rangeTables inner = rangeTables env ∧ warning ∈ (run inner).warnings := by
  cases found : matchArmEnv env source (.base .integer) normal alts with
  | none => simp [baseArm, found, baseEmpty] at member
  | some inner => exact ⟨inner, BudgetAnalysis.CallReach.tables_arm env source .integer64 normal alts inner found,
      by simpa only [baseArm, found] using member⟩

private theorem kindArm_warning_tables {kind env source normal alts run warning}
    (member : warning ∈ (baseKindArm kind env source normal alts run).warnings) :
    ∃ inner, rangeTables inner = rangeTables env ∧ warning ∈ (run inner).warnings := by
  cases found : matchKindArmEnv env source kind normal alts with
  | none => simp [baseKindArm, found, baseEmpty] at member
  | some inner => exact ⟨inner, BudgetAnalysis.CallReach.tables_arm env source kind normal alts inner found,
      by simpa only [baseKindArm, found] using member⟩

private theorem located_root {env : AbstractEnv} (key source warning)
    (same : warning.key = key) (operation : arithmeticOperationAt source = some warning.operation) :
    LocatedList env key (surfacePreorder source) warning := by
  refine ⟨source, ?_, arithmetic_target_at operation env warning.key⟩
  rw [surfacePreorder_children]
  simp [numberSources, same]

private theorem located_fixed_root {env key source binding positions values warning}
    (recognized : rangeCallAt env key source = some binding)
    (member : warning ∈ (baseFixedOwn binding key positions values).warnings) :
    LocatedList env key (surfacePreorder source) warning := by
  obtain ⟨rfl, _⟩ := baseFixedOwn_warning member
  refine ⟨source, ?_, call_binding_target recognized⟩
  rw [surfacePreorder_children]
  simp [numberSources]

private theorem binary_warning_origin {key op type left right warning}
    (member : warning ∈ (baseBinary key op type left right).warnings) :
    warning ∈ left.warnings ∨ warning ∈ right.warnings ∨
      (warning.key = key ∧ arithmeticOperationAt (.binary op type lhs rhs) = some warning.operation) := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseBinary, IntKind.ofType] at member
  all_goals try contradiction
  all_goals split at member <;> try contradiction
  all_goals
    rcases then_warning member with h | h
    · exact Or.inl h
    rcases then_warning h with h | h
    · exact Or.inr (Or.inl h)
    right; right
    first
    | have origin := baseOwn_warning_origin h
      exact ⟨origin.1, by simp_all [arithmeticOperationAt, IntKind.ofType, IntKind.type]⟩
    | have origin := baseOwnKind_warning_origin h
      exact ⟨origin.1, by simp_all [arithmeticOperationAt, IntKind.ofType, IntKind.type]⟩

/-- 呼び出しの引数容器の番号列を、ソース順の式の列へ展開する。 -/
private theorem preorderExprs_flatMap (sources : Exprs) :
    preorderExprs sources = (exprsChildren sources).flatMap surfacePreorder := by
  cases sources with
  | nil => rfl
  | cons source rest => simp only [preorderExprs, exprsChildren, List.flatMap_cons, preorderExprs_flatMap rest]


private theorem baseValuesWith_located {run : OperationKey → Expr → BaseApprox} {env key sources warning}
    (children : ∀ key source warning, warning ∈ (run key source).warnings →
      LocatedList env key (surfacePreorder source) warning)
    (member : warning ∈ (baseValuesWith run key sources).aggregate.warnings) :
    LocatedList env key (sources.flatMap surfacePreorder) warning := by
  induction sources generalizing key with
  | nil => contradiction
  | cons source rest ih =>
    simp only [baseValuesWith] at member
    split at member
    · rcases then_warning member with h | h
      · have located := children key source warning h
        have lifted := located_context (key := key) [] (rest.flatMap surfacePreorder) located
        simpa [LocatedList, List.flatMap_cons, advanceKey] using lifted
      · have located := ih h
        have lifted := located_context (key := key) (surfacePreorder source) []
          (by simpa [surfaceSize] using located)
        simpa [LocatedList, List.flatMap_cons] using lifted
    · have located := children key source warning member
      have lifted := located_context (key := key) [] (rest.flatMap surfacePreorder) located
      simpa [LocatedList, List.flatMap_cons, advanceKey] using lifted

mutual
/-- キーの範囲に加え、その出現の構文と演算の一致を示す。短絡後も成り立つ。 -/
private theorem base_warning_located (fuel : Nat) (env key source) {warning}
    (member : warning ∈ (analyzeBaseExpr fuel env key source).warnings) :
    LocatedList env key (surfacePreorder source) warning := by
  cases fuel with
  | zero => contradiction
  | succ fuel =>
    match source with
    | .literal value => cases value <;> simp [analyzeBaseExpr, baseInteger, baseBoolean, baseEmpty, baseUnknown] at member
    | .local index => simp only [analyzeBaseExpr, baseLocal_warnings, List.not_mem_nil] at member
    | .negInt _ | .unit => contradiction
    | .negInteger8 _ | .negInteger16 _ | .negInteger32 _ =>
      simp only [analyzeBaseExpr, baseWidthLiteral_warnings, List.not_mem_nil] at member
    | .paren child =>
      have h := base_warning_located fuel _ _ child member
      have lifted := located_context (key := key) ([.paren child]) ([])
        (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
      simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
        surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .constE type child =>
      have h := base_warning_located fuel _ _ child member
      have lifted := located_context (key := key) ([.constE type child]) ([])
        (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
      simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
        surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .returnE type child =>
      have h := base_warning_located fuel _ _ child member
      have lifted := located_context (key := key) ([.returnE type child]) ([])
        (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
      simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
        surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .not child =>
      have h := base_warning_located fuel _ _ child member
      have lifted := located_context (key := key) ([.not child]) ([])
        (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
      simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
        surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .neg type child =>
      rcases neg_warning_located member with h | h
      · have h := base_warning_located fuel env (childKey key []) child h
        have lifted := located_context (key := key) ([.neg type child]) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length,
            blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · exact located_root key _ _ h.1 h.2
    | .binary op type left right =>
      rcases binary_warning_origin member with h | h | h
      · have h := base_warning_located fuel env (childKey key []) left h
        have lifted := located_context (key := key) ([.binary op type left right]) (surfacePreorder right)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · have h := base_warning_located fuel env (childKey key [left]) right h
        have lifted := located_context (key := key) ([.binary op type left right] ++ surfacePreorder left) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · exact located_root key _ warning h.1 h.2
    | .and left right =>
      rcases merge_warning member with h | h | h
      · have h := base_warning_located fuel env (childKey key []) left h
        have lifted := located_context (key := key) ([.and left right]) (surfacePreorder right)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_warning_located fuel refined (childKey key [left]) right h)
        have lifted := located_context (key := key) ([.and left right] ++ surfacePreorder left) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨_, h⟩ := branch_warning h; contradiction
    | .or left right =>
      rcases merge_warning member with h | h | h
      · have h := base_warning_located fuel env (childKey key []) left h
        have lifted := located_context (key := key) ([.or left right]) (surfacePreorder right)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_warning_located fuel refined (childKey key [left]) right h)
        have lifted := located_context (key := key) ([.or left right] ++ surfacePreorder left) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨_, h⟩ := branch_warning h; contradiction
    | .block body =>
      have h := base_block_warning_located fuel _ _ body member
      have lifted := located_context (key := key) ([.block body]) ([])
        (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
      simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
        surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .ite cond yes no =>
      rcases merge_warning member with h | h | h
      · have h := base_warning_located fuel env (childKey key []) cond h
        have lifted := located_context (key := key) ([.ite cond yes no]) (preorderBlock yes ++ preorderBlock no)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_block_warning_located fuel refined (childKey key [cond]) yes h)
        have lifted := located_context (key := key) ([.ite cond yes no] ++ surfacePreorder cond) (preorderBlock no)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_block_warning_located fuel refined (childKey key (cond :: blockChildren yes)) no h)
        have lifted := located_context (key := key) ([.ite cond yes no] ++ surfacePreorder cond ++ preorderBlock yes) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .elseIf cond yes no =>
      rcases merge_warning member with h | h | h
      · have h := base_warning_located fuel env (childKey key []) cond h
        have lifted := located_context (key := key) ([.elseIf cond yes no]) (preorderBlock yes ++ surfacePreorder no)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_block_warning_located fuel refined (childKey key [cond]) yes h)
        have lifted := located_context (key := key) ([.elseIf cond yes no] ++ surfacePreorder cond) (surfacePreorder no)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_warning_located fuel refined (childKey key (cond :: blockChildren yes)) no h)
        have lifted := located_context (key := key) ([.elseIf cond yes no] ++ surfacePreorder cond ++ preorderBlock yes) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
    | .ifOnly cond yes =>
      rcases merge_warning member with h | h | h
      · have h := base_warning_located fuel env (childKey key []) cond h
        have lifted := located_context (key := key) ([.ifOnly cond yes]) (preorderBlock yes)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
        have h := located_tables (tables) (base_block_warning_located fuel refined (childKey key [cond]) yes h)
        have lifted := located_context (key := key) ([.ifOnly cond yes] ++ surfacePreorder cond) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · obtain ⟨_, h⟩ := branch_warning h; contradiction
    | .call callee labels positions arguments =>
      cases known : rangeCallAt env key (.call callee labels positions arguments) with
      | none => simp [analyzeBaseExpr, known, baseUnknown] at member
      | some binding =>
        simp only [analyzeBaseExpr, known] at member
        split at member
        · rcases then_warning member with h | h
          · have h := baseValuesWith_located
              (fun key source warning member => base_warning_located fuel env key source member) h
            have lifted := located_context (key := key)
              ([.call callee labels positions arguments] ++ surfacePreorder callee) []
              (by simpa [childKey, advanceKey, surfaceSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
            simpa [LocatedList, surfacePreorder, preorderExprs_flatMap, List.append_assoc] using lifted
          · exact located_fixed_root known h
        · rcases then_warning member with h | h
          · have h := base_arguments_warning_located fuel env (childKey key [callee]) (exprsChildren arguments) h
            have lifted := located_context (key := key)
              ([.call callee labels positions arguments] ++ surfacePreorder callee) []
              (by simpa [childKey, advanceKey, surfaceSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
            simpa [LocatedList, surfacePreorder, preorderExprs_flatMap, List.append_assoc] using lifted
          · simp only [baseRangeCall_warnings, List.not_mem_nil] at h
    | .matchE type source arms =>
      simp only [analyzeBaseExpr] at member
      split at member
      · rcases then_warning member with h | h
        · have h := base_warning_located fuel env (childKey key []) source h
          have lifted := located_context (key := key) ([.matchE type source arms]) (preorderArms arms)
            (by simpa [advanceKey, childKey] using h)
          simpa [LocatedList, surfacePreorder, List.append_assoc] using lifted
        · have h := base_resultArms_warning_located fuel env _ (childKey key [source]) arms h
          have lifted := located_context (key := key) ([.matchE type source arms] ++ surfacePreorder source) ([])
            (by simpa [advanceKey, childKey, surfaceSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
          simpa [LocatedList, surfacePreorder, List.append_assoc] using lifted
      · rcases matchKind_warning member with h | h
        · have h := base_warning_located fuel env (childKey key []) source h
          have lifted := located_context (key := key) ([.matchE type source arms]) (preorderArms arms)
            (by simpa [advanceKey, childKey] using h)
          simpa [LocatedList, surfacePreorder, List.append_assoc] using lifted
        · obtain ⟨kind, h⟩ := h
          have h := base_kindArms_warning_located fuel kind env source _ (childKey key [source]) arms h
          have lifted := located_context (key := key) ([.matchE type source arms] ++ surfacePreorder source) ([])
            (by simpa [advanceKey, childKey, surfaceSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
          simpa [LocatedList, surfacePreorder, List.append_assoc] using lifted
    | .funName .. | .funDicts .. | .methName .. | .primName .. | .opName .. | .opDicts ..
    | .raise .. | .nullCon .. | .conValue .. | .builderOp .. | .handleFail ..
    | .negFloat .. | .negDecimal ..
    | .negFloat32 .. | .conCall .. | .pipe .. | .partialCall .. | .partialCon ..
    | .list .. | .listSpread .. | .interpolation .. | .lam ..
    | .tryResult .. | .tryOption .. | .tryResultDie .. | .tryOptionDie .. | .withE ..
    | .lazyE .. | .handleE .. | .resume .. => contradiction

private theorem base_block_warning_located (fuel : Nat) (env key body) {warning}
    (member : warning ∈ (analyzeBaseBlock fuel env key body).warnings) :
    LocatedList env key (preorderBlock body) warning := by
  cases fuel with
  | zero => contradiction
  | succ fuel =>
    match body with
    | .empty => contradiction
    | .builderBind kind rest =>
      simpa only [LocatedList, target_extend, preorderBlock] using base_block_warning_located fuel (extend env (.builder kind)) key rest member
    | .last source => exact base_warning_located fuel env key source member
    | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source =>
      rcases then_warning member with h | h
      · exact base_warning_located fuel env key source h
      · contradiction
    | .bind _ _ source rest | .discard source rest | .seq source rest | .bindPat _ _ _ source rest =>
      rcases then_warning member with h | h
      · have h := base_warning_located fuel env key source h
        have lifted := located_context (key := key) ([]) (preorderBlock rest)
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
      · have h := base_block_warning_located fuel _ (advanceKey key (surfaceSize source)) rest h
        have lifted := located_context (key := key) (surfacePreorder source) ([])
          (by simpa [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h)
        simpa [LocatedList, surfacePreorder, preorderBlock, childKey, advanceKey,
          surfaceSize, List.append_assoc, Nat.add_assoc] using lifted
/-- 腕の容器を数えず、guard と本体の実際の演算の出現を保つ。 -/
private theorem base_arms_warning_located (fuel : Nat) (env source normal key arms) {warning}
    (member : warning ∈ (analyzeBaseArms fuel env source normal key arms).warnings) :
    LocatedList env key (preorderArms arms) warning := by
  cases fuel with
  | zero => contradiction
  | succ fuel =>
    cases arms with
    | nil => contradiction
    | cons alts guard body rest =>
      rcases List.mem_append.mp member with h | h
      · obtain ⟨inner, innerTables, h⟩ := arm_warning_tables h
        cases guard with
        | none =>
          have h := located_tables innerTables (base_block_warning_located fuel inner key body h)
          have lifted := located_context (key := key) ([]) (preorderArms rest) h
          simpa [LocatedList, preorderArms, advanceKey] using lifted
        | some condition =>
          rcases merge_warning h with h | h | h
          · have h := located_tables innerTables (base_warning_located fuel inner key condition h)
            have lifted := located_context (key := key) ([]) (preorderBlock body ++ preorderArms rest) h
            simpa [LocatedList, preorderArms, advanceKey, List.append_assoc] using lifted
          · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
            have h := located_tables (tables.trans innerTables) (base_block_warning_located fuel refined (advanceKey key (surfaceSize condition)) body h)
            have lifted := located_context (key := key) (surfacePreorder condition) (preorderArms rest)
              (by simpa [surfaceSize] using h)
            simpa [LocatedList, preorderArms, List.append_assoc] using lifted
          · contradiction
      · have h := base_arms_warning_located fuel env source normal
          (advanceKey key (guardSize guard + blockSize body)) rest h
        have lifted := located_context (key := key)
          ((guard.toList.flatMap surfacePreorder) ++ preorderBlock body) ([])
          (by cases guard <;> simpa [guardSize, surfaceSize, preorderBlock_length] using h)
        cases guard <;> simpa [LocatedList, preorderArms, List.append_assoc] using lifted

private theorem base_kindArms_warning_located (fuel : Nat) (kind : IntKind) (env source normal key arms) {warning}
    (member : warning ∈ (analyzeBaseKindArms fuel kind env source normal key arms).warnings) :
    LocatedList env key (preorderArms arms) warning := by
  cases fuel with
  | zero => contradiction
  | succ fuel =>
    cases arms with
    | nil => contradiction
    | cons alts guard body rest =>
      rcases List.mem_append.mp member with h | h
      · obtain ⟨inner, innerTables, h⟩ := kindArm_warning_tables h
        cases guard with
        | none =>
          have h := located_tables innerTables (base_block_warning_located fuel inner key body h)
          have lifted := located_context (key := key) ([]) (preorderArms rest) h
          simpa [LocatedList, preorderArms, advanceKey] using lifted
        | some condition =>
          rcases merge_warning h with h | h | h
          · have h := located_tables innerTables (base_warning_located fuel inner key condition h)
            have lifted := located_context (key := key) ([]) (preorderBlock body ++ preorderArms rest) h
            simpa [LocatedList, preorderArms, advanceKey, List.append_assoc] using lifted
          · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
            have h := located_tables (tables.trans innerTables) (base_block_warning_located fuel refined (advanceKey key (surfaceSize condition)) body h)
            have lifted := located_context (key := key) (surfacePreorder condition) (preorderArms rest)
              (by simpa [surfaceSize] using h)
            simpa [LocatedList, preorderArms, List.append_assoc] using lifted
          · contradiction
      · have h := base_kindArms_warning_located fuel kind env source normal
          (advanceKey key (guardSize guard + blockSize body)) rest h
        have lifted := located_context (key := key)
          ((guard.toList.flatMap surfacePreorder) ++ preorderBlock body) ([])
          (by cases guard <;> simpa [guardSize, surfaceSize, preorderBlock_length] using h)
        cases guard <;> simpa [LocatedList, preorderArms, List.append_assoc] using lifted

/-- 引数列の警告は実際の引数の演算の出現に対応する。 -/
private theorem base_arguments_warning_located (fuel : Nat) (env key sources) {warning}
    (member : warning ∈ (analyzeBaseArguments fuel env key sources).warnings) :
    LocatedList env key (sources.flatMap surfacePreorder) warning := by
  cases fuel with
  | zero => contradiction
  | succ fuel =>
    cases sources with
    | nil => contradiction
    | cons source rest =>
      rcases then_warning member with h | h
      · have h := base_warning_located fuel env key source h
        have lifted := located_context (key := key) ([]) (rest.flatMap surfacePreorder) h
        simpa [LocatedList, List.flatMap_cons, advanceKey] using lifted
      · have h := base_arguments_warning_located fuel env (advanceKey key (surfaceSize source)) rest h
        have lifted := located_context (key := key) (surfacePreorder source) ([])
          (by simpa [surfaceSize] using h)
        simpa [LocatedList, List.flatMap_cons] using lifted

private theorem base_resultArms_warning_located (fuel : Nat) (env input key arms) {warning}
    (member : warning ∈ (analyzeBaseResultArms fuel env input key arms).warnings) :
    LocatedList env key (preorderArms arms) warning := by
  cases fuel with
  | zero => contradiction
  | succ fuel =>
    cases arms with
    | nil => contradiction
    | cons alts guard body rest =>
      rcases List.mem_append.mp member with h | h
      · let inner := baseResultArmEnv env input alts
        change warning ∈ (match guard with
          | none => analyzeBaseBlock fuel inner key body
          | some condition => baseMerge (analyzeBaseExpr fuel inner key condition)
              (baseBranch inner condition (analyzeBaseExpr fuel inner key condition) true (fun refined =>
                analyzeBaseBlock fuel refined (advanceKey key (surfaceSize condition)) body)) baseEmpty).warnings at h
        cases guard with
        | none =>
          have h := base_block_warning_located fuel inner key body h
          have lifted := located_context (key := key) ([]) (preorderArms rest) h
          simpa [LocatedList, inner, preorderArms, advanceKey] using lifted
        | some condition =>
          rcases merge_warning h with h | h | h
          · have h := base_warning_located fuel inner key condition h
            have lifted := located_context (key := key) ([]) (preorderBlock body ++ preorderArms rest) h
            simpa [LocatedList, inner, preorderArms, advanceKey, List.append_assoc] using lifted
          · obtain ⟨refined, tables, h⟩ := branch_warning_tables h
            have h := located_tables (tables) (base_block_warning_located fuel refined (advanceKey key (surfaceSize condition)) body h)
            have lifted := located_context (key := key) (surfacePreorder condition) (preorderArms rest)
              (by simpa [surfaceSize] using h)
            simpa [LocatedList, inner, preorderArms, List.append_assoc] using lifted
          · contradiction
      · have h := base_resultArms_warning_located fuel env input
          (advanceKey key (guardSize guard + blockSize body)) rest h
        have lifted := located_context (key := key)
          ((guard.toList.flatMap surfacePreorder) ++ preorderBlock body) ([])
          (by cases guard <;> simpa [guardSize, surfaceSize, preorderBlock_length] using h)
        cases guard <;> simpa [LocatedList, preorderArms, List.append_assoc] using lifted


end

/-- 解析が出す全警告は、元の番号付けにある同じ演算の出現に対応する。 -/
theorem analyzeBase_warning_located : WarningLocated analyzeBase := by
  intro env input fuel warning member
  obtain ⟨source, numbered, operation⟩ :=
    base_warning_located fuel (resetRanges env) input.key input.source member
  exact ⟨source, numbered, (target_tables (left := resetRanges env) (right := env) rfl warning.key source).symm.trans operation⟩

private theorem numberSources_bounds {start : OperationKey} {sources : List Expr} {key source}
    (member : (key, source) ∈ numberSources start sources) : KeyWithin start sources.length key := by
  induction sources generalizing start with
  | nil => simp [numberSources] at member
  | cons head rest ih =>
    simp only [numberSources, List.zipIdx_cons, List.map_cons, List.mem_cons] at member
    rcases member with same | tail
    · cases same; simp [KeyWithin]
    · have small := ih (start := advanceKey start 1) tail
      simp only [KeyWithin, advanceKey, List.length_cons] at small ⊢
      exact ⟨small.1, by omega, by omega⟩

private theorem located_bounds {env key sources warning} (h : LocatedList env key sources warning) :
    KeyWithin key sources.length warning.key := by
  obtain ⟨source, member, _⟩ := h
  exact numberSources_bounds member

theorem base_warning_bounds (fuel : Nat) (env key source) {warning}
    (member : warning ∈ (analyzeBaseExpr fuel env key source).warnings) :
    KeyWithin key (surfaceSize source) warning.key := by
  exact located_bounds (base_warning_located fuel env key source member)

theorem base_block_warning_bounds (fuel : Nat) (env key body) {warning}
    (member : warning ∈ (analyzeBaseBlock fuel env key body).warnings) :
    KeyWithin key (blockSize body) warning.key := by
  simpa only [preorderBlock_length] using located_bounds (base_block_warning_located fuel env key body member)

theorem base_arms_warning_bounds (fuel : Nat) (env source normal key arms) {warning}
    (member : warning ∈ (analyzeBaseArms fuel env source normal key arms).warnings) :
    KeyWithin key (armsSize arms) warning.key := by
  exact located_bounds (base_arms_warning_located fuel env source normal key arms member)

theorem base_kindArms_warning_bounds (fuel : Nat) (kind : IntKind) (env source normal key arms) {warning}
    (member : warning ∈ (analyzeBaseKindArms fuel kind env source normal key arms).warnings) :
    KeyWithin key (armsSize arms) warning.key := by
  exact located_bounds (base_kindArms_warning_located fuel kind env source normal key arms member)

theorem base_arguments_warning_bounds (fuel : Nat) (env key sources) {warning}
    (member : warning ∈ (analyzeBaseArguments fuel env key sources).warnings) :
    KeyWithin key (sources.map surfaceSize).sum warning.key := by
  have lengths : (sources.flatMap surfacePreorder).length = (sources.map surfaceSize).sum := by
    clear member
    induction sources with
    | nil => rfl
    | cons source rest ih => simp only [List.flatMap_cons, List.length_append, List.map_cons, List.sum_cons, ih, surfaceSize]
  simpa only [lengths] using located_bounds (base_arguments_warning_located fuel env key sources member)

theorem base_resultArms_warning_bounds (fuel : Nat) (env input key arms) {warning}
    (member : warning ∈ (analyzeBaseResultArms fuel env input key arms).warnings) :
    KeyWithin key (armsSize arms) warning.key := by
  exact located_bounds (base_resultArms_warning_located fuel env input key arms member)

private def Good (key : OperationKey) (size : Nat)
    (warnings : List IntervalWarning) (trace : EvalTrace) : Prop :=
  (∀ warning ∈ warnings, KeyWithin key size warning.key) ∧
  (∀ event ∈ trace, KeyWithin key size event.key) ∧
  (∀ warning ∈ warnings, ∀ event, Reached trace warning event →
    event.result = .rejected warning.cause.toFailure)

private theorem Good.emptyTrace {key size warnings}
    (bounds : ∀ warning ∈ warnings, KeyWithin key size warning.key) :
    Good key size warnings [] := ⟨bounds, by simp, by simp [Reached]⟩

private theorem Good.noWarnings {key size trace} (keys : TraceKeys key size trace) :
    Good key size [] trace := ⟨by simp, keys.2, by simp⟩

private theorem Good.subset {key size warnings warnings' trace}
    (good : Good key size warnings trace) (sub : ∀ w ∈ warnings', w ∈ warnings) :
    Good key size warnings' trace :=
  ⟨fun w h => good.1 w (sub w h), good.2.1,
    fun w h e r => good.2.2 w (sub w h) e r⟩

private theorem Good.widen {key key' size size' warnings trace}
    (good : Good key size warnings trace) (same : key.definition = key'.definition)
    (low : key'.surfacePreorder ≤ key.surfacePreorder)
    (high : key.surfacePreorder + size ≤ key'.surfacePreorder + size') :
    Good key' size' warnings trace := by
  refine ⟨?_, ?_, good.2.2⟩
  · intro w h; obtain ⟨d, l, u⟩ := good.1 w h
    exact ⟨d.trans same, by omega, by omega⟩
  · intro e h; obtain ⟨d, l, u⟩ := good.2.1 e h
    exact ⟨d.trans same, by omega, by omega⟩

private theorem Good.append {leftKey rightKey leftSize rightSize lw rw lt rt}
    (left : Good leftKey leftSize lw lt) (right : Good rightKey rightSize rw rt)
    (separated : leftKey.surfacePreorder + leftSize ≤ rightKey.surfacePreorder ∨
      rightKey.surfacePreorder + rightSize ≤ leftKey.surfacePreorder)
    {key size} (leftFits : ∀ k, KeyWithin leftKey leftSize k → KeyWithin key size k)
    (rightFits : ∀ k, KeyWithin rightKey rightSize k → KeyWithin key size k) :
    Good key size (lw ++ rw) (lt ++ rt) := by
  refine ⟨?_, ?_, ?_⟩
  · intro w h; rcases List.mem_append.mp h with h | h
    · exact leftFits _ (left.1 w h)
    · exact rightFits _ (right.1 w h)
  · intro e h; rcases List.mem_append.mp h with h | h
    · exact leftFits _ (left.2.1 e h)
    · exact rightFits _ (right.2.1 e h)
  · intro w hw e reached
    obtain ⟨he, same, op⟩ := reached
    rcases List.mem_append.mp hw with hw | hw <;> rcases List.mem_append.mp he with he | he
    · exact left.2.2 w hw e ⟨he, same, op⟩
    · have a := left.1 w hw; have b := right.2.1 e he
      rw [same] at b
      simp only [KeyWithin] at a b
      rcases separated with h | h <;> omega
    · have a := right.1 w hw; have b := left.2.1 e he
      rw [same] at b
      simp only [KeyWithin] at a b
      rcases separated with h | h <;> omega
    · exact right.2.2 w hw e ⟨he, same, op⟩

private theorem Good.follow {key first second lw rw lt rt}
    (left : Good key first lw lt)
    (right : Good (advanceKey key first) second rw rt) :
    Good key (first + second) (lw ++ rw) (lt ++ rt) := by
  apply left.append right (Or.inl (by simp [advanceKey]))
  · intro k h; simp only [KeyWithin] at *; exact ⟨h.1, h.2.1, by omega⟩
  · intro k h; simp only [KeyWithin, advanceKey] at *; exact ⟨h.1, by omega, by omega⟩

private theorem Good.parent {key size warnings trace}
    (good : Good (childKey key []) size warnings trace) :
    Good key (1 + size) warnings trace := by
  apply good.widen (key' := key) (size' := 1 + size) rfl (by simp [childKey])
  simp only [childKey, List.map_nil, List.sum_nil]
  omega

private theorem Good.root {key size cw ct ow ot}
    (children : Good (childKey key []) size cw ct)
    (own : Good key 1 ow ot) :
    Good key (1 + size) (cw ++ ow) (ct ++ ot) := by
  apply children.append own (Or.inr (by simp [childKey]))
  · intro k h; simp only [KeyWithin, childKey, List.map_nil, List.sum_nil] at *
    exact ⟨h.1, by omega, by omega⟩
  · intro k h; simp only [KeyWithin] at *; exact ⟨h.1, h.2.1, by omega⟩

/-- 幅付き演算の警告は、正常に得た同じ種類の引数を原因どおり拒否する。 -/
theorem widthOwn_warning_sound {key kind} {op : WidthBinary} {left right a b warning}
    (ha : left.Contains (.ofInteger kind a)) (hb : right.Contains (.ofInteger kind b))
    (member : warning ∈ (baseOwnKind key op.op kind left right).warnings) :
    (op.apply kind a b) = .rejected warning.cause.toFailure := by
  have la := BaseApprox.contains_rangeKind kind a ha
  have rb := BaseApprox.contains_rangeKind kind b hb
  cases op with
  | add =>
    change warning ∈ (if addAlwaysOverflows (left.rangeKind kind) (right.rangeKind kind) then
      [⟨key, .binary .add kind.type, .overflow⟩] else []) at member
    split at member
    · rename_i always
      cases List.mem_singleton.mp member
      exact add_always_overflows_sound la rb always
    · contradiction
  | sub =>
    change warning ∈ (if subAlwaysOverflows (left.rangeKind kind) (right.rangeKind kind) then
      [⟨key, .binary .sub kind.type, .overflow⟩] else []) at member
    split at member
    · rename_i always
      cases List.mem_singleton.mp member
      exact sub_always_overflows_sound la rb always
    · contradiction
  | mul =>
    change warning ∈ (if mulAlwaysOverflows (left.rangeKind kind) (right.rangeKind kind) then
      [⟨key, .binary .mul kind.type, .overflow⟩] else []) at member
    split at member
    · rename_i always
      cases List.mem_singleton.mp member
      exact mul_always_overflows_sound la rb always
    · contradiction
  | intDiv =>
    change warning ∈ (if divModAlwaysZero .intDiv (left.rangeKind kind) (right.rangeKind kind) then
      [⟨key, .binary .intDiv kind.type, .zeroDivisor⟩] else []) at member
    split at member
    · rename_i always
      cases List.mem_singleton.mp member
      exact divMod_always_zero_sound la rb always
    · contradiction
  | mod =>
    change warning ∈ (if divModAlwaysZero .mod (left.rangeKind kind) (right.rangeKind kind) then
      [⟨key, .binary .mod kind.type, .zeroDivisor⟩] else []) at member
    split at member
    · rename_i always
      cases List.mem_singleton.mp member
      exact divMod_always_zero_sound la rb always
    · contradiction
  | compare op =>
    have recognized : Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl
    have notAdd : op.binOp ≠ .add := by cases op <;> decide
    have notSub : op.binOp ≠ .sub := by cases op <;> decide
    have notMul : op.binOp ≠ .mul := by cases op <;> decide
    have notDiv : ¬ IntegerDivisionOp op.binOp := by cases op <;> simp [Comparison.binOp, IntegerDivisionOp]
    simp [WidthBinary.op, baseOwnKind, recognized, notAdd, notSub, notMul, notDiv,
      baseBoolean, baseEmpty] at member

theorem widthNegOwn_warning_sound {key kind signed child a warning}
    (ha : child.Contains (.ofInteger kind a))
    (member : warning ∈ (baseNegOwnKind key kind signed child).warnings) :
    kind.checkedNeg signed a = .rejected warning.cause.toFailure := by
  have inside := BaseApprox.contains_rangeKind kind a ha
  simp only [baseNegOwnKind] at member
  split at member
  · rename_i always
    cases List.mem_singleton.mp member
    exact neg_always_overflows_sound signed inside always
  · contradiction

private theorem width_own_absent (key op kind left right) :
    Good key 1 (baseOwnKind key op kind left right).warnings [] := by
  apply Good.emptyTrace
  intro w h
  rw [(baseOwnKind_warning_origin h).1]
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

private theorem width_own_good {key kind} {op : WidthBinary} {left right a b}
    (ha : left.Contains (.ofInteger kind a)) (hb : right.Contains (.ofInteger kind b)) :
    Good key 1 (baseOwnKind key op.op kind left right).warnings
      [⟨key, .binary op.op kind.type, [.ofInteger kind a, .ofInteger kind b], op.apply kind a b⟩] := by
  refine ⟨(width_own_absent key op.op kind left right).1, ?_, ?_⟩
  · intro e h; cases List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro w h e reached
    cases List.mem_singleton.mp reached.1
    exact widthOwn_warning_sound ha hb h

private theorem width_neg_absent (key kind signed child) :
    Good key 1 (baseNegOwnKind key kind signed child).warnings [] := by
  apply Good.emptyTrace
  intro w h
  simp only [baseNegOwnKind] at h
  split at h
  · cases List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · contradiction

private theorem width_neg_good {key kind signed child a}
    (ha : child.Contains (.ofInteger kind a)) :
    Good key 1 (baseNegOwnKind key kind signed child).warnings
      [⟨key, .neg kind.type, [.ofInteger kind a], kind.checkedNeg signed a⟩] := by
  refine ⟨(width_neg_absent key kind signed child).1, ?_, ?_⟩
  · intro e h; cases List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro w h e reached
    cases List.mem_singleton.mp reached.1
    exact widthNegOwn_warning_sound ha h

private theorem Good.widthNegating {key kind signed child tested trace ownTrace}
    (not64 : kind ≠ .integer64)
    (childGood : Good (childKey key []) (surfaceSize child) tested.warnings trace)
    (ownGood : Good key 1 (baseNegOwnKind key kind signed tested).warnings ownTrace) :
    Good key (surfaceSize (.neg kind.type child))
      (baseNeg key kind.type tested).warnings (trace ++ ownTrace) := by
  have all := childGood.root ownGood
  apply Good.subset (by simpa only [surfaceSize_neg] using all)
  intro warning member
  rw [baseNeg_atKind _ _ signed _ not64] at member
  exact List.mem_append.mpr (then_warning member)

private theorem Good.widthBinary {key kind op leftSource rightSource left right lt rt ot}
    (not64 : kind ≠ .integer64)
    (hl : Good (childKey key []) (surfaceSize leftSource) left.warnings lt)
    (hr : Good (childKey key [leftSource]) (surfaceSize rightSource) right.warnings rt)
    (ho : Good key 1 (baseOwnKind key op kind left right).warnings ot) :
    Good key (surfaceSize (.binary op kind.type leftSource rightSource))
      (baseBinary key op kind.type left right).warnings (lt ++ rt ++ ot) := by
  have children := hl.follow (by simpa [advanceKey, childKey] using hr)
  have all := children.root ho
  have full : Good key (surfaceSize (.binary op kind.type leftSource rightSource))
      ((left.warnings ++ right.warnings) ++ (baseOwnKind key op kind left right).warnings)
      (lt ++ rt ++ ot) := by simpa only [surfaceSize_binary, Nat.add_assoc] using all
  apply full.subset
  intro w h
  rw [baseBinary_atKind _ _ _ _ _ not64] at h
  split at h <;> try contradiction
  rcases then_warning h with h | h
  · exact List.mem_append_left _ (List.mem_append_left _ h)
  rcases then_warning h with h | h
  · exact List.mem_append_left _ (List.mem_append_right _ h)
  · exact List.mem_append_right _ h

private theorem own_bounds (key op type left right) {warning}
    (h : warning ∈ (baseOwn key op type left right).warnings) : warning.key = key :=
  (baseOwn_warning_origin h).1

private theorem own_absent (key op type left right) :
    Good key 1 (baseOwn key op type left right).warnings [] := by
  apply Good.emptyTrace
  intro w h; rw [own_bounds key op type left right h]
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

private theorem own_add_good {key left right a b}
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b)) :
    Good key 1 (baseOwn key .add (.base .integer) left right).warnings
      [⟨key, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩] := by
  refine ⟨(own_absent key .add (.base .integer) left right).1, ?_, ?_⟩
  · intro e h; obtain rfl := List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro w h e reached
    change w ∈ (if addAlwaysOverflows left.integer right.integer then
      [⟨key, .binary .add (.base .integer), .overflow⟩] else []) at h
    split at h
    · rename_i always
      obtain rfl := List.mem_singleton.mp h
      obtain rfl := List.mem_singleton.mp reached.1
      exact add_always_overflows_sound ha hb always
    · contradiction

private theorem own_sub_good {key left right a b}
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b)) :
    Good key 1 (baseOwn key .sub (.base .integer) left right).warnings
      [⟨key, .binary .sub (.base .integer), [.integer a, .integer b], checkedSub a b⟩] := by
  refine ⟨(own_absent key .sub (.base .integer) left right).1, ?_, ?_⟩
  · intro e h; obtain rfl := List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro w h e reached
    change w ∈ (if subAlwaysOverflows left.integer right.integer then
      [⟨key, .binary .sub (.base .integer), .overflow⟩] else []) at h
    split at h
    · rename_i always
      obtain rfl := List.mem_singleton.mp h
      obtain rfl := List.mem_singleton.mp reached.1
      exact sub_always_overflows_sound ha hb always
    · contradiction

private theorem own_mul_good {key left right a b}
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b)) :
    Good key 1 (baseOwn key .mul (.base .integer) left right).warnings
      [⟨key, .binary .mul (.base .integer), [.integer a, .integer b], checkedMul a b⟩] := by
  refine ⟨(own_absent key .mul (.base .integer) left right).1, ?_, ?_⟩
  · intro e h; obtain rfl := List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro w h e reached
    change w ∈ (if mulAlwaysOverflows left.integer right.integer then
      [⟨key, .binary .mul (.base .integer), .overflow⟩] else []) at h
    split at h
    · rename_i always
      obtain rfl := List.mem_singleton.mp h
      obtain rfl := List.mem_singleton.mp reached.1
      exact mul_always_overflows_sound ha hb always
    · contradiction

private theorem own_neg_absent (key child) :
    Good key 1 (baseNegOwn key child).warnings [] := by
  apply Good.emptyTrace
  intro w h
  cases negOwn_warning h
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

private theorem own_neg_good {key child a}
    (ha : BaseApprox.Contains child (.integer a)) :
    Good key 1 (baseNegOwn key child).warnings
      [⟨key, .neg (.base .integer), [.integer a], checkedNeg a⟩] := by
  refine ⟨(own_neg_absent key child).1, ?_, ?_⟩
  · intro event member; cases List.mem_singleton.mp member
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro warning member event reached
    simp only [baseNegOwn] at member
    split at member
    · rename_i always
      cases List.mem_singleton.mp member
      cases List.mem_singleton.mp reached.1
      exact neg_always_overflows_sound (by decide) ha always
    · contradiction

/-- 子の事象と負号自身の事象を、重ならない番号範囲で合成する。 -/
private theorem Good.negating {key child tested trace ownTrace}
    (childGood : Good (childKey key []) (surfaceSize child) tested.warnings trace)
    (ownGood : Good key 1 (baseNegOwn key tested).warnings ownTrace) :
    Good key (surfaceSize (.neg (.base .integer) child))
      (baseNeg key (.base .integer) tested).warnings (trace ++ ownTrace) := by
  have all := childGood.root ownGood
  apply Good.subset (by simpa only [surfaceSize_neg] using all)
  intro warning member
  simp only [baseNeg] at member
  exact List.mem_append.mpr (then_warning member)

private theorem own_div_good {key op left right a b} (target : IntegerDivisionOp op)
    (ha : BaseApprox.Contains left (.integer a))
    (hb : BaseApprox.Contains right (.integer b)) :
    Good key 1 (baseOwn key op (.base .integer) left right).warnings
      [⟨key, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩] := by
  refine ⟨(own_absent key op (.base .integer) left right).1, ?_, ?_⟩
  · intro e h; obtain rfl := List.mem_singleton.mp h
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro w h e reached
    have notAdd : op ≠ .add := by rcases target with rfl | rfl <;> decide
    have notSub : op ≠ .sub := by rcases target with rfl | rfl <;> decide
    have notMul : op ≠ .mul := by rcases target with rfl | rfl <;> decide
    simp only [baseOwn, notAdd, notSub, notMul, ↓reduceIte, ite_eq_left target, analyzeDivMod] at h
    split at h
    · rename_i always
      obtain rfl := List.mem_singleton.mp h
      obtain rfl := List.mem_singleton.mp reached.1
      exact divMod_always_zero_sound ha hb always
    · contradiction

private theorem discard_warnings (value : BaseApprox) :
    (baseDiscard value).warnings = value.warnings := by
  unfold baseDiscard baseThen
  split <;> simp [baseUnit, baseEmpty, BaseApprox.abrupt]

private theorem Good.thenFollow {key first second left right lt rt}
    (hl : Good key first left.warnings lt)
    (hr : Good (advanceKey key first) second right.warnings rt) :
    Good key (first + second) (baseThen left right).warnings (lt ++ rt) := by
  apply (hl.follow hr).subset
  intro w h; exact List.mem_append.mpr (then_warning h)

private theorem Good.binary {key op leftSource rightSource left right lt rt ot}
    (hl : Good (childKey key []) (surfaceSize leftSource) left.warnings lt)
    (hr : Good (childKey key [leftSource]) (surfaceSize rightSource) right.warnings rt)
    (ho : Good key 1 (baseOwn key op (.base .integer) left right).warnings ot) :
    Good key (surfaceSize (.binary op (.base .integer) leftSource rightSource))
      (baseBinary key op (.base .integer) left right).warnings (lt ++ rt ++ ot) := by
  have children := hl.follow (by simpa [advanceKey, childKey] using hr)
  have all := children.root ho
  have full : Good key (surfaceSize (.binary op (.base .integer) leftSource rightSource))
      ((left.warnings ++ right.warnings) ++ (baseOwn key op (.base .integer) left right).warnings)
      (lt ++ rt ++ ot) := by simpa only [surfaceSize_binary, Nat.add_assoc] using all
  apply full.subset
  intro w h
  dsimp only [baseBinary] at h
  split at h <;> try contradiction
  rcases then_warning h with h | h
  · exact List.mem_append_left _ (List.mem_append_left _ h)
  · rcases then_warning h with h | h
    · exact List.mem_append_left _ (List.mem_append_right _ h)
    · exact List.mem_append_right _ h

private theorem Good.branch {env condition tested truth run refined key size trace}
    (atEnv : branchEnv env condition tested.boolean truth = some refined)
    (good : Good key size (run refined).warnings trace) :
    Good key size (baseBranch env condition tested truth run).warnings trace := by
  simpa only [baseBranch, atEnv] using good

private theorem Good.shortCircuit {key left right tested continueTruth run lt rt env}
    (hl : Good (childKey key []) (surfaceSize left) tested.warnings lt)
    (hr : Good (childKey key [left]) (surfaceSize right)
      (baseBranch env left tested continueTruth run).warnings rt) :
    Good key (1 + surfaceSize left + surfaceSize right)
      (baseShortCircuit env left tested continueTruth run).warnings (lt ++ rt) := by
  rw [baseShortCircuit_warnings]
  have h := hl.follow (by simpa [advanceKey, childKey] using hr)
  simpa only [Nat.add_assoc] using h.parent

private theorem Good.branches {key condition yes noSize tested yesResult noResult ct yt nt}
    (hc : Good (childKey key []) (surfaceSize condition) tested.warnings ct)
    (hy : Good (childKey key [condition]) (blockSize yes) yesResult.warnings yt)
    (hn : Good (childKey key (condition :: blockChildren yes)) noSize noResult.warnings nt) :
    Good key (1 + surfaceSize condition + blockSize yes + noSize)
      (baseMerge tested yesResult noResult).warnings (ct ++ yt ++ nt) := by
  have hcy := hc.follow (by simpa [advanceKey, childKey] using hy)
  have h := hcy.follow (by simpa [advanceKey, childKey, blockSize, Nat.add_assoc] using hn)
  simpa [baseMerge, baseJoin, List.append_assoc, Nat.add_assoc] using h.parent

private theorem branch_absent {env condition tested truth run key size}
    (bounds : ∀ refined w, w ∈ (run refined).warnings → KeyWithin key size w.key) :
    Good key size (baseBranch env condition tested truth run).warnings [] := by
  apply Good.emptyTrace
  intro w h; obtain ⟨refined, h⟩ := branch_warning h
  exact bounds refined w h

private theorem absent_block (fuel : Nat) (env : AbstractEnv) (condition : Expr)
    (tested : BaseApprox) (truth : Bool) (key : OperationKey) (body : Block) :
    Good key (blockSize body) (baseBranch env condition tested truth
      (fun refined => analyzeBaseBlock fuel refined key body)).warnings [] :=
  branch_absent (fun refined _ h => base_block_warning_bounds fuel refined key body h)

private theorem absent_expr (fuel : Nat) (env : AbstractEnv) (condition : Expr)
    (tested : BaseApprox) (truth : Bool) (key : OperationKey) (source : Expr) :
    Good key (surfaceSize source) (baseBranch env condition tested truth
      (fun refined => analyzeBaseExpr fuel refined key source)).warnings [] :=
  branch_absent (fun refined _ h => base_warning_bounds fuel refined key source h)

private theorem absent_unit (env : AbstractEnv) (condition : Expr) (tested : BaseApprox)
    (truth : Bool) (key : OperationKey) :
    Good key 0 (baseBranch env condition tested truth (fun _ => baseUnit)).warnings [] :=
  branch_absent (by simp [baseUnit, baseEmpty])

private theorem own_compare_good {key op left right a b} :
    Good key 1 (baseOwn key op.binOp (.base .integer) left right).warnings
      [⟨key, .binary op.binOp (.base .integer), [.integer a, .integer b], checkedCompare op a b⟩] := by
  have notAdd : op.binOp ≠ .add := by cases op <;> decide
  have notSub : op.binOp ≠ .sub := by cases op <;> decide
  have notMul : op.binOp ≠ .mul := by cases op <;> decide
  have notDiv : ¬ IntegerDivisionOp op.binOp := by cases op <;> simp [IntegerDivisionOp, Comparison.binOp]
  have recognized : Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl
  simp only [baseOwn, notAdd, notSub, notMul, ↓reduceIte, ite_eq_right notDiv, recognized, Option.isSome_some,
    ↓reduceIte, baseBoolean, baseEmpty]
  refine ⟨by simp, ?_, by simp⟩
  intro e h; obtain rfl := List.mem_singleton.mp h
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

private theorem Good.matching {key source arms tested armResult st atTrace}
    (hs : Good (childKey key []) (surfaceSize source) tested.warnings st)
    (ha : Good (childKey key [source]) (armsSize arms) armResult.warnings atTrace) :
    Good key (surfaceSize (.matchE type source arms)) (baseMatch tested armResult).warnings (st ++ atTrace) := by
  have all := (hs.follow (by simpa [advanceKey, childKey] using ha)).parent
  have full : Good key (surfaceSize (.matchE type source arms))
      (tested.warnings ++ armResult.warnings) (st ++ atTrace) := by
    simpa only [surfaceSize_matchE, Nat.add_assoc] using all
  apply full.subset
  intro w h
  exact List.mem_append.mpr (match_warning h)

private theorem Good.matchingThen {key source arms tested armResult st atTrace type}
    (hs : Good (childKey key []) (surfaceSize source) tested.warnings st)
    (ha : Good (childKey key [source]) (armsSize arms) armResult.warnings atTrace) :
    Good key (surfaceSize (.matchE type source arms))
      (baseThen tested armResult).warnings (st ++ atTrace) := by
  have all := (hs.follow (by simpa [advanceKey, childKey] using ha)).parent
  have full : Good key (surfaceSize (.matchE type source arms))
      (tested.warnings ++ armResult.warnings) (st ++ atTrace) := by
    simpa only [surfaceSize_matchE, Nat.add_assoc] using all
  apply full.subset
  intro w h
  exact List.mem_append.mpr (then_warning h)

private theorem Good.arm {env source normal alts run inner key size trace}
    (entry : matchArmEnv env source (.base .integer) normal alts = some inner)
    (good : Good key size (run inner).warnings trace) :
    Good key size (baseArm env source normal alts run).warnings trace := by
  simpa only [baseKindArm, matchKindArmEnv, baseArm, entry] using good

private theorem Good.absentArm {env source normal alts run key size}
    (absent : ∀ inner, Good key size (run inner).warnings []) :
    Good key size (baseArm env source normal alts run).warnings [] := by
  unfold baseArm
  split
  · exact Good.emptyTrace (by simp [baseEmpty])
  · exact absent _

private theorem Good.kindArm {kind env source normal alts run inner key size trace}
    (entry : matchKindArmEnv env source kind normal alts = some inner)
    (good : Good key size (run inner).warnings trace) :
    Good key size (baseKindArm kind env source normal alts run).warnings trace := by
  simpa only [baseKindArm, entry] using good

private theorem Good.absentKindArm {kind env source normal alts run key size}
    (absent : ∀ inner, Good key size (run inner).warnings []) :
    Good key size (baseKindArm kind env source normal alts run).warnings [] := by
  unfold baseKindArm
  split
  · exact Good.emptyTrace (by simp [baseEmpty])
  · exact absent _

private theorem Good.guarded {key guard body tested branchResult gt bt}
    (hg : Good key (surfaceSize guard) tested.warnings gt)
    (hb : Good (advanceKey key (surfaceSize guard)) (blockSize body) branchResult.warnings bt) :
    Good key (surfaceSize guard + blockSize body)
      (baseMerge tested branchResult baseEmpty).warnings (gt ++ bt) := by
  simpa [baseMerge, baseJoin, baseEmpty] using hg.follow hb

private theorem absent_arm (fuel : Nat) (env source normal key alts guard body) :
    Good key (guardSize guard + blockSize body)
      (baseArm env source normal alts (fun inner =>
        match guard with
        | none => analyzeBaseBlock fuel inner key body
        | some condition =>
          let tested := analyzeBaseExpr fuel inner key condition
          baseMerge tested
            (baseBranch inner condition tested true (fun refined =>
              analyzeBaseBlock fuel refined (advanceKey key (surfaceSize condition)) body)) baseEmpty)).warnings [] := by
  apply Good.absentArm
  intro inner
  cases guard with
  | none =>
      simpa only [guardSize, Option.map_none, Option.getD_none, Nat.zero_add] using
        Good.emptyTrace (fun w h => base_block_warning_bounds fuel inner key body h)
  | some condition =>
      have hg := Good.emptyTrace (fun w h => base_warning_bounds fuel inner key condition h)
      have hb := absent_block fuel inner condition (analyzeBaseExpr fuel inner key condition) true
        (advanceKey key (surfaceSize condition)) body
      simpa [guardSize] using hg.guarded hb
private theorem absent_kindArm (fuel : Nat) (kind : IntKind) (env source normal key alts guard body) :
    Good key (guardSize guard + blockSize body)
      (baseKindArm kind env source normal alts (fun inner =>
        match guard with
        | none => analyzeBaseBlock fuel inner key body
        | some condition =>
          let tested := analyzeBaseExpr fuel inner key condition
          baseMerge tested
            (baseBranch inner condition tested true (fun refined =>
              analyzeBaseBlock fuel refined (advanceKey key (surfaceSize condition)) body)) baseEmpty)).warnings [] := by
  apply Good.absentKindArm
  intro inner
  cases guard with
  | none =>
      simpa only [guardSize, Option.map_none, Option.getD_none, Nat.zero_add] using
        Good.emptyTrace (fun w h => base_block_warning_bounds fuel inner key body h)
  | some condition =>
      have hg := Good.emptyTrace (fun w h => base_warning_bounds fuel inner key condition h)
      have hb := absent_block fuel inner condition (analyzeBaseExpr fuel inner key condition) true
        (advanceKey key (surfaceSize condition)) body
      simpa [guardSize] using hg.guarded hb

/-- Result の未選択の腕は、静的な番号範囲だけを保証する。 -/
private theorem absent_resultArm (fuel : Nat) (env input key alts guard body) :
    Good key (guardSize guard + blockSize body)
      (match guard with
      | none => analyzeBaseBlock fuel (baseResultArmEnv env input alts) key body
      | some condition =>
        let inner := baseResultArmEnv env input alts
        let tested := analyzeBaseExpr fuel inner key condition
        baseMerge tested (baseBranch inner condition tested true (fun refined =>
          analyzeBaseBlock fuel refined (advanceKey key (surfaceSize condition)) body)) baseEmpty).warnings [] := by
  let inner := baseResultArmEnv env input alts
  cases guard with
  | none =>
    simpa only [guardSize, Option.map_none, Option.getD_none, Nat.zero_add] using
      Good.emptyTrace (fun w h => base_block_warning_bounds fuel inner key body h)
  | some condition =>
    have hg := Good.emptyTrace (fun w h => base_warning_bounds fuel inner key condition h)
    have hb := absent_block fuel inner condition (analyzeBaseExpr fuel inner key condition) true
      (advanceKey key (surfaceSize condition)) body
    simpa [guardSize] using hg.guarded hb

private theorem surfaceSize_record (constructor types positions sources) :
    surfaceSize (.record constructor types positions sources) =
      1 + ((exprsChildren sources).map surfaceSize).sum := by
  rw [surfaceSize_children]; rfl

private theorem surfaceSize_recordUpdate (constructor types count positions base sources) :
    surfaceSize (.recordUpdate constructor types count positions base sources) =
      1 + (surfaceSize base + ((exprsChildren sources).map surfaceSize).sum) := by
  rw [surfaceSize_children]; rfl

private theorem preorderSources_length (sources : List Expr) :
    (sources.flatMap surfacePreorder).length = (sources.map surfaceSize).sum := by
  induction sources with
  | nil => rfl
  | cons source rest ih => simp only [List.flatMap_cons, List.length_append, List.map_cons, List.sum_cons, ih, surfaceSize]

@[simp] private theorem baseValuesWith_aggregate_cons (run key source rest) :
    (baseValuesWith run key (source :: rest)).aggregate =
      baseThen (run key source) (baseValuesWith run (advanceKey key (surfaceSize source)) rest).aggregate := by
  rw [baseValuesWith]
  split
  · rfl
  · simp_all [baseThen]

private theorem baseFixedOwn_bounds {binding key positions values warning}
    (member : warning ∈ (baseFixedOwn binding key positions values).warnings) :
    KeyWithin key 1 warning.key := by
  obtain ⟨rfl, _⟩ := baseFixedOwn_warning member
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

private theorem baseFixedOwn_good {binding key positions approxs values arguments result}
    (models : ValuesModels approxs values)
    (ordered : orderArguments positions values = some arguments)
    (evaluated : EvalStandard binding.rule key arguments result) :
    Good key 1 (baseFixedOwn binding key positions approxs).warnings
      [⟨key, .standard binding, arguments, result⟩] := by
  refine ⟨fun _ member => baseFixedOwn_bounds member, ?_, ?_⟩
  · intro event member
    cases List.mem_singleton.mp member
    exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
  · intro warning member event reached
    obtain ⟨rfl, outside⟩ := baseFixedOwn_warning member
    cases List.mem_singleton.mp reached.1
    exact baseFixedOutside_reject outside models ordered evaluated

private theorem Good.callChildren {key callee labels positions sources cw ct ow ot}
    (args : Good (childKey key [callee]) ((exprsChildren sources).map surfaceSize).sum cw ct)
    (own : Good key 1 ow ot) :
    Good key (surfaceSize (.call callee labels positions sources)) (cw ++ ow) (ct ++ ot) := by
  have widened : Good (childKey key [])
      (surfaceSize callee + ((exprsChildren sources).map surfaceSize).sum) cw ct := by
    apply args.widen (key' := childKey key []) rfl
    · simp [childKey]
    · simp [childKey, Nat.add_assoc]
  simpa only [surfaceSize_children, Interval.children, List.map_cons, List.sum_cons, List.append_nil] using
    widened.root own

private theorem baseValuesWith_good {run : OperationKey → Expr → BaseApprox} {abstract concrete key sources types outcome trace}
    (located : ∀ key source warning, warning ∈ (run key source).warnings →
      LocatedList abstract key (surfacePreorder source) warning)
    (children : ∀ input outcome trace, EvalPartial concrete input outcome trace →
      Good input.key (surfaceSize input.source) (run input.key input.source).warnings trace)
    (eval : EvalTypedArguments concrete key sources types outcome trace) :
    Good key (sources.map surfaceSize).sum (baseValuesWith run key sources).aggregate.warnings trace := by
  have lengths (sources : List Expr) :
      (sources.flatMap surfacePreorder).length = (sources.map surfaceSize).sum := by
    induction sources with
    | nil => rfl
    | cons source rest ih => simp only [List.flatMap_cons, List.length_append, List.map_cons, List.sum_cons, ih, surfaceSize]
  induction sources generalizing key types outcome trace with
  | nil => cases eval; exact Good.emptyTrace (by simp [baseValuesWith, baseUnit, baseEmpty])
  | cons source rest ih =>
    rw [baseValuesWith_aggregate_cons]
    cases eval with
    | cons _ _ _ _ _ _ _ _ _ _ head tail
    | tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
      simpa only [List.map_cons, List.sum_cons] using (children _ _ _ head).thenFollow (ih tail)
    | headAbrupt _ _ _ _ _ _ _ _ head abrupt =>
      have absent : Good (advanceKey key (surfaceSize source)) (rest.map surfaceSize).sum
          (baseValuesWith run (advanceKey key (surfaceSize source)) rest).aggregate.warnings [] := by
        apply Good.emptyTrace
        intro warning member
        simpa only [lengths] using located_bounds (baseValuesWith_located located member)
      simpa only [List.map_cons, List.sum_cons, List.append_nil] using (children _ _ _ head).thenFollow absent

set_option maxHeartbeats 800000 in
mutual
/-- 警告と到達記録を同じ部分木で対応させ、警告原因どおりの拒否を示す。 -/
private theorem base_warning_sound (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace) :
    Good input.key (surfaceSize input.source)
      (analyzeBaseExpr fuel abstract input.key input.source).warnings trace := by
  cases fuel with
  | zero => exact Good.noWarnings (eval_trace_keys eval)
  | succ fuel =>
    match eval with
    | .standardCall env key callee labels positions sources binding values arguments result trace recognized children ordered evaluated =>
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding := by
        rw [range_call_at_agrees (input := ⟨.call callee labels positions sources, binding.rule.resultType, key⟩) models]
        exact recognized
      simp only [analyzeBaseExpr, atCall]
      split
      · have all := baseValuesWith_models children (run := analyzeBaseExpr fuel abstract)
          (fun input value trace child => base_normal_sound fuel models rangeRelated child value rfl)
        have argsGood := baseValuesWith_good
          (fun key source warning member => base_warning_located fuel abstract key source member)
          (fun input outcome trace child => base_warning_sound fuel models rangeRelated child) children
        have full := argsGood.callChildren (key := key) (callee := callee) (labels := labels) (positions := positions) (sources := sources) (baseFixedOwn_good all.2 ordered evaluated)
        exact full.subset (fun _ member => List.mem_append.mpr (then_warning member))
      · have argsGood := base_typed_arguments_warning_sound fuel models rangeRelated children
        have rootGood : Good key 1 [] [⟨key, .standard binding, arguments, result⟩] := by
          refine ⟨by simp, ?_, by simp⟩
          intro event member; cases List.mem_singleton.mp member
          exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩
        apply (argsGood.callChildren (key := key) (callee := callee) (labels := labels) (positions := positions) (sources := sources) rootGood).subset
        intro warning member
        rcases then_warning member with h | h
        · exact List.mem_append_left _ h
        · simp only [baseRangeCall_warnings, List.not_mem_nil] at h
    | .standardCallAbrupt env key callee labels positions sources binding outcome trace recognized children abrupt =>
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding := by
        rw [range_call_at_agrees (input := ⟨.call callee labels positions sources, binding.rule.resultType, key⟩) models]
        exact recognized
      simp only [analyzeBaseExpr, atCall]
      split
      · have argsGood := baseValuesWith_good
          (fun key source warning member => base_warning_located fuel abstract key source member)
          (fun input outcome trace child => base_warning_sound fuel models rangeRelated child) children
        have rootGood : Good key 1
            (baseFixedOwn binding key positions
              (baseValuesWith (analyzeBaseExpr fuel abstract) (childKey key [callee]) (exprsChildren sources)).values).warnings [] :=
          Good.emptyTrace (fun _ member => baseFixedOwn_bounds member)
        have full := argsGood.callChildren (key := key) (callee := callee) (labels := labels) (positions := positions) (sources := sources) rootGood
        rw [List.append_nil] at full
        apply full.subset
        intro warning member; exact List.mem_append.mpr (then_warning member)
      · have argsGood := base_typed_arguments_warning_sound fuel models rangeRelated children
        have full := argsGood.widen (key' := key)
          (size' := surfaceSize (.call callee labels positions sources)) rfl
          (by simp [childKey]; omega) (by simp [surfaceSize_children, Interval.children, childKey, Nat.add_assoc])
        apply full.subset
        intro warning member
        rcases then_warning member with h | h
        · exact h
        · simp only [baseRangeCall_warnings, List.not_mem_nil] at h
    | .fixedCallFailed env key callee labels positions sources binding values arguments reason type trace recognized fixed children ordered evaluated =>
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding := by
        rw [range_call_at_agrees (input := ⟨.call callee labels positions sources, type, key⟩) models]
        exact recognized
      have all := baseValuesWith_models children (run := analyzeBaseExpr fuel abstract)
        (fun input value trace child => base_normal_sound fuel models rangeRelated child value rfl)
      have argsGood := baseValuesWith_good
        (fun key source warning member => base_warning_located fuel abstract key source member)
        (fun input outcome trace child => base_warning_sound fuel models rangeRelated child) children
      have full := argsGood.callChildren (key := key) (callee := callee) (labels := labels) (positions := positions) (sources := sources) (baseFixedOwn_good all.2 ordered evaluated)
      have fixed' : fixedBinding binding = true := fixed
      simp only [analyzeBaseExpr, atCall, fixed', ↓reduceIte]
      exact full.subset (fun _ member => List.mem_append.mpr (then_warning member))
    | .fixedCallAbrupt env key callee labels positions sources binding type outcome trace recognized fixed children abrupt =>
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding := by
        rw [range_call_at_agrees (input := ⟨.call callee labels positions sources, type, key⟩) models]
        exact recognized
      have argsGood := baseValuesWith_good
        (fun key source warning member => base_warning_located fuel abstract key source member)
        (fun input outcome trace child => base_warning_sound fuel models rangeRelated child) children
      have rootGood : Good key 1
            (baseFixedOwn binding key positions
              (baseValuesWith (analyzeBaseExpr fuel abstract) (childKey key [callee]) (exprsChildren sources)).values).warnings [] :=
          Good.emptyTrace (fun _ member => baseFixedOwn_bounds member)
      have full := argsGood.callChildren (key := key) (callee := callee) (labels := labels) (positions := positions) (sources := sources) rootGood
      have fixed' : fixedBinding binding = true := fixed
      simp only [analyzeBaseExpr, atCall, fixed', ↓reduceIte]
      rw [List.append_nil] at full
      apply full.subset
      intro warning member; exact List.mem_append.mpr (then_warning member)
    | .unknownNormal _ _ _ unknown _ | .unknownFailed _ _ unknown =>
      rw [unknown_base (fuel + 1) unknown abstract models]
      exact Good.emptyTrace (by simp [baseUnknown])
    | .integer .. | .negInt .. | .boolean .. | .unit .. | .local ..
    | .integer8 .. | .integer16 .. | .integer32 ..
    | .unsignedInteger16 .. | .unsignedInteger32 .. | .unsignedInteger64 ..
    | .negInteger8 .. | .negInteger16 .. | .negInteger32 .. =>
      exact Good.emptyTrace (by simp [analyzeBaseExpr, baseWidthLiteral_warnings, baseInteger, baseBoolean, baseUnit, baseEmpty])
    | .paren _ _ _ _ _ _ child | .returnE _ _ _ _ _ _ _ child
    | .not _ _ _ _ _ child | .notAbrupt _ _ _ _ _ child _ =>
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_paren, surfaceSize_returnE, surfaceSize_not] using
        (base_warning_sound fuel models rangeRelated child).parent
    | .constE _ _ _ _ _ _ child =>
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_constE] using
        (base_warning_sound fuel (abstract := clearLocals abstract) (concrete := { concrete with locals := [] })
          (models_clearLocals models) (ranges_clearLocals abstract concrete) child).parent
    | .block _ _ _ _ _ _ child =>
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_block] using (base_block_warning_sound fuel models rangeRelated child).parent
    | .widthBinary _ _ kind op _ _ a b _ _ not64 el er =>
      exact (base_warning_sound fuel models rangeRelated el).widthBinary not64 (base_warning_sound fuel models rangeRelated er)
        (width_own_good ((base_normal_sound fuel models rangeRelated el) _ rfl)
          ((base_normal_sound fuel models rangeRelated er) _ rfl))
    | .widthNeg _ _ kind _ a _ not64 signed child =>
      simpa only [analyzeBaseExpr] using
        (base_warning_sound fuel models rangeRelated child).widthNegating not64
          (width_neg_good ((base_normal_sound fuel models rangeRelated child) _ rfl))
    | .widthNegAbrupt _ _ kind _ _ _ not64 signed child _ =>
      simpa only [analyzeBaseExpr, List.append_nil] using
        (base_warning_sound fuel models rangeRelated child).widthNegating not64 (width_neg_absent _ _ signed _)
    | .widthBinaryLeftAbrupt _ key kind op left right _ _ not64 child _ =>
      have hr := Good.emptyTrace (fun w h => base_warning_bounds fuel abstract (childKey key [left]) right h)
      simpa only [analyzeBaseExpr, List.append_nil] using
        (base_warning_sound fuel models rangeRelated child).widthBinary not64 hr (width_own_absent _ _ _ _ _)
    | .widthBinaryRightAbrupt _ _ kind op _ _ _ _ _ _ not64 el er _ =>
      simpa only [analyzeBaseExpr, List.append_nil] using
        (base_warning_sound fuel models rangeRelated el).widthBinary not64 (base_warning_sound fuel models rangeRelated er)
          (width_own_absent _ _ _ _ _)
    | .add _ _ _ _ _ _ _ _ el er =>
      exact (base_warning_sound fuel models rangeRelated el).binary (base_warning_sound fuel models rangeRelated er)
        (own_add_good ((base_normal_sound fuel models rangeRelated el) _ rfl)
          ((base_normal_sound fuel models rangeRelated er) _ rfl))
    | .sub _ _ _ _ _ _ _ _ el er =>
      exact (base_warning_sound fuel models rangeRelated el).binary (base_warning_sound fuel models rangeRelated er)
        (own_sub_good ((base_normal_sound fuel models rangeRelated el) _ rfl)
          ((base_normal_sound fuel models rangeRelated er) _ rfl))
    | .mul _ _ _ _ _ _ _ _ el er =>
      exact (base_warning_sound fuel models rangeRelated el).binary (base_warning_sound fuel models rangeRelated er)
        (own_mul_good ((base_normal_sound fuel models rangeRelated el) _ rfl)
          ((base_normal_sound fuel models rangeRelated er) _ rfl))
    | .neg _ _ _ _ _ child =>
      simpa only [analyzeBaseExpr] using
        (base_warning_sound fuel models rangeRelated child).negating
          (own_neg_good ((base_normal_sound fuel models rangeRelated child) _ rfl))
    | .negAbrupt _ _ _ _ _ child _ =>
      simpa only [analyzeBaseExpr, List.append_nil] using
        (base_warning_sound fuel models rangeRelated child).negating (own_neg_absent _ _)
    | .divMod _ _ _ _ _ _ _ _ _ target el er =>
      exact (base_warning_sound fuel models rangeRelated el).binary (base_warning_sound fuel models rangeRelated er)
        (own_div_good target ((base_normal_sound fuel models rangeRelated el) _ rfl)
          ((base_normal_sound fuel models rangeRelated er) _ rfl))
    | .compare _ _ _ _ _ _ _ _ _ el er =>
      exact (base_warning_sound fuel models rangeRelated el).binary (base_warning_sound fuel models rangeRelated er) own_compare_good
    | .addLeftAbrupt _ key left right _ _ child _ | .subLeftAbrupt _ key left right _ _ child _ | .mulLeftAbrupt _ key left right _ _ child _
    | .divModLeftAbrupt _ key op left right _ _ _ child _
    | .compareLeftAbrupt _ key op left right _ _ child _ =>
      have hr := Good.emptyTrace (fun w h => base_warning_bounds fuel abstract (childKey key [left]) right h)
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, List.append_nil] using (base_warning_sound fuel models rangeRelated child).binary hr (own_absent _ _ _ _ _)
    | .addRightAbrupt _ _ _ _ _ _ _ _ el er _ | .subRightAbrupt _ _ _ _ _ _ _ _ el er _ | .mulRightAbrupt _ _ _ _ _ _ _ _ el er _
    | .divModRightAbrupt _ _ _ _ _ _ _ _ _ _ el er _
    | .compareRightAbrupt _ _ _ _ _ _ _ _ _ el er _ =>
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, List.append_nil] using (base_warning_sound fuel models rangeRelated el).binary
        (base_warning_sound fuel models rangeRelated er) (own_absent _ _ _ _ _)
    | .andRight _ key left right _ _ bt condition branch
    | .orRight _ key left right _ _ bt condition branch =>
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      have hr := Good.branch (run := fun env => analyzeBaseExpr fuel env (childKey key [left]) right)
        atEnv (base_warning_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch)
      simpa only [analyzeBaseExpr, surfaceSize_and, surfaceSize_or] using
        (base_warning_sound fuel models rangeRelated condition).shortCircuit hr
    | .andShort _ key left right _ condition
    | .andAbrupt _ key left right _ _ condition _ =>
      have hr := absent_expr fuel abstract left
        (analyzeBaseExpr fuel abstract (childKey key []) left) true (childKey key [left]) right
      simpa only [analyzeBaseExpr, surfaceSize_and, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).shortCircuit hr
    | .orShort _ key left right _ condition
    | .orAbrupt _ key left right _ _ condition _ =>
      have hr := absent_expr fuel abstract left
        (analyzeBaseExpr fuel abstract (childKey key []) left) false (childKey key [left]) right
      simpa only [analyzeBaseExpr, surfaceSize_or, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).shortCircuit hr
    | .matchInteger _ key source arms _ integer _ _ _ child selected =>
      have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
      have rangeAbsent := range_match_at_integer_none (kind := .integer64) models rangeRelated child (arms := arms)
      simp only [analyzeBaseExpr, rangeAbsent]
      change Good _ _ (baseMatchKind _ _).warnings _
      unfold baseMatchKind
      cases known : (analyzeBaseExpr fuel abstract (childKey key []) source).matchKind with
      | none =>
        exact (base_warning_sound fuel models rangeRelated child).matchingThen
          (Good.noWarnings (arms_trace_keys selected))
      | some kind =>
        have same := matchKind_contains (actual := .integer64) inside known
        subst kind
        exact (base_warning_sound fuel models rangeRelated child).matchingThen
          (base_arms_warning_sound fuel models rangeRelated child inside selected)
    | .matchWidth _ key kind source arms _ integer _ _ _ not64 child selected =>
      have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
      have rangeAbsent := range_match_at_integer_none models rangeRelated child (arms := arms)
      simp only [analyzeBaseExpr, rangeAbsent]
      change Good _ _ (baseMatchKind _ _).warnings _
      unfold baseMatchKind
      cases known : (analyzeBaseExpr fuel abstract (childKey key []) source).matchKind with
      | none =>
        exact (base_warning_sound fuel models rangeRelated child).matchingThen
          (Good.noWarnings (widthArms_trace_keys selected))
      | some chosen =>
        have same := matchKind_contains inside known
        subst chosen
        exact (base_warning_sound fuel models rangeRelated child).matchingThen
          (base_widthArms_warning_sound fuel kind not64 models rangeRelated child
            (BaseApprox.contains_rangeKind kind integer inside) selected)
    | .matchResult _ key source arms type sourceType result names tag payload outcome st armTrace matched view child selected =>
      cases recognized : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms with
      | none =>
        have inside := (base_normal_sound fuel models rangeRelated child) _ rfl
        have fallback := noninteger_matchKind_none inside (range_result_view_noninteger view)
        simp only [analyzeBaseExpr, recognized, baseMatchKind, fallback]
        exact (base_warning_sound fuel models rangeRelated child).matchingThen
          (Good.noWarnings (resultArms_trace_keys selected))
      | some origin =>
        have recognizedActual : rangeMatchAt abstract ⟨source, sourceType, childKey key []⟩ arms = some origin := by
          exact (range_match_at_type abstract ⟨source, sourceType, childKey key []⟩ (.base .unit) arms).symm.trans recognized
        have actual := range_match_at_evaluated models rangeRelated recognizedActual child
        have same : names = origin.names := Option.some.inj (matched.symm.trans actual)
        subst names
        simp only [analyzeBaseExpr, recognized]
        have armGood := base_resultArms_warning_sound fuel models rangeRelated recognizedActual child actual view selected
        rw [← analyzeBaseResultArms_type fuel abstract ⟨source, sourceType, childKey key []⟩
          (.base .unit) (childKey key [source]) arms] at armGood
        exact (base_warning_sound fuel models rangeRelated child).matchingThen armGood
    | .matchAbrupt _ key source arms _ _ _ _ child _
    | .matchOtherNormal _ key source arms _ _ _ _ _ child _ _ _
    | .matchOtherFailed _ key source arms _ _ _ _ child _ _ =>
      cases recognized : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms with
      | some origin =>
        simp only [analyzeBaseExpr, recognized]
        have absent := Good.emptyTrace (fun w h => base_resultArms_warning_bounds fuel abstract
          ⟨source, .base .unit, childKey key []⟩ (childKey key [source]) arms h)
        simpa only [List.append_nil] using (base_warning_sound fuel models rangeRelated child).matchingThen absent
      | none =>
        simp only [analyzeBaseExpr, recognized]
        change Good _ _ (baseMatchKind _ _).warnings _
        unfold baseMatchKind
        cases known : (analyzeBaseExpr fuel abstract (childKey key []) source).matchKind with
        | none =>
          simpa only [List.append_nil] using
            (base_warning_sound fuel models rangeRelated child).matchingThen
              (Good.emptyTrace (by simp [baseUnknown]))
        | some kind =>
          have absent := Good.emptyTrace (fun w h => base_kindArms_warning_bounds fuel kind abstract source
            ((analyzeBaseExpr fuel abstract (childKey key []) source).rangeKind kind)
            (childKey key [source]) arms h)
          simpa only [List.append_nil] using (base_warning_sound fuel models rangeRelated child).matchingThen absent
    | .iteTrue _ key cond yes no _ _ ct bt condition branch =>
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      have hy : Good (childKey key [cond]) (blockSize yes)
          (baseBranch abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
            (fun env => analyzeBaseBlock fuel env (childKey key [cond]) yes)).warnings bt := by
        simpa only [analyzeBaseExpr, BaseApprox.abrupt, baseBranch, atEnv] using base_block_warning_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch
      have hn := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes)) no
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_ite, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .elseIfTrue _ key cond yes no _ _ ct bt condition branch =>
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      have hy : Good (childKey key [cond]) (blockSize yes)
          (baseBranch abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
            (fun env => analyzeBaseBlock fuel env (childKey key [cond]) yes)).warnings bt := by
        simpa only [analyzeBaseExpr, BaseApprox.abrupt, baseBranch, atEnv] using base_block_warning_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch
      have hn := absent_expr fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes)) no
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_elseIf, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .iteFalse _ key cond yes no _ _ ct bt condition branch =>
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      have hn : Good (childKey key (cond :: blockChildren yes)) (blockSize no)
          (baseBranch abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
            (fun env => analyzeBaseBlock fuel env (childKey key (cond :: blockChildren yes)) no)).warnings bt := by
        simpa only [analyzeBaseExpr, BaseApprox.abrupt, baseBranch, atEnv] using base_block_warning_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch
      have hy := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
        (childKey key [cond]) yes
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_ite, List.append_nil, List.nil_append] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .elseIfFalse _ key cond yes no _ _ ct bt condition branch =>
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      have hn : Good (childKey key (cond :: blockChildren yes)) (surfaceSize no)
          (baseBranch abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
            (fun env => analyzeBaseExpr fuel env (childKey key (cond :: blockChildren yes)) no)).warnings bt := by
        simpa only [analyzeBaseExpr, BaseApprox.abrupt, baseBranch, atEnv] using base_warning_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch
      have hy := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
        (childKey key [cond]) yes
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_elseIf, List.append_nil, List.nil_append] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .ifOnlyTrue _ key cond yes _ ct bt condition branch =>
      obtain ⟨refined, atEnv, related⟩ := branch_models models condition
        ((base_normal_sound fuel models rangeRelated condition) _ rfl)
      have hy : Good (childKey key [cond]) (blockSize yes)
          (baseBranch abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
            (fun env => analyzeBaseBlock fuel env (childKey key [cond]) yes)).warnings bt := by
        simpa only [analyzeBaseExpr, BaseApprox.abrupt, baseBranch, atEnv] using base_block_warning_sound fuel related (ranges_branchEnv rangeRelated atEnv) branch
      have hn := absent_unit abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes))
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_ifOnly, Nat.add_zero, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .ifOnlyFalse _ key cond yes _ condition =>
      have hy := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
        (childKey key [cond]) yes
      have hn := absent_unit abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes))
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_ifOnly, Nat.add_zero, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .iteAbrupt _ key cond yes no _ _ _ condition _ =>
      have hy := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
        (childKey key [cond]) yes
      have hn := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes)) no
      simpa only [analyzeBaseExpr, surfaceSize_ite, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .elseIfAbrupt _ key cond yes no _ _ _ condition _ =>
      have hy := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
        (childKey key [cond]) yes
      have hn := absent_expr fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes)) no
      simpa only [analyzeBaseExpr, surfaceSize_elseIf, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn
    | .ifOnlyAbrupt _ key cond yes _ _ condition _ =>
      have hy := absent_block fuel abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) true
        (childKey key [cond]) yes
      have hn := absent_unit abstract cond (analyzeBaseExpr fuel abstract (childKey key []) cond) false
        (childKey key (cond :: blockChildren yes))
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, surfaceSize_ifOnly, Nat.add_zero, List.append_nil] using
        (base_warning_sound fuel models rangeRelated condition).branches hy hn

/-- Blockの途中の失敗・returnと未実行の続きも、番号範囲を分けて合成する。 -/
private theorem base_block_warning_sound (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace) :
    Good key (blockSize body) (analyzeBaseBlock fuel abstract key body).warnings trace := by
  cases fuel with
  | zero => exact Good.noWarnings (block_trace_keys eval)
  | succ fuel =>
    match eval with
    | .empty .. => exact Good.emptyTrace (by simp [analyzeBaseBlock, baseUnit, baseEmpty])
    | .builderBind _ _ _ _ _ _ _ child =>
      exact base_block_warning_sound fuel (models_extend models (value := none) trivial) (ranges_extend rangeRelated none) child
    | .last _ _ _ _ _ _ child =>
      simpa [analyzeBaseBlock, blockSize, blockChildren] using base_warning_sound fuel models rangeRelated child
    | .lastBind _ _ _ _ _ _ _ child | .lastDiscard _ _ _ _ _ _ child
    | .lastPat _ _ _ _ _ _ _ _ child =>
      simpa only [analyzeBaseExpr, BaseApprox.abrupt, analyzeBaseBlock, discard_warnings, blockSize, blockChildren, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, Nat.add_zero] using base_warning_sound fuel models rangeRelated child
    | .bind _ key kind boundType source rest _ boundValue _ _ _ head tail =>
      have inside := (base_normal_sound fuel models rangeRelated head) _ rfl
      have related : Models
          (baseBindSource kind abstract boundType (analyzeBaseExpr fuel abstract key source) ⟨source, boundType, key⟩)
          { concrete with locals := some boundValue :: concrete.locals } := by
        exact bind_models kind models (eval_normal_typed head) inside
      have innerRanges := range_save_result_of_eval models rangeRelated head
      simpa [analyzeBaseBlock, blockSize, blockChildren] using
        (base_warning_sound fuel models rangeRelated head).thenFollow (base_block_warning_sound fuel related innerRanges tail)
    | .discard _ _ _ _ _ _ _ _ _ _ head tail | .seq _ _ _ _ _ _ _ _ _ head tail =>
      simpa [analyzeBaseBlock, blockSize, blockChildren] using
        (base_warning_sound fuel models rangeRelated head).thenFollow (base_block_warning_sound fuel models rangeRelated tail)
    | .bindPat _ _ _ pattern boundType _ _ _ _ _ _ _ _ head bindings tail =>
      have related := pattern_models models (eval_normal_typed head) bindings
      have innerRanges := pattern_ranges (type := boundType) rangeRelated bindings
      simpa [analyzeBaseBlock, blockSize, blockChildren] using
        (base_warning_sound fuel models rangeRelated head).thenFollow (base_block_warning_sound fuel related innerRanges tail)
    | .bindAbrupt _ key kind type source rest _ _ _ head _ =>
      have tail : Good (advanceKey key (surfaceSize source)) (blockSize rest)
          (analyzeBaseBlock fuel (baseBindSource kind abstract type (analyzeBaseExpr fuel abstract key source) ⟨source, type, key⟩) (advanceKey key (surfaceSize source)) rest).warnings [] :=
        Good.emptyTrace (fun w h => base_block_warning_bounds fuel (baseBindSource kind abstract type (analyzeBaseExpr fuel abstract key source) ⟨source, type, key⟩) _ rest h)
      simpa only [analyzeBaseBlock, blockSize, blockChildren, List.map_cons, List.sum_cons,
        List.append_nil] using (base_warning_sound fuel models rangeRelated head).thenFollow tail
    | .discardAbrupt _ key source rest _ _ _ _ head _
    | .seqAbrupt _ key source rest _ _ _ head _ =>
      have tail : Good (advanceKey key (surfaceSize source)) (blockSize rest)
          (analyzeBaseBlock fuel abstract (advanceKey key (surfaceSize source)) rest).warnings [] :=
        Good.emptyTrace (fun w h => base_block_warning_bounds fuel abstract _ rest h)
      simpa only [analyzeBaseBlock, blockSize, blockChildren, List.map_cons, List.sum_cons,
        List.append_nil] using (base_warning_sound fuel models rangeRelated head).thenFollow tail
    | .bindPatAbrupt _ key kind pattern type source rest _ _ _ head _ =>
      have tail : Good (advanceKey key (surfaceSize source)) (blockSize rest)
          (analyzeBaseBlock fuel (extendPattern abstract pattern type) (advanceKey key (surfaceSize source)) rest).warnings [] :=
        Good.emptyTrace (fun w h => base_block_warning_bounds fuel (extendPattern abstract pattern type) _ rest h)
      simpa only [analyzeBaseBlock, blockSize, blockChildren, List.map_cons, List.sum_cons,
        List.append_nil] using (base_warning_sound fuel models rangeRelated head).thenFollow tail

/-- 腕内の事象と未実行部分の警告は、互いに重ならない範囲で合成する。 -/
private theorem base_arms_warning_sound (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseArms fuel abstract source normal key arms).warnings trace := by
  cases fuel with
  | zero => exact Good.noWarnings (arms_trace_keys eval)
  | succ fuel =>
    match eval with
    | .nil .. => exact Good.emptyTrace (by simp [analyzeBaseArms, analyzeBaseKindArms, baseKindArm, matchKindArmEnv, baseArm, baseEmpty])
    | .skip _ _ _ alts guard body rest _ _ _ _ tail =>
      have ha := absent_arm fuel abstract source normal key alts guard body
      have ht := base_arms_warning_sound fuel models rangeRelated scrutinee inside tail
      simpa only [analyzeBaseArms, analyzeBaseKindArms, baseKindArm, matchKindArmEnv, baseArm, baseJoin, armsSize_cons, List.nil_append, Nat.add_assoc] using ha.follow ht
    | .body _ _ _ alts body rest _ _ _ _ selection branch =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models rangeRelated scrutinee inside selection entry
      have ha := Good.arm (run := fun inner => analyzeBaseBlock fuel inner key body)
        entry (base_block_warning_sound fuel related innerRanges branch)
      have ht := Good.emptyTrace (fun w h => base_arms_warning_bounds fuel abstract source normal
        (advanceKey key (blockSize body)) rest h)
      simpa only [analyzeBaseArms, analyzeBaseKindArms, baseKindArm, matchKindArmEnv, baseArm, baseJoin, armsSize_cons, guardSize, Option.map_none,
        Option.getD_none, Nat.zero_add, List.append_nil] using ha.follow ht
    | .guardTrue _ _ _ alts guard body rest _ _ _ _ _ selection condition branch =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models rangeRelated scrutinee inside selection entry
      obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition
        ((base_normal_sound fuel related innerRanges condition) _ rfl)
      have hb := Good.branch (run := fun refined => analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)
        atEnv (base_block_warning_sound fuel modeled (ranges_branchEnv innerRanges atEnv) branch)
      have ha := Good.arm (run := fun inner =>
        baseMerge (analyzeBaseExpr fuel inner key guard)
          (baseBranch inner guard (analyzeBaseExpr fuel inner key guard) true (fun refined =>
            analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)) baseEmpty)
        entry ((base_warning_sound fuel related innerRanges condition).guarded hb)
      have ht := Good.emptyTrace (fun w h => base_arms_warning_bounds fuel abstract source normal
        (advanceKey key (surfaceSize guard + blockSize body)) rest h)
      simpa only [analyzeBaseArms, analyzeBaseKindArms, baseKindArm, matchKindArmEnv, baseArm, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht
    | .guardFalse _ _ _ alts guard body rest _ _ _ _ _ selection condition tail =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models rangeRelated scrutinee inside selection entry
      have hb := absent_block fuel inner guard (analyzeBaseExpr fuel inner key guard) true
        (advanceKey key (surfaceSize guard)) body
      have ha := Good.arm (run := fun inner =>
        baseMerge (analyzeBaseExpr fuel inner key guard)
          (baseBranch inner guard (analyzeBaseExpr fuel inner key guard) true (fun refined =>
            analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)) baseEmpty)
        entry ((base_warning_sound fuel related innerRanges condition).guarded hb)
      have ht := base_arms_warning_sound fuel models rangeRelated scrutinee inside tail
      simpa only [analyzeBaseArms, analyzeBaseKindArms, baseKindArm, matchKindArmEnv, baseArm, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht
    | .guardAbrupt _ _ _ alts guard body rest _ _ _ _ selection condition _ =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models rangeRelated scrutinee inside selection entry
      have hb := absent_block fuel inner guard (analyzeBaseExpr fuel inner key guard) true
        (advanceKey key (surfaceSize guard)) body
      have ha := Good.arm (run := fun inner =>
        baseMerge (analyzeBaseExpr fuel inner key guard)
          (baseBranch inner guard (analyzeBaseExpr fuel inner key guard) true (fun refined =>
            analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)) baseEmpty)
        entry ((base_warning_sound fuel related innerRanges condition).guarded hb)
      have ht := Good.emptyTrace (fun w h => base_arms_warning_bounds fuel abstract source normal
        (advanceKey key (surfaceSize guard + blockSize body)) rest h)
      simpa only [analyzeBaseArms, analyzeBaseKindArms, baseKindArm, matchKindArmEnv, baseArm, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht

private theorem base_widthArms_warning_sound (fuel : Nat) (kind : IntKind)
    {abstract concrete source key scrutineeKey arms type outcome trace st}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64) (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseKindArms fuel kind abstract source normal key arms).warnings trace := by
  cases fuel with
  | zero => exact Good.noWarnings (widthArms_trace_keys eval)
  | succ fuel =>
    match eval with
    | .nil .. => exact Good.emptyTrace (by simp [analyzeBaseKindArms, baseEmpty])
    | .skip _ _ _ _ alts guard body rest _ _ _ _ tail =>
      have ha := absent_kindArm fuel kind abstract source normal key alts guard body
      have ht := base_widthArms_warning_sound fuel kind not64 models rangeRelated scrutinee inside tail
      simpa only [analyzeBaseKindArms, baseJoin, armsSize_cons, List.nil_append, Nat.add_assoc] using ha.follow ht
    | .body _ _ _ _ alts body rest _ _ _ _ selection branch =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models rangeRelated scrutinee inside selection not64 entry
      have ha := Good.kindArm (run := fun inner => analyzeBaseBlock fuel inner key body)
        entry (base_block_warning_sound fuel related innerRanges branch)
      have ht := Good.emptyTrace (fun w h => base_kindArms_warning_bounds fuel kind abstract source normal
        (advanceKey key (blockSize body)) rest h)
      simpa only [analyzeBaseKindArms, baseJoin, armsSize_cons, guardSize, Option.map_none,
        Option.getD_none, Nat.zero_add, List.append_nil] using ha.follow ht
    | .guardTrue _ _ _ _ alts guard body rest _ _ _ _ _ selection condition branch =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models rangeRelated scrutinee inside selection not64 entry
      obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition
        ((base_normal_sound fuel related innerRanges condition) _ rfl)
      have hb := Good.branch (run := fun refined => analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)
        atEnv (base_block_warning_sound fuel modeled (ranges_branchEnv innerRanges atEnv) branch)
      have ha := Good.kindArm (run := fun inner =>
        baseMerge (analyzeBaseExpr fuel inner key guard)
          (baseBranch inner guard (analyzeBaseExpr fuel inner key guard) true (fun refined =>
            analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)) baseEmpty)
        entry ((base_warning_sound fuel related innerRanges condition).guarded hb)
      have ht := Good.emptyTrace (fun w h => base_kindArms_warning_bounds fuel kind abstract source normal
        (advanceKey key (surfaceSize guard + blockSize body)) rest h)
      simpa only [analyzeBaseKindArms, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht
    | .guardFalse _ _ _ _ alts guard body rest _ _ _ _ _ selection condition tail =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models rangeRelated scrutinee inside selection not64 entry
      have hb := absent_block fuel inner guard (analyzeBaseExpr fuel inner key guard) true
        (advanceKey key (surfaceSize guard)) body
      have ha := Good.kindArm (run := fun inner =>
        baseMerge (analyzeBaseExpr fuel inner key guard)
          (baseBranch inner guard (analyzeBaseExpr fuel inner key guard) true (fun refined =>
            analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)) baseEmpty)
        entry ((base_warning_sound fuel related innerRanges condition).guarded hb)
      have ht := base_widthArms_warning_sound fuel kind not64 models rangeRelated scrutinee inside tail
      simpa only [analyzeBaseKindArms, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht
    | .guardAbrupt _ _ _ _ alts guard body rest _ _ _ _ selection condition _ =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models rangeRelated scrutinee inside selection not64 entry
      have hb := absent_block fuel inner guard (analyzeBaseExpr fuel inner key guard) true
        (advanceKey key (surfaceSize guard)) body
      have ha := Good.kindArm (run := fun inner =>
        baseMerge (analyzeBaseExpr fuel inner key guard)
          (baseBranch inner guard (analyzeBaseExpr fuel inner key guard) true (fun refined =>
            analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)) baseEmpty)
        entry ((base_warning_sound fuel related innerRanges condition).guarded hb)
      have ht := Good.emptyTrace (fun w h => base_kindArms_warning_bounds fuel kind abstract source normal
        (advanceKey key (surfaceSize guard + blockSize body)) rest h)
      simpa only [analyzeBaseKindArms, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht

/-- 引数列の警告は、評価された接頭辞と未実行の残りを分けて保存する。 -/
private theorem base_typed_arguments_warning_sound (fuel : Nat) {abstract concrete key sources types outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalTypedArguments concrete key sources types outcome trace) :
    Good key (sources.map surfaceSize).sum (analyzeBaseArguments fuel abstract key sources).warnings trace := by
  cases fuel with
  | zero => exact Good.noWarnings (typed_arguments_trace_keys eval)
  | succ fuel =>
    match eval with
    | .nil .. => exact Good.emptyTrace (by simp [analyzeBaseArguments, baseUnit, baseEmpty])
    | .cons _ _ _ _ _ _ _ _ _ _ head tail
    | .tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
      simpa only [analyzeBaseArguments, List.map_cons, List.sum_cons] using
        (base_warning_sound fuel models rangeRelated head).thenFollow
          (base_typed_arguments_warning_sound fuel models rangeRelated tail)
    | .headAbrupt _ key source rest _ _ _ _ head _ =>
      have absent := Good.emptyTrace (fun w h => base_arguments_warning_bounds fuel abstract
        (advanceKey key (surfaceSize source)) rest h)
      simpa only [analyzeBaseArguments, List.map_cons, List.sum_cons, List.append_nil] using
        (base_warning_sound fuel models rangeRelated head).thenFollow absent

/-- Result の選ばれた腕と未選択の腕も、番号の範囲を分けて警告を合成する。 -/
private theorem base_resultArms_warning_sound (fuel : Nat)
    {abstract concrete input arms origin result tag payload key type outcome trace st}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (recognized : rangeMatchAt abstract input arms = some origin)
    (scrutinee : EvalPartial concrete input (.normal result) st)
    (matched : rangeResultMatch concrete result arms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (eval : EvalResultArms concrete key origin.names result tag payload arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseResultArms fuel abstract input key arms).warnings trace := by
  cases fuel with
  | zero => exact Good.noWarnings (resultArms_trace_keys eval)
  | succ fuel =>
    match eval with
    | .nil .. => exact Good.emptyTrace (by simp [analyzeBaseResultArms, baseEmpty])
    | .skip _ _ _ _ _ _ alts guard body rest _ _ _ _ tail =>
      have ha := absent_resultArm fuel abstract input key alts guard body
      have nextRecognized := range_match_at_tail recognized
      have nextMatched := range_match_at_evaluated models rangeRelated nextRecognized scrutinee
      have ht := base_resultArms_warning_sound fuel models rangeRelated nextRecognized scrutinee nextMatched view tail
      simpa only [analyzeBaseResultArms, baseJoin, armsSize_cons, List.nil_append, Nat.add_assoc] using ha.follow ht
    | .body _ _ _ _ _ _ alts body rest _ _ _ _ selection branch =>
      let inner := baseResultArmEnv abstract input alts
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have innerRanges := baseResultArmEnv_ranges models rangeRelated recognized scrutinee matched view selection
      have ha := base_block_warning_sound fuel innerModels innerRanges branch
      have ht := Good.emptyTrace (fun w h => base_resultArms_warning_bounds fuel abstract input
        (advanceKey key (blockSize body)) rest h)
      simpa only [analyzeBaseResultArms, baseJoin, armsSize_cons, guardSize, Option.map_none,
        Option.getD_none, Nat.zero_add, List.append_nil] using ha.follow ht
    | .guardTrue _ _ _ _ _ _ alts guard body rest _ _ _ _ _ selection condition branch =>
      let inner := baseResultArmEnv abstract input alts
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have innerRanges := baseResultArmEnv_ranges models rangeRelated recognized scrutinee matched view selection
      obtain ⟨refined, atEnv, modeled⟩ := branch_models innerModels condition
        (base_normal_sound fuel innerModels innerRanges condition _ rfl)
      have hb := Good.branch (run := fun refined => analyzeBaseBlock fuel refined (advanceKey key (surfaceSize guard)) body)
        atEnv (base_block_warning_sound fuel modeled (ranges_branchEnv innerRanges atEnv) branch)
      have ha := (base_warning_sound fuel innerModels innerRanges condition).guarded hb
      have ht := Good.emptyTrace (fun w h => base_resultArms_warning_bounds fuel abstract input
        (advanceKey key (surfaceSize guard + blockSize body)) rest h)
      simpa only [analyzeBaseResultArms, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht
    | .guardFalse _ _ _ _ _ _ alts guard body rest _ _ _ _ _ selection condition tail =>
      let inner := baseResultArmEnv abstract input alts
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have innerRanges := baseResultArmEnv_ranges models rangeRelated recognized scrutinee matched view selection
      have hb := absent_block fuel inner guard (analyzeBaseExpr fuel inner key guard) true
        (advanceKey key (surfaceSize guard)) body
      have ha := (base_warning_sound fuel innerModels innerRanges condition).guarded hb
      have nextRecognized := range_match_at_tail recognized
      have nextMatched := range_match_at_evaluated models rangeRelated nextRecognized scrutinee
      have ht := base_resultArms_warning_sound fuel models rangeRelated nextRecognized scrutinee nextMatched view tail
      simpa only [analyzeBaseResultArms, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht
    | .guardAbrupt _ _ _ _ _ _ alts guard body rest _ _ _ _ selection condition _ =>
      let inner := baseResultArmEnv abstract input alts
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have innerRanges := baseResultArmEnv_ranges models rangeRelated recognized scrutinee matched view selection
      have hb := absent_block fuel inner guard (analyzeBaseExpr fuel inner key guard) true
        (advanceKey key (surfaceSize guard)) body
      have ha := (base_warning_sound fuel innerModels innerRanges condition).guarded hb
      have ht := Good.emptyTrace (fun w h => base_resultArms_warning_bounds fuel abstract input
        (advanceKey key (surfaceSize guard + blockSize body)) rest h)
      simpa only [analyzeBaseResultArms, baseJoin, armsSize_cons, guardSize, Option.map_some,
        Option.getD_some, List.append_nil] using ha.follow ht

end

private theorem base_arguments_warning_sound (fuel : Nat) {abstract concrete key sources type outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalArguments concrete key sources type outcome trace) :
    Good key (sources.map surfaceSize).sum (analyzeBaseArguments fuel abstract key sources).warnings trace := by
  exact base_typed_arguments_warning_sound fuel models rangeRelated (arguments_typed eval)


/-- 土台の解析に対する、正常値所属の中心定理。 -/
theorem analyzeBase_normal_sound : NormalSoundness Models analyzeBase := by
  intro abstract concrete input fuel value trace models eval
  exact ⟨eval_normal_typed eval, (base_normal_sound fuel (models_resetRanges models) (ranges_reset_models abstract concrete) eval) value rfl⟩

/-- 土台の解析に対する、警告原因どおりの拒否の中心定理。 -/
theorem analyzeBase_warning_sound : WarningSoundness Models analyzeBase := by
  intro abstract concrete input fuel outcome trace models eval warning warned event reached
  exact (base_warning_sound fuel (models_resetRanges models) (ranges_reset_models abstract concrete) eval).2.2 warning warned event reached

-- 親の除数0と子のあふれを区別し、returnと未選択枝から警告を作らない。
-- 期待する番号と原因は、番号付け関数や局所の解析結果から作らない。
#guard
    let key : OperationKey := ⟨"Example.baseWarnings", 0⟩
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
    let overflow := .binary .add (.base .integer) maximum one
    let inputs : List Expr := [
      .binary .intDiv (.base .integer) (.binary .intDiv (.base .integer) one one) zero,
      .binary .intDiv (.base .integer) overflow zero,
      .binary .intDiv (.base .integer) (.returnE (.base .integer) one) zero,
      .ite (.literal (.boolean false)) (.last overflow) (.last one),
      .elseIf (.literal (.boolean true)) (.last one) overflow,
      .ifOnly (.literal (.boolean false)) (.lastDiscard overflow),
      .binary .sub (.base .integer) overflow one,
      .binary .add (.base .float) overflow one]
    (inputs.map fun source =>
      let result := analyzeBaseExpr 16 (AbstractEnv.ofLocals []) key source
      (result.integer, result.other, result.mayFail,
        result.warnings.map fun w => (w.key.surfacePreorder, w.cause))) =
    [(top, false, true, [(0, WarningCause.zeroDivisor)]),
     (.bottom, false, true, [(1, .overflow)]),
     (.bottom, false, false, []),
     (normalize 1 1, false, false, []),
     (normalize 1 1, false, false, []),
     (.bottom, true, false, []),
     (.bottom, false, true, [(1, .overflow)]),
     (top, true, true, [])]

-- shadowの位置追加後も、比較は元の整数の位置だけを絞る。
-- 正常な偽枝の一点0と、真枝の全域外の加算を独立に固定する。
#guard
    let key : OperationKey := ⟨"Example.baseShadow", 0⟩
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let source : Expr := .block (.bind .shadow (.base .integer)
      (.literal (.integer ⟨9, by decide⟩))
      (.last (.ite (.binary .gt (.base .integer) (.local 1) zero)
        (.last (.binary .add (.base .integer) (.local 1)
          (.literal (.integer ⟨9223372036854775807, by decide⟩)))) (.last (.local 1)))))
    let result := analyzeBaseExpr 16 (AbstractEnv.ofLocals [.integer (normalize 0 2)]) key source
    result.integer = normalize 0 0 ∧ result.mayFail = true ∧
      result.warnings.map (fun w => (w.key.surfacePreorder, w.cause)) = [(6, WarningCause.overflow)]

-- 別名を絞っても元の位置を逆向きに狭めない。真枝で元の位置を返す。
#guard
    let key : OperationKey := ⟨"Example.baseAlias", 0⟩
    let source : Expr := .block (.bind .bind (.base .integer) (.local 0)
      (.last (.ite (.binary .lt (.base .integer) (.local 0)
        (.literal (.integer ⟨0, by decide⟩))) (.last (.local 1)) (.last (.local 0)))))
    let result := analyzeBaseExpr 16 (AbstractEnv.ofLocals [.integer (normalize (-2) 2)]) key source
    result.integer = normalize (-2) 2 ∧ result.warnings = []

-- 実際の正常評価の導出を中心定理へ渡す。深さ0も含む任意の打ち切りを使える。
example (fuel : Nat) :
    let key : OperationKey := ⟨"Example.baseNormal", 0⟩
    let source : Expr := .binary .add (.base .integer)
      (.literal (.integer ⟨1, by decide⟩)) (.literal (.integer ⟨2, by decide⟩))
    (analyzeBase (AbstractEnv.ofLocals []) ⟨source, .base .integer, key⟩ fuel).normal (.integer ⟨3, by decide⟩) := by
  dsimp only
  let concrete : ConcreteEnv := ⟨[], [], fun _ => none⟩
  have eval := EvalPartial.add concrete (⟨"Example.baseNormal", 0⟩ : OperationKey)
    (.literal (.integer ⟨1, by decide⟩)) (.literal (.integer ⟨2, by decide⟩))
    ⟨1, by decide⟩ ⟨2, by decide⟩ [] [] (.integer _ _ _) (.integer _ _ _)

  exact analyzeBase_normal_sound (AbstractEnv.ofLocals []) concrete _ fuel _ _ ⟨.nil, rfl, rfl⟩ eval

-- 短絡した右辺の失敗・警告を除外し、到達した右辺と左辺の失敗を順に保つ。
-- 期待する正常真偽・失敗可能性・警告番号は解析結果から生成しない。
#guard
    let key : OperationKey := ⟨"Example.shortCircuit", 0⟩
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let bad : Expr := .binary .eq (.base .integer)
      (.binary .add (.base .integer)
        (.literal (.integer ⟨9223372036854775807, by decide⟩))
        (.literal (.integer ⟨1, by decide⟩))) zero
    let yes : Expr := .literal (.boolean true)
    let no : Expr := .literal (.boolean false)
    ([Expr.and no bad, .or yes bad, .and yes bad, .or no bad,
      .not (.and no bad), .and bad yes].map fun source =>
        let result := analyzeBaseExpr 16 (AbstractEnv.ofLocals []) key source
        (result.boolean, result.mayFail,
          result.warnings.map fun w => (w.key.surfacePreorder, w.cause))) =
      [((true, false), false, []), ((false, true), false, []),
       ((false, false), true, [(3, WarningCause.overflow)]),
       ((false, false), true, [(3, .overflow)]),
       ((false, true), false, []), ((false, false), true, [(2, .overflow)])]

-- andの真・orの偽を右辺へ渡さない退行は、右辺のあふれ警告を失う。
-- 複合条件の真環境はifにも渡り、否定と未知の条件でも過剰に絞らない。
#guard
    let key : OperationKey := ⟨"Example.shortCircuitEnvironment", 0⟩
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize (-2) 2)])
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let positive : Expr := .binary .gt (.base .integer) (.local 0) zero
    let maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
    let bad : Expr := .binary .eq (.base .integer)
      (.binary .add (.base .integer) (.local 0) maximum) zero
    let unknown : Expr := .funName "Example.unknownCondition" [] []
    ([Expr.and positive bad, .or (.not positive) bad].map fun source =>
      (analyzeBaseExpr 16 env key source).warnings.map fun w => w.cause) =
        [[WarningCause.overflow], [.overflow]] ∧
    (analyzeBaseExpr 16 env key
      (.ite (.and positive (.binary .le (.base .integer) (.local 0)
          (.literal (.integer ⟨1, by decide⟩))))
        (.last (.local 0)) (.last zero))).integer = normalize 0 1 ∧
    (analyzeBaseExpr 16 env key
      (.ite (.and positive unknown) (.last (.local 0)) (.last zero))).integer = normalize 0 2 ∧
    (analyzeBaseExpr 16 env key
      (.ite unknown (.last (.local 0)) (.last zero))).integer = normalize (-2) 2

end Benitoite.Interval
