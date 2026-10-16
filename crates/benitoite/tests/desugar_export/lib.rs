//! 本番の構文受理前に、実際の交換器を独立した corpus 10 と照合する
//! （設計書 07-04「01-12 との対応」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
#[path = "exchange.rs"]
mod exchange;

use crate::pipeline::CheckedProgram;
use serde_json::{Value, json};
use std::collections::BTreeMap;

fn rename(value: &mut Value, names: &BTreeMap<String, String>) {
    match value {
        Value::String(s) => {
            if let Some(name) = names.get(s) {
                *s = name.clone();
            }
        }
        Value::Array(xs) => xs.iter_mut().for_each(|v| rename(v, names)),
        Value::Object(xs) => xs.values_mut().for_each(|v| rename(v, names)),
        Value::Null | Value::Bool(_) | Value::Number(_) => {}
    }
}

// 関門: Die の辞書・標準参照・説明と独立した期待コアへの投影を守る。
// 本番 parser は拒否を保つため、統合入力にはこの分岐へ達する入力がない。
// 既存の cfg(test) の解析入口を使い、本番の API やフラグは加えない。
#[test]
fn typed_try_exchange_matches_independent_corpus_ten() {
    let fixture: Value = serde_json::from_str(include_str!(
        "../../../../formal/tests/try-exchange/corpus.json"
    ))
    .unwrap();
    let stdlib = exchange::complete_stdlib();
    for (index, params, input, suffix, result) in [
        (
            0,
            "[E: Trait.Show]",
            "Result[Integer, E]",
            " or die",
            "Integer",
        ),
        (
            1,
            "[E: Trait.Show]",
            "Result[Integer, E]",
            " or die(exit)",
            "Integer",
        ),
        (2, "", "Option[Integer]", " or die", "Integer"),
        (3, "", "Option[Integer]", " or die(exit)", "Integer"),
        (4, "[E]", "Result[Integer, E]", "", "Result[Integer, E]"),
        (
            5,
            "[E]",
            "Result[Integer, E]",
            " or return",
            "Result[Integer, E]",
        ),
        (6, "", "Option[Integer]", "", "Option[Integer]"),
        (7, "", "Option[Integer]", " or return", "Option[Integer]"),
        (9, "", "Result[Integer, String]", " or die", "Integer"),
    ] {
        let (arguments, effects, body) = if (4..=7).contains(&index) {
            let ctor = if index < 6 {
                "Result.Ok"
            } else {
                "Option.Some"
            };
            (
                format!("input: {input}"),
                "",
                format!("{ctor}(try input{suffix})"),
            )
        } else {
            (
                format!("show: {input}, exit: String"),
                " uses Process.Exit",
                format!("try show{suffix}"),
            )
        };
        let source = format!(
            "import Benitoite.Trait\nimport Benitoite.Unofficial.IO.Process\nfunction f{params}({arguments}) -> {result}{effects}\n return {body}\nend function\n"
        );
        let (load, resolved, types, core) =
            crate::ir::desugar::test_support::desugar_die_source(&source);
        let p = CheckedProgram {
            modules: load.modules,
            asts: load.asts,
            comments: load.comments,
            resolved,
            types,
        };
        let definitions = exchange::named_definitions(&p, &core);
        assert_eq!(definitions.len(), 1);
        let mut input = json!({"group":"golden","name":"typed-die","excluded":[],
            "definitions":definitions,"constants":[],"dataTypes":[]});
        let operations = exchange::named_operation_tables(&p, &core);
        let classes = exchange::named_class_tables(&p, &core);
        for part in [operations, classes] {
            for (key, value) in part.as_object().unwrap() {
                input[key] = value.clone();
            }
        }
        let table = exchange::named_builtin_tables(&p, &input, &stdlib);
        let declarations: Value = serde_json::from_slice(
            &exchange::to_vec(&exchange::named_stdlib_declarations(&p, &core, &input)).unwrap(),
        )
        .unwrap();
        let mut coverage = Value::Null;
        exchange::attach_metadata(&mut input, &table, &mut coverage);
        let nonce = getrandom::u64().unwrap();
        let directory = std::env::temp_dir().join(format!(
            "benitoite-die-exchange-{}-{index}-{nonce:016x}",
            std::process::id()
        ));
        std::fs::create_dir(&directory).unwrap();
        let mut stream = exchange::InputStream::new(&directory, "die");
        stream.push(&input);
        assert_eq!(stream.count, 1);
        let path = directory.join("corpus.json");
        stream.finish(
            &path,
            json!({"version":10,"operators":exchange::operators()}),
        );
        let written: Value = serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
        std::fs::remove_file(path).unwrap();
        std::fs::remove_dir(&directory).unwrap();
        let actual = &written["inputs"][0]["definitions"][0]["scope"]["inScope"];
        let class = p.resolved.stdlib("Benitoite.Trait.Show").unwrap();
        let method = p.resolved.stdlib("Benitoite.Trait.Show.show").unwrap();
        let show_class = input["classes"]
            .as_array()
            .unwrap()
            .iter()
            .find(|c| c["name"] == format!("class:{}", class.0))
            .unwrap();
        assert_eq!(
            show_class["methods"][0]["name"],
            format!("meth:{}", method.0)
        );
        let exit = crate::builtins::lookup_builtin("Benitoite.IO.Process.exit").unwrap();
        let mut names = BTreeMap::from([
            (format!("class:{}", class.0), "class:7".into()),
            (format!("meth:{}", method.0), "meth:9".into()),
            (
                crate::builtins::builtin_decl(exit).unwrap().name.into(),
                "prim:8".into(),
            ),
        ]);
        for (path, target) in [
            ("Benitoite.Result.Result", "Result"),
            ("Benitoite.Option.Option", "Option"),
        ] {
            let id = p.resolved.stdlib(path).unwrap();
            names.insert(format!("data:{}", id.0), target.into());
            let tags = if target == "Result" {
                ["con:ok", "con:error"]
            } else {
                ["con:some", "con:none"]
            };
            for (tag, name) in tags.iter().enumerate() {
                names.insert(format!("con:{}:{tag}", id.0), (*name).into());
            }
        }
        if index == 9 {
            let implementation = core
                .impls
                .iter()
                .find(|i| {
                    i.class == class
                        && i.target
                            == crate::types::TypeArg::Ty(crate::types::Ty::Con(
                                crate::types::TyCon::Builtin(
                                    crate::types::builtin::BuiltinTypeId::STRING,
                                ),
                                vec![],
                            ))
                })
                .unwrap();
            let name = format!("impl:{}", implementation.impl_decl.0);
            assert!(
                declarations["impls"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .any(|i| i["signature"]["name"] == name)
            );
            names.insert(name, "Show".into());
        }
        let mut actual = actual.clone();
        rename(&mut actual, &names);
        let expected = &fixture["inputs"][0]["definitions"][index]["scope"]["inScope"];
        // 所属と view は実ソースの読み込み結果。独立入力の架空の所属とは比較しない。
        for key in ["header", "dictParams"] {
            assert_eq!(
                actual["surface"][key], expected["surface"][key],
                "{index}: surface {key}"
            );
        }
        // 末尾 return の注釈は従来どおり Unit。処置自体と期待コアを比較する。
        assert_eq!(
            actual["surface"]["body"]["last"]["expr"]["returnE"]["inner"],
            expected["surface"]["body"]["last"]["expr"]["returnE"]["inner"],
            "{index}: try"
        );
        assert_eq!(actual["core"], expected["core"], "{index}: core");
        assert_eq!(
            actual["surface"]["body"]["last"]["expr"]["returnE"]["inner"]
                .as_object()
                .unwrap()
                .len(),
            1
        );
        assert_eq!(
            exchange::named_type(
                &p,
                &crate::types::Ty::Con(
                    crate::types::TyCon::Builtin(crate::types::builtin::BuiltinTypeId::INTEGER),
                    vec![]
                )
            ),
            json!({"base":{"name":"Integer"}})
        );
    }
}

// 関門: 入力の後に説明を走査し、両者の lambda の効果を交換に残す。
// 辞書・局所参照だけの表では、説明の走査を省く退行を検出できない。
#[test]
fn die_exchange_keeps_operand_then_message_lambda_effects() {
    let source = r#"
import Benitoite.Unofficial.IO.Process
function f(input: Option[Integer], message: String) -> Integer uses Process.Exit
 return try (if true then
  bind _ <- lambda(text: String) -> String uses State
   return text
  end lambda
  input
 else
  input
 end if) or die(if true then
  bind _ <- lambda(text: String) -> String uses Process.Exit
   return text
  end lambda
  message
 else
  message
 end if)
end function
"#;
    let (load, resolved, types, core) =
        crate::ir::desugar::test_support::desugar_die_source(source);
    let p = CheckedProgram {
        modules: load.modules,
        asts: load.asts,
        comments: load.comments,
        resolved,
        types,
    };
    let definitions = exchange::named_definitions(&p, &core);
    assert_eq!(definitions.len(), 1);
    let scope = &definitions[0]["scope"]["inScope"];
    let expected = json!([[{"name":{"value":"State"}}], [{"name":{"value":"Process.Exit"}}]]);
    assert_eq!(scope["core"]["lambdaEffects"], expected);
    let expression = &scope["surface"]["body"]["last"]["expr"]["returnE"]["inner"]["tryOptionDie"];
    for (part, effect) in [("inner", &expected[0]), ("message", &expected[1])] {
        let branch = if part == "inner" {
            &expression[part]["paren"]["inner"]
        } else {
            &expression[part]
        };
        assert_eq!(
            branch["ite"]["yes"]["discard"]["expr"]["lam"]["eff"], *effect,
            "{part}"
        );
    }
}
