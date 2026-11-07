import Benitoite.Release.Refinement.Admissible
import Benitoite.Release.Refinement.TargetText

/-! # 解析済みの対象と要求の端点

文字列の字句解析の実装との一致は供給境界で照合する。OSや実行のσは読まない。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

def Val.reqTarget : Val → Option Target
  | .con "Http.ClientRequest" _ [_, .const (.string url), _, _, _] => parseUrlTarget url
  | _ => none

/-- HTTPS のループバック URL は、同じ IP と既定のポートを返す。 -/
theorem parseUrlTarget_https_loopback : parseUrlTarget "https://127.0.0.1/" =
    some (.endpoint ⟨.ip (.v4 2130706433 (by decide)),⟨443,by decide⟩⟩) := by
  have lower : "https://127.0.0.1/".toLower = "https://127.0.0.1/" := by decide +kernel
  simp +decide [parseUrlTarget,urlAuthority,lower,urlAlphabet,parseAuthority,parseHost,isIPv4MappedHost,
    parseIPv4,splitText,splitChars,parseNatDec,urlPort,numericHost]

/-- 末尾の空ラベルを持つホストは URL の対象にならない。 -/
theorem parseUrlTarget_trailing_dot : parseUrlTarget "https://example.com./" = none := by
  have lower : "https://example.com./".toLower = "https://example.com./" := by decide +kernel
  have hostLower : "example.com.".toLower = "example.com." := by decide +kernel
  simp +decide [parseUrlTarget,urlAuthority,lower,urlAlphabet,parseAuthority,parseHost,
    parseIPv4,splitText,splitChars,parseNatDec,urlPort,numericHost,hostLower,NameWordWF]

/-- DNS 名の URL は元の名前を正規化した端点を返す。 -/
theorem parseUrlTarget_example (secure : Bool) :
    parseUrlTarget (if secure then "https://example.com/" else "http://example.com/") =
      some (.endpoint ⟨.name ["example","com"],⟨if secure then 443 else 80,by cases secure <;> decide⟩⟩) := by
  have lower₁ : "https://example.com/".toLower = "https://example.com/" := by decide +kernel
  have lower₂ : "http://example.com/".toLower = "http://example.com/" := by decide +kernel
  have hostLower : "example.com".toLower = "example.com" := by decide +kernel
  cases secure <;>
    simp +decide [parseUrlTarget,urlAuthority,lower₁,lower₂,urlAlphabet,parseAuthority,parseHost,
      parseIPv4,splitText,splitChars,parseNatDec,urlPort,numericHost,hostLower,
      NameWordWF,NameLabelWF,FourDigitLabels,isIPv4MappedHost]

theorem parseUrlTarget_kind {s t} (h : parseUrlTarget s = some t) : t.kind = .endpoint := by
  obtain ⟨⟨authority,port⟩,_,ht⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨target,_,ht⟩ := Option.bind_eq_some_iff.mp ht
  cases target <;> simp only at ht
  all_goals first | cases ht | split at ht <;> cases ht <;> rfl

theorem Val.reqTarget_kind {v : Val} {t : Target} (h : v.reqTarget = some t) : t.kind = .endpoint := by
  unfold Val.reqTarget at h
  split at h
  · exact parseUrlTarget_kind h
  · cases h

def Val.target? : Val → Option Target
  | .checked t | .checkedRequest t _ | .checkedAt _ _ t _ => some t
  | _ => none

def parseAtInput (k : Kind) (v : Val) : Option TargetInput :=
  match v with
  | .const (.string s) => parseTargetInput k s
  | _ => v.reqTarget.map TargetInput.absolute

/-- ホストのループバック字句を、パターンの解析にも同じ対象として渡す。 -/
theorem parseAtInput_host_loopback : parseAtInput .host (.const (.string "127.0.0.1")) =
    some (.absolute (.host (.ip (.v4 2130706433 (by decide))))) := by
  simp +decide [parseAtInput,parseTargetInput,parseHost,parseIPv4,splitText,splitChars,parseNatDec]

/-- 空ラベルを持つホスト条件は対象の解析でも拒否する。 -/
theorem parseAtInput_host_bad_pattern :
    parseAtInput .host (.const (.string "bad..pattern")) = none := by
  have lower : "bad..pattern".toLower = "bad..pattern" := by decide +kernel
  simp +decide [parseAtInput,parseTargetInput,parseHost,parseIPv4,splitText,splitChars,lower,NameWordWF]

/-- 完全一致のホスト条件に使う DNS 名を同じ解析で得る。 -/
theorem parseAtInput_host_other_example :
    parseAtInput .host (.const (.string "other.example")) =
      some (.absolute (.host (.name ["other","example"]))) := by
  have lower : "other.example".toLower = "other.example" := by decide +kernel
  simp +decide [parseAtInput,parseTargetInput,parseHost,parseIPv4,splitText,splitChars,lower,
    NameWordWF,NameLabelWF,FourDigitLabels]

/-- 絶対形のパス条件 `/a/b`（exact）と `/a/b/**`（tree）。根の木は `/**` である。 -/
def parseAbsolutePathPattern (raw : String) : Option PathPattern := do
  let tree := raw.endsWith "/**"
  let stem := if tree then String.ofList (raw.toList.take (raw.length-3)) else raw
  let base := if stem = "" && tree then "/" else stem
  if tree && stem == "/" then none else
  match parseAtInput .path (.const (.string base)) with
  | some (.absolute (.path w)) =>
    let p := if tree then PathPattern.tree w else PathPattern.exact w
    if p.WF then some p else none
  | _ => none

/-- ホスト条件の exact・one（`*.`）・many（`**.`）・CIDR。 -/
def parseHostPatternText (raw : String) : Option HostPattern := do
  let pattern ←
    if raw.startsWith "**." then
      match parseAtInput .host (.const (.string (String.ofList (raw.toList.drop 3)))) with
      | some (.absolute (.host (.name w))) => some (HostPattern.name (.many w))
      | _ => none
    else if raw.startsWith "*." then
      match parseAtInput .host (.const (.string (String.ofList (raw.toList.drop 2)))) with
      | some (.absolute (.host (.name w))) => some (HostPattern.name (.one w))
      | _ => none
    else match (raw.toList.splitOn '/').map String.ofList with
      | [address,prefixText] => do
        if prefixText.length ≥ 4 ∨ (prefixText.length ≥ 2 ∧ prefixText.startsWith "0") then none else do
        let n ← prefixText.toNat?
        match parseAtInput .host (.const (.string address)) with
        | some (.absolute (.host (.ip ip))) => some (HostPattern.ip (.cidr ⟨ip.family,ip.bits,n⟩))
        | _ => none
      | [host] => match parseAtInput .host (.const (.string host)) with
        | some (.absolute (.host (.name w))) => some (HostPattern.name (.exact w))
        | some (.absolute (.host (.ip ip))) => some (HostPattern.ip (.exact ip))
        | _ => none
      | _ => none
  if pattern.WF then some pattern.normalize else none

/-- 明示した基準の名前の接頭辞。`~` は home の別の綴りである。 -/
def pathBasePrefixes : List (String × PathBase) :=
  [("{root}", .root), ("{cwd}", .cwd), ("{home}", .home), ("~", .home), ("{work}", .work), ("{tmp}", .tmp)]

/-- 基準からの残りの部分（空か `/` で始まる部分）を、基準からの条件として読む。 -/
def parseBasedRest (base : PathBase) (rest : String) : Option RangeExpr :=
  if rest = "" then (parseAbsolutePathPattern "/").map (.based base)
  else if rest.startsWith "/" ∧ rest ≠ "/" then (parseAbsolutePathPattern rest).map (.based base)
  else none

/-- パス条件の文字列（設計書 01-07「閉じた範囲引数」の書き方）。絶対形、明示した基準（`{root}`・`{cwd}`・`{home}`・`~`・
`{work}`・`{tmp}`）からの形、`{secrets}`、裸の相対形（`data/a`・`./data/a`・`.`・`./**`。root からの形）を読む。
`..`・途中の `.`・空の要素・余分な末尾の `/`・`~user` は拒否する。 -/
def parsePathPatternText (s : String) : Option RangeExpr :=
  if s = "{secrets}" then some .secrets
  else if s.startsWith "/" then (parseAbsolutePathPattern s).map RangeExpr.path
  else match pathBasePrefixes.find? (fun e => s.startsWith e.1) with
    | some (name, base) => parseBasedRest base (String.ofList (s.toList.drop name.length))
    | none =>
      if s.startsWith "{" then none
      else if s = "." then parseBasedRest .root ""
      else if s.startsWith "./" then parseBasedRest .root (String.ofList (s.toList.drop 1))
      else parseBasedRest .root ("/" ++ s)

/-- 動的な pattern の文字列を、名前の種類ごとに範囲の式として読む。端点の種類は文字列の書き方を持たない。 -/
def parsePatternText : Kind → String → Option RangeExpr
  | .path, s => parsePathPatternText s
  | .host, s => (parseHostPatternText s).map RangeExpr.host
  | .endpoint, _ => none

/-- At の pattern の値。解析済みの範囲の値と動的な文字列を受け、どちらも名前の種類・整形式・正規形を確かめる。 -/
def parseAtPattern (k : Kind) : Val → Option RangeExpr
  | .scopePattern r => if r.FitsKind k ∧ r.WF ∧ r.Canonical then some r else none
  | .const (.string s) => (parsePatternText k s).bind fun r =>
      if r.FitsKind k ∧ r.WF ∧ r.Canonical then some r else none
  | _ => none

/-- 解析に成功した pattern は、名前の種類に合い、整形式で正規形である。 -/
theorem parseAtPattern_formed {k : Kind} {v : Val} {r : RangeExpr} (h : parseAtPattern k v = some r) :
    r.FitsKind k ∧ r.WF ∧ r.Canonical := by
  unfold parseAtPattern at h
  split at h
  · split at h
    · cases h; assumption
    · cases h
  · obtain ⟨r', _, h⟩ := Option.bind_eq_some_iff.mp h
    split at h
    · cases h; assumption
    · cases h
  · cases h

private theorem splitChars_ne_nil (sep : Char) (cs : List Char) : splitChars sep cs ≠ [] := by
  induction cs with
  | nil => simp [splitChars]
  | cons c cs ih =>
    simp only [splitChars]
    split
    · simp
    · cases h : splitChars sep cs with
      | nil => simp
      | cons part parts => simp

private theorem intercalate_splitChars (sep : Char) (cs : List Char) :
    List.intercalate [sep] (splitChars sep cs) = cs := by
  induction cs with
  | nil => simp [splitChars]
  | cons c cs ih =>
    obtain ⟨part,parts,h⟩ := List.exists_cons_of_ne_nil (splitChars_ne_nil sep cs)
    simp only [splitChars, h]
    split <;> rename_i hc
    · subst c
      simpa [List.intercalate_cons_of_ne_nil, h] using congrArg (sep :: ·) ih
    · simpa [List.intercalate_cons_cons_left, h] using congrArg (c :: ·) ih

private theorem intercalate_splitText (s : String) (sep : Char) :
    String.intercalate (String.singleton sep) (splitText s sep) = s := by
  apply String.toList_inj.mp
  simpa [splitText, String.toList_intercalate, List.map_map] using intercalate_splitChars sep s.toList

/-- 絶対形として受理したパスは、成分の結合から元の文字列へ戻る。 -/
theorem parseAtInput_path_text {s : String} {w : Word}
    (h : parseAtInput .path (.const (.string s)) = some (.absolute (.path w))) :
    "/" ++ String.intercalate "/" w = s := by
  simp only [parseAtInput,parseTargetInput] at h
  split at h
  · rename_i hs
    subst s
    cases h
    rfl
  · split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · cases h
        · by_cases ha : s.startsWith "/" = true
          · simp only [ha, ↓reduceIte] at h
            split at h
            · cases Option.some.inj h
              rw [show "/" = String.singleton '/' from rfl, intercalate_splitText]
              apply String.toList_inj.mp
              obtain ⟨tail,ht⟩ := String.startsWith_string_iff.mp ha
              simp [String.toList_append, ← ht]
            · cases h
          · have hf : s.startsWith "/" = false := Bool.eq_false_iff.mpr ha
            simp only [hf, Bool.false_eq_true, ↓reduceIte] at h
            repeat' split at h
            all_goals cases h

end Benitoite.Release.Refinement
