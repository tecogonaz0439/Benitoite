//! 束縛の収集と検査ごとの状態（設計書 02-04「束縛と表」「解決の手順」）。

use std::collections::BTreeMap;

use crate::base::{BindingId, IdGen, ModuleId, NodeId, NodeMap, SourceTable, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, ReportKind, Severity};
use crate::modules::{ModuleKind, ModuleTable};
use crate::syntax::ast::*;
use crate::types::builtin::{BUILTIN_TYPES, BuiltinEffectId, BuiltinTypeId, find_builtin_effect};

use super::lookup::Ctx;
use super::{Binding, BindingKind, DeclSite, ResolveOutput};

type Names = BTreeMap<String, BindingId>;

pub(super) struct Resolver<'a> {
    pub(super) modules: &'a ModuleTable,
    pub(super) asts: &'a [Module],
    pub(super) sources: &'a SourceTable,
    pub(super) ids: &'a mut IdGen,
    pub(super) out: ResolveOutput,
    pub(super) top: BTreeMap<ModuleId, Names>,
    // None の取り込みは派生した未定義名の診断を抑える（実装プラン F06「import」）。
    pub(super) imported: BTreeMap<ModuleId, BTreeMap<String, Option<BindingId>>>,
    pub(super) prelude: Names,
    pub(super) members: BTreeMap<BindingId, Names>,
    pub(super) contexts: NodeMap<Ctx>,
    pub(super) insertion: BTreeMap<BindingId, Span>,
    pub(super) parent: BTreeMap<BindingId, NodeId>,
    pub(super) alias_edges: BTreeMap<BindingId, Vec<BindingId>>,
    pub(super) trait_edges: BTreeMap<BindingId, Vec<BindingId>>,
    pub(super) const_edges: BTreeMap<BindingId, Vec<BindingId>>,
    pub(super) contracts: Vec<(BindingId, BindingId, Span)>,
}

impl<'a> Resolver<'a> {
    pub(super) fn new(
        modules: &'a ModuleTable,
        asts: &'a [Module],
        sources: &'a SourceTable,
        ids: &'a mut IdGen,
    ) -> Self {
        Self {
            modules,
            asts,
            sources,
            ids,
            out: ResolveOutput::default(),
            top: BTreeMap::new(),
            imported: BTreeMap::new(),
            prelude: Names::new(),
            members: BTreeMap::new(),
            contexts: NodeMap::new(),
            insertion: BTreeMap::new(),
            parent: BTreeMap::new(),
            alias_edges: BTreeMap::new(),
            trait_edges: BTreeMap::new(),
            const_edges: BTreeMap::new(),
            contracts: Vec::new(),
        }
    }

    pub(super) fn ast(&self, module: ModuleId) -> Option<&'a Module> {
        self.asts.get(usize::try_from(module.0).ok()?)
    }

    pub(super) fn internal(&mut self, message: String) {
        self.out.diagnostics.push(Diagnostic {
            kind: ReportKind::Internal,
            severity: Severity::Error,
            code: None,
            message,
            primary: None,
            secondary: Vec::new(),
            notes: Vec::new(),
            helps: Vec::new(),
            trace: None,
            task_origins: Vec::new(),
            waiting: Vec::new(),
            backtrace: None,
        });
    }

    pub(super) fn index(&mut self, index: usize) -> u32 {
        match u32::try_from(index) {
            Ok(index) => index,
            Err(_) => {
                self.internal("declaration index exceeds u32".into());
                0
            }
        }
    }

    pub(super) fn bind(&mut self, binding: Binding) -> BindingId {
        let id = self.ids.binding();
        if let DeclSite::Node(node) = binding.decl {
            self.out.decls.insert(node, id);
        }
        self.out.bindings.insert(id, binding);
        id
    }

    pub(super) fn node_binding(
        &mut self,
        module: ModuleId,
        node: NodeId,
        name: &Name,
        kind: BindingKind,
        public: bool,
        deprecated: Option<String>,
    ) -> BindingId {
        self.bind(Binding {
            kind,
            name: name.text.clone(),
            module,
            decl: DeclSite::Node(node),
            span: Some(name.span),
            public,
            deprecated,
        })
    }

    fn table_binding(&mut self, module: ModuleId, name: &str, kind: BindingKind) -> BindingId {
        self.bind(Binding {
            kind,
            name: name.into(),
            module,
            decl: DeclSite::Table,
            span: None,
            public: true,
            deprecated: None,
        })
    }

    pub(super) fn duplicate(
        &mut self,
        code: DiagCode,
        name: &Name,
        earlier: BindingId,
        container: &str,
    ) {
        let mut d = DiagBuilder::new(code)
            .arg("name", name.text.clone())
            .arg("ty", container)
            .arg("trait_name", container)
            .primary(name.span);
        if let Some(span) = self.out.bindings.get(earlier).and_then(|b| b.span) {
            d = d.secondary(span, "first");
        }
        self.out.diagnostics.push(d.build());
    }

    fn add_top(&mut self, module: ModuleId, id: BindingId, name: &Name) {
        let earlier = self
            .top
            .get(&module)
            .and_then(|table| table.get(&name.text))
            .copied();
        if let Some(earlier) = earlier {
            let code = if name.text.starts_with(|c: char| c.is_ascii_uppercase()) {
                DiagCode::E0305
            } else {
                DiagCode::E0306
            };
            self.duplicate(code, name, earlier, "");
            return;
        }
        self.top
            .entry(module)
            .or_default()
            .insert(name.text.clone(), id);
        if self.out.bindings.get(id).is_some_and(|b| b.public) {
            self.out
                .exports
                .entry(module)
                .or_default()
                .insert(name.text.clone(), id);
        }
    }

    fn child(
        &mut self,
        owner: BindingId,
        id: BindingId,
        name: &Name,
        code: DiagCode,
        container: &str,
    ) {
        if let Some(earlier) = self
            .members
            .get(&owner)
            .and_then(|m| m.get(&name.text))
            .copied()
        {
            self.duplicate(code, name, earlier, container);
        } else {
            self.members
                .entry(owner)
                .or_default()
                .insert(name.text.clone(), id);
        }
    }

    pub(super) fn collect(&mut self) {
        let Some(first) = self
            .modules
            .iter()
            .find(|m| m.kind == ModuleKind::Prelude)
            .map(|m| m.id)
        else {
            self.internal("resolver requires a prelude module".into());
            return;
        };
        for (name, kind) in [
            ("Benitoite", BindingKind::NamespaceRoot),
            ("Unit", BindingKind::BuiltinType(BuiltinTypeId::UNIT)),
            ("State", BindingKind::BuiltinEffect(BuiltinEffectId::STATE)),
        ] {
            let id = self.table_binding(first, name, kind);
            self.prelude.insert(name.into(), id);
            if name != "Benitoite" {
                self.out
                    .stdlib_names
                    .insert(format!("Benitoite.{name}"), id);
            }
        }
        for module in self
            .modules
            .iter()
            .filter(|m| m.kind == ModuleKind::Prelude)
        {
            if let Some(name) = module.name.0.last() {
                let id = self.table_binding(module.id, name, BindingKind::Module(module.id));
                self.prelude.insert(name.clone(), id);
            }
        }
        for module in self.modules.iter() {
            self.out.exports.entry(module.id).or_default();
            let path: Vec<&str> = module.name.0.iter().skip(1).map(String::as_str).collect();
            if matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib) {
                for (index, def) in BUILTIN_TYPES
                    .iter()
                    .enumerate()
                    .filter(|(_, d)| !d.module.is_empty() && d.module == path)
                {
                    let Ok(index) = u16::try_from(index) else {
                        self.internal("builtin type index exceeds u16".into());
                        continue;
                    };
                    let id = self.table_binding(
                        module.id,
                        def.name,
                        BindingKind::BuiltinType(BuiltinTypeId(index)),
                    );
                    self.top
                        .entry(module.id)
                        .or_default()
                        .insert(def.name.into(), id);
                    self.out
                        .exports
                        .entry(module.id)
                        .or_default()
                        .insert(def.name.into(), id);
                }
                if path == ["IO"] {
                    let id = self.table_binding(
                        module.id,
                        "All",
                        BindingKind::BuiltinEffect(BuiltinEffectId::IO_ALL),
                    );
                    self.top
                        .entry(module.id)
                        .or_default()
                        .insert("All".into(), id);
                    self.out
                        .exports
                        .entry(module.id)
                        .or_default()
                        .insert("All".into(), id);
                }
            }
            let Some(ast) = self.ast(module.id) else {
                continue;
            };
            for top in &ast.decls {
                self.collect_decl(module.id, top);
            }
        }
        // 索引は公開したトップレベルとその中の名前を指す。import の別名を含めない（02-04「標準ライブラリのソースの持ち方」）。
        for module in self
            .modules
            .iter()
            .filter(|m| matches!(m.kind, ModuleKind::Prelude | ModuleKind::Stdlib))
        {
            let prefix = module.name.dotted();
            if let Some(exports) = self.out.exports.get(&module.id) {
                for (name, id) in exports {
                    self.out
                        .stdlib_names
                        .insert(format!("{prefix}.{name}"), *id);
                    if let Some(children) = self.members.get(id) {
                        for (child, cid) in children {
                            let full = if module.name.0.last() == Some(name) {
                                format!("{prefix}.{child}")
                            } else {
                                format!("{prefix}.{name}.{child}")
                            };
                            self.out.stdlib_names.insert(full, *cid);
                        }
                    }
                }
            }
        }
    }

    fn collect_decl(&mut self, module: ModuleId, top: &TopDecl) {
        let public = top.public.is_some();
        let deprecated = top
            .attrs
            .iter()
            .find(|a| a.name.text == "deprecated")
            .and_then(|a| a.args.first())
            .map(|a| a.value.clone());
        let (name, kind, start) = match &top.item {
            Item::Fn(d) => {
                let mut kind = BindingKind::Fn;
                if let Some(attr) = top.attrs.iter().find(|a| a.name.text == "builtin")
                    && let Some(name) = attr.args.first()
                {
                    if let Some(id) = crate::builtins::lookup_builtin(&name.value) {
                        kind = BindingKind::BuiltinFn(id);
                    } else {
                        self.internal(format!("unknown builtin in stdlib source: {}", name.value));
                    }
                }
                (&d.name, kind, d.span)
            }
            Item::Const(d) => (&d.name, BindingKind::Const, d.span),
            Item::Data(d) => (&d.name, BindingKind::Data, d.span),
            Item::Alias(d) => (&d.name, BindingKind::Alias, d.span),
            Item::Record(d) => (&d.name, BindingKind::Record, d.span),
            Item::Trait(d) => (&d.name, BindingKind::Trait, d.span),
            Item::Effect(d) => (&d.name, BindingKind::Effect, d.span),
            Item::Impl(d) => {
                let mut seen = BTreeMap::new();
                for f in &d.fns {
                    let id = self.node_binding(
                        module,
                        f.decl.id,
                        &f.decl.name,
                        BindingKind::ImplFn { impl_decl: d.id },
                        false,
                        None,
                    );
                    if let Some(first) = seen.insert(f.decl.name.text.clone(), id) {
                        self.duplicate(DiagCode::E0306, &f.decl.name, first, "");
                    }
                    self.parent.insert(id, d.id);
                }
                return;
            }
            Item::Error(_) => return,
        };
        let owner = top.item.id();
        let id = self.node_binding(module, owner, name, kind, public, deprecated.clone());
        self.parent.insert(id, owner);
        self.insertion.insert(
            id,
            Span {
                end: start.start,
                ..start
            },
        );
        if name.text == "Benitoite" {
            self.out.diagnostics.push(
                DiagBuilder::new(DiagCode::E0325)
                    .primary(name.span)
                    .note("reserved")
                    .build(),
            );
        } else {
            self.add_top(module, id, name);
        }
        if kind == BindingKind::Fn
            && name.text == "main"
            && self
                .modules
                .get(module)
                .is_some_and(|m| m.kind == ModuleKind::Entry)
        {
            self.out.main = Some(id);
        }
        let mut children = Vec::new();
        match &top.item {
            Item::Data(d) => {
                for (index, v) in d.variants.iter().enumerate() {
                    let tag = self.index(index);
                    let child = self.node_binding(
                        module,
                        v.id,
                        &v.name,
                        BindingKind::Ctor { data: id, tag },
                        public,
                        deprecated.clone(),
                    );
                    self.child(id, child, &v.name, DiagCode::E0309, &name.text);
                    children.push(child);
                }
            }
            Item::Record(d) => {
                for (index, f) in d.fields.iter().enumerate() {
                    let index = self.index(index);
                    let child = self.node_binding(
                        module,
                        f.id,
                        &f.name,
                        BindingKind::Field { record: id, index },
                        public,
                        deprecated.clone(),
                    );
                    self.child(id, child, &f.name, DiagCode::E0327, &name.text);
                    children.push(child);
                }
            }
            Item::Trait(d) => {
                for (index, m) in d.methods.iter().enumerate() {
                    let index = self.index(index);
                    let child = self.node_binding(
                        module,
                        m.id,
                        &m.name,
                        BindingKind::Method { trait_: id, index },
                        public,
                        deprecated.clone(),
                    );
                    self.child(id, child, &m.name, DiagCode::E0328, &name.text);
                    children.push(child);
                }
            }
            Item::Effect(d) => {
                if self.modules.get(module).and_then(|m| m.name.0.last()) == Some(&name.text) {
                    self.out.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0326)
                            .arg("name", name.text.clone())
                            .primary(name.span)
                            .help("rename")
                            .build(),
                    );
                }
                let info = self.modules.get(module);
                let path: Vec<&str> = info
                    .into_iter()
                    .flat_map(|m| m.name.0.iter().skip(1))
                    .map(String::as_str)
                    .collect();
                let builtin = info
                    .is_some_and(|m| matches!(m.kind, ModuleKind::Prelude | ModuleKind::Stdlib))
                    && find_builtin_effect(&path, &name.text).is_some();
                for (index, op) in d.ops.iter().enumerate() {
                    let index = self.index(index);
                    let child = self.node_binding(
                        module,
                        op.id,
                        &op.name,
                        BindingKind::Op { effect: id, index },
                        public,
                        deprecated.clone(),
                    );
                    self.add_top(module, child, &op.name);
                    children.push(child);
                    if builtin {
                        let full = format!("Benitoite.{}.{}", path.join("."), op.name.text);
                        if let Some(builtin) = crate::builtins::lookup_builtin(&full) {
                            self.out.builtin_ops.insert(child, builtin);
                        } else {
                            self.internal(format!(
                                "unknown effect operation in stdlib source: {full}"
                            ));
                        }
                    }
                }
            }
            Item::Fn(_) | Item::Const(_) | Item::Alias(_) | Item::Impl(_) | Item::Error(_) => {}
        }
        for child in children {
            self.parent.insert(child, owner);
            self.insertion.insert(
                child,
                Span {
                    end: start.start,
                    ..start
                },
            );
        }
    }
}
