import Benitoite.Interval.BudgetWalk

/-!
# 独立した入力の忘却・保存・復帰の実行定義

解析本体を引数として受け取り、その定義と証明へ依存せずに入力の結果を保存する。
親の警告列と局所の事実を分け、予算・次キー・識別と入力の保存列を共有する。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 忘却した環境は子の解析中だけ一時保持する。記録のinitialは証明用であり、
Rustは環境の項目を保存しない。外側のindependentWithのscopeで成否とも返却する。 -/
def prepareIndependent (env : AbstractEnv) : Analysis AbstractEnv :=
  scan (BudgetScan.forgetEnv env)

/-- 保存枠を取得した後は、成功・停止とも入力の結果を保存して親へ復帰する。
結果の一記録を auxiliary 一項とし、候補は別に保存計上する。initialは証明用の欄であり保存項目に含めない。 -/
def captureIndependent (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) : Analysis Unit := fun limits parent =>
  let child := { parent with warningsRev := [], unsupported := false }
  let (prepared, ready) := prepareIndependent env limits child
  let (result, final) : Except Halt BaseApprox × Context := match prepared with
    | .error reason => (.error reason, ready)
    | .ok initial => work initial limits ready
  let entry : IndependentResult :=
    ⟨input, parent.next, prepared.toOption, result, final.warningsRev, final.unsupported⟩
  (result.map (fun _ => ()), { final with
    warningsRev := parent.warningsRev
    unsupported := parent.unsupported
    independentRev := entry :: final.independentRev })

/-- 保存に必要な枠は解析前に確保し、途中停止後に確保し直さない。 -/
def independentWith (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) : Analysis Unit := scope fun _ => do
  scan (BudgetScan.allocate .auxiliary .saved)
  captureIndependent input env work

end Benitoite.Interval.BudgetAnalysis
