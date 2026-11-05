import Benitoite.Release.Refinement.StandardModelCollectionBodies
import Benitoite.Release.Refinement.StandardModelSafeBodies

/-! # 合成表の上の全本体の型付け

合成プログラムの全130本体は、任意の外部宣言について、同じ合成表で型付く。各本体の証明は、元の
証明の構成を合成表の宣言・組込み・関数参照の上で閉じ直したもの（StandardModelListBodies・
StandardModelCoreBodies・StandardModelSafeBodies・StandardModelCollectionBodies）である。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

private theorem of_row {P B} {row : StandardContracts.Row} {d : Def} (h : row.definition = some d)
    (typed : row.BodyTyped P B) : d.WellTyped P B := by
  obtain ⟨d', hd, t⟩ := typed
  cases Option.some.inj (hd.symm.trans h)
  exact t

/-- 合成表のPairの二射影の本体は、元のPairの射影の定義である。 -/
theorem pair_body (externals : List (ExternalKey × ExternalDecl)) (second : Bool) :
    (if second then Body.b107 else Body.b106).definition = StandardOrdinaryCoreProgram.pairDefinition second := by
  have h1 := body_lookup externals (if second then Body.b107 else Body.b106)
  have h2 := pair_lookup externals second
  cases second <;> exact Option.some.inj (h1.symm.trans h2)

/-- 合成プログラムの全130本体は、任意の外部宣言の合成表で型付く。 -/
theorem body_typed (externals : List (ExternalKey × ExternalDecl)) (body : Body) :
    body.definition.WellTyped (program externals) (builtins (program externals)) := by
  cases body
  case b001 => exact (list_bodies_typed externals false).2.1
  case b002 => exact (list_bodies_typed externals true).2.1
  case b003 => exact (list_helpers_typed externals .fold).2
  case b004 => exact (list_helpers_typed externals .forEach).2
  case b005 => exact (list_helpers_typed externals .any).2
  case b006 => exact (list_helpers_typed externals .all).2
  case b007 => exact (list_helpers_typed externals .find).2
  case b008 => exact ordinary_collection_typed externals true false
  case b009 => exact ordinary_collection_typed externals true true
  case b010 => exact core_bodies_typed externals .mapFold
  case b011 => exact core_bodies_typed externals .mapForEach
  case b012 => exact ordinary_collection_typed externals false false
  case b013 => exact ordinary_collection_typed externals false true
  case b014 => exact core_bodies_typed externals .setFold
  case b015 => exact core_bodies_typed externals .setForEach
  case b016 => exact core_bodies_typed externals .checkInteger
  case b017 => exact (getters_typed externals .minimum).2
  case b018 => exact (getters_typed externals .maximum).2
  case b019 => exact (getters_typed externals .integerValue).2
  case b020 => exact core_bodies_typed externals .checkLength
  case b021 => exact (getters_typed externals .lengthMinimum).2
  case b022 => exact (getters_typed externals .lengthMaximum).2
  case b023 => exact (getters_typed externals .length).2
  case b024 => exact (getters_typed externals .lengthValues).2
  case b025 => exact core_bodies_typed externals .checkIndex
  case b026 => exact (getters_typed externals .index).2
  case b027 => exact (getters_typed externals .indexValues).2
  case b028 => exact (getters_typed externals .element).2
  case b029 => exact core_bodies_typed externals .nonemptyFromList
  case b030 => exact core_bodies_typed externals .nonemptyToList
  case b031 => exact (getters_typed externals .first).2
  case b032 => exact (getters_typed externals .rest).2
  case b033 => exact core_bodies_typed externals .nonemptyMap
  case b034 => exact of_row rfl (aliases_typed externals .Integer64_toString)
  case b035 => exact of_row rfl (aliases_typed externals .Integer64_parse)
  case b036 => exact of_row rfl (aliases_typed externals .Integer64_toFloat)
  case b037 => exact of_row rfl (aliases_typed externals .Integer64_floorDivide)
  case b038 => exact of_row rfl (aliases_typed externals .Integer64_floorModulo)
  case b039 => exact of_row rfl (aliases_typed externals .Integer64_absolute)
  case b040 => exact of_row rfl (aliases_typed externals .Integer64_minimum)
  case b041 => exact of_row rfl (aliases_typed externals .Integer64_maximum)
  case b042 => exact of_row rfl (aliases_typed externals .Integer64_bitwiseAnd)
  case b043 => exact of_row rfl (aliases_typed externals .Integer64_bitwiseOr)
  case b044 => exact of_row rfl (aliases_typed externals .Integer64_bitwiseExclusiveOr)
  case b045 => exact of_row rfl (aliases_typed externals .Integer64_bitwiseNot)
  case b046 => exact of_row rfl (aliases_typed externals .Integer64_shiftLeft)
  case b047 => exact of_row rfl (aliases_typed externals .Integer64_shiftRight)
  case b048 => exact of_row rfl (aliases_typed externals .Integer64_shiftRightUnsigned)
  case b049 => exact of_row rfl (aliases_typed externals .UnsignedInteger_fromInteger)
  case b050 => exact of_row rfl (aliases_typed externals .UnsignedInteger_toInteger)
  case b051 => exact of_row rfl (aliases_typed externals .UnsignedInteger_parse)
  case b052 => exact of_row rfl (aliases_typed externals .UnsignedInteger_toString)
  case b053 => exact of_row rfl (aliases_typed externals .UnsignedInteger_toFloat)
  case b054 => exact of_row rfl (aliases_typed externals .UnsignedInteger_toDecimal)
  case b055 => exact of_row rfl (aliases_typed externals .UnsignedInteger_fromDecimal)
  case b056 => exact of_row rfl (aliases_typed externals .UnsignedInteger_absolute)
  case b057 => exact of_row rfl (aliases_typed externals .UnsignedInteger_minimum)
  case b058 => exact of_row rfl (aliases_typed externals .UnsignedInteger_maximum)
  case b059 => exact of_row rfl (aliases_typed externals .UnsignedInteger_floorDivide)
  case b060 => exact of_row rfl (aliases_typed externals .UnsignedInteger_floorModulo)
  case b061 => exact of_row rfl (aliases_typed externals .UnsignedInteger_bitwiseAnd)
  case b062 => exact of_row rfl (aliases_typed externals .UnsignedInteger_bitwiseOr)
  case b063 => exact of_row rfl (aliases_typed externals .UnsignedInteger_bitwiseExclusiveOr)
  case b064 => exact of_row rfl (aliases_typed externals .UnsignedInteger_bitwiseNot)
  case b065 => exact of_row rfl (aliases_typed externals .UnsignedInteger_shiftLeft)
  case b066 => exact of_row rfl (aliases_typed externals .UnsignedInteger_shiftRight)
  case b067 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_fromInteger)
  case b068 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_toInteger)
  case b069 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_toString)
  case b070 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_bitwiseAnd)
  case b071 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_bitwiseOr)
  case b072 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_bitwiseExclusiveOr)
  case b073 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_bitwiseNot)
  case b074 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_shiftLeft)
  case b075 => exact of_row rfl (aliases_typed externals .UnsignedInteger8_shiftRight)
  case b076 => exact of_row rfl (aliases_typed externals .Float64_toString)
  case b077 => exact of_row rfl (aliases_typed externals .Float64_parse)
  case b078 => exact of_row rfl (aliases_typed externals .Float64_truncate)
  case b079 => exact of_row rfl (aliases_typed externals .Float64_isNaN)
  case b080 => exact of_row rfl (aliases_typed externals .Float64_absolute)
  case b081 => exact of_row rfl (aliases_typed externals .Float64_floor)
  case b082 => exact of_row rfl (aliases_typed externals .Float64_ceiling)
  case b083 => exact of_row rfl (aliases_typed externals .Float64_round)
  case b084 => exact of_row rfl (aliases_typed externals .Float64_squareRoot)
  case b085 => exact of_row rfl (StandardSafe.head_row_typed _ _)
  case b086 => exact of_row rfl StandardSafe.Composed.get_row_typed
  case b087 => exact of_row rfl StandardSafe.Composed.checked_row_typed
  case b088 => exact of_row rfl StandardSafe.Composed.same_row_typed
  case b089 => exact of_row rfl StandardSafe.Composed.fromList_row_typed
  case b090 => exact of_row rfl (StandardSafe.toList_row_typed _ _)
  case b091 => exact of_row rfl (StandardSafe.head_row_typed _ _)
  case b092 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .minimum)
  case b093 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .maximum)
  case b094 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .value)
  case b095 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .lengthMinimum)
  case b096 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .lengthMaximum)
  case b097 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .checkedLength)
  case b098 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .lengthValues)
  case b099 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .indexValue)
  case b100 => exact of_row rfl (StandardSafe.Composed.precise_row_typed .indexValues)
  case b101 => exact (list_bodies_typed externals false).2.2.1
  case b102 => exact (list_bodies_typed externals true).2.2.1
  case b103 => exact (list_bodies_typed externals false).2.2.2
  case b104 => exact (list_bodies_typed externals true).2.2.2
  case b105 => exact nonempty_map_typed externals
  case b106 => exact (pair_body externals false).symm ▸ pairs_typed externals false
  case b107 => exact (pair_body externals true).symm ▸ pairs_typed externals true
  case b108 => exact refined_collection_typed externals true false
  case b109 => exact refined_collection_typed externals true true
  case b110 => exact refined_collection_typed externals false false
  case b111 => exact refined_collection_typed externals false true
  case b112 => exact (list_helpers_typed externals .fold).1
  case b113 => exact (list_helpers_typed externals .forEach).1
  case b114 => exact (list_helpers_typed externals .any).1
  case b115 => exact (list_helpers_typed externals .all).1
  case b116 => exact (list_helpers_typed externals .find).1
  case b117 => exact (getters_typed externals .minimum).1
  case b118 => exact (getters_typed externals .maximum).1
  case b119 => exact (getters_typed externals .integerValue).1
  case b120 => exact (getters_typed externals .lengthMinimum).1
  case b121 => exact (getters_typed externals .lengthMaximum).1
  case b122 => exact (getters_typed externals .length).1
  case b123 => exact (getters_typed externals .lengthValues).1
  case b124 => exact (getters_typed externals .indexValues).1
  case b125 => exact (getters_typed externals .index).1
  case b126 => exact (getters_typed externals .element).1
  case b127 => exact (getters_typed externals .first).1
  case b128 => exact (getters_typed externals .rest).1
  case b129 => exact (list_bodies_typed externals false).1
  case b130 => exact (list_bodies_typed externals true).1

/-- 合成表の成功した全lookupの定義は、同じ合成表で型付く。 -/
theorem definition_typed (externals : List (ExternalKey × ExternalDecl))
    (f : Benitoite.Release.FunName) (d : Def) (lookup : (program externals).defs f = some d) :
    Def.WellTyped (program externals) (builtins (program externals)) d := by
  obtain ⟨body, _, _, rfl⟩ := lookup_body lookup
  exact body_typed externals body

/-- 外部宣言の表が構造検証を満たせば、合成プログラムは同じ合成表で型付く。 -/
theorem program_typed (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) :
    (program externals).WellTyped (builtins (program externals)) where
  variance := variance_valid externals
  external := hw
  defs := definition_typed externals
  impls := fun _ _ lookup => by cases lookup

/-- 空の外部宣言表の合成プログラムは、構造検証を満たし、同じ合成表で型付く。 -/
example : (program []).WellTyped (builtins (program [])) :=
  program_typed [] ⟨List.nodup_nil, by intro key decl member; cases member⟩

end
end Benitoite.Release.Refinement.StandardModel
