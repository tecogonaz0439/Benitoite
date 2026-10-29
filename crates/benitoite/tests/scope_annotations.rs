//! 範囲注釈の通常の解析・名前解決・型検査の接続（設計書 01-02、01-07、02-04）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

use benitoite::{
    diag::Diagnostic,
    pipeline::{self, CheckOptions, CheckedProgram},
    syntax::ast::{FnDecl, Item},
    types::{Scheme, Ty, TyNames},
};
use std::collections::BTreeSet;

const IMPORTS: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.Failure\n";

fn check(source: &str) -> pipeline::CheckResult {
    pipeline::check_text(
        "scope-annotations.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    )
}

fn errors(result: &pipeline::CheckResult) -> Vec<&Diagnostic> {
    result.diagnostics.iter().filter(|d| d.is_error()).collect()
}

fn signature<'a>(program: &'a CheckedProgram, name: &str) -> &'a Scheme {
    let (id, _) = program
        .resolved
        .bindings
        .iter()
        .find(|(_, b)| b.name == name)
        .unwrap();
    program.types.decl_types.get(id).unwrap()
}

fn function<'a>(program: &'a CheckedProgram, name: &str) -> &'a FnDecl {
    program
        .asts
        .iter()
        .flat_map(|m| &m.decls)
        .find_map(|d| {
            if let Item::Fn(f) = &d.item
                && f.name.text == name
            {
                Some(f.as_ref())
            } else {
                None
            }
        })
        .unwrap()
}

fn slice(source: &str, span: benitoite::base::Span) -> &str {
    &source[usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()]
}

// 関門: 通常の構文から原子列への展開・標準束縛の認定・正規化・元位置をまとめて守る。
// 代数だけの既存テストでは、解決時に範囲をTopへ戻す退行や、略記の要素位置の消失を捕まえない。
// 公開のcheck入口を使い、検査専用の差し込み口は設けない。
#[test]
fn scope_shorthand_preserves_atoms_and_source_elements() {
    let source = format!(
        "{IMPORTS}function sample() -> Unit uses File.Write[\"/data/a/**\", \"/data/a/input\",], File.Write, Http.Connect[\"A.Example\", 0x1_bb, \"192.168.1.0/24\", 80..81], Failure.Fail[String]\n ()\nend function\n"
    );
    let checked = check(&source);
    assert!(errors(&checked).is_empty(), "{:?}", checked.diagnostics);
    let program = checked.program.unwrap();
    let scheme = signature(&program, "sample");
    let suffixes = scheme
        .effects
        .names
        .iter()
        .map(|n| n.range().unwrap().suffix())
        .collect::<BTreeSet<_>>();
    assert_eq!(
        suffixes,
        [
            "",
            "[\"/data/a/**\"]",
            "[\"/data/a/input\"]",
            "[\"a.example\", 443]",
            "[\"192.168.1.0/24\", 80..81]",
        ]
        .into_iter()
        .map(str::to_owned)
        .collect()
    );
    assert_eq!(scheme.effects.names.len(), 5);
    assert_eq!(scheme.effects.failures.len(), 1);
    let uses = function(&program, "sample").uses.as_ref().unwrap();
    assert_eq!(uses.effects.len(), 6);
    let scoped = uses
        .effects
        .iter()
        .filter_map(|e| e.scope.as_ref())
        .collect::<Vec<_>>();
    assert_eq!(scoped.len(), 4);
    assert_eq!(
        scoped
            .iter()
            .map(|s| slice(&source, s.element_span()))
            .collect::<Vec<_>>(),
        [
            "\"/data/a/**\"",
            "\"/data/a/input\"",
            "\"A.Example\", 0x1_bb",
            "\"192.168.1.0/24\", 80..81"
        ]
    );
    assert_eq!(scoped[0].span, scoped[1].span);
    assert_eq!(scoped[2].span, scoped[3].span);
    assert_eq!(scoped[0].items.len(), 2);
    assert_eq!(scoped[2].items.len(), 4);
    assert_eq!(
        slice(&source, scoped[0].span),
        "[\"/data/a/**\", \"/data/a/input\",]"
    );
    let shown = scheme.fn_ty().show(&TyNames {
        bindings: &program.resolved.bindings,
        adts: &program.types.adts,
        effects: &program.types.effects,
        type_params: &[],
        effect_params: &[],
    });
    for expected in suffixes.iter().filter(|s| !s.is_empty()) {
        assert!(shown.contains(expected), "{shown}");
    }
}

// 関門: 型引数と範囲引数を区別した後も、Failの型代入と関数型の原子を保存する。
// 既存の型APIのテストはソースの注釈を通らず、parser/resolveからの取り落としを捕まえない。
#[test]
fn scoped_function_types_and_failure_arguments_survive_instantiation() {
    let source = format!(
        "{IMPORTS}function identity[T](value: T) -> T uses Failure.Fail[T]\n return value\nend function\nfunction relay[T](body: function(value: T) -> T uses File.Read[\"/data/**\"], value: T) -> T uses File.Read[\"/data/**\"]\n return body(value: value)\nend function\nfunction target(value: Integer) -> Integer uses File.Read[\"/data/**\"]\n return value\nend function\nfunction sample() -> Integer uses File.Read[\"/data/**\"], Failure.Fail[Integer]\n return relay(body: target, value: identity(value: 7))\nend function\n"
    );
    let checked = check(&source);
    assert!(errors(&checked).is_empty(), "{:?}", checked.diagnostics);
    let program = checked.program.unwrap();
    let identity = signature(&program, "identity");
    assert_eq!(identity.effects.failures, [Ty::Param(0)]);
    let relay = signature(&program, "relay");
    let Ty::Fn(callback) = &relay.params[0] else {
        panic!("callback is not a function")
    };
    assert_eq!(callback.effects.names.len(), 1);
    assert_eq!(
        callback.effects.names[0].range().unwrap().suffix(),
        "[\"/data/**\"]"
    );
    let failure = function(&program, "identity")
        .uses
        .as_ref()
        .unwrap()
        .effects
        .first()
        .unwrap();
    assert_eq!(failure.args.as_ref().unwrap().len(), 1);
    assert!(failure.scope.is_none());

    let wrong = source.replace(
        "function target(value: Integer) -> Integer uses File.Read[\"/data/**\"]",
        "function target(value: Integer) -> Integer uses File.Read[\"/other/**\"]",
    );
    let rejected = check(&wrong);
    assert!(rejected.program.is_none());
    let diagnostics = errors(&rejected);
    assert_eq!(
        diagnostics
            .iter()
            .filter_map(|d| d.code.map(|c| c.info().id))
            .collect::<Vec<_>>(),
        ["E0519"],
        "{:?}",
        rejected.diagnostics
    );
    assert!(
        diagnostics[0]
            .primary
            .as_ref()
            .unwrap()
            .text
            .contains("/other/**"),
        "{:?}",
        diagnostics[0]
    );
    assert!(
        diagnostics[0]
            .primary
            .as_ref()
            .unwrap()
            .text
            .contains("/data/**"),
        "{:?}",
        diagnostics[0]
    );
}

// 関門: 不正な注釈を補完・Top化せず、名前の要求する引数の種類に応じて診断する。
// 既存の型引数検査は文字列/組/式を構文段で拒否するため、この診断の分担を確認できない。
#[test]
fn invalid_scopes_are_rejected_by_the_argument_contract() {
    for (setup, annotation, code) in [
        ("", "File.Write[Integer]", "E0520"),
        ("", "File.Write[]", "E0520"),
        ("", "File.Write[0]", "E0520"),
        ("", "File.Write[\"/data\", 443]", "E0520"),
        ("", "File.Write[\"relative\"]", "E0520"),
        ("", "File.Write[\"/data/../file\"]", "E0520"),
        ("", "File.Write[\"/data/*\"]", "E0520"),
        ("", "File.Write[\"${1}\"]", "E0520"),
        ("", "File.Write[\"/a\", true]", "E0520"),
        ("", "File.Write[\"/a\", false]", "E0520"),
        (
            "",
            "File.Write[\"${if true then 1 else 2 end if}\"]",
            "E0520",
        ),
        (
            "",
            "File.Write[\"${if false then f(1) else 2 end if}\"]",
            "E0520",
        ),
        ("", "File.Write[\"${\"x\" |> f()}\"]", "E0520"),
        ("", "File.Write[\"${\"${f([1, 2])}\"}\"]", "E0520"),
        ("", "File.Write[\"/data\" + \"/file\"]", "E0520"),
        (
            "const pattern: String = \"/data\"\n",
            "File.Write[pattern]",
            "E0520",
        ),
        ("", "Http.Connect[]", "E0520"),
        ("", "Http.Connect[\"a.example\"]", "E0520"),
        ("", "Http.Connect[443]", "E0520"),
        (
            "",
            "Http.Connect[\"a.example\", 443, \"b.example\"]",
            "E0520",
        ),
        ("", "Http.Connect[\"a.example\", \"443\"]", "E0520"),
        ("", "Http.Connect[\"a.example\", 65536]", "E0520"),
        ("", "Http.Connect[\"a.example\", 443..80]", "E0520"),
        ("", "Http.Connect[\"192.168.1.1/24\", 443]", "E0520"),
        ("", "Http.Connect[\"127.0.0.01\", 443]", "E0520"),
        ("", "Http.Connect[\"2001:0DB8::1\", 443]", "E0520"),
        ("", "Http.Connect[\"[::1]\", 443]", "E0520"),
        ("", "Http.Connect[\"fe80::1%en0\", 443]", "E0520"),
        ("", "Http.Connect[\"**.127.0.0.1\", 443]", "E0520"),
        ("", "Failure.Fail[\"x\"]", "E0513"),
        ("", "Failure.Fail[\"x\", \"y\"]", "E0513"),
        ("", "Failure.Fail[]", "E0513"),
        (
            "effect Local\n function ask() -> Unit\nend effect\n",
            "Local[Integer]",
            "E0513",
        ),
        (
            "effect Local\n function ask() -> Unit\nend effect\n",
            "Local[\"/data\"]",
            "E0513",
        ),
        (
            "effect Write\n function ask() -> Unit\nend effect\n",
            "Write[\"/data\"]",
            "E0513",
        ),
        (
            "effect Connect\n function ask() -> Unit\nend effect\n",
            "Connect[\"example.com\", 443]",
            "E0513",
        ),
        ("", "IO.All[\"/data\"]", "E0513"),
        ("", "State[\"/data\"]", "E0513"),
    ] {
        let source = format!(
            "{IMPORTS}{setup}function sample() -> Unit uses {annotation}\n ()\nend function\n"
        );
        let result = check(&source);
        assert!(result.program.is_none(), "accepted: {annotation}");
        let diagnostics = errors(&result);
        assert!(
            !diagnostics.is_empty(),
            "{annotation}: {:?}",
            result.diagnostics
        );
        assert!(
            diagnostics
                .iter()
                .all(|d| d.code.is_some_and(|c| c.info().id == code)),
            "{annotation}: {diagnostics:?}"
        );
    }
}

// 関門: 略記内と別群にまたがる重複を、正規化後の同一原子として両位置で示す。
// 集合APIのdedupだけでは、明示重複を黙って消す退行を捕まえない。
#[test]
fn duplicate_atoms_report_both_original_elements() {
    for (annotation, first, repeated) in [
        ("File.Write[\"/data\", \"/data\"]", "\"/data\"", "\"/data\""),
        (
            "File.Write[\"/data\", \"/other\"], File.Write[\"/data\"]",
            "\"/data\"",
            "\"/data\"",
        ),
        (
            "Http.Connect[\"A.Example\", 443, \"a.example\", 443..443]",
            "\"A.Example\", 443",
            "\"a.example\", 443..443",
        ),
        (
            "Http.Connect[\"192.0.2.1/32\", 443], Http.Connect[\"192.0.2.1\", 443]",
            "\"192.0.2.1/32\", 443",
            "\"192.0.2.1\", 443",
        ),
        (
            "Http.Connect[\"::1/128\", 0], Http.Connect[\"::1\", 0]",
            "\"::1/128\", 0",
            "\"::1\", 0",
        ),
    ] {
        let source =
            format!("{IMPORTS}function sample() -> Unit uses {annotation}\n ()\nend function\n");
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert_eq!(diagnostics.len(), 1, "{annotation}: {diagnostics:?}");
        let diagnostic = diagnostics[0];
        assert_eq!(
            diagnostic.code.unwrap().info().id,
            "E0419",
            "{annotation}: {diagnostic:?}"
        );
        let primary = diagnostic.primary.as_ref().unwrap().span;
        let earlier = diagnostic.secondary.first().unwrap().span;
        assert!(
            earlier.start < primary.start,
            "{annotation}: {diagnostic:?}"
        );
        assert_eq!(slice(&source, earlier), first, "{diagnostic:?}");
        assert_eq!(slice(&source, primary), repeated, "{diagnostic:?}");
    }
}

// 関門: PortArg は既存の IntLit を使う。接尾辞付き字句の取り落としと、
// 接尾辞固有の値域の無視を、通常の注釈の受理と拒否の対で捕まえる。
#[test]
fn port_arguments_use_integer_literal_values_and_widths() {
    for (literal, normalized) in [
        ("0s8", 0),
        ("127s8", 127),
        ("255u8", 255),
        ("443s16", 443),
        ("443s32", 443),
        ("443s64", 443),
        ("443u16", 443),
        ("443u32", 443),
        ("443u64", 443),
        ("0xff_ffu16", 65535),
    ] {
        let source = format!(
            "{IMPORTS}function sample() -> Unit uses Http.Connect[\"example.com\", {literal}]\n ()\nend function\n"
        );
        let checked = check(&source);
        assert!(
            errors(&checked).is_empty(),
            "{literal}: {:?}",
            checked.diagnostics
        );
        let program = checked.program.unwrap();
        assert_eq!(
            signature(&program, "sample").effects.names[0]
                .range()
                .unwrap()
                .suffix(),
            format!("[\"example.com\", {normalized}]")
        );
    }
    for literal in [
        "128s8",
        "256u8",
        "65535s16",
        "65536u16",
        "18446744073709551615u64",
        "-1",
        "443.0",
        "443m",
    ] {
        let source = format!(
            "{IMPORTS}function sample() -> Unit uses Http.Connect[\"example.com\", {literal}]\n ()\nend function\n"
        );
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert!(!diagnostics.is_empty(), "accepted {literal}");
        assert!(
            diagnostics
                .iter()
                .all(|d| d.code.is_some_and(|c| c.info().id == "E0520")),
            "{literal}: {diagnostics:?}"
        );
    }
}

// 関門: 範囲引数の構文が通常の値型に範囲を付ける許可へ広がらず、
// 閉じ括弧を失った入力は従来の構文診断で止まることを公開入口で確かめる。
#[test]
fn value_type_scope_misuse_and_unrecoverable_syntax_are_rejected() {
    for ty in [
        "Integer[\"/data\"]",
        "Integer[\"${1}\"]",
        "Integer[\"/data\", \"/other\"]",
        "Reference[\"/data\"]",
        "List[Integer[\"/data\"]]",
    ] {
        let source = format!("function sample(value: {ty}) -> Unit\n ()\nend function\n");
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert!(!diagnostics.is_empty(), "accepted {ty}");
        assert!(
            diagnostics
                .iter()
                .all(|d| d.code.is_some_and(|c| c.info().id == "E0520")),
            "{ty}: {diagnostics:?}"
        );
    }
    let source = format!(
        "{IMPORTS}function sample() -> Unit uses File.Write[\"/data\"\n ()\nend function\n"
    );
    let checked = check(&source);
    let diagnostics = errors(&checked);
    assert!(!diagnostics.is_empty());
    assert!(
        diagnostics.iter().all(|d| d
            .code
            .is_some_and(|c| c.info().id.starts_with("E01") || c.info().id.starts_with("E02"))),
        "{diagnostics:?}"
    );
}

// 関門: 型の構文誤りの番号・文・位置は基準版の固定期待値で守る。
// 既存の拒否テストはE0520だけを調べ、型引数への分岐の退行を捕まえない。
#[test]
fn malformed_type_arguments_keep_the_original_syntax_diagnostic() {
    for (ty, found, column) in [
        ("List[string]", "string", 17),
        ("Option[int]", "int", 19),
        ("List[]", "]", 17),
        ("Integer[]", "]", 20),
    ] {
        let source = format!("type Bad = {ty}\n");
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert_eq!(diagnostics.len(), 1, "{ty}: {diagnostics:?}");
        let d = diagnostics[0];
        assert_eq!(d.code.unwrap().info().id, "E0201", "{ty}: {d:?}");
        assert_eq!(d.message, format!("expected a type, found `{found}`"));
        let span = d.primary.as_ref().unwrap().span;
        assert_eq!(slice(&source, span), found);
        let pos = checked.sources.get(span.file).unwrap().line_col(span.start);
        assert_eq!((pos.line, pos.column), (1, column));
    }
    // 関門: 型パラメータの有無で診断文を分ける契約を固定する。
    // 従来の番号だけの検査ではIntegerや利用者型への誤った案内を捕まえない。
    for (setup, ty, name, expected, found) in [
        ("", "List[42]", "List", "type arguments", "[42]"),
        ("", "List[\"a\"]", "List", "type arguments", "[\"a\"]"),
        ("", "List[\"${1}\"]", "List", "type arguments", "[\"${1}\"]"),
        (
            "",
            "Integer[\"/data\"]",
            "Integer",
            "no scope arguments",
            "[\"/data\"]",
        ),
        (
            "record R\n value: String\nend record\n",
            "R[\"a\"]",
            "R",
            "no scope arguments",
            "[\"a\"]",
        ),
        (
            "record R[T]\n value: T\nend record\n",
            "R[\"a\"]",
            "R",
            "type arguments",
            "[\"a\"]",
        ),
    ] {
        let source = format!("{setup}type Bad = {ty}\n");
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert_eq!(diagnostics.len(), 1, "{ty}: {diagnostics:?}");
        let d = diagnostics[0];
        assert_eq!(d.code.unwrap().info().id, "E0520");
        assert_eq!(
            d.message,
            format!("invalid scope arguments for `{name}` (expected {expected})")
        );
        assert_eq!(d.notes, [format!("found: {found}")]);
    }
}

// 関門: 閉じ忘れで次の宣言や本体をEOFまで読み飛ばさない。
// 旧テストの番号だけでは検出できないため、通常入口の主位置を行・列まで固定する。
#[test]
fn unclosed_scopes_stop_at_the_next_unexpected_token() {
    for (source, token, line, column) in [
        (
            "function sample() -> Unit uses File.Write[\"/data\"\n f(1)\nend function\n",
            "f",
            2,
            2,
        ),
        (
            "function sample() -> Unit uses File.Write[\"/data\"\n x\nend function\n",
            "x",
            2,
            2,
        ),
        (
            "function sample() -> Unit uses File.Write[\"/data\"\n \"x\" |> print\nend function\n",
            "string",
            2,
            2,
        ),
        (
            "function sample() -> Unit uses File.Write[\"/data\"\n let a = 1\nend function\n",
            "let",
            2,
            2,
        ),
        (
            "uses File.Write[\"/data\"\nfunction after() -> Unit\nend function\n",
            "function",
            2,
            1,
        ),
        ("uses File.Write[\"/data\"\nuses File.Read\n", "uses", 2, 1),
        (
            "function sample() -> Unit uses File.Write[\"/data\"\n ()\nend function\n",
            "(",
            2,
            2,
        ),
        (
            "function sample() -> Unit uses File.Write[\"/data\"\nend function\n",
            "end",
            2,
            1,
        ),
        ("uses File.Write[\"/data\"\n)\n", ")", 2, 1),
        ("uses File.Write[\"/data\" + (1]\n", "]", 1, 29),
    ] {
        let checked = check(source);
        let d = errors(&checked)[0];
        assert_eq!(d.code.unwrap().info().id, "E0201", "{source}: {d:?}");
        assert_eq!(
            d.message,
            if token == "string" {
                "expected `,` or `]`, found a string literal".to_owned()
            } else {
                format!("expected `,` or `]`, found `{token}`")
            }
        );
        let span = d.primary.as_ref().unwrap().span;
        assert_eq!(
            slice(source, span),
            if token == "string" { "\"x\"" } else { token },
            "{source}: {d:?}"
        );
        let pos = checked.sources.get(span.file).unwrap().line_col(span.start);
        assert_eq!((pos.line, pos.column), (line, column), "{source}");
    }
}

// 関門: 一つの元の名前への診断・同じ修正編集を展開後の原子数だけ増やさない。
// 既存の正常な展開とE0513の検査は、名前の検索の失敗を通らない。
#[test]
fn shorthand_reports_name_resolution_errors_and_repairs_once() {
    for (annotation, code, replacements) in [
        ("File.Wrte[\"/a\", \"/b\"]", "E0303", vec!["Write"]),
        ("IO[\"/a\", \"/b\"]", "E0333", vec!["IO.All"]),
        ("Integer[\"/a\", \"/b\"]", "E0315", vec![]),
        (
            "File.Read, Benitoite.Integer[\"/a\", \"/b\"]",
            "E0316",
            vec![],
        ),
    ] {
        let source =
            format!("{IMPORTS}function sample() -> Unit uses {annotation}\n ()\nend function\n");
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert_eq!(diagnostics.len(), 1, "{annotation}: {diagnostics:?}");
        let d = diagnostics[0];
        assert_eq!(d.code.unwrap().info().id, code);
        assert_eq!(
            d.helps
                .iter()
                .flat_map(|h| &h.edits)
                .map(|e| e.replacement.as_str())
                .collect::<Vec<_>>(),
            replacements
        );
    }
}

// 関門: 閉じ忘れの回復で、正しい複数行の群・末尾コンマを拒否しない。
// 一行の展開テストでは物理行の境界による誤拒否を捕まえない。
#[test]
fn multiline_scopes_keep_valid_groups_and_expression_diagnostics() {
    for annotation in [
        "File.Write[\n \"/a\"\n , \"/b\"\n ]",
        "File.Write[\n \"/a\",\n \"/b\",\n ]",
        "Http.Connect[\n \"a.example\",\n 443,\n \"b.example\", 80..81,\n ]",
    ] {
        let source =
            format!("{IMPORTS}function sample() -> Unit uses {annotation}\n ()\nend function\n");
        let checked = check(&source);
        assert!(
            errors(&checked).is_empty(),
            "{annotation}: {:?}",
            checked.diagnostics
        );
    }
    for annotation in [
        "File.Write[\"/a\"\n + \"/b\"]",
        "File.Write[\"/a\" +\n \"/b\"]",
        "File.Write[\"/a\", (\"/b\"\n + \"/c\")]",
    ] {
        let source =
            format!("{IMPORTS}function sample() -> Unit uses {annotation}\n ()\nend function\n");
        let checked = check(&source);
        let diagnostics = errors(&checked);
        assert_eq!(diagnostics.len(), 1, "{annotation}: {diagnostics:?}");
        assert_eq!(
            diagnostics[0].code.unwrap().info().id,
            "E0520",
            "{annotation}: {diagnostics:?}"
        );
    }
}

// 関門: 通常ソースの範囲付き uses から一原子の被覆・拒否理由を検査する。
// 代数の単体テストは制約の選択と関数型の流れ込みを通らず、既存例は同じ範囲の比較だけである。
// 公開check入口で、名前・族・Top・和の境界と理由別の注記・修正案を固定した期待値と照合する。
#[test]
fn effect_coverage_uses_one_same_named_atom() {
    for (required, allowed, rejection) in [
        ("File.Read[\"/data/a\"]", "File.Read[\"/data/**\"]", None),
        ("File.Read[\"/data/**\"]", "File.Read", None),
        ("File.Read[\"/data\"]", "File.Read[\"/data/**\"]", None),
        (
            "File.Read[\"/data/**\"]",
            "File.Read[\"/data/a\"]",
            Some(("E0519", "notCovered")),
        ),
        (
            r#"File.Read["/data/**"]"#,
            r#"File.Read["/data/a"], File.Write["/other/**"]"#,
            Some(("E0519", "notCovered")),
        ),
        (
            "File.Read",
            "File.Read[\"/**\"]",
            Some(("E0519", "unknownSource")),
        ),
        (
            "File.Read[\"/data/a\"]",
            "File.Write[\"/data/**\"]",
            Some(("E0501", "")),
        ),
        (
            "Http.Connect[\"a.example\", 443]",
            "Http.Connect[\"*.example\", 400..500]",
            None,
        ),
        (
            "Http.Connect[\"example\", 443]",
            "Http.Connect[\"**.example\", 443]",
            Some(("E0519", "notCovered")),
        ),
        (
            "Http.Connect[\"a.b.example\", 443]",
            "Http.Connect[\"*.example\", 443]",
            Some(("E0519", "notCovered")),
        ),
        (
            "Http.Connect[\"a.b.example\", 443]",
            "Http.Connect[\"**.example\", 443]",
            None,
        ),
        (
            "Http.Connect[\"a.example\", 0..9]",
            "Http.Connect[\"a.example\", 0..4, \"a.example\", 5..9]",
            Some(("E0519", "atomicCoverOnly")),
        ),
        (
            "Http.Connect[\"192.0.2.1\", 443]",
            "Http.Connect[\"192.0.2.0/24\", 443]",
            None,
        ),
        (
            "Http.Connect[\"192.0.2.1\", 443]",
            "Http.Connect[\"::/0\", 443]",
            Some(("E0519", "notCovered")),
        ),
        (
            "Http.Connect[\"::ffff:192.0.2.1\", 443]",
            "Http.Connect[\"0.0.0.0/0\", 443]",
            Some(("E0519", "notCovered")),
        ),
        (
            "Http.Connect[\"a.example\", 443]",
            "Http.Connect[\"0.0.0.0/0\", 0..65535]",
            Some(("E0519", "notCovered")),
        ),
        (
            r#"File.Read["/**"]"#,
            r#"File.Read["/a/**", "/b/**"]"#,
            Some(("E0519", "atomicCoverOnly")),
        ),
        (
            "File.Read",
            r#"File.Read["/a/**", "/b/**"]"#,
            Some(("E0519", "unknownSource")),
        ),
        (
            r#"File.Read["/a/x"]"#,
            r#"File.Read["/a/**", "/b/**"]"#,
            None,
        ),
    ] {
        let source = format!(
            "{IMPORTS}function target() -> Unit uses {required}\n ()\nend function\nfunction caller() -> Unit uses {allowed}\n target()\nend function\n"
        );
        let checked = check(&source);
        if let Some((code, reason)) = rejection {
            let ds = errors(&checked);
            assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
            assert_eq!(ds[0].code.unwrap().info().id, code, "{source}\n{ds:?}");
            if code == "E0501" {
                continue;
            }
            assert_eq!(
                slice(&source, ds[0].primary.as_ref().unwrap().span),
                "target()"
            );
            // 同名の uses の元位置を示す。略記は一位置にまとめ、別名の原子は含めない
            // （設計書 02-10「診断の内部の表現」）。
            let declared = match allowed {
                r#"File.Read["/data/a"], File.Write["/other/**"]"# => r#"File.Read["/data/a"]"#,
                _ => allowed,
            };
            assert_eq!(ds[0].secondary.len(), 1, "{source}\n{ds:?}");
            assert_eq!(slice(&source, ds[0].secondary[0].span), declared);
            assert_eq!(
                usize::try_from(ds[0].secondary[0].span.start.0).unwrap(),
                source.rfind(declared).unwrap()
            );
            assert_eq!(ds[0].secondary[0].text, "declared here");
            if allowed == r#"File.Read["/data/a"], File.Write["/other/**"]"# {
                assert_eq!(
                    ds[0].primary.as_ref().unwrap().text,
                    r#"`File.Read["/data/**"]` is not covered by `File.Read["/data/a"]`"#
                );
            }
            assert_eq!(ds[0].helps.len(), 1);
            let (note, help) = match reason {
                "unknownSource" => (
                    "the incoming scope (knownUpperBound) is Top (all targets); only a surrounding Top atom of the same name in requiredUpperBound covers it",
                    "to keep a bounded contract, use a scoped entry such as `File.readTextIn` after `Scope.checkPathIn`, and annotate the checked result with a scope covered by that contract, or narrow the callee's `uses` annotation; to permit all targets, declare the same effect without scope arguments in the surrounding `uses` annotation",
                ),
                "atomicCoverOnly" => (
                    "two or more closed surrounding atoms (requiredUpperBound) have the same name, but no one atom covers the incoming scope (knownUpperBound); coverage by their union is not checked",
                    "to keep the surrounding contract, use a callee or entry whose declared scope is covered by one surrounding atom; to permit a broader scope, explicitly enlarge the surrounding `uses` annotation to cover the incoming scope in one atom",
                ),
                "notCovered" => (
                    "no one surrounding atom of the same name (requiredUpperBound) covers the incoming scope (knownUpperBound)",
                    "to keep the surrounding contract, use a callee or entry whose declared scope is covered by one surrounding atom; to permit a broader scope, explicitly enlarge the surrounding `uses` annotation to cover the incoming scope in one atom",
                ),
                _ => panic!("unexpected coverage reason: {reason}"),
            };
            assert_eq!(ds[0].helps[0].message, help, "{source}");
            assert!(ds[0].message.ends_with(&format!("({reason})")), "{ds:?}");
            let upper_bound = match allowed {
                r#"File.Read["/a/**", "/b/**"]"# => r#"File.Read["/a/**"], File.Read["/b/**"]"#,
                r#"Http.Connect["a.example", 0..4, "a.example", 5..9]"# => {
                    r#"Http.Connect["a.example", 0..4], Http.Connect["a.example", 5..9]"#
                }
                _ => declared,
            };
            assert_eq!(
                ds[0].notes,
                [
                    note.to_owned(),
                    format!("reason: {reason}"),
                    format!("requiredUpperBound: {upper_bound}"),
                    format!("knownUpperBound: {required}"),
                    format!("uncoveredAtom: {required}"),
                    "source: the effect flowing from this call or expression".to_owned(),
                ],
                "{source}"
            );
        } else {
            assert!(
                errors(&checked).is_empty(),
                "{source}\n{:?}",
                checked.diagnostics
            );
        }
    }
}

// 関門: 範囲付き原子の存在だけで、効果名の宣言漏れの位置と修正案を変えない。
// Topだけの既存の診断例では、無関係な範囲がE0519へ分岐させる退行を捕まえない。
// 通常のcheck入口で診断を観測し、差し込み口は追加しない。
#[test]
fn effect_coverage_preserves_missing_effect_diagnostics() {
    for (required, surrounding) in [
        (r#"File.Read["/data/a"]"#, ""),
        ("Console.Write", r#" uses File.Read["/data/**"]"#),
    ] {
        let source = format!(
            "{IMPORTS}import Benitoite.Unofficial.IO.Console\nfunction target() -> Unit uses {required}\n ()\nend function\nfunction main() -> Unit{surrounding}\n target()\nend function\n"
        );
        let checked = check(&source);
        let ds = errors(&checked);
        assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
        let d = ds[0];
        assert_eq!(d.code.unwrap().info().id, "E0501", "{source}\n{ds:?}");
        let primary = d.primary.as_ref().unwrap();
        assert_eq!(slice(&source, primary.span), "target()");
        assert_eq!(
            usize::try_from(primary.span.start.0).unwrap(),
            source.rfind("target()").unwrap()
        );
        assert_eq!(primary.text, format!("`{required}` happens here"));
        assert_eq!(d.secondary.len(), 1);
        assert_eq!(slice(&source, d.secondary[0].span), "main");
        assert_eq!(d.secondary[0].text, "declared here");
        assert_eq!(d.helps.len(), 1);
        assert_eq!(
            d.helps[0].message,
            format!(
                "add `uses {required}` to the signature, or move this call to a function that uses `{required}`"
            )
        );
    }
}

// 関門: 一つの引数で複数の原子が上限を超えても、同じ位置の不一致は一件で報告する。
// 一原子ずつの既存例は、pair制約でのE0519の重複を観測しない。
#[test]
fn effect_coverage_reports_one_failure_per_argument() {
    let source = format!(
        r#"{IMPORTS}
function relay(body: function() -> Unit uses File.Read["/allowed/**"], File.Write["/allowed/**"]) -> Unit
 ()
end function
function main() -> Unit
 bind g <- lambda() -> Unit uses File.Read["/other/a"], File.Write["/other/a"]
  ()
 end lambda
 relay(body: g)
end function
"#
    );
    let checked = check(&source);
    let ds = errors(&checked);
    assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
    assert_eq!(ds[0].code.unwrap().info().id, "E0519", "{ds:?}");
}

// 関門: 被覆を制約の各生成位置へ接続し、型確定後のコアIRにも同じ意味で渡す。
// 通常の呼び出しだけではラムダ・関数値の潜在効果・resumeの制約の選択漏れを捕まえない。
#[test]
fn effect_coverage_flows_through_lambdas_callbacks_and_resume() {
    let source = format!(
        r#"{IMPORTS}
effect Ask
 function ask() -> Integer
end effect
function resumed() -> Integer uses File.Read["/data/**"]
 return handle
  ask()
 with
 case ask() -> resume(target(value: 1))
 end handle
end function
function target(value: Integer) -> Integer uses File.Read["/data/a"]
 return value
end function
function relay(body: function(value: Integer) -> Integer uses File.Read["/data/**"]) -> Integer uses File.Read["/data/**"]
 return body(value: 1)
end function
trait ReadValue[T]
 function readValue(value: T) -> Integer uses File.Read["/data/**"]
end trait
implement ReadValue[Integer]
 function readValue(value: Integer) -> Integer uses File.Read["/data/**"]
  return target(value: value)
 end function
end implement
function sample() -> Integer uses File.Read["/data/**"]
 bind partial: function(value: Integer) -> Integer uses File.Read["/data/**"] <- target(value: _)
 bind f: function(value: Integer) -> Integer uses File.Read["/data/**"] <- target
 bind g <- lambda(value: Integer) -> Integer uses File.Read["/data/**"]
   return target(value: value)
 end lambda
 return relay(body: g) + relay(body: f) + partial(value: 1) + ReadValue.readValue(value: 1)
end function
"#
    );
    let checked = check(&source);
    assert!(errors(&checked).is_empty(), "{:?}", checked.diagnostics);
    let program = checked.program.unwrap();
    let core = benitoite::ir::desugar::desugar(
        &program.modules,
        &program.asts,
        &program.resolved,
        &program.types,
    )
    .unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());
}

// 関門: 最外側の潜在効果の被覆を、コレクション・引数・Failの不変な位置へ広げない。
// 同じ範囲の既存例だけでは、相互被覆を構造等号に流用する退行が観測できない。
#[test]
fn effect_coverage_keeps_nested_types_and_failures_invariant() {
    for (parameters, code) in [
        (
            r#"values: List[function() -> Unit uses File.Read["/data/a"]]"#,
            "E0401",
        ),
        (
            r#"values: List[function() -> Unit uses File.Read["/data/**"], File.Read["/data/a"]]"#,
            "E0401",
        ),
    ] {
        let source = format!(
            r#"{IMPORTS}
function consume(values: List[function() -> Unit uses File.Read["/data/**"]]) -> Unit
 ()
end function
function caller({parameters}) -> Unit
 consume(values: values)
end function
"#
        );
        let checked = check(&source);
        let ds = errors(&checked);
        assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
        assert_eq!(ds[0].code.unwrap().info().id, code, "{ds:?}");
    }
    let source = format!(
        r#"{IMPORTS}
function target() -> Unit uses Failure.Fail[function() -> Unit uses File.Read["/data/a"]]
 ()
end function
function caller() -> Unit uses Failure.Fail[function() -> Unit uses File.Read["/data/**"]]
 target()
end function
"#
    );
    let checked = check(&source);
    assert!(
        errors(&checked)
            .iter()
            .any(|d| d.code.unwrap().info().id == "E0514"),
        "{:?}",
        checked.diagnostics
    );
}

// 関門: 標準の不透明型の認定と添字を通常の型注釈から確定した型・IRまで保つ。
// 原子の既存テストでは、同じ範囲の値型・型別名・入れ子と照合の接続を観測できない。
// 公開のcheckとdesugarを使い、内部への差し込み口を増やさない。
#[test]
fn opaque_standard_value_types_keep_their_invariant_scope() {
    use benitoite::types::{
        TyCon,
        builtin::{BuiltinTypeId as B, RangeIndex},
    };
    let source = r#"import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.Network.Http

type Selected = Scope.PathIn["/data/**"]
function bare(path: Scope.PathIn, request: Http.RequestIn) -> Scope.PathIn
 return path
end function
function selected(path: Selected) -> Selected
 return match path with
  case value -> value
 end match
end function
function ignore(request: Http.RequestIn["*.example.com", 443..445]) -> Unit
 match request with
  case _ -> ()
 end match
end function
function nested(paths: List[Selected]) -> List[Selected]
 return paths
end function
function checkPath(value: Selected) -> Selected
 return value
end function
"#;
    let checked = check(source);
    assert!(errors(&checked).is_empty(), "{:?}", checked.diagnostics);
    let program = checked.program.unwrap();
    assert_eq!(
        signature(&program, "bare").params,
        [
            Ty::Con(TyCon::Builtin(B::PATH_IN), vec![], RangeIndex::TOP),
            Ty::Con(TyCon::Builtin(B::REQUEST_IN), vec![], RangeIndex::TOP)
        ]
    );
    let selected = signature(&program, "selected");
    assert_eq!(
        selected.params.as_slice(),
        std::slice::from_ref(&selected.ret)
    );
    let Ty::Con(TyCon::Builtin(id), args, ix) = &selected.ret else {
        panic!("not an opaque built-in type")
    };
    assert_eq!(*id, B::PATH_IN);
    assert!(args.is_empty());
    assert_eq!(ix.range().unwrap().suffix(), "[\"/data/**\"]");
    assert!(selected.ret.indices_valid(0));
    let primitive = benitoite::builtins::lookup_builtin("Scope.checkPath").unwrap();
    let (standard, _) = program.resolved.bindings.iter().find(|(_, binding)| matches!(binding.kind, benitoite::resolve::BindingKind::BuiltinFn(id) if id == primitive)).unwrap();
    assert_eq!(
        program
            .types
            .range_signatures
            .get(standard)
            .unwrap()
            .range_count(),
        0
    );
    for (user, _) in program
        .resolved
        .bindings
        .iter()
        .filter(|(_, binding)| binding.name == "checkPath")
    {
        assert!(program.types.range_signatures.get(user).is_none());
    }
    let core = benitoite::ir::desugar::desugar(
        &program.modules,
        &program.asts,
        &program.resolved,
        &program.types,
    )
    .unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());

    for (argument, parameter) in [
        ("Scope.PathIn", "Scope.PathIn[\"/data/**\"]"),
        ("Scope.PathIn[\"/data/**\"]", "Scope.PathIn"),
        ("Scope.PathIn[\"/data/a\"]", "Scope.PathIn[\"/data/**\"]"),
        ("Scope.PathIn[\"/data/**\"]", "Scope.PathIn[\"/data/a\"]"),
        (
            "Http.RequestIn[\"api.example.com\", 443]",
            "Http.RequestIn[\"*.example.com\", 443]",
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Network.Http\nfunction accept(value: {parameter}) -> Unit\n ()\nend function\nfunction caller(value: {argument}) -> Unit\n accept(value: value)\nend function\n"
        );
        let checked = check(&source);
        let ds = errors(&checked);
        assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
        assert_eq!(ds[0].code.unwrap().info().id, "E0401", "{ds:?}");
    }

    // 射影の入口も不変の添字を保ち、旧 CheckedPath から無検査で受け取らない。
    // 一般のacceptの比較だけでは、標準署名の誤った登録や具体化を捕まえない。
    for (argument, code) in [
        ("Scope.CheckedPath", "E0401"),
        ("Scope.PathIn[\"/data/**\"]", "E0519"),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nfunction project(value: {argument}) -> String\n return Scope.pathInValue(path: value)\nend function\n"
        );
        let checked = check(&source);
        let ds = errors(&checked);
        assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
        assert_eq!(ds[0].code.unwrap().info().id, code, "{source}\n{ds:?}");
    }

    // 型注釈だけの引数には事実がない。同じ Result の Ok を直接照合する場合は、
    // 既知の範囲を持つ成功値を非 Top のまま射影できる。
    let checked = check(
        r#"import Benitoite.Unofficial.Scope
function project(raw: String) -> String
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: raw)
 return match result with
 case Result.Ok(value) -> Scope.pathInValue(path: value)
 case Result.Error(_) -> "outside"
 end match
end function
"#,
    );
    assert!(errors(&checked).is_empty(), "{:?}", checked.diagnostics);
}

// 関門: 認定を名前の綴りや一般の@opaqueへ広げず、標準型には一つの範囲だけを許す。
// 型APIの単体テストでは名前解決の誤認定や構文上の複数範囲の受理を捕まえない。
#[test]
fn only_certified_opaque_types_accept_one_scope() {
    for (setup, ty) in [
        ("", "Scope.PathIn[\"/a\", \"/b\"]"),
        ("", "Scope.PathIn[Integer]"),
        ("type R = String\n", "Scope.PathIn[R]"),
        (
            "",
            "Http.RequestIn[\"example.com\", 443, \"other.com\", 80]",
        ),
        ("", "Http.RequestIn[\"example.com\"]"),
        ("", "IOError[\"/a\"]"),
        ("", "Task[\"/a\"]"),
        (
            "import Benitoite.Unofficial.IO.File\n",
            "File.Reader[\"/a\"]",
        ),
        (
            "import Benitoite.Unofficial.Regex\n",
            "Regex.Pattern[\"/a\"]",
        ),
        (
            "record PathIn\n path: String\nend record\n",
            "PathIn[\"/a\"]",
        ),
        (
            "@opaque\npublic record RequestIn\n request: String\nend record\n",
            "RequestIn[\"example.com\", 443]",
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Network.Http\n{setup}function sample(value: {ty}) -> Unit\n ()\nend function\n"
        );
        let checked = check(&source);
        let ds = errors(&checked);
        assert_eq!(ds.len(), 1, "{source}\n{ds:?}");
        assert_eq!(ds[0].code.unwrap().info().id, "E0520", "{source}\n{ds:?}");
    }
}

// 関門: 型名の公開は内部表現の公開にならず、構築・更新・表現照合・アクセサを拒否する。
// 一般の@opaqueの既存例では組み込み表から登録した型に表現が生じる退行を観測できない。
#[test]
fn opaque_standard_values_have_no_public_representation() {
    for (name, ty, expression, code) in [
        (
            "Scope.PathIn",
            "Scope.PathIn[\"/data/**\"]",
            "Scope.PathIn(path: \"/data/a\")",
            "E0304",
        ),
        (
            "Scope.PathIn",
            "Scope.PathIn[\"/data/**\"]",
            "Scope.PathIn(..value, path: \"/data/a\")",
            "E0304",
        ),
        (
            "Scope.PathIn",
            "Scope.PathIn[\"/data/**\"]",
            "match value with case Scope.PathIn(path: _) -> () end match",
            "E0304",
        ),
        (
            "Scope.PathIn",
            "Scope.PathIn[\"/data/**\"]",
            "Scope.PathIn.path(value)",
            "E0304",
        ),
        (
            "Http.RequestIn",
            "Http.RequestIn[\"example.com\", 443]",
            "Http.RequestIn(request: value)",
            "E0304",
        ),
        (
            "Http.RequestIn",
            "Http.RequestIn[\"example.com\", 443]",
            "Http.RequestIn(..value, request: value)",
            "E0304",
        ),
        (
            "Http.RequestIn",
            "Http.RequestIn[\"example.com\", 443]",
            "match value with case Http.RequestIn(request: _) -> () end match",
            "E0304",
        ),
        (
            "Http.RequestIn",
            "Http.RequestIn[\"example.com\", 443]",
            "Http.RequestIn.request(value)",
            "E0304",
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Network.Http\nfunction sample(value: {ty}) -> Unit\n {expression}\nend function\n"
        );
        let checked = check(&source);
        let ds = errors(&checked);
        assert_eq!(ds.len(), 1, "{name}: {source}\n{ds:?}");
        assert_eq!(ds[0].code.unwrap().info().id, code, "{source}\n{ds:?}");
    }
}
