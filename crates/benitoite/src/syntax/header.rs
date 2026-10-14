//! 先頭の部分の語と診断の位置を、構文解析と読み込みで共有する
//! （設計書 01-02「ファイルの先頭の部分」、02-03「構文の規則に伴う診断」）。

use super::ast::HeaderItem;
use crate::base::{BytePos, Span};

pub(crate) const LANGUAGE: &str = "language";
pub(crate) const DEPENDENCY: &str = "dependency";
pub(crate) const PACKAGE: &str = "package";
pub(crate) const PATH: &str = "path";
pub(crate) const EFFECTS: &str = "effects";
pub(crate) const HASH: &str = "hash";
pub(crate) const SOURCE: &str = "source";
pub(crate) const VERSION: &str = "version";
pub(crate) const COMMIT: &str = "commit";
pub(crate) const BENITOITE: &str = "Benitoite";
pub(crate) const HASH_PREFIX: &str = "sha256:";
pub(crate) const DEPENDENCY_FIELDS: &[&str] = &[PATH, HASH, EFFECTS];
pub(crate) const UNAVAILABLE_FIELDS: &[&str] = &[SOURCE, VERSION, COMMIT];
pub(crate) const PACKAGE_FIELDS: &[&str] = &["license"];

/// 項目全体から、先頭の語だけの位置を返す。
pub(crate) fn keyword(item: &HeaderItem) -> (&'static str, Span) {
    let (name, span) = match item {
        HeaderItem::Language(decl) => (LANGUAGE, decl.span),
        HeaderItem::Dependency(block) => (DEPENDENCY, block.span),
        HeaderItem::Package(block) => (PACKAGE, block.span),
    };
    // 語は固定の短い ASCII 文字列であり、長さは u32 に収まる。
    let length = u32::try_from(name.len()).unwrap_or(0);
    (
        name,
        Span {
            end: BytePos(span.start.0.saturating_add(length)),
            ..span
        },
    )
}

/// ハッシュの書式を構文解析と読み込みで共有し、誤った値では計算しない。
pub(crate) fn valid_hash(value: &str) -> bool {
    value.strip_prefix(HASH_PREFIX).is_some_and(|hash| {
        hash.len() == 64
            && hash
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    })
}

/// 記録したエフェクトは空か、カンマで区切った大文字の名前の並びとする。
pub(crate) fn valid_effects(value: &str) -> bool {
    value.is_empty()
        || value.split(',').all(|effect| {
            effect.trim().split('.').all(|part| {
                part.as_bytes().first().is_some_and(u8::is_ascii_uppercase)
                    && part
                        .bytes()
                        .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_')
            })
        })
}
