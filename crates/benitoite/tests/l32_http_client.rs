//! HTTP クライアントをループバックの実通信で確かめる（実装プラン L32、ADR 0222）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::{InterruptSource, RunInput};
use benitoite::runtime::run::{self, EndKind, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{NetworkFaults, RuntimeParts};
use benitoite::vm::{ExecMode, VmConfig};
use std::io::{Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream};
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
    mpsc,
};
use std::time::{Duration, Instant};

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
const IMPORTS: &str =
    "import Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.IO.Console\n";
fn run_script(body: &str, mode: ExecMode) -> String {
    let program = {
        let checked = pipeline::check_text(
            "l32.bnt",
            format!("{IMPORTS}{body}").as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        pipeline::compile(&core, checked.sources).unwrap()
    };
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let output = Arc::clone(&stdout);
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let errors = Arc::clone(&stderr);
    let (wake_tx, wake_rx) = mpsc::channel();
    let flag = Arc::new(AtomicBool::new(false));
    let interrupted = Arc::clone(&flag);
    let (tx, rx) = mpsc::channel();
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
                stderr: OutputTarget::Capture(errors),
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
    let wakeup = wake_rx.recv_timeout(Duration::from_secs(30)).unwrap();
    let end = rx
        .recv_timeout(Duration::from_secs(30))
        .unwrap_or_else(|error| {
            flag.store(true, Ordering::Relaxed);
            wakeup.wake();
            panic!("HTTP script did not finish: {error}");
        });
    thread.join().unwrap();
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert!(
        end.main_error.is_none() && end.reports.is_empty(),
        "{end:?}"
    );
    assert!(
        stderr.lock().unwrap().is_empty(),
        "{:?}",
        stderr.lock().unwrap()
    );
    String::from_utf8(stdout.lock().unwrap().clone()).unwrap()
}

// 関門: 200/404/500、POST・DELETE の本体・要求のヘッダ、応答のレコードの欄・重複ヘッダ・UTF-8、
// ソースの get/clientRequest を同じスクリプトで守る。L30 の外部クライアントでは
// Http.send の読み書きとワーカからの完了を確かめられない。差し込み口を加えない。
#[test]
fn status_headers_post_and_source_defaults_roundtrip() {
    let source = r#"
function server(listener: Http.Listener, statuses: List[Integer]) -> Result[Unit, String] uses Http.Listen, State
 match statuses with
  case [] -> return Result.Ok(())
  case [status, ..rest] ->
   with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
    bind req <- Http.requestOf(exchange)
    bind body <- if status = 500 then
     if Http.Request.method(req) <> "POST" or Http.header(Http.Request.headers(req), "x-request") <> Option.Some("雪") then
      return Result.Error("request method or header")
     end if
     Http.Request.body(req)
    else String.toUTF8("ok") end if
    bind _ <- try Http.respond(exchange, Http.Response(status: status,
      headers: [Pair("X-A", "1"), Pair("X-B", "2"), Pair("x-a", "3"), Pair("X-Unicode", "雪")], body: body)) |> Result.mapError(_, NetworkError.message)
   end with
   return server(listener, rest)
 end match
end function
function checkResponse(response: Http.Response, status: Integer, body: String) -> Result[Unit, String] uses Console.Write
 bind headers <- Http.Response.headers(response)
 if Http.Response.status(response) <> status or Http.Response.body(response) <> String.toUTF8(body)
  or List.filter(headers, lambda(h) return Pair.first(h) = "x-a" end lambda) <> [Pair("x-a", "1"), Pair("x-a", "3")]
  or Http.header(headers, "x-b") <> Option.Some("2") or Http.header(headers, "x-unicode") <> Option.Some("雪")
  or List.any(headers, lambda(h) return Pair.first(h) <> String.toLowercase(Pair.first(h)) end lambda) then
  return Result.Error("response fields")
 end if
 if status = 200 then
  List.forEach(headers, lambda(h) Console.writeLine(Pair.first(h) + ":" + Pair.second(h)) end lambda)
 end if
 return Result.Ok(())
end function
function main() -> Result[Unit, String] uses Http.Listen, Http.Connect, Console.Write, State
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  bind url <- "http://127.0.0.1:" + Integer.toString(Http.listenerPort(listener)) + "/post"
  bind request <- Http.clientRequest("POST", url)
  if Http.ClientRequest.method(request) <> "POST" or Http.ClientRequest.url(request) <> url
   or Http.ClientRequest.headers(request) <> [] or Http.ClientRequest.body(request) <> Bytes.empty()
   or Http.ClientRequest.timeoutMilliseconds(request) <> 30000 then return Result.Error("clientRequest defaults") end if
  bind task <- TaskGroup.spawn(group, lambda() return server(listener, [200, 404, 500]) end lambda)
  bind first <- try Http.get(url) |> Result.mapError(_, NetworkError.message)
  bind _ <- try checkResponse(first, 200, "ok")
  bind second <- try Http.get(url) |> Result.mapError(_, NetworkError.message)
  bind _ <- try checkResponse(second, 404, "ok")
  bind third <- try Http.send(Http.ClientRequest(..request, headers: [Pair("X-Request", "雪")], body: String.toUTF8("posted"))) |> Result.mapError(_, NetworkError.message)
  bind _ <- try checkResponse(third, 500, "posted")
  return Task.await(task)
 end with
end function
"#;
    for method in ["POST", "DELETE"] {
        let source = source.replace("\"POST\"", &format!("\"{method}\""));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let output = run_script(&source, mode);
            let headers: Vec<_> = output.lines().collect();
            assert!(
                headers.windows(2).any(|pair| pair == ["x-a:1", "x-a:3"]),
                "{output}"
            );
            assert!(headers.contains(&"x-b:2"));
            println!("{method} {mode:?} header order: {headers:?}");
        }
    }
}

// 関門: 実際のクライアントが 10 回まで辿り、11 回目は Other を返す。
// 固定の注入では回数・設定の渡し忘れを捕まえない。各通信の規模は最大 11 要求である。
#[test]
fn redirects_follow_ten_and_return_other_on_eleventh() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for redirects in [10, 11] {
            let source = format!(
                r#"
function server(listener: Http.Listener, url: String, n: Integer) -> Result[Unit,String] uses Http.Listen, State
 if n = 0 then return Result.Ok(()) end if
 with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
  bind status <- if n = 1 and {redirects} = 10 then 200 else 302 end if
  bind _ <- try Http.respond(exchange, Http.Response(status: status, headers: [Pair("location", url)], body: String.toUTF8("ok"))) |> Result.mapError(_, NetworkError.message)
 end with
 return server(listener, url, n - 1)
end function
function main() -> Result[Unit,String] uses Http.Listen, Http.Connect, State
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  bind url <- "http://127.0.0.1:" + Integer.toString(Http.listenerPort(listener)) + "/redirect"
  bind task <- TaskGroup.spawn(group, lambda() return server(listener, url, 11) end lambda)
  bind result <- Http.get(url)
  bind _ <- try Task.await(task)
  return match result with
   case Result.Ok(response) -> if {redirects} = 10 and Http.Response.status(response) = 200 then Result.Ok(()) else Result.Error("redirect count") end if
   case Result.Error(error) -> if {redirects} = 11 and NetworkError.kind(error) = NetworkErrorKind.Other and String.contains(NetworkError.message(error), "redirect") then Result.Ok(()) else Result.Error(NetworkError.message(error)) end if
  end match
 end with
end function
"#
            );
            assert!(run_script(&source, mode).is_empty());
        }
    }
}

// 不正な HTTP は Http.respond では作れないので、この共有のサーバだけを Rust で置く。
// 受信した要求を読み終えてから FIN を送る。未読の本体による RST を再現と取り違えない。
fn raw_server(responses: Vec<Vec<u8>>) -> (u16, std::thread::JoinHandle<Vec<Vec<u8>>>) {
    let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let port = listener.local_addr().unwrap().port();
    listener.set_nonblocking(true).unwrap();
    let thread = std::thread::spawn(move || {
        let mut requests = Vec::new();
        let mut reusable = None;
        for response in responses {
            let start = Instant::now();
            let mut stream = if let Some(stream) = reusable.take() {
                stream
            } else {
                loop {
                    match listener.accept() {
                        Ok((stream, _)) => break stream,
                        Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                            assert!(
                                start.elapsed() < Duration::from_secs(30),
                                "missing HTTP request"
                            );
                            std::thread::sleep(Duration::from_millis(1));
                        }
                        Err(error) => panic!("accept: {error}"),
                    }
                }
            };
            // macOS では待ち受けの非ブロック設定を受理したソケットが引き継ぐ。
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(30)))
                .unwrap();
            stream
                .set_write_timeout(Some(Duration::from_secs(30)))
                .unwrap();
            requests.push(read_wire_request(&mut stream));
            stream.write_all(&response).unwrap();
            if response
                .windows(b"Connection: keep-alive".len())
                .any(|part| part == b"Connection: keep-alive")
            {
                reusable = Some(stream);
            } else {
                stream.shutdown(Shutdown::Write).unwrap();
            }
        }
        requests
    });
    (port, thread)
}

fn read_wire_request(stream: &mut TcpStream) -> Vec<u8> {
    let mut bytes = Vec::new();
    let mut chunk = [0; 4096];
    loop {
        if let Some(header_end) = bytes.windows(4).position(|part| part == b"\r\n\r\n") {
            let header = std::str::from_utf8(bytes.get(..header_end).unwrap()).unwrap();
            let length: usize = header
                .lines()
                .filter_map(|line| line.split_once(':'))
                .find(|(name, _)| name.eq_ignore_ascii_case("content-length"))
                .map(|(_, value)| value.trim().parse().unwrap())
                .unwrap_or(0);
            if bytes.len() >= header_end.saturating_add(4).saturating_add(length) {
                return bytes;
            }
        }
        let read = stream.read(&mut chunk).unwrap();
        assert!(read > 0, "request ended early");
        bytes.extend_from_slice(chunk.get(..read).unwrap());
        assert!(bytes.len() < 65536, "test request too large");
    }
}

fn redirect_client(url: &str, method: &str, body: &str) -> String {
    format!(
        r#"
function main() -> Result[Unit,String] uses Http.Connect, Console.Write
 bind request <- Http.ClientRequest(..Http.clientRequest("{method}", "{url}"),
  headers: [Pair("Authorization", "Bearer secret"), Pair("Cookie", "secret=1"), Pair("X-Custom", "kept")], body: String.toUTF8("{body}"))
 return match Http.send(request) with
  case Result.Ok(response) ->
   Console.writeLine(Integer.toString(Http.Response.status(response)))
   Console.writeLine(Integer.toString(Bytes.length(Http.Response.body(response))))
   Result.Ok(())
  case Result.Error(error) ->
   match NetworkError.kind(error) with
    case NetworkErrorKind.InvalidHTTPData ->
     Console.writeLine("InvalidHTTPData")
     Result.Ok(())
    case NetworkErrorKind.Other ->
     Console.writeLine("Other")
     Result.Ok(())
    case _ -> Result.Error(NetworkError.message(error))
   end match
 end match
end function
"#
    )
}

// 関門: 3xx の本体の欠落は InvalidHTTPData で返り、作業用のスレッドの panic で
// 実行全体が止まらない。既存の Http.respond は不正なチャンクを送れない。
// Location の有無・空でないチャンク・Content-Length の不足を同じ公開の経路で守る。
// 読み捨てる本体の上限を超える Content-Length には Other を返す。
// 1xx を最終応答と取り違えて検査を終える退行も、同じ実通信の境界で捕まえる。
#[test]
fn malformed_and_oversized_redirect_bodies_return_errors() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for informational in [
            "",
            "HTTP/1.1 100 Continue\r\n\r\n",
            "HTTP/1.1 103 Early Hints\r\nLink: </asset>\r\n\r\n",
            "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 103 Early Hints\r\nLink: </asset>\r\n\r\n",
        ] {
            for location in ["Location: /next\r\n", ""] {
                for (framing, body, expected) in [
                    ("Transfer-Encoding: chunked", "0\r\n", "InvalidHTTPData\n"),
                    (
                        "Transfer-Encoding: chunked",
                        "1\r\nx\r\n0\r\n",
                        "InvalidHTTPData\n",
                    ),
                    ("Transfer-Encoding: chunked", "2\r\nx", "InvalidHTTPData\n"),
                    ("Content-Length: 2", "x", "InvalidHTTPData\n"),
                    ("Content-Length: 1073741825", "", "Other\n"),
                ] {
                    let response = format!(
                        "{informational}HTTP/1.1 302 Found\r\n{location}{framing}\r\nConnection: close\r\n\r\n{body}"
                    );
                    let (port, server) = raw_server(vec![response.into_bytes()]);
                    let source =
                        redirect_client(&format!("http://127.0.0.1:{port}/start"), "GET", "");
                    assert_eq!(
                        run_script(&source, mode),
                        expected,
                        "{informational:?} {location} {framing} {body:?}"
                    );
                    assert_eq!(server.join().unwrap().len(), 1);
                }
            }
        }
    }
}

// 関門: 同じ接続の次の応答でも検査を始め直す。別のホストへ移るときも独自の
// ヘッダの扱いを変えない。正常な Location のない 3xx と 304 の従来の区別も守る。
#[test]
fn redirect_connection_reuse_host_change_and_missing_location() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let (port, server) = raw_server(vec![
            b"HTTP/1.1 302 Found\r\nLocation: /next\r\nContent-Length: 2\r\nConnection: keep-alive\r\n\r\nok".to_vec(),
            b"HTTP/1.1 302 Found\r\nLocation: /last\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n0\r\n".to_vec(),
        ]);
        let source = redirect_client(&format!("http://127.0.0.1:{port}/start"), "GET", "");
        assert_eq!(run_script(&source, mode), "InvalidHTTPData\n");
        assert_eq!(server.join().unwrap().len(), 2);

        let (target, target_server) = raw_server(vec![
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".to_vec(),
        ]);
        let (port, server) = raw_server(vec![format!("HTTP/1.1 302 Found\r\nLocation: http://localhost:{target}/next\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").into_bytes()]);
        let source = redirect_client(&format!("http://127.0.0.1:{port}/start"), "GET", "");
        assert_eq!(run_script(&source, mode), "200\n2\n");
        assert_eq!(server.join().unwrap().len(), 1);
        let requests = target_server.join().unwrap();
        let request = String::from_utf8(requests.first().unwrap().clone())
            .unwrap()
            .to_ascii_lowercase();
        assert!(!request.contains("authorization:"), "{request}");
        assert!(!request.contains("cookie:"), "{request}");
        assert!(request.contains("x-custom: kept\r\n"), "{request}");

        for (status, expected) in [(302, "InvalidHTTPData\n"), (304, "304\n0\n")] {
            let (port, server) = raw_server(vec![
                format!(
                    "HTTP/1.1 {status} Response\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                )
                .into_bytes(),
            ]);
            let source = redirect_client(&format!("http://127.0.0.1:{port}/start"), "GET", "");
            assert_eq!(run_script(&source, mode), expected);
            assert_eq!(server.join().unwrap().len(), 1);
        }
    }
}

// 関門: 301/302/303 の方法の変更、307/308 の再送の拒否、相対 URL、秘密のヘッダの
// 除去と独自のヘッダの保持を守る。既存の回数のテストは GET の同じ URL だけである。
// 本体が正常なチャンク・トレーラ・HEAD の場合も、終端の検査で誤って拒まない。
#[test]
fn redirect_methods_relative_locations_and_headers_are_preserved() {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for status in [301, 302, 303, 307, 308] {
            for method in ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"] {
                let rejected = matches!(status, 307 | 308)
                    && matches!(method, "POST" | "PUT" | "PATCH" | "DELETE");
                let body = if matches!(method, "POST" | "PUT" | "PATCH" | "DELETE") {
                    "posted"
                } else {
                    ""
                };
                let mut responses = vec![format!("HTTP/1.1 {status} Redirect\r\nLocation: ../next?q=1\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n{}",
                    if method == "HEAD" { "" } else { "2\r\nok\r\n0\r\nX-Trailer: yes\r\n\r\n" }).into_bytes()];
                if !rejected {
                    responses.push(
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}",
                            if method == "HEAD" { "" } else { "ok" }
                        )
                        .into_bytes(),
                    );
                }
                let (port, server) = raw_server(responses);
                let source =
                    redirect_client(&format!("http://127.0.0.1:{port}/dir/start"), method, body);
                let expected = if rejected {
                    "Other\n"
                } else if method == "HEAD" {
                    "200\n0\n"
                } else {
                    "200\n2\n"
                };
                assert_eq!(run_script(&source, mode), expected, "{status} {method}");
                let requests = server.join().unwrap();
                let first = String::from_utf8(requests.first().unwrap().clone()).unwrap();
                assert!(
                    first.starts_with(&format!("{method} /dir/start HTTP/1.1\r\n")),
                    "{first}"
                );
                assert!(
                    first
                        .to_ascii_lowercase()
                        .contains("authorization: bearer secret\r\n")
                );
                assert!(first.to_ascii_lowercase().contains("cookie: secret=1\r\n"));
                assert!(first.ends_with(body));
                if !rejected {
                    let redirected = String::from_utf8(requests.get(1).unwrap().clone()).unwrap();
                    let new_method = if method == "HEAD" { "HEAD" } else { "GET" };
                    assert!(
                        redirected.starts_with(&format!("{new_method} /next?q=1 HTTP/1.1\r\n")),
                        "{redirected}"
                    );
                    let headers = redirected.to_ascii_lowercase();
                    assert!(!headers.contains("authorization:"), "{redirected}");
                    assert!(!headers.contains("cookie:"), "{redirected}");
                    assert!(headers.contains("x-custom: kept\r\n"), "{redirected}");
                    assert!(!headers.contains("content-length:"), "{redirected}");
                    assert!(redirected.ends_with("\r\n\r\n"), "{redirected}");
                }
            }
        }
    }
}

// 関門: 要求の側の誤りを応答の解析の誤りと取り違えない。既存の正常な GET・POST は
// この分類を通らない。送信前の検査で返るので、外部の DNS とサーバを必要としない。
#[test]
fn invalid_request_body_and_methods_return_invalid_input() {
    let source = r#"
function main() -> Result[Unit,String] uses Http.Connect
 bind requests <- [
  Http.ClientRequest(..Http.clientRequest("GET", "http://127.0.0.1:1/"), body: String.toUTF8("body")),
  Http.ClientRequest(..Http.clientRequest("HEAD", "http://127.0.0.1:1/"), body: String.toUTF8("body")),
  Http.ClientRequest(..Http.clientRequest("GET", "http://127.0.0.1:1/"), headers: [Pair("Content-Length", "0")], body: String.toUTF8("body")),
  Http.ClientRequest(..Http.clientRequest("POST", "http://127.0.0.1:1/"), headers: [Pair("Content-Length", "bad")]),
  Http.ClientRequest(..Http.clientRequest("GET", "http://127.0.0.1:1/"), headers: [Pair("Host", "one"), Pair("Host", "two")]),
  Http.clientRequest("PURGE", "http://127.0.0.1:1/"),
  Http.clientRequest("get", "http://127.0.0.1:1/")]
 return List.fold(requests, Result.Ok(()), lambda(result, request)
  bind _ <- try result
  return match Http.send(request) with
   case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.InvalidInput then Result.Ok(()) else Result.Error(NetworkError.message(error)) end if
   case Result.Ok(_) -> Result.Error("invalid request succeeded")
  end match
 end lambda)
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        assert!(run_script(source, mode).is_empty());
    }
}

// 関門: timeoutMilliseconds が本物のクライアントへ渡る契約。時間切れを渡さない退行では
// クライアントが応答を待ち続け、上限の 30 秒でテストが失敗する。実時間の 100 ms は ADR 0330
// の例外。サーバは要求を受け付けず応答もしないので、時間切れが接続・送信・応答の待ちの
// どの段で起きても TimedOut になり、結果がスレッドの速さによらない（FLNX。受け付けて
// から応答する形では、遅い環境で要求の前に時間切れになると Http.accept が次の要求を
// 待ち続けた。接続は待ち受けの backlog に留まり、待ち受けを閉じるときに OS が閉じる）。
#[test]
fn real_timeout_returns_timed_out_without_server_response() {
    let source = r#"
function main() -> Result[Unit,String] uses Http.Listen, Http.Connect, State
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  bind url <- "http://127.0.0.1:" + Integer.toString(Http.listenerPort(listener)) + "/timeout"
  bind task <- TaskGroup.spawn(group, lambda()
   return Http.send(Http.ClientRequest(..Http.clientRequest("GET", url), timeoutMilliseconds: 100))
  end lambda)
  return match Task.await(task) with
   case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.TimedOut then Result.Ok(()) else Result.Error(NetworkError.message(error)) end if
   case Result.Ok(_) -> Result.Error("missing timeout")
  end match
 end with
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        assert!(run_script(source, mode).is_empty());
    }
}

// 関門: 閉じたポートの実際の Io(ConnectionRefused) の分類。失敗の注入はこの変換を通らない。
// ポート番号はスクリプト自身が開いて閉じた待ち受けから得る。
#[test]
fn closed_listener_port_returns_connection_refused() {
    let source = r#"
function main() -> Result[Unit,String] uses Http.Listen, Http.Connect, State
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message) do
  bind port <- Http.listenerPort(listener)
  bind _ <- try Http.closeListener(listener) |> Result.mapError(_, NetworkError.message)
  return match Http.get("http://127.0.0.1:" + Integer.toString(port) + "/") with
   case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.ConnectionRefused then Result.Ok(()) else Result.Error(NetworkError.message(error)) end if
   case Result.Ok(_) -> Result.Error("closed port connected")
  end match
 end with
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        assert!(run_script(source, mode).is_empty());
    }
}
