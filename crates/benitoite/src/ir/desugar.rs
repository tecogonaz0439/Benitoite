//! 型検査済みの AST を値と計算に分けたコア IR に移す
//! （設計書 02-06「脱糖」、01-12「表層からの脱糖」「初回リリース版の拡張」）。

use std::collections::BTreeMap;

use crate::base::{BindingId, NodeId, Span};
use crate::builtins::table::{self, EntryKind};
use crate::builtins::{self, BuiltinId};

use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::resolve::{Binding, BindingKind};
use crate::syntax::ast;
use crate::syntax::ast::Module;
use crate::typeck::TypeckOutput;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId};
use crate::types::{ConstValue, EffectSet, FnTy, Scheme, Ty, TyCon, TypeArg, TypeArgs};

use super::InternalError;
use super::core_ir::*;

mod decls;
mod dicts;
mod effects;
mod exprs;
mod patterns;
#[cfg(test)]
mod tests;

/// 型検査を通ったプログラムをコア IR に移す（02-06「脱糖」、01-12「表層からの脱糖」「初回リリース版の拡張」）。
/// 定義の並びは、モジュールの ID の順、モジュールの中では宣言の順とする。
/// `Program::main` は `types.main` から写す（`require_main` が偽の検査では `None`）。
pub fn desugar(
    modules: &ModuleTable,
    asts: &[Module],
    resolved: &ResolveOutput,
    types: &TypeckOutput,
) -> Result<CoreProgram, InternalError> {
    decls::program(modules, asts, resolved, types)
}

fn error(message: impl Into<String>) -> InternalError {
    InternalError {
        stage: "desugar",
        message: message.into(),
    }
}

fn number(n: usize) -> Result<u32, InternalError> {
    u32::try_from(n).map_err(|_| error("index does not fit u32"))
}

fn fresh(n: &mut u32) -> Result<u32, InternalError> {
    let id = *n;
    *n = n
        .checked_add(1)
        .ok_or_else(|| error("identifier overflow"))?;
    Ok(id)
}

fn basic(id: BuiltinTypeId) -> Ty {
    Ty::Con(TyCon::Builtin(id), vec![])
}
fn function(params: Vec<Ty>, ret: Ty, effects: EffectSet) -> Ty {
    Ty::Fn(Box::new(FnTy {
        params,
        ret,
        effects,
    }))
}
fn value(kind: ValKind<Comp>, ty: Ty, origin: Span) -> CoreVal {
    Val { kind, ty, origin }
}
fn returned(v: CoreVal) -> Comp {
    Comp {
        ty: v.ty.clone(),
        origin: v.origin,
        eff: EffectSet::empty(),
        kind: CompKind::Return(v),
    }
}
/// 01-12「名前とリテラル」の `()` の行と「ブロック」の空のブロックの行。
fn unit(origin: Span) -> Comp {
    returned(value(
        ValKind::Const(Const::Unit),
        basic(BuiltinTypeId::UNIT),
        origin,
    ))
}
fn variable(v: &Var, origin: Span) -> CoreVal {
    value(ValKind::Var(v.id), v.ty.clone(), origin)
}
fn let_comp(var: Var, bound: Comp, body: Comp, origin: Span) -> Comp {
    Comp {
        ty: body.ty.clone(),
        eff: bound.eff.union(&body.eff),
        origin,
        kind: CompKind::Let {
            var,
            bound: Box::new(bound),
            body: Box::new(body),
        },
    }
}
fn app(
    func: CoreVal,
    dicts: Vec<DictVal>,
    args: Vec<CoreVal>,
    origin: Span,
) -> Result<Comp, InternalError> {
    let Ty::Fn(f) = &func.ty else {
        return Err(error("callee does not have a function type"));
    };
    Ok(Comp {
        ty: f.ret.clone(),
        eff: f.effects.clone(),
        origin,
        kind: CompKind::App { func, dicts, args },
    })
}

/// 子の計算を新しい変数に束縛する。続きを別に作り、書いた順を `finish` で復元する
/// （設計書 01-12「呼び出し」「演算子」「ブロック」）。
fn bind(
    state: &mut State<'_>,
    bound: Comp,
    pending: &mut Vec<(Var, Comp)>,
) -> Result<CoreVal, InternalError> {
    let var = state.var(None, bound.ty.clone())?;
    let v = variable(&var, bound.origin);
    pending.push((var, bound));
    Ok(v)
}
fn finish(pending: Vec<(Var, Comp)>, mut body: Comp, origin: Span) -> Comp {
    for (var, bound) in pending.into_iter().rev() {
        body = let_comp(var, bound, body, origin);
    }
    body
}

fn constant(c: &ConstValue) -> Result<Const, InternalError> {
    Ok(match c {
        ConstValue::Integer(v) => Const::Int(*v),
        ConstValue::Float(v) => Const::Float(*v),
        ConstValue::String(v) => Const::Str(v.clone()),
        ConstValue::Character(v) => Const::Char(*v),
        ConstValue::Boolean(v) => Const::Bool(*v),
        ConstValue::Unit => Const::Unit,
        ConstValue::Byte(v) => Const::Byte(*v),
        ConstValue::Decimal(v) => Const::Decimal(*v),
        ConstValue::Ctor { .. } | ConstValue::List(_) | ConstValue::Map(_) | ConstValue::Set(_) => {
            return Err(error("compound value in literal table"));
        }
    })
}

// 解放が残る with の本体も関数の結果になるので、末尾と結果を区別する
// （設計書 01-08「末尾呼び出し」、01-12「関数の境界と escape」）。
#[derive(Clone, Copy, PartialEq, Eq)]
enum Position {
    Tail,
    Result,
    Other,
}

struct State<'a> {
    resolved: &'a ResolveOutput,
    types: &'a TypeckOutput,
    bodies: &'a mut u32,
    vars: u32,
    locals: BTreeMap<BindingId, Var>,
    scheme: Scheme,
    return_ty: Option<Ty>,
    dict_params: Vec<DictParam>,
    impl_constraints: usize,
    impl_head: bool,
    conts: Vec<(ContVar, Ty)>,
}

impl<'a> State<'a> {
    fn new(
        resolved: &'a ResolveOutput,
        types: &'a TypeckOutput,
        bodies: &'a mut u32,
        scheme: Scheme,
    ) -> Self {
        Self {
            resolved,
            types,
            bodies,
            vars: 0,
            locals: BTreeMap::new(),
            scheme,
            return_ty: None,
            dict_params: vec![],
            impl_constraints: 0,
            impl_head: false,
            conts: vec![],
        }
    }
    fn ty(&self, node: NodeId) -> Result<Ty, InternalError> {
        self.types
            .expr_types
            .get(node)
            .cloned()
            .ok_or_else(|| error(format!("missing expr_types for {node:?}")))
    }
    fn result_ty(&self, node: NodeId, position: Position) -> Result<Ty, InternalError> {
        match position {
            Position::Tail | Position::Result => self
                .return_ty
                .clone()
                .ok_or_else(|| error("result position has no enclosing function")),
            Position::Other => self.ty(node),
        }
    }
    fn reference(&self, node: NodeId) -> Result<BindingId, InternalError> {
        self.resolved
            .refs
            .get(node)
            .copied()
            .ok_or_else(|| error(format!("missing refs for {node:?}")))
    }
    fn declaration(&self, node: NodeId) -> Result<BindingId, InternalError> {
        self.resolved
            .decls
            .get(node)
            .copied()
            .ok_or_else(|| error(format!("missing decls for {node:?}")))
    }
    fn binding(&self, id: BindingId) -> Result<&Binding, InternalError> {
        self.resolved
            .bindings
            .get(id)
            .ok_or_else(|| error(format!("missing bindings for {id:?}")))
    }
    fn declared(&self, id: BindingId) -> Result<&Scheme, InternalError> {
        self.types
            .decl_types
            .get(id)
            .ok_or_else(|| error(format!("missing decl_types for {id:?}")))
    }
    fn targs(&self, node: NodeId, id: BindingId) -> Result<TypeArgs, InternalError> {
        if let Some(args) = self.types.type_args.get(node) {
            return Ok(args.clone());
        }
        let s = self.declared(id)?;
        if s.type_params.is_empty() && s.effect_params.is_empty() {
            Ok(TypeArgs::default())
        } else {
            Err(error(format!("missing type_args for {node:?}")))
        }
    }
    fn var(&mut self, name: Option<String>, ty: Ty) -> Result<Var, InternalError> {
        Ok(Var {
            id: VarId(fresh(&mut self.vars)?),
            name,
            ty,
        })
    }
    fn local(&mut self, node: NodeId, name: Option<String>, ty: Ty) -> Result<Var, InternalError> {
        let id = self.declaration(node)?;
        let var = self.var(name, ty)?;
        self.locals.insert(id, var.clone());
        Ok(var)
    }
    fn body_id(&mut self) -> Result<BodyId, InternalError> {
        Ok(BodyId(fresh(self.bodies)?))
    }
    fn eval(
        &mut self,
        e: &ast::Expr,
        pending: &mut Vec<(Var, Comp)>,
    ) -> Result<CoreVal, InternalError> {
        let comp = self.expr(e, Position::Other)?;
        bind(self, comp, pending)
    }
    fn builtin(
        &self,
        id: BuiltinId,
        decl: Option<BindingId>,
        op: Option<BindingId>,
        targs: TypeArgs,
        span: Span,
    ) -> Result<CoreVal, InternalError> {
        let entry = builtins::builtin_decl(id)
            .ok_or_else(|| error(format!("missing builtin_decl for {id:?}")))?;
        let s = if let Some(decl) = decl {
            self.declared(decl)?.clone()
        } else {
            table::builtin_scheme(id)
                .ok_or_else(|| error(format!("missing builtin_scheme for {id:?}")))?
        };
        Ok(value(
            ValKind::Builtin {
                id,
                info: BuiltinInfo {
                    class: entry.capability,
                    op,
                    decl,
                    intrinsic: table::builtin_intrinsic(id),
                },
                targs: targs.clone(),
            },
            s.fn_ty().subst(&targs.tys, &targs.effects),
            span,
        ))
    }
    fn table_builtin(
        &self,
        id: BuiltinId,
        tys: Vec<TypeArg>,
        span: Span,
    ) -> Result<CoreVal, InternalError> {
        let kind = table::builtin_kind(id)
            .ok_or_else(|| error(format!("missing builtin_kind for {id:?}")))?;
        let decl = match kind {
            EntryKind::Declared => {
                let entry = builtins::builtin_decl(id)
                    .ok_or_else(|| error(format!("missing builtin_decl for {id:?}")))?;
                Some(
                    self.resolved
                        .stdlib(&format!("Benitoite.{}", entry.name))
                        .ok_or_else(|| error(format!("missing stdlib declaration for {id:?}")))?,
                )
            }
            EntryKind::Operator { .. }
            | EntryKind::Equality { .. }
            | EntryKind::Interpolation { .. }
            | EntryKind::ListPattern(_) => None,
            EntryKind::EffectOp => return Err(error("effect operation requested without binding")),
        };
        let s = if let Some(d) = decl {
            self.declared(d)?.clone()
        } else {
            table::builtin_scheme(id)
                .ok_or_else(|| error(format!("missing builtin_scheme for {id:?}")))?
        };
        self.builtin(
            id,
            decl,
            None,
            TypeArgs {
                tys,
                effects: vec![EffectSet::empty(); s.effect_params.len()],
            },
            span,
        )
    }
}

#[cfg(test)]
// テストの失敗を処理系の停止と区別する（実装プラン F11「テストの補助」）。
#[allow(clippy::panic)]
pub(crate) mod test_support {
    use super::*;
    use crate::modules::LoadOutput;

    /// ソースから脱糖し、独立したコア IR の検査器にも通す（実装プラン F11「テストの補助」）。
    pub(crate) fn desugar_files(
        files: &[(&str, &str)],
        require_main: bool,
    ) -> (LoadOutput, ResolveOutput, TypeckOutput, CoreProgram) {
        let (load, resolved, types, diagnostics) =
            crate::typeck::test_support::check_files(files, require_main);
        assert!(
            !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
            "{diagnostics:#?}"
        );
        let core = desugar(&load.modules, &load.asts, &resolved, &types)
            .unwrap_or_else(|e| panic!("{e:#?}"));
        let errors = super::super::check::check_program(&core);
        assert!(errors.is_empty(), "{errors:#?}");
        (load, resolved, types, core)
    }
}
