//! 構築器の型付き表層を既存のセルと純粋演算へ展開する（設計書 02-06「脱糖」）。
use super::*;
use crate::resolve::builders::BuilderOp;
use crate::typeck::{BuilderDecl, BuilderKind, BuilderOperation};

impl State<'_> {
    fn builder_function(
        &self,
        id: BindingId,
        tys: Vec<Ty>,
        span: Span,
    ) -> Result<CoreVal, InternalError> {
        let targs = TypeArgs {
            tys: tys.into_iter().map(TypeArg::Ty).collect(),
            effects: vec![],
        };
        let kind = self.binding(id)?.kind;
        if let BindingKind::BuiltinFn(b) = kind {
            self.builtin(b, Some(id), None, targs, span)
        } else if kind == BindingKind::Fn {
            let ty = self.declared(id)?.fn_ty().subst(&targs.tys, &targs.effects);
            Ok(value(ValKind::TopFn { def: id, targs }, ty, span))
        } else {
            Err(error("invalid builder helper declaration"))
        }
    }

    pub(super) fn builder_new(
        &mut self,
        decl: &BuilderDecl,
        span: Span,
    ) -> Result<Comp, InternalError> {
        let contents = builder_contents(&decl.kind);
        let initial = match &decl.kind {
            BuilderKind::String => returned(value(
                ValKind::Const(Const::Str(String::new())),
                contents.clone(),
                span,
            )),
            BuilderKind::List(_) => returned(value(ValKind::List(vec![]), contents.clone(), span)),
            BuilderKind::Bytes => app(
                self.builder_function(
                    decl.refs
                        .empty
                        .ok_or_else(|| error("missing bytes empty"))?,
                    vec![],
                    span,
                )?,
                vec![],
                vec![],
                span,
            )?,
        };
        let mut pending = vec![];
        let initial = bind(self, initial, &mut pending)?;
        let cell = app(
            self.builder_function(decl.refs.new, vec![contents], span)?,
            vec![],
            vec![initial],
            span,
        )?;
        Ok(finish(pending, cell, span))
    }

    #[inline(never)]
    pub(super) fn builder_operation(
        &mut self,
        call: &ast::CallExpr,
        op: &BuilderOperation,
    ) -> Result<Comp, InternalError> {
        let cell = self
            .locals
            .get(&op.builder.0)
            .cloned()
            .ok_or_else(|| error("missing builder cell"))?;
        let span = call.span;
        let contents = builder_contents(&op.kind);
        let targs = match &op.kind {
            BuilderKind::List(t) => vec![t.clone()],
            BuilderKind::String | BuilderKind::Bytes => vec![],
        };
        let mut pending = vec![];
        let mut args = vec![];
        // 引数の副作用を一度ずつ終えてから get する。合成 let の値は通常の
        // 生存判定と根の保存を通る（設計書 01-06「関数内の構築器」）。
        for node in &op.args {
            let arg = call
                .args
                .iter()
                .filter_map(ast::Arg::expr)
                .find(|e| e.id() == *node)
                .ok_or_else(|| error("missing builder argument"))?;
            args.push(self.eval(arg, &mut pending)?);
        }
        let get = app(
            self.builder_function(op.refs.get, vec![contents.clone()], span)?,
            vec![],
            vec![variable(&cell, span)],
            span,
        )?;
        let result = match op.op {
            BuilderOp::Copy => get,
            BuilderOp::Length => {
                let old = bind(self, get, &mut pending)?;
                app(
                    self.builder_function(op.refs.length, targs.clone(), span)?,
                    vec![],
                    vec![old],
                    span,
                )?
            }
            BuilderOp::Append | BuilderOp::AppendAll => {
                let old = bind(self, get, &mut pending)?;
                let arg = args
                    .into_iter()
                    .next()
                    .ok_or_else(|| error("missing builder append argument"))?;
                let mut combine = vec![];
                let next = match &op.kind {
                    BuilderKind::String => {
                        let fragment = if op.op == BuilderOp::AppendAll {
                            let empty = value(
                                ValKind::Const(Const::Str(String::new())),
                                contents.clone(),
                                span,
                            );
                            let join = app(
                                self.builder_function(op.refs.join, vec![], span)?,
                                vec![],
                                vec![arg, empty],
                                span,
                            )?;
                            bind(self, join, &mut combine)?
                        } else {
                            arg
                        };
                        let add = table::operator_builtin(OperatorKind::Add, BuiltinTypeId::STRING)
                            .ok_or_else(|| error("missing string append primitive"))?;
                        app(
                            self.table_builtin(add, vec![], span)?,
                            vec![],
                            vec![old, fragment],
                            span,
                        )?
                    }
                    BuilderKind::List(_) => {
                        let helper = if op.op == BuilderOp::Append {
                            op.refs.single.ok_or_else(|| error("missing list append"))?
                        } else {
                            op.refs.join
                        };
                        app(
                            self.builder_function(helper, targs, span)?,
                            vec![],
                            vec![old, arg],
                            span,
                        )?
                    }
                    BuilderKind::Bytes => {
                        let fragment = if op.op == BuilderOp::Append {
                            let single = value(
                                ValKind::List(vec![arg]),
                                Ty::Con(
                                    TyCon::Builtin(BuiltinTypeId::LIST),
                                    vec![basic(BuiltinTypeId::BYTE)],
                                ),
                                span,
                            );
                            let bytes = app(
                                self.builder_function(
                                    op.refs
                                        .single
                                        .ok_or_else(|| error("missing bytes fromList"))?,
                                    vec![],
                                    span,
                                )?,
                                vec![],
                                vec![single],
                                span,
                            )?;
                            bind(self, bytes, &mut combine)?
                        } else {
                            arg
                        };
                        app(
                            self.builder_function(op.refs.join, vec![], span)?,
                            vec![],
                            vec![old, fragment],
                            span,
                        )?
                    }
                };
                // 合成の内部の let はセルを更新する let の内側に閉じる。
                // 形式化した脱糖と同じ束縛の範囲を保つ（設計書 01-12「構築器の専用操作と脱糖」）。
                let next = finish(combine, next, span);
                let next = bind(self, next, &mut pending)?;
                app(
                    self.builder_function(op.refs.set, vec![contents], span)?,
                    vec![],
                    vec![variable(&cell, span), next],
                    span,
                )?
            }
        };
        Ok(finish(pending, result, span))
    }
}

fn builder_contents(kind: &BuilderKind) -> Ty {
    match kind {
        BuilderKind::String => basic(BuiltinTypeId::STRING),
        BuilderKind::List(t) => Ty::Con(TyCon::Builtin(BuiltinTypeId::LIST), vec![t.clone()]),
        BuilderKind::Bytes => basic(BuiltinTypeId::BYTES),
    }
}
