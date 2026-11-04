import Benitoite.Release.Refinement.StandardSafeContracts

/-! # Checked系と非空の固定依存列と具体構成子の対応 -/
namespace Benitoite.Release.Refinement.StandardSafe
open InternalContracts
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 1000000
set_option linter.unusedSimpArgs false

def names : Names := ⟨"Benitoite.Range.CheckedInteger", "Benitoite.Range.CheckedLength", "Benitoite.Range.CheckedIndex", "Benitoite.Result.Result", "Benitoite.NonEmptyList.EmptyListError", "Benitoite.Range.CheckedInteger", "Benitoite.Range.CheckedLength", "Benitoite.Range.CheckedIndex"⟩
def constructors : List (Benitoite.Release.ConName × ConDecl) := [
 (names.checkedIntegerCtor, ⟨names.checkedInteger, 0, [.base .integer, .base .integer, .base .integer]⟩),
 (names.checkedLengthCtor, ⟨names.checkedLength, 1, [.base .integer, .base .integer, .base .integer, .list (.tvar 0)]⟩),
 (names.checkedIndexCtor, ⟨names.checkedIndex, 1, [.list (.tvar 0), .base .integer, .tvar 0]⟩),
 ("Benitoite.Result.Result.Ok", ⟨names.result, 2, [.tvar 0]⟩),
 ("Benitoite.Result.Result.Error", ⟨names.result, 2, [.tvar 1]⟩),
 ("Benitoite.NonEmptyList.EmptyListError.EmptyList", ⟨names.emptyListError, 0, []⟩)]
def program (definitions : FunName → Option Def) : Program where
 defs := definitions
 cons := fun c => constructors.lookup c
 ops := fun _ => none
 effects := fun _ => none
 classes := fun _ => none
 impls := fun _ => none
variable {defs : FunName → Option Def}

private theorem cons_mem {c cd} (hc : (program defs).cons c = some cd) : (c,cd) ∈ constructors := by
 obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp hc
 rw [eq]
 exact List.mem_append_right _ (List.mem_cons_self ..)
@[simp] theorem checkedInteger_arity : (program defs).DataArity names.checkedInteger 0 := by
 constructor
 · exact ⟨names.checkedIntegerCtor, _, by rfl, rfl⟩
 · intro c cd hc same
   have mem := cons_mem hc
   simp only [constructors, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   all_goals simp_all [names]
@[simp] theorem checkedLength_arity : (program defs).DataArity names.checkedLength 1 := by
 constructor
 · exact ⟨names.checkedLengthCtor, _, by rfl, rfl⟩
 · intro c cd hc same
   have mem := cons_mem hc
   simp only [constructors, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   all_goals simp_all [names]
@[simp] theorem checkedIndex_arity : (program defs).DataArity names.checkedIndex 1 := by
 constructor
 · exact ⟨names.checkedIndexCtor, _, by rfl, rfl⟩
 · intro c cd hc same
   have mem := cons_mem hc
   simp only [constructors, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   all_goals simp_all [names]
@[simp] theorem result_arity : (program defs).DataArity names.result 2 := by
 constructor
 · exact ⟨"Benitoite.Result.Result.Ok", _, by rfl, rfl⟩
 · intro c cd hc same
   have mem := cons_mem hc
   simp only [constructors, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   all_goals simp_all [names]
@[simp] theorem emptyListError_arity : (program defs).DataArity names.emptyListError 0 := by
 constructor
 · exact ⟨"Benitoite.NonEmptyList.EmptyListError.EmptyList", _, by rfl, rfl⟩
 · intro c cd hc same
   have mem := cons_mem hc
   simp only [constructors, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   all_goals simp_all [names]


def C : TypeCtx := [TypeCtx.valueParam]
def D2 : TypeCtx := [TypeCtx.valueParam,TypeCtx.valueParam]
private theorem annotation_01 : Ty.Annotation (program defs) C [] (.dependentFn (safeHead (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_02 : Ty.Annotation (program defs) C [] (.dependentFn (safeGet (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_03 : Ty.Annotation (program defs) C [] (.dependentFn (safeTail (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_04 : Ty.Annotation (program defs) C [] (.dependentFn (checkedGet names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_05 : Ty.Annotation (program defs) D2 [] (.dependentFn (sameLengthGet names (.tvar 0) (.tvar 1))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_06 : Ty.Annotation (program defs) [] [] (.dependentFn (checkedIntegerProjection names 0)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_07 : Ty.Annotation (program defs) [] [] (.dependentFn (checkedIntegerProjection names 1)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_08 : Ty.Annotation (program defs) [] [] (.dependentFn (checkedIntegerProjection names 2)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_09 : Ty.Annotation (program defs) C [] (.dependentFn (checkedLengthProjection names (.tvar 0) 0)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_10 : Ty.Annotation (program defs) C [] (.dependentFn (checkedLengthProjection names (.tvar 0) 1)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_11 : Ty.Annotation (program defs) C [] (.dependentFn (checkedLength names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_12 : Ty.Annotation (program defs) C [] (.dependentFn (checkedLengthValues names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_13 : Ty.Annotation (program defs) C [] (.dependentFn (checkedIndexProjection names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_14 : Ty.Annotation (program defs) C [] (.dependentFn (checkedIndexValues names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_15 : Ty.Annotation (program defs) C [] (.dependentFn (nonemptyFromList names (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_16 : Ty.Annotation (program defs) C [] (.dependentFn (nonemptyToList (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_17 : Ty.Annotation (program defs) C [] (.dependentFn (safeHead (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_18 : Ty.Annotation (program defs) C [] (.dependentFn (safeTail (.tvar 0))) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl

private theorem annotation_19 : Ty.Annotation (program defs) D2 [] (.dependentFn (nonemptyMap (.tvar 0) (.tvar 1) (.row 0))) := by
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
def declarationRows : List StandardContracts.Row :=
 (InternalContracts.all names (.tvar 0) (.tvar 1) (.row 0)).zipIdx |>.map fun (entry,i) =>
  ⟨entry.1, if i=4 ∨ i=18 then D2 else if 5≤i ∧ i≤7 then [] else C,
   if i=18 then 1 else 0,entry.2,none,.core,[]⟩

/-- WF・sort・構成子と欄の宣言を、同じ有限表の全行へ適用する。 -/
theorem declarations_annotation : ∀ row ∈ declarationRows,
 Ty.Annotation (program defs) row.tparams [] (.dependentFn row.tel) := by
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
  | exact annotation_17
  | exact annotation_18
  | exact annotation_19

example : Ty.Annotation (program defs) D2 [] (.dependentFn (nonemptyMap (.tvar 0) (.tvar 1) (.row 0))) :=
 declarations_annotation ⟨"NonEmptyList.map",D2,1,nonemptyMap (.tvar 0) (.tvar 1) (.row 0),none,.core,[]⟩
  (by simp [declarationRows,InternalContracts.all,List.zipIdx])

example : (program defs).DataArity names.checkedInteger 0 := checkedInteger_arity
example : (program defs).DataArity names.checkedLength 1 := checkedLength_arity
example : (program defs).DataArity names.checkedIndex 1 := checkedIndex_arity
example : (program defs).DataArity names.result 2 := result_arity
example : (program defs).DataArity names.emptyListError 0 := emptyListError_arity

end
end Benitoite.Release.Refinement.StandardSafe
