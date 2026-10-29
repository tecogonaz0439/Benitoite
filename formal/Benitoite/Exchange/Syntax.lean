import Lean
import Benitoite.Surface.Desugar
import Benitoite.Exchange.Range

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
namespace Benitoite.Exchange
open Lean

inductive TyCon where
  | data (name : String)
  | list | set | map | reference | lazyT
  deriving BEq, ToJson, FromJson, Repr

mutual
  inductive Atom where
    /-- 名前の原子と範囲の位置（corpus 15・sidecar 7。旧版は明示の Top で読む。`Exchange/Range.lean`）。 -/
    | name (value : String) (ix : Scope.Signature.Ix)
    | rho (index : Nat)
    | fail (error : Ty)
  inductive Ty where
    | base (name : String)
    /-- 不透明型と範囲の位置（corpus 15・sidecar 7。旧版は明示の Top で読む）。 -/
    | opaque (name : String) (ix : Scope.Signature.Ix)
    | data (name : String) (args : List Ty)
    | list (elem : Ty)
    | fn (names : List String) (params : List Ty) (ret : Ty) (eff : List Atom)
    | tvar (index : Nat)
    | reference (elem : Ty)
    | lazyT (elem : Ty)
    | map (key value : Ty)
    | set (elem : Ty)
    | bytes
    | dict (cls : String) (arg : Ty)
    | tapp (index : Nat) (args : List Ty)
    | ctor (head : TyCon)


end
deriving instance BEq, Repr for Atom, Ty
abbrev Eff := List Atom

mutual
  partial def encodeAtom : Atom → Json
    | .name n ix => Json.mkObj [("name", encodeNameBody n ix)]
    | .rho i => Json.mkObj [("rho", Json.mkObj [("index", toJson i)])]
    | .fail t => Json.mkObj [("kind", toJson "fail"), ("error", encodeTy t)]
  partial def encodeTy : Ty → Json
    | .base x0 => Json.mkObj [("base", Json.mkObj [("name", toJson x0)])]
    | .opaque x0 ix => Json.mkObj [("opaque", encodeOpaqueBody x0 ix)]
    | .data x0 x1 => Json.mkObj [("data", Json.mkObj [("name", toJson x0), ("args", Json.arr (x1.map encodeTy).toArray)])]
    | .list x0 => Json.mkObj [("list", Json.mkObj [("elem", encodeTy x0)])]
    | .fn x0 x1 x2 x3 => Json.mkObj [("fn", Json.mkObj [("names", toJson x0), ("params", Json.arr (x1.map encodeTy).toArray), ("ret", encodeTy x2), ("eff", Json.arr (x3.map encodeAtom).toArray)])]
    | .tvar x0 => Json.mkObj [("tvar", Json.mkObj [("index", toJson x0)])]
    | .reference x0 => Json.mkObj [("reference", Json.mkObj [("elem", encodeTy x0)])]
    | .lazyT x0 => Json.mkObj [("lazyT", Json.mkObj [("elem", encodeTy x0)])]
    | .map x0 x1 => Json.mkObj [("map", Json.mkObj [("key", encodeTy x0), ("value", encodeTy x1)])]
    | .set x0 => Json.mkObj [("set", Json.mkObj [("elem", encodeTy x0)])]
    | .bytes => toJson "bytes"
    | .dict x0 x1 => Json.mkObj [("dict", Json.mkObj [("cls", toJson x0), ("arg", encodeTy x1)])]
    | .tapp x0 x1 => Json.mkObj [("tapp", Json.mkObj [("index", toJson x0), ("args", Json.arr (x1.map encodeTy).toArray)])]
    | .ctor x0 => Json.mkObj [("ctor", Json.mkObj [("head", toJson x0)])]
end
mutual
  partial def decodeAtom (j : Json) : Except String Atom := do
    if let .ok k := j.getObjVal? "kind" then
      if k != toJson "fail" || (← j.getObj?).toArray.size != 2 then throw "invalid Fail atom"
      return .fail (← decodeTy (← j.getObjVal? "error"))
    if let .ok o := j.getObjVal? "name" then
      let (l, ix) ← decodeNameBody o
      -- 新版の必須の欄を補わず、余りの欄を読み捨てない。
      if encodeNameBody l ix != o then throw "unexpected effect atom fields"
      return .name l ix
    if let .ok o := j.getObjVal? "rho" then return .rho (← o.getObjValAs? Nat "index")
    throw "unknown effect atom"
  partial def decodeTy (j : Json) : Except String Ty := do
    if let .ok o := j.getObjVal? "base" then return .base (← fromJson? (← o.getObjVal? "name"))
    if let .ok o := j.getObjVal? "opaque" then
      let (n, ix) ← decodeOpaqueBody o
      if encodeOpaqueBody n ix != o then throw "unexpected opaque type fields"
      return .opaque n ix
    if let .ok o := j.getObjVal? "data" then return .data (← fromJson? (← o.getObjVal? "name")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeTy)
    if let .ok o := j.getObjVal? "list" then return .list (← decodeTy (← o.getObjVal? "elem"))
    if let .ok o := j.getObjVal? "fn" then return .fn (← fromJson? (← o.getObjVal? "names")) (← (← (← o.getObjVal? "params").getArr?).toList.mapM decodeTy) (← decodeTy (← o.getObjVal? "ret")) (← (← (← o.getObjVal? "eff").getArr?).toList.mapM decodeAtom)
    if let .ok o := j.getObjVal? "tvar" then return .tvar (← fromJson? (← o.getObjVal? "index"))
    if let .ok o := j.getObjVal? "reference" then return .reference (← decodeTy (← o.getObjVal? "elem"))
    if let .ok o := j.getObjVal? "lazyT" then return .lazyT (← decodeTy (← o.getObjVal? "elem"))
    if let .ok o := j.getObjVal? "map" then return .map (← decodeTy (← o.getObjVal? "key")) (← decodeTy (← o.getObjVal? "value"))
    if let .ok o := j.getObjVal? "set" then return .set (← decodeTy (← o.getObjVal? "elem"))
    if j == toJson "bytes" then return .bytes
    if let .ok o := j.getObjVal? "dict" then return .dict (← fromJson? (← o.getObjVal? "cls")) (← decodeTy (← o.getObjVal? "arg"))
    if let .ok o := j.getObjVal? "tapp" then return .tapp (← fromJson? (← o.getObjVal? "index")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeTy)
    if let .ok o := j.getObjVal? "ctor" then return .ctor (← fromJson? (← o.getObjVal? "head"))
    throw "unknown type constructor"
end
instance : ToJson Atom := ⟨encodeAtom⟩
instance : FromJson Atom := ⟨decodeAtom⟩
instance : ToJson Ty := ⟨encodeTy⟩
instance : FromJson Ty := ⟨decodeTy⟩

inductive Const where
  | integer (value : Int)
  | decimal (mantissa : Int) (scale : Nat)
  | float (bits : UInt64)
  | string (value : String)
  | character (value : Nat)
  | boolean (value : Bool)
  | unit
  | byte (value : Nat)
  | integer8 (value : Int)
  | integer16 (value : Int)
  | integer32 (value : Int)
  | unsignedInteger16 (value : Int)
  | unsignedInteger32 (value : Int)
  | unsignedInteger64 (value : Int)
  /-- JSON の数を丸めずに読み、変換時に 32 bit に収まるか検査する。 -/
  | float32 (bits : Nat)
  deriving BEq, ToJson, FromJson, Repr

inductive ListRest where
  | skip | bind
  deriving BEq, ToJson, FromJson, Repr

inductive Pattern where
  | wild
  | var
  | const (value : Const)
  | con (name : String) (args : List Pattern)
  | record (name : String) (n : Nat) (positions : List Nat) (args : List Pattern)
  | range (lo hi : Const)
  | list (before : List Pattern) (rest : Option ListRest) (after : List Pattern)
  | unsupported (name : String)
  deriving BEq, ToJson, FromJson, Repr

structure Alternative where
  pat : Pattern
  slots : List Nat
  deriving BEq, ToJson, FromJson, Repr

inductive OpRef where
  | user (name : String)
  | prim (name : String)
  | fail
  deriving BEq, ToJson, FromJson, Repr

inductive DictEv where
  | impl (name : String) (tys : List Ty) (args : List DictEv)
  | local (index : Nat)
  | clause (outer arity dictCount constraint depth : Nat)
  | super (dict : DictEv) (cls : String)
  deriving ToJson, FromJson, Repr

/-- 書式の七指定を省略も含めて交換する。幅と精度は必須のnullable欄である。 -/
structure FormatSpec where
  kind : String
  align : String
  sign : String
  alternate : Bool
  zero : Bool
  width : Option Nat
  precision : Option Nat
  deriving ToJson, FromJson, Repr

inductive InterpPart where
  | text (value : String)
  | stringExpr
  | converted (ty : Ty)
  | formatted (ty : Ty) (spec : FormatSpec)
  deriving ToJson, Repr

/-- 新構成の欠落・余剰欄は、指定の省略として読み替えない。 -/
instance : FromJson InterpPart := ⟨fun j => do
  if let .ok o := j.getObjVal? "formatted" then
    if (← j.getObj?).toArray.size != 1 || (← o.getObj?).toArray.size != 2 then
      throw "invalid formatted interpolation fields"
    let raw ← o.getObjVal? "spec"
    let keys := ["kind", "align", "sign", "alternate", "zero", "width", "precision"]
    let obj ← raw.getObj?
    if obj.toArray.size != keys.length then throw "invalid format spec fields"
    for k in keys do
      if !obj.contains k then throw s!"missing format spec field: {k}"
    return .formatted (← o.getObjValAs? Ty "ty") (← fromJson? raw)
  if let .ok o := j.getObjVal? "text" then return .text (← o.getObjValAs? String "value")
  if j == toJson "stringExpr" then return .stringExpr
  if let .ok o := j.getObjVal? "converted" then return .converted (← o.getObjValAs? Ty "ty")
  throw "unknown interpolation part"⟩

/-- corpus 13 の専用分類。通常の Ty へ混ぜない。 -/
inductive BuilderKind where
  | string | list (element : Ty) | bytes
  deriving ToJson, FromJson, Repr, BEq

inductive BuilderOp where
  | append | appendAll | copy | length
  deriving ToJson, FromJson, Repr, BEq

mutual
  inductive Expr where
    | builderOp (op : BuilderOp) (index : Nat) (args : List Expr) (kind : BuilderKind)
    | local (index : Nat)
    | constName (name : String)
    | funName (name : String) (tys : List Ty) (effs : List Eff)
    | funDicts (name : String) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (names : List String) (params : List Ty) (eff : Eff)
    | methName (dict : DictEv) (name : String) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (names : List String) (params : List Ty) (eff : Eff)
    /-- 型検査器が選んだ範囲の列を持つ（corpus 15。旧版は空の列で読む）。 -/
    | primName (name : String) (tys : List Ty) (effs : List Eff) (ranges : List Scope.Domain.Range)
    | opName (name : String) (tys : List Ty)
    | opDicts (name : String) (tys : List Ty) (dicts : List DictEv) (names : List String) (params : List Ty) (eff : Eff)
    | raise (result error : Ty)
    | handleFail (error result : Ty) (body clause : Block)
    | nullCon (name : String) (tys : List Ty)
    | conValue (name : String) (tys : List Ty) (names : List String) (params : List Ty)
    | literal (value : Const)
    /-- 型検査が記録した符号反転後の Float のビット。 -/
    | negFloat (bits : UInt64)
    | negDecimal (mantissa : Int) (scale : Nat)
    | negInteger8 (magnitude : Nat)
    | negInteger16 (magnitude : Nat)
    | negInteger32 (magnitude : Nat)
    /-- 旧 Float と同じく、型検査が記録した符号反転後のビット列。 -/
    | negFloat32 (bits : Nat)
    | unit
    | paren (inner : Expr)
    | block (body : Block)
    | record (name : String) (tys : List Ty) (positions : List Nat) (args : List Expr)
    | recordUpdate (name : String) (tys : List Ty) (n : Nat) (positions : List Nat) (base : Expr) (args : List Expr)
    | conCall (name : String) (tys : List Ty) (args : List Expr)
    | call (callee : Expr) (labels : List (Option String)) (positions : List Nat) (args : List Expr)
    | pipe (lhs rhs : Expr)
    | partialCall (callee : Expr) (names : List String) (args : List HoleArg) (ret : Ty) (eff : Eff)
    | partialCon (name : String) (tys : List Ty) (args : List HoleArg)
    | binary (op : String) (operand : Ty) (lhs rhs : Expr)
    | neg (operand : Ty) (inner : Expr)
    | not (inner : Expr)
    | and (lhs rhs : Expr)
    | or (lhs rhs : Expr)
    | list (elem : Ty) (elems : List Expr)
    | listSpread (elem : Ty) (concat : Expr) (before : List Expr) (spread : Expr) (after : List Expr)
    | interpolation (parts : List InterpPart) (es converters : List Expr)
    | lam (names : List String) (params : List Ty) (ret : Ty) (eff : Eff) (body : Block)
    | ite (cond : Expr) (yes no : Block)
    | elseIf (cond : Expr) (yes : Block) (no : Expr)
    | ifOnly (cond : Expr) (yes : Block)
    | matchE (ret : Ty) (scrutinee : Expr) (arms : List Arm)
    | returnE (ret : Ty) (inner : Expr)
    | tryResult (retArgs : List Ty) (ok err : String) (inner : Expr)
    | tryOption (retArgs : List Ty) (someCon noneCon : String) (inner : Expr)
    /-- corpus 10: 処置をタグで保持し、裸の try と区別する。 -/
    | tryResultReturn (retArgs : List Ty) (ok err : String) (inner : Expr)
    | tryOptionReturn (retArgs : List Ty) (someCon noneCon : String) (inner : Expr)
    | tryResultDie (ty : Ty) (ok err : String) (dict : DictEv)
        (showMethod exit : String) (inner : Expr) (message : Option Expr)
    | tryOptionDie (ty : Ty) (someCon noneCon exit : String)
        (inner : Expr) (message : Option Expr)
    | withE (o : String) (bound : Expr) (body : Block)
    | lazyE (body : Block)
    | handleE (body : Block) (clauses : List SurfaceClause)
    | resume (index : Nat) (inner : Expr)
  inductive SurfaceClause where
    | mk (op : OpRef) (arity ntys : Nat) (body : Block) (dictCount : Nat) (failureType : Option Ty)
  inductive HoleArg where
    | expr (label : Option String) (position : Nat) (inner : Expr)
    | hole (label : Option String) (position : Nat) (ty : Ty)
  inductive Arm where
    | mk (alts : List Alternative) (guard : Option Expr) (body : Block)
  inductive Block where
    | builderBind (kind : BuilderKind) (rest : Block)
    | empty
    | last (expr : Expr)
    | lastBind (shadow : Bool) (ty : Ty) (expr : Expr)
    | lastDiscard (expr : Expr)
    | bind (shadow : Bool) (ty : Ty) (expr : Expr) (rest : Block)
    | discard (expr : Expr) (rest : Block)
    | seq (expr : Expr) (rest : Block)
    | lastPat (shadow : Bool) (pattern : Pattern) (ty : Ty) (expr : Expr)
    | bindPat (shadow : Bool) (pattern : Pattern) (ty : Ty) (expr : Expr) (rest : Block)
end

mutual
  partial def encodeExpr : Expr → Json
    | .builderOp op index args kind => Json.mkObj [("builderOp", Json.mkObj [("op", toJson op), ("index", toJson index), ("args", Json.arr (args.map encodeExpr).toArray), ("kind", toJson kind)])]
    | .constName name => Json.mkObj [("constName", Json.mkObj [("name", toJson name)])]
    | .funDicts name tys effs dicts names params eff => Json.mkObj [("funDicts", Json.mkObj [("names", toJson names), ("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("dicts", toJson dicts), ("params", toJson params), ("eff", toJson eff)])]
    | .methName dict name tys effs dicts names params eff => Json.mkObj [("methName", Json.mkObj [("names", toJson names), ("dict", toJson dict), ("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("dicts", toJson dicts), ("params", toJson params), ("eff", toJson eff)])]
    | .local index => Json.mkObj [("local", Json.mkObj [("index", toJson index)])]
    | .funName name tys effs => Json.mkObj [("funName", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs)])]
    | .primName name tys effs ranges => Json.mkObj [("primName", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("ranges", encodeRanges ranges)])]
    | .nullCon name tys => Json.mkObj [("nullCon", Json.mkObj [("name", toJson name), ("tys", toJson tys)])]
    | .conValue name tys names params => Json.mkObj [("conValue", Json.mkObj [("names", toJson names), ("name", toJson name), ("tys", toJson tys), ("params", toJson params)])]
    | .literal value => Json.mkObj [("literal", Json.mkObj [("value", toJson value)])]
    | .negFloat bits => Json.mkObj [("negFloat", Json.mkObj [("bits", toJson bits)])]
    | .negDecimal mantissa scale => Json.mkObj [("negDecimal", Json.mkObj [("mantissa", toJson mantissa), ("scale", toJson scale)])]
    | .negInteger8 magnitude => Json.mkObj [("negInteger8", Json.mkObj [("magnitude", toJson magnitude)])]
    | .negInteger16 magnitude => Json.mkObj [("negInteger16", Json.mkObj [("magnitude", toJson magnitude)])]
    | .negInteger32 magnitude => Json.mkObj [("negInteger32", Json.mkObj [("magnitude", toJson magnitude)])]
    | .negFloat32 bits => Json.mkObj [("negFloat32", Json.mkObj [("bits", toJson bits)])]
    | .listSpread elem concat before spread after => Json.mkObj [("listSpread", Json.mkObj [("elem", toJson elem), ("concat", encodeExpr concat), ("before", Json.arr (before.map encodeExpr).toArray), ("spread", encodeExpr spread), ("after", Json.arr (after.map encodeExpr).toArray)])]
    | .interpolation parts es converters => Json.mkObj [("interpolation", Json.mkObj [("parts", toJson parts), ("es", Json.arr (es.map encodeExpr).toArray), ("converters", Json.arr (converters.map encodeExpr).toArray)])]
    | .unit  => toJson "unit"
    | .block body => Json.mkObj [("block", Json.mkObj [("body", encodeBlock body)])]
    | .paren inner => Json.mkObj [("paren", Json.mkObj [("inner", encodeExpr inner)])]
    | .record name tys positions args => Json.mkObj [("record", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("positions", toJson positions), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .recordUpdate name tys n positions base args => Json.mkObj [("recordUpdate", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("n", toJson n), ("positions", toJson positions), ("base", encodeExpr base), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .conCall name tys args => Json.mkObj [("conCall", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .call callee labels positions args => Json.mkObj [("call", Json.mkObj [("labels", toJson labels), ("positions", toJson positions), ("callee", encodeExpr callee), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .pipe lhs rhs => Json.mkObj [("pipe", Json.mkObj [("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .partialCall callee names args ret eff => Json.mkObj [("partialCall", Json.mkObj [("names", toJson names), ("callee", encodeExpr callee), ("args", Json.arr (args.map encodeHoleArg).toArray), ("ret", toJson ret), ("eff", toJson eff)])]
    | .partialCon name tys args => Json.mkObj [("partialCon", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeHoleArg).toArray)])]
    | .binary op operand lhs rhs => Json.mkObj [("binary", Json.mkObj [("op", toJson op), ("operand", toJson operand), ("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .neg operand inner => Json.mkObj [("neg", Json.mkObj [("operand", toJson operand), ("inner", encodeExpr inner)])]
    | .not inner => Json.mkObj [("not", Json.mkObj [("inner", encodeExpr inner)])]
    | .and lhs rhs => Json.mkObj [("and", Json.mkObj [("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .or lhs rhs => Json.mkObj [("or", Json.mkObj [("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .list elem elems => Json.mkObj [("list", Json.mkObj [("elem", toJson elem), ("elems", Json.arr (elems.map encodeExpr).toArray)])]
    | .lam names params ret eff body => Json.mkObj [("lam", Json.mkObj [("names", toJson names), ("params", toJson params), ("ret", toJson ret), ("eff", toJson eff), ("body", encodeBlock body)])]
    | .ite cond yes no => Json.mkObj [("ite", Json.mkObj [("cond", encodeExpr cond), ("yes", encodeBlock yes), ("no", encodeBlock no)])]
    | .elseIf cond yes no => Json.mkObj [("elseIf", Json.mkObj [("cond", encodeExpr cond), ("yes", encodeBlock yes), ("no", encodeExpr no)])]
    | .ifOnly cond yes => Json.mkObj [("ifOnly", Json.mkObj [("cond", encodeExpr cond), ("yes", encodeBlock yes)])]
    | .matchE ret scrutinee arms => Json.mkObj [("matchE", Json.mkObj [("ret", toJson ret), ("scrutinee", encodeExpr scrutinee), ("arms", Json.arr (arms.map encodeArm).toArray)])]
    | .returnE ret inner => Json.mkObj [("returnE", Json.mkObj [("ret", toJson ret), ("inner", encodeExpr inner)])]
    | .tryResult retArgs ok err inner => Json.mkObj [("tryResult", Json.mkObj [("retArgs", toJson retArgs), ("ok", toJson ok), ("err", toJson err), ("inner", encodeExpr inner)])]
    | .tryOption retArgs someCon noneCon inner => Json.mkObj [("tryOption", Json.mkObj [("retArgs", toJson retArgs), ("someCon", toJson someCon), ("noneCon", toJson noneCon), ("inner", encodeExpr inner)])]
    | .tryResultReturn retArgs ok err inner => Json.mkObj [("tryResultReturn", Json.mkObj [("retArgs", toJson retArgs), ("ok", toJson ok), ("err", toJson err), ("inner", encodeExpr inner)])]
    | .tryOptionReturn retArgs someCon noneCon inner => Json.mkObj [("tryOptionReturn", Json.mkObj [("retArgs", toJson retArgs), ("someCon", toJson someCon), ("noneCon", toJson noneCon), ("inner", encodeExpr inner)])]
    | .tryResultDie ty ok err dict showMethod exit inner message => Json.mkObj [("tryResultDie", Json.mkObj [("ty", toJson ty), ("ok", toJson ok), ("err", toJson err), ("dict", toJson dict), ("showMethod", toJson showMethod), ("exit", toJson exit), ("inner", encodeExpr inner), ("message", (message.map encodeExpr).getD Json.null)])]
    | .tryOptionDie ty someCon noneCon exit inner message => Json.mkObj [("tryOptionDie", Json.mkObj [("ty", toJson ty), ("someCon", toJson someCon), ("noneCon", toJson noneCon), ("exit", toJson exit), ("inner", encodeExpr inner), ("message", (message.map encodeExpr).getD Json.null)])]
    | .withE o bound body => Json.mkObj [("withE", Json.mkObj [("o", toJson o), ("bound", encodeExpr bound), ("body", encodeBlock body)])]
    | .lazyE body => Json.mkObj [("lazyE", Json.mkObj [("body", encodeBlock body)])]
    | .opName name tys => Json.mkObj [("opName", Json.mkObj [("name", toJson name), ("tys", toJson tys)])]
    | .handleE body clauses => Json.mkObj [("handleE", Json.mkObj [("body", encodeBlock body), ("clauses", Json.arr (clauses.map encodeSurfaceClause).toArray)])]
    | .resume index inner => Json.mkObj [("resume", Json.mkObj [("index", toJson index), ("inner", encodeExpr inner)])]
    | .raise result error => Json.mkObj [("raise", Json.mkObj [("result", toJson result), ("error", toJson error)])]
    | .opDicts name tys dicts names params eff => Json.mkObj [("opDicts", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("dicts", toJson dicts), ("names", toJson names), ("params", toJson params), ("eff", toJson eff)])]
    | .handleFail error result body clause => Json.mkObj [("handleFail", Json.mkObj [("error", toJson error), ("result", toJson result), ("body", encodeBlock body), ("clause", encodeBlock clause)])]
  partial def encodeSurfaceClause : SurfaceClause → Json
    | .mk op arity ntys body dictCount failureType => Json.mkObj [("op", toJson op), ("arity", toJson arity), ("ntys", toJson ntys), ("dictCount", toJson dictCount), ("failureType", toJson failureType), ("body", encodeBlock body)]
  partial def encodeHoleArg : HoleArg → Json
    | .expr label position inner => Json.mkObj [("expr", Json.mkObj [("label", toJson label), ("position", toJson position), ("inner", encodeExpr inner)])]
    | .hole label position ty => Json.mkObj [("hole", Json.mkObj [("label", toJson label), ("position", toJson position), ("ty", toJson ty)])]
  partial def encodeArm : Arm → Json
    | .mk alts guard body => Json.mkObj [("mk", Json.mkObj [("alts", toJson alts), ("guard", guard.map encodeExpr |>.getD Json.null), ("body", encodeBlock body)])]
  partial def encodeBlock : Block → Json
    | .builderBind kind rest => Json.mkObj [("builderBind", Json.mkObj [("kind", toJson kind), ("rest", encodeBlock rest)])]
    | .empty  => toJson "empty"
    | .last expr => Json.mkObj [("last", Json.mkObj [("expr", encodeExpr expr)])]
    | .lastBind shadow ty expr => Json.mkObj [("lastBind", Json.mkObj [("shadow", toJson shadow), ("ty", toJson ty), ("expr", encodeExpr expr)])]
    | .lastDiscard expr => Json.mkObj [("lastDiscard", Json.mkObj [("expr", encodeExpr expr)])]
    | .bind shadow ty expr rest => Json.mkObj [("bind", Json.mkObj [("shadow", toJson shadow), ("ty", toJson ty), ("expr", encodeExpr expr), ("rest", encodeBlock rest)])]
    | .discard expr rest => Json.mkObj [("discard", Json.mkObj [("expr", encodeExpr expr), ("rest", encodeBlock rest)])]
    | .seq expr rest => Json.mkObj [("seq", Json.mkObj [("expr", encodeExpr expr), ("rest", encodeBlock rest)])]
    | .lastPat shadow pattern ty expr => Json.mkObj [("lastPat", Json.mkObj [("shadow", toJson shadow), ("pattern", toJson pattern), ("ty", toJson ty), ("expr", encodeExpr expr)])]
    | .bindPat shadow pattern ty expr rest => Json.mkObj [("bindPat", Json.mkObj [("shadow", toJson shadow), ("pattern", toJson pattern), ("ty", toJson ty), ("expr", encodeExpr expr), ("rest", encodeBlock rest)])]
end
/-- try の処置の情報を、別のタグの未知の欄として読み捨てない。 -/
def checkTryFields (j : Json) : Except String Unit := do
  for (tag, fields) in [
      ("tryResult", ["retArgs", "ok", "err", "inner"]),
      ("tryOption", ["retArgs", "someCon", "noneCon", "inner"]),
      ("tryResultReturn", ["retArgs", "ok", "err", "inner"]),
      ("tryOptionReturn", ["retArgs", "someCon", "noneCon", "inner"]),
      ("tryResultDie", ["ty", "ok", "err", "dict", "showMethod", "exit", "inner", "message"]),
      ("tryOptionDie", ["ty", "someCon", "noneCon", "exit", "inner", "message"])] do
    if let .ok payload := j.getObjVal? tag then
      let obj ← j.getObj?
      if obj.toArray.size != 1 then throw "ambiguous try action"
      let obj ← payload.getObj?
      for (key, _) in obj.toArray do
        if !fields.contains key then throw s!"unexpected {tag} field: {key}"

/-- 新しい式の情報を別のタグや余分な型引数の欄として読み捨てない。 -/
def checkBatch2ExprFields (j : Json) : Except String Unit := do
  for (tag, fields) in [("raise", ["result", "error"]),
      ("handleFail", ["error", "result", "body", "clause"]),
      ("opDicts", ["name", "tys", "dicts", "names", "params", "eff"])] do
    if let .ok payload := j.getObjVal? tag then
      if (← j.getObj?).toArray.size != 1 then throw "ambiguous batch2 expression"
      let obj ← payload.getObj?
      for (key, _) in obj.toArray do
        if !fields.contains key then throw s!"unexpected {tag} field: {key}"
      for key in fields do
        if !obj.contains key then throw s!"missing {tag} field: {key}"

/-- 新タグの曖昧な別名や未知の欄を、既存タグとして読み捨てない。 -/
def checkBuilderFields (j : Json) : Except String Unit := do
  for (tag, fields) in [("builderOp", ["op", "index", "args", "kind"]),
      ("builderBind", ["kind", "rest"])] do
    if let .ok payload := j.getObjVal? tag then
      if (← j.getObj?).toArray.size != 1 then throw "ambiguous builder syntax"
      let obj ← payload.getObj?
      for (key, _) in obj.toArray do
        if !fields.contains key then throw s!"unexpected {tag} field: {key}"
      for key in fields do
        if !obj.contains key then throw s!"missing {tag} field: {key}"
      let raw ← payload.getObjVal? "kind"
      let kind : BuilderKind ← fromJson? raw
      if toJson kind != raw then throw "unexpected builder kind fields"

mutual
  partial def decodeExpr (j : Json) : Except String Expr := do
    checkBuilderFields j
    if let .ok o := j.getObjVal? "builderOp" then
      return .builderOp (← o.getObjValAs? BuilderOp "op") (← o.getObjValAs? Nat "index") (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr) (← o.getObjValAs? BuilderKind "kind")
    checkTryFields j
    checkBatch2ExprFields j
    if let .ok o := j.getObjVal? "raise" then return .raise (← o.getObjValAs? Ty "result") (← o.getObjValAs? Ty "error")
    if let .ok o := j.getObjVal? "opDicts" then return .opDicts (← o.getObjValAs? String "name") (← o.getObjValAs? (List Ty) "tys") (← o.getObjValAs? (List DictEv) "dicts") (← o.getObjValAs? (List String) "names") (← o.getObjValAs? (List Ty) "params") (← o.getObjValAs? Eff "eff")
    if let .ok o := j.getObjVal? "handleFail" then return .handleFail (← o.getObjValAs? Ty "error") (← o.getObjValAs? Ty "result") (← decodeBlock (← o.getObjVal? "body")) (← decodeBlock (← o.getObjVal? "clause"))
    if let .ok o := j.getObjVal? "constName" then
      return .constName (← fromJson? (← o.getObjVal? "name"))
    if let .ok o := j.getObjVal? "funDicts" then
      return .funDicts (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← fromJson? (← o.getObjVal? "dicts")) (← fromJson? (← o.getObjVal? "names")) (← fromJson? (← o.getObjVal? "params")) (← fromJson? (← o.getObjVal? "eff"))
    if let .ok o := j.getObjVal? "methName" then
      return .methName (← fromJson? (← o.getObjVal? "dict")) (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← fromJson? (← o.getObjVal? "dicts")) (← fromJson? (← o.getObjVal? "names")) (← fromJson? (← o.getObjVal? "params")) (← fromJson? (← o.getObjVal? "eff"))
    if let .ok o := j.getObjVal? "local" then
      return .local (← fromJson? (← o.getObjVal? "index"))
    if let .ok o := j.getObjVal? "funName" then
      return .funName (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs"))
    if let .ok o := j.getObjVal? "primName" then
      return .primName (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← decodeRanges (← o.getObjVal? "ranges"))
    if let .ok o := j.getObjVal? "nullCon" then
      return .nullCon (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys"))
    if let .ok o := j.getObjVal? "conValue" then
      return .conValue (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "names")) (← fromJson? (← o.getObjVal? "params"))
    if let .ok o := j.getObjVal? "literal" then
      return .literal (← fromJson? (← o.getObjVal? "value"))
    if let .ok o := j.getObjVal? "negFloat" then
      return .negFloat (← fromJson? (← o.getObjVal? "bits"))
    if let .ok o := j.getObjVal? "negDecimal" then
      return .negDecimal (← fromJson? (← o.getObjVal? "mantissa")) (← fromJson? (← o.getObjVal? "scale"))
    if let .ok o := j.getObjVal? "negInteger8" then
      return .negInteger8 (← fromJson? (← o.getObjVal? "magnitude"))
    if let .ok o := j.getObjVal? "negInteger16" then
      return .negInteger16 (← fromJson? (← o.getObjVal? "magnitude"))
    if let .ok o := j.getObjVal? "negInteger32" then
      return .negInteger32 (← fromJson? (← o.getObjVal? "magnitude"))
    if let .ok o := j.getObjVal? "negFloat32" then
      return .negFloat32 (← fromJson? (← o.getObjVal? "bits"))
    if let .ok o := j.getObjVal? "listSpread" then
      return .listSpread (← fromJson? (← o.getObjVal? "elem")) (← decodeExpr (← o.getObjVal? "concat")) (← (← (← o.getObjVal? "before").getArr?).toList.mapM decodeExpr) (← decodeExpr (← o.getObjVal? "spread")) (← (← (← o.getObjVal? "after").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "interpolation" then
      return .interpolation (← fromJson? (← o.getObjVal? "parts")) (← (← (← o.getObjVal? "es").getArr?).toList.mapM decodeExpr) (← (← (← o.getObjVal? "converters").getArr?).toList.mapM decodeExpr)
    if j == toJson "unit" then return .unit
    if let .ok o := j.getObjVal? "block" then
      if (← j.getObj?).toArray.size != 1 || (← o.getObj?).toArray.size != 1 then
        throw "unexpected block fields"
      return .block (← decodeBlock (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "paren" then
      return .paren (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "record" then
      return .record (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "positions")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "recordUpdate" then
      return .recordUpdate (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "n")) (← fromJson? (← o.getObjVal? "positions")) (← decodeExpr (← o.getObjVal? "base")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "conCall" then
      return .conCall (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "call" then
      return .call (← decodeExpr (← o.getObjVal? "callee")) (← fromJson? (← o.getObjVal? "labels")) (← fromJson? (← o.getObjVal? "positions")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "pipe" then
      return .pipe (← decodeExpr (← o.getObjVal? "lhs")) (← decodeExpr (← o.getObjVal? "rhs"))
    if let .ok o := j.getObjVal? "partialCall" then
      return .partialCall (← decodeExpr (← o.getObjVal? "callee")) (← fromJson? (← o.getObjVal? "names")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeHoleArg) (← fromJson? (← o.getObjVal? "ret")) (← fromJson? (← o.getObjVal? "eff"))
    if let .ok o := j.getObjVal? "partialCon" then
      return .partialCon (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeHoleArg)
    if let .ok o := j.getObjVal? "binary" then
      return .binary (← fromJson? (← o.getObjVal? "op")) (← fromJson? (← o.getObjVal? "operand")) (← decodeExpr (← o.getObjVal? "lhs")) (← decodeExpr (← o.getObjVal? "rhs"))
    if let .ok o := j.getObjVal? "neg" then
      return .neg (← fromJson? (← o.getObjVal? "operand")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "not" then
      return .not (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "and" then
      return .and (← decodeExpr (← o.getObjVal? "lhs")) (← decodeExpr (← o.getObjVal? "rhs"))
    if let .ok o := j.getObjVal? "or" then
      return .or (← decodeExpr (← o.getObjVal? "lhs")) (← decodeExpr (← o.getObjVal? "rhs"))
    if let .ok o := j.getObjVal? "list" then
      return .list (← fromJson? (← o.getObjVal? "elem")) (← (← (← o.getObjVal? "elems").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "lam" then
      return .lam (← fromJson? (← o.getObjVal? "names")) (← fromJson? (← o.getObjVal? "params")) (← fromJson? (← o.getObjVal? "ret")) (← fromJson? (← o.getObjVal? "eff")) (← decodeBlock (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "ite" then
      return .ite (← decodeExpr (← o.getObjVal? "cond")) (← decodeBlock (← o.getObjVal? "yes")) (← decodeBlock (← o.getObjVal? "no"))
    if let .ok o := j.getObjVal? "elseIf" then
      return .elseIf (← decodeExpr (← o.getObjVal? "cond")) (← decodeBlock (← o.getObjVal? "yes")) (← decodeExpr (← o.getObjVal? "no"))
    if let .ok o := j.getObjVal? "ifOnly" then
      return .ifOnly (← decodeExpr (← o.getObjVal? "cond")) (← decodeBlock (← o.getObjVal? "yes"))
    if let .ok o := j.getObjVal? "matchE" then
      return .matchE (← fromJson? (← o.getObjVal? "ret")) (← decodeExpr (← o.getObjVal? "scrutinee")) (← (← (← o.getObjVal? "arms").getArr?).toList.mapM decodeArm)
    if let .ok o := j.getObjVal? "returnE" then
      return .returnE (← fromJson? (← o.getObjVal? "ret")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "tryResult" then
      return .tryResult (← fromJson? (← o.getObjVal? "retArgs")) (← fromJson? (← o.getObjVal? "ok")) (← fromJson? (← o.getObjVal? "err")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "tryOption" then
      return .tryOption (← fromJson? (← o.getObjVal? "retArgs")) (← fromJson? (← o.getObjVal? "someCon")) (← fromJson? (← o.getObjVal? "noneCon")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "tryResultReturn" then
      return .tryResultReturn (← fromJson? (← o.getObjVal? "retArgs")) (← fromJson? (← o.getObjVal? "ok")) (← fromJson? (← o.getObjVal? "err")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "tryOptionReturn" then
      return .tryOptionReturn (← fromJson? (← o.getObjVal? "retArgs")) (← fromJson? (← o.getObjVal? "someCon")) (← fromJson? (← o.getObjVal? "noneCon")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "tryResultDie" then
      let message ← o.getObjVal? "message"
      return .tryResultDie (← fromJson? (← o.getObjVal? "ty")) (← fromJson? (← o.getObjVal? "ok")) (← fromJson? (← o.getObjVal? "err")) (← fromJson? (← o.getObjVal? "dict")) (← fromJson? (← o.getObjVal? "showMethod")) (← fromJson? (← o.getObjVal? "exit")) (← decodeExpr (← o.getObjVal? "inner")) (← if message == Json.null then pure none else some <$> decodeExpr message)
    if let .ok o := j.getObjVal? "tryOptionDie" then
      let message ← o.getObjVal? "message"
      return .tryOptionDie (← fromJson? (← o.getObjVal? "ty")) (← fromJson? (← o.getObjVal? "someCon")) (← fromJson? (← o.getObjVal? "noneCon")) (← fromJson? (← o.getObjVal? "exit")) (← decodeExpr (← o.getObjVal? "inner")) (← if message == Json.null then pure none else some <$> decodeExpr message)
    if let .ok o := j.getObjVal? "withE" then
      return .withE (← fromJson? (← o.getObjVal? "o")) (← decodeExpr (← o.getObjVal? "bound")) (← decodeBlock (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "lazyE" then
      return .lazyE (← decodeBlock (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "opName" then
      return .opName (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys"))
    if let .ok o := j.getObjVal? "handleE" then
      return .handleE (← decodeBlock (← o.getObjVal? "body")) (← (← (← o.getObjVal? "clauses").getArr?).toList.mapM decodeSurfaceClause)
    if let .ok o := j.getObjVal? "resume" then
      return .resume (← fromJson? (← o.getObjVal? "index")) (← decodeExpr (← o.getObjVal? "inner"))
    throw "unknown Expr constructor"
  partial def decodeSurfaceClause (j : Json) : Except String SurfaceClause := do
    return .mk (← fromJson? (← j.getObjVal? "op")) (← fromJson? (← j.getObjVal? "arity")) (← fromJson? (← j.getObjVal? "ntys")) (← decodeBlock (← j.getObjVal? "body")) (← j.getObjValAs? Nat "dictCount") (← j.getObjValAs? (Option Ty) "failureType")
  partial def decodeHoleArg (j : Json) : Except String HoleArg := do
    if let .ok o := j.getObjVal? "expr" then
      return .expr (← fromJson? (← o.getObjVal? "label")) (← fromJson? (← o.getObjVal? "position")) (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "hole" then
      return .hole (← fromJson? (← o.getObjVal? "label")) (← fromJson? (← o.getObjVal? "position")) (← fromJson? (← o.getObjVal? "ty"))
    throw "unknown HoleArg constructor"
  partial def decodeArm (j : Json) : Except String Arm := do
    if let .ok o := j.getObjVal? "mk" then
      let g ← o.getObjVal? "guard"
      return .mk (← fromJson? (← o.getObjVal? "alts")) (← if g == Json.null then pure none else some <$> decodeExpr g) (← decodeBlock (← o.getObjVal? "body"))
    throw "unknown Arm constructor"
  partial def decodeBlock (j : Json) : Except String Block := do
    checkBuilderFields j
    if let .ok o := j.getObjVal? "builderBind" then
      return .builderBind (← o.getObjValAs? BuilderKind "kind") (← decodeBlock (← o.getObjVal? "rest"))
    if j == toJson "empty" then return .empty
    if let .ok o := j.getObjVal? "last" then
      return .last (← decodeExpr (← o.getObjVal? "expr"))
    if let .ok o := j.getObjVal? "lastBind" then
      return .lastBind (← fromJson? (← o.getObjVal? "shadow")) (← fromJson? (← o.getObjVal? "ty")) (← decodeExpr (← o.getObjVal? "expr"))
    if let .ok o := j.getObjVal? "lastDiscard" then
      return .lastDiscard (← decodeExpr (← o.getObjVal? "expr"))
    if let .ok o := j.getObjVal? "bind" then
      return .bind (← fromJson? (← o.getObjVal? "shadow")) (← fromJson? (← o.getObjVal? "ty")) (← decodeExpr (← o.getObjVal? "expr")) (← decodeBlock (← o.getObjVal? "rest"))
    if let .ok o := j.getObjVal? "discard" then
      return .discard (← decodeExpr (← o.getObjVal? "expr")) (← decodeBlock (← o.getObjVal? "rest"))
    if let .ok o := j.getObjVal? "seq" then
      return .seq (← decodeExpr (← o.getObjVal? "expr")) (← decodeBlock (← o.getObjVal? "rest"))
    if let .ok o := j.getObjVal? "lastPat" then
      return .lastPat (← fromJson? (← o.getObjVal? "shadow")) (← fromJson? (← o.getObjVal? "pattern")) (← fromJson? (← o.getObjVal? "ty")) (← decodeExpr (← o.getObjVal? "expr"))
    if let .ok o := j.getObjVal? "bindPat" then
      return .bindPat (← fromJson? (← o.getObjVal? "shadow")) (← fromJson? (← o.getObjVal? "pattern")) (← fromJson? (← o.getObjVal? "ty")) (← decodeExpr (← o.getObjVal? "expr")) (← decodeBlock (← o.getObjVal? "rest"))
    throw "unknown Block constructor"
end
instance : ToJson Expr := ⟨encodeExpr⟩
instance : FromJson Expr := ⟨decodeExpr⟩
instance : ToJson HoleArg := ⟨encodeHoleArg⟩
instance : FromJson HoleArg := ⟨decodeHoleArg⟩
instance : ToJson Arm := ⟨encodeArm⟩
instance : FromJson Arm := ⟨decodeArm⟩
instance : ToJson Block := ⟨encodeBlock⟩
instance : FromJson Block := ⟨decodeBlock⟩

/-- 専用場所は通常の値と区別する。 -/
inductive LocalRef where
  | bound (index : Nat)
  | loc (index : Nat)
  deriving ToJson, FromJson, Repr, BEq

/-- 専用コアでも、旧参照先や未知の欄を読み捨てない。 -/
def checkCoreBuilderFields (j : Json) : Except String Unit := do
  for (tag, fields) in [("builderOp", ["kind", "op", "ref", "args"]),
      ("builderLet", ["kind", "body"])] do
    if let .ok payload := j.getObjVal? tag then
      if (← j.getObj?).toArray.size != 1 then throw "ambiguous core builder syntax"
      let obj ← payload.getObj?
      for (key, _) in obj.toArray do
        if !fields.contains key then throw s!"unexpected {tag} field: {key}"
      for key in fields do
        if !obj.contains key then throw s!"missing {tag} field: {key}"
      let raw ← payload.getObjVal? "kind"
      let kind : BuilderKind ← fromJson? raw
      if toJson kind != raw then throw "unexpected builder kind fields"
      if tag == "builderOp" then
        let raw ← payload.getObjVal? "ref"
        let ref : LocalRef ← fromJson? raw
        if toJson ref != raw then throw "unexpected local reference fields"

mutual
  inductive Val where
    | var (index : Nat)
    | const (value : Const)
    | fnRef (name : String) (tys : List Ty) (effs : List Eff)
    /-- 具体化した範囲の列を持つ（corpus 15。旧版は空の列で読む）。 -/
    | prim (name : String) (tys : List Ty) (effs : List Eff) (ranges : List Scope.Domain.Range)
    | op (name : String) (tys : List Ty)
    | raise (result error : Ty)
    | lam (names : List String) (params : List Ty) (body : Comp)
    | con (name : String) (tys : List Ty) (args : List Val)
    | list (elems : List Val)
    | dict (name : String) (tys : List Ty) (args : List Val)
    | super (dict : Val) (cls : String)
    | unsupported (name : String)
  inductive Comp where
    | builderLet (kind : BuilderKind) (body : Comp)
    | builderOp (kind : BuilderKind) (op : BuilderOp) (ref : LocalRef) (args : List Val)
    | ret (value : Val)
    | letIn (bound body : Comp)
    | app (callee : Val) (args : List Val)
    | meth (dict : Val) (name : String) (tys : List Ty) (effs : List Eff) (args : List Val)
    | ite (cond : Val) (yes no : Comp)
    | matchC (scrutinee : Val) (arms : List CoreArm)
    | escape (value : Val)
    | use (resource : Val) (body : Comp)
    | lazyC (body : Comp)
    | handle (body : Comp) (clauses : List CoreClause)
    | resume (index : Nat) (value : Val)
    | unsupported (name : String)
  inductive CoreArm where
    | mk (alts : List Alternative) (guard : Option Comp) (body : Comp)
  inductive CoreClause where
    | mk (op : OpRef) (arity ntys : Nat) (body : Comp) (dictCount : Nat) (failureType : Option Ty)
end
deriving instance BEq for Val, Comp, CoreArm, CoreClause
mutual
  partial def encodeVal : Val → Json
    | .dict name tys args => Json.mkObj [("dict", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .super dict cls => Json.mkObj [("super", Json.mkObj [("dict", encodeVal dict), ("cls", toJson cls)])]
    | .var index => Json.mkObj [("var", Json.mkObj [("index", toJson index)])]
    | .const value => Json.mkObj [("const", Json.mkObj [("value", toJson value)])]
    | .fnRef name tys effs => Json.mkObj [("fnRef", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs)])]
    | .prim name tys effs ranges => Json.mkObj [("prim", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("ranges", encodeRanges ranges)])]
    | .lam names params body => Json.mkObj [("lam", Json.mkObj [("names", toJson names), ("params", toJson params), ("body", encodeComp body)])]
    | .con name tys args => Json.mkObj [("con", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .list elems => Json.mkObj [("list", Json.mkObj [("elems", Json.arr (elems.map encodeVal).toArray)])]
    | .unsupported name => Json.mkObj [("unsupported", Json.mkObj [("name", toJson name)])]
    | .op name tys => Json.mkObj [("op", Json.mkObj [("name", toJson name), ("tys", toJson tys)])]
    | .raise result error => Json.mkObj [("raise", Json.mkObj [("result", toJson result), ("error", toJson error)])]
  partial def encodeComp : Comp → Json
    | .builderLet kind body => Json.mkObj [("builderLet", Json.mkObj [("kind", toJson kind), ("body", encodeComp body)])]
    | .builderOp kind op ref args => Json.mkObj [("builderOp", Json.mkObj [("kind", toJson kind), ("op", toJson op), ("ref", toJson ref), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .meth dict name tys effs args => Json.mkObj [("meth", Json.mkObj [("dict", encodeVal dict), ("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .ret value => Json.mkObj [("ret", Json.mkObj [("value", encodeVal value)])]
    | .letIn bound body => Json.mkObj [("letIn", Json.mkObj [("bound", encodeComp bound), ("body", encodeComp body)])]
    | .app callee args => Json.mkObj [("app", Json.mkObj [("callee", encodeVal callee), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .ite cond yes no => Json.mkObj [("ite", Json.mkObj [("cond", encodeVal cond), ("yes", encodeComp yes), ("no", encodeComp no)])]
    | .matchC scrutinee arms => Json.mkObj [("matchC", Json.mkObj [("scrutinee", encodeVal scrutinee), ("arms", Json.arr (arms.map encodeCoreArm).toArray)])]
    | .use resource body => Json.mkObj [("use", Json.mkObj [("resource", encodeVal resource), ("body", encodeComp body)])]
    | .lazyC body => Json.mkObj [("lazyC", Json.mkObj [("body", encodeComp body)])]
    | .escape value => Json.mkObj [("escape", Json.mkObj [("value", encodeVal value)])]
    | .unsupported name => Json.mkObj [("unsupported", Json.mkObj [("name", toJson name)])]
    | .handle body clauses => Json.mkObj [("handle", Json.mkObj [("body", encodeComp body), ("clauses", Json.arr (clauses.map encodeCoreClause).toArray)])]
    | .resume index value => Json.mkObj [("resume", Json.mkObj [("index", toJson index), ("value", encodeVal value)])]
  partial def encodeCoreArm : CoreArm → Json
    | .mk alts guard body => Json.mkObj [("mk", Json.mkObj [("alts", toJson alts), ("guard", guard.map encodeComp |>.getD Json.null), ("body", encodeComp body)])]
  partial def encodeCoreClause : CoreClause → Json
    | .mk op arity ntys body dictCount failureType => Json.mkObj [("op", toJson op), ("arity", toJson arity), ("ntys", toJson ntys), ("dictCount", toJson dictCount), ("failureType", toJson failureType), ("body", encodeComp body)]
end
mutual
  partial def decodeVal (j : Json) : Except String Val := do
    checkBatch2ExprFields j
    if let .ok o := j.getObjVal? "raise" then return .raise (← o.getObjValAs? Ty "result") (← o.getObjValAs? Ty "error")
    if let .ok o := j.getObjVal? "dict" then
      return .dict (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeVal)
    if let .ok o := j.getObjVal? "super" then
      return .super (← decodeVal (← o.getObjVal? "dict")) (← fromJson? (← o.getObjVal? "cls"))
    if let .ok o := j.getObjVal? "var" then
      return .var (← fromJson? (← o.getObjVal? "index"))
    if let .ok o := j.getObjVal? "const" then
      return .const (← fromJson? (← o.getObjVal? "value"))
    if let .ok o := j.getObjVal? "fnRef" then
      return .fnRef (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs"))
    if let .ok o := j.getObjVal? "prim" then
      return .prim (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← decodeRanges (← o.getObjVal? "ranges"))
    if let .ok o := j.getObjVal? "lam" then
      return .lam (← fromJson? (← o.getObjVal? "names")) (← fromJson? (← o.getObjVal? "params")) (← decodeComp (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "con" then
      return .con (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeVal)
    if let .ok o := j.getObjVal? "list" then
      return .list (← (← (← o.getObjVal? "elems").getArr?).toList.mapM decodeVal)
    if let .ok o := j.getObjVal? "unsupported" then
      return .unsupported (← fromJson? (← o.getObjVal? "name"))
    if let .ok o := j.getObjVal? "op" then
      return .op (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys"))
    throw "unknown Val constructor"
  partial def decodeComp (j : Json) : Except String Comp := do
    checkCoreBuilderFields j
    if let .ok o := j.getObjVal? "builderLet" then
      return .builderLet (← o.getObjValAs? BuilderKind "kind") (← decodeComp (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "builderOp" then
      return .builderOp (← o.getObjValAs? BuilderKind "kind") (← o.getObjValAs? BuilderOp "op")
        (← o.getObjValAs? LocalRef "ref") (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeVal)
    if let .ok o := j.getObjVal? "meth" then
      return .meth (← decodeVal (← o.getObjVal? "dict")) (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeVal)
    if let .ok o := j.getObjVal? "ret" then
      return .ret (← decodeVal (← o.getObjVal? "value"))
    if let .ok o := j.getObjVal? "letIn" then
      return .letIn (← decodeComp (← o.getObjVal? "bound")) (← decodeComp (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "app" then
      return .app (← decodeVal (← o.getObjVal? "callee")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeVal)
    if let .ok o := j.getObjVal? "ite" then
      return .ite (← decodeVal (← o.getObjVal? "cond")) (← decodeComp (← o.getObjVal? "yes")) (← decodeComp (← o.getObjVal? "no"))
    if let .ok o := j.getObjVal? "matchC" then
      return .matchC (← decodeVal (← o.getObjVal? "scrutinee")) (← (← (← o.getObjVal? "arms").getArr?).toList.mapM decodeCoreArm)
    if let .ok o := j.getObjVal? "escape" then
      return .escape (← decodeVal (← o.getObjVal? "value"))
    if let .ok o := j.getObjVal? "unsupported" then
      return .unsupported (← fromJson? (← o.getObjVal? "name"))
    if let .ok o := j.getObjVal? "use" then
      return .use (← decodeVal (← o.getObjVal? "resource")) (← decodeComp (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "lazyC" then
      return .lazyC (← decodeComp (← o.getObjVal? "body"))
    if let .ok o := j.getObjVal? "handle" then
      return .handle (← decodeComp (← o.getObjVal? "body")) (← (← (← o.getObjVal? "clauses").getArr?).toList.mapM decodeCoreClause)
    if let .ok o := j.getObjVal? "resume" then
      return .resume (← fromJson? (← o.getObjVal? "index")) (← decodeVal (← o.getObjVal? "value"))
    throw "unknown Comp constructor"
  partial def decodeCoreArm (j : Json) : Except String CoreArm := do
    let o ← j.getObjVal? "mk"
    let g ← o.getObjVal? "guard"
    return .mk (← fromJson? (← o.getObjVal? "alts")) (← if g == Json.null then pure none else some <$> decodeComp g) (← decodeComp (← o.getObjVal? "body"))
  partial def decodeCoreClause (j : Json) : Except String CoreClause := do
    return .mk (← fromJson? (← j.getObjVal? "op")) (← fromJson? (← j.getObjVal? "arity")) (← fromJson? (← j.getObjVal? "ntys")) (← decodeComp (← j.getObjVal? "body")) (← j.getObjValAs? Nat "dictCount") (← j.getObjValAs? (Option Ty) "failureType")
end
instance : ToJson Val := ⟨encodeVal⟩
instance : FromJson Val := ⟨decodeVal⟩
instance : ToJson Comp := ⟨encodeComp⟩
instance : FromJson Comp := ⟨decodeComp⟩

/-- 宣言順の行パラメータ。NoFail はシグネチャから再計算して照合する。 -/
structure EffParam where
  noFail : Bool
  deriving BEq, ToJson, FromJson

structure Header where
  tparams : List (Bool × Bool)
  neffs : Nat
  effParams : List EffParam
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  deriving BEq, ToJson, FromJson

structure SurfaceDef where
  package : String
  coverageView : List String
  header : Header
  body : Block
  dictParams : List (String × Nat)
  implementation : Option String
  method : Option String
  supers : List (String × DictEv)
  deriving ToJson, FromJson
structure CoreDef where
  header : Header
  body : Comp
  lambdaEffects : List Eff
  supers : List (String × Val)
  deriving BEq, ToJson, FromJson
/-- 取得関数には表層の本体がない。構成子の宣言から Program が生成する。 -/
structure RecordConDecl where
  fields : List String
  data : String
  ntys : Nat
  args : List Ty
  deriving BEq, ToJson, FromJson
inductive Scope where
  | inScope (surface : SurfaceDef) (core : CoreDef)
  | accessor (name con : String) (k : Nat) (decl : RecordConDecl) (core : CoreDef)
  | outOfScope (elements : List String)
  deriving ToJson, FromJson
structure Definition where
  name : String
  scope : Scope
  deriving ToJson, FromJson
structure OpEntry where
  dictParams : List (String × Nat)
  effectKind : String
  name : String
  eff : String
  header : Header
  deriving ToJson, FromJson
structure EffectEntry where
  name : String
  ops : List String
  deriving ToJson, FromJson
/-- 組み込みの操作は利用者の表に含めず、節の束縛数の検査に必要な部分だけ持つ。 -/
structure PrimOpEntry where
  effectKind : String
  names : List String
  name : String
  arity : Nat
  ntys : Nat
  deriving ToJson, FromJson
structure MethodEntry where
  name : String
  header : Header
  deriving ToJson, FromJson
structure ClassEntry where
  name : String
  supers : List String
  methods : List MethodEntry
  deriving ToJson, FromJson
structure ImplEntry where
  name : String
  tparams : List (Bool × Bool)
  dictParams : List (String × Nat)
  cls : String
  target : Ty
  deriving ToJson, FromJson
/-- 同じ名前の参照には、同じ注釈型と閉じた本体を使う。 -/
structure ConstantEntry where
  package : String
  name : String
  ty : Ty
  body : Expr
  deriving ToJson, FromJson
/-- 表示名とは独立した、標準ライブラリの既知の型の識別。 -/
inductive BuiltinData where
  | ordinary | result | option
  deriving BEq, ToJson, FromJson
/-- 宣言の属性と、照合元で有効な view を分けて交換する。 -/
structure DataTypeInfo where
  builtin : BuiltinData
  package : String
  name : String
  typeName : String
  isRecord : Bool
  extensible : Bool
  deriving BEq, ToJson, FromJson

structure Input where
  dataTypes : List DataTypeInfo
  group : String
  name : String
  excluded : List String
  definitions : List Definition
  constants : List ConstantEntry
  ops : List OpEntry
  effects : List EffectEntry
  primOps : List PrimOpEntry
  classes : List ClassEntry
  impls : List ImplEntry
  /-- 必須の判定の入力（corpus 15。`Exchange/Observe.lean` の `ScopeAcceptanceEntry`）。旧版は `null`（規則のない受理
  の入力、旧の像）で読む。中身は `CheckInput.prepare` が読む。 -/
  scopeAcceptance : Json
  deriving ToJson, FromJson
structure OperatorEntry where
  op : String
  operand : Option Ty
  name : String
  deriving ToJson, FromJson
structure Corpus where
  version : Nat
  operators : List OperatorEntry
  inputs : List Input
  deriving ToJson, FromJson
end Benitoite.Exchange
