import Benitoite.Release.Refinement.StandardPureResults
import Benitoite.Release.Refinement.StandardStringTables

/-! # Stringの切出し・変換・文字列全体の表示幅の具体応答 -/
namespace Benitoite.Release.Refinement.StandardStringOrdinaryResponse
open StandardPureResults
noncomputable section
set_option maxRecDepth 5000

inductive API where
 | byteSlice
 | characterAt
 | characterSlice
 | isEmpty
 | contains
 | startsWith
 | endsWith
 | byteIndexOf
 | split
 | lines
 | join
 | trim
 | replace
 | repeat
 | characters
 | fromCharacters
 | toUppercase
 | toLowercase
 | toUTF8
 | fromUTF8
 | displayWidth
 | displayWidthCJK
 | displayWidthPadStart
 | displayWidthPadEnd
 | displayWidthPadStartCJK
 | displayWidthPadEndCJK
 deriving DecidableEq
def API.name : API → String
 | .byteSlice => "String.byteSlice"
 | .characterAt => "String.characterAt"
 | .characterSlice => "String.characterSlice"
 | .isEmpty => "String.isEmpty"
 | .contains => "String.contains"
 | .startsWith => "String.startsWith"
 | .endsWith => "String.endsWith"
 | .byteIndexOf => "String.byteIndexOf"
 | .split => "String.split"
 | .lines => "String.lines"
 | .join => "String.join"
 | .trim => "String.trim"
 | .replace => "String.replace"
 | .repeat => "String.repeat"
 | .characters => "String.characters"
 | .fromCharacters => "String.fromCharacters"
 | .toUppercase => "String.toUppercase"
 | .toLowercase => "String.toLowercase"
 | .toUTF8 => "String.toUTF8"
 | .fromUTF8 => "String.fromUTF8"
 | .displayWidth => "String.displayWidth"
 | .displayWidthCJK => "String.displayWidthCJK"
 | .displayWidthPadStart => "String.displayWidthPadStart"
 | .displayWidthPadEnd => "String.displayWidthPadEnd"
 | .displayWidthPadStartCJK => "String.displayWidthPadStartCJK"
 | .displayWidthPadEndCJK => "String.displayWidthPadEndCJK"
def API.names : API → List String
 | .byteSlice => ["s","start","stop"]
 | .characterAt => ["s","i"]
 | .characterSlice => ["s","start","stop"]
 | .isEmpty => ["s"]
 | .contains => ["s","part"]
 | .startsWith => ["s","prefix"]
 | .endsWith => ["s","suffix"]
 | .byteIndexOf => ["s","part"]
 | .split => ["s","separator"]
 | .lines => ["s"]
 | .join => ["xs","separator"]
 | .trim => ["s"]
 | .replace => ["s","old","new"]
 | .repeat => ["s","n"]
 | .characters => ["s"]
 | .fromCharacters => ["cs"]
 | .toUppercase => ["s"]
 | .toLowercase => ["s"]
 | .toUTF8 => ["s"]
 | .fromUTF8 => ["b"]
 | .displayWidth => ["s"]
 | .displayWidthCJK => ["s"]
 | .displayWidthPadStart => ["s","width"]
 | .displayWidthPadEnd => ["s","width"]
 | .displayWidthPadStartCJK => ["s","width"]
 | .displayWidthPadEndCJK => ["s","width"]
def API.inputs : API → List Ty
 | .byteSlice => [(.base .string),(.base .integer),(.base .integer)]
 | .characterAt => [(.base .string),(.base .integer)]
 | .characterSlice => [(.base .string),(.base .integer),(.base .integer)]
 | .isEmpty => [(.base .string)]
 | .contains => [(.base .string),(.base .string)]
 | .startsWith => [(.base .string),(.base .string)]
 | .endsWith => [(.base .string),(.base .string)]
 | .byteIndexOf => [(.base .string),(.base .string)]
 | .split => [(.base .string),(.base .string)]
 | .lines => [(.base .string)]
 | .join => [(.list (.base .string)),(.base .string)]
 | .trim => [(.base .string)]
 | .replace => [(.base .string),(.base .string),(.base .string)]
 | .repeat => [(.base .string),(.base .integer)]
 | .characters => [(.base .string)]
 | .fromCharacters => [(.list (.base .character))]
 | .toUppercase => [(.base .string)]
 | .toLowercase => [(.base .string)]
 | .toUTF8 => [(.base .string)]
 | .fromUTF8 => [(.bytes)]
 | .displayWidth => [(.base .string)]
 | .displayWidthCJK => [(.base .string)]
 | .displayWidthPadStart => [(.base .string),(.base .integer)]
 | .displayWidthPadEnd => [(.base .string),(.base .integer)]
 | .displayWidthPadStartCJK => [(.base .string),(.base .integer)]
 | .displayWidthPadEndCJK => [(.base .string),(.base .integer)]
def API.resultKind : API → Kind
 | .byteSlice => .option .string
 | .characterAt => .option .character
 | .characterSlice => .option .string
 | .isEmpty => .boolean
 | .contains => .boolean
 | .startsWith => .boolean
 | .endsWith => .boolean
 | .byteIndexOf => .option .integer
 | .split => .list .string
 | .lines => .list .string
 | .join => .string
 | .trim => .string
 | .replace => .string
 | .repeat => .string
 | .characters => .list .character
 | .fromCharacters => .string
 | .toUppercase => .string
 | .toLowercase => .string
 | .toUTF8 => .bytes
 | .fromUTF8 => .option .string
 | .displayWidth => .integer
 | .displayWidthCJK => .integer
 | .displayWidthPadStart => .string
 | .displayWidthPadEnd => .string
 | .displayWidthPadStartCJK => .string
 | .displayWidthPadEndCJK => .string
def API.signature (api : API) : PrimSig :=
 ⟨[],0,api.names,api.inputs,api.resultKind.type,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

private def malformed {α : Type} : Except String α := .error "invalid String arguments"
private def checkedString (s : String) : Except String String :=
 if s.toUTF8.size≤1073741824 then .ok s else .error "ValueTooLarge"
private def checkedList {α : Type} (xs : List α) : Except String (List α) :=
 if xs.length≤16777216 then .ok xs else .error "ValueTooLarge"
private def checkedOptionString : Option String → Except String (Option String)
 | none => .ok none | some s => (checkedString s).map some
private def checkedStrings (xs : List String) : Except String (List String) :=
 if xs.any (fun s => 1073741824<s.toUTF8.size) then .error "ValueTooLarge" else checkedList xs
private def checkedBytes (xs : List UInt8) : Except String (List UInt8) :=
 if xs.length≤1073741824 then .ok xs else .error "ValueTooLarge"
private def count (n : Nat) : Except String Integer64Value :=
 match StandardScalar.integerConvert .integer64 n with
 | some v => .ok v | none => .error "length does not fit Integer"
private def optionalCount : Option Nat → Except String (Option Integer64Value)
 | none => .ok none | some n => (count n).map some
private def stringValue : Val → Option String
 | .const (.string s) => some s | _ => none
private def characterValue : Val → Option Char
 | .const (.character c) => some c | _ => none
private def byteValues (ns : List Nat) : Option (List UInt8) :=
 if ns.all (· ≤ 255) then some (ns.map UInt8.ofNat) else none

def byteBoundaries (s : String) : List Nat :=
 (s.toList.foldl (fun (st : Nat × List Nat) c =>
  let next := st.1+c.utf8Size
  (next,next::st.2)) (0,[0])).2

def byteSlice (s : String) (start stop : Int) : Option String :=
 if 0≤start ∧ start≤stop ∧ stop≤(s.toUTF8.size : Int) ∧
   start.toNat ∈ byteBoundaries s ∧ stop.toNat ∈ byteBoundaries s then
  String.fromUTF8? (s.toUTF8.extract start.toNat stop.toNat)
 else none

def characterSlice (s : String) (start stop : Int) : Option String :=
 if 0≤start ∧ start≤stop ∧ stop≤(s.toList.length : Int) then
  some (String.ofList ((s.toList.drop start.toNat).take (stop-start).toNat))
 else none

private def findIndex (source part : List Char) : Option Nat :=
 if part.isEmpty then some 0 else
  match source with
  | [] => none
  | c::cs => if part.isPrefixOf source then some 0 else
     (findIndex cs part).map (fun i => c.utf8Size+i)

def split (s separator : String) : List String :=
 if separator.isEmpty then s.toList.map (fun c => String.ofList [c]) else stringParts s separator

def lines (s : String) : List String :=
 if s.isEmpty then [] else
 let pieces := stringParts s "\n"
 let kept := if s.endsWith "\n" then pieces.take (pieces.length-1) else pieces
 kept.map (fun piece => if piece.endsWith "\r" then String.ofList (piece.toList.take (piece.toList.length-1)) else piece)

private def whitespace (c : Char) : Bool := c==' ' || c=='\t' || c=='\n' || c=='\r'
def trim (s : String) : String :=
 String.ofList (((s.toList.dropWhile whitespace).reverse.dropWhile whitespace).reverse)
def caseChars (mapping : List (Nat × List Nat)) (c : Char) : List Char :=
 ((mapping.lookup c.toNat).getD [c.toNat]).map Char.ofNat

private def casedAhead : List Char → Bool
 | [] => false
 | c::cs => match StandardStringTables.sigmaClass c with
    | 2 => casedAhead cs | 1 => true | _ => false
private def lowerChars (before : List Char) : List Char → List Char
 | [] => []
 | c::cs =>
   let output := if c=='Σ' && casedAhead before && !casedAhead cs
     then ['ς'] else caseChars StandardCharacterData.lower c
   output ++ lowerChars (c::before) cs
def lowercase (s : String) : String := String.ofList (lowerChars [] s.toList)
def uppercase (s : String) : String := String.ofList (s.toList.flatMap (caseChars StandardCharacterData.upper))

private def widthBoundary (c : Char) : Bool :=
 c.toNat≤31 || (127≤c.toNat && c.toNat≤159) || c.toNat==8232 || c.toNat==8233
def displayWidth (cjk : Bool) (s : String) : Nat :=
 (s.toList.foldr (fun c (st : Int × Nat) =>
  if widthBoundary c then (st.1,0) else
   let next := StandardStringTables.transition cjk st.2 c
   (st.1+next.1,next.2)) (0,0)).1.toNat
def pad (cjk front : Bool) (s : String) (width : Int) : Except String String :=
 let missing := width.toNat - displayWidth cjk s
 if missing=0 then .ok s else
 if s.toUTF8.size+missing≤1073741824 then
  let blanks := String.ofList (List.replicate missing ' ')
  .ok (if front then blanks++s else s++blanks)
 else .error "ValueTooLarge"

def API.evaluate : (api : API) → List Val → Except String api.resultKind.Payload
 | .byteSlice,[.const (.string s),.const (.integer start),.const (.integer stop)] => checkedOptionString (StandardStringOrdinaryResponse.byteSlice s start.toInt stop.toInt)
 | .characterAt,[.const (.string s),.const (.integer i)] => .ok (if i.toInt<0 then none else s.toList[i.toInt.toNat]?)
 | .characterSlice,[.const (.string s),.const (.integer start),.const (.integer stop)] => checkedOptionString (StandardStringOrdinaryResponse.characterSlice s start.toInt stop.toInt)
 | .isEmpty,[.const (.string s)] => .ok s.isEmpty
 | .contains,[.const (.string s),.const (.string part)] => .ok ((findIndex s.toList part.toList).isSome)
 | .startsWith,[.const (.string s),.const (.string initial)] => .ok (initial.toList.isPrefixOf s.toList)
 | .endsWith,[.const (.string s),.const (.string suffix)] => .ok (suffix.toList.isSuffixOf s.toList)
 | .byteIndexOf,[.const (.string s),.const (.string part)] => optionalCount (findIndex s.toList part.toList)
 | .split,[.const (.string s),.const (.string separator)] => checkedStrings (StandardStringOrdinaryResponse.split s separator)
 | .lines,[.const (.string s)] => checkedStrings (StandardStringOrdinaryResponse.lines s)
 | .join,[.list vs,.const (.string separator)] =>
   match vs.mapM stringValue with
   | some xs => checkedString (String.intercalate separator xs)
   | none => malformed
 | .trim,[.const (.string s)] => checkedString (StandardStringOrdinaryResponse.trim s)
 | .replace,[.const (.string s),.const (.string old),.const (.string replacement)] =>
   checkedString (if old.isEmpty then s else String.intercalate replacement (stringParts s old))
 | .repeat,[.const (.string s),.const (.integer n)] =>
   if n.toInt≤0 || s.isEmpty then .ok "" else
   if s.toUTF8.size*n.toInt.toNat≤1073741824 then
    .ok (String.join (List.replicate n.toInt.toNat s))
   else .error "ValueTooLarge"
 | .characters,[.const (.string s)] => checkedList s.toList
 | .fromCharacters,[.list vs] =>
   match vs.mapM characterValue with
   | some cs => checkedString (String.ofList cs)
   | none => malformed
 | .toUppercase,[.const (.string s)] => checkedString (uppercase s)
 | .toLowercase,[.const (.string s)] => checkedString (lowercase s)
 | .toUTF8,[.const (.string s)] => checkedBytes s.toUTF8.data.toList
 | .fromUTF8,[.bytesV ns] =>
   if ns.length>1073741824 then .error "ValueTooLarge" else
   match byteValues ns with
   | some bs => .ok (String.fromUTF8? ⟨bs.toArray⟩)
   | none => malformed
 | .displayWidth,[.const (.string s)] => count (StandardStringOrdinaryResponse.displayWidth false s)
 | .displayWidthCJK,[.const (.string s)] => count (StandardStringOrdinaryResponse.displayWidth true s)
 | .displayWidthPadStart,[.const (.string s),.const (.integer width)] => pad false true s width.toInt
 | .displayWidthPadEnd,[.const (.string s),.const (.integer width)] => pad false false s width.toInt
 | .displayWidthPadStartCJK,[.const (.string s),.const (.integer width)] => pad true true s width.toInt
 | .displayWidthPadEndCJK,[.const (.string s),.const (.integer width)] => pad true false s width.toInt
 | _,_ => malformed

def API.delta (api : API) (b : PrimName) (ts : List Ty) (es : List Eff)
 (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
 if b=api.name ∧ ts=[] ∧ es=[] ∧ rs=[] then some (reply api.resultKind (api.evaluate ws)) else none

private theorem instantiated (api : API) :
 instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
 Ty.toTel api.names api.inputs api.resultKind.type Eff.empty := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]
 cases api <;> simp [emptyRange,API.signature,API.inputs,API.resultKind,API.names,Kind.type,
  PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
  Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
  Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
  substAtoms_nil,instAtoms_nil,rowFails,rawBindTys]

private theorem arguments {P B Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
 ts=[] ∧ es=[] ∧ rs=[] ∧ a=api.resultKind.type ∧ e=Eff.empty := by
 have ts0 : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst ts; subst es; subst rs
 have values := args.arguments
 rw [instantiated] at values
 have names : NamesWF api.names api.inputs := by cases api <;> simp [API.names,API.inputs,NamesWF]
 obtain ⟨_,ar,ee⟩ := values.toTelValues names
 exact ⟨rfl,rfl,rfl,args.result.2.symm.trans (ar.trans api.resultKind.normal),
  args.effect.2.symm.trans ee⟩

/-- 全BuiltinArgsから、同じ実名と実引数の具体応答を構成する。 -/
theorem response {P B Ψ ts es rs ws a e} (api : API)
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1)
 (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
 ∃ out, api.delta api.name ts es rs ws=some out ∧ Outcome.Typed P B Ψ out a ∧
 AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 obtain ⟨rfl,rfl,rfl,rfl,rfl⟩ := arguments api args
 exact ⟨_,by simp [API.delta],reply_safe someDecl noneDecl arity api.resultKind (api.evaluate ws) ws⟩

def API.all : List API := [.byteSlice,.characterAt,.characterSlice,.isEmpty,.contains,.startsWith,.endsWith,.byteIndexOf,.split,.lines,.join,.trim,.replace,.repeat,.characters,.fromCharacters,.toUppercase,.toLowercase,.toUTF8,.fromUTF8,.displayWidth,.displayWidthCJK,.displayWidthPadStart,.displayWidthPadEnd,.displayWidthPadStartCJK,.displayWidthPadEndCJK]
def dispatch (b : PrimName) : Option API := API.all.find? (fun api => b==api.name)
private theorem dispatch_name (api : API) : dispatch api.name=some api := by
 cases api <;> rfl
def lookup (b : PrimName) : Option PrimSig := (dispatch b).map API.signature
def table (base : Builtins) : Builtins :=
 {base with sig := lookup,delta := fun b ts es rs ws =>
  (dispatch b).bind (fun api => api.delta b ts es rs ws)}

theorem table_response {base Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs StandardPureResults.program (table base) Ψ api.name api.signature ts es rs ws a e) :
 (table base).sig api.name=some api.signature ∧
 ∃ out, (table base).delta api.name ts es rs ws=some out ∧
 Outcome.Typed StandardPureResults.program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 refine ⟨by simp only [table,lookup,dispatch_name,Option.map_some],?_⟩
 obtain ⟨out,hd,ht,ha,hn⟩ := response api rfl rfl StandardPureResults.option_arity args
 exact ⟨out,by simpa only [table,dispatch_name,Option.bind_some] using hd,ht,ha,hn⟩

example {base Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs StandardPureResults.program (table base) Ψ api.name api.signature ts es rs ws a e) :=
 table_response api args

example : byteSlice "é" 1 1 = none := by decide
example : lines "a\r" = ["a"] := by decide +kernel
example : lowercase "AΣ" = "aς" := by decide
end
end Benitoite.Release.Refinement.StandardStringOrdinaryResponse

