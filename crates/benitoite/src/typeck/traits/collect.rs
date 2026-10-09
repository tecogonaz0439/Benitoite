//! 型クラスと実装の頭部を集め、シグネチャを定義内の番号へ移す（設計書 02-05「宣言の検査」）。
use super::{class_name, kind, text};
use crate::base::{BindingId, ModuleId};
use crate::diag::{DiagBuilder, DiagCode};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::typeck::decls::{Decls, Scope, scheme, unit};
use crate::types::*;

pub(super) fn trait_decl<'a>(d: &'a Decls<'_>, id: BindingId) -> Option<&'a TraitDecl> {
    d.asts.iter().flat_map(|a| &a.decls).find_map(|top| {
        if let Item::Trait(t) = &top.item
            && d.binding(t.id) == Some(id)
        {
            Some(t)
        } else {
            None
        }
    })
}
pub(super) fn parameter<'a>(d: &'a Decls<'_>, id: BindingId) -> Option<&'a TypeParamDecl> {
    let mut params = vec![];
    for top in d.asts.iter().flat_map(|a| &a.decls) {
        match &top.item {
            Item::Fn(f) => params.extend(&f.type_params),
            Item::Data(a) => params.extend(&a.type_params),
            Item::Record(a) => params.extend(&a.type_params),
            Item::Alias(a) => params.extend(&a.type_params),
            Item::Trait(t) => {
                params.push(&t.param);
                for m in &t.methods {
                    params.extend(&m.type_params);
                }
            }
            Item::Impl(i) => {
                params.extend(&i.type_params);
                for f in &i.fns {
                    params.extend(&f.decl.type_params);
                }
            }
            Item::Effect(e) => {
                for op in &e.ops {
                    params.extend(&op.type_params);
                }
            }
            Item::Const(_) | Item::Error(_) => {}
        }
    }
    params.into_iter().find(|p| d.binding(p.id) == Some(id))
}
pub(super) fn check_parameters(
    d: &mut Decls<'_>,
    params: &[TypeParamDecl],
    _: &Scope,
    _: &Scheme,
    allowed: bool,
) {
    for p in params {
        for c in &p.constraints {
            match c {
                ConstraintRef::Builtin {
                    span,
                    kind: builtin,
                } if !allowed || kind(p) != ParamKind::Value => {
                    let name = match builtin {
                        BuiltinConstraint::Equality => text::EQUALITY,
                        BuiltinConstraint::Key => text::KEY,
                        BuiltinConstraint::Ordered => text::ORDERED,
                    };
                    d.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0425)
                            .arg("constraint", name)
                            .primary(*span)
                            .build(),
                    );
                }
                ConstraintRef::Class(c) => {
                    if let Some(class) = d.reference(c.id)
                        && let Some(t) = trait_decl(d, class)
                        && kind(&t.param) != kind(p)
                    {
                        let wanted = kind(&t.param);
                        let diag =
                            if let (ParamKind::Ctor { arity }, ParamKind::Ctor { arity: needed }) =
                                (kind(p), wanted)
                            {
                                DiagBuilder::new(DiagCode::E0427)
                                    .arg("name", &p.name.text)
                                    .arg("expected", arity.to_string())
                                    .arg("found", needed.to_string())
                                    .primary(c.span)
                            } else {
                                DiagBuilder::new(DiagCode::E0714)
                                    .arg("name", &p.name.text)
                                    .arg("trait_name", class_name(d, class))
                                    .primary(c.span)
                                    .help(if wanted == ParamKind::Value {
                                        "value"
                                    } else {
                                        "constructor"
                                    })
                            };
                        d.diagnostics.push(diag.build());
                    }
                }
                ConstraintRef::Builtin { .. } => {}
            }
        }
    }
}
pub(super) fn collect(d: &mut Decls<'_>) {
    // 全頭部を先に置く。先に宣言した関数の制約と、後方の上位クラスも同じ AST で検査できる。
    for (module, ast) in d.asts.iter().enumerate() {
        for top in &ast.decls {
            if let Item::Trait(t) = &top.item
                && let Some(binding) = d.binding(t.id)
            {
                d.out.traits.insert(
                    binding,
                    TraitDef {
                        binding,
                        name: t.name.text.clone(),
                        module: ModuleId(u32::try_from(module).unwrap_or(u32::MAX)),
                        param_kind: kind(&t.param),
                        supers: t
                            .param
                            .constraints
                            .iter()
                            .filter_map(|c| {
                                if let ConstraintRef::Class(c) = c {
                                    d.reference(c.id)
                                } else {
                                    None
                                }
                            })
                            .collect(),
                        methods: t.methods.iter().filter_map(|m| d.binding(m.id)).collect(),
                    },
                );
            }
        }
    }
    for ast in d.asts {
        for top in &ast.decls {
            if let Item::Trait(t) = &top.item {
                collect_trait(d, t);
            }
        }
    }
    for (module, ast) in d.asts.iter().enumerate() {
        for top in &ast.decls {
            if let Item::Impl(i) = &top.item {
                collect_impl(d, i, ModuleId(u32::try_from(module).unwrap_or(u32::MAX)));
            }
        }
    }
}
fn collect_trait(d: &mut Decls<'_>, t: &TraitDecl) {
    let Some(class) = d.binding(t.id) else {
        return;
    };
    let before = d.diagnostics.len();
    let (scope, mut s) = d.parameters(
        std::slice::from_ref(&t.param),
        Scope::default(),
        scheme(vec![], unit()),
        false,
    );
    // 引数の宣言の制約は上位のクラスであり、メソッド自身が受け取る辞書は自己のクラス一つである
    // （実装プラン 10-05「型パラメータの番号」）。
    s.class_constraints = vec![ClassConstraint { param: 0, class }];
    d.scopes.insert(t.id, scope.clone());
    if t.methods.is_empty() {
        d.diagnostics.push(
            DiagBuilder::new(DiagCode::E0710)
                .arg("name", &t.name.text)
                .primary(t.name.span)
                .build(),
        );
    }
    let invalid = d.diagnostics.len() != before;
    for m in &t.methods {
        let Some(id) = d.binding(m.id) else {
            continue;
        };
        let before = d.diagnostics.len();
        let f = FnDecl {
            id: m.id,
            span: m.span,
            name: m.name.clone(),
            type_params: m.type_params.clone(),
            params: m.params.clone(),
            ret: m.ret.clone(),
            uses: m.uses.clone(),
            body: None,
        };
        let s = d.signature(&f, scope.clone(), s.clone());
        if before == d.diagnostics.len()
            && !s.params.iter().any(|t| has_param(t, 0))
            && !has_param(&s.ret, 0)
        {
            d.diagnostics.push(
                DiagBuilder::new(DiagCode::E0709)
                    .arg("name", &m.name.text)
                    .arg("trait_name", &t.name.text)
                    .primary(m.name.span)
                    .build(),
            );
        }
        d.out.decl_types.insert(id, s);
        if invalid || before != d.diagnostics.len() {
            d.invalid.insert(id);
        }
    }
    if before != d.diagnostics.len() {
        d.invalid.insert(class);
    }
}
fn collect_impl(d: &mut Decls<'_>, i: &ImplDecl, module: ModuleId) {
    let Some(class) = d.reference(i.class.id) else {
        return;
    };
    let Some(t) = d.out.traits.get(class).cloned() else {
        return;
    };
    let before = d.diagnostics.len();
    let (scope, s) = d.parameters(
        &i.type_params,
        Scope::default(),
        scheme(vec![], unit()),
        true,
    );
    d.scopes.insert(i.id, scope.clone());
    let target = match t.param_kind {
        ParamKind::Value => TypeArg::Ty(d.ty(&i.target, &scope)),
        ParamKind::Ctor { arity } => {
            let con = constructor(d, &i.target);
            if let Some((con, n, name)) = &con {
                if *n == 0 {
                    d.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0714)
                            .arg("name", name)
                            .arg("trait_name", &t.name)
                            .primary(i.target.span())
                            .help("constructor")
                            .build(),
                    );
                } else if *n != arity {
                    d.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0427)
                            .arg("name", name)
                            .arg("expected", n.to_string())
                            .arg("found", arity.to_string())
                            .primary(i.target.span())
                            .build(),
                    );
                }
                TypeArg::Head(TyHead::Con(*con))
            } else {
                let ty = d.ty(&i.target, &scope);
                d.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0712)
                        .arg("ty", show(d, &s, &ty))
                        .primary(i.target.span())
                        .help("form")
                        .build(),
                );
                // 具体的な型構成子のない誤りを、本物の Unit の実装として登録しない（ADR 0024）。
                TypeArg::Head(TyHead::Param(u32::MAX))
            }
        }
    };
    let target_con = match &target {
        TypeArg::Ty(Ty::Con(c, _)) | TypeArg::Head(TyHead::Con(c)) => *c,
        TypeArg::Ty(_) | TypeArg::Head(TyHead::Param(_)) => {
            TyCon::Builtin(crate::types::builtin::BuiltinTypeId::UNIT)
        }
    };
    let invalid = before != d.diagnostics.len() || d.invalid.contains(&class);
    let methods = t
        .methods
        .iter()
        .filter_map(|m| {
            i.fns
                .iter()
                .find(|f| d.reference(f.id) == Some(*m))
                .and_then(|f| d.binding(f.decl.id))
        })
        .collect();
    d.out.impls.insert(
        i.id,
        ImplDef {
            decl: i.id,
            module,
            class,
            target,
            target_con,
            type_params: s.type_params.clone(),
            class_constraints: s.class_constraints.clone(),
            methods,
            supers: vec![],
        },
    );
    for f in &i.fns {
        if let Some(id) = d.binding(f.decl.id) {
            let before = d.diagnostics.len();
            let sig = d.signature(&f.decl, scope.clone(), s.clone());
            d.out.decl_types.insert(id, sig);
            if invalid || before != d.diagnostics.len() {
                d.invalid.insert(id);
            }
        }
    }
}
fn constructor(d: &Decls<'_>, expr: &TypeExpr) -> Option<(TyCon, u32, String)> {
    if let TypeExpr::Paren(p) = expr {
        return constructor(d, &p.inner);
    }
    let TypeExpr::Named(t) = expr else {
        return None;
    };
    if !t.args.is_empty() {
        return None;
    }
    let id = d.reference(t.id)?;
    let b = d.resolved.bindings.get(id)?;
    if let BindingKind::BuiltinType(c) = b.kind {
        return Some((TyCon::Builtin(c), u32::from(c.def()?.arity), b.name.clone()));
    }
    if matches!(b.kind, BindingKind::Data | BindingKind::Record) {
        return Some((
            TyCon::Adt(id),
            u32::try_from(d.out.adts.get(id)?.type_params.len()).ok()?,
            b.name.clone(),
        ));
    }
    None
}
pub(super) fn has_param(t: &Ty, p: u32) -> bool {
    match t {
        Ty::Param(i) => *i == p,
        Ty::App(i, a) => *i == p || a.iter().any(|t| has_param(t, p)),
        Ty::Con(_, a) => a.iter().any(|t| has_param(t, p)),
        Ty::Fn(f) => f.params.iter().any(|t| has_param(t, p)) || has_param(&f.ret, p),
        Ty::Rigid { .. } => false,
    }
}
pub(super) fn show(d: &Decls<'_>, s: &Scheme, t: &Ty) -> String {
    let names: Vec<_> = s.type_params.iter().map(|p| p.name.clone()).collect();
    t.show(&TyNames {
        adts: &d.out.adts,
        effects: &d.out.effects,
        type_params: &names,
        effect_params: &s.effect_params,
    })
}
