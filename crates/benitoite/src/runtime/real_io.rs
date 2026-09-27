//! 本番のハンドラ表と出力のバッファ（設計書 02-09「ハンドラ表」「出力のバッファ」）。
//!
//! 書き込みはまずバッファにため、64 KiB に達したときと実行の終わり（`flush_all`）にだけ書き出す。
//! 書き出しに一度失敗した出力は、以後の書き込みを捨てる（02-09「出力のバッファ」）。

use std::io::{Read, Write};

use super::heap::Heap;
use super::io::{IoHandlers, IoOp};
use super::value::Value;
use super::{MAX_STRING_BYTES, ResourceError, RuntimeError, SizeUnit, Stop, Stream};
use crate::builtins::io_error;

/// バッファの中身を書き出す大きさ（64 KiB）。
pub const FLUSH_THRESHOLD: usize = 65_536;

/// 開発用の panic を起こす環境変数と、その値（10-09 の最後の段落）。
const DEV_PANIC_VAR: &str = "BENITOITE_DEV_PANIC";
const DEV_PANIC_RUN: &str = "run";
/// 開発用の panic の文言。処理系の不具合の報告のテストで使う
const DEV_PANIC_MESSAGE: &str = "BENITOITE_DEV_PANIC=run: panic after the first Console.println";

/// prelude の `Result` の構成子のタグ（`Ok` が 0、`Err` が 1。TestIo と揃える）。
const RESULT_OK: u32 = 0;
const RESULT_ERR: u32 = 1;

/// 一つの出力のバッファ。
pub struct OutputBuffer {
    buf: Vec<u8>,
    sink: Box<dyn Write>,
    /// 書き出しに失敗したときの理由。失敗した後は書き込みを捨てる
    failed: Option<String>,
}

/// 本番のハンドラ表。
pub struct RealIo {
    stdout: OutputBuffer,
    stderr: OutputBuffer,
    args: Vec<String>,
    /// デバッグビルドで `BENITOITE_DEV_PANIC=run` のとき true（10-09）。作るときに環境変数を読む
    dev_panic_on_println: bool,
}

impl OutputBuffer {
    /// 空のバッファを作る。
    pub fn new(sink: Box<dyn Write>) -> OutputBuffer {
        OutputBuffer {
            buf: Vec::new(),
            sink,
            failed: None,
        }
    }

    /// バッファに加える。加えた結果 FLUSH_THRESHOLD 以上になったら書き出す。書き出しに失敗したら理由を返す
    pub fn write(&mut self, bytes: &[u8]) -> Result<(), String> {
        // 失敗した出力への以後の書き込みは捨てる。同じ失敗を二度報告しない（02-09「出力のバッファ」）。
        if self.failed.is_some() {
            return Ok(());
        }
        self.buf.extend_from_slice(bytes);
        if self.buf.len() >= FLUSH_THRESHOLD {
            self.flush()?;
        }
        Ok(())
    }

    /// 中身をすべて書き出す。前に失敗していれば何もせず `Ok`
    pub fn flush(&mut self) -> Result<(), String> {
        if self.failed.is_some() {
            return Ok(());
        }
        let result = self
            .sink
            .write_all(&self.buf)
            .and_then(|()| self.sink.flush());
        // 成功しても失敗しても中身は捨てる。失敗した後に書き出し直すことはしない（02-09）。
        self.buf.clear();
        match result {
            Ok(()) => Ok(()),
            Err(e) => {
                let reason = e.to_string();
                self.failed = Some(reason.clone());
                Err(reason)
            }
        }
    }

    /// 書き出しに失敗していれば、その理由を返す。
    pub fn failure(&self) -> Option<&str> {
        self.failed.as_deref()
    }
}

impl RealIo {
    /// 標準出力と標準エラー出力に書き出す本番のハンドラ表
    pub fn new(args: Vec<String>) -> RealIo {
        RealIo::with_sinks(
            args,
            Box::new(std::io::stdout()),
            Box::new(std::io::stderr()),
        )
    }

    /// 書き出し先を与えて作る（テストで使う）
    pub fn with_sinks(args: Vec<String>, stdout: Box<dyn Write>, stderr: Box<dyn Write>) -> RealIo {
        // リリースビルドでは環境変数を読まない（10-09）。
        let dev_panic_on_println = cfg!(debug_assertions)
            && std::env::var(DEV_PANIC_VAR).is_ok_and(|v| v == DEV_PANIC_RUN);
        RealIo {
            stdout: OutputBuffer::new(stdout),
            stderr: OutputBuffer::new(stderr),
            args,
            dev_panic_on_println,
        }
    }

    /// 書き込み一つ。バッファの書き出しに失敗したら書き込みの失敗の実行時エラーにする。
    fn write_to(&mut self, stream: Stream, text: &str, newline: bool) -> Result<(), Stop> {
        let buffer = match stream {
            Stream::Stdout => &mut self.stdout,
            Stream::Stderr => &mut self.stderr,
        };
        let mut result = buffer.write(text.as_bytes());
        if newline && result.is_ok() {
            result = buffer.write(b"\n");
        }
        result.map_err(|reason| Stop::Runtime(RuntimeError::WriteFailed { stream, reason }))
    }

    /// 開発用の panic（10-09）。出力のバッファを書き出してから処理系の不具合を報告する順序を
    /// CLI の別プロセスのテストで確かめるために、最初の `Console.println` の直後に起こす。
    #[allow(clippy::panic)] // 意図して panic を起こす（00-02 の `#[allow]` の表）
    fn dev_panic(&self) {
        if self.dev_panic_on_println {
            panic!("{DEV_PANIC_MESSAGE}");
        }
    }

    fn args_list(&self, heap: &mut Heap) -> Result<Value, Stop> {
        let mut items = Vec::with_capacity(self.args.len());
        for a in &self.args {
            items.push(heap.string(a));
        }
        heap.list_from_vec(items, "Process.args")
    }
}

/// ファイルを読み、`Ok(内容)` か `Err(IoError)` の値にする。
fn read_text(path: &str, heap: &mut Heap) -> Result<Value, Stop> {
    match read_file(path)? {
        Ok(text) => {
            let s = heap.string(&text);
            Ok(heap.ctor(RESULT_OK, vec![s]))
        }
        Err(message) => {
            let e = heap.io_error(message);
            Ok(heap.ctor(RESULT_ERR, vec![e]))
        }
    }
}

/// ファイルを読む。内側の `Err` は `IoError` にする文言。
/// 上限より 1 バイト多い分まで読み、超えたら資源の不足（02-09「一つの操作で作る値の大きさの上限」）。
fn read_file(path: &str) -> Result<Result<String, String>, Stop> {
    let file = match std::fs::File::open(path) {
        Ok(f) => f,
        Err(e) => return Ok(Err(e.to_string())),
    };
    let mut bytes = Vec::new();
    // ディレクトリを開いたときの誤りは OS により開くときか読むときに出るが、どちらも `Err` になる。
    if let Err(e) = file
        .take(MAX_STRING_BYTES.saturating_add(1))
        .read_to_end(&mut bytes)
    {
        return Ok(Err(e.to_string()));
    }
    let size = u64::try_from(bytes.len())
        .map_err(|_| Stop::Internal(String::from("file size does not fit in u64")))?;
    if size > MAX_STRING_BYTES {
        return Err(Stop::Resource(ResourceError::ValueTooLarge {
            function: "File.readText",
            size,
            unit: SizeUnit::Bytes,
            limit: MAX_STRING_BYTES,
        }));
    }
    // 先頭の BOM は取り除かない（01-07「外部から受け取る文字列」）。
    Ok(String::from_utf8(bytes).map_err(|_| String::from(io_error::text::MSG_INVALID_UTF8)))
}

fn one_string(args: &[Value]) -> Result<&str, Stop> {
    match args {
        [v] => v.as_str().ok_or_else(invalid_arguments),
        _ => Err(invalid_arguments()),
    }
}

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("real IO handler received invalid arguments"))
}

impl IoHandlers for RealIo {
    /// 書き込みの中の書き出しで失敗したら `Stop::Runtime(RuntimeError::WriteFailed)` を返す。
    /// `ReadText` は、読めない・正しい UTF-8 でないときに `Err(IoError)` の値を返す（ADR 0012）。
    /// ファイルは上限より 1 バイト多い分まで読み、上限を超えたら資源の不足を返す（02-09）。
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop> {
        match op {
            IoOp::Print => {
                self.write_to(Stream::Stdout, one_string(args)?, false)?;
                Ok(Value::Unit)
            }
            IoOp::Println => {
                self.write_to(Stream::Stdout, one_string(args)?, true)?;
                self.dev_panic();
                Ok(Value::Unit)
            }
            IoOp::Eprintln => {
                self.write_to(Stream::Stderr, one_string(args)?, true)?;
                Ok(Value::Unit)
            }
            IoOp::ReadText => read_text(one_string(args)?, heap),
            IoOp::Args => {
                if !args.is_empty() {
                    return Err(invalid_arguments());
                }
                self.args_list(heap)
            }
        }
    }

    fn flush_all(&mut self) -> Vec<(Stream, String)> {
        let mut failures = Vec::new();
        // 標準出力、標準エラー出力の順（02-09「出力のバッファ」）。
        if let Err(reason) = self.stdout.flush() {
            failures.push((Stream::Stdout, reason));
        }
        if let Err(reason) = self.stderr.flush() {
            failures.push((Stream::Stderr, reason));
        }
        failures
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
pub(crate) mod tests {
    // 出力のバッファの書き出しの時点と失敗の後の扱い、ファイルの読み込みを公開の関数で確かめる
    // （設計書 02-09「出力のバッファ」、07-03「テストの設計の原則」）。
    use std::cell::RefCell;
    use std::io::Write;
    use std::rc::Rc;

    use super::{FLUSH_THRESHOLD, OutputBuffer, RealIo};
    use crate::builtins::io_error::text;
    use crate::runtime::heap::Heap;
    use crate::runtime::io::{IoHandlers, IoOp};
    use crate::runtime::{RuntimeError, Stop, Stream};

    /// 書き出された内容を共有して見られる書き出し先。
    #[derive(Clone, Default)]
    pub(crate) struct SharedSink(pub(crate) Rc<RefCell<Vec<u8>>>);

    impl Write for SharedSink {
        fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
            self.0.borrow_mut().extend_from_slice(buf);
            Ok(buf.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }

    /// 読み手の終わったパイプのように、常に `BrokenPipe` を返す書き出し先。
    pub(crate) struct BrokenSink;

    impl Write for BrokenSink {
        fn write(&mut self, _buf: &[u8]) -> std::io::Result<usize> {
            Err(std::io::Error::from(std::io::ErrorKind::BrokenPipe))
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Err(std::io::Error::from(std::io::ErrorKind::BrokenPipe))
        }
    }

    #[test]
    fn buffer_is_written_only_at_the_threshold_and_on_flush() {
        let sink = SharedSink::default();
        let mut buf = OutputBuffer::new(Box::new(sink.clone()));
        buf.write(&vec![b'a'; FLUSH_THRESHOLD - 1]).unwrap();
        assert!(sink.0.borrow().is_empty());
        buf.write(b"b").unwrap();
        assert_eq!(sink.0.borrow().len(), FLUSH_THRESHOLD);
        buf.write(b"tail").unwrap();
        assert_eq!(sink.0.borrow().len(), FLUSH_THRESHOLD);
        buf.flush().unwrap();
        assert!(sink.0.borrow().ends_with(b"btail"));
        assert_eq!(sink.0.borrow().len(), FLUSH_THRESHOLD + 4);
    }

    #[test]
    fn failed_flush_is_recorded_and_later_writes_are_dropped() {
        let mut buf = OutputBuffer::new(Box::new(BrokenSink));
        buf.write(b"x").unwrap();
        let reason = buf.flush().unwrap_err();
        assert_eq!(buf.failure(), Some(reason.as_str()));
        assert_eq!(buf.write(&vec![b'y'; FLUSH_THRESHOLD]), Ok(()));
        assert_eq!(buf.flush(), Ok(()));
    }

    #[test]
    fn println_whose_flush_fails_stops_with_write_failed() {
        let mut io = RealIo::with_sinks(
            Vec::new(),
            Box::new(BrokenSink),
            Box::new(SharedSink::default()),
        );
        let mut heap = Heap::new();
        let big = heap.string(&"z".repeat(FLUSH_THRESHOLD));
        match io.call(IoOp::Println, &[big], &mut heap) {
            Err(Stop::Runtime(RuntimeError::WriteFailed { stream, .. })) => {
                assert_eq!(stream, Stream::Stdout);
            }
            other => panic!("expected WriteFailed, got {other:?}"),
        }
    }

    #[test]
    fn read_text_returns_ok_or_err_values() {
        let dir = std::env::temp_dir().join(format!("benitoite-t23-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let good = dir.join("good.txt");
        let bad = dir.join("bad.txt");
        std::fs::write(&good, "\u{feff}héllo").unwrap();
        std::fs::write(&bad, [0xff]).unwrap();
        let missing = dir.join("missing.txt");

        let mut io = RealIo::with_sinks(
            Vec::new(),
            Box::new(SharedSink::default()),
            Box::new(SharedSink::default()),
        );
        let mut heap = Heap::new();
        let mut read = |path: &std::path::Path| {
            let p = heap.string(path.to_str().unwrap());
            let v = io.call(IoOp::ReadText, &[p], &mut heap).unwrap();
            let (tag, fields) = v.as_ctor().unwrap();
            let payload = &fields[0];
            (
                tag,
                payload
                    .as_str()
                    .or_else(|| payload.as_io_error())
                    .unwrap()
                    .to_owned(),
            )
        };
        // 先頭の BOM は取り除かない（01-07）。
        assert_eq!(read(&good), (0, String::from("\u{feff}héllo")));
        assert_eq!(read(&bad), (1, String::from(text::MSG_INVALID_UTF8)));
        assert_eq!(read(&missing).0, 1);
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
