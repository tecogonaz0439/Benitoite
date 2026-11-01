import Lean
import Benitoite.Release.Refinement.HandlerOperation

open Lean Elab Command in
def rvAlias (m : Name) (s : String) : CommandElabM Unit := liftCoreM do
  let base := `Benitoite.Release.Refinement
  let priv := mkPrivateNameCore m (base ++ s.toName)
  let ci ← getConstInfo priv
  let nn : Name := Name.mkStr (base ++ `rv) s
  let v := mkConst priv (ci.levelParams.map mkLevelParam)
  addDecl (Declaration.thmDecl (TheoremVal.mk (ConstantVal.mk nn ci.levelParams ci.toConstantVal.type) v [nn]))

run_cmd do
  let p := `Benitoite.Release.Refinement.HandlerPreservation
  let o := `Benitoite.Release.Refinement.HandlerOperation
  rvAlias p "normal_return_tail"
  rvAlias p "closure_normal"
  rvAlias p "empty_annotation"
  rvAlias p "empty_sub"
  rvAlias p "closed_set"
  rvAlias o "covers_state"

namespace Benitoite.Release.Refinement
noncomputable section
open rv

abbrev S : Atom := .name stateEff (.fixed .top)

/-- 旧 handled_state に当たる条件。旧は EffectsOk と state_effect から導く。 -/
def NoStateHandled (P : Program) (B : Builtins) : Prop := ∀ h, ¬ (handled P B h).mem S

theorem union_mem {e f : Eff} {a} (h : (Eff.union e f).mem a) : e.mem a ∨ f.mem a := by
  simpa [Eff.mem,Eff.test,Eff.union,Eff.norm,Eff.atoms] using h

theorem state_end {P B σ Ψ R ε k a b Eb Re} (hN : NoStateHandled P B)
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hs : ε.mem S) : Eb.mem S := by
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

theorem prepend_releases {P B σ Ψ R0 e0 saved a0 t ec r} (hN : NoStateHandled P B)
    (hs : ContTy P B σ Ψ R0 e0 saved a0 t ec r)
    {R ε k a b Eb Re} (hk : ContTy P B σ Ψ R ε k a b Eb Re)
    (hc : ec.mem S → ε.mem S) : ContTy P B σ Ψ R ε (releases saved ++ k) a b Eb Re := by
  induction hs with
  | K_Empty => exact hk
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih => simpa [releases] using ih hc
  | K_Handle _ _ _ _ _ _ _ _ _ _ _ _ _ ih => simpa [releases] using ih hc
  | K_Handle_Fail _ _ _ _ _ _ _ _ _ _ _ _ _ ih => simpa [releases] using ih hc
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih => simpa [releases] using ih hc
  | K_Sub _ _ ih => exact ih hc
  | K_Release hv had hr hm ht ih =>
    exact .K_Release hv had hr (hc (state_end hN ht hm)) (ih hc)
  | K_Drop hl hcond ht ih =>
    exact .K_Drop hl (fun h => hc (state_end hN ht (hcond h))) (ih hc)

theorem drop_inv' {P B σ Ψ R e k a b Eb Re l}
    (h : ContTy P B σ Ψ R e (.drop l :: k) a b Eb Re) :
    ∃ t b' t' e' R', Ψ l = some (.cont b' t' e' R') ∧ (e'.mem S → e.mem S) ∧
      Ty.LeQ [] [] a t ∧ ContTy P B σ Ψ R e k t b Eb Re := by
  generalize he : (.drop l :: k) = frames at h
  induction h with
  | K_Drop hl hc ht => cases he; exact ⟨_,_,_,_,_,hl,hc,.refl,ht⟩
  | K_Sub _ hl ih =>
    obtain ⟨t,b',t',e',R',hp,hc,hle,ht⟩ := ih he
    exact ⟨t,b',t',e',R',hp,hc,.trans hl hle,ht⟩
  | _ => cases he

theorem rvRel (f : Frame) (k : Cont) (h : f ∈ releases k) : f ∈ k ∧ True := by
  induction k with
  | nil => simp [releases] at h
  | cons g k ih =>
    cases g with
    | release v | drop l =>
      simp only [releases,List.mem_cons] at h
      rcases h with rfl | h
      · exact ⟨List.mem_cons_self,trivial⟩
      · exact ⟨List.mem_cons_of_mem _ (ih h).1,trivial⟩
    | _ =>
      simp only [releases] at h
      exact ⟨List.mem_cons_of_mem _ (ih h).1,trivial⟩

/-- E_DropRel は、旧の前提 NoStateHandled を足せば現在の定義のまま定数の view で閉じる。 -/
theorem StateTyE.drop_rel_const {P B σ Eb q c l k μ saved} (hN : NoStateHandled P B)
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret (.const c)) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) (releases saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨t,b',t',e',R',hp,hcond,hle,ht⟩ := drop_inv' hk
  have hv' := hq.ret_const hA.substitutions hs.wf hv
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  obtain ⟨x,t2,e2,r2,hp2,_,R0,e0,hsv⟩ := hs.2.2.2.2 l _ hl
  cases Option.some.inj (hp2.symm.trans hp)
  have ht2 := prepend_releases hN hsv ht hcond
  obtain ⟨R2,hRn,ht3⟩ := normal_return_tail ht2 rfl a ha (closure_normal hq) hle
  have hr := ContTy.return_annotation ht3 rfl
  have hq' := ClosureTy.pure (.C_Return (R := R2) hv') (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) (closure_normal hq) hRn
  refine ⟨.E_DropRel hv hl,Ψ,R2,a,b,e,Eff.empty,hs.use_continuation hp,hq',empty_sub e,ht3,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,?_,closed_set hμ trivial⟩
  intro f hf
  rcases List.mem_append.mp hf with hf | hf
  · have hc := hμ l _ hl
    obtain ⟨hmem,_⟩ := by
      have := Benitoite.Release.Refinement.rvRel f saved hf
      exact this
    exact hc f hmem
  · exact hkc f (List.mem_cons_of_mem _ hf)

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.StateTyE.drop_rel_const
