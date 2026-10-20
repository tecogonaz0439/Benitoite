//! 読み込みの段の契約の検査（設計書 02-02「ソースとファイル ID」、
//! 02-04「モジュールの探し方」「依存グラフと循環の検出」）。
//! 探索規則・ID の対応・診断の位置と順・循環を公開の読み込みの結果で確かめる。
//! 既存の構文解析のテストでは届かない、複数のソースと外部のファイルシステムの境界を扱う。

// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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

// spec: 01-03 依存の記述と `package.bnt`
#[test]
fn language_versions_check_the_release_boundary_in_each_header_location() {
    for location in ["entry", "config", "dependency"] {
        for (version, expected) in [
            ("0.0.0", Some(DiagCode::E0908)),
            ("0.0.3", Some(DiagCode::E0908)),
            ("0.0.4", Some(DiagCode::E0908)),
            ("0.0.5", Some(DiagCode::E0908)),
            ("0.0.6", Some(DiagCode::E0908)),
            ("0.0.7", Some(DiagCode::E0908)),
            ("0.0.8", Some(DiagCode::E0908)),
            ("0.0.9", Some(DiagCode::E0908)),
            ("0.0.10", None),
            ("0.0.11", Some(DiagCode::E0907)),
        ] {
            let header = format!("language \"{version}\"\n");
            let entry_source = format!("{header}{MAIN}");
            let dependency_source = format!("{header}package Library\nend package\n");
            let files = match location {
                "entry" => vec![("main.bnt", entry_source.as_str())],
                "config" => vec![("main.bnt", MAIN), ("package.bnt", header.as_str())],
                _ => vec![
                    (
                        "main.bnt",
                        "dependency Library\npath \"deps/library\"\nend dependency\nfunction main() -> Unit\nreturn ()\nend function\n",
                    ),
                    ("deps/library/package.bnt", dependency_source.as_str()),
                ],
            };
            let (output, _) = load_files(&files);
            assert_eq!(
                codes(&output),
                expected.into_iter().collect::<Vec<_>>(),
                "{location}: {version}"
            );
            assert_aligned(&output);
            let Some(code) = expected else {
                continue;
            };
            let diagnostic = &output.diagnostics[0];
            assert_eq!(primary_text(&output, diagnostic), format!("\"{version}\""));
            if code == DiagCode::E0908 {
                assert_eq!(
                    diagnostic.message,
                    format!(
                        "this file was written for Benitoite {version}, and the language changed incompatibly in {}",
                        match version {
                            "0.0.9" => "0.0.10",
                            "0.0.8" => "0.0.9",
                            "0.0.7" => "0.0.8",
                            "0.0.6" => "0.0.7",
                            "0.0.5" => "0.0.6",
                            _ => "0.0.5",
                        }
                    )
                );
                let first = match version {
                    "0.0.9" => 5,
                    "0.0.8" => 4,
                    "0.0.7" => 3,
                    "0.0.6" => 2,
                    "0.0.5" => 1,
                    _ => 0,
                };
                let notes = [
                    "0.0.5: calls with two or more parameters require named arguments; function types and higher-order contracts require parameter names, and function values must match those names in order",
                    "0.0.6: `die` is reserved; IOErrorKind, NetworkErrorKind, Json.ParseError, and Csv.ParseError are @extensible; return values must start on the same physical line as `return`",
                    "0.0.7: Command.environment rejects names starting with DYLD_ or LD_ (ASCII case-insensitive), including build-tool variables such as LD_RUN_PATH",
                    "0.0.8: Character ranges covering all Unicode scalar values are exhaustive; a following catch-all is unreachable",
                    "0.0.9: direct Regex.compile calls reject invalid constant sources with E0457 or E0458; direct Scope checks reject invalid known arguments with E0459 through E0462",
                    "0.0.10: `block` is reserved; Integer ranges covering the full signed 64-bit domain are exhaustive and a following catch-all is unreachable",
                ];
                let helps = [
                    "see the 0.0.5 section of CHANGELOG.md for named arguments and named function types",
                    "rename user-defined names spelled `die`; outside the defining package, add an unguarded `case other` or `case _` to cover future @extensible values in matches, and use a variable or `_` instead of destructuring them in bindings; record `..` covers only declared fields, while construction, updates, and getters keep their declared field contracts; start each return value on the same physical line as `return` (the value may continue across lines after it starts); use `try value or return`, `try value or die`, or `try value or die(message)` to make the failure action explicit; bare `try value` still returns failure from the innermost function or lambda; see CHANGELOG.md for migration details",
                    "review explicit settings of DYLD_ and LD_ variables, including LD_RUN_PATH used by build tools; run and runAttached return IOErrorKind.InvalidInput before starting a child; inherited variables are unchanged; update the language declaration to the current version after reviewing the script, update dependency hashes, and see CHANGELOG.md for migration details",
                    "review full-domain Character matches and remove unreachable branches or move their work into reachable branches; keep catch-alls for guarded Character ranges and Integer ranges; update E0601 character witness snapshots, language declarations to the current version, and dependency hashes; see the 0.0.8 section of CHANGELOG.md",
                    "to test Result.Error, pass the pattern to a normal function whose parameters are used by Regex.compile or Scope checks; review constant patterns, language declarations and dependency hashes; see the 0.0.9 section of CHANGELOG.md",
                    "rename identifiers spelled `block`; review full-domain Integer matches and remove unreachable branches or correct their intervals; keep catch-alls for guarded or incomplete ranges; review Log and SourceLocation prelude names, explicit Log permissions, width-specific numeric warnings under --deny-warnings, and derive version 3 records; update language declarations to the current version and dependency hashes after reviewing the source; see the 0.0.10 section of CHANGELOG.md",
                ];
                assert_eq!(diagnostic.notes, notes[first..]);
                assert_eq!(diagnostic.helps.len(), helps.len() - first);
                for (help, expected) in diagnostic.helps.iter().zip(&helps[first..]) {
                    assert_eq!(help.message, *expected);
                    assert!(help.edits.is_empty());
                }
            } else {
                assert_eq!(
                    diagnostic.message,
                    "this file needs Benitoite 0.0.11 or later, but this is Benitoite 0.0.10"
                );
                assert!(diagnostic.notes.is_empty());
                assert!(diagnostic.helps.is_empty());
            }
        }
    }
}

// spec: 01-03 依存の記述と `package.bnt`
#[test]
fn dependency_without_path_reports_only_the_missing_field() {
    let source = format!(
        "dependency Fuzzy\n  hash \"sha256:{}\"\nend dependency\n{MAIN}",
        "00".repeat(32)
    );
    let (output, _) = load_files(&[("main.bnt", &source)]);
    assert_eq!(codes(&output), vec![DiagCode::E0904]);
}

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
        "Integer8",
        "Integer16",
        "Integer32",
        "Integer64",
        "UnsignedInteger8",
        "UnsignedInteger16",
        "UnsignedInteger32",
        "UnsignedInteger64",
        "UnsignedInteger",
        "Float32",
        "Float64",
        "SourceLocation",
        "Log",
    ];
    for (index, name) in expected.iter().enumerate() {
        let module = &output.modules.modules[index + 1];
        assert_eq!(module.name.dotted(), format!("Benitoite.{name}"));
        assert_eq!(module.kind, ModuleKind::Prelude);
    }
    assert!(
        output
            .modules
            .find(&module_path("Benitoite.Trait"))
            .is_none()
    );
    for name in ["IOError", "NetworkError"] {
        let module = output
            .modules
            .find(&module_path(&format!("Benitoite.{name}")))
            .unwrap();
        assert!(module.imports.is_empty());
        assert!(module.internal_dependencies.is_empty());
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
    let console = &output.modules.modules[expected.len() + 2];
    assert_eq!(console.name.dotted(), "Benitoite.IO.Console");
    assert_eq!(console.kind, ModuleKind::Stdlib);
    let log = output.modules.find(&module_path("Benitoite.Log")).unwrap();
    assert!(
        log.imports
            .iter()
            .any(|edge| edge.target == Some(console.id))
    );
    assert_eq!(output.modules.modules.len(), expected.len() + 4);
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
    // prelude も明示して取り込むので、その import から始まる循環を取り逃がさない。
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
            "similar" => format!("a similar module exists: `{suggestion}`"),
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
fn stdlib_last_segment_candidates_precede_distance_and_require_uniqueness() {
    // 距離だけでは見つからないモジュールと、最後の段が曖昧な場合の契約を守る。
    let embedded = [
        StdlibModuleSource {
            path: &["IO", "Console"],
            prelude: false,
            unofficial: true,
            text: "",
        },
        StdlibModuleSource {
            path: &["Other", "Console"],
            prelude: false,
            unofficial: false,
            text: "",
        },
    ];
    for sources in [&embedded[..1], &embedded[..]] {
        let fs = MemFs::new(&[("main.bnt", "import Benitoite.CONSOLE as C")]);
        let output = load_program(&entry("main.bnt"), sources, &fs, &mut IdGen::new());
        assert_eq!(codes(&output), [DiagCode::E0321]);
        let d = &output.diagnostics[0];
        assert!(d.notes.is_empty());
        assert_eq!(d.helps.len(), 1);
        if sources.len() == 1 {
            assert_eq!(d.helps[0].message, "use `Benitoite.Unofficial.IO.Console`");
            assert_eq!(
                d.helps[0].edits[0].replacement,
                "Benitoite.Unofficial.IO.Console"
            );
        } else {
            assert_eq!(
                d.helps[0].message,
                "use `Benitoite.Other.Console`, `Benitoite.Unofficial.IO.Console`"
            );
            assert!(d.helps[0].edits.is_empty());
        }
    }
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
    let dir = super::test_support::Temporary::new();
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

// 設定ファイルにも同じ上限を適用し、読めなかったときには番号を振らない。
#[test]
fn settings_sources_count_toward_source_limits() {
    let fs = MemFs::new(&[("main.bnt", " "), ("package.bnt", "  ")]);
    for (file_limit, total_limit, reason) in [
        (2, 3, None),
        (1, 3, Some(text::SOURCE_TOO_LARGE)),
        (2, 2, Some(text::TOTAL_TOO_LARGE)),
    ] {
        let output = load::load_with_limits(
            &entry("main.bnt"),
            &[],
            &fs,
            &mut IdGen::new(),
            file_limit,
            total_limit,
        );
        assert_aligned(&output);
        if let Some(reason) = reason {
            assert_eq!(codes(&output), [DiagCode::E0101]);
            assert!(output.diagnostics[0].primary.is_none());
            assert_eq!(output.diagnostics[0].notes, [reason]);
            assert_eq!(output.asts.len(), 1);
        } else {
            assert!(output.diagnostics.is_empty());
            assert_eq!(output.asts.len(), 2);
        }
    }
}

#[test]
fn root_settings_do_not_come_from_parent_directories() {
    let fs = MemFs::new(&[
        ("project/main.bnt", MAIN),
        ("package.bnt", "language \"99.0.0\"\n"),
    ]);
    let entry = EntrySpec {
        path: "/root/project/main.bnt".into(),
        display_name: "project/main.bnt".into(),
        root: "/root/project".into(),
    };
    let output = load_program(&entry, STDLIB, &fs, &mut IdGen::new());
    assert!(output.diagnostics.is_empty(), "{:?}", output.diagnostics);
    assert_aligned(&output);
    assert!(
        !output
            .modules
            .iter()
            .any(|module| module.kind == ModuleKind::Config)
    );
}

// 設定ファイルが入ってもソースとモジュールの番号・読み込みの順を保つ契約を守る。
#[test]
fn config_is_a_module_between_entry_and_prelude_and_uses_exact_name() {
    for config_name in ["package.bnt", "Package.bnt"] {
        let (output, _) = load_files(&[("main.bnt", MAIN), (config_name, "language \"0.0.10\"\n")]);
        assert!(output.diagnostics.is_empty(), "{:?}", output.diagnostics);
        assert_aligned(&output);
        if config_name == "package.bnt" {
            assert_eq!(output.modules.modules[1].kind, ModuleKind::Config);
            assert_eq!(
                output.modules.modules[1].name,
                ModulePath(vec!["package.bnt".into()])
            );
            assert_eq!(output.sources.get(FileId(1)).unwrap().name(), "package.bnt");
            assert!(output.asts[1].decls.is_empty());
            assert_eq!(output.modules.modules[2].kind, ModuleKind::Prelude);
        } else {
            assert_eq!(output.modules.modules[1].kind, ModuleKind::Prelude);
        }
    }
}

#[test]
fn config_cannot_be_a_starting_file() {
    let fs = MemFs::new(&[("/root/package.bnt", "language \"0.0.10\"\n")]);
    let entry = EntrySpec {
        path: "/root/package.bnt".into(),
        display_name: "package.bnt".into(),
        root: "/root".into(),
    };
    let output = load_program(&entry, STDLIB, &fs, &mut IdGen::new());
    assert_eq!(codes(&output), vec![DiagCode::E0913]);
    assert!(output.diagnostics[0].primary.is_none());
    assert!(output.sources.iter().next().is_none());
}

// 関門: 設定を import の有無によらず先に読み、異なる依存のモジュールと ID の対応を守る。
// ゴールデンの出力からは読む順とソース表の対応を観察できない。
#[test]
fn dependency_configs_precede_prelude_and_imported_modules() {
    let fs = MemFs::new(&[
        ("main.bnt", "import One.Slug\nimport Two.Slug as Second\n"),
        (
            "package.bnt",
            "dependency One\n  path \"/library\"\nend dependency\ndependency Two\n  path \"../second\"\nend dependency\ndependency Unused\n  path \"/unused\"\nend dependency\n",
        ),
        (
            "/library/package.bnt",
            "language \"0.0.10\"\npackage Textkit\nend package\n",
        ),
        ("/library/Slug.bnt", "import Internal.Helper\n"),
        ("/library/Internal/Helper.bnt", ""),
        (
            "/second/package.bnt",
            "language \"0.0.10\"\npackage Textkit\nend package\n",
        ),
        ("/second/Slug.bnt", "import Internal.Helper\n"),
        ("/second/Internal/Helper.bnt", ""),
        (
            "/unused/package.bnt",
            "language \"0.0.10\"\npackage Unused\nend package\n",
        ),
        ("/unused/Unread.bnt", "this is deliberately not a module"),
    ]);
    let output = load(&fs, "project/main.bnt");
    assert!(output.diagnostics.is_empty(), "{:#?}", output.diagnostics);
    assert_aligned(&output);
    let names: Vec<_> = output
        .modules
        .iter()
        .take(5)
        .map(|module| module.name.dotted())
        .collect();
    assert_eq!(
        names,
        [
            "",
            "package.bnt",
            "One.package.bnt",
            "Two.package.bnt",
            "Unused.package.bnt"
        ]
    );
    for alias in ["One", "Two"] {
        assert_eq!(
            output
                .modules
                .find(&ModulePath(vec![alias.into(), "package.bnt".into()]))
                .unwrap()
                .kind,
            ModuleKind::PackageConfig
        );
        let slug = output
            .modules
            .find(&module_path(&format!("{alias}.Slug")))
            .unwrap();
        let helper = output
            .modules
            .find(&module_path(&format!("{alias}.Internal.Helper")))
            .unwrap();
        assert_eq!(slug.kind, ModuleKind::Package);
        assert_eq!(slug.imports[0].target, Some(helper.id));
    }
    assert_ne!(
        output.modules.find(&module_path("One.Slug")).unwrap().id,
        output.modules.find(&module_path("Two.Slug")).unwrap().id
    );
    assert!(output.modules.find(&module_path("Unused.Unread")).is_none());
    assert_eq!(
        output.sources.get(FileId(3)).unwrap().name(),
        "project/../second/package.bnt"
    );
}

// 関門: パッケージの根を境界とするリンクの検査と入口の取り込み禁止を守る。
// ファイルシステムのリンクだけを差し替え、本物の読み込みの段の診断を調べる。
#[test]
fn package_imports_keep_their_canonical_root_and_reject_the_entry() {
    // 入口自身は根のリンクから拒否する。依存から入口を指すリンクは根の境界で先に拒否する。
    for (package_link, target, expected) in [
        (true, "/outside/Target.bnt", DiagCode::E0319),
        (true, "/root/main.bnt", DiagCode::E0319),
        (false, "/root/main.bnt", DiagCode::E0320),
    ] {
        let main = if package_link {
            "dependency Lib\n  path \"deps/library\"\nend dependency\nimport Lib.Linked\n"
        } else {
            "import Linked\n"
        };
        let mut fs = MemFs::new(&[
            ("main.bnt", main),
            (
                "deps/library/package.bnt",
                "language \"0.0.10\"\npackage Library\nend package\n",
            ),
            ("/outside/Target.bnt", ""),
        ]);
        fs.add_link(
            if package_link {
                "deps/library/Linked.bnt"
            } else {
                "Linked.bnt"
            },
            target,
        );
        let output = load(&fs, "main.bnt");
        assert_eq!(codes(&output), vec![expected]);
        assert_eq!(
            primary_text(&output, &output.diagnostics[0]),
            if package_link { "Lib.Linked" } else { "Linked" }
        );
        if package_link {
            assert!(output.diagnostics[0].message.contains("package root"));
        }
    }
}

// 関門: 根の外の依存と根のリンクが同じファイルを指すとき、依存として取り込む。
// 根として読む場合の境界検査を先に当てる退行を、読み込みの公開の結果で捕まえる。
#[test]
fn root_link_to_the_dependency_imports_the_package() {
    let mut fs = MemFs::new(&[
        (
            "main.bnt",
            "dependency Textkit\n  path \"../library\"\nend dependency\nimport Textkit.Slug\n",
        ),
        (
            "/library/package.bnt",
            "language \"0.0.10\"\npackage Textkit\nend package\n",
        ),
        ("/library/Slug.bnt", ""),
    ]);
    fs.add_link("Textkit", "/library");
    let output = load(&fs, "main.bnt");
    assert!(output.diagnostics.is_empty(), "{:#?}", output.diagnostics);
    assert_eq!(
        output
            .modules
            .find(&module_path("Textkit.Slug"))
            .unwrap()
            .kind,
        ModuleKind::Package
    );
    assert_aligned(&output);
}

// 関門: 正規化した依存の根の重なりを、import の有無によらず拒否する。
// 同じファイルが別名ごとに読まれる退行を、読み込みの境界で捕まえる。
// spec: 01-03 依存のパッケージの取り込み
#[test]
fn overlapping_dependency_roots_are_rejected_before_imports() {
    for (first, second) in [
        ("/libs", "/libs"),
        ("/libs", "/libs/Nested"),
        ("/libs/Nested", "/libs"),
        ("/libs", "Linked"),
    ] {
        let main = format!(
            "dependency One\npath \"{first}\"\nend dependency\ndependency Two\npath \"{second}\"\nend dependency\nimport Two.Value\n"
        );
        let mut fs = MemFs::new(&[
            ("main.bnt", &main),
            (
                "/libs/package.bnt",
                "language \"0.0.10\"\npackage Libs\nend package\n",
            ),
            (
                "/libs/Nested/package.bnt",
                "language \"0.0.10\"\npackage Nested\nend package\n",
            ),
            ("/libs/Value.bnt", ""),
            ("/libs/Nested/Value.bnt", ""),
        ]);
        fs.add_link("Linked", "/libs");
        let output = load(&fs, "main.bnt");
        assert_eq!(codes(&output), [DiagCode::E0922], "{main}");
        assert_eq!(
            primary_text(&output, &output.diagnostics[0]),
            format!("\"{second}\"")
        );
        assert_eq!(output.diagnostics[0].secondary.len(), 1);
        assert!(output.modules.find(&module_path("Two.Value")).is_none());
        assert_aligned(&output);
    }
}

// 関門: 根のリンクを通す診断でも、import に書ける候補にだけ編集を付ける。
// パスの構文の検査では届かない、正規化後の名前の提案を読み込みで確かめる。
// spec: 01-03 依存のパッケージの取り込み
#[test]
fn dependency_import_edits_only_use_valid_module_names() {
    for (tail, expected) in [
        ("Value.bnt", Some("Tk.Value")),
        ("impl/x.bnt", None),
        ("Bad-Name.bnt", None),
    ] {
        let mut fs = MemFs::new(&[
            (
                "main.bnt",
                "dependency Tk\npath \"/library\"\nend dependency\nimport Linked as Local\n",
            ),
            (
                "/library/package.bnt",
                "language \"0.0.10\"\npackage Library\nend package\n",
            ),
        ]);
        fs.add_file(format!("/library/{tail}"), vec![]);
        fs.add_link("Linked.bnt", format!("/library/{tail}"));
        let output = load(&fs, "main.bnt");
        assert_eq!(codes(&output), [DiagCode::E0921]);
        let diag = &output.diagnostics[0];
        assert_eq!(diag.notes, ["package: `Library`"]);
        let edits: Vec<_> = diag.helps.iter().flat_map(|help| &help.edits).collect();
        assert_eq!(diag.helps.len(), usize::from(expected.is_some()));
        assert_eq!(edits.len(), usize::from(expected.is_some()));
        if let Some(expected) = expected {
            assert_eq!(edits[0].replacement, expected);
            assert_eq!(edits[0].span, diag.primary.as_ref().unwrap().span);
            assert_eq!(primary_text(&output, diag), "Linked");
        }
    }
}

// 関門: 二か所の依存の記述は E0911 だけで報告し、片方を消すと消える E0922 を重ねない。
// 二つの別名を使うため、別名の重複を飛ばす処理では通らない。
// spec: 01-03 依存の記述と `package.bnt`
#[test]
fn duplicate_dependency_locations_do_not_also_report_root_overlap() {
    let fs = MemFs::new(&[
        (
            "main.bnt",
            "dependency One\npath \"deps/lib\"\nend dependency\nimport One.Value\n",
        ),
        (
            "package.bnt",
            "dependency Two\npath \"deps/lib\"\nend dependency\n",
        ),
        (
            "deps/lib/package.bnt",
            "language \"0.0.10\"\npackage Library\nend package\n",
        ),
        ("deps/lib/Value.bnt", ""),
    ]);
    let output = load(&fs, "main.bnt");
    assert_eq!(codes(&output), [DiagCode::E0911]);
    assert!(output.modules.find(&module_path("One.Value")).is_some());
    assert_aligned(&output);
}

#[test]
fn die_internal_dependencies_keep_source_spans_and_participate_in_cycles() {
    use crate::syntax::{lexer, newline, parser::parse};
    // prelude から Trait への辺はないため、明示 import で検査対象を読む。
    // Trait の AST から抽出した内部依存の自己循環も落とさない。
    let source = format!("import Benitoite.Trait\n{MAIN}");
    let (mut load, mut ids) = load_files(&[("main.bnt", &source)]);
    let trait_module = load
        .modules
        .iter()
        .find(|m| m.name.dotted() == "Benitoite.Trait")
        .unwrap()
        .id;
    let source =
        "function hidden() -> Integer\n try Option.Some(1) or die(\"context\")\nend function\n";
    let file = FileId(trait_module.0);
    let lexed = lexer::lex(file, source.as_bytes());
    let parsed = parse(
        file,
        SourceKind::User,
        source.as_bytes(),
        newline::resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut ids,
    );
    assert!(parsed.diagnostics.is_empty(), "{:?}", parsed.diagnostics);
    let requests = super::internal::requested(&parsed.module);
    assert_eq!(
        requests
            .iter()
            .map(|(path, _)| path.dotted())
            .collect::<Vec<_>>(),
        ["Benitoite.Trait", "Benitoite.IO.Process"]
    );
    let try_start = u32::try_from(source.find("try").unwrap()).unwrap();
    assert!(
        requests
            .iter()
            .all(|(_, span)| span.file == file && span.start == BytePos(try_start))
    );
    let span = requests[0].1;
    load.modules.modules[trait_module.0 as usize]
        .internal_dependencies
        .push(InternalDependency {
            target: trait_module,
            span,
        });
    let diags = super::cycle::detect(&load.modules, &load.asts);
    assert_eq!(diags.len(), 1, "{diags:?}");
    assert_eq!(diags[0].code, Some(DiagCode::E0322));
    assert_eq!(diags[0].primary.as_ref().unwrap().span, span);
    assert!(
        diags[0]
            .notes
            .iter()
            .any(|n| n.contains("Benitoite.Trait -> Benitoite.Trait"))
    );
    assert!(
        load.asts
            .iter()
            .all(|ast| ast.imports.iter().all(|i| i.span != span))
    );
}
