import Benitoite.Scope.RangeCover

/-!
# Scopeの解析済み入力についての独立した小モデル

文字列の解析・小文字化を済ませた要素列と、解析済みの IP アドレス・CIDR を扱う。対象とパターンの型、
所属、整形式性の述語は `Benitoite.Scope.Domain` の定義をそのまま使い、本モジュールでは定義し直さない
（L00.08 の一括の問い、問 17）。妥当性の検査はこの表現での前提を明示するために置き、元の文字列の
parserの正しさは仮定しない。字面の所属から操作の許可やIOの成功は導かない
（設計書 01-12「検査済みの値の独立した小モデル」）。

ホストの対象はホスト名か IP アドレス（`Scope.Domain.HostTarget`）、ホストのパターンはホスト名の
パターンか IP のパターン（完全一致・CIDR。`Scope.Domain.HostPattern`）である（設計者の決定、DET-01 の
領域の部分）。ホスト名だけの入力は `.name` で包んだ値であり、その結果は旧のホスト名だけのモデルと同じである
（`rawMakeHost_name` と `*_name` の系）。

名前の扱い: `Scope.Domain` の `HostPattern`・`PathPattern` と `Checked.Range` との混同を避けるため、
`open Benitoite.Scope.Domain` をせず `Scope.Domain.HostPattern` などと修飾して書く（`Scope/Domain.lean` の
先頭のコメント）。
-/
namespace Benitoite.Checked.Scope

/-! ## ポート（言語の整数） -/

-- 言語の整数のままの条件。解析済みのポート `Scope.Domain.Port`（`Fin 65536`）への変換の条件と同じである
-- （`validPort_iff_ofInt?`）。
def PortBounds (lo hi : Int) : Prop := 0 ≤ lo ∧ lo ≤ hi ∧ hi ≤ 65535
def ValidPort (port : Int) : Prop := 0 ≤ port ∧ port ≤ 65535
def PortMatches (lo hi port : Int) : Prop := lo ≤ port ∧ port ≤ hi

instance (lo hi : Int) : Decidable (PortBounds lo hi) := by
  unfold PortBounds; infer_instance
instance (port : Int) : Decidable (ValidPort port) := by
  unfold ValidPort; infer_instance
instance (lo hi port : Int) : Decidable (PortMatches lo hi port) := by
  unfold PortMatches; infer_instance

/-- 言語の整数のポートの妥当性は、解析済みのポートへの変換が成功する条件と同じである。 -/
theorem validPort_iff_ofInt? (port : Int) : ValidPort port ↔ (Scope.Domain.Port.ofInt? port).isSome :=
  (Scope.Domain.Port.ofInt?_isSome_iff port).symm

/-! ## 入力と検査済みの値 -/

/-- パターンの種類を保つ。元の字面とparserのreasonは本モデルの外側である。 -/
inductive Pattern where
  | host (pattern : Scope.Domain.HostPattern)
  | path (pattern : Scope.Domain.PathPattern)
  deriving DecidableEq, Repr

/-- 失敗。対象は種類のタグ（`Scope.Domain.Target` の `host`・`path`）を付けて保存する。 -/
inductive ScopeError where
  | invalidPattern (pattern : Pattern)
  | invalidTarget (target : Scope.Domain.Target)
  | invalidPortRange (minimum maximum : Int)
  | invalidPort (port : Int)
  | outsideScope (pattern : Pattern) (target : Scope.Domain.Target)
  | portOutsideScope (minimum maximum port : Int)
  deriving DecidableEq, Repr

structure RawHost where
  pattern : Scope.Domain.HostPattern
  target : Scope.Domain.HostTarget
  deriving DecidableEq, Repr
structure CheckedHost extends RawHost where
  patternValid : pattern.WF
  targetValid : target.WF
  membership : pattern.Matches target

structure RawPath where
  pattern : Scope.Domain.PathPattern
  target : Scope.Domain.Word
  deriving DecidableEq, Repr
structure CheckedPath extends RawPath where
  patternValid : pattern.WF
  targetValid : Scope.Domain.PathWordWF target
  membership : pattern.Matches target

structure RawEndpoint where
  hostPattern : Scope.Domain.HostPattern
  host : Scope.Domain.HostTarget
  minimumPort : Int
  maximumPort : Int
  port : Int
  deriving DecidableEq, Repr
structure CheckedEndpoint extends RawEndpoint where
  patternValid : hostPattern.WF
  targetValid : host.WF
  bounds : PortBounds minimumPort maximumPort
  portValid : ValidPort port
  hostMatches : hostPattern.Matches host
  portMatches : PortMatches minimumPort maximumPort port

def eraseHost (v : CheckedHost) : RawHost := v.toRawHost
def erasePath (v : CheckedPath) : RawPath := v.toRawPath
def eraseEndpoint (v : CheckedEndpoint) : RawEndpoint := v.toRawEndpoint

def makeHost (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    Except ScopeError CheckedHost :=
  if hp : p.WF then
    if ht : target.WF then
      if hm : p.Matches target then .ok ⟨⟨p, target⟩, hp, ht, hm⟩
      else .error (.outsideScope (.host p) (.host target))
    else .error (.invalidTarget (.host target))
  else .error (.invalidPattern (.host p))

def rawMakeHost (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    Except ScopeError RawHost :=
  if p.WF then
    if target.WF then
      if p.Matches target then .ok ⟨p, target⟩
      else .error (.outsideScope (.host p) (.host target))
    else .error (.invalidTarget (.host target))
  else .error (.invalidPattern (.host p))

def makePath (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) :
    Except ScopeError CheckedPath :=
  if hp : p.WF then
    if ht : Scope.Domain.PathWordWF target then
      if hm : p.Matches target then .ok ⟨⟨p, target⟩, hp, ht, hm⟩
      else .error (.outsideScope (.path p) (.path target))
    else .error (.invalidTarget (.path target))
  else .error (.invalidPattern (.path p))

def rawMakePath (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) :
    Except ScopeError RawPath :=
  if p.WF then
    if Scope.Domain.PathWordWF target then
      if p.Matches target then .ok ⟨p, target⟩
      else .error (.outsideScope (.path p) (.path target))
    else .error (.invalidTarget (.path target))
  else .error (.invalidPattern (.path p))

def makeEndpoint (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) (lo hi port : Int) :
    Except ScopeError CheckedEndpoint :=
  if hp : p.WF then
    if ht : target.WF then
      if hb : PortBounds lo hi then
        if hv : ValidPort port then
          if hm : p.Matches target then
            if hr : PortMatches lo hi port then
              .ok ⟨⟨p, target, lo, hi, port⟩, hp, ht, hb, hv, hm, hr⟩
            else .error (.portOutsideScope lo hi port)
          else .error (.outsideScope (.host p) (.host target))
        else .error (.invalidPort port)
      else .error (.invalidPortRange lo hi)
    else .error (.invalidTarget (.host target))
  else .error (.invalidPattern (.host p))

def rawMakeEndpoint (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) (lo hi port : Int) :
    Except ScopeError RawEndpoint :=
  if p.WF then
    if target.WF then
      if PortBounds lo hi then
        if ValidPort port then
          if p.Matches target then
            if PortMatches lo hi port then .ok ⟨p, target, lo, hi, port⟩
            else .error (.portOutsideScope lo hi port)
          else .error (.outsideScope (.host p) (.host target))
        else .error (.invalidPort port)
      else .error (.invalidPortRange lo hi)
    else .error (.invalidTarget (.host target))
  else .error (.invalidPattern (.host p))

/-! ## 成功・失敗・消去 -/

theorem makeHost_ok (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) (v : CheckedHost)
    (h : makeHost p target = .ok v) :
    v.pattern = p ∧ v.target = target ∧ p.Matches target ∧ p.WF ∧ target.WF := by
  unfold makeHost at h
  split at h <;> (try split at h) <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, ‹p.Matches target›, ‹p.WF›, ‹target.WF›⟩

theorem makePath_ok (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) (v : CheckedPath)
    (h : makePath p target = .ok v) :
    v.pattern = p ∧ v.target = target ∧ p.Matches target ∧
      p.WF ∧ Scope.Domain.PathWordWF target := by
  unfold makePath at h
  split at h <;> (try split at h) <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, ‹p.Matches target›, ‹p.WF›, ‹Scope.Domain.PathWordWF target›⟩

theorem makeEndpoint_ok (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) (v : CheckedEndpoint) (h : makeEndpoint p target lo hi port = .ok v) :
    v.hostPattern = p ∧ v.host = target ∧ v.minimumPort = lo ∧
      v.maximumPort = hi ∧ v.port = port ∧ p.Matches target ∧
      PortBounds lo hi ∧ PortMatches lo hi port ∧ ValidPort port ∧
      p.WF ∧ target.WF := by
  unfold makeEndpoint at h
  split at h <;> (try split at h) <;> (try split at h) <;>
    (try split at h) <;> (try split at h) <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, rfl, rfl, rfl, ‹p.Matches target›, ‹PortBounds lo hi›, ‹PortMatches lo hi port›,
    ‹ValidPort port›, ‹p.WF›, ‹target.WF›⟩

theorem makeHost_success_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    (∃ v, makeHost p target = .ok v) ↔ p.WF ∧ target.WF ∧ p.Matches target := by
  constructor
  · rintro ⟨v, hv⟩
    obtain ⟨_, _, hm, hp, ht⟩ := makeHost_ok p target v hv
    exact ⟨hp, ht, hm⟩
  · rintro ⟨hp, ht, hm⟩; simp [makeHost, hp, ht, hm]

theorem makePath_success_iff (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) :
    (∃ v, makePath p target = .ok v) ↔
      p.WF ∧ Scope.Domain.PathWordWF target ∧ p.Matches target := by
  constructor
  · rintro ⟨v, hv⟩
    obtain ⟨_, _, hm, hp, ht⟩ := makePath_ok p target v hv
    exact ⟨hp, ht, hm⟩
  · rintro ⟨hp, ht, hm⟩; simp [makePath, hp, ht, hm]

theorem makeEndpoint_success_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) :
    (∃ v, makeEndpoint p target lo hi port = .ok v) ↔
      p.WF ∧ target.WF ∧ PortBounds lo hi ∧
      ValidPort port ∧ p.Matches target ∧ PortMatches lo hi port := by
  constructor
  · rintro ⟨v, hv⟩
    obtain ⟨_, _, _, _, _, hm, hb, hr, hv, hp, ht⟩ := makeEndpoint_ok p target lo hi port v hv
    exact ⟨hp, ht, hb, hv, hm, hr⟩
  · rintro ⟨hp, ht, hb, hv, hm, hr⟩; simp [makeEndpoint, hp, ht, hb, hv, hm, hr]

theorem makeHost_invalidPattern_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    makeHost p target = .error (.invalidPattern (.host p)) ↔ ¬ p.WF := by
  unfold makeHost
  split <;> (try split) <;> (try split) <;> simp_all

theorem makeHost_invalidTarget_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    makeHost p target = .error (.invalidTarget (.host target)) ↔ p.WF ∧ ¬ target.WF := by
  unfold makeHost
  split <;> (try split) <;> (try split) <;> simp_all

theorem makePath_invalidPattern_iff (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) :
    makePath p target = .error (.invalidPattern (.path p)) ↔ ¬ p.WF := by
  unfold makePath
  split <;> (try split) <;> (try split) <;> simp_all

theorem makePath_invalidTarget_iff (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) :
    makePath p target = .error (.invalidTarget (.path target)) ↔
      p.WF ∧ ¬ Scope.Domain.PathWordWF target := by
  unfold makePath
  split <;> (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_invalidPattern_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) :
    makeEndpoint p target lo hi port = .error (.invalidPattern (.host p)) ↔ ¬ p.WF := by
  unfold makeEndpoint
  split <;> (try split) <;> (try split) <;> (try split) <;>
    (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_invalidTarget_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) :
    makeEndpoint p target lo hi port = .error (.invalidTarget (.host target)) ↔
      p.WF ∧ ¬ target.WF := by
  unfold makeEndpoint
  split <;> (try split) <;> (try split) <;> (try split) <;>
    (try split) <;> (try split) <;> simp_all

theorem makeHost_error_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (hp : p.WF) (ht : target.WF) :
    makeHost p target = .error (.outsideScope (.host p) (.host target)) ↔ ¬ p.Matches target := by
  simp [makeHost, hp, ht]

theorem makePath_error_iff (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word)
    (hp : p.WF) (ht : Scope.Domain.PathWordWF target) :
    makePath p target = .error (.outsideScope (.path p) (.path target)) ↔ ¬ p.Matches target := by
  simp [makePath, hp, ht]

theorem makeEndpoint_invalidBounds_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) (hp : p.WF) (ht : target.WF) :
    makeEndpoint p target lo hi port = .error (.invalidPortRange lo hi) ↔ ¬ PortBounds lo hi := by
  simp only [makeEndpoint, dite_eq_left hp, dite_eq_left ht]
  split <;> (try split) <;> (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_invalidPort_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) (hp : p.WF) (ht : target.WF) (hb : PortBounds lo hi) :
    makeEndpoint p target lo hi port = .error (.invalidPort port) ↔ ¬ ValidPort port := by
  simp only [makeEndpoint, dite_eq_left hp, dite_eq_left ht, dite_eq_left hb]
  split <;> (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_outside_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) (hp : p.WF) (ht : target.WF) (hb : PortBounds lo hi) (hv : ValidPort port) :
    (makeEndpoint p target lo hi port = .error (.outsideScope (.host p) (.host target)) ↔
      ¬ p.Matches target) ∧
    (makeEndpoint p target lo hi port = .error (.portOutsideScope lo hi port) ↔
      p.Matches target ∧ ¬ PortMatches lo hi port) := by
  simp only [makeEndpoint, dite_eq_left hp, dite_eq_left ht, dite_eq_left hb, dite_eq_left hv]
  split <;> (try split) <;> simp_all

theorem erase_makeHost (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    (makeHost p target).map eraseHost = rawMakeHost p target := by
  unfold makeHost rawMakeHost
  split <;> (try split) <;> (try split) <;> rfl

theorem erase_makePath (p : Scope.Domain.PathPattern) (target : Scope.Domain.Word) :
    (makePath p target).map erasePath = rawMakePath p target := by
  unfold makePath rawMakePath
  split <;> (try split) <;> (try split) <;> rfl

theorem erase_makeEndpoint (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget)
    (lo hi port : Int) :
    (makeEndpoint p target lo hi port).map eraseEndpoint = rawMakeEndpoint p target lo hi port := by
  unfold makeEndpoint rawMakeEndpoint
  split <;> (try split) <;> (try split) <;> (try split) <;>
    (try split) <;> (try split) <;> rfl

/-! ## ホスト名だけの入力（旧の言明の系）

旧のモデルのホストのパターンは `Scope.Domain.NamePattern` と同じ形（exact・one・many）、対象は
`Scope.Domain.Word` だった。旧の妥当性と所属の述語は `Scope.Domain` の述語と同じ定義であり
（`ValidHostWord` は `NameWordWF`、`ValidHostPattern` は `NamePattern.WF`、`HostMatches` は
`NamePattern.Matches`）、本モジュールはそれらを `Scope.Domain` の名前で使う。ホスト名だけの入力は
`.name` で包んだ値であり、次の系が旧の言明をその形で与える。
-/

/-- ホスト名だけの入力での結果は、旧の `rawMakeHost` の検査の順と結果に、パターンと対象を `.name` で
包んだものである。 -/
theorem rawMakeHost_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word) :
    rawMakeHost (.name p) (.name target) =
      if p.WF then
        if Scope.Domain.NameWordWF target then
          if p.Matches target then .ok ⟨.name p, .name target⟩
          else .error (.outsideScope (.host (.name p)) (.host (.name target)))
        else .error (.invalidTarget (.host (.name target)))
      else .error (.invalidPattern (.host (.name p))) := by
  by_cases hp : p.WF <;> by_cases ht : Scope.Domain.NameWordWF target <;>
    by_cases hm : p.Matches target <;>
    simp [rawMakeHost, Scope.Domain.HostPattern.WF, Scope.Domain.HostTarget.WF,
      Scope.Domain.HostPattern.Matches, hp, ht, hm]

/-- ホスト名だけの入力での Endpoint の結果も、旧の検査の順と結果に `.name` で包んだものである。 -/
theorem rawMakeEndpoint_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) :
    rawMakeEndpoint (.name p) (.name target) lo hi port =
      if p.WF then
        if Scope.Domain.NameWordWF target then
          if PortBounds lo hi then
            if ValidPort port then
              if p.Matches target then
                if PortMatches lo hi port then .ok ⟨.name p, .name target, lo, hi, port⟩
                else .error (.portOutsideScope lo hi port)
              else .error (.outsideScope (.host (.name p)) (.host (.name target)))
            else .error (.invalidPort port)
          else .error (.invalidPortRange lo hi)
        else .error (.invalidTarget (.host (.name target)))
      else .error (.invalidPattern (.host (.name p))) := by
  by_cases hp : p.WF <;> by_cases ht : Scope.Domain.NameWordWF target <;>
    by_cases hb : PortBounds lo hi <;> by_cases hv : ValidPort port <;>
    by_cases hm : p.Matches target <;> by_cases hr : PortMatches lo hi port <;>
    simp [rawMakeEndpoint, Scope.Domain.HostPattern.WF, Scope.Domain.HostTarget.WF,
      Scope.Domain.HostPattern.Matches, hp, ht, hb, hv, hm, hr]

theorem makeHost_ok_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word) (v : CheckedHost)
    (h : makeHost (.name p) (.name target) = .ok v) :
    v.pattern = .name p ∧ v.target = .name target ∧ p.Matches target ∧
      p.WF ∧ Scope.Domain.NameWordWF target :=
  makeHost_ok _ _ v h

theorem makeEndpoint_ok_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) (v : CheckedEndpoint)
    (h : makeEndpoint (.name p) (.name target) lo hi port = .ok v) :
    v.hostPattern = .name p ∧ v.host = .name target ∧ v.minimumPort = lo ∧
      v.maximumPort = hi ∧ v.port = port ∧ p.Matches target ∧
      PortBounds lo hi ∧ PortMatches lo hi port ∧ ValidPort port ∧
      p.WF ∧ Scope.Domain.NameWordWF target :=
  makeEndpoint_ok _ _ lo hi port v h

theorem makeHost_success_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word) :
    (∃ v, makeHost (.name p) (.name target) = .ok v) ↔
      p.WF ∧ Scope.Domain.NameWordWF target ∧ p.Matches target :=
  makeHost_success_iff _ _

theorem makeEndpoint_success_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) :
    (∃ v, makeEndpoint (.name p) (.name target) lo hi port = .ok v) ↔
      p.WF ∧ Scope.Domain.NameWordWF target ∧ PortBounds lo hi ∧
      ValidPort port ∧ p.Matches target ∧ PortMatches lo hi port :=
  makeEndpoint_success_iff _ _ lo hi port

theorem makeHost_invalidPattern_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word) :
    makeHost (.name p) (.name target) = .error (.invalidPattern (.host (.name p))) ↔ ¬ p.WF :=
  makeHost_invalidPattern_iff _ _

theorem makeHost_invalidTarget_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word) :
    makeHost (.name p) (.name target) = .error (.invalidTarget (.host (.name target))) ↔
      p.WF ∧ ¬ Scope.Domain.NameWordWF target :=
  makeHost_invalidTarget_iff _ _

theorem makeEndpoint_invalidPattern_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) :
    makeEndpoint (.name p) (.name target) lo hi port = .error (.invalidPattern (.host (.name p))) ↔
      ¬ p.WF :=
  makeEndpoint_invalidPattern_iff _ _ lo hi port

theorem makeEndpoint_invalidTarget_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) :
    makeEndpoint (.name p) (.name target) lo hi port = .error (.invalidTarget (.host (.name target))) ↔
      p.WF ∧ ¬ Scope.Domain.NameWordWF target :=
  makeEndpoint_invalidTarget_iff _ _ lo hi port

theorem makeHost_error_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (hp : p.WF) (ht : Scope.Domain.NameWordWF target) :
    makeHost (.name p) (.name target) = .error (.outsideScope (.host (.name p)) (.host (.name target))) ↔
      ¬ p.Matches target :=
  makeHost_error_iff _ _ hp ht

theorem makeEndpoint_invalidBounds_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) (hp : p.WF) (ht : Scope.Domain.NameWordWF target) :
    makeEndpoint (.name p) (.name target) lo hi port = .error (.invalidPortRange lo hi) ↔
      ¬ PortBounds lo hi :=
  makeEndpoint_invalidBounds_iff _ _ lo hi port hp ht

theorem makeEndpoint_invalidPort_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) (hp : p.WF) (ht : Scope.Domain.NameWordWF target) (hb : PortBounds lo hi) :
    makeEndpoint (.name p) (.name target) lo hi port = .error (.invalidPort port) ↔ ¬ ValidPort port :=
  makeEndpoint_invalidPort_iff _ _ lo hi port hp ht hb

theorem makeEndpoint_outside_iff_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) (hp : p.WF) (ht : Scope.Domain.NameWordWF target) (hb : PortBounds lo hi)
    (hv : ValidPort port) :
    (makeEndpoint (.name p) (.name target) lo hi port =
        .error (.outsideScope (.host (.name p)) (.host (.name target))) ↔
      ¬ p.Matches target) ∧
    (makeEndpoint (.name p) (.name target) lo hi port = .error (.portOutsideScope lo hi port) ↔
      p.Matches target ∧ ¬ PortMatches lo hi port) :=
  makeEndpoint_outside_iff _ _ lo hi port hp ht hb hv

theorem erase_makeHost_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word) :
    (makeHost (.name p) (.name target)).map eraseHost =
      if p.WF then
        if Scope.Domain.NameWordWF target then
          if p.Matches target then .ok ⟨.name p, .name target⟩
          else .error (.outsideScope (.host (.name p)) (.host (.name target)))
        else .error (.invalidTarget (.host (.name target)))
      else .error (.invalidPattern (.host (.name p))) := by
  rw [erase_makeHost, rawMakeHost_name]

theorem erase_makeEndpoint_name (p : Scope.Domain.NamePattern) (target : Scope.Domain.Word)
    (lo hi port : Int) :
    (makeEndpoint (.name p) (.name target) lo hi port).map eraseEndpoint =
      if p.WF then
        if Scope.Domain.NameWordWF target then
          if PortBounds lo hi then
            if ValidPort port then
              if p.Matches target then
                if PortMatches lo hi port then .ok ⟨.name p, .name target, lo, hi, port⟩
                else .error (.portOutsideScope lo hi port)
              else .error (.outsideScope (.host (.name p)) (.host (.name target)))
            else .error (.invalidPort port)
          else .error (.invalidPortRange lo hi)
        else .error (.invalidTarget (.host (.name target)))
      else .error (.invalidPattern (.host (.name p))) := by
  rw [erase_makeEndpoint, rawMakeEndpoint_name]

/-! ## IP アドレスと CIDR の入力 -/

/-- IP のパターンと IP の対象では、対象の妥当性は常に成り立ち、成否はパターンの整形式性と所属だけで決まる。 -/
theorem makeHost_ip_success_iff (p : Scope.Domain.IPPattern) (a : Scope.Domain.IPAddr) :
    (∃ v, makeHost (.ip p) (.ip a) = .ok v) ↔ p.WF ∧ p.Matches a := by
  rw [makeHost_success_iff]
  exact ⟨fun h => ⟨h.1, h.2.2⟩, fun h => ⟨h.1, trivial, h.2⟩⟩

/-- ホスト名のパターンは IP の対象を含まない。DNS の解決による相互変換をしない（DET-01）。 -/
theorem makeHost_name_ip (p : Scope.Domain.NamePattern) (a : Scope.Domain.IPAddr) (hp : p.WF) :
    makeHost (.name p) (.ip a) = .error (.outsideScope (.host (.name p)) (.host (.ip a))) :=
  (makeHost_error_iff (.name p) (.ip a) hp trivial).mpr id

/-- IP のパターンはホスト名の対象を含まない。 -/
theorem makeHost_ip_name (p : Scope.Domain.IPPattern) (target : Scope.Domain.Word) (hp : p.WF)
    (ht : Scope.Domain.NameWordWF target) :
    makeHost (.ip p) (.name target) = .error (.outsideScope (.host (.ip p)) (.host (.name target))) :=
  (makeHost_error_iff (.ip p) (.name target) hp ht).mpr id

/-- 族の違う IP の対象は所属しない。IPv4 を射影した IPv6 アドレスは IPv4 のパターンに所属しない。 -/
theorem makeHost_ip_family_ne (p : Scope.Domain.IPPattern) (a : Scope.Domain.IPAddr) (hp : p.WF)
    (hf : a.family ≠ p.family) :
    makeHost (.ip p) (.ip a) = .error (.outsideScope (.host (.ip p)) (.host (.ip a))) :=
  (makeHost_error_iff (.ip p) (.ip a) hp trivial).mpr fun h => hf (Scope.Domain.IPPattern.family_of_matches h)

/-- 四つの全数字のラベルの列はホスト名の対象として妥当でない（旧のモデルと同じ）。IP の対象は解析器が
`.ip` として渡す。 -/
theorem makeHost_fourDigit_name (p : Scope.Domain.HostPattern) (target : Scope.Domain.Word) (hp : p.WF)
    (h4 : Scope.Domain.FourDigitLabels target) :
    makeHost p (.name target) = .error (.invalidTarget (.host (.name target))) :=
  (makeHost_invalidTarget_iff _ _).mpr ⟨hp, fun h => h.2.2 h4⟩

/-! ## 正規化と被覆 -/

/-- ホストのパターンの整形式性は正規化の前後で変わらない。 -/
theorem hostPattern_normalize_wf_iff (p : Scope.Domain.HostPattern) : p.normalize.WF ↔ p.WF := by
  refine ⟨fun h => ?_, Scope.Domain.HostPattern.normalize_wf⟩
  cases p with
  | name q => exact h
  | ip q =>
    cases q with
    | exact a => trivial
    | cidr c =>
      by_cases hc : c.prefixLen = c.family.width
      · refine ⟨Nat.le_of_eq hc, ?_⟩
        simp [Scope.Domain.CIDR.blockSize, Scope.Domain.CIDR.hostBits, hc, Nat.mod_one]
      · simpa [Scope.Domain.HostPattern.normalize, Scope.Domain.IPPattern.normalize, hc] using h

/-- パターンを正規化しても成否は変わらない。`/32`・`/128` の CIDR と同じアドレスの完全一致は、同じ対象に
ついて同じ成否を返す（DET-01）。 -/
theorem makeHost_normalize_success_iff (p : Scope.Domain.HostPattern) (target : Scope.Domain.HostTarget) :
    (∃ v, makeHost p.normalize target = .ok v) ↔ (∃ v, makeHost p target = .ok v) := by
  rw [makeHost_success_iff, makeHost_success_iff, hostPattern_normalize_wf_iff,
    Scope.Domain.HostPattern.normalize_matches]

/-- 検査済みのホストの対象は、そのパターンを覆う全てのパターンに所属する（被覆の健全性）。 -/
theorem CheckedHost.matches_of_covers (v : CheckedHost) {q : Scope.Domain.HostPattern}
    (h : q.Covers v.pattern) : q.Matches v.target :=
  Scope.Domain.HostPattern.Covers.sound h v.membership

theorem CheckedPath.matches_of_covers (v : CheckedPath) {q : Scope.Domain.PathPattern}
    (h : q.Covers v.pattern) : q.Matches v.target :=
  Scope.Domain.PathPattern.Covers.sound h v.membership

/-- 成功した入力は、整形式で元のパターンを覆う広いパターンでも成功する。 -/
theorem makeHost_widen {p q : Scope.Domain.HostPattern} {target : Scope.Domain.HostTarget}
    {v : CheckedHost} (h : makeHost p target = .ok v) (hq : q.WF) (hc : q.Covers p) :
    ∃ v', makeHost q target = .ok v' := by
  obtain ⟨_, _, hm, _, ht⟩ := makeHost_ok p target v h
  exact (makeHost_success_iff q target).mpr ⟨hq, ht, Scope.Domain.HostPattern.Covers.sound hc hm⟩

theorem makePath_widen {p q : Scope.Domain.PathPattern} {target : Scope.Domain.Word}
    {v : CheckedPath} (h : makePath p target = .ok v) (hq : q.WF) (hc : q.Covers p) :
    ∃ v', makePath q target = .ok v' := by
  obtain ⟨_, _, hm, _, ht⟩ := makePath_ok p target v h
  exact (makePath_success_iff q target).mpr ⟨hq, ht, Scope.Domain.PathPattern.Covers.sound hc hm⟩

theorem makeEndpoint_widen {p q : Scope.Domain.HostPattern} {target : Scope.Domain.HostTarget}
    {lo hi port : Int} {v : CheckedEndpoint} (h : makeEndpoint p target lo hi port = .ok v)
    (hq : q.WF) (hc : q.Covers p) : ∃ v', makeEndpoint q target lo hi port = .ok v' := by
  obtain ⟨_, _, _, _, _, hm, hb, hr, hv, _, ht⟩ := makeEndpoint_ok p target lo hi port v h
  exact (makeEndpoint_success_iff q target lo hi port).mpr
    ⟨hq, ht, hb, hv, Scope.Domain.HostPattern.Covers.sound hc hm, hr⟩

/-! ## 範囲の領域との対応

検査済みの値のパターンと対象を `Scope.Domain.Range`・`Scope.Domain.Target` として読む。Endpoint の端点と
port は妥当性の証拠から `Scope.Domain.Port` へ写す。
-/

def CheckedHost.toRange (v : CheckedHost) : Scope.Domain.Range := .host v.pattern
def CheckedHost.toTarget (v : CheckedHost) : Scope.Domain.Target := .host v.target
def CheckedPath.toRange (v : CheckedPath) : Scope.Domain.Range := .path v.pattern
def CheckedPath.toTarget (v : CheckedPath) : Scope.Domain.Target := .path v.target

theorem CheckedHost.toRange_wf (v : CheckedHost) : v.toRange.WF := v.patternValid
theorem CheckedHost.toTarget_wf (v : CheckedHost) : v.toTarget.WF := v.targetValid
theorem CheckedPath.toRange_wf (v : CheckedPath) : v.toRange.WF := v.patternValid
theorem CheckedPath.toTarget_wf (v : CheckedPath) : v.toTarget.WF := v.targetValid

/-- 検査済みのホストの対象は、種類 `host` のもとでパターンの範囲に所属する。 -/
theorem CheckedHost.memK (v : CheckedHost) : v.toRange.MemK .host v.toTarget :=
  ⟨rfl, v.membership⟩

theorem CheckedPath.memK (v : CheckedPath) : v.toRange.MemK .path v.toTarget :=
  ⟨rfl, v.membership⟩

/-- 検査済みの対象は、パターンの範囲を覆う全ての範囲に所属する。 -/
theorem CheckedHost.mem_of_covers (v : CheckedHost) {r : Scope.Domain.Range} (h : r.Covers v.toRange) :
    r.Mem v.toTarget :=
  Scope.Domain.Range.Covers.sound h _ v.memK.2

theorem CheckedPath.mem_of_covers (v : CheckedPath) {r : Scope.Domain.Range} (h : r.Covers v.toRange) :
    r.Mem v.toTarget :=
  Scope.Domain.Range.Covers.sound h _ v.memK.2

/-- 端点の下端の解析済みのポート。 -/
def CheckedEndpoint.minimum (v : CheckedEndpoint) : Scope.Domain.Port :=
  ⟨v.minimumPort.toNat, by have := v.bounds; unfold PortBounds at this; omega⟩

/-- 端点の上端の解析済みのポート。 -/
def CheckedEndpoint.maximum (v : CheckedEndpoint) : Scope.Domain.Port :=
  ⟨v.maximumPort.toNat, by have := v.bounds; unfold PortBounds at this; omega⟩

/-- 解析済みのポート。 -/
def CheckedEndpoint.portValue (v : CheckedEndpoint) : Scope.Domain.Port :=
  ⟨v.port.toNat, by have := v.portValid; unfold ValidPort at this; omega⟩

def CheckedEndpoint.toPattern (v : CheckedEndpoint) : Scope.Domain.EndpointPattern :=
  ⟨v.hostPattern, ⟨v.minimum, v.maximum⟩⟩

def CheckedEndpoint.toEndpoint (v : CheckedEndpoint) : Scope.Domain.Endpoint := ⟨v.host, v.portValue⟩

def CheckedEndpoint.toRange (v : CheckedEndpoint) : Scope.Domain.Range := .endpoint v.toPattern
def CheckedEndpoint.toTarget (v : CheckedEndpoint) : Scope.Domain.Target := .endpoint v.toEndpoint

/-- 解析済みのポートは、言語の整数からの変換 `Port.ofInt?` の結果と同じである。 -/
theorem CheckedEndpoint.ofInt?_port (v : CheckedEndpoint) :
    Scope.Domain.Port.ofInt? v.port = some v.portValue := by
  have := v.portValid
  unfold ValidPort at this
  simp [Scope.Domain.Port.ofInt?, this, CheckedEndpoint.portValue]

theorem CheckedEndpoint.ofInt?_minimum (v : CheckedEndpoint) :
    Scope.Domain.Port.ofInt? v.minimumPort = some v.minimum := by
  have := v.bounds
  unfold PortBounds at this
  simp [Scope.Domain.Port.ofInt?, CheckedEndpoint.minimum]
  omega

theorem CheckedEndpoint.ofInt?_maximum (v : CheckedEndpoint) :
    Scope.Domain.Port.ofInt? v.maximumPort = some v.maximum := by
  have := v.bounds
  unfold PortBounds at this
  simp [Scope.Domain.Port.ofInt?, CheckedEndpoint.maximum]
  omega

theorem CheckedEndpoint.toRange_wf (v : CheckedEndpoint) : v.toRange.WF := by
  refine ⟨v.patternValid, ?_⟩
  have := v.bounds
  unfold PortBounds at this
  show v.minimum ≤ v.maximum
  simp only [Fin.le_def, CheckedEndpoint.minimum, CheckedEndpoint.maximum]
  omega

theorem CheckedEndpoint.toTarget_wf (v : CheckedEndpoint) : v.toTarget.WF := v.targetValid

/-- 検査済みのエンドポイントは、種類 `endpoint` のもとでパターンの範囲に所属する。 -/
theorem CheckedEndpoint.memK (v : CheckedEndpoint) : v.toRange.MemK .endpoint v.toTarget := by
  refine ⟨rfl, v.hostMatches, ?_⟩
  have := v.portMatches
  have hb := v.bounds
  have hv := v.portValid
  unfold PortMatches at this
  unfold PortBounds at hb
  unfold ValidPort at hv
  show v.minimum ≤ v.portValue ∧ v.portValue ≤ v.maximum
  simp only [Fin.le_def, CheckedEndpoint.minimum, CheckedEndpoint.maximum, CheckedEndpoint.portValue]
  omega

theorem CheckedEndpoint.matches_of_covers (v : CheckedEndpoint) {q : Scope.Domain.EndpointPattern}
    (h : q.Covers v.toPattern) : q.Matches v.toEndpoint :=
  Scope.Domain.EndpointPattern.Covers.sound h v.memK.2

theorem CheckedEndpoint.mem_of_covers (v : CheckedEndpoint) {r : Scope.Domain.Range}
    (h : r.Covers v.toRange) : r.Mem v.toTarget :=
  Scope.Domain.Range.Covers.sound h _ v.memK.2

/-! ## 射影と小補題 -/

def host (v : CheckedHost) : Scope.Domain.HostTarget := v.target
def hostPattern (v : CheckedHost) : Scope.Domain.HostPattern := v.pattern
def path (v : CheckedPath) : Scope.Domain.Word := v.target
def pathPattern (v : CheckedPath) : Scope.Domain.PathPattern := v.pattern
def endpointHost (v : CheckedEndpoint) : Scope.Domain.HostTarget := v.host
def endpointHostPattern (v : CheckedEndpoint) : Scope.Domain.HostPattern := v.hostPattern
def endpointPort (v : CheckedEndpoint) : Int := v.port
def endpointMinimumPort (v : CheckedEndpoint) : Int := v.minimumPort
def endpointMaximumPort (v : CheckedEndpoint) : Int := v.maximumPort

theorem projection_preserves (h : CheckedHost) (p : CheckedPath) (e : CheckedEndpoint) :
    host h = (eraseHost h).target ∧ hostPattern h = (eraseHost h).pattern ∧
    path p = (erasePath p).target ∧ pathPattern p = (erasePath p).pattern ∧
    endpointHost e = (eraseEndpoint e).host ∧
    endpointHostPattern e = (eraseEndpoint e).hostPattern ∧
    endpointPort e = (eraseEndpoint e).port ∧
    endpointMinimumPort e = (eraseEndpoint e).minimumPort ∧
    endpointMaximumPort e = (eraseEndpoint e).maximumPort := by
  exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem one_excludes_apex (s : Scope.Domain.Word) :
    ¬ (Scope.Domain.HostPattern.name (.one s)).Matches (.name s) := by
  rintro ⟨x, hx⟩
  have := congrArg List.length hx
  simp only [List.length_cons] at this; omega

theorem one_excludes_deep (s extra : Scope.Domain.Word) (h : 2 ≤ extra.length) :
    ¬ (Scope.Domain.HostPattern.name (.one s)).Matches (.name (extra ++ s)) := by
  rintro ⟨x, hx⟩
  have := congrArg List.length hx
  simp only [List.length_cons, List.length_append] at this; omega

theorem many_excludes_apex (s : Scope.Domain.Word) :
    ¬ (Scope.Domain.HostPattern.name (.many s)).Matches (.name s) := by
  rintro ⟨xs, hx, he⟩
  have := congrArg List.length he
  have := List.length_pos_iff.mpr hx
  simp only [List.length_append] at *; omega

theorem path_tree_includes_self (s : Scope.Domain.Word) : (Scope.Domain.PathPattern.tree s).Matches s :=
  ⟨[], (List.append_nil s).symm⟩

/-- 同じCheckedHost型だけでは、別の条件への所属を導けない。 -/
theorem unindexed_policy_counterexample :
    ∃ v : CheckedHost, (Scope.Domain.HostPattern.name (.exact ["other", "example", "com"])).WF ∧
      ¬ (Scope.Domain.HostPattern.name (.exact ["other", "example", "com"])).Matches v.target := by
  refine ⟨⟨⟨.name (.one ["example", "com"]), .name ["api", "example", "com"]⟩,
    by decide, by decide, by decide⟩, by decide, by decide⟩

/-! ## 小さい具体例

成功と失敗は証拠を消した `rawMake*` を `#guard`（コンパイルした判定の評価）で確かめ、カーネルの展開に
頼らない。`erase_make*` が `make*` の結果と `rawMake*` の結果を結ぶ。
-/

private def hostIs (r : Except ScopeError RawHost) (x : Except ScopeError RawHost) : Bool :=
  match r, x with
  | .ok a, .ok b => decide (a = b)
  | .error a, .error b => decide (a = b)
  | _, _ => false

private def endpointIs (r : Except ScopeError RawEndpoint) (x : Except ScopeError RawEndpoint) : Bool :=
  match r, x with
  | .ok a, .ok b => decide (a = b)
  | .error a, .error b => decide (a = b)
  | _, _ => false

private def pathIs (r : Except ScopeError RawPath) (x : Except ScopeError RawPath) : Bool :=
  match r, x with
  | .ok a, .ok b => decide (a = b)
  | .error a, .error b => decide (a = b)
  | _, _ => false

private def nm (p : Scope.Domain.NamePattern) : Scope.Domain.HostPattern := .name p
private def hn (w : Scope.Domain.Word) : Scope.Domain.HostTarget := .name w

-- 正規化済みホスト名の文法。IPv4形式は数字の値の範囲によらずホスト名として拒否する。
#guard decide (Scope.Domain.NameWordWF ["localhost"]) && !decide (Scope.Domain.NameWordWF []) &&
  !decide (Scope.Domain.NameWordWF ["api", "", "com"]) &&
  !decide (Scope.Domain.NameWordWF ["-api", "example", "com"]) &&
  !decide (Scope.Domain.NameWordWF ["api-", "example", "com"]) &&
  !decide (Scope.Domain.NameWordWF ["API", "example", "com"]) &&
  !decide (Scope.Domain.NameWordWF ["日本語", "example", "com"]) &&
  !decide (Scope.Domain.NameWordWF ["999", "999", "999", "999"])

-- 一段と多段を同じtreeとして扱う誤りを区別する。
#guard (Scope.Domain.NamePattern.one ["example", "com"]).matches? ["api", "example", "com"] &&
  !(Scope.Domain.NamePattern.one ["example", "com"]).matches? ["a", "b", "example", "com"] &&
  (Scope.Domain.NamePattern.many ["example", "com"]).matches? ["api", "example", "com"] &&
  (Scope.Domain.NamePattern.many ["example", "com"]).matches? ["a", "b", "example", "com"] &&
  !(Scope.Domain.NamePattern.many ["example", "com"]).matches? ["example", "com"]

-- 根は空列。対象内の*は普通の文字だが、パターンの幹には書けない。
#guard decide (Scope.Domain.PathWordWF []) && !decide (Scope.Domain.PathWordWF [""]) &&
  !decide (Scope.Domain.PathWordWF ["data", ".."]) &&
  !decide (Scope.Domain.PathWordWF ["data\\reports"]) &&
  !decide (Scope.Domain.PathWordWF ["data\x00reports"]) &&
  decide (Scope.Domain.PathWordWF ["資料", "*.txt"]) &&
  !decide (Scope.Domain.PathPattern.exact ["資料", "*.txt"]).WF &&
  (Scope.Domain.PathPattern.tree []).matches? [] &&
  (Scope.Domain.PathPattern.tree []).matches? ["data"] &&
  (Scope.Domain.PathPattern.tree ["data", "reports"]).matches? ["data", "reports"] &&
  (Scope.Domain.PathPattern.tree ["data", "reports"]).matches? ["data", "reports", "日報"] &&
  !(Scope.Domain.PathPattern.tree ["data", "reports"]).matches? ["data", "reports-old"]

-- 証拠を消した返り値で、正規化済みの条件とUnicode対象の保存を確認する。
#guard hostIs (rawMakeHost (nm (.one ["example", "com"])) (hn ["api", "example", "com"]))
  (.ok ⟨nm (.one ["example", "com"]), hn ["api", "example", "com"]⟩)
#guard pathIs (rawMakePath (.tree ["資料"]) ["資料", "*.txt"]) (.ok ⟨.tree ["資料"], ["資料", "*.txt"]⟩)

private def examplePattern : Scope.Domain.HostPattern := .name (.many ["example", "com"])
private def exampleHost : Scope.Domain.HostTarget := .name ["a", "b", "example", "com"]

-- 負数と上限超過は、ホストの所属を調べる前にInvalidPortとなる。
#guard endpointIs (rawMakeEndpoint examplePattern (hn ["elsewhere"]) 0 65535 (-1)) (.error (.invalidPort (-1)))
#guard endpointIs (rawMakeEndpoint examplePattern (hn ["elsewhere"]) 0 65535 70000)
  (.error (.invalidPort 70000))
-- 端点も不正ならInvalidPortRangeが先である。
#guard endpointIs (rawMakeEndpoint examplePattern exampleHost 443 0 70000) (.error (.invalidPortRange 443 0))
-- 両方の所属に失敗すると、ホスト側の失敗を先に返す。
#guard endpointIs (rawMakeEndpoint examplePattern (hn ["elsewhere"]) 443 443 444)
  (.error (.outsideScope (.host examplePattern) (.host (hn ["elsewhere"]))))
#guard endpointIs (rawMakeEndpoint examplePattern exampleHost 443 443 444)
  (.error (.portOutsideScope 443 443 444))
-- 形式の失敗は端点よりも先であり、パターンを対象より先に検査する。
#guard endpointIs (rawMakeEndpoint (nm (.one [])) (hn []) 443 0 (-1)) (.error (.invalidPattern (.host (nm (.one [])))))
#guard endpointIs (rawMakeEndpoint examplePattern (hn []) 443 0 (-1)) (.error (.invalidTarget (.host (hn []))))
-- 端点0/65535と一点区間で、閉区間の成功と全欄の保存を確認する。
#guard endpointIs (rawMakeEndpoint examplePattern exampleHost 0 65535 0) (.ok ⟨examplePattern, exampleHost, 0, 65535, 0⟩)
#guard endpointIs (rawMakeEndpoint examplePattern exampleHost 0 65535 65535)
  (.ok ⟨examplePattern, exampleHost, 0, 65535, 65535⟩)
#guard endpointIs (rawMakeEndpoint examplePattern exampleHost 443 443 443)
  (.ok ⟨examplePattern, exampleHost, 443, 443, 443⟩)

private def lan24 : Scope.Domain.HostPattern := .ip (.cidr (Scope.Domain.CIDR.v4 0xC0A80100 24))   -- 192.168.1.0/24
private def lanHost : Scope.Domain.HostTarget := .ip (Scope.Domain.IPAddr.v4 0xC0A80114)            -- 192.168.1.20
private def otherHost : Scope.Domain.HostTarget := .ip (Scope.Domain.IPAddr.v4 0xC0A80214)          -- 192.168.2.20
private def mappedHost : Scope.Domain.HostTarget := .ip (Scope.Domain.IPAddr.v6 0xFFFFC0A80114)     -- ::ffff:192.168.1.20
private def host32 : Scope.Domain.HostPattern := .ip (.cidr (Scope.Domain.CIDR.v4 0xC0A80114 32))  -- 192.168.1.20/32
private def hostExact : Scope.Domain.HostPattern := .ip (.exact (Scope.Domain.IPAddr.v4 0xC0A80114)) -- 192.168.1.20

-- CIDR の所属。区間の外の同族のアドレスは outsideScope になる。
#guard hostIs (rawMakeHost lan24 lanHost) (.ok ⟨lan24, lanHost⟩)
#guard hostIs (rawMakeHost lan24 otherHost) (.error (.outsideScope (.host lan24) (.host otherHost)))
-- IPv4 を射影した IPv6 アドレスは IPv4 の CIDR に所属しない。
#guard hostIs (rawMakeHost lan24 mappedHost) (.error (.outsideScope (.host lan24) (.host mappedHost)))
-- host bits が 0 でない CIDR は不正なパターンである。
#guard hostIs (rawMakeHost (.ip (.cidr (Scope.Domain.CIDR.v4 0xC0A80105 24))) lanHost)
  (.error (.invalidPattern (.host (.ip (.cidr (Scope.Domain.CIDR.v4 0xC0A80105 24))))))
-- `/32` と完全一致は同じ対象について同じ成否を返し、正規化の後に同じパターンになる。
#guard hostIs (rawMakeHost host32 lanHost) (.ok ⟨host32, lanHost⟩)
#guard hostIs (rawMakeHost hostExact lanHost) (.ok ⟨hostExact, lanHost⟩)
#guard host32.normalize == hostExact
-- ホスト名と IP は互いに所属しない。全数字のホスト名は対象として不正であり、IP の対象としては受理する。
#guard hostIs (rawMakeHost (nm (.exact ["localhost"])) lanHost)
  (.error (.outsideScope (.host (nm (.exact ["localhost"]))) (.host lanHost)))
#guard hostIs (rawMakeHost lan24 (hn ["localhost"])) (.error (.outsideScope (.host lan24) (.host (hn ["localhost"]))))
#guard hostIs (rawMakeHost lan24 (hn ["192", "168", "1", "20"])) (.error (.invalidTarget (.host (hn ["192", "168", "1", "20"]))))
-- IP の対象と CIDR のエンドポイント。
#guard endpointIs (rawMakeEndpoint lan24 lanHost 0 1023 80) (.ok ⟨lan24, lanHost, 0, 1023, 80⟩)
#guard endpointIs (rawMakeEndpoint lan24 mappedHost 0 1023 80)
  (.error (.outsideScope (.host lan24) (.host mappedHost)))
-- 被覆: `/16` は `/24` を覆い、IPv4 の `/0` は射影したアドレスの完全一致を覆わない。
#guard decide ((Scope.Domain.HostPattern.ip (.cidr (Scope.Domain.CIDR.v4 0xC0A80000 16))).Covers lan24)
#guard !decide ((Scope.Domain.HostPattern.ip (.cidr (Scope.Domain.CIDR.v4 0 0))).Covers
  (.ip (.exact (Scope.Domain.IPAddr.v6 0xFFFFC0A80114))))

end Benitoite.Checked.Scope
