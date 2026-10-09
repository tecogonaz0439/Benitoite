//! 初回リリース版の段別の時間と回収の費用を測る（設計書 07-02、実装プラン C16）。
//! 開発用の例なので、文言を `text` にまとめる規約は対象外とする。lint は処理系と同じである。

use std::path::Path;
use std::process::ExitCode;
use std::time::Instant;

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::{HeapConfig, HeapStats};
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};

struct Options {
    path: String,
    args: Vec<String>,
    vm: VmConfig,
    heap: HeapConfig,
    mode: ExecMode,
    repeat_check: usize,
}

fn options() -> Result<Options, String> {
    let mut vm = VmConfig::default();
    let mut heap = HeapConfig::default();
    let mut mode = ExecMode::Direct;
    let mut repeat_check = 1;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        if let Some(value) = arg.strip_prefix("--call-budget=") {
            vm.call_budget = positive(value)?;
        } else if let Some(value) = arg.strip_prefix("--trigger-factor=") {
            heap.trigger_factor_percent = value.parse().map_err(|_| "invalid trigger factor")?;
        } else if let Some(value) = arg.strip_prefix("--repeat-check=") {
            repeat_check = usize::try_from(positive(value)?).map_err(|e| e.to_string())?;
        } else if let Some(value) = arg.strip_prefix("--io-mode=") {
            mode = match value {
                "direct" => ExecMode::Direct,
                "request" => ExecMode::Request,
                _ => return Err("expected --io-mode=direct|request".into()),
            };
        } else {
            let path = if arg == "--" {
                args.next().ok_or("expected script path")?
            } else if arg.starts_with("--") {
                return Err(format!("unknown option: {arg}"));
            } else {
                arg
            };
            return Ok(Options {
                path,
                args: args.collect(),
                vm,
                heap,
                mode,
                repeat_check,
            });
        }
    }
    Err("usage: bench_run [--call-budget=N] [--trigger-factor=PERCENT] [--io-mode=direct|request] [--repeat-check=N] [--] SCRIPT [ARG ...]".into())
}

fn positive(value: &str) -> Result<u32, String> {
    let count: u32 = value.parse().map_err(|_| "expected a positive count")?;
    if count == 0 {
        return Err("expected a positive count".into());
    }
    Ok(count)
}

// 百分位は nearest-rank とし、標本がない場合を 0 として出す（実装プラン C16）。
fn percentile(sorted: &[u64], percent: usize) -> Result<u64, String> {
    if sorted.is_empty() {
        return Ok(0);
    }
    let rank = sorted
        .len()
        .checked_mul(percent)
        .and_then(|n| n.checked_add(99))
        .map(|n| n / 100)
        .and_then(|n| n.checked_sub(1))
        .ok_or("percentile rank overflow")?;
    sorted
        .get(rank)
        .copied()
        .ok_or("invalid percentile rank".into())
}

fn emit(stats: &HeapStats, times: [u128; 5], options: &Options) -> Result<(), String> {
    let mut pauses = stats.pause_nanos.clone();
    pauses.sort_unstable();
    let sum = pauses.iter().try_fold(0_u128, |sum, &value| {
        sum.checked_add(u128::from(value))
            .ok_or("pause sum overflow")
    })?;
    let [check, desugar, compile, run, total] = times;
    eprintln!(
        "bench-run: check_nanos={check} desugar_nanos={desugar} compile_nanos={compile} run_nanos={run} total_nanos={total} repeat_check={} call_budget={} trigger_factor_percent={} allocations={} allocated_bytes={} live_bytes={} peak_heap_bytes={} collections={} roots_traced={} frees={} pause_count={} pause_p50_nanos={} pause_p95_nanos={} pause_p99_nanos={} pause_max_nanos={} pause_total_nanos={sum}",
        options.repeat_check,
        options.vm.call_budget,
        options.heap.trigger_factor_percent,
        stats.allocations,
        stats.allocated_bytes,
        stats.live_bytes,
        stats.peak_heap_bytes,
        stats.collections,
        stats.roots_traced,
        stats.frees,
        pauses.len(),
        percentile(&pauses, 50)?,
        percentile(&pauses, 95)?,
        percentile(&pauses, 99)?,
        pauses.last().copied().unwrap_or(0),
    );
    // R33 は R12 と同じく全実行の標本を合わせた百分位も求める。
    // 既存の整数だけの統計行を保ち、個々の停止時間は別の行で出す。
    eprintln!(
        "bench-pauses: {}",
        stats
            .pause_nanos
            .iter()
            .map(u64::to_string)
            .collect::<Vec<_>>()
            .join(",")
    );
    Ok(())
}

fn execute() -> Result<u8, String> {
    let options = options()?;
    let path = Path::new(&options.path);
    let started = Instant::now();
    let mut checks = Vec::new();
    let mut last = None;
    for _ in 0..options.repeat_check {
        let checking = Instant::now();
        let checked = pipeline::check_path(
            path,
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        )
        .map_err(|e| format!("{e:?}"))?;
        checks.push(checking.elapsed().as_nanos());
        if checked.program.is_none() {
            return Err(format!("{:?}", checked.diagnostics));
        }
        last = Some(checked);
    }
    checks.sort_unstable();
    let upper = checks
        .get(checks.len() / 2)
        .copied()
        .ok_or("missing check sample")?;
    let check_nanos = if checks.len().is_multiple_of(2) {
        let lower_index = (checks.len() / 2)
            .checked_sub(1)
            .ok_or("missing check sample")?;
        let lower = checks.get(lower_index).ok_or("missing check sample")?;
        upper.checked_add(*lower).ok_or("check time overflow")? / 2
    } else {
        upper
    };
    let checked = last.ok_or("missing checked program")?;
    let program = checked.program.ok_or("missing checked program")?;
    let lowering = Instant::now();
    let core = pipeline::desugar_checked(&program).map_err(|e| format!("{e:?}"))?;
    let desugar_nanos = lowering.elapsed().as_nanos();
    let compiling = Instant::now();
    let compiled = pipeline::compile(&core, checked.sources).map_err(|e| format!("{e:?}"))?;
    let compile_nanos = compiling.elapsed().as_nanos();
    let entry = pipeline::entry_spec(path).map_err(|e| format!("{e:?}"))?;
    let input = run::run_input(
        &entry,
        options.args.clone(),
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
            mode: options.mode,
            vm: options.vm,
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
    emit(
        &end.heap,
        [
            check_nanos,
            desugar_nanos,
            compile_nanos,
            run_nanos,
            total_nanos,
        ],
        &options,
    )?;
    Ok(end.exit_code)
}

fn main() -> ExitCode {
    match execute() {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(2)
        }
    }
}
