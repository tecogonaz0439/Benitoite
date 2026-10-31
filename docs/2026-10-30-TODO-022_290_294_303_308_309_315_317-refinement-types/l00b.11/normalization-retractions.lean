import Lean
import Benitoite.Release.Refinement.LocalTransport
import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.ClosureTyping

namespace Benitoite.Release.Refinement.NormalizationRetractions
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth

theorem raw_wf : raw.WF 0 0 0 := ⟨trivial, trivial, by simp [Ty.NotContCore]⟩
theorem raw_not_normal : ¬ raw.Normal := by intro h; cases h

theorem closed_value_subst_not_raw : substTyValues Val.var raw ≠ raw := by
  intro he; cases he

theorem closed_builder_wf : LocTy.WF (.builder (.list raw)) := raw_wf

theorem closed_builder_subst_not_raw :
    substKind Val.var (.list raw) ≠ BuilderKind.list raw := by
  intro he; cases he

theorem raw_renameTypes_not_raw_shift :
    raw.renameTypes (shiftIndex 1 0) ≠ shiftTypes 1 0 raw := by
  intro he; cases he

theorem instantiatedTel_raw_equality_false :
    substTyValues Val.var (.dependentFn (instantiatedTel (.done U Eff.empty) [] [])) ≠
      Ty.dependentFn (instantiatedTel (.done U Eff.empty) [] []) := by
  have he : instantiatedTel (.done U Eff.empty) [] [] = .done U Eff.empty := by
    simp [instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, U,
      Eff.rawBind, Eff.norm, Eff.empty, typeEnvAt, rowFails, rawBindTys,
      instAtoms_nil, substAtoms_nil, Ty.normTys]
  rw [he]
  simp only [substTyValues, Ty.bind, Ty.rawBind, Tel.rawBind, valEnv, Ty.norm]
  simp only [Eff.rawBind, valEnv, instAtoms_nil, substAtoms_nil, rowFails,
    List.length_nil, List.range_zero, List.filter_nil, List.flatMap_nil, rawBindTys,
    List.nil_append, Eff.norm, Ty.normTys, U, Ty.rawBind, Ty.norm, Eff.empty,
    Order.sortUnique]
  change (Ty.dependentFn (.done U Eff.empty)).norm ≠ Ty.dependentFn (.done U Eff.empty)
  rw [show (Ty.dependentFn (.done U Eff.empty)).norm = Ty.fn [] [] U Eff.empty from
    Ty.norm_toTel (ns := []) (ps := []) (r := U) (e := Eff.empty) ⟨rfl, List.nodup_nil⟩]
  intro he; cases he

theorem done_annotation (P : Program) :
    Ty.Annotation P [] [] (.dependentFn (.done raw Eff.empty)) := by
  exact ⟨⟨raw_wf, trivial, rfl⟩, ⟨⟨trivial, trivial⟩, trivial⟩,
    ⟨⟨trivial, trivial⟩, trivial⟩⟩

theorem done_typed (P : Program) (B : Builtins) :
    HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] []
      (.done raw Eff.empty) raw Eff.empty := .done (done_annotation P)

theorem tel_normal_without_premise_false (P : Program) (B : Builtins) :
    HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] []
      (.done raw Eff.empty) raw Eff.empty ∧ ¬ (raw.norm = raw ∧ Eff.empty.norm = Eff.empty) :=
  ⟨done_typed P B, fun h => raw_not_normal h.1⟩

theorem tel_instantiate_raw_result_false :
    Tel.instantiate (.done raw Eff.empty) [] ≠ some (raw, Eff.empty) := by
  simp only [Tel.instantiate]
  rw [Ty.norm_refined_truth]
  change some (U, Eff.empty) ≠ some (raw, Eff.empty)
  intro he; cases he

theorem tel_arguments_raw_result_false :
    Tel.arguments (.done raw Eff.empty) [] ≠ some ([], raw, Eff.empty) := by
  simp only [Tel.arguments]
  rw [Ty.norm_refined_truth]
  change some ([], U, Eff.empty) ≠ some ([], raw, Eff.empty)
  intro he; cases he

/-- 終端の生の結果と Tel.arguments の正規化した結果は一致しない。 -/
theorem of_arguments_without_normal_false (P : Program) (B : Builtins) :
    Tel.arguments (.done raw Eff.empty) [] = some ([],U,Eff.empty) ∧
    HasTypeVsQ P B StoreTy.empty Qempty [] [] [] [] [] ∧
    Ty.Annotation P [] [] (.dependentFn (.done raw Eff.empty)) ∧
    ¬ HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] []
      (.done raw Eff.empty) U Eff.empty := by
  refine ⟨?_,.nil,done_annotation P,?_⟩
  · simp [Tel.arguments,raw,U,Ty.norm,Ty.refineNorm,Ty.core,Ty.refinementPredicates,
      Ty.packRefinements,Pred.conjuncts,Eff.norm,Eff.empty,Ty.normTys,Order.sortUnique]
  · intro h
    cases h

theorem closed_tel_bind_not_raw :
    Tel.bind (valEnv Val.var) (.done raw Eff.empty) ≠ Tel.done raw Eff.empty := by
  intro he
  have hr := (Tel.done.inj he).1
  cases hr

theorem closure_result_normal {P B Ψ ps R q a e} (h : ClosureTy P B Ψ ps R q a e) : a.Normal := by
  cases h
  exact Ty.norm_idem _

theorem raw_result_typed (P : Program) (B : Builtins) :
    HasTypeC P B StoreTy.empty [] [] [] none (.ret (.const .unit)) raw Eff.empty := by
  apply HasTypeCQ.C_Return
  exact .V_Sub (.V_Const trivial) (.introduce trivial .truth) raw_wf
    ⟨trivial,trivial⟩ ⟨trivial,trivial⟩

/-- 旧 ClosureTy.pure は WF と Annotation だけから生の結果を要求していた。 -/
theorem pure_without_normal_false (P : Program) (B : Builtins) :
    HasTypeC P B StoreTy.empty [] [] [] none (.ret (.const .unit)) raw Eff.empty ∧
    Ty.Annotation P [] [] (.dependentFn (.done raw Eff.empty)) ∧
    ¬ ClosureTy P B StoreTy.empty [] none (Closure.pure (.ret (.const .unit))) raw Eff.empty :=
  ⟨raw_result_typed P B, done_annotation P, fun h => raw_not_normal (closure_result_normal h)⟩

theorem close_return_normal {cap : Capture} {n : Nat} {R : Option Ty} {r : Ty}
    (h : cap.closeRAt n R = some r) : r.Normal := by
  cases R with
  | none => cases h
  | some a =>
    have he : substTyValues (upSubst n cap.env) a = r := Option.some.inj h
    rw [←he]
    exact substTyValues_normal _ _

theorem closure_return_normal {P B Ψ ps R q a e} (h : ClosureTy P B Ψ ps R q a e) :
    ∀ r, R = some r → r.Normal := by
  cases h with
  | mk hc hb hl he hss hcs hR ha hae hdr hdc =>
    intro r hr
    exact close_return_normal (hR.trans hr)

theorem pure_without_return_normal_false (P : Program) (B : Builtins) :
    HasTypeC P B StoreTy.empty [] [] [] (some raw) (.ret (.const .unit)) U Eff.empty ∧
    Ty.Annotation P [] [] (.dependentFn (.done U Eff.empty)) ∧
    (∀ r, (some raw : Option Ty) = some r → r.WF 0 0 0 ∧ r.Declared P [] []) ∧
    ¬ ClosureTy P B StoreTy.empty [] (some raw) (Closure.pure (.ret (.const .unit))) U Eff.empty := by
  refine ⟨.C_Return (.V_Const trivial),⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩,?_,?_⟩
  · intro r hr
    cases Option.some.inj hr
    exact ⟨raw_wf,⟨trivial,trivial⟩⟩
  · intro h
    exact raw_not_normal (closure_return_normal h raw rfl)

theorem continuation_raw_components_differ :
    (Ty.cont U raw Eff.empty).norm = (Ty.cont U U Eff.empty).norm ∧
    Ty.cont U raw Eff.empty ≠ Ty.cont U U Eff.empty := by
  constructor
  · exact congrArg (fun t => Ty.cont U.norm t Eff.empty.norm) (Ty.norm_refined_truth U)
  · intro he; cases he

end
end Benitoite.Release.Refinement.NormalizationRetractions

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".NormalizationRetractions.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
