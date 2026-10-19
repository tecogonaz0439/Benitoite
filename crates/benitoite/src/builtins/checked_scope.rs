//! Scopeの字面・所属・失敗順を静的検査と実行時で共有する（設計書 03-06「Scope」）。

mod text {
    pub const HOST: &str =
        "expected nonempty ASCII host labels without edge hyphens, empty labels, or IPv4 form";
    pub const HOST_PATTERN: &str = "expected a host, *.host, or **.host";
    pub const PATH: &str =
        "expected an absolute path without empty, dot, or dot-dot components, NUL, or backslash";
    pub const PATH_PATTERN: &str = "expected an exact path or a trailing /** wildcard";
}

/// 成功時に保存する条件と対象の借用。ホストの小文字化は実行時の包みで行う。
pub(crate) struct CheckedPair<'a> {
    pub pattern: &'a str,
    pub target: &'a str,
    pub lowercase: bool,
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

#[derive(Clone, Copy)]
enum HostKind {
    Exact,
    One,
    Many,
}

fn host_word(word: &str) -> bool {
    let mut count = 0usize;
    let mut numeric = true;
    for label in word.split('.') {
        if label.is_empty()
            || label.starts_with('-')
            || label.ends_with('-')
            || !label
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-')
        {
            return false;
        }
        count = count.saturating_add(1);
        numeric &= label.bytes().all(|b| b.is_ascii_digit());
    }
    !(count == 4 && numeric)
}

fn host_pattern(pattern: &str) -> Result<(HostKind, &str), Failure> {
    let (kind, stem) = if let Some(stem) = pattern.strip_prefix("**.") {
        (HostKind::Many, stem)
    } else if let Some(stem) = pattern.strip_prefix("*.") {
        (HostKind::One, stem)
    } else {
        (HostKind::Exact, pattern)
    };
    if !host_word(stem) {
        return Err(Failure::InvalidPattern(text::HOST_PATTERN));
    }
    Ok((kind, stem))
}

fn host_matches(kind: HostKind, stem: &str, host: &str) -> bool {
    let mut host_labels = host.rsplit('.');
    for label in stem.rsplit('.') {
        if !host_labels
            .next()
            .is_some_and(|h| h.eq_ignore_ascii_case(label))
        {
            return false;
        }
    }
    match kind {
        HostKind::Exact => host_labels.next().is_none(),
        HostKind::One => host_labels.next().is_some() && host_labels.next().is_none(),
        HostKind::Many => host_labels.next().is_some(),
    }
}

fn path_word(word: &str) -> bool {
    if word == "/" {
        return true;
    }
    let Some(rest) = word.strip_prefix('/') else {
        return false;
    };
    !word.contains(['\0', '\\']) && rest.split('/').all(|part| !matches!(part, "" | "." | ".."))
}

fn path_pattern(pattern: &str) -> Result<(bool, &str), Failure> {
    let (tree, stem) = if pattern == "/**" {
        (true, "/")
    } else if let Some(stem) = pattern.strip_suffix("/**") {
        if stem == "/" {
            return Err(Failure::InvalidPattern(text::PATH_PATTERN));
        }
        (true, stem)
    } else {
        (false, pattern)
    };
    if stem.contains('*') || !path_word(stem) {
        return Err(Failure::InvalidPattern(text::PATH_PATTERN));
    }
    Ok((tree, stem))
}

fn path_matches(tree: bool, stem: &str, path: &str) -> bool {
    path == stem
        || (tree && (stem == "/" || path.strip_prefix(stem).is_some_and(|s| s.starts_with('/'))))
}

fn port_valid(port: i64) -> bool {
    (0..=65535).contains(&port)
}

// 未知の入力は推測しない。既知の不良をこの順で返せば、未知をどの値で埋めても
// 実行時の結果はErrorになる（設計書 02-05「本体の後の検査」）。
fn host_format<'a>(
    pattern: Option<&'a str>,
    host: Option<&'a str>,
) -> Result<Option<(HostKind, &'a str, &'a str)>, Failure> {
    let pattern = pattern.map(host_pattern).transpose()?;
    if host.is_some_and(|h| !host_word(h)) {
        return Err(Failure::InvalidTarget(text::HOST));
    }
    Ok(pattern
        .zip(host)
        .map(|((kind, stem), host)| (kind, stem, host)))
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
    let parsed = pattern.map(path_pattern).transpose()?;
    if path.is_some_and(|p| !path_word(p)) {
        return Err(Failure::InvalidTarget(text::PATH));
    }
    if let Some(((tree, stem), path)) = parsed.zip(path)
        && !path_matches(tree, stem, path)
    {
        return Err(Failure::OutsideScope);
    }
    Ok(pattern.zip(path).map(|(pattern, target)| CheckedPair {
        pattern,
        target,
        lowercase: false,
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
    if minimum.is_some_and(|p| !port_valid(p)) {
        return Err(Failure::InvalidMinimum);
    }
    if maximum.is_some_and(|p| !port_valid(p)) {
        return Err(Failure::InvalidMaximum);
    }
    if minimum.zip(maximum).is_some_and(|(lo, hi)| lo > hi) {
        return Err(Failure::InvalidBounds);
    }
    if port.is_some_and(|p| !port_valid(p)) {
        return Err(Failure::InvalidPort);
    }
    if let Some((kind, stem, host)) = parsed
        && !host_matches(kind, stem, host)
    {
        return Err(Failure::OutsideScope);
    }
    if let Some(((lo, hi), p)) = minimum.zip(maximum).zip(port)
        && !(lo..=hi).contains(&p)
    {
        return Err(Failure::PortOutsideScope);
    }
    Ok(pattern.zip(host).map(|(pattern, target)| CheckedPair {
        pattern,
        target,
        lowercase: true,
    }))
}
