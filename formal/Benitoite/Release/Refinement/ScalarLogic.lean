import Benitoite.Release.Refinement.ClosedEvaluation

/-! # scalar比較で使う順序とIEEEの符号・ゼロ -/
namespace Benitoite.Release.Refinement

private theorem zero_mod_iff {x m : Nat} (hm : 0 < m) (hx : x < 2*m) :
    x % m = 0 ↔ x = 0 ∨ x = m := by
  have hq : x / m < 2 := (Nat.div_lt_iff_lt_mul hm).mpr hx
  have he := Nat.mod_add_div x m
  constructor
  · intro hz
    have hh := Nat.le_one_iff_eq_zero_or_eq_one.mp (Nat.le_of_lt_succ hq)
    rcases hh with hh | hh
    · rw [hh, hz] at he
      simp only [Nat.zero_add, Nat.mul_zero] at he
      exact Or.inl he.symm
    · rw [hh, hz] at he
      simp only [Nat.zero_add, Nat.mul_one] at he
      exact Or.inr he.symm
  · rintro (rfl | rfl) <;> simp

/-- 数として等しい二つのゼロを同じ順序の位置へ写す。 -/
def ieeeRank (fraction exponent x : Nat) : Int :=
  let m := 2^(fraction+exponent)
  if x % m = 0 then 0 else if x < m then Int.ofNat x else -Int.ofNat x

private theorem ieeeRank_compare {f e x y : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e))
    (hnx : ieeeNaN f e x = false) (hny : ieeeNaN f e y = false) (o : Comparison) :
    ieeeCompare f e x y o = o.fromEqLt
      (decide (ieeeRank f e x = ieeeRank f e y))
      (decide (ieeeRank f e x < ieeeRank f e y))
      (decide (ieeeRank f e y < ieeeRank f e x)) := by
  have hm : 0 < 2^(f+e) := Nat.two_pow_pos _
  have zx := zero_mod_iff hm hx
  have zy := zero_mod_iff hm hy
  have sx := Nat.div_eq_zero_iff_lt (x := x) hm
  have sy := Nat.div_eq_zero_iff_lt (x := y) hm
  simp only [ieeeCompare, hnx, hny, Bool.false_or, Bool.false_eq_true, ↓reduceIte,
    ieeeZero, ieeeRank]
  by_cases hxz : x % 2^(f+e) = 0 <;>
    by_cases hyz : y % 2^(f+e) = 0 <;>
    by_cases hxs : x < 2^(f+e) <;>
    by_cases hys : y < 2^(f+e)
  all_goals cases o <;> apply Bool.eq_iff_iff.mpr <;>
    simp_all [Comparison.fromEqLt] <;> omega

theorem ieeeCompare_rank {f e x y : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (o : Comparison) :
    ieeeCompare f e x y o =
      if ieeeNaN f e x || ieeeNaN f e y then o == .ne else
        o.fromEqLt (decide (ieeeRank f e x = ieeeRank f e y))
          (decide (ieeeRank f e x < ieeeRank f e y))
          (decide (ieeeRank f e y < ieeeRank f e x)) := by
  by_cases hxnan : ieeeNaN f e x = true
  · simp [ieeeCompare, hxnan]
  by_cases hynan : ieeeNaN f e y = true
  · simp [ieeeCompare, hynan]
  have hxfalse : ieeeNaN f e x = false := by cases h : ieeeNaN f e x <;> simp_all
  have hyfalse : ieeeNaN f e y = false := by cases h : ieeeNaN f e y <;> simp_all
  simp only [hxfalse, hyfalse, Bool.false_or, Bool.false_eq_true, ↓reduceIte]
  exact ieeeRank_compare hx hy hxfalse hyfalse o

theorem cross_le_trans {x y z a b c : Int}
    (ha : 0 < a) (hb : 0 < b) (hc : 0 < c)
    (hxy : x*b ≤ y*a) (hyz : y*c ≤ z*b) : x*c ≤ z*a := by
  have h1 := Int.mul_le_mul_of_nonneg_right hxy (Int.le_of_lt hc)
  have h2 := Int.mul_le_mul_of_nonneg_right hyz (Int.le_of_lt ha)
  have hmid : y*a*c = y*c*a := by ac_rfl
  have hout : x*b*c ≤ z*b*a := Int.le_trans h1 (hmid ▸ h2)
  have hleft : x*b*c = (x*c)*b := by ac_rfl
  have hright : z*b*a = (z*a)*b := by ac_rfl
  rw [hleft, hright] at hout
  exact Int.le_of_mul_le_mul_right hout hb

theorem cross_lt_le_trans {x y z a b c : Int}
    (ha : 0 < a) (hb : 0 < b) (hc : 0 < c)
    (hxy : x*b < y*a) (hyz : y*c ≤ z*b) : x*c < z*a := by
  have h1 := Int.mul_lt_mul_of_pos_right hxy hc
  have h2 := Int.mul_le_mul_of_nonneg_right hyz (Int.le_of_lt ha)
  have hmid : y*a*c = y*c*a := by ac_rfl
  have hout : x*b*c < z*b*a := Int.lt_of_lt_of_le h1 (hmid ▸ h2)
  have hleft : x*b*c = (x*c)*b := by ac_rfl
  have hright : z*b*a = (z*a)*b := by ac_rfl
  rw [hleft, hright] at hout
  exact Int.lt_of_mul_lt_mul_right hout (Int.le_of_lt hb)

theorem cross_le_lt_trans {x y z a b c : Int}
    (ha : 0 < a) (hb : 0 < b) (hc : 0 < c)
    (hxy : x*b ≤ y*a) (hyz : y*c < z*b) : x*c < z*a := by
  have h1 := Int.mul_le_mul_of_nonneg_right hxy (Int.le_of_lt hc)
  have h2 := Int.mul_lt_mul_of_pos_right hyz ha
  have hmid : y*a*c = y*c*a := by ac_rfl
  have hout : x*b*c < z*b*a := Int.lt_of_le_of_lt h1 (hmid ▸ h2)
  have hleft : x*b*c = (x*c)*b := by ac_rfl
  have hright : z*b*a = (z*a)*b := by ac_rfl
  rw [hleft, hright] at hout
  exact Int.lt_of_mul_lt_mul_right hout (Int.le_of_lt hb)

inductive ScalarRule where
  | eqSymm | eqTrans | ltTrans | leTrans | ltLe | leLt
  deriving DecidableEq

def ScalarRule.test {α : Type} (cmp : Comparison → α → α → Bool)
    (a b c : α) : ScalarRule → Bool
  | .eqSymm => !(cmp .eq a b) || cmp .eq b a
  | .eqTrans => !(cmp .eq a b && cmp .eq b c) || cmp .eq a c
  | .ltTrans => !(cmp .lt a b && cmp .lt b c) || cmp .lt a c
  | .leTrans => !(cmp .le a b && cmp .le b c) || cmp .le a c
  | .ltLe => !(cmp .lt a b && cmp .le b c) || cmp .lt a c
  | .leLt => !(cmp .le a b && cmp .lt b c) || cmp .lt a c

private theorem int_order_test (a b c : Int) (r : ScalarRule) :
    r.test (fun o x y => o.fromEqLt (decide (x=y)) (decide (x<y)) (decide (y<x)))
      a b c = true := by
  cases r <;> simp only [ScalarRule.test, Comparison.fromEqLt]
  all_goals apply Bool.eq_iff_iff.mpr
  all_goals simp only [Bool.or_eq_true, Bool.not_eq_true', Bool.and_eq_false_iff, Bool.or_eq_false_iff,
    decide_eq_true_eq, decide_eq_false_iff_not, iff_true]
  all_goals omega

theorem ieee_order_test {f e x y z : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (hz : z < 2 * 2^(f+e))
    (r : ScalarRule) : r.test (fun o a b => ieeeCompare f e a b o) x y z = true := by
  cases r <;> simp only [ScalarRule.test]
  all_goals simp only [ieeeCompare_rank hx hy, ieeeCompare_rank hy hx,
    ieeeCompare_rank hy hz, ieeeCompare_rank hx hz]
  all_goals cases hnx : ieeeNaN f e x <;> cases hny : ieeeNaN f e y <;>
    cases hnz : ieeeNaN f e z <;>
    simp [Comparison.fromEqLt] <;> omega

private def decimalCompare (o : Comparison) (a b : Int × Nat) : Bool :=
  o.fromEqLt (decide (a.1*10^b.2 = b.1*10^a.2))
    (decide (a.1*10^b.2 < b.1*10^a.2)) (decide (b.1*10^a.2 < a.1*10^b.2))

theorem decimal_order_test (a b c : Int × Nat) (r : ScalarRule) :
    r.test decimalCompare a b c = true := by
  have ha : (0 : Int) < 10^a.2 := Int.pow_pos (by decide)
  have hb : (0 : Int) < 10^b.2 := Int.pow_pos (by decide)
  have hc : (0 : Int) < 10^c.2 := Int.pow_pos (by decide)
  cases r <;> simp only [ScalarRule.test, decimalCompare, Comparison.fromEqLt]
  all_goals apply Bool.eq_iff_iff.mpr
  all_goals simp only [Bool.or_eq_true, Bool.not_eq_true', Bool.and_eq_false_iff, Bool.or_eq_false_iff,
    decide_eq_true_eq, decide_eq_false_iff_not, iff_true]
  · omega
  · by_cases h1 : a.1*10^b.2 = b.1*10^a.2
    · by_cases h2 : b.1*10^c.2 = c.1*10^b.2
      · have h3 := cross_le_trans ha hb hc (Int.le_of_eq h1) (Int.le_of_eq h2)
        have h4 := cross_le_trans hc hb ha (Int.le_of_eq h2.symm) (Int.le_of_eq h1.symm)
        omega
      · omega
    · omega
  · by_cases h1 : a.1*10^b.2 < b.1*10^a.2
    · by_cases h2 : b.1*10^c.2 < c.1*10^b.2
      · have := cross_lt_le_trans ha hb hc h1 (Int.le_of_lt h2)
        omega
      · omega
    · omega
  · by_cases h1 : a.1*10^b.2 ≤ b.1*10^a.2
    · by_cases h2 : b.1*10^c.2 ≤ c.1*10^b.2
      · have := cross_le_trans ha hb hc h1 h2
        omega
      · omega
    · omega
  · by_cases h1 : a.1*10^b.2 < b.1*10^a.2
    · by_cases h2 : b.1*10^c.2 ≤ c.1*10^b.2
      · have := cross_lt_le_trans ha hb hc h1 h2
        omega
      · omega
    · omega
  · by_cases h1 : a.1*10^b.2 ≤ b.1*10^a.2
    · by_cases h2 : b.1*10^c.2 < c.1*10^b.2
      · have := cross_le_lt_trans ha hb hc h1 h2
        omega
      · omega
    · omega

def orderedScalarSorts : List «Sort» := [.character, .decimal, .float64, .float32]
def equalityScalarSorts : List «Sort» := [.boolean, .string, .unit]
def scalarSorts : List «Sort» := orderedScalarSorts ++ equalityScalarSorts

theorem observation_order_test {s : «Sort»} (hs : s ∈ orderedScalarSorts)
    (a b c : Observation) (ha : a.sort = s) (hb : b.sort = s) (hc : c.sort = s)
    (r : ScalarRule) : r.test (fun o x y => x.compare o y) a b c = true := by
  cases a <;> simp only [Observation.sort] at ha <;> rw [← ha] at hs hb hc <;>
    simp only [orderedScalarSorts, List.mem_cons, List.not_mem_nil, or_false,
      reduceCtorEq, false_or] at hs
  all_goals try contradiction
  all_goals cases b <;> simp only [Observation.sort, reduceCtorEq] at hb <;> try contradiction
  all_goals cases c <;> simp only [Observation.sort, reduceCtorEq] at hc <;> try contradiction
  case character.character.character x y z =>
    have h := int_order_test (Int.ofNat x.toNat) (Int.ofNat y.toNat) (Int.ofNat z.toNat) r
    cases r <;> simpa [ScalarRule.test, Observation.compare, Comparison.fromEqLt,
      Int.ofNat_inj, Char.toNat_inj] using h
  case decimal.decimal.decimal x sx y sy z sz =>
    have h := decimal_order_test (x,sx) (y,sy) (z,sz) r
    cases r <;> simpa [ScalarRule.test, decimalCompare, Observation.compare,
      Comparison.fromEqLt] using h
  case float64.float64.float64 x y z =>
    exact ieee_order_test (UInt64.toNat_lt x) (UInt64.toNat_lt y) (UInt64.toNat_lt z) r
  case float32.float32.float32 x y z =>
    exact ieee_order_test (UInt32.toNat_lt x) (UInt32.toNat_lt y) (UInt32.toNat_lt z) r

theorem observation_equality_test {s : «Sort»} (hs : s ∈ equalityScalarSorts)
    (a b c : Observation) (ha : a.sort = s) (hb : b.sort = s) (hc : c.sort = s)
    (r : ScalarRule) (hr : r = .eqSymm ∨ r = .eqTrans) :
    r.test (fun o x y => x.compare o y) a b c = true := by
  cases a <;> simp only [Observation.sort] at ha <;> rw [← ha] at hs hb hc <;>
    simp only [equalityScalarSorts, List.mem_cons, List.not_mem_nil, or_false,
      reduceCtorEq, false_or] at hs
  all_goals try contradiction
  all_goals cases b <;> simp only [Observation.sort, reduceCtorEq] at hb <;> try contradiction
  all_goals cases c <;> simp only [Observation.sort, reduceCtorEq] at hc <;> try contradiction
  all_goals rcases hr with rfl | rfl
  all_goals simp [ScalarRule.test, Observation.compare, Comparison.fromEqLt]
  all_goals apply Classical.byContradiction
  all_goals intro h
  all_goals simp only [not_or, Classical.not_not] at h
  all_goals first | exact h.2 h.1.symm | exact h.2 (h.1.1.trans h.1.2)

theorem observation_eq_ne {s : «Sort»} (hs : s ∈ scalarSorts)
    (a b : Observation) (ha : a.sort = s) (hb : b.sort = s) :
    a.compare .ne b = !(a.compare .eq b) := by
  cases a <;> simp only [Observation.sort] at ha <;> rw [← ha] at hs hb <;>
    simp only [scalarSorts, orderedScalarSorts, equalityScalarSorts,
      List.mem_append, List.mem_cons, List.not_mem_nil, or_false,
      reduceCtorEq, false_or, or_self] at hs
  all_goals try contradiction
  all_goals cases b <;> simp only [Observation.sort, reduceCtorEq] at hb <;> try contradiction
  all_goals simp only [Observation.compare, ieeeCompare]
  all_goals first | rfl | (split <;> rfl)

/-- 指数部の最大値を除いた範囲は、Infinityの符号を除いたbitsより小さい。 -/
theorem ieee_finite_parts (f e x : Nat) :
    ieeeClass f e x .finite = decide (x % 2^(f+e) < (2^e-1)*2^f) := by
  have hf : 0 < 2^f := Nat.two_pow_pos _
  have he : 0 < 2^e := Nat.two_pow_pos _
  have hr : x % 2^(f+e) < 2^e*2^f := by
    simpa only [Nat.pow_add, Nat.mul_comm] using Nat.mod_lt x (Nat.two_pow_pos (f+e))
  have hq : x % 2^(f+e) / 2^f < 2^e := (Nat.div_lt_iff_lt_mul hf).mpr hr
  have hd : x / 2^f % 2^e = x % 2^(f+e) / 2^f := by
    rw [Nat.pow_add, Nat.mod_mul_right_div_self]
  unfold ieeeClass
  simp only [hd]
  apply decide_eq_decide.mpr
  calc
    x % 2^(f+e) / 2^f ≠ 2^e-1 ↔ x % 2^(f+e) / 2^f < 2^e-1 := by
      generalize x % 2^(f+e) / 2^f = q at hq ⊢
      omega
    _ ↔ x % 2^(f+e) < (2^e-1)*2^f := Nat.div_lt_iff_lt_mul hf

theorem ieee_nan_parts (f e x : Nat) :
    ieeeNaN f e x = decide ((2^e-1)*2^f < x % 2^(f+e)) := by
  have hd : x / 2^f % 2^e = x % 2^(f+e) / 2^f := by
    rw [Nat.pow_add, Nat.mod_mul_right_div_self]
  have hm : x % 2^f = (x % 2^(f+e)) % 2^f := by
    rw [Nat.pow_add, Nat.mod_mul_right_mod]
  have hf := ieee_finite_parts f e x
  have hfin : (x / 2^f % 2^e ≠ 2^e-1) ↔ x % 2^(f+e) < (2^e-1)*2^f := by
    simpa only [ieeeClass, decide_eq_true_eq] using (Bool.eq_iff_iff.mp hf)
  have he := Nat.mod_add_div (x % 2^(f+e)) (2^f)
  unfold ieeeNaN
  apply decide_eq_decide.mpr
  constructor
  · rintro ⟨hq, hn⟩
    rw [hd] at hq
    rw [hq] at he
    rw [hm] at hn
    have hp : 2^f*(2^e-1) = (2^e-1)*2^f := Nat.mul_comm _ _
    omega
  · intro hr
    have hq : x / 2^f % 2^e = 2^e-1 := by
      apply Classical.byContradiction
      intro h
      have := hfin.mp h
      omega
    refine ⟨hq, ?_⟩
    rw [hd] at hq
    rw [hq] at he
    rw [hm]
    have hp : 2^f*(2^e-1) = (2^e-1)*2^f := Nat.mul_comm _ _
    omega

theorem ieee_class_parts (f e x : Nat) (c : FloatClass) :
    ieeeClass f e x c = match c with
    | .finite => decide (x % 2^(f+e) < (2^e-1)*2^f)
    | .nan => decide ((2^e-1)*2^f < x % 2^(f+e))
    | .positiveInfinity => !(x / 2^(f+e) != 0) && decide (x % 2^(f+e) = (2^e-1)*2^f)
    | .negativeInfinity => (x / 2^(f+e) != 0) && decide (x % 2^(f+e) = (2^e-1)*2^f)
    | .positiveZero => !(x / 2^(f+e) != 0) && decide (x % 2^(f+e) = 0)
    | .negativeZero => (x / 2^(f+e) != 0) && decide (x % 2^(f+e) = 0) := by
  cases c
  · exact ieee_finite_parts f e x
  · exact ieee_nan_parts f e x
  all_goals rfl

def ieeePartition (f e x : Nat) : Bool :=
  let fin := ieeeClass f e x .finite
  let nan := ieeeClass f e x .nan
  let pos := ieeeClass f e x .positiveInfinity
  let neg := ieeeClass f e x .negativeInfinity
  (fin || nan || pos || neg) &&
    !(fin && (nan || pos || neg)) && !(nan && (pos || neg)) && !(pos && neg)

def ieeeClassTest (f e x y : Nat) (c : FloatClass) : Bool :=
  ieeePartition f e x && match c with
  | .finite => !(ieeeClass f e x .finite) ||
      (!(ieeeClass f e x .nan) && !(ieeeClass f e x .positiveInfinity) &&
        !(ieeeClass f e x .negativeInfinity))
  | .nan => !(ieeeClass f e x .nan) ||
      (!(ieeeCompare f e x y .eq) && !(ieeeCompare f e x y .lt) &&
       !(ieeeCompare f e x y .le) && !(ieeeCompare f e x y .gt) && !(ieeeCompare f e x y .ge))
  | .positiveInfinity => !(ieeeClass f e x .positiveInfinity) ||
      !(ieeeClass f e y .finite) ||
        (ieeeCompare f e x y .gt && !(ieeeCompare f e x y .le))
  | .negativeInfinity => !(ieeeClass f e x .negativeInfinity) ||
      !(ieeeClass f e y .finite) ||
        (ieeeCompare f e x y .lt && !(ieeeCompare f e x y .ge))
  | .positiveZero => !(ieeeClass f e x .positiveZero) ||
      (ieeeClass f e x .finite && ieeeCompare f e x (2^(f+e)) .eq &&
        !(ieeeClass f e x .negativeZero))
  | .negativeZero => !(ieeeClass f e x .negativeZero) ||
      (ieeeClass f e x .finite && ieeeCompare f e x 0 .eq &&
        !(ieeeClass f e x .positiveZero))

theorem ieee_partition (f e x : Nat) : ieeePartition f e x = true := by
  unfold ieeePartition
  simp only [ieee_class_parts]
  have horder : x % 2^(f+e) < (2^e-1)*2^f ∨
      x % 2^(f+e) = (2^e-1)*2^f ∨ (2^e-1)*2^f < x % 2^(f+e) := by omega
  rcases horder with h | h | h
  all_goals cases hs : (x / 2^(f+e) != 0) <;> simp [h] <;> omega

theorem ieee_class_test {f e x y : Nat} (he : 0 < e)
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (c : FloatClass) :
    ieeeClassTest f e x y c = true := by
  have hm : 0 < 2^(f+e) := Nat.two_pow_pos _
  have hi : 0 < (2^e-1)*2^f :=
    Nat.mul_pos (by have := Nat.one_lt_two_pow (Nat.ne_of_gt he); omega) (Nat.two_pow_pos _)
  have hil : (2^e-1)*2^f < 2^(f+e) := by
    rw [Nat.pow_add, Nat.mul_comm (2^f)]
    apply Nat.mul_lt_mul_of_pos_right _ (Nat.two_pow_pos _)
    have := Nat.two_pow_pos e
    omega
  have zx := zero_mod_iff hm hx
  have zy := zero_mod_iff hm hy
  have sx := Nat.div_eq_zero_iff_lt (x := x) hm
  have sy := Nat.div_eq_zero_iff_lt (x := y) hm
  have xp := Nat.mod_add_div x (2^(f+e))
  have yp := Nat.mod_add_div y (2^(f+e))
  have xq := Nat.le_one_iff_eq_zero_or_eq_one.mp
    (Nat.le_of_lt_succ ((Nat.div_lt_iff_lt_mul hm).mpr hx))
  have yq := Nat.le_one_iff_eq_zero_or_eq_one.mp
    (Nat.le_of_lt_succ ((Nat.div_lt_iff_lt_mul hm).mpr hy))
  rcases xq with xq | xq <;> rcases yq with yq | yq
  all_goals rw [xq] at xp; rw [yq] at yp
  all_goals simp only [Nat.mul_zero, Nat.mul_one, Nat.add_zero] at xp yp
  all_goals cases c <;>
    simp only [ieeeClassTest, ieee_partition, Bool.true_and,
      ieeeCompare_rank hx hy, ieeeCompare_rank hx (show 2^(f+e) < 2*2^(f+e) by omega),
      ieeeCompare_rank hx (show 0 < 2*2^(f+e) by omega),
      ieee_class_parts, ieee_nan_parts,
      ieeeRank, xq, Nat.zero_mod, Nat.mod_self,
      Comparison.fromEqLt]
  all_goals simp_all <;> omega

theorem observation_order_complement {s : «Sort»} (hs : s = .character ∨ s = .decimal)
    (a b : Observation) (ha : a.sort = s) (hb : b.sort = s) :
    a.compare .ge b = !(a.compare .lt b) ∧ a.compare .gt b = !(a.compare .le b) := by
  rcases hs with rfl | rfl
  all_goals cases a <;> simp only [Observation.sort, reduceCtorEq] at ha <;> try contradiction
  all_goals cases b <;> simp only [Observation.sort, reduceCtorEq] at hb <;> try contradiction
  all_goals constructor <;> apply Bool.eq_iff_iff.mpr <;>
    simp [Observation.compare, Comparison.fromEqLt, ← Char.toNat_inj] <;> omega

end Benitoite.Release.Refinement
