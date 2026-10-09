//! リソースの表と状態（設計書 02-09「リソースの追跡」、ADR 0150・0266）。

use std::collections::{BTreeMap, BTreeSet, VecDeque};

use crate::builtins::iface::OsResource;
use crate::runtime::heap::ResourceId;
use crate::runtime::sched::ExtOpId;
use crate::runtime::{ResourceKind, Stop};
use crate::vm::{InstrRef, TaskId};

/// リソースの状態（ADR 0266 の決定 2）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ResourceState {
    Open,
    /// 作業用のスレッドに貸している。二つ目は閉じる要求があるか
    Lent(ExtOpId, bool),
    /// 解放を行っている
    Releasing(ExtOpId),
    Released,
}

/// リソースの中身。
#[derive(Debug)]
pub enum ResourceContent {
    /// OS の資源。貸している間と解放した後は `None`
    Os(Option<Box<dyn OsResource>>),
    /// `TaskGroup` が起動したタスク（所有しない番号。ADR 0266 の決定 10）
    TaskGroup(Vec<TaskId>),
}

/// リソースの表の項目。
#[derive(Debug)]
pub struct ResourceEntry {
    pub kind: ResourceKind,
    pub content: ResourceContent,
    pub state: ResourceState,
    /// リソースを開いた呼び出しの命令（解放の失敗の報告に使う）
    pub opened_at: Option<InstrRef>,
    /// 貸し出しを受けるために返却を待つタスク（呼んだ順。`WaitReason::Lend`）
    pub waiters: Vec<TaskId>,
    /// 解放の完了を待った側に渡す解放の失敗の理由（`finish_release` が入れ、`take_release_failure` が除く）
    pub release_failure: Option<String>,
}

/// リソースの表（実行ごとに一つ）。
#[derive(Debug, Default)]
pub struct ResourceTable {
    pub entries: BTreeMap<ResourceId, ResourceEntry>,
    /// 作業用のスレッドへまだ出していない、ブロックする解放の仕事（`Releasing` の項目の番号。始めた順）
    pub release_jobs: VecDeque<ResourceId>,
    // 下位 3 ビットは種類、残りは種類ごとの通し番号。FileReader の計数器は next。
    // 解放済みの種類を項目ごとに保存せず、発行した範囲だけを固定量で持つ（SECB6）。
    next: u64,
    other_next: [u64; 4],
    closed_before: [u64; 5],
    waiter_resources: BTreeMap<TaskId, BTreeSet<ResourceId>>,
    group_tasks: BTreeMap<TaskId, (ResourceId, usize)>,
    readiness_watches: BTreeSet<ResourceId>,
    closed_watches: BTreeSet<ResourceId>,
    /// リソースに添えた、言語の値を含まない Rust の値（受け付けた HTTP の要求など。実装プラン 10-16
    /// 「受け付けた要求の保存」）。リソースを解放するときに除く
    pub attachments: BTreeMap<ResourceId, Box<dyn std::any::Any + Send>>,
}

/// 貸し出しの結果。
#[derive(Debug)]
pub enum LendResult {
    Lent(Box<dyn OsResource>),
    /// 返るまで待つ
    MustWait,
    /// 解放したリソースの使用（実行時エラー）
    Released(ResourceKind),
}

/// 解放の要求の結果。
#[derive(Debug)]
pub enum ReleaseStart {
    /// 解放を終えた（失敗は理由）。`TaskGroup` はここに来ない
    Done(Result<(), String>),
    /// 作業用のスレッドで解放する（ブロックする解放）。OS の資源は項目に残し、番号を `release_jobs` に加えた
    Blocking,
    /// 返るまで待ち、返った後に解放する
    AfterReturn,
    /// 解放を行っている（`Releasing`）。完了を待つ
    InProgress,
    /// `TaskGroup`: 子のタスクの終わりを待つか取り消すかは呼び出し側（10-09 の解放の枠）が決める。
    /// 既に `Released` でも子の並びを返す（解放の枠が呼ばれるたびに子を評価し直すため）
    TaskGroup(Vec<TaskId>),
    /// 解放を終えてある（`Released`）
    AlreadyReleased,
}

impl ResourceTable {
    pub fn insert(
        &mut self,
        kind: ResourceKind,
        content: ResourceContent,
        opened_at: Option<InstrRef>,
    ) -> ResourceId {
        let tag = kind_tag(kind);
        let counter = if tag == 0 {
            &mut self.next
        } else if let Some(counter) = self.other_next.get_mut(tag.wrapping_sub(1)) {
            counter
        } else {
            debug_assert!(false, "invalid resource kind tag");
            return ResourceId(u64::MAX);
        };
        // 1 ns に一つでも 2^61 個には 70 年以上かかる。一実行で使い切らない
        // 前提は従来と同じであり、番号は解放や close_all_silently でも再使用しない。
        let id = ResourceId((*counter << 3) | u64::try_from(tag).unwrap_or(0));
        *counter = counter.wrapping_add(1);
        if let ResourceContent::TaskGroup(children) = &content {
            for (position, &task) in children.iter().enumerate() {
                self.group_tasks.insert(task, (id, position));
            }
        }
        self.entries.insert(
            id,
            ResourceEntry {
                kind,
                content,
                state: ResourceState::Open,
                opened_at,
                waiters: Vec::new(),
                release_failure: None,
            },
        );
        id
    }
    pub fn state(&self, id: ResourceId) -> Option<ResourceState> {
        self.entries
            .get(&id)
            .map(|entry| entry.state)
            .or_else(|| self.kind(id).map(|_| ResourceState::Released))
    }
    /// OS の資源を操作 `op` に貸す。`MustWait` なら `task` を返却を待つ並びの末尾に加える。
    pub fn lend(&mut self, id: ResourceId, op: ExtOpId, task: TaskId) -> LendResult {
        // 呼び出し側の check_lend を前提にする。失敗を表せない戻り値なので、不整合でも
        // 待ちを登録せず状態を保つ（実装プラン R24「凍結した戻り値で処理系の不具合を扱う方法」）。
        let valid = self.check_lend(id).is_ok();
        debug_assert!(valid, "check_lend must precede lend");
        if !valid {
            return LendResult::Released(
                self.entries
                    .get(&id)
                    .map_or(ResourceKind::FileReader, |e| e.kind),
            );
        }
        let Some(entry) = self.entries.get_mut(&id) else {
            return LendResult::Released(self.kind(id).unwrap_or(ResourceKind::FileReader));
        };
        match entry.state {
            ResourceState::Open => {
                if let ResourceContent::Os(handle) = &mut entry.content
                    && let Some(handle) = handle.take()
                {
                    entry.state = ResourceState::Lent(op, false);
                    return LendResult::Lent(handle);
                }
                debug_assert!(false, "checked OS resource missing");
                LendResult::Released(entry.kind)
            }
            ResourceState::Lent(_, _) => {
                entry.waiters.push(task);
                self.waiter_resources.entry(task).or_default().insert(id);
                LendResult::MustWait
            }
            ResourceState::Releasing(_) | ResourceState::Released => {
                LendResult::Released(entry.kind)
            }
        }
    }
    /// 返却を待つ並びから `task` を除く（取り消しと止める手順。すべての項目から除く）。
    pub fn remove_waiter(&mut self, task: TaskId) {
        if let Some(resources) = self.waiter_resources.remove(&task) {
            for id in resources {
                if let Some(entry) = self.entries.get_mut(&id) {
                    entry.waiters.retain(|waiter| *waiter != task);
                }
                self.prune_released(id);
            }
        }
    }
    /// 返却を待つ並びの先頭のタスクを除いて返す。
    pub fn pop_waiter(&mut self, id: ResourceId) -> Option<TaskId> {
        let entry = self.entries.get_mut(&id)?;
        if entry.waiters.is_empty() {
            return None;
        }
        let task = entry.waiters.remove(0);
        if !entry.waiters.contains(&task)
            && let Some(resources) = self.waiter_resources.get_mut(&task)
        {
            resources.remove(&id);
            if resources.is_empty() {
                self.waiter_resources.remove(&task);
            }
        }
        self.prune_released(id);
        Some(task)
    }
    /// 貸した資源を返す（完了の手順 1）。閉じる要求があれば `true` を返し、状態を `Open` に戻す。
    /// 呼び出し側は、ほかの処理を挟まずに `request_release` で解放を始める。
    pub fn give_back(&mut self, id: ResourceId, handle: Box<dyn OsResource>) -> bool {
        let Some(entry) = self.entries.get_mut(&id) else {
            // 実行終了後の返却は言語の解放を呼ばず、OS の資源だけ閉じる（ADR 0266 の決定 11）。
            drop(handle);
            return false;
        };
        if let (ResourceState::Lent(_, requested), ResourceContent::Os(place)) =
            (entry.state, &mut entry.content)
            && place.is_none()
        {
            *place = Some(handle);
            entry.state = ResourceState::Open;
            return requested;
        }
        // 完了の共通処理は一度だけ返却する。食い違いでも既存の資源を上書きしない（ADR 0266）。
        debug_assert!(false, "resource is not lent");
        drop(handle);
        false
    }
    /// 解放を要求する（`with` を抜けるとき、取り消し、止める手順、E-DropRel、返却の後の解放）。
    pub fn request_release(&mut self, id: ResourceId, op: ExtOpId) -> ReleaseStart {
        // check_release を先に通した呼び出しだけを受ける。不整合を解放の失敗と混同せず、
        // この到達しない分岐では表を変えない（実装プラン R24 のオーケストレータの決定）。
        let valid = self.check_release(id).is_ok();
        debug_assert!(valid, "check_release must precede request_release");
        if !valid {
            return ReleaseStart::AlreadyReleased;
        }
        let Some(entry) = self.entries.get_mut(&id) else {
            return if self.kind(id) == Some(ResourceKind::TaskGroup) {
                ReleaseStart::TaskGroup(Vec::new())
            } else {
                ReleaseStart::AlreadyReleased
            };
        };
        let result = match entry.state {
            ResourceState::Lent(op, _) => {
                entry.state = ResourceState::Lent(op, true);
                ReleaseStart::AfterReturn
            }
            ResourceState::Releasing(_) => ReleaseStart::InProgress,
            ResourceState::Released => match &entry.content {
                ResourceContent::TaskGroup(children) => ReleaseStart::TaskGroup(children.clone()),
                ResourceContent::Os(_) => ReleaseStart::AlreadyReleased,
            },
            ResourceState::Open => match &mut entry.content {
                ResourceContent::TaskGroup(children) => {
                    entry.state = ResourceState::Released;
                    self.attachments.remove(&id);
                    ReleaseStart::TaskGroup(children.clone())
                }
                ResourceContent::Os(handle) => {
                    if matches!(
                        entry.kind,
                        ResourceKind::FileWriter | ResourceKind::HttpExchange
                    ) {
                        if let Some(exchange) = handle.as_mut().and_then(|handle| {
                            handle.as_any_mut().downcast_mut::<super::http::Exchange>()
                        }) {
                            match exchange.prepare_release() {
                                Ok(socket) => {
                                    // 要求は解放の開始後に使えない。添え物を停止用の接続に替える。
                                    // Arc の共有なので OS の記述子は増えない（設計書 02-09「リソースの追跡」）。
                                    self.attachments.insert(id, Box::new(socket));
                                }
                                Err(error) => {
                                    *handle = None;
                                    entry.state = ResourceState::Released;
                                    self.attachments.remove(&id);
                                    let reason = error.to_string();
                                    self.record_closed_watch(id);
                                    return ReleaseStart::Done(Err(reason));
                                }
                            }
                        }
                        entry.state = ResourceState::Releasing(op);
                        self.release_jobs.push_back(id);
                        ReleaseStart::Blocking
                    } else if let Some(handle) = handle.take() {
                        entry.state = ResourceState::Released;
                        self.attachments.remove(&id);
                        let result = handle.release();
                        ReleaseStart::Done(result)
                    } else {
                        debug_assert!(false, "checked OS resource missing");
                        ReleaseStart::AlreadyReleased
                    }
                }
            },
        };
        if self.entries.get(&id).is_some_and(|entry| {
            matches!(
                entry.state,
                ResourceState::Releasing(_) | ResourceState::Released
            )
        }) {
            self.record_closed_watch(id);
        }
        // 即時の失敗の位置は報告側が取り出すまで残す。理由は Done で渡し、
        // release_failure には従来どおり finish_release だけが書く。
        if !matches!(result, ReleaseStart::Done(Err(_))) {
            self.prune_released(id);
        }
        result
    }
    /// 作業用のスレッドへまだ出していないブロックする解放の仕事を一つ取り出す。項目の OS の資源を取り出して返す。
    pub fn take_release_job(&mut self) -> Option<(ResourceId, ExtOpId, Box<dyn OsResource>)> {
        let id = loop {
            let id = *self.release_jobs.front()?;
            if self
                .entries
                .get(&id)
                .is_some_and(|entry| matches!(entry.state, ResourceState::Releasing(_)))
            {
                break id;
            }
            // 止める手順で閉じた Exchange の未開始の仕事は、取り出すときに捨てる。
            self.release_jobs.pop_front();
        };
        let entry = self.entries.get_mut(&id)?;
        let ResourceState::Releasing(op) = entry.state else {
            debug_assert!(false, "release job is not releasing");
            return None;
        };
        let ResourceContent::Os(handle) = &mut entry.content else {
            debug_assert!(false, "release job has no OS resource");
            return None;
        };
        let handle = handle.take()?;
        self.release_jobs.pop_front();
        Some((id, op, handle))
    }
    /// 解放の完了を記録し、状態を `Released` にする。失敗なら理由を `release_failure` に入れる。
    pub fn finish_release(&mut self, id: ResourceId, result: Result<(), String>) {
        self.attachments.remove(&id);
        self.record_closed_watch(id);
        if let Some(entry) = self.entries.get_mut(&id) {
            entry.state = ResourceState::Released;
            entry.release_failure = result.err();
        }
        self.prune_released(id);
    }
    /// 解放の完了を待った側が、記録した解放の失敗を一度だけ取り出す。
    pub fn take_release_failure(&mut self, id: ResourceId) -> Option<String> {
        let failure = self.entries.get_mut(&id)?.release_failure.take();
        self.prune_released(id);
        failure
    }
    /// 実行を終えるとき、表に残った OS の資源を閉じる（言語の解放ではない。失敗は報告しない）。
    pub fn close_all_silently(&mut self) {
        // 言語の release（書き出しなど）を呼ばない。実行終了後の返却も同じく破棄する
        // （設計書 02-09「リソースの追跡」、ADR 0266 の決定 11）。
        self.release_jobs.clear();
        self.entries.clear();
        self.attachments.clear();
        self.waiter_resources.clear();
        self.group_tasks.clear();
        self.readiness_watches.clear();
        self.closed_watches.clear();
        self.closed_before = self.counters();
    }

    /// 凍結した貸し出しの戻り値にない不具合を、呼ぶ側で先に報告する（実装プラン R24）。
    pub(crate) fn check_lend(&self, id: ResourceId) -> Result<(), Stop> {
        self.check_release(id)?;
        let Some(entry) = self.entries.get(&id) else {
            return Ok(());
        };
        if entry.kind == ResourceKind::TaskGroup && entry.state == ResourceState::Open {
            return Err(internal("TaskGroup cannot be lent as an OS resource"));
        }
        Ok(())
    }

    /// 解放前に番号と状態・種類・中身の不変条件を確かめる（実装プラン R24）。
    pub(crate) fn check_release(&self, id: ResourceId) -> Result<(), Stop> {
        let Some(entry) = self.entries.get(&id) else {
            return self
                .kind(id)
                .map(|_| ())
                .ok_or_else(|| internal("resource missing"));
        };
        let valid = match &entry.content {
            ResourceContent::TaskGroup(_) => {
                entry.kind == ResourceKind::TaskGroup
                    && matches!(entry.state, ResourceState::Open | ResourceState::Released)
            }
            ResourceContent::Os(handle) => {
                entry.kind != ResourceKind::TaskGroup
                    && match entry.state {
                        ResourceState::Open => handle.is_some(),
                        ResourceState::Lent(_, _) | ResourceState::Released => handle.is_none(),
                        ResourceState::Releasing(_) => matches!(
                            entry.kind,
                            ResourceKind::FileWriter | ResourceKind::HttpExchange
                        ),
                    }
            }
        };
        if valid {
            Ok(())
        } else {
            Err(internal("inconsistent resource entry"))
        }
    }
    pub(crate) fn watch_readiness(&mut self, id: ResourceId) {
        self.readiness_watches.insert(id);
    }
    pub(crate) fn unwatch_readiness(&mut self, id: ResourceId) {
        self.readiness_watches.remove(&id);
        self.closed_watches.remove(&id);
    }
    pub(crate) fn closed_readiness(&self) -> impl Iterator<Item = ResourceId> + '_ {
        self.closed_watches.iter().copied()
    }
    fn record_closed_watch(&mut self, id: ResourceId) {
        if self.readiness_watches.contains(&id) {
            self.closed_watches.insert(id);
        }
    }

    fn counters(&self) -> [u64; 5] {
        let mut counters = [0; 5];
        for (to, from) in counters
            .iter_mut()
            .zip(std::iter::once(&self.next).chain(&self.other_next))
        {
            *to = *from;
        }
        counters
    }

    /// 表から除いた項目の種類も、発行範囲と番号から得る。未発行と終了時の破棄は区別する。
    pub(crate) fn kind(&self, id: ResourceId) -> Option<ResourceKind> {
        if let Some(entry) = self.entries.get(&id) {
            return Some(entry.kind);
        }
        let tag = usize::try_from(id.0 & 7).ok()?;
        let serial = id.0 >> 3;
        let counters = self.counters();
        if serial < *self.closed_before.get(tag)? || serial >= *counters.get(tag)? {
            return None;
        }
        tag_kind(tag)
    }

    // 待ち・未報告の失敗・まだ動く子だけが、Released の項目を必要とする。
    fn prune_released(&mut self, id: ResourceId) {
        if self.entries.get(&id).is_some_and(|entry| {
            entry.state == ResourceState::Released
                && entry.waiters.is_empty()
                && entry.release_failure.is_none()
                && match &entry.content {
                    ResourceContent::Os(_) => true,
                    ResourceContent::TaskGroup(children) => children.is_empty(),
                }
        }) {
            self.entries.remove(&id);
        }
    }

    /// 子の番号と位置を同時に登録し、終了時に表全体を探さない。
    pub(crate) fn add_group_task(&mut self, group: ResourceId, task: TaskId) -> Result<(), Stop> {
        let entry = self
            .entries
            .get_mut(&group)
            .ok_or_else(|| internal("spawn group missing"))?;
        let ResourceContent::TaskGroup(children) = &mut entry.content else {
            return Err(internal("spawn group content mismatch"));
        };
        self.group_tasks.insert(task, (group, children.len()));
        children.push(task);
        Ok(())
    }

    /// 終わった子を、末尾の子と入れ替えて除く。子の実行・取り消しの順序は規定しない。
    pub(crate) fn finish_group_task(&mut self, task: TaskId) -> Result<Option<ResourceId>, Stop> {
        let Some((group, position)) = self.group_tasks.remove(&task) else {
            return Ok(None);
        };
        let entry = self
            .entries
            .get_mut(&group)
            .ok_or_else(|| internal("task group missing"))?;
        let ResourceContent::TaskGroup(children) = &mut entry.content else {
            return Err(internal("task group content mismatch"));
        };
        if children.get(position) != Some(&task) {
            return Err(internal("task group index mismatch"));
        }
        children.swap_remove(position);
        if let Some(&moved) = children.get(position) {
            self.group_tasks.insert(moved, (group, position));
        }
        self.prune_released(group);
        Ok(Some(group))
    }
}

fn kind_tag(kind: ResourceKind) -> usize {
    match kind {
        ResourceKind::FileReader => 0,
        ResourceKind::FileWriter => 1,
        ResourceKind::HttpListener => 2,
        ResourceKind::HttpExchange => 3,
        ResourceKind::TaskGroup => 4,
    }
}
fn tag_kind(tag: usize) -> Option<ResourceKind> {
    match tag {
        0 => Some(ResourceKind::FileReader),
        1 => Some(ResourceKind::FileWriter),
        2 => Some(ResourceKind::HttpListener),
        3 => Some(ResourceKind::HttpExchange),
        4 => Some(ResourceKind::TaskGroup),
        _ => None,
    }
}

fn internal(message: &str) -> Stop {
    Stop::Internal(message.to_owned())
}

#[cfg(test)]
mod tests;
