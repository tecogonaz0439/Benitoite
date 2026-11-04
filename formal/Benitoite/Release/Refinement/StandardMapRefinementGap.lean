import Benitoite.Release.Refinement.StandardListBodies
import Benitoite.Release.Refinement.StandardSafeContracts
import Benitoite.Release.Refinement.LogicSound

/-! # Listの依存する長さの注釈と、通常getの枝で不足する事実 -/
namespace Benitoite.Release.Refinement.StandardMapRefinementGap
open InternalContracts
set_option maxRecDepth 5000
set_option maxHeartbeats 1000000

private def C : TypeCtx := [TypeCtx.valueParam,TypeCtx.valueParam]
private def callback : Ty := .fn ["value"] [.tvar 0] (.tvar 1) (Eff.row 0)
private def indexType : Ty := .refined (.base .integer)
 (.and (.le (.integer 0) (.var 0)) (.le (.var 0) (length (.var 2))))
private def accumulatorType : Ty := .refined (.list (.tvar 1))
 (.eq (length (.var 0)) (.var 1))
private def resultType : Ty := .refined (.list (.tvar 1))
 (.eq (length (.var 0)) (length (.var 4)))

/-- xsとfの後でiの上限を、iの後でaccの長さを束縛する依存列。 -/
def mapFromTel : Tel :=
 .param "xs" (.list (.tvar 0)) (.param "f" callback
  (.param "i" indexType (.param "acc" accumulatorType (.done resultType (Eff.row 0)))))

def mapTel : Tel :=
 .param "xs" (.list (.tvar 0)) (.param "f" callback
  (.done (.refined (.list (.tvar 1))
   (.eq (length (.var 0)) (length (.var 2)))) (Eff.row 0)))

private def before : Ctx :=
 (((Ctx.extend [] (.list (.tvar 0))).extend callback).extend indexType).extend accumulatorType
private def gamma : Ctx := before.extend (.data "Option" [.tvar 0])
private def alts : List Alt := [⟨.con "Option.None" [],[]⟩]
private def phi : List Pred := pathFacts (some (.var 0)) (matchedTests alts)
private def goal : Pred := .eq (length (.var 1)) (length (.var 4))
private def eta : ObservationEnvModel := fun
 | 0 => some (.dataValue "Option.None" [])
 | 1 => some (.listValue [some .unitValue])
 | 2 => some (.integer 1)
 | 4 => some (.listValue [some .unitValue,some .unitValue])
 | _ => none

/-- 型の形成と依存する値番号は既存の篩の規則で表せる。 -/
theorem annotations (P : Program) :
 Ty.Annotation P C [] (.dependentFn mapFromTel) ∧
 Ty.Annotation P C [] (.dependentFn mapTel) := by
 constructor <;> constructor
 all_goals simp [mapFromTel,mapTel,C,callback,indexType,accumulatorType,resultType,length,
  Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
  Ty.Declared,Tel.Declared,declaredTys,declaredEff,NamesWF,
  Eff.WF,Eff.Canonical,Eff.row,Eff.norm,Ty.normTys,
  Pred.WF,Pred.VarsIn,Term.VarsIn,Pred.Sorted,Term.HasSort,Term.Shape,
  Term.References,Ctx.Readable,Ordinary,Ty.core,Ty.HasSort,Ty.sort?,
  Ctx.extend,Ty.shiftV,Eff.shiftV,predBind,termBind,Measure.input,Measure.output,
  Pred.Declared,Term.Declared,Ty.NotContCore,Ctx.declarationSelf]

private theorem assumptions_true : ∀ p ∈ gamma.facts ++ phi, p.interpret eta = true := by
 have h : (gamma.facts ++ phi).all (fun p => p.interpret eta) = true := by decide
 exact List.all_eq_true.mp h

private theorem goal_false : goal.interpret eta = false := by decide

/-- 通常のgetの結果型とNoneの経路だけから、accとxsの同長は導けない。 -/
theorem none_branch_gap : ¬Entails (gamma.facts ++ phi) goal := by
 intro h
 have impossible := h.sound eta assumptions_true
 rw [goal_false] at impossible
 cases impossible

example (P : Program) : Ty.Annotation P C [] (.dependentFn mapFromTel) := (annotations P).1
example (P : Program) : Ty.Annotation P C [] (.dependentFn mapTel) := (annotations P).2
example : ¬Entails (gamma.facts ++ phi) goal := none_branch_gap
example : phi = [.constructorIs (.var 0) "Option.None"] := rfl
example : (resultType.shiftV 1 0).refinementPredicates =
 [(.eq (length (.var 0)) (length (.var 5)))] := rfl
end Benitoite.Release.Refinement.StandardMapRefinementGap
