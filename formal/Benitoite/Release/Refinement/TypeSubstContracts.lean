import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.CaptureRegularity

/-! 型・行の閉じた像の入力。型付けの保存の結論を入力欄には含めない。 -/
namespace Benitoite.Release.Refinement

structure ClosedTypeSubstInput (P : Program) (B : Builtins)
    (C0 C1 : TypeCtx) (Γ : Ctx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = C0.length
  typeWF : ∀ t ∈ ts, t.WF 0 0 0
  typeKinds : TypeArgsKinded P [] ts (TypeCtx.kinds C0)
  typeAnnotations : TypeAnnotations P [] [] ts
  constraints : SatAll B C1 ts (TypeCtx.constraints C0)
  rowWF : ∀ e ∈ es, e.WF 0 0 0
  rowAnnotations : RowAnnotations P [] [] es
  rowKinds : ∀ e ∈ es, kindsEff P [] e
  context : CaptureContextRegular P (C1 ++ C0) Γ

end Benitoite.Release.Refinement
