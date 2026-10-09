//! ファイルシステムを読まずにパスを結合・分解・正規化する（設計書 03-08「Path」）。

use std::ffi::OsStr;
use std::path::{Component, MAIN_SEPARATOR, Path, is_separator};

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::{CheckedLen, StrBuf, Value, ValueCtx};
use crate::runtime::{RuntimeError, Stop};

builtin! {
    /// `Path.join` の本体。空の子にも区切りを足す（設計書 03-08「Path」、ADR 0328）。
    name = "Path.join",
    pure fn join(ctx, base: &'c str, child: &'c str) -> Value<'e> {
        let mut buf = StrBuf::new("Path.join");
        if !Path::new(child).is_absolute() {
            buf.push_str(base)?;
        }
        append_child(&mut buf, child)?;
        ctx.alloc_str_buf(buf)
    }
}

builtin! {
    /// `Path.joinAll` の本体（設計書 03-08「Path」）。
    name = "Path.joinAll",
    pure fn join_all(ctx, parts: Value<'e>) -> Value<'e> {
        let mut buf = StrBuf::new("Path.joinAll");
        for value in crate::runtime::list::to_vec(&ctx, parts)? {
            let child = ctx.str(value)
                .ok_or_else(|| Stop::Internal("Path.joinAll expected String elements".into()))?;
            append_child(&mut buf, child)?;
        }
        ctx.alloc_str_buf(buf)
    }
}

// 結合のたびに上限を確かめ、絶対パスならそれまでの親を捨てる
// （設計書 03-08「Path」、02-09「一つの操作で作る値の大きさの上限」）。
fn append_child(buf: &mut StrBuf, child: &str) -> Result<(), Stop> {
    if Path::new(child).is_absolute() {
        *buf = StrBuf::new(buf.function());
    }
    if !buf.as_str().is_empty() && !buf.as_str().ends_with(is_separator) {
        buf.push_char(MAIN_SEPARATOR)?;
    }
    buf.push_str(child)
}

builtin! {
    /// `Path.parent` の本体。`"a"` と `"."` の親は `Some("")` とする
    /// （設計書 03-08「Path」、実装プラン L20「手順の要点」）。
    name = "Path.parent",
    pure fn parent(ctx, p: &'c str) -> Value<'e> {
        option_string(&ctx, Path::new(p).parent().map(Path::as_os_str), "Path.parent")
    }
}

builtin! {
    /// `Path.fileName` の本体。`.` だけのパスにも名前はない（設計書 03-08「Path」）。
    name = "Path.fileName",
    pure fn file_name(ctx, p: &'c str) -> Value<'e> {
        option_string(&ctx, Path::new(p).file_name(), "Path.fileName")
    }
}

builtin! {
    /// `Path.stem` の本体（設計書 03-08「Path」）。
    name = "Path.stem",
    pure fn stem(ctx, p: &'c str) -> Value<'e> {
        option_string(&ctx, Path::new(p).file_stem(), "Path.stem")
    }
}

builtin! {
    /// `Path.extension` の本体（設計書 03-08「Path」）。
    name = "Path.extension",
    pure fn extension(ctx, p: &'c str) -> Value<'e> {
        option_string(&ctx, Path::new(p).extension(), "Path.extension")
    }
}

fn utf8(s: &OsStr) -> Result<&str, Stop> {
    s.to_str()
        .ok_or_else(|| Stop::Internal("UTF-8 path became non-UTF-8".into()))
}

fn option_string<'e>(
    ctx: &ValueCtx<'e>,
    s: Option<&OsStr>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let value = s.map(|s| ctx.alloc_str(utf8(s)?, function)).transpose()?;
    super::option(ctx, value)
}

builtin! {
    /// `Path.withExtension` の本体。ファイル名のないパス（空、根、末尾の `..`、`.`）は
    /// 入力のまま返す（設計書 03-08「Path」、実装プラン L20「手順の要点」）。
    name = "Path.withExtension",
    pure fn with_extension(ctx, p: &'c str, extension: &'c str) -> Value<'e> {
        if extension.contains(is_separator) {
            return Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                function: "Path.withExtension",
                argument: 1,
            }));
        }
        let path = Path::new(p);
        let Some(stem) = path.file_stem() else {
            return ctx.alloc_str(p, "Path.withExtension");
        };
        let name = utf8(path.file_name()
            .ok_or_else(|| Stop::Internal("file stem without file name".into()))?)?;
        let stem = utf8(stem)?;
        let end = p.rfind(name)
            .and_then(|start| start.checked_add(stem.len()))
            .ok_or_else(|| Stop::Internal("file stem not found in UTF-8 path".into()))?;
        let prefix = p.get(..end)
            .ok_or_else(|| Stop::Internal("file stem boundary outside UTF-8 path".into()))?;
        // 区切り入りの拡張子で panic する PathBuf の API は使わず、上限付きで組み立てる
        // （設計書 03-08「Path」、ADR 0328）。
        let mut buf = StrBuf::new("Path.withExtension");
        buf.push_str(prefix)?;
        if !extension.is_empty() {
            buf.push_char('.')?;
            buf.push_str(extension)?;
        }
        ctx.alloc_str_buf(buf)
    }
}

builtin! {
    /// `Path.isAbsolute` の本体（設計書 03-08「Path」）。
    name = "Path.isAbsolute",
    pure fn is_absolute(ctx, p: &'c str) -> bool {
        let _ = ctx;
        Ok(Path::new(p).is_absolute())
    }
}

builtin! {
    /// `Path.components` の本体。`.` だけのパスは空のリストを返す（設計書 03-08「Path」）。
    name = "Path.components",
    pure fn components(ctx, p: &'c str) -> Value<'e> {
        let parts = || Path::new(p).components().filter(|c| !matches!(c, Component::CurDir));
        CheckedLen::elements(super::count(parts().count())?, "Path.components")?;
        let mut values = Vec::new();
        for part in parts() {
            values.push(ctx.alloc_str(utf8(part.as_os_str())?, "Path.components")?);
        }
        crate::runtime::list::from_values(&ctx, &values, "Path.components")
    }
}

builtin! {
    /// `Path.normalize` の本体。空と `.` だけのパスは `"."` を返す（設計書 03-08「Path」）。
    name = "Path.normalize",
    pure fn normalize(ctx, p: &'c str) -> Value<'e> {
        let path = Path::new(p);
        let mut parts = Vec::new();
        for part in path.components() {
            match part {
                Component::CurDir => {}
                Component::ParentDir => {
                    if matches!(parts.last(), Some(Component::Normal(_))) {
                        parts.pop();
                    } else if !path.is_absolute() {
                        parts.push(part);
                    }
                }
                Component::Prefix(_) | Component::RootDir | Component::Normal(_) => parts.push(part),
            }
        }
        let mut buf = StrBuf::new("Path.normalize");
        for part in parts {
            append_child(&mut buf, utf8(part.as_os_str())?)?;
        }
        if buf.as_str().is_empty() {
            buf.push_char('.')?;
        }
        ctx.alloc_str_buf(buf)
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    join::DECL,
    join_all::DECL,
    parent::DECL,
    file_name::DECL,
    stem::DECL,
    extension::DECL,
    with_extension::DECL,
    is_absolute::DECL,
    components::DECL,
    normalize::DECL,
];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::arithmetic_side_effects,
        clippy::indexing_slicing
    )]
    // 関門: 03-08 の返す値と L20 の端のケースを守る。空の親、隠しファイル、
    // 根を越える ..、絶対パスによる置き換えの退行を捕まえる。既存の表のテストは
    // 本体を呼ばないため、この失敗を捕まえない。差し込み口や公開範囲は加えない。
    // 本体を直接呼ぶ形は、実装プラン 10-15「確かめること」の個別指示に従う。
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::builtins::table::tags;
    use crate::runtime::heap::{CtorTag, FieldsKind, Heap, HeapConfig};

    fn option_text<'a, 'e>(ctx: &'a ValueCtx<'e>, value: Value<'e>) -> Option<&'a str> {
        if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
            return None;
        }
        assert_eq!(
            ctx.fields_header(value),
            Some((FieldsKind::Ctor, tags::OPTION_SOME))
        );
        assert_eq!(ctx.fields_len(value), Some(1));
        Some(ctx.str(ctx.field(value, 0).unwrap()).unwrap())
    }

    #[test]
    fn join_preserves_spelling_and_replaces_base_for_absolute_child() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (base, child, expected) in [
                ("", "a", "a"),
                ("a/", "b", "a/b"),
                ("a", "", "a/"),
                ("a", "/b", "/b"),
                ("", "", ""),
                ("a/", "", "a/"),
                ("/", "", "/"),
                ("a//", "b", "a//b"),
                ("a", "./b", "a/./b"),
                ("/a", "../b/", "/a/../b/"),
                ("資料", "名前.txt", "資料/名前.txt"),
                ("a", "b\\c", "a/b\\c"),
            ] {
                let value = direct!(ctx, join, base, child).unwrap();
                assert_eq!(ctx.str(value), Some(expected), "join({base:?}, {child:?})");
            }
        });
    }

    #[test]
    fn join_all_folds_in_order_including_empty_and_absolute_parts() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (parts, expected) in [
                (&[][..], ""),
                (&[""][..], ""),
                (&["", "a"][..], "a"),
                (&["a", "b", "c"][..], "a/b/c"),
                (&["a", ""][..], "a/"),
                (&["a/", "", "b"][..], "a/b"),
                (&["a", "/b", "c", ""][..], "/b/c/"),
                (&["/", "a//b", "..", "c"][..], "/a//b/../c"),
            ] {
                let values = parts
                    .iter()
                    .map(|s| ctx.alloc_str(s, "test").unwrap())
                    .collect::<Vec<_>>();
                let list = crate::runtime::list::from_values(ctx, &values, "test").unwrap();
                let value = direct!(ctx, join_all, list).unwrap();
                assert_eq!(ctx.str(value), Some(expected), "joinAll({parts:?})");
            }
        });
    }

    #[test]
    fn decomposition_returns_options_for_parents_names_stems_and_extensions() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (p, par, name, base, ext) in [
                ("", None, None, None, None),
                ("/", None, None, None, None),
                (".", Some(""), None, None, None),
                ("a", Some(""), Some("a"), Some("a"), None),
                ("/a", Some("/"), Some("a"), Some("a"), None),
                ("a/b/", Some("a"), Some("b"), Some("b"), None),
                ("a//b", Some("a"), Some("b"), Some("b"), None),
                ("./a", Some("."), Some("a"), Some("a"), None),
                ("a/./b", Some("a"), Some("b"), Some("b"), None),
                ("a/..", Some("a"), None, None, None),
                ("..", Some(""), None, None, None),
                ("a/.", Some(""), Some("a"), Some("a"), None),
                (
                    "a.tar.gz",
                    Some(""),
                    Some("a.tar.gz"),
                    Some("a.tar"),
                    Some("gz"),
                ),
                (".bashrc", Some(""), Some(".bashrc"), Some(".bashrc"), None),
                (
                    ".config.toml",
                    Some(""),
                    Some(".config.toml"),
                    Some(".config"),
                    Some("toml"),
                ),
                ("a.", Some(""), Some("a."), Some("a"), Some("")),
                (
                    "資料/名前.文",
                    Some("資料"),
                    Some("名前.文"),
                    Some("名前"),
                    Some("文"),
                ),
            ] {
                for (actual, expected) in [
                    (direct!(ctx, parent, p).unwrap(), par),
                    (direct!(ctx, file_name, p).unwrap(), name),
                    (direct!(ctx, stem, p).unwrap(), base),
                    (direct!(ctx, extension, p).unwrap(), ext),
                ] {
                    assert_eq!(option_text(ctx, actual), expected, "path {p:?}");
                }
            }
        });
    }

    #[test]
    fn with_extension_replaces_removes_and_preserves_nameless_paths() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (p, ext, expected) in [
                ("a", "txt", "a.txt"),
                ("a.tar.gz", "xz", "a.tar.xz"),
                ("a.tar.gz", "", "a.tar"),
                ("a", "", "a"),
                (".bashrc", "txt", ".bashrc.txt"),
                (".bashrc", "", ".bashrc"),
                ("a.", "txt", "a.txt"),
                ("a.", "", "a"),
                ("a/b.txt/", "md", "a/b.md"),
                ("a//b.txt/.", "md", "a//b.md"),
                ("/a/b", "tar.gz", "/a/b.tar.gz"),
                ("a", ".txt", "a..txt"),
                ("資料/名前.文", "表", "資料/名前.表"),
                ("a", "b\\c", "a.b\\c"),
                ("", "txt", ""),
                ("/", "txt", "/"),
                ("a/..", "txt", "a/.."),
                (".", "txt", "."),
            ] {
                let value = direct!(ctx, with_extension, p, ext).unwrap();
                assert_eq!(
                    ctx.str(value),
                    Some(expected),
                    "withExtension({p:?}, {ext:?})"
                );
            }
            // 名前がなくても不正な拡張子を受理しない（ADR 0328 の決定 1）。
            for p in ["a", "", "/", "a/.."] {
                assert!(matches!(
                    direct!(ctx, with_extension, p, "b/c"),
                    Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                        function: "Path.withExtension",
                        argument: 1,
                    }))
                ));
            }
        });
    }

    #[test]
    fn absolute_and_components_follow_unix_roots_and_remove_curdir() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (p, absolute, expected) in [
                ("", false, &[][..]),
                (".", false, &[][..]),
                ("/", true, &["/"][..]),
                ("///", true, &["/"][..]),
                ("a/b/", false, &["a", "b"][..]),
                ("a//b", false, &["a", "b"][..]),
                ("./a/./b", false, &["a", "b"][..]),
                ("/a/../b", true, &["/", "a", "..", "b"][..]),
                ("../a", false, &["..", "a"][..]),
                ("/../a", true, &["/", "..", "a"][..]),
                ("資料/名前.文", false, &["資料", "名前.文"][..]),
                ("a\\b", false, &["a\\b"][..]),
            ] {
                assert_eq!(
                    direct!(ctx, is_absolute, p).unwrap(),
                    absolute,
                    "path {p:?}"
                );
                let value = direct!(ctx, components, p).unwrap();
                let actual = crate::runtime::list::to_vec(ctx, value).unwrap();
                let actual = actual
                    .iter()
                    .map(|v| ctx.str(*v).unwrap())
                    .collect::<Vec<_>>();
                assert_eq!(actual, expected, "components({p:?})");
            }
        });
    }

    #[test]
    fn normalize_cancels_only_normal_components_and_never_crosses_root() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (p, expected) in [
                ("", "."),
                (".", "."),
                ("././", "."),
                ("/", "/"),
                ("///", "/"),
                ("a/b/", "a/b"),
                ("a//b", "a/b"),
                ("a/./b/../c", "a/c"),
                ("../a", "../a"),
                ("/../a", "/a"),
                ("a/..", "."),
                ("../../a", "../../a"),
                ("a/../../b", "../b"),
                ("/a/../../b", "/b"),
                ("/a/..", "/"),
                ("../a/..", ".."),
                (".bashrc", ".bashrc"),
                ("資料/./名前/../文", "資料/文"),
            ] {
                let value = direct!(ctx, normalize, p).unwrap();
                assert_eq!(ctx.str(value), Some(expected), "normalize({p:?})");
            }
        });
    }

    // 関門: 独立した再構成と冪等性の契約を、固定例にない組み合わせでも守る。
    // 期待値を標準ライブラリで作らず、組み込みの返す値どうしの関係で確かめる
    // （実装プラン L20「受け入れテスト」）。
    #[test]
    fn seeded_paths_preserve_normalized_parent_name_reconstruction_and_idempotence() {
        let mut seed = 0x20_ba_71_0fu64;
        let mut pick = |count: usize| {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            usize::try_from(seed % u64::try_from(count).unwrap()).unwrap()
        };
        let mut reconstructed = 0;
        for _ in 0..256 {
            let mut p = String::new();
            if pick(2) == 0 {
                p.push('/');
            }
            for _ in 0..pick(9) {
                if !p.is_empty() {
                    p.push_str(["/", "//"][pick(2)]);
                }
                p.push_str(["a", "b.txt", ".hidden", ".", "..", "資料"][pick(6)]);
            }
            if pick(3) == 0 {
                p.push('/');
            }
            Heap::new(HeapConfig::default()).epoch(|ctx| {
                let call = crate::builtins::iface::CallCtx::new(ctx, None, None, None);
                let pure = call.pure_ctx();
                let ctx = pure.values();
                let normalized = normalize(pure, p.as_str()).unwrap();
                let expected = ctx.str(normalized).unwrap();
                let twice = normalize(pure, expected).unwrap();
                assert_eq!(ctx.str(twice), Some(expected), "idempotence for {p:?}");
                let par = parent(pure, p.as_str()).unwrap();
                let name = file_name(pure, p.as_str()).unwrap();
                if let (Some(par), Some(name)) = (option_text(ctx, par), option_text(ctx, name)) {
                    let joined = join(pure, par, name).unwrap();
                    let actual = normalize(pure, ctx.str(joined).unwrap()).unwrap();
                    assert_eq!(ctx.str(actual), Some(expected), "reconstruction for {p:?}");
                    reconstructed += 1;
                }
            });
        }
        assert!(reconstructed > 100);
    }
}
