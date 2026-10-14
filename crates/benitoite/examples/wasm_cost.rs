//! 外部の呼び出し、燃料、大きさごとのコンパイルの費用を測る
//! （設計書 07-02「測る項目」、02-09「外部の関数の実行」）。

use std::error::Error;
use std::hint::black_box;
use std::path::Path;
use std::time::Instant;
use wasmtime::component::{Component, Linker, Val};
use wasmtime::{Engine, Store, StoreLimits, StoreLimitsBuilder, Trap};

type Outcome<T> = Result<T, Box<dyn Error>>;
fn limits() -> benitoite::external::Limits {
    benitoite::external::Limits::default()
}
const LIBRARIES: &str = "crates/benitoite/testdata/packages/libraries.files";

fn store(engine: &Engine, fuel: u64) -> Outcome<Store<StoreLimits>> {
    let store_limits = StoreLimitsBuilder::new()
        .memory_size(usize::try_from(limits().memory())?)
        .build();
    let mut store = Store::new(engine, store_limits);
    store.limiter(|limits| limits);
    store.set_fuel(fuel)?;
    store.set_hostcall_fuel(usize::try_from(limits().transfer())?);
    store.set_epoch_deadline(1);
    Ok(store)
}

fn compile(engine: &Engine, bytes: &[u8], label: &str) -> Outcome<Component> {
    let start = Instant::now();
    let component = Component::from_binary(engine, bytes)?;
    println!(
        "{} label={label} bytes={} nanos={}",
        text::COMPILE,
        bytes.len(),
        start.elapsed().as_nanos()
    );
    Ok(component)
}

fn calls(engine: &Engine, count: u64) -> Outcome<()> {
    let bytes = wat::parse_str(
        r#"(component
      (core module $m
        (func (export "empty") (result i64) i64.const 7)
        (func (export "identity") (param i64) (result i64) local.get 0))
      (core instance $i (instantiate $m))
      (func (export "empty") (result s64) (canon lift (core func $i "empty")))
      (func (export "identity") (param "value" s64) (result s64) (canon lift (core func $i "identity"))))"#,
    )?;
    let component = compile(engine, &bytes, "calls")?;
    let linker = Linker::<StoreLimits>::new(engine);
    let start = Instant::now();
    for _ in 0..count {
        let mut store = store(engine, limits().fuel())?;
        black_box(linker.instantiate(&mut store, &component)?);
    }
    report(text::INSTANTIATE, count, start);
    // 二つのシグネチャとも、動的な値、型付き、新しいインスタンスを分ける。
    for name in ["empty", "identity"] {
        let mut store = store(engine, limits().fuel())?;
        let instance = linker.instantiate(&mut store, &component)?;
        let function = instance
            .get_func(&mut store, name)
            .ok_or(text::MISSING_FUNCTION)?;
        let arguments = if name == "empty" {
            vec![]
        } else {
            vec![Val::S64(7)]
        };
        let mut results = [Val::S64(0)];
        let start = Instant::now();
        for _ in 0..count {
            function.call(&mut store, &arguments, &mut results)?;
            black_box(&results);
        }
        report(&format!("{}-{name}", text::DYNAMIC), count, start);
        let empty = instance.get_typed_func::<(), (i64,)>(&mut store, "empty")?;
        let identity = instance.get_typed_func::<(i64,), (i64,)>(&mut store, "identity")?;
        let start = Instant::now();
        for _ in 0..count {
            if name == "empty" {
                black_box(empty.call(&mut store, ())?);
            } else {
                black_box(identity.call(&mut store, (7,))?);
            }
        }
        report(&format!("{}-{name}", text::TYPED), count, start);
        let start = Instant::now();
        for _ in 0..count {
            let mut fresh = crate::store(engine, limits().fuel())?;
            let instance = linker.instantiate(&mut fresh, &component)?;
            let function = instance
                .get_func(&mut fresh, name)
                .ok_or(text::MISSING_FUNCTION)?;
            function.call(&mut fresh, &arguments, &mut results)?;
            black_box(&results);
        }
        report(&format!("{}-{name}", text::FRESH), count, start);
    }
    Ok(())
}

fn report(label: &str, count: u64, start: Instant) {
    println!(
        "{} label={label} count={count} nanos={}",
        text::CALLS,
        start.elapsed().as_nanos()
    );
}

fn fuel(engine: &Engine, budget: u64) -> Outcome<()> {
    let bytes = wat::parse_str(
        r#"(component
      (core module $m (func (export "spin") (loop $again br $again)))
      (core instance $i (instantiate $m))
      (func (export "spin") (canon lift (core func $i "spin"))))"#,
    )?;
    let component = compile(engine, &bytes, "fuel")?;
    let mut store = store(engine, budget)?;
    let instance = Linker::new(engine).instantiate(&mut store, &component)?;
    let function = instance.get_typed_func::<(), ()>(&mut store, "spin")?;
    let start = Instant::now();
    let error = function
        .call(&mut store, ())
        .err()
        .ok_or(text::EXPECTED_TRAP)?;
    if error.downcast_ref::<Trap>() != Some(&Trap::OutOfFuel) {
        return Err(error.into());
    }
    let nanos = start.elapsed().as_nanos();
    let consumed = budget
        .checked_sub(store.get_fuel()?)
        .ok_or(text::FUEL_INCREASED)?;
    println!(
        "{} fuel={consumed} nanos={nanos} ns_per_fuel={}",
        text::FUEL,
        nanos as f64 / consumed as f64
    );
    Ok(())
}

fn fuzzy(engine: &Engine, quick: bool) -> Outcome<()> {
    let path = Path::new(LIBRARIES).join("fuzzy/wasm/fuzzy.wasm");
    let component = compile(engine, &std::fs::read(path)?, "fuzzy")?;
    for length in if quick {
        vec![10, 30]
    } else {
        vec![100, 1000, 3000]
    } {
        let mut store = store(engine, limits().fuel())?;
        let instance = Linker::new(engine).instantiate(&mut store, &component)?;
        let function = instance.get_typed_func::<(&str, &str), (i64,)>(&mut store, "distance")?;
        let a = "a".repeat(length);
        let b = "b".repeat(length);
        let start = Instant::now();
        let result = function.call(&mut store, (&a, &b))?;
        if result.0 != i64::try_from(length)? {
            return Err(text::WRONG_DISTANCE.into());
        }
        let nanos = start.elapsed().as_nanos();
        let consumed = limits()
            .fuel()
            .checked_sub(store.get_fuel()?)
            .ok_or(text::FUEL_INCREASED)?;
        println!(
            "{} length={length} fuel={consumed} nanos={nanos} ns_per_fuel={}",
            text::FUZZY,
            nanos as f64 / consumed as f64
        );
    }
    Ok(())
}

// 関数の数でコードを増やす形と、データだけを増やす形を区別する。
// WAT の文字数でなく、符号化したコンポーネントのバイト数で目標に合わせる。
fn synthetic(target: usize, kind: &str) -> Outcome<Vec<u8>> {
    if !(1024..=256 * 1024 * 1024).contains(&target) {
        return Err(text::INVALID_SIZE.into());
    }
    let mut module = String::from("(component (core module $m ");
    if kind == "data" {
        module.push_str(&format!(
            "(memory {}) (data (i32.const 0) \"",
            target.div_ceil(65536)
        ));
        module.push_str(&"x".repeat(target));
        module.push_str("\")");
    } else {
        let sequence = "local.get 0 i64.const 3 i64.mul local.set 0 local.get 0 i64.const 17 i64.gt_s if local.get 0 call 0 local.set 0 else local.get 0 i64.const 1 i64.add local.set 0 end ";
        let body = if kind == "nop" {
            "nop ".repeat(1024)
        } else {
            sequence.repeat(32)
        };
        // 参照される補助の関数も入れ、命令の選択とレジスタの割り当てを伴わせる。
        module.push_str("(func (param i64) (result i64) local.get 0 i64.const 7 i64.xor) ");
        let encoded = wat::parse_str(format!(
            "(module (func (param i64) (result i64) local.get 0) (func (param i64) (local i64) {body}))"
        ))?;
        let per_function = encoded.len().saturating_sub(32).max(1);
        let count = target.div_ceil(per_function);
        for _ in 0..count {
            module.push_str("(func (param i64) (local i64) ");
            module.push_str(&body);
            module.push(')');
        }
    }
    module.push_str("))");
    Ok(wat::parse_str(module)?)
}

fn main() -> Outcome<()> {
    let mut arguments: Vec<String> = std::env::args().skip(1).collect();
    let quick = arguments.iter().any(|arg| arg == "--quick");
    arguments.retain(|arg| arg != "--quick");
    let engine = Engine::new(&benitoite::external::engine_config())?;
    match arguments.first().map(String::as_str) {
        None if quick => {
            calls(&engine, 20)?;
            fuel(&engine, 10_000)?;
            fuzzy(&engine, true)?;
            compile(&engine, &synthetic(1024, "code")?, "code")?;
            compile(&engine, &synthetic(1024, "data")?, "data")?;
            Ok(())
        }
        Some("calls") => calls(&engine, if quick { 20 } else { 10_000 }),
        Some("fuel") => fuel(&engine, if quick { 10_000 } else { limits().fuel() }),
        Some("fuzzy") => fuzzy(&engine, quick),
        Some("compile") => {
            let path = arguments.get(1).ok_or(text::USAGE)?;
            compile(&engine, &std::fs::read(path)?, path)?;
            Ok(())
        }
        Some("synthesize") => {
            let size = arguments.get(1).ok_or(text::USAGE)?.parse::<usize>()?;
            let kind = arguments.get(2).ok_or(text::USAGE)?;
            if !["code", "data", "nop"].contains(&kind.as_str()) {
                return Err(text::USAGE.into());
            }
            let path = arguments.get(3).ok_or(text::USAGE)?;
            let bytes = synthetic(size, kind)?;
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(path)?;
            std::io::Write::write_all(&mut file, &bytes)?;
            Ok(())
        }
        None | Some(_) => Err(text::USAGE.into()),
    }
}

mod text {
    pub const USAGE: &str = "usage: wasm_cost [--quick] [calls|fuel|fuzzy|compile PATH|synthesize BYTES code|data|nop PATH]";
    pub const COMPILE: &str = "compile";
    pub const CALLS: &str = "calls";
    pub const FUEL: &str = "fuel";
    pub const FUZZY: &str = "fuzzy";
    pub const INSTANTIATE: &str = "instantiate";
    pub const DYNAMIC: &str = "dynamic-retained";
    pub const TYPED: &str = "typed-retained";
    pub const FRESH: &str = "dynamic-fresh";
    pub const MISSING_FUNCTION: &str = "missing component function";
    pub const EXPECTED_TRAP: &str = "the fuel loop returned without a trap";
    pub const FUEL_INCREASED: &str = "remaining fuel exceeds its initial budget";
    pub const WRONG_DISTANCE: &str = "unexpected Fuzzy distance";
    pub const INVALID_SIZE: &str = "synthetic size must be between 1024 and 268435456 bytes";
}
