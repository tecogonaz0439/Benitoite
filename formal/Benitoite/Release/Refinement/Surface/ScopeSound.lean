import Benitoite.Release.Refinement.Surface.ScopeRules
import Benitoite.Release.Refinement.ModelTargets
import Benitoite.Release.Refinement.ModelHttpConditions

/-!
# 本番の δ による Scope の必須の判定の規則の表

Scope の必須の判定の六つの項目を、篩付きの型の核の実例の表（`ModelTargets.builtins`・`ModelHttp.builtins`）の δ で
具体化し、その表の健全性を示す（設計書 01-12「Scope の局所解析の状態と規則の表」、07-04「証明する性質」）。

- 規則の実行: 実例の表の δ（`ScopeResponse.delta`）を、閉じた範囲の具体化（`RangeExpr.absolute`）で呼ぶ
  （`deltaRun`）。値を返す結果だけを値とし、誤り・終了は値なしとする。
- 動的なパターンと対象: 実行時の検査と同じ解析（`ScopeDelta.parsePattern`・`parseAtInput`・
  `RequestDelta.parseHostPattern`・`Val.reqTarget`）で読む。
- 型検査器の既知の範囲: 処理系の解析器が読んだ表（交換の入力）のうち、実行時の検査と同じ解析と一致する項目だけを
  使う（`agreed`）。一致しない項目は未知（Top）にする。
- 健全性（`productionRules_sound`）: δ の `Error` の構成子の名前と違う Ok の構成子の名前で、六つの項目はどれも
  健全である。表の条件はない。
-/

namespace Benitoite.Release.Refinement.Surface.ScopeSound

open Benitoite.Scope.Inference
open ScopeState
open Benitoite.Scope.Domain (Range Target)

/-! ## 本番の δ を規則の実行にする -/

/-- 本番の表 B の組み込みの関数 b の δ を、Scope の規則の実行（閉じた範囲の列と引数から値）にする。値を返す結果
だけを値とし、誤り・終了は値なしとする。 -/
def deltaRun (B : Builtins) (b : PrimName) : List Range → List Refinement.Val → Option Refinement.Val :=
  fun rs vs =>
    match B.delta b [] [] (rs.map .absolute) vs with
    | some (.val v) => some v
    | _ => none

theorem deltaRun_eq_some {B : Builtins} {b : PrimName} {rs : List Range} {vs : List Refinement.Val}
    {v : Refinement.Val} : deltaRun B b rs vs = some v ↔ B.delta b [] [] (rs.map .absolute) vs = some (.val v) := by
  unfold deltaRun
  constructor
  · intro h
    split at h
    · next v' hd => cases h; exact hd
    · cases h
  · intro h
    rw [h]

/-- 検査の δ の `Error` の値は、`Error` と違う名前の Ok の成功値を持たない。 -/
theorem okPayload_error {ok : ConName} (hne : ok ≠ "Result.Error") (a e : Ty) (x : Refinement.Val) :
    okPayload ok (ScopeDelta.resultValue false a e x) = none := by
  simp only [ScopeDelta.resultValue, okPayload, Bool.false_eq_true, ↓reduceIte]
  exact ite_eq_right (fun h => hne h.symm)

/-- 検査の δ の `Ok` の値の成功値は、保持した値である。 -/
theorem okPayload_ok {ok : ConName} {a e : Ty} {x w : Refinement.Val}
    (h : okPayload ok (ScopeDelta.resultValue true a e x) = some w) : w = x := by
  simp only [ScopeDelta.resultValue, okPayload, ↓reduceIte] at h
  split at h
  · cases h; rfl
  · cases h

/-! ## 実行時の検査と同じ解析 -/

/-- パスのパターンの文字列の解析（`Scope.checkPathIn` の実行時の検査と同じ解析）。 -/
def pathPattern (s : String) : Option Range := (ScopeDelta.parsePattern s).map .path

/-- 検査するパスの文字列の解析。絶対形のパスだけを対象にする。 -/
def pathTarget (s : String) : Option Target :=
  match parseAtInput .path (.const (.string s)) with
  | some (.absolute (.path w)) => some (.path w)
  | _ => none

/-- 要求の値の実効の endpoint。 -/
def reqEndpoint (v : Refinement.Val) : Option Scope.Domain.Endpoint :=
  match v.reqTarget with
  | some (.endpoint e) => some e
  | _ => none

/-- 処理系の解析器が読んだ表の項目のうち、形式化の解析 formal と同じ結果の項目だけを返す。 -/
def agreed {α : Type} [DecidableEq α] (table formal : String → Option α) (s : String) : Option α :=
  match table s with
  | some x => if formal s = some x then some x else none
  | none => none

theorem agreed_sound {α : Type} [DecidableEq α] {table formal : String → Option α} {s : String} {x : α}
    (h : agreed table formal s = some x) : formal s = some x := by
  unfold agreed at h
  split at h
  · split at h
    · next x' _ hf => cases h; exact hf
    · cases h
  · cases h

/-! ## 本番の検査の δ と Scope の契約 -/

private theorem makePath_ok {p : Scope.Domain.PathPattern} {t : Scope.Domain.Word} {c : Checked.Scope.CheckedPath}
    (h : Checked.Scope.makePath p t = .ok c) : p.Matches t := by
  unfold Checked.Scope.makePath at h
  split at h
  · split at h
    · split at h
      · assumption
      · cases h
    · cases h
  · cases h

/-- パスの検査の δ が `Ok` の成功値を返すのは、パターンと絶対形のパスが解析でき、パスがパターンと具体化した範囲の
両方に属するときだけであり、成功値はそのパスを持つ検査済みの対象の値である。 -/
theorem pathRun_ok {ok : ConName} (hne : ok ≠ "Result.Error") {r : Range} {vs : List Refinement.Val}
    {v w : Refinement.Val} (h : ScopeDelta.run (.absolute r) vs = .val v) (hw : okPayload ok v = some w) :
    ∃ pattern target p t, vs = [.const (.string pattern), .const (.string target)] ∧
      ScopeDelta.parsePattern pattern = some p ∧
      parseAtInput .path (.const (.string target)) = some (.absolute (.path t)) ∧
      p.Matches t ∧ r.Mem (.path t) ∧ w = .checked (.path t) := by
  unfold ScopeDelta.run at h
  split at h
  · next pattern target =>
    split at h
    · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
      rw [okPayload_error hne] at hw; cases hw
    · next p hp =>
      split at h
      · next t ht =>
        split at h
        · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
          rw [okPayload_error hne] at hw; cases hw
        · next c hc =>
          dsimp only at h
          split at h
          · simp only [ScopeDelta.ok, Outcome.val.injEq] at h
            next hm =>
            subst h
            exact ⟨pattern, target, p, t, rfl, hp, ht, makePath_ok hc, hm.2, okPayload_ok hw⟩
          · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
            rw [okPayload_error hne] at hw; cases hw
      · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
        rw [okPayload_error hne] at hw; cases hw
      · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
        rw [okPayload_error hne] at hw; cases hw
      · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
        rw [okPayload_error hne] at hw; cases hw
  · simp only [ScopeDelta.error, Outcome.val.injEq] at h; subst h
    rw [okPayload_error hne] at hw; cases hw

/-- 実例の表 `ModelTargets.builtins` の `Scope.checkPathIn` の δ は、実行時と同じ解析で読むパスの検査の項目の契約を
満たす。 -/
theorem modelTargets_contract {ok : ConName} (hne : ok ≠ "Result.Error") (known : String → Option Range) :
    (pathCheck pathPattern pathTarget known).Contract ok (deltaRun ModelTargets.builtins checkPathName) := by
  intro rs vs v w hrun hw
  have hd := deltaRun_eq_some.mp hrun
  simp only [ModelTargets.builtins, ScopeSignatures.builtins, ScopeResponse.delta, ScopeDelta.delta,
    checkPathName, true_and, ↓reduceIte] at hd
  match rs, hd with
  | [r], hd =>
    simp only [List.map_cons, List.map_nil, Option.some.injEq] at hd
    obtain ⟨pattern, target, p, t, rfl, hp, ht, hm, hr, rfl⟩ := pathRun_ok hne hd hw
    exact ⟨r, .path p, .path t, rfl, by simp [pathCheck, pathPattern, hp],
      by simp [pathCheck, pathTarget, ht], rfl, rfl, hm, hr⟩
  | [], hd => simp at hd
  | _ :: _ :: _, hd => simp at hd

private theorem makeEndpoint_ok {p : Scope.Domain.HostPattern} {host : Scope.Domain.HostTarget} {lo hi port : Int}
    {c : Checked.Scope.CheckedEndpoint} (h : Checked.Scope.makeEndpoint p host lo hi port = .ok c) :
    Checked.Scope.PortBounds lo hi ∧ p.Matches host ∧ Checked.Scope.PortMatches lo hi port := by
  unfold Checked.Scope.makeEndpoint at h
  split at h
  · split at h
    · split at h
      · next hb =>
        split at h
        · split at h
          · next hm =>
            split at h
            · next hr => exact ⟨hb, hm, hr⟩
            · cases h
          · cases h
        · cases h
      · cases h
    · cases h
  · cases h

/-- 要求の検査の δ が `Ok` の成功値を返すのは、ホストのパターンが解析でき、要求の実効の endpoint がホストの
パターン・二つのポートの区間・具体化した範囲に属するときだけであり、成功値は渡された要求を保持する検査済みの要求の
値である。 -/
theorem requestRun_ok {ok : ConName} (hne : ok ≠ "Result.Error") {r : Range} {vs : List Refinement.Val}
    {v w : Refinement.Val} (h : RequestDelta.run (.absolute r) vs = .val v) (hw : okPayload ok v = some w) :
    ∃ pattern lo hi req endpoint p,
      vs = [.const (.string pattern), .const (.integer lo), .const (.integer hi), req] ∧
      req.reqTarget = some (.endpoint endpoint) ∧ RequestDelta.parseHostPattern pattern = some p ∧
      Checked.Scope.PortBounds lo.toInt hi.toInt ∧ p.Matches endpoint.host ∧
      lo.toInt ≤ (endpoint.port.val : Int) ∧ (endpoint.port.val : Int) ≤ hi.toInt ∧
      r.Mem (.endpoint endpoint) ∧ w = .checkedRequest (.endpoint endpoint) req := by
  unfold RequestDelta.run at h
  repeat' split at h
  all_goals first
    | (simp only [RequestDelta.error, Outcome.val.injEq] at h; subst h
       rw [okPayload_error hne] at hw; cases hw)
    | skip
  rename_i _ pattern lo hi req _ _ _ _ _ _ endpoint ht _ p hp _ _ hc _ bound hb hm
  cases hb
  simp only [RequestDelta.ok, Outcome.val.injEq] at h
  subst h
  obtain ⟨hbd, hmatch, hpm⟩ := makeEndpoint_ok hc
  -- ポートの比較は、言語の整数へ写したポートの値で行われる。
  have hpm' : lo.toInt ≤ (endpoint.port.val : Int) ∧ (endpoint.port.val : Int) ≤ hi.toInt := hpm
  exact ⟨pattern, lo, hi, req, endpoint, p, rfl, ht, hp, hbd, hmatch, hpm'.1, hpm'.2, hm.2, okPayload_ok hw⟩

/-- 実例の表 `ModelHttp.builtins` の `Http.checkRequestIn` の δ は、実行時と同じ解析で読む要求の検査の項目の契約を
満たす。成功値は渡された要求を保持する検査済みの要求の値であり、`Val.target?` が実効の endpoint を返す。 -/
theorem modelHttp_contract {ok : ConName} (hne : ok ≠ "Result.Error") (bound : List AbsArg → Bound) :
    (requestCheck RequestDelta.parseHostPattern reqEndpoint bound).Contract ok
      (deltaRun ModelHttp.builtins checkRequestName) := by
  intro rs vs v w hrun hw
  have hd := deltaRun_eq_some.mp hrun
  simp only [ModelHttp.builtins, ScopeSignatures.builtins, ScopeResponse.delta, RequestDelta.delta,
    checkRequestName, true_and, ↓reduceIte] at hd
  rw [ite_eq_right (by decide)] at hd
  match rs, hd with
  | [r], hd =>
    simp only [List.map_cons, List.map_nil, Option.some.injEq] at hd
    obtain ⟨pattern, lo, hi, req, endpoint, p, rfl, ht, hp, hbd, hm, hlo, hhi, hr, rfl⟩ := requestRun_ok hne hd hw
    obtain ⟨h0, hlh, h1⟩ := hbd
    cases el : Scope.Domain.Port.ofInt? lo.toInt with
    | none => simp [Scope.Domain.Port.ofInt?] at el; omega
    | some l =>
      cases eu : Scope.Domain.Port.ofInt? hi.toInt with
      | none => simp [Scope.Domain.Port.ofInt?] at eu; omega
      | some u =>
        have hl := Scope.Domain.Port.ofInt?_val el
        have hu := Scope.Domain.Port.ofInt?_val eu
        refine ⟨r, .endpoint ⟨p, ⟨l, u⟩⟩, .endpoint endpoint, rfl, ?_, ?_, rfl, rfl, ?_, hr⟩
        · simp [requestCheck, hp, el, eu]
        · simp [requestCheck, reqEndpoint, ht]
        · refine ⟨hm, ?_, ?_⟩
          · show l.val ≤ endpoint.port.val
            omega
          · show endpoint.port.val ≤ u.val
            omega
  | [], hd => simp at hd
  | _ :: _ :: _, hd => simp at hd

/-! ## 本番の六つの項目と健全性 -/

/-- 実例の表の δ を規則にした六つの項目。`pattern`・`host` は処理系の解析器がリテラルのパスのパターンとホストの
パターンを読んだ表（交換の入力）であり、型検査器の既知の範囲は、そのうち実行時の検査と同じ解析と一致する項目
だけから作る。検査・射影・拡大の実行は、同じ名前の組み込みの関数の実例の表の δ である。 -/
def productionRules (pattern : String → Option Range) (host : String → Option Scope.Domain.HostPattern) : Rules where
  checkPath := checkRule (pathCheck pathPattern pathTarget (agreed pattern pathPattern))
    (deltaRun ModelTargets.builtins checkPathName)
  checkRequest :=
    checkRule (requestCheck RequestDelta.parseHostPattern reqEndpoint
      (requestLitBound (agreed host RequestDelta.parseHostPattern)))
      (deltaRun ModelHttp.builtins checkRequestName)
  pathValue := projectRule (deltaRun ModelTargets.builtins pathValueName)
  requestValue := projectRule (deltaRun ModelHttp.builtins requestValueName)
  widenPath := projectRule (deltaRun ModelTargets.builtins widenPathName)
  widenRequest := projectRule (deltaRun ModelHttp.builtins widenRequestName)

/-- 実例の表の δ を規則にした表は、δ の `Error` の構成子の名前と違う Ok の構成子の名前で健全である。表の条件はない。 -/
theorem productionRules_sound (pattern : String → Option Range) (host : String → Option Scope.Domain.HostPattern)
    {ok : ConName} (hne : ok ≠ "Result.Error") (facts : String → Option Range) :
    (productionRules pattern host).Sound (models ok facts) :=
  ⟨checkRule_sound (pathCheck_boundSound ok facts fun _ _ h => agreed_sound h) (modelTargets_contract hne _),
   checkRule_sound (requestLitBound_boundSound ok facts reqEndpoint fun _ _ h => agreed_sound h)
     (modelHttp_contract hne _),
   projectRule_sound _ _, projectRule_sound _ _, projectRule_sound _ _, projectRule_sound _ _⟩

end Benitoite.Release.Refinement.Surface.ScopeSound
