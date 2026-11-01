import Benitoite.Release.Refinement.HandlerContinuation

/-! E_OpFail: 失敗の値が節の宣言の型に合うことと、Fail の節での切り出し。-/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem nohandler_tail {f : Frame} {k : Cont} {o} (h : NoHandler (f :: k) o) : NoHandler k o :=
  fun cap cs hm => h cap cs (List.mem_cons_of_mem _ hm)

private theorem union_fail {e f : Eff} {t} (h : (Eff.union e f).memFail t) : e.memFail t ∨ f.memFail t := by
  have h' := (Eff.norm_memFail _ _).mp h
  obtain ⟨x,hx,he⟩ := h'
  rcases List.mem_append.mp hx with hx | hx
  · exact Or.inl ⟨x,hx,he⟩
  · exact Or.inr ⟨x,hx,he⟩

private theorem failure_handles' {P B Ψ Q C Γ Φ E R cs t ec L}
    (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t ec L) : handles cs .fail = true := by
  cases h; simp [handles,Clause.op]

/-- 型の付いた継続のもとの Fail は、処理する節の宣言の型と正規形で一致する。 -/
theorem ContTy.fail_input {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2 E'}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) (hn : NoHandler k1 .fail)
    (hf : ε.memFail E') :
    ∃ R1 Γ Φ Es Rs ts ecs, CaptureOk P B (hideBuilders Ψ) R1 Γ Φ cap ∧
      HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ Es Rs [.fail E0 body] ts ecs [] ∧
      (cap.closeTy Es).norm = E'.norm := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ _ ih => exact ih he hn hf
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih | K_Release _ _ _ _ _ ih | K_Drop _ _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2 (nohandler_tail hn) hf
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih =>
    obtain ⟨_,hx,_⟩ := hf; cases hx
  | K_Handle ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    cases k1 with
    | nil => cases he; cases hcs
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      refine ih he.2 (nohandler_tail hn) ?_
      rcases union_fail (hb.2 _ hf) with h | h
      · exact hc.2 _ h
      · obtain ⟨_,hx,_⟩ := h; cases hx
  | K_Handle_Fail ht hc hnf hcap hcs hR hty hec hE hrd hcov ha had ih =>
    cases k1 with
    | nil =>
      cases he
      rcases union_fail hf with h | h
      · obtain ⟨x,hx,hxe⟩ := h
        simp only [Eff.singleFail,Eff.fails,List.mem_singleton] at hx
        subst x
        refine ⟨_,_,_,_,_,_,_,hcap,hcs,?_⟩
        rw [hE, ←hxe, Ty.norm_idem]
      · obtain ⟨_,hx,_⟩ := h
        rw [hnf.1] at hx; cases hx
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      obtain ⟨rfl,he2⟩ := he
      have hh := hn _ _ List.mem_cons_self
      rw [failure_handles' hcs] at hh; cases hh

/-- Fail の節での切り出し。保存する継続の行は末尾の原子と節の Fail から作る。 -/
theorem ContTy.split_fail {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) :
    ∃ t ec et Rh, ContTy P B σ Ψ R ε (k1 ++ [.handleF cap [.fail E0 body]]) a t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧ Eff.Sub (.mk et.atoms ec.fails) et := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ hl ih =>
    obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
    exact ⟨t,ec,et,Rh,.K_Sub h1 hl,h2,h3,h4⟩
  | K_Let hq had ha hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Let hq had ha hs h1,h2,h3,h4⟩
  | K_Mark _ ha ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Mark h1 ha,h2,h3,h4⟩
  | K_Update hl ha _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Update hl ha h1,h2,h3,h4⟩
  | K_Release hv had hr hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Release hv had hr hs h1,h2,h3,h4⟩
  | K_Drop hl hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Drop hl hs h1,h2,h3,h4⟩
  | K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp _ had ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp h1 had,h2,h3,h4⟩
  | K_Handle ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    cases k1 with
    | nil => cases he; cases hcs
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Handle h1 hc hb hcap hcs hR hty hec heb ha has hr had,h2,h3,h4⟩
  | @K_Handle_Fail R0 ε0 ec0 rest E cap0 cs0 tail t0 b0 E0' Re0 Γ Φ Rs ts ecs Es
      ht hc hnf hcap hcs hR hty hec hE hr hcov ha had ih =>
    cases k1 with
    | nil =>
      cases he
      have hsub : Eff.Sub (.mk ε0.atoms ec0.fails) (.mk ε0.atoms ec0.fails) := ⟨fun _ h => h,fun _ h => h⟩
      refine ⟨_,ec0,ε0,_,?_,ht,hcov,hcov.widen_atoms.2⟩
      refine .K_Handle_Fail (ε := .mk ε0.atoms ec0.fails) (rest := rest) (ec := ec0) (.K_Empty hsub ha) ?_ hnf hcap hcs hR hty hec hE hr ?_ ha had
      · exact ⟨fun a ha => hc.1 a ha,fun t ht => by obtain ⟨_,hx,_⟩ := ht; rw [hnf.1] at hx; cases hx⟩
      · exact ⟨fun a ha => hcov.1 a ha,fun _ h => h⟩
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Handle_Fail h1 hc hnf hcap hcs hR hty hec hE hr hcov ha had,h2,h3,h4⟩

end
end Benitoite.Release.Refinement