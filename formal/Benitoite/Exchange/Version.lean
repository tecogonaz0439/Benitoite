import Benitoite.Exchange.Syntax
import Benitoite.Exchange.Observe

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

/-- 新しい欄の補完は旧版だけに行い、既存の辞書欄とは区別する。 -/
partial def batch2Defaults : Json → Json
  | .arr xs => .arr (xs.map batch2Defaults)
  | .obj xs => Id.run do
      let mut j := Json.mkObj (xs.toArray.toList.map fun (k,v) => (k,batch2Defaults v))
      if let .ok ne := j.getObjValAs? Nat "neffs" then
        j := addFields j [("effParams", toJson (List.replicate ne (EffParam.mk false)))]
      if (j.getObjVal? "op").isOk && (j.getObjVal? "arity").isOk then
        j := addFields j [("dictCount", toJson (0 : Nat)), ("failureType", Json.null)]
      j := mapField j "ops" (mapArray fun o =>
        if (o.getObjVal? "header").isOk then
          addFields o [("dictParams", toJson ([] : List (String × Nat))), ("effectKind", toJson "ordinary")]
        else o)
      j := mapField j "primOps" (mapArray fun o => addFields o [("effectKind", toJson "ordinary")])
      return j
  | j => j

/-- 旧版の操作宣言に辞書を混ぜても、既存の関数の辞書欄とは混同しない。 -/
partial def rejectBatch2 : Json → Except String Unit
  | .arr xs => xs.toList.forM rejectBatch2
  | j@(.obj xs) => do
      if (j.getObjVal? "kind").toOption == some (toJson "fail") ||
          (j.getObjVal? "op").toOption == some (toJson "fail") then
        throw "Fail requires new exchange version"
      if let .ok os := (j.getObjVal? "ops").bind Json.getArr? then
        for o in os do
          if (o.getObjVal? "header").isOk && (o.getObjVal? "dictParams").isOk then
            throw "operation dictionaries require new exchange version"
      xs.toArray.toList.forM (fun (_,v) => rejectBatch2 v)
  | _ => pure ()

/-- 行の一覧は宣言した個数と完全に対応し、真偽値以外を参照として解釈しない。 -/
partial def validateBatch2 : Json → Except String Unit
  | .arr xs => xs.toList.forM validateBatch2
  | j@(.obj xs) => do
      if let .ok ne := j.getObjValAs? Nat "neffs" then
        let rows ← (j.getObjValAs? (List EffParam) "effParams").mapError (fun e => s!"effParams/noFail: {e}")
        if rows.length != ne then throw "NoFail row count mismatch"
      if (j.getObjVal? "op").isOk && (j.getObjVal? "arity").isOk then
        let count ← (j.getObjValAs? Nat "dictCount").mapError (fun e => s!"dictCount: {e}")
        if !(← j.getObj?).contains "failureType" then throw "missing failureType"
        let failure ← (j.getObjVal? "failureType").mapError (fun e => s!"failureType: {e}")
        if failure == Json.null then
          if (← j.getObjVal? "op") == toJson "fail" then throw "Fail clause requires failureType"
        else
          let _ ← decodeTy failure
          if (← j.getObjVal? "op") != toJson "fail" || count != 0 ||
              (← j.getObjValAs? Nat "arity") != 1 || (← j.getObjValAs? Nat "ntys") != 1 then
            throw "invalid Fail clause signature"
      if (j.getObjVal? "kind").toOption == some (toJson "fail") then
        let _ ← decodeAtom j
      if let .ok os := (j.getObjVal? "ops").bind Json.getArr? then
        for o in os do
          if (o.getObjVal? "header").isOk then
            let _ ← o.getObjValAs? (List (String × Nat)) "dictParams"
            if (← o.getObjValAs? String "effectKind") != "ordinary" then
              throw "user operation must be ordinary"
      if let .ok os := (j.getObjVal? "primOps").bind Json.getArr? then
        for o in os do
          if (← o.getObjValAs? String "effectKind") != "ordinary" then
            throw "primitive operation must be ordinary"
      xs.toArray.toList.forM (fun (_,v) => validateBatch2 v)
  | _ => pure ()

/-- 比較専用の期待コアや未使用の定数も、型付けへの変換前に有界にする。
型の名前や文字列の値を整数と解釈せず、交換の Const.integer のタグだけを読む
（設計書 07-04「証明する性質」）。 -/
partial def validateIntegerConstants : Json → Except String Unit
  | .arr xs => xs.toList.forM validateIntegerConstants
  | j@(.obj xs) => do
      if let .ok value := j.getObjVal? "integer" then
        let n ← value.getObjValAs? Int "value"
        if !(Benitoite.Release.min64 ≤ n && n ≤ Benitoite.Release.max64) then
          throw "integer outside i64"
      xs.toArray.toList.forM (fun (_,v) => validateIntegerConstants v)
  | _ => pure ()

/-- 範囲を表す欄（corpus 15・sidecar 7 で加えた）。旧版の入力には置かせない。 -/
def rangeFields : List String :=
  ["ix", "ranges", "rkinds", "shape", "effKinds", "valKinds", "admitsR", "valContents", "scopeAcceptance"]

/-- 範囲の入力の検査（L50.2）。全ての範囲の位置 `ix` の範囲の変数の番号が上限 bound より小さく、閉じた範囲と範囲の
列 `ranges` の範囲が整形式で正規形であることを確かめる（一つの節点は `checkIxInput`・`checkRangeInput`）。 -/
partial def validateRanges (bound : Nat) : Json → Except String Unit
  | .arr xs => xs.toList.forM (validateRanges bound)
  | .obj xs => xs.toArray.toList.forM fun (k, v) => do
      if k == "ix" then checkIxInput bound (← decodeIxStrict v)
      if k == "ranges" then (← decodeRanges v).forM checkRangeInput
      validateRanges bound v
  | _ => pure ()

/-- Top でない範囲の数（範囲の位置の閉じた範囲と、範囲の列の要素）。比較の報告に書き、全て Top だけの入力の一致を
範囲の比較の成功に数えないための件数にする（L50.2）。 -/
partial def countNonTopRanges : Json → Nat
  | .arr xs => xs.foldl (fun n v => n + countNonTopRanges v) 0
  | .obj xs => xs.toArray.foldl (fun n (k, v) =>
      let own := if k == "ix" then (match decodeIxStrict v with | .ok (.fixed r) => if r == .top then 0 else 1 | _ => 0)
        else if k == "ranges" then (match decodeRanges v with | .ok rs => (rs.filter (· != .top)).length | _ => 0)
        else 0
      n + own + countNonTopRanges v) 0
  | _ => 0

/-- 組み込みの表の一つの入力の検査。署名の範囲の変数の番号は、その項目の `rkinds` の個数より小さい。表の `admitsR`
の規則の番号も、名前の項目の範囲の変数の個数より小さい。項目の外（エフェクトの表など）は範囲の変数を置けない。 -/
def validateBuiltinRanges (input : Json) : Except String Unit := do
  let prims ← (← input.getObjVal? "prims").getArr?
  let mut counts : List (String × Nat) := []
  for p in prims do
    let n := (← (← p.getObjVal? "rkinds").getArr?).size
    validateRanges n p
    counts := counts ++ [(← p.getObjValAs? String "name", n)]
  for e in ← (← input.getObjVal? "admitsR").getArr? do
    let name ← e.getObjValAs? String "name"
    let some (_, n) := counts.find? (·.1 == name) | throw s!"admitsR entry without a primitive: {name}"
    checkAdmitsRuleInput n (← e.getObjValAs? AdmitsRule "rule")
  match input with
  | .obj xs => xs.toArray.toList.forM fun (k, v) => if k == "prims" then pure () else validateRanges 0 v
  | _ => pure ()

/-- corpus の一つの入力の必須の判定の入力の検査。新版は欄を必須とし、パターンの範囲とホストのパターンが整形式で
正規形であることを確かめる。 -/
def validateScopeAcceptance (input : Json) : Except String Unit := do
  let raw ← input.getObjVal? "scopeAcceptance"
  if raw == Json.null then throw "missing scopeAcceptance"
  let s : ScopeAcceptanceEntry ← fromJson? raw
  s.patterns.forM fun p => checkRangeInput p.range
  s.hosts.forM fun h => checkRangeInput (.host h.pattern)

/-- 新版の入力の範囲の検査。形式ごとに範囲の変数の上限を決める（表の署名だけが項目の個数、ほかは 0）。 -/
def validateRangeInput (kind : String) (j : Json) : Except String Unit := do
  -- 入力の配列がない形（欄の誤り）は各形式の読者が拒否する。ここでは配列の要素だけを辿る。
  let inputs := ((j.getObjVal? "inputs").bind Json.getArr?).toOption.getD #[]
  if kind == "builtins" then
    for i in inputs do validateBuiltinRanges i
    match j with
    | .obj xs => xs.toArray.toList.forM fun (k, v) => if k == "inputs" then pure () else validateRanges 0 v
    | _ => pure ()
  else
    validateRanges 0 j
    if kind == "corpus" then
      for i in inputs do validateScopeAcceptance i

/-- 旧版の全ての節点に `legacyRangeNode` を当てる（子を先に変える）。名前の原子と不透明型は明示の Top の範囲の位置を、
組み込みの呼び出しは空の範囲の列を持つ。暗黙に狭い範囲としては読まない（設計書 07-04「交換の形式の版」）。 -/
partial def legacyRanges : Json → Json
  | .arr xs => .arr (xs.map legacyRanges)
  | .obj xs => legacyRangeNode (Json.mkObj (xs.toArray.toList.map fun (k, v) => (k, legacyRanges v)))
  | j => j

/-- 全ての節点に `legacyRangeNodeMissing` を当てる（子を先に変える）。 -/
partial def legacyRangesMissing : Json → Json
  | .arr xs => .arr (xs.map legacyRangesMissing)
  | .obj xs => legacyRangeNodeMissing (Json.mkObj (xs.toArray.toList.map fun (k, v) => (k, legacyRangesMissing v)))
  | j => j

/-- 旧版の組み込みの表の項目は範囲の変数を持たず（`rkinds` は空、形は対象なし）、表のデータは空である
（`Builtins` の既定の値。旧の像）。 -/
def legacyTableDefaults (kind : String) (j : Json) : Json :=
  if kind == "builtins" then
    mapField j "inputs" (mapArray fun i =>
      let i := addFields i [("effKinds", Json.arr #[]), ("valKinds", Json.arr #[]),
        ("admitsR", Json.arr #[]), ("valContents", Json.arr #[])]
      mapField i "prims" (mapArray fun p => addFields p [("rkinds", Json.arr #[]), ("shape", toJson "untargeted")]))
  else j

/-- 範囲を持たない旧版を新版の形にする。新版はこの変換を通さず、欄を必須とする。 -/
def legacyRangeDefaults (kind : String) (j : Json) : Json :=
  let j := legacyTableDefaults kind (legacyRanges j)
  -- 旧版の入力は必須の判定の入力を持たず、規則のない受理の入力（旧の像）で読む。
  if kind == "corpus" then mapField j "inputs" (mapArray fun i => addFields i [("scopeAcceptance", Json.null)]) else j

/-- corpus と sidecar の世代を独立に判定し、旧版の深い位置でも新情報を捨てない。 -/
def exchangeJson (kind : String) (j : Json) : Except String Json := do
  let version ← j.getObjValAs? Nat "version"
  let corpus := kind == "corpus"
  if !(if corpus then [8, 9, 10, 11, 12, 13, 14, 15] else [2, 3, 4, 5, 6, 7]).contains version then
    -- 契約名導入前の入力にも、既存の具体的な拒否理由を保つ。
    if version == (if corpus then 7 else 1) then
      rejectFields ["names", "labels", "positions", "fields"] j
    throw s!"unsupported {kind} exchange version: {version}"
  if version < (if corpus then 14 else 6) then
    match rejectFields ["formatted"] j with
    | .error _ => throw "formatted interpolation requires corpus 14/sidecar 6; regenerate with new version"
    | .ok _ => pure ()
  if !corpus || version < 13 then
    rejectFields ["block"] j
  if corpus && version == 12 then
    match rejectFields ["builderBind", "builderOp", "builderLet", "refs", "newRef", "getRef", "setRef"] j with
    | .error _ => throw "builder syntax requires exchange version 13; regenerate with version 13"
    | .ok _ => pure ()
  if !corpus || version < 13 then
    rejectFields ["builderBind", "builderOp", "builderLet", "localRef", "refs", "newRef", "getRef", "setRef"] j
  else
    rejectFields ["refs", "newRef", "getRef", "setRef"] j
  validateIntegerConstants j
  let ranged := version >= (if corpus then 15 else 7)
  if !ranged then rejectFields rangeFields j
  -- 範囲の変数は組み込みの表の署名にだけ置ける。プログラムと他の表の型に置かせない（設計書 01-12「構文」）。
  if ranged && kind != "builtins" then rejectFields ["rvar"] j
  -- 新版は範囲の正規形と範囲の変数の番号を確かめる（問3・問4）。
  if ranged then validateRangeInput kind j
  -- 旧版は型の読み込み（validateBatch2 など）より前に明示の Top を持たせる。
  let j := if ranged then j else legacyRangeDefaults kind j
  if corpus && version < 10 then
    rejectFields ["tryResultReturn", "tryOptionReturn", "tryResultDie", "tryOptionDie"] j
  let batch2 := version >= (if corpus then 11 else 4)
  if !batch2 then
    rejectFields ["effParams", "noFail", "dictCount", "failureType", "effectKind", "opDicts", "raise", "handleFail", "clause"] j
    rejectBatch2 j
  if version == (if corpus then 8 else 2) then
    rejectFields (["builtin", "package", "coverageView", "extensible", "isRecord", "dataTypes"] ++
      if kind == "coverage" then [] else ["typeName", "constructorName"]) j
    return batch2Defaults (closedDefaults kind j)
  if batch2 then
    validateBatch2 j
    return j
  return batch2Defaults j

/-- corpus 15はsidecar 7、14は6、13は5、11と12は4を使う。 -/
def sidecarVersion (corpusVersion : Nat) : Nat :=
  if corpusVersion >= 15 then 7 else if corpusVersion >= 14 then 6 else if corpusVersion >= 13 then 5 else if corpusVersion >= 11 then 4 else if corpusVersion >= 9 then 3 else 2

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
      if ["matchE", "bind", "lastBind", "bindPat", "lastPat", "builderBind", "builderOp"].contains k then
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
