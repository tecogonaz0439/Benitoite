import Benitoite.Release.Refinement.CoverageExamples
import Benitoite.Release.Refinement.CoverageRuntime

/-!
# 有界 Integer の網羅性の独立例

判定の入口で、反例・到達しない選択肢の位置・覆う分岐・燃料切れを照合する。区間の期待値は判定の定義から生成せず、
境界と入力の相関から書く（設計書 01-12「網羅性検査」）。到達しない選択肢の実行時の系
（`checkMatch_unreachable_runtime`）を、全域の後のワイルドカードに当てる。
-/
namespace Benitoite.Release.Refinement.CoverageIntegerExamples
open Coverage CoverageExamples
open Benitoite.Release (Pat Integer64Value)

def ints (lo hi : Integer64Value) : Pat := .range (.integer lo) (.integer hi)
def int (n : Integer64Value) : Pat := .const (.integer n)
def bool (b : Bool) : Pat := .const (.boolean b)
def intMin : Integer64Value := ⟨-9223372036854775808, by decide⟩
def intMax : Integer64Value := ⟨9223372036854775807, by decide⟩
def intFull : Pat := ints intMin intMax
def intNegative : Pat := ints intMin ⟨-1, by decide⟩
def intNonnegative : Pat := ints ⟨0, by decide⟩ intMax
abbrev intTy : Ty := .base .integer
abbrev boolTy : Ty := .base .boolean

/-- ガードのない分岐。各選択肢の束縛は左から順に並べる。 -/
def plain (ps : List Pat) : Arm := .mk (ps.map fun p => ⟨p, List.range p.binders⟩) none (.ret (.const .unit))
/-- ガード付きの分岐。 -/
def guarded (ps : List Pat) : Arm :=
  .mk (ps.map fun p => ⟨p, List.range p.binders⟩) (some (.ret (.const (.boolean true)))) (.ret (.const .unit))

/-- 照合の結果の組（反例・到達しない位置・覆う分岐・燃料切れ）。 -/
def inspect (P : Program) (ctors : DataName → List ConName) (view : CoverageView) (a : Ty) (arms : List Arm) :
    Option CoverageWitness × List (Nat × Nat) × List ((Nat × Nat) × List Nat) × Bool :=
  let r := checkMatchWithView P ctors view a arms
  (r.uncovered, r.unreachable, r.coveredBy, r.fuelExhausted)

/-- 一つの全域、隣接区間、重なり、定数による一点の補充。内側の一点・下端・上端の穴はいずれも other を必要とする。 -/
theorem integer_holes :
    ([[intFull], [intNegative, intNonnegative], [ints intMin ⟨1, by decide⟩, intNonnegative],
      [intNegative, int ⟨0, by decide⟩, ints ⟨1, by decide⟩ intMax],
      [intNegative, ints ⟨1, by decide⟩ intMax],
      [ints ⟨-9223372036854775807, by decide⟩ intMax],
      [ints intMin ⟨9223372036854775806, by decide⟩]] : List (List Pat)).map
      (fun ps => coverage program ctors closedView intTy ps) =
    [.exhaustive, .exhaustive, .exhaustive, .exhaustive,
     .nonExhaustive [.other], .nonExhaustive [.other], .nonExhaustive [.other]] := by rfl

/-- 全域後のワイルドカード、同じ分岐内の重複、ガードだけの全域を区別する。非選択の説明は、全域を合わせて覆った
二分岐を両方挙げる。 -/
theorem integer_unreachable :
    inspect program ctors closedView intTy [plain [intFull], plain [.wild]] = (none, [(1, 0)], [((1, 0), [0])], false) ∧
    inspect program ctors closedView intTy [plain [intNegative], plain [intNonnegative], plain [.wild]] =
      (none, [(2, 0)], [((2, 0), [0, 1])], false) ∧
    inspect program ctors closedView intTy [plain [intFull, .wild]] = (none, [(0, 1)], [((0, 1), [])], false) ∧
    inspect program ctors closedView intTy [guarded [intFull, .wild]] = (some .wild, [(0, 1)], [((0, 1), [])], false) ∧
    inspect program ctors closedView intTy [guarded [intFull], plain [intFull]] = (none, [], [], false) ∧
    inspect program ctors closedView intTy [guarded [intFull]] = (some .wild, [], [], false) ∧
    inspect program ctors closedView intTy [guarded [intNegative], plain [intNonnegative]] =
      (some .other, [], [], false) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> rfl

/-- 問いを全域にすると、欠けた一点は実際の区間として返る。max+1 は Int の境界の計算にだけ現れ、値域の上端も
一つの区間となる。 -/
theorem integer_missing_points :
    ([[intNegative, ints ⟨1, by decide⟩ intMax], [ints intMin ⟨9223372036854775806, by decide⟩],
      [ints ⟨-9223372036854775807, by decide⟩ intMax]] : List (List Pat)).map
      (fun ps => useful program ctors [intTy] (ps.map fun p => [p]) [intFull]) =
    [some [.interval false 0 0],
     some [.interval false 9223372036854775807 9223372036854775807],
     some [.interval false (-9223372036854775808) (-9223372036854775808)]] := by rfl

/-- 各欄の被覆を合併すると、負数と false の組合せを見落とす。 -/
theorem integer_correlation :
    ([[[intFull, bool true], [intFull, bool false]],
      [[intNegative, bool true], [intNonnegative, bool false]]] : List (List (List Pat))).map
      (fun rows => useful program ctors [intTy, boolTy] rows [.wild, .wild]) =
    [none, some [.interval false (-9223372036854775808) (-1), .boolean false]] := by rfl

/-- リスト要素へも同じ全域の判定を渡す。 -/
theorem integer_list_elements :
    inspect program ctors closedView (.list intTy) [plain [.list [] none []], plain [.list [intFull] (some .skip) []]] =
      (none, [], [], false) := by rfl

/-- 全域の入力でも、区間の特殊化後の燃料切れを成功にしない。 -/
theorem integer_fuel :
    let r := usefulFuel program ctors 1 [intTy] [[intFull]] [.wild]
    (r.witness, r.fuelExhausted) = (some [.interval false (-9223372036854775808) 9223372036854775807], true) := by rfl

/-! ## 構成子の内側の区間と将来の構成子 -/

/-- 一つの型引数を持つ `Choice` の二つの構成子 `L`・`R`。 -/
def choiceProgram : Program := { program with
  cons := fun c => if c = "L" ∨ c = "R" then some ⟨"Choice", 1, [.tvar 0]⟩ else none }

def choiceCtors : DataName → List ConName := fun d => if d = "Choice" then ["L", "R"] else []

def externalChoice : CoverageView := fun d => d == "Choice"

/-- 構成子の内側でも区間の分割と他の欄との相関を保つ。外部の将来の構成子は消さない。 -/
theorem choice_intervals :
    inspect choiceProgram choiceCtors closedView (.data "Choice" [intTy])
      [plain [.con "L" [intNegative]], plain [.con "L" [intNonnegative]], plain [.con "R" [intFull]]] =
      (none, [], [], false) ∧
    useful choiceProgram choiceCtors [.data "Choice" [intTy], boolTy]
      [[.con "L" [intNegative], bool true], [.con "L" [intNonnegative], bool false], [.con "R" [intFull], .wild]]
      [.wild, .wild] = some [.con "L" [.interval false (-9223372036854775808) (-1)], .boolean false] ∧
    inspect choiceProgram choiceCtors externalChoice (.data "Choice" [intTy])
      [plain [.con "L" [intFull]], plain [.con "R" [intFull]]] = (some (.future "Choice"), [], [], false) := by
  refine ⟨?_, ?_, ?_⟩ <;> rfl

/-! ## 到達しない選択肢の実行時の系 -/

/-- 全域の後のワイルドカード（分岐 1 の選択肢 0）は、どの Integer の値でも実行時に選ばれない。 -/
theorem integer_wild_never_runtime (n : Integer64Value) :
    ¬ RuntimeSelected [plain [intFull], plain [.wild]] 1 0 (.const (.integer n)) := by
  apply checkMatch_unreachable_runtime program ctors intTy _ 1 0 complete
  · intro arm ha alt halt v ws hm
    simp only [List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with rfl | rfl <;> simp [plain, Arm.alts] at halt <;> subst alt <;> rfl
  · exact (by rfl : (checkMatch program ctors intTy [plain [intFull], plain [.wild]]).unreachable = [(1, 0)]) ▸
      List.mem_singleton_self _
  · exact Inhabits.const (c := .integer n)

/-- 照合の遷移が分岐 0 で全域の選択肢を使うとき（`E_MatchBody` の前提）、その選択肢は到達しないと報告された位置ではない。 -/
theorem integer_full_selected (n : Integer64Value) :
    ∃ j alt xs, ([⟨intFull, []⟩] : List Alt)[j]? = some alt ∧ matchVal alt.pat (.const (.integer n)) = some xs ∧
      selectSlots xs alt.slots = some [] ∧
      (0, j) ∉ (checkMatchWithView program ctors closedView intTy [plain [intFull], plain [.wild]]).unreachable := by
  refine firstAlt_not_unreachable program ctors closedView (guard := none) (body := .ret (.const .unit)) complete ?_
    (Inhabits.const (c := .integer n)) (by intro arm ha; simp at ha) rfl ?_
  · intro arm ha alt halt v ws hm
    simp only [List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with rfl | rfl <;> simp [plain, Arm.alts] at halt <;> subst alt <;> rfl
  · have hm : matchVal intFull (.const (.integer n)) = some [] := by
      have h1 := n.property
      simp only [Benitoite.Release.min64, Benitoite.Release.max64] at h1
      simp only [intFull, ints, intMin, intMax, matchVal, patternRange]
      simp [Benitoite.Release.Integer64Value.toInt, h1]
    simp [firstAlt, hm, selectSlots]

end Benitoite.Release.Refinement.CoverageIntegerExamples
