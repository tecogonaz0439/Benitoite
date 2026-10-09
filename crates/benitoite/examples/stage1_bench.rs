//! 第1段のパイプラインと実行を同じ条件で測る（設計書 07-02、実装プラン R12）。

#[path = "stage1_support/mod.rs"]
mod support;

use std::path::Path;
use std::process::ExitCode;
use std::time::Instant;

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};

fn main() -> ExitCode {
    match execute() {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(2)
        }
    }
}

fn execute() -> Result<u8, String> {
    let options = support::options()?;
    let mut args = options.args.into_iter();
    let path = args.next().ok_or(text::USAGE)?;
    let started = Instant::now();
    let checked = pipeline::check_path(
        Path::new(&path),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
    .map_err(|e| format!("{e:?}"))?;
    let check_nanos = started.elapsed().as_nanos();
    let program = checked
        .program
        .ok_or_else(|| format!("{:?}", checked.diagnostics))?;
    let lowering = Instant::now();
    let core = pipeline::desugar_checked(&program).map_err(|e| format!("{e:?}"))?;
    let compiled = pipeline::compile(&core, checked.sources).map_err(|e| format!("{e:?}"))?;
    let compile_nanos = lowering.elapsed().as_nanos();
    for proto in &compiled.protos {
        for instruction in &proto.code {
            if !instruction.opcode().ok_or(text::NOT_STAGE1)?.in_stage1() {
                return Err(text::NOT_STAGE1.into());
            }
        }
    }
    if options.check_only {
        return Ok(0);
    }
    let entry = pipeline::entry_spec(Path::new(&path)).map_err(|e| format!("{e:?}"))?;
    let input = run::run_input(
        &entry,
        args.collect(),
        std::env::current_dir().map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    let running = Instant::now();
    let end = run::run_program(
        &compiled,
        RunEnv {
            input,
            stdin: StdinSource::Process,
            stdout: OutputTarget::Stdout,
            stderr: OutputTarget::Stderr,
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode: ExecMode::Direct,
            vm: VmConfig::default(),
            heap: options.heap,
            dev_panic_after_first_write: false,
        },
    );
    let run_nanos = running.elapsed().as_nanos();
    let total_nanos = started.elapsed().as_nanos();
    if let Some(message) = end.main_error {
        eprintln!("{message}");
    }
    for report in end.reports {
        eprintln!("{report:?}");
    }
    support::emit(
        &end.heap,
        check_nanos,
        compile_nanos,
        run_nanos,
        total_nanos,
        None,
    )?;
    Ok(end.exit_code)
}

mod text {
    pub const USAGE: &str =
        "usage: stage1_bench [--factor N] [--no-reuse] [--check-only] -- SCRIPT [ARG ...]";
    pub const NOT_STAGE1: &str = "compiled program contains a stage 2 instruction";
}
