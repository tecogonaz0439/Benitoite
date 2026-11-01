import Benitoite.Release.Refinement.HandlerCalls

/-! 任意の引数の数の、依存列に沿った捕捉の延長。二引数の依存する結果はこの例である。-/
namespace Benitoite.Release.Refinement
noncomputable section

def telExtend : Ctx → Tel → Ctx
  | Γ, .done .. => Γ
  | Γ, .param _ a t => telExtend (Γ.extend a) t

def telLift : List Pred → Tel → List Pred
  | Φ, .done .. => Φ
  | Φ, .param _ _ t => telLift (Φ.map Pred.lift) t

theorem telExtend_sig (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (Γ : Ctx) (hl : ns.length = ps.length) :
    telExtend Γ (signatureTel ns ps r e) = Γ.extendMany ps := by
  induction ps generalizing ns Γ with
  | nil => cases ns <;> simp_all [signatureTel,telExtend,Ctx.extendMany]
  | cons a ps ih =>
    cases ns with
    | nil => simp at hl
    | cons n ns =>
      simp only [signatureTel,telExtend,Ctx.extendMany]
      exact ih ns _ (by simpa using hl)

theorem capture_tel {P B Ψ R} : (t : Tel) → ∀ {Γ Φ} {cap : Capture} {vs r f},
    CaptureOk P B Ψ R Γ Φ cap → Ty.Annotation P [] Γ (.dependentFn t) →
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) r f →
    (∀ v ∈ vs, v.Ground) →
    CaptureOk P B Ψ R (telExtend Γ t) (telLift Φ t) (cap.extendMany vs) ∧ vs.length = t.arity
  | .done a e, Γ, Φ, cap, vs, r, f, hc, _, hargs, _ => by
    simp only [Capture.closeTel,Tel.bind_done] at hargs
    cases hargs
    exact ⟨hc,rfl⟩
  | .param n x t, Γ, Φ, cap, vs, r, f, hc, ha, hargs, hg => by
    simp only [Capture.closeTel,Tel.bind_param] at hargs
    cases hargs with
    | param _ hv hrest =>
      have hx : Ty.Annotation P [] Γ x := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
      have hr : Ty.Annotation P [] (Γ.extend x) (.dependentFn t) :=
        ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ha.wf.2,ha.sorted.2,ha.declared.2⟩
      have hc1 := hc.extend hx (by simpa only [Capture.closeTy,substTyValues_eq_bind] using hv)
        (hg _ List.mem_cons_self)
      rw [Capture.openTel] at hrest
      obtain ⟨h1,h2⟩ := capture_tel t hc1 hr hrest (fun w hw => hg w (List.mem_cons_of_mem _ hw))
      exact ⟨h1,by simp [Tel.arity,Tel.names] at h2 ⊢; exact h2⟩

/-- 依存する結果は、節の捕捉を閉じた像と呼出しの結果で一致する。hcap は任意である。 -/
theorem result_tel {P B Ψ vs r f} {cap : Capture} {t : Tel}
    (hargs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) r f)
    (hl : vs.length = t.arity) :
    r = (cap.extendMany vs).closeTy t.result ∧ f = (cap.extendMany vs).closeEff t.effect := by
  have hn : (cap.closeTel t).Normal := Tel.norm_idem _
  have hi := hargs.instantiate hn
  rw [Capture.instantiate cap t vs hl] at hi
  have := Option.some.inj hi
  exact ⟨(Prod.mk.inj this).1.symm,(Prod.mk.inj this).2.symm⟩

/-- 閉じた宣言は捕捉に依らないので、呼出しの引数列の型付けから hcap の下の型付けへ移せる。-/
theorem args_under_capture {P B Ψ vs r f} {cap : Capture} {t : Tel} (hw : t.WF 0 0 0)
    (hargs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t.norm r f) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) r f := by
  rw [Capture.closeTel,Tel.bind_values_of_wf_zero hw]; exact hargs


end
end Benitoite.Release.Refinement
