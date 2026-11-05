import Benitoite.Release.Refinement.RequestDelta
import Benitoite.Release.Refinement.AtPrepare

/-! # 動的な pattern の文字列

At の pattern 引数は、解析済みの範囲の値のほかに動的な `String` を受ける（設計書 01-07「範囲」）。文字列は
`parsePatternText` で範囲の式へ読み、解析済みの値と同じく名前の種類・整形式・正規形を確かめる。

- 絶対形のパス条件とホスト条件の読み方は、旧 API の純粋チェック（`ScopeDelta.parsePattern`・
  `RequestDelta.parseHostPattern`）と同じ定義である。
- 解析できない文字列は準備の形式不正、基準からの条件で起点の値を渡さない At は準備の未束縛、渡した起点値が基準を
  束縛しない At は検査の未束縛の誤りになる。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

theorem ScopeDelta.parsePattern_eq : ScopeDelta.parsePattern = parseAbsolutePathPattern := rfl

theorem RequestDelta.parseHostPattern_eq : RequestDelta.parseHostPattern = parseHostPatternText := rfl

/-- 文字列の pattern の解析の成功は、文字列の解析の成功と、名前の種類・整形式・正規形である。 -/
theorem parseAtPattern_string {k : Kind} {s : String} {r : RangeExpr} :
    parseAtPattern k (.const (.string s)) = some r ↔
      parsePatternText k s = some r ∧ r.FitsKind k ∧ r.WF ∧ r.Canonical := by
  simp only [parseAtPattern, Option.bind_eq_some_iff]
  constructor
  · rintro ⟨r', h, h'⟩
    split at h'
    · cases h'; exact ⟨h, by assumption⟩
    · cases h'
  · rintro ⟨h, hf⟩
    exact ⟨r, h, by simp [hf]⟩

/-- 解析できない文字列の pattern は、At の準備の形式不正の誤りになる。 -/
theorem AtPrepare.text_invalid {B cap kind name bases pattern input r s}
    (hv : closeVal cap pattern = .const (.string s)) (h : parsePatternText kind s = none) :
    AtPrepare B cap kind name bases pattern input (.fixed r) =
      .error (AtError.save (closeVal cap pattern) (closeVal cap input) none none none .invalidPattern) :=
  AtPrepare.pattern_invalid (by simp [hv, parseAtPattern, h])

/-- 渡した起点値が基準を束縛しないとき、基準からの条件の検査は未束縛の誤りになる。 -/
theorem checkAt_based_unbound (σ : PathEnv) (k : Kind) (b : PathBase) (p : PathPattern)
    (input : TargetInput) (bound : RangeExpr) (hb : σ.lookup b = none) :
    checkAt (some σ) k (.based b p) input bound =
      .error (atDetail (some σ) (.based b p) input (.unbound b)) := by
  simp [checkAt, resolveSnapshot, RangeExpr.resolve, hb]; rfl

/-- 起点の文字列 `{work}/out/**` は work からの木であり、work を持たない起点値では未束縛の誤りになる。 -/
example (σ : PathEnv) (input : TargetInput) (bound : RangeExpr) (hw : σ.work = none) :
    parsePatternText .path "{work}/out/**" = some (.based .work (.tree ["out"])) ∧
      checkAt (some σ) .path (.based .work (.tree ["out"])) input bound =
        .error (atDetail (some σ) (.based .work (.tree ["out"])) input (.unbound .work)) :=
  ⟨by decide +kernel, checkAt_based_unbound σ .path .work _ input bound (by simp [PathEnv.lookup, hw])⟩

/-- 裸の相対形と `.` は root からの条件、`{cwd}` は cwd からの条件、`{secrets}` は一覧である。 -/
example : parsePatternText .path "./data/a" = some (.based .root (.exact ["data", "a"])) ∧
    parsePatternText .path "data/**" = some (.based .root (.tree ["data"])) ∧
    parsePatternText .path "." = some (.based .root (.exact [])) ∧
    parsePatternText .path "{cwd}/data/**" = some (.based .cwd (.tree ["data"])) ∧
    parsePatternText .path "~/notes" = some (.based .home (.exact ["notes"])) ∧
    parsePatternText .path "{secrets}" = some .secrets ∧
    parsePatternText .path "/data/**" = some (.path (.tree ["data"])) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> decide +kernel

/-- `~user`・余分な末尾の `/`・`..`・未知の基準の名前・端点の種類は解析しない。 -/
example : parsePatternText .path "~user/x" = none ∧ parsePatternText .path "{root}/" = none ∧
    parsePatternText .path "a/../b" = none ∧ parsePatternText .path "{base}/a" = none ∧
    parsePatternText .endpoint "example.com:443" = none := by
  refine ⟨?_, ?_, ?_, ?_, rfl⟩ <;> decide +kernel

/-- 文字列の pattern の解析は、解析済みの範囲の値と同じ検査を通る。 -/
example : parseAtPattern .path (.const (.string "{cwd}/data/**")) = some (.based .cwd (.tree ["data"])) :=
  parseAtPattern_string.mpr ⟨by decide +kernel, by decide⟩

end Benitoite.Release.Refinement
