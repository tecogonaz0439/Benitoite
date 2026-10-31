import Lean
import Benitoite.Release.Refinement.Kinds
import Benitoite.Release.Refinement.BindCongr
/-! 篩の下への rawApply により、無制限の像の正規化が交換する。 -/
namespace Benitoite.Release.Refinement.L00b11ContractCounter
open Benitoite.Release.Refinement
abbrev arg : Ty := .refined (.tvar 0) .truth
abbrev source : Ty := .tapp 0 [.base .unit]
theorem source_wf : source.WF 0 1 0 := by simp [source, Ty.WF, Ty.WFList]
theorem image_value_kind {P : Program} : arg.HasKind P [.value] .value := by
  simp [arg, Ty.HasKind, Ty.NotContCore]
theorem substitute_then_normalize : (source.subst [arg] []).norm = .tapp 0 [.base .unit] := by
  simp [source, arg, Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt,
    rawBindTys, rawApply, shiftTypes_zero, Ty.norm, Ty.refineNorm,
    Ty.packRefinements, Ty.refinementPredicates, Pred.conjuncts]
theorem normalize_then_substitute : source.subst [arg.norm] [] = .tapp 0 [.base .unit] := by
  simp [source, arg, Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt,
    rawBindTys, rawApply, shiftTypes_zero, Ty.norm, Ty.refineNorm,
    Ty.packRefinements, Ty.refinementPredicates, Pred.conjuncts, Ty.normTys]
theorem unrestricted_image_normalization (a : Ty) (ts : List Ty) :
    a.subst (Ty.normTys ts) [] = a.subst ts [] := Ty.subst_norm_images a ts

theorem proper_constructor_unchanged (a : Ty) : rawApply (.ctor .list) [a] = .list a := rfl

theorem refined_head_keeps_arguments :
    rawApply arg [.base .unit] = .refined (.tapp 0 [.base .unit]) .truth := rfl

end Benitoite.Release.Refinement.L00b11ContractCounter

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".L00b11ContractCounter.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
