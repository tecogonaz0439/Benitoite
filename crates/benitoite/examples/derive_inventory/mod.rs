//! JSON への変換は通常の型の表を読む。型の解決は行わない（設計書 03-06「外部生成の宣言情報」）。
pub mod config;
mod ranges;
mod schema;
pub use ranges::to_string;
pub mod text;
use benitoite::{
    base::{BindingId, Span},
    modules::{DirEntryName, EntrySpec, ModuleFs, RealFs},
    pipeline::declarations::{DeclarationInventory, collect_declarations},
    resolve::{BindingKind, DeclSite},
    syntax::ast::{self, Item, RecordDecl},
    types::{Scheme, Ty, TyCon, TyNames},
};
use config::{Error, string};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    io,
    path::{Component, Path, PathBuf},
};

pub fn hash(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

// 対象を同じ根から import し、入口だけに特有の空のモジュール名を target に使わない。
struct InventoryFs {
    entry: PathBuf,
    bytes: Vec<u8>,
}
impl ModuleFs for InventoryFs {
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
        if path == self.entry {
            Ok(self.bytes.clone())
        } else {
            RealFs.read_file(path)
        }
    }
    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
        if path == self.entry {
            Ok(path.to_path_buf())
        } else {
            RealFs.canonicalize(path)
        }
    }
    fn list_dir(&self, path: &Path) -> io::Result<Vec<DirEntryName>> {
        RealFs.list_dir(path)
    }
}
struct Output<'a> {
    inv: &'a DeclarationInventory,
    root: &'a Path,
    bindings: benitoite::base::BindingMap<benitoite::resolve::Binding>,
    adts: benitoite::types::AdtTable,
    effects: benitoite::base::BindingMap<benitoite::types::EffectDef>,
}
impl Output<'_> {
    fn name(&self, id: BindingId) -> String {
        let Some(b) = self.inv.resolved.bindings.get(id) else {
            return String::new();
        };
        let module = self
            .inv
            .modules
            .get(b.module)
            .map(|m| m.name.dotted())
            .unwrap_or_default();
        if module.is_empty() {
            b.name.clone()
        } else {
            format!("{module}.{}", b.name)
        }
    }
    fn path(&self, path: &str) -> String {
        Path::new(path)
            .strip_prefix(self.root)
            .unwrap_or(Path::new(path))
            .to_string_lossy()
            .into_owned()
    }
    fn span(&self, span: Span) -> Value {
        let path = self.inv.sources.get(span.file).map(|s| self.path(s.name()));
        json!({"path":path,"start":span.start.0,"end":span.end.0})
    }
    fn original(&self, span: Span) -> String {
        self.inv
            .sources
            .get(span.file)
            .and_then(|s| {
                s.text()
                    .get(usize::try_from(span.start.0).ok()?..usize::try_from(span.end.0).ok()?)
            })
            .map(|b| String::from_utf8_lossy(b).into_owned())
            .unwrap_or_default()
    }
    // 表示名も解決名へ置き換えるので、別モジュールの同名型をハッシュで混同しない。
    fn show(&self, ty: &Ty, scheme: &Scheme) -> String {
        ty.show(&TyNames {
            bindings: &self.bindings,
            adts: &self.adts,
            effects: &self.effects,
            type_params: &scheme
                .type_params
                .iter()
                .map(|p| p.name.clone())
                .collect::<Vec<_>>(),
            effect_params: &scheme.effect_params,
        })
    }
    fn dependencies(&self, ty: &Ty, out: &mut Vec<String>) {
        match ty {
            Ty::Con(con, args, _) => {
                if let TyCon::Adt(id) | TyCon::External(id) = con {
                    let name = self.name(*id);
                    if !out.contains(&name) {
                        out.push(name);
                    }
                }
                for t in args {
                    self.dependencies(t, out);
                }
            }
            Ty::Fn(f) => {
                for t in f
                    .params
                    .iter()
                    .chain(std::iter::once(&f.ret))
                    .chain(&f.effects.failures)
                {
                    self.dependencies(t, out);
                }
            }
            Ty::App(_, args) => {
                for t in args {
                    self.dependencies(t, out);
                }
            }
            Ty::Param(_) | Ty::Rigid { .. } => {}
        }
    }
    fn record(&self, record: &RecordDecl, id: BindingId) -> Result<Value, Error> {
        let adt = self
            .inv
            .types
            .adts
            .get(id)
            .ok_or(text::MISSING_RECORD_TYPE)?;
        let scheme = self
            .inv
            .types
            .decl_types
            .get(id)
            .ok_or(text::MISSING_RECORD_SIGNATURE)?;
        let binding = self
            .inv
            .resolved
            .bindings
            .get(id)
            .ok_or(text::MISSING_RECORD_BINDING)?;
        let mut deps = vec![];
        let types = &adt
            .ctors
            .first()
            .ok_or(text::MISSING_RECORD_CONSTRUCTOR)?
            .fields;
        let fields = record.fields.iter().zip(types).map(|(f,t)| {
            self.dependencies(t,&mut deps);
            Ok(json!({"name":f.name.text,"span":self.span(f.span),"typeSpan":self.span(f.ty.span()),"type":self.ty(t,scheme,&benitoite::types::signature::RangeSignature::default())?,"metadata":{"original":self.original(f.ty.span()),"resolved":self.show(t,scheme),"span":self.span(f.ty.span())}}))
        }).collect::<Result<Vec<_>, Error>>()?;
        Ok(
            json!({"type":self.name(id),"module":self.inv.modules.get(binding.module).map(|m|m.name.dotted()),
            "name":record.name.text,"span":self.span(record.span),"public":binding.public,"package":binding.package,
            "visibility":visibility(binding)?,"opaque":binding.opaque,"canConstruct":true,"canInspect":true,
            "typeParams":type_params(&scheme.type_params),"fields":fields,"dependencies":deps}),
        )
    }
    fn function(&self, f: &benitoite::syntax::ast::FnDecl, id: BindingId) -> Result<Value, Error> {
        let s = self
            .inv
            .types
            .decl_types
            .get(id)
            .ok_or(text::MISSING_FUNCTION_SIGNATURE)?;
        let b = self
            .inv
            .resolved
            .bindings
            .get(id)
            .ok_or(text::MISSING_FUNCTION_BINDING)?;
        Ok(
            json!({"name":self.name(id),"span":self.span(f.span),"public":b.public,"package":b.package,
            "visibility":visibility(b)?,"signature":self.signature(s,id)?}),
        )
    }
}

pub fn inventory(root: &Path, config: &Value, config_bytes: &[u8]) -> Result<Value, Error> {
    let root = root.canonicalize()?;
    let targets = config
        .get("targets")
        .and_then(Value::as_array)
        .ok_or(text::EXPECTED_TARGETS)?;
    let mut imports = BTreeSet::new();
    let mut target_paths = BTreeMap::new();
    for target in targets {
        let source = Path::new(string(target, "source")?);
        if source
            .components()
            .any(|p| !matches!(p, Component::Normal(_)))
        {
            return Err(text::SOURCE_MUST_BE_RELATIVE_TO_ROOT.into());
        }
        let path = root.join(source).canonicalize()?;
        if !path.starts_with(&root) {
            return Err(text::SOURCE_ESCAPES_ROOT.into());
        }
        let ty = string(target, "type")?;
        let (module, _) = ty
            .rsplit_once('.')
            .ok_or(text::TYPE_MUST_INCLUDE_ITS_MODULE_NAME)?;
        // 名前は import の構文として解析する前に区切りを検査する。
        if module
            .split('.')
            .any(|p| p.is_empty() || !p.chars().all(|c| c.is_alphanumeric() || c == '_'))
        {
            return Err(text::INVALID_MODULE_NAME.into());
        }
        if target.get("json").is_some() {
            imports.insert("Benitoite.Unofficial.Json.Codec".to_owned());
        }
        if target.get("property").is_some() {
            imports.insert("Benitoite.Unofficial.Test.Property".to_owned());
        }
        if ["show", "order"]
            .iter()
            .any(|key| target.get(*key).and_then(Value::as_bool) == Some(true))
        {
            imports.insert("Benitoite.Trait".to_owned());
        }
        imports.insert(module.to_owned());
        target_paths.insert(ty.to_owned(), path);
        if let Some(fields) = target.get("fields").and_then(Value::as_object) {
            for name in fields
                .values()
                .filter_map(Value::as_object)
                .flat_map(|f| f.values())
            {
                let (module, _) = name
                    .as_str()
                    .and_then(|n| n.rsplit_once('.'))
                    .ok_or(text::CUSTOM_FUNCTIONS_MUST_HAVE_QUALIFIED_NAMES)?;
                if module
                    .split('.')
                    .any(|p| p.is_empty() || !p.chars().all(|c| c.is_alphanumeric() || c == '_'))
                {
                    return Err(text::INVALID_MODULE_NAME.into());
                }
                imports.insert(module.to_owned());
            }
        }
    }
    let entry_path = root.join(".benitoite-derive-inventory.bnt");
    let bytes = imports
        .iter()
        .enumerate()
        .map(|(i, m)| format!("import {m} as DeriveInventory{i}\n"))
        .collect::<String>()
        .into_bytes();
    let entry = EntrySpec {
        path: entry_path.clone(),
        display_name: entry_path.to_string_lossy().into_owned(),
        root: root.clone(),
    };
    let result = collect_declarations(
        &entry,
        &InventoryFs {
            entry: entry_path,
            bytes,
        },
    );
    let inv = result
        .inventory
        .ok_or_else(|| text::declaration_failure(&result.diagnostics))?;
    let mut out = Output {
        inv: &inv,
        root: &root,
        bindings: inv.resolved.bindings.clone(),
        adts: inv.types.adts.clone(),
        effects: inv.types.effects.clone(),
    };
    for (id, b) in inv.resolved.bindings.iter() {
        let mut b = b.clone();
        b.name = out.name(id);
        out.bindings.insert(id, b);
    }
    for (id, a) in inv.types.adts.adts.iter() {
        let mut a = a.clone();
        a.name = out.name(id);
        out.adts.adts.insert(id, a);
    }
    for (id, e) in inv.types.effects.iter() {
        let mut e = e.clone();
        e.display_name = out.name(id);
        out.effects.insert(id, e);
    }
    // import の表から公開の綴りと解決名の対応を得る。非公式の名前空間も
    // 独自の書き換え規則で解決せず、通常の読み込みの結果に従う。
    let entry_module = inv
        .modules
        .iter()
        .find(|m| m.id.file().0 == 0)
        .ok_or(text::MISSING_ENTRY_MODULE)?;
    let requested_modules = inv
        .asts
        .iter()
        .find(|a| a.file.0 == 0)
        .into_iter()
        .flat_map(|a| &a.imports)
        .filter_map(|i| {
            let target = entry_module
                .imports
                .iter()
                .find(|l| l.decl == i.id)?
                .target?;
            Some((
                i.path
                    .iter()
                    .map(|p| p.text.as_str())
                    .collect::<Vec<_>>()
                    .join("."),
                inv.modules.get(target)?.name.dotted(),
            ))
        })
        .collect::<BTreeMap<_, _>>();
    let mut records = BTreeMap::new();
    let mut functions = BTreeMap::new();
    let (types, classes, implementations) = out.declaration_tables()?;
    for ast in &inv.asts {
        for top in &ast.decls {
            let Some(id) = inv.resolved.decls.get(top.item.id()).copied() else {
                continue;
            };
            match &top.item {
                Item::Record(r) => {
                    records.insert(out.name(id), out.record(r, id)?);
                }
                Item::Fn(f) => {
                    functions.insert(out.name(id), out.function(f, id)?);
                }
                Item::Data(_)
                | Item::Const(_)
                | Item::Alias(_)
                | Item::Trait(_)
                | Item::Impl(_)
                | Item::Effect(_)
                | Item::ExternalType(_)
                | Item::Error(_) => {}
            }
        }
    }
    let mut rows = vec![];
    for target in targets {
        let name = string(target, "type")?;
        if types.get(name).is_some_and(|t| {
            t.get("opaque") == Some(&Value::Bool(true))
                && t.get("kind").and_then(Value::as_str) == Some("data")
        }) {
            return Err(text::OPAQUE_TARGET.into());
        }
        let mut record = records
            .get(name)
            .cloned()
            .ok_or_else(|| text::not_record(name))?;
        let source = record
            .pointer("/span/path")
            .and_then(Value::as_str)
            .ok_or(text::MISSING_SOURCE)?;
        if Some(&root.join(source).canonicalize()?) != target_paths.get(name) {
            return Err(text::TARGET_SOURCE_DOES_NOT_MATCH_DECLARATION.into());
        }
        let fields = record
            .get("fields")
            .and_then(Value::as_array)
            .ok_or(text::MISSING_FIELDS)?;
        let names = fields
            .iter()
            .filter_map(|f| f.get("name").and_then(Value::as_str))
            .collect::<BTreeSet<_>>();
        for mapping in [target.get("fields"), target.pointer("/json/keys")]
            .into_iter()
            .flatten()
        {
            for key in mapping
                .as_object()
                .ok_or(text::EXPECTED_FIELD_MAPPING)?
                .keys()
            {
                if !names.contains(key.as_str()) {
                    return Err(text::unknown_field(key).into());
                }
            }
        }
        let mut keys = BTreeSet::new();
        for name in &names {
            let key = target
                .get("json")
                .and_then(|j| j.get("keys"))
                .and_then(|k| k.get(*name))
                .and_then(Value::as_str)
                .unwrap_or(name);
            if !keys.insert(key) {
                return Err(text::DUPLICATE_JSON_FIELD_KEY.into());
            }
        }
        let mut custom = BTreeMap::new();
        if let Some(fields) = target.get("fields").and_then(Value::as_object) {
            for field in fields.values() {
                for name in field
                    .as_object()
                    .ok_or(text::EXPECTED_FIELD_SETTINGS)?
                    .values()
                {
                    let name = name.as_str().ok_or(text::EXPECTED_CUSTOM_FUNCTION_NAME)?;
                    let (module, local) = name
                        .rsplit_once('.')
                        .ok_or(text::CUSTOM_FUNCTIONS_MUST_HAVE_QUALIFIED_NAMES)?;
                    let module = requested_modules
                        .get(module)
                        .ok_or(text::MISSING_IMPORTED_MODULE)?;
                    let resolved_name = format!("{module}.{local}");
                    let function = functions
                        .get(&resolved_name)
                        .ok_or_else(|| text::unknown_function(name))?;
                    let same_module =
                        Some(module.as_str()) == record.get("module").and_then(Value::as_str);
                    if !same_module && function.get("public").and_then(Value::as_bool) != Some(true)
                    {
                        return Err(text::CUSTOM_FUNCTION_IS_NOT_PUBLIC.into());
                    }
                    custom.insert(name.to_owned(), function.clone());
                }
            }
        }
        let object = record.as_object_mut().ok_or(text::EXPECTED_AN_OBJECT)?;
        object.insert("source".into(), json!(string(target, "source")?));
        object.insert("region".into(), json!(string(target, "region")?));
        object.insert("config".into(), target.clone());
        object.insert("customFunctions".into(), json!(custom));
        rows.push(record);
    }
    let inputs = inv.files.iter().filter(|f| f.path != entry.path)
        .map(|f|json!({"path":out.path(&f.path.to_string_lossy()),"sha256":hash(&f.bytes),"kind":"file"}))
        .chain(inv.sources.iter().filter(|(_,s)| s.kind() == benitoite::base::SourceKind::Prelude)
        .map(|(_,s)|json!({"path":s.name(),"sha256":hash(s.text()),"kind":"embedded"}))).collect::<Vec<_>>();
    let modules = inv.modules.iter().filter(|m|m.id.file().0 != 0).map(|m| {
        let ast = inv.asts.iter().find(|a|a.file == m.id.file());
        // 生成の import はモジュールの説明と言語・依存の宣言の後へ置く。
        let preamble_end = ast.map(|a| {
            a.header.iter().map(|h| match h {
                ast::HeaderItem::Language(h) => h.span.end.0,
                ast::HeaderItem::Dependency(h) | ast::HeaderItem::Package(h) => h.span.end.0,
            }).chain(a.doc.iter().map(|d| d.span.end.0)).max().unwrap_or(0)
        }).unwrap_or(0);
        let file_uses = ast.and_then(|a| a.file_uses.as_ref());
        let imports = ast.into_iter().flat_map(|a|&a.imports).map(|i| {
            let target = m.imports.iter().find(|link|link.decl==i.id)
                .and_then(|link|link.target).and_then(|id|inv.modules.get(id));
            json!({"alias":i.alias.as_ref().or_else(||i.path.last()).map(|n|&n.text),
                "module":target.map(|m|m.name.dotted()),"written":i.path.iter().map(|p|p.text.as_str()).collect::<Vec<_>>().join("."),"span":out.span(i.span)})
        }).collect::<Vec<_>>();
        let import_path = if matches!(m.kind,benitoite::modules::ModuleKind::Stdlib | benitoite::modules::ModuleKind::Prelude) {
                benitoite::prelude::STDLIB.iter().find(|s|s.path.iter().copied().eq(m.name.0.iter().skip(1).map(String::as_str)))
                    .map(|s|format!("Benitoite{}.{}",if s.unofficial {".Unofficial"} else {""},s.path.join(".")))
                    .unwrap_or_else(||m.name.dotted())
            } else {m.name.dotted()};
            json!({"name":m.name.dotted(),"importPath":import_path,"path":inv.sources.get(m.id.file()).map(|s|out.path(s.name())),"imports":imports,"preambleEnd":preamble_end,
                "fileUses":file_uses.map(|u|json!({"text":out.original(u.span),"span":out.span(u.span)})),
                "importInsertLimit":file_uses.map(|u|u.span.start.0)})
    }).collect::<Vec<_>>();
    let top_level = inv
        .asts
        .iter()
        .flat_map(|a| {
            a.decls
                .iter()
                .map(|d| d.item.id())
                .chain(a.imports.iter().map(|i| i.id))
        })
        .collect::<BTreeSet<_>>();
    for (_, b) in inv.resolved.bindings.iter() {
        visibility(b)?;
    }
    let declarations = inv.resolved.bindings.iter().filter(|(_,b)|matches!(b.decl,DeclSite::Node(_)) && !matches!(b.kind,BindingKind::Local(_) | BindingKind::TypeParam{..} | BindingKind::EffectVar{..})).map(|(id,b)|json!({"name":out.name(id),"module":inv.modules.get(b.module).map(|m|m.name.dotted()),"topLevel":matches!(b.decl,DeclSite::Node(node) if top_level.contains(&node)),"kind":out.declaration_kind(b.kind),"public":b.public,"package":b.package,"visibility":visibility(b).ok(),"span":b.span.map(|s|out.span(s))})).collect::<Vec<_>>();
    Ok(
        json!({"version":4,"types":types,"classes":classes,"implementations":implementations,"configSha256":hash(config_bytes),"targets":rows,"records":records,"functions":functions,"declarations":declarations,"modules":modules,"inputs":inputs}),
    )
}

fn binding_kind(kind: BindingKind) -> &'static str {
    match kind {
        BindingKind::Fn | BindingKind::BuiltinFn(_) => "function",
        BindingKind::ImplFn { .. } => "implementationFunction",
        BindingKind::Const => "constant",
        BindingKind::Data => "data",
        BindingKind::BuiltinType(_) => "builtinType",
        BindingKind::Alias => "alias",
        BindingKind::ExternalType => "externalType",
        BindingKind::Record => "record",
        BindingKind::Field { .. } => "field",
        BindingKind::Ctor { .. } => "constructor",
        BindingKind::Trait => "trait",
        BindingKind::Method { .. } => "method",
        BindingKind::Effect | BindingKind::BuiltinEffect(_) => "effect",
        BindingKind::Op { .. } => "operation",
        BindingKind::Module(_) => "module",
        BindingKind::NamespaceRoot => "namespace",
        BindingKind::TypeParam { .. } => "typeParameter",
        BindingKind::EffectVar { .. } => "effectParameter",
        BindingKind::Local(_) => "local",
    }
}

fn visibility(b: &benitoite::resolve::Binding) -> Result<&'static str, Error> {
    match (b.public, b.package) {
        (true, false) => Ok("public"),
        (false, true) => Ok("package"),
        (false, false) => Ok("private"),
        (true, true) => Err(text::INVALID_SCHEMA.into()),
    }
}
fn kind(k: benitoite::types::ParamKind) -> Value {
    match k {
        benitoite::types::ParamKind::Value => json!({"tag":"value"}),
        benitoite::types::ParamKind::Ctor { arity } => json!({"tag":"constructor","arity":arity}),
    }
}
fn type_params(ps: &[benitoite::types::TypeParamInfo]) -> Vec<Value> {
    ps.iter().map(|p|json!({"name":p.name,"kind":kind(p.kind),"builtin":p.builtin.map(|b|match b {
        benitoite::types::BuiltinConstraint::Equality => "equality", benitoite::types::BuiltinConstraint::Key => "key",
        benitoite::types::BuiltinConstraint::Ordered => "ordered" })})).collect()
}

impl Output<'_> {
    fn declaration_kind(&self, k: BindingKind) -> &'static str {
        if let BindingKind::Module(id) = k
            && let Some(m) = self
                .inv
                .modules
                .get(id)
                .filter(|m| m.kind == benitoite::modules::ModuleKind::Stdlib)
        {
            match m.name.dotted().as_str() {
                "Benitoite.StringBuilder" => return "stringBuilder",
                "Benitoite.ListBuilder" => return "listBuilder",
                "Benitoite.BytesBuilder" => return "bytesBuilder",
                _ => {}
            }
        }
        binding_kind(k)
    }
}
