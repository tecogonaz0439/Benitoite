//! 仮想機械（設計書 02-08）。言語の関数の呼び出しで Rust の関数を入れ子に呼ばない（ADR 0016）。

use crate::bytecode::program::{CompiledProgram, ProtoIdx};
use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::io::IoOp;
use crate::runtime::value::{FuncRef, Value};

/// 呼び出しの枠一つの大きさとして数える固定の定数（02-08「呼び出しの入れ子の上限」）。
pub const FRAME_COST: u64 = 96;
/// レジスタ一つの大きさとして数える固定の定数。
pub const REG_COST: u64 = 32;
/// 呼び出しの情報の合計の上限の既定（1 GiB。ADR 0030）。
pub const DEFAULT_MAX_CALL_STACK: u64 = 1_073_741_824;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct VmConfig {
    pub max_call_stack_bytes: u64,
}

/// 命令の位置（原型と命令の番号の組）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct InstrRef {
    pub proto: ProtoIdx,
    pub pc: u32,
}

/// 呼び出しの枠。
#[derive(Clone, Debug)]
pub struct Frame {
    /// 実行中の関数の値
    pub func: FuncRef,
    pub proto: ProtoIdx,
    /// 次に実行する命令の位置
    pub pc: u32,
    /// レジスタの窓の先頭（レジスタの積み重ねの中の位置）
    pub base: u32,
    /// 窓の大きさ
    pub size: u32,
    /// 結果を入れる呼び出し元のレジスタ（レジスタの積み重ねの中の位置）。`main` の枠では使わない
    pub ret_reg: u32,
    /// 呼び出した命令。`main` の枠では `None`
    pub call_site: Option<InstrRef>,
}

/// IO の要求（要求と応答の方式。ADR 0029）。
#[derive(Debug)]
pub struct IoRequest {
    pub op: IoOp,
    pub args: Vec<Value>,
}

/// 実行時エラーの情報の記録の、呼び出しの枠一つ分（02-08「実行時エラーの情報の記録」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct FrameRecord {
    pub proto: ProtoIdx,
    pub call_site: Option<InstrRef>,
}

/// 止まったときの記録。`frames` は内側から外側の順。
#[derive(Clone, Debug)]
pub struct StopInfo {
    pub stop: Stop,
    /// 止まった命令。書き込みの失敗など、命令と関係しないときは `None`
    pub at: Option<InstrRef>,
    pub frames: Vec<FrameRecord>,
}

/// VM の実行関数が返すもの（02-08「IO の命令」の最後の段落）。
#[derive(Debug)]
pub enum VmStep {
    /// 要求を返して止まった（要求と応答の方式だけ）
    Request(IoRequest),
    /// `main` の結果で終わった
    Finished(Value),
    /// 実行時エラー・資源の不足・処理系の不具合で止まった
    Stopped(StopInfo),
}

/// IO の命令の実行の方式。
pub enum IoDispatch<'a> {
    /// 直接呼び出し: ハンドラ表を直接呼ぶ
    Direct(&'a mut dyn crate::runtime::io::IoHandlers),
    /// 要求と応答: 要求を返して止まる
    Request,
}

/// 実行ごとの VM の状態。
pub struct Vm<'p> {
    program: &'p CompiledProgram,
    config: VmConfig,
    regs: Vec<Value>,
    frames: Vec<Frame>,
    heap: Heap,
    /// 呼び出しの枠とレジスタの合計の大きさ（FRAME_COST と REG_COST で数える）
    cost: u64,
    /// 原型ごと・定数ごとの、作った値の使い回しの表（String と原型の定数だけ入れる。10-07）
    const_cache: Vec<Vec<Option<Value>>>,
    /// 要求と応答の方式で、応答を待っている IO の命令の結果のレジスタ
    pending_io: Option<u32>,
    /// `resume` で受け取った応答が止まる理由だったときに、次の `run` で返す
    pending_stop: Option<Stop>,
}

use crate::builtins::table::spec;
use crate::builtins::{BuiltinKind, ops};
use crate::bytecode::instr::{Instr, Opcode};
use crate::bytecode::program::{CaptureSource, ConstDesc, Proto};
use crate::runtime::ResourceError;
use crate::runtime::io::IoHandlers;
use crate::runtime::value::{FuncObj, values_equal};

/// 命令を一つ実行した後に、振り分けのループがどうするか。
enum Flow {
    /// 次の命令へ進む
    Continue,
    /// `main` の枠が降りた
    Finished(Value),
    /// 要求と応答の方式で、IO の要求を返す
    Request(IoRequest),
}

/// 処理系の不具合を表す止まる理由を作る。説明は調べるためのもので、診断の表に載せない（00-02「文言」）。
fn internal(message: &str) -> Stop {
    Stop::Internal(String::from(message))
}

/// 窓の中のレジスタ番号を、レジスタの積み重ねの中の位置にする。
fn reg_index(base: usize, i: u16) -> Result<usize, Stop> {
    base.checked_add(usize::from(i))
        .ok_or_else(|| internal("register index overflow"))
}

/// 窓の終わり（窓の後ろの最初の位置）。
#[inline]
fn window_end(base: usize, size: usize) -> Result<usize, Stop> {
    base.checked_add(size)
        .ok_or_else(|| internal("register stack overflow"))
}

/// 現在の枠の窓 `base .. base + size`。
///
/// レジスタの積み重ねは、呼び出しから戻っても縮めずに使い回す（伸び縮みのたびに確保と `Unit` の
/// 書き込みをしないため）。そのため積み重ねの長さは窓の終わりより長いことがあり、窓の外の読み書きは
/// 積み重ねの範囲ではなく窓の範囲で確かめる。窓の後ろのレジスタは常に `Unit` にしておく
/// （`RETURN` と `TAILCALL` が捨てる窓を `Unit` で埋める）ので、窓の外に古い値の参照は残らない（ADR 0078）。
#[inline]
fn window(regs: &mut [Value], base: usize, size: usize) -> Result<&mut [Value], Stop> {
    regs.get_mut(base..window_end(base, size)?)
        .ok_or_else(|| internal("window out of the register stack"))
}

/// 値を複製する。結果は `v.clone()` と同じである。
///
/// 参照を持たない値（`Int` など）は、その場で写す。参照を持つ値は参照の数を一つ増やす
/// （02-09「値の表現」）が、その処理は `Value` の `Clone` に任せ、振り分けのループの中に
/// 展開しない（命令ごとの処理が大きくなると、かえって遅くなった）。
#[inline(always)]
fn dup(v: &Value) -> Value {
    match v {
        Value::Int(n) => Value::Int(*n),
        Value::Float(x) => Value::Float(*x),
        Value::Bool(b) => Value::Bool(*b),
        Value::Char(ch) => Value::Char(*ch),
        Value::Unit => Value::Unit,
        Value::Str(_) | Value::Func(_) | Value::Ctor(_) | Value::List(_) | Value::IoError(_) => {
            v.clone()
        }
    }
}

/// レジスタに値を入れ、前の値を捨てる。
///
/// 前の値が参照を持たない値（`Int` など）なら、`Value` の解放の処理を呼ばずに済ませる。参照を
/// 持たない値は `forget` しても何も漏れない。参照を持つ値はその場で解放する（参照の数を一つ減らし、
/// 0 になれば解放する）ので、解放の時点は `*slot = value` と同じである。
#[inline(always)]
fn store(slot: &mut Value, value: Value) {
    let old = std::mem::replace(slot, value);
    match old {
        Value::Int(_) | Value::Float(_) | Value::Bool(_) | Value::Char(_) | Value::Unit => {
            std::mem::forget(old);
        }
        Value::Str(_) | Value::Func(_) | Value::Ctor(_) | Value::List(_) | Value::IoError(_) => {
            drop(old);
        }
    }
}

/// レジスタから値を移し出し、`Unit` を残す。移し出したレジスタをその後読まないことが
/// 命令の意味から確かな箇所（捨てる窓のレジスタ）でだけ使う。
#[inline(always)]
fn take(slot: &mut Value) -> Value {
    std::mem::replace(slot, Value::Unit)
}

/// 窓の `R[i]` を読む。
#[inline(always)]
fn read(regs: &[Value], i: u16) -> Result<&Value, Stop> {
    regs.get(usize::from(i))
        .ok_or_else(|| internal("register out of window"))
}

/// 窓の `R[i]` に書く。
#[inline(always)]
fn write(regs: &mut [Value], i: u16, value: Value) -> Result<(), Stop> {
    let slot = regs
        .get_mut(usize::from(i))
        .ok_or_else(|| internal("register out of window"))?;
    store(slot, value);
    Ok(())
}

/// 窓の `R[start] .. R[start + count - 1]` の並び。組み込みの関数・IO・構成子の引数に使う。
#[inline]
fn reg_slice(regs: &[Value], start: u16, count: u16) -> Result<&[Value], Stop> {
    let from = usize::from(start);
    let to = from
        .checked_add(usize::from(count))
        .ok_or_else(|| internal("register range overflow"))?;
    regs.get(from..to)
        .ok_or_else(|| internal("register range out of window"))
}

#[inline]
fn read_int(regs: &[Value], i: u16) -> Result<i64, Stop> {
    read(regs, i)?
        .as_int()
        .ok_or_else(|| internal("operand is not Int"))
}

fn read_float(regs: &[Value], i: u16) -> Result<f64, Stop> {
    read(regs, i)?
        .as_float()
        .ok_or_else(|| internal("operand is not Float"))
}

#[inline]
fn read_bool(regs: &[Value], i: u16) -> Result<bool, Stop> {
    read(regs, i)?
        .as_bool()
        .ok_or_else(|| internal("operand is not Bool"))
}

fn read_char(regs: &[Value], i: u16) -> Result<char, Stop> {
    read(regs, i)?
        .as_char()
        .ok_or_else(|| internal("operand is not Char"))
}

fn read_str(regs: &[Value], i: u16) -> Result<&str, Stop> {
    read(regs, i)?
        .as_str()
        .ok_or_else(|| internal("operand is not String"))
}

/// 呼ぶ関数の値の原型の番号。枠に置く参照は、`CALL` では複製し、`TAILCALL` では移す。
/// VM が作る関数の値は常に `FuncObj::Proto` である。`FuncObj::Ref` は参照インタプリタの値であり、VM に現れたら不具合である。
fn callee_proto(value: &Value) -> Result<ProtoIdx, Stop> {
    let Value::Func(func) = value else {
        return Err(internal("callee is not a function value"));
    };
    match func.obj() {
        FuncObj::Proto { proto, .. } => Ok(*proto),
        FuncObj::Ref { .. } => Err(internal("callee is a reference-interpreter function")),
    }
}

/// 関数の値から、呼び出しの枠に置く参照と原型の番号を取り出す。
/// VM が作る関数の値は常に `FuncObj::Proto` である。`FuncObj::Ref` は参照インタプリタの値であり、VM に現れたら不具合である。
#[inline]
fn callee_of(value: &Value) -> Result<(FuncRef, ProtoIdx), Stop> {
    let Value::Func(func) = value else {
        return Err(internal("callee is not a function value"));
    };
    match func.obj() {
        FuncObj::Proto { proto, .. } => Ok((func.clone(), *proto)),
        FuncObj::Ref { .. } => Err(internal("callee is a reference-interpreter function")),
    }
}

/// 現在の関数の値が捕捉した k 番目の値。
fn capture_of(func: &FuncRef, k: u16) -> Result<&Value, Stop> {
    match func.obj() {
        FuncObj::Proto { captures, .. } => captures
            .get(usize::from(k))
            .ok_or_else(|| internal("capture index out of range")),
        FuncObj::Ref { .. } => Err(internal("running a reference-interpreter function")),
    }
}

#[inline]
fn to_u32(n: usize) -> Result<u32, Stop> {
    u32::try_from(n).map_err(|_| internal("value does not fit u32"))
}

#[inline]
fn to_usize(n: u32) -> Result<usize, Stop> {
    usize::try_from(n).map_err(|_| internal("value does not fit usize"))
}

/// 窓の大きさ `n` のレジスタの分の大きさ（02-08「呼び出しの入れ子の上限」）。
/// 溢れたら `None` を返し、呼び出し側は上限を超えたものとして扱う。
fn regs_cost(n: u64) -> Option<u64> {
    REG_COST.checked_mul(n)
}

/// 呼び出しの枠一つと窓 `n` 個の分の大きさ。
fn frame_cost(n: u64) -> Option<u64> {
    regs_cost(n).and_then(|r| r.checked_add(FRAME_COST))
}

/// 跳ぶ先の位置。`next` は跳ぶ命令の次の位置、`offset` はそこからの相対位置（10-07「命令の符号化」）。
/// 計算は `i64` で行い、原型の命令の範囲の外なら不具合とする。
#[inline]
fn jump_target(next: u32, offset: i32, code_len: usize) -> Result<u32, Stop> {
    let target = i64::from(next)
        .checked_add(i64::from(offset))
        .ok_or_else(|| internal("jump target overflow"))?;
    let target = u32::try_from(target).map_err(|_| internal("jump target out of range"))?;
    if to_usize(target)? >= code_len {
        return Err(internal("jump target out of range"));
    }
    Ok(target)
}

impl<'p> Vm<'p> {
    /// 実行ごとの状態を作る。枠はまだ積まない（`start_main` で積む）。
    pub fn new(program: &'p CompiledProgram, config: VmConfig) -> Vm<'p> {
        // 使い回しの表は原型の定数表と同じ形にしておき、初めての `LOADK` で埋める（10-07）。
        let const_cache = program
            .protos
            .iter()
            .map(|p| vec![None; p.consts.len()])
            .collect();
        Vm {
            program,
            config,
            regs: Vec::new(),
            frames: Vec::new(),
            heap: Heap::new(),
            cost: 0,
            const_cache,
            pending_io: None,
            pending_stop: None,
        }
    }

    /// `main` の関数の値を引数なしで呼ぶ呼び出しの枠を積む（02-08「実行の開始と終わり」）。
    pub fn start_main(&mut self) -> Result<(), StopInfo> {
        let no_instr = |stop: Stop| StopInfo {
            stop,
            at: None,
            frames: Vec::new(),
        };
        if !self.frames.is_empty() {
            return Err(no_instr(internal("main is already started")));
        }
        let main = self.program.main;
        let Some(proto) = self.program.proto(main) else {
            return Err(no_instr(internal("main prototype is missing")));
        };
        if proto.num_params != 0 {
            return Err(no_instr(internal("main takes parameters")));
        }
        let n = proto.num_regs;
        // main の枠も呼び出しの情報に数える。確保の前に上限を確かめる（02-08「呼び出しの入れ子の上限」）。
        let cost = match frame_cost(u64::from(n)) {
            Some(c) if c <= self.config.max_call_stack_bytes => c,
            Some(_) | None => {
                return Err(no_instr(Stop::Resource(ResourceError::CallStackTooDeep {
                    frames: 0,
                })));
            }
        };
        let func_value = self.heap.func_proto(main, Vec::new());
        let (func, _) = callee_of(&func_value).map_err(no_instr)?;
        self.regs.resize(usize::from(n), Value::Unit);
        self.frames.push(Frame {
            func,
            proto: main,
            pc: 0,
            base: 0,
            size: u32::from(n),
            ret_reg: 0,
            call_site: None,
        });
        self.cost = cost;
        Ok(())
    }

    /// 命令を実行する。直接呼び出しの方式では `Request` を返さない。
    ///
    /// 振り分けのループはこの関数の中の一つだけである。命令一つは `step` が実行するが、`step` は
    /// 言語の関数の呼び出しでも枠の積み重ねを操作して戻るだけであり、Rust の関数を入れ子に呼ばない
    /// （設計書 02-08「実行の手順」、ADR 0016）。
    pub fn run(&mut self, mut io: IoDispatch<'_>) -> VmStep {
        // 要求への応答が止まる理由だったときは、要求を出した IO の命令で止まったものとして記録する。
        // その命令は、枠の pc を進めた後の一つ前の位置にある（02-08「IO の命令」）。
        if let Some(stop) = self.pending_stop.take() {
            let at = self.frames.last().and_then(|f| {
                f.pc.checked_sub(1)
                    .map(|pc| InstrRef { proto: f.proto, pc })
            });
            return VmStep::Stopped(self.stop_info(stop, at));
        }
        if self.pending_io.is_some() {
            return VmStep::Stopped(self.stop_info(internal("run before resume"), None));
        }
        let mut builtins = BuiltinCache::new();
        loop {
            let Some(frame) = self.frames.last() else {
                return VmStep::Stopped(self.stop_info(internal("no frame to run"), None));
            };
            let at = InstrRef {
                proto: frame.proto,
                pc: frame.pc,
            };
            match self.step(&mut io, &mut builtins, at) {
                Ok(Flow::Continue) => {}
                Ok(Flow::Finished(value)) => return VmStep::Finished(value),
                Ok(Flow::Request(request)) => return VmStep::Request(request),
                // 枠を一つも降ろさずに記録する（02-08「実行時エラーの情報の記録」）。
                Err(stop) => return VmStep::Stopped(self.stop_info(stop, Some(at))),
            }
        }
    }

    /// 要求と応答の方式で、要求への応答を渡す。続けて `run` を呼ぶ。
    pub fn resume(&mut self, response: Result<Value, Stop>) {
        let Some(slot) = self.pending_io.take() else {
            self.pending_stop = Some(internal("resume without a pending request"));
            return;
        };
        match response {
            Ok(value) => {
                let Ok(slot) = to_usize(slot) else {
                    self.pending_stop = Some(internal("pending register out of range"));
                    return;
                };
                match self.regs.get_mut(slot) {
                    Some(r) => *r = value,
                    None => self.pending_stop = Some(internal("pending register out of range")),
                }
            }
            Err(stop) => self.pending_stop = Some(stop),
        }
    }

    /// 実行ごとのヒープ（確保の統計を読むのに使う）。
    pub fn heap(&self) -> &Heap {
        &self.heap
    }

    /// 実行ごとのヒープ。要求と応答の方式で、外側の実行器がハンドラ表に渡す。
    pub fn heap_mut(&mut self) -> &mut Heap {
        &mut self.heap
    }

    /// 止まったときの記録。枠の積み重ねを内側から外側の順に写す（02-08「実行時エラーの情報の記録」）。
    fn stop_info(&self, stop: Stop, at: Option<InstrRef>) -> StopInfo {
        let frames = self
            .frames
            .iter()
            .rev()
            .map(|f| FrameRecord {
                proto: f.proto,
                call_site: f.call_site,
            })
            .collect();
        StopInfo { stop, at, frames }
    }

    fn frame_count(&self) -> u64 {
        u64::try_from(self.frames.len()).unwrap_or(u64::MAX)
    }

    fn too_deep(&self) -> Stop {
        Stop::Resource(ResourceError::CallStackTooDeep {
            frames: self.frame_count(),
        })
    }

    /// 現在の枠の命令を一つ実行する。`at` はその命令の位置。
    /// `Err` を返すときは、枠の積み重ねを変えていない（呼び出しの上限は枠を積む前に確かめる）。
    fn step(
        &mut self,
        io: &mut IoDispatch<'_>,
        builtins: &mut BuiltinCache,
        at: InstrRef,
    ) -> Result<Flow, Stop> {
        let program = self.program;
        let proto = program
            .proto(at.proto)
            .ok_or_else(|| internal("prototype is missing"))?;
        let instr: Instr = *proto
            .code
            .get(to_usize(at.pc)?)
            .ok_or_else(|| internal("pc out of range"))?;
        let next = at
            .pc
            .checked_add(1)
            .ok_or_else(|| internal("pc overflow"))?;
        let frame = self
            .frames
            .last_mut()
            .ok_or_else(|| internal("no frame to run"))?;
        // 命令を読んだら先に pc を進める。跳ぶ命令の相対位置は、進めた後の位置から数える（10-07）。
        frame.pc = next;
        let base = to_usize(frame.base)?;
        let size = to_usize(frame.size)?;
        let op = instr.opcode().ok_or_else(|| internal("unknown opcode"))?;
        let (a, b, c) = (instr.a(), instr.b(), instr.c());
        // 以下の命令は、窓の中のレジスタ番号で読み書きする。
        let regs = window(&mut self.regs, base, size)?;

        match op {
            // MOVE の後も元のレジスタ（変数のレジスタなど）は読まれうるので、移さずに複製する。
            Opcode::Move => {
                let v = dup(read(regs, b)?);
                write(regs, a, v)?;
            }
            Opcode::LoadK => {
                let v = self.load_const(proto, at.proto, instr.bx())?;
                write(window(&mut self.regs, base, size)?, a, v)?;
            }
            Opcode::GetCap => {
                let frame = self
                    .frames
                    .last()
                    .ok_or_else(|| internal("no frame to run"))?;
                let v = dup(capture_of(&frame.func, b)?);
                write(regs, a, v)?;
            }
            Opcode::Closure => {
                let target = ProtoIdx(instr.bx());
                let target_proto = program
                    .proto(target)
                    .ok_or_else(|| internal("closure prototype is missing"))?;
                let frame = self
                    .frames
                    .last()
                    .ok_or_else(|| internal("no frame to run"))?;
                // 平らなクロージャ: 捕捉する値を作る時点で写す（02-07「関数の値と捕捉」）。
                let mut captures = Vec::with_capacity(target_proto.captures.len());
                for source in &target_proto.captures {
                    let v = match *source {
                        CaptureSource::Reg(r) => read(regs, r)?,
                        CaptureSource::Capture(k) => capture_of(&frame.func, k)?,
                    };
                    captures.push(dup(v));
                }
                let v = self.heap.func_proto(target, captures);
                write(regs, a, v)?;
            }
            Opcode::Call => return self.call(at, base, a, b, c),
            Opcode::TailCall => return self.tail_call(at, base, b, c),
            Opcode::Return => return self.ret(base, a),
            Opcode::Prim => {
                let (kind, arity) = builtins.get(program, b)?;
                let BuiltinKind::Pure(f) = kind else {
                    return Err(internal("PRIM refers to an IO builtin"));
                };
                // 引数は窓のレジスタをそのまま借りて渡す。組み込みの関数は引数を変えない。
                let args = reg_slice(regs, c, arity)?;
                let v = f(&mut self.heap, args)?;
                write(regs, a, v)?;
            }
            Opcode::Io => {
                let (kind, arity) = builtins.get(program, b)?;
                let BuiltinKind::Io(io_op) = kind else {
                    return Err(internal("IO refers to a pure builtin"));
                };
                let args = reg_slice(regs, c, arity)?;
                // 結果のレジスタ A が窓の中かを、IO を行う前に確かめる。要求と応答の方式では、応答を
                // `resume` が並びの絶対位置に書き込む。並びは窓より長いことがある（戻っても縮めない）ので、
                // ここで確かめないと窓の外に書き込んでしまう。二つの方式で同じく、IO を行わずに止まる。
                if usize::from(a) >= regs.len() {
                    return Err(internal("register out of window"));
                }
                match io {
                    // 直接呼び出し: 応答が止まる理由なら、この命令で止まる（02-08「IO の命令」、ADR 0029）。
                    IoDispatch::Direct(handlers) => {
                        let v = IoHandlers::call(&mut **handlers, io_op, args, &mut self.heap)?;
                        write(regs, a, v)?;
                    }
                    // 要求と応答: pc は進めてあるので、応答を入れた後は次の命令から続く。
                    IoDispatch::Request => {
                        let args = args.iter().map(dup).collect();
                        let slot = to_u32(reg_index(base, a)?)?;
                        self.pending_io = Some(slot);
                        return Ok(Flow::Request(IoRequest { op: io_op, args }));
                    }
                }
            }
            Opcode::AddI => int_binary(regs, a, b, c, ops::int_add)?,
            Opcode::SubI => int_binary(regs, a, b, c, ops::int_sub)?,
            Opcode::MulI => int_binary(regs, a, b, c, ops::int_mul)?,
            Opcode::DivI => int_binary(regs, a, b, c, ops::int_div)?,
            Opcode::ModI => int_binary(regs, a, b, c, ops::int_rem)?,
            Opcode::NegI => {
                let v = ops::int_neg(read_int(regs, b)?)?;
                write(regs, a, Value::Int(v))?;
            }
            Opcode::AddF => float_binary(regs, a, b, c, |x, y| x + y)?,
            Opcode::SubF => float_binary(regs, a, b, c, |x, y| x - y)?,
            Opcode::MulF => float_binary(regs, a, b, c, |x, y| x * y)?,
            Opcode::DivF => float_binary(regs, a, b, c, |x, y| x / y)?,
            Opcode::NegF => {
                let v = -read_float(regs, b)?;
                write(regs, a, Value::Float(v))?;
            }
            Opcode::Concat => {
                let v = ops::string_concat(&mut self.heap, read_str(regs, b)?, read_str(regs, c)?)?;
                write(regs, a, v)?;
            }
            Opcode::EqI => compare(regs, a, b, c, read_int, |x, y| x == y)?,
            Opcode::LtI => compare(regs, a, b, c, read_int, |x, y| x < y)?,
            Opcode::LeI => compare(regs, a, b, c, read_int, |x, y| x <= y)?,
            // Float の比較は IEEE 754 に従い、NaN との比較はすべて false（01-04「Float」）。
            Opcode::EqF => compare(regs, a, b, c, read_float, |x, y| x == y)?,
            Opcode::LtF => compare(regs, a, b, c, read_float, |x, y| x < y)?,
            Opcode::LeF => compare(regs, a, b, c, read_float, |x, y| x <= y)?,
            // String の順序はスカラー値の辞書式の順序で、UTF-8 のバイト列の順序と一致する（01-04「String」）。
            Opcode::EqS => str_compare(regs, a, b, c, |x, y| x == y)?,
            Opcode::LtS => str_compare(regs, a, b, c, |x, y| x < y)?,
            Opcode::LeS => str_compare(regs, a, b, c, |x, y| x <= y)?,
            Opcode::EqC => compare(regs, a, b, c, read_char, |x, y| x == y)?,
            Opcode::LtC => compare(regs, a, b, c, read_char, |x, y| x < y)?,
            Opcode::LeC => compare(regs, a, b, c, read_char, |x, y| x <= y)?,
            Opcode::EqB => compare(regs, a, b, c, read_bool, |x, y| x == y)?,
            Opcode::EqV => {
                let v = values_equal(read(regs, b)?, read(regs, c)?)?;
                write(regs, a, Value::Bool(v))?;
            }
            Opcode::Not => {
                let v = !read_bool(regs, b)?;
                write(regs, a, Value::Bool(v))?;
            }
            Opcode::Con => {
                let info = program
                    .ctors
                    .get(usize::from(b))
                    .ok_or_else(|| internal("constructor index out of range"))?;
                let fields = reg_slice(regs, c, info.arity)?.iter().map(dup).collect();
                let v = self.heap.ctor(info.tag, fields);
                write(regs, a, v)?;
            }
            Opcode::List => {
                let items = reg_slice(regs, b, c)?.iter().map(dup).collect();
                // 要素の数はレジスタの数（65535 以下）を超えないので、長さの上限には当たらない。
                let v = self.heap.list_from_vec(items, "list literal")?;
                write(regs, a, v)?;
            }
            Opcode::Field => {
                let (_, fields) = read(regs, b)?
                    .as_ctor()
                    .ok_or_else(|| internal("FIELD operand is not a constructor value"))?;
                let v = dup(fields
                    .get(usize::from(c))
                    .ok_or_else(|| internal("FIELD index out of range"))?);
                write(regs, a, v)?;
            }
            Opcode::Jmp => {
                let target = jump_target(next, instr.sbx(), proto.code.len())?;
                self.set_pc(target)?;
            }
            Opcode::JmpF => {
                if !read_bool(regs, a)? {
                    let target = jump_target(next, instr.sbx(), proto.code.len())?;
                    self.set_pc(target)?;
                }
            }
            Opcode::Switch => {
                let (tag, _) = read(regs, a)?
                    .as_ctor()
                    .ok_or_else(|| internal("SWITCH operand is not a constructor value"))?;
                let table = proto
                    .switch_tables
                    .get(to_usize(instr.bx())?)
                    .ok_or_else(|| internal("switch table index out of range"))?;
                // 表にないタグは `_` の分岐へ。`_` の分岐もなければ、型検査を通ったプログラムでは起きない。
                let offset = to_usize(tag)
                    .ok()
                    .and_then(|t| table.targets.get(t).copied().flatten())
                    .or(table.default)
                    .ok_or_else(|| internal("SWITCH has no branch for the tag"))?;
                let target = jump_target(next, offset, proto.code.len())?;
                self.set_pc(target)?;
            }
        }
        Ok(Flow::Continue)
    }

    fn set_pc(&mut self, pc: u32) -> Result<(), Stop> {
        let frame = self
            .frames
            .last_mut()
            .ok_or_else(|| internal("no frame to run"))?;
        frame.pc = pc;
        Ok(())
    }

    /// `LOADK`: 定数の記述から値を作る（02-07「値の移し方」）。`String` と原型の定数から作った値だけを
    /// 使い回しの表に取っておく。ほかの定数はヒープを確保しないので毎回作る（10-07）。
    fn load_const(&mut self, proto: &Proto, proto_idx: ProtoIdx, k: u32) -> Result<Value, Stop> {
        let k = to_usize(k)?;
        let desc = proto
            .consts
            .get(k)
            .ok_or_else(|| internal("constant index out of range"))?;
        let v = match desc {
            ConstDesc::Int(n) => Value::Int(*n),
            ConstDesc::Float(x) => Value::Float(*x),
            ConstDesc::Char(ch) => Value::Char(*ch),
            ConstDesc::Bool(bv) => Value::Bool(*bv),
            ConstDesc::Unit => Value::Unit,
            ConstDesc::NullaryCtor { tag } => self.heap.ctor(*tag, Vec::new()),
            ConstDesc::Str(_) | ConstDesc::Proto(_) => {
                let slot = self
                    .const_cache
                    .get_mut(to_usize(proto_idx.0)?)
                    .and_then(|row| row.get_mut(k))
                    .ok_or_else(|| internal("constant cache out of range"))?;
                if let Some(v) = slot {
                    return Ok(v.clone());
                }
                let v = match desc {
                    ConstDesc::Str(s) => self.heap.string(s),
                    ConstDesc::Proto(p) => self.heap.func_proto(*p, Vec::new()),
                    ConstDesc::Int(_)
                    | ConstDesc::Float(_)
                    | ConstDesc::Char(_)
                    | ConstDesc::Bool(_)
                    | ConstDesc::Unit
                    | ConstDesc::NullaryCtor { .. } => {
                        return Err(internal("unexpected constant kind"));
                    }
                };
                *slot = Some(v.clone());
                v
            }
        };
        Ok(v)
    }

    /// `CALL A B C`（02-08「実行の手順」）。上限を確かめてから、現在の窓の後ろに新しい窓を確保して枠を積む。
    fn call(&mut self, at: InstrRef, base: usize, a: u16, b: u16, c: u16) -> Result<Flow, Stop> {
        let frame = self
            .frames
            .last()
            .ok_or_else(|| internal("no frame to run"))?;
        let new_base = window_end(base, to_usize(frame.size)?)?;
        let caller = self
            .regs
            .get(base..new_base)
            .ok_or_else(|| internal("window out of the register stack"))?;
        let (func, callee) = callee_of(read(caller, b)?)?;
        let callee_proto = self
            .program
            .proto(callee)
            .ok_or_else(|| internal("callee prototype is missing"))?;
        if callee_proto.num_params != c {
            return Err(internal("argument count does not match the callee"));
        }
        let n = callee_proto.num_regs;
        if c > n {
            return Err(internal("callee has fewer registers than parameters"));
        }
        // 上限を超えるときは呼び出しを行わない。溢れも上限を超えたものとして扱う（02-08「呼び出しの入れ子の上限」）。
        let new_cost = frame_cost(u64::from(n))
            .and_then(|add| self.cost.checked_add(add))
            .filter(|total| *total <= self.config.max_call_stack_bytes)
            .ok_or_else(|| self.too_deep())?;
        let ret_reg = to_u32(reg_index(base, a)?)?;
        let arg_start = reg_index(base, b)?
            .checked_add(1)
            .ok_or_else(|| internal("register index overflow"))?;
        let arg_end = arg_start
            .checked_add(usize::from(c))
            .ok_or_else(|| internal("register index overflow"))?;
        if arg_end > new_base {
            return Err(internal("arguments out of window"));
        }
        let new_base_u32 = to_u32(new_base)?;
        let new_len = window_end(new_base, usize::from(n))?;
        // 積み重ねは縮めずに使い回すので、足りないときだけ伸ばす。窓の後ろは常に Unit なので、
        // 新しい窓の引数でないレジスタを埋め直す必要はない。
        if self.regs.len() < new_len {
            self.regs.resize(new_len, Value::Unit);
        }
        // 引数を新しい窓のレジスタ 0 から順に写す。CALL の後も呼び出し元の引数のレジスタは残る
        // （02-08 の CALL は引数を「写す」）ので、移さずに複製する。
        let (lower, upper) = self
            .regs
            .split_at_mut_checked(new_base)
            .ok_or_else(|| internal("register stack overflow"))?;
        let args = lower
            .get(arg_start..arg_end)
            .ok_or_else(|| internal("arguments out of window"))?;
        let params = upper
            .get_mut(..usize::from(c))
            .ok_or_else(|| internal("register stack overflow"))?;
        for (param, arg) in params.iter_mut().zip(args) {
            store(param, dup(arg));
        }
        self.frames.push(Frame {
            func,
            proto: callee,
            pc: 0,
            base: new_base_u32,
            size: u32::from(n),
            ret_reg,
            call_site: Some(at),
        });
        self.cost = new_cost;
        Ok(Flow::Continue)
    }

    /// `TAILCALL B C`（02-08「実行の手順」、ADR 0013）。枠を積まずに現在の枠を置き換える。
    fn tail_call(&mut self, at: InstrRef, base: usize, b: u16, c: u16) -> Result<Flow, Stop> {
        let frame = self
            .frames
            .last()
            .ok_or_else(|| internal("no frame to run"))?;
        let size = frame.size;
        let old_size = to_usize(size)?;
        let old_window = self
            .regs
            .get(base..window_end(base, old_size)?)
            .ok_or_else(|| internal("window out of the register stack"))?;
        let callee = callee_proto(read(old_window, b)?)?;
        let callee_proto = self
            .program
            .proto(callee)
            .ok_or_else(|| internal("callee prototype is missing"))?;
        if callee_proto.num_params != c {
            return Err(internal("argument count does not match the callee"));
        }
        let n = callee_proto.num_regs;
        if c > n {
            return Err(internal("callee has fewer registers than parameters"));
        }
        let arg_start = usize::from(b)
            .checked_add(1)
            .ok_or_else(|| internal("register index overflow"))?;
        let arg_end = arg_start
            .checked_add(usize::from(c))
            .ok_or_else(|| internal("register index overflow"))?;
        if arg_end > old_size {
            return Err(internal("arguments out of window"));
        }
        let size = u64::from(size);
        let n64 = u64::from(n);
        // 窓が大きくなるときだけ上限を確かめる。小さくなるときは減らすだけである。
        let new_cost = if n64 > size {
            regs_cost(n64.saturating_sub(size))
                .and_then(|add| self.cost.checked_add(add))
                .filter(|total| *total <= self.config.max_call_stack_bytes)
                .ok_or_else(|| self.too_deep())?
        } else {
            regs_cost(size.saturating_sub(n64))
                .and_then(|sub| self.cost.checked_sub(sub))
                .ok_or_else(|| internal("call stack cost underflow"))?
        };
        let new_len = window_end(base, usize::from(n))?;
        if self.regs.len() < new_len {
            self.regs.resize(new_len, Value::Unit);
        }
        // ここから先は失敗しない確かめだけが残る。古い窓は捨てるので、関数の値と引数は
        // 複製せずに移す（捨てる窓のレジスタは、この後だれも読まない）。
        let regs = self
            .regs
            .get_mut(base..)
            .ok_or_else(|| internal("window out of the register stack"))?;
        let Value::Func(func) = take(
            regs.get_mut(usize::from(b))
                .ok_or_else(|| internal("register out of window"))?,
        ) else {
            return Err(internal("callee is not a function value"));
        };
        // 引数を窓の先頭に移す。引数のレジスタと窓の先頭は重なりうるが、i 番目の引数の元の位置
        // （b + 1 + i）は行き先 i より後ろにあるので、先頭から順に移せば、まだ移していない引数を
        // 上書きしない。行き先にあった古い値は、上書きするときに解放する。
        for i in 0..usize::from(c) {
            let from = arg_start
                .checked_add(i)
                .ok_or_else(|| internal("register index overflow"))?;
            let v = take(
                regs.get_mut(from)
                    .ok_or_else(|| internal("arguments out of window"))?,
            );
            store(
                regs.get_mut(i)
                    .ok_or_else(|| internal("register out of window"))?,
                v,
            );
        }
        // 古い窓の残りの値を捨てて Unit にする。使わなくなったレジスタに参照を残さない（ADR 0078）。
        // 新しい窓が古い窓より大きいときも、古い窓の後ろは元から Unit なので、新しい窓の引数でない
        // レジスタはすべて Unit になる。
        let rest = regs
            .get_mut(usize::from(c)..old_size)
            .ok_or_else(|| internal("window out of the register stack"))?;
        for slot in rest {
            store(slot, Value::Unit);
        }
        let frame = self
            .frames
            .last_mut()
            .ok_or_else(|| internal("no frame to run"))?;
        frame.func = func;
        frame.proto = callee;
        frame.pc = 0;
        frame.size = u32::from(n);
        frame.call_site = Some(at);
        self.cost = new_cost;
        Ok(Flow::Continue)
    }

    /// `RETURN A`（02-08「実行の手順」）。枠を降ろし、窓のレジスタを捨てて、結果を呼び出し元のレジスタに入れる。
    fn ret(&mut self, base: usize, a: u16) -> Result<Flow, Stop> {
        let frame = self
            .frames
            .last()
            .ok_or_else(|| internal("no frame to run"))?;
        let is_main = self.frames.len() == 1;
        let ret_reg = to_usize(frame.ret_reg)?;
        // 枠を降ろす前に、失敗しうる確かめをすべて済ませる（止まるときは枠を変えない）。
        if !is_main && ret_reg >= base {
            return Err(internal("return register is not in the caller window"));
        }
        let released = frame_cost(u64::from(frame.size))
            .and_then(|sub| self.cost.checked_sub(sub))
            .ok_or_else(|| internal("call stack cost underflow"))?;
        let regs = window(&mut self.regs, base, to_usize(frame.size)?)?;
        let result = take(
            regs.get_mut(usize::from(a))
                .ok_or_else(|| internal("register out of window"))?,
        );
        // 窓のレジスタを捨てて Unit にする。参照が残ると解放が遅れる（ADR 0078）。積み重ねは縮めずに
        // 次の呼び出しで使い回す。
        for slot in regs {
            store(slot, Value::Unit);
        }
        self.frames.pop();
        self.cost = released;
        if is_main {
            return Ok(Flow::Finished(result));
        }
        let slot = self
            .regs
            .get_mut(ret_reg)
            .ok_or_else(|| internal("return register out of range"))?;
        store(slot, result);
        Ok(Flow::Continue)
    }
}

/// 組み込みの関数の控えの大きさ。番号の下位の桁で場所を決める（直接写像）。
const BUILTIN_CACHE_SIZE: usize = 32;

/// `run` 一回の間の、組み込みの関数の種類と引数の個数の控え。
///
/// `PRIM` と `IO` のたびに組み込みの表（`builtins::table::spec`）を引くと、表の項目を毎回作り直す
/// 費用がかかる。表は実行の間に変わらない（00-02「大域の状態」）ので、引いた結果を控えて使い回す。
/// 控えは `run` の局所の値であり、`Vm` の欄は増やさない。要求と応答の方式では要求のたびに `run` を
/// 呼び直すので、控えはヒープを確保しない固定の大きさの配列にし、作る費用を小さくする。
/// 番号が同じ場所に当たったら、後から引いたもので置き換える（結果は表を引いたときと変わらない）。
struct BuiltinCache {
    entries: [Option<(u16, BuiltinKind, u16)>; BUILTIN_CACHE_SIZE],
}

impl BuiltinCache {
    fn new() -> BuiltinCache {
        BuiltinCache {
            entries: [None; BUILTIN_CACHE_SIZE],
        }
    }

    /// 番号 `b` の組み込みの関数の種類と引数の個数。
    #[inline]
    fn get(&mut self, program: &CompiledProgram, b: u16) -> Result<(BuiltinKind, u16), Stop> {
        let slot = self
            .entries
            .get_mut(usize::from(b) % BUILTIN_CACHE_SIZE)
            .ok_or_else(|| internal("builtin cache index out of range"))?;
        if let Some((key, kind, arity)) = *slot
            && key == b
        {
            return Ok((kind, arity));
        }
        let id = program
            .builtins
            .get(usize::from(b))
            .ok_or_else(|| internal("builtin index out of range"))?;
        let s = spec(*id);
        *slot = Some((b, s.kind, s.arity));
        Ok((s.kind, s.arity))
    }
}

/// `Int` の二項の演算。溢れと 0 による除算は `builtins::ops` が実行時エラーとして返す。
fn int_binary(
    regs: &mut [Value],
    a: u16,
    b: u16,
    c: u16,
    f: fn(i64, i64) -> Result<i64, Stop>,
) -> Result<(), Stop> {
    let v = f(read_int(regs, b)?, read_int(regs, c)?)?;
    write(regs, a, Value::Int(v))
}

/// `Float` の二項の演算。IEEE 754 の結果をそのまま返し、実行時エラーにしない（01-04「Float」）。
fn float_binary(
    regs: &mut [Value],
    a: u16,
    b: u16,
    c: u16,
    f: fn(f64, f64) -> f64,
) -> Result<(), Stop> {
    let v = f(read_float(regs, b)?, read_float(regs, c)?);
    write(regs, a, Value::Float(v))
}

/// 比較の命令。`R[A] ← R[B] ⊕ R[C]` の結果を `Bool` で入れる。
fn compare<T>(
    regs: &mut [Value],
    a: u16,
    b: u16,
    c: u16,
    get: fn(&[Value], u16) -> Result<T, Stop>,
    f: fn(T, T) -> bool,
) -> Result<(), Stop> {
    let v = f(get(regs, b)?, get(regs, c)?);
    write(regs, a, Value::Bool(v))
}

/// `String` の比較の命令。借りた `&str` の寿命が引数ごとに違うので、`compare` と分けて書く。
fn str_compare(
    regs: &mut [Value],
    a: u16,
    b: u16,
    c: u16,
    f: fn(&str, &str) -> bool,
) -> Result<(), Stop> {
    let v = f(read_str(regs, b)?, read_str(regs, c)?);
    write(regs, a, Value::Bool(v))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // 命令を手で組んだプログラムを VM の公開の関数で実行し、結果と止まったときの記録を確かめる
    // （設計書 07-03「テストの設計の原則」）。
    use std::collections::BTreeMap;
    use std::sync::Arc;

    use super::{
        DEFAULT_MAX_CALL_STACK, FrameRecord, InstrRef, IoDispatch, StopInfo, Vm, VmConfig, VmStep,
    };
    use crate::base::SourceTable;
    use crate::builtins::BuiltinId;
    use crate::bytecode::instr::{Instr, Opcode};
    use crate::bytecode::program::{
        CaptureSource, CompiledProgram, ConstDesc, CtorInfo, MainKind, Proto, ProtoIdx,
        ProtoOrigin, SwitchTable,
    };
    use crate::runtime::heap::Heap;
    use crate::runtime::io::{IoEvent, IoHandlers, IoOp};
    use crate::runtime::test_io::TestIo;
    use crate::runtime::value::Value;
    use crate::runtime::{ResourceError, RuntimeError, Stop, Stream};

    fn abc(op: Opcode, a: u16, b: u16, c: u16) -> Instr {
        Instr::abc(op, a, b, c)
    }

    fn abx(op: Opcode, a: u16, bx: u32) -> Instr {
        Instr::abx(op, a, bx)
    }

    fn asbx(op: Opcode, a: u16, sbx: i32) -> Instr {
        Instr::asbx(op, a, sbx)
    }

    /// 手で組む原型。捕捉と分岐表は後から欄を書き換えて与える。
    fn proto(code: Vec<Instr>, consts: Vec<ConstDesc>, num_regs: u16, num_params: u16) -> Proto {
        let positions = vec![None; code.len()];
        Proto {
            name: String::from("f"),
            origin: ProtoOrigin::UserFn,
            lambda_span: None,
            code,
            consts,
            switch_tables: Vec::new(),
            num_regs,
            num_params,
            captures: Vec::new(),
            positions,
        }
    }

    /// 原型 0 を `main` とするプログラム。
    fn program(
        protos: Vec<Proto>,
        builtins: Vec<BuiltinId>,
        ctors: Vec<CtorInfo>,
    ) -> CompiledProgram {
        CompiledProgram {
            protos,
            top_fns: Vec::new(),
            ctors,
            builtins,
            main: ProtoIdx(0),
            main_kind: MainKind::Unit,
            sources: Arc::new(SourceTable::new()),
        }
    }

    fn ctor(tag: u32, arity: u16) -> CtorInfo {
        CtorInfo {
            type_name: String::from("T"),
            ctor_name: format!("C{tag}"),
            tag,
            arity,
        }
    }

    #[derive(Clone, Copy)]
    enum Mode {
        Direct,
        Request,
    }

    /// `main` を最後まで実行する。要求と応答の方式では、要求ごとにハンドラ表を呼んで `resume` する。
    fn execute(program: &CompiledProgram, max: u64, mode: Mode, io: &mut dyn IoHandlers) -> VmStep {
        let mut vm = Vm::new(
            program,
            VmConfig {
                max_call_stack_bytes: max,
            },
        );
        if let Err(info) = vm.start_main() {
            return VmStep::Stopped(info);
        }
        match mode {
            Mode::Direct => vm.run(IoDispatch::Direct(io)),
            Mode::Request => loop {
                match vm.run(IoDispatch::Request) {
                    VmStep::Request(req) => {
                        let response = io.call(req.op, &req.args, vm.heap_mut());
                        vm.resume(response);
                    }
                    other @ (VmStep::Finished(_) | VmStep::Stopped(_)) => return other,
                }
            },
        }
    }

    fn run(program: &CompiledProgram, max: u64) -> VmStep {
        execute(program, max, Mode::Direct, &mut TestIo::default())
    }

    fn finished(step: VmStep) -> Value {
        match step {
            VmStep::Finished(v) => v,
            other @ (VmStep::Request(_) | VmStep::Stopped(_)) => {
                panic!("expected Finished, got {other:?}")
            }
        }
    }

    fn stopped(step: VmStep) -> StopInfo {
        match step {
            VmStep::Stopped(info) => info,
            other @ (VmStep::Request(_) | VmStep::Finished(_)) => {
                panic!("expected Stopped, got {other:?}")
            }
        }
    }

    fn at(proto: u32, pc: u32) -> InstrRef {
        InstrRef {
            proto: ProtoIdx(proto),
            pc,
        }
    }

    #[test]
    fn int_division_truncates_and_zero_divisor_stops_at_the_instruction() {
        // 01-04「Int」: `/` は 0 の方向に切り捨て、`%` の符号は被除数と同じ。除数 0 は実行時エラー。
        let cases = [
            (Opcode::DivI, -7, 2, Ok(-3)),
            (Opcode::ModI, -7, 2, Ok(-1)),
            (Opcode::ModI, 7, -2, Ok(1)),
            (Opcode::DivI, 7, 0, Err(RuntimeError::DivisionByZero)),
            (Opcode::ModI, 7, 0, Err(RuntimeError::DivisionByZero)),
            (
                Opcode::DivI,
                i64::MIN,
                -1,
                Err(RuntimeError::IntegerOverflow),
            ),
        ];
        for (op, x, y, expected) in cases {
            let main = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    abx(Opcode::LoadK, 1, 1),
                    abc(op, 2, 0, 1),
                    abc(Opcode::Return, 2, 0, 0),
                ],
                vec![ConstDesc::Int(x), ConstDesc::Int(y)],
                3,
                0,
            );
            let p = program(vec![main], Vec::new(), Vec::new());
            let step = run(&p, DEFAULT_MAX_CALL_STACK);
            match expected {
                Ok(v) => assert_eq!(finished(step).as_int(), Some(v), "{op:?} {x} {y}"),
                Err(e) => {
                    let info = stopped(step);
                    assert_eq!(info.stop, Stop::Runtime(e), "{op:?} {x} {y}");
                    assert_eq!(info.at, Some(at(0, 2)));
                    assert_eq!(
                        info.frames,
                        vec![FrameRecord {
                            proto: ProtoIdx(0),
                            call_site: None
                        }]
                    );
                }
            }
        }
    }

    #[test]
    fn call_passes_arguments_and_keeps_the_caller_window() {
        // main: R3 = add(40, 2); R4 = R3 + R1。呼び出しの後も呼び出し元の R1 が残っていることを確かめる。
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abx(Opcode::LoadK, 1, 1),
                abx(Opcode::LoadK, 2, 2),
                abc(Opcode::Call, 3, 0, 2),
                abc(Opcode::AddI, 4, 3, 1),
                abc(Opcode::Return, 4, 0, 0),
            ],
            vec![
                ConstDesc::Proto(ProtoIdx(1)),
                ConstDesc::Int(40),
                ConstDesc::Int(2),
            ],
            5,
            0,
        );
        let add = proto(
            vec![abc(Opcode::AddI, 2, 0, 1), abc(Opcode::Return, 2, 0, 0)],
            Vec::new(),
            3,
            2,
        );
        let p = program(vec![main, add], Vec::new(), Vec::new());
        assert_eq!(finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(), Some(82));
    }

    #[test]
    fn closures_capture_outer_registers_and_outer_captures() {
        // main: x = 10; f1 = fn(y) { f2 = fn() { x - y }; f2() }; f1(5)
        // f2 は x を f1 の捕捉から（Capture）、y を f1 のレジスタから（Reg）写す。
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abx(Opcode::Closure, 1, 1),
                abx(Opcode::LoadK, 2, 1),
                abc(Opcode::Call, 0, 1, 1),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![ConstDesc::Int(10), ConstDesc::Int(5)],
            3,
            0,
        );
        let mut f1 = proto(
            vec![
                abx(Opcode::Closure, 1, 2),
                abc(Opcode::Call, 1, 1, 0),
                abc(Opcode::Return, 1, 0, 0),
            ],
            Vec::new(),
            2,
            1,
        );
        f1.captures = vec![CaptureSource::Reg(0)];
        let mut f2 = proto(
            vec![
                abc(Opcode::GetCap, 0, 0, 0),
                abc(Opcode::GetCap, 1, 1, 0),
                abc(Opcode::SubI, 0, 0, 1),
                abc(Opcode::Return, 0, 0, 0),
            ],
            Vec::new(),
            2,
            0,
        );
        f2.captures = vec![CaptureSource::Capture(0), CaptureSource::Reg(0)];
        let p = program(vec![main, f1, f2], Vec::new(), Vec::new());
        assert_eq!(finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(), Some(5));
    }

    /// 原型 1: `f(n) = if n == 0 then 0 else f(n - 1) + 1`（末尾でない再帰。CALL は位置 8）。
    /// 原型 0（main）: `f(n)`。
    fn count_down_non_tail(n: i64) -> CompiledProgram {
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abx(Opcode::LoadK, 1, 1),
                abc(Opcode::Call, 0, 0, 1),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![ConstDesc::Proto(ProtoIdx(1)), ConstDesc::Int(n)],
            2,
            0,
        );
        let f = proto(
            vec![
                abx(Opcode::LoadK, 1, 0),
                abc(Opcode::EqI, 1, 0, 1),
                asbx(Opcode::JmpF, 1, 2),
                abx(Opcode::LoadK, 1, 0),
                abc(Opcode::Return, 1, 0, 0),
                abx(Opcode::LoadK, 2, 1),
                abx(Opcode::LoadK, 1, 2),
                abc(Opcode::SubI, 3, 0, 1),
                abc(Opcode::Call, 2, 2, 1),
                abc(Opcode::AddI, 2, 2, 1),
                abc(Opcode::Return, 2, 0, 0),
            ],
            vec![
                ConstDesc::Int(0),
                ConstDesc::Proto(ProtoIdx(1)),
                ConstDesc::Int(1),
            ],
            4,
            1,
        );
        program(vec![main, f], Vec::new(), Vec::new())
    }

    #[test]
    fn deep_non_tail_recursion_runs_without_the_rust_stack() {
        // 言語の呼び出しで Rust の関数を入れ子に呼ばない（ADR 0016）。既定の上限の中なら深い再帰も終わる。
        let p = count_down_non_tail(100_000);
        assert_eq!(
            finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(),
            Some(100_000)
        );
    }

    #[test]
    fn non_tail_recursion_stops_at_the_call_stack_limit() {
        let max = 10_240;
        let p = count_down_non_tail(1_000_000);
        let info = stopped(run(&p, max));
        // 上限の計算（02-08）: 枠一つ 96、レジスタ一つ 32。main は 2 個、f は 4 個のレジスタを使う。
        // 上限と等しい大きさまでは呼べる（この値では f の枠 45 個でちょうど 10240 になる）。
        let main_cost = 96 + 32 * 2;
        let f_cost = 96 + 32 * 4;
        let expected_frames = 1 + (max - main_cost) / f_cost;
        assert_eq!(
            info.stop,
            Stop::Resource(ResourceError::CallStackTooDeep {
                frames: expected_frames
            })
        );
        assert_eq!(info.frames.len() as u64, expected_frames);
        assert_eq!(info.at, Some(at(1, 8)));
        // 内側の枠は f の CALL から、最も外側は main（呼び出した命令なし）。
        assert_eq!(info.frames.first().unwrap().call_site, Some(at(1, 8)));
        assert_eq!(info.frames.last().unwrap().call_site, None);
        assert_eq!(info.frames[info.frames.len() - 2].call_site, Some(at(0, 2)));
    }

    #[test]
    fn main_frame_over_the_limit_stops_before_running() {
        let p = count_down_non_tail(0);
        let info = stopped(run(&p, 96 + 32 * 2 - 1));
        assert_eq!(
            info.stop,
            Stop::Resource(ResourceError::CallStackTooDeep { frames: 0 })
        );
        assert_eq!(info.at, None);
        assert!(info.frames.is_empty());
    }

    #[test]
    fn a_million_tail_calls_fit_in_a_small_limit() {
        // f(n, acc) = if n == 0 then acc else f(n - 1, acc + 1)。末尾呼び出しは枠を増やさない（ADR 0013）。
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abx(Opcode::LoadK, 1, 1),
                abx(Opcode::LoadK, 2, 2),
                abc(Opcode::Call, 0, 0, 2),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![
                ConstDesc::Proto(ProtoIdx(1)),
                ConstDesc::Int(1_000_000),
                ConstDesc::Int(0),
            ],
            3,
            0,
        );
        let f = proto(
            vec![
                abx(Opcode::LoadK, 2, 0),
                abc(Opcode::EqI, 2, 0, 2),
                asbx(Opcode::JmpF, 2, 1),
                abc(Opcode::Return, 1, 0, 0),
                abx(Opcode::LoadK, 3, 1),
                abx(Opcode::LoadK, 2, 2),
                abc(Opcode::SubI, 4, 0, 2),
                abc(Opcode::AddI, 5, 1, 2),
                abc(Opcode::TailCall, 0, 3, 2),
            ],
            vec![
                ConstDesc::Int(0),
                ConstDesc::Proto(ProtoIdx(1)),
                ConstDesc::Int(1),
            ],
            6,
            2,
        );
        let p = program(vec![main, f], Vec::new(), Vec::new());
        assert_eq!(finished(run(&p, 1024)).as_int(), Some(1_000_000));
    }

    /// `is_even`（原型 1、レジスタ 3 個）と `is_odd`（原型 2、レジスタ 10 個）が互いに末尾呼び出しする。
    /// 関数の値を窓の先頭 R0 に、引数を R1 に置くので、引数のレジスタと新しい窓の先頭が重なる。
    fn even_odd(n: i64) -> CompiledProgram {
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abx(Opcode::LoadK, 1, 1),
                abc(Opcode::Call, 0, 0, 1),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![ConstDesc::Proto(ProtoIdx(1)), ConstDesc::Int(n)],
            2,
            0,
        );
        let side = |on_zero: bool, other: u32, num_regs: u16| {
            proto(
                vec![
                    abx(Opcode::LoadK, 1, 0),
                    abc(Opcode::EqI, 1, 0, 1),
                    asbx(Opcode::JmpF, 1, 2),
                    abx(Opcode::LoadK, 1, 1),
                    abc(Opcode::Return, 1, 0, 0),
                    abx(Opcode::LoadK, 1, 2),
                    abc(Opcode::SubI, 1, 0, 1),
                    abx(Opcode::LoadK, 0, 3),
                    abc(Opcode::TailCall, 0, 0, 1),
                ],
                vec![
                    ConstDesc::Int(0),
                    ConstDesc::Bool(on_zero),
                    ConstDesc::Int(1),
                    ConstDesc::Proto(ProtoIdx(other)),
                ],
                num_regs,
                1,
            )
        };
        program(
            vec![main, side(true, 2, 3), side(false, 1, 10)],
            Vec::new(),
            Vec::new(),
        )
    }

    #[test]
    fn tail_calls_between_different_window_sizes() {
        for (n, expected) in [(10_000, true), (10_001, false)] {
            let p = even_odd(n);
            assert_eq!(finished(run(&p, 1024)).as_bool(), Some(expected), "n = {n}");
        }
    }

    #[test]
    fn tail_call_moves_overlapping_arguments_in_order() {
        // f: R0 = g、R1 = 10、R2 = 3 として TAILCALL B=0 C=2。引数 R1・R2 は g の R0・R1 と重なる。
        // g: R0 - R1。引数が順に渡れば 7 になる。窓が小さくなる場合と大きくなる場合の両方で確かめる。
        for (f_regs, g_regs) in [(6, 3), (3, 8)] {
            let main = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    abc(Opcode::Call, 0, 0, 0),
                    abc(Opcode::Return, 0, 0, 0),
                ],
                vec![ConstDesc::Proto(ProtoIdx(1))],
                1,
                0,
            );
            let f = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    abx(Opcode::LoadK, 1, 1),
                    abx(Opcode::LoadK, 2, 2),
                    abc(Opcode::TailCall, 0, 0, 2),
                ],
                vec![
                    ConstDesc::Proto(ProtoIdx(2)),
                    ConstDesc::Int(10),
                    ConstDesc::Int(3),
                ],
                f_regs,
                0,
            );
            let g = proto(
                vec![abc(Opcode::SubI, 2, 0, 1), abc(Opcode::Return, 2, 0, 0)],
                Vec::new(),
                g_regs,
                2,
            );
            let p = program(vec![main, f, g], Vec::new(), Vec::new());
            assert_eq!(
                finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(),
                Some(7),
                "f_regs = {f_regs}, g_regs = {g_regs}"
            );
        }
    }

    #[test]
    fn growing_tail_call_checks_the_limit_first() {
        // main（96 + 32×2）と is_even（96 + 32×3）で 352。is_odd の窓へ広げると 7 個分（224）増えて 576。
        let p = even_odd(1);
        assert_eq!(finished(run(&p, 576)).as_bool(), Some(false));
        let info = stopped(run(&p, 575));
        assert_eq!(
            info.stop,
            Stop::Resource(ResourceError::CallStackTooDeep { frames: 2 })
        );
        assert_eq!(info.at, Some(at(1, 8)));
        assert_eq!(info.frames.len(), 2);
    }

    #[test]
    fn switch_selects_the_branch_by_tag() {
        // SWITCH の後に、分岐ごとに「LOADK R1 K; RETURN R1」を並べる（跳ぶ先は 0、2、4）。
        let with_table = |tag: u32, table: SwitchTable| {
            let mut main = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    abx(Opcode::Switch, 0, 0),
                    abx(Opcode::LoadK, 1, 1),
                    abc(Opcode::Return, 1, 0, 0),
                    abx(Opcode::LoadK, 1, 2),
                    abc(Opcode::Return, 1, 0, 0),
                    abx(Opcode::LoadK, 1, 3),
                    abc(Opcode::Return, 1, 0, 0),
                ],
                vec![
                    ConstDesc::NullaryCtor { tag },
                    ConstDesc::Int(100),
                    ConstDesc::Int(101),
                    ConstDesc::Int(102),
                ],
                2,
                0,
            );
            main.switch_tables = vec![table];
            program(vec![main], Vec::new(), Vec::new())
        };
        let full = SwitchTable {
            targets: vec![Some(0), Some(2), Some(4)],
            default: None,
        };
        let with_default = SwitchTable {
            targets: vec![Some(2), None],
            default: Some(4),
        };
        let cases = [
            (0, full.clone(), 100),
            (1, full.clone(), 101),
            (2, full, 102),
            (0, with_default.clone(), 101),
            (1, with_default.clone(), 102),
            (5, with_default, 102),
        ];
        for (tag, table, expected) in cases {
            let p = with_table(tag, table);
            assert_eq!(
                finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(),
                Some(expected),
                "tag {tag}"
            );
        }

        let no_default = SwitchTable {
            targets: vec![Some(0), Some(2)],
            default: None,
        };
        let info = stopped(run(&with_table(2, no_default), DEFAULT_MAX_CALL_STACK));
        assert!(matches!(info.stop, Stop::Internal(_)), "{:?}", info.stop);
        assert_eq!(info.at, Some(at(0, 1)));
    }

    #[test]
    fn jmpf_and_jmp_express_if() {
        // if c then 1 else 2
        for (cond, expected) in [(true, 1), (false, 2)] {
            let main = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    asbx(Opcode::JmpF, 0, 2),
                    abx(Opcode::LoadK, 1, 1),
                    asbx(Opcode::Jmp, 0, 1),
                    abx(Opcode::LoadK, 1, 2),
                    abc(Opcode::Return, 1, 0, 0),
                ],
                vec![ConstDesc::Bool(cond), ConstDesc::Int(1), ConstDesc::Int(2)],
                2,
                0,
            );
            let p = program(vec![main], Vec::new(), Vec::new());
            assert_eq!(
                finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(),
                Some(expected),
                "cond {cond}"
            );
        }
    }

    #[test]
    fn list_con_field_and_structural_equality() {
        // [1, 2] == [1, second] と、Some(3) の引数の取り出し。
        let list_eq = |second: i64| {
            let main = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    abx(Opcode::LoadK, 1, 1),
                    abc(Opcode::List, 2, 0, 2),
                    abx(Opcode::LoadK, 1, 2),
                    abc(Opcode::List, 3, 0, 2),
                    abc(Opcode::EqV, 0, 2, 3),
                    abc(Opcode::Return, 0, 0, 0),
                ],
                vec![ConstDesc::Int(1), ConstDesc::Int(2), ConstDesc::Int(second)],
                4,
                0,
            );
            program(vec![main], Vec::new(), Vec::new())
        };
        for (second, expected) in [(2, true), (3, false)] {
            assert_eq!(
                finished(run(&list_eq(second), DEFAULT_MAX_CALL_STACK)).as_bool(),
                Some(expected)
            );
        }

        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abc(Opcode::Con, 1, 0, 0),
                abc(Opcode::Field, 2, 1, 0),
                abc(Opcode::Return, 2, 0, 0),
            ],
            vec![ConstDesc::Int(3)],
            3,
            0,
        );
        let p = program(vec![main], Vec::new(), vec![ctor(1, 1)]);
        assert_eq!(finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(), Some(3));
    }

    #[test]
    fn builtin_calls_check_the_builtin_kind() {
        // PRIM は IO を行わない組み込みの関数だけを、IO は IO の組み込みの関数だけを呼ぶ。
        let with = |op: Opcode, id: BuiltinId| {
            let main = proto(
                vec![
                    abx(Opcode::LoadK, 0, 0),
                    abc(op, 1, 0, 0),
                    abc(Opcode::Return, 1, 0, 0),
                ],
                vec![ConstDesc::Str(String::from("héllo"))],
                2,
                0,
            );
            program(vec![main], vec![id], Vec::new())
        };
        let p = with(Opcode::Prim, BuiltinId::StringByteLength);
        assert_eq!(finished(run(&p, DEFAULT_MAX_CALL_STACK)).as_int(), Some(6));

        for (op, id) in [
            (Opcode::Prim, BuiltinId::ConsolePrintln),
            (Opcode::Io, BuiltinId::StringByteLength),
        ] {
            let p = with(op, id);
            let info = stopped(run(&p, DEFAULT_MAX_CALL_STACK));
            assert!(
                matches!(info.stop, Stop::Internal(_)),
                "{op:?} {:?}",
                info.stop
            );
            assert_eq!(info.at, Some(at(0, 1)));
        }
    }

    /// `Console.println("a"); Console.println("b")` に当たるプログラム。IO の命令は位置 1 と 3。
    fn println_twice() -> CompiledProgram {
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abc(Opcode::Io, 1, 0, 0),
                abx(Opcode::LoadK, 0, 1),
                abc(Opcode::Io, 1, 0, 0),
                abc(Opcode::Return, 1, 0, 0),
            ],
            vec![
                ConstDesc::Str(String::from("a")),
                ConstDesc::Str(String::from("b")),
            ],
            2,
            0,
        );
        program(vec![main], vec![BuiltinId::ConsolePrintln], Vec::new())
    }

    #[test]
    fn both_io_modes_produce_the_same_events() {
        // 二つの方式は同じ観測できる振る舞いを示す（ADR 0029）。
        let p = println_twice();
        let expected = vec![
            IoEvent::Write {
                stream: Stream::Stdout,
                text: String::from("a\n"),
            },
            IoEvent::Write {
                stream: Stream::Stdout,
                text: String::from("b\n"),
            },
        ];
        for mode in [Mode::Direct, Mode::Request] {
            let mut io = TestIo::new(Vec::new(), BTreeMap::new());
            let v = finished(execute(&p, DEFAULT_MAX_CALL_STACK, mode, &mut io));
            assert!(matches!(v, Value::Unit));
            assert_eq!(io.events, expected);
        }
    }

    /// 書き込みがいつも失敗するハンドラ表。
    struct FailingIo;

    impl IoHandlers for FailingIo {
        fn call(&mut self, _op: IoOp, _args: &[Value], _heap: &mut Heap) -> Result<Value, Stop> {
            Err(Stop::Runtime(RuntimeError::WriteFailed {
                stream: Stream::Stdout,
                reason: String::from("broken pipe"),
            }))
        }
    }

    /// IO の命令が実行された時点での、解放の回数を控えるハンドラ表。
    #[cfg(feature = "alloc-stats")]
    struct FreedAtIo {
        start: u64,
        seen: Vec<u64>,
    }

    #[cfg(feature = "alloc-stats")]
    impl IoHandlers for FreedAtIo {
        fn call(&mut self, _op: IoOp, _args: &[Value], _heap: &mut Heap) -> Result<Value, Stop> {
            let freed = crate::runtime::heap::freed_count().saturating_sub(self.start);
            self.seen.push(freed);
            Ok(Value::Unit)
        }
    }

    #[cfg(feature = "alloc-stats")]
    #[test]
    fn discarded_windows_release_their_values_before_the_next_instruction() {
        // RETURN と TAILCALL が捨てた窓に置いた構成子の値は、次の命令の前に解放される（ADR 0078）。
        // レジスタの積み重ねを縮めずに使い回しても、捨てた窓の外に参照を残さないことを確かめる。
        // 構成子の値は f の窓の中で、続く窓（main の窓・g の窓）より後ろのレジスタに置く。
        let println_x = |result: u16| {
            vec![
                abx(Opcode::LoadK, 0, 0),
                abc(Opcode::Io, result, 0, 0),
                abc(Opcode::Return, result, 0, 0),
            ]
        };
        // RETURN: main が f を呼び、戻った後に IO を実行する。
        let main_calls_then_io = {
            let mut code = vec![abx(Opcode::LoadK, 0, 1), abc(Opcode::Call, 1, 0, 0)];
            code.extend(println_x(1));
            proto(
                code,
                vec![
                    ConstDesc::Str(String::from("x")),
                    ConstDesc::Proto(ProtoIdx(1)),
                ],
                2,
                0,
            )
        };
        let f_returns = proto(
            vec![
                abx(Opcode::LoadK, 1, 0),
                abc(Opcode::Con, 3, 0, 1),
                abx(Opcode::LoadK, 0, 1),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![ConstDesc::Int(7), ConstDesc::Unit],
            4,
            0,
        );
        // TAILCALL: f が窓の小さい g を末尾呼び出しし、g が IO を実行する。
        let main_calls = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abc(Opcode::Call, 0, 0, 0),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![ConstDesc::Proto(ProtoIdx(1))],
            1,
            0,
        );
        let f_tail_calls = proto(
            vec![
                abx(Opcode::LoadK, 1, 0),
                abc(Opcode::Con, 3, 0, 1),
                abx(Opcode::LoadK, 0, 1),
                abc(Opcode::TailCall, 0, 0, 0),
            ],
            vec![ConstDesc::Int(7), ConstDesc::Proto(ProtoIdx(2))],
            4,
            0,
        );
        let g = proto(println_x(1), vec![ConstDesc::Str(String::from("x"))], 2, 0);
        let cases = [
            ("RETURN", vec![main_calls_then_io, f_returns]),
            ("TAILCALL", vec![main_calls, f_tail_calls, g]),
        ];
        for (name, protos) in cases {
            let p = program(protos, vec![BuiltinId::ConsolePrintln], vec![ctor(0, 1)]);
            for mode in [Mode::Direct, Mode::Request] {
                let mut io = FreedAtIo {
                    start: crate::runtime::heap::freed_count(),
                    seen: Vec::new(),
                };
                finished(execute(&p, DEFAULT_MAX_CALL_STACK, mode, &mut io));
                assert_eq!(io.seen, vec![1], "{name}");
            }
        }
    }

    #[test]
    fn io_failure_stops_at_the_io_instruction_in_both_modes() {
        let p = println_twice();
        for mode in [Mode::Direct, Mode::Request] {
            let info = stopped(execute(&p, DEFAULT_MAX_CALL_STACK, mode, &mut FailingIo));
            assert_eq!(
                info.stop,
                Stop::Runtime(RuntimeError::WriteFailed {
                    stream: Stream::Stdout,
                    reason: String::from("broken pipe"),
                })
            );
            assert_eq!(info.at, Some(at(0, 1)));
            assert_eq!(info.frames.len(), 1);
        }
    }

    #[test]
    fn io_result_register_out_of_window_stops_without_io_in_both_modes() {
        // main（窓 2）が窓 8 の f を呼んで戻った後、窓の外の R5 を結果とする IO を実行する。
        // レジスタの並びは f の窓の分だけ長いまま残るが、窓の外なので処理系の不具合として
        // IO の命令の位置で止まり、どちらの方式でも IO を行わない（要求も出さない）。
        let main = proto(
            vec![
                abx(Opcode::LoadK, 0, 0),
                abc(Opcode::Call, 0, 0, 0),
                abx(Opcode::LoadK, 0, 1),
                abc(Opcode::Io, 5, 0, 0),
                abc(Opcode::Return, 0, 0, 0),
            ],
            vec![
                ConstDesc::Proto(ProtoIdx(1)),
                ConstDesc::Str(String::from("x")),
            ],
            2,
            0,
        );
        let f = proto(
            vec![abx(Opcode::LoadK, 0, 0), abc(Opcode::Return, 0, 0, 0)],
            vec![ConstDesc::Unit],
            8,
            0,
        );
        let p = program(vec![main, f], vec![BuiltinId::ConsolePrintln], Vec::new());
        for mode in [Mode::Direct, Mode::Request] {
            let mut io = TestIo::new(Vec::new(), BTreeMap::new());
            let info = stopped(execute(&p, DEFAULT_MAX_CALL_STACK, mode, &mut io));
            assert!(matches!(info.stop, Stop::Internal(_)), "{:?}", info.stop);
            assert_eq!(info.at, Some(at(0, 3)));
            assert!(io.events.is_empty(), "{:?}", io.events);
        }
    }

    #[test]
    fn io_response_value_reaches_the_result_register_in_both_modes() {
        // R0 = Process.args(); R1 = List.length(R0)。応答の値を後の命令で使い、
        // 要求と応答の方式で `resume` が応答を結果のレジスタに入れることを確かめる（ADR 0029）。
        let main = proto(
            vec![
                abc(Opcode::Io, 0, 0, 0),
                abc(Opcode::Prim, 1, 1, 0),
                abc(Opcode::Return, 1, 0, 0),
            ],
            Vec::new(),
            2,
            0,
        );
        let p = program(
            vec![main],
            vec![BuiltinId::ProcessArgs, BuiltinId::ListLength],
            Vec::new(),
        );
        for mode in [Mode::Direct, Mode::Request] {
            let mut io = TestIo::new(vec![String::from("x"), String::from("y")], BTreeMap::new());
            let v = finished(execute(&p, DEFAULT_MAX_CALL_STACK, mode, &mut io));
            assert_eq!(v.as_int(), Some(2));
        }
    }

    #[test]
    fn unknown_opcode_is_an_internal_error() {
        let main = proto(vec![Instr(0xff)], Vec::new(), 1, 0);
        let p = program(vec![main], Vec::new(), Vec::new());
        let info = stopped(run(&p, DEFAULT_MAX_CALL_STACK));
        assert!(matches!(info.stop, Stop::Internal(_)), "{:?}", info.stop);
        assert_eq!(info.at, Some(at(0, 0)));
    }
}
