import Benitoite.Release.Refinement.MatchPaths
/-! D19 が一般の束縛数でも破綻しない見通しの確認。任意の δ の腕まで歩き、
    一束縛の本体の ClosureTy を、評価の入力と束縛値の型付けだけから閉じる。 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeArmsQ.select_plain {P B Ψ Γ Φ R Rs obs arms a b e L cap vs v n alts body}
    (h : HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms a b e L)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (hi : arms[n]? = some (.mk alts none body))
    (he : MatchPathsEvaluated v arms n) :
    ∃ δ Ξ, AltsTy P alts a δ ∧ CaptureOk P B Ψ R Γ Ξ cap ∧
      HasTypeCQ P B Ψ Qempty [] (bindParams Γ δ) (liftMany δ.length Ξ)
        (Rs.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
        (localExtend δ.length L) := by
  match h with
  | .nil _ => simp at hi
  | .plain (δ := δ) hp hw hb hs =>
    cases n with
    | zero =>
      cases Option.some.inj hi
      have hc' := hc.addEvaluatedFacts (FactsWF.left (by simpa only [pathFacts_append] using hw))
        (hc.paths_evaluate ho hv (he.2 _ _ _ rfl))
      exact ⟨δ,_,hp,hc',hb⟩
    | succ n =>
      have hc' := hc.addEvaluatedFacts (FactsWF.right (by simpa only [pathFacts_append] using hw))
        (hc.paths_evaluate ho hv (he.1 0 _ _ _ rfl (by omega) rfl))
      exact hs.select_plain hc' ho hv hi ⟨
        (by intro i as g m hh hn hg; exact he.1 (i+1) as g m hh (by omega) hg),
        (by intro as g m hh; exact he.2 as g m hh)⟩
  | .guarded hp hw hgp hg hb hs =>
    cases n with
    | zero => cases Option.some.inj hi
    | succ n => exact hs.select_plain hc ho hv hi ⟨
        (by intro i as g m hh hn hg; exact he.1 (i+1) as g m hh (by omega) hg),
        (by intro as g m hh; exact he.2 as g m hh)⟩
termination_by n

/-- 一束縛の本体。入力は評価の成功から得た CaptureOk・束縛値の型付けと Ground・型の注釈、
    および置換とシフトの打ち消しの等式（標準の補題であり、ここでは入力に置く）だけである。 -/
theorem ClosureTy.body_one {P B Ψ Γ Ξ R Rs' cap s body L ρ w b' e'}
    (hW : Ψ.WF)
    (hc : CaptureOk P B Ψ R Γ Ξ cap)
    (hs : Ty.Annotation P [] Γ s)
    (hw : HasTypeVQ P B Ψ Qempty [] [] [] w (cap.closeTy s)) (hg : w.Ground)
    (hb : HasTypeCQ P B Ψ Qempty [] (bindParams Γ [s]) (liftMany 1 Ξ)
      Rs' body b' e' (localExtend 1 L))
    (hl : CaptureLocals Ψ cap.env L ρ)
    (ht : Ty.Annotation P [] [] (.dependentFn (.done ((cap.extend w).closeTy b') ((cap.extend w).closeEff e'))))
    (hR : (cap.extend w).closeR Rs' = R) (hr : ∀ r, Rs' = some r → r.Declared P [] (Γ.extend s)) :
    ClosureTy P B Ψ [] R (.mk (cap.extend w) (body.resolveLocals (upLocalSubst 1 ρ)))
      ((cap.extend w).closeTy b') ((cap.extend w).closeEff e') := by
  have hc1 := hc.extend hs hw hg
  have hb' : HasTypeCQ P B Ψ Qempty [] (Γ.extend s) (Ξ.map Pred.lift) Rs' body b' e' (localExtend 1 L) := by
    simpa [bindParams,Ctx.extend] using (show HasTypeCQ P B Ψ Qempty [] (bindParams Γ [s]) (Ξ.map Pred.lift) Rs' body b' e' (localExtend 1 L) from hb)
  have hl' := CaptureLocals.extendMany hW [w] hl
  simp only [Capture.extendMany,List.foldl_cons,List.foldl_nil,List.length_cons,List.length_nil] at hl'
  exact ClosureTy.capture_resolved_closed hc1 hb' hl' ht hR hr
end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.HasTypeArmsQ.select_plain
#print axioms Benitoite.Release.Refinement.ClosureTy.body_one
