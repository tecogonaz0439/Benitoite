//! 循環の4形を公開のヒープ API で測る。VM の Reference の統合は対象外（実装プラン R12）。

#[path = "stage1_support/mod.rs"]
mod support;

use benitoite::runtime::Stop;
use benitoite::runtime::heap::Heap;
use benitoite::runtime::heap::{FieldsKind, NoGcCtx, RootStack, Value};
use std::process::ExitCode;
use std::time::Instant;

fn main() -> ExitCode {
    match execute() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(2)
        }
    }
}

fn execute() -> Result<(), String> {
    let options = support::options()?;
    let [shape, rounds, size] = options.args.as_slice() else {
        return Err(text::USAGE.into());
    };
    if options.check_only {
        return Err(text::USAGE.into());
    }
    let rounds = positive(rounds)?;
    let size = positive(size)?;
    let mut config = options.heap;
    // RC の循環の閾値未満でも毎回回収させる。通常の VM の時間測定とは分ける（実装プラン R12）。
    config.stress = true;
    let mut heap = Heap::new(config);
    let mut roots = RootStack::new();
    let started = Instant::now();
    for _ in 0..rounds {
        heap.epoch(|ctx| {
            let cell = make_cycle(ctx, shape, size)?;
            roots.push(ctx, cell);
            roots.truncate(ctx, 0);
            Ok::<(), Stop>(())
        })
        .map_err(|e| format!("{e:?}"))?;
        heap.collect(&roots);
        if let Some(fault) = heap.take_fault() {
            return Err(format!("{fault:?}"));
        }
    }
    let run = started.elapsed().as_nanos();
    let remaining = heap.object_ids().len();
    if remaining != 0 {
        return Err(format!("{remaining}"));
    }
    println!("remaining={remaining}");
    support::emit(&heap.stats(), 0, 0, run, run, Some(remaining))
}

fn positive(s: &str) -> Result<u32, String> {
    s.parse::<u32>()
        .ok()
        .filter(|n| *n > 0)
        .ok_or_else(|| support::text::COUNT.into())
}

fn make_cycle<'e>(ctx: &NoGcCtx<'e>, shape: &str, size: u32) -> Result<Value<'e>, Stop> {
    let first = ctx.alloc_cell(Value::Unit);
    match shape {
        "self" => ctx.cell_set(first, first)?,
        "pair" => {
            let second = ctx.alloc_cell(first);
            ctx.cell_set(first, second)?;
        }
        "ring" => {
            let mut previous = first;
            for _ in 0..size {
                let next = ctx.alloc_cell(Value::Unit);
                let fields = ctx.alloc_fields(FieldsKind::Ctor, 0, &[next, Value::Int(1)])?;
                ctx.cell_set(previous, fields)?;
                previous = next;
            }
            ctx.cell_set(previous, first)?;
        }
        "list" => {
            // 各要素で同じセルを指す長いリストをセルへ入れる。ListCell の長さと末尾も
            // 通常のリストに合わせ、循環の候補がリスト全体を辿る負荷にする（実装プラン R12）。
            let mut tail = Value::EmptyList;
            for length in 1..=size {
                tail = ctx.alloc_fields(FieldsKind::ListCell, length, &[first, tail])?;
            }
            ctx.cell_set(first, tail)?;
        }
        _ => return Err(Stop::Internal(text::SHAPE.into())),
    }
    Ok(first)
}

mod text {
    pub const USAGE: &str =
        "usage: stage1_heap_bench [--factor N] [--no-reuse] -- SHAPE ROUNDS SIZE";
    pub const SHAPE: &str = "invalid cycle shape";
}
