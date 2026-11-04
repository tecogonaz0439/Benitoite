import Benitoite.Release.Refinement.StandardSafeBodies
import Benitoite.Release.Refinement.LogicSound

/-! # 開いたgetter腕に未生成の欄等号の反モデル -/
namespace Benitoite.Release.Refinement.StandardSafeFieldGap
open Benitoite.Release.Refinement Benitoite.Release.Refinement.InternalContracts
set_option maxRecDepth 5000
set_option maxHeartbeats 500000
set_option linter.unusedSimpArgs false

private def names : Names := StandardSafe.names
private def ciDecl : ConDecl := ⟨names.checkedInteger,0,[.base .integer,.base .integer,.base .integer]⟩
private def program : Program := StandardSafe.safeProgram

private def pattern : Pat := .con names.checkedIntegerCtor [.var,.wild,.wild]
private def alts : List Alt := [⟨pattern,[0]⟩]
private def getter : Comp := .match (.var 0) [.mk alts none (.ret (.var 0))]
private def inputType : Ty := checkedIntegerType names
private def before : Ctx := Ctx.extend [] inputType
private def gamma : Ctx := bindParams before [.base .integer]
private def actualPhi : List Pred := liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts) ++ [])
private def phi : List Pred := actualPhi ++ liftMany 1 before.facts

private def minimumRef : FieldRef := ⟨names.checkedInteger,names.checkedIntegerCtor,0,.integer⟩
private def goal : Pred := .eq (.var 0) (.field minimumRef (.var 1))
private def eta : ObservationEnvModel := fun
 | 0 => some (.integer 7)
 | 1 => some (.dataValue names.checkedIntegerCtor [some (.integer 0),some (.integer 0),some (.integer 0)])
 | _ => none

private theorem exact_gamma : gamma = [some (.base .integer),some inputType] := by rfl

private theorem exact_actualPhi : actualPhi = [.constructorIs (.var 1) names.checkedIntegerCtor] := by rfl

private theorem exact_phi : phi = [.constructorIs (.var 1) names.checkedIntegerCtor,
 .le (integerField names 0 (.var 1)) (integerField names 2 (.var 1)),
 .le (integerField names 2 (.var 1)) (integerField names 1 (.var 1))] := by rfl

private theorem actual_pattern_typed : PatTy program pattern inputType [.base .integer] := by
 apply PatTy.P_Refined
 change PatTy program (.con names.checkedIntegerCtor [.var,.wild,.wild]) (.data ciDecl.data []) [.base .integer]
 apply PatTy.P_Con (cd := ciDecl) (ts := []) (by rfl) rfl
 · intro a ha
   simp [ciDecl] at ha
   subst a
   trivial
 · exact .cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil))

private theorem actual_alts_typed : AltsTy program alts inputType [.base .integer] := by
 refine ⟨by decide,rfl,?_,?_⟩
 · intro alt h
   cases Option.some.inj h
   rfl
 · intro alt h
   cases List.mem_singleton.mp h
   exact ⟨[.base .integer],actual_pattern_typed,List.Perm.refl _,rfl⟩

private theorem minimum_declared : minimumRef.Declared program [] gamma (.var 1) := by
 refine ⟨[],ciDecl,.base .integer,Term.HasData.var (by rfl) (by rfl),?_,rfl,rfl,rfl,trivial,rfl⟩
 rfl

private theorem goal_well_formed : Pred.WellFormed program [] gamma goal := by
 have read0 : Ctx.Readable gamma 0 := ⟨.base .integer,rfl,by intro b t e he; cases he⟩
 have read1 : Ctx.Readable gamma 1 := ⟨inputType,rfl,by intro b t e he; cases he⟩
 refine ⟨by decide,?_,?_⟩
 · exact ⟨⟨read0,⟨.base .integer,rfl,rfl⟩⟩,⟨read1,⟨⟨inputType,rfl,rfl⟩,rfl⟩⟩⟩
 · exact ⟨read0,read1,minimum_declared⟩

private theorem selected_observation : eta 0 = some (.integer 7) := rfl

private theorem receiver_observation : eta 1 =
 some (.dataValue names.checkedIntegerCtor [some (.integer 0),some (.integer 0),some (.integer 0)]) := rfl

private theorem exact_result_type :
 ((checkedIntegerProjection names 0).result.shiftV 1 0) =
 .refined (.base .integer) (.eq (.var 0) (.field minimumRef (.var 2))) := by rfl

private theorem exact_open_goal :
 (Pred.eq (.var 0) (.field minimumRef (.var 2))).open (.var 0) = goal := by rfl

private theorem assumptions_true : ∀ p ∈ gamma.facts ++ phi, p.interpret eta = true := by
 have h : (gamma.facts ++ phi).all (fun p => p.interpret eta) = true := by decide
 exact List.all_eq_true.mp h

private theorem goal_false : goal.interpret eta = false := by decide

private theorem not_entails : ¬ Entails (gamma.facts ++ phi) goal := by
 intro h
 have he := h.sound eta assumptions_true
 rw [goal_false] at he
 cases he

private theorem not_entails_actual : ¬ Entails (gamma.facts ++ actualPhi) goal := by
 intro h
 apply not_entails
 apply h.weaken
 intro p hp
 rcases List.mem_append.mp hp with hp | hp
 · exact List.mem_append_left _ hp
 · exact List.mem_append_right _ (List.mem_append_left _ hp)


/-- 当該V_Refineに必要なEntailsだけを反証する。全導出の不可能性は結論しない。 -/
theorem missing_field_equality :
 gamma = [some (.base .integer),some inputType] ∧
 actualPhi = [.constructorIs (.var 1) names.checkedIntegerCtor] ∧
 PatTy program pattern inputType [.base .integer] ∧
 AltsTy program alts inputType [.base .integer] ∧
 Pred.WellFormed program [] gamma goal ∧
 ¬Entails (gamma.facts ++ actualPhi) goal ∧ ¬Entails (gamma.facts ++ phi) goal :=
 ⟨exact_gamma,exact_actualPhi,actual_pattern_typed,actual_alts_typed,goal_well_formed,not_entails_actual,not_entails⟩

example : ¬Entails (gamma.facts ++ actualPhi) goal := missing_field_equality.2.2.2.2.2.1
example : ((checkedIntegerProjection names 0).result.shiftV 1 0) =
 .refined (.base .integer) (.eq (.var 0) (.field minimumRef (.var 2))) := exact_result_type
example : (Pred.eq (.var 0) (.field minimumRef (.var 2))).open (.var 0) = goal := exact_open_goal
example : eta 0 = some (.integer 7) := selected_observation
example : eta 1 = some (.dataValue names.checkedIntegerCtor [some (.integer 0),some (.integer 0),some (.integer 0)]) := receiver_observation
example : phi = [.constructorIs (.var 1) names.checkedIntegerCtor,
 .le (integerField names 0 (.var 1)) (integerField names 2 (.var 1)),
 .le (integerField names 2 (.var 1)) (integerField names 1 (.var 1))] := exact_phi
example : getter = .match (.var 0) [.mk alts none (.ret (.var 0))] := rfl
end Benitoite.Release.Refinement.StandardSafeFieldGap
