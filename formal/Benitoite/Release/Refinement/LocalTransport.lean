import Benitoite.Release.Refinement.ValueBinding

namespace Benitoite.Release.Refinement
noncomputable section

theorem renameKind_shift (b : BuilderKind) (k c : Nat) :
    renameKind (shiftIndex k c) b = match b with
      | .list a => .list (a.shiftV k c) | b => b := by
  cases b <;> simp [renameKind, Ty.shiftV_eq_renameTy]

theorem renameKind_comm (b : BuilderKind) (k c) :
    renameKind (shiftIndex k (c+1)) (renameKind (shiftIndex 1 0) b) =
      renameKind (shiftIndex 1 0) (renameKind (shiftIndex k c) b) := by
  cases b <;> simp only [renameKind_shift, Ty.shiftV_comm]

theorem substKind_shift (b : BuilderKind) (ν : Nat → Val) :
    substKind (upSubst 1 ν) (renameKind (shiftIndex 1 0) b) =
      renameKind (shiftIndex 1 0) (substKind ν b) := by
  cases b <;> simp only [renameKind_shift, substKind, Ty.bind_shiftV_values]

theorem renameKind_closed {b : BuilderKind} (h : LocTy.WF (.builder b)) (ξ : Nat → Nat) :
    renameKind ξ b = b := by
  cases b with
  | string | bytes => rfl
  | list a =>
    change BuilderKind.list (a.rawBind (renEnv ξ)) = .list a
    simp only [renEnv, ← Ty.rawSubstV_eq_rawBind]
    exact congrArg BuilderKind.list (Ty.rawSubstV_of_wf_zero h _)

theorem substKind_closed {b : BuilderKind} (h : LocTy.WF (.builder b)) (ν : Nat → Val) :
    substKind ν b = b := by
  cases b with
  | string | bytes => rfl
  | list a => exact congrArg BuilderKind.list (Ty.subst_values_of_wf_zero h ν)

theorem LocalCtx.Shift.empty (k c) (L : LocalCtx) : LocalCtx.Shift k c [] L := by
  intro i b hi; simp at hi

theorem LocalCtx.Shift.refl (L : LocalCtx) : LocalCtx.Shift 0 0 L L := by
  intro i b hi
  have hk : renameKind (shiftIndex 0 0) b = b := by
    have he : shiftIndex 0 0 = id := by funext i; simp [shiftIndex]
    rw [he]
    cases b <;> simp [renameKind, renameTy_id]
  simpa only [shiftIndex, Nat.not_lt_zero, ↓reduceIte, Nat.add_zero, hk] using hi

theorem LocalCtx.Shift.extend {k c L L'} (h : LocalCtx.Shift k c L L')
    (x : Option BuilderKind) :
    LocalCtx.Shift k (c+1) (LocalCtx.extend (x.map (renameKind (shiftIndex 1 0))) L)
      (LocalCtx.extend (x.map (fun b => renameKind (shiftIndex 1 0) (renameKind (shiftIndex k c) b))) L') := by
  intro i b hi
  cases i with
  | zero =>
    cases x with
    | none => simp [LocalCtx.extend] at hi
    | some b' =>
      simp only [LocalCtx.extend, Option.map_some, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      simp only [shiftIndex, Nat.zero_lt_succ, ↓reduceIte, LocalCtx.extend,
        Option.map_some, List.getElem?_cons_zero, renameKind_comm]
  | succ i =>
    simp only [LocalCtx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨u, hu, he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some a =>
      cases he
      have hh := h i a hu
      have hs : shiftIndex k (c+1) (i+1) = shiftIndex k c i+1 := by unfold shiftIndex; split <;> split <;> omega
      simp only [LocalCtx.extend, hs, List.getElem?_cons_succ, List.getElem?_map,
        hh, Option.map_some, renameKind_comm]

theorem LocalCtx.Shift.localExtend {k c L L'} (h : LocalCtx.Shift k c L L') (n : Nat) :
    LocalCtx.Shift k (c+n) (localExtend n L) (localExtend n L') := by
  induction n with
  | zero => simpa only [Refinement.localExtend, Nat.add_zero] using h
  | succ n ih => simpa only [Refinement.localExtend, Option.map_none, Nat.add_assoc] using ih.extend none

theorem LocalRef.HasKind.shift {Ψ Ψ' L L' r b k c}
    (h : LocalRef.HasKind Ψ L r b) (hw : Ψ.WF) (he : Ψ.Extends Ψ')
    (hl : LocalCtx.Shift k c L L') :
    LocalRef.HasKind Ψ' L' (r.rename (shiftIndex k c)) (renameKind (shiftIndex k c) b) := by
  cases h with
  | bound hi => exact .bound (hl _ _ hi)
  | loc hi => rw [renameKind_closed (hw _ _ hi)]; exact .loc (he _ _ hi)

theorem LocalRef.HasKind.lift {Ψ L r b} (h : LocalRef.HasKind Ψ L r b) (hw : Ψ.WF)
    (x : Option BuilderKind) :
    LocalRef.HasKind Ψ (LocalCtx.extend x L) (r.rename (· + 1)) (renameKind (shiftIndex 1 0) b) := by
  cases h with
  | bound hi => exact .bound (by simp [LocalCtx.extend, hi])
  | loc hi => rw [renameKind_closed (hw _ _ hi)]; exact .loc hi

theorem LocalSubstOk.empty (Ψ : StoreTy) (ν : Nat → Val) (ρ : Nat → LocalRef) (L : LocalCtx) :
    LocalSubstOk Ψ [] ν ρ L := by intro i b hi; simp at hi

theorem LocalSubstOk.extend {Ψ L L' ν ρ} (h : LocalSubstOk Ψ L ν ρ L') (hw : Ψ.WF)
    (x : Option BuilderKind) :
    LocalSubstOk Ψ (LocalCtx.extend (x.map (renameKind (shiftIndex 1 0))) L)
      (upSubst 1 ν) (upLocalSubst 1 ρ)
      (LocalCtx.extend (x.map (fun b => renameKind (shiftIndex 1 0) (substKind ν b))) L') := by
  intro i b hi
  cases i with
  | zero =>
    cases x with
    | none => simp [LocalCtx.extend] at hi
    | some b' =>
      simp only [LocalCtx.extend, Option.map_some, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      rw [substKind_shift]
      exact .bound (by simp [LocalCtx.extend])
  | succ i =>
    simp only [LocalCtx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨u, hu, he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some a =>
      cases he
      rw [substKind_shift]
      simpa only [upLocalSubst, Nat.succ_lt_succ_iff, Nat.not_lt_zero, ↓reduceIte,
        Nat.add_one_sub_one] using (h i a hu).lift hw (x.map (fun b => renameKind (shiftIndex 1 0) (substKind ν b)))

theorem LocalRef.HasKind.subst {Ψ L L' r b ν ρ}
    (h : LocalRef.HasKind Ψ L r b) (hw : Ψ.WF) (hl : LocalSubstOk Ψ L ν ρ L') :
    LocalRef.HasKind Ψ L' (r.subst ρ) (substKind ν b) := by
  cases h with
  | bound hi => exact hl _ _ hi
  | loc hi => rw [substKind_closed (hw _ _ hi)]; exact .loc hi

@[simp] theorem BuilderKind.contents_rename (b : BuilderKind) (k c) :
    (renameKind (shiftIndex k c) b).contents = b.contents.shiftV k c := by
  cases b <;> simp [renameKind_shift, BuilderKind.contents, Ty.shiftV]

@[simp] theorem BuilderKind.contents_subst (b : BuilderKind) (ν) :
    (substKind ν b).contents = substTyValues ν b.contents := by cases b <;> rfl

@[simp] theorem BuilderOp.parameters_rename (op : BuilderOp) (b : BuilderKind) (k c) :
    op.parameters (renameKind (shiftIndex k c) b) = (op.parameters b).map (Ty.shiftV k c) := by
  cases op <;> cases b <;> simp [BuilderOp.parameters, BuilderKind.contents, BuilderKind.item, renameKind_shift, Ty.shiftV]

@[simp] theorem BuilderOp.resultType_rename (op : BuilderOp) (b : BuilderKind) (k c) :
    op.resultType (renameKind (shiftIndex k c) b) = (op.resultType b).shiftV k c := by
  cases op <;> simp [BuilderOp.resultType, Ty.shiftV]

@[simp] theorem BuilderOp.parameters_subst (op : BuilderOp) (b : BuilderKind) (ν) :
    op.parameters (substKind ν b) = (op.parameters b).map (substTyValues ν) := by
  cases op <;> cases b <;> rfl

@[simp] theorem BuilderOp.resultType_subst (op : BuilderOp) (b : BuilderKind) (ν) :
    op.resultType (substKind ν b) = substTyValues ν (op.resultType b) := by cases op <;> cases b <;> rfl

end
end Benitoite.Release.Refinement
