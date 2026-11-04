import Benitoite.Release.Refinement.StandardCharacterResponse
import Init.Data.Float.Model

/-! # 七整数幅の十進表記・解析・Float変換 -/
namespace Benitoite.Release.Refinement.StandardIntegerTextResponse
open Benitoite.Interval StandardScalar
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 2000000

inductive API where
 | toString | parse | toFloat
 deriving DecidableEq

def name (k : IntKind) (api : API) : String :=
 integerModule k ++ match api with | .toString => ".toString" | .parse => ".parse" | .toFloat => ".toFloat"
def input (k : IntKind) : API → Ty
 | .parse => .base .string | _ => embedTy k.type
def result (k : IntKind) : API → Ty
 | .parse => .data "Option" [embedTy k.type] | .toString => .base .string | .toFloat => .base .float
def signature (k : IntKind) (api : API) : PrimSig :=
 ⟨[],0,[if api=.parse then "s" else "n"],[input k api],result k api,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

private def readInteger (k : IntKind) : Val → Option Int
 | .const (.integer n) => if k=.integer64 then some n.toInt else none
 | .const (.integer8 n) => if k=.integer8 then some n else none
 | .const (.integer16 n) => if k=.integer16 then some n else none
 | .const (.integer32 n) => if k=.integer32 then some n else none
 | .const (.unsignedInteger16 n) => if k=.unsignedInteger16 then some n else none
 | .const (.unsignedInteger32 n) => if k=.unsignedInteger32 then some n else none
 | .const (.unsignedInteger64 n) => if k=.unsignedInteger64 then some n else none
 | _ => none

def parseInteger (k : IntKind) (s : String) : Option (IntegerValue k) :=
 let negative := k.min < 0 && s.toList.head? == some '-'
 let digits := if negative then s.toList.drop 1 else s.toList
 if !digits.isEmpty && !(digits.length > 1 && digits.head? == some '0') && digits.all (fun c => '0'.toNat≤c.toNat && c.toNat≤'9'.toNat) then
  let magnitude := digits.foldl (fun acc c => acc*10+(c.toNat-'0'.toNat)) 0
  integerConvert k (if negative then -(magnitude : Int) else magnitude)
 else none

def delta (k : IntKind) (api : API) (b : PrimName) (ts : List Ty) (es : List Eff)
 (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
 if b=name k api ∧ ts=[] ∧ es=[] ∧ rs=[] then
  match api,ws with
  | .parse,[.const (.string s)] => some (.val (integerOption k (parseInteger k s)))
  | .toString,[v] => (readInteger k v).map (fun n => .val (.const (.string (toString n))))
  | .toFloat,[v] => (readInteger k v).map (fun n => .val (.const (.float64 (Float.Model.ofInt n).toBits)))
  | _,_ => none
 else none

private theorem instantiated (k : IntKind) (api : API) :
 instantiatedTel (Tel.instR [] (signature k api).tel) [] [] =
 Ty.toTel [if api=.parse then "s" else "n"] [input k api] (result k api) Eff.empty := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]
 cases k <;> cases api <;> simp [emptyRange,signature,input,result,embedTy,IntKind.type,
  PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
  Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
  Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
  substAtoms_nil,instAtoms_nil,rowFails]

private theorem arguments {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
 (args : BuiltinArgs P B Ψ (name k api) (signature k api) ts es rs ws a e) :
 ts=[] ∧ es=[] ∧ rs=[] ∧ a=result k api ∧ e=Eff.empty ∧
 ∃ v, ws=[v] ∧ HasTypeVQ P B Ψ Qempty [] [] [] v (input k api) := by
 have ts0 : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst ts; subst es; subst rs
 have values := args.arguments
 rw [instantiated] at values
 obtain ⟨values,ar,ee⟩ := values.toTelValues (by simp [NamesWF])
 cases values with | cons typed rest =>
  cases rest
  have norm : (result k api).norm=result k api := by cases k <;> cases api <;> rfl
  have normi : (input k api).norm=input k api := by cases k <;> cases api <;> rfl
  exact ⟨rfl,rfl,rfl,args.result.2.symm.trans (ar.trans norm),args.effect.2.symm.trans ee,
   _,rfl,normi ▸ typed⟩

private theorem integer_shape {P B Ψ v} (k : IntKind)
 (h : HasTypeVQ P B Ψ Qempty [] [] [] v (embedTy k.type)) :
 ∃ n : IntegerValue k, v=.const (embedConst (IntegerValue.toConst k n)) := by
 cases k <;> obtain ⟨c,rfl,hc,ht⟩ := h.canonical_scalar rfl
 all_goals cases c <;> cases ht
 all_goals first | exact ⟨_,rfl⟩ | exact ⟨⟨_,hc⟩,rfl⟩

private theorem read_same (k : IntKind) (n : IntegerValue k) :
 readInteger k (.const (embedConst (IntegerValue.toConst k n))) = some n.toInt := by
 cases k <;> rfl

private theorem option_safe (k : IntKind) (v : Option (IntegerValue k)) (ws : List Val) :
 (integerOption k v).Ground ∧ AdequateResult ws (.val (integerOption k v)) := by
 cases k <;> cases v <;> refine ⟨?_,by intro σ _ _; trivial⟩
 all_goals simp [integerOption,Val.Ground,Val.ClosedAt,Val.ClosedList,embedTy,IntKind.type,Ty.WF]

/-- 全型・行・範囲・値引数から、同じ十進入力又は同じ整数の応答を作る。 -/
theorem response {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1)
 (args : BuiltinArgs P B Ψ (name k api) (signature k api) ts es rs ws a e) :
 ∃ out, delta k api (name k api) ts es rs ws=some out ∧ Outcome.Typed P B Ψ out a ∧
 AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 obtain ⟨rfl,rfl,rfl,rfl,rfl,v,rfl,typed⟩ := arguments k api args
 cases api with
 | parse =>
  obtain ⟨c,rfl,hc,tag⟩ := typed.canonical_scalar rfl
  cases c <;> cases tag
  rename_i s
  refine ⟨.val (integerOption k (parseInteger k s)),by simp [delta],?_,(option_safe k _ _).2,by intro i; simp⟩
  exact ⟨integerOption_typed P B Ψ k _ someDecl noneDecl arity,(option_safe k _ []).1⟩
 | toString =>
  obtain ⟨n,rfl⟩ := integer_shape k typed
  exact ⟨.val (.const (.string (toString n.toInt))),by simp [delta,read_same],
   ⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
 | toFloat =>
  obtain ⟨n,rfl⟩ := integer_shape k typed
  exact ⟨.val (.const (.float64 (Float.Model.ofInt n.toInt).toBits)),by simp [delta,read_same],
   ⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩

private def kinds : List IntKind := [.integer8,.integer16,.integer32,.integer64,
 .unsignedInteger16,.unsignedInteger32,.unsignedInteger64]
private def apis : List API := [.toString,.parse,.toFloat]
def dispatch (b : PrimName) : Option (IntKind × API) :=
 kinds.findSome? (fun k => apis.findSome? (fun api => if b=name k api then some (k,api) else none))
private theorem dispatch_name (k : IntKind) (api : API) : dispatch (name k api)=some (k,api) := by
 cases k <;> cases api <;> rfl

def lookup (b : PrimName) : Option PrimSig := (dispatch b).map (fun (k,api) => signature k api)
def table (base : Builtins) : Builtins :=
 {base with sig := lookup,delta := fun b ts es rs ws =>
  (dispatch b).bind (fun (k,api) => delta k api b ts es rs ws)}

theorem table_response {base Ψ ts es rs ws a e} (k : IntKind) (api : API)
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ (name k api) (signature k api) ts es rs ws a e) :
 (table base).sig (name k api)=some (signature k api) ∧
 ∃ out, (table base).delta (name k api) ts es rs ws=some out ∧
 Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 have h := response k api rfl rfl StandardConversionResponse.option_arity args
 obtain ⟨rfl,rfl,rfl,rfl,rfl,v,rfl,typed⟩ := arguments k api args
 refine ⟨?_,?_⟩
 · simp only [table,lookup,dispatch_name,Option.map_some]
 · obtain ⟨out,hd,ht,ha,hn⟩ := h
   refine ⟨out,?_,ht,ha,hn⟩
   simpa only [table,dispatch_name,Option.bind_some] using hd

example {base Ψ ts es rs ws a e} (k : IntKind) (api : API)
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ (name k api) (signature k api) ts es rs ws a e) := table_response k api args
example : (parseInteger .integer8 "128").isNone=true := by decide
example : (parseInteger .integer16 "-12").map IntegerValue.toInt = some (-12) := by decide
example : (parseInteger .integer16 "-012").isNone=true := by decide
example : (parseInteger .integer64 "+1").isNone=true := by decide
end
end Benitoite.Release.Refinement.StandardIntegerTextResponse
