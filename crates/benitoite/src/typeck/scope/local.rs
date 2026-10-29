//! Scope の成功値の局所解析（設計書 02-05「Scope の必須判定の入力」）。
//! 型・警告・区間の状態を読まない。

use super::lower::{Argument, Instruction};
use super::*;
use crate::types::scope::{Kind, PathPattern, Range};
use std::collections::BTreeMap;
use std::sync::Arc;

/// 検査で読めた条件。未知と既知の Top を混同しない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScopeBound {
    Known(Range),
    Unknown,
}

/// 一つの検査の出現と、検査した種類・条件。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeValueOrigin {
    pub key: ScopeKey,
    pub kind: Kind,
    pub bound: ScopeBound,
}

/// 保存した Result と、その Ok の同じ成功値の事実。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScopeFact {
    Result(ScopeValueOrigin),
    Checked {
        origin: ScopeValueOrigin,
        success_id: u64,
    },
}

/// 局所の位置。辞書・匿名の位置は binding が None である。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeLocal {
    pub binding: Option<BindingId>,
    pub id: u64,
    pub fact: Option<ScopeFact>,
}

// 各記録が位置の列全体を複写しないよう、変更しない節点を同じ arena に置く。
// arena の参照は添字だけで、深い局所の列の drop も再帰しない。
#[derive(Clone, Debug)]
struct Slot {
    local: ScopeLocal,
    tail: Option<usize>,
    epoch: u64,
}

#[derive(Clone, Debug, Default)]
struct Snapshot {
    head: Option<usize>,
    next_id: u64,
    epoch: u64,
    held: u64,
}

/// 文の始まりの状態。位置と成功値番号を保つ。
#[derive(Clone, Debug)]
pub struct ScopeState {
    snapshot: Snapshot,
    slots: Arc<Vec<Slot>>,
}

impl ScopeState {
    /// 最後に束縛した位置から、入口の位置へ向かって読む。
    pub fn locals(&self) -> impl Iterator<Item = ScopeLocal> + '_ {
        let mut head = self.snapshot.head;
        std::iter::from_fn(move || {
            let slot = self.slots.get(head?)?;
            head = slot.tail;
            let mut local = slot.local.clone();
            if slot.epoch != self.snapshot.epoch {
                local.fact = None;
            }
            Some(local)
        })
    }

    /// 次に導入する位置の番号。忘却しても既存の位置の同一性を保つ。
    pub fn next_id(&self) -> u64 {
        self.snapshot.next_id
    }
}

/// 一つの文の始まりの記録。番号は番号付き入力と同じである。
#[derive(Clone, Debug)]
pub struct ScopeRecord {
    pub key: ScopeKey,
    pub state: ScopeState,
}

/// 規則へ渡す抽象の引数。整数を文字列に符号化しない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScopeArgument {
    String(Arc<str>),
    Integer(i64),
    Local { id: u64, fact: Option<ScopeFact> },
    Unknown,
}

/// 呼び出しの出現を、その番号の各記録（なければ factFree）で読んだ引数。
/// transfer の結果は記録のある出現だけに置く。射影の結果には事実を作らない。
#[derive(Clone, Debug)]
pub struct ScopeCallFacts {
    pub key: ScopeKey,
    pub declaration: ScopeDeclaration,
    pub arguments: Vec<ScopeArgument>,
    pub result: Option<ScopeFact>,
}

/// 一つの本体または全体に許す累積の操作数と同時の事実数。
#[derive(Clone, Copy, Debug)]
pub struct ScopeCap {
    pub operations: u64,
    pub items: u64,
}

/// 局所解析の上限。採用値を暗黙に置かず、呼び出し元が指定する。
#[derive(Clone, Copy, Debug)]
pub struct ScopeLimits {
    pub body: ScopeCap,
    pub whole: ScopeCap,
}

/// 通常ソースの測定から採用した Scope 専用の上限。
/// Range の警告解析とは、値も状態も共有しない（設計書 02-05「Scope の必須判定の入力」）。
pub const DEFAULT_SCOPE_LIMITS: ScopeLimits = ScopeLimits {
    body: ScopeCap {
        operations: 16_384,
        items: 512,
    },
    whole: ScopeCap {
        operations: 65_536,
        items: 2_048,
    },
};

/// 局所解析で承認した操作数と、候補を含む同時保持数の最大値。
/// 本体の操作数は入口ごとに 0 へ戻るため、その最大値を記録する。
#[derive(Clone, Debug, Default)]
pub struct ScopeMetrics {
    pub body_operations: u64,
    pub whole_operations: u64,
    pub max_body_items: u64,
    pub max_whole_items: u64,
    /// 最初に各 Run が止まった文の先行順番号と理由。番号付け停止は別に記録する。
    pub stops: Vec<(u64, ScopeInputStop)>,
}

/// 本体の解析結果。型制約への接続と範囲の列の選択は含まない。
#[derive(Debug)]
pub struct ScopeAnalysis {
    pub metrics: ScopeMetrics,
    pub input: ScopeNumberedInput,
    pub records: Vec<ScopeRecord>,
    pub calls: Vec<ScopeCallFacts>,
    /// 最後の Run の停止。内側だけで超過して外側が回復した場合は含めない。
    pub stopped: Option<ScopeInputStop>,
    pub(super) fact_indices: BTreeMap<u64, Vec<usize>>,
}

impl ScopeAnalysis {
    /// 補間の型が確定した後に番号ラベルだけを更新する。事実・操作費用・停止は作り直さない。
    /// 対応は元の文・呼び出しの NodeId から取り、仮の番号を最終の照合へ残さない。
    pub fn renumber(&mut self, input: ScopeNumberedInput) -> Result<(), ScopeInputStop> {
        if input.stopped != self.input.stopped {
            return Err(input.stopped.unwrap_or(ScopeInputStop::NumberOverflow));
        }
        if input.stopped.is_some() {
            // 停止した本体は全規則に Top を要求し、接頭辞の番号も事実も使わない。
            self.input = input;
            return Ok(());
        }
        let statements: BTreeMap<_, _> = input
            .statements
            .iter()
            .map(|statement| (statement.statement, statement.preorder))
            .collect();
        let calls: BTreeMap<_, _> = input
            .calls
            .iter()
            .map(|call| (call.node, call.preorder))
            .collect();
        let mut positions = BTreeMap::new();
        for statement in &self.input.statements {
            let position = statements
                .get(&statement.statement)
                .ok_or(ScopeInputStop::MissingInput(statement.statement))?;
            positions.insert(statement.preorder, *position);
        }
        for call in &self.input.calls {
            let position = calls
                .get(&call.node)
                .ok_or(ScopeInputStop::MissingInput(call.node))?;
            positions.insert(call.preorder, *position);
        }
        let remap = |key: &mut ScopeKey| -> Result<(), ScopeInputStop> {
            key.surface_preorder = *positions
                .get(&key.surface_preorder)
                .ok_or(ScopeInputStop::NumberOverflow)?;
            Ok(())
        };
        let fact = |fact: &mut ScopeFact| -> Result<(), ScopeInputStop> {
            match fact {
                ScopeFact::Result(origin) | ScopeFact::Checked { origin, .. } => {
                    remap(&mut origin.key)
                }
            }
        };
        if let Some(first) = self.records.first() {
            // 全記録が同じ arena を共有する。複写は記録ごとでなく全体で一度だけ行う。
            let mut slots = first.state.slots.as_ref().clone();
            for slot in &mut slots {
                if let Some(local_fact) = &mut slot.local.fact {
                    fact(local_fact)?;
                }
            }
            let slots = Arc::new(slots);
            for record in &mut self.records {
                remap(&mut record.key)?;
                record.state.slots = Arc::clone(&slots);
            }
        }
        for call in &mut self.calls {
            remap(&mut call.key)?;
            if let Some(result) = &mut call.result {
                fact(result)?;
            }
            for argument in &mut call.arguments {
                if let ScopeArgument::Local {
                    fact: Some(argument_fact),
                    ..
                } = argument
                {
                    fact(argument_fact)?;
                }
            }
        }
        for (position, _) in &mut self.metrics.stops {
            if let Some(final_position) = positions.get(position) {
                *position = *final_position;
            }
        }
        self.input = input;
        self.fact_indices.clear();
        for (index, call) in self.calls.iter().enumerate() {
            self.fact_indices
                .entry(call.key.surface_preorder)
                .or_default()
                .push(index);
        }
        Ok(())
    }
}

#[derive(Clone, Default)]
struct Budget {
    body: u64,
    whole: u64,
    outer_items: u64,
}

#[derive(Clone, Default)]
struct Run {
    state: Snapshot,
    budget: Budget,
    stopped: Option<ScopeInputStop>,
}

struct Analysis<'a> {
    structure: &'a super::input::Structure,
    program: &'a super::lower::Program,
    input: &'a ScopeNumberedInput,
    calls_by_node: BTreeMap<NodeId, &'a ScopeCall>,
    slots: Vec<Slot>,
    epoch: u64,
    metrics: ScopeMetrics,
    position: u64,
}

impl Analysis<'_> {
    fn key(&self, preorder: u64) -> ScopeKey {
        ScopeKey {
            definition: self.input.body_key.definition.clone(),
            surface_preorder: preorder,
        }
    }

    fn extend(&mut self, st: &mut Snapshot, binding: Option<BindingId>, fact: Option<ScopeFact>) {
        let local = ScopeLocal {
            binding,
            id: st.next_id,
            fact,
        };
        if local.fact.is_some() {
            st.held = st.held.saturating_add(1);
        }
        self.slots.push(Slot {
            local,
            tail: st.head,
            epoch: st.epoch,
        });
        st.head = self.slots.len().checked_sub(1);
        st.next_id = st.next_id.saturating_add(1);
    }

    fn forget(&mut self, st: &mut Snapshot) {
        self.epoch = self.epoch.saturating_add(1);
        st.epoch = self.epoch;
        st.held = 0;
    }

    fn local(&self, st: &Snapshot, binding: BindingId) -> Option<(u64, Option<&ScopeFact>)> {
        let mut head = st.head;
        while let Some(slot) = head.and_then(|i| self.slots.get(i)) {
            if slot.local.binding == Some(binding) {
                return Some((
                    slot.local.id,
                    (slot.epoch == st.epoch)
                        .then_some(slot.local.fact.as_ref())
                        .flatten(),
                ));
            }
            head = slot.tail;
        }
        None
    }

    fn argument(&self, st: &Snapshot, form: &Argument) -> ScopeArgument {
        let mut form = form;
        // constArg? は constE の鎖だけを辿る。演算・括弧や局所には入らない。
        // 番号付けがこの鎖の展開を予算内で完了した後だけ呼ばれる。
        for _ in 0..=4096 {
            match form {
                Argument::String(s) => return ScopeArgument::String(Arc::clone(s)),
                Argument::Integer(n) => return ScopeArgument::Integer(*n),
                Argument::Constant(b) => {
                    let Some(next) = self
                        .structure
                        .constants
                        .get(b)
                        .and_then(|i| self.structure.bodies.get(*i))
                    else {
                        break;
                    };
                    form = &next.literal;
                }
                Argument::Local(b) => {
                    return self
                        .local(st, *b)
                        .map_or(ScopeArgument::Unknown, |(id, fact)| ScopeArgument::Local {
                            id,
                            fact: fact.cloned(),
                        });
                }
                // projectRule.transfer = none。射影の値を再包装・保存しても由来は生まれない。
                Argument::Projection(_) | Argument::Other => break,
            }
        }
        ScopeArgument::Unknown
    }

    fn arguments(&self, st: &Snapshot, call: &ScopeCall) -> Vec<ScopeArgument> {
        let forms = self.program.arguments.get(&call.node);
        call.contract_to_source
            .iter()
            .map(|source| match source {
                ScopeArgumentSource::Explicit(i) => forms
                    .and_then(|xs| xs.get(*i))
                    .map_or(ScopeArgument::Unknown, |a| self.argument(st, a)),
                ScopeArgumentSource::PipeLeft(_) => ScopeArgument::Unknown,
            })
            .collect()
    }

    fn transfer(&self, call: &ScopeCall, arguments: &[ScopeArgument]) -> Option<ScopeFact> {
        let (kind, bound) = match call.declaration {
            ScopeDeclaration::CheckPath => (
                Kind::Path,
                match arguments.first() {
                    Some(ScopeArgument::String(s)) => PathPattern::parse(s).ok().map(Range::Path),
                    _ => None,
                },
            ),
            ScopeDeclaration::CheckRequest => (
                Kind::Endpoint,
                match arguments {
                    [
                        ScopeArgument::String(s),
                        ScopeArgument::Integer(lo),
                        ScopeArgument::Integer(hi),
                        _,
                    ] => crate::builtins::checked_scope::endpoint_pattern(s, *lo, *hi)
                        .ok()
                        .map(Range::Endpoint),
                    _ => None,
                },
            ),
            ScopeDeclaration::PathValue
            | ScopeDeclaration::RequestValue
            | ScopeDeclaration::WidenPath
            | ScopeDeclaration::WidenRequest => return None,
        };
        Some(ScopeFact::Result(ScopeValueOrigin {
            key: self.key(call.preorder),
            kind,
            bound: bound.map_or(ScopeBound::Unknown, ScopeBound::Known),
        }))
    }

    fn arg_cost(&self, st: &Snapshot, a: &Argument) -> u64 {
        match a {
            Argument::Local(b) | Argument::Projection(b) => {
                let checked = self
                    .local(st, *b)
                    .is_some_and(|(_, f)| matches!(f, Some(ScopeFact::Checked { .. })));
                1_u64
                    .saturating_add(u64::from(checked))
                    .saturating_add(u64::from(matches!(a, Argument::Projection(_))))
            }
            Argument::String(_)
            | Argument::Integer(_)
            | Argument::Constant(_)
            | Argument::Other => 0,
        }
    }

    fn admit(&mut self, run: &mut Run, limits: ScopeLimits, ops: u64, held: u64) -> bool {
        let body = run.budget.body.checked_add(ops);
        let whole = run.budget.whole.checked_add(ops);
        use ScopeBudgetResource as R;
        use ScopeBudgetScope as S;
        self.metrics.max_body_items = self.metrics.max_body_items.max(held);
        self.metrics.max_whole_items = self
            .metrics
            .max_whole_items
            .max(run.budget.outer_items.saturating_add(held));
        let failure = if body.is_none_or(|n| n > limits.body.operations) {
            Some((S::Body, R::Operations))
        } else if whole.is_none_or(|n| n > limits.whole.operations) {
            Some((S::Whole, R::Operations))
        } else if held > limits.body.items {
            Some((S::Body, R::Items))
        } else if run
            .budget
            .outer_items
            .checked_add(held)
            .is_none_or(|n| n > limits.whole.items)
        {
            Some((S::Whole, R::Items))
        } else {
            None
        };
        if let Some((scope, resource)) = failure {
            let stop = ScopeInputStop::BudgetExceeded { scope, resource };
            self.metrics.stops.push((self.position, stop));
            run.stopped = Some(stop);
            self.forget(&mut run.state);
            false
        } else {
            run.budget.body = body.unwrap_or(u64::MAX);
            run.budget.whole = whole.unwrap_or(u64::MAX);
            self.metrics.body_operations = self.metrics.body_operations.max(run.budget.body);
            self.metrics.whole_operations = run.budget.whole;
            true
        }
    }

    fn step(&mut self, run: &mut Run, instruction: &Instruction, limits: ScopeLimits) {
        // Run.step の stopped 分岐は blindStep だけを行い、引数・転送・費用を再計算しない。
        if run.stopped.is_some() {
            let binding = match instruction {
                Instruction::Bind { binding, .. } | Instruction::Ok { binding, .. } => *binding,
                Instruction::Record(_)
                | Instruction::Stop(_)
                | Instruction::Save
                | Instruction::Restore
                | Instruction::Enter(_)
                | Instruction::Leave => return,
            };
            self.extend(&mut run.state, binding, None);
            return;
        }
        let (binding, fact, cost) = match instruction {
            Instruction::Bind {
                binding,
                rhs,
                alias,
                call,
            } => {
                let fact = call
                    .as_ref()
                    .and_then(|_| rhs.and_then(|node| self.calls_by_node.get(&node).copied()))
                    .and_then(|c| self.transfer(c, &self.arguments(&run.state, c)));
                let cost = call.as_ref().map_or(u64::from(*alias), |args| {
                    args.iter()
                        .fold(1_u64, |n, a| n.saturating_add(self.arg_cost(&run.state, a)))
                        .saturating_add(u64::from(fact.is_some()))
                });
                (*binding, fact, cost)
            }
            Instruction::Ok { binding, scrutinee } => {
                let origin = self
                    .local(&run.state, *scrutinee)
                    .and_then(|(_, f)| match f {
                        Some(ScopeFact::Result(o)) => Some(o.clone()),
                        _ => None,
                    });
                let cost = 1_u64.saturating_add(u64::from(origin.is_some()));
                (
                    *binding,
                    origin.map(|origin| ScopeFact::Checked {
                        origin,
                        success_id: run.state.next_id,
                    }),
                    cost,
                )
            }
            Instruction::Record(_)
            | Instruction::Stop(_)
            | Instruction::Save
            | Instruction::Restore
            | Instruction::Enter(_)
            | Instruction::Leave => return,
        };
        let held = run.state.held.saturating_add(u64::from(fact.is_some()));
        let fact = if run.stopped.is_none() && self.admit(run, limits, cost, held) {
            fact
        } else {
            None
        };
        self.extend(&mut run.state, binding, fact);
    }
}

impl ScopeBodyInput {
    /// 番号付き入力を一度読み、その番号のまま ScopeLower の局所解析を行う。
    /// 規則のない本体は contains_rules() で先に除外できる。
    pub fn analyze(&self, numbering_operations: u64, limits: ScopeLimits) -> ScopeAnalysis {
        let input = self.numbered(numbering_operations);
        self.analyze_input(input, limits)
    }

    /// 型制約の前の局所解析。未確定の補間の変換には一時の番号ラベルを割り振る。
    /// 変換の有無にかかわらず読み取りイベントの操作費用は同じであり、予算は変わらない。
    /// 型の確定後に renumber でラベルを確定し、局所解析そのものは再実行しない。
    pub fn analyze_pending(&self, numbering_operations: u64, limits: ScopeLimits) -> ScopeAnalysis {
        self.analyze_input(self.number(numbering_operations, true), limits)
    }

    /// 局所解析だけに limits を指定し、番号付けには独立した既定上限を使う。
    /// 各定義の whole は、Lean analyzeBody と同じく、その定義内の全本体を含む。
    pub fn analyze_with_limits(&self, limits: ScopeLimits) -> ScopeAnalysis {
        self.analyze_input(self.numbered(DEFAULT_NUMBERING_OPERATIONS), limits)
    }

    /// 型確定前の本番入口。番号付けの資源上限と局所解析の limits は独立する。
    pub(in crate::typeck) fn analyze_pending_with_limits(
        &self,
        limits: ScopeLimits,
    ) -> ScopeAnalysis {
        self.analyze_input(self.number(DEFAULT_NUMBERING_OPERATIONS, true), limits)
    }

    fn analyze_input(&self, input: ScopeNumberedInput, limits: ScopeLimits) -> ScopeAnalysis {
        let mut metrics = ScopeMetrics::default();
        let mut records = Vec::new();
        let mut calls = Vec::new();
        let mut stopped = input.stopped;
        if stopped.is_none()
            && let Some(body) = self.structure.bodies.get(self.index)
        {
            let program = &body.program;
            let mut analysis = Analysis {
                structure: &self.structure,
                program,
                input: &input,
                calls_by_node: input.calls.iter().map(|c| (c.node, c)).collect(),
                slots: Vec::new(),
                epoch: 0,
                metrics: ScopeMetrics::default(),
                position: 0,
            };
            let mut run = Run::default();
            // entry.positions は既に最後の引数が先頭であり、重ねて逆順にはしない。
            for (i, binding) in input.entry.positions.iter().enumerate().rev() {
                let id = u64::try_from(i).unwrap_or(u64::MAX);
                analysis.slots.push(Slot {
                    local: ScopeLocal {
                        binding: *binding,
                        id,
                        fact: None,
                    },
                    tail: run.state.head,
                    epoch: 0,
                });
                run.state.head = analysis.slots.len().checked_sub(1);
            }
            run.state.next_id = input.entry.next_id;
            let statements: BTreeMap<NodeId, u64> = input
                .statements
                .iter()
                .map(|s| (s.statement, s.preorder))
                .collect();
            let mut saved = Vec::new();
            let mut snapshots = Vec::new();
            for instruction in &program.code {
                match instruction {
                    Instruction::Stop(reason) => {
                        stopped = Some(*reason);
                        break;
                    }
                    Instruction::Record(node) => {
                        if let Some(preorder) = statements.get(node) {
                            analysis.position = *preorder;
                            snapshots.push((*preorder, run.state.clone()));
                        } else {
                            stopped = Some(ScopeInputStop::MissingInput(*node));
                            break;
                        }
                    }
                    Instruction::Save => saved.push(run.clone()),
                    Instruction::Enter(bindings) => {
                        saved.push(run.clone());
                        let whole_stop = matches!(
                            run.stopped,
                            Some(ScopeInputStop::BudgetExceeded {
                                scope: ScopeBudgetScope::Whole,
                                ..
                            })
                        );
                        if !whole_stop {
                            run.budget.body = 0;
                            run.budget.outer_items =
                                run.budget.outer_items.saturating_add(run.state.held);
                            run.stopped = None;
                        }
                        analysis.forget(&mut run.state);
                        for binding in bindings {
                            analysis.extend(&mut run.state, *binding, None);
                        }
                    }
                    Instruction::Restore | Instruction::Leave => {
                        if let Some(mut outer) = saved.pop() {
                            if matches!(instruction, Instruction::Leave) {
                                outer.budget.whole = run.budget.whole;
                                if matches!(
                                    run.stopped,
                                    Some(ScopeInputStop::BudgetExceeded {
                                        scope: ScopeBudgetScope::Whole,
                                        ..
                                    })
                                ) {
                                    outer.stopped = run.stopped;
                                    analysis.forget(&mut outer.state);
                                }
                            } else {
                                outer.budget = run.budget;
                                if run.stopped.is_some() {
                                    outer.stopped = run.stopped;
                                    analysis.forget(&mut outer.state);
                                }
                            }
                            run = outer;
                        }
                    }
                    Instruction::Bind { .. } | Instruction::Ok { .. } => {
                        analysis.step(&mut run, instruction, limits)
                    }
                }
            }
            stopped = stopped.or(run.stopped);
            let mut by_key: BTreeMap<u64, Vec<&Snapshot>> = BTreeMap::new();
            for (key, state) in &snapshots {
                by_key.entry(*key).or_default().push(state);
            }
            for call in &input.calls {
                let empty = Snapshot::default();
                let states = by_key
                    .get(&call.preorder)
                    .cloned()
                    .unwrap_or_else(|| vec![&empty]);
                for st in states {
                    let arguments = analysis.arguments(st, call);
                    // analyzeExpr が辿らないパイプ等の内側には transfer も置かない。
                    // 引数のリテラルは残し、受理の index は factFree で計算できる。
                    let result = by_key
                        .contains_key(&call.preorder)
                        .then(|| analysis.transfer(call, &arguments))
                        .flatten();
                    calls.push(ScopeCallFacts {
                        key: analysis.key(call.preorder),
                        declaration: call.declaration,
                        arguments,
                        result,
                    });
                }
            }
            metrics = analysis.metrics;
            let slots = Arc::new(analysis.slots);
            for (preorder, snapshot) in snapshots {
                records.push(ScopeRecord {
                    key: ScopeKey {
                        definition: input.body_key.definition.clone(),
                        surface_preorder: preorder,
                    },
                    state: ScopeState {
                        snapshot,
                        slots: Arc::clone(&slots),
                    },
                });
            }
        }
        let mut fact_indices: BTreeMap<u64, Vec<usize>> = BTreeMap::new();
        for (index, call) in calls.iter().enumerate() {
            fact_indices
                .entry(call.key.surface_preorder)
                .or_default()
                .push(index);
        }
        ScopeAnalysis {
            metrics,
            input,
            records,
            calls,
            stopped,
            fact_indices,
        }
    }
}
