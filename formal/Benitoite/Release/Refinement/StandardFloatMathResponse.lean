import Benitoite.Release.Refinement.StandardIntegerTextResponse

/-! # Float二幅の整数丸め・絶対値・平方根の具体応答 -/
namespace Benitoite.Release.Refinement.StandardFloatMathResponse
open Benitoite.Interval StandardScalar
noncomputable section
set_option maxRecDepth 5000

inductive API where
 | truncate | absolute | floor | ceiling | round | squareRoot
 deriving DecidableEq

def moduleName (single : Bool) : String := if single then "Float32" else "Float"
def API.suffix : API → String
 | .truncate => ".truncate" | .absolute => ".absolute" | .floor => ".floor"
 | .ceiling => ".ceiling" | .round => ".round" | .squareRoot => ".squareRoot"
def name (single : Bool) (api : API) : String := moduleName single ++ api.suffix
def base (single : Bool) : BaseTy := if single then .float32 else .float
def result (single : Bool) : API → Ty
 | .truncate => .data "Option" [.base .integer] | _ => .base (base single)
def signature (single : Bool) (api : API) : PrimSig :=
 ⟨[],0,[if single then "n" else "x"],[.base (base single)],result single api,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

def constant (single : Bool) (n : Nat) : Val :=
 if single then .const (.float32 (UInt32.ofNat n)) else .const (.float64 (UInt64.ofNat n))
private def read (single : Bool) : Val → Option Nat
 | .const (.float32 bits) => if single then some bits.toNat else none
 | .const (.float64 bits) => if single then none else some bits.toNat
 | _ => none

/-- 仮数と指数から整数部・剰余・分母を計算する。特殊値は別枝で扱う。 -/
def parts (single : Bool) (n : Nat) : Bool × Nat × Nat × Nat × Bool :=
 let m : Nat := if single then 23 else 52
 let e : Nat := if single then 8 else 11
 let bias : Int := if single then 127 else 1023
 let exp := n / 2^m % 2^e
 let mant := n % 2^m + if exp=0 then 0 else 2^m
 let exponent : Int := (if exp=0 then 1 else (exp : Int))-bias-(m : Int)
 let negative := n / 2^(m+e) % 2 == 1
 let denominator : Nat := if exponent<0 then 2^(-exponent).toNat else 1
 let numerator : Nat := if exponent<0 then mant else mant*2^exponent.toNat
 (negative,numerator/denominator,numerator%denominator,denominator,exp==2^e-1)

private def integerBits (single : Bool) (negative : Bool) (magnitude : Nat) : Nat :=
 if magnitude=0 then if negative then 2^(if single then 31 else 63) else 0
 else
  let z : Int := if negative then -(magnitude : Int) else magnitude
  if single then (Float32.Model.ofInt z).toBits.toNat else (Float.Model.ofInt z).toBits.toNat

/-- 特殊値の枝では NaN の payload は言語から観測できない値として扱い、Rust の quiet 化を写さない。
    floor・ceiling・round は入力の特殊値のビット列を保ち、squareRoot は Lean の模型を使う。 -/
def roundedBits (single : Bool) (api : API) (n : Nat) : Nat :=
 let (negative,q,r,d,special) := parts single n
 match api with
 | .absolute => n % 2^(if single then 31 else 63)
 | .squareRoot =>
   if single then (Float32.Model.sqrt (Float32.Model.ofBits (UInt32.ofNat n))).toBits.toNat
   else (Float.Model.sqrt (Float.Model.ofBits (UInt64.ofNat n))).toBits.toNat
 | _ => if special then n else
   let step : Bool := match api with
    | .floor => negative && r != 0
    | .ceiling => !negative && r != 0
    | .round => 2*r≥d
    | _ => false
   integerBits single negative (q + if step then 1 else 0)

def integerResult (single : Bool) (n : Nat) : Option (IntegerValue .integer64) :=
 let (negative,q,_,_,special) := parts single n
 if special then none else integerConvert .integer64 (if negative then -(q : Int) else q)

def output (single : Bool) (api : API) (n : Nat) : Val :=
 if api=.truncate then integerOption .integer64 (integerResult single n)
 else constant single (roundedBits single api n)

def delta (single : Bool) (api : API) (b : PrimName) (ts : List Ty) (es : List Eff)
 (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
 if b=name single api ∧ ts=[] ∧ es=[] ∧ rs=[] then
  match ws with | [v] => (read single v).map (fun n => .val (output single api n)) | _ => none
 else none

private theorem instantiated (single : Bool) (api : API) :
 instantiatedTel (Tel.instR [] (signature single api).tel) [] [] =
 Ty.toTel [if single then "n" else "x"] [.base (base single)] (result single api) Eff.empty := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]
 cases single <;> cases api <;> simp [emptyRange,signature,base,result,PrimSig.tel,signatureTel,
  instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,
  Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
  Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
  substAtoms_nil,instAtoms_nil,rowFails]

private theorem arguments {P B Ψ ts es rs ws a e} (single : Bool) (api : API)
 (args : BuiltinArgs P B Ψ (name single api) (signature single api) ts es rs ws a e) :
 ts=[] ∧ es=[] ∧ rs=[] ∧ a=result single api ∧ e=Eff.empty ∧
 ∃ n : Nat, ws=[constant single n] ∧ read single (constant single n)=some n := by
 have ts0 : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst ts; subst es; subst rs
 have values := args.arguments
 rw [instantiated] at values
 obtain ⟨values,ar,ee⟩ := values.toTelValues (by simp [NamesWF])
 cases values with | cons typed rest =>
  cases rest
  have norm : (result single api).norm=result single api := by cases single <;> cases api <;> rfl
  refine ⟨rfl,rfl,rfl,args.result.2.symm.trans (ar.trans norm),args.effect.2.symm.trans ee,?_⟩
  cases single <;> obtain ⟨c,rfl,hc,tag⟩ := typed.canonical_scalar rfl
  all_goals cases c <;> cases tag
  all_goals rename_i bits
  all_goals exact ⟨bits.toNat,by simp [constant],by simp [constant,read]⟩

private theorem output_safe {P B Ψ} (single : Bool) (api : API) (n : Nat) (ws : List Val)
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1) :
 Outcome.Typed P B Ψ (.val (output single api n)) (result single api) ∧
 AdequateResult ws (.val (output single api n)) := by
 cases api
 case truncate =>
  change Outcome.Typed P B Ψ (.val (integerOption .integer64 (integerResult single n))) _ ∧ _
  have safe (v : Option (IntegerValue .integer64)) :
   (integerOption .integer64 v).Ground ∧ AdequateResult ws (.val (integerOption .integer64 v)) := by
   cases v <;> refine ⟨?_,by intro σ _ _; trivial⟩
   all_goals simp [integerOption,Val.Ground,Val.ClosedAt,Val.ClosedList,embedTy,IntKind.type,Ty.WF]
  exact ⟨⟨integerOption_typed P B Ψ .integer64 _ someDecl noneDecl arity,(safe _).1⟩,(safe _).2⟩
 all_goals cases single <;> exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial⟩

/-- 二幅の全型付き入力を、同じビット列に対する具体応答へ接続する。 -/
theorem response {P B Ψ ts es rs ws a e} (single : Bool) (api : API)
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1)
 (args : BuiltinArgs P B Ψ (name single api) (signature single api) ts es rs ws a e) :
 ∃ out, delta single api (name single api) ts es rs ws=some out ∧ Outcome.Typed P B Ψ out a ∧
 AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 obtain ⟨rfl,rfl,rfl,rfl,rfl,n,rfl,hr⟩ := arguments single api args
 exact ⟨.val (output single api n),by simp [delta,hr],
  (output_safe (B := B) (Ψ := Ψ) single api n [constant single n] someDecl noneDecl arity).1,
  (output_safe (B := B) (Ψ := Ψ) single api n [constant single n] someDecl noneDecl arity).2,by intro i; simp⟩

private def apis : List API := [.truncate,.absolute,.floor,.ceiling,.round,.squareRoot]
def dispatch (b : PrimName) : Option (Bool × API) :=
 [false,true].findSome? (fun single => apis.findSome? (fun api => if b=name single api then some (single,api) else none))
private theorem dispatch_name (single : Bool) (api : API) : dispatch (name single api)=some (single,api) := by
 cases single <;> cases api <;> rfl

def lookup (b : PrimName) : Option PrimSig := (dispatch b).map (fun (single,api) => signature single api)
def table (base : Builtins) : Builtins :=
 {base with sig := lookup,delta := fun b ts es rs ws =>
  (dispatch b).bind (fun (single,api) => delta single api b ts es rs ws)}

theorem table_response {base Ψ ts es rs ws a e} (single : Bool) (api : API)
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ (name single api) (signature single api) ts es rs ws a e) :
 (table base).sig (name single api)=some (signature single api) ∧
 ∃ out, (table base).delta (name single api) ts es rs ws=some out ∧
 Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 refine ⟨by simp only [table,lookup,dispatch_name,Option.map_some],?_⟩
 obtain ⟨out,hd,ht,ha,hn⟩ := response single api rfl rfl StandardConversionResponse.option_arity args
 exact ⟨out,by simpa only [table,dispatch_name,Option.bind_some] using hd,ht,ha,hn⟩

example {base Ψ ts es rs ws a e} (single : Bool) (api : API)
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ (name single api) (signature single api) ts es rs ws a e) := table_response single api args
example : parts true 0x3fc00000 = (false,1,4194304,8388608,false) := by decide
example : roundedBits true .floor 0xbfc00000 = 0xc0000000 := by decide
end
end Benitoite.Release.Refinement.StandardFloatMathResponse
