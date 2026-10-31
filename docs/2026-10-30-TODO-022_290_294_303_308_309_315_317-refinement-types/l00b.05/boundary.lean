import Lean
import Benitoite.Release.Refinement.ExternalConnection
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.Certificate

namespace Benitoite.Release.Refinement.LeafReceiveBoundary
noncomputable section

def scalar : Ty := .base .integer8
def condition : Pred := .le (.integer 0) (.var 0)
def positive : Ty := .refined scalar condition
def seven : Val := .const (.integer8 7)
def negative : Val := .const (.integer8 (-1))
def f : ExternalFunctionId := .mk 0
def decl : ExternalSignature := ⟨.mk 0,"receive",[],[],.done positive Eff.empty,[]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none,
    externals := [(.function f,.function f decl)] }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set",
    externalResponse := fun id ts vs out obs =>
      id = f ∧ ts = [] ∧ vs = [] ∧ obs = [] ∧ (out = .val seven ∨ out = .val negative) }

theorem positive_ann : Ty.Annotation P [] [] positive := by
  refine ⟨?_,?_,?_⟩
  · simp [positive,scalar,condition,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · simp [positive,scalar,condition,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,
      Term.VarsIn,Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary]
  · simp [positive,scalar,condition,Ty.Declared,Pred.Declared,Term.Declared,
      Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Ordinary,Ctx.Readable]

theorem done_ann : Ty.Annotation P [] [] (.dependentFn (.done positive Eff.empty)) := by
  exact ⟨⟨positive_ann.wf,trivial,rfl⟩,⟨positive_ann.sorted,trivial⟩,⟨positive_ann.declared,trivial⟩⟩

theorem decl_wf : decl.WF P := by
  refine ⟨rfl,rfl,done_ann,?_,?_,by simp [decl],?_⟩
  · simp [decl,positive,scalar,Ty.HasKind,kindsTel,kindsEff,Ty.NotContCore,Ty.core,Eff.empty,kindsList]
  · intro use; constructor
    · simp [decl]
    · intro h; cases h with | result h => cases h with | refined h => cases h
  · exact .done (.refined (.scalar (b := .integer8) trivial)) rfl

theorem admissible : ExternalCallAdmissible P B [] decl [] := by
  refine ⟨rfl,⟨rfl,[],rfl,?_⟩,⟨rfl,?_⟩,?_⟩
  · intro i a k hi; cases hi
  · intro i a p hi; cases hi
  · intro t ht; cases ht

theorem bound_decl : Tel.bind (typeEnv []) decl.parameters = .done positive Eff.empty := by
  simp [decl,positive,scalar,condition,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,
    Eff.rawBind,Eff.norm,Eff.empty,rowFails,rawBindTys,Ty.normTys,typeEnv,typeEnvAt,
    instAtoms_nil,substAtoms_nil,predBind,upValues,termBind,termBind?]

theorem arguments : ExternalArgs P B StoreTy.empty decl [] [] positive Eff.empty := by
  refine ⟨admissible,?_,by simp,by simp,⟨positive_ann.wf,Ty.canonical_of_wf positive_ann.wf⟩,⟨trivial,rfl⟩⟩
  rw [bound_decl]; exact .done done_ann

theorem call_typed : HasTypeC P B StoreTy.empty [] [] [] none
    (.externalCall f [] []) positive Eff.empty :=
  .C_External rfl decl_wf admissible arguments.arguments

theorem seven_carrier : Outcome.Carrier P B StoreTy.empty (.val seven) positive := by
  exact ⟨.refined (.scalar (.V_Const (by change (-128 : Int) ≤ _ ∧ _ ≤ 127; decide))) positive_ann,trivial⟩
theorem negative_carrier : Outcome.Carrier P B StoreTy.empty (.val negative) positive := by
  exact ⟨.refined (.scalar (.V_Const (by change (-128 : Int) ≤ _ ∧ _ ≤ 127; decide))) positive_ann,trivial⟩

macro "receive_check" : tactic => `(tactic| (simp only [externalCheck,positive,scalar,condition,
  seven,negative,Ty.sort?,Val.toTerm?,Const.type,Pred.open,predBind,termBind,termBind?]; decide))
theorem accept : externalCheck P seven positive = true := by receive_check
theorem reject : externalCheck P negative positive = false := by receive_check

theorem seven_typed : HasTypeV P B StoreTy.empty [] [] [] seven positive :=
  seven_carrier.1.checked_typed accept

theorem seven_observation : ∃ t, (Tel.argumentsEnv seven).values 0 = some t ∧
    termBind (Tel.argumentsEnv seven).values (.var 0) = t ∧ t.Closed :=
  seven_typed.argumentsEnv_observation (s := .integer) rfl

def call : State := .run (.pure (.externalCall f [] [])) [] Store.empty
def returned : State := .run (.pure (.ret seven)) [] Store.empty
def rejected : State := .error ["ExternalRefinement"] [] Store.empty

private theorem state_of_comp {body : Comp}
    (hb : HasTypeC P B StoreTy.empty [] [] [] none body positive Eff.empty)
    (hc : body.ClosedAt 0 0) (ha : body.Adequate σ) (hv : σ.Valid) :
    StateTy P B σ (.run (Closure.pure body) [] Store.empty) := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,positive,positive,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,?_,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ positive_ann,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · exact .pure hb done_ann (by intros; contradiction)
  · exact ⟨trivial,ha⟩
  · exact ⟨trivial,hc⟩
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem before (hv : σ.Valid) : StateTy P B σ call :=
  state_of_comp call_typed (by simp [Comp.ClosedAt,Val.ClosedList]) (by trivial) hv

theorem accepted_step (σ : PathEnv) : Step P B σ call none returned :=
  .external_accept arguments rfl rfl ⟨rfl,rfl,rfl,rfl,Or.inl rfl⟩ accept

theorem rejected_step (σ : PathEnv) : Step P B σ call none rejected :=
  .external_reject arguments rfl rfl ⟨rfl,rfl,rfl,rfl,Or.inr rfl⟩ reject

theorem after_accept (hv : σ.Valid) : StateTy P B σ returned :=
  state_of_comp (.C_Return seven_typed) (by trivial) (by trivial) hv

theorem after_reject (hv : σ.Valid) : StateTy P B σ rejected := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,positive,positive,Eff.empty,
    StoreOk.empty P B σ,.K_Empty ⟨fun _ h => h,fun _ h => h⟩ positive_ann,?_,?_⟩
  · intro a ha; cases ha
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem step_accept (σ : PathEnv) :
    step P B σ (fun _ _ _ _ => (.err "unused",[])) (fun _ _ _ => (.val seven,[]))
      (fun _ => none) (fun _ => 0) call = some (none,returned) := by
  change (match externalReceive P decl [] [] (.val seven) with
    | some (.val v) => some (none, State.run (Closure.pure (.ret v)) [] Store.empty)
    | some (.err r) => some (none, State.error [r] [] Store.empty)
    | _ => none) = _
  rw [externalReceive_of_args arguments]
  simp [externalCheckedOutcome,accept,returned]

theorem step_reject (σ : PathEnv) :
    step P B σ (fun _ _ _ _ => (.err "unused",[])) (fun _ _ _ => (.val negative,[]))
      (fun _ => none) (fun _ => 0) call = some (none,rejected) := by
  change (match externalReceive P decl [] [] (.val negative) with
    | some (.val v) => some (none, State.run (Closure.pure (.ret v)) [] Store.empty)
    | some (.err r) => some (none, State.error [r] [] Store.empty)
    | _ => none) = _
  rw [externalReceive_of_args arguments,externalCheckedOutcome_reject reject]
  rfl

def lengthLeaf : PreparedLeaf := ⟨.le (.integer 0) (.measure .listLength (.listValue [none,some (.integer 3)])),.lengthNonnegative⟩
def nonempty : Certificate := .consume (.discard (.leaf lengthLeaf))
theorem length_certificate : nonempty.check [.and .truth .truth] lengthLeaf.predicate = true := by
  simp only [nonempty,Certificate.check,lengthLeaf,PreparedLeaf.check,decide_true,Bool.true_and]
  decide
theorem length_entails : Entails [.and .truth .truth] lengthLeaf.predicate := Certificate.sound length_certificate

theorem branched : Certificate.check [.or .truth .truth] .truth (.cases (.use 0) (.use 0)) = true := by simp [Certificate.check]
theorem branched_entails : Entails [.or .truth .truth] .truth := Certificate.sound branched

theorem out_of_range : Certificate.check [.truth] .truth (.use 1) = false := by decide
theorem sibling_reference : Certificate.check [.or .truth .falsity] .truth (.cases (.use 0) (.use 1)) = false := by simp [Certificate.check]
theorem corrupt_leaf : Certificate.check [] .falsity (.leaf ⟨.falsity,.closed⟩) = false := by simp [Certificate.check,PreparedLeaf.check,Pred.closedTrue]; decide
theorem wrong_sort : Certificate.check [] (.eq (.boolean true) (.integer 1))
    (.leaf ⟨.eq (.boolean true) (.integer 1),.closed⟩) = false := by
  simp only [Certificate.check,decide_true,Bool.true_and,PreparedLeaf.check,Bool.and_true]
  decide
theorem corrupt_eq : EqProof.check (.integer 0) (.integer 1) .refl = false := by simp [EqProof.check]
theorem wrong_builtin : PreparedLeaf.check ⟨.truth,.lengthNonnegative⟩ = false := by decide

/-- sort入口は、論理のhypだけでは拒めない不適格な仮定も拒否する。 -/
theorem malformed_assumption : Certificate.checkSorted []
    [.eq (.boolean true) (.integer 1)] (.eq (.boolean true) (.integer 1)) (.use 0) = false := by
  simp [Certificate.checkSorted,Pred.Sorted,Term.HasSort,Term.Shape]

theorem sorted_certificate : Certificate.checkSorted [] [.and .truth .truth]
    lengthLeaf.predicate nonempty = true := by
  simp only [Certificate.checkSorted]
  have hs : lengthLeaf.predicate.Sorted [] none ∧
      ∀ p ∈ [Pred.and .truth .truth], p.Sorted [] none := by
    constructor
    · decide
    · intro p hp; simp only [List.mem_singleton] at hp; cases hp; trivial
  simp only [Bool.and_eq_true,decide_eq_true_eq]
  exact ⟨hs,length_certificate⟩

theorem substituted_certificate : Certificate.check [] (.le (.integer 7) (.integer 8))
    (.substitute (.le (.var 0) (.integer 8)) (.integer 7) (.integer 7) .refl
      (.leaf ⟨.le (.integer 7) (.integer 8),.closed⟩)) = true := by
  simp only [Certificate.check,Pred.open,predBind,termBind,termBind?,EqProof.check,
    Option.getD_some,decide_true,Bool.true_and,PreparedLeaf.check,Bool.and_true]
  decide

theorem substituted_entails : Entails [] (.le (.integer 7) (.integer 8)) :=
  Certificate.sound substituted_certificate

/-- 宣言の結果型を求められても、exitを実行へ写す規則はない。 -/
theorem exit_rejected (σ : PathEnv) :
    step P B σ (fun _ _ _ _ => (.err "unused",[])) (fun _ _ _ => (.exit 0,[]))
      (fun _ => none) (fun _ => 0) call = none := by
  change (match externalReceive P decl [] [] (.exit 0) with
    | some (.val v) => some (none, State.run (Closure.pure (.ret v)) [] Store.empty)
    | some (.err r) => some (none, State.error [r] [] Store.empty)
    | _ => none) = _
  rw [externalReceive_of_args arguments]
  rfl

/-- 観測不能な根の既定値と、snapshotの欠落は異なる。 -/
theorem missing_slot_preserved :
    (Tel.argumentsEnv (.fnRef "opaque" [] [])).values 0 = none ∧
    slotBind (Tel.argumentsEnv (.fnRef "opaque" [] [])).values (some (.var 0)) = none ∧
    termBind (Tel.argumentsEnv (.fnRef "opaque" [] [])).values (.var 0) = .integer 0 := by
  exact ⟨rfl,rfl,rfl⟩

/-- 幅の外の数値は、外部のcarrierの葉にも使えない。 -/
theorem unrepresented : ¬ ConstOK B (.integer8 128) := by
  change ¬ ((-128 : Int) ≤ 128 ∧ 128 ≤ 127)
  decide

/-- 不変な欄からのlengthと展開した値のlengthは、閉じた葉で一致する。 -/
def fieldLength : PreparedLeaf :=
  ⟨.eq (.measure .listLength (.field ⟨"Box","Box",0,.list⟩
      (.dataValue "Box" [some (.listValue [none,none])])))
    (.measure .listLength (.listValue [none,none])),.closed⟩
theorem field_length : fieldLength.check = true := by decide
theorem field_length_entails : Entails [] fieldLength.predicate := fieldLength.entails field_length

namespace Dependent

/-- 先行する実引数xから、結果の篩x ≤ rを具体化する。 -/
def depResult : Ty := .refined scalar (.le (.var 1) (.var 0))
def depTel : Tel := .param "x" scalar (.done depResult Eff.empty)
def depDecl : ExternalSignature := ⟨.mk 0,"dep",[],[],depTel,[]⟩
def five : Val := .const (.integer8 5)
def three : Val := .const (.integer8 3)
def received : Ty := .refined scalar (.le (.integer 5) (.var 0))
def depP : Program := { P with externals := [(.function f,.function f depDecl)] }
def depB : Builtins := { B with externalResponse := fun id ts vs out obs =>
  id = f ∧ ts = [] ∧ vs = [five] ∧ obs = [] ∧
    (out = .val seven ∨ out = .val three ∨ out = .err "trap") }

theorem received_ann : Ty.Annotation depP [] [] received := by
  refine ⟨?_,?_,?_⟩
  · simp [received,scalar,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · simp [received,scalar,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,
      Term.VarsIn,Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary]
  · simp [received,scalar,Ty.Declared,Pred.Declared,Term.Declared,
      Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Ordinary,Ctx.Readable]

theorem received_done_ann : Ty.Annotation depP [] [] (.dependentFn (.done received Eff.empty)) :=
  ⟨⟨received_ann.wf,trivial,rfl⟩,⟨received_ann.sorted,trivial⟩,⟨received_ann.declared,trivial⟩⟩

theorem dep_admissible : ExternalCallAdmissible depP depB [] depDecl [] := by
  refine ⟨rfl,⟨rfl,[],rfl,?_⟩,⟨rfl,?_⟩,?_⟩
  · intro i a k hi; cases hi
  · intro i a p hi; cases hi
  · intro t ht; cases ht

theorem dep_arguments : ExternalArgs depP depB StoreTy.empty depDecl [] [five] received Eff.empty := by
  refine ⟨dep_admissible,?_,?_,by simp,
    ⟨received_ann.wf,Ty.canonical_of_wf received_ann.wf⟩,⟨trivial,rfl⟩⟩
  · have hb : Tel.bind (typeEnv []) depDecl.parameters = depTel := by
      simp [depDecl,depTel,depResult,scalar,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,
        Eff.rawBind,Eff.norm,Eff.empty,rowFails,rawBindTys,Ty.normTys,typeEnv,typeEnvAt,
        instAtoms_nil,substAtoms_nil,predBind,upValues,termBind,termBind?]
    rw [hb]
    apply HasTypeTelArgsQ.param (v := five) (a := scalar) ⟨trivial,trivial,trivial⟩
      (.V_Const (by change (-128 : Int) ≤ 5 ∧ 5 ≤ 127; decide))
    have ht : HasTypeTelArgs depP depB StoreTy.empty [] [] [] []
        (.done received Eff.empty) received Eff.empty := .done received_done_ann
    simpa [depTel,depResult,received,scalar,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,
      Eff.rawBind,Eff.norm,Eff.empty,rowFails,rawBindTys,Ty.normTys,
      instAtoms_nil,substAtoms_nil,predBind,upValues,termBind,termBind?,Tel.argumentsEnv,valEnv,five,Val.toTerm?] using ht
  · intro v hv; simp only [List.mem_singleton] at hv; cases hv; trivial

theorem dep_instantiate : depDecl.instantiate [] [five] = some (received,Eff.empty) :=
  dep_arguments.instantiate

theorem dep_accept : externalCheck depP seven received = true := by
  simp only [externalCheck,received,scalar,seven,Ty.sort?,Val.toTerm?,Const.type,
    Pred.open,predBind,termBind,termBind?]
  decide

theorem dep_reject : externalCheck depP three received = false := by
  simp only [externalCheck,received,scalar,three,Ty.sort?,Val.toTerm?,Const.type,
    Pred.open,predBind,termBind,termBind?]
  decide

def depCall : State := .run (.pure (.externalCall f [] [five])) [] Store.empty

theorem dep_accepted_step (σ : PathEnv) : Step depP depB σ depCall none
    (.run (.pure (.ret seven)) [] Store.empty) :=
  .external_accept dep_arguments rfl rfl ⟨rfl,rfl,rfl,rfl,Or.inl rfl⟩ dep_accept

theorem dep_rejected_step (σ : PathEnv) : Step depP depB σ depCall none
    (.error ["ExternalRefinement"] [] Store.empty) :=
  .external_reject dep_arguments rfl rfl ⟨rfl,rfl,rfl,rfl,Or.inr (Or.inl rfl)⟩ dep_reject

theorem dep_raw_err_step (σ : PathEnv) : Step depP depB σ depCall none
    (.error ["trap"] [] Store.empty) := by
  apply Step.E_ExternalErr rfl (show depP.externalFunction f = some depDecl from rfl)
    (show depB.externalResponse f [] [five] (.err "trap") [] from
      ⟨rfl,rfl,rfl,rfl,Or.inr (Or.inr rfl)⟩)
  rw [externalReceive_of_args dep_arguments]
  rfl

theorem dep_step_accept (σ : PathEnv) :
    step depP depB σ (fun _ _ _ _ => (.err "unused",[])) (fun _ _ _ => (.val seven,[]))
      (fun _ => none) (fun _ => 0) depCall =
      some (none,.run (.pure (.ret seven)) [] Store.empty) := by
  change (match externalReceive depP depDecl [] [five] (.val seven) with
    | some (.val v) => some (none, State.run (Closure.pure (.ret v)) [] Store.empty)
    | some (.err r) => some (none, State.error [r] [] Store.empty)
    | _ => none) = _
  rw [externalReceive_of_args dep_arguments]
  simp [externalCheckedOutcome,dep_accept]

theorem dep_step_reject (σ : PathEnv) :
    step depP depB σ (fun _ _ _ _ => (.err "unused",[])) (fun _ _ _ => (.val three,[]))
      (fun _ => none) (fun _ => 0) depCall =
      some (none,.error ["ExternalRefinement"] [] Store.empty) := by
  change (match externalReceive depP depDecl [] [five] (.val three) with
    | some (.val v) => some (none, State.run (Closure.pure (.ret v)) [] Store.empty)
    | some (.err r) => some (none, State.error [r] [] Store.empty)
    | _ => none) = _
  rw [externalReceive_of_args dep_arguments,externalCheckedOutcome_reject dep_reject]

theorem dep_step_raw_err (σ : PathEnv) :
    step depP depB σ (fun _ _ _ _ => (.err "unused",[])) (fun _ _ _ => (.err "trap",[]))
      (fun _ => none) (fun _ => 0) depCall =
      some (none,.error ["trap"] [] Store.empty) := by
  change (match externalReceive depP depDecl [] [five] (.err "trap") with
    | some (.val v) => some (none, State.run (Closure.pure (.ret v)) [] Store.empty)
    | some (.err r) => some (none, State.error [r] [] Store.empty)
    | _ => none) = _
  rw [externalReceive_of_args dep_arguments]
  rfl

/-- 二つの実引数の順序と、selfの下のde Bruijnの番号を保つ。 -/
def twoTel : Tel := .param "x" scalar (.param "y" scalar
  (.done (.refined scalar (.and (.le (.var 2) (.var 0)) (.le (.var 0) (.var 1)))) Eff.empty))
theorem two_instantiate : Tel.instantiate twoTel [five,three] =
    some (.refined scalar (.and (.le (.integer 5) (.var 0)) (.le (.var 0) (.integer 3))),Eff.empty) := by
  simp [twoTel,scalar,five,three,Tel.instantiate,Tel.bind,Tel.rawBind,
    Tel.norm,Ty.rawBind,Ty.norm,Eff.rawBind,Eff.norm,Eff.empty,rowFails,rawBindTys,Ty.normTys,
    instAtoms_nil,substAtoms_nil,predBind,upValues,termBind,termBind?,Tel.argumentsEnv,valEnv,Val.toTerm?]

end Dependent

end
end Benitoite.Release.Refinement.LeafReceiveBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if name.toString.startsWith "Benitoite.Release.Refinement.LeafReceiveBoundary.Dependent." then
      some name else none).mergeSort (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
