import Benitoite.Surface.CheckComputeAtoms

/-! 構文の各場合で、計算結果と要求の再帰的な支持を保存する。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem computes_builderOp {q o i args k} (ih : TypesComputes q args) :
    ExprComputes q (.builderOp o i args k) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hkind
  apply computes_bind (ih mode Δ C Γ R _ _ _ hq he.2 hΓ hR hB (o.params_atoms he.1))
  intro ε hε
  exact computes_pure ⟨o.result_atoms he.1, hε⟩

theorem computes_local {q i} : ExprComputes q (.local i) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro a ha
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨Env.atoms_get hΓ (lookup_local_ok ha), emptyEff_atoms _⟩

theorem computes_funName {q f ts es} : ExprComputes q (.funName f ts es) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro d hd
  repeat (apply computes_lift_bind; intro _ _)
  exact computes_pure ⟨fnTyCheck_atoms (hq.declarations.1 f d (lookup_ok hd)).1.1
    (hq.declarations.1 f d (lookup_ok hd)).1.2.1
    (hq.declarations.1 f d (lookup_ok hd)).1.2.2 he.1 he.2, emptyEff_atoms _⟩

theorem computes_primName {q b ts es} : ExprComputes q (.primName b ts es) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro s hs
  repeat (apply computes_lift_bind; intro _ _)
  have ha := hq.builtins b s (lookup_ok hs)
  exact computes_pure ⟨fnTyCheck_atoms ha.1 ha.2.1 ha.2.2 he.1 he.2, emptyEff_atoms _⟩

theorem computes_opName {q o ts} : ExprComputes q (.opName o ts) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro od hd
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  intro u hdict
  apply computes_lift_bind
  intro u hatom
  have ha := hq.declarations.2.2.1 o od (lookup_ok hd)
  exact computes_pure ⟨fnTyCheck_atoms ha.1 ha.2
    (singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok hatom).1)) he (by simp), emptyEff_atoms _⟩

theorem computes_nullCon {q c ts} : ExprComputes q (.nullCon c ts) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  exact computes_pure ⟨he, emptyEff_atoms _⟩

theorem computes_conValue {q c ts names ps} : ExprComputes q (.conValue c ts names ps) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  exact computes_pure ⟨⟨he.2, he.1, emptyEff_atoms _⟩, emptyEff_atoms _⟩

theorem computes_literal {q l} : ExprComputes q (.literal l) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  cases l <;> exact computes_pure ⟨trivial, emptyEff_atoms _⟩

theorem computes_block {q body} (ih : BlockComputes q body) : ExprComputes q (.block body) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  exact computes_guard (ih _ Δ _ _ _ _ _ hq he hΓ hR hB)

theorem computes_paren {q e} (ih : ExprComputes q e) : ExprComputes q (.paren e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  exact computes_guard (ih _ Δ _ _ _ _ _ hq he hΓ hR hB)

theorem computes_const {q t e} (ih : ExprComputes q e) : ExprComputes q (.constE t e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ih _ [] _ _ _ _ _ hq he.2 (Env.atoms_nil _) hR (BuilderInvariant.empty _ _ _))
  intro ε hε
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨he.1, emptyEff_atoms _⟩

theorem computes_conCall {q c ts args} (ih : TypesComputes q args) :
    ExprComputes q (.conCall c ts args) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro cd hd
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ih _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB
    (substParams_atoms he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))))
  intro ε hε
  exact computes_pure ⟨he.1, hε⟩

theorem computes_not {q e} (ih : ExprComputes q e) : ExprComputes q (.not e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ih _ Δ _ _ _ _ _ hq he hΓ hR hB)
  intro ε hε
  exact computes_pure ⟨trivial, hε⟩

theorem computes_neg {q t e} (ih : ExprComputes q e) : ExprComputes q (.neg t e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ih _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  intro ε hε
  exact computes_pure ⟨he.1, hε⟩

theorem computes_list {q t es} (ih : EachComputes q es) : ExprComputes q (.list t es) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ih _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB he.1)
  intro ε hε
  exact computes_pure ⟨he.1, hε⟩

theorem computes_lam {q names ps r ε body} (ih : BlockComputes q body) : ExprComputes q (.lam names ps r ε body) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ih _ [] _ _ _ _ _ hq he.2.2.2 (Env.atoms_append (Env.atoms_binds he.1) (Env.atoms_hideConts hΓ)) (fun t ht => by cases ht; exact he.2.1) (BuilderInvariant.empty _ _ _))
  intro εb hb
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨⟨he.1, he.2.1, he.2.2.1⟩, emptyEff_atoms _⟩


theorem computes_types_nil {q} : TypesComputes q .nil := by
  intro mode Δ C Γ R path index ts hq he hΓ hR hB ht
  cases ts
  · exact computes_pure (emptyEff_atoms _)
  · exact computes_throw

theorem computes_each_nil {q} : EachComputes q .nil := by
  intro mode Δ C Γ R path index a hq he hΓ hR hB ht
  exact computes_pure (emptyEff_atoms _)

theorem computes_types_cons {q e es} (ihe : ExprComputes q e) (ihs : TypesComputes q es) :
    TypesComputes q (.cons e es) := by
  intro mode Δ C Γ R path index ts hq he hΓ hR hB ht
  simp only [Exprs.AtomsIn] at he
  cases ts with
  | nil => exact computes_throw
  | cons t ts =>
    apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
    intro ε hε
    apply computes_bind (ihs _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht.2)
    intro εs hs
    exact computes_pure (union_atoms hε hs)

theorem computes_each_cons {q e es} (ihe : ExprComputes q e) (ihs : EachComputes q es) :
    EachComputes q (.cons e es) := by
  intro mode Δ C Γ R path index a hq he hΓ hR hB ht
  simp only [Exprs.AtomsIn] at he
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  intro ε hε
  apply computes_bind (ihs _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht)
  intro εs hs
  exact computes_pure (union_atoms hε hs)

theorem computes_holes_nil {q} : HolesComputes q .nil := by
  intro mode Δ C Γ R path index ts hq he hΓ hR hB ht
  cases ts
  · exact computes_pure (emptyEff_atoms _)
  · exact computes_throw

theorem computes_holes_expr {q label position e args} (ihe : ExprComputes q e) (ihs : HolesComputes q args) :
    HolesComputes q (.expr label position e args) := by
  intro mode Δ C Γ R path index ts hq he hΓ hR hB ht
  simp only [HoleArgs.AtomsIn] at he
  cases ts with
  | nil => exact computes_throw
  | cons t ts =>
    apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
    intro ε hε
    apply computes_bind (ihs _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht.2)
    intro εs hs
    exact computes_pure (union_atoms hε hs)

theorem computes_holes_hole {q label position t args} (ihs : HolesComputes q args) :
    HolesComputes q (.hole label position t args) := by
  intro mode Δ C Γ R path index ts hq he hΓ hR hB ht
  simp only [HoleArgs.AtomsIn] at he
  cases ts with
  | nil => exact computes_throw
  | cons a ts =>
    apply computes_lift_bind
    intro u hu
    exact ihs _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht.2

theorem computes_arms_nil {q} : ArmsComputes q .nil := by
  intro mode Δ C Γ R p path a b hq he hΓ hR hB ha hb
  apply computes_lift_bind
  intro u hu
  exact computes_pure (emptyEff_atoms _)

theorem computes_arms_cons {q alts guard body rest}
    (ihg : ∀ g, guard = some g → ExprComputes q g)
    (ihb : BlockComputes q body) (ihr : ArmsComputes q rest) :
    ArmsComputes q (.cons alts guard body rest) := by
  intro mode Δ C Γ R p path a b hq he hΓ hR hB ha hb
  simp only [Arms.AtomsIn] at he
  rw [checkArmsR]
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  intro δ hδ
  have hδ := altsTy_atoms (Declarations.atoms_con hq.declarations) ha (lookup_ok hδ)
  have henv := Env.atoms_append (Env.atoms_binds hδ) hΓ
  cases guard with
  | none =>
    apply computes_accept_bind (ihb _ (List.replicate δ.length none ++ Δ) _ _ _ _ _ hq he.2.1 henv hR (hB.values δ))
    intro ε hε
    apply computes_bind (ihr _ Δ _ _ _ _ _ _ _ hq he.2.2 hΓ hR hB ha hb)
    intro εs hs
    exact computes_pure (union_atoms hε hs)
  | some g =>
    apply computes_accept_bind (ihg g rfl _ (List.replicate δ.length none ++ Δ) _ _ _ _ _ hq (he.1 g rfl) (Env.atoms_hideConts henv) (fun t ht => by cases ht) ((hB.values δ).hide))
    intro ε hε
    apply computes_lift_bind
    intro u hu
    apply computes_accept_bind (ihb _ (List.replicate δ.length none ++ Δ) _ _ _ _ _ hq he.2.1 henv hR (hB.values δ))
    intro ε hε
    apply computes_bind (ihr _ Δ _ _ _ _ _ _ _ hq he.2.2 hΓ hR hB ha hb)
    intro εs hs
    exact computes_pure (union_atoms hε hs)

theorem computes_clauses_nil {q} : ClausesComputes q .nil := by
  intro mode Δ C Γ R path t ε hq he hΓ hR hB ht hε
  exact computes_pure (emptyEff_atoms _)

theorem computes_clauseTypes_nil {q} : ClauseTypesComputes q .nil := by
  intro Δ C Γ R path t ε hq he hΓ hR hB ht hε
  exact computes_pure ht

theorem computes_clauses_cons {q o n ntys body rest ndicts}
    (ihb : BlockComputes q body) (ihr : ClausesComputes q rest) :
    ClausesComputes q (.cons o n ntys body rest ndicts) := by
  intro mode Δ C Γ R path t ε hq he hΓ hR hB ht hε
  simp only [Clauses.AtomsIn] at he
  apply computes_lift_bind
  intro sg hsg
  repeat (apply computes_lift_bind; intro _ _)
  have hsg := opSig_atoms hq.declarations hq.builtins (lookup_ok hsg)
  apply computes_accept_bind (ihb _ [] _ _ _ _ _ hq he.1 (clauseEnv_atoms hsg.1 hsg.2 ht hε hΓ) (returnAtoms_shift hR ntys) (BuilderInvariant.empty _ _ _))
  intro εb hb
  apply computes_bind computes_get
  intro st hst
  split
  all_goals
    repeat (apply computes_lift_bind; intro _ _)
    apply computes_bind (ihr _ Δ _ _ _ _ _ _ hq he.2 hΓ hR hB ht hε)
    intro εs hs
    exact computes_pure (union_atoms
      (substEffAt_atoms hb (tysAtoms_replicate (show Ty.AtomsIn q.atoms (.base .unit) from trivial) ntys) (by simp) 0) hs)

theorem computes_clauseTypes_cons {q o n ntys body rest ndicts}
    (ihb : BlockComputes q body) (ihr : ClauseTypesComputes q rest) :
    ClauseTypesComputes q (.cons o n ntys body rest ndicts) := by
  intro Δ C Γ R path t ε hq he hΓ hR hB ht hε
  simp only [Clauses.AtomsIn] at he
  apply computes_lift_bind
  intro sg hsg
  repeat (apply computes_lift_bind; intro _ _)
  have hsg := opSig_atoms hq.declarations hq.builtins (lookup_ok hsg)
  apply computes_bind (ihb _ [] _ _ _ _ _ hq he.1 (clauseEnv_atoms hsg.1 hsg.2 ht hε hΓ) (returnAtoms_shift hR ntys) (BuilderInvariant.empty _ _ _))
  rintro ⟨a, δ⟩ ⟨ha, hδ⟩
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  intro j hj
  have ha' := substTy_atoms (es := ([] : List Eff)) ha (tysAtoms_replicate (show Ty.AtomsIn q.atoms (.base .unit) from trivial) ntys) (by simp)
  exact ihr Δ _ _ _ _ _ _ hq he.2 hΓ hR hB (join_atoms ht ha' hj) hε


theorem computes_block_builderBind {q k rest} (ihr : BlockComputes q rest) :
    BlockComputes q (.builderBind k rest) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hkind
  have hk := Bool.and_eq_true_iff.mp (require_ok hkind).1
  have hc := (cleanTy_spec _ _ he.1).mp hk.1
  have hs := (singleTyCheck_spec _ he.1).mp hk.2
  exact ihr mode (some k :: Δ) C (none :: Γ) R p _ hq he.2
    (by intro t ht; exact hΓ t (by simpa using ht)) hR (hB.builder hc he.1 hs)

theorem computes_block_empty {q} : BlockComputes q .empty := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  exact computes_guard (computes_pure ⟨trivial, emptyEff_atoms _⟩)

theorem computes_block_last {q e} (ih : ExprComputes q e) : BlockComputes q (.last e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  exact computes_guard (ih _ Δ _ _ _ _ _ hq he hΓ hR hB)

theorem computes_block_lastBind {q name t e} (ih : ExprComputes q e) :
    BlockComputes q (.lastBind name t e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ih _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  intro ε hε
  exact computes_pure ⟨trivial, hε⟩

theorem computes_block_lastDiscard {q e} (ih : ExprComputes q e) : BlockComputes q (.lastDiscard e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_bind (ih _ Δ _ _ _ _ _ hq he hΓ hR hB)
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  exact computes_pure ⟨trivial, hε⟩

theorem computes_block_bind {q name t e rest} (ihe : ExprComputes q e) (ihr : BlockComputes q rest) :
    BlockComputes q (.bind name t e rest) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.2.1 hΓ hR hB)
  intro ε hε
  apply computes_bind (ihr _ (none :: Δ) _ _ _ _ _ hq he.2.2 (Env.atoms_cons hΓ he.1) hR (hB.value _))
  rintro ⟨a, εs⟩ ⟨ha, hs⟩
  exact computes_pure ⟨ha, union_atoms hε hs⟩

theorem computes_block_discard {q e rest} (ihe : ExprComputes q e) (ihr : BlockComputes q rest) :
    BlockComputes q (.discard e rest) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_bind (ihe _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  rintro ⟨t, ε⟩ ⟨ht, hε⟩
  apply computes_bind (ihr _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  rintro ⟨a, εs⟩ ⟨ha, hs⟩
  exact computes_pure ⟨ha, union_atoms hε hs⟩

theorem computes_block_seq {q e rest} (ihe : ExprComputes q e) (ihr : BlockComputes q rest) :
    BlockComputes q (.seq e rest) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  intro ε hε
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ihr _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  rintro ⟨a, εs⟩ ⟨ha, hs⟩
  exact computes_pure ⟨ha, union_atoms hε hs⟩

theorem computes_block_lastPat {q name pat t e} (ihe : ExprComputes q e) :
    BlockComputes q (.lastPat name pat t e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  intro ε hε
  exact computes_pure ⟨trivial, hε⟩

theorem computes_block_bindPat {q name pat t e rest} (ihe : ExprComputes q e) (ihr : BlockComputes q rest) :
    BlockComputes q (.bindPat name pat t e rest) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Block.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  intro δ hδ
  apply computes_lift_bind
  intro u hu
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.2.1 hΓ hR hB)
  intro ε hε
  apply computes_bind (ihr _ (List.replicate δ.length none ++ Δ) _ _ _ _ _ hq he.2.2 (Env.atoms_append (Env.atoms_binds (surfacePatTy_atoms hq.declarations he.1 (lookup_ok hδ))) hΓ) hR (hB.values δ))
  rintro ⟨a, εs⟩ ⟨ha, hs⟩
  exact computes_pure ⟨ha, union_atoms hε hs⟩

theorem computes_ite {q c y n} (ihc : ExprComputes q c) (ihy : BlockComputes q y) (ihn : BlockComputes q n) :
    ExprComputes q (.ite c y n) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ihc _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  intro εc hc
  apply computes_bind (ihy _ Δ _ _ _ _ _ hq he.2.1 hΓ hR hB)
  rintro ⟨ay, εy⟩ ⟨hy, hεy⟩
  apply computes_bind (ihn _ Δ _ _ _ _ _ hq he.2.2 hΓ hR hB)
  rintro ⟨an, εn⟩ ⟨hn, hεn⟩
  apply computes_lift_bind
  intro j hj
  exact computes_pure ⟨join_atoms hy hn hj, union_atoms hc (union_atoms hεy hεn)⟩

theorem computes_elseIf {q c y n} (ihc : ExprComputes q c) (ihy : BlockComputes q y) (ihn : ExprComputes q n) :
    ExprComputes q (.elseIf c y n) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_accept_bind (ihc _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  intro εc hc
  apply computes_bind (ihy _ Δ _ _ _ _ _ hq he.2.1 hΓ hR hB)
  rintro ⟨ay, εy⟩ ⟨hy, hεy⟩
  apply computes_bind (ihn _ Δ _ _ _ _ _ hq he.2.2 hΓ hR hB)
  rintro ⟨an, εn⟩ ⟨hn, hεn⟩
  apply computes_lift_bind
  intro j hj
  exact computes_pure ⟨join_atoms hy hn hj, union_atoms hc (union_atoms hεy hεn)⟩

theorem computes_ifOnly {q c y} (ihc : ExprComputes q c) (ihy : BlockComputes q y) :
    ExprComputes q (.ifOnly c y) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ihc _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  intro εc hc
  apply computes_accept_bind (ihy _ Δ _ _ _ _ _ hq he.2 hΓ hR hB)
  intro εy hy
  exact computes_pure ⟨trivial, union_atoms hc hy⟩

theorem computes_return {q a e} (ihe : ExprComputes q e) : ExprComputes q (.returnE a e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro r hr
  have hret : ReturnAtoms q.atoms (some r) := by
    intro t ht; cases ht; exact hR r (lookup_ok hr)
  cases p
  · apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.2 hΓ hret hB)
    intro ε hε
    exact computes_pure ⟨hR r (lookup_ok hr), hε⟩
  · apply computes_lift_bind
    intro u hu
    apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.2 hΓ hret hB)
    intro ε hε
    exact computes_pure ⟨he.1, hε⟩

theorem computes_lazy {q b} (ihb : BlockComputes q b) : ExprComputes q (.lazyE b) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_bind (ihb _ [] _ _ _ _ _ hq he (Env.atoms_hideConts hΓ) (fun t ht => by cases ht) (BuilderInvariant.empty _ _ _))
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨ha, emptyEff_atoms _⟩

theorem computes_with {q o e b} (ihe : ExprComputes q e) (ihb : BlockComputes q b) :
    ExprComputes q (.withE o e b) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  intro u hatom
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he.1 hΓ hR hB)
  intro εe hee
  apply computes_bind (ihb _ (none :: Δ) _ _ _ _ _ hq he.2 (Env.atoms_cons hΓ (by trivial)) hR (hB.value _))
  rintro ⟨a, εb⟩ ⟨ha, hb⟩
  exact computes_pure ⟨ha, union_atoms hee (union_atoms hb
    (singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok hatom).1)))⟩

theorem computes_resume {q k e} (ihe : ExprComputes q e) : ExprComputes q (.resume k e) := by
  intro mode Δ C Γ R p path hq he hΓ hR hB
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro a ha
  have hat := Env.atoms_get hΓ (lookup_local_ok ha)
  cases a <;> try exact computes_throw
  rename_i b t ε
  apply computes_accept_bind (ihe _ Δ _ _ _ _ _ hq he hΓ hR hB)
  intro εarg harg
  apply computes_bind computes_get
  intro st hst
  split
  · apply computes_lift_bind
    intro u hu
    exact computes_pure ⟨hat.2.1, hat.2.2⟩
  · apply computes_bind (computes_modify (f := fun st => { st with requests := (Γ.length - (k + 1), εarg) :: st.requests })
      (fun s hs => requests_atoms_cons (r := (Γ.length - (k + 1), εarg)) harg hs))
    intro u hu
    exact computes_pure ⟨hat.2.1, hat.2.2⟩

end Benitoite.Surface.Check
