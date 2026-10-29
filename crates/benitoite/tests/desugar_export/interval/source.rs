//! Surface の宣言順を独立に辿り、通常解析が取得した接頭辞と照合する。
//! （設計書 02-05「区間解析の式の識別」）。
use super::*;
use std::collections::BTreeMap;

/// 元の出現との照合を通った本文・対応・候補。
pub(super) struct Connected {
    pub definition: Value,
    pub correspondence: Vec<Value>,
    pub candidates: Value,
    pub embedded: Vec<Value>,
    pub manifest: Vec<String>,
    pub body_types: Vec<Value>,
}

/// 元位置の注釈を外し、独立交換の正規の本文を得る。
pub(super) fn strip(value: &Value) -> Value {
    if value.get("$interval").is_some() {
        return strip(&value["expr"]);
    }
    match value {
        Value::Array(xs) => json!(xs.iter().map(strip).collect::<Vec<_>>()),
        Value::Object(xs) => Value::Object(xs.iter().map(|(k, v)| (k.clone(), strip(v))).collect()),
        Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => value.clone(),
    }
}

struct Walk<'a> {
    name: &'a str,
    constants: BTreeMap<String, Value>,
    active: std::collections::BTreeSet<String>,
    entries: Vec<Value>,
    bodies: Vec<(String, Value)>,
}

impl Walk<'_> {
    fn block(&mut self, block: &Value, parent: usize) {
        if block == "empty" {
            return;
        }
        let (tag, fields) = block.as_object().unwrap().iter().next().unwrap();
        match tag.as_str() {
            "builderBind" => self.block(&fields["rest"], parent),
            "last" | "lastBind" | "lastDiscard" | "lastPat" => {
                self.expr(&fields["expr"], Some(parent), None)
            }
            "bind" | "discard" | "seq" | "bindPat" => {
                self.expr(&fields["expr"], Some(parent), None);
                self.block(&fields["rest"], parent);
            }
            _ => panic!("unknown Surface Block: {tag}"),
        }
    }
    fn list(&mut self, list: &Value, parent: usize) {
        for e in list.as_array().unwrap() {
            self.expr(e, Some(parent), None);
        }
    }
    fn holes(&mut self, args: &Value, parent: usize) {
        for arg in args.as_array().unwrap() {
            if let Some(e) = arg.get("expr") {
                self.expr(&e["inner"], Some(parent), None);
            } else {
                assert!(arg.get("hole").is_some(), "unknown HoleArg {arg}");
            }
        }
    }
    fn expr(&mut self, wrapped: &Value, parent: Option<usize>, root_type: Option<&Value>) {
        let (value, metadata) = if root_type.is_some() {
            (wrapped, Value::Null)
        } else {
            assert!(
                wrapped.get("$interval").is_some(),
                "missing source correspondence: {wrapped}"
            );
            (&wrapped["expr"], wrapped["$interval"].clone())
        };
        let (tag, fields) = if value == "unit" {
            ("unit", &Value::Null)
        } else {
            let obj = value.as_object().unwrap();
            assert_eq!(obj.len(), 1, "Surface expression {value}");
            let (tag, fields) = obj.iter().next().unwrap();
            (tag.as_str(), fields)
        };
        let form = match tag {
            "constName" => "Const",
            "lam" => "Lambda",
            "ite" => "IfElse",
            "matchE" => "Match",
            "returnE" => "Return",
            "tryResultReturn" => "TryResult",
            "tryOptionReturn" => "TryOption",
            "withE" => "With",
            "lazyE" => "Lazy",
            "handleE" => "Handle",
            "literal"
                if fields["value"]["integer"]["value"]
                    .as_i64()
                    .is_some_and(|n| n < 0) =>
            {
                "NegInt"
            }
            other => {
                let mut chars = other.chars();
                // Surface の構成子名の先頭だけを大文字にして、内部の形の名前と照合する。
                let form = format!("{}{}", chars.next().unwrap().to_uppercase(), chars.as_str());
                let index = self.entries.len();
                self.push(index, parent, &metadata, root_type, form, value);
                self.children(tag, fields, index);
                self.entries[index]["end"] = json!(self.entries.len().to_string());
                return;
            }
        };
        let index = self.entries.len();
        self.push(index, parent, &metadata, root_type, form.to_owned(), value);
        self.children(tag, fields, index);
        self.entries[index]["end"] = json!(self.entries.len().to_string());
    }
    fn push(
        &mut self,
        index: usize,
        parent: Option<usize>,
        metadata: &Value,
        root_type: Option<&Value>,
        form: String,
        value: &Value,
    ) {
        self.entries.push(
            json!({"preorder":index.to_string(),"parent":parent.map(|n|n.to_string()),
            "form":form,"node":metadata["node"],"span":metadata["span"],
            "type":root_type.unwrap_or(&metadata["type"]),"expression":strip(value),
            "sourceStatus":if root_type.is_some(){"syntheticBodyRoot"}else{"mapped"}}),
        );
    }
    fn children(&mut self, tag: &str, f: &Value, parent: usize) {
        match tag {
            "local" | "funName" | "funDicts" | "methName" | "primName" | "opName" | "opDicts"
            | "raise" | "nullCon" | "conValue" | "literal" | "negInt" | "negFloat"
            | "negDecimal" | "negInteger8" | "negInteger16" | "negInteger32" | "negFloat32"
            | "unit" => {}
            "constName" => {
                let name = f["name"].as_str().unwrap();
                assert!(
                    self.active.insert(name.to_owned()),
                    "cyclic constant {name}"
                );
                let body = self.constants.get(name).unwrap().clone();
                self.expr(&body, Some(parent), None);
                self.active.remove(name);
            }
            "builderOp" | "conCall" | "record" => self.list(&f["args"], parent),
            "list" => self.list(&f["elems"], parent),
            "paren" | "neg" | "not" | "returnE" | "tryResult" | "tryResultReturn" | "tryOption"
            | "tryOptionReturn" | "resume" => self.expr(&f["inner"], Some(parent), None),
            "block" => self.block(&f["body"], parent),
            "lam" | "lazyE" => {
                self.bodies
                    .push((format!("{}%body:{parent}:0", self.name), f["body"].clone()));
                self.block(&f["body"], parent);
            }
            "handleFail" => {
                self.bodies.push((
                    format!("{}%body:{parent}:0", self.name),
                    f["clause"].clone(),
                ));
                self.block(&f["body"], parent);
                self.block(&f["clause"], parent);
            }
            "recordUpdate" => {
                self.expr(&f["base"], Some(parent), None);
                self.list(&f["args"], parent);
            }
            "call" => {
                self.expr(&f["callee"], Some(parent), None);
                self.list(&f["args"], parent);
            }
            "pipe" | "binary" | "and" | "or" => {
                self.expr(&f["lhs"], Some(parent), None);
                self.expr(&f["rhs"], Some(parent), None);
            }
            "partialCall" => {
                self.expr(&f["callee"], Some(parent), None);
                self.holes(&f["args"], parent);
            }
            "partialCon" => self.holes(&f["args"], parent),
            "listSpread" => {
                self.expr(&f["concat"], Some(parent), None);
                self.list(&f["before"], parent);
                self.expr(&f["spread"], Some(parent), None);
                self.list(&f["after"], parent);
            }
            "interpolation" => {
                self.list(&f["es"], parent);
                self.list(&f["converters"], parent);
            }
            "ite" => {
                self.expr(&f["cond"], Some(parent), None);
                self.block(&f["yes"], parent);
                self.block(&f["no"], parent);
            }
            "elseIf" => {
                self.expr(&f["cond"], Some(parent), None);
                self.block(&f["yes"], parent);
                self.expr(&f["no"], Some(parent), None);
            }
            "ifOnly" => {
                self.expr(&f["cond"], Some(parent), None);
                self.block(&f["yes"], parent);
            }
            "matchE" => {
                self.expr(&f["scrutinee"], Some(parent), None);
                for arm in f["arms"].as_array().unwrap() {
                    let arm = &arm["mk"];
                    if !arm["guard"].is_null() {
                        self.expr(&arm["guard"], Some(parent), None);
                    }
                    self.block(&arm["body"], parent);
                }
            }
            "tryResultDie" | "tryOptionDie" => {
                self.expr(&f["inner"], Some(parent), None);
                if !f["message"].is_null() {
                    self.expr(&f["message"], Some(parent), None);
                }
            }
            "withE" => {
                self.expr(&f["bound"], Some(parent), None);
                self.block(&f["body"], parent);
            }
            "handleE" => {
                // manifest は境界の先行順、同じ境界では節順。内側より先に全節を登録する。
                for (ordinal, clause) in f["clauses"].as_array().unwrap().iter().enumerate() {
                    self.bodies.push((
                        format!("{}%body:{parent}:{ordinal}", self.name),
                        clause["body"].clone(),
                    ));
                }
                self.block(&f["body"], parent);
                for clause in f["clauses"].as_array().unwrap() {
                    self.block(&clause["body"], parent);
                }
            }
            _ => panic!("unknown Surface Expr {tag} in {}", self.name),
        }
    }
}

fn verify(name: &str, entries: &mut [Value], observed: &Value) {
    assert_eq!(name, observed["definition"].as_str().unwrap());
    let actual = observed["occurrences"].as_array().unwrap();
    assert!(actual.len() <= entries.len(), "{name} extra occurrences");
    for (actual, expected) in actual.iter().zip(entries.iter()) {
        for field in ["preorder", "parent", "form", "node", "span"] {
            assert_eq!(
                actual[field], expected[field],
                "{name} key {} field {field}",
                actual["preorder"]
            );
        }
        if !actual["end"].is_null() {
            assert_eq!(actual["end"], expected["end"], "{name} subtree end");
        }
    }
    assert_eq!(observed["next"], actual.len().to_string());
    if observed["coverage"] == "Prepared" {
        assert_eq!(actual.len(), entries.len(), "{name} missing suffix");
    }
    // 親と独立入力自身の候補を、対応表を照合した後にだけ読む。
    let parent = observed["candidates"].as_array().unwrap().iter();
    let independent = observed["independent"]
        .as_array()
        .unwrap()
        .iter()
        .flat_map(|input| input["candidates"].as_array().unwrap());
    for candidate in parent.chain(independent) {
        let index: usize = candidate["preorder"].as_str().unwrap().parse().unwrap();
        assert!(
            index < actual.len(),
            "{name} candidate without acquired identity"
        );
        assert_eq!(
            candidate["node"], entries[index]["node"],
            "{name} candidate source"
        );
        assert_eq!(
            candidate["originSpan"], entries[index]["span"],
            "{name} candidate span"
        );
    }
    for (index, entry) in entries.iter_mut().enumerate() {
        entry["acquired"] = json!(index < actual.len());
        entry["observedEnd"] = actual
            .get(index)
            .map_or(Value::Null, |actual| actual["end"].clone());
    }
}

fn candidates(observed: &Value) -> Value {
    json!({"parent":observed["candidates"],"independent":observed["independent"],"coverage":observed["coverage"],"next":observed["next"]})
}

/// 実 Surface の番号と通常解析の訪問表を照合してから候補を読む。
pub(super) fn connect(raw: &Value, observations: &[Value]) -> Connected {
    assert_eq!(
        raw["outside"],
        json!([]),
        "out-of-scope Surface {}",
        raw["name"]
    );
    let name = raw["name"].as_str().unwrap();
    let observed = observations
        .iter()
        .find(|entry| entry["definition"] == name)
        .filter(|entry| entry["kind"] != "whole");
    let mut walk = Walk {
        name,
        constants: raw["constants"]
            .as_array()
            .unwrap()
            .iter()
            .map(|entry| {
                (
                    entry["name"].as_str().unwrap().to_owned(),
                    entry["body"].clone(),
                )
            })
            .collect(),
        active: Default::default(),
        entries: Vec::new(),
        bodies: Vec::new(),
    };
    walk.expr(
        &json!({"block":{"body":raw["body"]}}),
        None,
        Some(&raw["type"]),
    );
    if let Some(observed) = observed {
        verify(name, &mut walk.entries, observed);
    } else {
        for entry in &mut walk.entries {
            entry["acquired"] = json!(false);
            entry["observedEnd"] = Value::Null;
        }
    }
    let manifest = std::iter::once(name.to_owned())
        .chain(walk.bodies.iter().map(|(name, _)| name.clone()))
        .collect();
    let body_types = std::iter::once(json!({"definition":name,"type":raw["type"]}))
        .chain(
            walk.bodies
                .iter()
                .map(|(name, body)| json!({"definition":name,"type":block_type(body)})),
        )
        .collect();
    let mut embedded = Vec::new();
    for (name, body) in &walk.bodies {
        if let Some(actual) = observations
            .iter()
            .find(|entry| entry["definition"] == *name)
        {
            let mut child = Walk {
                name,
                constants: walk.constants.clone(),
                active: Default::default(),
                entries: Vec::new(),
                bodies: Vec::new(),
            };
            child.expr(&json!({"block":{"body":body}}), None, Some(&Value::Null));
            verify(name, &mut child.entries, actual);
            embedded.push(
                json!({"name":name,"correspondence":child.entries,"candidates":candidates(actual)}),
            );
        }
    }
    // 未発見・未解析の manifest の比較と区別し、存在する観測の取り落としは拒否する。
    for actual in observations.iter().filter(|entry| {
        entry["definition"]
            .as_str()
            .unwrap()
            .starts_with(&format!("{name}%body:"))
    }) {
        assert!(
            embedded
                .iter()
                .any(|entry| entry["name"] == actual["definition"]),
            "unmatched embedded body {actual}"
        );
    }
    let types: Vec<_> = walk
        .entries
        .iter()
        .map(|entry| json!({"key":[name,entry["preorder"]],"type":entry["type"]}))
        .collect();
    let source_keys: Vec<_> = walk
        .entries
        .iter()
        .filter(|entry| {
            let e = &entry["expression"];
            let ty = if entry["form"] == "Neg" {
                &e["neg"]["operand"]
            } else {
                &e["binary"]["operand"]
            };
            let arithmetic = matches!(
                e["binary"]["op"].as_str(),
                Some(
                    "add"
                        | "sub"
                        | "mul"
                        | "intDiv"
                        | "mod"
                        | "eq"
                        | "ne"
                        | "lt"
                        | "le"
                        | "gt"
                        | "ge"
                )
            ) || entry["form"] == "Neg"
                && matches!(
                    ty["base"]["name"].as_str(),
                    Some("Integer" | "Integer8" | "Integer16" | "Integer32")
                );
            arithmetic
                && matches!(
                    ty["base"]["name"].as_str(),
                    Some(
                        "Integer"
                            | "Integer8"
                            | "Integer16"
                            | "Integer32"
                            | "UnsignedInteger16"
                            | "UnsignedInteger32"
                            | "UnsignedInteger64"
                    )
                )
        })
        .map(|entry| json!([name, entry["preorder"]]))
        .collect();
    Connected {
        definition: json!({"name":name,"kind":raw["kind"],"params":raw["params"],"type":raw["type"],"body":strip(&raw["body"]),"types":types,"sourceKeys":source_keys}),
        correspondence: walk.entries,
        candidates: observed.map_or_else(|| json!({"coverage":"notAnalyzed"}), candidates),
        embedded,
        manifest,
        body_types,
    }
}

// Exchange.reportedBodyType と同じく、元の全型表の末尾の式から別本体の型を読む。
fn block_type(block: &Value) -> Value {
    if block == "empty" {
        return json!({"base":{"name":"Unit"}});
    }
    let (tag, fields) = block.as_object().unwrap().iter().next().unwrap();
    match tag.as_str() {
        "last" => fields["expr"]["$interval"]["type"].clone(),
        "lastBind" | "lastDiscard" | "lastPat" => json!({"base":{"name":"Unit"}}),
        "builderBind" | "bind" | "discard" | "seq" | "bindPat" => block_type(&fields["rest"]),
        _ => panic!("unknown Surface Block {tag}"),
    }
}

/// 対応記録を本文から外し、呼び出し側の独立期待値とともに包む。
pub(super) fn corpus(raw: &Value, mut connected: Connected, expected: Value) -> Value {
    connected.definition["expected"] = expected;
    json!({"kind":"interval-corpus","version":1,"surfaceVersion":15,"traversalVersion":1,"profile":"base",
        "inputs":[{"name":raw["name"],"fuel":"200","limits":{"body":{"operations":"100000","items":"100000"},"whole":{"operations":"1000000","items":"1000000"}},
            "initial":{"body":{"operations":"0","temporary":"0","saved":"0","peak":"0"},"whole":{"operations":"0","saved":"0","peak":"0"}},
            "constants":strip(&raw["constants"]),"standards":[],"apiAt":[],"modules":[{"name":raw["module"],"definitions":[connected.definition]}]}]})
}

/// 標準表と実際のcallの頭を結び、対象キーを先行順へ戻す。
/// 型引数・エフェクト引数・操作の頭は標準callに認定しない。
pub(super) fn standard_sites(connected: &mut Connected, standards: &[Value]) -> Vec<Value> {
    let name = connected.definition["name"].as_str().unwrap();
    let mut sites = Vec::new();
    for entry in &connected.correspondence {
        let head = &entry["expression"]["call"]["callee"];
        let head = head.get("funName").or_else(|| head.get("primName"));
        if let Some(head) = head
            && head["tys"] == json!([])
            && head["effs"] == json!([])
            && standards.iter().any(|s| s["declaration"] == head["name"])
        {
            assert_eq!(entry["sourceStatus"], "mapped");
            assert!(!entry["node"].is_null());
            sites.push(json!({"key":[name,entry["preorder"]],"declaration":head["name"]}));
        }
    }
    let mut keys = connected.definition["sourceKeys"]
        .as_array()
        .unwrap()
        .clone();
    keys.extend(sites.iter().map(|s| s["key"].clone()));
    keys.sort_by_key(|key| key[1].as_str().unwrap().parse::<usize>().unwrap());
    connected.definition["sourceKeys"] = json!(keys);
    sites
}

/// 読者の契約だけを検査する入力。予算0による未着手を独立に期待する。
/// 解析値・消費・警告の全比較はX02で通常の予算と独立期待値を渡す。
pub(super) fn reader_input(
    raw: &Value,
    connected: &Connected,
    label: &str,
    standards: &[Value],
    sites: Vec<Value>,
) -> Value {
    let mut definition = connected.definition.clone();
    let stop = json!({"kind":"exceeded","scope":"whole","resource":"operations"});
    definition["expected"] = json!({"notAnalyzed":stop});
    let zero = json!({"body":{"operations":"0","temporary":"0","saved":"0","peak":"0"},
        "whole":{"operations":"0","saved":"0","peak":"0"}});
    json!({"name":format!("{label}:{}",raw["name"].as_str().unwrap()),"fuel":"2000",
        "limits":{"body":{"operations":"100000","items":"100000"},"whole":{"operations":"0","items":"1000000"}},
        "initial":zero,"constants":strip(&raw["constants"]),"standards":standards,"apiAt":sites,
        "modules":[{"name":raw["module"],"definitions":[definition]}],
        "expected":{"after":zero,"phaseStops":[{"phase":"whole","reason":stop}],
            "counts":{"inputDefinitions":"1","unsupportedBodies":"0","bodyBudgetExceeded":"0","unidentifiedBodies":"0","wholeBudgetSkipped":"1"}}})
}
