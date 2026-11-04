import Benitoite.Release.Refinement.StandardIntegerAPI
import Benitoite.Release.Refinement.IntervalConnection

/-! # 幅付き整数の正常値と局所の拒否 -/
namespace Benitoite.Release.Refinement.StandardScalar
open Benitoite.Interval
open IntervalConnection

/-- 区間の拒否理由を、整数の実応答の理由へ写す。 -/
def integerFailure : Failure → ErrKind
  | .overflow => "IntegerOverflow"
  | .zeroDivisor => "DivisionByZero"
  | _ => "ArgumentOutOfDomain"

theorem integerOutcome_rejected (r : Failure) :
    integerOutcome (.rejected r) = .err (integerFailure r) := by cases r <;> rfl

/-- 正常値では同じ定数を対応させ、拒否ではその位置の理由だけを返す。 -/
theorem integerChecked_split (k : IntKind) (n : Int) :
    (∃ v : IntegerValue k, v.toInt = n ∧
      integerChecked k n = .normal (.ofInteger k v) ∧
      integerOutcome (integerChecked k n) = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
    (integerChecked k n = .rejected .overflow ∧
      integerOutcome (integerChecked k n) = .err "IntegerOverflow" ∧
      (n < k.min ∨ k.max < n)) := by
  cases h : integerConvert k n with
  | some v =>
    left
    refine ⟨v,(integerConvert_some k n v).mp h,?_,?_,.integer k v⟩
    · simp only [integerChecked,h]
    · simp only [integerChecked,h,integerOutcome_normal]
  | none =>
    right
    exact ⟨by simp only [integerChecked,h],by simp only [integerChecked,h,integerOutcome],
      (integerConvert_none k n).mp h⟩

private theorem checked_same (k : IntKind) (n : Int) :
    (if h : k.min ≤ n ∧ n ≤ k.max then OperationResult.normal (.ofInteger k ⟨n,h⟩)
     else .rejected .overflow) = integerChecked k n := by
  unfold integerChecked integerConvert
  split <;> rfl

/-- 加減乗の実 OperationResult は、同じ数学値の検査である。 -/
theorem binary_checked (k : IntKind) (op : WidthBinary) (a b : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul) :
    op.apply k a b = integerChecked k
      (match op with | .add => a.toInt+b.toInt | .sub => a.toInt-b.toInt | _ => a.toInt*b.toInt) := by
  rcases supported with rfl | rfl | rfl
  all_goals exact checked_same k _

theorem neg_checked (k : IntKind) (signed : k.min < 0) (a : IntegerValue k) :
    k.checkedNeg signed a = integerChecked k (-a.toInt) := checked_same k _

/-- 商は表現可能性を検査し、剰余は同じ幅の正常値を直接作る。 -/
theorem divMod_checked (k : IntKind) (a b : IntegerValue k) (modulo : Bool) :
    k.checkedDivMod (if modulo then .mod else .intDiv) a b =
      if b.toInt = 0 then .rejected .zeroDivisor
      else integerChecked k (if modulo then a.toInt.tmod b.toInt else a.toInt.tdiv b.toInt) := by
  cases modulo with
  | false =>
    simp only [Bool.false_eq_true,ite_false,IntKind.checkedDivMod,IntegerDivisionOp,
      true_or,ite_true,reduceCtorEq]
    split
    · rfl
    · exact checked_same k _
  | true =>
    simp only [ite_true,IntKind.checkedDivMod,IntegerDivisionOp,or_true]
    split
    · rfl
    · rename_i hz
      unfold integerChecked integerConvert
      rw [dite_eq_left (k.tmod_bounds a b hz)]

/-- 実表の加減乗を、正常な同じ値又はその場の overflow へ分ける。 -/
theorem binary_delta_split (k : IntKind) (op : WidthBinary) (a b : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul) :
    (∃ v : IntegerValue k,
      integerBinaryDelta k op a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
    (integerBinaryDelta k op a b = .err "IntegerOverflow" ∧
      ((match op with | .add => a.toInt+b.toInt | .sub => a.toInt-b.toInt | _ => a.toInt*b.toInt) < k.min ∨ k.max < (match op with | .add => a.toInt+b.toInt | .sub => a.toInt-b.toInt | _ => a.toInt*b.toInt))) := by
  rw [integerBinaryDelta,binary_checked k op a b supported]
  rcases integerChecked_split k _ with ⟨v,_,_,hv,rel⟩ | ⟨_,err,outside⟩
  · exact .inl ⟨v,hv,rel⟩
  · exact .inr ⟨err,outside⟩

/-- 正常な剰余は商の表現可能性に依存しない。 -/
theorem modulo_normal (k : IntKind) (a b : IntegerValue k) (nonzero : b.toInt ≠ 0) :
    ∃ v : IntegerValue k, v.toInt = a.toInt.tmod b.toInt ∧
      integerBinaryDelta k .mod a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) := by
  let v : IntegerValue k := ⟨_,k.tmod_bounds a b nonzero⟩
  refine ⟨v,rfl,?_,.integer k v⟩
  change integerOutcome (k.checkedDivMod .mod a b) = _
  simp only [IntKind.checkedDivMod,IntegerDivisionOp,or_true,ite_true,
    dite_eq_right nonzero,integerOutcome_normal]
  rfl

theorem divMod_zero (k : IntKind) (a b : IntegerValue k) (zero : b.toInt = 0)
    (modulo : Bool) :
    integerBinaryDelta k (if modulo then .mod else .intDiv) a b = .err "DivisionByZero" := by
  cases modulo <;> simp only [ite_true,Bool.false_eq_true,ite_false,integerBinaryDelta,
    WidthBinary.apply,IntKind.checkedDivMod,IntegerDivisionOp,or_true,true_or,ite_true,
    dite_eq_left zero,integerOutcome]

/-- 正常な負号又は overflow を同じ実本体から得る。 -/
theorem neg_delta_split (k : IntKind) (signed : k.min < 0) (a : IntegerValue k) :
    (∃ v : IntegerValue k, v.toInt = -a.toInt ∧
      integerNegDelta k signed a = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
    (integerNegDelta k signed a = .err "IntegerOverflow" ∧
      (-a.toInt < k.min ∨ k.max < -a.toInt)) := by
  rw [integerNegDelta,neg_checked]
  rcases integerChecked_split k (-a.toInt) with ⟨v,eq,_,hv,rel⟩ | ⟨_,err,hout⟩
  · exact .inl ⟨v,eq,hv,rel⟩
  · exact .inr ⟨err,hout⟩

theorem floor_delta_split (k : IntKind) (modulo : Bool) (a b : IntegerValue k) :
    (b.toInt = 0 ∧ integerFloorDelta k modulo a b = .err "DivisionByZero") ∨
    (b.toInt ≠ 0 ∧
      ((∃ v : IntegerValue k, v.toInt = StandardIntegerAPI.floorNumber modulo a.toInt b.toInt ∧
          integerFloorDelta k modulo a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
          ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
       (integerFloorDelta k modulo a b = .err "IntegerOverflow" ∧
          (StandardIntegerAPI.floorNumber modulo a.toInt b.toInt < k.min ∨
           k.max < StandardIntegerAPI.floorNumber modulo a.toInt b.toInt)))) := by
  by_cases hz : b.toInt = 0
  · exact .inl ⟨hz,by simp only [integerFloorDelta,hz,ite_true]⟩
  · right
    refine ⟨hz,?_⟩
    change _ ∨ _
    have eq : integerFloorDelta k modulo a b =
        integerOutcome (integerChecked k (StandardIntegerAPI.floorNumber modulo a.toInt b.toInt)) := by
      simp only [integerFloorDelta,ite_eq_right hz,StandardIntegerAPI.floorNumber]
    rw [eq]
    rcases integerChecked_split k (StandardIntegerAPI.floorNumber modulo a.toInt b.toInt) with
      ⟨v,hv,_,he,rel⟩ | ⟨_,he,ho⟩
    · exact .inl ⟨v,hv,he,rel⟩
    · exact .inr ⟨he,ho⟩

private theorem floor_modulo_bounds (k : IntKind) (a b : IntegerValue k)
    (nonzero : b.toInt ≠ 0) :
    k.min ≤ StandardIntegerAPI.floorNumber true a.toInt b.toInt ∧
      StandardIntegerAPI.floorNumber true a.toInt b.toInt ≤ k.max := by
  have hb := b.toInt_bounds
  have hr := k.tmod_bounds a b nonzero
  have hlo : k.min ≤ 0 := by cases k <;> decide
  have hhi : 0 ≤ k.max := by cases k <;> decide
  unfold StandardIntegerAPI.floorNumber
  simp only [ite_true]
  split
  · rename_i hc
    by_cases pos : 0 < b.toInt
    · have lo := Int.lt_tmod_of_pos a.toInt pos
      have hi := Int.tmod_lt_of_pos a.toInt pos
      have rneg : a.toInt.tmod b.toInt < 0 := by
        by_cases h : a.toInt.tmod b.toInt < 0
        · exact h
        · exact False.elim (hc.2 (propext (by omega)))
      omega
    · have neg : 0 < -b.toInt := by omega
      have lo := Int.lt_tmod_of_pos a.toInt neg
      have hi := Int.tmod_lt_of_pos a.toInt neg
      rw [Int.tmod_neg] at lo hi
      have rpos : 0 < a.toInt.tmod b.toInt := by
        by_cases h : 0 < a.toInt.tmod b.toInt
        · exact h
        · exact False.elim (hc.2 (propext (by omega)))
      omega
  · exact hr

/-- 床剰余は非零の除数なら必ず同じ幅に収まる。 -/
theorem floorModulo_normal (k : IntKind) (a b : IntegerValue k) (nonzero : b.toInt ≠ 0) :
    ∃ v : IntegerValue k, v.toInt = StandardIntegerAPI.floorNumber true a.toInt b.toInt ∧
      integerFloorDelta k true a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) := by
  rcases floor_delta_split k true a b with ⟨hz,_⟩ | ⟨_,⟨v,hv,he,rel⟩ | ⟨_,ho⟩⟩
  · exact False.elim (nonzero hz)
  · exact ⟨v,hv,he,rel⟩
  · have := floor_modulo_bounds k a b nonzero; omega

private theorem signed_asymmetric (k : IntKind) (signed : k.min < 0) : k.max < -k.min := by
  cases k <;> simp_all [IntKind.min,IntKind.max,Benitoite.Release.min64,Benitoite.Release.max64]

/-- 符号付き四幅の最小値では、absolute と最小値÷−1の商だけがあふれる。 -/
theorem signed_minimum_stops (k : IntKind) (signed : k.min < 0) (a b : IntegerValue k)
    (minimum : a.toInt = k.min) (minusOne : b.toInt = -1) :
    integerAbsoluteDelta k a = .err "IntegerOverflow" ∧
    integerFloorDelta k false a b = .err "IntegerOverflow" ∧
    integerBinaryDelta k .intDiv a b = .err "IntegerOverflow" ∧
    (∃ v : IntegerValue k, v.toInt = 0 ∧
      integerFloorDelta k true a b = .val (.const (embedConst (IntegerValue.toConst k v)))) := by
  have ho := signed_asymmetric k signed
  have conv : integerConvert k (-k.min) = none := (integerConvert_none k _).mpr (.inr ho)
  have abs : (a.toInt.natAbs : Int) = -k.min := by
    rw [minimum,Int.ofNat_natAbs_of_nonpos (by omega)]
  refine ⟨?_,?_,?_,?_⟩
  · simp only [integerAbsoluteDelta,abs,integerChecked,conv,integerOutcome]
  · simp [integerFloorDelta,minusOne,minimum,integerChecked,conv,integerOutcome]
  · change integerOutcome (k.checkedDivMod .intDiv a b) = _
    rw [show k.checkedDivMod .intDiv a b = _ from divMod_checked k a b false]
    simp [minusOne,minimum,integerChecked,conv,integerOutcome]
  · obtain ⟨v,hv,he,_⟩ := floorModulo_normal k a b (by omega)
    exact ⟨v,by simpa [StandardIntegerAPI.floorNumber,minusOne] using hv,he⟩

theorem absolute_split (k : IntKind) (a : IntegerValue k) :
    (∃ v : IntegerValue k, v.toInt = (a.toInt.natAbs : Int) ∧
      integerAbsoluteDelta k a = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
    (integerAbsoluteDelta k a = .err "IntegerOverflow" ∧ k.max < (a.toInt.natAbs : Int)) := by
  rcases integerChecked_split k (a.toInt.natAbs : Int) with ⟨v,hv,_,he,rel⟩ | ⟨_,he,ho⟩
  · exact .inl ⟨v,hv,he,rel⟩
  · have hn : k.min ≤ (a.toInt.natAbs : Int) := by
      cases k <;> simp only [IntKind.min,Benitoite.Release.min64] <;> omega
    exact .inr ⟨he,by omega⟩

/-- count の域外はビット値を計算する前に拒否する。 -/
theorem shift_outside (k : IntKind) (op : IntegerBits) (a b : IntegerValue k) (count : Int)
    (shift : op = .shiftLeft ∨ op = .shiftRight ∨ op = .shiftRightUnsigned)
    (outside : count < 0 ∨ (integerWidth k : Int) ≤ count) :
    integerBitsDelta k op a b count = .err "ArgumentOutOfDomain" := by
  simp only [integerBitsDelta,shift,outside,and_self,ite_true]

theorem shift_inside (k : IntKind) (op : IntegerBits) (a b : IntegerValue k) (count : Int)
    (inside : 0 ≤ count ∧ count < (integerWidth k : Int)) :
    ∃ v : IntegerValue k,
      integerBitsDelta k op a b count = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) := by
  unfold integerBitsDelta
  rw [ite_eq_right (by omega)]
  exact ⟨_,rfl,.integer k _⟩

/-- 剰余は0除算又は正常値、商はそれに値域外の overflow を加えて分ける。 -/
theorem divMod_delta_split (k : IntKind) (a b : IntegerValue k) (modulo : Bool) :
    if modulo then
      integerBinaryDelta k .mod a b = .err "DivisionByZero" ∨
      ∃ v : IntegerValue k, v.toInt = a.toInt.tmod b.toInt ∧
        integerBinaryDelta k .mod a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
        ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))
    else
      integerBinaryDelta k .intDiv a b = .err "DivisionByZero" ∨
      (integerBinaryDelta k .intDiv a b = .err "IntegerOverflow" ∧
        (a.toInt.tdiv b.toInt < k.min ∨ k.max < a.toInt.tdiv b.toInt)) ∨
      ∃ v : IntegerValue k, v.toInt = a.toInt.tdiv b.toInt ∧
        integerBinaryDelta k .intDiv a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
        ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) := by
  cases modulo with
  | true =>
    simp only [ite_true]
    by_cases hz : b.toInt = 0
    · exact .inl (divMod_zero k a b hz true)
    · exact .inr (modulo_normal k a b hz)
  | false =>
    simp only [Bool.false_eq_true,ite_false]
    by_cases hz : b.toInt = 0
    · exact .inl (divMod_zero k a b hz false)
    · right
      have eq : integerBinaryDelta k .intDiv a b =
          integerOutcome (integerChecked k (a.toInt.tdiv b.toInt)) := by
        unfold integerBinaryDelta
        change integerOutcome (k.checkedDivMod .intDiv a b) = _
        congr 1
        simpa only [Bool.false_eq_true,ite_false,ite_eq_right hz] using divMod_checked k a b false
      rw [eq]
      rcases integerChecked_split k _ with ⟨v,hv,_,he,rel⟩ | ⟨_,he,outside⟩
      · exact .inr ⟨v,hv,he,rel⟩
      · exact .inl ⟨he,outside⟩

private theorem tdiv_outside_minimum (k : IntKind) (a b : IntegerValue k)
    (nonzero : b.toInt ≠ 0)
    (outside : a.toInt.tdiv b.toInt < k.min ∨ k.max < a.toInt.tdiv b.toInt) :
    k.min < 0 ∧ a.toInt = k.min ∧ b.toInt = -1 := by
  have ha := a.toInt_bounds
  have hb := b.toInt_bounds
  have hlo : k.min ≤ 0 := by cases k <;> decide
  have hhi : 1 ≤ k.max := by cases k <;> decide
  have shape : k.min = 0 ∨ k.min + k.max = -1 := by cases k <;> decide
  have size := Int.natAbs_tdiv_le_natAbs a.toInt b.toInt
  have qlo := (Int.le_natAbs (a := -(a.toInt.tdiv b.toInt)))
  rw [Int.natAbs_neg] at qlo
  have qhi := (Int.le_natAbs (a := a.toInt.tdiv b.toInt))
  by_cases apos : 0 ≤ a.toInt
  · have aa := Int.natAbs_of_nonneg apos
    rcases shape with unsigned | signed
    · have bp : 0 ≤ b.toInt := by omega
      have qp := Int.tdiv_nonneg apos bp
      omega
    · omega
  · have an : a.toInt < 0 := by omega
    have aa : (a.toInt.natAbs : Int) = -a.toInt := by
      simpa only [Int.natAbs_neg] using Int.natAbs_of_nonneg (show 0 ≤ -a.toInt by omega)
    have signed : k.min + k.max = -1 := by omega
    by_cases bpos : 0 < b.toInt
    · have qp : a.toInt.tdiv b.toInt ≤ 0 := by
        have h := Int.tdiv_nonneg (a := -a.toInt) (b := b.toInt) (by omega) (by omega)
        rw [Int.neg_tdiv] at h
        omega
      omega
    · have bn : b.toInt < 0 := by omega
      have qp := Int.tdiv_nonneg_of_nonpos_of_nonpos (Int.le_of_lt an) (Int.le_of_lt bn)
      have qa := Int.natAbs_of_nonneg qp
      have ba : (b.toInt.natAbs : Int) = -b.toInt := by
        simpa only [Int.natAbs_neg] using Int.natAbs_of_nonneg (show 0 ≤ -b.toInt by omega)
      have prod : (a.toInt.tdiv b.toInt).natAbs * b.toInt.natAbs ≤ a.toInt.natAbs := by
        rw [Int.natAbs_tdiv]
        exact Nat.div_mul_le_self _ _
      have babs : b.toInt.natAbs = 1 := by
        by_cases h : b.toInt.natAbs = 1
        · exact h
        have two : 2 ≤ b.toInt.natAbs := by omega
        have twice := Nat.mul_le_mul_left (a.toInt.tdiv b.toInt).natAbs two
        omega
      have beq : b.toInt = -1 := by omega
      have qeq : a.toInt.tdiv b.toInt = -a.toInt := by simp [beq]
      exact ⟨by omega,by omega,beq⟩

/-- 非零除数の通常の商があふれるのは、符号付き最小値÷−1に限る。 -/
theorem division_overflow_iff (k : IntKind) (a b : IntegerValue k) (nonzero : b.toInt ≠ 0) :
    integerBinaryDelta k .intDiv a b = .err "IntegerOverflow" ↔
      k.min < 0 ∧ a.toInt = k.min ∧ b.toInt = -1 := by
  constructor
  · intro overflow
    have split := divMod_delta_split k a b false
    simp only [Bool.false_eq_true,ite_false] at split
    rcases split with zero | ⟨_,outside⟩ | ⟨v,_,normal,_⟩
    · rw [overflow] at zero
      have unequal : ("IntegerOverflow" : ErrKind) ≠ "DivisionByZero" := by decide
      exact False.elim (unequal (Outcome.err.inj zero))
    · exact tdiv_outside_minimum k a b nonzero outside
    · rw [overflow] at normal
      cases normal
  · rintro ⟨signed,minimum,minusOne⟩
    exact (signed_minimum_stops k signed a b minimum minusOne).2.2.1

example :
    let a : IntegerValue .integer8 := ⟨-128,by decide⟩
    let b : IntegerValue .integer8 := ⟨-1,by decide⟩
    integerBinaryDelta .integer8 .intDiv a b = .err "IntegerOverflow" ∧
      a.toInt = IntKind.min .integer8 ∧ b.toInt = -1 := by
  dsimp only
  have characterization := division_overflow_iff .integer8 ⟨-128,by decide⟩ ⟨-1,by decide⟩ (by decide)
  exact ⟨characterization.mpr ⟨by decide,rfl,rfl⟩,rfl,rfl⟩

example (k : IntKind) (a b : IntegerValue k) (nonzero : b.toInt ≠ 0)
    (overflow : integerBinaryDelta k .intDiv a b = .err "IntegerOverflow") :
    k.min < 0 ∧ a.toInt = k.min ∧ b.toInt = -1 :=
  (division_overflow_iff k a b nonzero).mp overflow

/-- 符号なしの絶対値は、元の同じ値である。 -/
theorem unsigned_absolute (k : IntKind) (unsigned : k.min = 0) (a : IntegerValue k) :
    integerAbsoluteDelta k a = .val (.const (embedConst (IntegerValue.toConst k a))) := by
  have ha : 0 ≤ a.toInt := by have := a.toInt_bounds; omega
  have hc := (integerChecked_normal k a.toInt a).mpr rfl
  simp only [integerAbsoluteDelta,Int.ofNat_natAbs_of_nonneg ha,hc,integerOutcome_normal]

/-- 加減乗の名前付き δ と、その同じ結果の正常・拒否を同時に返す。 -/
theorem named_binary_split (k : IntKind) (op : WidthBinary) (a b : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul) :
    ∃ out, integerDelta ("%" ++ integerModule k ++ match op with
        | .add => ".add" | .sub => ".subtract" | .mul => ".multiply" | _ => "") [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] = some out ∧
      ((∃ v : IntegerValue k, out = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
        ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
        out = .err "IntegerOverflow") :=
  ⟨_,integerDelta_binary k op a b supported,
    (binary_delta_split k op a b supported).imp id And.left⟩

example (k : IntKind) (a b : IntegerValue k) :
    ∃ out, integerDelta ("%" ++ integerModule k ++ ".add") [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] = some out ∧
      ((∃ v : IntegerValue k, out = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
        ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
        out = .err "IntegerOverflow") := named_binary_split k .add a b (.inl rfl)

example (r : Failure) : integerOutcome (.rejected r) = .err (integerFailure r) :=
  integerOutcome_rejected r

example (k : IntKind) (signed : k.min < 0) (a : IntegerValue k) :
    integerDelta ("%" ++ integerModule k ++ ".negate") [] [] []
      [.const (embedConst (IntegerValue.toConst k a))] = some (integerNegDelta k signed a) ∧
      ((∃ v : IntegerValue k, v.toInt = -a.toInt ∧
        integerNegDelta k signed a = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
        ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
      (integerNegDelta k signed a = .err "IntegerOverflow" ∧
        (-a.toInt < k.min ∨ k.max < -a.toInt))) :=
  ⟨integerDelta_negate k signed a,neg_delta_split k signed a⟩

example (k : IntKind) (a b : IntegerValue k) :
    integerBinaryDelta k .mod a b = .err "DivisionByZero" ∨
    ∃ v : IntegerValue k, v.toInt = a.toInt.tmod b.toInt ∧
      integerBinaryDelta k .mod a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) :=
  divMod_delta_split k a b true

example (k : IntKind) (a b : IntegerValue k) :
    integerBinaryDelta k .intDiv a b = .err "DivisionByZero" ∨
    (integerBinaryDelta k .intDiv a b = .err "IntegerOverflow" ∧
      (a.toInt.tdiv b.toInt < k.min ∨ k.max < a.toInt.tdiv b.toInt)) ∨
    ∃ v : IntegerValue k, v.toInt = a.toInt.tdiv b.toInt ∧
      integerBinaryDelta k .intDiv a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) :=
  divMod_delta_split k a b false

example (k : IntKind) (a b : IntegerValue k) (nonzero : b.toInt ≠ 0) :
    ∃ v : IntegerValue k, v.toInt = a.toInt.tmod b.toInt ∧
      integerBinaryDelta k .mod a b = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) := modulo_normal k a b nonzero

example (k : IntKind) (signed : k.min < 0) (a b : IntegerValue k)
    (minimum : a.toInt = k.min) (minusOne : b.toInt = -1) :
    integerDelta (integerModule k ++ ".absolute") [] [] []
        [.const (embedConst (IntegerValue.toConst k a))] = some (.err "IntegerOverflow") ∧
    integerDelta (integerModule k ++ ".floorDivide") [] [] []
        [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
      some (.err "IntegerOverflow") ∧
    ∃ v : IntegerValue k, v.toInt = 0 ∧
      integerDelta (integerModule k ++ ".floorModulo") [] [] []
        [.const (embedConst (IntegerValue.toConst k a)),.const (embedConst (IntegerValue.toConst k b))] =
      some (.val (.const (embedConst (IntegerValue.toConst k v)))) := by
  obtain ⟨ha,hq,_,v,hv,hr⟩ := signed_minimum_stops k signed a b minimum minusOne
  exact ⟨(integerDelta_absolute k a).trans (congrArg some ha),
    (integerDelta_floor k false a b).trans (congrArg some hq),v,hv,
    (integerDelta_floor k true a b).trans (congrArg some hr)⟩

example (k : IntKind) (unsigned : k.min = 0) (a : IntegerValue k) :
    integerDelta (integerModule k ++ ".absolute") [] [] []
      [.const (embedConst (IntegerValue.toConst k a))] =
      some (.val (.const (embedConst (IntegerValue.toConst k a)))) :=
  (integerDelta_absolute k a).trans (congrArg some (unsigned_absolute k unsigned a))

example (k : IntKind) (a : IntegerValue k) :
    (∃ v : IntegerValue k, v.toInt = (a.toInt.natAbs : Int) ∧
      integerAbsoluteDelta k a = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v)))) ∨
    (integerAbsoluteDelta k a = .err "IntegerOverflow" ∧ k.max < (a.toInt.natAbs : Int)) := absolute_split k a

example (k : IntKind) (a : IntegerValue k) (count : Benitoite.Release.Integer64Value)
    (outside : count.toInt < 0 ∨ (integerWidth k : Int) ≤ count.toInt) :
    integerDelta (integerModule k ++ ".shiftLeft") [] [] []
      [.const (embedConst (IntegerValue.toConst k a)),.const (.integer count)] =
      some (.err "ArgumentOutOfDomain") :=
  (integerDelta_shift k .shiftLeft a count (.inl rfl) (by intro h; cases h)).trans
    (congrArg some (shift_outside k .shiftLeft a a count.toInt (.inl rfl) outside))

example (k : IntKind) (a : IntegerValue k) (count : Int)
    (inside : 0 ≤ count ∧ count < (integerWidth k : Int)) :
    ∃ v : IntegerValue k,
      integerBitsDelta k .shiftRight a a count = .val (.const (embedConst (IntegerValue.toConst k v))) ∧
      ValueRel (.ofInteger k v) (.const (embedConst (IntegerValue.toConst k v))) :=
  shift_inside k .shiftRight a a count inside

example :
    let a : IntegerValue .integer8 := ⟨127,by decide⟩
    let b : IntegerValue .integer8 := ⟨1,by decide⟩
    integerBinaryDelta .integer8 .add a b = .err "IntegerOverflow" ∧
      IntKind.max .integer8 < a.toInt + b.toInt := by
  dsimp only
  have split := binary_delta_split .integer8 .add ⟨127,by decide⟩ ⟨1,by decide⟩ (.inl rfl)
  rcases split with ⟨v,normal,_⟩ | ⟨overflow,outside⟩
  · have stopped : integerBinaryDelta .integer8 .add ⟨127,by decide⟩ ⟨1,by decide⟩ =
        .err "IntegerOverflow" := rfl
    rw [stopped] at normal
    cases normal
  · exact ⟨overflow,outside.resolve_left (by decide)⟩

end Benitoite.Release.Refinement.StandardScalar
