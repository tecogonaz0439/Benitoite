import Benitoite

namespace Benitoite.Release.Refinement.CaptureLambda
noncomputable section

def U : Ty := .base .unit
def E : Eff := Eff.empty
def F : Ty := .fn [] [] U E
def raw : Val := .lam [] [] (.ret (.const .unit))
def cap : Capture := Capture.empty.extend raw
def code : Comp := .app (.var 0) []
def q : Closure := .mk cap code
def s : State := .run q [] Store.empty

theorem ann (P : Program) : Ty.Annotation P [] [] F := by
  constructor <;> simp [F,U,E,Ty.WF,Ty.Sorted,Ty.Declared,Ty.WFList,NamesWF,Eff.WF,
    Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,sortedTys,sortedEff,declaredTys,declaredEff]

theorem raw_typed (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] [] raw F := by
  exact .V_Lam (ann P).wf.1 (ann P).wf (ann P).sorted
    (.C_Return (.V_Const trivial)) (ann P).declared

theorem capture (P : Program) (B : Builtins) :
    CaptureOk P B StoreTy.empty none (Ctx.extend [] F) [] cap := by
  have he : Capture.empty.closeTy F = F :=
    (Ty.subst_values_of_wf_zero (ann P).wf _).trans rfl
  have ht : HasTypeV P B StoreTy.empty [] [] [] raw (Capture.empty.closeTy F) := he.symm ▸ raw_typed P B
  have hc := (CaptureOk.empty P B StoreTy.empty none).extend (ann P) ht
    (by simp [raw,Val.Ground,Val.ClosedAt,Comp.ClosedAt,NamesWF])
  simpa [cap] using hc

theorem body (P : Program) (B : Builtins) :
    HasTypeC P B StoreTy.empty [] (Ctx.extend [] F) [] none code U E := by
  apply HasTypeCQ.C_App (ns := []) (as := [])
  · apply HasTypeVQ.V_Var (a := F)
    · rfl
    · trivial
  · exact .nil

theorem closure (P : Program) (B : Builtins) :
    ClosureTy P B StoreTy.empty [] none q U E := by
  have ha : Ty.Annotation P [] (Ctx.extend [] F) (.dependentFn (.done U E)) := by
    constructor <;> simp [U,E,Ty.WF,Tel.WF,Tel.Sorted,Tel.Declared,Ty.Sorted,Ty.Declared,Eff.WF,Eff.empty,Eff.Canonical,
      Eff.norm,Ty.normTys,sortedEff,declaredEff,Ty.WFList,sortedTys,declaredTys]
  have h := ClosureTy.capture (capture P B) (body P B) ha rfl (by intro r hr; cases hr)
  have hu : cap.closeTy U = U := rfl
  have he : cap.closeEff E = E := cap.closeEff_empty
  rw [hu,he] at h
  exact h

theorem view : q.view = .app raw [] := rfl

theorem state (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ E s := by
  refine ⟨StoreTy.empty,none,U,U,E,E,StoreOk.empty P B σ,closure P B,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩ ?_,?_,?_,?_,?_⟩
  · exact ⟨trivial,trivial,trivial⟩
  · simp [q,cap,raw,code,Closure.Adequate,Capture.Adequate,Capture.extend,Capture.empty,
      Capture.values,Val.Adequate,Comp.Adequate,adequateCaptureSlots,adequateVals]
  · simp [q,cap,raw,code,Closure.ClosedAt,Capture.Closed,Capture.extend,Capture.empty,
      Capture.values,Val.ClosedAt,Comp.ClosedAt,Val.ClosedList,captureSlotsClosed,NamesWF]
  · intro f hf; cases hf
  · intro l c hc; cases hc

/-- ソースに直接書いたlambdaはcloseValによりclosureになる。 -/
theorem direct_lambda_closes :
    closeVal Capture.empty raw =
      .closure (Capture.empty.closeTel (lambdaShape [] []))
        (.mk Capture.empty (.ret (.const .unit))) := rfl

/-- 捕捉した同じlambdaは変数の射影では変換されない。 -/
theorem captured_lambda_remains : closeVal cap (.var 0) = raw := rfl

theorem no_runtime_closure :
    ¬ ∃ runtime body ws, q.view = .app (.closure runtime body) ws := by
  rintro ⟨runtime,body,ws,hv⟩
  rw [view] at hv
  cases hv

theorem stateTy (P : Program) (B : Builtins) {σ : PathEnv} (valid : σ.Valid) :
    StateTy P B σ s := by
  refine ⟨valid,E,?_,state P B σ⟩
  constructor
  · rfl
  · intro a ha
    have hn : ¬ Eff.mem E a := by
      cases a <;> simp [E,Eff.empty,Eff.mem,Eff.test,Eff.atoms]
    exact (hn ha).elim

/-- 閉じたappの共通入力は得られるが、実行時のclosureの形は得られない。 -/
theorem formed_application (P : Program) (B : Builtins) (σ : PathEnv)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    ∃ Ψ t r ef, HasTypeVQ P B Ψ Qempty [] [] [] raw (.dependentFn t) ∧
      Ty.Annotation P [] [] (.dependentFn t) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] [] t r ef := by
  obtain ⟨Ψ,_,_,_,t,r,ef,_,_,hf,ha,args,_,_⟩ :=
    (state P B σ).app_inputs hP hPB hB view
  exact ⟨Ψ,t,r,ef,hf,ha,args⟩

theorem no_step {P B σ event dest} : ¬ Step P B σ s event dest := by
  intro h
  cases h <;> simp_all [raw,q,code,Closure.view,cap,closeVal,Capture.env,
    Capture.extend,Capture.empty,Capture.values,Closure.code,Closure.capture,closeVals]

end
end Benitoite.Release.Refinement.CaptureLambda
