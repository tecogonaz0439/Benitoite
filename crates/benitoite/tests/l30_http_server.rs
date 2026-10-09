//! HTTP サーバを公開パイプラインと実通信で確かめる（実装プラン L30）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
// 関門: 解析・IO・準備の待ち・解放を一つの実行につなぐ。内部の解析テストでは
// 登録の取りこぼし、要求の置き直し、with の解放を確かめられない。
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::services::{InterruptSource, RunInput};
use benitoite::runtime::run::{self, EndKind, OutputTarget, RunEnd, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{NetworkFaults, RuntimeParts};
use benitoite::vm::{ExecMode, VmConfig};
use std::io::{Read, Write};
use std::net::{Shutdown, TcpStream};
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
    mpsc,
};
use std::time::{Duration, Instant};
const LIMIT: Duration = Duration::from_secs(30);
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
fn compile(source: &str) -> benitoite::bytecode::program::CompiledProgram {
    let checked = pipeline::check_text(
        "l30.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}
struct Server {
    port: u16,
    flag: Arc<AtomicBool>,
    wakeup: Wakeup,
    result: mpsc::Receiver<RunEnd>,
    stdout: Arc<Mutex<Vec<u8>>>,
}
impl Server {
    fn start(source: String, mode: ExecMode) -> Self {
        let program = compile(&source);
        let stdout = Arc::new(Mutex::new(Vec::new()));
        let output = Arc::clone(&stdout);
        let flag = Arc::new(AtomicBool::new(false));
        let interrupted = Arc::clone(&flag);
        let (wake_tx, wake_rx) = mpsc::channel();
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || {
            let parts = RuntimeParts::real_with_poll(NetworkFaults::default()).unwrap();
            wake_tx.send(parts.workers.wakeup().unwrap()).unwrap();
            let end = run::run_program(
                &program,
                RunEnv {
                    input: RunInput {
                        arguments: vec![],
                        working_directory: "/".into(),
                        script_directory: "/".into(),
                    },
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(output),
                    stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    interrupt: Box::new(Interrupt(interrupted)),
                    parts: Some(parts),
                    mode,
                    vm: VmConfig {
                        call_budget: 8,
                        ..VmConfig::default()
                    },
                    heap: HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                    dev_panic_after_first_write: false,
                },
            );
            drop(tx.send(end));
        });
        let wakeup = wake_rx.recv_timeout(LIMIT).unwrap();
        let start = Instant::now();
        loop {
            let bytes = stdout.lock().unwrap().clone();
            if let Some(line) = bytes
                .split(|b| *b == b'\n')
                .next()
                .filter(|_| bytes.contains(&b'\n'))
            {
                let port = std::str::from_utf8(line).unwrap().parse().unwrap();
                return Self {
                    port,
                    flag,
                    wakeup,
                    result: rx,
                    stdout,
                };
            }
            if let Ok(end) = rx.try_recv() {
                panic!("server ended before publishing its port: {end:?}");
            }
            if start.elapsed() >= LIMIT {
                flag.store(true, Ordering::Relaxed);
                wakeup.wake();
                panic!("server port timeout");
            }
            std::thread::sleep(Duration::from_millis(1));
        }
    }
    fn connect(&self) -> TcpStream {
        assert_ne!(self.port, 0);
        let socket = TcpStream::connect(("127.0.0.1", self.port)).unwrap();
        socket.set_read_timeout(Some(LIMIT)).unwrap();
        socket.set_write_timeout(Some(LIMIT)).unwrap();
        socket
    }
    fn request(&self, request: &[u8]) -> Vec<u8> {
        let mut socket = self.connect();
        socket.write_all(request).unwrap();
        let mut response = Vec::new();
        if let Err(error) = socket.read_to_end(&mut response) {
            // 上限で本体を読まずに閉じた接続は RST で終わっても、先に受けた応答を検査する。
            assert!(
                error.kind() == std::io::ErrorKind::ConnectionReset && !response.is_empty(),
                "{error}"
            );
        }
        response
    }
    fn finish(&self) -> RunEnd {
        self.result.recv_timeout(LIMIT).unwrap()
    }
    fn interrupt(&self) {
        self.flag.store(true, Ordering::Relaxed);
        self.wakeup.wake();
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        self.interrupt();
    }
}
const IMPORTS: &str = "import Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Clock\n";
fn source(body: &str) -> String {
    format!(
        "{IMPORTS}function main() -> Result[Unit, String] uses Http.Listen, Console.Write, Clock.Time, State\n with listener = try Http.listen(\"127.0.0.1\", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do\n  Console.writeLine(Integer.toString(Http.listenerPort(listener)))\n {body}\n end with\nend function\n"
    )
}
const EXCHANGE: &str =
    "with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do";
const RESPOND: &str = "bind _ <- try Http.respond(exchange, Http.Response(status: 200, headers: [Pair(\"Content-Length\", \"999\"), Pair(\"CONNECTION\", \"keep-alive\")], body: String.toUTF8(\"ok\"))) |> Result.mapError(_, NetworkError.message)";
fn normal_source() -> String {
    source(&format!(
        "{EXCHANGE}\n {RESPOND}\n return Result.Ok(())\nend with"
    ))
}
fn returned(end: RunEnd) {
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert!(end.main_error.is_none(), "{end:?}");
    assert!(end.reports.is_empty(), "{end:?}");
}

const QUERY_CASES: &[(&str, &str)] = &[
    (
        "/path?q=a+b%20c&a&&b=c=d&bad=%G0&tail=%",
        "[Pair(\"q\", \"a b c\"), Pair(\"a\", \"\"), Pair(\"b\", \"c=d\"), Pair(\"bad\", \"%G0\"), Pair(\"tail\", \"%\")]",
    ),
    ("/path?", "[]"),
    ("/path", "[]"),
];
fn roundtrip_source(query: &str) -> String {
    source(&format!(
        r#"{EXCHANGE}
 bind req <- Http.requestOf(exchange)
 if Http.Request.method(req) <> "POST" or Http.Request.path(req) <> "/path"
   or Http.Request.query(req) <> {query}
   or List.take(Http.Request.headers(req), 2) <> [Pair("x-test", "one"), Pair("x-test", "two")]
   or Http.Request.body(req) <> String.toUTF8("abc") then
   return Result.Error("request fields")
 end if
 {RESPOND}
 return Result.Ok(())
end with"#
    ))
}
#[test]
fn roundtrip_content_length_and_chunked_in_both_modes() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for (target, query) in QUERY_CASES {
            for body in [b"Content-Length: 3\r\n\r\nabc".as_slice(), b"Transfer-Encoding: chunked\r\n\r\n1\r\na\r\n2;ext=x\r\nbc\r\n0\r\nX-Trailer: yes\r\n\r\n"] {
                let server = Server::start(roundtrip_source(query), mode);
                let head = format!("POST {target} HTTP/1.1\r\nX-Test: one\r\nx-TEST: two\r\n");
                let mut socket = server.connect();
                // 分割した書き込みでも、最後の本体まで揃ってから要求を渡す。
                for bytes in [head.as_bytes(), body] { socket.write_all(bytes).unwrap(); }
                let mut response = Vec::new(); socket.read_to_end(&mut response).unwrap();
                assert_eq!(response, b"HTTP/1.1 200 OK\r\ncontent-length: 2\r\nconnection: close\r\n\r\nok");
                returned(server.finish());
            }
        }
    }
}
#[test]
fn invalid_and_slow_connections_do_not_stop_the_same_accept() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let server = Server::start(normal_source(), mode);
        let mut slow = server.connect();
        slow.write_all(b"GET / HTTP/1.1\r\nX:").unwrap();
        let mut lost = server.connect();
        lost.write_all(b"GET /").unwrap();
        lost.shutdown(Shutdown::Both).unwrap();
        for (request, code) in [
            (b"GET / HTTP/1.1\r\nX: \xff\r\n\r\n".to_vec(), 400),
            (
                b"POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n1\r\na\r\n1000000\r\n"
                    .to_vec(),
                413,
            ),
            (
                format!("GET / HTTP/1.1\r\n{}\r\n", "X: a\r\n".repeat(101)).into_bytes(),
                431,
            ),
            (b"bad\r\n\r\n".to_vec(), 400),
            (b"GET /?q=%FF HTTP/1.1\r\n\r\n".to_vec(), 400),
            (
                b"POST / HTTP/1.1\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n"
                    .to_vec(),
                400,
            ),
            (
                b"POST / HTTP/1.1\r\nContent-Length: 16777217\r\n\r\n".to_vec(),
                413,
            ),
            (
                b"POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n1000001\r\n".to_vec(),
                413,
            ),
            (
                [
                    b"GET / HTTP/1.1\r\nX: ".as_slice(),
                    &vec![b'x'; 65_536],
                    b"\r\n\r\n",
                ]
                .concat(),
                431,
            ),
        ] {
            assert!(
                server
                    .request(&request)
                    .starts_with(format!("HTTP/1.1 {code} ").as_bytes()),
                "{code}"
            );
        }
        assert!(server.request(b"GET / HTTP/1.1\r\n\r\n").ends_with(b"ok"));
        returned(server.finish());
    }
}
#[test]
fn exchange_scope_sends_500_and_explicit_close_returns_success() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for close in [false, true] {
            let body = if close {
                "bind _ <- try Http.closeExchange(exchange) |> Result.mapError(_, NetworkError.message)"
            } else {
                ""
            };
            let server = Server::start(
                source(&format!(
                    "{EXCHANGE}\n {body}\n return Result.Ok(())\nend with"
                )),
                mode,
            );
            assert!(
                server
                    .request(b"GET / HTTP/1.1\r\n\r\n")
                    .starts_with(b"HTTP/1.1 500 Internal Server Error\r\n")
            );
            returned(server.finish());
        }
    }
}
fn error_actions() -> Vec<(String, benitoite::diag::DiagCode)> {
    vec![
        (
            format!("{RESPOND}\n{RESPOND}"),
            benitoite::diag::DiagCode::R0801,
        ),
        (
            format!("bind _ <- Http.closeExchange(exchange)\n{RESPOND}"),
            benitoite::diag::DiagCode::R0402,
        ),
        (
            "bind _ <- Http.closeExchange(exchange)\nbind _ <- Http.requestOf(exchange)".into(),
            benitoite::diag::DiagCode::R0402,
        ),
        (
            "bind _ <- Http.respond(exchange, Http.text(99, \"bad\"))".into(),
            benitoite::diag::DiagCode::R0701,
        ),
    ]
}

#[test]
fn respond_twice_and_access_after_close_are_runtime_errors() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for (action, code) in error_actions() {
            let server = Server::start(
                source(&format!(
                    "{EXCHANGE}\n {action}\n return Result.Ok(())\nend with"
                )),
                mode,
            );
            server.request(b"GET / HTTP/1.1\r\n\r\n");
            let end = server.finish();
            assert_eq!(end.end, EndKind::Stopped, "{end:?}");
            assert_eq!(end.reports.len(), 1, "{end:?}");
            assert_eq!(end.reports[0].code, Some(code), "{end:?}");
        }
    }
}
#[test]
fn accepting_allows_computation_and_sleep_and_can_be_interrupted() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = source(
            r#"
 bind child <- TaskGroup.spawn(group, lambda()
   bind values <- List.map([1, 2, 3], lambda(x) return x + 1 end lambda)
   Clock.sleep(1)
   Console.writeLine("child")
   return values
 end lambda)
 bind _ <- Http.accept(listener)
 bind _ <- Task.await(child)
 return Result.Ok(())"#,
        );
        let server = Server::start(script, mode);
        let start = Instant::now();
        while !server.stdout.lock().unwrap().ends_with(b"child\n") {
            assert!(start.elapsed() < LIMIT);
            std::thread::sleep(Duration::from_millis(1));
        }
        server.interrupt();
        let end = server.finish();
        assert_eq!(end.end, EndKind::Interrupted, "{end:?}");
    }
}
#[test]
fn closing_listener_wakes_its_waiting_accept() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let server = Server::start(
            source(
                r#"
 bind child <- TaskGroup.spawn(group, lambda()
   Clock.sleep(1)
   return Http.closeListener(listener)
 end lambda)
 bind _ <- Http.accept(listener)
 bind _ <- Task.await(child)
 return Result.Ok(())"#,
            ),
            mode,
        );
        let end = server.finish();
        assert_eq!(end.end, EndKind::Stopped, "{end:?}");
        assert_eq!(end.reports.len(), 1, "{end:?}");
        assert_eq!(
            end.reports[0].code,
            Some(benitoite::diag::DiagCode::R0402),
            "{end:?}"
        );
    }
}
// 実通信が使えない環境でも、統合テストのスクリプトの型とコード生成を検査する。
#[test]
fn integration_scripts_compile() {
    compile(&normal_source());
    for (_, query) in QUERY_CASES {
        compile(&roundtrip_source(query));
    }
    for (action, _) in error_actions() {
        compile(&source(&format!(
            "{EXCHANGE}\n{action}\nreturn Result.Ok(())\nend with"
        )));
    }
    compile(&source(&format!(
        "{EXCHANGE}\nbind _ <- Http.closeExchange(exchange)\nreturn Result.Ok(())\nend with"
    )));
}

#[test]
fn disconnected_exchange_release_does_not_stop_the_program() {
    let script = source(&format!(
        r#"{EXCHANGE}
 Console.writeLine("accepted")
 with gate = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
  return Result.Ok(())
 end with
end with"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let server = Server::start(script.clone(), mode);
        let mut lost = server.connect();
        lost.write_all(b"GET / HTTP/1.1\r\n\r\n").unwrap();
        let start = Instant::now();
        while !server.stdout.lock().unwrap().ends_with(b"accepted\n") {
            assert!(start.elapsed() < LIMIT);
            std::thread::sleep(Duration::from_millis(1));
        }
        lost.shutdown(Shutdown::Both).unwrap();
        drop(lost);
        assert!(
            server
                .request(b"GET /gate HTTP/1.1\r\n\r\n")
                .starts_with(b"HTTP/1.1 500 ")
        );
        returned(server.finish());
    }
}
