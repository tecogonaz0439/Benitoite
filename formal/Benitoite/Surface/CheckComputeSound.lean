import Benitoite.Surface.CheckComputePipe

/-! strictとrelaxedの全計算についての再帰的な支持保存。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

inductive ComputeNode where
  | expr (e : Expr)
  | exprs (es : Exprs)
  | holes (args : HoleArgs)
  | arms (arms : Arms)
  | clauses (cs : Clauses)
  | block (body : Block)

noncomputable def ComputeNode.size : ComputeNode → Nat
  | .expr e => sizeOf e
  | .exprs es => sizeOf es
  | .holes args => sizeOf args
  | .arms as_ => sizeOf as_
  | .clauses cs => sizeOf cs
  | .block body => sizeOf body

def NodeComputes (q : Input) : ComputeNode → Prop
  | .expr e => ExprComputes q e
  | .exprs es => TypesComputes q es ∧ EachComputes q es
  | .holes args => HolesComputes q args
  | .arms arms => ArmsComputes q arms
  | .clauses cs => ClausesComputes q cs ∧ ClauseTypesComputes q cs
  | .block body => BlockComputes q body

macro "compute_child " ih:ident : tactic => `(tactic| first
  | (refine $ih (.expr _) ?_; simp [ComputeNode.size] <;> omega)
  | (refine ($ih (.exprs _) ?_).1; simp [ComputeNode.size] <;> omega)
  | (refine ($ih (.exprs _) ?_).2; simp [ComputeNode.size] <;> omega)
  | (refine $ih (.holes _) ?_; simp [ComputeNode.size] <;> omega)
  | (refine $ih (.arms _) ?_; simp [ComputeNode.size] <;> omega)
  | (refine ($ih (.clauses _) ?_).1; simp [ComputeNode.size] <;> omega)
  | (refine ($ih (.clauses _) ?_).2; simp [ComputeNode.size] <;> omega)
  | (refine $ih (.block _) ?_; simp [ComputeNode.size] <;> omega))

/-- 子の結果と要求を同時に保存し、探索に型付けを仮定しない。 -/
theorem nodeComputes (q : Input) (node : ComputeNode) : NodeComputes q node := by
  induction node using (measure ComputeNode.size).wf.induction with
  | h node ih =>
    change ∀ child, child.size < node.size → NodeComputes q child at ih
    cases node with
    | expr e =>
      cases e with
      | builderOp => apply computes_builderOp <;> compute_child ih
      | «local» => apply computes_local <;> compute_child ih
      | «constE» => apply computes_const <;> compute_child ih
      | «funName» => apply computes_funName <;> compute_child ih
      | «funDicts» => apply computes_funDicts <;> compute_child ih
      | «opDicts» => exact computes_opDicts
      | «methName» => apply computes_methName <;> compute_child ih
      | «primName» => apply computes_primName <;> compute_child ih
      | raise => exact computes_raise
      | handleFail => apply computes_handleFail <;> compute_child ih
      | «opName» => apply computes_opName <;> compute_child ih
      | «nullCon» => apply computes_nullCon <;> compute_child ih
      | «conValue» => apply computes_conValue <;> compute_child ih
      | «literal» => apply computes_literal <;> compute_child ih
      | «paren» => apply computes_paren <;> compute_child ih
      | «block» => apply computes_block <;> compute_child ih
      | «conCall» => apply computes_conCall <;> compute_child ih
      | «record» => apply computes_record <;> compute_child ih
      | «recordUpdate» => apply computes_recordUpdate <;> compute_child ih
      | «call» => apply computes_call <;> compute_child ih
      | «partialCall» => apply computes_partialCall <;> compute_child ih
      | «partialCon» => apply computes_partialCon <;> compute_child ih
      | «binary» => apply computes_binary <;> compute_child ih
      | «neg» => apply computes_neg <;> compute_child ih
      | «not» => apply computes_not <;> compute_child ih
      | «and» => apply computes_and <;> compute_child ih
      | «or» => apply computes_or <;> compute_child ih
      | «list» => apply computes_list <;> compute_child ih
      | «listSpread» => apply computes_listSpread <;> compute_child ih
      | «interpolation» => apply computes_interpolation <;> compute_child ih
      | «lam» => apply computes_lam <;> compute_child ih
      | «ite» => apply computes_ite <;> compute_child ih
      | «elseIf» => apply computes_elseIf <;> compute_child ih
      | «ifOnly» => apply computes_ifOnly <;> compute_child ih
      | «matchE» => apply computes_match <;> compute_child ih
      | «returnE» => apply computes_return <;> compute_child ih
      | «tryResult» => apply computes_tryResult <;> compute_child ih
      | «tryOption» => apply computes_tryOption <;> compute_child ih
      | «withE» => apply computes_with <;> compute_child ih
      | «lazyE» => apply computes_lazy <;> compute_child ih
      | «handleE» => apply computes_handle <;> compute_child ih
      | «resume» => apply computes_resume <;> compute_child ih
      | negInt =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | negFloat =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | negDecimal =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | negInteger8 =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | negInteger16 =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | negInteger32 =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | negFloat32 =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | unit =>
        intro mode Δ C Γ R p path hq he hΓ hR hB
        exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)
      | tryResultDie =>
        apply computes_tryResultDie
        · compute_child ih
        · intro m hm
          subst_vars
          compute_child ih
      | tryOptionDie =>
        apply computes_tryOptionDie
        · compute_child ih
        · intro m hm
          subst_vars
          compute_child ih
      | pipe lhs rhs =>
        have hl : ExprComputes q lhs := by compute_child ih
        have hr : ExprComputes q rhs := by compute_child ih
        cases rhs <;> first
          | (apply computes_pipe_call hl <;> compute_child ih)
          | (apply computes_pipe_conCall hl <;> compute_child ih)
          | exact computes_pipe_conValue hl
          | (intro mode Δ C Γ R p path hq he hΓ hR hB
             have he := pipe_computes_atoms.mp he
             apply computes_guard
             exact computes_pipe_value hl hr hB hq he.1 he.2 hΓ hR)
    | exprs es =>
      cases es with
      | nil => exact ⟨computes_types_nil, computes_each_nil⟩
      | cons e es =>
        constructor
        · apply computes_types_cons <;> compute_child ih
        · apply computes_each_cons <;> compute_child ih
    | holes args =>
      cases args with
      | nil => exact computes_holes_nil
      | expr => apply computes_holes_expr <;> compute_child ih
      | hole => apply computes_holes_hole <;> compute_child ih
    | arms arms =>
      cases arms with
      | nil => exact computes_arms_nil
      | cons alts guard body rest =>
        apply computes_arms_cons
        · intro g hg
          subst guard
          compute_child ih
        · compute_child ih
        · compute_child ih
    | clauses cs =>
      cases cs with
      | nil => exact ⟨computes_clauses_nil, computes_clauseTypes_nil⟩
      | cons =>
        constructor
        · apply computes_clauses_cons <;> compute_child ih
        · apply computes_clauseTypes_cons <;> compute_child ih
    | block body =>
      cases body with
      | builderBind => apply computes_block_builderBind <;> compute_child ih
      | empty => exact computes_block_empty
      | last => apply computes_block_last <;> compute_child ih
      | lastBind => apply computes_block_lastBind <;> compute_child ih
      | lastDiscard => apply computes_block_lastDiscard <;> compute_child ih
      | bind => apply computes_block_bind <;> compute_child ih
      | discard => apply computes_block_discard <;> compute_child ih
      | seq => apply computes_block_seq <;> compute_child ih
      | lastPat => apply computes_block_lastPat <;> compute_child ih
      | bindPat => apply computes_block_bindPat <;> compute_child ih

/-- 初期状態の要求を含め、任意の探索モードで支持を保存する。 -/
theorem checkExprR_computes (q : Input) (e : Expr) : ExprComputes q e := nodeComputes q (.expr e)
theorem checkBlockR_computes (q : Input) (b : Block) : BlockComputes q b := nodeComputes q (.block b)
theorem checkClausesR_computes (q : Input) (cs : Clauses) : ClausesComputes q cs :=
  (nodeComputes q (.clauses cs)).1
theorem inferClauseTypesR_computes (q : Input) (cs : Clauses) : ClauseTypesComputes q cs :=
  (nodeComputes q (.clauses cs)).2

/-- 反復の各stepは空の要求から検査するので、外側の状態の支持を要求しない。 -/
theorem handlerStep_atoms {q Δ C Γ R path cs t e out s s'}
    (hB : BuilderInvariant q C Γ Δ) (hq : q.Sound) (hc : cs.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : t.AtomsIn q.atoms) (he : e.AtomsIn q.atoms)
    (h : (do
      let (actual, st) ← (checkClausesR q .relaxed Δ C Γ R path cs t e).run {}
      modify fun outer => { outer with requests := outer.requests ++
        (st.requests.filter (fun r => !(clauseKeys Γ.length cs).contains r.1)) }
      pure (union q actual (requestedEffect q (clauseKeys Γ.length cs) st.requests)) : Checking Eff)
        s = .ok (out, s')) : out.AtomsIn q.atoms := by
  obtain ⟨⟨actual, st⟩, hcs, h⟩ := checking_lift_bind_ok h
  have hs := (checkClausesR_computes q cs .relaxed Δ C Γ R path t e hq hc hΓ hR hB ht he)
    {} st actual (requests_atoms_nil _) hcs
  obtain ⟨u, mid, hu, h⟩ := checking_bind_ok h
  have eq := (checking_pure_ok h).1
  subst out
  exact union_atoms hs.1 (requestedEffect_atoms q _ st.requests hs.2)

end Benitoite.Surface.Check
