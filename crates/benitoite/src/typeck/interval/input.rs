//! 型解決後・finish 前の本体の読み取りと定義の列挙
//! （設計書 02-05「区間解析の内部入力」）。

use super::super::context::Body;
use crate::base::{BindingId, BindingMap, NodeId};
use crate::resolve::ResolveOutput;
use crate::types::{ConstValue, Scheme, Ty};
use std::collections::{BTreeMap, BTreeSet};

/// 型検査済みのリテラル値を、種類と数学的な端点として読む。
/// 負の幅付きの葉も共有表の値を使い、元 NodeId と Span は呼び出し側で保つ。
pub(super) fn integer_literal(value: &ConstValue) -> Option<(super::domain::IntKind, i128)> {
    use super::domain::IntKind as K;
    Some(match value {
        ConstValue::Integer(v) => (K::Integer64, i128::from(*v)),
        ConstValue::Integer8(v) => (K::Integer8, i128::from(*v)),
        ConstValue::Integer16(v) => (K::Integer16, i128::from(*v)),
        ConstValue::Integer32(v) => (K::Integer32, i128::from(*v)),
        ConstValue::UnsignedInteger16(v) => (K::UnsignedInteger16, i128::from(*v)),
        ConstValue::UnsignedInteger32(v) => (K::UnsignedInteger32, i128::from(*v)),
        ConstValue::UnsignedInteger64(v) => (K::UnsignedInteger64, i128::from(*v)),
        ConstValue::Float(_)
        | ConstValue::String(_)
        | ConstValue::Character(_)
        | ConstValue::Boolean(_)
        | ConstValue::Unit
        | ConstValue::Byte(_)
        | ConstValue::Decimal(_)
        | ConstValue::Ctor { .. }
        | ConstValue::List(_)
        | ConstValue::Map(_)
        | ConstValue::Set(_)
        | ConstValue::Float32(_) => return None,
    })
}

pub(in crate::typeck) use super::super::source_input::{
    BodySource, Definition, InputError, SourceOrder, definitions,
};

/// solver と Body の可変参照を外へ持ち越さない、確定済みの型の写し。
pub(in crate::typeck) struct BodyInput<'ast> {
    pub definition: Definition<'ast>,
    expression_types: Vec<(NodeId, Ty)>,
    local_types: Vec<(BindingId, Ty)>,
    interpolation_types: Vec<(NodeId, Ty)>,
    try_kinds: BTreeMap<NodeId, super::super::TryKind>,
    failure_handlers: BTreeSet<NodeId>,
    pub(super) range: Option<Box<super::flow::range::Tables>>,
}

impl<'ast> BodyInput<'ast> {
    /// 呼び出し側は consts::warnings と同じ valid 条件を渡す。
    /// E0208 で finish が出力表を転記しない場合も、既存の出力表には頼らない。
    pub fn collect(
        definition: Definition<'ast>,
        body: &Body<'_, '_>,
        valid: bool,
    ) -> Result<Self, InputError> {
        if !valid
            || body
                .diagnostics
                .iter()
                .any(crate::diag::Diagnostic::is_error)
        {
            return Err(InputError::InvalidBody);
        }
        let owner = match definition.source {
            BodySource::Function { declaration, .. } => Some(declaration.id),
            BodySource::Constant(_) => None,
        };
        if body.module != definition.order.module || body.owner != owner {
            return Err(InputError::WrongBody);
        }
        let finalize = |node, ty| {
            // 多相の呼び出し先には、正常な本体でも未解決の型引数が残る。
            // finish と同じ具体化を使い、その位置から値の事実を作らない
            // （設計書 02-05「区間解析の内部入力」）。
            body.solver
                .finalize_valid(ty, body.decls.resolved)
                .ok_or(InputError::InvalidType(node))
        };
        let expression_types = snapshot_types(body.expr_types.iter(), finalize)?;
        let local_types = snapshot_types(body.locals.iter(), |_, ty| {
            finalize(definition.source.node(), ty)
        })?;
        let interpolation_types = snapshot_types(body.interp_types.iter(), finalize)?;
        let try_kinds = body
            .try_kinds
            .iter()
            .map(|(node, (kind, _))| (node, *kind))
            .collect();
        // failure_type の具体化は finish 内なので、ここでは解決済みの対象を読む。
        let failure_handlers = body
            .failure_handles
            .iter()
            .map(|(node, _, _)| *node)
            .collect();
        for param in definition.source.params() {
            if type_at(&expression_types, &param.id).is_none() {
                return Err(InputError::MissingType(param.id));
            }
        }
        if let BodySource::Constant(c) = definition.source
            && type_at(&expression_types, &c.value.id()).is_none()
        {
            return Err(InputError::MissingType(c.value.id()));
        }
        let range = super::flow::range::Tables::collect(&definition, body);
        Ok(Self {
            range,
            definition,
            expression_types,
            local_types,
            interpolation_types,
            try_kinds,
            failure_handlers,
        })
    }

    pub fn expression_type(&self, node: NodeId) -> Result<&Ty, InputError> {
        type_at(&self.expression_types, &node).ok_or(InputError::MissingType(node))
    }

    pub fn local_type(&self, binding: BindingId) -> Option<&Ty> {
        type_at(&self.local_types, &binding)
    }

    pub fn interpolation_type(&self, node: NodeId) -> Result<&Ty, InputError> {
        type_at(&self.interpolation_types, &node).ok_or(InputError::MissingType(node))
    }

    pub fn try_kind(&self, node: NodeId) -> Option<super::super::TryKind> {
        self.try_kinds.get(&node).copied()
    }

    pub fn failure_handler(&self, node: NodeId) -> bool {
        self.failure_handlers.contains(&node)
    }
}

// 元の表が返す件数を使い、小さい本体でも Vec の最小伸長分を繰り返し確保しない。
fn snapshot_types<'a, K: Copy>(
    entries: impl Iterator<Item = (K, &'a super::super::infer::ITy)>,
    mut finalize: impl FnMut(K, &'a super::super::infer::ITy) -> Result<Ty, InputError>,
) -> Result<Vec<(K, Ty)>, InputError> {
    let mut out = Vec::with_capacity(entries.size_hint().0);
    for (key, ty) in entries {
        out.push((key, finalize(key, ty)?));
    }
    Ok(out)
}

// Body の番号順の表を、そのまま更新しない配列へ具体化する。小さな本体ごとに
// 木の一節点分を確保しない（設計書 02-05「区間解析の内部入力」）。
fn type_at<'a, K: Ord>(types: &'a [(K, Ty)], key: &K) -> Option<&'a Ty> {
    let index = types.binary_search_by(|(stored, _)| stored.cmp(key)).ok()?;
    types.get(index).map(|(_, ty)| ty)
}

/// 全定数の評価後に借りる共有表。収集時の未完成の定数表を複製しない。
pub(in crate::typeck) struct InputTables<'a> {
    pub resolved: &'a ResolveOutput,
    pub constants: &'a BindingMap<ConstValue>,
    pub literals: &'a crate::base::NodeMap<ConstValue>,
    pub range_bounds: &'a crate::base::NodeMap<(ConstValue, ConstValue)>,
    pub schemes: &'a BindingMap<Scheme>,
}

/// Surface.Expr の53構成子。AST の構成子数や子を辿るかどうかと混同しない。
/// 合成・埋め込み・先行モデルの形も列挙し、対応付けは identity が受け持つ。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum SurfaceForm {
    Local,
    BuilderOp,
    Const,
    FunName,
    FunDicts,
    MethName,
    PrimName,
    OpName,
    OpDicts,
    Raise,
    HandleFail,
    NullCon,
    ConValue,
    Literal,
    NegInt,
    NegFloat,
    NegDecimal,
    NegInteger8,
    NegInteger16,
    NegInteger32,
    NegFloat32,
    Unit,
    Paren,
    Block,
    ConCall,
    Record,
    RecordUpdate,
    Call,
    Pipe,
    PartialCall,
    PartialCon,
    Binary,
    Neg,
    Not,
    And,
    Or,
    List,
    ListSpread,
    Interpolation,
    Lambda,
    IfElse,
    ElseIf,
    IfOnly,
    Match,
    Return,
    TryResult,
    TryOption,
    TryResultDie,
    TryOptionDie,
    With,
    Lazy,
    Handle,
    Resume,
}

/// 親への伝播・独立入力・別本体の分類。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum Handling {
    /// literal の型、binary の演算とオペランド型は別途制限する。
    Transfer,
    UnknownValue,
    IndependentExpressions,
    /// handler の節は別本体。保護された本体だけを独立入力にする。
    IndependentBlocks,
    SeparateBody,
}

impl SurfaceForm {
    pub fn handling(self) -> Handling {
        match self {
            Self::Local
            | Self::Const
            | Self::Literal
            | Self::NegInt
            | Self::NegInteger8
            | Self::NegInteger16
            | Self::NegInteger32
            | Self::Unit
            | Self::Paren
            | Self::Block
            | Self::Binary
            | Self::Not
            | Self::And
            | Self::Or
            | Self::IfElse
            | Self::ElseIf
            | Self::IfOnly
            | Self::Match
            | Self::Return => Handling::Transfer,
            Self::FunName
            | Self::FunDicts
            | Self::MethName
            | Self::PrimName
            | Self::OpName
            | Self::OpDicts
            | Self::Raise
            | Self::NullCon
            | Self::ConValue
            | Self::NegFloat
            | Self::NegDecimal
            | Self::NegFloat32 => Handling::UnknownValue,
            Self::BuilderOp
            | Self::ConCall
            | Self::Record
            | Self::RecordUpdate
            | Self::Call
            | Self::Pipe
            | Self::PartialCall
            | Self::PartialCon
            | Self::Neg
            | Self::List
            | Self::ListSpread
            | Self::Interpolation
            | Self::TryResult
            | Self::TryOption
            | Self::TryResultDie
            | Self::TryOptionDie
            | Self::Resume => Handling::IndependentExpressions,
            Self::With | Self::HandleFail | Self::Handle => Handling::IndependentBlocks,
            Self::Lambda | Self::Lazy => Handling::SeparateBody,
        }
    }
}
