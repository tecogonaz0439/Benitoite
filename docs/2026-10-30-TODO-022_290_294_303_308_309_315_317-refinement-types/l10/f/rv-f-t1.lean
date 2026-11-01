import Benitoite
/-! 捕捉の継続は WF を持たず、旧の網羅性は範囲変数の不透明型で新の網羅性へ移らない。 -/
namespace RVLTenF
open Benitoite.Release.Refinement

/-- 捕捉の整形式は継続の行を読まないので、WF にならない継続の型を通す。 -/
def k0 : Ty := .cont (.base .unit) (.base .unit) (.mk (fun _ => false) [.tvar 0])

theorem capture_accepts : k0.CaptureWF 0 0 0 := by
  simp [k0, Ty.CaptureWF, Ty.WF]

theorem not_wf : ¬ k0.WF 0 0 0 := by
  simp [k0, Ty.WF, Eff.WF, Ty.WFList]

/-- 文脈全体でも同じ。Ty.bind_wf の入力の WF を CaptureWF から得られない。 -/
theorem ctx_capture : Ctx.CaptureWF 0 0 [some k0] := by
  intro i a h
  cases i with
  | zero =>
    simp at h
    subst h
    simp [k0, Ty.CaptureWF, Ty.WF]
  | succ i => simp at h

end RVLTenF

#print axioms RVLTenF.not_wf
