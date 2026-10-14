//! 平らな型と呼び出し型を、独立した期待値と正準 ABI の検証で確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::emit::{CoreSignature, CoreType};
use super::layout::{FunctionAbi, LayoutTable};
use crate::external::WitPlan as P;
use wasm_encoder::{
    CodeSection, ExportKind, ExportSection, Function, FunctionSection, ImportSection, Instruction,
    MemArg, MemorySection, MemoryType, Module, TypeSection, ValType,
};
use wasmtime::component::{Component, Linker, Val};

fn table(plans: &[P]) -> LayoutTable {
    LayoutTable::new(plans, &mut 100_000).unwrap()
}

fn variant(payloads: Vec<Option<P>>) -> P {
    P::Variant {
        cases: payloads
            .into_iter()
            .enumerate()
            .map(|(i, p)| (format!("c{i}"), i as u32, p.map(Box::new)))
            .collect(),
    }
}

#[test]
fn flattening_preserves_scalar_widths_field_order_and_variant_slots() {
    // 関門: 表の入口で ABI の型列を守る。配置の試験では見えない型・欄順・合流の退行を捕まえる。
    // 期待値は正準 ABI から手で列挙し、生成器や非公開の計算を使って作らない。
    use CoreType::{F32, F64, I32, I64};
    for (plan, expected) in [
        (P::S8, vec![I32]),
        (P::S16, vec![I32]),
        (P::S32, vec![I32]),
        (P::S64, vec![I64]),
        (P::U8, vec![I32]),
        (P::U16, vec![I32]),
        (P::U32, vec![I32]),
        (P::U64, vec![I64]),
        (P::F32, vec![F32]),
        (P::F64, vec![F64]),
        (P::Bool, vec![I32]),
        (P::Char, vec![I32]),
        (P::String, vec![I32, I32]),
        (P::Bytes, vec![I32, I32]),
        (P::List(Box::new(P::F64)), vec![I32, I32]),
        (P::Map(Box::new(P::U8), Box::new(P::F64)), vec![I32, I32]),
        (
            P::Enum {
                cases: vec![("a".into(), 7)],
            },
            vec![I32],
        ),
        (
            P::Flags {
                cases: (0..32).map(|i| (format!("c{i}"), i)).collect(),
            },
            vec![I32],
        ),
        (P::Record { fields: vec![] }, vec![]),
        (
            P::Tuple(vec![P::U8, P::F32, P::U64, P::F64]),
            vec![I32, F32, I64, F64],
        ),
        (P::TupleFields(vec![P::F64, P::F32]), vec![F64, F32]),
        (
            P::ConstructorTuple {
                tag: 55,
                fields: vec![P::S64, P::String],
            },
            vec![I64, I32, I32],
        ),
        (
            P::Record {
                fields: vec![
                    ("a".into(), P::F64),
                    ("b".into(), P::Tuple(vec![P::F32, P::U8])),
                ],
            },
            vec![F64, F32, I32],
        ),
        (P::Option(Box::new(P::F32)), vec![I32, F32]),
        (
            P::Result {
                ok: None,
                err: None,
            },
            vec![I32],
        ),
        (
            P::Result {
                ok: Some(Box::new(P::F32)),
                err: Some(Box::new(P::U32)),
            },
            vec![I32, I32],
        ),
        (
            P::Result {
                ok: Some(Box::new(P::F64)),
                err: Some(Box::new(P::S64)),
            },
            vec![I32, I64],
        ),
        (
            variant(vec![None, Some(P::F32), Some(P::F32)]),
            vec![I32, F32],
        ),
        (variant(vec![Some(P::F64), Some(P::F64)]), vec![I32, F64]),
        (
            variant(vec![
                Some(P::TupleFields(vec![P::F32, P::F64, P::F32])),
                Some(P::TupleFields(vec![P::U32, P::F32])),
            ]),
            vec![I32, I32, I64, F32],
        ),
        (
            variant(vec![Some(P::Option(Box::new(P::F32))), Some(P::U64)]),
            vec![I32, I64, F32],
        ),
    ] {
        let layout = table(&[plan]);
        assert_eq!(layout.roots.flat, expected);
        assert_eq!(layout.nodes[layout.roots.fields[0].node].flat, expected);
    }
    assert_eq!(
        table(&[P::F32, P::String, P::S64]).roots.flat,
        [F32, I32, I32, I64]
    );
}

fn raw(value: &wasmtime::Val) -> u64 {
    match value {
        wasmtime::Val::I32(v) => u64::from(*v as u32),
        wasmtime::Val::I64(v) => *v as u64,
        wasmtime::Val::F32(v) => u64::from(*v),
        wasmtime::Val::F64(v) => *v,
        wasmtime::Val::V128(_)
        | wasmtime::Val::FuncRef(_)
        | wasmtime::Val::ExternRef(_)
        | wasmtime::Val::AnyRef(_)
        | wasmtime::Val::ExnRef(_)
        | wasmtime::Val::ContRef(_) => panic!("numeric value expected"),
    }
}

fn core_value(ty: CoreType, bits: u64) -> wasmtime::Val {
    match ty {
        CoreType::I32 => wasmtime::Val::I32(bits as i32),
        CoreType::I64 => wasmtime::Val::I64(bits as i64),
        CoreType::F32 => wasmtime::Val::F32(bits as u32),
        CoreType::F64 => wasmtime::Val::F64(bits),
    }
}

#[test]
fn variant_joins_and_generated_conversions_preserve_bits() {
    // 関門: 実際の Wasm 命令の出力を確認し、数値変換・符号拡張・切り戻し漏れを捕まえる。
    // コア型列だけの試験は命令を実行せず、この誤りを検出できない。公開範囲は広げない。
    use CoreType::{F32, F64, I32, I64};
    let types = [I32, I64, F32, F64];
    let expected = [
        [I32, I64, I32, I64],
        [I64, I64, I64, I64],
        [I32, I64, F32, I64],
        [I64, I64, I64, F64],
    ];
    for (a, &left) in types.iter().enumerate() {
        for (b, &right) in types.iter().enumerate() {
            let layout = table(&[variant(vec![
                Some(match left {
                    I32 => P::U32,
                    I64 => P::U64,
                    F32 => P::F32,
                    F64 => P::F64,
                }),
                Some(match right {
                    I32 => P::U32,
                    I64 => P::U64,
                    F32 => P::F32,
                    F64 => P::F64,
                }),
            ])]);
            assert_eq!(layout.roots.flat, [I32, expected[a][b]]);
        }
    }
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    for (original, joined, samples) in [
        (I32, I32, vec![0xffff_ffff]),
        (I64, I64, vec![0xfedc_ba98_7654_3210]),
        (F32, F32, vec![0x8000_0000, 0x7fc0_1234, 0x3fa0_0000]),
        (F64, F64, vec![0x8000_0000_0000_0000, 0x7ff8_0000_0000_1234]),
        (F32, I32, vec![0x8000_0000, 0x7fc0_1234, 0x3fa0_0000]),
        (I32, I64, vec![0xffff_ffff, 0x8000_0000]),
        (F32, I64, vec![0x8000_0000, 0x7fc0_1234, 0x3fa0_0000]),
        (
            F64,
            I64,
            vec![
                0x8000_0000_0000_0000,
                0x7ff8_0000_0000_1234,
                0x3ff4_0000_0000_0000,
            ],
        ),
    ] {
        let conversion = original.conversion(joined).unwrap();
        let mut module = Module::new();
        let mut types = TypeSection::new();
        CoreSignature {
            params: vec![original],
            results: vec![joined],
        }
        .encode(&mut types);
        CoreSignature {
            params: vec![joined],
            results: vec![original],
        }
        .encode(&mut types);
        module.section(&types);
        let mut functions = FunctionSection::new();
        functions.function(0).function(1);
        module.section(&functions);
        let mut exports = ExportSection::new();
        exports
            .export("join", ExportKind::Func, 0)
            .export("split", ExportKind::Func, 1);
        module.section(&exports);
        let mut code = CodeSection::new();
        for instructions in [conversion.to_joined, conversion.from_joined] {
            let mut f = Function::new([]);
            f.instruction(&Instruction::LocalGet(0));
            for instruction in instructions {
                f.instruction(instruction);
            }
            f.instruction(&Instruction::End);
            code.function(&f);
        }
        module.section(&code);
        let module = wasmtime::Module::new(&engine, module.finish()).unwrap();
        let mut store = wasmtime::Store::new(&engine, ());
        store.set_fuel(1_000_000).unwrap();
        store.set_epoch_deadline(1);
        let instance = wasmtime::Instance::new(&mut store, &module, &[]).unwrap();
        let join = instance.get_func(&mut store, "join").unwrap();
        let split = instance.get_func(&mut store, "split").unwrap();
        for bits in samples {
            let mut output = [core_value(joined, 0)];
            join.call(&mut store, &[core_value(original, bits)], &mut output)
                .unwrap();
            assert_eq!(raw(&output[0]), bits);
            // 狭い場合へ戻すとき、非選択の上位ビットを値へ混ぜない。
            let joined_bits = if joined == I64 && matches!(original, I32 | F32) {
                bits | 0xdead_beef_0000_0000
            } else {
                bits
            };
            let mut output = [core_value(original, 0)];
            split
                .call(&mut store, &[core_value(joined, joined_bits)], &mut output)
                .unwrap();
            assert_eq!(raw(&output[0]), bits);
        }
    }
    for (original, joined) in [(I32, F32), (F32, F64), (F64, F32), (I64, I32)] {
        assert!(original.conversion(joined).is_err());
    }
}

fn memory_type() -> MemoryType {
    MemoryType {
        minimum: 1,
        maximum: None,
        memory64: false,
        shared: false,
        page_size_log2: None,
    }
}

#[test]
fn handwritten_variants_validate_join_types_and_pass_payload_bits() {
    // 関門: 手書きの WIT に対して生成した型を Wasmtime が検証し、場合のビット列を渡す。
    // コアの変換命令の試験だけでは、Component Model の合流規則との食い違いを検出できない。
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    for (left, right, left_wit, right_wit, values) in [
        (
            P::U32,
            P::F32,
            "u32",
            "f32",
            vec![
                (Val::U32(u32::MAX), 0xffff_ffff),
                (Val::Float32(-0.0), 0x8000_0000),
            ],
        ),
        (
            P::U64,
            P::F64,
            "u64",
            "f64",
            vec![
                (Val::U64(u64::MAX), u64::MAX),
                (Val::Float64(-0.0), 0x8000_0000_0000_0000),
            ],
        ),
        (
            P::F32,
            P::F64,
            "f32",
            "f64",
            vec![
                (Val::Float32(1.25), 0x3fa0_0000),
                (Val::Float64(1.25), 0x3ff4_0000_0000_0000),
            ],
        ),
        (
            P::U32,
            P::U64,
            "u32",
            "u64",
            vec![
                (Val::U32(u32::MAX), 0xffff_ffff),
                (Val::U64(u64::MAX), u64::MAX),
            ],
        ),
        (
            P::F32,
            P::F32,
            "f32",
            "f32",
            vec![
                (Val::Float32(-0.0), 0x8000_0000),
                (Val::Float32(1.25), 0x3fa0_0000),
            ],
        ),
        (
            P::F64,
            P::F64,
            "f64",
            "f64",
            vec![
                (Val::Float64(-0.0), 0x8000_0000_0000_0000),
                (Val::Float64(1.25), 0x3ff4_0000_0000_0000),
            ],
        ),
    ] {
        let abi = FunctionAbi::new(
            &table(&[variant(vec![Some(left), Some(right)])]),
            &table(&[P::U64]),
        )
        .unwrap();
        let mut module = Module::new();
        let mut types = TypeSection::new();
        abi.lift.encode(&mut types);
        module.section(&types);
        let mut functions = FunctionSection::new();
        functions.function(0);
        module.section(&functions);
        let mut exports = ExportSection::new();
        exports.export("f", ExportKind::Func, 0);
        module.section(&exports);
        let mut f = Function::new([]);
        f.instruction(&Instruction::LocalGet(1));
        for instruction in abi.lift.params[1]
            .conversion(CoreType::I64)
            .unwrap()
            .to_joined
        {
            f.instruction(instruction);
        }
        f.instruction(&Instruction::End);
        let mut code = CodeSection::new();
        code.function(&f);
        module.section(&code);
        let source = wasmtime::Module::new(&engine, module.finish()).unwrap();
        let payload_type = match abi.lift.params[1] {
            CoreType::I32 => "i32",
            CoreType::I64 => "i64",
            CoreType::F32 => "f32",
            CoreType::F64 => "f64",
        };
        let bytes = wat::parse_str(format!(r#"(component
            (import "source" (core module $m (export "f" (func (param i32 {payload_type}) (result i64)))))
            (core instance $i (instantiate $m))
            (type $v0 (variant (case "a" {left_wit}) (case "b" {right_wit})))
            (export $v "value" (type $v0))
            (func (export "f") (param "v" $v) (result u64)
                (canon lift (core func $i "f"))))"#)).unwrap();
        let component = Component::from_binary(&engine, &bytes).unwrap();
        let mut store = wasmtime::Store::new(&engine, ());
        store.set_fuel(1_000_000).unwrap();
        store.set_epoch_deadline(1);
        let mut linker = Linker::new(&engine);
        linker.root().module("source", &source).unwrap();
        let instance = linker.instantiate(&mut store, &component).unwrap();
        let f = instance.get_func(&mut store, "f").unwrap();
        for (name, (value, expected)) in ["a", "b"].into_iter().zip(values) {
            let mut results = [Val::Bool(false)];
            f.call(
                &mut store,
                &[Val::Variant(name.into(), Some(Box::new(value)))],
                &mut results,
            )
            .unwrap();
            assert_eq!(results[0], Val::U64(expected));
        }
    }
}

fn mem(offset: u64) -> MemArg {
    MemArg {
        offset,
        align: 2,
        memory_index: 0,
    }
}

fn wit_tuple(count: u32) -> String {
    format!("(tuple {})", vec!["u32"; count as usize].join(" "))
}

fn lifted_core(abi: &FunctionAbi, count: u32) -> Vec<u8> {
    let mut module = Module::new();
    let mut types = TypeSection::new();
    abi.lift.encode(&mut types);
    types.ty().function([ValType::I32; 4], [ValType::I32]);
    module.section(&types);
    let mut functions = FunctionSection::new();
    functions.function(0).function(1);
    module.section(&functions);
    let mut memory = MemorySection::new();
    memory.memory(memory_type());
    module.section(&memory);
    let mut exports = ExportSection::new();
    exports
        .export("f", ExportKind::Func, 0)
        .export("realloc", ExportKind::Func, 1)
        .export("memory", ExportKind::Memory, 0);
    module.section(&exports);
    let mut code = CodeSection::new();
    let mut f = Function::new([]);
    if abi.indirect_results {
        f.instruction(&Instruction::I32Const(0));
    }
    f.instruction(&Instruction::I32Const(0));
    for i in 0..count {
        if abi.indirect_params {
            f.instruction(&Instruction::LocalGet(0))
                .instruction(&Instruction::I32Load(mem(u64::from(i) * 4)));
        } else {
            f.instruction(&Instruction::LocalGet(i));
        }
        f.instruction(&Instruction::I32Add);
    }
    if abi.indirect_results {
        f.instruction(&Instruction::I32Store(mem(0)))
            .instruction(&Instruction::I32Const(0))
            .instruction(&Instruction::I32Const(1000))
            .instruction(&Instruction::I32Store(mem(4)))
            .instruction(&Instruction::I32Const(0));
    }
    f.instruction(&Instruction::End);
    code.function(&f);
    let mut realloc = Function::new([]);
    realloc
        .instruction(&Instruction::I32Const(128))
        .instruction(&Instruction::End);
    code.function(&realloc);
    module.section(&code);
    module.finish()
}

fn lowered_caller(abi: &FunctionAbi, count: u32) -> Vec<u8> {
    let mut module = Module::new();
    let mut types = TypeSection::new();
    abi.lower.encode(&mut types);
    types.ty().function([], [ValType::I32]);
    module.section(&types);
    let mut imports = ImportSection::new();
    imports.import("callee", "f", wasm_encoder::EntityType::Function(0));
    imports.import(
        "mem",
        "memory",
        wasm_encoder::EntityType::Memory(memory_type()),
    );
    module.section(&imports);
    let mut functions = FunctionSection::new();
    functions.function(1);
    module.section(&functions);
    let mut exports = ExportSection::new();
    exports.export("run", ExportKind::Func, 1);
    module.section(&exports);
    let mut f = Function::new([]);
    if abi.indirect_params {
        for i in 0..count {
            f.instruction(&Instruction::I32Const(512))
                .instruction(&Instruction::I32Const((i + 1) as i32))
                .instruction(&Instruction::I32Store(mem(u64::from(i) * 4)));
        }
        f.instruction(&Instruction::I32Const(512));
    } else {
        for i in 0..count {
            f.instruction(&Instruction::I32Const((i + 1) as i32));
        }
    }
    if abi.indirect_results {
        f.instruction(&Instruction::I32Const(1024));
    }
    f.instruction(&Instruction::Call(0));
    if abi.indirect_results {
        f.instruction(&Instruction::I32Const(1024))
            .instruction(&Instruction::I32Load(mem(0)))
            .instruction(&Instruction::I32Const(1024))
            .instruction(&Instruction::I32Load(mem(4)))
            .instruction(&Instruction::I32Add);
    }
    f.instruction(&Instruction::End);
    let mut code = CodeSection::new();
    code.function(&f);
    module.section(&code);
    module.finish()
}

#[test]
fn handwritten_component_types_validate_and_execute_both_indirect_directions() {
    // 関門: 16/17 引数と 1/2 結果を、手書きの WIT と Wasmtime の検証・実行で確かめる。
    // 同じ表を使うホストの復号だけでは、lift/lower の結果の位置の取り違えを捕まえられない。
    use CoreType::I32;
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    for count in [16_u32, 17] {
        for result_count in [1, 2] {
            let abi = FunctionAbi::new(
                &table(&[P::TupleFields(vec![P::U32; count as usize])]),
                &table(&[if result_count == 1 {
                    P::U32
                } else {
                    P::TupleFields(vec![P::U32; 2])
                }]),
            )
            .unwrap();
            let expected_params = if count == 16 {
                vec![I32; 16]
            } else {
                vec![I32]
            };
            let mut expected_lower_params = expected_params.clone();
            if result_count == 2 {
                expected_lower_params.push(I32);
            }
            assert_eq!(abi.lift.params, expected_params);
            assert_eq!(abi.lift.results, [I32]);
            assert_eq!(abi.lower.params, expected_lower_params);
            assert_eq!(
                abi.lower.results,
                if result_count == 1 { vec![I32] } else { vec![] }
            );
            assert_eq!(abi.indirect_params, count == 17);
            assert_eq!(abi.indirect_results, result_count == 2);
            let argument_type = wit_tuple(count);
            let result_type = if result_count == 1 {
                "u32".into()
            } else {
                wit_tuple(2)
            };
            let source = wasmtime::Module::new(&engine, lifted_core(&abi, count)).unwrap();
            let lift_params = if count == 16 {
                vec!["i32"; 16].join(" ")
            } else {
                "i32".into()
            };
            let lower_params = if result_count == 2 {
                format!("{lift_params} i32")
            } else {
                lift_params.clone()
            };
            let lower_result = if result_count == 1 {
                "(result i32)"
            } else {
                ""
            };
            let component = wat::parse_str(format!(
                r#"(component
                (import "source" (core module $m
                    (export "f" (func (param {lift_params}) (result i32)))
                    (export "realloc" (func (param i32 i32 i32 i32) (result i32)))
                    (export "memory" (memory 1))))
                (core instance $i (instantiate $m))
                (type $a {argument_type})
                (type $r {result_type})
                (func (export "f") (param "a" $a) (result $r)
                    (canon lift (core func $i "f") (memory (core memory $i "memory"))
                        (realloc (core func $i "realloc")))))"#
            ))
            .unwrap();
            let component = Component::from_binary(&engine, &component).unwrap();
            let mut store = wasmtime::Store::new(&engine, ());
            store.set_fuel(1_000_000).unwrap();
            store.set_epoch_deadline(1);
            let mut linker = Linker::new(&engine);
            linker.root().module("source", &source).unwrap();
            let instance = linker.instantiate(&mut store, &component).unwrap();
            let f = instance.get_func(&mut store, "f").unwrap();
            let values = (1..=count).map(Val::U32).collect::<Vec<_>>();
            let sum = count * (count + 1) / 2;
            let mut results = [Val::Bool(false)];
            f.call(&mut store, &[Val::Tuple(values)], &mut results)
                .unwrap();
            assert_eq!(
                results[0],
                if result_count == 1 {
                    Val::U32(sum)
                } else {
                    Val::Tuple(vec![Val::U32(sum), Val::U32(1000)])
                }
            );

            let caller = wasmtime::Module::new(&engine, lowered_caller(&abi, count)).unwrap();
            let component = wat::parse_str(format!(r#"(component
                (type $a {argument_type})
                (type $r {result_type})
                (import "callee" (func $f (param "a" $a) (result $r)))
                (core module $mem (memory (export "memory") 1))
                (core instance $memi (instantiate $mem))
                (core func $lower (canon lower (func $f) (memory (core memory $memi "memory"))))
                (core instance $callee (export "f" (func $lower)))
                (import "caller" (core module $caller
                    (import "callee" "f" (func (param {lower_params}) {lower_result}))
                    (import "mem" "memory" (memory 1))
                    (export "run" (func (result i32)))))
                (core instance $c (instantiate $caller (with "callee" (instance $callee)) (with "mem" (instance $memi))))
                (func (export "run") (result u32) (canon lift (core func $c "run"))))"#)).unwrap();
            let component = Component::from_binary(&engine, &component).unwrap();
            let mut linker = Linker::new(&engine);
            linker.root().module("caller", &caller).unwrap();
            linker
                .root()
                .func_new("callee", move |_store, _ty, params, results| {
                    assert_eq!(params, [Val::Tuple((1..=count).map(Val::U32).collect())]);
                    results[0] = if result_count == 1 {
                        Val::U32(sum)
                    } else {
                        Val::Tuple(vec![Val::U32(sum), Val::U32(1000)])
                    };
                    Ok(())
                })
                .unwrap();
            let instance = linker.instantiate(&mut store, &component).unwrap();
            let run = instance
                .get_typed_func::<(), (u32,)>(&mut store, "run")
                .unwrap();
            assert_eq!(
                run.call(&mut store, ()).unwrap().0,
                sum + if result_count == 2 { 1000 } else { 0 }
            );
        }
    }
}

#[test]
fn empty_functions_and_empty_aggregates_need_no_indirect_result() {
    // 関門: 戻り値の省略と空の record の零個の平らな値を区別せず ABI へ渡せることを守る。
    let empty = table(&[]);
    for results in [table(&[]), table(&[P::Record { fields: vec![] }])] {
        let abi = FunctionAbi::new(&empty, &results).unwrap();
        assert_eq!(
            abi.lift,
            CoreSignature {
                params: vec![],
                results: vec![]
            }
        );
        assert_eq!(abi.lower, abi.lift);
        assert!(!abi.indirect_params);
        assert!(!abi.indirect_results);
    }
    assert!(FunctionAbi::new(&empty, &table(&[P::U32, P::U32])).is_err());
}
