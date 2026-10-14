//! 外部の関数と型の宣言、コンポーネントの照合（設計書 03-10）。
//! Wasmtime の状態は検査ごとに作り、照合の結果には平らなデータだけを残す。

use crate::base::{ModuleId, NodeId};
use crate::syntax::ast::StrArg;
use std::sync::Arc;

pub(crate) mod adapter;
pub(crate) mod check;
mod convert;
pub(crate) mod expansion;
pub(crate) mod path;
mod runtime;
pub(crate) mod stats;
mod text;
mod typed;
pub use runtime::{ExternalFailure, ExternalRuntime, Limits, call};
mod types;
pub(crate) use check::check_component;
pub use check::check_externals;

/// 属性の文字列と照合の結果（設計書 03-10「照合」）。
#[derive(Clone, Debug)]
pub struct ExternalDecl {
    pub module: ModuleId,
    pub decl: NodeId,
    pub kind: StrArg,
    pub path: StrArg,
    pub export: StrArg,
    /// 照合の前と、誤りを出した宣言では None。
    pub spec: Option<Arc<ExternalSpec>>,
    /// 外部の型の照合結果。関数と未照合の型では None。
    pub external_type: Option<Arc<ExternalTypeSpec>>,
}

/// 照合を通った外部の型。Wasmtime の型は検査の中だけで使う。
#[derive(Clone, Debug)]
pub struct ExternalTypeSpec {
    pub id: u32,
    pub component: Arc<ComponentSource>,
    pub instance: Option<String>,
    pub name: String,
}

/// 実行時にも使う宣言の型と WIT の型の対応（設計書 03-10「型の対応」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum WitPlan {
    S64,
    F64,
    Bool,
    Char,
    String,
    U8,
    Bytes,
    /// 引数で借りる外部の型の束縛の番号。
    Borrow(u32),
    /// 戻り値で所有する外部の型の束縛の番号。
    Own(u32),
    List(Box<WitPlan>),
    /// WIT の鍵と値を言語の Map の組へ対応させる。
    Map(Box<WitPlan>, Box<WitPlan>),
    Option(Box<WitPlan>),
    /// Unit の側は WIT で省く。
    Result {
        ok: Option<Box<WitPlan>>,
        err: Option<Box<WitPlan>>,
    },
    Tuple(Vec<WitPlan>),
    /// 一構成子の data のタグと、位置で対応する WIT の tuple の要素。
    ConstructorTuple {
        tag: u32,
        fields: Vec<WitPlan>,
    },
    /// variant の複数の欄をまとめる ABI 専用の tuple。言語の組は作らない。
    TupleFields(Vec<WitPlan>),
    /// WIT の欄の名前と順を保存する。
    Record {
        fields: Vec<(String, WitPlan)>,
    },
    /// WIT の場合の名前と、宣言の構成子のタグを対応させる。
    Variant {
        cases: Vec<(String, u32, Option<Box<WitPlan>>)>,
    },
    /// 引数のない構成子を WIT の enum に対応させる。
    Enum {
        cases: Vec<(String, u32)>,
    },
    S8,
    S16,
    S32,
    U16,
    U32,
    U64,
    F32,
    /// 宣言順の WIT の項目番号と、引数なしの構成子のタグを対応させる。
    Flags {
        cases: Vec<(String, u32)>,
    },
}

/// 宣言の型に応じて選ぶ呼び出しの経路（設計書 03-10「実行」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum ExternalRoute {
    Dynamic,
    Stateful,
    Typed(TypedShape),
}

/// 型付きの呼び出しで具体化する引数と戻り値の種類。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TypedShape {
    pub params: Vec<TypedKind>,
    pub result: TypedKind,
}

/// 型付きの呼び出しに対応する単独の型。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TypedKind {
    S64,
    F64,
    String,
    Bytes,
    ListU8,
    ListS64,
    ListF64,
}
impl TypedKind {
    fn of(plan: &WitPlan) -> Option<Self> {
        match plan {
            WitPlan::S64 => Some(Self::S64),
            WitPlan::F64 => Some(Self::F64),
            WitPlan::String => Some(Self::String),
            WitPlan::Bytes => Some(Self::Bytes),
            WitPlan::List(inner) => match inner.as_ref() {
                WitPlan::U8 => Some(Self::ListU8),
                WitPlan::S64 => Some(Self::ListS64),
                WitPlan::F64 => Some(Self::ListF64),
                WitPlan::S8
                | WitPlan::S16
                | WitPlan::S32
                | WitPlan::U16
                | WitPlan::U32
                | WitPlan::U64
                | WitPlan::F32
                | WitPlan::Bool
                | WitPlan::Char
                | WitPlan::String
                | WitPlan::Bytes
                | WitPlan::Own(_)
                | WitPlan::Borrow(_)
                | WitPlan::List(_)
                | WitPlan::Option(_)
                | WitPlan::Result { .. }
                | WitPlan::Map(_, _)
                | WitPlan::Tuple(_)
                | WitPlan::ConstructorTuple { .. }
                | WitPlan::TupleFields(_)
                | WitPlan::Record { .. }
                | WitPlan::Variant { .. }
                | WitPlan::Enum { .. }
                | WitPlan::Flags { .. } => None,
            },
            WitPlan::Own(_)
            | WitPlan::Borrow(_)
            | WitPlan::S8
            | WitPlan::S16
            | WitPlan::S32
            | WitPlan::U16
            | WitPlan::U32
            | WitPlan::U64
            | WitPlan::F32
            | WitPlan::Bool
            | WitPlan::Char
            | WitPlan::U8
            | WitPlan::Option(_)
            | WitPlan::Result { .. }
            | WitPlan::Map(_, _)
            | WitPlan::Tuple(_)
            | WitPlan::ConstructorTuple { .. }
            | WitPlan::TupleFields(_)
            | WitPlan::Record { .. }
            | WitPlan::Variant { .. }
            | WitPlan::Enum { .. }
            | WitPlan::Flags { .. } => None,
        }
    }
}
impl ExternalRoute {
    /// WIT の照合後に、型付きの呼び出しの対象を決める。
    pub fn of(params: &[WitPlan], result: Option<&WitPlan>) -> Self {
        let mut pending: Vec<_> = params.iter().chain(result).collect();
        while let Some(p) = pending.pop() {
            match p {
                WitPlan::Own(_) | WitPlan::Borrow(_) => return Self::Stateful,
                WitPlan::List(p) | WitPlan::Option(p) => pending.push(p),
                WitPlan::Map(key, value) => pending.extend([key.as_ref(), value.as_ref()]),
                WitPlan::Result { ok, err } => {
                    pending.extend(ok.iter().chain(err).map(Box::as_ref))
                }
                WitPlan::Tuple(ps) | WitPlan::TupleFields(ps) => pending.extend(ps),
                WitPlan::ConstructorTuple { fields, .. } => pending.extend(fields),
                WitPlan::Record { fields } => pending.extend(fields.iter().map(|(_, p)| p)),
                WitPlan::Variant { cases } => {
                    pending.extend(cases.iter().filter_map(|(_, _, p)| p.as_deref()))
                }
                WitPlan::S64
                | WitPlan::S8
                | WitPlan::S16
                | WitPlan::S32
                | WitPlan::U16
                | WitPlan::U32
                | WitPlan::U64
                | WitPlan::F32
                | WitPlan::F64
                | WitPlan::Bool
                | WitPlan::Char
                | WitPlan::String
                | WitPlan::U8
                | WitPlan::Bytes
                | WitPlan::Enum { .. }
                | WitPlan::Flags { .. } => {}
            }
        }
        if params.len() > 3 {
            return Self::Dynamic;
        }
        let Some(result) = result.and_then(TypedKind::of) else {
            return Self::Dynamic;
        };
        let Some(params) = params.iter().map(TypedKind::of).collect::<Option<Vec<_>>>() else {
            return Self::Dynamic;
        };
        // 数のリストを含む 3 引数の具体化を省き、実行ファイルの増分を抑える
        // （設計書 03-10「実行」）。Bytes と List[Byte] の具体化は共有する。
        if params.len() == 3
            && params
                .iter()
                .any(|p| matches!(p, TypedKind::ListS64 | TypedKind::ListF64))
        {
            return Self::Dynamic;
        }
        Self::Typed(TypedShape { params, result })
    }
}

/// コンポーネントの名前と読み込んだバイト列。
#[derive(Clone)]
pub struct ComponentSource {
    pub display: String,
    pub bytes: Arc<[u8]>,
}
impl std::fmt::Debug for ComponentSource {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ComponentSource")
            .field("display", &self.display)
            .field("bytes", &self.bytes.len())
            .finish()
    }
}

/// 照合を通った外部の関数。プログラムの中の番号だけで同一性を比べる。
#[derive(Clone)]
pub struct ExternalSpec {
    pub id: u32,
    pub function: String,
    pub component: Arc<ComponentSource>,
    /// インターフェースの書き出しの名前。world の直下なら None。
    pub instance: Option<String>,
    /// 関数の名前。インターフェースの中なら `#` の後半だけを持つ。表示には `export_name` を使う。
    pub export: String,
    pub params: Vec<WitPlan>,
    /// None は Unit（戻り値なし）。
    pub result: Option<WitPlan>,
    /// 照合済みの型から決めた経路。Wasmtime の状態は含めない。
    pub route: ExternalRoute,
    /// Dynamic の宣言で使う補助、または生成・配置の上限による動的への振り分け。
    pub(crate) adapter: Option<Arc<adapter::runtime::Binding>>,
}
impl PartialEq for ExternalSpec {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}
impl Eq for ExternalSpec {}
impl ExternalSpec {
    /// 診断と逆アセンブルでは、宣言に書いた二段の名前を示す。
    pub(crate) fn export_name(&self) -> String {
        self.instance.as_ref().map_or_else(
            || self.export.clone(),
            |instance| format!("{instance}#{}", self.export),
        )
    }
}
impl std::fmt::Debug for ExternalSpec {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ExternalSpec")
            .field("id", &self.id)
            .field("function", &self.function)
            .field("component", &self.component)
            .field("instance", &self.instance)
            .field("export", &self.export)
            .field("params", &self.params)
            .field("result", &self.result)
            .field("route", &self.route)
            .finish()
    }
}

/// 検査と実行で同じコードをコンパイルするための設定（設計書 03-10「照合」）。
pub fn engine_config() -> wasmtime::Config {
    let mut config = wasmtime::Config::new();
    config
        .consume_fuel(true)
        .epoch_interruption(true)
        .wasm_component_model_map(true)
        .max_wasm_stack(512 * 1024)
        .wasm_backtrace_max_frames(None);
    config
}

#[cfg(test)]
mod tests;
