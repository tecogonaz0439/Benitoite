//! HTTP クライアントの操作と TLS の構成（設計書 03-09「クライアント」、実装プラン 10-15・10-16）。

use crate::builtins::iface::{BuiltinDecl, IoCtx, IoReply, IoWait, Lend, WorkerWait, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, FieldsKind, Value, ValueCtx};
use crate::runtime::sched::parts::NetworkFault;
use crate::runtime::{ResourceError, RuntimeError, SizeUnit, Stop};
use std::io::{self, Read};
use std::time::Duration;
use ureq::http::{Request, Uri};
use ureq::unversioned::resolver::{DefaultResolver, ResolvedSocketAddrs, Resolver};
use ureq::unversioned::transport::NextTimeout;

mod redirect_body;

builtin! {
    /// `Benitoite.Network.Http.send` の本体（設計書 03-09「クライアント」）。
    name = "Benitoite.Network.Http.send",
    io fn send(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let (request, timeout) = match read_request(&ctx, arg0)? {
            Ok(request) => request,
            Err(failure) => return Ok(IoReply::Done(complete(&ctx, Err(failure))?)),
        };
        let host = request.uri().host().ok_or_else(|| internal("validated URL has no host"))?;
        let fault = ctx.services().runtime_view()
            .ok_or_else(|| internal("HTTP runtime unavailable"))?
            .rt.parts.network_faults.lookup(host);
        if let Some(fault) = fault {
            let kind = match fault {
                NetworkFault::HostNotFound => tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND,
                NetworkFault::ConnectionRefused => tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED,
                NetworkFault::ConnectionReset => tags::NETWORK_ERROR_KIND_CONNECTION_RESET,
                NetworkFault::TimedOut => tags::NETWORK_ERROR_KIND_TIMED_OUT,
            };
            return Ok(IoReply::Done(complete(&ctx, Err(Failure::Network(kind, text::INJECTED.into())))?));
        }
        let missing = missing_cpu_features();
        if request.uri().scheme_str() == Some("https") && let Some(failure) = tls_failure(&missing) {
            return Ok(IoReply::Done(complete(&ctx, Err(failure))?));
        }
        // スレッドに渡す要求・応答は Rust の所有する値だけにする（ADR 0261）。
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing, move |_| execute(request, timeout, missing), send_done,
        ))))
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[send::DECL];

// provider を大域に登録せず、Agent ごとに渡す（ADR 0015・0143）。
fn make_agent(timeout: std::time::Duration, tls_available: bool) -> ureq::Agent {
    let config = ureq::Agent::config_builder()
        .proxy(None)
        .http_status_as_error(false)
        .max_redirects(10)
        .timeout_global(Some(timeout));
    if tls_available {
        let provider: rustls::crypto::CryptoProvider = rustls_graviola::default_provider();
        let tls = ureq::tls::TlsConfig::builder()
            .unversioned_rustls_crypto_provider(std::sync::Arc::new(provider))
            .root_certs(ureq::tls::RootCerts::PlatformVerifier)
            .build();
        ureq::Agent::with_parts(
            config.tls_config(tls).build(),
            redirect_body::CheckedConnector(
                ureq::unversioned::transport::DefaultConnector::default(),
            ),
            NetworkResolver(DefaultResolver::default()),
        )
    } else {
        // HTTP から HTTPS へのリダイレクトも暗号の入口に到達させない（ADR 0330）。
        ureq::Agent::with_parts(
            config.build(),
            redirect_body::CheckedConnector(ureq::unversioned::transport::TcpConnector::default()),
            NetworkResolver(DefaultResolver::default()),
        )
    }
}

// DefaultResolver は OS の解決の失敗を Io で返す。接続の失敗と区別できるこの段で
// HostNotFound に揃え、解決の時間切れはそのまま通す（設計書 03-09「失敗の種類」）。
#[derive(Debug)]
struct NetworkResolver<R>(R);

impl<R: Resolver> Resolver for NetworkResolver<R> {
    fn resolve(
        &self,
        uri: &Uri,
        config: &ureq::config::Config,
        timeout: NextTimeout,
    ) -> Result<ResolvedSocketAddrs, ureq::Error> {
        self.0.resolve(uri, config, timeout).map_err(|error| {
            if matches!(error, ureq::Error::Io(_)) {
                ureq::Error::HostNotFound
            } else {
                error
            }
        })
    }
}

// レコードの宣言順の位置を一箇所に置く（実装プラン 10-15「レコードの値の作り方」）。
mod request_fields {
    pub const METHOD: u32 = 0;
    pub const URL: u32 = 1;
    pub const HEADERS: u32 = 2;
    pub const BODY: u32 = 3;
    pub const TIMEOUT: u32 = 4;
}

#[derive(Debug)]
enum Failure {
    Network(u32, String),
    InputTooLarge(u64),
}
struct ResponseData {
    status: u16,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
}
type PreparedRequest = Result<(Request<Vec<u8>>, Duration), Failure>;

fn read_request<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<PreparedRequest, Stop> {
    if ctx.fields_header(value) != Some((FieldsKind::Ctor, tags::RECORD))
        || ctx.fields_len(value) != Some(5)
    {
        return Err(internal("HTTP client request is not ClientRequest"));
    }
    let field = |index| {
        ctx.field(value, index)
            .ok_or_else(|| internal("HTTP request field missing"))
    };
    let string = |index| {
        ctx.str(field(index)?)
            .ok_or_else(|| internal("HTTP request field is not String"))
    };
    let method = string(request_fields::METHOD)?;
    let url = string(request_fields::URL)?;
    let headers = read_pairs(ctx, field(request_fields::HEADERS)?)?;
    let body = ctx
        .bytes(field(request_fields::BODY)?)
        .ok_or_else(|| internal("HTTP request body is not Bytes"))?;
    let timeout = field(request_fields::TIMEOUT)?
        .as_int()
        .ok_or_else(|| internal("HTTP timeout is not Integer"))?;
    if timeout < 1
        || headers
            .iter()
            .any(|(name, value)| !valid_header(name, value))
    {
        return Err(domain());
    }
    let timeout =
        u64::try_from(timeout).map_err(|_| internal("validated HTTP timeout overflow"))?;
    let uri = match url.parse::<Uri>() {
        Ok(uri)
            if matches!(uri.scheme_str(), Some("http" | "https"))
                && uri.host().is_some_and(|host| !host.is_empty()) =>
        {
            uri
        }
        _ => {
            return Ok(Err(Failure::Network(
                tags::NETWORK_ERROR_KIND_INVALID_INPUT,
                text::INVALID_URL.into(),
            )));
        }
    };
    let mut builder = Request::builder().method(method).uri(uri);
    for (name, value) in headers {
        builder = builder.header(name, value);
    }
    let request = match builder.body(body.to_vec()) {
        Ok(request) => request,
        Err(error) => {
            return Ok(Err(Failure::Network(
                tags::NETWORK_ERROR_KIND_INVALID_INPUT,
                error.to_string(),
            )));
        }
    };
    Ok(Ok((request, Duration::from_millis(timeout))))
}

fn valid_header(name: &str, value: &str) -> bool {
    !name.is_empty()
        && name.bytes().all(|b| {
            b.is_ascii_alphanumeric()
                || matches!(
                    b,
                    b'!' | b'#'
                        | b'$'
                        | b'%'
                        | b'&'
                        | b'\''
                        | b'*'
                        | b'+'
                        | b'-'
                        | b'.'
                        | b'^'
                        | b'_'
                        | b'`'
                        | b'|'
                        | b'~'
                )
        })
        && value
            .bytes()
            .all(|b| matches!(b, b'\t' | b' '..=b'~' | 0x80..=0xff))
}

fn read_pairs<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Vec<(String, String)>, Stop> {
    let mut pairs = Vec::new();
    let mut cursor = crate::runtime::list::cursor(ctx, value)?;
    while let Some(pair) = cursor.next(ctx)? {
        let name = ctx
            .field(pair, 0)
            .and_then(|v| ctx.str(v))
            .ok_or_else(|| internal("HTTP header name missing"))?;
        let value = ctx
            .field(pair, 1)
            .and_then(|v| ctx.str(v))
            .ok_or_else(|| internal("HTTP header value missing"))?;
        pairs.push((name.to_owned(), value.to_owned()));
    }
    Ok(pairs)
}

fn execute(
    request: Request<Vec<u8>>,
    timeout: Duration,
    missing: Vec<&'static str>,
) -> Result<ResponseData, Failure> {
    let request = validate_request(request)?;
    let agent = make_agent(timeout, missing.is_empty());
    let mut response = agent
        .run(request)
        .map_err(|error| classify(error, &missing))?;
    let mut headers = Vec::new();
    for (name, value) in response.headers() {
        // to_str は非 ASCII の UTF-8 も拒むため、バイト列で検査する（実装プラン L32）。
        let value = std::str::from_utf8(value.as_bytes()).map_err(|_| {
            Failure::Network(
                tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA,
                text::INVALID_HEADER_UTF8.into(),
            )
        })?;
        headers.push((name.as_str().to_owned(), value.to_owned()));
    }
    let body = read_limited(
        &mut response.body_mut().as_reader(),
        crate::runtime::MAX_STRING_BYTES,
        &missing,
    )?;
    Ok(ResponseData {
        status: response.status().as_u16(),
        headers,
        body,
    })
}

// Agent::run は本体を強制送信する指定を加えるため、その前に既定の要求検査を通す。
// Content-Length と HTTP の版の失敗は応答にもあるので、段を区別する（設計書 03-09）。
fn validate_request(request: Request<Vec<u8>>) -> Result<Request<Vec<u8>>, Failure> {
    let (parts, body) = request.into_parts();
    let mut call = ureq_proto::client::Call::new(Request::from_parts(parts.clone(), ()))
        .map_err(request_protocol_failure)?;
    if !body.is_empty()
        && !parts
            .headers
            .contains_key(ureq::http::header::CONTENT_LENGTH)
        && !parts
            .headers
            .contains_key(ureq::http::header::TRANSFER_ENCODING)
    {
        call.header(ureq::http::header::CONTENT_LENGTH, body.len().to_string())
            .map_err(request_protocol_failure)?;
    }
    call.proceed()
        .headers_map()
        .map_err(request_protocol_failure)?;
    // GET は L32 の追加指示で拒み、HEAD・CONNECT は ureq-proto の既定の制約を守る。
    // Content-Length: 0 を指定した本体も、強制送信の入口へ渡さない。
    if !body.is_empty()
        && matches!(
            parts.method,
            ureq::http::Method::GET | ureq::http::Method::HEAD | ureq::http::Method::CONNECT
        )
    {
        return Err(request_protocol_failure(ureq_proto::Error::BodyNotAllowed));
    }
    Ok(Request::from_parts(parts, body))
}

fn request_protocol_failure(error: ureq_proto::Error) -> Failure {
    Failure::Network(
        protocol_kind(&error, true),
        ureq::Error::from(error).to_string(),
    )
}

fn protocol_kind(error: &ureq_proto::Error, request: bool) -> u32 {
    use ureq_proto::Error;
    match error {
        Error::BadHeader(_)
        | Error::MethodVersionMismatch(_, _)
        | Error::TooManyHostHeaders
        | Error::BadHostHeader
        | Error::BadAuthorizationHeader
        | Error::BodyNotAllowed
        | Error::BodyContentAfterFinish
        | Error::BodyLargerThanContentLength
        | Error::BodyIsChunked => tags::NETWORK_ERROR_KIND_INVALID_INPUT,
        Error::UnsupportedVersion
        | Error::TooManyContentLengthHeaders
        | Error::BadContentLengthHeader
            if request =>
        {
            tags::NETWORK_ERROR_KIND_INVALID_INPUT
        }
        Error::UnsupportedVersion
        | Error::TooManyContentLengthHeaders
        | Error::BadContentLengthHeader
        | Error::ChunkLenNotAscii
        | Error::ChunkLenNotANumber
        | Error::ChunkExpectedCrLf
        | Error::HttpParseFail(_)
        | Error::HttpParseTooManyHeaders
        | Error::NoLocationHeader
        | Error::BadLocationHeader(_)
        | Error::HeadersWith100 => tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA,
        Error::OutputOverflow | Error::BadReject100Status(_) => tags::NETWORK_ERROR_KIND_OTHER,
        // 外部の非網羅 enum の未知の失敗は、規則を作らず Other に寄せる。
        _ => tags::NETWORK_ERROR_KIND_OTHER,
    }
}

// 本体の大きさを言語の値の確保前に判定する。reader の既定の 10 MB 制限を使わない（設計書 02-09）。
fn read_limited(reader: &mut impl Read, limit: u64, missing: &[&str]) -> Result<Vec<u8>, Failure> {
    let mut bytes = Vec::new();
    reader
        .take(limit.saturating_add(1))
        .read_to_end(&mut bytes)
        .map_err(|error| classify(ureq::Error::from(error), missing))?;
    let size = u64::try_from(bytes.len()).map_err(|_| Failure::InputTooLarge(limit))?;
    if size > limit {
        return Err(Failure::InputTooLarge(limit));
    }
    Ok(bytes)
}

/// ureq 3.4.2 の失敗を設計書 03-09「失敗の種類」へ対応させる。
///
/// | ureq / std::io の失敗 | NetworkErrorKind |
/// | --- | --- |
/// | 解決器の Io（HostNotFound に変換）、HostNotFound | HostNotFound |
/// | Io(ConnectionRefused / ConnectionReset) | ConnectionRefused / ConnectionReset |
/// | Timeout、Io(TimedOut) | TimedOut |
/// | Protocol の要求検査・送信の失敗（下記） | InvalidInput |
/// | Protocol の応答解析の失敗、LargeResponseHeader、Io(InvalidData / UnexpectedEof)、BodyStalled | InvalidHTTPData |
/// | BadUri、Http（要求の構築） | InvalidInput |
/// | TlsRequired（CPU 機能不足）、Rustls、Io（内側が rustls::Error）、TooManyRedirects、その他 | Other |
///
/// BodyReader が包んだ ureq の失敗は Error::from(io::Error) で戻してから分類する。
/// rustls の complete_io は検証の失敗を Io(InvalidData) に包むので、内側の型を先に調べる。
/// 要求側: BadHeader、MethodVersionMismatch、TooManyHostHeaders、BadHostHeader、
/// BadAuthorizationHeader、BodyNotAllowed、BodyContentAfterFinish、BodyLargerThanContentLength、
/// BodyIsChunked。UnsupportedVersion、TooManyContentLengthHeaders、BadContentLengthHeader は
/// 要求検査の段では InvalidInput、応答解析の段では InvalidHTTPData とする。
/// OutputOverflow と BadReject100Status は Other とする。
fn classify(error: ureq::Error, missing: &[&str]) -> Failure {
    let kind = match &error {
        ureq::Error::HostNotFound => tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND,
        ureq::Error::Timeout(_) => tags::NETWORK_ERROR_KIND_TIMED_OUT,
        ureq::Error::Io(error)
            if error
                .get_ref()
                .is_some_and(|inner| inner.is::<rustls::Error>()) =>
        {
            tags::NETWORK_ERROR_KIND_OTHER
        }
        ureq::Error::Io(error) => [
            (
                io::ErrorKind::ConnectionRefused,
                tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED,
            ),
            (
                io::ErrorKind::ConnectionReset,
                tags::NETWORK_ERROR_KIND_CONNECTION_RESET,
            ),
            (io::ErrorKind::TimedOut, tags::NETWORK_ERROR_KIND_TIMED_OUT),
            (
                io::ErrorKind::InvalidData,
                tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA,
            ),
            (
                io::ErrorKind::UnexpectedEof,
                tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA,
            ),
        ]
        .into_iter()
        .find_map(|(kind, tag)| (error.kind() == kind).then_some(tag))
        .unwrap_or(tags::NETWORK_ERROR_KIND_OTHER),
        ureq::Error::Protocol(error) => protocol_kind(error, false),
        ureq::Error::LargeResponseHeader(_, _) | ureq::Error::BodyStalled => {
            tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA
        }
        ureq::Error::BadUri(_) | ureq::Error::Http(_) => tags::NETWORK_ERROR_KIND_INVALID_INPUT,
        ureq::Error::TlsRequired if !missing.is_empty() => {
            return tls_failure(missing).unwrap_or_else(|| {
                Failure::Network(tags::NETWORK_ERROR_KIND_OTHER, error.to_string())
            });
        }
        ureq::Error::StatusCode(_)
        | ureq::Error::RedirectFailed
        | ureq::Error::InvalidProxyUrl
        | ureq::Error::ConnectionFailed
        | ureq::Error::BodyExceedsLimit(_)
        | ureq::Error::TooManyRedirects
        | ureq::Error::Tls(_)
        | ureq::Error::Pem(_)
        | ureq::Error::Rustls(_)
        | ureq::Error::RequireHttpsOnly(_)
        | ureq::Error::ConnectProxyFailed(_)
        | ureq::Error::TlsRequired
        | ureq::Error::Other(_) => tags::NETWORK_ERROR_KIND_OTHER,
        // 外部の非網羅 enum に今後加わる失敗も、既存の Other に寄せる。
        _ => tags::NETWORK_ERROR_KIND_OTHER,
    };
    Failure::Network(kind, error.to_string())
}

fn missing_cpu_features() -> Vec<&'static str> {
    #[cfg(target_arch = "x86_64")]
    let features = [
        ("aes", std::arch::is_x86_feature_detected!("aes")),
        (
            "pclmulqdq",
            std::arch::is_x86_feature_detected!("pclmulqdq"),
        ),
        ("bmi1", std::arch::is_x86_feature_detected!("bmi1")),
        ("adx", std::arch::is_x86_feature_detected!("adx")),
        ("avx", std::arch::is_x86_feature_detected!("avx")),
        ("avx2", std::arch::is_x86_feature_detected!("avx2")),
    ];
    #[cfg(target_arch = "aarch64")]
    let features = [
        ("neon", std::arch::is_aarch64_feature_detected!("neon")),
        ("aes", std::arch::is_aarch64_feature_detected!("aes")),
        ("pmull", std::arch::is_aarch64_feature_detected!("pmull")),
        ("sha2", std::arch::is_aarch64_feature_detected!("sha2")),
    ];
    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    let features = [("supported architecture", false)];
    features
        .into_iter()
        .filter_map(|(name, present)| (!present).then_some(name))
        .collect()
}

fn tls_failure(missing: &[&str]) -> Option<Failure> {
    (!missing.is_empty()).then(|| {
        Failure::Network(
            tags::NETWORK_ERROR_KIND_OTHER,
            format!("{}{}", text::MISSING_CPU, missing.join(", ")),
        )
    })
}

fn send_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<ResponseData, Failure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete(ctx, output)
}
fn complete<'e>(
    ctx: &ValueCtx<'e>,
    output: Result<ResponseData, Failure>,
) -> Result<Value<'e>, Stop> {
    match output {
        Err(Failure::InputTooLarge(limit)) => Err(Stop::Resource(ResourceError::InputTooLarge {
            function: send::DECL.name,
            unit: SizeUnit::Bytes,
            limit,
        })),
        Err(Failure::Network(kind, reason)) => {
            let reason = ctx.alloc_str(&reason, send::DECL.name)?;
            let error = ctx.alloc_fields(FieldsKind::NetworkError, kind, &[reason])?;
            ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])
        }
        Ok(output) => {
            CheckedLen::elements(super::count(output.headers.len())?, send::DECL.name)?;
            let mut headers = Vec::with_capacity(output.headers.len());
            for (name, value) in output.headers {
                let name = ctx.alloc_str(&name, send::DECL.name)?;
                let value = ctx.alloc_str(&value, send::DECL.name)?;
                headers.push(ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[name, value])?);
            }
            let headers = crate::runtime::list::from_values(ctx, &headers, send::DECL.name)?;
            let body = ctx.alloc_bytes(&output.body, send::DECL.name)?;
            let response = ctx.alloc_fields(
                FieldsKind::Ctor,
                tags::RECORD,
                &[Value::Int(i64::from(output.status)), headers, body],
            )?;
            ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[response])
        }
    }
}
fn internal(message: &str) -> Stop {
    Stop::Internal(message.into())
}
fn domain() -> Stop {
    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
        function: send::DECL.name,
        argument: 0,
    })
}
mod text {
    pub const INVALID_URL: &str = "URL must be an absolute http or https URL";
    pub const INJECTED: &str = "injected network failure";
    pub const INVALID_HEADER_UTF8: &str = "HTTP response header is not valid UTF-8";
    pub const MISSING_CPU: &str = "HTTPS requires unavailable CPU features: ";
}

#[cfg(test)]
mod tests;
