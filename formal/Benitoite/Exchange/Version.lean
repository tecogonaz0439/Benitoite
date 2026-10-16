import Benitoite.Exchange.Syntax

/-! 設計書 07-04「証明する性質」に対応する版ごとの交換契約。
旧版の閉じた既定だけを補い、新版の必須情報は補完しない。 -/
namespace Benitoite.Exchange
open Lean

/-- 旧版で新しい情報を無視しない。未知の式の内側にも同じ制約を適用する。 -/
partial def rejectFields (keys : List String) : Json → Except String Unit
  | .arr xs => xs.toList.forM (rejectFields keys)
  | .obj xs => xs.toArray.toList.forM fun (k,v) => do
      if keys.contains k then throw s!"field requires new exchange version: {k}"
      rejectFields keys v
  | _ => pure ()

def addFields (j : Json) (fields : List (String × Json)) : Json :=
  match j with
  | .obj xs => Json.mkObj (xs.toArray.toList ++ fields)
  | _ => j

/-- 旧版の既知の欄だけを辿る。式の中の同名の欄から種類を推測しない。 -/
def mapField (j : Json) (key : String) (f : Json → Json) : Json :=
  match j with
  | .obj xs => Json.mkObj (xs.toArray.toList.map fun (k,v) => (k, if k == key then f v else v))
  | _ => j

def mapArray (f : Json → Json) : Json → Json
  | .arr xs => .arr (xs.map f)
  | j => j

def legacyBody (j : Json) : Json :=
  addFields j [("package", toJson "legacy"), ("coverageView", toJson ([] : List String))]

def legacyData (kind : String) (j : Json) : Json :=
  let cs := ((j.getObjVal? "ctors").bind Json.getArr?).toOption.getD #[]
  let record := if kind == "coverage" then (j.getObjVal? "fields").toOption.any (· != Json.null)
    else cs.any fun c => (c.getObjVal? "fields").toOption.any (· != Json.null)
  addFields j ([("builtin", toJson "ordinary"), ("package", toJson "legacy"), ("extensible", toJson false),
    ("isRecord", toJson record)] ++
    if kind == "builtins" then [("typeName", (j.getObjVal? "name").toOption.getD Json.null)] else [])

/-- 互換の変換は形式ごとの既知の経路にだけ適用する。 -/
def closedDefaults (kind : String) (j : Json) : Json :=
  if kind == "corpus" then mapField j "inputs" (mapArray fun i =>
    let i := addFields i [("dataTypes", toJson ([] : List DataTypeInfo))]
    let i := mapField i "constants" (mapArray fun c => addFields c [("package", toJson "legacy")])
    mapField i "definitions" (mapArray fun d =>
      mapField d "scope" (fun scope => mapField scope "inScope" (fun scope =>
        mapField scope "surface" legacyBody))))
  else if kind == "builtins" then
    mapField j "inputs" (mapArray fun i => mapField i "dataDecls" (mapArray (legacyData kind)))
  else if kind == "coverage" then
    mapField j "cases" (mapArray fun i => mapField (legacyBody i) "decls" (mapArray (legacyData kind)))
  else if kind == "coverage-program" then
    mapField j "inputs" (mapArray fun i =>
      mapField (mapField i "matches" (mapArray legacyBody)) "bindings" (mapArray legacyBody))
  else j

/-- 8/2/2 と 9/3/3 は、それぞれ後の版の情報がない場合だけ互換入力として読める。 -/
def exchangeJson (kind : String) (j : Json) : Except String Json := do
  let version ← j.getObjValAs? Nat "version"
  let old := if kind == "corpus" then 8 else 2
  let current := if kind == "corpus" then 10 else 3
  if kind == "corpus" && version < 10 then
    rejectFields ["tryResultReturn", "tryOptionReturn", "tryResultDie", "tryOptionDie"] j
  -- 契約名の導入前の版に新版の欄を混ぜた誤りを、単なる版の拒否と区別する。
  if version == (if kind == "corpus" then 7 else 1) then
    rejectFields ["names", "labels", "positions", "fields"] j
  if version == old then
    rejectFields (["builtin", "package", "coverageView", "extensible", "isRecord", "dataTypes"] ++
      if kind == "coverage" then [] else ["typeName", "constructorName"]) j
    return closedDefaults kind j
  if version != current && !(kind == "corpus" && version == 9) then
    throw s!"unsupported {kind} exchange version: {version}"
  return j

def validateDataTypes (ds : List DataTypeInfo) : Except String Unit := do
  if (ds.map (·.name)).eraseDups.length != ds.length then throw "duplicate data type metadata"
  if ds.any (fun d => d.name.isEmpty || d.typeName.isEmpty || d.package.isEmpty) then
    throw "empty data type name or package"
  -- 解決された標準の型の識別で判定し、表示名は使わない。
  if ds.any (fun d => d.builtin != .ordinary && d.extensible) then
    throw "Result/Option must be closed"

  -- 表示名ではなく builtin の印に対し、一意性と標準の所属を検査する。
  for builtin in [BuiltinData.result, BuiltinData.option] do
    let entries := ds.filter (·.builtin == builtin)
    if entries.length > 1 then throw "duplicate builtin data type"
    if entries.any (·.package != "stdlib") then throw "builtin data type must belong to stdlib"

/-- 構成子名と型パラメータの位置を照合する。型・構成子の識別名は推測しない。 -/
def validateBuiltinShape (builtin : BuiltinData) (ntys : Nat) (record : Bool)
    (ctors : List (String × List (Option Nat))) : Except String Unit := do
  if builtin == .ordinary then return
  let expected := if builtin == .result then [("Ok", [some 0]), ("Error", [some 1])]
    else [("Some", [some 0]), ("None", [])]
  let params := if builtin == .result then 2 else 1
  if record || ntys != params || ctors.length != 2 ||
      expected.any (fun c => !ctors.contains c) then throw "invalid builtin constructor shape"

partial def validateConstantBody : Json → Except String Unit
  | .arr xs => xs.toList.forM validateConstantBody
  | .obj xs => xs.toArray.toList.forM fun (k,v) => do
      if ["matchE", "bind", "lastBind", "bindPat", "lastPat"].contains k then
        throw "source match/binding in constant"
      validateConstantBody v
  | _ => pure ()

/-- 解決済みの所属から Lean でも view を計算し、受け取った一覧を完全に照合する。 -/
def coverageView (ds : List DataTypeInfo) (package : String) (names : List String) :
    Except String Benitoite.Release.CoverageView := do
  validateDataTypes ds
  if package.isEmpty then throw "empty body package"
  if names.eraseDups.length != names.length then throw "duplicate coverage view type"
  for n in names do
    let some d := ds.find? (·.name == n) | throw s!"unknown coverage view type: {n}"
    if !d.extensible then throw s!"coverage view type is not extensible: {n}"
  let expected := ds.filter fun d => d.extensible && d.package != package
  if names.length != expected.length || expected.any (fun d => !names.contains d.name) then
    throw "coverage view/package mismatch"
  return fun d => names.contains d

def Input.validateViews (i : Input) : Except String Unit := do
  validateDataTypes i.dataTypes
  for c in i.constants do
    if c.package.isEmpty then throw "empty constant package"
  for d in i.definitions do
    if let .inScope s _ := d.scope then
      let _ ← coverageView i.dataTypes s.package s.coverageView

/-- 型引数の内側や定数の本体を含め、交換された data 型の識別名を漏らさない。 -/
partial def referencedData : Json → List String
  | .arr xs => xs.toList.flatMap referencedData
  | j@(.obj xs) =>
      let own := ((j.getObjVal? "data").bind (fun d => d.getObjValAs? String "name")).toOption.toList
      own ++ xs.toArray.toList.flatMap (fun (_,v) => referencedData v)
  | _ => []

def readCorpus (j : Json) : Except String Corpus := do
  let c : Corpus ← fromJson? (← exchangeJson "corpus" j)
  c.inputs.forM Input.validateViews
  if c.version >= 9 then
    for i in c.inputs do
      for constant in i.constants do
        validateConstantBody (toJson constant.body)
      for n in referencedData (toJson i) do
        if !i.dataTypes.any (·.name == n) then throw s!"missing data type metadata: {n}"
  return c
end Benitoite.Exchange
