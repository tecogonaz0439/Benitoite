//! 宣言の公開境界と、生成道具が読む JSON 契約（設計書 02-01「宣言だけの収集」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

#[path = "../examples/derive_inventory/mod.rs"]
mod derive_inventory;
use benitoite::{
    modules::{EntrySpec, RealFs},
    pipeline::{self, CheckOptions, declarations::collect_declarations},
};
use serde_json::{Value, json};
use std::path::PathBuf;

struct Project(PathBuf);
impl Project {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "benitoite-declarations-{}-{:?}-{}",
            std::process::id(),
            std::thread::current().id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn write(&self, path: &str, source: &str) {
        let path = self.0.join(path);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, source).unwrap();
    }
    fn entry(&self) -> EntrySpec {
        EntrySpec {
            path: self.0.join("main.bnt"),
            display_name: self.0.join("main.bnt").to_string_lossy().into_owned(),
            root: self.0.clone(),
        }
    }
}
impl Drop for Project {
    fn drop(&mut self) {
        if let Err(error) = std::fs::remove_dir_all(&self.0) {
            eprintln!("temporary project cleanup failed: {error}");
        }
    }
}

// 関門: 新しい標準型の属性・所有元を取り落とすと、利用者が保証を偽造できる。
// 一般のopaqueのテストでは標準モジュールの登録漏れを捕まえられない。
#[test]
fn checked_lists_hide_representation_and_bind_indices_to_their_list() {
    use benitoite::diag::DiagCode as C;
    for (module, name, fields) in [
        (
            "Range",
            "CheckedLength",
            vec![
                ("minimum", "0"),
                ("maximum", "1"),
                ("length", "0"),
                ("values", "[]"),
            ],
        ),
        (
            "Range",
            "CheckedIndex",
            vec![("values", "[7]"), ("index", "0"), ("element", "7")],
        ),
        (
            "NonEmptyList",
            "NonEmptyList",
            vec![("first", "7"), ("rest", "[]")],
        ),
    ] {
        let ctor = format!("{module}.{name}");
        let args = fields
            .iter()
            .map(|(name, value)| format!("{name}: {value}"))
            .collect::<Vec<_>>()
            .join(", ");
        let pattern = fields
            .iter()
            .map(|(name, _)| format!("{name}: _"))
            .collect::<Vec<_>>()
            .join(", ");
        let mut expressions = vec![
            format!("{ctor}({args})"),
            format!("{ctor}(..value, {}: {})", fields[0].0, fields[0].1),
            format!("match value with case {ctor}({pattern}) -> () end match"),
            ctor.clone(),
        ];
        expressions.extend(
            fields
                .iter()
                .map(|(field, _)| format!("{ctor}.{field}(value)")),
        );
        for expr in expressions {
            let source = format!(
                "import Benitoite.Unofficial.{module}\nfunction sample(value: {ctor}[Integer]) -> Unit\nbind _ <- {expr}\nend function\n"
            );
            let checked = pipeline::check_text(
                "checked-lists.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            let codes: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect();
            assert_eq!(codes, [C::E0340], "{expr}: {:?}", checked.diagnostics);
            assert!(checked.program.is_none());
        }
    }
    let checked = pipeline::check_text("checked-index.bnt", b"import Benitoite.Unofficial.Range\nfunction sample(value: Range.CheckedIndex[Integer]) -> Integer\nreturn Range.get(value, [99])\nend function\n", CheckOptions { require_main: false, deny_warnings: false });
    let codes: Vec<_> = checked
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .filter_map(|d| d.code)
        .collect();
    assert_eq!(codes, [C::E0402], "{:?}", checked.diagnostics);
    assert!(checked.program.is_none());
}

// 四問: 本体が未生成でも宣言の解決・制約・位置を取得できる契約を守る。
// 通常の check を誤って呼ぶ退行と、宣言の検査を省く退行で失敗する。
// 既存の check のテストは本体を無視する境界と JSON 出力を通らない。
// 公開 API と example の実際の入口を使い、テスト専用の本番 API は増やさない。
#[test]
fn declarations_do_not_resolve_check_or_evaluate_bodies() {
    let p = Project::new();
    p.write("main.bnt", "import Model\n");
    p.write("Model.bnt", "public record Person\n name: String\nend record\nconst bad: Integer = 1 / 0\nfunction make() -> Person\n return missingGenerated()\nend function\n");
    let result = collect_declarations(&p.entry(), &RealFs);
    assert!(result.inventory.is_some(), "{:?}", result.diagnostics);
    let inv = result.inventory.unwrap();
    assert!(inv.types.expr_types.iter().next().is_none());
    assert!(inv.types.consts.iter().next().is_none());
    let person = inv
        .types
        .adts
        .adts
        .iter()
        .find(|(_, a)| a.name == "Person")
        .unwrap()
        .1;
    assert_eq!(person.record.as_ref().unwrap()[0].name, "name");
    assert!(
        inv.files.iter().any(|f| f.path.ends_with("Model.bnt")
            && f.bytes.windows(16).any(|b| b == b"missingGenerated"))
    );
    let checked = pipeline::check(
        &p.entry(),
        &RealFs,
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert!(checked.program.is_none());
    assert!(checked.diagnostics.iter().any(|d| d.is_error()));
}

#[test]
fn declaration_errors_are_rejected_at_the_same_stage_as_check() {
    use benitoite::diag::DiagCode as C;
    for (source, expected) in [
        ("record Bad\n field: Missing\nend record\n", C::E0301),
        (
            "record Bad\n field: List[String, Integer]\nend record\n",
            C::E0410,
        ),
        (
            "record Bad\n field: String\n field: String\nend record\n",
            C::E0327,
        ),
        (
            "record Secret\n value: String\nend record\npublic function leak() -> Secret\n return missing()\nend function\n",
            C::E0329,
        ),
        (
            "function bad[T: Missing](value: T) -> T\n return missing()\nend function\n",
            C::E0301,
        ),
        (
            "function bad() -> Unit uses Missing\n ()\nend function\n",
            C::E0301,
        ),
        ("function bad() -> Unit\n bind <-\nend function\n", C::E0201),
        ("import Missing\n", C::E0318),
    ] {
        let p = Project::new();
        p.write("main.bnt", source);
        let result = collect_declarations(&p.entry(), &RealFs);
        assert!(result.inventory.is_none(), "{source}");
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert!(!errors.is_empty(), "{source}");
        assert_eq!(errors[0].code, Some(expected), "{source}: {errors:?}");
        let checked = pipeline::check(
            &p.entry(),
            &RealFs,
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        let first = checked.diagnostics.iter().find(|d| d.is_error()).unwrap();
        assert_eq!(
            (errors[0].code, errors[0].primary.as_ref().map(|l| l.span)),
            (first.code, first.primary.as_ref().map(|l| l.span)),
            "{source}"
        );
    }
    let p = Project::new();
    let missing = collect_declarations(&p.entry(), &RealFs);
    assert!(missing.inventory.is_none());
    assert!(missing.diagnostics.iter().any(|d| d.is_error()));
}

fn config() -> Value {
    json!({"version":1,"targets":[{"source":"People.bnt","type":"People.Person","region":"person","json":{"encode":"encodePerson","decode":"decodePerson"},"property":{"generator":"genPerson","shrinker":"shrinkPerson"},"fields":{}}]})
}

#[test]
fn inventory_json_preserves_resolved_types_order_spans_and_input_hashes() {
    let p = Project::new();
    p.write("Other.bnt","public record Address\n city: String\nend record\npublic function text(value: String) -> String\n return missingGenerated()\nend function\n");
    let source = "import Other as O\r\n// 日本語\r\npublic type Text = String\r\npublic record Person\r\n name: Text\r\n address: O.Address\r\n history: List[Option[Map[String, O.Address]]]\r\n opaque: function(value: Integer) -> Integer\r\nend record\r\nfunction pending() -> Unit\r\n missingGenerated()\r\nend function\r\n";
    p.write("People.bnt", source);
    p.write(
        "Helpers.bnt",
        "public function text(value: String) -> String\n return missingGenerated()\nend function\n",
    );
    let mut c = config();
    c["targets"][0]["fields"] = json!({"name":{"encode":"Helpers.text","decode":"Helpers.text"},"opaque":{"encode":"Benitoite.Unofficial.Failure.toResult","decode":"Benitoite.Unofficial.Failure.toResult"}});
    let bytes = serde_json::to_vec(&c).unwrap();
    let first = derive_inventory::inventory(&p.0, &c, &bytes).unwrap();
    assert_eq!(first["version"], 2);
    let target = &first["targets"][0];
    let failure = &target["customFunctions"]["Benitoite.Unofficial.Failure.toResult"];
    assert_eq!(failure["name"], "Benitoite.Failure.toResult");
    assert_eq!(failure["signature"]["noFail"], json!([0]));
    let failure_module = first["modules"]
        .as_array()
        .unwrap()
        .iter()
        .find(|m| m["name"] == "Benitoite.Failure")
        .unwrap();
    assert_eq!(failure_module["importPath"], "Benitoite.Unofficial.Failure");
    let module = first["modules"]
        .as_array()
        .unwrap()
        .iter()
        .find(|m| m["name"] == "People")
        .unwrap();
    assert_eq!(module["imports"][0]["alias"], "O");
    assert_eq!(module["imports"][0]["module"], "Other");
    assert_eq!(
        target["customFunctions"]["Helpers.text"]["signature"]["params"][0]["name"],
        "value"
    );
    assert_eq!(
        target["customFunctions"]["Helpers.text"]["signature"]["returnType"],
        json!({"tag":"application","head":{"tag":"named","name":"Benitoite.String.String"},"arguments":[]})
    );
    assert_eq!(target["module"], "People");
    assert_eq!(target["public"], true);
    let fields = target["fields"].as_array().unwrap();
    assert_eq!(
        fields
            .iter()
            .map(|f| f["name"].as_str().unwrap())
            .collect::<Vec<_>>(),
        ["name", "address", "history", "opaque"]
    );
    assert_eq!(
        fields[0]["type"],
        json!({"tag":"application","head":{"tag":"named","name":"Benitoite.String.String"},"arguments":[]})
    );
    assert_eq!(
        fields[1]["type"],
        json!({"tag":"application","head":{"tag":"named","name":"Other.Address"},"arguments":[]})
    );
    assert_eq!(
        fields[2]
            .pointer("/type/arguments/0/arguments/0/arguments/1/head/name")
            .unwrap(),
        "Other.Address"
    );
    assert_eq!(fields[3]["type"]["tag"], "function");
    assert_eq!(
        fields[3]["metadata"]["original"],
        "function(value: Integer) -> Integer"
    );
    assert_eq!(
        fields[0]["span"]["start"],
        u64::try_from(source.find("name: Text").unwrap()).unwrap()
    );
    assert_eq!(
        first["inputs"]
            .as_array()
            .unwrap()
            .iter()
            .find(|f| f["path"] == "People.bnt")
            .unwrap()["sha256"],
        "e5f5146f75423577203b7e707855332fdffef15df5012d6144df19a476867a72"
    );
    assert_eq!(
        first["records"]["Other.Address"]["fields"][0]["name"],
        "city"
    );
    assert_eq!(
        first["functions"]["People.pending"]["signature"]["returnType"],
        json!({"tag":"application","head":{"tag":"named","name":"Benitoite.Unit"},"arguments":[]})
    );
    p.write("Other.bnt","public record Address\n city: String\n zip: Integer\nend record\npublic function text(value: String) -> String\n return missingGenerated()\nend function\n");
    let second = derive_inventory::inventory(&p.0, &c, &bytes).unwrap();
    assert_ne!(first["inputs"], second["inputs"]);
    assert_ne!(
        first["records"]["Other.Address"],
        second["records"]["Other.Address"]
    );
}

#[test]
fn config_rejects_duplicate_unknown_and_incomplete_settings() {
    for bytes in [
        r#"{"version":1,"version":1,"targets":[]}"#,
        r#"{"version":1,"targets":[],"unknown":0}"#,
        r#"{"version":2,"targets":[]}"#,
        r#"{"version":1,"targets":[{"source":"P.bnt","type":"P.P","region":"p","fields":{"x":{"encode":"P.e"}}}]}"#,
        r#"{"version":1,"targets":[{"source":"P.bnt","type":"P.P","region":"p","fields":{"x":{"gen":"P.g","gen":"P.g","shrink":"P.s"}}}]}"#,
    ] {
        assert!(
            derive_inventory::config::read(bytes.as_bytes()).is_err(),
            "{bytes}"
        );
    }
    assert!(derive_inventory::config::read(&serde_json::to_vec(&config()).unwrap()).is_ok());
}

// 四問: 宣言だけの収集でもopaqueの所有元・印・完全な内部型表を渡す契約を守る。
// 公開契約で内部型を漏れと誤判定する変更、メンバー表を消す変更で失敗する。
// 本体を辿る通常のcheckだけでは生成道具の境界を確かめられない。既存公開APIを使う。
#[test]
fn opaque_declarations_keep_representation_and_owner_but_hide_its_contract() {
    let p = Project::new();
    p.write("main.bnt", "import Model\n");
    let model = "record Hidden\n value: Integer\nend record\n@opaque\npublic record Box[T]\n raw: T\n hidden: Hidden\nend record\n@opaque\npublic(package) data Secret\n A(Hidden)\n B\nend data\npublic function identity(value: Box[Integer]) -> Box[Integer]\n return value\nend function\n";
    p.write("Model.bnt", model);
    let result = collect_declarations(&p.entry(), &RealFs);
    assert!(result.inventory.is_some(), "{:?}", result.diagnostics);
    let inv = result.inventory.unwrap();
    for name in ["Box", "Secret"] {
        let (id, binding) = inv
            .resolved
            .bindings
            .iter()
            .find(|(_, b)| b.name == name && b.opaque)
            .unwrap();
        assert_eq!(
            inv.modules.get(binding.module).unwrap().name.dotted(),
            "Model"
        );
        let adt = inv.types.adts.adts.get(id).unwrap();
        if name == "Box" {
            assert_eq!(adt.record.as_ref().unwrap().len(), 2);
        } else {
            assert_eq!(adt.ctors.len(), 2);
        }
    }
    // opaqueの内部だけを免除する。公開する関数の署名のE0329は残す。
    p.write(
        "Model.bnt",
        &format!(
            "{model}\npublic function leak() -> Hidden\n return missingBody()\nend function\n"
        ),
    );
    let result = collect_declarations(&p.entry(), &RealFs);
    assert!(result.inventory.is_none());
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{errors:?}");
    assert_eq!(errors[0].code, Some(benitoite::diag::DiagCode::E0329));
}

#[test]
fn opaque_types_keep_nominal_equality_and_nonempty_coverage() {
    use benitoite::diag::DiagCode as C;
    let p = Project::new();
    p.write("Model.bnt", "@opaque\npublic data Secret\n A(Integer)\n B\nend data\n@opaque\npublic record Callback\n run: function() -> Unit\nend record\n");
    for (source, code) in [
        (
            "function f(x: Model.Secret) -> Boolean\n return x = x\nend function",
            None,
        ),
        (
            "function f(x: Model.Secret) -> Unit\n match x with\n case _ -> ()\n end match\nend function",
            None,
        ),
        (
            "function f(x: Model.Secret) -> Unit\n match x with\n case _ if false -> ()\n end match\nend function",
            Some(C::E0601),
        ),
        (
            "function f(x: Model.Callback) -> Boolean\n return x = x\nend function",
            Some(C::E0406),
        ),
    ] {
        p.write("main.bnt", &format!("import Model\n{source}\n"));
        let result = pipeline::check(
            &p.entry(),
            &RealFs,
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        let errors: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .map(|d| d.code)
            .collect();
        assert_eq!(
            errors,
            code.into_iter().map(Some).collect::<Vec<_>>(),
            "{source}: {:?}",
            result.diagnostics
        );
    }
}

// 四問: 版2の種類・多相署名・匿名実装と不透明型の境界を、宣言情報の入口で観察する。
// Debug出力への退行やimplementの欠落、opaqueの取り落としで失敗する。
// 旧版のレコード中心の例は二引数クラスと匿名実装を読まない。テスト用の公開APIは足さない。
#[test]
fn inventory_v2_preserves_kinds_anonymous_implementations_and_opaque_boundaries() {
    let p = Project::new();
    p.write("People.bnt", "import Benitoite.Trait\nimport Benitoite.StringBuilder as SB\n@opaque\npublic record Person\n value: Integer64\nend record\n@opaque\npublic data Secret\n Secret(String)\nend data\npublic record Box[T]\n value: T\nend record\npublic trait Readable[T]\n function read(value: T) -> String\nend trait\n// benitoite-derive:begin traits\nimplement[T] Readable[Box[T]]\n function read(value: Box[T]) -> String\n  return missingGenerated()\n end function\nend implement\n// benitoite-derive:end traits\npublic function call[F[_, _], A, E, effect EF](f: function(value: A) -> F[A, E] uses EF, value: A) -> F[A, E] uses EF\n return missingGenerated()\nend function\n");
    let c = config();
    let inv = derive_inventory::inventory(&p.0, &c, &serde_json::to_vec(&c).unwrap()).unwrap();
    let target = &inv["targets"][0];
    assert_eq!(target["opaque"], true);
    assert_eq!(target["canConstruct"], true);
    assert_eq!(target["canInspect"], true);
    assert_eq!(target["visibility"], "public");
    assert_eq!(inv["types"]["People.Secret"]["opaque"], true);
    assert_eq!(inv["types"]["People.Secret"]["kind"], "data");
    assert_eq!(inv["types"]["People.Box"]["arity"], 1);
    assert_eq!(
        target["fields"][0]["type"]["head"]["name"],
        "Benitoite.Integer.Integer"
    );
    assert_eq!(
        inv["records"]["People.Box"]["fields"][0]["type"],
        json!({"tag":"parameter","index":0})
    );
    let sig = &inv["functions"]["People.call"]["signature"];
    assert_eq!(
        sig["typeParams"][0]["kind"],
        json!({"tag":"constructor","arity":2})
    );
    assert_eq!(
        sig["returnType"]["head"],
        json!({"tag":"parameter","index":0})
    );
    assert_eq!(sig["params"][0]["type"]["effects"]["vars"], json!([0]));
    let impls = inv["implementations"].as_array().unwrap();
    let i = impls
        .iter()
        .find(|i| i["class"] == "People.Readable")
        .unwrap();
    assert_eq!(i["target"]["head"]["name"], "People.Box");
    assert_eq!(
        i["target"]["arguments"][0],
        json!({"tag":"parameter","index":0})
    );
    assert_eq!(i["methods"][0]["name"], "read");
    assert_eq!(i["sourceRegion"], "traits");
    assert!(
        inv["declarations"]
            .as_array()
            .unwrap()
            .iter()
            .any(|d| d["kind"] == "stringBuilder" && d["module"] == "People")
    );
    let result = impls
        .iter()
        .find(|i| i["class"] == "Benitoite.Trait.Monad2")
        .unwrap();
    assert_eq!(result["sourceRegion"], Value::Null);
    assert_eq!(
        result["target"],
        json!({"tag":"named","name":"Benitoite.Result.Result"})
    );
}

// 関門: 標準のLogだけを組み込みとして扱い、IO.All・利用者同名・as禁止を独立に確かめる。
// 宣言の収集と公開checkを通すので、名前の綴りだけのテストにはしない。
#[test]
fn log_standard_declarations_and_effect_identity() {
    use benitoite::diag::DiagCode as C;
    use benitoite::pipeline::{self, CheckOptions};
    let p = Project::new();
    p.write(
        "main.bnt",
        "function main() -> Unit uses Log\n ()\nend function\n",
    );
    let result = collect_declarations(&p.entry(), &RealFs);
    assert!(result.inventory.is_some(), "{:?}", result.diagnostics);
    let inventory = result.inventory.unwrap();
    let log = inventory.resolved.stdlib("Benitoite.Log.Log").unwrap();
    let definition = inventory.types.effects.get(log).unwrap();
    assert!(matches!(
        definition.name,
        benitoite::types::EffectName::Builtin(_)
    ));
    assert_eq!(definition.ops.len(), 2);
    let opts = CheckOptions {
        require_main: true,
        deny_warnings: false,
    };
    for (header, expected) in [
        ("uses Log", vec![]),
        ("", vec![C::E0501]),
        ("uses IO.All", vec![C::E0501]),
    ] {
        let source = format!(
            "function main() -> Unit {header}\n bind _ <- Log.enabled(Log.Level.Debug)\nend function\n"
        );
        let checked = pipeline::check_text("main.bnt", source.as_bytes(), opts);
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{:?}",
            checked.diagnostics
        );
    }
    for (source, expected) in [
        (
            "import Benitoite.Unofficial.Log as L\nfunction main() -> Unit\n ()\nend function\n",
            C::E0339,
        ),
        (
            "effect Log\n function entry() -> Unit\nend effect\nfunction main() -> Unit uses Log\n ()\nend function\n",
            C::E0506,
        ),
    ] {
        let checked = pipeline::check_text("main.bnt", source.as_bytes(), opts);
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            [expected],
            "{:?}",
            checked.diagnostics
        );
    }
    let checked = pipeline::check_text("main.bnt", b"function main() -> Unit\n handle Log.emit(record: Log.Record(level: Log.Level.Info, message: \"event\", attributes: [], location: SourceLocation.here())) with\n  case Log.emit(record) -> resume(())\n  case Log.enabled(level) -> resume(false)\n end handle\nend function\n", opts);
    assert!(checked.program.is_some(), "{:?}", checked.diagnostics);
}

// 関門: Logを処理した後もsink/本文の外側効果を宣言し、withAttributesはLogを残す。
#[test]
fn log_standard_handlers_keep_the_outer_effect_contract() {
    use benitoite::diag::DiagCode;
    use benitoite::pipeline::{self, CheckOptions};
    for (body, effect) in [
        (
            "Log.withTextLogger(minimum: Log.Level.Info, body: lambda() Log.info(message: \"event\", attributes: [], location: SourceLocation.here()) end lambda)",
            "Console.Write",
        ),
        (
            "Log.withAttributes(attributes: [], body: lambda() Log.info(message: \"event\", attributes: [], location: SourceLocation.here()) end lambda)",
            "Log",
        ),
        (
            "Log.withSinks(sinks: [Pair(Log.Level.Debug, lambda(record: Log.Record) Console.writeLine(Log.Record.message(record)) end lambda)], body: lambda() Log.info(message: \"event\", attributes: [], location: SourceLocation.here()) end lambda)",
            "Console.Write",
        ),
    ] {
        for declared in [false, true] {
            let header = if declared {
                format!("uses {effect}")
            } else {
                String::new()
            };
            let source = format!(
                "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit {header}\n {body}\nend function\n"
            );
            let checked = pipeline::check_text(
                "log-contract.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: true,
                    deny_warnings: false,
                },
            );
            let expected = if declared {
                vec![]
            } else {
                vec![DiagCode::E0501]
            };
            assert_eq!(
                checked
                    .diagnostics
                    .iter()
                    .filter(|d| d.is_error())
                    .filter_map(|d| d.code)
                    .collect::<Vec<_>>(),
                expected,
                "{source}: {:?}",
                checked.diagnostics
            );
        }
    }
}
