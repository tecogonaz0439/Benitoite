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
