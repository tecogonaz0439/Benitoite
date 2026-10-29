//! File の実際の単一対象の署名から、入力・潜在効果・節へ渡す範囲を確かめる。
//! 関門: 仮の宣言表の単体検査では、本番の登録漏れと通常 IR の再検査に届かない。
//! 本番の差し込み口を増やさず、六操作を表にして同じ公開入口を通す。

use super::{check, pipeline};
use benitoite::types::builtin::{BuiltinEffectId, BuiltinTypeId, RangeIndex};
use benitoite::types::scope::{Kind, PathPattern, Range};
use benitoite::types::signature::IoShape;
use benitoite::types::{EffectName, Ty, TyCon};

const IMPORTS: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Scope\n";

fn accepted(source: &str) -> pipeline::CheckedProgram {
    let result = check(source);
    assert!(
        !result.diagnostics.iter().any(|d| d.is_error()),
        "{source}\n{:?}",
        result.diagnostics
    );
    let program = result.program.unwrap();
    let core = pipeline::desugar_checked(&program).unwrap();
    assert!(
        benitoite::ir::check::check_program(&core).is_empty(),
        "{source}"
    );
    program
}

fn errors(source: &str, expected: &[&str]) {
    let result = check(source);
    let actual: Vec<_> = result
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .map(|d| d.code.unwrap().info().id)
        .collect();
    assert_eq!(actual, expected, "{source}\n{:?}", result.diagnostics);
}

#[test]
fn file_single_target_signatures_follow_inputs_and_expected_function_inputs() {
    let narrow = Range::Path(PathPattern::parse("/data/**").unwrap());
    for (name, extra, result_type, effect) in [
        ("readTextIn", "", "String", BuiltinEffectId::FILE_READ),
        ("readBytesIn", "", "Bytes", BuiltinEffectId::FILE_READ),
        (
            "writeTextIn",
            ", text: String",
            "Unit",
            BuiltinEffectId::FILE_WRITE,
        ),
        (
            "appendTextIn",
            ", text: String",
            "Unit",
            BuiltinEffectId::FILE_WRITE,
        ),
        (
            "writeBytesIn",
            ", content: Bytes",
            "Unit",
            BuiltinEffectId::FILE_WRITE,
        ),
        (
            "appendBytesIn",
            ", content: Bytes",
            "Unit",
            BuiltinEffectId::FILE_WRITE,
        ),
    ] {
        let effect_name = if effect == BuiltinEffectId::FILE_READ {
            "Read"
        } else {
            "Write"
        };
        let args = match extra {
            ", text: String" => ", text: text",
            ", content: Bytes" => ", content: content",
            _ => "",
        };
        let direct = format!(
            "function sample(path: Scope.PathIn[\"/data/**\"]{extra}) -> Result[{result_type}, IOError] uses File.{effect_name}[\"/data/**\"]\n return File.{name}(path: path{args})\nend function"
        );
        let expected_function = format!(
            "function sample() -> function(path: Scope.PathIn[\"/data/**\"]{extra}) -> Result[{result_type}, IOError] uses File.{effect_name}[\"/data/**\"]\n return File.{name}\nend function"
        );
        let unannotated =
            format!("function sample() -> Unit\n bind operation <- File.{name}\n ()\nend function");
        for (body, expected) in [
            (direct, narrow.clone()),
            (expected_function, narrow.clone()),
            (unannotated, Range::Top),
        ] {
            let source = format!("{IMPORTS}{body}");
            let program = accepted(&source);
            let binding = program
                .resolved
                .stdlib(&format!("Benitoite.IO.File.{name}"))
                .unwrap();
            let scheme = program.types.decl_types.get(binding).unwrap();
            let signature = program.types.range_signatures.get(binding).unwrap();
            assert_eq!(signature.kinds, [Kind::Path]);
            assert_eq!(signature.range_count(), 1);
            assert_eq!(
                signature.shape,
                IoShape::Single {
                    kind: Kind::Path,
                    position: 0
                }
            );
            assert!(
                matches!(scheme.params.first(), Some(Ty::Con(TyCon::Builtin(BuiltinTypeId::PATH_IN), args, ix)) if args.is_empty() && ix == &RangeIndex::var(0))
            );
            assert_eq!(
                scheme.effects.names,
                [EffectName::Builtin(effect, RangeIndex::var(0))]
            );
            let heads: Vec<_> = program
                .resolved
                .refs
                .iter()
                .filter_map(|(node, target)| (*target == binding).then_some(node))
                .collect();
            assert_eq!(heads.len(), 1, "{source}: {heads:?}");
            let head = heads[0];
            assert_eq!(
                program.types.call_ranges.get(head),
                Some(&vec![expected.clone()]),
                "{source}"
            );
            let Ty::Fn(function) = program.types.expr_types.get(head).unwrap() else {
                panic!("operation must have a function type: {source}");
            };
            assert_eq!(
                function.params.first(),
                Some(&Ty::Con(
                    TyCon::Builtin(BuiltinTypeId::PATH_IN),
                    vec![],
                    RangeIndex::fixed(expected.clone())
                )),
                "{source}"
            );
            assert_eq!(
                function.effects.names,
                [EffectName::Builtin(effect, RangeIndex::fixed(expected))],
                "{source}"
            );
            assert!(function.effects.vars.is_empty(), "{source}");
        }
        let wrong_input = format!(
            "{IMPORTS}function sample(path: String{extra}) -> Result[{result_type}, IOError] uses File.{effect_name}\n return File.{name}(path: path{args})\nend function"
        );
        errors(&wrong_input, &["E0401"]);
    }
    let aliased = r#"import Benitoite.Unofficial.IO.File as Files
import Benitoite.Unofficial.Scope
function sample(path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses Files.Read["/data/**"]
 return Files.readTextIn(path: path)
end function"#;
    // 組み込みのエフェクトを宣言するモジュールは改名できない。
    errors(aliased, &["E0339"]);
}

#[test]
fn file_io_constraints_choose_check_indices_and_top_cannot_be_narrowed_afterward() {
    for (annotation, indirect, expected_suffix) in [
        (
            ": Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]",
            false,
            "[\"/data/**\"]",
        ),
        ("", false, "[\"/data/**\"]"),
        ("", true, ""),
    ] {
        let invocation = if indirect {
            "readTop(path: checkedPath)"
        } else {
            "File.readTextIn(path: checkedPath)"
        };
        let top_callee = if indirect {
            "function readTop(path: Scope.PathIn) -> Result[String, IOError] uses File.Read\n return File.readTextIn(path: path)\nend function\n"
        } else {
            ""
        };
        let source = format!(
            r#"{IMPORTS}{top_callee}function sample(path: String) -> Result[String, IOError] uses File.Read
 bind checked{annotation} <- Scope.checkPathIn(pattern: "/data/**", path: path)
 return match checked with
 case Result.Ok(checkedPath) ->
  {invocation}
 case Result.Error(_) -> Result.Ok("failed check")
 end match
end function"#
        );
        let program = accepted(&source);
        let ranges: Vec<_> = program
            .types
            .call_ranges
            .iter()
            .filter(|(_, ranges)| !ranges.is_empty())
            .collect();
        assert_eq!(ranges.len(), 2, "{source}: {ranges:?}");
        assert!(
            ranges
                .iter()
                .all(|(_, ranges)| ranges.len() == 1 && ranges[0].suffix() == expected_suffix),
            "{source}: {ranges:?}"
        );
        if indirect {
            let rejected = source.replace("readTop(path: checkedPath)", "bind wide: Scope.PathIn[\"/data/**\"] <- Scope.widenPathIn(path: checkedPath)\n readTop(path: checkedPath)");
            errors(&rejected, &["E0519"]);
            let result = check(&rejected);
            assert!(
                result
                    .diagnostics
                    .iter()
                    .any(|d| d.is_error() && d.message.contains("notCovered")),
                "{rejected}\n{:?}",
                result.diagnostics
            );
        }
    }
}

#[test]
fn file_handler_clause_projection_and_widen_require_local_facts_for_non_top() {
    for (index, clause, expected_reason) in [
        (
            "[\"/data/a\"]",
            "bind text <- Scope.pathInValue(path: captured)\n resume(Result.Ok(text))",
            Some("unknownSource"),
        ),
        (
            "[\"/data/a\"]",
            "bind wide: Scope.PathIn[\"/data/**\"] <- Scope.widenPathIn(path: captured)\n resume(Result.Ok(\"wide\"))",
            Some("unknownSource"),
        ),
        (
            "",
            "bind text <- Scope.pathInValue(path: captured)\n resume(Result.Ok(text))",
            None,
        ),
        (
            "",
            "bind wide: Scope.PathIn <- Scope.widenPathIn(path: captured)\n resume(Result.Ok(\"wide\"))",
            None,
        ),
        (
            "",
            "bind wide: Scope.PathIn[\"/data/**\"] <- Scope.widenPathIn(path: captured)\n resume(Result.Ok(\"wide\"))",
            Some("unknownSource"),
        ),
    ] {
        let source = format!(
            "{IMPORTS}function sample(path: Scope.PathIn{index}) -> Result[String, IOError] uses File.Read{index}\n return handle File.readTextIn(path: path) with\n case File.readTextIn(captured) ->\n {clause}\n end handle\nend function"
        );
        if let Some(reason) = expected_reason {
            errors(&source, &["E0519"]);
            let result = check(&source);
            assert!(
                result
                    .diagnostics
                    .iter()
                    .any(|d| d.is_error() && d.message.contains(reason)),
                "{source}\n{:?}",
                result.diagnostics
            );
        } else {
            accepted(&source);
        }
    }
}

#[test]
fn file_handler_unhandled_write_is_accepted_but_captured_index_is_invariant() {
    let source = format!(
        r#"{IMPORTS}effect Tick
 function tick() -> Unit
end effect
function sample(path: Scope.PathIn["/data/a.txt"]) -> Unit uses File.Write["/data/**"]
 return handle
  bind _ <- File.writeTextIn(path: path, text: "x")
  tick()
 with
 case tick() -> resume(())
 end handle
end function"#
    );
    accepted(&source);
    for (index, expected) in [("/data/a.txt", &[][..]), ("/data/**", &["E0401"][..])] {
        let source = format!(
            r#"{IMPORTS}function accept(path: Scope.PathIn["{index}"], text: String) -> Result[Unit, IOError]
 return Result.Ok(())
end function
function sample(path: Scope.PathIn["/data/a.txt"]) -> Result[Unit, IOError] uses File.Write["/data/**"]
 return handle File.writeTextIn(path: path, text: "x") with
 case File.writeTextIn(captured, text) -> resume(accept(path: captured, text: text))
 end handle
end function"#
        );
        errors(&source, expected);
        if expected.is_empty() {
            accepted(&source);
        }
    }
}

#[test]
fn file_handler_clause_io_on_another_path_remains_outside_the_handle() {
    let source = |effect| {
        format!(
            r#"{IMPORTS}function sample(protectedPath: Scope.PathIn["/data/a"], other: Scope.PathIn["/logs/a"]) -> Result[Unit, IOError] uses {effect}
 return handle File.writeTextIn(path: protectedPath, text: "x") with
 case File.writeTextIn(captured, text) ->
  bind result <- File.writeTextIn(path: other, text: text)
  resume(result)
 case File.writeText(path, text) -> Result.Ok(())
 case File.appendText(path, text) -> Result.Ok(())
 case File.writeBytes(path, content) -> Result.Ok(())
 case File.appendBytes(path, content) -> Result.Ok(())
 case File.appendTextIn(path, text) -> Result.Ok(())
 case File.writeBytesIn(path, content) -> Result.Ok(())
 case File.appendBytesIn(path, content) -> Result.Ok(())
 case File.createDirectory(path) -> Result.Ok(())
 case File.remove(path) -> Result.Ok(())
 case File.removeTree(path) -> Result.Ok(())
 case File.rename(from, to) -> Result.Ok(())
 case File.openWriter(path, mode) -> Result.Ok(())
 case File.write(writer, text) -> Result.Ok(())
 case File.writeLine(writer, text) -> Result.Ok(())
 case File.writeChunk(writer, content) -> Result.Ok(())
 end handle
end function"#
        )
    };
    accepted(&source("File.Write[\"/logs/a\"]"));
    errors(&source("File.Write[\"/data/a\"]"), &["E0519"]);
}

#[test]
fn file_single_target_operations_work_in_implementation_methods_with_dictionaries() {
    let source = format!(
        r#"{IMPORTS}import Benitoite.Trait
trait Read[T]
 function read(value: T, path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses File.Read["/data/**"]
end trait
implement Read[String]
 function read(value: String, path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses File.Read["/data/**"]
  bind _ <- Trait.Show.show(value)
  return File.readTextIn(path: path)
 end function
end implement
function sample(path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses File.Read["/data/**"]
 return Read.read(value: "read", path: path)
end function"#
    );
    accepted(&source);
    let bad = source.replace("value: \"read\"", "value: 1");
    errors(&bad, &["E0705"]);
}
