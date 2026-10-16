//! 明示の積み重ねによる依存グラフの探索（設計書 02-04「依存グラフと循環の検出」）。

use std::collections::BTreeMap;

use crate::base::{ModuleId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::ast;

use super::{ModuleTable, find};

struct Frame {
    module: ModuleId,
    next: usize,
    incoming: Option<Span>,
}

pub(super) fn detect(modules: &ModuleTable, asts: &[ast::Module]) -> Vec<Diagnostic> {
    let mut diagnostics = Vec::new();
    let spans: BTreeMap<_, _> = asts
        .iter()
        .flat_map(|ast| &ast.imports)
        .map(|import| (import.id, find::import_span(import)))
        .collect();
    // active は道筋の位置、done は探索済みの印。平行する import の辺も一つずつ辿る
    // （設計書 02-04「依存グラフと循環の検出」）。
    let mut active = BTreeMap::new();
    let mut done = std::collections::BTreeSet::new();
    for root in modules.iter() {
        if done.contains(&root.id) {
            continue;
        }
        active.insert(root.id, 0usize);
        let mut stack = vec![Frame {
            module: root.id,
            next: 0,
            incoming: None,
        }];
        while let Some(frame) = stack.last_mut() {
            let edge = modules.get(frame.module).and_then(|module| {
                if let Some(edge) = module.imports.get(frame.next) {
                    Some((edge.target, spans.get(&edge.decl).copied()))
                } else {
                    module
                        .internal_dependencies
                        .get(frame.next.saturating_sub(module.imports.len()))
                        .map(|edge| (Some(edge.target), Some(edge.span)))
                }
            });
            frame.next = frame.next.saturating_add(1);
            let Some((target, span)) = edge else {
                if let Some(frame) = stack.pop() {
                    active.remove(&frame.module);
                    done.insert(frame.module);
                }
                continue;
            };
            let (Some(target), Some(span)) = (target, span) else {
                continue;
            };
            if let Some(start) = active.get(&target).copied() {
                let members = stack.get(start..).unwrap_or(&[]);
                let mut names: Vec<_> = members
                    .iter()
                    .filter_map(|frame| {
                        modules.get(frame.module).map(|module| module.name.dotted())
                    })
                    .collect();
                if let Some(module) = modules.get(target) {
                    names.push(module.name.dotted());
                }
                let mut builder = DiagBuilder::new(DiagCode::E0322)
                    .primary(span)
                    .arg("chain", names.join(" -> "))
                    .note("chain");
                for member in members.iter().skip(1).filter_map(|frame| frame.incoming) {
                    builder = builder.secondary(member, "member");
                }
                diagnostics.push(builder.build());
            } else if !done.contains(&target) {
                active.insert(target, stack.len());
                stack.push(Frame {
                    module: target,
                    next: 0,
                    incoming: Some(span),
                });
            }
        }
    }
    diagnostics
}
