//! 実行ごとの状態のうち VM が使うもの（設計書 02-08）。

use crate::runtime::Stop;
use crate::runtime::heap::{RootStack, Slot, Trace, Tracer};

use super::TaskId;
use super::unwind::{ReturnWork, UnwindWork};
use crate::runtime::io::resources::ResourceTable;
use crate::runtime::sched::Scheduler;

use super::budget::{Budget, StackMeter};
use super::frame::{CallFrame, Segment, TaskStack};
use super::{FrameRecord, InstrRef, StopInfo, StopReason, VmConfig, VmStep};

/// 実行ごとの状態のうち VM が使うもの。欄は R09（第 1 段）と R20〜R28（第 2 段）が決める。
pub struct RunState {
    pub(crate) stack: TaskStack,
    pub(crate) roots: RootStack,
    pub(crate) constants: Vec<Option<Slot>>,
    pub(crate) meter: StackMeter,
    pub(crate) budget: Budget,
    pub(crate) precall_done: Option<InstrRef>,
    pub(crate) stopping: Option<StopReason>,
    pub(crate) step: Option<VmStep>,
    pub(crate) started: bool,
    pub(crate) current_task: TaskId,
    pub(crate) inherited: Vec<Slot>,
    pub(crate) returning: Option<ReturnWork>,
    // R25 が TaskState::Unwinding へ移す。回収と待ちの間も根に残す（実装プラン R21）。
    pub(crate) unwinding: Option<UnwindWork>,
    // 第 2 段だけが使う大きい状態を窓・予算・計数から離す（設計書 07-02「性能の関門」）。
    pub(crate) scheduler: Box<Scheduler>,
    pub(crate) resources: Box<ResourceTable>,
    // 命令のない UPDATE の呼び直しでも、設定した初期予算へ戻す（設計書 02-08「タスクの切り替え」）。
    pub(crate) call_budget: u32,
    pub(crate) tasks: Box<super::task::TaskTable>,
    pub(crate) scheduling: Box<Scheduling>,
    // テストの実行だけが使う。`start_test` を呼ばない実行（`run`）では空のまま（実装プラン 10-18）。
    pub(crate) assert: Option<std::sync::Arc<crate::runtime::assert::AssertTable>>,
    // 最初のタスクの戻り値の型。`None` なら `CompiledProgram::main_kind` で読む（10-18「テストの関数の実行」）。
    pub(crate) main_kind: Option<crate::bytecode::program::MainKind>,
    // 確認の失敗の記録。失敗を見つけた時点で、枠を降ろす前に作る（10-18「`Assert.Check` の処理」）。
    pub(crate) check_failure: Option<Box<crate::runtime::assert::CheckFailure>>,
}

impl Trace for RunState {
    fn trace(&self, t: &mut Tracer<'_>) {
        self.tasks.trace(t);
        self.stack.trace(t);
        self.roots.trace(t);
        t.slots(&self.inherited);
        if let Some(work) = &self.returning {
            work.trace(t);
        }
        if let Some(work) = &self.unwinding {
            work.trace(t);
        }
        for value in self.constants.iter().flatten() {
            t.slot(value);
        }
    }
}

impl RunState {
    pub(crate) fn new(config: VmConfig, constant_count: usize) -> Self {
        Self {
            stack: TaskStack::default(),
            roots: RootStack::new(),
            constants: std::iter::repeat_with(|| None)
                .take(constant_count)
                .collect(),
            meter: StackMeter::new(config.max_call_stack_bytes),
            budget: Budget::new(config.call_budget),
            precall_done: None,
            stopping: None,
            step: None,
            started: false,
            current_task: TaskId {
                index: 0,
                generation: 0,
            },
            inherited: Vec::new(),
            returning: None,
            unwinding: None,
            scheduler: Box::default(),
            resources: Box::default(),
            call_budget: config.call_budget,
            tasks: Box::default(),
            scheduling: Box::default(),
            assert: None,
            main_kind: None,
            check_failure: None,
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(crate) fn segment(&self) -> Result<&Segment, Stop> {
        self.stack
            .segments
            .last()
            .ok_or_else(|| internal("no active segment"))
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(crate) fn segment_mut(&mut self) -> Result<&mut Segment, Stop> {
        self.stack
            .segments
            .last_mut()
            .ok_or_else(|| internal("no active segment"))
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(crate) fn frame(&self) -> Result<&CallFrame, Stop> {
        self.segment()?
            .calls
            .last()
            .ok_or_else(|| internal("no active call frame"))
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(crate) fn frame_mut(&mut self) -> Result<&mut CallFrame, Stop> {
        self.segment_mut()?
            .calls
            .last_mut()
            .ok_or_else(|| internal("no active call frame"))
    }

    pub(crate) fn stop_info(&self, stop: Stop, at: Option<InstrRef>) -> StopInfo {
        StopInfo {
            stop,
            // 枠を降ろす途中の停止は、既に降ろした呼び出しではなく戻りを始めた命令に付ける
            // （実装プラン R21「止まったときの記録」、設計書 02-08「実行時エラーの情報の記録」）。
            at: self.returning.as_ref().map_or(at, |work| Some(work.at)),
            frames: self
                .stack
                .segments
                .iter()
                .rev()
                .flat_map(|s| {
                    s.calls.iter().rev().map(|f| FrameRecord {
                        proto: f.proto,
                        call_site: f.call_site,
                    })
                })
                .collect(),
            spawns: self
                .scheduling
                .spawns
                .get(&self.current_task)
                .map_or_else(Vec::new, |s| s.history.clone()),
            deadlock: Vec::new(),
        }
    }

    pub(crate) fn fail(&mut self, stop: Stop, at: Option<InstrRef>) {
        // 後始末の途中でも最初の停止理由を保つ（設計書 02-08「止める手順」）。
        if self.stopping.is_none() {
            self.stopping = Some(StopReason::Error(self.stop_info(stop, at)));
        }
        self.precall_done = None;
    }
}

// 失敗の説明の確保は、枠を得る正常な経路へ展開しない（設計書 07-02「性能の関門」）。
#[cold]
#[inline(never)]
pub(crate) fn internal(message: &str) -> Stop {
    Stop::Internal(message.to_owned())
}

/// 切り替えのときだけ読む状態を窓と予算から離す（設計書 07-02「性能の関門」）。
#[derive(Default)]
pub(crate) struct Scheduling {
    pub(crate) boundary_at: Option<crate::runtime::io::WaitPoint>,
    pub(crate) switch: Option<Switch>,
    pub(crate) main: Option<TaskId>,
    pub(crate) outcome: Option<super::MainOutcome>,
    pub(crate) serial: u64,
    pub(crate) member_positions: std::collections::BTreeMap<TaskId, usize>,
    pub(crate) child_positions: std::collections::BTreeMap<TaskId, usize>,
    pub(crate) deliveries: std::collections::BTreeMap<TaskId, u16>,
    pub(crate) timed_out: std::collections::BTreeSet<TaskId>,
    pub(crate) spawns: std::collections::BTreeMap<TaskId, SpawnHistory>,
    pub(crate) stopping: bool,
    pub(crate) active: bool,
    // ブロックする偽の資源の完了を、待ちの境界で記録する補助（実装プラン R25「受け入れテスト」）。
    #[cfg(test)]
    pub(crate) test_boundary: Option<Box<TestBoundary>>,
    #[cfg(test)]
    pub(crate) test_parts: Option<crate::runtime::sched::parts::RuntimeParts>,
    pub(crate) failures: Vec<crate::runtime::ReleaseFailure>,
    // 停止の理由を置き換えず、後始末を進められなかった処理系の不具合を残す。
    pub(crate) stop_error: Option<Stop>,
    // IO に触る前の共通境界で取り消しを反映する（実装プラン R26）。
    pub(crate) cancelled_io: Vec<TaskId>,
    pub(crate) expire_io: bool,
}
pub(crate) struct SpawnHistory {
    pub(crate) serial: u64,
    pub(crate) history: Vec<super::SpawnRecord>,
}
#[derive(Clone, Copy)]
pub(crate) enum Switch {
    Yield,
    Park,
    Done,
}
// 一度の呼び出しだけ借り、実行中の窓とサービスの表を分ける（実装プラン R25）。
pub(crate) struct Stage1StateServices<'a> {
    pub(crate) resources: &'a mut ResourceTable,
    pub(crate) scheduler: &'a mut Scheduler,
}
impl crate::builtins::iface::StateServices for Stage1StateServices<'_> {
    fn resource_table(&mut self) -> Option<&mut ResourceTable> {
        Some(self.resources)
    }
    fn task_poll<'e>(
        &mut self,
        ctx: &crate::runtime::heap::NoGcCtx<'e>,
        task: crate::runtime::heap::Value<'e>,
    ) -> Result<crate::builtins::iface::TaskPoll<'e>, Stop> {
        use super::task::{TaskObj, TaskResult};
        use crate::builtins::iface::TaskPoll;
        let task = ctx
            .host::<TaskObj>(task)
            .ok_or_else(|| internal("Task.await requires a task"))?;
        match &task.result {
            TaskResult::Value(slot) => Ok(TaskPoll::Done(ctx.load(slot))),
            TaskResult::Pending => Ok(TaskPoll::Pending(task.id)),
            TaskResult::Cancelled => Err(Stop::Runtime(
                crate::runtime::RuntimeError::AwaitedTaskCancelled,
            )),
        }
    }
    fn open_task_group(&mut self, opened_at: Option<InstrRef>) -> crate::runtime::heap::ResourceId {
        self.resources.insert(
            crate::runtime::ResourceKind::TaskGroup,
            crate::runtime::io::resources::ResourceContent::TaskGroup(Vec::new()),
            opened_at,
        )
    }
    fn begin_release(
        &mut self,
        resource: crate::runtime::heap::ResourceId,
    ) -> Result<Option<crate::builtins::iface::StateWait>, Stop> {
        use crate::runtime::io::resources::ReleaseStart;
        self.resources.check_release(resource)?;
        let op = self.scheduler.new_ext_op_id();
        let kind = self
            .resources
            .kind(resource)
            .ok_or_else(|| internal("released resource missing"))?;
        let opened_at = self
            .resources
            .entries
            .get(&resource)
            .and_then(|entry| entry.opened_at);
        let result = match self.resources.request_release(resource, op) {
            ReleaseStart::Done(result) => result,
            ReleaseStart::AlreadyReleased => self
                .resources
                .take_release_failure(resource)
                .map_or(Ok(()), Err),
            ReleaseStart::Blocking | ReleaseStart::AfterReturn | ReleaseStart::InProgress => {
                return Ok(Some(crate::builtins::iface::StateWait::Resource(resource)));
            }
            ReleaseStart::TaskGroup(_) => {
                return Err(internal("TaskGroup cannot be closed as an OS resource"));
            }
        };
        if let Err(reason) = result {
            self.resources.take_release_failure(resource);
            if kind != crate::runtime::ResourceKind::HttpExchange {
                return Err(Stop::Runtime(crate::runtime::RuntimeError::ReleaseFailed(
                    vec![crate::runtime::ReleaseFailure {
                        kind,
                        opened_at,
                        reason,
                    }],
                )));
            }
        }
        Ok(None)
    }

    fn begin_close(
        &mut self,
        resource: crate::runtime::heap::ResourceId,
    ) -> Result<crate::builtins::iface::CloseStep, Stop> {
        use crate::builtins::iface::{CloseStep, StateWait};
        use crate::runtime::io::resources::ReleaseStart;
        self.resources.check_release(resource)?;
        let op = self.scheduler.new_ext_op_id();
        Ok(match self.resources.request_release(resource, op) {
            ReleaseStart::Done(result) => {
                self.resources.take_release_failure(resource);
                CloseStep::Done(result.err())
            }
            ReleaseStart::AlreadyReleased => {
                CloseStep::Done(self.resources.take_release_failure(resource))
            }
            ReleaseStart::Blocking | ReleaseStart::AfterReturn | ReleaseStart::InProgress => {
                CloseStep::Wait(StateWait::Resource(resource))
            }
            ReleaseStart::TaskGroup(_) => {
                return Err(internal("TaskGroup cannot be closed as an OS resource"));
            }
        })
    }
}

#[cfg(test)]
pub(crate) type TestBoundary =
    dyn for<'e> FnMut(&mut RunState, &mut crate::runtime::heap::NoGcCtx<'e>) -> Result<(), Stop>;

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used)]
    use super::*;
    use crate::builtins::iface::{IoServices, StateServices};
    use crate::runtime::io::services::{IoView, ProcessStdio, RunInput};

    #[derive(Debug)]
    struct ReleaseResult(Option<String>);
    impl crate::builtins::iface::OsResource for ReleaseResult {
        fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
            self
        }
        fn release(self: Box<Self>) -> Result<(), String> {
            self.0.map_or(Ok(()), Err)
        }
    }

    // 関門: close はすぐに終わる失敗と待った後の失敗を一度返し、後の解放を失敗させない。
    // 既存の begin_release のテストは失敗を Stop として扱うため、close の関数が解放の失敗を返す契約（設計書 02-09「リソースの追跡」）を確かめない。
    #[test]
    fn begin_close_returns_release_failure_once_for_immediate_and_blocking_resources() {
        use crate::builtins::iface::{CloseStep, StateWait};
        use crate::runtime::ResourceKind;
        use crate::runtime::io::resources::{ResourceContent, ResourceState};
        let mut resources = ResourceTable::default();
        let mut scheduler = Scheduler::default();
        for kind in [
            ResourceKind::FileReader,
            ResourceKind::FileWriter,
            ResourceKind::HttpExchange,
        ] {
            for reason in [None, Some("fake close failure".to_owned())] {
                let resource = resources.insert(
                    kind,
                    ResourceContent::Os(Some(Box::new(ReleaseResult(reason.clone())))),
                    None,
                );
                let result = Stage1StateServices {
                    resources: &mut resources,
                    scheduler: &mut scheduler,
                }
                .begin_close(resource)
                .unwrap();
                if kind == ResourceKind::FileReader {
                    assert_eq!(result, CloseStep::Done(reason.clone()));
                } else {
                    assert_eq!(result, CloseStep::Wait(StateWait::Resource(resource)));
                    assert_eq!(
                        Stage1StateServices {
                            resources: &mut resources,
                            scheduler: &mut scheduler
                        }
                        .begin_close(resource)
                        .unwrap(),
                        result
                    );
                    let (id, _, handle) = resources.take_release_job().unwrap();
                    assert_eq!(id, resource);
                    resources.finish_release(id, handle.release());
                    assert_eq!(
                        Stage1StateServices {
                            resources: &mut resources,
                            scheduler: &mut scheduler
                        }
                        .begin_close(resource)
                        .unwrap(),
                        CloseStep::Done(reason)
                    );
                }
                assert_eq!(resources.state(resource), Some(ResourceState::Released));
                let mut state = Stage1StateServices {
                    resources: &mut resources,
                    scheduler: &mut scheduler,
                };
                assert_eq!(state.begin_close(resource).unwrap(), CloseStep::Done(None));
                assert_eq!(state.begin_release(resource).unwrap(), None);
            }
        }
    }

    struct DefaultClose(Option<crate::builtins::iface::StateWait>);
    impl StateServices for DefaultClose {
        fn task_poll<'e>(
            &mut self,
            _: &crate::runtime::heap::NoGcCtx<'e>,
            _: crate::runtime::heap::Value<'e>,
        ) -> Result<crate::builtins::iface::TaskPoll<'e>, Stop> {
            Err(internal("unused task poll"))
        }
        fn open_task_group(&mut self, _: Option<InstrRef>) -> crate::runtime::heap::ResourceId {
            crate::runtime::heap::ResourceId(0)
        }
        fn begin_release(
            &mut self,
            _: crate::runtime::heap::ResourceId,
        ) -> Result<Option<crate::builtins::iface::StateWait>, Stop> {
            Ok(self.0.take())
        }
    }

    // 関門: 既存のサービスは begin_close を上書きしなくても、待ちと完了を引き継ぐ（10-16）。
    #[test]
    fn default_begin_close_maps_the_existing_release_reply() {
        use crate::builtins::iface::{CloseStep, StateWait};
        let resource = crate::runtime::heap::ResourceId(8);
        for wait in [None, Some(StateWait::Resource(resource))] {
            let mut state = DefaultClose(wait);
            assert_eq!(
                state.begin_close(resource).unwrap(),
                wait.map_or(CloseStep::Done(None), CloseStep::Wait)
            );
            assert_eq!(state.begin_close(resource).unwrap(), CloseStep::Done(None));
        }
    }

    #[test]
    fn u3_runtime_views_reborrow_the_vm_runtime_and_resources() {
        // 関門: 口を通した変更が VM の実際の状態に戻ることを確かめる。単に Some を返す
        // テストでは、別の表を返す誤りを捕まえられない（実装プラン L00「10-16 の口」）。
        let mut io = super::super::dispatch::test_support::TestIo::new(RunInput {
            arguments: Vec::new(),
            working_directory: ".".into(),
            script_directory: ".".into(),
        });
        assert_eq!(io.rt.process_stdio, ProcessStdio::default());
        let mut resources = ResourceTable::default();
        assert!(resources.attachments.is_empty());
        {
            let mut io_view = IoView {
                rt: &mut io.rt,
                resources: &mut resources,
            };
            let view = io_view.runtime_view().unwrap();
            view.rt.process_stdio.inherit_stdout = true;
            view.resources
                .attachments
                .insert(crate::runtime::heap::ResourceId(41), Box::new(123_u32));
        }
        assert!(io.rt.process_stdio.inherit_stdout);
        let mut scheduler = Scheduler::default();
        {
            let mut state = Stage1StateServices {
                resources: &mut resources,
                scheduler: &mut scheduler,
            };
            let table = state.resource_table().unwrap();
            assert_eq!(
                table
                    .attachments
                    .get(&crate::runtime::heap::ResourceId(41))
                    .unwrap()
                    .downcast_ref::<u32>(),
                Some(&123)
            );
            table.attachments.clear();
        }
        assert!(resources.attachments.is_empty());
    }
}
