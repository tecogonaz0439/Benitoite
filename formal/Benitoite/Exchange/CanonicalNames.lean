import Benitoite.Exchange.Syntax
import Benitoite.Release.Refinement.StandardModelDeclarations

/-! # 交換の識別子と標準の宣言名の対応

標準ライブラリの属性と構成子の対応から、一意に定まる型と構成子だけを標準表の名前へ写す。
不透明型は明示した有限表の引数のないものだけを写す。文字列の値は識別子として扱わない。
-/
namespace Benitoite.Exchange
open Lean

structure CanonicalNames where
  dataNames : List (String × String) := []
  constructorNames : List (String × String) := []
  opaqueNames : List (String × String) := []
  /-- 真なら構成子の名前の欄だけを写し、primitive・効果・型の名前は保つ。 -/
  constructorsOnly : Bool := false

namespace CanonicalNames

private def lookup (entries : List (String × String)) (name : String) : String :=
  (entries.lookup name).getD name

/-- 公開宣言名との一次の対応を持つ primitive だけを写す。残りは同じ名前を保つ。 -/
private def primitiveAliases : List (String × String) := [
  ("Benitoite.Assert.equal","Assert.equal"),
  ("Benitoite.Assert.fail","Assert.fail"),
  ("Benitoite.Assert.isTrue","Assert.isTrue"),
  ("Benitoite.Assert.notEqual","Assert.notEqual"),
  ("Benitoite.IO.Clock.localOffsetMinutes","Clock.localOffsetMinutes"),
  ("Benitoite.IO.Clock.monotonicMilliseconds","Clock.monotonicMilliseconds"),
  ("Benitoite.IO.Clock.now","Clock.now"),
  ("Benitoite.IO.Clock.sleep","Clock.sleep"),
  ("Benitoite.IO.Console.readAll","Console.readAll"),
  ("Benitoite.IO.Console.readAllBytes","Console.readAllBytes"),
  ("Benitoite.IO.Console.readAllLines","Console.readAllLines"),
  ("Benitoite.IO.Console.readLine","Console.readLine"),
  ("Benitoite.IO.Console.write","Console.write"),
  ("Benitoite.IO.Console.writeError","Console.writeError"),
  ("Benitoite.IO.Console.writeErrorLine","Console.writeErrorLine"),
  ("Benitoite.IO.Console.writeLine","Console.writeLine"),
  ("Benitoite.IO.File.appendBytes","File.appendBytes"),
  ("Benitoite.IO.File.appendBytesIn","File.appendBytesIn"),
  ("Benitoite.IO.File.appendText","File.appendText"),
  ("Benitoite.IO.File.appendTextIn","File.appendTextIn"),
  ("Benitoite.IO.File.canonicalize","File.canonicalize"),
  ("Benitoite.IO.File.createDirectory","File.createDirectory"),
  ("Benitoite.IO.File.exists","File.exists"),
  ("Benitoite.IO.File.info","File.info"),
  ("Benitoite.IO.File.listDirectory","File.listDirectory"),
  ("Benitoite.IO.File.openReader","File.openReader"),
  ("Benitoite.IO.File.openWriter","File.openWriter"),
  ("Benitoite.IO.File.readBytes","File.readBytes"),
  ("Benitoite.IO.File.readBytesIn","File.readBytesIn"),
  ("Benitoite.IO.File.readChunk","File.readChunk"),
  ("Benitoite.IO.File.readLine","File.readLine"),
  ("Benitoite.IO.File.readLines","File.readLines"),
  ("Benitoite.IO.File.readText","File.readText"),
  ("Benitoite.IO.File.readTextIn","File.readTextIn"),
  ("Benitoite.IO.File.remove","File.remove"),
  ("Benitoite.IO.File.removeTree","File.removeTree"),
  ("Benitoite.IO.File.rename","File.rename"),
  ("Benitoite.IO.File.walk","File.walk"),
  ("Benitoite.IO.File.write","File.write"),
  ("Benitoite.IO.File.writeBytes","File.writeBytes"),
  ("Benitoite.IO.File.writeBytesIn","File.writeBytesIn"),
  ("Benitoite.IO.File.writeChunk","File.writeChunk"),
  ("Benitoite.IO.File.writeLine","File.writeLine"),
  ("Benitoite.IO.File.writeText","File.writeText"),
  ("Benitoite.IO.File.writeTextIn","File.writeTextIn"),
  ("Benitoite.IO.Process.arguments","Process.arguments"),
  ("Benitoite.IO.Process.environmentVariable","Process.environmentVariable"),
  ("Benitoite.IO.Process.exit","Process.exit"),
  ("Benitoite.IO.Process.run","Process.run"),
  ("Benitoite.IO.Process.runAttached","Process.runAttached"),
  ("Benitoite.IO.Process.scriptDirectory","Process.scriptDirectory"),
  ("Benitoite.IO.Process.shell","Process.shell"),
  ("Benitoite.IO.Process.workingDirectory","Process.workingDirectory"),
  ("Benitoite.IO.Random.boolean","Random.boolean"),
  ("Benitoite.IO.Random.choose","Random.choose"),
  ("Benitoite.IO.Random.float","Random.float"),
  ("Benitoite.IO.Random.integer","Random.integer"),
  ("Benitoite.IO.Random.shuffle","Random.shuffle"),
  ("Benitoite.Log.emit","Log.emit"),
  ("Benitoite.Log.enabled","Log.enabled"),
  ("Benitoite.Network.Http.accept","Http.accept"),
  ("Benitoite.Network.Http.listen","Http.listen"),
  ("Benitoite.Network.Http.listenerPort","Http.listenerPort"),
  ("Benitoite.Network.Http.respond","Http.respond"),
  ("Benitoite.Network.Http.send","Http.send"),
  ("Benitoite.Network.Http.sendIn","Http.sendIn"),
  ("IO.File.closeReader","File.closeReader"),
  ("IO.File.closeWriter","File.closeWriter"),
  ("IO.Random.fromSeed","Random.fromSeed"),
  ("IO.Random.nextFloat","Random.nextFloat"),
  ("IO.Random.nextInteger","Random.nextInteger"),
  ("IO.Random.shuffleWith","Random.shuffleWith")
]

/-- 表にない primitive の名前を推測しない。 -/
def primitiveName (name : String) : String := lookup primitiveAliases name

/-- 公開宣言名との対応の有限表が写す先の primitive の名前（仮定側の組み込みの関数の名前）。 -/
def primitiveTargets : List String := primitiveAliases.map Prod.snd

private def effectAliases : List (String × String) := [
  ("IO.Console.Write","Console.Write"), ("IO.Console.Read","Console.Read"),
  ("IO.File.Read","File.Read"), ("IO.File.Write","File.Write"),
  ("IO.Process.Run","Process.Run"), ("IO.Process.Exit","Process.Exit"),
  ("IO.Process.Environment","Process.Environment"), ("IO.Clock.Time","Clock.Time"),
  ("IO.Random.Generate","Random.Generate"),
  ("Network.Http.Listen","Http.Listen"), ("Network.Http.Connect","Http.Connect")]

/-- 組込みの効果の有限の名前の対応。 -/
def effectName (name : String) : String := lookup effectAliases name

/-- 不透明型の引数を含む元の名前は、その一意性を保つ。 -/
def opaqueName (names : CanonicalNames) (name : String) : String := lookup names.opaqueNames name

private def publicName (name : String) : String :=
  if name.startsWith "Benitoite." then (name.drop 10).toString else name

private def leafName (name : String) : String := (name.splitOn ".").getLast!

private def sameDisplay (source target : String) : Bool :=
  source == target || source == publicName target || source == leafName target

private def put (table : List (String × String)) (source target : String) : Except String (List (String × String)) := do
  if let some old := table.lookup source then
    if old == target then return table
    throw s!"ambiguous canonical name: {source}"
  if table.any (fun entry => entry.2 == target && entry.1 != source) then
    throw s!"canonical name collision: {target}"
  return table ++ [(source,target)]

private def unique (what : String) (values : List α) : Except String (Option α) :=
  match values with
  | [] => pure none
  | [value] => pure (some value)
  | _ => throw s!"ambiguous standard declaration: {what}"

private def standardData (info : DataTypeInfo) : Except String (Option Benitoite.Release.Refinement.StandardKeyTyping.DataDecl) := do
  let declarations := Benitoite.Release.Refinement.StandardModel.declarations
  let allowed := info.package == "stdlib" || info.builtin != .ordinary
  if !allowed then return none
  let candidates := declarations.filter fun declaration =>
    let nameMatches := match info.builtin with
      | .result => declaration.name == "Result" || declaration.name == info.name
      | .option => declaration.name == "Option"
      | .ordinary => sameDisplay info.typeName declaration.name
    nameMatches && (info.builtin != .ordinary || declaration.constructors.length == info.constructors.length) &&
      info.constructors.all fun entry =>
      declaration.constructors.any (fun ctor => sameDisplay entry.2 ctor.1)
  let literalSource := candidates.filter fun declaration => declaration.name == info.name
  let literalType := candidates.filter fun declaration => declaration.name == info.typeName
  let publicType := candidates.filter fun declaration => publicName declaration.name == info.typeName
  unique info.name (if !literalSource.isEmpty then literalSource
    else if !literalType.isEmpty then literalType
    else if !publicType.isEmpty then publicType else candidates)

/-- 標準ライブラリの data の属性から、表示名が対応する標準の宣言の名前。構成子は照らさない（照らすのは
`standardData`）。 -/
def displayCounterparts (builtin : BuiltinData) (package name typeName : String) : List String :=
  if package != "stdlib" && builtin == .ordinary then [] else
  (Benitoite.Release.Refinement.StandardModel.declarations.filter fun declaration => match builtin with
    | .result => declaration.name == "Result" || declaration.name == name
    | .option => declaration.name == "Option"
    | .ordinary => sameDisplay typeName declaration.name).map (·.name)

private def addData (names : CanonicalNames) (info : DataTypeInfo) : Except String CanonicalNames := do
  let some declaration ← standardData info | return names
  let dataNames ← put names.dataNames info.name declaration.name
  let constructorNames ← info.constructors.foldlM (fun table entry => do
    let target ← unique entry.1 (declaration.constructors.filter fun ctor => sameDisplay entry.2 ctor.1)
    let some target := target | throw s!"missing standard constructor: {entry.1}"
    put table entry.1 target.1) names.constructorNames
  return { names with dataNames, constructorNames }

private def builtinDataInfo (value : Json) : Except String DataTypeInfo := do
  let constructors ← (← value.getObjValAs? (Array Json) "ctors").toList.mapM fun ctor => do
    let name ← ctor.getObjValAs? String "name"
    let label := (ctor.getObjValAs? (Option String) "constructorName").toOption.join.getD name
    return (name,label)
  return ⟨(← value.getObjValAs? BuiltinData "builtin"),
    (← value.getObjValAs? String "package"), (← value.getObjValAs? String "name"),
    (← value.getObjValAs? String "typeName"), (← value.getObjValAs? Bool "isRecord"),
    (← value.getObjValAs? Bool "extensible"), constructors⟩

/-- 実際の標準署名で使う引数のない不透明型と、処理系の公開宣言名の対応。 -/
private def knownOpaque : List (String × String) := [
  ("Benitoite.IOError.IOError","IOError"),
  ("Benitoite.NetworkError.NetworkError","NetworkError"),
  ("Benitoite.Scope.PathIn","Scope.PathIn"),
  ("Benitoite.Network.Http.RequestIn","Http.RequestIn")]

private def noOpaqueArguments (name : String) : Bool :=
  match name.splitOn ":" with
  | [] | [_] => false
  | id :: rest => id.toNat?.isSome &&
      ((Json.parse (String.intercalate ":" rest)).toOption == some (Json.arr #[]))

private def noCollision (table : List (String × String)) (originals : List String) : Except String Unit := do
  let _ ← originals.foldlM (fun seen source => put seen source (lookup table source)) []
  pure ()

/-- 同じ入力と組込みの書き出しだけから、明示された名前の対応を構成する。 -/
def ofInputs (input : Input) (builtin : Json) : Except String CanonicalNames := do
  let builtinInfo ← (← builtin.getObjValAs? (Array Json) "dataDecls").toList.mapM builtinDataInfo
  let infos := input.dataTypes ++ builtinInfo
  let names ← infos.foldlM addData {}
  let opaqueEntries ← builtin.getObjValAs? (List (String × String)) "opaqueNames"
  let opaqueNames ← opaqueEntries.foldlM (fun table entry => do
    if !noOpaqueArguments entry.1 then return table
    -- 公開名は、処理系の書き出しの完全名（`Benitoite.` で始まる）、その接頭辞を除いた名前、標準表の名前の
    -- どれでも受ける。どれも有限表の同じ行を指す。
    let some target := (knownOpaque.lookup entry.2).or (knownOpaque.lookup ("Benitoite." ++ entry.2)) |>.or
        (if knownOpaque.any (·.2 == entry.2) then some entry.2 else none) | return table
    put table entry.1 target) []
  noCollision names.dataNames (infos.map (·.name))
  noCollision names.constructorNames (infos.flatMap fun info => info.constructors.map Prod.fst)
  noCollision opaqueNames (opaqueEntries.map Prod.fst)
  let prims ← (← builtin.getObjValAs? (Array Json) "prims").toList.mapM fun value => value.getObjValAs? String "name"
  noCollision primitiveAliases (prims ++ input.definitions.map (·.name))
  let effects ← (← builtin.getObjValAs? (Array Json) "effects").toList.mapM fun value => value.getObjValAs? String "name"
  noCollision effectAliases (effects ++ input.effects.map (·.name))
  return { names with opaqueNames }

/-! ## 篩の項と述語の名前の写し

篩の述語の中の data と構成子の名前は、型付きの項と述語の上で写す。欄の参照（`FieldRef`）は所属の data
（`owner`）と構成子の名前を持つので、両方を写す。値の文字列（`Term.string` など）は識別子として扱わない。
構成子の名前の欄だけを写す対応（`constructorsOnly`）では、欄の参照の所属の data の名前も保つ。 -/

open Benitoite.Release.Refinement (FieldRef Pred)

/-- 欄の参照の所属の data と構成子の名前を写す。 -/
def fieldRef (names : CanonicalNames) (r : FieldRef) : FieldRef :=
  { r with owner := if names.constructorsOnly then r.owner else lookup names.dataNames r.owner
           constructor := lookup names.constructorNames r.constructor }

mutual
  /-- 項の中の構成子と欄の参照の名前を写す。 -/
  def term (names : CanonicalNames) : Benitoite.Release.Refinement.Term → Benitoite.Release.Refinement.Term
    | .listValue xs => .listValue (slots names xs)
    | .mapValue ks vs => .mapValue (slots names ks) (slots names vs)
    | .setValue xs => .setValue (slots names xs)
    | .dataValue c xs => .dataValue (lookup names.constructorNames c) (slots names xs)
    | .field r t => .field (names.fieldRef r) (term names t)
    | .measure m t => .measure m (term names t)
    | .add a b => .add (term names a) (term names b)
    | .neg a => .neg (term names a)
    | .scale c a => .scale c (term names a)
    | t => t
  /-- 観測しない位置（`none`）を保って、各位置の項を写す。 -/
  def slots (names : CanonicalNames) : List (Option Benitoite.Release.Refinement.Term) → List (Option Benitoite.Release.Refinement.Term)
    | [] => []
    | none :: xs => none :: slots names xs
    | some t :: xs => some (term names t) :: slots names xs
end

/-- 述語の中の項と構成子の判定の名前を写す。 -/
def pred (names : CanonicalNames) : Pred → Pred
  | .eq a b => .eq (names.term a) (names.term b)
  | .le a b => .le (names.term a) (names.term b)
  | .lt a b => .lt (names.term a) (names.term b)
  | .compare s o a b => .compare s o (names.term a) (names.term b)
  | .floatClass w c v => .floatClass w c (names.term v)
  | .decimalRepresented v => .decimalRepresented (names.term v)
  | .charactersIn t lo hi => .charactersIn (names.term t) lo hi
  | .member k v r => .member k (names.term v) r
  | .constructorIs v c => .constructorIs (names.term v) (lookup names.constructorNames c)
  | .and p q => .and (pred names p) (pred names q)
  | .or p q => .or (pred names p) (pred names q)
  | .not p => .not (pred names p)
  | p => p

/-- 欄の参照の交換の形（構造体から導出した四つの欄だけを持つ対象）か。 -/
private def fieldRefJson? (value : Json) : Option FieldRef :=
  match value with
  | .obj entries =>
      if entries.toArray.size == 4 && ["owner", "constructor", "position", "result"].all
          (fun key => (value.getObjVal? key).isOk) then
        (fromJson? value : Except String FieldRef).toOption
      else none
  | _ => none

private def objectContext (outer : String) (value : Json) : String :=
  if (value.getObjVal? "typeName").isOk && (value.getObjVal? "builtin").isOk then "dataEntry"
  else if (value.getObjVal? "constructorName").isOk then "constructorEntry"
  else if (value.getObjVal? "ctors").isOk then "dataEntry"
  else outer

private def constructorField (context field : String) : Bool :=
  (field == "name" && ["con", "record", "recordUpdate", "conCall", "conValue", "nullCon", "partialCon",
    "constructorEntry"].contains context) ||
  field == "constructor" || field == "con" || field == "ok" || field == "err" ||
    field == "someCon" || field == "noneCon"

private def renameString (names : CanonicalNames) (context field value : String) : String :=
  if names.constructorsOnly then
    if constructorField context field then lookup names.constructorNames value else value
  else if field == "name" then
    if ["data", "dataEntry", "summaries"].contains context then lookup names.dataNames value
    else if ["con", "record", "recordUpdate", "conCall", "conValue", "nullCon", "partialCon",
      "constructorEntry"].contains context then lookup names.constructorNames value
    else if ["opaque", "scoped", "valKinds", "valContents"].contains context then names.opaqueName value
    else if ["effects", "effKinds"].contains context then effectName value
    else if ["prim", "primName", "funName", "funDicts", "fnRef", "prims", "definitions", "ops",
      "primOps", "operators", "admitsR"].contains context then primitiveName value
    else value
  else if field == "value" && context == "name" then effectName value
  else if field == "constructor" || field == "con" || field == "ok" || field == "err" ||
      field == "someCon" || field == "noneCon" then lookup names.constructorNames value
  else if field == "data" then lookup names.dataNames value
  else if field == "opEff" || field == "eff" then effectName value
  else if field == "function" || field == "exit" then primitiveName value
  else value

/-- 型・構成子・primitive・効果の識別欄だけを文法に沿って写す。値の文字列は保存する。篩付きの型の述語（欄
`predicate`）は型付きの述語として読んで `pred` で写し、そのほかの位置の欄の参照も `fieldRef` で写す。 -/
private partial def rewrite (names : CanonicalNames) (context : String) : Json → Json
  | .arr values => .arr (values.map (rewrite names context))
  | value@(.obj entries) =>
    match fieldRefJson? value with
    | some r => toJson (names.fieldRef r)
    | none =>
      let context := objectContext context value
      Json.mkObj (entries.toArray.toList.map fun (field, child) =>
        let next := if ["dataTypes", "dataDecls", "ctors", "definitions", "prims", "effects", "ops", "primOps",
          "effKinds", "valKinds", "admitsR", "valContents", "operators", "summaries"].contains field
          then field
          else if entries.toArray.size == 1 then field else context
        let predicate := if field == "predicate" then (fromJson? child : Except String Pred).toOption else none
        let rewritten := if field == "annotations" then child else
          if let some p := predicate then toJson (names.pred p) else match child with
          | .str text => .str (renameString names context field text)
          | .arr values =>
              if !names.constructorsOnly && (field == "statePure" || field == "supplementalPrims") then
                .arr (values.map fun value => match value with | .str name => .str (primitiveName name) | _ => value)
              else if field == "coverageView" then
                .arr (values.map fun value => match value with | .str name => .str (lookup names.dataNames name) | _ => value)
              else if !names.constructorsOnly && field == "ops" && context == "effects" then
                .arr (values.map fun value => match value with | .str name => .str (primitiveName name) | _ => rewrite names next value)
              else if field == "supplementalData" then
                .arr (values.map fun value => match value with
                  | .arr pair => .arr (pair.map fun value => match value with
                      | .str name => .str (lookup names.dataNames name) | _ => value)
                  | _ => value)
              else if field == "constructors" && context == "dataEntry" then
                .arr (values.map fun value => match value with
                  | .arr pair => .arr (pair.mapIdx fun i value => match value with
                      | .str name => if i == 0 then .str (lookup names.constructorNames name) else value
                      | _ => value)
                  | _ => value)
              else rewrite names next (.arr values)
          | _ => rewrite names next child
        (field,rewritten))
  | value => value

/-- 同じ入力の元の識別子を、証拠から決まった名前へ写す。資源の番号と文字列の値は保つ。 -/
def json (names : CanonicalNames) (value : Json) : Json := rewrite names "" value

/-- 交換の Result の構成子の名前（`Ok`・`Error`）と、篩付きの表層の実例の表の名前（`Result.Ok`・`Result.Error`）を
入れ替える対応。入れ替えなので、二度写すと元に戻る。 -/
def resultConstructors : CanonicalNames :=
  { constructorNames := [("Ok", "Result.Ok"), ("Result.Ok", "Ok"), ("Error", "Result.Error"),
      ("Result.Error", "Error")], constructorsOnly := true }

/-- 交換の文書の構成子の名前の欄だけを `resultConstructors` で写す（設計書 07-04「交換の形式の版」）。 -/
def resultJson (value : Json) : Json := resultConstructors.json value

/-- `resultConstructors` の構成子の名前の写しは入れ替えなので、二度写すと元の名前に戻る。 -/
theorem resultConstructors_lookup_twice (s : String) :
    lookup resultConstructors.constructorNames (lookup resultConstructors.constructorNames s) = s := by
  by_cases h1 : s = "Ok"
  · subst h1; rfl
  by_cases h2 : s = "Result.Ok"
  · subst h2; rfl
  by_cases h3 : s = "Error"
  · subst h3; rfl
  by_cases h4 : s = "Result.Error"
  · subst h4; rfl
  have h : lookup resultConstructors.constructorNames s = s := by
    have e1 : (s == "Ok") = false := beq_false_of_ne h1
    have e2 : (s == "Result.Ok") = false := beq_false_of_ne h2
    have e3 : (s == "Error") = false := beq_false_of_ne h3
    have e4 : (s == "Result.Error") = false := beq_false_of_ne h4
    simp only [lookup, resultConstructors, List.lookup, e1, e2, e3, e4, Option.getD_none]
  rw [h, h]

/-- 構成子の名前の欄だけを写す対応は、欄の参照の所属の data の名前を変えない。 -/
theorem resultConstructors_fieldRef_owner (r : FieldRef) : (resultConstructors.fieldRef r).owner = r.owner := rfl

/-- 欄の参照の写しも、二度写すと元に戻る。 -/
theorem resultConstructors_fieldRef_twice (r : FieldRef) :
    resultConstructors.fieldRef (resultConstructors.fieldRef r) = r := by
  cases r
  simp only [fieldRef, resultConstructors_lookup_twice]
  rfl

mutual
  /-- 項の写しも、二度写すと元に戻る。 -/
  theorem resultConstructors_term_twice : (t : Benitoite.Release.Refinement.Term) →
      resultConstructors.term (resultConstructors.term t) = t
    | .listValue xs => by simp only [term, resultConstructors_slots_twice xs]
    | .mapValue ks vs => by simp only [term, resultConstructors_slots_twice ks, resultConstructors_slots_twice vs]
    | .setValue xs => by simp only [term, resultConstructors_slots_twice xs]
    | .dataValue c xs => by simp only [term, resultConstructors_lookup_twice, resultConstructors_slots_twice xs]
    | .field r t => by simp only [term, resultConstructors_fieldRef_twice, resultConstructors_term_twice t]
    | .measure m t => by simp only [term, resultConstructors_term_twice t]
    | .add a b => by simp only [term, resultConstructors_term_twice a, resultConstructors_term_twice b]
    | .neg a => by simp only [term, resultConstructors_term_twice a]
    | .scale c a => by simp only [term, resultConstructors_term_twice a]
    | .var _ | .integer _ | .character _ | .float64 _ | .float32 _ | .decimal _ _ | .boolean _ | .unitValue
    | .string _ | .bytesValue _ | .targetValue _ _ => rfl
  /-- 位置の列の写しも、二度写すと元に戻る。 -/
  theorem resultConstructors_slots_twice : (xs : List (Option Benitoite.Release.Refinement.Term)) →
      resultConstructors.slots (resultConstructors.slots xs) = xs
    | [] => rfl
    | none :: xs => by simp only [slots, resultConstructors_slots_twice xs]
    | some t :: xs => by simp only [slots, resultConstructors_term_twice t, resultConstructors_slots_twice xs]
end

/-- 篩の述語の写しも、二度写すと元に戻る（交換の文書を篩付きの表層の名前へ写す `resultJson` の述語の部分）。 -/
theorem resultConstructors_pred_twice (p : Pred) :
    resultConstructors.pred (resultConstructors.pred p) = p := by
  induction p with
  | and p q hp hq => simp only [pred, hp, hq]
  | or p q hp hq => simp only [pred, hp, hq]
  | not p hp => simp only [pred, hp]
  | constructorIs v c => simp only [pred, resultConstructors_term_twice, resultConstructors_lookup_twice]
  | truth | falsity => rfl
  | _ => simp only [pred, resultConstructors_term_twice]

/-- 交換の名前の Result の判定と欄の参照を持つ述語は、写すと表層の名前になり、もう一度写すと戻る。 -/
example : resultConstructors.pred (.constructorIs (.var 0) "Ok") = .constructorIs (.var 0) "Result.Ok" ∧
    resultConstructors.pred (resultConstructors.pred
      (.eq (.field ⟨"Result", "Ok", 0, .integer⟩ (.var 0)) (.integer 1))) =
      .eq (.field ⟨"Result", "Ok", 0, .integer⟩ (.var 0)) (.integer 1) :=
  ⟨rfl, resultConstructors_pred_twice _⟩

end CanonicalNames
end Benitoite.Exchange
