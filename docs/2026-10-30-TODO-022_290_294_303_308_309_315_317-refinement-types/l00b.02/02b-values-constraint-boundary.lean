import Benitoite.Release.Refinement.TypingDeclared
import Benitoite.Release.Refinement.ValueInstantiation

namespace Benitoite.Release.Refinement.ValueConstraintBoundary

/-- 外側の Integer を読む、整形式の鍵型。 -/
def keyTy : Ty := .refined (.base .integer) (.eq (.var 1) (.integer 0))
def sourceCtx : Ctx := [some (.base .integer)]
def zero : Val := .const (.integer ⟨0, by decide⟩)
def ν : Nat → Val := fun _ => zero

/-- 型の置換には不変だが、値注釈の置換には不変でない表の例。 -/
def Sat (_ : List TParam) (a : Ty) (p : TParam) : Prop := p.key = false ∨ a = keyTy

def B : Builtins :=
  { sig := fun _ => none
    delta := fun _ _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ _ => False
    releaseResponse := fun _ _ => True
    isResource := fun _ => false
    effects := fun _ => none
    sat := Sat
    refGet := "get"
    refSet := "set" }

theorem source_annotation (P : Program) : Ty.Annotation P [] sourceCtx keyTy := by
  constructor
  · simp [keyTy, sourceCtx, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
  · simp [keyTy, sourceCtx, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape,
      Ty.HasSort, Ty.sort?, Term.References, Term.VarsIn, Ctx.Readable]
  · simp [keyTy, sourceCtx, Ty.Declared, Pred.Declared, Term.Declared, Ctx.declarationSelf,
      Ctx.extend, Ctx.Readable, Ty.shiftV]

theorem typed_image (P : Program) (Ψ : StoreTy) :
    SubstOk P B Ψ Qempty [] sourceCtx [] [] [] none ν := by
  intro i a hi
  cases i with
  | zero =>
    simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    left
    exact ⟨by simp, .V_Const trivial⟩
  | succ i => simp [sourceCtx] at hi

theorem source_sat : B.sat [] keyTy TParam.keyC := Or.inr rfl

theorem substituted_key : substTyValues ν keyTy =
    .refined (.base .integer) (.eq (.integer 0) (.integer 0)) := by
  rfl

theorem target_not_sat : ¬ B.sat [] (substTyValues ν keyTy) TParam.keyC := by
  rw [substituted_key]
  simp [B, Sat, TParam.keyC, keyTy]

theorem shifted_not_sat : ¬ B.sat [] (keyTy.shiftV 1 0) TParam.keyC := by
  simp [B, Sat, TParam.keyC, keyTy, Ty.shiftV, predBind, termBind, termBind?]

/-- 既存の制約の型文脈の延長則より強い性質を満たす。 -/
theorem sat_local (C1 C0 : List TParam) (a : Ty) (p : TParam) :
    Sat C1 a p → Sat (C1 ++ C0) a p := id

/-- 制約なしのパラメータは全型を受け入れる。 -/
theorem sat_unconstrained (a : Ty) : Sat [] a ({} : TParam) := Or.inl rfl

theorem keyTy_type_subst (c : Nat) (ts : List Ty) (es : List Eff) :
    keyTy.substAt c ts es = keyTy := by
  simp [Ty.substAt, substTypeAt, Ty.bind, keyTy, Ty.rawBind, typeEnvAt,
    upValues_id, predBind_id, Ty.norm]

/-- 閉じた型の像に限らず、任意の型・行の像でも既存の型置換則を満たす。 -/
theorem sat_subst (C0 C1 : List TParam) (a : Ty) (p : TParam) (ts : List Ty) (es : List Eff) :
    Sat (C1 ++ C0) a p → Sat C1 (a.substAt C1.length ts es) p := by
  rintro (hp | rfl)
  · exact Or.inl hp
  · exact Or.inr (keyTy_type_subst _ _ _)

/-- 旧の sat の三つの条件だけから値置換の保存は導けない。 -/
theorem no_value_transport : ¬ (∀ (a : Ty) (p : TParam),
    B.sat [] a p → B.sat [] (substTyValues ν a) p) := by
  intro h
  exact target_not_sat (h _ _ source_sat)

/-- 署名どおりの空 Map の前提が、型付きの値置換後に失われる。 -/
theorem map_premises (P : Program) (Ψ : StoreTy) :
    HasTypeEachQ P B Ψ Qempty [] sourceCtx [] [] keyTy ∧
    Ty.Annotation P [] sourceCtx keyTy ∧ B.sat [] keyTy TParam.keyC ∧
    ¬ B.sat [] (substTyValues ν keyTy) TParam.keyC :=
  ⟨.nil, source_annotation P, source_sat, target_not_sat⟩

def locStore : StoreTy := fun i => if i = 0 then some (.ref (.base .unit)) else none

theorem locStore_wf : StoreTy.WF locStore := by
  intro i t ht
  by_cases hi : i = 0
  · simp only [locStore, hi, ↓reduceIte, Option.some.injEq] at ht
    cases ht; trivial
  · simp [locStore, hi] at ht

theorem location_typed (P : Program) :
    HasTypeVQ P B locStore Qempty [] [] [] (.loc 0) (.reference (.base .unit)) :=
  .V_LocRef (by simp [locStore]) trivial

private theorem empty_no_location_aux {P Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) : Ψ 0 = none → v = .loc 0 → False := by
  match h with
  | .V_LocRef hl _ | .V_LocLazy hl _ => intro h0 he; cases he; rw [h0] at hl; cases hl
  | .V_Sub hv _ _ _ _ => exact empty_no_location_aux hv
  | .V_Refine hv _ _ _ _ _ _ _ => exact empty_no_location_aux hv
  | .V_Var _ _ | .V_Const _ | .V_Lam _ _ _ _ _ | .V_List _ _ _ _
  | .V_Raise _ | .V_Bytes _ | .V_Con _ _ _ _ _ | .V_Super _ _ _ _ => intro _ he; cases he

theorem empty_no_location {P Q C Γ Φ a}
    (h : HasTypeVQ P B StoreTy.empty Q C Γ Φ (.loc 0) a) : False :=
  empty_no_location_aux h rfl rfl

theorem cannot_erase_location : ¬ StoreTy.PreservesNormals locStore StoreTy.empty := by
  intro h
  have hh := h 0 (.ref (.base .unit)) (by simp [locStore]) trivial
  cases hh

#print axioms locStore_wf
#print axioms location_typed
#print axioms empty_no_location
#print axioms cannot_erase_location
#print axioms sat_local
#print axioms sat_unconstrained
#print axioms keyTy_type_subst
#print axioms source_sat
#print axioms substituted_key
#print axioms empty_no_location_aux
#print axioms source_annotation
#print axioms typed_image
#print axioms target_not_sat
#print axioms shifted_not_sat
#print axioms sat_subst
#print axioms no_value_transport
#print axioms map_premises
end Benitoite.Release.Refinement.ValueConstraintBoundary
