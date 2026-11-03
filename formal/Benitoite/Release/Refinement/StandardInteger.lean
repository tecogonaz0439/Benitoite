import Benitoite.Release.Refinement.StandardScalar
import Benitoite.Release.Refinement.StandardContracts
import Benitoite.Release.Refinement.NormalResultLeaves

/-! # 幅付き整数の明示変換と標準の正常応答 -/
namespace Benitoite.Release.Refinement.StandardScalar
open Benitoite.Interval

/-- 対象幅へ同じ整数を写す。域外は Option の失敗である。 -/
def integerConvert (k : IntKind) (n : Int) : Option (IntegerValue k) :=
  if h : k.min ≤ n ∧ n ≤ k.max then some ⟨n,h⟩ else none

theorem integerConvert_some (k : IntKind) (n : Int) (v : IntegerValue k) :
    integerConvert k n = some v ↔ v.toInt = n := by
  unfold integerConvert
  split
  · simp only [Option.some.injEq]
    constructor
    · intro h; cases h; rfl
    · intro h; apply Subtype.ext; exact h.symm
  · simp only [reduceCtorEq, false_iff]
    intro h
    exact ‹¬ (k.min ≤ n ∧ n ≤ k.max)› (h ▸ v.property)

private theorem integerConvert_self (k : IntKind) (v : IntegerValue k) :
    integerConvert k v.toInt = some v := (integerConvert_some k v.toInt v).mpr rfl

private theorem integerConvert64_self (v : Benitoite.Release.Integer64Value) :
    integerConvert .integer64 v.toInt = some v := integerConvert_self .integer64 v

theorem integerConvert_none (k : IntKind) (n : Int) :
    integerConvert k n = none ↔ n < k.min ∨ k.max < n := by
  unfold integerConvert
  split <;> simp_all <;> omega

/-- 実変換の成功は、数の同一性と実定数の表現可能性をともに返す。 -/
theorem integerConvert_result (k : IntKind) (n : Int) (v : IntegerValue k)
    (h : integerConvert k n = some v) :
    v.toInt = n ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
      (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? = some (.integer n) := by
  have eq := (integerConvert_some k n v).mp h
  obtain ⟨represented, observed⟩ := NumericContracts.integer_result k v
  exact ⟨eq, represented, eq ▸ observed⟩

/-- u64 以外の整数型から Integer への変換は全域で同じ値を持つ。 -/
theorem integerWiden (k : IntKind) (small : k ≠ .unsignedInteger64) (v : IntegerValue k) :
    ∃ w : IntegerValue .integer64, integerConvert .integer64 v.toInt = some w ∧
      w.toInt = v.toInt := by
  have h := v.toInt_bounds
  have bound : IntKind.integer64.min ≤ v.toInt ∧ v.toInt ≤ IntKind.integer64.max := by
    cases k <;> simp_all [IntKind.min, IntKind.max, IntegerValue.toInt, Benitoite.Release.min64, Benitoite.Release.max64] <;> omega
  exact ⟨⟨v.toInt,bound⟩, (integerConvert_some _ _ _).mpr rfl, rfl⟩

/-- 正常な演算結果だけを値へ移し、拒否を error に残す。 -/
def integerOutcome : OperationResult → Outcome
  | .normal (.integer n) => .val (.const (.integer n))
  | .normal (.integer8 n) => .val (.const (.integer8 n.val))
  | .normal (.integer16 n) => .val (.const (.integer16 n.val))
  | .normal (.integer32 n) => .val (.const (.integer32 n.val))
  | .normal (.unsignedInteger16 n) => .val (.const (.unsignedInteger16 n.val))
  | .normal (.unsignedInteger32 n) => .val (.const (.unsignedInteger32 n.val))
  | .normal (.unsignedInteger64 n) => .val (.const (.unsignedInteger64 n.val))
  | .normal (.boolean b) => .val (.const (.boolean b))
  | .normal _ => .err "unsupported"
  | .rejected .overflow => .err "IntegerOverflow"
  | .rejected .zeroDivisor => .err "DivisionByZero"
  | .rejected _ => .err "ArgumentOutOfDomain"

/-- 七幅の定数の符号と幅を保った応答。 -/
theorem integerOutcome_normal (k : IntKind) (v : IntegerValue k) :
    integerOutcome (.normal (.ofInteger k v)) =
      .val (.const (embedConst (IntegerValue.toConst k v))) := by
  cases k <;> rfl

/-- 標準の加減乗は独立評価と同じ checked 演算を呼ぶ。 -/
def integerBinaryDelta (k : IntKind) (op : WidthBinary) (a b : IntegerValue k) : Outcome :=
  integerOutcome (op.apply k a b)

/-- 同じ正常応答から算術の等式と値の範囲を読む。 -/
theorem integerBinary_reply (k : IntKind) (op : WidthBinary) (a b v : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (h : op.apply k a b = .normal (.ofInteger k v)) :
    integerBinaryDelta k op a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
    (v.toInt = match op with
      | .add => a.toInt + b.toInt
      | .sub => a.toInt - b.toInt
      | _ => a.toInt * b.toInt) ∧
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? = some (.integer v.toInt) := by
  exact ⟨by rw [integerBinaryDelta,h,integerOutcome_normal],
    NumericContracts.binary_normal k op a b v supported h⟩

/-- 標準の負号も同じ符号付き checked 演算を呼ぶ。 -/
def integerNegDelta (k : IntKind) (signed : k.min < 0) (a : IntegerValue k) : Outcome :=
  integerOutcome (k.checkedNeg signed a)

theorem integerNeg_reply (k : IntKind) (signed : k.min < 0) (a v : IntegerValue k)
    (h : k.checkedNeg signed a = .normal (.ofInteger k v)) :
    integerNegDelta k signed a = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
    v.toInt = -a.toInt ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? = some (.integer v.toInt) :=
  ⟨by rw [integerNegDelta,h,integerOutcome_normal], NumericContracts.neg_normal k signed a v h⟩


/-- 変換の失敗を算術の overflow として扱う入口。 -/
def integerChecked (k : IntKind) (n : Int) : OperationResult :=
  match integerConvert k n with
  | some v => .normal (.ofInteger k v)
  | none => .rejected .overflow

theorem integerChecked_normal (k : IntKind) (n : Int) (v : IntegerValue k) :
    integerChecked k n = .normal (.ofInteger k v) ↔ v.toInt = n := by
  unfold integerChecked
  generalize he : integerConvert k n = out
  cases out with
  | none =>
    simp only [reduceCtorEq, false_iff]
    intro h
    have := (integerConvert_some k n v).mpr h
    rw [he] at this
    cases this
  | some w =>
    simp only [OperationResult.normal.injEq, ConcreteValue.ofInteger_inj]
    have hw := (integerConvert_some k n w).mp he
    constructor
    · intro h; cases h; exact hw
    · intro h; apply Subtype.ext; exact hw.trans h.symm

/-- 床除算と床剰余は、切捨ての商・剰余の符号を補正する。 -/
def integerFloorDelta (k : IntKind) (modulo : Bool) (a b : IntegerValue k) : Outcome :=
  if b.toInt = 0 then .err "DivisionByZero" else
    let q := a.toInt.tdiv b.toInt
    let r := a.toInt.tmod b.toInt
    let result := if modulo then
      if r ≠ 0 ∧ ((r < 0) ≠ (b.toInt < 0)) then r + b.toInt else r
    else if r ≠ 0 ∧ ((a.toInt < 0) ≠ (b.toInt < 0)) then q - 1 else q
    integerOutcome (integerChecked k result)

/-- 絶対値の正常枝は数学上の絶対値を同じ幅で返す。 -/
def integerAbsoluteDelta (k : IntKind) (a : IntegerValue k) : Outcome :=
  integerOutcome (integerChecked k (a.toInt.natAbs : Int))

/-- 比較による選択では、元の同じ値を返す。 -/
def integerMinMaxDelta (k : IntKind) (maximum : Bool) (a b : IntegerValue k) : Outcome :=
  .val (.const (embedConst (IntegerValue.toConst k
    (if maximum then (if a.toInt < b.toInt then b else a)
      else (if a.toInt ≤ b.toInt then a else b)))))

/-- 整数の六比較は、整数専用の等号・不等号の原子を使う。 -/
def integerComparePred (op : Comparison) (a b : Term) : Pred :=
  match op with
  | .eq => .eq a b
  | .ne => .not (.eq a b)
  | .lt => .lt a b
  | .le => .le a b
  | .gt => .lt b a
  | .ge => .le b a

def integerCompareDelta (op : Comparison) (a b : Int) : Outcome :=
  .val (.const (.boolean (op.fromEqLt (a == b) (decide (a < b)) (decide (b < a)))))

theorem integerCompare_reply (η : ObservationEnvModel) (op : Comparison) (a b : Int) :
    ∃ value, integerCompareDelta op a b = .val (.const (.boolean value)) ∧
      (integerComparePred op (.integer a) (.integer b)).interpret η = value := by
  refine ⟨_,rfl,?_⟩
  cases op <;> simp [integerComparePred,Pred.interpret,Pred.atomValue,
    integerAs,observeAs,Term.interpret,Observation.sort,Comparison.fromEqLt]
  all_goals
    apply Bool.eq_iff_iff.mpr
    simp only [decide_eq_true_eq, Bool.or_eq_true, beq_iff_eq] <;> omega

/-- 有限幅のビット列は幅を法として読み、符号付きでは同じ符号を復元する。 -/
def integerWrap (k : IntKind) (n : Int) : IntegerValue k :=
  ⟨(n - k.min) % (k.max - k.min + 1) + k.min, by
    have pos : 0 < k.max - k.min + 1 := by have := k.bounds; omega
    have lo := Int.emod_nonneg (n-k.min) (by omega : k.max-k.min+1 ≠ 0)
    have hi := Int.emod_lt_of_pos (n-k.min) pos
    omega⟩

inductive IntegerBits where
  | bitwiseAnd | bitwiseOr | bitwiseExclusiveOr | bitwiseNot
  | shiftLeft | shiftRight | shiftRightUnsigned
  deriving DecidableEq

def integerWidth : IntKind → Nat
  | .integer8 => 8
  | .integer16 | .unsignedInteger16 => 16
  | .integer32 | .unsignedInteger32 => 32
  | .integer64 | .unsignedInteger64 => 64

/-- bitwise は低位の同じビット、shift は count の検査後の同じビットを返す。 -/
def integerBitsDelta (k : IntKind) (op : IntegerBits) (a b : IntegerValue k)
    (count : Int) : Outcome :=
  let shifted := op = .shiftLeft ∨ op = .shiftRight ∨ op = .shiftRightUnsigned
  if shifted ∧ (count < 0 ∨ (integerWidth k : Int) ≤ count) then .err "ArgumentOutOfDomain" else
    let x := (a.toInt % (2 ^ integerWidth k)).toNat
    let y := (b.toInt % (2 ^ integerWidth k)).toNat
    let n : Int := match op with
      | .bitwiseAnd => (x &&& y : Nat)
      | .bitwiseOr => (x ||| y : Nat)
      | .bitwiseExclusiveOr => (x ^^^ y : Nat)
      | .bitwiseNot => (x ^^^ (2 ^ integerWidth k - 1) : Nat)
      | .shiftLeft => a.toInt <<< count.toNat
      | .shiftRight => a.toInt >>> count.toNat
      | .shiftRightUnsigned => (a.toInt % (2 ^ integerWidth k)) >>> count.toNat
    .val (.const (embedConst (IntegerValue.toConst k (integerWrap k n))))

/-- 任意の正常な幅付き整数の応答を、値の型付けへ直接渡す。 -/
theorem integer_result_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (k : IntKind) (v : IntegerValue k) :
    HasTypeVQ P B Ψ Q C Γ Φ (.const (embedConst (IntegerValue.toConst k v)))
      (embedConst (IntegerValue.toConst k v)).type := by
  apply HasTypeVQ.V_Const
  have h := v.toInt_bounds
  cases k <;> first | exact trivial | simpa [IntegerValue.toConst, embedConst, ConstOK,
    IntKind.min,IntKind.max,IntegerValue.toInt,Benitoite.Release.min64,Benitoite.Release.max64] using h

private def integerKinds : List IntKind :=
  [.integer8,.integer16,.integer32,.integer64,.unsignedInteger16,.unsignedInteger32,.unsignedInteger64]

/-- 全七幅の導入の境界は、実際の Some/None の分岐で検査する。 -/
example : integerKinds.all (fun k =>
    (integerConvert k k.min).isSome && (integerConvert k k.max).isSome &&
      (integerConvert k (k.min-1)).isNone && (integerConvert k (k.max+1)).isNone) = true := by decide

example (k : IntKind) (n : Int) (v : IntegerValue k) (h : integerConvert k n = some v) :
    v.toInt = n ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
      (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? = some (.integer n) :=
  integerConvert_result k n v h

example (k : IntKind) (n : Int) :
    integerConvert k n = none ↔ n < k.min ∨ k.max < n := integerConvert_none k n

example (k : IntKind) (small : k ≠ .unsignedInteger64) (v : IntegerValue k) :
    ∃ w : IntegerValue .integer64, integerConvert .integer64 v.toInt = some w ∧ w.toInt = v.toInt :=
  integerWiden k small v

example (η : ObservationEnvModel) (a b : Int) :
    ∃ v, integerCompareDelta .le a b = .val (.const (.boolean v)) ∧
      (integerComparePred .le (.integer a) (.integer b)).interpret η = v :=
  integerCompare_reply η .le a b

example (P : Program) (B : Builtins) (Ψ : StoreTy) (k : IntKind) (v : IntegerValue k) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (embedConst (IntegerValue.toConst k v)))
      (embedConst (IntegerValue.toConst k v)).type := integer_result_typed P B Ψ Qempty [] [] [] k v


/-- 実定数の幅が一致するときだけ数値を読む。 -/
def integerRead (k : IntKind) : Val → Option (IntegerValue k)
  | .const (.integer n) => if k = .integer64 then integerConvert k n.toInt else none
  | .const (.integer8 n) => if k = .integer8 then integerConvert k n else none
  | .const (.integer16 n) => if k = .integer16 then integerConvert k n else none
  | .const (.integer32 n) => if k = .integer32 then integerConvert k n else none
  | .const (.unsignedInteger16 n) => if k = .unsignedInteger16 then integerConvert k n else none
  | .const (.unsignedInteger32 n) => if k = .unsignedInteger32 then integerConvert k n else none
  | .const (.unsignedInteger64 n) => if k = .unsignedInteger64 then integerConvert k n else none
  | _ => none

theorem integerRead_const (k : IntKind) (v : IntegerValue k) :
    integerRead k (.const (embedConst (IntegerValue.toConst k v))) = some v := by
  cases k <;> simp only [IntegerValue.toConst,embedConst,integerRead,ite_true]
  all_goals exact (integerConvert_some _ _ _).mpr rfl

def integerModule : IntKind → String
  | .integer8 => "Integer8"
  | .integer16 => "Integer16"
  | .integer32 => "Integer32"
  | .integer64 => "Integer"
  | .unsignedInteger16 => "UnsignedInteger16"
  | .unsignedInteger32 => "UnsignedInteger32"
  | .unsignedInteger64 => "UnsignedInteger64"

/-- Option の正常値を実際の構成子と型引数で表す。 -/
def scalarOption {α : Type} (base : BaseTy) (encode : α → Val) : Option α → Val
  | some v => .con "Option.Some" [.base base] [encode v]
  | none => .con "Option.None" [.base base] []

/-- Some と None はともに正常値であり、同じ宣言表の Option 型を持つ。 -/
theorem scalarOption_typed {α : Type} (P : Program) (B : Builtins) (Ψ : StoreTy)
    (base : BaseTy) (encode : α → Val) (v : Option α)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1)
    (values : ∀ x, HasTypeVQ P B Ψ Qempty [] [] [] (encode x) (.base base)) :
    HasTypeVQ P B Ψ Qempty [] [] [] (scalarOption base encode v) (.data "Option" [.base base]) := by
  have kinded : TypeArgsKinded P [] [.base base] [.value] := by
    refine ⟨rfl,?_⟩
    intro i t k ht hk
    cases i with
    | zero => simp only [List.getElem?_cons_zero,Option.some.injEq] at ht hk; subst t; subst k; exact ⟨trivial,by intro _; simp [Ordinary,Ty.core]⟩
    | succ i => simp at ht
  have annotation : Ty.Annotation P [] [] (.data "Option" [.base base]) :=
    ⟨⟨trivial,trivial⟩,⟨trivial,trivial⟩,⟨⟨1,arity,rfl⟩,trivial,trivial⟩⟩
  cases v with
  | none => exact .V_Con noneDecl rfl kinded (by simp) .nil annotation
  | some x =>
    apply HasTypeVQ.V_Con someDecl rfl kinded ?_ ?_ annotation
    · intro t ht
      simp only [List.mem_singleton] at ht
      subst t
      exact Nat.zero_lt_succ 0
    · exact .cons (values x) .nil

/-- 同じ Option の構成子と対象型で結果を作る。 -/
def integerOption (k : IntKind) (v : Option (IntegerValue k)) : Val :=
  match v with
  | some n => .con "Option.Some" [embedTy k.type] [.const (embedConst (IntegerValue.toConst k n))]
  | none => .con "Option.None" [embedTy k.type] []

/-- 名前と実引数を検査し、同じ幅の標準数値の本体を呼ぶ部分表。 -/
def integerDeltaAt (k : IntKind) (name : PrimName) (ws : List Val) : Option Outcome := do
  let moduleName := integerModule k
  if name = moduleName ++ ".fromInteger" ∧ k ≠ .integer64 then
    match ws with
    | [.const (.integer n)] => return .val (integerOption k (integerConvert k n.toInt))
    | _ => none
  else if name = moduleName ++ ".toInteger" ∧ k ≠ .integer64 then
    match ws with
    | [w] =>
      let v ← integerRead k w
      if k = .unsignedInteger64 then
        return .val (integerOption .integer64 (integerConvert .integer64 v.toInt))
      else
        match integerConvert .integer64 v.toInt with
        | some n => return .val (.const (embedConst (IntegerValue.toConst .integer64 n)))
        | none => none
    | _ => none
  else
    match ws with
    | [w] =>
      let a ← integerRead k w
      if name = moduleName ++ ".absolute" then return integerAbsoluteDelta k a
      else if h : name = "%" ++ moduleName ++ ".negate" ∧ k.min < 0 then
        return integerNegDelta k h.2 a
      else if name = moduleName ++ ".bitwiseNot" then return integerBitsDelta k .bitwiseNot a a 0
      else none
    | [w,z] =>
      let a ← integerRead k w
      if name = moduleName ++ ".shiftLeft" ∨ name = moduleName ++ ".shiftRight" ∨
          name = moduleName ++ ".shiftRightUnsigned" then
        match z with
        | .const (.integer n) =>
          if name = moduleName ++ ".shiftRightUnsigned" ∧ ¬ k.min < 0 then none else
          return integerBitsDelta k
            (if name = moduleName ++ ".shiftLeft" then .shiftLeft
             else if name = moduleName ++ ".shiftRight" then .shiftRight else .shiftRightUnsigned) a a n.toInt
        | _ => none
      else
        let b ← integerRead k z
        if name = "%" ++ moduleName ++ ".add" then return integerBinaryDelta k .add a b
        else if name = "%" ++ moduleName ++ ".subtract" then return integerBinaryDelta k .sub a b
        else if name = "%" ++ moduleName ++ ".multiply" then return integerBinaryDelta k .mul a b
        else if name = moduleName ++ ".minimum" then return integerMinMaxDelta k false a b
        else if name = moduleName ++ ".maximum" then return integerMinMaxDelta k true a b
        else if name = moduleName ++ ".floorDivide" then return integerFloorDelta k false a b
        else if name = moduleName ++ ".floorModulo" then return integerFloorDelta k true a b
        else if name = moduleName ++ ".bitwiseAnd" then return integerBitsDelta k .bitwiseAnd a b 0
        else if name = moduleName ++ ".bitwiseOr" then return integerBitsDelta k .bitwiseOr a b 0
        else if name = moduleName ++ ".bitwiseExclusiveOr" then return integerBitsDelta k .bitwiseExclusiveOr a b 0
        else if name = "%" ++ moduleName ++ ".less" then return integerCompareDelta .lt a.toInt b.toInt
        else if name = "%" ++ moduleName ++ ".lessOrEqual" then return integerCompareDelta .le a.toInt b.toInt
        else if name = "%" ++ moduleName ++ ".greater" then return integerCompareDelta .gt a.toInt b.toInt
        else if name = "%" ++ moduleName ++ ".greaterOrEqual" then return integerCompareDelta .ge a.toInt b.toInt
        else none
    | _ => none

/-- 篩の外側を除き、等値比較の型引数の基本型を読む。 -/
def scalarTypeCore : Ty → Option BaseTy
  | .refined a _ => scalarTypeCore a
  | .base b => some b
  | _ => none

/-- 等値比較は一つの型引数を持ち、行・範囲の引数を持たない。
他の数値の項目は型・行・範囲の引数を持たない。 -/
def scalarArguments (base : BaseTy) (name : PrimName) (ts : List Ty)
    (es : List Eff) (rs : List RangeExpr) : Bool :=
  es.isEmpty && rs.isEmpty &&
    (if name == "%eq" || name == "%ne" then
      match ts with | [t] => scalarTypeCore t == some base | _ => false
    else ts.isEmpty)

/-- 基本型の部分表は、共通の引数検査を通った入力だけを本体へ渡す。 -/
def scalarDelta (base : BaseTy) (body : PrimName → List Val → Option Outcome)
    (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if scalarArguments base name ts es rs then body name ws else none

/-- 六比較のうち等値の二つだけが型引数を持つ。 -/
def comparisonTypes (base : BaseTy) : Comparison → List Ty
  | .eq | .ne => [.base base]
  | _ => []

private def integerKindOfTy (t : Ty) : Option IntKind :=
  match scalarTypeCore t with
  | some .integer => some .integer64
  | some .integer8 => some .integer8
  | some .integer16 => some .integer16
  | some .integer32 => some .integer32
  | some .unsignedInteger16 => some .unsignedInteger16
  | some .unsignedInteger32 => some .unsignedInteger32
  | some .unsignedInteger64 => some .unsignedInteger64
  | _ => none

/-- 全七幅の純粋な数値応答の表。型・行・範囲の引数を持たない項目だけを選ぶ。 -/
def integerDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  if (name = "%eq" ∨ name = "%ne") ∧ es.isEmpty ∧ rs.isEmpty then do
    let k ← match ts with | [t] => integerKindOfTy t | _ => none
    match ws with
    | [w,z] =>
      let a ← integerRead k w
      let b ← integerRead k z
      return integerCompareDelta (if name = "%eq" then .eq else .ne) a.toInt b.toInt
    | _ => none
  else if ts.isEmpty && es.isEmpty && rs.isEmpty then
    integerKinds.findSome? (fun k => integerDeltaAt k name ws)
  else none



private def integerBinaryName (k : IntKind) (op : WidthBinary) : String :=
  "%" ++ integerModule k ++ match op with
    | .add => ".add" | .sub => ".subtract" | .mul => ".multiply"
    | _ => ""

/-- 名前で引いた実表は、同じ二引数の加減乗本体へ到達する。 -/
theorem integerDelta_binary (k : IntKind) (op : WidthBinary) (a b : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul) :
    integerDelta (integerBinaryName k op) [] [] []
      [.const (embedConst (IntegerValue.toConst k a)), .const (embedConst (IntegerValue.toConst k b))] =
      some (integerBinaryDelta k op a b) := by
  rcases supported with rfl | rfl | rfl
  all_goals cases k <;> simp [integerDelta, integerKinds, integerDeltaAt, integerModule,
    integerBinaryName, integerRead, IntegerValue.toConst, embedConst, integerConvert_self, integerConvert64_self,
    List.findSome?, Option.bind]

/-- 実表の正常加減乗から、同じ結果の有限な葉と型付けを作る。 -/
theorem integerDelta_binary_facts {P : Program} (valid : P.VarianceValid) (B : Builtins)
    (Ψ : StoreTy) (k : IntKind) (op : WidthBinary) (a b v : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (h : op.apply k a b = .normal (.ofInteger k v)) :
    integerDelta (integerBinaryName k op) [] [] []
      [.const (embedConst (IntegerValue.toConst k a)), .const (embedConst (IntegerValue.toConst k b))] =
      some (.val (.const (embedConst (IntegerValue.toConst k v)))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (embedConst (IntegerValue.toConst k v)))
      (embedConst (IntegerValue.toConst k v)).type ∧
    Entails [] (NormalResultLeaves.leaf op a.toInt b.toInt v.toInt).predicate := by
  obtain ⟨reply,_,_,_⟩ := integerBinary_reply k op a b v supported h
  exact ⟨(integerDelta_binary k op a b supported).trans (congrArg some reply),
    integer_result_typed P B Ψ Qempty [] [] [] k v,
    by simpa only [renEnv_values,id_eq,predBind_id] using NormalResultLeaves.binary_entails_at valid k op a b v supported h (renEnv id).values⟩

/-- absolute の正常値は非負であり、同じ数の絶対値である。 -/
theorem integerAbsolute_normal (k : IntKind) (a v : IntegerValue k)
    (h : integerChecked k (a.toInt.natAbs : Int) = .normal (.ofInteger k v)) :
    integerAbsoluteDelta k a = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      v.toInt = (a.toInt.natAbs : Int) ∧ 0 ≤ v.toInt := by
  have hn := (integerChecked_normal k _ v).mp h
  refine ⟨by rw [integerAbsoluteDelta,h,integerOutcome_normal],hn,?_⟩
  rw [hn]; omega

/-- min/max の同じ選択値は、元の型域と結果型を保つ。 -/
theorem integerMinMax_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : IntKind) (maximum : Bool) (a b : IntegerValue k) :
    ∃ v : IntegerValue k,
      integerMinMaxDelta k maximum a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      (v = a ∨ v = b) ∧ HasTypeVQ P B Ψ Qempty [] [] []
        (.const (embedConst (IntegerValue.toConst k v))) (embedTy k.type) := by
  let v := if maximum then (if a.toInt < b.toInt then b else a)
    else (if a.toInt ≤ b.toInt then a else b)
  refine ⟨v,rfl,?_,?_⟩
  · dsimp [v]; split <;> split <;> simp
  · have h := integer_result_typed P B Ψ Qempty [] [] [] k v
    cases k <;> exact h

/-- 正常なビット演算の応答は count の拒否と区別され、同じ幅で型付く。 -/
theorem integerBits_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : IntKind) (op : IntegerBits) (a b : IntegerValue k) (count : Int) :
    integerBitsDelta k op a b count = .err "ArgumentOutOfDomain" ∨
    ∃ v : IntegerValue k,
      integerBitsDelta k op a b count = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (embedConst (IntegerValue.toConst k v))) (embedTy k.type) := by
  by_cases bad : (op = .shiftLeft ∨ op = .shiftRight ∨ op = .shiftRightUnsigned) ∧
      (count < 0 ∨ (integerWidth k : Int) ≤ count)
  · left; simp only [integerBitsDelta, ite_eq_left bad]
  · simp only [integerBitsDelta, ite_eq_right bad]
    right; refine ⟨_,rfl,?_⟩
    cases k <;> apply integer_result_typed

example {P : Program} (valid : P.VarianceValid) (B : Builtins) (Ψ : StoreTy)
    (k : IntKind) (op : WidthBinary) (a b v : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (h : op.apply k a b = .normal (.ofInteger k v)) :
    Entails [] (NormalResultLeaves.leaf op a.toInt b.toInt v.toInt).predicate :=
  (integerDelta_binary_facts valid B Ψ k op a b v supported h).2.2

example (k : IntKind) (signed : k.min < 0) (a v : IntegerValue k)
    (h : k.checkedNeg signed a = .normal (.ofInteger k v)) :
    integerNegDelta k signed a = .val (.const (embedConst (IntegerValue.toConst k v))) :=
  (integerNeg_reply k signed a v h).1

example (k : IntKind) (a v : IntegerValue k)
    (h : integerChecked k (a.toInt.natAbs : Int) = .normal (.ofInteger k v)) :
    0 ≤ v.toInt := (integerAbsolute_normal k a v h).2.2

example (P : Program) (B : Builtins) (Ψ : StoreTy) (k : IntKind) (maximum : Bool) (a b : IntegerValue k) :
    ∃ v : IntegerValue k,
      integerMinMaxDelta k maximum a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      (v = a ∨ v = b) ∧ HasTypeVQ P B Ψ Qempty [] [] []
        (.const (embedConst (IntegerValue.toConst k v))) (embedTy k.type) :=
  integerMinMax_typed P B Ψ k maximum a b

example (P : Program) (B : Builtins) (Ψ : StoreTy) (k : IntKind) (op : IntegerBits)
    (a b : IntegerValue k) (count : Int) :
    integerBitsDelta k op a b count = .err "ArgumentOutOfDomain" ∨
    ∃ v : IntegerValue k,
      integerBitsDelta k op a b count = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (embedConst (IntegerValue.toConst k v))) (embedTy k.type) :=
  integerBits_typed P B Ψ k op a b count


/-- 各 fromInteger の表は同じ Integer を Some 又は None へ変換する。 -/
theorem integerDelta_fromInteger (k : IntKind) (n : Benitoite.Release.Integer64Value)
    (hasAPI : k ≠ .integer64) :
    integerDelta (integerModule k ++ ".fromInteger") [] [] [] [.const (.integer n)] =
      some (.val (integerOption k (integerConvert k n.toInt))) := by
  cases k <;> simp_all [integerDelta, integerKinds, integerDeltaAt, integerModule,
    integerRead, List.findSome?, Option.bind]
  all_goals cases integerConvert .integer64 n.toInt <;> rfl

/-- u64 から Integer への変換は Option であり、最大値を失敗として返す。 -/
example : integerDelta "UnsignedInteger64.toInteger" [] [] []
    [.const (.unsignedInteger64 18446744073709551615)] =
    some (.val (.con "Option.None" [.base .integer] [])) := by rfl

example : integerDelta "UnsignedInteger64.toInteger" [] [] []
    [.const (.unsignedInteger64 9223372036854775807)] =
    some (.val (.con "Option.Some" [.base .integer]
      [.const (.integer ⟨9223372036854775807,by decide⟩)])) := by rfl

example : integerDelta "Integer8.fromInteger" [] [] [] [.const (.integer ⟨128,by decide⟩)] =
    some (.val (.con "Option.None" [.base .integer8] [])) :=
  integerDelta_fromInteger .integer8 _ (by decide)

example : integerDelta "Integer8.fromInteger" [] [] [] [.const (.integer ⟨127,by decide⟩)] =
    some (.val (.con "Option.Some" [.base .integer8] [.const (.integer8 127)])) :=
  integerDelta_fromInteger .integer8 _ (by decide)

example (k : IntKind) (v : IntegerValue k) :
    integerRead k (.const (embedConst (IntegerValue.toConst k v))) = some v :=
  integerRead_const k v

example : integerDelta "Integer8.floorDivide" [] [] [] [.const (.integer8 (-7)),.const (.integer8 3)] =
    some (.val (.const (.integer8 (-3)))) := by rfl
example : integerDelta "Integer8.floorModulo" [] [] [] [.const (.integer8 (-7)),.const (.integer8 3)] =
    some (.val (.const (.integer8 2))) := by rfl
example : integerDelta "Integer8.shiftRight" [] [] []
    [.const (.integer8 (-128)),.const (.integer ⟨1,by decide⟩)] =
    some (.val (.const (.integer8 (-64)))) := by rfl
example : integerDelta "Integer8.shiftRightUnsigned" [] [] []
    [.const (.integer8 (-128)),.const (.integer ⟨1,by decide⟩)] =
    some (.val (.const (.integer8 64))) := by rfl
example : integerDelta "UnsignedInteger64.shiftLeft" [] [] []
    [.const (.unsignedInteger64 18446744073709551615),.const (.integer ⟨1,by decide⟩)] =
    some (.val (.const (.unsignedInteger64 18446744073709551614))) := by rfl


/-- 整数の等号と不等号も、同じ型引数と二定数で実応答を得る。 -/
theorem integerDelta_equality (k : IntKind) (a b : IntegerValue k) (equal : Bool) :
    integerDelta (if equal then "%eq" else "%ne") [embedTy k.type] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
    some (integerCompareDelta (if equal then .eq else .ne) a.toInt b.toInt) := by
  cases equal <;> cases k <;>
    simp [integerDelta,integerKindOfTy,scalarTypeCore,IntKind.type,embedTy,integerRead_const]

example (k : IntKind) (a b : IntegerValue k) (equal : Bool) :
    integerDelta (if equal then "%eq" else "%ne") [embedTy k.type] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
    some (integerCompareDelta (if equal then .eq else .ne) a.toInt b.toInt) :=
  integerDelta_equality k a b equal


/-- 小幅の全域拡大と u64 の Option を区別する。 -/
def integerToIntegerDelta (k : IntKind) (v : IntegerValue k) : Option Outcome :=
  if k = .unsignedInteger64 then some (.val (integerOption .integer64 (integerConvert .integer64 v.toInt)))
  else match integerConvert .integer64 v.toInt with
    | some n => some (.val (.const (embedConst (IntegerValue.toConst .integer64 n))))
    | none => none

theorem integerDelta_toInteger (k : IntKind) (v : IntegerValue k) (hasAPI : k ≠ .integer64) :
    integerDelta (integerModule k ++ ".toInteger") [] [] []
      [.const (embedConst (IntegerValue.toConst k v))] = integerToIntegerDelta k v := by
  cases k <;> simp_all [integerDelta,integerToIntegerDelta,integerKinds,integerDeltaAt,
    integerModule,integerRead,IntegerValue.toConst,embedConst,integerConvert_self,
    List.findSome?,Option.bind]
  all_goals split <;> rename_i h <;> exact h.symm

private def integerOrderName (k : IntKind) (op : Comparison) : String :=
  "%" ++ integerModule k ++ match op with
    | .lt => ".less" | .le => ".lessOrEqual" | .gt => ".greater" | .ge => ".greaterOrEqual"
    | _ => ""

theorem integerDelta_order (k : IntKind) (op : Comparison) (a b : IntegerValue k)
    (ordered : op = .lt ∨ op = .le ∨ op = .gt ∨ op = .ge) :
    integerDelta (integerOrderName k op) [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
    some (integerCompareDelta op a.toInt b.toInt) := by
  rcases ordered with rfl | rfl | rfl | rfl
  all_goals cases k <;> simp [integerDelta,integerOrderName,integerKinds,integerDeltaAt,
    integerModule,integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind]

example (k : IntKind) (v : IntegerValue k) (hasAPI : k ≠ .integer64) :
    integerDelta (integerModule k ++ ".toInteger") [] [] []
      [.const (embedConst (IntegerValue.toConst k v))] = integerToIntegerDelta k v :=
  integerDelta_toInteger k v hasAPI

example (k : IntKind) (a b : IntegerValue k) (η : ObservationEnvModel) (op : Comparison)
    (ordered : op = .lt ∨ op = .le ∨ op = .gt ∨ op = .ge) :
    ∃ v, integerDelta (integerOrderName k op) [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
        some (.val (.const (.boolean v))) ∧
      (integerComparePred op (.integer a.toInt) (.integer b.toInt)).interpret η = v := by
  obtain ⟨v,hv,hp⟩ := integerCompare_reply η op a.toInt b.toInt
  exact ⟨v,(integerDelta_order k op a b ordered).trans (congrArg some hv),hp⟩


/-- 正常な検査付き整数の応答では、計算した数をそのまま型付き定数にする。 -/
theorem integerChecked_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (k : IntKind) (n : Int) :
    integerOutcome (integerChecked k n) = .err "IntegerOverflow" ∨
    ∃ v : IntegerValue k, v.toInt = n ∧
      integerOutcome (integerChecked k n) = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (embedConst (IntegerValue.toConst k v))) (embedTy k.type) := by
  cases h : integerConvert k n with
  | none => left; simp only [integerChecked,h,integerOutcome]
  | some v =>
    right; refine ⟨v,(integerConvert_some k n v).mp h,?_,?_⟩
    · simp only [integerChecked,h,integerOutcome_normal]
    · have ht := integer_result_typed P B Ψ Qempty [] [] [] k v
      cases k <;> exact ht

example (P : Program) (B : Builtins) (Ψ : StoreTy) (k : IntKind) (a b : IntegerValue k)
    (modulo : Bool) :
    integerFloorDelta k modulo a b = .err "DivisionByZero" ∨
    integerFloorDelta k modulo a b = .err "IntegerOverflow" ∨
    ∃ v : IntegerValue k,
      integerFloorDelta k modulo a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (embedConst (IntegerValue.toConst k v))) (embedTy k.type) := by
  by_cases hz : b.toInt = 0
  · left; simp [integerFloorDelta,hz]
  · right
    simp only [integerFloorDelta,ite_eq_right hz]
    rcases integerChecked_typed P B Ψ k _ with err | ⟨v,_,hv,ht⟩
    · exact Or.inl err
    · exact Or.inr ⟨v,hv,ht⟩


/-- 等値の型引数に篩を持つ実入力も、同じ整数の比較へ渡す。 -/
example : integerDelta "%eq" [.refined (.base .integer8) (.le (.integer 0) (.var 0))] [] []
    [.const (.integer8 7),.const (.integer8 7)] = some (.val (.const (.boolean true))) := by rfl

/-- 床除算と床剰余の実名は、同じ幅と二値の本体を選ぶ。 -/
theorem integerDelta_floor (k : IntKind) (modulo : Bool) (a b : IntegerValue k) :
    integerDelta (integerModule k ++ if modulo then ".floorModulo" else ".floorDivide") [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
      some (integerFloorDelta k modulo a b) := by
  cases modulo <;>
    cases k <;> simp [integerDelta,integerKinds,integerDeltaAt,integerModule,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind]

/-- absolute の実名は、同じ幅と値の本体を選ぶ。 -/
theorem integerDelta_absolute (k : IntKind) (a : IntegerValue k) :
    integerDelta (integerModule k ++ ".absolute") [] [] []
      [.const (embedConst (IntegerValue.toConst k a))] = some (integerAbsoluteDelta k a) := by
  cases k <;> simp [integerDelta,integerKinds,integerDeltaAt,integerModule,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind]

/-- minimum と maximum の実名は、同じ二値の選択を行う。 -/
theorem integerDelta_minMax (k : IntKind) (maximum : Bool) (a b : IntegerValue k) :
    integerDelta (integerModule k ++ if maximum then ".maximum" else ".minimum") [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
      some (integerMinMaxDelta k maximum a b) := by
  cases maximum <;>
    cases k <;> simp [integerDelta,integerKinds,integerDeltaAt,integerModule,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind]

private def integerBitsName (k : IntKind) (op : IntegerBits) : String :=
  integerModule k ++ match op with
    | .bitwiseAnd => ".bitwiseAnd" | .bitwiseOr => ".bitwiseOr"
    | .bitwiseExclusiveOr => ".bitwiseExclusiveOr" | .bitwiseNot => ".bitwiseNot"
    | .shiftLeft => ".shiftLeft" | .shiftRight => ".shiftRight"
    | .shiftRightUnsigned => ".shiftRightUnsigned"

/-- 二項ビット演算の実名は、全七幅で同じ本体を選ぶ。 -/
theorem integerDelta_bitwise (k : IntKind) (op : IntegerBits) (a b : IntegerValue k)
    (binary : op = .bitwiseAnd ∨ op = .bitwiseOr ∨ op = .bitwiseExclusiveOr) :
    integerDelta (integerBitsName k op) [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
      some (integerBitsDelta k op a b 0) := by
  rcases binary with rfl | rfl | rfl
  all_goals cases k <;> simp [integerDelta,integerKinds,integerDeltaAt,integerModule,integerBitsName,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind]

/-- 単項の反転は、全七幅で同じ本体を選ぶ。 -/
theorem integerDelta_bitwiseNot (k : IntKind) (a : IntegerValue k) :
    integerDelta (integerModule k ++ ".bitwiseNot") [] [] []
      [.const (embedConst (IntegerValue.toConst k a))] = some (integerBitsDelta k .bitwiseNot a a 0) := by
  cases k <;> simp [integerDelta,integerKinds,integerDeltaAt,integerModule,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind]

/-- シフトの実名は、同じ幅の本体へ Integer の量を渡す。
論理右シフトは符号付きの型にだけ存在する。 -/
theorem integerDelta_shift (k : IntKind) (op : IntegerBits) (a : IntegerValue k)
    (count : Benitoite.Release.Integer64Value)
    (shift : op = .shiftLeft ∨ op = .shiftRight ∨ op = .shiftRightUnsigned)
    (available : op = .shiftRightUnsigned → k.min < 0) :
    integerDelta (integerBitsName k op) [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (.integer count)] =
      some (integerBitsDelta k op a a count.toInt) := by
  rcases shift with rfl | rfl | rfl
  all_goals cases k <;> simp_all [integerDelta,integerKinds,integerDeltaAt,integerModule,integerBitsName,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind,IntKind.min,Benitoite.Release.min64]

/-- 負号の実名は、符号付きの全幅で検査付きの負号へ到達する。 -/
theorem integerDelta_negate (k : IntKind) (signed : k.min < 0) (a : IntegerValue k) :
    integerDelta ("%" ++ integerModule k ++ ".negate") [] [] []
      [.const (embedConst (IntegerValue.toConst k a))] = some (integerNegDelta k signed a) := by
  cases k <;> simp_all [integerDelta,integerKinds,integerDeltaAt,integerModule,
    integerRead,IntegerValue.toConst,embedConst,integerConvert_self,integerConvert64_self,
    List.findSome?,Option.bind,IntKind.min,Benitoite.Release.min64]

example : integerDelta (integerModule .integer8 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .integer8 (⟨3,by decide⟩ : IntegerValue .integer8)))),(.const (embedConst (IntegerValue.toConst .integer8 (⟨2,by decide⟩ : IntegerValue .integer8))))] =
    some (integerFloorDelta .integer8 false (⟨3,by decide⟩ : IntegerValue .integer8) (⟨2,by decide⟩ : IntegerValue .integer8)) := integerDelta_floor .integer8 false _ _

example : integerDelta (integerModule .integer16 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .integer16 (⟨3,by decide⟩ : IntegerValue .integer16)))),(.const (embedConst (IntegerValue.toConst .integer16 (⟨2,by decide⟩ : IntegerValue .integer16))))] =
    some (integerFloorDelta .integer16 false (⟨3,by decide⟩ : IntegerValue .integer16) (⟨2,by decide⟩ : IntegerValue .integer16)) := integerDelta_floor .integer16 false _ _

example : integerDelta (integerModule .integer32 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .integer32 (⟨3,by decide⟩ : IntegerValue .integer32)))),(.const (embedConst (IntegerValue.toConst .integer32 (⟨2,by decide⟩ : IntegerValue .integer32))))] =
    some (integerFloorDelta .integer32 false (⟨3,by decide⟩ : IntegerValue .integer32) (⟨2,by decide⟩ : IntegerValue .integer32)) := integerDelta_floor .integer32 false _ _

example : integerDelta (integerModule .integer64 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .integer64 (⟨3,by decide⟩ : IntegerValue .integer64)))),(.const (embedConst (IntegerValue.toConst .integer64 (⟨2,by decide⟩ : IntegerValue .integer64))))] =
    some (integerFloorDelta .integer64 false (⟨3,by decide⟩ : IntegerValue .integer64) (⟨2,by decide⟩ : IntegerValue .integer64)) := integerDelta_floor .integer64 false _ _

example : integerDelta (integerModule .unsignedInteger16 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .unsignedInteger16 (⟨3,by decide⟩ : IntegerValue .unsignedInteger16)))),(.const (embedConst (IntegerValue.toConst .unsignedInteger16 (⟨2,by decide⟩ : IntegerValue .unsignedInteger16))))] =
    some (integerFloorDelta .unsignedInteger16 false (⟨3,by decide⟩ : IntegerValue .unsignedInteger16) (⟨2,by decide⟩ : IntegerValue .unsignedInteger16)) := integerDelta_floor .unsignedInteger16 false _ _

example : integerDelta (integerModule .unsignedInteger32 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .unsignedInteger32 (⟨3,by decide⟩ : IntegerValue .unsignedInteger32)))),(.const (embedConst (IntegerValue.toConst .unsignedInteger32 (⟨2,by decide⟩ : IntegerValue .unsignedInteger32))))] =
    some (integerFloorDelta .unsignedInteger32 false (⟨3,by decide⟩ : IntegerValue .unsignedInteger32) (⟨2,by decide⟩ : IntegerValue .unsignedInteger32)) := integerDelta_floor .unsignedInteger32 false _ _

example : integerDelta (integerModule .unsignedInteger64 ++ ".floorDivide") [] [] [] [(.const (embedConst (IntegerValue.toConst .unsignedInteger64 (⟨3,by decide⟩ : IntegerValue .unsignedInteger64)))),(.const (embedConst (IntegerValue.toConst .unsignedInteger64 (⟨2,by decide⟩ : IntegerValue .unsignedInteger64))))] =
    some (integerFloorDelta .unsignedInteger64 false (⟨3,by decide⟩ : IntegerValue .unsignedInteger64) (⟨2,by decide⟩ : IntegerValue .unsignedInteger64)) := integerDelta_floor .unsignedInteger64 false _ _

example := integerDelta_absolute .integer16 (⟨-3,by decide⟩)

example := integerDelta_minMax .unsignedInteger32 true (⟨3,by decide⟩) (⟨2,by decide⟩)

example := integerDelta_bitwise .unsignedInteger16 .bitwiseExclusiveOr (⟨3,by decide⟩) (⟨2,by decide⟩) (Or.inr (Or.inr rfl))

example := integerDelta_bitwiseNot .integer32 (⟨3,by decide⟩)

example := integerDelta_shift .integer16 .shiftRightUnsigned (⟨-3,by decide⟩) (⟨1,by decide⟩) (Or.inr (Or.inr rfl)) (by decide)

example := integerDelta_negate .integer64 (by decide) (⟨-3,by decide⟩)

/-- 各幅の明示変換の Some と None を、実宣言の Option で型付ける。 -/
theorem integerOption_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (k : IntKind)
    (v : Option (IntegerValue k))
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    HasTypeVQ P B Ψ Qempty [] [] [] (integerOption k v) (.data "Option" [embedTy k.type]) := by
  cases k with
  | integer8 =>
    have h := scalarOption_typed P B Ψ .integer8
      (fun x : IntegerValue .integer8 => .const (embedConst (IntegerValue.toConst .integer8 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .integer8 x)
    cases v <;> exact h
  | integer16 =>
    have h := scalarOption_typed P B Ψ .integer16
      (fun x : IntegerValue .integer16 => .const (embedConst (IntegerValue.toConst .integer16 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .integer16 x)
    cases v <;> exact h
  | integer32 =>
    have h := scalarOption_typed P B Ψ .integer32
      (fun x : IntegerValue .integer32 => .const (embedConst (IntegerValue.toConst .integer32 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .integer32 x)
    cases v <;> exact h
  | integer64 =>
    have h := scalarOption_typed P B Ψ .integer
      (fun x : IntegerValue .integer64 => .const (embedConst (IntegerValue.toConst .integer64 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .integer64 x)
    cases v <;> exact h
  | unsignedInteger16 =>
    have h := scalarOption_typed P B Ψ .unsignedInteger16
      (fun x : IntegerValue .unsignedInteger16 => .const (embedConst (IntegerValue.toConst .unsignedInteger16 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .unsignedInteger16 x)
    cases v <;> exact h
  | unsignedInteger32 =>
    have h := scalarOption_typed P B Ψ .unsignedInteger32
      (fun x : IntegerValue .unsignedInteger32 => .const (embedConst (IntegerValue.toConst .unsignedInteger32 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .unsignedInteger32 x)
    cases v <;> exact h
  | unsignedInteger64 =>
    have h := scalarOption_typed P B Ψ .unsignedInteger64
      (fun x : IntegerValue .unsignedInteger64 => .const (embedConst (IntegerValue.toConst .unsignedInteger64 x))) v
      someDecl noneDecl arity (fun x => integer_result_typed P B Ψ Qempty [] [] [] .unsignedInteger64 x)
    cases v <;> exact h

/-- 名前付きの変換の正常応答を、構成子の型付けへ渡す。 -/
theorem integerDelta_fromInteger_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : IntKind) (n : Benitoite.Release.Integer64Value) (hasAPI : k ≠ .integer64)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, integerDelta (integerModule k ++ ".fromInteger") [] [] [] [.const (.integer n)] = some (.val v) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [embedTy k.type]) :=
  ⟨_,integerDelta_fromInteger k n hasAPI,integerOption_typed P B Ψ k _ someDecl noneDecl arity⟩

end Benitoite.Release.Refinement.StandardScalar
