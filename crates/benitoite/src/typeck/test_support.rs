//! 後続の段のテストが使う実際の読み込み・名前解決・型検査（設計書 02-01「検査と実行の経路」）。
// テストの準備の失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing
)]
use super::{TypeckOutput, typecheck};
use crate::diag::Diagnostic;
use crate::modules::LoadOutput;
use crate::resolve::{ResolveOutput, test_support::resolve_files};
/// メモリ上のソースを本物の標準ライブラリとともに検査する。誤りのある前段の出力は後段へ渡さない（02-01「誤りが見つかったときの段の進め方」）。
pub(crate) fn check_files(
    files: &[(&str, &str)],
    require_main: bool,
) -> (LoadOutput, ResolveOutput, TypeckOutput, Vec<Diagnostic>) {
    // 名前解決のテストの補助は読み込みの成功を前提にする。失敗の場合も全診断を返すため、先に読み込む。
    let (loaded, _) = crate::modules::memfs::load_files(files);
    if loaded.diagnostics.iter().any(Diagnostic::is_error) {
        let diagnostics = loaded.diagnostics.clone();
        return (
            loaded,
            ResolveOutput::default(),
            TypeckOutput::default(),
            diagnostics,
        );
    }
    let (load, resolved, _) = resolve_files(files);
    let mut diagnostics = load.diagnostics.clone();
    diagnostics.extend(resolved.diagnostics.clone());
    let out = if diagnostics.iter().any(Diagnostic::is_error) {
        TypeckOutput::default()
    } else {
        let (out, diags) = typecheck(
            &load.modules,
            &load.asts,
            &load.sources,
            &resolved,
            require_main,
        );
        diagnostics.extend(diags);
        out
    };
    (load, resolved, out, diagnostics)
}

/// 未接続の名前付き引数の AST を用意する。型検査と脱糖は公開の入口を使う。
pub(crate) fn name_call_arguments(
    load: &mut LoadOutput,
    function: &str,
    labels: &[Option<&str>],
) -> crate::base::NodeId {
    use crate::syntax::ast::{Arg, ArgValue, Expr, Item, Name, NamedArg, Stmt};
    let f = load
        .asts
        .iter_mut()
        .flat_map(|m| &mut m.decls)
        .find_map(|d| {
            if let Item::Fn(f) = &mut d.item {
                (f.name.text == function).then_some(f)
            } else {
                None
            }
        })
        .expect("function");
    let Stmt::Expr(expr) = f
        .body
        .as_mut()
        .expect("body")
        .stmts
        .last_mut()
        .expect("statement")
    else {
        panic!("expression")
    };
    let expr = if let Expr::Return(r) = expr {
        &mut r.value
    } else {
        expr
    };
    let Expr::Call(call) = expr else {
        panic!("call")
    };
    assert_eq!(call.args.len(), labels.len());
    for (arg, label) in call.args.iter_mut().zip(labels) {
        if let Some(label) = label {
            let old = std::mem::replace(
                arg,
                Arg::Expr(Expr::Unit(crate::syntax::ast::UnitExpr {
                    id: call.id,
                    span: call.span,
                })),
            );
            let value = match old {
                Arg::Expr(e) => ArgValue::Expr(e),
                Arg::Placeholder(p) => ArgValue::Placeholder(p),
                Arg::Named(_) => panic!("already named"),
            };
            let span = match &value {
                ArgValue::Expr(e) => e.span(),
                ArgValue::Placeholder(p) => p.span,
            };
            *arg = Arg::Named(Box::new(NamedArg {
                name: Name {
                    text: (*label).into(),
                    span,
                },
                value,
            }));
        }
    }
    call.id
}

/// 通常の読み込みで標準モジュールを揃え、同じソース表と番号生成器に登録した
/// 対象の AST を差し替える。解析には本番の公開入口を使う。fixture の import は内部依存の自動追加の検査ではない。
pub(crate) fn check_die_source(
    source: &str,
) -> (LoadOutput, ResolveOutput, TypeckOutput, Vec<Diagnostic>) {
    use crate::base::{FileId, Source, SourceKind, SourceTable};
    use crate::syntax::{lexer, newline, parser::parse};
    let mut fixture =
        String::from("import Benitoite.Trait\nimport Benitoite.Unofficial.IO.Process\n");
    for line in source
        .lines()
        .filter(|line| line.trim_start().starts_with("import "))
    {
        if line.trim() != "import Benitoite.Trait"
            && line.trim() != "import Benitoite.Unofficial.IO.Process"
        {
            fixture.push_str(line);
            fixture.push('\n');
        }
    }
    let (mut load, mut ids) = crate::modules::memfs::load_files(&[("fixture.bnt", &fixture)]);
    assert!(
        !load.diagnostics.iter().any(Diagnostic::is_error),
        "{:?}",
        load.diagnostics
    );
    let mut sources = SourceTable::new();
    for (file, original) in load.sources.iter() {
        let replacement = if file == FileId(0) {
            Source::new(
                "die.bnt".into(),
                SourceKind::User,
                source.as_bytes().to_vec(),
            )
        } else {
            Source::new(
                original.name().into(),
                original.kind(),
                original.text().to_vec(),
            )
        };
        assert_eq!(sources.add(replacement), file);
    }
    load.sources = sources;
    let file = FileId(0);
    let lexed = lexer::lex(file, source.as_bytes());
    let parsed = parse(
        file,
        SourceKind::User,
        source.as_bytes(),
        newline::resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut ids,
    );
    let mut diagnostics = lexed.diagnostics;
    diagnostics.extend(parsed.diagnostics);
    let imports = parsed
        .module
        .imports
        .iter()
        .map(|import| {
            let path: Vec<_> = import
                .path
                .iter()
                .map(|n| n.text.clone())
                .filter(|n| n != "Unofficial")
                .collect();
            let target = load.modules.iter().find(|m| m.name.0 == path).map(|m| m.id);
            assert!(target.is_some(), "fixture must load {path:?}");
            crate::modules::ImportLink {
                decl: import.id,
                target,
            }
        })
        .collect();
    let entry = load
        .modules
        .modules
        .iter_mut()
        .find(|m| m.kind == crate::modules::ModuleKind::Entry)
        .unwrap();
    entry.imports = imports;
    load.asts[0] = parsed.module;
    load.comments[0] = parsed.comments;
    if diagnostics.iter().any(Diagnostic::is_error) {
        return (
            load,
            ResolveOutput::default(),
            TypeckOutput::default(),
            diagnostics,
        );
    }
    let resolved = crate::resolve::resolve(&load.modules, &load.asts, &load.sources, &mut ids);
    diagnostics.extend(resolved.diagnostics.clone());
    let out = if diagnostics.iter().any(Diagnostic::is_error) {
        TypeckOutput::default()
    } else {
        let (out, diags) = typecheck(&load.modules, &load.asts, &load.sources, &resolved, false);
        diagnostics.extend(diags);
        out
    };
    (load, resolved, out, diagnostics)
}
