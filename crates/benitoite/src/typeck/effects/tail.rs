//! 節の終わり方と途中の脱出を構文で判定する（設計書 02-05「書く位置の検査」、01-08、ADR 0151）。
use crate::syntax::ast::*;

pub(super) fn resumptive(body: &Block) -> bool {
    !escape_block(body) && tail_block(body)
}
fn tail_block(b: &Block) -> bool {
    matches!(b.stmts.last(), Some(Stmt::Expr(e)) if tail_expr(e))
}
fn tail_if(e: &IfExpr) -> bool {
    tail_block(&e.then_block)
        && match &e.else_branch {
            Some(ElseBranch::Block(b)) => tail_block(b),
            Some(ElseBranch::If(e)) => tail_if(e),
            None => false,
        }
}
fn tail_expr(e: &Expr) -> bool {
    match e {
        Expr::Resume(_) => true,
        Expr::Paren(e) => tail_expr(&e.inner),
        Expr::If(e) => tail_if(e),
        Expr::Match(e) => !e.arms.is_empty() && e.arms.iter().all(|a| tail_block(&a.body)),
        // with と内側の handle の後には解放とハンドラの終了がある。
        // and/or は短絡の道筋が resume で終わらない（設計書 01-08「末尾呼び出し」）。
        Expr::Lit(_)
        | Expr::Interp(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::List(_)
        | Expr::Call(_)
        | Expr::Record(_)
        | Expr::Binary(_)
        | Expr::Unary(_)
        | Expr::Pipe(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Error(_) => false,
    }
}
fn escape_block(b: &Block) -> bool {
    b.stmts.iter().any(|s| match s {
        Stmt::Bind(b) => escape(&b.value),
        Stmt::Expr(e) => escape(e),
        Stmt::Error(_) => false,
    })
}
fn escape_if(e: &IfExpr) -> bool {
    escape(&e.cond)
        || escape_block(&e.then_block)
        || match &e.else_branch {
            Some(ElseBranch::Block(b)) => escape_block(b),
            Some(ElseBranch::If(e)) => escape_if(e),
            None => false,
        }
}
fn escape(e: &Expr) -> bool {
    match e {
        Expr::Return(_) | Expr::Try(_) => true,
        // 内側のラムダの return と try は別の関数の呼び出しを終える（設計書 01-09）。
        Expr::Lambda(_) => false,
        Expr::Paren(e) => escape(&e.inner),
        Expr::Interp(e) => e.segments.iter().any(|s| escape(&s.expr)),
        Expr::List(e) => e.elems.iter().any(|e| match e {
            ListElem::Expr(e) => escape(e),
            ListElem::Spread(s) => escape(&s.expr),
        }),
        Expr::Call(e) => {
            escape(&e.callee)
                || e.args
                    .iter()
                    .any(|a| matches!(a, Arg::Expr(e) if escape(e)))
        }
        Expr::Record(e) => {
            e.base.as_ref().is_some_and(|e| escape(e)) || e.fields.iter().any(|f| escape(&f.value))
        }
        Expr::Binary(e) => escape(&e.lhs) || escape(&e.rhs),
        Expr::Unary(e) => escape(&e.operand),
        Expr::Pipe(e) => escape(&e.lhs) || escape(&e.rhs),
        Expr::If(e) => escape_if(e),
        Expr::Match(e) => {
            escape(&e.scrutinee)
                || e.arms
                    .iter()
                    .any(|a| a.guard.as_ref().is_some_and(|g| escape(g)) || escape_block(&a.body))
        }
        Expr::Lazy(e) => escape_block(&e.body),
        Expr::With(e) => e.binds.iter().any(|b| escape(&b.value)) || escape_block(&e.body),
        Expr::Handle(e) => escape_block(&e.body) || e.clauses.iter().any(|c| escape_block(&c.body)),
        Expr::Resume(e) => escape(&e.value),
        Expr::Lit(_) | Expr::Unit(_) | Expr::Name(_) | Expr::Error(_) => false,
    }
}
