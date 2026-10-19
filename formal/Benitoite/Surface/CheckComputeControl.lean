import Benitoite.Surface.CheckComputeCalls

/-! try・ハンドラの探索・継続の要求の支持保存。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

private theorem result_computes_atoms {atoms t ok err dict method exit e message} :
    (Expr.tryResultDie t ok err dict method exit e message).AtomsIn atoms ↔
      t.AtomsIn atoms ∧ dict.AtomsIn atoms ∧ e.AtomsIn atoms ∧
        (match message with | none => True | some m => m.AtomsIn atoms) := by
  cases message <;> simp only [Expr.AtomsIn]

private theorem option_computes_atoms {atoms t cs cn exit e message} :
    (Expr.tryOptionDie t cs cn exit e message).AtomsIn atoms ↔
      t.AtomsIn atoms ∧ e.AtomsIn atoms ∧
        (match message with | none => True | some m => m.AtomsIn atoms) := by
  cases message <;> simp only [Expr.AtomsIn]

theorem checkDieExit_contains {q C path exit t u}
    (h : checkDieExit q C path exit t = .ok u) : .name "Process.Exit" ∈ q.atoms := by
  obtain ⟨s, hs, h⟩ := bind_ok h
  obtain ⟨u, hu, h⟩ := bind_ok h
  obtain ⟨u, hu, h⟩ := bind_ok h
  obtain ⟨u, hu, h⟩ := bind_ok h
  exact List.mem_of_elem_eq_true (require_ok hu).1

theorem computes_dieMessage {q message}
    (ih : ∀ m, message = some m → ExprComputes q m)
    {mode Δ C Γ path} (hB : BuilderInvariant q C Γ Δ) (hq : q.Sound) (hΓ : Env.AtomsIn q.atoms Γ)
    (hm : match message with | none => True | some m => m.AtomsIn q.atoms) :
    ComputesIn q (fun _ : Unit => True) (checkDieMessageR q mode Δ C Γ path message) := by
  cases message with
  | none => exact computes_pure trivial
  | some m =>
    apply computes_accept_bind (ih m rfl _ Δ _ _ _ _ _ hq hm (Env.atoms_hideConts hΓ)
      (fun t ht => by cases ht) hB.hide)
    intro ε hε
    exact computes_lift (fun _ _ => trivial)

theorem computes_tryOption {q retArgs cs cn e} (ihe : ExprComputes q e) :
    ExprComputes q (.tryOption retArgs cs cn e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (ihe _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  cases a <;> try exact computes_throw
  rename_i d ts
  cases ts with
  | nil => exact computes_throw
  | cons t ts =>
    cases ts with
    | cons u us => exact computes_throw
    | nil =>
      repeat (apply computes_lift_bind; intro _ _)
      exact computes_pure ⟨ha.1, hε⟩

theorem computes_tryResult {q retArgs co ce e} (ihe : ExprComputes q e) :
    ExprComputes q (.tryResult retArgs co ce e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (ihe _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  cases a <;> try exact computes_throw
  rename_i d ts
  cases ts with
  | nil => exact computes_throw
  | cons t ts =>
    cases ts with
    | nil => exact computes_throw
    | cons u us =>
      cases us with
      | cons v vs => exact computes_throw
      | nil =>
        repeat (apply computes_lift_bind; intro _ _)
        exact computes_pure ⟨ha.1, hε⟩

theorem computes_tryOptionDie {q t cs cn exit e message} (ihe : ExprComputes q e)
    (ihm : ∀ m, message = some m → ExprComputes q m) :
    ExprComputes q (.tryOptionDie t cs cn exit e message) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  have he := option_computes_atoms.mp he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (ihe _ Δ _ _ _ _ _ hq he.2.1 hΓ hR hB)
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  cases a <;> try exact computes_throw
  rename_i d ts
  cases ts with
  | nil => exact computes_throw
  | cons actual ts =>
    cases ts with
    | cons u us => exact computes_throw
    | nil =>
      apply computes_lift_bind
      intro u hu
      apply computes_lift_bind
      intro u hu
      apply computes_lift_bind
      intro u hexit
      apply computes_bind (computes_dieMessage ihm hB hq hΓ he.2.2)
      intro u hu
      exact computes_pure ⟨he.1, union_atoms hε (singleEff_atoms _ _ (checkDieExit_contains hexit))⟩

theorem computes_tryResultDie {q t co ce dict method exit e message} (ihe : ExprComputes q e)
    (ihm : ∀ m, message = some m → ExprComputes q m) :
    ExprComputes q (.tryResultDie t co ce dict method exit e message) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  have he := result_computes_atoms.mp he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (ihe _ Δ _ _ _ _ _ hq he.2.2.1 hΓ hR hB)
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  cases a <;> try exact computes_throw
  rename_i d ts
  cases ts with
  | nil => exact computes_throw
  | cons actual ts =>
    cases ts with
    | nil => exact computes_throw
    | cons et us =>
      cases us with
      | cons v vs => exact computes_throw
      | nil =>
        apply computes_lift_bind
        intro u hu
        apply computes_lift_bind
        intro u hu
        apply computes_lift_bind
        intro u hshow
        apply computes_lift_bind
        intro u hexit
        apply computes_bind (computes_dieMessage ihm hB hq hΓ he.2.2.2)
        intro u hu
        exact computes_pure ⟨he.1, union_atoms hε (singleEff_atoms _ _ (checkDieExit_contains hexit))⟩

theorem computes_handle {q body cs} (ihb : BlockComputes q body)
    (iht : ClauseTypesComputes q cs) (ihc : ClausesComputes q cs) :
    ExprComputes q (.handleE body cs) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_bind (ihb _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  rintro ⟨t0, εbody⟩ ⟨ht0, hbody⟩
  have hi : (diffEff q.atoms εbody (handled q.D.patternProgram q.B cs.skeleton)).AtomsIn q.atoms :=
    diffEff_atoms hbody
  apply computes_bind (computes_run_empty (iht Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht0 hi))
  rintro ⟨t, st⟩ ⟨ht, hst⟩
  have hstep : ∀ e, e.AtomsIn q.atoms → ComputesIn q (Eff.AtomsIn q.atoms)
      (do
        let (actual, req) ← (checkClausesR q .relaxed Δ C Γ R (child path 1) cs t e).run {}
        modify fun outer => { outer with requests := outer.requests ++
          (req.requests.filter (fun r => !(clauseKeys Γ.length cs).contains r.1)) }
        pure (union q actual (requestedEffect q (clauseKeys Γ.length cs) req.requests))) := by
    intro e heff
    apply computes_bind (computes_run_empty (ihc _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht heff))
    rintro ⟨actual, req⟩ ⟨ha, hr⟩
    apply computes_bind (computes_modify
      (f := fun outer => { outer with requests := outer.requests ++
        (req.requests.filter (fun r => !(clauseKeys Γ.length cs).contains r.1)) })
      (fun outer ho => requests_atoms_append ho (requests_atoms_filter hr _)))
    intro u hu
    exact computes_pure (union_atoms ha (requestedEffect_atoms q _ req.requests hr))
  apply computes_bind (fixedEffectsR_computes hstep _ hi)
  intro ε hε
  apply computes_bind computes_get
  intro saved hsaved
  apply computes_bind (computes_modify
    (f := fun st => { st with strictConts := clauseKeys Γ.length cs ++ saved.strictConts })
    (fun st hs => hs))
  intro u hu
  apply computes_bind (ihc _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht hε)
  intro actual ha
  apply computes_bind (computes_modify (f := fun st => { st with strictConts := saved.strictConts })
    (fun st hs => hs))
  intro u hu
  repeat (apply computes_lift_bind; intro _ _)
  exact computes_pure ⟨ht, hε⟩

theorem computes_raise {q t E} : ExprComputes q (.raise t E) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨⟨⟨he.2, trivial⟩, he.1, singleFailure_atoms he.2⟩, emptyEff_atoms _⟩

theorem computes_handleFail {q E t body clause}
    (ihb : BlockComputes q body) (ihc : BlockComputes q clause) :
    ExprComputes q (.handleFail E t body clause) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_accept_bind (ihb _ Δ _ _ _ _ _ hq he.2.2.1 hΓ hR hB)
  intro eb heb
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihc _ [] _ _ _ _ _ hq he.2.2.2 (failureEnv_atoms he.1 hΓ) (returnAtoms_shift hR 1) (BuilderInvariant.empty _ _ _))
  intro eh heh
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨he.2.1, union_atoms (remainingEffect_atoms heb)
    (substEffAt_atoms (ts := [.base .unit]) (es := []) heh ⟨trivial, trivial⟩ (by simp) 0)⟩

end Benitoite.Surface.Check
