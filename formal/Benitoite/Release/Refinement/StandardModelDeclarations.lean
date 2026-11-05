import Benitoite.Release.Refinement.FunctionNameMap
import Benitoite.Release.Refinement.StandardOrdinaryCoreProgram
import Benitoite.Release.Refinement.StandardCollectionRefinedBodies
import Benitoite.Release.Refinement.StandardSafeBodies
import Benitoite.Release.Refinement.StandardAliasBodies
import Benitoite.Release.Refinement.ScopeDeclarations

/-! # 標準本体の元定義と、関数参照名を写した有限宣言 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

inductive Body where
  | b001
  | b002
  | b003
  | b004
  | b005
  | b006
  | b007
  | b008
  | b009
  | b010
  | b011
  | b012
  | b013
  | b014
  | b015
  | b016
  | b017
  | b018
  | b019
  | b020
  | b021
  | b022
  | b023
  | b024
  | b025
  | b026
  | b027
  | b028
  | b029
  | b030
  | b031
  | b032
  | b033
  | b034
  | b035
  | b036
  | b037
  | b038
  | b039
  | b040
  | b041
  | b042
  | b043
  | b044
  | b045
  | b046
  | b047
  | b048
  | b049
  | b050
  | b051
  | b052
  | b053
  | b054
  | b055
  | b056
  | b057
  | b058
  | b059
  | b060
  | b061
  | b062
  | b063
  | b064
  | b065
  | b066
  | b067
  | b068
  | b069
  | b070
  | b071
  | b072
  | b073
  | b074
  | b075
  | b076
  | b077
  | b078
  | b079
  | b080
  | b081
  | b082
  | b083
  | b084
  | b085
  | b086
  | b087
  | b088
  | b089
  | b090
  | b091
  | b092
  | b093
  | b094
  | b095
  | b096
  | b097
  | b098
  | b099
  | b100
  | b101
  | b102
  | b103
  | b104
  | b105
  | b106
  | b107
  | b108
  | b109
  | b110
  | b111
  | b112
  | b113
  | b114
  | b115
  | b116
  | b117
  | b118
  | b119
  | b120
  | b121
  | b122
  | b123
  | b124
  | b125
  | b126
  | b127
  | b128
  | b129
  | b130

def Body.name : Body → String
  | .b001 => "List.map"
  | .b002 => "List.filter"
  | .b003 => "List.fold"
  | .b004 => "List.forEach"
  | .b005 => "List.any"
  | .b006 => "List.all"
  | .b007 => "List.find"
  | .b008 => "Map.map"
  | .b009 => "Map.filter"
  | .b010 => "Map.fold"
  | .b011 => "Map.forEach"
  | .b012 => "Set.map"
  | .b013 => "Set.filter"
  | .b014 => "Set.fold"
  | .b015 => "Set.forEach"
  | .b016 => "Range.checkInteger"
  | .b017 => "Range.minimum"
  | .b018 => "Range.maximum"
  | .b019 => "Range.value"
  | .b020 => "Range.checkLength"
  | .b021 => "Range.lengthMinimum"
  | .b022 => "Range.lengthMaximum"
  | .b023 => "Range.checkedLength"
  | .b024 => "Range.lengthValues"
  | .b025 => "Range.checkIndex"
  | .b026 => "Range.indexValue"
  | .b027 => "Range.indexValues"
  | .b028 => "Range.get"
  | .b029 => "NonEmptyList.fromList"
  | .b030 => "NonEmptyList.toList"
  | .b031 => "NonEmptyList.head"
  | .b032 => "NonEmptyList.tail"
  | .b033 => "NonEmptyList.map"
  | .b034 => "Integer64.toString"
  | .b035 => "Integer64.parse"
  | .b036 => "Integer64.toFloat"
  | .b037 => "Integer64.floorDivide"
  | .b038 => "Integer64.floorModulo"
  | .b039 => "Integer64.absolute"
  | .b040 => "Integer64.minimum"
  | .b041 => "Integer64.maximum"
  | .b042 => "Integer64.bitwiseAnd"
  | .b043 => "Integer64.bitwiseOr"
  | .b044 => "Integer64.bitwiseExclusiveOr"
  | .b045 => "Integer64.bitwiseNot"
  | .b046 => "Integer64.shiftLeft"
  | .b047 => "Integer64.shiftRight"
  | .b048 => "Integer64.shiftRightUnsigned"
  | .b049 => "UnsignedInteger.fromInteger"
  | .b050 => "UnsignedInteger.toInteger"
  | .b051 => "UnsignedInteger.parse"
  | .b052 => "UnsignedInteger.toString"
  | .b053 => "UnsignedInteger.toFloat"
  | .b054 => "UnsignedInteger.toDecimal"
  | .b055 => "UnsignedInteger.fromDecimal"
  | .b056 => "UnsignedInteger.absolute"
  | .b057 => "UnsignedInteger.minimum"
  | .b058 => "UnsignedInteger.maximum"
  | .b059 => "UnsignedInteger.floorDivide"
  | .b060 => "UnsignedInteger.floorModulo"
  | .b061 => "UnsignedInteger.bitwiseAnd"
  | .b062 => "UnsignedInteger.bitwiseOr"
  | .b063 => "UnsignedInteger.bitwiseExclusiveOr"
  | .b064 => "UnsignedInteger.bitwiseNot"
  | .b065 => "UnsignedInteger.shiftLeft"
  | .b066 => "UnsignedInteger.shiftRight"
  | .b067 => "UnsignedInteger8.fromInteger"
  | .b068 => "UnsignedInteger8.toInteger"
  | .b069 => "UnsignedInteger8.toString"
  | .b070 => "UnsignedInteger8.bitwiseAnd"
  | .b071 => "UnsignedInteger8.bitwiseOr"
  | .b072 => "UnsignedInteger8.bitwiseExclusiveOr"
  | .b073 => "UnsignedInteger8.bitwiseNot"
  | .b074 => "UnsignedInteger8.shiftLeft"
  | .b075 => "UnsignedInteger8.shiftRight"
  | .b076 => "Float64.toString"
  | .b077 => "Float64.parse"
  | .b078 => "Float64.truncate"
  | .b079 => "Float64.isNaN"
  | .b080 => "Float64.absolute"
  | .b081 => "Float64.floor"
  | .b082 => "Float64.ceiling"
  | .b083 => "Float64.round"
  | .b084 => "Float64.squareRoot"
  | .b085 => "Internal.safeHead"
  | .b086 => "Internal.safeGet"
  | .b087 => "Internal.CheckedIndex.get"
  | .b088 => "Internal.sameLengthGet"
  | .b089 => "Internal.NonEmptyList.fromList"
  | .b090 => "Internal.NonEmptyList.toList"
  | .b091 => "Internal.NonEmptyList.head"
  | .b092 => "Range.minimum"
  | .b093 => "Range.maximum"
  | .b094 => "Range.value"
  | .b095 => "Range.lengthMinimum"
  | .b096 => "Range.lengthMaximum"
  | .b097 => "Range.checkedLength"
  | .b098 => "Range.lengthValues"
  | .b099 => "Range.indexValue"
  | .b100 => "Range.indexValues"
  | .b101 => "List.mapFrom"
  | .b102 => "List.filterFrom"
  | .b103 => "List.map"
  | .b104 => "List.filter"
  | .b105 => "NonEmptyList.map"
  | .b106 => "Pair.first"
  | .b107 => "Pair.second"
  | .b108 => "Map.map"
  | .b109 => "Map.filter"
  | .b110 => "Set.map"
  | .b111 => "Set.filter"
  | .b112 => "List.foldFrom"
  | .b113 => "List.forEachFrom"
  | .b114 => "List.anyFrom"
  | .b115 => "List.allFrom"
  | .b116 => "List.findFrom"
  | .b117 => "Benitoite.Range.CheckedInteger.minimum"
  | .b118 => "Benitoite.Range.CheckedInteger.maximum"
  | .b119 => "Benitoite.Range.CheckedInteger.value"
  | .b120 => "Benitoite.Range.CheckedLength.minimum"
  | .b121 => "Benitoite.Range.CheckedLength.maximum"
  | .b122 => "Benitoite.Range.CheckedLength.length"
  | .b123 => "Benitoite.Range.CheckedLength.values"
  | .b124 => "Benitoite.Range.CheckedIndex.values"
  | .b125 => "Benitoite.Range.CheckedIndex.index"
  | .b126 => "Benitoite.Range.CheckedIndex.element"
  | .b127 => "Benitoite.NonEmptyList.NonEmptyList.first"
  | .b128 => "Benitoite.NonEmptyList.NonEmptyList.rest"
  | .b129 => "List.mapFrom"
  | .b130 => "List.filterFrom"

def Body.refined : Body → Bool
  | .b001 => false
  | .b002 => false
  | .b003 => false
  | .b004 => false
  | .b005 => false
  | .b006 => false
  | .b007 => false
  | .b008 => false
  | .b009 => false
  | .b010 => false
  | .b011 => false
  | .b012 => false
  | .b013 => false
  | .b014 => false
  | .b015 => false
  | .b016 => false
  | .b017 => false
  | .b018 => false
  | .b019 => false
  | .b020 => false
  | .b021 => false
  | .b022 => false
  | .b023 => false
  | .b024 => false
  | .b025 => false
  | .b026 => false
  | .b027 => false
  | .b028 => false
  | .b029 => false
  | .b030 => false
  | .b031 => false
  | .b032 => false
  | .b033 => false
  | .b034 => false
  | .b035 => false
  | .b036 => false
  | .b037 => false
  | .b038 => false
  | .b039 => false
  | .b040 => false
  | .b041 => false
  | .b042 => false
  | .b043 => false
  | .b044 => false
  | .b045 => false
  | .b046 => false
  | .b047 => false
  | .b048 => false
  | .b049 => false
  | .b050 => false
  | .b051 => false
  | .b052 => false
  | .b053 => false
  | .b054 => false
  | .b055 => false
  | .b056 => false
  | .b057 => false
  | .b058 => false
  | .b059 => false
  | .b060 => false
  | .b061 => false
  | .b062 => false
  | .b063 => false
  | .b064 => false
  | .b065 => false
  | .b066 => false
  | .b067 => false
  | .b068 => false
  | .b069 => false
  | .b070 => false
  | .b071 => false
  | .b072 => false
  | .b073 => false
  | .b074 => false
  | .b075 => false
  | .b076 => false
  | .b077 => false
  | .b078 => false
  | .b079 => false
  | .b080 => false
  | .b081 => false
  | .b082 => false
  | .b083 => false
  | .b084 => false
  | .b085 => false
  | .b086 => false
  | .b087 => false
  | .b088 => false
  | .b089 => false
  | .b090 => false
  | .b091 => false
  | .b092 => true
  | .b093 => true
  | .b094 => true
  | .b095 => true
  | .b096 => true
  | .b097 => true
  | .b098 => true
  | .b099 => true
  | .b100 => true
  | .b101 => true
  | .b102 => true
  | .b103 => true
  | .b104 => true
  | .b105 => true
  | .b106 => true
  | .b107 => true
  | .b108 => true
  | .b109 => true
  | .b110 => true
  | .b111 => true
  | .b112 => false
  | .b113 => false
  | .b114 => false
  | .b115 => false
  | .b116 => false
  | .b117 => false
  | .b118 => false
  | .b119 => false
  | .b120 => false
  | .b121 => false
  | .b122 => false
  | .b123 => false
  | .b124 => false
  | .b125 => false
  | .b126 => false
  | .b127 => false
  | .b128 => false
  | .b129 => false
  | .b130 => false

/-- 出典のDefはそのまま保持する。存在の証拠は各出典の定義から供給する。 -/
def Body.original : Body → Def
  | .b001 => ((StandardBodies.listHigherRow false).definition : Option Def).get (by rfl)
  | .b002 => ((StandardBodies.listHigherRow true).definition : Option Def).get (by rfl)
  | .b003 => (StandardOrdinaryCoreProgram.program.defs "List.fold" : Option Def).get (by rfl)
  | .b004 => (StandardOrdinaryCoreProgram.program.defs "List.forEach" : Option Def).get (by rfl)
  | .b005 => (StandardOrdinaryCoreProgram.program.defs "List.any" : Option Def).get (by rfl)
  | .b006 => (StandardOrdinaryCoreProgram.program.defs "List.all" : Option Def).get (by rfl)
  | .b007 => (StandardOrdinaryCoreProgram.program.defs "List.find" : Option Def).get (by rfl)
  | .b008 => ((StandardBodies.collectionHigherRow true false).definition : Option Def).get (by rfl)
  | .b009 => ((StandardBodies.collectionHigherRow true true).definition : Option Def).get (by rfl)
  | .b010 => (StandardOrdinaryCoreProgram.program.defs "Map.fold" : Option Def).get (by rfl)
  | .b011 => (StandardOrdinaryCoreProgram.program.defs "Map.forEach" : Option Def).get (by rfl)
  | .b012 => ((StandardBodies.collectionHigherRow false false).definition : Option Def).get (by rfl)
  | .b013 => ((StandardBodies.collectionHigherRow false true).definition : Option Def).get (by rfl)
  | .b014 => (StandardOrdinaryCoreProgram.program.defs "Set.fold" : Option Def).get (by rfl)
  | .b015 => (StandardOrdinaryCoreProgram.program.defs "Set.forEach" : Option Def).get (by rfl)
  | .b016 => (StandardOrdinaryCoreProgram.program.defs "Range.checkInteger" : Option Def).get (by rfl)
  | .b017 => (StandardOrdinaryCoreProgram.program.defs "Range.minimum" : Option Def).get (by rfl)
  | .b018 => (StandardOrdinaryCoreProgram.program.defs "Range.maximum" : Option Def).get (by rfl)
  | .b019 => (StandardOrdinaryCoreProgram.program.defs "Range.value" : Option Def).get (by rfl)
  | .b020 => (StandardOrdinaryCoreProgram.program.defs "Range.checkLength" : Option Def).get (by rfl)
  | .b021 => (StandardOrdinaryCoreProgram.program.defs "Range.lengthMinimum" : Option Def).get (by rfl)
  | .b022 => (StandardOrdinaryCoreProgram.program.defs "Range.lengthMaximum" : Option Def).get (by rfl)
  | .b023 => (StandardOrdinaryCoreProgram.program.defs "Range.checkedLength" : Option Def).get (by rfl)
  | .b024 => (StandardOrdinaryCoreProgram.program.defs "Range.lengthValues" : Option Def).get (by rfl)
  | .b025 => (StandardOrdinaryCoreProgram.program.defs "Range.checkIndex" : Option Def).get (by rfl)
  | .b026 => (StandardOrdinaryCoreProgram.program.defs "Range.indexValue" : Option Def).get (by rfl)
  | .b027 => (StandardOrdinaryCoreProgram.program.defs "Range.indexValues" : Option Def).get (by rfl)
  | .b028 => (StandardOrdinaryCoreProgram.program.defs "Range.get" : Option Def).get (by rfl)
  | .b029 => (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.fromList" : Option Def).get (by rfl)
  | .b030 => (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.toList" : Option Def).get (by rfl)
  | .b031 => (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.head" : Option Def).get (by rfl)
  | .b032 => (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.tail" : Option Def).get (by rfl)
  | .b033 => (StandardOrdinaryCoreProgram.program.defs "NonEmptyList.map" : Option Def).get (by rfl)
  | .b034 => ((StandardAliasBodies.API.Integer64_toString.row).definition : Option Def).get (by rfl)
  | .b035 => ((StandardAliasBodies.API.Integer64_parse.row).definition : Option Def).get (by rfl)
  | .b036 => ((StandardAliasBodies.API.Integer64_toFloat.row).definition : Option Def).get (by rfl)
  | .b037 => ((StandardAliasBodies.API.Integer64_floorDivide.row).definition : Option Def).get (by rfl)
  | .b038 => ((StandardAliasBodies.API.Integer64_floorModulo.row).definition : Option Def).get (by rfl)
  | .b039 => ((StandardAliasBodies.API.Integer64_absolute.row).definition : Option Def).get (by rfl)
  | .b040 => ((StandardAliasBodies.API.Integer64_minimum.row).definition : Option Def).get (by rfl)
  | .b041 => ((StandardAliasBodies.API.Integer64_maximum.row).definition : Option Def).get (by rfl)
  | .b042 => ((StandardAliasBodies.API.Integer64_bitwiseAnd.row).definition : Option Def).get (by rfl)
  | .b043 => ((StandardAliasBodies.API.Integer64_bitwiseOr.row).definition : Option Def).get (by rfl)
  | .b044 => ((StandardAliasBodies.API.Integer64_bitwiseExclusiveOr.row).definition : Option Def).get (by rfl)
  | .b045 => ((StandardAliasBodies.API.Integer64_bitwiseNot.row).definition : Option Def).get (by rfl)
  | .b046 => ((StandardAliasBodies.API.Integer64_shiftLeft.row).definition : Option Def).get (by rfl)
  | .b047 => ((StandardAliasBodies.API.Integer64_shiftRight.row).definition : Option Def).get (by rfl)
  | .b048 => ((StandardAliasBodies.API.Integer64_shiftRightUnsigned.row).definition : Option Def).get (by rfl)
  | .b049 => ((StandardAliasBodies.API.UnsignedInteger_fromInteger.row).definition : Option Def).get (by rfl)
  | .b050 => ((StandardAliasBodies.API.UnsignedInteger_toInteger.row).definition : Option Def).get (by rfl)
  | .b051 => ((StandardAliasBodies.API.UnsignedInteger_parse.row).definition : Option Def).get (by rfl)
  | .b052 => ((StandardAliasBodies.API.UnsignedInteger_toString.row).definition : Option Def).get (by rfl)
  | .b053 => ((StandardAliasBodies.API.UnsignedInteger_toFloat.row).definition : Option Def).get (by rfl)
  | .b054 => ((StandardAliasBodies.API.UnsignedInteger_toDecimal.row).definition : Option Def).get (by rfl)
  | .b055 => ((StandardAliasBodies.API.UnsignedInteger_fromDecimal.row).definition : Option Def).get (by rfl)
  | .b056 => ((StandardAliasBodies.API.UnsignedInteger_absolute.row).definition : Option Def).get (by rfl)
  | .b057 => ((StandardAliasBodies.API.UnsignedInteger_minimum.row).definition : Option Def).get (by rfl)
  | .b058 => ((StandardAliasBodies.API.UnsignedInteger_maximum.row).definition : Option Def).get (by rfl)
  | .b059 => ((StandardAliasBodies.API.UnsignedInteger_floorDivide.row).definition : Option Def).get (by rfl)
  | .b060 => ((StandardAliasBodies.API.UnsignedInteger_floorModulo.row).definition : Option Def).get (by rfl)
  | .b061 => ((StandardAliasBodies.API.UnsignedInteger_bitwiseAnd.row).definition : Option Def).get (by rfl)
  | .b062 => ((StandardAliasBodies.API.UnsignedInteger_bitwiseOr.row).definition : Option Def).get (by rfl)
  | .b063 => ((StandardAliasBodies.API.UnsignedInteger_bitwiseExclusiveOr.row).definition : Option Def).get (by rfl)
  | .b064 => ((StandardAliasBodies.API.UnsignedInteger_bitwiseNot.row).definition : Option Def).get (by rfl)
  | .b065 => ((StandardAliasBodies.API.UnsignedInteger_shiftLeft.row).definition : Option Def).get (by rfl)
  | .b066 => ((StandardAliasBodies.API.UnsignedInteger_shiftRight.row).definition : Option Def).get (by rfl)
  | .b067 => ((StandardAliasBodies.API.UnsignedInteger8_fromInteger.row).definition : Option Def).get (by rfl)
  | .b068 => ((StandardAliasBodies.API.UnsignedInteger8_toInteger.row).definition : Option Def).get (by rfl)
  | .b069 => ((StandardAliasBodies.API.UnsignedInteger8_toString.row).definition : Option Def).get (by rfl)
  | .b070 => ((StandardAliasBodies.API.UnsignedInteger8_bitwiseAnd.row).definition : Option Def).get (by rfl)
  | .b071 => ((StandardAliasBodies.API.UnsignedInteger8_bitwiseOr.row).definition : Option Def).get (by rfl)
  | .b072 => ((StandardAliasBodies.API.UnsignedInteger8_bitwiseExclusiveOr.row).definition : Option Def).get (by rfl)
  | .b073 => ((StandardAliasBodies.API.UnsignedInteger8_bitwiseNot.row).definition : Option Def).get (by rfl)
  | .b074 => ((StandardAliasBodies.API.UnsignedInteger8_shiftLeft.row).definition : Option Def).get (by rfl)
  | .b075 => ((StandardAliasBodies.API.UnsignedInteger8_shiftRight.row).definition : Option Def).get (by rfl)
  | .b076 => ((StandardAliasBodies.API.Float64_toString.row).definition : Option Def).get (by rfl)
  | .b077 => ((StandardAliasBodies.API.Float64_parse.row).definition : Option Def).get (by rfl)
  | .b078 => ((StandardAliasBodies.API.Float64_truncate.row).definition : Option Def).get (by rfl)
  | .b079 => ((StandardAliasBodies.API.Float64_isNaN.row).definition : Option Def).get (by rfl)
  | .b080 => ((StandardAliasBodies.API.Float64_absolute.row).definition : Option Def).get (by rfl)
  | .b081 => ((StandardAliasBodies.API.Float64_floor.row).definition : Option Def).get (by rfl)
  | .b082 => ((StandardAliasBodies.API.Float64_ceiling.row).definition : Option Def).get (by rfl)
  | .b083 => ((StandardAliasBodies.API.Float64_round.row).definition : Option Def).get (by rfl)
  | .b084 => ((StandardAliasBodies.API.Float64_squareRoot.row).definition : Option Def).get (by rfl)
  | .b085 => (StandardSafe.headRow.definition : Option Def).get (by rfl)
  | .b086 => (StandardSafe.getRow.definition : Option Def).get (by rfl)
  | .b087 => (StandardSafe.checkedRow.definition : Option Def).get (by rfl)
  | .b088 => (StandardSafe.sameRow.definition : Option Def).get (by rfl)
  | .b089 => (StandardSafe.fromListRow.definition : Option Def).get (by rfl)
  | .b090 => (StandardSafe.toListRow.definition : Option Def).get (by rfl)
  | .b091 => (StandardSafe.nonemptyHeadRow.definition : Option Def).get (by rfl)
  | .b092 => (StandardSafe.PreciseGetter.minimum.row.definition : Option Def).get (by rfl)
  | .b093 => (StandardSafe.PreciseGetter.maximum.row.definition : Option Def).get (by rfl)
  | .b094 => (StandardSafe.PreciseGetter.value.row.definition : Option Def).get (by rfl)
  | .b095 => (StandardSafe.PreciseGetter.lengthMinimum.row.definition : Option Def).get (by rfl)
  | .b096 => (StandardSafe.PreciseGetter.lengthMaximum.row.definition : Option Def).get (by rfl)
  | .b097 => (StandardSafe.PreciseGetter.checkedLength.row.definition : Option Def).get (by rfl)
  | .b098 => (StandardSafe.PreciseGetter.lengthValues.row.definition : Option Def).get (by rfl)
  | .b099 => (StandardSafe.PreciseGetter.indexValue.row.definition : Option Def).get (by rfl)
  | .b100 => (StandardSafe.PreciseGetter.indexValues.row.definition : Option Def).get (by rfl)
  | .b101 => (StandardCollectionRefinedBodies.program.defs "List.mapFrom" : Option Def).get (by rfl)
  | .b102 => (StandardCollectionRefinedBodies.program.defs "List.filterFrom" : Option Def).get (by rfl)
  | .b103 => (StandardCollectionRefinedBodies.program.defs "List.map" : Option Def).get (by rfl)
  | .b104 => (StandardCollectionRefinedBodies.program.defs "List.filter" : Option Def).get (by rfl)
  | .b105 => (StandardCollectionRefinedBodies.program.defs "NonEmptyList.map" : Option Def).get (by rfl)
  | .b106 => (StandardCollectionRefinedBodies.program.defs "Pair.first" : Option Def).get (by rfl)
  | .b107 => (StandardCollectionRefinedBodies.program.defs "Pair.second" : Option Def).get (by rfl)
  | .b108 => (StandardCollectionRefinedBodies.program.defs "Map.map" : Option Def).get (by rfl)
  | .b109 => (StandardCollectionRefinedBodies.program.defs "Map.filter" : Option Def).get (by rfl)
  | .b110 => (StandardCollectionRefinedBodies.program.defs "Set.map" : Option Def).get (by rfl)
  | .b111 => (StandardCollectionRefinedBodies.program.defs "Set.filter" : Option Def).get (by rfl)
  | .b112 => ((StandardOrdinaryCoreProgram.allDefinitions[11]?).map Prod.snd : Option Def).get (by rfl)
  | .b113 => ((StandardOrdinaryCoreProgram.allDefinitions[13]?).map Prod.snd : Option Def).get (by rfl)
  | .b114 => ((StandardOrdinaryCoreProgram.allDefinitions[15]?).map Prod.snd : Option Def).get (by rfl)
  | .b115 => ((StandardOrdinaryCoreProgram.allDefinitions[17]?).map Prod.snd : Option Def).get (by rfl)
  | .b116 => ((StandardOrdinaryCoreProgram.allDefinitions[19]?).map Prod.snd : Option Def).get (by rfl)
  | .b117 => ((StandardOrdinaryCoreProgram.allDefinitions[20]?).map Prod.snd : Option Def).get (by rfl)
  | .b118 => ((StandardOrdinaryCoreProgram.allDefinitions[22]?).map Prod.snd : Option Def).get (by rfl)
  | .b119 => ((StandardOrdinaryCoreProgram.allDefinitions[24]?).map Prod.snd : Option Def).get (by rfl)
  | .b120 => ((StandardOrdinaryCoreProgram.allDefinitions[26]?).map Prod.snd : Option Def).get (by rfl)
  | .b121 => ((StandardOrdinaryCoreProgram.allDefinitions[28]?).map Prod.snd : Option Def).get (by rfl)
  | .b122 => ((StandardOrdinaryCoreProgram.allDefinitions[30]?).map Prod.snd : Option Def).get (by rfl)
  | .b123 => ((StandardOrdinaryCoreProgram.allDefinitions[32]?).map Prod.snd : Option Def).get (by rfl)
  | .b124 => ((StandardOrdinaryCoreProgram.allDefinitions[34]?).map Prod.snd : Option Def).get (by rfl)
  | .b125 => ((StandardOrdinaryCoreProgram.allDefinitions[36]?).map Prod.snd : Option Def).get (by rfl)
  | .b126 => ((StandardOrdinaryCoreProgram.allDefinitions[38]?).map Prod.snd : Option Def).get (by rfl)
  | .b127 => ((StandardOrdinaryCoreProgram.allDefinitions[40]?).map Prod.snd : Option Def).get (by rfl)
  | .b128 => ((StandardOrdinaryCoreProgram.allDefinitions[42]?).map Prod.snd : Option Def).get (by rfl)
  | .b129 => ((StandardOrdinaryCoreProgram.allDefinitions[47]?).map Prod.snd : Option Def).get (by rfl)
  | .b130 => (some (StandardBodies.listFromDefinition true) : Option Def).get (by rfl)

def Body.key : Body → String
  | .b001 => "%List.map.ordinary"
  | .b002 => "%List.filter.ordinary"
  | .b003 => "List.fold"
  | .b004 => "List.forEach"
  | .b005 => "List.any"
  | .b006 => "List.all"
  | .b007 => "List.find"
  | .b008 => "%Map.map.ordinary"
  | .b009 => "%Map.filter.ordinary"
  | .b010 => "Map.fold"
  | .b011 => "Map.forEach"
  | .b012 => "%Set.map.ordinary"
  | .b013 => "%Set.filter.ordinary"
  | .b014 => "Set.fold"
  | .b015 => "Set.forEach"
  | .b016 => "Range.checkInteger"
  | .b017 => "%Range.minimum.ordinary"
  | .b018 => "%Range.maximum.ordinary"
  | .b019 => "%Range.value.ordinary"
  | .b020 => "Range.checkLength"
  | .b021 => "%Range.lengthMinimum.ordinary"
  | .b022 => "%Range.lengthMaximum.ordinary"
  | .b023 => "%Range.checkedLength.ordinary"
  | .b024 => "%Range.lengthValues.ordinary"
  | .b025 => "Range.checkIndex"
  | .b026 => "%Range.indexValue.ordinary"
  | .b027 => "%Range.indexValues.ordinary"
  | .b028 => "Range.get"
  | .b029 => "NonEmptyList.fromList"
  | .b030 => "NonEmptyList.toList"
  | .b031 => "NonEmptyList.head"
  | .b032 => "NonEmptyList.tail"
  | .b033 => "%NonEmptyList.map.ordinary"
  | .b034 => "Integer64.toString"
  | .b035 => "Integer64.parse"
  | .b036 => "Integer64.toFloat"
  | .b037 => "Integer64.floorDivide"
  | .b038 => "Integer64.floorModulo"
  | .b039 => "Integer64.absolute"
  | .b040 => "Integer64.minimum"
  | .b041 => "Integer64.maximum"
  | .b042 => "Integer64.bitwiseAnd"
  | .b043 => "Integer64.bitwiseOr"
  | .b044 => "Integer64.bitwiseExclusiveOr"
  | .b045 => "Integer64.bitwiseNot"
  | .b046 => "Integer64.shiftLeft"
  | .b047 => "Integer64.shiftRight"
  | .b048 => "Integer64.shiftRightUnsigned"
  | .b049 => "UnsignedInteger.fromInteger"
  | .b050 => "UnsignedInteger.toInteger"
  | .b051 => "UnsignedInteger.parse"
  | .b052 => "UnsignedInteger.toString"
  | .b053 => "UnsignedInteger.toFloat"
  | .b054 => "UnsignedInteger.toDecimal"
  | .b055 => "UnsignedInteger.fromDecimal"
  | .b056 => "UnsignedInteger.absolute"
  | .b057 => "UnsignedInteger.minimum"
  | .b058 => "UnsignedInteger.maximum"
  | .b059 => "UnsignedInteger.floorDivide"
  | .b060 => "UnsignedInteger.floorModulo"
  | .b061 => "UnsignedInteger.bitwiseAnd"
  | .b062 => "UnsignedInteger.bitwiseOr"
  | .b063 => "UnsignedInteger.bitwiseExclusiveOr"
  | .b064 => "UnsignedInteger.bitwiseNot"
  | .b065 => "UnsignedInteger.shiftLeft"
  | .b066 => "UnsignedInteger.shiftRight"
  | .b067 => "UnsignedInteger8.fromInteger"
  | .b068 => "UnsignedInteger8.toInteger"
  | .b069 => "UnsignedInteger8.toString"
  | .b070 => "UnsignedInteger8.bitwiseAnd"
  | .b071 => "UnsignedInteger8.bitwiseOr"
  | .b072 => "UnsignedInteger8.bitwiseExclusiveOr"
  | .b073 => "UnsignedInteger8.bitwiseNot"
  | .b074 => "UnsignedInteger8.shiftLeft"
  | .b075 => "UnsignedInteger8.shiftRight"
  | .b076 => "Float64.toString"
  | .b077 => "Float64.parse"
  | .b078 => "Float64.truncate"
  | .b079 => "Float64.isNaN"
  | .b080 => "Float64.absolute"
  | .b081 => "Float64.floor"
  | .b082 => "Float64.ceiling"
  | .b083 => "Float64.round"
  | .b084 => "Float64.squareRoot"
  | .b085 => "Internal.safeHead"
  | .b086 => "Internal.safeGet"
  | .b087 => "Internal.CheckedIndex.get"
  | .b088 => "Internal.sameLengthGet"
  | .b089 => "Internal.NonEmptyList.fromList"
  | .b090 => "Internal.NonEmptyList.toList"
  | .b091 => "Internal.NonEmptyList.head"
  | .b092 => "%Range.minimum.refined"
  | .b093 => "%Range.maximum.refined"
  | .b094 => "%Range.value.refined"
  | .b095 => "%Range.lengthMinimum.refined"
  | .b096 => "%Range.lengthMaximum.refined"
  | .b097 => "%Range.checkedLength.refined"
  | .b098 => "%Range.lengthValues.refined"
  | .b099 => "%Range.indexValue.refined"
  | .b100 => "%Range.indexValues.refined"
  | .b101 => "%List.mapFrom.refined"
  | .b102 => "%List.filterFrom.refined"
  | .b103 => "%List.map.refined"
  | .b104 => "%List.filter.refined"
  | .b105 => "%NonEmptyList.map.refined"
  | .b106 => "Pair.first"
  | .b107 => "Pair.second"
  | .b108 => "%Map.map.refined"
  | .b109 => "%Map.filter.refined"
  | .b110 => "%Set.map.refined"
  | .b111 => "%Set.filter.refined"
  | .b112 => "List.foldFrom"
  | .b113 => "List.forEachFrom"
  | .b114 => "List.anyFrom"
  | .b115 => "List.allFrom"
  | .b116 => "List.findFrom"
  | .b117 => "Benitoite.Range.CheckedInteger.minimum"
  | .b118 => "Benitoite.Range.CheckedInteger.maximum"
  | .b119 => "Benitoite.Range.CheckedInteger.value"
  | .b120 => "Benitoite.Range.CheckedLength.minimum"
  | .b121 => "Benitoite.Range.CheckedLength.maximum"
  | .b122 => "Benitoite.Range.CheckedLength.length"
  | .b123 => "Benitoite.Range.CheckedLength.values"
  | .b124 => "Benitoite.Range.CheckedIndex.values"
  | .b125 => "Benitoite.Range.CheckedIndex.index"
  | .b126 => "Benitoite.Range.CheckedIndex.element"
  | .b127 => "Benitoite.NonEmptyList.NonEmptyList.first"
  | .b128 => "Benitoite.NonEmptyList.NonEmptyList.rest"
  | .b129 => "%List.mapFrom.ordinary"
  | .b130 => "%List.filterFrom.ordinary"

theorem Body.key_correspondence (body : Body) : body.key = FunctionNames.rename body.refined body.name := by
  cases body <;> rfl

def Body.definition (body : Body) : Def :=
  FunctionNames.definition (FunctionNames.rename body.refined) body.original

/-- 全元定義に対して、本体の関数参照名だけを写す。 -/
theorem Body.correspondence (body : Body) :
    body.definition = FunctionNames.definition (FunctionNames.rename body.refined) body.original := rfl

theorem Body.tel (body : Body) : body.definition.tel = body.original.tel :=
  FunctionNames.definition_tel _ _

def Body.all : List Body := [.b001,.b002,.b003,.b004,.b005,.b006,.b007,.b008,.b009,.b010,.b011,.b012,.b013,.b014,.b015,.b016,.b017,.b018,.b019,.b020,.b021,.b022,.b023,.b024,.b025,.b026,.b027,.b028,.b029,.b030,.b031,.b032,.b033,.b034,.b035,.b036,.b037,.b038,.b039,.b040,.b041,.b042,.b043,.b044,.b045,.b046,.b047,.b048,.b049,.b050,.b051,.b052,.b053,.b054,.b055,.b056,.b057,.b058,.b059,.b060,.b061,.b062,.b063,.b064,.b065,.b066,.b067,.b068,.b069,.b070,.b071,.b072,.b073,.b074,.b075,.b076,.b077,.b078,.b079,.b080,.b081,.b082,.b083,.b084,.b085,.b086,.b087,.b088,.b089,.b090,.b091,.b092,.b093,.b094,.b095,.b096,.b097,.b098,.b099,.b100,.b101,.b102,.b103,.b104,.b105,.b106,.b107,.b108,.b109,.b110,.b111,.b112,.b113,.b114,.b115,.b116,.b117,.b118,.b119,.b120,.b121,.b122,.b123,.b124,.b125,.b126,.b127,.b128,.b129,.b130]

def definitions : List (String × Def) := Body.all.map (fun body => (body.key,body.definition))
/-- Decimalの丸めの五方式。Decimal.roundの引数の型が読む。 -/
def roundingMode : StandardKeyTyping.DataDecl :=
  ⟨"RoundingMode",0,[("RoundingMode.HalfToEven",[]),("RoundingMode.HalfAwayFromZero",[]),
    ("RoundingMode.TowardZero",[]),("RoundingMode.TowardNegativeInfinity",[]),
    ("RoundingMode.TowardPositiveInfinity",[])]⟩
def declarations : List StandardKeyTyping.DataDecl :=
  StandardOrdinaryCoreBodies.declarations ++ ScopeDeclarations.http.filter
    (fun d => !(StandardOrdinaryCoreBodies.declarations.any (fun old => old.name == d.name))) ++
    [roundingMode]
def constructors : List (String × ConDecl) := declarations.flatMap StandardKeyTyping.DataDecl.entries

def program (externals : List (ExternalKey × ExternalDecl)) : Program :=
  {StandardOrdinaryCoreProgram.program with
    defs := fun n => (Body.all.find? (fun body => body.key = n)).map Body.definition
    cons := fun n => constructors.lookup n
    externals := externals}

set_option maxHeartbeats 800000 in
/-- 各元定義から合成表へのlookup。外部宣言は任意である。 -/
theorem body_lookup (externals : List (ExternalKey × ExternalDecl)) (body : Body) :
    (program externals).defs body.key = some body.definition := by
  cases body <;> rfl

/-- 合成表の成功した全lookupは、保持した元定義のいずれかに対応する。 -/
theorem lookup_body {externals f d} (lookup : (program externals).defs f = some d) :
    ∃ body ∈ Body.all, f = body.key ∧ d = body.definition := by
  change (Body.all.find? (fun body => body.key = f)).map Body.definition = some d at lookup
  obtain ⟨body,found,eq⟩ := Option.map_eq_some_iff.mp lookup
  have name : body.key = f := of_decide_eq_true (List.find?_some (p := fun b : Body => decide (b.key = f)) found)
  exact ⟨body, List.mem_of_find?_eq_some found,name.symm,eq.symm⟩

/-- 有限台帳と合成表は、任意の名前とDefについて両方向に対応する。 -/
theorem definitions_iff (externals : List (ExternalKey × ExternalDecl)) (f : String) (d : Def) :
    (program externals).defs f = some d ↔ ∃ body ∈ Body.all, f = body.key ∧ d = body.definition := by
  constructor
  · exact lookup_body
  · rintro ⟨body,_,rfl,rfl⟩
    exact body_lookup externals body

example (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs Body.b001.key = some Body.b001.definition :=
  (definitions_iff externals _ _).mpr ⟨Body.b001,List.mem_cons_self,rfl,rfl⟩
/-- 同じ有限宣言表のOption構成子は通常側・精密側で共有する。 -/
theorem option_declarations (externals : List (ExternalKey × ExternalDecl)) :
    StandardActualListBodies.ListOptionDeclarations (program externals) := by
  have only : ∀ c cd, (program externals).cons c = some cd → cd.data = "Option" →
      c = "Option.None" ∨ c = "Option.Some" := by
    intro c cd lookup owner
    have mem : (c,cd) ∈ constructors := by
      change constructors.lookup c = some cd at lookup
      obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
      rw [eq]
      exact List.mem_append_right _ List.mem_cons_self
    simp [constructors,declarations,roundingMode,StandardOrdinaryCoreBodies.declarations,
      ScopeDeclarations.http,ScopeDeclarations.file,ScopeDeclarations.result,ScopeDeclarations.scopeError,
      ScopeDeclarations.pair,ScopeDeclarations.clientRequest,ScopeDeclarations.requestCheckError,
      StandardKeyTyping.DataDecl.entries,StandardOrdinaryCoreBodies.Record.owner,StandardSafe.names] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | rest
    · exact Or.inl rfl
    · exact Or.inr rfl
    · repeat' first | (rcases rest with ⟨rfl,rfl⟩ | rest) | (rcases rest with ⟨rfl,rfl⟩)
      all_goals simp_all
  refine ⟨rfl,rfl,?_,only⟩
  refine ⟨⟨"Option.None",_,rfl,rfl⟩,?_⟩
  intro c cd lookup owner
  rcases only c cd lookup owner with rfl | rfl
  all_goals cases Option.some.inj lookup; rfl

example : StandardActualListBodies.ListOptionDeclarations (program []) :=
  option_declarations []

end
end Benitoite.Release.Refinement.StandardModel
