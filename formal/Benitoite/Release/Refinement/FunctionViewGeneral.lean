import Benitoite.Release.Refinement.FiniteFunctionView
import Benitoite.Release.Refinement.CloseTyping

/-! # 関数 view の支持と捕捉された観測の成功 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 有限な支持を持つ view は元の依存列と名前・個数を共有する。 -/
theorem Tel.function_view_contract {s : List Atom} {t : Tel} {f : FnView}
    (hs : t.Support (· ∈ s)) (hv : t.fnViewWith? s = some f) :
    f.toTel = t ∧ f.names = t.names ∧ NamesWF t.names f.params ∧
      t.names.Nodup ∧ Ty.foldFnWith s t = .fn f.names f.params f.result f.effect := by
  have he := (Tel.fnViewWith?_eq_some_iff s t f hs).mp hv
  have hn : f.names = t.names := (Tel.names_toTel f.names_wf).symm.trans (congrArg Tel.names he)
  refine ⟨he,hn,hn ▸ f.names_wf,hn ▸ f.names_wf.2,?_⟩
  rw [Ty.foldFnWith_eq_foldFn s t hs,←he]
  exact Ty.foldFn_toTel f

/-- 捕捉の Transport によって観測の置換が成功し、getD の既定値へ進まない。 -/
theorem CaptureOk.termBind_success {P B Ψ R Γ Φ cap} {t : Term} {sort : «Sort»}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ht : t.HasSort Γ sort) :
    ∃ u, termBind? (valEnv cap.env).values t = some u ∧
      termBind (valEnv cap.env).values t = u ∧ u.HasSort [] sort := by
  obtain ⟨u,hu,hs⟩ := Term.hasSort_bind ht _ hc.transport.values hc.transport.references
  exact ⟨u,hu,by simp only [termBind,hu,Option.getD_some],hs⟩

/-- 実際の toTerm? の成功を、型付きの閉じた値と同じ観測へ移す。 -/
theorem HasTypeVQ.captured_observation {P B Ψ R Γ Φ cap v a t sort}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeV P B Ψ [] Γ Φ v a)
    (ho : v.toTerm? = some t) (ht : t.HasSort Γ sort) :
    ∃ u, (closeVal cap v).toTerm? = some u ∧
      termBind (valEnv cap.env).values t = u ∧ u.HasSort [] sort ∧
      HasTypeV P B Ψ [] [] [] (closeVal cap v) (cap.closeTy a) := by
  obtain ⟨u,hu,hbind,hus⟩ := hc.termBind_success ht
  refine ⟨u,?_,hbind,hus,close_value_typed hP hPB hB hw hs hd hc hv⟩
  rw [closeVal_observation,Val.toTerm_subst_optional,ho,Option.bind_some]
  exact hu

end
end Benitoite.Release.Refinement
