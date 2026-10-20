//! 型検査の後で外部の関数の宣言を照合する（設計書 03-10「照合」）。

use super::types::DeclPlan;
use super::{ComponentSource, ExternalDecl, ExternalSpec, path, text, types};
use crate::base::{SourceTable, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::modules::{EntrySpec, ModuleFs, ModuleKind, ModuleTable};
use crate::resolve::ResolveOutput;
use crate::syntax::ast::{FnDecl, HeaderItem, Item, Module};
use crate::typeck::TypeckOutput;
use crate::types::{Ty, TyNames};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use wasmtime::{
    Engine,
    component::{Component, types::ComponentItem},
};

/// バイト列の検証と取り込みの検査の失敗。宣言ごとの位置は呼び出し側が添える。
#[derive(Clone, Debug)]
pub(crate) enum ComponentError {
    NotWasm,
    Core,
    Invalid(String),
    Imports {
        count: usize,
        names: Vec<String>,
        wasi: bool,
    },
}

/// 検査とパッケージの報告で共有する、コンポーネントの検証と純粋性の判定。
pub(crate) fn check_component(engine: &Engine, bytes: &[u8]) -> Result<Component, ComponentError> {
    check_component_counted(engine, bytes, &mut 0)
}
fn check_component_counted(
    engine: &Engine,
    bytes: &[u8],
    compilations: &mut u64,
) -> Result<Component, ComponentError> {
    if !bytes.starts_with(b"\0asm") {
        return Err(ComponentError::NotWasm);
    }
    match bytes.get(4..8) {
        Some([1, 0, 0, 0]) => return Err(ComponentError::Core),
        Some([13, 0, 1, 0]) => {}
        Some(_) | None => return Err(ComponentError::Invalid(text::INVALID.into())),
    }
    *compilations = compilations.saturating_add(1);
    let component = Component::from_binary(engine, bytes)
        .map_err(|error| ComponentError::Invalid(format!("{error:#}")))?;
    let ty = component.component_type();
    let imports: Vec<_> = ty
        .imports(engine)
        .map(|(name, _)| name.to_owned())
        .collect();
    if !imports.is_empty() {
        return Err(ComponentError::Imports {
            count: imports.len(),
            wasi: imports.iter().any(|name| name.starts_with("wasi:")),
            names: imports.into_iter().take(5).collect(),
        });
    }
    Ok(component)
}

fn component_error(decl: &ExternalDecl, error: &ComponentError) -> Diagnostic {
    let builder = path::builder(&decl.path, DiagCode::E1004);
    match error {
        ComponentError::NotWasm => builder.note("not_wasm").build(),
        ComponentError::Core => builder.note("core").build(),
        ComponentError::Invalid(reason) => builder.arg("reason", reason).note("invalid").build(),
        ComponentError::Imports { count, names, wasi } => {
            let diagnostic = path::builder(&decl.path, DiagCode::E1005)
                .arg("count", text::count(*count))
                .arg("names", names.join(", "))
                .note("imports");
            if *wasi {
                diagnostic.note("target")
            } else {
                diagnostic
            }
            .build()
        }
    }
}

#[derive(Clone)]
enum CachedError {
    Read(&'static str),
    Component(ComponentError),
}
type CachedComponent = Result<(Arc<ComponentSource>, Component), CachedError>;

/// 型の検査を通った関数と型の宣言を照合し、外部の宣言の表に結果を入れる。
/// 外部の宣言がないときはファイルシステムも Wasmtime も使わない。
pub fn check_externals(
    entry: &EntrySpec,
    fs: &dyn ModuleFs,
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &mut ResolveOutput,
    types: &TypeckOutput,
) -> Vec<Diagnostic> {
    check_externals_counted(entry, fs, modules, asts, sources, resolved, types).0
}

/// 宣言の照合のコンパイル試行数を、実行用の共有表と分けて返す。
pub(crate) fn check_externals_counted(
    entry: &EntrySpec,
    fs: &dyn ModuleFs,
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &mut ResolveOutput,
    types: &TypeckOutput,
) -> (Vec<Diagnostic>, u64) {
    if resolved.externals.iter().next().is_none() {
        return (Vec::new(), 0);
    }
    let mut compilations = 0;
    let diagnostics = match check_all(
        entry,
        fs,
        modules,
        asts,
        sources,
        resolved,
        (types, &mut compilations),
    ) {
        Ok(diagnostics) => diagnostics,
        Err(message) => vec![Diagnostic {
            kind: crate::diag::ReportKind::Internal,
            severity: crate::diag::Severity::Error,
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
        }],
    };
    (diagnostics, compilations)
}

fn check_all(
    entry: &EntrySpec,
    fs: &dyn ModuleFs,
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &mut ResolveOutput,
    (types, compilations): (&TypeckOutput, &mut u64),
) -> Result<Vec<Diagnostic>, String> {
    let engine = Engine::new(&super::engine_config())
        .map_err(|error| format!("cannot create Wasmtime engine: {error}"))?;
    // 読み込みと照合の間にディレクトリが変化した場合も、宣言の位置で I/O の失敗を報告する。
    let root = fs.canonicalize(&entry.root);
    let dependencies = crate::modules::package::dependency_roots(entry, fs, modules, asts);
    let mut root_package = None;
    for module in modules
        .iter()
        .filter(|module| module.kind == ModuleKind::Config)
    {
        let ast = asts
            .get(usize::try_from(module.id.0).map_err(|_| "module index overflow")?)
            .ok_or_else(|| "missing configuration AST".to_owned())?;
        root_package = ast.header.iter().find_map(|item| match item {
            HeaderItem::Package(block) => Some(block.name.text.as_str()),
            HeaderItem::Language(_) | HeaderItem::Dependency(_) => None,
        });
    }
    let mut cache: BTreeMap<PathBuf, CachedComponent> = BTreeMap::new();
    let mut diagnostics = Vec::new();
    let mut next_id = 0_u32;
    let mut declarations: Vec<_> = resolved
        .externals
        .iter()
        .map(|(binding, decl)| (binding, decl.clone()))
        .collect();
    declarations.sort_by_key(|(id, _)| {
        !resolved
            .bindings
            .get(*id)
            .is_some_and(|b| b.kind == crate::resolve::BindingKind::ExternalType)
    });
    let mut resources = types::ResourceBindings::new();
    let names = TyNames {
        bindings: &resolved.bindings,
        adts: &types.adts,
        effects: &types.effects,
        type_params: &[],
        effect_params: &[],
    };
    let mut expansion_remaining = 1_000_000;
    for (binding, mut decl) in declarations {
        let module = modules
            .get(decl.module)
            .ok_or_else(|| "missing external module".to_owned())?;
        let ast = asts
            .get(usize::try_from(decl.module.0).map_err(|_| "module index overflow")?)
            .ok_or_else(|| "missing external AST".to_owned())?;
        let f = ast.decls.iter().find_map(|top| match &top.item {
            Item::Fn(f) if f.id == decl.decl => Some(f.as_ref()),
            Item::Fn(_)
            | Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::ExternalType(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Impl(_)
            | Item::Effect(_)
            | Item::Error(_) => None,
        });
        let planned = if let Some(f) = f {
            let scheme = types
                .decl_types
                .get(binding)
                .ok_or_else(|| "missing external scheme".to_owned())?;
            let (params, result) = declaration_plan(
                f,
                scheme,
                resolved,
                &names,
                sources,
                &mut diagnostics,
                &mut expansion_remaining,
            );
            let (Some(params), Some(result)) = (params, result) else {
                continue;
            };
            let external_ids: Vec<_> = params
                .iter()
                .chain(result.iter())
                .flat_map(DeclPlan::external_ids)
                .collect();
            // 型の照合が失敗したときは、関数に同じ原因の診断を重ねない（設計書 03-10「照合」）。
            if external_ids.iter().any(|id| !resources.contains_key(id)) {
                continue;
            }
            // エフェクトは型検査を通っているため、ここでは確定した型の変換表を使う。
            Some((f, scheme, params, result))
        } else {
            None
        };
        let alias = if module.kind == ModuleKind::Package {
            Some(
                module
                    .name
                    .0
                    .first()
                    .ok_or_else(|| "empty package module path".to_owned())?
                    .as_str(),
            )
        } else {
            None
        };
        let (component_root, display_root) = if let Some(alias) = alias {
            let dependencies = match &dependencies {
                Ok(dependencies) => dependencies,
                Err(error) => {
                    diagnostics.push(*path::read_error(&decl.path, text::io_reason(error)));
                    continue;
                }
            };
            let (root, display) = dependencies
                .get(alias)
                .ok_or_else(|| "missing external package root".to_owned())?;
            (root.as_path(), display.clone())
        } else {
            let root = match &root {
                Ok(root) => root,
                Err(error) => {
                    diagnostics.push(*path::read_error(&decl.path, text::io_reason(error)));
                    continue;
                }
            };
            let display = Path::new(&entry.display_name)
                .parent()
                .unwrap_or(Path::new(""))
                .display()
                .to_string();
            (root.as_path(), display)
        };
        let package = alias.or(root_package);
        let canonical = match path::resolve_path(fs, component_root, &decl.path, package) {
            Ok(path) => path,
            Err(diagnostic) => {
                diagnostics.push(*diagnostic);
                continue;
            }
        };
        let cached = cache.entry(canonical.clone()).or_insert_with(|| {
            let bytes = fs
                .read_file(&canonical)
                .map_err(|error| CachedError::Read(text::io_reason(&error)))?;
            if bytes.len() > crate::base::source::MAX_SOURCE_BYTES {
                return Err(CachedError::Read(text::TOO_LARGE));
            }
            let component = check_component_counted(&engine, &bytes, compilations)
                .map_err(CachedError::Component)?;
            let source = Arc::new(ComponentSource {
                display: Path::new(&display_root)
                    .join(&decl.path.value)
                    .display()
                    .to_string(),
                bytes: bytes.into(),
            });
            Ok((source, component))
        });
        let (source, component) = match cached {
            Ok(component) => component,
            Err(CachedError::Read(reason)) => {
                diagnostics.push(*path::read_error(&decl.path, reason));
                continue;
            }
            Err(CachedError::Component(error)) => {
                diagnostics.push(component_error(&decl, error));
                continue;
            }
        };
        let component_type = component.component_type();
        let (instance, export) = decl
            .export
            .value
            .rsplit_once('#')
            .map_or((None, decl.export.value.as_str()), |(instance, export)| {
                (Some(instance), export)
            });
        // 型の側の get_export は文字列の完全一致で引く。版の互換性による
        // 検索を使わず、宣言の契約を検査する（設計書 03-10「照合」）。
        let exported = match instance {
            None => component_type
                .get_export(&engine, export)
                .map(|item| item.ty),
            Some(name) => match component_type.get_export(&engine, name).map(|item| item.ty) {
                Some(ComponentItem::ComponentInstance(interface)) => {
                    interface.get_export(&engine, export).map(|item| item.ty)
                }
                _ => None,
            },
        };
        if planned.is_none() {
            let Some(ComponentItem::Resource(resource)) = exported else {
                diagnostics.push(missing_resource(&decl, &component_type, &engine));
                continue;
            };
            resources.insert(binding, (canonical, resource));
            decl.external_type = Some(Arc::new(super::ExternalTypeSpec {
                id: binding.0,
                component: Arc::clone(source),
                instance: instance.map(str::to_owned),
                name: export.to_owned(),
            }));
            resolved.externals.insert(binding, decl);
            continue;
        }
        let (f, scheme, params, result) =
            planned.ok_or_else(|| "external function plan missing".to_owned())?;
        let function = if module.kind == ModuleKind::Entry {
            f.name.text.clone()
        } else {
            format!("{}.{}", module.name.dotted(), f.name.text)
        };
        let exported_resources = resource_exports(&component_type, &engine);
        let context = types::BindContext {
            resources: &resources,
            exported_resources: &exported_resources,
            component_display: &source.display,
            component: &canonical,
            resolved,
            result: false,
        };
        let Some(ComponentItem::ComponentFunc(exported)) = exported else {
            diagnostics.push(missing_function(&decl, &component_type, &engine, instance));
            continue;
        };
        if exported.async_() {
            diagnostics.push(
                path::builder(&decl.path, DiagCode::E1011)
                    .arg("name", &decl.export.value)
                    .build(),
            );
            continue;
        }
        let declaration = types::declaration(&f.name.text, &exported);
        let before = diagnostics.len();
        let mut bound_params = Vec::new();
        if exported.params().len() != params.len() {
            diagnostics.push(
                with_declaration(
                    DiagBuilder::new(DiagCode::E1007)
                        .arg("name", &decl.export.value)
                        .arg("function", &function)
                        .arg("found", text::parameters(exported.params().len()))
                        .arg("expected", text::parameters(params.len()))
                        .primary(f.name.span),
                    declaration.as_deref(),
                )
                .build(),
            );
        } else {
            for (index, ((plan, (_, wit)), (param, ty))) in params
                .iter()
                .zip(exported.params())
                .zip(f.params.iter().zip(&scheme.params))
                .enumerate()
            {
                match types::bind(plan, &wit, &context) {
                    Ok(plan) => bound_params.push(plan),
                    Err(reason) => {
                        diagnostics.push(
                            with_user_type(
                                with_reason(
                                    with_declaration(
                                        mismatch(
                                            DiagCode::E1008,
                                            param.ty.as_ref().map_or(param.span, |ty| ty.span()),
                                            ty,
                                            &names,
                                            &function,
                                            plan.show(),
                                            types::show(&wit),
                                        )
                                        .arg("index", index.saturating_add(1).to_string()),
                                        declaration.as_deref(),
                                    ),
                                    reason,
                                ),
                                ty,
                                &wit,
                                &names,
                                sources,
                            )
                            .build(),
                        );
                    }
                }
            }
        }
        let results: Vec<_> = exported.results().collect();
        let bound_result = match (&result, results.as_slice()) {
            (None, []) => Ok(None),
            (Some(plan), [wit]) => types::bind(
                plan,
                wit,
                &types::BindContext {
                    result: true,
                    ..context
                },
            )
            .map(Some),
            _ => Err(types::Mismatch(None)),
        };
        let bound_result = match bound_result {
            Ok(plan) => plan,
            Err(reason) => {
                diagnostics.push(
                    with_user_type_result(
                        with_reason(
                            with_declaration(
                                mismatch(
                                    DiagCode::E1009,
                                    f.ret.span(),
                                    &scheme.ret,
                                    &names,
                                    &function,
                                    result
                                        .as_ref()
                                        .map_or_else(|| text::UNIT.into(), DeclPlan::show),
                                    if results.is_empty() {
                                        text::UNIT.into()
                                    } else {
                                        results
                                            .iter()
                                            .map(types::show)
                                            .collect::<Vec<_>>()
                                            .join(", ")
                                    },
                                ),
                                declaration.as_deref(),
                            ),
                            reason,
                        ),
                        &scheme.ret,
                        &results,
                        &names,
                        sources,
                    )
                    .build(),
                );
                None
            }
        };
        if diagnostics.len() == before {
            let id = next_id;
            next_id = next_id
                .checked_add(1)
                .ok_or_else(|| "external function index overflow".to_owned())?;
            let spec = Arc::new(ExternalSpec {
                adapter: None,
                id,
                function,
                component: Arc::clone(source),
                instance: instance.map(str::to_owned),
                export: export.to_owned(),
                route: super::ExternalRoute::of(&bound_params, bound_result.as_ref()),
                params: bound_params,
                result: bound_result,
            });
            decl.spec = Some(spec);
            resolved.externals.insert(binding, decl);
        }
    }
    // 状態を持つ経路と既存の具体化を先に選び、残る宣言だけを補助の集合へまとめる。
    // 生成・配置の上限による動的への振り分けも、ゲストを呼ぶ前に保存する。
    let eligible: Vec<_> = resolved
        .externals
        .iter()
        .filter_map(|(id, decl)| {
            decl.spec
                .as_ref()
                .filter(|spec| spec.route == super::ExternalRoute::Dynamic)
                .map(|spec| (id, decl.clone(), Arc::clone(spec)))
        })
        .collect();
    // 照合済みの型の再走査には宣言ごとの別予算を使う。照合の合計を重ねて消費しない。
    for (id, mut decl, spec) in eligible {
        match super::adapter::runtime::prepare(
            &[Arc::clone(&spec)],
            &mut 4_000_000,
            super::adapter::component::GENERATION_LIMIT,
        ) {
            Ok(mut bindings) => {
                let binding = bindings
                    .remove(&spec.id)
                    .ok_or_else(|| "prepared adapter binding missing".to_owned())?;
                let stored = decl
                    .spec
                    .as_mut()
                    .ok_or_else(|| "adapter declaration missing".to_owned())?;
                Arc::make_mut(stored).adapter = Some(binding);
                resolved.externals.insert(id, decl);
            }
            Err(super::adapter::layout::LayoutError::TypeBudget) => {
                diagnostics.push(
                    DiagBuilder::new(DiagCode::E1010)
                        .arg("name", &spec.function)
                        .primary_label(decl.export.span, "declaration")
                        .note("adapter_preparation_budget")
                        .build_variant("adapter_preparation"),
                );
            }
            Err(error) => return Err(format!("adapter preparation failed: {error:?}")),
        }
    }
    Ok(diagnostics)
}

fn missing_function(
    decl: &ExternalDecl,
    component: &wasmtime::component::types::Component,
    engine: &Engine,
    instance: Option<&str>,
) -> Diagnostic {
    let mut exports = Vec::new();
    let mut diagnostic = path::builder(&decl.path, DiagCode::E1006)
        .arg("name", &decl.export.value)
        .primary(decl.export.span)
        .note("exports");
    let mut version_found = false;
    for (name, item) in component.exports(engine) {
        match item.ty {
            ComponentItem::ComponentFunc(_) => exports.push(name.to_owned()),
            ComponentItem::ComponentInstance(interface) => {
                for (function, item) in interface.exports(engine) {
                    if matches!(item.ty, ComponentItem::ComponentFunc(_)) {
                        exports.push(format!("{name}#{function}"));
                    }
                }
                if instance.is_none() && name == decl.export.value {
                    diagnostic = diagnostic.note("interface");
                }
                if let Some(requested) = instance
                    && !version_found
                    && component.get_export(engine, requested).is_none()
                    && requested != name
                    && requested
                        .rsplit_once('@')
                        .map_or(requested, |(base, _)| base)
                        == name.rsplit_once('@').map_or(name, |(base, _)| base)
                {
                    diagnostic = diagnostic.arg("found", name).note("version");
                    version_found = true;
                }
            }
            ComponentItem::CoreFunc(_)
            | ComponentItem::Module(_)
            | ComponentItem::Component(_)
            | ComponentItem::Type(_)
            | ComponentItem::Resource(_) => {}
        }
    }
    diagnostic
        .arg("names", text::names(exports.into_iter()))
        .build()
}

fn with_reason(builder: DiagBuilder, reason: types::Mismatch) -> DiagBuilder {
    match reason.0 {
        Some(reason) => builder.arg("reason", reason).note("reason"),
        None => builder,
    }
}

fn with_declaration(builder: DiagBuilder, declaration: Option<&str>) -> DiagBuilder {
    match declaration {
        Some(declaration) => builder.arg("declaration", declaration).note("declaration"),
        None => builder,
    }
}

fn declaration_plan(
    f: &FnDecl,
    scheme: &crate::types::Scheme,
    resolved: &ResolveOutput,
    names: &TyNames<'_>,
    sources: &SourceTable,
    diagnostics: &mut Vec<Diagnostic>,
    expansion_remaining: &mut usize,
) -> (Option<Vec<DeclPlan>>, Option<Option<DeclPlan>>) {
    if *expansion_remaining == 0 {
        diagnostics.push(exhausted_declaration(f));
        return (None, None);
    }
    let mut params = Vec::new();
    let mut valid = true;
    for (param, ty) in f.params.iter().zip(&scheme.params) {
        if *expansion_remaining == 0 {
            diagnostics.push(exhausted_declaration(f));
            return (None, None);
        }
        match types::plan(ty, resolved, names.adts, expansion_remaining) {
            Ok(plan) => params.push(plan),
            Err(unsupported_ty) => {
                diagnostics.push(unsupported(
                    unsupported_ty,
                    names,
                    sources,
                    param.ty.as_ref().map_or(param.span, |ty| ty.span()),
                ));
                if *expansion_remaining == 0 {
                    return (None, None);
                }
                valid = false;
            }
        }
    }
    let result = if types::is_unit(&scheme.ret) {
        Some(None)
    } else if *expansion_remaining == 0 {
        diagnostics.push(exhausted_declaration(f));
        return (None, None);
    } else {
        match types::plan(&scheme.ret, resolved, names.adts, expansion_remaining) {
            Ok(plan) => Some(Some(plan)),
            Err(ty) => {
                diagnostics.push(unsupported(ty, names, sources, f.ret.span()));
                None
            }
        }
    };
    (valid.then_some(params), result)
}

fn exhausted_declaration(f: &FnDecl) -> Diagnostic {
    let span = f.params.first().map_or(f.name.span, |param| {
        param.ty.as_ref().map_or(param.span, |ty| ty.span())
    });
    DiagBuilder::new(DiagCode::E1010)
        .arg("name", &f.name.text)
        .primary_label(span, "declaration")
        .note("budget")
        .build_variant("declaration_budget")
}
fn unsupported(
    error: types::Unsupported<'_>,
    names: &TyNames<'_>,
    sources: &SourceTable,
    span: Span,
) -> Diagnostic {
    let ty = error.ty;
    let mut diag = DiagBuilder::new(DiagCode::E1010)
        .arg("ty", ty.show(names))
        .primary(span)
        .note("types");
    if let Some(note) = error.note {
        diag = diag.note(note);
    }
    if let Some(id) = error.recursive
        && let Some(def) = names.adts.get(id)
    {
        diag = diag
            .arg("recursive_name", &def.name)
            .note("recursive_declaration");
    }
    if error.note != Some("budget") {
        diag = user_type_note(diag, ty, names, sources);
    }

    diag.build()
}

fn with_user_type_result(
    builder: DiagBuilder,
    ty: &Ty,
    wit: &[wasmtime::component::Type],
    names: &TyNames<'_>,
    sources: &SourceTable,
) -> DiagBuilder {
    match wit {
        [wit] => with_user_type(builder, ty, wit, names, sources),
        _ => builder,
    }
}
fn with_user_type(
    builder: DiagBuilder,
    ty: &Ty,
    wit: &wasmtime::component::Type,
    names: &TyNames<'_>,
    sources: &SourceTable,
) -> DiagBuilder {
    if matches!(
        wit,
        wasmtime::component::Type::Option(_)
            | wasmtime::component::Type::Result(_)
            | wasmtime::component::Type::Tuple(_)
    ) {
        user_type_note(builder, ty, names, sources)
    } else {
        builder
    }
}
fn user_type_note(
    builder: DiagBuilder,
    ty: &Ty,
    names: &TyNames<'_>,
    sources: &SourceTable,
) -> DiagBuilder {
    if let Ty::Con(crate::types::TyCon::Adt(id), _) = ty
        && let Some(def) = names.adts.get(*id)
        && matches!(def.name.as_str(), "Option" | "Result" | "Pair" | "Triple")
        && let Some(source) = sources.get(def.module.file())
        && source.kind() == crate::base::SourceKind::User
    {
        builder
            .arg("name", &def.name)
            .arg("file", source.name())
            .note("user_type")
    } else {
        builder
    }
}

// 長い型の診断でも、見出しと注記が出力を埋め尽くさない（設計書 03-10「型の対応」）。
fn limited_display(value: String) -> String {
    if value.chars().count() <= 2_000 {
        value
    } else {
        value.chars().take(1_999).chain(['…']).collect()
    }
}

fn mismatch(
    code: DiagCode,
    span: Span,
    ty: &Ty,
    names: &TyNames<'_>,
    function: &str,
    expected: String,
    wit: String,
) -> DiagBuilder {
    DiagBuilder::new(code)
        .arg("function", function)
        .arg("declared", limited_display(ty.show(names)))
        .arg("expected", limited_display(expected))
        .arg("wit", limited_display(wit))
        .primary(span)
        .note("component")
        .note("maps")
}

fn missing_resource(
    decl: &ExternalDecl,
    component: &wasmtime::component::types::Component,
    engine: &Engine,
) -> Diagnostic {
    let resources = resource_exports(component, engine)
        .into_iter()
        .map(|(_, name)| name);
    path::builder(&decl.path, DiagCode::E1012)
        .arg("name", &decl.export.value)
        .arg("names", text::names(resources))
        .note("exports")
        .build()
}

pub(super) fn resource_exports(
    component: &wasmtime::component::types::Component,
    engine: &Engine,
) -> Vec<(wasmtime::component::ResourceType, String)> {
    let mut resources = Vec::new();
    for (name, item) in component.exports(engine) {
        match item.ty {
            ComponentItem::Resource(r) => resources.push((r, name.to_owned())),
            ComponentItem::ComponentInstance(i) => {
                resources.extend(i.exports(engine).filter_map(|(r, item)| {
                    if let ComponentItem::Resource(ty) = item.ty {
                        Some((ty, format!("{name}#{r}")))
                    } else {
                        None
                    }
                }));
            }
            ComponentItem::ComponentFunc(_)
            | ComponentItem::Component(_)
            | ComponentItem::Module(_)
            | ComponentItem::Type(_)
            | ComponentItem::CoreFunc(_) => {}
        }
    }
    resources
}
