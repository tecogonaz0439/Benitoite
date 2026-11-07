import Benitoite.Release.Refinement.Surface.ScopeNumbering
import Benitoite.Release.Refinement.Surface.ScopeLitBound
import Benitoite.Release.Refinement.Surface.CheckAcceptBase
import Benitoite.Release.Refinement.ScopeWiden

/-!
# 局所解析の番号・リテラルの要求・明示拡大の適用例

本体の入口の束縛番号（`CheckAccept.entryScope n`）から始めた局所解析の記録は、どの本体でも束縛番号の新規性を満たす。
最小が最大より大きいリテラルのポートの組は未知になり、既知の範囲はポートの区間が整形式の endpoint の範囲である。
`/data/a.txt` から `/data/**` への明示拡大の範囲の列は引数の型と戻り値の注釈から決まり、行き先は結果型から一意に
決まる（設計書 01-12「Scope の局所解析の接続定理」「Scope の局所解析の状態と規則の表」）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeFactExamples

open Benitoite.Scope.Inference
open ScopeState ScopeLower
open Benitoite.Scope.Domain (Range)

/-- 入口の束縛番号は新規性の不変条件を満たす。 -/
theorem entryScope_numbered (n : Nat) : WellNumbered (CheckAccept.entryScope n) :=
  ⟨fun _ h => List.mem_range.mp h, List.nodup_range⟩

/-- 入口の束縛番号から始めた本体の解析の記録は、全て新規性の不変条件を満たす。 -/
theorem body_records_numbered (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key) (n : Nat)
    (body : Block) : AllNumbered (analyzeBody ok T L key (CheckAccept.entryScope n) body).2 :=
  analyzeBody_numbered key (entryScope_numbered n) body

/-- 最小 443 が最大 80 より大きいリテラルの組は未知になる。 -/
theorem inverted_ports_unknown (host : String → Option Scope.Domain.HostPattern) (a : AbsArg) :
    requestLitBound host [.lit "example.com", .lit "\u0000443", .lit "\u000080", a] = .unknown :=
  requestLitBound_inverted_unknown (lo := 443) (hi := 80) (l := ⟨443, by decide⟩) (u := ⟨80, by decide⟩)
    (by decide) (by cbv) (by cbv) (by decide) (by decide) (by decide)

/-- リテラルの要求が既知にする範囲は、整形式のポートの区間を持つ endpoint の範囲で、ホストのパターンの解析が
整形式なら範囲も整形式である。 -/
theorem known_request_bound {host : String → Option Scope.Domain.HostPattern}
    (hhost : ∀ s h, host s = some h → h.WF) {aargs : List AbsArg} {r : Range}
    (hb : requestLitBound host aargs = .known r) :
    (∃ e : Scope.Domain.EndpointPattern, r = .endpoint e ∧ e.ports.WF) ∧ r.WF :=
  ⟨requestLitBound_known_ports_wf hb, requestLitBound_known_wf hhost hb⟩

private def exact : RangeExpr := .absolute (.path (.exact ["data", "a.txt"]))
private def tree : RangeExpr := .absolute (.path (.tree ["data"]))

/-- `PathIn["/data/a.txt"]` から `PathIn["/data/**"]` への明示拡大の範囲の列は [/data/a.txt, /data/**] であり、
同じ結果型を与える列は同じ行き先を持つ。 -/
theorem widen_data :
    ScopeWiden.widenRanges (.opaque "Scope.PathIn" (.fixed exact)) (.opaque "Scope.PathIn" (.fixed tree)) =
      some [exact, tree] ∧
    ∀ rs : List RangeExpr, rs.length = 2 →
      (instantiatedTel (Tel.instR rs ScopeSignatures.widenPathIn.tel) [] []).result =
        (instantiatedTel (Tel.instR [exact, tree] ScopeSignatures.widenPathIn.tel) [] []).result →
      rs[1]? = some tree := by
  refine ⟨(ScopeWiden.widenRanges_pathIn exact tree).1, fun rs hl h => ?_⟩
  have := ScopeWiden.widenPathIn_target_unique (rs' := [exact, tree]) hl rfl h
  simpa using this

end Benitoite.Release.Refinement.Surface.ScopeFactExamples
