import Benitoite.Release.Refinement.StandardByteStringResponse

/-! # 公開の型別名ラッパーを元の組込みへ接続する通常本体 -/
namespace Benitoite.Release.Refinement.StandardAliasBodies
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 2000000

inductive API where
 | Integer64_toString
 | Integer64_parse
 | Integer64_toFloat
 | Integer64_floorDivide
 | Integer64_floorModulo
 | Integer64_absolute
 | Integer64_minimum
 | Integer64_maximum
 | Integer64_bitwiseAnd
 | Integer64_bitwiseOr
 | Integer64_bitwiseExclusiveOr
 | Integer64_bitwiseNot
 | Integer64_shiftLeft
 | Integer64_shiftRight
 | Integer64_shiftRightUnsigned
 | UnsignedInteger_fromInteger
 | UnsignedInteger_toInteger
 | UnsignedInteger_parse
 | UnsignedInteger_toString
 | UnsignedInteger_toFloat
 | UnsignedInteger_toDecimal
 | UnsignedInteger_fromDecimal
 | UnsignedInteger_absolute
 | UnsignedInteger_minimum
 | UnsignedInteger_maximum
 | UnsignedInteger_floorDivide
 | UnsignedInteger_floorModulo
 | UnsignedInteger_bitwiseAnd
 | UnsignedInteger_bitwiseOr
 | UnsignedInteger_bitwiseExclusiveOr
 | UnsignedInteger_bitwiseNot
 | UnsignedInteger_shiftLeft
 | UnsignedInteger_shiftRight
 | UnsignedInteger8_fromInteger
 | UnsignedInteger8_toInteger
 | UnsignedInteger8_toString
 | UnsignedInteger8_bitwiseAnd
 | UnsignedInteger8_bitwiseOr
 | UnsignedInteger8_bitwiseExclusiveOr
 | UnsignedInteger8_bitwiseNot
 | UnsignedInteger8_shiftLeft
 | UnsignedInteger8_shiftRight
 | Float64_toString
 | Float64_parse
 | Float64_truncate
 | Float64_isNaN
 | Float64_absolute
 | Float64_floor
 | Float64_ceiling
 | Float64_round
 | Float64_squareRoot
 deriving DecidableEq

def API.name : API → String
 | .Integer64_toString => "Integer64.toString"
 | .Integer64_parse => "Integer64.parse"
 | .Integer64_toFloat => "Integer64.toFloat"
 | .Integer64_floorDivide => "Integer64.floorDivide"
 | .Integer64_floorModulo => "Integer64.floorModulo"
 | .Integer64_absolute => "Integer64.absolute"
 | .Integer64_minimum => "Integer64.minimum"
 | .Integer64_maximum => "Integer64.maximum"
 | .Integer64_bitwiseAnd => "Integer64.bitwiseAnd"
 | .Integer64_bitwiseOr => "Integer64.bitwiseOr"
 | .Integer64_bitwiseExclusiveOr => "Integer64.bitwiseExclusiveOr"
 | .Integer64_bitwiseNot => "Integer64.bitwiseNot"
 | .Integer64_shiftLeft => "Integer64.shiftLeft"
 | .Integer64_shiftRight => "Integer64.shiftRight"
 | .Integer64_shiftRightUnsigned => "Integer64.shiftRightUnsigned"
 | .UnsignedInteger_fromInteger => "UnsignedInteger.fromInteger"
 | .UnsignedInteger_toInteger => "UnsignedInteger.toInteger"
 | .UnsignedInteger_parse => "UnsignedInteger.parse"
 | .UnsignedInteger_toString => "UnsignedInteger.toString"
 | .UnsignedInteger_toFloat => "UnsignedInteger.toFloat"
 | .UnsignedInteger_toDecimal => "UnsignedInteger.toDecimal"
 | .UnsignedInteger_fromDecimal => "UnsignedInteger.fromDecimal"
 | .UnsignedInteger_absolute => "UnsignedInteger.absolute"
 | .UnsignedInteger_minimum => "UnsignedInteger.minimum"
 | .UnsignedInteger_maximum => "UnsignedInteger.maximum"
 | .UnsignedInteger_floorDivide => "UnsignedInteger.floorDivide"
 | .UnsignedInteger_floorModulo => "UnsignedInteger.floorModulo"
 | .UnsignedInteger_bitwiseAnd => "UnsignedInteger.bitwiseAnd"
 | .UnsignedInteger_bitwiseOr => "UnsignedInteger.bitwiseOr"
 | .UnsignedInteger_bitwiseExclusiveOr => "UnsignedInteger.bitwiseExclusiveOr"
 | .UnsignedInteger_bitwiseNot => "UnsignedInteger.bitwiseNot"
 | .UnsignedInteger_shiftLeft => "UnsignedInteger.shiftLeft"
 | .UnsignedInteger_shiftRight => "UnsignedInteger.shiftRight"
 | .UnsignedInteger8_fromInteger => "UnsignedInteger8.fromInteger"
 | .UnsignedInteger8_toInteger => "UnsignedInteger8.toInteger"
 | .UnsignedInteger8_toString => "UnsignedInteger8.toString"
 | .UnsignedInteger8_bitwiseAnd => "UnsignedInteger8.bitwiseAnd"
 | .UnsignedInteger8_bitwiseOr => "UnsignedInteger8.bitwiseOr"
 | .UnsignedInteger8_bitwiseExclusiveOr => "UnsignedInteger8.bitwiseExclusiveOr"
 | .UnsignedInteger8_bitwiseNot => "UnsignedInteger8.bitwiseNot"
 | .UnsignedInteger8_shiftLeft => "UnsignedInteger8.shiftLeft"
 | .UnsignedInteger8_shiftRight => "UnsignedInteger8.shiftRight"
 | .Float64_toString => "Float64.toString"
 | .Float64_parse => "Float64.parse"
 | .Float64_truncate => "Float64.truncate"
 | .Float64_isNaN => "Float64.isNaN"
 | .Float64_absolute => "Float64.absolute"
 | .Float64_floor => "Float64.floor"
 | .Float64_ceiling => "Float64.ceiling"
 | .Float64_round => "Float64.round"
 | .Float64_squareRoot => "Float64.squareRoot"

def API.target : API → String
 | .Integer64_toString => "Integer.toString"
 | .Integer64_parse => "Integer.parse"
 | .Integer64_toFloat => "Integer.toFloat"
 | .Integer64_floorDivide => "Integer.floorDivide"
 | .Integer64_floorModulo => "Integer.floorModulo"
 | .Integer64_absolute => "Integer.absolute"
 | .Integer64_minimum => "Integer.minimum"
 | .Integer64_maximum => "Integer.maximum"
 | .Integer64_bitwiseAnd => "Integer.bitwiseAnd"
 | .Integer64_bitwiseOr => "Integer.bitwiseOr"
 | .Integer64_bitwiseExclusiveOr => "Integer.bitwiseExclusiveOr"
 | .Integer64_bitwiseNot => "Integer.bitwiseNot"
 | .Integer64_shiftLeft => "Integer.shiftLeft"
 | .Integer64_shiftRight => "Integer.shiftRight"
 | .Integer64_shiftRightUnsigned => "Integer.shiftRightUnsigned"
 | .UnsignedInteger_fromInteger => "UnsignedInteger64.fromInteger"
 | .UnsignedInteger_toInteger => "UnsignedInteger64.toInteger"
 | .UnsignedInteger_parse => "UnsignedInteger64.parse"
 | .UnsignedInteger_toString => "UnsignedInteger64.toString"
 | .UnsignedInteger_toFloat => "UnsignedInteger64.toFloat"
 | .UnsignedInteger_toDecimal => "UnsignedInteger64.toDecimal"
 | .UnsignedInteger_fromDecimal => "UnsignedInteger64.fromDecimal"
 | .UnsignedInteger_absolute => "UnsignedInteger64.absolute"
 | .UnsignedInteger_minimum => "UnsignedInteger64.minimum"
 | .UnsignedInteger_maximum => "UnsignedInteger64.maximum"
 | .UnsignedInteger_floorDivide => "UnsignedInteger64.floorDivide"
 | .UnsignedInteger_floorModulo => "UnsignedInteger64.floorModulo"
 | .UnsignedInteger_bitwiseAnd => "UnsignedInteger64.bitwiseAnd"
 | .UnsignedInteger_bitwiseOr => "UnsignedInteger64.bitwiseOr"
 | .UnsignedInteger_bitwiseExclusiveOr => "UnsignedInteger64.bitwiseExclusiveOr"
 | .UnsignedInteger_bitwiseNot => "UnsignedInteger64.bitwiseNot"
 | .UnsignedInteger_shiftLeft => "UnsignedInteger64.shiftLeft"
 | .UnsignedInteger_shiftRight => "UnsignedInteger64.shiftRight"
 | .UnsignedInteger8_fromInteger => "Byte.fromInteger"
 | .UnsignedInteger8_toInteger => "Byte.toInteger"
 | .UnsignedInteger8_toString => "Byte.toString"
 | .UnsignedInteger8_bitwiseAnd => "Byte.bitwiseAnd"
 | .UnsignedInteger8_bitwiseOr => "Byte.bitwiseOr"
 | .UnsignedInteger8_bitwiseExclusiveOr => "Byte.bitwiseExclusiveOr"
 | .UnsignedInteger8_bitwiseNot => "Byte.bitwiseNot"
 | .UnsignedInteger8_shiftLeft => "Byte.shiftLeft"
 | .UnsignedInteger8_shiftRight => "Byte.shiftRight"
 | .Float64_toString => "Float.toString"
 | .Float64_parse => "Float.parse"
 | .Float64_truncate => "Float.truncate"
 | .Float64_isNaN => "Float.isNaN"
 | .Float64_absolute => "Float.absolute"
 | .Float64_floor => "Float.floor"
 | .Float64_ceiling => "Float.ceiling"
 | .Float64_round => "Float.round"
 | .Float64_squareRoot => "Float.squareRoot"

def API.names : API → List String
 | .Integer64_toString => ["n"]
 | .Integer64_parse => ["s"]
 | .Integer64_toFloat => ["n"]
 | .Integer64_floorDivide => ["a","b"]
 | .Integer64_floorModulo => ["a","b"]
 | .Integer64_absolute => ["n"]
 | .Integer64_minimum => ["a","b"]
 | .Integer64_maximum => ["a","b"]
 | .Integer64_bitwiseAnd => ["a","b"]
 | .Integer64_bitwiseOr => ["a","b"]
 | .Integer64_bitwiseExclusiveOr => ["a","b"]
 | .Integer64_bitwiseNot => ["a"]
 | .Integer64_shiftLeft => ["a","n"]
 | .Integer64_shiftRight => ["a","n"]
 | .Integer64_shiftRightUnsigned => ["a","n"]
 | .UnsignedInteger_fromInteger => ["n"]
 | .UnsignedInteger_toInteger => ["n"]
 | .UnsignedInteger_parse => ["s"]
 | .UnsignedInteger_toString => ["n"]
 | .UnsignedInteger_toFloat => ["n"]
 | .UnsignedInteger_toDecimal => ["n"]
 | .UnsignedInteger_fromDecimal => ["x"]
 | .UnsignedInteger_absolute => ["n"]
 | .UnsignedInteger_minimum => ["a","b"]
 | .UnsignedInteger_maximum => ["a","b"]
 | .UnsignedInteger_floorDivide => ["a","b"]
 | .UnsignedInteger_floorModulo => ["a","b"]
 | .UnsignedInteger_bitwiseAnd => ["a","b"]
 | .UnsignedInteger_bitwiseOr => ["a","b"]
 | .UnsignedInteger_bitwiseExclusiveOr => ["a","b"]
 | .UnsignedInteger_bitwiseNot => ["a"]
 | .UnsignedInteger_shiftLeft => ["a","n"]
 | .UnsignedInteger_shiftRight => ["a","n"]
 | .UnsignedInteger8_fromInteger => ["n"]
 | .UnsignedInteger8_toInteger => ["b"]
 | .UnsignedInteger8_toString => ["b"]
 | .UnsignedInteger8_bitwiseAnd => ["a","b"]
 | .UnsignedInteger8_bitwiseOr => ["a","b"]
 | .UnsignedInteger8_bitwiseExclusiveOr => ["a","b"]
 | .UnsignedInteger8_bitwiseNot => ["a"]
 | .UnsignedInteger8_shiftLeft => ["a","n"]
 | .UnsignedInteger8_shiftRight => ["a","n"]
 | .Float64_toString => ["x"]
 | .Float64_parse => ["s"]
 | .Float64_truncate => ["x"]
 | .Float64_isNaN => ["x"]
 | .Float64_absolute => ["x"]
 | .Float64_floor => ["x"]
 | .Float64_ceiling => ["x"]
 | .Float64_round => ["x"]
 | .Float64_squareRoot => ["x"]

def API.inputs : API → List Ty
 | .Integer64_toString => [(.base .integer)]
 | .Integer64_parse => [(.base .string)]
 | .Integer64_toFloat => [(.base .integer)]
 | .Integer64_floorDivide => [(.base .integer),(.base .integer)]
 | .Integer64_floorModulo => [(.base .integer),(.base .integer)]
 | .Integer64_absolute => [(.base .integer)]
 | .Integer64_minimum => [(.base .integer),(.base .integer)]
 | .Integer64_maximum => [(.base .integer),(.base .integer)]
 | .Integer64_bitwiseAnd => [(.base .integer),(.base .integer)]
 | .Integer64_bitwiseOr => [(.base .integer),(.base .integer)]
 | .Integer64_bitwiseExclusiveOr => [(.base .integer),(.base .integer)]
 | .Integer64_bitwiseNot => [(.base .integer)]
 | .Integer64_shiftLeft => [(.base .integer),(.base .integer)]
 | .Integer64_shiftRight => [(.base .integer),(.base .integer)]
 | .Integer64_shiftRightUnsigned => [(.base .integer),(.base .integer)]
 | .UnsignedInteger_fromInteger => [(.base .integer)]
 | .UnsignedInteger_toInteger => [(.base .unsignedInteger64)]
 | .UnsignedInteger_parse => [(.base .string)]
 | .UnsignedInteger_toString => [(.base .unsignedInteger64)]
 | .UnsignedInteger_toFloat => [(.base .unsignedInteger64)]
 | .UnsignedInteger_toDecimal => [(.base .unsignedInteger64)]
 | .UnsignedInteger_fromDecimal => [(.base .decimal)]
 | .UnsignedInteger_absolute => [(.base .unsignedInteger64)]
 | .UnsignedInteger_minimum => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_maximum => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_floorDivide => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_floorModulo => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_bitwiseAnd => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_bitwiseOr => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_bitwiseExclusiveOr => [(.base .unsignedInteger64),(.base .unsignedInteger64)]
 | .UnsignedInteger_bitwiseNot => [(.base .unsignedInteger64)]
 | .UnsignedInteger_shiftLeft => [(.base .unsignedInteger64),(.base .integer)]
 | .UnsignedInteger_shiftRight => [(.base .unsignedInteger64),(.base .integer)]
 | .UnsignedInteger8_fromInteger => [(.base .integer)]
 | .UnsignedInteger8_toInteger => [(.base .byte)]
 | .UnsignedInteger8_toString => [(.base .byte)]
 | .UnsignedInteger8_bitwiseAnd => [(.base .byte),(.base .byte)]
 | .UnsignedInteger8_bitwiseOr => [(.base .byte),(.base .byte)]
 | .UnsignedInteger8_bitwiseExclusiveOr => [(.base .byte),(.base .byte)]
 | .UnsignedInteger8_bitwiseNot => [(.base .byte)]
 | .UnsignedInteger8_shiftLeft => [(.base .byte),(.base .integer)]
 | .UnsignedInteger8_shiftRight => [(.base .byte),(.base .integer)]
 | .Float64_toString => [(.base .float)]
 | .Float64_parse => [(.base .string)]
 | .Float64_truncate => [(.base .float)]
 | .Float64_isNaN => [(.base .float)]
 | .Float64_absolute => [(.base .float)]
 | .Float64_floor => [(.base .float)]
 | .Float64_ceiling => [(.base .float)]
 | .Float64_round => [(.base .float)]
 | .Float64_squareRoot => [(.base .float)]

def API.result : API → Ty
 | .Integer64_toString => (.base .string)
 | .Integer64_parse => (.data "Option" [(.base .integer)])
 | .Integer64_toFloat => (.base .float)
 | .Integer64_floorDivide => (.base .integer)
 | .Integer64_floorModulo => (.base .integer)
 | .Integer64_absolute => (.base .integer)
 | .Integer64_minimum => (.base .integer)
 | .Integer64_maximum => (.base .integer)
 | .Integer64_bitwiseAnd => (.base .integer)
 | .Integer64_bitwiseOr => (.base .integer)
 | .Integer64_bitwiseExclusiveOr => (.base .integer)
 | .Integer64_bitwiseNot => (.base .integer)
 | .Integer64_shiftLeft => (.base .integer)
 | .Integer64_shiftRight => (.base .integer)
 | .Integer64_shiftRightUnsigned => (.base .integer)
 | .UnsignedInteger_fromInteger => (.data "Option" [(.base .unsignedInteger64)])
 | .UnsignedInteger_toInteger => (.data "Option" [(.base .integer)])
 | .UnsignedInteger_parse => (.data "Option" [(.base .unsignedInteger64)])
 | .UnsignedInteger_toString => (.base .string)
 | .UnsignedInteger_toFloat => (.base .float)
 | .UnsignedInteger_toDecimal => (.base .decimal)
 | .UnsignedInteger_fromDecimal => (.data "Option" [(.base .unsignedInteger64)])
 | .UnsignedInteger_absolute => (.base .unsignedInteger64)
 | .UnsignedInteger_minimum => (.base .unsignedInteger64)
 | .UnsignedInteger_maximum => (.base .unsignedInteger64)
 | .UnsignedInteger_floorDivide => (.base .unsignedInteger64)
 | .UnsignedInteger_floorModulo => (.base .unsignedInteger64)
 | .UnsignedInteger_bitwiseAnd => (.base .unsignedInteger64)
 | .UnsignedInteger_bitwiseOr => (.base .unsignedInteger64)
 | .UnsignedInteger_bitwiseExclusiveOr => (.base .unsignedInteger64)
 | .UnsignedInteger_bitwiseNot => (.base .unsignedInteger64)
 | .UnsignedInteger_shiftLeft => (.base .unsignedInteger64)
 | .UnsignedInteger_shiftRight => (.base .unsignedInteger64)
 | .UnsignedInteger8_fromInteger => (.data "Option" [(.base .byte)])
 | .UnsignedInteger8_toInteger => (.base .integer)
 | .UnsignedInteger8_toString => (.base .string)
 | .UnsignedInteger8_bitwiseAnd => (.base .byte)
 | .UnsignedInteger8_bitwiseOr => (.base .byte)
 | .UnsignedInteger8_bitwiseExclusiveOr => (.base .byte)
 | .UnsignedInteger8_bitwiseNot => (.base .byte)
 | .UnsignedInteger8_shiftLeft => (.base .byte)
 | .UnsignedInteger8_shiftRight => (.base .byte)
 | .Float64_toString => (.base .string)
 | .Float64_parse => (.data "Option" [(.base .float)])
 | .Float64_truncate => (.data "Option" [(.base .integer)])
 | .Float64_isNaN => (.base .boolean)
 | .Float64_absolute => (.base .float)
 | .Float64_floor => (.base .float)
 | .Float64_ceiling => (.base .float)
 | .Float64_round => (.base .float)
 | .Float64_squareRoot => (.base .float)

def API.signature (api : API) : PrimSig :=
 ⟨[],0,api.names,api.inputs,api.result,Eff.empty,(fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

def API.body (api : API) : Comp :=
 .app (.prim api.target [] [] []) ((List.range api.inputs.length).reverse.map Val.var)

def API.row (api : API) : StandardContracts.Row :=
 ⟨api.name,[],0,api.signature.tel,some api.body,.core,[]⟩

def API.all : List API := [.Integer64_toString,.Integer64_parse,.Integer64_toFloat,.Integer64_floorDivide,.Integer64_floorModulo,.Integer64_absolute,.Integer64_minimum,.Integer64_maximum,.Integer64_bitwiseAnd,.Integer64_bitwiseOr,.Integer64_bitwiseExclusiveOr,.Integer64_bitwiseNot,.Integer64_shiftLeft,.Integer64_shiftRight,.Integer64_shiftRightUnsigned,.UnsignedInteger_fromInteger,.UnsignedInteger_toInteger,.UnsignedInteger_parse,.UnsignedInteger_toString,.UnsignedInteger_toFloat,.UnsignedInteger_toDecimal,.UnsignedInteger_fromDecimal,.UnsignedInteger_absolute,.UnsignedInteger_minimum,.UnsignedInteger_maximum,.UnsignedInteger_floorDivide,.UnsignedInteger_floorModulo,.UnsignedInteger_bitwiseAnd,.UnsignedInteger_bitwiseOr,.UnsignedInteger_bitwiseExclusiveOr,.UnsignedInteger_bitwiseNot,.UnsignedInteger_shiftLeft,.UnsignedInteger_shiftRight,.UnsignedInteger8_fromInteger,.UnsignedInteger8_toInteger,.UnsignedInteger8_toString,.UnsignedInteger8_bitwiseAnd,.UnsignedInteger8_bitwiseOr,.UnsignedInteger8_bitwiseExclusiveOr,.UnsignedInteger8_bitwiseNot,.UnsignedInteger8_shiftLeft,.UnsignedInteger8_shiftRight,.Float64_toString,.Float64_parse,.Float64_truncate,.Float64_isNaN,.Float64_absolute,.Float64_floor,.Float64_ceiling,.Float64_round,.Float64_squareRoot]

def API.definition (api : API) : Def :=
 ⟨[],0,api.names,api.inputs,api.result,Eff.empty,api.body⟩

def program : Program :=
 {StandardCollectionModel.program with defs := (fun name =>
   API.all.findSome? (fun api => if name=api.name then some api.definition else none))}

private def P : Program := program

private theorem option_arity : P.DataArity "Option" 1 := StandardConversionResponse.option_arity

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

local macro "alias_simp" : tactic => `(tactic|
 simp_all [API.signature,API.names,API.inputs,API.result,API.target,API.row,API.body,
  StandardContracts.Row.definition,Def.WellTyped,Def.tel,PrimSig.tel,signatureTel,
  Tel.names,Tel.inputs,Tel.result,Tel.effect,
  TypeCtx.kinds,TypeCtx.constraints,TypeAnnotations,Ty.Annotation,
  Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
  Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
  NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Ordinary,Ty.core,
  Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
  Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,
  Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,
  SubstEnv.rangesOnly,Eff.rawBind,rowFails,substAtoms_nil,instAtoms_nil,
  Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
  TypeArgsKinded,RowAnnotations,empty_range,RowTransport,NoFail,Eff.test,Eff.atoms,Eff.fails,Eff.shiftV,Ty.shiftV,shiftVTys,Tel.shiftV,
  Ctx.extend,bindParams,localExtend,Pred.lift,liftMany,
  TyCon.arity_data option_arity,option_arity])

private theorem signature_formed (api : API) (Γ : Ctx) :
 Ty.Annotation P [] Γ (.fn api.names api.inputs api.result Eff.empty) := by
 cases api <;> constructor <;> alias_simp

private theorem primitive {B Ψ Q Γ Φ} (api : API)
 (lookup : B.sig api.target=some api.signature) :
 HasTypeVQ P B Ψ Q [] Γ Φ (.prim api.target [] [] [])
  (.fn api.names api.inputs api.result Eff.empty) := by
 apply (HasTypeVQ.V_Prim lookup ?_ ?_ ?_ ?_).convert ?_ (signature_formed api Γ)
 · cases api <;> alias_simp
 · cases api <;> alias_simp
 · cases api <;> constructor <;> alias_simp
 · cases api <;> constructor <;> try simp only [empty_range]
   all_goals try alias_simp
   all_goals constructor <;> alias_simp
 · have fold := Ty.foldFn_toTel ⟨api.names,api.inputs,api.result,Eff.empty,by cases api <;> simp [API.names,API.inputs,NamesWF]⟩
   cases api <;> alias_simp
   all_goals simpa [API.names,API.inputs,API.result,FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using fold

/-- 実署名の同じ組込みを一度呼ぶ通常本体を、固定の型付け規則で検査する。 -/
theorem body_typed {B} (api : API) (lookup : B.sig api.target=some api.signature) :
 api.row.BodyTyped P B := by
 refine ⟨⟨[],0,api.names,api.inputs,api.result,Eff.empty,api.body⟩,?_,?_,?_,?_,?_⟩
 · cases api <;> rfl
 · cases api <;> alias_simp
 · cases api <;> alias_simp
 · cases api <;> constructor <;> alias_simp
 · have fn := fun Γ Φ => primitive (Ψ := StoreTy.empty) (Q := QTel api.signature.tel) (Γ := Γ) (Φ := Φ) api lookup
   cases api
   all_goals apply TelBodyTy.param
   all_goals first
    | (apply TelBodyTy.done; apply HasTypeCQ.C_App (fn _ _); exact .cons (.V_Var rfl (by intro b t e h; cases h)) .nil)
    | (apply TelBodyTy.param; apply TelBodyTy.done; apply HasTypeCQ.C_App (fn _ _)
       exact .cons (.V_Var rfl (by intro b t e h; cases h)) (.cons (.V_Var rfl (by intro b t e h; cases h)) .nil))

def table (base : Builtins) : Builtins :=
 {base with sig := fun name =>
  API.all.findSome? fun api => if name=api.target then some api.signature else none}

private theorem target_lookup (base : Builtins) (api : API) :
 (table base).sig api.target=some api.signature := by
 cases api <;> simp [table,API.all,API.target,API.signature,API.names,API.inputs,API.result,List.findSome?]

/-- 同じ有限表に元の公開名と本体を登録し、lookupと本体型付けを供給する。 -/
theorem declarations_typed (base : Builtins) (api : API) :
 program.defs api.name=some api.definition ∧ api.row.definition=some api.definition ∧
 api.definition.WellTyped program (table base) := by
 have typed := body_typed api (target_lookup base api)
 have row : api.row.definition=some api.definition := by cases api <;> rfl
 obtain ⟨d,hd,ht⟩ := typed
 have same : d=api.definition := Option.some.inj (hd.symm.trans row)
 subst d
 refine ⟨?_,row,ht⟩
 cases api <;> simp [program,API.all,API.name,API.definition,API.names,API.inputs,API.result,API.body,API.target,List.findSome?]

example (base : Builtins) (api : API) : api.definition.WellTyped program (table base) :=
 (declarations_typed base api).2.2
example (base : Builtins) (api : API) :
 program.defs api.name=some api.definition := (declarations_typed base api).1
end
end Benitoite.Release.Refinement.StandardAliasBodies
