import Benitoite.Surface.CheckDictSupport

/-! die の辞書・終了操作・説明の検査と、二つの表層規則への接続。
対応する条件は設計書 01-12「die の先行モデル」、保証は 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

private theorem result_atoms {atoms t ok err dict method exit e message} :
    (Expr.tryResultDie t ok err dict method exit e message).AtomsIn atoms ↔
      t.AtomsIn atoms ∧ dict.AtomsIn atoms ∧ e.AtomsIn atoms ∧
        (match message with | none => True | some m => m.AtomsIn atoms) := by
  cases message <;> simp only [Expr.AtomsIn]

private theorem option_atoms {atoms t cs cn exit e message} :
    (Expr.tryOptionDie t cs cn exit e message).AtomsIn atoms ↔
      t.AtomsIn atoms ∧ e.AtomsIn atoms ∧
        (match message with | none => True | some m => m.AtomsIn atoms) := by
  cases message <;> simp only [Expr.AtomsIn]

theorem checkDieShow_sound {q C Γ path dict method errorTy u}
    (hq : q.Sound) (hd : dict.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (he : errorTy.AtomsIn q.atoms)
    (h : checkDieShow q C Γ path dict method errorTy = .ok u) :
    DieShowOk q.D q.B C Γ dict method errorTy := by
  obtain ⟨a, ha, h⟩ := bind_ok h
  obtain ⟨⟨cl, t⟩, hv, h⟩ := bind_ok h
  have ds := (dictionarySoundness q).dict dict C Γ path a hq hd hΓ ha
  have eq := dictView_ok hv
  obtain ⟨u1, ht, h⟩ := bind_ok h
  obtain ⟨cd, hc, h⟩ := bind_ok h
  obtain ⟨ms, hm, h⟩ := bind_ok h
  rw [eq] at ds
  have teq := tyEq_sound (a := t) ds.2 he (require_ok ht).1
  have valid := (require_ok h).1
  simp only [Bool.and_eq_true, beq_iff_eq] at valid
  obtain ⟨⟨⟨⟨⟨htp, hne⟩, hn⟩, hp⟩, hr⟩, hf⟩ := valid
  have ma := hq.declarations.2.2.2.1 cl cd method ms (lookup_ok hc) (lookup_ok hm)
  exact ⟨cl, cd, ms, by simpa only [teq] using ds.1, lookup_ok hc, lookup_ok hm, List.isEmpty_iff.mp htp, hne, hn,
    tysEq_sound ma.1 ⟨trivial, trivial⟩ hp, tyEq_sound ma.2.1 (by trivial) hr,
    effEq_sound ma.2.2 (emptyEff_atoms _) hf⟩

theorem checkDieExit_sound {q C path exit t u} (hq : q.Sound) (ht : t.AtomsIn q.atoms)
    (h : checkDieExit q C path exit t = .ok u) :
    DieExitOk q.B C exit t ∧ q.atoms.contains (.name "Process.Exit") = true := by
  obtain ⟨sg, hs, h⟩ := bind_ok h
  obtain ⟨u1, hv, h⟩ := bind_ok h
  obtain ⟨u2, ha, h⟩ := bind_ok h
  obtain ⟨u3, he, h⟩ := bind_ok h
  have valid := (require_ok hv).1
  simp only [Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at valid
  obtain ⟨⟨⟨⟨hk, hop⟩, hn⟩, hne⟩, hnames⟩ := valid
  have sa := hq.builtins exit sg (lookup_ok hs)
  have eq := tyEq_sound (fnTyCheck_atoms (ts := [t]) (es := []) sa.1 sa.2.1 sa.2.2 ⟨ht, trivial⟩ (by simp))
    (show Ty.AtomsIn q.atoms (.fn ["code"] [.base .integer] t
      (singleEff q.atoms (.name "Process.Exit"))) from ⟨⟨trivial, trivial⟩, ht, singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok he).1)⟩)
    (require_ok h).1
  rw [fnTyCheck_eq sg.names sg.params sg.ret sg.eff [t] []
    (by intro u hu; simp only [List.mem_singleton] at hu; subst u; exact ht) (by simp)
    sa.1 sa.2.1 sa.2.2, singleEff_eq_contains (require_ok he).1] at eq
  exact ⟨⟨sg, lookup_ok hs, hk, hop, hn, hne, (namesWF_spec _ _).mp hnames,
    hq.admits exit C [t] sg (lookup_ok hs) (require_ok ha).1, eq⟩, (require_ok he).1⟩

theorem checkDieMessageR_sound {q Δ C Γ path message s s' u}
    (ih : GuardSound q message) (hB : BuilderInvariant q C Γ Δ) (hq : q.Sound)
    (hm : ∀ m, message = some m → m.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (h : checkDieMessageR q .strict Δ C Γ path message s = .ok (u, s')) :
    ∀ m, message = some m →
      HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) Δ C (hideConts Γ) none .other m (.base .string) Eff.empty := by
  intro m he
  subst message
  obtain ⟨ε, mid, ht, ha, h, haClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ih m rfl Δ _ _ _ _ _ _ _ _ _ hB.hide hq (hm m rfl)
      (Env.atoms_hideConts hΓ) (by intro t ht; cases ht) h) (by trivial) h
  have hacc := (checking_lift_ok h).1
  exact .E_Sub ht (Or.inl rfl) (acceptEff_sound ha (emptyEff_atoms _) hacc) haClean

theorem tryResultDie_case {q t ok err dict method exit e message} :
    CaseSound q (.expr (.tryResultDie t ok err dict method exit e message)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihm : GuardSound q message := by
    intro m hm
    subst message
    exact ih (.expr m) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  rw [result_atoms] at he
  obtain ⟨cdo, ho, h⟩ := checking_lift_bind_ok h
  obtain ⟨cde, hec, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
  have valid := (require_ok hvalid).1
  simp only [Bool.and_eq_true, beq_iff_eq] at valid
  obtain ⟨⟨⟨⟨hno, hne⟩, hao⟩, hae⟩, hd⟩ := valid
  have hoArgs := tysEq_sound (hq.declarations.2.1 ok cdo (lookup_ok ho))
    (show Tys.AtomsIn q.atoms [.tvar 0] from ⟨trivial, trivial⟩) hao
  have heArgs := tysEq_sound (hq.declarations.2.1 err cde (lookup_ok hec))
    (show Tys.AtomsIn q.atoms [.tvar 1] from ⟨trivial, trivial⟩) hae
  obtain ⟨⟨input, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have es := ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.2.2.1 hΓ hR hc
  cases input <;> try contradiction
  case data d ts =>
    cases ts with
    | nil => contradiction
    | cons actual ts =>
      cases ts with
      | nil => contradiction
      | cons et ts =>
        cases ts with
        | cons _ _ => contradiction
        | nil =>
          obtain ⟨u2, hmatch, h⟩ := checking_lift_bind_ok h
          obtain ⟨u3, hex, h⟩ := checking_lift_bind_ok h
          obtain ⟨u4, hshow, h⟩ := checking_lift_bind_ok h
          obtain ⟨u5, hexit, h⟩ := checking_lift_bind_ok h
          obtain ⟨u6, mid', hm, h⟩ := checking_bind_ok h
          obtain ⟨eq, _⟩ := checking_pure_ok h
          cases eq
          have matched := (require_ok hmatch).1
          simp only [Bool.and_eq_true, beq_iff_eq] at matched
          have teq := tyEq_sound es.2.1.1 he.1 matched.2
          have dx := checkDieExit_sound hq he.1 hexit
          have ds := checkDieShow_sound hq he.2.1 hΓ es.2.1.2.1 hshow
          have ms := checkDieMessageR_sound ihm hB hq
            (by intro m hm; cases hm; exact he.2.2.2) hΓ hm
          refine ⟨?_, he.1, union_atoms es.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true dx.2))⟩
          rw [union_eq es.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true dx.2)), singleEff_eq_contains dx.2]
          exact .E_TryResultDie (lookup_ok ho) (lookup_ok hec) hno hne hoArgs heArgs hd
            (by simpa only [matched.1, teq] using es.1)
            (by rw [← matched.1]; exact tryResultExhaustive_sound hq.constructors (require_ok hex).1)
            ds dx.1 ms

theorem tryOptionDie_case {q t someCon noneCon exit e message} :
    CaseSound q (.expr (.tryOptionDie t someCon noneCon exit e message)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihm : GuardSound q message := by
    intro m hm
    subst message
    exact ih (.expr m) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  rw [option_atoms] at he
  obtain ⟨cds, hs, h⟩ := checking_lift_bind_ok h
  obtain ⟨cdn, hn, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
  have valid := (require_ok hvalid).1
  simp only [Bool.and_eq_true, beq_iff_eq] at valid
  obtain ⟨⟨⟨⟨hns, hnn⟩, has⟩, han⟩, hd⟩ := valid
  have hsArgs := tysEq_sound (hq.declarations.2.1 someCon cds (lookup_ok hs))
    (show Tys.AtomsIn q.atoms [.tvar 0] from ⟨trivial, trivial⟩) has
  have hnArgs := List.isEmpty_iff.mp han
  obtain ⟨⟨input, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have es := ihe Δ _ _ _ _ _ _ _ _ _ hB hq he.2.1 hΓ hR hc
  cases input <;> try contradiction
  case data d ts =>
    cases ts with
    | nil => contradiction
    | cons actual ts =>
      cases ts with
      | cons _ _ => contradiction
      | nil =>
        obtain ⟨u2, hmatch, h⟩ := checking_lift_bind_ok h
        obtain ⟨u3, hex, h⟩ := checking_lift_bind_ok h
        obtain ⟨u4, hexit, h⟩ := checking_lift_bind_ok h
        obtain ⟨u5, mid', hm, h⟩ := checking_bind_ok h
        obtain ⟨eq, _⟩ := checking_pure_ok h
        cases eq
        have matched := (require_ok hmatch).1
        simp only [Bool.and_eq_true, beq_iff_eq] at matched
        have teq := tyEq_sound es.2.1.1 he.1 matched.2
        have dx := checkDieExit_sound hq he.1 hexit
        have ms := checkDieMessageR_sound ihm hB hq
          (by intro m hm; cases hm; exact he.2.2) hΓ hm
        refine ⟨?_, he.1, union_atoms es.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true dx.2))⟩
        rw [union_eq es.2.2 (singleEff_atoms _ _ (List.mem_of_elem_eq_true dx.2)), singleEff_eq_contains dx.2]
        exact .E_TryOptionDie (lookup_ok hs) (lookup_ok hn) hns hnn hsArgs hnArgs hd
          (by simpa only [matched.1, teq] using es.1)
          (by rw [← matched.1]; exact tryOptionExhaustive_sound hq.constructors (require_ok hex).1)
          dx.1 ms

end Benitoite.Surface.Check
