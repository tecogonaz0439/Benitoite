//! 宣言の型と本体を辿って名前を解決する（設計書 02-04「解決の手順」の手順 3・4）。
//! AST を辿る再帰の深さは、構文解析器が抑える AST の深さの定数倍に収まる（00-02「再帰の深さ」）。

use std::collections::BTreeMap;

use super::BindingKind;
use super::collect::{Resolver, Src};
use super::lookup::{Ctx, Qualified};
use super::text;
use crate::base::Span;
use crate::diag::DiagCode;
use crate::syntax::ast::{
    Arg, Block, ElseBranch, Expr, FnDecl, IfExpr, Item, LambdaExpr, LetName, NameExpr, Param,
    Pattern, Program, Stmt, TypeDecl, TypeExpr, TypeParam,
};

impl Resolver<'_> {
    /// 一つのソースのトップレベルの宣言を一つずつ辿る。ある宣言の誤りはほかの宣言の解決を止めない。
    pub(super) fn walk_program(&mut self, src: Src, program: &Program) {
        for item in &program.items {
            match item {
                Item::Fn(decl) => self.walk_fn(src, decl),
                Item::Type(decl) => self.walk_type_decl(src, decl),
                Item::Error(_) => {}
            }
        }
    }

    fn walk_fn(&mut self, src: Src, decl: &FnDecl) {
        let mut cx = Ctx::new(src);
        self.declare_type_params(&mut cx, &decl.type_params);
        // 引数の段。本体のブロックはその内側に一段積む。
        cx.scopes.push(BTreeMap::new());
        self.declare_params(&mut cx, &decl.params, BindingKind::Param);
        self.ty(&cx, &decl.ret);
        self.uses(&cx, decl.uses.as_ref());
        self.block(&mut cx, &decl.body);
    }

    fn walk_type_decl(&mut self, src: Src, decl: &TypeDecl) {
        let mut cx = Ctx::new(src);
        self.declare_type_params(&mut cx, &decl.type_params);
        for variant in &decl.variants {
            for field in &variant.fields {
                self.ty(&cx, field);
            }
        }
    }

    /// 型パラメータの並びを宣言する。`index` は `effect` の有無で分けて数える（10-04 `BindingKind`）。
    fn declare_type_params(&mut self, cx: &mut Ctx, params: &[TypeParam]) {
        let mut first: BTreeMap<&str, Span> = BTreeMap::new();
        let mut type_index: u32 = 0;
        let mut effect_index: u32 = 0;
        for p in params {
            let kind = if p.is_effect {
                let k = BindingKind::EffectVar {
                    index: effect_index,
                };
                effect_index = effect_index.saturating_add(1);
                k
            } else {
                let k = BindingKind::TypeParam { index: type_index };
                type_index = type_index.saturating_add(1);
                k
            };
            let id = self.bind_node(kind, &p.name, p.id);
            if let Some(f) = first.get(p.name.text.as_str()).copied() {
                self.report_duplicate(DiagCode::E0312, &p.name, f);
                continue;
            }
            first.insert(p.name.text.as_str(), p.name.span);
            if self.lookup_upper(cx.src, &p.name.text).is_some() {
                self.report(
                    crate::diag::DiagBuilder::new(DiagCode::E0313)
                        .arg("name", p.name.text.clone())
                        .primary(p.name.span),
                );
            }
            let entry = (p.name.text.clone(), id);
            if p.is_effect {
                cx.effect_vars.push(entry);
            } else {
                cx.type_params.push(entry);
            }
        }
    }

    /// 関数とラムダの引数を現在の段に宣言する。型注釈を先に解決する。
    fn declare_params(&mut self, cx: &mut Ctx, params: &[Param], kind: BindingKind) {
        let mut first: BTreeMap<&str, Span> = BTreeMap::new();
        for p in params {
            if let Some(t) = &p.ty {
                self.ty(cx, t);
            }
            let id = self.bind_node(kind, &p.name, p.id);
            if let Some(f) = first.get(p.name.text.as_str()).copied() {
                self.report_duplicate(DiagCode::E0310, &p.name, f);
                continue;
            }
            first.insert(p.name.text.as_str(), p.name.span);
            if let Some(scope) = cx.scopes.last_mut() {
                scope.insert(p.name.text.clone(), id);
            }
        }
    }

    fn ty(&mut self, cx: &Ctx, t: &TypeExpr) {
        match t {
            TypeExpr::Named(n) => {
                self.named_type(cx, n);
                for a in &n.args {
                    self.ty(cx, a);
                }
            }
            TypeExpr::Fn(f) => {
                for p in &f.params {
                    self.ty(cx, p);
                }
                self.ty(cx, &f.ret);
                self.uses(cx, f.uses.as_ref());
            }
            TypeExpr::Paren(p) => self.ty(cx, &p.inner),
            TypeExpr::Error(_) => {}
        }
    }

    // ---------------- 本体 ----------------

    fn block(&mut self, cx: &mut Ctx, block: &Block) {
        cx.scopes.push(BTreeMap::new());
        for stmt in &block.stmts {
            match stmt {
                Stmt::Let(s) => {
                    if let Some(t) = &s.ty {
                        self.ty(cx, t);
                    }
                    // 右辺を解決した後で名前を加える。`let` は再帰的な束縛にならない（01-03）。
                    self.expr(cx, &s.value);
                    if let LetName::Var(name) = &s.name {
                        let id = self.bind_node(BindingKind::Let, name, s.id);
                        // 同じ段の同じ名前は置き換える（ADR 0010）。
                        if let Some(scope) = cx.scopes.last_mut() {
                            scope.insert(name.text.clone(), id);
                        }
                    }
                }
                Stmt::Expr(e) => self.expr(cx, e),
                Stmt::Error(_) => {}
            }
        }
        cx.scopes.pop();
    }

    fn expr(&mut self, cx: &mut Ctx, e: &Expr) {
        match e {
            Expr::Lit(_) | Expr::Unit(_) | Expr::Error(_) => {}
            Expr::Name(n) => self.name_expr(cx, n),
            Expr::Paren(p) => self.expr(cx, &p.inner),
            Expr::List(l) => {
                for x in &l.elems {
                    self.expr(cx, x);
                }
            }
            Expr::Call(c) => {
                self.expr(cx, &c.callee);
                for a in &c.args {
                    // プレースホルダは名前ではないので解決しない（02-04「解決の手順」）。
                    if let Arg::Expr(x) = a {
                        self.expr(cx, x);
                    }
                }
            }
            Expr::Binary(b) => {
                self.expr(cx, &b.lhs);
                self.expr(cx, &b.rhs);
            }
            Expr::Unary(u) => self.expr(cx, &u.operand),
            Expr::Pipe(p) => {
                self.expr(cx, &p.lhs);
                self.expr(cx, &p.rhs);
            }
            Expr::Block(b) => self.block(cx, b),
            Expr::If(i) => self.if_expr(cx, i),
            Expr::Match(m) => {
                self.expr(cx, &m.scrutinee);
                for arm in &m.arms {
                    cx.scopes.push(BTreeMap::new());
                    let mut bound: BTreeMap<String, Span> = BTreeMap::new();
                    self.pattern(cx, &arm.pattern, &mut bound);
                    self.expr(cx, &arm.body);
                    cx.scopes.pop();
                }
            }
            Expr::Lambda(l) => self.lambda(cx, l),
        }
    }

    fn if_expr(&mut self, cx: &mut Ctx, i: &IfExpr) {
        self.expr(cx, &i.cond);
        self.block(cx, &i.then_block);
        match &i.else_branch {
            Some(ElseBranch::Block(b)) => self.block(cx, b),
            Some(ElseBranch::If(inner)) => self.if_expr(cx, inner),
            None => {}
        }
    }

    fn lambda(&mut self, cx: &mut Ctx, l: &LambdaExpr) {
        cx.scopes.push(BTreeMap::new());
        self.declare_params(cx, &l.params, BindingKind::LambdaParam);
        if let Some(t) = &l.ret {
            self.ty(cx, t);
        }
        // ラムダの `uses` でも、外側の関数のエフェクト変数が見える。
        self.uses(cx, l.uses.as_ref());
        self.block(cx, &l.body);
        cx.scopes.pop();
    }

    fn name_expr(&mut self, cx: &Ctx, n: &NameExpr) {
        let found = match &n.qualifier {
            Some(q) => match self.qualified(cx.src, q, &n.name, n.span) {
                Qualified::Found(b) => Some(b),
                Qualified::Failed => None,
            },
            None if starts_upper(&n.name.text) => self.unqualified_upper(cx, &n.name),
            None => self.unqualified_lower(cx, &n.name),
        };
        if let Some(b) = found {
            self.out.refs.insert(n.id, b);
        }
    }

    /// パターンを辿る。変数は現在の段（分岐の段）に加え、一つのパターンの中の重複を報告する。
    fn pattern(&mut self, cx: &mut Ctx, p: &Pattern, bound: &mut BTreeMap<String, Span>) {
        match p {
            Pattern::Wildcard(_) | Pattern::Lit(_) | Pattern::Unit(_) | Pattern::Error(_) => {}
            Pattern::Var(v) => {
                let id = self.bind_node(BindingKind::PatternVar, &v.name, v.id);
                if let Some(first) = bound.get(&v.name.text).copied() {
                    self.report_duplicate(DiagCode::E0311, &v.name, first);
                    return;
                }
                bound.insert(v.name.text.clone(), v.name.span);
                if let Some(scope) = cx.scopes.last_mut() {
                    scope.insert(v.name.text.clone(), id);
                }
            }
            Pattern::Ctor(c) => {
                let found = match &c.qualifier {
                    Some(q) => match self.qualified(cx.src, q, &c.name, c.span) {
                        Qualified::Found(b) if self.is_ctor(b) => Some(b),
                        Qualified::Found(_) => {
                            // モジュールの関数を構成子のパターンに書いた場合。
                            self.report_kind(&c.name, text::VALUE, text::CONSTRUCTOR);
                            None
                        }
                        Qualified::Failed => None,
                    },
                    None => self.unqualified_upper(cx, &c.name),
                };
                if let Some(b) = found {
                    self.out.refs.insert(c.id, b);
                }
                for a in &c.args {
                    self.pattern(cx, a, bound);
                }
            }
        }
    }
}

fn starts_upper(name: &str) -> bool {
    name.chars().next().is_some_and(char::is_uppercase)
}
