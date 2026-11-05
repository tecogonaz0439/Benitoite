import Benitoite.Release.Refinement.FunctionNameMap
import Benitoite.Release.Refinement.StandardOrdinaryListBodies
import Benitoite.Release.Refinement.StandardOrderResponse

/-! # 通常の標準coreの有限宣言と全本体 -/
namespace Benitoite.Release.Refinement.StandardOrdinaryCoreProgram
noncomputable section
set_option maxRecDepth 6000
set_option maxHeartbeats 6000000
set_option linter.unusedSimpArgs false
open StandardOrdinaryCoreBodies
/-- 鍵の制約を持つ値の型パラメータ。 -/
def keyParam : TParamDecl := ⟨TParam.keyC,.value⟩
private def ci : Ty := Record.type .checkedInteger
private def cl : Ty := Record.type .checkedLength
private def cx : Ty := Record.type .checkedIndex
private def ne (a : Ty) : Ty := .data (Record.owner .nonempty) [a]
private def result (a : Ty) (err : String) : Ty := .data StandardSafe.names.result [a,.data err []]
private def rangeResult : Ty := result ci "Benitoite.Range.RangeError"
private def lengthResult : Ty := result cl "Benitoite.Range.LengthError"
private def indexResult : Ty := result cx "Benitoite.Range.IndexError"
private def nonemptyResult : Ty := result (ne (.tvar 0)) StandardSafe.names.emptyListError
/-- 二つの型パラメータのPair。 -/
def pair : Ty := .data "Pair" [.tvar 0,.tvar 1]
private def int : Ty := .base .integer
private def bool : Ty := .base .boolean
private def unit : Val := .const .unit
private def trueV : Val := .const (.boolean true)
private def zero : Val := .const (.integer ⟨0,by decide⟩)
private def app2 (name : String) (a b : Nat) : Comp := .app (.prim name [] [] []) [.var a,.var b]
private def less (a b : Nat) : Comp := app2 "%Integer.less" a b
private def greater (a b : Nat) : Comp := app2 "%Integer.greater" a b
private def listLength (i : Nat) : Comp := .app (.prim "List.length" [.tvar 0] [] []) [.var i]
private def ok (a : Ty) (err : String) (v : Val) : Val := .con "Benitoite.Result.Result.Ok" [a,.data err []] [v]
private def error (a : Ty) (err ctor : String) (vs : List Val) : Val :=
 .con "Benitoite.Result.Result.Error" [a,.data err []] [.con ctor [] vs]
private def projection (first : Bool) (i : Nat) : Comp := .app (.fnRef (if first then "Pair.first" else "Pair.second") [.tvar 0,.tvar 1] []) [.var i]
private def neProjection (first : Bool) (i : Nat) : Comp := .app (.fnRef (if first then Getter.first.name else Getter.rest.name) [.tvar 0] []) [.var i]

inductive API where
 | mapFold | mapForEach | setFold | setForEach
 | checkInteger | checkLength | checkIndex | nonemptyFromList | nonemptyToList | nonemptyMap
 deriving DecidableEq

def API.name : API → String
 | .mapFold => "Map.fold" | .mapForEach => "Map.forEach" | .setFold => "Set.fold" | .setForEach => "Set.forEach"
 | .checkInteger => "Range.checkInteger" | .checkLength => "Range.checkLength" | .checkIndex => "Range.checkIndex"
 | .nonemptyFromList => "NonEmptyList.fromList" | .nonemptyToList => "NonEmptyList.toList" | .nonemptyMap => "NonEmptyList.map"
def API.context : API → TypeCtx
 | .mapFold => [keyParam,TypeCtx.valueParam,TypeCtx.valueParam]
 | .mapForEach | .setFold => [keyParam,TypeCtx.valueParam]
 | .setForEach => [keyParam] | .checkInteger => []
 | .nonemptyMap => [TypeCtx.valueParam,TypeCtx.valueParam] | _ => [TypeCtx.valueParam]
def API.effect : API → Eff
 | .mapFold | .mapForEach | .setFold | .setForEach | .nonemptyMap => Eff.row 0
 | _ => Eff.empty
def API.neffs : API → Nat
 | .mapFold | .mapForEach | .setFold | .setForEach | .nonemptyMap => 1 | _ => 0
def API.names : API → List String
 | .mapFold => ["m","initial","f"] | .setFold => ["s","initial","f"]
 | .mapForEach => ["m","f"] | .setForEach => ["s","f"]
 | .checkInteger => ["minimum","maximum","value"] | .checkLength => ["minimum","maximum","values"]
 | .checkIndex => ["index","values"] | .nonemptyFromList => ["values"]
 | .nonemptyToList => ["value"] | .nonemptyMap => ["value","f"]
def API.inputs : API → List Ty
 | .mapFold => [.map (.tvar 0) (.tvar 1),.tvar 2,.fn ["acc","key","value"] [.tvar 2,.tvar 0,.tvar 1] (.tvar 2) (Eff.row 0)]
 | .mapForEach => [.map (.tvar 0) (.tvar 1),.fn ["key","value"] [.tvar 0,.tvar 1] (.base .unit) (Eff.row 0)]
 | .setFold => [.set (.tvar 0),.tvar 1,.fn ["acc","value"] [.tvar 1,.tvar 0] (.tvar 1) (Eff.row 0)]
 | .setForEach => [.set (.tvar 0),.fn ["value"] [.tvar 0] (.base .unit) (Eff.row 0)]
 | .checkInteger => [int,int,int] | .checkLength => [int,int,.list (.tvar 0)]
 | .checkIndex => [int,.list (.tvar 0)] | .nonemptyFromList => [.list (.tvar 0)]
 | .nonemptyToList => [ne (.tvar 0)]
 | .nonemptyMap => [ne (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 1) (Eff.row 0)]
def API.result : API → Ty
 | .mapFold => .tvar 2 | .setFold => .tvar 1 | .mapForEach | .setForEach => .base .unit
 | .checkInteger => rangeResult | .checkLength => lengthResult | .checkIndex => indexResult
 | .nonemptyFromList => nonemptyResult | .nonemptyToList => .list (.tvar 0) | .nonemptyMap => ne (.tvar 1)

private def mapFoldCallback : Comp := .letIn (projection true 0)
 (.letIn (projection false 1) (.app (.var 5) [.var 3,.var 1,.var 0]))
private def mapEachCallback : Comp := .letIn (projection true 0)
 (.letIn (projection false 1) (.app (.var 4) [.var 1,.var 0]))
private def integerOutside : Comp := .letIn (less 1 3) (.ite (.var 0) (.ret trueV) (greater 2 3))
private def invalidLength : Comp := .letIn (.app (.prim "%Integer.less" [] [] []) [.var 2,zero])
 (.ite (.var 0) (.ret trueV) (less 2 3))
private def lengthOutside : Comp := .letIn (less 0 4) (.ite (.var 0) (.ret trueV) (less 4 1))

def API.body : API → Comp
 | .mapFold => .letIn (.app (.prim "Map.toList" [.tvar 0,.tvar 1] [] []) [.var 2])
    (.app (.fnRef "List.fold" [pair,.tvar 2] [Eff.row 0]) [.var 0,.var 2,.lam ["acc","value"] [.tvar 2,pair] mapFoldCallback])
 | .mapForEach => .letIn (.app (.prim "Map.toList" [.tvar 0,.tvar 1] [] []) [.var 1])
    (.app (.fnRef "List.forEach" [pair] [Eff.row 0]) [.var 0,.lam ["value"] [pair] mapEachCallback])
 | .setFold => .letIn (.app (.prim "Set.toList" [.tvar 0] [] []) [.var 2])
    (.app (.fnRef "List.fold" [.tvar 0,.tvar 1] [Eff.row 0]) [.var 0,.var 2,.var 1])
 | .setForEach => .letIn (.app (.prim "Set.toList" [.tvar 0] [] []) [.var 1])
    (.app (.fnRef "List.forEach" [.tvar 0] [Eff.row 0]) [.var 0,.var 1])
 | .checkInteger => .letIn (greater 2 1)
    (.ite (.var 0)
      (.ret (error ci "Benitoite.Range.RangeError" "Benitoite.Range.RangeError.InvalidBounds" [.var 3,.var 2]))
      (.letIn integerOutside (.ite (.var 0)
        (.ret (error ci "Benitoite.Range.RangeError" "Benitoite.Range.RangeError.OutOfRange" [.var 4,.var 3,.var 2]))
        (.ret (ok ci "Benitoite.Range.RangeError" (.con (Record.owner .checkedInteger) [] [.var 4,.var 3,.var 2]))))))
 | .checkLength => .letIn
    (.letIn invalidLength (.ite (.var 0)
      (.escape (error cl "Benitoite.Range.LengthError" "Benitoite.Range.LengthError.InvalidBounds" [.var 3,.var 2]))
      (.ret unit)))
    (.letIn (listLength 1) (.letIn lengthOutside (.ite (.var 0)
      (.ret (error cl "Benitoite.Range.LengthError" "Benitoite.Range.LengthError.OutOfRange" [.var 5,.var 4,.var 1]))
      (.ret (ok cl "Benitoite.Range.LengthError" (.con (Record.owner .checkedLength) [.tvar 0] [.var 5,.var 4,.var 1,.var 3]))))))
 | .checkIndex => .letIn (.app (.prim "List.get" [.tvar 0] [] []) [.var 0,.var 1])
    (.match (.var 0) [
      .mk [⟨.con "Option.None" [],[]⟩] none (.letIn (listLength 1)
        (.ret (error cx "Benitoite.Range.IndexError" "Benitoite.Range.IndexError.OutOfBounds" [.var 3,.var 0]))),
      .mk [⟨.con "Option.Some" [.var],[0]⟩] none
        (.ret (ok cx "Benitoite.Range.IndexError" (.con (Record.owner .checkedIndex) [.tvar 0] [.var 2,.var 3,.var 0])))])
 | .nonemptyFromList => .match (.var 0) [
    .mk [⟨.list [] none [],[]⟩] none (.ret (error (ne (.tvar 0)) StandardSafe.names.emptyListError "Benitoite.NonEmptyList.EmptyListError.EmptyList" [])),
    .mk [⟨.list [.var] (some .bind) [],[0,1]⟩] none
      (.ret (ok (ne (.tvar 0)) StandardSafe.names.emptyListError (.con (Record.owner .nonempty) [.tvar 0] [.var 1,.var 0])))]
 | .nonemptyToList => .letIn (neProjection false 0) (.letIn (neProjection true 1)
    (.app (.prim "List.prepend" [.tvar 0] [] []) [.var 1,.var 0]))
 | .nonemptyMap => .letIn (neProjection true 1) (.letIn (.app (.var 1) [.var 0])
    (.letIn (neProjection false 3) (.letIn (.app (.fnRef "List.map" [.tvar 0,.tvar 1] [Eff.row 0]) [.var 0,.var 3])
      (.ret (.con (Record.owner .nonempty) [.tvar 1] [.var 2,.var 0])))))

def API.definition (a : API) : Def := ⟨a.context,a.neffs,a.names,a.inputs,a.result,a.effect,a.body⟩
def API.all : List API := [.mapFold,.mapForEach,.setFold,.setForEach,.checkInteger,.checkLength,.checkIndex,.nonemptyFromList,.nonemptyToList,.nonemptyMap]
def definitions : List (FunName × Def) := API.all.map fun a => (a.name,a.definition)
def listMapDefinition : Def :=
 ⟨[TypeCtx.valueParam,TypeCtx.valueParam],1,["xs","f"],
 [.list (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 1) (Eff.row 0)],.list (.tvar 1),Eff.row 0,
 (StandardBodies.listHigherRow false).body.getD (.ret unit)⟩
def listMapFromDefinition : Def := StandardBodies.listFromDefinition false

def pairDefinition (second : Bool) : Def :=
 ⟨[TypeCtx.valueParam,TypeCtx.valueParam],0,["p"],[pair],.tvar (if second then 1 else 0),Eff.empty,
 .match (.var 0) [.mk [⟨.con "Pair.Pair" [if second then .wild else .var,if second then .var else .wild],[0]⟩] none (.ret (.var 0))]⟩
def supportDefinitions : List (FunName × Def) := [
 ("Pair.first",pairDefinition false),
 ("Pair.second",pairDefinition true),
 ("List.map",listMapDefinition),("List.mapFrom",listMapFromDefinition)]
def allDefinitions : List (FunName × Def) := definitions ++ StandardOrdinaryListBodies.definitions ++ StandardOrdinaryCoreBodies.definitions ++ supportDefinitions

def program : Program := {StandardOrdinaryCoreBodies.program with defs := fun n => allDefinitions.lookup n}
def builtins : Builtins := { StandardOrdinaryListBodies.builtins with
 sig := fun n => if n="List.length" then some (StandardListResponse.API.signature .length)
  else if n="List.prepend" then some (StandardListResponse.API.signature .prepend)
  else if n="List.append" then some StandardBodies.listAppendSig
  else if n="%Integer.less" ∨ n="%Integer.greater" then some (StandardOrderResponse.signature .integer64)
  else StandardOrdinaryListBodies.builtins.sig n }

inductive DataId where
 | option | pair | result | ci | cl | cx | ne | rangeError | lengthError | indexError | emptyError
 deriving DecidableEq
def DataId.owner : DataId → String
 | .option => "Option"
 | .pair => "Pair"
 | .result => StandardSafe.names.result
 | .ci => Record.owner .checkedInteger
 | .cl => Record.owner .checkedLength
 | .cx => Record.owner .checkedIndex
 | .ne => Record.owner .nonempty
 | .rangeError => "Benitoite.Range.RangeError"
 | .lengthError => "Benitoite.Range.LengthError"
 | .indexError => "Benitoite.Range.IndexError"
 | .emptyError => StandardSafe.names.emptyListError
def DataId.count : DataId → Nat
 | .option => 1
 | .pair => 2
 | .result => 2
 | .ci => 0
 | .cl => 1
 | .cx => 1
 | .ne => 1
 | .rangeError => 0
 | .lengthError => 0
 | .indexError => 0
 | .emptyError => 0
def DataId.ctor : DataId → String
 | .option => "Option.None"
 | .pair => "Pair.Pair"
 | .result => "Benitoite.Result.Result.Ok"
 | .ci => Record.owner .checkedInteger
 | .cl => Record.owner .checkedLength
 | .cx => Record.owner .checkedIndex
 | .ne => Record.owner .nonempty
 | .rangeError => "Benitoite.Range.RangeError.InvalidBounds"
 | .lengthError => "Benitoite.Range.LengthError.InvalidBounds"
 | .indexError => "Benitoite.Range.IndexError.OutOfBounds"
 | .emptyError => "Benitoite.NonEmptyList.EmptyListError.EmptyList"
def DataId.fields : DataId → List Ty
 | .option => []
 | .pair => [.tvar 0,.tvar 1]
 | .result => [.tvar 0]
 | .ci => Record.fields .checkedInteger
 | .cl => Record.fields .checkedLength
 | .cx => Record.fields .checkedIndex
 | .ne => Record.fields .nonempty
 | .rangeError => [int,int]
 | .lengthError => [int,int]
 | .indexError => [int,int]
 | .emptyError => []
private theorem cons_mem {c cd} (h : program.cons c=some cd) : (c,cd) ∈ constructorTable := by
 obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp h
 rw [eq]; exact List.mem_append_right _ (List.mem_cons_self ..)

theorem data_arity (d : DataId) : program.DataArity d.owner d.count := by
 have lookup : program.cons d.ctor=some ⟨d.owner,d.count,d.fields⟩ := by cases d <;> rfl
 refine ⟨⟨d.ctor,_,lookup,rfl⟩,?_⟩
 intro c cd h owner
 have mem := cons_mem h
 simp [constructorTable,declarations,StandardKeyTyping.DataDecl.entries,List.mem_cons,List.not_mem_nil,Prod.mk.injEq] at mem
 cases d
 all_goals rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
 all_goals simp_all [DataId.owner,DataId.count,Record.owner,StandardSafe.names]

inductive Ref where
 | foldMap | foldSet | eachMap | eachSet | pairFirstFold | pairSecondFold | pairFirstEach | pairSecondEach | neFirstList | neRestList | neFirstMap | neRestMap | listMap
 deriving DecidableEq
def Ref.context : Ref → TypeCtx
 | .foldMap => API.context .mapFold
 | .foldSet => API.context .setFold
 | .eachMap => API.context .mapForEach
 | .eachSet => API.context .setForEach
 | .pairFirstFold => API.context .mapFold
 | .pairSecondFold => API.context .mapFold
 | .pairFirstEach => API.context .mapForEach
 | .pairSecondEach => API.context .mapForEach
 | .neFirstList => API.context .nonemptyToList
 | .neRestList => API.context .nonemptyToList
 | .neFirstMap => API.context .nonemptyMap
 | .neRestMap => API.context .nonemptyMap
 | .listMap => API.context .nonemptyMap
def Ref.source : Ref → Def
 | .foldMap => StandardOrdinaryListBodies.Op.fold.publicDefinition
 | .foldSet => StandardOrdinaryListBodies.Op.fold.publicDefinition
 | .eachMap => StandardOrdinaryListBodies.Op.forEach.publicDefinition
 | .eachSet => StandardOrdinaryListBodies.Op.forEach.publicDefinition
 | .pairFirstFold => pairDefinition false
 | .pairSecondFold => pairDefinition true
 | .pairFirstEach => pairDefinition false
 | .pairSecondEach => pairDefinition true
 | .neFirstList => Getter.first.definition
 | .neRestList => Getter.rest.definition
 | .neFirstMap => Getter.first.definition
 | .neRestMap => Getter.rest.definition
 | .listMap => listMapDefinition
def Ref.name : Ref → String
 | .foldMap => "List.fold"
 | .foldSet => "List.fold"
 | .eachMap => "List.forEach"
 | .eachSet => "List.forEach"
 | .pairFirstFold => "Pair.first"
 | .pairSecondFold => "Pair.second"
 | .pairFirstEach => "Pair.first"
 | .pairSecondEach => "Pair.second"
 | .neFirstList => Getter.first.name
 | .neRestList => Getter.rest.name
 | .neFirstMap => Getter.first.name
 | .neRestMap => Getter.rest.name
 | .listMap => "List.map"
def Ref.args : Ref → List Ty
 | .foldMap => [pair,.tvar 2]
 | .foldSet => [.tvar 0,.tvar 1]
 | .eachMap => [pair]
 | .eachSet => [.tvar 0]
 | .pairFirstFold => [.tvar 0,.tvar 1]
 | .pairSecondFold => [.tvar 0,.tvar 1]
 | .pairFirstEach => [.tvar 0,.tvar 1]
 | .pairSecondEach => [.tvar 0,.tvar 1]
 | .neFirstList => [.tvar 0]
 | .neRestList => [.tvar 0]
 | .neFirstMap => [.tvar 0]
 | .neRestMap => [.tvar 0]
 | .listMap => [.tvar 0,.tvar 1]
def Ref.names : Ref → List String
 | .foldMap => ["xs","initial","f"]
 | .foldSet => ["xs","initial","f"]
 | .eachMap => ["xs","f"]
 | .eachSet => ["xs","f"]
 | .pairFirstFold => ["p"]
 | .pairSecondFold => ["p"]
 | .pairFirstEach => ["p"]
 | .pairSecondEach => ["p"]
 | .neFirstList => ["value"]
 | .neRestList => ["value"]
 | .neFirstMap => ["value"]
 | .neRestMap => ["value"]
 | .listMap => ["xs","f"]
def Ref.inputs : Ref → List Ty
 | .foldMap => [.list pair,.tvar 2,.fn ["acc","value"] [.tvar 2,pair] (.tvar 2) (Eff.row 0)]
 | .foldSet => [.list (.tvar 0),.tvar 1,.fn ["acc","value"] [.tvar 1,.tvar 0] (.tvar 1) (Eff.row 0)]
 | .eachMap => [.list pair,.fn ["value"] [pair] (.base .unit) (Eff.row 0)]
 | .eachSet => [.list (.tvar 0),.fn ["value"] [.tvar 0] (.base .unit) (Eff.row 0)]
 | .pairFirstFold => [pair]
 | .pairSecondFold => [pair]
 | .pairFirstEach => [pair]
 | .pairSecondEach => [pair]
 | .neFirstList => [ne (.tvar 0)]
 | .neRestList => [ne (.tvar 0)]
 | .neFirstMap => [ne (.tvar 0)]
 | .neRestMap => [ne (.tvar 0)]
 | .listMap => [.list (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 1) (Eff.row 0)]
def Ref.result : Ref → Ty
 | .foldMap => .tvar 2
 | .foldSet => .tvar 1
 | .eachMap => .base .unit
 | .eachSet => .base .unit
 | .pairFirstFold => .tvar 0
 | .pairSecondFold => .tvar 1
 | .pairFirstEach => .tvar 0
 | .pairSecondEach => .tvar 1
 | .neFirstList => .tvar 0
 | .neRestList => .list (.tvar 0)
 | .neFirstMap => .tvar 0
 | .neRestMap => .list (.tvar 0)
 | .listMap => .list (.tvar 1)
def Ref.effect : Ref → Eff
 | .foldMap => Eff.row 0
 | .foldSet => Eff.row 0
 | .eachMap => Eff.row 0
 | .eachSet => Eff.row 0
 | .pairFirstFold => Eff.empty
 | .pairSecondFold => Eff.empty
 | .pairFirstEach => Eff.empty
 | .pairSecondEach => Eff.empty
 | .neFirstList => Eff.empty
 | .neRestList => Eff.empty
 | .neFirstMap => Eff.empty
 | .neRestMap => Eff.empty
 | .listMap => Eff.row 0
def Ref.rows (r : Ref) : List Eff := if r.source.neffs=0 then [] else [Eff.row 0]

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]
private theorem row_self : substAtoms [Eff.row 0] (Eff.row 0).atoms = (Eff.row 0).atoms := by
 funext a
 cases a with
 | name l r => simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
 | rho i => cases i <;> simp [substAtoms,Eff.row,Eff.atoms,Eff.test]

inductive Prim where
 | mapFoldList | mapForEachList | setFoldList | setForEachList | length | get | lessInteger | greaterInteger | lessLength | prepend
 deriving DecidableEq
def Prim.context : Prim → TypeCtx
 | .mapFoldList => API.context .mapFold
 | .mapForEachList => API.context .mapForEach
 | .setFoldList => API.context .setFold
 | .setForEachList => API.context .setForEach
 | .length => API.context .checkLength
 | .get => API.context .checkIndex
 | .lessInteger => API.context .checkInteger
 | .greaterInteger => API.context .checkInteger
 | .lessLength => API.context .checkLength
 | .prepend => API.context .nonemptyToList
def Prim.source : Prim → PrimSig
 | .mapFoldList => StandardCollections.MapAPI.signature builtins.sat .toList
 | .mapForEachList => StandardCollections.MapAPI.signature builtins.sat .toList
 | .setFoldList => StandardCollections.SetAPI.signature builtins.sat .toList
 | .setForEachList => StandardCollections.SetAPI.signature builtins.sat .toList
 | .length => StandardListResponse.API.signature .length
 | .get => StandardOrdinaryListBodies.getSignature
 | .lessInteger => StandardOrderResponse.signature .integer64
 | .greaterInteger => StandardOrderResponse.signature .integer64
 | .lessLength => StandardOrderResponse.signature .integer64
 | .prepend => StandardListResponse.API.signature .prepend
def Prim.name : Prim → String
 | .mapFoldList => "Map.toList"
 | .mapForEachList => "Map.toList"
 | .setFoldList => "Set.toList"
 | .setForEachList => "Set.toList"
 | .length => "List.length"
 | .get => "List.get"
 | .lessInteger => "%Integer.less"
 | .greaterInteger => "%Integer.greater"
 | .lessLength => "%Integer.less"
 | .prepend => "List.prepend"
def Prim.args : Prim → List Ty
 | .mapFoldList => [.tvar 0,.tvar 1]
 | .mapForEachList => [.tvar 0,.tvar 1]
 | .setFoldList => [.tvar 0]
 | .setForEachList => [.tvar 0]
 | .length => [.tvar 0]
 | .get => [.tvar 0]
 | .lessInteger => []
 | .greaterInteger => []
 | .lessLength => []
 | .prepend => [.tvar 0]
def Prim.names : Prim → List String
 | .mapFoldList => ["m"]
 | .mapForEachList => ["m"]
 | .setFoldList => ["s"]
 | .setForEachList => ["s"]
 | .length => ["xs"]
 | .get => ["xs","i"]
 | .lessInteger => ["left","right"]
 | .greaterInteger => ["left","right"]
 | .lessLength => ["left","right"]
 | .prepend => ["xs","x"]
def Prim.inputs : Prim → List Ty
 | .mapFoldList => [.map (.tvar 0) (.tvar 1)]
 | .mapForEachList => [.map (.tvar 0) (.tvar 1)]
 | .setFoldList => [.set (.tvar 0)]
 | .setForEachList => [.set (.tvar 0)]
 | .length => [.list (.tvar 0)]
 | .get => [.list (.tvar 0),int]
 | .lessInteger => [int,int]
 | .greaterInteger => [int,int]
 | .lessLength => [int,int]
 | .prepend => [.list (.tvar 0),.tvar 0]
def Prim.result : Prim → Ty
 | .mapFoldList => .list pair
 | .mapForEachList => .list pair
 | .setFoldList => .list (.tvar 0)
 | .setForEachList => .list (.tvar 0)
 | .length => int
 | .get => .data "Option" [.tvar 0]
 | .lessInteger => bool
 | .greaterInteger => bool
 | .lessLength => bool
 | .prepend => .list (.tvar 0)


inductive ConAt where
 | integerRecord | lengthRecord | indexRecord | neFrom | neMap | rangeInvalid | rangeOutside | lengthInvalid | lengthOutside | indexOutside | empty | integerOk | integerError | lengthOk | lengthError | indexOk | indexError | nonemptyOk | nonemptyError
 deriving DecidableEq
def ConAt.context : ConAt → TypeCtx
 | .integerRecord => API.context .checkInteger
 | .lengthRecord => API.context .checkLength
 | .indexRecord => API.context .checkIndex
 | .neFrom => API.context .nonemptyFromList
 | .neMap => API.context .nonemptyMap
 | .rangeInvalid => API.context .checkInteger
 | .rangeOutside => API.context .checkInteger
 | .lengthInvalid => API.context .checkLength
 | .lengthOutside => API.context .checkLength
 | .indexOutside => API.context .checkIndex
 | .empty => API.context .nonemptyFromList
 | .integerOk => API.context .checkInteger
 | .integerError => API.context .checkInteger
 | .lengthOk => API.context .checkLength
 | .lengthError => API.context .checkLength
 | .indexOk => API.context .checkIndex
 | .indexError => API.context .checkIndex
 | .nonemptyOk => API.context .nonemptyFromList
 | .nonemptyError => API.context .nonemptyFromList
def ConAt.name : ConAt → String
 | .integerRecord => Record.owner .checkedInteger
 | .lengthRecord => Record.owner .checkedLength
 | .indexRecord => Record.owner .checkedIndex
 | .neFrom => Record.owner .nonempty
 | .neMap => Record.owner .nonempty
 | .rangeInvalid => "Benitoite.Range.RangeError.InvalidBounds"
 | .rangeOutside => "Benitoite.Range.RangeError.OutOfRange"
 | .lengthInvalid => "Benitoite.Range.LengthError.InvalidBounds"
 | .lengthOutside => "Benitoite.Range.LengthError.OutOfRange"
 | .indexOutside => "Benitoite.Range.IndexError.OutOfBounds"
 | .empty => "Benitoite.NonEmptyList.EmptyListError.EmptyList"
 | .integerOk => "Benitoite.Result.Result.Ok"
 | .integerError => "Benitoite.Result.Result.Error"
 | .lengthOk => "Benitoite.Result.Result.Ok"
 | .lengthError => "Benitoite.Result.Result.Error"
 | .indexOk => "Benitoite.Result.Result.Ok"
 | .indexError => "Benitoite.Result.Result.Error"
 | .nonemptyOk => "Benitoite.Result.Result.Ok"
 | .nonemptyError => "Benitoite.Result.Result.Error"
def ConAt.owner : ConAt → String
 | .integerRecord => Record.owner .checkedInteger
 | .lengthRecord => Record.owner .checkedLength
 | .indexRecord => Record.owner .checkedIndex
 | .neFrom => Record.owner .nonempty
 | .neMap => Record.owner .nonempty
 | .rangeInvalid => "Benitoite.Range.RangeError"
 | .rangeOutside => "Benitoite.Range.RangeError"
 | .lengthInvalid => "Benitoite.Range.LengthError"
 | .lengthOutside => "Benitoite.Range.LengthError"
 | .indexOutside => "Benitoite.Range.IndexError"
 | .empty => StandardSafe.names.emptyListError
 | .integerOk => StandardSafe.names.result
 | .integerError => StandardSafe.names.result
 | .lengthOk => StandardSafe.names.result
 | .lengthError => StandardSafe.names.result
 | .indexOk => StandardSafe.names.result
 | .indexError => StandardSafe.names.result
 | .nonemptyOk => StandardSafe.names.result
 | .nonemptyError => StandardSafe.names.result
def ConAt.count : ConAt → Nat
 | .integerRecord => 0
 | .lengthRecord => 1
 | .indexRecord => 1
 | .neFrom => 1
 | .neMap => 1
 | .rangeInvalid => 0
 | .rangeOutside => 0
 | .lengthInvalid => 0
 | .lengthOutside => 0
 | .indexOutside => 0
 | .empty => 0
 | .integerOk => 2
 | .integerError => 2
 | .lengthOk => 2
 | .lengthError => 2
 | .indexOk => 2
 | .indexError => 2
 | .nonemptyOk => 2
 | .nonemptyError => 2
def ConAt.fields : ConAt → List Ty
 | .integerRecord => Record.fields .checkedInteger
 | .lengthRecord => Record.fields .checkedLength
 | .indexRecord => Record.fields .checkedIndex
 | .neFrom => Record.fields .nonempty
 | .neMap => Record.fields .nonempty
 | .rangeInvalid => [int,int]
 | .rangeOutside => [int,int,int]
 | .lengthInvalid => [int,int]
 | .lengthOutside => [int,int,int]
 | .indexOutside => [int,int]
 | .empty => []
 | .integerOk => [.tvar 0]
 | .integerError => [.tvar 1]
 | .lengthOk => [.tvar 0]
 | .lengthError => [.tvar 1]
 | .indexOk => [.tvar 0]
 | .indexError => [.tvar 1]
 | .nonemptyOk => [.tvar 0]
 | .nonemptyError => [.tvar 1]
def ConAt.args : ConAt → List Ty
 | .integerRecord => []
 | .lengthRecord => [.tvar 0]
 | .indexRecord => [.tvar 0]
 | .neFrom => [.tvar 0]
 | .neMap => [.tvar 1]
 | .rangeInvalid => []
 | .rangeOutside => []
 | .lengthInvalid => []
 | .lengthOutside => []
 | .indexOutside => []
 | .empty => []
 | .integerOk => [ci,.data "Benitoite.Range.RangeError" []]
 | .integerError => [ci,.data "Benitoite.Range.RangeError" []]
 | .lengthOk => [cl,.data "Benitoite.Range.LengthError" []]
 | .lengthError => [cl,.data "Benitoite.Range.LengthError" []]
 | .indexOk => [cx,.data "Benitoite.Range.IndexError" []]
 | .indexError => [cx,.data "Benitoite.Range.IndexError" []]
 | .nonemptyOk => [ne (.tvar 0),.data StandardSafe.names.emptyListError []]
 | .nonemptyError => [ne (.tvar 0),.data StandardSafe.names.emptyListError []]
def ConAt.inputs : ConAt → List Ty
 | .integerRecord => [int,int,int]
 | .lengthRecord => [int,int,int,.list (.tvar 0)]
 | .indexRecord => [.list (.tvar 0),int,.tvar 0]
 | .neFrom => [.tvar 0,.list (.tvar 0)]
 | .neMap => [.tvar 1,.list (.tvar 1)]
 | .rangeInvalid => [int,int]
 | .rangeOutside => [int,int,int]
 | .lengthInvalid => [int,int]
 | .lengthOutside => [int,int,int]
 | .indexOutside => [int,int]
 | .empty => []
 | .integerOk => [ci]
 | .integerError => [.data "Benitoite.Range.RangeError" []]
 | .lengthOk => [cl]
 | .lengthError => [.data "Benitoite.Range.LengthError" []]
 | .indexOk => [cx]
 | .indexError => [.data "Benitoite.Range.IndexError" []]
 | .nonemptyOk => [ne (.tvar 0)]
 | .nonemptyError => [.data StandardSafe.names.emptyListError []]
def ConAt.result : ConAt → Ty
 | .integerRecord => ci
 | .lengthRecord => cl
 | .indexRecord => cx
 | .neFrom => ne (.tvar 0)
 | .neMap => ne (.tvar 1)
 | .rangeInvalid => .data "Benitoite.Range.RangeError" []
 | .rangeOutside => .data "Benitoite.Range.RangeError" []
 | .lengthInvalid => .data "Benitoite.Range.LengthError" []
 | .lengthOutside => .data "Benitoite.Range.LengthError" []
 | .indexOutside => .data "Benitoite.Range.IndexError" []
 | .empty => .data StandardSafe.names.emptyListError []
 | .integerOk => StandardOrdinaryCoreProgram.result (ci) "Benitoite.Range.RangeError"
 | .integerError => StandardOrdinaryCoreProgram.result (ci) "Benitoite.Range.RangeError"
 | .lengthOk => StandardOrdinaryCoreProgram.result (cl) "Benitoite.Range.LengthError"
 | .lengthError => StandardOrdinaryCoreProgram.result (cl) "Benitoite.Range.LengthError"
 | .indexOk => StandardOrdinaryCoreProgram.result (cx) "Benitoite.Range.IndexError"
 | .indexError => StandardOrdinaryCoreProgram.result (cx) "Benitoite.Range.IndexError"
 | .nonemptyOk => StandardOrdinaryCoreProgram.result (ne (.tvar 0)) StandardSafe.names.emptyListError
 | .nonemptyError => StandardOrdinaryCoreProgram.result (ne (.tvar 0)) StandardSafe.names.emptyListError
def ConAt.declaration (c : ConAt) : ConDecl := ⟨c.owner,c.count,c.fields⟩

local macro "final_simp" : tactic => `(tactic|
 simp_all [FunctionNames.definition,ConAt.context,ConAt.name,ConAt.owner,ConAt.count,ConAt.fields,ConAt.args,ConAt.inputs,ConAt.result,ConAt.declaration,Prim.context,Prim.source,Prim.name,Prim.args,Prim.names,Prim.inputs,Prim.result,StandardCollections.MapAPI.signature,StandardCollections.MapAPI.names,StandardCollections.MapAPI.inputs,StandardCollections.MapAPI.result,StandardCollections.SetAPI.signature,StandardCollections.SetAPI.names,StandardCollections.SetAPI.inputs,StandardCollections.SetAPI.result,StandardListResponse.API.signature,StandardListResponse.API.names,StandardListResponse.API.inputs,StandardListResponse.API.result,StandardOrderResponse.signature,StandardOrderResponse.Kind.base,DataId.owner,DataId.count,Ref.context,Ref.source,Ref.name,Ref.args,Ref.names,Ref.inputs,Ref.result,Ref.effect,Ref.rows,API.context,API.effect,API.neffs,API.names,API.inputs,API.result,API.definition,keyParam,ci,cl,cx,ne,result,rangeResult,lengthResult,indexResult,nonemptyResult,pair,int,bool,unit,listMapDefinition,pairDefinition,Ty.subst,Ty.substAt,substTypeAt,empty_range,row_self,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,StandardOrdinaryListBodies.Op.count,StandardOrdinaryListBodies.Op.context,StandardOrdinaryListBodies.Op.args,StandardOrdinaryListBodies.Op.result,StandardOrdinaryListBodies.Op.callback,StandardOrdinaryListBodies.Op.label,StandardOrdinaryListBodies.Op.names,StandardOrdinaryListBodies.Op.inputs,StandardOrdinaryListBodies.Op.publicNames,StandardOrdinaryListBodies.Op.publicInputs,StandardOrdinaryListBodies.Op.tel,StandardOrdinaryListBodies.Op.publicTel,StandardOrdinaryListBodies.Op.definition,StandardOrdinaryListBodies.Op.publicDefinition,StandardOrdinaryListBodies.getSignature,StandardActualListBodies.additionSignature,Getter.record,Getter.position,Getter.result,Getter.field,Getter.name,Getter.pattern,Getter.alts,
  Getter.body,Getter.definition,Getter.publicBody,Getter.publicDefinition,
  Record.params,Record.arity,Record.type,Record.fields,Record.owner,StandardSafe.names,
  Def.tel,PrimSig.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
  TypeCtx.valueParam,TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,
  TypeAnnotations,RowAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
  Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
  NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.row,Eff.norm,Ordinary,Ty.core,
  Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
  Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,
  Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,Eff.rawBind,rowFails,
  substAtoms_nil,instAtoms_nil,Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
  RowTransport,NoFail,SatAll,Eff.test,Eff.atoms,Eff.fails,Eff.shiftV,Ty.shiftV,shiftVTys,Tel.shiftV,Ctx.extend,
  bindParams,localExtend,Pred.lift,liftMany])


private theorem ref_lookup (r : Ref) : program.defs r.name=some r.source := by
 cases r <;> simp [Ref.name,Ref.source,program,allDefinitions,definitions,API.all,API.name,
 StandardOrdinaryListBodies.definitions,StandardOrdinaryListBodies.Op.every,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,
 StandardOrdinaryCoreBodies.definitions,Getter.all,Getter.name,Getter.field,Getter.record,Getter.publicName,Record.owner,StandardSafe.names,supportDefinitions,List.lookup]
private theorem sat_empty : ∀ C a, builtins.sat C a {} := fun _ _ => rfl
private theorem ref_kinds {P : Program} (arity : ∀ d : DataId, P.DataArity d.owner d.count) (r : Ref) : TypeArgsKinded P r.context r.args (TypeCtx.kinds r.source.tparams) := by
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 cases r <;> refine ⟨rfl,?_⟩
 all_goals rintro (_|(_|i)) a k ha hk <;> final_simp <;> subst_vars <;> final_simp

/-- 元の通常署名を、各呼出し元の型引数でインスタンス化する。参照名は名前の写像の像で、参照先は
同じ写像で関数参照を写した元の定義である。 -/
theorem reference_of {P B ρ Γ Φ Q} (arity : ∀ d : DataId, P.DataArity d.owner d.count)
 (sat : ∀ C a, B.sat C a {}) (r : Ref)
 (lookup : P.defs (ρ r.name)=some (FunctionNames.definition ρ r.source)) :
 HasTypeVQ P B StoreTy.empty Q r.context Γ Φ
  (.fnRef (ρ r.name) r.args r.rows) (.fn r.names r.inputs r.result r.effect) := by
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 have selfrow := row_self
 simp only [Eff.row,Eff.atoms] at selfrow
 have kinds := ref_kinds arity r
 have hn : NamesWF r.source.names r.source.params := by cases r <;> final_simp
 have ad : Admissible B r.context Γ.length (TypeCtx.constraints r.source.tparams) r.source.neffs
  (Qsig r.source.params r.source.ret r.source.eff) Q r.args r.rows r.source.eff := by
  cases r <;> constructor
  all_goals first
   | (solve | constructor <;> final_simp)
   | (solve | final_simp)
   | (solve | final_simp; rintro (_|(_|i)) a p ha hp <;> final_simp)
 have inst : SignatureInstance P r.context Γ r.source.tel (TypeCtx.kinds r.source.tparams) r.args r.rows := by
  cases r <;> constructor
  all_goals first
   | (solve | constructor <;> final_simp)
   | (solve | final_simp)
   | (solve | exact kinds)
   | (solve | intro a ha; simp [Ref.args] at ha; rcases ha with rfl | rfl <;> constructor <;> final_simp)
   | (solve | intro a ha; cases List.mem_singleton.mp ha; constructor <;> final_simp)
   | (solve | intro e he; cases List.mem_singleton.mp he; constructor <;> final_simp)
 apply (HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Φ := Φ) lookup hn ad inst).convert
 · have fold := Ty.foldFn_toTel ⟨r.names,r.inputs,r.result,r.effect,by cases r <;> final_simp⟩
   cases r <;> final_simp
   all_goals simpa [Ref.names,Ref.inputs,Ref.result,Ref.effect,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row,Eff.empty,pair,ne] using fold
 · cases r <;> constructor <;> final_simp

private theorem prim_lookup (p : Prim) : builtins.sig p.name=some p.source := by cases p <;> rfl
private theorem prim_kinds {P : Program} (arity : ∀ d : DataId, P.DataArity d.owner d.count) (p : Prim) : TypeArgsKinded P p.context p.args (TypeCtx.kinds p.source.tparams) := by
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 cases p <;> refine ⟨rfl,?_⟩
 all_goals rintro (_|(_|i)) a k ha hk <;> final_simp <;> subst_vars <;> final_simp
/-- 元の通常署名の組込みを、各呼出し元の型引数でインスタンス化する。 -/
theorem primitive_of {P B Γ Φ Q} (arity : ∀ d : DataId, P.DataArity d.owner d.count)
 (p : Prim) (lookup : B.sig p.name=some p.source) :
 HasTypeVQ P B StoreTy.empty Q p.context Γ Φ
  (.prim p.name p.args [] []) (.fn p.names p.inputs p.result Eff.empty) := by
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 have sat0 : ∀ C a, builtins.sat C a {} := sat_empty
 have key1 : builtins.sat [TParam.keyC] (.tvar 0) TParam.keyC := by rfl
 have key2 : builtins.sat [TParam.keyC,{}] (.tvar 0) TParam.keyC := by rfl
 have key3 : builtins.sat [TParam.keyC,{},{}] (.tvar 0) TParam.keyC := by rfl
 have kinds := prim_kinds arity p
 have hn : NamesWF p.source.names p.source.params := by cases p <;> final_simp
 have range : B.RangeAdmissible p.name p.source [] := by cases p <;> final_simp
 have ad : PrimitiveAdmissible p.context Γ.length p.source Q p.args [] := by
  cases p <;> constructor
  all_goals first
   | (solve | constructor <;> final_simp)
   | (solve | final_simp)
   | (solve | final_simp; rintro (_|(_|i)) a c ha hc <;> final_simp <;> subst_vars <;> final_simp)
 have inst : SignatureInstance P p.context Γ (Tel.instR [] p.source.tel) (TypeCtx.kinds p.source.tparams) p.args [] := by
  cases p <;> constructor
  all_goals first
   | (solve | constructor <;> final_simp)
   | (solve | final_simp)
   | (solve | exact kinds)
   | (solve | intro a ha; simp [Prim.args] at ha; rcases ha with rfl | rfl <;> constructor <;> final_simp)
   | (solve | intro a ha; cases List.mem_singleton.mp ha; constructor <;> final_simp)
   | (solve | intro e he; cases he)
 apply (HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Φ := Φ) lookup range hn ad inst).convert
 · have fold := Ty.foldFn_toTel ⟨p.names,p.inputs,p.result,Eff.empty,by cases p <;> final_simp⟩
   cases p <;> final_simp
   all_goals simpa [Prim.names,Prim.inputs,Prim.result,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty,pair,int,bool] using fold
 · cases p <;> constructor <;> final_simp

private theorem con_kinds {P : Program} (arity : ∀ d : DataId, P.DataArity d.owner d.count) (c : ConAt) : TypeArgsKinded P c.context c.args (List.replicate c.count .value) := by
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 cases c <;> refine ⟨rfl,?_⟩
 all_goals rintro (_|(_|i)) a k ha hk <;> final_simp <;> subst_vars <;> final_simp

/-- 元の構成子の全欄を通常型で検査する。 -/
private theorem constructor_typed {P B Γ Φ Q vs} (arity : ∀ d : DataId, P.DataArity d.owner d.count)
 (cons : ∀ c : ConAt, P.cons c.name=some c.declaration) (c : ConAt)
 (values : HasTypeVsQ P B StoreTy.empty Q c.context Γ Φ vs c.inputs) :
 HasTypeVQ P B StoreTy.empty Q c.context Γ Φ (.con c.name c.args vs) c.result := by
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 have kinds := con_kinds arity c
 have lookup := cons c
 cases c
 all_goals apply HasTypeVQ.V_Con lookup rfl
 all_goals first
  | (solve | exact kinds)
  | (solve | final_simp)
  | (solve | intro a ha; simp [ConAt.fields] at ha; rcases ha with rfl | rfl | rfl | rfl <;> simp [Ty.WF])
  | (solve | intro a ha; simp [ConAt.fields] at ha; rcases ha with rfl | rfl | rfl <;> simp [Ty.WF])
  | (solve | intro a ha; simp [ConAt.fields] at ha; rcases ha with rfl | rfl <;> simp [Ty.WF])
  | (solve | intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF])
  | (solve | intro a ha; cases ha)
  | (solve | simpa [ConAt.fields,ConAt.args,ConAt.inputs,ConAt.declaration,Record.fields,int,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,rawBindTys,typeEnvAt,SubstEnv.up,Eff.rawBind,Ty.norm,Ty.normTys] using values)
  | (constructor <;> final_simp)

private theorem pure_effect {P B Ψ Q C Γ Φ R m a Δ} (ann : Ty.Annotation P C Γ a)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a Eff.empty Δ) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a (Eff.row 0) Δ := by
  apply HasTypeCQ.C_Sub typed .refl _ ann.wf ann.sorted ann.declared
  constructor
  · intro a h; simp [Eff.mem,Eff.empty,Eff.test,Eff.atoms] at h
  · intro t h; simp [Eff.memFail,Eff.empty,Eff.fails] at h

local macro "final_var" : tactic => `(tactic| (refine HasTypeVQ.V_Var rfl ?_; intro b t e; final_simp))
local macro "final_values" : tactic => `(tactic|
 (first
  | exact .nil
  | exact .cons (by final_var) .nil
  | exact .cons (by final_var) (.cons (by final_var) .nil)
  | exact .cons (by final_var) (.cons (by final_var) (.cons (by final_var) .nil))
  | exact .cons (by final_var) (.cons (by final_var) (.cons (by final_var) (.cons (by final_var) .nil)))))
local macro "final_pure" : tactic => `(tactic| apply pure_effect (by constructor <;> final_simp))
local macro "final_call" f:term : tactic => `(tactic| (apply HasTypeCQ.C_App ($f _ _); final_values))
local macro "return_constructed" outer:term "," inner:term : tactic => `(tactic|
 (apply HasTypeCQ.C_Return
  apply constructor_typed (arity := by assumption) (cons := by assumption) $outer
  refine .cons ?_ .nil
  apply constructor_typed (arity := by assumption) (cons := by assumption) $inner
  final_values))

private theorem option_declarations : StandardActualListBodies.ListOptionDeclarations program :=
 StandardOrdinaryListBodies.option_declarations rfl
private theorem option_alternatives {P : Program} (options : StandardActualListBodies.ListOptionDeclarations P) :
 AltsTy P [⟨.con "Option.None" [],[]⟩] (.data "Option" [.tvar 0]) [] ∧
 AltsTy P [⟨.con "Option.Some" [.var],[0]⟩] (.data "Option" [.tvar 0]) [.tvar 0] := by
 constructor
 · refine ⟨by simp,rfl,?_,?_⟩
   · intro alt h; cases Option.some.inj h; rfl
   · intro alt h; cases List.mem_singleton.mp h
     exact ⟨[],.P_Con options.none_decl rfl (by simp) .nil,by simp,rfl⟩
 · refine ⟨by simp,rfl,?_,?_⟩
   · intro alt h; cases Option.some.inj h; rfl
   · intro alt h; cases List.mem_singleton.mp h
     exact ⟨[.tvar 0],.P_Con options.some_decl rfl (by intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF]) (.cons .P_Var .nil),by simp,rfl⟩
private theorem option_exhaustive {P : Program} (options : StandardActualListBodies.ListOptionDeclarations P) (a : Ty) : Exhaustive P (.data "Option" [a]) [.con "Option.None" [],.con "Option.Some" [.var]] := by
 intro v inhabitant
 change Inhabits P (.data "Option" [a.norm]) v at inhabitant
 have aux : ∀ t v, Inhabits P t v → t=.data "Option" [a.norm] →
  ∃ p ∈ [Pat.con "Option.None" [],.con "Option.Some" [.var]], (matchVal p v).isSome := by
  intro t v h eq
  cases h <;> try (solve | cases eq)
  case const c => cases c <;> cases eq
  case atError => simp [atErrorType] at eq
  case con c ts tys args cd lookup ntys wf fields =>
   rcases options.only c cd lookup (Ty.data.inj eq).1 with hc | hc
   · subst c; cases Option.some.inj (lookup.symm.trans options.none_decl); cases fields
     exact ⟨.con "Option.None" [],by simp,by simp [matchVal,matchList]⟩
   · subst c; cases Option.some.inj (lookup.symm.trans options.some_decl)
     cases fields with
     | cons v fields =>
      cases fields
      exact ⟨.con "Option.Some" [.var],by simp,by simp [matchVal,matchList]⟩
 exact aux _ _ inhabitant rfl
private theorem list_alternatives {P : Program} :
 AltsTy P [⟨.list [] none [],[]⟩] (.list (.tvar 0)) [] ∧
 AltsTy P [⟨.list [.var] (some .bind) [],[0,1]⟩] (.list (.tvar 0)) [.tvar 0,.list (.tvar 0)] := by
 constructor
 · refine ⟨by simp,rfl,?_,?_⟩
   · intro alt h; cases Option.some.inj h; rfl
   · intro alt h; cases List.mem_singleton.mp h
     exact ⟨[],.P_List .nil .nil (by intro _; rfl),by simp,rfl⟩
 · refine ⟨by simp,rfl,?_,?_⟩
   · intro alt h; cases Option.some.inj h; rfl
   · intro alt h; cases List.mem_singleton.mp h
     exact ⟨[.tvar 0,.list (.tvar 0)],.P_List (.cons .P_Var .nil) .nil (by intro h; cases h),List.Perm.refl _,rfl⟩
private theorem list_exhaustive {P : Program} : Exhaustive P (.list (.tvar 0)) [.list [] none [],.list [.var] (some .bind) []] := by
 intro v h
 obtain ⟨xs,rfl,_⟩ := h.list_inv _ rfl
 cases xs with
 | nil => exact ⟨.list [] none [],by simp,by simp [matchVal,matchList]⟩
 | cons x xs => exact ⟨.list [.var] (some .bind) [],by simp,by simp [matchVal,matchList]⟩

/-- 本体が読むデータ宣言・構成子・Option、組込みと関数参照の型。関数参照の名前は写像ρの像である。 -/
structure Context (P : Program) (B : Builtins) (ρ : String → String) : Prop where
 arity : ∀ d : DataId, P.DataArity d.owner d.count
 cons : ∀ c : ConAt, P.cons c.name=some c.declaration
 options : StandardActualListBodies.ListOptionDeclarations P
 prim : ∀ Q Γ Φ (p : Prim), HasTypeVQ P B StoreTy.empty Q p.context Γ Φ
  (.prim p.name p.args [] []) (.fn p.names p.inputs p.result Eff.empty)
 ref : ∀ Q Γ Φ (r : Ref), HasTypeVQ P B StoreTy.empty Q r.context Γ Φ
  (.fnRef (ρ r.name) r.args r.rows) (.fn r.names r.inputs r.result r.effect)

/-- 全十本の関数参照を写像ρで写した本体は、同じ宣言・組込み・参照の型を持つ任意のP/Bで、元の
通常署名の型付けの規則で検査できる。 -/
theorem body_typed_of {P B ρ} (ctx : Context P B ρ) (a : API) :
 (FunctionNames.definition ρ a.definition).WellTyped P B := by
 have arity := ctx.arity
 have cons := ctx.cons
 have ar_option : ∃ n, P.DataArity (DataId.owner .option) n ∧ 1=n := ⟨_,arity .option,rfl⟩
 have ak_option := TyCon.arity_data (arity .option)
 have ar_pair : ∃ n, P.DataArity (DataId.owner .pair) n ∧ 2=n := ⟨_,arity .pair,rfl⟩
 have ak_pair := TyCon.arity_data (arity .pair)
 have ar_result : ∃ n, P.DataArity (DataId.owner .result) n ∧ 2=n := ⟨_,arity .result,rfl⟩
 have ak_result := TyCon.arity_data (arity .result)
 have ar_ci : ∃ n, P.DataArity (DataId.owner .ci) n ∧ 0=n := ⟨_,arity .ci,rfl⟩
 have ak_ci := TyCon.arity_data (arity .ci)
 have ar_cl : ∃ n, P.DataArity (DataId.owner .cl) n ∧ 1=n := ⟨_,arity .cl,rfl⟩
 have ak_cl := TyCon.arity_data (arity .cl)
 have ar_cx : ∃ n, P.DataArity (DataId.owner .cx) n ∧ 1=n := ⟨_,arity .cx,rfl⟩
 have ak_cx := TyCon.arity_data (arity .cx)
 have ar_ne : ∃ n, P.DataArity (DataId.owner .ne) n ∧ 1=n := ⟨_,arity .ne,rfl⟩
 have ak_ne := TyCon.arity_data (arity .ne)
 have ar_rangeError : ∃ n, P.DataArity (DataId.owner .rangeError) n ∧ 0=n := ⟨_,arity .rangeError,rfl⟩
 have ak_rangeError := TyCon.arity_data (arity .rangeError)
 have ar_lengthError : ∃ n, P.DataArity (DataId.owner .lengthError) n ∧ 0=n := ⟨_,arity .lengthError,rfl⟩
 have ak_lengthError := TyCon.arity_data (arity .lengthError)
 have ar_indexError : ∃ n, P.DataArity (DataId.owner .indexError) n ∧ 0=n := ⟨_,arity .indexError,rfl⟩
 have ak_indexError := TyCon.arity_data (arity .indexError)
 have ar_emptyError : ∃ n, P.DataArity (DataId.owner .emptyError) n ∧ 0=n := ⟨_,arity .emptyError,rfl⟩
 have ak_emptyError := TyCon.arity_data (arity .emptyError)
 have prim := fun Γ Φ p => ctx.prim (QTel a.definition.tel) Γ Φ p
 have ref := fun Γ Φ r => ctx.ref (QTel a.definition.tel) Γ Φ r
 cases a
 case mapFold =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,mapFoldCallback,mapEachCallback,projection]
    apply HasTypeCQ.C_Let (a := .list pair)
    · final_pure; final_call (fun Γ Φ => prim Γ Φ .mapFoldList)
    · apply HasTypeCQ.C_App (ref _ _ .foldMap)
      refine .cons (by final_var) (.cons (by final_var) (.cons ?_ .nil))
      apply HasTypeVQ.V_Lam
      · simp [NamesWF]
      · final_simp
      · final_simp
      · apply HasTypeCQ.C_Let (a := .tvar 0)
        · final_pure; final_call (fun Γ Φ => ref Γ Φ .pairFirstFold)
        · apply HasTypeCQ.C_Let (a := .tvar 1)
          · final_pure; final_call (fun Γ Φ => ref Γ Φ .pairSecondFold)
          · apply HasTypeCQ.C_App
            · final_var
            · final_values
          · final_simp
        · final_simp
      · final_simp
    · final_simp
 case mapForEach =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,mapFoldCallback,mapEachCallback,projection]
    apply HasTypeCQ.C_Let (a := .list pair)
    · final_pure; final_call (fun Γ Φ => prim Γ Φ .mapForEachList)
    · apply HasTypeCQ.C_App (ref _ _ .eachMap)
      refine .cons (by final_var) (.cons ?_ .nil)
      apply HasTypeVQ.V_Lam
      · simp [NamesWF]
      · final_simp
      · final_simp
      · apply HasTypeCQ.C_Let (a := .tvar 0)
        · final_pure; final_call (fun Γ Φ => ref Γ Φ .pairFirstEach)
        · apply HasTypeCQ.C_Let (a := .tvar 1)
          · final_pure; final_call (fun Γ Φ => ref Γ Φ .pairSecondEach)
          · apply HasTypeCQ.C_App
            · final_var
            · final_values
          · final_simp
        · final_simp
      · final_simp
    · final_simp
 case setFold =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,mapFoldCallback,mapEachCallback,projection]
    apply HasTypeCQ.C_Let (a := .list (.tvar 0))
    · final_pure; final_call (fun Γ Φ => prim Γ Φ .setFoldList)
    · apply HasTypeCQ.C_App (ref _ _ .foldSet)
      final_values
    · final_simp
 case setForEach =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,mapFoldCallback,mapEachCallback,projection]
    apply HasTypeCQ.C_Let (a := .list (.tvar 0))
    · final_pure; final_call (fun Γ Φ => prim Γ Φ .setForEachList)
    · apply HasTypeCQ.C_App (ref _ _ .eachSet)
      final_values
    · final_simp
 case checkInteger =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,greater,less,app2,integerOutside]
    apply HasTypeCQ.C_Let (a := bool)
    · final_call (fun Γ Φ => prim Γ Φ .greaterInteger)
    · apply HasTypeCQ.C_If
      · final_var
      · rfl
      · return_constructed .integerError , .rangeInvalid
      · apply HasTypeCQ.C_Let (a := bool)
        · apply HasTypeCQ.C_Let (a := bool)
          · final_call (fun Γ Φ => prim Γ Φ .lessInteger)
          · apply HasTypeCQ.C_If
            · final_var
            · rfl
            · exact .C_Return (.V_Const trivial)
            · final_call (fun Γ Φ => prim Γ Φ .greaterInteger)
          · final_simp
        · apply HasTypeCQ.C_If
          · final_var
          · rfl
          · return_constructed .integerError , .rangeOutside
          · return_constructed .integerOk , .integerRecord
        · final_simp
    · final_simp
 case checkLength =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,invalidLength,lengthOutside,listLength,less,app2]
    apply HasTypeCQ.C_Let (a := .base .unit)
    · apply HasTypeCQ.C_Let (a := bool)
      · apply HasTypeCQ.C_Let (a := bool)
        · apply HasTypeCQ.C_App (prim _ _ .lessLength)
          exact .cons (by final_var) (.cons (.V_Const trivial) .nil)
        · apply HasTypeCQ.C_If
          · final_var
          · rfl
          · exact .C_Return (.V_Const trivial)
          · final_call (fun Γ Φ => prim Γ Φ .lessLength)
        · final_simp
      · apply HasTypeCQ.C_If
        · final_var
        · rfl
        · apply HasTypeCQ.C_Escape
          · apply constructor_typed arity cons .lengthError
            refine .cons ?_ .nil
            apply constructor_typed arity cons .lengthInvalid
            final_values
          · constructor <;> final_simp
        · exact .C_Return (.V_Const trivial)
      · final_simp
    · apply HasTypeCQ.C_Let (a := int)
      · final_call (fun Γ Φ => prim Γ Φ .length)
      · apply HasTypeCQ.C_Let (a := bool)
        · apply HasTypeCQ.C_Let (a := bool)
          · final_call (fun Γ Φ => prim Γ Φ .lessLength)
          · apply HasTypeCQ.C_If
            · final_var
            · rfl
            · exact .C_Return (.V_Const trivial)
            · final_call (fun Γ Φ => prim Γ Φ .lessLength)
          · final_simp
        · apply HasTypeCQ.C_If
          · final_var
          · rfl
          · return_constructed .lengthError , .lengthOutside
          · return_constructed .lengthOk , .lengthRecord
        · final_simp
      · final_simp
    · final_simp
 case checkIndex =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,listLength]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · final_call (fun Γ Φ => prim Γ Φ .get)
    · apply HasTypeCQ.C_Match (obs := none)
      · final_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty (option_alternatives ctx.options).1 (by simp [pathFacts,FactsWF])
        · apply HasTypeCQ.C_Let (a := int)
          · final_call (fun Γ Φ => prim Γ Φ .length)
          · return_constructed .indexError , .indexOutside
          · final_simp
        · apply HasTypeArmsQ.plainEmpty (option_alternatives ctx.options).2 (by simp [pathFacts,FactsWF])
          · return_constructed .indexOk , .indexRecord
          · apply HasTypeArmsQ.nil; constructor <;> final_simp
      · exact option_exhaustive ctx.options (.tvar 0)
    · final_simp
 case nonemptyFromList =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body]
    apply HasTypeCQ.C_Match (obs := none)
    · final_var
    · intro t h; cases h
    · apply HasTypeArmsQ.plainEmpty list_alternatives.1 (by simp [pathFacts,FactsWF])
      · return_constructed .nonemptyError , .empty
      · apply HasTypeArmsQ.plainEmpty list_alternatives.2 (by simp [pathFacts,FactsWF])
        · return_constructed .nonemptyOk , .neFrom
        · apply HasTypeArmsQ.nil; constructor <;> final_simp
    · exact list_exhaustive
 case nonemptyToList =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,neProjection]
    apply HasTypeCQ.C_Let (a := .list (.tvar 0))
    · final_call (fun Γ Φ => ref Γ Φ .neRestList)
    · apply HasTypeCQ.C_Let (a := .tvar 0)
      · final_call (fun Γ Φ => ref Γ Φ .neFirstList)
      · final_call (fun Γ Φ => prim Γ Φ .prepend)
      · final_simp
    · final_simp
 case nonemptyMap =>
  refine ⟨by final_simp,by final_simp,?_,?_⟩
  · constructor <;> final_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [FunctionNames.definition,FunctionNames.computation,FunctionNames.value,FunctionNames.values,FunctionNames.arms,API.definition,API.body,neProjection]
    apply HasTypeCQ.C_Let (a := .tvar 0)
    · final_pure; final_call (fun Γ Φ => ref Γ Φ .neFirstMap)
    · apply HasTypeCQ.C_Let (a := .tvar 1)
      · apply HasTypeCQ.C_App
        · final_var
        · final_values
      · apply HasTypeCQ.C_Let (a := .list (.tvar 0))
        · final_pure; final_call (fun Γ Φ => ref Γ Φ .neRestMap)
        · apply HasTypeCQ.C_Let (a := .list (.tvar 1))
          · final_call (fun Γ Φ => ref Γ Φ .listMap)
          · final_pure; apply HasTypeCQ.C_Return
            apply constructor_typed arity cons .neMap
            final_values
          · final_simp
        · final_simp
      · final_simp
    · final_simp

private theorem ref_identity (r : Ref) : FunctionNames.definition id r.source = r.source := by
 cases r <;> rfl
private theorem api_identity (a : API) : FunctionNames.definition id a.definition = a.definition := by
 cases a <;> rfl

/-- 有限表の元の通常署名を、各呼出し元の型引数でインスタンス化する。 -/
private theorem reference {Γ Φ Q} (r : Ref) :
 HasTypeVQ program builtins StoreTy.empty Q r.context Γ Φ
  (.fnRef r.name r.args r.rows) (.fn r.names r.inputs r.result r.effect) :=
 reference_of (ρ := id) data_arity sat_empty r (by rw [ref_identity]; exact ref_lookup r)

private theorem primitive {Γ Φ Q} (p : Prim) :
 HasTypeVQ program builtins StoreTy.empty Q p.context Γ Φ
  (.prim p.name p.args [] []) (.fn p.names p.inputs p.result Eff.empty) :=
 primitive_of data_arity p (prim_lookup p)

private theorem context : Context program builtins id :=
 ⟨data_arity, (fun c => by cases c <;> rfl), option_declarations, fun _ _ _ p => primitive p,
  fun _ _ _ r => reference r⟩

/-- 全十本は元の通常署名と実本体を固定の型付け規則で検査する。 -/
theorem body_typed (a : API) : a.definition.WellTyped program builtins := by
 have typed := body_typed_of context a
 rwa [api_identity] at typed

private theorem pair_only {c cd} (h : program.cons c=some cd) (owner : cd.data="Pair") : c="Pair.Pair" := by
 have mem := cons_mem h
 simp [constructorTable,declarations,StandardKeyTyping.DataDecl.entries,List.mem_cons,List.not_mem_nil,Prod.mk.injEq] at mem
 rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
 all_goals simp_all [Record.owner,StandardSafe.names]
private def pairPattern (second : Bool) : Pat := .con "Pair.Pair" [if second then .wild else .var,if second then .var else .wild]
private def pairAlts (second : Bool) : List Alt := [⟨pairPattern second,[0]⟩]
private theorem pair_alts {P : Program} (decl : P.cons "Pair.Pair"=some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩) (second : Bool) :
 AltsTy P (pairAlts second) pair [.tvar (if second then 1 else 0)] := by
 cases second <;> refine ⟨by simp [pairAlts],rfl,?_,?_⟩
 all_goals first
  | (solve | intro alt h; cases Option.some.inj h; rfl)
  | (intro alt h; cases List.mem_singleton.mp h
     refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
     · intro a ha; simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
       rcases ha with rfl | rfl <;> simp [Ty.WF]
     · first | exact .cons .P_Var (.cons .P_Wild .nil) | exact .cons .P_Wild (.cons .P_Var .nil))
private theorem pair_exhaustive {P : Program} (decl : P.cons "Pair.Pair"=some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
 (only : ∀ c cd, P.cons c=some cd → cd.data="Pair" → c="Pair.Pair") (second : Bool) :
 Exhaustive P pair [pairPattern second] := by
 intro v inhabitant
 have aux : ∀ t v, Inhabits P t v → t=pair.norm → (matchVal (pairPattern second) v).isSome := by
  intro t v h eq
  cases h <;> try (solve | cases eq)
  case const c => cases c <;> cases eq
  case atError => simp [pair,atErrorType,Ty.norm,Ty.normTys] at eq
  case con c ts tys args cd lookup ntys wf fields =>
   have hc := only c cd lookup (Ty.data.inj eq).1
   subst c
   cases Option.some.inj (lookup.symm.trans decl)
   cases fields with
   | cons x fields =>
    cases fields with
    | cons y fields =>
     cases fields
     cases second <;> rfl
 exact ⟨pairPattern second,by simp,aux _ _ inhabitant rfl⟩
/-- Pairの二射影は、Pairの一つの構成子とarityを持つ任意のP・任意のBで型付く。 -/
theorem pair_typed_of {P B} (decl : P.cons "Pair.Pair"=some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
 (only : ∀ c cd, P.cons c=some cd → cd.data="Pair" → c="Pair.Pair") (arity : P.DataArity "Pair" 2)
 (second : Bool) : (pairDefinition second).WellTyped P B := by
 have ar : ∃ n, P.DataArity "Pair" n ∧ 2=n := ⟨2,arity,rfl⟩
 have ak := TyCon.arity_data arity
 cases second <;> refine ⟨?_,?_,?_,TelBodyTy.param (TelBodyTy.done ?_)⟩
 all_goals first
  | (solve | final_simp)
  | (solve | constructor <;> final_simp)
  | (apply HasTypeCQ.C_Match (obs := none)
     · final_var
     · intro t h; cases h
     · apply HasTypeArmsQ.plainEmpty (pair_alts decl _) (by simp [pathFacts,FactsWF])
       · exact .C_Return (by final_var)
       · apply HasTypeArmsQ.nil; constructor <;> final_simp
     · exact pair_exhaustive decl only _)
private theorem pair_typed (second : Bool) : (pairDefinition second).WellTyped program builtins :=
 pair_typed_of rfl (fun _ _ h owner => pair_only h owner) (data_arity .pair) second

private theorem getter_lookup (g : Getter) : program.defs g.name=some g.definition := by
 cases g <;> simp [program,allDefinitions,definitions,API.all,API.name,
 StandardOrdinaryListBodies.definitions,StandardOrdinaryListBodies.Op.every,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,
 StandardOrdinaryCoreBodies.definitions,Getter.all,Getter.name,Getter.field,Getter.record,Getter.publicName,Record.owner,StandardSafe.names,supportDefinitions,List.lookup]
private theorem projection_lookup (g : Getter) : program.defs g.publicName=some g.publicDefinition := by
 cases g <;> simp [program,allDefinitions,definitions,API.all,API.name,
 StandardOrdinaryListBodies.definitions,StandardOrdinaryListBodies.Op.every,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,
 StandardOrdinaryCoreBodies.definitions,Getter.all,Getter.name,Getter.field,Getter.record,Getter.publicName,Record.owner,StandardSafe.names,supportDefinitions,List.lookup]
private theorem list_inputs : StandardOrdinaryListBodies.Inputs program builtins := by
 refine ⟨StandardOrdinaryListBodies.option_declarations rfl,rfl,rfl,?_,sat_empty⟩
 intro o
 cases o <;> simp [program,allDefinitions,definitions,API.all,API.name,
 StandardOrdinaryListBodies.definitions,StandardOrdinaryListBodies.Op.every,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,List.lookup]
private theorem list_public_lookup (o : StandardOrdinaryListBodies.Op) : program.defs o.name=some o.publicDefinition := by
 cases o <;> simp [program,allDefinitions,definitions,API.all,API.name,
 StandardOrdinaryListBodies.definitions,StandardOrdinaryListBodies.Op.every,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,List.lookup]
private theorem api_lookup (a : API) : program.defs a.name=some a.definition := by
 cases a <;> simp [program,allDefinitions,definitions,API.all,API.name,List.lookup]
private theorem support_lookup :
 program.defs "List.mapFrom"=some listMapFromDefinition ∧ program.defs "List.map"=some listMapDefinition := by
 constructor <;> simp [program,allDefinitions,definitions,API.all,API.name,
 StandardOrdinaryListBodies.definitions,StandardOrdinaryListBodies.Op.every,StandardOrdinaryListBodies.Op.name,StandardOrdinaryListBodies.Op.helperName,
 StandardOrdinaryCoreBodies.definitions,Getter.all,Getter.name,Getter.field,Getter.record,Getter.publicName,Record.owner,StandardSafe.names,supportDefinitions,List.lookup]

/-- List.mapと非公開helperも、収集した同じP/Bの実宣言に接続する。 -/
theorem list_map_bodies : listMapFromDefinition.WellTyped program builtins ∧ listMapDefinition.WellTyped program builtins := by
 have hFrom := StandardActualListBodies.from_typed (P := program) (B := builtins) false option_declarations rfl rfl rfl support_lookup.1 (by intro i hi; rfl)
 have hMap := StandardActualListBodies.higher_typed (P := program) (B := builtins) false support_lookup.1 (by intro i hi; rfl)
 constructor
 · obtain ⟨d,hd,typed⟩ := hFrom
   have eq : d=listMapFromDefinition := Option.some.inj (hd.symm.trans rfl)
   simpa [eq] using typed
 · obtain ⟨d,hd,typed⟩ := hMap
   have eq : d=listMapDefinition := Option.some.inj (hd.symm.trans rfl)
   simpa [eq] using typed

/-- 全lookupの実本体を同じ有限P/Bの通常型付けに接続する。 -/
theorem all_lookup_typed {f d} (lookup : program.defs f=some d) : d.WellTyped program builtins := by
 obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
 have mem : (f,d) ∈ allDefinitions := by rw [eq]; exact List.mem_append_right _ (List.mem_cons_self ..)
 simp only [allDefinitions,List.mem_append] at mem
 rcases mem with ((mem | mem) | mem) | mem
 · obtain ⟨a,_,same⟩ := List.mem_map.mp mem
   cases same
   exact body_typed a
 · obtain ⟨o,_,mem⟩ := List.mem_flatMap.mp mem
   simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   · exact StandardOrdinaryListBodies.public_typed list_inputs o
   · exact StandardOrdinaryListBodies.helper_typed list_inputs o
 · obtain ⟨g,_,mem⟩ := List.mem_flatMap.mp mem
   simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   · exact StandardOrdinaryCoreBodies.getter_typed rfl builtins g
   · exact StandardOrdinaryCoreBodies.projection_typed rfl sat_empty g (getter_lookup g)
 · simp only [supportDefinitions,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
   rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
   · exact pair_typed false
   · exact pair_typed true
   · exact list_map_bodies.2
   · exact list_map_bodies.1

inductive PublicAPI where
 | projection (getter : Getter)
 | list (op : StandardOrdinaryListBodies.Op)
 | core (api : API)
def PublicAPI.name : PublicAPI → String
 | .projection g => g.publicName | .list o => o.name | .core a => a.name
def PublicAPI.definition : PublicAPI → Def
 | .projection g => g.publicDefinition | .list o => o.publicDefinition | .core a => a.definition
def PublicAPI.all : List PublicAPI := Getter.all.map .projection ++ StandardOrdinaryListBodies.Op.every.map .list ++ API.all.map .core

/-- 二十七の元の公開署名・本体・lookupを、同じP/Bの全定義へ接続する。 -/
theorem declarations_typed (a : PublicAPI) :
 program.defs a.name=some a.definition ∧ a.definition.WellTyped program builtins := by
 have lookup : program.defs a.name=some a.definition := by
  cases a with
  | projection g => exact projection_lookup g
  | list o => exact list_public_lookup o
  | core a => exact api_lookup a
 exact ⟨lookup,all_lookup_typed lookup⟩

example : PublicAPI.all.length=27 := by decide
example : allDefinitions.length=48 := by decide
example (a : PublicAPI) : a.definition.WellTyped program builtins := (declarations_typed a).2
example {f d} (lookup : program.defs f=some d) : d.WellTyped program builtins := all_lookup_typed lookup

end
end Benitoite.Release.Refinement.StandardOrdinaryCoreProgram
