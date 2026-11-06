import Benitoite.Release.Refinement.Surface.CheckSoundSupport

/-! 演算子とリストの検査を、元の文脈と束縛した引数の判断へ接続する。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckCompare CheckFormation CheckArguments

private theorem operator_args_support {s : List Atom} {op : Operator} {t : Ty}
    (ht : t.Support (· ∈ s)) : Ty.SupportList (· ∈ s) (op.typeArgs t) := by
  cases op with
  | neg => trivial
  | binary o => cases o <;> first | exact ⟨ht, trivial⟩ | trivial

private theorem types_append_support {s : List Atom} {ps qs : List Ty}
    (hp : Ty.SupportList (· ∈ s) ps) (hq : Ty.SupportList (· ∈ s) qs) :
    Ty.SupportList (· ∈ s) (ps ++ qs) := by
  induction ps with
  | nil => exact hq
  | cons p ps ih => exact ⟨hp.1, ih hp.2⟩

private theorem renamed_boundVars_support (s : List Atom) (n : Nat) (ξ : Nat → Nat) :
    ValuesSupport s (Val.renameList ξ (boundVars n)) := by
  have hm : ∀ ns : List Nat, ValuesSupport s (Val.renameList ξ (ns.map Val.var)) := by
    intro ns
    induction ns with
    | nil => trivial
    | cons i ns ih => exact ⟨trivial, ih⟩
  exact hm _

theorem binary_step {h cs} (ih : SoundBelow (.node .E_Binary h cs)) : ExprSoundAt (.node .E_Binary h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i o t lhs rhs gl gr
    split at hc
    · rename_i b ts hop
      split at hc
      · rename_i sg ds hhead
        simp only [allChecks, Bool.and_eq_true, and_true] at hc
        have hts := hq.operators _ _ _ _ hop hs.1
        have hd := head_sound hq hΓ (primitive_empty_support hq.tables hts) hg.1 hhead
        have hds : ds = [] := hd.2.2
        have hh : CallHeadTy q.D q.B (CheckAdmissible.NoFailCtxOf rows) C Γ (.primName b ts [] []) sg [] := by
          simpa only [hds] using hd.1
        have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [t,t] from ⟨hs.1,hs.1,trivial⟩)
        exact .E_Binary hc.1 hop (tysEq_sound hts (operator_args_support hs.1) hc.2.1) hh
          ((ih gl (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
            hq hΔ hΓ hR hs.2.1 hs.1 he hg.2.1 hc.2.2.2.1)
          ((ih gr (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
            hq hΔ hΓ hR hs.2.2 hs.1 he hg.2.2.1 hc.2.2.2.2.1)
          (valsTel_sound hq hΓ hΓ' (by exact ⟨trivial,trivial,trivial⟩) (tel_shift_support hd.2.1 _ _)
            (hg.1.ty 0) (hg.1.eff 0) hg.1 hc.2.2.2.2.2.1)
          (subtype_sound (hg.1.ty 0) (type_shift_support ha _ _) hg.1 hc.2.2.2.2.2.2.1)
          (covers_sound (hg.1.eff 0) ((Eff.support_iff _).mp (effect_shift_support he 2 0)).2 hc.2.2.2.2.2.2.2.1)
          (annotation_sound hq hΓ ha hc.2.2.2.2.2.2.2.2)
      · cases hc
    · cases hc
  · cases hc

theorem neg_step {h cs} (ih : SoundBelow (.node .E_Neg h cs)) : ExprSoundAt (.node .E_Neg h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i t e ge
    split at hc
    · rename_i b ts hop
      split at hc
      · rename_i sg ds hhead
        simp only [allChecks, Bool.and_eq_true, and_true] at hc
        have hts := hq.operators _ _ _ _ hop hs.1
        have hd := head_sound hq hΓ (primitive_empty_support hq.tables hts) hg.1 hhead
        have hds : ds = [] := hd.2.2
        have hh : CallHeadTy q.D q.B (CheckAdmissible.NoFailCtxOf rows) C Γ (.primName b ts [] []) sg [] := by
          simpa only [hds] using hd.1
        have hts0 : ts = [] := by cases ts <;> simp_all
        have hta := (rawTyEq_spec hs.1 ha).mp hc.2.2.2.1
        rw [← hta]
        exact .E_Neg hc.1 hop hts0 hh
          ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
            hq hΔ hΓ hR hs.2 hs.1 he hg.2.1 hc.2.2.2.2.1)
          (valsTel_sound hq hΓ (CtxSupport.bind hΓ ⟨hs.1,trivial⟩) (by exact ⟨trivial,trivial⟩)
            (tel_shift_support hd.2.1 _ _) (hg.1.ty 0) (hg.1.eff 0) hg.1 hc.2.2.2.2.2.1)
          (subtype_sound (hg.1.ty 0) (type_shift_support hs.1 _ _) hg.1 hc.2.2.2.2.2.2.1)
          (covers_sound (hg.1.eff 0) ((Eff.support_iff _).mp (effect_shift_support he 1 0)).2 hc.2.2.2.2.2.2.2.1)
          (annotation_sound hq hΓ hs.1 hc.2.2.2.2.2.2.2.2)
      · cases hc
    · cases hc
  · cases hc

theorem list_step {h cs} (ih : SoundBelow (.node .E_List h cs)) : ExprSoundAt (.node .E_List h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i t es ges
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    have hta := (rawTyEq_spec (a := Ty.list t) hs.1 ha).mp hc.1
    rw [← hta]
    exact .E_List (annotation_sound hq hΓ hs.1 hc.2.1)
      ((ih ges (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).types
        hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.1)
      (valsTys_sound hq hΓ (CtxSupport.bind hΓ (hg.1.tys 0)) (boundVars_support _ _)
        (types_support_replicate (type_shift_support hs.1 _ _) _) hg.1 hc.2.2.2)
  · cases hc

theorem listRefined_step {h cs} (ih : SoundBelow (.node .E_ListRefined h cs)) : ExprSoundAt (.node .E_ListRefined h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i t es ges
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    have hta := (rawTyEq_spec (a := Ty.refined (.list t) (h.pred 0)) hs.1 ha).mp hc.1
    rw [← hta]
    exact .E_ListRefined (annotation_sound hq hΓ hs.1 hc.2.1)
      ((ih ges (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).types
        hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.1)
      (valsTys_sound hq hΓ (CtxSupport.bind hΓ (hg.1.tys 0)) (boundVars_support _ _)
        (types_support_replicate (type_shift_support hs.1 _ _) _) hg.1 hc.2.2.2.1)
      ((h.proof 0).sound hc.2.2.2.2)
  · cases hc

theorem listSpread_step {h cs} (ih : SoundBelow (.node .E_ListSpread h cs)) : ExprSoundAt (.node .E_ListSpread h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i t f before spread after gb gs ga gu
    split at hc
    · rename_i sg ds hhead
      simp only [allChecks, Bool.and_eq_true, and_true] at hc
      have hd := head_sound hq hΓ (source_head_inputs hs.2.1) hg.1 hhead
      have hdict : DictsSupport q.formation.atoms ds := by
        rw [hd.2.2]
        exact source_head_dictionaries hs.2.1
      have htypes := types_append_support (hg.1.tys 0) (show Ty.SupportList (· ∈ q.formation.atoms)
        (h.ty 0 :: h.tys 1) from ⟨hg.1.ty 0,hg.1.tys 1⟩)
      have hta := (rawTyEq_spec (a := Ty.list t) hs.1 ha).mp hc.1
      rw [← hta]
      exact .E_ListSpread hd.1 (annotation_sound hq hΓ hs.1 hc.2.1)
        ((ih gb (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).types
          hq hΔ hΓ hR hs.2.2.1 (hg.1.tys 0) he hg.2.1 hc.2.2.1)
        ((ih gs (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
          hq hΔ hΓ hR hs.2.2.2.1 (hg.1.ty 0) he hg.2.2.1 hc.2.2.2.1)
        ((ih ga (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).types
          hq hΔ hΓ hR hs.2.2.2.2 (hg.1.tys 1) he hg.2.2.2.1 hc.2.2.2.2.1)
        (checkSpreadAt_sound hq hΓ (CtxSupport.bind hΓ htypes) hd.2.1 hdict
          (renamed_boundVars_support _ _ _) trivial (boundVars_support _ _)
          (type_shift_support hs.1 _ _) (effect_shift_support he _ _) hg.2.2.2.2.1 hc.2.2.2.2.2)
    · cases hc
  · cases hc

end Benitoite.Release.Refinement.Surface.Check
