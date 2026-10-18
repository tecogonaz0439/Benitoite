import Benitoite.Surface.CheckComputeCases

/-! 呼び出し・レコード・演算子の計算が支持を保つことの証明。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem computes_funDicts {q f ts es ds names ps} : ExprComputes q (.funDicts f ts es ds names ps) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro d hd
  repeat (apply computes_lift_bind; intro _ _)
  have ha := (hq.declarations.1 f d (lookup_ok hd)).1
  exact computes_pure ⟨fnTyCheck_atoms ha.1 ha.2.1 ha.2.2 he.1 he.2.1, emptyEff_atoms _⟩

theorem computes_opDicts {q o ts ds names ps} : ExprComputes q (.opDicts o ts ds names ps) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro od hd
  repeat (apply computes_lift_bind; intro _ _)
  rename_i u hatom
  have ha := hq.declarations.2.2.1 o od (lookup_ok hd)
  exact computes_pure ⟨fnTyCheck_atoms (OpDecl.valueParams_atoms ha.1) ha.2
    (singleEff_atoms _ _ (List.mem_of_elem_eq_true (require_ok hatom).1)) he.1 (by simp), emptyEff_atoms _⟩

theorem computes_methName {q d m ts es ds names ps} :
    ExprComputes q (.methName d m ts es ds names ps) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro a ha
  have had := checkDict_atoms d hq he.1 hΓ ha
  apply computes_lift_bind
  rintro ⟨cl, τ⟩ hv
  have eq := dictView_ok hv
  subst a
  apply computes_lift_bind
  intro cd hcd
  apply computes_lift_bind
  intro ms hms
  repeat (apply computes_lift_bind; intro _ _)
  have hms := hq.declarations.2.2.2.1 cl cd m ms (lookup_ok hcd) (lookup_ok hms)
  have hts := tysAtoms_append he.2.1 (show Tys.AtomsIn q.atoms [τ] from ⟨had, trivial⟩)
  exact computes_pure ⟨⟨he.2.2.2.2, substTy_atoms hms.2.1 hts he.2.2.1,
    substEffAt_atoms hms.2.2 hts he.2.2.1 0⟩, emptyEff_atoms _⟩

theorem computes_call {q f labels positions args} (ihf : ExprComputes q f) (iha : TypesComputes q args) :
    ExprComputes q (.call f labels positions args) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_bind (ihf _ _ _ _ _ _ hq he.1 hΓ hR)
  rintro ⟨a, εf⟩ ⟨ha, hf⟩
  apply computes_lift_bind
  rintro ⟨names, ps, r, εcall⟩ hv
  have eq := fnView_ok hv
  subst a
  apply computes_lift_bind
  intro u hu
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2 hΓ hR (sourceTypes_atoms ha.1))
  intro εargs hargs
  exact computes_pure ⟨ha.2.1, union_atoms hf (union_atoms hargs ha.2.2)⟩

theorem computes_record {q c ts positions args} (iha : TypesComputes q args) :
    ExprComputes q (.record c ts positions args) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro cd hcd
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2 hΓ hR
    (fieldTypes_atoms (substParams_atoms he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hcd)))))
  intro ε hε
  exact computes_pure ⟨he.1, hε⟩

theorem computes_recordUpdate {q c ts n positions base args}
    (ihb : ExprComputes q base) (iha : TypesComputes q args) :
    ExprComputes q (.recordUpdate c ts n positions base args) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro cd hcd
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihb _ _ _ _ _ _ hq he.2.1 hΓ hR)
  intro εb hb
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2.2 hΓ hR
    (fieldTypes_atoms (substParams_atoms he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hcd)))))
  intro εa ha
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨he.1, union_atoms hb ha⟩

theorem computes_partialCall {q f names args r ε}
    (ihf : ExprComputes q f) (iha : HolesComputes q args) :
    ExprComputes q (.partialCall f names args r ε) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ihf _ _ _ _ _ _ hq he.1 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.2.2.1))
  rintro ⟨a, εf⟩ ⟨ha, hf⟩
  apply computes_lift_bind
  rintro ⟨calleeNames, ps, r0, εcall⟩ hv
  have eq := fnView_ok hv
  subst a
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2.1 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.2.2.1) (sourceTypes_atoms ha.1))
  intro εargs hargs
  repeat (apply computes_lift_bind; intro _ _)
  exact computes_pure ⟨⟨holeTypes_atoms he.2.1, he.2.2.1, he.2.2.2⟩, emptyEff_atoms _⟩

theorem computes_partialCon {q c ts args} (iha : HolesComputes q args) :
    ExprComputes q (.partialCon c ts args) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro cd hcd
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.1)
    (substParams_atoms he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hcd))))
  intro εargs hargs
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨⟨holeTypes_atoms he.2, he.1,
    by rw [Eff.normWith_eq_norm q.atoms _ hargs]; exact Eff.norm_support _ hargs⟩, emptyEff_atoms _⟩

theorem computes_binary {q o t lhs rhs} (ihl : ExprComputes q lhs) (ihr : ExprComputes q rhs) :
    ExprComputes q (.binary o t lhs rhs) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_lift_bind
  rintro ⟨b, ts⟩ hop
  apply computes_lift_bind
  intro s hs
  apply computes_lift_bind
  intro u1 hu1
  apply computes_lift_bind
  intro u2 hu2
  apply computes_lift_bind
  intro u3 hu3
  apply computes_lift_bind
  rintro ⟨names, ps, r, ε⟩ hv
  have hsig := hq.builtins b s (lookup_ok hs)
  have ht : (fnTyCheck q.atoms s.names s.params s.ret s.eff ts []).AtomsIn q.atoms :=
    fnTyCheck_atoms hsig.1 hsig.2.1 hsig.2.2
    (hq.operators.atoms he.1 (lookup_ok hop)) (by simp)
  have eq := fnView_ok hv
  rw [eq] at ht
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq he.2.1 hΓ hR)
  intro εl hl
  apply computes_accept_bind (ihr _ _ _ _ _ _ hq he.2.2 hΓ hR)
  intro εr hr
  exact computes_pure ⟨ht.2.1, union_atoms hl hr⟩

theorem computes_and {q lhs rhs} (ihl : ExprComputes q lhs) (ihr : ExprComputes q rhs) :
    ExprComputes q (.and lhs rhs) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq he.1 hΓ hR)
  intro εl hl
  apply computes_accept_bind (ihr _ _ _ _ _ _ hq he.2 hΓ hR)
  intro εr hr
  exact computes_pure ⟨trivial, union_atoms hl hr⟩

theorem computes_or {q lhs rhs} (ihl : ExprComputes q lhs) (ihr : ExprComputes q rhs) :
    ExprComputes q (.or lhs rhs) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_accept_bind (ihl _ _ _ _ _ _ hq he.1 hΓ hR)
  intro εl hl
  apply computes_accept_bind (ihr _ _ _ _ _ _ hq he.2 hΓ hR)
  intro εr hr
  exact computes_pure ⟨trivial, union_atoms hl hr⟩

theorem computes_listSpread {q t f before spread after} (ihf : ExprComputes q f)
    (ihb : EachComputes q before) (ihs : ExprComputes q spread) (iha : EachComputes q after) :
    ExprComputes q (.listSpread t f before spread after) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  repeat (apply computes_lift_bind; intro _ _)
  apply computes_accept_bind (ihf _ _ _ _ _ _ hq he.2.1 hΓ hR)
  intro εf hf
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ihb _ _ _ _ _ _ _ hq he.2.2.1 hΓ hR he.1)
  intro εb hb
  apply computes_accept_bind (ihs _ _ _ _ _ _ hq he.2.2.2.1 hΓ hR)
  intro εs hs
  apply computes_bind (iha _ _ _ _ _ _ _ hq he.2.2.2.2 hΓ hR he.1)
  intro εa ha
  exact computes_pure ⟨he.1, union_atoms hb (union_atoms hs ha)⟩

theorem computes_interpolation {q parts es fs} (ihe : TypesComputes q es) (ihf : TypesComputes q fs) :
    ExprComputes q (.interpolation parts es fs) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  have ht := interpolation_types_atoms he.1
  apply computes_bind (ihe _ _ _ _ _ _ _ hq he.2.1 hΓ hR ht.1)
  intro ε hε
  apply computes_bind (ihf _ _ _ _ _ _ _ hq he.2.2 hΓ hR ht.2)
  intro εf hf
  repeat (apply computes_lift_bind; intro _ _)
  exact computes_pure ⟨trivial, hε⟩

theorem computes_match {q t e arms} (ihe : ExprComputes q e) (iha : ArmsComputes q arms) :
    ExprComputes q (.matchE t e arms) := by
  intro mode C Γ R p path hq he hΓ hR
  simp only [Expr.AtomsIn] at he
  apply computes_guard
  apply computes_lift_bind
  intro u hu
  apply computes_bind (ihe _ _ _ _ _ _ hq he.2.1 hΓ hR)
  rintro ⟨a, ε⟩ ⟨ha, hε⟩
  apply computes_bind (iha _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR ha he.1)
  intro εa haa
  apply computes_lift_bind
  intro u hu
  exact computes_pure ⟨he.1, union_atoms hε haa⟩

end Benitoite.Surface.Check
