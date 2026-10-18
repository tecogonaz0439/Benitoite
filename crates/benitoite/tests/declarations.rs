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
        json!({"tag":"builtin","name":"String"})
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
    assert_eq!(fields[0]["type"], json!({"tag":"builtin","name":"String"}));
    assert_eq!(
        fields[1]["type"],
        json!({"tag":"record","name":"Other.Address"})
    );
    assert_eq!(
        fields[2]
            .pointer("/type/element/element/value/name")
            .unwrap(),
        "Other.Address"
    );
    assert_eq!(fields[3]["type"]["tag"], "unsupported");
    assert_eq!(
        fields[3]["type"]["original"],
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
        first["functions"]["People.pending"]["signature"]["returnType"]["resolved"],
        "Unit"
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
