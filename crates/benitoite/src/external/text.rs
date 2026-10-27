//! 外部の関数の診断の型板に埋める語（設計書 02-10「文言の言語」）。

pub(super) const ROOT: &str = "root directory";
pub(super) const ROUTE_TYPED: &str = "typed";
pub(super) const ROUTE_ADAPTER: &str = "adapter";
pub(super) const ROUTE_DYNAMIC: &str = "dynamic";
pub(super) const ROUTE_STATEFUL: &str = "stateful";
pub(super) const FALLBACK_GENERATION: &str = "generation_limit";
pub(super) const FALLBACK_INSTANCES: &str = "core_instance_limit";
pub(super) const FALLBACK_MEMORY32: &str = "memory32_layout";
pub(super) const PACKAGE: &str = "package's wasm directory";
pub(super) const MISSING: &str = "no such file";
pub(super) const TOO_LARGE: &str = "the component exceeds the file size limit of 256 MiB";
pub(super) const INVALID: &str = "invalid WebAssembly component version";
pub(super) const NONE: &str = "(none)";
pub(super) const ITEM: &str = "item";
pub(super) const ITEMS: &str = "items";
pub(super) const PARAMETER: &str = "parameter";
pub(super) const PARAMETERS: &str = "parameters";
pub(super) const UNIT: &str = "no result";
pub(super) const IO_REASONS: &[(std::io::ErrorKind, &str)] = &[
    (std::io::ErrorKind::NotFound, MISSING),
    (std::io::ErrorKind::PermissionDenied, "permission denied"),
    (
        std::io::ErrorKind::NotADirectory,
        "a path component is not a directory",
    ),
    (std::io::ErrorKind::InvalidInput, "invalid file or path"),
];
pub(super) const IO_OTHER: &str = "cannot access the file";

pub(super) fn count(n: usize) -> String {
    format!("{n} {}", if n == 1 { ITEM } else { ITEMS })
}
pub(super) fn parameters(n: usize) -> String {
    format!("{n} {}", if n == 1 { PARAMETER } else { PARAMETERS })
}
pub(super) fn names(names: impl Iterator<Item = String>) -> String {
    let names: Vec<_> = names.collect();
    if names.is_empty() {
        NONE.into()
    } else {
        names.join(", ")
    }
}
pub(super) fn io_reason(error: &std::io::Error) -> &'static str {
    IO_REASONS
        .iter()
        .find_map(|(kind, reason)| (*kind == error.kind()).then_some(*reason))
        .unwrap_or(IO_OTHER)
}

pub(super) const MEMORY_LIMIT: &str = "external memory limit exceeded";
pub(super) const TABLE_LIMIT: &str = "external table limit exceeded";
// Wasmtime 49.0.4 の非公開の HostcallFuelExhausted の Display と一致させる。
// 実際の持ち上げで予算を超えるテストが、依存を更新したときの変更を検出する。
pub(super) const HOSTCALL_FUEL_EXHAUSTED: &str = "too much data is being copied between the host and the guest: fuel allocated for hostcalls has been exhausted";

// Wasmtime 49.0.4 の HandleTable::insert が返す原因と完全一致させる。
// 実コンポーネントの境界テストで、依存を更新したときの変更を検出する。
pub(super) const COMPONENT_HANDLE_LIMIT: &str =
    "cannot allocate another handle: store handle limit exceeded";

pub(super) const TABLE_ELEMENTS: &str = "table elements";
pub(super) const CORE_INSTANCES: &str = "core instances";
pub(super) const CORE_MEMORIES: &str = "core memories";
pub(super) const CORE_TABLES: &str = "core tables";
// Wasmtime 49.0.4 の StoreOpaque::bump_resource_counts の原因と必要数を照合する。
// 実際のインスタンス化の失敗を使うテストで、別のトラップの誤分類も防ぐ。
pub(super) const OBJECT_LIMITS: &[(&str, &str)] = &[
    (
        "resource limit exceeded: instance count too high at ",
        CORE_INSTANCES,
    ),
    (
        "resource limit exceeded: memory count too high at ",
        CORE_MEMORIES,
    ),
    (
        "resource limit exceeded: table count too high at ",
        CORE_TABLES,
    ),
];

pub(super) const DECLARED: &str = "the declaration";
pub(super) const WIT: &str = "WIT";
pub(super) const FIELD: &str = "field";
pub(super) const CASE: &str = "case";
pub(super) const FLAG: &str = "flag";
pub(super) const KEY: &str = "key";
pub(super) const VALUE: &str = "value";
pub(super) fn map_member(member: &str, expected: &str, found: &str) -> String {
    format!("map {member} requires `{expected}` but WIT has `{found}`")
}
const NAME_RULE: &str = "names are compared without `-` and ignoring ASCII case; `_` is preserved";
pub(super) fn duplicate_name(side: &str, name: &str) -> String {
    format!("`{name}` in {side} duplicates another normalized name; {NAME_RULE}")
}
pub(super) fn member_count(kind: &str, owner: &str, declared: usize, wit: usize) -> String {
    format!("WIT has {wit} {kind}s but `{owner}` has {declared}")
}
pub(super) fn member_name(
    kind: &str,
    owner: &str,
    index: usize,
    declared: &str,
    wit: &str,
) -> String {
    format!("{kind} {index} is `{wit}` in WIT but `{declared}` in `{owner}`; {NAME_RULE}")
}
pub(super) fn member_type(kind: &str, owner: &str, name: &str) -> String {
    format!("the type of {kind} `{name}` does not match `{owner}`")
}
pub(super) fn payload(owner: &str, name: &str) -> String {
    format!("the presence of a payload for case `{name}` does not match `{owner}`")
}

pub(super) const TYPE_INTEGER: &str = "Integer";
pub(super) const TYPE_INTEGER8: &str = "Integer8";
pub(super) const TYPE_INTEGER16: &str = "Integer16";
pub(super) const TYPE_INTEGER32: &str = "Integer32";
pub(super) const TYPE_UNSIGNED_INTEGER16: &str = "UnsignedInteger16";
pub(super) const TYPE_UNSIGNED_INTEGER32: &str = "UnsignedInteger32";
pub(super) const TYPE_UNSIGNED_INTEGER64: &str = "UnsignedInteger64";
pub(super) const TYPE_FLOAT32: &str = "Float32";
pub(super) const TYPE_FLOAT: &str = "Float";
pub(super) const TYPE_BOOLEAN: &str = "Boolean";
pub(super) const TYPE_CHARACTER: &str = "Character";
pub(super) const TYPE_STRING: &str = "String";
pub(super) const TYPE_BYTE: &str = "Byte";
pub(super) const TYPE_BYTES: &str = "Bytes";
pub(super) const TYPE_UNIT: &str = "Unit";
pub(super) const TYPE_LIST: &str = "List";
pub(super) const TYPE_OPTION: &str = "Option";
pub(super) const TYPE_RESULT: &str = "Result";
pub(super) const TYPE_PAIR: &str = "Pair";
pub(super) const TYPE_TRIPLE: &str = "Triple";

const DECLARATION: &str = "function {name}({params}) -> {result}";
pub(super) fn declaration(name: &str, params: &str, result: &str) -> String {
    DECLARATION
        .replace("{name}", name)
        .replace("{params}", params)
        .replace("{result}", result)
}
pub(super) fn applied_type(name: &str, args: &str) -> String {
    format!("{name}[{args}]")
}
pub(super) fn argument_name(position: usize) -> String {
    crate::base::parameter_names::positional(position)
}

/// 外部の型の照合で示す WIT の型。
pub(super) const EXTERNAL_TYPE: &str = "external type";
pub(super) fn external_mismatch(
    name: &str,
    decl: Option<&super::ExternalDecl>,
    expected: &str,
    found: &wasmtime::component::Type,
    found_resource: Option<&str>,
    component: &str,
) -> String {
    let (path, export) = decl.map_or(("_", "_"), |d| {
        (d.path.value.as_str(), d.export.value.as_str())
    });
    format!(
        "`{name}` is the resource `{export}` of `{path}`; this position requires `{expected}` of that same resource and component, but this position is `{}` of `{component}` (external functions can only lend external types in parameters)",
        if matches!(found, wasmtime::component::Type::Own(_)) {
            format!("own<{}>", found_resource.unwrap_or("resource"))
        } else if matches!(found, wasmtime::component::Type::Borrow(_)) {
            format!("borrow<{}>", found_resource.unwrap_or("resource"))
        } else {
            super::types::show(found)
        }
    )
}

pub(super) fn resource_drop(name: &str) -> String {
    format!("[resource-drop]{name}")
}
