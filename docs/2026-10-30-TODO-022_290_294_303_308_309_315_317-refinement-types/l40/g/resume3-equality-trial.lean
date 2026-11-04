import Benitoite.Release.Refinement.StandardStructuralEqualityResponse
namespace Benitoite.Release.Refinement.L40EqualityTrial
open StandardListRemainingResponse
/-! 中1(a)の部分試行。深さと列の補題だけであり、型付きEquality全体の正常性は結論しない。 -/
theorem depth_positive (o : Observation) : 0 < snapshotDepth o := by
  cases o <;> simp [snapshotDepth]
theorem member_depth (x : Observation) (xs : List (Option Observation))
    (h : some x ∈ xs) : snapshotDepth x ≤ slotDepth xs := by
  induction xs with
  | nil => cases h
  | cons a xs ih =>
    rcases List.mem_cons.mp h with hh | hh
    · cases hh
      exact Nat.le_max_left _ _
    · cases a with
      | none => exact ih hh
      | some a => exact Nat.le_trans (ih hh) (Nat.le_max_right _ _)
theorem integer_fuel (a b : Int) :
    equalityFuel (snapshotDepth (.integer a)) (.integer a) (.integer b) = some (a == b) := by simp [snapshotDepth, equalityFuel]
theorem slots_total (n : Nat) (xs ys : List Observation)
    (child : ∀ a ∈ xs, ∀ b ∈ ys, ∃ result, equalityFuel n a b = some result) :
    ∃ result, equalityFuel.slots n (xs.map some) (ys.map some) = some result := by
  induction xs generalizing ys with
  | nil => cases ys <;> simp [equalityFuel.slots]
  | cons a xs ih =>
    cases ys with
    | nil => simp [equalityFuel.slots]
    | cons b ys =>
      obtain ⟨result, h⟩ := child a (by simp) b (by simp)
      obtain ⟨tail, ht⟩ := ih ys (by intro x hx y hy; exact child x (by simp [hx]) y (by simp [hy]))
      cases result <;> simp [equalityFuel.slots, h, ht]
-- Map の残りは、縮約・整列後の値が元の値側スロットに由来することと燃料の境界である。
#check mapKeys
#check equalityFuel.entries
#check StandardKeyTyping.key_table_sound
end Benitoite.Release.Refinement.L40EqualityTrial
