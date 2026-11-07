import Benitoite.Release.Refinement.Surface.ScopeRules

/-!
# リテラルの要求が既知にする範囲の整形式

設計書 01-12「Scope の局所解析の状態と規則の表」に対応する。`Http.checkRequestIn` のホストのパターンと最小・最大の
ポートがリテラルのとき、局所解析が既知にする範囲は、ポートの区間が整形式（`PortRange.WF`。最小 ≤ 最大）の
エンドポイントの範囲である（`requestLitBound_known_ports_wf`）。最小が最大より大きい組は未知（Top）にする
（`requestLitBound_inverted_unknown`）。ホストのパターンの解析が整形式のパターンだけを返すなら、既知の範囲は整形式
（`Range.WF`）である（`requestLitBound_known_wf`）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeState

open Benitoite.Scope.Inference
open Benitoite.Scope.Domain (Range)

/-- リテラルによる読み取りが既知にする範囲は、ポートの区間が整形式のエンドポイントの範囲である。 -/
theorem requestLitBound_known_ports_wf {hostPattern : String → Option Scope.Domain.HostPattern}
    {aargs : List AbsArg} {r : Range} (hb : requestLitBound hostPattern aargs = .known r) :
    ∃ e : Scope.Domain.EndpointPattern, r = .endpoint e ∧ e.ports.WF := by
  unfold requestLitBound at hb
  split at hb
  · split at hb
    · split at hb
      · split at hb
        · next h => cases hb; exact ⟨_, rfl, h⟩
        · cases hb
      · cases hb
    · cases hb
  · cases hb

/-- ホストのパターンの解析が整形式のパターンだけを返すなら、リテラルによる読み取りが既知にする範囲は整形式である。 -/
theorem requestLitBound_known_wf {hostPattern : String → Option Scope.Domain.HostPattern}
    (hhost : ∀ s h, hostPattern s = some h → h.WF) {aargs : List AbsArg} {r : Range}
    (hb : requestLitBound hostPattern aargs = .known r) : r.WF := by
  unfold requestLitBound at hb
  split at hb
  · split at hb
    · split at hb
      · next eh _ _ =>
        split at hb
        · next h => cases hb; exact ⟨hhost _ _ eh, h⟩
        · cases hb
      · cases hb
    · cases hb
  · cases hb

/-- 最小が最大より大きいリテラルの組は、ホストのパターンによらず未知にする。 -/
theorem requestLitBound_inverted_unknown {hostPattern : String → Option Scope.Domain.HostPattern}
    {hs ls us : String} {lo hi : Int} {l u : Scope.Domain.Port} {a : AbsArg}
    (hh : litInt? hs = none) (hl : litInt? ls = some lo) (hu : litInt? us = some hi)
    (pl : Scope.Domain.Port.ofInt? lo = some l) (pu : Scope.Domain.Port.ofInt? hi = some u)
    (hlt : ¬ (⟨l, u⟩ : Scope.Domain.PortRange).WF) :
    requestLitBound hostPattern [.lit hs, .lit ls, .lit us, a] = .unknown := by
  simp only [requestLitBound, hh, hl, hu, pl, pu]
  cases hostPattern hs <;> simp [hlt]

end Benitoite.Release.Refinement.Surface.ScopeState
