//! 先頭の編集と公開宣言の集計の契約（設計書 06-09「`benitoite package`」）。
// 関門: 範囲外の保持と型の中の uses は、CLI の代表例だけでは落としやすい。
// 実際の解析器と整形器を使い、バイト列と集計結果を独立した期待値に照合する。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::*;
use crate::base::FileId;
fn module(source: &str) -> Module {
    let lexed = lex(FileId(0), source.as_bytes());
    let parsed = parse(
        FileId(0),
        SourceKind::User,
        source.as_bytes(),
        resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut IdGen::new(),
    );
    assert!(lexed.diagnostics.is_empty());
    assert!(parsed.diagnostics.is_empty(), "{:?}", parsed.diagnostics);
    parsed.module
}

// spec: 06-09 `benitoite package`
#[test]
fn header_edit_keeps_body_comments_and_line_endings() {
    let body = "// body\nfunction main() -> Unit\n      () // untouched\nend function\n";
    for prefix in [
        "",
        "\u{feff}",
        "\u{feff}language \"0.0.3\"\n\n",
        "//! module\n\n",
        "//! module\n \n\n",
        "#!/usr/bin/env benitoite\n\n",
        "//! module\n\n// header description\nlanguage \"0.0.3\" // trailing\n\n",
    ] {
        for nl in ["\n", "\r\n"] {
            let source = format!("{prefix}{body}").replace('\n', nl);
            let ast = module(&source);
            let bounds = edit::range(&source, &ast);
            let header = format!(
                "{}\n{}",
                &source[bounds.clone()],
                edit::dependency(
                    "Words",
                    "../text\\kit${x}\"",
                    &format!("sha256:{}", "a".repeat(64)),
                    "File.Read"
                )
            );
            let edited = edit::splice(&source, bounds, &header, FileId(0)).unwrap();
            assert!(edited.ends_with(&body.replace('\n', nl)));
            assert!(edited.contains(&format!("  effects \"File.Read\"{nl}")));
            if prefix.contains("header description") {
                assert!(edited.contains("// header description"));
                assert!(edited.contains("// trailing"));
            }
            if prefix.contains("//!") {
                assert!(edited.starts_with(&format!("//! module{nl}{nl}")));
            }
            let ast = module(&edited);
            let block = ast
                .header
                .iter()
                .find_map(|item| {
                    if let HeaderItem::Dependency(b) = item {
                        Some(b)
                    } else {
                        None
                    }
                })
                .unwrap();
            let path = block.fields.iter().find(|f| f.name.text == "path").unwrap();
            assert_eq!(path.value.value, "../text\\kit${x}\"");
            assert_eq!(
                &edited[path.value.span.start.0 as usize..path.value.span.end.0 as usize],
                edit::quote("../text\\kit${x}\"")
            );
        }
    }
    for source in ["", "//! module\n"] {
        let ast = module(source);
        let edited = edit::splice(
            source,
            edit::range(source, &ast),
            "language \"0.0.3\"\n",
            FileId(0),
        )
        .unwrap();
        assert!(edited.ends_with("language \"0.0.3\"\n"));
        assert_eq!(
            super::super::formatter::format_source(FileId(0), SourceKind::User, edited.as_bytes())
                .unwrap()
                .text,
            edited.as_bytes()
        );
    }
}

// spec: 06-09 `benitoite package`
#[test]
fn update_replaces_quoted_values_and_adds_missing_fields_without_changing_the_body() {
    for hash in ["", "  hash \"bad\" // hash comment\n"] {
        let source = format!(
            "// dependency\ndependency Words\n  path \"../words\" // path comment\n{hash}end dependency // end comment\n\n// body\nfunction main() -> Unit\n  ()\nend function\n"
        );
        let lexed = lex(FileId(0), source.as_bytes());
        let parsed = parse(
            FileId(0),
            SourceKind::User,
            source.as_bytes(),
            resolve_newlines(lexed.tokens),
            lexed.comments,
            &mut IdGen::new(),
        );
        let HeaderItem::Dependency(block) = &parsed.module.header[0] else {
            panic!()
        };
        let bounds = edit::range(&source, &parsed.module);
        let hash = format!("sha256:{}", "b".repeat(64));
        let header = edit::update(&source, &bounds, block, &hash, "File.Write").unwrap();
        let edited = edit::splice(&source, bounds, &header, FileId(0)).unwrap();
        assert!(edited.ends_with("// body\nfunction main() -> Unit\n  ()\nend function\n"));
        assert!(edited.contains("path \"../words\" // path comment"));
        assert!(edited.contains("end dependency // end comment"));
        let ast = module(&edited);
        let HeaderItem::Dependency(block) = &ast.header[0] else {
            panic!()
        };
        assert_eq!(field(block, "hash"), Some(hash.as_str()));
        assert_eq!(field(block, "effects"), Some("File.Write"));
        assert_eq!(
            super::super::formatter::format_source(FileId(0), SourceKind::User, edited.as_bytes())
                .unwrap()
                .text,
            edited.as_bytes()
        );
    }
}

// spec: 06-09 `benitoite package`
#[test]
fn public_contracts_include_nested_function_types_and_trait_methods() {
    let ast = module(
        "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Clock\nimport Benitoite.Unofficial.IO.Random\nimport Benitoite.Unofficial.IO.Process\n\npublic type Timer = function() -> Unit uses Clock.Time\n\npublic data Action[T]\n  Run(T, List[function(String) -> Unit uses Console.Read])\n  Stop\nend data\n\ndata Hidden\n  Run(function() -> Unit uses Process.Environment)\nend data\n\npublic record Generator\n  generate: function() -> Unit uses Random.Generate\nend record\n\npublic function apply[effect E](f: function(Integer) -> Unit uses File.Write, E) -> Unit uses State, IO.All, Console.Write\n  ()\nend function\n\nfunction hidden() -> Unit uses Process.Run\n  ()\nend function\n\npublic trait Source[T]\n  function read(value: T) -> (function() -> Unit uses File.Read)\nend trait\n",
    );
    let mut summary = effects::Summary::default();
    summary.collect(&ast);
    assert_eq!(
        summary.effects,
        BTreeSet::from(
            [
                "File.Write",
                "File.Read",
                "Console.Write",
                "Console.Read",
                "State",
                "IO.All",
                "Clock.Time",
                "Random.Generate"
            ]
            .map(str::to_owned)
        )
    );
}

// パッケージを使う側に見えない契約のエフェクトを報告へ混ぜる退行を捕まえる。
// spec: 06-09 `benitoite package`
#[test]
fn package_visibility_contracts_are_excluded_from_effect_reports() {
    let ast = module(
        "import Benitoite.Unofficial.IO.Process\nimport Benitoite.Unofficial.IO.Console\npublic(package) function internal() -> Unit uses Process.Run\n ()\nend function\npublic function visible() -> Unit uses Console.Write\n ()\nend function\n",
    );
    let mut summary = effects::Summary::default();
    summary.collect(&ast);
    assert_eq!(
        summary.effects,
        BTreeSet::from(["Console.Write".to_owned()])
    );
}

// 関門: 正式な import の名前だけを識別し、誤った名前を組み込みとみなす退行を捕まえる。
// spec: 06-09 `benitoite package`
#[test]
fn effect_imports_must_match_library_names() {
    for (path, effect, expected) in [
        ("Benitoite.Unofficial.IO.Console", "Console.Write", true),
        ("Benitoite.IO.Console", "Console.Write", false),
        (
            "Benitoite.Unofficial.Unofficial.IO.Console",
            "Console.Write",
            false,
        ),
        ("Benitoite.Unofficial.IO", "IO.Console.Write", false),
        ("Benitoite.IO", "IO.Console.Write", false),
        ("Benitoite.IO", "IO.All", true),
    ] {
        let ast = module(&format!(
            "import {path}\npublic function f() -> Unit uses {effect}\n  ()\nend function\n"
        ));
        let mut summary = effects::Summary::default();
        summary.collect(&ast);
        assert_eq!(
            summary.effects.contains(if effect == "IO.All" {
                "IO.All"
            } else {
                "Console.Write"
            }),
            expected,
            "{path}"
        );
    }
    let ast = module(
        "public function f() -> Unit uses Benitoite.Unofficial.IO.Console.Write\n  ()\nend function\n",
    );
    let mut summary = effects::Summary::default();
    summary.collect(&ast);
    assert!(
        summary.effects.is_empty(),
        "import のないモジュールは数えない"
    );
}
