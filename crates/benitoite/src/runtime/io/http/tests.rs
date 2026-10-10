//! HTTP の応答と準備の待ち、資源不足の再試行（実装プラン L30、設計書 03-09「サーバ」「失敗の種類」）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::*;

#[test]
fn response_replaces_framing_headers_and_uses_known_reason_phrases() {
    let bytes = response_bytes(
        200,
        &[
            ("Content-Length".into(), "999".into()),
            ("CONNECTION".into(), "keep-alive".into()),
            ("X".into(), "a".into()),
        ],
        b"abc",
    )
    .unwrap();
    assert_eq!(
        bytes,
        b"HTTP/1.1 200 OK\r\nX: a\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc"
    );
    assert!(
        response_bytes(599, &[], &[])
            .unwrap()
            .starts_with(b"HTTP/1.1 599 \r\n")
    );
}

use crate::builtins::iface::{IoReply, builtin};
use crate::runtime::Stream;
use crate::runtime::heap::{FieldsKind, HeapConfig, Value};
use crate::runtime::io::ops::{Completion, WorkerJob};
use crate::runtime::io::output::OutputPort;
use crate::runtime::io::services::{IoRuntime, RunInput};
use crate::runtime::sched::parts::{IdleWake, WorkerExec};
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::{ExecMode, MainOutcome, Vm, VmConfig, VmStep};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::{Arc, Mutex};

builtin! {
    name = "Benitoite.Network.Http.listen",
    io fn injected_listen(ctx, host: &'c str, port: i64) -> IoReply<'e> {
        let mut ctx = ctx;
        let _ = (host, port);
        // 非公開の注入は L30 の受け入れテストの指定。OS の上限を実際に使い切らない。
        let no_buffers = if cfg!(target_os = "macos") { 55 } else { 105 };
        let errors = [24, 23, no_buffers, 12].into_iter().cycle().take(11).map(io::Error::from_raw_os_error)
            .chain([io::Error::from(io::ErrorKind::PermissionDenied)]).collect();
        let listener = Listener { socket: None, injected: errors, registration: None, connections: Vec::new(), retry_at: None, retry_millis: ACCEPT_RETRY_INITIAL_MILLIS, registration_failure: None };
        let site = ctx.site();
        let id = ctx.services().register_resource(ResourceKind::HttpListener, Box::new(listener), site);
        Ok(IoReply::Done(ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::Resource(id)])?))
    }
}
#[derive(Debug)]
struct TimedWorkers {
    inner: Box<dyn WorkerExec>,
    script: ScheduleHandle,
    waits: Rc<RefCell<Vec<u64>>>,
}
impl WorkerExec for TimedWorkers {
    fn wakeup(&self) -> Option<Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        self.script.allow_worker(job.op);
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        let now = self.script.parts().clock.monotonic_millis();
        if let Some(deadline) = deadline {
            self.waits.borrow_mut().push(deadline - now);
            self.script.allow_time(deadline - now);
        }
        self.inner.idle(deadline)
    }
}
#[derive(Debug)]
struct Capture(Arc<Mutex<Vec<u8>>>);
impl Write for Capture {
    fn write(&mut self, data: &[u8]) -> io::Result<usize> {
        self.0.lock().unwrap().extend(data);
        Ok(data.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
struct Evidence {
    end: VmStep,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    waits: Vec<u64>,
}
fn run_injected(program: &crate::bytecode::program::CompiledProgram, mode: ExecMode) -> Evidence {
    let script = ScheduleHandle::new([], false);
    let mut parts = script.parts();
    let waits = Rc::new(RefCell::new(Vec::new()));
    parts.workers = Box::new(TimedWorkers {
        inner: parts.workers,
        script: script.clone(),
        waits: Rc::clone(&waits),
    });
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let wake = script.wakeup();
    let outputs = (
        OutputPort::start(
            Stream::Stdout,
            Box::new(Capture(Arc::clone(&stdout))),
            false,
            wake.clone(),
        ),
        OutputPort::start(
            Stream::Stderr,
            Box::new(Capture(Arc::clone(&stderr))),
            false,
            wake.clone(),
        ),
    );
    let mut rt = IoRuntime::new(
        RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        mode,
        outputs,
        Box::new(io::Cursor::new(Vec::<u8>::new())),
        parts,
        Box::new(crate::runtime::run::NoInterrupt),
        wake,
    );
    rt.builtin_overrides.insert(
        crate::builtins::table::lookup_builtin("Benitoite.Network.Http.listen").unwrap(),
        &injected_listen::DECL,
    );
    let mut vm = Vm::new(
        program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let end = loop {
        match vm.run(&mut rt) {
            VmStep::Requests(ids) => {
                for id in ids {
                    vm.serve_request(&mut rt, id);
                }
            }
            end @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break end,
        }
    };

    rt.stdout.finish().unwrap();
    rt.stderr.finish().unwrap();
    assert!(rt.readiness.resources.is_empty());
    assert!(rt.readiness.retries.is_empty());
    assert!(script.record().error.is_none(), "{:?}", script.record());
    let stdout = stdout.lock().unwrap().clone();
    let stderr = stderr.lock().unwrap().clone();
    let waits = waits.borrow().clone();
    Evidence {
        end,
        stdout,
        stderr,
        waits,
    }
}

// 関門: 再試行の期限が VM の idle に届き、満了で本物の accept を再実行する契約。
// retry の数値だけの検査では、満了後の要求の置き直しと他タスクの進行を検出できない。
#[test]
fn shortage_retries_use_vm_timers_and_one_warning_in_both_modes() {
    let checked = crate::pipeline::check_text("l30.bnt", br#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit, String] uses Http.Listen, Console.Write, Clock.Time, State
  with listener = try Result.mapError(Http.listen("fake", 0), NetworkError.message), group = TaskGroup.open() do
    bind child <- TaskGroup.spawn(group, lambda()
      bind _ <- Clock.sleep(1)
      bind _ <- Console.writeLine("child")
      return ()
    end lambda)
    bind result <- Http.accept(listener)
    bind _ <- Task.await(child)
    return match result with
      case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.PermissionDenied then Result.Ok(()) else Result.Error("wrong kind") end if
      case Result.Ok(_) -> Result.Error("unexpected accepted request")
    end match
  end with
end function
"#, crate::pipeline::CheckOptions { require_main: true, deny_warnings: false });
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = crate::pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = crate::pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let evidence = run_injected(&program, mode);
        assert_eq!(evidence.end, VmStep::Finished(MainOutcome::Ok));
        assert_eq!(evidence.stdout, b"child\n");
        assert_eq!(
            evidence
                .stderr
                .split(|b| *b == b'\n')
                .filter(|s| !s.is_empty())
                .count(),
            1
        );
        // 子の sleep が最初の 5 ms の待ちを 1 と 4 に分ける。
        assert_eq!(
            evidence.waits,
            [1, 4, 10, 20, 40, 80, 160, 320, 640, 1000, 1000, 1000]
        );
    }
}

// 関門: Poll のないテストの部品を準備の待ちで黙って使うと待ち続ける（L30）。
#[cfg(unix)]
#[test]
fn registration_without_poll_is_internal_error() {
    use std::os::fd::AsRawFd;
    let (reader, _writer) = std::os::unix::net::UnixStream::pair().unwrap();
    let mut source = mio::unix::SourceFd(&reader.as_raw_fd());
    assert!(matches!(
        Registration::arm(
            &mut None,
            &mut source,
            &event::wakeup_without_poll(),
            mio::Interest::READABLE
        ),
        Err(Stop::Internal(_))
    ));
}

// 関門: 二度目の応答と解放後の操作は HTTP の失敗の値でなく実行時エラー（03-09）。
#[test]
fn exchange_respond_twice_and_releasing_checks_precede_socket_access() {
    let mut table = ResourceTable::default();
    let id = table.insert(
        ResourceKind::HttpExchange,
        ResourceContent::Os(Some(Box::new(Exchange {
            socket: None,
            release_socket: None,
            registration: None,
            response: None,
            response_owner: None,
            responded: true,
            registration_failure: None,
        }))),
        None,
    );
    let owner = TaskId {
        index: 0,
        generation: 0,
    };
    assert!(matches!(
        respond(&mut table, id, owner, vec![]),
        Err(Stop::Runtime(RuntimeError::ResponseSentTwice))
    ));
    table.request_release(id, ExtOpId(2));
    assert!(matches!(
        respond(&mut table, id, owner, vec![]),
        Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed {
            kind: ResourceKind::HttpExchange
        }))
    ));
}

// 関門: CLI の部分応答の停止は、まだ始まっていない解放を通る。
// この境界では、解放が既に待ちの列か作業用スレッドに渡った場合を確かめる。
// 同じ実ソケットを使い、停止時の unwind_release の結果・EOF・遅い完了の受理を守る。
#[test]
fn stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting() {
    use crate::runtime::heap::Heap;
    use crate::runtime::io::ops::{
        Accepted, LentOwned, OpKind, OpRecord, OpTable, Outcome, accept_completion,
        check_completion,
    };
    use crate::vm::state::RunState;
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindStep, unwind_release};
    use std::time::Duration;

    for dispatched in [false, true] {
        let listener = std::net::TcpListener::bind(("127.0.0.1", 0)).unwrap();
        let mut client = std::net::TcpStream::connect(listener.local_addr().unwrap()).unwrap();
        client
            .set_read_timeout(Some(Duration::from_secs(30)))
            .unwrap();
        let (socket, _) = listener.accept().unwrap();
        socket.set_nonblocking(true).unwrap();
        let mut rt = RunState::new(VmConfig::default(), 0);
        let id = rt.resources.insert(
            ResourceKind::HttpExchange,
            ResourceContent::Os(Some(Box::new(Exchange {
                socket: Some(mio::net::TcpStream::from_std(socket)),
                release_socket: None,
                registration: None,
                response: None,
                response_owner: None,
                responded: false,
                registration_failure: None,
            }))),
            None,
        );
        let op = rt.scheduler.new_ext_op_id();
        rt.resources.check_release(id).unwrap();
        assert!(matches!(
            rt.resources.request_release(id, op),
            super::super::resources::ReleaseStart::Blocking
        ));
        let job = dispatched.then(|| rt.resources.take_release_job().unwrap());
        let mut heap = Heap::new(HeapConfig::default());
        let mut log = ReleaseLog::default();
        let stopped = heap.epoch(|ctx| {
            unwind_release(
                ctx,
                &mut rt,
                TaskId {
                    index: 0,
                    generation: 0,
                },
                id,
                crate::vm::InstrRef {
                    proto: crate::bytecode::program::ProtoIdx(0),
                    pc: 0,
                },
                UnwindCause::Stop,
                &mut log,
            )
        });
        assert!(matches!(stopped, Ok(UnwindStep::Popped)), "{stopped:?}");
        assert_eq!(rt.resources.state(id), Some(ResourceState::Released));
        assert!(rt.resources.take_release_job().is_none());
        assert!(rt.resources.attachments.is_empty());
        let mut bytes = Vec::new();
        client.read_to_end(&mut bytes).unwrap();
        assert!(bytes.is_empty(), "stopping sent a 500 response: {bytes:?}");
        if let Some((_, _, handle)) = job {
            let mut ops = OpTable::default();
            ops.insert(
                op,
                OpRecord {
                    kind: OpKind::Release(id),
                    deliver_to: None,
                    lent: None,
                    site: None,
                },
            );
            let completion = Completion {
                op,
                outcome: Outcome::Released(handle.release()),
                returned: LentOwned::Nothing,
            };
            check_completion(&ops, &rt.resources, &completion).unwrap();
            assert!(
                matches!(accept_completion(&mut ops, &mut rt.resources, &mut None, completion).as_slice(), [Accepted::ReleaseFinished(resource)] if *resource == id)
            );
        }
    }
}

// 関門: 登録を外した Listener には新しい準備が来ないので、待ちを解放で起こす（L30）。
// 仮想時計は VM が idle になるまで進まないため、close より前に accept が待つ。
#[test]
fn closing_listener_wakes_parked_accept_without_waiting_for_retry_deadline() {
    let checked = crate::pipeline::check_text("l30-close.bnt", br#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit, String] uses Http.Listen, Clock.Time, State
 with listener = try Http.listen("fake", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  bind _ <- TaskGroup.spawn(group, lambda()
   Clock.sleep(1)
   bind _ <- Http.closeListener(listener)
   return ()
  end lambda)
  bind _ <- Http.accept(listener)
  return Result.Ok(())
 end with
end function
"#, crate::pipeline::CheckOptions { require_main: true, deny_warnings: false });
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = crate::pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = crate::pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let evidence = run_injected(&program, mode);
        assert!(
            matches!(evidence.end, VmStep::Stopped(crate::vm::StopEnd { reason: crate::vm::StopReason::Error(ref info), .. }) if info.stop == Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind: ResourceKind::HttpListener }))
        );
        assert_eq!(evidence.waits, [1]);
    }
}
