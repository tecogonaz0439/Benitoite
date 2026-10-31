import Lean
import Benitoite.Release.Refinement.DependentBeta
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.DependentBetaBoundary
noncomputable section

abbrev I : Ty := .base .integer
def equalArg : Pred := .eq (.var 0) (.var 1)
def result : Ty := .refined I equalArg
def effect : Eff := Eff.singleFail result
def signature : Tel := .param "x" I (.done result effect)
def body : Comp := .ret (.var 0)
def sevenN : Integer64Value := ⟨7,by decide⟩
def seven : Val := .const (.integer sevenN)
def sevenFact : Pred := .eq (.var 0) (.integer 7)
def result7 : Ty := .refined I sevenFact
def effect7 : Eff := Eff.singleFail result7

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }

macro "ann" : tactic => `(tactic| simp [Ty.Annotation,I,equalArg,result,effect,signature,
  sevenFact,result7,effect7,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,
  Term.VarsIn,Ty.Sorted,sortedTys,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
  Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,declaredTys,declaredEff,
  Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Eff.singleFail,
  Ty.norm,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,
  Eff.norm,Eff.empty,Eff.WF,Eff.Canonical,sortedEff,Ty.normTys,Order.sortUnique,Tel.WF,Tel.Sorted,Tel.Declared,Pred.ofConjuncts])

theorem signature_ann : Ty.Annotation P [] [] (.dependentFn signature) := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem result7_ann : Ty.Annotation P [] [] result7 := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem signature_normal : signature.Normal := by rfl

theorem body_typed : HasTypeC P B StoreTy.empty [] (Ctx.extend [] I) [] (some result)
    body result effect := by
  have hv : HasTypeV P B StoreTy.empty [] (Ctx.extend [] I) [] (.var 0) result := by
    refine .V_Refine (.V_Var rfl (by trivial)) (sort := .integer) rfl rfl ?_ ?_ ?_ trivial ?_
    · exact signature_ann.sorted.2.1.2
    · exact signature_ann.wf.2.1.2.1
    · exact .eq_refl
    · exact signature_ann.declared.2.1.2
  apply HasTypeCQ.C_Eff (.C_Return hv)
  exact ⟨(by intro a ha; cases ha), (by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩

theorem seven_typed : HasTypeV P B StoreTy.empty [] [] [] seven I := .V_Const trivial

theorem seven_ground : seven.Ground := groundVal_ground (by rfl : groundVal seven = true)

theorem concrete_result : substTyValues (openValue seven) result = result7 := by rfl
theorem concrete_effect : substEffValues (openValue seven) effect = effect7 := by
  exact substEffValues_singleFail result (openValue seven)

theorem sub_refl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩

def failHandler : List Clause := [.fail result7 (.ret seven)]
def continuation : Cont := [.handleF Capture.empty failHandler]

theorem fail_clause (Ψ : StoreTy := StoreTy.empty) : HasFailureClause P B Ψ Qempty [] [] []
    result7 none failHandler I Eff.empty [] := by
  refine .one result7_ann ⟨trivial,trivial,trivial⟩ ?_ ?_
  · intro e he; cases List.mem_singleton.mp he
    exact ⟨⟨⟨rfl,by decide⟩,trivial,trivial,trivial,rfl⟩,⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩
  · exact .C_Return (.V_Const trivial)

theorem handler_cont (σ : PathEnv) (Ψ : StoreTy := StoreTy.empty) : ContTy P B σ Ψ none effect7
    continuation result7 I Eff.empty none := by
  apply ContTy.K_Sub (a' := I)
  · refine .K_Handle_Fail (ec := Eff.empty) (rest := Eff.empty) (E := result7)
      (.K_Empty (sub_refl _) ⟨trivial,trivial,trivial⟩) (Eff.Covers.refl [] [] _)
      ⟨rfl,by intro i hi; cases hi⟩ (CaptureOk.empty P B _ _) (fail_clause (hideBuilders Ψ)) rfl ?_ ?_ ?_
      (by intros; contradiction) (Eff.Covers.refl [] [] _) ⟨trivial,trivial,trivial⟩ ?_
    · rfl
    · exact Eff.subst_values_empty _
    · exact (Ty.subst_values_of_wf_zero result7_ann.wf _).trans (by rfl)
    · trivial
  · exact .forget

theorem continuation_closed : continuation.Closed := by
  intro f hf; cases List.mem_singleton.mp hf
  exact ⟨trivial,⟨result7_ann.wf,trivial,trivial⟩⟩

theorem effect_is_concrete : effect7 ≠ effect := by
  intro h
  have he := congrArg Eff.fails h
  have he := Ty.refined.inj (List.cons.inj he).1
  have he := Pred.eq.inj he.2
  cases he.2

def start : State := .run (Closure.pure (.app (.dependentLam signature body) [seven]))
  continuation Store.empty
def reached : State := .run ((Closure.pure body).apply [seven]) (markPush continuation) Store.empty

theorem substitution_assumptions : Builtins.SubstitutionAssumptions P B := by
  constructor <;> constructor
  · intros; trivial
  · intro b sg C Γ Δ ts ξ hs; cases hs
  · intros; trivial
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hs; cases hs
  · intros; trivial
  · intro b sg C C' Γ Δ ts ρ hs; cases hs
  · intros; trivial
  · intro b sg C0 C1 ts ts' es' hs; cases hs

/-- 結論の型付けを入力にせず、実際の依存βの両側を構成する。 -/
theorem beta_states (σ : PathEnv) (hσ : σ.Valid) :
    StateTy P B σ start ∧ Step P B σ start none reached ∧ StateTy P B σ reached := by
  exact StateTy.dependent_beta_one (Ψ := StoreTy.empty) substitution_assumptions.toValueAssumptions
    signature_ann signature_normal body_typed seven_typed
    seven_ground rfl (StoreOk.empty P B σ) (by intros; contradiction) (handler_cont σ) (by rw [concrete_effect]; exact sub_refl effect7)
    trivial trivial (by change 0 < 1; decide) continuation_closed (by intro l c hc; cases hc)
    hσ ⟨rfl,by intro a ha; cases ha⟩

/-- 到達した閉包が読む実際の return 値を、結果の具体化の後で型付ける。 -/
theorem returned_typed : HasTypeV P B StoreTy.empty [] [] []
    (closeVal (Capture.empty.extend seven) (.var 0)) result7 := by
  have hb := body_typed.open_one substitution_assumptions StoreTy.WF.empty
    (show Ty.Annotation P [] [] I from ⟨trivial,trivial,trivial⟩) (by simp [Ctx.WF]) seven_typed
  exact hb.ret_value rfl

theorem reached_view : ((Closure.pure body).apply [seven]).view = .ret seven := rfl

theorem returned_fact : Entails [] (.eq (.integer 7) (.integer 7)) := by
  exact returned_typed.facts rfl sevenFact (by change sevenFact ∈ [sevenFact]; simp)

theorem no_wrong_fact : ¬ Entails [] (.eq (.integer 7) (.integer 8)) := by
  intro h
  have h := h.sound (fun _ => none) (by simp)
  change false = true at h
  cases h

theorem no_false : ¬ Entails [] .falsity := by
  intro h
  have h := h.sound (fun _ => none) (by simp)
  cases h

theorem wrong_result_untyped : ¬ HasTypeV P B StoreTy.empty [] [] [] seven
    (.refined I (.eq (.var 0) (.integer 8))) := by
  intro h
  exact no_wrong_fact (h.facts rfl (.eq (.var 0) (.integer 8)) (by change _ ∈ [_]; simp))


def pathEnv : PathEnv := ⟨[],[],[],none,none,none⟩
theorem pathEnv_valid : pathEnv.Valid := by decide

theorem concrete_beta_with_fact : StateTy P B pathEnv start ∧
    Step P B pathEnv start none reached ∧ StateTy P B pathEnv reached ∧
    HasTypeV P B StoreTy.empty [] [] [] seven result7 ∧
    Entails [] (.eq (.integer 7) (.integer 7)) := by
  obtain ⟨h0,hs,h1⟩ := beta_states pathEnv pathEnv_valid
  exact ⟨h0,hs,h1,returned_typed,returned_fact⟩

namespace Received

def f : ExternalFunctionId := .mk 14
def decl : ExternalSignature := ⟨.mk 0,"seven",[],[],.done result7 Eff.empty,[]⟩
def program : Program := { P with externals := [(.function f,.function f decl)] }
def builtins : Builtins :=
  { B with externalResponse := fun _ _ _ out obs => out = .val seven ∧ obs = [] }

theorem result_ann : Ty.Annotation program [] [] result7 := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem declaration_wf : decl.WF program := by
  refine ⟨rfl,rfl,?_,?_,?_,by simp [decl],?_⟩
  · exact ⟨⟨result_ann.wf,trivial,rfl⟩,⟨result_ann.sorted,trivial⟩,
      ⟨result_ann.declared,trivial⟩⟩
  · exact ⟨⟨trivial,by simp [Ty.NotContCore,Ty.core]⟩,trivial⟩
  · intro use
    constructor
    · simp [decl]
    · intro h
      cases h with
      | result h => cases h with | refined h => cases h
  · exact .done (.refined (.scalar trivial)) rfl

theorem table_wf : program.ExternalWF := by
  refine ⟨by decide,?_⟩
  intro key decl' hm
  cases List.mem_singleton.mp hm
  exact ⟨rfl,declaration_wf⟩

theorem lookup : program.externalFunction f = some decl := rfl

theorem bind_signature : Tel.bind (typeEnv []) decl.parameters = .done result7 Eff.empty := by
  simp [decl,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,Eff.rawBind,Eff.norm,
    result7,sevenFact,I,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Eff.empty,rowFails,rawBindTys,Ty.normTys,typeEnv,
    typeEnvAt,instAtoms_nil,substAtoms_nil,predBind,upValues,termBind,termBind?]

theorem args_result {Ψ ts vs a e} (ha : ExternalArgs program builtins Ψ decl ts vs a e) :
    ts = [] ∧ vs = [] ∧ a = result7 ∧ e = Eff.empty := by
  have hts : ts = [] := List.eq_nil_of_length_eq_zero ha.admissible.count
  subst ts
  have hs := ha.arguments
  rw [bind_signature] at hs
  cases hs
  exact ⟨rfl,rfl,rfl,rfl⟩

theorem external_assumptions : Builtins.ExternalAssumptions program builtins := by
  constructor
  · intro Ψ f' d ts vs a e out obs _ hd ha hr
    have hd' : d = decl := by
      by_cases hf : f = f'
      · subst f'
        exact (Option.some.inj hd).symm
      · have hk : (ExternalKey.function f' == ExternalKey.function f) = false := by
          change decide (ExternalKey.function f' = ExternalKey.function f) = false
          simp [Ne.symm hf]
        simp only [program,Program.externalFunction,List.lookup_cons,List.lookup_nil,hk] at hd
        cases hd
    subst d
    obtain ⟨_,_,rfl,_⟩ := args_result ha
    rcases hr with ⟨rfl,_⟩
    exact ⟨⟨.refined (.scalar (.V_Const trivial)) result_ann,seven_ground⟩,
      fun n hn => by cases hn⟩
  · intro Ψ f' d ts vs a e _ _ _
    exact ⟨.val seven,[],rfl,rfl⟩
  · intro Ψ f' d ts vs a e out obs _ _ _ hr
    exact hr.2

theorem arguments : ExternalArgs program builtins StoreTy.empty decl [] [] result7 Eff.empty := by
  refine ⟨?_,?_,by simp,by simp,⟨result_ann.wf,by rfl⟩,⟨trivial,rfl⟩⟩
  · exact ⟨rfl,⟨rfl,[],rfl,by intros; contradiction⟩,
      ⟨rfl,by intros; contradiction⟩,by simp [TypeAnnotations]⟩
  · rw [bind_signature]
    exact .done ⟨⟨result_ann.wf,trivial,rfl⟩,⟨result_ann.sorted,trivial⟩,
      ⟨result_ann.declared,trivial⟩⟩

theorem receive_success : externalReceive program decl [] [] (.val seven) = some (.val seven) := by
  rw [externalReceive_of_args arguments]
  simp only [externalCheckedOutcome]
  have h : externalCheck program seven result7 = true := by cbv
  simp [h]

theorem received_original_type : HasTypeV program builtins StoreTy.empty [] [] [] seven result7 ∧
    seven.Ground ∧ seven.Adequate pathEnv ∧ ∀ p ∈ result7.assume,
      Entails [] (p.open (.integer 7)) :=
  external_assumptions.received_facts table_wf lookup arguments ⟨rfl,rfl⟩
    receive_success pathEnv rfl

theorem received_step : Step program builtins pathEnv
    (.run (Closure.pure (.externalCall f [] [])) [] Store.empty) none
    (.run (Closure.pure (.ret seven)) [] Store.empty) :=
  .E_External rfl lookup ⟨rfl,rfl⟩ receive_success

theorem received_leaf : Entails [] (.eq (.integer 7) (.integer 7)) :=
  received_original_type.2.2.2 sevenFact (by change sevenFact ∈ [sevenFact]; simp)

/-- 同じcarrierでも誤った篩を付ける応答は受信検査で拒まれる。 -/
theorem wrong_carrier : Outcome.Carrier program builtins StoreTy.empty (.val seven)
    (.refined I (.eq (.var 0) (.integer 8))) :=
  ⟨.refined (.scalar (.V_Const trivial)) ⟨by ann,by ann,by ann⟩,seven_ground⟩

theorem wrong_received : externalCheckedOutcome program (.refined I (.eq (.var 0) (.integer 8)))
    (.val seven) = .err "ExternalRefinement" := by
  apply externalCheckedOutcome_reject
  cbv

end Received

namespace Review

def builderTypes : StoreTy := fun l => if l = 0 then some (.builder .string) else none
def builderStore : Store := Store.empty.set 0 (.builder (.string ""))

theorem builder_not_hidden : hideBuilders builderTypes ≠ builderTypes := by
  intro h
  have := congrFun h 0
  cases this

theorem builder_store_ok (σ : PathEnv) : StoreOk P B σ builderTypes builderStore := by
  refine ⟨⟨1,?_⟩,?_,?_,?_,?_⟩
  · intro l hl
    simp [builderStore,Store.set,Store.empty,show l ≠ 0 by omega]
  · intro l t ht
    by_cases hl : l = 0
    · subst l; cases Option.some.inj ht; trivial
    · simp [builderTypes,hl] at ht
  · intro l t ht
    by_cases hl : l = 0
    · subst l; cases Option.some.inj ht; trivial
    · simp [builderTypes,hl] at ht
  · intro l t ht
    by_cases hl : l = 0
    · subst l; simp [builderStore,Store.set]
    · simp [builderTypes,hl] at ht
  · intro l c hc
    by_cases hl : l = 0
    · subst l
      have he : c = .builder (.string "") := (Option.some.inj hc).symm
      subst c
      exact ⟨.string,rfl,⟨by decide,trivial⟩,trivial⟩
    · simp [builderStore,Store.set,Store.empty,hl] at hc

theorem builder_store_closed : builderStore.Closed := by
  intro l c hc
  by_cases hl : l = 0
  · subst l; cases Option.some.inj hc; trivial
  · simp [builderStore,Store.set,Store.empty,hl] at hc

/-- builder を実際に持つ状態にも一般化した代表を使える。 -/
theorem beta_with_builder :
    let q := Closure.pure (.app (.dependentLam signature body) [seven])
    StateTy P B pathEnv (.run q continuation builderStore) ∧
    Step P B pathEnv (.run q continuation builderStore) none
      (.run ((Closure.pure body).apply [seven]) (markPush continuation) builderStore) ∧
    StateTy P B pathEnv
      (.run ((Closure.pure body).apply [seven]) (markPush continuation) builderStore) := by
  have hb : HasTypeC P B (hideBuilders builderTypes) [] (Ctx.extend [] I) []
      (some result) body result effect := by
    have he : hideBuilders builderTypes = StoreTy.empty := by
      funext l
      by_cases hl : l = 0 <;> simp [builderTypes,hideBuilders,hl,StoreTy.empty]
    rw [he]; exact body_typed
  exact StateTy.dependent_beta_one (Ψ := builderTypes) substitution_assumptions.toValueAssumptions
    signature_ann signature_normal hb (.V_Const trivial) seven_ground rfl
    (builder_store_ok pathEnv) (by intros; contradiction) (handler_cont pathEnv builderTypes)
    (by rw [concrete_effect]; exact sub_refl effect7) trivial trivial
    (by change 0 < 1; decide) continuation_closed builder_store_closed
    pathEnv_valid ⟨rfl,by intro a ha; cases ha⟩

/-- R=some の開始と既存の mark を同時構成し、markPush は併合する。 -/
theorem beta_with_existing_mark :
    let q := Closure.pure (.app (.dependentLam signature body) [seven])
    StateTy P B pathEnv (.run q (.mark :: continuation) Store.empty) ∧
    Step P B pathEnv (.run q (.mark :: continuation) Store.empty) none
      (.run ((Closure.pure body).apply [seven]) (.mark :: continuation) Store.empty) ∧
    StateTy P B pathEnv (.run ((Closure.pure body).apply [seven]) (.mark :: continuation) Store.empty) := by
  have hR : ∀ r, some result7 = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal := by
    intro r hr; cases hr
    exact ⟨result7_ann.wf,result7_ann.declared,by rfl⟩
  exact StateTy.dependent_beta_one (Ψ := StoreTy.empty) substitution_assumptions.toValueAssumptions
    signature_ann signature_normal body_typed seven_typed seven_ground rfl
    (StoreOk.empty P B pathEnv) hR (.K_Mark (handler_cont pathEnv) result7_ann)
    (by rw [concrete_effect]; exact sub_refl effect7) trivial trivial
    (by change 0 < 1; decide)
    (by intro f hf; rcases List.mem_cons.mp hf with rfl | hf; trivial; exact continuation_closed f hf)
    (by intro l c hc; cases hc) pathEnv_valid ⟨rfl,by intro a ha; cases ha⟩

def capturedΓ : Ctx := Ctx.extend [] I
def capturedCap : Capture := Capture.empty.extend seven
def capturedA : Ty := .refined I (.eq (.var 0) (.var 2))
def capturedTel : Tel := .param "y" I (.done capturedA Eff.empty)
def capturedCode : Comp := .ret (.var 1)

theorem captured_ok : CaptureOk P B (hideBuilders StoreTy.empty) none capturedΓ [] capturedCap := by
  exact (CaptureOk.empty P B _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) seven_ground

theorem captured_ann : Ty.Annotation P [] (hideConts capturedΓ) (.dependentFn capturedTel) := by
  simp only [capturedTel,capturedA,capturedΓ,hideConts]
  refine ⟨?_,?_,?_⟩ <;> ann

theorem captured_body : TelBodyTy P B (hideBuilders StoreTy.empty) Qempty []
    (hideConts capturedΓ) [] capturedTel capturedCode := by
  refine .param (.done (.C_Return ?_))
  refine .V_Refine (.V_Var rfl (by trivial)) (sort := .integer) rfl rfl ?_ ?_ ?_ trivial ?_
  · exact captured_ann.sorted.2.1.2
  · exact captured_ann.wf.2.1.2.1
  · exact .eq_refl
  · exact captured_ann.declared.2.1.2

/-- 捕捉の R と本体が使う hideConts Γ の移送を、本番の補題で使う。 -/
theorem captured_hidden : CaptureOk P B (hideBuilders StoreTy.empty) (some result7)
    (hideConts capturedΓ) [] capturedCap := captured_ok.hideConts_any

theorem captured_application : ClosureTy P B StoreTy.empty [] (some result7)
    (.mk (capturedCap.extend seven) capturedCode) result7 Eff.empty := by
  have h := ClosureTy.closure_one substitution_assumptions.toValueAssumptions StoreTy.WF.empty
    captured_ok captured_body captured_ann
      (show HasTypeV P B StoreTy.empty [] [] [] seven (capturedCap.closeTy I) from .V_Const trivial)
      seven_ground
  have he : (capturedCap.extend seven).closeTy capturedA = result7 := rfl
  rw [he] at h
  simpa only [Capture.closeEff,Eff.subst_values_empty] using h

theorem captured_step : Step P B pathEnv
    (.run (Closure.pure (.app (.closure (capturedCap.closeTel capturedTel)
      (.mk capturedCap capturedCode)) [seven])) [] Store.empty) none
    (.run (.mk (capturedCap.extend seven) capturedCode) [.mark] Store.empty) := by
  apply Step.E_Lam (signature := capturedCap.closeTel capturedTel)
    (body := .mk capturedCap capturedCode) (ws := [seven])
  · rfl
  · rfl

end Review

end
end Benitoite.Release.Refinement.DependentBetaBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "DependentBetaBoundary").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
