//! 公開宣言の組み込みのエフェクトと外部コンポーネントを集計する（設計書 06-09「`benitoite package`」）。

use crate::syntax::ast::{
    Item, Module, Param, StrArg, TypeExpr, TypeParamDecl, TypeParamKind, UsesList,
};
use crate::types::builtin::BUILTIN_EFFECTS;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Default)]
pub(super) struct Summary {
    pub effects: BTreeSet<String>,
    pub components: BTreeMap<String, StrArg>,
}

struct Names {
    imports: BTreeMap<String, Vec<String>>,
    declared: BTreeSet<String>,
}

impl Summary {
    pub(super) fn collect(&mut self, module: &Module) {
        let imports: BTreeMap<_, _> = module
            .imports
            .iter()
            .filter_map(|decl| {
                let name = decl.alias.as_ref().or_else(|| decl.path.last())?;
                Some((
                    name.text.clone(),
                    decl.path
                        .iter()
                        .map(|part| part.text.clone())
                        .collect::<Vec<_>>(),
                ))
            })
            .collect();
        let names = Names {
            imports,
            declared: module
                .decls
                .iter()
                .filter_map(|decl| match &decl.item {
                    Item::Fn(d) => Some(&d.name),
                    Item::Const(d) => Some(&d.name),
                    Item::Data(d) => Some(&d.name),
                    Item::Alias(d) => Some(&d.name),
                    Item::ExternalType(d) => Some(&d.name),
                    Item::Record(d) => Some(&d.name),
                    Item::Trait(d) => Some(&d.name),
                    Item::Effect(d) => Some(&d.name),
                    Item::Impl(_) | Item::Error(_) => None,
                })
                .map(|name| name.text.clone())
                .collect(),
        };
        // ファイル宣言は直下の公開関数だけの契約に加わる。型の内部へは複写しない
        // （設計書 06-09「`benitoite package`」）。
        if module.decls.iter().any(|decl| {
            decl.public.is_some() && decl.package.is_none() && matches!(decl.item, Item::Fn(_))
        }) {
            self.uses(&names, &BTreeSet::new(), module.file_uses.as_ref());
        }
        for decl in &module.decls {
            // 非公開の外部宣言も実行対象になりうるので、コンポーネントの一覧には含める。
            for attr in &decl.attrs {
                if attr.name.text == "external"
                    && let Some(path) = attr.args.get(1)
                {
                    self.components.insert(path.value.clone(), path.clone());
                }
            }
            if decl.public.is_none() || decl.package.is_some() {
                continue;
            }
            match &decl.item {
                Item::Fn(function) => self.signature(
                    &names,
                    &function.type_params,
                    &function.params,
                    &function.ret,
                    function.uses.as_ref(),
                ),
                Item::Trait(trait_decl) => {
                    for method in &trait_decl.methods {
                        self.signature(
                            &names,
                            &method.type_params,
                            &method.params,
                            &method.ret,
                            method.uses.as_ref(),
                        );
                    }
                }
                Item::Alias(alias) => {
                    self.types(&names, &alias.type_params, None, std::iter::once(&alias.ty))
                }
                Item::Record(record) => self.types(
                    &names,
                    &record.type_params,
                    None,
                    record.fields.iter().map(|f| &f.ty),
                ),
                Item::Data(data) => self.types(
                    &names,
                    &data.type_params,
                    None,
                    data.variants.iter().flat_map(|variant| &variant.fields),
                ),
                Item::Const(_)
                | Item::Effect(_)
                | Item::Impl(_)
                | Item::ExternalType(_)
                | Item::Error(_) => {}
            }
        }
    }
    fn signature(
        &mut self,
        names: &Names,
        variables: &[TypeParamDecl],
        params: &[Param],
        ret: &TypeExpr,
        uses: Option<&UsesList>,
    ) {
        self.types(
            names,
            variables,
            uses,
            params
                .iter()
                .filter_map(|p| p.ty.as_ref())
                .chain(std::iter::once(ret)),
        );
    }
    fn types<'a>(
        &mut self,
        names: &Names,
        variables: &[TypeParamDecl],
        uses: Option<&UsesList>,
        types: impl Iterator<Item = &'a TypeExpr>,
    ) {
        let variables: BTreeSet<_> = variables
            .iter()
            .filter(|p| p.kind == TypeParamKind::Effect)
            .map(|p| p.name.text.as_str())
            .collect();
        self.uses(names, &variables, uses);
        let mut pending: Vec<_> = types.collect();
        while let Some(ty) = pending.pop() {
            match ty {
                TypeExpr::Named(ty) => pending.extend(&ty.args),
                TypeExpr::Paren(ty) => pending.push(&ty.inner),
                TypeExpr::Fn(ty) => {
                    self.uses(names, &variables, ty.uses.as_ref());
                    pending.extend(&ty.params);
                    pending.push(&ty.ret);
                }
                TypeExpr::Error(_) => {}
            }
        }
    }
    fn uses(&mut self, names: &Names, variables: &BTreeSet<&str>, uses: Option<&UsesList>) {
        let Some(uses) = uses else {
            return;
        };
        for effect in &uses.effects {
            let parts: Vec<_> = effect.path.iter().map(|p| p.text.as_str()).collect();
            let Some(first) = parts.first() else {
                continue;
            };
            if variables.contains(first) {
                continue;
            }
            // prelude の Log は同名の宣言や import に隠される。根からの参照は
            // Log の隠蔽には影響されない（設計書 06-09「`benitoite package`」）。
            let prelude_log = parts == ["Log"]
                && !names.declared.contains("Log")
                && !names.imports.contains_key("Log");
            let qualified_log = parts == ["Benitoite", "Log"]
                && !names.declared.contains("Benitoite")
                && !names.imports.contains_key("Benitoite");
            if prelude_log || qualified_log {
                self.effects.insert("Log".into());
                continue;
            }
            let full: Vec<_> = if parts == ["State"] || parts == ["IO", "All"] {
                std::iter::once("Benitoite")
                    .chain(parts.iter().copied())
                    .collect()
            } else if let Some(import) = names.imports.get(*first) {
                if names.declared.contains(*first) {
                    continue;
                }
                if !crate::prelude::STDLIB.iter().any(|source| {
                    std::iter::once("Benitoite")
                        .chain(source.unofficial.then_some("Unofficial"))
                        .chain(source.path.iter().copied())
                        .eq(import.iter().map(String::as_str))
                }) {
                    continue;
                }
                import
                    .iter()
                    .map(String::as_str)
                    .chain(parts.iter().skip(1).copied())
                    .collect()
            } else {
                continue;
            };
            // Log モジュール自身の短縮参照も、その公開エフェクトを表す。
            if full == ["Benitoite", "Unofficial", "Log"] {
                self.effects.insert("Log".into());
                continue;
            }
            if full.first() != Some(&"Benitoite") {
                continue;
            }
            let unofficial = full.get(1) == Some(&"Unofficial");
            let start = if unofficial { 2 } else { 1 };
            let module: Vec<_> = full
                .iter()
                .skip(start)
                .take(full.len().saturating_sub(start).saturating_sub(1))
                .copied()
                .collect();
            if let Some(def) = BUILTIN_EFFECTS.iter().find(|def| {
                def.module == module
                    && full.last() == Some(&def.name)
                    && if def.declared_in_source {
                        crate::prelude::STDLIB.iter().any(|source| {
                            source.path == def.module && source.unofficial == unofficial
                        })
                    } else {
                        !unofficial
                    }
            }) {
                let name = if def.module.is_empty() || def.module == ["Log"] {
                    def.name.to_owned()
                } else {
                    format!("{}.{}", def.module.last().copied().unwrap_or(""), def.name)
                };
                self.effects.insert(name);
            }
        }
    }
}
