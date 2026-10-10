import Benitoite.Surface.CheckSoundBasicExpr
import Benitoite.Surface.CheckSoundSequence

/-! コレクション・レコード・分岐の検査の健全性。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

/-- 補間の型注釈から、入力と変換関数の期待型の原子集合を得る。 -/
theorem interpolation_types_atoms {atoms parts} (h : InterpParts.AtomsIn atoms parts) :
    Tys.AtomsIn atoms (InterpPart.exprTypes parts) ∧
      Tys.AtomsIn atoms (InterpPart.converterTypes parts) := by
  induction parts with
  | nil => exact ⟨trivial, trivial⟩
  | cons part parts ih =>
      have tail := ih (fun t ht => h t (List.mem_cons_of_mem _ ht))
      cases part with
      | text s => exact tail
      | stringExpr => exact ⟨⟨trivial, tail.1⟩, tail.2⟩
      | converted t =>
          have ht := h t (List.mem_cons_self ..)
          exact ⟨⟨ht, tail.1⟩, ⟨⟨⟨ht, trivial⟩, trivial, emptyEff_atoms _⟩, tail.2⟩⟩

theorem list_case {q t es} : CaseSound q (.expr (.list t es)) := by
  intro ih
  have ihes : ExprsSound q es := ih (.exprs es) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u, hwf, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, hc, h⟩ := checking_bind_ok h
  have ht := ihes.2 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR he.1 hc
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.E_List ((wfTy_spec _ _).mp (require_ok hwf).1) ht.1, he.1, ht.2⟩

theorem listSpread_case {q t f before spread after} :
    CaseSound q (.expr (.listSpread t f before spread after)) := by
  intro ih
  have ihf : ExprSound q f := ih (.expr f) (by simp [CheckNode.size] <;> omega)
  have ihb : ExprsSound q before := ih (.exprs before) (by simp [CheckNode.size] <;> omega)
  have ihs : ExprSound q spread := ih (.expr spread) (by simp [CheckNode.size] <;> omega)
  have iha : ExprsSound q after := ih (.exprs after) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hwf, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hdirect, h⟩ := checking_lift_bind_ok h
  have hft : Ty.AtomsIn q.atoms (.fn [.list t, .list t] (.list t) emptyEff) :=
    ⟨⟨he.1, he.1, trivial⟩, he.1, emptyEff_atoms _⟩
  obtain ⟨εf, mid, hf, haf, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihf _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hc) hft h
  obtain ⟨u3, hpure, h⟩ := checking_lift_bind_ok h
  have hfp := HasType.E_Sub hf (Or.inl rfl) (acceptEff_sound haf hpure)
  obtain ⟨εb, mid', hb, h⟩ := checking_bind_ok h
  have hbefore := ihb.2 _ _ _ _ _ _ _ _ _ hq he.2.2.1 hΓ hR he.1 hb
  obtain ⟨εs, mid'', hs, has, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihs _ _ _ _ _ _ _ _ _ hq he.2.2.2.1 hΓ hR hc)
    (show Ty.AtomsIn q.atoms (.list t) from he.1) h
  obtain ⟨εa, mid''', ha, h⟩ := checking_bind_ok h
  have hafter := iha.2 _ _ _ _ _ _ _ _ _ hq he.2.2.2.2 hΓ hR he.1 ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  obtain ⟨callee, hcallee⟩ := (isDirect_spec _).mp (require_ok hdirect).1
  rw [union_eq has hafter.2, union_eq hbefore.2 (CheckTools.union_atoms has hafter.2)]
  exact ⟨.E_ListSpread ((wfTy_spec _ _).mp (require_ok hwf).1) hcallee hfp
    hbefore.1 hs hafter.1, he.1, CheckTools.union_atoms hbefore.2 (CheckTools.union_atoms has hafter.2)⟩

theorem interpolation_case {q parts es fs} : CaseSound q (.expr (.interpolation parts es fs)) := by
  intro ih
  have ihes : ExprsSound q es := ih (.exprs es) (by simp [CheckNode.size] <;> omega)
  have ihfs : ExprsSound q fs := ih (.exprs fs) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hallowed, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, hes, h⟩ := checking_bind_ok h
  obtain ⟨εf, mid', hfs, h⟩ := checking_bind_ok h
  obtain ⟨u2, hpure, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hdirect, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, hadd, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have htypes := interpolation_types_atoms he.1
  have heTyped := ihes.1 _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR htypes.1 hes
  have hfTyped := ihfs.1 _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR htypes.2 hfs
  have eqε := eff_eq_empty_of_sub (acceptEff_sound hfTyped.2 hpure)
  rw [eqε] at hfTyped
  refine ⟨.E_Interpolation ((interpAllowed_spec _).mp (require_ok hallowed).1)
    heTyped.1 hfTyped.1 ((allDirect_spec _).mp (require_ok hdirect).1) ?_, trivial, heTyped.2⟩
  intro hcount
  have hh := (require_ok hadd).1
  have hn : ¬ InterpPart.count parts < 2 := by omega
  have hs : stringAddOk q.atoms q.B q.opPrim q.admitsDec C = true := by simpa [hn] using hh
  exact stringAddOk_sound hq.admits hq.builtins hs

theorem record_case {q c ts positions args} : CaseSound q (.expr (.record c ts positions args)) := by
  intro ih
  have ihargs : ExprsSound q args := ih (.exprs args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hperm, h⟩ := checking_lift_bind_ok h
  obtain ⟨εe, mid, hc, h⟩ := checking_bind_ok h
  have hparams := substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have ht := ihargs.1 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR (fieldTypes_atoms hparams) hc
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.E_Record (lookup_ok hd) (by simpa using (require_ok hlen).1)
    ((natPerm_spec _ _).mp (require_ok hperm).1) ?_, he.1, ht.2⟩
  simpa only [fieldTypes, substParams_eq] using ht.1

theorem recordUpdate_case {q c ts n positions base args} :
    CaseSound q (.expr (.recordUpdate c ts n positions base args)) := by
  intro ih
  have ihb : ExprSound q base := ih (.expr base) (by simp [CheckNode.size] <;> omega)
  have ihargs : ExprsSound q args := ih (.exprs args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hn, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hne, h⟩ := checking_lift_bind_ok h
  obtain ⟨u4, hnodup, h⟩ := checking_lift_bind_ok h
  obtain ⟨u5, hrange, h⟩ := checking_lift_bind_ok h
  obtain ⟨εb, mid, hb, hab, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ hc => ihb _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hc)
    (show Ty.AtomsIn q.atoms (.data cd.data ts) from he.1) h
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  obtain ⟨u6, hexh, h⟩ := checking_lift_bind_ok h
  have hparams := substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have ht := ihargs.1 _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR (fieldTypes_atoms hparams) ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq hab ht.2]
  refine ⟨.E_RecordUpdate (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (by simpa using (require_ok hn).1) ((nonemptyList_spec _).mp (require_ok hne).1)
    ((natNodup_spec _).mp (require_ok hnodup).1) ((positionsInRange_spec _ _).mp (require_ok hrange).1)
    hb ?_ (recordUpdateExhaustive_sound hq.constructors (require_ok hexh).1),
    he.1, CheckTools.union_atoms hab ht.2⟩
  simpa only [fieldTypes, substParams_eq] using ht.1

theorem arms_nil_case {q} : CaseSound q (.arms .nil) := by
  intro ih C Γ R p path a b s s' ε hq he hΓ hR ha hb h
  obtain ⟨u, hwf, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  exact ⟨.nil ((wfTy_spec _ _).mp (require_ok hwf).1), emptyEff_atoms _⟩

theorem arms_cons_case {q alts guard body rest} :
    CaseSound q (.arms (.cons alts guard body rest)) := by
  intro ih
  obtain ⟨ihg, ihb, ihr⟩ := arms_case_ih ih
  intro C Γ R p path a b s s' ε hq he hΓ hR ha hb h
  simp only [Arms.AtomsIn] at he
  cases guard with
  | none =>
      simp only [checkArmsR] at h
      obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
      obtain ⟨δ, halts, h⟩ := checking_lift_bind_ok h
      have hδ := altsTy_atoms (Declarations.atoms_con hq.declarations) ha (lookup_ok halts)
      have henv := Env.atoms_append (Env.atoms_binds hδ) hΓ
      have hvalid' := (alternativesValid_spec _).mp (require_ok hvalid).1
      have halts' := altsTy_sound (Declarations.atoms_con hq.declarations) ha (lookup_ok halts)
      obtain ⟨εb, mid, ht, hab, h⟩ := checking_accept_block_ok
        (fun _ _ _ _ hc => ihb _ _ _ _ _ _ _ _ _ hq he.2.1 henv hR hc) hb h
      obtain ⟨εs, mid', hs, h⟩ := checking_bind_ok h
      have htail := ihr _ _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR ha hb hs
      obtain ⟨eq, _⟩ := checking_pure_ok h
      cases eq
      rw [union_eq hab htail.2]
      exact ⟨.plain hvalid' halts' ht htail.1, CheckTools.union_atoms hab htail.2⟩
  | some g =>
      simp only [checkArmsR] at h
      obtain ⟨u1, hvalid, h⟩ := checking_lift_bind_ok h
      obtain ⟨δ, halts, h⟩ := checking_lift_bind_ok h
      have hδ := altsTy_atoms (Declarations.atoms_con hq.declarations) ha (lookup_ok halts)
      have henv := Env.atoms_append (Env.atoms_binds hδ) hΓ
      have hvalid' := (alternativesValid_spec _).mp (require_ok hvalid).1
      have halts' := altsTy_sound (Declarations.atoms_con hq.declarations) ha (lookup_ok halts)
      obtain ⟨εg, midg, hg, hag, h⟩ := checking_accept_expr_ok
        (fun _ _ _ _ hc => ihg g rfl _ _ _ _ _ _ _ _ _ hq (he.1 g rfl)
          (Env.atoms_hideConts henv) (show ReturnAtoms q.atoms none from by intro t ht; contradiction) hc)
        (show Ty.AtomsIn q.atoms (.base .boolean) from trivial) h
      obtain ⟨u2, hpure', h⟩ := checking_lift_bind_ok h
      have hgTyped := HasType.E_Sub hg (Or.inl rfl) (acceptEff_sound hag hpure')
      obtain ⟨εb, midb, ht, hab, h⟩ := checking_accept_block_ok
        (fun _ _ _ _ hc => ihb _ _ _ _ _ _ _ _ _ hq he.2.1 henv hR hc) hb h
      obtain ⟨εs, mid', hs, h⟩ := checking_bind_ok h
      have htail := ihr _ _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR ha hb hs
      obtain ⟨eq, _⟩ := checking_pure_ok h
      cases eq
      rw [union_eq hab htail.2]
      exact ⟨.guarded hvalid' halts' hgTyped ht htail.1, CheckTools.union_atoms hab htail.2⟩

theorem match_case {q b e arms} : CaseSound q (.expr (.matchE b e arms)) := by
  intro ih
  have ihe : ExprSound q e := ih (.expr e) (by simp [CheckNode.size] <;> omega)
  have iha : ArmsSound q arms := ih (.arms arms) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hne, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨t, εe⟩, mid, hc, h⟩ := checking_bind_ok h
  have ht := ihe _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hc
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  obtain ⟨u2, hexh, h⟩ := checking_lift_bind_ok h
  have har := iha _ _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR ht.2.1 he.1 ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  rw [union_eq ht.2.2 har.2]
  exact ⟨.E_Match ((nonemptyArms_spec _).mp (require_ok hne).1) ht.1 har.1
    (matchExhaustive_sound hq.constructors (require_ok hexh).1), he.1, CheckTools.union_atoms ht.2.2 har.2⟩

end Benitoite.Surface.Check
