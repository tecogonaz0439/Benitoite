import Benitoite.Release.Refinement.BuilderStateLeaves

/-! # 継続の末尾の効果と保存する解放枠の不変条件 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem cont_covered_name {outer inner : Eff} {name ix}
    (hc : Eff.Covers [] [] outer inner) (hm : inner.mem (.name name ix)) :
    ∃ jx, outer.mem (.name name jx) ∧ (Atom.name name jx).Covers (.name name ix) := by
  obtain ⟨a,ha,hcov⟩ := hc.1 _ hm
  obtain ⟨jx,rfl⟩ := hcov.name_right
  exact ⟨jx,ha,hcov⟩

theorem ContTy.name_end_ix {P B σ Ψ R e k a b Eb Re name ix}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (hm : e.mem (.name name ix))
    (hn : ∀ cap cs jx, Frame.handleF cap cs ∈ k → ¬(handled P B cs).mem (.name name jx)) :
    ∃ jx, Eb.mem (.name name jx) ∧ (Atom.name name jx).Covers (.name name ix) := by
  induction h generalizing ix with
  | K_Empty he _ => exact ⟨ix,he.1 _ hm,.refl _⟩
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih | K_Release _ _ _ _ _ ih | K_Drop _ _ _ ih =>
    exact ih hm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))
  | K_Sub _ _ ih => exact ih hm hn
  | @K_Handle R e ec eb cap cs tail t b Eb Re Γ Φ Rs ts ecs ebs
      hk hc hb hcap hcs hR ht hec heb ha has hr had ih =>
    have hmem := hb.1 _ hm
    rcases (Eff.mem_union_iff _ _ _).mp hmem with hmem | hmem
    · obtain ⟨jx,hj,hcover⟩ := cont_covered_name hc hmem
      obtain ⟨kx,hk,hcov⟩ := ih hj (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))
      exact ⟨kx,hk,hcov.trans hcover⟩
    · exact False.elim (hn cap cs ix List.mem_cons_self hmem)
  | K_Handle_Fail hk hc _ _ _ _ _ _ _ _ _ _ _ ih =>
    rcases (Eff.mem_union_iff _ _ _).mp hm with hm | hm
    · cases hm
    · obtain ⟨jx,hj,hcover⟩ := cont_covered_name hc hm
      obtain ⟨kx,hk,hcov⟩ := ih hj (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))
      exact ⟨kx,hk,hcov.trans hcover⟩
  | K_Guard => cases hm

theorem ContTy.mono_end {P B σ Ψ R e k a b Eb Eb' Re}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (he : Eff.Sub Eb Eb') :
    ContTy P B σ Ψ R e k a b Eb' Re := by
  induction h with
  | K_Empty hs ha => exact .K_Empty ⟨fun x hx => he.1 x (hs.1 x hx),fun t ht => he.2 t (hs.2 t ht)⟩ ha
  | K_Let hq had ha hs _ ih => exact .K_Let hq had ha hs (ih he)
  | K_Mark _ ha ih => exact .K_Mark (ih he) ha
  | K_Update hl ha _ ih => exact .K_Update hl ha (ih he)
  | K_Release hv had hr hs _ ih => exact .K_Release hv had hr hs (ih he)
  | K_Drop hl hs _ ih => exact .K_Drop hl hs (ih he)
  | K_Handle _ hc hb hcap hcs hR ht hec heb ha has hr had ih =>
    exact .K_Handle (ih he) hc hb hcap hcs hR ht hec heb ha has hr had
  | K_Handle_Fail _ hc hn hcap hcs hR ht hec hE hr hcov ha had ih =>
    exact .K_Handle_Fail (ih he) hc hn hcap hcs hR ht hec hE hr hcov ha had
  | K_Guard hcap hv ho hs hl har hr hx hval hR ha heq hbody hsub hp _ had ih =>
    exact .K_Guard hcap hv ho hs hl har hr hx hval hR ha heq hbody hsub hp (ih he) had
  | K_Sub _ hl ih => exact .K_Sub (ih he) hl

def FramesOk (P : Program) (B : Builtins) (Ψ : StoreTy) (Eb : Eff) (k : Cont) : Prop :=
  ∀ f ∈ k, match f with
    | .release v => (∃ o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) ∧ B.isResource o = true) ∧
        Eb.mem (.name stateEff (.fixed .top))
    | .drop l => ∃ a t e r, Ψ l = some (.cont a t e r) ∧
        (e.mem (.name stateEff (.fixed .top)) → Eb.mem (.name stateEff (.fixed .top)))
    | _ => True

theorem ContTy.framesOk {P B σ Ψ R e k a b Eb Re} (hN : NoStateHandled P B)
    (h : ContTy P B σ Ψ R e k a b Eb Re) : FramesOk P B Ψ Eb k := by
  induction h with
  | K_Empty => intro f hf; cases hf
  | K_Sub _ _ ih => exact ih
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih | K_Handle _ _ _ _ _ _ _ _ _ _ _ _ _ ih | K_Handle_Fail _ _ _ _ _ _ _ _ _ _ _ _ _ ih | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih =>
    intro f hf
    rcases List.mem_cons.mp hf with rfl | hf
    · trivial
    · exact ih f hf
  | K_Release hv _ hr hs hk ih =>
    intro f hf
    rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨⟨_,hv,hr⟩,hk.state_end hN hs⟩
    · exact ih f hf
  | K_Drop hl hs hk ih =>
    intro f hf
    rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨_,_,_,_,hl,fun hm => hk.state_end hN (hs hm)⟩
    · exact ih f hf

private theorem releases_kind {k : Cont} {f : Frame} (h : f ∈ releases k) :
    (∃ v, f = .release v) ∨ ∃ l, f = .drop l := by
  induction k with
  | nil => cases h
  | cons g k ih =>
    cases g <;> simp only [releases] at h
    all_goals first
      | exact ih h
      | (rcases List.mem_cons.mp h with rfl | h
         · first | exact Or.inl ⟨_,rfl⟩ | exact Or.inr ⟨_,rfl⟩
         · exact ih h)

private theorem prepend_frames {P B σ Ψ R e k a b Eb Re saved}
    (hk : ContTy P B σ Ψ R e k a b Eb Re) (hf : FramesOk P B Ψ e saved)
    (hr : ∀ f ∈ saved, (∃ v, f = .release v) ∨ ∃ l, f = .drop l)
    (had : saved.Adequate σ) : ContTy P B σ Ψ R e (saved++k) a b Eb Re := by
  induction saved with
  | nil => exact hk
  | cons f fs ih =>
    have ht := ih (fun f hm => hf f (List.mem_cons_of_mem _ hm))
      (fun f hm => hr f (List.mem_cons_of_mem _ hm)) (fun f hm => had f (List.mem_cons_of_mem _ hm))
    rcases hr f List.mem_cons_self with ⟨v,rfl⟩ | ⟨l,rfl⟩
    · obtain ⟨⟨o,hv,ho⟩,hs⟩ := hf _ List.mem_cons_self
      exact .K_Release hv (had _ List.mem_cons_self) ho hs ht
    · obtain ⟨x,t,ec,r,hl,hs⟩ := hf _ List.mem_cons_self
      exact .K_Drop hl hs ht

/-- 保存継続の全解放枠を、末尾の State の条件を通して前置する。 -/
theorem ContTy.drop_releases {P B σ Ψ R e k a b Eb Re R0 e0 saved x t ec r}
    (hN : NoStateHandled P B) (hk : ContTy P B σ Ψ R e k a b Eb Re)
    (hs : ContTy P B σ Ψ R0 e0 saved x t ec r)
    (hc : ec.mem (.name stateEff (.fixed .top)) → e.mem (.name stateEff (.fixed .top))) :
    ContTy P B σ Ψ R e (releases saved++k) a b Eb Re := by
  have hframes := hs.framesOk hN
  apply prepend_frames hk
  · intro f hf
    have hh := hframes f (releases_mem f saved hf)
    rcases releases_kind hf with ⟨v,rfl⟩ | ⟨l,rfl⟩
    · exact ⟨hh.1,hc hh.2⟩
    · obtain ⟨x,t,ec,r,hl,hm⟩ := hh
      exact ⟨x,t,ec,r,hl,fun h => hc (hm h)⟩
  · exact fun _ hf => releases_kind hf
  · exact fun f hf => hs.adequate f (releases_mem f saved hf)

end
end Benitoite.Release.Refinement
