import Lean
import Benitoite.Surface.Desugar

/-! C3〜C7c の交換形式。導出した JSON は構成子名を鍵、引数名を欄名にする。
型・表層・コアを別の型にし、範囲外のコアは unsupported として保持する。
エフェクトだけは順序によらず比較し、Float は UInt64 のビットで比較する。 -/
namespace Benitoite.Exchange
open Lean

inductive Atom where
  | name (value : String)
  | rho (index : Nat)
  deriving BEq, ToJson, FromJson, Repr
abbrev Eff := List Atom

inductive TyCon where
  | data (name : String)
  | list | set | map | reference | lazyT
  deriving BEq, ToJson, FromJson, Repr

inductive Ty where
  | base (name : String)
  | opaque (name : String)
  | data (name : String) (args : List Ty)
  | list (elem : Ty)
  | fn (params : List Ty) (ret : Ty) (eff : Eff)
  | tvar (index : Nat)
  | reference (elem : Ty)
  | lazyT (elem : Ty)
  | map (key value : Ty)
  | set (elem : Ty)
  | bytes
  | dict (cls : String) (arg : Ty)
  | tapp (index : Nat) (args : List Ty)
  | ctor (head : TyCon)
  deriving BEq, ToJson, FromJson, Repr

inductive Const where
  | integer (value : Int)
  | decimal (mantissa : Int) (scale : Nat)
  | float (bits : UInt64)
  | string (value : String)
  | character (value : Nat)
  | boolean (value : Bool)
  | unit
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
  deriving BEq, ToJson, FromJson, Repr

inductive DictEv where
  | impl (name : String) (tys : List Ty) (args : List DictEv)
  | local (index : Nat)
  | super (dict : DictEv) (cls : String)
  deriving ToJson, FromJson, Repr

inductive InterpPart where
  | text (value : String)
  | stringExpr
  | converted (ty : Ty)
  deriving ToJson, FromJson, Repr

mutual
  inductive Expr where
    | local (index : Nat)
    | constName (name : String)
    | funName (name : String) (tys : List Ty) (effs : List Eff)
    | funDicts (name : String) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (params : List Ty) (eff : Eff)
    | methName (dict : DictEv) (name : String) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (params : List Ty) (eff : Eff)
    | primName (name : String) (tys : List Ty) (effs : List Eff)
    | opName (name : String) (tys : List Ty)
    | nullCon (name : String) (tys : List Ty)
    | conValue (name : String) (tys params : List Ty)
    | literal (value : Const)
    /-- 型検査が記録した符号反転後の Float のビット。 -/
    | negFloat (bits : UInt64)
    | negDecimal (mantissa : Int) (scale : Nat)
    | unit
    | paren (inner : Expr)
    | record (name : String) (tys : List Ty) (positions : List Nat) (args : List Expr)
    | recordUpdate (name : String) (tys : List Ty) (n : Nat) (positions : List Nat) (base : Expr) (args : List Expr)
    | conCall (name : String) (tys : List Ty) (args : List Expr)
    | call (callee : Expr) (args : List Expr)
    | pipe (lhs rhs : Expr)
    | partialCall (callee : Expr) (args : List HoleArg) (ret : Ty) (eff : Eff)
    | partialCon (name : String) (tys : List Ty) (args : List HoleArg)
    | binary (op : String) (operand : Ty) (lhs rhs : Expr)
    | neg (operand : Ty) (inner : Expr)
    | not (inner : Expr)
    | and (lhs rhs : Expr)
    | or (lhs rhs : Expr)
    | list (elem : Ty) (elems : List Expr)
    | listSpread (elem : Ty) (concat : Expr) (before : List Expr) (spread : Expr) (after : List Expr)
    | interpolation (parts : List InterpPart) (es converters : List Expr)
    | lam (params : List Ty) (ret : Ty) (eff : Eff) (body : Block)
    | ite (cond : Expr) (yes no : Block)
    | elseIf (cond : Expr) (yes : Block) (no : Expr)
    | ifOnly (cond : Expr) (yes : Block)
    | matchE (ret : Ty) (scrutinee : Expr) (arms : List Arm)
    | returnE (ret : Ty) (inner : Expr)
    | tryResult (retArgs : List Ty) (ok err : String) (inner : Expr)
    | tryOption (retArgs : List Ty) (someCon noneCon : String) (inner : Expr)
    | withE (o : String) (bound : Expr) (body : Block)
    | lazyE (body : Block)
    | handleE (body : Block) (clauses : List SurfaceClause)
    | resume (index : Nat) (inner : Expr)
  inductive SurfaceClause where
    | mk (op : OpRef) (arity ntys : Nat) (body : Block)
  inductive HoleArg where
    | expr (inner : Expr)
    | hole (ty : Ty)
  inductive Arm where
    | mk (alts : List Alternative) (guard : Option Expr) (body : Block)
  inductive Block where
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
    | .constName name => Json.mkObj [("constName", Json.mkObj [("name", toJson name)])]
    | .funDicts name tys effs dicts params eff => Json.mkObj [("funDicts", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("dicts", toJson dicts), ("params", toJson params), ("eff", toJson eff)])]
    | .methName dict name tys effs dicts params eff => Json.mkObj [("methName", Json.mkObj [("dict", toJson dict), ("name", toJson name), ("tys", toJson tys), ("effs", toJson effs), ("dicts", toJson dicts), ("params", toJson params), ("eff", toJson eff)])]
    | .local index => Json.mkObj [("local", Json.mkObj [("index", toJson index)])]
    | .funName name tys effs => Json.mkObj [("funName", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs)])]
    | .primName name tys effs => Json.mkObj [("primName", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs)])]
    | .nullCon name tys => Json.mkObj [("nullCon", Json.mkObj [("name", toJson name), ("tys", toJson tys)])]
    | .conValue name tys params => Json.mkObj [("conValue", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("params", toJson params)])]
    | .literal value => Json.mkObj [("literal", Json.mkObj [("value", toJson value)])]
    | .negFloat bits => Json.mkObj [("negFloat", Json.mkObj [("bits", toJson bits)])]
    | .negDecimal mantissa scale => Json.mkObj [("negDecimal", Json.mkObj [("mantissa", toJson mantissa), ("scale", toJson scale)])]
    | .listSpread elem concat before spread after => Json.mkObj [("listSpread", Json.mkObj [("elem", toJson elem), ("concat", encodeExpr concat), ("before", Json.arr (before.map encodeExpr).toArray), ("spread", encodeExpr spread), ("after", Json.arr (after.map encodeExpr).toArray)])]
    | .interpolation parts es converters => Json.mkObj [("interpolation", Json.mkObj [("parts", toJson parts), ("es", Json.arr (es.map encodeExpr).toArray), ("converters", Json.arr (converters.map encodeExpr).toArray)])]
    | .unit  => toJson "unit"
    | .paren inner => Json.mkObj [("paren", Json.mkObj [("inner", encodeExpr inner)])]
    | .record name tys positions args => Json.mkObj [("record", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("positions", toJson positions), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .recordUpdate name tys n positions base args => Json.mkObj [("recordUpdate", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("n", toJson n), ("positions", toJson positions), ("base", encodeExpr base), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .conCall name tys args => Json.mkObj [("conCall", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .call callee args => Json.mkObj [("call", Json.mkObj [("callee", encodeExpr callee), ("args", Json.arr (args.map encodeExpr).toArray)])]
    | .pipe lhs rhs => Json.mkObj [("pipe", Json.mkObj [("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .partialCall callee args ret eff => Json.mkObj [("partialCall", Json.mkObj [("callee", encodeExpr callee), ("args", Json.arr (args.map encodeHoleArg).toArray), ("ret", toJson ret), ("eff", toJson eff)])]
    | .partialCon name tys args => Json.mkObj [("partialCon", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeHoleArg).toArray)])]
    | .binary op operand lhs rhs => Json.mkObj [("binary", Json.mkObj [("op", toJson op), ("operand", toJson operand), ("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .neg operand inner => Json.mkObj [("neg", Json.mkObj [("operand", toJson operand), ("inner", encodeExpr inner)])]
    | .not inner => Json.mkObj [("not", Json.mkObj [("inner", encodeExpr inner)])]
    | .and lhs rhs => Json.mkObj [("and", Json.mkObj [("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .or lhs rhs => Json.mkObj [("or", Json.mkObj [("lhs", encodeExpr lhs), ("rhs", encodeExpr rhs)])]
    | .list elem elems => Json.mkObj [("list", Json.mkObj [("elem", toJson elem), ("elems", Json.arr (elems.map encodeExpr).toArray)])]
    | .lam params ret eff body => Json.mkObj [("lam", Json.mkObj [("params", toJson params), ("ret", toJson ret), ("eff", toJson eff), ("body", encodeBlock body)])]
    | .ite cond yes no => Json.mkObj [("ite", Json.mkObj [("cond", encodeExpr cond), ("yes", encodeBlock yes), ("no", encodeBlock no)])]
    | .elseIf cond yes no => Json.mkObj [("elseIf", Json.mkObj [("cond", encodeExpr cond), ("yes", encodeBlock yes), ("no", encodeExpr no)])]
    | .ifOnly cond yes => Json.mkObj [("ifOnly", Json.mkObj [("cond", encodeExpr cond), ("yes", encodeBlock yes)])]
    | .matchE ret scrutinee arms => Json.mkObj [("matchE", Json.mkObj [("ret", toJson ret), ("scrutinee", encodeExpr scrutinee), ("arms", Json.arr (arms.map encodeArm).toArray)])]
    | .returnE ret inner => Json.mkObj [("returnE", Json.mkObj [("ret", toJson ret), ("inner", encodeExpr inner)])]
    | .tryResult retArgs ok err inner => Json.mkObj [("tryResult", Json.mkObj [("retArgs", toJson retArgs), ("ok", toJson ok), ("err", toJson err), ("inner", encodeExpr inner)])]
    | .tryOption retArgs someCon noneCon inner => Json.mkObj [("tryOption", Json.mkObj [("retArgs", toJson retArgs), ("someCon", toJson someCon), ("noneCon", toJson noneCon), ("inner", encodeExpr inner)])]
    | .withE o bound body => Json.mkObj [("withE", Json.mkObj [("o", toJson o), ("bound", encodeExpr bound), ("body", encodeBlock body)])]
    | .lazyE body => Json.mkObj [("lazyE", Json.mkObj [("body", encodeBlock body)])]
    | .opName name tys => Json.mkObj [("opName", Json.mkObj [("name", toJson name), ("tys", toJson tys)])]
    | .handleE body clauses => Json.mkObj [("handleE", Json.mkObj [("body", encodeBlock body), ("clauses", Json.arr (clauses.map encodeSurfaceClause).toArray)])]
    | .resume index inner => Json.mkObj [("resume", Json.mkObj [("index", toJson index), ("inner", encodeExpr inner)])]
  partial def encodeSurfaceClause : SurfaceClause → Json
    | .mk op arity ntys body => Json.mkObj [("op", toJson op), ("arity", toJson arity), ("ntys", toJson ntys), ("body", encodeBlock body)]
  partial def encodeHoleArg : HoleArg → Json
    | .expr inner => Json.mkObj [("expr", Json.mkObj [("inner", encodeExpr inner)])]
    | .hole ty => Json.mkObj [("hole", Json.mkObj [("ty", toJson ty)])]
  partial def encodeArm : Arm → Json
    | .mk alts guard body => Json.mkObj [("mk", Json.mkObj [("alts", toJson alts), ("guard", guard.map encodeExpr |>.getD Json.null), ("body", encodeBlock body)])]
  partial def encodeBlock : Block → Json
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
mutual
  partial def decodeExpr (j : Json) : Except String Expr := do
    if let .ok o := j.getObjVal? "constName" then
      return .constName (← fromJson? (← o.getObjVal? "name"))
    if let .ok o := j.getObjVal? "funDicts" then
      return .funDicts (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← fromJson? (← o.getObjVal? "dicts")) (← fromJson? (← o.getObjVal? "params")) (← fromJson? (← o.getObjVal? "eff"))
    if let .ok o := j.getObjVal? "methName" then
      return .methName (← fromJson? (← o.getObjVal? "dict")) (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs")) (← fromJson? (← o.getObjVal? "dicts")) (← fromJson? (← o.getObjVal? "params")) (← fromJson? (← o.getObjVal? "eff"))
    if let .ok o := j.getObjVal? "local" then
      return .local (← fromJson? (← o.getObjVal? "index"))
    if let .ok o := j.getObjVal? "funName" then
      return .funName (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs"))
    if let .ok o := j.getObjVal? "primName" then
      return .primName (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs"))
    if let .ok o := j.getObjVal? "nullCon" then
      return .nullCon (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys"))
    if let .ok o := j.getObjVal? "conValue" then
      return .conValue (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "params"))
    if let .ok o := j.getObjVal? "literal" then
      return .literal (← fromJson? (← o.getObjVal? "value"))
    if let .ok o := j.getObjVal? "negFloat" then
      return .negFloat (← fromJson? (← o.getObjVal? "bits"))
    if let .ok o := j.getObjVal? "negDecimal" then
      return .negDecimal (← fromJson? (← o.getObjVal? "mantissa")) (← fromJson? (← o.getObjVal? "scale"))
    if let .ok o := j.getObjVal? "listSpread" then
      return .listSpread (← fromJson? (← o.getObjVal? "elem")) (← decodeExpr (← o.getObjVal? "concat")) (← (← (← o.getObjVal? "before").getArr?).toList.mapM decodeExpr) (← decodeExpr (← o.getObjVal? "spread")) (← (← (← o.getObjVal? "after").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "interpolation" then
      return .interpolation (← fromJson? (← o.getObjVal? "parts")) (← (← (← o.getObjVal? "es").getArr?).toList.mapM decodeExpr) (← (← (← o.getObjVal? "converters").getArr?).toList.mapM decodeExpr)
    if j == toJson "unit" then return .unit
    if let .ok o := j.getObjVal? "paren" then
      return .paren (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "record" then
      return .record (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "positions")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "recordUpdate" then
      return .recordUpdate (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "n")) (← fromJson? (← o.getObjVal? "positions")) (← decodeExpr (← o.getObjVal? "base")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "conCall" then
      return .conCall (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "call" then
      return .call (← decodeExpr (← o.getObjVal? "callee")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeExpr)
    if let .ok o := j.getObjVal? "pipe" then
      return .pipe (← decodeExpr (← o.getObjVal? "lhs")) (← decodeExpr (← o.getObjVal? "rhs"))
    if let .ok o := j.getObjVal? "partialCall" then
      return .partialCall (← decodeExpr (← o.getObjVal? "callee")) (← (← (← o.getObjVal? "args").getArr?).toList.mapM decodeHoleArg) (← fromJson? (← o.getObjVal? "ret")) (← fromJson? (← o.getObjVal? "eff"))
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
      return .lam (← fromJson? (← o.getObjVal? "params")) (← fromJson? (← o.getObjVal? "ret")) (← fromJson? (← o.getObjVal? "eff")) (← decodeBlock (← o.getObjVal? "body"))
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
    return .mk (← fromJson? (← j.getObjVal? "op")) (← fromJson? (← j.getObjVal? "arity")) (← fromJson? (← j.getObjVal? "ntys")) (← decodeBlock (← j.getObjVal? "body"))
  partial def decodeHoleArg (j : Json) : Except String HoleArg := do
    if let .ok o := j.getObjVal? "expr" then
      return .expr (← decodeExpr (← o.getObjVal? "inner"))
    if let .ok o := j.getObjVal? "hole" then
      return .hole (← fromJson? (← o.getObjVal? "ty"))
    throw "unknown HoleArg constructor"
  partial def decodeArm (j : Json) : Except String Arm := do
    if let .ok o := j.getObjVal? "mk" then
      let g ← o.getObjVal? "guard"
      return .mk (← fromJson? (← o.getObjVal? "alts")) (← if g == Json.null then pure none else some <$> decodeExpr g) (← decodeBlock (← o.getObjVal? "body"))
    throw "unknown Arm constructor"
  partial def decodeBlock (j : Json) : Except String Block := do
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

mutual
  inductive Val where
    | var (index : Nat)
    | const (value : Const)
    | fnRef (name : String) (tys : List Ty) (effs : List Eff)
    | prim (name : String) (tys : List Ty) (effs : List Eff)
    | op (name : String) (tys : List Ty)
    | lam (params : List Ty) (body : Comp)
    | con (name : String) (tys : List Ty) (args : List Val)
    | list (elems : List Val)
    | dict (name : String) (tys : List Ty) (args : List Val)
    | super (dict : Val) (cls : String)
    | unsupported (name : String)
  inductive Comp where
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
    | mk (op : OpRef) (arity ntys : Nat) (body : Comp)
end
deriving instance BEq for Val, Comp, CoreArm, CoreClause
mutual
  partial def encodeVal : Val → Json
    | .dict name tys args => Json.mkObj [("dict", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .super dict cls => Json.mkObj [("super", Json.mkObj [("dict", encodeVal dict), ("cls", toJson cls)])]
    | .var index => Json.mkObj [("var", Json.mkObj [("index", toJson index)])]
    | .const value => Json.mkObj [("const", Json.mkObj [("value", toJson value)])]
    | .fnRef name tys effs => Json.mkObj [("fnRef", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs)])]
    | .prim name tys effs => Json.mkObj [("prim", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("effs", toJson effs)])]
    | .lam params body => Json.mkObj [("lam", Json.mkObj [("params", toJson params), ("body", encodeComp body)])]
    | .con name tys args => Json.mkObj [("con", Json.mkObj [("name", toJson name), ("tys", toJson tys), ("args", Json.arr (args.map encodeVal).toArray)])]
    | .list elems => Json.mkObj [("list", Json.mkObj [("elems", Json.arr (elems.map encodeVal).toArray)])]
    | .unsupported name => Json.mkObj [("unsupported", Json.mkObj [("name", toJson name)])]
    | .op name tys => Json.mkObj [("op", Json.mkObj [("name", toJson name), ("tys", toJson tys)])]
  partial def encodeComp : Comp → Json
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
    | .mk op arity ntys body => Json.mkObj [("op", toJson op), ("arity", toJson arity), ("ntys", toJson ntys), ("body", encodeComp body)]
end
mutual
  partial def decodeVal (j : Json) : Except String Val := do
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
      return .prim (← fromJson? (← o.getObjVal? "name")) (← fromJson? (← o.getObjVal? "tys")) (← fromJson? (← o.getObjVal? "effs"))
    if let .ok o := j.getObjVal? "lam" then
      return .lam (← fromJson? (← o.getObjVal? "params")) (← decodeComp (← o.getObjVal? "body"))
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
    return .mk (← fromJson? (← j.getObjVal? "op")) (← fromJson? (← j.getObjVal? "arity")) (← fromJson? (← j.getObjVal? "ntys")) (← decodeComp (← j.getObjVal? "body"))
end
instance : ToJson Val := ⟨encodeVal⟩
instance : FromJson Val := ⟨decodeVal⟩
instance : ToJson Comp := ⟨encodeComp⟩
instance : FromJson Comp := ⟨decodeComp⟩

structure Header where
  tparams : List (Bool × Bool)
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  deriving BEq, ToJson, FromJson

structure SurfaceDef where
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
  knownDifferences : List String := []
  scope : Scope
  deriving ToJson, FromJson
structure OpEntry where
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
  name : String
  ty : Ty
  body : Expr
  deriving ToJson, FromJson
structure Input where
  group : String
  name : String
  excluded : List String
  definitions : List Definition
  constants : List ConstantEntry
  ops : List OpEntry := []
  effects : List EffectEntry := []
  primOps : List PrimOpEntry := []
  classes : List ClassEntry
  impls : List ImplEntry
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
