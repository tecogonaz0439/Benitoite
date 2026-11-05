import Lean
import Benitoite
namespace Benitoite.RefinementHelperCollision
open Benitoite.Release.Refinement
/-- 二つの本体を保持しても、その中の同じ参照名が要求する定義は異なる。 -/
theorem helper_inputs_differ :
    (StandardBodies.listFromDefinition false).params ≠
    (StandardHeadTail.fromDefinition false).params := by
  intro h
  cases h
/-- 通常側の既存証明と精密側の既存証明のlookup副条件は同時に供給できない。 -/
theorem source_lookup_incompatible (P : Program)
    (ordinary : P.defs "List.mapFrom" = some (StandardBodies.listFromDefinition false))
    (refined : P.defs "List.mapFrom" = some (StandardHeadTail.fromDefinition false)) : False := by
  exact helper_inputs_differ (congrArg Def.params (Option.some.inj (ordinary.symm.trans refined)))
/-- 通常の公開mapは整数0を、精密な公開mapはリストを第3引数に渡す。 -/
theorem public_third_arguments_differ :
    (StandardBodies.listHigherRow false).body ≠ some (StandardHeadTail.publicBody false) := by
  intro h
  cases h
/-- 通常mapが渡す整数0を、精密helperの第3引数のListへ型付けることはできない。 -/
theorem integer_is_not_list {P B Ψ Q C Γ Φ a} (n : Benitoite.Release.Integer64Value)
    (typed : HasTypeVQ P B Ψ Q C Γ Φ (.const (.integer n)) (.list a)) : False := by
  have core := (typed.inv_const rfl).2
  cases core
#print axioms helper_inputs_differ
#print axioms source_lookup_incompatible
#print axioms integer_is_not_list
#print axioms public_third_arguments_differ
end Benitoite.RefinementHelperCollision

/- private・生成宣言も含む、この再現入力の全宣言の公理依存。 -/
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let localNames := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if localNames.isEmpty then break
    for n in localNames do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      elabCommand (← `(#print axioms $(mkIdent n)))
