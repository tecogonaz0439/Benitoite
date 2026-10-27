//! 検査ごとに渡す独立交換の任意の記録先
//! （設計書 02-05「区間解析の式の識別」）。
//! 解析済みの対応だけを読み、無効時は複写・確保も予算操作も行わない。

use super::{BodyReport, arithmetic::Candidate, identity::IdentityMap};
use serde_json::{Value, json};

fn span(s: crate::base::Span) -> Value {
    json!([s.file.0, s.start.0, s.end.0])
}

fn candidate(c: &Candidate) -> Value {
    json!({"preorder":c.preorder.to_string(), "node":c.origin.node.0,
    "primary":span(c.primary), "originSpan":span(c.origin.span), "operation":format!("{:?}", c.operation),
    "cause":match c.cause {
        super::arithmetic::Cause::Overflow => "overflow",
        super::arithmetic::Cause::ZeroDivisor => "zeroDivisor",
        super::arithmetic::Cause::OutsideDomain => "outsideDomain",
    }})
}

fn value(value: &Result<super::flow::Approx, super::IdentityStop>) -> Value {
    match value {
        Ok(value) => value.observed(),
        Err(_) => Value::Null,
    }
}

/// 新しい解析より前の診断と採用済みの組を、候補の統合の比較用に保存する。
pub(super) fn legacy_warnings(
    diagnostics: &[crate::diag::Diagnostic],
    warnings: &super::diagnostics::Warnings,
) -> Value {
    let diagnostics: Vec<_> = diagnostics.iter().filter(|d| matches!(d.code,
        Some(crate::diag::DiagCode::W0401 | crate::diag::DiagCode::W0402 | crate::diag::DiagCode::W0404)))
        .map(|d| json!({"code":format!("{:?}",d.code),"primary":d.primary.as_ref().map(|p|span(p.span))})).collect();
    json!({"diagnostics":diagnostics,"identities":warnings.observed()})
}

/// 発見の消費と混ぜず、解析の終了直後・本体予算のリセット前を保存する。
pub(super) fn context(
    sink: Option<&mut Vec<Value>>,
    identity: Option<&IdentityMap<'_>>,
    budget: &super::budget::Budget,
) {
    let (Some(records), Some(identity)) = (sink, identity) else {
        return;
    };
    records.push(json!({"definition":identity.definition,"contextBudget":{
        "body":{"operations":budget.body.operations.to_string(),"temporary":budget.body.temporary.to_string(),
            "saved":budget.body.saved.to_string(),"peak":budget.body.peak.to_string()},
        "whole":{"operations":budget.whole.operations.to_string(),"saved":budget.whole.saved.to_string(),"peak":budget.whole.peak.to_string()}}}));
}

pub(super) fn record(
    sink: Option<&mut Vec<Value>>,
    identity: &IdentityMap<'_>,
    report: &BodyReport,
) {
    let Some(records) = sink else { return };
    let occurrences: Vec<_> = (0..identity.occurrences.len())
        .map(|i| match identity.occurrences.get(i) {
            Some(e) => json!({"preorder":e.preorder.to_string(),
                    "parent":e.parent.map(|n| n.to_string()), "end":e.end.map(|n| n.to_string()),
                    "form":format!("{:?}",e.form), "node":e.origin.map(|o|o.node.0),
                    "span":e.origin.map(|o|span(o.span))}),
            // 表の内部の不整合も行を詰めずに残し、交換の照合で拒否する。
            None => json!({"preorder":i.to_string(),"missing":true}),
        })
        .collect();
    let candidates: Vec<_> = report
        .flow
        .as_ref()
        .into_iter()
        .flat_map(|flow| &flow.candidates)
        .map(candidate)
        .collect();
    let independent: Vec<_> = report
        .flow
        .as_ref()
        .into_iter()
        .flat_map(|flow| &flow.independent)
        .map(|input| {
            json!({"start":input.start.to_string(),
                "value":value(&input.value),
                "candidates":input.candidates.iter().map(candidate).collect::<Vec<_>>(),
                "stopped":input.value.as_ref().err().map(|reason| format!("{reason:?}")),
                "unsupported":input.unsupported})
        })
        .collect();
    let context_budget = records
        .last()
        .filter(|r| r["definition"] == identity.definition)
        .map(|r| r["contextBudget"].clone())
        .unwrap_or(Value::Null);
    if records
        .last()
        .is_some_and(|r| r["definition"] == identity.definition)
    {
        records.pop();
    }
    records.push(
        json!({"definition":identity.definition, "occurrences":occurrences,"contextBudget":context_budget,
            "next":identity.next.to_string(), "coverage":format!("{:?}",report.coverage),
            "value":report.flow.as_ref().map(|flow| value(&flow.value)),
            "unsupported":report.flow.as_ref().is_some_and(|flow|flow.unsupported),
            "usage":{"operations":report.usage.operations.to_string(),
                "temporary":report.usage.temporary.to_string(),"saved":report.usage.saved.to_string(),
                "peak":report.usage.peak.to_string()},
            "candidates":candidates,"independent":independent}),
    );
}

/// 本体のない入口停止も残す。空の definition は本体ではない検査全体の記録を表す。
pub(super) fn finish(
    sink: Option<&mut Vec<Value>>,
    report: &super::Report,
    pending: &std::collections::BTreeMap<crate::base::NodeId, Box<super::Pending<'_>>>,
    budget: &super::budget::Budget,
    fuel: u32,
) {
    let Some(records) = sink else { return };
    let mut ordered: Vec<_> = pending.values().collect();
    ordered.sort_unstable_by_key(|p| p.definition.order);
    let phases: Vec<_> = report.definitions.iter().zip(&ordered).map(|(phase,p)| {
        let status = |value: Option<Result<(), super::IdentityStop>>| value.map(|v|
            match v { Ok(())=>json!("complete"), Err(stop)=>json!({"stopped":format!("{stop:?}")}) });
        json!({"definition":p.definition.name,"entry":status(phase.prepared),
            "discovery":status(phase.discovery),"queue":status(phase.queue),
            "discovered":phase.discovered.iter().map(|(name,ready)|json!({"definition":name,"ready":ready})).collect::<Vec<_>>(),
            "pending":phase.pending,"embeddedStop":phase.embedded_stop.map(|s|format!("{s:?}"))})
    }).collect();
    records.push(json!({"definition":"","kind":"whole","fuel":fuel.to_string(),
        "limits":{"body":{"operations":budget.limits.body.operations.to_string(),"items":budget.limits.body.items.to_string()},
            "whole":{"operations":budget.limits.whole.operations.to_string(),"items":budget.limits.whole.items.to_string()}},
        "phases":phases,"stopped":report.stopped.map(|s|format!("{s:?}")),
        "bodies":report.bodies.iter().map(|b|json!({"definition":b.name,"coverage":format!("{:?}",b.coverage)})).collect::<Vec<_>>(),
        "remainingDefinitions":ordered.iter().filter(|p|report.remaining.is_some_and(|start|p.definition.order.module==start.module && p.definition.order>=start)).map(|p|&p.definition.name).collect::<Vec<_>>(),
        "remainingModules":report.remaining_modules.iter().map(|m|ordered.iter().filter(|p|p.definition.order.module==*m).map(|p|&p.definition.name).collect::<Vec<_>>()).collect::<Vec<_>>(),
        "after":{"operations":report.whole.operations.to_string(),"saved":report.whole.saved.to_string(),"peak":report.whole.peak.to_string()}}));
}
