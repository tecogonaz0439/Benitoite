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
                    &imports,
                    &function.type_params,
                    &function.params,
                    &function.ret,
                    function.uses.as_ref(),
                ),
                Item::Trait(trait_decl) => {
                    for method in &trait_decl.methods {
                        self.signature(
                            &imports,
                            &method.type_params,
                            &method.params,
                            &method.ret,
                            method.uses.as_ref(),
                        );
                    }
                }
                Item::Alias(alias) => self.types(
                    &imports,
                    &alias.type_params,
                    None,
                    std::iter::once(&alias.ty),
                ),
                Item::Record(record) => self.types(
                    &imports,
                    &record.type_params,
                    None,
                    record.fields.iter().map(|f| &f.ty),
                ),
                Item::Data(data) => self.types(
                    &imports,
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
        imports: &BTreeMap<String, Vec<String>>,
        variables: &[TypeParamDecl],
        params: &[Param],
        ret: &TypeExpr,
        uses: Option<&UsesList>,
    ) {
        self.types(
            imports,
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
        imports: &BTreeMap<String, Vec<String>>,
        variables: &[TypeParamDecl],
        uses: Option<&UsesList>,
        types: impl Iterator<Item = &'a TypeExpr>,
    ) {
        let variables: BTreeSet<_> = variables
            .iter()
            .filter(|p| p.kind == TypeParamKind::Effect)
            .map(|p| p.name.text.as_str())
            .collect();
        self.uses(imports, &variables, uses);
        let mut pending: Vec<_> = types.collect();
        while let Some(ty) = pending.pop() {
            match ty {
                TypeExpr::Named(ty) => pending.extend(&ty.args),
                TypeExpr::Paren(ty) => pending.push(&ty.inner),
                TypeExpr::Fn(ty) => {
                    self.uses(imports, &variables, ty.uses.as_ref());
                    pending.extend(&ty.params);
                    pending.push(&ty.ret);
                }
                TypeExpr::Error(_) => {}
            }
        }
    }
    fn uses(
        &mut self,
        imports: &BTreeMap<String, Vec<String>>,
        variables: &BTreeSet<&str>,
        uses: Option<&UsesList>,
    ) {
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
            let full: Vec<_> = if parts == ["State"] || parts == ["IO", "All"] {
                std::iter::once("Benitoite")
                    .chain(parts.iter().copied())
                    .collect()
            } else if let Some(import) = imports.get(*first) {
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
                let name = if def.module.is_empty() {
                    def.name.to_owned()
                } else {
                    format!("{}.{}", def.module.last().copied().unwrap_or(""), def.name)
                };
                self.effects.insert(name);
            }
        }
    }
}
