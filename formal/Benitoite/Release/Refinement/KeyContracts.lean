import Benitoite.Release.Refinement.ClosedKeys
import Benitoite.Release.Refinement.ObservationOrder
import Benitoite.Release.Refinement.MeasureContracts

/-! # 有限な鍵の構造、正常な大きさと観測の欠け -/
namespace Benitoite.Release.Refinement

mutual
  /-- 鍵にできる十一の観測形。欠けたスロットを成功の根拠にしない。 -/
  inductive Observation.KeyShape : Observation → Prop where
    | integer (n) : KeyShape (.integer n)
    | character (c) : KeyShape (.character c)
    | decimal (c s) : KeyShape (.decimal c s)
    | boolean (b) : KeyShape (.boolean b)
    | unit : KeyShape .unitValue
    | string (s) : KeyShape (.string s)
    | bytes {xs} : xs.all (· ≤ 255) = true → KeyShape (.bytesValue xs)
    | list {xs} : Observation.KeySlots xs → KeyShape (.listValue xs)
    | map {ks vs} : Observation.KeyPairs ks vs → KeyShape (.mapValue ks vs)
    | set {xs} : Observation.KeySlots xs → KeyShape (.setValue xs)
    | data {c xs} : Observation.KeySlots xs → KeyShape (.dataValue c xs)
  inductive Observation.KeySlots : List (Option Observation) → Prop where
    | nil : KeySlots []
    | cons {o xs} : o.KeyShape → KeySlots xs → KeySlots (some o :: xs)
  inductive Observation.KeyPairs : List (Option Observation) → List (Option Observation) → Prop where
    | nil : KeyPairs [] []
    | cons {k v ks vs} : k.KeyShape → v.KeyShape → KeyPairs ks vs →
        KeyPairs (some k :: ks) (some v :: vs)
end

mutual
  theorem Observation.KeyShape.code {o : Observation} (h : o.KeyShape) :
      ∃ c, o.keyCode? = some c := by
    cases h with
    | integer | character | decimal | boolean | unit | string => simp [Observation.keyCode?]
    | bytes h => simp [Observation.keyCode?, h]
    | list h | data h =>
      obtain ⟨cs, hc⟩ := h.codes
      simp [Observation.keyCode?, hc]
    | set h =>
      obtain ⟨cs, hc⟩ := h.setCodes []
      simp [Observation.keyCode?, hc]
    | map h =>
      obtain ⟨cs, hc⟩ := h.mapCodes []
      simp [Observation.keyCode?, hc]
  termination_by sizeOf o
  theorem Observation.KeySlots.codes {xs} (h : Observation.KeySlots xs) :
      ∃ cs, keySlotCodes xs = some cs := by
    cases h with
    | nil => exact ⟨[], by simp [keySlotCodes]⟩
    | cons h hs =>
      obtain ⟨c, hc⟩ := h.code
      obtain ⟨cs, hcs⟩ := hs.codes
      simp [keySlotCodes, hc, hcs]
  termination_by sizeOf xs
  theorem Observation.KeySlots.setCodes {xs} (h : Observation.KeySlots xs) (acc : List (List Nat)) :
      ∃ cs, keySetCodes xs acc = some cs := by
    cases h with
    | nil => exact ⟨acc, by simp [keySetCodes]⟩
    | cons h hs =>
      obtain ⟨c, hc⟩ := h.code
      simpa [keySetCodes, hc] using hs.setCodes (if c ∈ acc then acc else acc ++ [c])
  termination_by sizeOf xs
  theorem Observation.KeyPairs.mapCodes {ks vs} (h : Observation.KeyPairs ks vs)
      (acc : List (List Nat × List Nat)) : ∃ cs, keyMapCodes ks vs acc = some cs := by
    cases h with
    | nil => exact ⟨acc, by simp [keyMapCodes]⟩
    | cons hk hv hs =>
      obtain ⟨k, hk⟩ := hk.code
      obtain ⟨v, hv⟩ := hv.code
      simpa [keyMapCodes, hk, hv] using hs.mapCodes (insertKey k v acc)
  termination_by sizeOf ks + sizeOf vs
end

/-- 鍵の成功は、欠けたスロットや対象外の三形からは構成しない。 -/
theorem Observation.key_unsupported (x : UInt64) (y : UInt32)
    (bs : Option PathEnv) (t : Scope.Domain.Target) :
    (Observation.float64 x).keyCode? = none ∧
    (Observation.float32 y).keyCode? = none ∧
    (Observation.targetValue bs t).keyCode? = none := by simp [Observation.keyCode?]

/-- Map の大きさには値の鍵化を要求しない。 -/
theorem Observation.KeySlots.mapKeys {ks} (h : Observation.KeySlots ks)
    (vs : List (Option Observation)) (lengths : ks.length = vs.length)
    (acc : List (List Nat × Option Observation)) :
    ∃ entries, mapKeys.go ks vs acc = some entries := by
  cases h with
  | nil =>
    have : vs = [] := List.length_eq_zero_iff.mp lengths.symm
    subst vs; exact ⟨acc, rfl⟩
  | cons hk hs =>
    cases vs with
    | nil => simp at lengths
    | cons v vs =>
      obtain ⟨c, hc⟩ := hk.code
      simpa [mapKeys.go, hc] using hs.mapKeys vs (Nat.succ.inj lengths) (insertKey c v acc)

/-- 閉じた項の実観測と有限構造から、既存の鍵の入口の成功を得る。 -/
theorem Key.code_of_shape {t : Term} {o : Observation} (closed : t.Closed)
    (η : ObservationEnvModel) (observed : t.observe η = some o) (shape : o.KeyShape) :
    ∃ c, Key.code? t = some c ∧ o.keyCode? = some c := by
  obtain ⟨c, hc⟩ := shape.code
  refine ⟨c, ?_, hc⟩
  rw [Key.code?, ite_eq_left closed, ← Term.observe_closed closed η, observed]
  exact hc

/-- 同じ型の閉じた二鍵を既存の言語上の鍵等値へ渡す。
型の照合は呼出し元が行い、この補題は数の幅を推測しない。 -/
theorem Key.equal_of_shapes {a b : Term} {x y : Observation}
    (ha : a.Closed) (hb : b.Closed) (η : ObservationEnvModel)
    (ax : a.observe η = some x) (by' : b.observe η = some y)
    (hx : x.KeyShape) (hy : y.KeyShape) :
    ∃ c d, x.keyCode? = some c ∧ y.keyCode? = some d ∧
      Key.equal a b = some (decide (c = d)) := by
  obtain ⟨c, hc, hxc⟩ := Key.code_of_shape ha η ax hx
  obtain ⟨d, hd, hyd⟩ := Key.code_of_shape hb η by' hy
  exact ⟨c, d, hxc, hyd, by simp [Key.equal, hc, hd]⟩

/-- Decimal の正準化で小数点を一桁移しても数は同じである。 -/
theorem decimalNormal_value (c : Int) (s : Nat) :
    let p := decimalNormal c s
    p.1 * (10 : Int)^s = c * (10 : Int)^p.2 := by
  induction s generalizing c with
  | zero => simp [decimalNormal]
  | succ s ih =>
    rw [decimalNormal]
    split
    · rename_i h
      have hi := ih (c / 10)
      dsimp only at hi ⊢
      rw [Int.pow_succ, ← Int.mul_assoc, hi, Int.mul_assoc,
        Int.mul_comm ((10 : Int)^(decimalNormal (c / 10) s).2) 10, ← Int.mul_assoc]
      have he : c / 10 * 10 = c := by omega
      rw [he]
    · rfl

private theorem decimalNormal_code_injective (c d : Int) (s t : Nat)
    (h : (Observation.decimal c s).keyCode? = (Observation.decimal d t).keyCode?) :
    decimalNormal c s = decimalNormal d t := by
  cases hp : decimalNormal c s with
  | mk a u =>
    cases hq : decimalNormal d t with
    | mk b v =>
      simp only [Observation.keyCode?, hp, hq] at h
      change some (2 :: ((if a < 0 then [1,a.natAbs] else [0,a.natAbs]) ++ [u])) =
        some (2 :: ((if b < 0 then [1,b.natAbs] else [0,b.natAbs]) ++ [v])) at h
      split at h <;> split at h <;> simp_all
      all_goals omega

/-- Decimal 鍵のコードの衝突は、数としての等値を保つ。 -/
theorem decimal_key_compare {c d : Int} {s t : Nat}
    (h : (Observation.decimal c s).keyCode? = (Observation.decimal d t).keyCode?) :
    (Observation.decimal c s).compare .eq (.decimal d t) = true := by
  have hp := decimalNormal_code_injective c d s t h
  have hc := decimalNormal_value c s
  have hd := decimalNormal_value d t
  dsimp only at hc hd
  rw [← hp] at hd
  let p := decimalNormal c s
  have he : (c * (10 : Int)^t) * (10 : Int)^p.2 =
      (d * (10 : Int)^s) * (10 : Int)^p.2 := by
    calc
      _ = (c * (10 : Int)^p.2) * (10 : Int)^t := by ac_rfl
      _ = (p.1 * (10 : Int)^s) * (10 : Int)^t := by rw [hc]
      _ = (p.1 * (10 : Int)^t) * (10 : Int)^s := by ac_rfl
      _ = (d * (10 : Int)^p.2) * (10 : Int)^s := by rw [hd]
      _ = _ := by ac_rfl
  have nonzero : (10 : Int)^p.2 ≠ 0 := by exact Int.ne_of_gt (Int.pow_pos (by decide))
  have eq : c * (10 : Int)^t = d * (10 : Int)^s := by
    exact (Int.mul_eq_mul_right_iff nonzero).mp he
  simp [Observation.compare, Comparison.fromEqLt, eq]

/-- 閉じた Map の大きさは、実際に成功した縮約の長さである。 -/
theorem Key.map_measure {ks vs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots ks) (normal : Key.normalizeMap ks vs = some entries) :
    Observation.measure .mapSize (.mapValue (observeSlots η ks) (observeSlots η vs)) =
      some (.integer entries.length) := by
  have h := Key.normalizeMap_length η ks vs closed
  rw [normal] at h
  cases hm : mapKeys (observeSlots η ks) (observeSlots η vs) with
  | none => simp [hm] at h
  | some es =>
    have len : es.length = entries.length := by simpa [hm] using h
    simp [Observation.measure, hm, len]

/-- Set の大きさも重複縮約の後の長さであり、観測失敗を0へ写さない。 -/
theorem Key.set_measure {xs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots xs) (normal : Key.normalizeSet xs = some entries) :
    Observation.measure .setSize (.setValue (observeSlots η xs)) = some (.integer entries.length) := by
  have h := Key.normalizeSet_length η xs closed
  rw [normal] at h
  cases hm : keySetCodes (observeSlots η xs) [] with
  | none => simp [hm] at h
  | some es =>
    have len : es.length = entries.length := by simpa [hm] using h
    simp [Observation.measure, hm, len]

end Benitoite.Release.Refinement
