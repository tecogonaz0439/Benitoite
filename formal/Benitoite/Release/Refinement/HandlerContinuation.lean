import Benitoite.Release.Refinement.LazyPreservation
import Benitoite.Release.Refinement.HeldValues

/-! # 捕捉を保持するハンドラの切り出しと継続の接続 -/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

def HandlerFrameTy (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty)
    (cap : Capture) (h : List Clause) (t : Ty) (ec eb : Eff) : Prop :=
  ∃ Γ Φ Rs ts ecs ebs,
    CaptureOk P B (hideBuilders Ψ) R Γ Φ cap ∧
    HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs ebs h ts ecs [] ∧
    cap.closeR Rs = R ∧ cap.closeTy ts = t ∧ cap.closeEff ecs = ec ∧ cap.closeEff ebs = eb ∧
    Ty.Annotation P [] [] (.dependentFn (.done t ec)) ∧
    Ty.Annotation P [] Γ ts ∧ (∀ a, Rs = some a → a.Declared P [] Γ)

theorem ContTy.nil_inv {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hk : k = []) :
    Ty.LeQ P [] [] a b ∧ Eff.Sub ε Eb ∧ R = Re ∧ Ty.Annotation P [] [] b := by
  induction h with
  | K_Empty he ha => exact ⟨.refl,he,rfl,ha⟩
  | K_Sub _ hl ih =>
    obtain ⟨hl',he,hr,ha⟩ := ih hk
    exact ⟨.trans hl hl',he,hr,ha⟩
  | _ => cases hk

private theorem end_tail {f : Frame} {k : Cont} (h : EndsWithHandle (f :: k)) (hk : k ≠ []) :
    EndsWithHandle k := by
  obtain ⟨kp,cap,cs,he⟩ := h
  cases kp with
  | nil => exact False.elim (hk (List.cons.inj he).2)
  | cons g kp => exact ⟨kp,cap,cs,(List.cons.inj he).2⟩

private theorem end_tail' {f : Frame} {k : Cont} (h : EndsWithHandle (f :: k))
    (hf : ∀ cap cs, f ≠ .handleF cap cs) : EndsWithHandle k := by
  obtain ⟨kp,cap,cs,he⟩ := h
  cases kp with
  | nil => exact False.elim (hf cap cs (List.cons.inj he).1)
  | cons g kp => exact ⟨kp,cap,cs,(List.cons.inj he).2⟩

theorem ContTy.resume_append {P B σ Ψ R ε saved a t ec Rh}
    (hs : ContTy P B σ Ψ R ε saved a t ec Rh) (hend : EndsWithHandle saved)
    {k u b Eb Re e} (hl : Ty.LeQ P [] [] t u)
    (hk : ContTy P B σ Ψ Rh e k u b Eb Re) (he : Eff.Covers [] [] e ec) :
    ContTy P B σ Ψ R ε (saved ++ k) a b Eb Re := by
  induction hs generalizing u with
  | K_Empty _ _ => obtain ⟨kp,cap,cs,h⟩ := hend; simp at h
  | K_Let hq had ha hsub _ ih =>
    exact .K_Let hq had ha hsub (ih (end_tail' hend (by intro cap cs h; cases h)) hl hk he)
  | K_Mark _ ha ih => exact .K_Mark (ih (end_tail' hend (by intro cap cs h; cases h)) hl hk he) ha
  | K_Update hp ha _ ih => exact .K_Update hp ha (ih (end_tail' hend (by intro cap cs h; cases h)) hl hk he)
  | K_Release hv had hr hm _ ih =>
    exact .K_Release hv had hr hm (ih (end_tail' hend (by intro cap cs h; cases h)) hl hk he)
  | K_Drop hp hm _ ih => exact .K_Drop hp hm (ih (end_tail' hend (by intro cap cs h; cases h)) hl hk he)
  | K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp _ had ih =>
    exact .K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp
      (ih (end_tail' hend (by intro cap cs h; cases h)) hl hk he) had
  | K_Sub _ hle ih => exact .K_Sub (ih hend hl hk he) hle
  | @K_Handle R0 ε0 ec0 eb0 cap cs tail t0 b0 E0 Re0 Γ Φ Rs ts ecs ebs
      ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    by_cases hn : tail = []
    · subst tail
      obtain ⟨hle,hsub,hR0,_⟩ := ht.nil_inv rfl
      subst Re0
      exact .K_Handle (.K_Sub hk (.trans hle hl)) ((he.trans hsub.covers).trans hc)
        hb hcap hcs hR hty hec heb ha has hr had
    · exact .K_Handle (ih (end_tail hend hn) hl hk he) hc hb hcap hcs hR hty hec heb ha has hr had
  | @K_Handle_Fail R0 ε0 ec0 rest E cap cs tail t0 b0 E0 Re0 Γ Φ Rs ts ecs Es
      ht hc hn hcap hcs hR hty hec hE hr hcov ha had ih =>
    by_cases hnil : tail = []
    · subst tail
      obtain ⟨hle,hsub,hR0,_⟩ := ht.nil_inv rfl
      subst Re0
      exact .K_Handle_Fail (.K_Sub hk (.trans hle hl)) ((he.trans hsub.covers).trans hc)
        hn hcap hcs hR hty hec hE hr ((he.trans hsub.covers).trans hcov) ha had
    · exact .K_Handle_Fail (ih (end_tail hend hnil) hl hk he) hc hn hcap hcs hR hty hec hE hr hcov ha had

private theorem failure_handles {P B Ψ Q C Γ Φ E R cs t ec L}
    (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t ec L) : handles cs .fail = true := by
  cases h
  simp [handles,Clause.op]

private theorem covered_name {outer inner : Eff} {l ix}
    (hc : Eff.Covers [] [] outer inner) (hm : inner.mem (.name l ix)) :
    ∃ jx, outer.mem (.name l jx) ∧ jx.Covers ix := by
  obtain ⟨a,ha,hcov⟩ := hc.1 _ hm
  obtain ⟨jx,rfl⟩ := hcov.name_right
  refine ⟨jx,ha,?_⟩
  cases jx <;> cases ix <;> first | contradiction | exact hcov.2

private theorem union_name_mem {e f : Eff} {a : Atom}
    (hm : (Eff.union e f).mem a) : e.mem a ∨ f.mem a := by
  change (e.atoms a || f.atoms a) = true at hm
  simpa only [Bool.or_eq_true] using hm

private theorem handle_name {eb ec et : Eff} {P B cs l ix}
    (hb : Eff.Sub eb (Eff.union ec (handled P B cs)))
    (hc : Eff.Covers [] [] et ec) (hm : eb.mem (.name l ix))
    (hn : ∀ jx, ¬ (handled P B cs).mem (.name l jx)) :
    ∃ jx, et.mem (.name l jx) ∧ jx.Covers ix := by
  rcases union_name_mem (hb.1 _ hm) with hm | hm
  · exact covered_name hc hm
  · exact False.elim (hn ix hm)

private theorem failure_name {rest ec : Eff} {E l ix}
    (hc : Eff.Covers [] [] ec rest)
    (hm : (Eff.union (Eff.singleFail E) rest).mem (.name l ix)) :
    ∃ jx, ec.mem (.name l jx) ∧ jx.Covers ix := by
  rcases union_name_mem hm with hm | hm
  · cases hm
  · exact covered_name hc hm

theorem ContTy.split_handle {P B σ Ψ R ε k a b Eb Re cap cs k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap cs :: k2) (hn : handles cs .fail = false) :
    ∃ t ec eb et Rh,
      ContTy P B σ Ψ R ε (k1 ++ [.handleF cap cs]) a t ec Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧
      Eff.Sub eb (Eff.union ec (handled P B cs)) ∧
      HandlerFrameTy P B Ψ Rh cap cs t ec eb ∧
      (∀ l ix, ε.mem (.name l ix) →
        (∀ cap' cs' jx, Frame.handleF cap' cs' ∈ k1 → ¬ (handled P B cs').mem (.name l jx)) →
        ∃ jx, eb.mem (.name l jx) ∧ jx.Covers ix) := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ hl ih =>
    obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
    exact ⟨t,ec,eb,et,Rh,.K_Sub h1 hl,h2,h3,h4,h5,h6⟩
  | K_Let hq had ha hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Let hq had ha hs h1,h2,h3,h4,h5,by
        intro l ix hm hn
        exact h6 l ix hm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))⟩
  | K_Mark _ ha ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Mark h1 ha,h2,h3,h4,h5,by
        intro l ix hm hn
        exact h6 l ix hm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))⟩
  | K_Update hl ha _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Update hl ha h1,h2,h3,h4,h5,by
        intro l ix hm hn
        exact h6 l ix hm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))⟩
  | K_Release hv had hr hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Release hv had hr hs h1,h2,h3,h4,h5,by
        intro l ix hm hn
        exact h6 l ix hm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))⟩
  | K_Drop hl hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Drop hl hs h1,h2,h3,h4,h5,by
        intro l ix hm hn
        exact h6 l ix hm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))⟩
  | K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp _ had ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp h1 had,h2,h3,h4,h5,by
        intro l ix hm hn
        cases hm⟩
  | K_Handle ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    cases k1 with
    | nil =>
      cases he
      exact ⟨_,_,_,_,_,.K_Handle (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩)
        (.refl _ _ _) hb hcap hcs hR hty hec heb ha has hr had,
        ht,hc,hb,⟨_,_,_,_,_,_,hcap,hcs,hR,hty,hec,heb,ha,has,hr⟩,by
          intro l ix hm _
          exact ⟨ix,hm,RangeIx.Covers.refl ix⟩⟩
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Handle h1 hc hb hcap hcs hR hty hec heb ha has hr had,h2,h3,h4,h5,by
        intro l ix hm hn
        obtain ⟨jx,hjm,hji⟩ := handle_name hb hc hm (fun jx => by apply hn _ _ jx; exact List.mem_cons_self)
        obtain ⟨kx,hkm,hkj⟩ := h6 l jx hjm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))
        exact ⟨kx,hkm,hkj.trans hji⟩⟩
  | K_Handle_Fail ht hc hnf hcap hcs hR hty hec hE hr hcov ha had ih =>
    cases k1 with
    | nil => cases he; rw [failure_handles hcs] at hn; cases hn
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,eb,et,Rh,h1,h2,h3,h4,h5,h6⟩ := ih he
      exact ⟨t,ec,eb,et,Rh,.K_Handle_Fail h1 hc hnf hcap hcs hR hty hec hE hr hcov ha had,h2,h3,h4,h5,by
        intro l ix hm hn
        obtain ⟨jx,hjm,hji⟩ := failure_name hc hm
        obtain ⟨kx,hkm,hkj⟩ := h6 l jx hjm (fun cap cs jx hf => hn cap cs jx (List.mem_cons_of_mem _ hf))
        exact ⟨kx,hkm,hkj.trans hji⟩⟩

end
end Benitoite.Release.Refinement
