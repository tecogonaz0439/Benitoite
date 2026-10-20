//! 構築器を通常値と区別した専用コアへ移す（設計書 02-06「脱糖」）。
use super::*;
use crate::resolve::builders::BuilderOp;
use crate::typeck::BuilderOperation;

pub(super) fn core_kind(kind: &crate::typeck::BuilderKind) -> BuilderKind {
    match kind {
        crate::typeck::BuilderKind::String => BuilderKind::String,
        crate::typeck::BuilderKind::Bytes => BuilderKind::Bytes,
        crate::typeck::BuilderKind::List(t) => BuilderKind::List(t.clone()),
    }
}

impl State<'_> {
    #[inline(never)]
    pub(super) fn builder_operation(
        &mut self,
        call: &ast::CallExpr,
        op: &BuilderOperation,
    ) -> Result<Comp, InternalError> {
        let id = self
            .builders
            .get(&op.builder.0)
            .copied()
            .ok_or_else(|| error("missing builder local"))?;
        let kind = core_kind(&op.kind);
        let mut pending = vec![];
        let mut args = vec![];
        // ソース順の通常引数を一度ずつ評価し、専用操作は再開後の同じ局所欄を読む。
        // 構築器の番号を通常の値の let へ変換しない（設計書 01-12「構築器の専用操作と脱糖」）。
        for node in &op.args {
            let arg = call
                .args
                .iter()
                .filter_map(ast::Arg::expr)
                .find(|e| e.id() == *node)
                .ok_or_else(|| error("missing builder argument"))?;
            args.push(self.eval(arg, &mut pending)?);
        }
        let ty = match op.op {
            BuilderOp::Append | BuilderOp::AppendAll => basic(BuiltinTypeId::UNIT),
            BuilderOp::Copy => kind.contents(),
            BuilderOp::Length => basic(BuiltinTypeId::INTEGER),
        };
        let comp = Comp {
            kind: CompKind::BuilderOp {
                id,
                kind,
                op: op.op,
                args,
            },
            ty,
            eff: EffectSet::empty(),
            origin: call.span,
        };
        Ok(finish(pending, comp, call.span))
    }
}
