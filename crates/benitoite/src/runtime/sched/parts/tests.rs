//! 作業用のスレッドの契約を実際の WorkerExec の境界で確かめる（実装プラン R40）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::builtins::iface::{Lend, OsResource, WorkerWait};
use crate::runtime::heap::ResourceId;
use crate::runtime::io::event::{wakeup_with_poll, wakeup_without_poll};
use crate::runtime::io::ops::{JobWork, LentOwned};
use crate::runtime::sched::ExtOpId;
use std::collections::HashSet;
use std::thread::ThreadId;

#[test]
fn network_faults_lookup_is_ascii_case_insensitive_and_uses_first_match() {
    // 関門: 差し替えの表が実際に選ぶ失敗を公開の口で確かめる。ネットワークの本体がまだ
    // 仮置きの L00 では、そのテストは選択の順と ASCII の規則を検査できない（実装プラン 10-16）。
    let faults = NetworkFaults {
        by_host: vec![
            ("Example.COM".into(), NetworkFault::ConnectionRefused),
            ("example.com".into(), NetworkFault::TimedOut),
            ("reset.test".into(), NetworkFault::ConnectionReset),
            ("timeout.test".into(), NetworkFault::TimedOut),
            ("É.test".into(), NetworkFault::HostNotFound),
        ],
    };
    for (host, expected) in [
        ("EXAMPLE.com", Some(NetworkFault::ConnectionRefused)),
        ("RESET.TEST", Some(NetworkFault::ConnectionReset)),
        ("timeout.test", Some(NetworkFault::TimedOut)),
        ("É.TEST", Some(NetworkFault::HostNotFound)),
        ("é.test", None),
        ("missing.test", None),
        ("", None),
    ] {
        assert_eq!(faults.lookup(host), expected, "{host}");
    }
    assert_eq!(NetworkFaults::default().lookup("example.com"), None);
    assert!(
        RuntimeParts::real(wakeup_without_poll())
            .network_faults
            .by_host
            .is_empty()
    );
    let script = crate::runtime::sched::testing::ScheduleHandle::new([], true);
    assert!(script.parts().network_faults.by_host.is_empty());
}

// 関門: panic 時の返却、64 本の上限と再使用、期限のない待ちの起こし、終了時の非待機は
// 本物のスレッドと Poll 固有の契約であり、R26 の筋書きの実行器では捕まえられない。
// 外部の仕事だけを channel で止める。テストのための本番の差し込み口は加えない。
// recv_timeout は退行時にテストが終わらなくなるのを防ぐためだけで、順序は channel で決める。
fn receive<T>(receiver: &mpsc::Receiver<T>) -> T {
    receiver.recv_timeout(Duration::from_secs(10)).unwrap()
}

fn job(op: u64, lend: LentOwned, work: impl FnOnce() + Send + 'static) -> WorkerJob {
    let kind = match &lend {
        LentOwned::Nothing => Lend::Nothing,
        LentOwned::Resource(id, _) => Lend::Resource(*id),
        LentOwned::Stdin(_) => Lend::Stdin,
    };
    WorkerJob {
        op: ExtOpId(op),
        lent: lend,
        work: JobWork::Builtin(WorkerWait::new(
            kind,
            move |_| work(),
            |_, (), _| Ok(crate::runtime::heap::Value::Unit),
        )),
    }
}

fn completed(workers: &mut dyn WorkerExec) -> Completion {
    loop {
        if let Some(completion) = workers.try_recv() {
            return completion;
        }
        // 不具合で通知がなくても期限で戻る。時間の経過は結果の判定に使わない。
        assert!(matches!(workers.idle(Some(10_000)), IdleWake::Progress));
    }
}

#[derive(Debug)]
struct Resource {
    dropped: mpsc::Sender<()>,
    release: Option<(mpsc::Sender<ThreadId>, mpsc::Receiver<()>, bool)>,
}
impl Drop for Resource {
    fn drop(&mut self) {
        let _failed = self.dropped.send(()).is_err();
    }
}
impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(mut self: Box<Self>) -> Result<(), String> {
        let (entered, resume, fails) = self.release.take().unwrap();
        entered.send(std::thread::current().id()).unwrap();
        receive(&resume);
        if fails {
            Err("release failed".into())
        } else {
            Ok(())
        }
    }
}

#[test]
fn panic_returns_lent_resource_and_stdin_and_worker_remains_usable() {
    let mut parts = RuntimeParts::real(wakeup_with_poll().unwrap());
    let (dropped, drops) = mpsc::channel();
    let id = ResourceId(17);
    for (op, lend) in [
        (
            1,
            LentOwned::Resource(
                id,
                Box::new(Resource {
                    dropped,
                    release: None,
                }),
            ),
        ),
        (
            2,
            LentOwned::Stdin(Box::new(std::io::Cursor::new(b"input".to_vec()))),
        ),
    ] {
        parts
            .workers
            .submit(job(op, lend, || panic!("worker panic")));
        let result = completed(&mut *parts.workers);
        assert_eq!(result.op, ExtOpId(op));
        assert!(matches!(result.outcome, Outcome::Panicked(_)));
        match result.returned {
            LentOwned::Resource(returned_id, handle) => {
                assert_eq!(returned_id, id);
                assert!(drops.try_recv().is_err());
                drop(handle);
                receive(&drops);
            }
            LentOwned::Stdin(mut reader) => {
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                assert_eq!(line, "input");
            }
            LentOwned::Nothing => panic!("lent object missing"),
        }
    }
    parts.workers.submit(job(3, LentOwned::Nothing, || {}));
    assert!(matches!(
        completed(&mut *parts.workers).outcome,
        Outcome::Worker(_)
    ));
}

fn gated_job(op: u64, started: mpsc::Sender<(u64, ThreadId)>) -> (WorkerJob, mpsc::Sender<()>) {
    let (resume, gate) = mpsc::channel();
    (
        job(op, LentOwned::Nothing, move || {
            started.send((op, std::thread::current().id())).unwrap();
            receive(&gate);
        }),
        resume,
    )
}

#[test]
fn sixty_four_workers_queue_the_next_job_and_reuse_idle_threads() {
    let mut parts = RuntimeParts::real(wakeup_with_poll().unwrap());
    let (started, starts) = mpsc::channel();
    let mut gates = Vec::new();
    for op in 0..64 {
        let (job, resume) = gated_job(op, started.clone());
        parts.workers.submit(job);
        gates.push(resume);
    }
    let mut threads = HashSet::new();
    let mut first_thread = None;
    for _ in 0..64 {
        let (op, thread) = receive(&starts);
        threads.insert(thread);
        if op == 0 {
            first_thread = Some(thread);
        }
    }
    assert_eq!(threads.len(), 64);
    let (job, resume) = gated_job(64, started.clone());
    parts.workers.submit(job);
    gates[0].send(()).unwrap();
    // 64 本とも仕事の中で止めておくため、次の仕事は解放した一本だけが実行できる。
    let (op, thread) = receive(&starts);
    assert_eq!(op, 64);
    assert_eq!(Some(thread), first_thread);
    assert_eq!(completed(&mut *parts.workers).op, ExtOpId(0));
    resume.send(()).unwrap();
    for gate in gates.into_iter().skip(1) {
        gate.send(()).unwrap();
    }
    let mut finished = HashSet::new();
    for _ in 0..64 {
        finished.insert(completed(&mut *parts.workers).op);
    }
    assert_eq!(finished.len(), 64);
    let (job, resume) = gated_job(65, started);
    parts.workers.submit(job);
    let (_, thread) = receive(&starts);
    assert!(threads.contains(&thread));
    resume.send(()).unwrap();
    assert_eq!(completed(&mut *parts.workers).op, ExtOpId(65));
}

#[test]
fn completion_wakes_idle_without_deadline_and_expired_timer_does_not_wait() {
    for poll in [false, true] {
        let wakeup = if poll {
            wakeup_with_poll().unwrap()
        } else {
            wakeup_without_poll()
        };
        let (started, starts) = mpsc::channel();
        let (job, resume) = gated_job(1, started);
        let mut parts = RuntimeParts::real(wakeup);
        assert!(matches!(parts.workers.idle(Some(0)), IdleWake::Progress));
        parts.workers.submit(job);
        receive(&starts);
        let finishing = std::thread::spawn(move || resume.send(()).unwrap());
        assert!(matches!(parts.workers.idle(None), IdleWake::Progress));
        let completion = if poll {
            parts.workers.try_recv().unwrap()
        } else {
            completed(&mut *parts.workers)
        };
        assert_eq!(completion.op, ExtOpId(1));
        finishing.join().unwrap();
    }
}

#[test]
fn blocking_release_runs_once_on_worker_and_returns_failure() {
    for fails in [false, true] {
        let (dropped, drops) = mpsc::channel();
        let (entered, entries) = mpsc::channel();
        let (resume, gate) = mpsc::channel();
        let mut parts = RuntimeParts::real(wakeup_with_poll().unwrap());
        parts.workers.submit(WorkerJob {
            op: ExtOpId(9),
            work: JobWork::Release(Box::new(Resource {
                dropped,
                release: Some((entered, gate, fails)),
            })),
            lent: LentOwned::Nothing,
        });
        assert_ne!(receive(&entries), std::thread::current().id());
        assert!(parts.workers.try_recv().is_none());
        resume.send(()).unwrap();
        let result = completed(&mut *parts.workers);
        match result.outcome {
            Outcome::Released(result) => assert_eq!(
                result,
                if fails {
                    Err("release failed".into())
                } else {
                    Ok(())
                }
            ),
            other @ (Outcome::Worker(_) | Outcome::Ready | Outcome::Panicked(_)) => {
                panic!("unexpected outcome: {other:?}")
            }
        }
        assert!(matches!(result.returned, LentOwned::Nothing));
        receive(&drops);
        assert!(entries.try_recv().is_err());
    }
}

#[test]
fn dropping_runtime_does_not_wait_and_late_return_drops_resource() {
    use crate::runtime::Stream;
    use crate::runtime::io::services::RunInput;
    use crate::runtime::io::{output::OutputPort, services::IoRuntime};
    use crate::runtime::run::NoInterrupt;
    use crate::vm::ExecMode;
    let (dropped, drops) = mpsc::channel();
    let (started, starts) = mpsc::channel();
    let (resume, gate) = mpsc::channel();
    let (finished, finishes) = mpsc::channel();
    let runner = std::thread::spawn(move || {
        let wakeup = wakeup_with_poll().unwrap();
        let outputs = (
            OutputPort::start(
                Stream::Stdout,
                Box::new(std::io::sink()),
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
        let mut rt = IoRuntime::new(
            RunInput {
                arguments: vec![],
                working_directory: "/".into(),
                script_directory: "/".into(),
            },
            ExecMode::Direct,
            outputs,
            Box::new(std::io::Cursor::new(vec![])),
            RuntimeParts::real(wakeup.clone()),
            Box::new(NoInterrupt),
            wakeup,
        );
        rt.parts.workers.submit(job(
            1,
            LentOwned::Resource(
                ResourceId(1),
                Box::new(Resource {
                    dropped,
                    release: None,
                }),
            ),
            move || {
                started.send(()).unwrap();
                receive(&gate);
            },
        ));
        // 仕事が始まったことはテストの制御側が受け取る。実行器の drop は先に始めてもよいが、
        // 未開始の仕事を捨てる経路にならないように制御側から許可を受け取る。
        receive(&finishes);
        drop(rt);
    });
    receive(&starts);
    finished.send(()).unwrap();
    // join が戻ってから仕事を進めるので、drop が仕事の終わりを待てばここで失敗する。
    // join 自体を期限付き channel で囲み、退行でもテスト全体を止めない。
    let (joined, joins) = mpsc::channel();
    let joining = std::thread::spawn(move || {
        runner.join().unwrap();
        joined.send(()).unwrap();
    });
    receive(&joins);
    assert!(drops.try_recv().is_err());
    resume.send(()).unwrap();
    receive(&drops);
    joining.join().unwrap();
}
