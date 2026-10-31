import Lean
import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.ClosedKeys

namespace Benitoite.Release.Refinement.ClosedReviewBoundary
noncomputable section

def pos : Ty := .refined (.base .integer8) (.lt (.integer 0) (.var 0))
def nilD : ConDecl := ⟨"L",0,[]⟩
def consD : ConDecl := ⟨"L",0,[pos, .data "L" []]⟩
def prog : Program := ⟨fun _ => none, fun c => if c = "Nil" then some nilD else if c = "Cons" then some consD else none,
  fun _ => none, fun _ => none, fun _ => none, fun _ => none, []⟩
def lst (n : Int) : Val := .con "Cons" [] [.const (.integer8 1), .con "Cons" [] [.const (.integer8 n), .con "Nil" [] []]]

theorem pos_subst : pos.subst [] [] = pos := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, pos, typeEnvAt]
theorem l_subst : (Ty.data "L" []).subst [] [] = .data "L" [] := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, typeEnvAt]

theorem pos_ann : Ty.Annotation prog [] [] pos := by
  refine ⟨?_, ?_, ?_⟩
  · simp [pos, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn,Ty.NotContCore,Ty.core]
  · simp [pos,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,
      Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary]
  · simp [pos,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.extend,
      Ctx.Readable,Ty.shiftV,Ordinary]

theorem data_arity : prog.DataArity "L" 0 := by
  refine ⟨⟨"Nil",nilD,rfl,rfl⟩,?_⟩
  intro c cd hc _
  by_cases hn : c = "Nil"
  · subst c; have he : cd = nilD := Option.some.inj hc.symm; subst cd; rfl
  · by_cases hs : c = "Cons"
    · subst c; have he : cd = consD := Option.some.inj hc.symm; subst cd; rfl
    · simp [prog,hn,hs] at hc

theorem data_ann : Ty.Annotation prog [] [] (.data "L" []) :=
  ⟨trivial,trivial,⟨⟨0,data_arity,rfl⟩,trivial⟩⟩

theorem head_carrier (B : Builtins) (Ψ : StoreTy) (n : Int) (hn : -128 ≤ n ∧ n ≤ 127) :
    ExternalCarrier prog B Ψ (.const (.integer8 n)) pos :=
  .refined (.scalar (.V_Const hn)) pos_ann

theorem nil_carrier (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier prog B Ψ (.con "Nil" [] []) (.data "L" []) :=
  .data (cd := nilD) rfl rfl ⟨rfl,[],rfl,by simp⟩ (by simp [nilD]) .nil data_ann

theorem cons_carrier {B Ψ n v} (hn : -128 ≤ n ∧ n ≤ 127)
    (hv : ExternalCarrier prog B Ψ v (.data "L" [])) :
    ExternalCarrier prog B Ψ (.con "Cons" [] [.const (.integer8 n),v]) (.data "L" []) := by
  apply ExternalCarrier.data (cd := consD) rfl rfl
  · exact ⟨rfl,[],rfl,by simp⟩
  · intro t ht
    change t ∈ [pos,.data "L" []] at ht
    rcases List.mem_cons.mp ht with rfl | ht
    · exact pos_ann.wf
    · have he := List.mem_singleton.mp ht; subst t; trivial
  · change ExternalCarrierFields prog B Ψ [.const (.integer8 n),v] [pos.subst [] [], (Ty.data "L" []).subst [] []]
    rw [pos_subst,l_subst]
    exact .cons (head_carrier B Ψ n hn) (.cons hv .nil)
  · exact data_ann

theorem deep_carrier (B : Builtins) (Ψ : StoreTy) : ExternalCarrier prog B Ψ (lst 2) (.data "L" []) :=
  cons_carrier (by decide) (cons_carrier (by decide) (nil_carrier B Ψ))

theorem deep_predicates : ExternalPredicates prog (lst 2) (.data "L" []) := by
  apply ExternalPredicates.data (cd := consD) rfl rfl
  change ExternalPredicatesFields prog [.const (.integer8 1),.con "Cons" [] [.const (.integer8 2),.con "Nil" [] []]]
    [pos.subst [] [],(Ty.data "L" []).subst [] []]
  rw [pos_subst,l_subst]
  apply ExternalPredicatesFields.cons
  · exact .refined .scalar ⟨.integer 1,rfl,by decide⟩
  · apply ExternalPredicatesFields.cons
    · apply ExternalPredicates.data (cd := consD) rfl rfl
      change ExternalPredicatesFields prog [.const (.integer8 2),.con "Nil" [] []]
        [pos.subst [] [],(Ty.data "L" []).subst [] []]
      rw [pos_subst,l_subst]
      exact .cons (.refined .scalar ⟨.integer 2,rfl,by decide⟩) (.cons (.data rfl rfl .nil) .nil)
    · exact .nil

theorem deep_ok (B : Builtins) (Ψ : StoreTy) : externalCheck prog (lst 2) (.data "L" []) = true :=
  (deep_carrier B Ψ).accepted deep_predicates

theorem deep_bad_carrier (B : Builtins) (Ψ : StoreTy) : ExternalCarrier prog B Ψ (lst 0) (.data "L" []) :=
  cons_carrier (by decide) (cons_carrier (by decide) (nil_carrier B Ψ))

theorem p1 : externalCheck P (.const (.integer8 1)) pos = true := by
  simp only [externalCheck,pos,Val.toTerm?,Const.type,Ty.sort?,Pred.open,predBind,termBind,termBind?]; decide

theorem p0 : externalCheck P (.const (.integer8 0)) pos = false := by
  simp only [externalCheck,pos,Val.toTerm?,Const.type,Ty.sort?,Pred.open,predBind,termBind,termBind?]; decide

theorem deep_bad : externalCheck prog (lst 0) (.data "L" []) = false := by
  simp [lst,externalCheck,externalCheckFields,prog,consD,nilD,pos_subst,l_subst,p1,p0]

theorem deep_bad_rejected : externalCheckedOutcome prog (.data "L" []) (.val (lst 0)) = .err "ExternalRefinement" :=
  externalCheckedOutcome_reject deep_bad

theorem recursive_predicates_required (B : Builtins) (Ψ : StoreTy) : ¬ ExternalPredicates prog (lst 0) (.data "L" []) := by
  intro hp
  have he := (deep_bad_carrier B Ψ).accepted hp
  rw [deep_bad] at he
  cases he

def keys : List (Option Term) := [some (.decimal 10 1),some (.decimal 100 2)]

theorem keys_closed : Key.ClosedSlots keys := by
  simp [Key.ClosedSlots,keys,Term.Closed,termWF,Term.VarsIn]

theorem map_agreement (η : ObservationEnvModel) :
    (mapKeys (observeSlots η keys) (observeSlots η [none,none])).map List.length =
      (Key.normalizeMap keys [none,none]).map List.length := Key.normalizeMap_length η _ _ keys_closed

theorem set_agreement (η : ObservationEnvModel) :
    (keySetCodes (observeSlots η keys) []).map List.length =
      (Key.normalizeSet keys).map List.length := Key.normalizeSet_length η _ keys_closed

theorem missing_map_agreement (η : ObservationEnvModel) :
    (mapKeys (observeSlots η [none]) (observeSlots η [none])).map List.length =
      (Key.normalizeMap [none] [none]).map List.length := Key.normalizeMap_length η _ _ (by simp [Key.ClosedSlots])

theorem ready_length_observation :
    ∃ o, (Term.measure .listLength (.listValue [none,none])).observe (fun _ => none) = some o ∧
      o.sort = .integer ∧
      (Term.measure .listLength (.listValue [none,none])).interpret (fun _ => none) = some o ∧
      observeAs (fun _ => none) .integer (.measure .listLength (.listValue [none,none])) = o :=
  termReady_observation (by decide)

end
end Benitoite.Release.Refinement.ClosedReviewBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let ns := env.constants.toList.filterMap fun (n,_) =>
    if (`Benitoite.Release.Refinement.ClosedReviewBoundary).isPrefixOf n then some n else none
  logInfo m!"REVIEW_BOUNDARY_DECLARATIONS {ns.length}"
  for n in ns do elabCommand (← `(#print axioms $(mkIdent n)))
