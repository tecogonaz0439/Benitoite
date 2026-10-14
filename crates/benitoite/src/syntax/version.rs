//! 言語の版の書式を構文解析と読み込みで共有する（設計書 01-02「ファイルの先頭の部分」）。

/// 大きい版、小さい版、修正版の順に比較する言語の版。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) struct Version(pub(crate) u64, pub(crate) u64, pub(crate) u64);

/// ASCII の数字三組からなる版だけを受け入れる。先頭の余分な 0 と桁あふれを拒む。
pub(crate) fn parse_version(value: &str) -> Option<Version> {
    let mut parts = value.split('.');
    let major = number(parts.next()?)?;
    let minor = number(parts.next()?)?;
    let patch = number(parts.next()?)?;
    if parts.next().is_some() {
        return None;
    }
    Some(Version(major, minor, patch))
}

fn number(value: &str) -> Option<u64> {
    if value.is_empty()
        || !value.bytes().all(|byte| byte.is_ascii_digit())
        || (value.len() > 1 && value.starts_with('0'))
    {
        return None;
    }
    value.parse().ok()
}

impl std::fmt::Display for Version {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}.{}.{}", self.0, self.1, self.2)
    }
}
