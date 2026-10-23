//! 書式と合併済み契約の交換（設計書07-04「書式付き補間の交換形式」）。
use super::*;

// 関門: 型検査済み表層の書式・省略と内部頭を、独立したLeanの脱糖へ渡す。
// VMの出力テストではstringExprへの読み落としや交換表の欠落を検出できない。
// 公開pipelineと既存の交換を使い、本番への差し込み口は増やさない。
#[test]
fn export_batch5_formats() {
    let types = [
        "Integer",
        "Integer8",
        "Integer16",
        "Integer32",
        "Byte",
        "UnsignedInteger16",
        "UnsignedInteger32",
        "UnsignedInteger64",
        "Float",
        "Float32",
        "Decimal",
        "String",
        "Character",
        "Boolean",
    ];
    let mut source = String::new();
    for (index, ty) in types.iter().enumerate() {
        source.push_str(&format!("function format{index}(value: {ty}) -> String\n return \"${{value:8}}\"\nend function\n"));
    }
    for (index, ty, spec) in [
        (14, "Integer", "65535d"),
        (15, "Integer", "#65535b"),
        (16, "Integer", "#65535o"),
        (17, "Integer", "#65535x"),
        (18, "Integer", "#65535X"),
        (19, "Float", "f"),
        (20, "Float32", ".0f"),
        (21, "Decimal", "+08.28f"),
        (22, "String", "<1s"),
        (23, "Character", ">8c"),
        (24, "Boolean", "^8"),
    ] {
        source.push_str(&format!("function format{index}(value: {ty}) -> String\n return \"${{value:{spec}}}\"\nend function\n"));
    }
    source.push_str("function mixed(value: String) -> String\n return \"${value:8}${value}\"\nend function\nfunction plain(value: Integer) -> String\n return \"${value}\"\nend function\nfunction coverage(value: Integer) -> Integer\n return match value with case _ -> 0 end match\nend function\n");
    let directory = std::env::var_os("BENITOITE_DESUGAR_DIFF_DIR").map_or_else(
        || Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/formal-batch5"),
        |p| PathBuf::from(p).join("batch5"),
    );
    fs::create_dir_all(&directory).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut export = named::Export::new();
    for (name, text) in [
        ("formats", source),
        ("file-uses", effects_source(true)),
        ("individual-uses", effects_source(false)),
    ] {
        let checked = pipeline::check_text(
            name,
            text.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        export.push("golden", name, checked.program.as_ref().unwrap(), &stdlib);
        let input = export.inputs.last().unwrap();
        assert_eq!(input["excluded"], json!([]));
        assert!(
            input["definitions"]
                .as_array()
                .unwrap()
                .iter()
                .all(|d| d["scope"].get("inScope").is_some())
        );
    }
    let formats = export.tables[0]["prims"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|p| p["name"].as_str())
        .filter(|n| n.starts_with("%Format."))
        .collect::<Vec<_>>();
    assert_eq!(formats.len(), 14);
    for ty in types {
        assert!(formats.contains(&format!("%Format.{ty}").as_str()));
    }
    // 元のASTの書き方によらず、NoFail・行・本体とE2の宣言表を一致させる。
    for field in ["definitions", "effects", "ops", "primOps", "constants"] {
        assert_eq!(export.inputs[1][field], export.inputs[2][field], "{field}");
    }
    let mut file_table = export.tables[1].clone();
    let mut individual_table = export.tables[2].clone();
    file_table["name"] = Value::Null;
    individual_table["name"] = Value::Null;
    assert_eq!(file_table, individual_table);
    write_batch2(&directory, export);
}

fn effects_source(file: bool) -> String {
    let declaration = if file {
        "uses Log, Failure.Fail[String]\n"
    } else {
        ""
    };
    let suffix = if file {
        ""
    } else {
        " uses Log, Failure.Fail[String]"
    };
    format!(
        "import Benitoite.Unofficial.Failure\n{declaration}function sample(value: Integer) -> String{suffix}\n return \"${{value:8}}\"\nend function\nfunction apply[A, effect E](value: A, f: function(value: A) -> A uses E) -> A uses E{extra}\n return f(value)\nend function\n",
        extra = if file {
            ""
        } else {
            ", Log, Failure.Fail[String]"
        }
    )
}
