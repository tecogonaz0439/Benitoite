import Benitoite.Surface.CheckSoundCalls

/-! 制御構文とハンドラの節の検査の健全性。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem lam_case {q ps r eff body} : CaseSound q (.expr (.lam ps r eff body)) := by
  intro ih
  have ihb := lam_case_ih ih
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hexit, h⟩ := checking_lift_bind_ok h
  obtain ⟨εb, mid, hb, hbAtoms, h⟩ := checking_accept_block_ok
    (fun _ _ _ _ h => ihb _ _ _ _ _ _ _ _ _ hq he.2.2.2
      (Env.atoms_append (Env.atoms_binds he.1) (Env.atoms_hideConts hΓ))
      (fun t ht => by cases ht; exact he.2.1) h) he.2.1 h
  obtain ⟨u2, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Lam ((lamBodyOk_spec _ _).mp (require_ok hexit).1)
    (.B_Sub hb (Or.inl rfl) (acceptEff_sound hbAtoms heff)),
    ⟨he.1, he.2.1, he.2.2.1⟩, emptyEff_atoms _⟩

theorem ite_case {q cond yes no} : CaseSound q (.expr (.ite cond yes no)) := by
  intro ih
  have ihc : ExprSound q cond := ih (.expr cond) (by simp [CheckNode.size] <;> omega)
  have ihy : BlockSound q yes := ih (.block yes) (by simp [CheckNode.size] <;> omega)
  have ihn : BlockSound q no := ih (.block no) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εc, mid, hc, hcAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihc _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨⟨ay, εy⟩, mid', hy, h⟩ := checking_bind_ok h
  obtain ⟨⟨an, εn⟩, mid'', hn, h⟩ := checking_bind_ok h
  obtain ⟨out, hj, h⟩ := checking_lift_bind_ok h
  have ys := ihy _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hy
  have ns := ihn _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR hn
  have hjoin := join_sound ys.2.1 ns.2.1 hj
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, join_atoms ys.2.1 hj, union_atoms _ _ _⟩
  rw [union_eq hcAtoms (union_atoms _ _ _), union_eq ys.2.2 ns.2.2]
  exact .E_If hc (.B_Sub ys.1 hjoin.1 (fun _ h => h)) (.B_Sub ns.1 hjoin.2 (fun _ h => h))

theorem elseIf_case {q cond yes no} : CaseSound q (.expr (.elseIf cond yes no)) := by
  intro ih
  have ihc : ExprSound q cond := ih (.expr cond) (by simp [CheckNode.size] <;> omega)
  have ihy : BlockSound q yes := ih (.block yes) (by simp [CheckNode.size] <;> omega)
  have ihn : ExprSound q no := ih (.expr no) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u, hisIf, h⟩ := checking_lift_bind_ok h
  obtain ⟨εc, mid, hc, hcAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihc _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨⟨ay, εy⟩, mid', hy, h⟩ := checking_bind_ok h
  obtain ⟨⟨an, εn⟩, mid'', hn, h⟩ := checking_bind_ok h
  obtain ⟨out, hj, h⟩ := checking_lift_bind_ok h
  have ys := ihy _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hy
  have ns := ihn _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR hn
  have hjoin := join_sound ys.2.1 ns.2.1 hj
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, join_atoms ys.2.1 hj, union_atoms _ _ _⟩
  rw [union_eq hcAtoms (union_atoms _ _ _), union_eq ys.2.2 ns.2.2]
  exact .E_ElseIf hc (.B_Sub ys.1 hjoin.1 (fun _ h => h))
    (.E_Sub ns.1 hjoin.2 (fun _ h => h)) ((isIf_spec _).mp (require_ok hisIf).1)

theorem ifOnly_case {q cond yes} : CaseSound q (.expr (.ifOnly cond yes)) := by
  intro ih
  have ihc : ExprSound q cond := ih (.expr cond) (by simp [CheckNode.size] <;> omega)
  have ihy : BlockSound q yes := ih (.block yes) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εc, mid, hc, hcAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihc _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨εy, mid', hy, hyAtoms, h⟩ := checking_accept_block_ok
    (fun _ _ _ _ h => ihy _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR h) (by trivial) h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, by trivial, union_atoms _ _ _⟩
  rw [union_eq hcAtoms hyAtoms]
  exact .E_IfOnly hc hy

theorem return_case {q t e} : CaseSound q (.expr (.returnE t e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨r, hr, h⟩ := checking_lift_bind_ok h
  have hreq := lookup_ok hr
  have hrAtoms := hR r hreq
  rw [hreq]
  cases p with
  | tail =>
    obtain ⟨εe, mid, ht, htAtoms, h⟩ := checking_accept_expr_ok
      (fun _ _ _ _ h => ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ (fun t ht => by cases ht; exact hrAtoms) h) hrAtoms h
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    exact ⟨.E_ReturnTail ht, hrAtoms, htAtoms⟩
  | other =>
    obtain ⟨u, hwf, h⟩ := checking_lift_bind_ok h
    obtain ⟨εe, mid, ht, htAtoms, h⟩ := checking_accept_expr_ok
      (fun _ _ _ _ h => ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ (fun t ht => by cases ht; exact hrAtoms) h) hrAtoms h
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    exact ⟨.E_ReturnOther ((wfTy_spec _ _).mp (require_ok hwf).1) ht, he.1, htAtoms⟩

theorem with_case {q o e body} : CaseSound q (.expr (.withE o e body)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihb : BlockSound q body := ih (.block body) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hresource, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hstate, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, ht, htAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihe _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) (by trivial) h
  obtain ⟨⟨ab, εb⟩, mid', hb, h⟩ := checking_bind_ok h
  have bs := ihb _ _ _ _ _ _ _ _ _ hq he.2 (Env.atoms_cons hΓ (by trivial)) hR hb
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, bs.2.1, union_atoms _ _ _⟩
  rw [union_eq htAtoms (union_atoms _ _ _), union_eq bs.2.2 (singleEff_atoms _ _),
    singleEff_eq_contains (require_ok hstate).1]
  exact .E_With (require_ok hresource).1 ht bs.1

theorem lazy_case {q body} : CaseSound q (.expr (.lazyE body)) := by
  intro ih
  have ihb : BlockSound q body := ih (.block body) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨ab, εb⟩, mid, hb, h⟩ := checking_bind_ok h
  obtain ⟨u, heff, h⟩ := checking_lift_bind_ok h
  have bs := ihb _ _ _ _ _ _ _ _ _ hq he (Env.atoms_hideConts hΓ)
    (fun _ ht => by cases ht) hb
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Lazy (.B_Sub bs.1 (Or.inl rfl) (acceptEff_sound bs.2.2 heff)),
    bs.2.1, emptyEff_atoms _⟩

theorem resume_case {q k e} : CaseSound q (.expr (.resume k e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨t, ht, h⟩ := checking_lift_bind_ok h
  have localEq := lookup_local_ok ht
  have localAtoms := Env.atoms_get hΓ localEq
  cases t <;> try contradiction
  case cont b result eff =>
    obtain ⟨εe, mid, heTyped, heAtoms, h⟩ := checking_accept_expr_ok
      (fun _ _ _ _ h => ihe _ _ _ _ _ _ _ _ _ hq he hΓ hR h) localAtoms.1 h
    obtain ⟨st, mid2, hget, h⟩ := checking_bind_ok h
    change (do
      acceptEff q (child path 0) eff εe
      pure (result, eff) : Checking Inferred) mid2 = .ok ((a, ε), s') at h
    obtain ⟨u, heff, h⟩ := checking_lift_bind_ok h
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    exact ⟨.E_Resume localEq (.E_Sub heTyped (Or.inl rfl) (acceptEff_sound heAtoms heff)),
      localAtoms.2.1, localAtoms.2.2⟩

theorem clauses_nil_case {q} : CaseSound q (.clauses .nil) := by
  intro ih
  refine ⟨?_, clauseTypesAtoms q .nil⟩
  intro C Γ R path t ε s s' actual hq hc hΓ hR ht hε h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.nil, (fun _ h => by cases h), emptyEff_atoms _⟩

theorem clauses_cons_case {q o n ntys body rest} :
    CaseSound q (.clauses (.cons o n ntys body rest)) := by
  intro ih
  obtain ⟨ihb, ihr⟩ := clauses_case_ih ih
  refine ⟨?_, clauseTypesAtoms q _⟩
  intro C Γ R path t ε s s' actual hq hc hΓ hR ht hε h
  simp only [Clauses.AtomsIn] at hc
  obtain ⟨sg, hsg, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hn, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hntys, h⟩ := checking_lift_bind_ok h
  have sgAtoms := opSig_atoms hq.declarations hq.builtins (lookup_ok hsg)
  obtain ⟨εb, mid, hb, hbAtoms, h⟩ := checking_accept_block_ok
    (fun _ _ _ _ h => ihb _ _ _ _ _ _ _ _ _ hq hc.1
      (clauseEnv_atoms sgAtoms.1 sgAtoms.2 ht hε hΓ) (returnAtoms_shift hR ntys) h)
    (shiftTy_atoms ht ntys 0) h
  obtain ⟨st, mid2, hget, h⟩ := checking_bind_ok h
  change (do
    acceptEff q (child path 0) ε εb
    let εs ← checkClausesR q .strict C Γ R (child path 1) rest t ε
    pure (union q εb εs) : Checking Eff) mid2 = .ok (actual, s') at h
  obtain ⟨u3, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨εr, mid', hr, h⟩ := checking_bind_ok h
  have rs := ihr.1 _ _ _ _ _ _ _ _ _ hq hc.2 hΓ hR ht hε hr
  have hbSub := acceptEff_sound hbAtoms heff
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.cons (lookup_ok hsg) (by simpa using (require_ok hn).1)
    (by simpa using (require_ok hntys).1) ?_ rs.1, ?_, union_atoms _ _ _⟩
  · simpa only [shiftTy_eq, shiftTy_fun_eq, shiftEnv] using
      (HasBlock.B_Sub hb (Or.inl rfl) hbSub)
  · rw [union_eq hbAtoms rs.2.2]
    intro x hx
    cases Bool.or_eq_true_iff.mp hx with
    | inl hx => exact hbSub x hx
    | inr hx => exact rs.2.1 x hx

theorem handle_case {q body cs} : CaseSound q (.expr (.handleE body cs)) := by
  intro ih
  obtain ⟨ihb, ihcs⟩ := handle_case_ih ih
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨t0, εbody⟩, mid, hb, h⟩ := checking_bind_ok h
  have bs := ihb _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hb
  obtain ⟨⟨t, st⟩, hinfer, h⟩ := checking_lift_bind_ok h
  have tAtoms := ihcs.2 _ _ _ _ _ _ _ _ _ bs.2.1 hinfer
  obtain ⟨eff, mid', hfixed, h⟩ := checking_bind_ok h
  have effAtoms := fixedEffectsR_atoms (diffEff_atoms _ _ _) hfixed
  -- 反復の最初の節検査と要求の転記も成功している。型付けは後の厳密な検査を使う。
  obtain ⟨next, iterationState, hstep, hremaining⟩ := checking_bind_ok hfixed
  obtain ⟨⟨clauseEffect, requestState⟩, hrelaxed, hstep⟩ := checking_lift_bind_ok hstep
  obtain ⟨uRequests, transferState, hrequests, hstep⟩ := checking_bind_ok hstep
  obtain ⟨stepEffect, stepState⟩ := checking_pure_ok hstep
  obtain ⟨saved, mid'', hget, h⟩ := checking_bind_ok h
  obtain ⟨u1, mid3, hmodify, h⟩ := checking_bind_ok h
  obtain ⟨actual, mid4, hcs, h⟩ := checking_bind_ok h
  have css := ihcs.1 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR tAtoms effAtoms hcs
  obtain ⟨u2, mid5, hrestore, h⟩ := checking_bind_ok h
  obtain ⟨u3, htype, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Handle (.B_Sub bs.1 (tyLe_sound bs.2.1 tAtoms (require_ok htype).1)
    (fun _ h => h)) (acceptEff_handled_sound bs.2.2 heff) css.1, tAtoms, effAtoms⟩

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
  intro C Γ R p path s s' a ε hq he hΓ hR h
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
  have es := ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc
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
  intro C Γ R p path s s' a ε hq he hΓ hR h
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
  have es := ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc
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
    | «local» => exact local_case
    | constE => exact const_case
    | funName => exact funName_case
    | funDicts => exact funDicts_case
    | methName => exact methName_case
    | primName => exact primName_case
    | opName => exact opName_case
    | nullCon => exact nullCon_case
    | conValue => exact conValue_case
    | literal => exact literal_case
    | negInt => exact negInt_case
    | negFloat => exact negFloat_case
    | negDecimal => exact negDecimal_case
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
