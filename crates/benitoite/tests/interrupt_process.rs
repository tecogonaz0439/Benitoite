//! 実際のシグナルから停止・出力・終了状態までを別プロセスで確かめる
//! （設計書 07-03「中断の要求のテスト（初回リリース版）」、ADR 0223）。
#![cfg(unix)]
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use std::fs;
use std::io::Read;
use std::os::unix::process::ExitStatusExt;
use std::path::PathBuf;
use std::process::{Child, Command, ExitStatus, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const LIMIT: Duration = Duration::from_secs(30);
const READY: &[u8] = b"ready\n";
const IMPORTS: &str = "import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Clock\nimport Benitoite.Unofficial.IO.File\n";

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let mut attempt = 0_u64;
        loop {
            let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!(
                "../../target/r31-interrupt-{}-{stamp}-{attempt}",
                std::process::id()
            ));
            // 時刻の分解能で名前が重なっても、作成に成功したテストだけが使う。
            // create_dir_all では既存のディレクトリを共有してしまう（R31）。
            match fs::create_dir(&path) {
                Ok(()) => return Self(path.canonicalize().unwrap()),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {
                    attempt = attempt.checked_add(1).unwrap();
                }
                Err(error) => panic!("cannot create test directory: {error}"),
            }
        }
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _removed = fs::remove_dir_all(&self.0);
    }
}

// 待ちの上限を超えたときも、アサーションが失敗したときも子を kill して回収する。
// パイプを読むスレッドは、子が閉じた後で完了の channel に結果を返す（実装プラン R31）。
struct Process {
    child: Child,
    ready: Receiver<Vec<u8>>,
    stdout: Receiver<Vec<u8>>,
    stderr: Receiver<Vec<u8>>,
    resume_stdout: Sender<()>,
    readers: Vec<thread::JoinHandle<()>>,
    _directory: Directory,
}

impl Process {
    fn start(source: &str, mode: &str, hold_stdout: bool) -> Self {
        let directory = Directory::new();
        fs::write(directory.0.join("input.txt"), b"resource\n").unwrap();
        let script = directory.0.join("main.bnt");
        fs::write(&script, format!("{IMPORTS}{source}")).unwrap();
        let child = Command::new(env!("CARGO_BIN_EXE_benitoite"))
            .arg("run")
            .arg(&script)
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
        let (ready_send, ready) = mpsc::channel();
        let (out_send, stdout) = mpsc::channel();
        let (err_send, stderr) = mpsc::channel();
        let (resume_stdout, resume) = mpsc::channel();
        // spawn の直後からガードを持ち、準備の途中の失敗にも対応する。
        let mut process = Self {
            child,
            ready,
            stdout,
            stderr,
            resume_stdout,
            readers: Vec::new(),
            _directory: directory,
        };
        let mut out = process.child.stdout.take().unwrap();
        process.readers.push(thread::spawn(move || {
            // 二度目の要求のケースでは、準備行以外を先読みしてパイプを空けない。
            let mut line = Vec::new();
            let mut byte = [0u8; 1];
            while out.read(&mut byte).unwrap_or(0) != 0 {
                line.extend_from_slice(&byte);
                if byte.first() == Some(&b'\n') {
                    break;
                }
            }
            let _ready = ready_send.send(line.clone());
            if hold_stdout {
                let _resume = resume.recv_timeout(LIMIT);
            }
            let mut remaining = Vec::new();
            let _read = out.read_to_end(&mut remaining);
            line.extend(remaining);
            let _sent = out_send.send(line);
        }));
        let mut err = process.child.stderr.take().unwrap();
        process.readers.push(thread::spawn(move || {
            let mut bytes = Vec::new();
            let _read = err.read_to_end(&mut bytes);
            let _sent = err_send.send(bytes);
        }));
        process
    }

    fn await_ready(&mut self) {
        let line = self.ready.recv_timeout(LIMIT).unwrap_or_else(|error| {
            let status = self.child.try_wait().unwrap();
            let stderr = self.stderr.try_recv().ok();
            panic!("readiness did not arrive: {error}; status={status:?}; stderr={stderr:?}")
        });
        assert_eq!(
            line,
            READY,
            "unexpected readiness; stderr={:?}",
            self.stderr.try_recv().ok()
        );
    }

    fn signal(&self, signal: &str) {
        let sent = Command::new("kill")
            .args([signal, &self.child.id().to_string()])
            .output()
            .unwrap();
        assert!(sent.status.success(), "kill failed: {sent:?}");
    }

    fn wait(&mut self) -> ExitStatus {
        let started = Instant::now();
        loop {
            if let Some(status) = self.child.try_wait().unwrap() {
                return status;
            }
            assert!(
                started.elapsed() < LIMIT,
                "child did not exit after interrupt"
            );
            // 実時間は結果を決めず、終了の検出とテストの停止の検出にだけ使う。
            thread::sleep(Duration::from_millis(2));
        }
    }

    fn output(&self) -> (Vec<u8>, Vec<u8>) {
        (
            self.stdout
                .recv_timeout(LIMIT)
                .expect("stdout reader did not finish"),
            self.stderr
                .recv_timeout(LIMIT)
                .expect("stderr reader did not finish"),
        )
    }
}

impl Drop for Process {
    fn drop(&mut self) {
        // 正常に終えた場合も kill を試し、stdin の待ちを残さない。
        let _killed = self.child.kill();
        drop(self.child.stdin.take());
        let _waited = self.child.wait();
        let _resumed = self.resume_stdout.send(());
        for reader in self.readers.drain(..) {
            let _joined = reader.join();
        }
    }
}

// hold_stdout が真なら、準備の行の後を読まずにシグナルを送り、送った後で読み始める。
// シグナルを送る時点で、準備の行の後の出力の転送が終わっていないことを、実時間に頼らず作る。
fn interrupted(source: &str, signal: &str, hold_stdout: bool, expected_stdout: &[u8]) {
    for mode in ["direct", "request"] {
        let mut process = Process::start(source, mode, hold_stdout);
        process.await_ready();
        process.signal(signal);
        if hold_stdout {
            process.resume_stdout.send(()).unwrap();
        }
        let status = process.wait();
        let (stdout, stderr) = process.output();
        assert_eq!(
            status.code(),
            Some(130),
            "{mode}: {status:?}; stderr={stderr:?}"
        );
        // 大きな出力の比較でも失敗の報告が読めるように、長さと先頭だけを示す。
        assert!(
            stdout == expected_stdout,
            "{mode}: stdout has {} bytes, expected {}; head={:?}",
            stdout.len(),
            expected_stdout.len(),
            String::from_utf8_lossy(stdout.get(..64).unwrap_or(&stdout))
        );
        assert!(
            stderr.is_empty(),
            "{mode}: {}",
            String::from_utf8_lossy(&stderr)
        );
    }
}

// 関門: API に印を渡す R28 のテストでは、実際のシグナル登録とイベントループの
// 起こしを通らない。五つの独立した停止の契約を CLI の境界で確かめる（ADR 0223）。
#[test]
fn sigint_interrupts_stdin_and_preserves_output_after_the_ready_line() {
    interrupted(
        r#"
function main() -> Unit uses Console.Read,Console.Write
 Console.write("ready\nbuffered after ready")
 bind _ <- Console.readLine()
 Console.write("unreachable")
end function
"#,
        "-INT",
        false,
        b"ready\nbuffered after ready",
    );
    // 一回の書き込みに両方を含め、準備行を親が見た時点で後続の出力も受け付け済みにする。
    // 読み取り前の出力の転送は、別途 io_modes の筋書きで確かめる（設計書 02-09「出力のバッファ」）。
}

#[test]
fn sigterm_interrupts_timers_in_parent_and_child_tasks() {
    interrupted(
        r#"
function main() -> Unit uses State,Console.Write,Clock.Time
 with group = TaskGroup.open() do
  bind _ <- TaskGroup.spawn(group,lambda() Clock.sleep(3600000)
                            return () end lambda)
  Console.writeLine("ready")
  Clock.sleep(3600000)
 end with
end function
"#,
        "-TERM",
        false,
        READY,
    );
}

#[test]
fn sigint_interrupts_tail_recursive_computation() {
    // 一回の書き込みに準備の行と 2 MiB を含める。64 KiB 以上の書き込みで転送が依頼され、
    // 親が準備の行の後を読まない間は、パイプの容量を超えた転送が終わらない。
    // 書き込みの後は待ちを挟まずに計算を続けるので、シグナルが計算の前の待ちに当たらない
    // （FLNX。以前の Clock.sleep(1) の待ちに中断が当たると、後の出力が書かれずに揺れた）。
    let body = "x".repeat(2 * 1024 * 1024);
    let source = format!(
        r#"
function loop() -> Unit
 return loop()
end function
function main() -> Unit uses Console.Write
 Console.write("ready\n{body}")
 loop()
end function
"#
    );
    interrupted(&source, "-INT", true, format!("ready\n{body}").as_bytes());
    // 切り替えの位置で中断の印が調べられ、止める手順の終わりに転送の完了を待つ。
    // シグナルの時点で転送が終わっていないので、最後の転送の完了を待たずに終える退行は
    // 出力の欠けとして現れる（設計書 07-03「中断の要求のテスト（初回リリース版）」、
    // 02-09「出力のバッファ」）。
}

#[test]
fn sigint_interrupts_with_an_open_reader() {
    interrupted(
        r#"
function main() -> Result[Unit,String] uses File.Read,State,Console.Write,Console.Read
 with reader = try File.openReader("input.txt") |> Result.mapError(_,IOError.message) do
  bind _ <- try File.readLine(reader) |> Result.mapError(_,IOError.message)
  Console.writeLine("ready")
  bind _ <- Console.readLine()
  return Result.Ok(())
 end with
end function
"#,
        "-INT",
        false,
        READY,
    );
}

#[test]
fn second_sigint_terminates_without_waiting_for_blocked_stdout() {
    // 一つの write に準備行と 2 MiB を含める。準備行を受け取る時点で大きな出力の
    // 転送が始まっており、親は行の後を読まないので転送が完了しない（実装プラン R31）。
    let source = format!(
        r#"
function main() -> Unit uses Console.Write,Clock.Time
 Console.write("ready\n{}")
 Clock.sleep(3600000)
end function
"#,
        "x".repeat(2 * 1024 * 1024)
    );
    for mode in ["direct", "request"] {
        let mut process = Process::start(&source, mode, true);
        process.await_ready();
        // CLI は一度目の受信を外へ通知せず、標準出力も塞いでいるので、受信を確認してから
        // 二度目を送る手段がない。kill の成功は受信の確認ではなく、保留中の同じシグナルが
        // まとまる環境ではこのテストが揺れる制約が残る。時間待ちで受信済みと仮定しない。
        // 一度目の停止手順と終了コード 130 は、上の四件が両 IO 方式で別途確かめる（R31）。
        process.signal("-INT");
        process.signal("-INT");
        let status = process.wait();
        assert_eq!(
            status.signal(),
            Some(signal_hook::consts::SIGINT),
            "{mode}: {status:?}"
        );
        // 子が終わるまでパイプを空けない。終わった後で読み手を解放し、失敗時も Drop が解放する。
        process.resume_stdout.send(()).unwrap();
        let (_, stderr) = process.output();
        assert!(stderr.is_empty(), "{}", String::from_utf8_lossy(&stderr));
    }
}
