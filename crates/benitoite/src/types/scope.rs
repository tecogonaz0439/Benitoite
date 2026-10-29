//! 対象の正規形・所属・一原子の被覆。比較と hash は構造を使う
//! （設計書 01-12「操作の対象の範囲の領域と被覆」）。
//!
//! `formal/Benitoite/Scope/{Domain,Cover,IPCover,RangeCover}.lean` に対応する。
//! 字句の入口は不正な入力を補完しない。IP の文字列との境界は `ip_text` に分ける。
//! OS の実体・DNS・通信には依存しない。`covers` は外側を self、内側を引数とする。

/// IP/CIDR の正規形の文字列との変換。
pub mod ip_text;

/// 範囲の構築の失敗。入力の不良と内部の不具合を区別し、利用側で診断へ変換する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InvalidScope {
    /// 処理系の内部で範囲の不変条件が破れた。入力の誤りとは区別する。
    Internal,
    /// 絶対パスの形式または要素が不正である。
    Path,
    /// パスのパターンの形式または幹が不正である。
    PathPattern,
    /// ホスト名のラベルが不正であるか、四つの全数字ラベルである。
    Name,
    /// IP アドレスの字句が不正であるか、採択した正規形でない。
    IpAddress,
    /// CIDR の prefix の字句が不正であるか、族の幅を超える。
    PrefixLength,
    /// CIDR のネットワークの host bits が 0 でない。
    HostBits,
    /// ポートの閉区間の下端が上端を超える。
    PortBounds,
}

/// 正規の絶対パス。根は空の要素列。対象の `*` は普通の文字である。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Path(Vec<String>);

impl Path {
    /// 絶対形式を検査して要素列にする。補完やリンクの解決は行わない。
    pub fn parse(text: &str) -> Result<Self, InvalidScope> {
        if text == "/" {
            return Ok(Self(Vec::new()));
        }
        let rest = text.strip_prefix('/').ok_or(InvalidScope::Path)?;
        if text.contains(['\0', '\\']) || rest.split('/').any(|p| matches!(p, "" | "." | "..")) {
            return Err(InvalidScope::Path);
        }
        Ok(Self(rest.split('/').map(str::to_owned).collect()))
    }

    /// 根からの順の要素列を返す。根では空列になる。
    pub fn parts(&self) -> &[String] {
        &self.0
    }
}

/// パスの完全一致と木の区別。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum PathKind {
    Exact,
    Tree,
}

/// 幹は `*` を含まず、tree は幹自身を含む。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct PathPattern {
    kind: PathKind,
    stem: Path,
}

impl PathPattern {
    /// 正規のパスに種類を付ける。幹にワイルドカードがあれば拒否する。
    pub fn new(kind: PathKind, stem: Path) -> Result<Self, InvalidScope> {
        if stem.parts().iter().any(|p| p.contains('*')) {
            return Err(InvalidScope::PathPattern);
        }
        Ok(Self { kind, stem })
    }

    /// 完全一致または末尾 `/**` の木だけを受け付ける。
    pub fn parse(text: &str) -> Result<Self, InvalidScope> {
        let (kind, stem) = if text == "/**" {
            (PathKind::Tree, "/")
        } else if let Some(stem) = text.strip_suffix("/**") {
            if stem == "/" {
                return Err(InvalidScope::PathPattern);
            }
            (PathKind::Tree, stem)
        } else {
            (PathKind::Exact, text)
        };
        Self::new(
            kind,
            Path::parse(stem).map_err(|_| InvalidScope::PathPattern)?,
        )
    }

    /// 完全一致か木かを返す。
    pub fn kind(&self) -> PathKind {
        self.kind
    }

    /// 検査済みの幹を返す。
    pub fn stem(&self) -> &Path {
        &self.stem
    }

    /// 対象の要素列への所属を判定する。木は幹自身を含む。
    pub fn matches(&self, target: &Path) -> bool {
        match self.kind {
            PathKind::Exact => target == &self.stem,
            PathKind::Tree => target.parts().starts_with(self.stem.parts()),
        }
    }

    /// self が内側の一原子を丸ごと覆うか判定する。
    pub fn covers(&self, inner: &Self) -> bool {
        match (self.kind, inner.kind) {
            (PathKind::Exact, PathKind::Exact) => self.stem == inner.stem,
            (PathKind::Tree, _) => inner.stem.parts().starts_with(self.stem.parts()),
            (PathKind::Exact, PathKind::Tree) => false,
        }
    }
}

/// ホスト名。ASCII 小文字のラベル列を通常の順に保持する。四つの全数字ラベルは除く。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Name(Vec<String>);

impl Name {
    /// ASCII のラベルを検査して小文字化する。四つの全数字ラベルは拒否する。
    pub fn parse(text: &str) -> Result<Self, InvalidScope> {
        if ip_text::four_digit_labels(text)
            || text.split('.').any(|label| {
                label.is_empty()
                    || label.starts_with('-')
                    || label.ends_with('-')
                    || !label
                        .bytes()
                        .all(|b| b.is_ascii_alphanumeric() || b == b'-')
            })
        {
            return Err(InvalidScope::Name);
        }
        Ok(Self(text.split('.').map(str::to_ascii_lowercase).collect()))
    }

    /// 小文字化したラベル列を左から通常の順で返す。
    pub fn labels(&self) -> &[String] {
        &self.0
    }
}

/// ホスト名の完全一致・一段・一段以上の区別。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum NameKind {
    Exact,
    One,
    Many,
}

/// one はちょうど一段、many は一段以上で、いずれも幹自身を含まない。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct NamePattern {
    kind: NameKind,
    stem: Name,
}

impl NamePattern {
    /// 検査済みの幹に完全一致・一段・一段以上の種類を付ける。
    pub fn new(kind: NameKind, stem: Name) -> Self {
        Self { kind, stem }
    }

    /// 完全一致・`*.`・`**.` のホスト名パターンを受け付ける。
    pub fn parse(text: &str) -> Result<Self, InvalidScope> {
        let (kind, stem) = if let Some(stem) = text.strip_prefix("**.") {
            (NameKind::Many, stem)
        } else if let Some(stem) = text.strip_prefix("*.") {
            (NameKind::One, stem)
        } else {
            (NameKind::Exact, text)
        };
        Ok(Self::new(kind, Name::parse(stem)?))
    }

    /// ホスト名のパターンの種類を返す。
    pub fn kind(&self) -> NameKind {
        self.kind
    }

    /// 小文字化した幹を返す。
    pub fn stem(&self) -> &Name {
        &self.stem
    }

    /// ラベル単位の所属を判定する。one/many は幹自身を含まない。
    pub fn matches(&self, target: &Name) -> bool {
        let labels = target.labels();
        let stem = self.stem.labels();
        match self.kind {
            NameKind::Exact => labels == stem,
            NameKind::One => labels.split_first().is_some_and(|(_, tail)| tail == stem),
            NameKind::Many => labels.len() > stem.len() && labels.ends_with(stem),
        }
    }

    /// self が内側の一原子を丸ごと覆うか判定する。
    pub fn covers(&self, inner: &Self) -> bool {
        match (self.kind, inner.kind) {
            (_, NameKind::Exact) => self.matches(&inner.stem),
            (NameKind::One, NameKind::One) => self.stem == inner.stem,
            (NameKind::Many, _) => inner.stem.labels().ends_with(self.stem.labels()),
            _ => false,
        }
    }
}

/// IPのアドレス族。異族の値を同一視しない。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Family {
    V4,
    V6,
}

impl Family {
    /// 族の数値のビット幅（32または128）を返す。
    pub fn width(self) -> u8 {
        match self {
            Self::V4 => 32,
            Self::V6 => 128,
        }
    }
}

/// 解析済みの IP。mapped も V6 のままであり、V4 へ射影しない。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum IpAddress {
    V4(u32),
    V6(u128),
}

impl IpAddress {
    /// 数値のアドレス族を返す。mapped をV4へ変換しない。
    pub fn family(self) -> Family {
        match self {
            Self::V4(_) => Family::V4,
            Self::V6(_) => Family::V6,
        }
    }

    /// 族の幅を失わずに数値の演算を共通化するための値。
    pub fn bits(self) -> u128 {
        match self {
            Self::V4(n) => u128::from(n),
            Self::V6(n) => n,
        }
    }
}

/// 正規化した exact/CIDR。最大 prefix は exact（prefix_len が None）にそろえる。
/// フィールドは非公開にし、非零の host bits と幅を超える prefix を保持させない。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct IpPattern {
    address: IpAddress,
    prefix_len: Option<u8>,
    // 構築時に検査したマスク。上端の参照時には失敗する計算を残さない。
    host_mask: u128,
}

impl IpPattern {
    /// 一つの族と数値を完全一致のパターンにする。
    pub fn exact(address: IpAddress) -> Self {
        Self {
            address,
            prefix_len: None,
            host_mask: 0,
        }
    }

    /// prefix と host bits を検査する。最大 prefix は完全一致へそろえる。
    pub fn cidr(address: IpAddress, prefix_len: u8) -> Result<Self, InvalidScope> {
        let width = address.family().width();
        let host_bits = width
            .checked_sub(prefix_len)
            .ok_or(InvalidScope::PrefixLength)?;
        let host_mask = host_mask(host_bits)?;
        if address.bits() & host_mask != 0 {
            return Err(InvalidScope::HostBits);
        }
        Ok(Self {
            address,
            prefix_len: (prefix_len < width).then_some(prefix_len),
            host_mask,
        })
    }

    /// 完全一致の点、またはCIDRのネットワークの値を返す。
    pub fn address(self) -> IpAddress {
        self.address
    }

    /// CIDRのprefixを返す。完全一致ではNoneになる。
    pub fn prefix_len(self) -> Option<u8> {
        self.prefix_len
    }

    /// 同族の閉区間の下端を返す。
    pub fn lo(self) -> u128 {
        self.address.bits()
    }

    /// 同族の閉区間の上端を幅内の値で返す。
    pub fn hi(self) -> u128 {
        self.lo() | self.host_mask
    }

    /// 同じ族かつ閉区間内かを判定する。
    pub fn matches(self, target: IpAddress) -> bool {
        self.address.family() == target.family()
            && self.lo() <= target.bits()
            && target.bits() <= self.hi()
    }

    /// self が同族の内側の閉区間全体を覆うか判定する。
    pub fn covers(self, inner: Self) -> bool {
        self.address.family() == inner.address.family()
            && self.lo() <= inner.lo()
            && inner.hi() <= self.hi()
    }
}

// host_bits は検査済みの width - prefix、0..=128。2^128 自身を作らない。
fn host_mask(host_bits: u8) -> Result<u128, InvalidScope> {
    match host_bits {
        128 => Ok(u128::MAX),
        n => 1u128
            .checked_shl(u32::from(n))
            .map(|power| power.saturating_sub(1))
            .ok_or(InvalidScope::Internal),
    }
}

/// ホストの対象。ホスト名とIPの分類を保つ。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum HostTarget {
    Name(Name),
    Ip(IpAddress),
}

impl HostTarget {
    /// Scope の直接入力の境界。短い数値風の名前は Name のまま扱う。
    pub fn parse(text: &str) -> Result<Self, InvalidScope> {
        if text.contains(':') || ip_text::four_digit_labels(text) {
            ip_text::parse_address(text).map(Self::Ip)
        } else {
            Name::parse(text).map(Self::Name)
        }
    }
}

/// ホストの一原子のパターン。DNSによる変換は含まない。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum HostPattern {
    Name(NamePattern),
    Ip(IpPattern),
}

impl HostPattern {
    /// 直接入力をホスト名またはIP/CIDRに分け、検査して正規化する。
    pub fn parse(text: &str) -> Result<Self, InvalidScope> {
        if text.contains(':') || text.contains('/') || ip_text::four_digit_labels(text) {
            ip_text::parse_pattern(text).map(Self::Ip)
        } else {
            NamePattern::parse(text).map(Self::Name)
        }
    }

    /// ホスト名どうし、またはIPどうしの所属を判定する。相互変換しない。
    pub fn matches(&self, target: &HostTarget) -> bool {
        match (self, target) {
            (Self::Name(p), HostTarget::Name(t)) => p.matches(t),
            (Self::Ip(p), HostTarget::Ip(t)) => p.matches(*t),
            _ => false,
        }
    }

    /// self が同じ分類の内側の一原子を覆うか判定する。
    pub fn covers(&self, inner: &Self) -> bool {
        match (self, inner) {
            (Self::Name(p), Self::Name(q)) => p.covers(q),
            (Self::Ip(p), Self::Ip(q)) => p.covers(*q),
            _ => false,
        }
    }
}

/// 解析済みのポート。整数の切り詰め変換を行わない。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Port(u16);

impl Port {
    /// 幅の内側の値をポートにする。
    pub fn new(value: u16) -> Self {
        Self(value)
    }

    /// 範囲外の整数を拒否し、切り詰めずにポートへ変換する。
    pub fn from_int(value: i64) -> Option<Self> {
        u16::try_from(value).ok().map(Self)
    }

    /// 幅を保ったポートの数値を返す。
    pub fn value(self) -> u16 {
        self.0
    }
}

/// 整形式のポートの閉区間。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct PortRange {
    lo: Port,
    hi: Port,
}

impl PortRange {
    /// 端点の逆転を拒否して閉区間を作る。
    pub fn new(lo: Port, hi: Port) -> Result<Self, InvalidScope> {
        if lo > hi {
            return Err(InvalidScope::PortBounds);
        }
        Ok(Self { lo, hi })
    }

    /// 閉区間の下端を返す。
    pub fn lo(self) -> Port {
        self.lo
    }

    /// 閉区間の上端を返す。
    pub fn hi(self) -> Port {
        self.hi
    }

    /// 両端を含むポートの所属を判定する。
    pub fn matches(self, target: Port) -> bool {
        self.lo <= target && target <= self.hi
    }

    /// self の閉区間が内側の閉区間全体を含むか判定する。
    pub fn covers(self, inner: Self) -> bool {
        self.lo <= inner.lo && inner.hi <= self.hi
    }
}

/// 検査済みのhostとportの組。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Endpoint {
    /// ホスト名または IP アドレスの対象。
    pub host: HostTarget,
    /// 対象のポート。
    pub port: Port,
}

/// hostのパターンとportの閉区間の積。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct EndpointPattern {
    /// ホスト名または IP アドレスの一原子のパターン。
    pub host: HostPattern,
    /// 許すポートの閉区間。
    pub ports: PortRange,
}

impl EndpointPattern {
    /// host と port の両方の所属を要求する。
    pub fn matches(&self, target: &Endpoint) -> bool {
        self.host.matches(&target.host) && self.ports.matches(target.port)
    }

    /// host と port をともに self の一原子で覆うか判定する。
    pub fn covers(&self, inner: &Self) -> bool {
        self.host.covers(&inner.host) && self.ports.covers(inner.ports)
    }
}

/// 名前から決まる対象の種類。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Kind {
    Path,
    Host,
    Endpoint,
}

/// 操作の対象。範囲とは別に種類を保持する。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Target {
    Path(Path),
    Host(HostTarget),
    Endpoint(Endpoint),
}

impl Target {
    /// 対象の種類を返す。
    pub fn kind(&self) -> Kind {
        match self {
            Self::Path(_) => Kind::Path,
            Self::Host(_) => Kind::Host,
            Self::Endpoint(_) => Kind::Endpoint,
        }
    }
}

/// 閉じた一原子の範囲。Top の種類は名前が決める。名前の照合は利用側の責務である。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Range {
    Top,
    Path(PathPattern),
    Host(HostPattern),
    Endpoint(EndpointPattern),
}

impl Range {
    /// 原子の名前に続ける範囲の表示。Topは旧来どおり名前だけで表す。
    pub fn suffix(&self) -> String {
        fn host(pattern: &HostPattern) -> String {
            match pattern {
                HostPattern::Name(p) => format!(
                    "{}{}",
                    match p.kind() {
                        NameKind::Exact => "",
                        NameKind::One => "*.",
                        NameKind::Many => "**.",
                    },
                    p.stem().labels().join(".")
                ),
                HostPattern::Ip(p) => ip_text::format_pattern(*p),
            }
        }
        match self {
            Self::Top => String::new(),
            Self::Path(p) => {
                let stem = format!("/{}", p.stem().parts().join("/"));
                let text = match p.kind() {
                    PathKind::Exact => stem,
                    PathKind::Tree => format!("{}/**", stem.trim_end_matches('/')),
                };
                format!("[{}]", crate::base::literal::quoted(text.chars(), '"'))
            }
            Self::Host(p) => format!("[{}]", crate::base::literal::quoted(host(p).chars(), '"')),
            Self::Endpoint(p) => {
                let lo = p.ports.lo().value();
                let hi = p.ports.hi().value();
                let ports = if lo == hi {
                    lo.to_string()
                } else {
                    format!("{lo}..{hi}")
                };
                format!(
                    "[{}, {ports}]",
                    crate::base::literal::quoted(host(&p.host).chars(), '"')
                )
            }
        }
    }

    /// 非Topの種類を返す。Topの種類は名前が決めるためNoneとする。
    pub fn kind(&self) -> Option<Kind> {
        match self {
            Self::Top => None,
            Self::Path(_) => Some(Kind::Path),
            Self::Host(_) => Some(Kind::Host),
            Self::Endpoint(_) => Some(Kind::Endpoint),
        }
    }

    /// Top、または指定の種類と一致する範囲か判定する。
    pub fn fits_kind(&self, kind: Kind) -> bool {
        self.kind().is_none_or(|k| k == kind)
    }

    /// Topは全対象、それ以外は同じ種類の対象への所属を判定する。
    pub fn matches(&self, target: &Target) -> bool {
        match (self, target) {
            (Self::Top, _) => true,
            (Self::Path(p), Target::Path(t)) => p.matches(t),
            (Self::Host(p), Target::Host(t)) => p.matches(t),
            (Self::Endpoint(p), Target::Endpoint(t)) => p.matches(t),
            _ => false,
        }
    }

    /// 対象の種類との一致と範囲への所属をともに要求する。
    pub fn matches_kind(&self, kind: Kind, target: &Target) -> bool {
        target.kind() == kind && self.matches(target)
    }

    /// 一原子だけを比較する。和の計算・隣接区間の合併・Top の具体化を行わない。
    pub fn covers(&self, inner: &Self) -> bool {
        match (self, inner) {
            (Self::Top, _) => true,
            (Self::Path(p), Self::Path(q)) => p.covers(q),
            (Self::Host(p), Self::Host(q)) => p.covers(q),
            (Self::Endpoint(p), Self::Endpoint(q)) => p.covers(q),
            _ => false,
        }
    }
}

#[cfg(test)]
mod tests;
