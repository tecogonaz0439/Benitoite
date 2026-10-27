//! シフトの直接引数の認定・契約位置の選択と固定域の候補。
//! Lean の BudgetDomainScan・BudgetSelect の順序と停止時の保持を保つ
//! （設計書 01-12「区間解析の予算付きの式とフロー」）。

use super::super::fixed_domain::{Contract, Entry};
use super::*;

impl<'ast> Flow<'_, 'ast, '_> {
    /// domainEntry の参照、型列・ラベル・置換・引数容器の順で計上する。
    pub(super) fn domain_call_shape(
        &mut self,
        call: &CallExpr,
        contract: &Contract,
    ) -> Result<bool, IdentityStop> {
        let mut held = 0_u64;
        let target = (|| {
            for index in 0..=contract.argument {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::EnvironmentRead)?;
                let Some(ty) = contract.argument_types.get(index) else {
                    return Ok(false);
                };
                if index == contract.argument {
                    return Ok(*ty == B::INTEGER);
                }
            }
            Ok(false)
        })();
        self.budget.release(Lifetime::Temporary, held);
        if !target? {
            return Ok(false);
        }
        let count = contract.argument_types.len();
        self.domain_length(count)?;
        // rangeLength は長さが違えば、その場で返す。
        let mut held = 0_u64;
        let labels = (|| {
            for index in 0..=call.args.len().min(count) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if index == call.args.len() || index == count {
                    return Ok(call.args.len() == count);
                }
            }
            Ok(false)
        })();
        self.budget.release(Lifetime::Temporary, held);
        if !labels? || !self.domain_permutation(call)? {
            return Ok(false);
        }
        self.domain_length(call.args.len())?; // domainExprsLength
        self.domain_length(call.args.len())?; // countList positions
        Ok(true)
    }

    /// countList / domainExprsLength は末尾も一枠・一分類とする。
    fn domain_length(&mut self, count: usize) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for _ in 0..=count {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    /// 二引数の固定列を使い、Lean が作る基準列と削除の接頭辞だけを計上する。
    /// 置換用の auxiliary は region を出るまで保持し、停止時にも返す。
    fn domain_permutation(&mut self, call: &CallExpr) -> Result<bool, IdentityStop> {
        let temporary = self.budget.body.temporary;
        let result = (|| {
            let mut frames = 0_u64;
            for index in 0..=2 {
                self.frame()?;
                frames = frames.saturating_add(1);
                self.tick(Operation::Classification)?;
                if index < 2 {
                    self.budget
                        .reserve(Item::Auxiliary, Lifetime::Temporary)
                        .map_err(IdentityStop::AnalysisBudget)?;
                }
            }
            self.budget.release(Lifetime::Temporary, frames);
            let mut expected = [0, 1];
            let mut count = 2_usize;
            // domainIsPerm の再帰枠は、所属と削除の後も末尾まで保持する。
            for index in 0..=call.args.len() {
                self.frame()?;
                self.tick(Operation::Classification)?;
                if index == call.args.len() {
                    return Ok(count == 0);
                }
                let Some(position) = self.range_position(call, index) else {
                    return Ok(false);
                };
                let mut found = None;
                let mut held = 0_u64;
                for (offset, value) in expected.iter().take(count).enumerate() {
                    self.frame()?;
                    held = held.saturating_add(1);
                    self.tick(Operation::Classification)?;
                    if *value == position {
                        found = Some(offset);
                        break;
                    }
                }
                if found.is_none() {
                    self.frame()?; // domainContains の空の末尾
                    held = held.saturating_add(1);
                    self.tick(Operation::Classification)?;
                }
                self.budget.release(Lifetime::Temporary, held);
                let Some(offset) = found else {
                    return Ok(false);
                };
                let mut held = 0_u64;
                for prefix in 0..=offset {
                    self.frame()?;
                    held = held.saturating_add(1);
                    self.tick(Operation::Classification)?;
                    if prefix < offset {
                        self.budget
                            .reserve(Item::Auxiliary, Lifetime::Temporary)
                            .map_err(IdentityStop::AnalysisBudget)?;
                    }
                }
                self.budget.release(Lifetime::Temporary, held);
                // count は初期値2から減るだけで、found は take(count) の位置なので
                // offset < count ≤ expected.len()。移動元の末尾と移動先は列内に収まる
                // （設計書 02-05「区間解析の内部入力」）。
                expected.copy_within(offset.saturating_add(1)..count, offset);
                count = count.saturating_sub(1);
            }
            Ok(false)
        })();
        self.budget.release(
            Lifetime::Temporary,
            self.budget.body.temporary.saturating_sub(temporary),
        );
        result
    }

    #[inline(never)]
    pub(super) fn shift_called(
        &mut self,
        source: &'ast Expr,
        fuel: u32,
        entry: Entry,
    ) -> Result<Approx, IdentityStop> {
        let Expr::Call(call) = source else {
            return Err(IdentityStop::Unmapped(source.id()));
        };
        self.skip(SkipInput::Expr(Node::Expr(&call.callee)), fuel)?;
        let selected = self.select_arguments(call, fuel, entry.contract.argument)?;
        let outside = selected
            .normal
            .bounds()
            .is_some_and(|(lo, hi)| hi < entry.contract.minimum || entry.contract.maximum < lo);
        if outside {
            let argument = crate::typeck::consts::standard_argument(
                call,
                entry.contract.argument,
                entry
                    .contract
                    .parameters
                    .get(entry.contract.argument)
                    .copied()
                    .ok_or(IdentityStop::Unmapped(call.id))?,
            )
            .ok_or(IdentityStop::Unmapped(call.id))?;
            self.save_candidate(
                (
                    call.id,
                    argument.span(),
                    TargetOperation::Standard {
                        declaration: entry.declaration,
                        contract: entry.contract,
                    },
                ),
                IntKind::Integer64,
                Cause::OutsideDomain,
                &selected,
                &Approx::integer(Interval::normalize(
                    entry.contract.minimum,
                    entry.contract.maximum,
                )),
            )?;
        }
        if !selected.live {
            return Ok(selected);
        }
        let mut output = if outside {
            Approx::empty()
        } else {
            Approx::unknown()
        };
        output.unsupported = false;
        output.may_fail = true;
        output.preceded_by(&selected);
        Ok(output)
    }

    /// 全引数をソース順に解析し、契約位置の正常値だけを保持する。
    /// selectArguments の再帰では fuel を減らさず、各 run/skip は同じ fuel を使う。
    #[inline(never)]
    fn select_arguments(
        &mut self,
        call: &'ast CallExpr,
        fuel: u32,
        target: usize,
    ) -> Result<Approx, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            let mut selected = Approx::unit();
            let mut previous = Approx::unit();
            for index in 0..=call.args.len() {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                let Some(arg) = call.args.get(index) else {
                    selected.preceded_by(&previous);
                    return Ok(selected);
                };
                let source = arg.expr().ok_or(IdentityStop::Unmapped(call.id))?;
                let mut value = self.expr(source, fuel)?;
                value.preceded_by(&previous);
                if !value.live {
                    self.skip(
                        SkipInput::Arguments(
                            call.args
                                .get(index.saturating_add(1)..)
                                .ok_or(IdentityStop::Unmapped(call.id))?,
                        ),
                        fuel,
                    )?;
                    return Ok(value);
                }
                previous = Approx::unit();
                previous.preceded_by(&value);
                if self.range_position(call, index) == Some(target) {
                    selected = value;
                }
            }
            Ok(selected)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }
}
