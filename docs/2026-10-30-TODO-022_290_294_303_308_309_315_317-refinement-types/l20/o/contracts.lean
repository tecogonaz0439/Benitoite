import Benitoite
namespace Benitoite.Release.Refinement.LegacyContracts
noncomputable section
def embedHasTypeVQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValueInput K P0 B0 B Δ v →
      LegacyOutputInput K P0 B0 B (.value Δ.kinds Ψ Q C Γ v a) →
      Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a →
      ∀ Φ : List Pred, HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedVal v) (embedTy a)

def embedHasTypeVsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {ts : List Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.values Δ.kinds Ψ Q C Γ vs ts) →
      Benitoite.Release.HasTypeVsQ P0 B0 Ψ Q C Γ vs ts →
      ∀ Φ : List Pred, HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTys ts)

def embedHasTypeEachQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.each Δ.kinds Ψ Q C Γ vs a) →
      Benitoite.Release.HasTypeEachQ P0 B0 Ψ Q C Γ vs a →
      ∀ Φ : List Pred, HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTy a)

def embedHasTypeCQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyCompInput K P0 B0 B Δ m →
      LegacyOutputInput K P0 B0 B (.comp Δ.kinds Ψ Q C Γ R m a e L) →
      Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L →
      ∀ Φ : List Pred, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeArmsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {xs : List Benitoite.Release.Arm}
      {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyArmsInput K P0 B0 B Δ xs →
      LegacyOutputInput K P0 B0 B (.arms Δ.kinds Ψ Q C Γ R xs a b e L) →
      Benitoite.Release.HasTypeArmsQ P0 B0 Ψ Q C Γ R xs a b e L →
      ∀ Φ : List Pred, HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) none
        (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeClausesQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.clauses Δ.kinds Ψ Q C Γ R eb cs a e L) →
      Benitoite.Release.HasTypeClausesQ P0 B0 Ψ Q C Γ R eb cs a e L →
      ∀ Φ : List Pred, HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) (embedEff eb)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasFailureClause : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {E : Benitoite.Release.Ty} {R : Option Benitoite.Release.Ty}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.failure Δ.kinds Ψ Q C Γ E R cs a e L) →
      Benitoite.Release.HasFailureClause P0 B0 Ψ Q C Γ E R cs a e L →
      ∀ Φ : List Pred, HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))
end
end Benitoite.Release.Refinement.LegacyContracts
