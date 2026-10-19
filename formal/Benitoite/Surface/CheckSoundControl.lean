import Benitoite.Surface.CheckSoundCalls
import Benitoite.Surface.CheckSoundCollections
import Benitoite.Surface.CheckSoundDie

/-! 制御構文とハンドラの節の検査の健全性。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem raise_case {q t E} : CaseSound q (.expr (.raise t E)) := by
  intro ih Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  have h := guardInferred_ok h
  obtain ⟨u, hu, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hw := Bool.and_eq_true_iff.mp (require_ok hu).1
  rw [singleFailure_eq he.2]
  exact ⟨.E_Raise ((wfTy_spec _ _ he.1).mp hw.1) ((wfTy_spec _ _ he.2).mp hw.2),
    ⟨⟨he.2, trivial⟩, he.1, by simpa only [singleFailure_eq he.2] using singleFailure_atoms he.2⟩,
    emptyEff_atoms _⟩

theorem handleFail_case {q E t body clause} : CaseSound q (.expr (.handleFail E t body clause)) := by
  intro ih
  have ihb : BlockSound q body := ih (.block body) (by simp [CheckNode.size]; omega)
  have ihc : BlockSound q clause := ih (.block clause) (by simp [CheckNode.size]; omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  have h := guardInferred_ok h
  obtain ⟨u, hw, h⟩ := checking_lift_bind_ok h
  have hw := Bool.and_eq_true_iff.mp (require_ok hw).1
  obtain ⟨eb, mid, hb, heb, h, ht⟩ := checking_accept_block_ok
    (fun _ _ _ _ hc => ihb Δ _ _ _ _ _ _ _ _ _ hB hq he.2.2.1 hΓ hR hc) he.2.1 h
  obtain ⟨u, hnf, h⟩ := checking_lift_bind_ok h
  obtain ⟨u, hsub, h⟩ := checking_lift_bind_ok h
  have henv := failureEnv_atoms he.1 hΓ
  obtain ⟨eh, mid', hc, heh, h, htc⟩ := checking_accept_block_ok
    (fun _ _ _ _ hc => ihc [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq he.2.2.2 henv (returnAtoms_shift hR 1) hc)
    (shiftTy_atoms he.2.1 1 0) h
  let ec := substEffAt q.atoms 0 [.base .unit] [] eh
  have hec : ec.AtomsIn q.atoms := substEffAt_atoms (ts := [.base .unit]) (es := []) heh ⟨trivial, trivial⟩ (by simp) 0
  obtain ⟨u, hesc, h⟩ := checking_lift_bind_ok h
  have hesc := Bool.and_eq_true_iff.mp (require_ok hesc).1
  have hshift := effEq_sound (by rw [shiftEff_eq 1 0 ec hec]; exact Eff.shift_support 1 0 ec hec) heh hesc.2
  have hRest := remainingEffect_atoms heb
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, he.2.1, union_atoms hRest hec⟩
  rw [union_eq hRest hec]
  apply HasTypeQ.E_HandleFail hb
  · have hs := acceptEff_sound heb (union_atoms (singleFailure_atoms he.1) hRest) hsub
    rw [union_eq (singleFailure_atoms he.1) hRest, singleFailure_eq he.1] at hs
    exact hs
  · apply (noFailCheck_spec (effect_top_support hRest)).mp (require_ok hnf).1
  · exact Ty.VarsIn.wf _ ((cleanTy_spec _ _ he.1).mp hw.1)
  · exact Ty.VarsIn.wf _ ht
  · exact effect_wf_check hec hesc.1
  · have hshift' : eh = Eff.shift 1 0 ec := by
      rw [shiftEff_eq 1 0 ec hec] at hshift; exact hshift.symm
    simpa only [shiftTy_eq 1 0 E he.1, shiftTy_eq 1 0 t he.2.1,
      shiftEnv_eq 1 Γ (fun o ho t ht => by cases ht; exact hΓ t ho),
      shiftReturn_eq 1 R hR, hshift'] using hc

theorem lam_case {q names ps r eff body} : CaseSound q (.expr (.lam names ps r eff body)) := by
  intro ih
  have ihb := lam_case_ih ih
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨uNames, hnames, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hexit, h⟩ := checking_lift_bind_ok h
  obtain ⟨εb, mid, hb, hbAtoms, h, hbAtomsClean⟩ := checking_accept_block_ok
    (fun _ _ _ _ h => ihb [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq he.2.2.2
      (Env.atoms_append (Env.atoms_binds he.1) (Env.atoms_hideConts hΓ))
      (fun t ht => by cases ht; exact he.2.1) h) he.2.1 h
  obtain ⟨u2, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Lam ((namesWF_spec _ _).mp (require_ok hnames).1) ((lamBodyOk_spec _ _).mp (require_ok hexit).1)
    (.B_Sub hb (Or.inl rfl) (acceptEff_sound hbAtoms he.2.2.1 heff) hbAtomsClean),
    ⟨he.1, he.2.1, he.2.2.1⟩, emptyEff_atoms _⟩

theorem ite_case {q cond yes no} : CaseSound q (.expr (.ite cond yes no)) := by
  intro ih
  have ihc : ExprSound q cond := ih (.expr cond) (by simp [CheckNode.size] <;> omega)
  have ihy : BlockSound q yes := ih (.block yes) (by simp [CheckNode.size] <;> omega)
  have ihn : BlockSound q no := ih (.block no) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have hSingle := (guardInferred_result h).2
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εc, mid, hc, hcAtoms, h, hcAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihc Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨⟨ay, εy⟩, mid', hy, h⟩ := checking_bind_ok h
  obtain ⟨⟨an, εn⟩, mid'', hn, h⟩ := checking_bind_ok h
  obtain ⟨out, hj, h⟩ := checking_lift_bind_ok h
  have ys := ihy Δ _ _ _ _ _ _ _ _ _ hB hq he.2.1 hΓ hR hy
  have ns := ihn Δ _ _ _ _ _ _ _ _ _ hB hq he.2.2 hΓ hR hn
  have hjoin := join_sound ys.2.1 ns.2.1 hj
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hSafe : SingleTy (NoFailCtxOf q.noFailRows) a ∧ SingleEff (NoFailCtxOf q.noFailRows) (union q εc (union q εy εn)) :=
    ⟨(singleTyCheck_spec _ (join_atoms ys.2.1 ns.2.1 hj)).mp hSingle.1,
      (singleEffCheck_spec _ (union_atoms hcAtoms (union_atoms ys.2.2 ns.2.2))).mp hSingle.2⟩
  refine ⟨?_, join_atoms ys.2.1 ns.2.1 hj, union_atoms hcAtoms (union_atoms ys.2.2 ns.2.2)⟩
  rw [union_eq hcAtoms (union_atoms ys.2.2 ns.2.2), union_eq ys.2.2 ns.2.2] at hSafe ⊢
  apply HasTypeQ.E_If hc (.B_Sub ys.1 hjoin.1 (Eff.Sub.refl _) (join_clean (join_atoms ys.2.1 ns.2.1 hj) hj)) (.B_Sub ns.1 hjoin.2 (Eff.Sub.refl _) (join_clean (join_atoms ys.2.1 ns.2.1 hj) hj))
  exact hSafe

theorem elseIf_case {q cond yes no} : CaseSound q (.expr (.elseIf cond yes no)) := by
  intro ih
  have ihc : ExprSound q cond := ih (.expr cond) (by simp [CheckNode.size] <;> omega)
  have ihy : BlockSound q yes := ih (.block yes) (by simp [CheckNode.size] <;> omega)
  have ihn : ExprSound q no := ih (.expr no) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have hSingle := (guardInferred_result h).2
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u, hisIf, h⟩ := checking_lift_bind_ok h
  obtain ⟨εc, mid, hc, hcAtoms, h, hcAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihc Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨⟨ay, εy⟩, mid', hy, h⟩ := checking_bind_ok h
  obtain ⟨⟨an, εn⟩, mid'', hn, h⟩ := checking_bind_ok h
  obtain ⟨out, hj, h⟩ := checking_lift_bind_ok h
  have ys := ihy Δ _ _ _ _ _ _ _ _ _ hB hq he.2.1 hΓ hR hy
  have ns := ihn Δ _ _ _ _ _ _ _ _ _ hB hq he.2.2 hΓ hR hn
  have hjoin := join_sound ys.2.1 ns.2.1 hj
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hSafe : SingleTy (NoFailCtxOf q.noFailRows) a ∧ SingleEff (NoFailCtxOf q.noFailRows) (union q εc (union q εy εn)) :=
    ⟨(singleTyCheck_spec _ (join_atoms ys.2.1 ns.2.1 hj)).mp hSingle.1,
      (singleEffCheck_spec _ (union_atoms hcAtoms (union_atoms ys.2.2 ns.2.2))).mp hSingle.2⟩
  refine ⟨?_, join_atoms ys.2.1 ns.2.1 hj, union_atoms hcAtoms (union_atoms ys.2.2 ns.2.2)⟩
  rw [union_eq hcAtoms (union_atoms ys.2.2 ns.2.2), union_eq ys.2.2 ns.2.2] at hSafe ⊢
  apply HasTypeQ.E_ElseIf hc (.B_Sub ys.1 hjoin.1 (Eff.Sub.refl _) (join_clean (join_atoms ys.2.1 ns.2.1 hj) hj))
    (.E_Sub ns.1 hjoin.2 (Eff.Sub.refl _) (join_clean (join_atoms ys.2.1 ns.2.1 hj) hj)) ((isIf_spec _).mp (require_ok hisIf).1)
  exact hSafe

theorem ifOnly_case {q cond yes} : CaseSound q (.expr (.ifOnly cond yes)) := by
  intro ih
  have ihc : ExprSound q cond := ih (.expr cond) (by simp [CheckNode.size] <;> omega)
  have ihy : BlockSound q yes := ih (.block yes) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εc, mid, hc, hcAtoms, h, hcAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihc Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨εy, mid', hy, hyAtoms, h, hyAtomsClean⟩ := checking_accept_block_ok
    (fun _ _ _ _ h => ihy Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR h) (by trivial) h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, by trivial, union_atoms hcAtoms hyAtoms⟩
  rw [union_eq hcAtoms hyAtoms]
  exact .E_IfOnly hc hy

theorem return_case {q t e} : CaseSound q (.expr (.returnE t e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨r, hr, h⟩ := checking_lift_bind_ok h
  have hreq := lookup_ok hr
  have hrAtoms := hR r hreq
  rw [hreq]
  cases p with
  | tail =>
    obtain ⟨εe, mid, ht, htAtoms, h, htAtomsClean⟩ := checking_accept_expr_ok
      (fun _ _ _ _ h => ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ (fun t ht => by cases ht; exact hrAtoms) h) hrAtoms h
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    exact ⟨.E_ReturnTail ht, hrAtoms, htAtoms⟩
  | other =>
    obtain ⟨u, hwf, h⟩ := checking_lift_bind_ok h
    obtain ⟨εe, mid, ht, htAtoms, h, htAtomsClean⟩ := checking_accept_expr_ok
      (fun _ _ _ _ h => ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ (fun t ht => by cases ht; exact hrAtoms) h) hrAtoms h
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    exact ⟨.E_ReturnOther ((wfTy_spec _ _ he.1).mp (require_ok hwf).1) ht, he.1, htAtoms⟩

theorem with_case {q o e body} : CaseSound q (.expr (.withE o e body)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihb : BlockSound q body := ih (.block body) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hresource, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hstate, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, ht, htAtoms, h, htAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨⟨ab, εb⟩, mid', hb, h⟩ := checking_bind_ok h
  have bs := ihb (none :: Δ) _ _ _ _ _ _ _ _ _ (hB.value _) hq he.2 (Env.atoms_cons hΓ (by trivial)) hR hb
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, bs.2.1, union_atoms htAtoms (union_atoms bs.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok hstate).1)))⟩
  rw [union_eq htAtoms (union_atoms bs.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok hstate).1))), union_eq bs.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok hstate).1)),
    singleEff_eq_contains (require_ok hstate).1]
  exact .E_With (require_ok hresource).1 ht bs.1

theorem lazy_case {q body} : CaseSound q (.expr (.lazyE body)) := by
  intro ih
  have ihb : BlockSound q body := ih (.block body) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨ab, εb⟩, mid, hb, h⟩ := checking_bind_ok h
  obtain ⟨u, heff, h⟩ := checking_lift_bind_ok h
  have bs := ihb [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq he (Env.atoms_hideConts hΓ)
    (fun _ ht => by cases ht) hb
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hempty := eff_eq_empty_of_sub (acceptEff_sound bs.2.2 (emptyEff_atoms _) heff)
  rw [hempty] at bs
  exact ⟨.E_Lazy bs.1, bs.2.1, emptyEff_atoms _⟩

theorem resume_case {q k e} : CaseSound q (.expr (.resume k e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨t, ht, h⟩ := checking_lift_bind_ok h
  have localEq := lookup_local_ok ht
  have localAtoms := Env.atoms_get hΓ localEq
  cases t <;> try contradiction
  case cont b result eff =>
    obtain ⟨εe, mid, heTyped, heAtoms, h, heAtomsClean⟩ := checking_accept_expr_ok
      (fun _ _ _ _ h => ihe Δ _ _ _ _ _ _ _ _ _ hB hq he hΓ hR h) localAtoms.1 h
    obtain ⟨st, mid2, hget, h⟩ := checking_bind_ok h
    change (do
      acceptEff q (child path 0) eff εe
      pure (result, eff) : Checking Inferred) mid2 = .ok ((a, ε), s') at h
    obtain ⟨u, heff, h⟩ := checking_lift_bind_ok h
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    exact ⟨.E_Resume localEq (.E_Sub heTyped (Or.inl rfl) (acceptEff_sound heAtoms localAtoms.2.2 heff) heAtomsClean),
      localAtoms.2.1, localAtoms.2.2⟩

theorem clauses_nil_case {q} : CaseSound q (.clauses .nil) := by
  intro ih
  refine ⟨?_, clauseTypesAtoms q .nil⟩
  intro Δ C Γ R path t ε s s' actual hB hq hc hΓ hR ht hε h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.nil, Eff.empty_sub _, emptyEff_atoms _⟩

theorem clauses_cons_case {q o n ntys body rest ndicts} :
    CaseSound q (.clauses (.cons o n ntys body rest ndicts)) := by
  intro ih
  obtain ⟨ihb, ihr⟩ := clauses_case_ih ih
  refine ⟨?_, clauseTypesAtoms q _⟩
  intro Δ C Γ R path t ε s s' actual hB hq hc hΓ hR ht hε h
  simp only [Clauses.AtomsIn] at hc
  obtain ⟨sg, hsg, h⟩ := checking_lift_bind_ok h
  obtain ⟨uNames, hnames, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hn, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hntys, h⟩ := checking_lift_bind_ok h
  have hvalid := lookup_valid hsg
  have hwf : Eff.WF C.length ε := wfFails_sound hε hvalid
  have sgAtoms := opSig_atoms hq.declarations hq.builtins (lookup_ok hsg)
  obtain ⟨εb, mid, hb, hbAtoms, h, hbAtomsClean⟩ := checking_accept_block_ok
    (fun _ _ _ _ h => ihb [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq hc.1
      (clauseEnv_atoms sgAtoms.1 sgAtoms.2 ht hε hΓ) (returnAtoms_shift hR ntys) h)
    (shiftTy_atoms ht ntys 0) h
  obtain ⟨st, mid2, hget, h⟩ := checking_bind_ok h
  change (do
    acceptEff q (child path 0) (shiftEff q.atoms ntys 0 ε) εb
    let εouter := substEffAt q.atoms 0 (List.replicate ntys (.base .unit)) [] εb
    acceptEff q (child path 0) ε εouter
    let εs ← checkClausesR q .strict Δ C Γ R (child path 1) rest t ε
    pure (union q εouter εs) : Checking Eff) mid2 = .ok (actual, s') at h
  obtain ⟨u3, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, houter, h⟩ := checking_lift_bind_ok h
  obtain ⟨εr, mid', hr, h⟩ := checking_bind_ok h
  have rs := ihr.1 Δ _ _ _ _ _ _ _ _ _ hB hq hc.2 hΓ hR ht hε hr
  have shiftedAtoms : (shiftEff q.atoms ntys 0 ε).AtomsIn q.atoms := by
    rw [shiftEff_eq ntys 0 ε hε]; exact Eff.shift_support ntys 0 ε hε
  have hbSub := acceptEff_sound hbAtoms shiftedAtoms heff
  have outerAtoms := substEffAt_atoms (es := ([] : List Eff)) hbAtoms
    (tysAtoms_replicate (show Ty.AtomsIn q.atoms (.base .unit) from trivial) ntys) (by simp) 0
  have outerSub := acceptEff_sound outerAtoms hε houter
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.cons (lookup_ok hsg) ((namesWF_spec _ _).mp (require_ok hnames).1)
    (by simpa using (require_ok hn).1) (by simpa using (require_ok hntys).1) hwf ?_ rs.1,
    ?_, union_atoms outerAtoms rs.2.2⟩
  · simpa only [shiftTy_eq ntys 0 t ht, shiftEff_eq ntys 0 ε hε,
      shiftEnv_eq ntys Γ (fun o ho t he => hΓ t (he ▸ ho)), shiftReturn_eq ntys R hR]
      using (HasBlock.B_Sub hb (Or.inl rfl) hbSub hbAtomsClean)
  · rw [union_eq outerAtoms rs.2.2]
    constructor
    · intro x hx
      rcases (Eff.mem_union _ _ _).mp hx with hx | hx
      · exact outerSub.1 x hx
      · exact rs.2.1.1 x hx
    · intro t ht
      rcases (Eff.memFail_union _ _ _).mp ht with ht | ht
      · exact outerSub.2 t ht
      · exact rs.2.1.2 t ht

theorem handle_case {q body cs} : CaseSound q (.expr (.handleE body cs)) := by
  intro ih
  obtain ⟨ihb, ihcs⟩ := handle_case_ih ih
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨t0, εbody⟩, mid, hb, h⟩ := checking_bind_ok h
  have bs := ihb Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR hb
  obtain ⟨⟨t, st⟩, hinfer, h⟩ := checking_lift_bind_ok h
  have initialAtoms := diffEff_atoms (h := handled q.D.patternProgram q.B cs.skeleton) bs.2.2
  have tAtoms := ihcs.2 Δ C Γ R (child path 1) t0 _ {} st t hB hq he.2 hΓ hR bs.2.1 initialAtoms (requests_atoms_nil _) hinfer
  obtain ⟨eff, mid', hfixed, h⟩ := checking_bind_ok h
  have effAtoms := fixedEffectsR_atoms initialAtoms
    (fun e s s' out heff hs => handlerStep_atoms hB hq he.2 hΓ hR tAtoms heff hs) hfixed
  -- 反復の最初の節検査と要求の転記も成功している。型付けは後の厳密な検査を使う。
  obtain ⟨next, iterationState, hstep, hremaining⟩ := checking_bind_ok hfixed
  obtain ⟨⟨clauseEffect, requestState⟩, hrelaxed, hstep⟩ := checking_lift_bind_ok hstep
  obtain ⟨uRequests, transferState, hrequests, hstep⟩ := checking_bind_ok hstep
  obtain ⟨stepEffect, stepState⟩ := checking_pure_ok hstep
  obtain ⟨saved, mid'', hget, h⟩ := checking_bind_ok h
  obtain ⟨u1, mid3, hmodify, h⟩ := checking_bind_ok h
  obtain ⟨actual, mid4, hcs, h⟩ := checking_bind_ok h
  have css := ihcs.1 Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR tAtoms effAtoms hcs
  obtain ⟨u2, mid5, hrestore, h⟩ := checking_bind_ok h
  obtain ⟨u3, htype, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Handle (.B_Sub bs.1 (tyLe_sound bs.2.1 tAtoms (Bool.and_eq_true_iff.mp (require_ok htype).1).2)
    (Eff.Sub.refl _) ((cleanTy_spec _ _ tAtoms).mp (Bool.and_eq_true_iff.mp (require_ok htype).1).1)) (acceptEff_handled_sound bs.2.2 effAtoms heff) css.1, tAtoms, effAtoms⟩

theorem list_length_one {α : Type} {xs : List α} (h : xs.length = 1) :
    ∃ x, xs = [x] := by
  cases xs with
  | nil => simp at h
  | cons x xs =>
    cases xs with
    | nil => exact ⟨x, rfl⟩
    | cons y ys => simp at h

theorem list_length_two {α : Type} {xs : List α} (h : xs.length = 2) :
    ∃ x y, xs = [x, y] := by
  cases xs with
  | nil => simp at h
  | cons x xs =>
    obtain ⟨y, hy⟩ := list_length_one (by simpa using h)
    exact ⟨x, y, by rw [hy]⟩

theorem tryOption_case {q retArgs someCon noneCon e} :
    CaseSound q (.expr (.tryOption retArgs someCon noneCon e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cds, hs, h⟩ := checking_lift_bind_ok h
  obtain ⟨cdn, hn, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨r, hr, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hret, h⟩ := checking_lift_bind_ok h
  have valid := (require_ok hvalid).1
  simp only [Bool.and_eq_true, beq_iff_eq] at valid
  obtain ⟨⟨⟨⟨hns, hnn⟩, has⟩, han⟩, hd⟩ := valid
  have hsArgs := tysEq_sound (hq.declarations.2.1 someCon cds (lookup_ok hs))
    (show Tys.AtomsIn q.atoms [.tvar 0] from ⟨trivial, trivial⟩) has
  have hnArgs := List.isEmpty_iff.mp han
  have retEq := tyEq_sound (hR r (lookup_ok hr))
    (show Ty.AtomsIn q.atoms (.data cds.data retArgs) from he.1) (require_ok hret).1
  have R_eq := (lookup_ok hr).trans (congrArg some retEq)
  obtain ⟨u, hargs⟩ := list_length_one (by simpa using (require_ok hlen).1)
  have retAtoms := he.1
  rw [hargs] at retAtoms
  obtain ⟨⟨input, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have es := ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR hc
  cases input <;> try contradiction
  case data d ts =>
    cases ts with
    | nil => contradiction
    | cons t ts =>
      cases ts with
      | cons t' ts => contradiction
      | nil =>
        obtain ⟨u4, hdata, h⟩ := checking_lift_bind_ok h
        obtain ⟨u5, hexhaustive, h⟩ := checking_lift_bind_ok h
        obtain ⟨eq, _⟩ := checking_pure_ok h
        cases eq
        have deq : d = cds.data := by simpa using (require_ok hdata).1
        refine ⟨?_, es.2.1.1, es.2.2⟩
        rw [hargs]
        exact .E_TryOption (lookup_ok hs) (lookup_ok hn) hns hnn hsArgs hnArgs hd
          (by simpa [hargs] using R_eq) (by rw [← deq]; exact es.1)
          (by rw [← deq]; exact tryOptionExhaustive_sound hq.constructors (require_ok hexhaustive).1)

theorem tryResult_case {q retArgs ok err e} :
    CaseSound q (.expr (.tryResult retArgs ok err e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cdo, ho, h⟩ := checking_lift_bind_ok h
  obtain ⟨cde, hec, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨r, hr, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hret, h⟩ := checking_lift_bind_ok h
  have valid := (require_ok hvalid).1
  simp only [Bool.and_eq_true, beq_iff_eq] at valid
  obtain ⟨⟨⟨⟨hno, hne⟩, hao⟩, hae⟩, hd⟩ := valid
  have hoArgs := tysEq_sound (hq.declarations.2.1 ok cdo (lookup_ok ho))
    (show Tys.AtomsIn q.atoms [.tvar 0] from ⟨trivial, trivial⟩) hao
  have heArgs := tysEq_sound (hq.declarations.2.1 err cde (lookup_ok hec))
    (show Tys.AtomsIn q.atoms [.tvar 1] from ⟨trivial, trivial⟩) hae
  have retEq := tyEq_sound (hR r (lookup_ok hr))
    (show Ty.AtomsIn q.atoms (.data cdo.data retArgs) from he.1) (require_ok hret).1
  have R_eq := (lookup_ok hr).trans (congrArg some retEq)
  obtain ⟨u, errTy, hargs⟩ := list_length_two (by simpa using (require_ok hlen).1)
  have retAtoms := he.1
  rw [hargs] at retAtoms
  obtain ⟨⟨input, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have es := ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR hc
  cases input <;> try contradiction
  case data d ts =>
    cases ts with
    | nil => contradiction
    | cons t ts =>
      cases ts with
      | nil => contradiction
      | cons e' ts =>
        cases ts with
        | cons t' ts => contradiction
        | nil =>
          obtain ⟨u4, hmatch, h⟩ := checking_lift_bind_ok h
          obtain ⟨u5, hexhaustive, h⟩ := checking_lift_bind_ok h
          obtain ⟨eq, _⟩ := checking_pure_ok h
          cases eq
          have matched := (require_ok hmatch).1
          simp only [Bool.and_eq_true, beq_iff_eq] at matched
          have deq := matched.1
          have errEq : e' = errTy := tyEq_sound es.2.1.2.1 retAtoms.2.1
            (by simpa [hargs] using matched.2)
          refine ⟨?_, es.2.1.1, es.2.2⟩
          rw [hargs]
          exact .E_TryResult (lookup_ok ho) (lookup_ok hec) hno hne hoArgs heArgs hd
            (by simpa [hargs] using R_eq)
            (by rw [← deq, ← errEq]; exact es.1)
            (by rw [← deq, ← errEq]; exact tryResultExhaustive_sound hq.constructors (require_ok hexhaustive).1)

/-- 六つの構文の全構成子を、それぞれの成功経路の証明に接続する。 -/
theorem checkCasesSound (q : Input) : CheckCasesSound q := by
  intro node
  cases node with
  | expr value =>
    cases value with
    | builderOp => exact builderOp_case
    | «local» => exact local_case
    | constE => exact const_case
    | funName => exact funName_case
    | funDicts => exact funDicts_case
    | opDicts => exact opDicts_case
    | methName => exact methName_case
    | primName => exact primName_case
    | raise => exact raise_case
    | handleFail => exact handleFail_case
    | opName => exact opName_case
    | nullCon => exact nullCon_case
    | conValue => exact conValue_case
    | literal => exact literal_case
    | negInt => exact negInt_case
    | negFloat => exact negFloat_case
    | negDecimal => exact negDecimal_case
    | negInteger8 => exact negInteger8_case
    | negInteger16 => exact negInteger16_case
    | negInteger32 => exact negInteger32_case
    | negFloat32 => exact negFloat32_case
    | unit => exact unit_case
    | paren => exact paren_case
    | conCall => exact conCall_case
    | record => exact record_case
    | recordUpdate => exact recordUpdate_case
    | call => exact call_case
    | pipe => exact pipe_case
    | partialCall => exact partialCall_case
    | partialCon => exact partialCon_case
    | binary => exact binary_case
    | neg => exact neg_case
    | not => exact not_case
    | and => exact and_case
    | or => exact or_case
    | list => exact list_case
    | listSpread => exact listSpread_case
    | interpolation => exact interpolation_case
    | lam => exact lam_case
    | ite => exact ite_case
    | elseIf => exact elseIf_case
    | ifOnly => exact ifOnly_case
    | matchE => exact match_case
    | returnE => exact return_case
    | tryResult => exact tryResult_case
    | tryOption => exact tryOption_case
    | tryResultDie => exact tryResultDie_case
    | tryOptionDie => exact tryOptionDie_case
    | withE => exact with_case
    | lazyE => exact lazy_case
    | handleE => exact handle_case
    | resume => exact resume_case
  | exprs value =>
    cases value with
    | nil => exact exprs_nil_case
    | cons => exact exprs_cons_case
  | holes value =>
    cases value with
    | nil => exact holes_nil_case
    | expr => exact holes_expr_case
    | hole => exact holes_hole_case
  | arms value =>
    cases value with
    | nil => exact arms_nil_case
    | cons => exact arms_cons_case
  | clauses value =>
    cases value with
    | nil => exact clauses_nil_case
    | cons => exact clauses_cons_case
  | block value =>
    cases value with
    | empty => exact block_empty_case
    | last => exact block_last_case
    | lastBind => exact block_lastBind_case
    | lastDiscard => exact block_lastDiscard_case
    | builderBind => exact block_builderBind_case
    | bind => exact block_bind_case
    | discard => exact block_discard_case
    | seq => exact block_seq_case
    | lastPat => exact block_lastPat_case
    | bindPat => exact block_bindPat_case

theorem mutualSoundness (q : Input) : MutualSoundness q :=
  MutualSoundness.of_cases (checkCasesSound q)

theorem checkerSoundness (q : Input) : CheckerSoundness q :=
  ⟨mutualSoundness q, dictionarySoundness q⟩

end Benitoite.Surface.Check
