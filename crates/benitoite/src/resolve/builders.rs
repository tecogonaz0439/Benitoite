//! 通常の宣言と区別する標準専用名と局所の捕捉検査（設計書 01-06「関数内の構築器」）。

use super::BindingKind;
use super::collect::Resolver;
use super::lookup::Ctx;
use crate::base::{BindingId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::modules::ModuleKind;
use crate::syntax::ast::*;

/// 解決済みの局所束縛を識別する。脱糖・交換でも通常の局所位置を共有する。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuilderId(pub BindingId);

/// 専用操作。通常の関数値を表さない。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BuilderOp {
    Append,
    AppendAll,
    Copy,
    Length,
}

/// 専用契約は標準の通常宣言とは別に登録する。
pub(crate) struct BuilderContract {
    pub name: &'static str,
    pub op: Option<BuilderOp>,
    pub labels: &'static [&'static str],
    pub result: &'static str,
}

pub(crate) const STRING_OPERATIONS: &[BuilderContract] = &[
    BuilderContract {
        name: "new",
        op: None,
        labels: &[],
        result: "StringBuilder",
    },
    BuilderContract {
        name: "append",
        op: Some(BuilderOp::Append),
        labels: &["builder", "text"],
        result: "Unit",
    },
    BuilderContract {
        name: "appendAll",
        op: Some(BuilderOp::AppendAll),
        labels: &["builder", "texts"],
        result: "Unit",
    },
    BuilderContract {
        name: "copy",
        op: Some(BuilderOp::Copy),
        labels: &["builder"],
        result: "String",
    },
    BuilderContract {
        name: "byteLength",
        op: Some(BuilderOp::Length),
        labels: &["builder"],
        result: "Integer",
    },
];

pub(crate) const LIST_OPERATIONS: &[BuilderContract] = &[
    BuilderContract {
        name: "new",
        op: None,
        labels: &[],
        result: "ListBuilder[T]",
    },
    BuilderContract {
        name: "append",
        op: Some(BuilderOp::Append),
        labels: &["builder", "value"],
        result: "Unit",
    },
    BuilderContract {
        name: "appendAll",
        op: Some(BuilderOp::AppendAll),
        labels: &["builder", "values"],
        result: "Unit",
    },
    BuilderContract {
        name: "copy",
        op: Some(BuilderOp::Copy),
        labels: &["builder"],
        result: "List[T]",
    },
    BuilderContract {
        name: "length",
        op: Some(BuilderOp::Length),
        labels: &["builder"],
        result: "Integer",
    },
];
pub(crate) const BYTES_OPERATIONS: &[BuilderContract] = &[
    BuilderContract {
        name: "new",
        op: None,
        labels: &[],
        result: "BytesBuilder",
    },
    BuilderContract {
        name: "append",
        op: Some(BuilderOp::Append),
        labels: &["builder", "value"],
        result: "Unit",
    },
    BuilderContract {
        name: "appendAll",
        op: Some(BuilderOp::AppendAll),
        labels: &["builder", "bytes"],
        result: "Unit",
    },
    BuilderContract {
        name: "copy",
        op: Some(BuilderOp::Copy),
        labels: &["builder"],
        result: "Bytes",
    },
    BuilderContract {
        name: "length",
        op: Some(BuilderOp::Length),
        labels: &["builder"],
        result: "Integer",
    },
];
/// 名前解決時の分類。List の通常の要素型は型検査で確定する。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BuilderClass {
    String,
    List,
    Bytes,
}

impl BuilderClass {
    pub(crate) fn operations(self) -> &'static [BuilderContract] {
        match self {
            Self::String => STRING_OPERATIONS,
            Self::List => LIST_OPERATIONS,
            Self::Bytes => BYTES_OPERATIONS,
        }
    }
    pub(crate) fn module(self) -> &'static str {
        match self {
            Self::String => "StringBuilder",
            Self::List => "ListBuilder",
            Self::Bytes => "BytesBuilder",
        }
    }
    pub(crate) fn named(name: &str) -> Option<Self> {
        match name {
            "StringBuilder" => Some(Self::String),
            "ListBuilder" => Some(Self::List),
            "BytesBuilder" => Some(Self::Bytes),
            _ => None,
        }
    }
}

/// 構築器の宣言と捕捉境界。通常の型・値は載せない。
#[derive(Clone, Copy, Debug)]
pub struct BuilderDecl {
    pub class: BuilderClass,
    pub bind: NodeId,
    pub id: BuilderId,
    pub span: Span,
    pub boundary: NodeId,
}

/// 専用の直接呼び出し。通常引数のソース順は AST に保つ。
#[derive(Clone, Copy, Debug)]
pub struct BuilderCall {
    pub class: BuilderClass,
    pub builder: Option<BuilderId>,
    pub op: BuilderOp,
}

#[derive(Clone, Copy)]
enum Special {
    Class(BuilderClass),
    Operation(BuilderClass, Option<BuilderOp>),
}

impl Resolver<'_> {
    // 綴りだけで特別扱いせず、既存 import が解決した標準 ModuleId と照合する。
    fn builder_special(&self, ctx: &Ctx, path: &[Name]) -> Option<Special> {
        let (first, rest) = path.split_first()?;
        if ctx.local(&first.text).is_some() {
            return None;
        }
        let id = self.upper(ctx, &first.text, true)?;
        let BindingKind::Module(module) = self.out.bindings.get(id)?.kind else {
            return None;
        };
        let info = self.modules.get(module)?;
        if info.kind != ModuleKind::Stdlib || info.name.0.first()?.as_str() != "Benitoite" {
            return None;
        }
        let class = BuilderClass::named(info.name.0.get(1)?)?;
        match rest {
            [] => Some(Special::Class(class)),
            [name] => class
                .operations()
                .iter()
                .find(|contract| contract.name == name.text)
                .map(|contract| Special::Operation(class, contract.op)),
            _ => None,
        }
    }

    pub(super) fn builder_name(&mut self, ctx: &Ctx, node: NodeId, path: &[Name]) -> bool {
        if let Some(special) = self.builder_special(ctx, path) {
            if let (Some(first), Some(last)) = (path.first(), path.last()) {
                let (code, help) = match special {
                    Special::Class(_) => (DiagCode::E0464, "copy"),
                    Special::Operation(_, _) => (DiagCode::E0466, "direct"),
                };
                self.out.diagnostics.push(
                    DiagBuilder::new(code)
                        .primary(first.span.to(last.span))
                        .help(help)
                        .build(),
                );
            }
            return true;
        }
        if let [name] = path
            && let Some(id) = ctx.local(&name.text)
            && self.out.builder_decls.get(id).is_some()
        {
            self.builder_target(ctx, node, name, id, false);
            return true;
        }
        false
    }

    fn builder_target(
        &mut self,
        ctx: &Ctx,
        node: NodeId,
        name: &Name,
        id: BindingId,
        target: bool,
    ) {
        let Some(decl) = self.out.builder_decls.get(id) else {
            return;
        };
        let current = ctx.builder_boundary.map_or(ctx.owner, |b| b.0);
        if decl.boundary != current {
            let mut d = DiagBuilder::new(DiagCode::E0465)
                .primary(name.span)
                .secondary(decl.span, "declared")
                .help("copy");
            if let Some((_, label, span)) = ctx.builder_boundary {
                d = d.arg("boundary", label).secondary(span, "boundary");
            }
            self.out.diagnostics.push(d.build());
        } else if !target {
            self.out.diagnostics.push(
                DiagBuilder::new(DiagCode::E0464)
                    .primary(name.span)
                    .help("copy")
                    .build(),
            );
        }
        self.out.refs.insert(node, id);
    }

    pub(super) fn builder_bind(&mut self, ctx: &mut Ctx, stmt: &BindStmt) -> Option<BuilderClass> {
        let Some(TypeExpr::Named(t)) = &stmt.ty else {
            return None;
        };
        let Some(Special::Class(class)) = self.builder_special(ctx, &t.path) else {
            return None;
        };
        for arg in &t.args {
            self.ty(ctx, arg);
        }
        let valid = matches!((&stmt.pattern, &stmt.value),
            (Pattern::Var(_), Expr::Call(c))
                if t.args.len() == usize::from(class == BuilderClass::List) && matches!(c.callee.as_ref(), Expr::Name(n)
                    if matches!(self.builder_special(ctx, &n.path), Some(Special::Operation(other, None)) if other == class)));
        if !valid {
            self.out.diagnostics.push(
                DiagBuilder::new(DiagCode::E0463)
                    .primary(stmt.span)
                    .help("bind")
                    .build(),
            );
        } else if let Expr::Call(c) = &stmt.value
            && !c.args.is_empty()
        {
            if c.args.iter().any(|a| a.placeholder().is_some()) {
                self.out.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0466)
                        .primary(c.span)
                        .help("direct")
                        .build(),
                );
            }
            for arg in &c.args {
                if let Some(e) = arg.expr() {
                    self.expr(ctx, e);
                }
            }
        }
        Some(class)
    }

    #[inline(never)]
    pub(super) fn builder_expr(&mut self, ctx: &mut Ctx, expr: &Expr) -> bool {
        if let Expr::Pipe(pipe) = expr {
            let mut rhs = pipe.rhs.as_ref();
            loop {
                if let Expr::Paren(p) = rhs {
                    rhs = &p.inner;
                } else if let Expr::Call(c) = rhs {
                    rhs = &c.callee;
                } else {
                    break;
                }
            }
            if let Expr::Name(n) = rhs
                && matches!(
                    self.builder_special(ctx, &n.path),
                    Some(Special::Operation(_, _))
                )
            {
                self.out.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0466)
                        .primary(pipe.span)
                        .help("direct")
                        .build(),
                );
                return true;
            }
        }
        let Expr::Call(call) = expr else { return false };
        let Expr::Name(callee) = call.callee.as_ref() else {
            return false;
        };
        let Some(Special::Operation(class, op)) = self.builder_special(ctx, &callee.path) else {
            return false;
        };
        let Some(op) = op else {
            let holes = call.args.iter().any(|a| a.placeholder().is_some());
            let (code, help) = if holes {
                (DiagCode::E0466, "direct")
            } else {
                (DiagCode::E0463, "bind")
            };
            self.out
                .diagnostics
                .push(DiagBuilder::new(code).primary(call.span).help(help).build());
            return true;
        };
        if call.args.iter().any(|a| a.placeholder().is_some()) {
            self.out.diagnostics.push(
                DiagBuilder::new(DiagCode::E0466)
                    .primary(call.span)
                    .help("direct")
                    .build(),
            );
            return true;
        }
        let mut builder = None;
        for (index, arg) in call.args.iter().enumerate() {
            let Some(e) = arg.expr() else { continue };
            let target = match arg {
                Arg::Named(a) => a.name.text == "builder",
                Arg::Expr(_) => index == 0,
                Arg::Placeholder(_) => false,
            };
            if target
                && let Expr::Name(n) = e
                && let [name] = n.path.as_slice()
                && let Some(id) = ctx.local(&name.text)
                && self.out.builder_decls.get(id).is_some()
            {
                self.builder_target(ctx, n.id, name, id, true);
                builder = Some(BuilderId(id));
            } else {
                self.expr(ctx, e);
            }
        }
        // 引数名・個数は型検査の既存の契約検査へ渡す。対象なしもそこで回復する。
        self.out
            .builder_calls
            .insert(call.id, BuilderCall { class, builder, op });
        true
    }
}
