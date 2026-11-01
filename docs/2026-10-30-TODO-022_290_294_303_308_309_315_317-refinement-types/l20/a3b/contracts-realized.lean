import Benitoite.Release.Refinement.TypeSubstFormation

namespace Benitoite.Release.Refinement.A3bRealized

-- Ty.HasKind.closed_context
example : (∀ {P : Program} {K K' : KindCtx} {a : Ty} {k : TyKind} {nr nv : Nat},
  a.WF nr 0 nv → a.HasKind P K k → a.HasKind P K' k) := @Ty.HasKind.closed_context

-- kindsEff.closed_context
example : (∀ {P : Program} {K K' : KindCtx} {e : Eff} {nr nv : Nat},
  e.WF nr 0 nv → kindsEff P K e → kindsEff P K' e) := @kindsEff.closed_context

-- Ty.HasKind.substAt
example : (∀ {P : Program} {C0 C1 : TypeCtx} {a : Ty} {k : TyKind} {ts : List Ty} {es : List Eff},
  a.HasKind P (TypeCtx.kinds (C1 ++ C0)) k →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) →
  (a.substAt C1.length ts es).HasKind P (TypeCtx.kinds C1) k) := @Ty.HasKind.substAt

-- Tel.kinded_substAt
example : (∀ {P C0 C1 t ts es},
  kindsTel P (TypeCtx.kinds (C1 ++ C0)) t → TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) → kindsTel P (TypeCtx.kinds C1) (t.substAt C1.length ts es)) := @Tel.kinded_substAt

-- TypeArgsKinded.substAt
example : (∀ {P C0 C1 as ks ts es},
  TypeArgsKinded P (C1 ++ C0) as ks →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) → (∀ e ∈ es, kindsEff P [] e) →
  TypeArgsKinded P C1 (as.map (Ty.substAt C1.length ts es)) ks) := @TypeArgsKinded.substAt

-- Ty.Declared.substAt
example : (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → Ty.Annotation P (C1 ++ C0) Γ a →
  Ty.Declared P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) ((Ty.substAt C1.length ts es) a)) := @Ty.Declared.substAt

-- Tel.Declared.substAt
example : (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ t ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t) →
  Tel.Declared P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) ((Tel.substAt C1.length ts es) t)) := @Tel.Declared.substAt

-- declaredTys_substAt
example : (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeAnnotations P (C1 ++ C0) Γ as →
  declaredTys P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) (as.map (Ty.substAt C1.length ts es))) := @declaredTys_substAt

-- declaredEff_substAt
example : (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ e ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowAnnotations P (C1 ++ C0) Γ [e] →
  declaredEff P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) ((Eff.substAt C1.length ts es) e)) := @declaredEff_substAt

end Benitoite.Release.Refinement.A3bRealized
