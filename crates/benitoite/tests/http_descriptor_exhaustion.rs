//! 記述子の上限を実際に使い切り、HTTP サーバの継続と復帰を確かめる（03-09「失敗の種類」、SECB1）。
#![cfg(unix)]
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]

use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const ACCEPT_RETRY_REPORT: &str = "HTTP accept temporarily failed; retrying: ";
const LIMIT: Duration = Duration::from_secs(30);
const FD_LIMIT: usize = 96;
const CAPACITY_CONNECTIONS: usize = 60;
const PRESSURE_CONNECTIONS: usize = 128;
const SOURCE: &str = r#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Console
function one(listener: Http.Listener) -> Result[Boolean, String] uses Http.Listen, State
 with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
  bind done <- Http.Request.path(Http.requestOf(exchange)) = "/done"
  bind _ <- try Http.respond(exchange, Http.Response(status: 200, headers: [], body: String.toUTF8("ok"))) |> Result.mapError(_, NetworkError.message)
  return Result.Ok(done)
 end with
end function
function serve(listener: Http.Listener) -> Result[Unit, String] uses Http.Listen, State
 bind done <- try one(listener)
 if done then return Result.Ok(()) end if
 return serve(listener)
end function
function main() -> Result[Unit, String] uses Http.Listen, Console.Write, State
 with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message) do
  Console.writeLine(Integer.toString(Http.listenerPort(listener)))
  return serve(listener)
 end with
end function
"#;

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!(
            "../../target/secb1-http-{}-{stamp}",
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
    stderr: Receiver<String>,
    readers: Vec<thread::JoinHandle<()>>,
    port: u16,
    _directory: Directory,
}
impl Server {
    fn start(mode: &str) -> Self {
        let directory = Directory::new();
        let script = directory.0.join("server.bnt");
        fs::write(&script, SOURCE).unwrap();
        // 引数でパスを渡し、シェルによる展開を避ける。上限を変えるのは子だけである。
        let child = Command::new("sh")
            .args([
                "-c",
                "ulimit -n \"$1\" && exec \"$2\" run \"$3\"",
                "secb1-http",
            ])
            .arg(FD_LIMIT.to_string())
            .arg(env!("CARGO_BIN_EXE_benitoite"))
            .arg(script)
            .env("BENITOITE_DEV_IO_MODE", mode)
            .env_remove("BENITOITE_DEV_PANIC")
            .env_remove("BENITOITE_DEV_ALLOC_STATS")
            .env("NO_COLOR", "1")
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let (ready_tx, ready) = mpsc::channel();
        let (stderr_tx, stderr) = mpsc::channel();
        // 準備中の失敗でも子を回収できるよう、spawn の直後にガードを作る。
        let mut server = Self {
            child,
            stderr,
            readers: Vec::new(),
            port: 0,
            _directory: directory,
        };
        let stdout = server.child.stdout.take().unwrap();
        server.readers.push(thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            let mut line = String::new();
            let read = reader.read_line(&mut line);
            drop(ready_tx.send((read, line)));
            // 子が終了するまでパイプを保つ。
            drop(reader.read_to_end(&mut Vec::new()));
        }));
        let err = server.child.stderr.take().unwrap();
        server.readers.push(thread::spawn(move || {
            for line in BufReader::new(err).lines() {
                if stderr_tx.send(line.unwrap()).is_err() {
                    break;
                }
            }
        }));
        let (read, line) = ready.recv_timeout(LIMIT).unwrap();
        assert!(
            read.unwrap() > 0,
            "server ended before readiness: {:?}",
            server.stderr.try_iter().collect::<Vec<_>>()
        );
        server.port = line.trim().parse().unwrap();
        assert_ne!(server.port, 0);
        server
    }
    fn assert_running(&mut self) {
        assert!(
            self.child.try_wait().unwrap().is_none(),
            "server stopped: {:?}",
            self.stderr.try_iter().collect::<Vec<_>>()
        );
    }
    fn connect(&self) -> TcpStream {
        let stream =
            TcpStream::connect_timeout(&([127, 0, 0, 1], self.port).into(), LIMIT).unwrap();
        stream.set_read_timeout(Some(LIMIT)).unwrap();
        stream.set_write_timeout(Some(LIMIT)).unwrap();
        stream
    }
    fn request(&mut self, path: &str) {
        self.assert_running();
        let mut stream = self.connect();
        write!(stream, "GET {path} HTTP/1.1\r\nHost: localhost\r\n\r\n").unwrap();
        let mut response = Vec::new();
        stream.read_to_end(&mut response).unwrap();
        assert_eq!(
            response,
            b"HTTP/1.1 200 OK\r\ncontent-length: 2\r\nconnection: close\r\n\r\nok"
        );
    }
    fn wait_for_shortage(&mut self) {
        let line = self.stderr.recv_timeout(LIMIT).unwrap();
        assert!(
            line.starts_with(ACCEPT_RETRY_REPORT),
            "unexpected report: {line}"
        );
        self.assert_running();
    }
    fn finish(&mut self) {
        let started = Instant::now();
        let status = loop {
            if let Some(status) = self.child.try_wait().unwrap() {
                break status;
            }
            assert!(started.elapsed() < LIMIT, "server did not finish");
            thread::sleep(Duration::from_millis(2));
        };
        for reader in self.readers.drain(..) {
            reader.join().unwrap();
        }
        let reports: Vec<_> = self.stderr.try_iter().collect();
        assert!(status.success(), "{status:?}: {reports:?}");
        // クライアント側の close と、サーバ側での切断済みの接続の回収は同期しない。
        // 途中で接続の受け付けに成功すれば、次の資源不足では再び警告する（03-09「失敗の種類」）。
        assert!(
            reports
                .iter()
                .all(|line| line.starts_with(ACCEPT_RETRY_REPORT)),
            "unexpected reports: {reports:?}"
        );
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

// 関門: CLI の継続・終了状態と、OS の資源が戻った後の応答を守る。
// 接続ごとに Registry を複製すると半分の接続数で内部エラーになる。
// 既存の注入による再試行テストは本物の登録と記述子の消費を通らない。
// 本番の差し込み口は加えず、上限を下げた子と実通信だけで確かめる。
#[test]
fn descriptor_exhaustion_preserves_server_and_recovers_in_both_modes() {
    for mode in ["direct", "request"] {
        let mut server = Server::start(mode);
        let mut connections = Vec::new();
        for _ in 0..CAPACITY_CONNECTIONS {
            let mut stream = server.connect();
            stream.write_all(b"GET /slow HTTP/1.1\r\nHost:").unwrap();
            connections.push(stream);
        }
        // 二度の応答で、要求を処理した後に次の accept の登録を通ることも確かめる。
        server.request("/capacity");
        server.request("/capacity-again");
        assert!(
            server.stderr.try_recv().is_err(),
            "capacity alone exhausted descriptors"
        );
        for _ in CAPACITY_CONNECTIONS..PRESSURE_CONNECTIONS {
            let mut stream = server.connect();
            stream.write_all(b"GET /slow HTTP/1.1\r\nHost:").unwrap();
            connections.push(stream);
        }
        // 警告を待つことで、実際に OS の上限に達したことを確認する。
        server.wait_for_shortage();
        drop(connections);
        server.request("/recovered");
        server.request("/done");
        server.finish();
    }
}
