//! 標準入力を借り、完了で UTF-8 の行と残りを作る契約（実装プラン R29）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]
use super::super::runtime_test_support::*;
use super::*;
use crate::builtins::iface::CallCtx;
use crate::builtins::table::tags;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::io::resources::ResourceTable;
use crate::runtime::io::services::IoView;
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::ExecMode;
// 関門: 一行の区切り、終端、無効な UTF-8 と、二操作が読み手の位置を共有する契約。
// 既存の Console テストは書き込みだけであり、仕事から完了までを通す。
#[test]
fn read_line_handles_line_endings_eof_and_invalid_utf8() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(std::path::Path::new("/"), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut services = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for &(bytes, expected) in LINE_CASES {
            let mut input = std::io::Cursor::new(bytes);
            for &expected in expected {
                let work = worker(
                    read_line(
                        CallCtx::new(ctx, Some(&mut services), None, None)
                            .io_ctx()
                            .unwrap(),
                    )
                    .unwrap(),
                );
                assert_eq!(work.lend(), Lend::Stdin);
                assert!(work.needs_output_flush());
                let done = work.run(Lent::Stdin(&mut input));
                let result = done
                    .complete(
                        &mut CallCtx::new(ctx, Some(&mut services), None, None)
                            .io_ctx()
                            .unwrap(),
                        &[],
                    )
                    .unwrap();
                assert_eq!(line(ctx, result).as_deref(), expected, "{bytes:?}");
            }
        }
        let mut input = std::io::Cursor::new(b"\xff\n");
        let work = worker(
            read_line(
                CallCtx::new(ctx, Some(&mut services), None, None)
                    .io_ctx()
                    .unwrap(),
            )
            .unwrap(),
        );
        let done = work.run(Lent::Stdin(&mut input));
        let result = done
            .complete(
                &mut CallCtx::new(ctx, Some(&mut services), None, None)
                    .io_ctx()
                    .unwrap(),
                &[],
            )
            .unwrap();
        assert_eq!(error_kind(ctx, result), tags::IO_ERROR_KIND_INVALID_UTF8);
    });
}
#[test]
fn read_all_returns_only_the_remaining_bytes_and_checks_utf8() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(std::path::Path::new("/"), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut services = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (bytes, expected) in [
            (b"first\r\nnext\nlast".as_slice(), Some("next\nlast")),
            (b"first\n".as_slice(), Some("")),
            (b"first\n\xff".as_slice(), None),
        ] {
            let mut input = std::io::Cursor::new(bytes);
            let work = worker(
                read_line(
                    CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                )
                .unwrap(),
            );
            let done = work.run(Lent::Stdin(&mut input));
            let result = done
                .complete(
                    &mut CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    &[],
                )
                .unwrap();
            assert_eq!(line(ctx, result).as_deref(), Some("first"));
            let work = worker(
                read_all(
                    CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                )
                .unwrap(),
            );
            assert_eq!(work.lend(), Lend::Stdin);
            assert!(work.needs_output_flush());
            let done = work.run(Lent::Stdin(&mut input));
            let result = done
                .complete(
                    &mut CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    &[],
                )
                .unwrap();
            match expected {
                Some(text) => {
                    assert_eq!(ctx.str(payload(ctx, result, tags::RESULT_OK)), Some(text))
                }
                None => assert_eq!(error_kind(ctx, result), tags::IO_ERROR_KIND_INVALID_UTF8),
            }
        }
    });
}

// 関門: worker を出す時点でプロンプトが出力先へ届いていることを確認する。
// 単体テストの after_output_flush の印だけでは、出力の完了を待つ経路の誤りを捕まえない。
#[test]
fn prompt_reaches_output_before_stdin_work_starts() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Console.Read,Console.Write
 Console.write("Name: ")
 bind name <- try Console.readLine() |> Result.mapError(_,IOError.message)
 return if name = Option.Some("Ada") then Result.Ok(()) else Result.Error("wrong input") end if
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (mut rt, output) = runtime(std::path::Path::new("/"), mode, &script);
        rt.stdin = Some(Box::new(std::io::Cursor::new(b"Ada\n".to_vec())));
        let inner = std::mem::replace(&mut rt.parts.workers, script.parts().workers);
        rt.parts.workers = Box::new(ScriptedWorkers {
            inner,
            script: script.clone(),
            hold_resources: false,
            resource_jobs: Default::default(),
            before_stdin: Some(std::sync::Arc::clone(&output)),
        });
        let mut vm = crate::vm::Vm::new(
            &program,
            crate::vm::VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert_eq!(
            finish(&mut vm, &mut rt),
            crate::vm::VmStep::Finished(crate::vm::MainOutcome::Ok)
        );
        assert_eq!(*output.lock().unwrap(), b"Name: ");
        assert!(script.record().events.iter().any(|e| matches!(
            e,
            crate::runtime::sched::testing::ScheduleEvent::WorkerRan(_)
        )));
        consumed(&script);
    }
}

#[derive(Debug)]
struct FailedInput(std::io::ErrorKind);
impl std::io::Read for FailedInput {
    fn read(&mut self, _bytes: &mut [u8]) -> std::io::Result<usize> {
        Err(std::io::Error::from(self.0))
    }
}
impl std::io::BufRead for FailedInput {
    fn fill_buf(&mut self) -> std::io::Result<&[u8]> {
        Err(std::io::Error::from(self.0))
    }
    fn consume(&mut self, _amount: usize) {}
}
// 関門: OS の分類を読み取りの仕事から Result.Error まで通して確かめる。
// 生の OS の失敗だけを与え、期待する言語の種類や値はテストダブルで作らない。
// L10 の二操作も同じ表を通し、共通のエラー変換のテストを重ねない。
#[test]
fn input_failures_keep_the_os_message_and_classify_error_kinds() {
    use std::io::ErrorKind;
    let cases = [
        (ErrorKind::NotFound, tags::IO_ERROR_KIND_NOT_FOUND),
        (
            ErrorKind::PermissionDenied,
            tags::IO_ERROR_KIND_PERMISSION_DENIED,
        ),
        (ErrorKind::AlreadyExists, tags::IO_ERROR_KIND_ALREADY_EXISTS),
        (ErrorKind::IsADirectory, tags::IO_ERROR_KIND_IS_DIRECTORY),
        (ErrorKind::NotADirectory, tags::IO_ERROR_KIND_NOT_DIRECTORY),
        (
            ErrorKind::DirectoryNotEmpty,
            tags::IO_ERROR_KIND_DIRECTORY_NOT_EMPTY,
        ),
        (ErrorKind::InvalidInput, tags::IO_ERROR_KIND_INVALID_INPUT),
        (ErrorKind::InvalidData, tags::IO_ERROR_KIND_INVALID_UTF8),
        (ErrorKind::BrokenPipe, tags::IO_ERROR_KIND_OTHER),
    ];
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(std::path::Path::new("/"), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut services = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (os_kind, kind) in cases {
            for read in [read_line, read_all, read_all_lines, read_all_bytes] {
                let mut call = CallCtx::new(ctx, Some(&mut services), None, None);
                let reply = read(call.io_ctx().unwrap());
                let done = worker(reply.unwrap()).run(Lent::Stdin(&mut FailedInput(os_kind)));
                let result = done
                    .complete(
                        &mut CallCtx::new(ctx, Some(&mut services), None, None)
                            .io_ctx()
                            .unwrap(),
                        &[],
                    )
                    .unwrap();
                assert_eq!(error_kind(ctx, result), kind);
                let error = payload(ctx, result, tags::RESULT_ERROR);
                assert_eq!(
                    ctx.str(ctx.field(error, 0).unwrap()),
                    Some(std::io::Error::from(os_kind).to_string().as_str())
                );
            }
        }
    });
}

// 関門: 新しい二操作の行の区切り、残りの位置、UTF-8 の拒否とバイト列の保持を
// 仕事から完了まで通す。既存のテストは readAll の文字列だけであり、新しい戻り値を扱わない。
// 作業 L10 は本体ごとの単体テストを明示しているので、この境界で直接呼ぶ。
#[test]
fn read_all_lines_and_bytes_preserve_input_contracts() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(std::path::Path::new("/"), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut services = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for &(bytes, expected) in &[
            (b"a\r\nb\n".as_slice(), ["a", "b"].as_slice()),
            (b"".as_slice(), [].as_slice()),
            (b"\n\r\n\r\r".as_slice(), ["", "", "\r"].as_slice()),
        ] {
            let mut input = std::io::Cursor::new(bytes);
            let work = worker(
                read_all_lines(
                    CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                )
                .unwrap(),
            );
            assert_eq!(work.lend(), Lend::Stdin);
            assert!(work.needs_output_flush());
            let result = work
                .run(Lent::Stdin(&mut input))
                .complete(
                    &mut CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    &[],
                )
                .unwrap();
            let values =
                crate::runtime::list::to_vec(ctx, payload(ctx, result, tags::RESULT_OK)).unwrap();
            assert_eq!(
                values
                    .iter()
                    .map(|&v| ctx.str(v).unwrap())
                    .collect::<Vec<_>>(),
                expected
            );
        }
        for raw in [false, true] {
            for bytes in [b"first\nlast\r\n".as_slice(), b"first\n\xff\0".as_slice()] {
                let mut input = std::io::Cursor::new(bytes);
                let result = worker(
                    read_line(
                        CallCtx::new(ctx, Some(&mut services), None, None)
                            .io_ctx()
                            .unwrap(),
                    )
                    .unwrap(),
                )
                .run(Lent::Stdin(&mut input))
                .complete(
                    &mut CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    &[],
                )
                .unwrap();
                assert_eq!(line(ctx, result).as_deref(), Some("first"));
                let work = worker(
                    if raw {
                        read_all_bytes(
                            CallCtx::new(ctx, Some(&mut services), None, None)
                                .io_ctx()
                                .unwrap(),
                        )
                    } else {
                        read_all_lines(
                            CallCtx::new(ctx, Some(&mut services), None, None)
                                .io_ctx()
                                .unwrap(),
                        )
                    }
                    .unwrap(),
                );
                assert_eq!(work.lend(), Lend::Stdin);
                assert!(work.needs_output_flush());
                let result = work
                    .run(Lent::Stdin(&mut input))
                    .complete(
                        &mut CallCtx::new(ctx, Some(&mut services), None, None)
                            .io_ctx()
                            .unwrap(),
                        &[],
                    )
                    .unwrap();
                if raw {
                    assert_eq!(
                        ctx.bytes(payload(ctx, result, tags::RESULT_OK)).unwrap(),
                        bytes.strip_prefix(b"first\n").unwrap()
                    );
                } else if bytes.contains(&0xff) {
                    assert_eq!(error_kind(ctx, result), tags::IO_ERROR_KIND_INVALID_UTF8);
                } else {
                    let values =
                        crate::runtime::list::to_vec(ctx, payload(ctx, result, tags::RESULT_OK))
                            .unwrap();
                    assert_eq!(values.len(), 1);
                    assert_eq!(ctx.str(*values.first().unwrap()), Some("last"));
                }
            }
        }
    });
}

// 関門: 行が短ければバイト数の上限より先にリストの上限に達する。
// 上限を超える行数でも、各行を確保し始めず資源の不足を返す契約を本体で守る。
#[test]
fn read_all_lines_checks_element_limit_before_building_lines() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(std::path::Path::new("/"), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut services = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    let size = usize::try_from(crate::runtime::MAX_LIST_LEN.saturating_add(1)).unwrap();
    let mut input = std::io::Cursor::new(vec![b'\n'; size]);
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let work = worker(
            read_all_lines(
                CallCtx::new(ctx, Some(&mut services), None, None)
                    .io_ctx()
                    .unwrap(),
            )
            .unwrap(),
        );
        let result = work.run(Lent::Stdin(&mut input)).complete(
            &mut CallCtx::new(ctx, Some(&mut services), None, None)
                .io_ctx()
                .unwrap(),
            &[],
        );
        assert!(matches!(
            result,
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "Benitoite.IO.Console.readAllLines",
                unit: SizeUnit::Elements,
                ..
            }))
        ));
    });
}
