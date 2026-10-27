//! 操作数と保持項目数の本体・全体の予算
//! （設計書 02-05「区間解析の駆動と予算」）。

/// ホストの幅・容量によらない上限。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) struct Cap {
    pub operations: u64,
    pub items: u64,
}

#[derive(Clone, Copy, Debug)]
/// 一検査に使う本体・全体の上限。
pub(in crate::typeck) struct Limits {
    pub body: Cap,
    pub whole: Cap,
}

impl Default for Limits {
    fn default() -> Self {
        Self {
            body: Cap {
                operations: 100_000,
                items: 100_000,
            },
            whole: Cap {
                operations: 1_000_000,
                items: 1_000_000,
            },
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// 超過した資源。
pub(in crate::typeck) enum Resource {
    Operations,
    Items,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// 超過した上限の範囲。
pub(in crate::typeck) enum Scope {
    Body,
    Whole,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// 超過の原因。番号未取得にも同じ原因を付す。
pub(in crate::typeck) struct LimitFailure {
    pub scope: Scope,
    pub resource: Resource,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// 通常の解析停止と、番号付けの停止を区別する。
pub(in crate::typeck) enum StopReason {
    Exceeded(LimitFailure),
    Unidentified(LimitFailure),
}

impl StopReason {
    /// 番号付けを止めた原因として上限の範囲・資源を保つ。
    pub fn for_numbering(self) -> Self {
        match self {
            Self::Exceeded(f) | Self::Unidentified(f) => Self::Unidentified(f),
        }
    }
}

/// Lean の Budget.Operation と同じ計上単位。
#[derive(Clone, Copy, Debug)]
pub(in crate::typeck) enum Operation {
    Expression,
    EnvironmentRead,
    EnvironmentWrite,
    JoinItem,
    Numbering,
    Classification,
}

/// 同じ内容を二か所に保持すれば二項と数える。
#[derive(Clone, Copy, Debug)]
pub(in crate::typeck) enum Item {
    Environment,
    RecordField,
    Identity,
    Warning,
    Auxiliary,
    StackFrame,
}

#[derive(Clone, Copy, Debug)]
/// 本体終了時に返す保持と、後にも残す保持の区別。
pub(in crate::typeck) enum Lifetime {
    Temporary,
    Saved,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
/// 現在の本体の実消費と最大同時保持。
pub(in crate::typeck) struct BodyState {
    pub operations: u64,
    pub temporary: u64,
    pub saved: u64,
    pub peak: u64,
}

impl BodyState {
    /// 現本体の一時項目と保存項目の合計。
    pub fn held(self) -> u64 {
        self.temporary.saturating_add(self.saved)
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
/// 完了済み本体の保存項目と検査全体の実消費。
pub(in crate::typeck) struct WholeState {
    pub operations: u64,
    pub saved: u64,
    pub peak: u64,
}

/// Decls が検査ごとに一つ所有する。停止した計上は状態を変更しない。
#[derive(Debug, Default)]
pub(in crate::typeck) struct Budget {
    pub limits: Limits,
    pub body: BodyState,
    pub whole: WholeState,
}

impl Budget {
    /// 全体上限へ到達済みなら、次本体の枠を確保する前に止める。
    pub fn exhausted(&self) -> Option<StopReason> {
        let resource = if self.whole.operations >= self.limits.whole.operations {
            Some(Resource::Operations)
        } else if self.whole.saved.saturating_add(self.body.held()) >= self.limits.whole.items {
            Some(Resource::Items)
        } else {
            None
        };
        resource.map(|resource| {
            StopReason::Exceeded(LimitFailure {
                scope: Scope::Whole,
                resource,
            })
        })
    }

    fn admit(&self, resource: Resource, body: u64, whole: u64) -> Result<(), StopReason> {
        let (body_cap, whole_cap) = match resource {
            Resource::Operations => (self.limits.body.operations, self.limits.whole.operations),
            Resource::Items => (self.limits.body.items, self.limits.whole.items),
        };
        // Lean と同じく、同時に超過すれば本体の上限を先に報告する。
        let scope = if body > body_cap {
            Some(Scope::Body)
        } else if whole > whole_cap {
            Some(Scope::Whole)
        } else {
            None
        };
        match scope {
            Some(scope) => Err(StopReason::Exceeded(LimitFailure { scope, resource })),
            None => Ok(()),
        }
    }

    /// 実行する操作の直前に、本体・全体へ一回を計上する。
    pub fn charge(&mut self, _operation: Operation) -> Result<(), StopReason> {
        let body = self.body.operations.checked_add(1);
        let whole = self.whole.operations.checked_add(1);
        let (Some(body), Some(whole)) = (body, whole) else {
            return Err(StopReason::Exceeded(LimitFailure {
                scope: if body.is_none() {
                    Scope::Body
                } else {
                    Scope::Whole
                },
                resource: Resource::Operations,
            }));
        };
        self.admit(Resource::Operations, body, whole)?;
        self.body.operations = body;
        self.whole.operations = whole;
        Ok(())
    }

    /// 保存先の容量ではなく、追加する実在の一項を計上する。
    pub fn reserve(&mut self, _item: Item, lifetime: Lifetime) -> Result<(), StopReason> {
        let body = self.body.held().checked_add(1);
        let whole = body.and_then(|n| self.whole.saved.checked_add(n));
        let (Some(body), Some(whole)) = (body, whole) else {
            return Err(StopReason::Exceeded(LimitFailure {
                scope: if body.is_none() {
                    Scope::Body
                } else {
                    Scope::Whole
                },
                resource: Resource::Items,
            }));
        };
        self.admit(Resource::Items, body, whole)?;
        match lifetime {
            Lifetime::Temporary => self.body.temporary = self.body.temporary.saturating_add(1),
            Lifetime::Saved => self.body.saved = self.body.saved.saturating_add(1),
        }
        self.body.peak = self.body.peak.max(body);
        self.whole.peak = self.whole.peak.max(whole);
        Ok(())
    }

    /// 削除した項目を返す。過去の最大同時保持は変えない。
    pub fn release(&mut self, lifetime: Lifetime, count: u64) {
        let held = match lifetime {
            Lifetime::Temporary => &mut self.body.temporary,
            Lifetime::Saved => &mut self.body.saved,
        };
        debug_assert!(count <= *held);
        *held = held.saturating_sub(count);
    }

    /// 同じ項目を複製せず、一時領域から保存領域へ移す（Budget.save）。
    pub fn save_temporary(&mut self, count: u64) {
        debug_assert!(count <= self.body.temporary);
        self.body.temporary = self.body.temporary.saturating_sub(count);
        self.body.saved = self.body.saved.saturating_add(count);
    }

    /// 一時保持を閉じ、保存と全体の累積を次の本体へ引き継ぐ。
    pub fn finish_body(&mut self) -> BodyState {
        let body = std::mem::take(&mut self.body);
        self.whole.saved = self.whole.saved.saturating_add(body.saved);
        body
    }
}
