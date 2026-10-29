//! 宣言の公開境界と、生成道具が読む JSON 契約（設計書 02-01「宣言だけの収集」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

#[path = "../examples/derive_inventory/mod.rs"]
mod derive_inventory;
#[path = "declarations/interval_widths.rs"]
mod interval_widths;
use benitoite::{
    modules::{EntrySpec, RealFs},
    pipeline::{self, CheckOptions, declarations::collect_declarations},
};
use serde_json::{Value, json};
use std::path::PathBuf;

// 関門: 書式の後検査が回復の未知だけを抑え、既知の構造・自身の契約・正常な結果と、
// どの型にも適合しない書式の診断を残す。
// zonk後の型だけを見る退行、部分の誤りで全体を抑える退行を捕まえる。
// C2の書式なしの例はE0468を通らない。公開入口を使い差し込み口は増やさない。
#[test]
fn interpolation_formats_preserve_recovery() {
    use benitoite::diag::DiagCode as C;
    for cause in ["SourceLocation.here", "1(2)", "1(value: 2)"] {
        for (body, incompatible) in [
            (
                "bind value <- ERROR\n bind n: Integer <- value\n bind s: String <- value\n return \"${value:.2f}\"",
                false,
            ),
            ("bind value <- [ERROR]\n return \"${value:.2f}\"", true),
            (
                "bind value: String <- ERROR\n return \"${value:.2f}\"",
                true,
            ),
            ("bind value <- known(ERROR)\n return \"${value:.2f}\"", true),
            (
                "bind value <- Box(value: ERROR)\n return \"${value:.2f}\"",
                true,
            ),
            (
                "bind value <- Box(value: ERROR)\n bind item <- Box.value(value)\n return \"${item:.2f}\"",
                false,
            ),
            ("bind value <- ERROR\n return \"${value:+s}\"", true),
        ] {
            let body = body.replace("ERROR", cause);
            let source = format!(
                "record Box[T]\n value: T\nend record\nfunction known[T](value: T) -> String\n return \"ok\"\nend function\nfunction sample() -> String\n {body}\nend function\n"
            );
            let checked = pipeline::check_text(
                "format-recovery.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            let errors: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .collect();
            assert_eq!(
                errors.len(),
                if incompatible { 2 } else { 1 },
                "{source}: {errors:#?}"
            );
            assert!(
                errors.iter().any(|d| d.code
                    == Some(if cause == "SourceLocation.here" {
                        C::E0467
                    } else {
                        C::E0403
                    })),
                "{source}: {errors:#?}"
            );
            let formats: Vec<_> = errors.iter().filter(|d| d.code == Some(C::E0468)).collect();
            assert_eq!(
                formats.len(),
                usize::from(incompatible),
                "{source}: {errors:#?}"
            );
            if let Some(diag) = formats.first() {
                assert_eq!(
                    diag.primary.as_ref().unwrap().span.start.0 as usize,
                    source.rfind(':').unwrap()
                );
            }
            assert!(checked.program.is_none());
        }
    }
}

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
        // 関門: 宣言だけの入口でも、ファイルの効果の型引数の誤りを通常の検査と同じ位置で拒否する。
        (
            "uses Log[Integer]\nfunction f() -> Unit\n()\nend function\n",
            C::E0513,
        ),
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
    assert_eq!(first["version"], 4);
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
        json!({"tag":"application","head":{"tag":"named","name":"Benitoite.String.String"},"arguments":[],"ix":{"fixed":"top"}})
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
        json!({"tag":"application","head":{"tag":"named","name":"Benitoite.String.String"},"arguments":[],"ix":{"fixed":"top"}})
    );
    assert_eq!(
        fields[1]["type"],
        json!({"tag":"application","head":{"tag":"named","name":"Other.Address"},"arguments":[],"ix":{"fixed":"top"}})
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
        json!({"tag":"application","head":{"tag":"named","name":"Benitoite.Unit"},"arguments":[],"ix":{"fixed":"top"}})
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

// 関門: 宣言情報の交換境界で、Top・閉じた範囲・標準署名内の変数と被覆の向きを守る。
// 旧テストは範囲を import できない失敗だけを捕まえ、Top への置換や関係の消失を検出しない。
// 実際の宣言を読み、独立した期待値へ比較する。公開の差し込み口は増やさない。
#[test]
fn inventory_preserves_ranges_and_standard_signature_relationships() {
    let p = Project::new();
    p.write(
        "People.bnt",
        r#"import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Network.Http
public record Person
 path: Scope.PathIn["/data/**"]
 anyPath: Scope.PathIn
 request: Http.RequestIn["2001:db8::/32", 443]
end record
public function read(path: Scope.PathIn["/data/**"]) -> String uses File.Read["/data/**"]
 return missingBody()
end function
public function sorted() -> Unit uses Http.Connect["::1", 443], Http.Connect["::a", 443]
 return missingBody()
end function
"#,
    );
    let c = config();
    let inv = derive_inventory::inventory(&p.0, &c, &serde_json::to_vec(&c).unwrap()).unwrap();
    assert_eq!(inv["version"], 4);
    let path = json!({"fixed":{"path":{"tree":["data"]}}});
    let fields = &inv["targets"][0]["fields"];
    assert_eq!(fields[0]["type"]["ix"], path);
    assert_eq!(fields[1]["type"]["ix"], json!({"fixed":"top"}));
    assert_eq!(
        fields[2]["type"]["ix"],
        json!({"fixed":{"endpoint":{"host":{"ip":{"cidr":{"family":"v6","network":"42540766411282592856903984951653826560","prefixLen":32}}},"ports":{"lo":443,"hi":443}}}})
    );
    assert_eq!(inv["types"]["Benitoite.Scope.PathIn"]["rangeKind"], "path");
    assert_eq!(
        inv["types"]["Benitoite.Network.Http.RequestIn"]["rangeKind"],
        "endpoint"
    );
    assert_eq!(
        inv["types"]["Benitoite.String.String"]["rangeKind"],
        Value::Null
    );
    let read = &inv["functions"]["People.read"]["signature"];
    assert_eq!(read["rkinds"], json!([]));
    assert_eq!(read["params"][0]["type"]["ix"], path);
    assert_eq!(
        read["effects"]["names"],
        json!([{"tag":"builtin","name":"IO.File.Read","ix":path}])
    );
    for (module, check, project, widen, kind) in [
        (
            "Benitoite.Scope",
            "checkPathIn",
            "pathInValue",
            "widenPathIn",
            "path",
        ),
        (
            "Benitoite.Network.Http",
            "checkRequestIn",
            "requestInValue",
            "widenRequestIn",
            "endpoint",
        ),
    ] {
        let functions = &inv["functions"];
        let check = &functions[format!("{module}.{check}")]["signature"];
        let project = &functions[format!("{module}.{project}")]["signature"];
        let widen = &functions[format!("{module}.{widen}")]["signature"];
        assert_eq!(check["rkinds"], json!([kind]));
        assert_eq!(check["admission"], "any");
        assert_eq!(check["shape"], "untargeted");
        assert_eq!(check["returnType"]["arguments"][0]["ix"], json!({"rvar":0}));
        assert_eq!(project["rkinds"], json!([kind]));
        assert_eq!(project["params"][0]["type"]["ix"], json!({"rvar":0}));
        assert_eq!(widen["rkinds"], json!([kind, kind]));
        assert_eq!(widen["admission"], json!({"covers":{"inner":0,"outer":1}}));
        assert_eq!(widen["params"][0]["type"]["ix"], json!({"rvar":0}));
        assert_eq!(widen["returnType"]["ix"], json!({"rvar":1}));
    }
    let wire = derive_inventory::to_string(&inv).unwrap();
    assert!(wire.contains("\"network\":42540766411282592856903984951653826560,"));
    let sorted = &inv["functions"]["People.sorted"]["signature"]["effects"];
    let rows = sorted["names"].as_array().unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(
        rows[0]
            .pointer("/ix/fixed/endpoint/host/ip/exact/bits")
            .unwrap(),
        "1"
    );
    assert_eq!(
        rows[1]
            .pointer("/ix/fixed/endpoint/host/ip/exact/bits")
            .unwrap(),
        "10"
    );
}

// 関門: JSON に内包する利用者のキー名を、範囲の整数欄と取り違えない。
// 普通の型の期待値だけでは設定の再書き出しの破損を捕まえない。実際の出力境界を使う。
#[test]
fn inventory_json_keeps_user_key_mappings_as_strings() {
    let p = Project::new();
    p.write("People.bnt", "public record Person\n family: String\n bits: Integer\n network: String\n prefixLen: Integer\nend record\n");
    for keys in [
        json!({"family":"f","bits":"renamed"}),
        json!({"network":"123","prefixLen":"length"}),
    ] {
        let mut c = config();
        c["targets"][0]["json"]["keys"] = keys.clone();
        let inv = derive_inventory::inventory(&p.0, &c, &serde_json::to_vec(&c).unwrap()).unwrap();
        let wire = derive_inventory::to_string(&inv).unwrap();
        let decoded: Value = serde_json::from_str(&wire).unwrap();
        assert_eq!(decoded["targets"][0]["config"]["json"]["keys"], keys);
    }
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
        &definition.name,
        benitoite::types::EffectName::Builtin(_, ix) if ix == &benitoite::types::builtin::RangeIndex::TOP
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

// 関門: 通常のファイルの合併の成功と package.bnt の拒否は読み込みの公開境界に固有である。
#[test]
fn file_uses_loading_merges_functions_and_rejects_config_declarations() {
    use benitoite::diag::DiagCode as C;
    for (path, body, expected) in [
        (
            "main.bnt",
            "uses Log\nfunction main() -> Unit\n()\nend function\n",
            None,
        ),
        (
            "Helper.bnt",
            "uses Log\npublic function help() -> Unit\n()\nend function\n",
            None,
        ),
        ("package.bnt", "uses Log\n", Some(C::E0912)),
    ] {
        let mut files: Vec<(&str, &[u8])> = vec![
            (
                "main.bnt",
                b"import Helper\nfunction main() -> Unit\n()\nend function\n",
            ),
            (
                "Helper.bnt",
                b"public function help() -> Unit\n()\nend function\n",
            ),
        ];
        files.retain(|(name, _)| *name != path);
        files.push((path, body.as_bytes()));
        // 最初の要素を入口にする公開 API の規則を保つ。
        files.sort_by_key(|(name, _)| *name != "main.bnt");
        let result = pipeline::check_files(
            &files,
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected.into_iter().collect::<Vec<_>>(),
            "{path}: {errors:?}"
        );
        assert_eq!(result.program.is_some(), expected.is_none());
        if let Some(error) = errors.first() {
            let span = error.primary.as_ref().unwrap().span;
            assert_eq!(span.start.0, 0);
            assert!(span.end.0 >= 4);
        }
    }
    let result = pipeline::check_text(
        "main.bnt",
        b"function main() -> Unit\n()\nend function\n",
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
}

// 関門: 公開の宣言収集を境界に、元AST・合併後の型・NoFail・元位置の独立した契約を照合する。
// 個別usesだけの既存検査では、ファイル追加を後回しにする退行と入れ子への誤追加を捕まえない。
#[test]
fn file_uses_inventory_keeps_original_ast_and_effect_origins() {
    use benitoite::syntax::ast::Item;
    use benitoite::types::{EffVar, Ty};
    let p = Project::new();
    p.write("main.bnt", "import Benitoite.Unofficial.Failure\nuses Failure.Fail[Alias]\ntype Alias = String\nfunction forward[effect E](body: function() -> Integer uses E) -> Integer uses E, Failure.Fail[String]\n return body()\nend function\ntrait Value[T]\n function value(x: T) -> T\nend trait\nimplement Value[Integer]\n function value(x: Integer) -> Integer\n return x\n end function\nend implement\nconst answer: Integer = 42\neffect Ask\n function ask() -> Integer\nend effect\n");
    let result = collect_declarations(&p.entry(), &RealFs);
    assert!(result.inventory.is_some(), "{:?}", result.diagnostics);
    let inv = result.inventory.unwrap();
    let ast = inv
        .asts
        .iter()
        .find(|a| a.file == inv.modules.modules[0].id.file())
        .unwrap();
    let file = ast.file_uses.as_ref().unwrap();
    let f = ast
        .decls
        .iter()
        .find_map(|d| match &d.item {
            Item::Fn(f) => Some(f),
            Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::ExternalType(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Impl(_)
            | Item::Error(_) => None,
        })
        .unwrap();
    assert_eq!(f.uses.as_ref().unwrap().effects.len(), 2);
    let binding = *inv.resolved.decls.get(f.id).unwrap();
    let scheme = inv.types.decl_types.get(binding).unwrap();
    assert_eq!(scheme.effects.failures.len(), 1);
    assert_eq!(scheme.no_fail, [EffVar(0)]);
    let Ty::Fn(callback) = &scheme.params[0] else {
        panic!("callback type")
    };
    assert!(callback.effects.failures.is_empty());
    assert_eq!(callback.effects.vars, [EffVar(0)]);
    let effective = inv.types.effective_effects.get(binding).unwrap();
    assert_eq!(effective.effects, scheme.effects);
    assert_eq!(effective.origins.len(), 3);
    let origin = effective.origins.iter().find(|o| o.file).unwrap();
    assert_eq!(origin.span, file.effects[0].span);
    assert_eq!(origin.effects.failures, scheme.effects.failures);
    for name in ["value", "ask", "answer"] {
        let bindings: Vec<_> = inv
            .resolved
            .bindings
            .iter()
            .filter(|(_, b)| b.module == inv.modules.modules[0].id && b.name == name)
            .collect();
        assert_eq!(bindings.len(), if name == "value" { 2 } else { 1 });
        for (id, b) in bindings {
            use benitoite::resolve::BindingKind;
            assert!(matches!(
                (name, b.kind),
                (
                    "value",
                    BindingKind::Method { .. } | BindingKind::ImplFn { .. }
                ) | ("ask", BindingKind::Op { .. })
                    | ("answer", BindingKind::Const)
            ));
            let scheme = inv.types.decl_types.get(id);
            assert!(scheme.is_some(), "missing scheme: {name} {:?}", b.kind);
            assert!(scheme.unwrap().effects.failures.is_empty());
        }
    }
}

// 関門: 共通宣言の公開性は最も広い公開範囲で一度だけ診断し、修正を一括適用できる。
// 公開関数一つの既存対照では、同じ挿入の重複と公開範囲の取り違えを捕まえない。
#[test]
fn file_uses_visibility_reports_once_and_repairs_all_public_functions() {
    use benitoite::diag::DiagCode as C;
    for (effect_visibility, first, second, expected) in [
        ("", "public", "public", true),
        ("", "public(package)", "public", true),
        ("", "public", "public(package)", true),
        ("", "public(package)", "public(package)", true),
        ("public(package) ", "public(package)", "public", true),
        (
            "public(package) ",
            "public(package)",
            "public(package)",
            false,
        ),
    ] {
        let source = format!(
            "uses Hidden\n{effect_visibility}effect Hidden\n function ask() -> Unit\nend effect\n{first} function f() -> Unit\n()\nend function\n{second} function g() -> Unit\n()\nend function\n"
        );
        let options = CheckOptions {
            require_main: false,
            deny_warnings: false,
        };
        let checked = pipeline::check_text("visibility.bnt", source.as_bytes(), options);
        let errors: Vec<_> = checked
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect();
        assert!(
            errors.iter().all(|d| d.code == Some(C::E0329)),
            "{errors:?}"
        );
        let mut edits: Vec<_> = errors
            .iter()
            .flat_map(|d| &d.helps)
            .flat_map(|h| &h.edits)
            .collect();
        edits.sort_by_key(|e| std::cmp::Reverse(e.span.start));
        let mut repaired = source.clone();
        for edit in &edits {
            repaired.replace_range(
                edit.span.start.0 as usize..edit.span.end.0 as usize,
                &edit.replacement,
            );
        }
        let fixed = pipeline::check_text("visibility.bnt", repaired.as_bytes(), options);
        assert!(
            fixed.program.is_some(),
            "{repaired}: {:?}",
            fixed.diagnostics
        );
        assert_eq!(errors.len(), usize::from(expected), "{source}: {errors:?}");
        assert_eq!(edits.len(), usize::from(expected));
        for error in errors {
            assert!(error.helps.iter().all(|h| !h.message.contains("handle")));
            assert!(error.helps.iter().any(|h| h.message == "remove the effect from the file-level uses or move the public functions to a file without that declaration"));
            assert!(error.notes.iter().any(|n| n == "the file-level uses adds this effect to every public top-level function in the file"));
            let span = error.primary.as_ref().unwrap().span;
            assert_eq!(
                &source[span.start.0 as usize..span.end.0 as usize],
                "Hidden"
            );
        }
    }
}

// 関門: リスト内部の重複とリスト間の合併、入口・外部・公開性を本物の検査で区別する。
#[test]
fn file_uses_contracts_preserve_existing_restrictions() {
    use benitoite::diag::DiagCode as C;
    let cases = [
        (
            "uses Log\nfunction f() -> Unit uses Log\n()\nend function\n",
            vec![],
        ),
        (
            "uses Log, Log\nfunction f() -> Unit\n()\nend function\nfunction g() -> Unit\n()\nend function\n",
            vec![C::E0419],
        ),
        (
            "uses Log\nfunction f() -> Unit uses Log, Log\n()\nend function\n",
            vec![C::E0419],
        ),
        (
            "uses Unknown\nfunction f() -> Unit\n()\nend function\nfunction g() -> Unit\n()\nend function\n",
            vec![C::E0301],
        ),
        (
            "uses E\nfunction f[effect E](body: function() -> Unit uses E) -> Unit uses E\nbody()\nend function\n",
            vec![C::E0301],
        ),
        (
            "import Benitoite.Unofficial.Failure\nuses Failure.Fail[T]\nfunction f[T](x: T) -> T\nreturn x\nend function\n",
            vec![C::E0301],
        ),
        (
            "import Benitoite.Unofficial.Failure\nuses Failure.Fail[String]\nfunction f() -> Unit uses Failure.Fail[Integer]\n()\nend function\n",
            vec![C::E0514],
        ),
        (
            "uses Hidden\neffect Hidden\nfunction ask() -> Unit\nend effect\npublic function f() -> Unit\n()\nend function\n",
            vec![C::E0329],
        ),
        (
            "uses Hidden\neffect Hidden\nfunction ask() -> Unit\nend effect\nfunction main() -> Unit\nhandle ask() with case ask() -> resume(()) end handle\nend function\n",
            vec![C::E0506],
        ),
        (
            "uses Hidden\neffect Hidden\nfunction ask() -> Unit\nend effect\nfunction main() -> Unit uses Hidden\nhandle ask() with case ask() -> resume(()) end handle\nend function\n",
            vec![C::E0506],
        ),
        (
            "import Benitoite.Unofficial.Failure\nuses Failure.Fail[String]\n@test\nfunction sample() -> Unit\n()\nend function\n",
            vec![C::E0506],
        ),
        (
            "import Benitoite.Unofficial.Failure\nuses Failure.Fail[String]\nfunction main() -> Unit uses Failure.Fail[String]\n()\nend function\n",
            vec![C::E0506],
        ),
        (
            "import Benitoite.Unofficial.Failure\nuses Failure.Fail[String]\n@test\nfunction sample() -> Unit uses Failure.Fail[String]\n()\nend function\n",
            vec![C::E0506],
        ),
        (
            "import Benitoite.Assert\nuses Assert.Check\nfunction main() -> Unit\n()\nend function\n",
            vec![C::E0415],
        ),
        (
            "import Benitoite.Assert\nuses Assert.Check\nfunction main() -> Unit uses Assert.Check\n()\nend function\n",
            vec![C::E0415],
        ),
        (
            "uses Log\nfunction f() -> (function() -> Unit)\nreturn lambda() return () end lambda\nend function\nfunction g() -> Unit\nbind local: function() -> Unit <- lambda() return () end lambda\nlocal()\nend function\n",
            vec![],
        ),
        (
            "uses State\nfunction main() -> Unit\n()\nend function\n",
            vec![],
        ),
        (
            "import Benitoite.Unofficial.IO.Console\nuses IO.All, Log\nfunction f() -> Unit uses Console.Write, Log\nConsole.writeLine(\"ok\")\nend function\n",
            vec![],
        ),
        (
            "import Benitoite.StringBuilder\nuses State\nfunction f() -> String\nbind b: StringBuilder <- StringBuilder.new()\nStringBuilder.append(builder: b, text: \"value\")\nreturn StringBuilder.copy(b)\nend function\nfunction g() -> Unit\nbind pure: function() -> String <- f\nbind _ <- pure()\nend function\n",
            vec![C::E0401],
        ),
    ];
    for (source, expected) in cases {
        let checked = pipeline::check_text(
            "file-contract.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
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
        assert_eq!(checked.program.is_some(), expected.is_empty(), "{source}");
        for diagnostic in checked.diagnostics.iter().filter(|d| d.is_error()) {
            if diagnostic.code == Some(C::E0506) {
                assert!(
                    diagnostic
                        .helps
                        .iter()
                        .any(|h| h.message.contains("file-level uses")),
                    "{diagnostic:?}"
                );
                assert!(
                    diagnostic
                        .helps
                        .iter()
                        .all(|h| !h.message.contains("Failure.toResult")),
                    "{diagnostic:?}"
                );
                let span = diagnostic.primary.as_ref().unwrap().span;
                assert!(
                    (span.start.0 as usize) < source.find("function").unwrap(),
                    "{diagnostic:?}"
                );
            }
            if diagnostic.code == Some(C::E0415) {
                let span = diagnostic.primary.as_ref().unwrap().span;
                assert_eq!(
                    span.start.0 as usize,
                    source.find("uses Assert.Check").unwrap() + 5
                );
            }
            if diagnostic.code == Some(C::E0514) {
                let label = diagnostic
                    .secondary
                    .iter()
                    .find(|label| label.text == "the function's uses is declared here")
                    .unwrap();
                assert_eq!(
                    &source[label.span.start.0 as usize..label.span.end.0 as usize],
                    "uses Failure.Fail[Integer]"
                );
            }
        }
        if source.contains("uses Hidden")
            || source.contains("@test")
            || source.contains("Fail[Integer]")
        {
            let error = checked.diagnostics.iter().find(|d| d.is_error()).unwrap();
            let span = error.primary.as_ref().unwrap().span;
            assert!(
                span.start.0 < u32::try_from(source.find("function").unwrap()).unwrap(),
                "{error:?}"
            );
        }
    }
}

// 関門: import先の追加はその関数の契約だけに残り、呼び出し元全体へ再適用しない。
#[test]
fn file_uses_imports_and_higher_order_values_use_merged_contracts() {
    use benitoite::diag::DiagCode as C;
    for (body, effects, expected) in [
        ("()", "", vec![]),
        ("Helper.f()", "", vec![C::E0501]),
        ("Helper.f()", "uses Log", vec![]),
        (
            "bind f: function() -> Unit <- Helper.f\nf()",
            "",
            vec![C::E0401],
        ),
    ] {
        let source =
            format!("import Helper\nfunction main() -> Unit {effects}\n{body}\nend function\n");
        let result = pipeline::check_files(
            &[
                ("main.bnt", source.as_bytes()),
                (
                    "Helper.bnt",
                    b"uses Log\npublic function f() -> Unit\n()\nend function\n",
                ),
            ],
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{source}: {:?}",
            result.diagnostics
        );
    }
}

// 関門: 外部の実体を読まない宣言収集でも、合併後のStateちょうど一つという契約を守る。
#[test]
fn file_uses_external_declarations_check_the_effective_contract() {
    use benitoite::diag::DiagCode as C;
    for (file, individual, resource, expected) in [
        ("", "", false, None),
        ("uses Log\n", "", false, Some(C::E0812)),
        ("uses Log\n", "uses Log", false, Some(C::E0812)),
        ("uses State\n", "", true, None),
        ("uses State\n", "uses State", true, None),
        ("uses Log\n", "uses State", true, Some(C::E0812)),
        ("uses State, Log\n", "", true, Some(C::E0812)),
    ] {
        let p = Project::new();
        let (decl, ret) = if resource {
            (
                "@external(\"wasm\", \"x.wasm\", \"bnt:test/counter#cell\")\ntype Cell\n",
                "Cell",
            )
        } else {
            ("", "Integer")
        };
        let source = format!(
            "{file}{decl}@external(\"wasm\", \"x.wasm\", \"make\")\nfunction make() -> {ret} {individual}\n"
        );
        p.write("main.bnt", &source);
        let result = collect_declarations(&p.entry(), &RealFs);
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected.into_iter().collect::<Vec<_>>(),
            "{source}: {:?}",
            result.diagnostics
        );
        if expected.is_some() {
            let error = result.diagnostics.iter().find(|d| d.is_error()).unwrap();
            assert!(
                error.primary.as_ref().unwrap().span.start.0 < u32::try_from(file.len()).unwrap()
            );
            assert!(error.helps.iter().all(|h| h.edits.is_empty()), "{error:?}");
        }
    }
}

// 関門: 合併したFailと行変数から得たNoFailを、別モジュールでの具体化にも引き継ぐ。
#[test]
fn file_uses_failure_no_fail_is_enforced_at_calls() {
    use benitoite::diag::DiagCode as C;
    let library = "import Benitoite.Unofficial.Failure\nuses Failure.Fail[String]\npublic function load[effect E](body: function() -> Result[String, String] uses E) -> String uses E\n return Failure.fromResult(body())\nend function\n";
    for (file, expected) in [
        ("", vec![C::E0501, C::E0515]),
        ("uses Failure.Fail[String]\n", vec![]),
    ] {
        let source = format!(
            "import Load\nimport Benitoite.Unofficial.Failure\n{file}function use[effect E](body: function() -> Result[String, String] uses E) -> String uses E\n return Load.load(body)\nend function\n"
        );
        let result = pipeline::check_files(
            &[
                ("main.bnt", source.as_bytes()),
                ("Load.bnt", library.as_bytes()),
            ],
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{source}: {:?}",
            result.diagnostics
        );
    }
}

// 関門: 診断済みの未確定値だけを抑え、束縛自身の契約と独立した誤りを残す。
// 既存の宣言由来の検査には、位置の事前展開と呼び出し失敗からの束縛がない。
// 公開の検査入口で診断の位置まで確かめ、内部のグラフの形には依存しない。
#[test]
fn diagnosed_binding_recovery_preserves_own_contracts() {
    use benitoite::diag::DiagCode as C;
    for (error, cause) in [
        ("SourceLocation.here", C::E0467),
        ("1(2)", C::E0403),
        ("1(value: 2)", C::E0403),
    ] {
        for (binding, subject, own_contract) in [
            ("bind f <- ERROR\n bind n: Integer <- f", "f", false),
            (
                "bind f <- ERROR\n bind alias <- f\n bind n: Integer <- alias",
                "alias",
                false,
            ),
            ("bind f <- ERROR\n bind _ <- idInt(f)", "f", false),
            ("bind f: Integer <- ERROR", "f", true),
            ("bind f <- ERROR\n bind n: Integer <- f", "n", true),
        ] {
            let binding = binding.replace("ERROR", error);
            let usage = if own_contract {
                format!("bind wrong: String <- {subject}")
            } else {
                format!(
                    "match {subject} with\n case Option.Some(v) -> ()\n case Option.None -> ()\n end match"
                )
            };
            let source = format!(
                "function idInt(value: Integer) -> Integer\n return value\nend function\nfunction main() -> Unit\n {binding}\n {usage}\n bind independent: Integer <- \"wrong\"\nend function\nfunction other() -> Unit\n bind independent: Integer <- \"wrong\"\nend function\n"
            );
            let checked = pipeline::check_text(
                "main.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: true,
                    deny_warnings: false,
                },
            );
            assert!(checked.program.is_none(), "{source}");
            let errors: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .collect();
            assert_eq!(
                errors.iter().filter(|d| d.code == Some(cause)).count(),
                1,
                "{source}: {errors:#?}"
            );
            assert!(
                errors.iter().any(|d| d.code == Some(cause)
                    && d.primary
                        .as_ref()
                        .is_some_and(|p| p.span.start.0 as usize == source.find(error).unwrap())),
                "{source}: {errors:#?}"
            );
            let mismatches: Vec<_> = errors.iter().filter(|d| d.code == Some(C::E0401)).collect();
            assert_eq!(
                mismatches.len(),
                if own_contract { 3 } else { 2 },
                "{source}: {errors:#?}"
            );
            for position in source.match_indices("\"wrong\"").map(|(i, _)| i) {
                assert!(
                    mismatches.iter().any(|d| d
                        .primary
                        .as_ref()
                        .is_some_and(|p| p.span.start.0 as usize == position)),
                    "{source}: {errors:#?}"
                );
            }
            if own_contract {
                assert!(
                    mismatches.iter().any(|d| d
                        .primary
                        .as_ref()
                        .is_some_and(|p| p.span.start.0 as usize
                            == source.find("bind wrong: String <- ").unwrap()
                                + "bind wrong: String <- ".len())),
                    "{source}: {errors:#?}"
                );
            }
            assert_eq!(errors.len(), mismatches.len() + 1, "{source}: {errors:#?}");
        }
    }
    // 原因を直した入力では、実際の型に基づく不一致を再び報告する。
    let source = "function main() -> Unit\n bind f <- 1\n bind n: Integer <- f\n match f with\n case Option.Some(v) -> ()\n case Option.None -> ()\n end match\nend function\n";
    let checked = pipeline::check_text(
        "main.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 1, "{:#?}", checked.diagnostics);
    assert_eq!(checked.diagnostics[0].code, Some(C::E0401));
    assert_eq!(
        checked.diagnostics[0]
            .primary
            .as_ref()
            .unwrap()
            .span
            .start
            .0 as usize,
        source.find("Option.Some(v)").unwrap()
    );
}

// 関門: 複合型の未知の部分と、既知の外側・別の欄・宣言した結果の誤りを区別する。
// C1の単純な束縛では、要素や関数の部分がzonkで失われる退行を捕まえられない。
// 公開の検査入口を使い、原因の位置と独立した誤りの位置を固定する。
#[test]
fn diagnosed_recovery_preserves_partial_structure() {
    use benitoite::diag::DiagCode as C;
    let preamble = "import Benitoite.Unofficial.Failure\nrecord Box[T]\n value: T\nend record\nfunction idInt(value: Integer) -> Integer\n return value\nend function\nfunction failing[E](value: E) -> function() -> Unit uses Failure.Fail[E]\n return lambda() -> Unit uses Failure.Fail[E] return Failure.raise(value) end lambda\nend function\nfunction wrap[T](seed: T) -> function(value: T) -> Unit\n return lambda(value: T) () end lambda\nend function\n";
    for error in ["SourceLocation.here", "1(2)", "1(value: 2)"] {
        for (body, independent) in [
            (
                "bind xs <- [ERROR]\n bind ints: List[Integer] <- xs\n bind strings: List[String] <- xs",
                None,
            ),
            (
                "bind xs <- [ERROR]\n bind wrong: Integer <- xs",
                Some("xs\nend function"),
            ),
            (
                "bind xs <- [[ERROR]]\n bind wrong: List[Integer] <- xs",
                Some("xs\nend function"),
            ),
            (
                "bind xs <- [ERROR]\n bind wrong: List[String] <- [xs]",
                Some("[xs]"),
            ),
            (
                "bind pair <- Pair(ERROR, 1)\n bind ints: Pair[Integer, Integer] <- pair\n bind wrong: Pair[String, String] <- pair",
                Some("pair\nend function"),
            ),
            (
                "bind box <- Box(value: ERROR)\n bind ints: Box[Integer] <- box\n bind strings: Box[String] <- box",
                None,
            ),
            (
                "bind box <- Box(value: ERROR)\n bind wrong: Integer <- box",
                Some("box\nend function"),
            ),
            (
                "bind f <- lambda() return ERROR end lambda\n bind ints: function() -> Integer <- f\n bind strings: function() -> String <- f",
                None,
            ),
            (
                "bind f <- lambda() return ERROR end lambda\n bind wrong: Integer <- f",
                Some("f\nend function"),
            ),
            ("bind wrong: String <- idInt(ERROR)", Some("idInt(")),
            (
                "bind xs <- [ERROR, 1]\n bind wrong: List[String] <- xs",
                Some("xs\nend function"),
            ),
            (
                "bind box <- Box(value: ERROR)\n bind v <- Box.value(box)\n bind n: Integer <- v\n bind s: String <- v",
                None,
            ),
            (
                "bind Box(value: v) <- Box(value: ERROR)\n bind n: Integer <- v\n bind s: String <- v",
                None,
            ),
            (
                "match Option.Some(ERROR) with\n case Option.Some(v) ->\n bind n: Integer <- v\n bind s: String <- v\n case Option.None -> ()\n end match",
                None,
            ),
            (
                "bind f <- wrap(ERROR)\n bind ints: function(value: Integer) -> Unit <- f\n bind strings: function(value: String) -> Unit <- f",
                None,
            ),
            (
                "bind f <- failing(ERROR)\n bind ints: function() -> Unit uses Failure.Fail[Integer] <- f\n bind strings: function() -> Unit uses Failure.Fail[String] <- f",
                None,
            ),
            (
                "bind f <- failing(ERROR)\n bind wrong: function() -> String uses Failure.Fail[String] <- f",
                Some("f\nend function"),
            ),
        ] {
            let source = format!(
                "{preamble}function main() -> Unit\n {}\nend function\n",
                body.replace("ERROR", error)
            );
            let checked = pipeline::check_text(
                "main.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: true,
                    deny_warnings: false,
                },
            );
            assert!(checked.program.is_none(), "{source}");
            let errors: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .collect();
            let cause = if error == "SourceLocation.here" {
                C::E0467
            } else {
                C::E0403
            };
            assert_eq!(
                errors.iter().filter(|d| d.code == Some(cause)).count(),
                1,
                "{source}: {errors:#?}"
            );
            assert_eq!(
                errors.len(),
                1 + usize::from(independent.is_some()),
                "{source}: {errors:#?}"
            );
            if let Some(needle) = independent {
                let position = source.rfind(needle).unwrap();
                assert!(
                    errors.iter().any(|d| d.code == Some(C::E0401)
                        && d.primary
                            .as_ref()
                            .is_some_and(|p| p.span.start.0 as usize == position)),
                    "{source}: {errors:#?}"
                );
            }
        }
    }
    for (tail, expected_errors) in [("bind strings: List[String] <- xs", 1), ("()", 0)] {
        let source = format!(
            "function main() -> Unit\n bind xs <- [1]\n bind ints: List[Integer] <- xs\n {tail}\nend function\n"
        );
        let checked = pipeline::check_text(
            "main.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            expected_errors,
            "{source}: {:#?}",
            checked.diagnostics
        );
        assert_eq!(checked.program.is_some(), expected_errors == 0);
        if expected_errors != 0 {
            assert_eq!(checked.diagnostics[0].code, Some(C::E0401));
        }
    }
}

// 関門: 原因と独立した後検査は、同じ式に未知の部分があっても残す。
// 単純なE0401の対照では、集まり・型クラス・網羅性の一律抑制を検出できない。
#[test]
fn diagnosed_recovery_preserves_independent_later_checks() {
    use benitoite::diag::DiagCode as C;
    for (body, code) in [
        ("bind f <- ERROR\n bind _ <- true - false", C::E0405),
        ("bind _ <- \"${[ERROR]}\"", C::E0422),
        (
            "bind pair <- Pair(ERROR, lambda() () end lambda)\n bind _ <- pair = pair",
            C::E0406,
        ),
        ("bind _ <- Trait.Show.show(Box(value: ERROR))", C::E0705),
        ("match [ERROR] with\n case [] -> ()\n end match", C::E0601),
        ("bind f <- effectful(ERROR)\n bind _ <- pure(f)", C::E0401),
        ("bind f <- ERROR\n bind _ <- idInt()", C::E0402),
        ("bind _ <- idInt(wrong: ERROR)", C::E0451),
        ("bind f <- ERROR\n Console.writeLine(\"event\")", C::E0501),
    ] {
        for error in ["SourceLocation.here", "1(value: 2)"] {
            let source = format!(
                "import Benitoite.Trait\nimport Benitoite.Unofficial.IO.Console\nrecord Box[T]\n value: T\nend record\nfunction idInt(value: Integer) -> Integer\n return value\nend function\nfunction effectful[T](seed: T) -> function(value: T) -> Unit uses Console.Write\n return lambda(value: T) -> Unit uses Console.Write Console.writeLine(\"event\") end lambda\nend function\nfunction pure(body: function(value: Integer) -> Unit) -> Unit\n ()\nend function\nfunction main() -> Unit\n {}\nend function\n",
                body.replace("ERROR", error)
            );
            let checked = pipeline::check_text(
                "main.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: true,
                    deny_warnings: false,
                },
            );
            assert!(checked.program.is_none());
            let codes: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect();
            assert_eq!(codes.len(), 2, "{source}: {:#?}", checked.diagnostics);
            assert!(
                codes.contains(&if error == "SourceLocation.here" {
                    C::E0467
                } else {
                    C::E0403
                }),
                "{source}: {codes:?}"
            );
            assert!(codes.contains(&code), "{source}: {codes:?}");
        }
    }
}

// 関門: 保留中の呼び出しへの依存は、独立した剛な型の脱出を消す根拠にならない。
// 名前付き呼び出しからの値と節の型の関係が必要で、既存の脱出の例では保留へ到達しない。
#[test]
fn diagnosed_recovery_keeps_pending_call_escape() {
    use benitoite::diag::DiagCode as C;
    let source = r#"import Benitoite.Unofficial.Failure
effect Swap
 function store[T](x: T) -> T
end effect
function empty[A](seed: Unit) -> A uses Failure.Fail[String]
 return Failure.raise("stop")
end function
function same[A](a: A, b: A) -> Unit
 ()
end function
function run() -> Unit uses Failure.Fail[String]
 bind v <- empty(seed: ())
 handle
  bind _ <- store(1)
 with
  case store(x) ->
   same(a: v, b: x)
   resume(x)
 end handle
end function
"#;
    let checked = pipeline::check_text(
        "escape.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    let errors: Vec<_> = checked
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .collect();
    assert!(checked.program.is_none());
    assert_eq!(errors.len(), 1, "{errors:#?}");
    assert_eq!(errors[0].code, Some(C::E0401));
    assert!(
        errors[0]
            .notes
            .iter()
            .any(|note| note.contains("cannot leave the clause")),
        "{errors:#?}"
    );
    assert!(
        errors[0]
            .secondary
            .iter()
            .any(|label| label.span.start.0 as usize == source.find("store(x)").unwrap())
    );
}

// 関門: コールバックの引数注釈から、誤りの値や汎用な結果を確定しない。
// 同じ型変数が値と反変の引数の位置に現れる場合だけに起こる退行を公開入口で検査する。
#[test]
fn diagnosed_recovery_does_not_infer_values_from_callback_requirements() {
    use benitoite::diag::DiagCode as C;
    for value in ["SourceLocation.here", "1"] {
        let source = format!(
            "function pick[A](value: A, f: function(value: A) -> Unit) -> A\n return value\nend function\nfunction main() -> Unit\n bind result <- pick(value: {value}, f: lambda(value: Integer) () end lambda)\n bind n: Integer <- result\n bind wrong: String <- result\nend function\n"
        );
        let checked = pipeline::check_text(
            "callback.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let codes: Vec<_> = checked
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect();
        assert_eq!(
            codes,
            if value == "1" {
                vec![C::E0401]
            } else {
                vec![C::E0467]
            },
            "{:#?}",
            checked.diagnostics
        );
        assert!(checked.program.is_none());
    }
}

// 関門: 誤りの全体と部分を区別し、内側も照合する場合の網羅性の見送りを守る。
// 外側だけを照合する既存の表では、この二つの抑制の条件を確認できない。
#[test]
fn diagnosed_recovery_skips_coverage_without_a_known_pattern_shape() {
    use benitoite::diag::DiagCode as C;
    for body in [
        "match SourceLocation.here with case Option.Some(_) -> () end match",
        "match Option.Some(SourceLocation.here) with case Option.Some(1) -> () end match",
    ] {
        let source = format!("function main() -> Unit\n {body}\nend function\n");
        let checked = pipeline::check_text(
            "coverage.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            vec![C::E0467],
            "{:#?}",
            checked.diagnostics
        );
        assert!(checked.program.is_none());
    }
}

// 関門: 元の位置の誤りに続く束縛の連鎖で、長さの三乗の回復処理を再導入しない。
// 大きさ自体を検査するのでlongに分け、stressでは小さくする。公開入口の診断も照合する。
#[test]
#[ignore = "long: checks near-linear recovery of a long chain of diagnosed bindings"]
fn diagnosed_binding_chain_scales_with_input_length() {
    use benitoite::diag::DiagCode as C;
    use std::time::{Duration, Instant};
    let small = if cfg!(feature = "gc-stress") { 64 } else { 128 };
    let mut times = Vec::new();
    for n in [small, small * 4] {
        let mut source = String::from("function main() -> Unit\n bind x0 <- SourceLocation.here\n");
        for i in 1..=n {
            source.push_str(&format!(" bind x{i} <- x{}\n", i - 1));
        }
        source.push_str(" bind n: Integer <- x");
        source.push_str(&n.to_string());
        source.push_str("\n bind s: String <- x");
        source.push_str(&n.to_string());
        source.push_str("\nend function\n");
        let start = Instant::now();
        let checked = pipeline::check_text(
            "chain.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let elapsed = start.elapsed();
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            vec![C::E0467],
            "{:#?}",
            checked.diagnostics
        );
        assert!(checked.program.is_none());
        times.push(elapsed);
        eprintln!("diagnosed binding chain: N={n}, {elapsed:?}");
    }
    assert!(
        times[1] < times[0] * 8 + Duration::from_millis(500),
        "{times:?}"
    );
}

// 関門: 定数の展開を値表で置き換える退行と、同じ元演算の警告の重複を公開checkで検出する。
// 局所変数だけの表では、定数の真偽・未対応演算・宣言自身と複数展開を区別できない。
#[test]
fn constant_intervals_analyze_bodies_and_merge_original_warning_locations() {
    use benitoite::diag::DiagCode as C;
    let cases = [
        (
            "const debug: Boolean = false\nfunction sample() -> Integer\n bind z <- 0\n return if debug then 10 div z else 1 end if\nend function\n",
            vec![],
        ),
        (
            "const k: Integer = 0 div 1\nfunction sample() -> Integer\n bind z <- k\n return 10 div z\nend function\n",
            vec![],
        ),
        // 減算は同じ対象構文で解析し、一点0を呼び出し元の局所束縛へ渡す。
        (
            "const k: Integer = 3 - 3\nfunction sample() -> Integer\n bind z <- k\n return 10 div z\nend function\n",
            vec![C::W0401],
        ),
        // Lean はリテラル同士の整数比較の真偽を両方残すため、右辺の候補を作る。
        (
            "const c: Boolean = 1 > 2 and (10 div 0 = 1)\n",
            vec![C::W0401],
        ),
        (
            "const c: Boolean = 1 < 2 or (10 div 0 = 1)\n",
            vec![C::W0401],
        ),
        // 具体評価では短絡するが、divの結果はTopなので解析では右辺へ到達しうる。
        // 元の宣言だけでも解析し、参照回数を増やしても同じ元位置への警告は一件とする。
        (
            "const c: Boolean = 0 div 1 <> 0 and (10 div 0 = 1)\n",
            vec![C::W0401],
        ),
        (
            "const c: Boolean = 0 div 1 <> 0 and (10 div 0 = 1)\nconst alias: Boolean = c\nfunction sample() -> Boolean\n bind a <- c\n bind b <- alias\n return c or alias\nend function\n",
            vec![C::W0401],
        ),
        // 定数評価の確実な失敗は従来の誤りであり、局所警告を重ねない。
        (
            "const c: Boolean = 1 < 2 and (10 div 0 = 1)\n",
            vec![C::E0435],
        ),
        // 展開の後で呼び出し元の局所区間と由来を復元する。
        (
            "const debug: Boolean = false\nfunction sample() -> Integer\n bind z <- 0\n bind flag <- debug\n return 10 div z\nend function\n",
            vec![C::W0401],
        ),
    ];
    let mut mismatches = Vec::new();
    for (source, expected) in cases {
        let checked = pipeline::check_text(
            "constant-intervals.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count() == 0,
            !expected.contains(&C::E0435),
            "{source}: {:?}",
            checked.diagnostics
        );
        let found = checked
            .diagnostics
            .iter()
            .filter_map(|d| d.code)
            .collect::<Vec<_>>();
        if found != expected {
            mismatches.push(format!("{source}: expected {expected:?}, found {found:?}"));
            continue;
        }
        for warning in checked
            .diagnostics
            .iter()
            .filter(|d| d.code == Some(C::W0401))
        {
            let primary = warning.primary.as_ref().unwrap().span;
            let text = &source[primary.start.0 as usize..primary.end.0 as usize];
            assert!(
                warning
                    .notes
                    .iter()
                    .any(|n| n.starts_with("this local analysis"))
            );
            if source.contains("bind z <-") {
                assert_eq!(text, "z");
                assert_eq!(warning.secondary.len(), 1);
                let span = warning.secondary[0].span;
                assert_eq!(
                    &source[span.start.0 as usize..span.end.0 as usize],
                    if source.contains("bind z <- k") {
                        "bind z <- k"
                    } else {
                        "bind z <- 0"
                    }
                );
            } else {
                assert_eq!(text, "0");
                assert_eq!(
                    primary.start.0 as usize,
                    source.find("10 div 0").unwrap() + 7
                );
                assert!(warning.secondary.is_empty());
            }
        }
    }
    assert!(mismatches.is_empty(), "{}", mismatches.join("\n"));
}

// 関門: 従来の定数警告では検出できない束縛・比較からの算術警告を、
// 公開の検査入口で確かめる。未到達・未知・別名の扱いと旧警告の優先も同じ表で守る。
#[test]
fn local_intervals_report_only_reached_arithmetic_failures() {
    use benitoite::diag::DiagCode as C;
    let cases = [
        // 関門: 同じ公開境界で match の局所事実・選択肢の凸な合流・guard・
        // 腕間の独立性と、整数だけでない照合値の境界を確かめる。
        // 既存の if/短絡の行では腕への未接続や前腕の否定の持ち越しを捕まえられない。
        (
            "return match x with\n case 0 -> 10 div x\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "return match ((x)) with\n case -1..1 if x = 0 -> 10 div x\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "return match x with\n case -9223372036854775808..-9223372036854775808 -> x + -1\n case _ -> 1 end match",
            vec![C::W0402],
            true,
        ),
        (
            "return match x with\n case 9223372036854775807 -> x + 1\n case _ -> 1 end match",
            vec![C::W0402],
            true,
        ),
        (
            "bind z <- 0\n return match z with\n case 1..2 -> 10 div z\n case _ -> 1 end match",
            vec![],
            false,
        ),
        (
            "return match x with\n case -1, 1 if x = 0 -> 10 div x\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "bind z <- 0\n return match z with\n case -1, 0..1 -> 10 div z\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "return match x with\n case n if n = 0 and other = 1 -> 10 div n\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "bind z <- 0\n return match x with\n case n if false -> 10 div z\n case _ -> 1 end match",
            vec![],
            false,
        ),
        (
            "return match x with\n case n if n <> 0 and (10 div n = 1) -> 1\n case _ -> 1 end match",
            vec![],
            false,
        ),
        (
            "return match x with\n case n if n = 0 and (10 div n = 1) -> 1\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "return match x with\n case 0 -> 1\n case _ if x = 0 -> 10 div x\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "bind copy <- x\n return match x with\n case 0 -> 10 div copy\n case _ -> 1 end match",
            vec![],
            false,
        ),
        (
            "return match x with\n case n if n = 0 -> 10 div x\n case _ -> 1 end match",
            vec![],
            false,
        ),
        (
            "bind n <- match x with\n case 0 -> 0\n case _ -> 0 end match\n return 10 div n",
            vec![C::W0401],
            true,
        ),
        (
            "match x with\n case 0 -> ()\n case _ -> () end match\n return 10 div x",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n return match (lambda () -> Integer return 0 end lambda)() with\n case _ -> 10 div z end match",
            vec![],
            false,
        ),
        (
            "bind Pair(v, _) <- Pair(0, true)\n bind z <- 0\n return match v with\n case _ -> 10 div z end match",
            vec![],
            false,
        ),
        (
            "bind n <- 0s8\n bind z <- 0\n return match n with\n case v if v = 0s8 -> 10 div z\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "return match x + 0 with\n case 0 -> 10 div x\n case _ -> 1 end match",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n return match (block return 1 end block) with\n case _ -> 10 div z end match",
            vec![],
            false,
        ),
        (
            "bind Pair(v, _) <- Pair(0, true)\n bind z <- 0\n return if v = 0 then match v with\n case _ -> 10 div z end match else 1 end if",
            vec![],
            false,
        ),
        (
            "return match x with\n case 0 if 10 div x = 1 -> 1\n case _ -> 1 end match",
            vec![C::W0401],
            true,
        ),
        (
            "return match x with\n case n if n = 0 -> 1\n case _ -> 10 div x end match",
            vec![],
            false,
        ),
        (
            "bind n <- match x with\n case 0 -> 9223372036854775807\n case _ -> 9223372036854775807 end match\n return n + 1",
            vec![C::W0402],
            true,
        ),
        ("bind z <- 0\n return 10 div z", vec![C::W0401], true),
        ("bind z <- 0\n return 10 mod z", vec![C::W0401], true),
        (
            "return if x = 0 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "bind n <- 9223372036854775807\n return n + 1",
            vec![C::W0402],
            true,
        ),
        (
            "return if x >= 9223372036854775807 then x + 1 else 1 end if",
            vec![C::W0402],
            true,
        ),
        (
            "bind n <- -9223372036854775808\n return n + -1",
            vec![C::W0402],
            true,
        ),
        (
            "bind z <- 0\n return if false then 10 div z else 1 end if",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n return if z <> 0 then 10 div z else 1 end if",
            vec![],
            false,
        ),
        (
            "return if x = 0 then block if x <> 0 then bind n <- 10 div x end if\n 1 end block else 1 end if",
            vec![],
            false,
        ),
        (
            "bind copy <- x\n return if x = 0 then 10 div copy else 1 end if",
            vec![],
            false,
        ),
        ("return 10 div x", vec![], false),
        (
            "bind z <- 0s8\n bind n <- 10s8 div z\n return 1",
            vec![C::W0401],
            true,
        ),
        (
            "bind n <- 9223372036854775807\n return (n + 1) + (10 div x)",
            vec![C::W0402],
            true,
        ),
        ("return 10 div 0", vec![C::W0401], false),
        ("return 9223372036854775807 + 1", vec![C::W0402], false),
        (
            "bind n <- 10 div zero\n return 20 mod zero",
            vec![C::W0401, C::W0401],
            false,
        ),
        (
            "bind z <- 0\n return if false then 10 div 0 else 1 end if",
            vec![C::W0401],
            false,
        ),
        // リテラル同士の比較は真偽を精密化しない。新候補と旧警告を一件にまとめ、旧警告を採る。
        (
            "bind hit <- 1 > 2 and (10 div 0 = 1)\n return 1",
            vec![C::W0401],
            false,
        ),
        (
            "bind hit <- 1 < 2 or (10 div 0 = 1)\n return 1",
            vec![C::W0401],
            false,
        ),
        // 短絡と複合条件は、単一比較の表で未接続だった右辺の到達と環境の合流を守る。
        // 同じ公開入口と診断を使い、非公開の分類を直接呼ぶ検査は重ねない。
        (
            "return if x < 0 and x >= 0 then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n return if x < 0 or x >= 0 then 1 else 10 div z end if",
            vec![],
            false,
        ),
        (
            "return if not (x = 0 and x = 1) then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "bind hit <- x = 0 and true\n return 10 div x",
            vec![],
            false,
        ),
        (
            "bind hit <- x = 0 and (10 div x = 1)\n return 1",
            vec![C::W0401],
            true,
        ),
        (
            "bind hit <- x <> 0 or (10 div x = 1)\n return 1",
            vec![C::W0401],
            true,
        ),
        (
            "bind hit <- x <> 0 and (10 div x = 1)\n return 1",
            vec![],
            false,
        ),
        (
            "bind hit <- x = 0 or (10 div x = 1)\n return 1",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n bind hit <- false and (10 div z = 1)\n return 1",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n bind hit <- true or (10 div z = 1)\n return 1",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n bind hit <- true and (10 mod z = 1)\n return 1",
            vec![C::W0401],
            true,
        ),
        (
            "bind z <- 0\n bind hit <- false or (10 mod z = 1)\n return 1",
            vec![C::W0401],
            true,
        ),
        (
            "return if x <= 0 and x >= 0 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if x < 0 or x > 0 then 1 else 10 div x end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if not (x <> 0) then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if not (not (x = 0)) then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if x = 0 or x = 1 then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "return if (x = 0 or x = 1) and x < 1 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if (x = 0 or x = 1) and x > 0 then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "return if x = 0 or x = 0 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if x = 0 or false then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if false or x = 0 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "return if x < 0 or x > 0 then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "return if not (x <> 0 and other <> 0) then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "return if x = 0 or other = 0 then 10 div x else 1 end if",
            vec![],
            false,
        ),
        (
            "return if x <= 0 and other = 1 and x >= 0 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "bind copy <- x\n return if x <= 0 and x >= 0 then 10 div copy else 1 end if",
            vec![],
            false,
        ),
        (
            "return if (x = 0 or x = 1) and (other = 0 or other = 1) and x < 1 then 10 div x else 1 end if",
            vec![C::W0401],
            true,
        ),
        (
            "bind z <- 0\n bind hit <- (if flag then true else true end if) or (10 div z = 1)\n return 1",
            vec![],
            false,
        ),
        (
            "bind z <- 0\n bind hit <- (block bind n <- 9223372036854775807\n n + 1 end block) = 0 and (10 div z = 1)\n return 1",
            vec![C::W0402],
            true,
        ),
    ];
    for (body, expected, local) in cases {
        let source = format!(
            "const zero: Integer = 0\nfunction sample(x: Integer, other: Integer, flag: Boolean) -> Integer\n {body}\nend function\n"
        );
        let checked = pipeline::check_text(
            "intervals.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert!(
            checked.program.is_some(),
            "{source}: {:?}",
            checked.diagnostics
        );
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{source}"
        );
        for diagnostic in &checked.diagnostics {
            assert_eq!(
                diagnostic
                    .notes
                    .iter()
                    .any(|n| n.starts_with("this local analysis")),
                local,
                "{source}: {diagnostic:?}"
            );
            assert!(diagnostic.helps.is_empty());
            if local {
                assert!(
                    diagnostic
                        .notes
                        .iter()
                        .any(|n| n.starts_with("the inferred"))
                );
                assert!(!diagnostic.secondary.is_empty());
            }
        }
    }
    // 由来は別名へコピーした時点に固定し、直後の無関係な束縛や外れた枝を含めない。
    let source = "function sample(x: Integer) -> Integer\n return if x = 0 then block\n bind z <- x\n bind unrelated <- 7\n 10 div z\n end block else 1 end if\nend function\n";
    let checked = pipeline::check_text(
        "origins.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert!(checked.program.is_some());
    assert_eq!(checked.diagnostics.len(), 1);
    let diagnostic = &checked.diagnostics[0];
    let primary = diagnostic.primary.as_ref().unwrap().span;
    assert_eq!(
        &source[primary.start.0 as usize..primary.end.0 as usize],
        "z"
    );
    let origins: Vec<_> = diagnostic
        .secondary
        .iter()
        .map(|l| &source[l.span.start.0 as usize..l.span.end.0 as usize])
        .collect();
    assert_eq!(origins, ["bind z <- x", "x = 0"]);
    let mut source = String::from("function chain() -> Integer\n bind x0 <- 0\n");
    for index in 1_usize..12 {
        source.push_str(&format!(" bind x{index} <- x{}\n", index - 1));
    }
    source.push_str(" return 1 div x11\nend function\n");
    let checked = pipeline::check_text(
        "chain.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert!(checked.program.is_some());
    assert_eq!(checked.diagnostics.len(), 1);
    let selected: Vec<_> = checked.diagnostics[0]
        .secondary
        .iter()
        .map(|label| &source[label.span.start.0 as usize..label.span.end.0 as usize])
        .collect();
    assert_eq!(
        selected,
        [
            "bind x11 <- x10",
            "bind x10 <- x9",
            "bind x9 <- x8",
            "bind x8 <- x7",
            "bind x7 <- x6",
            "bind x6 <- x5",
            "bind x5 <- x4",
            "bind x4 <- x3",
        ]
    );
    // 関門: 公開診断で固定長の選択順・合成・重複を守る。件数だけでは、
    // 直近の位置の脱落や同じ根拠の重複を検出できない。新しい差し込み口は不要。
    for (body, expected) in [
        (
            "return match x with\n case n if n = 0 -> 1 div n\n case _ -> 1 end match",
            vec!["n = 0", "n"],
        ),
        (
            "bind root <- 0\n return match root with\n case n if n >= 0 -> 1 div n\n case _ -> 1 end match",
            vec!["n >= 0", "n", "bind root <- 0"],
        ),
        (
            "return match x with\n case 0 -> 1 div x\n case _ -> 1 end match",
            vec!["0"],
        ),
        (
            "bind root <- 0\n bind a <- root\n bind b <- root\n bind z <- a + b\n return 1 div z",
            vec![
                "bind z <- a + b",
                "bind a <- root",
                "bind root <- 0",
                "bind b <- root",
            ],
        ),
        (
            "bind root <- 0\n bind z <- if flag then block bind a <- root\n a end block else block bind b <- root\n b end block end if\n return 1 div z",
            vec![
                "bind z <- if flag then block bind a <- root\n a end block else block bind b <- root\n b end block end if",
                "bind a <- root",
                "bind root <- 0",
                "bind b <- root",
            ],
        ),
        (
            "bind a <- 9223372036854775807\n bind b <- 1\n return a + b",
            vec!["bind a <- 9223372036854775807", "bind b <- 1"],
        ),
        (
            "return if x >= 0 and x <= 0 then 1 div x else 1 end if",
            vec!["x <= 0", "x >= 0"],
        ),
        (
            "return if x = 0 then block bind copy <- x\n if copy >= 0 then 1 div copy else 1 end if end block else 1 end if",
            vec!["copy >= 0", "bind copy <- x", "x = 0"],
        ),
    ] {
        let source = format!(
            "function origins(x: Integer, flag: Boolean) -> Integer\n {body}\nend function\n"
        );
        let checked = pipeline::check_text(
            "selection.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert!(
            checked.program.is_some(),
            "{source}: {:?}",
            checked.diagnostics
        );
        assert_eq!(
            checked.diagnostics.len(),
            1,
            "{source}: {:?}",
            checked.diagnostics
        );
        let selected: Vec<_> = checked.diagnostics[0]
            .secondary
            .iter()
            .map(|label| &source[label.span.start.0 as usize..label.span.end.0 as usize])
            .collect();
        assert_eq!(selected, expected, "{source}");
    }
}

// 関門: 未知の親へ子のフローを合成しないことと、独立入力・別本体の警告を
// 公開の型検査境界で守る。既存表は捕捉・発見・特殊構文を通っていない。
#[test]
fn interval_boundaries_forget_outer_facts_and_keep_inner_warnings() {
    use benitoite::diag::DiagCode as C;
    let preamble = "import Benitoite.Unofficial.Failure\nimport Benitoite.Unofficial.IO.Process\nimport Benitoite.StringBuilder\neffect E\n function get() -> Integer\n function other() -> Integer\nend effect\nrecord Box\n value: Integer\nend record\nfunction id(value: Integer) -> Integer return value end function\nfunction pair(left: Integer, right: Integer) -> Integer return left end function\n";
    let inner = "block bind z <- 0\n 10 div z end block";
    let overflow = "block bind n <- 9223372036854775807\n n + 1 end block";
    let inline = "if x = 0 then 10 div x else 1 end if";
    let cases = [
        ("bind z <- 0\n return id(10 div z)".into(), vec![]),
        (format!("return id({inner})"), vec![C::W0401]),
        (format!("return id(id({inner}))"), vec![C::W0401]),
        (format!("return {inner} - {overflow}"), vec![C::W0401, C::W0402]),
        (format!("return {inner} * 3"), vec![C::W0401]),
        (format!("return -({inner})"), vec![C::W0401]),
        ("bind z <- 0\n bind _ <- id(1)\n return 10 div z".into(), vec![C::W0401]),
        ("return id(block if true then return 1 end if\n bind z <- 0\n 10 div z end block)".into(), vec![]),
        ("if false then bind _ <- id(block bind z <- 0\n 10 div z end block) end if\n return 1".into(), vec![]),
        ("if true then return 1 end if\n bind _ <- id(block bind z <- 0\n 10 div z end block)\n return 2".into(), vec![]),
        (format!("bind _ <- [{inner}, {overflow}]\n return 1"), vec![C::W0401, C::W0402]),
        (format!("bind _ <- [{inner}, ..[1], {overflow}]\n return 1"), vec![C::W0401, C::W0402]),
        (format!("bind _ <- \"${{{inline}}}\"\n return 1"), vec![C::W0401]),
        (format!("bind _ <- Box(value: {inner})\n return 1"), vec![C::W0401]),
        (format!("bind original <- Box(value: 1)\n bind _ <- Box(..original, value: {inner})\n return 1"), vec![C::W0401]),
        (format!("bind _ <- pair(left: _, right: {inner})\n return 1"), vec![C::W0401]),
        (format!("bind _ <- Pair(_, {inner})\n return 1"), vec![C::W0401]),
        (format!("return {inner} |> id"), vec![C::W0401]),
        ("bind z <- 0\n bind _ <- lambda() -> Integer return 10 div z end lambda\n return 1".into(), vec![]),
        ("bind _ <- lambda() -> Integer\n bind z <- 0\n return 10 div z end lambda\n return 1".into(), vec![C::W0401]),
        ("bind _ <- lambda(z: Integer) -> Integer return if z = 0 then 10 div z else 1 end if end lambda\n return 1".into(), vec![C::W0401]),
        ("bind z <- 0\n bind _ <- lazy 10 div z end lazy\n return 1".into(), vec![]),
        ("bind _ <- lazy bind z <- 0\n 10 div z end lazy\n return 1".into(), vec![C::W0401]),
        ("if false then bind _ <- lambda() -> Integer\n bind z <- 0\n return 10 div z end lambda end if\n return 1".into(), vec![C::W0401]),
        ("if true then return 1 end if\n bind _ <- lazy bind z <- 0\n 10 div z end lazy\n return 2".into(), vec![C::W0401]),
        ("bind z <- 0\n bind _ <- handle 10 div z with case get() -> 1 end handle\n return 1".into(), vec![]),
        ("bind z <- 0\n bind _ <- handle get() with case get() -> 10 div z end handle\n return 1".into(), vec![]),
        ("bind _ <- handle get() with case get() -> bind z <- 0\n 10 div z end handle\n return 1".into(), vec![C::W0401]),
        ("bind _ <- handle block bind z <- 0\n 10 div z end block with case get() -> 1 end handle\n return 1".into(), vec![C::W0401]),
        ("bind _ <- handle Failure.raise(\"bad\") with case Failure.raise(error) -> bind z <- 0\n 10 div z end handle\n return 1".into(), vec![C::W0401]),
        (format!("bind _ <- try Option.Some({inner}) or die(\"bad\")\n return 1"), vec![C::W0401]),
        (format!("bind _ <- try Option.Some(1) or die(\"${{{inline}}}\")\n return 1"), vec![C::W0401]),
        ("bind z <- 0\n with first = TaskGroup.open(), second = TaskGroup.open() do\n bind _ <- 10 div z\n end with\n return 1".into(), vec![]),
        ("with first = TaskGroup.open(), second = TaskGroup.open() do\n bind z <- 0\n bind _ <- 10 div z\n end with\n return 1".into(), vec![C::W0401]),
        (format!("bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(text: \"${{{inline}}}\", builder: b)\n return 1"), vec![C::W0401]),
    ];
    for (body, expected) in cases {
        let source = format!(
            "{preamble}function sample(x: Integer) -> Integer uses State, Process.Exit, E\n {body}\nend function\n"
        );
        let checked = pipeline::check_text(
            "boundaries.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert!(
            checked.program.is_some(),
            "{source}: {:?}",
            checked.diagnostics
        );
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{source}"
        );
    }
}
