import Benitoite.Interval.Eval

/-!
# 七種の整数の検査付き算術と区間

数学上の和と正常値の区間を分け、中間の失敗を後続の演算で取り消さない。
子の正常値がなければ、親の加算のあふれを新しく主張しない
（設計書 01-12「区間解析のInteger64加算」）。
整数除算と剰余は除数0だけを警告し、商・剰余の正常区間を伝播しない
（設計書 01-12「区間解析のInteger64除算と剰余」）。
減算と符号付き負号の局所の正常区間と失敗条件を定義する
（設計書 01-12「区間解析の減算と符号付き負号」）。
一点との積は符号で端点を交換し、一般の積はTopへ退く
（設計書 01-12「区間解析の定数倍」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

variable {kind : IntKind}

/-- 正常に得た値の区間と、子を含む失敗可能性。 -/
structure IntegerApprox (kind : IntKind := .integer64) where
  normal : Interval kind
  mayFail : Bool
  deriving DecidableEq, Repr

/-- 和の区間と指定した整数型の値域との交差。子Bottomはそのまま保つ。 -/
def addNormal : Interval kind → Interval kind → Interval kind
  | .bottom, _ | _, .bottom => .bottom
  | .closed lo hi _, .closed lo' hi' _ => normalize (lo + lo') (hi + hi') kind

/-- 正常引数が得られた場合に、この加算自身があふれる可能性。 -/
def addMayOverflow : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed lo hi _, .closed lo' hi' _ =>
      decide (lo + lo' < kind.min ∨ kind.max < hi + hi')

/-- 正常引数が存在し、そのすべての和が値域外となる条件。 -/
def addAlwaysOverflows : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed lo hi _, .closed lo' hi' _ =>
      decide (hi + hi' < kind.min ∨ kind.max < lo + lo')

/-- 左から評価する。右の失敗可能性は左に正常値がある場合だけ引き継ぐ。 -/
def addApprox (left right : IntegerApprox kind) : IntegerApprox kind :=
  ⟨addNormal left.normal right.normal,
    left.mayFail || (left.normal != .bottom &&
      (right.mayFail || addMayOverflow left.normal right.normal))⟩

/-- 加算の正常結果は数学上の和であり、検査はその表現可能性に一致する。 -/
theorem checkedAdd_normal_iff (left right value : IntegerValue kind) :
    IntKind.checkedAdd kind left right = .normal (.ofInteger kind value) ↔
      value.toInt = left.toInt + right.toInt := by
  unfold IntKind.checkedAdd
  dsimp only
  split
  · simp only [OperationResult.normal.injEq, ConcreteValue.ofInteger_inj]
    constructor
    · intro h; cases h; rfl
    · intro h; apply Subtype.ext; exact h.symm
  · constructor
    · intro h; cases h
    · intro h
      rename_i outside
      exact False.elim (outside (h ▸ value.toInt_bounds))

/-- 検査付き加算の拒否は、数学上の和が値域外であることと同値。 -/
theorem checkedAdd_overflow_iff (left right : IntegerValue kind) :
    IntKind.checkedAdd kind left right = .rejected .overflow ↔
      left.toInt + right.toInt < kind.min ∨ kind.max < left.toInt + right.toInt := by
  unfold IntKind.checkedAdd
  dsimp only
  split <;> simp_all <;> omega

/-- 正常な加算結果は、和と値域を交差した区間に所属する。 -/
theorem add_normal_sound {left right : Interval kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (normal : IntKind.checkedAdd kind a b = .normal (.ofInteger kind value)) :
    Mem value.toInt (addNormal left right) := by
  have sum := (checkedAdd_normal_iff a b value).mp normal
  have bounds := value.toInt_bounds
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      rw [addNormal, mem_normalize _ _ _ kind]
      simp only [Mem] at ha hb
      omega

/-- 実際の加算のあふれを、可能性の判定が見落とさない。 -/
theorem add_may_overflow_sound {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (overflow : IntKind.checkedAdd kind a b = .rejected .overflow) :
    addMayOverflow left right = true := by
  have outside := (checkedAdd_overflow_iff a b).mp overflow
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [addMayOverflow, decide_eq_true_eq]
      simp only [Mem] at ha hb
      omega

/-- 全域外の判定が真なら、正常に得た任意の二引数で加算があふれる。 -/
theorem add_always_overflows_sound {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (always : addAlwaysOverflows left right = true) :
    IntKind.checkedAdd kind a b = .rejected .overflow := by
  apply (checkedAdd_overflow_iff a b).mpr
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [addAlwaysOverflows, decide_eq_true_eq] at always
      simp only [Mem] at ha hb
      omega

/-- 正常評価した子の所属と加算の正常結果から、合成した近似への所属を得る。 -/
theorem add_approx_normal_sound {left right : IntegerApprox kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal)
    (normal : IntKind.checkedAdd kind a b = .normal (.ofInteger kind value)) :
    Mem value.toInt (addApprox left right).normal :=
  add_normal_sound ha hb normal

/-- 正常な二引数であふれた場合、合成した近似にも失敗可能性が残る。 -/
theorem add_approx_overflow_sound {left right : IntegerApprox kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal)
    (overflow : IntKind.checkedAdd kind a b = .rejected .overflow) :
    (addApprox left right).mayFail = true := by
  have possible := add_may_overflow_sound ha hb overflow
  have nonempty : left.normal ≠ .bottom := by intro h; rw [h] at ha; exact ha
  simp [addApprox, possible, nonempty]

/-- 子が非空なら、正常区間の消失と全域外の判定が一致する。 -/
theorem add_bottom_iff {left right : Interval kind}
    (hl : left ≠ .bottom) (hr : right ≠ .bottom) :
    addNormal left right = .bottom ↔ addAlwaysOverflows left right = true := by
  cases left with
  | bottom => contradiction
  | closed lo hi valid =>
    cases right with
    | bottom => contradiction
    | closed lo' hi' valid' =>
      simp only [addNormal, addAlwaysOverflows, decide_eq_true_eq, normalize]
      split
      · constructor
        · intro impossible; cases impossible
        · intro outside
          exfalso
          rename_i nonempty
          have low := Int.le_max_right kind.min (lo + lo')
          have high := Int.min_le_right kind.max (hi + hi')
          have low' := Int.le_max_left kind.min (lo + lo')
          have high' := Int.min_le_left kind.max (hi + hi')
          omega
      · simp only [true_iff]
        rename_i empty
        have ordered : lo + lo' ≤ hi + hi' := by omega
        have bounds := kind.bounds
        simp only [Int.max_le, Int.le_min] at empty
        omega

/-- 子Bottomから親のあふれ判定を作らず、正常値も復活させない。 -/
theorem add_bottom_child (other : Interval kind) :
    addNormal .bottom other = .bottom ∧ addNormal other .bottom = .bottom ∧
    addAlwaysOverflows .bottom other = false ∧
    addAlwaysOverflows other .bottom = false := by
  cases other <;> exact ⟨rfl, rfl, rfl, rfl⟩

/-- 差の区間と指定した整数型の値域との交差。子Bottomはそのまま保つ。 -/
def subNormal : Interval kind → Interval kind → Interval kind
  | .bottom, _ | _, .bottom => .bottom
  | .closed lo hi _, .closed lo' hi' _ => normalize (lo - hi') (hi - lo') kind

/-- 正常引数が得られた場合に、この減算自身があふれる可能性。 -/
def subMayOverflow : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed lo hi _, .closed lo' hi' _ =>
      decide (lo - hi' < kind.min ∨ kind.max < hi - lo')

/-- 正常引数が存在し、そのすべての差が値域外となる条件。 -/
def subAlwaysOverflows : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed lo hi _, .closed lo' hi' _ =>
      decide (hi - lo' < kind.min ∨ kind.max < lo - hi')

/-- 左から評価する。右の失敗可能性は左に正常値がある場合だけ引き継ぐ。 -/
def subApprox (left right : IntegerApprox kind) : IntegerApprox kind :=
  ⟨subNormal left.normal right.normal,
    left.mayFail || (left.normal != .bottom &&
      (right.mayFail || subMayOverflow left.normal right.normal))⟩

/-- 減算の正常結果は数学上の差であり、検査はその表現可能性に一致する。 -/
theorem checkedSub_normal_iff (left right value : IntegerValue kind) :
    IntKind.checkedSub kind left right = .normal (.ofInteger kind value) ↔
      value.toInt = left.toInt - right.toInt := by
  unfold IntKind.checkedSub
  dsimp only
  split
  · simp only [OperationResult.normal.injEq, ConcreteValue.ofInteger_inj]
    constructor
    · intro h; cases h; rfl
    · intro h; apply Subtype.ext; exact h.symm
  · constructor
    · intro h; cases h
    · intro h
      rename_i outside
      exact False.elim (outside (h ▸ value.toInt_bounds))

/-- 検査付き減算の拒否は、数学上の差が値域外であることと同値。 -/
theorem checkedSub_overflow_iff (left right : IntegerValue kind) :
    IntKind.checkedSub kind left right = .rejected .overflow ↔
      left.toInt - right.toInt < kind.min ∨ kind.max < left.toInt - right.toInt := by
  unfold IntKind.checkedSub
  dsimp only
  split <;> simp_all <;> omega

/-- 正常な減算結果は、差と値域を交差した区間に所属する。 -/
theorem sub_normal_sound {left right : Interval kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (normal : IntKind.checkedSub kind a b = .normal (.ofInteger kind value)) :
    Mem value.toInt (subNormal left right) := by
  have difference := (checkedSub_normal_iff a b value).mp normal
  have bounds := value.toInt_bounds
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      rw [subNormal, mem_normalize _ _ _ kind]
      simp only [Mem] at ha hb
      omega

/-- 実際の減算のあふれを、可能性の判定が見落とさない。 -/
theorem sub_may_overflow_sound {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (overflow : IntKind.checkedSub kind a b = .rejected .overflow) :
    subMayOverflow left right = true := by
  have outside := (checkedSub_overflow_iff a b).mp overflow
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [subMayOverflow, decide_eq_true_eq]
      simp only [Mem] at ha hb
      omega

/-- 全域外の判定が真なら、正常に得た任意の二引数で減算があふれる。 -/
theorem sub_always_overflows_sound {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (always : subAlwaysOverflows left right = true) :
    IntKind.checkedSub kind a b = .rejected .overflow := by
  apply (checkedSub_overflow_iff a b).mpr
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [subAlwaysOverflows, decide_eq_true_eq] at always
      simp only [Mem] at ha hb
      omega

/-- 正常評価した子の所属と減算の正常結果から、合成した近似への所属を得る。 -/
theorem sub_approx_normal_sound {left right : IntegerApprox kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal)
    (normal : IntKind.checkedSub kind a b = .normal (.ofInteger kind value)) :
    Mem value.toInt (subApprox left right).normal :=
  sub_normal_sound ha hb normal

/-- 正常な二引数であふれた場合、合成した近似にも失敗可能性が残る。 -/
theorem sub_approx_overflow_sound {left right : IntegerApprox kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal)
    (overflow : IntKind.checkedSub kind a b = .rejected .overflow) :
    (subApprox left right).mayFail = true := by
  have possible := sub_may_overflow_sound ha hb overflow
  have nonempty : left.normal ≠ .bottom := by intro h; rw [h] at ha; exact ha
  simp [subApprox, possible, nonempty]

/-- 子が非空なら、正常区間の消失と全域外の判定が一致する。 -/
theorem sub_bottom_iff {left right : Interval kind}
    (hl : left ≠ .bottom) (hr : right ≠ .bottom) :
    subNormal left right = .bottom ↔ subAlwaysOverflows left right = true := by
  cases left with
  | bottom => contradiction
  | closed lo hi valid =>
    cases right with
    | bottom => contradiction
    | closed lo' hi' valid' =>
      simp only [subNormal, subAlwaysOverflows, decide_eq_true_eq, normalize]
      split
      · constructor
        · intro impossible; cases impossible
        · intro outside
          exfalso
          rename_i nonempty
          have low := Int.le_max_right kind.min (lo - hi')
          have high := Int.min_le_right kind.max (hi - lo')
          have low' := Int.le_max_left kind.min (lo - hi')
          have high' := Int.min_le_left kind.max (hi - lo')
          omega
      · simp only [true_iff]
        rename_i empty
        have ordered : lo - hi' ≤ hi - lo' := by omega
        have bounds := kind.bounds
        simp only [Int.max_le, Int.le_min] at empty
        omega

/-- 子Bottomから親のあふれ判定を作らず、正常値も復活させない。 -/
theorem sub_bottom_child (other : Interval kind) :
    subNormal .bottom other = .bottom ∧ subNormal other .bottom = .bottom ∧
    subAlwaysOverflows .bottom other = false ∧
    subAlwaysOverflows other .bottom = false := by
  cases other <;> exact ⟨rfl, rfl, rfl, rfl⟩

/-- 定数の符号に従い、積の端点の向きを定める。 -/
def scaleBounds (k lo hi : Int) : Int × Int :=
  if 0 ≤ k then (k * lo, k * hi) else (k * hi, k * lo)

/-- 左右どちらかが一点の場合だけ積の端点を返す。両辺が一点なら左を使う。 -/
def mulBounds (lo hi lo' hi' : Int) : Option (Int × Int) :=
  if lo = hi then some (scaleBounds lo lo' hi')
  else if lo' = hi' then some (scaleBounds lo' lo hi)
  else none

/-- 子Bottomを保ち、一点のない積はTopへ退く。 -/
def mulNormal : Interval kind → Interval kind → Interval kind
  | .bottom, _ | _, .bottom => .bottom
  | .closed lo hi _, .closed lo' hi' _ =>
      match mulBounds lo hi lo' hi' with
      | some (low, high) => normalize low high kind
      | none => top kind

/-- 未対応の一般の積では、演算自身が失敗しないとは判定しない。 -/
def mulMayOverflow : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed lo hi _, .closed lo' hi' _ =>
      match mulBounds lo hi lo' hi' with
      | some (low, high) => decide (low < kind.min ∨ kind.max < high)
      | none => true

/-- 正常引数が存在し、定数倍の結果区間が全域外である場合だけ真にする。 -/
def mulAlwaysOverflows : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed lo hi _, .closed lo' hi' _ =>
      match mulBounds lo hi lo' hi' with
      | some (low, high) => decide (high < kind.min ∨ kind.max < low)
      | none => false

/-- 左からの到達と子の失敗可能性を保ち、定数倍自身の可能性を合成する。 -/
def mulApprox (left right : IntegerApprox kind) : IntegerApprox kind :=
  ⟨mulNormal left.normal right.normal,
    left.mayFail || (left.normal != .bottom &&
      (right.mayFail || mulMayOverflow left.normal right.normal))⟩

/-- 定数の符号による端点の交換で、所属値の積を挟む。 -/
theorem scaleBounds_sound {k lo hi value : Int} (inside : lo ≤ value ∧ value ≤ hi) :
    (scaleBounds k lo hi).1 ≤ k * value ∧ k * value ≤ (scaleBounds k lo hi).2 := by
  unfold scaleBounds
  split
  · rename_i nonneg
    exact ⟨Int.mul_le_mul_of_nonneg_left inside.1 nonneg,
      Int.mul_le_mul_of_nonneg_left inside.2 nonneg⟩
  · rename_i negative
    have nonpos : k ≤ 0 := by omega
    exact ⟨Int.mul_le_mul_of_nonpos_left nonpos inside.2,
      Int.mul_le_mul_of_nonpos_left nonpos inside.1⟩

/-- 左右どちらが一点でも、端点は二つの所属値の積を挟む。 -/
theorem mulBounds_sound {lo hi lo' hi' a b low high : Int}
    (ha : lo ≤ a ∧ a ≤ hi) (hb : lo' ≤ b ∧ b ≤ hi')
    (bounds : mulBounds lo hi lo' hi' = some (low, high)) :
    low ≤ a * b ∧ a * b ≤ high := by
  unfold mulBounds at bounds
  split at bounds
  · rename_i singleton
    have point : a = lo := by omega
    have enclosed := scaleBounds_sound (k := lo) hb
    simp only [Option.some.injEq] at bounds
    rw [bounds] at enclosed
    simpa only [point] using enclosed
  · split at bounds
    · rename_i singleton
      have point : b = lo' := by omega
      have enclosed := scaleBounds_sound (k := lo') ha
      simp only [Option.some.injEq] at bounds
      rw [bounds] at enclosed
      simpa only [point, Int.mul_comm a lo'] using enclosed
    · cases bounds

/-- 乗算の正常結果は数学上の積であり、検査はその表現可能性に一致する。 -/
theorem checkedMul_normal_iff (left right value : IntegerValue kind) :
    IntKind.checkedMul kind left right = .normal (.ofInteger kind value) ↔
      value.toInt = left.toInt * right.toInt := by
  unfold IntKind.checkedMul
  dsimp only
  split
  · simp only [OperationResult.normal.injEq, ConcreteValue.ofInteger_inj]
    constructor
    · intro h; cases h; rfl
    · intro h; apply Subtype.ext; exact h.symm
  · constructor
    · intro h; cases h
    · intro h
      rename_i outside
      exact False.elim (outside (h ▸ value.toInt_bounds))

/-- 検査付き乗算の拒否は、数学上の積が値域外であることと同値。 -/
theorem checkedMul_overflow_iff (left right : IntegerValue kind) :
    IntKind.checkedMul kind left right = .rejected .overflow ↔
      left.toInt * right.toInt < kind.min ∨ kind.max < left.toInt * right.toInt := by
  unfold IntKind.checkedMul
  dsimp only
  split <;> simp_all <;> omega

/-- 正常な乗算結果は、定数倍の正常区間または未対応のTopに所属する。 -/
theorem mul_normal_sound {left right : Interval kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (normal : IntKind.checkedMul kind a b = .normal (.ofInteger kind value)) :
    Mem value.toInt (mulNormal left right) := by
  have product := (checkedMul_normal_iff a b value).mp normal
  have bounded := value.toInt_bounds
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [Mem] at ha hb
      cases bounds : mulBounds lo hi lo' hi' with
      | none => simpa only [mulNormal, bounds] using (mem_top _ kind).mpr bounded
      | some ends =>
        obtain ⟨low, high⟩ := ends
        have enclosed := mulBounds_sound ha hb bounds
        simp only [mulNormal, bounds, mem_normalize]
        omega

/-- 実際の乗算のあふれを可能性の判定が見落とさない。 -/
theorem mul_may_overflow_sound {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (overflow : IntKind.checkedMul kind a b = .rejected .overflow) :
    mulMayOverflow left right = true := by
  have outside := (checkedMul_overflow_iff a b).mp overflow
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [Mem] at ha hb
      cases bounds : mulBounds lo hi lo' hi' with
      | none => simp only [mulMayOverflow, bounds]
      | some ends =>
        obtain ⟨low, high⟩ := ends
        have enclosed := mulBounds_sound ha hb bounds
        simp only [mulMayOverflow, bounds, decide_eq_true_eq]
        omega

/-- 全域外と判定した定数倍は、所属する任意の正常引数であふれる。 -/
theorem mul_always_overflows_sound {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (always : mulAlwaysOverflows left right = true) :
    IntKind.checkedMul kind a b = .rejected .overflow := by
  apply (checkedMul_overflow_iff a b).mpr
  cases left with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    cases right with
    | bottom => exact False.elim hb
    | closed lo' hi' valid' =>
      simp only [Mem] at ha hb
      cases bounds : mulBounds lo hi lo' hi' with
      | none => simp only [mulAlwaysOverflows, bounds, Bool.false_eq_true] at always
      | some ends =>
        obtain ⟨low, high⟩ := ends
        have enclosed := mulBounds_sound ha hb bounds
        simp only [mulAlwaysOverflows, bounds, decide_eq_true_eq] at always
        omega

/-- 子の正常値の所属と乗算の正常結果から、合成近似への所属を得る。 -/
theorem mul_approx_normal_sound {left right : IntegerApprox kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal)
    (normal : IntKind.checkedMul kind a b = .normal (.ofInteger kind value)) :
    Mem value.toInt (mulApprox left right).normal :=
  mul_normal_sound ha hb normal

/-- 正常引数で乗算があふれた場合、合成した近似にも失敗可能性が残る。 -/
theorem mul_approx_overflow_sound {left right : IntegerApprox kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal)
    (overflow : IntKind.checkedMul kind a b = .rejected .overflow) :
    (mulApprox left right).mayFail = true := by
  have possible := mul_may_overflow_sound ha hb overflow
  have nonempty : left.normal ≠ .bottom := by intro h; rw [h] at ha; exact ha
  simp [mulApprox, possible, nonempty]

/-- 子が非空なら、正常区間の消失と全域外の判定が一致する。 -/
theorem mul_bottom_iff {left right : Interval kind}
    (hl : left ≠ .bottom) (hr : right ≠ .bottom) :
    mulNormal left right = .bottom ↔ mulAlwaysOverflows left right = true := by
  cases left with
  | bottom => contradiction
  | closed lo hi valid =>
    cases right with
    | bottom => contradiction
    | closed lo' hi' valid' =>
      cases bounds : mulBounds lo hi lo' hi' with
      | none =>
        simp only [mulNormal, mulAlwaysOverflows, bounds, Bool.false_eq_true, iff_false]
        intro empty
        have member := (mem_top lo kind).mpr ⟨valid.1, by omega⟩
        rw [empty] at member
        exact member
      | some ends =>
        obtain ⟨low, high⟩ := ends
        have enclosed := mulBounds_sound (a := lo) (b := lo')
          ⟨Int.le_refl _, valid.2.1⟩ ⟨Int.le_refl _, valid'.2.1⟩ bounds
        have ordered : low ≤ high := by omega
        simp only [mulNormal, mulAlwaysOverflows, bounds, decide_eq_true_eq, normalize]
        split
        · constructor
          · intro impossible; cases impossible
          · intro outside
            exfalso
            rename_i nonempty
            have lowBound := Int.le_max_right kind.min low
            have highBound := Int.min_le_right kind.max high
            omega
        · simp only [true_iff]
          rename_i empty
          have limits := kind.bounds
          simp only [Int.max_le, Int.le_min] at empty
          omega

/-- 子Bottomに乗算自身の警告を重ねず、正常値を復活させない。 -/
theorem mul_bottom_child (other : Interval kind) :
    mulNormal .bottom other = .bottom ∧ mulNormal other .bottom = .bottom ∧
    mulMayOverflow .bottom other = false ∧ mulMayOverflow other .bottom = false ∧
    mulAlwaysOverflows .bottom other = false ∧
    mulAlwaysOverflows other .bottom = false := by
  cases other <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- 符号付きの負号の正常区間。端点の向きを交換し、値域と交差する。 -/
def negNormal (_signed : kind.min < 0) : Interval kind → Interval kind
  | .bottom => .bottom
  | .closed lo hi _ => normalize (-hi) (-lo) kind

/-- 正常引数を得た負号自身のあふれ可能性。 -/
def negMayOverflow (_signed : kind.min < 0) : Interval kind → Bool
  | .bottom => false
  | .closed lo hi _ => decide (-hi < kind.min ∨ kind.max < -lo)

/-- 正常引数が存在し、そのすべての負号が値域外となる条件。 -/
def negAlwaysOverflows (_signed : kind.min < 0) : Interval kind → Bool
  | .bottom => false
  | .closed lo hi _ => decide (-lo < kind.min ∨ kind.max < -hi)

/-- 子の失敗可能性を保ち、負号自身のあふれ可能性を加える。 -/
def negApprox (signed : kind.min < 0) (child : IntegerApprox kind) : IntegerApprox kind :=
  ⟨negNormal signed child.normal, child.mayFail || negMayOverflow signed child.normal⟩

variable (signed : kind.min < 0)

/-- 検査付き負号の正常結果は数学上の負号に一致する。 -/
theorem checkedNeg_normal_iff (child value : IntegerValue kind) :
    IntKind.checkedNeg kind signed child = .normal (.ofInteger kind value) ↔
      value.toInt = -child.toInt := by
  unfold IntKind.checkedNeg
  dsimp only
  split
  · simp only [OperationResult.normal.injEq, ConcreteValue.ofInteger_inj]
    constructor
    · intro h; cases h; rfl
    · intro h; apply Subtype.ext; exact h.symm
  · constructor
    · intro h; cases h
    · intro h
      rename_i outside
      exact False.elim (outside (h ▸ value.toInt_bounds))

/-- 検査付き負号の拒否は、数学上の負号が値域外であることと同値。 -/
theorem checkedNeg_overflow_iff (child : IntegerValue kind) :
    IntKind.checkedNeg kind signed child = .rejected .overflow ↔
      -child.toInt < kind.min ∨ kind.max < -child.toInt := by
  unfold IntKind.checkedNeg
  dsimp only
  split <;> simp_all <;> omega

/-- 負号の正常結果は、端点を交換して値域と交差した区間に所属する。 -/
theorem neg_normal_sound {child : Interval kind} {a value : IntegerValue kind}
    (ha : Mem a.toInt child)
    (normal : IntKind.checkedNeg kind signed a = .normal (.ofInteger kind value)) :
    Mem value.toInt (negNormal signed child) := by
  have negative := (checkedNeg_normal_iff signed a value).mp normal
  have bounds := value.toInt_bounds
  cases child with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    rw [negNormal, mem_normalize _ _ _ kind]
    simp only [Mem] at ha
    omega

/-- 実際の負号のあふれを、可能性の判定が見落とさない。 -/
theorem neg_may_overflow_sound {child : Interval kind} {a : IntegerValue kind}
    (ha : Mem a.toInt child)
    (overflow : IntKind.checkedNeg kind signed a = .rejected .overflow) :
    negMayOverflow signed child = true := by
  have outside := (checkedNeg_overflow_iff signed a).mp overflow
  cases child with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    simp only [negMayOverflow, decide_eq_true_eq]
    simp only [Mem] at ha
    omega

/-- 全域外なら、所属する任意の正常引数の負号があふれる。 -/
theorem neg_always_overflows_sound {child : Interval kind} {a : IntegerValue kind}
    (ha : Mem a.toInt child) (always : negAlwaysOverflows signed child = true) :
    IntKind.checkedNeg kind signed a = .rejected .overflow := by
  apply (checkedNeg_overflow_iff signed a).mpr
  cases child with
  | bottom => exact False.elim ha
  | closed lo hi valid =>
    simp only [negAlwaysOverflows, decide_eq_true_eq] at always
    simp only [Mem] at ha
    omega

/-- 子の正常値の所属と検査付き負号の正常結果から、合成近似への所属を得る。 -/
theorem neg_approx_normal_sound {child : IntegerApprox kind} {a value : IntegerValue kind}
    (ha : Mem a.toInt child.normal)
    (normal : IntKind.checkedNeg kind signed a = .normal (.ofInteger kind value)) :
    Mem value.toInt (negApprox signed child).normal :=
  neg_normal_sound signed ha normal

/-- 正常引数で負号があふれた場合、合成した近似にも失敗可能性が残る。 -/
theorem neg_approx_overflow_sound {child : IntegerApprox kind} {a : IntegerValue kind}
    (ha : Mem a.toInt child.normal)
    (overflow : IntKind.checkedNeg kind signed a = .rejected .overflow) :
    (negApprox signed child).mayFail = true := by
  have possible := neg_may_overflow_sound signed ha overflow
  simp [negApprox, possible]

/-- 子が非空なら、負号の正常区間の消失と全域外の判定が一致する。 -/
theorem neg_bottom_iff {child : Interval kind} (nonempty : child ≠ .bottom) :
    negNormal signed child = .bottom ↔ negAlwaysOverflows signed child = true := by
  cases child with
  | bottom => contradiction
  | closed lo hi valid =>
    simp only [negNormal, negAlwaysOverflows, decide_eq_true_eq, normalize]
    split
    · constructor
      · intro impossible; cases impossible
      · intro outside
        exfalso
        rename_i inhabited
        have low := Int.le_max_right kind.min (-hi)
        have high := Int.min_le_right kind.max (-lo)
        have low' := Int.le_max_left kind.min (-hi)
        have high' := Int.min_le_left kind.max (-lo)
        omega
    · simp only [true_iff]
      rename_i empty
      have bounds := kind.bounds
      simp only [Int.max_le, Int.le_min] at empty
      omega

/-- 子Bottomから負号のあふれを主張せず、正常値を復活させない。 -/
theorem neg_bottom_child :
    negNormal signed .bottom = .bottom ∧ negMayOverflow signed .bottom = false ∧
    negAlwaysOverflows signed .bottom = false := ⟨rfl, rfl, rfl⟩

/-- 商・剰余の正常値はTopへ退く。子Bottomから正常値を復活させない。 -/
def divModNormal : Interval kind → Interval kind → Interval kind
  | .bottom, _ | _, .bottom => .bottom
  | .closed _ _ _, .closed _ _ _ => top kind

/-- 二引数に正常値があり、整数の除数の区間が一点0の場合だけ警告する。 -/
def divModAlwaysZero (op : BinOp) : Interval kind → Interval kind → Bool
  | .bottom, _ | _, .bottom => false
  | .closed _ _ _, .closed lo hi _ => decide (IntegerDivisionOp op ∧ lo = 0 ∧ hi = 0)

/-- 除算自身の失敗を否定せず、子の失敗可能性は左からの到達に従って合成する。 -/
def divModApprox (left right : IntegerApprox kind) : IntegerApprox kind :=
  ⟨divModNormal left.normal right.normal,
    left.mayFail || (left.normal != .bottom && (right.mayFail || right.normal != .bottom))⟩

/-- 整数除算・剰余の除数0による拒否は、正常な除数が0であることと同値。 -/
theorem checkedDivMod_zero_iff {op : BinOp} (target : IntegerDivisionOp op)
    (a b : IntegerValue kind) :
    IntKind.checkedDivMod kind op a b = .rejected .zeroDivisor ↔ b.toInt = 0 := by
  unfold IntKind.checkedDivMod
  simp only [ite_eq_left target]
  split
  · simp_all
  · split
    · simp_all
    · split <;> simp_all

/-- 除数0の判定が真になる演算はintDivかmodだけである。 -/
theorem divMod_always_zero_target {op} {left right : Interval kind}
    (always : divModAlwaysZero op left right = true) : IntegerDivisionOp op := by
  cases left <;> cases right <;> simp_all [divModAlwaysZero]

/-- 正常に得た除数が判定区間に属するなら、警告の原因どおり拒否する。 -/
theorem divMod_always_zero_sound {op} {left right : Interval kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right)
    (always : divModAlwaysZero op left right = true) :
    IntKind.checkedDivMod kind op a b = .rejected .zeroDivisor := by
  apply (checkedDivMod_zero_iff (divMod_always_zero_target always) a b).mpr
  cases left <;> cases right <;> simp_all [divModAlwaysZero, Mem] <;> omega

/-- 商・剰余の正常結果はTopに所属する。子Bottomは正常評価の前提と両立しない。 -/
theorem divMod_normal_sound {left right : Interval kind} {a b value : IntegerValue kind}
    (ha : Mem a.toInt left) (hb : Mem b.toInt right) :
    Mem value.toInt (divModNormal left right) := by
  cases left <;> cases right <;> first
    | contradiction
    | exact (mem_top _ kind).mpr value.toInt_bounds

/-- 正常な二引数を得た除算について、失敗可能性を偽にしない。 -/
theorem divMod_approx_may_fail {left right : IntegerApprox kind} {a b : IntegerValue kind}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal) :
    (divModApprox left right).mayFail = true := by
  have hl : left.normal ≠ .bottom := by intro h; rw [h] at ha; exact ha
  have hr : right.normal ≠ .bottom := by intro h; rw [h] at hb; exact hb
  simp [divModApprox, hl, hr]

/-- 子Bottomには親の除数0の警告を重ねず、正常値も復活させない。 -/
theorem divMod_bottom_child (op : BinOp) (other : Interval kind) :
    divModNormal .bottom other = .bottom ∧ divModNormal other .bottom = .bottom ∧
    divModAlwaysZero op .bottom other = false ∧
    divModAlwaysZero op other .bottom = false := by
  cases other <;> exact ⟨rfl, rfl, rfl, rfl⟩

-- 七種の上限を独立した十進値で指定し、一部のあふれと全域外を区別する。
example :
    ([ (IntKind.integer8, 127), (.integer16, 32767), (.integer32, 2147483647),
       (.integer64, 9223372036854775807), (.unsignedInteger16, 65535),
       (.unsignedInteger32, 4294967295), (.unsignedInteger64, 18446744073709551615) ] :
      List (IntKind × Int)).all (fun (kind, hi) => decide (
        mulApprox ⟨normalize 2 2 kind, false⟩ ⟨normalize 0 hi kind, false⟩ =
          ⟨normalize 0 hi kind, true⟩ ∧
        mulAlwaysOverflows (normalize 2 2 kind) (normalize 0 hi kind) = false ∧
        mulApprox ⟨normalize hi hi kind, false⟩ ⟨normalize 2 2 kind, false⟩ =
          ⟨.bottom, true⟩ ∧
        mulAlwaysOverflows (normalize hi hi kind) (normalize 2 2 kind) = true ∧
        mulApprox ⟨normalize 0 0 kind, false⟩ ⟨top kind, false⟩ =
          ⟨normalize 0 0 kind, false⟩ ∧
        mulApprox ⟨top kind, false⟩ ⟨normalize 0 0 kind, false⟩ =
          ⟨normalize 0 0 kind, false⟩)) = true := by decide +kernel

-- 負の定数では端点を交換する。符号付き四種の最小値の(-1)倍は全域外になる。
example :
    mulApprox ⟨normalize (-2) (-2), false⟩ ⟨normalize (-3) 5, false⟩ =
      ⟨normalize (-10) 6, false⟩ ∧
    mulApprox ⟨normalize (-3) 5, false⟩ ⟨normalize (-2) (-2), false⟩ =
      ⟨normalize (-10) 6, false⟩ ∧
    ([ (IntKind.integer8, -128, 127), (.integer16, -32768, 32767),
       (.integer32, -2147483648, 2147483647),
       (.integer64, -9223372036854775808, 9223372036854775807) ] :
      List (IntKind × Int × Int)).all (fun (kind, lo, hi) => decide (
        mulApprox ⟨normalize lo (lo + 1) kind, false⟩ ⟨normalize (-1) (-1) kind, false⟩ =
          ⟨normalize hi hi kind, true⟩ ∧
        mulAlwaysOverflows (normalize lo (lo + 1) kind) (normalize (-1) (-1) kind) = false ∧
        mulNormal (normalize (-1) (-1) kind) (normalize lo lo kind) = .bottom ∧
        mulAlwaysOverflows (normalize (-1) (-1) kind) (normalize lo lo kind) = true ∧
        mulApprox ⟨normalize (-1) (-1) kind, false⟩ ⟨normalize 0 hi kind, false⟩ =
          ⟨normalize (-hi) 0 kind, false⟩ ∧
        mulApprox ⟨normalize lo (-1) kind, false⟩ ⟨normalize 2 2 kind, false⟩ =
          ⟨normalize lo (-2) kind, true⟩ ∧
        mulAlwaysOverflows (normalize lo (-1) kind) (normalize 2 2 kind) = false ∧
        mulNormal (normalize lo (lo + 1) kind) (normalize 2 2 kind) = .bottom ∧
        mulAlwaysOverflows (normalize lo (lo + 1) kind) (normalize 2 2 kind) = true)) = true := by
  decide +kernel

-- 両辺が複数値なら、積が全域外に見える場合も一般の積を精密化しない。
-- 子Bottomと左からの到達を保ち、0倍でも子の失敗を取り消さない。
example :
    mulApprox (kind := .integer8) ⟨normalize 100 101 .integer8, false⟩
      ⟨normalize 2 3 .integer8, false⟩ = ⟨top .integer8, true⟩ ∧
    mulAlwaysOverflows (normalize 100 101 .integer8) (normalize 2 3 .integer8) = false ∧
    mulApprox ⟨normalize 2 3, false⟩ ⟨normalize 4 5, false⟩ = ⟨top, true⟩ ∧
    mulApprox ⟨.bottom, true⟩ ⟨normalize 0 0, false⟩ = ⟨.bottom, true⟩ ∧
    mulApprox ⟨.bottom, false⟩ ⟨top, true⟩ = ⟨.bottom, false⟩ ∧
    mulApprox ⟨normalize 0 0, false⟩ ⟨.bottom, true⟩ = ⟨.bottom, true⟩ ∧
    mulApprox ⟨normalize 0 0, false⟩ ⟨top, true⟩ = ⟨normalize 0 0, true⟩ ∧
    mulApprox ⟨top, true⟩ ⟨normalize 0 0, false⟩ = ⟨normalize 0 0, true⟩ ∧
    mulAlwaysOverflows .bottom top = false ∧
    mulAlwaysOverflows top .bottom = false := by decide +kernel

-- 最大u64の積はi128には収まらない。数学上の正確な積と正常域の消失を別々に確かめる。
example :
    (18446744073709551615 : Int) * 18446744073709551615 =
      340282366920938463426481119284349108225 ∧
    (170141183460469231731687303715884105727 : Int) <
      340282366920938463426481119284349108225 ∧
    mulBounds 18446744073709551615 18446744073709551615
      18446744073709551615 18446744073709551615 =
      some (340282366920938463426481119284349108225,
        340282366920938463426481119284349108225) ∧
    mulApprox ⟨normalize 18446744073709551615 18446744073709551615 .unsignedInteger64, false⟩
      ⟨normalize 18446744073709551615 18446744073709551615 .unsignedInteger64, false⟩ =
      ⟨.bottom, true⟩ ∧
    mulAlwaysOverflows
      (normalize 18446744073709551615 18446744073709551615 .unsignedInteger64)
      (normalize 18446744073709551615 18446744073709551615 .unsignedInteger64) = true := by
  decide +kernel

-- 具体値の検査も区間の期待値とは独立に指定する。
example :
    IntKind.checkedMul .unsignedInteger64
      ⟨18446744073709551615, by decide⟩ ⟨18446744073709551615, by decide⟩ =
      .rejected .overflow ∧
    IntKind.checkedMul .unsignedInteger64
      ⟨18446744073709551615, by decide⟩ ⟨1, by decide⟩ =
      .normal (.unsignedInteger64 ⟨18446744073709551615, by decide⟩) ∧
    IntKind.checkedMul .integer8 ⟨-128, by decide⟩ ⟨-1, by decide⟩ = .rejected .overflow ∧
    IntKind.checkedMul .integer8 ⟨-2, by decide⟩ ⟨5, by decide⟩ =
      .normal (.integer8 ⟨-10, by decide⟩) ∧
    IntKind.checkedMul .integer64 ⟨-9223372036854775808, by decide⟩ ⟨0, by decide⟩ =
      .normal (.integer ⟨0, by decide⟩) := by
  repeat' constructor

-- 符号付き四種の両端を十進値で指定し、減算の一部のあふれと全域外を区別する。
example :
    ([ (IntKind.integer8, -128, 127), (.integer16, -32768, 32767),
       (.integer32, -2147483648, 2147483647),
       (.integer64, -9223372036854775808, 9223372036854775807) ] :
      List (IntKind × Int × Int)).all (fun (kind, lo, hi) => decide (
        subApprox ⟨normalize lo (lo + 1) kind, false⟩ ⟨normalize 1 1 kind, false⟩ =
          ⟨normalize lo lo kind, true⟩ ∧
        subAlwaysOverflows (normalize lo (lo + 1) kind) (normalize 1 1 kind) = false ∧
        subNormal (normalize lo lo kind) (normalize 1 1 kind) = .bottom ∧
        subAlwaysOverflows (normalize lo lo kind) (normalize 1 1 kind) = true ∧
        subApprox ⟨normalize (hi - 1) hi kind, false⟩ ⟨normalize (-1) (-1) kind, false⟩ =
          ⟨normalize hi hi kind, true⟩ ∧
        subAlwaysOverflows (normalize (hi - 1) hi kind) (normalize (-1) (-1) kind) = false ∧
        subNormal (normalize hi hi kind) (normalize (-1) (-1) kind) = .bottom ∧
        subAlwaysOverflows (normalize hi hi kind) (normalize (-1) (-1) kind) = true)) = true := by
  decide +kernel

-- 符号なしの下限0への切り詰めと最大u64からの正常な差を確認する。
example :
    ([ (IntKind.unsignedInteger16, 65535), (.unsignedInteger32, 4294967295),
       (.unsignedInteger64, 18446744073709551615) ] : List (IntKind × Int)).all
      (fun (kind, hi) => decide (
        subApprox ⟨normalize 0 1 kind, false⟩ ⟨normalize 1 1 kind, false⟩ =
          ⟨normalize 0 0 kind, true⟩ ∧
        subAlwaysOverflows (normalize 0 1 kind) (normalize 1 1 kind) = false ∧
        subNormal (normalize 0 0 kind) (normalize 1 1 kind) = .bottom ∧
        subAlwaysOverflows (normalize 0 0 kind) (normalize 1 1 kind) = true ∧
        subApprox ⟨normalize hi hi kind, false⟩ ⟨normalize hi hi kind, false⟩ =
          ⟨normalize 0 0 kind, false⟩)) = true := by decide +kernel

-- 負号は四種の最小値だけで全域外となり、最小値を含む広い区間は一部が成功する。
example :
    ([ (IntKind.integer8, -128, 127), (.integer16, -32768, 32767),
       (.integer32, -2147483648, 2147483647),
       (.integer64, -9223372036854775808, 9223372036854775807) ] :
      List (IntKind × Int × Int)).all (fun (kind, lo, hi) =>
        if signed : kind.min < 0 then decide (
          negApprox signed ⟨normalize lo (lo + 1) kind, false⟩ =
            ⟨normalize hi hi kind, true⟩ ∧
          negAlwaysOverflows signed (normalize lo (lo + 1) kind) = false ∧
          negNormal signed (normalize lo lo kind) = .bottom ∧
          negAlwaysOverflows signed (normalize lo lo kind) = true ∧
          negApprox signed ⟨top kind, false⟩ = ⟨normalize (-hi) hi kind, true⟩ ∧
          negAlwaysOverflows signed (top kind) = false)
        else false) = true := by decide +kernel

-- 具体演算の独立した値で符号・幅・あふれの拒否を確かめる。
example :
    IntKind.checkedSub .unsignedInteger64
      ⟨18446744073709551615, by decide⟩ ⟨1, by decide⟩ =
      .normal (.unsignedInteger64 ⟨18446744073709551614, by decide⟩) ∧
    IntKind.checkedSub .unsignedInteger16 ⟨0, by decide⟩ ⟨1, by decide⟩ =
      .rejected .overflow ∧
    IntKind.checkedSub .integer8 ⟨127, by decide⟩ ⟨-1, by decide⟩ =
      .rejected .overflow ∧
    IntKind.checkedSub .integer64 ⟨-9223372036854775808, by decide⟩ ⟨1, by decide⟩ =
      .rejected .overflow ∧
    IntKind.checkedNeg .integer8 (by decide) ⟨-128, by decide⟩ = .rejected .overflow ∧
    IntKind.checkedNeg .integer16 (by decide) ⟨-32768, by decide⟩ = .rejected .overflow ∧
    IntKind.checkedNeg .integer32 (by decide) ⟨-2147483648, by decide⟩ = .rejected .overflow ∧
    IntKind.checkedNeg .integer64 (by decide) ⟨-9223372036854775808, by decide⟩ =
      .rejected .overflow ∧
    IntKind.checkedNeg .integer8 (by decide) ⟨-127, by decide⟩ =
      .normal (.integer8 ⟨127, by decide⟩) ∧
    IntKind.checkedNeg .integer64 (by decide) ⟨0, by decide⟩ =
      .normal (.integer ⟨0, by decide⟩) := by
  repeat' constructor

-- 同じ区間から引いても相関を仮定しない。子の失敗・左からの到達とBottomを保つ。
example :
    subApprox ⟨normalize 2 4, false⟩ ⟨normalize 2 4, false⟩ =
      ⟨normalize (-2) 2, false⟩ ∧
    subApprox ⟨normalize (-2) 1, false⟩ ⟨normalize 2 3, false⟩ =
      ⟨normalize (-5) (-1), false⟩ ∧
    subApprox ⟨.bottom, true⟩ ⟨normalize (-1) (-1), false⟩ = ⟨.bottom, true⟩ ∧
    subApprox ⟨.bottom, false⟩ ⟨top, true⟩ = ⟨.bottom, false⟩ ∧
    subApprox ⟨normalize 1 1, false⟩ ⟨.bottom, true⟩ = ⟨.bottom, true⟩ ∧
    subAlwaysOverflows .bottom top = false ∧
    subAlwaysOverflows top .bottom = false ∧
    negApprox (kind := .integer64) (by decide) ⟨normalize (-3) 5, false⟩ =
      ⟨normalize (-5) 3, false⟩ ∧
    negApprox (kind := .integer64) (by decide) ⟨normalize 0 0, true⟩ =
      ⟨normalize 0 0, true⟩ ∧
    negApprox (kind := .integer64) (by decide) ⟨.bottom, true⟩ = ⟨.bottom, true⟩ ∧
    negAlwaysOverflows (kind := .integer64) (by decide) .bottom = false := by decide +kernel

-- 各幅の上限は独立した十進値で指定し、一部のあふれと全域外を区別する。
example :
    ([ (IntKind.integer8, 127), (.integer16, 32767), (.integer32, 2147483647),
       (.integer64, 9223372036854775807), (.unsignedInteger16, 65535),
       (.unsignedInteger32, 4294967295), (.unsignedInteger64, 18446744073709551615) ] :
      List (IntKind × Int)).all (fun (kind, hi) => decide (
        addNormal (normalize (hi - 1) hi kind) (normalize 1 1 kind) = normalize hi hi kind ∧
        addMayOverflow (normalize (hi - 1) hi kind) (normalize 1 1 kind) = true ∧
        addAlwaysOverflows (normalize (hi - 1) hi kind) (normalize 1 1 kind) = false ∧
        addNormal (normalize hi hi kind) (normalize 1 1 kind) = .bottom ∧
        addAlwaysOverflows (normalize hi hi kind) (normalize 1 1 kind) = true ∧
        divModAlwaysZero .intDiv (top kind) (normalize 0 0 kind) = true ∧
        divModNormal (top kind) (normalize 1 1 kind) = top kind)) = true := by decide +kernel

-- 符号なしの0を保ち、最大u64の直前からの加算と剰余も数学上のIntで検査する。
example :
    IntKind.checkedAdd .unsignedInteger64
      ⟨18446744073709551614, by decide⟩ ⟨1, by decide⟩ =
      .normal (.unsignedInteger64 ⟨18446744073709551615, by decide⟩) ∧
    IntKind.checkedAdd .unsignedInteger64
      ⟨18446744073709551615, by decide⟩ ⟨1, by decide⟩ = .rejected .overflow ∧
    IntKind.checkedDivMod .unsignedInteger64 .mod
      ⟨18446744073709551615, by decide⟩ ⟨2, by decide⟩ =
      .normal (.unsignedInteger64 ⟨1, by decide⟩) ∧
    IntKind.checkedDivMod .unsignedInteger16 .intDiv
      ⟨65535, by decide⟩ ⟨0, by decide⟩ = .rejected .zeroDivisor := by
  repeat' constructor

-- 0を含む区間と一点0を区別し、実数の / を除外する。
example :
    divModAlwaysZero .intDiv (normalize (-2) 3) (normalize 0 0) = true ∧
    divModAlwaysZero .mod top (normalize 0 0) = true ∧
    divModAlwaysZero .intDiv top (normalize (-1) 1) = false ∧
    divModAlwaysZero .mod top (normalize (-1) 1) = false ∧
    divModAlwaysZero .div top (normalize 0 0) = false ∧
    divModNormal top (normalize 0 0) = top ∧
    divModNormal (normalize 7 7) (normalize 2 2) = top := by decide

-- 独立した具体値で、0方向への切り捨てと最小値の商・剰余の差を確かめる。
example :
    checkedDivMod .intDiv ⟨-7, by decide⟩ ⟨2, by decide⟩ =
      .normal (.integer ⟨-3, by decide⟩) ∧
    checkedDivMod .mod ⟨-7, by decide⟩ ⟨2, by decide⟩ =
      .normal (.integer ⟨-1, by decide⟩) ∧
    checkedDivMod .mod ⟨7, by decide⟩ ⟨-2, by decide⟩ =
      .normal (.integer ⟨1, by decide⟩) ∧
    checkedDivMod .intDiv ⟨min64, by constructor <;> decide⟩ ⟨-1, by decide⟩ =
      .rejected .overflow ∧
    checkedDivMod .mod ⟨min64, by constructor <;> decide⟩ ⟨-1, by decide⟩ =
      .normal (.integer ⟨0, by decide⟩) ∧
    checkedDivMod .intDiv ⟨min64, by constructor <;> decide⟩ ⟨0, by decide⟩ =
      .rejected .zeroDivisor ∧
    checkedDivMod .mod ⟨min64, by constructor <;> decide⟩ ⟨0, by decide⟩ =
      .rejected .zeroDivisor := by
  repeat' constructor

-- 端点と期待値は加算の解析関数で生成せず、独立に指定する。
-- 一部のあふれでは成功域を切り詰め、警告の条件を真にしない。
example :
    addNormal (normalize (max64 - 1) max64) (normalize 1 1) = normalize max64 max64 ∧
    addMayOverflow (normalize (max64 - 1) max64) (normalize 1 1) = true ∧
    addAlwaysOverflows (normalize (max64 - 1) max64) (normalize 1 1) = false ∧
    addNormal (normalize min64 (min64 + 1)) (normalize (-1) (-1)) = normalize min64 min64 ∧
    addMayOverflow (normalize min64 (min64 + 1)) (normalize (-1) (-1)) = true ∧
    addAlwaysOverflows (normalize min64 (min64 + 1)) (normalize (-1) (-1)) = false := by decide

-- 値域内・全域外を両方向で照合し、一部のあふれと区別する。
example :
    addApprox ⟨normalize (-2) 1, false⟩ ⟨normalize 2 3, false⟩ =
      ⟨normalize 0 4, false⟩ ∧
    addNormal (normalize max64 max64) (normalize 1 1) = .bottom ∧
    addAlwaysOverflows (normalize max64 max64) (normalize 1 1) = true ∧
    addNormal (normalize min64 min64) (normalize (-1) (-1)) = .bottom ∧
    addAlwaysOverflows (normalize min64 min64) (normalize (-1) (-1)) = true := by decide

-- (max64+1)+(-1) は、内側の失敗を相殺して正常な max64 に戻さない。
-- 親はBottomを保ち、親自身のあふれを新しく主張せず、子の失敗可能性を残す。
example :
    let inner := addApprox ⟨normalize max64 max64, false⟩ ⟨normalize 1 1, false⟩
    inner = ⟨.bottom, true⟩ ∧
    addApprox inner ⟨normalize (-1) (-1), false⟩ = ⟨.bottom, true⟩ ∧
    addAlwaysOverflows inner.normal (normalize (-1) (-1)) = false ∧
    addApprox ⟨normalize 1 1, false⟩ ⟨.bottom, true⟩ = ⟨.bottom, true⟩ ∧
    addAlwaysOverflows (normalize 1 1) .bottom = false := by decide

-- 実際の評価でも左の中間失敗で止まり、到達記録には内側の加算だけを残す。
example (env : ConcreteEnv) :
    let outerKey : OperationKey := ⟨"Example.intermediate", 0⟩
    let innerKey : OperationKey := ⟨"Example.intermediate", 1⟩
    let maxExpr : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
    let oneExpr : Expr := .literal (.integer ⟨1, by decide⟩)
    let minusOne : Expr := .negInt ⟨1, by decide⟩
    let inner : Expr := .binary .add (.base .integer) maxExpr oneExpr
    let trace : EvalTrace := [⟨innerKey, .binary .add (.base .integer),
      [.integer ⟨max64, by constructor <;> decide⟩, .integer ⟨1, by decide⟩],
      .rejected .overflow⟩]
    EvalPartial env ⟨.binary .add (.base .integer) inner minusOne,
      .base .integer, outerKey⟩ (.failed .overflow) trace ∧
    ∀ event ∈ trace, event.key ≠ outerKey := by
  dsimp only
  constructor
  · apply EvalPartial.addLeftAbrupt
    · exact EvalPartial.add env ⟨"Example.intermediate", 1⟩
        _ _ _ _ [] []
        (.integer _ _ _) (.integer _ _ _)
    · trivial
  · simp [OperationKey.mk.injEq]

-- 右の子の失敗と、左からのreturnでも親の加算を記録しない。
example (env : ConcreteEnv) (key : OperationKey) :
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let unknown : Expr := .funName "Example.unknown" [] []
    EvalPartial env ⟨.binary .add (.base .integer) one unknown, .base .integer, key⟩
      (.failed .unknown) [] ∧
    EvalPartial env ⟨.binary .add (.base .integer)
      (.returnE (.base .integer) one) unknown, .base .integer, key⟩
      (.returned (.integer ⟨1, by decide⟩)) [] := by
  dsimp only
  constructor
  · exact .addRightAbrupt env key _ _ _ _ [] []
      (.integer _ _ _) (.unknownFailed _ _ (Or.inl (Or.inr rfl))) trivial
  · exact .addLeftAbrupt env key _ _ _ []
      (.returnE env (childKey key []) (.base .integer)
        (.literal (.integer ⟨1, by decide⟩)) (.base .integer) _ []
        (.integer _ _ ⟨1, by decide⟩)) trivial

end Benitoite.Interval
