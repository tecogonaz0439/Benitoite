import Benitoite.Release.CoverageExtension

/-!
# 有界 Integer の網羅性の独立例

判定の入口で反例・非選択の位置・覆う分岐・燃料切れを照合する。
区間の期待値は定義から生成せず、境界と入力の相関から書く。
-/
namespace Benitoite.Release.CoverageExamples
open Coverage

def ints (lo hi : Integer64Value) : Pat := .range (.integer lo) (.integer hi)
def intMin : Integer64Value := ⟨-9223372036854775808, by decide⟩
def intMax : Integer64Value := ⟨9223372036854775807, by decide⟩
def intFull : Pat := ints intMin intMax
def intNegative : Pat := ints intMin ⟨-1, by decide⟩
def intNonnegative : Pat := ints ⟨0, by decide⟩ intMax

/-- 一つの全域、隣接区間、重なり、定数による一点の補充。
内側の一点・下端・上端の穴はいずれも other を必要とする。 -/
example : ([
    [intFull], [intNegative, intNonnegative],
    [ints intMin ⟨1, by decide⟩, intNonnegative],
    [intNegative, int ⟨0, by decide⟩, ints ⟨1, by decide⟩ intMax],
    [intNegative, ints ⟨1, by decide⟩ intMax],
    [ints ⟨-9223372036854775807, by decide⟩ intMax],
    [ints intMin ⟨9223372036854775806, by decide⟩]] : List (List Pat)).map
    (fun ps => inspect intTy (ps.map fun p => plain [p])) =
    [(none, [], false), (none, [], false), (none, [], false), (none, [], false),
     (some [.other], [], false), (some [.other], [], false), (some [.other], [], false)] := by decide

/-- 全域後のワイルドカード、同じ分岐内の重複、ガードだけの全域を区別する。 -/
example : [
    inspect intTy [plain [intFull], plain [.wild]],
    inspect intTy [plain [intNegative], plain [intNonnegative], plain [.wild]],
    inspect intTy [plain [intFull, .wild]],
    inspect intTy [guarded [intFull, .wild]],
    inspect intTy [guarded [intFull], plain [intFull]],
    inspect intTy [guarded [intFull]],
    inspect intTy [guarded [intNegative], plain [intNonnegative]]] =
    [(none, [(1, 0)], false), (none, [(2, 0)], false), (none, [(0, 1)], false),
     (some [.wild], [(0, 1)], false), (none, [], false),
     (some [.wild], [], false), (some [.other], [], false)] := by decide

/-- 非選択の説明は、全域を合せて覆った二分岐を両方挙げる。 -/
example : inspectWithView closedView intTy
    [plain [intNegative], plain [intNonnegative], plain [.wild]] =
    (none, [(2, 0)], [((2, 0), [0, 1])], false) := by decide

/-- 問いを全域にすると、欠けた一点は実際の区間として返る。
max+1 は Int の境界計算にだけ現れ、値域の上端も一つの区間となる。 -/
example : ([
    [intNegative, ints ⟨1, by decide⟩ intMax],
    [ints intMin ⟨9223372036854775806, by decide⟩],
    [ints ⟨-9223372036854775807, by decide⟩ intMax]] : List (List Pat)).map
    (fun ps => (useful program ctors [intTy] (ps.map fun p => [p]) [intFull]).map
      (List.flatMap summarize)) =
    [some [.interval false 0 0],
     some [.interval false 9223372036854775807 9223372036854775807],
     some [.interval false (-9223372036854775808) (-9223372036854775808)]] := by decide

/-- 各欄の被覆を合併すると、負数と false の組合せを見落とす。 -/
example : ([
    [[intFull, bool true], [intFull, bool false]],
    [[intNegative, bool true], [intNonnegative, bool false]]] : List (List (List Pat))).map
    (fun rows => (useful program ctors [intTy, boolTy] rows [.wild, .wild]).map
      (List.flatMap summarize)) =
    [none, some [.interval false (-9223372036854775808) (-1), .boolean false]] := by decide

/-- 構成子の内側でも区間の分割と他の欄との相関を保つ。 -/
example : inspect (.data "Choice" [intTy])
    [plain [.con "L" [intNegative]], plain [.con "L" [intNonnegative]],
     plain [.con "R" [intFull]]] = (none, [], false) := by decide

example : (useful program ctors [.data "Choice" [intTy], boolTy]
    [[.con "L" [intNegative], bool true], [.con "L" [intNonnegative], bool false],
     [.con "R" [intFull], .wild]] [.wild, .wild]).map (List.flatMap summarize) =
    some [.con "L" 1, .interval false (-9223372036854775808) (-1), .boolean false] := by decide

/-- リスト要素へも同じ全域の判定を渡す。外部の将来の構成子は消さない。 -/
example : inspect (.list intTy)
    [plain [.list [] none []], plain [.list [intFull] (some .skip) []]] =
    (none, [], false) := by decide

example : inspectWithView externalChoice (.data "Choice" [intTy])
    [plain [.con "L" [intFull]], plain [.con "R" [intFull]]] =
    (some [.future "Choice"], [], [], false) := by decide

/-- 全域の入力でも、区間の特殊化後の燃料切れを成功にしない。 -/
example : let r := usefulFuel program ctors 1 [intTy] [[intFull]] [.wild]
    (r.witness.map (List.flatMap summarize), r.fuelExhausted) =
    (some [.interval false (-9223372036854775808) 9223372036854775807], true) := by decide

end Benitoite.Release.CoverageExamples
