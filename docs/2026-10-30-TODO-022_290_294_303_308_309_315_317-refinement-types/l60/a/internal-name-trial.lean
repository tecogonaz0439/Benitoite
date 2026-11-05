import Lean
import Benitoite
namespace Benitoite.RefinementInternalNameTrial
open Benitoite.Release.Refinement
open Benitoite.Release.Refinement.StandardSafe
open Benitoite.Release.Refinement.InternalContracts
open Benitoite.Release (NoFailCtx Qempty)
open StandardKeyTyping
noncomputable section
set_option linter.unusedSimpArgs false
abbrev ordinary := StandardOrdinaryCoreBodies.Getter.minimum.publicDefinition
abbrev precise := (StandardSafe.PreciseGetter.minimum.row.definition).getD ordinary
def definitions : List (Benitoite.Release.FunName × Def) :=
  [("%Range.minimum.ordinary",ordinary),("%Range.minimum.refined",precise),
   (StandardOrdinaryCoreBodies.Getter.minimum.name,StandardOrdinaryCoreBodies.Getter.minimum.definition)]
def program : Program := {StandardOrdinaryCoreProgram.program with defs := fun n => definitions.lookup n}
abbrev builtins := StandardOrdinaryCoreBodies.builtins
example : program.defs "%Range.minimum.ordinary" = some ordinary := rfl
example : program.defs "%Range.minimum.refined" = some precise := rfl
theorem ordinary_typed : ordinary.WellTyped program builtins :=
  StandardOrdinaryCoreBodies.projection_typed rfl (by intros; rfl) .minimum rfl
private theorem integer_arity : program.DataArity names.checkedInteger 0 :=
  StandardOrdinaryCoreProgram.data_arity .ci
private theorem annotation : Ty.Annotation program [] [] (.dependentFn (checkedIntegerProjection names 0)) := by
 constructor
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,NamesWF,Ty.WF,Tel.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,C,D2]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,Measure.input,Measure.output,sortedEff,sortedTys,Eff.empty]
 · simp [safeHead,safeGet,safeTail,checkedGet,sameLengthGet,checkedIntegerProjection,checkedLengthProjection,checkedLength,checkedLengthValues,checkedIndexProjection,checkedIndexValues,nonemptyFromList,nonemptyToList,nonemptyMap,nonnegativeIndex,nonempty,nonemptyType,nonemptyPredicate,checkedIntegerType,checkedLengthType,checkedIndexType,integerField,lengthField,lengthValues,indexValue,indexValues,getField,length,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ordinary,Ty.core,Ctx.extend,Eff.shiftV,Eff.row,Eff.WF,Eff.norm,predBind,termBind,Ty.shiftV,declaredEff,declaredTys,Eff.empty,integer_arity]
   all_goals repeat' apply And.intro
   all_goals
     refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
     · simp [Ty.WF]
     · rfl


local macro "safe_simp" : tactic => `(tactic|
 simp_all [headRow,toListRow,getRow,checkedRow,sameRow,fromListRow,nonemptyHeadRow,
  safeHead,safeGet,checkedGet,sameLengthGet,nonemptyFromList,nonemptyToList,Tel.arity,C,D2,a,PrimSig.tel,Def.tel,signatureTel,TypeCtx.valueParam,TypeCtx.kinds,
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


local macro "precise_simp" : tactic => `(tactic|
 (simp_all [PreciseGetter.tel,PreciseGetter.context,PreciseGetter.owner,PreciseGetter.fields,
   PreciseGetter.position,PreciseGetter.input,PreciseGetter.carrier,PreciseGetter.pattern,
   PreciseGetter.alts,PreciseGetter.measure,PreciseGetter.ref,PreciseGetter.links,
   precise,ordinary,StandardContracts.Row.definition,Option.getD,PreciseGetter.row,checkedIntegerProjection,checkedLengthProjection,checkedLength,
   checkedLengthValues,checkedIndexProjection,checkedIndexValues,checkedIntegerType,checkedLengthType,
   integerField,lengthField,lengthValues,viewTerm,fieldFacts,FieldLink.predicate,routeTerm]
  <;> safe_simp))


private theorem alts : AltsTy program PreciseGetter.minimum.alts PreciseGetter.minimum.input [PreciseGetter.minimum.carrier] := by
  refine ⟨by decide,rfl,?_,?_⟩
  · intro alt h; cases Option.some.inj h; rfl
  · intro alt h; cases List.mem_singleton.mp h
    refine ⟨[PreciseGetter.carrier .minimum],.P_Refined ?_,List.Perm.refl _,rfl⟩
    apply PatTy.P_Con (cd := ⟨names.checkedInteger,0,[.base .integer,.base .integer,.base .integer]⟩) (ts := []) rfl rfl
    · intro t ht; simp at ht; rcases ht with rfl | rfl | rfl <;> simp [Ty.WF]
    · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil)))
private theorem links : LinksValid PreciseGetter.minimum.alts 1 PreciseGetter.minimum.links := by
  intro link hl
  cases List.mem_singleton.mp hl
  refine ⟨_,rfl,⟨_,_,rfl⟩,by decide,rfl,?_,by decide⟩
  exact BinderPath.con (j := 0) (i := 0) rfl rfl rfl .var
private theorem field_wf :
    FactsWF program PreciseGetter.minimum.context (bindParams (Ctx.extend [] PreciseGetter.minimum.input) [PreciseGetter.minimum.carrier])
      (fieldFacts 1 (some (.var 0)) PreciseGetter.minimum.links) := by
  intro p hp
  cases List.mem_singleton.mp hp
  constructor <;> precise_simp
  all_goals
    refine ⟨_,_,_,Term.HasData.var rfl rfl,rfl,rfl,rfl,rfl,?_,rfl⟩
    simp [Ty.WF]
private theorem only {c cd} (lookup : program.cons c = some cd) (owner : cd.data = names.checkedInteger) :
    c = names.checkedInteger ∧ cd.args = [.base .integer,.base .integer,.base .integer] := by
  have mem : (c,cd) ∈ StandardOrdinaryCoreBodies.constructorTable := by
    obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
    rw [eq]
    exact List.mem_append_right _ List.mem_cons_self
  simp only [StandardOrdinaryCoreBodies.constructorTable,StandardOrdinaryCoreBodies.declarations,
    DataDecl.entries,List.flatMap_cons,List.flatMap_nil,List.map_cons,List.map_nil,List.append_nil,List.cons_append,List.nil_append] at mem
  simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp_all [StandardOrdinaryCoreBodies.Record.owner,StandardOrdinaryCoreBodies.Record.fields,names]
private theorem exhaustive : Exhaustive program PreciseGetter.minimum.input [PreciseGetter.minimum.pattern] := by
  intro v hv
  have hc := hv.core
  change Inhabits program (.data names.checkedInteger []) v at hc
  rcases hc.data_inv _ _ rfl with ⟨c,tys,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
  · obtain ⟨ceq,feq⟩ := only lookup owner
    subst c
    have cdEq : cd = ⟨names.checkedInteger,0,PreciseGetter.fields .minimum⟩ := Option.some.inj lookup.symm
    cases cdEq
    cases fields with | cons v0 fields =>
     cases fields with | cons v1 fields =>
      cases fields with | cons v2 fields =>
       cases fields
       exact ⟨PreciseGetter.pattern .minimum,by simp,by rfl⟩
  · simp [names] at impossible
private theorem path_wf :
    FactsWF program PreciseGetter.minimum.context (Ctx.extend [] PreciseGetter.minimum.input)
      (pathFacts (some (.var 0)) (matchedTests PreciseGetter.minimum.alts ++ excludedTests PreciseGetter.minimum.alts)) := by
  intro p hp
  change p ∈ [.constructorIs (.var 0) names.checkedInteger,.not (.constructorIs (.var 0) names.checkedInteger)] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · constructor <;> precise_simp
    all_goals exact ⟨_,⟨_,Term.HasData.var rfl rfl⟩,_,rfl,rfl⟩
  · cases List.mem_singleton.mp hp
    constructor <;> precise_simp
    all_goals exact ⟨_,⟨_,Term.HasData.var rfl rfl⟩,_,rfl,rfl⟩
private abbrev before := Ctx.extend [] PreciseGetter.minimum.input
private abbrev armContext := bindParams before [PreciseGetter.minimum.carrier]
private abbrev conditions := fieldFacts 1 (some (.var 0)) PreciseGetter.minimum.links ++
  liftMany 1 (pathFacts (some (.var 0)) (matchedTests PreciseGetter.minimum.alts) ++ [])
private theorem result_annotation : Ty.Annotation program [] before PreciseGetter.minimum.tel.result :=
  ⟨annotation.wf.2.1,annotation.sorted.2.1,annotation.declared.2.1⟩
private theorem returned (Q : NoFailCtx) (R : Option Ty) (L : LocalCtx) :
    HasTypeCQ program builtins StoreTy.empty Q [] armContext conditions
      R (.ret (.var 0)) (PreciseGetter.minimum.tel.result.shiftV 1 0) Eff.empty L := by
  apply HasTypeCQ.C_Return
  have ha := (ShiftMap.outer before [PreciseGetter.minimum.carrier]).annotation result_annotation
  apply HasTypeVQ.V_Refine (t := .var 0) (sort := .integer)
    (HasTypeVQ.V_Var (a := PreciseGetter.carrier .minimum) rfl (by intro b t e h; cases h)) rfl rfl
  · exact ha.sorted.2
  · exact ha.wf.2.1
  · exact .hyp (List.mem_append_right _ List.mem_cons_self)
  · exact ha.declared.1
  · exact ha.declared.2
 theorem precise_typed : precise.WellTyped program builtins := by
  refine ⟨?_,?_,?_,?_⟩
  · precise_simp
  · precise_simp
    exact TyCon.arity_data (StandardOrdinaryCoreProgram.data_arity .ci)
  · simpa only [precise,StandardContracts.Row.definition,PreciseGetter.row,Def.tel,StandardContracts.signatureTel_rebuild,Option.getD,PreciseGetter.context] using (show Ty.Annotation program [] [] (.dependentFn PreciseGetter.minimum.tel) from annotation)
  · change TelBodyTy program builtins StoreTy.empty (QTel PreciseGetter.minimum.tel) [] [] [] PreciseGetter.minimum.tel PreciseGetter.minimum.body
    apply TelBodyTy.param
    apply TelBodyTy.done
    apply HasTypeCQ.C_Match (obs := some (.var 0))
    · exact .V_Var (a := PreciseGetter.minimum.input) rfl (by intro b t e h; cases h)
    · intro t ht
      cases Option.some.inj ht
      refine ⟨rfl,.data,?_⟩
      exact ⟨⟨_,rfl,by intro b t e h; cases h⟩,_,rfl,rfl⟩
    · exact .plain alts links field_wf path_wf (returned _ _ _) (.nil result_annotation)
    · simpa only [PreciseGetter.body,unguardedPats,PreciseGetter.alts,List.map_cons,List.map_nil,List.append_nil] using exhaustive
example : (program.defs "%Range.minimum.ordinary" = some ordinary ∧ ordinary.WellTyped program builtins) ∧
    (program.defs "%Range.minimum.refined" = some precise ∧ precise.WellTyped program builtins) :=
  ⟨⟨rfl,ordinary_typed⟩,⟨rfl,precise_typed⟩⟩
end
end Benitoite.RefinementInternalNameTrial

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
