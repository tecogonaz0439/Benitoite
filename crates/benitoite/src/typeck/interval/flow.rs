//! 束縛・局所参照・ブロックの正常値の伝播
//! （設計書 02-05「区間解析の局所環境」）。
//! 対象算術の候補は値と分けて保存する
//! （設計書 02-05「区間解析のInteger64算術」）。
//! 比較と短絡条件の事実を枝の内側で使い、正常値だけを凸に合流する
//! （設計書 02-05「区間解析の単一比較とifの合流」）。

mod fixed_domain;
mod independent;
mod matching;
pub(super) mod range;
mod widths;

use super::arithmetic::{self, Candidate, Cause, TargetOperation};
use super::budget::{Budget, Item, Lifetime, Operation};
use super::discovery::SkipInput;
use super::domain::{IntKind, Interval};
use super::environment::{Environment, Slot};
use super::identity::{IdentityMap, IdentityStop, TraversalNode as Node};
use super::input::{BodyInput, BodySource, InputError, InputTables};
use super::origins::Provenance;
use crate::base::{BindingId, NodeId, Span};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::types::builtin::BuiltinTypeId as B;
use crate::types::{ConstValue, Ty, TyCon};
use std::collections::BTreeMap;

/// 正常な継続と return を分ける。returned は関数間の推論には使用しない。
#[derive(Clone, Debug)]
pub(in crate::typeck) struct Approx {
    pub normal: Interval,
    provenance: Provenance,
    pub returned: Interval,
    pub live: bool,
    /// Integer64 だけの正常値。六幅の正常値は widths から別に読む。
    pub only_integer: bool,
    /// Lean の nonIntegerOther。六幅の整数と Unit 等の正常値を区別する。
    non_integer_other: bool,
    pub boolean: (bool, bool),
    pub may_fail: bool,
    pub unsupported: bool,
    widths: widths::Widths,
    returned_widths: widths::Widths,
}

impl Approx {
    /// 任意の交換記録先だけから呼び、解析の値・予算・公開型を変更しない。
    pub(super) fn observed(&self) -> serde_json::Value {
        use serde_json::json;
        let interval = |value: Interval| match value.bounds() {
            None => json!("bottom"),
            Some((lo, hi)) => json!({"closed":[lo.to_string(), hi.to_string()]}),
        };
        let widths: serde_json::Map<_, _> = IntKind::WIDTHS
            .into_iter()
            .map(|kind| (format!("{kind:?}"), interval(self.range_kind(kind))))
            .collect();
        let other = self.non_integer_other
            || IntKind::WIDTHS
                .into_iter()
                .any(|kind| !self.range_kind(kind).is_bottom());
        json!({"integer":interval(self.normal), "boolean":[self.boolean.0,self.boolean.1],
            "other":other,"widths":widths,"nonIntegerOther":self.non_integer_other,
            "mayFail":self.may_fail, "returnedInteger":interval(self.returned)})
    }

    fn unknown() -> Self {
        Self {
            normal: Interval::top(),
            provenance: Provenance::default(),
            returned: Interval::bottom(),
            live: true,
            only_integer: false,
            non_integer_other: true,
            boolean: (true, true),
            may_fail: true,
            unsupported: true,
            widths: widths::Widths::Top,
            returned_widths: widths::Widths::Empty,
        }
    }

    fn integer(normal: Interval) -> Self {
        Self {
            normal,
            live: !normal.is_bottom(),
            only_integer: true,
            non_integer_other: false,
            boolean: (false, false),
            may_fail: false,
            unsupported: false,
            widths: widths::Widths::Empty,
            ..Self::unknown()
        }
    }

    fn integer_kind(kind: IntKind, normal: Interval) -> Self {
        if kind == IntKind::Integer64 {
            return Self::integer(normal);
        }
        Self {
            live: !normal.is_bottom(),
            widths: widths::Widths::single(kind, normal),
            non_integer_other: false,
            ..Self::unit()
        }
    }

    /// Integer64 の既存成分と混ぜず、指定した整数型の正常値を読む。
    pub fn range_kind(&self, kind: IntKind) -> Interval {
        if kind == IntKind::Integer64 {
            self.normal
        } else {
            self.widths.range(kind)
        }
    }

    /// 型注記だけで腕を解析せず、Lean の matchKind と同じ順で正常値を認定する。
    fn match_kind(&self) -> Option<IntKind> {
        if self.only_integer {
            return Some(IntKind::Integer64);
        }
        if self.boolean.0 || self.boolean.1 || self.non_integer_other || !self.normal.is_bottom() {
            return None;
        }
        IntKind::WIDTHS.into_iter().find(|kind| {
            IntKind::WIDTHS
                .into_iter()
                .all(|other| other == *kind || self.widths.range(other).is_bottom())
        })
    }

    fn unit() -> Self {
        Self {
            normal: Interval::bottom(),
            boolean: (false, false),
            may_fail: false,
            unsupported: false,
            widths: widths::Widths::Empty,
            ..Self::unknown()
        }
    }

    fn boolean(range: (bool, bool)) -> Self {
        Self {
            live: range.0 || range.1,
            boolean: range,
            non_integer_other: false,
            ..Self::unit()
        }
    }

    fn empty() -> Self {
        Self {
            live: false,
            non_integer_other: false,
            ..Self::unit()
        }
    }

    fn join(&mut self, other: &Self) {
        self.normal = self.normal.join(other.normal);
        self.returned = self.returned.join(other.returned);
        self.widths.join(&other.widths);
        self.returned_widths.join(&other.returned_widths);
        self.only_integer =
            (!self.live || self.only_integer) && (!other.live || other.only_integer);
        self.non_integer_other |= other.non_integer_other;
        self.live |= other.live;
        self.boolean = (
            self.boolean.0 || other.boolean.0,
            self.boolean.1 || other.boolean.1,
        );
        self.may_fail |= other.may_fail;
        self.unsupported |= other.unsupported;
    }

    fn preceded_by(&mut self, previous: &Self) {
        self.returned = previous.returned.join(self.returned);
        self.returned_widths.join(&previous.returned_widths);
        self.may_fail |= previous.may_fail;
        self.unsupported |= previous.unsupported;
    }
}

/// 停止でも保存済み候補を保持し、値の未取得と候補の不存在を混同しない。
#[derive(Debug)]
pub(in crate::typeck) struct Analysis {
    pub value: Result<Approx, IdentityStop>,
    pub candidates: Vec<Candidate>,
    pub independent: Vec<independent::IndependentResult>,
    pub unsupported: bool,
}

/// 引数・捕捉値の事実を忘れ、本体の一時表を必ず解放する。
pub(super) fn analyze<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    identity: &mut IdentityMap<'ast>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    budget: &mut Budget,
    fuel: u32,
    entry: (super::environment::SavedEnvironment, Option<&'ast Block>),
) -> Analysis {
    let mut flow = Flow {
        input,
        tables,
        identity,
        constants,
        budget,
        env: Environment::from_saved(entry.0),
        candidates: Vec::new(),
        independent: Vec::new(),
        unsupported: false,
        root_body: entry.1,
        current_occurrence: 0,
    };
    let checkpoint = flow.env.checkpoint();
    let temporary = flow.budget.body.temporary;
    let value = (|| {
        if let Some(stop) = flow.budget.exhausted() {
            return Err(IdentityStop::AnalysisBudget(stop));
        }
        // bodyWork の scope は忘却より前、根の expr の scope は忘却より後である。
        flow.frame()?;
        flow.env
            .forget(flow.budget)
            .map_err(IdentityStop::AnalysisBudget)?;
        flow.node(Node::Root, fuel)
    })();
    flow.env.rollback(checkpoint, flow.budget);
    flow.budget.release(
        Lifetime::Temporary,
        flow.budget.body.temporary.saturating_sub(temporary),
    );
    flow.identity.stopped = value.as_ref().err().copied();
    flow.identity.finish_embedding();
    Analysis {
        value,
        candidates: flow.candidates,
        independent: flow.independent,
        unsupported: flow.unsupported,
    }
}

struct Flow<'a, 'ast, 'tables> {
    input: &'a BodyInput<'ast>,
    tables: &'a InputTables<'tables>,
    identity: &'a mut IdentityMap<'ast>,
    constants: &'a BTreeMap<BindingId, &'a BodyInput<'ast>>,
    budget: &'a mut Budget,
    env: Environment,
    candidates: Vec<Candidate>,
    independent: Vec<independent::IndependentResult>,
    unsupported: bool,
    root_body: Option<&'ast Block>,
    current_occurrence: u64,
}

impl<'ast> Flow<'_, 'ast, '_> {
    fn tick(&mut self, operation: Operation) -> Result<(), IdentityStop> {
        self.budget
            .charge(operation)
            .map_err(IdentityStop::AnalysisBudget)
    }

    fn frame(&mut self) -> Result<(), IdentityStop> {
        self.budget
            .reserve(Item::StackFrame, Lifetime::Temporary)
            .map_err(IdentityStop::AnalysisBudget)
    }

    fn expr(&mut self, source: &'ast Expr, fuel: u32) -> Result<Approx, IdentityStop> {
        self.node(Node::Expr(source), fuel)
    }

    fn node(&mut self, mut source: Node<'ast>, mut fuel: u32) -> Result<Approx, IdentityStop> {
        let outer = self.current_occurrence;
        let start = self.identity.next;
        let checkpoint = self.env.checkpoint();
        let temporary = self.budget.body.temporary;
        let mut held = 0_u64;
        let result = (|| loop {
            fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
            self.frame()?;
            held = held.saturating_add(1);
            let parent = (self.identity.next != 0).then_some(self.current_occurrence);
            self.current_occurrence =
                self.identity
                    .identify(self.input, self.tables, source, parent, self.budget)?;
            self.tick(Operation::Expression)?;
            if let Node::Expr(Expr::Paren(paren)) = source {
                source = Node::Expr(&paren.inner);
            } else {
                break match source {
                    Node::Expr(source) => self.expr_inner(source, fuel),
                    Node::Root | Node::Conditional(_) | Node::With(_, _) | Node::Synthetic(..) => {
                        self.node_inner(source, fuel)
                    }
                };
            }
        })();
        if let Ok(value) = &result {
            self.unsupported |= value.unsupported;
            for key in start..start.saturating_add(held) {
                self.identity.finish(key);
            }
        }
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(
            Lifetime::Temporary,
            self.budget.body.temporary.saturating_sub(temporary),
        );
        self.current_occurrence = outer;
        result
    }

    #[inline(never)]
    fn node_inner(&mut self, source: Node<'ast>, fuel: u32) -> Result<Approx, IdentityStop> {
        match source {
            Node::Expr(source) => self.expr_inner(source, fuel),
            Node::Conditional(source) => self.conditional(source, fuel),
            Node::With(source, index) => {
                fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.unknown_with(source, index, fuel)?;
                Ok(Approx::unknown())
            }
            Node::Synthetic(..) => {
                fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                Ok(Approx::unknown())
            }
            Node::Root => self.root(fuel),
        }
    }

    // 合成した根の準備を、再帰する式の振り分けの枠に積まない。
    #[inline(never)]
    fn root(&mut self, fuel: u32) -> Result<Approx, IdentityStop> {
        if let Some(body) = self.root_body {
            return self.block(body, fuel);
        }
        match self.input.definition.source {
            BodySource::Function { body, .. } => self.block(body, fuel),
            BodySource::Constant(c) => {
                let fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                let result = self
                    .tick(Operation::Classification)
                    .and_then(|()| self.expr(&c.value, fuel));
                self.budget.release(Lifetime::Temporary, 1);
                result
            }
        }
    }

    fn skip(&mut self, source: SkipInput<'ast>, fuel: u32) -> Result<(), IdentityStop> {
        super::discovery::skip(
            self.input,
            self.tables,
            self.constants,
            self.budget,
            fuel,
            (self.identity, Some(self.current_occurrence)),
            source,
        )
    }

    #[inline(never)]
    fn expr_inner(&mut self, source: &'ast Expr, fuel: u32) -> Result<Approx, IdentityStop> {
        match source {
            Expr::Lit(_) => self.literal(source.id(), fuel),
            Expr::Unary(u) if u.op == UnOp::Neg && matches!(u.operand.as_ref(), Expr::Lit(_)) => {
                self.literal(u.id, fuel)
            }
            Expr::Unary(u) if u.op == UnOp::Not => self.negated(u, fuel),
            Expr::Unary(u) if u.op == UnOp::Neg => self.numeric_negated(source, u, fuel),
            Expr::Unit(_) => Ok(Approx::unit()),
            Expr::Name(n) => self.name(n, fuel),
            Expr::Binary(binary) => self.binary(binary, fuel),
            Expr::Block(b) => self.block(&b.body, fuel),
            Expr::If(source) => self.conditional(source, fuel),
            Expr::Match(source) => self.matching(source, fuel),
            Expr::Return(r) => self.returned(r, fuel),
            Expr::Call(_) => self.called(source, fuel),
            // 未対応の親は未知とし、子の独立入力と別本体を区別する。
            Expr::Interp(_)
            | Expr::Paren(_)
            | Expr::List(_)
            | Expr::Record(_)
            | Expr::Unary(_)
            | Expr::Pipe(_)
            | Expr::Lambda(_)
            | Expr::Try(_)
            | Expr::Lazy(_)
            | Expr::With(_)
            | Expr::Handle(_)
            | Expr::Resume(_) => self.unknown(source, fuel),
            Expr::Error(error) => Err(IdentityStop::Unmapped(error.id)),
        }
    }

    // 認定の停止を扱う一時値を、全ての式の振り分けの枠へ積まない。
    #[inline(never)]
    fn called(&mut self, source: &'ast Expr, fuel: u32) -> Result<Approx, IdentityStop> {
        let Some(recognized) = self.range_call(source)? else {
            return self.unknown(source, fuel);
        };
        if let range::Call::Shift(entry) = recognized {
            return self.shift_called(source, fuel, entry);
        }
        self.standard_called(source, fuel)
    }

    // 未認定callの再帰では、認定後の値・引数列の一時領域をスタックへ積まない。
    #[inline(never)]
    fn standard_called(&mut self, source: &'ast Expr, fuel: u32) -> Result<Approx, IdentityStop> {
        let Expr::Call(call) = source else {
            return Err(IdentityStop::Unmapped(source.id()));
        };
        let key = self.current_occurrence;
        self.skip(SkipInput::Expr(Node::Expr(&call.callee)), fuel)?;
        let values = self.standard_arguments(&call.args, fuel)?;
        let projected = self.range_value_scan(source, key)?;
        if !values.live {
            return Ok(values);
        }
        let mut output = projected.map_or_else(Approx::unknown, Approx::integer);
        // 精密な射影でも失敗可能性を残す（設計書 01-12「区間解析の土台の解析と健全性」）。
        output.may_fail = true;
        output.unsupported = false;
        output.preceded_by(&values);
        Ok(output)
    }

    // arguments は列の末尾も一枠・一分類とし、各要素と列の両方で fuel を減らす。
    #[inline(never)]
    fn standard_arguments(
        &mut self,
        args: &'ast [Arg],
        mut fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            let mut output = Approx::unit();
            let mut remaining = args;
            loop {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                let Some((head, tail)) = remaining.split_first() else {
                    return Ok(output);
                };
                let source = head
                    .expr()
                    .ok_or(IdentityStop::Unmapped(self.input.definition.source.node()))?;
                let mut value = self.expr(source, fuel)?;
                value.preceded_by(&output);
                if !value.live {
                    // skipExprs は残りの列について空の末尾まで分類する。
                    self.skip(SkipInput::Arguments(tail), fuel)?;
                    return Ok(value);
                }
                output = Approx::unit();
                output.preceded_by(&value);
                remaining = tail;
            }
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    #[inline(never)]
    fn returned(&mut self, source: &'ast ReturnExpr, fuel: u32) -> Result<Approx, IdentityStop> {
        let mut value = self.expr(&source.value, fuel)?;
        if value.live {
            value.returned = value.returned.join(value.normal);
            value.returned_widths.join(&value.widths);
        }
        value.normal = Interval::bottom();
        value.widths = widths::Widths::Empty;
        value.provenance = Provenance::default();
        value.boolean = (false, false);
        value.non_integer_other = false;
        value.live = false;
        Ok(value)
    }

    #[inline(never)]
    fn binary(&mut self, source: &'ast BinaryExpr, fuel: u32) -> Result<Approx, IdentityStop> {
        if matches!(source.op, BinOp::And | BinOp::Or) {
            return self.short_circuit(source, fuel);
        }
        let operation = arithmetic::Operation::from_binary(source.op);
        let comparison = Comparison::from_binary(source.op);
        if operation.is_none() && comparison.is_none() {
            return self.unknown_binary(source, fuel);
        }
        // 未対応の型・演算は、子自身の候補だけを独立に残す。
        let Some(kind) = self.binary_kind(source)? else {
            return self.unknown_binary(source, fuel);
        };
        let left = self.expr(&source.lhs, fuel)?;
        if !left.live {
            self.skip(SkipInput::Expr(Node::Expr(&source.rhs)), fuel)?;
            return Ok(left);
        }
        let right = self.expr(&source.rhs, fuel)?;
        self.binary_result(source, kind, operation, left, right)
    }

    // 型の一時値を、左右の式を再帰している枠に積まない。
    #[inline(never)]
    fn binary_kind(&self, source: &BinaryExpr) -> Result<Option<IntKind>, IdentityStop> {
        let left = IntKind::of_type(
            self.input
                .expression_type(source.lhs.id())
                .map_err(IdentityStop::Input)?,
        );
        let right = IntKind::of_type(
            self.input
                .expression_type(source.rhs.id())
                .map_err(IdentityStop::Input)?,
        );
        Ok(left.filter(|kind| Some(*kind) == right))
    }

    // 候補・由来・合成値の一時領域は、オペランドを再帰している間は積まない。
    #[inline(never)]
    fn binary_result(
        &mut self,
        source: &BinaryExpr,
        kind: IntKind,
        operation: Option<arithmetic::Operation>,
        left: Approx,
        mut right: Approx,
    ) -> Result<Approx, IdentityStop> {
        if !right.live {
            right.preceded_by(&left);
            return Ok(right);
        }
        let Some(operation) = operation else {
            let mut result = Approx::boolean((true, true));
            result.preceded_by(&right);
            result.preceded_by(&left);
            return Ok(result);
        };
        let own = operation.evaluate(kind, left.range_kind(kind), right.range_kind(kind));
        if let Some(cause) = own.cause {
            let primary = match cause {
                Cause::Overflow => source.span,
                Cause::ZeroDivisor => source.rhs.span(),
                Cause::OutsideDomain => return Err(IdentityStop::Unmapped(source.id)),
            };
            self.save_candidate(
                (source.id, primary, TargetOperation::Binary(source.op)),
                kind,
                cause,
                &left,
                &right,
            )?;
        }
        let provenance = left.provenance.combine(&right.provenance);
        let mut result = Approx {
            provenance,
            may_fail: own.may_fail,
            ..Approx::integer_kind(kind, own.normal)
        };
        result.preceded_by(&right);
        result.preceded_by(&left);
        Ok(result)
    }

    #[inline(never)]
    fn conditional(&mut self, source: &'ast IfExpr, fuel: u32) -> Result<Approx, IdentityStop> {
        let tested = self.expr(&source.cond, fuel)?;
        let mut positive = self.branch(
            &source.cond,
            tested.boolean,
            true,
            |flow| flow.block(&source.then_block, fuel),
            |flow| flow.skip(SkipInput::Statements(&source.then_block.stmts), fuel),
        )?;
        self.conditional_tail(source, fuel, &tested, &mut positive)?;
        Ok(positive)
    }

    // then の走査中に else と合流の一時領域を保持しない。
    #[inline(never)]
    fn conditional_tail(
        &mut self,
        source: &'ast IfExpr,
        fuel: u32,
        tested: &Approx,
        positive: &mut Approx,
    ) -> Result<(), IdentityStop> {
        let negative = self.branch(
            &source.cond,
            tested.boolean,
            false,
            |flow| match &source.else_branch {
                Some(ElseBranch::Block(body)) => flow.block(body, fuel),
                Some(ElseBranch::If(next)) => flow.node(Node::Conditional(next), fuel),
                None => Ok(Approx::unit()),
            },
            |flow| match &source.else_branch {
                Some(ElseBranch::Block(body)) => {
                    flow.skip(SkipInput::Statements(&body.stmts), fuel)
                }
                Some(ElseBranch::If(next)) => {
                    flow.skip(SkipInput::Expr(Node::Conditional(next)), fuel)
                }
                None => Ok(()),
            },
        )?;
        let empty = Provenance::default();
        let left = if positive.live && positive.only_integer {
            &positive.provenance
        } else {
            &empty
        };
        let right = if negative.live && negative.only_integer {
            &negative.provenance
        } else {
            &empty
        };
        positive.provenance = left.combine(right);
        positive.join(&negative);
        positive.returned = tested.returned.join(positive.returned);
        positive.may_fail |= tested.may_fail;
        positive.unsupported |= tested.unsupported;
        Ok(())
    }

    fn branch(
        &mut self,
        source: &'ast Expr,
        normal: (bool, bool),
        truth: bool,
        run: impl FnOnce(&mut Self) -> Result<Approx, IdentityStop>,
        skip: impl FnOnce(&mut Self) -> Result<(), IdentityStop>,
    ) -> Result<Approx, IdentityStop> {
        // BudgetAnalysis.branch の scope は、未到達の場合も先に確保する。
        // 真偽に正常値がなければ BudgetScan.branch は構文を再分類しない。
        self.frame()?;
        let checkpoint = self.env.checkpoint();
        let possible = if truth { normal.1 } else { normal.0 };
        let prepared = if possible {
            self.condition(source, truth)
        } else {
            Ok(false)
        };
        let result = match prepared {
            Ok(true) => run(self),
            Ok(false) => skip(self).map(|()| Approx::empty()),
            Err(stop) => Err(stop),
        };
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    /// 括弧と定数参照をループで下り、各分類の枠は内側の処理が終わるまで保持する。
    fn classify<T>(
        &mut self,
        mut source: &'ast Expr,
        constants: Option<IntKind>,
        finish: impl FnOnce(&mut Self, &'ast Expr) -> Result<T, IdentityStop>,
    ) -> Result<T, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            loop {
                self.frame()?;
                held = held.checked_add(1).ok_or(IdentityStop::Depth)?;
                self.tick(Operation::Classification)?;
                match source {
                    Expr::Paren(paren) => source = &paren.inner,
                    Expr::Name(name) if constants.is_some() => {
                        let binding = self.reference(name.id)?;
                        if !matches!(
                            self.tables.resolved.bindings.get(binding).map(|b| &b.kind),
                            Some(BindingKind::Const)
                        ) {
                            break;
                        }
                        let input = self
                            .constants
                            .get(&binding)
                            .ok_or(IdentityStop::MissingConstant(binding))?;
                        let BodySource::Constant(declaration) = input.definition.source else {
                            return Err(IdentityStop::MissingConstant(binding));
                        };
                        if IntKind::of_type(
                            input
                                .expression_type(declaration.value.id())
                                .map_err(IdentityStop::Input)?,
                        ) != constants
                        {
                            break;
                        }
                        source = &declaration.value;
                    }
                    Expr::Lit(_)
                    | Expr::Interp(_)
                    | Expr::Name(_)
                    | Expr::Unit(_)
                    | Expr::List(_)
                    | Expr::Call(_)
                    | Expr::Record(_)
                    | Expr::Binary(_)
                    | Expr::Unary(_)
                    | Expr::Pipe(_)
                    | Expr::If(_)
                    | Expr::Match(_)
                    | Expr::Lambda(_)
                    | Expr::Return(_)
                    | Expr::Try(_)
                    | Expr::Block(_)
                    | Expr::Lazy(_)
                    | Expr::With(_)
                    | Expr::Handle(_)
                    | Expr::Resume(_)
                    | Expr::Error(_) => break,
                }
            }
            finish(self, source)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn reference(&self, node: NodeId) -> Result<BindingId, IdentityStop> {
        self.tables
            .resolved
            .refs
            .get(node)
            .copied()
            .ok_or(IdentityStop::MissingReference(node))
    }

    fn local_index(&mut self, source: &'ast Expr) -> Result<Option<BindingId>, IdentityStop> {
        self.classify(source, None, |flow, source| {
            let Expr::Name(name) = source else {
                return Ok(None);
            };
            let binding = flow.reference(name.id)?;
            Ok(matches!(
                flow.tables.resolved.bindings.get(binding).map(|b| &b.kind),
                Some(BindingKind::Local(_))
            )
            .then_some(binding))
        })
    }

    fn constant(
        &mut self,
        source: &'ast Expr,
        kind: IntKind,
    ) -> Result<Option<i128>, IdentityStop> {
        self.classify(source, Some(kind), |flow, source| {
            let leaf = matches!(source, Expr::Lit(_))
                || matches!(source, Expr::Unary(u) if u.op == UnOp::Neg && matches!(u.operand.as_ref(), Expr::Lit(_)));
            if !leaf {
                return Ok(None);
            }
            Ok(flow
                .tables
                .literals
                .get(source.id())
                .and_then(super::input::integer_literal)
                .and_then(|(stored, value)| {
                    (stored == kind && kind.min() <= value && value <= kind.max()).then_some(value)
                }))
        })
    }

    fn comparison(
        &mut self,
        source: &'ast Expr,
    ) -> Result<Option<(IntKind, BindingId, Comparison, i128)>, IdentityStop> {
        // BudgetScan.comparisons と同じく根を一度だけ分類し、型で経路を選ぶ。
        self.classify(source, None, |flow, source| {
            let Expr::Binary(binary) = source else {
                return Ok(None);
            };
            let Some(op) = Comparison::from_binary(binary.op) else {
                return Ok(None);
            };
            let Some(kind) = flow.binary_kind(binary)? else {
                return Ok(None);
            };
            // comparisonOperands は、最初の組が成立しない場合にだけ左右を反転する。
            let index = flow.local_index(&binary.lhs)?;
            let value = flow.constant(&binary.rhs, kind)?;
            if let (Some(index), Some(value)) = (index, value) {
                return Ok(Some((kind, index, op, value)));
            }
            let index = flow.local_index(&binary.rhs)?;
            let value = flow.constant(&binary.lhs, kind)?;
            Ok(index
                .zip(value)
                .map(|(index, value)| (kind, index, op.reverse(), value)))
        })
    }

    fn condition(&mut self, source: &'ast Expr, truth: bool) -> Result<bool, IdentityStop> {
        self.classify(source, None, |flow, source| {
            if let Expr::Lit(_) = source
                && let Some(ConstValue::Boolean(value)) = flow.tables.literals.get(source.id())
            {
                return Ok(*value == truth);
            }
            if let Expr::Unary(u) = source
                && u.op == UnOp::Not
            {
                return flow.condition(&u.operand, !truth);
            }
            if let Expr::Binary(b) = source
                && matches!(b.op, BinOp::And | BinOp::Or)
            {
                if truth == (b.op == BinOp::And) {
                    return if flow.condition(&b.lhs, truth)? {
                        flow.condition(&b.rhs, truth)
                    } else {
                        Ok(false)
                    };
                }
                return flow.alternative_conditions(b, truth);
            }
            let Some((kind, binding, op, constant)) = flow.comparison(source)? else {
                return Ok(true);
            };
            let (range, _) = flow.integer_at(binding, kind)?;
            if op.refine(kind, range, constant, truth).is_bottom() {
                return Ok(false);
            }
            // atomic の到達判定に続いて refine がもう一度読む順序を保つ。
            let (range, provenance) = flow.integer_at(binding, kind)?;
            let provenance = provenance.with_position(source.span());
            flow.env
                .narrow(
                    binding,
                    Slot::integer_kind(kind, op.refine(kind, range, constant, truth), provenance),
                    flow.budget,
                )
                .map_err(IdentityStop::AnalysisBudget)?;
            Ok(true)
        })
    }

    #[inline(never)]
    fn alternative_conditions(
        &mut self,
        source: &'ast BinaryExpr,
        truth: bool,
    ) -> Result<bool, IdentityStop> {
        let base = self.env.snapshot();
        let first = self
            .condition(&source.lhs, truth)?
            .then(|| self.env.snapshot());
        self.env.select(base);
        let second = (self.condition(&source.lhs, !truth)?
            && self.condition(&source.rhs, truth)?)
        .then(|| self.env.snapshot());
        match (first, second) {
            (None, None) => {
                self.env.select(base);
                Ok(false)
            }
            (Some(head), None) | (None, Some(head)) => {
                self.env.select(head);
                Ok(true)
            }
            (Some(left), Some(right)) => {
                self.env
                    .join(base, left, right, self.budget)
                    .map_err(IdentityStop::AnalysisBudget)?;
                Ok(true)
            }
        }
    }

    #[inline(never)]
    fn short_circuit(
        &mut self,
        source: &'ast BinaryExpr,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        // BudgetAnalysis.shortCircuit は expr とは別に fuel を一段消費する。
        let fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        let tested = self.expr(&source.lhs, fuel)?;
        let continue_truth = source.op == BinOp::And;
        let mut continued = self.branch(
            &source.lhs,
            tested.boolean,
            continue_truth,
            |flow| flow.expr(&source.rhs, fuel),
            |flow| flow.skip(SkipInput::Expr(Node::Expr(&source.rhs)), fuel),
        )?;
        let shorted = self.branch(
            &source.lhs,
            tested.boolean,
            !continue_truth,
            |_| Ok(Approx::boolean((continue_truth, !continue_truth))),
            |_| Ok(()),
        )?;
        continued.join(&shorted);
        continued.preceded_by(&tested);
        Ok(continued)
    }

    #[inline(never)]
    fn negated(&mut self, source: &'ast UnaryExpr, fuel: u32) -> Result<Approx, IdentityStop> {
        let value = self.expr(&source.operand, fuel)?;
        Ok(Approx {
            may_fail: value.may_fail,
            unsupported: value.unsupported,
            ..Approx::boolean((value.boolean.1, value.boolean.0))
        })
    }

    #[inline(never)]
    fn numeric_negated(
        &mut self,
        expression: &'ast Expr,
        source: &'ast UnaryExpr,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        // 型の分類の一時値を、全ての式で再帰する振り分けの枠へ積まない
        // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
        let kind = IntKind::of_type(
            self.input
                .expression_type(source.operand.id())
                .map_err(IdentityStop::Input)?,
        );
        if let Some(kind) = kind.filter(|kind| kind.min() < 0) {
            self.integer_negated(source, kind, fuel)
        } else {
            self.unknown(expression, fuel)
        }
    }

    #[inline(never)]
    fn integer_negated(
        &mut self,
        source: &'ast UnaryExpr,
        kind: IntKind,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        let child = self.expr(&source.operand, fuel)?;
        let own = arithmetic::negate(kind, child.range_kind(kind));
        if let Some(cause) = own.cause {
            self.save_candidate(
                (source.id, source.span, TargetOperation::Neg),
                kind,
                cause,
                &child,
                &Approx::empty(),
            )?;
        }
        let mut result = Approx {
            provenance: child.provenance.clone(),
            may_fail: own.may_fail,
            ..Approx::integer_kind(kind, own.normal)
        };
        result.preceded_by(&child);
        Ok(result)
    }

    fn integer_at(
        &mut self,
        binding: BindingId,
        kind: IntKind,
    ) -> Result<(Interval, Provenance), IdentityStop> {
        Ok(
            match self
                .env
                .read(binding, self.budget)
                .map_err(IdentityStop::AnalysisBudget)?
            {
                Some(Slot::Integer(range, provenance)) if kind == IntKind::Integer64 => {
                    (range, provenance)
                }
                Some(Slot::IntegerKind(stored, range, provenance)) if stored == kind => {
                    (range, provenance)
                }
                _ => (Interval::top_kind(kind), Provenance::default()),
            },
        )
    }

    fn save_candidate(
        &mut self,
        source: (NodeId, Span, TargetOperation),
        kind: IntKind,
        cause: Cause,
        left: &Approx,
        right: &Approx,
    ) -> Result<(), IdentityStop> {
        // 各展開出現の番号で候補を保存する。元 NodeId による統合は診断時だけ行う。
        let occurrence = self
            .identity
            .occurrences
            .get(
                usize::try_from(self.current_occurrence)
                    .map_err(|_| IdentityStop::NumberOverflow)?,
            )
            .filter(|occurrence| {
                occurrence.type_owner == self.input.definition.binding
                    && occurrence
                        .origin
                        .is_some_and(|origin| origin.node == source.0)
            })
            .ok_or(IdentityStop::Unmapped(source.0))?;
        let origin = occurrence.origin.ok_or(IdentityStop::Unmapped(source.0))?;
        // BudgetAnalysis.saveWarnings と同じ順序: scope の枠、候補の保存、
        // 列への追加、枠の返却。確保を拒否された候補は列へ入れない。
        let provenance = match cause {
            Cause::ZeroDivisor => right.provenance.clone(),
            Cause::Overflow => left.provenance.combine(&right.provenance),
            Cause::OutsideDomain => left.provenance.clone(),
        };
        self.frame()?;
        let reserved = self
            .budget
            .reserve(Item::Warning, Lifetime::Saved)
            .map_err(IdentityStop::AnalysisBudget);
        if reserved.is_ok() {
            self.candidates.push(Candidate {
                preorder: occurrence.preorder,
                origin,
                primary: source.1,
                operation: source.2,
                cause,
                kind,
                left: left.range_kind(kind),
                right: right.range_kind(kind),
                origins: provenance,
            });
        }
        self.budget.release(Lifetime::Temporary, 1);
        reserved
    }

    #[inline(never)]
    fn literal(&self, node: NodeId, fuel: u32) -> Result<Approx, IdentityStop> {
        let value = self
            .tables
            .literals
            .get(node)
            .ok_or(IdentityStop::MissingLiteral(node))?;
        let result = Self::value(value);
        if result.unsupported && super::input::integer_literal(value).is_none() {
            // 未対応の葉も unknownChildren の深さを確認してから unsupported を記録する。
            fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        }
        Ok(result)
    }

    fn value(value: &ConstValue) -> Approx {
        if let Some((kind, value)) = super::input::integer_literal(value) {
            // Lean の widthLiteral は値域外を Bottom に正規化せず未知にする。
            return if kind.min() <= value && value <= kind.max() {
                Approx::integer_kind(kind, Interval::normalize_kind(kind, value, value))
            } else {
                Approx::unknown()
            };
        }
        match value {
            ConstValue::Boolean(value) => Approx::boolean((!value, *value)),
            ConstValue::Float(_)
            | ConstValue::String(_)
            | ConstValue::Character(_)
            | ConstValue::Unit
            | ConstValue::Byte(_)
            | ConstValue::Decimal(_)
            | ConstValue::Ctor { .. }
            | ConstValue::List(_)
            | ConstValue::Map(_)
            | ConstValue::Set(_)
            | ConstValue::Integer(_)
            | ConstValue::Integer8(_)
            | ConstValue::Integer16(_)
            | ConstValue::Integer32(_)
            | ConstValue::UnsignedInteger16(_)
            | ConstValue::UnsignedInteger32(_)
            | ConstValue::UnsignedInteger64(_)
            | ConstValue::Float32(_) => Approx::unknown(),
        }
    }

    #[inline(never)]
    fn name(&mut self, name: &NameExpr, fuel: u32) -> Result<Approx, IdentityStop> {
        let binding = *self
            .tables
            .resolved
            .refs
            .get(name.id)
            .ok_or(IdentityStop::MissingReference(name.id))?;
        let kind = &self
            .tables
            .resolved
            .bindings
            .get(binding)
            .ok_or(IdentityStop::MissingReference(name.id))?
            .kind;
        match kind {
            BindingKind::Const => {
                let input = *self
                    .constants
                    .get(&binding)
                    .ok_or(IdentityStop::MissingConstant(binding))?;
                let BodySource::Constant(declaration) = input.definition.source else {
                    return Err(IdentityStop::MissingConstant(binding));
                };
                // constE は clearLocals の環境で読む。局所区間とその由来をともに隠し、
                // 成功・停止のどちらでも呼び出し元へ戻す（設計書 02-05「区間解析の局所環境」）。
                let checkpoint = self.env.checkpoint();
                self.env.clear_locals();
                let previous = std::mem::replace(&mut self.input, input);
                let result = self.expr(&declaration.value, fuel);
                self.input = previous;
                self.env.rollback(checkpoint, self.budget);
                result
            }
            BindingKind::Local(_) => {
                let slot = self
                    .env
                    .read(binding, self.budget)
                    .map_err(IdentityStop::AnalysisBudget)?;
                Ok(match slot {
                    Some(Slot::Integer(range, provenance)) => Approx {
                        provenance,
                        may_fail: true,
                        ..Approx::integer(range)
                    },
                    Some(Slot::IntegerKind(kind, range, provenance)) => Approx {
                        provenance,
                        may_fail: true,
                        ..Approx::integer_kind(kind, range)
                    },
                    _ => Approx {
                        unsupported: false,
                        ..Approx::unknown()
                    },
                })
            }
            BindingKind::Fn
            | BindingKind::BuiltinFn(_)
            | BindingKind::ImplFn { .. }
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::ExternalType
            | BindingKind::Record
            | BindingKind::Field { .. }
            | BindingKind::Ctor { .. }
            | BindingKind::Trait
            | BindingKind::Method { .. }
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Op { .. }
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. } => {
                fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                Ok(Approx::unknown())
            }
        }
    }

    fn block(&mut self, body: &'ast Block, fuel: u32) -> Result<Approx, IdentityStop> {
        if let [Stmt::Expr(source)] = body.stmts.as_slice() {
            return self.last_expression(source, fuel);
        }
        let checkpoint = self.env.checkpoint();
        let mut held = 0_u64;
        let result = self.statements(&body.stmts, fuel, &mut held);
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    // Block.last の小さい枠。文列の合成値を深い if の各枝へ積まない。
    #[inline(never)]
    fn last_expression(&mut self, source: &'ast Expr, fuel: u32) -> Result<Approx, IdentityStop> {
        let fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        self.frame()?;
        let result = self
            .tick(Operation::Classification)
            .and_then(|()| self.expr(source, fuel));
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    #[inline(never)]
    fn statements(
        &mut self,
        statements: &'ast [Stmt],
        mut fuel: u32,
        held: &mut u64,
    ) -> Result<Approx, IdentityStop> {
        let mut result = Approx::unit();
        let mut index = 0_usize;
        loop {
            fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
            self.frame()?;
            *held = held.saturating_add(1);
            self.tick(Operation::Classification)?;
            let Some(statement) = statements.get(index) else {
                break;
            };
            let last = index.checked_add(1) == Some(statements.len());
            let mut next = match statement {
                Stmt::Expr(expr) => self.expr(expr, fuel)?,
                Stmt::Bind(bind) => self.binding(bind, last, fuel)?,
                Stmt::Error(error) => return Err(IdentityStop::Unmapped(error.id)),
            };
            next.preceded_by(&result);
            result = next;
            index = index.saturating_add(1);
            let builder = matches!(statement, Stmt::Bind(b) if self.tables.resolved.builder_binds.get(b.id).is_some());
            if last && !builder {
                break;
            }
            if !result.live {
                self.skip(
                    SkipInput::Statements(
                        statements
                            .get(index..)
                            .ok_or(IdentityStop::NumberOverflow)?,
                    ),
                    fuel,
                )?;
                break;
            }
        }
        Ok(result)
    }

    #[inline(never)]
    fn binding(
        &mut self,
        source: &'ast BindStmt,
        last: bool,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        if let Some(binding) = self.tables.resolved.builder_binds.get(source.id).copied() {
            self.env
                .write(binding, Slot::Builder, self.budget)
                .map_err(IdentityStop::AnalysisBudget)?;
            Ok(Approx::unit())
        } else {
            let source_key = self.identity.next;
            let value = self.expr(&source.value, fuel)?;
            if value.live && !last {
                match &source.pattern {
                    Pattern::Var(var) => {
                        let origin = self.range_origin(&source.value, source_key)?;
                        self.bind_variable(var.id, &value, source.span)?;
                        if let Some(origin) = origin {
                            self.env.save_range(origin, false, self.budget)?;
                        }
                    }
                    Pattern::Wildcard(_) => {}
                    pattern @ (Pattern::Lit(_)
                    | Pattern::Unit(_)
                    | Pattern::Ctor(_)
                    | Pattern::Record(_)
                    | Pattern::Range(_)
                    | Pattern::List(_)
                    | Pattern::Error(_)) => super::discovery::pattern_env(
                        self.input,
                        self.tables,
                        self.constants,
                        self.budget,
                        &mut self.env,
                        pattern,
                    )?,
                }
            }
            if value.live {
                let mut result = Approx::unit();
                result.preceded_by(&value);
                Ok(result)
            } else {
                Ok(value)
            }
        }
    }

    fn bind_variable(
        &mut self,
        node: NodeId,
        value: &Approx,
        span: crate::base::Span,
    ) -> Result<(), IdentityStop> {
        let binding = *self
            .tables
            .resolved
            .decls
            .get(node)
            .ok_or(IdentityStop::Input(InputError::MissingBinding(node)))?;
        // 構造パターンの内側の位置は型が整数でも未知とし、診断用の由来も作らない。
        let slot = self
            .input
            .local_type(binding)
            .and_then(IntKind::of_type)
            .map_or(Slot::Unknown, |kind| {
                Slot::integer_kind(
                    kind,
                    value.range_kind(kind),
                    value.provenance.with_position(span),
                )
            });
        self.env
            .write(binding, slot, self.budget)
            .map_err(IdentityStop::AnalysisBudget)
    }
}

#[derive(Clone, Copy)]
enum Comparison {
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
}

impl Comparison {
    fn from_binary(op: BinOp) -> Option<Self> {
        match op {
            BinOp::Eq => Some(Self::Eq),
            BinOp::Ne => Some(Self::Ne),
            BinOp::Lt => Some(Self::Lt),
            BinOp::Le => Some(Self::Le),
            BinOp::Gt => Some(Self::Gt),
            BinOp::Ge => Some(Self::Ge),
            BinOp::Add
            | BinOp::Sub
            | BinOp::Mul
            | BinOp::Div
            | BinOp::IntDiv
            | BinOp::Mod
            | BinOp::And
            | BinOp::Or => None,
        }
    }

    fn reverse(self) -> Self {
        match self {
            Self::Eq | Self::Ne => self,
            Self::Lt => Self::Gt,
            Self::Le => Self::Ge,
            Self::Gt => Self::Lt,
            Self::Ge => Self::Le,
        }
    }

    fn complement(self) -> Self {
        match self {
            Self::Eq => Self::Ne,
            Self::Ne => Self::Eq,
            Self::Lt => Self::Ge,
            Self::Le => Self::Gt,
            Self::Gt => Self::Le,
            Self::Ge => Self::Lt,
        }
    }

    fn refine(self, kind: IntKind, range: Interval, k: i128, truth: bool) -> Interval {
        let op = if truth { self } else { self.complement() };
        let Some((lo, hi)) = range.bounds() else {
            return range;
        };
        // k は七種の整数の型域内なので、i128 の k±1 は中間でもあふれない。
        // 不等値による内部の穴は凸な区間で表せず、端の除去だけを残す。
        match op {
            Self::Eq => range.meet(Interval::normalize_kind(kind, k, k)),
            Self::Ne if lo == k => Interval::normalize_kind(kind, lo.saturating_add(1), hi),
            Self::Ne if hi == k => Interval::normalize_kind(kind, lo, hi.saturating_sub(1)),
            Self::Ne => range,
            Self::Lt => range.meet(Interval::normalize_kind(
                kind,
                kind.min(),
                k.saturating_sub(1),
            )),
            Self::Le => range.meet(Interval::normalize_kind(kind, kind.min(), k)),
            Self::Gt => range.meet(Interval::normalize_kind(
                kind,
                k.saturating_add(1),
                kind.max(),
            )),
            Self::Ge => range.meet(Interval::normalize_kind(kind, k, kind.max())),
        }
    }
}
