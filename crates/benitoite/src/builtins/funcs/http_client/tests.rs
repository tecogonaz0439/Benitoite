//! HTTP の要求の検査・失敗の注入・本体の上限（実装プラン L32）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]
use super::*;
use crate::builtins::funcs::runtime_test_support::{payload, runtime};
use crate::builtins::iface::CallCtx;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::io::resources::ResourceTable;
use crate::runtime::io::services::IoView;
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::ExecMode;

// 関門: OS の名前解決の Io を HostNotFound に揃え、Timeout の種類を保つ。
// 失敗の注入は解決器を通らない。オーケストレータの指示に従い外部 DNS を置き換える。
#[test]
fn resolver_io_becomes_host_not_found_and_timeout_is_preserved() {
    #[derive(Debug)]
    struct FailedResolver(bool);
    impl Resolver for FailedResolver {
        fn resolve(
            &self,
            _uri: &Uri,
            _config: &ureq::config::Config,
            _timeout: NextTimeout,
        ) -> Result<ResolvedSocketAddrs, ureq::Error> {
            if self.0 {
                Err(ureq::Error::Timeout(ureq::Timeout::Resolve))
            } else {
                Err(ureq::Error::Io(io::Error::other("lookup failed")))
            }
        }
    }
    let uri = "http://resolver.invalid/".parse().unwrap();
    let config = ureq::Agent::config_builder().proxy(None).build();
    let timeout = NextTimeout {
        after: Duration::from_secs(1).into(),
        reason: ureq::Timeout::Resolve,
    };
    for timed_out in [false, true] {
        let error = NetworkResolver(FailedResolver(timed_out))
            .resolve(&uri, &config, timeout)
            .unwrap_err();
        if timed_out {
            assert!(matches!(
                error,
                ureq::Error::Timeout(ureq::Timeout::Resolve)
            ));
        }
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let result = complete(ctx, Err(classify(error, &[]))).unwrap();
            assert_eq!(
                network_kind(ctx, result),
                if timed_out {
                    tags::NETWORK_ERROR_KIND_TIMED_OUT
                } else {
                    tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND
                }
            );
        });
    }
}

fn request<'e>(ctx: &ValueCtx<'e>, url: &str, timeout: i64, headers: &[(&str, &str)]) -> Value<'e> {
    let method = ctx.alloc_str("GET", "test").unwrap();
    let url = ctx.alloc_str(url, "test").unwrap();
    let pairs: Vec<_> = headers
        .iter()
        .map(|(name, value)| {
            let name = ctx.alloc_str(name, "test").unwrap();
            let value = ctx.alloc_str(value, "test").unwrap();
            ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[name, value])
                .unwrap()
        })
        .collect();
    let headers = crate::runtime::list::from_values(ctx, &pairs, "test").unwrap();
    let body = ctx.alloc_bytes(&[], "test").unwrap();
    ctx.alloc_fields(
        FieldsKind::Ctor,
        tags::RECORD,
        &[method, url, headers, body, Value::Int(timeout)],
    )
    .unwrap()
}
fn network_kind<'e>(ctx: &ValueCtx<'e>, result: Value<'e>) -> u32 {
    let error = payload(ctx, result, tags::RESULT_ERROR);
    let Some((FieldsKind::NetworkError, tag)) = ctx.fields_header(error) else {
        panic!("expected NetworkError")
    };
    assert!(!ctx.str(ctx.field(error, 0).unwrap()).unwrap().is_empty());
    tag
}

// 関門: Http.send の実際の入口で、URL・引数の失敗が worker を待たずに返る契約を守る。
// サーバのテストは ClientRequest を読まない。差し込み口を加えず、本番の IoView を使う。
#[test]
fn invalid_urls_and_timeout_finish_before_worker_submission() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for url in ["not a url", "ftp://x", "/relative", "http://"] {
            let value = request(ctx, url, 30000, &[]);
            let mut io = IoView { rt: &mut rt, resources: &mut resources };
            let IoReply::Done(result) = send(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), value).unwrap() else { panic!("invalid URL waited") };
            assert_eq!(network_kind(ctx, result), tags::NETWORK_ERROR_KIND_INVALID_INPUT);
        }
        for timeout in [0, -1] {
            let value = request(ctx, "http://127.0.0.1/", timeout, &[]);
            let mut io = IoView { rt: &mut rt, resources: &mut resources };
            assert!(matches!(send(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), value),
                Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain { function, argument: 0 })) if function == send::DECL.name));
        }
    });
}

// 関門: ヘッダの分割と名前の不正文字を送信前に拒む。許す文字は worker の待ちまで進む。
// 通常の通信ではこの失敗を起こせず、L32・ADR 0331 が単体テストを指定する。
#[test]
fn request_headers_check_argument_zero_and_allow_utf8_and_tab() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (name, value, valid) in [
            ("bad name", "ok", false), ("bad:name", "ok", false), ("", "ok", false),
            ("bad\rname", "ok", false), ("bad\tname", "ok", false), ("雪", "ok", false),
            ("x-test", "bad\rvalue", false), ("x-test", "bad\nvalue", false), ("x-test", "bad\0value", false),
            ("x-test", "bad\u{1f}value", false), ("x-test", "bad\u{7f}value", false),
            ("Content-Length", "0\r\nx-injected: yes", false),
            ("x-test", "\tvisible space 雪", true), ("x-test", "", true),
            ("!#$%&'*+-.^_`|~0123456789AZaz", "ok", true),
        ] {
            let value = request(ctx, "http://127.0.0.1/", 30000, &[(name, value)]);
            let mut io = IoView { rt: &mut rt, resources: &mut resources };
            let result = send(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), value);
            if valid {
                assert!(matches!(result, Ok(IoReply::Wait(IoWait::Worker(_)))), "{name}: {result:?}");
            } else {
                assert!(matches!(result, Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain { function, argument: 0 })) if function == send::DECL.name), "{name}: {result:?}");
            }
        }
    });
}

// 関門: host の失敗の注入が四種類とも、その種類で即完了する。実通信のテストでは
// 決まった DNS・reset を作れない。既存の NetworkFaults 以外の差し込み口を加えない。
#[test]
fn configured_network_faults_return_without_worker() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&std::env::current_dir().unwrap(), ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    for (fault, kind) in [
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
        rt.parts.network_faults.by_host = vec![("127.0.0.1".into(), fault)];
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let value = request(ctx, "http://127.0.0.1/", 30000, &[]);
            let mut io = IoView {
                rt: &mut rt,
                resources: &mut resources,
            };
            let IoReply::Done(result) = send(
                CallCtx::new(ctx, Some(&mut io), None, None)
                    .io_ctx()
                    .unwrap(),
                value,
            )
            .unwrap() else {
                panic!("injected failure waited")
            };
            assert_eq!(network_kind(ctx, result), kind);
        });
    }
}

// 関門: L32 が指定する非公開関数のテスト。OS の CPU を差し替える公開の口を作らず、
// CPU が足りない理由が実際の完了の変換で Other の Result.Error になることを守る。
#[test]
fn missing_cpu_features_return_other_with_names() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let failure = tls_failure(&["aes", "pmull"]).unwrap();
        let result = complete(ctx, Err(failure)).unwrap();
        assert_eq!(network_kind(ctx, result), tags::NETWORK_ERROR_KIND_OTHER);
        let error = payload(ctx, result, tags::RESULT_ERROR);
        let reason = ctx.str(ctx.field(error, 0).unwrap()).unwrap();
        assert!(reason.contains("aes") && reason.contains("pmull"));
        let redirected = complete(ctx, Err(classify(ureq::Error::TlsRequired, &["aes"]))).unwrap();
        assert_eq!(
            network_kind(ctx, redirected),
            tags::NETWORK_ERROR_KIND_OTHER
        );
    });
}

// 関門: L32 が指定する非公開関数の境界テスト。1 GiB の通信を行わず、上限ちょうどと
// 上限 + 1 の判定・読み過ぎの防止・資源の不足への変換を、本番で使う関数で守る。
#[test]
fn body_limit_reads_at_most_one_extra_byte_and_stops() {
    assert_eq!(
        read_limited(&mut io::Cursor::new(b"abcd"), 4, &[]).unwrap(),
        b"abcd"
    );
    let mut reader = io::Cursor::new(b"abcdef");
    let failure = read_limited(&mut reader, 4, &[]).unwrap_err();
    assert_eq!(reader.position(), 5);
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        assert!(matches!(complete(ctx, Err(failure)), Err(Stop::Resource(ResourceError::InputTooLarge { function, unit: SizeUnit::Bytes, limit: 4 })) if function == send::DECL.name));
    });
}

// 関門: rustls の証明書の誤りを包んだ InvalidData を、HTTP の形式エラーと取り違えない。
// 実際の rustls の誤りの型から完了の値までを通す。HTTPS の外部接続と新しい差し込み口は要しない。
#[test]
fn wrapped_certificate_failure_is_other_not_invalid_http_data() {
    let error = io::Error::new(
        io::ErrorKind::InvalidData,
        rustls::Error::InvalidCertificate(rustls::CertificateError::UnknownIssuer),
    );
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let result = complete(ctx, Err(classify(ureq::Error::from(error), &[]))).unwrap();
        assert_eq!(network_kind(ctx, result), tags::NETWORK_ERROR_KIND_OTHER);
    });
}
