//! 宣言・文を一つずつ取り除く反例の縮小（設計書 07-03「差分テスト」、実装プラン C14）。

use benitoite::base::{FileId, IdGen, SourceKind, Span};
use benitoite::syntax::ast::{Arg, Block, ElseBranch, Expr, Item, ListElem, Stmt};
use benitoite::syntax::{lexer, newline, parser};

/// 同じ失敗が残る削除だけを採用し、削除できなくなるまで繰り返す。
/// 失敗の種類と、型の付くことを保つ条件は呼び出し側が判定する。
pub fn minimize(source: &str, mut still_fails: impl FnMut(&str) -> bool) -> String {
    let mut source = source.to_string();
    loop {
        let mut changed = false;
        for span in removable_spans(&source) {
            let start = usize::try_from(span.start.0).unwrap();
            let end = usize::try_from(span.end.0).unwrap();
            let mut candidate = source.clone();
            candidate.replace_range(start..end, "");
            if candidate.len() < source.len() && still_fails(&candidate) {
                source = candidate;
                changed = true;
                break;
            }
        }
        if !changed {
            return source;
        }
    }
}
fn removable_spans(source: &str) -> Vec<Span> {
    let file = FileId(0);
    let lexed = lexer::lex(file, source.as_bytes());
    let parsed = parser::parse(
        file,
        SourceKind::User,
        source.as_bytes(),
        newline::resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut IdGen::default(),
    );
    let mut spans = Vec::new();
    for declaration in &parsed.module.decls {
        match &declaration.item {
            Item::Fn(function) => {
                if function.name.text != "main" {
                    spans.push(declaration.span);
                }
                // 燃料の基底の分岐を落とすと停止しなくなるので、再帰関数は宣言ごとにだけ落とす。
                if function.name.text != "recur"
                    && function.name.text != "unwind"
                    && let Some(body) = &function.body
                {
                    block(body, &mut spans);
                }
            }
            Item::Impl(implementation) => {
                spans.push(declaration.span);
                for method in &implementation.fns {
                    if let Some(body) = &method.decl.body {
                        block(body, &mut spans);
                    }
                }
            }
            Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Error(_) => spans.push(declaration.span),
        }
    }
    // 大きな宣言や文を先に落とす。UTF-8 の境界は構文解析器が返した位置を使う。
    spans.sort_by_key(|s| std::cmp::Reverse(s.end.0 - s.start.0));
    spans.dedup();
    spans
}
fn block(body: &Block, spans: &mut Vec<Span>) {
    for statement in &body.stmts {
        match statement {
            Stmt::Bind(bind) => {
                spans.push(bind.span);
                expression(&bind.value, spans);
            }
            Stmt::Expr(expr) => {
                spans.push(expr.span());
                expression(expr, spans);
            }
            Stmt::Error(error) => spans.push(error.span),
        }
    }
}
fn branch(branch: &ElseBranch, spans: &mut Vec<Span>) {
    match branch {
        ElseBranch::Block(body) => block(body, spans),
        ElseBranch::If(expr) => {
            expression(&expr.cond, spans);
            block(&expr.then_block, spans);
            if let Some(other) = &expr.else_branch {
                self::branch(other, spans);
            }
        }
    }
}
fn expression(expr: &Expr, spans: &mut Vec<Span>) {
    match expr {
        Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Error(_) => {}
        Expr::Interp(expr) => {
            for segment in &expr.segments {
                expression(&segment.expr, spans);
            }
        }
        Expr::Paren(expr) => expression(&expr.inner, spans),
        Expr::List(expr) => {
            for elem in &expr.elems {
                match elem {
                    ListElem::Expr(expr) => expression(expr, spans),
                    ListElem::Spread(elem) => expression(&elem.expr, spans),
                }
            }
        }
        Expr::Call(expr) => {
            expression(&expr.callee, spans);
            for arg in &expr.args {
                match arg {
                    Arg::Expr(expr) => expression(expr, spans),
                    Arg::Placeholder(_) => {}
                }
            }
        }
        Expr::Record(expr) => {
            if let Some(base) = &expr.base {
                expression(base, spans);
            }
            for field in &expr.fields {
                expression(&field.value, spans);
            }
        }
        Expr::Binary(expr) => {
            expression(&expr.lhs, spans);
            expression(&expr.rhs, spans);
        }
        Expr::Unary(expr) => expression(&expr.operand, spans),
        Expr::Pipe(expr) => {
            expression(&expr.lhs, spans);
            expression(&expr.rhs, spans);
        }
        Expr::If(expr) => {
            expression(&expr.cond, spans);
            block(&expr.then_block, spans);
            if let Some(other) = &expr.else_branch {
                branch(other, spans);
            }
        }
        Expr::Match(expr) => {
            expression(&expr.scrutinee, spans);
            for arm in &expr.arms {
                if let Some(guard) = &arm.guard {
                    expression(guard, spans);
                }
                block(&arm.body, spans);
            }
        }
        Expr::Lambda(expr) => block(&expr.body, spans),
        Expr::Return(expr) => expression(&expr.value, spans),
        Expr::Try(expr) => expression(&expr.value, spans),
        Expr::Lazy(expr) => block(&expr.body, spans),
        Expr::With(expr) => {
            for bind in &expr.binds {
                expression(&bind.value, spans);
            }
            block(&expr.body, spans);
        }
        Expr::Handle(expr) => {
            block(&expr.body, spans);
            for clause in &expr.clauses {
                block(&clause.body, spans);
            }
        }
        Expr::Resume(expr) => expression(&expr.value, spans),
    }
}
