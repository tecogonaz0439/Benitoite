//! 移行の確認用に try の入力範囲と処置、囲む契約を公開の解析境界から読む。
//! AST と物理位置は設計書 02-03「AST」、01-02 の try の規則に従う。
use benitoite::{
    base::{FileId, IdGen, SourceKind, Span},
    pipeline::{self, CheckOptions, CheckedProgram},
    syntax::{ast::*, lexer, newline, parser},
    types::{EffectName, EffectSet, Ty, TyNames},
};
use serde_json::{Value, json};
use std::io::{self, Read};
use std::path::Path;

fn text(source: &str, span: Span) -> &str {
    source
        .get(span.start.0 as usize..span.end.0 as usize)
        .unwrap_or_default()
}

// 型検査と同じASTのIDだけを参照する。別の解析で得たNodeIdを型表へ渡さない。
fn effect_names(
    effects: &EffectSet,
    checked: &CheckedProgram,
    type_params: &[String],
    effect_params: &[String],
) -> Option<Vec<String>> {
    let names = TyNames {
        bindings: &checked.resolved.bindings,
        adts: &checked.types.adts,
        effects: &checked.types.effects,
        type_params,
        effect_params,
    };
    let mut out = Vec::new();
    for effect in &effects.names {
        out.push(match effect {
            EffectName::Builtin(id, ix) if ix == &benitoite::types::builtin::RangeIndex::TOP => {
                benitoite::types::builtin::effect_name(*id)?
            }
            EffectName::User(id, ix) if ix == &benitoite::types::builtin::RangeIndex::TOP => {
                checked.types.effects.get(*id)?.display_name.clone()
            }
            EffectName::Builtin(..) | EffectName::User(..) => return None,
        });
    }
    for failure in &effects.failures {
        out.push(format!("Failure.Fail[{}]", failure.show(&names)));
    }
    for var in &effects.vars {
        out.push(effect_params.get(usize::try_from(var.0).ok()?)?.clone());
    }
    out.sort();
    out.dedup();
    Some(out)
}

fn function_owner(
    f: &FnDecl,
    source: &str,
    public: bool,
    file_uses: Option<&UsesList>,
    path: &str,
    checked: Option<&CheckedProgram>,
) -> Value {
    let effective = checked.and_then(|c| {
        let binding = *c.resolved.decls.get(f.id)?;
        let scheme = c.types.decl_types.get(binding)?;
        effect_names(
            &scheme.effects,
            c,
            &scheme
                .type_params
                .iter()
                .map(|p| p.name.clone())
                .collect::<Vec<_>>(),
            &scheme.effect_params,
        )
    });
    json!({"kind":"function", "name":f.name.text, "public":public,
        "return_type":text(source, f.ret.span()),
        "uses":f.uses.as_ref().map(|u| text(source, u.span)).unwrap_or_default(),
        "file_uses":file_uses.map(|u|json!({"text":text(source, u.span),
            "span":{"path":path,"start":u.span.start.0,"end":u.span.end.0}})),
        "effective_effects":effective})
}

enum Work<'a> {
    Expr(&'a Expr, Value),
    Block(&'a Block, Value),
    If(&'a IfExpr, Value),
}

fn inventory(request: &Value) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
    let source = request
        .get("source")
        .and_then(Value::as_str)
        .ok_or("source")?;
    let path = request.get("path").and_then(Value::as_str).ok_or("path")?;
    let stdlib_path = path.strip_prefix("crates/benitoite/src/prelude/stdlib/");
    let kind = if stdlib_path.is_some() {
        SourceKind::Prelude
    } else {
        SourceKind::User
    };
    let parse = |s: &str| {
        let lx = lexer::lex(FileId(0), s.as_bytes());
        let result = parser::parse(
            FileId(0),
            kind,
            s.as_bytes(),
            newline::resolve_newlines(lx.tokens),
            lx.comments,
            lx.pending,
            &mut IdGen::new(),
        );
        let errors: Vec<_> = lx
            .diagnostics
            .iter()
            .chain(&result.diagnostics)
            .filter(|d| d.is_error())
            .map(|d| format!("{:?}", d.code))
            .collect();
        (result.module, errors)
    };
    let (mut module, mut parse_errors) = parse(source);
    // 説明用の式も位置を調べるが、仮の契約で型検査を通して編集可能にはしない。
    let prefix = "function inventoryFragment() -> Unit\n";
    let wrapped = format!("{prefix}{source}\nend function\n");
    let mut offset = 0;
    let mut parsed_source = source;
    let mut fragment = false;
    if !parse_errors.is_empty() {
        let (candidate, errors) = parse(&wrapped);
        if errors.is_empty() {
            module = candidate;
            parse_errors = errors;
            offset = u32::try_from(prefix.len())?;
            parsed_source = &wrapped;
            fragment = true;
        }
    }
    let options = CheckOptions {
        require_main: false,
        deny_warnings: false,
    };
    let checked = if fragment || !parse_errors.is_empty() {
        None
    } else if let Some(module_path) = stdlib_path {
        let name = module_path.trim_end_matches(".bnt");
        if let Some(m) = benitoite::prelude::STDLIB
            .iter()
            .find(|m| m.path.join("/") == name && m.text == source)
        {
            let namespace = if m.unofficial {
                "Benitoite.Unofficial"
            } else {
                "Benitoite"
            };
            Some(pipeline::check_text(
                "main.bnt",
                format!("import {namespace}.{}\n", m.path.join(".")).as_bytes(),
                options,
            ))
        } else {
            None
        }
    } else if request.get("direct").and_then(Value::as_bool) == Some(true) {
        // 渡された内容と実ファイルの一致を検証してから依存モジュールも読む。
        if std::fs::read(path)? != source.as_bytes() {
            return Err("source changed before check".into());
        }
        Some(pipeline::check_path(Path::new(path), options).map_err(|e| format!("{e:?}"))?)
    } else {
        Some(pipeline::check_text("main.bnt", source.as_bytes(), options))
    };
    let typed = checked.as_ref().is_some_and(|c| c.program.is_some());
    let check_codes: Vec<_> = checked
        .as_ref()
        .map(|c| {
            c.diagnostics
                .iter()
                .filter(|d| d.is_error())
                .map(|d| format!("{:?}", d.code))
                .collect()
        })
        .unwrap_or_default();
    // 元のソースと一致する検査済みモジュールへ切り替え、宣言と式の型表のIDをそろえる。
    let program = checked.as_ref().and_then(|c| c.program.as_ref());
    let checked_module = program.and_then(|c| {
        c.asts.iter().find(|m| {
            if stdlib_path.is_none() && checked.as_ref().and_then(|r| r.entry) != Some(m.file) {
                return false;
            }
            checked
                .as_ref()
                .and_then(|r| r.sources.get(m.file))
                .is_some_and(|s| s.text() == source.as_bytes())
        })
    });
    let module = checked_module.unwrap_or(&module);
    let program = checked_module.and(program);
    let file_uses = module.file_uses.as_ref().map(|u| {
        json!({"text":text(parsed_source,u.span),
        "span":{"path":path,"start":u.span.start.0,"end":u.span.end.0}})
    });
    let mut work = vec![];
    for decl in &module.decls {
        let public = decl.public.is_some() || decl.package.is_some();
        match &decl.item {
            Item::Fn(f) => {
                if let Some(body) = &f.body {
                    work.push(Work::Block(body, function_owner(f, parsed_source, public, module.file_uses.as_ref(), path, program)));
                }
            }
            Item::Impl(i) => {
                for f in &i.fns {
                    if let Some(body) = &f.decl.body {
                        let mut owner = function_owner(&f.decl, parsed_source, public, module.file_uses.as_ref(), path, program);
                        if let Some(kind) = owner.get_mut("kind") {
                            *kind = json!("implementation");
                        }
                        work.push(Work::Block(body, owner));
                    }
                }
            }
            Item::Const(c) => work.push(Work::Expr(
                &c.value,
                json!({"kind":"constant", "name":c.name.text, "uses":null, "file_uses":file_uses, "effective_effects":null}),
            )),
            Item::Data(_)
            | Item::Record(_)
            | Item::Alias(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::ExternalType(_)
            | Item::Error(_) => {}
        }
    }
    let mut rows = vec![];
    while let Some(job) = work.pop() {
        let (expr, owner) = match job {
            Work::Block(b, owner) => {
                for s in &b.stmts {
                    match s {
                        Stmt::Bind(b) => work.push(Work::Expr(&b.value, owner.clone())),
                        Stmt::Expr(e) => work.push(Work::Expr(e, owner.clone())),
                        Stmt::Error(_) => {}
                    }
                }
                continue;
            }
            Work::If(i, owner) => {
                work.push(Work::Expr(&i.cond, owner.clone()));
                work.push(Work::Block(&i.then_block, owner.clone()));
                match &i.else_branch {
                    Some(ElseBranch::Block(b)) => work.push(Work::Block(b, owner)),
                    Some(ElseBranch::If(i)) => work.push(Work::If(i, owner)),
                    None => {}
                }
                continue;
            }
            Work::Expr(e, owner) => (e, owner),
        };
        match expr {
            Expr::Try(t) => {
                let action = match &t.action {
                    TryAction::ImplicitReturn => "implicit_return",
                    TryAction::Return { .. } => "return",
                    TryAction::Die { .. } => "die",
                };
                let span = t.span;
                let operand = t.value.span();
                if let (Some(start), Some(end), Some(operand_start), Some(operand_end)) = (
                    span.start.0.checked_sub(offset),
                    span.end.0.checked_sub(offset),
                    operand.start.0.checked_sub(offset),
                    operand.end.0.checked_sub(offset),
                ) {
                    rows.push(
                        json!({"start":start,"end":end,"operand_start":operand_start,
                        "operand_end":operand_end,"action":action,"owner":owner}),
                    );
                }
                work.push(Work::Expr(&t.value, owner.clone()));
                if let TryAction::Die {
                    message: Some(message),
                    ..
                } = &t.action
                {
                    work.push(Work::Expr(message, owner));
                }
            }
            Expr::Lambda(l) => work.push(Work::Block(
                &l.body,
                json!({"kind":"callback",
                "name":format!("lambda@{}",l.span.start.0.saturating_sub(offset)),
                "return_type":l.ret.as_ref().map(|r|text(parsed_source,r.span())),
                "uses":l.uses.as_ref().map(|u|text(parsed_source,u.span)),
                "file_uses":file_uses,
                "effective_effects":program.and_then(|c| match c.types.expr_types.get(l.id)? {
                    Ty::Fn(f) if f.effects.failures.is_empty() => effect_names(&f.effects,c,&[],&[]),
                    Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => None,
                })}),
            )),
            Expr::If(i) => work.push(Work::If(i, owner)),
            Expr::Match(m) => {
                work.push(Work::Expr(&m.scrutinee, owner.clone()));
                for arm in &m.arms {
                    if let Some(g) = &arm.guard {
                        work.push(Work::Expr(g, owner.clone()));
                    }
                    work.push(Work::Block(&arm.body, owner.clone()));
                }
            }
            Expr::Call(c) => {
                work.push(Work::Expr(&c.callee, owner.clone()));
                for arg in &c.args {
                    let value = match arg {
                        Arg::Expr(e) => Some(e),
                        Arg::Named(a) => match &a.value {
                            ArgValue::Expr(e) => Some(e),
                            ArgValue::Placeholder(_) => None,
                        },
                        Arg::Placeholder(_) => None,
                    };
                    if let Some(e) = value {
                        work.push(Work::Expr(e, owner.clone()));
                    }
                }
            }
            Expr::Interp(i) => {
                for s in &i.segments {
                    work.push(Work::Expr(&s.expr, owner.clone()));
                }
            }
            Expr::Paren(p) => work.push(Work::Expr(&p.inner, owner)),
            Expr::List(l) => {
                for e in &l.elems {
                    let e = match e {
                        ListElem::Expr(e) => e,
                        ListElem::Spread(s) => &s.expr,
                    };
                    work.push(Work::Expr(e, owner.clone()));
                }
            }
            Expr::Record(r) => {
                if let Some(b) = &r.base {
                    work.push(Work::Expr(b, owner.clone()));
                }
                for f in &r.fields {
                    work.push(Work::Expr(&f.value, owner.clone()));
                }
            }
            Expr::Binary(b) => {
                work.push(Work::Expr(&b.lhs, owner.clone()));
                work.push(Work::Expr(&b.rhs, owner));
            }
            Expr::Pipe(p) => {
                work.push(Work::Expr(&p.lhs, owner.clone()));
                work.push(Work::Expr(&p.rhs, owner));
            }
            Expr::Unary(u) => work.push(Work::Expr(&u.operand, owner)),
            Expr::Return(r) => work.push(Work::Expr(&r.value, owner)),
            Expr::Resume(r) => work.push(Work::Expr(&r.value, owner)),
            Expr::Block(b) => work.push(Work::Block(&b.body, owner)),
            Expr::Lazy(l) => work.push(Work::Block(&l.body, owner)),
            Expr::With(w) => {
                for b in &w.binds {
                    work.push(Work::Expr(&b.value, owner.clone()));
                }
                work.push(Work::Block(&w.body, owner));
            }
            Expr::Handle(h) => {
                work.push(Work::Block(&h.body, owner.clone()));
                for c in &h.clauses {
                    work.push(Work::Block(
                        &c.body,
                        json!({"kind":"handler", "name":"handler", "uses":null, "file_uses":file_uses, "effective_effects":null}),
                    ));
                }
            }
            Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Error(_) => {}
        }
    }
    rows.sort_by_key(|r| r.get("start").and_then(Value::as_u64));
    Ok(
        json!({"version":2,"tries":rows,"typed":typed,"fragment":fragment,
        "parse_errors":parse_errors,"check_codes":check_codes}),
    )
}

fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    let requests: Vec<Value> = serde_json::from_str(&input)?;
    for request in requests {
        println!("{}", inventory(&request)?);
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    std::thread::Builder::new()
        .stack_size(pipeline::STAGE_STACK_BYTES)
        .spawn(run)?
        .join()
        .map_err(|_| "inventory thread failed")?
}
