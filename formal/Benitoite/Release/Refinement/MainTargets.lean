import Benitoite.Release.Refinement.MainProgress

/-! # IO の事象の対象健全性

設計書 01-12「確かめる性質」の性質 3 のうち対象健全性を、一段の IO の事象について示す。継続の末尾に効果 Eb を固定した
状態の IO の事象の観測の対象は、その操作の名前の Eb の原子が σ の下で許す。事象の実引数の型付けは、閉じた view の
型付き実引数から得るので、プログラムの整形式と型付けを前提に読む。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- どの枠も処理しない組み込みの操作の効果の原子は、継続の末尾の効果へ同じ対象の許可を残す。 -/
theorem ContTy.allows_end {P B σ Ψ R e k a b Eb Re l bs b0 t}
    (hdecl : P.EffectsOk B) (h : ContTy P B σ Ψ R e k a b Eb Re)
    (he : B.effects l = some bs) (hb : b0 ∈ bs) (hn : NoHandler k (.prim b0))
    (ha : Eff.Allows σ B.effKind e l t) : Eff.Allows σ B.effKind Eb l t := by
  obtain ⟨kd,r,hk,hm,hr⟩ := ha
  obtain ⟨jx,hj,hc⟩ := h.name_end_ix hm (fun cap cs jx hf =>
    hdecl.operation_not_handled he hb (hn cap cs hf))
  obtain ⟨jx',rfl⟩ : ∃ s, jx = .fixed s := by
    cases jx with
    | fixed s => exact ⟨s,rfl⟩
    | rvar i => cases hc
  exact Eff.allows_of_mem_covers hk hj hc hr

private theorem adequate_member {σ vs} (h : adequateVals σ vs) : ∀ v ∈ vs, v.Adequate σ := by
  induction vs with
  | nil => intro v hv; cases hv
  | cons w ws ih =>
    intro v hv
    rcases List.mem_cons.mp hv with rfl | hv
    · exact h.1
    · exact ih h.2 v hv

/-- 組み込みの IO の呼出しの観測の対象は、継続の末尾の効果が許す。 -/
private theorem io_call_target {P B σ Eb q k μ b ts es rs ws sg out obs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (ht : B.TargetAgreement P) (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws) (hsig : B.sig b = some sg)
    (hk : sg.kind = .io ∨ sg.kind = .exit) (hn : NoHandler k (.prim b))
    (hr : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws out obs) :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind Eb l t := by
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,hsub,hcont,had,hcl,_⟩ := h
  obtain ⟨r,ef,hargs,_,hcov⟩ :=
    hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hsig
  have hsh := hB.io_op b sg hsig hk
  have hadq : ∀ w ∈ ws, w.Adequate σ := by
    have hva := Closure.view_adequate had
    rw [hv] at hva
    exact adequate_member hva.2
  obtain ⟨l,hop,hallow⟩ := ht.obs_allowed hsh hsig hk (hB.sig_scoped b sg hsig).names hargs hadq hr
  obtain ⟨l',bs,hop',_,he,hb,_⟩ := hsh
  rw [hop] at hop'
  cases Option.some.inj hop'
  exact ⟨sg,l,hsig,hop,fun t hmem =>
    hcont.allows_end hdecl he hb hn ((hcov.allows (hallow t hmem)).mono hsub)⟩

/-- 一段の対象健全性。継続の末尾に効果 Eb を固定した状態の IO の事象の観測の対象は、その操作の名前の Eb の原子が
σ の下で許す。 -/
theorem StateTyE.io_target_sound {P B σ Eb s s' b ws o obs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (ht : B.TargetAgreement P) (h : StateTyE P B σ Eb s)
    (hst : Step P B σ s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind Eb l t := by
  cases hst with
  | E_IO hv hsig hk hn hr => exact io_call_target hP hPB hdecl hB ht h hv hsig (.inl hk) hn hr
  | E_IOErr hv hsig hk hn hr => exact io_call_target hP hPB hdecl hB ht h hv hsig hk hn hr
  | E_Exit hv hsig hk hn hr => exact io_call_target hP hPB hdecl hB ht h hv hsig (.inr hk) hn hr

end
end Benitoite.Release.Refinement
