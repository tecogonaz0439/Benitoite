//! 無作為に生成したソースを VM と参照インタプリタで比べる（設計書 07-03「差分テスト」、ADR 0213）。
//!
//! 再現: BENITOITE_RANDOM_PROGRAMS=1 BENITOITE_RANDOM_SEED=123 cargo test --test random_programs random_differential -- --nocapture
//! 長い実行: BENITOITE_RANDOM_PROGRAMS=100000 cargo test --release --test random_programs random_differential -- --nocapture
//! 種は十進の u64、件数は正の整数。同じ種からは同じソースができる。
//! 固定の並びは種 0 から始める。既知の反例は理由付きの ignore に残し、既定の並びからだけ外す。
//! 件数・種を指定した実行は既知の反例も試し、最後まで数えた後で失敗を返す。
//! 通常と gc-stress の既定の時間予算はそれぞれ 60 秒（実装プラン C14）。

// テストの失敗を panic で示し、生成の有限の上限の内側では添字と算術を使う（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

#[path = "golden/differential.rs"]
mod differential;
#[path = "random_programs/generator.rs"]
mod generator;
#[path = "random_programs/shrink.rs"]
mod shrink;

use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use benitoite::pipeline::{self, CheckOptions};
use benitoite::refinterp::RefOutcome;
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, MainOutcome, VmConfig};
use differential::Comparison;
use generator::{Coverage, REQUIRED, generate};

// 初めに通常・回収の強制で 1 件あたりの時間を測り、両方の 60 秒の予算から決める。
const DEFAULT_PROGRAMS: usize = 300;
const STRESS_PROGRAMS: usize = 200;
const KNOWN_SEEDS: &[u64] = &[];

#[derive(Clone, Debug, PartialEq, Eq)]
struct Failure {
    signature: String,
    detail: String,
}
impl Failure {
    fn new(signature: impl Into<String>, detail: impl Into<String>) -> Self {
        Self {
            signature: signature.into(),
            detail: detail.into(),
        }
    }
}
fn input() -> RunInput {
    RunInput {
        arguments: Vec::new(),
        working_directory: PathBuf::from("/root"),
        script_directory: PathBuf::from("/root"),
    }
}
fn options() -> CheckOptions {
    CheckOptions {
        require_main: true,
        deny_warnings: false,
    }
}

// 比較から外した結果も生成器の誤りとして扱う。成功例を捨てて別の種で穴埋めしない。
fn evaluate(seed: u64, source: &str) -> Result<(), Failure> {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let checked =
            pipeline::check_text(&format!("random-{seed}.bnt"), source.as_bytes(), options());
        let Some(program) = checked.program else {
            let codes: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .map(|d| d.code)
                .collect();
            return Err(Failure::new(
                format!("check:{codes:?}"),
                format!("check failed: {:?}", checked.diagnostics),
            ));
        };
        match differential::compare(program, checked.sources, input(), VmConfig::default(), mode) {
            Comparison::Matched => {}
            Comparison::Failed(detail) => {
                // 位置・実際の値が変わっても、同じ失敗の種類と方式だけを縮小する。
                let kind = detail.split(": VM").next().unwrap_or(&detail);
                let signature = if detail.starts_with("core IR check failed") {
                    "core IR check failed"
                } else if detail.starts_with("desugaring failed") {
                    "desugaring failed"
                } else if detail.starts_with("compilation failed") {
                    "compilation failed"
                } else {
                    kind
                };
                return Err(Failure::new(format!("{mode:?}:{signature}"), detail));
            }
            Comparison::Excluded(detail) => {
                return Err(Failure::new(format!("{mode:?}:excluded"), detail));
            }
        }
    }
    Ok(())
}

fn counterexample(
    seed: u64,
    source: &str,
    failure: &Failure,
    mut evaluate: impl FnMut(&str) -> Result<(), Failure>,
) -> String {
    let minimized = shrink::minimize(source, |candidate| {
        evaluate(candidate).is_err_and(|f| f.signature == failure.signature)
    });
    format!(
        "seed: {seed}\nfailure: {}\noriginal source:\n{source}\nminimized source:\n{minimized}",
        failure.detail
    )
}

// 関門: 本物のパイプライン・VM・参照インタプリタで、出力と停止の一致を守る。
// 人の書いたゴールデン例では届かない入れ子の組み合わせと GC 時の根の漏れを検出する。
#[test]
fn random_differential() {
    let count_env = std::env::var("BENITOITE_RANDOM_PROGRAMS").ok();
    let seed_env = std::env::var("BENITOITE_RANDOM_SEED").ok();
    let manual = count_env.is_some() || seed_env.is_some();
    let default_count = if cfg!(feature = "gc-stress") {
        STRESS_PROGRAMS
    } else {
        DEFAULT_PROGRAMS
    };
    let count: usize = count_env.map_or(default_count, |n| {
        n.parse()
            .expect("BENITOITE_RANDOM_PROGRAMS must be an integer")
    });
    assert!(count > 0, "BENITOITE_RANDOM_PROGRAMS must be positive");
    let first: u64 = seed_env.map_or(0, |n| {
        n.parse()
            .expect("BENITOITE_RANDOM_SEED must be a decimal u64")
    });
    let start = Instant::now();
    let mut coverage = Coverage::default();
    let mut failures = 0;
    let mut completed = 0;
    let mut offset = 0_u64;
    while completed < count {
        let seed = first
            .checked_add(offset)
            .expect("random seed range exceeds u64");
        offset += 1;
        if !manual && KNOWN_SEEDS.contains(&seed) {
            continue;
        }
        let generated = generate(seed, 6);
        coverage.merge(&generated.coverage);
        if let Err(failure) = evaluate(seed, &generated.source) {
            failures += 1;
            eprintln!(
                "{}",
                counterexample(seed, &generated.source, &failure, |s| evaluate(seed, s))
            );
        }
        completed += 1;
        if manual && completed % 1000 == 0 {
            eprintln!(
                "progress: {completed}/{count}, counterexamples: {failures}, elapsed: {:?}",
                start.elapsed()
            );
        }
    }
    let elapsed = start.elapsed();
    eprintln!(
        "programs: {completed}, counterexamples: {failures}, elapsed: {elapsed:?}, per program: {:?}, gc-stress: {}, coverage: {:?}",
        elapsed / u32::try_from(count).unwrap(),
        cfg!(feature = "gc-stress"),
        coverage.0
    );
    assert_eq!(
        failures, 0,
        "random differential counterexamples reported above"
    );
    if !manual {
        for feature in REQUIRED {
            assert!(
                coverage.0.get(feature).copied().unwrap_or(0) > 0,
                "feature missing: {feature}"
            );
        }
        assert!(
            elapsed < Duration::from_secs(60),
            "random differential exceeded the 60 second budget: {elapsed:?}"
        );
    }
}

// 関門: 種による再現は C14 が明示した生成器の契約。失敗を再現できなくなる退行を捕まえる。
// 個々のソースの字面を固定せず、違う種と別の生成を挟んでも種だけで再現できることを確かめる。
#[test]
fn seed_reproduces_source() {
    for stage in 1..=6 {
        let first = generate(31, stage);
        let other = generate(32, stage);
        assert_ne!(first.source, other.source);
        assert_eq!(first, generate(31, stage));
        assert!(evaluate(31, &first.source).is_ok());
    }
}

// 関門: 比較の検出力と縮小を C14 の個別指示で確かめる。実行結果の一バイトだけを変え、
// 構文・型の誤りを反例として採用しないことと、不要な宣言・文を落とすことを確認する。
#[test]
fn detects_and_shrinks_changed_output() {
    let source = "import Benitoite.Unofficial.IO.Console\nconst unused: Integer = 17\nfunction main() -> Unit uses Console.Write\nbind unusedValue <- 99\nConsole.writeLine(\"hello\")\nConsole.writeLine(\"world\")\nend function\n";
    assert!(evaluate(0, source).is_ok());
    let failure = injected_difference(source).expect_err("one changed byte must be detected");
    let report = counterexample(0, source, &failure, injected_difference);
    let minimized = report.split("minimized source:\n").nth(1).unwrap();
    assert!(minimized.len() < source.len());
    assert!(!minimized.contains("const unused"));
    assert!(!minimized.contains("bind unusedValue"));
    assert!(
        evaluate(0, minimized).is_ok(),
        "shrink must retain a valid program"
    );
    assert_eq!(
        injected_difference(minimized).unwrap_err().signature,
        failure.signature
    );
    assert!(
        report.contains("seed: 0")
            && report.contains("original source:")
            && report.contains("stdout")
    );
}

fn injected_difference(source: &str) -> Result<(), Failure> {
    let checked = pipeline::check_text("random-0.bnt", source.as_bytes(), options());
    let Some(checked_program) = checked.program else {
        return Ok(());
    };
    let core = pipeline::desugar_checked(&checked_program).unwrap();
    if !benitoite::ir::check::check_program(&core).is_empty() {
        return Ok(());
    }
    let program = pipeline::compile(&core, Arc::clone(&checked.sources)).unwrap();
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let vm = run::run_program(
        &program,
        RunEnv {
            input: input(),
            stdin: StdinSource::Empty,
            stdout: OutputTarget::Capture(Arc::clone(&stdout)),
            stderr: OutputTarget::Capture(Arc::clone(&stderr)),
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode: ExecMode::Direct,
            vm: VmConfig::default(),
            heap: HeapConfig::default(),
            dev_panic_after_first_write: false,
        },
    );
    let stdout = stdout.lock().unwrap();
    let stderr = stderr.lock().unwrap();
    let mut changed = stdout.clone();
    let Some(byte) = changed.first_mut() else {
        return Ok(());
    };
    *byte ^= 1;
    match differential::compare_results(
        &program,
        &checked.sources,
        &vm,
        (&stdout, &stderr),
        RefOutcome::Finished(MainOutcome::Ok),
        (&changed, &stderr),
    ) {
        Comparison::Failed(detail) => Err(Failure::new("injected stdout", detail)),
        Comparison::Matched | Comparison::Excluded(_) => Ok(()),
    }
}
