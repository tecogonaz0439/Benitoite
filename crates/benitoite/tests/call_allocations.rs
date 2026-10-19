//! 普通の呼び出しと戻りは容量の伸長以外に確保しない（設計書 07-02「性能の関門」）。
#![cfg(not(feature = "gc-stress"))]
// このバイナリだけで System への委譲を数える
// （AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(unsafe_code)]
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use benitoite::bytecode::program::CompiledProgram;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::time::Instant;

struct CountedSystem;
static COUNTING: AtomicBool = AtomicBool::new(false);
static ALLOCATIONS: AtomicUsize = AtomicUsize::new(0);
static ALLOCATED_BYTES: AtomicUsize = AtomicUsize::new(0);
static MEASUREMENT: Mutex<()> = Mutex::new(());
#[global_allocator]
static ALLOCATOR: CountedSystem = CountedSystem;

fn count(bytes: usize) {
    if COUNTING.load(Ordering::Relaxed) {
        ALLOCATIONS.fetch_add(1, Ordering::Relaxed);
        ALLOCATED_BYTES.fetch_add(bytes, Ordering::Relaxed);
    }
}
// SAFETY: System の契約を変えず、受けた配置・ポインタ・大きさをそのまま渡す。
unsafe impl GlobalAlloc for CountedSystem {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        count(layout.size());
        // SAFETY: GlobalAlloc の呼び出し側が保証した layout を、そのまま System に渡す。
        unsafe { System.alloc(layout) }
    }
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        count(layout.size());
        // SAFETY: GlobalAlloc の呼び出し側が保証した layout を、そのまま System に渡す。
        unsafe { System.alloc_zeroed(layout) }
    }
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        count(new_size);
        // SAFETY: System から得た ptr と元の layout、有効な new_size をそのまま委譲する。
        unsafe { System.realloc(ptr, layout, new_size) }
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        // SAFETY: System から得た ptr と確保時の layout を、そのまま System に渡す。
        unsafe { System.dealloc(ptr, layout) }
    }
}

fn compile(n: u32, answer: u32) -> CompiledProgram {
    let source = format!(
        r#"
function fib(n: Integer) -> Integer
  return if n < 2 then n else fib(n - 1) + fib(n - 2) end if
end function
function main() -> Result[Unit, String]
  return if fib({n}) = {answer} then Result.Ok(()) else Result.Error("wrong fibonacci value") end if
end function
"#
    );
    compile_source(&source)
}

fn compile_named(n: u32, answer: u32) -> CompiledProgram {
    compile_source(&format!(
        "function count(n: Integer, acc: Integer) -> Integer\n return if n = 0 then acc else count(acc: acc + 1, n: n - 1) end if\nend function\nfunction main() -> Result[Unit, String]\n return if count(acc: 0, n: {n}) = {answer} then Result.Ok(()) else Result.Error(\"wrong count\") end if\nend function"
    ))
}

fn compile_source(source: &str) -> CompiledProgram {
    let checked = pipeline::check_text(
        "allocations.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}

fn allocations(program: &CompiledProgram) -> usize {
    let env = RunEnv {
        input: RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        stdin: StdinSource::Empty,
        stdout: OutputTarget::Stdout,
        stderr: OutputTarget::Stderr,
        interrupt: Box::new(NoInterrupt),
        parts: None,
        mode: ExecMode::Direct,
        vm: VmConfig::default(),
        heap: HeapConfig::default(),
        dev_panic_after_first_write: false,
    };
    ALLOCATIONS.store(0, Ordering::Relaxed);
    COUNTING.store(true, Ordering::Relaxed);
    let result = run::run_program(program, env);
    COUNTING.store(false, Ordering::Relaxed);
    let count = ALLOCATIONS.load(Ordering::Relaxed);
    assert_eq!(result.exit_code, 0, "{:?}", result.reports);
    assert!(result.main_error.is_none());
    count
}

// 関門: 普通の呼び出しに比例する Rust の確保を検出する。既存の出力のテストでは
// 引数の Vec の復活を検出できない。公開のパイプラインと実行の入口だけを使う。
#[test]
fn ordinary_calls_and_returns_allocate_only_for_capacity_growth() {
    let _measurement = MEASUREMENT.lock().unwrap();
    let small = compile(18, 2584);
    let large = compile(22, 17711);
    // panic hook など実行ごとの費用でない初期化は、先に済ませる。
    allocations(&small);
    let a = allocations(&small);
    let b = allocations(&large);
    eprintln!("fib(18): {a} allocations; fib(22): {b} allocations");
    assert!(
        a.abs_diff(b) <= 16,
        "ordinary calls allocated in proportion to their count: {a} -> {b}"
    );
    let small = compile_named(100, 100);
    let large = compile_named(10000, 10000);
    allocations(&small);
    let a = allocations(&small);
    let b = allocations(&large);
    assert!(
        a.abs_diff(b) <= 16,
        "named tail calls allocated in proportion to their count: {a} -> {b}"
    );
}

// 関門: 2万個のconst連鎖を公開checkから検査し、由来の二乗確保の再発を捕まえる。
// 小さな診断例では総確保の膨張を検出できない。既存のSystem委譲だけで計数する。
#[test]
fn long_constant_chain_has_bounded_check_allocations() {
    let _measurement = MEASUREMENT.lock().unwrap();
    let mut source = String::from("import Benitoite.Unofficial.Regex\nconst c0: String = \"[\"\n");
    for i in 1..20_000 {
        source.push_str(&format!("const c{i}: String = c{}\n", i - 1));
    }
    source.push_str("function sample() -> Unit\n bind _ <- Regex.compile(c19999)\nend function\n");
    ALLOCATED_BYTES.store(0, Ordering::Relaxed);
    COUNTING.store(true, Ordering::Relaxed);
    let start = Instant::now();
    let checked = pipeline::check_text(
        "chain.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    let elapsed = start.elapsed();
    COUNTING.store(false, Ordering::Relaxed);
    let bytes = ALLOCATED_BYTES.load(Ordering::Relaxed);
    eprintln!("20000 constants: {elapsed:?}, {bytes} allocated bytes");
    let errors: Vec<_> = checked
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .collect();
    assert_eq!(errors.len(), 1, "{:?}", checked.diagnostics);
    assert_eq!(errors[0].code, Some(benitoite::diag::DiagCode::E0457));
    assert_eq!(errors[0].secondary.len(), 2);
    assert_eq!(
        errors[0].notes,
        ["19998 other constant declarations omitted"]
    );
    // ソースの読み込み・名前解決・型検査の全確保の和に対する上限であり、64 MiBの評価予算とは別。
    assert!(
        bytes < 512 * 1024 * 1024,
        "quadratic allocation regression: {bytes}"
    );
}

// 関門: 同じ由来を持つ診断が連鎖全体の走査を繰り返す退行を総確保で検出する。
// 単発の長い連鎖では診断数との積を捕まえられない。公開checkと既存の計数器を使う。
#[test]
fn repeated_constant_diagnostics_share_bounded_origin_work() {
    let _measurement = MEASUREMENT.lock().unwrap();
    let mut source = String::from(
        "import Benitoite.Unofficial.Regex\nimport Benitoite.Unofficial.Scope\nconst c0: String = \"[\"\n",
    );
    for i in 1..5_000 {
        source.push_str(&format!("const c{i}: String = c{}\n", i - 1));
    }
    // 本体をまたぎ、RegexとScopeの双方で同じ由来を使う。
    for i in 0..2 {
        source.push_str(&format!("function sample{i}() -> Unit\n"));
        for _ in 0..250 {
            source.push_str(" bind _ <- Regex.compile(c4999)\n bind _ <- Scope.checkHost(pattern: c4999, host: \"localhost\")\n");
        }
        source.push_str("end function\n");
    }
    ALLOCATED_BYTES.store(0, Ordering::Relaxed);
    COUNTING.store(true, Ordering::Relaxed);
    let start = Instant::now();
    let checked = pipeline::check_text(
        "repeated.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    let elapsed = start.elapsed();
    COUNTING.store(false, Ordering::Relaxed);
    let bytes = ALLOCATED_BYTES.load(Ordering::Relaxed);
    eprintln!("5000 constants, 1000 diagnostics: {elapsed:?}, {bytes} allocated bytes");
    let errors: Vec<_> = checked
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .collect();
    assert_eq!(errors.len(), 1000, "{:?}", checked.diagnostics);
    for pair in errors.as_chunks::<2>().0 {
        assert_eq!(pair[0].code, Some(benitoite::diag::DiagCode::E0457));
        assert_eq!(pair[1].code, Some(benitoite::diag::DiagCode::E0459));
        for diagnostic in pair {
            assert_eq!(diagnostic.secondary.len(), 2);
            assert_eq!(
                diagnostic.notes,
                ["4998 other constant declarations omitted"]
            );
        }
    }
    assert!(
        bytes < 256 * 1024 * 1024,
        "repeated origin traversal regression: {bytes}"
    );
}
