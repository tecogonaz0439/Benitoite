import Benitoite.Release.Refinement.SafeCheckPreservation
import Benitoite.Release.Refinement.SafeCheckErasureExamples

/-! # 外部宣言を保持した表層プログラムでの型保存の適用 -/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open RefinementCheck CheckErasure StandardModel

/-- 標準本体と外部宣言を含む表層の main に、全プログラムの型保存を適用する。 -/
example :
    let P := Surface.MainExamples.linked positiveExternals
    let B := (Surface.MainExamples.input positiveExternals).B
    (eraseProgram P).WellFormed ∧ (eraseProgram P).WellTyped B := by
  let T := Surface.MainExamples.data positiveExternals
  let I := Surface.MainExamples.includes positiveExternals
  have hc := ApplicationExamples.noAssumptions_completion nameLists_wf T
  have hcore := (completion_core nameLists positiveExternals nameLists_wf _ T _ I hc).1
  have hadd := Surface.link_additions _ (Surface.MainExamples.wellFormed _ positive_wf)
    (Surface.MainExamples.checked positiveExternals)
    (Surface.link_realizes _ (Surface.MainExamples.wellFormed _ positive_wf) closedView) hcore.values
  have premise := included_premises nameLists_wf T I hc positive_wf hadd
  have env := RowEnv.ofAgree nameLists_wf T I (complete_agree nameLists T ApplicationExamples.noAssumptions)
  exact program_preservation premise.1 premise.2.1 env.check (Agreement.complete nameLists_wf T _).signature

/-- let の中の成功した検査を含む計算も、同じ完成した表で同じ型と効果を持つ。 -/
example :
    let P := Surface.MainExamples.linked positiveExternals
    let B := (Surface.MainExamples.input positiveExternals).B
    HasTypeCQ (eraseProgram P) B StoreTy.empty Qempty [] [] [] none
      (erase checkedBody) (.base .unit) Eff.empty [] := by
  let T := Surface.MainExamples.data positiveExternals
  let I := Surface.MainExamples.includes positiveExternals
  have env := RowEnv.ofAgree nameLists_wf T I (complete_agree nameLists T ApplicationExamples.noAssumptions)
  have ann : Ty.Annotation (Surface.MainExamples.linked positiveExternals) [] [] nonnegative := by
    constructor
    · exact successfulSite.expectedWF
    · simp [nonnegative,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,
        Ctx.Readable,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
    · simp [nonnegative,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ctx.extend,Ty.shiftV,Ordinary]
  have args := RefinementCheck.arguments (B := (Surface.MainExamples.input positiveExternals).B)
    (Ψ := StoreTy.empty) env.check (t := .base .integer) (u := nonnegative)
    ⟨trivial,trivial,trivial⟩ ann trivial
    (by simp [nonnegative,Ty.HasKind,Ty.NotContCore,Ty.core])
    (by intro b t e h; cases h) (by intro b t e h; cases h) rfl rfl ⟨_,rfl⟩
    (v := successfulValue) (.V_Const trivial) trivial
  have callTyped := CheckErasure.call_typed (R := none) (Δ := [])
    (Agreement.complete nameLists_wf T _).signature args
  have bodyTyped : HasTypeCQ (Surface.MainExamples.linked positiveExternals)
      (Surface.MainExamples.input positiveExternals).B StoreTy.empty Qempty [] [] [] none
      checkedBody (.base .unit) Eff.empty [] :=
    .C_Let callTyped (.C_Return (.V_Const trivial)) trivial
  exact computation_preservation bodyTyped env.check (Agreement.complete nameLists_wf T _).signature

end
end Benitoite.Release.Refinement.SafeCheckErasure
