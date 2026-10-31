import Lean
import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.KleeneBoundary
noncomputable section

def someField : FieldRef := ⟨"Opt","Some",0,.integer⟩
def positive : Pred := .lt (.integer 0) (.field someField (.var 0))
def cond : Pred := .or (.constructorIs (.var 0) "None") positive
def reverseCond : Pred := .or positive (.constructorIs (.var 0) "None")
def negCond : Pred := .not (.and (.constructorIs (.var 0) "Some")
  (.le (.field someField (.var 0)) (.integer 0)))
def optT : Ty := .data "Opt" []
def noneV : Val := .con "None" [] []
def someV (n : Int) : Val := .con "Some" [] [.const (.integer8 n)]
def noneDecl : ConDecl := ⟨"Opt",0,[]⟩
def someDecl : ConDecl := ⟨"Opt",0,[.base .integer8]⟩
def prog : Program := ⟨fun _ => none, fun c => if c = "None" then some noneDecl else if c = "Some" then some someDecl else none,
  fun _ => none, fun _ => none, fun _ => none, fun _ => none, []⟩
def closed (p : Pred) : Pred := p.open (.dataValue "None" [])
def unknown : Pred := closed positive

theorem unknown_observation : unknown.evalClosed = none := by decide

theorem and_table :
    ([Pred.falsity,.truth,unknown].flatMap fun p =>
      [Pred.falsity,.truth,unknown].map fun q => (p.and q).evalClosed) =
    [some false,some false,some false,some false,some true,none,some false,none,none] := by decide

theorem or_table :
    ([Pred.falsity,.truth,unknown].flatMap fun p =>
      [Pred.falsity,.truth,unknown].map fun q => (p.or q).evalClosed) =
    [some false,some true,none,some true,some true,some true,none,some true,none] := by decide

theorem not_table :
    [Pred.falsity,.truth,unknown].map (fun p => p.not.evalClosed) =
    [some true,some false,none] := by decide

theorem none_eval : (closed cond).evalClosed = some true := by
  apply Pred.evalClosed_or_true_left (by decide) (by decide)
  decide

theorem reverse_none_eval : (closed reverseCond).evalClosed = some true := by
  apply Pred.evalClosed_or_true_right (by decide) (by decide)
  decide

theorem neg_none_eval : (closed negCond).evalClosed = some true := by decide

theorem none_ground : Entails [] (closed cond) := .ground (by decide) (by decide) none_eval

theorem none_facts (η : ObservationEnvModel) : (closed cond).interpret η = true :=
  none_ground.sound η (by simp)

-- 構成子の不一致で欄が観測できない。両側の観測を要求する十分条件の外でも決まる。
theorem decided_without_observable : ¬ (closed cond).ClosedObservable := by
  intro h
  cases h with
  | atom ha _ => cases ha
  | or _ hq => cases hq with
    | atom _ hr => change false = true at hr; cases hr

macro "check_receive" : tactic => `(tactic| (
  simp [externalCheck,externalCheckFields,prog,noneDecl,someDecl,optT,noneV,someV,
    Val.toTerm?,Val.toTermSlots,Const.type,Ty.sort?,Ty.subst,Ty.substAt,substTypeAt,
    Ty.bind,Ty.rawBind,Ty.norm,typeEnvAt]
  <;> decide))

theorem none_receive : externalCheck prog noneV (.refined optT cond) = true := by check_receive

theorem opt_arity : prog.DataArity "Opt" 0 := by
  refine ⟨⟨"None",noneDecl,rfl,rfl⟩,?_⟩
  intro c cd hc _
  by_cases hn : c = "None"
  · subst c; have he : cd = noneDecl := Option.some.inj hc.symm; subst cd; rfl
  · by_cases hs : c = "Some"
    · subst c; have he : cd = someDecl := Option.some.inj hc.symm; subst cd; rfl
    · simp [prog,hn,hs] at hc

theorem opt_ann : Ty.Annotation prog [] [] optT :=
  ⟨trivial,trivial,⟨⟨0,opt_arity,rfl⟩,trivial⟩⟩

theorem cond_ann : Ty.Annotation prog [] [] (.refined optT cond) := by
  refine ⟨?_,?_,?_⟩
  · simp [optT,cond,positive,someField,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Ty.WFList]
  · simp [optT,cond,positive,someField,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,
      Term.VarsIn,Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,sortedTys]
  · refine ⟨opt_ann.declared,?_⟩
    simp only [optT,cond,positive,someField,Pred.Declared,Term.Declared,Ctx.declarationSelf,
      Ctx.extend,Ctx.Readable,Ty.shiftV,Ordinary]
    refine ⟨⟨?_,⟨"Opt",[],noneDecl,.var rfl rfl,rfl,rfl⟩⟩,trivial,?_,?_⟩
    · exact ⟨.data "Opt" [],rfl,by intro b t e he; cases he⟩
    · exact ⟨.data "Opt" [],rfl,by intro b t e he; cases he⟩
    exact ⟨[],someDecl,.base .integer8,.var rfl rfl,rfl,rfl,rfl,rfl,trivial,by decide⟩

theorem none_carrier (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier prog B Ψ noneV (.refined optT cond) :=
  .refined (.data (cd := noneDecl) rfl rfl ⟨rfl,[],rfl,by simp⟩
    (by simp [noneDecl]) .nil opt_ann) cond_ann

theorem none_typed (B : Builtins) (Ψ : StoreTy) :
    HasTypeV prog B Ψ [] [] [] noneV (.refined optT cond) :=
  (none_carrier B Ψ).checked_typed none_receive

theorem none_outcome : externalCheckedOutcome prog (.refined optT cond) (.val noneV) = .val noneV := by
  simp [externalCheckedOutcome,none_receive]

theorem none_outcome_typed (B : Builtins) (Ψ : StoreTy) :
    Outcome.Typed prog B Ψ (externalCheckedOutcome prog (.refined optT cond) (.val noneV)) (.refined optT cond) :=
  externalCheckedOutcome_typed ⟨none_carrier B Ψ,by simp [noneV,Val.Ground,Val.ClosedAt,Val.ClosedList]⟩

theorem reverse_none_receive : externalCheck prog noneV (.refined optT reverseCond) = true := by check_receive

theorem neg_none_receive : externalCheck prog noneV (.refined optT negCond) = true := by check_receive

theorem positive_some_receive : externalCheck prog (someV 2) (.refined optT cond) = true := by check_receive

theorem violating_some_rejected : externalCheck prog (someV 0) (.refined optT cond) = false := by check_receive

theorem violating_neg_some_rejected : externalCheck prog (someV 0) (.refined optT negCond) = false := by check_receive

theorem violating_some_err : externalCheckedOutcome prog (.refined optT cond) (.val (someV 0)) =
    .err "ExternalRefinement" := externalCheckedOutcome_reject violating_some_rejected

def undecided : List Pred := [.or positive .falsity,.and positive .truth,.not positive]

theorem undecided_evals : undecided.map (fun p => (closed p).evalClosed) = [none,none,none] := by decide

theorem undecided_rejected : undecided.map (fun p => externalCheck prog noneV (.refined optT p)) =
    [false,false,false] := by check_receive

theorem undecided_err : undecided.map (fun p => externalCheckedOutcome prog (.refined optT p) (.val noneV)) =
    [.err "ExternalRefinement",.err "ExternalRefinement",.err "ExternalRefinement"] := by
  simp only [undecided,List.map_cons,List.map_nil,externalCheckedOutcome]
  have he := undecided_rejected
  simp only [undecided,List.map_cons,List.map_nil,List.cons.injEq] at he
  simp [he.1,he.2.1,he.2.2.1]

theorem ill_sorted_not_rescued :
    (Pred.or .truth (.eq (.boolean true) (.integer 0))).evalClosed = none ∧
    (Pred.and .falsity (.eq (.boolean true) (.integer 0))).evalClosed = none := by decide

theorem ill_sorted_receive_err :
    externalCheckedOutcome prog (.refined optT (.or .truth (.eq (.boolean true) (.integer 0)) )) (.val noneV) =
    .err "ExternalRefinement" := by
  apply externalCheckedOutcome_reject
  check_receive

end
end Benitoite.Release.Refinement.KleeneBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let ns := env.constants.toList.filterMap fun (n,_) =>
    if (`Benitoite.Release.Refinement.KleeneBoundary).isPrefixOf n then some n else none
  logInfo m!"KLEENE_BOUNDARY_DECLARATIONS {ns.length}"
  for n in ns do elabCommand (← `(#print axioms $(mkIdent n)))
