//! 読まない相手との実通信で Exchange の解放と CLI の停止を確かめる（SECB2）。
#![cfg(unix)]
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]

use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::{Child, Command, ExitStatus, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

// 3 秒の解放の期限を十分に上回る、停止の検出だけの上限。
const LIMIT: Duration = Duration::from_secs(30);
const CLIENTS: usize = 64;
const IMPORTS: &str = r#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Clock
"#;
// 64 MiB の応答を使い、受信バッファを OS 固有の API で縮めずに送信を待たせる。
const CANCEL: &str = r#"
function serve(listener: Http.Listener, group: TaskGroup, body: String, count: Integer) -> Result[Unit, String] uses Http.Listen, Console.Read, Console.Write, File.Read, Clock.Time, State
 if count = 0 then
  with gate = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
   bind text <- try File.readText("input.txt") |> Result.mapError(_, IOError.message)
   Console.writeLine(text)
   return Result.Ok(())
  end with
 end if
 bind exchange <- try Http.accept(listener) |> Result.mapError(_, NetworkError.message)
 bind _ <- TaskGroup.spawn(group, lambda()
  with current = exchange do
   bind winner <- Task.race([
    lambda()
     bind _ <- Http.respond(current, Http.text(200, body))
     return "responded"
    end lambda,
    lambda()
     bind _ <- Console.readLine()
     return "cancelled"
    end lambda
   ])
   Console.writeLine(Option.unwrapOr(winner, "empty"))
  end with
  Console.writeLine("released")
 end lambda)
 return serve(listener, group, body, count - 1)
end function
function main() -> Result[Unit, String] uses Http.Listen, Console.Read, Console.Write, File.Read, Clock.Time, State
 bind body <- String.repeat("x", 67108864)
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  Console.writeLine(Integer.toString(Http.listenerPort(listener)))
  return serve(listener, group, body, 64)
 end with
end function
"#;
const STOP: &str = r#"
function main() -> Result[Unit, String] uses Http.Listen, Console.Read, Console.Write, State
 bind body <- String.repeat("x", 67108864)
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  Console.writeLine(Integer.toString(Http.listenerPort(listener)))
  with current = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
   bind _ <- TaskGroup.spawn(group, lambda() return Http.respond(current, Http.text(200, body)) end lambda)
   bind _ <- Console.readLine()
   bind _ <- Http.respond(current, Http.text(700, "invalid status"))
   return Result.Ok(())
  end with
 end with
end function
"#;

struct Directory(PathBuf);
impl Directory {
    fn new(mode: &str, scenario: &str) -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!(
            "../../target/secb2-http-{}-{mode}-{scenario}-{stamp}",
            std::process::id()
        ));
        fs::create_dir(&path).unwrap();
        Self(path.canonicalize().unwrap())
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        drop(fs::remove_dir_all(&self.0));
    }
}

struct Server {
    child: Child,
    stdout: Receiver<String>,
    stderr: Receiver<String>,
    readers: Vec<thread::JoinHandle<()>>,
    observed: Vec<String>,
    port: u16,
    _directory: Directory,
}
impl Server {
    fn start(mode: &str, scenario: &str) -> Self {
        let directory = Directory::new(mode, scenario);
        fs::write(directory.0.join("input.txt"), "file-ok").unwrap();
        let script = directory.0.join("server.bnt");
        let body = if scenario == "cancel" { CANCEL } else { STOP };
        fs::write(&script, format!("{IMPORTS}{body}")).unwrap();
        let child = Command::new(env!("CARGO_BIN_EXE_benitoite"))
            .arg("run")
            .arg(script)
            .current_dir(&directory.0)
            .env("BENITOITE_DEV_IO_MODE", mode)
            .env_remove("BENITOITE_DEV_PANIC")
            .env_remove("BENITOITE_DEV_ALLOC_STATS")
            .env("NO_COLOR", "1")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let (stdout_tx, stdout) = mpsc::channel();
        let (stderr_tx, stderr) = mpsc::channel();
        // 準備中の失敗でも子を回収できるよう、spawn の直後にガードを作る。
        let mut server = Self {
            child,
            stdout,
            stderr,
            readers: Vec::new(),
            observed: Vec::new(),
            port: 0,
            _directory: directory,
        };
        let out = server.child.stdout.take().unwrap();
        server.readers.push(thread::spawn(move || {
            for line in BufReader::new(out).lines() {
                if stdout_tx.send(line.unwrap()).is_err() {
                    break;
                }
            }
        }));
        let mut err = server.child.stderr.take().unwrap();
        server.readers.push(thread::spawn(move || {
            let mut report = String::new();
            err.read_to_string(&mut report).unwrap();
            drop(stderr_tx.send(report));
        }));
        let line = server.stdout.recv_timeout(LIMIT).unwrap();
        server.port = line.parse().unwrap();
        assert_ne!(server.port, 0);
        server
    }
    fn request(&self, path: &str) -> TcpStream {
        let mut stream =
            TcpStream::connect_timeout(&([127, 0, 0, 1], self.port).into(), LIMIT).unwrap();
        stream.set_read_timeout(Some(LIMIT)).unwrap();
        stream.set_write_timeout(Some(LIMIT)).unwrap();
        write!(stream, "GET {path} HTTP/1.1\r\nHost: localhost\r\n\r\n").unwrap();
        stream
    }
    fn input(&mut self, line: &[u8]) {
        let stdin = self.child.stdin.as_mut().unwrap();
        stdin.write_all(line).unwrap();
        stdin.flush().unwrap();
    }
    fn wait_line(&mut self, expected: &str) {
        let started = Instant::now();
        loop {
            let line = self
                .stdout
                .recv_timeout(LIMIT.saturating_sub(started.elapsed()))
                .unwrap();
            // 大きな応答が完送された場合は、送信待ちの退行を検査できていない。
            assert!(
                line == "cancelled" || line == "released" || line == "file-ok",
                "unexpected output: {line}; observed={:?}",
                self.observed
            );
            let matched = line == expected;
            // 先に届いた released も数え、解放との順序を実時間の待ちで仮定しない。
            self.observed.push(line);
            if matched {
                return;
            }
        }
    }
    fn interrupt(&self) {
        // 既存の CLI のシグナルテストと同じく、kill で子に SIGINT を一度だけ送る。
        let sent = Command::new("kill")
            .args(["-INT", &self.child.id().to_string()])
            .output()
            .unwrap();
        assert!(sent.status.success(), "kill failed: {sent:?}");
    }
    fn finish(&mut self) -> (ExitStatus, String) {
        let started = Instant::now();
        let status = loop {
            if let Some(status) = self.child.try_wait().unwrap() {
                break status;
            }
            assert!(
                started.elapsed() < LIMIT,
                "server did not finish; observed={:?}",
                self.observed
            );
            thread::sleep(Duration::from_millis(2));
        };
        for reader in self.readers.drain(..) {
            reader.join().unwrap();
        }
        self.observed.extend(self.stdout.try_iter());
        (status, self.stderr.recv_timeout(LIMIT).unwrap())
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        drop(self.child.kill());
        drop(self.child.wait());
        for reader in self.readers.drain(..) {
            drop(reader.join());
        }
    }
}

// 関門: 部分応答を受信してから取り消し・停止を起こす。既存の小さい応答の
// テストでは、送信が WouldBlock になる経路と作業用スレッドの枯渇を通らない。
// 実ソケットと CLI の入出力だけを使い、本番の差し込み口は加えない。
fn scenario(name: &str) {
    for mode in ["direct", "request"] {
        let mut server = Server::start(mode, name);
        let mut sockets = Vec::new();
        let count = if name == "cancel" { CLIENTS } else { 1 };
        for _ in 0..count {
            let mut stream = server.request("/big");
            let mut first = [0];
            // 書き込みが始まったことを確認し、以後は読み取らない。
            stream.read_exact(&mut first).unwrap();
            assert_eq!(first, [b'H'], "{mode}/{name}: partial response missing");
            sockets.push(stream);
            if name == "cancel" {
                server.input(b"cancel\n");
                server.wait_line("cancelled");
            }
        }
        if name == "cancel" {
            sockets.push(server.request("/gate"));
            server.wait_line("file-ok");
        } else if name == "error" {
            server.input(b"fail\n");
        } else {
            server.interrupt();
        }
        // 相手の接続を閉じずに終了を待つ。閉じると旧実装でも解放が終わってしまう。
        let (status, stderr) = server.finish();
        if name == "cancel" {
            assert!(status.success(), "{mode}/{name}: {status:?}: {stderr}");
            for expected in ["cancelled", "released"] {
                assert_eq!(
                    server.observed.iter().filter(|s| *s == expected).count(),
                    CLIENTS,
                    "{mode}/{name}: {:?}",
                    server.observed
                );
            }
            assert!(stderr.is_empty(), "{mode}/{name}: {stderr}");
        } else if name == "error" {
            assert_eq!(status.code(), Some(1), "{mode}/{name}: {stderr}");
            assert!(stderr.contains("R0701"), "{mode}/{name}: {stderr}");
        } else {
            assert_eq!(status.code(), Some(130), "{mode}/{name}: {stderr}");
            assert!(stderr.is_empty(), "{mode}/{name}: {stderr}");
        }
        drop(sockets);
    }
}

#[test]
fn cancelled_responses_release_and_leave_file_workers_available() {
    scenario("cancel");
}

#[test]
fn runtime_error_after_partial_response_finishes() {
    scenario("error");
}

#[test]
fn one_sigint_after_partial_response_finishes() {
    scenario("interrupt");
}
