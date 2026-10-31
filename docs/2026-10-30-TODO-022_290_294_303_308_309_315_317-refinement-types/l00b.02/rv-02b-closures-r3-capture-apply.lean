import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping

/-! 束縛の開放: 入力を渡すときと腕へ入るときに CaptureLocals を作り直せるか。 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Ty.open_up (cap : Capture) (v : Val) (a : Ty) :
    Ty.bind (Tel.argumentsEnv v) (a.bind (valEnv cap.env).up) = (cap.extend v).closeTy a := by
  have h := Capture.openTel cap v (.done a Eff.empty)
  simp only [Capture.closeTel,Tel.bind_done] at h
  exact (Tel.done.inj h).1

/-- 閉じた像なら、未束縛の位置に実際の値を入れても像は変わらない。 -/
theorem substKind_apply (cap : Capture) (v : Val) (k : BuilderKind)
    (hw : LocTy.WF (.builder (substKind (upSubst 1 cap.env) k))) :
    substKind (cap.extend v).env k = substKind (upSubst 1 cap.env) k := by
  cases k with
  | string | bytes => rfl
  | list a =>
    have ha : (substTyValues (upSubst 1 cap.env) a).WF 0 0 0 := hw
    have he : substTyValues (upSubst 1 cap.env) a = a.bind (valEnv cap.env).up := by
      rw [substTyValues,valEnv_upSubst_one]
    have h := Ty.open_up cap v a
    rw [←he] at h
    have hs : Ty.bind (Tel.argumentsEnv v) (substTyValues (upSubst 1 cap.env) a) =
        substTyValues (upSubst 1 cap.env) a := by
      rw [←valEnv_openValue]; exact Ty.subst_values_of_wf_zero ha _
    rw [hs] at h
    exact congrArg BuilderKind.list h.symm

/-- E_Return: 入力1個の閉包に実際の値を渡す。L は同じまま。 -/
theorem CaptureLocals.apply_one {Ψ : StoreTy} {cap : Capture} {L ρ} (h : CaptureLocals Ψ (upSubst 1 cap.env) L ρ)
    (hw : Ψ.WF) (v : Val) : CaptureLocals Ψ (cap.extend v).env L ρ := by
  intro i k hi
  obtain ⟨l,hr,ht⟩ := h i k hi
  exact ⟨l,hr,by rw [substKind_apply cap v k (hw l _ ht)]; exact ht⟩

/-- E_MatchBody 等: 腕の束縛の下へ入る。 -/
theorem CaptureLocals.extendMany {Ψ : StoreTy} (hw : Ψ.WF) (ws : List Val) :
    ∀ {cap : Capture} {L : LocalCtx} {ρ}, CaptureLocals Ψ cap.env L ρ →
    CaptureLocals Ψ (cap.extendMany ws).env (Refinement.localExtend ws.length L) (upLocalSubst ws.length ρ) := by
  induction ws with
  | nil =>
    intro cap L ρ h
    simpa only [Capture.extendMany,List.foldl_nil,List.length_nil,Refinement.localExtend,upLocalSubst_zero] using h
  | cons w ws ih =>
    intro cap L ρ h
    have h1 : CaptureLocals Ψ (cap.extend w).env (Refinement.localExtend 1 L) (upLocalSubst 1 ρ) :=
      (h.localExtend hw).apply_one hw w
    have h2 := ih h1
    have hL : ∀ n, Refinement.localExtend n (Refinement.localExtend 1 L) = Refinement.localExtend (n+1) L := by
      intro n; induction n with
      | zero => rfl
      | succ n ih => simp only [Refinement.localExtend] at ih ⊢; rw [ih]
    simpa only [Capture.extendMany,List.foldl_cons,List.length_cons,hL,upLocalSubst_add,Nat.add_comm] using h2
#print axioms CaptureLocals.extendMany
end
end Benitoite.Release.Refinement
