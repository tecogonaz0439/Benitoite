import Benitoite.Release.Refinement.LegacyValues
import Benitoite.Release.Refinement.LegacyTypeAlgebra
import Benitoite.Release.Refinement.LegacyTableFacts
import Benitoite.Release.Refinement.LocalTyping

/-! # 適格な旧導出の埋め込み（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 七判断に共通の、任意の経路条件の下での結論。 -/
def LegacyJudgment.Embedded (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B : Builtins) : LegacyJudgment → Prop
  | .value κ Ψ Q C Γ v a => ∀ Φ, HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (embedVal v) (embedTy a)
  | .values κ Ψ Q C Γ vs ts => ∀ Φ, HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTys ts)
  | .each κ Ψ Q C Γ vs a => ∀ Φ, HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTy a)
  | .comp κ Ψ Q C Γ R m a e L => ∀ Φ, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
      (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))
  | .arms κ Ψ Q C Γ R xs a b e L => ∀ Φ, HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (R.map embedTy) none
      (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind))
  | .clauses κ Ψ Q C Γ R eb cs a e L => ∀ Φ, HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (R.map embedTy) (embedEff eb)
      (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))
  | .failure κ Ψ Q C Γ E R cs a e L => ∀ Φ, HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (embedTy E) (R.map embedTy)
      (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

/-- 各 node と子の入力・結論を同時に渡す帰納。 -/
theorem LegacyOutputInput.induct_regular {K P0 B0 B j} {M : LegacyJudgment → Prop}
    (input : LegacyOutputInput K P0 B0 B j)
    (step : ∀ {j children}, LegacyRule K P0 B0 j children →
      LegacyNodeRegular K P0 B0 B j →
      (∀ child ∈ children, LegacyOutputInput K P0 B0 B child) →
      (∀ child ∈ children, M child) → M j) : M j := by
  induction input with
  | node rule regular children ih => exact step rule regular children ih

/-- node の型入力から、同じ kind 列の形成を取り出す。 -/
theorem LegacyNodeTypes.annotation {K P0 κ C nv as a}
    (types : LegacyNodeTypes K P0 κ C nv as) (member : a ∈ as)
    (count : κ.length = C.length) (Γ : Ctx) :
    Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTy a) :=
  (types a member).annotation_at rfl count Γ


theorem legacy_local_kind_shift (b : Benitoite.Release.BuilderKind) (k c : Nat) :
    renameKind (shiftIndex k c) (embedBuilderKind b) = embedBuilderKind b := by
  cases b <;> simp only [embedBuilderKind,renameKind,renameTy_shiftIndex,legacy_shiftV]

theorem legacy_local_map (L : Benitoite.Release.LocalCtx) (k c : Nat) :
    (L.map (Option.map embedBuilderKind)).map (Option.map (renameKind (shiftIndex k c))) =
      L.map (Option.map embedBuilderKind) := by
  rw [List.map_map]
  apply List.map_congr_left
  intro b _
  cases b <;> simp only [Function.comp_def,Option.map_none,Option.map_some,legacy_local_kind_shift]

theorem legacy_localExtend (n : Nat) (L : Benitoite.Release.LocalCtx) :
    localExtend n (L.map (Option.map embedBuilderKind)) =
      List.replicate n none ++ L.map (Option.map embedBuilderKind) := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [localExtend,ih,LocalCtx.extend,List.map_append,List.map_replicate,
      Option.map_none,legacy_local_map,List.replicate_succ,List.cons_append]

theorem legacy_local_shift (n : Nat) (L : Benitoite.Release.LocalCtx) :
    LocalCtx.Shift 0 0 ((Benitoite.Release.LocalCtx.extend n L).map (Option.map embedBuilderKind))
      (localExtend n (L.map (Option.map embedBuilderKind))) := by
  cases L with
  | nil => exact LocalCtx.Shift.empty 0 0 _
  | cons b bs =>
    rw [legacy_localExtend]
    simp only [Benitoite.Release.LocalCtx.extend,List.map_append,List.map_replicate,Option.map_none,
      LocalCtx.Shift,shiftIndex_zero,renameKind_id,id_eq]
    intro i b hi
    exact hi

/-- 旧の局所文脈の拡張の像から、新しい局所文脈の拡張へ移す。 -/
theorem legacy_local_zero {P B Ψ Q C Γ Φ R m a e n L}
    (body : HasTypeCQ P B Ψ Q C Γ Φ R m a e
      ((Benitoite.Release.LocalCtx.extend n L).map (Option.map embedBuilderKind))) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a e (localExtend n (L.map (Option.map embedBuilderKind))) := by
  exact body.local_zero (legacy_local_shift n L)

end
end Benitoite.Release.Refinement
