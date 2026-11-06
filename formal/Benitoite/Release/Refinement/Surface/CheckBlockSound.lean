import Benitoite.Release.Refinement.Surface.CheckSoundBase

/-! ブロックの全規則について、小さい案内の健全性から元の型付けを得る。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckCompare

private theorem builder_extend {s Δ k} (h : BuilderSupport s Δ) (hk : k.contents.Support (· ∈ s)) :
    BuilderSupport s (LocalCtx.extend (some k) Δ) := by
  intro i kind hi
  cases i with
  | zero =>
    simp only [LocalCtx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    subst kind
    exact hk
  | succ i =>
    simp only [LocalCtx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hd : Δ[i]? with
    | none => simp [hd] at hi
    | some x => cases x with
      | none => simp [hd] at hi
      | some old =>
        simp only [hd, Option.map_some, Option.some.injEq] at hi
        subst kind
        have ho := h i old hd
        cases old <;> try trivial
        case list a =>
          change (renameTy (shiftIndex 1 0) a).Support (· ∈ s)
          rw [← Ty.shiftV_eq_renameTy]
          exact type_shift_support ho 1 0

private theorem kind_shift_support {s : List Atom} {k : BuilderKind} (hk : k.contents.Support (· ∈ s)) :
    (renameKind (shiftIndex 1 0) k).contents.Support (· ∈ s) := by
  cases k <;> try trivial
  case list a =>
    change (renameTy (shiftIndex 1 0) a).Support (· ∈ s)
    rw [← Ty.shiftV_eq_renameTy]
    exact type_shift_support hk 1 0

theorem checkBlockAt_step (g : Guide) (ih : SoundBelow g) : BlockSoundAt g := by
  intro q rows Δ C Γ Φ R p path body a ε hq hΔ hΓ hR hb ha he hg h
  unfold checkBlockAt at h
  have hc := (Bool.and_eq_true_iff.mp h).2
  split at hc
  · rename_i kind rest hints gr
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    exact .B_BuilderBind (annotation_sound hq hΓ hb.1 hc.1)
      (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.1)
      ((ih gr (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block hq
        (builder_extend hΔ (kind_shift_support hb.1)) (CtxSupport.extendNone hΓ) (hR.shift 1) hb.2
        (type_shift_support ha 1 0) (effect_shift_support he 1 0) hg.2.1 hc.2.2.1)
      (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2.2)
  · have hh := resultEq_sound (by trivial) (empty_effect_support _) ha he hc
    rw [← hh.1, ← hh.2]
    exact .B_Empty
  · rename_i e hints ge
    exact .B_Last ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
      hq hΔ hΓ hR hb ha he hg.2.1 hc)
  · rename_i k t e hints ge
    have hh := Bool.and_eq_true_iff.mp hc
    have ha' := (rawTyEq_spec (a := Ty.base .unit) (by trivial) ha).mp hh.1
    rw [← ha']
    exact .B_LastBind ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
      hq hΔ hΓ hR hb.2 hb.1 he hg.2.1 hh.2)
  · rename_i e hints ge
    have hh := Bool.and_eq_true_iff.mp hc
    have ha' := (rawTyEq_spec (a := Ty.base .unit) (by trivial) ha).mp hh.1
    rw [← ha']
    exact .B_LastDiscard ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
      hq hΔ hΓ hR hb (hg.1.ty 0) he hg.2.1 hh.2)
  · rename_i k t e rest hints ge gr
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    exact .B_Bind
      ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
        hq hΔ hΓ hR hb.2.1 hb.1 he hg.2.1 hc.1)
      ((ih gr (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
        hq (hΔ.localExtend 1) (hΓ.extend hb.1) (hR.shift 1) hb.2.2
        (type_shift_support ha 1 0) (effect_shift_support he 1 0) hg.2.2.1 hc.2.1)
      (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2)
  · rename_i e rest hints ge gr
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    exact .B_Discard
      ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
        hq hΔ hΓ hR hb.1 (hg.1.ty 0) he hg.2.1 hc.1)
      ((ih gr (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
        hq hΔ hΓ hR hb.2 ha he hg.2.2.1 hc.2.1)
      (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2)
  · rename_i e rest hints ge gr
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    exact .B_Seq
      ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
        hq hΔ hΓ hR hb.1 (by trivial) he hg.2.1 hc.1)
      hc.2.1
      ((ih gr (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
        hq hΔ hΓ hR hb.2 ha he hg.2.2.1 hc.2.2.1)
      (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2.2)
  · rename_i k pat t e hints ge
    split at hc
    · rename_i δ hδ
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have ha' := (rawTyEq_spec (a := Ty.base .unit) (by trivial) ha).mp hc.1
      rw [← ha']
      exact .B_LastPat hc.2.1.1 hc.2.1.2.1
        (CheckPatterns.surfacePatTy_sound hq.formation hb.1 hδ)
        (CheckPatterns.exhaustiveWithView_view hq.formation.ctors hc.2.2.1)
        (annotation_sound hq hΓ hb.1 hc.2.2.2.1) hc.2.1.2.2
        ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
          hq hΔ hΓ hR hb.2 hb.1 he hg.2.1 hc.2.2.2.2)
    · cases hc
  · rename_i k pat t e rest hints ge gr
    split at hc
    · rename_i δ hδ
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hδs := CheckPatterns.surfacePatTy_support hq.formation hb.1 hδ
      exact .B_BindPat hc.1.1 hc.1.2.1
        (CheckPatterns.surfacePatTy_sound hq.formation hb.1 hδ)
        (CheckPatterns.exhaustiveWithView_view hq.formation.ctors hc.2.1)
        (annotation_sound hq hΓ hb.1 hc.2.2.1) hc.1.2.2
        ((ih ge (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).expr
          hq hΔ hΓ hR hb.2.1 hb.1 he hg.2.1 hc.2.2.2.1)
        ((ih gr (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
          hq (hΔ.localExtend δ.length) (CtxSupport.bind hΓ hδs) (hR.shift δ.length) hb.2.2
          (type_shift_support ha _ _) (effect_shift_support he _ _) hg.2.2.1 hc.2.2.2.2.1)
        (annotation_sound hq hΓ ha hc.2.2.2.2.2)
    · cases hc
  · rename_i body hints gb
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    exact .B_Sub
      ((ih gb (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
        hq hΔ hΓ hR hb (hg.1.ty 0) (hg.1.eff 0) hg.2.1 hc.1)
      (subtype_sound (hg.1.ty 0) ha hg.1 hc.2.1)
      (CheckCompare.effCovers_sound (hg.1.eff 0) ((Eff.support_iff ε).mp he).2 hc.2.2.1)
      (annotation_sound hq hΓ ha hc.2.2.2)
  · cases hc

end Benitoite.Release.Refinement.Surface.Check
