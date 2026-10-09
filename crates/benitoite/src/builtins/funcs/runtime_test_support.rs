//! R29 の本体とプログラムを本番のランタイムにつなぐテストの準備（実装プラン R29）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

use super::super::table::tags;
use crate::builtins::iface::{IoReply, WorkerWait};
use crate::bytecode::program::CompiledProgram;
use crate::runtime::Stream;
use crate::runtime::heap::{FieldsKind, Value, ValueCtx};
use crate::runtime::io::output::OutputPort;
use crate::runtime::io::services::{IoRuntime, RunInput};
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::{ExecMode, Vm, VmStep};
use std::sync::{Arc, Mutex};

pub(super) fn worker(reply: IoReply<'_>) -> WorkerWait {
    let IoReply::Wait(crate::builtins::iface::IoWait::Worker(work)) = reply else {
        panic!("expected worker")
    };
    work
}
pub(super) fn payload<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, tag: u32) -> Value<'e> {
    assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, tag)));
    assert_eq!(ctx.fields_len(value), Some(1));
    ctx.field(value, 0).unwrap()
}
pub(super) fn line<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Option<String> {
    let value = payload(ctx, value, tags::RESULT_OK);
    if matches!(
        value,
        Value::Tag(crate::runtime::heap::CtorTag(tags::OPTION_NONE))
    ) {
        return None;
    }
    Some(
        ctx.str(payload(ctx, value, tags::OPTION_SOME))
            .unwrap()
            .to_owned(),
    )
}
pub(super) fn error_kind<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> u32 {
    let error = payload(ctx, value, tags::RESULT_ERROR);
    let Some((FieldsKind::IoError, kind)) = ctx.fields_header(error) else {
        panic!("expected IOError")
    };
    assert!(
        ctx.str(ctx.field(error, 0).unwrap())
            .is_some_and(|s| !s.is_empty())
    );
    kind
}

pub(super) struct TempDir(pub std::path::PathBuf);
impl TempDir {
    pub(super) fn new() -> Self {
        // create_dir の排他的な作成で並列のテストの衝突を防ぐ。大域の計数器は使わない。
        for serial in 0..10000 {
            let path =
                std::env::temp_dir().join(format!("benitoite-r29-{}-{serial}", std::process::id()));
            match std::fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(e) => panic!("temporary directory: {e}"),
            }
        }
        panic!("temporary directory names exhausted")
    }
}
impl Drop for TempDir {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

pub(super) fn runtime(
    directory: &std::path::Path,
    mode: ExecMode,
    script: &ScheduleHandle,
) -> (IoRuntime, Arc<Mutex<Vec<u8>>>) {
    let wakeup = script.wakeup();
    let captured = Arc::new(Mutex::new(Vec::new()));
    let outputs = (
        OutputPort::start(
            Stream::Stdout,
            Box::new(CaptureSink(Arc::clone(&captured))),
            false,
            wakeup.clone(),
        ),
        OutputPort::start(
            Stream::Stderr,
            Box::new(std::io::sink()),
            false,
            wakeup.clone(),
        ),
    );
    (
        IoRuntime::new(
            RunInput {
                arguments: vec![],
                working_directory: directory.to_owned(),
                script_directory: directory.to_owned(),
            },
            mode,
            outputs,
            Box::new(std::io::Cursor::new(Vec::<u8>::new())),
            script.parts(),
            Box::new(crate::runtime::run::NoInterrupt),
            wakeup,
        ),
        captured,
    )
}
pub(super) fn compile(source: &str) -> CompiledProgram {
    crate::pipeline::on_large_stack(|| {
        let checked = crate::pipeline::check_text(
            "r29.bnt",
            source.as_bytes(),
            crate::pipeline::CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = crate::pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        crate::pipeline::compile(&core, checked.sources).unwrap()
    })
    .unwrap()
}
pub(super) fn finish(vm: &mut Vm<'_>, rt: &mut IoRuntime) -> VmStep {
    for _ in 0..10000 {
        match vm.run(rt) {
            VmStep::Requests(ids) => {
                for id in ids {
                    vm.serve_request(rt, id);
                }
            }
            step @ (VmStep::Finished(_) | VmStep::Stopped(_)) => {
                rt.stdout.finish().unwrap();
                rt.stderr.finish().unwrap();
                return step;
            }
        }
    }
    panic!("VM did not finish")
}
pub(super) fn consumed(script: &ScheduleHandle) {
    let record = script.record();
    assert!(record.error.is_none(), "{record:?}");
    assert_eq!(record.remaining, 0, "{record:?}");
}

#[derive(Debug)]
pub(super) struct CaptureSink(pub Arc<Mutex<Vec<u8>>>);
impl std::io::Write for CaptureSink {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        self.0.lock().unwrap().extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

pub(super) const LINE_CASES: &[(&[u8], &[Option<&str>])] = &[
    (b"a\r\nb\n", &[Some("a"), Some("b"), None]),
    (b"a\n", &[Some("a"), None]),
    (b"a", &[Some("a"), None]),
    (b"a\r", &[Some("a"), None]),
    (b"\n\r\n\r\r", &[Some(""), Some(""), Some("\r"), None]),
    (b"", &[None]),
];

#[derive(Debug)]
pub(super) struct ScriptedWorkers {
    pub(super) inner: Box<dyn crate::runtime::sched::parts::WorkerExec>,
    pub(super) script: ScheduleHandle,
    pub(super) hold_resources: bool,
    pub(super) resource_jobs: std::rc::Rc<std::cell::RefCell<Vec<crate::runtime::sched::ExtOpId>>>,
    pub(super) before_stdin: Option<Arc<Mutex<Vec<u8>>>>,
}
impl crate::runtime::sched::parts::WorkerExec for ScriptedWorkers {
    fn wakeup(&self) -> Option<crate::runtime::io::event::Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: crate::runtime::io::ops::WorkerJob) {
        use crate::runtime::io::ops::LentOwned;
        if matches!(job.lent, LentOwned::Stdin(_))
            && let Some(output) = &self.before_stdin
        {
            assert_eq!(*output.lock().unwrap(), b"Name: ");
        }
        if matches!(job.lent, LentOwned::Resource(_, _)) {
            self.resource_jobs.borrow_mut().push(job.op);
            if !self.hold_resources {
                self.script.allow_worker(job.op);
            }
        } else {
            self.script.allow_worker(job.op);
        }
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<crate::runtime::io::ops::Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> crate::runtime::sched::parts::IdleWake {
        self.inner.idle(deadline)
    }
}
pub(super) fn permit_workers(
    rt: &mut IoRuntime,
    script: &ScheduleHandle,
) -> std::rc::Rc<std::cell::RefCell<Vec<crate::runtime::sched::ExtOpId>>> {
    let jobs = std::rc::Rc::new(std::cell::RefCell::new(Vec::new()));
    let inner = std::mem::replace(&mut rt.parts.workers, script.parts().workers);
    rt.parts.workers = Box::new(ScriptedWorkers {
        inner,
        script: script.clone(),
        hold_resources: false,
        resource_jobs: std::rc::Rc::clone(&jobs),
        before_stdin: None,
    });
    jobs
}
