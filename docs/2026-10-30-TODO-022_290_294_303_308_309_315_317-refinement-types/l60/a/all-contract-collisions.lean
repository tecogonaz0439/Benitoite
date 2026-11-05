import Lean
import Benitoite
namespace Benitoite.RefinementContractCollisions
open Benitoite.Release.Refinement
private def firstCall : Comp → String
  | .letIn m _ => firstCall m
  | .app (.fnRef name _ _) _ => name
  | .app (.prim name _ _ _) _ => name
  | _ => ""
theorem List_map_bodies :
    ((StandardBodies.listHigherRow false).definition).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "List.map").map Def.body := by
  intro equal
  cases equal

theorem List_map_inputs :
    ((StandardBodies.listHigherRow false).definition).map Def.params =
    (StandardCollectionRefinedBodies.program.defs "List.map").map Def.params := by
  rfl

theorem List_filter_bodies :
    ((StandardBodies.listHigherRow true).definition).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "List.filter").map Def.body := by
  intro equal
  cases equal

theorem List_filter_inputs :
    ((StandardBodies.listHigherRow true).definition).map Def.params =
    (StandardCollectionRefinedBodies.program.defs "List.filter").map Def.params := by
  rfl

theorem Map_map_bodies :
    ((StandardBodies.collectionHigherRow true false).definition).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "Map.map").map Def.body := by
  intro equal
  cases equal

theorem Map_map_inputs :
    ((StandardBodies.collectionHigherRow true false).definition).map Def.params =
    (StandardCollectionRefinedBodies.program.defs "Map.map").map Def.params := by
  rfl

theorem Map_filter_bodies :
    ((StandardBodies.collectionHigherRow true true).definition).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "Map.filter").map Def.body := by
  intro equal
  cases equal

theorem Map_filter_inputs :
    ((StandardBodies.collectionHigherRow true true).definition).map Def.params =
    (StandardCollectionRefinedBodies.program.defs "Map.filter").map Def.params := by
  rfl

theorem Set_map_bodies :
    ((StandardBodies.collectionHigherRow false false).definition).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "Set.map").map Def.body := by
  intro equal
  cases equal

theorem Set_map_inputs :
    ((StandardBodies.collectionHigherRow false false).definition).map Def.params =
    (StandardCollectionRefinedBodies.program.defs "Set.map").map Def.params := by
  rfl

theorem Set_filter_bodies :
    ((StandardBodies.collectionHigherRow false true).definition).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "Set.filter").map Def.body := by
  intro equal
  cases equal

theorem Set_filter_inputs :
    ((StandardBodies.collectionHigherRow false true).definition).map Def.params =
    (StandardCollectionRefinedBodies.program.defs "Set.filter").map Def.params := by
  rfl

theorem Range_minimum_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.minimum").map Def.body ≠
    (StandardSafe.PreciseGetter.minimum.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_minimum_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.minimum").map Def.params ≠
    (StandardSafe.PreciseGetter.minimum.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_maximum_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.maximum").map Def.body ≠
    (StandardSafe.PreciseGetter.maximum.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_maximum_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.maximum").map Def.params ≠
    (StandardSafe.PreciseGetter.maximum.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_value_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.value").map Def.body ≠
    (StandardSafe.PreciseGetter.value.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_value_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.value").map Def.params ≠
    (StandardSafe.PreciseGetter.value.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_lengthMinimum_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.lengthMinimum").map Def.body ≠
    (StandardSafe.PreciseGetter.lengthMinimum.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_lengthMinimum_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.lengthMinimum").map Def.params ≠
    (StandardSafe.PreciseGetter.lengthMinimum.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_lengthMaximum_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.lengthMaximum").map Def.body ≠
    (StandardSafe.PreciseGetter.lengthMaximum.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_lengthMaximum_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.lengthMaximum").map Def.params ≠
    (StandardSafe.PreciseGetter.lengthMaximum.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_checkedLength_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.checkedLength").map Def.body ≠
    (StandardSafe.PreciseGetter.checkedLength.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_checkedLength_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.checkedLength").map Def.params ≠
    (StandardSafe.PreciseGetter.checkedLength.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_lengthValues_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.lengthValues").map Def.body ≠
    (StandardSafe.PreciseGetter.lengthValues.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_lengthValues_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.lengthValues").map Def.params ≠
    (StandardSafe.PreciseGetter.lengthValues.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_indexValue_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.indexValue").map Def.body ≠
    (StandardSafe.PreciseGetter.indexValue.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_indexValue_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.indexValue").map Def.params ≠
    (StandardSafe.PreciseGetter.indexValue.row.definition).map Def.params := by
  intro equal
  cases equal

theorem Range_indexValues_bodies :
    (StandardOrdinaryCoreProgram.program.defs "Range.indexValues").map Def.body ≠
    (StandardSafe.PreciseGetter.indexValues.row.definition).map Def.body := by
  intro equal
  cases equal

theorem Range_indexValues_inputs :
    (StandardOrdinaryCoreProgram.program.defs "Range.indexValues").map Def.params ≠
    (StandardSafe.PreciseGetter.indexValues.row.definition).map Def.params := by
  intro equal
  cases equal

theorem NonEmptyList_map_bodies :
    (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.map").map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "NonEmptyList.map").map Def.body := by
  intro equal
  have names := congrArg (Option.map firstCall) equal
  change some "Benitoite.NonEmptyList.NonEmptyList.first" = some "List.map" at names
  have different : (some "Benitoite.NonEmptyList.NonEmptyList.first" : Option String) ≠ some "List.map" := by decide
  exact different names

theorem NonEmptyList_map_inputs :
    (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.map").map Def.params ≠
    (StandardCollectionRefinedBodies.program.defs "NonEmptyList.map").map Def.params := by
  intro equal
  cases equal

theorem List_mapFrom_bodies :
    ((StandardOrdinaryCoreProgram.allDefinitions[47]?).map Prod.snd).map Def.body ≠
    (StandardCollectionRefinedBodies.program.defs "List.mapFrom").map Def.body := by
  intro equal
  have names := congrArg (Option.map firstCall) equal
  change some "List.get" = some "List.head" at names
  have different : (some "List.get" : Option String) ≠ some "List.head" := by decide
  exact different names

theorem List_mapFrom_inputs :
    ((StandardOrdinaryCoreProgram.allDefinitions[47]?).map Prod.snd).map Def.params ≠
    (StandardCollectionRefinedBodies.program.defs "List.mapFrom").map Def.params := by
  intro equal
  cases equal

theorem duplicate_16 : ((StandardOrdinaryCoreProgram.allDefinitions[0]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Map.fold") := rfl
theorem duplicate_17 : ((StandardOrdinaryCoreProgram.allDefinitions[1]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Map.forEach") := rfl
theorem duplicate_18 : ((StandardOrdinaryCoreProgram.allDefinitions[2]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Set.fold") := rfl
theorem duplicate_19 : ((StandardOrdinaryCoreProgram.allDefinitions[3]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Set.forEach") := rfl
theorem duplicate_20 : ((StandardOrdinaryCoreProgram.allDefinitions[4]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.checkInteger") := rfl
theorem duplicate_21 : ((StandardOrdinaryCoreProgram.allDefinitions[5]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.checkLength") := rfl
theorem duplicate_22 : ((StandardOrdinaryCoreProgram.allDefinitions[6]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.checkIndex") := rfl
theorem duplicate_23 : ((StandardOrdinaryCoreProgram.allDefinitions[7]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.fromList") := rfl
theorem duplicate_24 : ((StandardOrdinaryCoreProgram.allDefinitions[8]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.toList") := rfl
theorem duplicate_25 : ((StandardOrdinaryCoreProgram.allDefinitions[9]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.map") := rfl
theorem duplicate_27 : ((StandardOrdinaryCoreProgram.allDefinitions[10]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "List.fold") := rfl
theorem duplicate_28 : ((StandardOrdinaryCoreProgram.allDefinitions[12]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "List.forEach") := rfl
theorem duplicate_29 : ((StandardOrdinaryCoreProgram.allDefinitions[14]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "List.any") := rfl
theorem duplicate_30 : ((StandardOrdinaryCoreProgram.allDefinitions[16]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "List.all") := rfl
theorem duplicate_31 : ((StandardOrdinaryCoreProgram.allDefinitions[18]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "List.find") := rfl
theorem duplicate_32 : ((StandardOrdinaryCoreProgram.allDefinitions[21]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.minimum") := rfl
theorem duplicate_34 : ((StandardOrdinaryCoreProgram.allDefinitions[23]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.maximum") := rfl
theorem duplicate_36 : ((StandardOrdinaryCoreProgram.allDefinitions[25]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.value") := rfl
theorem duplicate_38 : ((StandardOrdinaryCoreProgram.allDefinitions[27]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.lengthMinimum") := rfl
theorem duplicate_40 : ((StandardOrdinaryCoreProgram.allDefinitions[29]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.lengthMaximum") := rfl
theorem duplicate_42 : ((StandardOrdinaryCoreProgram.allDefinitions[31]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.checkedLength") := rfl
theorem duplicate_44 : ((StandardOrdinaryCoreProgram.allDefinitions[33]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.lengthValues") := rfl
theorem duplicate_46 : ((StandardOrdinaryCoreProgram.allDefinitions[35]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.indexValues") := rfl
theorem duplicate_48 : ((StandardOrdinaryCoreProgram.allDefinitions[37]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.indexValue") := rfl
theorem duplicate_50 : ((StandardOrdinaryCoreProgram.allDefinitions[39]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "Range.get") := rfl
theorem duplicate_51 : ((StandardOrdinaryCoreProgram.allDefinitions[41]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.head") := rfl
theorem duplicate_52 : ((StandardOrdinaryCoreProgram.allDefinitions[43]?).map Prod.snd) = (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.tail") := rfl
theorem duplicate_53 : ((StandardOrdinaryCoreProgram.allDefinitions[44]?).map Prod.snd) = (StandardCollectionRefinedBodies.program.defs "Pair.first") := rfl
theorem duplicate_54 : ((StandardOrdinaryCoreProgram.allDefinitions[45]?).map Prod.snd) = (StandardCollectionRefinedBodies.program.defs "Pair.second") := rfl
theorem duplicate_55 : ((StandardOrdinaryCoreProgram.allDefinitions[46]?).map Prod.snd) = ((StandardBodies.listHigherRow false).definition) := rfl
end Benitoite.RefinementContractCollisions

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
