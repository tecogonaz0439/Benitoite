import Benitoite.Release.Refinement.HandlerStore

/-! # State の予約と継続の破棄時の解放の効果 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 旧体系と同じ、操作の宣言の対応と組み込み名との分離。 -/
def Program.EffectsOk (P : Program) (B : Builtins) : Prop :=
  (∀ l os o, P.effects l = some os → o ∈ os → ∃ od, P.ops o = some od ∧ od.eff = l) ∧
    (∀ o od, P.ops o = some od → ∃ os, P.effects od.eff = some os ∧ o ∈ os) ∧
    (∀ l os, P.effects l = some os → B.effects l = none)

private theorem covers_state {outer inner : Eff} (h : Eff.Covers [] [] outer inner)
    (hm : inner.mem (.name stateEff (.fixed .top))) : outer.mem (.name stateEff (.fixed .top)) := by
  obtain ⟨a,ha,hcov⟩ := h.1 _ hm
  obtain ⟨ix,rfl⟩ := hcov.name_right
  cases ix with
  | rvar i => cases hcov
  | fixed r =>
    have hr : r = .top := (RangeExpr.covers_top_iff _).mp hcov.2
    rwa [hr] at ha

def NoStateHandled (P : Program) (B : Builtins) : Prop := ∀ h, ¬ (handled P B h).mem (.name stateEff (.fixed .top))

private theorem union_mem {e f : Eff} {a} (h : (Eff.union e f).mem a) : e.mem a ∨ f.mem a := by
  simpa [Eff.mem,Eff.test,Eff.union,Eff.norm,Eff.atoms] using h

theorem ContTy.state_end {P B σ Ψ R ε k a b Eb Re} (hN : NoStateHandled P B)
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hs : ε.mem (.name stateEff (.fixed .top))) : Eb.mem (.name stateEff (.fixed .top)) := by
  induction h with
  | K_Empty he _ => exact he.1 _ hs
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih | K_Release _ _ _ _ _ ih | K_Drop _ _ _ ih => exact ih hs
  | K_Sub _ _ ih => exact ih hs
  | K_Handle ht hc hb _ _ _ _ _ _ _ _ _ _ ih =>
    rcases union_mem (hb.1 _ hs) with h | h
    · exact ih (covers_state hc h)
    · exact False.elim (hN _ h)
  | K_Handle_Fail ht hc hn _ _ _ _ _ _ _ _ _ _ ih =>
    rcases union_mem hs with h | h
    · cases h
    · exact ih (covers_state hc h)
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih => cases hs

theorem ContTy.prepend_releases {P B σ Ψ R0 e0 saved a0 t ec r} (hN : NoStateHandled P B)
    (hs : ContTy P B σ Ψ R0 e0 saved a0 t ec r)
    {R ε k a b Eb Re} (hk : ContTy P B σ Ψ R ε k a b Eb Re)
    (hc : ec.mem (.name stateEff (.fixed .top)) → ε.mem (.name stateEff (.fixed .top))) : ContTy P B σ Ψ R ε (releases saved ++ k) a b Eb Re := by
  induction hs with
  | K_Empty => exact hk
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih => simpa [releases] using ih hc
  | K_Handle _ _ _ _ _ _ _ _ _ _ _ _ _ ih => simpa [releases] using ih hc
  | K_Handle_Fail _ _ _ _ _ _ _ _ _ _ _ _ _ ih => simpa [releases] using ih hc
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih => simpa [releases] using ih hc
  | K_Sub _ _ ih => exact ih hc
  | K_Release hv had hr hm ht ih =>
    exact .K_Release hv had hr (hc (ContTy.state_end hN ht hm)) (ih hc)
  | K_Drop hl hcond ht ih =>
    exact .K_Drop hl (fun h => hc (ContTy.state_end hN ht (hcond h))) (ih hc)


theorem Program.EffectsOk.noStateHandled {P B}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B) : NoStateHandled P B := by
  have hp : P.effects stateEff = none := by
    cases h : P.effects stateEff with
    | none => rfl
    | some os =>
      have hh := hdecl.2.2 _ _ h
      rw [hA.state_effect] at hh
      cases hh
  intro cs hm
  simp only [handled,effOps,hp,hA.state_effect,List.map_nil,Option.map_some,Eff.mem,Eff.test,Eff.atoms] at hm
  cases hm

end
end Benitoite.Release.Refinement
