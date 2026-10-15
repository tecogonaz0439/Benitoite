//! 公開 AST の宣言と参照位置を索引にする（設計書 02-03「AST」、02-04「束縛と表」）。
use benitoite::{
    base::{NodeId, Span},
    syntax::ast::*,
};
use serde_json::{Value, json};
use std::collections::BTreeMap;

fn position(s: Span) -> Value {
    json!({"file":s.file.0,"start":s.start.0,"end":s.end.0})
}
/// 関数型に明示された契約名を宣言順に返す。
pub(super) fn type_names(f: &FnType) -> Option<Vec<&str>> {
    Some(f.param_names.iter().map(|n| n.text.as_str()).collect())
}
fn function(
    id: NodeId,
    name: &str,
    params: &[Param],
    ret: &TypeExpr,
    public: bool,
    contracts: &mut BTreeMap<NodeId, Value>,
) {
    let inner: Vec<_> = params
        .iter()
        .map(|p| {
            let mut types = vec![];
            if let Some(t) = &p.ty {
                function_types(t, &mut types);
            }
            json!({"name":p.name.text,"id":p.id.0,"function_types":types})
        })
        .collect();
    contracts.insert(id, json!({"kind":"declaration","name":name,"names":params.iter().map(|p| &p.name.text).collect::<Vec<_>>(),"file":ret.span().file.0,"public":public,"inner":inner}));
    for p in params {
        if let Some(t) = &p.ty
            && let TypeExpr::Fn(f) = t
        {
            contracts.insert(p.id, json!({"kind":"annotation","name":name,"slot":p.name.text,"arity":f.params.len(),"names":type_names(f),"origin":position(f.span)}));
        }
    }
}
fn function_types(t: &TypeExpr, rows: &mut Vec<Value>) {
    match t {
        TypeExpr::Fn(f) => {
            rows.push(json!({"position":position(f.span),"arity":f.params.len(),"names":type_names(f),"params":f.params.iter().map(|t|position(t.span())).collect::<Vec<_>>()}));
            for t in &f.params {
                function_types(t, rows);
            }
            function_types(&f.ret, rows);
        }
        TypeExpr::Named(n) => {
            for t in &n.args {
                function_types(t, rows);
            }
        }
        TypeExpr::Paren(p) => function_types(&p.inner, rows),
        TypeExpr::Error(_) => {}
    }
}
/// モジュールの宣言と、名前を使う箇所の位置を索引へ追加する。
pub(super) fn module(
    m: &Module,
    contracts: &mut BTreeMap<NodeId, Value>,
    refs: &mut BTreeMap<NodeId, Span>,
) {
    for d in &m.decls {
        let public = d.public.is_some() || d.package.is_some();
        match &d.item {
            Item::Fn(f) => {
                function(f.id, &f.name.text, &f.params, &f.ret, public, contracts);
                if let Some(b) = &f.body {
                    block(b, contracts, refs);
                }
            }
            Item::Trait(t) => {
                for f in &t.methods {
                    function(
                        f.id,
                        &format!("{}.{}", t.name.text, f.name.text),
                        &f.params,
                        &f.ret,
                        public,
                        contracts,
                    );
                }
            }
            Item::Effect(t) => {
                for f in &t.ops {
                    function(
                        f.id,
                        &format!("{}.{}", t.name.text, f.name.text),
                        &f.params,
                        &f.ret,
                        public,
                        contracts,
                    );
                }
            }
            Item::Impl(i) => {
                for f in &i.fns {
                    function(
                        f.decl.id,
                        &f.decl.name.text,
                        &f.decl.params,
                        &f.decl.ret,
                        public,
                        contracts,
                    );
                    if let Some(b) = &f.decl.body {
                        block(b, contracts, refs);
                    }
                }
            }
            Item::Const(c) => expr(&c.value, contracts, refs),
            Item::Data(_)
            | Item::Record(_)
            | Item::Alias(_)
            | Item::ExternalType(_)
            | Item::Error(_) => {}
        }
    }
}
fn block(b: &Block, contracts: &mut BTreeMap<NodeId, Value>, refs: &mut BTreeMap<NodeId, Span>) {
    for s in &b.stmts {
        match s {
            Stmt::Bind(b) => expr(&b.value, contracts, refs),
            Stmt::Expr(e) => expr(e, contracts, refs),
            Stmt::Error(_) => {}
        }
    }
}
fn if_expr(i: &IfExpr, contracts: &mut BTreeMap<NodeId, Value>, refs: &mut BTreeMap<NodeId, Span>) {
    expr(&i.cond, contracts, refs);
    block(&i.then_block, contracts, refs);
    match &i.else_branch {
        Some(ElseBranch::Block(b)) => block(b, contracts, refs),
        Some(ElseBranch::If(i)) => if_expr(i, contracts, refs),
        None => {}
    }
}
fn expr(e: &Expr, contracts: &mut BTreeMap<NodeId, Value>, refs: &mut BTreeMap<NodeId, Span>) {
    match e {
        Expr::Name(n) => {
            if let Some(name) = n.path.last() {
                refs.insert(n.id, name.span);
            }
        }
        Expr::Interp(i) => {
            for s in &i.segments {
                expr(&s.expr, contracts, refs);
            }
        }
        Expr::Paren(p) => expr(&p.inner, contracts, refs),
        Expr::List(l) => {
            for e in &l.elems {
                match e {
                    ListElem::Expr(e) => expr(e, contracts, refs),
                    ListElem::Spread(s) => expr(&s.expr, contracts, refs),
                }
            }
        }
        Expr::Call(c) => {
            expr(&c.callee, contracts, refs);
            for a in &c.args {
                if let Some(e) = match a {
                    Arg::Expr(e) => Some(e),
                    Arg::Named(a) => match &a.value {
                        benitoite::syntax::ast::ArgValue::Expr(e) => Some(e),
                        benitoite::syntax::ast::ArgValue::Placeholder(_) => None,
                    },
                    Arg::Placeholder(_) => None,
                } {
                    expr(e, contracts, refs);
                }
            }
        }
        Expr::Record(r) => {
            if let Some(b) = &r.base {
                expr(b, contracts, refs);
            }
            for f in &r.fields {
                expr(&f.value, contracts, refs);
            }
        }
        Expr::Binary(b) => {
            expr(&b.lhs, contracts, refs);
            expr(&b.rhs, contracts, refs);
        }
        Expr::Unary(u) => expr(&u.operand, contracts, refs),
        Expr::Pipe(p) => {
            expr(&p.lhs, contracts, refs);
            expr(&p.rhs, contracts, refs);
        }
        Expr::If(i) => if_expr(i, contracts, refs),
        Expr::Match(m) => {
            expr(&m.scrutinee, contracts, refs);
            for a in &m.arms {
                if let Some(g) = &a.guard {
                    expr(g, contracts, refs);
                }
                block(&a.body, contracts, refs);
            }
        }
        Expr::Lambda(l) => {
            for p in &l.params {
                if let Some(TypeExpr::Fn(f)) = &p.ty {
                    contracts.insert(p.id, json!({"kind":"annotation","name":"lambda","slot":p.name.text,"arity":f.params.len(),"names":type_names(f),"origin":position(f.span)}));
                }
            }
            block(&l.body, contracts, refs);
        }
        Expr::Return(r) => expr(&r.value, contracts, refs),
        Expr::Try(t) => expr(&t.value, contracts, refs),
        Expr::Lazy(l) => block(&l.body, contracts, refs),
        Expr::With(w) => {
            for b in &w.binds {
                expr(&b.value, contracts, refs);
            }
            block(&w.body, contracts, refs);
        }
        Expr::Handle(h) => {
            block(&h.body, contracts, refs);
            for c in &h.clauses {
                block(&c.body, contracts, refs);
            }
        }
        Expr::Resume(r) => expr(&r.value, contracts, refs),
        Expr::Lit(_) | Expr::Unit(_) | Expr::Error(_) => {}
    }
}
