//! 補助コードのコア型と、合流した値のビット変換を定める（設計書 03-10「型の対応」）。
//! Wasmtime の内部型に依存せず、公開のバイナリ生成 API に変換する。

use wasm_encoder::{Instruction, TypeSection, ValType};

use super::layout::LayoutError;

/// 同期・memory32 の正準 ABI が使う四種類のコア型。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum CoreType {
    I32,
    I64,
    F32,
    F64,
}

/// 元の場合の型と合流後の型の間の変換。数値変換は含まない。
pub(crate) struct BitConversion {
    pub to_joined: &'static [Instruction<'static>],
    // 逆向きの列は、独立した ABI の試験でだけビットの保存を確認する。
    #[cfg(test)]
    pub from_joined: &'static [Instruction<'static>],
}

impl CoreType {
    /// variant の同じ位置にあるペイロードの型を合流する。
    pub(crate) fn join(self, other: Self) -> Self {
        if self == other {
            self
        } else if matches!(
            (self, other),
            (Self::I32, Self::F32) | (Self::F32, Self::I32)
        ) {
            Self::I32
        } else {
            Self::I64
        }
    }

    /// 合流で必要な再解釈と幅の変更だけを生成する。
    pub(crate) fn conversion(self, joined: Self) -> Result<BitConversion, LayoutError> {
        use Instruction::{
            F32ReinterpretI32, F64ReinterpretI64, I32ReinterpretF32, I32WrapI64, I64ExtendI32U,
            I64ReinterpretF64,
        };
        let (to_joined, _from_joined): (&'static [_], &'static [_]) = match (self, joined) {
            (Self::I32, Self::I32)
            | (Self::I64, Self::I64)
            | (Self::F32, Self::F32)
            | (Self::F64, Self::F64) => (&[], &[]),
            (Self::F32, Self::I32) => (&[I32ReinterpretF32], &[F32ReinterpretI32]),
            // 符号付きの整数でもビット列を合流するので、符号拡張を使わない。
            (Self::I32, Self::I64) => (&[I64ExtendI32U], &[I32WrapI64]),
            (Self::F32, Self::I64) => (
                &[I32ReinterpretF32, I64ExtendI32U],
                &[I32WrapI64, F32ReinterpretI32],
            ),
            (Self::F64, Self::I64) => (&[I64ReinterpretF64], &[F64ReinterpretI64]),
            _ => return Err(LayoutError::Internal("invalid flat variant conversion")),
        };
        Ok(BitConversion {
            to_joined,
            #[cfg(test)]
            from_joined: _from_joined,
        })
    }

    /// バイナリ生成器の公開のコア型へ変換する。
    pub(crate) fn encoded(self) -> ValType {
        match self {
            Self::I32 => ValType::I32,
            Self::I64 => ValType::I64,
            Self::F32 => ValType::F32,
            Self::F64 => ValType::F64,
        }
    }
}

/// 一つのコア関数の引数と結果。間接の位置も I32 として含む。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct CoreSignature {
    pub params: Vec<CoreType>,
    pub results: Vec<CoreType>,
}

impl CoreSignature {
    /// 型の区画へ宣言を追加する。関数の番号は生成する側が管理する。
    pub(crate) fn encode(&self, types: &mut TypeSection) {
        types.ty().function(
            self.params.iter().map(|t| t.encoded()),
            self.results.iter().map(|t| t.encoded()),
        );
    }
}

/// 補助の memory32 と、検査付きの realloc・範囲・ヘッダの検査を生成する。
/// 確保した領域は呼び出しの Store とともに捨てるため、解放した領域を再利用しない。
/// 呼び出しごとに新しい Store とインスタンスを作り、bump 確保の状態を残さない。
pub(crate) fn memory_module(
    minimum: u64,
    maximum: Option<u64>,
) -> Result<wasm_encoder::Module, LayoutError> {
    use wasm_encoder::{
        CodeSection, EntityType, ExportKind, ExportSection, FunctionSection, GlobalSection,
        GlobalType, ImportSection, MemorySection, MemoryType, Module,
    };
    if minimum == 0 || minimum > 65_536 || maximum.is_some_and(|max| max < minimum || max > 65_536)
    {
        return Err(LayoutError::Internal("invalid adapter memory limits"));
    }
    let mut module = Module::new();
    let mut types = TypeSection::new();
    for (params, results) in [
        (vec![CoreType::I32, CoreType::I64, CoreType::I64], vec![]),
        (vec![CoreType::I32; 3], vec![]),
        (vec![CoreType::I32; 4], vec![CoreType::I32]),
        (
            vec![CoreType::I32, CoreType::I32, CoreType::I32, CoreType::I64],
            vec![],
        ),
    ] {
        CoreSignature { params, results }.encode(&mut types);
    }
    module.section(&types);
    let mut imports = ImportSection::new();
    imports.import("adapter", "adapter-fail", EntityType::Function(0));
    module.section(&imports);
    let mut functions = FunctionSection::new();
    functions.function(1).function(2).function(3);
    module.section(&functions);
    let mut memory = MemorySection::new();
    memory.memory(MemoryType {
        minimum,
        maximum,
        memory64: false,
        shared: false,
        page_size_log2: None,
    });
    module.section(&memory);
    let mut globals = GlobalSection::new();
    // 零を未確保の位置として残し、整列の加算を memory32 より広い型で検査する。
    globals.global(
        GlobalType {
            val_type: ValType::I64,
            mutable: true,
            shared: false,
        },
        &wasm_encoder::ConstExpr::i64_const(8),
    );
    module.section(&globals);
    let mut exports = ExportSection::new();
    exports
        .export("memory", ExportKind::Memory, 0)
        .export("check-range", ExportKind::Func, 1)
        .export("realloc", ExportKind::Func, 2)
        .export("check-header", ExportKind::Func, 3);
    module.section(&exports);
    let mut code = CodeSection::new();
    code.function(&range_function());
    code.function(&realloc_function());
    code.function(&header_function());
    module.section(&code);
    Ok(module)
}

/// 命令を書き込む先。可変量の生成では残量を検査する実装を使う。
pub(super) trait InstructionSink {
    fn instruction(&mut self, instruction: &Instruction<'_>);
}
impl InstructionSink for wasm_encoder::Function {
    fn instruction(&mut self, instruction: &Instruction<'_>) {
        wasm_encoder::Function::instruction(self, instruction);
    }
}

/// 上限を超えた命令を保存しない。失敗は生成の終わりに返し、途中のコードは使わない。
pub(super) struct BoundedFunction {
    function: wasm_encoder::Function,
    limit: usize,
    exceeded: bool,
    scratch: Vec<u8>,
}
impl BoundedFunction {
    fn new<const N: usize>(locals: [(u32, ValType); N], limit: usize) -> Self {
        let function = wasm_encoder::Function::new(locals);
        let exceeded = function.byte_len() > limit;
        Self {
            function,
            limit,
            exceeded,
            scratch: Vec::new(),
        }
    }
    pub(super) fn instruction(&mut self, instruction: &Instruction<'_>) {
        use wasm_encoder::Encode;
        if self.exceeded {
            return;
        }
        self.scratch.clear();
        instruction.encode(&mut self.scratch);
        if self
            .function
            .byte_len()
            .checked_add(self.scratch.len())
            .is_none_or(|n| n > self.limit)
        {
            self.exceeded = true;
        } else {
            self.function.raw(self.scratch.iter().copied());
        }
    }
    fn finish(self) -> Result<wasm_encoder::Function, LayoutError> {
        if self.exceeded {
            Err(LayoutError::GenerationBudget)
        } else {
            Ok(self.function)
        }
    }
}
impl InstructionSink for BoundedFunction {
    fn instruction(&mut self, instruction: &Instruction<'_>) {
        BoundedFunction::instruction(self, instruction);
    }
}

/// 共通の命令列を、呼び出し元の関数へ順に追加する。
pub(super) fn instructions(function: &mut impl InstructionSink, code: &[Instruction<'_>]) {
    for instruction in code {
        function.instruction(instruction);
    }
}

// 報告の受け手が戻ったとしても続行しない。要求量・上限は unsigned のビットを保つ。
fn reject(
    function: &mut wasm_encoder::Function,
    code: super::runtime::FailureCode,
    requested: &[Instruction<'_>],
    limit: &[Instruction<'_>],
) {
    use wasm_encoder::BlockType;
    function.instruction(&Instruction::If(BlockType::Empty));
    function.instruction(&Instruction::I32Const(code as i32));
    instructions(function, requested);
    instructions(function, limit);
    instructions(
        function,
        &[
            Instruction::Call(0),
            Instruction::Unreachable,
            Instruction::End,
        ],
    );
}

fn memory_bytes(function: &mut wasm_encoder::Function) {
    instructions(
        function,
        &[
            Instruction::MemorySize(0),
            Instruction::I64ExtendI32U,
            Instruction::I64Const(16),
            Instruction::I64Shl,
        ],
    );
}

fn range_function() -> wasm_encoder::Function {
    use super::runtime::FailureCode::Format;
    use Instruction::*;
    let mut f = wasm_encoder::Function::new([(1, ValType::I64)]);
    // 正準 ABI の整列は零でない二の冪であり、位置も同じ整列に従う。
    instructions(
        &mut f,
        &[
            LocalGet(2),
            I32Eqz,
            LocalGet(2),
            LocalGet(2),
            I32Const(1),
            I32Sub,
            I32And,
            I32Eqz,
            I32Eqz,
            I32Or,
            LocalGet(0),
            LocalGet(2),
            I32Const(1),
            I32Sub,
            I32And,
            I32Eqz,
            I32Eqz,
            I32Or,
        ],
    );
    reject(
        &mut f,
        Format,
        &[LocalGet(0), I64ExtendI32U],
        &[LocalGet(2), I64ExtendI32U],
    );
    instructions(
        &mut f,
        &[
            LocalGet(0),
            I64ExtendI32U,
            LocalGet(1),
            I64ExtendI32U,
            I64Add,
            LocalSet(3),
            LocalGet(3),
            I64Const(i64::from(u32::MAX)),
            I64GtU,
        ],
    );
    reject(
        &mut f,
        Format,
        &[LocalGet(3)],
        &[I64Const(i64::from(u32::MAX))],
    );
    instructions(&mut f, &[LocalGet(3)]);
    memory_bytes(&mut f);
    f.instruction(&I64GtU);
    // memory.size は報告時にも読むので、要求量と現在のメモリを独立して保持できる。
    f.instruction(&wasm_encoder::Instruction::If(
        wasm_encoder::BlockType::Empty,
    ));
    instructions(&mut f, &[I32Const(Format as i32), LocalGet(3)]);
    memory_bytes(&mut f);
    instructions(&mut f, &[Call(0), Unreachable, End, End]);
    f
}

fn realloc_function() -> wasm_encoder::Function {
    use super::runtime::FailureCode::{Format, Realloc};
    use Instruction::*;
    use wasm_encoder::BlockType;
    let mut f = wasm_encoder::Function::new([(3, ValType::I64)]);
    instructions(
        &mut f,
        &[
            LocalGet(0),
            LocalGet(1),
            LocalGet(2),
            Call(1),
            LocalGet(0),
            I32Eqz,
            LocalGet(1),
            I32Eqz,
            I32Eqz,
            I32And,
        ],
    );
    reject(
        &mut f,
        Format,
        &[LocalGet(1), I64ExtendI32U],
        &[I64Const(0)],
    );
    instructions(
        &mut f,
        &[
            LocalGet(3),
            I32Eqz,
            If(BlockType::Empty),
            I32Const(0),
            Return,
            End,
            LocalGet(0),
            I32Eqz,
            I32Eqz,
            LocalGet(1),
            LocalGet(3),
            I32GeU,
            I32And,
            If(BlockType::Empty),
            LocalGet(0),
            Return,
            End,
        ],
    );
    // 転送ヘッダは整列 8 を要求するので、外側の list<u8> の要求にも整列 8 を使う。
    instructions(
        &mut f,
        &[
            LocalGet(2),
            I32Const(8),
            LocalGet(2),
            I32Const(8),
            I32GtU,
            Select,
            LocalSet(2),
        ],
    );
    // 和を i64 で求めてから整列する。i32 の折り返しで小さな確保へ化けさせない。
    instructions(
        &mut f,
        &[
            GlobalGet(0),
            LocalGet(2),
            I64ExtendI32U,
            I64Const(1),
            I64Sub,
            I64Add,
            LocalGet(2),
            I64ExtendI32U,
            I64Const(1),
            I64Sub,
            I64Const(-1),
            I64Xor,
            I64And,
            LocalSet(4),
            LocalGet(4),
            LocalGet(3),
            I64ExtendI32U,
            I64Add,
            LocalSet(5),
            LocalGet(5),
            I64Const(i64::from(u32::MAX)),
            I64GtU,
        ],
    );
    reject(
        &mut f,
        Realloc,
        &[LocalGet(5)],
        &[I64Const(i64::from(u32::MAX))],
    );
    instructions(&mut f, &[LocalGet(5)]);
    memory_bytes(&mut f);
    instructions(
        &mut f,
        &[
            I64GtU,
            If(BlockType::Empty),
            LocalGet(5),
            I64Const(65_535),
            I64Add,
            I64Const(16),
            I64ShrU,
            LocalSet(6),
            LocalGet(6),
            MemorySize(0),
            I64ExtendI32U,
            I64Sub,
            I32WrapI64,
            MemoryGrow(0),
            I32Const(-1),
            I32Eq,
            If(BlockType::Empty),
            I32Const(Realloc as i32),
            LocalGet(5),
        ],
    );
    memory_bytes(&mut f);
    instructions(
        &mut f,
        &[
            Call(0),
            Unreachable,
            End,
            End,
            LocalGet(4),
            I32WrapI64,
            LocalGet(0),
            LocalGet(1),
            LocalGet(3),
            LocalGet(1),
            LocalGet(3),
            I32LtU,
            Select,
            MemoryCopy {
                src_mem: 0,
                dst_mem: 0,
            },
            LocalGet(5),
            GlobalSet(0),
            LocalGet(4),
            I32WrapI64,
            End,
        ],
    );
    f
}

fn header_function() -> wasm_encoder::Function {
    use super::{
        runtime::FailureCode::{ArgumentTransfer, Format},
        wire,
    };
    use Instruction::*;
    let mut f = wasm_encoder::Function::new([]);
    instructions(
        &mut f,
        &[
            LocalGet(1),
            I32Const(i32::try_from(wire::HEADER_SIZE).unwrap_or(i32::MAX)),
            I32LtU,
        ],
    );
    reject(
        &mut f,
        Format,
        &[LocalGet(1), I64ExtendI32U],
        &[I64Const(i64::from(wire::HEADER_SIZE))],
    );
    instructions(&mut f, &[LocalGet(0), LocalGet(1), I32Const(8), Call(1)]);
    for (offset, expected) in [
        (
            wire::MAGIC_OFFSET,
            vec![I32Const(i32::from_le_bytes(*wire::MAGIC))],
        ),
        (
            wire::VERSION_OFFSET,
            vec![I32Const(i32::try_from(wire::VERSION).unwrap_or(i32::MAX))],
        ),
        (wire::LENGTH_OFFSET, vec![LocalGet(1)]),
        (wire::ROOTS_OFFSET, vec![LocalGet(2)]),
    ] {
        instructions(
            &mut f,
            &[
                LocalGet(0),
                I32Load(wasm_encoder::MemArg {
                    offset: u64::from(offset),
                    align: 2,
                    memory_index: 0,
                }),
            ],
        );
        instructions(&mut f, &expected);
        f.instruction(&I32Ne);
        reject(
            &mut f,
            Format,
            &[LocalGet(1), I64ExtendI32U],
            &[LocalGet(3)],
        );
    }
    for offset in [wire::TRANSFER_OFFSET, wire::CONSTRUCTION_OFFSET] {
        instructions(
            &mut f,
            &[
                LocalGet(0),
                I64Load(wasm_encoder::MemArg {
                    offset: u64::from(offset),
                    align: 3,
                    memory_index: 0,
                }),
                LocalGet(3),
                I64Ne,
            ],
        );
        reject(
            &mut f,
            Format,
            &[LocalGet(1), I64ExtendI32U],
            &[LocalGet(3)],
        );
    }
    instructions(&mut f, &[LocalGet(1), I64ExtendI32U, LocalGet(3), I64GtU]);
    reject(
        &mut f,
        ArgumentTransfer,
        &[LocalGet(1), I64ExtendI32U],
        &[LocalGet(3)],
    );
    f.instruction(&End);
    f
}

/// 固定部と単純な参照先の呼び出しを生成する。元の関数は取り込み 0 を一度だけ呼ぶ。
#[cfg(test)]
pub(crate) fn fixed_module(
    params: &[super::super::WitPlan],
    results: &[super::super::WitPlan],
) -> Result<wasm_encoder::Module, LayoutError> {
    fixed_module_bounded(
        params,
        results,
        super::component::GENERATION_LIMIT,
        &mut 1_000_000,
    )
}

/// 呼び出しの命令を書き込むたびに、補助区画の残量を検査する。
pub(super) fn fixed_module_bounded(
    params: &[super::super::WitPlan],
    results: &[super::super::WitPlan],
    limit: usize,
    budget: &mut usize,
) -> Result<wasm_encoder::Module, LayoutError> {
    use super::{codec::CodecPlan, emit_values::FixedValues, layout::FunctionAbi};
    use wasm_encoder::{
        CodeSection, EntityType, ExportKind, ExportSection, FunctionSection, ImportSection,
        MemoryType, Module,
    };
    let p = CodecPlan::new(params, budget)?;
    let r = CodecPlan::new(results, budget)?;
    let abi = FunctionAbi::new(&p.layout, &r.layout)?;
    let pv = FixedValues::new(params, &p)?;
    let rv = FixedValues::new(results, &r)?;
    let mut module = Module::new();
    let mut types = TypeSection::new();
    abi.lower.encode(&mut types);
    for (params, results) in [
        (vec![CoreType::I32; 4], vec![CoreType::I32]),
        (
            vec![CoreType::I32, CoreType::I32, CoreType::I32, CoreType::I64],
            vec![],
        ),
        (vec![CoreType::I32, CoreType::I64, CoreType::I64], vec![]),
        (vec![CoreType::I32; 2], vec![CoreType::I32]),
        (vec![CoreType::I32; 3], vec![]),
    ] {
        CoreSignature { params, results }.encode(&mut types);
    }
    module.section(&types);
    let mut imports = ImportSection::new();
    imports.import("guest", "call", EntityType::Function(0));
    imports.import("support", "realloc", EntityType::Function(1));
    imports.import("support", "check-header", EntityType::Function(2));
    imports.import("failure", "adapter-fail", EntityType::Function(3));
    imports.import("support", "check-range", EntityType::Function(5));
    imports.import(
        "support",
        "memory",
        EntityType::Memory(MemoryType {
            minimum: 1,
            maximum: None,
            memory64: false,
            shared: false,
            page_size_log2: None,
        }),
    );
    module.section(&imports);
    let mut functions = FunctionSection::new();
    functions.function(4);
    module.section(&functions);
    let mut exports = ExportSection::new();
    exports.export("call", ExportKind::Func, 5);
    module.section(&exports);
    // コード区画・関数の長さの LEB と要素数にも場所を残す。
    let body_limit = limit
        .checked_sub(module.as_slice().len())
        .and_then(|n| n.checked_sub(12))
        .ok_or(LayoutError::GenerationBudget)?;
    let mut code = CodeSection::new();
    code.function(&fixed_function(
        &pv,
        &rv,
        &abi,
        params.len(),
        results.len(),
        body_limit,
    )?);
    module.section(&code);
    Ok(module)
}

/// 条件を満たすとき、補助の専用の報告を呼んで続行を止める。
pub(super) fn fail_if(
    f: &mut BoundedFunction,
    code: super::runtime::FailureCode,
    requested: u64,
    limit: u64,
    fail: u32,
) {
    use Instruction::*;
    instructions(
        f,
        &[
            If(wasm_encoder::BlockType::Empty),
            I32Const(code as i32),
            I64Const(requested as i64),
            I64Const(limit as i64),
            Call(fail),
            Unreachable,
            End,
        ],
    );
}

fn fixed_function(
    params: &super::emit_values::FixedValues,
    results: &super::emit_values::FixedValues,
    abi: &super::layout::FunctionAbi,
    param_count: usize,
    result_count: usize,
    limit: usize,
) -> Result<wasm_encoder::Function, LayoutError> {
    use super::{
        emit_values::{CURSOR, END, LIMIT, OUTPUT, PAIR, PARAMS, RESULTS, check_budget, mem},
        runtime::FailureCode,
        wire,
    };
    use Instruction::*;
    let input_fixed = wire::HEADER_SIZE
        .checked_add(params.root.size)
        .ok_or(LayoutError::Memory32)?;
    let output_fixed = wire::HEADER_SIZE
        .checked_add(results.root.size)
        .ok_or(LayoutError::Memory32)?;
    let extra = params.extra_locals()?.max(results.extra_locals()?);
    let mut f = BoundedFunction::new(
        [(16, ValType::I32), (3, ValType::I64), (extra, ValType::I32)],
        limit,
    );
    // 可変長の参照先は固定部の後に続く。ヘッダを読む前に最低限の長さを照合する。
    instructions(&mut f, &[LocalGet(1), I32Const(input_fixed as i32), I32LtU]);
    fail_if(&mut f, FailureCode::Format, u64::from(input_fixed), 0, 3);
    instructions(
        &mut f,
        &[
            LocalGet(0),
            LocalGet(1),
            I32Const(8),
            Call(4),
            LocalGet(0),
            I64Load(mem(wire::TRANSFER_OFFSET, 3)),
            LocalSet(LIMIT),
            LocalGet(0),
            LocalGet(1),
            I32Const(u32::try_from(param_count).map_err(|_| LayoutError::Memory32)? as i32),
            LocalGet(LIMIT),
            Call(2),
        ],
    );
    params.measure(&mut f, 0, wire::HEADER_SIZE, true)?;
    // 固定部だけで上限を超える結果は、元の関数を呼ぶ前に拒否できる。
    for (code, requested) in [
        (FailureCode::ResultTransfer, u64::from(output_fixed)),
        (FailureCode::ResultConstruction, results.root.construction),
    ] {
        instructions(&mut f, &[I64Const(requested as i64), LocalSet(END)]);
        check_budget(&mut f, END, code);
    }
    allocate(&mut f, params.root.size, PARAMS);
    instructions(
        &mut f,
        &[
            LocalGet(PARAMS),
            LocalGet(0),
            I32Const(wire::HEADER_SIZE as i32),
            I32Add,
            I32Const(params.root.size as i32),
            MemoryCopy {
                src_mem: 0,
                dst_mem: 0,
            },
        ],
    );
    params.absolute_params(&mut f)?;
    allocate(&mut f, results.root.size, RESULTS);
    if !abi.indirect_results && !results.root.leaves.is_empty() {
        // 直接の結果では、保存先を呼び出しの引数より下に残す。
        f.instruction(&LocalGet(RESULTS));
    }
    if abi.indirect_params {
        f.instruction(&LocalGet(PARAMS));
    } else {
        params.load_flat(&mut f, PARAMS)?;
    }
    if abi.indirect_results {
        f.instruction(&LocalGet(RESULTS));
    }
    f.instruction(&Call(0));
    if !abi.indirect_results
        && let Some(leaf) = results.root.leaves.first()
    {
        leaf.store(&mut f, 0)?;
    }
    results.measure(&mut f, RESULTS, 0, false)?;
    allocate_local(&mut f, CURSOR, OUTPUT);
    instructions(
        &mut f,
        &[
            LocalGet(OUTPUT),
            I32Const(0),
            LocalGet(CURSOR),
            MemoryFill(0),
        ],
    );
    for (offset, value) in [
        (wire::MAGIC_OFFSET, i32::from_le_bytes(*wire::MAGIC)),
        (wire::VERSION_OFFSET, wire::VERSION as i32),
        (
            wire::ROOTS_OFFSET,
            u32::try_from(result_count).map_err(|_| LayoutError::Memory32)? as i32,
        ),
    ] {
        instructions(
            &mut f,
            &[LocalGet(OUTPUT), I32Const(value), I32Store(mem(offset, 2))],
        );
    }
    instructions(
        &mut f,
        &[
            LocalGet(OUTPUT),
            LocalGet(CURSOR),
            I32Store(mem(wire::LENGTH_OFFSET, 2)),
        ],
    );
    for offset in [wire::TRANSFER_OFFSET, wire::CONSTRUCTION_OFFSET] {
        instructions(
            &mut f,
            &[LocalGet(OUTPUT), LocalGet(LIMIT), I64Store(mem(offset, 3))],
        );
    }
    // 結果のメモリには合流前の配置が書かれる。選ばれた場合の葉だけを写す。
    results.copy_results(&mut f)?;
    results
        .root
        .validate(&mut f, OUTPUT, wire::HEADER_SIZE, 3)?;
    allocate(&mut f, 8, PAIR);
    instructions(
        &mut f,
        &[
            LocalGet(PAIR),
            LocalGet(OUTPUT),
            I32Store(mem(0, 2)),
            LocalGet(PAIR),
            LocalGet(CURSOR),
            I32Store(mem(4, 2)),
            LocalGet(PAIR),
            End,
        ],
    );
    f.finish()
}

/// 検査済みの局所変数の長さで、整列した独立の領域を確保する。
pub(super) fn allocate_local(f: &mut BoundedFunction, size: u32, local: u32) {
    use Instruction::*;
    instructions(
        f,
        &[
            I32Const(0),
            I32Const(0),
            I32Const(8),
            LocalGet(size),
            Call(1),
            LocalSet(local),
        ],
    );
}

fn allocate(f: &mut BoundedFunction, size: u32, local: u32) {
    use Instruction::*;
    instructions(
        f,
        &[
            I32Const(0),
            I32Const(0),
            I32Const(8),
            I32Const(size as i32),
            Call(1),
            LocalSet(local),
        ],
    );
}
