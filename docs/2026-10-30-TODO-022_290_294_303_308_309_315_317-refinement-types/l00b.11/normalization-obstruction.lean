import Lean
import Benitoite.Release.Refinement.InversionCore

/-!
正規化の移行で維持できない言明と、単純な平坦化の置換に対する反例。
本番の正規化を定義するファイルではない。新しい公理は宣言しない。
-/
namespace Benitoite.Release.Refinement.NormalizationObstruction

theorem true_erasure_not_fixedPoint
    (N : Ty → Ty) (htrue : ∀ a, N (.refined a .truth) = N a)
    (hu : N (.base .unit) = .base .unit) :
    ∃ a, a.WF 0 0 0 ∧ N a ≠ a := by
  refine ⟨.refined (.base .unit) .truth, ⟨trivial, trivial, ?_⟩, ?_⟩
  · simp [Ty.NotContCore, Ty.core]
  · rw [htrue, hu]
    intro h
    cases h

theorem rawApply_norm_unrestricted (t : Ty) (as : List Ty) :
    (rawApply t.norm (Ty.normTys as)).norm = (rawApply t as).norm :=
  rawApply_norm t as

private def addRefinement (a : Ty) (p : Pred) : Ty :=
  match p, a with
  | .truth, _ => a
  | p, .refined b q => .refined b (.and q p)
  | p, a => .refined a p

private def naive : Ty → Ty
  | .refined a p => addRefinement (naive a) p
  | a => a

private def image : SubstEnv :=
  ⟨fun _ => .refined (.base .unit) .falsity, [], [], fun i => some (.var i)⟩

theorem naive_flattening_breaks_substitution :
    let a := Ty.refined (.refined (.tvar 0) .falsity) .falsity
    naive (Ty.rawBind image (naive a)) ≠ naive (Ty.rawBind image a) := by
  dsimp only
  intro h
  cases h

theorem current_fn_bridge {Γ Φ ns ps r e} (hn : NamesWF ns ps) :
    Ty.LeQ Γ Φ (.dependentFn (Ty.toTel ns ps r e)) (.fn ns ps r e) :=
  .convert (Ty.norm_toTel hn)

theorem actual_wf_fixedPoint_false :
    ¬ (∀ a : Ty, a.WF 0 0 0 → a.norm = a) := by
  intro h
  have he := h (.refined (.base .unit) .truth)
    ⟨trivial, trivial, by simp [Ty.NotContCore]⟩
  change Ty.base .unit = Ty.refined (.base .unit) .truth at he
  cases he

theorem canonical_flattening_commutes_with_substitution :
    let a := Ty.refined (.refined (.tvar 0) .falsity) .falsity
    (Ty.rawBind image a.norm).norm = (Ty.rawBind image a).norm :=
  Ty.norm_rawBind image _

end Benitoite.Release.Refinement.NormalizationObstruction

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".NormalizationObstruction.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
