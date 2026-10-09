//! パスの操作の仕事と完了、ソースの copy とレコードの読み出しを確かめる（実装プラン L11）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::runtime_test_support::*;
use super::*;
use crate::builtins::iface::{CallCtx, IoServices};
use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx, ValueCtx};
use crate::runtime::io::resources::ResourceTable;
use crate::runtime::io::services::IoView;
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::{ExecMode, MainOutcome, StopEnd, StopReason, Vm, VmConfig, VmStep};

type PathOp = for<'c, 'e> fn(IoCtx<'c, 'e>, &'c str) -> Result<IoReply<'e>, Stop>;

fn complete<'e>(
    ctx: &mut NoGcCtx<'e>,
    services: &mut dyn IoServices,
    reply: Result<IoReply<'e>, Stop>,
) -> Result<Value<'e>, Stop> {
    let work = worker(reply?);
    assert_eq!(work.lend(), Lend::Nothing);
    work.run(Lent::Nothing).complete(
        &mut CallCtx::new(ctx, Some(services), None, None)
            .io_ctx()
            .unwrap(),
        &[],
    )
}
fn run<'e>(
    ctx: &mut NoGcCtx<'e>,
    services: &mut dyn IoServices,
    op: PathOp,
    path: &str,
) -> Result<Value<'e>, Stop> {
    let reply = op(
        CallCtx::new(ctx, Some(services), None, None)
            .io_ctx()
            .unwrap(),
        path,
    );
    complete(ctx, services, reply)
}
fn write<'e>(
    ctx: &mut NoGcCtx<'e>,
    services: &mut dyn IoServices,
    path: &str,
    bytes: &[u8],
    append: bool,
) -> Value<'e> {
    let mut call = CallCtx::new(ctx, Some(services), None, None);
    let io = call.io_ctx().unwrap();
    let reply = if append {
        append_bytes(io, path, bytes)
    } else {
        write_bytes(io, path, bytes)
    };
    complete(ctx, services, reply).unwrap()
}
fn move_path<'e>(
    ctx: &mut NoGcCtx<'e>,
    services: &mut dyn IoServices,
    from: &str,
    to: &str,
) -> Value<'e> {
    let reply = rename(
        CallCtx::new(ctx, Some(services), None, None)
            .io_ctx()
            .unwrap(),
        from,
        to,
    );
    complete(ctx, services, reply).unwrap()
}
fn ok<'e>(result: Value<'e>, tag: u32, ctx: &ValueCtx<'e>) -> Value<'e> {
    payload(ctx, result, tag)
}
fn returned_kind<'e>(result: Value<'e>, ctx: &ValueCtx<'e>) -> u32 {
    error_kind(ctx, result)
}
fn strings<'e>(result: Value<'e>, ctx: &ValueCtx<'e>) -> Vec<String> {
    crate::runtime::list::to_vec(ctx, ok(result, tags::RESULT_OK, ctx))
        .unwrap()
        .into_iter()
        .map(|v| ctx.str(v).unwrap().to_owned())
        .collect()
}
fn unit<'e>(result: Value<'e>, ctx: &ValueCtx<'e>) {
    assert!(matches!(ok(result, tags::RESULT_OK, ctx), Value::Unit));
}

// 関門: 13 項目の成功、置換・追記・基準ディレクトリ・LF/CR の契約を実物のファイルで守る。
// 既存の readText/writeText のテストは Bytes・パスの操作を呼ばない。差し込み口は加えない。
// 本体の直接呼び出しは L11 の個別の指示に従う（テスト戦略の一般的な境界の規則との違い）。
#[test]
fn path_operations_succeed_and_preserve_bytes_lines_and_relative_paths() {
    let dir = TempDir::new();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for path in ["sub/nested", "sub/nested"] {
            unit(run(ctx, &mut io, create_directory, path).unwrap(), ctx);
        }
        assert!(dir.0.join("sub/nested").is_dir());
        assert!(matches!(
            ok(
                run(ctx, &mut io, exists, "absent").unwrap(),
                tags::RESULT_OK,
                ctx
            ),
            Value::Bool(false)
        ));
        for (append, bytes, expected) in [
            (false, &b"old"[..], &b"old"[..]),
            (false, &b"\x00\xff"[..], &b"\x00\xff"[..]),
            (true, &b"a"[..], &b"\x00\xffa"[..]),
        ] {
            unit(write(ctx, &mut io, "data", bytes, append), ctx);
            let result = run(ctx, &mut io, read_bytes, "data").unwrap();
            assert_eq!(ctx.bytes(ok(result, tags::RESULT_OK, ctx)), Some(expected));
        }
        unit(write(ctx, &mut io, "new", b"new", true), ctx);
        assert_eq!(std::fs::read(dir.0.join("new")).unwrap(), b"new");
        assert!(matches!(
            ok(
                run(ctx, &mut io, exists, "data").unwrap(),
                tags::RESULT_OK,
                ctx
            ),
            Value::Bool(true)
        ));
        for &(bytes, expected) in LINE_CASES {
            std::fs::write(dir.0.join("lines"), bytes).unwrap();
            assert_eq!(
                strings(run(ctx, &mut io, read_lines, "lines").unwrap(), ctx),
                expected.iter().filter_map(|x| *x).collect::<Vec<_>>()
            );
        }
        std::fs::write(dir.0.join("lines"), "é\n日本\r\n").unwrap();
        assert_eq!(
            strings(run(ctx, &mut io, read_lines, "lines").unwrap(), ctx),
            ["é", "日本"]
        );
        let result = run(ctx, &mut io, canonicalize, "sub/../data").unwrap();
        // macOS の /private を含む絶対パスも、返ったパスが同じファイルを指すことで確かめる。
        let canonical = ctx.str(ok(result, tags::RESULT_OK, ctx)).unwrap();
        assert!(Path::new(canonical).is_absolute());
        assert_eq!(std::fs::read(canonical).unwrap(), b"\x00\xffa");
        unit(move_path(ctx, &mut io, "data", "moved"), ctx);
        assert!(!dir.0.join("data").exists());
        assert_eq!(std::fs::read(dir.0.join("moved")).unwrap(), b"\x00\xffa");
        unit(run(ctx, &mut io, remove, "moved").unwrap(), ctx);
        unit(run(ctx, &mut io, remove, "sub/nested").unwrap(), ctx);
        unit(run(ctx, &mut io, remove_tree, "sub").unwrap(), ctx);
        assert!(!dir.0.join("sub").exists());
    });
}

// 関門: OS のエラーと Result.Error の区別。表の行をまとめて確かめ、期待を OS に合わせない。
#[test]
fn path_errors_follow_the_ioerror_kind_table() {
    let dir = TempDir::new();
    std::fs::write(dir.0.join("file"), b"\xff").unwrap();
    std::fs::create_dir_all(dir.0.join("full/child")).unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (name, op) in [
            ("readBytes", read_bytes as PathOp),
            ("readLines", read_lines),
            ("exists", exists),
            ("info", info),
            ("listDirectory", list_directory),
            ("walk", walk),
            ("canonicalize", canonicalize),
            ("remove", remove),
            ("removeTree", remove_tree),
        ] {
            for (path, kind) in [
                ("bad\0path", tags::IO_ERROR_KIND_INVALID_INPUT),
                ("file/child", tags::IO_ERROR_KIND_NOT_DIRECTORY),
            ] {
                assert_eq!(
                    returned_kind(run(ctx, &mut io, op, path).unwrap(), ctx),
                    kind,
                    "{name}: {path:?}"
                );
            }
            if name != "exists" {
                assert_eq!(
                    returned_kind(run(ctx, &mut io, op, "absent").unwrap(), ctx),
                    tags::IO_ERROR_KIND_NOT_FOUND,
                    "{name}"
                );
            }
        }
        for (op, path, kind) in [
            (read_bytes as PathOp, ".", tags::IO_ERROR_KIND_IS_DIRECTORY),
            (read_lines, ".", tags::IO_ERROR_KIND_IS_DIRECTORY),
            (read_lines, "file", tags::IO_ERROR_KIND_INVALID_UTF8),
            (list_directory, "file", tags::IO_ERROR_KIND_NOT_DIRECTORY),
            (walk, "file", tags::IO_ERROR_KIND_NOT_DIRECTORY),
            (remove_tree, "file", tags::IO_ERROR_KIND_NOT_DIRECTORY),
            (create_directory, "file", tags::IO_ERROR_KIND_ALREADY_EXISTS),
            (
                create_directory,
                "file/child",
                tags::IO_ERROR_KIND_NOT_DIRECTORY,
            ),
            (
                create_directory,
                "bad\0path",
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
            (remove, "full", tags::IO_ERROR_KIND_DIRECTORY_NOT_EMPTY),
        ] {
            assert_eq!(
                returned_kind(run(ctx, &mut io, op, path).unwrap(), ctx),
                kind,
                "{path:?}"
            );
        }
        assert!(dir.0.join("file").is_file());
        for append in [false, true] {
            for (path, kind) in [
                ("absent/child", tags::IO_ERROR_KIND_NOT_FOUND),
                (".", tags::IO_ERROR_KIND_IS_DIRECTORY),
                ("file/child", tags::IO_ERROR_KIND_NOT_DIRECTORY),
                ("bad\0path", tags::IO_ERROR_KIND_INVALID_INPUT),
            ] {
                assert_eq!(
                    returned_kind(write(ctx, &mut io, path, b"x", append), ctx),
                    kind,
                    "append={append}, {path:?}"
                );
            }
        }
        for (from, to, kind) in [
            ("absent", "new", tags::IO_ERROR_KIND_NOT_FOUND),
            ("file", "full", tags::IO_ERROR_KIND_IS_DIRECTORY),
            ("file/child", "new", tags::IO_ERROR_KIND_NOT_DIRECTORY),
            ("bad\0path", "new", tags::IO_ERROR_KIND_INVALID_INPUT),
            ("file", "bad\0path", tags::IO_ERROR_KIND_INVALID_INPUT),
        ] {
            assert_eq!(
                returned_kind(move_path(ctx, &mut io, from, to), ctx),
                kind,
                "{from:?} -> {to:?}"
            );
        }
    });
}

// 関門: OS の列挙順や Path の構成要素の比較に依存せず、相対パス全体のバイト順を守る。
#[test]
fn directory_names_and_walk_paths_are_sorted_by_utf8_bytes() {
    let dir = TempDir::new();
    for name in ["é", "z", "a", "B", "a-"] {
        std::fs::write(dir.0.join(name), "").unwrap();
    }
    std::fs::create_dir(dir.0.join("a0")).unwrap();
    std::fs::write(dir.0.join("a0/z"), "").unwrap();
    std::fs::write(dir.0.join("a0-"), "").unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        assert_eq!(
            strings(run(ctx, &mut io, list_directory, ".").unwrap(), ctx),
            ["B", "a", "a-", "a0", "a0-", "z", "é"]
        );
        assert_eq!(
            strings(run(ctx, &mut io, walk, ".").unwrap(), ctx),
            ["B", "a", "a-", "a0", "a0-", "a0/z", "z", "é"]
        );
        std::fs::create_dir(dir.0.join("empty")).unwrap();
        for op in [list_directory as PathOp, walk] {
            assert!(strings(run(ctx, &mut io, op, "empty").unwrap(), ctx).is_empty());
        }
    });
}

// 関門: リンクを辿る退行による二重列挙・外部ファイルの削除と、不正な名前の置換を捕まえる。
#[cfg(unix)]
#[test]
fn links_are_described_without_following_and_invalid_names_fail() {
    use std::os::unix::ffi::OsStringExt;
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    std::fs::create_dir_all(dir.0.join("outside")).unwrap();
    std::fs::write(dir.0.join("outside/keep"), "keep").unwrap();
    std::fs::create_dir(dir.0.join("outside/nested")).unwrap();
    std::fs::write(dir.0.join("outside/nested/leaf"), "leaf").unwrap();
    std::fs::create_dir(dir.0.join("elsewhere")).unwrap();
    std::fs::write(dir.0.join("elsewhere/keep"), "keep").unwrap();
    symlink("../elsewhere", dir.0.join("outside/skip")).unwrap();
    std::fs::create_dir(dir.0.join("tree")).unwrap();
    symlink("../outside", dir.0.join("tree/link")).unwrap();
    symlink("missing", dir.0.join("broken")).unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        // 末尾の / や /. で lstat がリンクを辿っても、先の内容を削除してはならない。
        for path in ["tree/link/", "tree/link/.", "tree/link"] {
            assert_eq!(
                returned_kind(run(ctx, &mut io, remove_tree, path).unwrap(), ctx),
                tags::IO_ERROR_KIND_NOT_DIRECTORY
            );
            assert_eq!(
                std::fs::read_to_string(dir.0.join("outside/keep")).unwrap(),
                "keep"
            );
            assert_eq!(
                std::fs::read_to_string(dir.0.join("outside/nested/leaf")).unwrap(),
                "leaf"
            );
            assert!(
                std::fs::symlink_metadata(dir.0.join("tree/link"))
                    .unwrap()
                    .file_type()
                    .is_symlink()
            );
        }
        for path in [
            "tree/link",
            "tree/link/",
            "tree/link/.",
            "broken",
            "broken/",
            "broken/.",
        ] {
            assert!(matches!(
                ok(
                    run(ctx, &mut io, exists, path).unwrap(),
                    tags::RESULT_OK,
                    ctx
                ),
                Value::Bool(true)
            ));
            let result = ok(run(ctx, &mut io, info, path).unwrap(), tags::RESULT_OK, ctx);
            assert_eq!(
                ctx.fields_header(result),
                Some((FieldsKind::Ctor, tags::RECORD))
            );
            assert!(matches!(
                ctx.field(result, 0),
                Some(Value::Tag(CtorTag(tags::FILE_ENTRY_KIND_SYMBOLIC_LINK)))
            ));
        }
        assert_eq!(
            strings(run(ctx, &mut io, walk, "tree").unwrap(), ctx),
            ["link"]
        );
        // 列挙の根のリンクは辿るが、走査中に見つけた skip は辿らない（設計書 03-07「File」）。
        for path in ["tree/link", "tree/link/", "tree/link/."] {
            assert_eq!(
                strings(run(ctx, &mut io, list_directory, path).unwrap(), ctx),
                ["keep", "nested", "skip"]
            );
            assert_eq!(
                strings(run(ctx, &mut io, walk, path).unwrap(), ctx),
                ["keep", "nested", "nested/leaf", "skip"]
            );
        }
        // .. はリンク先を基準に解決し、途中の . は OS に渡したまま検査する。
        symlink("../outside/nested", dir.0.join("tree/parent-link")).unwrap();
        let parent = ok(
            run(ctx, &mut io, info, "tree/parent-link/../keep").unwrap(),
            tags::RESULT_OK,
            ctx,
        );
        assert!(matches!(ctx.field(parent, 1), Some(Value::Int(4))));
        assert_eq!(
            returned_kind(
                run(ctx, &mut io, info, "outside/keep/./child").unwrap(),
                ctx
            ),
            tags::IO_ERROR_KIND_NOT_DIRECTORY
        );
        unit(run(ctx, &mut io, remove_tree, "tree").unwrap(), ctx);
        assert_eq!(
            std::fs::read_to_string(dir.0.join("outside/keep")).unwrap(),
            "keep"
        );
        for suffix in ["", "/", "/."] {
            for (name, target) in [("remove-link", "outside"), ("remove-broken", "missing")] {
                symlink(target, dir.0.join(name)).unwrap();
                unit(
                    run(ctx, &mut io, remove, &format!("{name}{suffix}")).unwrap(),
                    ctx,
                );
                assert!(std::fs::symlink_metadata(dir.0.join(name)).is_err());
                assert!(dir.0.join("outside/keep").exists());
                assert!(dir.0.join("outside/nested/leaf").exists());
            }
        }
        let name = std::ffi::OsString::from_vec(vec![b'x', 0xff]);
        if let Err(e) = std::fs::write(dir.0.join(&name), "") {
            // 不正な UTF-8 の名前を OS/FS が拒否する環境では、その名前を列挙できない。
            // macOS の APFS は EILSEQ（92。std の分類では種類を持たない）で拒み、
            // サンドボックスの中では PermissionDenied になる。
            const EILSEQ: i32 = if cfg!(target_os = "macos") { 92 } else { 84 };
            assert!(
                matches!(
                    e.kind(),
                    io::ErrorKind::PermissionDenied | io::ErrorKind::InvalidInput
                ) || e.raw_os_error() == Some(EILSEQ)
            );
            eprintln!("invalid UTF-8 filename cases skipped: OS rejects creation: {e}");
            return;
        }
        for op in [list_directory as PathOp, walk] {
            assert_eq!(
                returned_kind(run(ctx, &mut io, op, ".").unwrap(), ctx),
                tags::IO_ERROR_KIND_INVALID_UTF8
            );
        }
        symlink(&name, dir.0.join("invalid-target")).unwrap();
        assert_eq!(
            returned_kind(
                run(ctx, &mut io, canonicalize, "invalid-target").unwrap(),
                ctx
            ),
            tags::IO_ERROR_KIND_INVALID_UTF8
        );
    });
}

// 関門: 調べられない項目を exists=false にする退行と、権限の失敗を Other にする退行。
// 親を記述子で開く際に、従来は要らなかった読み取り権限まで要求する退行も捕まえる。
#[cfg(unix)]
#[test]
fn path_permissions_allow_search_only_parents_and_report_denied_access() {
    use std::os::unix::fs::PermissionsExt;
    struct RestorePermissions<'a> {
        path: &'a Path,
        permissions: std::fs::Permissions,
    }
    impl RestorePermissions<'_> {
        fn restore(&self) -> io::Result<()> {
            std::fs::set_permissions(self.path, self.permissions.clone())
        }
    }
    impl Drop for RestorePermissions<'_> {
        fn drop(&mut self) {
            // 本来のテストの panic を、後片付けの panic で隠さない。
            if let Err(e) = self.restore() {
                eprintln!("failed to restore directory permissions: {e}");
            }
        }
    }
    let dir = TempDir::new();
    let locked = dir.0.join("locked");
    std::fs::create_dir(&locked).unwrap();
    std::fs::write(locked.join("file"), "x").unwrap();
    std::fs::create_dir_all(locked.join("removable/nested")).unwrap();
    std::fs::write(locked.join("removable/nested/leaf"), "leaf").unwrap();
    // TempDir より後に宣言し、巻き戻しでも一時ディレクトリの削除より先に権限を戻す。
    let restore = RestorePermissions {
        path: &locked,
        permissions: std::fs::metadata(&locked).unwrap().permissions(),
    };
    std::fs::set_permissions(&locked, std::fs::Permissions::from_mode(0o000)).unwrap();
    // root や権限の制限を強制しない FS では PermissionDenied を起こせない。
    let probe = std::fs::symlink_metadata(locked.join("file"));
    restore.restore().unwrap();
    if probe.is_ok() {
        eprintln!(
            "PermissionDenied skipped: OS permits traversal despite mode 000 (root or filesystem policy)"
        );
        return;
    }
    assert_eq!(probe.unwrap_err().kind(), io::ErrorKind::PermissionDenied);
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        std::fs::set_permissions(&locked, std::fs::Permissions::from_mode(0o300)).unwrap();
        let removed = run(ctx, &mut io, remove_tree, "locked/removable").unwrap();
        restore.restore().unwrap();
        unit(removed, ctx);
        assert!(!locked.join("removable").exists());
        std::fs::set_permissions(&locked, std::fs::Permissions::from_mode(0o000)).unwrap();
        // 通常は assert より先に戻し、途中の失敗は guard で戻す。
        let mut results: Vec<_> = [
            read_bytes as PathOp,
            read_lines,
            exists,
            info,
            list_directory,
            walk,
            canonicalize,
            remove,
            remove_tree,
            create_directory,
        ]
        .into_iter()
        .map(|op| run(ctx, &mut io, op, "locked/file/child").unwrap())
        .collect();
        results.push(write(ctx, &mut io, "locked/new", b"x", false));
        results.push(write(ctx, &mut io, "locked/new", b"x", true));
        results.push(move_path(ctx, &mut io, "locked/file", "new"));
        restore.restore().unwrap();
        for result in results {
            assert_eq!(
                returned_kind(result, ctx),
                tags::IO_ERROR_KIND_PERMISSION_DENIED
            );
        }
    });
}

// 関門: FS が日時を丸める環境でも、Integer の両端と範囲外の Other を直接確かめる。
// 純粋な補助の関数の直接検査は、オーケストレータの追加指示に従う。
#[test]
fn modification_nanoseconds_preserve_integer_boundaries_and_reject_overflow() {
    use std::time::{Duration, UNIX_EPOCH};
    for nanos in [i64::MIN, -1, 0, 1, i64::MAX] {
        let duration = Duration::from_nanos(nanos.unsigned_abs());
        let time = if nanos < 0 {
            UNIX_EPOCH.checked_sub(duration)
        } else {
            UNIX_EPOCH.checked_add(duration)
        }
        .unwrap();
        assert_eq!(modified_nanoseconds(time).ok(), Some(nanos));
    }
    for time in [
        UNIX_EPOCH
            .checked_sub(Duration::from_nanos(i64::MIN.unsigned_abs() + 1))
            .unwrap(),
        UNIX_EPOCH
            .checked_add(Duration::from_nanos(i64::MAX.unsigned_abs() + 1))
            .unwrap(),
    ] {
        let failure = modified_nanoseconds(time).err().unwrap();
        assert_eq!(failure.kind, tags::IO_ERROR_KIND_OTHER);
        assert_eq!(failure.reason, text::MODIFIED_OUT_OF_RANGE);
    }
}

// 関門: 深い入力が Rust のスタックや深さ分の記述子に依存しない。薄い入力のテストでは届かない。
#[test]
fn deep_walk_and_remove_tree_use_bounded_stack_and_close_directory_handles() {
    let dir = TempDir::new();
    let root = dir.0.join("deep");
    std::fs::create_dir(&root).unwrap();
    let mut path = root.clone();
    let mut depth = 0;
    for _ in 0..1100 {
        path.push("x");
        match std::fs::create_dir(&path) {
            Ok(()) => depth += 1,
            Err(e) => {
                // macOS の ENAMETOOLONG=63、Linux の ENAMETOOLONG=36。許可された環境差だけを飛ばす。
                assert!(
                    matches!(e.raw_os_error(), Some(63 | 36)),
                    "unexpected directory creation failure at {depth}: {e}"
                );
                eprintln!("deep directory limited to {depth} levels by the OS path length limit");
                path.pop();
                break;
            }
        }
    }
    assert!(depth > 100);
    assert!(depth > tree::MAX_HELD_DIRECTORY_FDS);
    // パスの上限に達したときも leaf を置く余地を残す。
    for _ in 0..3 {
        std::fs::remove_dir(&path).unwrap();
        path.pop();
        depth -= 1;
    }
    std::fs::write(path.join("leaf"), "leaf").unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let paths = strings(run(ctx, &mut io, walk, "deep").unwrap(), ctx);
        assert_eq!(paths.len(), depth + 1);
        assert_eq!(paths.first().unwrap(), "x");
        assert_eq!(
            paths.last().unwrap(),
            &format!("{}leaf", "x/".repeat(depth))
        );
        unit(run(ctx, &mut io, remove_tree, "deep").unwrap(), ctx);
    });
    assert!(!root.exists());
}

// 関門: OS 上の実物のディレクトリを判定直後・開いた後・記述子を閉じた後に
// 差し替えても、リンク先や別の inode の木を削除・列挙しない（ADR 0352）。
// 静止したリンクと深い木の既存テストでは競合の窓を捕まえられない。
// 差し込みは依頼で認められた cfg(test) の仕事の引数に限り、大域の状態を加えない。
#[cfg(unix)]
#[test]
fn tree_replacements_do_not_delete_or_enumerate_outside_files() {
    use std::os::unix::fs::symlink;

    for remove in [false, true] {
        for (point, deep, replacement_directory) in [
            (TreeVisit::BeforeOpen, false, false),
            (TreeVisit::BeforeOpen, false, true),
            (TreeVisit::AfterOpen, false, false),
            (TreeVisit::AfterOpen, true, false),
            (TreeVisit::AfterOpen, true, true),
        ] {
            let dir = TempDir::new();
            let root = dir.0.join("tree");
            let outside = dir.0.join("outside");
            let depth = if deep {
                tree::MAX_HELD_DIRECTORY_FDS + 4
            } else {
                1
            };
            let relative = PathBuf::from("x/".repeat(depth));
            std::fs::create_dir_all(root.join(&relative)).unwrap();
            // 差し替えた木にも同じ深さを用意するので、identity の検査を省くと
            // guard を列挙・削除する。単にパスがないために失敗するテストにしない。
            let outside_leaf = outside.join(PathBuf::from("x/".repeat(depth - 1)));
            std::fs::create_dir_all(&outside_leaf).unwrap();
            std::fs::write(root.join(&relative).join("inside"), "inside").unwrap();
            std::fs::write(outside_leaf.join("guard"), "outside").unwrap();
            let mut replaced = false;
            let mut hook = |event: TreeVisit, path: &Path| {
                if !replaced && event == point && path.components().count() == depth {
                    std::fs::rename(root.join("x"), dir.0.join("parked")).unwrap();
                    if replacement_directory {
                        std::fs::rename(&outside, root.join("x")).unwrap();
                    } else {
                        symlink(&outside, root.join("x")).unwrap();
                    }
                    replaced = true;
                }
            };
            let result = if remove {
                remove_tree_job(&root, &mut hook).map(|()| None)
            } else {
                directory_paths(&root, true, "Benitoite.IO.File.walk", &mut hook)
                    .unwrap()
                    .map(Some)
            };
            assert!(replaced, "the directory replacement must actually run");
            let guard = if replacement_directory {
                root.join(&relative).join("guard")
            } else {
                outside_leaf.join("guard")
            };
            assert_eq!(std::fs::read_to_string(guard).unwrap(), "outside");
            match result {
                Ok(Some(paths)) => {
                    assert!(
                        !paths
                            .iter()
                            .any(|path| path.file_name().is_some_and(|name| name == "guard"))
                    );
                    // 開いた記述子からは、元の木を列挙できる。
                    assert!(paths.contains(&relative.join("inside")));
                    assert!(!deep && point == TreeVisit::AfterOpen);
                }
                Ok(None) => assert!(!deep, "reopening a replaced ancestor must fail"),
                Err(failure) => {
                    if replacement_directory {
                        assert_eq!(failure.kind, tags::IO_ERROR_KIND_OTHER);
                        assert_eq!(failure.reason, text::DIRECTORY_CHANGED);
                    }
                }
            }
        }
    }
}

// 関門: Bytes の上限をコピーでも守り、行数を先に検査して巨大な言語のリストを作らない。
#[test]
fn oversized_sparse_bytes_and_too_many_lines_stop_before_building_values() {
    let dir = TempDir::new();
    File::create(dir.0.join("large"))
        .unwrap()
        .set_len(MAX_STRING_BYTES + 1)
        .unwrap();
    let mut lines = File::create(dir.0.join("lines")).unwrap();
    let chunk = vec![b'\n'; 1 << 20];
    for _ in 0..16 {
        lines.write_all(&chunk).unwrap();
    }
    lines.write_all(b"\n").unwrap();
    drop(lines);
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        assert!(matches!(
            run(ctx, &mut io, read_bytes, "large"),
            Err(Stop::Resource(ResourceError::InputTooLarge {
                function: "Benitoite.IO.File.readBytes",
                unit: SizeUnit::Bytes,
                limit: MAX_STRING_BYTES
            }))
        ));
        assert!(matches!(
            run(ctx, &mut io, read_lines, "lines"),
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "Benitoite.IO.File.readLines",
                unit: SizeUnit::Elements,
                limit: MAX_LIST_LEN,
                ..
            }))
        ));
    });
    let program = compile(
        "import Benitoite.Unofficial.IO.File\nfunction main() -> Result[Unit,String] uses File.Read,File.Write\n return File.copy(\"large\",\"target\") |> Result.mapError(_, IOError.message)\nend function\n",
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (mut rt, _) = runtime(&dir.0, mode, &script);
        permit_workers(&mut rt, &script);
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert!(
            matches!(finish(&mut vm, &mut rt), VmStep::Stopped(StopEnd {reason: StopReason::Error(ref info), ..}) if matches!(info.stop, Stop::Resource(ResourceError::InputTooLarge {function: "Benitoite.IO.File.readBytes", ..})))
        );
        assert!(!dir.0.join("target").exists());
        consumed(&script);
    }
}

// 関門: ソースの copy の try による伝播・上書きと、組み込みで作ったレコードの宣言順。
// 単体テストではソースのフィールド関数や両エフェクトを持つ copy の呼び出しを通らない。
#[test]
fn source_copy_and_info_records_work_with_both_io_modes() {
    let dir = TempDir::new();
    std::fs::write(dir.0.join("from"), b"\x00\xff\n").unwrap();
    let time = std::time::UNIX_EPOCH + std::time::Duration::from_secs(1_000_000);
    File::options()
        .write(true)
        .open(dir.0.join("from"))
        .unwrap()
        .set_times(std::fs::FileTimes::new().set_modified(time))
        .unwrap();
    let program = compile(
        r#"import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Time
function main() -> Result[Unit,String] uses File.Read,File.Write
 bind _ <- try File.copy("from", "to") |> Result.mapError(_, IOError.message)
 bind _ <- try File.copy("from", "new-copy") |> Result.mapError(_, IOError.message)
 bind info <- try File.info("to") |> Result.mapError(_, IOError.message)
 bind source <- try File.info("from") |> Result.mapError(_, IOError.message)
 bind bad <- File.copy(".", "bad")
 bind kind <- match bad with
  case Result.Error(e) -> IOError.kind(e)
  case Result.Ok(_) -> IOErrorKind.Other
 end match
 return if File.Info.kind(info) = File.EntryKind.RegularFile and File.Info.size(info) = 3 and Time.Instant.unixNanoseconds(File.Info.modified(source)) = 1000000000000000 and kind = IOErrorKind.IsDirectory then Result.Ok(()) else Result.Error("copy or record mismatch") end if
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        // 大きい古い内容で、writeBytes が末尾を残さず置換することも確かめる。
        std::fs::write(dir.0.join("to"), "older and longer content").unwrap();
        let script = ScheduleHandle::new([], false);
        let (mut rt, _) = runtime(&dir.0, mode, &script);
        permit_workers(&mut rt, &script);
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert_eq!(finish(&mut vm, &mut rt), VmStep::Finished(MainOutcome::Ok));
        assert_eq!(std::fs::read(dir.0.join("to")).unwrap(), b"\x00\xff\n");
        assert_eq!(
            std::fs::read(dir.0.join("new-copy")).unwrap(),
            b"\x00\xff\n"
        );
        assert!(!dir.0.join("bad").exists());
        consumed(&script);
    }
}

// 関門: kind/size/modified の意味と、1970 年より前の時刻の符号と範囲外の Result.Error。
// OS の時刻を操作し、Info の仕事と完了で確かめる。変換の補助だけは直接呼ばない。
#[test]
fn info_reports_file_kind_size_and_signed_modification_nanoseconds() {
    const INFO_KIND: u32 = 0;
    const INFO_SIZE: u32 = 1;
    const INFO_MODIFIED: u32 = 2;
    const INSTANT_NANOSECONDS: u32 = 0;
    let dir = TempDir::new();
    std::fs::write(dir.0.join("file"), b"abc").unwrap();
    std::fs::create_dir(dir.0.join("directory")).unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut io = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let file = File::options().write(true).open(dir.0.join("file")).unwrap();
        for (offset, expected) in [(-1_000_000_000i64, -1_000_000_000i64), (123_000_000_000, 123_000_000_000)] {
            let time = if offset < 0 { std::time::UNIX_EPOCH - std::time::Duration::from_nanos(offset.unsigned_abs()) } else { std::time::UNIX_EPOCH + std::time::Duration::from_nanos(offset.unsigned_abs()) };
            file.set_times(std::fs::FileTimes::new().set_modified(time)).unwrap();
            assert_eq!(file.metadata().unwrap().modified().unwrap(), time);
            let value = ok(run(ctx, &mut io, info, "file").unwrap(), tags::RESULT_OK, ctx);
            assert!(matches!(ctx.field(value, INFO_KIND), Some(Value::Tag(CtorTag(tags::FILE_ENTRY_KIND_REGULAR_FILE)))));
            assert!(matches!(ctx.field(value, INFO_SIZE), Some(Value::Int(3))));
            let instant = ctx.field(value, INFO_MODIFIED).unwrap();
            assert_eq!(ctx.fields_header(instant), Some((FieldsKind::Ctor, tags::RECORD)));
            assert!(matches!(ctx.field(instant, INSTANT_NANOSECONDS), Some(Value::Int(n)) if n == expected));
        }
        let value = ok(run(ctx, &mut io, info, "directory").unwrap(), tags::RESULT_OK, ctx);
        assert!(matches!(ctx.field(value, INFO_KIND), Some(Value::Tag(CtorTag(tags::FILE_ENTRY_KIND_DIRECTORY)))));
        let time = std::time::UNIX_EPOCH + std::time::Duration::from_secs(10_000_000_000);
        if file.set_times(std::fs::FileTimes::new().set_modified(time)).is_ok() && file.metadata().unwrap().modified().unwrap() == time {
            assert_eq!(returned_kind(run(ctx, &mut io, info, "file").unwrap(), ctx), tags::IO_ERROR_KIND_OTHER);
        } else {
            // OS/FS が Integer のナノ秒を超える時刻を保存できない場合は、この場合だけ飛ばす。
            eprintln!("out-of-range modification time skipped: filesystem cannot preserve it");
        }
    });
}
