//! 表層の式とブロックをコア計算に移す（設計書 01-12「表層からの脱糖」「初回リリース版の拡張」）。
use super::*;

enum Callee<'a> {
    Value(CoreVal, Vec<DictVal>),
    Ctor {
        adt: BindingId,
        tag: u32,
        tys: Vec<Ty>,
        ret: Ty,
    },
    Method(&'a ast::NameExpr),
}

struct ListParts {
    ty: Ty,
    elem: Ty,
    before: Vec<CoreVal>,
    after: Vec<CoreVal>,
    spread: Option<CoreVal>,
}

enum StatementWrap {
    Eval(Vec<(Var, Comp)>, Span),
    Let(Var, Comp, Span),
    Match {
        pending: Vec<(Var, Comp)>,
        scrutinee: CoreVal,
        vars: Vec<Var>,
        pattern: CorePat,
        span: Span,
    },
}

impl State<'_> {
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    pub(super) fn expr(
        &mut self,
        e: &ast::Expr,
        position: Position,
    ) -> Result<Comp, InternalError> {
        match e {
            ast::Expr::Lit(l) => self.literal(l.id, l.span),
            ast::Expr::Interp(e) => self.interpolation(e),
            ast::Expr::Name(n) => self.name_expr(n),
            ast::Expr::Unit(e) => Ok(unit(e.span)),
            ast::Expr::Paren(e) => self.parenthesized(e, position),
            ast::Expr::List(e) => self.list(e),
            ast::Expr::Call(e) => self.call(e, None, e.span),
            ast::Expr::Record(e) => self.record(e),
            ast::Expr::Binary(e) => self.binary(e, position),
            ast::Expr::Unary(e) => self.unary(e),
            ast::Expr::Pipe(e) => self.pipe(e),
            ast::Expr::If(e) => self.if_expr(e, position),
            ast::Expr::Match(e) => self.match_expr(e, position),
            ast::Expr::Lambda(e) => self.lambda(e),
            ast::Expr::Return(e) => self.return_expr(e, position),
            ast::Expr::Try(e) => self.try_expr(e),
            ast::Expr::Lazy(e) => self.lazy(e),
            ast::Expr::With(e) => self.with(e, position),
            ast::Expr::Handle(e) => self.handle(e),
            ast::Expr::Resume(e) => self.resume(e),
            ast::Expr::Error(e) => Err(error(format!("error expression {:?}", e.id))),
        }
    }

    /// 01-12「名前とリテラル」のリテラルと直接の負のリテラルの行。字面は読み直さない。
    fn literal(&self, node: NodeId, span: Span) -> Result<Comp, InternalError> {
        let c = self
            .types
            .lit_values
            .get(node)
            .ok_or_else(|| error(format!("missing lit_values for {node:?}")))?;
        Ok(returned(value(
            ValKind::Const(constant(c)?),
            self.ty(node)?,
            span,
        )))
    }
    /// 01-12「名前とリテラル」の `(e)` の行。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn parenthesized(
        &mut self,
        e: &ast::ParenExpr,
        position: Position,
    ) -> Result<Comp, InternalError> {
        self.expr(&e.inner, position)
    }

    /// 01-12「名前とリテラル」の局所・関数・組み込み・構成子の名前の各行。
    /// 初回リリース版の定数・操作・辞書を必要とする名前も、束縛の種類で分ける。
    fn name_expr(&mut self, n: &ast::NameExpr) -> Result<Comp, InternalError> {
        let id = self.reference(n.id)?;
        let kind = self.binding(id)?.kind;
        match kind {
            BindingKind::Local(_) => {
                let var = self
                    .locals
                    .get(&id)
                    .ok_or_else(|| error(format!("missing local for {:?}", n.id)))?;
                Ok(returned(variable(var, n.span)))
            }
            BindingKind::Const => Ok(returned(value(
                ValKind::ConstRef(id),
                self.declared(id)?.ret.clone(),
                n.span,
            ))),
            BindingKind::Method { .. } => self.dictionary_lambda(n),
            BindingKind::Fn | BindingKind::Op { .. }
                if !self.declared(id)?.class_constraints.is_empty() =>
            {
                self.dictionary_lambda(n)
            }
            BindingKind::Fn
            | BindingKind::BuiltinFn(_)
            | BindingKind::Field { .. }
            | BindingKind::Op { .. } => Ok(returned(self.direct_name(n)?)),
            BindingKind::Ctor { data, tag } => self.constructor_name(n, id, data, tag),
            BindingKind::Record => self.constructor_name(n, id, id, 0),
            BindingKind::ImplFn { .. }
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::ExternalType
            | BindingKind::Trait
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. } => Err(error(format!(
                "invalid value binding for {:?}: {kind:?}",
                n.id
            ))),
        }
    }

    pub(super) fn direct_name(&self, n: &ast::NameExpr) -> Result<CoreVal, InternalError> {
        let id = self.reference(n.id)?;
        let args = self.targs(n.id, id)?;
        let ty = self.ty(n.id)?;
        let mut result = match self.binding(id)?.kind {
            BindingKind::Fn | BindingKind::Field { .. } => Ok(value(
                ValKind::TopFn {
                    def: id,
                    targs: args,
                },
                ty,
                n.span,
            )),
            BindingKind::BuiltinFn(b) => self.builtin(b, Some(id), None, args, n.span),
            BindingKind::Op { .. } => {
                if let Some(b) = self.resolved.builtin_ops.get(id) {
                    self.builtin(*b, Some(id), Some(id), args, n.span)
                } else {
                    Ok(value(
                        ValKind::Op {
                            op: id,
                            targs: args,
                        },
                        ty,
                        n.span,
                    ))
                }
            }
            BindingKind::ImplFn { .. }
            | BindingKind::Const
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::ExternalType
            | BindingKind::Record
            | BindingKind::Ctor { .. }
            | BindingKind::Trait
            | BindingKind::Method { .. }
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Local(_) => Err(error(format!(
                "invalid bindings kind for direct callee at {:?}",
                n.id
            ))),
        }?;
        // 名前・型・エフェクトは検査済みの参照の型から保持する（設計書 02-05「出力」）。
        result.ty = self.ty(n.id)?;
        Ok(result)
    }

    /// 01-12「名前とリテラル」の、構成子を呼ばずに値として使う二つの行。
    fn constructor_name(
        &mut self,
        n: &ast::NameExpr,
        binding: BindingId,
        adt: BindingId,
        tag: u32,
    ) -> Result<Comp, InternalError> {
        let args = self.targs(n.id, binding)?;
        let tys = value_types(&args)?;
        let ty = self.ty(n.id)?;
        let ty = if matches!(ty, Ty::Fn(_)) {
            ty
        } else {
            self.declared(binding)?
                .fn_ty()
                .subst(&args.tys, &args.effects)
        };
        let Ty::Fn(f) = ty else {
            return Err(error("constructor scheme is not a function"));
        };
        if f.params.is_empty() {
            return Ok(returned(value(
                ValKind::Ctor {
                    adt,
                    tag,
                    tys,
                    args: vec![],
                },
                f.ret,
                n.span,
            )));
        }
        let id = self.body_id()?;
        let params = f
            .params
            .iter()
            .map(|t| self.var(None, t.clone()))
            .collect::<Result<Vec<_>, _>>()?;
        let body = returned(value(
            ValKind::Ctor {
                adt,
                tag,
                tys,
                args: params.iter().map(|p| variable(p, n.span)).collect(),
            },
            f.ret.clone(),
            n.span,
        ));
        Ok(returned(value(
            ValKind::Lambda(Box::new(Lambda {
                param_names: f.param_names.clone(),
                id,
                params,
                body,
                span: n.span,
            })),
            Ty::Fn(f),
            n.span,
        )))
    }

    fn prepare<'e>(
        &mut self,
        callee: &'e ast::Expr,
        pending: &mut Vec<(Var, Comp)>,
        span: Span,
    ) -> Result<Callee<'e>, InternalError> {
        // 標準 raise は表層の専用値であり、普通の操作名の直接呼び出しと
        // 区別して先に値へ束縛する（設計書 01-12「型付きの失敗の表層検査」）。
        if let ast::Expr::Name(n) = callee
            && self.resolved.refs.get(n.id).copied()
                != self.resolved.stdlib("Benitoite.Failure.raise")
        {
            let id = self.reference(n.id)?;
            match self.binding(id)?.kind {
                BindingKind::Ctor { data, tag } => {
                    let args = self.targs(n.id, id)?;
                    let Ty::Fn(f) = self.declared(id)?.fn_ty().subst(&args.tys, &args.effects)
                    else {
                        return Err(error("constructor scheme is not a function"));
                    };
                    return Ok(Callee::Ctor {
                        adt: data,
                        tag,
                        tys: value_types(&args)?,
                        ret: f.ret,
                    });
                }
                BindingKind::Method { .. } => return Ok(Callee::Method(n)),
                BindingKind::Fn
                | BindingKind::BuiltinFn(_)
                | BindingKind::Field { .. }
                | BindingKind::Op { .. } => {
                    return Ok(Callee::Value(
                        self.direct_name(n)?,
                        self.name_dicts(n, id, span)?,
                    ));
                }
                BindingKind::Local(_)
                | BindingKind::Const
                | BindingKind::ImplFn { .. }
                | BindingKind::Data
                | BindingKind::BuiltinType(_)
                | BindingKind::Alias
                | BindingKind::ExternalType
                | BindingKind::Record
                | BindingKind::Trait
                | BindingKind::Effect
                | BindingKind::BuiltinEffect(_)
                | BindingKind::Module(_)
                | BindingKind::NamespaceRoot
                | BindingKind::TypeParam { .. }
                | BindingKind::EffectVar { .. } => {}
            }
        }
        Ok(Callee::Value(self.eval(callee, pending)?, vec![]))
    }
    fn invoke(
        &self,
        callee: Callee<'_>,
        args: Vec<CoreVal>,
        span: Span,
    ) -> Result<Comp, InternalError> {
        match callee {
            Callee::Value(func, dicts) => app(func, dicts, args, span),
            Callee::Ctor { adt, tag, tys, ret } => Ok(returned(value(
                ValKind::Ctor {
                    adt,
                    tag,
                    tys,
                    args,
                },
                ret,
                span,
            ))),
            Callee::Method(n) => self.method(n, args, span),
        }
    }

    /// 01-12「呼び出し」の構成子とそのほかの呼び出しの行。展開後の呼び出しもここを通す。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn call(
        &mut self,
        e: &ast::CallExpr,
        inserted: Option<CoreVal>,
        span: Span,
    ) -> Result<Comp, InternalError> {
        let plan = self.call_plan(e, inserted.is_some())?;
        if e.args.iter().any(|a| a.placeholder().is_some()) {
            return self.placeholder(e, span);
        }
        let mut pending = vec![];
        let callee = self.prepare(&e.callee, &mut pending, span)?;
        let mut source = vec![];
        for arg in &e.args {
            let Some(arg) = arg.expr() else {
                return Err(error("unexpanded placeholder"));
            };
            source.push(self.eval(arg, &mut pending)?);
        }
        let args = planned_arguments(&plan, inserted, source)?;
        Ok(finish(pending, self.invoke(callee, args, span)?, span))
    }

    /// 対応表は検査済みの出力であり、欠落や不正を位置指定で補わない（設計書 02-06「脱糖」）。
    fn call_plan(
        &self,
        e: &ast::CallExpr,
        inserted: bool,
    ) -> Result<crate::typeck::CallPlan, InternalError> {
        let named = e.args.iter().any(|a| matches!(a, ast::Arg::Named(_)));
        let plan = self.types.call_plans.get(e.id).ok_or_else(|| {
            error(if named {
                "named call has no argument plan"
            } else {
                "call has no argument plan"
            })
        })?;
        let Ty::Fn(f) = self.ty(e.callee.id())? else {
            return Err(error("call callee has no function type"));
        };
        if usize::try_from(plan.arity).ok() != Some(f.params.len())
            || plan.inserted_first != inserted
            || plan.source_to_param.len() != e.args.len()
            || plan.hole_names.len() != e.args.iter().filter(|a| a.placeholder().is_some()).count()
        {
            return Err(error("invalid call argument plan"));
        }
        let mut occupied = vec![false; f.params.len()];
        if inserted {
            let slot = occupied
                .first_mut()
                .ok_or_else(|| error("inserted argument has no parameter"))?;
            *slot = true;
        }
        for (arg, position) in e.args.iter().zip(&plan.source_to_param) {
            let i =
                usize::try_from(*position).map_err(|_| error("argument position exceeds usize"))?;
            let slot = occupied
                .get_mut(i)
                .ok_or_else(|| error("argument position out of range"))?;
            if *slot {
                return Err(error("duplicate argument position"));
            }
            *slot = true;
            if let ast::Arg::Named(a) = arg
                && f.param_names.get(i) != Some(&a.name.text)
            {
                return Err(error("named call has no argument plan"));
            }
        }
        if occupied.iter().any(|present| !present) {
            return Err(error("missing argument position"));
        }
        Ok(plan.clone())
    }

    /// 01-12「呼び出し」の前段にあるプレースホルダの展開（設計書 01-02「部分適用のプレースホルダ」）。
    fn placeholder(&mut self, e: &ast::CallExpr, span: Span) -> Result<Comp, InternalError> {
        let plan = self.call_plan(e, false)?;
        let id = self.body_id()?;
        let mut params = vec![];
        for arg in &e.args {
            if let Some(p) = arg.placeholder() {
                params.push(self.var(None, self.ty(p.id)?)?);
            }
        }
        let Ty::Fn(ty) = self.ty(e.id)? else {
            return Err(error("placeholder call does not have a function type"));
        };
        if ty.param_names != plan.hole_names {
            return Err(error("placeholder names do not match argument plan"));
        }
        let conts = std::mem::take(&mut self.conts);
        let return_ty = self.return_ty.replace(ty.ret);
        let body = (|| {
            let mut parameters = params.iter();
            let mut pending = vec![];
            let callee = self.prepare(&e.callee, &mut pending, span)?;
            let mut args = vec![];
            for arg in &e.args {
                args.push(if let Some(e) = arg.expr() {
                    self.eval(e, &mut pending)?
                } else if let Some(p) = arg.placeholder() {
                    let v = parameters
                        .next()
                        .ok_or_else(|| error("missing placeholder parameter"))?;
                    bind(self, returned(variable(v, p.span)), &mut pending)?
                } else {
                    return Err(error("invalid placeholder argument"));
                });
            }
            let args = planned_arguments(&plan, None, args)?;
            let body = finish(pending, self.invoke(callee, args, span)?, span);
            Ok::<_, InternalError>(body)
        })();
        self.return_ty = return_ty;
        self.conts = conts;
        let body = body?;
        let effects = self
            .types
            .lambda_effects
            .get(e.id)
            .cloned()
            .ok_or_else(|| error(format!("missing lambda_effects for {:?}", e.id)))?;
        let ty = self.ty(e.id)?;
        if !matches!(&ty, Ty::Fn(f) if f.effects == effects && f.params == params.iter().map(|p| p.ty.clone()).collect::<Vec<_>>())
        {
            return Err(error("placeholder signature does not match inferred type"));
        }
        Ok(returned(value(
            ValKind::Lambda(Box::new(Lambda {
                param_names: match &ty {
                    Ty::Fn(f) => f.param_names.clone(),
                    Ty::Con(..) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => Vec::new(),
                },
                id,
                params,
                body,
                span,
            })),
            ty,
            span,
        )))
    }

    /// 01-12「呼び出し」のパイプの行。左辺を先に一度だけ評価する。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn pipe(&mut self, p: &ast::PipeExpr) -> Result<Comp, InternalError> {
        let mut pending = vec![];
        let left = self.eval(&p.lhs, &mut pending)?;
        let body = if let ast::Expr::Call(c) = p.rhs.as_ref()
            && !c.args.iter().any(|a| a.placeholder().is_some())
        {
            self.call(c, Some(left), p.span)?
        } else {
            let callee = self.prepare(&p.rhs, &mut pending, p.span)?;
            self.invoke(callee, vec![left], p.span)?
        };
        Ok(finish(pending, body, p.span))
    }

    /// 01-12「演算子」の二項演算の行、および `and`・`or` の二つの行。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn binary(&mut self, e: &ast::BinaryExpr, position: Position) -> Result<Comp, InternalError> {
        let mut pending = vec![];
        let lhs = self.eval(&e.lhs, &mut pending)?;
        if matches!(e.op, ast::BinOp::And | ast::BinOp::Or) {
            let rhs_position = if position == Position::Tail {
                Position::Tail
            } else {
                Position::Other
            };
            let rhs = self.expr(&e.rhs, rhs_position)?;
            self.finish_logic_binary(e, pending, lhs, rhs)
        } else {
            let rhs = self.eval(&e.rhs, &mut pending)?;
            self.finish_strict_binary(e, pending, lhs, rhs)
        }
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_logic_binary(
        &self,
        e: &ast::BinaryExpr,
        pending: Vec<(Var, Comp)>,
        lhs: CoreVal,
        rhs: Comp,
    ) -> Result<Comp, InternalError> {
        let fixed = boolean(e.op == ast::BinOp::Or, e.span);
        let (then_branch, else_branch) = if e.op == ast::BinOp::And {
            (rhs, fixed)
        } else {
            (fixed, rhs)
        };
        let body = branching(lhs, then_branch, else_branch, self.ty(e.id)?, e.span);
        Ok(finish(pending, body, e.span))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_strict_binary(
        &self,
        e: &ast::BinaryExpr,
        pending: Vec<(Var, Comp)>,
        lhs: CoreVal,
        rhs: CoreVal,
    ) -> Result<Comp, InternalError> {
        let operand = self
            .types
            .operand_types
            .get(e.id)
            .ok_or_else(|| error(format!("missing operand_types for {:?}", e.id)))?;
        let (id, tys) = match e.op {
            ast::BinOp::Eq | ast::BinOp::Ne => (
                table::equality_builtin(e.op == ast::BinOp::Ne)
                    .ok_or_else(|| error("missing equality_builtin"))?,
                vec![TypeArg::Ty(operand.clone())],
            ),
            ast::BinOp::Add
            | ast::BinOp::Sub
            | ast::BinOp::Mul
            | ast::BinOp::Div
            | ast::BinOp::IntDiv
            | ast::BinOp::Mod
            | ast::BinOp::Lt
            | ast::BinOp::Le
            | ast::BinOp::Gt
            | ast::BinOp::Ge => {
                let op = match e.op {
                    ast::BinOp::Add => OperatorKind::Add,
                    ast::BinOp::Sub => OperatorKind::Sub,
                    ast::BinOp::Mul => OperatorKind::Mul,
                    ast::BinOp::Div => OperatorKind::Div,
                    ast::BinOp::IntDiv => OperatorKind::IntDiv,
                    ast::BinOp::Mod => OperatorKind::Mod,
                    ast::BinOp::Lt => OperatorKind::Lt,
                    ast::BinOp::Le => OperatorKind::Le,
                    ast::BinOp::Gt => OperatorKind::Gt,
                    ast::BinOp::Ge => OperatorKind::Ge,
                    ast::BinOp::Eq | ast::BinOp::Ne | ast::BinOp::And | ast::BinOp::Or => {
                        return Err(error("invalid arithmetic operator"));
                    }
                };
                (
                    table::operator_builtin(op, basic_id(operand)?)
                        .ok_or_else(|| error(format!("missing operator_builtin for {:?}", e.id)))?,
                    vec![],
                )
            }
            ast::BinOp::And | ast::BinOp::Or => {
                return Err(error("invalid strict logical operator"));
            }
        };
        let body = app(
            self.table_builtin(id, tys, e.span)?,
            vec![],
            vec![lhs, rhs],
            e.span,
        )?;
        Ok(finish(pending, body, e.span))
    }

    /// 01-12「演算子」の `-e` と `not e` の二つの行。直接の負のリテラルは定数にする。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn unary(&mut self, e: &ast::UnaryExpr) -> Result<Comp, InternalError> {
        if self.types.lit_values.get(e.id).is_some() {
            return self.literal(e.id, e.span);
        }
        let mut pending = vec![];
        let operand = self.eval(&e.operand, &mut pending)?;
        self.finish_unary(e, pending, operand)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_unary(
        &self,
        e: &ast::UnaryExpr,
        pending: Vec<(Var, Comp)>,
        operand: CoreVal,
    ) -> Result<Comp, InternalError> {
        let body = match e.op {
            ast::UnOp::Not => branching(
                operand,
                boolean(false, e.span),
                boolean(true, e.span),
                self.ty(e.id)?,
                e.span,
            ),
            ast::UnOp::Neg => {
                let ty = self
                    .types
                    .operand_types
                    .get(e.id)
                    .ok_or_else(|| error(format!("missing operand_types for {:?}", e.id)))?;
                let id = table::operator_builtin(OperatorKind::Neg, basic_id(ty)?)
                    .ok_or_else(|| error(format!("missing operator_builtin for {:?}", e.id)))?;
                app(
                    self.table_builtin(id, vec![], e.span)?,
                    vec![],
                    vec![operand],
                    e.span,
                )?
            }
        };
        Ok(finish(pending, body, e.span))
    }

    /// 01-12「リスト、ラムダ、条件分岐、match」のラムダの行。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lambda(&mut self, e: &ast::LambdaExpr) -> Result<Comp, InternalError> {
        let id = self.body_id()?;
        let params = e
            .params
            .iter()
            .map(|p| self.local(p.id, Some(p.name.text.clone()), self.ty(p.id)?))
            .collect::<Result<Vec<_>, _>>()?;
        let Ty::Fn(ty) = self.ty(e.id)? else {
            return Err(error("lambda does not have a function type"));
        };
        let conts = std::mem::take(&mut self.conts);
        let return_ty = self.return_ty.replace(ty.ret);
        let body = self.block(&e.body, Position::Tail);
        self.return_ty = return_ty;
        self.conts = conts;
        let body = body?;
        let eff = self
            .types
            .lambda_effects
            .get(e.id)
            .cloned()
            .ok_or_else(|| error(format!("missing lambda_effects for {:?}", e.id)))?;
        let ty = Ty::Fn(Box::new(crate::types::FnTy {
            param_names: ty.param_names,
            params: params.iter().map(|p| p.ty.clone()).collect(),
            ret: body.ty.clone(),
            effects: eff,
        }));
        Ok(returned(value(
            ValKind::Lambda(Box::new(Lambda {
                param_names: match &ty {
                    Ty::Fn(f) => f.param_names.clone(),
                    Ty::Con(..) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => Vec::new(),
                },
                id,
                params,
                body,
                span: e.span,
            })),
            ty,
            e.span,
        )))
    }

    /// 01-12「リスト、ラムダ、条件分岐、match」の `if`・`else if`・`else` なしの三つの行。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn if_expr(&mut self, e: &ast::IfExpr, position: Position) -> Result<Comp, InternalError> {
        // else if は同じ順に条件と then を下ろし、型を取って包む順も逆順のまま保つ
        // （設計書 01-12「リスト、ラムダ、条件分岐、match」、02-01「関数の呼び出しと処理系のスタック」）。
        let mut current = e;
        let mut branches = Vec::new();
        let mut body = loop {
            let mut pending = vec![];
            let cond = self.eval(&current.cond, &mut pending)?;
            let then_branch = self.block(&current.then_block, position)?;
            branches.push((current, pending, cond, then_branch));
            match &current.else_branch {
                Some(ast::ElseBranch::If(next)) => current = next,
                Some(ast::ElseBranch::Block(block)) => break self.block(block, position)?,
                None => break unit(current.span),
            }
        };
        for (original, pending, cond, then_branch) in branches.into_iter().rev() {
            let ty = self.result_ty(original.id, position)?;
            body = Self::finish_if(original.span, pending, cond, then_branch, body, ty);
        }
        Ok(body)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_if(
        span: Span,
        pending: Vec<(Var, Comp)>,
        cond: CoreVal,
        then_branch: Comp,
        else_branch: Comp,
        ty: Ty,
    ) -> Comp {
        finish(
            pending,
            branching(cond, then_branch, else_branch, ty, span),
            span,
        )
    }

    /// 01-12「ブロック」の空・最後の式・式文・束縛の文の各行。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    pub(super) fn block(
        &mut self,
        block: &ast::Block,
        position: Position,
    ) -> Result<Comp, InternalError> {
        self.statements(&block.stmts, block.span, position)
    }
    // 一つの式だけのブロックでは文の組み立ての枠を積まない
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn statements(
        &mut self,
        stmts: &[ast::Stmt],
        span: Span,
        position: Position,
    ) -> Result<Comp, InternalError> {
        if let [ast::Stmt::Expr(e)] = stmts {
            return self.expr(e, position);
        }
        self.statement_sequence(stmts, span, position)
    }

    // 文を順に下ろして番号と誤りの順を保ち、続きを逆順に包むことで文の数に比例する再帰を避ける
    // （設計書 01-12「ブロック」、02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn statement_sequence(
        &mut self,
        mut stmts: &[ast::Stmt],
        span: Span,
        position: Position,
    ) -> Result<Comp, InternalError> {
        let mut wrappers = Vec::new();
        let mut body = loop {
            let Some((first, rest)) = stmts.split_first() else {
                break unit(span);
            };
            match first {
                ast::Stmt::Expr(e) if rest.is_empty() => break self.expr(e, position)?,
                ast::Stmt::Expr(e) => {
                    let mut pending = vec![];
                    self.eval(e, &mut pending)?;
                    wrappers.push(StatementWrap::Eval(pending, e.span()));
                }
                ast::Stmt::Bind(b) => wrappers.push(self.binding_stmt(b)?),
                ast::Stmt::Error(e) => return Err(error(format!("error statement {:?}", e.id))),
            }
            stmts = rest;
        };
        for wrapper in wrappers.into_iter().rev() {
            body = Self::finish_statement(wrapper, body);
        }
        Ok(body)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn binding_stmt(&mut self, b: &ast::BindStmt) -> Result<StatementWrap, InternalError> {
        let bound = self.expr(&b.value, Position::Other)?;
        self.binding_wrap(b, bound)
    }

    // パターンと変数の作成を値の式の再帰から分ける（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn binding_wrap(
        &mut self,
        b: &ast::BindStmt,
        bound: Comp,
    ) -> Result<StatementWrap, InternalError> {
        match &b.pattern {
            ast::Pattern::Var(v) => {
                let var = self.local(v.id, Some(v.name.text.clone()), self.ty(b.id)?)?;
                Ok(StatementWrap::Let(var, bound, b.span))
            }
            ast::Pattern::Wildcard(_) => {
                let var = self.var(None, self.ty(b.id)?)?;
                Ok(StatementWrap::Let(var, bound, b.span))
            }
            ast::Pattern::Lit(_)
            | ast::Pattern::Unit(_)
            | ast::Pattern::Ctor(_)
            | ast::Pattern::Record(_)
            | ast::Pattern::Range(_)
            | ast::Pattern::List(_) => {
                let mut pending = vec![];
                let scrutinee = bind(self, bound, &mut pending)?;
                let mut vars = vec![];
                let pattern = self.pattern(&b.pattern, &mut vars)?;
                Ok(StatementWrap::Match {
                    pending,
                    scrutinee,
                    vars,
                    pattern,
                    span: b.span,
                })
            }
            ast::Pattern::Error(e) => Err(error(format!("error binding pattern {:?}", e.id))),
        }
    }

    // 本体の型とエフェクトは包む時点で取り、再帰していたときと同じ IR を作る
    // （設計書 01-12「ブロック」、02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_statement(wrapper: StatementWrap, body: Comp) -> Comp {
        match wrapper {
            StatementWrap::Eval(pending, span) => finish(pending, body, span),
            StatementWrap::Let(var, bound, span) => let_comp(var, bound, body, span),
            StatementWrap::Match {
                pending,
                scrutinee,
                vars,
                pattern,
                span,
            } => {
                let comp = Comp {
                    ty: body.ty.clone(),
                    eff: body.eff.clone(),
                    origin: span,
                    kind: CompKind::Match {
                        scrutinee,
                        rows: vec![MatchRow { pattern, arm: 0 }],
                        arms: vec![MatchArm {
                            vars,
                            guard: None,
                            body,
                        }],
                    },
                };
                finish(pending, comp, span)
            }
        }
    }

    /// 01-12「`return`」の末尾位置と途中の二つの行。
    fn return_expr(
        &mut self,
        e: &ast::ReturnExpr,
        position: Position,
    ) -> Result<Comp, InternalError> {
        if position == Position::Tail {
            return self.expr(&e.value, Position::Tail);
        }
        let mut pending = vec![];
        let v = self.eval(&e.value, &mut pending)?;
        Ok(finish(
            pending,
            Comp {
                kind: CompKind::Escape(v),
                ty: self.result_ty(e.id, position)?,
                eff: EffectSet::empty(),
                origin: e.span,
            },
            e.span,
        ))
    }

    /// 01-12「リスト、ラムダ、条件分岐、match」のリスト、および「リストの展開」の行。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn list(&mut self, e: &ast::ListExpr) -> Result<Comp, InternalError> {
        let ty = self.ty(e.id)?;
        let Ty::Con(TyCon::Builtin(b), types) = &ty else {
            return Err(error("list type expected"));
        };
        if *b != BuiltinTypeId::LIST {
            return Err(error("list type expected"));
        }
        let elem = types
            .first()
            .cloned()
            .ok_or_else(|| error("list element type missing"))?;
        let mut pending = vec![];
        let mut before = vec![];
        let mut after = vec![];
        let mut spread = None;
        for item in &e.elems {
            match item {
                ast::ListElem::Expr(x) => {
                    let v = self.eval(x, &mut pending)?;
                    if spread.is_some() {
                        after.push(v);
                    } else {
                        before.push(v);
                    }
                }
                ast::ListElem::Spread(x) => {
                    if spread.is_some() {
                        return Err(error("multiple list spreads"));
                    }
                    spread = Some(self.eval(&x.expr, &mut pending)?);
                }
            }
        }
        self.finish_list(
            e,
            pending,
            ListParts {
                ty,
                elem,
                before,
                after,
                spread,
            },
        )
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_list(
        &mut self,
        e: &ast::ListExpr,
        mut pending: Vec<(Var, Comp)>,
        parts: ListParts,
    ) -> Result<Comp, InternalError> {
        let ListParts {
            ty,
            elem,
            before,
            after,
            spread,
        } = parts;
        let body = if let Some(spread) = spread {
            let binding = self
                .resolved
                .stdlib("Benitoite.List.concatenate")
                .ok_or_else(|| error("missing stdlib List.concatenate"))?;
            let scheme = self.declared(binding)?;
            let args = TypeArgs {
                tys: vec![TypeArg::Ty(elem)],
                effects: vec![EffectSet::empty(); scheme.effect_params.len()],
            };
            let func = match self.binding(binding)?.kind {
                BindingKind::Fn => value(
                    ValKind::TopFn {
                        def: binding,
                        targs: args.clone(),
                    },
                    scheme.fn_ty().subst(&args.tys, &args.effects),
                    e.span,
                ),
                BindingKind::BuiltinFn(b) => self.builtin(b, Some(binding), None, args, e.span)?,
                BindingKind::ImplFn { .. }
                | BindingKind::Const
                | BindingKind::Data
                | BindingKind::BuiltinType(_)
                | BindingKind::Alias
                | BindingKind::ExternalType
                | BindingKind::Record
                | BindingKind::Field { .. }
                | BindingKind::Ctor { .. }
                | BindingKind::Trait
                | BindingKind::Method { .. }
                | BindingKind::Effect
                | BindingKind::BuiltinEffect(_)
                | BindingKind::Op { .. }
                | BindingKind::Module(_)
                | BindingKind::NamespaceRoot
                | BindingKind::TypeParam { .. }
                | BindingKind::EffectVar { .. }
                | BindingKind::Local(_) => {
                    return Err(error(format!(
                        "invalid stdlib List.concatenate binding at {:?}",
                        e.id
                    )));
                }
            };
            let left = if before.is_empty() {
                spread
            } else {
                let c = app(
                    func.clone(),
                    vec![],
                    vec![value(ValKind::List(before), ty.clone(), e.span), spread],
                    e.span,
                )?;
                if after.is_empty() {
                    return Ok(finish(pending, c, e.span));
                }
                bind(self, c, &mut pending)?
            };
            if after.is_empty() {
                returned(left)
            } else {
                app(
                    func,
                    vec![],
                    vec![left, value(ValKind::List(after), ty.clone(), e.span)],
                    e.span,
                )?
            }
        } else {
            returned(value(ValKind::List(before), ty, e.span))
        };
        Ok(finish(pending, body, e.span))
    }

    /// 01-12「レコード」の構築と更新の二つの行。式を評価した後、宣言の順に値を並べる。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn record(&mut self, e: &ast::RecordExpr) -> Result<Comp, InternalError> {
        let adt = self.reference(e.id)?;
        let ty = self.ty(e.id)?;
        let tys = if let Some(base) = &e.base {
            let Ty::Con(TyCon::Adt(a), tys) = self.ty(base.id())? else {
                return Err(error("record base type expected"));
            };
            if a != adt {
                return Err(error("record base ADT mismatch"));
            }
            tys
        } else {
            value_types(&self.targs(e.id, adt)?)?
        };
        let fields = self
            .types
            .adts
            .get(adt)
            .and_then(|a| a.record.as_ref())
            .cloned()
            .ok_or_else(|| error("missing record fields"))?;
        let field_types = self
            .types
            .adts
            .field_types(adt, 0, &tys)
            .ok_or_else(|| error("missing record field types"))?;
        let mut pending = vec![];
        let base = e
            .base
            .as_ref()
            .map(|b| self.eval(b, &mut pending))
            .transpose()?;
        let mut written = BTreeMap::new();
        for f in &e.fields {
            written.insert(self.reference(f.id)?, self.eval(&f.value, &mut pending)?);
        }
        let mut args = vec![];
        let mut patterns = vec![];
        let mut vars = vec![];
        for (field, ty) in fields.iter().zip(field_types) {
            if let Some(v) = written.remove(&field.binding) {
                args.push(v);
                patterns.push(CorePat::Wild);
            } else if base.is_some() {
                let var = self.var(None, ty)?;
                patterns.push(CorePat::Var(var.id));
                args.push(variable(&var, e.span));
                vars.push(var);
            } else {
                return Err(error("missing record field argument"));
            }
        }
        let body = returned(value(
            ValKind::Ctor {
                adt,
                tag: 0,
                tys,
                args,
            },
            ty.clone(),
            e.span,
        ));
        let body = if let Some(base) = base {
            Comp {
                kind: CompKind::Match {
                    scrutinee: base,
                    rows: vec![MatchRow {
                        pattern: CorePat::Ctor {
                            adt,
                            tag: 0,
                            args: patterns,
                        },
                        arm: 0,
                    }],
                    arms: vec![MatchArm {
                        vars,
                        guard: None,
                        body,
                    }],
                },
                ty,
                eff: EffectSet::empty(),
                origin: e.span,
            }
        } else {
            body
        };
        Ok(finish(pending, body, e.span))
    }

    /// 01-12「文字列補間」の行。式の評価を先に終え、変換と連結を左から行う。
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn interpolation(&mut self, e: &ast::InterpExpr) -> Result<Comp, InternalError> {
        let mut pending = vec![];
        let mut evaluated = vec![];
        for segment in &e.segments {
            evaluated.push(self.eval(&segment.expr, &mut pending)?);
        }
        let mut parts = vec![];
        if !e.head.is_empty() {
            parts.push(string(&e.head, e.span));
        }
        for (segment, v) in e.segments.iter().zip(evaluated) {
            let ty = self
                .types
                .interp_types
                .get(segment.expr.id())
                .ok_or_else(|| {
                    error(format!("missing interp_types for {:?}", segment.expr.id()))
                })?;
            let v = if *ty == basic(BuiltinTypeId::STRING) {
                v
            } else {
                let id = table::interpolation_builtin(basic_id(ty)?).ok_or_else(|| {
                    error(format!(
                        "missing interpolation_builtin for {:?}",
                        segment.expr.id()
                    ))
                })?;
                let c = app(
                    self.table_builtin(id, vec![], segment.span)?,
                    vec![],
                    vec![v],
                    segment.span,
                )?;
                bind(self, c, &mut pending)?
            };
            parts.push(v);
            if !segment.tail.is_empty() {
                parts.push(string(&segment.tail, e.span));
            }
        }
        let mut parts = parts.into_iter();
        let mut left = parts.next().unwrap_or_else(|| string("", e.span));
        let mut rest = parts.peekable();
        while let Some(right) = rest.next() {
            let id = table::operator_builtin(OperatorKind::Add, BuiltinTypeId::STRING)
                .ok_or_else(|| error("missing String addition"))?;
            let c = app(
                self.table_builtin(id, vec![], e.span)?,
                vec![],
                vec![left, right],
                e.span,
            )?;
            if rest.peek().is_none() {
                return Ok(finish(pending, c, e.span));
            }
            left = bind(self, c, &mut pending)?;
        }
        Ok(finish(pending, returned(left), e.span))
    }
}

fn value_types(args: &TypeArgs) -> Result<Vec<Ty>, InternalError> {
    args.tys
        .iter()
        .map(|t| match t {
            TypeArg::Ty(t) => Ok(t.clone()),
            TypeArg::Head(_) => Err(error("constructor has a head type argument")),
        })
        .collect()
}
fn basic_id(ty: &Ty) -> Result<BuiltinTypeId, InternalError> {
    match ty {
        Ty::Con(TyCon::Builtin(b), args) if args.is_empty() => Ok(*b),
        Ty::Con(_, _) | Ty::Fn(_) | Ty::Param(_) | Ty::App(_, _) | Ty::Rigid { .. } => {
            Err(error(format!("basic type expected: {ty:?}")))
        }
    }
}
fn boolean(v: bool, span: Span) -> Comp {
    returned(value(
        ValKind::Const(Const::Bool(v)),
        basic(BuiltinTypeId::BOOLEAN),
        span,
    ))
}
fn string(v: &str, span: Span) -> CoreVal {
    value(
        ValKind::Const(Const::Str(v.into())),
        basic(BuiltinTypeId::STRING),
        span,
    )
}
fn branching(cond: CoreVal, then_branch: Comp, else_branch: Comp, ty: Ty, origin: Span) -> Comp {
    Comp {
        ty,
        eff: then_branch.eff.union(&else_branch.eff),
        origin,
        kind: CompKind::If {
            cond,
            then_branch: Box::new(then_branch),
            else_branch: Box::new(else_branch),
        },
    }
}

/// 式はすでにソース順に束縛してあり、ここで並べるのは保存した値の参照だけである。
fn planned_arguments(
    plan: &crate::typeck::CallPlan,
    inserted: Option<CoreVal>,
    source: Vec<CoreVal>,
) -> Result<Vec<CoreVal>, InternalError> {
    let arity = usize::try_from(plan.arity).map_err(|_| error("call arity exceeds usize"))?;
    if source.len() != plan.source_to_param.len() || inserted.is_some() != plan.inserted_first {
        return Err(error("argument plan does not match source arguments"));
    }
    let mut args = vec![None; arity];
    if let Some(value) = inserted {
        *args
            .first_mut()
            .ok_or_else(|| error("inserted argument has no parameter"))? = Some(value);
    }
    for (value, position) in source.into_iter().zip(&plan.source_to_param) {
        let i = usize::try_from(*position).map_err(|_| error("argument position exceeds usize"))?;
        let slot = args
            .get_mut(i)
            .ok_or_else(|| error("argument position out of range"))?;
        if slot.is_some() {
            return Err(error("duplicate argument position"));
        }
        *slot = Some(value);
    }
    args.into_iter()
        .map(|v| v.ok_or_else(|| error("missing argument position")))
        .collect()
}
