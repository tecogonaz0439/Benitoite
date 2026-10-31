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

def parseUrlTarget (s : String) : Option Target := do
  if ¬ s.toList.all urlAlphabet ∨ ¬ validPercent s.toList then none
  else
    let (rest, port) ←
      if s.startsWith "http://" then some (String.ofList (s.toList.drop 7), 80)
      else if s.startsWith "https://" then some (String.ofList (s.toList.drop 8), 443)
      else none
    let authority := String.ofList (rest.toList.takeWhile (fun c => c != '/' && c != '?' && c != '#'))
    parseAuthority authority port

def Val.reqTarget : Val → Option Target
  | .con "Http.ClientRequest" _ [_, .const (.string url), _, _, _] => parseUrlTarget url
  | _ => none

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

def parseAtPattern (k : Kind) : Val → Option RangeExpr
  | .scopePattern r => if r.FitsKind k ∧ r.WF ∧ r.Canonical then some r else none
  | _ => none

end Benitoite.Release.Refinement
