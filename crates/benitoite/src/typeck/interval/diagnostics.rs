//! 元の演算・原因・一次位置による算術と固定域の警告の統合
//! （設計書 02-05「警告」、02-10「警告の扱い」）。

use super::BodyReport;
use super::arithmetic::{Candidate, Cause, TargetOperation};
use super::identity::{IdentityMap, SourceNode};
use crate::base::{NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::ast::{Expr, UnOp};
use std::collections::HashSet;

/// 定数警告を先に登録し、本体順・先行順で最初の新候補だけを採る。
#[derive(Default)]
pub(in crate::typeck) struct Warnings(HashSet<(NodeId, Cause, Span)>);

impl Warnings {
    /// 独立交換の任意の記録先だけで、旧定数警告の採用済みの組を読む。
    pub(super) fn observed(&self) -> serde_json::Value {
        let mut rows: Vec<_> = self
            .0
            .iter()
            .map(|(node, cause, span)| {
                let cause = match cause {
                    Cause::ZeroDivisor => "zeroDivisor",
                    Cause::Overflow => "overflow",
                    Cause::OutsideDomain => "outsideDomain",
                };
                serde_json::json!({"node":node.0,"cause":cause,"primary":[span.file.0,span.start.0,span.end.0]})
            })
            .collect();
        rows.sort_by_cached_key(serde_json::Value::to_string);
        serde_json::json!(rows)
    }

    /// 既存の定数診断を、新しい候補より先に採用済みとして登録する。
    pub fn constant(&mut self, node: NodeId, cause: Cause, primary: Span) {
        self.0.insert((node, cause, primary));
    }

    /// 候補の元の列を保ち、本体内の先行順で重複しない診断だけを追加する。
    pub fn append(
        &mut self,
        identity: &IdentityMap<'_>,
        report: &BodyReport,
        diagnostics: &mut Vec<Diagnostic>,
    ) {
        let Some(analysis) = &report.flow else {
            return;
        };

        // 保存した候補列の順序は比較用に保つ。利用者向けの採用順だけを整える。
        let mut candidates = Vec::new();
        candidates.extend(analysis.candidates.iter());
        // independentRev.reverse: 入れ子の内側から保存した順に各入力の候補を読む。
        for input in &analysis.independent {
            let own = input
                .candidates
                .iter()
                .filter(|c| c.preorder >= input.start);
            candidates.extend(own);
        }
        // 安定ソートにより、同じキーでは親、独立入力の記録順、各候補列の順を保つ。
        candidates.sort_by_key(|c| c.preorder);
        for candidate in candidates {
            let Some(key) = identity.key(candidate.preorder) else {
                continue;
            };
            if key.definition != report.name {
                continue;
            }
            let Some(occurrence) = usize::try_from(key.surface_preorder)
                .ok()
                .and_then(|i| identity.occurrences.get(i))
            else {
                continue;
            };
            // キーの対象演算と元の出現の一致を確認してから診断にする。
            let operation_matches = match (occurrence.source, candidate.operation) {
                (SourceNode::Expression(Expr::Binary(b)), TargetOperation::Binary(op)) => {
                    b.op == op
                }
                (SourceNode::Expression(Expr::Unary(u)), TargetOperation::Neg) => u.op == UnOp::Neg,
                (
                    SourceNode::Expression(Expr::Call(call)),
                    TargetOperation::Standard { contract, .. },
                ) => {
                    // 宣言・型・元キーの同定は候補を保存した domainCall が行う。
                    // ここでは同じ元 call と、契約位置の引数の一次位置を照合する。
                    occurrence.form == super::input::SurfaceForm::Call
                        && matches!(call.callee.as_ref(), Expr::Name(_))
                        && contract
                            .parameters
                            .get(contract.argument)
                            .is_some_and(|name| {
                                crate::typeck::consts::standard_argument(
                                    call,
                                    contract.argument,
                                    name,
                                )
                                .is_some_and(|argument| argument.span() == candidate.primary)
                            })
                }
                _ => false,
            };
            if !operation_matches || occurrence.origin != Some(candidate.origin) {
                continue;
            }
            if self
                .0
                .insert((candidate.origin.node, candidate.cause, candidate.primary))
                && let Some(diagnostic) = diagnostic(candidate)
            {
                diagnostics.push(diagnostic);
            }
        }
    }
}

fn interval(lo: i128, hi: i128) -> String {
    format!("[{lo},{hi}]")
}

fn diagnostic(candidate: &Candidate) -> Option<Diagnostic> {
    let mut builder = match candidate.cause {
        Cause::OutsideDomain => {
            let TargetOperation::Standard { contract, .. } = candidate.operation else {
                return None;
            };
            let (lo, hi) = candidate.left.bounds()?;
            // Bottom・Top・交差を診断へ広げず、候補の正常域も契約と照合する。
            if candidate.right.bounds() != Some((contract.minimum, contract.maximum))
                || !(hi < contract.minimum || contract.maximum < lo)
            {
                return None;
            }
            DiagBuilder::new(DiagCode::W0404)
                .arg("parameter", *contract.parameters.get(contract.argument)?)
                .arg("function", contract.name.strip_prefix("Benitoite.")?)
                .arg("interval", interval(lo, hi))
                .arg("range", interval(contract.minimum, contract.maximum))
                .note("inferred_range")
                .note("allowed_range")
        }
        Cause::ZeroDivisor => {
            let (lo, hi) = candidate.right.bounds()?;
            DiagBuilder::new(DiagCode::W0401)
                .arg("interval", interval(lo, hi))
                .note("inferred_range")
        }
        Cause::Overflow => {
            let bounds = candidate.operation.result_bounds(
                candidate.kind,
                candidate.left,
                candidate.right,
            )?;
            DiagBuilder::new(DiagCode::W0402)
                .arg(
                    "ty",
                    candidate.kind.builtin().display_name().unwrap_or("Integer"),
                )
                .arg("interval", bounds.to_string())
                .arg(
                    "range",
                    interval(candidate.kind.min(), candidate.kind.max()),
                )
                .note("inferred_range")
                .note("allowed_range")
        }
    }
    .primary(candidate.primary)
    .note("local_analysis");
    for span in candidate.origins.as_slice() {
        builder = builder.secondary(*span, "origin");
    }
    Some(builder.build())
}
