//! 規則による範囲の選択と、型制約で確定した列の受理
//! （設計書 02-05「Scope の必須判定の入力」）。

use super::context::{Body, reason, substitute_effect};
use super::infer::*;
use super::scope::*;
use super::solve::Solver;
use crate::base::{BindingId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::types::builtin::{BuiltinTypeId, RangeIndex};
use crate::types::scope::Range;
use crate::types::signature::IoShape;
use crate::types::{Scheme, TyCon};
use std::collections::BTreeMap;

struct Pending {
    head: NodeId,
    call: NodeId,
    span: Span,
    source_span: Span,
    source: ITy,
    destination: Option<ITy>,
    fallback: Range,
    kind: BuiltinTypeId,
    check: bool,
    requires_top: bool,
}

// 単一の対象を持つ標準操作は、期待される関数型の入力からも範囲を選ぶ。
// Scope の成功型を推論する規則と分け、操作の戻り値から所属を作らない
// （設計書 02-05「型とエフェクトの表現」）。
struct PendingIo {
    head: NodeId,
    binding: BindingId,
    span: Span,
    source: ITy,
    kind: BuiltinTypeId,
    position: u32,
    latent: IEffect,
}

/// 本体ごとの解析を一度保存し、型と診断の確定後まで保持する。
#[derive(Default)]
pub(super) struct ScopedCalls {
    input: Option<ScopeBodyInput>,
    analysis: Option<ScopeAnalysis>,
    calls: BTreeMap<NodeId, ScopeCall>,
    spans: BTreeMap<NodeId, Span>,
    ranges: BTreeMap<NodeId, Vec<Range>>,
    annotations: BTreeMap<NodeId, Vec<Span>>,
    pending: Vec<Pending>,
    pending_io: Vec<PendingIo>,
}

impl ScopedCalls {
    pub(super) fn pending_count(&self) -> usize {
        self.pending.len().saturating_add(self.pending_io.len())
    }
}

fn limits() -> ScopeLimits {
    DEFAULT_SCOPE_LIMITS
}

impl Body<'_, '_> {
    pub(super) fn prepare_scope(&mut self, binding: BindingId) {
        let Some(input) = self
            .decls
            .out
            .scope_inputs
            .lookup(binding)
            .filter(|body| body.contains_rules() && !body.has_diagnosed_input())
            .cloned()
        else {
            return;
        };
        let analysis = input.analyze_pending_with_limits(limits());
        let calls = if analysis.input.stopped.is_some() {
            input.rule_calls()
        } else {
            analysis.input.calls.clone()
        };
        self.scoped_calls.calls = calls.into_iter().map(|call| (call.node, call)).collect();
        self.scoped_calls.input = Some(input);
        self.scoped_calls.analysis = Some(analysis);
    }

    /// 初期の列には宣言した個数の Top を置き、直接の規則では選択値を保存する。
    /// 単一対象の操作の列は、期待される入力型も用いて制約の解決時に確定する。
    pub(super) fn signature_at_call(
        &mut self,
        head: NodeId,
        _span: Span,
        binding: BindingId,
    ) -> Option<Scheme> {
        let signature = self
            .decls
            .out
            .range_signatures
            .get(binding)
            .cloned()
            .unwrap_or_default();
        let mut ranges = vec![Range::Top; signature.range_count()];
        if let Some(call) = self
            .active_scope_call
            .and_then(|node| self.scoped_calls.calls.get(&node))
            && call.binding == binding
            && let Some(analysis) = &self.scoped_calls.analysis
        {
            match analysis.selected_ranges(call) {
                Ok(selected) => {
                    for (slot, range) in ranges.iter_mut().zip(selected) {
                        *slot = range;
                    }
                }
                Err(_) => {
                    self.diagnostic(crate::runtime::report::internal_diagnostic(
                        "check",
                        "scope input stopped before range selection",
                        None,
                        crate::runtime::report::FaultThread::Stage,
                    ));
                    return None;
                }
            }
        }
        self.decls.out.call_ranges.insert(head, ranges.clone());
        if signature.range_count() == 0 {
            return self.signature_at_top(binding);
        }
        let scheme = self.decls.out.decl_types.get(binding)?;
        let operation = self
            .decls
            .resolved
            .bindings
            .get(binding)
            .is_some_and(|b| matches!(b.kind, crate::resolve::BindingKind::Op { .. }));
        signature.instantiate(scheme, &ranges, operation)
    }

    /// 添字を型変数として公開せず、対象の不透明型だけを一時的な型変数にする。
    /// 単一対象の操作では、入力と同じ範囲の潜在効果も解決まで保留する。
    pub(super) fn scope_shape(
        &mut self,
        head: NodeId,
        span: Span,
        binding: BindingId,
        mut params: Vec<ITy>,
        mut ret: ITy,
        effect: IEffect,
    ) -> (Vec<ITy>, ITy, IEffect) {
        if let Some(IoShape::Single { kind, position }) = self
            .decls
            .out
            .range_signatures
            .get(binding)
            .map(|signature| signature.shape)
        {
            let target = usize::try_from(position)
                .ok()
                .and_then(|position| params.get_mut(position));
            if let Some(target @ ITy::Con(_, _, _)) = target {
                let value_kind = match target {
                    ITy::Con(TyCon::Builtin(id), args, _) if args.is_empty() => {
                        (id.value_kind() == Some(kind)).then_some(*id)
                    }
                    ITy::Var(_)
                    | ITy::Con(..)
                    | ITy::Fn(_)
                    | ITy::Param(_)
                    | ITy::App(..)
                    | ITy::Rigid { .. }
                    | ITy::Error => None,
                };
                if let Some(kind) = value_kind {
                    let source = self.fresh_ty();
                    let latent = self.fresh_effect();
                    *target = source.clone();
                    self.scoped_calls.pending_io.push(PendingIo {
                        head,
                        binding,
                        span,
                        source,
                        kind,
                        position,
                        latent: latent.clone(),
                    });
                    return (params, ret, latent);
                }
            }
            self.diagnostic(crate::runtime::report::internal_diagnostic(
                "check",
                "single-target operation had no certified target parameter",
                None,
                crate::runtime::report::FaultThread::Stage,
            ));
            return (params, ret, effect);
        }
        let Some(call) = self
            .active_scope_call
            .and_then(|node| self.scoped_calls.calls.get(&node))
            .cloned()
            .filter(|call| call.binding == binding)
        else {
            return (params, ret, effect);
        };
        let kind = match call.declaration {
            ScopeDeclaration::CheckPath
            | ScopeDeclaration::PathValue
            | ScopeDeclaration::WidenPath => BuiltinTypeId::PATH_IN,
            ScopeDeclaration::CheckRequest
            | ScopeDeclaration::RequestValue
            | ScopeDeclaration::WidenRequest => BuiltinTypeId::REQUEST_IN,
        };
        let source = self.fresh_ty();
        let destination = matches!(
            call.declaration,
            ScopeDeclaration::WidenPath | ScopeDeclaration::WidenRequest
        )
        .then(|| self.fresh_ty());
        match call.declaration {
            ScopeDeclaration::CheckPath | ScopeDeclaration::CheckRequest => {
                if let ITy::Con(_, args, _) = &mut ret {
                    for arg in args {
                        if matches!(arg, ITy::Con(TyCon::Builtin(id), _, _) if *id == kind) {
                            *arg = source.clone();
                        }
                    }
                }
            }
            ScopeDeclaration::PathValue
            | ScopeDeclaration::RequestValue
            | ScopeDeclaration::WidenPath
            | ScopeDeclaration::WidenRequest => {
                if let Some(param) = params.first_mut() {
                    *param = source.clone();
                }
                if let Some(destination) = &destination {
                    ret = destination.clone();
                }
            }
        }
        let fallback = self
            .decls
            .out
            .call_ranges
            .get(head)
            .and_then(|ranges| ranges.first())
            .cloned()
            .unwrap_or(Range::Top);
        let check = matches!(
            call.declaration,
            ScopeDeclaration::CheckPath | ScopeDeclaration::CheckRequest
        );
        // 由来が未知の射影・拡大は Top だけを受理する。検査の既定値を
        // 選ぶ前に通常の型制約へ渡し、同じ成功型にもこの要求を伝える。
        let requires_top = !check
            && self.scoped_calls.analysis.as_ref().is_some_and(|analysis| {
                analysis.required_ranges(&call).is_ok_and(|states| {
                    states.iter().flatten().any(|requirement| {
                        matches!(
                            requirement,
                            ScopeRequired::Unknown | ScopeRequired::Exceeded
                        )
                    })
                })
            });
        self.scoped_calls.spans.insert(call.node, span);
        let source_span = call
            .contract_to_source
            .first()
            .and_then(|source| match source {
                ScopeArgumentSource::Explicit(index) => call.argument_preorders.get(*index),
                ScopeArgumentSource::PipeLeft(_) => None,
            })
            .and_then(|preorder| {
                self.scoped_calls.analysis.as_ref().and_then(|analysis| {
                    analysis
                        .input
                        .occurrences
                        .binary_search_by_key(preorder, |occurrence| occurrence.preorder)
                        .ok()
                        .and_then(|index| analysis.input.occurrences.get(index))
                })
            })
            .map_or(span, |occurrence| occurrence.span);
        self.scoped_calls.pending.push(Pending {
            head,
            call: call.node,
            span,
            source_span,
            source,
            destination,
            fallback,
            kind,
            check,
            requires_top,
        });
        (params, ret, effect)
    }

    pub(super) fn finish_scope(&mut self) {
        if self.scoped_calls.analysis.is_some() {
            self.decls
                .scope_analyses
                .push(std::mem::take(&mut self.scoped_calls));
        }
    }
}

fn candidate(solver: &Solver, ty: &ITy, kind: BuiltinTypeId) -> Option<Range> {
    match solver.zonk(ty) {
        ITy::Con(TyCon::Builtin(id), args, ix) if id == kind && args.is_empty() => {
            ix.range().cloned()
        }
        ITy::Var(_)
        | ITy::Con(..)
        | ITy::Fn(_)
        | ITy::Param(_)
        | ITy::App(..)
        | ITy::Rigid { .. }
        | ITy::Error => None,
    }
}

fn opaque(kind: BuiltinTypeId, range: Range) -> ITy {
    ITy::Con(TyCon::Builtin(kind), Vec::new(), RangeIndex::fixed(range))
}

/// 呼び出しと注釈の制約を使い切ってから、未指定の元範囲には規則の選択を使う。
pub(super) fn resolve(
    ctx: &mut Body<'_, '_>,
    solver: &Solver,
    final_pass: bool,
) -> Vec<Constraint> {
    resolve_selected(ctx, solver, final_pass, None)
}

/// 節に関係しない検査の既定値を早めず、保護本体の IO 入力に必要な分だけ確定する。
pub(super) fn resolve_handler_body(ctx: &mut Body<'_, '_>, solver: &Solver) -> Vec<Constraint> {
    let Some(handler) = ctx.pending_handlers.front() else {
        return Vec::new();
    };
    let inputs = solver.effect_inputs(handler.body_effect());
    let nodes: std::collections::BTreeSet<_> = ctx
        .scoped_calls
        .pending_io
        .iter()
        .filter(|pending| {
            pending
                .latent
                .var
                .is_some_and(|row| inputs.contains(&row.0))
        })
        .map(|pending| pending.head)
        .collect();
    let sources = ctx
        .scoped_calls
        .pending_io
        .iter()
        .filter(|pending| nodes.contains(&pending.head))
        .filter_map(|pending| match solver.zonk(&pending.source) {
            ITy::Var(variable) => Some(variable.0),
            ITy::Con(..)
            | ITy::Fn(_)
            | ITy::Param(_)
            | ITy::App(..)
            | ITy::Rigid { .. }
            | ITy::Error => None,
        })
        .collect();
    resolve_selected(ctx, solver, true, Some((&nodes, &sources)))
}

fn resolve_selected(
    ctx: &mut Body<'_, '_>,
    solver: &Solver,
    final_pass: bool,
    selected: Option<(
        &std::collections::BTreeSet<NodeId>,
        &std::collections::BTreeSet<u32>,
    )>,
) -> Vec<Constraint> {
    let can_default = |source: &ITy| {
        selected.is_none_or(|(_, sources)| {
        matches!(solver.zonk(source), ITy::Var(variable) if sources.contains(&variable.0))
    })
    };
    let mut constraints = Vec::new();
    for pending in &ctx.scoped_calls.pending {
        if pending.requires_top && matches!(solver.zonk(&pending.source), ITy::Var(_)) {
            constraints.push(Constraint::Equal {
                expected: opaque(pending.kind, Range::Top),
                found: pending.source.clone(),
                reason: reason(pending.source_span, ReasonKind::CallArg { index: 1 }),
            });
        }
    }
    if !constraints.is_empty() {
        // 既定値を選ぶ前に Top の要求を解く。既に注釈で決まった狭い型は
        // 書き換えず、後の必須受理で unknownSource として拒否する。
        return constraints;
    }
    let mut waiting = Vec::new();
    let checks_pending = ctx
        .scoped_calls
        .pending
        .iter()
        .any(|pending| pending.check && can_default(&pending.source));
    // 合流などで同じ未確定の型変数を共有する検査は、一括で既定値を選ぶ。
    // 狭い既定値が食い違えば Top とし、走査順で先の範囲へ固定しない。
    let mut defaults = BTreeMap::new();
    if final_pass {
        for pending in &ctx.scoped_calls.pending {
            if pending.check
                && can_default(&pending.source)
                && let ITy::Var(variable) = solver.zonk(&pending.source)
            {
                defaults
                    .entry(variable.0)
                    .and_modify(|range| {
                        if *range != pending.fallback {
                            *range = Range::Top;
                        }
                    })
                    .or_insert_with(|| pending.fallback.clone());
            }
        }
    }
    for pending in std::mem::take(&mut ctx.scoped_calls.pending) {
        let source = candidate(solver, &pending.source, pending.kind);
        let destination = pending
            .destination
            .as_ref()
            .and_then(|ty| candidate(solver, ty, pending.kind));
        let unresolved = source.is_none() || pending.destination.is_some() && destination.is_none();
        if unresolved
            && (!final_pass || !can_default(&pending.source) || checks_pending && !pending.check)
        {
            waiting.push(pending);
            continue;
        }
        let source = source.unwrap_or_else(|| {
            if let ITy::Var(variable) = solver.zonk(&pending.source)
                && let Some(range) = defaults.get(&variable.0)
            {
                return range.clone();
            }
            pending.fallback
        });
        let annotations = std::iter::once(&pending.source)
            .chain(pending.destination.iter())
            .filter_map(|ty| solver.scope_annotation(ty))
            .collect::<Vec<_>>();
        if !annotations.is_empty() {
            ctx.scoped_calls
                .annotations
                .insert(pending.call, annotations);
        }
        let mut ranges = vec![source.clone()];
        if let Some(target) = &pending.destination {
            if let Some(destination) = destination {
                ranges.push(destination.clone());
                constraints.push(Constraint::Equal {
                    expected: opaque(pending.kind, destination),
                    found: target.clone(),
                    reason: reason(pending.span, ReasonKind::ScopeResult),
                });
            } else {
                // 対応する検査済みの戻り型がなければ、拡大の行き先を補わない。
                ctx.diagnostic(
                    DiagBuilder::new(DiagCode::E0407)
                        .primary(pending.span)
                        .help(if pending.kind == BuiltinTypeId::PATH_IN {
                            "scope_widen_path"
                        } else {
                            "scope_widen_request"
                        })
                        .build(),
                );
                constraints.push(Constraint::Equal {
                    expected: ITy::Error,
                    found: target.clone(),
                    reason: reason(pending.span, ReasonKind::ScopeResult),
                });
            }
        }
        constraints.push(Constraint::Equal {
            expected: opaque(pending.kind, source),
            found: pending.source,
            reason: if pending.check {
                reason(pending.span, ReasonKind::ScopeResult)
            } else {
                reason(pending.source_span, ReasonKind::CallArg { index: 1 })
            },
        });
        ctx.decls
            .out
            .call_ranges
            .insert(pending.head, ranges.clone());
        ctx.scoped_calls.ranges.insert(pending.call, ranges);
    }
    ctx.scoped_calls.pending = waiting;
    // 検査の成功型を先に一括で確定してから、入力の型と同じ範囲を潜在効果へ写す。
    // 個別の候補ごとに solver 全体を再訪しない。
    let mut waiting_io = Vec::new();
    for pending in std::mem::take(&mut ctx.scoped_calls.pending_io) {
        let source = candidate(solver, &pending.source, pending.kind);
        if source.is_none()
            && (!final_pass
                || checks_pending
                || selected.is_some_and(|(nodes, _)| !nodes.contains(&pending.head)))
        {
            waiting_io.push(pending);
            continue;
        }
        let source = source.unwrap_or(Range::Top);
        let ranges = vec![source.clone()];
        let operation = ctx
            .decls
            .resolved
            .bindings
            .get(pending.binding)
            .is_some_and(|binding| matches!(binding.kind, crate::resolve::BindingKind::Op { .. }));
        let concrete = ctx
            .decls
            .out
            .range_signatures
            .get(pending.binding)
            .zip(ctx.decls.out.decl_types.get(pending.binding))
            .and_then(|(signature, scheme)| signature.instantiate(scheme, &ranges, operation));
        let Some((concrete, (types, rows))) = concrete.zip(ctx.type_args.get(pending.head)) else {
            ctx.diagnostic(crate::runtime::report::internal_diagnostic(
                "check",
                "single-target operation scope instantiation was incomplete",
                None,
                crate::runtime::report::FaultThread::Stage,
            ));
            continue;
        };
        let effect = substitute_effect(&concrete.effects, types, rows);
        let site = reason(
            pending.span,
            ReasonKind::CallArg {
                index: pending.position.saturating_add(1),
            },
        );
        constraints.push(Constraint::Equal {
            expected: opaque(pending.kind, source),
            found: pending.source,
            reason: site.clone(),
        });
        for (sub, sup) in [
            (effect.clone(), pending.latent.clone()),
            (pending.latent, effect),
        ] {
            // solve_pair は型の制約だけを処理するため、行の制約は solver の
            // 既存の登録入口へ次の再訪で渡す（設計書 02-05「制約の解決」）。
            ctx.add(Constraint::EffSub {
                relation: EffectRelation::Structural,
                sub,
                sup,
                reason: site.clone(),
            });
        }
        ctx.decls.out.call_ranges.insert(pending.head, ranges);
    }
    ctx.scoped_calls.pending_io = waiting_io;
    constraints
}

fn diagnostic(
    declaration: ScopeDeclaration,
    span: Span,
    failure: ScopeCoverFailure,
    budget: Option<ScopeInputStop>,
) -> crate::diag::Diagnostic {
    let reason = match failure {
        ScopeCoverFailure::NotCovered => super::text::NOT_COVERED,
        ScopeCoverFailure::UnknownSource => super::text::UNKNOWN_SOURCE,
        ScopeCoverFailure::BudgetExceeded => super::text::BUDGET_EXCEEDED,
    };
    let mut builder = DiagBuilder::new(DiagCode::E0519)
        .arg("effect", declaration.name())
        .arg("expected", super::text::SCOPE_RULE_CONTRACT)
        .arg("reason", reason)
        .primary(span)
        .note("scope_rule")
        .help(match failure {
            ScopeCoverFailure::NotCovered => "scope_coverage",
            ScopeCoverFailure::UnknownSource => match declaration {
                ScopeDeclaration::CheckPath | ScopeDeclaration::CheckRequest => {
                    "scope_check_unknown"
                }
                ScopeDeclaration::PathValue
                | ScopeDeclaration::RequestValue
                | ScopeDeclaration::WidenPath
                | ScopeDeclaration::WidenRequest => "scope_unknown",
            },
            ScopeCoverFailure::BudgetExceeded => match budget {
                Some(ScopeInputStop::NumberingLimit { .. }) => "scope_numbering_help",
                _ => "scope_budget_help",
            },
        });
    if failure == ScopeCoverFailure::BudgetExceeded
        && let Some(ScopeInputStop::BudgetExceeded { scope, resource }) = budget
    {
        builder = builder
            .arg(
                "budgetScope",
                match scope {
                    ScopeBudgetScope::Body => super::text::SCOPE_BUDGET_BODY,
                    ScopeBudgetScope::Whole => super::text::SCOPE_BUDGET_WHOLE,
                },
            )
            .arg(
                "budgetResource",
                match resource {
                    ScopeBudgetResource::Operations => super::text::SCOPE_BUDGET_OPERATIONS,
                    ScopeBudgetResource::Items => super::text::SCOPE_BUDGET_ITEMS,
                },
            )
            .note("scope_budget");
    }
    if failure == ScopeCoverFailure::BudgetExceeded
        && let Some(ScopeInputStop::NumberingLimit { max_operations }) = budget
    {
        builder = builder
            .arg(
                "numberingLimit",
                super::text::scope_numbering_limit(max_operations),
            )
            .note("scope_numbering");
    }
    let mut diagnostic = builder.build_variant(match declaration {
        ScopeDeclaration::CheckPath | ScopeDeclaration::CheckRequest => "scope_check",
        ScopeDeclaration::PathValue | ScopeDeclaration::RequestValue => "scope_projection",
        ScopeDeclaration::WidenPath | ScopeDeclaration::WidenRequest => "scope_widen",
    });
    diagnostic
        .notes
        .push(super::text::scope_field(super::text::SCOPE_REASON, reason));
    diagnostic
}

/// 診断だけの補足を作る。受理の判定・範囲の列・事実は書き換えない。
fn explain_rejection(
    diag: &mut crate::diag::Diagnostic,
    annotations: &BTreeMap<NodeId, Vec<Span>>,
    analysis: &ScopeAnalysis,
    call: &ScopeCall,
    ranges: &[Range],
) {
    let contracts = if matches!(
        call.declaration,
        ScopeDeclaration::WidenPath | ScopeDeclaration::WidenRequest
    ) {
        super::text::scope_widen_contract(ranges)
    } else {
        ranges
            .iter()
            .map(super::text::scope_range)
            .collect::<Vec<_>>()
            .join(", ")
    };
    diag.notes.push(super::text::scope_field(
        super::text::SCOPE_REQUIRED_UPPER_BOUND,
        &contracts,
    ));
    let mut all_known = false;
    if let Ok(required) = analysis.required_ranges(call) {
        all_known = !required.is_empty()
            && required
                .iter()
                .flatten()
                .all(|requirement| matches!(requirement, ScopeRequired::Known(_)));
        let mut known = Vec::new();
        for requirement in required.into_iter().flatten() {
            let shown = super::text::scope_range(&requirement.index());
            if !known.contains(&shown) {
                known.push(shown);
            }
        }
        diag.notes.push(super::text::scope_field(
            super::text::SCOPE_KNOWN_UPPER_BOUND,
            &known.join(", "),
        ));
    }
    for span in annotations.get(&call.node).into_iter().flatten() {
        if !diag.secondary.iter().any(|label| label.span == *span) {
            diag.secondary.push(crate::diag::Label {
                span: *span,
                text: super::text::SCOPE_CONTRACT_ANNOTATION.into(),
            });
        }
    }
    let mut sources = Vec::new();
    for facts in analysis
        .calls
        .iter()
        .filter(|facts| facts.key.surface_preorder == call.preorder)
    {
        for argument in &facts.arguments {
            if let ScopeArgument::Local {
                id,
                fact: Some(ScopeFact::Checked { origin, success_id }),
            } = argument
                && id == success_id
                && !sources.contains(&origin.key.surface_preorder)
            {
                sources.push(origin.key.surface_preorder);
            }
        }
    }
    if matches!(
        call.declaration,
        ScopeDeclaration::CheckPath | ScopeDeclaration::CheckRequest
    ) && all_known
    {
        diag.notes.push(super::text::scope_field(
            super::text::SCOPE_SOURCE,
            super::text::SCOPE_LITERAL_SOURCE,
        ));
    } else if sources.is_empty() {
        let source = if analysis.input.stopped.is_some() {
            super::text::SCOPE_NUMBERING_SOURCE
        } else if analysis.stopped.is_some() {
            super::text::SCOPE_BUDGET_SOURCE
        } else if matches!(
            call.declaration,
            ScopeDeclaration::CheckPath | ScopeDeclaration::CheckRequest
        ) {
            super::text::SCOPE_UNKNOWN_CONDITIONS
        } else {
            super::text::SCOPE_UNKNOWN_SOURCE
        };
        diag.notes
            .push(super::text::scope_field(super::text::SCOPE_SOURCE, source));
    } else {
        for preorder in sources {
            diag.notes.push(super::text::scope_field(
                super::text::SCOPE_SOURCE,
                &super::text::scope_success_source(&analysis.input.body_key.definition, preorder),
            ));
            if let Some(occurrence) = analysis
                .input
                .occurrences
                .iter()
                .find(|occurrence| occurrence.preorder == preorder)
            {
                diag.secondary.push(crate::diag::Label {
                    span: occurrence.span,
                    text: super::text::SCOPE_SUCCESS_CHECK.into(),
                });
            }
        }
    }
}

/// 表層の番号だけを確定し直し、解析を再実行せず全定義とメソッドを受理する。
pub(super) fn accept_program(decls: &mut super::decls::Decls<'_>) {
    if decls
        .diagnostics
        .iter()
        .any(crate::diag::Diagnostic::is_error)
    {
        return;
    }
    let mut bodies = std::mem::take(&mut decls.scope_analyses);
    // 表層の受理入口は通常の定義を全て調べてから実装メソッドへ進む
    // （設計書 01-12「Scope の必須の判定の受理と拒否の理由」）。
    bodies.sort_by_key(|body| {
        body.input
            .as_ref()
            .and_then(|input| input.binding)
            .and_then(|binding| decls.resolved.bindings.get(binding))
            .is_some_and(|binding| {
                matches!(binding.kind, crate::resolve::BindingKind::ImplFn { .. })
            })
    });
    for mut body in bodies {
        let Some(original) = &body.input else {
            continue;
        };
        let Some(input) = original
            .binding
            .and_then(|binding| decls.out.scope_inputs.lookup(binding))
        else {
            continue;
        };
        let Some(analysis) = &mut body.analysis else {
            continue;
        };
        if analysis
            .renumber(input.numbered(DEFAULT_NUMBERING_OPERATIONS))
            .is_err()
        {
            decls
                .diagnostics
                .push(crate::runtime::report::internal_diagnostic(
                    "check",
                    "scope numbering could not be finalized",
                    None,
                    crate::runtime::report::FaultThread::Stage,
                ));
            break;
        }
        if analysis.stopped.is_some_and(|stop| {
            !matches!(
                stop,
                ScopeInputStop::BudgetExceeded { .. } | ScopeInputStop::NumberingLimit { .. }
            )
        }) {
            decls
                .diagnostics
                .push(crate::runtime::report::internal_diagnostic(
                    "check",
                    "scope acceptance input stopped without a budget result",
                    None,
                    crate::runtime::report::FaultThread::Stage,
                ));
            return;
        }
        let calls = if analysis.input.stopped.is_some() {
            input.rule_calls()
        } else {
            analysis.input.calls.clone()
        };
        for call in calls {
            let ranges = body.ranges.get(&call.node).map_or(&[][..], Vec::as_slice);
            // 必須判定の未知・超過を先に分類する。型付けの widen 許容はその後に確かめる。
            let accepted = analysis.accept_call(&call, ranges).and_then(|()| {
                match decls.out.range_signatures.get(call.binding) {
                    Some(signature) if !signature.admits(ranges) => {
                        // widen の S が R を覆わないときは、S に対する Required の
                        // 未知・超過を先に報告する。既知の事実だけが notCovered になる。
                        if matches!(
                            call.declaration,
                            ScopeDeclaration::WidenPath | ScopeDeclaration::WidenRequest
                        ) {
                            analysis.accept_call(&call, ranges.get(1..).unwrap_or_default())?;
                        }
                        Err(ScopeAcceptError::Rejected(ScopeRejection {
                            definition: analysis.input.body_key.definition.clone(),
                            preorder: analysis.input.stopped.is_none().then_some(call.preorder),
                            node: call.node,
                            reason: ScopeCoverFailure::NotCovered,
                        }))
                    }
                    _ => Ok(()),
                }
            });
            if let Err(error) = accepted {
                match error {
                    ScopeAcceptError::Rejected(rejection) => {
                        if let Some(span) = body.spans.get(&call.node).copied() {
                            let mut diag = diagnostic(
                                call.declaration,
                                span,
                                rejection.reason,
                                analysis.stopped,
                            );
                            explain_rejection(
                                &mut diag,
                                &body.annotations,
                                analysis,
                                &call,
                                ranges,
                            );
                            // 番号付けの停止では番号を補わず、Run だけの超過では確定した番号を使う。
                            diag.notes.push(super::text::scope_key(
                                &rejection.definition,
                                rejection.preorder,
                            ));
                            decls.diagnostics.push(diag);
                        } else {
                            decls
                                .diagnostics
                                .push(crate::runtime::report::internal_diagnostic(
                                    "check",
                                    "rejected scope call had no source span",
                                    None,
                                    crate::runtime::report::FaultThread::Stage,
                                ));
                        }
                    }
                    ScopeAcceptError::InputStopped(_) => {
                        decls
                            .diagnostics
                            .push(crate::runtime::report::internal_diagnostic(
                                "check",
                                "scope acceptance input was incomplete",
                                None,
                                crate::runtime::report::FaultThread::Stage,
                            ))
                    }
                }
                return;
            }
        }
    }
}
