import Benitoite.Release.Refinement.StandardModelCore

/-! # 合成プログラムの格納された宣言の適格性

合成プログラムの全130本体は、元の本体の族ごとに、関数参照の名前の写像に依らず、依存列と本体の
深さの条件を満たす。型の注釈と種類は本体の型付けから読む。構成子の欄・操作・クラス・実装・変性の
情報は、合成プログラムの有限の宣言から検査する。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
set_option linter.unusedSimpArgs false

/-- 依存列の行・範囲の上限と、本体の深さの条件。型の注釈と種類は型付けから読む。 -/
def BodyScoped (d : Def) : Prop :=
  (Ty.dependentFn d.tel).RowsIn (· < d.neffs) ∧ (Ty.dependentFn d.tel).RangesScoped 0 ∧
    d.tel.RowsIn (· < d.neffs) ∧ d.body.SourceScoped 0 d.ntys d.neffs d.params.length

theorem Def.scoped_of_typed {P B} {d : Def} (typed : d.WellTyped P B) (formed : BodyScoped d) :
    d.Scoped P := by
  obtain ⟨names, kinds, annotation, _⟩ := typed
  obtain ⟨rows, ranges, telRows, body⟩ := formed
  exact ⟨names, ⟨⟨annotation.wf, rows, ranges⟩, telRows, kinds, annotation⟩, body⟩


open Lean Elab Tactic Meta in
/-- 目標に現れる非公開の定義を展開する。本体の補助の定義は各モジュールの非公開の名前である。 -/
local elab "unfold_private" : tactic => do
  let goal ← getMainGoal
  let target ← goal.getType
  let expanded ← deltaExpand target isPrivateName
  replaceMainGoal [← goal.replaceTargetDefEq expanded]

local macro "scoped_simp" : tactic => `(tactic| (
  try simp_all [BodyScoped, FunctionNames.definition, FunctionNames.computation, FunctionNames.value,
    FunctionNames.values, FunctionNames.arms, FunctionNames.clauses, FunctionNames.slots,
    Comp.SourceScoped, Val.SourceScoped, scopedValues, scopedArms, scopedClauses, scopedTypes, scopedRows,
    Ty.SourceScoped, Eff.SourceScoped, BuilderKind.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
    Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes,
    Eff.RangesScoped, Eff.WF, Eff.row, Eff.empty, Eff.single, Def.tel, Def.ntys, signatureTel, Tel.names,
    Tel.inputs, Tel.result, Tel.effect, NamesWF, Arm.bindersOf, StandardContracts.Row.definition,
    TypeCtx.valueParam, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core, Benitoite.Release.Arm.bindersOf, Benitoite.Release.Pat.binders,
    List.range, List.range.loop, Eff.Canonical, Benitoite.Release.Pat.bindersList, StandardOrdinaryListBodies.Op.args, Tel.arity,
    InternalContracts.nonempty, nonemptyType, InternalContracts.safeHead, InternalContracts.safeGet,
    InternalContracts.safeTail, InternalContracts.checkedGet, InternalContracts.sameLengthGet,
    InternalContracts.checkedIntegerProjection, InternalContracts.checkedLengthProjection,
    InternalContracts.checkedLength, InternalContracts.checkedLengthValues, InternalContracts.checkedIndexProjection,
    InternalContracts.checkedIntegerType, InternalContracts.checkedLengthType, InternalContracts.checkedIndexType,
    InternalContracts.nonnegativeIndex, InternalContracts.length, InternalContracts.getField,
    InternalContracts.integerField, InternalContracts.lengthField, InternalContracts.lengthValues,
    InternalContracts.indexValue, InternalContracts.indexValues, StandardOrdinaryCoreBodies.Record.type,
    StandardOrdinaryCoreBodies.Record.arity, StandardOrdinaryCoreBodies.Record.owner,
    InternalContracts.nonemptyFromList, InternalContracts.nonemptyToList, InternalContracts.checkedIndexValues,
    nonemptyPredicate, StandardSafe.a, StandardSafe.C, StandardSafe.D2, Ty.shiftV, Benitoite.Release.ListRest.binders,
    StandardSafe.headBody, StandardSafe.headAlts, StandardSafe.safeGetBody, StandardSafe.sameLengthBody,
    StandardSafe.checkedGetBody, StandardSafe.fromListBody, StandardSafe.toListBody, headRestPattern, StandardBodies.mapCallbackBody]
  try unfold_private
  try simp_all [BodyScoped, FunctionNames.definition, FunctionNames.computation, FunctionNames.value,
    FunctionNames.values, FunctionNames.arms, FunctionNames.clauses, FunctionNames.slots,
    Comp.SourceScoped, Val.SourceScoped, scopedValues, scopedArms, scopedClauses, scopedTypes, scopedRows,
    Ty.SourceScoped, Eff.SourceScoped, BuilderKind.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
    Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes,
    Eff.RangesScoped, Eff.WF, Eff.row, Eff.empty, Eff.single, Def.tel, Def.ntys, signatureTel, Tel.names,
    Tel.inputs, Tel.result, Tel.effect, NamesWF, Arm.bindersOf, StandardContracts.Row.definition,
    TypeCtx.valueParam, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core, Benitoite.Release.Arm.bindersOf, Benitoite.Release.Pat.binders,
    List.range, List.range.loop, Eff.Canonical, Benitoite.Release.Pat.bindersList, StandardOrdinaryListBodies.Op.args, Tel.arity,
    InternalContracts.nonempty, nonemptyType, InternalContracts.safeHead, InternalContracts.safeGet,
    InternalContracts.safeTail, InternalContracts.checkedGet, InternalContracts.sameLengthGet,
    InternalContracts.checkedIntegerProjection, InternalContracts.checkedLengthProjection,
    InternalContracts.checkedLength, InternalContracts.checkedLengthValues, InternalContracts.checkedIndexProjection,
    InternalContracts.checkedIntegerType, InternalContracts.checkedLengthType, InternalContracts.checkedIndexType,
    InternalContracts.nonnegativeIndex, InternalContracts.length, InternalContracts.getField,
    InternalContracts.integerField, InternalContracts.lengthField, InternalContracts.lengthValues,
    InternalContracts.indexValue, InternalContracts.indexValues, StandardOrdinaryCoreBodies.Record.type,
    StandardOrdinaryCoreBodies.Record.arity, StandardOrdinaryCoreBodies.Record.owner,
    InternalContracts.nonemptyFromList, InternalContracts.nonemptyToList, InternalContracts.checkedIndexValues,
    nonemptyPredicate, StandardSafe.a, StandardSafe.C, StandardSafe.D2, Ty.shiftV, Benitoite.Release.ListRest.binders,
    StandardSafe.headBody, StandardSafe.headAlts, StandardSafe.safeGetBody, StandardSafe.sameLengthBody,
    StandardSafe.checkedGetBody, StandardSafe.fromListBody, StandardSafe.toListBody, headRestPattern, StandardBodies.mapCallbackBody]
  try unfold_private
  try simp_all [BodyScoped, FunctionNames.definition, FunctionNames.computation, FunctionNames.value,
    FunctionNames.values, FunctionNames.arms, FunctionNames.clauses, FunctionNames.slots,
    Comp.SourceScoped, Val.SourceScoped, scopedValues, scopedArms, scopedClauses, scopedTypes, scopedRows,
    Ty.SourceScoped, Eff.SourceScoped, BuilderKind.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
    Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes,
    Eff.RangesScoped, Eff.WF, Eff.row, Eff.empty, Eff.single, Def.tel, Def.ntys, signatureTel, Tel.names,
    Tel.inputs, Tel.result, Tel.effect, NamesWF, Arm.bindersOf, StandardContracts.Row.definition,
    TypeCtx.valueParam, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core, Benitoite.Release.Arm.bindersOf, Benitoite.Release.Pat.binders,
    List.range, List.range.loop, Eff.Canonical, Benitoite.Release.Pat.bindersList, StandardOrdinaryListBodies.Op.args, Tel.arity,
    InternalContracts.nonempty, nonemptyType, InternalContracts.safeHead, InternalContracts.safeGet,
    InternalContracts.safeTail, InternalContracts.checkedGet, InternalContracts.sameLengthGet,
    InternalContracts.checkedIntegerProjection, InternalContracts.checkedLengthProjection,
    InternalContracts.checkedLength, InternalContracts.checkedLengthValues, InternalContracts.checkedIndexProjection,
    InternalContracts.checkedIntegerType, InternalContracts.checkedLengthType, InternalContracts.checkedIndexType,
    InternalContracts.nonnegativeIndex, InternalContracts.length, InternalContracts.getField,
    InternalContracts.integerField, InternalContracts.lengthField, InternalContracts.lengthValues,
    InternalContracts.indexValue, InternalContracts.indexValues, StandardOrdinaryCoreBodies.Record.type,
    StandardOrdinaryCoreBodies.Record.arity, StandardOrdinaryCoreBodies.Record.owner,
    InternalContracts.nonemptyFromList, InternalContracts.nonemptyToList, InternalContracts.checkedIndexValues,
    nonemptyPredicate, StandardSafe.a, StandardSafe.C, StandardSafe.D2, Ty.shiftV, Benitoite.Release.ListRest.binders,
    StandardSafe.headBody, StandardSafe.headAlts, StandardSafe.safeGetBody, StandardSafe.sameLengthBody,
    StandardSafe.checkedGetBody, StandardSafe.fromListBody, StandardSafe.toListBody, headRestPattern, StandardBodies.mapCallbackBody]))

theorem alias_scoped (ρ : String → String) (api : StandardAliasBodies.API) :
    BodyScoped (FunctionNames.definition ρ api.definition) := by
  cases api <;> (try simp only [StandardAliasBodies.API.definition, StandardAliasBodies.API.body, StandardAliasBodies.API.names, StandardAliasBodies.API.inputs, StandardAliasBodies.API.result]) <;> scoped_simp

theorem listHelper_scoped (ρ : String → String) (o : StandardOrdinaryListBodies.Op) :
    BodyScoped (FunctionNames.definition ρ o.definition) := by
  cases o <;> (try simp only [StandardOrdinaryListBodies.Op.definition, StandardOrdinaryListBodies.Op.body, StandardOrdinaryListBodies.Op.arms, StandardOrdinaryListBodies.Op.next, StandardOrdinaryListBodies.Op.afterCall, StandardOrdinaryListBodies.Op.noneBody, StandardOrdinaryListBodies.Op.context, StandardOrdinaryListBodies.Op.count, StandardOrdinaryListBodies.Op.names, StandardOrdinaryListBodies.Op.inputs, StandardOrdinaryListBodies.Op.result, StandardOrdinaryListBodies.Op.callback, StandardOrdinaryListBodies.Op.args, StandardOrdinaryListBodies.Op.label, StandardOrdinaryListBodies.Op.helperName, StandardOrdinaryListBodies.Op.name]) <;> scoped_simp

theorem listPublic_scoped (ρ : String → String) (o : StandardOrdinaryListBodies.Op) :
    BodyScoped (FunctionNames.definition ρ o.publicDefinition) := by
  cases o <;> (try simp only [StandardOrdinaryListBodies.Op.publicDefinition, StandardOrdinaryListBodies.Op.publicBody, StandardOrdinaryListBodies.Op.context, StandardOrdinaryListBodies.Op.count, StandardOrdinaryListBodies.Op.publicNames, StandardOrdinaryListBodies.Op.publicInputs, StandardOrdinaryListBodies.Op.result, StandardOrdinaryListBodies.Op.callback, StandardOrdinaryListBodies.Op.args, StandardOrdinaryListBodies.Op.label, StandardOrdinaryListBodies.Op.helperName, StandardOrdinaryListBodies.Op.name]) <;> scoped_simp

theorem getter_scoped (ρ : String → String) (g : StandardOrdinaryCoreBodies.Getter) :
    BodyScoped (FunctionNames.definition ρ g.definition) := by
  cases g <;> (try simp only [StandardOrdinaryCoreBodies.Getter.definition, StandardOrdinaryCoreBodies.Getter.body, StandardOrdinaryCoreBodies.Getter.alts, StandardOrdinaryCoreBodies.Getter.pattern, StandardOrdinaryCoreBodies.Getter.record, StandardOrdinaryCoreBodies.Getter.result, StandardOrdinaryCoreBodies.Getter.position, StandardOrdinaryCoreBodies.Record.params, StandardOrdinaryCoreBodies.Record.arity, StandardOrdinaryCoreBodies.Record.type, StandardOrdinaryCoreBodies.Record.fields, StandardOrdinaryCoreBodies.Record.owner, StandardSafe.names]) <;> scoped_simp

theorem projection_scoped (ρ : String → String) (g : StandardOrdinaryCoreBodies.Getter) :
    BodyScoped (FunctionNames.definition ρ g.publicDefinition) := by
  cases g <;> (try simp only [StandardOrdinaryCoreBodies.Getter.publicDefinition, StandardOrdinaryCoreBodies.Getter.definition, StandardOrdinaryCoreBodies.Getter.publicBody, StandardOrdinaryCoreBodies.Getter.record, StandardOrdinaryCoreBodies.Getter.result, StandardOrdinaryCoreBodies.Getter.position, StandardOrdinaryCoreBodies.Getter.name, StandardOrdinaryCoreBodies.Getter.field, StandardOrdinaryCoreBodies.Record.params, StandardOrdinaryCoreBodies.Record.arity, StandardOrdinaryCoreBodies.Record.type, StandardOrdinaryCoreBodies.Record.fields, StandardOrdinaryCoreBodies.Record.owner, StandardSafe.names]) <;> scoped_simp

theorem pair_scoped (ρ : String → String) (second : Bool) :
    BodyScoped (FunctionNames.definition ρ (StandardOrdinaryCoreProgram.pairDefinition second)) := by
  cases second <;> (try simp only [StandardOrdinaryCoreProgram.pairDefinition, StandardOrdinaryCoreProgram.pair]) <;> scoped_simp

theorem core_scoped (ρ : String → String) (a : StandardOrdinaryCoreProgram.API) :
    BodyScoped (FunctionNames.definition ρ a.definition) := by
  cases a <;> (try simp only [StandardOrdinaryCoreProgram.API.definition, StandardOrdinaryCoreProgram.API.body,
    StandardOrdinaryCoreProgram.API.context, StandardOrdinaryCoreProgram.API.neffs, StandardOrdinaryCoreProgram.API.names,
    StandardOrdinaryCoreProgram.API.inputs, StandardOrdinaryCoreProgram.API.result, StandardOrdinaryCoreProgram.API.effect,
    StandardOrdinaryCoreProgram.keyParam, StandardOrdinaryCoreProgram.pair]) <;> scoped_simp

theorem safe_scoped (ρ : String → String) {d : Def} :
    (StandardSafe.headRow.definition = some d ∨ StandardSafe.getRow.definition = some d ∨
      StandardSafe.checkedRow.definition = some d ∨ StandardSafe.sameRow.definition = some d ∨
      StandardSafe.fromListRow.definition = some d ∨ StandardSafe.toListRow.definition = some d ∨
      StandardSafe.nonemptyHeadRow.definition = some d) →
    BodyScoped (FunctionNames.definition ρ d) := by
  rintro (h | h | h | h | h | h | h) <;> simp only [StandardContracts.Row.definition, StandardSafe.headRow,
    StandardSafe.getRow, StandardSafe.checkedRow, StandardSafe.sameRow, StandardSafe.fromListRow,
    StandardSafe.toListRow, StandardSafe.nonemptyHeadRow, Option.some.injEq] at h <;> subst h <;>
    (try simp only [StandardSafe.headBody, StandardSafe.safeGetBody, StandardSafe.checkedGetBody,
      StandardSafe.sameLengthBody, StandardSafe.fromListBody, StandardSafe.toListBody, StandardSafe.headAlts,
      StandardSafe.safeHead, StandardSafe.safeGet, StandardSafe.checkedGet, StandardSafe.sameLengthGet,
      StandardSafe.nonemptyFromList, StandardSafe.nonemptyToList, StandardSafe.a, StandardSafe.names,
      InternalContracts.safeHead, InternalContracts.safeGet, InternalContracts.checkedGet,
      InternalContracts.sameLengthGet, InternalContracts.nonemptyFromList, InternalContracts.nonemptyToList]) <;>
    scoped_simp

theorem precise_scoped (ρ : String → String) (g : StandardSafe.PreciseGetter) {d : Def}
    (h : g.row.definition = some d) : BodyScoped (FunctionNames.definition ρ d) := by
  cases g <;> simp only [StandardContracts.Row.definition, StandardSafe.PreciseGetter.row, Option.some.injEq] at h <;>
    subst h <;> (try simp only [StandardSafe.PreciseGetter.body, StandardSafe.PreciseGetter.alts,
      StandardSafe.PreciseGetter.pattern, StandardSafe.PreciseGetter.fields, StandardSafe.PreciseGetter.position,
      StandardSafe.PreciseGetter.tel, StandardSafe.PreciseGetter.context, StandardSafe.PreciseGetter.owner]) <;>
    scoped_simp

theorem listHigher_scoped (ρ : String → String) (filter : Bool) {d : Def}
    (h : (StandardBodies.listHigherRow filter).definition = some d) : BodyScoped (FunctionNames.definition ρ d) := by
  cases filter <;> simp only [StandardContracts.Row.definition, StandardBodies.listHigherRow, Option.some.injEq] at h <;>
    subst h <;> scoped_simp

theorem listFrom_scoped (ρ : String → String) (filter : Bool) :
    BodyScoped (FunctionNames.definition ρ (StandardBodies.listFromDefinition filter)) := by
  cases filter <;> (try simp only [StandardBodies.listFromDefinition, StandardBodies.listFromBody]) <;> scoped_simp

theorem headTailFrom_scoped (ρ : String → String) (filter : Bool) :
    BodyScoped (FunctionNames.definition ρ (StandardHeadTail.fromDefinition filter)) := by
  cases filter <;> (try simp only [StandardHeadTail.fromDefinition, StandardHeadTail.fromBody,
    StandardHeadTail.fromTel, StandardHeadTail.fromName, StandardHeadTail.invariant]) <;> scoped_simp

theorem headTailPublic_scoped (ρ : String → String) (filter : Bool) :
    BodyScoped (FunctionNames.definition ρ (StandardHeadTail.publicDefinition filter)) := by
  cases filter <;> (try simp only [StandardHeadTail.publicDefinition, StandardHeadTail.publicBody,
    StandardHeadTail.publicTel, StandardHeadTail.fromName]) <;> scoped_simp

theorem nonempty_scoped (ρ : String → String) :
    BodyScoped (FunctionNames.definition ρ StandardHeadTail.nonemptyPublicDefinition) := by
  (try simp only [StandardHeadTail.nonemptyPublicDefinition, StandardHeadTail.nonemptyBody,
    StandardHeadTail.nonemptyPublicTel]) ; scoped_simp

theorem collectionHigher_scoped (ρ : String → String) (map filter : Bool) {d : Def}
    (h : (StandardBodies.collectionHigherRow map filter).definition = some d) :
    BodyScoped (FunctionNames.definition ρ d) := by
  cases map <;> cases filter <;> simp only [StandardContracts.Row.definition, StandardBodies.collectionHigherRow,
    Option.some.injEq] at h <;> subst h <;> (try simp only [StandardBodies.collectionHigherBody,
      StandardBodies.mapCallbackBody]) <;> scoped_simp

theorem refinedCollection_scoped (ρ : String → String) (api : StandardCollectionRefinedBodies.API) {d : Def}
    (h : api.row.definition = some d) : BodyScoped (FunctionNames.definition ρ d) := by
  cases api <;> simp only [StandardCollectionRefinedBodies.API.row, StandardCollectionRefinedBodies.API.map,
    StandardCollectionRefinedBodies.API.filter] at h <;> revert h <;> unfold_private <;> intro h <;>
    simp only [StandardContracts.Row.definition, Option.some.injEq] at h <;> subst h <;> scoped_simp

/-- 合成プログラムの全130本体は、依存列の行・範囲と本体の深さの条件を満たす。 -/
theorem body_scoped (body : Body) : BodyScoped body.definition := by
  cases body
  case b001 => exact listHigher_scoped _ false rfl
  case b002 => exact listHigher_scoped _ true rfl
  case b003 => exact listPublic_scoped _ .fold
  case b004 => exact listPublic_scoped _ .forEach
  case b005 => exact listPublic_scoped _ .any
  case b006 => exact listPublic_scoped _ .all
  case b007 => exact listPublic_scoped _ .find
  case b008 => exact collectionHigher_scoped _ true false rfl
  case b009 => exact collectionHigher_scoped _ true true rfl
  case b010 => exact core_scoped _ .mapFold
  case b011 => exact core_scoped _ .mapForEach
  case b012 => exact collectionHigher_scoped _ false false rfl
  case b013 => exact collectionHigher_scoped _ false true rfl
  case b014 => exact core_scoped _ .setFold
  case b015 => exact core_scoped _ .setForEach
  case b016 => exact core_scoped _ .checkInteger
  case b017 => exact projection_scoped _ .minimum
  case b018 => exact projection_scoped _ .maximum
  case b019 => exact projection_scoped _ .integerValue
  case b020 => exact core_scoped _ .checkLength
  case b021 => exact projection_scoped _ .lengthMinimum
  case b022 => exact projection_scoped _ .lengthMaximum
  case b023 => exact projection_scoped _ .length
  case b024 => exact projection_scoped _ .lengthValues
  case b025 => exact core_scoped _ .checkIndex
  case b026 => exact projection_scoped _ .index
  case b027 => exact projection_scoped _ .indexValues
  case b028 => exact projection_scoped _ .element
  case b029 => exact core_scoped _ .nonemptyFromList
  case b030 => exact core_scoped _ .nonemptyToList
  case b031 => exact projection_scoped _ .first
  case b032 => exact projection_scoped _ .rest
  case b033 => exact core_scoped _ .nonemptyMap
  case b034 => exact alias_scoped _ .Integer64_toString
  case b035 => exact alias_scoped _ .Integer64_parse
  case b036 => exact alias_scoped _ .Integer64_toFloat
  case b037 => exact alias_scoped _ .Integer64_floorDivide
  case b038 => exact alias_scoped _ .Integer64_floorModulo
  case b039 => exact alias_scoped _ .Integer64_absolute
  case b040 => exact alias_scoped _ .Integer64_minimum
  case b041 => exact alias_scoped _ .Integer64_maximum
  case b042 => exact alias_scoped _ .Integer64_bitwiseAnd
  case b043 => exact alias_scoped _ .Integer64_bitwiseOr
  case b044 => exact alias_scoped _ .Integer64_bitwiseExclusiveOr
  case b045 => exact alias_scoped _ .Integer64_bitwiseNot
  case b046 => exact alias_scoped _ .Integer64_shiftLeft
  case b047 => exact alias_scoped _ .Integer64_shiftRight
  case b048 => exact alias_scoped _ .Integer64_shiftRightUnsigned
  case b049 => exact alias_scoped _ .UnsignedInteger_fromInteger
  case b050 => exact alias_scoped _ .UnsignedInteger_toInteger
  case b051 => exact alias_scoped _ .UnsignedInteger_parse
  case b052 => exact alias_scoped _ .UnsignedInteger_toString
  case b053 => exact alias_scoped _ .UnsignedInteger_toFloat
  case b054 => exact alias_scoped _ .UnsignedInteger_toDecimal
  case b055 => exact alias_scoped _ .UnsignedInteger_fromDecimal
  case b056 => exact alias_scoped _ .UnsignedInteger_absolute
  case b057 => exact alias_scoped _ .UnsignedInteger_minimum
  case b058 => exact alias_scoped _ .UnsignedInteger_maximum
  case b059 => exact alias_scoped _ .UnsignedInteger_floorDivide
  case b060 => exact alias_scoped _ .UnsignedInteger_floorModulo
  case b061 => exact alias_scoped _ .UnsignedInteger_bitwiseAnd
  case b062 => exact alias_scoped _ .UnsignedInteger_bitwiseOr
  case b063 => exact alias_scoped _ .UnsignedInteger_bitwiseExclusiveOr
  case b064 => exact alias_scoped _ .UnsignedInteger_bitwiseNot
  case b065 => exact alias_scoped _ .UnsignedInteger_shiftLeft
  case b066 => exact alias_scoped _ .UnsignedInteger_shiftRight
  case b067 => exact alias_scoped _ .UnsignedInteger8_fromInteger
  case b068 => exact alias_scoped _ .UnsignedInteger8_toInteger
  case b069 => exact alias_scoped _ .UnsignedInteger8_toString
  case b070 => exact alias_scoped _ .UnsignedInteger8_bitwiseAnd
  case b071 => exact alias_scoped _ .UnsignedInteger8_bitwiseOr
  case b072 => exact alias_scoped _ .UnsignedInteger8_bitwiseExclusiveOr
  case b073 => exact alias_scoped _ .UnsignedInteger8_bitwiseNot
  case b074 => exact alias_scoped _ .UnsignedInteger8_shiftLeft
  case b075 => exact alias_scoped _ .UnsignedInteger8_shiftRight
  case b076 => exact alias_scoped _ .Float64_toString
  case b077 => exact alias_scoped _ .Float64_parse
  case b078 => exact alias_scoped _ .Float64_truncate
  case b079 => exact alias_scoped _ .Float64_isNaN
  case b080 => exact alias_scoped _ .Float64_absolute
  case b081 => exact alias_scoped _ .Float64_floor
  case b082 => exact alias_scoped _ .Float64_ceiling
  case b083 => exact alias_scoped _ .Float64_round
  case b084 => exact alias_scoped _ .Float64_squareRoot
  case b085 => exact safe_scoped _ (.inl rfl)
  case b086 => exact safe_scoped _ (.inr (.inl rfl))
  case b087 => exact safe_scoped _ (.inr (.inr (.inl rfl)))
  case b088 => exact safe_scoped _ (.inr (.inr (.inr (.inl rfl))))
  case b089 => exact safe_scoped _ (.inr (.inr (.inr (.inr (.inl rfl)))))
  case b090 => exact safe_scoped _ (.inr (.inr (.inr (.inr (.inr (.inl rfl))))))
  case b091 => exact safe_scoped _ (.inr (.inr (.inr (.inr (.inr (.inr rfl))))))
  case b092 => exact precise_scoped _ .minimum rfl
  case b093 => exact precise_scoped _ .maximum rfl
  case b094 => exact precise_scoped _ .value rfl
  case b095 => exact precise_scoped _ .lengthMinimum rfl
  case b096 => exact precise_scoped _ .lengthMaximum rfl
  case b097 => exact precise_scoped _ .checkedLength rfl
  case b098 => exact precise_scoped _ .lengthValues rfl
  case b099 => exact precise_scoped _ .indexValue rfl
  case b100 => exact precise_scoped _ .indexValues rfl
  case b101 => exact headTailFrom_scoped _ false
  case b102 => exact headTailFrom_scoped _ true
  case b103 => exact headTailPublic_scoped _ false
  case b104 => exact headTailPublic_scoped _ true
  case b105 => exact nonempty_scoped _
  case b106 => exact pair_scoped _ false
  case b107 => exact pair_scoped _ true
  case b108 => exact refinedCollection_scoped _ .mapMap rfl
  case b109 => exact refinedCollection_scoped _ .mapFilter rfl
  case b110 => exact refinedCollection_scoped _ .setMap rfl
  case b111 => exact refinedCollection_scoped _ .setFilter rfl
  case b112 => exact listHelper_scoped _ .fold
  case b113 => exact listHelper_scoped _ .forEach
  case b114 => exact listHelper_scoped _ .any
  case b115 => exact listHelper_scoped _ .all
  case b116 => exact listHelper_scoped _ .find
  case b117 => exact getter_scoped _ .minimum
  case b118 => exact getter_scoped _ .maximum
  case b119 => exact getter_scoped _ .integerValue
  case b120 => exact getter_scoped _ .lengthMinimum
  case b121 => exact getter_scoped _ .lengthMaximum
  case b122 => exact getter_scoped _ .length
  case b123 => exact getter_scoped _ .lengthValues
  case b124 => exact getter_scoped _ .indexValues
  case b125 => exact getter_scoped _ .index
  case b126 => exact getter_scoped _ .element
  case b127 => exact getter_scoped _ .first
  case b128 => exact getter_scoped _ .rest
  case b129 => exact listFrom_scoped _ false
  case b130 => exact listFrom_scoped _ true

/-- 合成プログラムの全構成子の欄は、型の変数だけを読み、効果の行と範囲を含まない。 -/
theorem field_rows (externals : List (ExternalKey × ExternalDecl)) :
    ∀ c cd, (program externals).cons c = some cd → ∀ a ∈ cd.args, a.RowsIn (· < 0) ∧ a.RangesScoped 0 := by
  intro c cd h
  have mem := cons_mem h
  simp only [constructors, declarations, byteOrder, roundingMode, StandardOrdinaryCoreBodies.declarations,
    ScopeDeclarations.http, ScopeDeclarations.file, ScopeDeclarations.result, ScopeDeclarations.scopeError,
    ScopeDeclarations.pair, ScopeDeclarations.clientRequest, ScopeDeclarations.requestCheckError,
    StandardOrdinaryCoreBodies.Record.owner, StandardOrdinaryCoreBodies.Record.fields,
    StandardSafe.names] at mem
  simp (config := {decide := true}) [List.filter, StandardKeyTyping.DataDecl.entries] at mem
  repeat' (rcases mem with ⟨rfl, rfl⟩ | mem)
  all_goals try (obtain ⟨rfl, rfl⟩ := mem)
  all_goals subst_vars
  all_goals
    intro a ha
    try (simp at ha; done)
    try simp only [atErrorFields, List.replicate, List.mem_cons, List.not_mem_nil, or_false] at ha
    repeat' (rcases ha with rfl | ha)
    all_goals try simp [Ty.RowsIn, Ty.RangesScoped, Ty.RowsInList, rangesScopedTypes, atErrorType]

/-- 合成プログラムの全構成子は、データ名の引数の数を一つに定め、欄が適格である。 -/
theorem cons_scoped (externals : List (ExternalKey × ExternalDecl)) :
    ∀ c cd, (program externals).cons c = some cd →
      (program externals).DataArity cd.data cd.ntys ∧ cd.Scoped (program externals) := by
  intro c cd h
  have variance := ((variance_valid externals).2 c cd h).2
  refine ⟨⟨⟨c, cd, h, rfl⟩, ?_⟩, ?_⟩
  · intro c' cd' h' owner
    obtain ⟨d1, hd1, e1⟩ := List.mem_flatMap.mp (cons_mem h)
    obtain ⟨_, _, s1⟩ := List.mem_map.mp e1
    obtain ⟨d2, hd2, e2⟩ := List.mem_flatMap.mp (cons_mem h')
    obtain ⟨_, _, s2⟩ := List.mem_map.mp e2
    cases s1; cases s2
    have all : ∀ x ∈ declarations, ∀ y ∈ declarations, x.name = y.name → x.ntys = y.ntys := by decide
    exact all _ hd2 _ hd1 owner
  · intro a ha
    obtain ⟨ann, kind, _⟩ := variance a ha
    obtain ⟨rows, ranges⟩ := field_rows externals c cd h a ha
    exact ⟨⟨by simpa using ann.wf, rows, ranges⟩, ann, kind⟩

/-- 合成プログラムの格納された全定義は、型付けと本体の形成から適格である。 -/
theorem definition_scoped (externals : List (ExternalKey × ExternalDecl)) :
    ∀ f d, (program externals).defs f = some d → d.Scoped (program externals) := by
  intro f d lookup
  obtain ⟨body, _, _, rfl⟩ := lookup_body lookup
  exact Def.scoped_of_typed (body_typed externals body) (body_scoped body)

/-- 外部宣言の表が構造検証を満たせば、合成プログラムの格納された宣言は適格である。 -/
theorem program_wellFormed (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) : (program externals).WellFormed where
  defs := definition_scoped externals
  cons := cons_scoped externals
  ops := fun _ _ h => by cases h
  classes := fun _ _ h => by cases h
  impls := fun _ _ h => by cases h
  metadata := fun d info h => by rw [dataInfo_none] at h; cases h
  external := hw

/-- 外部宣言を持たない合成プログラムは、適格で、同じ合成表で型付く。外部宣言の構造検証を受け取る形の
`definition_typed` も同じ証明から得る。 -/
example : (program []).WellFormed ∧ (program []).WellTyped (builtins (program [])) ∧
    ((program []).ExternalWF → ∀ f d, (program []).defs f = some d →
      Def.WellTyped (program []) (builtins (program [])) d) :=
  ⟨program_wellFormed [] ⟨List.nodup_nil, by intro key decl member; cases member⟩,
    program_typed [] ⟨List.nodup_nil, by intro key decl member; cases member⟩,
    fun _hw => definition_typed []⟩

end
end Benitoite.Release.Refinement.StandardModel
