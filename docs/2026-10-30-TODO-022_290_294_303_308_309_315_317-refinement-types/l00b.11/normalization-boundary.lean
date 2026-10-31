import Lean
import Benitoite.Release.Refinement.InversionCore
import Benitoite.Release.Refinement.NormalWellFormed

namespace Benitoite.Release.Refinement.NormalizationBoundary

abbrev U : Ty := .base .unit
abbrev p : Pred := .eq .unitValue .unitValue
abbrev q : Pred := .falsity

-- 正規形の等号は述語の順序と重複を保つ。
theorem true_erased : (Ty.refined U .truth).norm = U.norm := Ty.norm_refined_truth U

theorem refinement_association :
    (Ty.refined (.refined U p) q).norm = (Ty.refined U (.and p q)).norm := by
  rfl

theorem conjunction_association :
    (Ty.refined U (.and (.and p q) p)).norm =
      (Ty.refined U (.and p (.and q p))).norm := by
  rfl

theorem conjunction_order_preserved :
    (Ty.refined U (.and p q)).norm ≠ (Ty.refined U (.and q p)).norm := by
  intro he; cases he

theorem conjunction_duplicates_preserved :
    (Ty.refined U (.and p p)).norm ≠ (Ty.refined U p).norm := by
  intro he; cases he

theorem falsity_retained : (Ty.refined U .falsity).norm = .refined U .falsity := rfl

theorem empty_refinement_not_erased : (Ty.refined U .falsity).norm ≠ U.norm := by
  intro he; cases he

private def image : SubstEnv :=
  ⟨fun _ => .refined U q, [], [], fun i => some (.var i)⟩

-- ソースと像に篩があり、前回は括り方が一致しなかった境界。
theorem substitution_association :
    let a := Ty.refined (.refined (.tvar 0) p) q
    (a.norm.rawBind image).norm = (a.rawBind image).norm := Ty.norm_rawBind image _

theorem substitution_association_result :
    (Ty.refined (.refined (.tvar 0) p) q).bind image =
      .refined U (.and q (.and p q)) := rfl

theorem fn_dependent_equal :
    (Ty.dependentFn (Ty.toTel ["x"] [U] U Eff.empty)).norm =
      (Ty.fn ["x"] [U] U Eff.empty).norm :=
  Ty.norm_toTel ⟨rfl, by simp⟩

theorem fn_dependent_chain {Γ Φ} :
    Ty.LeQ Γ Φ (.refined (.dependentFn (Ty.toTel ["x"] [U] U Eff.empty)) .truth)
      (.fn ["x"] [U] U Eff.empty) :=
  .trans .forget (.convert fn_dependent_equal)

theorem function_extract_after_conversion {Γ Φ} :
    ∃ t, (Ty.fn ["x"] [U] U Eff.empty).fnCore = some t ∧
      TelClosure Γ Φ (Ty.toTel ["x"] [U] U Eff.empty) t :=
  fn_dependent_chain.fnCore rfl

theorem reference_true_equal {Γ Φ} :
    Ty.LeQ Γ Φ (.reference (.refined U .truth)) (.reference U) := .convert rfl

theorem reference_extract_after_conversion {Γ : Ctx} {Φ : List Pred} :
    ∃ b, (Ty.reference U).refCore = some b ∧ (Ty.refined U .truth).norm = b.norm :=
  (reference_true_equal (Γ := Γ) (Φ := Φ)).refCore rfl

theorem fail_true_equal :
    (Eff.singleFail (.refined U .truth)).memFail U :=
  (Eff.memFail_single_iff _ _).mpr rfl

theorem reference_covariance_rejected {Γ Φ} :
    ¬ Ty.LeQ Γ Φ (.reference (.refined U .falsity)) (.reference U) := by
  intro h
  obtain ⟨b, hb, he⟩ := h.refCore rfl
  cases hb
  cases he

theorem fail_covariance_rejected : ¬ (Eff.singleFail U).memFail (.refined U .falsity) := by
  rw [Eff.memFail_single_iff]
  intro he; cases he

theorem function_names_change_rejected {Γ Φ} :
    ¬ Ty.LeQ Γ Φ (.fn ["x"] [U] U Eff.empty) (.fn ["y"] [U] U Eff.empty) := by
  intro h
  have he := h.names_eq rfl rfl
  simp [Ty.toTel, Tel.names] at he

end Benitoite.Release.Refinement.NormalizationBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".NormalizationBoundary.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
