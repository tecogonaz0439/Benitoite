//! 型付き表層の先行順と元 AST の出現との対応
//! （設計書 02-05「区間解析の式の識別」）。
//! 解析の対応範囲に関係なく子を辿り、停止後は番号を詰め直さない。

use super::input::{BodyInput, InputError, InputTables, SurfaceForm as F};
use crate::base::{BindingId, NodeId, Span};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::types::{ConstValue, Ty};
#[cfg(test)]
use std::collections::BTreeMap;
use std::num::NonZeroU64;

/// 先行順番号は本体名と組にして用いる。AST の番号とは区別する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) struct OperationKey<'a> {
    pub definition: &'a str,
    pub surface_preorder: u64,
}

/// 一つの Surface の出現が指す元の構文。合成関数も元の演算へ対応させる。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) struct Origin {
    pub node: NodeId,
    pub span: Span,
}

/// AST に式として存在しない部分の由来。根は対象演算に含めない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum Synthetic {
    BodyRoot,
    ConstantWrapper,
    ListConcatenate,
    InterpolationConverter,
}

/// 正規化後も AST を借用し、後続が同じ演算のオペランドを読めるようにする。
#[derive(Clone, Copy, Debug)]
pub(in crate::typeck) enum SourceNode<'ast> {
    Expression(&'ast Expr),
    Conditional(&'ast IfExpr),
    WithBinding(&'ast WithExpr, usize),
    Synthetic(Synthetic),
}

/// 部分木の終わりは排他的。途中停止した祖先では end が None のまま残る。
#[derive(Clone, Debug)]
pub(in crate::typeck) struct Occurrence<'ast> {
    pub preorder: u64,
    pub parent: Option<u64>,
    pub end: Option<u64>,
    pub form: F,
    pub origin: Option<Origin>,
    pub source: SourceNode<'ast>,
    /// 定数を展開した子は、その定数の確定済み型表を使う。
    pub type_owner: BindingId,
}

/// 元定義の番号で別本体を命名する。内容の未取得部分を推測で埋めない。
#[derive(Clone, Debug)]
pub(in crate::typeck) struct EmbeddedBody<'ast> {
    pub owner: u64,
    pub ordinal: usize,
    pub body: &'ast Block,
    pub parent_start: Option<u64>,
    pub parent_end: Option<u64>,
}

impl EmbeddedBody<'_> {
    pub fn definition(&self, original: &str) -> String {
        format!("{original}%body:{}:{}", self.owner, self.ordinal)
    }

    /// 合成した根0と、空本体・未取得・範囲外には親の式を割り当てない。
    pub fn parent_key<'a>(&self, original: &'a str, index: u64) -> Option<OperationKey<'a>> {
        let offset = index.checked_sub(1)?;
        let start = self.parent_start?;
        let end = self.parent_end?;
        let preorder = start.checked_add(offset)?;
        (preorder < end).then_some(OperationKey {
            definition: original,
            surface_preorder: preorder,
        })
    }
}

/// 未対応の解析値、対応漏れ、番号を取得する予算の不足は同じ理由にしない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum IdentityStop {
    AnalysisBudget(super::budget::StopReason),
    Depth,
    NumberOverflow,
    Input(InputError),
    MissingReference(NodeId),
    MissingScheme(BindingId),
    MissingConstant(BindingId),
    MissingLiteral(NodeId),
    MissingTryKind(NodeId),
    Unmapped(NodeId),
}

impl IdentityStop {
    /// 番号付けの走査だけ、予算の停止を番号未取得へ分類する。
    pub(super) fn for_numbering(self) -> Self {
        if let Self::AnalysisBudget(reason) = self {
            Self::AnalysisBudget(reason.for_numbering())
        } else {
            self
        }
    }
}

/// 取得済み接頭辞と停止理由。失敗時も既に取得した対応を捨てない。
pub(in crate::typeck) struct IdentityMap<'ast> {
    pub definition: String,
    embedded: Option<Box<(String, EmbeddedBody<'ast>)>>,
    pub occurrences: Occurrences<'ast>,
    pub next: u64,
    pub stopped: Option<IdentityStop>,
}

/// 大きい出現の再確保・複写を避ける、追加専用の番号表。
/// 区画の容量は超過判定に使わず、実在する要素だけを一項として数える。
pub(in crate::typeck) struct Occurrences<'ast> {
    pages: Vec<Vec<StoredOccurrence<'ast>>>,
    len: usize,
}

// AST が持つ番号・位置を出現ごとに複写しない。合成節点の位置だけを別に保存する。
// parent は番号+1、end は正の排他的終端として格納し、u64 の範囲を保つ。
struct StoredOccurrence<'ast> {
    parent: Option<NonZeroU64>,
    end: Option<NonZeroU64>,
    form: F,
    source: StoredSource<'ast>,
    type_owner: BindingId,
}

enum StoredSource<'ast> {
    Expression(&'ast Expr),
    Conditional(&'ast IfExpr),
    WithBinding(&'ast WithExpr, usize),
    ConstantWrapper(&'ast Expr),
    Synthetic(Synthetic, Option<Box<Origin>>),
}

impl<'ast> StoredSource<'ast> {
    fn expand(&self) -> (SourceNode<'ast>, Option<Origin>) {
        match self {
            Self::Expression(e) => (
                SourceNode::Expression(e),
                Some(Origin {
                    node: e.id(),
                    span: e.span(),
                }),
            ),
            Self::Conditional(e) => (
                SourceNode::Conditional(e),
                Some(Origin {
                    node: e.id,
                    span: e.span,
                }),
            ),
            Self::WithBinding(e, index) => (
                SourceNode::WithBinding(e, *index),
                e.binds.get(*index).map(|b| Origin {
                    node: b.id,
                    span: b.span,
                }),
            ),
            Self::ConstantWrapper(e) => (
                SourceNode::Synthetic(Synthetic::ConstantWrapper),
                Some(Origin {
                    node: e.id(),
                    span: e.span(),
                }),
            ),
            Self::Synthetic(kind, origin) => {
                (SourceNode::Synthetic(*kind), origin.as_deref().copied())
            }
        }
    }
}

impl<'ast> Occurrences<'ast> {
    const PAGE_ITEMS: usize = 32;

    fn new() -> Self {
        Self {
            pages: Vec::new(),
            len: 0,
        }
    }

    /// 実在する出現だけを数える。
    pub fn len(&self) -> usize {
        self.len
    }

    /// 取得済みの先行順の位置を読む。
    pub fn get(&self, index: usize) -> Option<Occurrence<'ast>> {
        let entry = self
            .pages
            .get(index / Self::PAGE_ITEMS)?
            .get(index % Self::PAGE_ITEMS)?;
        Self::expand(index, entry)
    }

    fn expand(index: usize, entry: &StoredOccurrence<'ast>) -> Option<Occurrence<'ast>> {
        let (source, origin) = entry.source.expand();
        Some(Occurrence {
            preorder: u64::try_from(index).ok()?,
            parent: entry.parent.map(|p| p.get().saturating_sub(1)),
            end: entry.end.map(NonZeroU64::get),
            form: entry.form,
            origin,
            source,
            type_owner: entry.type_owner,
        })
    }

    fn get_mut(&mut self, index: usize) -> Option<&mut StoredOccurrence<'ast>> {
        self.pages
            .get_mut(index / Self::PAGE_ITEMS)?
            .get_mut(index % Self::PAGE_ITEMS)
    }

    /// 区画の境界に関係なく先行順で読む。
    #[cfg(test)]
    pub fn iter(&self) -> impl Iterator<Item = Occurrence<'ast>> {
        self.pages
            .iter()
            .flatten()
            .enumerate()
            .filter_map(|(index, entry)| Self::expand(index, entry))
    }

    fn push(&mut self, entry: Occurrence<'ast>) -> Result<(), IdentityStop> {
        let parent = match entry.parent {
            Some(p) => NonZeroU64::new(p.checked_add(1).ok_or(IdentityStop::NumberOverflow)?),
            None => None,
        };
        let source = match entry.source {
            SourceNode::Expression(e) if entry.form == F::Const => StoredSource::ConstantWrapper(e),
            SourceNode::Expression(e) => StoredSource::Expression(e),
            SourceNode::Conditional(e) => StoredSource::Conditional(e),
            SourceNode::WithBinding(e, i) => StoredSource::WithBinding(e, i),
            SourceNode::Synthetic(kind) => {
                StoredSource::Synthetic(kind, entry.origin.map(Box::new))
            }
        };
        let stored = StoredOccurrence {
            parent,
            end: entry.end.and_then(NonZeroU64::new),
            form: entry.form,
            source,
            type_owner: entry.type_owner,
        };
        if self
            .pages
            .last()
            .is_none_or(|page| page.len() == Self::PAGE_ITEMS)
        {
            self.pages.push(Vec::with_capacity(Self::PAGE_ITEMS));
        }
        if let Some(page) = self.pages.last_mut() {
            page.push(stored);
            self.len = self.len.saturating_add(1);
        }
        Ok(())
    }
}

/// AST に独立した Expr がない合成節点も、同じ逐次走査で扱う。
#[derive(Clone, Copy)]
pub(super) enum TraversalNode<'ast> {
    Root,
    Expr(&'ast Expr),
    Conditional(&'ast IfExpr),
    With(&'ast WithExpr, usize),
    Synthetic(F, Synthetic, Origin),
}

impl<'ast> IdentityMap<'ast> {
    pub(super) fn new(
        input: &BodyInput<'ast>,
        embedded: Option<(&str, &EmbeddedBody<'ast>)>,
    ) -> Self {
        Self {
            definition: embedded.map_or_else(
                || input.definition.name.clone(),
                |(name, e)| e.definition(name),
            ),
            embedded: embedded.map(|(name, entry)| Box::new((name.to_owned(), entry.clone()))),
            occurrences: Occurrences::new(),
            next: 0,
            stopped: None,
        }
    }

    /// BudgetScan.identify: 番号操作、対応一項の保存、次番号の更新の順で行う。
    /// 枠は呼び出し側の expr/skipExpr が持つ。AST の正規化は計上を増やさない。
    pub(super) fn identify(
        &mut self,
        input: &BodyInput<'ast>,
        tables: &InputTables<'_>,
        node: TraversalNode<'ast>,
        parent: Option<u64>,
        budget: &mut super::budget::Budget,
    ) -> Result<u64, IdentityStop> {
        let mut classifier = Classifier { tables };
        let (form, source, origin) = match node {
            TraversalNode::Root => (F::Block, SourceNode::Synthetic(Synthetic::BodyRoot), None),
            TraversalNode::Expr(e) => {
                input.expression_type(e.id()).map_err(IdentityStop::Input)?;
                (
                    classifier.form(input, e)?,
                    SourceNode::Expression(e),
                    Some(Origin {
                        node: e.id(),
                        span: e.span(),
                    }),
                )
            }
            TraversalNode::Conditional(e) => (
                Classifier::if_form(e),
                SourceNode::Conditional(e),
                Some(Origin {
                    node: e.id,
                    span: e.span,
                }),
            ),
            TraversalNode::With(e, index) => {
                let b = e.binds.get(index).ok_or(IdentityStop::Unmapped(e.id))?;
                (
                    F::With,
                    SourceNode::WithBinding(e, index),
                    Some(Origin {
                        node: b.id,
                        span: b.span,
                    }),
                )
            }
            TraversalNode::Synthetic(form, kind, origin) => {
                (form, SourceNode::Synthetic(kind), Some(origin))
            }
        };
        budget
            .charge(super::budget::Operation::Numbering)
            .map_err(|e| IdentityStop::AnalysisBudget(e.for_numbering()))?;
        budget
            .reserve(
                super::budget::Item::Identity,
                super::budget::Lifetime::Saved,
            )
            .map_err(|e| IdentityStop::AnalysisBudget(e.for_numbering()))?;
        let key = self.next;
        debug_assert_eq!(u64::try_from(self.occurrences.len()).ok(), Some(key));
        let next = key.checked_add(1).ok_or(IdentityStop::NumberOverflow)?;
        self.occurrences.push(Occurrence {
            preorder: key,
            parent,
            end: None,
            form,
            origin,
            source,
            type_owner: input.definition.binding,
        })?;
        self.next = next;
        Ok(key)
    }

    pub(super) fn finish(&mut self, key: u64) {
        if let Some(entry) = usize::try_from(key)
            .ok()
            .and_then(|i| self.occurrences.get_mut(i))
        {
            entry.end = NonZeroU64::new(self.next);
        }
    }

    /// 発見が途中停止して親の終端がなくても、別本体で取得した接頭辞は元へ戻せる。
    pub(super) fn finish_embedding(&mut self) {
        if let Some((_, entry)) = self.embedded.as_deref_mut()
            && entry.parent_end.is_none()
        {
            entry.parent_end = entry
                .parent_start
                .and_then(|start| start.checked_add(self.next.saturating_sub(1)));
        }
    }

    #[cfg(test)]
    pub fn build(
        input: &BodyInput<'ast>,
        tables: &InputTables<'_>,
        constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
        budget: &mut super::budget::Budget,
        fuel: u32,
    ) -> Self {
        let mut map = Self::new(input, None);
        let result =
            super::discovery::identify_all(input, tables, constants, budget, fuel, &mut map);
        map.stopped = result.err();
        map
    }

    pub fn key(&self, preorder: u64) -> Option<OperationKey<'_>> {
        if preorder != 0
            && self
                .embedded
                .as_ref()
                .is_some_and(|entry| entry.1.parent_key(&entry.0, preorder).is_none())
        {
            return None;
        }
        (preorder < self.next).then_some(OperationKey {
            definition: &self.definition,
            surface_preorder: preorder,
        })
    }
}

struct Classifier<'a, 'tables> {
    tables: &'a InputTables<'tables>,
}

#[cfg(test)]
pub(super) mod tests;

impl Classifier<'_, '_> {
    fn reference(&self, node: NodeId) -> Result<(BindingId, &BindingKind), IdentityStop> {
        let id = *self
            .tables
            .resolved
            .refs
            .get(node)
            .ok_or(IdentityStop::MissingReference(node))?;
        let binding = self
            .tables
            .resolved
            .bindings
            .get(id)
            .ok_or(IdentityStop::MissingReference(node))?;
        Ok((id, &binding.kind))
    }

    fn name_form(&self, input: &BodyInput<'_>, n: &NameExpr) -> Result<F, IdentityStop> {
        let (id, kind) = self.reference(n.id)?;
        let constrained = || {
            self.tables
                .schemes
                .get(id)
                .map(|s| !s.class_constraints.is_empty())
                .ok_or(IdentityStop::MissingScheme(id))
        };
        match kind {
            BindingKind::Local(_) => Ok(F::Local),
            BindingKind::Const => Ok(F::Const),
            BindingKind::Method { .. } => Ok(F::MethName),
            BindingKind::Fn | BindingKind::ImplFn { .. } | BindingKind::Field { .. } => {
                Ok(if constrained()? {
                    F::FunDicts
                } else {
                    F::FunName
                })
            }
            BindingKind::BuiltinFn(_) => Ok(F::PrimName),
            BindingKind::Op { .. } => Ok(
                if Some(id) == self.tables.resolved.stdlib("Benitoite.Failure.raise") {
                    F::Raise
                } else if self.tables.resolved.builtin_ops.get(id).is_some() {
                    F::PrimName
                } else if constrained()? {
                    F::OpDicts
                } else {
                    F::OpName
                },
            ),
            BindingKind::Ctor { .. } | BindingKind::Record => {
                let ty = input.expression_type(n.id).map_err(IdentityStop::Input)?;
                Ok(if matches!(ty, Ty::Fn(f) if !f.params.is_empty()) {
                    F::ConValue
                } else {
                    F::NullCon
                })
            }
            BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::ExternalType
            | BindingKind::Trait
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. } => Err(IdentityStop::Unmapped(n.id)),
        }
    }

    fn unary_form(&self, unary: &UnaryExpr) -> Result<F, IdentityStop> {
        if unary.op == UnOp::Not {
            return Ok(F::Not);
        }
        if !matches!(unary.operand.as_ref(), Expr::Lit(_)) {
            return Ok(F::Neg);
        }
        let value = self
            .tables
            .literals
            .get(unary.id)
            .ok_or(IdentityStop::MissingLiteral(unary.id))?;
        Ok(match value {
            // -0 は Convert の整数 literal と同じ形であり、子を作らない。
            ConstValue::Integer(n) => {
                if *n < 0 {
                    F::NegInt
                } else {
                    F::Literal
                }
            }
            ConstValue::Integer8(_) => F::NegInteger8,
            ConstValue::Integer16(_) => F::NegInteger16,
            ConstValue::Integer32(_) => F::NegInteger32,
            ConstValue::Float(_) => F::NegFloat,
            ConstValue::Float32(_) => F::NegFloat32,
            ConstValue::Decimal(_) => F::NegDecimal,
            ConstValue::String(_)
            | ConstValue::Character(_)
            | ConstValue::Boolean(_)
            | ConstValue::Unit
            | ConstValue::Byte(_)
            | ConstValue::Ctor { .. }
            | ConstValue::List(_)
            | ConstValue::Map(_)
            | ConstValue::Set(_)
            | ConstValue::UnsignedInteger16(_)
            | ConstValue::UnsignedInteger32(_)
            | ConstValue::UnsignedInteger64(_) => return Err(IdentityStop::Unmapped(unary.id)),
        })
    }

    fn call_form(&mut self, call: &CallExpr) -> Result<F, IdentityStop> {
        if self.tables.resolved.builder_calls.get(call.id).is_some() {
            return Ok(F::BuilderOp);
        }
        let constructor = if let Expr::Name(n) = call.callee.as_ref() {
            matches!(
                self.reference(n.id)?.1,
                BindingKind::Ctor { .. } | BindingKind::Record
            )
        } else {
            false
        };
        let mut holes = false;
        for arg in &call.args {
            holes |= arg.placeholder().is_some();
        }
        Ok(match (constructor, holes) {
            (true, true) => F::PartialCon,
            (true, false) => F::ConCall,
            (false, true) => F::PartialCall,
            (false, false) => F::Call,
        })
    }

    fn form(&mut self, input: &BodyInput<'_>, expr: &Expr) -> Result<F, IdentityStop> {
        Ok(match expr {
            Expr::Lit(_) => F::Literal,
            Expr::Unit(_) => F::Unit,
            Expr::Name(n) => return self.name_form(input, n),
            Expr::Paren(_) => F::Paren,
            Expr::Call(c) => return self.call_form(c),
            Expr::Pipe(_) => F::Pipe,
            Expr::Unary(u) => return self.unary_form(u),
            Expr::Binary(b) => match b.op {
                BinOp::And => F::And,
                BinOp::Or => F::Or,
                BinOp::Add
                | BinOp::Sub
                | BinOp::Mul
                | BinOp::Div
                | BinOp::IntDiv
                | BinOp::Mod
                | BinOp::Eq
                | BinOp::Ne
                | BinOp::Lt
                | BinOp::Le
                | BinOp::Gt
                | BinOp::Ge => F::Binary,
            },
            Expr::List(l) => {
                let mut spread = false;
                for elem in &l.elems {
                    spread |= matches!(elem, ListElem::Spread(_));
                }
                if spread { F::ListSpread } else { F::List }
            }
            Expr::Lambda(_) => F::Lambda,
            Expr::If(i) => Self::if_form(i),
            Expr::Match(_) => F::Match,
            Expr::Return(_) => F::Return,
            Expr::Interp(_) => F::Interpolation,
            Expr::Record(r) => {
                if r.base.is_some() {
                    F::RecordUpdate
                } else {
                    F::Record
                }
            }
            Expr::Try(t) => match (
                input
                    .try_kind(t.id)
                    .ok_or(IdentityStop::MissingTryKind(t.id))?,
                &t.action,
            ) {
                (super::super::TryKind::Result, TryAction::Die { .. }) => F::TryResultDie,
                (super::super::TryKind::Option, TryAction::Die { .. }) => F::TryOptionDie,
                (super::super::TryKind::Result, _) => F::TryResult,
                (super::super::TryKind::Option, _) => F::TryOption,
            },
            Expr::Block(_) => F::Block,
            Expr::Lazy(_) => F::Lazy,
            Expr::With(_) => F::With,
            Expr::Handle(h) => {
                if input.failure_handler(h.id) {
                    F::HandleFail
                } else {
                    F::Handle
                }
            }
            Expr::Resume(_) => F::Resume,
            Expr::Error(e) => return Err(IdentityStop::Unmapped(e.id)),
        })
    }

    fn if_form(expr: &IfExpr) -> F {
        match &expr.else_branch {
            Some(ElseBranch::If(_)) => F::ElseIf,
            Some(ElseBranch::Block(_)) => F::IfElse,
            None => F::IfOnly,
        }
    }
}
