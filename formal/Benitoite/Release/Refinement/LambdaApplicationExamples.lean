import Benitoite.Release.Refinement.ClosureStateLeaves
import Benitoite.Release.Refinement.ApplicationInputs
import Benitoite.Release.Refinement.MatchStateLeaves

namespace Benitoite.Release.Refinement.LambdaApplicationExamples
noncomputable section

private def U : Ty := .base .unit
private def E : Eff := Eff.empty
private def F : Ty := .fn [] [] U E
private def raw : Val := .lam [] [] (.ret (.const .unit))
private def cap : Capture := Capture.empty.extend raw
private def code : Comp := .app (.var 0) []
private def q : Closure := .mk cap code
private def s : State := .run q [] Store.empty

private theorem ann (P : Program) : Ty.Annotation P [] [] F := by
  constructor <;> simp [F,U,E,Ty.WF,Ty.Sorted,Ty.Declared,Ty.WFList,NamesWF,Eff.WF,
    Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,sortedTys,sortedEff,declaredTys,declaredEff]

private theorem raw_typed (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] [] raw F := by
  exact .V_Lam (ann P).wf.1 (ann P).wf (ann P).sorted
    (.C_Return (.V_Const trivial)) (ann P).declared

private theorem capture (P : Program) (B : Builtins) :
    CaptureOk P B StoreTy.empty none (Ctx.extend [] F) [] cap := by
  have he : Capture.empty.closeTy F = F :=
    (Ty.subst_values_of_wf_zero (ann P).wf _).trans rfl
  have ht : HasTypeV P B StoreTy.empty [] [] [] raw (Capture.empty.closeTy F) := he.symm ▸ raw_typed P B
  have hc := (CaptureOk.empty P B StoreTy.empty none).extend (ann P) ht
    (by simp [raw,Val.Ground,Val.ClosedAt,Comp.ClosedAt,NamesWF])
  simpa [cap] using hc

private theorem body (P : Program) (B : Builtins) :
    HasTypeC P B StoreTy.empty [] (Ctx.extend [] F) [] none code U E := by
  apply HasTypeCQ.C_App (ns := []) (as := [])
  · apply HasTypeVQ.V_Var (a := F)
    · rfl
    · trivial
  · exact .nil

private theorem closure (P : Program) (B : Builtins) :
    ClosureTy P B StoreTy.empty [] none q U E := by
  have ha : Ty.Annotation P [] (Ctx.extend [] F) (.dependentFn (.done U E)) := by
    constructor <;> simp [U,E,Ty.WF,Tel.WF,Tel.Sorted,Tel.Declared,Ty.Sorted,Ty.Declared,Eff.WF,Eff.empty,Eff.Canonical,
      Eff.norm,Ty.normTys,sortedEff,declaredEff,Ty.WFList,sortedTys,declaredTys]
  have h := ClosureTy.capture (capture P B) (body P B) ha rfl (by intro r hr; cases hr)
  have hu : cap.closeTy U = U := rfl
  have he : cap.closeEff E = E := cap.closeEff_empty
  rw [hu,he] at h
  exact h

private theorem view : q.view = .app raw [] := rfl

private theorem state (P : Program) (B : Builtins) (σ : PathEnv) :
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

private theorem stateTy (P : Program) (B : Builtins) {σ : PathEnv} (valid : σ.Valid) :
    StateTy P B σ s := by
  refine ⟨valid,E,?_,state P B σ⟩
  constructor
  · rfl
  · intro a ha
    have hn : ¬ Eff.mem E a := by
      cases a <;> simp [E,Eff.empty,Eff.mem,Eff.test,Eff.atoms]
    exact (hn ha).elim

private def target (k : Cont) (μ : Store) : State :=
  .run (Closure.pure (.ret (.const .unit))) (markPush k) μ

/-- 捕捉した生lambdaと直接のlambdaは同じ本体・同じ到達先を持つ。 -/
theorem captured_and_direct {P B σ k μ} :
    Step P B σ (.run q k μ) none (target k μ) ∧
    Step P B σ (.run (Closure.pure (.app raw [])) k μ) none (target k μ) :=
  ⟨.E_Lam view rfl rfl,
    .E_Lam (q := Closure.pure (.app raw [])) (ws := []) (k := k) (μ := μ) (f := closeVal Capture.empty raw)
      (signature := Capture.empty.closeTel (lambdaShape [] []))
      (body := Closure.pure (.ret (.const .unit))) rfl rfl rfl⟩

example {P B σ oracle externalOracle rel fresh} :
    step P B σ oracle externalOracle rel fresh s = some (none,target [] Store.empty) :=
  (step_lambda view rfl rfl).1

/-- 捕捉変数から読む生lambdaの状態はStateTyを持ち、Stepが存在する。 -/
example (P : Program) (B : Builtins) {σ : PathEnv} (valid : σ.Valid) :
    StateTy P B σ s ∧ ¬ (∀ event dest, ¬ Step P B σ s event dest) :=
  ⟨stateTy P B valid,fun h => h none (target [] Store.empty) captured_and_direct.1⟩

private def nested : Val := .closure (.done U E) q
private def initial : State := .run (Closure.pure (.app nested [])) [] Store.empty
private def afterFirst : State := .run q [.mark] Store.empty

private theorem nested_typed (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] [] nested (.dependentFn (.done U E)) := by
  have hc : CaptureOk P B (hideBuilders StoreTy.empty) none (Ctx.extend [] F) [] cap := by
    have he : hideBuilders StoreTy.empty = StoreTy.empty := by funext i; rfl
    rw [he]
    exact capture P B
  have hb : TelBodyTy P B (hideBuilders StoreTy.empty) Qempty []
      (hideConts (Ctx.extend [] F)) [] (.done U E) code := by
    apply TelBodyTy.done
    apply HasTypeCQ.C_App (ns := []) (as := [])
    · exact .V_Var rfl (by trivial)
    · exact .nil
  have ha : Ty.Annotation P [] (hideConts (Ctx.extend [] F)) (.dependentFn (.done U E)) := by
    exact (show Ty.Annotation P [] (hideConts (Ctx.extend [] F)) U from ⟨trivial,trivial,trivial⟩).done_empty
  have he : cap.closeTel (.done U E) = .done U E := by
    simp [Capture.closeTel,Tel.bind_done,Eff.bind,Eff.rawBind,E,Eff.empty,Eff.norm,rowFails,
      instAtoms_nil,substAtoms_nil,Ty.normTys,valEnv,Ty.bind,Ty.rawBind,Ty.norm,U]
  have hdst := DependentClosureTy.mk hc hb ha (by
    rw [he]; exact (show Ty.Annotation P [] [] U from ⟨trivial,trivial,trivial⟩).done_empty)
  apply HasTypeVQ.V_Closure (runtime := .done U E)
    (show Ty.Annotation P [] [] (.dependentFn (.done U E)) from
      (show Ty.Annotation P [] [] U from ⟨trivial,trivial,trivial⟩).done_empty)
    ⟨by trivial,by trivial,trivial⟩
  rw [he] at hdst
  exact hdst

private theorem initial_typed (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ E initial := by
  have hu : Ty.Annotation P [] [] U := ⟨trivial,trivial,trivial⟩
  have hb : HasTypeC P B StoreTy.empty [] [] [] none (.app nested []) U E :=
    .C_DependentApp (nested_typed P B) (.done hu.done_empty)
  have hq := ClosureTy.pure hb hu.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  refine ⟨StoreTy.empty,none,U,U,E,E,StoreOk.empty P B σ,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩ hu,?_,?_,
    (by intro f hf; cases hf),(by intro l c hc; cases hc)⟩
  · simp [nested,q,cap,raw,code,Closure.pure,Closure.Adequate,Capture.Adequate,
      Capture.extend,Capture.empty,Capture.values,Val.Adequate,Comp.Adequate,adequateCaptureSlots,adequateVals]
  · simp [nested,q,cap,raw,code,Closure.pure,Closure.ClosedAt,Capture.Closed,
      Capture.extend,Capture.empty,Capture.values,Val.ClosedAt,Comp.ClosedAt,Val.ClosedList,
      captureSlotsClosed,NamesWF,telBinders,Tel.WF,Eff.WF,E,Eff.empty,Eff.Canonical,
      Eff.norm,Ty.WF,Ty.WFList,U] <;> trivial

/-- 型付きの開始から、捕捉に生lambdaを持つclosureを経て次の本体へ進む。 -/
theorem two_steps (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ E initial ∧
    Step P B σ initial none afterFirst ∧ Step P B σ afterFirst none (target [.mark] Store.empty) :=
  ⟨initial_typed P B σ,.E_Lam (q := Closure.pure (.app nested [])) (ws := []) (k := []) (μ := Store.empty) (f := nested) (signature := .done U E) (body := q) rfl rfl rfl,captured_and_direct.1⟩

/-- δが同じ捕捉付きclosureを返すときの四つの実行葉。具体表の充足は仮定しない。 -/
theorem delta_return_path {P B σ b sg ts es rs}
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (hd : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs [] = some (.val nested))
    (start : Closure) (hv : start.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) []) :
    let continuation := Closure.pure (.app (.var 0) [])
    let next := continuation.apply [nested]
    Step P B σ (.run start [.letF continuation] Store.empty) none
      (.run (Closure.pure (.ret nested)) [.letF continuation] Store.empty) ∧
    Step P B σ (.run (Closure.pure (.ret nested)) [.letF continuation] Store.empty) none
      (.run next [] Store.empty) ∧
    Step P B σ (.run next [] Store.empty) none afterFirst ∧
    Step P B σ afterFirst none (target [.mark] Store.empty) :=
  ⟨.E_Prim hv hs hk hd,.E_Return rfl,.E_Lam (q := (Closure.pure (.app (.var 0) [])).apply [nested]) (ws := []) (k := []) (μ := Store.empty) (f := nested) (signature := .done U E) (body := q) rfl rfl rfl,captured_and_direct.1⟩

/-- 具体の観測は、定義した状態と保存の葉を同時に読む。 -/
example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ E (target [] Store.empty) := by
  have ⟨_,ht⟩ := (state P B σ).lambda_beta_all hP hPB hB view rfl rfl
  exact ht

example {P B σ k μ} : Step P B σ (.run q k μ) none (target k μ) :=
  captured_and_direct.1

example (P : Program) (B : Builtins) (σ : PathEnv) :
    ∃ source dest, StateTyE P B σ E source ∧ Step P B σ source none dest := by
  obtain ⟨ht,hs,_⟩ := two_steps P B σ
  exact ⟨initial,afterFirst,ht,hs⟩

/-- 同じδ応答の経路を次の呼出しのStepへ使う読者。 -/
example {P} {B : Builtins} {σ b sg ts} {es : List Eff} {rs} {start : Closure}
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (hd : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs [] = some (.val nested))
    (hv : start.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) []) :
    Step P B σ afterFirst none (target [.mark] Store.empty) :=
  (delta_return_path hs hk hd start hv).2.2.2

end
end Benitoite.Release.Refinement.LambdaApplicationExamples
