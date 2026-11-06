import Benitoite.Release.Refinement.Surface.OpenSurfaceCallExpr

/-! # 開いた範囲文脈の外部関数の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

private theorem external_value_instR (rs : List RangeExpr) (f : ExternalFunctionId) (ts : List Ty) :
    (Val.externalRef f ts).instR rs = .externalRef f (ts.map (rangeTy rs)) := by
  cases rs with
  | nil => change Val.externalRef f ts = .externalRef f (ts.map id); rw [List.map_id]
  | cons r rs => rfl

theorem externalName_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p f d ts}
    (hR : D.Realizes P) (σ : Instance ks)
    (hf : D.core.externalFunction f = some d) (hsc : d.parameters.RangesScoped 0)
    (had : ExternalAdmits D.core B ks C d ts)
    (hsi : Signature D.core ks C Γ d.parameters d.kinds ts []) :
    ExprCore P B op Q Δ C Γ Φ R p (.externalName f ts)
      (.dependentFn (instantiatedTel d.parameters ts [])) Eff.empty σ.val := by
  have hf' : P.externalFunction f = some d := (hR.externalFunction _).symm.trans hf
  have hwf := hR.externalWF.function_lookup hf'
  have hw : d.parameters.WF 0 d.kinds.length 0 := by
    simpa only [Ty.WF, hwf.kinds, List.length_nil] using hwf.annotation.wf
  have hsig := signature_source_convert ((hsi σ).sameTypes hR.types) hw (closedTel_norm hsc σ).symm
  have ha := had σ
  have hv := HasTypeVQ.V_ExternalRef (Ψ := StoreTy.empty) (Q := Q) (Φ := Φ) (Γ := rangeCtx σ.val Γ)
    hf' hwf ⟨ha.count, ha.kinds.sameTypes hR.types, ha.constraints, ha.types.sameTypes hR.types⟩
    (by simpa only [List.map_nil] using hsig)
  have ht : instantiatedTel d.parameters (ts.map (rangeTy σ.val)) [] =
      rangeTel σ.val (instantiatedTel d.parameters ts []) := by
    rw [OpenSignatureExchange.rangeTel_instantiated, List.map_nil,
      ← instantiatedTel_norm_source (rangeTel σ.val d.parameters), closedTel_norm hsc σ,
      instantiatedTel_norm_source]
  rw [ht] at hv
  unfold ExprCore
  rw [desugarExpr, comp_ret_instR, external_value_instR, rangeEff_empty]
  exact .C_Return (dependentFn_range_type hv)

theorem callExternal_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p f d ts labels positions args as r e b ε}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hf : D.core.externalFunction f = some d) (hsc : d.parameters.RangesScoped 0)
    (had : ExternalAdmits D.core B ks C d ts)
    (_hok : CallOk d.parameters.names (telBinders d.parameters) false labels positions)
    (hargs : ExprsCore P B op Q Δ C Γ Φ R args as ε σ.val)
    (hv : ValsTel D B ks C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
      (recordFields as.length positions (boundVars as.length) (.const .unit))
      (Tel.bind (typeEnv ts) d.parameters) r e)
    (hle : Ty.LeQ D.core (bindParams Γ as) (liftMany as.length Φ) r (b.shiftV as.length 0))
    (hc : Eff.Covers (bindParams Γ as) (liftMany as.length Φ) (Eff.shiftV as.length 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) :
    ExprCore P B op Q Δ C Γ Φ R p (.call (.externalName f ts) labels positions args) b ε σ.val := by
  have hf' : P.externalFunction f = some d := (hR.externalFunction _).symm.trans hf
  have hwf := hR.externalWF.function_lookup hf'
  have hcount := (had σ).count
  simp only [List.length_map, hwf.monomorphic, List.length_nil] at hcount
  have hts : ts = [] := List.eq_nil_of_length_eq_zero hcount
  subst ts
  apply callDirect_core (.external hf hsc had) ?_ hle hc hb hR hA σ hargs
  simpa only [List.map_nil, List.nil_append, external_tel_shift hwf] using hv

end
end Benitoite.Release.Refinement.Surface.OpenSurface
