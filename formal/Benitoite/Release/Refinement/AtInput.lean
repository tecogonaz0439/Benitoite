import Benitoite.Release.Refinement.Admissible

/-! # 解析済みの対象と要求の端点

文字列の字句解析の実装との一致は供給境界で照合する。OSや実行のσは読まない。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

private def splitChars (sep : Char) : List Char → List (List Char)
  | [] => [[]]
  | c :: cs =>
    let rest := splitChars sep cs
    if c = sep then [] :: rest
    else match rest with | [] => [[c]] | part :: parts => (c :: part) :: parts

private def splitText (s : String) (sep : Char) : List String :=
  (splitChars sep s.toList).map String.ofList

private def breakDoubleColon : List Char → Option (List Char × List Char)
  | ':' :: ':' :: rest => some ([], rest)
  | c :: rest => (breakDoubleColon rest).map (fun (left,right) => (c :: left,right))
  | [] => none

private def parseNatDec (s : String) : Option Nat :=
  if s.isEmpty then none else
    s.toList.foldlM (fun n c => if '0' ≤ c ∧ c ≤ '9' then some (n*10+c.toNat-'0'.toNat) else none) 0

private def parseIPv4 (s : String) : Option IPAddr := do
  let parts := splitText s '.'
  if parts.length ≠ 4 then none else do
    let ns ← parts.mapM fun p => do
      let n ← parseNatDec p
      if n < 256 ∧ (p.length = 1 ∨ p.toList.head? ≠ some '0') then some n else none
    match ns with
    | [a,b,c,d] => some (.v4 ((a*16777216+b*65536+c*256+d) % (2^32)) (Nat.mod_lt _ (by decide)))
    | _ => none

private def hexDigit (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

private def parseHexGroup (s : String) : Option Nat :=
  if s.isEmpty ∨ s.length > 4 then none else
    s.toList.foldlM (fun n c => (hexDigit c).map (fun d => n*16+d)) 0

private def parseV6Parts : List String → Option (List Nat)
  | [] => some []
  | [s] => if s.contains '.' then do
      let ip ← parseIPv4 s
      match ip with
      | ⟨.v4, n⟩ => some [n.val / 65536, n.val % 65536]
      | _ => none
    else (parseHexGroup s).map (fun n => [n])
  | s :: ss => do
      let n ← parseHexGroup s
      let ns ← parseV6Parts ss
      some (n :: ns)

private def v6Groups (s : String) : Option (List Nat) := do
  let groups ← match breakDoubleColon s.toList with
    | none => parseV6Parts (splitText s ':')
    | some (leftChars, rightChars) => do
      let _ ← if (breakDoubleColon rightChars).isSome then (none : Option Unit) else some ()
      let left := String.ofList leftChars
      let right := String.ofList rightChars
      let ls ← if left.contains '.' then none else if left.isEmpty then some [] else parseV6Parts (splitText left ':')
      let rs ← if right.isEmpty then some [] else parseV6Parts (splitText right ':')
      if ls.length + rs.length < 8 then
        some (ls ++ List.replicate (8 - ls.length - rs.length) 0 ++ rs)
      else none
  if groups.length = 8 then some groups else none

private def parseIPv6 (s : String) : Option IPAddr := do
  let gs ← v6Groups s
  let n := gs.foldl (fun n g => n*65536+g) 0
  some (.v6 (n % (2^128)) (Nat.mod_lt _ (by decide)))

private def hexText (n : Nat) : String :=
  let digit := fun n => Char.ofNat (if n < 10 then '0'.toNat+n else 'a'.toNat+n-10)
  let rec loop : Nat → Nat → List Char
    | 0, _ => []
    | fuel+1, n => if n < 16 then [digit n] else loop fuel (n/16) ++ [digit (n%16)]
  String.ofList (loop 4 n)

private def canonicalV6 (gs : List Nat) : String := Id.run do
  if gs.take 6 = [0,0,0,0,0,65535] then
    let n := (gs[6]?).getD 0 * 65536 + (gs[7]?).getD 0
    return "::ffff:" ++ String.intercalate "."
      ([n/16777216, n/65536%256, n/256%256, n%256].map toString)
  let mut best := (0, 0)
  let mut run := (0, 0)
  for (g, i) in gs.zipIdx do
    if g = 0 then
      if run.2 = 0 then run := (i, 1) else run := (run.1, run.2+1)
      if run.2 > best.2 then best := run
    else run := (0, 0)
  if best.2 < 2 then return String.intercalate ":" (gs.map hexText)
  return String.intercalate ":" ((gs.take best.1).map hexText) ++ "::" ++
    String.intercalate ":" ((gs.drop (best.1+best.2)).map hexText)

private def parseHost (s : String) : Option HostTarget :=
  if ¬ s.toList.all (fun c => decide (c.toNat < 128)) then none
  else if s.contains ':' then do
    let gs ← v6Groups s
    if canonicalV6 gs = s then (parseIPv6 s).map HostTarget.ip else none
  else match parseIPv4 s with
    | some ip => some (.ip ip)
    | none =>
      let w := splitText s.toLower '.'
      if NameWordWF w then some (.name w) else none

private def numericHost (s : String) : Bool :=
  (splitText s '.').all fun p =>
    (p.toList.head?.map Char.isDigit).getD false &&
      p.toList.all (fun c => (hexDigit c).isSome || c == 'x' || c == 'X')

private def validPercent : List Char → Bool
  | [] => true
  | '%' :: a :: b :: rest => (hexDigit a).isSome && (hexDigit b).isSome && validPercent rest
  | '%' :: _ => false
  | _ :: rest => validPercent rest

private def urlAlphabet (c : Char) : Bool :=
  decide (('a' ≤ c ∧ c ≤ 'z') ∨ ('A' ≤ c ∧ c ≤ 'Z') ∨ ('0' ≤ c ∧ c ≤ '9')) ||
    "-._~:/?#[]@!$&'()*+,;=%".contains c

private def urlPort (suffix : String) (defaultPort : Nat) : Option Port :=
  if suffix = "" ∨ suffix = ":" then
    some ⟨defaultPort % 65536, Nat.mod_lt _ (by decide)⟩
  else match splitText suffix ':' with
    | ["", p] => do
      let n ← parseNatDec p
      if hn : n < 65536 then some ⟨n,hn⟩ else none
    | _ => none

private def parseAuthority (text : String) (defaultPort : Nat) : Option Target := do
  if text.contains '@' then none
  else if text.startsWith "[" then
    match splitText text ']'  with
    | [hostText, suffix] =>
      let ip ← parseIPv6 (String.ofList (hostText.toList.drop 1))
      let port ← urlPort suffix defaultPort
      some (.endpoint ⟨.ip ip, port⟩)
    | _ => none
  else
    let (hostText, suffix) ← match splitText text ':' with
      | [h] => some (h, "")
      | [h,p] => some (h, ":" ++ p)
      | _ => none
    let host ← parseHost hostText
    let port ← urlPort suffix defaultPort
    if numericHost hostText then
      match host with | .name _ => none | .ip _ => some (.endpoint ⟨host,port⟩)
    else some (.endpoint ⟨host,port⟩)

/-- URL の文字・scheme・authority を読み、ホストの妥当性とは分ける。 -/
private def urlAuthority (s : String) : Option (String × Nat) := do
  if ¬ s.toList.all urlAlphabet ∨ ¬ validPercent s.toList then none
  else
    let (rest, port) ←
      if s.toLower.startsWith "http://" then some (String.ofList (s.toList.drop 7), 80)
      else if s.toLower.startsWith "https://" then some (String.ofList (s.toList.drop 8), 443)
      else none
    let authority := String.ofList (rest.toList.takeWhile (fun c => c != '/' && c != '?' && c != '#'))
    some (authority, port)

/-- URL の形だけを検査し、角括弧を除いたホストの綴りと実効ポートを返す。 -/
def parseUrlShape (s : String) : Option (String × Port) := do
  let (authority, defaultPort) ← urlAuthority s
  if authority.contains '@' then none else do
    let (host, suffix) ←
      if authority.startsWith "[" then
        match splitText authority ']' with
        | [h, suffix] => some (String.ofList (h.toList.drop 1), suffix)
        | _ => none
      else match splitText authority ':' with
        | [h] => some (h, "")
        | [h, p] => some (h, ":" ++ p)
        | _ => none
    if host.isEmpty then none else do
      let port ← urlPort suffix defaultPort
      some (host, port)

/-- 射影形はパターンの数値代数を保ち、URL の対象の入口で拒否する。 -/
def isIPv4MappedHost : HostTarget → Bool
  | .ip ⟨.v6, bits⟩ => bits.val / 2^32 == 65535
  | _ => false

/-- 角括弧を除いた URL のホストが射影形かを、同じ IPv6 解析で判定する。 -/
def urlHostMapped (host : String) : Bool :=
  ((parseIPv6 host).map (fun ip => isIPv4MappedHost (.ip ip))).getD false

def parseUrlTarget (s : String) : Option Target := do
  let (authority, port) ← urlAuthority s
  let target ← parseAuthority authority port
  match target with
  | .endpoint e => if isIPv4MappedHost e.host then none else some target
  | _ => none

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
  | .const (.string s) => match k with
    | .path =>
      if s = "/" then some (.absolute (.path []))
      else if s = "." then some (.relativePath [])
      else if s = "~" then some (.homePath [])
      else
        let absolute := s.startsWith "/"
        let home := s.startsWith "~/"
        let relativeDot := s.startsWith "./"
        if s.startsWith "~" && !home then none else
          let body := if absolute then String.ofList (s.toList.drop 1)
            else if home || relativeDot then String.ofList (s.toList.drop 2) else s
          let w := splitText body '/'
          if PathWordWF w then
            if absolute then some (.absolute (.path w))
            else if home then some (.homePath w) else some (.relativePath w)
          else none
    | .host => (parseHost s).map (fun h => .absolute (.host h))
    | .endpoint => (parseUrlTarget s).map TargetInput.absolute
  | _ => v.reqTarget.map TargetInput.absolute

/-- ホストのループバック字句を、パターンの解析にも同じ対象として渡す。 -/
theorem parseAtInput_host_loopback : parseAtInput .host (.const (.string "127.0.0.1")) =
    some (.absolute (.host (.ip (.v4 2130706433 (by decide))))) := by
  simp +decide [parseAtInput,parseHost,parseIPv4,splitText,splitChars,parseNatDec]

/-- 空ラベルを持つホスト条件は対象の解析でも拒否する。 -/
theorem parseAtInput_host_bad_pattern :
    parseAtInput .host (.const (.string "bad..pattern")) = none := by
  have lower : "bad..pattern".toLower = "bad..pattern" := by decide +kernel
  simp +decide [parseAtInput,parseHost,parseIPv4,splitText,splitChars,lower,NameWordWF]

/-- 完全一致のホスト条件に使う DNS 名を同じ解析で得る。 -/
theorem parseAtInput_host_other_example :
    parseAtInput .host (.const (.string "other.example")) =
      some (.absolute (.host (.name ["other","example"]))) := by
  have lower : "other.example".toLower = "other.example" := by decide +kernel
  simp +decide [parseAtInput,parseHost,parseIPv4,splitText,splitChars,lower,
    NameWordWF,NameLabelWF,FourDigitLabels]

def parseAtPattern (k : Kind) : Val → Option RangeExpr
  | .scopePattern r => if r.FitsKind k ∧ r.WF ∧ r.Canonical then some r else none
  | _ => none

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
  simp only [parseAtInput] at h
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
