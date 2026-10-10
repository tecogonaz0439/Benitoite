import Benitoite.Exchange.Convert

open Lean Benitoite.Exchange

structure Counts where
  matched : Nat := 0
  mismatched : Nat := 0
  knownMismatched : Nat := 0
  outside : Nat := 0
  excluded : Nat := 0
  deriving ToJson

structure Summary where
  programs : Counts := {}
  definitions : Counts := {}
  elements : List (String × Nat) := []
  programElements : List (String × Nat) := []
  constructions : List (String × Nat) := []
  constructionUnits : List (String × Nat) := []
  knownDifferences : List (String × Nat) := []
  deriving ToJson

def increment (entries : List (String × Nat)) (name : String) : List (String × Nat) :=
  if entries.any (fun p => p.1 == name) then
    entries.map fun (n, k) => (n, if n == name then k + 1 else k)
  else entries ++ [(name, 1)]

/-- 辞書の local を普通の式の local と分けて数える。 -/
partial def dictionaryFeatures (j : Json) : List String :=
  match (fromJson? j : Except String DictEv) with
  | .ok (.local _) => ["DictEv.local"]
  | .ok (.super d _) => "DictEv.super" :: dictionaryFeatures (toJson d)
  | .ok (.impl _ _ ds) => "DictEv.impl" :: ds.flatMap (fun d => dictionaryFeatures (toJson d))
  | .error _ => []

partial def expressionFeatures : Json → List String
  | .arr xs => xs.toList.flatMap expressionFeatures
  | j@(.obj xs) =>
      let own := if let .ok f := j.getObjVal? "funDicts" then
          let ds := ((f.getObjVal? "dicts").toOption.bind (fun j => j.getArr?.toOption)).getD #[]
          ["funDicts"] ++ ds.toList.flatMap dictionaryFeatures
        else []
      let method := if let .ok m := j.getObjVal? "methName" then
          let ds := ((m.getObjVal? "dicts").toOption.bind (fun j => j.getArr?.toOption)).getD #[]
          [if ds.isEmpty then "methName: empty U" else "methName: nonempty U"] ++
            dictionaryFeatures ((m.getObjVal? "dict").toOption.getD Json.null) ++ ds.toList.flatMap dictionaryFeatures
        else []
      own ++ method ++ xs.toArray.toList.flatMap (fun (_,v) => expressionFeatures v)
  | _ => []

/-- 呼び出しの形は親のパイプを見て分類する。規則 1 の右辺を通常の call に重ねない。
括弧の有無と Ū の空・非空は、コアから推測せず表層の頭から数える。 -/
partial def headFeature (head : Json) (form : String) (paren : Bool := false) : List String :=
  if let .ok p := head.getObjVal? "paren" then
    headFeature ((p.getObjVal? "inner").toOption.getD Json.null) form true
  else
    let kind := if (head.getObjVal? "funDicts").isOk then some "funDicts"
      else if let .ok m := head.getObjVal? "methName" then
        let ds := ((m.getObjVal? "dicts").toOption.bind (fun j => j.getArr?.toOption)).getD #[]
        some (if ds.isEmpty then "methName: empty U" else "methName: nonempty U")
      else none
    match kind with
    | none => []
    | some k => [k ++ (if paren then " parenthesized: " else " direct: ") ++ form]

partial def callFeatures (j : Json) (pipeRhs : Bool := false) : List String :=
  match j with
  | .arr xs => xs.toList.flatMap (fun x => callFeatures x)
  | .obj xs =>
      if let .ok p := j.getObjVal? "pipe" then
        let lhs := (p.getObjVal? "lhs").toOption.getD Json.null
        let rhs := (p.getObjVal? "rhs").toOption.getD Json.null
        let feature := if let .ok c := rhs.getObjVal? "call" then
            headFeature ((c.getObjVal? "callee").toOption.getD Json.null) "pipe rule 1"
          else if let .ok c := rhs.getObjVal? "partialCall" then
            headFeature ((c.getObjVal? "callee").toOption.getD Json.null) "placeholder pipe rule 2"
          else headFeature rhs "pipe rule 2"
        feature ++ callFeatures lhs ++ callFeatures rhs true
      else
        let own := if let .ok c := j.getObjVal? "partialCall" then
            headFeature ((c.getObjVal? "callee").toOption.getD Json.null) "placeholder"
          else if let .ok c := j.getObjVal? "call" then
            if pipeRhs then [] else
              headFeature ((c.getObjVal? "callee").toOption.getD Json.null) "call"
          else []
        own ++ xs.toArray.toList.flatMap (fun (_,v) => callFeatures v)
  | _ => []

/-- C6 の件数は比較した定義の表層から数える。空の text は有効な部分に数えない。 -/
def extensionNames : List String := [
  "guard", "alternatives", "alternative", "alternative: reordered binders", "guarded alternatives",
  "range pattern", "range pattern: negative Integer", "range pattern: Character",
  "list pattern: no rest", "list pattern: skip", "list pattern: bind", "list pattern: suffix",
  "list pattern binding",
  "constant reference", "constant: basic", "constant: list", "constant: record",
  "constant: data", "constant: nested", "constant: call argument", "constant: constructor field",
  "constant: list element", "constant: lambda", "constant: record update base",
  "constant: under local binding",
  "Decimal literal", "Decimal direct negation", "Decimal direct negative zero",
  "spread: first", "spread: middle", "spread: last",
  "spread: before empty", "spread: after empty", "spread: both empty",
  "interpolation", "interpolation: text", "interpolation: empty text",
  "interpolation: String", "interpolation: Integer", "interpolation: Float",
  "interpolation: Character", "interpolation: Boolean", "interpolation: Byte",
  "interpolation: Decimal", "interpolation: consecutive expressions",
  "interpolation: parts 0", "interpolation: parts 1", "interpolation: parts 2+",
  "record construction", "record construction: reordered",
  "record update: partial", "record update: all", "record update: reordered",
  "record pattern", "record pattern: partial", "record pattern: nested", "record pattern: reordered",
  "accessor definition", "accessor definition: polymorphic",
  "accessor direct: call", "accessor parenthesized: call",
  "accessor direct: pipe rule 1", "accessor parenthesized: pipe rule 1",
  "accessor direct: pipe rule 2", "accessor parenthesized: pipe rule 2",
  "accessor direct: placeholder", "accessor parenthesized: placeholder",
  "accessor direct: placeholder pipe rule 2", "accessor parenthesized: placeholder pipe rule 2",
  "accessor parenthesized value" ]

partial def extensionFeatures : Json → List String
  | .arr xs => xs.toList.flatMap extensionFeatures
  | j@(.obj xs) => Id.run do
      let mut own := []
      if let .ok l := j.getObjVal? "literal" then
        if ((l.getObjVal? "value").bind (fun v => v.getObjVal? "decimal")).isOk then
          own := own ++ ["Decimal literal"]
      if let .ok n := j.getObjVal? "negDecimal" then
        own := own ++ ["Decimal direct negation"]
        if (n.getObjVal? "mantissa").toOption == some (toJson (0 : Int)) then
          own := own ++ ["Decimal direct negative zero"]
      if let .ok s := j.getObjVal? "listSpread" then
        let before := ((s.getObjVal? "before").bind Json.getArr?).toOption.getD #[]
        let after := ((s.getObjVal? "after").bind Json.getArr?).toOption.getD #[]
        if before.isEmpty && after.isEmpty then own := own ++ ["spread: both empty"]
        else if before.isEmpty then own := own ++ ["spread: first", "spread: before empty"]
        else if after.isEmpty then own := own ++ ["spread: last", "spread: after empty"]
        else own := own ++ ["spread: middle"]
      if let .ok i := j.getObjVal? "interpolation" then
        own := own ++ ["interpolation"]
        let ps := ((i.getObjVal? "parts").bind (fun j => (fromJson? j : Except String (List InterpPart)))).toOption.getD []
        let mut count := 0
        let mut previousExpr := false
        for p in ps do
          match p with
          | .text s =>
              own := own ++ [if s.isEmpty then "interpolation: empty text" else "interpolation: text"]
              if !s.isEmpty then
                count := count + 1
                previousExpr := false
          | .stringExpr | .converted _ =>
              count := count + 1
              if previousExpr then own := own ++ ["interpolation: consecutive expressions"]
              previousExpr := true
              own := own ++ [match p with
                | .stringExpr => "interpolation: String"
                | .converted (.base n) => "interpolation: " ++ n
                | _ => "interpolation: invalid type"]
        own := own ++ [if count == 0 then "interpolation: parts 0"
          else if count == 1 then "interpolation: parts 1" else "interpolation: parts 2+"]
        if count >= 2 then own := own ++ [s!"interpolation: parts {count}"]
      return own ++ xs.toArray.toList.flatMap (fun (_,v) => extensionFeatures v)
  | _ => []

/-- レコードの位置は書いた順。入れ子はレコードの子のパターン内にあるものを数える。 -/
partial def recordFeatures (j : Json) (insidePattern : Bool := false) : List String :=
  match j with
  | .arr xs => xs.toList.flatMap (fun x => recordFeatures x insidePattern)
  | .obj xs => Id.run do
      let mut own := []
      let mut pattern := false
      if let .ok r := j.getObjVal? "record" then
        let positions := ((r.getObjVal? "positions").bind (fun j => (fromJson? j : Except String (List Nat)))).toOption.getD []
        let reordered := positions != positions.mergeSort (· ≤ ·)
        if (r.getObjVal? "tys").isOk then
          own := ["record construction"] ++ (if reordered then ["record construction: reordered"] else [])
        else
          pattern := true
          let n := ((r.getObjVal? "n").bind (fun j => (fromJson? j : Except String Nat))).toOption.getD 0
          own := ["record pattern"] ++ (if insidePattern then ["record pattern: nested"] else []) ++
            (if positions.length < n then ["record pattern: partial"] else []) ++
            (if reordered then ["record pattern: reordered"] else [])
      if let .ok r := j.getObjVal? "recordUpdate" then
        let positions := ((r.getObjVal? "positions").bind (fun j => (fromJson? j : Except String (List Nat)))).toOption.getD []
        let n := ((r.getObjVal? "n").bind (fun j => (fromJson? j : Except String Nat))).toOption.getD 0
        own := [if positions.length == n then "record update: all" else "record update: partial"] ++
          (if positions != positions.mergeSort (· ≤ ·) then ["record update: reordered"] else [])
      return own ++ xs.toArray.toList.flatMap (fun (_,v) => recordFeatures v (insidePattern || pattern))
  | _ => []

/-- パターンには式がない。各選択肢の子も一度ずつ数え、ガードを複製しない。 -/
partial def patternFeatures (j : Json) : List String :=
  match j with
  | .arr xs => xs.toList.flatMap patternFeatures
  | .obj xs => Id.run do
      let mut own := []
      if let .ok r := j.getObjVal? "range" then
        own := ["range pattern"]
        let lo := (r.getObjVal? "lo").toOption.getD Json.null
        let hi := (r.getObjVal? "hi").toOption.getD Json.null
        if (lo.getObjVal? "character").isOk then own := own ++ ["range pattern: Character"]
        let negative := fun c => (((c.getObjVal? "integer").bind (fun i => i.getObjVal? "value")).bind
          (fun v => (fromJson? v : Except String Int))).toOption.getD 0 < 0
        if negative lo && negative hi then own := own ++ ["range pattern: negative Integer"]
      if let .ok l := j.getObjVal? "list" then
        if (l.getObjVal? "before").isOk then
          let rest := (l.getObjVal? "rest").toOption.getD Json.null
          own := own ++ [if rest == Json.null then "list pattern: no rest"
            else if rest == toJson "skip" then "list pattern: skip" else "list pattern: bind"]
          let after := ((l.getObjVal? "after").bind Json.getArr?).toOption.getD #[]
          if !after.isEmpty then own := own ++ ["list pattern: suffix"]
      return own ++ xs.toArray.toList.flatMap (fun (_,v) => patternFeatures v)
  | _ => []

partial def matchFeatures (j : Json) : List String :=
  match j with
  | .arr xs => xs.toList.flatMap matchFeatures
  | .obj xs => Id.run do
      let mut own := []
      if let .ok m := j.getObjVal? "mk" then
        if let .ok alts := (m.getObjVal? "alts").bind Json.getArr? then
          let guard := (m.getObjVal? "guard").toOption.getD Json.null
          if guard != Json.null then own := own ++ ["guard"]
          if alts.size > 1 then
            own := own ++ ["alternatives"]
            if guard != Json.null then own := own ++ ["guarded alternatives"]
            for a in alts do
              own := own ++ ["alternative"]
              let slots := ((a.getObjVal? "slots").bind (fun j => (fromJson? j : Except String (List Nat)))).toOption.getD []
              if slots != List.range slots.length then own := own ++ ["alternative: reordered binders"]
      for tag in ["lastPat", "bindPat"] do
        if let .ok b := j.getObjVal? tag then
          if ((b.getObjVal? "pattern").bind (fun p => p.getObjVal? "list")).isOk then
            own := own ++ ["list pattern binding"]
      return own ++ xs.toArray.toList.flatMap (fun (_,v) => matchFeatures v)
  | _ => []

/-- 比較する利用者の取得関数名だけを判定に使う。標準ライブラリの宣言は要らない。 -/
partial def accessorHeadFeature (names : List String) (head : Json) (form : String)
    (paren : Bool := false) : List String :=
  if let .ok p := head.getObjVal? "paren" then
    accessorHeadFeature names ((p.getObjVal? "inner").toOption.getD Json.null) form true
  else if let .ok f := head.getObjVal? "funName" then
    let name := ((f.getObjVal? "name").bind Json.getStr?).toOption.getD ""
    if names.contains name then ["accessor" ++ (if paren then " parenthesized: " else " direct: ") ++ form] else []
  else []

partial def accessorCallFeatures (names : List String) (j : Json) (pipeRhs : Bool := false) : List String :=
  match j with
  | .arr xs => xs.toList.flatMap (fun x => accessorCallFeatures names x)
  | .obj xs =>
      if let .ok p := j.getObjVal? "pipe" then
        let lhs := (p.getObjVal? "lhs").toOption.getD Json.null
        let rhs := (p.getObjVal? "rhs").toOption.getD Json.null
        let feature := if let .ok c := rhs.getObjVal? "call" then
            accessorHeadFeature names ((c.getObjVal? "callee").toOption.getD Json.null) "pipe rule 1"
          else if let .ok c := rhs.getObjVal? "partialCall" then
            accessorHeadFeature names ((c.getObjVal? "callee").toOption.getD Json.null) "placeholder pipe rule 2"
          else accessorHeadFeature names rhs "pipe rule 2"
        feature ++ accessorCallFeatures names lhs ++ accessorCallFeatures names rhs true
      else
        let own := if let .ok c := j.getObjVal? "partialCall" then
            accessorHeadFeature names ((c.getObjVal? "callee").toOption.getD Json.null) "placeholder"
          else if let .ok c := j.getObjVal? "call" then
            if pipeRhs then [] else accessorHeadFeature names ((c.getObjVal? "callee").toOption.getD Json.null) "call"
          else if (j.getObjVal? "paren").isOk && !(accessorHeadFeature names j "value").isEmpty then
            ["accessor parenthesized value"]
          else []
        own ++ xs.toArray.toList.flatMap (fun (_,v) => accessorCallFeatures names v)
  | _ => []

/-- data 型の定数をレコードと区別する。別名は同じ表を辿る。 -/
partial def isRecordConstant (table : List ConstantEntry) : Benitoite.Exchange.Expr → Bool
  | .record .. => true
  | .paren e => isRecordConstant table e
  | .constName n => ((table.find? (fun e => e.name == n)).map (fun e => isRecordConstant table e.body)).getD false
  | _ => false

/-- 箇所は参照を展開した表層に対応する。閉じた本体へ使用位置の文脈を渡さない。
位置の分類は祖先の構成に基づくため、複数の分類が重なる。 -/
partial def constantFeatures (table : List ConstantEntry) (j : Json)
    (contexts : List String := []) (nested : Bool := false) : List String :=
  match j with
  | .arr xs => xs.toList.flatMap (fun x => constantFeatures table x contexts nested)
  | .obj xs =>
      if let .ok o := j.getObjVal? "constName" then
        let name := ((o.getObjVal? "name").bind Json.getStr?).toOption.getD ""
        match table.find? (fun e => e.name == name) with
        | none => [] -- constantCache と変換が欠けた定義をエラーにする。
        | some e =>
            ["constant reference", match e.ty with
              | .base _ => "constant: basic" | .list _ => "constant: list"
              | .data .. => if isRecordConstant table e.body then "constant: record" else "constant: data" | _ => "constant: other type"] ++
            (if nested then ["constant: nested"] else []) ++ contexts.eraseDups ++
            constantFeatures table (toJson e.body) [] true
      else xs.toArray.toList.flatMap fun (tag, value) =>
        let fields := value.getObj?.toOption.map (fun fs => fs.toArray.toList)
        match fields with
        | none => constantFeatures table value contexts nested
        | some fields => fields.flatMap fun (field, child) =>
            let extra := if tag == "lam" && field == "body" then ["constant: lambda"]
              else if ["bind", "bindPat"].contains tag && field == "rest" then ["constant: under local binding"]
              else if ["call", "partialCall"].contains tag && field == "args" then ["constant: call argument"]
              else if ["conCall", "partialCon", "record", "recordUpdate"].contains tag && field == "args" then ["constant: constructor field"]
              else if tag == "list" && field == "elems" then ["constant: list element"]
              else if tag == "recordUpdate" && field == "base" then ["constant: record update base"]
              else []
            constantFeatures table child (contexts ++ extra) nested
  | _ => []

def surfaceFeatures (accessors : List String) (d : SurfaceDef) : List String :=
  patternFeatures (toJson d.body) ++ matchFeatures (toJson d.body) ++ recordFeatures (toJson d.body) ++ accessorCallFeatures accessors (toJson d.body) ++
  expressionFeatures (toJson d.body) ++ callFeatures (toJson d.body) ++ extensionFeatures (toJson d.body) ++
    d.supers.flatMap (fun (_,e) => "implementation superclass dictionary" :: dictionaryFeatures (toJson e)) ++
    (if d.implementation.isSome then
      if d.method.isSome then ["implementation method"] else ["implementation supers unit"]
     else [])

/-- 最初の差の場所と、差のある最小の JSON 部分木。完全な項は corpus.json にある。 -/
partial def difference (path : String) (expected actual : Json) : Option (String × Json × Json) :=
  if expected == actual then none else
  match expected, actual with
  | .arr es, .arr as =>
      if es.size != as.size then some (path ++ ".length", toJson es.size, toJson as.size)
      else (List.range es.size).findSome? (fun i => difference s!"{path}[{i}]" es[i]! as[i]!)
  | .obj es, .obj as =>
      let keys := (es.toArray.toList.map Prod.fst ++ as.toArray.toList.map Prod.fst).eraseDups
      keys.findSome? fun key =>
        let e := expected.getObjVal? key
        let a := actual.getObjVal? key
        match e, a with
        | .ok e, .ok a => difference (path ++ "." ++ key) e a
        | _, _ => some (path, expected, actual)
  | _, _ => some (path, expected, actual)

structure Mismatch where
  group : String
  input : String
  definition : String
  path : String
  expected : Json
  actual : Json
  expectedDefinition : CoreDef
  actualDefinition : CoreDef
  knownDifferences : List String
  deriving ToJson

def compareInput (atoms : Eff) (operators : List OperatorEntry) (input : Input)
    (summary : Summary) : Except String (Summary × List Mismatch) := do
  let mut s := summary
  let mut failures := []
  let mut outsideElements : List String := []
  let mut anyOutside := input.definitions.isEmpty
  if !input.excluded.isEmpty then
    if !input.definitions.isEmpty then throw "excluded input has definitions"
    return ({ s with programs.excluded := s.programs.excluded + 1 }, [])
  if input.definitions.isEmpty then outsideElements := ["no user function"]
  let operationProgram ← input.operationProgram
  let constants ← input.constantCache
  for e in input.constants do
    validateClauses operationProgram input.primOps (toJson e.body)
  let names := input.definitions.filterMap (fun d => match d.scope with
    | .accessor name _ _ _ _ => some name | _ => none)
  for d in input.definitions do
    if d.knownDifferences.eraseDups != d.knownDifferences ||
        d.knownDifferences.any (fun k => k != "ガードの中の resume（TODO-190）") then
      throw "invalid known-difference classification"
    match d.scope with
    | .outOfScope elements =>
        if elements.isEmpty then throw "outOfScope without a reason"
        anyOutside := true
        s := { s with definitions.outside := s.definitions.outside + 1 }
        for e in elements do
          s := { s with elements := increment s.elements e }
          if !outsideElements.contains e then outsideElements := outsideElements ++ [e]
    | scope =>
        let (features, expected, core) ← match scope with
          | .inScope surface core => do
              validateClauses operationProgram input.primOps (toJson surface)
              pure (surfaceFeatures names surface ++ constantFeatures input.constants (toJson surface.body),
                ← desugar atoms operators operationProgram surface constants input.constants, core)
          | .accessor name con k decl core => do
              pure (["accessor definition"] ++ (if decl.ntys > 0 then ["accessor definition: polymorphic"] else []),
                ← desugarAccessor atoms operators operationProgram name con k decl, core)
          | .outOfScope _ => throw "unexpected outOfScope"
        for f in features do
          s := { s with constructions := increment s.constructions f }
        for f in features.eraseDups do
          s := { s with constructionUnits := increment s.constructionUnits f }
        let expectedJson := canonicalJson atoms (toJson expected)
        let actualJson := canonicalJson atoms (toJson core)
        if let some (path, e, a) := difference "definition" expectedJson actualJson then
          failures := failures ++ [{
            group := input.group
            input := input.name
            definition := d.name
            path := path
            expected := e
            actual := a
            expectedDefinition := expected
            actualDefinition := core
            knownDifferences := d.knownDifferences }]
          if d.knownDifferences.isEmpty then
            s := { s with definitions.mismatched := s.definitions.mismatched + 1 }
          else
            s := { s with definitions.knownMismatched := s.definitions.knownMismatched + 1 }
          for k in d.knownDifferences do
            s := { s with knownDifferences := increment s.knownDifferences (k ++ ": mismatched") }
        else
          s := { s with definitions.matched := s.definitions.matched + 1 }
          for k in d.knownDifferences do
            s := { s with knownDifferences := increment s.knownDifferences (k ++ ": matched") }
  for e in outsideElements do
    s := { s with programElements := increment s.programElements e }
  if failures.any (fun f => f.knownDifferences.isEmpty) then s := { s with programs.mismatched := s.programs.mismatched + 1 }
  else if !failures.isEmpty then s := { s with programs.knownMismatched := s.programs.knownMismatched + 1 }
  else if anyOutside then s := { s with programs.outside := s.programs.outside + 1 }
  else s := { s with programs.matched := s.programs.matched + 1 }
  return (s, failures)

def printCounts (label : String) (c : Counts) : IO Unit :=
  IO.println s!"{label}: matched={c.matched} mismatched={c.mismatched} knownMismatched={c.knownMismatched} outOfScope={c.outside} excluded(check error)={c.excluded}"

def printSummary (group : String) (s : Summary) : IO Unit := do
  printCounts (group ++ " programs") s.programs
  printCounts (group ++ " functions") s.definitions
  for (name, count) in s.knownDifferences do
    IO.println s!"{group} known difference: {name}: functions={count}"
  for (name, count) in s.constructions do
    IO.println s!"{group} compared construction: {name}: positions={count}, units={(s.constructionUnits.find? (fun p => p.1 == name)).map Prod.snd |>.getD 0}"
  for (name, count) in s.elements do
    IO.println s!"{group} outOfScope element: {name}: functions={count}, programs={(s.programElements.find? (fun p => p.1 == name)).map Prod.snd |>.getD 0}"
  if s.programElements.any (fun p => p.1 == "no user function") then
    IO.println s!"{group} outOfScope element: no user function: functions=0, programs={(s.programElements.find? (fun p => p.1 == "no user function")).map Prod.snd |>.getD 0}"

def run (args : List String) : IO UInt32 := do
  let [file, report] := args | throw (IO.userError "usage: desugarDiff corpus.json report.json")
  let raw ← IO.FS.readFile file
  let json ← IO.ofExcept (Json.parse raw)
  let corpus ← IO.ofExcept (fromJson? json : Except String Corpus)
  if corpus.version != 7 then throw (IO.userError "unsupported exchange version")
  let atoms := (collectAtoms json).eraseDups
  let initial : Summary := {
    knownDifferences := [("ガードの中の resume（TODO-190）: matched", 0), ("ガードの中の resume（TODO-190）: mismatched", 0)]
    constructions := extensionNames.map (fun n => (n, 0))
    constructionUnits := extensionNames.map (fun n => (n, 0)) }
  let mut golden := initial
  let mut random := initial
  let mut mismatches : List Mismatch := []
  for input in corpus.inputs do
    if input.group != "golden" && input.group != "random" then throw (IO.userError "unknown corpus group")
    let summary := if input.group == "golden" then golden else random
    let (updated, failures) ← IO.ofExcept (compareInput atoms corpus.operators input summary)
    if input.group == "golden" then golden := updated else random := updated
    mismatches := mismatches ++ failures
  printSummary "golden" golden
  printSummary "random" random
  for m in mismatches do
    IO.println s!"mismatch: {m.group}/{m.input}: {m.definition}: {m.path}"
  IO.FS.writeFile report ((Json.mkObj [("golden", toJson golden), ("random", toJson random),
    ("mismatches", toJson mismatches)]).pretty ++ "\n")
  return if mismatches.all (fun f => !f.knownDifferences.isEmpty) then 0 else 1

def main (args : List String) : IO UInt32 := do
  try run args catch e =>
    (← IO.getStderr).putStrLn s!"desugarDiff: {e}"
    return 2
