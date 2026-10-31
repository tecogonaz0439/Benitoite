import Benitoite.Release.Refinement.MatchPaths
namespace Benitoite.Release.Refinement
-- 欄のパターン・リテラル・空リスト・照合しない構成子の除外は作らない（健全側の確認と、未提供の範囲の確認）。
example : excludedTests [⟨.con "Box" [.const (.boolean true)],[]⟩] = [] := rfl
example : excludedTests [⟨.con "Box" [.wild],[]⟩] = [] := rfl
example : excludedTests [⟨.list [] none [],[]⟩] = [] := rfl
example : matchedTests [⟨.list [] none [],[]⟩] = [] := rfl
example : matchedTests [⟨.const (.boolean true),[]⟩] = [] := rfl
example : excludedTests [⟨.const (.boolean true),[]⟩] = [] := rfl
example : matchedTests [⟨.range (.integer ⟨1,by decide⟩) (.integer ⟨5,by decide⟩),[]⟩] = [] := rfl
example : matchedTests [⟨.con "A" [],[]⟩,⟨.con "B" [],[]⟩] = [] := rfl
example : excludedTests [⟨.con "A" [],[]⟩,⟨.wild,[]⟩] = [.excluded "A"] := rfl
-- 観測できない欄を持つ構成子でも閉じた評価は成功する（L20 の入力が関数を持つデータで詰まらない）。
example : (Pred.constructorIs (.dataValue "Box" [none]) "Box").evalClosed = some true := by decide
example : (Pred.not (.constructorIs (.dataValue "Box" [none]) "Other")).evalClosed = some true := by decide
example : (Pred.lt (.integer 0) (.measure .listLength (.listValue [none]))).evalClosed = some true := by decide
end Benitoite.Release.Refinement
