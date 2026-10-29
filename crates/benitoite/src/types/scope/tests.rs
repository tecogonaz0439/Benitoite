//! 対象の代数の公開APIに対する独立期待値（設計書 07-03「テストの設計の原則」）。

use super::*;
use ip_text::{format_address, format_pattern, parse_address, parse_pattern};

// 修正案に埋める範囲も言語の文字列リテラルでなければならない。
// 既存の所属の検査は補間の開始・引用符・制御文字を表示して再利用する境界に届かない。
#[test]
fn scope_suffix_uses_language_literals() -> Result<(), InvalidScope> {
    for (path, expected) in [
        ("/data/${name}", r#"["/data/\${name}"]"#),
        ("/data/\"quoted\"", r#"["/data/\"quoted\""]"#),
        (
            "/data/\n\r\t\u{1b}\u{200e}",
            r#"["/data/\n\r\t\u{1b}\u{200e}"]"#,
        ),
        ("/data/日本語/**", r#"["/data/日本語/**"]"#),
    ] {
        assert_eq!(Range::Path(PathPattern::parse(path)?).suffix(), expected);
    }
    let host = HostPattern::parse("a.example")?;
    assert_eq!(Range::Host(host.clone()).suffix(), r#"["a.example"]"#);
    let ports = PortRange::new(Port::new(443), Port::new(445))?;
    assert_eq!(
        Range::Endpoint(EndpointPattern { host, ports }).suffix(),
        r#"["a.example", 443..445]"#,
    );
    Ok(())
}

// 作成時の関門: 公開の代数を境界に、所属・一原子の被覆を守る
// （設計書 01-12「操作の対象の範囲の領域と被覆」）。
// 期待は手で固定した真偽値・数値・字句であり、対象の演算から生成しない。
// 既存の Scope fixture は旧入口だけで、IP/CIDR・被覆・構造比較には届かない。
// 幹の混同、族の消失、切り下げ、区間の合併があれば失敗する。テスト用の差し込み口はない。

#[test]
fn path_membership_and_atomic_cover() -> Result<(), InvalidScope> {
    for (pattern, target, expected) in [
        ("/data/**", "/data", true),
        ("/data/**", "/data/a/b", true),
        ("/data/**", "/database", false),
        ("/data/**", "/Data/a", false),
        ("/data/**", "/data/*", true),
        ("/data", "/data/a", false),
        ("/", "/", true),
        ("/", "/a", false),
        ("/**", "/", true),
        ("/**", "/日本語/a", true),
    ] {
        assert_eq!(
            PathPattern::parse(pattern)?.matches(&Path::parse(target)?),
            expected,
            "{pattern}: {target}"
        );
    }
    for (outer, inner, expected) in [
        ("/data/**", "/data", true),
        ("/data/**", "/data/**", true),
        ("/data/**", "/data/a/**", true),
        ("/data/**", "/database/**", false),
        ("/data/**", "/database", false),
        ("/data", "/data/**", false),
        ("/data", "/data", true),
        ("/data/a/**", "/data/**", false),
        ("/**", "/", true),
        ("/", "/**", false),
    ] {
        assert_eq!(
            PathPattern::parse(outer)?.covers(&PathPattern::parse(inner)?),
            expected,
            "{outer}: {inner}"
        );
    }
    Ok(())
}

#[test]
fn path_lexical_boundary_rejects_repairs() -> Result<(), InvalidScope> {
    for text in [
        "",
        "data",
        "//",
        "/data/",
        "/data//a",
        "/./a",
        "/data/../a",
        "/a\\b",
        "/a\0b",
    ] {
        assert!(Path::parse(text).is_err(), "{text:?}");
    }
    for text in [
        "*",
        "//**",
        "/data/*",
        "/data/**/a",
        "/data/**/**",
        "/data//**",
        "/data/../**",
        "/a*b",
    ] {
        assert!(PathPattern::parse(text).is_err(), "{text}");
    }
    assert_eq!(Path::parse("/")?.parts(), &[] as &[String]);
    assert_eq!(Path::parse("/a/*")?.parts(), &["a", "*"]);
    assert!(PathPattern::new(PathKind::Exact, Path::parse("/a/*")?).is_err());
    Ok(())
}

#[test]
fn name_membership_and_atomic_cover() -> Result<(), InvalidScope> {
    for (pattern, target, expected) in [
        ("EXAMPLE.com", "example.COM", true),
        ("*.example.com", "api.example.com", true),
        ("*.example.com", "example.com", false),
        ("*.example.com", "a.b.example.com", false),
        ("**.example.com", "example.com", false),
        ("**.example.com", "api.example.com", true),
        ("**.example.com", "a.b.example.com", true),
        ("**.example.com", "badexample.com", false),
        ("**.example.com", "example.com.evil", false),
        ("example.com", "a.example.com", false),
    ] {
        assert_eq!(
            NamePattern::parse(pattern)?.matches(&Name::parse(target)?),
            expected,
            "{pattern}: {target}"
        );
    }
    for (outer, inner, expected) in [
        ("example.com", "EXAMPLE.COM", true),
        ("example.com", "*.example.com", false),
        ("example.com", "**.example.com", false),
        ("*.example.com", "api.example.com", true),
        ("*.example.com", "a.b.example.com", false),
        ("*.example.com", "*.example.com", true),
        ("*.example.com", "*.a.example.com", false),
        ("*.example.com", "**.example.com", false),
        ("**.example.com", "example.com", false),
        ("**.example.com", "*.example.com", true),
        ("**.example.com", "*.a.example.com", true),
        ("**.example.com", "**.example.com", true),
        ("**.example.com", "**.a.example.com", true),
        ("**.a.example.com", "**.example.com", false),
    ] {
        assert_eq!(
            NamePattern::parse(outer)?.covers(&NamePattern::parse(inner)?),
            expected,
            "{outer}: {inner}"
        );
    }
    Ok(())
}

#[test]
fn name_and_direct_ip_classification() -> Result<(), InvalidScope> {
    for text in [
        "",
        ".a",
        "a.",
        "a..b",
        "-a",
        "a-",
        "a_b",
        "日本語",
        "127.0.0.1",
        "999.0.0.1",
        "1.02.3.4",
        "[::1]",
    ] {
        assert!(Name::parse(text).is_err(), "{text}");
    }
    for text in [
        "*",
        "*.",
        "a.*.com",
        "**.127.0.0.1",
        "*.999.0.0.1",
        "*.::1",
        "**.192.0.2.0/24",
    ] {
        assert!(HostPattern::parse(text).is_err(), "{text}");
    }
    for text in ["127.1", "123", "0x7f000001", "v1.fe80"] {
        assert!(
            matches!(HostTarget::parse(text), Ok(HostTarget::Name(_))),
            "{text}"
        );
        assert!(
            matches!(HostPattern::parse(text), Ok(HostPattern::Name(_))),
            "{text}"
        );
    }
    assert_eq!(Name::parse("API.Example")?.labels(), &["api", "example"]);
    assert_eq!(
        HostTarget::parse("127.0.0.1"),
        Ok(HostTarget::Ip(IpAddress::V4(0x7f000001)))
    );
    for text in ["999.0.0.1", "1.02.3.4", "[::1]", "[v1.fe80]", "fe80::1%en0"] {
        assert!(HostTarget::parse(text).is_err(), "{text}");
    }
    Ok(())
}

#[test]
fn ip_parser_and_formatter_have_independent_numeric_examples() -> Result<(), InvalidScope> {
    for (text, address) in [
        ("0.0.0.0", IpAddress::V4(0)),
        ("192.0.2.1", IpAddress::V4(0xc0000201)),
        ("255.255.255.255", IpAddress::V4(u32::MAX)),
        ("::", IpAddress::V6(0)),
        ("::1", IpAddress::V6(1)),
        (
            "2001:db8::1",
            IpAddress::V6(0x20010db8000000000000000000000001),
        ),
        (
            "2001:db8::1:0:0:1",
            IpAddress::V6(0x20010db8000000000001000000000001),
        ),
        (
            "2001:0:0:1::1",
            IpAddress::V6(0x20010000000000010000000000000001),
        ),
        (
            "1:2:3:4:5:6:0:8",
            IpAddress::V6(0x00010002000300040005000600000008),
        ),
        (
            "1:2:3:4:5:6::",
            IpAddress::V6(0x00010002000300040005000600000000),
        ),
        ("::c000:201", IpAddress::V6(0xc0000201)),
        ("::ffff:0.0.0.0", IpAddress::V6(0xffff00000000)),
        ("::ffff:192.0.2.1", IpAddress::V6(0xffffc0000201)),
        (
            "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
            IpAddress::V6(u128::MAX),
        ),
    ] {
        assert_eq!(parse_address(text), Ok(address), "{text}");
        assert_eq!(format_address(address), text);
    }
    Ok(())
}

#[test]
fn ip_parser_rejects_noncanonical_or_out_of_domain_text() -> Result<(), InvalidScope> {
    for text in [
        "",
        "127.1",
        "123",
        "0x7f000001",
        "192.00.2.1",
        "256.0.0.1",
        "0000.0.0.0",
        "1.2.3.4.5",
        "1.2.3.",
        "+1.2.3.4",
        " 1.2.3.4",
        "1.2.3.4\n",
        "[::1]",
        "::1%lo0",
        "[v1.fe80]",
        "v1.fe80",
        "2001:DB8::1",
        "2001:0db8::1",
        "0:0:0:0:0:0:0:1",
        "2001:db8::0:1",
        "2001:db8:0:0:1::1",
        "1:2:3:4:5:6::8",
        "::ffff:c000:201",
        "::FFFF:192.0.2.1",
        "::ffff:192.00.2.1",
        "::192.0.2.1",
        "2001:db8::192.0.2.1",
        "0:0:0:0:0:ffff:192.0.2.1",
        ":::1",
        "1::2::3",
        "1:2:3:4:5:6:7",
        "1:2:3:4:5:6:7:8:9",
        "1:2:3:4:5:6:7:8::",
        "::1:2:3:4:5:6:7:8",
        "10000::",
        "::g",
        ":1",
        "1:",
    ] {
        assert_eq!(
            parse_address(text),
            Err(InvalidScope::IpAddress),
            "{text:?}"
        );
    }
    Ok(())
}

#[test]
fn cidr_normalization_bounds_and_rejection() -> Result<(), InvalidScope> {
    for (text, address, prefix, lo, hi, canonical) in [
        (
            "0.0.0.0/0",
            IpAddress::V4(0),
            Some(0),
            0,
            0xffffffff,
            "0.0.0.0/0",
        ),
        (
            "192.168.1.0/24",
            IpAddress::V4(0xc0a80100),
            Some(24),
            0xc0a80100,
            0xc0a801ff,
            "192.168.1.0/24",
        ),
        (
            "255.255.255.254/31",
            IpAddress::V4(0xfffffffe),
            Some(31),
            0xfffffffe,
            0xffffffff,
            "255.255.255.254/31",
        ),
        (
            "192.0.2.1/32",
            IpAddress::V4(0xc0000201),
            None,
            0xc0000201,
            0xc0000201,
            "192.0.2.1",
        ),
        ("::/0", IpAddress::V6(0), Some(0), 0, u128::MAX, "::/0"),
        (
            "8000::/1",
            IpAddress::V6(0x80000000000000000000000000000000),
            Some(1),
            0x80000000000000000000000000000000,
            u128::MAX,
            "8000::/1",
        ),
        (
            "::ffff:0.0.0.0/96",
            IpAddress::V6(0xffff00000000),
            Some(96),
            0xffff00000000,
            0xffffffffffff,
            "::ffff:0.0.0.0/96",
        ),
        (
            "ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe/127",
            IpAddress::V6(u128::MAX - 1),
            Some(127),
            u128::MAX - 1,
            u128::MAX,
            "ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe/127",
        ),
        (
            "::ffff:192.0.2.1/128",
            IpAddress::V6(0xffffc0000201),
            None,
            0xffffc0000201,
            0xffffc0000201,
            "::ffff:192.0.2.1",
        ),
    ] {
        let p = parse_pattern(text)?;
        assert_eq!(
            (p.address(), p.prefix_len(), p.lo(), p.hi()),
            (address, prefix, lo, hi),
            "{text}"
        );
        assert_eq!(format_pattern(p), canonical);
    }
    for (text, expected) in [
        ("192.168.1.5/24", InvalidScope::HostBits),
        ("0.0.0.1/0", InvalidScope::HostBits),
        ("::1/0", InvalidScope::HostBits),
        ("::1/127", InvalidScope::HostBits),
        ("::ffff:192.0.2.1/96", InvalidScope::HostBits),
        ("0.0.0.0/33", InvalidScope::PrefixLength),
        ("::/129", InvalidScope::PrefixLength),
        ("::/256", InvalidScope::PrefixLength),
        ("::/9999", InvalidScope::PrefixLength),
        ("::/00", InvalidScope::PrefixLength),
        ("::/01", InvalidScope::PrefixLength),
        ("::/+1", InvalidScope::PrefixLength),
        ("::/-1", InvalidScope::PrefixLength),
        ("::/", InvalidScope::PrefixLength),
        ("::/1/2", InvalidScope::PrefixLength),
        ("::/ 1", InvalidScope::PrefixLength),
        ("::/１", InvalidScope::PrefixLength),
    ] {
        assert_eq!(parse_pattern(text), Err(expected), "{text}");
    }
    assert_eq!(
        IpPattern::cidr(IpAddress::V4(0), 255),
        Err(InvalidScope::PrefixLength)
    );
    assert_eq!(
        IpPattern::cidr(IpAddress::V6(1), 127),
        Err(InvalidScope::HostBits)
    );
    assert_eq!(
        IpPattern::cidr(IpAddress::V4(u32::MAX), 32),
        Ok(IpPattern::exact(IpAddress::V4(u32::MAX)))
    );
    assert_eq!(
        IpPattern::cidr(IpAddress::V6(u128::MAX), 128),
        Ok(IpPattern::exact(IpAddress::V6(u128::MAX)))
    );
    Ok(())
}

#[test]
fn ip_membership_keeps_family_and_closed_endpoints() -> Result<(), InvalidScope> {
    for (pattern, target, expected) in [
        ("192.168.1.0/24", IpAddress::V4(0xc0a80100), true),
        ("192.168.1.0/24", IpAddress::V4(0xc0a801ff), true),
        ("192.168.1.0/24", IpAddress::V4(0xc0a800ff), false),
        ("192.168.1.0/24", IpAddress::V4(0xc0a80200), false),
        ("0.0.0.0/0", IpAddress::V4(u32::MAX), true),
        ("0.0.0.0/0", IpAddress::V6(0xffffc0000201), false),
        ("::/0", IpAddress::V6(u128::MAX), true),
        ("::/0", IpAddress::V4(0), false),
        ("::ffff:0.0.0.0/96", IpAddress::V6(0xffffc0000201), true),
        ("::ffff:0.0.0.0/96", IpAddress::V4(0xc0000201), false),
        ("192.0.2.1", IpAddress::V6(0xffffc0000201), false),
        ("::ffff:192.0.2.1", IpAddress::V6(0xffffc0000201), true),
        ("::ffff:192.0.2.1", IpAddress::V4(0xc0000201), false),
    ] {
        assert_eq!(
            parse_pattern(pattern)?.matches(target),
            expected,
            "{pattern}: {target:?}"
        );
    }
    Ok(())
}

#[test]
fn ip_atomic_cover_is_same_family_interval_inclusion() -> Result<(), InvalidScope> {
    for (outer, inner, expected) in [
        ("192.168.1.0/24", "192.168.1.128/25", true),
        ("192.168.1.0/24", "192.168.1.0", true),
        ("192.168.1.0/24", "192.168.1.255", true),
        ("192.168.1.0/24", "192.168.2.0/24", false),
        ("192.168.1.128/25", "192.168.1.0/24", false),
        ("192.0.2.1", "192.0.2.1/32", true),
        ("192.0.2.1", "192.0.2.0/31", false),
        ("0.0.0.0/0", "::/0", false),
        ("::/0", "0.0.0.0/0", false),
        ("::/0", "::ffff:0.0.0.0/96", true),
        ("::ffff:0.0.0.0/96", "::ffff:192.0.2.1", true),
        ("::ffff:0.0.0.0/96", "192.0.2.1", false),
        ("::1", "::1/128", true),
        ("::1", "::/127", false),
    ] {
        assert_eq!(
            parse_pattern(outer)?.covers(parse_pattern(inner)?),
            expected,
            "{outer}: {inner}"
        );
    }
    Ok(())
}

#[test]
fn host_name_and_ip_never_convert_into_each_other() -> Result<(), InvalidScope> {
    for (outer, inner, expected) in [
        ("**.example.com", "a.example.com", true),
        ("**.0.0.1", "127.0.0.1", false),
        ("0.0.0.0/0", "localhost", false),
        ("::/0", "localhost", false),
        ("localhost", "::1", false),
        ("::/0", "0.0.0.0/0", false),
    ] {
        assert_eq!(
            HostPattern::parse(outer)?.covers(&HostPattern::parse(inner)?),
            expected,
            "{outer}: {inner}"
        );
    }
    for (pattern, target, expected) in [
        ("**.0.0.1", "127.0.0.1", false),
        ("::/0", "localhost", false),
        ("localhost", "::1", false),
        ("192.0.2.0/24", "192.0.2.1", true),
    ] {
        assert_eq!(
            HostPattern::parse(pattern)?.matches(&HostTarget::parse(target)?),
            expected,
            "{pattern}: {target}"
        );
    }
    Ok(())
}

fn ports(lo: u16, hi: u16) -> Result<PortRange, InvalidScope> {
    PortRange::new(Port::new(lo), Port::new(hi))
}

#[test]
fn ports_and_endpoint_product_use_closed_bounds() -> Result<(), InvalidScope> {
    for (input, expected) in [
        (i64::MIN, None),
        (-1, None),
        (0, Some(0)),
        (65535, Some(65535)),
        (65536, None),
        (i64::MAX, None),
    ] {
        assert_eq!(Port::from_int(input).map(Port::value), expected);
    }
    assert_eq!(
        PortRange::new(Port::new(1), Port::new(0)),
        Err(InvalidScope::PortBounds)
    );
    for (lo, hi, p, expected) in [
        (0, 65535, 0, true),
        (0, 65535, 65535, true),
        (443, 445, 443, true),
        (443, 445, 445, true),
        (443, 445, 442, false),
        (443, 445, 446, false),
        (0, 0, 0, true),
        (65535, 65535, 65535, true),
    ] {
        assert_eq!(ports(lo, hi)?.matches(Port::new(p)), expected);
    }
    let outer = EndpointPattern {
        host: HostPattern::parse("**.example.com")?,
        ports: ports(443, 445)?,
    };
    for (host, port, expected) in [
        ("api.example.com", 443, true),
        ("a.b.example.com", 445, true),
        ("example.com", 443, false),
        ("api.example.com", 442, false),
        ("api.example.com", 446, false),
        ("192.0.2.1", 443, false),
    ] {
        assert_eq!(
            outer.matches(&Endpoint {
                host: HostTarget::parse(host)?,
                port: Port::new(port)
            }),
            expected
        );
    }
    for (host, lo, hi, expected) in [
        ("*.example.com", 443, 445, true),
        ("a.example.com", 444, 444, true),
        ("*.example.com", 442, 445, false),
        ("*.example.com", 443, 446, false),
        ("example.com", 443, 445, false),
        ("0.0.0.0/0", 443, 445, false),
    ] {
        assert_eq!(
            outer.covers(&EndpointPattern {
                host: HostPattern::parse(host)?,
                ports: ports(lo, hi)?
            }),
            expected
        );
    }
    Ok(())
}

#[test]
fn atomic_cover_does_not_combine_a_union() -> Result<(), InvalidScope> {
    let host = HostPattern::parse("api.example.com")?;
    let inner = Range::Endpoint(EndpointPattern {
        host: host.clone(),
        ports: ports(0, 9)?,
    });
    let halves = [
        Range::Endpoint(EndpointPattern {
            host: host.clone(),
            ports: ports(0, 4)?,
        }),
        Range::Endpoint(EndpointPattern {
            host,
            ports: ports(5, 9)?,
        }),
    ];
    assert!(!halves.iter().any(|outer| outer.covers(&inner)));
    // 和としては全点を含むが、一原子の被覆では通らない。
    for p in 0..=9 {
        let target = Target::Endpoint(Endpoint {
            host: HostTarget::parse("api.example.com")?,
            port: Port::new(p),
        });
        assert!(halves.iter().any(|outer| outer.matches(&target)));
    }
    let subnet = parse_pattern("192.0.2.0/24")?;
    let halves = ["192.0.2.0/25", "192.0.2.128/25"]
        .into_iter()
        .map(parse_pattern)
        .collect::<Result<Vec<_>, _>>()?;
    assert!(!halves.into_iter().any(|outer| outer.covers(subnet)));
    Ok(())
}

#[test]
fn top_and_kinds_follow_domain_instead_of_set_equivalence() -> Result<(), InvalidScope> {
    let root = Range::Path(PathPattern::parse("/**")?);
    let all_v4 = Range::Host(HostPattern::parse("0.0.0.0/0")?);
    let target = Target::Host(HostTarget::parse("localhost")?);
    assert!(Range::Top.matches(&target));
    assert!(Range::Top.matches_kind(Kind::Host, &target));
    assert!(!Range::Top.matches_kind(Kind::Path, &target));
    assert!(!root.matches(&target));
    assert!(root.fits_kind(Kind::Path));
    assert!(!root.fits_kind(Kind::Host));
    assert_eq!(root.kind(), Some(Kind::Path));
    assert_eq!(Range::Top.kind(), None);
    for kind in [Kind::Path, Kind::Host, Kind::Endpoint] {
        assert!(Range::Top.fits_kind(kind));
    }
    assert!(Range::Top.covers(&Range::Top));
    for range in [root, all_v4] {
        assert!(Range::Top.covers(&range));
        assert!(!range.covers(&Range::Top));
    }
    assert!(
        !Range::Host(HostPattern::parse("localhost")?)
            .covers(&Range::Path(PathPattern::parse("/localhost")?))
    );
    Ok(())
}

#[test]
fn equality_hash_and_order_preserve_narrow_atoms() -> Result<(), InvalidScope> {
    use std::collections::{BTreeSet, HashSet};
    let broad = Range::Path(PathPattern::parse("/data/**")?);
    let narrow = Range::Path(PathPattern::parse("/data/a")?);
    assert!(broad.covers(&narrow));
    assert_ne!(broad, narrow);
    let mut sorted = vec![broad.clone(), narrow.clone(), narrow.clone()];
    sorted.sort();
    sorted.dedup();
    assert_eq!(sorted.len(), 2);
    assert!(sorted.contains(&narrow));
    assert!(sorted.contains(&broad));
    assert_eq!(BTreeSet::from([broad.clone(), narrow.clone()]).len(), 2);
    assert_eq!(HashSet::from([broad, narrow]).len(), 2);
    let exact = HostPattern::parse("192.0.2.1")?;
    let max_prefix = HostPattern::parse("192.0.2.1/32")?;
    assert_eq!(exact, max_prefix);
    assert_eq!(HashSet::from([exact, max_prefix]).len(), 1);
    assert_eq!(
        HostPattern::parse("EXAMPLE.COM"),
        HostPattern::parse("example.com")
    );
    assert_ne!(
        HostPattern::parse("::ffff:192.0.2.1")?,
        HostPattern::parse("192.0.2.1")?
    );
    Ok(())
}
