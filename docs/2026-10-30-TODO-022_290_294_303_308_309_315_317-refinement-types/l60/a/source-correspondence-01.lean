import Lean
import Benitoite.Release.Refinement.StandardModelResponse
import Benitoite.Release.Refinement.StandardAliasBodies
import Benitoite.Release.Refinement.StandardSafeBodies
namespace Benitoite.RefinementSourceCorrespondence
open Benitoite.Release.Refinement
theorem source001 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b001.key =
      ((StandardBodies.listHigherRow false).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source002 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b002.key =
      ((StandardBodies.listHigherRow true).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source003 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b003.key =
      (StandardOrdinaryCoreProgram.program.defs "List.fold" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source004 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b004.key =
      (StandardOrdinaryCoreProgram.program.defs "List.forEach" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source005 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b005.key =
      (StandardOrdinaryCoreProgram.program.defs "List.any" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source006 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b006.key =
      (StandardOrdinaryCoreProgram.program.defs "List.all" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source007 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b007.key =
      (StandardOrdinaryCoreProgram.program.defs "List.find" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source008 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b008.key =
      ((StandardBodies.collectionHigherRow true false).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source009 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b009.key =
      ((StandardBodies.collectionHigherRow true true).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source010 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b010.key =
      (StandardOrdinaryCoreProgram.program.defs "Map.fold" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source011 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b011.key =
      (StandardOrdinaryCoreProgram.program.defs "Map.forEach" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source012 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b012.key =
      ((StandardBodies.collectionHigherRow false false).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source013 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b013.key =
      ((StandardBodies.collectionHigherRow false true).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source014 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b014.key =
      (StandardOrdinaryCoreProgram.program.defs "Set.fold" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source015 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b015.key =
      (StandardOrdinaryCoreProgram.program.defs "Set.forEach" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source016 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b016.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.checkInteger" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source017 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b017.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.minimum" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source018 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b018.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.maximum" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source019 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b019.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.value" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source020 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b020.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.checkLength" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source021 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b021.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.lengthMinimum" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source022 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b022.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.lengthMaximum" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source023 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b023.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.checkedLength" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source024 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b024.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.lengthValues" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source025 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b025.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.checkIndex" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source026 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b026.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.indexValue" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source027 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b027.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.indexValues" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source028 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b028.key =
      (StandardOrdinaryCoreProgram.program.defs "Range.get" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source029 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b029.key =
      (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.fromList" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source030 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b030.key =
      (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.toList" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source031 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b031.key =
      (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.head" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source032 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b032.key =
      (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.tail" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source033 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b033.key =
      (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.map" : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source034 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b034.key =
      ((StandardAliasBodies.API.Integer64_toString.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source035 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b035.key =
      ((StandardAliasBodies.API.Integer64_parse.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source036 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b036.key =
      ((StandardAliasBodies.API.Integer64_toFloat.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source037 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b037.key =
      ((StandardAliasBodies.API.Integer64_floorDivide.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source038 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b038.key =
      ((StandardAliasBodies.API.Integer64_floorModulo.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source039 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b039.key =
      ((StandardAliasBodies.API.Integer64_absolute.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source040 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b040.key =
      ((StandardAliasBodies.API.Integer64_minimum.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source041 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b041.key =
      ((StandardAliasBodies.API.Integer64_maximum.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source042 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b042.key =
      ((StandardAliasBodies.API.Integer64_bitwiseAnd.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source043 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b043.key =
      ((StandardAliasBodies.API.Integer64_bitwiseOr.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source044 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b044.key =
      ((StandardAliasBodies.API.Integer64_bitwiseExclusiveOr.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source045 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b045.key =
      ((StandardAliasBodies.API.Integer64_bitwiseNot.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source046 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b046.key =
      ((StandardAliasBodies.API.Integer64_shiftLeft.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source047 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b047.key =
      ((StandardAliasBodies.API.Integer64_shiftRight.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source048 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b048.key =
      ((StandardAliasBodies.API.Integer64_shiftRightUnsigned.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source049 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b049.key =
      ((StandardAliasBodies.API.UnsignedInteger_fromInteger.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source050 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b050.key =
      ((StandardAliasBodies.API.UnsignedInteger_toInteger.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source051 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b051.key =
      ((StandardAliasBodies.API.UnsignedInteger_parse.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source052 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b052.key =
      ((StandardAliasBodies.API.UnsignedInteger_toString.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source053 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b053.key =
      ((StandardAliasBodies.API.UnsignedInteger_toFloat.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source054 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b054.key =
      ((StandardAliasBodies.API.UnsignedInteger_toDecimal.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source055 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b055.key =
      ((StandardAliasBodies.API.UnsignedInteger_fromDecimal.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source056 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b056.key =
      ((StandardAliasBodies.API.UnsignedInteger_absolute.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source057 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b057.key =
      ((StandardAliasBodies.API.UnsignedInteger_minimum.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source058 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b058.key =
      ((StandardAliasBodies.API.UnsignedInteger_maximum.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source059 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b059.key =
      ((StandardAliasBodies.API.UnsignedInteger_floorDivide.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source060 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b060.key =
      ((StandardAliasBodies.API.UnsignedInteger_floorModulo.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source061 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b061.key =
      ((StandardAliasBodies.API.UnsignedInteger_bitwiseAnd.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source062 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b062.key =
      ((StandardAliasBodies.API.UnsignedInteger_bitwiseOr.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source063 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b063.key =
      ((StandardAliasBodies.API.UnsignedInteger_bitwiseExclusiveOr.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source064 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b064.key =
      ((StandardAliasBodies.API.UnsignedInteger_bitwiseNot.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source065 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b065.key =
      ((StandardAliasBodies.API.UnsignedInteger_shiftLeft.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source066 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b066.key =
      ((StandardAliasBodies.API.UnsignedInteger_shiftRight.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source067 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b067.key =
      ((StandardAliasBodies.API.UnsignedInteger8_fromInteger.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source068 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b068.key =
      ((StandardAliasBodies.API.UnsignedInteger8_toInteger.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source069 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b069.key =
      ((StandardAliasBodies.API.UnsignedInteger8_toString.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source070 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b070.key =
      ((StandardAliasBodies.API.UnsignedInteger8_bitwiseAnd.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source071 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b071.key =
      ((StandardAliasBodies.API.UnsignedInteger8_bitwiseOr.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source072 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b072.key =
      ((StandardAliasBodies.API.UnsignedInteger8_bitwiseExclusiveOr.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source073 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b073.key =
      ((StandardAliasBodies.API.UnsignedInteger8_bitwiseNot.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source074 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b074.key =
      ((StandardAliasBodies.API.UnsignedInteger8_shiftLeft.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source075 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b075.key =
      ((StandardAliasBodies.API.UnsignedInteger8_shiftRight.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source076 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b076.key =
      ((StandardAliasBodies.API.Float64_toString.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source077 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b077.key =
      ((StandardAliasBodies.API.Float64_parse.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source078 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b078.key =
      ((StandardAliasBodies.API.Float64_truncate.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source079 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b079.key =
      ((StandardAliasBodies.API.Float64_isNaN.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
  rw [StandardModel.body_lookup]
  rfl

theorem source080 (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.b080.key =
      ((StandardAliasBodies.API.Float64_absolute.row).definition : Option Def).map
        (FunctionNames.definition (FunctionNames.rename false)) := by
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
