//! 展開・推論した型の資源の上限（設計書 02-03「入れ子の深さ」）。

use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::types::Ty;

pub(super) const MAX_TYPE_DEPTH: usize = 1000;
pub(super) const MAX_TYPE_NODES: usize = 16_384;

#[derive(Clone, Copy)]
pub(super) enum TypeLimit {
    Depth,
    Nodes,
}
impl TypeLimit {
    pub fn diagnostic(self, span: Span) -> Diagnostic {
        let limit = match self {
            Self::Depth => format!("{MAX_TYPE_DEPTH}{}", super::text::TYPE_DEPTH),
            Self::Nodes => format!("{MAX_TYPE_NODES}{}", super::text::TYPE_NODES),
        };
        DiagBuilder::new(DiagCode::E0208)
            .arg("limit", limit)
            .primary(span)
            .build()
    }
    pub fn diagnostic_limits(span: Span) -> Diagnostic {
        // 単一化で組み立てた一時的な関数型が超えた場合は、元の二つの型から
        // 超えた上限を復元できない。両方の上限を示して、失敗の診断を失わない。
        DiagBuilder::new(DiagCode::E0208)
            .arg(
                "limit",
                format!(
                    "{MAX_TYPE_DEPTH}{} / {MAX_TYPE_NODES}{}",
                    super::text::TYPE_DEPTH,
                    super::text::TYPE_NODES
                ),
            )
            .primary(span)
            .build()
    }
}

#[derive(Default)]
pub(super) struct TypeBudget {
    nodes: usize,
}
impl TypeBudget {
    pub fn enter(&mut self, depth: usize) -> Result<(), TypeLimit> {
        if depth > MAX_TYPE_DEPTH {
            return Err(TypeLimit::Depth);
        }
        if self.nodes == MAX_TYPE_NODES {
            return Err(TypeLimit::Nodes);
        }
        self.nodes = self.nodes.saturating_add(1);
        Ok(())
    }

    // 同時置換の結果を、複製する前に数える。置換先のパラメータは再置換しない。
    // 明示の積み重ねなので、拒否する型の深さにも Rust のスタックを使わない。
    pub fn substituted(&mut self, ty: &Ty, args: &[Ty], depth: usize) -> Result<(), TypeLimit> {
        let mut pending = vec![(ty, depth, true)];
        while let Some((ty, depth, substitute)) = pending.pop() {
            if substitute
                && let Ty::Param(i) = ty
                && let Some(arg) = usize::try_from(*i).ok().and_then(|i| args.get(i))
            {
                pending.push((arg, depth, false));
                continue;
            }
            self.enter(depth)?;
            let next = depth.saturating_add(1);
            match ty {
                Ty::Con(_, ts) | Ty::App(_, ts) => {
                    pending.extend(ts.iter().map(|t| (t, next, substitute)));
                }
                Ty::Fn(f) => {
                    pending.push((&f.ret, next, substitute));
                    pending.extend(f.params.iter().map(|t| (t, next, substitute)));
                }
                Ty::Param(_) | Ty::Rigid { .. } => {}
            }
        }
        Ok(())
    }
}
