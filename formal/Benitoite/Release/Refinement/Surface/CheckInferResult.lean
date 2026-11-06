import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.CheckInferFailure

/-! 推論の拒否と打ち切りを分け、公開の診断へ射影する。 -/
namespace Benitoite.Release.Refinement.Surface.CheckInfer

/-- 成功・拒否・打ち切りを、再帰と各段の結合を通じて保持する結果。 -/
abbrev Result (α : Type) := Except Failure α

/-- 公開入口のunknownは、内部の打ち切りだけから作る。 -/
def Failure.toError : Failure → Check.Error
  | .rejected path reason => ⟨path, reason, .rejected⟩
  | .stopped path reason => ⟨path, reason.message, .unknown⟩

/-- 公開の診断へ変換しても、成功した値は変えない。 -/
def Result.toCheck (result : Result α) : Check.Result α :=
  result.mapError Failure.toError

/-- unknownという公開の種類には、内部の打ち切りの証人がある。 -/
theorem Failure.toError_unknown {failure : Failure}
    (h : failure.toError.kind = .unknown) :
    ∃ path reason, failure = .stopped path reason := by
  cases failure with
  | rejected path reason => cases h
  | stopped path reason => exact ⟨path,reason,rfl⟩

/-- 結果の射影がunknownなら、その入力は停止した結果である。 -/
theorem Result.toCheck_unknown {result : Result α} {error : Check.Error}
    (h : result.toCheck = .error error) (hu : error.kind = .unknown) :
    ∃ path reason, result = .error (.stopped path reason) := by
  cases result with
  | ok value => cases h
  | error failure =>
      cases h
      obtain ⟨path,reason,rfl⟩ := Failure.toError_unknown hu
      exact ⟨path,reason,rfl⟩

/-- 成功は同じ値を保持し、エラーから成功への変換を行わない。 -/
theorem Result.toCheck_ok {result : Result α} {value : α} :
    result.toCheck = .ok value ↔ result = .ok value := by
  cases result <;> simp [Result.toCheck, Except.mapError]

end Benitoite.Release.Refinement.Surface.CheckInfer
