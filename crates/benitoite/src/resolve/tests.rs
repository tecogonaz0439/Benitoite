//! 名前解決の公開の出力を確かめる（設計書 02-04、実装プラン F06「受け入れテスト」）。

// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::test_support::resolve_files;

#[test]
fn all_stdlib_sources_resolve() {
    let mut source = String::new();
    for module in crate::prelude::STDLIB.iter().filter(|m| !m.prelude) {
        source.push_str(&format!(
            "import Benitoite.{}{}\n",
            if module.unofficial { "Unofficial." } else { "" },
            module.path.join(".")
        ));
    }
    source.push_str("function main() -> Unit\nend function\n");
    let (_, resolved, _) = resolve_files(&[("main.bnt", &source)]);
    assert!(
        resolved.diagnostics.is_empty(),
        "{:?}",
        resolved.diagnostics
    );
}

// 作成時の関門: F06 の受け入れ条件を公開の resolve と実際のソースで検査する。
// 最小実行版の検査から移したテストだけでは、新しい表・複数モジュールの契約を確かめられない。
// 束縛の誤った共有、非公開名の漏れ、修正案の誤った範囲が利用者に及ぼす回帰を検出する
// （設計書 07-03「テストの設計の原則」、スキル test-audit「作成時の関門」）。
use super::{Binding, BindingKind, DeclSite, LocalKind, ResolveOutput};
use crate::base::{BindingId, NodeId, Span};
use crate::diag::{DiagCode, Diagnostic};
use crate::modules::{LoadOutput, ModuleKind};
use crate::syntax::ast::{Expr, FnDecl, Item, Pattern, Stmt, TypeExpr};

fn entry(load: &LoadOutput) -> &crate::syntax::ast::Module {
    let id = load
        .modules
        .iter()
        .find(|m| m.kind == ModuleKind::Entry)
        .unwrap()
        .id;
    &load.asts[usize::try_from(id.0).unwrap()]
}

fn function<'a>(load: &'a LoadOutput, name: &str) -> &'a FnDecl {
    entry(load)
        .decls
        .iter()
        .find_map(|d| {
            if let Item::Fn(f) = &d.item
                && f.name.text == name
            {
                Some(f)
            } else {
                None
            }
        })
        .unwrap()
}

fn clean(out: &ResolveOutput) {
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
}

fn diagnostic(out: &ResolveOutput, code: DiagCode) -> &Diagnostic {
    let ds: Vec<_> = out
        .diagnostics
        .iter()
        .filter(|d| d.code == Some(code))
        .collect();
    assert_eq!(ds.len(), 1, "{code:?}: {:?}", out.diagnostics);
    ds[0]
}

fn snippet(load: &LoadOutput, span: Span) -> &str {
    let bytes = load.sources.get(span.file).unwrap().text();
    std::str::from_utf8(
        &bytes[usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()],
    )
    .unwrap()
}

fn primary<'a>(load: &'a LoadOutput, out: &ResolveOutput, code: DiagCode) -> &'a str {
    snippet(load, diagnostic(out, code).primary.as_ref().unwrap().span)
}

fn apply(source: &str, d: &Diagnostic) -> String {
    let mut edits: Vec<_> = d.helps.iter().flat_map(|h| h.edits.iter()).collect();
    assert!(!edits.is_empty(), "{d:?}");
    edits.sort_by_key(|e| std::cmp::Reverse(e.span.start));
    let mut fixed = source.to_owned();
    for edit in edits {
        fixed.replace_range(
            usize::try_from(edit.span.start.0).unwrap()..usize::try_from(edit.span.end.0).unwrap(),
            &edit.replacement,
        );
    }
    fixed
}

fn reference(out: &ResolveOutput, node: NodeId) -> (BindingId, &Binding) {
    let id = *out.refs.get(node).expect("reference is missing");
    let binding = out.binding_of_ref(node).unwrap();
    assert_eq!(Some(binding), out.bindings.get(id));
    (id, binding)
}

#[test]
fn stdlib_source_and_table_contracts() {
    use crate::builtins::iface::Capability;
    use crate::builtins::table::{EntryKind, builtin_kind, tags};
    use crate::builtins::{BuiltinId, builtin_decl, lookup_builtin};
    let mut source = String::new();
    for m in crate::prelude::STDLIB.iter().filter(|m| !m.prelude) {
        source.push_str(&format!(
            "import Benitoite.{}{}\n",
            if m.unofficial { "Unofficial." } else { "" },
            m.path.join(".")
        ));
    }
    source.push_str("function main() -> Unit\nend function\n");
    let (load, out, _) = resolve_files(&[("main.bnt", &source)]);
    clean(&out);
    let mut counts = std::collections::BTreeMap::<BuiltinId, usize>::new();
    for ast in &load.asts {
        for top in &ast.decls {
            match &top.item {
                Item::Fn(f) => {
                    let Some(attr) = top.attrs.iter().find(|a| a.name.text == "builtin") else {
                        continue;
                    };
                    let name = &attr.args[0].value;
                    assert!(
                        !name.starts_with("Benitoite.") && !name.starts_with('%'),
                        "{name}"
                    );
                    let id = lookup_builtin(name).unwrap();
                    assert_eq!(
                        out.bindings
                            .get(*out.decls.get(f.id).unwrap())
                            .unwrap()
                            .kind,
                        BindingKind::BuiltinFn(id)
                    );
                    let declared = builtin_decl(id).unwrap();
                    assert_eq!(usize::from(declared.arity), f.params.len(), "{name}");
                    assert_ne!(declared.capability, Capability::Io, "{name}");
                    assert_eq!(builtin_kind(id), Some(EntryKind::Declared));
                    if declared.capability == Capability::Pure
                        && let Some(uses) = &f.uses
                    {
                        for effect in &uses.effects {
                            assert!(
                                matches!(
                                    reference(&out, effect.id).1.kind,
                                    BindingKind::EffectVar { .. }
                                ),
                                "{name}"
                            );
                        }
                    }
                    *counts.entry(id).or_default() += 1;
                }
                Item::Effect(e) => {
                    for op in &e.ops {
                        let binding = *out.decls.get(op.id).unwrap();
                        let Some(id) = out.builtin_ops.get(binding) else {
                            continue;
                        };
                        let declared = builtin_decl(*id).unwrap();
                        assert_eq!(usize::from(declared.arity), op.params.len());
                        assert_eq!(declared.capability, Capability::Io);
                        assert_eq!(builtin_kind(*id), Some(EntryKind::EffectOp));
                        assert_eq!(lookup_builtin(declared.name), Some(*id));
                        *counts.entry(*id).or_default() += 1;
                    }
                }
                Item::Const(_)
                | Item::Data(_)
                | Item::Alias(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Impl(_)
                | Item::Error(_) => {}
            }
        }
    }
    let mut index = 0_u16;
    while let Some(declared) = builtin_decl(BuiltinId(index)) {
        if matches!(
            builtin_kind(BuiltinId(index)),
            Some(EntryKind::Declared | EntryKind::EffectOp)
        ) {
            assert_eq!(counts.get(&BuiltinId(index)), Some(&1), "{}", declared.name);
        }
        index += 1;
    }
    // 引数の数と権限は、Rust の宣言の字面でなく、ソースを読んだ結果と表で照合する
    // （実装プラン L00「ソースと表の照合」）。U3 の State の例外が増減した場合も検出する。
    let state_names = crate::builtins::funcs::PARTS[22..]
        .iter()
        .flat_map(|part| part.iter())
        .filter(|decl| decl.capability == Capability::State)
        .map(|decl| decl.name)
        .collect::<Vec<_>>();
    assert_eq!(
        state_names,
        [
            "IO.File.closeWriter",
            "Network.Http.requestOf",
            "Network.Http.closeListener",
            "Network.Http.closeExchange",
        ]
    );
    for (name, tag) in [
        ("Option.Some", tags::OPTION_SOME),
        ("Option.None", tags::OPTION_NONE),
        ("Result.Ok", tags::RESULT_OK),
        ("Result.Error", tags::RESULT_ERROR),
        ("Pair.Pair", tags::PAIR),
        ("Triple.Triple", tags::TRIPLE),
        ("IOErrorKind.NotFound", tags::IO_ERROR_KIND_NOT_FOUND),
        (
            "IOErrorKind.PermissionDenied",
            tags::IO_ERROR_KIND_PERMISSION_DENIED,
        ),
        (
            "IOErrorKind.AlreadyExists",
            tags::IO_ERROR_KIND_ALREADY_EXISTS,
        ),
        ("IOErrorKind.IsDirectory", tags::IO_ERROR_KIND_IS_DIRECTORY),
        (
            "IOErrorKind.NotDirectory",
            tags::IO_ERROR_KIND_NOT_DIRECTORY,
        ),
        (
            "IOErrorKind.DirectoryNotEmpty",
            tags::IO_ERROR_KIND_DIRECTORY_NOT_EMPTY,
        ),
        ("IOErrorKind.InvalidUTF8", tags::IO_ERROR_KIND_INVALID_UTF8),
        (
            "IOErrorKind.InvalidInput",
            tags::IO_ERROR_KIND_INVALID_INPUT,
        ),
        ("IOErrorKind.Other", tags::IO_ERROR_KIND_OTHER),
        ("RoundingMode.HalfToEven", tags::ROUNDING_MODE_HALF_TO_EVEN),
        (
            "RoundingMode.HalfAwayFromZero",
            tags::ROUNDING_MODE_HALF_AWAY_FROM_ZERO,
        ),
        ("RoundingMode.TowardZero", tags::ROUNDING_MODE_TOWARD_ZERO),
        (
            "RoundingMode.TowardNegativeInfinity",
            tags::ROUNDING_MODE_TOWARD_NEGATIVE_INFINITY,
        ),
        (
            "RoundingMode.TowardPositiveInfinity",
            tags::ROUNDING_MODE_TOWARD_POSITIVE_INFINITY,
        ),
        ("ByteOrder.BigEndian", tags::BYTE_ORDER_BIG_ENDIAN),
        ("ByteOrder.LittleEndian", tags::BYTE_ORDER_LITTLE_ENDIAN),
        (
            "NetworkErrorKind.HostNotFound",
            tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND,
        ),
        (
            "NetworkErrorKind.ConnectionRefused",
            tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED,
        ),
        (
            "NetworkErrorKind.ConnectionReset",
            tags::NETWORK_ERROR_KIND_CONNECTION_RESET,
        ),
        (
            "NetworkErrorKind.TimedOut",
            tags::NETWORK_ERROR_KIND_TIMED_OUT,
        ),
        (
            "NetworkErrorKind.AddressInUse",
            tags::NETWORK_ERROR_KIND_ADDRESS_IN_USE,
        ),
        (
            "NetworkErrorKind.InvalidHTTPData",
            tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA,
        ),
        (
            "NetworkErrorKind.InvalidInput",
            tags::NETWORK_ERROR_KIND_INVALID_INPUT,
        ),
        (
            "NetworkErrorKind.PermissionDenied",
            tags::NETWORK_ERROR_KIND_PERMISSION_DENIED,
        ),
        ("NetworkErrorKind.Other", tags::NETWORK_ERROR_KIND_OTHER),
        (
            "IO.File.EntryKind.RegularFile",
            tags::FILE_ENTRY_KIND_REGULAR_FILE,
        ),
        (
            "IO.File.EntryKind.Directory",
            tags::FILE_ENTRY_KIND_DIRECTORY,
        ),
        (
            "IO.File.EntryKind.SymbolicLink",
            tags::FILE_ENTRY_KIND_SYMBOLIC_LINK,
        ),
        ("IO.File.EntryKind.Other", tags::FILE_ENTRY_KIND_OTHER),
        ("IO.File.WriteMode.Replace", tags::FILE_WRITE_MODE_REPLACE),
        ("IO.File.WriteMode.Append", tags::FILE_WRITE_MODE_APPEND),
        ("Json.Value.Null", tags::JSON_VALUE_NULL),
        ("Json.Value.Boolean", tags::JSON_VALUE_BOOLEAN),
        ("Json.Value.Integer", tags::JSON_VALUE_INTEGER),
        ("Json.Value.Float", tags::JSON_VALUE_FLOAT),
        ("Json.Value.String", tags::JSON_VALUE_STRING),
        ("Json.Value.Array", tags::JSON_VALUE_ARRAY),
        ("Json.Value.Object", tags::JSON_VALUE_OBJECT),
    ] {
        let id = out.stdlib(&format!("Benitoite.{name}")).expect(name);
        assert!(
            matches!(out.bindings.get(id).unwrap().kind, BindingKind::Ctor { tag: actual, .. } if actual == tag),
            "{name}"
        );
        let DeclSite::Node(node) = out.bindings.get(id).unwrap().decl else {
            panic!("table constructor")
        };
        assert_eq!(out.decls.get(node), Some(&id));
    }
    let write = out.stdlib("Benitoite.IO.Console.writeLine").unwrap();
    assert!(out.builtin_ops.get(write).is_some());
    assert!(matches!(
        out.bindings
            .get(out.stdlib("Benitoite.Map.fromList").unwrap())
            .unwrap()
            .kind,
        BindingKind::BuiltinFn(_)
    ));
    use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId};
    for (name, expected) in [
        (
            "Benitoite.Integer.Integer",
            BindingKind::BuiltinType(BuiltinTypeId::INTEGER),
        ),
        (
            "Benitoite.Unit",
            BindingKind::BuiltinType(BuiltinTypeId::UNIT),
        ),
        (
            "Benitoite.State",
            BindingKind::BuiltinEffect(BuiltinEffectId::STATE),
        ),
        (
            "Benitoite.IO.All",
            BindingKind::BuiltinEffect(BuiltinEffectId::IO_ALL),
        ),
    ] {
        let binding = out.bindings.get(out.stdlib(name).expect(name)).unwrap();
        assert_eq!(binding.kind, expected);
        assert_eq!(binding.decl, DeclSite::Table);
        if name == "Benitoite.Integer.Integer" {
            assert_eq!(
                load.modules.get(binding.module).unwrap().name.dotted(),
                "Benitoite.Integer"
            );
        }
    }
    let (_, again, _) = resolve_files(&[("main.bnt", &source)]);
    assert_eq!(
        out.bindings.iter().collect::<Vec<_>>(),
        again.bindings.iter().collect::<Vec<_>>()
    );
    assert_eq!(
        out.refs.iter().collect::<Vec<_>>(),
        again.refs.iter().collect::<Vec<_>>()
    );
    assert_eq!(
        out.decls.iter().collect::<Vec<_>>(),
        again.decls.iter().collect::<Vec<_>>()
    );
    assert_eq!(out.stdlib_names, again.stdlib_names);
    let (_, small, _) = resolve_files(&[("main.bnt", "function main() -> Unit\nend function")]);
    assert_eq!(small.stdlib("Benitoite.IO.Console.Write"), None);
}

#[test]
fn lookup_modules_constructors_and_prelude_shadowing() {
    let (load, out, _) = resolve_files(&[
        (
            "main.bnt",
            "import Lib.Text\nimport Lib.Geometry.Shape as GShape\nimport Benitoite.Unofficial.IO.Console\ndata Option\n Mine\nend data\nfunction main(x: Option, y: Benitoite.Option[Integer], zs: List[Integer]) -> Unit uses Console.Write\n Text.slug(\"Hello\")\n GShape.Shape.Circle(1.0)\n Benitoite.Option.Some(1)\n List.map(zs, lambda(z) return z end lambda)\nend function",
        ),
        (
            "Lib/Text.bnt",
            "public function slug(s: String) -> String\n return s\nend function",
        ),
        (
            "Lib/Geometry/Shape.bnt",
            "public data Shape\n Circle(Float)\n Square(Float)\nend data",
        ),
    ]);
    clean(&out);
    let f = function(&load, "main");
    let Some(TypeExpr::Named(own)) = &f.params[0].ty else {
        panic!()
    };
    let Some(TypeExpr::Named(prelude)) = &f.params[1].ty else {
        panic!()
    };
    assert_eq!(reference(&out, own.id).1.kind, BindingKind::Data);
    assert_eq!(
        reference(&out, own.id).1.module,
        load.modules
            .iter()
            .find(|m| m.kind == ModuleKind::Entry)
            .unwrap()
            .id
    );
    assert!(out.prelude_shadowed.get(own.id).is_some());
    assert_eq!(
        reference(&out, prelude.id).0,
        out.stdlib("Benitoite.Option.Option").unwrap()
    );
    let Some(TypeExpr::Named(list)) = &f.params[2].ty else {
        panic!()
    };
    assert!(matches!(
        reference(&out, list.id).1.kind,
        BindingKind::BuiltinType(_)
    ));
    let stmts = &f.body.as_ref().unwrap().stmts;
    let Stmt::Expr(Expr::Call(text_call)) = &stmts[0] else {
        panic!()
    };
    let Expr::Name(text) = text_call.callee.as_ref() else {
        panic!()
    };
    let (_, binding) = reference(&out, text.id);
    assert_eq!(binding.kind, BindingKind::Fn);
    assert_eq!(
        load.modules.get(binding.module).unwrap().name.dotted(),
        "Lib.Text"
    );
    assert!(
        matches!(binding.decl, DeclSite::Node(node) if out.decls.get(node) == out.refs.get(text.id))
    );
    for stmt in &stmts[1..3] {
        let Stmt::Expr(Expr::Call(call)) = stmt else {
            panic!()
        };
        let Expr::Name(name) = call.callee.as_ref() else {
            panic!()
        };
        assert!(matches!(
            reference(&out, name.id).1.kind,
            BindingKind::Ctor { .. }
        ));
    }
    let Stmt::Expr(Expr::Call(map)) = &stmts[3] else {
        panic!()
    };
    let Expr::Name(map) = map.callee.as_ref() else {
        panic!()
    };
    assert_eq!(
        reference(&out, map.id).0,
        out.stdlib("Benitoite.List.map").unwrap()
    );
    assert_eq!(out.main, out.decls.get(f.id).copied());
    for import in &entry(&load).imports {
        assert_eq!(out.refs.get(import.id), out.decls.get(import.id));
    }
}

#[test]
fn name_errors_have_the_failed_segment_and_appropriate_guidance() {
    for (source, code, segment, note) in [
        (
            "function f(s: String) -> Unit\n String.length(s)\nend function",
            DiagCode::E0303,
            "length",
            "byteLength",
        ),
        (
            "function f(o: Option[Integer]) -> Unit\n Option.unwrap(o)\nend function",
            DiagCode::E0303,
            "unwrap",
            "match",
        ),
        (
            "function f() -> Unit\n Nothing.x()\nend function",
            DiagCode::E0302,
            "Nothing",
            "",
        ),
        (
            "function f() -> Unit\n missing()\nend function",
            DiagCode::E0301,
            "missing",
            "",
        ),
        (
            "function f(x: State) -> Unit\nend function",
            DiagCode::E0314,
            "State",
            "uses",
        ),
        (
            "function f() -> Unit\n Integer()\nend function",
            DiagCode::E0304,
            "Integer",
            "",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(out.diagnostics.len(), 1, "{source}: {:?}", out.diagnostics);
        assert_eq!(primary(&load, &out, code), segment);
        if !note.is_empty() {
            assert!(
                {
                    let diagnostic = diagnostic(&out, code);
                    diagnostic.notes.iter().any(|n| n.contains(note))
                        || diagnostic
                            .helps
                            .iter()
                            .any(|help| help.message.contains(note))
                },
                "{:?}",
                out.diagnostics
            );
        }
    }
    let (load, out, _) = resolve_files(&[
        (
            "main.bnt",
            "import Lib.A\nfunction main() -> Unit\n A.B.x()\nend function",
        ),
        ("Lib/A.bnt", "import Lib.B"),
        ("Lib/B.bnt", "public function x() -> Unit\nend function"),
    ]);
    assert_eq!(primary(&load, &out, DiagCode::E0303), "B");
    assert!(
        diagnostic(&out, DiagCode::E0303)
            .notes
            .iter()
            .any(|n| n.contains("not visible"))
    );
    let (load, out, _) = resolve_files(&[
        (
            "main.bnt",
            "import Lib.A\nfunction main() -> Unit\n A.hidden()\nend function",
        ),
        ("Lib/A.bnt", "function hidden() -> Unit\nend function"),
    ]);
    assert_eq!(primary(&load, &out, DiagCode::E0330), "hidden");
    assert_eq!(out.diagnostics.len(), 1);
    assert!(!diagnostic(&out, DiagCode::E0330).helps.is_empty());
}

#[test]
fn hidden_standard_library_name_has_no_make_public_help() {
    // 標準ライブラリのソースは利用者が直せないので、`public` を付ける修正案を出さない（01-03「公開（初回リリース版）」）。
    let (load, out, _) = resolve_files(&[(
        "main.bnt",
        "function main() -> Unit
 bind _ <- List.mapFrom([1], lambda(v) return v end lambda, 0, [])
 return ()
end function",
    )]);
    assert_eq!(primary(&load, &out, DiagCode::E0330), "mapFrom");
    assert!(diagnostic(&out, DiagCode::E0330).helps.is_empty());
}

#[test]
fn imports_conflicts_and_whole_line_removal() {
    for (source, code, span) in [
        ("import Lib.A as X\nimport Lib.B as X", DiagCode::E0323, "X"),
        ("import Lib.A as Benitoite", DiagCode::E0325, "Benitoite"),
        ("import Lib.A\ndata A\n One\nend data", DiagCode::E0305, "A"),
    ] {
        let (load, out, _) =
            resolve_files(&[("main.bnt", source), ("Lib/A.bnt", ""), ("Lib/B.bnt", "")]);
        assert_eq!(primary(&load, &out, code), span);
        if code != DiagCode::E0325 {
            let fixed = apply(source, diagnostic(&out, code));
            let (_, fixed, _) =
                resolve_files(&[("main.bnt", &fixed), ("Lib/A.bnt", ""), ("Lib/B.bnt", "")]);
            clean(&fixed);
        }
    }
    for ending in ["\n", "\r\n", ""] {
        let source = format!("import Lib.A as First\n  import Lib.A as Second{ending}");
        let (load, out, _) = resolve_files(&[("main.bnt", &source), ("Lib/A.bnt", "")]);
        assert_eq!(
            primary(&load, &out, DiagCode::E0324),
            "import Lib.A as Second"
        );
        assert_eq!(
            apply(&source, diagnostic(&out, DiagCode::E0324)),
            "import Lib.A as First\n"
        );
    }
}

#[test]
fn repairs_for_missing_imports_constructors_and_uses_resolve() {
    for (source, code, expected) in [
        (
            "function f() -> Unit\n Console.writeLine(\"ok\")\nend function",
            DiagCode::E0332,
            "Console",
        ),
        (
            "  import Benitoite.Decimal\nfunction f() -> Unit\n Console.writeLine(\"ok\")\nend function",
            DiagCode::E0332,
            "Console",
        ),
        (
            "function f() -> Unit uses IO\nend function",
            DiagCode::E0333,
            "IO",
        ),
        (
            "function f() -> Unit uses Integer\nend function",
            DiagCode::E0315,
            "Integer",
        ),
        (
            "import Benitoite.Unofficial.IO.Console\nfunction f(x: function(function() -> Unit uses Console.Write, Integer) -> Unit) -> Unit\nend function",
            DiagCode::E0316,
            "Integer",
        ),
        (
            "function f() -> Unit\n Some(1)\nend function",
            DiagCode::E0331,
            "Some",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(out.diagnostics.len(), 1, "{source}: {:?}", out.diagnostics);
        assert_eq!(primary(&load, &out, code), expected);
        if code != DiagCode::E0315 {
            let fixed = apply(source, diagnostic(&out, code));
            let (_, fixed, _) = resolve_files(&[("main.bnt", &fixed)]);
            clean(&fixed);
        }
        if code == DiagCode::E0331 {
            assert_eq!(
                diagnostic(&out, code).helps[0].edits[0].replacement,
                "Option.Some"
            );
        }
    }
    let source = "data Shape\n Circle(Float)\n Square(Float)\nend data\nfunction f() -> Unit\n Circle(1.0)\nend function";
    let (load, out, _) = resolve_files(&[("main.bnt", source)]);
    assert_eq!(primary(&load, &out, DiagCode::E0331), "Circle");
    let fixed = apply(source, diagnostic(&out, DiagCode::E0331));
    assert!(fixed.contains("Shape.Circle"));
    let (_, out, _) = resolve_files(&[("main.bnt", &fixed)]);
    clean(&out);
}

#[test]
fn declaration_collisions_and_parameter_names() {
    for (source, code, span) in [
        (
            "data A\n One\nend data\nrecord A\n x: Integer\nend record",
            DiagCode::E0305,
            "A",
        ),
        (
            "function a() -> Unit\nend function\nconst a: Integer = 0",
            DiagCode::E0306,
            "a",
        ),
        (
            "function a() -> Unit\nend function\neffect E\n function a() -> Unit\nend effect",
            DiagCode::E0306,
            "a",
        ),
        (
            "function f[List]() -> Unit\nend function",
            DiagCode::E0313,
            "List",
        ),
        (
            "function f[Benitoite]() -> Unit\nend function",
            DiagCode::E0313,
            "Benitoite",
        ),
        (
            "function f[T, T]() -> Unit\nend function",
            DiagCode::E0312,
            "T",
        ),
        (
            "function f(x: Integer, x: Integer) -> Unit\nend function",
            DiagCode::E0310,
            "x",
        ),
        ("data A\n One\n One\nend data", DiagCode::E0309, "One"),
        (
            "record R\n x: Integer\n x: String\nend record",
            DiagCode::E0327,
            "x",
        ),
        (
            "data Benitoite\n One\nend data",
            DiagCode::E0325,
            "Benitoite",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(out.diagnostics.len(), 1, "{source}: {:?}", out.diagnostics);
        assert_eq!(primary(&load, &out, code), span);
    }
    let (load, out, _) = resolve_files(&[
        ("main.bnt", "import Lib.Log"),
        (
            "Lib/Log.bnt",
            "effect Log\n function write(x: String) -> Unit\nend effect",
        ),
    ]);
    assert_eq!(primary(&load, &out, DiagCode::E0326), "Log");
}

#[test]
fn public_contracts_include_nested_types_effects_and_supertraits() {
    for (source, segment, public_decl) in [
        (
            "data Hidden\n H\nend data\npublic function f(x: Hidden) -> Unit\nend function",
            "Hidden",
            "public data Hidden",
        ),
        (
            "data Hidden\n H\nend data\npublic function f(x: function(Hidden) -> Unit) -> Unit\nend function",
            "Hidden",
            "public data Hidden",
        ),
        (
            "effect Secret\n function write() -> Unit\nend effect\npublic function f() -> Unit uses Secret\nend function",
            "Secret",
            "public effect Secret",
        ),
        (
            "trait Hidden[T]\nend trait\npublic trait C[T: Hidden]\nend trait",
            "Hidden",
            "public trait Hidden",
        ),
        (
            "/// description\n@deprecated(\"old\")\ndata Hidden\n H\nend data\npublic function f(x: Hidden) -> Unit\nend function",
            "Hidden",
            "@deprecated(\"old\")\npublic data Hidden",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(primary(&load, &out, DiagCode::E0329), segment);
        let fixed = apply(source, diagnostic(&out, DiagCode::E0329));
        assert!(fixed.contains(public_decl), "{fixed}");
        let (_, fixed, _) = resolve_files(&[("main.bnt", &fixed)]);
        assert!(
            !fixed.diagnostics.iter().any(Diagnostic::is_error),
            "{:?}",
            fixed.diagnostics
        );
    }
}

#[test]
fn binding_keywords_and_implicit_binders() {
    for (source, code, span, hidden) in [
        (
            "function f(x: Integer) -> Unit\n bind x <- 2\nend function",
            DiagCode::E0334,
            "bind",
            "x",
        ),
        (
            "function f() -> Unit\n shadow y <- 2\nend function",
            DiagCode::E0335,
            "shadow",
            "",
        ),
        (
            "function f(a: Integer, p: Pair[Integer, Integer]) -> Unit\n shadow Pair(a, b) <- p\nend function",
            DiagCode::E0336,
            "shadow",
            "a",
        ),
        (
            "function f() -> Unit\n shadow _ <- 2\nend function",
            DiagCode::E0337,
            "shadow",
            "",
        ),
        (
            "function total(items: List[Integer]) -> Integer\n bind sum <- 0\n return List.fold(items, sum, lambda(sum, x) return sum + x end lambda)\nend function",
            DiagCode::E0338,
            "sum",
            "sum",
        ),
        (
            "function f() -> Unit\n with r = 1, r = 2 do\n r\n end with\nend function",
            DiagCode::E0338,
            "r",
            "r",
        ),
        (
            "function f(x: Integer) -> Unit\n match 1 with\n case x -> x\n end match\nend function",
            DiagCode::E0338,
            "x",
            "x",
        ),
        (
            "effect E\n function op(x: Integer) -> Unit\nend effect\nfunction f(x: Integer) -> Unit\n handle\n op(1)\n with\n case op(x) -> resume(())\n end handle\nend function",
            DiagCode::E0338,
            "x",
            "x",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(out.diagnostics.len(), 1, "{source}: {:?}", out.diagnostics);
        assert_eq!(primary(&load, &out, code), span);
        let d = diagnostic(&out, code);
        if !hidden.is_empty() {
            assert_eq!(snippet(&load, d.secondary[0].span), hidden);
        }
        if matches!(code, DiagCode::E0334 | DiagCode::E0335 | DiagCode::E0337) {
            let fixed = apply(source, d);
            let (_, out, _) = resolve_files(&[("main.bnt", &fixed)]);
            clean(&out);
        } else {
            assert!(d.helps.iter().all(|h| h.edits.is_empty()));
        }
    }
    for source in [
        "function normalize(text: String) -> String\n shadow text <- String.trim(text)\n shadow text <- String.replace(text, \"\\t\", \" \")\n bind words <- String.split(text, \" \")\n return String.join(words, \" \")\nend function",
        "function helper() -> Unit\nend function\nfunction f() -> Unit\n bind helper <- 1\nend function",
        "function _helper(_x: Integer) -> Integer\n shadow _x <- _x + 1\n return _x\nend function\nfunction main() -> Unit\n bind _ <- _helper(1)\nend function",
        "const maxRetries: Integer = 3\nfunction f(maxRetries: Integer) -> Unit\nend function\nfunction g() -> Unit\n bind maxRetries <- 2\nend function",
    ] {
        let (_, out, _) = resolve_files(&[("main.bnt", source)]);
        clean(&out);
    }
}

#[test]
fn shadow_rhs_and_scope_exit_refer_to_outer_binding() {
    let (load, out, _) = resolve_files(&[(
        "main.bnt",
        "function f(x: Integer) -> Integer\n if true then\n shadow x <- x + 1\n x\n end if\n return x\nend function",
    )]);
    clean(&out);
    let f = function(&load, "f");
    let param = *out.decls.get(f.params[0].id).unwrap();
    let body = f.body.as_ref().unwrap();
    let Stmt::Expr(Expr::If(branch)) = &body.stmts[0] else {
        panic!()
    };
    let Stmt::Bind(bind) = &branch.then_block.stmts[0] else {
        panic!()
    };
    let Expr::Binary(binary) = &bind.value else {
        panic!()
    };
    let Expr::Name(rhs) = binary.lhs.as_ref() else {
        panic!()
    };
    assert_eq!(reference(&out, rhs.id).0, param);
    let Pattern::Var(var) = &bind.pattern else {
        panic!()
    };
    let shadow = *out.decls.get(var.id).unwrap();
    assert_ne!(shadow, param);
    assert_eq!(
        out.bindings.get(shadow).unwrap().kind,
        BindingKind::Local(LocalKind::BindVar)
    );
    let Stmt::Expr(Expr::Name(inner)) = &branch.then_block.stmts[1] else {
        panic!()
    };
    assert_eq!(reference(&out, inner.id).0, shadow);
    let Stmt::Expr(Expr::Return(ret)) = &body.stmts[1] else {
        panic!()
    };
    let Expr::Name(outer) = ret.value.as_ref() else {
        panic!()
    };
    assert_eq!(reference(&out, outer.id).0, param);
}

#[test]
fn match_alternatives_share_bindings_and_rest_counts_as_variable() {
    let (load, out, _) = resolve_files(&[(
        "main.bnt",
        "function f(p: Pair[Integer, Integer]) -> Integer\n match p with\n case Pair(x, 0), Pair(0, x) -> return x\n end match\nend function",
    )]);
    clean(&out);
    let Stmt::Expr(Expr::Match(m)) = &function(&load, "f").body.as_ref().unwrap().stmts[0] else {
        panic!()
    };
    let arm = &m.arms[0];
    let Pattern::Ctor(first) = &arm.patterns[0] else {
        panic!()
    };
    let Pattern::Ctor(second) = &arm.patterns[1] else {
        panic!()
    };
    let Pattern::Var(first_x) = &first.args[0] else {
        panic!()
    };
    let Pattern::Var(second_x) = &second.args[1] else {
        panic!()
    };
    assert_eq!(out.refs.get(second_x.id), out.decls.get(first_x.id));
    assert!(out.decls.get(second_x.id).is_none());
    assert!(out.refs.get(first_x.id).is_none());
    assert_eq!(
        out.bindings
            .get(*out.decls.get(first_x.id).unwrap())
            .unwrap()
            .decl,
        DeclSite::Node(first_x.id)
    );
    for (source, code, segment) in [
        (
            "function f(o: Option[Integer]) -> Unit\n match o with\n case Option.Some(x), Option.None -> ()\n end match\nend function",
            DiagCode::E0604,
            "Option.None",
        ),
        (
            "function f(xs: List[Integer]) -> Unit\n match xs with\n case [x, ..x] -> ()\n end match\nend function",
            DiagCode::E0311,
            "x",
        ),
        (
            "function f(p: Pair[Integer, Integer]) -> Unit\n match p with\n case Pair(x, 0), Pair(0, y) -> ()\n end match\nend function",
            DiagCode::E0604,
            "Pair(0, y)",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(out.diagnostics.len(), 1, "{:?}", out.diagnostics);
        assert_eq!(primary(&load, &out, code), segment);
    }
}

#[test]
fn pattern_constant_guard_repair_is_conditional() {
    for (params, pattern, repair) in [
        ("x: Integer", "maxRetries", true),
        ("n: Integer", "maxRetries", false),
        ("x: Integer", "maxRetries if maxRetries > 0", false),
        ("x: Integer", "maxRetries, 0", false),
    ] {
        let source = format!(
            "const maxRetries: Integer = 3\nfunction f({params}) -> Unit\n match 1 with\n case {pattern} -> ()\n end match\nend function"
        );
        let (load, out, _) = resolve_files(&[("main.bnt", &source)]);
        assert_eq!(primary(&load, &out, DiagCode::E0603), "maxRetries");
        let d = diagnostic(&out, DiagCode::E0603);
        assert_eq!(d.helps.iter().any(|h| !h.edits.is_empty()), repair);
        if repair {
            let fixed = apply(&source, d);
            let (_, out, _) = resolve_files(&[("main.bnt", &fixed)]);
            clean(&out);
        }
    }
}

#[test]
fn declaration_cycles_and_implementation_methods() {
    for (source, code, name) in [
        ("type A = B\ntype B = List[A]", DiagCode::E0431, "A"),
        (
            "const a: Integer = b\nconst b: Integer = a",
            DiagCode::E0437,
            "a",
        ),
        (
            "trait A[T: B]\nend trait\ntrait B[T: A]\nend trait",
            DiagCode::E0703,
            "A",
        ),
        (
            "trait C[T]\n function run(x: T) -> Unit\n function run(x: T) -> Unit\nend trait",
            DiagCode::E0328,
            "run",
        ),
        (
            "trait C[T]\n function run(x: T) -> Unit\nend trait\nimplement C[Integer]\nend implement",
            DiagCode::E0707,
            "C",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source)]);
        assert_eq!(out.diagnostics.len(), 1, "{source}: {:?}", out.diagnostics);
        assert_eq!(primary(&load, &out, code), name);
        if matches!(code, DiagCode::E0431 | DiagCode::E0437 | DiagCode::E0703) {
            assert!(!diagnostic(&out, code).secondary.is_empty());
            assert!(diagnostic(&out, code).notes[0].contains(" -> "));
        }
    }
    let source = "trait C[T]\n function run(x: T) -> Unit\nend trait\nimplement C[Integer]\n function rn(x: Integer) -> Unit\n end function\nend implement";
    let (load, out, _) = resolve_files(&[("main.bnt", source)]);
    assert_eq!(primary(&load, &out, DiagCode::E0708), "rn");
    diagnostic(&out, DiagCode::E0707);
    let fixed = apply(source, diagnostic(&out, DiagCode::E0708));
    let (load, out, _) = resolve_files(&[("main.bnt", &fixed)]);
    clean(&out);
    let Item::Impl(implementation) = &entry(&load).decls[1].item else {
        panic!()
    };
    let f = &implementation.fns[0];
    assert!(matches!(
        reference(&out, f.id).1.kind,
        BindingKind::Method { .. }
    ));
    assert!(
        matches!(out.bindings.get(*out.decls.get(f.decl.id).unwrap()).unwrap().kind, BindingKind::ImplFn { impl_decl } if impl_decl == implementation.id)
    );
}

#[test]
fn deprecated_references_warn_outside_declaration() {
    let source = "@deprecated(\"use g\")\nfunction f(x: Integer) -> Integer\n return f(x)\nend function\nfunction g() -> Integer\n return f(1)\nend function";
    let (load, out, _) = resolve_files(&[("main.bnt", source)]);
    assert_eq!(out.diagnostics.len(), 1);
    assert_eq!(primary(&load, &out, DiagCode::W0301), "f");
    let d = diagnostic(&out, DiagCode::W0301);
    assert!(d.notes.iter().any(|n| n.contains("use g")));
    assert_eq!(snippet(&load, d.secondary[0].span), "f");
}

#[test]
fn independent_errors_survive_and_unresolved_imports_do_not_cascade() {
    // 読み込みが失敗した出力を意図して渡す。通常の呼び出し側はここに進まないが、
    // 解決器自身も決まらない import からの派生の誤りを抑える（F06「import」）。
    let (load, mut ids) = crate::modules::memfs::load_files(&[(
        "main.bnt",
        "import Missing.Module\nfunction f(x: Unknown) -> Unit\n Module.anything()\n absent()\nend function\nfunction g() -> Unit\n other()\nend function",
    )]);
    assert!(load.diagnostics.iter().any(Diagnostic::is_error));
    let out = super::resolve(&load.modules, &load.asts, &load.sources, &mut ids);
    assert_eq!(out.diagnostics.len(), 3, "{:?}", out.diagnostics);
    let names: Vec<_> = out
        .diagnostics
        .iter()
        .map(|d| snippet(&load, d.primary.as_ref().unwrap().span))
        .collect();
    assert_eq!(names, ["Unknown", "absent", "other"]);
    let Expr::Call(call) = &function(&load, "f")
        .body
        .as_ref()
        .unwrap()
        .stmts
        .iter()
        .find_map(|s| if let Stmt::Expr(e) = s { Some(e) } else { None })
        .unwrap()
    else {
        panic!()
    };
    let Expr::Name(name) = call.callee.as_ref() else {
        panic!()
    };
    assert!(out.refs.get(name.id).is_none());
}

#[test]
fn acceptance_fixtures_resolve() {
    for source in [
        include_str!("../../testdata/names/f06_normalize.bnt"),
        include_str!("../../testdata/names/f06_shadow_scope.bnt"),
        include_str!("../../testdata/names/f06_pattern_alternatives.bnt"),
        include_str!("../../testdata/names/f06_prelude_shadow.bnt"),
    ] {
        let (_, out, _) = resolve_files(&[("main.bnt", source)]);
        clean(&out);
    }
    let (_, out, _) = resolve_files(&[
        (
            "main.bnt",
            include_str!("../../testdata/names/f06_public_import/main.bnt"),
        ),
        (
            "Lib/Text.bnt",
            include_str!("../../testdata/names/f06_public_import/Lib/Text.bnt"),
        ),
    ]);
    clean(&out);
}

#[test]
fn type_and_effect_parameter_numbers_have_separate_indices_and_owners() {
    let source = "trait C[T]\n function apply[U, effect E, V, effect F](x: T, y: U, z: V) -> T uses E, F\nend trait\nimplement[Q] C[List[Q]]\n function apply[U, effect E, V, effect F](x: List[Q], y: U, z: V) -> List[Q] uses E, F\n return x\n end function\nend implement";
    let (load, out, _) = resolve_files(&[("main.bnt", source)]);
    clean(&out);
    let Item::Trait(trait_) = &entry(&load).decls[0].item else {
        panic!()
    };
    let method = &trait_.methods[0];
    let Item::Impl(implementation) = &entry(&load).decls[1].item else {
        panic!()
    };
    let f = &implementation.fns[0].decl;
    for (owner, params) in [(method.id, &method.type_params), (f.id, &f.type_params)] {
        for (param, index, effect) in [(0, 0, false), (1, 0, true), (2, 1, false), (3, 1, true)] {
            let id = *out.decls.get(params[param].id).unwrap();
            let expected = if effect {
                BindingKind::EffectVar { owner, index }
            } else {
                BindingKind::TypeParam { owner, index }
            };
            assert_eq!(out.bindings.get(id).unwrap().kind, expected);
        }
    }
    let q = &implementation.type_params[0];
    assert_eq!(
        out.bindings
            .get(*out.decls.get(q.id).unwrap())
            .unwrap()
            .kind,
        BindingKind::TypeParam {
            owner: implementation.id,
            index: 0
        }
    );
    let TypeExpr::Named(ret) = &f.ret else {
        panic!()
    };
    let TypeExpr::Named(q_ref) = &ret.args[0] else {
        panic!()
    };
    assert_eq!(out.refs.get(q_ref.id), out.decls.get(q.id));
}

#[test]
fn record_fields_and_deprecated_children_are_references() {
    let source = "@deprecated(\"use New\")\nrecord Old\n value: Integer\nend record\nfunction f() -> Unit\n bind p <- Old(value: 1, unknown: 2)\n match p with\n case Old(value: x, unknown: _) -> x\n end match\nend function";
    let (load, out, _) = resolve_files(&[("main.bnt", source)]);
    assert_eq!(out.diagnostics.len(), 4, "{:?}", out.diagnostics);
    assert!(
        out.diagnostics
            .iter()
            .all(|d| d.code == Some(DiagCode::W0301))
    );
    let Item::Record(record) = &entry(&load).decls[0].item else {
        panic!()
    };
    let field = *out.decls.get(record.fields[0].id).unwrap();
    let body = function(&load, "f").body.as_ref().unwrap();
    let Stmt::Bind(bind) = &body.stmts[0] else {
        panic!()
    };
    let Expr::Record(expr) = &bind.value else {
        panic!()
    };
    assert_eq!(out.refs.get(expr.fields[0].id), Some(&field));
    assert!(out.refs.get(expr.fields[1].id).is_none());
    let Stmt::Expr(Expr::Match(m)) = &body.stmts[1] else {
        panic!()
    };
    let Pattern::Record(p) = &m.arms[0].patterns[0] else {
        panic!()
    };
    assert_eq!(out.refs.get(p.fields[0].id), Some(&field));
    assert!(out.refs.get(p.fields[1].id).is_none());
}

#[test]
fn import_repair_preserves_leading_docs_attributes_and_utf8() {
    for prefix in [
        "/// explanation\n",
        "@deprecated(\"old\")\n",
        "// 日本語\r\n",
        "\u{feff}",
    ] {
        let source =
            format!("{prefix}function f() -> Unit\n Console.writeLine(\"ok\")\nend function");
        let (load, out, _) = resolve_files(&[("main.bnt", &source)]);
        assert_eq!(primary(&load, &out, DiagCode::E0332), "Console");
        let fixed = apply(&source, diagnostic(&out, DiagCode::E0332));
        let (_, out, _) = resolve_files(&[("main.bnt", &fixed)]);
        clean(&out);
    }
}

#[test]
fn typo_edits_require_a_unique_candidate() {
    for (decls, typo, fixed) in [
        (
            "function helper() -> Unit\nend function\n",
            "helpr",
            Some("helper"),
        ),
        (
            "function help() -> Unit\nend function\nfunction helm() -> Unit\nend function\n",
            "helx",
            None,
        ),
    ] {
        let source = format!("{decls}function main() -> Unit\n {typo}()\nend function");
        let (load, out, _) = resolve_files(&[("main.bnt", &source)]);
        assert_eq!(primary(&load, &out, DiagCode::E0301), typo);
        let d = diagnostic(&out, DiagCode::E0301);
        let edits: Vec<_> = d.helps.iter().flat_map(|h| &h.edits).collect();
        if let Some(expected) = fixed {
            assert_eq!(edits[0].replacement, expected);
            let fixed = apply(&source, d);
            let (_, out, _) = resolve_files(&[("main.bnt", &fixed)]);
            clean(&out);
        } else {
            assert!(edits.is_empty());
            assert!(d.helps[0].message.contains("`helm`, `help`"));
        }
    }
}

#[test]
fn uses_repair_only_closes_a_valid_effect_prefix_in_a_type_list() {
    for source in [
        "type Bad = function() -> Unit uses State, Integer",
        "type Bad = function((function() -> Unit uses State, Integer)) -> Unit",
        "type Bad = function(function() -> Unit uses Integer, String) -> Unit",
    ] {
        let (_, out, _) = resolve_files(&[("main.bnt", source)]);
        let d = diagnostic(&out, DiagCode::E0316);
        assert!(d.helps.iter().all(|h| h.edits.is_empty()), "{source}");
    }
    let source = "type Bad = function(function() -> Unit uses State, Integer, String) -> Unit";
    let (_, out, _) = resolve_files(&[("main.bnt", source)]);
    let ds: Vec<_> = out
        .diagnostics
        .iter()
        .filter(|d| d.code == Some(DiagCode::E0316))
        .collect();
    assert_eq!(ds.len(), 2);
    assert!(ds[1].helps.iter().all(|h| h.edits.is_empty()));
    let fixed = apply(source, ds[0]);
    let (_, out, _) = resolve_files(&[("main.bnt", &fixed)]);
    clean(&out);
}

#[test]
fn qualified_typo_candidates_follow_the_segment_position() {
    for (source, segment, other) in [
        (
            "import Lib.Geo\nfunction f() -> Unit\n Geo.Shpe.Circle(1.0)\nend function",
            "Shpe",
            "public data Shape\n Circle(Float)\nend data",
        ),
        (
            "function f(x: Benitoite.Integeer) -> Unit\nend function",
            "Integeer",
            "",
        ),
    ] {
        let (load, out, _) = resolve_files(&[("main.bnt", source), ("Lib/Geo.bnt", other)]);
        assert_eq!(primary(&load, &out, DiagCode::E0303), segment);
        let fixed = apply(source, diagnostic(&out, DiagCode::E0303));
        let (_, out, _) = resolve_files(&[("main.bnt", &fixed), ("Lib/Geo.bnt", other)]);
        clean(&out);
    }
}
