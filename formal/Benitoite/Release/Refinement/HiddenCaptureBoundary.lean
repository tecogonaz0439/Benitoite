import Benitoite.Release.Refinement.BuilderStateLeaves
import Benitoite.Release.Refinement.LocalInvariant
namespace Benitoite.Release.Refinement.CaptureLocalRefsBoundary
noncomputable section
private def hiddenBody : Closure := .pure (.builderOp .string .copy (.loc 7) [])
private def hiddenValue : Val := .closure (.done (.base .unit) Eff.empty) hiddenBody
private def hiddenCapture : Capture := Capture.empty.extend hiddenValue
private def hiddenState : State := .run (.mk hiddenCapture (.ret (.const .unit))) [] Store.empty
private theorem unitAnnotation {P : Program} : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
private theorem hiddenGround : hiddenValue.Ground := by
  simp [hiddenValue,hiddenBody,Val.Ground,Val.ClosedAt,Closure.ClosedAt,Closure.pure,Capture.empty,
    Capture.values,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,telBinders,
    Tel.WF,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WF,Ty.WFList] <;> trivial
/-- 捕捉の全 some slot を検査する LocalRefs に必要となる、一段の条件。 -/
private def SlotBuilderLive (μ : Store) (cap : Capture) : Prop :=
  ∀ ov ∈ cap.values, ∀ runtime body kind op l args,
    ov = some (.closure runtime body) → body.code = .builderOp kind op (.loc l) args →
      ∃ c, μ l = some (.builder c)

private theorem hidden_state_typed (P : Program) (B : Builtins) (σ : PathEnv) : StateTyE P B σ Eff.empty hiddenState := by
  have hc : CaptureOk P B StoreTy.empty none ([none] : Ctx) [] hiddenCapture :=
    (CaptureOk.empty P B StoreTy.empty none).extendHidden hiddenValue hiddenGround
  have hb : HasTypeCQ P B StoreTy.empty Qempty [] [none] [] none (.ret (.const .unit)) (.base .unit) Eff.empty [] :=
    .C_Return (.V_Const trivial)
  have hq := ClosureTy.capture_resolved_closed hc hb (CaptureLocals.empty _ _ LocalRef.bound)
    (by simpa only [Capture.closeTy,Capture.closeEff,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,substEffValues_empty] using (unitAnnotation (P := P)).done_empty) rfl (by intros; contradiction)
  have hq' : ClosureTy P B StoreTy.empty [] none (.mk hiddenCapture (.ret (.const .unit))) (.base .unit) Eff.empty := by
    simpa [Comp.resolveLocals_id,Capture.closeTy,Capture.closeEff,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,
      substEffValues_empty] using hq
  refine ⟨StoreTy.empty,none,.base .unit,.base .unit,Eff.empty,Eff.empty,StoreOk.empty P B σ,hq',
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty (⟨fun _ h => h,fun _ h => h⟩) unitAnnotation,?_,?_,?_,?_⟩
  · trivial
  · exact ⟨⟨hiddenGround,trivial⟩,trivial⟩
  · intro f hf; cases hf
  · intro l c hc; cases hc

/-- 型付きの状態でも、None の slot にある閉包は存在しない専用場所を参照できる。 -/
theorem hidden_slot_counterexample (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ Eff.empty hiddenState ∧ ¬SlotBuilderLive Store.empty hiddenCapture := by
  refine ⟨hidden_state_typed P B σ,?_⟩
  intro h
  obtain ⟨c,hc⟩ := h (some hiddenValue) (by exact List.mem_cons_self)
    (.done (.base .unit) Eff.empty) hiddenBody .string .copy 7 [] rfl rfl
  cases hc

/-- 同じ返却本体で捕捉を空にした場合は、全 slot の必要条件も満たす。 -/
theorem empty_capture_accepts (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      SlotBuilderLive Store.empty Capture.empty := by
  have ha := unitAnnotation (P := P)
  have hq := ClosureTy.pure (Ψ := StoreTy.empty) (HasTypeCQ.C_Return (R := none) (HasTypeVQ.V_Const (B := B) (c := .unit) trivial))
    ha.done_empty (by intros; contradiction) rfl (by intros; contradiction)
  refine ⟨⟨StoreTy.empty,none,.base .unit,.base .unit,Eff.empty,Eff.empty,StoreOk.empty P B σ,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩ ha,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,(by intro f hf; cases hf),(by intro l c hc; cases hc)⟩,?_⟩
  intro ov hov; cases hov


/-- 導出に対応する位置の条件は満たすが、保存した全位置の条件は満たさない。 -/
theorem hidden_slot_read_localrefs (P : Program) (B : Builtins) (σ : PathEnv) :
    LocalStateInvariant P B σ hiddenState ∧ ¬SlotBuilderLive Store.empty hiddenCapture := by
  exact ⟨(hidden_state_typed P B σ).local_invariant,(hidden_slot_counterexample P B σ).2⟩

end
theorem reject_executed_stale_builder (P : Program) (B : Builtins) (σ : PathEnv) :
    ¬StateTyE P B σ Eff.empty (.run hiddenBody [] Store.empty) := by
  intro h
  obtain ⟨contents,hcell⟩ := h.builder_live (kind := .string) (op := .copy) (l := 7) (args := []) rfl
  cases hcell

end Benitoite.Release.Refinement.CaptureLocalRefsBoundary
