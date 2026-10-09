//! Process.exit の引数の範囲と応答（実装プラン R29）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]
use super::super::runtime_test_support::runtime;
use super::*;
use crate::builtins::iface::CallCtx;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::sched::testing::ScheduleHandle;
// 関門: 終了状態の範囲の境界を本体で確かめる。プログラムの停止テストは正常な一値だけを使う。
#[test]
fn exit_validates_both_endpoints_and_rejects_out_of_domain_codes() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(
        std::path::Path::new("/"),
        crate::vm::ExecMode::Direct,
        &script,
    );
    let mut resources = crate::runtime::io::resources::ResourceTable::default();
    let mut services = crate::runtime::io::services::IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for code in [0, 255] {
            assert!(matches!(exit(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), code).unwrap(), IoReply::Exit(crate::builtins::iface::ExitStatus(n)) if i64::from(n) == code));
        }
        for code in [-1, 256, i64::MIN, i64::MAX] {
            assert!(matches!(exit(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), code), Err(Stop::Runtime(crate::runtime::RuntimeError::ArgumentOutOfDomain { function: "Benitoite.IO.Process.exit", argument: 0 }))));
        }
    });
}

use super::super::runtime_test_support::{error_kind, line, payload};
use super::super::stage1_io::TestIo;
use crate::builtins::iface::{IoServices, IoWait, OsResource};
use crate::runtime::heap::ResourceId;
use crate::runtime::io::services::RunInput;
use crate::runtime::{ResourceKind, Stream};
use crate::vm::InstrRef;
use std::ffi::OsString;
use std::os::unix::ffi::OsStringExt;
use std::path::Path;

// 環境変数名は OS に渡す前に検査する契約も確かめる。戻り値だけでは
// 検査の位置の退行を検出できないので、外部の環境の口で不正な名を拒む。
struct Environment(TestIo);
impl IoServices for Environment {
    fn environment_variable(&self, name: &str) -> Option<OsString> {
        assert!(
            !name.is_empty() && !name.contains(['\0', '=']),
            "invalid name reached services"
        );
        self.0.environment_variable(name)
    }
    fn arguments(&self) -> &[String] {
        self.0.arguments()
    }
    fn script_directory(&self) -> &Path {
        self.0.script_directory()
    }
    fn working_directory(&self) -> &Path {
        self.0.working_directory()
    }
    fn now_millis(&self) -> i64 {
        self.0.now_millis()
    }
    fn local_offset_minutes(&self) -> i32 {
        self.0.local_offset_minutes()
    }
    fn monotonic_millis(&self) -> i64 {
        self.0.monotonic_millis()
    }
    fn random_u64(&mut self) -> u64 {
        self.0.random_u64()
    }
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop> {
        self.0.write_output(stream, text)
    }
    fn register_resource(
        &mut self,
        kind: ResourceKind,
        handle: Box<dyn OsResource>,
        opened_at: Option<InstrRef>,
    ) -> ResourceId {
        self.0.register_resource(kind, handle, opened_at)
    }
}

// 関門: 未定義、空の値、無効な UTF-8、不正な名前を、新しい本体の応答で区別する。
// stage1_io のテストは外部の部品自体のテストであり、この本体の検査と変換には届かない。
#[test]
fn environment_variable_validates_names_and_preserves_values() {
    let mut io = Environment(TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/work".into(),
        script_directory: "/scripts".into(),
    }));
    for (name, value) in [
        ("DEFINED", OsString::from("値")),
        ("EMPTY", OsString::new()),
        ("INVALID", OsString::from_vec(vec![0xff])),
    ] {
        io.0.environment.insert(name.into(), value);
    }
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (name, expected) in [
            ("DEFINED", Some("値")),
            ("EMPTY", Some("")),
            ("MISSING", None),
        ] {
            let arg = ctx.alloc_str(name, "test").unwrap();
            let reply = environment_variable(
                CallCtx::new(ctx, Some(&mut io), None, None)
                    .io_ctx()
                    .unwrap(),
                arg,
            )
            .unwrap();
            let IoReply::Done(value) = reply else {
                unreachable!()
            };
            assert_eq!(line(ctx, value).as_deref(), expected);
        }
        for (name, kind) in [
            ("", tags::IO_ERROR_KIND_INVALID_INPUT),
            ("a=b", tags::IO_ERROR_KIND_INVALID_INPUT),
            ("a\0b", tags::IO_ERROR_KIND_INVALID_INPUT),
            ("INVALID", tags::IO_ERROR_KIND_INVALID_UTF8),
        ] {
            let arg = ctx.alloc_str(name, "test").unwrap();
            let IoReply::Done(value) = environment_variable(
                CallCtx::new(ctx, Some(&mut io), None, None)
                    .io_ctx()
                    .unwrap(),
                arg,
            )
            .unwrap() else {
                unreachable!()
            };
            assert_eq!(error_kind(ctx, value), kind, "{name:?}");
        }
    });
}

// 関門: プロセスの cwd ではなく、別々に与えた二つのディレクトリを読む。
// 無効な UTF-8 は scriptDirectory では不具合、workingDirectory では IOError になる。
#[test]
fn directories_use_run_input_and_reject_invalid_utf8() {
    let mut io = TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/work/資料".into(),
        script_directory: "/scripts".into(),
    });
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let IoReply::Done(value) = script_directory(
            CallCtx::new(ctx, Some(&mut io), None, None)
                .io_ctx()
                .unwrap(),
        )
        .unwrap() else {
            unreachable!()
        };
        assert_eq!(ctx.str(value), Some("/scripts"));
        let IoReply::Done(value) = working_directory(
            CallCtx::new(ctx, Some(&mut io), None, None)
                .io_ctx()
                .unwrap(),
        )
        .unwrap() else {
            unreachable!()
        };
        assert_eq!(
            ctx.str(payload(ctx, value, tags::RESULT_OK)),
            Some("/work/資料")
        );
        let bad = std::path::PathBuf::from(OsString::from_vec(b"/bad\xff".to_vec()));
        let mut io = TestIo::new(RunInput {
            arguments: vec![],
            working_directory: bad.clone(),
            script_directory: bad,
        });
        assert!(matches!(
            script_directory(
                CallCtx::new(ctx, Some(&mut io), None, None)
                    .io_ctx()
                    .unwrap()
            ),
            Err(Stop::Internal(_))
        ));
        let IoReply::Done(value) = working_directory(
            CallCtx::new(ctx, Some(&mut io), None, None)
                .io_ctx()
                .unwrap(),
        )
        .unwrap() else {
            unreachable!()
        };
        assert_eq!(error_kind(ctx, value), tags::IO_ERROR_KIND_INVALID_UTF8);
    });
}
