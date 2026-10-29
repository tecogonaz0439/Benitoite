//! HTTP の純粋な要求検査と、同じ要求の射影（設計書 03-09「クライアント」）。

use super::{Uri, request_fields};
use crate::builtins::checked_scope::{self, Failure};
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::{FieldsKind, Value, ValueCtx};
use crate::types::scope::{Endpoint, HostTarget, IpAddress, Port, ip_text};

mod text {
    pub(super) const FUNCTION: &str = "Http.checkRequestIn";
    pub(super) const INVALID_URL: &str = "expected an absolute ASCII http or https URL with a host, valid percent escapes, no userinfo, and a port in 0..65535";
    pub(super) const INVALID_HOST: &str =
        "expected an ASCII host name, canonical IPv4, or numeric IPv6 without a zone identifier";
}

enum RequestFailure {
    InvalidUrl,
    Scope(Failure, String),
}

// Uri と同じ URL を読み、数値風のホストを OS に解釈させない。URL の
// IPv6 は数値として正規化するが、Scope の直接入力の正規形は緩めない
// （設計書 03-09「クライアント」、01-12「操作の対象の範囲の領域と被覆」）。
fn endpoint(url: &str) -> Result<(Endpoint, String), RequestFailure> {
    if url
        .bytes()
        .any(|b| !b.is_ascii_alphanumeric() && !b"-._~:/?#[]@!$&'()*+,;=%".contains(&b))
        || !valid_percent(url)
    {
        return Err(RequestFailure::InvalidUrl);
    }
    let uri = url.parse::<Uri>().map_err(|_| RequestFailure::InvalidUrl)?;
    let default_port = match uri.scheme_str() {
        Some("http") => 80,
        Some("https") => 443,
        _ => return Err(RequestFailure::InvalidUrl),
    };
    let authority = uri.authority().ok_or(RequestFailure::InvalidUrl)?;
    if authority.as_str().contains('@') {
        return Err(RequestFailure::InvalidUrl);
    }
    let host = authority.host();
    if host.is_empty() {
        return Err(RequestFailure::InvalidUrl);
    }
    // Authority::port() は不正な port にも None を返すため、省略と区別して読む。
    let suffix = authority
        .as_str()
        .strip_prefix(host)
        .ok_or(RequestFailure::InvalidUrl)?;
    let port = match suffix {
        "" | ":" => default_port,
        _ => suffix
            .strip_prefix(':')
            .filter(|text| !text.is_empty() && text.bytes().all(|b| b.is_ascii_digit()))
            .and_then(|text| text.parse::<u16>().ok())
            .ok_or(RequestFailure::InvalidUrl)?,
    };
    let target = if let Some(ip) = host.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
        let ip = ip.parse::<std::net::Ipv6Addr>().map_err(|_| {
            RequestFailure::Scope(Failure::InvalidTarget(text::INVALID_HOST), ip.to_owned())
        })?;
        HostTarget::Ip(IpAddress::V6(u128::from(ip)))
    } else {
        let target = HostTarget::parse(host).map_err(|_| {
            RequestFailure::Scope(Failure::InvalidTarget(text::INVALID_HOST), host.to_owned())
        })?;
        if matches!(target, HostTarget::Name(_)) && numeric_host(host) {
            return Err(RequestFailure::Scope(
                Failure::InvalidTarget(text::INVALID_HOST),
                host.to_owned(),
            ));
        }
        target
    };
    let spelling = host
        .strip_prefix('[')
        .and_then(|s| s.strip_suffix(']'))
        .unwrap_or(host)
        .to_owned();
    let target = checked_scope::host_target(target)
        .map_err(|failure| RequestFailure::Scope(failure, spelling.clone()))?;
    Ok((
        Endpoint {
            host: target,
            port: Port::new(port),
        },
        spelling,
    ))
}

fn valid_percent(text: &str) -> bool {
    let mut bytes = text.bytes();
    while let Some(byte) = bytes.next() {
        if byte == b'%'
            && !(bytes.next().is_some_and(|b| b.is_ascii_hexdigit())
                && bytes.next().is_some_and(|b| b.is_ascii_hexdigit()))
        {
            return false;
        }
    }
    true
}

// OS が数値として解釈しうる字面を、保守的に DNS 名の分類から除く。
// 0x/0X だけの要素も含め、全要素が数字で始まり数字・a〜f・A〜F・x・X
// だけからなる場合を拒否する。英字で始まるラベルを含む名前は除かない。
fn numeric_host(host: &str) -> bool {
    host.split('.').all(|part| {
        part.as_bytes().first().is_some_and(u8::is_ascii_digit)
            && part
                .bytes()
                .all(|b| b.is_ascii_hexdigit() || b == b'x' || b == b'X')
    })
}

fn string<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c str, Stop> {
    ctx.str(value)
        .ok_or_else(|| Stop::Internal("HTTP expected String".into()))
}

fn request_url<'e>(ctx: &ValueCtx<'e>, request: Value<'e>) -> Result<Value<'e>, Stop> {
    if ctx.fields_header(request) != Some((FieldsKind::Ctor, tags::RECORD))
        || ctx.fields_len(request) != Some(5)
    {
        return Err(Stop::Internal("HTTP expected ClientRequest".into()));
    }
    ctx.field(request, request_fields::URL)
        .ok_or_else(|| Stop::Internal("HTTP ClientRequest lost its URL".into()))
}

// 射影と送信が同じ欄0を読む。送信だけが保持 endpoint も読むが、どちらも
// レコードを再構築しない（設計書 03-09「クライアント」）。
fn request_value<'e>(ctx: &ValueCtx<'e>, request: Value<'e>) -> Result<Value<'e>, Stop> {
    if ctx.fields_header(request) != Some((FieldsKind::Ctor, tags::RECORD))
        || ctx.fields_len(request) != Some(3)
    {
        return Err(Stop::Internal("HTTP expected RequestIn".into()));
    }
    let value = ctx
        .field(request, 0)
        .ok_or_else(|| Stop::Internal("HTTP RequestIn lost its request".into()))?;
    request_url(ctx, value)?;
    Ok(value)
}

/// 送信に使う同じ要求と、検査の成功時に保持した endpoint を読む。
pub(super) fn retained_request<'e>(
    ctx: &ValueCtx<'e>,
    request: Value<'e>,
) -> Result<(Value<'e>, Endpoint), Stop> {
    let value = request_value(ctx, request)?;
    let host = ctx
        .field(request, 1)
        .and_then(|host| ctx.str(host))
        .and_then(|host| HostTarget::parse(host).ok())
        .ok_or_else(|| Stop::Internal("HTTP RequestIn lost its host".into()))?;
    let port = ctx
        .field(request, 2)
        .and_then(Value::as_int)
        .and_then(Port::from_int)
        .ok_or_else(|| Stop::Internal("HTTP RequestIn lost its port".into()))?;
    Ok((value, Endpoint { host, port }))
}

/// 純粋な検査と同じ解析で、送信用 URI の対象を保持 endpoint と照合する。
pub(super) fn matches_endpoint(url: &str, retained: &Endpoint) -> bool {
    endpoint(url).is_ok_and(|(actual, _)| &actual == retained)
}

fn scope_error<'e>(
    ctx: &ValueCtx<'e>,
    failure: Failure,
    pattern: Value<'e>,
    host: Value<'e>,
    minimum: i64,
    maximum: i64,
    port: i64,
) -> Result<Value<'e>, Stop> {
    let (tag, args) = match failure {
        Failure::InvalidPattern(reason) => (
            tags::SCOPE_ERROR_INVALID_PATTERN,
            vec![pattern, ctx.alloc_str(reason, text::FUNCTION)?],
        ),
        Failure::InvalidTarget(reason) => (
            tags::SCOPE_ERROR_INVALID_TARGET,
            vec![host, ctx.alloc_str(reason, text::FUNCTION)?],
        ),
        Failure::InvalidMinimum | Failure::InvalidMaximum | Failure::InvalidBounds => (
            tags::SCOPE_ERROR_INVALID_PORT_RANGE,
            vec![Value::Int(minimum), Value::Int(maximum)],
        ),
        Failure::InvalidPort => (tags::SCOPE_ERROR_INVALID_PORT, vec![Value::Int(port)]),
        Failure::OutsideScope => (tags::SCOPE_ERROR_OUTSIDE_SCOPE, vec![pattern, host]),
        Failure::PortOutsideScope => (
            tags::SCOPE_ERROR_PORT_OUTSIDE_SCOPE,
            vec![Value::Int(minimum), Value::Int(maximum), Value::Int(port)],
        ),
    };
    ctx.alloc_fields(FieldsKind::Ctor, tag, &args)
}

fn check<'e>(
    ctx: &ValueCtx<'e>,
    pattern: Value<'e>,
    minimum: i64,
    maximum: i64,
    request: Value<'e>,
    static_range: &crate::types::scope::Range,
) -> Result<Value<'e>, Stop> {
    let url = request_url(ctx, request)?;
    let url_text = string(ctx, url)?;
    let parsed = endpoint(url_text);
    let (tag, value) = match parsed {
        Err(RequestFailure::InvalidUrl) => {
            let message = ctx.alloc_str(text::INVALID_URL, text::FUNCTION)?;
            (
                tags::RESULT_ERROR,
                ctx.alloc_fields(
                    FieldsKind::Ctor,
                    tags::REQUEST_CHECK_ERROR_INVALID_URL,
                    &[message],
                )?,
            )
        }
        Err(RequestFailure::Scope(failure, spelling)) => {
            let host = ctx.alloc_str(&spelling, text::FUNCTION)?;
            let error = scope_error(ctx, failure, pattern, host, minimum, maximum, 0)?;
            (
                tags::RESULT_ERROR,
                ctx.alloc_fields(FieldsKind::Ctor, tags::REQUEST_CHECK_ERROR_SCOPE, &[error])?,
            )
        }
        Ok((endpoint, spelling)) => {
            let host = ctx.alloc_str(&spelling, text::FUNCTION)?;
            let dynamic = checked_scope::endpoint_pattern(string(ctx, pattern)?, minimum, maximum);
            let checked = dynamic.and_then(|range| {
                if !range.host.matches(&endpoint.host) {
                    Err(Failure::OutsideScope)
                } else if !range.ports.matches(endpoint.port) {
                    Err(Failure::PortOutsideScope)
                } else if !match static_range {
                    crate::types::scope::Range::Top => true,
                    crate::types::scope::Range::Endpoint(range) => range.matches(&endpoint),
                    crate::types::scope::Range::Path(_) | crate::types::scope::Range::Host(_) => {
                        false
                    }
                } {
                    Err(Failure::OutsideScope)
                } else {
                    Ok(())
                }
            });
            match checked {
                Err(failure) => {
                    let error = scope_error(
                        ctx,
                        failure,
                        pattern,
                        host,
                        minimum,
                        maximum,
                        i64::from(endpoint.port.value()),
                    )?;
                    (
                        tags::RESULT_ERROR,
                        ctx.alloc_fields(
                            FieldsKind::Ctor,
                            tags::REQUEST_CHECK_ERROR_SCOPE,
                            &[error],
                        )?,
                    )
                }
                Ok(()) => {
                    let normalized = match &endpoint.host {
                        HostTarget::Name(name) => name.labels().join("."),
                        HostTarget::Ip(ip) => ip_text::format_address(*ip),
                    };
                    let host = ctx.alloc_str(&normalized, text::FUNCTION)?;
                    // 全欄を持つ同じレコードと実効 endpoint を既存の構成子の欄で保つ。
                    // ValueCtx の区間内だけで確保するので安全点も追跡規則も増やさない
                    // （設計書 02-08「値の表現」）。
                    let wrapped = ctx.alloc_fields(
                        FieldsKind::Ctor,
                        tags::RECORD,
                        &[request, host, Value::Int(i64::from(endpoint.port.value()))],
                    )?;
                    (tags::RESULT_OK, wrapped)
                }
            }
        }
    };
    ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
}

builtin! {
    /// 動的な条件と実効 endpoint を検査し同じ要求を保持する（設計書 03-09「クライアント」）。
    name = "Http.checkRequestIn",
    pure fn check_request_in(ctx, host_pattern: Value<'e>, minimum_port: i64, maximum_port: i64, request: Value<'e>) -> Value<'e> {
        let [range] = ctx.ranges() else {
            return Err(Stop::Internal("HTTP check requires one static range".into()));
        };
        if !range.fits_kind(crate::types::scope::Kind::Endpoint) {
            return Err(Stop::Internal("HTTP check requires an endpoint range".into()));
        }
        check(&ctx, host_pattern, minimum_port, maximum_port, request, range)
    }
}

builtin! {
    /// 保持した要求を作り直さず返す（設計書 03-09「クライアント」）。
    name = "Http.requestInValue",
    pure fn request_in_value(ctx, request: Value<'e>) -> Value<'e> {
        request_value(&ctx, request)
    }
}

builtin! {
    /// 戻りの範囲による被覆を確かめ、同じ要求と endpoint を持つ値を返す（設計書 03-09「クライアント」）。
    name = "Http.widenRequestIn",
    pure fn widen_request_in(ctx, request: Value<'e>) -> Value<'e> {
        let [source, destination] = ctx.ranges() else {
            return Err(Stop::Internal("HTTP widen requires two static ranges".into()));
        };
        if !source.fits_kind(crate::types::scope::Kind::Endpoint)
            || !destination.fits_kind(crate::types::scope::Kind::Endpoint)
            || !destination.covers(source)
        {
            return Err(Stop::Internal("HTTP widen requires covering endpoint ranges".into()));
        }
        request_in_value(ctx, request)?;
        Ok(request)
    }
}

pub(super) const DECLS: &[BuiltinDecl] = &[
    check_request_in::DECL,
    request_in_value::DECL,
    widen_request_in::DECL,
];
