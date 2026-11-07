import Benitoite.Release.Refinement.Surface.ScopeConnectionExamples

/-!
# 要求の検査の接続定理の成功の場合の具体例

`Http.checkRequestIn` の本番の δ（`ModelHttp.builtins`）が `Result.Ok` を返す具体の入力（ホストのパターン
`127.0.0.1`、ポート 443、要求 `GET https://127.0.0.1/`）で、接続定理の前提の δ の成功と成功値を満たし、
結論の検査済みの要求の値が実際の成功値について成り立つことを示す（設計書 01-12「Scope の局所解析の接続定理」）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeConnectionExamples

open Benitoite.Scope.Inference
open ScopeState ScopeLower ScopeAccept ScopeSound
open Benitoite.Scope.Domain (Range Target)

noncomputable section

/-- 範囲 Top の要求の検査が成功する入力について、δ の成功値は渡された要求を保持する検査済みの要求の値であり、
その実効の endpoint は受理した契約に属する。 -/
theorem request_connection_ok :
    ∃ pattern lo hi req v w, deltaRun ModelHttp.builtins checkRequestName [.top] [pattern, lo, hi, req] = some v ∧
      okPayload "Result.Ok" v = some w ∧
      ∃ R t req', w = .checkedRequest (.endpoint t) req' ∧ req' = req ∧ req'.reqTarget = some (.endpoint t) ∧
        R.Mem (.endpoint t) ∧ ∃ S, [Range.top][0]? = some S ∧ S.Covers R ∧ S.Mem (.endpoint t) := by
  obtain ⟨pattern, port, req, endpoint, hrun, -, -⟩ := RequestDelta.run_top_ok
  have hd : deltaRun ModelHttp.builtins checkRequestName [.top]
      [.const (.string pattern), .const (.integer port), .const (.integer port), req] =
      some (ScopeDelta.resultValue true (.opaque "Http.RequestIn" (.fixed (.absolute .top)))
        ScopeSignatures.requestCheckErrorTy (.checkedRequest (.endpoint endpoint) req)) := by
    simp only [deltaRun, ModelHttp.builtins, ScopeSignatures.builtins, ScopeResponse.delta, RequestDelta.delta,
      checkRequestName, List.map_cons, List.map_nil, true_and, ↓reduceIte]
    rw [ite_eq_right (by decide)]
    simp [hrun, RequestDelta.ok]
  have hw : okPayload "Result.Ok" (ScopeDelta.resultValue true (.opaque "Http.RequestIn" (.fixed (.absolute .top)))
      ScopeSignatures.requestCheckErrorTy (.checkedRequest (.endpoint endpoint) req)) =
      some (.checkedRequest (.endpoint endpoint) req) := by
    simp [okPayload, ScopeDelta.resultValue]
  obtain ⟨R, t, req', he, hreq, hm, S, hS, hcov, hSm⟩ := request_connection _ _ _ _ .top _ _ hd hw
  cases he
  exact ⟨_, _, _, _, _, _, hd, hw, R, _, _, rfl, rfl, hreq, hm, S, hS, hcov, hSm⟩

end
end Benitoite.Release.Refinement.Surface.ScopeConnectionExamples
