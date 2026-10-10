//! HTTP の値の契約と解放の失敗（実装プラン L30、設計書 03-09「サーバ」、02-09「リソースの追跡」）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
use super::*;
use crate::builtins::funcs::runtime_test_support::*;
use crate::builtins::iface::{CallCtx, OsResource};
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::io::resources::{ResourceContent, ResourceTable};
use crate::runtime::io::services::IoView;
use crate::runtime::sched::testing::ScheduleHandle;
use crate::runtime::sched::{ExtOpId, Scheduler};
use crate::vm::{ExecMode, state::Stage1StateServices};
#[derive(Debug)]
struct FailRelease;
impl OsResource for FailRelease {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        Err("fake close failure".into())
    }
}
// 関門: port の位置と範囲を、本番の関数で確認する。OS の bind に依存しない。
#[test]
fn listen_port_checks_argument_one_before_io() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for port in [-1, 65536] {
            let mut io = IoView {
                rt: &mut rt,
                resources: &mut resources,
            };
            assert!(matches!(
                listen(
                    CallCtx::new(ctx, Some(&mut io), None, None)
                        .io_ctx()
                        .unwrap(),
                    "127.0.0.1",
                    port
                ),
                Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                    argument: 1,
                    ..
                }))
            ));
        }
        for port in [0, 65535] {
            let mut io = IoView {
                rt: &mut rt,
                resources: &mut resources,
            };
            assert!(matches!(
                listen(
                    CallCtx::new(ctx, Some(&mut io), None, None)
                        .io_ctx()
                        .unwrap(),
                    "127.0.0.1",
                    port
                )
                .unwrap(),
                IoReply::Wait(IoWait::Worker(_))
            ));
        }
    });
}
// 関門: 純粋と宣言する requestOf が内部の State の口から宣言順で要求を作る。
// 解析器のテストだけではレコードの欄と Pair/List への変換を検査できない。
#[test]
fn request_record_fields_and_release_check() {
    let mut resources = ResourceTable::default();
    let mut scheduler = Scheduler::default();
    let id = resources.insert(
        ResourceKind::HttpExchange,
        ResourceContent::Os(Some(Box::new(FailRelease))),
        None,
    );
    resources.attachments.insert(
        id,
        Box::new(RequestData {
            method: "POST".into(),
            path: "/path".into(),
            query: vec![
                ("q".into(), "a b c".into()),
                ("bad".into(), "%G0".into()),
                ("a".into(), "".into()),
            ],
            headers: vec![
                ("x-test".into(), "one".into()),
                ("x-test".into(), "two".into()),
            ],
            body: b"abc".to_vec(),
        }),
    );
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let mut state = Stage1StateServices {
            resources: &mut resources,
            scheduler: &mut scheduler,
        };
        let StateReply::Done(request) = request_of(
            CallCtx::new(ctx, None, Some(&mut state), None)
                .state_ctx()
                .unwrap(),
            id,
        )
        .unwrap() else {
            panic!("request waited")
        };
        assert_eq!(ctx.str(ctx.field(request, 0).unwrap()), Some("POST"));
        assert_eq!(ctx.str(ctx.field(request, 1).unwrap()), Some("/path"));
        assert_eq!(
            read_pairs(ctx, ctx.field(request, 2).unwrap()).unwrap(),
            [
                ("q".into(), "a b c".into()),
                ("bad".into(), "%G0".into()),
                ("a".into(), "".into())
            ]
        );
        assert_eq!(
            read_pairs(ctx, ctx.field(request, 3).unwrap()).unwrap(),
            [
                ("x-test".into(), "one".into()),
                ("x-test".into(), "two".into())
            ]
        );
        assert_eq!(
            ctx.bytes(ctx.field(request, 4).unwrap()),
            Some(b"abc".as_slice())
        );
        resources.request_release(id, ExtOpId(1));
        let mut state = Stage1StateServices {
            resources: &mut resources,
            scheduler: &mut scheduler,
        };
        assert!(matches!(
            request_of(
                CallCtx::new(ctx, None, Some(&mut state), None)
                    .state_ctx()
                    .unwrap(),
                id
            ),
            Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed {
                kind: ResourceKind::HttpExchange
            }))
        ));
    });
}
// 関門: 明示 close は解放の理由を NetworkError.Other として返す（設計書 02-09「リソースの追跡」）。
// L30 の指定により失敗を返す OsResource を入れ、OS の特定の失敗に依存しない。
#[test]
fn explicit_close_returns_other_and_then_release_is_idempotent() {
    for kind in [ResourceKind::HttpListener, ResourceKind::HttpExchange] {
        let mut resources = ResourceTable::default();
        let mut scheduler = Scheduler::default();
        let id = resources.insert(kind, ResourceContent::Os(Some(Box::new(FailRelease))), None);
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let mut state = Stage1StateServices {
                resources: &mut resources,
                scheduler: &mut scheduler,
            };
            let first = close(
                CallCtx::new(ctx, None, Some(&mut state), None)
                    .state_ctx()
                    .unwrap(),
                id,
                "test",
            )
            .unwrap();
            let result = if let StateReply::Done(result) = first {
                result
            } else {
                let (id, _, handle) = resources.take_release_job().unwrap();
                resources.finish_release(id, handle.release());
                let mut state = Stage1StateServices {
                    resources: &mut resources,
                    scheduler: &mut scheduler,
                };
                let StateReply::Done(result) = close(
                    CallCtx::new(ctx, None, Some(&mut state), None)
                        .state_ctx()
                        .unwrap(),
                    id,
                    "test",
                )
                .unwrap() else {
                    panic!("close waited twice")
                };
                result
            };
            let failure = payload(ctx, result, tags::RESULT_ERROR);
            assert_eq!(
                ctx.fields_header(failure),
                Some((FieldsKind::NetworkError, tags::NETWORK_ERROR_KIND_OTHER))
            );
            assert_eq!(
                ctx.str(ctx.field(failure, 0).unwrap()),
                Some("fake close failure")
            );
            let mut state = Stage1StateServices {
                resources: &mut resources,
                scheduler: &mut scheduler,
            };
            let StateReply::Done(result) = close(
                CallCtx::new(ctx, None, Some(&mut state), None)
                    .state_ctx()
                    .unwrap(),
                id,
                "test",
            )
            .unwrap() else {
                panic!("released close waited")
            };
            assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
        });
    }
}

#[derive(Debug)]
struct GoodRelease;
impl OsResource for GoodRelease {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        Ok(())
    }
}
builtin! {
    name = "Benitoite.Network.Http.listen",
    io fn fake_listen(ctx, host: &'c str, port: i64) -> IoReply<'e> {
        let mut ctx = ctx; let _ = port;
        let handle: Box<dyn OsResource> = if host == "fails" { Box::new(FailRelease) } else { Box::new(GoodRelease) };
        let site = ctx.site();
        let id = ctx.services().register_resource(ResourceKind::HttpListener, handle, site);
        Ok(IoReply::Done(ok(&ctx, Value::Resource(id))?))
    }
}
builtin! {
    name = "Benitoite.Network.Http.accept",
    io fn fake_accept(ctx, listener: ResourceId) -> IoReply<'e> {
        let mut ctx = ctx; let _ = listener;
        let site = ctx.site();
        let mut view = ctx.services().runtime_view().unwrap();
        assert!(view.resources.attachments.is_empty());
        let id = view.register_resource(ResourceKind::HttpExchange, Box::new(FailRelease), site);
        view.resources.attachments.insert(id, Box::new(RequestData { method: "GET".into(), path: "/".into(), query: vec![], headers: vec![], body: vec![] }));
        Ok(IoReply::Done(ok(&ctx, Value::Resource(id))?))
    }
}
builtin! {
    name = "Benitoite.Network.Http.listenerPort",
    io fn fake_port(ctx, listener: ResourceId) -> IoReply<'e> {
        let mut ctx = ctx; let _ = listener;
        let view = ctx.services().runtime_view().unwrap();
        assert!(view.resources.attachments.is_empty());
        assert!(view.resources.entries.values().filter(|entry| entry.kind == ResourceKind::HttpExchange).all(|entry| entry.state == ResourceState::Released));
        Ok(IoReply::Done(Value::Int(0)))
    }
}
// 関門: close で受け取った失敗は with を抜けるとき再報告しない。Exchange の
// with の失敗は捨てる（設計書 02-09「リソースの追跡」）。偽の release は L30 が指定する注入。
#[test]
fn close_failures_and_exchange_implicit_release_follow_vm_scopes() {
    use crate::vm::{MainOutcome, Vm, VmConfig, VmStep};
    let explicit_listener = r#"
function main() -> Result[Unit, String] uses Http.Listen, State
 with listener = try Http.listen("fails", 0) |> Result.mapError(_, NetworkError.message) do
  return match Http.closeListener(listener) with
   case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.Other and NetworkError.message(error) = "fake close failure" then Result.Ok(()) else Result.Error("close error") end if
   case Result.Ok(_) -> Result.Error("missing failure")
  end match
 end with
end function
"#;
    let repeat = if cfg!(feature = "gc-stress") { 8 } else { 16 };
    for body in [
        explicit_listener.to_owned(),
        format!(
            r#"
function requests(listener: Http.Listener, n: Integer) -> Result[Unit,String] uses Http.Listen, State
 if n = 0 then return Result.Ok(()) end if
 with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
  bind req <- Http.requestOf(exchange)
  if Http.Request.path(req) <> "/" or Http.Request.query(req) <> [] then return Result.Error("request") end if
 end with
 return requests(listener, n - 1)
end function
function main() -> Result[Unit,String] uses Http.Listen, State
 with listener = try Http.listen("good", 0) |> Result.mapError(_, NetworkError.message) do
  bind result <- requests(listener, {repeat})
  bind _ <- Http.listenerPort(listener)
  return result
 end with
end function
"#
        ),
    ] {
        let program = compile(&format!("import Benitoite.Unofficial.Network.Http\n{body}"));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let script = ScheduleHandle::new([], false);
            let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), mode, &script);
            permit_workers(&mut rt, &script);
            rt.builtin_overrides.insert(
                crate::builtins::lookup_builtin("Benitoite.Network.Http.listen").unwrap(),
                &fake_listen::DECL,
            );
            rt.builtin_overrides.insert(
                crate::builtins::lookup_builtin("Benitoite.Network.Http.accept").unwrap(),
                &fake_accept::DECL,
            );
            rt.builtin_overrides.insert(
                crate::builtins::lookup_builtin("Benitoite.Network.Http.listenerPort").unwrap(),
                &fake_port::DECL,
            );
            let mut vm = Vm::new(
                &program,
                VmConfig::default(),
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            assert_eq!(finish(&mut vm, &mut rt), VmStep::Finished(MainOutcome::Ok));
            consumed(&script);
        }
    }
}

// 関門: respond の範囲違反は応答が第二引数であることを示す（L30）。
#[test]
fn respond_status_checks_argument_one() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let empty = crate::runtime::list::from_values(ctx, &[], "test").unwrap();
        let body = ctx.alloc_bytes(&[], "test").unwrap();
        for status in [99, 600] {
            let response = ctx
                .alloc_fields(
                    FieldsKind::Ctor,
                    tags::RECORD,
                    &[Value::Int(status), empty, body],
                )
                .unwrap();
            let mut io = IoView {
                rt: &mut rt,
                resources: &mut resources,
            };
            assert!(matches!(
                respond(
                    CallCtx::new(ctx, Some(&mut io), None, None)
                        .io_ctx()
                        .unwrap(),
                    ResourceId(99),
                    response
                ),
                Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                    argument: 1,
                    ..
                }))
            ));
        }
    });
}
// 関門: 不正な応答ヘッダを送る前に第二引数の範囲違反として止める（設計書 03-09「サーバの接続と要求の読み方」）。
// 従来の応答テストは不正文字を含まない。実際の組み込み関数を呼び、
// 許す値は解放済みリソースの検査まで進むことを確かめ、差し込み口を加えない。
#[test]
fn respond_headers_reject_invalid_bytes_before_resource_access() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let id = resources.insert(
        ResourceKind::HttpExchange,
        ResourceContent::Os(Some(Box::new(GoodRelease))),
        None,
    );
    resources.request_release(id, ExtOpId(1));
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (name, value, valid) in [
            ("bad name", "ok", false), ("bad:name", "ok", false), ("bad\rname", "ok", false),
            ("", "ok", false), ("bad\tname", "ok", false), ("雪", "ok", false),
            ("x-test", "bad\rvalue", false), ("x-test", "bad\nvalue", false), ("x-test", "bad\0value", false),
            ("x-test", "bad\u{1f}value", false), ("x-test", "bad\u{7f}value", false),
            ("Content-Length", "0\r\nx-injected: yes", false), ("Connection", "close\n", false),
            ("x-test", "\tvisible space 雪", true), ("x-test", "", true),
            ("!#$%&'*+-.^_`|~0123456789AZaz", "ok", true),
        ] {
            let headers = pairs(ctx, &[(name.into(), value.into())], "test").unwrap();
            let body = ctx.alloc_bytes(&[], "test").unwrap();
            let response = ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[Value::Int(200), headers, body]).unwrap();
            let mut io = IoView { rt: &mut rt, resources: &mut resources };
            let result = respond(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), id, response);
            if valid {
                assert!(matches!(result, Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind: ResourceKind::HttpExchange }))), "{name:?}: {value:?}: {result:?}");
            } else {
                assert!(matches!(result, Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain { function, argument: 1 })) if function == respond::DECL.name), "{name:?}: {value:?}: {result:?}");
            }
        }
    });
}
// 関門: テスト用ハンドラ表の失敗は worker へ出さず、その種類で返す（10-16）。
#[test]
fn listen_returns_each_configured_network_fault() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    for (fault, tag) in [
        (
            NetworkFault::HostNotFound,
            tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND,
        ),
        (
            NetworkFault::ConnectionRefused,
            tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED,
        ),
        (
            NetworkFault::ConnectionReset,
            tags::NETWORK_ERROR_KIND_CONNECTION_RESET,
        ),
        (NetworkFault::TimedOut, tags::NETWORK_ERROR_KIND_TIMED_OUT),
    ] {
        rt.parts.network_faults.by_host = vec![("fake".into(), fault)];
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let mut io = IoView {
                rt: &mut rt,
                resources: &mut resources,
            };
            let IoReply::Done(result) = listen(
                CallCtx::new(ctx, Some(&mut io), None, None)
                    .io_ctx()
                    .unwrap(),
                "fake",
                0,
            )
            .unwrap() else {
                panic!("fault waited")
            };
            let failure = payload(ctx, result, tags::RESULT_ERROR);
            assert_eq!(
                ctx.fields_header(failure),
                Some((FieldsKind::NetworkError, tag))
            );
        });
    }
}
