import Benitoite.Release.Refinement.Surface.OpenSurfaceCallExpr

/-! # 開いたパイプの呼出しの型の保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem pipeCallDirect_core {P B ks op Q Δ C Γ Φ R p lhs f labels positions args tl t ds as r e b ε}
    {D : Declarations} (hh : CallHeadTy D B ks Q C Γ f t ds)
    (hv : ValsTel D B ks C Γ (as.length + 1) (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ)
      (ds.map (fun d => d.toVal.rename (· + (as.length + 1))) ++
        recordFields (as.length + 1) (0 :: positions) (.var as.length :: boundVars as.length) (.const .unit))
      (Tel.shiftV (as.length + 1) 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ) r (b.shiftV (as.length + 1) 0))
    (hc : Eff.Covers (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ)
      (Eff.shiftV (as.length + 1) 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs tl ε σ.val)
    (hms : ExprsCore P B op Q Δ C Γ Φ R args as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.pipe lhs (.call f labels positions args)) b ε σ.val := by
  have hlen := exprs_length hms
  obtain ⟨h, hd⟩ : ∃ h, directCallee f = some h := by cases hh <;> exact ⟨_, rfl⟩
  have hseq := direct_sequence_core (as := tl :: as) (R := R) (Δ := Δ)
    (ms := desugarExpr op .other lhs :: desugarExprs op args)
    (ws := recordFields (as.length + 1) (0 :: positions) (.var as.length :: boundVars as.length) (.const .unit))
    hh hd (by simpa only [List.length_cons, Nat.add_comm 1] using hv)
    (by simpa only [List.length_cons, Nat.add_comm 1] using hle)
    (by simpa only [List.length_cons, Nat.add_comm 1] using hc) hb rfl hR hA σ (.cons hl hms)
  simp only [letChain] at hseq
  rw [show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity] at hseq
  simpa [ExprCore, desugarExpr, callComp, hd, desugarExprs_length, hlen, letChain,
    Val.renameList, Val.rename, List.range_one, Nat.add_comm 1] using hseq

theorem pipeCall_core {P B ks op Q Δ C Γ Φ R p lhs f labels positions args tl t as r e b ε}
    {D : Declarations} (hnd : directCallee f = none)
    (hv : ValsTel D B ks C Γ (as.length + 2) (bindParams Γ (tl :: .dependentFn t :: as))
      (liftMany (as.length + 2) Φ)
      (recordFields (as.length + 1) (0 :: positions) (.var (as.length + 1) :: boundVars as.length) (.const .unit))
      (Tel.shiftV (as.length + 2) 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ (tl :: .dependentFn t :: as)) (liftMany (as.length + 2) Φ)
      r (b.shiftV (as.length + 2) 0))
    (hc : Eff.Covers (bindParams Γ (tl :: .dependentFn t :: as)) (liftMany (as.length + 2) Φ)
      (Eff.shiftV (as.length + 2) 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs tl ε σ.val)
    (hf : ExprCore P B op Q Δ C Γ Φ R .other f (.dependentFn t) ε σ.val)
    (hms : ExprsCore P B op Q Δ C Γ Φ R args as ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.pipe lhs (.call f labels positions args)) b ε σ.val := by
  have hlen := exprs_length hms
  have hj : (bindParams Γ (tl :: .dependentFn t :: as))[as.length]? =
      some (some (.dependentFn (Tel.shiftV (tl :: .dependentFn t :: as).length 0 t))) := by
    simpa only [Ty.shiftV, List.length_cons, Nat.add_comm 1, Nat.add_assoc] using
      bindParams_lookup_second Γ tl (.dependentFn t) as
  have hseq := indirect_sequence_core (as := tl :: .dependentFn t :: as) (j := as.length)
    (Q := Q) (R := R) (Δ := Δ) (ms := desugarExpr op .other lhs :: desugarExpr op .other f :: desugarExprs op args)
    hj (by simpa only [List.length_cons, Nat.add_comm 1, Nat.add_assoc] using hv)
    (by simpa only [List.length_cons, Nat.add_comm 1, Nat.add_assoc] using hle)
    (by simpa only [List.length_cons, Nat.add_comm 1, Nat.add_assoc] using hc) hb hR hA σ (.cons hl (.cons hf hms))
  simp only [letChain] at hseq
  rw [show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity] at hseq
  simpa [ExprCore, desugarExpr, callComp, hnd, desugarExprs_length, hlen, letChain,
    Val.renameList, Val.rename, List.range_one, Nat.add_comm 1] using hseq

theorem pipeApplyDirect_core {P B ks op Q Δ C Γ Φ R p lhs rhs tl t ds r e b ε}
    {D : Declarations} (hpv : rhs.PipeValue) (hh : CallHeadTy D B ks Q C Γ rhs t ds)
    (hv : ValsTel D B ks C Γ 1 (bindParams Γ [tl]) (liftMany 1 Φ)
      (ds.map (fun d => d.toVal.rename (· + 1)) ++ [.var 0]) (Tel.shiftV 1 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ [tl]) (liftMany 1 Φ) r (b.shiftV 1 0))
    (hc : Eff.Covers (bindParams Γ [tl]) (liftMany 1 Φ) (Eff.shiftV 1 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs tl ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.pipe lhs rhs) b ε σ.val := by
  obtain ⟨h, hd⟩ : ∃ h, directCallee rhs = some h := by cases hh <;> exact ⟨_, rfl⟩
  have hseq := direct_sequence_core (as := [tl]) (ws := [.var 0]) (R := R) (Δ := Δ)
    (ms := [desugarExpr op .other lhs]) hh hd hv hle hc hb rfl hR hA σ (.cons hl .nil)
  simp only [letChain] at hseq
  rw [show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity] at hseq
  unfold ExprCore
  rw [desugarExpr_pipe_value hpv]
  simpa [callComp, hd, Val.renameList, Val.rename, List.range_one, recordFields, fieldAt, boundVars, letChain] using hseq

theorem pipeApply_core {P B ks op Q Δ C Γ Φ R p lhs rhs tl t r e b ε}
    {D : Declarations} (hpv : rhs.PipeValue) (hnd : directCallee rhs = none)
    (hv : ValsTel D B ks C Γ 2 (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ)
      [.var 1] (Tel.shiftV 2 0 t) r e)
    (hle : Ty.LeQ D.core (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ) r (b.shiftV 2 0))
    (hc : Eff.Covers (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) e)
    (hb : Ty.AnnotationR D.core ks C Γ b) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hl : ExprCore P B op Q Δ C Γ Φ R .other lhs tl ε σ.val)
    (hf : ExprCore P B op Q Δ C Γ Φ R .other rhs (.dependentFn t) ε σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.pipe lhs rhs) b ε σ.val := by
  have hj : (bindParams Γ [tl, .dependentFn t])[0]? = some (some (.dependentFn (Tel.shiftV 2 0 t))) := by
    simpa only [Ty.shiftV, List.length_nil, Nat.zero_add] using bindParams_lookup_second Γ tl (.dependentFn t) []
  have hseq := indirect_sequence_core (as := [tl, .dependentFn t]) (j := 0) (Q := Q) (R := R) (Δ := Δ)
    (ms := [desugarExpr op .other lhs, desugarExpr op .other rhs]) hj hv hle hc hb hR hA σ
    (.cons hl (.cons hf .nil))
  simp only [letChain] at hseq
  rw [show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity] at hseq
  unfold ExprCore
  rw [desugarExpr_pipe_value hpv]
  simpa [callComp, hnd, Val.renameList, Val.rename, List.range_one, recordFields, fieldAt, boundVars, letChain] using hseq

end
end Benitoite.Release.Refinement.Surface.OpenSurface
