import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.MethodArguments

namespace Benitoite.Release.Refinement
noncomputable section

/-- 実引数列は終端の注釈を結果の文脈で持つ。 -/
theorem HasTypeTelArgsQ.resultAnnotation {P B Ψ Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) : Ty.Annotation P C Γ a := by
  match h with
  | .done ha => exact ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩
  | .param _ _ hs => exact hs.resultAnnotation

theorem HasTypeTelArgsQ.normInput {P B Ψ Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.norm t) a.norm e.norm := by
  match h with
  | .done ha =>
    have hd : Ty.Annotation P C Γ (.dependentFn (.done a.norm e.norm)) :=
      ⟨⟨Ty.wf_norm ha.wf.1, (Eff.wf_norm ha.wf.2.1), Eff.norm_idem _⟩,
        ⟨Ty.sorted_norm ha.sorted.1, sortedEff_norm ha.sorted.2⟩,
        ⟨ha.declared.1.norm, declaredEff_norm ha.declared.2⟩⟩
    exact .done hd
  | .param ha hv hs =>
    apply HasTypeTelArgsQ.param ha.norm hv.V_Normal
    simpa only [Tel.bind, Tel.norm_idem, Tel.norm_rawBind] using hs.normInput

private theorem open_shift_ty (a : Ty) (v : Val) :
    (a.shiftV 1 0).bind (Tel.argumentsEnv v) = a.norm := by
  rw [argumentsEnv_eq]
  unfold Ty.bind SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind, Ty.substV_shift_cancel a (by intro i; rfl)]

private theorem open_shift_eff (e : Eff) (v : Val) :
    Eff.bind (Tel.argumentsEnv v) (e.shiftV 1 0) = e.norm := by
  rw [argumentsEnv_eq]
  unfold Eff.bind SubstEnv.valuesOnly
  rw [← Eff.rawSubstV_eq_rawBind, Eff.substV_shift_cancel e (by intro i; rfl)]

theorem HasTypeTelArgsQ.toTelValues {P B Ψ Q C Γ Φ vs ns ps r e a f}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Ty.toTel ns ps r e) a f)
    (hn : NamesWF ns ps) : HasTypeVsQ P B Ψ Q C Γ Φ vs (Ty.normTys ps) ∧
      a.norm = r.norm ∧ f.norm = e.norm := by
  induction ns generalizing ps vs r e a f with
  | nil =>
    cases ps with
    | cons => simp [NamesWF] at hn
    | nil => cases h with
      | done ha => exact ⟨.nil, rfl, rfl⟩
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons p ps =>
      cases h with
      | @param _ _ _ _ _ _ _ _ v _ _ _ ha hv hs =>
        have he : Tel.bind (Tel.argumentsEnv v) (Ty.toTel ns (shiftVTys 1 0 ps)
            (r.shiftV 1 0) (e.shiftV 1 0)) =
            Ty.toTel ns (Ty.normTys ps) r.norm e.norm := by
          rw [Tel.bind_toTel, open_shift_ty, open_shift_eff]
          congr 1
          simp only [shiftVTys_eq_map, Ty.normTys_eq_map, List.map_map, Function.comp_def, open_shift_ty]
        rw [he] at hs
        have hn' : NamesWF ns (Ty.normTys ps) :=
          ⟨by simpa [Ty.normTys_eq_map] using Nat.succ.inj hn.1, hn.2.of_cons⟩
        obtain ⟨hvs, hr, hf⟩ := ih hs hn'
        refine ⟨.cons hv.V_Normal ?_, ?_, ?_⟩
        · simpa only [Ty.normTys_eq_map, List.map_map, Function.comp_def, Ty.norm_idem] using hvs
        · simpa only [Ty.norm_idem] using hr
        · simpa only [Eff.norm_idem] using hf

/-- 正規化した関数型での適用は、既存の二つの適用と部分型変換から導く。 -/
theorem HasTypeCQ.dependentApp_normalized {P B Ψ Q C Γ Φ Δ R f args t a e}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ f (Ty.dependentFn t).norm)
    (hs : HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) a e Δ := by
  have ha := hs.resultAnnotation
  have hn := hs.normInput
  have hc : HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) a.norm e.norm Δ := by
    change HasTypeVQ P B Ψ Q C Γ Φ f (Ty.foldFn (Tel.norm t)) at hv
    cases he : (Tel.norm t).fnView? with
    | none =>
      simp only [Ty.foldFn, he] at hv
      exact .C_DependentApp hv hn
    | some view =>
      have ht := (Tel.fnView?_eq_some_iff _ _).mp he
      rw [← ht] at hn
      obtain ⟨hvs, hr, hf⟩ := hn.toTelValues view.names_wf
      simp only [Ty.norm_idem, Eff.norm_idem] at hr hf
      simp only [Ty.foldFn, he] at hv
      have hh := HasTypeCQ.C_App (R := R) (Δ := Δ) hv.V_Normal hvs
      simpa only [Ty.norm, hr, hf] using hh
  exact .C_Sub hc (.convert (Ty.norm_idem a))
    (Eff.covers_norm_right.mpr (Eff.Covers.refl Γ Φ e)) ha.wf ha.sorted ha.declared

/-- 互換の名前。独立した帰納的規則ではない。 -/
theorem HasTypeCQ.C_DependentAppNorm {P B Ψ Q C Γ Φ Δ R f args t a e}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ f (Ty.dependentFn t).norm)
    (hs : HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) a e Δ :=
  HasTypeCQ.dependentApp_normalized hv hs

end
end Benitoite.Release.Refinement
