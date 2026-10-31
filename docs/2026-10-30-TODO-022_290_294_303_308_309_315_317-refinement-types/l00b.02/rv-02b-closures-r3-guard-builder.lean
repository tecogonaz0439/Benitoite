import ClosureR3Boundary

/-! 境界入力にない行: 構築器を局所に持つ K_Guard（L=[some kind0]）の E_MatchGuard と E_GuardT。 -/
namespace Benitoite.Release.Refinement.ClosureR3
noncomputable section
set_option linter.unusedSimpArgs false
set_option linter.unusedVariables false

def armCap : Capture := cap.extendMany [seven]
def armΓ : Ctx := Γ0.extend scalar
def armBody : Comp := .builderOp (.list (R 1)) .length (.loc 0) []
def guardFalseQ : Closure := .mk armCap (.ret (.const (.boolean false)))
def armBodyQ : Closure := .mk armCap armBody
def bGuardK : Cont := [.guardF seven cap builderArms 1 armBodyQ]
def bμ : Store := Store.empty.set 0 (.builder (substKind cap.env kind0).empty)

theorem arm_capture (P : Program) (B : Builtins) : CaptureOk P B runtimeBuilder none armΓ [] armCap := by
  have hget : ∀ i a, armΓ[i]? = some (some a) → (i = 0 ∧ a = scalar) ∨ (i = 1 ∧ a = scalar) := by
    intro i a hi
    cases i with
    | zero => cases hi; exact Or.inl ⟨rfl,rfl⟩
    | succ i => cases i with
      | zero => cases hi; exact Or.inr ⟨rfl,rfl⟩
      | succ i => simp [armΓ,Γ0,Ctx.extend] at hi
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨seven,rfl⟩
    · exact ⟨seven,rfl⟩
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> exact ⟨trivial,trivial⟩
  · intro p hp; cases hp
  · intro ov ho v he
    simp [armCap,Capture.extendMany,cap,seven,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl <;> cases he <;> trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;>
      exact .ordinary (by simp [Ty.Ordinary,scalar]) (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))
  · intro p hp; simp [armΓ,Γ0,Ctx.extend,Ctx.facts,Ty.shiftV,renameTy,scalar,Ty.assume] at hp

theorem arm_locals : CaptureLocals runtimeBuilder armCap.env (localExtend 1 [some kind0]) (upLocalSubst 1 builderρ) := by
  intro i k hi
  cases i with
  | zero => cases hi
  | succ i => cases i with
    | zero => cases hi; exact ⟨0,rfl,rfl⟩
    | succ i => simp [localExtend,LocalCtx.extend] at hi

theorem R1_arm_ann (P : Program) : Ty.Annotation P [] armΓ (R 1) := by
  have h := R_unit_ann P
  exact ⟨h.wf,h.sorted,h.declared⟩

theorem arm_body_closure (P : Program) (B : Builtins) :
    ClosureTy P B runtimeBuilder [] none armBodyQ (.base .integer) Eff.empty := by
  have ha := R1_arm_ann P
  have hh := ClosureTy.capture_resolved (Rs := none) (arm_capture P B)
    (.C_BuilderOp (kind := .list (R 1)) (op := .length) (ref := .bound 1) (args := [])
      ⟨ha.wf,ha.sorted,ha.declared⟩ (kinded P _ (R_kind P 1)) (.bound rfl) .nil)
    arm_locals (done_ann (P := P) (Γ := armΓ) (a := .base .integer) ⟨trivial,trivial,trivial⟩)
    rfl (by intros; contradiction)
  simpa [armBodyQ,armBody,Comp.resolveLocals,Val.resolveLocalsList,LocalRef.subst,LocalRef.rename,upLocalSubst,builderρ,BuilderOp.resultType] using hh

theorem guard_closure (P : Program) (B : Builtins) (c : Bool) :
    ClosureTy P B runtimeBuilder [] none (.mk armCap (.ret (.const (.boolean c)))) (.base .boolean) Eff.empty := by
  simpa using ClosureTy.capture (Rs := none) (a := .base .boolean) (arm_capture P B)
    (.C_Return (.V_Const (c := .boolean c) trivial)) (done_ann (P := P) (Γ := armΓ) (a := .base .boolean) ⟨trivial,trivial,trivial⟩)
    rfl (by intros; contradiction)

theorem bguard_cont (P : Program) (B : Builtins) (σ : PathEnv) :
    ContTy P B σ runtimeBuilder none Eff.empty bGuardK (.base .boolean) (.base .integer) Eff.empty none := by
  have hx : Exhaustive P scalar (unguardedPats [Arm.mk varAlt (some (.ret (.const (.boolean false)))) (.builderOp (.list (R 1)) .length (.bound 1) []), .mk varAlt none (.builderOp (.list (R 1)) .length (.bound 1) [])]) := by
    intro v hv; exact ⟨.var,by simp [varAlt,unguardedPats],by simp [matchVal]⟩
  refine .K_Guard (Rs := none) (as := .base .integer) (es := Eff.empty) (L := [some kind0]) (ρ := builderρ)
    (arms0 := [Arm.mk varAlt (some (.ret (.const (.boolean false)))) (.builderOp (.list (R 1)) .length (.bound 1) []), .mk varAlt none (.builderOp (.list (R 1)) .length (.bound 1) [])])
    (capture_typed P B runtimeBuilder) (vs := .var 0) (t := scalar)
    (.V_Var (i := 0) rfl (by simp [scalar,Ty.Ordinary])) (builder_arms P B) builder_locals
    (by simp [builderArms,Arm.resolveLocalsList,Comp.resolveLocals,Val.resolveLocals,Val.resolveLocalsList,LocalRef.subst,LocalRef.rename,upLocalSubst,builderρ,show Arm.bindersOf varAlt = 1 from rfl])
    (by intros; contradiction) hx rfl rfl (close_base _ _) (close_empty _) (arm_body_closure P B)
    ⟨fun _ h => h,fun _ h => h⟩ ?_ (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩) ?_
  · intro arm ha hg
    simp [builderArms] at ha; subst arm; cases hg
  · simp [Frame.Adequate,armBodyQ,armBody,armCap,Capture.extendMany,builderArms,cap,seven,Capture.values,Capture.extend,Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate,adequateArms,adequateVals]

theorem arm_cap_closed : armCap.Closed := by
  simp [armCap,Capture.extendMany,cap,seven,Capture.values,Capture.extend,Capture.Closed,captureSlotsClosed,Val.ClosedAt]

theorem guard_state (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) (c : Bool) :
    StateTy P B σ (.run (.mk armCap (.ret (.const (.boolean c)))) bGuardK bμ) := by
  apply run_state hv (empty_builtin P B) (builder_store P B σ) (guard_closure P B c) (bguard_cont P B σ)
  · simp [armCap,Capture.extendMany,cap,seven,Capture.values,Capture.extend,Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate]
  · exact ⟨arm_cap_closed,trivial⟩
  · intro f hf; have he := List.mem_singleton.mp hf; subst f
    exact ⟨trivial,unit_closed.1,⟨trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial⟩,
      arm_cap_closed,⟨(R_unit_ann P).wf,trivial,trivial⟩⟩
  · exact one_closed trivial

/-- 行: matchRun 0 → E_MatchGuard → K_Guard（L=[some kind0]）。 -/
theorem builder_guard_push (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ builderMatchState ∧
    Step P B σ builderMatchState none (.run guardFalseQ bGuardK bμ) ∧
    StateTy P B σ (.run guardFalseQ bGuardK bμ) :=
  ⟨builder_match_after P B σ hv,.E_MatchGuard (ws := [seven]) (alts := varAlt)
    (guard := .ret (.const (.boolean false))) (body := armBody) rfl rfl,guard_state P B σ hv false⟩

theorem arm_body_state (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run armBodyQ [] bμ) := by
  apply run_state hv (empty_builtin P B) (builder_store P B σ) (arm_body_closure P B)
    (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩)
  · simp [armBodyQ,armBody,armCap,Capture.extendMany,cap,seven,Capture.values,Capture.extend,Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate,adequateVals]
  · exact ⟨arm_cap_closed,(R_unit_ann P).wf,trivial,trivial⟩
  · intro f hf; cases hf
  · exact one_closed trivial

/-- 行: K_Guard（L=[some kind0]）から true で本体へ。 -/
theorem builder_guard_true (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run (.mk armCap (.ret (.const (.boolean true)))) bGuardK bμ) ∧
    Step P B σ (.run (.mk armCap (.ret (.const (.boolean true)))) bGuardK bμ) none (.run armBodyQ [] bμ) ∧
    StateTy P B σ (.run armBodyQ [] bμ) :=
  ⟨guard_state P B σ hv true,.E_GuardT rfl,arm_body_state P B σ hv⟩

/-- 行: K_Guard（L=[some kind0]）から false で次の腕へ。 -/
theorem builder_guard_false (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run (.mk armCap (.ret (.const (.boolean false)))) bGuardK bμ) ∧
    Step P B σ (.run (.mk armCap (.ret (.const (.boolean false)))) bGuardK bμ) none
      (.matchRun seven cap builderArms 1 [] bμ) ∧
    StateTy P B σ (.matchRun seven cap builderArms 1 [] bμ) := by
  refine ⟨guard_state P B σ hv false,.E_GuardF rfl,?_⟩
  refine ⟨hv,Eff.empty,empty_builtin P B,runtimeBuilder,none,.base .integer,.base .integer,Eff.empty,Eff.empty,
    builder_store P B σ,⟨.var 0,rfl,builder_match_closure P B⟩,subRefl _,
    .K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩,trivial,?_,?_,trivial,?_,?_,?_,one_closed trivial⟩
  · exact unit_adequate σ |>.1
  · intro arm ha hg
    simp [builderArms] at ha; subst arm; cases hg
  · simp [builderArms,adequateArms,Comp.Adequate,Val.Adequate,adequateVals]
  · exact ⟨unit_closed.1,⟨trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial⟩⟩
  · intro f hf; cases hf

#print axioms builder_guard_push
#print axioms builder_guard_true
#print axioms builder_guard_false
end
end Benitoite.Release.Refinement.ClosureR3
