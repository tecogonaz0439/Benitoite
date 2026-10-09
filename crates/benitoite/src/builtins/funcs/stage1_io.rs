//! 第 1 段の IO の口（設計書 02-09「出力のバッファ」、実装プラン R08）。
//! R26 が 10-10 の IoRuntime に置き換えて消す。

use std::collections::BTreeMap;
use std::ffi::OsString;
use std::io::{self, Write};
use std::path::Path;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use crate::builtins::iface::{IoServices, IoWait, OsResource};
use crate::runtime::heap::ResourceId;
use crate::runtime::io::services::RunInput;
use crate::runtime::{ResourceKind, RuntimeError, Stop, Stream};
use crate::vm::InstrRef;

const FLUSH_THRESHOLD: usize = 65_536;

struct Output {
    buffer: Vec<u8>,
    sink: Box<dyn Write>,
    failure: Option<String>,
}

impl Output {
    fn new(sink: Box<dyn Write>) -> Self {
        Self {
            buffer: Vec::new(),
            sink,
            failure: None,
        }
    }

    fn flush(&mut self) -> io::Result<()> {
        if self.failure.is_some() {
            return Ok(());
        }
        let result = self
            .sink
            .write_all(&self.buffer)
            .and_then(|()| self.sink.flush());
        // 部分的に書けた場合も再送しない（設計書 02-09「出力のバッファ」）。
        self.buffer.clear();
        if let Err(error) = &result {
            self.failure = Some(error.to_string());
        }
        result
    }
}

/// 第 1 段の本番の IO。R26 が 10-10 の `IoRuntime` に置き換えて消す。
/// リソースの登録と乱数は第 1 段では使わない。呼ばれたら不具合を記録し、
/// 次の書き込みか `take_internal_error` で `Stop::Internal` にする。
pub struct RealIo {
    input: RunInput,
    stdout: Output,
    stderr: Output,
    started: Instant,
    internal_error: Option<&'static str>,
}

impl RealIo {
    /// 実行の入力から作る。R26 が 10-10 の `IoRuntime` に置き換えて消す。
    pub fn new(input: RunInput) -> Self {
        Self::with_sinks(input, Box::new(io::stdout()), Box::new(io::stderr()))
    }

    /// 実行の出力先を与えて作る。R26 が 10-10 の `IoRuntime` に置き換えて消す。
    /// 失敗する出力先も同じバッファの手順を通す（実装プラン R08「受け入れテスト」）。
    pub fn with_sinks(input: RunInput, stdout: Box<dyn Write>, stderr: Box<dyn Write>) -> Self {
        Self {
            input,
            stdout: Output::new(stdout),
            stderr: Output::new(stderr),
            started: Instant::now(),
            internal_error: None,
        }
    }

    /// 最後の標準出力の書き出し。失敗は記録し、その呼び出しで返す。
    pub fn flush_stdout(&mut self) -> io::Result<()> {
        self.stdout.flush()
    }

    /// 最後の標準エラー出力の書き出し。標準出力の後に呼ぶ。
    pub fn flush_stderr(&mut self) -> io::Result<()> {
        self.stderr.flush()
    }

    /// 出力の失敗の記録。取り出しても以後の書き込みを拒む印は残す。
    pub fn output_failure(&self, stream: Stream) -> Option<&str> {
        match stream {
            Stream::Stdout => self.stdout.failure.as_deref(),
            Stream::Stderr => self.stderr.failure.as_deref(),
        }
    }

    /// 使わないはずの口を呼んだ記録。実行の終わりにも確かめる。
    pub fn take_internal_error(&mut self) -> Option<Stop> {
        self.internal_error
            .take()
            .map(|reason| Stop::Internal(reason.into()))
    }
}

impl IoServices for RealIo {
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop> {
        if let Some(error) = self.take_internal_error() {
            return Err(error);
        }
        let output = match stream {
            Stream::Stdout => &mut self.stdout,
            Stream::Stderr => &mut self.stderr,
        };
        if let Some(reason) = &output.failure {
            return Err(Stop::Runtime(RuntimeError::WriteFailed {
                stream,
                reason: reason.clone(),
            }));
        }
        output.buffer.extend_from_slice(text.as_bytes());
        if output.buffer.len() >= FLUSH_THRESHOLD {
            output.flush().map_err(|error| {
                Stop::Runtime(RuntimeError::WriteFailed {
                    stream,
                    reason: error.to_string(),
                })
            })?;
        }
        Ok(None)
    }
    fn arguments(&self) -> &[String] {
        &self.input.arguments
    }
    fn script_directory(&self) -> &Path {
        &self.input.script_directory
    }
    fn working_directory(&self) -> &Path {
        &self.input.working_directory
    }
    fn environment_variable(&self, name: &str) -> Option<OsString> {
        std::env::var_os(name)
    }
    fn now_millis(&self) -> i64 {
        match SystemTime::now().duration_since(UNIX_EPOCH) {
            Ok(duration) => i64::try_from(duration.as_millis()).unwrap_or(i64::MAX),
            Err(error) => i64::try_from(error.duration().as_millis())
                .unwrap_or(i64::MAX)
                .saturating_neg(),
        }
    }
    fn local_offset_minutes(&self) -> i32 {
        0
    }
    fn monotonic_millis(&self) -> i64 {
        i64::try_from(self.started.elapsed().as_millis()).unwrap_or(i64::MAX)
    }
    fn random_u64(&mut self) -> u64 {
        self.internal_error = Some("stage 1 must not request random numbers");
        0
    }
    fn register_resource(
        &mut self,
        _kind: ResourceKind,
        _handle: Box<dyn OsResource>,
        _opened_at: Option<InstrRef>,
    ) -> ResourceId {
        self.internal_error = Some("stage 1 must not register resources");
        ResourceId(u64::MAX)
    }
}

/// 第 1 段のテスト用の IO。R26 が 10-10 の `IoRuntime` に置き換えて消す。
/// 環境・時計・乱数には与えた値を使い、出力は書き込みごとに順を記録する。
/// 登録の口は使わない。呼ばれたら `take_internal_error` で不具合として取り出す。
pub struct TestIo {
    input: RunInput,
    output: Vec<(Stream, Vec<u8>)>,
    /// テストが与える環境変数。
    pub environment: BTreeMap<String, OsString>,
    /// テストが与える UTC のミリ秒。
    pub now: i64,
    /// テストが与える地方時の差。
    pub local_offset: i32,
    /// テストが与える単調な時計のミリ秒。
    pub monotonic: i64,
    /// テストが与える乱数の値。
    pub random: u64,
    internal_error: Option<&'static str>,
}

impl TestIo {
    /// 入力から作る。R26 が 10-10 の `IoRuntime` に置き換えて消す。
    pub fn new(input: RunInput) -> Self {
        Self {
            input,
            output: Vec::new(),
            environment: BTreeMap::new(),
            now: 0,
            local_offset: 0,
            monotonic: 0,
            random: 0,
            internal_error: None,
        }
    }
    /// 書いた順のバイト列を取り出す。出力の種類を各書き込みとともに返す。
    pub fn take_output(&mut self) -> Vec<(Stream, Vec<u8>)> {
        std::mem::take(&mut self.output)
    }
    /// 未対応の登録の口を呼んだ記録。実行の終わりにも確かめる。
    pub fn take_internal_error(&mut self) -> Option<Stop> {
        self.internal_error
            .take()
            .map(|reason| Stop::Internal(reason.into()))
    }
}

impl IoServices for TestIo {
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop> {
        if let Some(error) = self.take_internal_error() {
            return Err(error);
        }
        self.output.push((stream, text.as_bytes().to_vec()));
        Ok(None)
    }
    fn arguments(&self) -> &[String] {
        &self.input.arguments
    }
    fn script_directory(&self) -> &Path {
        &self.input.script_directory
    }
    fn working_directory(&self) -> &Path {
        &self.input.working_directory
    }
    fn environment_variable(&self, name: &str) -> Option<OsString> {
        self.environment.get(name).cloned()
    }
    fn now_millis(&self) -> i64 {
        self.now
    }
    fn local_offset_minutes(&self) -> i32 {
        self.local_offset
    }
    fn monotonic_millis(&self) -> i64 {
        self.monotonic
    }
    fn random_u64(&mut self) -> u64 {
        self.random
    }
    fn register_resource(
        &mut self,
        _kind: ResourceKind,
        _handle: Box<dyn OsResource>,
        _opened_at: Option<InstrRef>,
    ) -> ResourceId {
        self.internal_error = Some("stage 1 must not register resources");
        ResourceId(u64::MAX)
    }
}

#[cfg(test)]
mod tests {
    // 外部の出力先を置き換え、書き出しの時点・失敗の記録・その後の拒否を確かめる
    // （実装プラン R08「受け入れテスト」、設計書 02-09「出力のバッファ」）。
    // テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;
    use std::cell::RefCell;
    use std::rc::Rc;

    #[derive(Clone, Default)]
    struct Sink(Rc<RefCell<Vec<u8>>>);
    impl Write for Sink {
        fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
            self.0.borrow_mut().extend_from_slice(bytes);
            Ok(bytes.len())
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    #[derive(Debug)]
    struct UnusedResource;
    impl OsResource for UnusedResource {
        fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
            self
        }
        fn release(self: Box<Self>) -> Result<(), String> {
            Ok(())
        }
    }

    struct BrokenSink;
    impl Write for BrokenSink {
        fn write(&mut self, _bytes: &[u8]) -> io::Result<usize> {
            Err(io::ErrorKind::BrokenPipe.into())
        }
        fn flush(&mut self) -> io::Result<()> {
            Err(io::ErrorKind::BrokenPipe.into())
        }
    }

    fn input() -> RunInput {
        let directory = std::env::current_dir().unwrap();
        RunInput {
            arguments: vec!["arg".into()],
            working_directory: directory.clone(),
            script_directory: directory.join("scripts"),
        }
    }

    #[test]
    fn real_io_buffers_each_stream_until_threshold_or_final_flush() {
        let stdout = Sink::default();
        let stderr = Sink::default();
        let mut services =
            RealIo::with_sinks(input(), Box::new(stdout.clone()), Box::new(stderr.clone()));
        assert!(
            services
                .write_output(Stream::Stdout, &"a".repeat(FLUSH_THRESHOLD - 1))
                .unwrap()
                .is_none()
        );
        assert!(
            services
                .write_output(Stream::Stderr, "error")
                .unwrap()
                .is_none()
        );
        assert!(stdout.0.borrow().is_empty());
        assert!(stderr.0.borrow().is_empty());
        services.write_output(Stream::Stdout, "b").unwrap();
        assert_eq!(stdout.0.borrow().len(), FLUSH_THRESHOLD);
        assert!(stderr.0.borrow().is_empty());
        services.write_output(Stream::Stdout, "tail").unwrap();
        services.flush_stdout().unwrap();
        services.flush_stderr().unwrap();
        assert!(stdout.0.borrow().ends_with(b"btail"));
        assert_eq!(&*stderr.0.borrow(), b"error");
        assert!(services.output_failure(Stream::Stdout).is_none());
        assert!(services.output_failure(Stream::Stderr).is_none());
    }

    #[test]
    fn failed_final_or_threshold_flush_is_recorded_and_later_writes_fail() {
        for stream in [Stream::Stdout, Stream::Stderr] {
            for threshold in [false, true] {
                let mut services =
                    RealIo::with_sinks(input(), Box::new(BrokenSink), Box::new(BrokenSink));
                if threshold {
                    assert!(
                        matches!(services.write_output(stream, &"x".repeat(FLUSH_THRESHOLD)), Err(Stop::Runtime(RuntimeError::WriteFailed { stream: actual, .. })) if actual == stream)
                    );
                } else {
                    assert!(services.write_output(stream, "x").unwrap().is_none());
                    let error = match stream {
                        Stream::Stdout => services.flush_stdout(),
                        Stream::Stderr => services.flush_stderr(),
                    }
                    .unwrap_err();
                    assert_eq!(error.kind(), io::ErrorKind::BrokenPipe);
                }
                let reason = services.output_failure(stream).unwrap().to_owned();
                assert!(!reason.is_empty());
                assert!(
                    matches!(services.write_output(stream, "later"), Err(Stop::Runtime(RuntimeError::WriteFailed { stream: actual, reason: failure })) if actual == stream && failure == reason)
                );
                // 失敗したバッファを再送せず、二度目の失敗も報告しない（設計書 02-09「出力のバッファ」）。
                match stream {
                    Stream::Stdout => services.flush_stdout(),
                    Stream::Stderr => services.flush_stderr(),
                }
                .unwrap();
                assert_eq!(services.output_failure(stream), Some(reason.as_str()));
            }
        }
    }

    #[test]
    fn test_io_supplies_environment_clocks_and_records_unexpected_registration() {
        let input = input();
        let mut services = TestIo::new(input.clone());
        services
            .environment
            .insert("EXAMPLE".into(), "value".into());
        services.now = 123;
        services.local_offset = 540;
        services.monotonic = 456;
        services.random = 789;
        assert_eq!(services.arguments(), input.arguments);
        assert_eq!(services.working_directory(), input.working_directory);
        assert_eq!(services.script_directory(), input.script_directory);
        assert_eq!(
            services.environment_variable("EXAMPLE"),
            Some("value".into())
        );
        assert_eq!(services.environment_variable("MISSING"), None);
        assert_eq!(services.now_millis(), 123);
        assert_eq!(services.local_offset_minutes(), 540);
        assert_eq!(services.monotonic_millis(), 456);
        assert_eq!(services.random_u64(), 789);
        assert!(services.take_internal_error().is_none());
        services.register_resource(ResourceKind::FileReader, Box::new(UnusedResource), None);
        assert!(
            matches!(services.take_internal_error(), Some(Stop::Internal(reason)) if reason.contains("must not register resources"))
        );
    }
}
