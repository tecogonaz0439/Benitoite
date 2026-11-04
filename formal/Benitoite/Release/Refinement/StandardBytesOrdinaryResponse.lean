import Benitoite.Release.Refinement.StandardPureResults

/-! # Bytesの変換・切出し・整数の読み書きの具体応答 -/
namespace Benitoite.Release.Refinement.StandardBytesOrdinaryResponse
open StandardPureResults
noncomputable section
set_option maxRecDepth 5000

inductive API where
 | empty
 | fromIntegers
 | fromHex
 | fromBinary
 | toHex
 | toBinary
 | get
 | slice
 | concatenate
 | readUnsigned
 | readSigned
 | fromUnsigned
 | fromSigned
 deriving DecidableEq

def API.name : API → String
 | .empty => "Bytes.empty"
 | .fromIntegers => "Bytes.fromIntegers"
 | .fromHex => "Bytes.fromHex"
 | .fromBinary => "Bytes.fromBinary"
 | .toHex => "Bytes.toHex"
 | .toBinary => "Bytes.toBinary"
 | .get => "Bytes.get"
 | .slice => "Bytes.slice"
 | .concatenate => "Bytes.concatenate"
 | .readUnsigned => "Bytes.readUnsigned"
 | .readSigned => "Bytes.readSigned"
 | .fromUnsigned => "Bytes.fromUnsigned"
 | .fromSigned => "Bytes.fromSigned"
def API.names : API → List String
 | .empty => []
 | .fromIntegers => ["ns"]
 | .fromHex => ["s"]
 | .fromBinary => ["s"]
 | .toHex => ["b"]
 | .toBinary => ["b"]
 | .get => ["b","i"]
 | .slice => ["b","start","stop"]
 | .concatenate => ["a","b"]
 | .readUnsigned => ["b","offset","count","order"]
 | .readSigned => ["b","offset","count","order"]
 | .fromUnsigned => ["n","count","order"]
 | .fromSigned => ["n","count","order"]
def API.inputs : API → List Ty
 | .empty => []
 | .fromIntegers => [(.list (.base .integer))]
 | .fromHex => [(.base .string)]
 | .fromBinary => [(.base .string)]
 | .toHex => [(.bytes)]
 | .toBinary => [(.bytes)]
 | .get => [(.bytes),(.base .integer)]
 | .slice => [(.bytes),(.base .integer),(.base .integer)]
 | .concatenate => [(.bytes),(.bytes)]
 | .readUnsigned => [(.bytes),(.base .integer),(.base .integer),(.data "ByteOrder" [])]
 | .readSigned => [(.bytes),(.base .integer),(.base .integer),(.data "ByteOrder" [])]
 | .fromUnsigned => [(.base .integer),(.base .integer),(.data "ByteOrder" [])]
 | .fromSigned => [(.base .integer),(.base .integer),(.data "ByteOrder" [])]
def API.resultKind : API → Kind
 | .empty => .bytes
 | .fromIntegers => .option .bytes
 | .fromHex => .option .bytes
 | .fromBinary => .option .bytes
 | .toHex => .string
 | .toBinary => .string
 | .get => .option .byte
 | .slice => .option .bytes
 | .concatenate => .bytes
 | .readUnsigned => .option .integer
 | .readSigned => .option .integer
 | .fromUnsigned => .option .bytes
 | .fromSigned => .option .bytes
def API.signature (api : API) : PrimSig :=
 ⟨[],0,api.names,api.inputs,api.resultKind.type,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

private def bytes (ns : List Nat) : Option (List UInt8) :=
 if ns.all (· ≤ 255) then some (ns.map UInt8.ofNat) else none
private def integers : List Val → Option (List Integer64Value)
 | [] => some []
 | .const (.integer n)::xs => (integers xs).map (n::·)
 | _ => none
private def byteOrder : Val → Option Bool
 | .con "ByteOrder.BigEndian" [] [] => some true
 | .con "ByteOrder.LittleEndian" [] [] => some false
 | _ => none

private def checkedBytes (bs : List UInt8) : Except String (List UInt8) :=
 if bs.length≤1073741824 then .ok bs else .error "ValueTooLarge"
private def checkedOption (value : Option (List UInt8)) : Except String (Option (List UInt8)) :=
 match value with
 | none => .ok none
 | some bs => (checkedBytes bs).map some

private def digit (radix : Nat) (b : UInt8) : Option Nat :=
 let n := b.toNat
 if 48≤n ∧ n≤57 ∧ n-48<radix then some (n-48)
 else if radix=16 ∧ 97≤n ∧ n≤102 then some (n-87)
 else if radix=16 ∧ 65≤n ∧ n≤70 then some (n-55)
 else none

def parseDigits (radix width : Nat) (s : String) : Option (List UInt8) := do
 let ds ← (s.toUTF8.data.toList.filter (fun b => b != 95 && b != 32)).mapM (digit radix)
 if ds.length % width != 0 then none else
  some ((List.range (ds.length/width)).map (fun i =>
   UInt8.ofNat (((ds.drop (i*width)).take width).foldl (fun acc d => acc*radix+d) 0)))

private def hexDigit (n : Nat) : Char := Char.ofNat (if n<10 then 48+n else 87+n)
def toHex (bs : List UInt8) : String :=
 String.ofList (bs.flatMap (fun b => [hexDigit (b.toNat/16),hexDigit (b.toNat%16)]))
def toBinary (bs : List UInt8) : String :=
 String.ofList (bs.flatMap (fun b =>
  (List.range 8).reverse.map (fun i => if b.toNat/2^i%2=0 then '0' else '1')))

def readInteger (bs : List UInt8) (offset count : Int) (big signed : Bool) :
 Option Integer64Value :=
 if count<1 ∨ 8<count ∨ offset<0 ∨ (bs.length : Int)<offset+count then none else
 let part := (bs.drop offset.toNat).take count.toNat
 let ordered := if big then part else part.reverse
 let value : Nat := ordered.foldl (fun acc b => acc*256+b.toNat) 0
 let n : Int := if signed && value≥2^(count.toNat*8-1) then (value : Int)-2^(count.toNat*8) else value
 StandardScalar.integerConvert .integer64 n

def writeInteger (n count : Int) (big signed : Bool) : Option (List UInt8) :=
 if count<1 ∨ 8<count then none else
 let bits := count.toNat*8
 if (signed && -(2^(bits-1) : Int)≤n && n<(2^(bits-1) : Int)) ||
    (!signed && 0≤n && n<(2^bits : Int)) then
  let magnitude := (n % (2^bits : Int)).toNat
  let little := (List.range count.toNat).map (fun i => UInt8.ofNat (magnitude/2^(8*i)%256))
  some (if big then little.reverse else little)
 else none

private def malformed {α : Type} : Except String α := .error "invalid Bytes arguments"

def API.evaluate : (api : API) → List Val → Except String api.resultKind.Payload
 | .empty,[] => .ok []
 | .fromIntegers,[.list vs] =>
   match integers vs with
   | none => malformed
   | some ns => if ns.length>1073741824 then .error "ValueTooLarge" else
      checkedOption (ns.mapM (fun n =>
       if 0≤n.toInt ∧ n.toInt≤255 then some (UInt8.ofNat n.toInt.toNat) else none))
 | .fromHex,[.const (.string s)] => checkedOption (parseDigits 16 2 s)
 | .fromBinary,[.const (.string s)] => checkedOption (parseDigits 2 8 s)
 | .toHex,[.bytesV ns] =>
   match bytes ns with
   | none => malformed
   | some bs => if ns.length*2≤1073741824 then .ok (StandardBytesOrdinaryResponse.toHex bs) else .error "ValueTooLarge"
 | .toBinary,[.bytesV ns] =>
   match bytes ns with
   | none => malformed
   | some bs => if ns.length*8≤1073741824 then .ok (StandardBytesOrdinaryResponse.toBinary bs) else .error "ValueTooLarge"
 | .get,[.bytesV ns,.const (.integer i)] =>
   match bytes ns with
   | none => malformed
   | some bs => .ok (if i.toInt<0 then none else bs[i.toInt.toNat]?)
 | .slice,[.bytesV ns,.const (.integer start),.const (.integer stop)] =>
   match bytes ns with
   | none => malformed
   | some bs => checkedOption (if 0≤start.toInt ∧ start.toInt≤stop.toInt ∧ stop.toInt≤(bs.length : Int)
      then some ((bs.drop start.toInt.toNat).take (stop.toInt-start.toInt).toNat) else none)
 | .concatenate,[.bytesV xs,.bytesV ys] =>
   match bytes xs,bytes ys with
   | some a,some b => if a.length+b.length≤1073741824 then .ok (a++b) else .error "ValueTooLarge"
   | _,_ => malformed
 | .readUnsigned,[.bytesV ns,.const (.integer offset),.const (.integer count),order] =>
   match bytes ns,byteOrder order with
   | some bs,some big => .ok (readInteger bs offset.toInt count.toInt big false)
   | _,_ => malformed
 | .readSigned,[.bytesV ns,.const (.integer offset),.const (.integer count),order] =>
   match bytes ns,byteOrder order with
   | some bs,some big => .ok (readInteger bs offset.toInt count.toInt big true)
   | _,_ => malformed
 | .fromUnsigned,[.const (.integer n),.const (.integer count),order] =>
   match byteOrder order with
   | some big => checkedOption (writeInteger n.toInt count.toInt big false)
   | none => malformed
 | .fromSigned,[.const (.integer n),.const (.integer count),order] =>
   match byteOrder order with
   | some big => checkedOption (writeInteger n.toInt count.toInt big true)
   | none => malformed
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

def API.all : List API := [.empty,.fromIntegers,.fromHex,.fromBinary,.toHex,.toBinary,.get,.slice,.concatenate,.readUnsigned,.readSigned,.fromUnsigned,.fromSigned]
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

example : (parseDigits 16 2 "DE ad_BE ef").map (List.map UInt8.toNat) = some [222,173,190,239] := by decide
example : (readInteger [255] 0 1 true true).map Integer64Value.toInt = some (-1) := by decide
example : (writeInteger 128 1 true true).isNone=true := by decide
end
end Benitoite.Release.Refinement.StandardBytesOrdinaryResponse

