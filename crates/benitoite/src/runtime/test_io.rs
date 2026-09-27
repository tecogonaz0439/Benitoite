//! テスト用のハンドラ表（設計書 02-09「ハンドラ表」）。

use std::collections::BTreeMap;

use super::heap::Heap;
use super::io::{IoEvent, IoHandlers, IoOp};
use super::value::Value;
use super::{Stop, Stream};
use crate::builtins::io_error::text;

/// 書き込みをメモリに記録し、ファイルの内容とコマンドライン引数を与えられた値から返す。
#[derive(Debug, Default)]
pub struct TestIo {
    pub args: Vec<String>,
    /// パス（与えたままの文字列）→ 内容のバイト列
    pub files: BTreeMap<String, Vec<u8>>,
    pub events: Vec<IoEvent>,
    pub stdout: String,
    pub stderr: String,
}

impl TestIo {
    /// 与えたファイルと引数を使う、空の記録状態を持つハンドラ表を作る。
    pub fn new(args: Vec<String>, files: BTreeMap<String, Vec<u8>>) -> TestIo {
        TestIo {
            args,
            files,
            events: Vec::new(),
            stdout: String::new(),
            stderr: String::new(),
        }
    }
}

impl IoHandlers for TestIo {
    /// 外部 IO をメモリ上の状態に置き換え、同じ操作順を記録する。
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop> {
        match op {
            IoOp::Print | IoOp::Println | IoOp::Eprintln => {
                let mut output = one_string(args)?.to_owned();
                let stream = match op {
                    IoOp::Print | IoOp::Println => Stream::Stdout,
                    IoOp::Eprintln => Stream::Stderr,
                    IoOp::ReadText | IoOp::Args => return Err(invalid_arguments()),
                };
                if matches!(op, IoOp::Println | IoOp::Eprintln) {
                    output.push('\n');
                }
                match stream {
                    Stream::Stdout => self.stdout.push_str(&output),
                    Stream::Stderr => self.stderr.push_str(&output),
                }
                self.events.push(IoEvent::Write {
                    stream,
                    text: output,
                });
                Ok(Value::Unit)
            }
            IoOp::ReadText => {
                let path = one_string(args)?.to_owned();
                let (value, ok) = match self.files.get(&path) {
                    Some(bytes) => match std::str::from_utf8(bytes) {
                        Ok(contents) => {
                            let contents = heap.string(contents);
                            (heap.ctor(0, vec![contents]), true)
                        }
                        Err(_) => {
                            let error = heap.io_error(String::from(text::MSG_INVALID_UTF8));
                            (heap.ctor(1, vec![error]), false)
                        }
                    },
                    None => {
                        let error = heap.io_error(String::from(text::MSG_NOT_FOUND));
                        (heap.ctor(1, vec![error]), false)
                    }
                };
                // Result の Ok と Err は prelude の構成子順に対応する（設計書 02-09「ハンドラ表」）。
                self.events.push(IoEvent::ReadFile { path, ok });
                Ok(value)
            }
            IoOp::Args => {
                if !args.is_empty() {
                    return Err(invalid_arguments());
                }
                let mut values = Vec::with_capacity(self.args.len());
                for argument in &self.args {
                    values.push(heap.string(argument));
                }
                let result = heap.list_from_vec(values, "Process.args")?;
                self.events.push(IoEvent::Args);
                Ok(result)
            }
        }
    }
}

fn one_string(args: &[Value]) -> Result<&str, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_str)
        .ok_or_else(invalid_arguments)
}

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("test IO handler received invalid arguments"))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // テスト用ハンドラの出力・ファイル読み込み・引数の返却を公開境界で確かめる（設計書 07-03「テストの設計の原則」）。
    use std::collections::BTreeMap;

    use crate::builtins::io_error::text;
    use crate::runtime::heap::Heap;
    use crate::runtime::io::{IoEvent, IoHandlers, IoOp};
    use crate::runtime::value::Value;
    use crate::runtime::{Stop, Stream};

    use super::TestIo;

    #[test]
    fn writes_are_recorded_in_order_with_the_written_text() {
        let mut io = TestIo::new(Vec::new(), BTreeMap::new());
        let mut heap = Heap::new();
        let first = heap.string("a");
        let second = heap.string("b");

        assert!(matches!(
            io.call(IoOp::Println, &[first], &mut heap),
            Ok(Value::Unit)
        ));
        assert!(matches!(
            io.call(IoOp::Print, &[second], &mut heap),
            Ok(Value::Unit)
        ));
        assert_eq!(io.stdout, "a\nb");
        assert_eq!(
            io.events,
            vec![
                IoEvent::Write {
                    stream: Stream::Stdout,
                    text: String::from("a\n"),
                },
                IoEvent::Write {
                    stream: Stream::Stdout,
                    text: String::from("b"),
                },
            ]
        );
    }

    #[test]
    fn eprintln_writes_to_stderr_with_a_newline() {
        let mut io = TestIo::new(Vec::new(), BTreeMap::new());
        let mut heap = Heap::new();
        let value = heap.string("warning");

        assert!(matches!(
            io.call(IoOp::Eprintln, &[value], &mut heap),
            Ok(Value::Unit)
        ));

        assert_eq!(io.stderr, "warning\n");
        assert_eq!(
            io.events,
            vec![IoEvent::Write {
                stream: Stream::Stderr,
                text: String::from("warning\n"),
            }]
        );
    }

    #[test]
    fn reads_return_ok_or_shared_io_error_messages_and_record_each_attempt() {
        let files = BTreeMap::from([
            (String::from("in.txt"), b"contents".to_vec()),
            (String::from("invalid.txt"), vec![0xff]),
        ]);
        let mut io = TestIo::new(Vec::new(), files);
        let mut heap = Heap::new();

        let existing_path = heap.string("in.txt");
        let existing = io
            .call(IoOp::ReadText, &[existing_path], &mut heap)
            .unwrap();
        assert_read_result(&existing, Ok("contents"));

        let missing_path = heap.string("x.txt");
        let missing = io.call(IoOp::ReadText, &[missing_path], &mut heap).unwrap();
        assert_read_result(&missing, Err(text::MSG_NOT_FOUND));

        let invalid_path = heap.string("invalid.txt");
        let invalid = io.call(IoOp::ReadText, &[invalid_path], &mut heap).unwrap();
        assert_read_result(&invalid, Err(text::MSG_INVALID_UTF8));

        assert_eq!(
            io.events,
            vec![
                IoEvent::ReadFile {
                    path: String::from("in.txt"),
                    ok: true,
                },
                IoEvent::ReadFile {
                    path: String::from("x.txt"),
                    ok: false,
                },
                IoEvent::ReadFile {
                    path: String::from("invalid.txt"),
                    ok: false,
                },
            ]
        );
    }

    #[test]
    fn args_are_returned_in_the_supplied_order() {
        let mut io = TestIo::new(
            vec![String::from("one"), String::from("two")],
            BTreeMap::new(),
        );
        let mut heap = Heap::new();

        let result = io.call(IoOp::Args, &[], &mut heap).unwrap();
        let values = result
            .as_list()
            .unwrap()
            .iter()
            .map(|value| value.as_str().unwrap())
            .collect::<Vec<_>>();

        assert_eq!(values, vec!["one", "two"]);
        assert_eq!(io.events, vec![IoEvent::Args]);
    }

    #[test]
    fn invalid_argument_values_stop_as_internal_errors() {
        let mut io = TestIo::new(Vec::new(), BTreeMap::new());
        let mut heap = Heap::new();
        let invalid_string = [Value::Unit];

        for op in [IoOp::Print, IoOp::Println, IoOp::Eprintln, IoOp::ReadText] {
            assert!(matches!(
                io.call(op, &invalid_string, &mut heap),
                Err(Stop::Internal(_))
            ));
        }
        assert!(matches!(
            io.call(IoOp::Args, &invalid_string, &mut heap),
            Err(Stop::Internal(_))
        ));
    }

    fn assert_read_result(value: &Value, expected: Result<&str, &str>) {
        let (tag, fields) = value.as_ctor().unwrap();
        match expected {
            Ok(contents) => {
                assert_eq!(tag, 0);
                assert_eq!(fields.len(), 1);
                assert_eq!(fields.first().and_then(Value::as_str), Some(contents));
            }
            Err(message) => {
                assert_eq!(tag, 1);
                assert_eq!(fields.len(), 1);
                assert_eq!(fields.first().and_then(Value::as_io_error), Some(message));
            }
        }
    }
}
