import Benitoite.Release.Refinement.Context.Capture
namespace Benitoite.Release.Refinement.RV03
noncomputable section
def scalar : Ty := .base .integer8
def seven : Val := .const (.integer8 7)
def equalSeven : Ty := .refined scalar (.eq (.var 0) (.integer 7))
def same (i : Nat) : Ty := .refined scalar (.eq (.var 0) (.var (i+1)))
def selfCycle : Ctx := [some (same 0)]
def cap0 : Capture := Capture.empty.extend seven

theorem not_ordered : ¬ selfCycle.Ordered := by
  intro h
  have hp := h.refined_outer (i := 0) (a := scalar) (p := .eq (.var 0) (.var 1)) rfl
  simp [Pred.VarsIn, Term.VarsIn] at hp

theorem seven_equalSeven (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] seven equalSeven := by
  have hs : HasTypeVQ P B Ψ Qempty [] [] [] seven scalar :=
    .V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)
  refine .V_Refine hs rfl rfl ⟨⟨⟨scalar, rfl, by simp [scalar, Ordinary]⟩, scalar, rfl, rfl⟩, ⟨trivial, rfl⟩⟩ ?_ .eq_refl trivial ⟨⟨scalar.shiftV 1 0, rfl, by simp [scalar, Ty.shiftV, Ordinary]⟩, trivial⟩
  simp [Pred.WF, Pred.VarsIn, Term.VarsIn]

theorem close_same : cap0.closeTy (same 0) = equalSeven := by
  simp [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, same, equalSeven, scalar,
    predBind, upValues, termBind, termBind?, valEnv, cap0, Capture.extend, Capture.env,
    Capture.empty, Capture.values, seven, Val.toTerm?]

/-- 自分を参照する文脈が CaptureOk を満たす。Ordered は CaptureOk に含まれない。 -/
theorem cycle_capture (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none selfCycle [] cap0 := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi
    cases i with
    | zero =>
      cases hi
      simp [Ty.CaptureWF, same, scalar, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core, selfCycle]
    | succ i => simp [selfCycle] at hi
  · intro i a hi
    cases i with
    | zero => exact ⟨seven, rfl⟩
    | succ i => simp [selfCycle] at hi
  · intro i a hi
    cases i with
    | zero =>
      cases hi
      have hr : Ctx.Readable (some scalar :: selfCycle) 1 :=
        ⟨same 0, rfl, by simp [same, Ordinary]⟩
      have hd : (Term.var 1).Declared P [] ((selfCycle).extend scalar) ∧ True := by
        refine ⟨⟨(same 0).shiftV 1 0, rfl, by simp [same, Ty.shiftV, Ordinary]⟩, trivial⟩
      refine ⟨⟨trivial, ⟨⟨scalar, rfl, by simp [scalar, Ordinary]⟩, scalar, rfl, rfl⟩, ⟨hr, same 0, rfl, rfl⟩⟩, ⟨trivial, ⟨scalar.shiftV 1 0, rfl, by simp [scalar, Ty.shiftV, Ordinary]⟩, hd.1⟩⟩
    | succ i => simp [selfCycle] at hi
  · intro p hp; cases hp
  · intro ov ho w he
    simp only [cap0, Capture.extend, Capture.empty, Capture.values, List.mem_cons, List.not_mem_nil, or_false] at ho
    subst ho
    cases he
    trivial
  · intro i a hi
    cases i with
    | zero =>
      cases hi
      apply ImageOk.ordinary (by simp [same, Ordinary])
      change HasTypeVQ P B Ψ Qempty [] [] [] seven (cap0.closeTy (same 0))
      rw [close_same]
      exact seven_equalSeven P B Ψ
    | succ i => simp [selfCycle] at hi
  · intro p hp
    simp only [List.append_nil] at hp
    obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
    cases i with
    | zero =>
      cases hi
      simp only [same, Ty.assume, List.mem_cons, scalar, List.not_mem_nil, or_false] at hq
      subst hq
      exact .eq_refl
    | succ i => simp [selfCycle] at hi
#print axioms cycle_capture
#print axioms not_ordered
end
end Benitoite.Release.Refinement.RV03
