//! 普通の呼び出しと戻りは容量の伸長以外に確保しない（設計書 07-02「性能の関門」、実装プラン R15）。
#![cfg(not(feature = "gc-stress"))]
// このバイナリだけで System への委譲を数える（実装プラン 00-02 の R15 の例外）。
#![allow(unsafe_code)]
// テストの失敗は panic で表す（実装プラン 00-02）。
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
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

struct CountedSystem;
static COUNTING: AtomicBool = AtomicBool::new(false);
static ALLOCATIONS: AtomicUsize = AtomicUsize::new(0);
#[global_allocator]
static ALLOCATOR: CountedSystem = CountedSystem;

fn count() {
    if COUNTING.load(Ordering::Relaxed) {
        ALLOCATIONS.fetch_add(1, Ordering::Relaxed);
    }
}
// SAFETY: System の契約を変えず、受けた配置・ポインタ・大きさをそのまま渡す。
unsafe impl GlobalAlloc for CountedSystem {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        count();
        // SAFETY: GlobalAlloc の呼び出し側が保証した layout を、そのまま System に渡す。
        unsafe { System.alloc(layout) }
    }
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        count();
        // SAFETY: GlobalAlloc の呼び出し側が保証した layout を、そのまま System に渡す。
        unsafe { System.alloc_zeroed(layout) }
    }
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        count();
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
// 引数の Vec の復活を検出できない。公開のパイプラインと実行の入口だけを使う（R15）。
#[test]
fn ordinary_calls_and_returns_allocate_only_for_capacity_growth() {
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
}
