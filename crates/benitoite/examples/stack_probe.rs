//! 子のプロセスの終了状態で最小のスタックを測る（設計書 02-01「関数の呼び出しと処理系のスタック」）。
//! `stack_probe run <shape> <depth|max> <stack-bytes> <stage>`、または
//! `stack_probe measure <shape> <depth|max> <stage>`。段は parse/check/desugar/lower/codegen/all。
//! 各段までを順に行い、結果の破棄も測るスレッドの中で行う。開発用の例なので文言の表は使わない。

#[path = "stack_probe/support.rs"]
mod support;
use benitoite::{
    base::{FileId, IdGen, SourceKind},
    pipeline::{self, CheckOptions},
};
use std::process::{Command, ExitCode};
use std::sync::Arc;

const STEP: usize = 16 * 1024;
const MAX_STACK: usize = 64 * 1024 * 1024;

fn stages(source: &str, stage: &str) -> Result<(), String> {
    if stage == "parse" {
        let lexed = benitoite::syntax::lexer::lex(FileId(0), source.as_bytes());
        let parsed = benitoite::syntax::parser::parse(
            FileId(0),
            SourceKind::User,
            source.as_bytes(),
            benitoite::syntax::newline::resolve_newlines(lexed.tokens),
            lexed.comments,
            &mut IdGen::new(),
        );
        if !lexed.diagnostics.is_empty() || !parsed.diagnostics.is_empty() {
            return Err(format!(
                "parse: {:?} {:?}",
                lexed.diagnostics, parsed.diagnostics
            ));
        }
        return Ok(());
    }
    let result = pipeline::check_text_on_current_thread(
        "probe.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    if !result.diagnostics.is_empty() {
        return Err(format!("check: {:?}", result.diagnostics));
    }
    let p = result.program.as_ref().ok_or("check produced no program")?;
    if stage == "check" {
        return Ok(());
    }
    let core = benitoite::ir::desugar::desugar(&p.modules, &p.asts, &p.resolved, &p.types)
        .map_err(|e| format!("desugar: {e:?}"))?;
    if stage == "desugar" {
        return Ok(());
    }
    let lower =
        benitoite::ir::decision::lower_program(&core).map_err(|e| format!("lower: {e:?}"))?;
    if stage == "lower" {
        return Ok(());
    }
    let _compiled = benitoite::bytecode::codegen::codegen(&lower, Arc::clone(&result.sources))
        .map_err(|e| format!("codegen: {e:?}"))?;
    Ok(())
}

fn succeeds(shape: &str, depth: usize, bytes: usize, stage: &str) -> Result<bool, String> {
    let output = Command::new(std::env::current_exe().map_err(|e| e.to_string())?)
        .args(["run", shape, &depth.to_string(), &bytes.to_string(), stage])
        .output()
        .map_err(|e| e.to_string())?;
    match output.status.code() {
        Some(0) => Ok(true),
        None => Ok(false),
        Some(code) => Err(format!(
            "child exited with {code}: {}",
            String::from_utf8_lossy(&output.stderr)
        )),
    }
}

fn minimum(shape: &str, depth: usize, stage: &str) -> Result<usize, String> {
    if !succeeds(shape, depth, MAX_STACK, stage)? {
        return Err("overflow at 64 MiB".into());
    }
    let mut low = 0usize;
    let mut high = MAX_STACK.checked_div(STEP).ok_or("invalid step")?;
    while high.saturating_sub(low) > 1 {
        let mid = low.saturating_add(
            high.saturating_sub(low)
                .checked_div(2)
                .ok_or("invalid divisor")?,
        );
        if succeeds(shape, depth, mid.saturating_mul(STEP), stage)? {
            high = mid;
        } else {
            low = mid;
        }
    }
    Ok(high.saturating_mul(STEP))
}

fn run() -> Result<(), String> {
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    let mode = args
        .first()
        .ok_or("usage: stack_probe run|measure <shape> <depth|max> [bytes] <stage>")?;
    let shape = args.get(1).ok_or("missing shape")?;
    let depth = args.get(2).ok_or("missing depth")?;
    let depth = if depth == "max" {
        support::limit(shape, benitoite::syntax::parser::MAX_DEPTH)?
    } else {
        depth.parse::<usize>().map_err(|e| e.to_string())?
    };
    let stage = args
        .get(if mode == "run" { 4 } else { 3 })
        .ok_or("missing stage")?;
    if !["parse", "check", "desugar", "lower", "codegen", "all"].contains(&stage.as_str()) {
        return Err(format!("unknown stage: {stage}"));
    }
    match mode.as_str() {
        "run" => {
            let bytes = args
                .get(3)
                .ok_or("missing bytes")?
                .parse::<usize>()
                .map_err(|e| e.to_string())?;
            let source = support::source(shape, depth)?;
            let stage = stage.clone();
            std::thread::Builder::new()
                .stack_size(bytes)
                .spawn(move || stages(&source, &stage))
                .map_err(|e| e.to_string())?
                .join()
                .map_err(|_| "stage panicked".to_string())??;
        }
        "measure" => {
            let half = depth.checked_div(2).ok_or("invalid divisor")?;
            let small = minimum(shape, half, stage)?;
            let large = minimum(shape, depth, stage)?;
            let per_level = large
                .saturating_sub(small)
                .checked_div(depth.saturating_sub(half))
                .ok_or("depth must exceed zero")?;
            println!("{shape},{stage},{depth},{small},{large},{per_level}");
        }
        _ => return Err(format!("unknown mode: {mode}")),
    }
    Ok(())
}
fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(2)
        }
    }
}
