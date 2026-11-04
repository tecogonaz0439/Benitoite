import Benitoite.Release.Refinement.StandardCollectionExamples

/-! # Map.fromList の長さだけでは区別できない鍵の縮約 -/
namespace Benitoite.Release.Refinement.StandardMapHigherPrecisionGap
open StandardCollections
noncomputable section

private def key : Val := .const (.decimal 1 0)
private def otherKey : Val := .const (.decimal 2 0)
private def value : Val := .const .unit
private def pair (k : Val) : Val := .con "Pair.Pair" [.base .decimal,.base .unit] [k,value]
private def duplicate : List Val := [pair key,pair key]
private def distinct : List Val := [pair key,pair otherKey]

theorem same_input_length : duplicate.length = distinct.length := rfl

theorem duplicate_response :
    mapDelta [] "Map.fromList" [.base .decimal,.base .unit] [] [] [.list duplicate] =
      some (.val (.mapV [key] [value])) := by cbv

theorem distinct_response :
    mapDelta [] "Map.fromList" [.base .decimal,.base .unit] [] [] [.list distinct] =
      some (.val (.mapV [key,otherKey] [value,value])) := by cbv

/-- 一般のMap.fromListへ、入力列の長さとの等号を付けることはできない。 -/
theorem duplicate_size_not_length :
    (Pred.eq (.measure .mapSize (.mapValue (Val.toTermSlots [key]) (Val.toTermSlots [value])))
      (.measure .listLength (.listValue (Val.toTermSlots duplicate)))).evalWith (fun _ => none) = some false := by cbv

/-- 異なる鍵の列なら同じ二要素でも二件のMapを返す。 -/
theorem distinct_size_is_length :
    (Pred.eq (.measure .mapSize (.mapValue (Val.toTermSlots [key,otherKey]) (Val.toTermSlots [value,value])))
      (.measure .listLength (.listValue (Val.toTermSlots distinct)))).evalWith (fun _ => none) = some true := by cbv

/-- toList・List.map・fromListから得る大きさだけの三契約。 -/
def scalarFacts : List Pred := [
  .eq (.var 1) (.var 0),
  .eq (.var 2) (.var 1),
  .le (.var 3) (.var 2),
  .le (.integer 0) (.var 0),.le (.integer 0) (.var 3)]
def scalarGoal : Pred := .eq (.var 3) (.var 0)
private def countermodel : ObservationEnvModel := fun i => some (.integer (if i=3 then 1 else 2))

/-- 長さ・大きさだけの中間契約から、Map.mapの等式は導けない。 -/
theorem scalar_contract_gap : ¬ Entails scalarFacts scalarGoal := by
  intro h
  have valid : ∀ p ∈ scalarFacts, p.interpret countermodel = true := by
    intro p hp
    rcases List.mem_cons.mp hp with rfl | hp
    · rfl
    rcases List.mem_cons.mp hp with rfl | hp
    · rfl
    rcases List.mem_cons.mp hp with rfl | hp
    · rfl
    rcases List.mem_cons.mp hp with rfl | hp
    · rfl
    cases List.mem_singleton.mp hp
    rfl
  have bad := Entails.sound h countermodel valid
  change false = true at bad
  cases bad

/-- 全体の反例ではなく、汎用fromListの等式とスカラー契約の経路を退ける。 -/
example : duplicate.length = distinct.length ∧
    ¬ Entails scalarFacts scalarGoal := ⟨same_input_length,scalar_contract_gap⟩

end
end Benitoite.Release.Refinement.StandardMapHigherPrecisionGap
