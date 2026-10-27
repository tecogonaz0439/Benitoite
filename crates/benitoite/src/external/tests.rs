//! 外部の関数の検査の契約を、本物のパイプラインとコンポーネントで確かめる（設計書 03-10）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::diag::DiagCode;
use crate::pipeline::{self, CheckOptions};

const ADD: &str = r#"(component
    (core module $m (func (export "add") (param i64 i64) (result i64) local.get 0 local.get 1 i64.add))
    (core instance $i (instantiate $m))
    (func (export "add") (param "a" s64) (param "b" s64) (result s64)
        (canon lift (core func $i "add"))))"#;

fn check(source: &str, bytes: &[u8]) -> pipeline::CheckResult {
    pipeline::check_files(
        &[("main.bnt", source.as_bytes()), ("wasm/x.wasm", bytes)],
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
}
fn declaration(params: &str, ret: &str, export: &str) -> String {
    format!(
        "@external(\"wasm\", \"wasm/x.wasm\", \"{export}\")\nfunction externalFn({params}) -> {ret}\nfunction main() -> Unit\n()\nend function\n"
    )
}
fn codes(result: &pipeline::CheckResult) -> Vec<DiagCode> {
    result
        .diagnostics
        .iter()
        .filter_map(|d| d.is_error().then_some(d.code).flatten())
        .collect()
}

#[test]
fn component_and_signature_errors() {
    // spec: 01-02 外部の関数の宣言
    // 関門: 完全な書き出しの名前と属性の区切りをパイプラインの境界で検査する。
    // 既存の表は world の直下だけを扱い、版の互換検索や空の名前の退行を捕まえない。
    let interface =
        wat::parse_str(include_str!("../../testdata/external/interface/x.wat")).unwrap();
    let add = wat::parse_str(ADD).unwrap();
    let cases = [
        (
            declaration("a: Integer, b: Integer", "Integer", "add"),
            add.clone(),
            None,
        ),
        (
            declaration("a: Integer", "Integer", "add"),
            add.clone(),
            Some(DiagCode::E1007),
        ),
        (
            declaration("a: Integer, b: Integer", "Unit", "add"),
            add.clone(),
            Some(DiagCode::E1009),
        ),
        (
            declaration("a: Integer, b: Integer", "String", "add"),
            add.clone(),
            Some(DiagCode::E1009),
        ),
        (
            declaration("", "Unit", "add"),
            b"hello".to_vec(),
            Some(DiagCode::E1004),
        ),
        (
            declaration("", "Unit", "add"),
            wat::parse_str("(module)").unwrap(),
            Some(DiagCode::E1004),
        ),
        (
            declaration("", "Unit", "add"),
            b"\0asm\x02\0\0\0".to_vec(),
            Some(DiagCode::E1004),
        ),
        (
            declaration("", "Unit", "add"),
            b"\0asm\x0d\0\x01\0\xff".to_vec(),
            Some(DiagCode::E1004),
        ),
        (
            declaration("", "Unit", "missing"),
            add,
            Some(DiagCode::E1006),
        ),
        (
            declaration("", "Unit", "nested"),
            wat::parse_str("(component (instance (export \"nested\")))").unwrap(),
            Some(DiagCode::E1006),
        ),
    ];
    let cases = cases.into_iter().chain([
        (
            declaration(
                "a: Integer, b: Integer",
                "Integer",
                "bnt:test/api@1.2.0#add",
            ),
            interface.clone(),
            None,
        ),
        (declaration("", "Integer", "top"), interface.clone(), None),
        (
            declaration(
                "a: Integer, b: Integer",
                "Integer",
                "bnt:test/api@1.9.9#add",
            ),
            interface.clone(),
            Some(DiagCode::E1006),
        ),
        (
            declaration("a: Integer, b: Integer", "Integer", "bnt:test/api#add"),
            interface.clone(),
            Some(DiagCode::E1006),
        ),
        (
            declaration("", "Unit", "#api#add"),
            interface.clone(),
            Some(DiagCode::E1006),
        ),
        (
            declaration("", "Unit", "bnt:test/api@1.2.0#[method]pattern.is-match"),
            interface.clone(),
            Some(DiagCode::E1006),
        ),
        (
            declaration("", "Unit", "#add"),
            interface.clone(),
            Some(DiagCode::E0815),
        ),
        (
            declaration("", "Unit", "bnt:test/api@1.2.0#"),
            interface.clone(),
            Some(DiagCode::E0815),
        ),
        (
            declaration("", "Unit", "#"),
            interface,
            Some(DiagCode::E0815),
        ),
    ]);
    for (source, bytes, expected) in cases {
        let result = check(&source, &bytes);
        assert_eq!(
            codes(&result),
            expected.into_iter().collect::<Vec<_>>(),
            "{source}: {:?}",
            result.diagnostics
        );
        assert_eq!(result.program.is_some(), expected.is_none());
        if expected == Some(DiagCode::E0815) {
            let span = result.diagnostics[0].primary.as_ref().unwrap().span;
            assert_eq!(
                &source[span.start.0 as usize..span.end.0 as usize],
                source
                    .split(',')
                    .nth(2)
                    .unwrap()
                    .split(')')
                    .next()
                    .unwrap()
                    .trim()
            );
        }
    }
    let notes = [
        (b"hello".to_vec(), "magic bytes"),
        (wat::parse_str("(module)").unwrap(), "core WebAssembly"),
        (b"\0asm\x02\0\0\0".to_vec(), "version"),
    ];
    for (bytes, note) in notes {
        let result = check(&declaration("", "Unit", "x"), &bytes);
        assert!(result.diagnostics[0].notes.iter().any(|s| s.contains(note)));
    }
}

fn typed_component(wit: &str, core_params: &str, core_result: &str) -> Vec<u8> {
    let exported_type = if ["(record", "(variant", "(enum", "(flags"]
        .iter()
        .any(|prefix| wit.starts_with(prefix))
    {
        "(export $public \"t\" (type $t))"
    } else {
        ""
    };
    let value_type = if exported_type.is_empty() {
        "$t"
    } else {
        "$public"
    };
    let wat = format!(
        r#"(component
            (core module $m
                (memory (export "memory") 1)
                (func (export "realloc") (param i32 i32 i32 i32) (result i32) unreachable)
                (func (export "f") (param {core_params}) (result {core_result}) unreachable))
            (core instance $i (instantiate $m))
            (type $t {wit})
            {exported_type}
            (func (export "f") (param "different-name" {value_type}) (result {value_type})
                (canon lift (core func $i "f") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    wat::parse_str(&wat).unwrap()
}

#[test]
fn supported_types_and_aliases_produce_matching_plans() {
    // 合成の型は引数と戻り値の両方で照合し、Unit の省略も確認する。
    let cases = [
        ("Integer", "s64", "i64", "i64"),
        ("Integer64", "s64", "i64", "i64"),
        ("Integer8", "s8", "i32", "i32"),
        ("Integer16", "s16", "i32", "i32"),
        ("Integer32", "s32", "i32", "i32"),
        ("UnsignedInteger16", "u16", "i32", "i32"),
        ("UnsignedInteger32", "u32", "i32", "i32"),
        ("UnsignedInteger64", "u64", "i64", "i64"),
        ("UnsignedInteger", "u64", "i64", "i64"),
        ("Float32", "f32", "f32", "f32"),
        ("Float", "f64", "f64", "f64"),
        ("Float64", "f64", "f64", "f64"),
        ("Boolean", "bool", "i32", "i32"),
        ("Character", "char", "i32", "i32"),
        ("String", "string", "i32 i32", "i32"),
        ("Byte", "u8", "i32", "i32"),
        ("UnsignedInteger8", "u8", "i32", "i32"),
        ("Bytes", "(list u8)", "i32 i32", "i32"),
        ("List[Byte]", "(list u8)", "i32 i32", "i32"),
        ("List[Integer]", "(list s64)", "i32 i32", "i32"),
        ("List[Float]", "(list f64)", "i32 i32", "i32"),
        ("List[Integer32]", "(list s32)", "i32 i32", "i32"),
        ("List[UnsignedInteger8]", "(list u8)", "i32 i32", "i32"),
        ("List[Integer64]", "(list s64)", "i32 i32", "i32"),
        ("List[Float64]", "(list f64)", "i32 i32", "i32"),
        ("Octets", "(list u8)", "i32 i32", "i32"),
        ("Numbers", "(list s64)", "i32 i32", "i32"),
        ("Floats", "(list f64)", "i32 i32", "i32"),
        ("Option[Integer]", "(option s64)", "i32 i64", "i32"),
        (
            "Result[Integer, String]",
            "(result s64 (error string))",
            "i32 i64 i32",
            "i32",
        ),
        (
            "Result[Unit, String]",
            "(result (error string))",
            "i32 i32 i32",
            "i32",
        ),
        ("Result[Integer, Unit]", "(result s64)", "i32 i64", "i32"),
        ("Result[Unit, Unit]", "(result)", "i32", "i32"),
        (
            "Pair[Integer, String]",
            "(tuple s64 string)",
            "i64 i32 i32",
            "i32",
        ),
        (
            "Triple[Integer, Boolean, Byte]",
            "(tuple s64 bool u8)",
            "i64 i32 i32",
            "i32",
        ),
        ("Number", "s64", "i64", "i64"),
    ];
    for (declared, wit, core_params, core_result) in cases {
        let bytes = typed_component(wit, core_params, core_result);
        let source = format!(
            "type Number = Integer\ntype Octets = List[Byte]\ntype Numbers = List[Integer]\ntype Floats = List[Float]\n{}",
            declaration(&format!("x: {declared}"), declared, "f")
        );
        let result = check(&source, &bytes);
        assert!(
            result.diagnostics.is_empty(),
            "{declared}: {:?}",
            result.diagnostics
        );
        let program = result.program.unwrap();
        let spec = program
            .resolved
            .externals
            .iter()
            .next()
            .unwrap()
            .1
            .spec
            .as_ref()
            .unwrap();
        assert_eq!(spec.params.len(), 1);
        assert_eq!(spec.result.as_ref(), spec.params.first());
        if matches!(
            declared,
            "Octets"
                | "Numbers"
                | "Floats"
                | "Integer64"
                | "Float64"
                | "List[UnsignedInteger8]"
                | "List[Integer64]"
                | "List[Float64]"
        ) {
            assert!(matches!(spec.route, ExternalRoute::Typed(_)));
        }
        if matches!(
            declared,
            "Integer8"
                | "Integer16"
                | "Integer32"
                | "UnsignedInteger16"
                | "UnsignedInteger32"
                | "UnsignedInteger64"
                | "UnsignedInteger"
                | "Float32"
                | "List[Integer32]"
                | "UnsignedInteger8"
        ) {
            assert_eq!(spec.route, ExternalRoute::Dynamic);
            assert!(spec.adapter.is_some());
        }
        let mismatch = check(
            &format!(
                "type Number = Integer\ntype Octets = List[Byte]\ntype Numbers = List[Integer]\ntype Floats = List[Float]\n{}",
                declaration("", declared, "f")
            ),
            &bytes,
        );
        assert_eq!(codes(&mismatch), vec![DiagCode::E1007]);
        let expected = match declared {
            "List[Byte]" | "List[UnsignedInteger8]" | "Octets" => "Bytes",
            "Integer64" => "Integer",
            "Float64" => "Float",
            "UnsignedInteger8" => "Byte",
            "UnsignedInteger" => "UnsignedInteger64",
            "List[Integer64]" => "List[Integer]",
            "List[Float64]" => "List[Float]",
            "Numbers" => "List[Integer]",
            "Floats" => "List[Float]",
            "Number" => "Integer",
            ty => ty,
        };
        assert!(mismatch.diagnostics[0].notes.contains(&format!(
            "the component function corresponds to `function externalFn(differentName: {expected}) -> {expected}`"
        )));
    }
    let unit = wat::parse_str(
        r#"(component (core module $m (func (export "f")))
        (core instance $i (instantiate $m)) (func (export "f") (canon lift (core func $i "f"))))"#,
    )
    .unwrap();
    assert!(
        check(&declaration("", "Unit", "f"), &unit)
            .program
            .is_some()
    );
    let mismatch = check(&declaration("", "Integer", "f"), &unit);
    assert_eq!(codes(&mismatch), vec![DiagCode::E1009]);
    assert!(mismatch.diagnostics[0].notes.contains(
        &"the component function corresponds to `function externalFn() -> Unit`".to_owned()
    ));
}

// 関門: 注記の宣言をそのまま使っても引数名が構文の誤りにならない。
// 既存の対応表は予約語と大文字の略語を含まず、この退行を捕まえない。
// spec: 03-10 照合
#[test]
fn declaration_notes_use_lowercase_non_keyword_parameter_names() {
    for (wit_name, other_name, expected) in [
        ("data", "b", "arg1"),
        ("URL", "b", "url"),
        ("URL-path", "b", "urlPath"),
        ("data", "arg1", "arg2"),
    ] {
        let bytes = wat::parse_str(
            ADD.replace("\"a\"", &format!("\"{wit_name}\""))
                .replace("\"b\"", &format!("\"{other_name}\"")),
        )
        .unwrap();
        let result = check(&declaration("", "Integer", "add"), &bytes);
        assert_eq!(codes(&result), [DiagCode::E1007]);
        let expected =
            format!("function externalFn({expected}: Integer, {other_name}: Integer) -> Integer");
        assert!(
            result.diagnostics[0].notes.contains(&format!(
                "the component function corresponds to `{expected}`"
            )),
            "{:?}",
            result.diagnostics
        );
        assert!(check(&format!("@external(\"wasm\", \"wasm/x.wasm\", \"add\")\n{expected}\nfunction main() -> Unit\n()\nend function"), &bytes).diagnostics.is_empty());
    }
}

// 関門: 照合できる大きさの型でも、診断の型の表示は 2,000 文字で止める。
// 深さと節点数の検査は、この表示の上限を守らない。
// spec: 03-10 型の対応
#[test]
fn mismatch_type_displays_are_bounded() {
    let mut wit = "(record".to_owned();
    let mut declaration_source = "record Large\n".to_owned();
    for n in 0..250 {
        wit += &format!(" (field \"field{n}\" s64)");
        declaration_source += &format!("field{n}: Float\n");
    }
    wit += ")";
    declaration_source += "end record\n";
    declaration_source += &declaration("v: Large", "Large", "f");
    let bytes = typed_component(&wit, "i32", "i32");
    let result = check(&declaration_source, &bytes);
    assert_eq!(codes(&result), [DiagCode::E1008, DiagCode::E1009]);
    for diagnostic in result.diagnostics {
        assert_eq!(
            diagnostic
                .notes
                .iter()
                .map(|n| n.matches('…').count())
                .sum::<usize>(),
            2,
            "{diagnostic:?}"
        );
        assert!(diagnostic.notes.iter().all(|n| n.chars().count() < 2_050));
    }
    let mut declared = "Integer".to_owned();
    let mut wit = "s64".to_owned();
    for _ in 0..6 {
        declared = format!("Triple[{declared}, {declared}, {declared}]");
        wit = format!("(tuple {wit} {wit} {wit})");
    }
    let result = check(
        &declaration(&format!("v: {declared}"), &declared, "f"),
        &typed_component(&wit, "i32", "i32"),
    );
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    let result = check(
        &declaration(&format!("v: {declared}"), &declared, "f"),
        &typed_component(&wit.replace("s64", "f64"), "i32", "i32"),
    );
    assert_eq!(codes(&result), [DiagCode::E1008, DiagCode::E1009]);
    for diagnostic in result.diagnostics {
        assert!(diagnostic.primary.as_ref().unwrap().text.contains('…'));
        assert!(diagnostic.primary.as_ref().unwrap().text.chars().count() < 2_050);
        let maps = diagnostic
            .notes
            .iter()
            .find(|note| note.contains("is passed as"))
            .unwrap();
        assert_eq!(maps.matches('…').count(), 2);
        assert!(maps.chars().count() < 4_050);
    }
}

// 関門: 利用者の同名の型と標準ライブラリの型の取り違えを照合の診断で説明する。
// E1010 の表だけでは、展開できる型の E1008・E1009 の注記を守れない。
// spec: 03-10 型の対応
#[test]
fn user_named_standard_types_are_identified_in_mismatches() {
    let source = "data Result\nOk(Integer)\nError(String)\nend data\n".to_owned()
        + &declaration("r: Result", "Result", "f");
    let result = check(
        &source,
        &typed_component("(result s64 (error string))", "i32 i64 i32", "i32"),
    );
    assert_eq!(codes(&result), [DiagCode::E1008, DiagCode::E1009]);
    for diagnostic in result.diagnostics {
        assert!(
            diagnostic.notes.contains(
                &"`Result` here is the type declared in `main.bnt`, not `Benitoite.Result.Result`"
                    .into()
            ),
            "{diagnostic:?}"
        );
    }
}

#[test]
fn numeric_mismatches_preserve_widths_and_declaration_notes() {
    // 関門: 幅と符号の異なる数を暗黙に変換せず、両方向の診断に修正可能な宣言を示す。
    // 成功の対応表と実行のゴールデンだけでは、誤った数の型を受理する退行を捕まえない。
    for (wit, core_params, core_result, expected, wrong, passed) in [
        ("s8", "i32", "i32", "Integer8", "Integer16", "s16"),
        ("s16", "i32", "i32", "Integer16", "Integer8", "s8"),
        ("s32", "i32", "i32", "Integer32", "UnsignedInteger32", "u32"),
        ("s64", "i64", "i64", "Integer", "UnsignedInteger64", "u64"),
        ("u8", "i32", "i32", "Byte", "Integer8", "s8"),
        ("u16", "i32", "i32", "UnsignedInteger16", "Integer16", "s16"),
        ("u32", "i32", "i32", "UnsignedInteger32", "Integer32", "s32"),
        ("u64", "i64", "i64", "UnsignedInteger64", "Integer", "s64"),
        ("f32", "f32", "f32", "Float32", "Float", "f64"),
        ("f64", "f64", "f64", "Float", "Float32", "f32"),
        (
            "(list s32)",
            "i32 i32",
            "i32",
            "List[Integer32]",
            "List[Integer]",
            "list<s64>",
        ),
    ] {
        let bytes = typed_component(wit, core_params, core_result);
        for params in [String::new(), format!("a: {wrong}")] {
            let result = check(&declaration(&params, wrong, "f"), &bytes);
            assert_eq!(
                codes(&result),
                if params.is_empty() {
                    vec![DiagCode::E1007, DiagCode::E1009]
                } else {
                    vec![DiagCode::E1008, DiagCode::E1009]
                },
                "{wit}: {:?}",
                result.diagnostics
            );
            for diagnostic in &result.diagnostics {
                assert!(diagnostic.notes.contains(&format!(
                    "the component function corresponds to `function externalFn(differentName: {expected}) -> {expected}`"
                )));
                if diagnostic.code != Some(DiagCode::E1007) {
                    assert!(
                        diagnostic
                            .notes
                            .contains(&format!("`{wrong}` is passed as `{passed}`"))
                    );
                }
            }
        }
    }
}

// 関門: WIT の型に対応する名前がない場合に、推測した宣言を診断に出さない。
// 型が一致する既存の表では、照合の誤りの注記の省略を確かめられない。
#[test]
fn unmapped_component_types_omit_declaration_notes() {
    for (wit, core_params, core_result) in [
        ("(record (field \"x\" s64))", "i64", "i64"),
        ("(tuple s64)", "i64", "i64"),
        (
            "(variant (case \"one\" s64) (case \"none\"))",
            "i32 i64",
            "i32",
        ),
        ("(enum \"one\" \"two\")", "i32", "i32"),
    ] {
        let bytes = typed_component(wit, core_params, core_result);
        for params in ["", "a: Integer"] {
            let result = check(&declaration(params, "Integer", "f"), &bytes);
            assert_eq!(
                codes(&result),
                if params.is_empty() {
                    vec![DiagCode::E1007, DiagCode::E1009]
                } else {
                    vec![DiagCode::E1008, DiagCode::E1009]
                }
            );
            assert!(
                result
                    .diagnostics
                    .iter()
                    .all(|d| d.notes.iter().all(|note| !note.contains("corresponds to")))
            );
        }
    }
}

#[test]
fn unsupported_types_are_rejected_at_the_declared_type() {
    let bytes = wat::parse_str(ADD).unwrap();
    for (ty, unsupported) in [
        ("Decimal", "Decimal"),
        ("Map[Decimal, Integer]", "Decimal"),
        ("Set[Integer]", "Set[Integer]"),
        ("Unit", "Unit"),
        ("List[Unit]", "Unit"),
        ("Option[Unit]", "Unit"),
        ("Pair[Integer, Unit]", "Unit"),
        ("Task[Integer]", "Task[Integer]"),
        (
            "(function(value: Integer) -> Integer)",
            "function(value: Integer) -> Integer",
        ),
    ] {
        let source = declaration(&format!("a: {ty}"), "Integer", "add");
        let result = check(&source, &bytes);
        assert_eq!(
            codes(&result),
            vec![DiagCode::E1010],
            "{ty}: {:?}",
            result.diagnostics
        );
        let span = result.diagnostics[0].primary.as_ref().unwrap().span;
        assert_eq!(&source[span.start.0 as usize..span.end.0 as usize], ty);
        assert!(
            result.diagnostics[0]
                .message
                .starts_with(&format!("`{unsupported}`")),
            "{:?}",
            result.diagnostics
        );
    }
}

// 関門: flags の項目数、名前と宣言順、引数なしの具体的な data という契約を照合で守る。
// 既存の enum の表では Set の要素型の制約を検出できず、配置と実行はゴールデンで守る。
#[test]
fn flags_match_concrete_data_and_reject_invalid_members() {
    let too_many = (1..=33).map(|i| format!("F{i}\n")).collect::<String>();
    let cases = [
        (
            "data D[T]\nBlueIsh\nRed\nend data\n".to_owned(),
            "Set[D[Integer]]",
            "(flags \"blue-ish\" \"red\")",
            None,
            "",
        ),
        (
            "data D\nBlue\nRed\nend data\n".to_owned(),
            "Set[D]",
            "(flags \"red\" \"blue\")",
            Some(DiagCode::E1008),
            "flag 1 is `red`",
        ),
        (
            "data D\nBlue\nend data\n".to_owned(),
            "Set[D]",
            "(flags \"blue\" \"red\")",
            Some(DiagCode::E1008),
            "WIT has 2 flags",
        ),
        (
            "data D\nByteStart\nBytestart\nend data\n".to_owned(),
            "Set[D]",
            "(flags \"byte-start\" \"other\")",
            Some(DiagCode::E1008),
            "in the declaration duplicates",
        ),
        (
            "data D\nABc\nOther\nend data\n".to_owned(),
            "Set[D]",
            "(flags \"a-bc\" \"ab-c\")",
            Some(DiagCode::E1008),
            "in WIT duplicates",
        ),
        (
            "data D\nBlue(Integer)\nend data\n".to_owned(),
            "Set[D]",
            "(flags \"blue\")",
            Some(DiagCode::E1010),
            "every constructor takes no arguments",
        ),
        (
            format!("data D\n{too_many}end data\n"),
            "Set[D]",
            "(flags \"blue\")",
            Some(DiagCode::E1010),
            "1 to 32 constructors",
        ),
        (
            "record D\nx: Integer\nend record\n".to_owned(),
            "Set[D]",
            "(flags \"x\")",
            Some(DiagCode::E1010),
            "concrete data type",
        ),
    ];
    for (defs, ty, wit, code, reason) in cases {
        let source = defs + &declaration(&format!("v: {ty}"), ty, "f");
        // 宣言で分かる拒否は、壊れたコンポーネントより先に出なければならない。
        let bytes = if code == Some(DiagCode::E1010) {
            b"bad component".to_vec()
        } else {
            typed_component(wit, "i32", "i32")
        };
        let result = check(&source, &bytes);
        let expected = match code {
            Some(DiagCode::E1008) => vec![DiagCode::E1008, DiagCode::E1009],
            Some(code) => vec![code, code],
            None => vec![],
        };
        assert_eq!(
            codes(&result),
            expected,
            "{source}: {:?}",
            result.diagnostics
        );
        for diagnostic in &result.diagnostics {
            assert!(
                diagnostic.notes.iter().any(|note| note.contains(reason)),
                "{reason}: {diagnostic:?}"
            );
        }
    }
    // 構成子が零の data は外部の照合に進む前に、型検査で拒否される。
    let result = check(
        &("data D\nend data\n".to_owned() + &declaration("v: Set[D]", "Unit", "f")),
        b"bad component",
    );
    assert_eq!(codes(&result), vec![DiagCode::E0411]);
}

// 関門: 選択された名前のバイト数だけを両方向の予算と統計へ数える。
// 配置のゴールデンでは、小さい予算の前後と戻り値の hostcall fuel を確かめられない。
#[test]
fn dynamic_flags_transfer_budgets_count_selected_names_in_both_directions() {
    use super::stats::{Collector, ExecutionOptions};
    use crate::runtime::heap::{CtorTag, Heap, HeapConfig, Value};
    use crate::runtime::{ResourceError, Stop, map};
    let bytes = wat::parse_str(
        r#"(component
        (core module $m (func (export "f") (param i32) (result i32) i32.const 2))
        (core instance $i (instantiate $m))
        (type $t (flags "x" "long-name"))
        (export $flags "flags" (type $t))
        (func (export "f") (param "v" $flags) (result $flags)
            (canon lift (core func $i "f"))))"#,
    )
    .unwrap();
    let result = check(
        &("data D\nX\nLongName\nend data\n".to_owned() + &declaration("v: Set[D]", "Set[D]", "f")),
        &bytes,
    );
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    let checked = result.program.unwrap();
    let core = pipeline::desugar_checked(&checked).unwrap();
    let mut program = pipeline::compile(&core, Arc::clone(&result.sources)).unwrap();
    // 動的への事前の振り分けでも、名前の長さで数える既存の予算を保つ。
    Arc::make_mut(&mut program.externals.functions[0].spec).adapter = None;
    let table = &program.externals;
    let WitPlan::Flags { cases } = &table.functions[0].spec.params[0] else {
        panic!("flags plan missing")
    };
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let selected = cases
            .iter()
            .map(|(_, tag)| Value::Tag(CtorTag(*tag)))
            .collect::<Vec<_>>();
        let both = map::set_from_sorted(ctx, &selected, "test").unwrap();
        for (arg, cost, limit, succeeds) in [
            (Value::EmptySet, 0, 8, false),
            (Value::EmptySet, 0, 9, true),
            (both, 10, 9, false),
            (both, 10, 10, true),
        ] {
            let stats = Collector::new();
            let mut runtime = ExternalRuntime::configured(
                None,
                ExecutionOptions {
                    session: None,
                    limits: Limits {
                        transfer: limit,
                        ..Limits::default()
                    },
                    stats: Some(stats.clone()),
                },
            )
            .unwrap();
            let result = call(&mut runtime, table, 0, ctx, &[arg]);
            if succeeds {
                let set = result.unwrap();
                assert_eq!(map::set_len(ctx, set).unwrap(), 1);
                assert!(map::set_contains(ctx, set, selected[1]).unwrap());
                let json = stats.json().unwrap();
                assert_eq!(json["routes"]["dynamic"], 1);
                assert_eq!(json["arguments_transfer"]["total"], cost);
                assert_eq!(json["results_transfer"]["total"], 9);
            } else {
                assert!(
                    matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalTransfer { .. }
                        )))
                    ),
                    "{result:?}"
                );
            }
        }
    });
}

// 関門: 構造の照合と名前の正規化を、診断と検査の成否で守る。
// 既存の表は名前のない型だけを扱う。ABI の往復は CLI のゴールデンで確かめる。
// spec: 03-10 型の対応
#[test]
fn aggregate_types_match_structure_and_normalized_names() {
    let cases = [
        (
            "record Point\nhttpError: Integer\nend record\n",
            "Point",
            "(record (field \"HTTP-error\" s64))",
            "i64",
            "i64",
        ),
        (
            "data Color\nRed\nBlueIsh\nend data\n",
            "Color",
            "(variant (case \"red\") (case \"blue-ish\"))",
            "i32",
            "i32",
        ),
        (
            "import Benitoite.Unofficial.Json\n",
            "Json.ParseError",
            "(record (field \"line\" s64) (field \"column\" s64) (field \"message\" string))",
            "i64 i64 i32 i32",
            "i32",
        ),
    ];
    for (defs, ty, wit, params, ret) in cases {
        let result = check(
            &(defs.to_owned() + &declaration(&format!("v: {ty}"), ty, "f")),
            &typed_component(wit, params, ret),
        );
        assert!(
            result.diagnostics.is_empty(),
            "{ty}: {:?}",
            result.diagnostics
        );
        assert!(result.program.is_some());
    }
    // 同じ型を兄弟の欄で使う場合は再帰ではない。
    let bytes = wat::parse_str(
        r#"(component
        (core module $m (memory (export "memory") 1) (func (export "f") (param i64 i64) (result i32) unreachable))
        (core instance $i (instantiate $m))
        (type $leaf (record (field "x" s64)))
        (export $l "leaf" (type $leaf))
        (type $root (record (field "a" $l) (field "b" $l)))
        (export $r "root" (type $root))
        (func (export "f") (param "v" $r) (result $r) (canon lift (core func $i "f") (memory (core memory $i "memory")))))"#,
    )
    .unwrap();
    let source = "record Leaf\nx: Integer\nend record\nrecord Root\na: Leaf\nb: Leaf\nend record\n"
        .to_owned()
        + &declaration("v: Root", "Root", "f");
    let result = check(&source, &bytes);
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
}

// spec: 03-10 型の対応
#[test]
fn aggregate_mismatches_report_the_first_reason_in_both_directions() {
    let cases = [
        (
            "record Point\ny: Integer\nbyteStart: Integer\nend record\n",
            "Point",
            "(record (field \"byte-start\" s64) (field \"y\" s64))",
            "i64 i64",
            "i32",
            "field 1 is `byte-start`",
        ),
        (
            "record Point\nx: Integer\nz: Integer\nend record\n",
            "Point",
            "(record (field \"x\" s64) (field \"y\" s64))",
            "i64 i64",
            "i32",
            "field 2 is `y`",
        ),
        (
            "record Point\nx: Integer\nend record\n",
            "Point",
            "(record (field \"x\" s64) (field \"y\" s64))",
            "i64 i64",
            "i32",
            "WIT has 2 fields",
        ),
        (
            "record Point\nx: Float\nend record\n",
            "Point",
            "(record (field \"x\" s64))",
            "i64",
            "i64",
            "type of field `x`",
        ),
        (
            "record Point\nx_y: Integer\nend record\n",
            "Point",
            "(record (field \"x-y\" s64))",
            "i64",
            "i64",
            "`_` is preserved",
        ),
        (
            "record Point\nbyteStart: Integer\nbytestart: Integer\nend record\n",
            "Point",
            "(record (field \"byte-start\" s64) (field \"y\" s64))",
            "i64 i64",
            "i32",
            "in the declaration duplicates",
        ),
        (
            "record Point\naBc: Integer\nx: Integer\nend record\n",
            "Point",
            "(record (field \"a-bc\" s64) (field \"ab-c\" s64))",
            "i64 i64",
            "i32",
            "in WIT duplicates",
        ),
        (
            "data Color\nRed\nend data\n",
            "Color",
            "(enum \"red\" \"blue\")",
            "i32",
            "i32",
            "WIT has 2 cases",
        ),
        (
            "data Color\nBlue\nRed\nend data\n",
            "Color",
            "(enum \"red\" \"blue\")",
            "i32",
            "i32",
            "case 1 is `red`",
        ),
        (
            "data Color\nABc\nOther\nend data\n",
            "Color",
            "(enum \"a-bc\" \"ab-c\")",
            "i32",
            "i32",
            "in WIT duplicates",
        ),
        (
            "data Color\nByteStart\nBytestart\nend data\n",
            "Color",
            "(enum \"byte-start\" \"other\")",
            "i32",
            "i32",
            "in the declaration duplicates",
        ),
        (
            "data Shape\nEmpty\nend data\n",
            "Shape",
            "(variant (case \"circle\" s64) (case \"empty\"))",
            "i32 i64",
            "i32",
            "WIT has 2 cases",
        ),
        (
            "data Shape\nEmpty\nCircle(Integer)\nend data\n",
            "Shape",
            "(variant (case \"circle\" s64) (case \"empty\"))",
            "i32 i64",
            "i32",
            "case 1 is `circle`",
        ),
        (
            "data Shape\nCircle(Float)\nEmpty\nend data\n",
            "Shape",
            "(variant (case \"circle\" s64) (case \"empty\"))",
            "i32 i64",
            "i32",
            "type of case `circle`",
        ),
        (
            "data Shape\nCircle\nEmpty\nend data\n",
            "Shape",
            "(variant (case \"circle\" f64) (case \"empty\"))",
            "i32 f64",
            "i32",
            "presence of a payload",
        ),
        (
            "data Shape\nCircle(Float)\nEmpty\nend data\n",
            "Shape",
            "(variant (case \"circle\") (case \"empty\"))",
            "i32",
            "i32",
            "presence of a payload",
        ),
        (
            "data Shape\nCircle(Float)\nEmpty\nend data\n",
            "Shape",
            "(enum \"circle\" \"empty\")",
            "i32",
            "i32",
            "presence of a payload",
        ),
        (
            "data Shape\nABc\nOther\nend data\n",
            "Shape",
            "(variant (case \"a-bc\") (case \"ab-c\"))",
            "i32",
            "i32",
            "in WIT duplicates",
        ),
        (
            "data Shape\nByteStart\nBytestart\nend data\n",
            "Shape",
            "(variant (case \"byte-start\") (case \"other\"))",
            "i32",
            "i32",
            "in the declaration duplicates",
        ),
    ];
    for (defs, ty, wit, params, ret, reason) in cases {
        let result = check(
            &(defs.to_owned() + &declaration(&format!("v: {ty}"), ty, "f")),
            &typed_component(wit, params, ret),
        );
        assert_eq!(
            codes(&result),
            vec![DiagCode::E1008, DiagCode::E1009],
            "{ty}: {:?}",
            result.diagnostics
        );
        for diagnostic in result.diagnostics {
            assert!(
                diagnostic.notes.iter().any(|note| note.contains(reason)),
                "{reason}: {diagnostic:?}"
            );
            assert!(
                diagnostic
                    .notes
                    .iter()
                    .all(|note| !note.contains("corresponds to"))
            );
        }
    }
}

// 関門: 型の宣言の連なりと共有した型の展開を、コンポーネントを読む前に抑える。
// 構文の入れ子の上限と再帰の検出では、非再帰の深い型と指数的な展開を抑えられない。
// spec: 03-10 型の対応
#[test]
fn declaration_expansion_stops_at_depth_and_node_limits() {
    let chain = |levels: usize, branching: bool| {
        let mut source = "record T0\na: Integer\nend record\n".to_owned();
        for n in 1..levels {
            source += &format!("record T{n}\na: T{}\n", n - 1);
            if branching {
                source += &format!("b: T{}\n", n - 1);
            }
            source += "end record\n";
        }
        source + &declaration(&format!("v: T{}", levels - 1), "Integer", "missing")
    };
    for (levels, branching, expected) in [
        (99, false, DiagCode::E1004), // 葉の Integer を含めて深さ 100。
        (100, false, DiagCode::E1010),
        (15, true, DiagCode::E1004), // 49,151 節点。
        (16, true, DiagCode::E1004), // 98,303 節点。
        (17, true, DiagCode::E1010), // 196,607 節点になる前に止める。
        (41, true, DiagCode::E1010),
    ] {
        let result = check(&chain(levels, branching), b"not a component");
        assert_eq!(
            codes(&result),
            [expected],
            "{levels}/{branching}: {:?}",
            result.diagnostics
        );
        if expected == DiagCode::E1010 {
            assert!(
                result.diagnostics[0]
                    .message
                    .starts_with(&format!("`T{}`", levels - 1))
            );
            assert!(
                result.diagnostics[0]
                    .notes
                    .iter()
                    .any(|note| note.contains("types deeper than 100")),
                "{:?}",
                result.diagnostics
            );
        }
    }
    // 共有する二分木を組み合わせ、根を含めたちょうど 100,000 節点とその一つ上を確かめる。
    let defs = chain(16, true)
        .split("@external")
        .next()
        .unwrap()
        .to_owned();
    let mut root = "record Root\n".to_owned();
    for (field, level) in [15, 9, 5, 4, 2, 1, 0].into_iter().enumerate() {
        root += &format!("a{field}: T{level}\n");
    }
    root += "last: Integer\n";
    for (extra, expected) in [("", DiagCode::E1004), ("extra: Integer\n", DiagCode::E1010)] {
        let source = defs.clone()
            + &root
            + extra
            + "end record\n"
            + &declaration("v: Root", "Integer", "missing");
        let result = check(&source, b"not a component");
        assert_eq!(
            codes(&result),
            [expected],
            "{extra}: {:?}",
            result.diagnostics
        );
        if expected == DiagCode::E1010 {
            assert!(result.diagnostics[0].message.starts_with("`Root`"));
            assert!(
                result.diagnostics[0]
                    .notes
                    .iter()
                    .any(|note| note.contains("types deeper than 100")),
                "{:?}",
                result.diagnostics
            );
        }
    }
    // 一つずつは展開できても、同じ検査で大量の宣言を繰り返して予算を逃れない。
    let mut source = defs;
    for n in 0..12 {
        source += &format!(
            "@external(\"wasm\", \"wasm/x.wasm\", \"missing\")\nfunction f{n}(v: T15) -> Integer\n"
        );
    }
    source += "@external(\"wasm\", \"wasm/x.wasm\", \"missing\")\nfunction scalar(a: Integer, b: Integer) -> Unit\n@external(\"wasm\", \"wasm/x.wasm\", \"missing\")\nfunction empty() -> Unit\n";
    source += "function main() -> Unit\n()\nend function\n";
    let result = check(&source, b"not a component");
    assert_eq!(
        codes(&result)
            .iter()
            .filter(|c| **c == DiagCode::E1004)
            .count(),
        10
    );
    let over: Vec<_> = result
        .diagnostics
        .iter()
        .filter(|d| d.code == Some(DiagCode::E1010))
        .collect();
    assert_eq!(over.len(), 4);
    for (diagnostic, name) in over.iter().skip(1).zip(["f11", "scalar", "empty"]) {
        assert!(diagnostic.message.contains(name));
        assert!(
            !diagnostic.message.contains("`Integer`") && !diagnostic.message.contains("`Unit`")
        );
        let primary = diagnostic.primary.as_ref().unwrap();
        assert_eq!(primary.text, format!("external declaration `{name}`"));
        let span = primary.span;
        let fragment = &source[span.start.0 as usize..span.end.0 as usize];
        assert_eq!(
            fragment,
            if name == "empty" {
                "empty"
            } else if name == "scalar" {
                "Integer"
            } else {
                "T15"
            }
        );
    }
    assert!(
        over.iter()
            .all(|d| d.notes.iter().any(|n| n.contains("1,000,000 per check")))
    );
}

// 関門: 宣言だけで分かる誤りをコンポーネントの読み込みより先に報告する。
// 既存の未対応型の表は型の定義を辿る検査を守らない。
// spec: 03-10 型の対応
#[test]
fn recursive_types_are_rejected_before_reading_components() {
    let cases = [
        (
            "record Nest[T]\nvalue: Nest[List[T]]\nend record\n",
            "Nest[Integer]",
            "recursive types",
        ),
        (
            "data Left[T]\nNext(Right[T])\nend data\nrecord Right[T]\nvalue: Left[List[T]]\nend record\n",
            "Left[Integer]",
            "recursive types",
        ),
        (
            "data Phantom[T]\nEmpty\nend data\nrecord Recursive\nvalue: Phantom[Recursive]\nend record\n",
            "Recursive",
            "recursive types",
        ),
        (
            "data Recursive\nNext(Recursive)\nDone\nend data\n",
            "Recursive",
            "recursive types",
        ),
        (
            "data Recursive\nNext(List[Recursive])\nDone\nend data\n",
            "Recursive",
            "recursive types",
        ),
        (
            "record Recursive\nx: Option[Recursive]\nend record\n",
            "Recursive",
            "recursive types",
        ),
        (
            "data Recursive\nNext(Other)\nend data\nrecord Other\nx: List[Recursive]\nend record\n",
            "Recursive",
            "recursive types",
        ),
    ];
    for (defs, ty, note) in cases {
        let source = defs.to_owned() + &declaration(&format!("v: {ty}"), "Integer", "missing");
        let result = check(&source, b"not a component");
        assert_eq!(
            codes(&result),
            vec![DiagCode::E1010],
            "{ty}: {:?}",
            result.diagnostics
        );
        assert!(
            result.diagnostics[0]
                .message
                .starts_with(&format!("`{ty}`")),
            "{:?}",
            result.diagnostics
        );
        assert!(
            result.diagnostics[0].notes.iter().any(|n| n.contains(note)),
            "{:?}",
            result.diagnostics
        );
    }
    // 入口の型と、依存の循環が閉じる宣言は区別して報告する。
    let source =
        "record Wrapper\nvalue: Loop\nend record\nrecord Loop\nvalue: List[Loop]\nend record\n"
            .to_owned()
            + &declaration("v: Wrapper", "Integer", "missing");
    let result = check(&source, b"not a component");
    assert_eq!(codes(&result), vec![DiagCode::E1010]);
    assert!(result.diagnostics[0].message.starts_with("`Wrapper`"));
    assert!(
        result.diagnostics[0]
            .notes
            .iter()
            .any(|note| note.contains("`Loop`")),
        "{:?}",
        result.diagnostics
    );
}

// 関門: 境界の変換表が依存の走査を検査全体の予算へ含め、欄の情報の不足を拒む。
// パイプラインの正常な型の表だけでは、欄を黙って切り詰める退行は観察できない。
#[test]
fn declaration_plan_checks_dependencies_and_record_fields() {
    use crate::types::{Ty, TyCon};
    let result = check(
        "data Phantom[T]\nEmpty\nend data\nrecord Wrapper\nvalue: Phantom[Integer]\nend record\nfunction main() -> Unit\n()\nend function\n",
        b"",
    );
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    let mut program = result.program.unwrap();
    let (id, def) = program
        .types
        .adts
        .adts
        .iter()
        .find(|(_, def)| def.name == "Wrapper")
        .unwrap();
    let mut def = def.clone();
    let ty = Ty::Con(TyCon::Adt(id), vec![]);
    let mut total = 100;
    assert!(types::plan(&ty, &program.resolved, &program.types.adts, &mut total).is_ok());
    let mut total = 2;
    let budget_note = types::plan(&ty, &program.resolved, &program.types.adts, &mut total)
        .err()
        .and_then(|error| error.note);

    let fields = def.record.as_mut().unwrap();
    let mut extra = fields[0].clone();
    extra.name = "extra".into();
    fields.push(extra);
    program.types.adts.adts.insert(id, def);
    let mut total = 100;
    let missing_fields_rejected =
        types::plan(&ty, &program.resolved, &program.types.adts, &mut total).is_err();
    assert_eq!(
        (budget_note, missing_fields_rejected),
        (Some("budget"), true)
    );
}

// 関門: 具体的な欄の代入と未使用の型引数を、本物のコンポーネントとの照合で守る。
// 従来の拒否の表では、有限の同型の入れ子と再帰の区別や、パラメータの環境を確かめられない。
#[test]
fn generic_concrete_types_match_used_fields() {
    let bytes = wat::parse_str(include_str!(
        "../../testdata/external/wit-generic-values/x.wat"
    ))
    .unwrap();
    for (defs, ty, export, expected) in [
        (
            "record Box[T]\nvalue: T\nend record\n",
            "Box[Integer]",
            "box",
            None,
        ),
        (
            "record Box[T]\nvalue: T\nend record\n",
            "Box[Box[Integer]]",
            "nested",
            None,
        ),
        (
            "record Box[T]\nvalue: T\nend record\nrecord Carrier[T]\nvalue: Box[T]\nend record\n",
            "Carrier[Integer]",
            "nested",
            None,
        ),
        (
            "record Box[A, B]\nvalue: B\nend record\n",
            "Box[Float, Integer]",
            "box",
            None,
        ),
        (
            "record Box[T]\nvalue: T\nend record\n",
            "Box[Float]",
            "box",
            Some(DiagCode::E1008),
        ),
        (
            "data Envelope[T]\nWrapped(T)\nEmpty\nend data\n",
            "Envelope[Integer]",
            "envelope",
            None,
        ),
        (
            "record Wrapped[T]\nvalue: Result[Unit, T]\nend record\n",
            "Wrapped[Integer]",
            "result",
            None,
        ),
        (
            "record Wrapped[T]\nvalue: Result[T, Integer]\nend record\n",
            "Wrapped[Unit]",
            "result",
            None,
        ),
        (
            "record Wrapped[T]\nvalue: Result[T, Unit]\nend record\n",
            "Wrapped[Integer]",
            "result",
            Some(DiagCode::E1008),
        ),
        (
            "data Phantom[T]\nEmpty\nend data\ndata Nest[T]\nNext(Nest[List[T]])\nend data\n",
            "Phantom[Nest[Integer]]",
            "phantom",
            None,
        ),
    ] {
        let ret = match export {
            "box" if ty == "Box[Float, Integer]" => ty,
            "box" => "Box[Integer]",
            "nested" => "Box[Box[Integer]]",
            "envelope" => "Envelope[Integer]",
            _ => "Unit",
        };
        let source = defs.to_owned() + &declaration(&format!("v: {ty}"), ret, export);
        let result = check(&source, &bytes);
        assert_eq!(
            codes(&result),
            expected.into_iter().collect::<Vec<_>>(),
            "{ty}: {:?}",
            result.diagnostics
        );
    }
}

// 関門: resource の探索が予算切れのときに、部分的な探索結果からエフェクトを診断しない。
// 既存の予算の試験には、代入後の深さと State の判定の組み合わせがない。
#[test]
fn generic_state_budget_reports_the_root_type() {
    let bytes = wat::parse_str(include_str!("../../testdata/external/resource/x.wat")).unwrap();
    let cell = "@external(\"wasm\", \"wasm/x.wasm\", \"bnt:test/counter@0.1.0#cell\")\ntype Cell\n";
    let mut defs = format!("{cell}record T0[T]\nvalue: T\nend record\n");
    for n in 1..100 {
        defs += &format!("record T{n}[T]\nvalue: T{}[T]\nend record\n", n - 1);
    }
    for (ty, effects, expected) in [
        ("T98[Cell]", "", DiagCode::E0816),
        ("T99[Cell]", "", DiagCode::E1010),
        ("T99[Cell]", " uses State", DiagCode::E1010),
    ] {
        let source = format!(
            "{defs}@external(\"wasm\", \"wasm/x.wasm\", \"missing\")\nfunction externalFn(v: {ty}) -> Integer{effects}\nfunction main() -> Unit\n()\nend function\n"
        );
        let result = check(&source, &bytes);
        assert_eq!(
            codes(&result),
            [expected],
            "{ty}/{effects}: {:?}",
            result.diagnostics
        );
        if expected == DiagCode::E1010 {
            assert!(
                result.diagnostics[0]
                    .message
                    .starts_with(&format!("`{ty}`"))
            );
            assert!(
                result.diagnostics[0]
                    .notes
                    .iter()
                    .any(|note| note.contains("100,000 expanded nodes per type"))
            );
        }
    }
}

// 関門: 同じ宣言の別の具体化を省略せず、使われる欄に到達した resource だけに State を要求する。
// 既存の直接の resource の試験では、未使用の引数や宣言一回だけの訪問による見落としを検出できない。
#[test]
fn generic_state_follows_instantiated_fields() {
    let bytes = wat::parse_str(include_str!("../../testdata/external/resource/x.wat")).unwrap();
    let cell = "@external(\"wasm\", \"wasm/x.wasm\", \"bnt:test/counter@0.1.0#cell\")\ntype Cell\n";
    for (defs, params, ret, effects, export, expected) in [
        (
            "data Phantom[T]\nEmpty\nend data\n",
            "v: Phantom[Cell]",
            "Integer",
            "",
            "[static]cell.count",
            DiagCode::E1007,
        ),
        (
            "data Phantom[T]\nEmpty\nend data\n",
            "",
            "Phantom[Cell]",
            "",
            "[static]cell.count",
            DiagCode::E1009,
        ),
        (
            "data Phantom[T]\nEmpty\nend data\n",
            "",
            "Phantom[Cell]",
            " uses State",
            "[static]cell.count",
            DiagCode::E0812,
        ),
        (
            "record Box[T]\nvalue: T\nend record\n",
            "v: Box[Cell]",
            "Integer",
            "",
            "[method]cell.get",
            DiagCode::E0816,
        ),
        (
            "data Box[T]\nValue(T)\nend data\n",
            "",
            "Box[Cell]",
            "",
            "[static]cell.count",
            DiagCode::E0816,
        ),
        (
            "record Box[T]\nvalue: T\nend record\n",
            "v: Box[Box[Cell]]",
            "Integer",
            " uses State",
            "[method]cell.get",
            DiagCode::E1008,
        ),
        (
            "record Box[T]\nvalue: T\nend record\n",
            "v: Box[Box[Cell]]",
            "Integer",
            " uses Console.Write",
            "[method]cell.get",
            DiagCode::E0812,
        ),
        (
            "record Box[T]\nvalue: T\nend record\nrecord Both\nplain: Box[Integer]\nresource: Box[Cell]\nend record\n",
            "v: Both",
            "Integer",
            "",
            "[method]cell.get",
            DiagCode::E0816,
        ),
        (
            "record Box[T]\nvalue: T\nend record\nrecord Both\nresource: Box[Cell]\nplain: Box[Integer]\nend record\n",
            "v: Both",
            "Integer",
            "",
            "[method]cell.get",
            DiagCode::E0816,
        ),
    ] {
        let function = format!(
            "@external(\"wasm\", \"wasm/x.wasm\", \"bnt:test/counter@0.1.0#{export}\")\nfunction externalFn({params}) -> {ret}{effects}\n"
        );
        for forward in [false, true] {
            let source = format!(
                "import Benitoite.Unofficial.IO.Console\n{cell}{}{}function main() -> Unit\n()\nend function\n",
                if forward { &function } else { defs },
                if forward { defs } else { &function }
            );
            assert_eq!(
                codes(&check(&source, &bytes)),
                [expected],
                "{params}/{ret}/{effects}/{forward}"
            );
        }
    }
}

#[test]
fn paths_are_exact_and_stay_under_their_root() {
    use crate::modules::{EntrySpec, memfs::MemFs};
    let bytes = wat::parse_str(ADD).unwrap();
    for (path, expected) in [
        ("", DiagCode::E1002),
        ("/wasm/x.wasm", DiagCode::E1002),
        ("wasm\\x.wasm", DiagCode::E1002),
        ("wasm//x.wasm", DiagCode::E1002),
        ("wasm/./x.wasm", DiagCode::E1002),
        ("wasm/../x.wasm", DiagCode::E1002),
        ("wasm/x.wat", DiagCode::E1002),
        ("wasm/.x.wasm", DiagCode::E1002),
        ("wasm/.hidden/x.wasm", DiagCode::E1002),
        ("wasm/X.wasm", DiagCode::E1001),
        ("wasm/missing.wasm", DiagCode::E1001),
        ("wasm/escape.wasm", DiagCode::E1003),
    ] {
        let source = declaration("a: Integer, b: Integer", "Integer", "add")
            .replace("wasm/x.wasm", &path.replace('\\', "\\\\"));
        let mut fs = MemFs::new(&[("main.bnt", &source)]);
        fs.case_insensitive = true;
        fs.add_file("wasm/x.wasm", bytes.clone());
        fs.add_file("/outside/x.wasm", bytes.clone());
        fs.add_link("wasm/escape.wasm", "/outside/x.wasm");
        let result = pipeline::check(
            &EntrySpec {
                path: "/root/main.bnt".into(),
                root: "/root".into(),
                display_name: "main.bnt".into(),
            },
            &fs,
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            codes(&result),
            vec![expected],
            "{path}: {:?}",
            result.diagnostics
        );
        if expected == DiagCode::E1002 {
            let hidden_note = result.diagnostics[0]
                .notes
                .iter()
                .any(|note| note.contains("starts with `.`"));
            assert_eq!(
                hidden_note,
                matches!(path, "wasm/.x.wasm" | "wasm/.hidden/x.wasm"),
                "{path}"
            );
        }
    }
}

// spec: 01-02 外部の関数の宣言
#[test]
fn directories_lost_after_loading_are_component_read_errors() {
    use crate::modules::{DirEntryName, EntrySpec, ModuleFs, memfs::MemFs};
    use std::{
        io,
        path::{Path, PathBuf},
    };
    struct UnavailableFs {
        fs: MemFs,
        unavailable: PathBuf,
        reason: io::ErrorKind,
    }
    impl ModuleFs for UnavailableFs {
        fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
            self.fs.read_file(path)
        }
        fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
            if path == self.unavailable {
                Err(self.reason.into())
            } else {
                self.fs.canonicalize(path)
            }
        }
        fn list_dir(&self, path: &Path) -> io::Result<Vec<DirEntryName>> {
            self.fs.list_dir(path)
        }
    }
    for (dependency, reason, note) in [
        (false, io::ErrorKind::NotFound, "no such file"),
        (true, io::ErrorKind::PermissionDenied, "permission denied"),
    ] {
        let declaration = declaration("a: Integer, b: Integer", "Integer", "add");
        let mut fs = if dependency {
            MemFs::new(&[
                (
                    "main.bnt",
                    "dependency Lib\npath \"deps/lib\"\nend dependency\nimport Lib.Calc\nfunction main() -> Unit\n()\nend function\n",
                ),
                (
                    "deps/lib/package.bnt",
                    "language \"0.0.12\"\npackage Library\nend package\n",
                ),
                ("deps/lib/Calc.bnt", &declaration),
            ])
        } else {
            MemFs::new(&[("main.bnt", &declaration)])
        };
        fs.add_file(
            if dependency {
                "deps/lib/wasm/x.wasm"
            } else {
                "wasm/x.wasm"
            },
            wat::parse_str(ADD).unwrap(),
        );
        let entry = EntrySpec {
            path: "/root/main.bnt".into(),
            root: "/root".into(),
            display_name: "main.bnt".into(),
        };
        let result = pipeline::check(
            &entry,
            &fs,
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
        let mut program = result.program.unwrap();
        let fs = UnavailableFs {
            fs,
            unavailable: if dependency {
                "/root/deps/lib"
            } else {
                "/root"
            }
            .into(),
            reason,
        };
        let diagnostics = check_externals(
            &entry,
            &fs,
            &program.modules,
            &program.asts,
            &result.sources,
            &mut program.resolved,
            &program.types,
        );
        assert_eq!(diagnostics.len(), 1, "{diagnostics:?}");
        assert_eq!(
            diagnostics[0].code,
            Some(DiagCode::E1001),
            "{diagnostics:?}"
        );
        assert_eq!(diagnostics[0].notes, vec![note]);
        let span = diagnostics[0].primary.as_ref().unwrap().span;
        let source = result.sources.get(span.file).unwrap();
        assert_eq!(
            &source.text()[span.start.0 as usize..span.end.0 as usize],
            b"\"wasm/x.wasm\""
        );
    }
}

#[test]
fn one_component_read_serves_multiple_declarations() {
    use crate::modules::{DirEntryName, EntrySpec, ModuleFs, memfs::MemFs};
    use std::{
        io,
        path::{Path, PathBuf},
        sync::atomic::{AtomicUsize, Ordering},
    };
    struct CountingFs {
        fs: MemFs,
        reads: AtomicUsize,
    }
    impl ModuleFs for CountingFs {
        fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
            if path.extension().is_some_and(|ext| ext == "wasm") {
                self.reads.fetch_add(1, Ordering::Relaxed);
            }
            self.fs.read_file(path)
        }
        fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
            self.fs.canonicalize(path)
        }
        fn list_dir(&self, path: &Path) -> io::Result<Vec<DirEntryName>> {
            self.fs.list_dir(path)
        }
    }
    let source = declaration("a: Integer, b: Integer", "Integer", "add")
        + "@external(\"wasm\", \"wasm/alias.wasm\", \"add\")\nfunction second(a: Integer, b: Integer) -> Integer\n";
    let mut fs = MemFs::new(&[("main.bnt", &source)]);
    fs.add_file("wasm/x.wasm", wat::parse_str(ADD).unwrap());
    fs.add_link("wasm/alias.wasm", "x.wasm");
    let fs = CountingFs {
        fs,
        reads: AtomicUsize::new(0),
    };
    let result = pipeline::check(
        &EntrySpec {
            path: "/root/main.bnt".into(),
            root: "/root".into(),
            display_name: "main.bnt".into(),
        },
        &fs,
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    assert_eq!(fs.reads.load(Ordering::Relaxed), 1);
    let program = result.program.unwrap();
    let specs: Vec<_> = program
        .resolved
        .externals
        .iter()
        .map(|(_, decl)| decl.spec.as_ref().unwrap())
        .collect();
    assert!(Arc::ptr_eq(&specs[0].component, &specs[1].component));
    assert_ne!(specs[0], specs[1]);
}

#[test]
fn module_roots_and_package_wasm_boundaries() {
    let bytes = wat::parse_str(ADD).unwrap();
    let options = CheckOptions {
        require_main: true,
        deny_warnings: false,
    };
    let main = "import Lib.Nested\nfunction main() -> Unit\n()\nend function\n";
    let nested = declaration("a: Integer, b: Integer", "Integer", "add")
        .replace("function externalFn", "public function externalFn");
    let result = pipeline::check_files(
        &[
            ("main.bnt", main.as_bytes()),
            (
                "Lib/Nested.bnt",
                nested.replace("wasm/x.wasm", "x.wasm").as_bytes(),
            ),
            ("package.bnt", b"language \"0.0.12\"\n"),
            ("x.wasm", &bytes),
        ],
        options,
    );
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    let spec = result
        .program
        .unwrap()
        .resolved
        .externals
        .iter()
        .next()
        .unwrap()
        .1
        .spec
        .clone()
        .unwrap();
    assert_eq!(spec.function, "Lib.Nested.externalFn");
    for (path, expected) in [
        ("wasm/impl/x.wasm", None),
        ("x.wasm", Some(DiagCode::E1003)),
    ] {
        let main = "dependency Alias\npath \"deps/fuzzy\"\nend dependency\nimport Alias.Distance\nfunction main() -> Unit\n()\nend function\n";
        let config = "language \"0.0.12\"\npackage Fuzzy\nlicense \"MIT\"\nend package\n";
        let module = nested.replace("wasm/x.wasm", path);
        let result = pipeline::check_files(
            &[
                ("main.bnt", main.as_bytes()),
                ("deps/fuzzy/package.bnt", config.as_bytes()),
                ("deps/fuzzy/Distance.bnt", module.as_bytes()),
                ("deps/fuzzy/wasm/impl/x.wasm", &bytes),
                ("deps/fuzzy/x.wasm", &bytes),
            ],
            options,
        );
        assert_eq!(
            codes(&result),
            expected.into_iter().collect::<Vec<_>>(),
            "{path}: {:?}",
            result.diagnostics
        );
        if let Some(program) = result.program {
            let spec = program
                .resolved
                .externals
                .iter()
                .next()
                .unwrap()
                .1
                .spec
                .as_ref()
                .unwrap();
            assert_eq!(spec.component.display, "deps/fuzzy/wasm/impl/x.wasm");
            assert_eq!(spec.function, "Alias.Distance.externalFn");
        }
    }
}

// 関門: 例外・非同期の型・lift/lower の実際の検証拒否を守る。
// 通常のゲストの照合では、依存更新で機能が有効になる退行を捕まえない。
#[test]
fn component_proposals_follow_the_fixed_engine_features() {
    let exception = r#"(component
        (core module $m
            (tag $e (param i64))
            (func (export "f") (result i64)
                (block $caught (result i64)
                    (try_table (catch $e $caught)
                        i64.const 42 throw $e)
                    i64.const 0)))
        (core instance $i (instantiate $m))
        (func (export "f") (result s64) (canon lift (core func $i "f"))))"#;
    let async_lift = r#"(component (core module $m (func (export "f")))
        (core instance $i (instantiate $m))
        (func (export "f") async (canon lift (core func $i "f") async)))"#;
    let async_lower = r#"(component (core module $m (func (export "f")))
        (core instance $i (instantiate $m))
        (func $f async (canon lift (core func $i "f") async))
        (core func (canon lower (func $f) async)))"#;
    for (wat, reason) in [
        (exception, "exceptions proposal not enabled"),
        (async_lift, "component model async feature"),
        (
            r#"(component (type (future u8)))"#,
            "component model async feature",
        ),
        (
            r#"(component (type (stream u8)))"#,
            "component model async feature",
        ),
        (async_lower, "component model async feature"),
    ] {
        let bytes = wat::parse_str(wat).unwrap();
        // 入力自体の不正で通る否定テストを避け、機能を許す検証器では有効と確かめる。
        wasmparser::Validator::new_with_features(wasmparser::WasmFeatures::all())
            .validate_all(&bytes)
            .unwrap();
        let result = check(&declaration("", "Unit", "f"), &bytes);
        assert_eq!(
            codes(&result),
            [DiagCode::E1004],
            "{wat}: {:?}",
            result.diagnostics
        );
        assert!(result.program.is_none());
        assert!(
            result.diagnostics[0]
                .notes
                .iter()
                .any(|note| note.contains(reason)),
            "{wat}: {:?}",
            result.diagnostics
        );
    }
}

#[test]
fn mismatches_include_nested_types_and_omitted_result_sides() {
    for (declared, wit, params, ret, rendered) in [
        ("Integer", "s32", "i32", "i32", "s32"),
        ("Float", "f32", "f32", "f32", "f32"),
        ("Bytes", "(list s8)", "i32 i32", "i32", "list<s8>"),
        (
            "List[Integer]",
            "(list bool)",
            "i32 i32",
            "i32",
            "list<bool>",
        ),
        (
            "Option[Integer]",
            "(option string)",
            "i32 i32 i32",
            "i32",
            "option<string>",
        ),
        (
            "Result[Unit, String]",
            "(result bool (error string))",
            "i32 i32 i32",
            "i32",
            "result<bool, string>",
        ),
        (
            "Pair[Integer, Boolean]",
            "(tuple s64 string)",
            "i64 i32 i32",
            "i32",
            "tuple<s64, string>",
        ),
        (
            "Pair[Integer, Boolean]",
            "(tuple s64)",
            "i64",
            "i64",
            "tuple<s64>",
        ),
        (
            "Integer",
            "(record (field \"value\" s64))",
            "i64",
            "i64",
            "record { value: s64 }",
        ),
    ] {
        let result = check(
            &declaration(&format!("x: {declared}"), declared, "f"),
            &typed_component(wit, params, ret),
        );
        assert_eq!(
            codes(&result),
            vec![DiagCode::E1008, DiagCode::E1009],
            "{declared}: {:?}",
            result.diagnostics
        );
        assert!(
            result.diagnostics[0]
                .notes
                .iter()
                .any(|note| note.contains(rendered))
        );
    }
}

// 関門: 書き出しと borrow の型の同一性を、実際のコンポーネントで確かめる。
// 別のインターフェースの同名の型を誤って受け付ける退行も拒否する。
// spec: 03-10 型の対応
#[test]
fn exported_resource_identity_matches_borrow() {
    use wasmtime::component::{Component, Type, types::ComponentItem};
    let engine = wasmtime::Engine::new(&engine_config()).unwrap();
    let bytes = wat::parse_str(include_str!("../../testdata/external/resource/x.wat")).unwrap();
    let component = Component::from_binary(&engine, &bytes).unwrap();
    let ty = component.component_type();
    let interface = |name| {
        let ComponentItem::ComponentInstance(i) = ty.get_export(&engine, name).unwrap().ty else {
            panic!("interface missing");
        };
        i
    };
    let counter = interface("bnt:test/counter@0.1.0");
    let second = interface("bnt:test/second@0.1.0");
    let ComponentItem::Resource(cell) = counter.get_export(&engine, "cell").unwrap().ty else {
        panic!("resource missing");
    };
    let ComponentItem::Resource(other) = second.get_export(&engine, "cell").unwrap().ty else {
        panic!("resource missing");
    };
    let ComponentItem::ComponentFunc(get) =
        counter.get_export(&engine, "[method]cell.get").unwrap().ty
    else {
        panic!("method missing");
    };
    let Type::Borrow(borrow) = get.params().next().unwrap().1 else {
        panic!("borrow missing");
    };
    assert_eq!(cell, borrow);
    assert_ne!(other, borrow);
}

// 関門: 外部の型の同一性・所有の方向・エフェクトをパイプラインの入口から守る。
// 既存の外部の関数の表は、中身を見せない型と状態の契約を扱わない。
// spec: 03-10 型の対応
// spec: 01-07 外部の関数のエフェクト
#[test]
fn external_types_and_effects_match_component_contracts() {
    let bytes = wat::parse_str(include_str!("../../testdata/external/resource/x.wat")).unwrap();
    let cell = "@external(\"wasm\", \"wasm/x.wasm\", \"bnt:test/counter@0.1.0#cell\")\ntype Cell\n";
    let counter = "bnt:test/counter@0.1.0";
    // 呼び出し側にエフェクトを足す前に、外部の宣言の誤りを報告しなければならない。
    // 既存の表は、宣言を呼ばないため検査の段の順序の退行を捕まえない。
    let source = "import Benitoite.Unofficial.IO.Console\n@external(\"wasm\", \"wasm/x.wasm\", \"add\")\nfunction add(a: Integer, b: Integer) -> Integer uses Console.Write\nfunction main() -> Unit\nbind _ <- add(a: 1, b: 2)\n()\nend function\n";
    assert!(codes(&check(source, &wat::parse_str(ADD).unwrap())).contains(&DiagCode::E0812));
    for (type_decl, params, ret, export, effects, expected, forward) in [
        (
            cell.to_owned(),
            "",
            "Integer",
            "[static]cell.count",
            "",
            None,
            false,
        ),
        (
            cell.to_owned(),
            "start: Integer",
            "Cell",
            "[constructor]cell",
            " uses State",
            None,
            false,
        ),
        (
            cell.to_owned(),
            "start: Integer",
            "Option[Cell]",
            "[static]cell.make",
            " uses State",
            None,
            false,
        ),
        (
            cell.to_owned(),
            "self: Cell, by: Integer",
            "Integer",
            "[method]cell.bump",
            " uses State",
            None,
            false,
        ),
        (
            cell.to_owned(),
            "self: Cell, other: Cell",
            "Integer",
            "[method]cell.pair",
            " uses State",
            None,
            false,
        ),
        (
            cell.to_owned(),
            "self: Cell, other: Cell",
            "Integer",
            "[method]cell.take",
            " uses State",
            Some(DiagCode::E1008),
            false,
        ),
        (
            cell.replace("counter@", "second@"),
            "self: Cell",
            "Integer",
            "[method]cell.get",
            " uses State",
            Some(DiagCode::E1008),
            false,
        ),
        (
            cell.replace("#cell", "#other"),
            "self: Cell",
            "Integer",
            "[method]cell.get",
            " uses State",
            Some(DiagCode::E1012),
            false,
        ),
        (
            cell.replace("#cell", "#missing"),
            "self: Cell",
            "Integer",
            "[method]cell.get",
            " uses State",
            Some(DiagCode::E1012),
            false,
        ),
        (
            cell.to_owned(),
            "self: Cell",
            "Integer",
            "[method]cell.get",
            "",
            Some(DiagCode::E0816),
            false,
        ),
        (
            cell.to_owned(),
            "self: Cell",
            "Integer",
            "[method]cell.get",
            " uses State, Console.Write",
            Some(DiagCode::E0812),
            false,
        ),
        (
            cell.to_owned(),
            "x: Integer",
            "Integer",
            "other",
            " uses State",
            Some(DiagCode::E0812),
            false,
        ),
        (
            format!("{cell}type Alias = Cell\n"),
            "self: Alias",
            "Integer",
            "[method]cell.get",
            " uses State",
            None,
            false,
        ),
        // 関門: レコードの欄を辿る State の検査を、前方・後方の宣言で守る。
        // 直接の Cell と別名だけでは、欄を辿らない退行を検出できない。
        // State が正しい行は照合の E1008 まで進み、型検査の診断がないことを確かめる。
        (
            format!("{cell}record Holder\ncell: Cell\nend record\n"),
            "h: Holder",
            "Integer",
            "[method]cell.get",
            "",
            Some(DiagCode::E0816),
            true,
        ),
        (
            format!("{cell}record Holder\ncell: Cell\nend record\n"),
            "h: Holder",
            "Integer",
            "[method]cell.get",
            " uses State",
            Some(DiagCode::E1008),
            true,
        ),
        (
            format!("{cell}record Holder\ncell: Cell\nend record\n"),
            "h: Holder",
            "Integer",
            "[method]cell.get",
            " uses Console.Write",
            Some(DiagCode::E0812),
            true,
        ),
        (
            format!("{cell}record Holder\ncell: Cell\nend record\n"),
            "h: Holder",
            "Integer",
            "[method]cell.get",
            "",
            Some(DiagCode::E0816),
            false,
        ),
        (
            format!("{cell}record Holder\ncell: Cell\nend record\n"),
            "h: Holder",
            "Integer",
            "[method]cell.get",
            " uses State",
            Some(DiagCode::E1008),
            false,
        ),
        (
            format!("{cell}record Holder\ncell: Cell\nend record\n"),
            "h: Holder",
            "Integer",
            "[method]cell.get",
            " uses Console.Write",
            Some(DiagCode::E0812),
            false,
        ),
    ] {
        // 関数と型の宣言順を変え、束縛の番号の順に依存した検査を検出する。
        let function = format!(
            "@external(\"wasm\", \"wasm/x.wasm\", \"{counter}#{export}\")\nfunction externalFn({params}) -> {ret}{effects}\n"
        );
        let declarations = if forward {
            type_decl + &function
        } else {
            function + &type_decl
        };
        let source = format!(
            "import Benitoite.Unofficial.IO.Console\n{declarations}function main() -> Unit\n()\nend function\n"
        );
        let result = check(&source, &bytes);
        assert_eq!(
            codes(&result),
            expected.into_iter().collect::<Vec<_>>(),
            "{source}: {:?}",
            result.diagnostics
        );
        if expected == Some(DiagCode::E0812) {
            let edits = &result.diagnostics[0].helps[0].edits;
            assert_eq!(edits.len(), 1);
            assert_eq!(
                edits[0].replacement,
                if params.contains("Cell") || params.contains("Holder") {
                    "uses State"
                } else {
                    ""
                }
            );
            let mut fixed = source.clone();
            fixed.replace_range(
                edits[0].span.start.0 as usize..edits[0].span.end.0 as usize,
                &edits[0].replacement,
            );
            assert_eq!(
                codes(&check(&fixed, &bytes)),
                if params.contains("Holder") {
                    vec![DiagCode::E1008]
                } else {
                    Vec::new()
                }
            );
        }
        if let Some(program) = result.program {
            assert!(
                program
                    .resolved
                    .externals
                    .iter()
                    .filter_map(|(_, d)| d.spec.as_ref())
                    .all(|s| if export == "[static]cell.count" {
                        matches!(s.route, ExternalRoute::Typed(_))
                    } else {
                        s.route == ExternalRoute::Stateful
                    })
            );
        }
    }
    for (expression, expected) in [
        ("a = a", DiagCode::E0406),
        ("a <> a", DiagCode::E0406),
        ("Map.fromList([Pair(a, 1)])", DiagCode::E0423),
        ("Set.fromList([a])", DiagCode::E0423),
        ("Assert.equal(actual: a, expected: a)", DiagCode::E0406),
        ("\"${a}\"", DiagCode::E0422),
        ("a < a", DiagCode::E0405),
        ("with x = a do () end with", DiagCode::E0443),
    ] {
        let source = format!(
            "{cell}function reject(a: Cell) -> Unit uses State, Assert.Check\nbind _ <- {expression}\n()\nend function\nfunction main() -> Unit\n()\nend function\n"
        );
        let result = check(&source, &bytes);
        assert!(result.program.is_none(), "{expression}");
        assert!(
            codes(&result).contains(&expected),
            "{expression}: {:?}",
            result.diagnostics
        );
        assert!(
            codes(&result).iter().all(|code| matches!(
                code,
                DiagCode::E0406
                    | DiagCode::E0423
                    | DiagCode::E0422
                    | DiagCode::E0405
                    | DiagCode::E0443
            )),
            "{expression}: {:?}",
            result.diagnostics
        );
    }
    let source = format!(
        "import Benitoite.Trait\n{cell}implement Trait.Show[Cell]\nfunction show(x: Cell) -> String\nreturn \"cell\"\nend function\nend implement\nfunction stringify(a: Cell) -> String\nreturn Trait.Show.show(a)\nend function\nfunction main() -> Unit\n()\nend function\n"
    );
    let result = check(&source, &bytes);
    assert!(codes(&result).is_empty(), "{:?}", result.diagnostics);
    let source = format!(
        "{cell}public function expose(a: Cell) -> Unit\n()\nend function\nfunction main() -> Unit\n()\nend function\n"
    );
    assert_eq!(codes(&check(&source, &bytes)), vec![DiagCode::E0329]);
}

// 関門: WIT と共通の鍵だけを照合し、鍵と値の不一致の位置を診断する。
// 既存の未対応型の表には、対応する Map と鍵だけが未対応の Map の区別がない。
#[test]
fn map_keys_and_member_mismatches() {
    let bytes = typed_component(
        "(record (field \"entries\" (map string s64)))",
        "i32 i32",
        "i32",
    );
    let source = "record Bag[K, V]\nentries: Map[K, V]\nend record\n".to_owned()
        + &declaration("v: Bag[String, Integer]", "Bag[String, Integer]", "f");
    let result = check(&source, &bytes);
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    for (key, wit) in [
        ("Boolean", "bool"),
        ("Integer8", "s8"),
        ("Integer16", "s16"),
        ("Integer32", "s32"),
        ("Integer", "s64"),
        ("Byte", "u8"),
        ("UnsignedInteger16", "u16"),
        ("UnsignedInteger32", "u32"),
        ("UnsignedInteger64", "u64"),
        ("Character", "char"),
        ("String", "string"),
    ] {
        let ty = format!("Map[{key}, Option[Integer]]");
        let bytes = typed_component(&format!("(map {wit} (option s64))"), "i32 i32", "i32");
        let result = check(&declaration(&format!("v: {ty}"), &ty, "f"), &bytes);
        assert!(
            result.diagnostics.is_empty(),
            "{key}: {:?}",
            result.diagnostics
        );
    }
    let bytes = typed_component("(map string s64)", "i32 i32", "i32");
    for key in ["Decimal", "Bytes", "Unit", "Pair[Integer, Integer]"] {
        let result = check(
            &declaration(&format!("v: Map[{key}, Integer]"), "Unit", "f"),
            &bytes,
        );
        assert_eq!(
            codes(&result),
            [DiagCode::E1010],
            "{key}: {:?}",
            result.diagnostics
        );
        assert!(
            result.diagnostics[0]
                .notes
                .iter()
                .any(|note| note.contains("map keys must be"))
        );
    }
    for (ty, member) in [
        ("Map[Integer, Integer]", "key"),
        ("Map[String, String]", "value"),
    ] {
        let result = check(
            &declaration(&format!("v: {ty}"), "Map[String, Integer]", "f"),
            &bytes,
        );
        assert_eq!(codes(&result), [DiagCode::E1008]);
        assert!(
            result.diagnostics[0]
                .notes
                .iter()
                .any(|note| note.contains(&format!("map {member} requires"))),
            "{:?}",
            result.diagnostics
        );
    }
    let result = check(
        &declaration("a: Map[String, Integer], b: Integer", "Integer", "add"),
        &wat::parse_str(ADD).unwrap(),
    );
    assert_eq!(codes(&result), [DiagCode::E1008]);
}

fn map_program(source: &str, wat: &str) -> crate::bytecode::program::CompiledProgram {
    let result = check(source, &wat::parse_str(wat).unwrap());
    assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
    let core = pipeline::desugar_checked(&result.program.unwrap()).unwrap();
    pipeline::compile(&core, Arc::clone(&result.sources)).unwrap()
}

// 関門: Benitoite の名前から宣言位置へ写し、異なる WIT 名には位置で渡す。
// 宣言だけの照合や ABI の単体検査では、CallPlan・コード生成を通る並べ替えを捕まえない。
#[test]
fn named_external_calls_keep_positions_independent_of_wit_names() {
    use crate::runtime::heap::HeapConfig;
    use crate::runtime::io::services::RunInput;
    use crate::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
    use crate::vm::{ExecMode, VmConfig};
    use std::sync::Mutex;

    let component = ADD.replace("i64.add", "i64.sub");
    let declaration = "@external(\"wasm\", \"wasm/x.wasm\", \"add\")\nfunction externalFn(left: Integer, right: Integer) -> Integer\n";
    let source = format!(
        r#"
import Benitoite.Unofficial.IO.Console
{declaration}
function main() -> Unit uses Console.Write
 bind direct <- externalFn(right: 2, left: 17)
 bind action: function(left: Integer, right: Integer) -> Integer <- externalFn
 bind viaValue <- action(right: 2, left: 17)
 bind partial <- externalFn(right: _, left: 17)
 bind viaPartial <- partial(right: 2)
 bind piped <- 17 |> externalFn(right: 2)
 Console.writeLine(text: Integer.toString(n: direct + viaValue + viaPartial + piped))
end function
"#
    );
    let program = map_program(&source, &component);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let stdout = Arc::new(Mutex::new(Vec::new()));
        let stderr = Arc::new(Mutex::new(Vec::new()));
        let result = run::run_program(
            &program,
            RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: "/".into(),
                    script_directory: "/".into(),
                },
                stdin: StdinSource::Bytes(vec![]),
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                interrupt: Box::new(NoInterrupt),
                parts: None,
                mode,
                vm: VmConfig::default(),
                heap: HeapConfig::default(),
                dev_panic_after_first_write: false,
            },
        );
        assert_eq!(result.end, EndKind::Returned, "{result:?}");
        assert_eq!(result.exit_code, 0, "{result:?}");
        assert!(result.main_error.is_none(), "{result:?}");
        assert!(result.reports.is_empty(), "{result:?}");
        assert_eq!(*stdout.lock().unwrap(), b"60\n");
        assert!(stderr.lock().unwrap().is_empty());
    }
    let bad = format!(
        "{declaration}\nfunction main() -> Unit\n bind value <- externalFn(a: 17, right: 2)\n ()\nend function"
    );
    let result = check(&bad, &wat::parse_str(&component).unwrap());
    assert_eq!(codes(&result), [DiagCode::E0451]);
}

// 関門: 消える組も Wasmtime の予算と ABI の検査に含める。
// 変換の往復だけではゲストの不正値や hostcall fuel の不足を検出できない。
#[test]
fn dynamic_map_transfer_limits_include_disappearing_entries_and_strings() {
    use super::stats::{Collector, ExecutionOptions};
    use crate::runtime::heap::{Heap, HeapConfig, Value};
    use crate::runtime::{ResourceError, RuntimeError, Stop, map};
    let wat = include_str!("../../testdata/external/wit-map-values/x.wat");
    let mut program = map_program(
        &declaration("v: Map[String, Integer]", "Map[String, Integer]", "result"),
        wat,
    );
    let mut echo = map_program(
        &declaration("v: Map[String, Integer]", "Map[String, Integer]", "echo"),
        wat,
    );
    // 動的への事前の振り分けでも、Val の大きさと消える組を数える契約を保つ。
    for program in [&mut program, &mut echo] {
        Arc::make_mut(&mut program.externals.functions[0].spec).adapter = None;
    }
    let pair = u64::try_from(std::mem::size_of::<(
        wasmtime::component::Val,
        wasmtime::component::Val,
    )>())
    .unwrap();
    let result_cost = 3 * pair + 3;
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let z = ctx.alloc_str("z", "test").unwrap();
        let a = ctx.alloc_str("a", "test").unwrap();
        let input = map::map_insert(ctx, Value::EmptyMap, z, Value::Int(9), "test").unwrap();
        let input = map::map_insert(ctx, input, a, Value::Int(8), "test").unwrap();
        let arg_cost = 2 * pair + 2;
        for (program, arg, cost, returned, last, limit, succeeds) in [
            (
                &program,
                Value::EmptyMap,
                0,
                result_cost,
                3,
                result_cost - 1,
                false,
            ),
            (
                &program,
                Value::EmptyMap,
                0,
                result_cost,
                3,
                result_cost,
                true,
            ),
            (&program, input, arg_cost, result_cost, 3, result_cost, true),
            (&echo, input, arg_cost, arg_cost, 9, arg_cost - 1, false),
            (&echo, input, arg_cost, arg_cost, 9, arg_cost, true),
        ] {
            let stats = Collector::new();
            let mut runtime = ExternalRuntime::configured(
                None,
                ExecutionOptions {
                    session: None,
                    limits: Limits {
                        transfer: limit,
                        ..Limits::default()
                    },
                    stats: Some(stats.clone()),
                },
            )
            .unwrap();
            let result = call(&mut runtime, &program.externals, 0, ctx, &[arg]);
            if succeeds {
                let result = result.unwrap();
                assert_eq!(map::map_len(ctx, result).unwrap(), 2);
                assert_eq!(
                    map::map_get(ctx, result, z).unwrap().unwrap().as_int(),
                    Some(last)
                );
                let stats = stats.json().unwrap();
                assert_eq!(stats["routes"]["dynamic"], 1);
                assert_eq!(stats["arguments_transfer"]["total"], cost);
                assert_eq!(stats["results_transfer"]["total"], returned);
            } else {
                assert!(
                    matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalTransfer { .. }
                        )))
                    ),
                    "{result:?}"
                );
            }
        }
        let bad = map_program(&declaration("", "Map[Integer, Character]", "bad"), wat);
        let mut runtime = ExternalRuntime::new(None).unwrap();
        assert!(matches!(
            call(&mut runtime, &bad.externals, 0, ctx, &[]),
            Err(ExternalFailure::Stop(Stop::Runtime(
                RuntimeError::ExternalTrap { .. }
            )))
        ));
    });
}

// 関門: 重複で消えた resource は回収で解放され、残った対象は Map の借用で使える。
// 通常の resource の回収試験には、変換中の挿入で失われる対象がない。
#[test]
fn map_resources_require_state_and_release_disappearing_values() {
    use crate::runtime::heap::{Heap, HeapConfig, RootStack};
    use crate::runtime::map;
    let wat = include_str!("../../testdata/external/wit-map-resource/x.wat");
    let source = "@external(\"wasm\", \"wasm/x.wasm\", \"cell\")\ntype Cell\n@external(\"wasm\", \"wasm/x.wasm\", \"make\")\nfunction make() -> Map[Integer, Cell] uses State\n@external(\"wasm\", \"wasm/x.wasm\", \"read\")\nfunction read(v: Map[Integer, Cell]) -> Integer uses State\nfunction main() -> Unit\n()\nend function\n";
    let without = check(
        &source.replace(" uses State", ""),
        &wat::parse_str(wat).unwrap(),
    );
    assert_eq!(
        codes(&without),
        [DiagCode::E0816, DiagCode::E0816],
        "{:?}",
        without.diagnostics
    );
    let program = map_program(source, wat);
    assert!(
        program
            .externals
            .functions
            .iter()
            .all(|reference| reference.spec.route == ExternalRoute::Stateful)
    );
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    let mut roots = RootStack::new();
    let root = heap.epoch(|ctx| {
        let value = call(&mut runtime, &program.externals, 0, ctx, &[]).unwrap();
        assert_eq!(map::map_len(ctx, value).unwrap(), 2);
        assert_eq!(
            call(&mut runtime, &program.externals, 1, ctx, &[value])
                .unwrap()
                .as_int(),
            Some(0)
        );
        roots.push(ctx, value)
    });
    heap.collect(&roots);
    heap.epoch(|ctx| {
        let value = roots.get(ctx, root).unwrap();
        assert_eq!(
            call(&mut runtime, &program.externals, 1, ctx, &[value])
                .unwrap()
                .as_int(),
            Some(1)
        );
        roots.truncate(ctx, 0);
    });
    heap.collect(&roots);
    heap.epoch(|ctx| {
        assert_eq!(
            call(
                &mut runtime,
                &program.externals,
                1,
                ctx,
                &[crate::runtime::heap::Value::EmptyMap]
            )
            .unwrap()
            .as_int(),
            Some(3)
        );
    });
}

// 関門: 一構成子の data の対応は WIT の種類で決め、欄数と型の不一致を照合で拒む。
// 実行のゴールデンでは、拒否する宣言と Unit の省略禁止は確かめられない。
#[test]
fn tuple_and_multi_argument_variant_contracts() {
    let defs = "data Many\nItem(Integer, Integer)\nend data\n";
    for wit in [
        "(tuple s64 s64)",
        "(variant (case \"item\" (tuple s64 s64)))",
    ] {
        let params = if wit.starts_with("(tuple") {
            "i64 i64"
        } else {
            "i32 i64 i64"
        };
        let result = check(
            &(defs.to_owned() + &declaration("v: Many", "Many", "f")),
            &typed_component(wit, params, "i32"),
        );
        assert!(result.program.is_some(), "{:?}", result.diagnostics);
        assert!(result.diagnostics.is_empty());
    }
    let one = "data One\nItem(Integer)\nend data\n";
    let result = check(
        &(one.to_owned() + &declaration("v: One", "One", "f")),
        &typed_component("(variant (case \"item\" s64))", "i32 i64", "i32"),
    );
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
    assert!(result.diagnostics.is_empty());
    for (defs, ty, wit, params, ret) in [
        (defs, "Many", "(tuple s64)", "i64", "i64"),
        (defs, "Many", "(tuple s64 f64)", "i64 f64", "i32"),
        (
            defs,
            "Many",
            "(variant (case \"item\" s64))",
            "i32 i64",
            "i32",
        ),
        (
            defs,
            "Many",
            "(variant (case \"item\" (tuple s64)))",
            "i32 i64",
            "i32",
        ),
        (
            defs,
            "Many",
            "(variant (case \"item\" (tuple s64 f64)))",
            "i32 i64 f64",
            "i32",
        ),
        (
            "data Empty\nItem\nend data\n",
            "Empty",
            "(tuple s64)",
            "i64",
            "i64",
        ),
        (
            "data Two\nItem(Integer)\nOther\nend data\n",
            "Two",
            "(tuple s64)",
            "i64",
            "i64",
        ),
        (
            "record Rec\nx: Integer\nend record\n",
            "Rec",
            "(tuple s64)",
            "i64",
            "i64",
        ),
        (
            "data WithUnit\nItem(Integer, Unit)\nend data\n",
            "WithUnit",
            "(tuple s64)",
            "i64",
            "i64",
        ),
        ("", "Unit", "(tuple s64)", "i64", "i64"),
    ] {
        let result = check(
            &(defs.to_owned() + &declaration(&format!("v: {ty}"), ty, "f")),
            &typed_component(wit, params, ret),
        );
        assert_eq!(
            codes(&result),
            if ty == "WithUnit" {
                vec![DiagCode::E1010, DiagCode::E1010]
            } else if ty == "Unit" {
                vec![DiagCode::E1010]
            } else {
                vec![DiagCode::E1008, DiagCode::E1009]
            },
            "{ty}, {wit}: {:?}",
            result.diagnostics
        );
    }
}
