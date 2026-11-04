import Benitoite.Release.Refinement.StandardPureResults

/-! # 十進の実表記・解析・FloatとDecimalの変換 -/
namespace Benitoite.Release.Refinement.StandardNumericRemainingResponse
open StandardPureResults StandardScalar
noncomputable section
set_option maxRecDepth 10000
set_option maxHeartbeats 2000000


namespace FloatText
private def roundUpRev : List Nat → List Nat × Bool
 | [] => ([],true)
 | d::ds => if d<9 then ((d+1)::ds,false) else
   let (tail,carry) := roundUpRev ds
   (0::tail,carry)
private def roundUp (digits : List Nat) : List Nat × Bool :=
 let (rev,carry) := roundUpRev digits.reverse
 if carry then ((rev++[1]).reverse,true) else (rev.reverse,false)

private theorem loop_decrease (inclusive : Bool) (r scale minus plus : Nat)
 (positiveMinus : 0<minus) (positivePlus : 0<plus)
 (continues : ¬((if inclusive then r≤minus else r<minus) ∨
   (if inclusive then scale≤r+plus else scale<r+plus))) :
 scale-10*plus < scale-plus := by
 cases inclusive <;> simp_all <;> omega

private def generate (inclusive : Bool) (scale mant minus plus : Nat)
 (positiveMinus : 0<minus) (positivePlus : 0<plus) (digits : List Nat) : List Nat × Bool :=
 let q := mant/scale
 let r := mant%scale
 let down := if inclusive then r≤minus else r<minus
 let up := if inclusive then scale≤r+plus else scale<r+plus
 let next := digits++[q]
 if stop : down ∨ up then
  if up ∧ (¬down ∨ scale≤2*r) then roundUp next else (next,false)
 else generate inclusive scale (10*r) (10*minus) (10*plus)
   (by omega) (by omega) next
termination_by scale-plus
decreasing_by
 exact loop_decrease inclusive _ _ _ _ positiveMinus positivePlus stop

def shortest (single : Bool) (bits : Nat) : List Nat × Int :=
 let width : Nat := if single then 23 else 52
 let exponentWidth : Nat := if single then 8 else 11
 let bias : Int := if single then 127 else 1023
 let rawExp := bits/2^width%2^exponentWidth
 let rawFraction := bits%2^width
 let originalMant := if rawExp=0 then 2*rawFraction else rawFraction+2^width
 let originalExp : Int := (rawExp : Int)-bias-(width : Int)
 let isBoundary := rawExp≠0 ∧ originalMant=2^width
 let mant := if rawExp=0 then originalMant else if isBoundary then 4*originalMant else 2*originalMant
 let exp := if rawExp=0 then originalExp else if isBoundary then originalExp-2 else originalExp-1
 let pcoeff := if isBoundary then 2 else 1
 let inclusive := originalMant%2==0
 let k : Int := (((Nat.log2 (mant+pcoeff-1)+1 : Nat) : Int)+exp)*1292913986/4294967296
 let powerTwo := if exp<0 then 1 else 2^exp.toNat
 let powerTen := if k<0 then 10^(-k).toNat else 1
 let multiplier := powerTwo*powerTen
 let scale := (if exp<0 then 2^(-exp).toNat else 1) * (if k<0 then 1 else 10^k.toNat)
 let mant := mant*multiplier
 let minus := multiplier
 let plus := pcoeff*multiplier
 let correction := if inclusive then scale≤mant+plus else scale<mant+plus
 let factor := if correction then 1 else 10
 have positiveTwo : 0<powerTwo := by
  dsimp [powerTwo]; split <;> first | decide | exact Nat.pow_pos (by decide)
 have positiveTen : 0<powerTen := by
  dsimp [powerTen]; split <;> first | decide | exact Nat.pow_pos (by decide)
 have positiveMultiplier : 0<multiplier := Nat.mul_pos positiveTwo positiveTen
 have positiveCoefficient : 0<pcoeff := by dsimp [pcoeff]; split <;> decide
 have positiveFactor : 0<factor := by dsimp [factor]; split <;> decide
 let (ds,carry) := generate inclusive scale (mant*factor) (minus*factor) (plus*factor)
   (Nat.mul_pos positiveMultiplier positiveFactor)
   (Nat.mul_pos (Nat.mul_pos positiveCoefficient positiveMultiplier) positiveFactor) []
 (ds,k+(if correction then 1 else 0)+(if carry then 1 else 0))

private def chars (ds : List Nat) : String := String.ofList (ds.map (fun n => Char.ofNat (48+n)))
def formatDigits (digits : List Nat) (k : Int) : String :=
 let exponent := k-1
 if exponent < -5 ∨ 21≤exponent then
  let mantissa := match digits with
    | [] => "0.0"
    | d::ds => chars [d] ++ "." ++ (if ds=[] then "0" else chars ds)
  mantissa ++ "e" ++ (if exponent<0 then "" else "+") ++ toString exponent
 else if exponent<0 then "0." ++ String.ofList (List.replicate (-k).toNat '0') ++ chars digits
 else
  let position := k.toNat
  if digits.length≤position then chars digits ++
    String.ofList (List.replicate (position-digits.length) '0') ++ ".0"
  else chars (digits.take position) ++ "." ++ chars (digits.drop position)

def text (single : Bool) (bits : Nat) : String :=
 let width : Nat := if single then 23 else 52
 let ewidth : Nat := if single then 8 else 11
 let negative := bits/2^(width+ewidth)%2==1
 let exp := bits/2^width%2^ewidth
 let frac := bits%2^width
 let sign := if negative then "-" else ""
 if exp=2^ewidth-1 then
  if frac=0 then sign++"Infinity" else "NaN"
 else if exp=0 ∧ frac=0 then sign++"0.0"
 else
  let (digits,k) := shortest single bits
  sign++formatDigits digits k
end FloatText

private def digitsValid (ds : List Char) : Bool :=
 !ds.isEmpty && ds.all (fun c => '0'.toNat≤c.toNat && c.toNat≤'9'.toNat)
private def wholeValid (ds : List Char) : Bool :=
 digitsValid ds && !(ds.length>1 && ds.head?==some '0')
private def digitsNumber (ds : List Char) : Nat :=
 ds.foldl (fun n c => n*10+(c.toNat-'0'.toNat)) 0
private def signAndBody (s : String) : Bool × String :=
 if s.startsWith "-" then (true,String.ofList (s.toList.drop 1)) else (false,s)
private def exponentValue (s : String) : Option Int :=
 let negative := s.startsWith "-"
 let body := if negative || s.startsWith "+" then s.toList.drop 1 else s.toList
 if digitsValid body then some (if negative then -(digitsNumber body : Int) else digitsNumber body) else none

def parseScientific (s : String) : Option (Bool × Nat × Int) := do
 let (negative,body) := signAndBody s
 let normalized := String.ofList (body.toList.map (fun c => if c=='E' then 'e' else c))
 let (mantissa,exponent) ← match stringParts normalized "e" with
  | [m] => some (m,0)
  | [m,e] => (exponentValue e).map (m,·)
  | _ => none
 let (whole,fraction) ← match stringParts mantissa "." with
  | [w] => some (w.toList,[])
  | [w,f] => if digitsValid f.toList then some (w.toList,f.toList) else none
  | _ => none
 if wholeValid whole then
  some (negative,digitsNumber (whole++fraction),exponent-(fraction.length : Int))
 else none

def parseFloat64 (s : String) : Option UInt64 := do
 let (negative,m,e) ← parseScientific s
 let value := Float.Model.ofScientific m e
 let signed := if negative then -value else value
 if signed.isFinite then some signed.toBits else none
def parseFloat32 (s : String) : Option UInt32 := do
 let (negative,m,e) ← parseScientific s
 let value := Float32.Model.ofScientific m e
 let signed := if negative then -value else value
 if signed.isFinite then some signed.toBits else none

private def roundTo (format : Float.Model.Format) : Float.Model.UnpackedFloat → Float.Model.UnpackedFloat
 | .finite sign mantissa exponent _ => Float.Model.UnpackedFloat.round format sign mantissa exponent
 | other => other

def narrow (bits : UInt64) : Option UInt32 :=
 let raw := bits.toNat
 if raw/2^52%2048=2047 ∧ raw%2^52≠0 then
  some (UInt32.ofNat ((raw/2^63%2)*2^31+0x7f800000+
    ((raw%2^52/2^29) ||| 0x400000)))
 else
 let value := Float.Model.ofBits bits
 let result := Float32.Model.pack (roundTo .binary32 value.unpack)
 if value.isFinite && !result.isFinite then none else some result.toBits
def widen (bits : UInt32) : UInt64 :=
 let raw := bits.toNat
 if raw/2^23%256=255 ∧ raw%2^23≠0 then
  UInt64.ofNat ((raw/2^31%2)*2^63+0x7ff0000000000000+
   (((raw%2^23)*2^29) ||| 0x8000000000000))
 else (Float.Model.pack (roundTo .binary64 (Float32.Model.ofBits bits).unpack)).toBits

private def checkedDecimal (c : Int) (s : Nat) : Option Kind.decimal.Payload :=
 if h : decimalRepresentable c s then some ⟨(c,s),h⟩ else none
private def checkDecimalOption (parsed : Option (Int × Nat)) : Option Kind.decimal.Payload :=
 parsed.bind (fun p => checkedDecimal p.1 p.2)

def parseDecimal (s : String) : Option Kind.decimal.Payload := do
 let (negative,body) := signAndBody s
 let (whole,fraction) ← match stringParts body "." with
  | [w] => some (w.toList,[])
  | [w,f] => if digitsValid f.toList then some (w.toList,f.toList) else none
  | _ => none
 if wholeValid whole then
  let n := digitsNumber (whole++fraction)
  checkedDecimal (if negative then -(n : Int) else n) fraction.length
 else none

def decimalText (c : Int) (scale : Nat) : String :=
 let digits := (toString c.natAbs).toList
 let sign := if c<0 then "-" else ""
 if scale=0 then sign++String.ofList digits else
 if digits.length≤scale then
  sign++"0."++String.ofList (List.replicate (scale-digits.length) '0'++digits)
 else
  let pos := digits.length-scale
  sign++String.ofList (digits.take pos)++"."++String.ofList (digits.drop pos)

def floatDecimalParsed (bits : UInt64) : Option (Int × Nat) := do
 if ! (Float.Model.ofBits bits).isFinite then none else
 let (negative,text) := signAndBody (FloatText.text false bits.toNat)
 let (mantissa,e) ← match stringParts text "e" with
  | [m] => some (m,0)
  | [m,e] => (exponentValue e).map (m,·)
  | _ => none
 let (whole,fraction) ← match stringParts mantissa "." with
  | [w] => some (w.toList,[])
  | [w,f] => some (w.toList,f.toList)
  | _ => none
 let oldScale := (fraction.length : Int)-e
 let digits := whole++fraction++List.replicate (-oldScale).toNat '0'
 let scale := oldScale.toNat
 let discarded := scale-28
 let retained := digits.length-discarded
 let coefficient := digitsNumber (digits.take retained)
 if 170141183460469231731687303715884105727 < coefficient then none else
 let tail := digits.drop retained
 let first := (tail.head?).getD '0'
 let aboveHalf := '5'.toNat<first.toNat || (first=='5' && (tail.drop 1).any (· != '0'))
 let increment := discarded != 0 && discarded≤digits.length &&
  (aboveHalf || (first=='5' && coefficient%2==1))
 let rounded := coefficient + if increment then 1 else 0
 if 170141183460469231731687303715884105727 < rounded then none else
 some (if negative then -(rounded : Int) else rounded,min scale 28)

inductive API where
 | Float_toString
 | Float_parse
 | Float32_fromFloat
 | Float32_toFloat
 | Float32_parse
 | Float32_toString
 | Decimal_toFloat
 | Decimal_fromFloat
 | Decimal_toString
 | Decimal_parse
 deriving DecidableEq
def API.name : API → String
 | .Float_toString => "Float.toString"
 | .Float_parse => "Float.parse"
 | .Float32_fromFloat => "Float32.fromFloat"
 | .Float32_toFloat => "Float32.toFloat"
 | .Float32_parse => "Float32.parse"
 | .Float32_toString => "Float32.toString"
 | .Decimal_toFloat => "Decimal.toFloat"
 | .Decimal_fromFloat => "Decimal.fromFloat"
 | .Decimal_toString => "Decimal.toString"
 | .Decimal_parse => "Decimal.parse"
def API.names : API → List String
 | .Float_toString => ["x"]
 | .Float_parse => ["s"]
 | .Float32_fromFloat => ["n"]
 | .Float32_toFloat => ["n"]
 | .Float32_parse => ["s"]
 | .Float32_toString => ["n"]
 | .Decimal_toFloat => ["x"]
 | .Decimal_fromFloat => ["x"]
 | .Decimal_toString => ["x"]
 | .Decimal_parse => ["s"]
def API.inputs : API → List Ty
 | .Float_toString => [(.base .float)]
 | .Float_parse => [(.base .string)]
 | .Float32_fromFloat => [(.base .float)]
 | .Float32_toFloat => [(.base .float32)]
 | .Float32_parse => [(.base .string)]
 | .Float32_toString => [(.base .float32)]
 | .Decimal_toFloat => [(.base .decimal)]
 | .Decimal_fromFloat => [(.base .float)]
 | .Decimal_toString => [(.base .decimal)]
 | .Decimal_parse => [(.base .string)]
def API.resultKind : API → Kind
 | .Float_toString => .string
 | .Float_parse => .option .float64
 | .Float32_fromFloat => .option .float32
 | .Float32_toFloat => .float64
 | .Float32_parse => .option .float32
 | .Float32_toString => .string
 | .Decimal_toFloat => .float64
 | .Decimal_fromFloat => .option .decimal
 | .Decimal_toString => .string
 | .Decimal_parse => .option .decimal
def API.signature (api : API) : PrimSig :=
 ⟨[],0,api.names,api.inputs,api.resultKind.type,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

private def malformed {α : Type} : Except String α := .error "invalid numeric arguments"

def API.evaluate : (api : API) → List Val → Except String api.resultKind.Payload
 | .Float_toString,[.const (.float64 bits)] => .ok (FloatText.text false bits.toNat)
 | .Float_parse,[.const (.string s)] => .ok (parseFloat64 s)
 | .Float32_toString,[.const (.float32 bits)] => .ok (FloatText.text true bits.toNat)
 | .Float32_parse,[.const (.string s)] => .ok (parseFloat32 s)
 | .Float32_fromFloat,[.const (.float64 bits)] => .ok (narrow bits)
 | .Float32_toFloat,[.const (.float32 bits)] => .ok (widen bits)
 | .Decimal_toString,[.const (.decimal c scale)] =>
   if decimalRepresentable c scale then .ok (decimalText c scale) else malformed
 | .Decimal_parse,[.const (.string s)] => .ok (parseDecimal s)
 | .Decimal_toFloat,[.const (.decimal c scale)] =>
   if decimalRepresentable c scale then
    let value := Float.Model.ofScientific c.natAbs (-(scale : Int))
    .ok ((if c<0 then -value else value).toBits)
   else malformed
 | .Decimal_fromFloat,[.const (.float64 bits)] => .ok (checkDecimalOption (floatDecimalParsed bits))
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

def API.all : List API := [.Float_toString,.Float_parse,.Float32_fromFloat,.Float32_toFloat,.Float32_parse,.Float32_toString,.Decimal_toFloat,.Decimal_fromFloat,.Decimal_toString,.Decimal_parse]
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

/-- 同じbitsから計算したparsedを、既存のDecimal再検査出口へ渡す。 -/
theorem fromFloat_parsed (bits : UInt64) :
 API.delta .Decimal_fromFloat "Decimal.fromFloat" [] [] [] [.const (.float64 bits)] =
 some (decimalConversionReply (floatDecimalParsed bits)) := by
 simp only [API.delta,API.name,and_self,ite_true,API.evaluate,reply,API.resultKind,
  checkDecimalOption,decimalConversionReply]
 cases h : floatDecimalParsed bits with
 | none => rfl
 | some p =>
  rcases p with ⟨c,s⟩
  by_cases represented : decimalRepresentable c s
  · simp [checkedDecimal,decimalChecked,represented,Kind.encode,Kind.type,decimalOption]
  · simp [checkedDecimal,decimalChecked,represented,Kind.encode,Kind.type,decimalOption]

example (bits : UInt64) :
 API.delta .Decimal_fromFloat "Decimal.fromFloat" [] [] [] [.const (.float64 bits)] =
 some (decimalConversionReply (floatDecimalParsed bits)) := fromFloat_parsed bits
example : FloatText.text false 0x3ff8000000000000 = "1.5" := by decide +kernel
example : FloatText.text false 0x8000000000000000 = "-0.0" := by decide +kernel
example : (parseFloat32 "01.0").isNone=true := by decide +kernel
example : decimalText 150 2 = "1.50" := by decide +kernel
example : narrow 0xfff8000000000000 = some 0xffc00000 := by decide +kernel
example : narrow 0x7ff0000000000001 = some 0x7fc00000 := by decide +kernel
example : narrow 0xfff123456789abcd = some 0xffc91a2b := by decide +kernel
example : widen 0xffc00001 = 0xfff8000020000000 := by decide +kernel
example : widen 0x7f800001 = 0x7ff8000020000000 := by decide +kernel
example : widen 0xff812345 = 0xfff82468a0000000 := by decide +kernel
end
end Benitoite.Release.Refinement.StandardNumericRemainingResponse

