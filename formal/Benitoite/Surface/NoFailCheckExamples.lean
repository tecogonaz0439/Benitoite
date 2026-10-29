import Benitoite.Surface.NoFailCheck

/-! 署名の Q と、行の像を検査する境界の受理・拒否例。 -/
namespace Benitoite.Surface.NoFailCheckExamples
open Benitoite.Release Benitoite.Surface.CheckTools

private def intTy : Ty := .base .integer
private def stringTy : Ty := .base .string
private def unitTy : Ty := .base .unit
private def failInt : Eff := .mk (fun _ => false) [intTy]
private def failString : Eff := .mk (fun _ => false) [stringTy]
private def failAndRow : Eff := .mk (· == .rho 0) [intTy]
private def rowOnly : Eff := .mk (· == .rho 0) []

/-- 明示の Fail と並ぶ行を、引数・結果・Fail のエラー型の内部まで走査する。
明示の Fail のない通常の行は Q に加えない。 -/
example :
    [signatureQ 2 [.fn [] [] unitTy failAndRow] unitTy Eff.empty,
     signatureQ 2 [] (.fn [] [] unitTy failAndRow) Eff.empty,
     signatureQ 2 [] unitTy (.mk (fun _ => false) [.fn [] [] unitTy failAndRow]),
     signatureQ 2 [] unitTy rowOnly] =
      [[true, false], [true, false], [true, false], [false, false]] := by
  rfl

/-- 印付きの行への異型 Fail・未供給の像・未承認の caller 行を拒否する。
State・caller が印を持つ行・印のない通常の多相な行は受理する。 -/
example :
    [rowTransportCheck [.rho 0] [true] [] [failString],
     rowTransportCheck [] [true] [] [],
     rowTransportCheck [.rho 0] [true] [] [rowOnly],
     rowTransportCheck [.nameTop stateEff] [true] [] [Eff.single stateEff],
     rowTransportCheck [.rho 0] [true] [true] [rowOnly],
     rowTransportCheck [] [false] [] [failInt]] =
      [false, false, false, true, true, true] := by
  rfl

/-- 型付きの条件でも、Fail と並ぶ行への別型の Fail を排除する。 -/
example : ¬ RowTransport (Qsig [] unitTy failAndRow) Qempty [failString] := by
  intro h
  have hq : Qsig [] unitTy failAndRow 0 := by
    exact Or.inr (Or.inr (Or.inl ⟨by decide, by decide⟩))
  have hf := h 0 hq
  have hm : Eff.memFail (Eff.rowImage [failString] 0) stringTy := by
    exact ⟨stringTy, List.mem_cons_self, rfl⟩
  exact hf.not_memFail stringTy hm

/-- NoFail は最外の条件であり、名前の種類や内部の Fail 型の比較は不要である。 -/
example : NoFail Qempty (Eff.single stateEff) := by
  refine ⟨rfl, ?_⟩
  intro i hi
  have he := (Eff.mem_single _ _).mp hi
  cases he

end Benitoite.Surface.NoFailCheckExamples
