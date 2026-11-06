import Benitoite.Release.Refinement.ContextTransport

/-! # 局所文脈と戻り先の移送（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement

theorem renameKind_id (b : BuilderKind) : renameKind id b = b := by
  cases b <;> simp [renameKind,renameTy_id]

theorem renameKind_zero (b : BuilderKind) (c : Nat) : renameKind (shiftIndex 0 c) b = b := by
  cases b <;> simp [renameKind_shift,Ty.shiftV_zero]

theorem LocalCtx.Shift.zero_extend {L L'} (h : LocalCtx.Shift 0 0 L L') (x : Option BuilderKind) :
    LocalCtx.Shift 0 0 (LocalCtx.extend x L) (LocalCtx.extend x L') := by
  simp only [LocalCtx.Shift,shiftIndex_zero,renameKind_id,id_eq] at h ⊢
  intro i b hi
  cases i with
  | zero => simpa only [LocalCtx.extend,List.getElem?_cons_zero] using hi
  | succ i =>
    simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi ⊢
    cases hl : L[i]? with
    | none => simp [hl] at hi
    | some ob => cases ob with
      | none => simp [hl] at hi
      | some a =>
        simp only [hl,Option.map_some,Option.some.injEq] at hi
        cases hi
        rw [h i a hl]
        rfl

theorem LocalCtx.Shift.zero_localExtend {L L'} (h : LocalCtx.Shift 0 0 L L') (n : Nat) :
    LocalCtx.Shift 0 0 (Refinement.localExtend n L) (Refinement.localExtend n L') := by
  have hh := h.localExtend n
  simpa only [LocalCtx.Shift,renameKind_zero,shiftIndex_zero] using hh

theorem LocalRef.HasKind.local_zero {Ψ L L' r b} (h : LocalRef.HasKind Ψ L r b)
    (hL : LocalCtx.Shift 0 0 L L') : LocalRef.HasKind Ψ L' r b := by
  induction h with
  | bound hi => exact .bound (by simpa only [shiftIndex_zero,renameKind_id,id_eq] using hL _ _ hi)
  | loc hi => exact .loc hi
  | normal h ih => exact ih.normal

mutual
  theorem HasTypeCQ.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasTypeCQ P B Ψ Q C Γ Φ R m a e L' := by
    match h with
    | @HasTypeCQ.C_BuilderLet _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_BuilderLet x11 x12 (HasTypeCQ.local_zero x13 (hL.zero_extend _)) x14
    | @HasTypeCQ.C_BuilderOp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_BuilderOp x11 x12 (x13.local_zero hL) x14
    | @HasTypeCQ.C_Return _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .C_Return x9
    | @HasTypeCQ.C_Let _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Let (HasTypeCQ.local_zero x12 hL) (HasTypeCQ.local_zero x13 (hL.zero_localExtend 1)) x14
    | @HasTypeCQ.C_App _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_App x13 x14
    | @HasTypeCQ.C_DependentApp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 =>
      exact .C_DependentApp x12 x13
    | @HasTypeCQ.C_If _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_If x13 x14 (HasTypeCQ.local_zero x15 hL) (HasTypeCQ.local_zero x16 hL)
    | @HasTypeCQ.C_Match _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Match x13 x14 (HasTypeArmsQ.local_zero x15 hL) x16 x17
    | @HasTypeCQ.C_Lazy _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .C_Lazy x9 x10
    | @HasTypeCQ.C_Escape _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .C_Escape x10 x11
    | @HasTypeCQ.C_Use _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact .C_Use x12 x13 (HasTypeCQ.local_zero x14 hL) x15
    | @HasTypeCQ.C_Handle _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Handle (HasTypeCQ.local_zero x12 hL) x13 (HasTypeClausesQ.local_zero x14 hL)
    | @HasTypeCQ.C_Handle_Fail _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Handle_Fail (HasTypeCQ.local_zero x14 hL) x15 x16 (HasFailureClause.local_zero x17 hL)
    | @HasTypeCQ.C_Resume _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Resume x12 x13 x14
    | @HasTypeCQ.C_ResumeL _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_ResumeL x12 x13 x14
    | @HasTypeCQ.C_ResumeNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_ResumeNorm x12 x13 x14
    | @HasTypeCQ.C_ResumeLNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_ResumeLNorm x13 x14 x15 x16
    | @HasTypeCQ.C_Normal _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .C_Normal (HasTypeCQ.local_zero x10 hL)
    | @HasTypeCQ.C_Meth _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 =>
      exact .C_Meth x19 x20 x21 x22 x23 x24 x25 x26 x27 x28
    | @HasTypeCQ.C_External _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_External x13 x14 x15 x16
    | @HasTypeCQ.C_IssuePathBases _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_IssuePathBases x7 x8 x9 x10 x11 x12 x13 x14
    | @HasTypeCQ.C_CheckAt _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_CheckAt x14
    | @HasTypeCQ.C_Sub _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Sub (HasTypeCQ.local_zero x12 hL) x13 x14 x15 x16 x17
    | @HasTypeCQ.C_Eff _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .C_Eff (HasTypeCQ.local_zero x11 hL) x12
  termination_by structural h

  theorem HasTypeArmsQ.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a : Ty} {b : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L' := by
    match h with
    | @HasTypeArmsQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .nil x11
    | @HasTypeArmsQ.plain _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18  x19 x20 x21 =>
      exact .plain x16 x17 x18 x19 (HasTypeCQ.local_zero x20 (hL.zero_localExtend _)) (HasTypeArmsQ.local_zero x21 hL)
    | @HasTypeArmsQ.guarded _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22  x23 x24 x25 =>
      exact .guarded x18 x19 x20 x21 x22 (HasTypeCQ.local_zero x23 (hL.zero_localExtend _)) (HasTypeCQ.local_zero x24 (hL.zero_localExtend _)) (HasTypeArmsQ.local_zero x25 hL)
  termination_by structural h

  theorem HasTypeClausesQ.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {eb : Eff} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L' := by
    match h with
    | @HasTypeClausesQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .nil 
    | @HasTypeClausesQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 =>
      exact .cons x16 x17 x18 x19 x20 x21 (HasTypeClausesQ.local_zero x22 hL)
  termination_by structural h

  theorem HasFailureClause.local_zero {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {E : Ty} {R : Option Ty} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) {L' : LocalCtx} (hL : LocalCtx.Shift 0 0 L L') :
    HasFailureClause P B Ψ Q C Γ Φ E R cs t e L' := by
    match h with
    | @HasFailureClause.one _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .one x11 x12 x13 x14

end

mutual
  theorem HasTypeCQ.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasTypeCQ P B Ψ Q C Γ Φ R' m a e L := by
    match h with
    | @HasTypeCQ.C_BuilderLet _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_BuilderLet x11 x12 (HasTypeCQ.withReturn x13 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x14
    | @HasTypeCQ.C_BuilderOp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_BuilderOp x11 x12 x13 x14
    | @HasTypeCQ.C_Return _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .C_Return x9
    | @HasTypeCQ.C_Let _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Let (HasTypeCQ.withReturn x12 (by rw [hΨ] <;> rfl) (by simp [hR]) _) (HasTypeCQ.withReturn x13 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x14
    | @HasTypeCQ.C_App _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_App x13 x14
    | @HasTypeCQ.C_DependentApp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 =>
      exact .C_DependentApp x12 x13
    | @HasTypeCQ.C_If _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_If x13 x14 (HasTypeCQ.withReturn x15 (by rw [hΨ] <;> rfl) (by simp [hR]) _) (HasTypeCQ.withReturn x16 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
    | @HasTypeCQ.C_Match _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Match x13 x14 (HasTypeArmsQ.withReturn x15 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x16 x17
    | @HasTypeCQ.C_Lazy _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .C_Lazy x9 x10
    | @HasTypeCQ.C_Escape _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      cases hR
    | @HasTypeCQ.C_Use _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact .C_Use x12 x13 (HasTypeCQ.withReturn x14 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x15
    | @HasTypeCQ.C_Handle _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Handle (HasTypeCQ.withReturn x12 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x13 (HasTypeClausesQ.withReturn x14 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
    | @HasTypeCQ.C_Handle_Fail _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Handle_Fail (HasTypeCQ.withReturn x14 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x15 x16 (HasFailureClause.withReturn x17 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
    | @HasTypeCQ.C_Resume _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Resume x12 x13 x14
    | @HasTypeCQ.C_ResumeL _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      rw [hΨ] at x12
      cases x12
    | @HasTypeCQ.C_ResumeNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_ResumeNorm x12 x13 x14
    | @HasTypeCQ.C_ResumeLNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      rw [hΨ] at x13
      cases x13
    | @HasTypeCQ.C_Normal _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .C_Normal (HasTypeCQ.withReturn x10 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
    | @HasTypeCQ.C_Meth _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 =>
      exact .C_Meth x19 x20 x21 x22 x23 x24 x25 x26 x27 x28
    | @HasTypeCQ.C_External _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_External x13 x14 x15 x16
    | @HasTypeCQ.C_IssuePathBases _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_IssuePathBases x7 x8 x9 x10 x11 x12 x13 x14
    | @HasTypeCQ.C_CheckAt _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_CheckAt x14
    | @HasTypeCQ.C_Sub _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Sub (HasTypeCQ.withReturn x12 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x13 x14 x15 x16 x17
    | @HasTypeCQ.C_Eff _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .C_Eff (HasTypeCQ.withReturn x11 (by rw [hΨ] <;> rfl) (by simp [hR]) _) x12
  termination_by structural h

  theorem HasTypeArmsQ.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a : Ty} {b : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R' obs arms a b e L := by
    match h with
    | @HasTypeArmsQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .nil x11
    | @HasTypeArmsQ.plain _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18  x19 x20 x21 =>
      exact .plain x16 x17 x18 x19 (HasTypeCQ.withReturn x20 (by rw [hΨ] <;> rfl) (by simp [hR]) _) (HasTypeArmsQ.withReturn x21 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
    | @HasTypeArmsQ.guarded _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22  x23 x24 x25 =>
      exact .guarded x18 x19 x20 x21 x22 x23 (HasTypeCQ.withReturn x24 (by rw [hΨ] <;> rfl) (by simp [hR]) _) (HasTypeArmsQ.withReturn x25 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
  termination_by structural h

  theorem HasTypeClausesQ.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {eb : Eff} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasTypeClausesQ P B Ψ Q C Γ Φ R' eb cs t e L := by
    match h with
    | @HasTypeClausesQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .nil 
    | @HasTypeClausesQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 =>
      exact .cons x16 x17 x18 x19 x20 (HasTypeCQ.withReturn x21 (by rw [hΨ] <;> rfl) (by simp [hR]) _) (HasTypeClausesQ.withReturn x22 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
  termination_by structural h

  theorem HasFailureClause.withReturn {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {E : Ty} {R : Option Ty} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) (hΨ : Ψ = StoreTy.empty) (hR : R = none) (R' : Option Ty) :
    HasFailureClause P B Ψ Q C Γ Φ E R' cs t e L := by
    match h with
    | @HasFailureClause.one _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .one x11 x12 x13 (HasTypeCQ.withReturn x14 (by rw [hΨ] <;> rfl) (by simp [hR]) _)
  termination_by structural h

end

end Benitoite.Release.Refinement
