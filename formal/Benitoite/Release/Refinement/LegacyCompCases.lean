import Benitoite.Release.Refinement.LegacySequenceEmbedding
import Benitoite.Release.Refinement.PathConditions

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_comp_annotation {K P0 B0 B κ Ψ Q C Γ R m a e L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R m a e L)) :
    Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      (Γ.map (Option.map embedTy)) (embedTy a) :=
  reg.2.2.1.annotation (by simp) reg.1.2.2.1 _

theorem legacy_shiftVCtx (Γ : List (Option Benitoite.Release.Ty)) (n c : Nat) :
    (Γ.map (Option.map embedTy)).map (Option.map (Ty.shiftV n c)) = Γ.map (Option.map embedTy) := by
  rw [List.map_map]
  apply List.map_congr_left
  intro a _
  cases a <;> simp only [Function.comp_def,Option.map_none,Option.map_some,legacy_shiftV]

theorem legacy_shiftVR (R : Option Benitoite.Release.Ty) (n c : Nat) :
    (R.map embedTy).map (Ty.shiftV n c) = R.map embedTy := by
  cases R <;> simp only [Option.map_none,Option.map_some,legacy_shiftV]

theorem legacy_empty : embedEff Benitoite.Release.Eff.empty = Eff.empty := by
  apply congrArg (fun f => EffR.mk f [])
  funext a
  cases a with
  | rho i => rfl
  | name n ix => cases ix with
    | rvar i => rfl
    | fixed r => cases r <;> rfl

namespace LegacyCompCases

theorem return_case {K P0 B κ Ψ Q C Γ R v a L}
    (ih : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.ret v) a Benitoite.Release.Eff.empty L) := by
  intro Φ
  simpa only [embedComp,legacy_empty] using HasTypeCQ.C_Return (R := R.map embedTy)
    (Δ := L.map (Option.map embedBuilderKind)) (ih Φ)

theorem let_case {K P0 B0 B κ Ψ Q C Γ R m n a b e L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.letIn m n) b e L))
    (first : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C (some a :: Γ) R n b e (Benitoite.Release.LocalCtx.extend 1 L))) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.letIn m n) b e L) := by
  intro Φ
  apply HasTypeCQ.C_Let (first Φ) _ (legacy_comp_annotation reg).declared
  simpa only [Ctx.extend,List.map_cons,Option.map_some,legacy_shiftV,legacy_shiftVEff,
    legacy_shiftVCtx,legacy_shiftVR] using legacy_local_zero (body (Φ.map Pred.lift))

theorem app_case {K P0 B κ Ψ Q C Γ R f args ns as b e L}
    (fn : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ f (.fn ns as b e)))
    (argsTy : LegacyJudgment.Embedded K P0 B (.values κ Ψ Q C Γ args as)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.app f args) b e L) := by
  intro Φ
  exact .C_App (fn Φ) (argsTy Φ)

end LegacyCompCases
end
end Benitoite.Release.Refinement
