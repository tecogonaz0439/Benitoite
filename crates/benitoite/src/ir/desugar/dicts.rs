//! 型検査の辞書の求め方を IR に移す（設計書 02-06「辞書の引数」、01-12「型クラス」）。
use super::*;
use crate::types::{DictExpr, ParamKind, TyHead};

impl State<'_> {
    /// 01-12「型クラス」の V-Dict と V-Super。制約の番号は実装の文脈で読み替える。
    pub(super) fn dict(&self, expr: &DictExpr, span: Span) -> Result<DictVal, InternalError> {
        match expr {
            DictExpr::Impl {
                impl_decl,
                type_args,
                args,
            } => {
                let info = self
                    .types
                    .impls
                    .get(*impl_decl)
                    .ok_or_else(|| error(format!("missing impls for {impl_decl:?}")))?;
                let arg = match &info.target {
                    TypeArg::Ty(t) => TypeArg::Ty(t.subst(type_args, &[])),
                    TypeArg::Head(TyHead::Param(i)) => type_args
                        .get(usize::try_from(*i).map_err(|_| error("type argument overflow"))?)
                        .cloned()
                        .ok_or_else(|| error("missing implementation type argument"))?,
                    TypeArg::Head(h) => TypeArg::Head(h.clone()),
                };
                Ok(DictVal {
                    kind: DictKind::Impl {
                        impl_decl: *impl_decl,
                        tys: type_args.clone(),
                        args: args
                            .iter()
                            .map(|d| self.dict(d, span))
                            .collect::<Result<_, _>>()?,
                    },
                    class: info.class,
                    arg,
                    origin: span,
                })
            }
            DictExpr::Param { constraint, supers } => {
                let index =
                    usize::try_from(*constraint).map_err(|_| error("constraint index overflow"))?;
                let c =
                    self.scheme.class_constraints.get(index).ok_or_else(|| {
                        error(format!("missing class_constraints for {constraint}"))
                    })?;
                let p = self
                    .scheme
                    .type_params
                    .get(usize::try_from(c.param).map_err(|_| error("parameter overflow"))?)
                    .ok_or_else(|| error("missing constraint type parameter"))?;
                let arg = match p.kind {
                    ParamKind::Value => TypeArg::Ty(Ty::Param(c.param)),
                    ParamKind::Ctor { .. } => TypeArg::Head(TyHead::Param(c.param)),
                };
                let kind = if self.impl_head || index < self.impl_constraints {
                    DictKind::ImplParam(*constraint)
                } else {
                    let local = index
                        .checked_sub(self.impl_constraints)
                        .ok_or_else(|| error("constraint offset underflow"))?;
                    DictKind::Param(
                        self.dict_params
                            .get(local)
                            .ok_or_else(|| error("missing dictionary parameter"))?
                            .var,
                    )
                };
                let mut out = DictVal {
                    kind,
                    class: c.class,
                    arg,
                    origin: span,
                };
                for class in supers {
                    let previous = self
                        .types
                        .traits
                        .get(out.class)
                        .ok_or_else(|| error("missing supertrait source"))?;
                    let index = previous
                        .supers
                        .iter()
                        .position(|s| s == class)
                        .ok_or_else(|| error("supertrait not declared"))?;
                    out = DictVal {
                        class: *class,
                        arg: out.arg.clone(),
                        origin: span,
                        kind: DictKind::Super {
                            of: Box::new(out),
                            index: number(index)?,
                        },
                    };
                }
                Ok(out)
            }
        }
    }

    /// 01-12「型クラス」の制約を持つ関数の呼び出しの行。辞書の順は宣言の制約の順。
    pub(super) fn name_dicts(
        &self,
        name: &ast::NameExpr,
        binding: BindingId,
        span: Span,
    ) -> Result<Vec<DictVal>, InternalError> {
        if self.declared(binding)?.class_constraints.is_empty() {
            return Ok(vec![]);
        }
        self.types
            .dicts
            .get(name.id)
            .ok_or_else(|| error(format!("missing dicts for {:?}", name.id)))?
            .iter()
            .map(|d| self.dict(d, span))
            .collect()
    }

    /// 01-12「型クラス」のメソッドの呼び出しの行。
    pub(super) fn method(
        &self,
        name: &ast::NameExpr,
        args: Vec<CoreVal>,
        span: Span,
    ) -> Result<Comp, InternalError> {
        let binding = self.reference(name.id)?;
        let BindingKind::Method { index, .. } = self.binding(binding)?.kind else {
            return Err(error("method binding expected"));
        };
        let mut dicts = self.name_dicts(name, binding, span)?.into_iter();
        let dict = dicts
            .next()
            .ok_or_else(|| error(format!("missing method dictionary for {:?}", name.id)))?;
        let targs = self.targs(name.id, binding)?;
        let ty = self
            .declared(binding)?
            .fn_ty()
            .subst(&targs.tys, &targs.effects);
        let Ty::Fn(f) = ty else {
            return Err(error("method scheme is not a function"));
        };
        Ok(Comp {
            ty: f.ret,
            eff: f.effects,
            origin: span,
            kind: CompKind::Method(Box::new(MethodCall {
                dict,
                method: index,
                targs: TypeArgs {
                    tys: targs.tys.into_iter().skip(1).collect(),
                    effects: targs.effects,
                },
                dicts: dicts.collect(),
                args,
            })),
        })
    }

    /// 01-12「型クラス」のメソッド・制約を持つ関数を値として使う二つの行。
    pub(super) fn dictionary_lambda(
        &mut self,
        name: &ast::NameExpr,
    ) -> Result<Comp, InternalError> {
        let binding = self.reference(name.id)?;
        let targs = self.targs(name.id, binding)?;
        let ty = self
            .declared(binding)?
            .fn_ty()
            .subst(&targs.tys, &targs.effects);
        let Ty::Fn(f) = &ty else {
            return Err(error("dictionary lambda has no function type"));
        };
        let id = self.body_id()?;
        let params = f
            .params
            .iter()
            .map(|t| self.var(None, t.clone()))
            .collect::<Result<Vec<_>, _>>()?;
        let args = params.iter().map(|p| variable(p, name.span)).collect();
        let body = if matches!(self.binding(binding)?.kind, BindingKind::Method { .. }) {
            self.method(name, args, name.span)?
        } else {
            app(
                self.direct_name(name)?,
                self.name_dicts(name, binding, name.span)?,
                args,
                name.span,
            )?
        };
        Ok(returned(value(
            ValKind::Lambda(Box::new(Lambda {
                id,
                params,
                body,
                span: name.span,
            })),
            ty,
            name.span,
        )))
    }
}
