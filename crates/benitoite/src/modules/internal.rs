//! 構文に必要な標準モジュールを抽出する（設計書 02-04「依存グラフと循環の検出」）。
use super::ModulePath;
use crate::base::Span;
use crate::syntax::ast::*;

pub(super) fn requested(module: &Module) -> Vec<(ModulePath, Span)> {
    let mut out = Vec::new();
    let mut found = |e: &Expr| {
        if let Expr::Try(t) = e
            && matches!(t.action, TryAction::Die { .. })
        {
            for path in [
                vec!["Benitoite", "Trait"],
                vec!["Benitoite", "IO", "Process"],
            ] {
                out.push((
                    ModulePath(path.into_iter().map(String::from).collect()),
                    t.span,
                ));
            }
        }
    };
    for decl in &module.decls {
        match &decl.item {
            Item::Fn(f) => {
                if let Some(body) = &f.body {
                    visit_block(body, &mut found);
                }
            }
            Item::Const(c) => visit_expr(&c.value, &mut found),
            Item::Impl(i) => {
                for f in &i.fns {
                    if let Some(body) = &f.decl.body {
                        visit_block(body, &mut found);
                    }
                }
            }
            Item::Data(_)
            | Item::Alias(_)
            | Item::ExternalType(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Error(_) => {}
        }
    }
    out
}

fn visit_block(b: &Block, f: &mut impl FnMut(&Expr)) {
    for s in &b.stmts {
        match s {
            Stmt::Expr(e) => visit_expr(e, f),
            Stmt::Bind(b) => visit_expr(&b.value, f),
            Stmt::Error(_) => {}
        }
    }
}
// 呼び出し側の検査は If 自体を対象にしないので、else if の子だけを同じ順序で辿る。
fn visit_if(i: &IfExpr, f: &mut impl FnMut(&Expr)) {
    visit_expr(&i.cond, f);
    visit_block(&i.then_block, f);
    if let Some(b) = &i.else_branch {
        match b {
            ElseBranch::Block(b) => visit_block(b, f),
            ElseBranch::If(i) => visit_if(i, f),
        }
    }
}
#[inline(never)]
fn visit_expr(e: &Expr, f: &mut impl FnMut(&Expr)) {
    f(e);
    match e {
        Expr::Paren(p) => visit_expr(&p.inner, f),
        Expr::Interp(i) => {
            for s in &i.segments {
                visit_expr(&s.expr, f);
            }
        }
        Expr::List(l) => {
            for e in &l.elems {
                match e {
                    ListElem::Expr(e) => visit_expr(e, f),
                    ListElem::Spread(s) => visit_expr(&s.expr, f),
                }
            }
        }
        Expr::Call(c) => {
            visit_expr(&c.callee, f);
            for a in &c.args {
                if let Some(e) = a.expr() {
                    visit_expr(e, f);
                }
            }
        }
        Expr::Record(r) => {
            if let Some(b) = &r.base {
                visit_expr(b, f);
            }
            for field in &r.fields {
                visit_expr(&field.value, f);
            }
        }
        Expr::Binary(b) => {
            visit_expr(&b.lhs, f);
            visit_expr(&b.rhs, f);
        }
        Expr::Unary(u) => visit_expr(&u.operand, f),
        Expr::Pipe(p) => {
            visit_expr(&p.lhs, f);
            visit_expr(&p.rhs, f);
        }
        Expr::Return(r) => visit_expr(&r.value, f),
        Expr::If(i) => visit_if(i, f),
        Expr::Match(m) => {
            visit_expr(&m.scrutinee, f);
            for arm in &m.arms {
                if let Some(g) = &arm.guard {
                    visit_expr(g, f);
                }
                visit_block(&arm.body, f);
            }
        }
        Expr::Lambda(l) => visit_block(&l.body, f),
        Expr::Try(t) => {
            visit_expr(&t.value, f);
            if let crate::syntax::ast::TryAction::Die {
                message: Some(message),
                ..
            } = &t.action
            {
                visit_expr(message, f);
            }
        }
        Expr::Block(e) => visit_block(&e.body, f),
        Expr::Lazy(l) => visit_block(&l.body, f),
        Expr::With(w) => {
            for b in &w.binds {
                visit_expr(&b.value, f);
            }
            visit_block(&w.body, f);
        }
        Expr::Handle(h) => {
            visit_block(&h.body, f);
            for c in &h.clauses {
                visit_block(&c.body, f);
            }
        }
        Expr::Resume(r) => visit_expr(&r.value, f),
        Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Error(_) => {}
    }
}
