import Benitoite.Release.Refinement.SubstTyping

/-!
全sortの署名のうち、snapshot・長さ・Noneの位置に限った再現である。
本番の整数だけのTerm/Predや、その既存の定理の反例ではない。
-/
namespace RefinementWFBoundary
open Benitoite.Release.Refinement

inductive T where
  | var (i : Nat)
  | integer (n : Int)
  | listValue (elements : List (Option T))
  | length (t : T)

mutual
  def wf (nv : Nat) : T → Prop
    | .var i => i < nv
    | .integer _ => True
    | .listValue xs => wfSlots nv xs
    | .length t => wf nv t
  def wfSlots (nv : Nat) : List (Option T) → Prop
    | [] => True
    | none :: xs => wfSlots nv xs
    | some t :: xs => wf nv t ∧ wfSlots nv xs
end

-- スロットにはsortを要求しない、署名1.3の規約。
def sorted (Γ : List (Option «Sort»)) : T → «Sort» → Prop
  | .var i, s => Γ[i]? = some (some s)
  | .integer _, s => s = .integer
  | .listValue _, s => s = .list
  | .length t, s => sorted Γ t .list ∧ s = .integer

mutual
  def bindOptional (ν : Nat → Option T) : T → Option T
    | .var i => ν i
    | .integer n => some (.integer n)
    | .listValue xs => some (.listValue (bindSlots ν xs))
    | .length t => some (.length ((bindOptional ν t).getD (.integer 0)))
  def bindSlots (ν : Nat → Option T) : List (Option T) → List (Option T)
    | [] => []
    | none :: xs => none :: bindSlots ν xs
    | some t :: xs => bindOptional ν t :: bindSlots ν xs
end

def sortImages (Γ Δ : List (Option «Sort»)) (ν : Nat → Option T) : Prop :=
  ∀ i s, Γ[i]? = some (some s) → ∃ t, ν i = some t ∧ sorted Δ t s

def term : T := .length (.listValue [some (.var 0)])
def image : Nat → Option T := fun _ => some (.var 0)

-- 根はinteger sortでも、スロットの参照の上限は従わない。
theorem integer_sort_does_not_imply_wf :
    sorted [] term .integer ∧ ¬ wf 0 term := by
  constructor
  · exact ⟨rfl, rfl⟩
  · simp [term, wf, wfSlots]


-- Γ=[none]では全sortの像の条件は空に成り立つ。元の項はWF 1である。
-- それでも空文脈への置換後の項はWF 0にならない。
theorem sorted_images_do_not_preserve_wf :
    wf 1 term ∧ sorted [none] term .integer ∧ sortImages [none] [] image ∧
      bindOptional image term = some term ∧ ¬ wf 0 term := by
  refine ⟨?_, ⟨rfl, rfl⟩, ?_, rfl, integer_sort_does_not_imply_wf.2⟩
  · simp [term, wf, wfSlots]
  · intro i s hi
    cases i <;> simp at hi

def selfTerm : T := .length (.listValue [some (.var 1)])
def liftedImage : Nat → Option T
  | 0 => some (.var 0)
  | _+1 => some (.var 1)

-- 篩のselfを一つ置いた同じ例。外側のnoneの番号は1になる。
theorem refinement_self_boundary :
    wf 2 selfTerm ∧ sorted [some «Sort».list, none] selfTerm .integer ∧
    bindOptional liftedImage selfTerm = some selfTerm ∧ ¬ wf 1 selfTerm := by
  refine ⟨?_, ⟨rfl, rfl⟩, rfl, ?_⟩ <;> simp [selfTerm, wf, wfSlots]

-- 本番の現行SubstOkも、Noneの位置の像には条件を置かない。
-- ここで証明するのはこの定義の事実であり、旧整数体系のWF保存の反例ではない。
theorem actual_substOk_none (P : Program) (B : Builtins) (Ψ : StoreTy) :
    SubstOk P B Ψ Benitoite.Release.Qempty [] [none] [] [] [] none
      (fun _ => Val.var 0) := by
  intro i a hi
  cases i <;> simp at hi

#print axioms integer_sort_does_not_imply_wf
#print axioms sorted_images_do_not_preserve_wf
#print axioms refinement_self_boundary
#print axioms actual_substOk_none
end RefinementWFBoundary
