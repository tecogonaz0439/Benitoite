//! 局所解析が選んだ範囲と、型付けで確定した列の受理
//! （設計書 02-05「Scope の必須判定の入力」、01-12「Scope の必須の判定の受理と拒否の理由」）。

use super::*;
use crate::types::scope::{PathPattern, Range};

/// 規則の選択を診断のために分類した必須判定の結果。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScopeRequired {
    /// 静的に認定した範囲。Top は含めない。
    Known(Range),
    /// 由来を認定できなかった。
    Unknown,
    /// 最後の Run または番号付けが予算を超えた。
    Exceeded,
}

impl ScopeRequired {
    /// 型制約へ渡す添字。未知と予算の超過は Top となる。
    pub fn index(&self) -> Range {
        match self {
            Self::Known(range) => range.clone(),
            Self::Unknown | Self::Exceeded => Range::Top,
        }
    }

    fn of_index(range: Range, exceeded: bool) -> Self {
        match range {
            Range::Top if exceeded => Self::Exceeded,
            Range::Top => Self::Unknown,
            range @ (Range::Path(_) | Range::Host(_) | Range::Endpoint(_)) => Self::Known(range),
        }
    }
}

/// 一つの範囲の被覆を拒否した理由。効果原子の和の拒否は別の判定が担う。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeCoverFailure {
    /// 既知の範囲を契約が覆わない、または必要な位置が列にない。
    NotCovered,
    /// 未知の由来から非 Top の契約を得ようとした。
    UnknownSource,
    /// 予算の超過で Top を要求する位置に非 Top の契約を付けた。
    BudgetExceeded,
}

/// 最初に拒否した呼び出し。番号付けの停止後は途中の番号を診断にも流用しない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeRejection {
    /// 囲む定義名。
    pub definition: String,
    /// 完全な番号付けで得た先行順番号。番号付けが停止した本体では None。
    pub preorder: Option<u64>,
    /// 元ソースの呼び出し。
    pub node: NodeId,
    /// 被覆を拒否した理由。
    pub reason: ScopeCoverFailure,
}

/// 受理の失敗と、入力を完全に読めなかった停止を区別する。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScopeAcceptError {
    /// 型の列と規則の選ぶ範囲が適合しない。
    Rejected(ScopeRejection),
    /// 予算以外の入力の停止。規則なしとして受理してはならない。
    InputStopped(ScopeInputStop),
}

fn arg_index(argument: &ScopeArgument) -> Range {
    match argument {
        ScopeArgument::Local {
            id,
            fact: Some(ScopeFact::Checked { origin, success_id }),
        } if id == success_id => match &origin.bound {
            ScopeBound::Known(range) => range.clone(),
            ScopeBound::Unknown => Range::Top,
        },
        ScopeArgument::String(_)
        | ScopeArgument::Integer(_)
        | ScopeArgument::Local { .. }
        | ScopeArgument::Unknown => Range::Top,
    }
}

fn rule_index(declaration: ScopeDeclaration, arguments: &[ScopeArgument]) -> Range {
    match declaration {
        ScopeDeclaration::CheckPath => match arguments {
            [ScopeArgument::String(pattern), _] => PathPattern::parse(pattern)
                .ok()
                .map_or(Range::Top, Range::Path),
            _ => Range::Top,
        },
        ScopeDeclaration::CheckRequest => match arguments {
            [
                ScopeArgument::String(pattern),
                ScopeArgument::Integer(lo),
                ScopeArgument::Integer(hi),
                _,
            ] => crate::builtins::checked_scope::endpoint_pattern(pattern, *lo, *hi)
                .ok()
                .map_or(Range::Top, Range::Endpoint),
            _ => Range::Top,
        },
        ScopeDeclaration::PathValue
        | ScopeDeclaration::RequestValue
        | ScopeDeclaration::WidenPath
        | ScopeDeclaration::WidenRequest => match arguments {
            [argument] => arg_index(argument),
            _ => Range::Top,
        },
    }
}

impl ScopeAnalysis {
    /// 呼び出し位置の全ての記録で規則が選ぶ列。無記録の位置も analyze が factFree で読む。
    /// widen の行き先には規則が制約を置かないため、元の範囲の一要素だけを返す。
    pub fn required_ranges(
        &self,
        call: &ScopeCall,
    ) -> Result<Vec<Vec<ScopeRequired>>, ScopeInputStop> {
        if let Some(stop) = self.input.stopped {
            return match stop {
                ScopeInputStop::NumberingLimit { .. } => Ok(vec![vec![ScopeRequired::Exceeded]]),
                ScopeInputStop::BudgetExceeded { .. } => Err(stop),
                ScopeInputStop::Depth
                | ScopeInputStop::NumberOverflow
                | ScopeInputStop::MissingInput(_)
                | ScopeInputStop::PendingInterpolation(_) => Err(stop),
            };
        }
        if let Some(stop) = self.stopped
            && !matches!(stop, ScopeInputStop::BudgetExceeded { .. })
        {
            return Err(stop);
        }
        let exceeded = self.stopped.is_some();
        // PipeLeft は contractOrder が失敗して acceptCall … [] に入る形に対応する。
        if call
            .contract_to_source
            .iter()
            .any(|source| matches!(source, ScopeArgumentSource::PipeLeft(_)))
        {
            return Ok(vec![vec![ScopeRequired::of_index(Range::Top, exceeded)]]);
        }
        let required: Vec<_> = self
            .fact_indices
            .get(&call.preorder)
            .into_iter()
            .flatten()
            .filter_map(|index| self.calls.get(*index))
            .map(|facts| {
                vec![ScopeRequired::of_index(
                    rule_index(call.declaration, &facts.arguments),
                    exceeded,
                )]
            })
            .collect();
        if required.is_empty() {
            Err(ScopeInputStop::MissingInput(call.node))
        } else {
            Ok(required)
        }
    }

    /// 型制約の前に選ぶ範囲。全状態で同じ範囲を認定できたときだけ非 Top を選ぶ。
    pub fn selected_ranges(&self, call: &ScopeCall) -> Result<Vec<Range>, ScopeInputStop> {
        let required = self.required_ranges(call)?;
        let mut selected: Option<Range> = None;
        for state in required {
            let current = state.first().map_or(Range::Top, ScopeRequired::index);
            selected = Some(match selected {
                None => current,
                Some(previous) if previous == current => previous,
                Some(_) => Range::Top,
            });
        }
        Ok(vec![selected.unwrap_or(Range::Top)])
    }

    /// 確定した範囲の列を、呼び出し位置の全ての状態で確かめる。
    pub fn accept_call(&self, call: &ScopeCall, ranges: &[Range]) -> Result<(), ScopeAcceptError> {
        let required = self
            .required_ranges(call)
            .map_err(ScopeAcceptError::InputStopped)?;
        for state in required {
            for (position, requirement) in state.iter().enumerate() {
                let failure = match ranges.get(position) {
                    None => Some(ScopeCoverFailure::NotCovered),
                    Some(Range::Top) => None,
                    Some(contract) => match requirement {
                        ScopeRequired::Known(range) => {
                            (!contract.covers(range)).then_some(ScopeCoverFailure::NotCovered)
                        }
                        ScopeRequired::Unknown => Some(ScopeCoverFailure::UnknownSource),
                        ScopeRequired::Exceeded => Some(ScopeCoverFailure::BudgetExceeded),
                    },
                };
                if let Some(reason) = failure {
                    return Err(ScopeAcceptError::Rejected(ScopeRejection {
                        definition: self.input.body_key.definition.clone(),
                        preorder: self.input.stopped.is_none().then_some(call.preorder),
                        node: call.node,
                        reason,
                    }));
                }
            }
        }
        Ok(())
    }
}
