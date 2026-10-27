import Benitoite.Interval.Exchange

/-!
# interval-corpus の読者の正負例

生の JSON から本体・型・番号・期待結果までを読む境界で検査する。
期待結果の解析との一致は実行器の責務であり、この例では読み取った値を確認する。
（設計書 07-04「区間解析の独立交換の読者」）。
-/
namespace Benitoite.Interval.Exchange
open Lean Benitoite.Release

private def sample : String := r#"{
  "kind":"interval-corpus", "version":1, "surfaceVersion":14,
  "traversalVersion":1, "profile":"base",
  "inputs":[{
    "name":"division", "fuel":"100",
    "limits":{"body":{"operations":"100000","items":"100000"},
              "whole":{"operations":"1000000","items":"1000000"}},
    "initial":{"body":{"operations":"0","temporary":"0","saved":"0","peak":"0"},
               "whole":{"operations":"0","saved":"0","peak":"0"}},
    "constants":[], "standards":[], "apiAt":[],
    "modules":[{"name":"Main", "definitions":[{
      "name":"Main.divide", "kind":"function", "params":[],
      "type":{"base":{"name":"Integer"}},
      "body":{"last":{"expr":{"paren":{"inner":{"binary":{
        "op":"intDiv", "operand":{"base":{"name":"Integer"}},
        "lhs":{"literal":{"value":{"integer":{"value":8}}}},
        "rhs":{"literal":{"value":{"integer":{"value":0}}}}
      }}}}}},
      "types":[
        {"key":["Main.divide","0"],"type":{"base":{"name":"Integer"}}},
        {"key":["Main.divide","1"],"type":{"base":{"name":"Integer"}}},
        {"key":["Main.divide","2"],"type":{"base":{"name":"Integer"}}},
        {"key":["Main.divide","3"],"type":{"base":{"name":"Integer"}}},
        {"key":["Main.divide","4"],"type":{"base":{"name":"Integer"}}}
      ],
      "sourceKeys":[["Main.divide","2"]],
      "expected":{
        "integer":"top", "boolean":[false,false], "other":false,"mayFail":true,
        "warnings":[{"key":["Main.divide","2"],
          "operation":{"binary":"intDiv","type":{"base":{"name":"Integer"}}},
          "cause":"zeroDivisor"}],
        "coverage":"complete",
        "after":{"body":{"operations":"0","temporary":"0","saved":"0","peak":"0"},
                 "whole":{"operations":"0","saved":"0","peak":"0"}}
      }
    }]}]
  }]
}"#

-- 深いパスの編集に失敗した例を「拒否された入力」に数えない。
private def replaceAt : List String → Json → Json → Option Json
  | [], value, _ => some value
  | key :: rest, value, .obj fields => do
      let previous ← fields[key]?
      let next ← replaceAt rest value previous
      pure (Json.mkObj (fields.toArray.toList.map fun (k,v) => (k, if k == key then next else v)))
  | key :: rest, value, .arr values => do
      let index ← key.toNat?
      let previous ← values[index]?
      let next ← replaceAt rest value previous
      pure (.arr (values.set! index next))
  | _, _, _ => none

private def inputPath := ["inputs", "0"]
private def modulePath := inputPath ++ ["modules", "0"]
private def definitionPath := modulePath ++ ["definitions", "0"]
private def binaryPath := definitionPath ++ ["body", "last", "expr", "paren", "inner", "binary"]
private def expectedPath := definitionPath ++ ["expected"]

private def changed (path : List String) (value : Json) : Option String := do
  let original ← (UniqueJson.parse sample).toOption
  pure (← replaceAt path value original).compress

private def rejected (path : List String) (value : Json) : Bool :=
  (changed path value).any fun raw => !(readCorpus raw).isOk

-- 値・順序・数学上の番号を固定の期待値で確認し、解析結果から作らない。
#guard match readCorpus sample with
  | .error _ => false
  | .ok corpus => match corpus.inputs with
    | [input] => match input.modules with
      | [module] => match module.definitions with
        | [definition] => input.name == "division" && input.fuel == 100 &&
            definition.input.name == "Main.divide" && definition.types.length == 5 &&
            definition.sourceKeys.map (·.surfacePreorder) == [2] &&
            match definition.expected with
            | .analyzed expected => expected.integer == top && expected.mayFail &&
                expected.warnings.map (·.key.surfacePreorder) == [2]
            | .notAnalyzed _ => false
        | _ => false
      | _ => false
    | _ => false

-- 端点は i64 の両端を正確に保持し、予算と番号の復号はホスト幅で制限しない。
#guard (changed (expectedPath ++ ["integer"])
  (Json.mkObj [("closed", toJson (["-9223372036854775808", "9223372036854775807"] : List String))])).any
  fun raw => match readCorpus raw with
    | .ok ⟨[⟨_, _, _, _, _, [⟨_, [definition]⟩], _, _⟩], _⟩ =>
        match definition.expected with
          | .analyzed expected => match expected.integer with
            | .closed lo hi _ => lo == min64 && hi == max64
            | _ => false
          | .notAnalyzed _ => false
    | _ => false
#guard (decimalNat (toJson "184467440737095516160000000000000000000")).toOption ==
  some 184467440737095516160000000000000000000
#guard (readKey (toJson ([toJson "Main.divide", toJson "18446744073709551616"] : List Json))).toOption.map
  (·.surfacePreorder) == some 18446744073709551616
#guard (changed (inputPath ++ ["fuel"]) (toJson "18446744073709551616")).any fun raw =>
  (readCorpus raw).isOk

-- 欄の順序と空白は任意。重複欄は文字列エスケープを解いた名前で比較する。
#guard (UniqueJson.parse " { \"b\": [true, null, \"quoted \\\"key\\\"\"], \"a\": -123 } ").isOk
#guard !(readCorpus (sample.replace "\"version\":1" "\"version\":1,\"version\":1")).isOk
#guard !(readCorpus (sample.replace "\"op\":\"intDiv\""
  "\"op\":\"intDiv\",\"\\u006fp\":\"mod\"")).isOk
#guard !(readCorpus (sample ++ " true")).isOk

-- 版・profile と深い未知欄・未知構成子・必須欄を、同じ入口で拒否する。
#guard (changed ["profile"] (toJson "future")).any fun raw =>
  match readCorpus raw with
  | .error message => message == "unsupported interval profile"
  | .ok _ => false
#guard ([
  (["kind"], toJson "corpus"), (["version"], toJson (2 : Nat)),
  (["surfaceVersion"], toJson (13 : Nat)), (["traversalVersion"], toJson (2 : Nat)),
  (inputPath ++ ["standards"], Json.arr #[Json.mkObj [("declaration", toJson "Integer.shiftLeft")]]),
  (inputPath ++ ["apiAt"], Json.arr #[toJson "fake"]),
  (definitionPath ++ ["kind"], toJson "lambda"),
  (definitionPath ++ ["name"], toJson "Other.divide"),
  (definitionPath ++ ["type"], Json.mkObj [("base", Json.mkObj [("name", toJson "Integer"), ("extra", toJson true)])]),
  (binaryPath ++ ["operand"], Json.mkObj [("list", Json.mkObj [("elem", Json.mkObj [("future", Json.mkObj [])])])]),
  (binaryPath ++ ["lhs"], Json.mkObj [("future", Json.mkObj [])]),
  (binaryPath ++ ["rhs"], Json.mkObj [("literal", Json.mkObj [("value", Json.mkObj [
      ("integer", Json.mkObj [("value", toJson (0 : Nat)), ("extra", toJson false)])])])]),
  (binaryPath ++ ["op"], toJson "future"),
  (expectedPath ++ ["coverage"], Json.mkObj [("stopped", Json.mkObj [
      ("kind", toJson "exceeded"), ("scope", toJson "body"),
      ("resource", toJson "items"), ("extra", toJson true)])]),
  (expectedPath ++ ["warnings", "0", "cause"], toJson "unknown"),
  (expectedPath ++ ["warnings", "0", "operation", "binary"], toJson "add"),
  (expectedPath ++ ["warnings", "0", "key", "1"], toJson "3"),
  (definitionPath ++ ["params"], Json.arr #[Json.mkObj [("base", Json.mkObj [])]])
] : List (List String × Json)).all fun (path,value) => rejected path value

-- 番号は根0から元の全先行順に一致し、未対応・未到達の子も抜かさない。
#guard ([
  (definitionPath ++ ["types"], Json.arr #[]),
  (definitionPath ++ ["types", "4", "key", "1"], toJson "3"),
  (definitionPath ++ ["types", "3", "key", "1"], toJson "4"),
  (definitionPath ++ ["types", "0", "type"], Json.mkObj [("base", Json.mkObj [("name", toJson "Boolean")])]),
  (definitionPath ++ ["sourceKeys"], Json.arr #[]),
  (definitionPath ++ ["sourceKeys"], toJson ([["Main.divide", "2"], ["Main.divide", "2"]] : List (List String))),
  (definitionPath ++ ["sourceKeys", "0", "1"], toJson "3"),
  (definitionPath ++ ["sourceKeys", "0", "0"], toJson "Other.divide"),
  (expectedPath ++ ["warnings", "0", "key", "1"], toJson "999")
] : List (List String × Json)).all fun (path,value) => rejected path value

-- 端点と予算は正規の十進文字列。指数・小数・丸め・逆転・値域外を許さない。
#guard (["01", "-0", "+1", "1.0", "1e3", " 1", "1 ", ""] : List String).all fun value =>
  rejected (inputPath ++ ["fuel"]) (toJson value)
#guard ([
  toJson (["2", "1"] : List String),
  toJson (["-9223372036854775809", "0"] : List String),
  toJson (["0", "9223372036854775808"] : List String),
  toJson (["-0", "0"] : List String),
  toJson (["0.0", "1"] : List String),
  toJson (["0e0", "1"] : List String),
  toJson (["0"] : List String), toJson ([0,1] : List Nat)
] : List Json).all fun pair => rejected (expectedPath ++ ["integer"]) (Json.mkObj [("closed", pair)])
#guard rejected (inputPath ++ ["limits", "body", "items"]) (toJson (100 : Nat))
#guard rejected (inputPath ++ ["initial", "body", "operations"]) (toJson "1")
#guard rejected (inputPath ++ ["initial", "body", "saved"]) (toJson "1")
#guard rejected (binaryPath ++ ["lhs", "literal", "value", "integer", "value"])
  (toJson (9223372036854775808 : Int))

-- 同名の容器や候補を足しても、列の先頭を採用して読み捨てない。
private def duplicateAt (path : List String) : Bool :=
  match (UniqueJson.parse sample).toOption with
  | none => false
  | some j =>
    let rec lookup : List String → Json → Option Json
      | [], value => some value
      | key :: rest, .obj fields => fields[key]?.bind (lookup rest)
      | key :: rest, .arr values => key.toNat?.bind fun i => values[i]?.bind (lookup rest)
      | _, _ => none
    match lookup path j with
    | some (.arr xs) => match replaceAt path (.arr (xs ++ xs)) j with
      | some modified => !(readCorpus modified.compress).isOk
      | none => false
    | _ => false

#guard ([ ["inputs"], inputPath ++ ["modules"], modulePath ++ ["definitions"],
    expectedPath ++ ["warnings"] ] : List (List String)).all duplicateAt

-- 除数0だけでなく加算・負号のあふれの候補も保持する。
private def overflow : String := (sample.replace "intDiv" "add").replace
  "\"value\":8" "\"value\":9223372036854775807" |>.replace
  "\"value\":0" "\"value\":1" |>.replace "zeroDivisor" "overflow" |>.replace
  "\"integer\":\"top\"" "\"integer\":\"bottom\""
#guard (readCorpus overflow).isOk

private def negation : Option String := do
  let original ← (UniqueJson.parse overflow).toOption
  let ty := Json.mkObj [("base", Json.mkObj [("name", toJson "Integer")])]
  let literal := Json.mkObj [("literal", Json.mkObj [("value", Json.mkObj [
    ("integer", Json.mkObj [("value", toJson (-9223372036854775808 : Int))])])])]
  let body := Json.mkObj [("neg", Json.mkObj [("operand", ty), ("inner", literal)])]
  let original ← replaceAt (definitionPath ++ ["body", "last", "expr", "paren", "inner"]) body original
  let original ← replaceAt (definitionPath ++ ["types"]) (Json.arr (([0,1,2,3] : List Nat).map fun n =>
    Json.mkObj [("key", toJson ([toJson "Main.divide", toJson (toString n)] : List Json)), ("type", ty)]).toArray) original
  let original ← replaceAt (expectedPath ++ ["warnings", "0", "operation"]) (Json.mkObj [("neg", ty)]) original
  pure original.compress
#guard negation.any fun raw => match readCorpus raw with
  | .ok ⟨[⟨_, _, _, _, _, [⟨_, [definition]⟩], _, _⟩], _⟩ =>
      match definition.expected with
      | .analyzed expected => expected.integer == Interval.bottom && match expected.warnings with
          | [⟨_, .neg _, .overflow⟩] => true | _ => false
      | .notAnalyzed _ => false
  | _ => false

-- 定数の表を実際に展開し、埋め込み本体も先行順に含める。
private def constant : Json := Json.mkObj [
  ("package", toJson "prelude"), ("name", toJson "Main.limit"),
  ("ty", Json.mkObj [("base", Json.mkObj [("name", toJson "Integer")])]),
  ("body", Json.mkObj [("literal", Json.mkObj [("value", Json.mkObj [
    ("integer", Json.mkObj [("value", toJson (8 : Nat))])])])])]
private def constantSample : Option Json := do
  let original ← (UniqueJson.parse sample).toOption
  let original ← replaceAt (inputPath ++ ["constants"]) (Json.arr #[constant]) original
  let original ← replaceAt (definitionPath ++ ["body"]) (Json.mkObj [("last", Json.mkObj [
    ("expr", Json.mkObj [("constName", Json.mkObj [("name", toJson "Main.limit")])])])]) original
  let original ← replaceAt (definitionPath ++ ["types"]) (Json.arr (([0,1,2] : List Nat).map fun n =>
    Json.mkObj [("key", toJson ([toJson "Main.divide", toJson (toString n)] : List Json)),
      ("type", Json.mkObj [("base", Json.mkObj [("name", toJson "Integer")])])]).toArray) original
  let original ← replaceAt (definitionPath ++ ["sourceKeys"]) (Json.arr #[]) original
  replaceAt (expectedPath ++ ["warnings"]) (Json.arr #[]) original
#guard constantSample.any fun j => (readCorpus j.compress).isOk
#guard constantSample.any fun j => (replaceAt (inputPath ++ ["constants"])
  (Json.arr #[constant,constant]) j).any fun modified => !(readCorpus modified.compress).isOk
#guard constantSample.any fun j => (replaceAt (inputPath ++ ["constants", "0", "body"])
  (Json.mkObj [("constName", Json.mkObj [("name", toJson "Main.limit")])]) j).any
    fun modified => !(readCorpus modified.compress).isOk
#guard constantSample.any fun j => (replaceAt (inputPath ++ ["constants"])
  (Json.arr #[]) j).any fun modified => !(readCorpus modified.compress).isOk

-- 組み込みの関数・操作はprimName、利用者関数・シフトの包みはfunNameのまま読む。
-- baseはどちらにも標準規則を認定しない。頭の形を操作の除外に使わない。
#guard ([ ("primName", "Console.writeLine"), ("primName", "Integer.shiftLeft"),
    ("funName", "User.function"), ("funName", "Integer64.shiftLeft") ] : List (String × String)).all
  fun (constructor,name) =>
    let ty := Json.mkObj [("fn", Json.mkObj [("names", Json.arr #[]), ("params", Json.arr #[]),
      ("ret", Json.mkObj [("base", Json.mkObj [("name", toJson "Integer")])]), ("eff", Json.arr #[])])]
    (constantSample.bind fun j => replaceAt (definitionPath ++ ["body", "last", "expr"])
      (Json.mkObj [(constructor, Json.mkObj [("name", toJson name),
        ("tys", Json.arr #[]), ("effs", Json.arr #[])])]) j >>= fun j =>
      replaceAt (definitionPath ++ ["type"]) ty j >>= fun j =>
      replaceAt (definitionPath ++ ["types"]) (Json.arr (([0,1] : List Nat).map fun n =>
        Json.mkObj [("key", toJson ([toJson "Main.divide", toJson (toString n)] : List Json)),
          ("type", ty)]).toArray) j).any fun j => (readCorpus j.compress).isOk

#guard (readCorpus (sample.replace "Main.divide" "Main%impl:2:1:divide")).isOk
#guard !(readCorpus (sample.replace "Main.divide" "Main%impl:02:1:divide")).isOk
#guard !(readCorpus (sample.replace "Main.divide" "Main.divide%body:1:0")).isOk

-- modules の先頭だけを実行開始のモジュールとして扱い、. を含む元キーを保つ。
private def entrySample : String := (sample.replace "\"name\":\"Main\"" "\"name\":\"\"").replace
  "Main.divide" ".divide"
#guard match readCorpus entrySample with
  | .ok ⟨[input], _⟩ => match input.modules with
    | [⟨name, [definition]⟩] => name.isEmpty && definition.input.name == ".divide" &&
        definition.types.map (·.1.definition) == List.replicate 5 ".divide" &&
        definition.sourceKeys.map (·.definition) == [".divide"]
    | _ => false
  | _ => false
#guard (readCorpus (entrySample.replace ".divide" "%impl:2:1:divide")).isOk
#guard !(readCorpus (entrySample.replace ".divide" ".")).isOk
#guard !(readCorpus (entrySample.replace ".divide" "Other.divide")).isOk
-- 空定義列のモジュールも位置と重複の制約を受ける。
private def modulesExample (modules : List Json) : Bool :=
  (changed (inputPath ++ ["modules"]) (toJson modules)).any fun raw => (readCorpus raw).isOk
private def emptyModule (name : String) : Json :=
  Json.mkObj [("name", toJson name), ("definitions", Json.arr #[])]
#guard modulesExample [emptyModule "", emptyModule "Library"]
#guard !modulesExample [emptyModule "Library", emptyModule ""]
#guard !modulesExample [emptyModule "", emptyModule ""]
#guard !modulesExample [emptyModule "Library", emptyModule "Library"]
#guard ([
  (inputPath ++ ["limits", "body"], Json.mkObj [("operations", toJson "1"),
    ("items", toJson "1"), ("extra", toJson false)]),
  (expectedPath ++ ["after", "whole"], Json.mkObj [("operations", toJson "0"),
    ("saved", toJson "0"), ("peak", toJson "0"), ("extra", toJson false)]),
  (definitionPath ++ ["sourceKeys", "0", "1"], toJson "-1"),
  (definitionPath ++ ["sourceKeys", "0", "1"], toJson (2 : Nat)),
  (definitionPath ++ ["type"], Json.mkObj [("base", Json.mkObj [("name", toJson "FutureType")])]),
  (binaryPath ++ ["operand"], Json.mkObj [("base", Json.mkObj [("name", toJson "Integer")]),
    ("list", Json.mkObj [("elem", Json.mkObj [("base", Json.mkObj [("name", toJson "Integer")])])])]),
  (expectedPath ++ ["boolean"], Json.arr #[toJson true]),
  (expectedPath ++ ["coverage"], Json.mkObj [("stopped", Json.mkObj [("kind", toJson "exceeded"),
    ("scope", toJson "future"), ("resource", toJson "items")])])
] : List (List String × Json)).all fun (path,value) => rejected path value
#guard !(readCorpus (sample.replace "\"mayFail\":true," "")).isOk
#guard !(readCorpus (sample.replace "\"version\":1" "\"version\":1,\"extra\":null")).isOk
#guard !(readCorpus (sample.replace "\"name\":\"division\"" "\"name\":\"division\",\"extra\":null")).isOk
#guard !(UniqueJson.parse "[1,]").isOk && !(UniqueJson.parse "{\"a\":1,}").isOk

end Benitoite.Interval.Exchange
