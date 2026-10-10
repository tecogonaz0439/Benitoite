import Benitoite.Surface.CheckSoundDicts

/-! 名前・定数・リテラル・演算子の検査の健全性。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem literal_case {q l} : CaseSound q (.expr (.literal l)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Literal, by cases l <;> trivial, emptyEff_atoms _⟩

theorem negInt_case {q n} : CaseSound q (.expr (.negInt n)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_NegInt, by trivial, emptyEff_atoms _⟩

theorem negFloat_case {q x} : CaseSound q (.expr (.negFloat x)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_NegFloat, by trivial, emptyEff_atoms _⟩

theorem negDecimal_case {q n scale} : CaseSound q (.expr (.negDecimal n scale)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_NegDecimal, by trivial, emptyEff_atoms _⟩

theorem unit_case {q} : CaseSound q (.expr .unit) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Unit, by trivial, emptyEff_atoms _⟩

theorem local_case {q i} : CaseSound q (.expr (.local i)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  obtain ⟨t, ht, h⟩ := checking_lift_bind_ok h
  obtain ⟨u, hu, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Local (lookup_local_ok ht) ((notCont_spec _).mp (require_ok hu).1),
    Env.atoms_get hΓ (lookup_local_ok ht), emptyEff_atoms _⟩

theorem const_case {q t body} : CaseSound q (.expr (.constE t body)) := by
  intro ih
  have ihb : ExprSound q body := ih (.expr body) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εb, mid, ht, hb, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihb _ _ _ _ _ _ _ _ _ hq he.2 (Env.atoms_nil _) hR hc) he.1 h
  obtain ⟨u, hu, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Const (.E_Sub ht (Or.inl rfl) (acceptEff_sound hb hu)), he.1, emptyEff_atoms _⟩

theorem paren_case {q e} : CaseSound q (.expr (.paren e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  have ht := ihe _ _ _ _ _ _ _ _ _ hq he hΓ hR h
  exact ⟨.E_Paren ht.1, ht.2⟩

theorem funName_case {q f ts es} : CaseSound q (.expr (.funName f ts es)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨d, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hsat, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hdict, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hd' := lookup_ok hd
  have ha := (hq.declarations.1 f d hd').1
  refine ⟨?_, fnTyCheck_atoms ha.1 ha.2.1 ha.2.2 he.1 he.2, emptyEff_atoms _⟩
  rw [fnTyCheck_eq]
  exact .E_Fun hd' (satAll_sound hq.sat (require_ok hsat).1)
    (by simpa using (require_ok hlen).1) (List.isEmpty_iff.mp (require_ok hdict).1)

theorem primName_case {q b ts es} : CaseSound q (.expr (.primName b ts es)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨sg, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, htlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, helen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hadmit, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hd' := lookup_ok hd
  have ha := hq.builtins b sg hd'
  refine ⟨?_, fnTyCheck_atoms ha.1 ha.2.1 ha.2.2 he.1 he.2, emptyEff_atoms _⟩
  rw [fnTyCheck_eq]
  exact .E_Prim hd' (by simpa using (require_ok htlen).1)
    (by simpa using (require_ok helen).1) (hq.admits b C ts sg hd' (require_ok hadmit).1)

theorem opName_case {q o ts} : CaseSound q (.expr (.opName o ts)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨od, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hsat, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hd' := lookup_ok hd
  have ha := hq.declarations.2.2.1 o od hd'
  refine ⟨?_, fnTyCheck_atoms ha.1 ha.2 (singleEff_atoms _ _) he (by simp), emptyEff_atoms _⟩
  rw [fnTyCheck_eq, singleEff_eq_contains (require_ok heff).1]
  exact .E_Op hd' (satAll_sound hq.sat (require_ok hsat).1)

theorem nullCon_case {q c ts} : CaseSound q (.expr (.nullCon c ts)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hargs, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_NullCon (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (List.isEmpty_iff.mp (require_ok hargs).1), he, emptyEff_atoms _⟩

theorem conValue_case {q c ts ps} : CaseSound q (.expr (.conValue c ts ps)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hps, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hne, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have ha := substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have hp := tysEq_sound he.2 ha (require_ok hps).1
  refine ⟨.E_ConValue (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (by simpa only [substParams_eq] using hp) ((nonemptyList_spec _).mp (require_ok hne).1),
    ⟨he.2, he.1, emptyEff_atoms _⟩, emptyEff_atoms _⟩

theorem funDicts_case {q f ts es ds ps} : CaseSound q (.expr (.funDicts f ts es ds ps)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨d, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hsat, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hne, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, hps, h⟩ := checking_lift_bind_ok h
  obtain ⟨u5, hds, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hd' := lookup_ok hd
  have ha := hq.declarations.1 f d hd'
  have hp := substParams_atoms he.1 he.2.1 ha.1.1
  have hpEq := tysEq_sound he.2.2.2 hp (require_ok hps).1
  have hda := substParams_atoms (es := []) he.1 (by simp) ha.2
  have hh := dicts_sound q ds _ _ _ 0 _ hq he.2.2.1 hΓ hda (by cases u5; exact hds)
  refine ⟨?_, fnTyCheck_atoms ha.1.1 ha.1.2.1 ha.1.2.2 he.1 he.2.1, emptyEff_atoms _⟩
  rw [fnTyCheck_eq]
  exact .E_FunDicts hd' (satAll_sound hq.sat (require_ok hsat).1)
    (by simpa using (require_ok hlen).1) ((nonemptyList_spec _).mp (require_ok hne).1)
    (by simpa only [substParams_eq] using hpEq) (by simpa only [substParams_eq] using hh)

theorem methName_case {q d m ts es ds ps} : CaseSound q (.expr (.methName d m ts es ds ps)) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨dt, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨cl, τ⟩, hv, h⟩ := checking_lift_bind_ok h
  obtain ⟨cd, hc, h⟩ := checking_lift_bind_ok h
  obtain ⟨ms, hm, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hsat, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hds, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, hps, h⟩ := checking_lift_bind_ok h
  obtain ⟨u5, hhead, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hdt := dict_sound q d _ _ _ _ hq he.1 hΓ hd
  have eqt := dictView_ok hv
  subst dt
  have ha := hq.declarations.2.2.2.1 cl cd m ms (lookup_ok hc) (lookup_ok hm)
  have hts := tysAtoms_append he.2.1 (show Tys.AtomsIn q.atoms [τ] from ⟨hdt.2, trivial⟩)
  have hp := substParams_atoms hts he.2.2.1 ha.1
  have hh := dicts_sound q ds _ _ _ 0 _ hq he.2.2.2.1 hΓ (tysAtoms_take hp _) (by cases u3; exact hds)
  refine ⟨?_, ⟨he.2.2.2.2, substTy_atoms ha.2.1 hts he.2.2.1,
    substRho_atoms ha.2.2 he.2.2.1⟩, emptyEff_atoms _⟩
  rw [substTy_eq]
  exact .E_MethName hdt.1 (lookup_ok hc) (lookup_ok hm)
    (satAll_sound hq.sat (require_ok hsat).1) (by simpa using (require_ok hlen).1)
    (by simpa only [substParams_eq] using hh)
    (by simpa only [substParams_eq] using tysEq_sound he.2.2.2.2 (tysAtoms_drop hp _) (require_ok hps).1)
    ((headNotDict_spec _).mp (require_ok hhead).1)


theorem not_case {q e} : CaseSound q (.expr (.not e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he hΓ hR hc) (by trivial) h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_Not ht, trivial, hae⟩

theorem and_case {q lhs rhs} : CaseSound q (.expr (.and lhs rhs)) := by
  intro ih
  have ihl : ExprSound q lhs := ih (.expr lhs) (by simp [CheckNode.size] <;> omega)
  have ihr : ExprSound q rhs := ih (.expr rhs) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εl, mid, hl, hal, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihl _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc) (by trivial) h
  obtain ⟨εr, mid', hr, har, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihr _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc) (by trivial) h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq hal har]
  exact ⟨.E_And hl hr, trivial, CheckTools.union_atoms hal har⟩

theorem or_case {q lhs rhs} : CaseSound q (.expr (.or lhs rhs)) := by
  intro ih
  have ihl : ExprSound q lhs := ih (.expr lhs) (by simp [CheckNode.size] <;> omega)
  have ihr : ExprSound q rhs := ih (.expr rhs) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨εl, mid, hl, hal, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihl _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc) (by trivial) h
  obtain ⟨εr, mid', hr, har, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihr _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc) (by trivial) h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq hal har]
  exact ⟨.E_Or hl hr, trivial, CheckTools.union_atoms hal har⟩

theorem neg_case {q t e} : CaseSound q (.expr (.neg t e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨b, ts⟩, hop, h⟩ := checking_lift_bind_ok h
  obtain ⟨u0, hnil, h⟩ := checking_lift_bind_ok h
  obtain ⟨sg, hsig, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, heffs, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hadmit, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, hfn, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc) he.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hop' := lookup_ok hop
  have hsig' := lookup_ok hsig
  have ha := hq.builtins b sg hsig'
  have hts := hq.operators.atoms he.1 hop'
  have htarget : Ty.AtomsIn q.atoms (.fn [t] t emptyEff) :=
    ⟨⟨he.1, trivial⟩, he.1, emptyEff_atoms _⟩
  have hfnEq := tyEq_sound (fnTyCheck_atoms ha.1 ha.2.1 ha.2.2 hts (by simp)) htarget (require_ok hfn).1
  refine ⟨.E_Neg hop' (List.isEmpty_iff.mp (require_ok hnil).1) hsig'
    (by simpa using (require_ok hlen).1) (by simpa using (require_ok heffs).1)
    (hq.admits b C ts sg hsig' (require_ok hadmit).1)
    (by simpa only [fnTyCheck_eq, emptyEff] using hfnEq) ht, he.1, hae⟩

theorem binary_case {q o t lhs rhs} : CaseSound q (.expr (.binary o t lhs rhs)) := by
  intro ih
  have ihl : ExprSound q lhs := ih (.expr lhs) (by simp [CheckNode.size] <;> omega)
  have ihr : ExprSound q rhs := ih (.expr rhs) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨b, ts⟩, hop, h⟩ := checking_lift_bind_ok h
  obtain ⟨sg, hsig, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, heffs, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hadmit, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨ps, r, εop⟩, hv, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, hps, h⟩ := checking_lift_bind_ok h
  obtain ⟨u5, hpure, h⟩ := checking_lift_bind_ok h
  obtain ⟨εl, mid, hl, hal, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihl _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hc) he.1 h
  obtain ⟨εr, mid', hr, har, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihr _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR hc) he.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hop' := lookup_ok hop
  have hsig' := lookup_ok hsig
  have ha := hq.builtins b sg hsig'
  have hts := hq.operators.atoms he.1 hop'
  have hf := fnView_ok hv
  have haf := fnTyCheck_atoms (es := []) ha.1 ha.2.1 ha.2.2 hts (by simp)
  rw [hf] at haf
  have hpsEq := tysEq_sound haf.1 (show Tys.AtomsIn q.atoms [t, t] from ⟨he.1, he.1, trivial⟩) (require_ok hps).1
  have hεEq := eff_eq_empty_of_sub (acceptEff_sound haf.2.2 hpure)
  rw [union_eq hal har]
  refine ⟨.E_Binary hop' (hq.operators _ _ _ _ hop') hsig'
    (by simpa using (require_ok hlen).1) (by simpa using (require_ok heffs).1)
    (hq.admits b C ts sg hsig' (require_ok hadmit).1) ?_ hl hr,
    haf.2.1, CheckTools.union_atoms hal har⟩
  simpa only [fnTyCheck_eq, hpsEq, hεEq] using hf

end Benitoite.Surface.Check
