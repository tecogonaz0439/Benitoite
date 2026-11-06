import Init

/-! 推論が拒否した理由と、計算を打ち切った段を表す有限のデータ。 -/
namespace Benitoite.Release.Refinement.Surface.CheckInfer

/-- 計算を打ち切った段を保持する。 -/
inductive StopReason where
  | structural
  | handlerIteration
  deriving Repr, DecidableEq

def StopReason.message : StopReason → String
  | .structural => "structural inference bound exhausted"
  | .handlerIteration => "handler effect iteration exhausted its bound"

/-- 拒否には理由を、打ち切りには実際に打ち切った段を保持する。 -/
inductive Failure where
  | rejected (path : List Nat) (reason : String)
  | stopped (path : List Nat) (reason : StopReason)
  deriving Repr, DecidableEq

end Benitoite.Release.Refinement.Surface.CheckInfer
