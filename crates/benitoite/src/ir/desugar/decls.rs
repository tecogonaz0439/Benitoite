//! モジュールの定義を宣言の順にまとめる（設計書 01-12「モジュール」、02-06「コア IR」）。
use super::*;
use crate::modules::{ModuleInfo, ModuleKind};
use crate::types::{EffectName, TyHead, TyNames};

/// 01-12「初回リリース版の拡張」のモジュール・型の別名・ドキュメントコメントの行。
/// 別名は型検査済みの型に現れず、コメントは実行の意味を持たない。
pub(super) fn program(
    modules: &ModuleTable,
    asts: &[Module],
    resolved: &ResolveOutput,
    types: &TypeckOutput,
) -> Result<CoreProgram, InternalError> {
    let mut out = Program {
        defs: vec![],
        impls: vec![],
        consts: vec![],
        ops: vec![],
        adts: types.adts.clone(),
        traits: types.traits.clone(),
        schemes: types.decl_types.clone(),
        main: types.main.map(|m| m.binding),
        main_returns_result: types.main.is_some_and(|m| m.returns_result),
        body_count: 0,
    };
    for module in modules.iter() {
        let ast = asts
            .get(usize::try_from(module.id.0).map_err(|_| error("module index overflow"))?)
            .ok_or_else(|| error(format!("missing AST for {:?}", module.id)))?;
        for decl in &ast.decls {
            match &decl.item {
                ast::Item::Fn(f) if f.body.is_some() => {
                    out.defs.push(definition(
                        module,
                        f,
                        DefKind::Fn,
                        None,
                        resolved,
                        types,
                        &mut out.body_count,
                    )?);
                }
                ast::Item::Fn(_)
                | ast::Item::Data(_)
                | ast::Item::Alias(_)
                | ast::Item::Trait(_)
                | ast::Item::Effect(_) => {}
                ast::Item::Record(r) => getters(module, r, resolved, types, &mut out)?,
                ast::Item::Const(c) => {
                    out.consts
                        .push(const_def(c, resolved, types, &mut out.body_count)?)
                }
                ast::Item::Impl(i) => out.impls.push(implementation(
                    module,
                    i,
                    resolved,
                    types,
                    &mut out.body_count,
                )?),
                ast::Item::Error(e) => return Err(error(format!("error item {:?}", e.id))),
            }
        }
    }
    for (_, effect) in types.effects.iter() {
        for id in &effect.ops {
            let b = resolved
                .bindings
                .get(*id)
                .ok_or_else(|| error(format!("missing operation binding {id:?}")))?;
            let s = types
                .decl_types
                .get(*id)
                .ok_or_else(|| error(format!("missing operation scheme {id:?}")))?;
            let module = modules
                .get(b.module)
                .ok_or_else(|| error("missing operation module"))?;
            let prefix = match effect.name {
                EffectName::User(_) => effect.display_name.as_str(),
                EffectName::Builtin(_) => module
                    .name
                    .0
                    .last()
                    .ok_or_else(|| error("empty operation module path"))?,
            };
            out.ops.push(OpDef {
                binding: *id,
                effect: effect.name,
                name: format!("{prefix}.{}", b.name),
                arity: number(s.params.len())?,
                builtin: resolved.builtin_ops.get(*id).copied(),
            });
        }
    }
    Ok(out)
}

fn origin(module: &ModuleInfo, public: bool) -> DefOrigin {
    match module.kind {
        ModuleKind::Entry | ModuleKind::User => DefOrigin::User,
        ModuleKind::Prelude | ModuleKind::Stdlib => {
            if public {
                DefOrigin::StdlibPublic
            } else {
                DefOrigin::StdlibHelper
            }
        }
    }
}
fn name(module: &ModuleInfo, public: bool, name: &str) -> Result<String, InternalError> {
    Ok(match module.kind {
        ModuleKind::Entry => name.into(),
        ModuleKind::User => format!("{}.{name}", module.name.dotted()),
        ModuleKind::Prelude | ModuleKind::Stdlib => {
            if public {
                format!(
                    "{}.{name}",
                    module
                        .name
                        .0
                        .last()
                        .ok_or_else(|| error("empty module path"))?
                )
            } else {
                name.into()
            }
        }
    })
}
fn dictionaries(state: &mut State<'_>) -> Result<(), InternalError> {
    for constraint in state
        .scheme
        .class_constraints
        .clone()
        .into_iter()
        .skip(state.impl_constraints)
    {
        let var = VarId(fresh(&mut state.vars)?);
        state.dict_params.push(DictParam { var, constraint });
    }
    Ok(())
}

/// 01-12「トップレベルの関数」。宣言の型から値の引数と辞書の引数を作る。
fn definition(
    module: &ModuleInfo,
    f: &ast::FnDecl,
    kind: DefKind,
    implementation: Option<(&str, usize)>,
    resolved: &ResolveOutput,
    types: &TypeckOutput,
    bodies: &mut u32,
) -> Result<CoreDef, InternalError> {
    let binding = resolved
        .decls
        .get(f.id)
        .copied()
        .ok_or_else(|| error(format!("missing decls for {:?}", f.id)))?;
    let scheme = types
        .decl_types
        .get(binding)
        .cloned()
        .ok_or_else(|| error(format!("missing decl_types for {binding:?}")))?;
    let mut state = State::new(resolved, types, bodies, scheme.clone());
    state.return_ty = Some(scheme.ret.clone());
    state.impl_constraints = implementation.map_or(0, |(_, count)| count);
    dictionaries(&mut state)?;
    let mut params = vec![];
    if f.params.len() != scheme.params.len() {
        return Err(error("function parameter count mismatch"));
    }
    for (p, ty) in f.params.iter().zip(&scheme.params) {
        params.push(state.local(p.id, Some(p.name.text.clone()), ty.clone())?);
    }
    let body = state.block(
        f.body
            .as_ref()
            .ok_or_else(|| error("missing function body"))?,
        Position::Tail,
    )?;
    let public = state.binding(binding)?.public;
    Ok(Def {
        binding,
        name: match implementation {
            Some((prefix, _)) => format!("{prefix}.{}", f.name.text),
            None => name(module, public, &f.name.text)?,
        },
        origin: origin(module, public || implementation.is_some()),
        kind,
        type_params: scheme.type_params.iter().map(|p| p.name.clone()).collect(),
        effect_params: scheme.effect_params,
        dict_params: state.dict_params,
        params,
        ret: scheme.ret,
        eff: scheme.effects,
        body,
        span: f.span,
        var_count: state.vars,
    })
}

/// 01-12「レコード」のフィールドを取り出す関数の行。
fn getters(
    module: &ModuleInfo,
    record: &ast::RecordDecl,
    resolved: &ResolveOutput,
    types: &TypeckOutput,
    out: &mut CoreProgram,
) -> Result<(), InternalError> {
    let adt = resolved
        .decls
        .get(record.id)
        .copied()
        .ok_or_else(|| error(format!("missing record decls for {:?}", record.id)))?;
    for (i, field) in record.fields.iter().enumerate() {
        let binding = resolved
            .decls
            .get(field.id)
            .copied()
            .ok_or_else(|| error(format!("missing field decls for {:?}", field.id)))?;
        let scheme = types
            .decl_types
            .get(binding)
            .cloned()
            .ok_or_else(|| error(format!("missing field scheme for {binding:?}")))?;
        let mut state = State::new(resolved, types, &mut out.body_count, scheme.clone());
        let r = state.var(
            None,
            scheme
                .params
                .first()
                .cloned()
                .ok_or_else(|| error("getter has no parameter"))?,
        )?;
        let z = state.var(None, scheme.ret.clone())?;
        let pattern = CorePat::Ctor {
            adt,
            tag: 0,
            args: record
                .fields
                .iter()
                .enumerate()
                .map(|(j, _)| {
                    if i == j {
                        CorePat::Var(z.id)
                    } else {
                        CorePat::Wild
                    }
                })
                .collect(),
        };
        let body = Comp {
            kind: CompKind::Match {
                scrutinee: variable(&r, field.span),
                rows: vec![MatchRow { pattern, arm: 0 }],
                arms: vec![MatchArm {
                    vars: vec![z.clone()],
                    guard: None,
                    body: returned(variable(&z, field.span)),
                }],
            },
            ty: scheme.ret.clone(),
            eff: EffectSet::empty(),
            origin: field.span,
        };
        let public = state.binding(binding)?.public;
        out.defs.push(Def {
            binding,
            name: name(
                module,
                public,
                &format!("{}.{}", record.name.text, field.name.text),
            )?,
            origin: origin(module, public),
            kind: DefKind::FieldGetter {
                record: adt,
                index: number(i)?,
            },
            type_params: scheme.type_params.iter().map(|p| p.name.clone()).collect(),
            effect_params: scheme.effect_params,
            dict_params: vec![],
            params: vec![r],
            ret: scheme.ret,
            eff: scheme.effects,
            body,
            span: field.span,
            var_count: state.vars,
        });
    }
    Ok(())
}

/// 01-12「トップレベルの定数」。計算と型検査済みの値を両方残す（設計書 02-06「コア IR」）。
fn const_def(
    c: &ast::ConstDecl,
    resolved: &ResolveOutput,
    types: &TypeckOutput,
    bodies: &mut u32,
) -> Result<ConstDef<Comp>, InternalError> {
    let binding = resolved
        .decls
        .get(c.id)
        .copied()
        .ok_or_else(|| error(format!("missing constant decls for {:?}", c.id)))?;
    let scheme = types
        .decl_types
        .get(binding)
        .cloned()
        .ok_or_else(|| error(format!("missing constant scheme for {binding:?}")))?;
    let mut state = State::new(resolved, types, bodies, scheme.clone());
    let body = state.expr(&c.value, Position::Other)?;
    Ok(ConstDef {
        binding,
        name: c.name.text.clone(),
        ty: scheme.ret,
        body,
        value: types
            .consts
            .get(binding)
            .cloned()
            .ok_or_else(|| error(format!("missing consts for {binding:?}")))?,
        span: c.span,
        var_count: state.vars,
    })
}

/// 01-12「型クラス」の実装の定義（D-Impl）。メソッドは型クラスの宣言の順にする。
fn implementation(
    module: &ModuleInfo,
    decl: &ast::ImplDecl,
    resolved: &ResolveOutput,
    types: &TypeckOutput,
    bodies: &mut u32,
) -> Result<ImplDef<Comp>, InternalError> {
    let info = types
        .impls
        .get(decl.id)
        .ok_or_else(|| error(format!("missing impls for {:?}", decl.id)))?;
    let type_params: Vec<_> = info.type_params.iter().map(|p| p.name.clone()).collect();
    let names = TyNames {
        adts: &types.adts,
        effects: &types.effects,
        type_params: &type_params,
        effect_params: &[],
    };
    let target = match &info.target {
        TypeArg::Ty(t) => t.show(&names),
        TypeArg::Head(TyHead::Param(i)) => type_params
            .get(usize::try_from(*i).map_err(|_| error("type parameter overflow"))?)
            .cloned()
            .ok_or_else(|| error("missing constructor parameter"))?,
        TypeArg::Head(TyHead::Con(TyCon::Adt(a))) => types
            .adts
            .get(*a)
            .ok_or_else(|| error("missing target ADT"))?
            .name
            .clone(),
        TypeArg::Head(TyHead::Con(TyCon::Builtin(b))) => basic(*b).show(&names),
    };
    let class = types
        .traits
        .get(info.class)
        .ok_or_else(|| error("missing implementation class"))?;
    let name = format!("{}[{target}]", class.name);
    let scheme = Scheme {
        type_params: info.type_params.clone(),
        class_constraints: info.class_constraints.clone(),
        effect_params: vec![],
        params: vec![],
        ret: basic(BuiltinTypeId::UNIT),
        effects: EffectSet::empty(),
        wrote_io_all: false,
    };
    let mut state = State::new(resolved, types, bodies, scheme);
    state.impl_head = true;
    state.impl_constraints = info.class_constraints.len();
    let supers = info
        .supers
        .iter()
        .map(|d| state.dict(d, decl.span))
        .collect::<Result<_, _>>()?;
    let mut methods = vec![];
    for (index, binding) in info.methods.iter().enumerate() {
        let f = decl
            .fns
            .iter()
            .find(|f| resolved.decls.get(f.decl.id) == Some(binding))
            .ok_or_else(|| error(format!("missing implementation method {binding:?}")))?;
        methods.push(definition(
            module,
            &f.decl,
            DefKind::Method {
                impl_decl: decl.id,
                index: number(index)?,
            },
            Some((&name, info.class_constraints.len())),
            resolved,
            types,
            state.bodies,
        )?);
    }
    Ok(ImplDef {
        impl_decl: decl.id,
        class: info.class,
        name,
        origin: origin(module, true),
        type_params,
        target: info.target.clone(),
        dict_params: info.class_constraints.clone(),
        supers,
        methods,
        span: decl.span,
    })
}
