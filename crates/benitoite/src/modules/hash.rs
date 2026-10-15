//! パッケージに含める相対パスと中身からハッシュを計算する
//! （設計書 06-09「中身のハッシュ」）。

use std::collections::BTreeMap;
use std::io;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

use super::ModuleFs;

/// ハッシュに含めるファイルの数と、バイト数の合計の上限。
#[derive(Clone, Copy)]
pub(super) struct HashLimits {
    pub files: usize,
    pub entries: usize,
    pub bytes: usize,
}

impl Default for HashLimits {
    fn default() -> Self {
        Self {
            files: 10_000,
            entries: 100_000,
            bytes: 128 * 1024 * 1024,
        }
    }
}

/// 計算できない理由を分け、読み込みの診断の注記を選べるようにする。
#[derive(Debug)]
pub(crate) enum HashError {
    Symlink { path: String },
    Case { path: String, other: String },
    Name { path: String },
    TooMany { limit: usize },
    TooManyEntries { limit: usize },
    TooLarge { limit: usize },
    Read { path: String, reason: io::Error },
}

/// ファイルシステムの列挙順や根の実パスによらないハッシュを返す。
pub(super) fn package_hash(
    fs: &dyn ModuleFs,
    root: &Path,
    limits: HashLimits,
) -> Result<String, HashError> {
    hash_files(fs, package_files(fs, root, limits)?, limits.bytes)
}

/// ハッシュと公開宣言の集計に共通する、含める相対パスの一覧。
pub(super) fn package_files(
    fs: &dyn ModuleFs,
    root: &Path,
    limits: HashLimits,
) -> Result<BTreeMap<String, PathBuf>, HashError> {
    let root = fs.canonicalize(root).map_err(|reason| HashError::Read {
        path: root.display().to_string(),
        reason,
    })?;
    let mut pending = vec![(root, String::new(), false)];
    let mut files = BTreeMap::new();
    let mut folded = BTreeMap::new();
    let mut visited = 0usize;
    while let Some((dir, relative, in_wasm)) = pending.pop() {
        let mut entries = fs.list_dir(&dir).map_err(|reason| HashError::Read {
            path: if relative.is_empty() {
                ".".to_owned()
            } else {
                relative.clone()
            },
            reason,
        })?;
        entries.sort_by(|a, b| a.name.cmp(&b.name));
        for entry in entries {
            visited = visited
                .checked_add(1)
                .filter(|count| *count <= limits.entries)
                .ok_or(HashError::TooManyEntries {
                    limit: limits.entries,
                })?;
            if entry.name.starts_with('.') {
                continue;
            }
            let path = dir.join(&entry.name);
            let relative_path = if relative.is_empty() {
                entry.name.clone()
            } else {
                format!("{relative}/{}", entry.name)
            };
            // 一覧に含めないファイルも含め、辿るディレクトリの全項目でリンクを拒否する。
            let canonical = fs.canonicalize(&path).map_err(|reason| {
                // 一覧にあった項目が存在しない場合は、壊れたリンクとして扱う。
                if reason.kind() == io::ErrorKind::NotFound {
                    HashError::Symlink {
                        path: relative_path.clone(),
                    }
                } else {
                    HashError::Read {
                        path: relative_path.clone(),
                        reason,
                    }
                }
            })?;
            if canonical != path {
                return Err(HashError::Symlink {
                    path: relative_path,
                });
            }
            if entry.is_dir {
                let child_in_wasm = in_wasm || (relative.is_empty() && entry.name == "wasm");
                if child_in_wasm
                    || entry
                        .name
                        .as_bytes()
                        .first()
                        .is_some_and(u8::is_ascii_uppercase)
                {
                    pending.push((path, relative_path, child_in_wasm));
                }
                continue;
            }
            if !included(&entry.name) {
                continue;
            }
            if relative_path.contains('\n') {
                return Err(HashError::Name {
                    path: relative_path,
                });
            }
            if let Some(other) = folded.insert(relative_path.to_lowercase(), relative_path.clone())
            {
                return Err(HashError::Case {
                    path: relative_path,
                    other,
                });
            }
            if files.len() >= limits.files {
                return Err(HashError::TooMany {
                    limit: limits.files,
                });
            }
            files.insert(relative_path, path);
        }
    }
    Ok(files)
}

fn included(name: &str) -> bool {
    name.ends_with(".bnt")
        || name.ends_with(".wasm")
        || ["LICENSE", "COPYING", "README"].iter().any(|prefix| {
            name.get(..prefix.len())
                .is_some_and(|start| start.eq_ignore_ascii_case(prefix))
        })
}

fn hash_files(
    fs: &dyn ModuleFs,
    files: BTreeMap<String, PathBuf>,
    limit: usize,
) -> Result<String, HashError> {
    let mut summary = Sha256::new();
    let mut total = 0usize;
    // BTreeMap の文字列の順は UTF-8 のバイト列の順である。要約は蓄積せず逐次更新する。
    for (relative, path) in files {
        let bytes = fs.read_file(&path).map_err(|reason| HashError::Read {
            path: relative.clone(),
            reason,
        })?;
        total = total
            .checked_add(bytes.len())
            .filter(|total| *total <= limit)
            .ok_or(HashError::TooLarge { limit })?;
        summary.update(hex(Sha256::digest(&bytes).as_slice()).as_bytes());
        summary.update(b"  ");
        summary.update(relative.as_bytes());
        summary.update(b"\n");
    }
    Ok(format!("sha256:{}", hex(summary.finalize().as_slice())))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[cfg(test)]
mod tests {
    // 固定値は外部の sha256sum、走査と上限は小さな入力で確かめる。
    // 既存の読み込みのテストはパッケージのハッシュの規則を扱わない。
    // テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;
    use crate::base::IdGen;
    use crate::diag::DiagCode;
    use crate::modules::{EntrySpec, RealFs, load_program, memfs::MemFs};

    // 列挙順だけを変える。ハッシュの判定は本物の実装で行う。
    struct ReversedListing<'a>(&'a MemFs);

    impl ModuleFs for ReversedListing<'_> {
        fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
            self.0.read_file(path)
        }
        fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
            self.0.canonicalize(path)
        }
        fn list_dir(&self, dir: &Path) -> io::Result<Vec<crate::modules::DirEntryName>> {
            let mut entries = self.0.list_dir(dir)?;
            entries.reverse();
            Ok(entries)
        }
    }

    const FIXED: &str = "sha256:a1b90227fd78ffd9f1ce24c6969a96511416e6f18571e480713a16e92f7b503f";
    const CONFIG: &str = "language \"0.0.5\"\npackage Textkit\nend package\n";

    fn fixture() -> MemFs {
        let mut fs = MemFs::new(&[
            ("package.bnt", CONFIG),
            ("Z.bnt", "abc\r\n"),
            ("A/Sub.bnt", "abc\n"),
            ("License.md", "MIT\n"),
            ("readme.md", "example\n"),
            ("COPYING", "copy\n"),
        ]);
        fs.add_file("wasm/x.wasm", vec![0, 97, 115, 109, 255]);
        fs
    }

    #[test]
    fn fixed_digest_and_inclusion_rules() {
        // 根で sha256sum A/Sub.bnt COPYING License.md Z.bnt package.bnt readme.md wasm/x.wasm
        // | sha256sum として固定値を求めた。CRLF と非 UTF-8 の中身をそのまま含める。
        let mut fs = fixture();
        for name in [
            ".Hidden.bnt",
            ".git/Module.bnt",
            "wit/x.wit",
            "rust/src/lib.rs",
            "rust/target/x.wasm",
            "target/x.wasm",
            "lower/x.bnt",
            "Z.BNT",
            "wasm/x.WASM",
            "A/lower/x.bnt",
            "A/wasm/x.wasm",
            "wasm/.hidden/x.wasm",
            "A/.Hidden/x.bnt",
            "Other/ignored.txt",
        ] {
            fs.add_file(name, b"excluded".to_vec());
        }
        let root = Path::new("/root");
        #[cfg(unix)]
        {
            use std::os::unix::ffi::OsStringExt;
            fs.add_file(
                std::ffi::OsString::from_vec(vec![255, b'.', b'b', b'n', b't']),
                b"excluded".to_vec(),
            );
        }
        assert_eq!(
            package_hash(&fs, root, HashLimits::default()).unwrap(),
            FIXED
        );
        // 含める各種類の変更と、下位のモジュールの追加を取り逃がさないことも確かめる。
        for name in [
            "Z.bnt",
            "wasm/x.wasm",
            "License.md",
            "readme.md",
            "COPYING",
            "package.bnt",
            "A/Deep/New.bnt",
            "wasm/impl/x.wasm",
            "wasm/components/deep/x.wasm",
        ] {
            let mut changed = fixture();
            changed.add_file(name, b"changed".to_vec());
            assert_ne!(
                package_hash(&changed, root, HashLimits::default()).unwrap(),
                FIXED,
                "{name}"
            );
        }
    }

    #[test]
    fn rejects_colliding_paths_and_newlines() {
        for names in [
            ["A/File.bnt", "A/file.bnt"],
            ["A/File.bnt", "a.bnt"],
            ["Ä.bnt", "ä.bnt"],
        ] {
            let fs = MemFs::new(&[(names[0], ""), (names[1], "")]);
            let result = package_hash(&fs, Path::new("/root"), HashLimits::default());
            if names[1] == "a.bnt" {
                assert!(result.is_ok());
            } else {
                assert!(matches!(result, Err(HashError::Case { .. })));
            }
        }
        // 衝突とリンクが同時にある場合も、報告する原因とパスは列挙順に依存しない。
        let mut fs = MemFs::new(&[("A.bnt", ""), ("a.bnt", "")]);
        fs.add_link("z.bnt", "A.bnt");
        for fs in [&fs as &dyn ModuleFs, &ReversedListing(&fs)] {
            assert!(
                matches!(package_hash(fs, Path::new("/root"), HashLimits::default()),
                Err(HashError::Case { path, other }) if path == "a.bnt" && other == "A.bnt")
            );
        }
        assert!(
            matches!(package_hash(&fs, Path::new("/root/A.bnt"), HashLimits::default()),
            Err(HashError::Read { path, .. }) if path == ".")
        );
        for path in ["bad\n.bnt", "Bad\n/Sub.bnt"] {
            let fs = MemFs::new(&[(path, "")]);
            assert!(matches!(
                package_hash(&fs, Path::new("/root"), HashLimits::default()),
                Err(HashError::Name { .. })
            ));
        }
    }

    #[test]
    fn count_and_total_size_limits_include_the_boundary() {
        let fs = MemFs::new(&[("A.bnt", "ab"), ("B.bnt", "c")]);
        let root = Path::new("/root");
        assert!(
            package_hash(
                &fs,
                root,
                HashLimits {
                    files: 2,
                    bytes: 3,
                    entries: 2
                }
            )
            .is_ok()
        );
        assert!(matches!(
            package_hash(
                &fs,
                root,
                HashLimits {
                    files: 1,
                    bytes: 3,
                    entries: 2
                }
            ),
            Err(HashError::TooMany { limit: 1 })
        ));
        assert!(matches!(
            package_hash(
                &fs,
                root,
                HashLimits {
                    files: 2,
                    bytes: 2,
                    entries: 2
                }
            ),
            Err(HashError::TooLarge { limit: 2 })
        ));
        assert!(matches!(
            package_hash(
                &fs,
                root,
                HashLimits {
                    files: 2,
                    bytes: 0,
                    entries: 2
                }
            ),
            Err(HashError::TooLarge { limit: 0 })
        ));
        // 含めないファイルと隠れた項目も走査の上限に数える。
        let fs = MemFs::new(&[("ignored.txt", ""), (".hidden", "")]);
        assert!(
            package_hash(
                &fs,
                root,
                HashLimits {
                    files: 0,
                    bytes: 0,
                    entries: 2
                }
            )
            .is_ok()
        );
        assert!(matches!(
            package_hash(
                &fs,
                root,
                HashLimits {
                    files: 0,
                    bytes: 0,
                    entries: 1
                }
            ),
            Err(HashError::TooManyEntries { limit: 1 })
        ));
    }

    #[test]
    fn loading_reports_hash_errors_without_reading_package_modules() {
        // 照合の呼ぶ時点と省略の契約は、公開の読み込みから確かめる。
        for with_hash in [false, true] {
            let field = if with_hash {
                format!("hash \"{}\"\n", "sha256:".to_owned() + &"0".repeat(64))
            } else {
                String::new()
            };
            let main = format!(
                "dependency Words\npath \"deps/textkit\"\n{field}end dependency\nimport Words.Z\n"
            );
            let mut fs = MemFs::new(&[
                ("main.bnt", &main),
                ("deps/textkit/package.bnt", CONFIG),
                ("deps/textkit/Z.bnt", ""),
            ]);
            fs.add_link("deps/textkit/ignored.txt", "Z.bnt");
            let entry = EntrySpec {
                path: "/root/main.bnt".into(),
                display_name: "main.bnt".into(),
                root: "/root".into(),
            };
            let output = load_program(&entry, &[], &fs, &mut IdGen::new());
            if with_hash {
                let codes: Vec<_> = output.diagnostics.iter().map(|diag| diag.code).collect();
                assert_eq!(codes, [Some(DiagCode::E0920)]);
                assert!(
                    output
                        .diagnostics
                        .iter()
                        .any(|diag| diag.notes.iter().any(|note| note.contains("symbolic link")))
                );
                assert!(
                    !output
                        .modules
                        .iter()
                        .any(|module| module.kind == crate::modules::ModuleKind::Package)
                );
            } else {
                assert!(output.diagnostics.is_empty());
                assert!(
                    output
                        .modules
                        .iter()
                        .any(|module| module.kind == crate::modules::ModuleKind::Package)
                );
            }
        }
    }

    // 関門: 書式の誤った hash には、計算の失敗や不一致を重ねない。
    // リンクの拒否が働く入力も使い、計算を省く契約を読み込みの結果で確かめる。
    #[test]
    fn malformed_hashes_do_not_trigger_hash_calculation() {
        for linked in [false, true] {
            let mut fs = MemFs::new(&[
                (
                    "main.bnt",
                    "dependency Words\npath \"deps/textkit\"\nhash \"\"\nend dependency\n",
                ),
                ("deps/textkit/package.bnt", CONFIG),
                ("deps/textkit/Z.bnt", ""),
            ]);
            if linked {
                fs.add_link("deps/textkit/ignored.txt", "Z.bnt");
            }
            let output = load_program(
                &EntrySpec {
                    path: "/root/main.bnt".into(),
                    display_name: "main.bnt".into(),
                    root: "/root".into(),
                },
                &[],
                &fs,
                &mut IdGen::new(),
            );
            assert_eq!(
                output
                    .diagnostics
                    .iter()
                    .map(|diag| diag.code)
                    .collect::<Vec<_>>(),
                [Some(DiagCode::E0906)]
            );
        }
    }

    // 関門: 編集中のロックの壊れたリンクがあっても、根と依存の import とハッシュ照合が通る。
    // ハッシュ単体では届かない、RealFs の列挙からモジュールの探索への接続を確かめる。
    #[cfg(unix)]
    #[test]
    fn editor_lock_links_do_not_block_imports_or_hashes() {
        use std::os::unix::fs::symlink;
        let temporary = crate::modules::test_support::Temporary::new();
        let dir = &temporary.0;
        std::fs::write(dir.join("A.bnt"), b"").unwrap();
        std::fs::create_dir(dir.join("Sub")).unwrap();
        symlink("missing", dir.join(".#A.bnt")).unwrap();
        // 編集中のロックが根と依存の双方にあっても、import とハッシュの照合は続けられる。
        std::fs::write(dir.join("Sub/package.bnt"), CONFIG).unwrap();
        std::fs::write(dir.join("Sub/Value.bnt"), b"").unwrap();
        symlink("missing", dir.join("Sub/.#Value.bnt")).unwrap();
        let hash = package_hash(&RealFs, &dir.join("Sub"), HashLimits::default()).unwrap();
        let main = format!(
            "dependency Library\npath \"Sub\"\nhash \"{hash}\"\nend dependency\nimport A\nimport Library.Value\n"
        );
        std::fs::write(dir.join("main.bnt"), main).unwrap();
        let output = load_program(
            &EntrySpec {
                path: dir.join("main.bnt"),
                display_name: "main.bnt".into(),
                root: dir.clone(),
            },
            &[],
            &RealFs,
            &mut IdGen::new(),
        );
        assert!(output.diagnostics.is_empty(), "{:?}", output.diagnostics);
        assert_eq!(
            output.modules.modules[0]
                .imports
                .iter()
                .filter(|link| link.target.is_some())
                .count(),
            2
        );
    }

    #[cfg(unix)]
    #[test]
    fn real_files_reject_links_and_non_regular_files() {
        use std::os::unix::fs::symlink;
        let temporary = crate::modules::test_support::Temporary::new();
        let dir = &temporary.0;
        std::fs::write(dir.join("A.bnt"), b"").unwrap();
        std::fs::create_dir(dir.join("Sub")).unwrap();
        let original = package_hash(&RealFs, dir, HashLimits::default()).unwrap();
        for (name, target) in [
            ("Link.bnt", "A.bnt"),
            ("ignored.txt", "A.bnt"),
            ("Directory", "Sub"),
            ("Broken.bnt", "missing"),
        ] {
            symlink(target, dir.join(name)).unwrap();
            assert!(matches!(
                package_hash(&RealFs, dir, HashLimits::default()),
                Err(HashError::Symlink { .. })
            ));
            std::fs::remove_file(dir.join(name)).unwrap();
        }
        symlink("missing", dir.join(".#A.bnt")).unwrap();
        assert_eq!(
            package_hash(&RealFs, dir, HashLimits::default()).unwrap(),
            original
        );
        assert!(
            std::process::Command::new("mkfifo")
                .arg(dir.join("Pipe.bnt"))
                .status()
                .unwrap()
                .success()
        );
        assert!(matches!(
            package_hash(&RealFs, dir, HashLimits::default()),
            Err(HashError::Read { .. })
        ));
    }
}
