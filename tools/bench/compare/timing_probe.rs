//! 共通比較器の観測。段の公開境界と各版自身の変換を使う（設計書 07-02「測る項目」）。
use benitoite::*;
use ir::core_ir::*;
use runtime::heap::HeapConfig;
use runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use std::{
    error::Error,
    path::Path,
    sync::{Arc, Mutex},
    time::Instant,
};
use types::{EffectSet, Ty, TyCon};

mod refbridge {
    include!(env!("BENITOITE_COMPARE_BRIDGE"));
}

fn count_value(value: &CoreVal) -> usize {
    match &value.kind {
        ValKind::Lambda(l) => count_comp(&l.body),
        ValKind::Ctor { args, .. } | ValKind::List(args) => args.iter().map(count_value).sum(),
        _ => 0,
    }
}
fn count_comp(comp: &Comp) -> usize {
    match &comp.kind {
        CompKind::Let { bound, body, .. } => {
            // Let の並びは深さを Rust の呼び出しへ移さない。
            let mut total = 0;
            let mut at = comp;
            while let CompKind::Let { bound, body, .. } = &at.kind {
                total += 1 + count_comp(bound);
                at = body;
            }
            let _ = (bound, body);
            total + count_comp(at)
        }
        CompKind::Return(v) | CompKind::Escape(v) | CompKind::Resume { value: v, .. } => {
            count_value(v)
        }
        CompKind::App { func, args, .. } => {
            count_value(func) + args.iter().map(count_value).sum::<usize>()
        }
        CompKind::Method(m) => m.args.iter().map(count_value).sum(),
        CompKind::If {
            cond,
            then_branch,
            else_branch,
        } => count_value(cond) + count_comp(then_branch) + count_comp(else_branch),
        CompKind::Match {
            scrutinee, arms, ..
        } => {
            count_value(scrutinee)
                + arms
                    .iter()
                    .map(|a| a.guard.as_ref().map_or(0, count_comp) + count_comp(&a.body))
                    .sum::<usize>()
        }
        CompKind::Use { resource, body } => count_value(resource) + count_comp(body),
        CompKind::Lazy { body, .. } => count_comp(body),
        CompKind::Handle(h) => {
            count_comp(&h.body) + h.clauses.iter().map(|c| count_comp(&c.body)).sum::<usize>()
        }
        _ => 0, // 新しい専用構築器は穴の入力に含まれない。版間で同じコードをコンパイルする。
    }
}

fn irenv(n: usize) -> Result<serde_json::Value, Box<dyn Error>> {
    use base::{BindingId, Span};
    let ty = Ty::Con(TyCon::Builtin(types::builtin::BuiltinTypeId::UNIT), vec![]);
    let origin = Span {
        file: base::FileId(0),
        start: base::BytePos(0),
        end: base::BytePos(0),
    };
    let unit = CoreVal {
        kind: ValKind::Const(Const::Unit),
        ty: ty.clone(),
        origin,
    };
    let ret = Comp {
        kind: CompKind::Return(unit.clone()),
        ty: ty.clone(),
        eff: EffectSet::empty(),
        origin,
    };
    let mut body = ret.clone();
    for i in (0..n).rev() {
        body = Comp {
            kind: CompKind::Let {
                var: Var {
                    id: VarId(u32::try_from(i)?),
                    name: None,
                    ty: ty.clone(),
                },
                bound: Box::new(ret.clone()),
                body: Box::new(body),
            },
            ..ret.clone()
        };
    }
    let def = Def {
        param_names: vec![],
        binding: BindingId(0),
        name: "main".into(),
        origin: DefOrigin::User,
        kind: DefKind::Fn,
        type_params: vec![],
        effect_params: vec![],
        dict_params: vec![],
        params: vec![],
        ret: ty.clone(),
        eff: EffectSet::empty(),
        body,
        span: origin,
        var_count: u32::try_from(n.max(1))?,
    };
    let mut p = CoreProgram {
        defs: vec![def],
        impls: vec![],
        consts: vec![],
        ops: vec![],
        adts: Default::default(),
        traits: Default::default(),
        schemes: Default::default(),
        main: None,
        main_returns_result: false,
        body_count: 0,
    };
    // 検査器は本体と宣言の型を照合する。入力の宣言型も計時の前に用意する
    // （設計書 02-06「コア IR の検査器」）。両版で同じ前提を満たす。
    p.schemes.insert(
        BindingId(0),
        types::Scheme {
            param_names: vec![],
            type_params: vec![],
            effect_params: vec![],
            no_fail: vec![],
            class_constraints: vec![],
            params: vec![],
            ret: ty.clone(),
            effects: EffectSet::empty(),
            wrote_io_all: false,
        },
    );
    let start = Instant::now();
    let errors = ir::check::check_program(&p);
    let elapsed = start.elapsed().as_secs_f64();
    if !errors.is_empty() {
        return Err(format!("valid IR rejected: {errors:?}").into());
    }
    // 兄弟の枝へ局所束縛が流れ込む不正 IR を独立に作る。
    let v = Var {
        id: VarId(0),
        name: None,
        ty: ty.clone(),
    };
    let bound = Comp {
        kind: CompKind::Let {
            var: v.clone(),
            bound: Box::new(ret.clone()),
            body: Box::new(ret.clone()),
        },
        ..ret.clone()
    };
    let bad = Comp {
        kind: CompKind::Return(CoreVal {
            kind: ValKind::Var(v.id),
            ..unit
        }),
        ..ret.clone()
    };
    p.defs[0].body = Comp {
        kind: CompKind::If {
            cond: CoreVal {
                kind: ValKind::Const(Const::Bool(true)),
                ty: Ty::Con(
                    TyCon::Builtin(types::builtin::BuiltinTypeId::BOOLEAN),
                    vec![],
                ),
                origin,
            },
            then_branch: Box::new(bound),
            else_branch: Box::new(bad),
        },
        ..ret
    };
    let rejected = !ir::check::check_program(&p).is_empty();
    if !rejected {
        return Err("invalid sibling IR accepted".into());
    }
    Ok(serde_json::json!({"ir_check":elapsed,"ir_errors":0,"sibling_rejected":1}))
}

fn stages(input: &str, mode: &str, args: Vec<String>) -> Result<serde_json::Value, Box<dyn Error>> {
    let entry = pipeline::entry_spec(Path::new(input)).map_err(|e| format!("{e:?}"))?;
    let mut ids = base::IdGen::new();
    let start = Instant::now();
    let loaded = modules::load_program(&entry, prelude::STDLIB, &modules::RealFs, &mut ids);
    let load = start.elapsed().as_secs_f64();
    if loaded.diagnostics.iter().any(diag::Diagnostic::is_error) {
        return Err(format!("load errors: {:?}", loaded.diagnostics).into());
    }
    let start = Instant::now();
    let resolved = resolve::resolve(&loaded.modules, &loaded.asts, &loaded.sources, &mut ids);
    let resolve_time = start.elapsed().as_secs_f64();
    if resolved.diagnostics.iter().any(diag::Diagnostic::is_error) {
        return Err(format!("resolve errors: {:?}", resolved.diagnostics).into());
    }
    let start = Instant::now();
    let (_types, diagnostics) = typeck::typecheck(
        &loaded.modules,
        &loaded.asts,
        &loaded.sources,
        &resolved,
        true,
    );
    let typeck_time = start.elapsed().as_secs_f64();
    let errors = diagnostics.iter().filter(|d| d.is_error()).count();
    let mut parse_ids = base::IdGen::new();
    let start = Instant::now();
    for (file, source) in loaded.sources.iter() {
        let lexed = syntax::lexer::lex(file, source.text());
        let tokens = syntax::newline::resolve_newlines(lexed.tokens);
        let parsed = syntax::parser::parse(
            file,
            source.kind(),
            source.text(),
            tokens,
            lexed.comments,
            #[cfg(benitoite_parser_pending)]
            lexed.pending,
            &mut parse_ids,
        );
        std::hint::black_box(parsed);
    }
    let reparse = start.elapsed().as_secs_f64();
    let mut out = serde_json::json!({"load_parse":load,"reparse":reparse,"resolve":resolve_time,"typeck":typeck_time,"errors":errors});
    if mode == "check" || errors != 0 {
        return Ok(out);
    }
    // 公開 pipeline の前処理も通す。上の単独の型検査と各区間は加算しない。
    let checked = pipeline::check(
        &entry,
        &modules::RealFs,
        pipeline::CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    let program = checked
        .program
        .ok_or_else(|| format!("pipeline errors: {:?}", checked.diagnostics))?;
    let start = Instant::now();
    let core = pipeline::desugar_checked(&program).map_err(|e| format!("{e:?}"))?;
    out["desugar"] = start.elapsed().as_secs_f64().into();
    out["hole_lets"] = core
        .defs
        .iter()
        .filter(|d| d.origin == DefOrigin::User)
        .map(|d| count_comp(&d.body))
        .sum::<usize>()
        .into();
    let start = Instant::now();
    let errors = ir::check::check_program(&core);
    out["ir_check"] = start.elapsed().as_secs_f64().into();
    if !errors.is_empty() {
        return Err(format!("IR rejected: {errors:?}").into());
    }
    let start = Instant::now();
    let lower = ir::decision::lower_program(&core).map_err(|e| format!("{e:?}"))?;
    out["lower"] = start.elapsed().as_secs_f64().into();
    let start = Instant::now();
    let compiled =
        bytecode::codegen::codegen(&lower, checked.sources).map_err(|e| format!("{e:?}"))?;
    out["codegen"] = start.elapsed().as_secs_f64().into();
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let input =
        run::run_input(&entry, args, std::env::current_dir()?).map_err(|e| e.to_string())?;
    let start = Instant::now();
    let end = run::run_program(
        &compiled,
        RunEnv {
            input,
            stdin: StdinSource::Empty,
            stdout: OutputTarget::Capture(Arc::clone(&stdout)),
            stderr: OutputTarget::Capture(Arc::clone(&stderr)),
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode: vm::ExecMode::Direct,
            vm: vm::VmConfig::default(),
            heap: HeapConfig::default(),
            dev_panic_after_first_write: false,
        },
    );
    out["vm_run"] = start.elapsed().as_secs_f64().into();
    if end.exit_code != 0
        || !end.reports.is_empty()
        || end.main_error.is_some()
        || !stderr.lock().map_err(|_| "capture poisoned")?.is_empty()
    {
        return Err(format!("run failed: {end:?}").into());
    }
    out["output"] =
        String::from_utf8(stdout.lock().map_err(|_| "capture poisoned")?.clone())?.into();
    #[cfg(feature = "alloc-stats")]
    {
        out["allocated_bytes"] = end.heap.allocated_bytes.into();
        out["peak_heap_bytes"] = end.heap.peak_heap_bytes.into();
    }
    Ok(out)
}

fn execute() -> Result<(), Box<dyn Error>> {
    let mut args = std::env::args().skip(1);
    let input = args.next().ok_or("input required")?;
    let mode = args.next().unwrap_or_else(|| "check".into());
    let value = match mode.as_str() {
        "irenv" => irenv(args.next().ok_or("size required")?.parse()?)?,
        "bridge" => {
            let shape = args.next().ok_or("shape required")?;
            let n = args.next().ok_or("size required")?.parse()?;
            let text = refbridge::observe(&shape, n).map_err(|e| format!("{e:?}"))?;
            serde_json::from_str(&text)?
        }
        "stages" | "check" => stages(&input, &mode, args.collect())?,
        _ => return Err(format!("unknown mode: {mode}").into()),
    };
    println!("{value}");
    Ok(())
}
fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    // 本体の段と同じスタックを使い、probe だけの浅い制限を持ち込まない。
    std::thread::Builder::new()
        .stack_size(pipeline::STAGE_STACK_BYTES)
        .spawn(|| execute().map_err(|e| e.to_string()))?
        .join()
        .map_err(|_| "probe thread panicked")?
        .map_err(Into::into)
}
