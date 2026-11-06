import Benitoite.Exchange.Syntax
import Benitoite.Exchange.Observe

/-! # 交換の版と入力の完全性

コーパス16と付随の表8だけを読み、欄の欠落と未知の欄を拒否する。型と範囲の位置は新しい判断へ直接写す。
-/
namespace Benitoite.Exchange
open Lean Benitoite.Release.Refinement

/-- 禁止された欄を、未使用の子の中まで検査する。 -/
partial def rejectFields (keys : List String) : Json → Except String Unit
  | .arr xs => xs.toList.forM (rejectFields keys)
  | .obj xs => xs.toArray.toList.forM fun (k, v) => do
      if keys.contains k then throw s!"unsupported exchange field: {k}"
      rejectFields keys v
  | _ => pure ()

/-- 必須欄が揃い、指定した欄のほかを持たないことを確かめる。 -/
def exactFields (keys : List String) (j : Json) : Except String Unit := do
  let obj ← j.getObj?
  for k in keys do
    if !obj.contains k then throw s!"missing exchange field: {k}"
  for (k, _) in obj.toArray do
    if !keys.contains k then throw s!"unexpected exchange field: {k}"

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


/-- 書き出しの統計は既知の三分類と二つの自然数だけを持つ。 -/
def validateAnnotations (j : Json) : Except String Unit := do
  let obj ← j.getObj?
  for (kind, value) in obj.toArray do
    if !["resultMatch", "resultReturn", "tailMatch"].contains kind then
      throw s!"unknown annotation class: {kind}"
    let pair : List Nat ← fromJson? value
    if pair.length != 2 then throw "annotation count must have two elements"

/-- 型・効果・表層・期待コアの既知の構成子を、書き戻した形との一致で検査する。 -/
partial def validateSyntaxFields : Json → Except String Unit
  | .arr xs => xs.toList.forM validateSyntaxFields
  | j@(.obj xs) => do
      if let .ok annotations := j.getObjVal? "annotations" then validateAnnotations annotations
      if xs.contains "effParams" && xs.contains "tparams" && !xs.contains "rkinds" then
        exactFields ["tparams", "tparamKinds", "neffs", "effParams", "names", "params", "ret", "eff", "rangeParams", "proofSteps"] j
        let h : Header ← fromJson? j
        if h.tparams.length != h.tparamKinds.length then throw "type parameter kind count mismatch"
        if toJson h != j then throw "unexpected header fields"
      if xs.contains "definitions" && xs.contains "constants" then
        exactFields ["dataTypes", "group", "name", "excluded", "definitions", "constants", "candidates", "ops", "effects", "primOps", "classes", "impls", "scopeAcceptance", "aliases", "records", "testers", "externals", "logicCertificates"] j
        let i : Input ← fromJson? j
        LogicCertificateEntry.validate i.logicCertificates
        if toJson i != j then throw "unexpected input syntax fields"
      if xs.contains "argumentKind" && xs.contains "methods" && xs.contains "supers" then
        exactFields ["name", "argumentKind", "supers", "methods"] j
      xs.toArray.toList.forM (fun (_, v) => validateSyntaxFields v)
  | _ => pure ()

/-- 値とパターンの定数だけを i64 に制限する。論理の項と線形式の係数は数学的な整数である。 -/
private def validateIntegerConstant (j : Json) : Except String Unit := do
  if let .ok value := j.getObjVal? "integer" then
    let n ← value.getObjValAs? Int "value"
    if !(Benitoite.Release.min64 ≤ n && n ≤ Benitoite.Release.max64) then throw "integer outside i64"

partial def validateIntegerConstants : Json → Except String Unit
  | .arr xs => xs.toList.forM validateIntegerConstants
  | j@(.obj xs) => do
      if xs.toArray.size == 1 then
        for tag in ["literal", "const"] do
          if let .ok body := j.getObjVal? tag then validateIntegerConstant (← body.getObjVal? "value")
        if let .ok body := j.getObjVal? "range" then
          validateIntegerConstant (← body.getObjVal? "lo")
          validateIntegerConstant (← body.getObjVal? "hi")
      xs.toArray.toList.forM (fun (_, v) => validateIntegerConstants v)
  | _ => pure ()

/-- 範囲の位置・宣言・実引数と、表のデータの欄。 -/
def rangeFields : List String :=
  ["ix", "ranges", "rkinds", "rangeParams", "shape", "effKinds", "valKinds", "admitsR", "valContents", "scopeAcceptance"]

/-- 記号付きの範囲も、実行時の環境を読む前に構文の整形式と正規形を検査する。 -/
def checkRefinedRangeInput (range : RangeExpr) : Except String Unit :=
  if range.WF ∧ range.Canonical then .ok () else .error "range is not well-formed and canonical"

def checkRefinedIxInput (depth : Nat) : RangeIx → Except String Unit
  | .fixed range => checkRefinedRangeInput range
  | .rvar i => if i < depth then .ok () else .error "range variable outside declaration"

theorem checkRefinedRangeInput_sound {range : RangeExpr}
    (h : checkRefinedRangeInput range = .ok ()) : range.WF ∧ range.Canonical := by
  unfold checkRefinedRangeInput at h
  split at h
  · assumption
  · cases h

/-- 成功した位置は宣言の深さに収まり、固定の範囲は同じ構文の検査を通っている。 -/
theorem checkRefinedIxInput_sound {depth ix} (h : checkRefinedIxInput depth ix = .ok ()) :
    ix.WF depth ∧ ∀ range, ix = .fixed range → range.WF ∧ range.Canonical := by
  cases ix with
  | fixed range =>
      refine ⟨trivial, ?_⟩
      intro r hr
      cases hr
      exact checkRefinedRangeInput_sound h
  | rvar i =>
      simp only [checkRefinedIxInput] at h
      split at h
      · exact ⟨‹i < depth›, fun _ h => by cases h⟩
      · cases h

/-- 宣言した範囲の文脈を本体へ渡し、全ての範囲の位置と実引数を同じ深さで検査する。 -/
partial def validateRanges (bound : Nat) : Json → Except String Unit
  | .arr xs => xs.toList.forM (validateRanges bound)
  | j@(.obj xs) => do
      let own := ((j.getObjVal? "rangeParams").bind Json.getArr?).toOption.map (·.size)
      let own := own.or (((j.getObjVal? "rkinds").bind Json.getArr?).toOption.map (·.size))
      let own := own.or (((j.getObjVal? "header").bind (fun h => h.getObjVal? "rangeParams") >>= Json.getArr?).toOption.map (·.size))
      let depth := own.getD bound
      if let .ok member := j.getObjVal? "member" then
        checkRefinedRangeInput (← member.getObjValAs? RangeExpr "range")
      xs.toArray.toList.forM fun (k, v) => do
        if k == "ix" then checkRefinedIxInput depth (← decodeRefinedIxStrict v)
        if k == "ranges" then
          let rs : List RangeIx ← fromJson? v
          rs.forM (checkRefinedIxInput depth)
        validateRanges depth v
  | _ => pure ()

/-- Top 以外の固定の範囲と範囲変数の出現数。 -/
partial def countNonTopRanges : Json → Nat
  | .arr xs => xs.foldl (fun n v => n + countNonTopRanges v) 0
  | .obj xs => xs.toArray.foldl (fun n (k, v) =>
      let own := if k == "ix" then (match decodeRefinedIxStrict v with | .ok (.fixed .top) => 0 | .ok _ => 1 | _ => 0)
        else if k == "ranges" then (match (fromJson? v : Except String (List RangeIx)) with
          | .ok rs => (rs.filter (fun r => r != .fixed .top)).length | _ => 0)
        else 0
      n + own + countNonTopRanges v) 0
  | _ => 0

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

def validateScopeAcceptance (input : Json) : Except String Unit := do
  let raw ← input.getObjVal? "scopeAcceptance"
  if raw == Json.null then throw "missing scopeAcceptance"
  let s : ScopeAcceptanceEntry ← fromJson? raw
  s.patterns.forM fun p => checkRangeInput p.range
  s.hosts.forM fun h => checkRangeInput (.host h.pattern)

def validateRangeInput (kind : String) (j : Json) : Except String Unit := do
  let inputs := ((j.getObjVal? "inputs").bind Json.getArr?).toOption.getD #[]
  if kind == "builtins" then
    for i in inputs do validateBuiltinRanges i
  else
    validateRanges 0 j
    if kind == "corpus" then
      for i in inputs do validateScopeAcceptance i

/-- 入力の種類ごとに同じ新版だけを受ける。旧版と未知の版は変換せず拒否する。 -/
def exchangeJson (kind : String) (j : Json) : Except String Json := do
  let version ← j.getObjValAs? Nat "version"
  let expected : Nat := if kind == "corpus" then 16 else 8
  if version != expected then throw s!"unsupported {kind} exchange version: {version}; regenerate with version {expected}"
  let fields ← match kind with
    | "corpus" => pure ["version", "operators", "inputs"]
    | "builtins" | "stdlib" | "coverage-program" => pure ["version", "inputs"]
    | "coverage" => pure ["version", "seedXor", "randomCases", "boundaryCases", "kinds", "cases"]
    | _ => throw s!"unknown exchange kind: {kind}"
  let optional := if kind == "coverage" then ["budget"] else if kind == "corpus" then ["annotations"] else []
  let obj ← j.getObj?
  for k in fields do
    if !obj.contains k then throw s!"missing exchange field: {k}"
  for (k, _) in obj.toArray do
    if !(fields ++ optional).contains k then throw s!"unexpected exchange field: {k}"
  rejectFields ["refs", "newRef", "getRef", "setRef"] j
  validateBatch2 j
  validateSyntaxFields j
  validateIntegerConstants j
  validateRangeInput kind j
  return j

/-- コーパス16と付随の表8を一組として用いる。 -/
def sidecarVersion (_corpusVersion : Nat) : Nat := 8

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
  for i in c.inputs do
    for constant in i.constants do
      validateConstantBody (toJson constant.body)
    for n in referencedData (toJson i) do
      if !i.dataTypes.any (·.name == n) then throw s!"missing data type metadata: {n}"
  return c
end Benitoite.Exchange
