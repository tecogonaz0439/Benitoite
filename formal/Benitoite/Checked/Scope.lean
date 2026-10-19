import Std

/-!
# Scopeの解析済み入力についての独立した小モデル

文字列の解析・小文字化を済ませた要素列を扱う。妥当性の検査はこの表現での
前提を明示するために置き、元の文字列のparserの正しさは仮定しない。
字面の所属から操作の許可やIOの成功は導かない
（設計書 01-12「検査済みの値の独立した小モデル」）。
-/
namespace Benitoite.Checked.Scope

abbrev Word := List String

inductive HostPattern where
  | exact (stem : Word)
  | one (stem : Word)
  | many (stem : Word)
  deriving DecidableEq, Repr

inductive PathPattern where
  | exact (stem : Word)
  | tree (stem : Word)
  deriving DecidableEq, Repr

def HostMatches : HostPattern → Word → Prop
  | .exact s, h => h = s
  | .one s, h => ∃ x, h = x :: s
  | .many s, h => ∃ xs, xs ≠ [] ∧ h = xs ++ s

def PathMatches : PathPattern → Word → Prop
  | .exact s, p => p = s
  | .tree s, p => ∃ rest, p = s ++ rest

def hostMatch : HostPattern → Word → Bool
  | .exact s, h => decide (h = s)
  | .one _, [] => false
  | .one s, _ :: tail => decide (tail = s)
  | .many s, h => s.isSuffixOf h && decide (s.length < h.length)

def pathMatch : PathPattern → Word → Bool
  | .exact s, p => decide (p = s)
  | .tree s, p => s.isPrefixOf p

theorem hostMatch_spec (p : HostPattern) (h : Word) :
    hostMatch p h = true ↔ HostMatches p h := by
  cases p with
  | exact s => simp [hostMatch, HostMatches]
  | one s => cases h <;> simp [hostMatch, HostMatches]
  | many s =>
    simp only [hostMatch, Bool.and_eq_true, List.isSuffixOf_iff_suffix,
      decide_eq_true_eq, List.IsSuffix, HostMatches]
    constructor
    · rintro ⟨⟨xs, hx⟩, hl⟩
      refine ⟨xs, ?_, hx.symm⟩
      intro he; subst xs; simp_all
    · rintro ⟨xs, hx, rfl⟩
      refine ⟨⟨xs, rfl⟩, ?_⟩
      have : 0 < xs.length := List.length_pos_iff.mpr hx
      simp only [List.length_append]; omega

theorem pathMatch_spec (p : PathPattern) (target : Word) :
    pathMatch p target = true ↔ PathMatches p target := by
  cases p with
  | exact s => simp [pathMatch, PathMatches]
  | tree s =>
    simp only [pathMatch, List.isPrefixOf_iff_prefix, List.IsPrefix, PathMatches]
    exact exists_congr fun _ => eq_comm

instance (p : HostPattern) (h : Word) : Decidable (HostMatches p h) :=
  decidable_of_iff (hostMatch p h = true) (hostMatch_spec p h)

instance (p : PathPattern) (h : Word) : Decidable (PathMatches p h) :=
  decidable_of_iff (pathMatch p h = true) (pathMatch_spec p h)

-- 正規化後だけを扱うため、大文字と区切り文字はラベルに含めない。
def lowerAlphaNumeric (c : Char) : Bool :=
  decide (('a' ≤ c ∧ c ≤ 'z') ∨ ('0' ≤ c ∧ c ≤ '9'))

def ValidHostLabel (s : String) : Prop :=
  s ≠ "" ∧ s.toList.head? ≠ some '-' ∧ s.toList.getLast? ≠ some '-' ∧
    s.toList.all (fun c => lowerAlphaNumeric c || c == '-') = true

instance (s : String) : Decidable (ValidHostLabel s) := by
  unfold ValidHostLabel; infer_instance

def IPv4Word (w : Word) : Prop :=
  w.length = 4 ∧ w.all (fun s => !s.isEmpty && s.toList.all Char.isDigit) = true

instance (w : Word) : Decidable (IPv4Word w) := by
  unfold IPv4Word; infer_instance

def ValidHostWord (w : Word) : Prop :=
  w ≠ [] ∧ (∀ s ∈ w, ValidHostLabel s) ∧ ¬ IPv4Word w

instance (w : Word) : Decidable (ValidHostWord w) := by
  unfold ValidHostWord; infer_instance

def ValidHostPattern : HostPattern → Prop
  | .exact s | .one s | .many s => ValidHostWord s

instance (p : HostPattern) : Decidable (ValidHostPattern p) := by
  cases p <;> unfold ValidHostPattern <;> infer_instance

-- []は根「/」であり、空の要素を含むパスとは区別する。
def ValidPathPart (s : String) : Prop :=
  s ≠ "" ∧ s ≠ "." ∧ s ≠ ".." ∧
    s.toList.all (fun c => c != '/' && c != '\\' && c != '\x00') = true

instance (s : String) : Decidable (ValidPathPart s) := by
  unfold ValidPathPart; infer_instance

def ValidPathWord (w : Word) : Prop := ∀ s ∈ w, ValidPathPart s

instance (w : Word) : Decidable (ValidPathWord w) := by
  unfold ValidPathWord; infer_instance

def ValidPathPattern : PathPattern → Prop
  | .exact s | .tree s =>
    ValidPathWord s ∧ ∀ part ∈ s, part.toList.all (fun c => c != '*') = true

instance (p : PathPattern) : Decidable (ValidPathPattern p) := by
  cases p <;> unfold ValidPathPattern <;> infer_instance

def PortBounds (lo hi : Int) : Prop := 0 ≤ lo ∧ lo ≤ hi ∧ hi ≤ 65535
def ValidPort (port : Int) : Prop := 0 ≤ port ∧ port ≤ 65535
def PortMatches (lo hi port : Int) : Prop := lo ≤ port ∧ port ≤ hi

instance (lo hi : Int) : Decidable (PortBounds lo hi) := by
  unfold PortBounds; infer_instance
instance (port : Int) : Decidable (ValidPort port) := by
  unfold ValidPort; infer_instance
instance (lo hi port : Int) : Decidable (PortMatches lo hi port) := by
  unfold PortMatches; infer_instance

/-- パターンの種類を保つ。元の字面とparserのreasonは本モデルの外側である。 -/
inductive Pattern where
  | host (pattern : HostPattern)
  | path (pattern : PathPattern)
  deriving DecidableEq, Repr

inductive ScopeError where
  | invalidPattern (pattern : Pattern)
  | invalidTarget (target : Word)
  | invalidPortRange (minimum maximum : Int)
  | invalidPort (port : Int)
  | outsideScope (pattern : Pattern) (target : Word)
  | portOutsideScope (minimum maximum port : Int)
  deriving DecidableEq, Repr

structure RawHost where
  pattern : HostPattern
  target : Word
  deriving DecidableEq, Repr
structure CheckedHost extends RawHost where
  patternValid : ValidHostPattern pattern
  targetValid : ValidHostWord target
  membership : HostMatches pattern target

structure RawPath where
  pattern : PathPattern
  target : Word
  deriving DecidableEq, Repr
structure CheckedPath extends RawPath where
  patternValid : ValidPathPattern pattern
  targetValid : ValidPathWord target
  membership : PathMatches pattern target

structure RawEndpoint where
  hostPattern : HostPattern
  host : Word
  minimumPort : Int
  maximumPort : Int
  port : Int
  deriving DecidableEq, Repr
structure CheckedEndpoint extends RawEndpoint where
  patternValid : ValidHostPattern hostPattern
  targetValid : ValidHostWord host
  bounds : PortBounds minimumPort maximumPort
  portValid : ValidPort port
  hostMatches : HostMatches hostPattern host
  portMatches : PortMatches minimumPort maximumPort port

def eraseHost (v : CheckedHost) : RawHost := v.toRawHost
def erasePath (v : CheckedPath) : RawPath := v.toRawPath
def eraseEndpoint (v : CheckedEndpoint) : RawEndpoint := v.toRawEndpoint

def makeHost (p : HostPattern) (target : Word) : Except ScopeError CheckedHost :=
  if hp : ValidHostPattern p then
    if ht : ValidHostWord target then
      if hm : HostMatches p target then .ok ⟨⟨p, target⟩, hp, ht, hm⟩
      else .error (.outsideScope (.host p) target)
    else .error (.invalidTarget target)
  else .error (.invalidPattern (.host p))

def rawMakeHost (p : HostPattern) (target : Word) : Except ScopeError RawHost :=
  if ValidHostPattern p then
    if ValidHostWord target then
      if HostMatches p target then .ok ⟨p, target⟩
      else .error (.outsideScope (.host p) target)
    else .error (.invalidTarget target)
  else .error (.invalidPattern (.host p))

def makePath (p : PathPattern) (target : Word) : Except ScopeError CheckedPath :=
  if hp : ValidPathPattern p then
    if ht : ValidPathWord target then
      if hm : PathMatches p target then .ok ⟨⟨p, target⟩, hp, ht, hm⟩
      else .error (.outsideScope (.path p) target)
    else .error (.invalidTarget target)
  else .error (.invalidPattern (.path p))

def rawMakePath (p : PathPattern) (target : Word) : Except ScopeError RawPath :=
  if ValidPathPattern p then
    if ValidPathWord target then
      if PathMatches p target then .ok ⟨p, target⟩
      else .error (.outsideScope (.path p) target)
    else .error (.invalidTarget target)
  else .error (.invalidPattern (.path p))

def makeEndpoint (p : HostPattern) (target : Word) (lo hi port : Int) :
    Except ScopeError CheckedEndpoint :=
  if hp : ValidHostPattern p then
    if ht : ValidHostWord target then
      if hb : PortBounds lo hi then
        if hv : ValidPort port then
          if hm : HostMatches p target then
            if hr : PortMatches lo hi port then
              .ok ⟨⟨p, target, lo, hi, port⟩, hp, ht, hb, hv, hm, hr⟩
            else .error (.portOutsideScope lo hi port)
          else .error (.outsideScope (.host p) target)
        else .error (.invalidPort port)
      else .error (.invalidPortRange lo hi)
    else .error (.invalidTarget target)
  else .error (.invalidPattern (.host p))

def rawMakeEndpoint (p : HostPattern) (target : Word) (lo hi port : Int) :
    Except ScopeError RawEndpoint :=
  if ValidHostPattern p then
    if ValidHostWord target then
      if PortBounds lo hi then
        if ValidPort port then
          if HostMatches p target then
            if PortMatches lo hi port then .ok ⟨p, target, lo, hi, port⟩
            else .error (.portOutsideScope lo hi port)
          else .error (.outsideScope (.host p) target)
        else .error (.invalidPort port)
      else .error (.invalidPortRange lo hi)
    else .error (.invalidTarget target)
  else .error (.invalidPattern (.host p))

theorem makeHost_ok (p : HostPattern) (target : Word) (v : CheckedHost)
    (h : makeHost p target = .ok v) :
    v.pattern = p ∧ v.target = target ∧ HostMatches p target ∧
      ValidHostPattern p ∧ ValidHostWord target := by
  unfold makeHost at h
  split at h <;> (try split at h) <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, ‹HostMatches p target›, ‹ValidHostPattern p›, ‹ValidHostWord target›⟩

theorem makePath_ok (p : PathPattern) (target : Word) (v : CheckedPath)
    (h : makePath p target = .ok v) :
    v.pattern = p ∧ v.target = target ∧ PathMatches p target ∧
      ValidPathPattern p ∧ ValidPathWord target := by
  unfold makePath at h
  split at h <;> (try split at h) <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, ‹PathMatches p target›, ‹ValidPathPattern p›, ‹ValidPathWord target›⟩

theorem makeEndpoint_ok (p : HostPattern) (target : Word) (lo hi port : Int)
    (v : CheckedEndpoint) (h : makeEndpoint p target lo hi port = .ok v) :
    v.hostPattern = p ∧ v.host = target ∧ v.minimumPort = lo ∧
      v.maximumPort = hi ∧ v.port = port ∧ HostMatches p target ∧
      PortBounds lo hi ∧ PortMatches lo hi port ∧ ValidPort port ∧
      ValidHostPattern p ∧ ValidHostWord target := by
  unfold makeEndpoint at h
  split at h <;> (try split at h) <;> (try split at h) <;>
    (try split at h) <;> (try split at h) <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, rfl, rfl, rfl, ‹HostMatches p target›, ‹PortBounds lo hi›, ‹PortMatches lo hi port›,
    ‹ValidPort port›, ‹ValidHostPattern p›, ‹ValidHostWord target›⟩

theorem makeHost_success_iff (p : HostPattern) (target : Word) :
    (∃ v, makeHost p target = .ok v) ↔
      ValidHostPattern p ∧ ValidHostWord target ∧ HostMatches p target := by
  constructor
  · rintro ⟨v, hv⟩
    obtain ⟨_, _, hm, hp, ht⟩ := makeHost_ok p target v hv
    exact ⟨hp, ht, hm⟩
  · rintro ⟨hp, ht, hm⟩; simp [makeHost, hp, ht, hm]

theorem makePath_success_iff (p : PathPattern) (target : Word) :
    (∃ v, makePath p target = .ok v) ↔
      ValidPathPattern p ∧ ValidPathWord target ∧ PathMatches p target := by
  constructor
  · rintro ⟨v, hv⟩
    obtain ⟨_, _, hm, hp, ht⟩ := makePath_ok p target v hv
    exact ⟨hp, ht, hm⟩
  · rintro ⟨hp, ht, hm⟩; simp [makePath, hp, ht, hm]

theorem makeEndpoint_success_iff (p : HostPattern) (target : Word) (lo hi port : Int) :
    (∃ v, makeEndpoint p target lo hi port = .ok v) ↔
      ValidHostPattern p ∧ ValidHostWord target ∧ PortBounds lo hi ∧
      ValidPort port ∧ HostMatches p target ∧ PortMatches lo hi port := by
  constructor
  · rintro ⟨v, hv⟩
    obtain ⟨_, _, _, _, _, hm, hb, hr, hv, hp, ht⟩ := makeEndpoint_ok p target lo hi port v hv
    exact ⟨hp, ht, hb, hv, hm, hr⟩
  · rintro ⟨hp, ht, hb, hv, hm, hr⟩; simp [makeEndpoint, hp, ht, hb, hv, hm, hr]

theorem makeHost_invalidPattern_iff (p : HostPattern) (target : Word) :
    makeHost p target = .error (.invalidPattern (.host p)) ↔ ¬ ValidHostPattern p := by
  unfold makeHost
  split <;> (try split) <;> (try split) <;> simp_all

theorem makeHost_invalidTarget_iff (p : HostPattern) (target : Word) :
    makeHost p target = .error (.invalidTarget target) ↔
      ValidHostPattern p ∧ ¬ ValidHostWord target := by
  unfold makeHost
  split <;> (try split) <;> (try split) <;> simp_all

theorem makePath_invalidPattern_iff (p : PathPattern) (target : Word) :
    makePath p target = .error (.invalidPattern (.path p)) ↔ ¬ ValidPathPattern p := by
  unfold makePath
  split <;> (try split) <;> (try split) <;> simp_all

theorem makePath_invalidTarget_iff (p : PathPattern) (target : Word) :
    makePath p target = .error (.invalidTarget target) ↔
      ValidPathPattern p ∧ ¬ ValidPathWord target := by
  unfold makePath
  split <;> (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_invalidPattern_iff (p : HostPattern) (target : Word) (lo hi port : Int) :
    makeEndpoint p target lo hi port = .error (.invalidPattern (.host p)) ↔
      ¬ ValidHostPattern p := by
  unfold makeEndpoint
  split <;> (try split) <;> (try split) <;> (try split) <;>
    (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_invalidTarget_iff (p : HostPattern) (target : Word) (lo hi port : Int) :
    makeEndpoint p target lo hi port = .error (.invalidTarget target) ↔
      ValidHostPattern p ∧ ¬ ValidHostWord target := by
  unfold makeEndpoint
  split <;> (try split) <;> (try split) <;> (try split) <;>
    (try split) <;> (try split) <;> simp_all

theorem makeHost_error_iff (p : HostPattern) (target : Word)
    (hp : ValidHostPattern p) (ht : ValidHostWord target) :
    makeHost p target = .error (.outsideScope (.host p) target) ↔ ¬ HostMatches p target := by
  simp [makeHost, hp, ht]

theorem makePath_error_iff (p : PathPattern) (target : Word)
    (hp : ValidPathPattern p) (ht : ValidPathWord target) :
    makePath p target = .error (.outsideScope (.path p) target) ↔ ¬ PathMatches p target := by
  simp [makePath, hp, ht]

theorem makeEndpoint_invalidBounds_iff (p : HostPattern) (target : Word) (lo hi port : Int)
    (hp : ValidHostPattern p) (ht : ValidHostWord target) :
    makeEndpoint p target lo hi port = .error (.invalidPortRange lo hi) ↔ ¬ PortBounds lo hi := by
  simp only [makeEndpoint, dite_eq_left hp, dite_eq_left ht]
  split <;> (try split) <;> (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_invalidPort_iff (p : HostPattern) (target : Word) (lo hi port : Int)
    (hp : ValidHostPattern p) (ht : ValidHostWord target) (hb : PortBounds lo hi) :
    makeEndpoint p target lo hi port = .error (.invalidPort port) ↔ ¬ ValidPort port := by
  simp only [makeEndpoint, dite_eq_left hp, dite_eq_left ht, dite_eq_left hb]
  split <;> (try split) <;> (try split) <;> simp_all

theorem makeEndpoint_outside_iff (p : HostPattern) (target : Word) (lo hi port : Int)
    (hp : ValidHostPattern p) (ht : ValidHostWord target) (hb : PortBounds lo hi)
    (hv : ValidPort port) :
    (makeEndpoint p target lo hi port = .error (.outsideScope (.host p) target) ↔
      ¬ HostMatches p target) ∧
    (makeEndpoint p target lo hi port = .error (.portOutsideScope lo hi port) ↔
      HostMatches p target ∧ ¬ PortMatches lo hi port) := by
  simp only [makeEndpoint, dite_eq_left hp, dite_eq_left ht, dite_eq_left hb, dite_eq_left hv]
  split <;> (try split) <;> simp_all

theorem erase_makeHost (p : HostPattern) (target : Word) :
    (makeHost p target).map eraseHost = rawMakeHost p target := by
  unfold makeHost rawMakeHost
  split <;> (try split) <;> (try split) <;> rfl

theorem erase_makePath (p : PathPattern) (target : Word) :
    (makePath p target).map erasePath = rawMakePath p target := by
  unfold makePath rawMakePath
  split <;> (try split) <;> (try split) <;> rfl

theorem erase_makeEndpoint (p : HostPattern) (target : Word) (lo hi port : Int) :
    (makeEndpoint p target lo hi port).map eraseEndpoint = rawMakeEndpoint p target lo hi port := by
  unfold makeEndpoint rawMakeEndpoint
  split <;> (try split) <;> (try split) <;> (try split) <;>
    (try split) <;> (try split) <;> rfl

def host (v : CheckedHost) : Word := v.target
def hostPattern (v : CheckedHost) : HostPattern := v.pattern
def path (v : CheckedPath) : Word := v.target
def pathPattern (v : CheckedPath) : PathPattern := v.pattern
def endpointHost (v : CheckedEndpoint) : Word := v.host
def endpointHostPattern (v : CheckedEndpoint) : HostPattern := v.hostPattern
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

theorem one_excludes_apex (s : Word) : ¬ HostMatches (.one s) s := by
  rintro ⟨x, hx⟩
  have := congrArg List.length hx
  simp only [List.length_cons] at this; omega

theorem one_excludes_deep (s extra : Word) (h : 2 ≤ extra.length) :
    ¬ HostMatches (.one s) (extra ++ s) := by
  rintro ⟨x, hx⟩
  have := congrArg List.length hx
  simp only [List.length_cons, List.length_append] at this; omega

theorem many_excludes_apex (s : Word) : ¬ HostMatches (.many s) s := by
  rintro ⟨xs, hx, he⟩
  have := congrArg List.length he
  have := List.length_pos_iff.mpr hx
  simp only [List.length_append] at *; omega

theorem path_tree_includes_self (s : Word) : PathMatches (.tree s) s :=
  ⟨[], (List.append_nil s).symm⟩

/-- 同じCheckedHost型だけでは、別の条件への所属を導けない。 -/
theorem unindexed_policy_counterexample :
    ∃ v : CheckedHost, ValidHostPattern (.exact ["other", "example", "com"]) ∧
      ¬ HostMatches (.exact ["other", "example", "com"]) v.target := by
  refine ⟨⟨⟨.one ["example", "com"], ["api", "example", "com"]⟩,
    by decide, by decide, by decide⟩, by decide, by decide⟩

-- 正規化済みホストの文法。IPv4形式は数字の値の範囲によらず拒否する。
example : ValidHostWord ["localhost"] ∧
    ¬ ValidHostWord [] ∧ ¬ ValidHostWord ["api", "", "com"] ∧
    ¬ ValidHostWord ["-api", "example", "com"] ∧
    ¬ ValidHostWord ["api-", "example", "com"] ∧
    ¬ ValidHostWord ["API", "example", "com"] ∧
    ¬ ValidHostWord ["日本語", "example", "com"] ∧
    ¬ ValidHostWord ["999", "999", "999", "999"] := by decide

-- 一段と多段を同じtreeとして扱う誤りを区別する。
example : hostMatch (.one ["example", "com"]) ["api", "example", "com"] = true ∧
    hostMatch (.one ["example", "com"]) ["a", "b", "example", "com"] = false ∧
    hostMatch (.many ["example", "com"]) ["api", "example", "com"] = true ∧
    hostMatch (.many ["example", "com"]) ["a", "b", "example", "com"] = true ∧
    hostMatch (.many ["example", "com"]) ["example", "com"] = false := by decide

-- 根は空列。対象内の*は普通の文字だが、パターンの幹には書けない。
example : ValidPathWord [] ∧ ¬ ValidPathWord [""] ∧
    ¬ ValidPathWord ["data", ".."] ∧ ¬ ValidPathWord ["data\\reports"] ∧
    ¬ ValidPathWord ["data\x00reports"] ∧
    ValidPathWord ["資料", "*.txt"] ∧
    ¬ ValidPathPattern (.exact ["資料", "*.txt"]) ∧
    pathMatch (.tree []) [] = true ∧
    pathMatch (.tree []) ["data"] = true ∧
    pathMatch (.tree ["data", "reports"]) ["data", "reports"] = true ∧
    pathMatch (.tree ["data", "reports"]) ["data", "reports", "日報"] = true ∧
    pathMatch (.tree ["data", "reports"]) ["data", "reports-old"] = false := by decide

-- 証拠を消した返り値で、正規化済みの条件とUnicode対象の保存を確認する。
example : (makeHost (.one ["example", "com"]) ["api", "example", "com"]).map eraseHost =
    .ok ⟨.one ["example", "com"], ["api", "example", "com"]⟩ := by
  rw [erase_makeHost]; rfl
example : (makePath (.tree ["資料"]) ["資料", "*.txt"]).map erasePath =
    .ok ⟨.tree ["資料"], ["資料", "*.txt"]⟩ := by
  rw [erase_makePath]; rfl

private def examplePattern : HostPattern := .many ["example", "com"]
private def exampleHost : Word := ["a", "b", "example", "com"]

-- 負数と上限超過は、ホストの所属を調べる前にInvalidPortとなる。
example : makeEndpoint examplePattern ["elsewhere"] 0 65535 (-1) = .error (.invalidPort (-1)) := rfl
example : makeEndpoint examplePattern ["elsewhere"] 0 65535 70000 = .error (.invalidPort 70000) := rfl
-- 端点も不正ならInvalidPortRangeが先である。
example : makeEndpoint examplePattern exampleHost 443 0 70000 =
    .error (.invalidPortRange 443 0) := rfl
-- 両方の所属に失敗すると、ホスト側の失敗を先に返す。
example : makeEndpoint examplePattern ["elsewhere"] 443 443 444 =
    .error (.outsideScope (.host examplePattern) ["elsewhere"]) := rfl
example : makeEndpoint examplePattern exampleHost 443 443 444 =
    .error (.portOutsideScope 443 443 444) := rfl
-- 形式の失敗は端点よりも先であり、パターンを対象より先に検査する。
example : makeEndpoint (.one []) [] 443 0 (-1) =
    .error (.invalidPattern (.host (.one []))) := rfl
example : makeEndpoint examplePattern [] 443 0 (-1) = .error (.invalidTarget []) := rfl

-- 端点0/65535と一点区間で、閉区間の成功と全欄の保存を確認する。
example : (makeEndpoint examplePattern exampleHost 0 65535 0).map eraseEndpoint =
    .ok ⟨examplePattern, exampleHost, 0, 65535, 0⟩ := by rw [erase_makeEndpoint]; rfl
example : (makeEndpoint examplePattern exampleHost 0 65535 65535).map eraseEndpoint =
    .ok ⟨examplePattern, exampleHost, 0, 65535, 65535⟩ := by rw [erase_makeEndpoint]; rfl
example : (makeEndpoint examplePattern exampleHost 443 443 443).map eraseEndpoint =
    .ok ⟨examplePattern, exampleHost, 443, 443, 443⟩ := by rw [erase_makeEndpoint]; rfl

end Benitoite.Checked.Scope
