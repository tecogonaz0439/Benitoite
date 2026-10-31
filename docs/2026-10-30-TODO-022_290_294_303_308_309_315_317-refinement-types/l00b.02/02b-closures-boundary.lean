import Lean
import Benitoite

namespace Benitoite.Release.Refinement.ClosureBoundary
noncomputable section

def scalar : Ty := .base .integer8
def seven : Val := .const (.integer8 7)
def refinement : Pred := .eq (.var 0) (.integer 7)
def refined : Ty := .refined scalar refinement
def capturedΓ : Ctx := [none,some refined]
def capturedΦ : List Pred := [.eq (.var 1) (.integer 7)]
def capture : Capture := .mk [none,some seven]

theorem scalar_annotation (P : Program) (C : List TParam) (Γ : Ctx) : Ty.Annotation P C Γ scalar :=
  ⟨trivial,trivial,trivial⟩

theorem seven_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] seven refined := by
  refine .V_Refine (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)) rfl rfl ?_ ?_ ?_ trivial ?_
  · exact ⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨trivial,rfl⟩⟩
  · simp [refinement,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · exact .eq_refl
  · exact ⟨⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩,trivial⟩

theorem capture_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none capturedΓ capturedΦ capture := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi
    cases i with
    | zero => cases hi
    | succ i => cases i with
      | zero => cases hi; simp [refined,scalar,refinement,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,capturedΓ]
      | succ i => simp [capturedΓ] at hi
  · intro i a hi
    cases i with
    | zero => cases hi
    | succ i => cases i with
      | zero => exact ⟨seven,rfl⟩
      | succ i => simp [capturedΓ] at hi
  · intro i a hi
    cases i with
    | zero => cases hi
    | succ i => cases i with
      | zero =>
        cases hi
        exact ⟨⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨trivial,rfl⟩⟩⟩,
          trivial,⟨⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩,trivial⟩⟩
      | succ i => simp [capturedΓ] at hi
  · intro p hp
    have he : p = .eq (.var 1) (.integer 7) := List.mem_singleton.mp hp
    subst p
    refine ⟨by simp [capturedΓ,Pred.WF,Pred.VarsIn,Term.VarsIn], ?_, ?_⟩
    · exact ⟨⟨⟨refined,rfl,by simp [refined]⟩,refined,rfl,rfl⟩,⟨trivial,rfl⟩⟩
    · exact ⟨⟨refined,rfl,by simp [refined]⟩,trivial⟩
  · intro ov ho v hv
    simp [capture,Capture.values] at ho
    rcases ho with rfl | rfl
    · cases hv
    · cases hv; trivial
  · intro i a hi
    cases i with
    | zero => cases hi
    | succ i => cases i with
      | zero =>
        cases hi
        refine .ordinary (by simp [refined]) ?_
        simpa [capture,Capture.env,Capture.values,seven,substTyValues,refined,scalar,refinement,Ty.bind,Ty.rawBind,Ty.norm,
          predBind,upValues,termBind,termBind?] using seven_typed P B Ψ
      | succ i => simp [capturedΓ] at hi
  · intro p hp
    have he : p = .eq (.var 1) (.integer 7) := by
      simpa [capturedΓ,capturedΦ,Ctx.facts,refined,scalar,refinement,Ty.assume,Pred.open,predBind,termBind,termBind?,openingEnv] using hp
    subst p
    exact .eq_refl

/-- Noneの位置にはFailの継続場所が残ってもよい。型付き像としては読まない。 -/
theorem masked_capture (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none [none] [] (.mk [some (.loc 0)]) := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; cases i <;> simp at hi
  · intro i a hi; cases i <;> simp at hi
  · intro i a hi; cases i <;> simp at hi
  · intro p hp; cases hp
  · intro ov ho v hv
    have he : ov=some (.loc 0) := List.mem_singleton.mp ho
    rw [he] at hv
    cases hv
    trivial
  · intro i a hi; cases i <;> simp at hi
  · intro p hp
    simp [Ctx.facts] at hp

/-- Noneを詰めず、捕捉した述語を閉じる。 -/
theorem captured_fact (P : Program) (B : Builtins) (Ψ : StoreTy) :
    Entails [] (predBind (valEnv capture.env).values (.eq (.var 1) (.integer 7))) :=
  (capture_typed P B Ψ).conditions _ (List.mem_append_right _ (by simp [capturedΦ]))

def dependent : Tel := .param "x" scalar (.done (.refined scalar (.eq (.var 0) (.var 1))) Eff.empty)

theorem dependent_annotation (P : Program) : Ty.Annotation P [] capturedΓ (.dependentFn dependent) := by
  refine ⟨by simp [dependent,scalar,Ty.WF,Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,capturedΓ,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.WFList], ?_, ?_⟩
  · exact ⟨trivial,⟨⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,
      ⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,trivial⟩⟩
  · exact ⟨trivial,⟨⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,
      ⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩,trivial⟩⟩

theorem dependent_body (P : Program) (B : Builtins) (Ψ : StoreTy) :
    TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts capturedΓ) capturedΦ dependent (.ret (.var 0)) := by
  apply TelBodyTy.param
  apply TelBodyTy.done
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Var rfl (by simp [scalar])) rfl rfl ?_ ?_ ?_ trivial ?_
  · exact ⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,
      ⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩
  · simp [Pred.WF,Pred.VarsIn,Term.VarsIn,capturedΓ,Ctx.extend,hideConts]
  · exact .eq_refl
  · exact ⟨⟨scalar,rfl,by simp [scalar]⟩,
      ⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩

theorem dependent_lambda (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] capturedΓ capturedΦ (.dependentLam dependent (.ret (.var 0))) (.dependentFn dependent) :=
  .V_DependentLam (dependent_annotation P) (dependent_body P B Ψ)

/-- 逆向きの補題で依存する結果を構成する。 -/
theorem dependent_arguments (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeTelArgs P B Ψ [] capturedΓ capturedΦ [seven] dependent
      (.refined scalar (.eq (.var 0) (.integer 7))) Eff.empty := by
  apply HasTypeTelArgsQ.of_arguments (as := [scalar])
  · simp [dependent,Tel.arguments,Tel.bind,Tel.rawBind,Tel.norm,scalar,Ty.rawBind,Ty.norm,
      Eff.rawBind,Eff.norm,Eff.empty,rawBindTys,rowFails,substAtoms_nil,instAtoms_nil,
      Tel.argumentsEnv,valEnv,seven,Val.toTerm?,predBind,upValues,termBind,termBind?]
  · exact .cons (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)) .nil
  · exact dependent_annotation P
  · exact (capture_typed P B Ψ).wf

theorem dependent_call (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeC P B Ψ [] capturedΓ capturedΦ none
      (.app (.dependentLam dependent (.ret (.var 0))) [seven])
      (.refined scalar (.eq (.var 0) (.integer 7))) Eff.empty :=
  .C_DependentApp (dependent_lambda P B Ψ) (dependent_arguments P B Ψ)

theorem closed_closure (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] (.closure (capture.closeTel dependent) (.mk capture (.ret (.var 0))))
      (.dependentFn (capture.closeTel dependent)) := by
  have ha0 := (capture_typed P B Ψ).substOk.annotation (dependent_annotation P)
  have ha : Ty.Annotation P [] [] (.dependentFn (capture.closeTel dependent)) := by
    simpa only [substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Capture.closeTel,Tel.bind] using ha0
  refine .V_Closure ha ⟨ha.wf,ha.wf,Tel.SameInputs.refl _⟩ ?_
  exact .mk (capture_typed P B (hideBuilders Ψ)) (dependent_body P B Ψ)
    (dependent_annotation P) ha

theorem dependent_capture_subst (P : Program) (B : Builtins) (Ψ : StoreTy)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeV P B Ψ [] [] []
      ((Val.dependentLam dependent (.ret (.var 0))).subst capture.env)
      (substTyValues capture.env (.dependentFn dependent)) := by
  have hc := capture_typed P B Ψ
  exact (dependent_lambda P B Ψ).subst hA hw hc.substOk
    (fun p hp => hc.conditions p (List.mem_append_right _ hp))

theorem dependent_lam_step (P : Program) (B : Builtins) (σ : PathEnv) (k : Cont) (μ : Store) :
    Step P B σ
      (.run (Closure.pure (.app (.closure (capture.closeTel dependent) (.mk capture (.ret (.var 0)))) [seven])) k μ)
      none (.run ((Closure.mk capture (.ret (.var 0))).apply [seven]) (markPush k) μ) := by
  apply Step.E_Lam rfl
  simp [Capture.closeTel,Tel.arity,Tel.names_bind,dependent,Tel.names]

/-- 実行用旧lamのUnit終端から、Boolean契約を推測しない。 -/
theorem legacy_shape : (lambdaShape ["x"] [scalar]).SameInputs
    (Ty.toTel ["x"] [scalar] (.base .boolean) Eff.empty) := Tel.SameInputs.toTel _ _ _ _ _ _

theorem legacy_closure (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] []
      (.closure (lambdaShape ["x"] [scalar]) (Closure.pure (.ret (.const (.boolean true)))))
      (.dependentFn (Ty.toTel ["x"] [scalar] (.base .boolean) Eff.empty)) := by
  have hn : NamesWF ["x"] [scalar] := ⟨rfl,by decide⟩
  have ha : Ty.Annotation P [] [] (.dependentFn (Ty.toTel ["x"] [scalar] (.base .boolean) Eff.empty)) :=
    ⟨Tel.wf_toTel hn ⟨trivial,trivial⟩ trivial trivial rfl,⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩
  refine .V_Closure ha ⟨Tel.wf_toTel hn ⟨trivial,trivial⟩ trivial trivial rfl,ha.wf,legacy_shape⟩ ?_
  have hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] [] []
      (Ty.toTel ["x"] [scalar] (.base .boolean) Eff.empty) (.ret (.const (.boolean true))) :=
    (TelBodyTy.toTel_iff hn).mpr (.C_Return (.V_Const trivial))
  have hcap := CaptureOk.empty P B (hideBuilders Ψ) none
  have he : Capture.empty.closeTel (Ty.toTel ["x"] [scalar] (.base .boolean) Eff.empty) =
      Ty.toTel ["x"] [scalar] (.base .boolean) Eff.empty := Tel.bind_values_of_wf_zero ha.wf _
  have hc := DependentClosureTy.mk hcap hb ha (by simpa only [he] using ha)
  simpa only [he,Closure.pure] using hc

theorem captured_beta (P : Program) (B : Builtins) (Ψ : StoreTy) : Tel.instantiate (capture.closeTel dependent) (closeVals capture [seven]) =
    some (capture.closeTy (.refined scalar (.eq (.var 0) (.integer 7))), capture.closeEff Eff.empty) := by
  rw [Capture.closeTel_instantiate_runtime, (dependent_arguments P B Ψ).instantiate]
  rfl

theorem beta_environment (P : Program) (B : Builtins) (Ψ : StoreTy) :
    (capture.extendMany [seven]).closeTy dependent.result =
      capture.closeTy (.refined scalar (.eq (.var 0) (.integer 7))) := by
  have hb := captured_beta P B Ψ
  change Tel.instantiate (capture.closeTel dependent) [seven] = _ at hb
  rw [capture.instantiate dependent [seven] rfl] at hb
  exact congrArg Prod.fst (Option.some.inj hb)

/-- ストアの閉じたWFだけでは宣言されていないdataを排除できない。 -/
def emptyProgram : Program where
  defs _ := none
  cons _ := none
  ops _ := none
  effects _ := none
  classes _ := none
  impls _ := none
def undeclaredStore : StoreTy := fun l => if l=0 then
  some (.cont (.base .unit) (.data "Missing" []) Eff.empty none) else none
def undeclaredHeap : Store := Store.empty.set 0 .used

theorem undeclared_wf : undeclaredStore.WF := by
  intro l x hx
  by_cases hl : l=0
  · subst l
    simp only [undeclaredStore,↓reduceIte,Option.some.injEq] at hx
    subst x
    exact ⟨trivial,trivial,trivial,rfl,by intro a ha; cases ha⟩
  · simp [undeclaredStore,hl] at hx

/-- Declared以外のStoreOkの条件は実際に満たす。否定が別の理由で通ることを防ぐ。 -/
theorem undeclared_prior_conditions (B : Builtins) (σ : PathEnv) :
    (∃ n, ∀ l, n ≤ l → undeclaredHeap l = none) ∧ undeclaredStore.WF ∧
    (∀ l x, undeclaredStore l = some x → undeclaredHeap l ≠ none) ∧
    (∀ l c, undeclaredHeap l = some c → CellOk emptyProgram B σ undeclaredStore l c) := by
  refine ⟨⟨1,?_⟩,undeclared_wf,?_,?_⟩
  · intro l hl
    simp [undeclaredHeap,Store.set,Store.empty,show l ≠ 0 by omega]
  · intro l x hx
    by_cases hl : l=0
    · subst l; simp [undeclaredHeap,Store.set]
    · simp [undeclaredStore,hl] at hx
  · intro l c hc
    by_cases hl : l=0
    · subst l
      simp only [undeclaredHeap,Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      exact ⟨.base .unit,.data "Missing" [],Eff.empty,none,rfl⟩
    · simp [undeclaredHeap,Store.set,Store.empty,hl] at hc

theorem undeclared_not_storeOk (B : Builtins) (σ : PathEnv) (μ : Store) :
    ¬ StoreOk emptyProgram B σ undeclaredStore μ := by
  intro hs
  have hd := hs.cont_result_declared (l := 0) (C := []) (Γ := []) rfl
  obtain ⟨⟨n,hn,_⟩,_⟩ := hd
  obtain ⟨c,cd,hc,_⟩ := hn.1
  change none = some cd at hc
  cases hc

def builderStore : StoreTy := fun l => if l=0 then some (.builder .string) else none
def variableAlt : Alt := ⟨.var,[0]⟩
def guardCode : Comp := .letIn (.builderOp .string .length (.loc 0) []) (.ret (.const (.boolean true)))
def unitCode : Comp := .ret (.const .unit)
def guardedArms : List Arm := [.mk [variableAlt] (some guardCode) unitCode,.mk [variableAlt] none unitCode]

theorem variable_alt (P : Program) : AltsTy P [variableAlt] (.base .unit) [.base .unit] := by
  refine ⟨by simp,rfl,?_,?_⟩
  · intro alt h; cases h; rfl
  · intro alt h
    have he := List.mem_singleton.mp h
    subst alt
    exact ⟨[.base .unit],.P_Var,List.Perm.refl _,rfl⟩

theorem string_kinded (P : Program) : TypeArgsKinded P [] [.base .string] [.value] := by
  refine ⟨rfl,[],rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => cases ha; cases hk; trivial
  | succ i => simp at ha

theorem guard_with_builder (P : Program) (B : Builtins) :
    HasTypeCQ P B builderStore Qempty [] (hideConts (bindParams [] [.base .unit])) (liftMany 1 [])
      none guardCode (.base .boolean) Eff.empty (localExtend 1 []) := by
  refine .C_Let (.C_BuilderOp ⟨trivial,trivial,trivial⟩ (string_kinded P) (.loc (by simp [builderStore])) .nil) ?_ trivial
  exact .C_Return (.V_Const trivial)

theorem guard_frame (P : Program) (B : Builtins) (σ : PathEnv) :
    ContTy P B σ builderStore none Eff.empty
      [.guardF (.const .unit) Capture.empty guardedArms 1 (Closure.pure unitCode)]
      (.base .boolean) (.base .unit) Eff.empty none := by
  have hunit : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have har : HasTypeArmsQ P B builderStore Qempty [] [] [] none guardedArms
      (.base .unit) (.base .unit) Eff.empty [] :=
    .guarded (variable_alt P) (guard_with_builder P B) (.C_Return (.V_Const trivial))
      (.plain (variable_alt P) (.C_Return (.V_Const trivial)) (.nil hunit))
  have hbody : ClosureTy P B builderStore [] none (Closure.pure unitCode) (.base .unit) Eff.empty :=
    .pure (.C_Return (.V_Const trivial)) ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩ (by intros; contradiction)
  refine .K_Guard (CaptureOk.empty P B builderStore none) (.V_Const (c := .unit) trivial) har ⟨trivial,trivial⟩ (by intros; contradiction) ?_
    rfl rfl ?_ ?_ hbody ⟨fun _ h => h,fun _ h => h⟩ ?_
    (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ hunit) ?_
  · intro v hv
    exact ⟨.var,by simp [guardedArms,unguardedPats,variableAlt],by simp [matchVal]⟩
  · exact Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .base .unit) trivial _
  · exact substEffValues_empty _
  · intro arm hm hg
    have he : arm = .mk [variableAlt] (some guardCode) unitCode := by
      simpa only [guardedArms,List.take_succ_cons,List.take_zero,List.mem_cons,List.not_mem_nil,or_false] using hm
    subst arm
    cases hg
  · trivial

/-- 全状態はValidだけを要求し、Readyを前提に加えない。 -/
theorem unit_state (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run (Closure.pure unitCode) [] Store.empty) := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,.base .unit,.base .unit,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,?_,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · exact .pure (.C_Return (.V_Const trivial)) ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩ (by intros; contradiction)
  · trivial
  · trivial
  · intro f hf; cases hf
  · intro l c hc; cases hc

#check ContTy.K_Guard
#check ContTy.K_Handle_Fail
#check StoreOk.cont_result_declared
#check TelBodyTy.subst
#check TelBodyTy.narrow
#check TelBodyTy.shift_values
#check TelBodyTy.shift_types
#check StateTy
#check Step.E_Lam
#check step

end
end Benitoite.Release.Refinement.ClosureBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (n,_) =>
    if (`Benitoite.Release.Refinement.ClosureBoundary).isPrefixOf n then some n else none
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for n in names do
    elabCommand (← `(#print axioms $(mkIdent n)))
