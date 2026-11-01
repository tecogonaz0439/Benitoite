import Benitoite.Release.Refinement.TypeSubstContracts
import Benitoite.Release.Refinement.LegacyValues

namespace Benitoite.Release.Refinement.A3aBoundary
noncomputable section

private theorem singleton_kinded {P C a k}
    (h : a.HasKind P (TypeCtx.kinds C) k) (ho : k = .value → Ordinary a) :
    TypeArgsKinded P C [a] [k] := by
  refine ⟨rfl, ?_⟩
  intro i b l hb hl
  cases i with
  | zero => cases Option.some.inj hb; cases Option.some.inj hl; exact ⟨h, ho⟩
  | succ i => cases hb

theorem value_tvar (P : Program) :
    TypeArgsKinded P [TypeCtx.valueParam] [.tvar 0] [.value] :=
  singleton_kinded rfl (by intro _; simp [Ordinary, Ty.core])

theorem constructor_tvar (P : Program) :
    TypeArgsKinded P [⟨{}, .constructor 1⟩] [.tvar 0] [.constructor 1] :=
  singleton_kinded rfl (by intro h; cases h)

theorem reject_constructor_as_value (P : Program) :
    ¬ TypeArgsKinded P [⟨{}, .constructor 1⟩] [.tvar 0] [.value] := by
  intro h
  have hk := (h.2 0 (.tvar 0) .value rfl rfl).1
  simp [Ty.HasKind, TypeCtx.kinds] at hk

theorem reject_value_as_constructor (P : Program) :
    ¬ TypeArgsKinded P [TypeCtx.valueParam] [.tvar 0] [.constructor 1] := by
  intro h
  have hk := (h.2 0 (.tvar 0) (.constructor 1) rfl rfl).1
  simp [Ty.HasKind, TypeCtx.kinds, TypeCtx.valueParam] at hk

theorem bytes_image (P : Program) : TypeArgsKinded P [] [.bytes] [.value] :=
  singleton_kinded trivial (by intro _; simp [Ordinary, Ty.core])

theorem constructor_image (P : Program) :
    TypeArgsKinded P [] [.ctor .list] [.constructor 1] :=
  singleton_kinded rfl (by intro h; cases h)

theorem reject_tapp_arity (P : Program) (Γ : Ctx) :
    ¬ Ty.Declared P [⟨{}, .constructor 1⟩] Γ (.tapp 0 [.bytes, .bytes]) := by
  simp [Ty.Declared, TypeCtx.kinds]

theorem valid_tapp (P : Program) (Γ : Ctx) :
    Ty.Annotation P [⟨{}, .constructor 1⟩] Γ (.tapp 0 [.bytes]) := by
  constructor
  · simp [Ty.WF, Ty.WFList]
  · trivial
  · exact ⟨rfl, trivial, trivial⟩

theorem rename_tapp_head {P C C' Γ Δ i as ρ}
    (h : Ty.Declared P C Γ (.tapp i as))
    (hr : KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') ρ)
    (ha : declaredTys P C' Δ (rawRenameTypesList ρ as)) :
    Ty.Declared P C' Δ ((Ty.tapp i as).rawRenameTypes ρ) :=
  ⟨by simpa only [rawRenameTypesList_length] using hr _ _ h.1, ha⟩

theorem norm_tapp (P : Program) (Γ : Ctx) :
    Ty.Annotation P [⟨{}, .constructor 1⟩] Γ (Ty.tapp 0 [.bytes]).norm :=
  (valid_tapp P Γ).norm

theorem value_shift_tapp (P : Program) (Γ : Ctx) :
    Ty.Declared P [⟨{}, .constructor 1⟩] (Γ.extendNone)
      ((Ty.tapp 0 [.bytes]).shiftV 1 0) :=
  (ShiftMap.outerValue Γ none).declared (valid_tapp P Γ).declared

theorem declared_closed (P : Program) (C : TypeCtx) (Γ : Ctx) :
    Ty.Annotation P C Γ (.list .bytes) :=
  (show Ty.Annotation P [] [] (.list .bytes) from ⟨trivial, trivial, trivial⟩).closed_context

theorem legacy_context_kinds {C κ} (h : κ.length = C.length) :
    TypeCtx.kinds (legacyTypeCtx C κ) = κ := legacyTypeCtx_kinds h

theorem legacy_context_constraints {C κ} (h : κ.length = C.length) :
    TypeCtx.constraints (legacyTypeCtx C κ) = C := legacyTypeCtx_constraints h

end
end Benitoite.Release.Refinement.A3aBoundary

#print axioms Benitoite.Release.Refinement.A3aBoundary.reject_constructor_as_value
#print axioms Benitoite.Release.Refinement.A3aBoundary.reject_value_as_constructor
#print axioms Benitoite.Release.Refinement.A3aBoundary.reject_tapp_arity
#print axioms Benitoite.Release.Refinement.A3aBoundary.rename_tapp_head
