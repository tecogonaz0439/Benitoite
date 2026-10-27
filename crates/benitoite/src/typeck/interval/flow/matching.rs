//! 整数だけの照合値と認定した Range の Result から、腕の環境と guard の真枝を作る
//! （設計書 02-05「区間解析のmatchとguard」）。

use super::*;

enum MatchKind {
    Integer(IntKind),
    RangeResult(u64),
}

impl<'ast> Flow<'_, 'ast, '_> {
    /// 正常な照合値の Range の認定を、整数の近似の判定より先に行う。
    #[inline(never)]
    pub(super) fn matching(
        &mut self,
        source: &'ast MatchExpr,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        let source_key = self.identity.next;
        let tested = self.expr(&source.scrutinee, fuel)?;
        if !tested.live {
            self.skip(SkipInput::Arms(&source.arms), fuel)?;
            return Ok(tested);
        }
        let kind = if self.scan_range_match(source, source_key)? {
            Some(MatchKind::RangeResult(source_key))
        } else {
            tested.match_kind().map(MatchKind::Integer)
        };
        let Some(kind) = kind else {
            self.skip(SkipInput::Arms(&source.arms), fuel)?;
            self.unsupported = true;
            let mut result = Approx::unknown();
            result.preceded_by(&tested);
            return Ok(result);
        };
        let mut result = self.match_arms(source, kind, &tested, fuel)?;
        result.preceded_by(&tested);
        Ok(result)
    }

    // 由来の大きい戻り値を、照合値へ再帰している各 matching の枠へ積まない。
    #[inline(never)]
    fn scan_range_match(
        &mut self,
        source: &'ast MatchExpr,
        key: u64,
    ) -> Result<bool, IdentityStop> {
        self.range_match(&source.scrutinee, key, &source.arms, None)
            .map(|origin| origin.is_some())
    }

    // Analysis.scope は環境を返さない。成功・停止とも入口後の一時項目を返す。
    fn match_scope<T>(
        &mut self,
        run: impl FnOnce(&mut Self) -> Result<T, IdentityStop>,
    ) -> Result<T, IdentityStop> {
        self.frame()?;
        let checkpoint = self.env.checkpoint();
        let result = run(self);
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    #[inline(never)]
    fn match_arms(
        &mut self,
        source: &'ast MatchExpr,
        kind: MatchKind,
        tested: &Approx,
        mut fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        // armList の連なりはループで下りるが、nil を含む各 scope を保持する。
        let mut held = 0_u64;
        let result = (|| {
            let mut joined = Approx::empty();
            for arm in &source.arms {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                let first = self.match_scope(|flow| {
                    let reachable = match kind {
                        MatchKind::Integer(kind) => {
                            flow.match_arm_env(&source.scrutinee, kind, tested, arm)?
                        }
                        MatchKind::RangeResult(key) => {
                            // 認定済みの Result でも実行時に選ばれる腕は推測しない。
                            // Error・全体パターンを含め、各腕を親の環境から解析する。
                            flow.range_match(&source.scrutinee, key, &source.arms, Some(arm))?;
                            true
                        }
                    };
                    if !reachable {
                        flow.skip(SkipInput::Optional(arm.guard.as_deref()), fuel)?;
                        flow.skip(SkipInput::Statements(&arm.body.stmts), fuel)?;
                        return Ok(Approx::empty());
                    }
                    if let Some(condition) = &arm.guard {
                        let guard = flow.expr(condition, fuel)?;
                        let mut positive = flow.branch(
                            condition,
                            guard.boolean,
                            true,
                            |flow| flow.block(&arm.body, fuel),
                            |flow| flow.skip(SkipInput::Statements(&arm.body.stmts), fuel),
                        )?;
                        positive.preceded_by(&guard);
                        Ok(positive)
                    } else {
                        flow.block(&arm.body, fuel)
                    }
                })?;
                joined.provenance = joined.provenance.combine(&first.provenance);
                joined.join(&first);
            }
            fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
            self.frame()?;
            held = held.saturating_add(1);
            self.tick(Operation::Classification)?;
            Ok(joined)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    #[inline(never)]
    fn match_arm_env(
        &mut self,
        source: &'ast Expr,
        kind: IntKind,
        tested: &Approx,
        arm: &'ast MatchArm,
    ) -> Result<bool, IdentityStop> {
        let base = self.env.snapshot();
        // 整数に照合できるパターンの束縛は、値そのものの一位置だけである。
        // 選択肢は名前解決済みの同じ番号を共有し、先頭の選択肢が共通位置を定める。
        let binding = match arm.patterns.first() {
            Some(Pattern::Var(var)) => Some(self.pattern_binding(var.id)?),
            _ => None,
        };
        self.match_count(binding.is_some())?;
        self.match_template(binding, kind)?;
        let template = self.env.snapshot();
        self.env.select(base);
        let mut pending = Vec::new();
        let mut held = 0_u64;
        let result = (|| {
            for pattern in &arm.patterns {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                self.env.select(base);
                let first = self.match_alternative(source, kind, tested, pattern, binding)?;
                pending.push(first.then(|| self.env.snapshot()));
            }
            // alternatives の末尾 [] も枠と分類を持つ。
            self.frame()?;
            held = held.saturating_add(1);
            self.tick(Operation::Classification)?;
            self.budget.release(Lifetime::Temporary, 1);
            held = held.saturating_sub(1);
            let mut tail = None;
            while let Some(first) = pending.pop() {
                tail = match (first, tail) {
                    (None, tail) => tail,
                    (first, None) => first,
                    (Some(left), Some(right)) => {
                        self.env
                            .join(template, left, right, self.budget)
                            .map_err(IdentityStop::AnalysisBudget)?;
                        Some(self.env.snapshot())
                    }
                };
                self.budget.release(Lifetime::Temporary, 1);
                held = held.saturating_sub(1);
            }
            self.env.select(tail.unwrap_or(base));
            Ok(tail.is_some())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn pattern_binding(&self, node: NodeId) -> Result<BindingId, IdentityStop> {
        self.tables
            .resolved
            .decls
            .get(node)
            .copied()
            .or_else(|| self.tables.resolved.refs.get(node).copied())
            .ok_or(IdentityStop::Input(InputError::MissingBinding(node)))
    }

    // countList alt.slots と replicateOnto の各再帰枠を、空の末尾まで数える。
    fn match_count(&mut self, one: bool) -> Result<(), IdentityStop> {
        self.frame()?;
        let result = (|| {
            self.tick(Operation::Classification)?;
            if one {
                self.match_count(false)?;
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    fn match_template(
        &mut self,
        binding: Option<BindingId>,
        kind: IntKind,
    ) -> Result<(), IdentityStop> {
        self.frame()?;
        let result = (|| {
            self.tick(Operation::Classification)?;
            if let Some(binding) = binding {
                self.match_template(None, kind)?;
                self.env
                    .write(
                        binding,
                        Slot::integer_kind(kind, Interval::top_kind(kind), Provenance::default()),
                        self.budget,
                    )
                    .map_err(IdentityStop::AnalysisBudget)?;
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    #[inline(never)]
    fn match_alternative(
        &mut self,
        source: &'ast Expr,
        kind: IntKind,
        tested: &Approx,
        pattern: &Pattern,
        binding: Option<BindingId>,
    ) -> Result<bool, IdentityStop> {
        self.frame()?;
        let result = (|| {
            self.tick(Operation::Classification)?;
            // 六幅のパターンは束縛・ワイルドカードだけで、型域は狭めない。
            let pattern_range = if kind == IntKind::Integer64 {
                self.integer_pattern_range(pattern)?
            } else {
                Interval::top_kind(kind)
            };
            let range = tested.range_kind(kind).meet(pattern_range);
            if range.is_bottom() {
                return Ok(false);
            }
            let provenance = tested.provenance.with_position(pattern.span());
            if let Some(local) = self.local_index(source)? {
                self.env
                    .narrow(
                        local,
                        Slot::integer_kind(kind, range, provenance.clone()),
                        self.budget,
                    )
                    .map_err(IdentityStop::AnalysisBudget)?;
            }
            let refined = self.env.snapshot();
            // patternSlotsScan は分類の一回を持つが、それ自身の frame は持たない。
            self.tick(Operation::Classification)?;
            if let Pattern::Var(var) = pattern {
                let binding = binding.ok_or(IdentityStop::Unmapped(var.id))?;
                self.env.clear_locals();
                self.env
                    .write(
                        binding,
                        Slot::integer_kind(kind, range, provenance),
                        self.budget,
                    )
                    .map_err(IdentityStop::AnalysisBudget)?;
                let raw = self.env.snapshot();
                self.match_select(raw, refined, binding, var.span)?;
            } else {
                // 非変数の整数パターンは patternBinders=0、replicateOnto=0。
                // 構造パターンは型検査成功済みの整数照合には現れない。
                self.match_count(false)?;
                self.match_template(None, kind)?;
                self.match_select_empty()?;
            }
            Ok(true)
        })();
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    fn match_select(
        &mut self,
        raw: super::super::environment::Snapshot,
        refined: super::super::environment::Snapshot,
        binding: BindingId,
        span: crate::base::Span,
    ) -> Result<(), IdentityStop> {
        self.frame()?;
        let result = (|| {
            self.tick(Operation::Classification)?;
            self.env.select(raw);
            let slot = self
                .env
                .read(binding, self.budget)
                .map_err(IdentityStop::AnalysisBudget)?;
            let slot = match slot {
                Some(Slot::Integer(range, provenance)) => {
                    Slot::Integer(range, provenance.with_position(span))
                }
                Some(Slot::IntegerKind(kind, range, provenance)) => {
                    Slot::IntegerKind(kind, range, provenance.with_position(span))
                }
                _ => return Err(IdentityStop::Unmapped(self.input.definition.source.node())),
            };
            self.env.select(refined);
            self.env
                .write(binding, slot, self.budget)
                .map_err(IdentityStop::AnalysisBudget)?;
            self.match_select_empty()
        })();
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    fn match_select_empty(&mut self) -> Result<(), IdentityStop> {
        self.frame()?;
        let result = self.tick(Operation::Classification);
        self.budget.release(Lifetime::Temporary, 1);
        result
    }

    fn integer_pattern_range(&self, pattern: &Pattern) -> Result<Interval, IdentityStop> {
        match pattern {
            Pattern::Lit(p) => match self.tables.literals.get(p.id) {
                Some(ConstValue::Integer(value)) => {
                    let value = i128::from(*value);
                    Ok(Interval::normalize(value, value))
                }
                _ => Ok(Interval::top()),
            },
            Pattern::Range(p) => match self.tables.range_bounds.get(p.id) {
                Some((ConstValue::Integer(lo), ConstValue::Integer(hi))) => {
                    Ok(Interval::normalize(i128::from(*lo), i128::from(*hi)))
                }
                _ => Ok(Interval::top()),
            },
            Pattern::Var(_) | Pattern::Wildcard(_) => Ok(Interval::top()),
            // 型検査済みで整数だけの照合に、構造の束縛数を推測して適用しない。
            Pattern::Unit(_)
            | Pattern::Ctor(_)
            | Pattern::Record(_)
            | Pattern::List(_)
            | Pattern::Error(_) => Err(IdentityStop::Unmapped(pattern.id())),
        }
    }
}
