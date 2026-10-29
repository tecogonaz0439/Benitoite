import Benitoite.Exchange.Range
import Benitoite.Surface.CheckAccept

/-!
# 交換の形式の観測・拒否の理由・必須の判定の入力と、範囲の入力の検査（L50.2）

corpus 15・sidecar 7 の交換の形式に、次のものを加える（設計書 07-04「交換の形式の版」）。

- 観測: IO の事象が作用した対象（`Scope.Domain.Target`）とその有限列。名前の原子の閉じた範囲の列が観測を許す
  ことの判定 `observationAllowed` と、その健全性（`Eff.Allows`）。
- 拒否の理由: DET-05 の列挙 `CoverFailure`（`notCovered`・`atomicCoverOnly`・`unknownSource`・`budgetExceeded`）と、
  入口の拒否（出現の鍵と理由）。
- 必須の判定の入力（corpus 15 の入力ごとの `scopeAcceptance`）: リテラルのパスのパターンとホストのパターンを
  処理系の解析器が読んだ結果の表と、本体と全体の上限。文字列の解析は形式化の外側であり、表を信頼する。
- 範囲の入力の検査: 範囲が整形式で正規形であること（問4）、プログラムと表の範囲の位置に範囲の変数がないか、
  署名の範囲の変数の番号が上限より小さいこと（問3）。一つの節点の検査は全域の関数で書き、健全性を示す。JSON の
  全体を辿る部分（`Version.lean` の `validateRangeInput`）は `partial` であり、Lean では証明しない（既存の交換の
  読み込みと同じ扱い）。
-/

namespace Benitoite.Exchange
open Lean Benitoite.Scope.Domain Benitoite.Scope.Signature
open Benitoite.Surface.ScopeAccept (CoverFailure)

/-! ## 対象と観測 -/

def encodeHostTarget : HostTarget → Json
  | .name w => Json.mkObj [("name", encodeWord w)]
  | .ip a => Json.mkObj [("ip", encodeIPAddr a)]

def decodeHostTarget (j : Json) : Except String HostTarget := do
  if let .ok w := j.getObjVal? "name" then return .name (← decodeWord w)
  if let .ok a := j.getObjVal? "ip" then return .ip (← decodeIPAddr a)
  throw "unknown host target"

theorem decodeHostTarget_encode (h : HostTarget) : decodeHostTarget (encodeHostTarget h) = .ok h := by
  cases h with
  | name w =>
    show (do let x ← decodeWord (encodeWord w); pure (HostTarget.name x)) = _
    rw [decodeWord_encodeWord]; rfl
  | ip a =>
    show (do let x ← decodeIPAddr (encodeIPAddr a); pure (HostTarget.ip x)) = _
    rw [decodeIPAddr_encodeIPAddr]; rfl

/-- 対象の交換の形。種類の名前を鍵に持つ一つの欄の対象である。 -/
def encodeTarget : Target → Json
  | .path w => Json.mkObj [("path", encodeWord w)]
  | .host h => Json.mkObj [("host", encodeHostTarget h)]
  | .endpoint e => Json.mkObj [("endpoint", Json.mkObj [("host", encodeHostTarget e.host), ("port", encodePort e.port)])]

def decodeTarget (j : Json) : Except String Target := do
  if let .ok w := j.getObjVal? "path" then return .path (← decodeWord w)
  if let .ok h := j.getObjVal? "host" then return .host (← decodeHostTarget h)
  if let .ok e := j.getObjVal? "endpoint" then
    return .endpoint ⟨← decodeHostTarget (← e.getObjVal? "host"), ← decodePort (← e.getObjVal? "port")⟩
  throw "unknown target"

/-- 対象の書き出しと読み込みの往復は元の対象に戻る。 -/
theorem decodeTarget_encode (t : Target) : decodeTarget (encodeTarget t) = .ok t := by
  cases t with
  | path w =>
    show (do let x ← decodeWord (encodeWord w); pure (Target.path x)) = _
    rw [decodeWord_encodeWord]; rfl
  | host h =>
    show (do let x ← decodeHostTarget (encodeHostTarget h); pure (Target.host x)) = _
    rw [decodeHostTarget_encode]; rfl
  | endpoint e =>
    obtain ⟨h, p⟩ := e
    show (do
      let h' ← decodeHostTarget (encodeHostTarget h)
      let p' ← decodePort (encodePort p)
      pure (Target.endpoint ⟨h', p'⟩)) = _
    rw [decodeHostTarget_encode, decodePort_encodePort]; rfl

/-- 欄の余りや別の綴りを残さない読み込み（書き戻した形と一致しない入力は誤りにする）。 -/
def decodeTargetStrict (j : Json) : Except String Target := do
  let t ← decodeTarget j
  if encodeTarget t != j then throw "noncanonical target fields"
  return t

/-- 観測（IO の事象の `obs`。順と重複は意味を持たない）の交換の形。対象の配列である。 -/
def encodeObservation (obs : List Target) : Json := .arr (obs.map encodeTarget).toArray

def decodeObservation (j : Json) : Except String (List Target) := do
  (← j.getArr?).toList.mapM decodeTargetStrict

/-- 読み込みの各要素は `decodeTarget` の結果である（厳密な読み込みは余りの欄を拒否するだけである）。 -/
theorem decodeTargetStrict_ok {j : Json} {t : Target} (h : decodeTargetStrict j = .ok t) : decodeTarget j = .ok t := by
  unfold decodeTargetStrict at h
  cases hd : decodeTarget j with
  | error e => rw [hd] at h; cases h
  | ok t' =>
    rw [hd] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · cases h; rfl

/-- 名前 l の操作の観測が、原子の列（効果の上限の名前の原子）に許されるかの判定。観測の各対象について、同じ名前の
閉じた範囲の原子が種類 k に相対的にその対象を含む（`Range.MemK`）。範囲の変数の原子は許さない。 -/
def observationAllowed (κ : String → Option Kind) (atoms : List Benitoite.Release.Atom) (l : String)
    (obs : List Target) : Bool :=
  match κ l with
  | none => obs.isEmpty
  | some k => obs.all fun t => atoms.any fun a => match a with
    | .name m (.fixed r) => decide (m = l) && decide (r.MemK k t)
    | _ => false

/-- 観測の許可の判定の健全性。原子の列の原子が全て効果 ε に属するなら、許可と判定した観測の各対象を ε が許す
（`Release.Eff.Allows`。L20.6 の観測、L30 の対象健全性の結論の形）。 -/
theorem observationAllowed_sound {κ : String → Option Kind} {atoms : List Benitoite.Release.Atom} {l : String}
    {obs : List Target} {ε : Benitoite.Release.Eff} (hε : ∀ a ∈ atoms, Benitoite.Release.Eff.mem ε a)
    (h : observationAllowed κ atoms l obs = true) : ∀ t ∈ obs, Benitoite.Release.Eff.Allows κ ε l t := by
  intro t ht
  unfold observationAllowed at h
  split at h
  · next hk => simp [List.isEmpty_iff] at h; subst h; cases ht
  · next k hk =>
    obtain ⟨a, ha, hm⟩ := List.any_eq_true.mp (List.all_eq_true.mp h t ht)
    match a, hm with
    | .name m (.fixed r), hm =>
      obtain ⟨hl, hr⟩ := Bool.and_eq_true_iff.mp hm
      have hl := of_decide_eq_true hl
      subst hl
      exact ⟨k, r, hk, hε _ ha, of_decide_eq_true hr⟩

/-! ## 拒否の理由 -/

def encodeCoverFailure : CoverFailure → Json
  | .notCovered => .str "notCovered"
  | .atomicCoverOnly => .str "atomicCoverOnly"
  | .unknownSource => .str "unknownSource"
  | .budgetExceeded => .str "budgetExceeded"

def decodeCoverFailure (j : Json) : Except String CoverFailure :=
  match j with
  | .str "notCovered" => .ok .notCovered
  | .str "atomicCoverOnly" => .ok .atomicCoverOnly
  | .str "unknownSource" => .ok .unknownSource
  | .str "budgetExceeded" => .ok .budgetExceeded
  | _ => .error "unknown cover failure reason"

theorem decodeCoverFailure_encode (f : CoverFailure) : decodeCoverFailure (encodeCoverFailure f) = .ok f := by
  cases f <;> rfl

/-- 理由の名前は四つで互いに異なる（DET-05 の列挙の名前をそのまま使う）。 -/
theorem encodeCoverFailure_injective {f g : CoverFailure} (h : encodeCoverFailure f = encodeCoverFailure g) :
    f = g := by
  have := congrArg decodeCoverFailure h
  rw [decodeCoverFailure_encode, decodeCoverFailure_encode] at this
  exact Except.ok.inj this

/-- 出現の鍵（区間解析と同じ形。定義の名前と先行順の番号）。 -/
def encodeKey (k : Benitoite.Interval.OperationKey) : Json :=
  Json.mkObj [("definition", .str k.definition), ("surfacePreorder", encodeNat k.surfacePreorder)]

/-- 入口の拒否の交換の形。 -/
def encodeEntryError : Benitoite.Surface.CheckAccept.EntryError → Json
  | .typing e => Json.mkObj [("typing", Json.mkObj [("path", toJson e.path), ("reason", .str e.reason)])]
  | .cover k f => Json.mkObj [("cover", Json.mkObj [("key", encodeKey k), ("reason", encodeCoverFailure f)])]

/-! ## 必須の判定の入力 -/

def encodeCap (c : Benitoite.Surface.ScopeState.Cap) : Json :=
  Json.mkObj [("operations", encodeNat c.operations), ("items", encodeNat c.items)]

def decodeCap (j : Json) : Except String Benitoite.Surface.ScopeState.Cap := do
  if (← j.getObj?).toArray.size != 2 then throw "unexpected scope limit fields"
  return ⟨← decodeNat (← j.getObjVal? "operations"), ← decodeNat (← j.getObjVal? "items")⟩

def encodeLimits (L : Benitoite.Surface.ScopeState.Limits) : Json :=
  Json.mkObj [("body", encodeCap L.body), ("whole", encodeCap L.whole)]

def decodeLimits (j : Json) : Except String Benitoite.Surface.ScopeState.Limits := do
  if (← j.getObj?).toArray.size != 2 then throw "unexpected scope limit fields"
  return ⟨← decodeCap (← j.getObjVal? "body"), ← decodeCap (← j.getObjVal? "whole")⟩

/-- リテラルの綴りと、処理系の解析器が読んだ結果の組。 -/
structure PatternEntry where
  text : String
  range : Range

structure HostEntry where
  text : String
  pattern : HostPattern

/-- corpus 15 の入力ごとの必須の判定の入力。 -/
structure ScopeAcceptanceEntry where
  /-- `Scope.checkPathIn` のパターンのリテラルと、それを解析した範囲。 -/
  patterns : List PatternEntry
  /-- `Http.checkRequestIn` のホストのパターンのリテラルと、それを解析したホストのパターン。 -/
  hosts : List HostEntry
  limits : Benitoite.Surface.ScopeState.Limits

instance : ToJson ScopeAcceptanceEntry := ⟨fun s => Json.mkObj [
  ("patterns", .arr (s.patterns.map fun p => Json.mkObj [("text", .str p.text), ("range", encodeRange p.range)]).toArray),
  ("hosts", .arr (s.hosts.map fun h => Json.mkObj [("text", .str h.text), ("pattern", encodeHostPattern h.pattern)]).toArray),
  ("limits", encodeLimits s.limits)]⟩

/-- 欄の欠落と余りを拒否し、範囲の正規形を確かめる前の値を読む（正規形は `validateRangeInput` が確かめる）。 -/
instance : FromJson ScopeAcceptanceEntry := ⟨fun j => do
  if (← j.getObj?).toArray.size != 3 then throw "unexpected scopeAcceptance fields"
  let patterns ← (← (← j.getObjVal? "patterns").getArr?).toList.mapM fun p => do
    if (← p.getObj?).toArray.size != 2 then throw "unexpected scope pattern fields"
    return (⟨← p.getObjValAs? String "text", ← decodeRange (← p.getObjVal? "range")⟩ : PatternEntry)
  let hosts ← (← (← j.getObjVal? "hosts").getArr?).toList.mapM fun h => do
    if (← h.getObj?).toArray.size != 2 then throw "unexpected scope host fields"
    return (⟨← h.getObjValAs? String "text", ← decodeHostPattern (← h.getObjVal? "pattern")⟩ : HostEntry)
  if (patterns.map (·.text)).eraseDups.length != patterns.length ||
      (hosts.map (·.text)).eraseDups.length != hosts.length then
    throw "duplicate scope pattern text"
  return ⟨patterns, hosts, ← decodeLimits (← j.getObjVal? "limits")⟩⟩

/-- パスのパターンの解析の表。表にない綴りは解析できない（`none`）。 -/
def ScopeAcceptanceEntry.pattern (s : ScopeAcceptanceEntry) (text : String) : Option Range :=
  (s.patterns.find? (·.text == text)).map (·.range)

def ScopeAcceptanceEntry.host (s : ScopeAcceptanceEntry) (text : String) : Option HostPattern :=
  (s.hosts.find? (·.text == text)).map (·.pattern)

/-- 交換の入力から作る受理の入力。規則は本番の実例の表の δ による六項目（`ScopeSound.productionRules`）であり、
受理は規則の添字と事実の転送だけを読む（実行の δ は読まない）。旧版の入力（範囲を持たない）は規則のない受理の
入力（旧の像）で読む。 -/
def ScopeAcceptanceEntry.acceptInput : Option ScopeAcceptanceEntry → Benitoite.Surface.CheckAccept.AcceptInput
  | none => Benitoite.Surface.CheckAccept.AcceptInput.noRules
  | some s =>
    ⟨"Ok", (Benitoite.Surface.ScopeSound.productionRules s.pattern (fun _ => none) s.host (fun _ => none)).lookup,
      s.limits, fun i m => i ++ "." ++ m⟩

/-- 交換の入力から作る規則の表は健全である（条件はない）。接続定理（`CheckAccept.accepted_check_connection`）の
前提の一つである。 -/
theorem ScopeAcceptanceEntry.acceptInput_sound (s : ScopeAcceptanceEntry) :
    ∃ R : Benitoite.Surface.ScopeState.Rules,
      R.Sound (Benitoite.Surface.ScopeState.models (ScopeAcceptanceEntry.acceptInput (some s)).ok
        ⟨s.pattern, fun _ => none⟩) ∧
      (ScopeAcceptanceEntry.acceptInput (some s)).rules = R.lookup :=
  ⟨_, Benitoite.Surface.ScopeSound.productionRules_sound s.pattern (fun _ => none) s.host (fun _ => none), rfl⟩

/-- 旧版の入力は規則のない受理の入力で読み、入口は型付けの検査と同じ結果を返す（`checkProgramAccepted_noRules`）。 -/
theorem ScopeAcceptanceEntry.acceptInput_none_noRules (d : String) :
    (ScopeAcceptanceEntry.acceptInput none).rules d = none := rfl

/-! ## 範囲の入力の検査（一つの節点） -/

/-- 範囲が整形式で正規形であること（問4）。 -/
def checkRangeInput (r : Range) : Except String Unit :=
  if r.WF ∧ r.Canonical then .ok () else .error "range is not well formed or not canonical"

theorem checkRangeInput_sound {r : Range} (h : checkRangeInput r = .ok ()) : r.WF ∧ r.Canonical := by
  unfold checkRangeInput at h
  split at h
  · assumption
  · cases h

theorem checkRangeInput_complete {r : Range} (h : r.WF ∧ r.Canonical) : checkRangeInput r = .ok () := by
  simp [checkRangeInput, h]

/-- 範囲の位置の検査。範囲の変数の番号は上限 n より小さく（問3。プログラムと表の型は n = 0）、閉じた範囲は整形式で
正規形である。 -/
def checkIxInput (n : Nat) : Ix → Except String Unit
  | .fixed r => checkRangeInput r
  | .rvar i => if i < n then .ok () else .error "range variable index out of bounds"

theorem checkIxInput_sound {n : Nat} {ix : Ix} (h : checkIxInput n ix = .ok ()) :
    ix.WF n ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical := by
  cases ix with
  | fixed r =>
    exact ⟨trivial, fun r' he => by cases he; exact checkRangeInput_sound h⟩
  | rvar i =>
    by_cases hi : i < n
    · exact ⟨hi, fun _ he => by cases he⟩
    · simp [checkIxInput, hi] at h

/-- 上限 0 で検査した範囲の位置は閉じた範囲である（プログラムの型に範囲の変数がない。問3）。 -/
theorem checkIxInput_zero {ix : Ix} (h : checkIxInput 0 ix = .ok ()) : ∃ r, ix = .fixed r := by
  cases ix with
  | fixed r => exact ⟨r, rfl⟩
  | rvar i => simp [checkIxInput] at h

/-- 表の `admitsR` の規則の範囲の変数の番号が、項目の範囲の変数の個数より小さいこと。 -/
def checkAdmitsRuleInput (n : Nat) : AdmitsRule → Except String Unit
  | .any => .ok ()
  | .covers i j => if i < n ∧ j < n then .ok () else .error "admitsR range index out of bounds"

theorem checkAdmitsRuleInput_sound {n : Nat} {i j : Nat} (h : checkAdmitsRuleInput n (.covers i j) = .ok ()) :
    i < n ∧ j < n := by
  by_cases hij : i < n ∧ j < n
  · exact hij
  · simp only [checkAdmitsRuleInput, hij, ↓reduceIte, reduceCtorEq] at h

end Benitoite.Exchange
