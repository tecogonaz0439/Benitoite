import Lean
import Benitoite.Release.Refinement.StandardModelResponse
import Benitoite.Release.Refinement.StandardAliasBodies
import Benitoite.Release.Refinement.StandardSafeBodies
namespace Benitoite.RefinementSourceCorrespondence
open Benitoite.Release.Refinement
theorem source081 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b081.key =
      ((StandardAliasBodies.API.Float64_floor.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source082 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b082.key =
      ((StandardAliasBodies.API.Float64_ceiling.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source083 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b083.key =
      ((StandardAliasBodies.API.Float64_round.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source084 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b084.key =
      ((StandardAliasBodies.API.Float64_squareRoot.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source085 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b085.key =
      (StandardSafe.headRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source086 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b086.key =
      (StandardSafe.getRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source087 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b087.key =
      (StandardSafe.checkedRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source088 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b088.key =
      (StandardSafe.sameRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source089 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b089.key =
      (StandardSafe.fromListRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source090 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b090.key =
      (StandardSafe.toListRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source091 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b091.key =
      (StandardSafe.nonemptyHeadRow.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source092 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b092.key =
      (StandardSafe.PreciseGetter.minimum.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source093 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b093.key =
      (StandardSafe.PreciseGetter.maximum.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source094 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b094.key =
      (StandardSafe.PreciseGetter.value.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source095 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b095.key =
      (StandardSafe.PreciseGetter.lengthMinimum.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source096 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b096.key =
      (StandardSafe.PreciseGetter.lengthMaximum.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source097 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b097.key =
      (StandardSafe.PreciseGetter.checkedLength.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source098 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b098.key =
      (StandardSafe.PreciseGetter.lengthValues.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source099 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b099.key =
      (StandardSafe.PreciseGetter.indexValue.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source100 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b100.key =
      (StandardSafe.PreciseGetter.indexValues.row.definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source101 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b101.key =
      (StandardCollectionRefinedBodies.program.defs "List.mapFrom" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source102 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b102.key =
      (StandardCollectionRefinedBodies.program.defs "List.filterFrom" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source103 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b103.key =
      (StandardCollectionRefinedBodies.program.defs "List.map" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source104 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b104.key =
      (StandardCollectionRefinedBodies.program.defs "List.filter" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source105 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b105.key =
      (StandardCollectionRefinedBodies.program.defs "NonEmptyList.map" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source106 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b106.key =
      (StandardCollectionRefinedBodies.program.defs "Pair.first" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source107 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b107.key =
      (StandardCollectionRefinedBodies.program.defs "Pair.second" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source108 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b108.key =
      (StandardCollectionRefinedBodies.program.defs "Map.map" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source109 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b109.key =
      (StandardCollectionRefinedBodies.program.defs "Map.filter" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source110 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b110.key =
      (StandardCollectionRefinedBodies.program.defs "Set.map" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source111 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b111.key =
      (StandardCollectionRefinedBodies.program.defs "Set.filter" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source112 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b010.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[0]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source113 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b011.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[1]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source114 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b014.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[2]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source115 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b015.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[3]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source116 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b016.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[4]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source117 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b020.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[5]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source118 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b025.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[6]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source119 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b029.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[7]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source120 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b030.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[8]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source121 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b033.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[9]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source122 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b003.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[10]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source123 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b112.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[11]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source124 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b004.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[12]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source125 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b113.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[13]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source126 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b005.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[14]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source127 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b114.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[15]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source128 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b006.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[16]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source129 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b115.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[17]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source130 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b007.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[18]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source131 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b116.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[19]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source132 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b117.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[20]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source133 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b017.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[21]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source134 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b118.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[22]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source135 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b018.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[23]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source136 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b119.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[24]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source137 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b019.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[25]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source138 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b120.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[26]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source139 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b021.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[27]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source140 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b121.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[28]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source141 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b022.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[29]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source142 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b122.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[30]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source143 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b023.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[31]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source144 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b123.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[32]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source145 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b024.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[33]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source146 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b124.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[34]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source147 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b027.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[35]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source148 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b125.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[36]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source149 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b026.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[37]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source150 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b126.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[38]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source151 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b028.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[39]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source152 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b127.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[40]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source153 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b031.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[41]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source154 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b128.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[42]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source155 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b032.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[43]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source156 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b106.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[44]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source157 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b107.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[45]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename true)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source158 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b001.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[46]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source159 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b129.key =
      ((StandardOrdinaryCoreProgram.allDefinitions[47]?).map Prod.snd : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem ordinary_filter_helper (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b130.key =
      some (FunctionNames.definition (FunctionNames.rename false) (StandardBodies.listFromDefinition true)) := by
  rw [StandardModel.body_lookup]
  rfl

end Benitoite.RefinementSourceCorrespondence
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let names := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if names.isEmpty then break
    for n in names do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      let deps ← Lean.collectAxioms n
      logInfo m!"'{n}' depends on axioms: [{String.intercalate ", " (deps.toList.map Name.toString)}]"
