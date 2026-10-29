//! IP/CIDR の文字列との境界。所属・被覆は親モジュールの解析済み数値で行う。
//! 採択した正規形の入力に限る（設計書 01-12「操作の対象の範囲の領域と被覆」）。
//! URL の host の抽出や非正規数値 host の分類はここで行わない。

use super::{InvalidScope, IpAddress, IpPattern};

/// 四つの空でない ASCII 全数字ラベル。IPv4 として不正でも Name へ戻さない。
pub fn four_digit_labels(text: &str) -> bool {
    let mut labels = text.split('.');
    for _ in 0..4 {
        if !labels
            .next()
            .is_some_and(|s| !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()))
        {
            return false;
        }
    }
    labels.next().is_none()
}

/// 正規形だけを受け付ける。IPv6 の大小文字や圧縮の違いを補正して受理しない。
pub fn parse_address(text: &str) -> Result<IpAddress, InvalidScope> {
    if text.contains(':') {
        let address = IpAddress::V6(parse_v6(text)?);
        if format_address(address) != text {
            return Err(InvalidScope::IpAddress);
        }
        Ok(address)
    } else {
        parse_v4(text).map(IpAddress::V4)
    }
}

fn parse_v4(text: &str) -> Result<u32, InvalidScope> {
    let mut labels = text.split('.');
    let mut octets = [0u8; 4];
    for octet in &mut octets {
        let label = labels.next().ok_or(InvalidScope::IpAddress)?;
        if label.is_empty()
            || label.len() > 3
            || (label.len() > 1 && label.starts_with('0'))
            || !label.bytes().all(|b| b.is_ascii_digit())
        {
            return Err(InvalidScope::IpAddress);
        }
        *octet = label.parse().map_err(|_| InvalidScope::IpAddress)?;
    }
    if labels.next().is_some() {
        return Err(InvalidScope::IpAddress);
    }
    Ok(u32::from_be_bytes(octets))
}

fn parse_v6(text: &str) -> Result<u128, InvalidScope> {
    // 混合表記を許す prefix は mapped だけである。
    if let Some(tail) = text.strip_prefix("::ffff:")
        && tail.contains('.')
    {
        return Ok((0xffffu128 << 32) | u128::from(parse_v4(tail)?));
    }
    let mut groups = [0u16; 8];
    if let Some((left, right)) = text.split_once("::") {
        let left_count = parse_v6_groups(left, &mut groups)?;
        let mut suffix = [0u16; 8];
        let right_count = parse_v6_groups(right, &mut suffix)?;
        // :: は少なくとも一要素を埋める。各 count は 0..=8。
        if left_count.saturating_add(right_count) >= 8 {
            return Err(InvalidScope::IpAddress);
        }
        for (slot, value) in groups
            .iter_mut()
            .rev()
            .zip(suffix.iter().take(right_count).rev())
        {
            *slot = *value;
        }
    } else if parse_v6_groups(text, &mut groups)? != 8 {
        return Err(InvalidScope::IpAddress);
    }
    Ok(groups
        .into_iter()
        .fold(0u128, |n, g| (n << 16) | u128::from(g)))
}

fn parse_v6_groups(text: &str, groups: &mut [u16; 8]) -> Result<usize, InvalidScope> {
    if text.is_empty() {
        return Ok(0);
    }
    let mut count = 0;
    for (i, label) in text.split(':').enumerate() {
        let slot = groups.get_mut(i).ok_or(InvalidScope::IpAddress)?;
        if label.is_empty() || label.len() > 4 || !label.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(InvalidScope::IpAddress);
        }
        *slot = u16::from_str_radix(label, 16).map_err(|_| InvalidScope::IpAddress)?;
        count = i.saturating_add(1);
    }
    Ok(count)
}

/// host bits を切り下げず拒否する。最大 prefix の CIDR は exact へそろえる。
pub fn parse_pattern(text: &str) -> Result<IpPattern, InvalidScope> {
    if let Some((address, prefix)) = text.split_once('/') {
        if prefix.is_empty()
            || prefix.len() > 3
            || (prefix.len() > 1 && prefix.starts_with('0'))
            || !prefix.bytes().all(|b| b.is_ascii_digit())
        {
            return Err(InvalidScope::PrefixLength);
        }
        let address = parse_address(address)?;
        let prefix = prefix.parse().map_err(|_| InvalidScope::PrefixLength)?;
        IpPattern::cidr(address, prefix)
    } else {
        parse_address(text).map(IpPattern::exact)
    }
}

/// 採択した正規形。mapped だけを混合表記にし、他は小文字の16進表記にする。
pub fn format_address(address: IpAddress) -> String {
    match address {
        IpAddress::V4(n) => format_v4(n.to_be_bytes()),
        IpAddress::V6(n) => {
            let [a, b, c, d, e, f, g, h, i, j, k, l, m, o, p, q] = n.to_be_bytes();
            if n >> 32 == 0xffff {
                return format!("::ffff:{}", format_v4([m, o, p, q]));
            }
            let groups = [
                u16::from_be_bytes([a, b]),
                u16::from_be_bytes([c, d]),
                u16::from_be_bytes([e, f]),
                u16::from_be_bytes([g, h]),
                u16::from_be_bytes([i, j]),
                u16::from_be_bytes([k, l]),
                u16::from_be_bytes([m, o]),
                u16::from_be_bytes([p, q]),
            ];
            format_v6(&groups)
        }
    }
}

fn format_v4([a, b, c, d]: [u8; 4]) -> String {
    format!("{a}.{b}.{c}.{d}")
}

fn format_v6(groups: &[u16; 8]) -> String {
    // 長さ2以上の最長の零列を一つ圧縮する。同長なら左を保つ。
    let (mut best_start, mut best_len, mut run_len) = (0usize, 0usize, 0usize);
    for (i, group) in groups.iter().enumerate() {
        if *group == 0 {
            run_len = run_len.saturating_add(1);
            if run_len > best_len {
                best_len = run_len;
                best_start = i.saturating_add(1).saturating_sub(run_len);
            }
        } else {
            run_len = 0;
        }
    }
    let join = |start: usize, count: usize| {
        groups
            .iter()
            .skip(start)
            .take(count)
            .map(|g| format!("{g:x}"))
            .collect::<Vec<_>>()
            .join(":")
    };
    if best_len < 2 {
        join(0, groups.len())
    } else {
        format!(
            "{}::{}",
            join(0, best_start),
            join(best_start.saturating_add(best_len), groups.len())
        )
    }
}

/// 正規化済みの完全一致またはCIDRを文字列にする。
pub fn format_pattern(pattern: IpPattern) -> String {
    let address = format_address(pattern.address());
    match pattern.prefix_len() {
        Some(prefix) => format!("{address}/{prefix}"),
        None => address,
    }
}
