//! 補助用メモリと内部の報告関数を外側に置く（設計書 03-10「実行」）。
//! 元のゲストへ報告の取り込みを加えず、ホストの関数の公開の入口も増やさない。

use wasm_encoder::{
    CanonicalFunctionSection, Component, ComponentImportSection, ComponentTypeRef,
    ComponentTypeSection, ExportKind, InstanceSection, ModuleArg, ModuleSection, PrimitiveValType,
};

use super::{emit, layout::LayoutError};

/// 新しい外側の先頭に、報告関数とメモリのコアインスタンスを置く。
/// コンポーネント関数 0 は報告、コア関数 0 はその lower、コアインスタンス 1 はメモリである。
pub(crate) fn memory_component(
    minimum: u64,
    maximum: Option<u64>,
) -> Result<Component, LayoutError> {
    let module = emit::memory_module(minimum, maximum)?;
    let mut component = Component::new();
    let mut types = ComponentTypeSection::new();
    types
        .function()
        .params([
            ("code", PrimitiveValType::U32),
            ("requested", PrimitiveValType::U64),
            ("limit", PrimitiveValType::U64),
        ])
        .result(None);
    component.section(&types);
    let mut imports = ComponentImportSection::new();
    imports.import("adapter-fail", ComponentTypeRef::Func(0));
    component.section(&imports);
    let mut canonical = CanonicalFunctionSection::new();
    canonical.lower(0, []);
    component.section(&canonical);
    component.section(&ModuleSection(&module));
    let mut instances = InstanceSection::new();
    instances.export_items([("adapter-fail", ExportKind::Func, 0)]);
    instances.instantiate(0, [("adapter", ModuleArg::Instance(0))]);
    component.section(&instances);
    Ok(component)
}

/// 元の入力を除く、補助の区画全体のバイト数の上限。
pub(crate) const GENERATION_LIMIT: usize = 16 * 1024 * 1024;

/// 生成前の判定と、生成器の不具合を区別する。
#[cfg(test)]
#[derive(Debug)]
pub(crate) enum BuildError {
    Layout(LayoutError),
    Original(super::super::check::ComponentError),
    Invalid(String),
}
#[cfg(test)]
impl From<LayoutError> for BuildError {
    fn from(error: LayoutError) -> Self {
        Self::Layout(error)
    }
}
#[cfg(test)]
impl BuildError {
    /// 呼び出しを始める前だけ、表現・生成の上限を理由に動的な経路へ移せる。
    pub(crate) fn permits_dynamic(&self) -> bool {
        matches!(
            self,
            Self::Layout(LayoutError::GenerationBudget | LayoutError::Memory32)
        )
    }
}

/// WIT の形を前順の平らな列で表す。言語のタグと ABI 専用の組の区別は含めない。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum Shape {
    Kind(&'static str),
    Count(usize),
    Name(String),
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct TypeKey {
    shape: Vec<Shape>,
    construction: super::codec::ConstructionTable,
}
impl TypeKey {
    fn new(plans: &[super::super::WitPlan], budget: &mut usize) -> Result<Self, LayoutError> {
        use super::super::WitPlan as P;
        let codec = super::codec::CodecPlan::new(plans, budget)?;
        let mut shape = vec![Shape::Count(plans.len())];
        let mut work: Vec<_> = plans.iter().rev().collect();
        while let Some(plan) = work.pop() {
            let kind = match plan {
                P::S8 => "s8",
                P::S16 => "s16",
                P::S32 => "s32",
                P::S64 => "s64",
                P::U8 => "u8",
                P::U16 => "u16",
                P::U32 => "u32",
                P::U64 => "u64",
                P::F32 => "f32",
                P::F64 => "f64",
                P::Bool => "bool",
                P::Char => "char",
                P::String => "string",
                P::Bytes => {
                    shape.extend([Shape::Kind("list"), Shape::Kind("u8")]);
                    continue;
                }
                P::List(p) | P::Option(p) => {
                    work.push(p);
                    if matches!(plan, P::List(_)) {
                        "list"
                    } else {
                        "option"
                    }
                }
                P::Map(k, v) => {
                    work.extend([v.as_ref(), k.as_ref()]);
                    "map"
                }
                P::Result { ok, err } => {
                    shape.extend([
                        Shape::Kind("result"),
                        Shape::Count(usize::from(ok.is_some())),
                        Shape::Count(usize::from(err.is_some())),
                    ]);
                    work.extend(err.iter().chain(ok).map(Box::as_ref));
                    continue;
                }
                P::Tuple(ps) | P::TupleFields(ps) | P::ConstructorTuple { fields: ps, .. } => {
                    shape.extend([Shape::Kind("tuple"), Shape::Count(ps.len())]);
                    work.extend(ps.iter().rev());
                    continue;
                }
                P::Record { fields } => {
                    shape.extend([Shape::Kind("record"), Shape::Count(fields.len())]);
                    shape.extend(fields.iter().map(|(name, _)| Shape::Name(name.clone())));
                    work.extend(fields.iter().rev().map(|(_, p)| p));
                    continue;
                }
                P::Variant { cases } => {
                    shape.extend([Shape::Kind("variant"), Shape::Count(cases.len())]);
                    for (name, _, payload) in cases {
                        shape.extend([
                            Shape::Name(name.clone()),
                            Shape::Count(usize::from(payload.is_some())),
                        ]);
                    }
                    work.extend(cases.iter().rev().filter_map(|(_, _, p)| p.as_deref()));
                    continue;
                }
                P::Enum { cases } | P::Flags { cases } => {
                    shape.push(Shape::Kind(if matches!(plan, P::Enum { .. }) {
                        "enum"
                    } else {
                        "flags"
                    }));
                    shape.push(Shape::Count(cases.len()));
                    shape.extend(cases.iter().map(|(name, _)| Shape::Name(name.clone())));
                    continue;
                }
                P::Own(_) | P::Borrow(_) => return Err(LayoutError::Resource),
            };
            shape.push(Shape::Kind(kind));
        }
        Ok(Self {
            shape,
            construction: codec.construction,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct FunctionKey {
    instance: Option<String>,
    export: String,
    params: TypeKey,
    results: TypeKey,
}

/// ソース・呼ぶ関数・構築の規則・形式の版を含む共有の鍵。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct ComponentKey {
    original: std::sync::Arc<[u8]>,
    functions: Vec<FunctionKey>,
    version: u32,
}

struct AdapterFunction {
    key: FunctionKey,
    params: Vec<super::super::WitPlan>,
    results: Vec<super::super::WitPlan>,
}

/// 元バイト列・呼ぶ関数・構築規則が同じ宣言だけをまとめる。インスタンスと Store は保持せず、呼び出しごとに作る。
pub(crate) struct ComponentGroup {
    pub key: ComponentKey,
    /// 宣言の番号から補助の書き出しへ引く。タグの対応は宣言側の WitPlan を使う。
    pub exports: std::collections::BTreeMap<u32, String>,
    functions: Vec<AdapterFunction>,
}
impl ComponentGroup {
    /// 同じ WIT の関数でも、ホストの構築規則が違えば別の補助を書き出す。
    #[cfg(test)]
    pub(crate) fn prepare(
        specs: &[std::sync::Arc<super::super::ExternalSpec>],
    ) -> Result<Vec<Self>, LayoutError> {
        Self::prepare_with_budget(specs, &mut 1_000_000)
    }

    /// 準備の予算を共有の鍵と生成へ引き継ぐ。
    pub(crate) fn prepare_with_budget(
        specs: &[std::sync::Arc<super::super::ExternalSpec>],
        budget: &mut usize,
    ) -> Result<Vec<Self>, LayoutError> {
        let mut sources: Vec<(std::sync::Arc<[u8]>, Vec<&super::super::ExternalSpec>)> = Vec::new();
        for spec in specs {
            if let Some((_, declarations)) = sources
                .iter_mut()
                .find(|(bytes, _)| bytes.as_ref() == spec.component.bytes.as_ref())
            {
                declarations.push(spec);
            } else {
                sources.push((std::sync::Arc::clone(&spec.component.bytes), vec![spec]));
            }
        }
        let mut groups = Vec::new();
        for (original, declarations) in sources {
            let mut functions = std::collections::BTreeMap::new();
            for spec in declarations {
                let results: Vec<_> = spec.result.iter().cloned().collect();
                let key = FunctionKey {
                    instance: spec.instance.clone(),
                    export: spec.export.clone(),
                    params: TypeKey::new(&spec.params, budget)?,
                    results: TypeKey::new(&results, budget)?,
                };
                let entry = functions.entry(key.clone()).or_insert_with(|| {
                    (
                        AdapterFunction {
                            key,
                            params: spec.params.clone(),
                            results,
                        },
                        Vec::new(),
                    )
                });
                entry.1.push(spec.id);
            }
            for (_, (function, ids)) in functions {
                let name = adapter_export(0);
                groups.push(Self {
                    key: ComponentKey {
                        original: std::sync::Arc::clone(&original),
                        functions: vec![function.key.clone()],
                        version: super::wire::VERSION,
                    },
                    exports: ids.into_iter().map(|id| (id, name.clone())).collect(),
                    functions: vec![function],
                });
            }
        }
        Ok(groups)
    }

    /// 元のゲストの取り込みなしを再確認し、生成したバイナリも検証する。
    /// コンパイル済みコードだけを共有し、成功・失敗の後のインスタンスは再利用しない。
    #[cfg(test)]
    pub(crate) fn compile(
        &self,
        engine: &wasmtime::Engine,
        limit: usize,
    ) -> Result<wasmtime::component::Component, BuildError> {
        super::super::check_component(engine, &self.key.original).map_err(BuildError::Original)?;
        let bytes = self.generate(limit)?;
        wasmtime::component::Component::from_binary(engine, &bytes)
            .map_err(|e| BuildError::Invalid(format!("{e:#}")))
    }

    /// インスタンス化より先に生成上限を判定できるよう、合成とコンパイルを分ける。
    #[cfg(test)]
    pub(crate) fn generate(&self, limit: usize) -> Result<Vec<u8>, LayoutError> {
        self.generate_with_budget(limit, &mut 1_000_000)
    }

    /// 型の走査を再開しても、準備で消費した予算を戻さない。
    pub(crate) fn generate_with_budget(
        &self,
        limit: usize,
        budget: &mut usize,
    ) -> Result<Vec<u8>, LayoutError> {
        let names: Vec<_> = (0..self.functions.len()).map(adapter_export).collect();
        compose(&self.key.original, &self.functions, &names, limit, budget)
    }
}

/// 取り込みのない元コードのインスタンス数を、ゲストの start を実行せずに見積もる。
/// 取り込み・書き出しから得るコンポーネントは上限を保守的に見積もり、動的経路へ残す。
pub(crate) fn core_instances(bytes: &[u8]) -> Result<usize, LayoutError> {
    use wasmparser::{
        ComponentAlias, ComponentExternalKind as Kind, ComponentInstance, ComponentOuterAliasKind,
        ComponentTypeRef, Instance, Parser, Payload,
    };
    #[derive(Default)]
    struct Scope {
        components: Vec<usize>,
        instances: usize,
    }
    let bound = super::super::runtime::OBJECTS.saturating_add(1);
    let invalid = |_| LayoutError::Internal("cannot count validated component instances");
    let mut scopes = vec![Some(Scope::default())];
    for payload in Parser::new(0).parse_all(bytes) {
        let payload = payload.map_err(invalid)?;
        match payload {
            Payload::ModuleSection { .. } => {
                scopes.push(None);
            }
            Payload::ComponentSection { .. } => {
                scopes.push(Some(Scope::default()));
            }
            Payload::End(_) => {
                let scope = scopes
                    .pop()
                    .ok_or(LayoutError::Internal("instance-count scope missing"))?;
                if scopes.is_empty() {
                    return scope
                        .map(|s| s.instances)
                        .ok_or(LayoutError::Internal("expected component"));
                }
                if let Some(scope) = scope
                    && let Some(Some(parent)) = scopes.last_mut()
                {
                    parent.components.push(scope.instances);
                }
            }
            Payload::InstanceSection(section) => {
                if let Some(Some(scope)) = scopes.last_mut() {
                    for instance in section {
                        if matches!(instance.map_err(invalid)?, Instance::Instantiate { .. }) {
                            scope.instances = scope.instances.saturating_add(1).min(bound);
                        }
                    }
                }
            }
            Payload::ComponentInstanceSection(section) => {
                if let Some(Some(scope)) = scopes.last_mut() {
                    for instance in section {
                        if let ComponentInstance::Instantiate {
                            component_index, ..
                        } = instance.map_err(invalid)?
                        {
                            let count = scope
                                .components
                                .get(
                                    usize::try_from(component_index)
                                        .map_err(|_| LayoutError::Memory32)?,
                                )
                                .copied()
                                .unwrap_or(bound);
                            scope.instances = scope.instances.saturating_add(count).min(bound);
                        }
                    }
                }
            }
            Payload::ComponentCanonicalSection(section) => {
                if let Some(Some(scope)) = scopes.last_mut() {
                    for function in section {
                        // lower ごとに融合用のモジュールが一個増えうる。ホスト向けも多めに数える。
                        if matches!(
                            function.map_err(invalid)?,
                            wasmparser::CanonicalFunction::Lower { .. }
                        ) {
                            scope.instances = scope.instances.saturating_add(1).min(bound);
                        }
                    }
                }
            }
            Payload::ComponentImportSection(section) => {
                if let Some(Some(scope)) = scopes.last_mut() {
                    for import in section {
                        if matches!(import.map_err(invalid)?.ty, ComponentTypeRef::Component(_)) {
                            scope.components.push(bound);
                        }
                    }
                }
            }
            Payload::ComponentAliasSection(section) => {
                for alias in section {
                    let count = match alias.map_err(invalid)? {
                        ComponentAlias::Outer {
                            kind: ComponentOuterAliasKind::Component,
                            count,
                            index,
                        } => {
                            let count =
                                usize::try_from(count).map_err(|_| LayoutError::Memory32)?;
                            let index =
                                usize::try_from(index).map_err(|_| LayoutError::Memory32)?;
                            scopes
                                .len()
                                .checked_sub(count.saturating_add(1))
                                .and_then(|i| scopes.get(i))
                                .and_then(Option::as_ref)
                                .and_then(|s| s.components.get(index))
                                .copied()
                                .unwrap_or(bound)
                        }
                        ComponentAlias::InstanceExport {
                            kind: Kind::Component,
                            ..
                        } => bound,
                        ComponentAlias::InstanceExport { .. }
                        | ComponentAlias::CoreInstanceExport { .. }
                        | ComponentAlias::Outer { .. } => continue,
                    };
                    if let Some(Some(scope)) = scopes.last_mut() {
                        scope.components.push(count);
                    }
                }
            }
            Payload::ComponentExportSection(section) => {
                if let Some(Some(scope)) = scopes.last_mut() {
                    for export in section {
                        let export = export.map_err(invalid)?;
                        if export.kind == Kind::Component {
                            let index =
                                usize::try_from(export.index).map_err(|_| LayoutError::Memory32)?;
                            let count = scope.components.get(index).copied().unwrap_or(bound);
                            scope.components.push(count);
                        }
                    }
                }
            }
            Payload::Version { .. }
            | Payload::TypeSection(_)
            | Payload::ImportSection(_)
            | Payload::FunctionSection(_)
            | Payload::TableSection(_)
            | Payload::MemorySection(_)
            | Payload::TagSection(_)
            | Payload::GlobalSection(_)
            | Payload::ExportSection(_)
            | Payload::StartSection { .. }
            | Payload::ElementSection(_)
            | Payload::DataCountSection { .. }
            | Payload::DataSection(_)
            | Payload::CodeSectionStart { .. }
            | Payload::CodeSectionEntry(_)
            | Payload::CoreTypeSection(_)
            | Payload::ComponentTypeSection(_)
            | Payload::ComponentStartSection { .. }
            | Payload::CustomSection(_) => {}
            Payload::UnknownSection { .. } | _ => {
                // 将来のセクションの消費量は分からないため、補助を加えず動的経路へ回す。
                return Ok(bound);
            }
        }
    }
    Err(LayoutError::Internal("unterminated instance-count scope"))
}

fn adapter_export(index: usize) -> String {
    format!("adapter-call-{index}")
}

/// 一関数の合成も集合の合成と同じ番号管理・予算を使う。
#[cfg(test)]
pub(crate) fn fixed_component(
    original: &[u8],
    export: &str,
    params: &[super::super::WitPlan],
    results: &[super::super::WitPlan],
) -> Result<Vec<u8>, LayoutError> {
    let mut budget = 1_000_000;
    let function = AdapterFunction {
        key: FunctionKey {
            instance: None,
            export: export.into(),
            params: TypeKey::new(params, &mut budget)?,
            results: TypeKey::new(results, &mut budget)?,
        },
        params: params.to_vec(),
        results: results.to_vec(),
    };
    compose(
        original,
        &[function],
        &["call".into()],
        GENERATION_LIMIT,
        &mut budget,
    )
}

fn compose(
    original: &[u8],
    functions: &[AdapterFunction],
    names: &[String],
    limit: usize,
    budget: &mut usize,
) -> Result<Vec<u8>, LayoutError> {
    use wasm_encoder::{
        Alias, CanonicalOption, ComponentAliasSection, ComponentExportKind, ComponentExportSection,
        ComponentInstanceSection, ComponentValType, RawSection,
    };
    let mut component = memory_component(1, None)?;
    let mut generated = component.as_slice().len();
    if generated > limit {
        return Err(LayoutError::GenerationBudget);
    }
    // 元のバイト列は除くが、入れ子の区画の識別子と長さは補助の生成量に含める。
    use wasm_encoder::Encode;
    let mut length = Vec::new();
    u32::try_from(original.len())
        .map_err(|_| LayoutError::Memory32)?
        .encode(&mut length);
    generated = generated
        .checked_add(length.len())
        .and_then(|n| n.checked_add(1))
        .ok_or(LayoutError::GenerationBudget)?;
    if generated > limit {
        return Err(LayoutError::GenerationBudget);
    }
    component.section(&RawSection {
        id: 4,
        data: original,
    });
    let mut instances = ComponentInstanceSection::new();
    instances.instantiate(0, std::iter::empty::<(&str, ComponentExportKind, u32)>());
    append(&mut component, &instances, &mut generated, limit)?;
    let mut aliases = ComponentAliasSection::new();
    aliases.alias(Alias::CoreInstanceExport {
        instance: 1,
        kind: ExportKind::Memory,
        name: "memory",
    });
    aliases.alias(Alias::CoreInstanceExport {
        instance: 1,
        kind: ExportKind::Func,
        name: "realloc",
    });
    append(&mut component, &aliases, &mut generated, limit)?;
    let mut types = ComponentTypeSection::new();
    types.defined_type().list(PrimitiveValType::U8);
    types
        .function()
        .params([("bytes", ComponentValType::Type(1))])
        .result(Some(ComponentValType::Type(1)));
    append(&mut component, &types, &mut generated, limit)?;
    let mut component_funcs = 1_u32;
    let mut core_funcs = 2_u32;
    let mut core_instances = 2_u32;
    let mut component_instances = 1_u32;
    for (index, function) in functions.iter().enumerate() {
        // 長い名前を持つ別名の区画も、作る前に残量に収まることを確認する。
        let name_bytes = function
            .key
            .export
            .len()
            .checked_add(function.key.instance.as_ref().map_or(0, String::len))
            .ok_or(LayoutError::GenerationBudget)?;
        if name_bytes > limit.saturating_sub(generated) {
            return Err(LayoutError::GenerationBudget);
        }
        let module = emit::fixed_module_bounded(
            &function.params,
            &function.results,
            limit.saturating_sub(generated),
            budget,
        )?;
        let mut aliases = ComponentAliasSection::new();
        let instance = if let Some(name) = &function.key.instance {
            aliases.alias(Alias::InstanceExport {
                instance: 0,
                kind: ComponentExportKind::Instance,
                name,
            });
            let id = component_instances;
            component_instances = component_instances
                .checked_add(1)
                .ok_or(LayoutError::Memory32)?;
            id
        } else {
            0
        };
        aliases.alias(Alias::InstanceExport {
            instance,
            kind: ComponentExportKind::Func,
            name: &function.key.export,
        });
        append(&mut component, &aliases, &mut generated, limit)?;
        let mut canonical = CanonicalFunctionSection::new();
        canonical.lower(
            component_funcs,
            [
                CanonicalOption::Memory(0),
                CanonicalOption::Realloc(1),
                CanonicalOption::UTF8,
            ],
        );
        append(&mut component, &canonical, &mut generated, limit)?;
        append(
            &mut component,
            &ModuleSection(&module),
            &mut generated,
            limit,
        )?;
        let mut instances = InstanceSection::new();
        instances.export_items([("call", ExportKind::Func, core_funcs)]);
        instances.instantiate(
            u32::try_from(index)
                .map_err(|_| LayoutError::Memory32)?
                .checked_add(1)
                .ok_or(LayoutError::Memory32)?,
            [
                ("guest", ModuleArg::Instance(core_instances)),
                ("support", ModuleArg::Instance(1)),
                ("failure", ModuleArg::Instance(0)),
            ],
        );
        append(&mut component, &instances, &mut generated, limit)?;
        let mut aliases = ComponentAliasSection::new();
        aliases.alias(Alias::CoreInstanceExport {
            instance: core_instances.checked_add(1).ok_or(LayoutError::Memory32)?,
            kind: ExportKind::Func,
            name: "call",
        });
        append(&mut component, &aliases, &mut generated, limit)?;
        let mut canonical = CanonicalFunctionSection::new();
        canonical.lift(
            core_funcs.checked_add(1).ok_or(LayoutError::Memory32)?,
            2,
            [
                CanonicalOption::Memory(0),
                CanonicalOption::Realloc(1),
                CanonicalOption::UTF8,
            ],
        );
        append(&mut component, &canonical, &mut generated, limit)?;
        let mut exports = ComponentExportSection::new();
        exports.export(
            names
                .get(index)
                .ok_or(LayoutError::Internal("adapter export name is missing"))?,
            ComponentExportKind::Func,
            component_funcs
                .checked_add(1)
                .ok_or(LayoutError::Memory32)?,
            None,
        );
        append(&mut component, &exports, &mut generated, limit)?;
        // 書き出しも関数の別名を定義するため、元の別名・lift と合わせて三つ進める。
        component_funcs = component_funcs
            .checked_add(3)
            .ok_or(LayoutError::Memory32)?;
        core_funcs = core_funcs.checked_add(2).ok_or(LayoutError::Memory32)?;
        core_instances = core_instances.checked_add(2).ok_or(LayoutError::Memory32)?;
    }
    Ok(component.finish())
}

fn append(
    component: &mut Component,
    section: &impl wasm_encoder::ComponentSection,
    generated: &mut usize,
    limit: usize,
) -> Result<(), LayoutError> {
    // 区画を外側へ書く前に長さを検査する。元の入力だけは生成量に含めない。
    let mut bytes = Vec::new();
    section.encode(&mut bytes);
    let length = bytes
        .len()
        .checked_add(1)
        .ok_or(LayoutError::GenerationBudget)?;
    let next = generated
        .checked_add(length)
        .ok_or(LayoutError::GenerationBudget)?;
    if next > limit {
        return Err(LayoutError::GenerationBudget);
    }
    component.section(section);
    *generated = next;
    Ok(())
}
