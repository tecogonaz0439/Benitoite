import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.CheckPatterns

/-! 成功と失敗の二つの構成子のパターンと、その網羅性の有限検査。 -/
namespace Benitoite.Release.Refinement.Surface.CheckTry
open CheckCompare

/-- Result の二つの腕から、それぞれの束縛型を得る。 -/
def resultParts (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat)
    (ok err : ConName) (t et : Ty) : Option (DataName × Ty × Ty) := do
  let cd ← q.D.cons err
  let a := Ty.data cd.data [t, et]
  match CheckPatterns.patTy q.formation q.D.core (.con ok [.var]) a,
      CheckPatterns.patTy q.formation q.D.core (.con err [.var]) a with
  | some [t1], some [e1] =>
      if CheckFormation.annotation q.formation q.D.core C Γ path a &&
        (decide (Ordinary t1) && (normTyEq q.formation.atoms t1 t &&
          CheckPatterns.exhaustiveWithView q.D q.formation.ctors closedView a [.con ok [.var], .con err [.var]]))
      then some (cd.data, t1, e1) else none
  | _, _ => none

structure ResultPartsChecked (q : Check.Input) (C : TypeCtx) (Γ : Ctx)
    (ok err d : String) (t et t1 e1 : Ty) : Prop where
  constructor : ∃ cd, q.D.cons err = some cd ∧ cd.data = d
  annotation : Ty.Annotation q.D.core C Γ (.data d [t, et])
  ordinarySuccess : Ordinary t1
  successPattern : PatTy q.D.core (.con ok [.var]) (.data d [t, et]) [t1]
  sameSuccess : t1.norm = t.norm
  failurePattern : PatTy q.D.core (.con err [.var]) (.data d [t, et]) [e1]
  exhaustive : Exhaustive q.D.core (.data d [t, et]) [.con ok [.var], .con err [.var]]
  successSupport : t1.Support (· ∈ q.formation.atoms)
  failureSupport : e1.Support (· ∈ q.formation.atoms)

theorem resultParts_sound {q C Γ path ok err t et d t1 e1}
    (hq : q.Sound) (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (ht : t.Support (· ∈ q.formation.atoms)) (he : et.Support (· ∈ q.formation.atoms))
    (h : resultParts q C Γ path ok err t et = some (d, t1, e1)) :
    ResultPartsChecked q C Γ ok err d t et t1 e1 := by
  unfold resultParts at h
  obtain ⟨cd, hc, h⟩ := Option.bind_eq_some_iff.mp h
  dsimp only at h
  split at h
  · rename_i a b ha hb
    split at h
    · next hs =>
      simp only [Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl, rfl⟩ := h
      have hh := Bool.and_eq_true_iff.mp hs
      have hr := Bool.and_eq_true_iff.mp hh.2
      have hf := Bool.and_eq_true_iff.mp hr.2
      have hsupport : (Ty.data cd.data [t, et]).Support (· ∈ q.formation.atoms) := ⟨ht, he, trivial⟩
      have hat := CheckPatterns.patTy_support hq.formation hsupport ha
      have hbt := CheckPatterns.patTy_support hq.formation hsupport hb
      exact ⟨⟨cd, hc, rfl⟩, CheckFormation.annotation_sound hq.formation hΓ hsupport hh.1,
        of_decide_eq_true hr.1, CheckPatterns.patTy_sound hq.formation hsupport ha,
        (normTyEq_spec hat.1 ht).mp hf.1, CheckPatterns.patTy_sound hq.formation hsupport hb,
        CheckPatterns.exhaustiveWithView_sound hq.formation.ctors hf.2, hat.1, hbt.1⟩
    · cases h
  · cases h

/-- Option の成功側の束縛型と、失敗側に束縛がないことを照合する。 -/
def optionParts (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat)
    (someCon noneCon : ConName) (t : Ty) : Option (DataName × Ty) := do
  let cd ← q.D.cons noneCon
  let a := Ty.data cd.data [t]
  match CheckPatterns.patTy q.formation q.D.core (.con someCon [.var]) a,
      CheckPatterns.patTy q.formation q.D.core (.con noneCon []) a with
  | some [t1], some [] =>
      if CheckFormation.annotation q.formation q.D.core C Γ path a &&
        (decide (Ordinary t1) && (normTyEq q.formation.atoms t1 t &&
          CheckPatterns.exhaustiveWithView q.D q.formation.ctors closedView a [.con someCon [.var], .con noneCon []]))
      then some (cd.data, t1) else none
  | _, _ => none

structure OptionPartsChecked (q : Check.Input) (C : TypeCtx) (Γ : Ctx)
    (someCon noneCon d : String) (t t1 : Ty) : Prop where
  constructor : ∃ cd, q.D.cons noneCon = some cd ∧ cd.data = d
  annotation : Ty.Annotation q.D.core C Γ (.data d [t])
  ordinarySuccess : Ordinary t1
  successPattern : PatTy q.D.core (.con someCon [.var]) (.data d [t]) [t1]
  sameSuccess : t1.norm = t.norm
  failurePattern : PatTy q.D.core (.con noneCon []) (.data d [t]) []
  exhaustive : Exhaustive q.D.core (.data d [t]) [.con someCon [.var], .con noneCon []]
  successSupport : t1.Support (· ∈ q.formation.atoms)

theorem optionParts_sound {q C Γ path someCon noneCon t d t1}
    (hq : q.Sound) (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (ht : t.Support (· ∈ q.formation.atoms))
    (h : optionParts q C Γ path someCon noneCon t = some (d, t1)) :
    OptionPartsChecked q C Γ someCon noneCon d t t1 := by
  unfold optionParts at h
  obtain ⟨cd, hc, h⟩ := Option.bind_eq_some_iff.mp h
  dsimp only at h
  split at h
  · rename_i a ha hb
    split at h
    · next hs =>
      simp only [Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      have hh := Bool.and_eq_true_iff.mp hs
      have hr := Bool.and_eq_true_iff.mp hh.2
      have hf := Bool.and_eq_true_iff.mp hr.2
      have hsupport : (Ty.data cd.data [t]).Support (· ∈ q.formation.atoms) := ⟨ht, trivial⟩
      have hat := CheckPatterns.patTy_support hq.formation hsupport ha
      exact ⟨⟨cd, hc, rfl⟩, CheckFormation.annotation_sound hq.formation hΓ hsupport hh.1,
        of_decide_eq_true hr.1, CheckPatterns.patTy_sound hq.formation hsupport ha,
        (normTyEq_spec hat.1 ht).mp hf.1, CheckPatterns.patTy_sound hq.formation hsupport hb,
        CheckPatterns.exhaustiveWithView_sound hq.formation.ctors hf.2, hat.1⟩
    · cases h
  · cases h

end Benitoite.Release.Refinement.Surface.CheckTry
