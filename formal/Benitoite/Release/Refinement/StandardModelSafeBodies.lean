import Benitoite.Release.Refinement.StandardModelCoreBodies

/-! # 合成表の上の安全な入口と精密なgetterの本体

安全な入口の内部の本体（列の添字の取得・検査済みの添字・同じ長さの列の取得・非空の列の構成）と
九つの精密なgetterを、合成プログラムの同じ構成子と合成表の内部の組込み %List.getFront の上で、
元の証明の構成（StandardSafeAnnotations・StandardSafeBodies）で検査する。 -/
namespace Benitoite.Release.Refinement.StandardSafe.Composed
open InternalContracts
noncomputable section
set_option linter.unusedSimpArgs false

variable {externals : List (ExternalKey × ExternalDecl)}

@[simp] private theorem checkedInteger_arity : (StandardModel.program externals).DataArity names.checkedInteger 0 :=
 StandardModel.data_arity _ _ (c := names.checkedIntegerCtor) rfl rfl (by decide)
@[simp] private theorem checkedLength_arity : (StandardModel.program externals).DataArity names.checkedLength 1 :=
 StandardModel.data_arity _ _ (c := names.checkedLengthCtor) rfl rfl (by decide)
@[simp] private theorem checkedIndex_arity : (StandardModel.program externals).DataArity names.checkedIndex 1 :=
 StandardModel.data_arity _ _ (c := names.checkedIndexCtor) rfl rfl (by decide)
@[simp] private theorem result_arity : (StandardModel.program externals).DataArity names.result 2 :=
 StandardModel.data_arity _ _ (c := "Benitoite.Result.Result.Ok") rfl rfl (by decide)
@[simp] private theorem emptyListError_arity : (StandardModel.program externals).DataArity names.emptyListError 0 :=
 StandardModel.data_arity _ _ (c := "Benitoite.NonEmptyList.EmptyListError.EmptyList") rfl rfl (by decide)

private theorem read_carrier {P B Ψ Q C Γ Φ v a p} (h : HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p))
 (ann : Ty.Annotation P C Γ a) : HasTypeVQ P B Ψ Q C Γ Φ v a :=
 .V_Sub h .forget ann.wf ann.sorted ann.declared

private theorem annotation_01 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (safeHead (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_02 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (safeGet (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_03 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (safeTail (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_04 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedGet names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_05 : Ty.Annotation (StandardModel.program externals) D2 [] (.dependentFn (sameLengthGet names (.tvar 0) (.tvar 1))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_06 : Ty.Annotation (StandardModel.program externals) [] [] (.dependentFn (checkedIntegerProjection names 0)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_07 : Ty.Annotation (StandardModel.program externals) [] [] (.dependentFn (checkedIntegerProjection names 1)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_08 : Ty.Annotation (StandardModel.program externals) [] [] (.dependentFn (checkedIntegerProjection names 2)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_09 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedLengthProjection names (.tvar 0) 0)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_10 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedLengthProjection names (.tvar 0) 1)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_11 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedLength names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_12 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedLengthValues names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_13 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedIndexProjection names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_14 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedIndexValues names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_15 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (nonemptyFromList names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_16 : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (nonemptyToList (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_19 : Ty.Annotation (StandardModel.program externals) D2 [] (.dependentFn (nonemptyMap (.tvar 0) (.tvar 1) (.row 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty,Eff.row,Eff.atoms,Eff.fails,Eff.Canonical,Eff.norm,Eff.atoms]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty,Eff.row,Eff.atoms,Eff.fails,Eff.Canonical,Eff.norm,Eff.atoms]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl


/-- 全19行は、宣言ごとの型パラメータ数を持つ。mapだけが潜在行を1個受ける。 -/
theorem declarations_annotation : ∀ row ∈ declarationRows,
 Ty.Annotation (StandardModel.program externals) row.tparams [] (.dependentFn row.tel) := by
 intro row h
 simp only [declarationRows,InternalContracts.all,List.zipIdx,List.map_cons,List.map_nil,
   List.mem_cons,List.not_mem_nil,or_false] at h
 rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
 all_goals first
  | exact annotation_01
  | exact annotation_02
  | exact annotation_03
  | exact annotation_04
  | exact annotation_05
  | exact annotation_06
  | exact annotation_07
  | exact annotation_08
  | exact annotation_09
  | exact annotation_10
  | exact annotation_11
  | exact annotation_12
  | exact annotation_13
  | exact annotation_14
  | exact annotation_15
  | exact annotation_16
  | exact annotation_19

private theorem empty_map_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

private theorem cx_arity : TyCon.arity (StandardModel.program externals) (.data names.checkedIndex) = some 1 :=
 TyCon.arity_data checkedIndex_arity
private theorem result_kind_arity : TyCon.arity (StandardModel.program externals) (.data names.result) = some 2 :=
 TyCon.arity_data result_arity
private theorem empty_kind_arity : TyCon.arity (StandardModel.program externals) (.data names.emptyListError) = some 0 :=
 TyCon.arity_data emptyListError_arity

local macro "safe_simp" : tactic => `(tactic|
 simp_all [cx_arity,result_kind_arity,empty_kind_arity,empty_map_range,headRow,toListRow,getRow,checkedRow,sameRow,fromListRow,nonemptyHeadRow,
  safeHead,safeGet,checkedGet,sameLengthGet,nonemptyFromList,nonemptyToList,Tel.arity,C,D2,a,frontSig,PrimSig.tel,Def.tel,signatureTel,TypeCtx.valueParam,TypeCtx.kinds,
  TypeCtx.constraints,TParamDecl.constraints,TypeAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,
  Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,Ty.Declared,Tel.Declared,declaredTys,declaredEff,
  Ty.HasKind,kindsTel,kindsList,kindsEff,NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.row,
  Eff.norm,Ty.NotContCore,Ordinary,Ty.core,Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,
  Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,
  Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,
  SubstEnv.rangesOnly,Eff.rawBind,rowFails,substAtoms_nil,instAtoms_nil,Qsig,QTel,
  QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,RowTransport,NoFail,
  Eff.test,Eff.atoms,Eff.fails,shiftVTys,Eff.shiftV,Ty.shiftV,Tel.shiftV,Ctx.extend,bindParams,
  localExtend,Pred.lift,liftMany,predBind,termBind,termBind?,nonnegativeIndex,nonempty,nonemptyType,
  nonemptyPredicate,Pred.Sorted,Pred.Declared,Pred.WellFormed,Pred.WF,Pred.VarsIn,Term.HasSort,Term.Declared,
  Term.References,Term.VarsIn,Term.Shape,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.Readable,
  Ctx.declarationSelf,length,indexValue,indexValues,getField,checkedIndexType,Tel.argumentsEnv,
  valEnv,Val.toTerm?,upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Tel.names,Tel.inputs,Tel.result,Tel.effect])

private theorem front_function {P Γ Φ Q} (two : Bool) :
 HasTypeVQ P (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty Q (if two then D2 else C) Γ Φ
  (.prim "%List.getFront" [.tvar (if two then 1 else 0)] [] [])
  (.fn ["xs","index"] [.list (.tvar (if two then 1 else 0)),.base .integer]
    (.tvar (if two then 1 else 0)) Eff.empty) := by
 have lookup : (StandardModel.builtins (StandardModel.program externals)).sig "%List.getFront" = some frontSig := by rfl
 have range : (StandardModel.builtins (StandardModel.program externals)).RangeAdmissible "%List.getFront" frontSig [] := by safe_simp
 have names : NamesWF frontSig.names frontSig.params := by safe_simp
 have admissible : PrimitiveAdmissible (if two then D2 else C) Γ.length frontSig Q
  [.tvar (if two then 1 else 0)] [] := by
  cases two <;> constructor
  all_goals first | (constructor <;> safe_simp) | safe_simp
  all_goals rintro (_|i) t p ht hp <;> safe_simp <;> subst_vars
  all_goals exact StandardModel.sat_empty _ _ _
 have inst : SignatureInstance P (if two then D2 else C) Γ (Tel.instR [] frontSig.tel)
  (TypeCtx.kinds frontSig.tparams) [.tvar (if two then 1 else 0)] [] := by
  cases two <;> refine ⟨?_,?_,?_,?_,?_,?_⟩
  all_goals first
   | (solve | safe_simp)
   | (solve | constructor <;> safe_simp)
   | (solve | intro t ht; simp only [List.mem_singleton] at ht; subst t; constructor <;> safe_simp)
   | (solve | refine ⟨rfl,?_⟩; rintro (_|i) t k ht hk <;> safe_simp <;> subst_vars <;> safe_simp)
   | (solve | intro e he; cases he)
 have typed := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Φ := Φ) lookup range names admissible inst
 apply typed.convert
 · cases two <;> safe_simp
   all_goals first
    | simpa [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using (Ty.foldFn_toTel
        ⟨["xs","index"],[.list (.tvar 0),.base .integer],.tvar 0,Eff.empty,by simp [NamesWF]⟩)
    | simpa [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using (Ty.foldFn_toTel
        ⟨["xs","index"],[.list (.tvar 1),.base .integer],.tvar 1,Eff.empty,by simp [NamesWF]⟩)
 · cases two <;> constructor <;> safe_simp

private theorem get_body : TelBodyTy (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty (QTel (safeGet a)) C [] []
 (safeGet a) safeGetBody := by
 apply TelBodyTy.param
 apply TelBodyTy.param
 apply TelBodyTy.done
 apply HasTypeCQ.C_App (front_function false)
 refine .cons (.V_Var rfl (by intro b t e h; cases h)) (.cons ?_ .nil)
 exact read_carrier (.V_Var rfl (by intro b t e h; cases h)) ⟨trivial,trivial,trivial⟩

private theorem get_annotation : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (safeGet a)) :=
 declarations_annotation ⟨"safeGet",C,0,safeGet a,none,.core,[]⟩
 (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])

theorem get_row_typed : getRow.BodyTyped (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) := by
 refine ⟨_,rfl,?_,?_,get_annotation,get_body⟩
 · safe_simp
 · safe_simp

private def cxPattern (index : Bool) : Pat :=
 .con names.checkedIndexCtor (if index then [.wild,.var,.wild] else [.wild,.wild,.var])
private def cxAlts (index : Bool) : List Alt := [⟨cxPattern index,[0]⟩]

private theorem cx_pattern (index : Bool) (p : Pred) :
 PatTy (StandardModel.program externals) (cxPattern index) (.refined (.data names.checkedIndex [a]) p)
  [if index then .base .integer else a] := by
 apply PatTy.P_Refined
 apply PatTy.P_Con (cd := ⟨names.checkedIndex,1,[.list (.tvar 0),.base .integer,.tvar 0]⟩) (ts := [a]) rfl rfl
 · intro a ha
   simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
   rcases ha with rfl | rfl | rfl <;> simp [Ty.WF]
 · cases index <;> safe_simp
   · exact .cons .P_Wild (.cons .P_Wild (.cons .P_Var .nil))
   · exact .cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil))

private theorem cx_only {c cd} (h : (StandardModel.program externals).cons c = some cd) (owner : cd.data = names.checkedIndex) :
 c=names.checkedIndexCtor ∧ cd=⟨names.checkedIndex,1,[.list (.tvar 0),.base .integer,.tvar 0]⟩ := by
 have mem := StandardModel.data_only names.checkedIndex [names.checkedIndexCtor] (by decide) h owner
 rw [List.mem_singleton] at mem
 subst mem
 exact ⟨rfl,Option.some.inj (h.symm.trans rfl)⟩

private theorem cx_exhaustive (index : Bool) (T : Ty) (p : Pred) :
 Exhaustive (StandardModel.program externals) (.refined (.data names.checkedIndex [T]) p) [cxPattern index] := by
 intro v hv
 have hc : Inhabits (StandardModel.program externals) (.data names.checkedIndex [T.norm]) v := by
  simpa [Ty.refined_norm_core,Ty.norm,Ty.normTys,Ty.core] using hv.core
 rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
 · obtain ⟨rfl,rfl⟩ := cx_only lookup owner
   cases fields with
   | cons v0 rest => cases rest with
     | cons v1 rest => cases rest with
       | cons v2 rest =>
         cases rest
         exact ⟨cxPattern index,by simp,by cases index <;> simp [cxPattern,matchVal,matchList]⟩
 · simp [names] at impossible

private theorem cx_alts (index : Bool) (p : Pred) :
 AltsTy (StandardModel.program externals) (cxAlts index) (.refined (.data names.checkedIndex [a]) p)
 [if index then .base .integer else a] := by
 refine ⟨by simp [cxAlts],by cases index <;> rfl,?_,?_⟩
 · intro alt h; cases Option.some.inj h; cases index <;> rfl
 · intro alt h; cases List.mem_singleton.mp h
   exact ⟨_,cx_pattern index p,List.Perm.refl _,rfl⟩

private theorem checked_body : TelBodyTy (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty (QTel (checkedGet names a)) C [] []
 (checkedGet names a) checkedGetBody := by
 apply TelBodyTy.param
 apply TelBodyTy.done
 apply HasTypeCQ.C_Match (obs := none)
 · exact .V_Var rfl (by intro b t e h; cases h)
 · intro t ht; cases ht
 · apply HasTypeArmsQ.plainEmpty (cx_alts false _)
   · simp [pathFacts,FactsWF]
   · exact .C_Return (.V_Var rfl (by intro b t e h; cases h))
   · apply HasTypeArmsQ.nil
     exact ⟨by safe_simp,trivial,trivial⟩
 · simpa [checkedGetBody,cxPattern,cxAlts,unguardedPats,checkedIndexType,Ty.shiftV,a,
     predBind,termBind,termBind?,indexValue,indexValues,getField,length] using cx_exhaustive false a
       (.and (.le (.integer 0) (indexValue names (.var 0)))
         (.lt (indexValue names (.var 0)) (length (indexValues names (.var 0)))))

private theorem same_body : TelBodyTy (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty (QTel (sameLengthGet names a (.tvar 1))) D2 [] []
 (sameLengthGet names a (.tvar 1)) sameLengthBody := by
 apply TelBodyTy.param
 apply TelBodyTy.param
 apply TelBodyTy.done
 apply HasTypeCQ.C_Match (obs := none)
 · exact .V_Var rfl (by intro b t e h; cases h)
 · intro t ht; cases ht
 · apply HasTypeArmsQ.plainEmpty (cx_alts true _)
   · simp [pathFacts,FactsWF]
   · apply HasTypeCQ.C_App (front_function true)
     refine .cons ?_ (.cons (.V_Var rfl (by intro b t e h; cases h)) .nil)
     exact read_carrier (.V_Var rfl (by intro b t e h; cases h)) ⟨by safe_simp,trivial,trivial⟩
   · apply HasTypeArmsQ.nil
     exact ⟨by safe_simp,trivial,trivial⟩
 · simpa [sameLengthBody,cxPattern,cxAlts,unguardedPats,checkedIndexType,Ty.shiftV,a,
     predBind,termBind,termBind?,indexValue,indexValues,getField,length] using cx_exhaustive true a
       (.and (.le (.integer 0) (indexValue names (.var 0)))
         (.lt (indexValue names (.var 0)) (length (indexValues names (.var 0)))))

private theorem checked_annotation : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (checkedGet names a)) :=
 declarations_annotation ⟨"CheckedIndex.get",C,0,checkedGet names a,none,.core,[]⟩
 (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
private theorem same_annotation : Ty.Annotation (StandardModel.program externals) D2 [] (.dependentFn (sameLengthGet names a (.tvar 1))) :=
 declarations_annotation ⟨"sameLengthGet",D2,0,sameLengthGet names a (.tvar 1),none,.core,[]⟩
 (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])

theorem checked_row_typed : checkedRow.BodyTyped (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) := by
 refine ⟨_,rfl,?_,?_,checked_annotation,checked_body⟩ <;> safe_simp

theorem same_row_typed : sameRow.BodyTyped (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) := by
 refine ⟨_,rfl,?_,?_,same_annotation,same_body⟩ <;> safe_simp

private def outputType : Ty := .data names.result [nonempty a,.data names.emptyListError []]
private def emptyErrorType : Ty := .data names.emptyListError []
private theorem output_annotation (Γ : Ctx) : Ty.Annotation (StandardModel.program externals) C Γ outputType := by
 constructor <;> simp [outputType,emptyErrorType,Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,
  Ty.Declared,declaredTys,nonempty,nonemptyType,nonemptyPredicate,Ty.NotContCore,Ty.core,
  Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.HasSort,Term.References,Term.VarsIn,
  Term.Shape,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.HasSort,Ty.sort?,
  Measure.input,Measure.output,Ctx.extend,Ty.shiftV,C,a]
 all_goals exact ⟨.list a,rfl,by intro b t e h; cases h⟩

private theorem result_kinds : TypeArgsKinded (StandardModel.program externals) C
 [nonempty a,emptyErrorType] [.value,.value] := by
 refine ⟨rfl,?_⟩
 rintro (_|(_|i)) t k ht hk <;> simp at ht hk <;> subst_vars <;> safe_simp
 all_goals simp [emptyErrorType,Ty.HasKind,empty_kind_arity,Ty.NotContCore,Ty.core,kindsList]

private theorem error_typed {Γ Φ Q} : HasTypeVQ (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty Q C Γ Φ
 (.con "Benitoite.NonEmptyList.EmptyListError.EmptyList" [] []) emptyErrorType := by
 refine .V_Con (cd := ⟨names.emptyListError,0,[]⟩) rfl rfl
  ⟨rfl,by intro i t k h; cases h⟩ (by intro a h; cases h) .nil ?_
 exact ⟨trivial,trivial,⟨⟨0,emptyListError_arity,rfl⟩,trivial⟩⟩

private theorem error_result {Γ Φ Q} : HasTypeVQ (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty Q C Γ Φ
 (.con "Benitoite.Result.Result.Error" [nonempty a,emptyErrorType]
  [.con "Benitoite.NonEmptyList.EmptyListError.EmptyList" [] []]) outputType := by
 refine .V_Con (cd := ⟨names.result,2,[.tvar 1]⟩) rfl rfl result_kinds
  (by intro a h; cases List.mem_singleton.mp h; simp [Ty.WF]) ?_ (output_annotation Γ)
 have values := HasTypeVsQ.cons (error_typed (externals := externals) (Γ:=Γ) (Φ:=Φ) (Q:=Q)) HasTypeVsQ.nil
 simpa [emptyErrorType,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,
  Ty.norm,Ty.normTys,rawBindTys,typeEnvAt] using values

private theorem ok_result {Γ Φ Q v} (value : HasTypeVQ (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty Q C Γ Φ v (nonempty a)) :
 HasTypeVQ (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty Q C Γ Φ
 (.con "Benitoite.Result.Result.Ok" [nonempty a,emptyErrorType] [v]) outputType := by
 refine .V_Con (cd := ⟨names.result,2,[.tvar 0]⟩) rfl rfl result_kinds
  (by intro a h; cases List.mem_singleton.mp h; simp [Ty.WF]) ?_ (output_annotation Γ)
 have values := HasTypeVsQ.cons value HasTypeVsQ.nil
 simpa [nonempty,nonemptyType,nonemptyPredicate,a,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,
  Ty.norm,Ty.normTys,rawBindTys,typeEnvAt,Ty.shiftV,Ty.refineNorm,Ty.packRefinements,
  Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,predBind,termBind,termBind?,upValues,
  Ty.core,SubstEnv.up,Ty.NotContCore] using values

private theorem empty_alts : AltsTy (StandardModel.program externals) [⟨.list [] none [],[]⟩] (.list a) [] := by
 refine ⟨by simp,rfl,?_,?_⟩
 · intro alt h; cases Option.some.inj h; rfl
 · intro alt h; cases List.mem_singleton.mp h
   refine ⟨[],.P_List .nil .nil (by intro h; cases h; rfl),List.Perm.refl [],?_⟩
   rfl
private theorem list_head_alts : AltsTy (StandardModel.program externals) headAlts (.list a) [a,.list a] := by
 refine ⟨by simp [headAlts],rfl,?_,?_⟩
 · intro alt h; cases Option.some.inj h; rfl
 · intro alt h; cases List.mem_singleton.mp h
   exact ⟨_,.P_List (.cons .P_Var .nil) .nil (by intro h; cases h),List.Perm.refl _,rfl⟩

private theorem list_exhaustive : Exhaustive (StandardModel.program externals) (.list a) [.list [] none [],headRestPattern] := by
 intro v hv
 obtain ⟨xs,rfl,_⟩ := hv.list_inv _ rfl
 cases xs with
 | nil => exact ⟨.list [] none [],by simp,by simp [matchVal,matchList]⟩
 | cons x xs => exact ⟨headRestPattern,by simp,by simp [headRestPattern,matchVal,matchList]⟩

private theorem fromList_body : TelBodyTy (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty (QTel (nonemptyFromList names a)) C [] []
 (nonemptyFromList names a) fromListBody := by
 apply TelBodyTy.param
 apply TelBodyTy.done
 apply HasTypeCQ.C_Match (obs := some (.var 0))
 · exact .V_Var rfl (by intro b t e h; cases h)
 · intro t h; cases Option.some.inj h
   refine ⟨rfl,.list,?_⟩
   safe_simp
 · apply HasTypeArmsQ.plainEmpty empty_alts
   · simp [pathFacts,matchedTests,patternTest?,nonemptyPattern,PathTest.predicate,excludedTests,excludedTest?,headAlts,headRestPattern,FactsWF,Pred.VarsIn]
     all_goals first | (solve | safe_simp) | (solve | constructor <;> constructor <;> safe_simp)
   · exact .C_Return error_result
   · apply HasTypeArmsQ.plainEmpty list_head_alts
     · simp [pathFacts,matchedTests,patternTest?,nonemptyPattern,PathTest.predicate,excludedTests,excludedTest?,headAlts,headRestPattern,FactsWF,Pred.VarsIn]
       all_goals first | (solve | safe_simp) | (solve | constructor <;> safe_simp)
     · apply HasTypeCQ.C_Return
       apply ok_result
       apply HasTypeVQ.V_Refine (a:=.list a) (.V_Var (i:=2) rfl (by intro b t e h; cases h)) (sort:=.list) rfl rfl
       · safe_simp
       · decide
       · apply Entails.hyp
         apply List.mem_append_right
         change (Pred.lt (.integer 0) (.measure .listLength (.var 2))) ∈
          [(Pred.lt (.integer 0) (.measure .listLength (.var 2))),(Pred.lt (.integer 0) (.measure .listLength (.var 2)))]
         simp
       · trivial
       · safe_simp
     · apply HasTypeArmsQ.nil
       exact ⟨(output_annotation (externals := externals) _).wf,(output_annotation (externals := externals) _).sorted,(output_annotation (externals := externals) _).declared⟩
 · simpa [fromListBody,headAlts,unguardedPats,Ty.shiftV,a] using list_exhaustive

private theorem fromList_annotation : Ty.Annotation (StandardModel.program externals) C [] (.dependentFn (nonemptyFromList names a)) :=
 declarations_annotation ⟨"NonEmptyList.fromList",C,0,nonemptyFromList names a,none,.core,[]⟩
 (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])

theorem fromList_row_typed : fromListRow.BodyTyped (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) := by
 refine ⟨_,rfl,?_,?_,fromList_annotation,?_⟩
 · safe_simp
 · safe_simp
 · exact fromList_body

local macro "precise_simp" : tactic => `(tactic|
 (simp_all [PreciseGetter.tel,PreciseGetter.context,PreciseGetter.owner,PreciseGetter.fields,
   PreciseGetter.position,PreciseGetter.input,PreciseGetter.carrier,PreciseGetter.pattern,
   PreciseGetter.alts,PreciseGetter.measure,PreciseGetter.ref,PreciseGetter.links,
   PreciseGetter.row,checkedIntegerProjection,checkedLengthProjection,checkedLength,
   checkedLengthValues,checkedIndexProjection,checkedIndexValues,checkedIntegerType,checkedLengthType,
   integerField,lengthField,lengthValues,viewTerm,fieldFacts,FieldLink.predicate,routeTerm]
  <;> safe_simp))

private theorem precise_annotation (g : PreciseGetter) :
    Ty.Annotation (StandardModel.program externals) g.context [] (.dependentFn g.tel) := by
  cases g
  case minimum =>
    exact declarations_annotation ⟨"Range.minimum",[],0,checkedIntegerProjection names 0,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case maximum =>
    exact declarations_annotation ⟨"Range.maximum",[],0,checkedIntegerProjection names 1,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case value =>
    exact declarations_annotation ⟨"Range.value",[],0,checkedIntegerProjection names 2,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case lengthMinimum =>
    exact declarations_annotation ⟨"Range.lengthMinimum",C,0,checkedLengthProjection names a 0,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case lengthMaximum =>
    exact declarations_annotation ⟨"Range.lengthMaximum",C,0,checkedLengthProjection names a 1,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case checkedLength =>
    exact declarations_annotation ⟨"Range.checkedLength",C,0,checkedLength names a,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case lengthValues =>
    exact declarations_annotation ⟨"Range.lengthValues",C,0,checkedLengthValues names a,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case indexValue =>
    exact declarations_annotation ⟨"Range.indexValue",C,0,checkedIndexProjection names a,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])
  case indexValues =>
    exact declarations_annotation ⟨"Range.indexValues",C,0,checkedIndexValues names a,none,.core,[]⟩
      (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])

private theorem precise_alts (g : PreciseGetter) :
    AltsTy (StandardModel.program externals) g.alts g.input [g.carrier] := by
  cases g <;> refine ⟨by decide,rfl,?_,?_⟩
  all_goals first | (solve | intro alt h; cases Option.some.inj h; rfl) | skip
  case minimum.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .minimum],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedInteger,0,[.base .integer,.base .integer,.base .integer]⟩) (ts := []) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil)))
  case maximum.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .maximum],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedInteger,0,[.base .integer,.base .integer,.base .integer]⟩) (ts := []) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil)))
  case value.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .value],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedInteger,0,[.base .integer,.base .integer,.base .integer]⟩) (ts := []) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Var .nil)))
  case lengthMinimum.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .lengthMinimum],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedLength,1,[.base .integer,.base .integer,.base .integer,.list (.tvar 0)]⟩) (ts := [a]) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild (.cons .P_Wild .nil))))
  case lengthMaximum.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .lengthMaximum],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedLength,1,[.base .integer,.base .integer,.base .integer,.list (.tvar 0)]⟩) (ts := [a]) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Wild (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil))))
  case checkedLength.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .checkedLength],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedLength,1,[.base .integer,.base .integer,.base .integer,.list (.tvar 0)]⟩) (ts := [a]) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil))))
  case lengthValues.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .lengthValues],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedLength,1,[.base .integer,.base .integer,.base .integer,.list (.tvar 0)]⟩) (ts := [a]) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Wild (.cons .P_Var .nil))))
  case indexValue.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .indexValue],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedIndex,1,[.list (.tvar 0),.base .integer,.tvar 0]⟩) (ts := [a]) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil)))
  case indexValues.refine_2 =>
    intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .indexValues],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedIndex,1,[.list (.tvar 0),.base .integer,.tvar 0]⟩) (ts := [a]) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil)))

private theorem precise_links (g : PreciseGetter) : LinksValid g.alts 1 g.links := by
  intro link hl
  cases List.mem_singleton.mp hl
  cases g <;> refine ⟨_,rfl,⟨_,_,rfl⟩,by decide,rfl,?_,by decide⟩
  case refl.minimum => exact BinderPath.con (j := 0) (i := 0) rfl rfl rfl .var
  case refl.maximum => exact BinderPath.con (j := 1) (i := 0) rfl rfl rfl .var
  case refl.value => exact BinderPath.con (j := 2) (i := 0) rfl rfl rfl .var
  case refl.lengthMinimum => exact BinderPath.con (j := 0) (i := 0) rfl rfl rfl .var
  case refl.lengthMaximum => exact BinderPath.con (j := 1) (i := 0) rfl rfl rfl .var
  case refl.checkedLength => exact BinderPath.con (j := 2) (i := 0) rfl rfl rfl .var
  case refl.lengthValues => exact BinderPath.con (j := 3) (i := 0) rfl rfl rfl .var
  case refl.indexValue => exact BinderPath.con (j := 1) (i := 0) rfl rfl rfl .var
  case refl.indexValues => exact BinderPath.con (j := 0) (i := 0) rfl rfl rfl .var

private theorem precise_field_wf (g : PreciseGetter) :
    FactsWF (StandardModel.program externals) g.context (bindParams (Ctx.extend [] g.input) [g.carrier])
      (fieldFacts 1 (some (.var 0)) g.links) := by
  intro p hp
  cases List.mem_singleton.mp hp
  cases g <;> constructor <;> precise_simp
  all_goals
    refine ⟨_,_,_,Term.HasData.var rfl rfl,rfl,rfl,rfl,rfl,?_,rfl⟩
    simp [Ty.WF]


private theorem precise_only (g : PreciseGetter) {c cd}
    (lookup : (StandardModel.program externals).cons c = some cd) (owner : cd.data = g.owner) :
    c = g.owner ∧ cd.args = g.fields := by
  have mem := StandardModel.data_only g.owner [g.owner] (by cases g <;> decide) lookup owner
  rw [List.mem_singleton] at mem
  subst mem
  refine ⟨rfl,?_⟩
  cases g <;> cases Option.some.inj (lookup.symm.trans rfl) <;> rfl

private theorem precise_exhaustive (g : PreciseGetter) :
    Exhaustive (StandardModel.program externals) g.input [g.pattern] := by
  intro v hv
  have hc := hv.core
  cases g
  case minimum =>
    change Inhabits (StandardModel.program externals) (.data names.checkedInteger []) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .minimum lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedInteger,0,PreciseGetter.fields .minimum⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields
         exact ⟨PreciseGetter.pattern .minimum,by simp,by rfl⟩
    · simp [names] at impossible
  case maximum =>
    change Inhabits (StandardModel.program externals) (.data names.checkedInteger []) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .maximum lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedInteger,0,PreciseGetter.fields .maximum⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields
         exact ⟨PreciseGetter.pattern .maximum,by simp,by rfl⟩
    · simp [names] at impossible
  case value =>
    change Inhabits (StandardModel.program externals) (.data names.checkedInteger []) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .value lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedInteger,0,PreciseGetter.fields .value⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields
         exact ⟨PreciseGetter.pattern .value,by simp,by rfl⟩
    · simp [names] at impossible
  case lengthMinimum =>
    change Inhabits (StandardModel.program externals) (.data names.checkedLength [a]) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .lengthMinimum lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedLength,1,PreciseGetter.fields .lengthMinimum⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields with | cons v3 fields =>
          cases fields
          exact ⟨PreciseGetter.pattern .lengthMinimum,by simp,by rfl⟩
    · simp [names] at impossible
  case lengthMaximum =>
    change Inhabits (StandardModel.program externals) (.data names.checkedLength [a]) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .lengthMaximum lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedLength,1,PreciseGetter.fields .lengthMaximum⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields with | cons v3 fields =>
          cases fields
          exact ⟨PreciseGetter.pattern .lengthMaximum,by simp,by rfl⟩
    · simp [names] at impossible
  case checkedLength =>
    change Inhabits (StandardModel.program externals) (.data names.checkedLength [a]) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .checkedLength lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedLength,1,PreciseGetter.fields .checkedLength⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields with | cons v3 fields =>
          cases fields
          exact ⟨PreciseGetter.pattern .checkedLength,by simp,by rfl⟩
    · simp [names] at impossible
  case lengthValues =>
    change Inhabits (StandardModel.program externals) (.data names.checkedLength [a]) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .lengthValues lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedLength,1,PreciseGetter.fields .lengthValues⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields with | cons v3 fields =>
          cases fields
          exact ⟨PreciseGetter.pattern .lengthValues,by simp,by rfl⟩
    · simp [names] at impossible
  case indexValue =>
    change Inhabits (StandardModel.program externals) (.data names.checkedIndex [a]) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .indexValue lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedIndex,1,PreciseGetter.fields .indexValue⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields
         exact ⟨PreciseGetter.pattern .indexValue,by simp,by rfl⟩
    · simp [names] at impossible
  case indexValues =>
    change Inhabits (StandardModel.program externals) (.data names.checkedIndex [a]) v at hc
    rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
    · obtain ⟨ceq,feq⟩ := precise_only .indexValues lookup owner
      subst c
      have cdEq : cd = ⟨names.checkedIndex,1,PreciseGetter.fields .indexValues⟩ := Option.some.inj lookup.symm
      cases cdEq
      cases fields with | cons v0 fields =>
       cases fields with | cons v1 fields =>
        cases fields with | cons v2 fields =>
         cases fields
         exact ⟨PreciseGetter.pattern .indexValues,by simp,by rfl⟩
    · simp [names] at impossible

private theorem precise_path_wf (g : PreciseGetter) :
    FactsWF (StandardModel.program externals) g.context (Ctx.extend [] g.input)
      (pathFacts (some (.var 0)) (matchedTests g.alts ++ excludedTests g.alts)) := by
  intro p hp
  have exactFacts : pathFacts (some (.var 0)) (matchedTests g.alts ++ excludedTests g.alts) =
      [.constructorIs (.var 0) g.owner,.not (.constructorIs (.var 0) g.owner)] := by cases g <;> rfl
  rw [exactFacts] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · cases g <;> constructor <;> precise_simp
    all_goals exact ⟨_,⟨_,Term.HasData.var rfl rfl⟩,_,rfl,rfl⟩
  · cases List.mem_singleton.mp hp
    cases g <;> constructor <;> precise_simp
    all_goals exact ⟨_,⟨_,Term.HasData.var rfl rfl⟩,_,rfl,rfl⟩

private def _root_.Benitoite.Release.Refinement.StandardSafe.PreciseGetter.before (g : PreciseGetter) : Ctx := Ctx.extend [] g.input
private def _root_.Benitoite.Release.Refinement.StandardSafe.PreciseGetter.armContext (g : PreciseGetter) : Ctx := bindParams g.before [g.carrier]
private def _root_.Benitoite.Release.Refinement.StandardSafe.PreciseGetter.armConditions (g : PreciseGetter) : List Pred :=
    fieldFacts 1 (some (.var 0)) g.links ++ liftMany 1 (pathFacts (some (.var 0)) (matchedTests g.alts) ++ [])

private theorem precise_result_annotation (g : PreciseGetter) :
    Ty.Annotation (StandardModel.program externals) g.context g.before g.tel.result := by
  have ha := precise_annotation (externals := externals) g
  cases g <;> exact ⟨ha.wf.2.1,ha.sorted.2.1,ha.declared.2.1⟩

private theorem precise_result_shift_annotation (g : PreciseGetter) :
    Ty.Annotation (StandardModel.program externals) g.context g.armContext (g.tel.result.shiftV 1 0) :=
  (ShiftMap.outer g.before [g.carrier]).annotation (precise_result_annotation g)


private theorem integer_symmetry {Ξ : List Pred} (x y : Term) (h : Entails Ξ (.eq x y)) : Entails Ξ (.eq y x) := by
  have checked : CertificateKernel.check (.and (.eq (.var 0) (.var 1)) (.eq (.var 0) (.var 0)))
      (.eq (.var 1) (.var 0))
      (.substitute (.eq (.var 0) (.var 1)) (.var 0) (.var 1) (.hyp 0) (.use 1) .integer) = true := by decide
  exact Entails.checkedAt (fun i => if i=0 then some x else some y) checked (.and_intro h .eq_refl)

private theorem integer_lower {Ξ : List Pred} (x y z : Term)
    (h : Entails Ξ (.eq x y)) (r : Entails Ξ (.le z y)) : Entails Ξ (.le z x) := by
  have checked : CertificateKernel.check (.and (.eq (.var 0) (.var 1)) (.le (.var 2) (.var 1)))
      (.le (.var 2) (.var 0))
      (.substitute (.le (.var 3) (.var 0)) (.var 1) (.var 0) (.symm (.hyp 0)) (.use 1) .integer) = true := by decide
  exact Entails.checkedAt (fun i => if i=0 then some x else if i=1 then some y else some z) checked (.and_intro h r)

private theorem integer_upper {Ξ : List Pred} (x y z : Term)
    (h : Entails Ξ (.eq x y)) (r : Entails Ξ (.le y z)) : Entails Ξ (.le x z) := by
  have checked : CertificateKernel.check (.and (.eq (.var 0) (.var 1)) (.le (.var 1) (.var 2)))
      (.le (.var 0) (.var 2))
      (.substitute (.le (.var 0) (.var 3)) (.var 1) (.var 0) (.symm (.hyp 0)) (.use 1) .integer) = true := by decide
  exact Entails.checkedAt (fun i => if i=0 then some x else if i=1 then some y else some z) checked (.and_intro h r)

private theorem integer_strictUpper {Ξ : List Pred} (x y z : Term)
    (h : Entails Ξ (.eq x y)) (r : Entails Ξ (.lt y z)) : Entails Ξ (.lt x z) := by
  have checked : CertificateKernel.check (.and (.eq (.var 0) (.var 1)) (.lt (.var 1) (.var 2)))
      (.lt (.var 0) (.var 2))
      (.substitute (.lt (.var 0) (.var 3)) (.var 1) (.var 0) (.symm (.hyp 0)) (.use 1) .integer) = true := by decide
  exact Entails.checkedAt (fun i => if i=0 then some x else if i=1 then some y else some z) checked (.and_intro h r)

private theorem integer_equality {Ξ : List Pred} (x y z : Term)
    (h : Entails Ξ (.eq x y)) (r : Entails Ξ (.eq y z)) : Entails Ξ (.eq x z) := by
  have checked : CertificateKernel.check (.and (.eq (.var 0) (.var 1)) (.eq (.var 1) (.var 2)))
      (.eq (.var 0) (.var 2))
      (.substitute (.eq (.var 1) (.var 0)) (.var 1) (.var 2) (.hyp 1) (.use 0) .integer) = true := by decide
  exact Entails.checkedAt (fun i => if i=0 then some x else if i=1 then some y else some z) checked (.and_intro h r)

private theorem precise_length_entails :
    Entails (PreciseGetter.checkedLength.armContext.facts ++ PreciseGetter.checkedLength.armConditions)
      (.and (.eq (.var 0) (lengthField names 2 (.var 1)))
        (.and (.eq (.var 0) (length (lengthValues names (.var 1))))
          (.and (.le (lengthField names 0 (.var 1)) (.var 0))
            (.le (.var 0) (lengthField names 1 (.var 1)))))) := by
  have field : Entails (PreciseGetter.checkedLength.armContext.facts ++ PreciseGetter.checkedLength.armConditions)
      (.eq (.var 0) (lengthField names 2 (.var 1))) := .hyp (List.mem_append_right _ List.mem_cons_self)
  have stored : Entails (PreciseGetter.checkedLength.armContext.facts ++ PreciseGetter.checkedLength.armConditions)
      (.eq (lengthField names 2 (.var 1)) (length (lengthValues names (.var 1)))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .checkedLength,(.eq (lengthField names 2 (.var 0)) (length (lengthValues names (.var 0)))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  have lower : Entails (PreciseGetter.checkedLength.armContext.facts ++ PreciseGetter.checkedLength.armConditions)
      (.le (lengthField names 0 (.var 1)) (lengthField names 2 (.var 1))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .checkedLength,(.le (lengthField names 0 (.var 0)) (lengthField names 2 (.var 0))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  have upper : Entails (PreciseGetter.checkedLength.armContext.facts ++ PreciseGetter.checkedLength.armConditions)
      (.le (lengthField names 2 (.var 1)) (lengthField names 1 (.var 1))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .checkedLength,(.le (lengthField names 2 (.var 0)) (lengthField names 1 (.var 0))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  exact .and_intro field (.and_intro (integer_equality _ _ _ field stored)
    (.and_intro (integer_lower _ _ _ field lower) (integer_upper _ _ _ field upper)))

private theorem precise_values_entails :
    Entails (PreciseGetter.lengthValues.armContext.facts ++ PreciseGetter.lengthValues.armConditions)
      (.and (.eq (length (.var 0)) (lengthField names 2 (.var 1)))
        (.and (.le (lengthField names 0 (.var 1)) (length (.var 0)))
          (.le (length (.var 0)) (lengthField names 1 (.var 1))))) := by
  have field : Entails (PreciseGetter.lengthValues.armContext.facts ++ PreciseGetter.lengthValues.armConditions)
      (.eq (length (.var 0)) (length (lengthValues names (.var 1)))) := .hyp (List.mem_append_right _ List.mem_cons_self)
  have stored : Entails (PreciseGetter.lengthValues.armContext.facts ++ PreciseGetter.lengthValues.armConditions)
      (.eq (lengthField names 2 (.var 1)) (length (lengthValues names (.var 1)))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .lengthValues,(.eq (lengthField names 2 (.var 0)) (length (lengthValues names (.var 0)))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  have lower : Entails (PreciseGetter.lengthValues.armContext.facts ++ PreciseGetter.lengthValues.armConditions)
      (.le (lengthField names 0 (.var 1)) (lengthField names 2 (.var 1))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .lengthValues,(.le (lengthField names 0 (.var 0)) (lengthField names 2 (.var 0))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  have upper : Entails (PreciseGetter.lengthValues.armContext.facts ++ PreciseGetter.lengthValues.armConditions)
      (.le (lengthField names 2 (.var 1)) (lengthField names 1 (.var 1))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .lengthValues,(.le (lengthField names 2 (.var 0)) (lengthField names 1 (.var 0))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  have equal := integer_equality _ _ _ field (integer_symmetry _ _ stored)
  exact .and_intro equal (.and_intro (integer_lower _ _ _ equal lower) (integer_upper _ _ _ equal upper))

private theorem precise_index_entails :
    Entails (PreciseGetter.indexValue.armContext.facts ++ PreciseGetter.indexValue.armConditions)
      (.and (.eq (.var 0) (indexValue names (.var 1)))
        (.and (.le (.integer 0) (.var 0)) (.lt (.var 0) (length (indexValues names (.var 1)))))) := by
  have field : Entails (PreciseGetter.indexValue.armContext.facts ++ PreciseGetter.indexValue.armConditions)
      (.eq (.var 0) (indexValue names (.var 1))) := .hyp (List.mem_append_right _ List.mem_cons_self)
  have lower : Entails (PreciseGetter.indexValue.armContext.facts ++ PreciseGetter.indexValue.armConditions)
      (.le (.integer 0) (indexValue names (.var 1))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .indexValue,(.le (.integer 0) (indexValue names (.var 0))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  have upper : Entails (PreciseGetter.indexValue.armContext.facts ++ PreciseGetter.indexValue.armConditions)
      (.lt (indexValue names (.var 1)) (length (indexValues names (.var 1)))) := by
    apply Entails.hyp
    apply List.mem_append_left
    apply Ctx.mem_facts.mpr
    refine ⟨1,PreciseGetter.input .indexValue,(.lt (indexValue names (.var 0)) (length (indexValues names (.var 0)))),rfl,?_,rfl⟩
    precise_simp
    simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ty.core]
  exact .and_intro field (.and_intro (integer_lower _ _ _ field lower) (integer_strictUpper _ _ _ field upper))

private theorem precise_return (g : PreciseGetter) (Q : NoFailCtx) (R : Option Ty) (L : LocalCtx) :
    HasTypeCQ (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty Q g.context g.armContext g.armConditions
      R (.ret (.var 0)) (g.tel.result.shiftV 1 0) Eff.empty L := by
  apply HasTypeCQ.C_Return
  have ha := precise_result_shift_annotation (externals := externals) g
  cases g
  case minimum =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .minimum) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      first | exact .hyp (List.mem_append_right _ (List.mem_cons_self)) | skip
    · exact ha.declared.1
    · exact ha.declared.2
  case maximum =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .maximum) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      first | exact .hyp (List.mem_append_right _ (List.mem_cons_self)) | skip
    · exact ha.declared.1
    · exact ha.declared.2
  case value =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .value) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      first | exact .hyp (List.mem_append_right _ (List.mem_cons_self)) | skip
    · exact ha.declared.1
    · exact ha.declared.2
  case lengthMinimum =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .lengthMinimum) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      first | exact .hyp (List.mem_append_right _ (List.mem_cons_self)) | skip
    · exact ha.declared.1
    · exact ha.declared.2
  case lengthMaximum =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .lengthMaximum) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      first | exact .hyp (List.mem_append_right _ (List.mem_cons_self)) | skip
    · exact ha.declared.1
    · exact ha.declared.2
  case checkedLength =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .checkedLength) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      simpa [PreciseGetter.tel,checkedLength,checkedLengthValues,checkedIndexProjection,Ty.shiftV,Pred.open,openingEnv,predBind,termBind,termBind?,upValues,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length] using precise_length_entails
    · exact ha.declared.1
    · exact ha.declared.2
  case lengthValues =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .list)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .lengthValues) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      simpa [PreciseGetter.tel,checkedLength,checkedLengthValues,checkedIndexProjection,Ty.shiftV,Pred.open,openingEnv,predBind,termBind,termBind?,upValues,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length] using precise_values_entails
    · exact ha.declared.1
    · exact ha.declared.2
  case indexValue =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .indexValue) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      simpa [PreciseGetter.tel,checkedLength,checkedLengthValues,checkedIndexProjection,Ty.shiftV,Pred.open,openingEnv,predBind,termBind,termBind?,upValues,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length] using precise_index_entails
    · exact ha.declared.1
    · exact ha.declared.2
  case indexValues =>
    apply HasTypeVQ.V_Refine (t := .var 0) (sort := .list)
      (HasTypeVQ.V_Var (a := PreciseGetter.carrier .indexValues) rfl (by intro b t e h; cases h)) rfl rfl
    · exact ha.sorted.2
    · exact ha.wf.2.1
    · change Entails _ _
      first | exact .hyp (List.mem_append_right _ (List.mem_cons_self)) | skip
    · exact ha.declared.1
    · exact ha.declared.2

private theorem precise_body (g : PreciseGetter) :
    TelBodyTy (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) StoreTy.empty (QTel g.tel) g.context [] [] g.tel g.body := by
  cases htel : g.tel with
  | done r e => cases g <;> cases htel
  | param label input rest =>
    have hinput : input = g.input := by cases g <;> cases htel <;> rfl
    have hrest : rest = .done g.tel.result Eff.empty := by cases g <;> cases htel <;> rfl
    rw [hinput,hrest]
    apply TelBodyTy.param
    apply TelBodyTy.done
    apply HasTypeCQ.C_Match (obs := some (.var 0))
    · exact .V_Var (a := g.input) (by cases g <;> rfl) (by cases g <;> intro b t e h <;> cases h)
    · intro t ht
      cases Option.some.inj ht
      refine ⟨rfl,.data,?_⟩
      have lookup : (Ctx.extend [] g.input)[0]? = some (some g.input) := by cases g <;> rfl
      have ordinary : Ordinary g.input := by cases g <;> intro b t e h <;> cases h
      exact ⟨⟨g.input,lookup,ordinary⟩,g.input,lookup,by cases g <;> rfl⟩
    · exact .plain (precise_alts g) (precise_links g) (precise_field_wf g)
        (precise_path_wf g) (precise_return g _ _ _) (.nil (precise_result_annotation g))
    · simpa only [PreciseGetter.body,unguardedPats,PreciseGetter.alts,List.map_cons,List.map_nil,List.append_nil] using precise_exhaustive g

/-- 固定19行のうち精密getter九行を、同じ依存列と実本体で検査する。 -/
theorem precise_row_typed (g : PreciseGetter) : g.row.BodyTyped (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) := by
  refine ⟨_,rfl,?_,?_,?_,?_⟩
  · cases g <;> precise_simp
  · cases g <;> precise_simp
    all_goals first
      | exact TyCon.arity_data checkedInteger_arity
      | exact TyCon.arity_data checkedLength_arity
      | exact TyCon.arity_data checkedIndex_arity
  · simpa only [PreciseGetter.row,Def.tel,StandardContracts.signatureTel_rebuild] using precise_annotation g
  · simpa only [PreciseGetter.row,Def.tel,StandardContracts.signatureTel_rebuild] using precise_body g

end
end Benitoite.Release.Refinement.StandardSafe.Composed
