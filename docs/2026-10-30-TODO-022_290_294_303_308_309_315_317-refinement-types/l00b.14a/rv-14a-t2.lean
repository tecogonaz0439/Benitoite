import Benitoite.Release.Refinement.DependentBeta
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeCQ.store_ext {P B store Q C Γ Φ R m a e L} (hb : HasTypeCQ P B store Q C Γ Φ R m a e L) {store'}
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.Extends store') :
    HasTypeCQ P B store' Q C Γ Φ R m a e L := by
  have hh := HasTypeCQ.shift_values hb (k := 0) (c := 0) hA hw hp
      ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
      (LocalCtx.Shift.refl _) (Ξ := _) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [Ty.shiftV_zero,Eff.shiftV_zero,shiftIndex_zero,Comp.rename_identity,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,id_eq] using hh

theorem hide_extends (Ψ : StoreTy) : (hideBuilders Ψ).Extends Ψ := by
  intro l t ht
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> cases ht <;> rfl

/-- hh を外し、本体を hideBuilders Ψ で受ける版（reached の型付けだけ）。 -/
theorem reached_general {P B σ Ψ name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B) (hW : Ψ.WF)
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B (hideBuilders Ψ) [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hk : ContTy P B σ Ψ none ε k (substTyValues (openValue v) a) b Eb none) :
    HasTypeV P B Ψ [] [] [] (.dependentLam (.param name x (.done a e)) body)
      (.dependentFn (.param name x (.done a e))) ∧
    ClosureTy P B Ψ [] (some (substTyValues (openValue v) a))
      ((Closure.pure body).apply [v])
      (substTyValues (openValue v) a) (substEffValues (openValue v) e) := by
  have hb' := hb.store_ext hA hW.hide (hide_extends Ψ)
  exact ⟨.V_DependentLam ht (.param (.done hb)), ClosureTy.dependent_one ht hn hb' hv hg⟩

/-- 本体を hideBuilders Ψ で受け hh を外した全文。 -/
theorem StateTyE.dependent_beta_any_store
    {P B σ Ψ μ name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B (hideBuilders Ψ) [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hk : ContTy P B σ Ψ none ε k (substTyValues (openValue v) a) b Eb none)
    (he : Eff.Sub (substEffValues (openValue v) e) ε)
    (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hcbody : body.ClosedAt 0 1) (hck : k.Closed) (hcμ : μ.Closed) :
    StateTyE P B σ Eb (.run ((Closure.pure body).apply [v]) (Refinement.markPush k) μ) := by
  have hW := hs.wf
  have htav := (SubstOk.openValue (R := none) hv
    ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩ (by simp [Ctx.WF])).telAnnotation
    (show Ty.Annotation P [] (Ctx.extend [] x) (.dependentFn (.done a e)) from
      ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ht.wf.2,
        ht.sorted.2,ht.declared.2⟩)
  have hca : Ty.Annotation P [] [] (substTyValues (openValue v) a) := ⟨htav.wf.1,htav.sorted.1,htav.declared.1⟩
  have hdst := (reached_general hA hW ht hn hb hv hg hk).2
  refine ⟨Ψ,_,_,b,ε,_,hs,hdst,he,hk.markPush hca,⟨⟨hval,trivial⟩,hbody⟩,⟨⟨hg,trivial⟩,hcbody⟩,?_,hcμ⟩
  have hm : ∀ f ∈ Refinement.markPush k, f = .mark ∨ f ∈ k := by
    intro f hf
    cases k with
    | nil => simpa [Refinement.markPush] using hf
    | cons f0 k => cases f0 <;> simp_all [Refinement.markPush]
  intro f hf
  rcases hm f hf with rfl | h
  · trivial
  · exact hck f h
#print axioms StateTyE.dependent_beta_any_store
end
end Benitoite.Release.Refinement
