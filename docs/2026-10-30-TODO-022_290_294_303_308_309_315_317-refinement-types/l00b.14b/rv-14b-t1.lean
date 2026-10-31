import Benitoite.Release.Refinement.CapturedFacts
import Benitoite.Release.Refinement.LogicSound
namespace Benitoite.Release.Refinement
noncomputable section

/-- evaluated_fact の前提 hc・hp は要らない。evalClosed が WF と Sorted を検査している。 -/
theorem evaluated_alone {p : Pred} (he : p.evalClosed = some true) : Entails [] p := by
  unfold Pred.evalClosed at he
  split at he
  · rename_i h; exact .closed h.1 h.2 (by unfold Pred.evalClosed; rw [if_pos h]; exact he)
  · cases he

/-- 評価の成功でなく導出から足す入口。CaptureOk の事実の欄と同じ強さ。 -/
theorem CaptureOk.addEntailed {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ p)
    (hf : Entails [] (predBind (valEnv cap.env).values p)) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap := by
  cases hc with
  | mk hw hn hh hs hΦ hg hi hfact =>
    refine .mk hw hn hh hs ?_ hg hi ?_
    · intro q hq
      rcases List.mem_cons.mp hq with rfl | hq
      · exact ⟨hp.wf,hp.sorted,hp.declared⟩
      · exact hΦ q hq
    · intro q hq
      rcases List.mem_append.mp hq with hq | hq
      · exact hfact q (List.mem_append_left _ hq)
      · rcases List.mem_cons.mp hq with rfl | hq
        · exact hf
        · exact hfact q (List.mem_append_right _ hq)

/-- 真偽の変数の経路条件。 -/
def boolCond (i : Nat) (b : Bool) : Pred := .compare .boolean .eq (.var i) (.boolean b)

/-- E_IfT/F の前提の値から、評価の成功を導く。 -/
theorem boolCond_evaluates {P B Ψ R Γ Φ cap i b}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ (boolCond i b))
    (hv : closeVal cap (.var i) = .const (.boolean b)) :
    (predBind (valEnv cap.env).values (boolCond i b)).evalClosed = some true := by
  have hclosed := hp.map hc.substOk.observations hc.substOk.references hc.substOk.declaration
  have henv : cap.env i = .const (.boolean b) := hv
  have heq : predBind (valEnv cap.env).values (boolCond i b)
      = .compare .boolean .eq (.boolean b) (.boolean b) := by
    simp [boolCond,predBind,valEnv,SubstEnv.values,henv,Val.toTerm?]
  rw [heq] at hclosed ⊢
  unfold Pred.evalClosed
  rw [if_pos ⟨hclosed.wf,hclosed.sorted⟩]
  cases b <;> simp [Pred.evalWith,Pred.atomReady,Pred.atomValue,termReady,Term.observe,
    Observation.sort,observeAs,Term.interpret,Observation.compare,Comparison.fromEqLt,
    Comparison.Allowed] <;> exact decide_eq_true trivial

/-- 枝の型付けが経路条件を足す規則を仮に置いたときの E_IfT/F の到達の閉包。
    規則を足さず、枝の導出を入力に取る。 -/
theorem ClosureTy.branch {P B Ψ R Rs Γ Φ cap i b m a e}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ (boolCond i b))
    (hv : closeVal cap (.var i) = .const (.boolean b))
    (hm : HasTypeC P B Ψ [] Γ (boolCond i b :: Φ) Rs m a e)
    (ha : Ty.Annotation P [] Γ (.dependentFn (.done a e)))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap m) (cap.closeTy a) (cap.closeEff e) :=
  ClosureTy.capture (hc.addEvaluated hp (boolCond_evaluates hc hp hv)) hm ha hR hr

/-- 実際の Step の前提の形から条件を得る。 -/
theorem boolCond_of_view {cap : Capture} {i b m n}
    (h : (Closure.mk cap (.ite (.var i) m n)).view = .ite (.const (.boolean b)) m n) :
    closeVal cap (.var i) = .const (.boolean b) := by
  have h' : Comp.ite (closeVal cap (.var i)) m n = .ite (.const (.boolean b)) m n := h
  exact (Comp.ite.inj h').1

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.evaluated_alone
#print axioms Benitoite.Release.Refinement.CaptureOk.addEntailed
#print axioms Benitoite.Release.Refinement.ClosureTy.branch
