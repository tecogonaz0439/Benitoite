//! 型の確定に依存しない元定義の列挙と本体の識別
//! （設計書 02-05「Scope の必須判定の入力」）。

use crate::base::{BindingId, ModuleId, NodeId};
use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::{Block, ConstDecl, FnDecl, Item, Module, Param};

/// 定数の評価順・本体の検査完了順から独立した、元の定義の順。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(in crate::typeck) struct SourceOrder {
    pub module: ModuleId,
    pub declaration: usize,
    pub method: Option<usize>,
}

/// 定数の値は Surface.Block.last に包む。AST の複製や合成 NodeId は作らない。
#[derive(Clone, Copy, Debug)]
pub(in crate::typeck) enum BodySource<'ast> {
    Constant(&'ast ConstDecl),
    Function {
        declaration: &'ast FnDecl,
        body: &'ast Block,
    },
}

impl<'ast> BodySource<'ast> {
    pub fn node(self) -> NodeId {
        match self {
            Self::Constant(c) => c.id,
            Self::Function { declaration, .. } => declaration.id,
        }
    }

    pub fn params(self) -> &'ast [Param] {
        match self {
            Self::Constant(_) => &[],
            Self::Function { declaration, .. } => &declaration.params,
        }
    }
}

/// 元 AST の定義一つ。impl のメソッドも kind は function とする。
#[derive(Clone, Debug)]
pub(in crate::typeck) struct Definition<'ast> {
    pub order: SourceOrder,
    pub binding: BindingId,
    pub name: String,
    pub source: BodySource<'ast>,
}

/// 不正な入力は Top と区別する。予算による停止・未同定は番号付けの段で扱う。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum InputError {
    InvalidBody,
    WrongBody,
    MissingBinding(NodeId),
    MissingModule(ModuleId),
    WrongModule(NodeId),
    MissingType(NodeId),
    InvalidType(NodeId),
}

/// 列挙で失敗した定義も、本体の受理の対象から落とさないための由来。
#[derive(Debug)]
pub(in crate::typeck) struct DefinitionFailure {
    pub name: String,
    pub node: NodeId,
    pub binding: Option<BindingId>,
    pub reason: InputError,
}

/// 区間解析は従来と同じ入力誤りを読み、Scope は失敗した定義の由来も保つ。
pub(in crate::typeck) fn definitions<'ast>(
    asts: &'ast [Module],
    modules: &'ast ModuleTable,
    resolved: &'ast ResolveOutput,
) -> impl Iterator<Item = Result<Definition<'ast>, InputError>> + 'ast {
    definition_inputs(asts, modules, resolved).map(|d| d.map_err(|error| error.reason))
}

/// 型の確定を待たずに対象を列挙するための候補。有効性は利用側が検査する。
/// 外部宣言・trait の署名を含めず、検査用の生成関数は通常の Item::Fn として含む。
pub(in crate::typeck) fn definition_inputs<'ast>(
    asts: &'ast [Module],
    modules: &'ast ModuleTable,
    resolved: &'ast ResolveOutput,
) -> impl Iterator<Item = Result<Definition<'ast>, DefinitionFailure>> + 'ast {
    asts.iter().flat_map(move |ast| {
        ast.decls.iter().enumerate().flat_map(move |(index, top)| {
            let (single, methods) = match &top.item {
                Item::Const(c) => (Some(BodySource::Constant(c)), None),
                Item::Fn(f) => (
                    f.body.as_ref().map(|body| BodySource::Function {
                        declaration: f,
                        body,
                    }),
                    None,
                ),
                Item::Impl(i) => (None, Some(i.fns.as_slice())),
                Item::Data(_)
                | Item::Alias(_)
                | Item::ExternalType(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Error(_) => (None, None),
            };
            let methods = methods
                .into_iter()
                .flatten()
                .enumerate()
                .filter_map(|(method, f)| {
                    f.decl.body.as_ref().map(|body| {
                        (
                            Some(method),
                            BodySource::Function {
                                declaration: &f.decl,
                                body,
                            },
                        )
                    })
                });
            single
                .into_iter()
                .map(|source| (None, source))
                .chain(methods)
                .map(move |(method, source)| {
                    let node = source.node();
                    let result = (|| {
                        let binding = *resolved
                            .decls
                            .get(node)
                            .ok_or(InputError::MissingBinding(node))?;
                        let declaration = resolved
                            .bindings
                            .get(binding)
                            .ok_or(InputError::MissingBinding(node))?;
                        let module = declaration.module;
                        // AST 配列は ModuleId 順。別モジュールの回復値を受け入れない。
                        if usize::try_from(module.0)
                            .ok()
                            .and_then(|i| asts.get(i))
                            .map(|m| m.id)
                            != Some(ast.id)
                        {
                            return Err(InputError::WrongModule(node));
                        }
                        let module_name = modules
                            .get(module)
                            .ok_or(InputError::MissingModule(module))?
                            .name
                            .dotted();
                        let name = match method {
                            Some(method) => {
                                format!("{module_name}%impl:{index}:{method}:{}", declaration.name)
                            }
                            None => format!("{module_name}.{}", declaration.name),
                        };
                        Ok(Definition {
                            order: SourceOrder {
                                module,
                                declaration: index,
                                method,
                            },
                            binding,
                            name,
                            source,
                        })
                    })();
                    result.map_err(|reason| {
                        let module_name = modules
                            .get(ModuleId::of_file(ast.file))
                            .map(|m| m.name.dotted())
                            .unwrap_or_else(|| format!("<module:{}>", ast.file.0));
                        let short = match source {
                            BodySource::Constant(c) => &c.name.text,
                            BodySource::Function { declaration, .. } => &declaration.name.text,
                        };
                        let name = match method {
                            Some(method) => format!("{module_name}%impl:{index}:{method}:{short}"),
                            None => format!("{module_name}.{short}"),
                        };
                        DefinitionFailure {
                            name,
                            node,
                            binding: resolved.decls.get(node).copied(),
                            reason,
                        }
                    })
                })
        })
    })
}
