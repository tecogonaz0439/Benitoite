//! シグネチャと本体の AST の走査（設計書 02-04「解決の手順」の手順 3・5）。

use std::collections::{BTreeMap, BTreeSet};

use crate::base::{BindingId, ModuleId, NodeId};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::*;

use super::collect::Resolver;
use super::lookup::{Ctx, Position};
use super::{BindingKind, LocalKind};

impl Resolver<'_> {
    fn type_parameters(&mut self, ctx: &mut Ctx, owner: NodeId, params: &[TypeParamDecl]) {
        let mut seen = BTreeMap::new();
        let mut types = 0_u32;
        let mut effects = 0_u32;
        for param in params {
            if let Some(first) = seen.get(&param.name.text).copied() {
                self.duplicate(DiagCode::E0312, &param.name, first, "");
            } else if let Some(top) = self.upper(ctx, &param.name.text, false) {
                let mut d = DiagBuilder::new(DiagCode::E0313)
                    .arg("name", param.name.text.clone())
                    .primary(param.name.span);
                if let Some(span) = self.out.bindings.get(top).and_then(|b| b.span) {
                    d = d.secondary(span, "declared");
                }
                self.out.diagnostics.push(d.build());
            }
            let kind = match param.kind {
                TypeParamKind::Value | TypeParamKind::Ctor { .. } => {
                    let index = types;
                    types = types.saturating_add(1);
                    BindingKind::TypeParam { owner, index }
                }
                TypeParamKind::Effect => {
                    let index = effects;
                    effects = effects.saturating_add(1);
                    BindingKind::EffectVar { owner, index }
                }
            };
            let id = self.node_binding(ctx.module, param.id, &param.name, kind, false, None);
            seen.entry(param.name.text.clone()).or_insert(id);
            ctx.types.insert(param.name.text.clone(), id);
        }
        for param in params {
            for constraint in &param.constraints {
                if let ConstraintRef::Class(c) = constraint {
                    self.name(ctx, c.id, &c.path, Position::Class);
                }
            }
        }
    }

    pub(super) fn ty(&mut self, ctx: &mut Ctx, ty: &TypeExpr) {
        self.ty_in_list(ctx, ty, false);
    }

    // 括弧で囲んだ型は独立した型であり、uses のコンマを外の並びへ戻せない。
    // 修正案は、型引数か関数の引数の型の並びにある場合だけに付ける（02-04「誤りと修正案」、F06「確認の観点」）。
    fn ty_in_list(&mut self, ctx: &mut Ctx, ty: &TypeExpr, in_list: bool) {
        match ty {
            TypeExpr::Named(t) => {
                self.name(ctx, t.id, &t.path, Position::Type);
                for arg in &t.args {
                    self.ty_in_list(ctx, arg, true);
                }
            }
            TypeExpr::Fn(t) => {
                for param in &t.params {
                    self.ty_in_list(ctx, param, true);
                }
                self.ty(ctx, &t.ret);
                if let Some(uses) = &t.uses {
                    self.uses(ctx, uses, in_list.then_some(t.span));
                }
            }
            TypeExpr::Paren(t) => self.ty(ctx, &t.inner),
            TypeExpr::Error(_) => {}
        }
    }

    fn signature(
        &mut self,
        ctx: &mut Ctx,
        owner: NodeId,
        type_params: &[TypeParamDecl],
        params: &[Param],
        ret: &TypeExpr,
        uses: Option<&UsesList>,
    ) {
        self.type_parameters(ctx, owner, type_params);
        for param in params {
            if let Some(ty) = &param.ty {
                self.ty(ctx, ty);
            }
        }
        self.ty(ctx, ret);
        if let Some(uses) = uses {
            self.uses(ctx, uses, None);
        }
        ctx.scopes.push(BTreeMap::new());
        self.parameters(ctx, params, LocalKind::Param);
    }

    pub(super) fn signatures(&mut self) {
        for module in self.modules.iter() {
            let Some(ast) = self.ast(module.id) else {
                continue;
            };
            for top in &ast.decls {
                self.decl_signature(module.id, top);
            }
        }
    }

    fn save_contract(&mut self, top: &TopDecl, ctx: &Ctx) {
        if top.public.is_some()
            && let Some(owner) = self.out.decls.get(top.item.id()).copied()
        {
            self.contracts
                .extend(ctx.used.iter().map(|(used, span)| (owner, *used, *span)));
        }
    }

    fn decl_signature(&mut self, module: ModuleId, top: &TopDecl) {
        let mut ctx = Ctx::new(module, top.item.id());
        match &top.item {
            Item::Fn(d) => {
                self.signature(
                    &mut ctx,
                    d.id,
                    &d.type_params,
                    &d.params,
                    &d.ret,
                    d.uses.as_ref(),
                );
                self.contexts.insert(d.id, ctx.clone());
            }
            Item::Const(d) => {
                self.ty(&mut ctx, &d.ty);
                self.contexts.insert(d.id, ctx.clone());
            }
            Item::Data(d) => {
                self.type_parameters(&mut ctx, d.id, &d.type_params);
                for v in &d.variants {
                    for ty in &v.fields {
                        self.ty(&mut ctx, ty);
                    }
                }
            }
            Item::Alias(d) => {
                self.type_parameters(&mut ctx, d.id, &d.type_params);
                self.ty(&mut ctx, &d.ty);
                if let Some(id) = self.out.decls.get(d.id).copied() {
                    self.alias_edges
                        .insert(id, self.used_of_kind(&ctx, BindingKind::Alias));
                }
            }
            Item::Record(d) => {
                self.type_parameters(&mut ctx, d.id, &d.type_params);
                for f in &d.fields {
                    self.ty(&mut ctx, &f.ty);
                }
            }
            Item::Trait(d) => {
                self.type_parameters(&mut ctx, d.id, std::slice::from_ref(&d.param));
                if let Some(id) = self.out.decls.get(d.id).copied() {
                    self.trait_edges
                        .insert(id, self.used_of_kind(&ctx, BindingKind::Trait));
                }
                for method in &d.methods {
                    let mut method_ctx = ctx.clone();
                    method_ctx.used.clear();
                    self.signature(
                        &mut method_ctx,
                        method.id,
                        &method.type_params,
                        &method.params,
                        &method.ret,
                        method.uses.as_ref(),
                    );
                    ctx.used.extend(method_ctx.used);
                }
            }
            Item::Effect(d) => {
                for op in &d.ops {
                    let mut op_ctx = Ctx::new(module, d.id);
                    self.signature(
                        &mut op_ctx,
                        op.id,
                        &op.type_params,
                        &op.params,
                        &op.ret,
                        None,
                    );
                    ctx.used.extend(op_ctx.used);
                }
            }
            Item::Impl(d) => {
                self.type_parameters(&mut ctx, d.id, &d.type_params);
                self.name(&mut ctx, d.class.id, &d.class.path, Position::Class);
                self.ty(&mut ctx, &d.target);
                for f in &d.fns {
                    let mut fn_ctx = ctx.clone();
                    // 非推奨の自己参照の除外は、実装全体を囲む宣言の ID を使う（10-04）。
                    fn_ctx.used.clear();
                    self.signature(
                        &mut fn_ctx,
                        f.decl.id,
                        &f.decl.type_params,
                        &f.decl.params,
                        &f.decl.ret,
                        f.decl.uses.as_ref(),
                    );
                    self.contexts.insert(f.decl.id, fn_ctx);
                }
            }
            Item::Error(_) => {}
        }
        self.save_contract(top, &ctx);
    }

    pub(super) fn used_of_kind(&self, ctx: &Ctx, kind: BindingKind) -> Vec<BindingId> {
        ctx.used
            .iter()
            .filter(|(id, _)| self.out.bindings.get(*id).is_some_and(|b| b.kind == kind))
            .map(|(id, _)| *id)
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect()
    }

    pub(super) fn bodies(&mut self) {
        for module in self.modules.iter() {
            let Some(ast) = self.ast(module.id) else {
                continue;
            };
            for top in &ast.decls {
                match &top.item {
                    Item::Fn(d) => self.function_body(d),
                    Item::Impl(d) => {
                        for f in &d.fns {
                            self.function_body(&f.decl);
                        }
                    }
                    Item::Const(d) => {
                        let Some(mut ctx) = self.contexts.get(d.id).cloned() else {
                            continue;
                        };
                        ctx.used.clear();
                        self.expr(&mut ctx, &d.value);
                        if let Some(id) = self.out.decls.get(d.id).copied() {
                            self.const_edges
                                .insert(id, self.used_of_kind(&ctx, BindingKind::Const));
                        }
                    }
                    Item::Data(_)
                    | Item::Alias(_)
                    | Item::Record(_)
                    | Item::Trait(_)
                    | Item::Effect(_)
                    | Item::Error(_) => {}
                }
            }
        }
    }

    fn function_body(&mut self, decl: &FnDecl) {
        if let Some(body) = &decl.body
            && let Some(mut ctx) = self.contexts.get(decl.id).cloned()
        {
            ctx.used.clear();
            self.block(&mut ctx, body);
        }
    }

    pub(super) fn block(&mut self, ctx: &mut Ctx, block: &Block) {
        ctx.scopes.push(BTreeMap::new());
        for stmt in &block.stmts {
            match stmt {
                Stmt::Bind(stmt) => self.bind_statement(ctx, stmt),
                Stmt::Expr(expr) => self.expr(ctx, expr),
                Stmt::Error(_) => {}
            }
        }
        ctx.scopes.pop();
    }

    fn if_expr(&mut self, ctx: &mut Ctx, expr: &IfExpr) {
        self.expr(ctx, &expr.cond);
        self.block(ctx, &expr.then_block);
        if let Some(branch) = &expr.else_branch {
            match branch {
                ElseBranch::Block(b) => self.block(ctx, b),
                ElseBranch::If(e) => self.if_expr(ctx, e),
            }
        }
    }

    pub(super) fn expr(&mut self, ctx: &mut Ctx, expr: &Expr) {
        match expr {
            Expr::Name(e) => {
                self.name(ctx, e.id, &e.path, Position::Value);
            }
            Expr::Interp(e) => {
                for segment in &e.segments {
                    self.expr(ctx, &segment.expr);
                }
            }
            Expr::Paren(e) => self.expr(ctx, &e.inner),
            Expr::List(e) => {
                for elem in &e.elems {
                    match elem {
                        ListElem::Expr(e) => self.expr(ctx, e),
                        ListElem::Spread(e) => self.expr(ctx, &e.expr),
                    }
                }
            }
            Expr::Call(e) => {
                self.expr(ctx, &e.callee);
                for arg in &e.args {
                    match arg {
                        Arg::Expr(e) => self.expr(ctx, e),
                        Arg::Placeholder(_) => {}
                    }
                }
            }
            Expr::Record(e) => {
                let record = self.name(ctx, e.id, &e.path, Position::Record);
                if let Some(base) = &e.base {
                    self.expr(ctx, base);
                }
                for field in &e.fields {
                    if let Some(record) = record
                        && let Some(id) = self
                            .members
                            .get(&record)
                            .and_then(|m| m.get(&field.name.text))
                            .copied()
                    {
                        self.record_ref(ctx, field.id, id, field.name.span);
                    }
                    self.expr(ctx, &field.value);
                }
            }
            Expr::Binary(e) => {
                self.expr(ctx, &e.lhs);
                self.expr(ctx, &e.rhs);
            }
            Expr::Unary(e) => self.expr(ctx, &e.operand),
            Expr::Pipe(e) => {
                self.expr(ctx, &e.lhs);
                self.expr(ctx, &e.rhs);
            }
            Expr::If(e) => self.if_expr(ctx, e),
            Expr::Match(e) => {
                self.expr(ctx, &e.scrutinee);
                for arm in &e.arms {
                    self.arm(ctx, arm);
                }
            }
            Expr::Lambda(e) => {
                for param in &e.params {
                    if let Some(ty) = &param.ty {
                        self.ty(ctx, ty);
                    }
                }
                if let Some(ty) = &e.ret {
                    self.ty(ctx, ty);
                }
                if let Some(uses) = &e.uses {
                    self.uses(ctx, uses, None);
                }
                ctx.scopes.push(BTreeMap::new());
                self.parameters(ctx, &e.params, LocalKind::LambdaParam);
                self.block(ctx, &e.body);
                ctx.scopes.pop();
            }
            Expr::Return(e) => self.expr(ctx, &e.value),
            Expr::Try(e) => self.expr(ctx, &e.value),
            Expr::Lazy(e) => self.block(ctx, &e.body),
            Expr::With(e) => {
                ctx.scopes.push(BTreeMap::new());
                for bind in &e.binds {
                    self.expr(ctx, &bind.value);
                    self.implicit_shadow(ctx, &bind.name, LocalKind::WithVar);
                    self.add_local(ctx, bind.id, &bind.name, LocalKind::WithVar);
                }
                self.block(ctx, &e.body);
                ctx.scopes.pop();
            }
            Expr::Handle(e) => {
                self.block(ctx, &e.body);
                for clause in &e.clauses {
                    self.name(ctx, clause.op.id, &clause.op.path, Position::Value);
                    ctx.scopes.push(BTreeMap::new());
                    let mut seen = BTreeMap::new();
                    for param in &clause.params {
                        if let Some(name) = &param.name {
                            if let Some(first) = seen.get(&name.text).copied() {
                                self.duplicate(DiagCode::E0310, name, first, "");
                            } else {
                                self.implicit_shadow(ctx, name, LocalKind::ClauseParam);
                            }
                            let id = self.add_local(ctx, param.id, name, LocalKind::ClauseParam);
                            seen.entry(name.text.clone()).or_insert(id);
                        }
                    }
                    self.block(ctx, &clause.body);
                    ctx.scopes.pop();
                }
            }
            Expr::Resume(e) => self.expr(ctx, &e.value),
            Expr::Lit(_) | Expr::Unit(_) | Expr::Error(_) => {}
        }
    }
}
