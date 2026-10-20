//! 解決済みの位置の式を型検査前に通常レコードへ展開する
//! （設計書 02-04「位置の式の事前展開」）。

use crate::base::{BindingId, FileId, IdGen, Source, SourceTable};
use crate::cli::tools::doc_examples::SourceMap;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::*;

/// docの仮想入口から元コメントへの位置対応。内部生成範囲は呼び出しにしない。
#[derive(Clone, Copy)]
pub(crate) struct DocOrigin<'a> {
    pub source: &'a Source,
    pub map: &'a SourceMap,
}

enum Pending<'a> {
    Expr(&'a mut Expr, bool),
    If(&'a mut IfExpr),
}

fn block<'a>(pending: &mut Vec<Pending<'a>>, body: &'a mut Block) {
    for statement in &mut body.stmts {
        let expr = match statement {
            Stmt::Expr(e) => e,
            Stmt::Bind(b) => &mut b.value,
            Stmt::Error(_) => continue,
        };
        pending.push(Pending::Expr(expr, true));
    }
}

fn standard(resolved: &ResolveOutput, expr: &Expr, binding: BindingId) -> bool {
    matches!(expr, Expr::Name(n) if resolved.refs.get(n.id) == Some(&binding))
}

/// 新しいノードは共有の番号源から振り、通常のレコードとリテラルだけを後段へ渡す。
pub(super) fn expand(
    modules: &ModuleTable,
    asts: &mut [Module],
    sources: &SourceTable,
    resolved: &mut ResolveOutput,
    ids: &mut IdGen,
    origin: Option<DocOrigin<'_>>,
) -> Vec<Diagnostic> {
    let Some(here) = resolved.stdlib("Benitoite.SourceLocation.here") else {
        return vec![];
    };
    let Some(location) = resolved.stdlib("Benitoite.SourceLocation.Location") else {
        return vec![];
    };
    let mut diagnostics = Vec::new();
    for (index, ast) in asts.iter_mut().enumerate() {
        let mut pending = Vec::new();
        for decl in &mut ast.decls {
            match &mut decl.item {
                Item::Fn(f) => {
                    if let Some(body) = &mut f.body {
                        block(&mut pending, body);
                    }
                }
                Item::Const(c) => pending.push(Pending::Expr(&mut c.value, true)),
                Item::Impl(i) => {
                    for f in &mut i.fns {
                        if let Some(body) = &mut f.decl.body {
                            block(&mut pending, body);
                        }
                    }
                }
                Item::Data(_)
                | Item::Alias(_)
                | Item::ExternalType(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Error(_) => {}
            }
        }
        while let Some(next) = pending.pop() {
            let (expr, direct) = match next {
                Pending::Expr(expr, direct) => (expr, direct),
                Pending::If(e) => {
                    pending.push(Pending::Expr(&mut e.cond, true));
                    block(&mut pending, &mut e.then_block);
                    match &mut e.else_branch {
                        Some(ElseBranch::Block(b)) => block(&mut pending, b),
                        Some(ElseBranch::If(e)) => pending.push(Pending::If(e)),
                        None => {}
                    }
                    continue;
                }
            };
            if let Expr::Call(c) = expr
                && standard(resolved, &c.callee, here)
                && direct
                && c.args.is_empty()
            {
                let span = c.span;
                let (source, point) = if span.file == FileId(0)
                    && let Some(origin) = origin
                {
                    (
                        Some(origin.source),
                        origin.map.map_span(FileId(0), span).start,
                    )
                } else {
                    (sources.get(span.file), span.start)
                };
                if let Some(source) = source {
                    let lc = source.line_col(point);
                    // 診断の依存識別は保つ。絶対指定の入口だけはホストのパスを埋め込まない
                    // （設計書 01-03「位置の式」）。
                    let path = std::path::Path::new(source.name());
                    let file = if path.is_absolute() {
                        modules
                            .modules
                            .get(index)
                            .filter(|m| !m.name.0.is_empty())
                            .map(|m| format!("{}.bnt", m.name.0.join("/")))
                            .unwrap_or_else(|| {
                                path.file_name()
                                    .unwrap_or_default()
                                    .to_string_lossy()
                                    .into_owned()
                            })
                    } else {
                        source.name().to_owned()
                    };
                    let mut fields = Vec::new();
                    for (name, lit) in [
                        ("file", Literal::Str(file)),
                        (
                            "line",
                            Literal::Int {
                                radix: 10,
                                digits: lc.line.to_string(),
                            },
                        ),
                        (
                            "column",
                            Literal::Int {
                                radix: 10,
                                digits: lc.column.to_string(),
                            },
                        ),
                    ] {
                        let id = ids.node();
                        if let Some(binding) =
                            resolved.stdlib(&format!("Benitoite.SourceLocation.Location.{name}"))
                        {
                            resolved.refs.insert(id, binding);
                        }
                        fields.push(FieldArg {
                            id,
                            span,
                            name: Name {
                                text: name.into(),
                                span,
                            },
                            value: Expr::Lit(LitExpr {
                                id: ids.node(),
                                span,
                                lit,
                            }),
                        });
                    }
                    resolved.refs.insert(c.id, location);
                    *expr = Expr::Record(RecordExpr {
                        id: c.id,
                        span,
                        path: vec![Name {
                            text: "Location".into(),
                            span,
                        }],
                        base: None,
                        fields,
                    });
                }
                continue;
            }
            if standard(resolved, expr, here)
                || matches!(expr, Expr::Call(c) if !direct && standard(resolved, &c.callee, here))
            {
                diagnostics.push(
                    DiagBuilder::new(DiagCode::E0467)
                        .primary(expr.span())
                        .help("direct")
                        .build(),
                );
                *expr = Expr::Error(ErrorNode {
                    id: expr.id(),
                    span: expr.span(),
                });
                continue;
            }
            match expr {
                Expr::Call(c) => {
                    // 余分な引数は通常の個数・ラベル診断へ渡す。callee自体の値化とは扱わない。
                    if !standard(resolved, &c.callee, here) {
                        pending.push(Pending::Expr(&mut c.callee, true));
                    }
                    for arg in &mut c.args {
                        match arg {
                            Arg::Expr(e) => pending.push(Pending::Expr(e, true)),
                            Arg::Named(a) => {
                                if let ArgValue::Expr(e) = &mut a.value {
                                    pending.push(Pending::Expr(e, true));
                                }
                            }
                            Arg::Placeholder(_) => {}
                        }
                    }
                }
                Expr::Pipe(e) => {
                    pending.push(Pending::Expr(&mut e.lhs, true));
                    pending.push(Pending::Expr(&mut e.rhs, false));
                }
                Expr::Paren(e) => pending.push(Pending::Expr(&mut e.inner, direct)),
                Expr::Interp(e) => {
                    for segment in &mut e.segments {
                        pending.push(Pending::Expr(&mut segment.expr, true));
                    }
                }
                Expr::List(e) => {
                    for element in &mut e.elems {
                        pending.push(Pending::Expr(
                            match element {
                                ListElem::Expr(e) => e,
                                ListElem::Spread(e) => &mut e.expr,
                            },
                            true,
                        ));
                    }
                }
                Expr::Record(e) => {
                    if let Some(base) = &mut e.base {
                        pending.push(Pending::Expr(base, true));
                    }
                    for field in &mut e.fields {
                        pending.push(Pending::Expr(&mut field.value, true));
                    }
                }
                Expr::Binary(e) => {
                    pending.push(Pending::Expr(&mut e.lhs, true));
                    pending.push(Pending::Expr(&mut e.rhs, true));
                }
                Expr::Unary(e) => pending.push(Pending::Expr(&mut e.operand, true)),
                Expr::If(e) => pending.push(Pending::If(e)),
                Expr::Match(e) => {
                    pending.push(Pending::Expr(&mut e.scrutinee, true));
                    for arm in &mut e.arms {
                        if let Some(guard) = &mut arm.guard {
                            pending.push(Pending::Expr(guard, true));
                        }
                        block(&mut pending, &mut arm.body);
                    }
                }
                Expr::Lambda(e) => block(&mut pending, &mut e.body),
                Expr::Return(e) => pending.push(Pending::Expr(&mut e.value, true)),
                Expr::Try(e) => {
                    pending.push(Pending::Expr(&mut e.value, true));
                    if let TryAction::Die {
                        message: Some(message),
                        ..
                    } = &mut e.action
                    {
                        pending.push(Pending::Expr(message, true));
                    }
                }
                Expr::Block(e) => block(&mut pending, &mut e.body),
                Expr::Lazy(e) => block(&mut pending, &mut e.body),
                Expr::With(e) => {
                    for bind in &mut e.binds {
                        pending.push(Pending::Expr(&mut bind.value, true));
                    }
                    block(&mut pending, &mut e.body);
                }
                Expr::Handle(e) => {
                    block(&mut pending, &mut e.body);
                    for clause in &mut e.clauses {
                        block(&mut pending, &mut clause.body);
                    }
                }
                Expr::Resume(e) => pending.push(Pending::Expr(&mut e.value, true)),
                Expr::Lit(_) | Expr::Unit(_) | Expr::Name(_) | Expr::Error(_) => {}
            }
        }
    }
    diagnostics
}
