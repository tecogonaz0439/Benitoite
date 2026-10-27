//! Range の認定の借用走査と、由来の保存前の計上
//! （設計書 01-12「区間解析の予算付きの局所走査」）。

use super::*;
use crate::typeck::interval::input::SurfaceForm;

pub(super) enum Call {
    Range,
    Shift(super::super::fixed_domain::Entry),
}

/// 成功値の同定に要る解決済みの名前。表示名からは作らない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck::interval) struct Names {
    result: BindingId,
    owner: BindingId,
    error: BindingId,
    ok: BindingId,
    err: BindingId,
}

/// 診断の由来とは別に、同じ検査の結果を識別する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck::interval) struct Origin {
    names: Names,
    key: u64,
    minimum: i128,
    maximum: i128,
}

/// checked の番号は、この記録を置く局所位置の番号と一致しなければならない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck::interval) struct Fact {
    pub origin: Origin,
    pub success_id: Option<u64>,
}

enum Standard {
    Check {
        declaration: BindingId,
        names: Names,
    },
    Value {
        declaration: BindingId,
        owner: BindingId,
    },
    Shift(super::super::fixed_domain::Entry),
}

impl Standard {
    fn declaration(&self) -> BindingId {
        match self {
            Self::Check { declaration, .. } | Self::Value { declaration, .. } => *declaration,
            Self::Shift(entry) => entry.declaration,
        }
    }

    fn check(&self) -> Option<Names> {
        match self {
            Self::Check { names, .. } => Some(*names),
            Self::Value { .. } | Self::Shift(_) => None,
        }
    }

    fn value(&self) -> Option<BindingId> {
        match self {
            Self::Value { owner, .. } => Some(*owner),
            Self::Check { .. } | Self::Shift(_) => None,
        }
    }
}

/// 標準表と出現表は解決済みの宣言から作る。空の表を名前の字面で補わない。
pub(in crate::typeck::interval) struct Tables {
    standards: Vec<Standard>,
    calls: BTreeMap<NodeId, BindingId>,
}

impl Tables {
    fn range_bindings(
        body: &crate::typeck::context::Body<'_, '_>,
    ) -> Option<(BindingId, BindingId, Names)> {
        let resolved = body.decls.resolved;
        Some((
            resolved.stdlib("Benitoite.Range.checkInteger")?,
            resolved.stdlib("Benitoite.Range.value")?,
            Names {
                result: resolved.stdlib("Benitoite.Result.Result")?,
                owner: resolved.stdlib("Benitoite.Range.CheckedInteger")?,
                error: resolved.stdlib("Benitoite.Range.RangeError")?,
                ok: resolved.stdlib("Benitoite.Result.Ok")?,
                err: resolved.stdlib("Benitoite.Result.Error")?,
            },
        ))
    }

    /// finish 前に解決済みの宣言だけを保存する。CallPlan と表示名には依存しない。
    pub(in crate::typeck::interval) fn collect(
        definition: &super::super::input::Definition<'_>,
        body: &crate::typeck::context::Body<'_, '_>,
    ) -> Option<Box<Self>> {
        let range = Self::range_bindings(body);
        let mut has_range = false;
        let mut has_shift = false;
        let mut shifts = None;
        let mut calls = BTreeMap::new();
        let mut visit = |source: &Expr| {
            // 名前の出現を保存すれば、定数展開・別本体の元キーからも同じ同定を読める。
            if let Some((check, value, names)) = range {
                for (name, declaration) in [
                    ("Benitoite.Range.checkInteger", check),
                    ("Benitoite.Range.value", value),
                    ("Benitoite.Result.Ok", names.ok),
                ] {
                    if crate::typeck::consts::std_call(body.decls, source, name) {
                        calls.insert(source.id(), declaration);
                        has_range = true;
                        return;
                    }
                }
            }
            let Expr::Name(name) = source else {
                return;
            };
            let Some(binding) = body.decls.resolved.binding_of_ref(name.id) else {
                return;
            };
            // 通常の本体には27宣言の署名確認や追加確保を持ち込まない。
            // この綴りの確認は候補を絞るだけで、同定は必ず std_call と署名で行う。
            if !matches!(
                binding.name.as_str(),
                "shiftLeft" | "shiftRight" | "shiftRightUnsigned"
            ) {
                return;
            }
            let entries =
                shifts.get_or_insert_with(|| super::super::fixed_domain::loaded(body.decls));
            for entry in entries {
                if crate::typeck::consts::std_call(body.decls, source, entry.contract.name) {
                    calls.insert(source.id(), entry.declaration);
                    has_shift = true;
                    break;
                }
            }
        };
        match definition.source {
            BodySource::Function { body, .. } => {
                crate::typeck::consts::visit_block(body, &mut visit)
            }
            BodySource::Constant(source) => {
                crate::typeck::consts::visit_expr(&source.value, &mut visit)
            }
        }
        if calls.is_empty() {
            return None;
        }
        let mut standards = Vec::new();
        if has_range && let Some((check, value, names)) = range {
            standards.push(Standard::Check {
                declaration: check,
                names,
            });
            standards.push(Standard::Value {
                declaration: value,
                owner: names.owner,
            });
        }
        // Range の二項を動かさず、シフトは完全名の辞書順で追加する。
        // 出現のない本体は従来の二表のままにする。交換もこの順序を使う。
        if has_shift {
            standards.extend(shifts.into_iter().flatten().map(Standard::Shift));
        }
        Some(Box::new(Self { standards, calls }))
    }
}

impl<'ast> Flow<'_, 'ast, '_> {
    // Scan.frame は成功・停止とも一枠を返す。環境・auxiliary はその外で保持する。
    fn range_frame<T>(
        &mut self,
        run: impl FnOnce(&mut Self) -> Result<T, IdentityStop>,
    ) -> Result<T, IdentityStop> {
        self.frame()?;
        let result = run(self);
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    fn range_tables_at(&self, key: u64) -> Option<&Tables> {
        let occurrence = self.identity.occurrences.get(usize::try_from(key).ok()?)?;
        let input = if occurrence.type_owner == self.input.definition.binding {
            self.input
        } else {
            *self.constants.get(&occurrence.type_owner)?
        };
        input.range.as_deref()
    }

    fn range_standard_at(&mut self, key: u64) -> Result<Option<usize>, IdentityStop> {
        self.tick(Operation::EnvironmentRead)?;
        let declaration = self.range_tables_at(key).and_then(|tables| {
            let occurrence = self.identity.occurrences.get(usize::try_from(key).ok()?)?;
            let super::super::identity::SourceNode::Expression(Expr::Call(call)) =
                occurrence.source
            else {
                return None;
            };
            tables.calls.get(&call.callee.id()).copied()
        });
        let Some(declaration) = declaration else {
            return Ok(None);
        };
        let mut held = 0_u64;
        let result = (|| {
            let mut index = 0_usize;
            loop {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::EnvironmentRead)?;
                let Some(entry) = self
                    .range_tables_at(key)
                    .and_then(|tables| tables.standards.get(index))
                else {
                    return Ok(None);
                };
                if entry.declaration() == declaration {
                    return Ok(Some(index));
                }
                index = index.saturating_add(1);
            }
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    /// rangeCall は由来の走査と違い、引数より先に出現の同定表を読む。
    #[inline(never)]
    pub(super) fn range_call(&mut self, source: &'ast Expr) -> Result<Option<Call>, IdentityStop> {
        let occurrence = self
            .identity
            .occurrences
            .get(
                usize::try_from(self.current_occurrence)
                    .map_err(|_| IdentityStop::NumberOverflow)?,
            )
            .ok_or(IdentityStop::Unmapped(source.id()))?;
        if occurrence.form != SurfaceForm::Call {
            return Ok(None);
        }
        self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            let Some(call) = flow.standard_direct_call(source, flow.current_occurrence, true)?
            else {
                return Ok(None);
            };
            let Some(index) = flow.range_standard_at(flow.current_occurrence)? else {
                return Ok(None);
            };
            let Some(entry) = flow
                .range_tables_at(flow.current_occurrence)
                .and_then(|tables| tables.standards.get(index))
            else {
                return Ok(None);
            };
            let Expr::Name(name) = call.callee.as_ref() else {
                return Ok(None);
            };
            if flow.reference(name.id)? != entry.declaration() {
                return Ok(None);
            }
            if entry.check().is_some() {
                if flow
                    .standard_direct_call(source, flow.current_occurrence, false)?
                    .is_none()
                {
                    return Ok(None);
                }
                return Ok(flow.range_check_arguments(call)?.then_some(Call::Range));
            } else if entry.value().is_some() {
                if flow
                    .standard_direct_call(source, flow.current_occurrence, false)?
                    .is_none()
                {
                    return Ok(None);
                }
                return Ok(flow.range_value_argument(call)?.then_some(Call::Range));
            }
            let Standard::Shift(entry) = entry else {
                return Ok(None);
            };
            let entry = *entry;
            Ok(flow
                .domain_call_shape(call, entry.contract)?
                .then_some(Call::Shift(entry)))
        })
    }

    /// rangeOrigin はラベル、引数、契約位置を借用してから同定表を読む。
    pub(super) fn range_origin(
        &mut self,
        source: &'ast Expr,
        key: u64,
    ) -> Result<Option<Origin>, IdentityStop> {
        self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            let Some(call) = flow.standard_direct_call(source, key, false)? else {
                return Ok(None);
            };
            if !flow.range_check_arguments(call)? {
                return Ok(None);
            }
            let Some(index) = flow.range_standard_at(key)? else {
                return Ok(None);
            };
            let Some(entry) = flow
                .range_tables_at(key)
                .and_then(|tables| tables.standards.get(index))
            else {
                return Ok(None);
            };
            let Expr::Name(name) = call.callee.as_ref() else {
                return Ok(None);
            };
            if flow.reference(name.id)? != entry.declaration() {
                return Ok(None);
            }
            let Some(names) = entry.check() else {
                return Ok(None);
            };
            let Some(lower) = flow.range_argument(call, 0) else {
                return Ok(None);
            };
            let Some(upper) = flow.range_argument(call, 1) else {
                return Ok(None);
            };
            let Some(minimum) = flow.constant(lower, IntKind::Integer64)? else {
                return Ok(None);
            };
            let Some(maximum) = flow.constant(upper, IntKind::Integer64)? else {
                return Ok(None);
            };
            Ok(Some(Origin {
                names,
                key,
                minimum,
                maximum,
            }))
        })
    }

    /// standardCallHead と同じ単相の funName/primName。Range の由来は funName に限る。
    fn standard_direct_call(
        &self,
        source: &'ast Expr,
        key: u64,
        primitive: bool,
    ) -> Result<Option<&'ast CallExpr>, IdentityStop> {
        let Expr::Call(call) = source else {
            return Ok(None);
        };
        let form = self
            .identity
            .occurrences
            .get(usize::try_from(key).map_err(|_| IdentityStop::NumberOverflow)?)
            .filter(|entry| entry.origin.is_some_and(|origin| origin.node == call.id))
            .map(|entry| entry.form);
        // 元の番号付けで確定した Surface の分類を使い、穴を再走査しない。
        if form != Some(SurfaceForm::Call) {
            return Ok(None);
        }
        let Expr::Name(name) = call.callee.as_ref() else {
            return Ok(None);
        };
        let binding = self.reference(name.id)?;
        let kind = self
            .tables
            .resolved
            .bindings
            .get(binding)
            .map(|entry| &entry.kind);
        // identity::name_form が PrimName にする組み込みの操作も照会する。
        // 操作の固定域の項は標準表へ登録しない（設計書 02-05「区間解析の内部入力」）。
        let ordinary = matches!(
            kind,
            Some(BindingKind::Fn | BindingKind::ImplFn { .. } | BindingKind::Field { .. })
        ) || (primitive
            && (matches!(kind, Some(BindingKind::BuiltinFn(_)))
                || (matches!(kind, Some(BindingKind::Op { .. }))
                    && self.tables.resolved.builtin_ops.get(binding).is_some()
                    && Some(binding) != self.tables.resolved.stdlib("Benitoite.Failure.raise"))));
        let direct = ordinary
            && self.tables.schemes.get(binding).is_some_and(|scheme| {
                scheme.type_params.is_empty()
                    && scheme.effect_params.is_empty()
                    && scheme.class_constraints.is_empty()
            });
        Ok(direct.then_some(call))
    }

    fn range_check_arguments(&mut self, source: &'ast CallExpr) -> Result<bool, IdentityStop> {
        // rangeLength labels 3 は、空の末尾も一枠・一分類を持つ。
        let mut held = 0_u64;
        let result = (|| {
            let mut labels = source.args.iter();
            let mut remaining = 3_u32;
            loop {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                match (labels.next(), remaining) {
                    (None, 0) => break,
                    (None, _) | (Some(_), 0) => return Ok(false),
                    (Some(_), count) => remaining = count.saturating_sub(1),
                }
            }
            // rangeLength の再帰枠は戻ってから rangeThreeExprs へ進む。
            self.budget.release(Lifetime::Temporary, held);
            held = 0;
            // AST では三容器が同じ長さを持つ。各 rangeThree は一枠の中で
            // 先頭三項と末尾を別々に分類し、容器を作り直さない。
            for _ in 0..2 {
                self.frame()?;
                held = 1;
                for _ in 0..4 {
                    self.tick(Operation::Classification)?;
                }
                self.budget.release(Lifetime::Temporary, 1);
                held = 0;
            }
            let positions = [
                self.range_position(source, 0),
                self.range_position(source, 1),
                self.range_position(source, 2),
            ];
            Ok(matches!(
                positions,
                [Some(0), Some(1), Some(2)]
                    | [Some(0), Some(2), Some(1)]
                    | [Some(1), Some(0), Some(2)]
                    | [Some(1), Some(2), Some(0)]
                    | [Some(2), Some(0), Some(1)]
                    | [Some(2), Some(1), Some(0)]
            ))
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    // AST の三容器は同じ引数列を借りる。契約位置の並べ替えも固定個数だけで行う。
    fn range_argument(&self, source: &'ast CallExpr, position: usize) -> Option<&'ast Expr> {
        crate::typeck::consts::standard_argument(
            source,
            position,
            match position {
                0 => "minimum",
                1 => "maximum",
                2 => "value",
                _ => return None,
            },
        )
    }

    pub(super) fn range_position(&self, source: &CallExpr, index: usize) -> Option<usize> {
        let arg = source.args.get(index)?;
        if let Arg::Named(arg) = arg {
            let Expr::Name(name) = source.callee.as_ref() else {
                return None;
            };
            let binding = self.tables.resolved.refs.get(name.id)?;
            let scheme = self.tables.schemes.get(*binding)?;
            scheme
                .param_names
                .iter()
                .position(|name| *name == arg.name.text)
        } else {
            Some(index)
        }
    }

    fn range_value_argument(&mut self, source: &'ast CallExpr) -> Result<bool, IdentityStop> {
        let count = self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            if source.args.is_empty() {
                return Ok(false);
            }
            flow.range_frame(|flow| {
                flow.tick(Operation::Classification)?;
                Ok(source.args.len() == 1)
            })
        })?;
        if !count {
            return Ok(false);
        }
        let position = self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            if source.args.is_empty() {
                return Ok(false);
            }
            flow.tick(Operation::Classification)?;
            Ok(source.args.len() == 1 && flow.range_position(source, 0) == Some(0))
        })?;
        if position {
            self.range_frame(|flow| {
                flow.tick(Operation::Classification)?;
                if !source.args.is_empty() {
                    flow.tick(Operation::Classification)?;
                }
                Ok(())
            })?;
        }
        Ok(position)
    }

    /// rangeValueOrigin と同じ番号・所有元の成功値だけから正常区間を得る。
    pub(super) fn range_value_scan(
        &mut self,
        source: &'ast Expr,
        key: u64,
    ) -> Result<Option<Interval>, IdentityStop> {
        let binding = self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            let Some(call) = flow.standard_direct_call(source, key, false)? else {
                return Ok(None);
            };
            if !flow.range_value_argument(call)? {
                return Ok(None);
            }
            flow.tick(Operation::Classification)?;
            let Some(Expr::Name(name)) = crate::typeck::consts::standard_argument(call, 0, "value")
            else {
                return Ok(None);
            };
            let binding = flow.reference(name.id)?;
            if !matches!(
                flow.tables
                    .resolved
                    .bindings
                    .get(binding)
                    .map(|entry| &entry.kind),
                Some(BindingKind::Local(_))
            ) {
                return Ok(None);
            }
            let Some(index) = flow.range_standard_at(key)? else {
                return Ok(None);
            };
            let owner = flow
                .range_tables_at(key)
                .and_then(|tables| tables.standards.get(index))
                .and_then(|entry| entry.value());
            Ok(owner.map(|owner| (binding, owner)))
        })?;
        if let Some((binding, owner)) = binding {
            let fact = self
                .env
                .read_checked_range(binding, self.budget)
                .map_err(IdentityStop::AnalysisBudget)?;
            return Ok(fact
                .filter(|fact| fact.origin.names.owner == owner)
                .map(|fact| Interval::normalize(fact.origin.minimum, fact.origin.maximum)));
        }
        Ok(None)
    }

    /// rangeResultSource は括弧を剥がさず、直接の局所位置だけ別経路で読む。
    fn range_result_source(
        &mut self,
        source: &'ast Expr,
        key: u64,
    ) -> Result<Option<Origin>, IdentityStop> {
        if let Expr::Name(name) = source {
            let binding = self.reference(name.id)?;
            if matches!(
                self.tables
                    .resolved
                    .bindings
                    .get(binding)
                    .map(|entry| &entry.kind),
                Some(BindingKind::Local(_))
            ) {
                let fact = self
                    .env
                    .read_range(binding, self.budget)
                    .map_err(IdentityStop::AnalysisBudget)?;
                return Ok(fact
                    .filter(|fact| fact.success_id.is_none())
                    .map(|fact| fact.origin));
            }
        }
        self.range_origin(source, key)
    }

    fn range_names(&mut self, names: Names, key: u64) -> Result<bool, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            let mut index = 0_usize;
            loop {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::EnvironmentRead)?;
                let Some(entry) = self
                    .range_tables_at(key)
                    .and_then(|tables| tables.standards.get(index))
                else {
                    return Ok(false);
                };
                if let Some(found) = entry.check()
                    && found.result == names.result
                    && found.owner == names.owner
                    && found.error == names.error
                    && found.ok != found.err
                {
                    return Ok(found == names);
                }
                index = index.saturating_add(1);
            }
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn range_one<T>(&mut self, entries: &'ast [T]) -> Result<Option<&'ast T>, IdentityStop> {
        self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            let Some(first) = entries.first() else {
                return Ok(None);
            };
            flow.tick(Operation::Classification)?;
            Ok((entries.len() == 1).then_some(first))
        })
    }

    fn range_pattern(
        &mut self,
        names: Names,
        pattern: &'ast Pattern,
        ok_only: bool,
    ) -> Result<bool, IdentityStop> {
        self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            match pattern {
                Pattern::Wildcard(_) | Pattern::Var(_) => Ok(!ok_only),
                Pattern::Ctor(ctor) => {
                    let Some(child) = flow.range_one(&ctor.args)? else {
                        return Ok(false);
                    };
                    flow.tick(Operation::Classification)?;
                    let shape = matches!(child, Pattern::Var(_))
                        || (!ok_only && matches!(child, Pattern::Wildcard(_)));
                    let tag = flow.reference(ctor.id)?;
                    Ok(shape && (tag == names.ok || (!ok_only && tag == names.err)))
                }
                Pattern::Lit(_)
                | Pattern::Unit(_)
                | Pattern::Record(_)
                | Pattern::Range(_)
                | Pattern::List(_)
                | Pattern::Error(_) => Ok(false),
            }
        })
    }

    fn range_patterns(
        &mut self,
        names: Names,
        patterns: &'ast [Pattern],
    ) -> Result<bool, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for pattern in patterns.iter().map(Some).chain(std::iter::once(None)) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(pattern) = pattern
                    && !self.range_pattern(names, pattern, false)?
                {
                    return Ok(false);
                }
            }
            Ok(true)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn range_arms(&mut self, names: Names, arms: &'ast [MatchArm]) -> Result<bool, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for arm in arms.iter().map(Some).chain(std::iter::once(None)) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(arm) = arm
                    && !self.range_patterns(names, &arm.patterns)?
                {
                    return Ok(false);
                }
            }
            Ok(true)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    /// Result の認定と、認定後の一腕の入口準備を同じ借用入力から行う。
    /// selected がある呼び出しは rangeArm/readRangeArm の走査だけを行う。
    pub(super) fn range_match(
        &mut self,
        source: &'ast Expr,
        key: u64,
        arms: &'ast [MatchArm],
        selected: Option<&'ast MatchArm>,
    ) -> Result<Option<Origin>, IdentityStop> {
        if let Some(arm) = selected {
            return self.range_arm(source, key, arm);
        }
        let Some(origin) = self.range_result_source(source, key)? else {
            return Ok(None);
        };
        if !self.range_names(origin.names, key)? {
            return Ok(None);
        }
        Ok(self.range_arms(origin.names, arms)?.then_some(origin))
    }

    fn range_slot(pattern: &'ast Pattern) -> Option<&'ast VarPat> {
        match pattern {
            Pattern::Var(var) => Some(var),
            Pattern::Ctor(ctor) => match ctor.args.as_slice() {
                [Pattern::Var(var)] => Some(var),
                _ => None,
            },
            Pattern::Wildcard(_)
            | Pattern::Lit(_)
            | Pattern::Unit(_)
            | Pattern::Record(_)
            | Pattern::Range(_)
            | Pattern::List(_)
            | Pattern::Error(_) => None,
        }
    }

    fn range_arm(
        &mut self,
        source: &'ast Expr,
        key: u64,
        arm: &'ast MatchArm,
    ) -> Result<Option<Origin>, IdentityStop> {
        // rangeMatch が受理するパターンの通常位置は高々一つ。
        let parent = self.env.snapshot();
        let slot = arm.patterns.first().and_then(Self::range_slot);
        self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            if slot.is_some() {
                flow.range_frame(|flow| flow.tick(Operation::Classification))?;
            }
            Ok(())
        })?;
        self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            if let Some(var) = slot {
                flow.range_frame(|flow| flow.tick(Operation::Classification))?;
                let binding = flow
                    .tables
                    .resolved
                    .decls
                    .get(var.id)
                    .copied()
                    .or_else(|| flow.tables.resolved.refs.get(var.id).copied())
                    .ok_or(IdentityStop::Input(InputError::MissingBinding(var.id)))?;
                flow.env
                    .write(binding, Slot::Unknown, flow.budget)
                    .map_err(IdentityStop::AnalysisBudget)?;
            }
            Ok(())
        })?;
        let initial = self.env.snapshot();
        let Some(pattern) = self.range_one(&arm.patterns)? else {
            return Ok(None);
        };
        // readRangeArm の slots は、空でも一回、単一位置なら末尾まで二回読む。
        let known = self.range_frame(|flow| {
            flow.tick(Operation::Classification)?;
            if slot.is_none() {
                return Ok(false);
            }
            flow.tick(Operation::Classification)?;
            Ok(true)
        })?;
        if !known {
            return Ok(None);
        }
        self.env.select(parent);
        let found = self.range_result_source(source, key);
        self.env.select(initial);
        let Some(origin) = found? else {
            return Ok(None);
        };
        if !self.range_pattern(origin.names, pattern, true)? {
            return Ok(None);
        }
        self.env.save_range(origin, true, self.budget)?;
        Ok(Some(origin))
    }
}

#[cfg(test)]
#[path = "range/tables_tests.rs"]
mod tables_tests;
