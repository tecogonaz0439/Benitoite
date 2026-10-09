//! OPEN-062 の R14 と R04 の HTTP の反例を実通信で確かめる（設計書 03-09・07-03、実装プラン L33）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::services::{InterruptSource, RunInput};
use benitoite::runtime::run::{self, EndKind, OutputTarget, RunEnd, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{NetworkFaults, RuntimeParts, TaskPicker};
use benitoite::vm::{ExecMode, TaskId, VmConfig};
use std::collections::VecDeque;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
    mpsc,
};
use std::time::{Duration, Instant};

const LIMIT: Duration = Duration::from_secs(10);
const IMPORTS: &str =
    "import Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.IO.Console\n";
type Capture = Arc<Mutex<Vec<u8>>>;

#[derive(Debug)]
struct Interrupt(Arc<AtomicBool>);
impl InterruptSource for Interrupt {
    fn requested(&self) -> bool {
        self.0.load(Ordering::Relaxed)
    }
    fn flag(&self) -> Option<&AtomicBool> {
        Some(&self.0)
    }
}

// R30 と同じ上限付きの観測。上限は停止の検出にだけ使い、期待値や実行の順序は決めない。
fn bounded<T: Send + 'static>(f: impl FnOnce() -> T + Send + 'static) -> T {
    let (tx, rx) = mpsc::channel();
    let thread = std::thread::spawn(move || {
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(f));
        let _sent = tx.send(result);
    });
    let result = rx.recv_timeout(Duration::from_secs(20)).unwrap();
    thread.join().unwrap();
    result.unwrap_or_else(|payload| std::panic::resume_unwind(payload))
}

// 作業文書が求める出力の容量待ちを、公開の待ち行列から観測する。
// 本物の選択は変えず、spawned を含めて内側の部品へ渡す（R30「補助の作り方」）。
#[derive(Debug)]
struct BlockedWriter {
    inner: Box<dyn TaskPicker>,
    writer: Option<TaskId>,
    stderr: Capture,
    notify: Option<mpsc::Sender<()>>,
}
impl TaskPicker for BlockedWriter {
    fn spawned(&mut self, serial: u64, task: TaskId) {
        if serial == 1 {
            self.writer = Some(task);
        }
        self.inner.spawned(serial, task);
    }
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize> {
        if self.writer.is_some_and(|writer| !ready.contains(&writer))
            && self.stderr.lock().unwrap().ends_with(b"filled\n")
            && let Some(notify) = self.notify.take()
        {
            notify.send(()).unwrap();
        }
        self.inner.pick(ready)
    }
}

struct Server {
    flag: Arc<AtomicBool>,
    wakeup: Wakeup,
    result: mpsc::Receiver<RunEnd>,
    thread: Option<std::thread::JoinHandle<()>>,
    stderr: Capture,
}
impl Server {
    fn start(
        source: &str,
        mode: ExecMode,
        budget: u32,
        stdout: Capture,
        stderr: Capture,
        notify: Option<mpsc::Sender<()>>,
    ) -> Self {
        let checked = pipeline::check_text(
            "open-062-http.bnt",
            format!("{IMPORTS}{source}").as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        let program = pipeline::compile(&core, checked.sources).unwrap();
        let flag = Arc::new(AtomicBool::new(false));
        let interrupted = Arc::clone(&flag);
        let errors = Arc::clone(&stderr);
        let (wake_tx, wake_rx) = mpsc::channel();
        let (tx, result) = mpsc::channel();
        let thread = std::thread::spawn(move || {
            let mut parts = RuntimeParts::real_with_poll(NetworkFaults::default()).unwrap();
            wake_tx.send(parts.workers.wakeup().unwrap()).unwrap();
            if notify.is_some() {
                parts.picker = Box::new(BlockedWriter {
                    inner: parts.picker,
                    writer: None,
                    stderr: Arc::clone(&errors),
                    notify,
                });
            }
            let end = run::run_program(
                &program,
                RunEnv {
                    input: RunInput {
                        arguments: vec![],
                        working_directory: env!("CARGO_MANIFEST_DIR").into(),
                        script_directory: env!("CARGO_MANIFEST_DIR").into(),
                    },
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(stdout),
                    stderr: OutputTarget::Capture(errors),
                    interrupt: Box::new(Interrupt(interrupted)),
                    parts: Some(parts),
                    mode,
                    vm: VmConfig {
                        call_budget: budget,
                        ..VmConfig::default()
                    },
                    heap: HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                    dev_panic_after_first_write: false,
                },
            );
            let _sent = tx.send(end);
        });
        Self {
            flag,
            wakeup: wake_rx.recv_timeout(LIMIT).unwrap(),
            result,
            thread: Some(thread),
            stderr,
        }
    }
    fn port(&self) -> u16 {
        let started = Instant::now();
        loop {
            let bytes = self.stderr.lock().unwrap().clone();
            if let Some(end) = bytes.iter().position(|byte| *byte == b'\n') {
                let line = bytes.get(..end).unwrap();
                return std::str::from_utf8(line).unwrap().parse().unwrap();
            }
            if let Ok(end) = self.result.try_recv() {
                panic!("server ended before port: {end:?}");
            }
            assert!(started.elapsed() < LIMIT, "server did not publish port");
            std::thread::yield_now();
        }
    }
    fn finish(mut self) -> RunEnd {
        let end = self.result.recv_timeout(LIMIT).unwrap();
        self.thread.take().unwrap().join().unwrap();
        end
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        self.flag.store(true, Ordering::Relaxed);
        self.wakeup.wake();
    }
}

fn normal(end: RunEnd) {
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert_eq!(end.exit_code, 0, "{end:?}");
    assert!(
        end.main_error.is_none() && end.reports.is_empty(),
        "{end:?}"
    );
}
fn socket(port: u16) -> TcpStream {
    let stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
    stream.set_read_timeout(Some(LIMIT)).unwrap();
    stream.set_write_timeout(Some(LIMIT)).unwrap();
    stream
}
fn request(port: u16, request: &[u8]) -> Vec<u8> {
    let mut stream = socket(port);
    stream.write_all(request).unwrap();
    let mut bytes = Vec::new();
    stream.read_to_end(&mut bytes).unwrap();
    bytes
}
fn response(bytes: &[u8], status: u16, body: Option<&str>) {
    let text = std::str::from_utf8(bytes).unwrap();
    assert!(text.starts_with(&format!("HTTP/1.1 {status} ")), "{text}");
    if let Some(body) = body {
        assert_eq!(text.split_once("\r\n\r\n").unwrap().1, body);
    }
}
fn matrix() -> impl Iterator<Item = (ExecMode, u32)> {
    [ExecMode::Direct, ExecMode::Request]
        .into_iter()
        .flat_map(|mode| {
            [1, VmConfig::default().call_budget]
                .into_iter()
                .map(move |budget| (mode, budget))
        })
}

fn server(source: &str, mode: ExecMode, budget: u32) -> Server {
    Server::start(
        source,
        mode,
        budget,
        Arc::new(Mutex::new(vec![])),
        Arc::new(Mutex::new(vec![])),
        None,
    )
}

const ACCEPT_QUERY: &str = r#"
function main() -> Result[Unit, String] uses Http.Listen, Console.Write, State
  with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message) do
    Console.writeErrorLine(Integer.toString(Http.listenerPort(listener)))
    with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
      bind query <- Http.Request.query(Http.requestOf(exchange))
      bind body <- if query = [Pair("q", "%G0")] then "%G0" else "wrong query" end if
      return Http.respond(exchange, Http.text(200, body)) |> Result.mapError(_, NetworkError.message)
    end with
  end with
end function
"#;

// OPEN-062 R14 の反例: `?q=%FF`、`%G0`、UTF-8 でない受信のヘッダ。
// クエリ: %FF には 400 を返し、同じ accept が %G0 を字面の Pair として受け付ける
// （設計書 03-09「サーバの接続と要求の読み方」「要求と応答の型」、ADR 0322 決定 4・0330 決定 1）。
// 関門: 拒否の後に同じ accept を続ける契約。正常なソースのクライアントでは不正な入力を作れない。
#[test]
fn open_062_r14_query_rejects_invalid_utf8_and_keeps_malformed_escape() {
    for (mode, budget) in matrix() {
        bounded(move || {
            let server = server(ACCEPT_QUERY, mode, budget);
            let port = server.port();
            response(
                &request(port, b"GET /?q=%FF HTTP/1.1\r\nHost: localhost\r\n\r\n"),
                400,
                None,
            );
            response(
                &request(port, b"GET /?q=%G0 HTTP/1.1\r\nHost: localhost\r\n\r\n"),
                200,
                Some("%G0"),
            );
            normal(server.finish());
        });
    }
}

// OPEN-062 R14 の反例: `?q=%FF`、`%G0`、UTF-8 でない受信のヘッダ。
// サーバ: UTF-8 でない値には 400 を返し、同じ accept が次の正しい要求を受け付ける（03-09、ADR 0291）。
// 関門: クエリの拒否とは別の外部入力。値を String にする前の拒否の漏れを捕まえる。
#[test]
fn open_062_r14_server_header_rejects_invalid_utf8() {
    for (mode, budget) in matrix() {
        bounded(move || {
            let server = server(ACCEPT_QUERY, mode, budget);
            let port = server.port();
            response(
                &request(
                    port,
                    b"GET / HTTP/1.1\r\nHost: localhost\r\nX-Bad: \xff\r\n\r\n",
                ),
                400,
                None,
            );
            response(
                &request(port, b"GET /?q=%G0 HTTP/1.1\r\nHost: localhost\r\n\r\n"),
                200,
                Some("%G0"),
            );
            normal(server.finish());
        });
    }
}

// OPEN-062 R14 の反例: `?q=%FF`、`%G0`、UTF-8 でない受信のヘッダ。
// クライアント: UTF-8 でない応答の値は InvalidHTTPData の Result.Error になる（03-09、10-16）。
// 関門: 本物のクライアントの応答から言語の String への変換を守る。注入の表はこの変換を通らない。
#[test]
fn open_062_r14_client_header_returns_invalid_http_data() {
    for (mode, budget) in matrix() {
        bounded(move || {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            let port = listener.local_addr().unwrap().port();
            let source = format!(
                r#"
function main() -> Result[Unit, String] uses Http.Connect
  return match Http.get("http://127.0.0.1:{port}/") with
    case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.InvalidHTTPData then Result.Ok(()) else Result.Error(NetworkError.message(error)) end if
    case Result.Ok(_) -> Result.Error("invalid header was accepted")
  end match
end function
"#
            );
            let client = server(&source, mode, budget);
            let (mut stream, _) = listener.accept().unwrap();
            stream.set_read_timeout(Some(LIMIT)).unwrap();
            stream.set_write_timeout(Some(LIMIT)).unwrap();
            let mut head = vec![];
            while !head.ends_with(b"\r\n\r\n") {
                let mut byte = [0];
                stream.read_exact(&mut byte).unwrap();
                head.extend_from_slice(&byte);
                assert!(head.len() < 65536);
            }
            assert!(head.starts_with(b"GET / HTTP/1.1\r\n"));
            stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nX-Bad: \xff\r\nConnection: close\r\n\r\nok").unwrap();
            drop(stream);
            normal(client.finish());
        });
    }
}

const BLOCKED_OUTPUT: &str = r#"
function waitFilled(filled: Reference[Boolean]) -> Unit uses State
  if Reference.get(filled) then return () end if
  return waitFilled(filled)
end function
function main() -> Result[Unit, String] uses Http.Listen, Console.Write, State
  with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
    Console.writeErrorLine(Integer.toString(Http.listenerPort(listener)))
    bind filled <- Reference.new(false)
    bind done <- Reference.new(false)
    bind writer <- TaskGroup.spawn(group, lambda()
      Console.write(String.repeat("x", 1048577))
      Reference.set(filled, true)
      Console.writeErrorLine("filled")
      Console.write("capacity")
      Reference.set(done, true)
      return ()
    end lambda)
    waitFilled(filled)
    with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
      bind status <- if Reference.get(done) then 500 else 200 end if
      bind _ <- try Http.respond(exchange, Http.text(status, "accepted while stdout blocked")) |> Result.mapError(_, NetworkError.message)
    end with
    Task.await(writer)
    return Result.Ok(())
  end with
end function
"#;

// OPEN-062 R04 の反例: 読み手が読まないパイプに 64 KiB を超えて書くと、
// ほかのタスク、タイマー、HTTP の受け付け、中断の要求の確認が止まる。
// 1 MiB を超える出力の後、容量待ちになったタスクを観測してから接続し、
// stdout の Mutex を放す前に HTTP の応答が届く性質を確かめる（ADR 0265、L33）。
// 関門: R30 のタイマーのテストでは届かない、出力の待ちと本物の準備の待ちの組み合わせ。
#[test]
fn open_062_r04_blocked_stdout_does_not_block_http_accept() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for budget in [1, VmConfig::default().call_budget] {
            bounded(move || {
                let output = Arc::new(Mutex::new(vec![]));
                let held = Arc::clone(&output);
                let (release_tx, release_rx) = mpsc::channel();
                let (held_tx, held_rx) = mpsc::channel();
                let gate = std::thread::spawn(move || {
                    let guard = held.lock().unwrap();
                    held_tx.send(()).unwrap();
                    let released = release_rx.recv().is_ok();
                    drop(guard);
                    released
                });
                held_rx.recv_timeout(LIMIT).unwrap();
                let (blocked_tx, blocked_rx) = mpsc::channel();
                let server = Server::start(
                    BLOCKED_OUTPUT,
                    mode,
                    budget,
                    Arc::clone(&output),
                    Arc::new(Mutex::new(vec![])),
                    Some(blocked_tx),
                );
                let port = server.port();
                blocked_rx.recv_timeout(LIMIT).unwrap();
                // Mutex はまだ助けのスレッドが持つ。容量待ちのまま accept と respond が進む。
                assert!(output.try_lock().is_err());
                let bytes = request(port, b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n");
                let still_held = output.try_lock().is_err();
                release_tx.send(()).unwrap();
                let released_by_signal = gate.join().unwrap();
                assert!(
                    still_held && released_by_signal,
                    "gate released before HTTP response"
                );
                response(&bytes, 200, Some("accepted while stdout blocked"));
                normal(server.finish());
                let bytes = output.lock().unwrap();
                assert_eq!(bytes.len(), 1_048_585);
                assert!(
                    bytes
                        .get(..1_048_577)
                        .unwrap()
                        .iter()
                        .all(|byte| *byte == b'x')
                );
                assert_eq!(bytes.get(1_048_577..).unwrap(), b"capacity");
            });
        }
    }
}
