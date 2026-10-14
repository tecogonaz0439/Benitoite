//! 外部の関数の生成・コンパイル・受け渡しを直接計時する（設計書 07-02「測る項目」）。
//! 内部の生成器と復号器はこの例のクレート内に読み込み、公開 API は増やさない。

#[path = "../src/base/mod.rs"]
pub mod base;
#[path = "../src/builtins/mod.rs"]
pub mod builtins;
#[path = "../src/bytecode/mod.rs"]
pub mod bytecode;
#[path = "../src/cli/mod.rs"]
pub mod cli;
#[path = "../src/diag/mod.rs"]
pub mod diag;
#[path = "../src/external/mod.rs"]
pub mod external;
#[path = "../src/ir/mod.rs"]
pub mod ir;
#[path = "../src/modules/mod.rs"]
pub mod modules;
#[path = "../src/pipeline.rs"]
pub mod pipeline;
#[path = "../src/prelude/mod.rs"]
pub mod prelude;
#[path = "../src/refinterp/mod.rs"]
pub mod refinterp;
#[path = "../src/resolve/mod.rs"]
pub mod resolve;
#[path = "../src/runtime/mod.rs"]
pub mod runtime;
#[path = "../src/syntax/mod.rs"]
pub mod syntax;
#[path = "../src/typeck/mod.rs"]
pub mod typeck;
#[path = "../src/types/mod.rs"]
pub mod types;
#[path = "../src/vm/mod.rs"]
pub mod vm;

use external::adapter::{codec::CodecPlan, component::ComponentGroup};
use external::{ExternalSpec, WitPlan as P};
use runtime::heap::{CtorTag, FieldsKind, Heap, HeapConfig, NoGcCtx, Value};
use serde_json::{Value as Json, json};
use std::{path::Path, sync::Arc, time::Instant};
use wasmtime::component::{Component, Linker, Val};
use wasmtime::{Engine, Store, StoreLimits, StoreLimitsBuilder};

type Outcome<T> = Result<T, String>;

mod text {
    //! 計時の報告に載せる比較範囲の説明をまとめる。
    pub const HOST_CONVERSION_SCOPE: &str =
        "adapter-codec-only; typed/dynamic host conversion is unmeasured and cannot be compared";
}

fn error(e: impl std::fmt::Debug) -> String {
    format!("{e:?}")
}

// JSON は独立した期待値の読み込みだけに使い、生成器の出力から期待値を作らない。
fn val(plan: &P, value: &Json) -> Outcome<Val> {
    let signed = || value.as_i64().ok_or_else(|| error(value));
    let unsigned = || value.as_u64().ok_or_else(|| error(value));
    let float = || value.as_f64().ok_or_else(|| error(value));
    Ok(match plan {
        P::S8 => Val::S8(i8::try_from(signed()?).map_err(error)?),
        P::S16 => Val::S16(i16::try_from(signed()?).map_err(error)?),
        P::S32 => Val::S32(i32::try_from(signed()?).map_err(error)?),
        P::S64 => Val::S64(signed()?),
        P::U8 => Val::U8(u8::try_from(unsigned()?).map_err(error)?),
        P::U16 => Val::U16(u16::try_from(unsigned()?).map_err(error)?),
        P::U32 => Val::U32(u32::try_from(unsigned()?).map_err(error)?),
        P::U64 => Val::U64(unsigned()?),
        P::F32 => Val::Float32(float()? as f32),
        P::F64 => Val::Float64(float()?),
        P::Bool => Val::Bool(value.as_bool().ok_or_else(|| error(value))?),
        P::Char => {
            let mut chars = value.as_str().ok_or_else(|| error(value))?.chars();
            let ch = chars.next().ok_or_else(|| error(value))?;
            if chars.next().is_some() {
                return Err(error(value));
            }
            Val::Char(ch)
        }
        P::String => Val::String(value.as_str().ok_or_else(|| error(value))?.into()),
        P::Bytes => Val::List(
            array(value)?
                .iter()
                .map(|v| val(&P::U8, v))
                .collect::<Outcome<_>>()?,
        ),
        P::List(p) => Val::List(
            array(value)?
                .iter()
                .map(|v| val(p, v))
                .collect::<Outcome<_>>()?,
        ),
        P::Map(k, v) => Val::Map(
            array(value)?
                .iter()
                .map(|pair| {
                    let [a, b] = array(pair)? else {
                        return Err(error(pair));
                    };
                    Ok((val(k, a)?, val(v, b)?))
                })
                .collect::<Outcome<_>>()?,
        ),
        P::Tuple(ps) | P::TupleFields(ps) | P::ConstructorTuple { fields: ps, .. } => {
            let values = array(value)?;
            if ps.len() != values.len() {
                return Err(error(value));
            }
            Val::Tuple(
                ps.iter()
                    .zip(values)
                    .map(|(p, v)| val(p, v))
                    .collect::<Outcome<_>>()?,
            )
        }
        P::Record { fields } => Val::Record(
            fields
                .iter()
                .map(|(name, p)| {
                    Ok((
                        name.clone(),
                        val(p, value.get(name).ok_or_else(|| error(value))?)?,
                    ))
                })
                .collect::<Outcome<_>>()?,
        ),
        P::Variant { cases } => {
            let name = value
                .get("case")
                .and_then(Json::as_str)
                .ok_or_else(|| error(value))?;
            let (_, _, payload) = cases
                .iter()
                .find(|(n, _, _)| n == name)
                .ok_or_else(|| error(value))?;
            Val::Variant(
                name.into(),
                payload
                    .as_ref()
                    .map(|p| {
                        val(p, value.get("payload").ok_or_else(|| error(value))?).map(Box::new)
                    })
                    .transpose()?,
            )
        }
        P::Flags { .. } => Val::Flags(
            array(value)?
                .iter()
                .map(|v| v.as_str().map(String::from).ok_or_else(|| error(v)))
                .collect::<Outcome<_>>()?,
        ),
        P::Enum { .. } => Val::Enum(value.as_str().ok_or_else(|| error(value))?.into()),
        P::Borrow(_) | P::Own(_) | P::Option(_) | P::Result { .. } => {
            return Err(format!("unsupported fixture plan: {plan:?}"));
        }
    })
}

fn array(value: &Json) -> Outcome<&[Json]> {
    value
        .as_array()
        .map(Vec::as_slice)
        .ok_or_else(|| error(value))
}

fn language<'e>(ctx: &NoGcCtx<'e>, plan: &P, value: &Val) -> Outcome<Value<'e>> {
    use builtins::table::tags;
    let fields = |tag, items: Vec<Value<'e>>| {
        ctx.alloc_fields(FieldsKind::Ctor, tag, &items)
            .map_err(error)
    };
    Ok(match (plan, value) {
        (P::S8, Val::S8(v)) => Value::Int8(*v),
        (P::S16, Val::S16(v)) => Value::Int16(*v),
        (P::S32, Val::S32(v)) => Value::Int32(*v),
        (P::S64, Val::S64(v)) => Value::Int(*v),
        (P::U8, Val::U8(v)) => Value::Byte(*v),
        (P::U16, Val::U16(v)) => Value::UInt16(*v),
        (P::U32, Val::U32(v)) => Value::UInt32(*v),
        (P::U64, Val::U64(v)) => Value::UInt64(*v),
        (P::F32, Val::Float32(v)) => Value::Float32(*v),
        (P::F64, Val::Float64(v)) => Value::Float(*v),
        (P::Bool, Val::Bool(v)) => Value::Bool(*v),
        (P::Char, Val::Char(v)) => Value::Char(*v),
        (P::String, Val::String(v)) => ctx.alloc_str(v, "benchmark fixture").map_err(error)?,
        (P::Bytes, Val::List(vs)) => {
            let bytes = vs
                .iter()
                .map(|v| {
                    if let Val::U8(v) = v {
                        Ok(*v)
                    } else {
                        Err(error(v))
                    }
                })
                .collect::<Outcome<Vec<_>>>()?;
            ctx.alloc_bytes(&bytes, "benchmark fixture")
                .map_err(error)?
        }
        (P::List(p), Val::List(vs)) => runtime::list::from_values(
            ctx,
            &vs.iter()
                .map(|v| language(ctx, p, v))
                .collect::<Outcome<Vec<_>>>()?,
            "benchmark fixture",
        )
        .map_err(error)?,
        (P::Map(k, v), Val::Map(vs)) => {
            let mut map = Value::EmptyMap;
            for (a, b) in vs {
                map = runtime::map::map_insert(
                    ctx,
                    map,
                    language(ctx, k, a)?,
                    language(ctx, v, b)?,
                    "benchmark fixture",
                )
                .map_err(error)?;
            }
            map
        }
        (P::Record { fields: ps }, Val::Record(vs)) => fields(
            tags::RECORD,
            ps.iter()
                .zip(vs)
                .map(|((_, p), (_, v))| language(ctx, p, v))
                .collect::<Outcome<_>>()?,
        )?,
        (P::Tuple(ps) | P::ConstructorTuple { fields: ps, .. }, Val::Tuple(vs)) => {
            let tag = if let P::ConstructorTuple { tag, .. } = plan {
                *tag
            } else {
                match ps.len() {
                    2 => tags::PAIR,
                    3 => tags::TRIPLE,
                    _ => return Err(error(plan)),
                }
            };
            fields(
                tag,
                ps.iter()
                    .zip(vs)
                    .map(|(p, v)| language(ctx, p, v))
                    .collect::<Outcome<_>>()?,
            )?
        }
        (P::Variant { cases }, Val::Variant(name, value)) => {
            let (_, tag, p) = cases
                .iter()
                .find(|(n, _, _)| n == name)
                .ok_or_else(|| error(name))?;
            match (p.as_deref(), value.as_deref()) {
                (None, None) => Value::Tag(CtorTag(*tag)),
                (Some(P::TupleFields(ps)), Some(Val::Tuple(vs))) => fields(
                    *tag,
                    ps.iter()
                        .zip(vs)
                        .map(|(p, v)| language(ctx, p, v))
                        .collect::<Outcome<_>>()?,
                )?,
                (Some(p), Some(v)) => fields(*tag, vec![language(ctx, p, v)?])?,
                _ => return Err(error(value)),
            }
        }
        (P::Flags { cases }, Val::Flags(names)) => {
            let mut set = Value::EmptySet;
            for name in names {
                let (_, tag) = cases
                    .iter()
                    .find(|(n, _)| n == name)
                    .ok_or_else(|| error(name))?;
                set = runtime::map::set_insert(
                    ctx,
                    set,
                    Value::Tag(CtorTag(*tag)),
                    "benchmark fixture",
                )
                .map_err(error)?;
            }
            set
        }
        _ => return Err(format!("unsupported language fixture: {plan:?} {value:?}")),
    })
}

fn store(engine: &Engine) -> Outcome<Store<StoreLimits>> {
    let limits = external::Limits::default();
    let mut store = Store::new(
        engine,
        StoreLimitsBuilder::new()
            .memory_size(usize::try_from(limits.memory()).map_err(error)?)
            .build(),
    );
    store.limiter(|s| s);
    store.set_fuel(limits.fuel()).map_err(error)?;
    store.set_hostcall_fuel(usize::try_from(limits.transfer()).map_err(error)?);
    store.set_epoch_deadline(1);
    Ok(store)
}

fn typed_call(
    store: &mut Store<StoreLimits>,
    instance: &wasmtime::component::Instance,
    name: &str,
    args: &[Val],
) -> Outcome<(Val, u128)> {
    // この入力群の型付き宣言は一引数で、引数と戻り値の種類が同じである。
    macro_rules! one {
        ($ty:ty, $arg:expr, $variant:ident) => {{
            let f = instance
                .get_typed_func::<($ty,), ($ty,)>(&mut *store, name)
                .map_err(error)?;
            let started = Instant::now();
            let (out,) = f.call(&mut *store, ($arg,)).map_err(error)?;
            (Val::$variant(out), started.elapsed().as_nanos())
        }};
    }
    Ok(match args {
        [Val::S64(v)] => one!(i64, *v, S64),
        [Val::Float64(v)] => one!(f64, *v, Float64),
        [Val::String(v)] => {
            let f = instance
                .get_typed_func::<(&str,), (String,)>(&mut *store, name)
                .map_err(error)?;
            let started = Instant::now();
            let (out,) = f.call(&mut *store, (v.as_str(),)).map_err(error)?;
            (Val::String(out), started.elapsed().as_nanos())
        }
        [Val::List(vs)] => {
            let bytes = vs
                .iter()
                .map(|v| {
                    if let Val::U8(v) = v {
                        Ok(*v)
                    } else {
                        Err(error(v))
                    }
                })
                .collect::<Outcome<Vec<_>>>()?;
            let f = instance
                .get_typed_func::<(&[u8],), (Vec<u8>,)>(&mut *store, name)
                .map_err(error)?;
            let started = Instant::now();
            let (out,) = f.call(&mut *store, (&bytes,)).map_err(error)?;
            let call = started.elapsed().as_nanos();
            let out = Val::List(out.into_iter().map(Val::U8).collect());
            (out, call)
        }
        _ => return Err(format!("unsupported typed fixture: {args:?}")),
    })
}

fn measure(
    engine: &Engine,
    spec: &Arc<ExternalSpec>,
    fixtures: &[Json],
    route: &str,
    rounds: usize,
) -> Outcome<Json> {
    let mut budget = 1_000_000;
    let started = Instant::now();
    let group = if route == "adapter" {
        ComponentGroup::prepare_with_budget(&[Arc::clone(spec)], &mut budget)
            .map_err(error)?
            .pop()
    } else {
        None
    };
    let prepare = if group.is_some() {
        started.elapsed().as_nanos()
    } else {
        0
    };
    let started = Instant::now();
    let bytes = if let Some(g) = &group {
        g.generate_with_budget(external::adapter::component::GENERATION_LIMIT, &mut budget)
            .map_err(error)?
    } else {
        spec.component.bytes.to_vec()
    };
    let generation = if group.is_some() {
        started.elapsed().as_nanos()
    } else {
        0
    };
    let started = Instant::now();
    let component = Component::from_binary(engine, &bytes).map_err(error)?;
    let compile = started.elapsed().as_nanos();
    let results: Vec<_> = spec.result.iter().cloned().collect();
    let input_codec = CodecPlan::new(&spec.params, &mut budget).map_err(error)?;
    let output_codec = CodecPlan::new(&results, &mut budget).map_err(error)?;
    let mut samples = Vec::new();
    for round in 0..rounds {
        for (fixture_index, fixture) in fixtures.iter().enumerate() {
            let raw_args = array(fixture.get("arguments").ok_or_else(|| error(fixture))?)?;
            if raw_args.len() != spec.params.len() {
                return Err(error(fixture));
            }
            let expected = val(
                spec.result.as_ref().ok_or_else(|| error(spec))?,
                fixture.get("result").ok_or_else(|| error(fixture))?,
            )?;
            let mut heap = Heap::new(HeapConfig::default());
            let sample = heap.epoch(|ctx| -> Outcome<Json> {
                let args = spec.params.iter().zip(raw_args).map(|(p, v)| val(p, v)).collect::<Outcome<Vec<_>>>()?;
                let language_args = spec.params.iter().zip(&args).map(|(p, v)| language(ctx, p, v)).collect::<Outcome<Vec<_>>>()?;
                let started = Instant::now();
                let input = if group.is_some() {
                    Some(input_codec.encode(ctx, &language_args, external::Limits::default().transfer()).map_err(error)?)
                } else { None };
                let pack = input.as_ref().map(|_| started.elapsed().as_nanos());
                let mut store = store(engine)?;
                let mut linker = Linker::new(engine);
                if group.is_some() { external::adapter::runtime::link_failure(&mut linker).map_err(error)?; }
                let started = Instant::now();
                let instance = linker.instantiate(&mut store, &component).map_err(error)?;
                let instantiate = started.elapsed().as_nanos();
                let export = group.as_ref().and_then(|g| g.exports.get(&spec.id)).map_or(spec.export.as_str(), String::as_str);
                let (call, decode, transfer, construction) = if let Some(input) = input {
                    let f = instance.get_typed_func::<(&[u8],), (Vec<u8>,)>(&mut store, export).map_err(error)?;
                    let started = Instant::now();
                    let (output,) = f.call(&mut store, (&input.bytes,)).map_err(error)?;
                    let call = started.elapsed().as_nanos();
                    let started = Instant::now();
                    let decoded = output_codec.decode(ctx, &output, external::Limits::default().transfer()).map_err(error)?;
                    let decode = started.elapsed().as_nanos();
                    let [actual] = decoded.values.as_slice() else { return Err(error(spec)); };
                    let expected_value = language(ctx, spec.result.as_ref().ok_or_else(|| error(spec))?, &expected)?;
                    if !runtime::equal::values_equal(ctx, *actual, expected_value).map_err(error)? { return Err(format!("result mismatch: {}", spec.function)); }
                    (call, Some(decode), json!({"arguments": input.bytes.len(), "results": output.len()}),
                        json!(input.construction_bytes.checked_add(decoded.construction_bytes).ok_or("construction overflow")?))
                } else {
                    let (out, call) = if route == "typed" { typed_call(&mut store, &instance, export, &args)? } else {
                        let f = instance.get_func(&mut store, export).ok_or_else(|| error(spec))?;
                        let mut out = [Val::Bool(false)];
                        let started = Instant::now();
                        f.call(&mut store, &args, &mut out).map_err(error)?;
                        let call = started.elapsed().as_nanos();
                        let [out] = out;
                        (out, call)
                    };
                    let actual = language(ctx, spec.result.as_ref().ok_or_else(|| error(spec))?, &out)?;
                    let expected_value = language(ctx, spec.result.as_ref().ok_or_else(|| error(spec))?, &expected)?;
                    if !runtime::equal::values_equal(ctx, actual, expected_value).map_err(error)? { return Err(format!("result mismatch: {} {out:?} {expected:?}", spec.function)); }
                    // 例の変換は処理系の typed/dynamic の変換ではないため、比較用の計時に含めない。
                    (call, None, Json::Null, Json::Null)
                };
                Ok(json!({"round": round, "fixture": fixture_index, "cache": if round == 0 && fixture_index == 0 { "cold" } else { "same-session" },
                    "instantiate_nanos": instantiate, "call_nanos": call, "host_pack_nanos": pack, "host_decode_nanos": decode,
                    "fuel": external::Limits::default().fuel().checked_sub(store.get_fuel().map_err(error)?).ok_or("fuel increased")?,
                    "transfer_bytes": transfer, "construction_bytes": construction}))
            })?;
            samples.push(sample);
        }
    }
    Ok(
        json!({"function": spec.function, "export": spec.export, "route": route, "prepare_nanos": prepare, "generation_nanos": generation,
        "compile_nanos": compile, "component_bytes": bytes.len(), "samples": samples}),
    )
}

fn execute() -> Outcome<()> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let [script, case, rounds] = args.as_slice() else {
        return Err("usage: wit_transfer_cost SCRIPT CASE ROUNDS".into());
    };
    let rounds: usize = rounds.parse().map_err(error)?;
    if rounds == 0 {
        return Err("rounds must be positive".into());
    }
    let checked = pipeline::check_path(
        Path::new(script),
        pipeline::CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
    .map_err(error)?;
    let program = checked.program.ok_or_else(|| error(checked.diagnostics))?;
    let core = pipeline::desugar_checked(&program).map_err(error)?;
    let compiled = pipeline::compile(&core, checked.sources).map_err(error)?;
    let fixtures: Json = serde_json::from_slice(
        &std::fs::read("tools/bench/wit-transfer/expected/small-values.json").map_err(error)?,
    )
    .map_err(error)?;
    let functions = fixtures
        .get("cases")
        .and_then(|v| v.get(case))
        .and_then(Json::as_object)
        .ok_or_else(|| error(case))?;
    let engine = Engine::new(&external::engine_config()).map_err(error)?;
    let mut measurements = Vec::new();
    for (name, fixtures) in functions {
        let spec = &compiled
            .externals
            .functions
            .iter()
            .find(|f| f.spec.function == *name)
            .ok_or_else(|| format!("missing fixture declaration: {name}"))?
            .spec;
        let route = if matches!(spec.route, external::ExternalRoute::Typed(_)) {
            "typed"
        } else {
            "adapter"
        };
        measurements.push(measure(&engine, spec, array(fixtures)?, route, rounds)?);
        measurements.push(measure(&engine, spec, array(fixtures)?, "dynamic", rounds)?);
    }
    println!(
        "{}",
        json!({"schema_version": 1, "case": case, "scope": "isolated-functions-fresh-store-shared-component", "host_conversion_scope": text::HOST_CONVERSION_SCOPE, "measurements": measurements})
    );
    Ok(())
}

fn main() -> std::process::ExitCode {
    match execute() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{e}");
            std::process::ExitCode::FAILURE
        }
    }
}
