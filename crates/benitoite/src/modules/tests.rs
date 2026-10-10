//! 読み込みの段の契約の検査（設計書 02-02・02-04、実装プラン F05「受け入れテスト」）。
//! 探索規則・ID の対応・診断の位置と順・循環を公開の読み込みの結果で確かめる。
//! 既存の構文解析のテストでは届かない、複数のソースと外部のファイルシステムの境界を扱う。

// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::base::{BytePos, FileId, SourceKind, Span};
use crate::diag::{DiagCode, Diagnostic, Edit};
use crate::prelude::STDLIB;
use memfs::{MemFs, load_files};

const MAIN: &str = "function main() -> Unit\n  return ()\nend function\n";

fn entry(display: &str) -> EntrySpec {
    EntrySpec {
        path: PathBuf::from("/root/main.bnt"),
        display_name: display.to_owned(),
        root: PathBuf::from("/root"),
    }
}

fn load(fs: &dyn ModuleFs, display: &str) -> LoadOutput {
    load_program(&entry(display), STDLIB, fs, &mut IdGen::new())
}

fn module_path(name: &str) -> ModulePath {
    ModulePath(name.split('.').map(str::to_owned).collect())
}

fn primary_text<'a>(output: &'a LoadOutput, diagnostic: &Diagnostic) -> &'a str {
    let span = diagnostic.primary.as_ref().unwrap().span;
    let source = output.sources.get(span.file).unwrap();
    std::str::from_utf8(&source.text()[span.start.0 as usize..span.end.0 as usize]).unwrap()
}

fn codes(output: &LoadOutput) -> Vec<DiagCode> {
    output
        .diagnostics
        .iter()
        .map(|diagnostic| diagnostic.code.unwrap())
        .collect()
}

fn assert_aligned(output: &LoadOutput) {
    assert_eq!(output.sources.iter().count(), output.modules.modules.len());
    assert_eq!(output.asts.len(), output.modules.modules.len());
    assert_eq!(output.comments.len(), output.asts.len());
    for (index, module) in output.modules.iter().enumerate() {
        assert_eq!(module.id.0 as usize, index);
        assert_eq!(output.asts[index].file, module.id.file());
        assert_eq!(output.modules.get(module.id), Some(module));
        assert_eq!(output.modules.find(&module.name), Some(module));
    }
}

#[test]
fn prelude_order_kinds_and_clock_dependency() {
    let (output, ids) = load_files(&[("main.bnt", MAIN)]);
    assert!(output.diagnostics.is_empty(), "{:#?}", output.diagnostics);
    assert_aligned(&output);
    assert_eq!(output.modules.modules[0].name, ModulePath(vec![]));
    assert_eq!(output.modules.modules[0].kind, ModuleKind::Entry);
    let expected = [
        "Integer",
        "Float",
        "Decimal",
        "RoundingMode",
        "Byte",
        "Character",
        "String",
        "Boolean",
        "List",
        "Map",
        "Set",
        "Option",
        "Result",
        "Pair",
        "Triple",
        "IOError",
        "IOErrorKind",
        "Reference",
        "Lazy",
        "Task",
        "TaskGroup",
        "IO",
        "Assert",
        "Bytes",
        "ByteOrder",
        "NetworkError",
        "NetworkErrorKind",
    ];
    for (index, name) in expected.iter().enumerate() {
        let module = &output.modules.modules[index + 1];
        assert_eq!(module.name.dotted(), format!("Benitoite.{name}"));
        assert_eq!(module.kind, ModuleKind::Prelude);
    }
    let clock = &output.modules.modules[expected.len() + 1];
    assert_eq!(clock.name.dotted(), "Benitoite.IO.Clock");
    assert_eq!(clock.kind, ModuleKind::Stdlib);
    let time = output.modules.modules.last().unwrap();
    assert_eq!(time.name.dotted(), "Benitoite.Time");
    assert_eq!(time.kind, ModuleKind::Stdlib);
    assert!(
        clock
            .imports
            .iter()
            .any(|edge| edge.target == Some(time.id))
    );
    assert_eq!(output.modules.modules.len(), expected.len() + 3);
    assert!(ids.node_count() > output.asts.len() as u32);
    assert!(
        output
            .sources
            .iter()
            .skip(1)
            .all(|(_, source)| source.kind() == SourceKind::Prelude)
    );
}

#[test]
fn every_stdlib_source_and_its_imports_load_without_cycles() {
    // prelude も明示して取り込むので、その import から始まる循環を取り逃がさない（F05）。
    let imports = STDLIB
        .iter()
        .map(|source| format!("import {}\n", find::import_name(source)))
        .collect::<String>();
    let (output, _) = load_files(&[("main.bnt", &(imports + MAIN))]);
    assert!(output.diagnostics.is_empty(), "{:#?}", output.diagnostics);
    assert_eq!(output.modules.modules.len(), STDLIB.len() + 1);
    assert!(
        output
            .modules
            .iter()
            .all(|module| module.imports.iter().all(|edge| edge.target.is_some()))
    );
    assert_aligned(&output);
}

#[test]
fn fifo_order_identity_comments_and_display_names() {
    let source = format!(
        "// entry comment\nimport B\nimport A as Alias\nimport Benitoite.Unofficial.IO.Console\n{MAIN}"
    );
    let fs = MemFs::new(&[
        ("main.bnt", &source),
        ("A.bnt", "import C\nimport Lib.Common\n"),
        ("B.bnt", "import Lib.Common\nimport Lib.Common as Again\n"),
        ("C.bnt", ""),
        ("Lib/Common.bnt", "import Lib.Text\n"),
        ("Lib/Text.bnt", ""),
        ("Unused.bnt", "this must not be parsed"),
    ]);
    let output = load(&fs, "./app/main.bnt");
    let repeated = load(&fs, "./app/main.bnt");
    assert!(output.diagnostics.is_empty(), "{:#?}", output.diagnostics);
    assert_eq!(output.modules, repeated.modules);
    assert_eq!(output.diagnostics, repeated.diagnostics);
    assert_aligned(&output);
    let names: Vec<_> = output
        .modules
        .iter()
        .filter(|module| module.kind != ModuleKind::Prelude)
        .map(|module| module.name.dotted())
        .collect();
    assert_eq!(
        names,
        [
            "",
            "B",
            "A",
            "Benitoite.IO.Console",
            "Benitoite.IO.Clock",
            "Lib.Common",
            "C",
            "Benitoite.Time",
            "Lib.Text"
        ]
    );
    assert_eq!(output.comments[0].len(), 1);
    let common = output.modules.find(&module_path("Lib.Common")).unwrap();
    assert_eq!(
        output.sources.get(common.id.file()).unwrap().name(),
        "./app/Lib/Common.bnt"
    );
    let text = output.modules.find(&module_path("Lib.Text")).unwrap();
    assert_eq!(
        output.sources.get(text.id.file()).unwrap().name(),
        "./app/Lib/Text.bnt"
    );
    let b = output.modules.find(&module_path("B")).unwrap();
    assert_eq!(b.imports[0].target, Some(common.id));
    assert_eq!(b.imports[1].target, Some(common.id));
    let console = output
        .modules
        .find(&module_path("Benitoite.IO.Console"))
        .unwrap();
    assert_eq!(
        output.sources.get(console.id.file()).unwrap().name(),
        "<benitoite>/IO/Console.bnt"
    );
}

#[test]
fn missing_and_case_only_names_do_not_depend_on_fs_case_sensitivity() {
    for insensitive in [false, true] {
        let mut fs = MemFs::new(&[
            ("main.bnt", "import Lib.Text\nimport Lib.Missing\n"),
            ("Lib/text.bnt", ""),
        ]);
        fs.case_insensitive = insensitive;
        // 区別しない設定なら実際に開ける。それでも読み込みの段は一覧で拒む（02-04「モジュールの探し方」）。
        assert_eq!(
            fs.read_file(Path::new("/root/Lib/Text.bnt")).is_ok(),
            insensitive
        );
        let output = load(&fs, "main.bnt");
        assert_eq!(codes(&output), [DiagCode::E0318, DiagCode::E0318]);
        assert_eq!(primary_text(&output, &output.diagnostics[0]), "Lib.Text");
        assert_eq!(
            output.diagnostics[0].notes,
            ["the directory has `text.bnt`, which differs only in upper and lower case"]
        );
        assert_eq!(primary_text(&output, &output.diagnostics[1]), "Lib.Missing");
        assert!(
            output.modules.modules[0]
                .imports
                .iter()
                .all(|edge| edge.target.is_none())
        );
    }
}

#[test]
fn user_similar_names_and_wrong_entry_kinds() {
    let fs = MemFs::new(&[
        (
            "main.bnt",
            "import Lib.Tex\nimport Lib.Dir\nimport Lib.File.Child\n",
        ),
        ("Lib/Text.bnt", ""),
        ("Lib/Texx.bnt", ""),
        ("Lib/Texy.bnt", ""),
        ("Lib/Texz.bnt", ""),
        ("Lib/Dir/Child.bnt", ""),
        ("Lib/File.bnt", ""),
    ]);
    let output = load(&fs, "main.bnt");
    assert_eq!(
        codes(&output),
        [DiagCode::E0318, DiagCode::E0318, DiagCode::E0318]
    );
    assert_eq!(
        output.diagnostics[0].notes,
        ["a similar module exists: Lib.Text, Lib.Texx, Lib.Texy, Lib.Texz"]
    );
    assert!(
        output
            .diagnostics
            .iter()
            .all(|diagnostic| diagnostic.helps.is_empty())
    );
    assert_eq!(
        primary_text(&output, &output.diagnostics[2]),
        "Lib.File.Child"
    );
}

#[test]
fn symbolic_links_enforce_root_and_entry_but_keep_named_module_identity() {
    let fs_files = [
        (
            "main.bnt",
            "import Lib.Out\nimport Main\nimport Lib.A\nimport Lib.B\nimport Linked.C\n",
        ),
        ("/outside/Evil.bnt", ""),
        ("Lib/Shared.bnt", ""),
        ("Lib/C.bnt", ""),
    ];
    let mut fs = MemFs::new(&fs_files);
    fs.add_link("Lib/Out.bnt", "/outside/Evil.bnt");
    fs.add_link("Main.bnt", "main.bnt");
    fs.add_link("Lib/A.bnt", "Shared.bnt");
    fs.add_link("Lib/B.bnt", "Shared.bnt");
    fs.add_link("Linked", "Lib");
    let output = load(&fs, "main.bnt");
    assert_eq!(codes(&output), [DiagCode::E0319, DiagCode::E0320]);
    assert_eq!(primary_text(&output, &output.diagnostics[0]), "Lib.Out");
    assert_eq!(
        output.diagnostics[0].notes,
        ["`Lib/Out.bnt` resolves to `/outside/Evil.bnt`, outside `/root`"]
    );
    assert_eq!(primary_text(&output, &output.diagnostics[1]), "Main");
    assert_eq!(
        output.diagnostics[1].notes,
        ["`Main` is the starting file of this program"]
    );
    let a = output.modules.find(&module_path("Lib.A")).unwrap();
    let b = output.modules.find(&module_path("Lib.B")).unwrap();
    assert_ne!(a.id, b.id);
    assert!(output.modules.find(&module_path("Linked.C")).is_some());
    assert_aligned(&output);
}

#[test]
fn stdlib_spelling_status_and_reserved_root_diagnostics() {
    for (name, key, suggestion) in [
        (
            "Benitoite.Unofficial.IO.Consol",
            "similar",
            "Benitoite.Unofficial.IO.Console",
        ),
        (
            "Benitoite.IO.Console",
            "unofficial",
            "Benitoite.Unofficial.IO.Console",
        ),
        ("Benitoite.Unofficial.Trait", "standard", "Benitoite.Trait"),
    ] {
        let source = format!("import {name} as Renamed\n{MAIN}");
        let (output, _) = load_files(&[("main.bnt", &source)]);
        assert_eq!(codes(&output), [DiagCode::E0321]);
        let diagnostic = &output.diagnostics[0];
        assert_eq!(primary_text(&output, diagnostic), name);
        let span = diagnostic.primary.as_ref().unwrap().span;
        assert_eq!(
            diagnostic.helps[0].edits,
            [Edit {
                span,
                replacement: suggestion.to_owned()
            }]
        );
        let expected = match key {
            "similar" => format!("a similar module exists: {suggestion}"),
            "unofficial" => format!(
                "this module is unofficial in this version and is imported as `{suggestion}`"
            ),
            "standard" => format!(
                "this module is a standard module in this version and is imported as `{suggestion}`"
            ),
            _ => unreachable!(),
        };
        assert_eq!(diagnostic.helps[0].message, expected);
        assert!(diagnostic.notes.is_empty());
    }
    let (output, _) = load_files(&[
        ("main.bnt", "import Benitoite.X\n"),
        ("Benitoite/X.bnt", ""),
    ]);
    assert_eq!(codes(&output), [DiagCode::E0321]);
    assert_eq!(primary_text(&output, &output.diagnostics[0]), "Benitoite.X");
    assert_eq!(
        output.diagnostics[0].notes,
        [
            "names that start with `Benitoite` always refer to the standard library, so `/root/Benitoite` cannot be imported"
        ]
    );
}

#[test]
fn cycles_use_closing_spans_and_do_not_repeat_on_shared_paths() {
    let (output, _) = load_files(&[
        ("main.bnt", "import A\nimport B\nimport C\n"),
        ("A.bnt", "import B\n"),
        ("B.bnt", "import A\n"),
        ("C.bnt", "import C\n"),
    ]);
    assert_eq!(codes(&output), [DiagCode::E0322, DiagCode::E0322]);
    let first = &output.diagnostics[0];
    assert_eq!(first.notes, ["the cycle is A -> B -> A"]);
    let b = output.modules.find(&module_path("B")).unwrap();
    assert_eq!(
        first.primary.as_ref().unwrap().span,
        Span {
            file: b.id.file(),
            start: BytePos(7),
            end: BytePos(8)
        }
    );
    assert_eq!(first.secondary.len(), 1);
    let a = output.modules.find(&module_path("A")).unwrap();
    assert_eq!(
        first.secondary[0].span,
        Span {
            file: a.id.file(),
            start: BytePos(7),
            end: BytePos(8)
        }
    );
    assert_eq!(first.secondary[0].text, "part of the cycle");
    assert_eq!(output.diagnostics[1].notes, ["the cycle is C -> C"]);
    assert_eq!(primary_text(&output, &output.diagnostics[1]), "C");
    assert!(output.diagnostics[1].secondary.is_empty());
}

#[test]
fn dependency_chain_of_2000_modules_uses_no_rust_recursion() {
    let mut fs = MemFs::new(&[("main.bnt", "import M0\n")]);
    for index in 0..2000 {
        let next = (index + 1) % 2000;
        fs.add_file(
            format!("M{index}.bnt"),
            format!("import M{next}\n").into_bytes(),
        );
    }
    let output = load(&fs, "main.bnt");
    assert_eq!(codes(&output), [DiagCode::E0322]);
    assert_eq!(primary_text(&output, &output.diagnostics[0]), "M0");
    assert_eq!(output.diagnostics[0].secondary.len(), 1999);
    assert_aligned(&output);
}

#[test]
fn unreadable_entry_continues_prelude_without_reserving_an_id() {
    let output = load(&MemFs::default(), "missing.bnt");
    assert_eq!(codes(&output), [DiagCode::E0101]);
    assert!(output.diagnostics[0].primary.is_none());
    assert_eq!(output.modules.modules[0].id, ModuleId::of_file(FileId(0)));
    assert_eq!(output.modules.modules[0].name.dotted(), "Benitoite.Integer");
    assert!(
        output
            .modules
            .find(&module_path("Benitoite.IO.Clock"))
            .is_some()
    );
    assert_aligned(&output);
}

#[test]
fn size_limits_reject_sources_without_breaking_ids_or_import_order() {
    for (file_limit, total_limit, reason) in [
        (32, 100, text::SOURCE_TOO_LARGE),
        (64, 48, text::TOTAL_TOO_LARGE),
    ] {
        let mut fs = MemFs::new(&[
            ("main.bnt", "import Big\nimport Small\n"),
            ("Small.bnt", ""),
        ]);
        fs.add_file("Big.bnt", vec![b' '; 33]);
        let output = load::load_with_limits(
            &entry("main.bnt"),
            &[],
            &fs,
            &mut IdGen::new(),
            file_limit,
            total_limit,
        );
        assert_eq!(codes(&output), [DiagCode::E0101]);
        assert_eq!(primary_text(&output, &output.diagnostics[0]), "Big");
        assert_eq!(
            output.diagnostics[0].primary.as_ref().unwrap().text,
            "the module is imported here"
        );
        assert_eq!(output.diagnostics[0].notes, [reason]);
        assert_eq!(output.modules.modules.len(), 2);
        assert_eq!(output.modules.modules[0].imports[0].target, None);
        assert_eq!(
            output.modules.modules[0].imports[1].target,
            Some(ModuleId::of_file(FileId(1)))
        );
        assert_aligned(&output);
    }
}

#[test]
fn syntax_and_lexical_errors_precede_import_errors_and_cycles() {
    let mut fs = MemFs::new(&[
        ("main.bnt", "import A\nimport Missing\n"),
        (
            "A.bnt",
            "import B\nimport Absent\nfunction f() -> Unit\n  bind x <-\nend function\n",
        ),
        ("B.bnt", "import A\n"),
    ]);
    fs.add_file("B.bnt", b"import A\n\xff".to_vec());
    let output = load(&fs, "main.bnt");
    let repeated = load(&fs, "main.bnt");
    assert_eq!(output.diagnostics, repeated.diagnostics);
    assert_eq!(output.modules, repeated.modules);
    assert_eq!(codes(&output).first(), Some(&DiagCode::E0318));
    assert_eq!(codes(&output).last(), Some(&DiagCode::E0322));
    let a = output.modules.find(&module_path("A")).unwrap();
    let a_diagnostics: Vec<_> = output
        .diagnostics
        .iter()
        .filter(|diag| {
            diag.code != Some(DiagCode::E0322)
                && diag.primary.as_ref().unwrap().span.file == a.id.file()
        })
        .collect();
    assert!(a_diagnostics.len() >= 2);
    assert_eq!(a_diagnostics.last().unwrap().code, Some(DiagCode::E0318));
    assert_eq!(
        output.diagnostics[output.diagnostics.len() - 2].code,
        Some(DiagCode::E0102)
    );
    assert_eq!(
        output.diagnostics.last().unwrap().notes,
        ["the cycle is A -> B -> A"]
    );
    assert_aligned(&output);
}

#[test]
fn real_fs_matches_memory_for_files_imports_and_missing_modules() {
    struct Temporary(PathBuf);
    impl Drop for Temporary {
        fn drop(&mut self) {
            let _result = std::fs::remove_dir_all(&self.0);
        }
    }
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../target")
        .join(format!("benitoite-f05-{}", std::process::id()));
    std::fs::create_dir(&path).unwrap();
    let dir = Temporary(path);
    let files = [
        ("main.bnt", "import Lib.Text\nimport Missing\n"),
        ("Lib/Text.bnt", ""),
    ];
    std::fs::create_dir(dir.0.join("Lib")).unwrap();
    for (path, source) in files {
        std::fs::write(dir.0.join(path), source).unwrap();
    }
    let real_entry = EntrySpec {
        path: dir.0.join("main.bnt"),
        display_name: "main.bnt".to_owned(),
        root: dir.0.clone(),
    };
    let real = load_program(&real_entry, STDLIB, &RealFs, &mut IdGen::new());
    let memory = load(&MemFs::new(&files), "main.bnt");
    assert_eq!(real.modules, memory.modules);
    assert_eq!(real.asts, memory.asts);
    assert_eq!(real.diagnostics, memory.diagnostics);
    assert_eq!(codes(&real), [DiagCode::E0318]);
    assert_eq!(primary_text(&real, &real.diagnostics[0]), "Missing");
    std::fs::write(dir.0.join("main.bnt"), MAIN).unwrap();
    let one = load_program(&real_entry, STDLIB, &RealFs, &mut IdGen::new());
    let (expected, _) = load_files(&[("main.bnt", MAIN)]);
    assert_eq!(one.modules, expected.modules);
    assert_eq!(one.diagnostics, expected.diagnostics);

    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("testdata/modules/f05_imports");
    let example = load_program(
        &EntrySpec {
            path: root.join("main.bnt"),
            display_name: "f05_imports/main.bnt".to_owned(),
            root,
        },
        STDLIB,
        &RealFs,
        &mut IdGen::new(),
    );
    assert!(example.diagnostics.is_empty(), "{:#?}", example.diagnostics);
    for name in ["Lib.Text", "Lib.Geometry.Shape", "Benitoite.IO.Console"] {
        assert!(example.modules.find(&module_path(name)).is_some());
    }
}

// ModuleFs だけを置き換えて、OS の失敗を決まった位置で起こす（07-03「テストの設計の原則」）。
struct FailingFs {
    memory: MemFs,
    read: Option<PathBuf>,
    list: Option<PathBuf>,
    canonical: Option<PathBuf>,
}

impl ModuleFs for FailingFs {
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
        if self.read.as_deref() == Some(path) {
            Err(io::Error::from(io::ErrorKind::PermissionDenied))
        } else {
            self.memory.read_file(path)
        }
    }
    fn list_dir(&self, path: &Path) -> io::Result<Vec<DirEntryName>> {
        if self.list.as_deref() == Some(path) {
            Err(io::Error::from(io::ErrorKind::PermissionDenied))
        } else {
            self.memory.list_dir(path)
        }
    }
    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
        if self.canonical.as_deref() == Some(path) {
            Err(io::Error::from(io::ErrorKind::PermissionDenied))
        } else {
            self.memory.canonicalize(path)
        }
    }
}

#[test]
fn io_failures_keep_each_import_and_continue_loading_readable_modules() {
    for (read, list, canonical, expected, count) in [
        (Some("/root/Lib/A.bnt"), None, None, DiagCode::E0101, 3),
        (None, Some("/root/Lib"), None, DiagCode::E0318, 3),
        (None, None, Some("/root"), DiagCode::E0318, 3),
        (None, None, Some("/root/Lib/A.bnt"), DiagCode::E0101, 3),
    ] {
        let fs = FailingFs {
            memory: MemFs::new(&[
                (
                    "main.bnt",
                    "import Lib.A\nimport B\nimport Lib.A as Again\n",
                ),
                ("Lib/A.bnt", ""),
                ("B.bnt", "import Lib.A\n"),
            ]),
            read: read.map(PathBuf::from),
            list: list.map(PathBuf::from),
            canonical: canonical.map(PathBuf::from),
        };
        let output = load(&fs, "main.bnt");
        assert_eq!(codes(&output), vec![expected; count]);
        assert!(output.modules.find(&module_path("Lib.A")).is_none());
        assert!(
            output
                .modules
                .find(&module_path("Benitoite.IO.Clock"))
                .is_some()
        );
        assert_aligned(&output);
        for (index, diagnostic) in output.diagnostics.iter().enumerate() {
            let expected_name = if canonical == Some("/root") && index == 1 {
                "B"
            } else {
                "Lib.A"
            };
            assert_eq!(primary_text(&output, diagnostic), expected_name);
            if expected == DiagCode::E0101 {
                assert_eq!(
                    diagnostic.primary.as_ref().unwrap().text,
                    "the module is imported here"
                );
                assert_eq!(
                    diagnostic.notes,
                    [io::Error::from(io::ErrorKind::PermissionDenied).to_string()]
                );
            }
        }
        assert_eq!(output.modules.modules[0].imports.len(), 3);
    }
}

#[test]
fn exact_size_boundaries_and_embedded_sources_count_toward_total() {
    let fs = MemFs::new(&[("main.bnt", "import A\n"), ("A.bnt", " ")]);
    let output = load::load_with_limits(&entry("main.bnt"), &[], &fs, &mut IdGen::new(), 9, 10);
    assert!(output.diagnostics.is_empty());
    assert_eq!(output.modules.modules.len(), 2);
    let embedded = [StdlibModuleSource {
        path: &["TestPrelude"],
        prelude: true,
        unofficial: false,
        text: " ",
    }];
    let output =
        load::load_with_limits(&entry("main.bnt"), &embedded, &fs, &mut IdGen::new(), 9, 10);
    assert_eq!(codes(&output), [DiagCode::E0101]);
    assert_eq!(primary_text(&output, &output.diagnostics[0]), "A");
    assert_eq!(output.diagnostics[0].notes, [text::TOTAL_TOO_LARGE]);
    assert_eq!(
        output.modules.modules[1].name.dotted(),
        "Benitoite.TestPrelude"
    );
    assert_aligned(&output);
}
