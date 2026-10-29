//! Scopeの字面・所属・失敗順を静的検査と実行時で共有する（設計書 03-06「Scope」）。

use crate::types::scope::{
    EndpointPattern, HostPattern, HostTarget, IpAddress, Path, PathPattern, Port, PortRange,
    ip_text,
};
use std::borrow::Cow;

mod text {
    pub const HOST: &str = "expected nonempty ASCII host labels without edge hyphens or empty labels, or a canonical IP address";
    pub const HOST_PATTERN: &str =
        "expected a host, *.host, **.host, canonical IP address, or CIDR";
    pub const PATH: &str =
        "expected an absolute path without empty, dot, or dot-dot components, NUL, or backslash";
    pub const PATH_PATTERN: &str = "expected an exact path or a trailing /** wildcard";
    pub const ENDPOINT_PATTERN: &str = "expected a host pattern or a canonical IP address or CIDR";
    pub const MAPPED_TARGET: &str =
        "IPv4-mapped IPv6 addresses are not supported as targets; use an IPv4 address";
}

/// 対象の入口だけで射影の形を拒否する。範囲の数値の代数とパターンは変えない。
pub(crate) fn host_target(target: HostTarget) -> Result<HostTarget, Failure> {
    if matches!(target, HostTarget::Ip(IpAddress::V6(bits)) if bits >> 32 == 0xffff) {
        return Err(Failure::InvalidTarget(text::MAPPED_TARGET));
    }
    Ok(target)
}

/// HTTP の動的条件と後続の静的判定が使う、同じ host/port の代数の入口。
pub(crate) fn endpoint_pattern(
    pattern: &str,
    minimum: i64,
    maximum: i64,
) -> Result<EndpointPattern, Failure> {
    let host =
        HostPattern::parse(pattern).map_err(|_| Failure::InvalidPattern(text::ENDPOINT_PATTERN))?;
    let lo = Port::from_int(minimum).ok_or(Failure::InvalidMinimum)?;
    let hi = Port::from_int(maximum).ok_or(Failure::InvalidMaximum)?;
    let ports = PortRange::new(lo, hi).map_err(|_| Failure::InvalidBounds)?;
    Ok(EndpointPattern { host, ports })
}

/// 成功時に保存する正規化済みの条件と対象。正規形のパスは入力を借用する。
pub(crate) struct CheckedPair<'a> {
    pub pattern: Cow<'a, str>,
    pub target: Cow<'a, str>,
}

/// 共通の失敗。端点の位置の区別は追加診断で使い、実行時の失敗番号は共有する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Failure {
    InvalidPattern(&'static str),
    InvalidTarget(&'static str),
    InvalidMinimum,
    InvalidMaximum,
    InvalidBounds,
    InvalidPort,
    OutsideScope,
    PortOutsideScope,
}

impl Failure {
    /// 私有builtinから標準ソースへ渡す番号とreason。
    pub(crate) fn encoded(self) -> (i64, &'static str) {
        match self {
            Self::InvalidPattern(reason) => (1, reason),
            Self::InvalidTarget(reason) => (2, reason),
            Self::InvalidMinimum | Self::InvalidMaximum | Self::InvalidBounds => (3, ""),
            Self::InvalidPort => (4, ""),
            Self::OutsideScope => (5, ""),
            Self::PortOutsideScope => (6, ""),
        }
    }
}

// 未知の入力は推測しない。既知の不良をこの順で返せば、未知をどの値で埋めても
// 実行時の結果はErrorになる（設計書 02-05「本体の後の検査」）。
fn host_format(
    pattern: Option<&str>,
    host: Option<&str>,
) -> Result<Option<(HostPattern, HostTarget)>, Failure> {
    let pattern = pattern
        .map(HostPattern::parse)
        .transpose()
        .map_err(|_| Failure::InvalidPattern(text::HOST_PATTERN))?;
    let host = host
        .map(|raw| {
            HostTarget::parse(raw)
                .map_err(|_| Failure::InvalidTarget(text::HOST))
                .and_then(host_target)
        })
        .transpose()?;
    Ok(pattern.zip(host))
}

/// 既知のホスト入力の形式・所属を検査する。実行時は二入力ともSomeで呼ぶ。
pub(crate) fn check_host<'a>(
    pattern: Option<&'a str>,
    host: Option<&'a str>,
) -> Result<Option<CheckedPair<'a>>, Failure> {
    check_endpoint(pattern, host, None, None, None)
}

/// パスの木は幹自身と子を含む。対象の*は普通の文字として保存する。
pub(crate) fn check_path<'a>(
    pattern: Option<&'a str>,
    path: Option<&'a str>,
) -> Result<Option<CheckedPair<'a>>, Failure> {
    let parsed = pattern
        .map(PathPattern::parse)
        .transpose()
        .map_err(|_| Failure::InvalidPattern(text::PATH_PATTERN))?;
    let target = path
        .map(Path::parse)
        .transpose()
        .map_err(|_| Failure::InvalidTarget(text::PATH))?;
    if let Some((pattern, target)) = parsed.zip(target)
        && !pattern.matches(&target)
    {
        return Err(Failure::OutsideScope);
    }
    Ok(pattern.zip(path).map(|(pattern, target)| CheckedPair {
        pattern: Cow::Borrowed(pattern),
        target: Cow::Borrowed(target),
    }))
}

/// 形式→端点→port→ホスト所属→ポート所属の順で、既知の部分を検査する。
pub(crate) fn check_endpoint<'a>(
    pattern: Option<&'a str>,
    host: Option<&'a str>,
    minimum: Option<i64>,
    maximum: Option<i64>,
    port: Option<i64>,
) -> Result<Option<CheckedPair<'a>>, Failure> {
    let parsed = host_format(pattern, host)?;
    if minimum.is_some_and(|p| Port::from_int(p).is_none()) {
        return Err(Failure::InvalidMinimum);
    }
    if maximum.is_some_and(|p| Port::from_int(p).is_none()) {
        return Err(Failure::InvalidMaximum);
    }
    if minimum.zip(maximum).is_some_and(|(lo, hi)| lo > hi) {
        return Err(Failure::InvalidBounds);
    }
    if port.is_some_and(|p| Port::from_int(p).is_none()) {
        return Err(Failure::InvalidPort);
    }
    if let Some((pattern, host)) = &parsed
        && !pattern.matches(host)
    {
        return Err(Failure::OutsideScope);
    }
    if let Some(((lo, hi), p)) = minimum.zip(maximum).zip(port)
        && !(lo..=hi).contains(&p)
    {
        return Err(Failure::PortOutsideScope);
    }
    Ok(parsed
        .zip(pattern.zip(host))
        .map(
            |((parsed_pattern, parsed_target), (pattern, target))| CheckedPair {
                pattern: Cow::Owned(match parsed_pattern {
                    HostPattern::Name(_) => pattern.to_ascii_lowercase(),
                    HostPattern::Ip(ip) => ip_text::format_pattern(ip),
                }),
                target: Cow::Owned(match parsed_target {
                    HostTarget::Name(_) => target.to_ascii_lowercase(),
                    HostTarget::Ip(ip) => ip_text::format_address(ip),
                }),
            },
        ))
}
