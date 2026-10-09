//! HTTP のソースの関数を公開パイプラインと実通信で確かめる（設計書 03-09、実装プラン L31）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

// 関門: L30 の接続のテストでは届かない、ソースの応答・経路・要求ごとの
// タスク起動・引き継いだハンドラの契約を守る。逐次処理への退行と、ソースの
// フィールドやエフェクトの接続の誤りを捕まえる。本番の差し込み口は加えない。
use benitoite::bytecode::program::CompiledProgram;
use benitoite::diag::DiagCode;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::services::{InterruptSource, RunInput};
use benitoite::runtime::run::{self, EndKind, OutputTarget, RunEnd, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{NetworkFaults, RuntimeParts};
use benitoite::vm::{ExecMode, VmConfig};
use std::io::{ErrorKind, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
    mpsc,
};
use std::time::{Duration, Instant};

const LIMIT: Duration = Duration::from_secs(30);
const IMPORTS: &str = "import Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.Json\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Clock\n";

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

fn compile(source: &str) -> CompiledProgram {
    let checked = pipeline::check_text(
        "l31.bnt",
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
    flag: Arc<AtomicBool>,
    wakeup: Wakeup,
    result: mpsc::Receiver<RunEnd>,
    stdout: Arc<Mutex<Vec<u8>>>,
    thread: Option<std::thread::JoinHandle<()>>,
}
impl Server {
    fn start(source: &str, mode: ExecMode) -> Self {
        let program = compile(source);
        let stdout = Arc::new(Mutex::new(Vec::new()));
        let output = Arc::clone(&stdout);
        let flag = Arc::new(AtomicBool::new(false));
        let interrupted = Arc::clone(&flag);
        let (wake_tx, wake_rx) = mpsc::channel();
        let (tx, result) = mpsc::channel();
        let thread = std::thread::spawn(move || {
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
                    heap: HeapConfig::default(),
                    dev_panic_after_first_write: false,
                },
            );
            drop(tx.send(end));
        });
        Self {
            flag,
            wakeup: wake_rx.recv_timeout(LIMIT).unwrap(),
            result,
            stdout,
            thread: Some(thread),
        }
    }

    fn wait_line(&self, expected: Option<&str>) -> String {
        let start = Instant::now();
        loop {
            let bytes = self.stdout.lock().unwrap().clone();
            for line in bytes
                .split(|b| *b == b'\n')
                .take(bytes.iter().filter(|b| **b == b'\n').count())
            {
                let line = std::str::from_utf8(line).unwrap();
                if expected.is_none_or(|expected| line == expected) {
                    return line.to_owned();
                }
            }
            if let Ok(end) = self.result.try_recv() {
                panic!("server ended before publishing output: {end:?}");
            }
            assert!(start.elapsed() < LIMIT, "output timeout: {expected:?}");
            std::thread::sleep(Duration::from_millis(1));
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
        // アサーションの失敗でも、待ち受けと子のタスクを取り消す（L30 と同じ起こし口）。
        self.flag.store(true, Ordering::Relaxed);
        self.wakeup.wake();
    }
}

fn connect(port: u16) -> TcpStream {
    let start = Instant::now();
    loop {
        match TcpStream::connect(("127.0.0.1", port)) {
            Ok(socket) => {
                socket.set_read_timeout(Some(LIMIT)).unwrap();
                socket.set_write_timeout(Some(LIMIT)).unwrap();
                return socket;
            }
            Err(error)
                if error.kind() == ErrorKind::ConnectionRefused && start.elapsed() < LIMIT =>
            {
                std::thread::sleep(Duration::from_millis(1));
            }
            Err(error) => panic!("connect to {port}: {error}"),
        }
    }
}

fn send(port: u16, path: &str) -> TcpStream {
    let mut socket = connect(port);
    socket
        .write_all(format!("GET {path} HTTP/1.1\r\nHost: localhost\r\n\r\n").as_bytes())
        .unwrap();
    socket
}

fn response(mut socket: TcpStream, status: u16, content_type: &str, body: &str) {
    let mut bytes = Vec::new();
    socket.read_to_end(&mut bytes).unwrap();
    let text = std::str::from_utf8(&bytes).unwrap();
    let (head, actual_body) = text.split_once("\r\n\r\n").unwrap();
    assert!(head.starts_with(&format!("HTTP/1.1 {status} ")), "{text}");
    assert!(
        head.split("\r\n")
            .any(|line| line == format!("content-type: {content_type}")),
        "{text}"
    );
    assert_eq!(actual_body, body);
}

fn returned(end: RunEnd) {
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert_eq!(end.exit_code, 0, "{end:?}");
    assert!(end.main_error.is_none(), "{end:?}");
    assert!(end.reports.is_empty(), "{end:?}");
}

fn stop(server: Server, port: u16) {
    // 印を読んだ相手のタスクは、/stop の応答の完了を待たずに serve を取り消せる。
    // 終了用の要求は送り、Task.race と解放が正常に終わったことを確かめる（実装プラン L31）。
    let _socket = send(port, "/stop");
    returned(server.finish());
}

// 空いたポートの予約は Http.serve の開始前に外す（実装プラン L31）。
fn vacant_port() -> u16 {
    TcpListener::bind(("127.0.0.1", 0))
        .unwrap()
        .local_addr()
        .unwrap()
        .port()
}

const ROUTE: &str = r#"
function route(request: Http.Request) -> Http.Response
  bind segments <- Http.pathSegments(Http.Request.path(request))
  return match Pair(Http.Request.method(request), segments) with
    case Pair("GET", []) -> Http.html(200, "<h1>Hello</h1>")
    case Pair("GET", ["items", id]) -> Http.json(200, Json.Value.Object(Map.fromList([Pair("id", Json.Value.String(id))])))
    case Pair("GET", ["headers"]) ->
      if Http.header([Pair("X-MiXeD", "first"), Pair("x-mixed", "second")], "x-MIXED") = Option.Some("first")
        and Http.header([], "missing") = Option.None
        and Http.header([Pair("other", "value")], "missing") = Option.None then
        Http.text(200, "headers ok")
      else Http.text(500, "headers wrong") end if
    case _ -> Http.text(404, "not found")
  end match
end function

function waitStop(stopped: Reference[Boolean]) -> Result[Unit, NetworkError] uses Clock.Time, State
  if Reference.get(stopped) then return Result.Ok(()) end if
  Clock.sleep(1)
  return waitStop(stopped)
end function
"#;

const LISTEN_LOOP: &str = r#"
function listenLoop(listener: Http.Listener, group: TaskGroup, handler: function(Http.Request) -> Http.Response uses State) -> Result[Unit, NetworkError] uses Http.Listen, State
  bind exchange <- try Http.accept(listener)
  bind _ <- TaskGroup.spawn(group, lambda()
    with current = exchange do
      return Http.respond(current, handler(Http.requestOf(current)))
    end with
  end lambda)
  return listenLoop(listener, group, handler)
end function
"#;

fn main_source(extra: &str, body: &str) -> String {
    format!(
        "{IMPORTS}{ROUTE}{extra}\nfunction main() -> Result[Unit, String] uses Http.Listen, Console.Write, Clock.Time, State\n{body}\nend function\n"
    )
}

fn route_source(port: Option<u16>) -> String {
    let handler = r#"lambda(request)
      if Http.Request.method(request) = "GET" and Http.Request.path(request) = "/stop" then
        Reference.set(stopped, true)
        return Http.text(200, "stopped")
      end if
      return route(request)
    end lambda"#;
    let race = |action: &str| {
        format!(
            r#"
      bind winner <- Task.race([
        lambda() return {action} end lambda,
        lambda() return waitStop(stopped) end lambda])
      return match winner with
        case Option.Some(result) -> Result.mapError(result, NetworkError.message)
        case Option.None -> Result.Error("race had no result")
      end match"#
        )
    };
    match port {
        Some(port) => main_source(
            "",
            &format!(
                "bind stopped <- Reference.new(false)\nbind handler <- {handler}\n{}",
                race(&format!("Http.serve(\"127.0.0.1\", {port}, handler)"))
            ),
        ),
        None => main_source(
            LISTEN_LOOP,
            &format!(
                r#"
            bind stopped <- Reference.new(false)
            bind handler <- {handler}
            with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
              Console.writeLine(Integer.toString(Http.listenerPort(listener)))
              {}
            end with"#,
                race("listenLoop(listener, group, handler)")
            ),
        ),
    }
}

#[test]
fn route_and_helpers_work_with_listen_and_serve_in_both_modes() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for use_serve in [false, true] {
            let selected = use_serve.then(vacant_port);
            let server = Server::start(&route_source(selected), mode);
            let port = selected.unwrap_or_else(|| server.wait_line(None).parse().unwrap());
            for (path, status, content_type, body) in [
                ("/", 200, "text/html; charset=utf-8", "<h1>Hello</h1>"),
                ("/items/1", 200, "application/json", "{\"id\":\"1\"}"),
                ("/missing", 404, "text/plain; charset=utf-8", "not found"),
                ("/headers", 200, "text/plain; charset=utf-8", "headers ok"),
            ] {
                response(send(port, path), status, content_type, body);
            }
            stop(server, port);
        }
    }
}

#[test]
fn serve_responds_to_all_simultaneous_requests() {
    // 4 要求で所要時間を確かめてから増やした。回収の強制では要求数を抑える（依頼の補足）。
    let count = if cfg!(feature = "gc-stress") { 8 } else { 32 };
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let port = vacant_port();
        let server = Server::start(&route_source(Some(port)), mode);
        let sockets = (0..count)
            .map(|_| send(port, "/items/1"))
            .collect::<Vec<_>>();
        for socket in sockets {
            response(socket, 200, "application/json", "{\"id\":\"1\"}");
        }
        stop(server, port);
    }
}

fn computation_source(port: u16, limit: u32) -> String {
    main_source(
        r#"
function spin(mark: Reference[Boolean], remaining: Integer) -> Http.Response uses State
  if Reference.get(mark) then return Http.text(200, "released") end if
  if remaining = 0 then return Http.text(500, "iteration limit") end if
  return spin(mark, remaining - 1)
end function
"#,
        &format!(
            r#"
    bind stopped <- Reference.new(false)
    bind mark <- Reference.new(false)
    bind handler <- lambda(request)
      return match Http.Request.path(request) with
        case "/spin" ->
          Console.writeLine("spinning")
          spin(mark, {limit})
        case "/release" ->
          Reference.set(mark, true)
          Http.text(200, "release")
        case "/stop" ->
          Reference.set(stopped, true)
          Http.text(200, "stopped")
        case _ -> route(request)
      end match
    end lambda
    bind winner <- Task.race([
      lambda() return Http.serve("127.0.0.1", {port}, handler) end lambda,
      lambda() return waitStop(stopped) end lambda])
    return match winner with
      case Option.Some(result) -> Result.mapError(result, NetworkError.message)
      case Option.None -> Result.Error("race had no result")
    end match"#
        ),
    )
}

#[test]
fn computing_handler_allows_another_request_to_run() {
    // 上限は、ソケットの読み取りの時間切れ（LIMIT）を確実に超える回数にする。印が立てばすぐに終わるので、
    // 正常な場合の所要時間は変わらない。小さいと、負荷の高いときに B が届く前に A が上限に達して落ちる。
    // 要求ごとにタスクを起動しない退行では、B の応答の読み取りが LIMIT で時間切れになって失敗する。
    let limit = 1_000_000_000;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let port = vacant_port();
        let server = Server::start(&computation_source(port, limit), mode);
        let waiting = send(port, "/spin");
        server.wait_line(Some("spinning"));
        response(
            send(port, "/release"),
            200,
            "text/plain; charset=utf-8",
            "release",
        );
        response(waiting, 200, "text/plain; charset=utf-8", "released");
        stop(server, port);
    }
}

fn error_source(port: u16, handler: &str, clause: Option<&str>) -> String {
    let serve = format!("Http.serve(\"127.0.0.1\", {port}, {handler})");
    let action = match clause {
        Some(clause) => format!("handle\n{serve}\nwith\ncase answer() ->\n{clause}\nend handle"),
        None => serve,
    };
    main_source(
        "effect Answer\nfunction answer() -> String\nend effect\n",
        &format!("return {action} |> Result.mapError(_, NetworkError.message)"),
    )
}

#[test]
fn handler_runtime_error_and_non_tail_inherited_clause_stop_every_task() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for (handler, clause, code) in [
            (
                "lambda(request) return Http.text(200, Integer.toString(1 div 0)) end lambda",
                None,
                DiagCode::R0101,
            ),
            (
                "lambda(request) return Http.text(200, answer()) end lambda",
                Some("bind _ <- resume(\"bad\")\nResult.Ok(())"),
                DiagCode::R0502,
            ),
        ] {
            let port = vacant_port();
            let server = Server::start(&error_source(port, handler, clause), mode);
            // クライアントの応答・切断の時機を期待に含めない（実装プラン L31）。
            let _socket = send(port, "/");
            let end = server.finish();
            assert_eq!(end.end, EndKind::Stopped, "{end:?}");
            assert_eq!(end.reports.len(), 1, "{end:?}");
            assert_eq!(end.reports[0].code, Some(code), "{end:?}");
        }
    }
}

#[test]
fn serve_inherits_tail_resuming_handler() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let port = vacant_port();
        let base = route_source(Some(port));
        let source = base.replace("return route(request)", "return Http.text(200, answer())")
            .replace("function main()", "effect Answer\nfunction answer() -> String\nend effect\nfunction main()")
            .replace("bind winner <- Task.race([", "bind winner <- handle\nTask.race([")
            .replace("lambda() return waitStop(stopped) end lambda])", "lambda() return waitStop(stopped) end lambda])\nwith\ncase answer() -> resume(\"inherited\")\nend handle");
        let server = Server::start(&source, mode);
        response(
            send(port, "/"),
            200,
            "text/plain; charset=utf-8",
            "inherited",
        );
        stop(server, port);
    }
}

#[test]
fn serve_returns_network_error_when_port_is_in_use() {
    let occupied = TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let port = occupied.local_addr().unwrap().port();
    let source = main_source(
        "",
        &format!(
            r#"
        return match Http.serve("127.0.0.1", {port}, route) with
          case Result.Error(error) ->
            if NetworkError.kind(error) = NetworkErrorKind.AddressInUse then Result.Ok(())
            else Result.Error(NetworkError.message(error)) end if
          case Result.Ok(_) -> Result.Error("unexpected listen success")
        end match"#
        ),
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        returned(Server::start(&source, mode).finish());
    }
}
