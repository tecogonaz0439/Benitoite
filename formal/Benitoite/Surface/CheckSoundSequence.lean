import Benitoite.Surface.CheckSoundDicts

/-! 引数・要素・穴の並びとブロックの検査の健全性。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem exprs_nil_case {q} : CaseSound q (.exprs .nil) := by
  intro ih
  constructor
  · intro C Γ R path index ts s s' ε hq he hΓ hR hts h
    simp only [Exprs.AtomsIn] at he
    cases ts with
    | nil =>
        obtain ⟨rfl, _⟩ := checking_pure_ok h
        exact ⟨.nil, emptyEff_atoms _⟩
    | cons t ts => contradiction
  · intro C Γ R path index a s s' ε hq he hΓ hR ha h
    simp only [Exprs.AtomsIn] at he
    obtain ⟨rfl, _⟩ := checking_pure_ok h
    exact ⟨.nil, emptyEff_atoms _⟩

theorem exprs_cons_case {q e es} : CaseSound q (.exprs (.cons e es)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihes : ExprsSound q es := ih (.exprs es) (by simp [CheckNode.size] <;> omega)
  constructor
  · intro C Γ R path index ts s s' ε hq he hΓ hR hts h
    simp only [Exprs.AtomsIn] at he
    cases ts with
    | nil => contradiction
    | cons a as =>
        obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
          (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc) hts.1 h
        obtain ⟨εs, mid', hs, h⟩ := checking_bind_ok h
        have htail := ihes.1 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hts.2 hs
        obtain ⟨eq, _⟩ := checking_pure_ok h
        cases eq
        rw [union_eq hae htail.2]
        exact ⟨.cons ht htail.1, CheckTools.union_atoms hae htail.2⟩
  · intro C Γ R path index a s s' ε hq he hΓ hR ha h
    simp only [Exprs.AtomsIn] at he
    obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
      (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc) ha h
    obtain ⟨εs, mid', hs, h⟩ := checking_bind_ok h
    have htail := ihes.2 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR ha hs
    obtain ⟨eq, _⟩ := checking_pure_ok h
    cases eq
    rw [union_eq hae htail.2]
    exact ⟨.cons ht htail.1, CheckTools.union_atoms hae htail.2⟩

theorem holes_nil_case {q} : CaseSound q (.holes .nil) := by
  intro ih C Γ R path index ts s s' ε hq he hΓ hR hts h
  simp only [HoleArgs.AtomsIn] at he
  cases ts with
  | nil =>
      obtain ⟨rfl, _⟩ := checking_pure_ok h
      exact ⟨.nil, emptyEff_atoms _⟩
  | cons t ts => contradiction

theorem holes_expr_case {q e args} : CaseSound q (.holes (.expr e args)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihargs : HoleArgsSound q args := ih (.holes args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R path index ts s s' ε hq he hΓ hR hts h
  simp only [HoleArgs.AtomsIn] at he
  cases ts with
  | nil => contradiction
  | cons a as =>
      obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
        (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc) hts.1 h
      obtain ⟨εs, mid', hs, h⟩ := checking_bind_ok h
      have htail := ihargs _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hts.2 hs
      obtain ⟨eq, _⟩ := checking_pure_ok h
      cases eq
      rw [union_eq hae htail.2]
      exact ⟨.expr ht htail.1, CheckTools.union_atoms hae htail.2⟩

theorem holes_hole_case {q t args} : CaseSound q (.holes (.hole t args)) := by
  intro ih
  have ihargs : HoleArgsSound q args := ih (.holes args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R path index ts s s' ε hq he hΓ hR hts h
  simp only [HoleArgs.AtomsIn] at he
  cases ts with
  | nil => contradiction
  | cons a as =>
      obtain ⟨u, hu, h⟩ := checking_lift_bind_ok h
      have htail := ihargs _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hts.2 h
      exact ⟨.hole (tyLe_sound he.1 hts.1 (require_ok hu).1) htail.1, htail.2⟩

theorem block_empty_case {q} : CaseSound q (.block .empty) := by
  intro ih C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.B_Empty, trivial, emptyEff_atoms _⟩

theorem block_last_case {q e} : CaseSound q (.block (.last e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  have ht := ihe _ _ _ _ _ _ _ _ _ hq he hΓ hR h
  exact ⟨.B_Last ht.1, ht.2⟩

theorem block_lastBind_case {q k t e} : CaseSound q (.block (.lastBind k t e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc) he.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.B_LastBind ht, trivial, hae⟩

theorem block_lastDiscard_case {q e} : CaseSound q (.block (.lastDiscard e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨⟨t, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have ht := ihe _ _ _ _ _ _ _ _ _ hq he hΓ hR hc
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.B_LastDiscard ht.1, trivial, ht.2.2⟩

theorem block_bind_case {q k t e rest} : CaseSound q (.block (.bind k t e rest)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihr : BlockSound q rest := ih (.block rest) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hc) he.1 h
  obtain ⟨⟨b, εs⟩, mid', hs, h⟩ := checking_bind_ok h
  have htail := ihr _ _ _ _ _ _ _ _ _ hq he.2.2 (Env.atoms_cons hΓ he.1) hR hs
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq hae htail.2.2]
  exact ⟨.B_Bind ht htail.1, htail.2.1, CheckTools.union_atoms hae htail.2.2⟩

theorem block_discard_case {q e rest} : CaseSound q (.block (.discard e rest)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihr : BlockSound q rest := ih (.block rest) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨⟨t, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have ht := ihe _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc
  obtain ⟨⟨b, εs⟩, mid', hs, h⟩ := checking_bind_ok h
  have htail := ihr _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hs
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq ht.2.2 htail.2.2]
  exact ⟨.B_Discard ht.1 htail.1, htail.2.1, CheckTools.union_atoms ht.2.2 htail.2.2⟩

theorem block_seq_case {q e rest} : CaseSound q (.block (.seq e rest)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihr : BlockSound q rest := ih (.block rest) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hc) (by trivial) h
  obtain ⟨u, hu, h⟩ := checking_lift_bind_ok h
  have hn : ¬ e.Exits := by
    intro hx
    have hh := (exprExits_spec e).mpr hx
    simpa [hh] using (require_ok hu).1
  obtain ⟨⟨b, εs⟩, mid', hs, h⟩ := checking_bind_ok h
  have htail := ihr _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hs
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq hae htail.2.2]
  exact ⟨.B_Seq ht hn htail.1, htail.2.1, CheckTools.union_atoms hae htail.2.2⟩

theorem block_lastPat_case {q k pat t e} : CaseSound q (.block (.lastPat k pat t e)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
  obtain ⟨δ, hpat, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hexh, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hc) he.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hv := Bool.and_eq_true_iff.mp (require_ok hvalid).1
  exact ⟨.B_LastPat ((nontrivial_spec _).mp hv.1) ((patternValid_spec _).mp hv.2)
    (surfacePatTy_sound (lookup_ok hpat)) (bindingExhaustive_sound hq.constructors (require_ok hexh).1)
    ht, trivial, hae⟩

theorem block_bindPat_case {q k pat t e rest} : CaseSound q (.block (.bindPat k pat t e rest)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have ihr : BlockSound q rest := ih (.block rest) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Block.AtomsIn] at he
  obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
  obtain ⟨δ, hpat, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hexh, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, ht, hae, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihe _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hc) he.1 h
  obtain ⟨⟨b, εs⟩, mid', hs, h⟩ := checking_bind_ok h
  have hδ := surfacePatTy_atoms hq.declarations he.1 (lookup_ok hpat)
  have htail := ihr _ _ _ _ _ _ _ _ _ hq he.2.2
    (Env.atoms_append (Env.atoms_binds hδ) hΓ) hR hs
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq hae htail.2.2]
  have hv := Bool.and_eq_true_iff.mp (require_ok hvalid).1
  exact ⟨.B_BindPat ((nontrivial_spec _).mp hv.1) ((patternValid_spec _).mp hv.2)
    (surfacePatTy_sound (lookup_ok hpat)) (bindingExhaustive_sound hq.constructors (require_ok hexh).1)
    ht htail.1, htail.2.1, CheckTools.union_atoms hae htail.2.2⟩

end Benitoite.Surface.Check
