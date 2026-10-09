//! 参照インタプリタのリソースの表とランタイムの口（設計書 01-10、02-09「リソースの追跡」）。
//! IoServices の登録だけを引き受け、解放は成功・失敗によらず一度だけ行う。
use crate::builtins::iface::{
    IoServices, IoWait, Lend, Lent, OsResource, StateServices, StateWait, TaskPoll, WorkerDone,
    WorkerWait,
};
use crate::runtime::heap::{NoGcCtx, ResourceId, Value};
use crate::runtime::{ReleaseFailure, ResourceKind, RuntimeError, Stop, Stream};
use crate::vm::InstrRef;
use std::cell::RefCell;
use std::ffi::OsString;
use std::path::Path;
use std::rc::Rc;

struct Entry {
    kind: ResourceKind,
    handle: Option<Box<dyn OsResource>>,
}
#[derive(Default)]
pub(super) struct Resources {
    entries: Vec<Entry>,
    fault: Option<Stop>,
    stdin: Option<std::io::BufReader<std::io::Stdin>>,
}
pub(super) type Shared = Rc<RefCell<Resources>>;
impl Resources {
    pub fn release(&mut self, id: ResourceId) -> Result<(), Stop> {
        let entry = self
            .entries
            .get_mut(usize::try_from(id.0).map_err(|_| fault())?)
            .ok_or_else(fault)?;
        if let Some(handle) = entry.handle.take()
            && let Err(reason) = handle.release()
            && entry.kind != ResourceKind::HttpExchange
        {
            return Err(Stop::Runtime(RuntimeError::ReleaseFailed(vec![
                ReleaseFailure {
                    kind: entry.kind,
                    opened_at: None,
                    reason,
                },
            ])));
        }
        Ok(())
    }
    pub fn worker(&mut self, wait: WorkerWait) -> Result<WorkerDone, Stop> {
        match wait.lend() {
            Lend::Nothing => Ok(wait.run(Lent::Nothing)),
            Lend::Resource(id) => {
                let entry = self
                    .entries
                    .get_mut(usize::try_from(id.0).map_err(|_| fault())?)
                    .ok_or_else(fault)?;
                let handle = entry.handle.as_deref_mut().ok_or(Stop::Runtime(
                    RuntimeError::ReleasedResourceUsed { kind: entry.kind },
                ))?;
                Ok(wait.run(Lent::Resource(handle)))
            }
            Lend::Stdin => {
                // 読み手を呼び出しごとに作ると先読みしたバイトを失う。実行中は同じ読み手を貸す
                // （実装プラン 10-11「応答と待つ理由」の Lend::Stdin）。
                let reader = self
                    .stdin
                    .get_or_insert_with(|| std::io::BufReader::new(std::io::stdin()));
                Ok(wait.run(Lent::Stdin(reader)))
            }
        }
    }
    pub fn take_fault(&mut self) -> Option<Stop> {
        self.fault.take()
    }
}
pub(super) fn fault() -> Stop {
    Stop::Internal("invalid reference resource table access".into())
}
pub(super) struct Io<'a> {
    pub base: &'a mut dyn IoServices,
    pub resources: Shared,
}
impl IoServices for Io<'_> {
    fn write_output(&mut self, s: Stream, t: &str) -> Result<Option<IoWait>, Stop> {
        self.base.write_output(s, t)
    }
    fn arguments(&self) -> &[String] {
        self.base.arguments()
    }
    fn script_directory(&self) -> &Path {
        self.base.script_directory()
    }
    fn working_directory(&self) -> &Path {
        self.base.working_directory()
    }
    fn environment_variable(&self, n: &str) -> Option<OsString> {
        self.base.environment_variable(n)
    }
    fn now_millis(&self) -> i64 {
        self.base.now_millis()
    }
    fn local_offset_minutes(&self) -> i32 {
        self.base.local_offset_minutes()
    }
    fn monotonic_millis(&self) -> i64 {
        self.base.monotonic_millis()
    }
    fn random_u64(&mut self) -> u64 {
        self.base.random_u64()
    }
    fn register_resource(
        &mut self,
        kind: ResourceKind,
        handle: Box<dyn OsResource>,
        _at: Option<InstrRef>,
    ) -> ResourceId {
        let Ok(mut table) = self.resources.try_borrow_mut() else {
            return ResourceId(u64::MAX);
        };
        let Ok(id) = u64::try_from(table.entries.len()) else {
            table.fault = Some(fault());
            return ResourceId(u64::MAX);
        };
        table.entries.push(Entry {
            kind,
            handle: Some(handle),
        });
        ResourceId(id)
    }
}
pub(super) struct State {
    pub resources: Shared,
}
impl StateServices for State {
    fn task_poll<'e>(
        &mut self,
        _ctx: &NoGcCtx<'e>,
        _task: Value<'e>,
    ) -> Result<TaskPoll<'e>, Stop> {
        Err(Stop::Internal(
            "reference interpreter cannot poll tasks".into(),
        ))
    }
    fn open_task_group(&mut self, _at: Option<InstrRef>) -> ResourceId {
        // この口は失敗を返せない。呼ばれた記録を呼び出しの境目で Stop::Internal にする（F14「解放」）。
        if let Ok(mut table) = self.resources.try_borrow_mut() {
            table.fault = Some(Stop::Internal(
                "reference interpreter cannot open task groups".into(),
            ));
        }
        ResourceId(u64::MAX)
    }
    fn begin_release(&mut self, id: ResourceId) -> Result<Option<StateWait>, Stop> {
        self.resources
            .try_borrow_mut()
            .map_err(|_| fault())?
            .release(id)?;
        Ok(None)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reference_and_stage1_services_do_not_expose_vm_runtime_views() {
        // 関門: VM 専用の口を、異なる表現のリソースを持つ実装が公開しない契約を守る
        // （実装プラン L00「10-16 の口」）。差し込みのための本番の口は加えない。
        let input = crate::runtime::io::services::RunInput {
            arguments: Vec::new(),
            working_directory: ".".into(),
            script_directory: ".".into(),
        };
        let mut stage1 = crate::builtins::funcs::stage1_io::TestIo::new(input);
        assert!(stage1.runtime_view().is_none());
        let resources = Rc::new(RefCell::new(Resources::default()));
        let mut io = Io {
            base: &mut stage1,
            resources: Rc::clone(&resources),
        };
        assert!(io.runtime_view().is_none());
        let mut state = State { resources };
        assert!(state.resource_table().is_none());
    }
}
