//! File の読み書きの本体と、VM の解放・取り消しを確かめる（設計書 03-07「File」、01-10、実装プラン L12）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::runtime_test_support::*;
use super::*;
use crate::builtins::iface::{CallCtx, Reply, StateWait, WaitRequest};
use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx};
use crate::runtime::io::resources::{LendResult, ResourceContent, ResourceTable};
use crate::runtime::io::services::{IoRuntime, IoView};
use crate::runtime::sched::testing::{ScheduleHandle, ScheduleStep};
use crate::runtime::sched::{ExtOpId, Scheduler};
use crate::vm::state::Stage1StateServices;
use crate::vm::{ExecMode, MainOutcome, StopEnd, StopReason, TaskId, Vm, VmConfig, VmStep};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::{Arc, Mutex};

fn io_call<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut IoRuntime,
    resources: &mut ResourceTable,
    decl: &BuiltinDecl,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let work = {
        let mut io = IoView { rt, resources };
        let mut call = CallCtx::new(ctx, Some(&mut io), None, None);
        let Reply::Wait(WaitRequest::Io(IoWait::Worker(work))) = (decl.raw)(&mut call, args)?
        else {
            panic!("expected worker")
        };
        work
    };
    let done = match work.lend() {
        Lend::Nothing => work.run(Lent::Nothing),
        Lend::Resource(id) => {
            let LendResult::Lent(mut handle) = resources.lend(
                id,
                ExtOpId(99),
                TaskId {
                    index: 0,
                    generation: 0,
                },
            ) else {
                panic!("not lent")
            };
            let done = work.run(Lent::Resource(handle.as_mut()));
            assert!(!resources.give_back(id, handle));
            done
        }
        Lend::Stdin => panic!("unexpected stdin"),
    };
    let mut io = IoView { rt, resources };
    done.complete(
        &mut CallCtx::new(ctx, Some(&mut io), None, None)
            .io_ctx()
            .unwrap(),
        args,
    )
}

fn close<'e>(
    ctx: &mut NoGcCtx<'e>,
    resources: &mut ResourceTable,
    scheduler: &mut Scheduler,
    id: ResourceId,
) -> StateReply<'e> {
    let mut state = Stage1StateServices {
        resources,
        scheduler,
    };
    close_writer(
        CallCtx::new(ctx, None, Some(&mut state), None)
            .state_ctx()
            .unwrap(),
        id,
    )
    .unwrap()
}

fn finish_close<'e>(
    ctx: &mut NoGcCtx<'e>,
    resources: &mut ResourceTable,
    scheduler: &mut Scheduler,
    id: ResourceId,
) -> Value<'e> {
    assert!(
        matches!(close(ctx, resources, scheduler, id), StateReply::Wait(StateWait::Resource(r)) if r == id)
    );
    let (resource, _, handle) = resources.take_release_job().unwrap();
    assert_eq!(resource, id);
    resources.finish_release(id, handle.release());
    let StateReply::Done(result) = close(ctx, resources, scheduler, id) else {
        panic!("close still waited")
    };
    result
}

// 関門: readChunk の引数の範囲、EOF、バイトの保存、readLine が先読みした後の位置を守る。
// Reader の既存のテストはバイトの読み取りも、巨大な maximumBytes も呼ばない。
#[test]
fn read_chunk_is_bounded_reports_eof_and_continues_the_buffered_reader() {
    let dir = TempDir::new();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let path = ctx.alloc_str("input", "test").unwrap();
        for (input, reads) in [
            (
                b"a\xffb".as_slice(),
                vec![
                    (1, Some(b"a".as_slice())),
                    (100, Some(b"\xffb".as_slice())),
                    (1, None),
                ],
            ),
            (b"".as_slice(), vec![(i64::MAX, None)]),
            (
                b"tiny".as_slice(),
                vec![(i64::MAX, Some(b"tiny".as_slice())), (1, None)],
            ),
        ] {
            std::fs::write(dir.0.join("input"), input).unwrap();
            let result =
                io_call(ctx, &mut rt, &mut resources, &open_reader::DECL, &[path]).unwrap();
            let reader = payload(ctx, result, tags::RESULT_OK);
            for (maximum, expected) in reads {
                let result = io_call(
                    ctx,
                    &mut rt,
                    &mut resources,
                    &read_chunk::DECL,
                    &[reader, Value::Int(maximum)],
                )
                .unwrap();
                let option = payload(ctx, result, tags::RESULT_OK);
                match expected {
                    Some(expected) => assert_eq!(
                        ctx.bytes(payload(ctx, option, tags::OPTION_SOME)),
                        Some(expected)
                    ),
                    None => assert!(matches!(option, Value::Tag(CtorTag(tags::OPTION_NONE)))),
                }
            }
            for maximum in [0, -1, i64::MIN] {
                assert_eq!(
                    io_call(
                        ctx,
                        &mut rt,
                        &mut resources,
                        &read_chunk::DECL,
                        &[reader, Value::Int(maximum)]
                    )
                    .unwrap_err(),
                    Stop::Runtime(crate::runtime::RuntimeError::ArgumentOutOfDomain {
                        function: "Benitoite.IO.File.readChunk",
                        argument: 1
                    })
                );
            }
        }
        std::fs::write(dir.0.join("input"), b"head\r\nabcdef\nlast").unwrap();
        let result = io_call(ctx, &mut rt, &mut resources, &open_reader::DECL, &[path]).unwrap();
        let reader = payload(ctx, result, tags::RESULT_OK);
        let result = io_call(ctx, &mut rt, &mut resources, &read_line::DECL, &[reader]).unwrap();
        assert_eq!(line(ctx, result).as_deref(), Some("head"));
        let result = io_call(
            ctx,
            &mut rt,
            &mut resources,
            &read_chunk::DECL,
            &[reader, Value::Int(3)],
        )
        .unwrap();
        assert_eq!(
            ctx.bytes(payload(
                ctx,
                payload(ctx, result, tags::RESULT_OK),
                tags::OPTION_SOME
            )),
            Some(b"abc".as_slice())
        );
        let result = io_call(ctx, &mut rt, &mut resources, &read_line::DECL, &[reader]).unwrap();
        assert_eq!(line(ctx, result).as_deref(), Some("def"));
        let result = io_call(
            ctx,
            &mut rt,
            &mut resources,
            &read_chunk::DECL,
            &[reader, Value::Int(100)],
        )
        .unwrap();
        assert_eq!(
            ctx.bytes(payload(
                ctx,
                payload(ctx, result, tags::RESULT_OK),
                tags::OPTION_SOME
            )),
            Some(b"last".as_slice())
        );
    });
}

// 関門: Replace と Append の作成・切り詰め・追記、三つの write の内容、close の書き出しと冪等性。
// パスへの書き込みのテストでは Writer のバッファとブロックする解放を通らない。
#[test]
fn writer_modes_and_all_writes_round_trip_through_close_and_read_text() {
    let dir = TempDir::new();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut scheduler = Scheduler::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let text = ctx.alloc_str("日本語\r", "test").unwrap();
        let bytes = ctx.alloc_bytes(b"chunk", "test").unwrap();
        for (name, initial, mode, prefix) in [
            ("replace-new", None, tags::FILE_WRITE_MODE_REPLACE, ""),
            (
                "replace-old",
                Some("old"),
                tags::FILE_WRITE_MODE_REPLACE,
                "",
            ),
            ("append-new", None, tags::FILE_WRITE_MODE_APPEND, ""),
            (
                "append-old",
                Some("old"),
                tags::FILE_WRITE_MODE_APPEND,
                "old",
            ),
        ] {
            if let Some(initial) = initial {
                std::fs::write(dir.0.join(name), initial).unwrap();
            }
            let path = ctx.alloc_str(name, "test").unwrap();
            let result = io_call(
                ctx,
                &mut rt,
                &mut resources,
                &open_writer::DECL,
                &[path, Value::Tag(CtorTag(mode))],
            )
            .unwrap();
            let writer = payload(ctx, result, tags::RESULT_OK);
            let id = writer.as_resource().unwrap();
            assert_eq!(resources.entries[&id].kind, ResourceKind::FileWriter);
            for (decl, data) in [
                (&write::DECL, text),
                (&write_line::DECL, text),
                (&write_chunk::DECL, bytes),
            ] {
                let result = io_call(ctx, &mut rt, &mut resources, decl, &[writer, data]).unwrap();
                assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
            }
            let result = finish_close(ctx, &mut resources, &mut scheduler, id);
            assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
            let StateReply::Done(result) = close(ctx, &mut resources, &mut scheduler, id) else {
                panic!("second close waited")
            };
            assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
            let result = io_call(ctx, &mut rt, &mut resources, &read_text::DECL, &[path]).unwrap();
            assert_eq!(
                ctx.str(payload(ctx, result, tags::RESULT_OK)).unwrap(),
                format!("{prefix}日本語\r日本語\r\nchunk")
            );
        }
        // writeChunk は UTF-8 の文字列に変えず、すべてのバイトを保存する（設計書 03-07「File」）。
        let path = ctx.alloc_str("binary", "test").unwrap();
        let result = io_call(
            ctx,
            &mut rt,
            &mut resources,
            &open_writer::DECL,
            &[path, Value::Tag(CtorTag(tags::FILE_WRITE_MODE_REPLACE))],
        )
        .unwrap();
        let writer = payload(ctx, result, tags::RESULT_OK);
        let bytes = ctx.alloc_bytes(b"\0\xff", "test").unwrap();
        let result = io_call(
            ctx,
            &mut rt,
            &mut resources,
            &write_chunk::DECL,
            &[writer, bytes],
        )
        .unwrap();
        assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
        let result = finish_close(
            ctx,
            &mut resources,
            &mut scheduler,
            writer.as_resource().unwrap(),
        );
        assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
        let result = io_call(ctx, &mut rt, &mut resources, &read_bytes::DECL, &[path]).unwrap();
        assert_eq!(
            ctx.bytes(payload(ctx, result, tags::RESULT_OK)),
            Some(b"\0\xff".as_slice())
        );
        for (name, kind) in [
            ("missing/file", tags::IO_ERROR_KIND_NOT_FOUND),
            (".", tags::IO_ERROR_KIND_IS_DIRECTORY),
        ] {
            let path = ctx.alloc_str(name, "test").unwrap();
            let result = io_call(
                ctx,
                &mut rt,
                &mut resources,
                &open_writer::DECL,
                &[path, Value::Tag(CtorTag(tags::FILE_WRITE_MODE_REPLACE))],
            )
            .unwrap();
            assert_eq!(error_kind(ctx, result), kind);
        }
    });
}

// 関門: 書き込みの OS の失敗は Result.Error に変える。解放の偽の失敗ではこの経路を通らない。
// 読み取り専用の実物の File を使い、OS ごとの特殊な出力先に依存しない。
#[test]
fn writes_return_io_errors_and_unreleased_buffers_are_discarded() {
    let dir = TempDir::new();
    std::fs::write(dir.0.join("readonly"), "original").unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let bytes = vec![b'x'; 20_000];
        let text = ctx
            .alloc_str(std::str::from_utf8(&bytes).unwrap(), "test")
            .unwrap();
        let data = ctx.alloc_bytes(&bytes, "test").unwrap();
        for (decl, data) in [
            (&write::DECL, text),
            (&write_line::DECL, text),
            (&write_chunk::DECL, data),
        ] {
            let id = resources.insert(
                ResourceKind::FileWriter,
                ResourceContent::Os(Some(Box::new(FileWriter(Some(BufWriter::new(
                    File::open(dir.0.join("readonly")).unwrap(),
                )))))),
                None,
            );
            let result = io_call(
                ctx,
                &mut rt,
                &mut resources,
                decl,
                &[Value::Resource(id), data],
            )
            .unwrap();
            let error = payload(ctx, result, tags::RESULT_ERROR);
            assert!(matches!(
                ctx.fields_header(error),
                Some((FieldsKind::IoError, _))
            ));
            assert!(!ctx.str(ctx.field(error, 0).unwrap()).unwrap().is_empty());
        }
        let path = ctx.alloc_str("unreleased", "test").unwrap();
        let result = io_call(
            ctx,
            &mut rt,
            &mut resources,
            &open_writer::DECL,
            &[path, Value::Tag(CtorTag(tags::FILE_WRITE_MODE_REPLACE))],
        )
        .unwrap();
        let writer = payload(ctx, result, tags::RESULT_OK);
        let text = ctx.alloc_str("buffered", "test").unwrap();
        let result = io_call(ctx, &mut rt, &mut resources, &write::DECL, &[writer, text]).unwrap();
        assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
        resources.close_all_silently();
        assert_eq!(std::fs::read(dir.0.join("unreleased")).unwrap(), b"");
        assert_eq!(std::fs::read(dir.0.join("readonly")).unwrap(), b"original");
    });
}

#[derive(Debug)]
struct FailRelease;
impl OsResource for FailRelease {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        Err("fake flush failure".into())
    }
}

// 関門: closeWriter が待ちの後の理由を Other と文字列で返す。StateServices だけの検査では
// IOError の値への変換を確かめられない（設計書 02-09「リソースの追跡」）。
#[test]
fn close_writer_returns_the_blocking_release_failure_as_ioerror() {
    let mut resources = ResourceTable::default();
    let mut scheduler = Scheduler::default();
    let id = resources.insert(
        ResourceKind::FileWriter,
        ResourceContent::Os(Some(Box::new(FailRelease))),
        None,
    );
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let result = finish_close(ctx, &mut resources, &mut scheduler, id);
        assert_eq!(error_kind(ctx, result), tags::IO_ERROR_KIND_OTHER);
        let error = payload(ctx, result, tags::RESULT_ERROR);
        assert_eq!(
            ctx.str(ctx.field(error, 0).unwrap()),
            Some("fake flush failure")
        );
        let StateReply::Done(result) = close(ctx, &mut resources, &mut scheduler, id) else {
            panic!("already released")
        };
        assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
    });
}

const IMPORTS: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Clock\n";
fn vm(program: &crate::bytecode::program::CompiledProgram) -> Vm<'_> {
    let mut vm = Vm::new(
        program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    vm
}

// 関門: 実物の Writer の書き出しを、with の正常終了と停止の後始末につなぐ。
// 単体テストで release を直接呼んでも解放の枠の接続の漏れは捕まえられない。
#[test]
fn with_flushes_writer_on_return_and_division_by_zero_in_both_io_modes() {
    let dir = TempDir::new();
    for stop in [false, true] {
        let body = if stop {
            "bind zero <- 0\n bind _ <- 1 div zero\n return Result.Ok(())"
        } else {
            "return Result.Ok(())"
        };
        let program = compile(&format!(
            r#"{IMPORTS}
function writeFile() -> Result[Unit,String] uses File.Write,State
 with w = try File.openWriter("output", File.WriteMode.Replace) |> Result.mapError(_,IOError.message) do
  bind _ <- try File.write(w,"buffered") |> Result.mapError(_,IOError.message)
  {body}
 end with
end function
function main() -> Result[Unit,String] uses File.Read,File.Write,State
 bind _ <- try writeFile()
 bind content <- try File.readText("output") |> Result.mapError(_,IOError.message)
 return if content = "buffered" then Result.Ok(()) else Result.Error("with did not flush") end if
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let script = ScheduleHandle::new([], false);
            let (mut rt, _) = runtime(&dir.0, mode, &script);
            permit_workers(&mut rt, &script);
            let end = finish(&mut vm(&program), &mut rt);
            if stop {
                assert!(
                    matches!(end, VmStep::Stopped(StopEnd {reason: StopReason::Error(ref info), ref release_failures, ..}) if info.stop == Stop::Runtime(crate::runtime::RuntimeError::DivisionByZero) && release_failures.is_empty()),
                    "{end:?}"
                );
            } else {
                assert_eq!(end, VmStep::Finished(MainOutcome::Ok));
            }
            assert_eq!(
                std::fs::read_to_string(dir.0.join("output")).unwrap(),
                "buffered"
            );
            consumed(&script);
        }
    }
}

// 関門: 解放済みの write は本体を呼ぶ前の貸し出し境界で止まる。単体テストでは届かない。
#[test]
fn writing_after_close_stops_with_released_resource_used() {
    let dir = TempDir::new();
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Result[Unit,String] uses File.Write,State
 with w = try File.openWriter("output",File.WriteMode.Replace) |> Result.mapError(_,IOError.message) do
  bind _ <- try File.closeWriter(w) |> Result.mapError(_,IOError.message)
  bind _ <- try File.closeWriter(w) |> Result.mapError(_,IOError.message)
  bind _ <- try File.write(w,"late") |> Result.mapError(_,IOError.message)
  return Result.Ok(())
 end with
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (mut rt, _) = runtime(&dir.0, mode, &script);
        let jobs = permit_workers(&mut rt, &script);
        let end = finish(&mut vm(&program), &mut rt);
        assert!(
            matches!(end, VmStep::Stopped(StopEnd {reason: StopReason::Error(ref info), ..}) if info.stop == Stop::Runtime(crate::runtime::RuntimeError::ReleasedResourceUsed {kind: ResourceKind::FileWriter})),
            "{end:?}"
        );
        assert!(jobs.borrow().is_empty());
        assert_eq!(std::fs::read(dir.0.join("output")).unwrap(), b"");
        consumed(&script);
    }
}

builtin! {
    /// 解放の失敗を実物の解放の枠へ渡す（実装プラン L12「解放の失敗」）。
    name = "Test.openFailingWriter",
    io fn open_failing_writer(ctx, path: &'c str, mode: Value<'e>) -> IoReply<'e> {
        let _ = (ctx, path, mode);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Nothing, |_| (), failing_writer_done))))
    }
}
fn failing_writer_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    _: (),
    _: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let site = ctx.site();
    let id =
        ctx.services()
            .register_resource(ResourceKind::FileWriter, Box::new(FailRelease), site);
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::Resource(id)])
}

// 関門: 明示の close の Error を扱った後の with は成功し、close しない with は ReleaseFailed。
// 外部の解放の失敗だけを差し替え、VM の待ちと解放の枠は本物を使う（01-10「解放の失敗」）。
#[test]
fn with_reports_release_failure_unless_close_has_already_returned_it() {
    let dir = TempDir::new();
    for close in [false, true] {
        let body = if close {
            r#"
 bind result <- File.closeWriter(w)
 return match result with
  case Result.Error(e) -> match IOError.kind(e) with
   case IOErrorKind.Other -> if IOError.message(e) = "fake flush failure" then Result.Ok(()) else Result.Error("reason") end if
   case _ -> Result.Error("kind")
  end match
  case _ -> Result.Error("close succeeded")
 end match
"#
        } else {
            "return Result.Ok(())"
        };
        let program = compile(&format!(
            r#"{IMPORTS}
function main() -> Result[Unit,String] uses File.Write,State
 with w = try File.openWriter("unused",File.WriteMode.Replace) |> Result.mapError(_,IOError.message) do
 {body}
 end with
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let script = ScheduleHandle::new([], false);
            let (mut rt, _) = runtime(&dir.0, mode, &script);
            permit_workers(&mut rt, &script);
            rt.builtin_overrides.insert(
                crate::builtins::lookup_builtin("Benitoite.IO.File.openWriter").unwrap(),
                &open_failing_writer::DECL,
            );
            let end = finish(&mut vm(&program), &mut rt);
            if close {
                assert_eq!(end, VmStep::Finished(MainOutcome::Ok));
            } else {
                let VmStep::Stopped(StopEnd {
                    reason: StopReason::Error(info),
                    ..
                }) = end
                else {
                    panic!("expected failed release")
                };
                let Stop::Runtime(crate::runtime::RuntimeError::ReleaseFailed(failures)) =
                    info.stop
                else {
                    panic!("wrong stop")
                };
                assert_eq!(failures.len(), 1);
                assert_eq!(failures[0].kind, ResourceKind::FileWriter);
                assert_eq!(failures[0].reason, "fake flush failure");
                assert!(failures[0].opened_at.is_some());
            }
            consumed(&script);
        }
    }
}

#[derive(Debug)]
struct CountRelease {
    inner: Box<dyn OsResource>,
    count: Arc<Mutex<usize>>,
}
impl OsResource for CountRelease {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self.inner.as_any_mut()
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        *self.count.lock().unwrap() += 1;
        self.inner.release()
    }
}

#[derive(Debug)]
struct ReleaseWorkers {
    inner: ScriptedWorkers,
    count: Arc<Mutex<usize>>,
    delayed: Rc<RefCell<bool>>,
}
impl crate::runtime::sched::parts::WorkerExec for ReleaseWorkers {
    fn wakeup(&self) -> Option<crate::runtime::io::event::Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, mut job: crate::runtime::io::ops::WorkerJob) {
        use crate::runtime::io::ops::JobWork;
        job.work = match job.work {
            JobWork::Release(inner) => JobWork::Release(Box::new(CountRelease {
                inner,
                count: Arc::clone(&self.count),
            })),
            JobWork::Builtin(work) => JobWork::Builtin(work),
        };
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<crate::runtime::io::ops::Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> crate::runtime::sched::parts::IdleWake {
        // 進められるタスクがなくなるまで write を保留する。勝者が終わって取り消しの
        // 後始末が返却を待つ位置で、初めて仕事を進める（設計書 02-09「リソースの追跡」、実装プラン L12）。
        if self.inner.hold_resources
            && !*self.delayed.borrow()
            && let Some(&op) = self.inner.resource_jobs.borrow().first()
        {
            assert_eq!(
                *self.count.lock().unwrap(),
                0,
                "released before the write returned"
            );
            *self.delayed.borrow_mut() = true;
            self.inner.script.allow_worker(op);
        }
        self.inner.idle(deadline)
    }
}
type ResourceJobs = Rc<RefCell<Vec<ExtOpId>>>;
type ReleaseCount = Arc<Mutex<usize>>;
type Delayed = Rc<RefCell<bool>>;

fn release_workers(
    rt: &mut IoRuntime,
    script: &ScheduleHandle,
    hold: bool,
) -> (ResourceJobs, ReleaseCount, Delayed) {
    let jobs = Rc::new(RefCell::new(Vec::new()));
    let count = Arc::new(Mutex::new(0));
    let delayed = Rc::new(RefCell::new(false));
    let inner = std::mem::replace(&mut rt.parts.workers, script.parts().workers);
    rt.parts.workers = Box::new(ReleaseWorkers {
        inner: ScriptedWorkers {
            inner,
            script: script.clone(),
            hold_resources: hold,
            resource_jobs: Rc::clone(&jobs),
            before_stdin: None,
        },
        count: Arc::clone(&count),
        delayed: Rc::clone(&delayed),
    });
    (jobs, count, delayed)
}

fn cancellation_program() -> crate::bytecode::program::CompiledProgram {
    compile(&format!(
        r#"{IMPORTS}
function main() -> Result[Unit,String] uses File.Write,State,Clock.Time,Console.Write
 bind continued <- Reference.new(false)
 bind winner <- Task.race([
  lambda()
   with w = try File.openWriter("output",File.WriteMode.Replace) do
    bind _ <- try File.write(w,"written after cancellation")
    Reference.set(continued,true)
    Console.write("continued")
    return Result.Ok(1)
   end with
  end lambda,
  lambda() return Result.Ok(2) end lambda])
 bind value <- match winner with
  case Option.Some(Result.Ok(n)) -> n
  case _ -> 0
 end match
 return if value = 2 and not Reference.get(continued) then Result.Ok(()) else Result.Error("cancelled writer continued") end if
end function
"#
    ))
}

// 関門: 貸した Writer を race で取り消し、返却してから一度だけ書き出す（設計書 02-09「リソースの追跡」）。
// ScriptedWorkers が write を保留し、勝者の後に返却を待つ位置で仕事を許す。
#[test]
fn cancelled_write_returns_writer_before_flushing_in_both_io_modes() {
    let dir = TempDir::new();
    let program = cancellation_program();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new(
            [
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2),
            ],
            false,
        );
        let (mut rt, output) = runtime(&dir.0, mode, &script);
        let (jobs, count, delayed) = release_workers(&mut rt, &script, true);
        let mut vm = vm(&program);
        assert_eq!(finish(&mut vm, &mut rt), VmStep::Finished(MainOutcome::Ok));
        assert!(*delayed.borrow());
        assert_eq!(jobs.borrow().len(), 1);
        assert_eq!(*count.lock().unwrap(), 1);
        assert_eq!(
            std::fs::read_to_string(dir.0.join("output")).unwrap(),
            "written after cancellation"
        );
        assert!(output.lock().unwrap().is_empty());
        assert!(rt.ops.records.is_empty());
        consumed(&script);
    }
}

// 関門: 要求の方式で外側に公開した write を、送り出す前に race が取り消す。
// 貸した後のテストでは、期限切れの要求が本体を呼ぶ退行を捕まえられない（設計書 02-09「IO 実行器」）。
#[test]
fn outstanding_write_cancelled_by_race_is_never_invoked_or_lent() {
    let dir = TempDir::new();
    let program = cancellation_program();
    let script = ScheduleHandle::new(
        [
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(2),
        ],
        false,
    );
    let (mut rt, output) = runtime(&dir.0, ExecMode::Request, &script);
    let (jobs, count, _) = release_workers(&mut rt, &script, false);
    let mut vm = vm(&program);
    let VmStep::Requests(open) = vm.run(&mut rt) else {
        panic!("open request missing")
    };
    assert_eq!(open.len(), 1);
    vm.serve_request(&mut rt, open[0]);
    let VmStep::Requests(write) = vm.run(&mut rt) else {
        panic!("write request missing")
    };
    assert_eq!(write.len(), 1);
    assert!(jobs.borrow().is_empty());
    assert_eq!(finish(&mut vm, &mut rt), VmStep::Finished(MainOutcome::Ok));
    vm.serve_request(&mut rt, write[0]);
    assert!(jobs.borrow().is_empty());
    assert_eq!(*count.lock().unwrap(), 1);
    assert_eq!(std::fs::read(dir.0.join("output")).unwrap(), b"");
    assert!(output.lock().unwrap().is_empty());
    assert!(rt.ops.records.is_empty());
    consumed(&script);
}
