import Benitoite.Release.Refinement.RuntimeSyntax

namespace Benitoite.Release.Refinement

def patternMatches : Benitoite.Release.Const → Const → Bool
  | .integer a, .integer b => a.toInt == b.toInt
  | .string a, .string b => a == b
  | .character a, .character b => a == b
  | .boolean a, .boolean b => a == b
  | .unit, .unit => true
  | _, _ => false

def patternRange : Benitoite.Release.Const → Benitoite.Release.Const → Const → Bool
  | .integer lo, .integer hi, .integer n => decide (lo.toInt ≤ n.toInt ∧ n.toInt ≤ hi.toInt)
  | .character lo, .character hi, .character c => decide (lo.toNat ≤ c.toNat ∧ c.toNat ≤ hi.toNat)
  | _, _, _ => false

mutual
  def matchVal : Pat → Val → Option (List Val)
    | .wild, _ => some []
    | .var, v => some [v]
    | .const c, .const c' => if patternMatches c c' then some [] else none
    | .con c ps, .con c' _ args =>
        if c = c' then matchList ps args else none
    | .range lo hi, .const c => if patternRange lo hi c then some [] else none
    | .list before rest after, .list elems => do
        let n := before.length + after.length
        if (if rest.isSome then n ≤ elems.length else n = elems.length) then
          let left ← matchList before (elems.take before.length)
          let right ← matchList after (elems.drop (elems.length - after.length))
          let middle := elems.drop before.length |>.take (elems.length - n)
          let bound := match rest with
            | some .bind => [Val.list middle]
            | _ => []
          pure (left ++ bound ++ right)
        else none
    | _, _ => none

  def matchList : List Pat → List Val → Option (List Val)
    | [], [] => some []
    | p :: ps, v :: vs => do
        let a ← matchVal p v
        let b ← matchList ps vs
        pure (a ++ b)
    | _, _ => none
end

/-- 選択肢の束縛を分岐の変数の順に並べ替える。範囲外の番号は照合の失敗になる。 -/
def selectSlots {α : Type} (xs : List α) : List Nat → Option (List α)
  | [] => some []
  | i :: is => do
      let x ← xs[i]?
      let ys ← selectSlots xs is
      pure (x :: ys)

theorem selectSlots_map {α β : Type} (f : α → β) (xs : List α) (slots : List Nat) :
    selectSlots (xs.map f) slots = (selectSlots xs slots).map (List.map f) := by
  induction slots with
  | nil => rfl
  | cons i is ih =>
      simp only [selectSlots, List.getElem?_map]
      cases xs[i]? <;> simp [ih]
      cases selectSlots xs is <;> simp

theorem selectSlots_mem {α : Type} {xs ys : List α} {slots : List Nat}
    (h : selectSlots xs slots = some ys) : ∀ x ∈ ys, x ∈ xs := by
  induction slots generalizing ys with
  | nil => simp [selectSlots] at h; subst ys; simp
  | cons i is ih =>
      simp only [selectSlots] at h
      cases hi : xs[i]? with
      | none => simp [hi] at h
      | some x =>
          cases hs : selectSlots xs is with
          | none => simp [hi, hs] at h
          | some zs =>
              simp [hi, hs] at h; subst ys
              intro y hy
              rcases List.mem_cons.mp hy with rfl | hy
              · exact List.mem_of_getElem? hi
              · exact ih hs y hy

/-- 選択肢を左から調べ、一つ照合した時点で分岐を選ぶ。
型の付いた選択肢では、照合すれば並べ替え（`selectSlots`）に失敗しない
（`AltsTy` の順列の条件による）。 -/
def firstAlt (v : Val) : List Alt → Option (List Val)
  | [] => none
  | alt :: alts =>
      match matchVal alt.pat v with
      | some ws => selectSlots ws alt.slots
      | none => firstAlt v alts


end Benitoite.Release.Refinement
