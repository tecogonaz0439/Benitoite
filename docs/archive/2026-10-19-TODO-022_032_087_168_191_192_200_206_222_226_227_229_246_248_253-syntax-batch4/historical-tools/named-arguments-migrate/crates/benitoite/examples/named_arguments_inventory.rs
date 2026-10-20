//! 移行候補を公開の解析・名前解決・型検査の境界から抽出する。
//! ソース位置と束縛の参照は設計書 02-03「AST」、02-04「束縛と表」に従う。
use benitoite::{
    base::*,
    pipeline::{self, CheckedProgram},
    syntax::{ast::*, lexer, newline, parser},
    types::Ty,
};
#[path = "named_inventory/index.rs"]
mod index;
use serde_json::{Value, json};
use std::{
    collections::{BTreeMap, BTreeSet},
    io::{self, Read},
    path::Path,
};
fn contains_fn(t: &Ty) -> bool {
    match t {
        Ty::Fn(_) => true,
        Ty::Con(_, ts) | Ty::App(_, ts) => ts.iter().any(contains_fn),
        Ty::Param(_) | Ty::Rigid { .. } => false,
    }
}
struct Scan<'a> {
    source: &'a Source,
    checked: Option<&'a CheckedProgram>,
    rows: Vec<Value>,
    decls: Vec<Value>,
    locals: BTreeMap<NodeId, &'a Expr>,
    params: BTreeMap<NodeId, Vec<String>>,
    flows: Vec<Value>,
    calls: Vec<Value>,
    lambdas: Vec<Value>,
    annotations: Vec<Value>,
    contracts: BTreeMap<NodeId, Value>,
    name_spans: BTreeMap<NodeId, Span>,
}
impl<'a> Scan<'a> {
    fn pos(&self, s: Span) -> Value {
        let lc = self.source.line_col(s.start);
        json!({"file":s.file.0,"line":lc.line,"column":lc.column,"start":s.start.0,"end":s.end.0})
    }
    fn text(&self, s: Span) -> String {
        String::from_utf8_lossy(
            self.source
                .text()
                .get(s.start.0 as usize..s.end.0 as usize)
                .unwrap_or_default(),
        )
        .into_owned()
    }
    fn ty(&self, e: &Expr) -> Option<&Ty> {
        self.checked?.types.expr_types.get(e.id())
    }
    fn names(&self, e: &Expr, seen: &mut BTreeSet<NodeId>) -> Vec<Value> {
        let mut path = seen.clone();
        if !path.insert(e.id()) {
            return vec![json!({"kind":"unresolved_cycle"})];
        }
        match e {
            Expr::Lambda(l) => vec![
                json!({"names":l.params.iter().map(|p|&p.name.text).collect::<Vec<_>>(),"origin":self.pos(l.span),"kind":"lambda"}),
            ],
            Expr::Name(n) => {
                let Some(p) = self.checked else { return vec![] };
                let Some(b) = p
                    .resolved
                    .refs
                    .get(n.id)
                    .and_then(|id| p.resolved.bindings.get(*id))
                else {
                    return vec![];
                };
                if let benitoite::resolve::DeclSite::Node(id) = b.decl {
                    if let Some(v) = self.locals.get(&id) {
                        return self.names(v, &mut path);
                    }
                    if let Some(contract) = self.contracts.get(&id) {
                        return vec![contract.clone()];
                    }
                }
                vec![
                    json!({"kind":"resolved_binding","name":b.name,"binding_kind":format!("{:?}",b.kind),"module":p.modules.modules.get(b.module.0 as usize).map(|m|m.name.dotted()),"span":format!("{:?}",b.span),"needs_contract_table":true}),
                ]
            }
            Expr::Block(b) => self.block_names(&b.body, &mut path),
            Expr::Paren(p) => self.names(&p.inner, &mut path),
            Expr::If(i) => {
                let mut ns = self.block_names(&i.then_block, &mut path);
                if let Some(b) = &i.else_branch {
                    match b {
                        ElseBranch::Block(b) => ns.extend(self.block_names(b, &mut path)),
                        ElseBranch::If(i) => {
                            ns.extend(self.names(&Expr::If((**i).clone()), &mut path))
                        }
                    }
                };
                ns
            }
            Expr::Match(m) => m
                .arms
                .iter()
                .flat_map(|a| self.block_names(&a.body, &mut path))
                .collect(),
            Expr::List(l) => l
                .elems
                .iter()
                .flat_map(|v| match v {
                    ListElem::Expr(e) => self.names(e, &mut path),
                    ListElem::Spread(s) => self.names(&s.expr, &mut path),
                })
                .collect(),
            Expr::Record(r) => r
                .fields
                .iter()
                .flat_map(|f| self.names(&f.value, &mut path))
                .collect(),
            Expr::Lit(_)
            | Expr::Interp(_)
            | Expr::Unit(_)
            | Expr::Call(_)
            | Expr::Binary(_)
            | Expr::Unary(_)
            | Expr::Pipe(_)
            | Expr::Return(_)
            | Expr::Try(_)
            | Expr::Lazy(_)
            | Expr::With(_)
            | Expr::Handle(_)
            | Expr::Resume(_)
            | Expr::Error(_) => vec![],
        }
    }
    fn block_names(&self, b: &Block, seen: &mut BTreeSet<NodeId>) -> Vec<Value> {
        match b.stmts.last() {
            Some(Stmt::Expr(e)) => self.names(e, seen),
            _ => vec![],
        }
    }
    fn row(&mut self, kind: &str, e: &Expr, values: Vec<&Expr>, owner: &str) {
        let typed = (kind != "return" && self.ty(e).is_some_and(contains_fn))
            || values.iter().any(|v| self.ty(v).is_some_and(contains_fn));
        if !typed {
            return;
        }
        let mut ns = Vec::new();
        for v in &values {
            ns.extend(self.names(v, &mut BTreeSet::new()))
        }
        if kind == "if" {
            ns = self.names(e, &mut BTreeSet::new());
        }
        ns.sort_by_key(|n| {
            n.get("origin")
                .and_then(|p| p.get("start"))
                .and_then(Value::as_u64)
                .unwrap_or(u64::MAX)
        });
        ns.dedup();
        self.rows.push(json!({"kind":kind,"position":self.pos(e.span()),"owner":owner,"type":format!("{:?}",self.ty(e)),"value_types":values.iter().map(|v|format!("{:?}",self.ty(v))).collect::<Vec<_>>(),"contract_sources":ns,"sample":self.text(e.span())}));
    }
    fn types(&self, t: &TypeExpr, slot: &str, out: &mut Vec<Value>) {
        match t {
            TypeExpr::Fn(f) => {
                out.push(json!({"slot":slot,"arity":f.params.len(),"position":self.pos(f.span),"type":self.text(f.span),"names":index::type_names(f),"params":f.params.iter().map(|t| self.pos(t.span())).collect::<Vec<_>>()}));
                for (i, t) in f.params.iter().enumerate() {
                    self.types(t, &format!("{slot}.param{}", i.saturating_add(1)), out)
                }
                self.types(&f.ret, &format!("{slot}.return"), out)
            }
            TypeExpr::Named(n) => {
                for (i, t) in n.args.iter().enumerate() {
                    self.types(t, &format!("{slot}.type_arg{}", i.saturating_add(1)), out)
                }
            }
            TypeExpr::Paren(p) => self.types(&p.inner, slot, out),
            _ => {}
        }
    }
    fn decl(&mut self, id: NodeId, name: &str, params: &[Param], ret: &TypeExpr, kind: &str) {
        let mut inner = vec![];
        for p in params {
            if let Some(t) = &p.ty {
                self.types(t, &p.name.text, &mut inner)
            }
        }
        self.types(ret, "return", &mut inner);
        self.params
            .insert(id, params.iter().map(|p| p.name.text.clone()).collect());
        for p in params {
            if let Some(t) = &p.ty {
                self.annotation(t, name);
            }
        }
        self.annotation(ret, name);
        self.decls.push(json!({"name":name,"kind":kind,"params":params.iter().map(|p|&p.name.text).collect::<Vec<_>>(),"position":self.pos(ret.span()),"inner_function_types":inner,"public":self.contracts.get(&id).and_then(|c|c.get("public")).and_then(Value::as_bool).unwrap_or(false)}));
    }
    fn collect_locals(&mut self, b: &'a Block) {
        for s in &b.stmts {
            if let Stmt::Bind(v) = s
                && let Pattern::Var(p) = &v.pattern
            {
                self.locals.insert(p.id, &v.value);
            }
        }
    }
    fn block(&mut self, b: &'a Block, owner: &str) {
        self.collect_locals(b);
        for s in &b.stmts {
            match s {
                Stmt::Bind(v) => {
                    if let Some(t) = &v.ty {
                        self.annotation(t, owner);
                        let mut types = vec![];
                        self.types(t, owner, &mut types);
                        self.flows.push(json!({"types":types,"sources":self.names(&v.value, &mut BTreeSet::new())}));
                    }
                    self.expr(&v.value, owner);
                }
                Stmt::Expr(e) => self.expr(e, owner),
                _ => {}
            }
        }
    }
    fn expr(&mut self, e: &'a Expr, owner: &str) {
        match e {
            Expr::If(i) => self.if_walk(i, owner),
            Expr::Match(m) => {
                let vs = m
                    .arms
                    .iter()
                    .filter_map(|a| match a.body.stmts.last() {
                        Some(Stmt::Expr(v)) => Some(v),
                        _ => None,
                    })
                    .collect();
                self.row("match", e, vs, owner);
                self.expr(&m.scrutinee, owner);
                for a in &m.arms {
                    if let Some(g) = &a.guard {
                        self.expr(g, owner)
                    }
                    self.block(&a.body, owner)
                }
            }
            Expr::List(l) => {
                let vs = l
                    .elems
                    .iter()
                    .map(|v| match v {
                        ListElem::Expr(e) => e,
                        ListElem::Spread(s) => &s.expr,
                    })
                    .collect();
                self.row("list", e, vs, owner);
                for v in &l.elems {
                    match v {
                        ListElem::Expr(e) => self.expr(e, owner),
                        ListElem::Spread(s) => self.expr(&s.expr, owner),
                    }
                }
            }
            Expr::Record(r) => {
                for f in &r.fields {
                    self.row("record_field", &f.value, vec![&f.value], owner);
                    self.expr(&f.value, owner)
                }
                if let Some(b) = &r.base {
                    self.expr(b, owner)
                }
            }
            Expr::Return(r) => {
                self.row("return", e, vec![&r.value], owner);
                self.expr(&r.value, owner)
            }
            Expr::Call(c) => {
                self.call(c, false);
                if let Expr::Name(n) = c.callee.as_ref()
                    && let Some(p) = self.checked
                    && let Some(b) = p
                        .resolved
                        .refs
                        .get(n.id)
                        .and_then(|id| p.resolved.bindings.get(*id))
                    && b.name == "set"
                    && p.modules
                        .modules
                        .get(b.module.0 as usize)
                        .is_some_and(|m| m.name.dotted() == "Benitoite.Reference")
                {
                    self.row(
                        "reference_set",
                        e,
                        c.args
                            .iter()
                            .filter_map(|a| match a {
                                Arg::Expr(v) => Some(v),
                                Arg::Named(a) => match &a.value {
                                    benitoite::syntax::ast::ArgValue::Expr(e) => Some(e),
                                    benitoite::syntax::ast::ArgValue::Placeholder(_) => None,
                                },
                                Arg::Placeholder(_) => None,
                            })
                            .collect(),
                        owner,
                    )
                }
                self.expr(&c.callee, owner);
                for a in &c.args {
                    if let Some(v) = match a {
                        Arg::Expr(e) => Some(e),
                        Arg::Named(a) => match &a.value {
                            benitoite::syntax::ast::ArgValue::Expr(e) => Some(e),
                            benitoite::syntax::ast::ArgValue::Placeholder(_) => None,
                        },
                        Arg::Placeholder(_) => None,
                    } {
                        self.expr(v, owner)
                    }
                }
            }
            Expr::Lambda(l) => {
                self.lambda(l);
                self.block(
                    &l.body,
                    &format!("{owner}/lambda@{}", self.source.line_col(l.span.start).line),
                );
            }
            Expr::Paren(p) => self.expr(&p.inner, owner),
            Expr::Binary(b) => {
                self.expr(&b.lhs, owner);
                self.expr(&b.rhs, owner)
            }
            Expr::Pipe(p) => {
                self.expr(&p.lhs, owner);
                if let Expr::Call(c) = p.rhs.as_ref() {
                    self.call(c, true);
                }
                self.expr(&p.rhs, owner)
            }
            Expr::Unary(u) => self.expr(&u.operand, owner),
            Expr::Try(t) => {
                self.expr(&t.value, owner);
                if let benitoite::syntax::ast::TryAction::Die {
                    message: Some(message),
                    ..
                } = &t.action
                {
                    self.expr(message, owner);
                }
            }
            Expr::Resume(r) => self.expr(&r.value, owner),
            Expr::Block(b) => self.block(&b.body, owner),
            Expr::Lazy(l) => self.block(&l.body, owner),
            Expr::With(w) => {
                for b in &w.binds {
                    self.expr(&b.value, owner)
                }
                self.block(&w.body, owner)
            }
            Expr::Handle(h) => {
                self.block(&h.body, owner);
                for c in &h.clauses {
                    self.block(&c.body, owner)
                }
            }
            Expr::Interp(i) => {
                for s in &i.segments {
                    self.expr(&s.expr, owner)
                }
            }
            Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Error(_) => {}
        }
    }
    fn if_walk(&mut self, i: &'a IfExpr, owner: &str) {
        let mut vs = vec![];
        if let Some(Stmt::Expr(v)) = i.then_block.stmts.last() {
            vs.push(v)
        }
        if let Some(ElseBranch::Block(b)) = &i.else_branch
            && let Some(Stmt::Expr(v)) = b.stmts.last()
        {
            vs.push(v)
        }
        let e = Expr::If(i.clone());
        self.row("if", &e, vs, owner);
        self.expr(&i.cond, owner);
        self.block(&i.then_block, owner);
        if let Some(b) = &i.else_branch {
            match b {
                ElseBranch::Block(b) => self.block(b, owner),
                ElseBranch::If(i) => self.if_walk(i, owner),
            }
        }
    }
    fn annotation(&mut self, t: &TypeExpr, owner: &str) {
        let mut rows = vec![];
        self.types(t, owner, &mut rows);
        self.annotations.extend(rows);
    }
    fn lambda(&mut self, l: &LambdaExpr) {
        let mut params = vec![];
        let mut collisions = BTreeSet::new();
        if let Some(p) = self.checked {
            // 参照されない外側の局所名も隠せないため、囲む関数の先行する束縛を
            // 保守的に保留へ含める（設計書 01-03「シャドーイング」）。
            let enclosing = p.asts.iter().flat_map(|m| &m.decls).find_map(|d| {
                let functions: Vec<_> = match &d.item {
                    Item::Fn(f) => vec![f.as_ref()],
                    Item::Impl(i) => i.fns.iter().map(|f| &f.decl).collect(),
                    Item::Const(_)
                    | Item::Data(_)
                    | Item::Record(_)
                    | Item::Alias(_)
                    | Item::Trait(_)
                    | Item::Effect(_)
                    | Item::ExternalType(_)
                    | Item::Error(_) => vec![],
                };
                functions.into_iter().find_map(|f| {
                    (f.span.file == l.span.file
                        && f.span.start <= l.span.start
                        && f.span.end >= l.span.end)
                        .then_some(f.span)
                })
            });
            for (_, b) in p.resolved.bindings.iter() {
                if b.span.is_some_and(|s| {
                    s.file == l.span.file
                        && ((s.start >= l.span.start && s.end <= l.span.end)
                            || enclosing.is_some_and(|f| {
                                s.start >= f.start
                                    && s.end <= l.span.start
                                    && !self.lambdas.iter().any(|previous| {
                                        let position = &previous["position"];
                                        let start = position["start"].as_u64();
                                        let end = position["end"].as_u64();
                                        start.is_some_and(|start| start <= u64::from(s.start.0))
                                            && end.is_some_and(|end| {
                                                end >= u64::from(s.end.0)
                                                    && end <= u64::from(l.span.start.0)
                                            })
                                    })
                            }))
                }) {
                    collisions.insert(b.name.clone());
                }
            }
            for (node, binding) in p.resolved.refs.iter() {
                if self.name_spans.get(&node).is_some_and(|s| {
                    s.file == l.span.file && s.start >= l.span.start && s.end <= l.span.end
                }) && let Some(b) = p.resolved.bindings.get(*binding)
                {
                    collisions.insert(b.name.clone());
                }
            }
        }
        for param in &l.params {
            let binding = self.checked.and_then(|p| p.resolved.decls.get(param.id));
            let mut uses = vec![];
            if let (Some(p), Some(binding)) = (self.checked, binding) {
                for (node, b) in p.resolved.refs.iter() {
                    if b == binding
                        && let Some(span) = self.name_spans.get(&node)
                    {
                        uses.push(self.pos(*span));
                    }
                }
            }
            params.push(json!({"name":param.name.text,"position":self.pos(param.name.span),"references":uses}));
            if let Some(t) = &param.ty {
                self.annotation(t, "lambda.parameter");
            }
        }
        if let Some(t) = &l.ret {
            self.annotation(t, "lambda.return");
        }
        self.lambdas
            .push(json!({"position":self.pos(l.span),"params":params,"bound_names":collisions}));
    }
    fn call(&mut self, c: &CallExpr, pipe: bool) {
        let sources = self.names(&c.callee, &mut BTreeSet::new());
        let contract = self.ty(&c.callee).and_then(|t| match t {
            Ty::Fn(f) => Some(json!({"names":f.param_names,"origin":"Named"})),
            Ty::Param(_) | Ty::Con(_, _) | Ty::App(_, _) | Ty::Rigid { .. } => None,
        });
        let binding = match c.callee.as_ref() {
            Expr::Name(n) => self.checked.and_then(|p| p.resolved.binding_of_ref(n.id)),
            Expr::Lit(_)
            | Expr::Interp(_)
            | Expr::Unit(_)
            | Expr::Paren(_)
            | Expr::List(_)
            | Expr::Call(_)
            | Expr::Record(_)
            | Expr::Binary(_)
            | Expr::Unary(_)
            | Expr::Pipe(_)
            | Expr::If(_)
            | Expr::Match(_)
            | Expr::Lambda(_)
            | Expr::Return(_)
            | Expr::Try(_)
            | Expr::Block(_)
            | Expr::Lazy(_)
            | Expr::With(_)
            | Expr::Handle(_)
            | Expr::Resume(_)
            | Expr::Error(_) => None,
        };
        let constructor =
            binding.is_some_and(|b| matches!(b.kind, benitoite::resolve::BindingKind::Ctor { .. }));
        let args: Vec<_> = c.args.iter().map(|a| match a {
            Arg::Expr(e) => json!({"position":self.pos(e.span()),"sources":self.names(e, &mut BTreeSet::new()),"type":format!("{:?}",self.ty(e)),"hole":false}),
            Arg::Placeholder(p) => json!({"position":self.pos(p.span),"sources":[],"hole":true}),
            Arg::Named(a) => match &a.value {
                benitoite::syntax::ast::ArgValue::Expr(e) => json!({"position":self.pos(e.span()),"label":a.name.text,"sources":self.names(e, &mut BTreeSet::new()),"type":format!("{:?}",self.ty(e)),"hole":false}),
                benitoite::syntax::ast::ArgValue::Placeholder(p) => json!({"position":self.pos(p.span),"label":a.name.text,"sources":[],"hole":true}),
            },
        }).collect();
        self.calls.push(json!({"position":self.pos(c.span),"callee":self.text(c.callee.span()),"contract_sources":sources,"static_contract":contract,"args":args,"pipe":pipe,"constructor":constructor}));
    }
    fn module(&mut self, m: &'a Module) {
        for d in &m.decls {
            match &d.item {
                Item::Fn(f) => self.decl(f.id, &f.name.text, &f.params, &f.ret, "function"),
                Item::Trait(t) => {
                    for f in &t.methods {
                        self.decl(
                            f.id,
                            &format!("{}.{}", t.name.text, f.name.text),
                            &f.params,
                            &f.ret,
                            "method",
                        )
                    }
                }
                Item::Impl(i) => {
                    for f in &i.fns {
                        self.decl(
                            f.decl.id,
                            &format!("implement.{}", f.decl.name.text),
                            &f.decl.params,
                            &f.decl.ret,
                            "implementation",
                        )
                    }
                }
                Item::Effect(t) => {
                    for f in &t.ops {
                        self.decl(
                            f.id,
                            &format!("{}.{}", t.name.text, f.name.text),
                            &f.params,
                            &f.ret,
                            "operation",
                        )
                    }
                }
                Item::Const(c) => self.annotation(&c.ty, &c.name.text),
                Item::Data(d) => {
                    for v in &d.variants {
                        for t in &v.fields {
                            self.annotation(t, &v.name.text);
                        }
                    }
                }
                Item::Alias(a) => self.annotation(&a.ty, &a.name.text),
                Item::Record(r) => {
                    for f in &r.fields {
                        self.annotation(&f.ty, &f.name.text);
                    }
                }
                Item::ExternalType(_) | Item::Error(_) => {}
            }
        }
        for d in &m.decls {
            match &d.item {
                Item::Fn(f) => {
                    if let Some(b) = &f.body {
                        self.block(b, &f.name.text)
                    }
                }
                Item::Impl(i) => {
                    for f in &i.fns {
                        if let Some(b) = &f.decl.body {
                            self.block(b, &format!("implement.{}", f.decl.name.text))
                        }
                    }
                }
                Item::Const(c) => self.expr(&c.value, &c.name.text),
                Item::Data(_)
                | Item::Alias(_)
                | Item::ExternalType(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Error(_) => {}
            }
        }
    }
}
struct OneFile {
    path: std::path::PathBuf,
    text: Vec<u8>,
}
impl benitoite::modules::ModuleFs for OneFile {
    fn read_file(&self, p: &Path) -> io::Result<Vec<u8>> {
        if p == self.path {
            Ok(self.text.clone())
        } else {
            Err(io::ErrorKind::NotFound.into())
        }
    }
    fn list_dir(&self, _: &Path) -> io::Result<Vec<benitoite::modules::DirEntryName>> {
        Ok(vec![])
    }
    fn canonicalize(&self, p: &Path) -> io::Result<std::path::PathBuf> {
        Ok(p.into())
    }
}
fn inventory(r: &Value) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
    let path = r.get("path").and_then(Value::as_str).ok_or("path")?;
    let text = r.get("source").and_then(Value::as_str).ok_or("source")?;
    let stdlib = path.starts_with("crates/benitoite/src/prelude/stdlib/");
    let kind = if stdlib {
        SourceKind::Prelude
    } else {
        SourceKind::User
    };
    let source = Source::new(path.into(), kind, text.as_bytes().to_vec());
    let lx = lexer::lex(FileId(0), text.as_bytes());
    let parsed = parser::parse(
        FileId(0),
        kind,
        text.as_bytes(),
        newline::resolve_newlines(lx.tokens),
        lx.comments,
        &mut IdGen::new(),
    );
    let parse_errors = lx
        .diagnostics
        .iter()
        .chain(&parsed.diagnostics)
        .filter(|d| d.is_error())
        .count();
    let direct = r.get("direct").and_then(Value::as_bool).unwrap_or(false);
    let virtual_fs = OneFile {
        path: Path::new("/inventory/main.bnt").into(),
        text: if stdlib {
            let module_path = path
                .trim_start_matches("crates/benitoite/src/prelude/stdlib/")
                .trim_end_matches(".bnt");
            let module = benitoite::prelude::STDLIB
                .iter()
                .find(|m| m.path.join("/") == module_path)
                .ok_or("unknown standard library module")?;
            let namespace = if module.unofficial {
                "Benitoite.Unofficial"
            } else {
                "Benitoite"
            };
            format!(
                "import {namespace}.{}\nfunction main() -> Unit\nend function\n",
                module.path.join(".")
            )
            .into_bytes()
        } else {
            text.as_bytes().to_vec()
        },
    };
    let entry = if direct && !stdlib {
        pipeline::entry_spec(Path::new(path)).map_err(|e| format!("{e:?}"))?
    } else {
        benitoite::modules::EntrySpec {
            path: virtual_fs.path.clone(),
            root: Path::new("/inventory").into(),
            display_name: path.into(),
        }
    };
    let fs: &dyn benitoite::modules::ModuleFs = if direct && !stdlib {
        &benitoite::modules::RealFs
    } else {
        &virtual_fs
    };
    let mut ids = IdGen::new();
    let loaded = benitoite::modules::load_program(&entry, benitoite::prelude::STDLIB, fs, &mut ids);
    let mut diagnostics = loaded.diagnostics;
    let resolved =
        benitoite::resolve::resolve(&loaded.modules, &loaded.asts, &loaded.sources, &mut ids);
    diagnostics.extend(resolved.diagnostics.clone());
    let can_type = !diagnostics.iter().any(|d| d.is_error());
    let (types, type_diags) = if can_type {
        benitoite::typeck::typecheck(
            &loaded.modules,
            &loaded.asts,
            &loaded.sources,
            &resolved,
            false,
        )
    } else {
        (benitoite::typeck::TypeckOutput::default(), vec![])
    };
    diagnostics.extend(type_diags);
    let typed = can_type && !diagnostics.iter().any(|d| d.is_error());
    let checked = CheckedProgram {
        modules: loaded.modules,
        asts: loaded.asts,
        comments: loaded.comments,
        resolved,
        types,
    };
    let mut contracts = BTreeMap::new();
    let mut name_spans = BTreeMap::new();
    for m in &checked.asts {
        index::module(m, &mut contracts, &mut name_spans);
    }
    // Imported declarations keep their own file and module; they cannot become edits in this source.
    for c in contracts.values_mut() {
        if let Some(file) = c
            .get("file")
            .or_else(|| c.get("origin").and_then(|o| o.get("file")))
            .and_then(Value::as_u64)
            .and_then(|n| u32::try_from(n).ok())
            && let Some(s) = loaded.sources.get(FileId(file))
        {
            c["source_path"] = json!(s.name());
        }
    }
    let selected = checked.asts.iter().find(|m| {
        loaded.sources.get(m.file).is_some_and(|s| {
            if stdlib {
                s.name().strip_prefix("<benitoite>/").is_some_and(|name| {
                    path.strip_prefix("crates/benitoite/src/prelude/stdlib/") == Some(name)
                })
            } else {
                s.name() == path
            }
        })
    });
    let m = selected.unwrap_or(&parsed.module);
    let mut scan = Scan {
        source: &source,
        checked: can_type.then_some(&checked),
        rows: vec![],
        decls: vec![],
        locals: BTreeMap::new(),
        params: BTreeMap::new(),
        flows: vec![],
        calls: vec![],
        lambdas: vec![],
        annotations: vec![],
        contracts,
        name_spans,
    };
    scan.module(m);
    let codes: Vec<_> = diagnostics.iter().map(|d| json!({"code":d.code.map(|c|format!("{c:?}")),"error":d.is_error(),"message":d.message})).collect();
    Ok(
        json!({"path":path,"snippet":r.get("snippet"),"parse_errors":parse_errors,"typed":typed,"recovered_error_types":can_type && !typed,"check_codes":codes,"declarations":scan.decls,"joins":scan.rows,"flows":scan.flows,"calls":scan.calls,"lambdas":scan.lambdas,"annotations":scan.annotations,"file":m.file.0}),
    )
}
fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    let inputs: Vec<Value> = serde_json::from_str(&input)?;
    for r in inputs {
        println!("{}", inventory(&r)?);
    }
    Ok(())
}
fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    std::thread::Builder::new()
        .stack_size(benitoite::pipeline::STAGE_STACK_BYTES)
        .spawn(run)?
        .join()
        .map_err(|_| "inventory thread failed")?
}
