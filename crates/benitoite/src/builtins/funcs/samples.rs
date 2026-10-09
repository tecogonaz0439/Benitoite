//! 型付きの組み込みの関数の見本（設計書 02-08「組み込みの関数の呼び出し」、ADR 0261 の決定 7）。
//! 見本はテストでだけ使い、本番の組み込みの表には登録しない。

use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

use crate::builtins::iface::{IoCtx, IoReply, IoWait, Lend, WorkerWait, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, FieldsKind, StrBuf, Value};
use crate::runtime::{MAX_STRING_BYTES, ResourceError, RuntimeError, SizeUnit, Stop};

mod text {
    pub const INVALID_UTF8: &str = "input is not valid UTF-8";
}

builtin! {
    /// 整数の絶対値。最小の整数の絶対値は表せない（設計書 01-08「実行時エラーによる停止」）。
    name = "Sample.absolute",
    pure fn integer_absolute(ctx, n: i64) -> i64 {
        let _ = ctx;
        n.checked_abs().ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}

builtin! {
    /// 結果の大きさを確かめてから文字列を繰り返す（設計書 02-09「一つの操作で作る値の大きさの上限」）。
    name = "Sample.repeat",
    pure fn string_repeat(ctx, s: &'c str, n: i64) -> Value<'e> {
        let bytes = u64::try_from(s.len())
            .map_err(|_| Stop::Internal("string length does not fit u64".into()))?;
        let count = u64::try_from(n.max(0))
            .map_err(|_| Stop::Internal("nonnegative repeat count does not fit u64".into()))?;
        // u64 にも収まらない結果は、その最大値で上限超過を報告する
        // （設計書 02-09「一つの操作で作る値の大きさの上限」）。
        let size = bytes.checked_mul(count).ok_or(Stop::Resource(ResourceError::ValueTooLarge {
            function: "Sample.repeat",
            size: u64::MAX,
            unit: SizeUnit::Bytes,
            limit: MAX_STRING_BYTES,
        }))?;
        CheckedLen::bytes(size, "Sample.repeat")?;
        let mut buf = StrBuf::new("Sample.repeat");
        // 空の文字列では、回数が大きくても走査する必要がない（設計書 02-09「一つの操作で作る値の大きさの上限」）。
        if !s.is_empty() {
            for _ in 0..count {
                buf.push_str(s)?;
            }
        }
        ctx.alloc_str_buf(buf)
    }
}

struct IoFailure {
    kind: u32,
    reason: String,
}

impl From<io::Error> for IoFailure {
    fn from(error: io::Error) -> Self {
        let kind = [
            (io::ErrorKind::NotFound, tags::IO_ERROR_KIND_NOT_FOUND),
            (
                io::ErrorKind::PermissionDenied,
                tags::IO_ERROR_KIND_PERMISSION_DENIED,
            ),
            (
                io::ErrorKind::AlreadyExists,
                tags::IO_ERROR_KIND_ALREADY_EXISTS,
            ),
            (
                io::ErrorKind::IsADirectory,
                tags::IO_ERROR_KIND_IS_DIRECTORY,
            ),
            (
                io::ErrorKind::NotADirectory,
                tags::IO_ERROR_KIND_NOT_DIRECTORY,
            ),
            (
                io::ErrorKind::DirectoryNotEmpty,
                tags::IO_ERROR_KIND_DIRECTORY_NOT_EMPTY,
            ),
            (
                io::ErrorKind::InvalidInput,
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
        ]
        .into_iter()
        .find_map(|(kind, tag)| (error.kind() == kind).then_some(tag))
        .unwrap_or(tags::IO_ERROR_KIND_OTHER);
        Self {
            kind,
            reason: error.to_string(),
        }
    }
}

fn read_limited(path: &Path) -> Result<Vec<u8>, IoFailure> {
    let file = File::open(path)?;
    let mut bytes = Vec::new();
    // 不明な長さの入力は上限より 1 バイト多い分まで読み、VM 側で上限を判定する
    // （設計書 02-09「一つの操作で作る値の大きさの上限」）。
    file.take(MAX_STRING_BYTES.saturating_add(1))
        .read_to_end(&mut bytes)?;
    Ok(bytes)
}

fn read_text_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Vec<u8>, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let failure = match output {
        Ok(bytes) => {
            let len = u64::try_from(bytes.len())
                .map_err(|_| Stop::Internal("input length does not fit u64".into()))?;
            if len > MAX_STRING_BYTES {
                return Err(Stop::Resource(ResourceError::InputTooLarge {
                    function: "Sample.readText",
                    unit: SizeUnit::Bytes,
                    limit: MAX_STRING_BYTES,
                }));
            }
            // 外部のバイト列の検査は、文字列の値の API に集める（設計書 02-09「組み込みの操作とハンドラ表」）。
            if let Some(value) = ctx.alloc_str_utf8(&bytes, "Sample.readText")? {
                return ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value]);
            }
            IoFailure {
                kind: tags::IO_ERROR_KIND_INVALID_UTF8,
                reason: text::INVALID_UTF8.into(),
            }
        }
        Err(failure) => failure,
    };
    let reason = ctx.alloc_str(&failure.reason, "Sample.readText")?;
    let error = ctx.alloc_fields(FieldsKind::IoError, failure.kind, &[reason])?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])
}

builtin! {
    /// 基準のディレクトリからファイルを読み、完了の処理で文字列の値にする（設計書 02-09「組み込みの操作とハンドラ表」）。
    name = "Sample.readText",
    io fn file_read_text(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_lent| read_limited(&path),
            read_text_done,
        ))))
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use std::ffi::OsString;
    use std::path::PathBuf;

    use super::*;
    use crate::builtins::iface::{
        CallCtx, Capability, IoServices, OsResource, Reply, StateReply, WaitRequest,
    };
    use crate::builtins::table::{call_builtin, complete_worker};
    use crate::bytecode::program::ProtoIdx;
    use crate::runtime::heap::{Heap, HeapConfig, ResourceId};
    use crate::runtime::{ResourceKind, Stream};
    use crate::vm::InstrRef;

    struct TestIo {
        directory: PathBuf,
    }

    impl IoServices for TestIo {
        fn write_output(&mut self, _stream: Stream, _text: &str) -> Result<Option<IoWait>, Stop> {
            panic!("sample must not write output")
        }
        fn arguments(&self) -> &[String] {
            &[]
        }
        fn script_directory(&self) -> &Path {
            &self.directory
        }
        fn working_directory(&self) -> &Path {
            &self.directory
        }
        fn environment_variable(&self, _name: &str) -> Option<OsString> {
            None
        }
        fn now_millis(&self) -> i64 {
            0
        }
        fn local_offset_minutes(&self) -> i32 {
            0
        }
        fn monotonic_millis(&self) -> i64 {
            0
        }
        fn random_u64(&mut self) -> u64 {
            panic!("sample must not use random numbers")
        }
        fn register_resource(
            &mut self,
            _kind: ResourceKind,
            _handle: Box<dyn OsResource>,
            _opened_at: Option<InstrRef>,
        ) -> ResourceId {
            panic!("sample must not register a resource")
        }
    }

    struct TempDirectory(PathBuf);

    impl TempDirectory {
        fn new() -> Self {
            // 作業ディレクトリの外を変えず、並行するテスト実行とも名前を重ねない
            // （R07 の受け入れテストの一時ディレクトリ）。
            let base = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target");
            std::fs::create_dir_all(&base).unwrap();
            for attempt in 0..1000 {
                let path = base.join(format!("r07-samples-{}-{attempt}", std::process::id()));
                match std::fs::create_dir(&path) {
                    Ok(()) => return Self(path),
                    Err(error) if error.kind() == io::ErrorKind::AlreadyExists => {}
                    Err(error) => panic!("cannot create sample test directory: {error}"),
                }
            }
            panic!("no unused sample test directory")
        }
    }

    impl Drop for TempDirectory {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).unwrap();
        }
    }

    #[test]
    fn absolute_body_and_wrapper_report_overflow() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (input, expected) in [
                (-5, Ok(5)),
                (i64::MIN, Err(Stop::Runtime(RuntimeError::IntegerOverflow))),
            ] {
                let call = CallCtx::new(ctx, None, None, None);
                assert_eq!(integer_absolute(call.pure_ctx(), input), expected);
                let wrapped = call_builtin(
                    &integer_absolute::DECL,
                    ctx,
                    None,
                    None,
                    None,
                    &[Value::Int(input)],
                );
                match expected {
                    Ok(n) => assert!(
                        matches!(wrapped, Ok(Reply::Done(Value::Int(actual))) if actual == n)
                    ),
                    Err(error) => assert_eq!(wrapped.unwrap_err(), error),
                }
            }
        });
    }

    #[test]
    fn repeat_body_and_wrapper_check_size_before_allocation() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (s, n, expected) in [
                ("ab", 3, "ababab"),
                ("ab", 0, ""),
                ("ab", -5, ""),
                ("", i64::MAX, ""),
                ("あ", 2, "ああ"),
            ] {
                let input = ctx.alloc_str(s, "test").unwrap();
                let call = CallCtx::new(ctx, None, None, None);
                let direct = string_repeat(call.pure_ctx(), s, n).unwrap();
                assert_eq!(ctx.str(direct), Some(expected));
                let Reply::Done(wrapped) = call_builtin(
                    &string_repeat::DECL,
                    ctx,
                    None,
                    None,
                    None,
                    &[input, Value::Int(n)],
                )
                .unwrap() else {
                    panic!("pure repeat must finish")
                };
                assert_eq!(ctx.str(wrapped), Some(expected));
            }
        });

        let before = heap.stats().allocations;
        heap.epoch(|ctx| {
            for (s, n, size) in [
                (
                    "ab",
                    i64::try_from(MAX_STRING_BYTES / 2 + 1).unwrap(),
                    MAX_STRING_BYTES + 2,
                ),
                ("abc", i64::MAX, u64::MAX),
            ] {
                let call = CallCtx::new(ctx, None, None, None);
                assert_eq!(
                    string_repeat(call.pure_ctx(), s, n).unwrap_err(),
                    Stop::Resource(ResourceError::ValueTooLarge {
                        function: "Sample.repeat",
                        size,
                        unit: SizeUnit::Bytes,
                        limit: MAX_STRING_BYTES,
                    })
                );
            }
        });
        assert_eq!(heap.stats().allocations, before);

        let mut input = heap.epoch(|ctx| ctx.new_slot(ctx.alloc_str("ab", "test").unwrap()));
        let before = heap.stats().allocations;
        heap.epoch(|ctx| {
            let value = ctx.load(&input);
            for n in [i64::try_from(MAX_STRING_BYTES / 2 + 1).unwrap(), i64::MAX] {
                assert!(matches!(
                    call_builtin(
                        &string_repeat::DECL,
                        ctx,
                        None,
                        None,
                        None,
                        &[value, Value::Int(n)]
                    ),
                    Err(Stop::Resource(ResourceError::ValueTooLarge {
                        function: "Sample.repeat",
                        ..
                    }))
                ));
            }
            ctx.clear(&mut input);
        });
        assert_eq!(heap.stats().allocations, before);
    }

    #[test]
    fn declarations_and_wrappers_reject_argument_mismatches() {
        let directory = TempDirectory::new();
        let mut io = TestIo {
            directory: directory.0.clone(),
        };
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let string = ctx.alloc_str("ab", "test").unwrap();
            for (decl, name, capability, arity, invalid) in [
                (
                    integer_absolute::DECL,
                    "Sample.absolute",
                    Capability::Pure,
                    1,
                    vec![
                        vec![],
                        vec![Value::Int(1), Value::Int(2)],
                        vec![Value::Bool(true)],
                    ],
                ),
                (
                    string_repeat::DECL,
                    "Sample.repeat",
                    Capability::Pure,
                    2,
                    vec![
                        vec![string],
                        vec![string, Value::Int(2), Value::Unit],
                        vec![Value::Int(1), Value::Int(2)],
                        vec![string, string],
                    ],
                ),
                (
                    file_read_text::DECL,
                    "Sample.readText",
                    Capability::Io,
                    1,
                    vec![vec![], vec![string, string], vec![Value::Int(1)]],
                ),
            ] {
                assert_eq!(
                    (decl.name, decl.capability, decl.arity),
                    (name, capability, arity)
                );
                for args in invalid {
                    assert_eq!(
                        call_builtin(&decl, ctx, Some(&mut io), None, None, &args).unwrap_err(),
                        Stop::Internal(format!("builtin {name}: argument count or kind mismatch"))
                    );
                }
            }
        });
    }

    #[test]
    fn read_text_body_and_wrapper_complete_files_and_failures() {
        let directory = TempDirectory::new();
        std::fs::write(directory.0.join("valid"), "hello あ\n").unwrap();
        std::fs::write(directory.0.join("invalid"), [0xff, 0xfe]).unwrap();
        let mut io = TestIo {
            directory: directory.0.clone(),
        };
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (path, error_tag) in [("valid", None), ("missing", Some(0)), ("invalid", Some(6))] {
                let input = ctx.alloc_str(path, "test").unwrap();
                for direct in [true, false] {
                    let wait = if direct {
                        let mut call = CallCtx::new(ctx, Some(&mut io), None, None);
                        let IoReply::Wait(IoWait::Worker(wait)) =
                            file_read_text(call.io_ctx().unwrap(), path).unwrap()
                        else {
                            panic!("readText must return a worker wait")
                        };
                        wait
                    } else {
                        let Reply::Wait(WaitRequest::Io(IoWait::Worker(wait))) = call_builtin(
                            &file_read_text::DECL,
                            ctx,
                            Some(&mut io),
                            None,
                            None,
                            &[input],
                        )
                        .unwrap() else {
                            panic!("readText wrapper must return a worker wait")
                        };
                        wait
                    };
                    let result = complete_worker(wait, ctx, &mut io, None, &[input]).unwrap();
                    assert_eq!(ctx.fields_len(result), Some(1));
                    let value = ctx.field(result, 0).unwrap();
                    if let Some(tag) = error_tag {
                        assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, 1)));
                        assert_eq!(ctx.fields_header(value), Some((FieldsKind::IoError, tag)));
                        assert_eq!(ctx.fields_len(value), Some(1));
                        let reason = ctx.str(ctx.field(value, 0).unwrap()).unwrap();
                        assert!(!reason.is_empty());
                    } else {
                        assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, 0)));
                        assert_eq!(ctx.str(value), Some("hello あ\n"));
                    }
                }
            }
        });
    }

    builtin! {
        /// State の口がない呼び出しを確かめるための宣言。
        name = "Test.state",
        state fn state_sample(ctx) -> StateReply<'e> {
            let _ = ctx;
            Ok(StateReply::Done(Value::Unit))
        }
    }

    #[test]
    fn calls_require_services_for_their_capability() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let path = ctx.alloc_str("unused", "test").unwrap();
            assert_eq!(
                call_builtin(&file_read_text::DECL, ctx, None, None, None, &[path]).unwrap_err(),
                Stop::Internal("io builtin called without io services".into())
            );
            assert_eq!(
                call_builtin(&state_sample::DECL, ctx, None, None, None, &[]).unwrap_err(),
                Stop::Internal("state builtin called without state services".into())
            );
        });
    }

    fn unexpected_completion<'c, 'e>(
        _ctx: &mut IoCtx<'c, 'e>,
        _output: (),
        _args: &[Value<'e>],
    ) -> Result<Value<'e>, Stop> {
        panic!("rejected worker must not complete")
    }

    #[test]
    fn stage_one_rejects_lending_before_running_the_job() {
        let directory = TempDirectory::new();
        let mut io = TestIo {
            directory: directory.0.clone(),
        };
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for lend in [Lend::Stdin, Lend::Resource(ResourceId(1))] {
                let wait = WorkerWait::new(
                    lend,
                    |_lent| panic!("rejected worker must not run"),
                    unexpected_completion,
                );
                assert_eq!(
                    complete_worker(wait, ctx, &mut io, None, &[]).unwrap_err(),
                    Stop::Internal("stage 1 worker cannot borrow resources or stdin".into())
                );
            }
        });
    }

    fn complete_with_arguments<'c, 'e>(
        ctx: &mut IoCtx<'c, 'e>,
        output: i64,
        args: &[Value<'e>],
    ) -> Result<Value<'e>, Stop> {
        assert_eq!(
            ctx.site(),
            Some(InstrRef {
                proto: ProtoIdx(2),
                pc: 3
            })
        );
        assert_eq!(args.len(), 1);
        Ok(Value::Int(output + args[0].as_int().unwrap()))
    }

    #[test]
    fn worker_completion_receives_call_site_and_arguments() {
        let directory = TempDirectory::new();
        let mut io = TestIo {
            directory: directory.0.clone(),
        };
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let wait = WorkerWait::new(Lend::Nothing, |_lent| 5_i64, complete_with_arguments);
            let result = complete_worker(
                wait,
                ctx,
                &mut io,
                Some(InstrRef {
                    proto: ProtoIdx(2),
                    pc: 3,
                }),
                &[Value::Int(7)],
            )
            .unwrap();
            assert_eq!(result.as_int(), Some(12));
        });
    }
}
