//! 測定の例の引数と統計の出力（設計書 07-02、実装プラン R12）。

use benitoite::runtime::heap::{HeapConfig, HeapStats};

pub mod text {
    pub const OPTION: &str = "invalid benchmark option";
    pub const COUNT: &str = "expected a positive count";
}

/// 二つの例が共通に読むヒープの設定と引数。
pub struct Options {
    pub heap: HeapConfig,
    pub check_only: bool,
    pub args: Vec<String>,
}

/// 設定の後の `--` から先を、負荷の引数として返す。
pub fn options() -> Result<Options, String> {
    let mut heap = HeapConfig::default();
    let mut check_only = false;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--" => {
                return Ok(Options {
                    heap,
                    check_only,
                    args: args.collect(),
                });
            }
            "--factor" => {
                heap.trigger_factor_percent = args
                    .next()
                    .ok_or(text::OPTION)?
                    .parse()
                    .map_err(|_| text::OPTION)?
            }
            "--no-reuse" => heap.reuse = false,
            "--check-only" => check_only = true,
            _ => return Err(text::OPTION.into()),
        }
    }
    Err(text::OPTION.into())
}

/// HeapStats の全項目と段別の時間を一行で出す。
pub fn emit(
    stats: &HeapStats,
    check: u128,
    compile: u128,
    run: u128,
    total: u128,
    remaining: Option<usize>,
) -> Result<(), String> {
    let pauses = stats
        .pause_nanos
        .iter()
        .map(u64::to_string)
        .collect::<Vec<_>>()
        .join(",");
    let denominator = stats
        .allocations
        .checked_add(stats.reuses)
        .ok_or(text::COUNT)?;
    // 割合の算出は Python に任せ、整数の元の値を失わずに出す（実装プラン R12「記録する項目」）。
    eprintln!(
        "stage1 allocations={} allocated_bytes={} live_bytes={} peak_heap_bytes={} collections={} roots_traced={} rc_increments={} rc_decrements={} rc_elided={} reuses={} frees={} reuse_denominator={} pause_nanos={} check_nanos={} compile_nanos={} run_nanos={} total_nanos={} remaining={}",
        stats.allocations,
        stats.allocated_bytes,
        stats.live_bytes,
        stats.peak_heap_bytes,
        stats.collections,
        stats.roots_traced,
        stats.rc_increments,
        stats.rc_decrements,
        stats.rc_elided,
        stats.reuses,
        stats.frees,
        denominator,
        pauses,
        check,
        compile,
        run,
        total,
        remaining.map_or_else(|| "na".into(), |v| v.to_string())
    );
    Ok(())
}
