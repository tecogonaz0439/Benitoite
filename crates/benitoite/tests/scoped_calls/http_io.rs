//! Http.sendIn の本番署名と通常の解析入口で、対象入力・潜在効果・節の添字を照合する。
//! 関門: 仮の Single 署名と File の検査は、Http の登録漏れや新旧二操作の完全性に届かない。
//! 表の各行は異なる型制約か節の境界を守り、本番の差し込み口を増やさない。

use super::{check, pipeline};
use benitoite::types::builtin::{BuiltinEffectId, BuiltinTypeId, RangeIndex};
use benitoite::types::scope::{EndpointPattern, HostPattern, Kind, Port, PortRange, Range};
use benitoite::types::signature::IoShape;
use benitoite::types::{EffectName, Ty, TyCon};

const IMPORT: &str = "import Benitoite.Unofficial.Network.Http\n";
const NARROW: &str = "[\"api.example\", 443]";

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

fn errors(source: &str, expected: &[&str], reason: Option<&str>) {
    let result = check(source);
    let actual: Vec<_> = result
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .map(|d| d.code.unwrap().info().id)
        .collect();
    assert_eq!(actual, expected, "{source}\n{:?}", result.diagnostics);
    if let Some(reason) = reason {
        assert!(
            result
                .diagnostics
                .iter()
                .any(|d| d.is_error() && d.message.contains(reason)),
            "{source}\n{:?}",
            result.diagnostics
        );
    }
}

#[test]
fn http_single_target_signature_follows_input_and_expected_function_input() {
    let narrow = Range::Endpoint(EndpointPattern {
        host: HostPattern::parse("api.example").unwrap(),
        ports: PortRange::new(Port::new(443), Port::new(443)).unwrap(),
    });
    for (body, expected) in [
        (
            format!(
                "function sample(request: Http.RequestIn{NARROW}) -> Result[Http.Response, NetworkError] uses Http.Connect{NARROW}\n return Http.sendIn(request: request)\nend function"
            ),
            narrow.clone(),
        ),
        (
            format!(
                "function sample() -> function(request: Http.RequestIn{NARROW}) -> Result[Http.Response, NetworkError] uses Http.Connect{NARROW}\n return Http.sendIn\nend function"
            ),
            narrow.clone(),
        ),
        (
            "function sample() -> Unit\n bind operation <- Http.sendIn\n ()\nend function".into(),
            Range::Top,
        ),
    ] {
        let source = format!("{IMPORT}{body}");
        let program = accepted(&source);
        let binding = program
            .resolved
            .stdlib("Benitoite.Network.Http.sendIn")
            .unwrap();
        let signature = program.types.range_signatures.get(binding).unwrap();
        assert_eq!(signature.kinds, [Kind::Endpoint]);
        assert_eq!(signature.range_count(), 1);
        assert_eq!(
            signature.shape,
            IoShape::Single {
                kind: Kind::Endpoint,
                position: 0
            }
        );
        let scheme = program.types.decl_types.get(binding).unwrap();
        assert!(
            matches!(scheme.params.first(), Some(Ty::Con(TyCon::Builtin(BuiltinTypeId::REQUEST_IN), args, ix)) if args.is_empty() && ix == &RangeIndex::var(0))
        );
        assert_eq!(
            scheme.effects.names,
            [EffectName::Builtin(
                BuiltinEffectId::HTTP_CONNECT,
                RangeIndex::var(0)
            )]
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
                TyCon::Builtin(BuiltinTypeId::REQUEST_IN),
                vec![],
                RangeIndex::fixed(expected.clone())
            )),
            "{source}"
        );
        assert_eq!(
            function.effects.names,
            [EffectName::Builtin(
                BuiltinEffectId::HTTP_CONNECT,
                RangeIndex::fixed(expected)
            )],
            "{source}"
        );
        assert!(function.effects.vars.is_empty(), "{source}");
    }
    errors(
        &format!(
            "{IMPORT}function sample(request: Http.ClientRequest) -> Result[Http.Response, NetworkError] uses Http.Connect\n return Http.sendIn(request: request)\nend function"
        ),
        &["E0401"],
        None,
    );
    errors(
        "import Benitoite.Unofficial.Network.Http as H\nfunction sample() -> Unit\n ()\nend function",
        &["E0339"],
        None,
    );
}

#[test]
fn http_io_constraints_choose_check_index_and_top_cannot_be_narrowed_afterward() {
    for (annotation, indirect, expected_suffix) in [
        (
            ": Result[Http.RequestIn[\"api.example\", 443], Http.RequestCheckError]",
            false,
            NARROW,
        ),
        ("", false, NARROW),
        ("", true, ""),
    ] {
        let invocation = if indirect {
            "sendTop(request: checkedRequest)"
        } else {
            "Http.sendIn(request: checkedRequest)"
        };
        let top_callee = if indirect {
            "function sendTop(request: Http.RequestIn) -> Result[Http.Response, NetworkError] uses Http.Connect\n return Http.sendIn(request: request)\nend function\n"
        } else {
            ""
        };
        let source = format!(
            r#"{IMPORT}{top_callee}function sample(request: Http.ClientRequest) -> Result[Http.Response, NetworkError] uses Http.Connect
 bind checked{annotation} <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 443, maximumPort: 443, request: request)
 return match checked with
 case Result.Ok(checkedRequest) -> {invocation}
 case Result.Error(_) -> Result.Ok(Http.text(status: 400, s: "failed check"))
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
            let rejected = source.replace("sendTop(request: checkedRequest)", "bind wide: Http.RequestIn[\"api.example\", 443] <- Http.widenRequestIn(request: checkedRequest)\n sendTop(request: checkedRequest)");
            errors(&rejected, &["E0519"], Some("notCovered"));
        }
    }
}

#[test]
fn http_handler_clause_projection_and_widen_require_local_facts_for_non_top() {
    for (index, clause, expected_reason) in [
        (
            NARROW,
            "bind original <- Http.requestInValue(request: captured)\n resume(Result.Ok(Http.text(status: 200, s: Http.ClientRequest.url(original))))",
            Some("unknownSource"),
        ),
        (
            NARROW,
            "bind wide: Http.RequestIn[\"**.example\", 400..500] <- Http.widenRequestIn(request: captured)\n resume(Result.Ok(Http.text(status: 200, s: \"wide\")))",
            Some("unknownSource"),
        ),
        (
            "",
            "bind original <- Http.requestInValue(request: captured)\n resume(Result.Ok(Http.text(status: 200, s: Http.ClientRequest.url(original))))",
            None,
        ),
        (
            "",
            "bind wide: Http.RequestIn <- Http.widenRequestIn(request: captured)\n resume(Result.Ok(Http.text(status: 200, s: \"wide\")))",
            None,
        ),
        (
            "",
            "bind wide: Http.RequestIn[\"**.example\", 400..500] <- Http.widenRequestIn(request: captured)\n resume(Result.Ok(Http.text(status: 200, s: \"wide\")))",
            Some("unknownSource"),
        ),
    ] {
        let source = format!(
            "{IMPORT}function sample(request: Http.RequestIn{index}) -> Result[Http.Response, NetworkError] uses Http.Connect{index}\n return handle Http.sendIn(request: request) with\n case Http.sendIn(captured) ->\n {clause}\n end handle\nend function"
        );
        if let Some(reason) = expected_reason {
            errors(&source, &["E0519"], Some(reason));
        } else {
            accepted(&source);
        }
    }
}

#[test]
fn http_handlers_require_both_operations_and_keep_captured_input_invariant() {
    let old_only = |effect: &str| {
        format!(
            "{IMPORT}function sample(request: Http.ClientRequest) -> Result[Http.Response, NetworkError]{effect}\n return handle Http.send(request: request) with\n case Http.send(captured) -> Result.Ok(Http.text(status: 200, s: \"handled\"))\n end handle\nend function"
        )
    };
    accepted(&old_only(" uses Http.Connect"));
    errors(&old_only(""), &["E0501"], None);
    let complete = old_only("").replace(" end handle", " case Http.sendIn(captured) -> Result.Ok(Http.text(status: 200, s: \"handled in\"))\n end handle");
    accepted(&complete);
    for (index, expected) in [
        (NARROW, &[][..]),
        ("[\"**.example\", 400..500]", &["E0401"][..]),
    ] {
        let source = format!(
            r#"{IMPORT}function accept(request: Http.RequestIn{index}) -> Result[Http.Response, NetworkError]
 return Result.Ok(Http.text(status: 200, s: "forwarded"))
end function
function sample(request: Http.RequestIn{NARROW}) -> Result[Http.Response, NetworkError] uses Http.Connect["**.example", 400..500]
 return handle Http.sendIn(request: request) with
 case Http.sendIn(captured) -> resume(accept(request: captured))
 end handle
end function"#
        );
        if expected.is_empty() {
            accepted(&source);
        } else {
            errors(&source, expected, None);
        }
    }
}

#[test]
fn http_complete_handler_leaves_its_own_other_endpoint_io_outside() {
    let source = |effect| {
        format!(
            r#"{IMPORT}function sample(protectedRequest: Http.RequestIn["api.example", 443], other: Http.RequestIn["logs.example", 8443]) -> Result[Http.Response, NetworkError] uses {effect}
 return handle Http.sendIn(request: protectedRequest) with
 case Http.sendIn(captured) ->
  bind result <- Http.sendIn(request: other)
  resume(result)
 case Http.send(captured) -> Result.Ok(Http.text(status: 200, s: "old"))
 end handle
end function"#
        )
    };
    accepted(&source("Http.Connect[\"logs.example\", 8443]"));
    errors(
        &source("Http.Connect[\"api.example\", 443]"),
        &["E0519"],
        Some("notCovered"),
    );
}
