import Benitoite.Surface.CheckComputeControl

/-! パイプの右辺の形に応じた計算の支持保存。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem pipe_computes_atoms {atoms lhs rhs} :
    (Expr.pipe lhs rhs).AtomsIn atoms ↔ lhs.AtomsIn atoms ∧ rhs.AtomsIn atoms := by
  simp only [Expr.AtomsIn]

theorem tysAtoms_tail {atoms ps} (hp : Tys.AtomsIn atoms ps) : Tys.AtomsIn atoms ps.tail := by
  cases ps with
  | nil => trivial
  | cons t ts => exact hp.2

theorem computes_pipe_call {q lhs f labels positions args}
    (ihl : ExprComputes q lhs) (ihf : ExprComputes q f) (iha : TypesComputes q args) :
    ExprComputes q (.pipe lhs (.call f labels positions args)) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_bind (ihf _ _ _ _ _ _ hq he.2.1 hΓ hR)
  rintro ⟨a, εf⟩ ⟨ha, hf⟩
  apply computes_lift_bind
  rintro ⟨names, ps, r, εcall⟩ hv
  have eq := fnView_ok hv
  subst a
  apply computes_lift_bind
  intro t ht
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq he.1 hΓ hR)
  intro εl hl
  apply computes_lift_bind
  intro u hu
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2.2 hΓ hR (sourceTypes_atoms ha.1))
  intro εargs hargs
  exact computes_pure ⟨ha.2.1, union_atoms hl (union_atoms hf (union_atoms hargs ha.2.2))⟩

theorem computes_pipe_conCall {q lhs c ts args}
    (ihl : ExprComputes q lhs) (iha : TypesComputes q args) :
    ExprComputes q (.pipe lhs (.conCall c ts args)) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro cd hcd
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq he.1 hΓ hR)
  intro εl hl
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2.2 hΓ hR
    (tysAtoms_tail (substParams_atoms he.2.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hcd)))))
  intro εargs hargs
  exact computes_pure ⟨he.2.1, union_atoms hl hargs⟩

theorem computes_pipe_conValue {q lhs c ts names ps} (ihl : ExprComputes q lhs) :
    ExprComputes q (.pipe lhs (.conValue c ts names ps)) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq he.1 hΓ hR)
  intro εl hl
  exact computes_pure ⟨he.2.1, hl⟩

/-- 右辺の特別な構文の場合分けを済ませた後の、一般の関数値の計算。 -/
theorem computes_pipe_value {q lhs rhs} (ihl : ExprComputes q lhs) (ihr : ExprComputes q rhs)
    {mode C Γ R path} (hq : q.Sound) (hl : lhs.AtomsIn q.atoms) (hr : rhs.AtomsIn q.atoms)
    (hΓ : Env.AtomsIn q.atoms Γ) (hR : ReturnAtoms q.atoms R) :
    ComputesIn q (Inferred.AtomsIn q.atoms) (do
      require (child path 1) "invalid pipe value" (pipeValue rhs)
      let (a, εf) ← checkExprR q mode C Γ R .other (child path 1) rhs
      let (names, ps, r, εcall) ← fnView (child path 1) a
      require (child path 1) "pipe value must have one parameter and one name"
        ((ps.length == 1) && (names.length == 1))
      let t ← lookup (child path 1) "pipe value has no parameter" ps.head?
      let εl ← accept q C.length (child path 0) t (← checkExprR q mode C Γ R .other (child path 0) lhs)
      pure (r, union q εl (union q εf εcall))) := by
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ihr _ _ _ _ _ _ hq hr hΓ hR)
  rintro ⟨a, εf⟩ ⟨ha, hf⟩
  apply computes_lift_bind
  rintro ⟨names, ps, r, εcall⟩ hv
  have eq := fnView_ok hv
  subst a
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq hl hΓ hR)
  intro εl hl
  exact computes_pure ⟨ha.2.1, union_atoms hl (union_atoms hf ha.2.2)⟩

end Benitoite.Surface.Check
