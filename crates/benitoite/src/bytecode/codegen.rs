//! コード生成: 下位 IR から、レジスタ型のバイトコードからなるコンパイル済みプログラムを作る
//! （設計書 02-07「コード生成」）。
//!
//! 計算は「結果の行き先」を引数にとって再帰的に命令へ移す。行き先は、結果を入れるレジスタか、
//! 末尾位置（結果をそのまま呼び出し元へ返す）のどちらかである。末尾位置の関数の適用は
//! `TAILCALL` に、末尾位置の組み込みの関数と演算子は命令の後に `RETURN` を置く形にし、
//! 末尾呼び出しの保証（ADR 0013）を満たす（02-07「末尾呼び出し」）。
//!
//! 再帰は下位 IR の木の深さに比例する。下位 IR は AST から作るので、その深さは構文解析器の
//! 入れ子の上限（02-03「入れ子の深さ」、ADR 0086）の定数倍に収まる。最適化しないビルドの
//! テストのスレッドでも 1000 段の入れ子を移せるように、次のようにして一段のスタックを小さく保つ
//! （実装プラン 00-02「再帰の深さ」）。
//! - 再帰の経路にある関数（`comp` と `if`・`let`・`case`・`join` の関数）は、再帰の前後の処理を
//!   補助の関数に分ける。誤りの型は箱に入れて一語にする（`CgResult`）。
//! - ラムダの本体は、出会った時点では原型の場所を取って捕捉の表を決めるだけにし、作る側の原型を
//!   移し終えてから移す（`drain_lambdas`）。ラムダの入れ子で再帰が深くならない。
//! - ラムダの自由な変数は、明示の積み重ねで辿って集める（`free_vars`）。

use std::collections::{HashMap, VecDeque};
use std::sync::Arc;

use super::instr::{Instr, Opcode};
use super::program::{
    CaptureSource, CompiledProgram, ConstDesc, CtorInfo, MainKind, Proto, ProtoIdx, ProtoOrigin,
    SwitchTable,
};
use crate::base::{BindingId, SourceTable, Span};
use crate::builtins::table::spec;
use crate::builtins::{BuiltinId, BuiltinKind};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::ir::InternalError;
use crate::ir::core_ir::{Const, DefOrigin, Lambda, ValKind, Var, VarId};
use crate::ir::lower_ir::{CtorArm, JoinId, LComp, LCompKind, LowVal, LowerDef, LowerProgram};
use crate::types::{Ty, TyCon};

/// コード生成の失敗。
#[derive(Debug)]
pub enum CodegenError {
    /// 処理系の制限（L0101・L0102）。制限に当たった関数ごとに一つ
    Limit(Vec<Diagnostic>),
    Internal(InternalError),
}

/// 下位 IR からコンパイル済みプログラムを作る（02-07「コード生成」）。
pub fn codegen(
    program: &LowerProgram,
    sources: Arc<SourceTable>,
) -> Result<CompiledProgram, CodegenError> {
    let mut g = Gen::new(program);

    // 定義の原型の番号は、定義の並びの順に原型の表の先頭から振る。本体の中で後の定義を
    // 参照しても番号が引けるように、本体を移す前にすべて振っておく（T21 の 1）。
    let mut top_fns = Vec::with_capacity(program.defs.len());
    for def in &program.defs {
        let idx = g.reserve_proto().map_err(|e| CodegenError::Internal(*e))?;
        g.def_protos.insert(def.binding, idx);
        top_fns.push((def.binding, idx));
    }
    for (def, (_, idx)) in program.defs.iter().zip(top_fns.iter()) {
        let proto = g.def_proto(def).map_err(|e| CodegenError::Internal(*e))?;
        g.set_proto(*idx, proto)
            .map_err(|e| CodegenError::Internal(*e))?;
        g.drain_lambdas().map_err(|e| CodegenError::Internal(*e))?;
    }

    let Some(main) = g.def_protos.get(&program.main).copied() else {
        return Err(CodegenError::Internal(*internal(
            "the main function has no prototype",
        )));
    };
    if !g.diags.is_empty() {
        return Err(CodegenError::Limit(g.diags));
    }
    let mut protos = Vec::with_capacity(g.protos.len());
    for p in g.protos {
        let Some(p) = p else {
            return Err(CodegenError::Internal(*internal(
                "a prototype slot was never filled",
            )));
        };
        protos.push(p);
    }
    Ok(CompiledProgram {
        protos,
        top_fns,
        ctors: g.ctors,
        builtins: g.builtins,
        main,
        main_kind: if program.main_returns_result {
            MainKind::Result
        } else {
            MainKind::Unit
        },
        sources,
    })
}

/// `InternalError` の段の名前。
const STAGE: &str = "codegen";

/// 生成の途中の失敗。再帰の経路の各段が `Result` の一時の値を持つので、最適化しないビルドでも
/// 一段のスタックを小さく保てるように、誤りを箱に入れて一語の大きさにする（00-02「再帰の深さ」）。
type CgResult<T> = Result<T, Box<InternalError>>;

fn internal(message: impl Into<String>) -> Box<InternalError> {
    Box::new(InternalError {
        stage: STAGE,
        message: message.into(),
    })
}

/// 一つの原型のレジスタの数の上限（02-07「処理系の制限」）。
const MAX_REGS: u32 = 65535;
/// 一つの原型の定数表の大きさの上限。番号 0〜65535 が 16 ビットに収まる。
const MAX_CONSTS: usize = 65536;

/// レジスタの番号や個数を命令のオペランドにする。
///
/// 16 ビットに収まらないのは、原型のレジスタの数が上限を超えたときだけである。そのときは
/// 原型ごとに L0101 を報告してプログラムを実行しないので、ここでは値を丸めて生成を続け、
/// ほかの制限（L0102）とほかの原型の制限も一度に報告できるようにする（T21「処理系の制限」）。
fn r16(n: u32) -> u16 {
    u16::try_from(n).unwrap_or(u16::MAX)
}

/// 並びの長さを u32 にする。長さは入力の大きさで抑えられ、u32 を超えることはないが、
/// 超えたときも丸めて上限の検査（L0101・L0102）に任せる。
fn count_u32(n: usize) -> u32 {
    u32::try_from(n).unwrap_or(u32::MAX)
}

/// 変数の置き場所（02-07「値の移し方」の「変数」）。
#[derive(Clone, Copy, Debug)]
enum Loc {
    /// 実行中の関数のレジスタ
    Reg(u32),
    /// 実行中の関数の値が捕捉した値の番号（`GETCAP` で取り出す）
    Cap(u32),
}

/// 計算の結果の行き先（02-07「コード生成」の「結果を入れるレジスタ」と「末尾位置か」）。
#[derive(Clone, Copy, Debug)]
enum Target {
    /// 結果をこのレジスタに入れて、続きの命令へ進む
    Reg(u32),
    /// 末尾位置。結果を呼び出し元へ返す
    Tail,
}

/// 定数表の使い回しの鍵。`Float` はビットで比べ、`NaN` どうしや `0.0` と `-0.0` を
/// 取り違えないようにする（T21「原型の番号と表」の 5）。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
enum ConstKey {
    Int(i64),
    Float(u64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    NullaryCtor(u32),
    Proto(u32),
}

impl ConstKey {
    fn of(desc: &ConstDesc) -> ConstKey {
        match desc {
            ConstDesc::Int(n) => ConstKey::Int(*n),
            ConstDesc::Float(x) => ConstKey::Float(x.to_bits()),
            ConstDesc::Str(s) => ConstKey::Str(s.clone()),
            ConstDesc::Char(c) => ConstKey::Char(*c),
            ConstDesc::Bool(b) => ConstKey::Bool(*b),
            ConstDesc::Unit => ConstKey::Unit,
            ConstDesc::NullaryCtor { tag } => ConstKey::NullaryCtor(*tag),
            ConstDesc::Proto(p) => ConstKey::Proto(p.0),
        }
    }
}

fn const_desc(c: &Const) -> ConstDesc {
    match c {
        Const::Int(n) => ConstDesc::Int(*n),
        Const::Float(x) => ConstDesc::Float(*x),
        Const::Str(s) => ConstDesc::Str(s.clone()),
        Const::Char(ch) => ConstDesc::Char(*ch),
        Const::Bool(b) => ConstDesc::Bool(*b),
        Const::Unit => ConstDesc::Unit,
    }
}

/// `join` の印の状態。
#[derive(Debug)]
struct JoinState {
    /// `join` の引数のレジスタ
    params: Vec<u32>,
    /// `jump` が跳ぶ先 `Lk` の命令の位置（まだ命令を出していなければ `None`）
    target: Option<usize>,
    /// `Lk` の位置が決まったら書き換える `JMP` の位置
    pending: Vec<usize>,
}

/// `case` の終わりの処理に要る状態。
#[derive(Debug)]
struct CaseEnd {
    /// `case` の前の次に空いているレジスタ（対象の値の一時的なレジスタを解放する）
    mark: u32,
    /// `case` の終わりへ跳ぶ `JMP` の位置
    to_end: Vec<usize>,
}

/// 構成子の `case` を移す途中の状態。
#[derive(Debug)]
struct SwitchState {
    /// 対象の値のレジスタ
    scrutinee: u32,
    /// 分岐表の番号
    table: usize,
    /// `SWITCH` の位置
    switch: usize,
    /// 後に `JMP` を置かない分岐（`_` の分岐がなければ最後の分岐）
    last_arm: Option<usize>,
    /// 分岐の変数に割り当てる最初のレジスタ
    arm_base: u32,
    end: CaseEnd,
}

/// プログラム全体で共有する生成の状態。
struct Gen<'p> {
    program: &'p LowerProgram,
    /// 原型の表。場所を先に取り、本体を移し終えたら入れる
    protos: Vec<Option<Proto>>,
    def_protos: HashMap<BindingId, ProtoIdx>,
    /// 値として使う組み込みの関数の原型。組み込みの関数ごとに一つ（02-07「値の移し方」）
    builtin_protos: HashMap<BuiltinId, ProtoIdx>,
    builtins: Vec<BuiltinId>,
    builtin_index: HashMap<BuiltinId, u16>,
    ctors: Vec<CtorInfo>,
    ctor_index: HashMap<(TyCon, u32), u16>,
    /// 処理系の制限の診断
    diags: Vec<Diagnostic>,
    /// 原型の場所を取り、本体をまだ移していないラムダ（出会った順）
    pending: VecDeque<PendingLambda<'p>>,
}

/// 本体をまだ移していないラムダ。
struct PendingLambda<'p> {
    idx: ProtoIdx,
    lambda: &'p Lambda<LComp>,
    /// 引数と捕捉した変数の置き場所を入れた、本体を移すための状態
    inner: Box<FnGen<'p>>,
}

/// 生成中の一つの原型の状態。
struct FnGen<'p> {
    /// 原型を含む定義（制限の診断の名前と位置に使う）
    def: &'p LowerDef,
    /// 利用者の定義の中か（ラムダの由来の種類を決める）
    user: bool,
    code: Vec<Instr>,
    positions: Vec<Option<Span>>,
    consts: Vec<ConstDesc>,
    const_index: HashMap<ConstKey, u32>,
    switch_tables: Vec<SwitchTable>,
    /// 次に空いているレジスタ。下位 IR は木の形なので、割り当てと解放は積み重ねの順になる
    /// （02-07「レジスタの割り当て」）
    next_reg: u32,
    /// 同時に使ったレジスタの最大数
    max_regs: u32,
    env: HashMap<VarId, Loc>,
    joins: HashMap<JoinId, JoinState>,
    /// ラムダの原型の捕捉の表（定義の原型は空）
    captures: Vec<CaptureSource>,
}

impl<'p> FnGen<'p> {
    fn new(def: &'p LowerDef, user: bool) -> FnGen<'p> {
        FnGen {
            def,
            user,
            code: Vec::new(),
            positions: Vec::new(),
            consts: Vec::new(),
            const_index: HashMap::new(),
            switch_tables: Vec::new(),
            next_reg: 0,
            max_regs: 0,
            env: HashMap::new(),
            joins: HashMap::new(),
            captures: Vec::new(),
        }
    }

    fn alloc(&mut self) -> u32 {
        self.alloc_block(1)
    }

    /// 連続した n 個のレジスタを取り、先頭の番号を返す。
    fn alloc_block(&mut self, n: u32) -> u32 {
        let base = self.next_reg;
        self.next_reg = self.next_reg.saturating_add(n);
        self.max_regs = self.max_regs.max(self.next_reg);
        base
    }

    /// `mark` より後に取ったレジスタをすべて解放する。
    fn release(&mut self, mark: u32) {
        self.next_reg = mark;
    }

    fn emit(&mut self, instr: Instr, origin: Option<Span>) -> usize {
        let pos = self.code.len();
        self.code.push(instr);
        self.positions.push(origin);
        pos
    }

    fn here(&self) -> usize {
        self.code.len()
    }

    /// 跳ぶ先をまだ決めない `JMP`・`JMPF` を出す。後で `patch` で書き換える。
    fn emit_jump(&mut self, op: Opcode, a: u32, origin: Span) -> usize {
        self.emit(Instr::asbx(op, r16(a), 0), Some(origin))
    }

    /// `pos` の跳ぶ命令の跳ぶ先を `target` にする（`Instr::asbx` で作り直す）。
    fn patch(&mut self, pos: usize, target: usize) -> CgResult<()> {
        let offset = relative(pos, target)?;
        let Some(slot) = self.code.get_mut(pos) else {
            return Err(internal("patching a jump outside the code"));
        };
        let Some(op) = slot.opcode() else {
            return Err(internal("patching an unknown instruction"));
        };
        *slot = Instr::asbx(op, slot.a(), offset);
        Ok(())
    }

    /// 末尾位置でなければ、分岐の終わりへの `JMP` を出してその位置を返す（02-07「分岐と合流の並べ方」）。
    fn jump_to_end(&mut self, target: Target, origin: Span) -> Option<usize> {
        match target {
            Target::Reg(_) => Some(self.emit_jump(Opcode::Jmp, 0, origin)),
            Target::Tail => None,
        }
    }

    /// `pos` の跳ぶ命令の跳ぶ先を、次に出す命令の位置にする。
    fn patch_here(&mut self, pos: usize) -> CgResult<()> {
        let here = self.here();
        self.patch(pos, here)
    }

    /// `jump_to_end` の出した `JMP` があれば、その跳ぶ先を次に出す命令の位置にする。
    fn patch_end(&mut self, pos: Option<usize>) -> CgResult<()> {
        match pos {
            Some(pos) => self.patch_here(pos),
            None => Ok(()),
        }
    }

    /// 構成子の `case` の分岐の先頭: 分岐表に跳ぶ先を記録し、`FIELD` で引数を分岐の変数の
    /// レジスタに取り出す。
    fn ctor_arm_head(&mut self, st: &SwitchState, arm: &CtorArm, origin: Span) -> CgResult<()> {
        let offset = relative(st.switch, self.here())?;
        let slot = usize::try_from(arm.tag)
            .ok()
            .and_then(|t| self.switch_tables.get_mut(st.table)?.targets.get_mut(t))
            .ok_or_else(|| internal("constructor tag out of range"))?;
        *slot = Some(offset);
        for (k, field) in arm.fields.iter().enumerate() {
            let r = self.alloc();
            // 引数が 65536 個以上なら、分岐の変数のレジスタだけで上限を超え L0101 になる
            let k = r16(count_u32(k));
            self.emit(
                Instr::abc(Opcode::Field, r16(r), r16(st.scrutinee), k),
                Some(origin),
            );
            self.env.insert(field.id, Loc::Reg(r));
        }
        Ok(())
    }

    /// 構成子の `case` の分岐の終わり: 分岐の変数を解放し、末尾位置でなければ `case` の
    /// 終わりへの `JMP` を置く。
    fn ctor_arm_tail(
        &mut self,
        st: &mut SwitchState,
        arm: &CtorArm,
        index: usize,
        target: Target,
        origin: Span,
    ) {
        for field in &arm.fields {
            self.env.remove(&field.id);
        }
        self.release(st.arm_base);
        if st.last_arm != Some(index)
            && let Some(pos) = self.jump_to_end(target, origin)
        {
            st.end.to_end.push(pos);
        }
    }

    /// `_` の分岐の跳ぶ先を分岐表に記録する。
    fn switch_default(&mut self, st: &SwitchState) -> CgResult<()> {
        let offset = relative(st.switch, self.here())?;
        if let Some(t) = self.switch_tables.get_mut(st.table) {
            t.default = Some(offset);
        }
        Ok(())
    }

    /// `case` の終わり: 終わりへの `JMP` の跳ぶ先を書き換え、対象の値のレジスタを解放する。
    fn case_end(&mut self, end: CaseEnd) -> CgResult<()> {
        for pos in end.to_end {
            self.patch_here(pos)?;
        }
        self.release(end.mark);
        Ok(())
    }

    /// 定数の `case` の分岐の先頭。`compare` で、定数が比べられる型なら、定数を一時的な
    /// レジスタに `LOADK` して `==` の命令で比べ、`JMPF` を出してその位置を返す。比べないときは `None`。
    fn const_arm_head(
        &mut self,
        scrutinee: u32,
        value: &Const,
        compare: bool,
        origin: Span,
    ) -> Option<usize> {
        let op = const_eq_op(value).filter(|_| compare)?;
        let mark = self.next_reg;
        let t = self.alloc();
        self.load_const(t, const_desc(value), origin);
        self.emit(Instr::abc(op, r16(t), r16(scrutinee), r16(t)), Some(origin));
        let jmpf = self.emit_jump(Opcode::JmpF, t, origin);
        self.release(mark);
        Some(jmpf)
    }

    /// 比べた定数の分岐の終わり。比べた分岐の後には必ず次の比較か `_` の分岐が続くので、
    /// 末尾位置でなければ `case` の終わりへの `JMP` を置き、`JMPF` を次の比較へ跳ばせる。
    fn const_arm_tail(
        &mut self,
        end: &mut CaseEnd,
        jmpf: usize,
        target: Target,
        origin: Span,
    ) -> CgResult<()> {
        if let Some(pos) = self.jump_to_end(target, origin) {
            end.to_end.push(pos);
        }
        self.patch_here(jmpf)
    }

    /// `join` の引数にレジスタを割り当て、印を登録する。割り当ての前の次に空いているレジスタを返す。
    fn join_head(&mut self, label: JoinId, param_count: usize) -> u32 {
        let mark = self.next_reg;
        let params: Vec<u32> = (0..param_count).map(|_| self.alloc()).collect();
        self.joins.insert(
            label,
            JoinState {
                params,
                target: None,
                pending: Vec::new(),
            },
        );
        mark
    }

    /// N を移し終えた後: 末尾位置でなければ `JMP →Lend` を置き、`Lk` の位置を決めて `jump` の
    /// 跳ぶ先を書き換え、M のために引数の変数を束縛する。`JMP →Lend` の位置を返す。
    fn join_label(
        &mut self,
        label: JoinId,
        params: &[Var],
        target: Target,
        origin: Span,
    ) -> CgResult<Option<usize>> {
        let to_end = self.jump_to_end(target, origin);
        let lk = self.here();
        let Some(state) = self.joins.get_mut(&label) else {
            return Err(internal("join label disappeared"));
        };
        state.target = Some(lk);
        let pending = std::mem::take(&mut state.pending);
        let regs = state.params.clone();
        for pos in pending {
            self.patch(pos, lk)?;
        }
        for (p, r) in params.iter().zip(regs) {
            self.env.insert(p.id, Loc::Reg(r));
        }
        Ok(to_end)
    }

    /// M を移し終えた後: `JMP →Lend` の跳ぶ先を書き換え、引数の変数とレジスタを解放する。
    fn join_end(
        &mut self,
        label: JoinId,
        params: &[Var],
        to_end: Option<usize>,
        mark: u32,
    ) -> CgResult<()> {
        for p in params {
            self.env.remove(&p.id);
        }
        self.patch_end(to_end)?;
        self.joins.remove(&label);
        self.release(mark);
        Ok(())
    }

    /// 定数表の番号。同じ記述には同じ番号を使う（T21「原型の番号と表」の 5）。
    fn constant(&mut self, desc: ConstDesc) -> u32 {
        let key = ConstKey::of(&desc);
        if let Some(i) = self.const_index.get(&key) {
            return *i;
        }
        let i = count_u32(self.consts.len());
        self.consts.push(desc);
        self.const_index.insert(key, i);
        i
    }

    fn load_const(&mut self, dst: u32, desc: ConstDesc, origin: Span) {
        let k = self.constant(desc);
        self.emit(Instr::abx(Opcode::LoadK, r16(dst), k), Some(origin));
    }

    /// 値がレジスタにある変数なら、そのレジスタ。
    fn reg_of(&self, v: &LowVal) -> Option<u32> {
        match &v.kind {
            ValKind::Var(x) => match self.env.get(x) {
                Some(Loc::Reg(r)) => Some(*r),
                Some(Loc::Cap(_)) | None => None,
            },
            ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::Lambda(_)
            | ValKind::Ctor { .. }
            | ValKind::List(_) => None,
        }
    }

    fn lookup(&self, var: VarId) -> CgResult<Loc> {
        self.env
            .get(&var)
            .copied()
            .ok_or_else(|| internal(format!("variable v{} has no location", var.0)))
    }
}

/// 跳ぶ命令の位置 `from` から `to` への相対位置。跳ぶ命令の次の命令からの距離である（10-07）。
fn relative(from: usize, to: usize) -> CgResult<i32> {
    let too_long = || internal("code too long for a jump offset");
    let from = i64::try_from(from).map_err(|_| too_long())?;
    let to = i64::try_from(to).map_err(|_| too_long())?;
    let next = from.checked_add(1).ok_or_else(too_long)?;
    let diff = to.checked_sub(next).ok_or_else(too_long)?;
    i32::try_from(diff).map_err(|_| too_long())
}

/// 演算子の命令の選び方（02-07「演算子の移し方」）。
enum OpPlan {
    /// `op r x y`。`swap` なら `op r y x`、`negate` なら続けて `NOT r r`
    Binary {
        op: Opcode,
        swap: bool,
        negate: bool,
    },
    /// `op r x`
    Unary(Opcode),
    /// オペランドを見ずに `Bool` の定数を入れる（`Unit` の `==`・`!=`）
    ConstBool(bool),
}

fn binary(op: Opcode) -> OpPlan {
    OpPlan::Binary {
        op,
        swap: false,
        negate: false,
    }
}

/// `>`・`>=` は、オペランドを入れ替えた `<`・`<=` で表す。`!(a < b)` で表すと、`Float` の
/// `NaN` で結果が変わるからである（02-07「演算子の移し方」）。
fn swapped(op: Opcode) -> OpPlan {
    OpPlan::Binary {
        op,
        swap: true,
        negate: false,
    }
}

/// `==`（`negate` なら `!=`）の命令を、型の引数 `ty` で選ぶ。
/// `!=` は `==` の否定と定まっているので、`NaN` でも `NOT` で正しい（02-07）。
fn equality_plan(ty: Option<&Ty>, negate: bool) -> CgResult<OpPlan> {
    let op = match ty {
        Some(Ty::Con(TyCon::Int, _)) => Opcode::EqI,
        Some(Ty::Con(TyCon::Float, _)) => Opcode::EqF,
        Some(Ty::Con(TyCon::String, _)) => Opcode::EqS,
        Some(Ty::Con(TyCon::Char, _)) => Opcode::EqC,
        Some(Ty::Con(TyCon::Bool, _)) => Opcode::EqB,
        Some(Ty::Con(TyCon::Unit, _)) => return Ok(OpPlan::ConstBool(!negate)),
        Some(Ty::Con(TyCon::List | TyCon::Option | TyCon::Result | TyCon::Adt(_), _)) => {
            Opcode::EqV
        }
        // 関数の型と IoError は等値の型でなく（ADR 0048）、型パラメータの `==` は利用者の
        // プログラムにも prelude のソースにも現れない。型検査を通ったプログラムでは起きない。
        Some(Ty::Con(TyCon::IoError, _) | Ty::Fn(_) | Ty::Param(_)) | None => {
            return Err(internal(
                "`==` applied to a type that is not an equality type",
            ));
        }
    };
    Ok(OpPlan::Binary {
        op,
        swap: false,
        negate,
    })
}

fn operator_plan(id: BuiltinId, tys: &[Ty]) -> CgResult<OpPlan> {
    use BuiltinId as B;
    let plan = match id {
        B::AddInt => binary(Opcode::AddI),
        B::SubInt => binary(Opcode::SubI),
        B::MulInt => binary(Opcode::MulI),
        B::DivInt => binary(Opcode::DivI),
        B::RemInt => binary(Opcode::ModI),
        B::NegInt => OpPlan::Unary(Opcode::NegI),
        B::AddFloat => binary(Opcode::AddF),
        B::SubFloat => binary(Opcode::SubF),
        B::MulFloat => binary(Opcode::MulF),
        B::DivFloat => binary(Opcode::DivF),
        B::NegFloat => OpPlan::Unary(Opcode::NegF),
        B::ConcatString => binary(Opcode::Concat),
        B::LtInt => binary(Opcode::LtI),
        B::LeInt => binary(Opcode::LeI),
        B::GtInt => swapped(Opcode::LtI),
        B::GeInt => swapped(Opcode::LeI),
        B::LtFloat => binary(Opcode::LtF),
        B::LeFloat => binary(Opcode::LeF),
        B::GtFloat => swapped(Opcode::LtF),
        B::GeFloat => swapped(Opcode::LeF),
        B::LtString => binary(Opcode::LtS),
        B::LeString => binary(Opcode::LeS),
        B::GtString => swapped(Opcode::LtS),
        B::GeString => swapped(Opcode::LeS),
        B::LtChar => binary(Opcode::LtC),
        B::LeChar => binary(Opcode::LeC),
        B::GtChar => swapped(Opcode::LtC),
        B::GeChar => swapped(Opcode::LeC),
        B::Eq => equality_plan(tys.first(), false)?,
        B::Ne => equality_plan(tys.first(), true)?,
        B::IntToString
        | B::IntParse
        | B::IntToFloat
        | B::IntFloorDiv
        | B::IntMod
        | B::IntAbs
        | B::IntMin
        | B::IntMax
        | B::FloatToString
        | B::FloatParse
        | B::FloatTruncate
        | B::FloatIsNaN
        | B::FloatAbs
        | B::FloatFloor
        | B::FloatCeil
        | B::FloatRound
        | B::FloatSqrt
        | B::CharToInt
        | B::CharFromInt
        | B::CharToString
        | B::CharIsAsciiDigit
        | B::CharIsAsciiWhitespace
        | B::StringByteLength
        | B::StringByteSlice
        | B::StringCharCount
        | B::StringCharAt
        | B::StringCharSlice
        | B::StringIsEmpty
        | B::StringContains
        | B::StringStartsWith
        | B::StringEndsWith
        | B::StringByteIndexOf
        | B::StringSplit
        | B::StringLines
        | B::StringJoin
        | B::StringTrim
        | B::StringReplace
        | B::StringRepeat
        | B::StringChars
        | B::StringFromChars
        | B::ListLength
        | B::ListIsEmpty
        | B::ListHead
        | B::ListTail
        | B::ListGet
        | B::ListPrepend
        | B::ListAppend
        | B::ListConcat
        | B::ListReverse
        | B::ListTake
        | B::ListDrop
        | B::ListRange
        | B::ListContains
        | B::ListSort
        | B::ListDropFirst
        | B::IoErrorMessage
        | B::ConsolePrint
        | B::ConsolePrintln
        | B::ConsoleEprintln
        | B::FileReadText
        | B::ProcessArgs => {
            return Err(internal(format!("{id:?} is not an operator")));
        }
    };
    Ok(plan)
}

/// 定数の `case` で定数と比べる `==` の命令。`Unit` は比べないので `None`。
fn const_eq_op(c: &Const) -> Option<Opcode> {
    match c {
        Const::Int(_) => Some(Opcode::EqI),
        Const::Float(_) => Some(Opcode::EqF),
        Const::Str(_) => Some(Opcode::EqS),
        Const::Char(_) => Some(Opcode::EqC),
        Const::Bool(_) => Some(Opcode::EqB),
        Const::Unit => None,
    }
}

/// 値として使う組み込みの関数の原型の名前（`Int.floorDiv` の形。02-07「原型の名前と由来の種類」）。
fn builtin_value_name(id: BuiltinId) -> String {
    let s = spec(id);
    match s.module {
        Some(m) => format!("{}.{}", m.name(), s.name),
        None => s.name.to_string(),
    }
}

impl<'p> Gen<'p> {
    fn new(program: &'p LowerProgram) -> Gen<'p> {
        Gen {
            program,
            protos: Vec::new(),
            def_protos: HashMap::new(),
            builtin_protos: HashMap::new(),
            builtins: Vec::new(),
            builtin_index: HashMap::new(),
            ctors: Vec::new(),
            ctor_index: HashMap::new(),
            diags: Vec::new(),
            pending: VecDeque::new(),
        }
    }

    /// 原型の表の後ろに場所を取る。ラムダの原型は出会った順に番号を振る（T21 の 2）ので、
    /// 本体を移す前に場所を取り、本体の中のラムダがその後ろに並ぶようにする。
    fn reserve_proto(&mut self) -> CgResult<ProtoIdx> {
        let idx = u32::try_from(self.protos.len()).map_err(|_| internal("too many prototypes"))?;
        self.protos.push(None);
        Ok(ProtoIdx(idx))
    }

    fn set_proto(&mut self, idx: ProtoIdx, proto: Proto) -> CgResult<()> {
        let slot = usize::try_from(idx.0)
            .ok()
            .and_then(|i| self.protos.get_mut(i))
            .ok_or_else(|| internal("prototype index out of range"))?;
        *slot = Some(proto);
        Ok(())
    }

    /// `PRIM`・`IO` の B が指す組み込みの関数の表の番号。初めて使ったときに加える。
    fn builtin_idx(&mut self, id: BuiltinId) -> CgResult<u16> {
        if let Some(i) = self.builtin_index.get(&id) {
            return Ok(*i);
        }
        let i = u16::try_from(self.builtins.len())
            .map_err(|_| internal("too many builtin references"))?;
        self.builtins.push(id);
        self.builtin_index.insert(id, i);
        Ok(i)
    }

    /// `CON` の B が指す構成子の表の番号。初めて使ったときに加える。
    fn ctor_idx(&mut self, con: TyCon, tag: u32) -> CgResult<u16> {
        if let Some(i) = self.ctor_index.get(&(con, tag)) {
            return Ok(*i);
        }
        let adt = self
            .program
            .adts
            .get(con)
            .ok_or_else(|| internal("constructor of an unknown type"))?;
        let ctor = adt
            .ctors
            .iter()
            .find(|c| c.tag == tag)
            .ok_or_else(|| internal("unknown constructor tag"))?;
        // 引数が 65536 個以上の構成子を作る原型は、引数を置く連続したレジスタだけで上限を超え、
        // L0101 を報告して実行しない（T21「処理系の制限」）。ここでは丸めて生成を続ける（`r16`）。
        let arity = r16(count_u32(ctor.fields.len()));
        let i = u16::try_from(self.ctors.len()).map_err(|_| internal("too many constructors"))?;
        self.ctors.push(CtorInfo {
            type_name: adt.name.clone(),
            ctor_name: ctor.name.clone(),
            tag,
            arity,
        });
        self.ctor_index.insert((con, tag), i);
        Ok(i)
    }

    /// 値として使う組み込みの関数の原型。組み込みの関数ごとに一つ作って使い回す。
    /// 引数を `R[0]`〜`R[n-1]` に受け取り、`PRIM 0 b 0`（IO なら `IO 0 b 0`）と `RETURN 0` だけからなる。
    fn builtin_proto(&mut self, id: BuiltinId) -> CgResult<ProtoIdx> {
        if let Some(p) = self.builtin_protos.get(&id) {
            return Ok(*p);
        }
        let s = spec(id);
        let b = self.builtin_idx(id)?;
        let op = match s.kind {
            BuiltinKind::Pure(_) => Opcode::Prim,
            BuiltinKind::Io(_) => Opcode::Io,
        };
        let idx = self.reserve_proto()?;
        let proto = Proto {
            name: builtin_value_name(id),
            origin: ProtoOrigin::BuiltinValue,
            lambda_span: None,
            code: vec![Instr::abc(op, 0, b, 0), Instr::abc(Opcode::Return, 0, 0, 0)],
            consts: Vec::new(),
            switch_tables: Vec::new(),
            // 引数のない関数（`Process.args`）でも、結果を入れるレジスタ 0 が要る
            num_regs: s.arity.max(1),
            num_params: s.arity,
            captures: Vec::new(),
            positions: vec![None, None],
        };
        self.set_proto(idx, proto)?;
        self.builtin_protos.insert(id, idx);
        Ok(idx)
    }

    /// 定義の原型を作る。引数は `R[0]` から順に置く（02-07「レジスタの割り当て」）。
    fn def_proto(&mut self, def: &'p LowerDef) -> CgResult<Proto> {
        let user = def.origin == DefOrigin::User;
        let mut fg = Box::new(FnGen::new(def, user));
        for p in &def.params {
            let r = fg.alloc();
            fg.env.insert(p.id, Loc::Reg(r));
        }
        self.comp(&mut fg, &def.body, Target::Tail)?;
        let origin = match def.origin {
            DefOrigin::User => ProtoOrigin::UserFn,
            DefOrigin::PreludePublic { .. } => ProtoOrigin::PreludePublic,
            DefOrigin::PreludeHelper => ProtoOrigin::PreludeHelper,
        };
        Ok(self.finish(
            fg,
            def.name.clone(),
            origin,
            None,
            count_u32(def.params.len()),
        ))
    }

    /// 生成を終えた原型の状態から原型を作り、処理系の制限を確かめる（02-07「処理系の制限」）。
    /// 制限に当たっても原型は作り、ほかの原型の生成を続ける。
    fn finish(
        &mut self,
        fg: Box<FnGen<'p>>,
        name: String,
        origin: ProtoOrigin,
        lambda_span: Option<Span>,
        num_params: u32,
    ) -> Proto {
        let fg = *fg;
        // 診断の `{name}` は原型の名前、ラムダではそれを含む定義の名前。主な位置は定義の宣言
        // （T21「処理系の制限」、02-10「処理系の不具合と処理系の制限の報告」）
        if fg.max_regs > MAX_REGS {
            self.diags.push(
                DiagBuilder::new(DiagCode::L0101)
                    .arg("name", fg.def.name.clone())
                    .primary(fg.def.span)
                    .note("limit")
                    .build(),
            );
        }
        if fg.consts.len() > MAX_CONSTS {
            self.diags.push(
                DiagBuilder::new(DiagCode::L0102)
                    .arg("name", fg.def.name.clone())
                    .primary(fg.def.span)
                    .note("limit")
                    .build(),
            );
        }
        Proto {
            name,
            origin,
            lambda_span,
            code: fg.code,
            consts: fg.consts,
            switch_tables: fg.switch_tables,
            num_regs: r16(fg.max_regs),
            num_params: r16(num_params),
            captures: fg.captures,
            positions: fg.positions,
        }
    }

    // ---- 計算 ----

    /// 計算を、結果の行き先 `target` に向けて移す（02-07「コード生成」の表）。
    fn comp(&mut self, fg: &mut FnGen<'p>, c: &'p LComp, target: Target) -> CgResult<()> {
        match &c.kind {
            LCompKind::Return(v) => self.return_(fg, c, v, target),
            LCompKind::Let { .. } => self.let_(fg, c, target),
            LCompKind::App { func, args } => self.app(fg, c, func, args, target),
            LCompKind::If { .. } => self.if_(fg, c, target),
            LCompKind::CaseCtor { .. } => self.case_ctor(fg, c, target),
            LCompKind::CaseConst { .. } => self.case_const(fg, c, target),
            LCompKind::Join { .. } => self.join(fg, c, target),
            LCompKind::Jump { label, args } => self.jump(fg, c, *label, args),
        }
    }

    /// `return V`: V を r に入れる。末尾位置なら V のレジスタを `RETURN` する。
    fn return_(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        v: &'p LowVal,
        target: Target,
    ) -> CgResult<()> {
        match target {
            Target::Reg(r) => self.val_into(fg, v, r),
            Target::Tail => {
                let mark = fg.next_reg;
                let x = match fg.reg_of(v) {
                    Some(r) => r,
                    None => {
                        let t = fg.alloc();
                        self.val_into(fg, v, t)?;
                        t
                    }
                };
                fg.emit(Instr::abc(Opcode::Return, r16(x), 0, 0), Some(c.origin));
                fg.release(mark);
                Ok(())
            }
        }
    }

    /// `let x ⇐ M in N`: x にレジスタを割り当て、M をそのレジスタを結果として（末尾位置でなく）移し、
    /// N を同じ行き先で移す。`let` の右側が入れ子の形でも、同じ規則を再帰的に適用する（02-07）。
    fn let_(&mut self, fg: &mut FnGen<'p>, c: &'p LComp, target: Target) -> CgResult<()> {
        let LCompKind::Let { var, bound, body } = &c.kind else {
            return Err(internal("let expected"));
        };
        let mark = fg.next_reg;
        let x = fg.alloc();
        self.comp(fg, bound, Target::Reg(x))?;
        fg.env.insert(var.id, Loc::Reg(x));
        self.comp(fg, body, target)?;
        fg.env.remove(&var.id);
        fg.release(mark);
        Ok(())
    }

    /// 関数の適用。演算子、そのほかの組み込みの関数、そのほかの関数の三つに分ける。
    fn app(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        func: &'p LowVal,
        args: &'p [LowVal],
        target: Target,
    ) -> CgResult<()> {
        let mark = fg.next_reg;
        let n = count_u32(args.len());
        if let ValKind::Builtin { id, tys, .. } = &func.kind {
            let id = *id;
            if id.is_operator() {
                self.operator(fg, c, id, tys, args, target)?;
            } else {
                // 組み込みの関数は呼び出しの情報を積まないので、末尾位置でも PRIM・IO の後に
                // RETURN を置けば継続は伸びない（02-07「末尾呼び出し」）。
                let s = spec(id);
                if usize::from(s.arity) != args.len() {
                    return Err(internal(format!(
                        "{id:?} applied to a wrong number of arguments"
                    )));
                }
                let base = fg.alloc_block(n);
                self.vals_into(fg, args, base)?;
                let dst = match target {
                    Target::Reg(r) => r,
                    Target::Tail => fg.alloc(),
                };
                let op = match s.kind {
                    BuiltinKind::Pure(_) => Opcode::Prim,
                    BuiltinKind::Io(_) => Opcode::Io,
                };
                let b = self.builtin_idx(id)?;
                fg.emit(Instr::abc(op, r16(dst), b, r16(base)), Some(c.origin));
                if let Target::Tail = target {
                    fg.emit(Instr::abc(Opcode::Return, r16(dst), 0, 0), Some(c.origin));
                }
            }
        } else {
            // 関数を R[b]、引数を R[b+1]…R[b+n] に置く。末尾位置なら TAILCALL にして
            // 呼び出しの枠を積まない（ADR 0013）。
            let base = fg.alloc_block(n.saturating_add(1));
            self.val_into(fg, func, base)?;
            self.vals_into(fg, args, base.saturating_add(1))?;
            let instr = match target {
                Target::Reg(r) => Instr::abc(Opcode::Call, r16(r), r16(base), r16(n)),
                Target::Tail => Instr::abc(Opcode::TailCall, 0, r16(base), r16(n)),
            };
            fg.emit(instr, Some(c.origin));
        }
        fg.release(mark);
        Ok(())
    }

    /// 演算子の組み込みの関数を専用の命令に移す（02-07「演算子の移し方」）。
    fn operator(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        id: BuiltinId,
        tys: &[Ty],
        args: &'p [LowVal],
        target: Target,
    ) -> CgResult<()> {
        let plan = operator_plan(id, tys)?;
        let dst_of = |fg: &mut FnGen<'p>| match target {
            Target::Reg(r) => r,
            Target::Tail => fg.alloc(),
        };
        let dst = match plan {
            OpPlan::ConstBool(b) => {
                // Unit の値はどれも等しいので、オペランドを読まずに結果が決まる
                let dst = dst_of(fg);
                fg.load_const(dst, ConstDesc::Bool(b), c.origin);
                dst
            }
            OpPlan::Unary(op) => {
                let [x] = args else {
                    return Err(internal("unary operator with a wrong number of operands"));
                };
                let x = self.operand(fg, x)?;
                let dst = dst_of(fg);
                fg.emit(Instr::abc(op, r16(dst), r16(x), 0), Some(c.origin));
                dst
            }
            OpPlan::Binary { op, swap, negate } => {
                let [x, y] = args else {
                    return Err(internal("binary operator with a wrong number of operands"));
                };
                // 値を移す命令は左のオペランドから出す。入れ替えるのは命令のオペランドの順だけである
                let x = self.operand(fg, x)?;
                let y = self.operand(fg, y)?;
                let (x, y) = if swap { (y, x) } else { (x, y) };
                let dst = dst_of(fg);
                fg.emit(Instr::abc(op, r16(dst), r16(x), r16(y)), Some(c.origin));
                if negate {
                    fg.emit(
                        Instr::abc(Opcode::Not, r16(dst), r16(dst), 0),
                        Some(c.origin),
                    );
                }
                dst
            }
        };
        if let Target::Tail = target {
            fg.emit(Instr::abc(Opcode::Return, r16(dst), 0, 0), Some(c.origin));
        }
        Ok(())
    }

    /// `if`: `JMPF v →Lelse`、M、（末尾位置でなければ）`JMP →Lend`、`Lelse:` N、`Lend:`
    /// （02-07「分岐と合流の並べ方」）。
    fn if_(&mut self, fg: &mut FnGen<'p>, c: &'p LComp, target: Target) -> CgResult<()> {
        // 再帰の経路にある関数なので、再帰の前後の処理は補助の関数に分け、一段のスタックを
        // 小さく保つ（00-02「再帰の深さ」。最適化しないビルドでは一時の値が別々の場所を占める）
        let LCompKind::If {
            cond,
            then_branch,
            else_branch,
        } = &c.kind
        else {
            return Err(internal("if expected"));
        };
        let jmpf = self.cond_jump(fg, cond, c.origin)?;
        self.comp(fg, then_branch, target)?;
        // 末尾位置では M は RETURN・TAILCALL・jump の JMP で終わるので、JMP →Lend は要らない
        let to_end = fg.jump_to_end(target, c.origin);
        fg.patch_here(jmpf)?;
        self.comp(fg, else_branch, target)?;
        fg.patch_end(to_end)
    }

    /// `JMPF v` を出し、その位置を返す。条件の値は JMPF の後に使わないので、一時的なレジスタに
    /// 移したならここで解放する。
    fn cond_jump(&mut self, fg: &mut FnGen<'p>, cond: &'p LowVal, origin: Span) -> CgResult<usize> {
        let mark = fg.next_reg;
        let v = self.operand(fg, cond)?;
        let pos = fg.emit_jump(Opcode::JmpF, v, origin);
        fg.release(mark);
        Ok(pos)
    }

    /// 構成子の `case`: `SWITCH` と分岐表。各分岐の先頭で `FIELD` によって引数を取り出す。
    ///
    /// `case`・`join` は入れ子になりうるので、再帰の前後の処理は補助の関数に分け、一段の
    /// スタックを小さく保つ（00-02「再帰の深さ」）。
    fn case_ctor(&mut self, fg: &mut FnGen<'p>, c: &'p LComp, target: Target) -> CgResult<()> {
        let LCompKind::CaseCtor {
            scrutinee,
            arms,
            default,
        } = &c.kind
        else {
            return Err(internal("constructor case expected"));
        };
        let mut st = self.switch_head(fg, c, scrutinee, arms.len(), default.is_some())?;
        for (i, arm) in arms.iter().enumerate() {
            fg.ctor_arm_head(&st, arm, c.origin)?;
            self.comp(fg, &arm.body, target)?;
            fg.ctor_arm_tail(&mut st, arm, i, target, c.origin);
        }
        if let Some(d) = default {
            fg.switch_default(&st)?;
            self.comp(fg, d, target)?;
        }
        fg.case_end(st.end)
    }

    /// 構成子の `case` の対象の値をレジスタに置き、分岐表を作って `SWITCH` を出す。
    fn switch_head(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        scrutinee: &'p LowVal,
        arm_count: usize,
        has_default: bool,
    ) -> CgResult<Box<SwitchState>> {
        let con = match &scrutinee.ty {
            Ty::Con(con, _) => *con,
            Ty::Fn(_) | Ty::Param(_) => {
                return Err(internal(
                    "constructor case on a value that is not a data type",
                ));
            }
        };
        let tag_count = self
            .program
            .adts
            .get(con)
            .ok_or_else(|| internal("constructor case on an unknown type"))?
            .ctors
            .len();
        // 対象の値は各分岐の FIELD で読むので、case を移し終えるまで解放しない
        let mark = fg.next_reg;
        let scrutinee = self.operand(fg, scrutinee)?;
        let table = fg.switch_tables.len();
        fg.switch_tables.push(SwitchTable {
            targets: vec![None; tag_count],
            default: None,
        });
        let switch = fg.emit(
            Instr::abx(Opcode::Switch, r16(scrutinee), count_u32(table)),
            Some(c.origin),
        );
        // 最後に置く分岐の後はすぐに case の終わりなので、JMP を置かない（`if` の N と同じ）
        let last_arm = if has_default {
            None
        } else {
            arm_count.checked_sub(1)
        };
        Ok(Box::new(SwitchState {
            scrutinee,
            table,
            switch,
            last_arm,
            arm_base: fg.next_reg,
            end: CaseEnd {
                mark,
                to_end: Vec::new(),
            },
        }))
    }

    /// 定数の `case`: 定数ごとに `LOADK`、`==` の命令、`JMPF` で次の比較へ跳ぶ形を並べ、
    /// 最後に `_` の分岐を置く（02-07「コード生成」の表）。
    fn case_const(&mut self, fg: &mut FnGen<'p>, c: &'p LComp, target: Target) -> CgResult<()> {
        let LCompKind::CaseConst {
            scrutinee,
            arms,
            default,
        } = &c.kind
        else {
            return Err(internal("constant case expected"));
        };
        // 対象の値はすべての比較で読むので、case を移し終えるまで解放しない
        let mark = fg.next_reg;
        let s = self.operand(fg, scrutinee)?;
        let mut end = CaseEnd {
            mark,
            to_end: Vec::new(),
        };
        for (i, arm) in arms.iter().enumerate() {
            // default のない case の最後の分岐は比べない。それまでの定数のどれでもなければ、
            // 残る値はその定数しかない。Unit の定数は比べずに一致したものとし、後の分岐には
            // 届かないので置かない。
            let compare = default.is_some() || i.saturating_add(1) < arms.len();
            match fg.const_arm_head(s, &arm.value, compare, c.origin) {
                Some(jmpf) => {
                    self.comp(fg, &arm.body, target)?;
                    fg.const_arm_tail(&mut end, jmpf, target, c.origin)?;
                }
                None => {
                    self.comp(fg, &arm.body, target)?;
                    return fg.case_end(end);
                }
            }
        }
        let Some(d) = default else {
            return Err(internal("constant case without a final arm"));
        };
        self.comp(fg, d, target)?;
        fg.case_end(end)
    }

    /// `join k(x̄) = M in N`: N、（末尾位置でなければ）`JMP →Lend`、`Lk:` M、`Lend:`
    /// （02-07「分岐と合流の並べ方」）。
    fn join(&mut self, fg: &mut FnGen<'p>, c: &'p LComp, target: Target) -> CgResult<()> {
        let LCompKind::Join {
            label,
            params,
            handler,
            body,
        } = &c.kind
        else {
            return Err(internal("join expected"));
        };
        // x̄ のレジスタは、N と M を移し終えるまで解放しない
        let mark = fg.join_head(*label, params.len());
        self.comp(fg, body, target)?;
        let to_end = fg.join_label(*label, params, target, c.origin)?;
        self.comp(fg, handler, target)?;
        fg.join_end(*label, params, to_end, mark)
    }

    /// `jump k(V̄)`: V̄ を k の引数のレジスタに移して `JMP →Lk`。
    fn jump(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        label: JoinId,
        args: &'p [LowVal],
    ) -> CgResult<()> {
        let params = match fg.joins.get(&label) {
            Some(state) => state.params.clone(),
            None => return Err(internal("jump to an unknown join label")),
        };
        if params.len() != args.len() {
            return Err(internal("jump with a wrong number of arguments"));
        }
        // 値が読むレジスタと k の引数のレジスタが重なるときは、先に書いた引数が後の値を
        // 壊さないように、いったん一時的なレジスタにすべて写してから移す（T21 の新たな決定）。
        let overlap = args.iter().enumerate().any(|(i, a)| {
            val_reads(fg, a)
                .iter()
                .any(|r| params.iter().enumerate().any(|(j, p)| p == r && j != i))
        });
        let mark = fg.next_reg;
        if overlap {
            let tmp = fg.alloc_block(count_u32(args.len()));
            self.vals_into(fg, args, tmp)?;
            for (i, p) in params.iter().enumerate() {
                let from = tmp.saturating_add(count_u32(i));
                fg.emit(
                    Instr::abc(Opcode::Move, r16(*p), r16(from), 0),
                    Some(c.origin),
                );
            }
        } else {
            for (a, p) in args.iter().zip(params.iter()) {
                self.val_into(fg, a, *p)?;
            }
        }
        fg.release(mark);
        let pos = fg.emit_jump(Opcode::Jmp, 0, c.origin);
        let known = match fg.joins.get_mut(&label) {
            Some(state) => match state.target {
                Some(t) => Some(t),
                None => {
                    state.pending.push(pos);
                    None
                }
            },
            None => return Err(internal("jump to an unknown join label")),
        };
        if let Some(t) = known {
            fg.patch(pos, t)?;
        }
        Ok(())
    }

    // ---- 値 ----

    /// 値を命令のオペランドにするレジスタ。レジスタにある変数はそのレジスタ、そのほかは
    /// 一時的なレジスタに移す（02-07「コード生成」の最後の段落）。一時的なレジスタの解放は呼ぶ側が行う。
    fn operand(&mut self, fg: &mut FnGen<'p>, v: &'p LowVal) -> CgResult<u32> {
        if let Some(r) = fg.reg_of(v) {
            return Ok(r);
        }
        let t = fg.alloc();
        self.val_into(fg, v, t)?;
        Ok(t)
    }

    /// 値の並びを、`base` から始まる連続したレジスタに移す。
    fn vals_into(&mut self, fg: &mut FnGen<'p>, vals: &'p [LowVal], base: u32) -> CgResult<()> {
        for (i, v) in vals.iter().enumerate() {
            self.val_into(fg, v, base.saturating_add(count_u32(i)))?;
        }
        Ok(())
    }

    /// 値をレジスタ `dst` に移す（02-07「値の移し方」）。
    fn val_into(&mut self, fg: &mut FnGen<'p>, v: &'p LowVal, dst: u32) -> CgResult<()> {
        // ラムダの入れ子は再帰の経路になるので、分岐ごとの処理は補助の関数に分けて一段の
        // スタックを小さく保つ（00-02「再帰の深さ」）
        match &v.kind {
            ValKind::Var(x) => self.var_into(fg, *x, dst, v.origin),
            ValKind::Const(_) | ValKind::TopFn { .. } | ValKind::Builtin { .. } => {
                self.const_into(fg, v, dst)
            }
            ValKind::Lambda(lambda) => self.closure_into(fg, lambda, dst, v.origin),
            ValKind::Ctor { .. } => self.ctor_into(fg, v, dst),
            ValKind::List(items) => self.list_into(fg, items, dst, v.origin),
        }
    }

    /// 定数表から作る値（定数、トップレベルの関数、値として使う組み込みの関数）を `LOADK` する。
    fn const_into(&mut self, fg: &mut FnGen<'p>, v: &'p LowVal, dst: u32) -> CgResult<()> {
        let desc = match &v.kind {
            ValKind::Const(k) => const_desc(k),
            // トップレベルの関数は何も捕捉しないので、原型の番号の定数から作る（02-07）
            ValKind::TopFn { def, .. } => match self.def_protos.get(def) {
                Some(p) => ConstDesc::Proto(*p),
                None => return Err(internal("reference to an unknown top-level function")),
            },
            ValKind::Builtin { id, .. } => ConstDesc::Proto(self.builtin_proto(*id)?),
            ValKind::Var(_) | ValKind::Lambda(_) | ValKind::Ctor { .. } | ValKind::List(_) => {
                return Err(internal("constant value expected"));
            }
        };
        fg.load_const(dst, desc, v.origin);
        Ok(())
    }

    fn var_into(&mut self, fg: &mut FnGen<'p>, x: VarId, dst: u32, origin: Span) -> CgResult<()> {
        match fg.lookup(x)? {
            Loc::Reg(r) => {
                if r != dst {
                    fg.emit(Instr::abc(Opcode::Move, r16(dst), r16(r), 0), Some(origin));
                }
            }
            Loc::Cap(i) => {
                fg.emit(
                    Instr::abc(Opcode::GetCap, r16(dst), r16(i), 0),
                    Some(origin),
                );
            }
        }
        Ok(())
    }

    fn ctor_into(&mut self, fg: &mut FnGen<'p>, v: &'p LowVal, dst: u32) -> CgResult<()> {
        let ValKind::Ctor { con, tag, args, .. } = &v.kind else {
            return Err(internal("constructor value expected"));
        };
        if args.is_empty() {
            // 引数のない構成子はタグだけで値が決まるので、定数にする（02-07）
            fg.load_const(dst, ConstDesc::NullaryCtor { tag: *tag }, v.origin);
            return Ok(());
        }
        let mark = fg.next_reg;
        let base = fg.alloc_block(count_u32(args.len()));
        self.vals_into(fg, args, base)?;
        let k = self.ctor_idx(*con, *tag)?;
        fg.emit(
            Instr::abc(Opcode::Con, r16(dst), k, r16(base)),
            Some(v.origin),
        );
        fg.release(mark);
        Ok(())
    }

    fn list_into(
        &mut self,
        fg: &mut FnGen<'p>,
        items: &'p [LowVal],
        dst: u32,
        origin: Span,
    ) -> CgResult<()> {
        let mark = fg.next_reg;
        let n = count_u32(items.len());
        let base = fg.alloc_block(n);
        self.vals_into(fg, items, base)?;
        fg.emit(
            Instr::abc(Opcode::List, r16(dst), r16(base), r16(n)),
            Some(origin),
        );
        fg.release(mark);
        Ok(())
    }

    /// ラムダの原型を作り、`CLOSURE` で関数の値を `dst` に作る（02-07「関数の値と捕捉」）。
    fn closure_into(
        &mut self,
        fg: &mut FnGen<'p>,
        lambda: &'p Lambda<LComp>,
        dst: u32,
        origin: Span,
    ) -> CgResult<()> {
        let idx = self.lambda_start(fg, lambda)?;
        fg.emit(Instr::abx(Opcode::Closure, r16(dst), idx.0), Some(origin));
        Ok(())
    }

    /// ラムダの原型の場所を取り、本体を移すための状態を作って、後で移すラムダの列に加える。
    /// 自由な変数を現れた順に並べて捕捉の表にし、作る側の原型でその変数がレジスタにあれば `Reg`、
    /// 捕捉した値なら `Capture` を記録する（02-07「関数の値と捕捉」）。
    ///
    /// 捕捉の取り方は作る側のその時点の変数の置き場所で決まるので、ここで決める。本体は作る側の
    /// 原型を移し終えてから移す（`drain_lambdas`）。ラムダの入れ子の深さに比例して再帰しないためである。
    fn lambda_start(&mut self, fg: &FnGen<'p>, lambda: &'p Lambda<LComp>) -> CgResult<ProtoIdx> {
        let free = free_vars(
            Node::Comp(&lambda.body),
            lambda.params.iter().map(|p| p.id).collect(),
        );

        let mut inner = Box::new(FnGen::new(fg.def, fg.user));
        for x in &free {
            inner.captures.push(match fg.lookup(*x)? {
                Loc::Reg(r) => CaptureSource::Reg(r16(r)),
                Loc::Cap(i) => CaptureSource::Capture(r16(i)),
            });
        }
        for p in &lambda.params {
            let r = inner.alloc();
            inner.env.insert(p.id, Loc::Reg(r));
        }
        for (i, x) in free.iter().enumerate() {
            inner.env.insert(*x, Loc::Cap(count_u32(i)));
        }
        let idx = self.reserve_proto()?;
        self.pending.push_back(PendingLambda { idx, lambda, inner });
        Ok(idx)
    }

    /// 後で移すラムダの列が空になるまで、ラムダの本体を移して原型を作る。本体の中のラムダは
    /// 列の後ろに加わる。
    fn drain_lambdas(&mut self) -> CgResult<()> {
        while let Some(PendingLambda {
            idx,
            lambda,
            mut inner,
        }) = self.pending.pop_front()
        {
            self.comp(&mut inner, &lambda.body, Target::Tail)?;
            self.lambda_finish(inner, lambda, idx)?;
        }
        Ok(())
    }

    fn lambda_finish(
        &mut self,
        inner: Box<FnGen<'p>>,
        lambda: &'p Lambda<LComp>,
        idx: ProtoIdx,
    ) -> CgResult<()> {
        // 利用者の定義の中のラムダは `<lambda>` と位置で示し、prelude のソースの中のラムダは
        // 補助の関数と同じく呼び出しの履歴に示さない（02-07「原型の名前と由来の種類」）
        let (origin, lambda_span) = if inner.user {
            (ProtoOrigin::UserLambda, Some(lambda.span))
        } else {
            (ProtoOrigin::PreludeHelper, None)
        };
        let proto = self.finish(
            inner,
            "<lambda>".to_string(),
            origin,
            lambda_span,
            count_u32(lambda.params.len()),
        );
        self.set_proto(idx, proto)
    }
}

// ---- 自由な変数 ----
//
// 変数の番号は定義ごとに重ならない（10-06 `VarId`）。束縛する側は、その変数を参照する計算より
// 行きがけ順で先に現れるので、一度の行きがけ順の走査で、束縛した変数を記録しながら、記録にない
// 参照を自由な変数として集められる。入れ子の深さに比例して再帰しないよう、明示の積み重ねで辿る。

/// 走査の積み重ねに置く節。
enum Node<'a> {
    Comp(&'a LComp),
    Val(&'a LowVal),
}

/// `root` の中の変数の参照のうち、`bound` にも `root` の中の束縛にもないものを、現れた順に
/// 重複なく返す。
fn free_vars(root: Node<'_>, mut bound: Vec<VarId>) -> Vec<VarId> {
    let mut out: Vec<VarId> = Vec::new();
    let mut stack = vec![root];
    while let Some(node) = stack.pop() {
        // 子は現れる順の逆に積み、積み重ねから現れる順に取り出す
        match node {
            Node::Val(v) => match &v.kind {
                ValKind::Var(x) => {
                    if !bound.contains(x) && !out.contains(x) {
                        out.push(*x);
                    }
                }
                ValKind::Lambda(l) => {
                    bound.extend(l.params.iter().map(|p| p.id));
                    stack.push(Node::Comp(&l.body));
                }
                ValKind::Ctor { args, .. } | ValKind::List(args) => {
                    stack.extend(args.iter().rev().map(Node::Val));
                }
                ValKind::Const(_) | ValKind::TopFn { .. } | ValKind::Builtin { .. } => {}
            },
            Node::Comp(c) => match &c.kind {
                LCompKind::Return(v) => stack.push(Node::Val(v)),
                LCompKind::Let {
                    var,
                    bound: m,
                    body,
                } => {
                    bound.push(var.id);
                    stack.push(Node::Comp(body));
                    stack.push(Node::Comp(m));
                }
                LCompKind::App { func, args } => {
                    stack.extend(args.iter().rev().map(Node::Val));
                    stack.push(Node::Val(func));
                }
                LCompKind::If {
                    cond,
                    then_branch,
                    else_branch,
                } => {
                    stack.push(Node::Comp(else_branch));
                    stack.push(Node::Comp(then_branch));
                    stack.push(Node::Val(cond));
                }
                LCompKind::CaseCtor {
                    scrutinee,
                    arms,
                    default,
                } => {
                    for arm in arms {
                        bound.extend(arm.fields.iter().map(|f| f.id));
                    }
                    if let Some(d) = default {
                        stack.push(Node::Comp(d));
                    }
                    stack.extend(arms.iter().rev().map(|a| Node::Comp(&a.body)));
                    stack.push(Node::Val(scrutinee));
                }
                LCompKind::CaseConst {
                    scrutinee,
                    arms,
                    default,
                } => {
                    if let Some(d) = default {
                        stack.push(Node::Comp(d));
                    }
                    stack.extend(arms.iter().rev().map(|a| Node::Comp(&a.body)));
                    stack.push(Node::Val(scrutinee));
                }
                // 命令の並びと同じく、N を M より先に辿る
                LCompKind::Join {
                    params,
                    handler,
                    body,
                    ..
                } => {
                    bound.extend(params.iter().map(|p| p.id));
                    stack.push(Node::Comp(handler));
                    stack.push(Node::Comp(body));
                }
                LCompKind::Jump { args, .. } => {
                    stack.extend(args.iter().rev().map(Node::Val));
                }
            },
        }
    }
    out
}

/// 値を移すときに読むレジスタ（`jump` の引数の重なりを調べるため）。
fn val_reads(fg: &FnGen<'_>, v: &LowVal) -> Vec<u32> {
    free_vars(Node::Val(v), Vec::new())
        .iter()
        .filter_map(|x| match fg.env.get(x) {
            Some(Loc::Reg(r)) => Some(*r),
            Some(Loc::Cap(_)) | None => None,
        })
        .collect()
}

#[cfg(test)]
// テストの失敗は panic で表す（設計書 07-03「実装の規約と静的な検査」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::{BytePos, FileId};
    use crate::builtins::PreludeModule;
    use crate::ir::core_ir::{Def, LambdaId, Program, Val};
    use crate::ir::lower_ir::ConstArm;
    use crate::types::{AdtDef, AdtTable, CtorDef, EffectSet, EqSummary};

    use Opcode as O;

    const TREE: TyCon = TyCon::Adt(BindingId(100));

    fn span(n: u32) -> Span {
        Span {
            file: FileId(0),
            start: BytePos(n),
            end: BytePos(n),
        }
    }

    /// `Option`（`Some` が 0、`None` が 1）と `type Tree { Leaf | Node(Tree, Int, Tree) }` の表。
    fn adts() -> AdtTable {
        let ctor = |name: &str, tag: u32, fields: Vec<Ty>| CtorDef {
            name: name.to_string(),
            binding: BindingId(200 + tag),
            tag,
            fields,
        };
        let adt = |con: TyCon, name: &str, ctors: Vec<CtorDef>| AdtDef {
            con,
            name: name.to_string(),
            type_params: Vec::new(),
            ctors,
            eq_summary: EqSummary::default(),
        };
        let tree = Ty::con(TREE);
        AdtTable {
            adts: vec![
                adt(
                    TyCon::Option,
                    "Option",
                    vec![ctor("Some", 0, vec![Ty::Param(0)]), ctor("None", 1, vec![])],
                ),
                adt(
                    TREE,
                    "Tree",
                    vec![
                        ctor("Leaf", 0, vec![]),
                        ctor("Node", 1, vec![tree.clone(), Ty::int(), tree]),
                    ],
                ),
            ],
        }
    }

    // ---- 下位 IR を組む補助 ----

    fn var(id: u32, ty: Ty) -> Var {
        Var {
            id: VarId(id),
            name: None,
            ty,
        }
    }

    fn val(kind: ValKind<LComp>, ty: Ty) -> LowVal {
        Val {
            kind,
            ty,
            origin: span(1),
        }
    }

    fn v(x: &Var) -> LowVal {
        val(ValKind::Var(x.id), x.ty.clone())
    }

    fn k(c: Const) -> LowVal {
        val(ValKind::Const(c), Ty::int())
    }

    fn int(n: i64) -> LowVal {
        k(Const::Int(n))
    }

    fn top(binding: u32) -> LowVal {
        val(
            ValKind::TopFn {
                def: BindingId(binding),
                tys: Vec::new(),
                effs: Vec::new(),
            },
            Ty::int(),
        )
    }

    fn builtin(id: BuiltinId, tys: Vec<Ty>) -> LowVal {
        val(
            ValKind::Builtin {
                id,
                tys,
                effs: Vec::new(),
            },
            Ty::int(),
        )
    }

    fn lambda(id: u32, params: Vec<Var>, body: LComp, at: u32) -> LowVal {
        val(
            ValKind::Lambda(Box::new(Lambda {
                id: LambdaId(id),
                params,
                body,
                span: span(at),
            })),
            Ty::int(),
        )
    }

    fn list(items: Vec<LowVal>) -> LowVal {
        val(ValKind::List(items), Ty::list(Ty::int()))
    }

    /// 計算の由来位置は 2 にし、値の由来位置（1）と区別する。
    fn comp(kind: LCompKind) -> LComp {
        LComp {
            kind,
            ty: Ty::int(),
            eff: EffectSet::empty(),
            origin: span(2),
        }
    }

    fn ret(x: LowVal) -> LComp {
        comp(LCompKind::Return(x))
    }

    fn let_(x: &Var, bound: LComp, body: LComp) -> LComp {
        comp(LCompKind::Let {
            var: x.clone(),
            bound: Box::new(bound),
            body: Box::new(body),
        })
    }

    fn app(func: LowVal, args: Vec<LowVal>) -> LComp {
        comp(LCompKind::App { func, args })
    }

    fn if_(cond: LowVal, then_branch: LComp, else_branch: LComp) -> LComp {
        comp(LCompKind::If {
            cond,
            then_branch: Box::new(then_branch),
            else_branch: Box::new(else_branch),
        })
    }

    fn jump(label: u32, args: Vec<LowVal>) -> LComp {
        comp(LCompKind::Jump {
            label: JoinId(label),
            args,
        })
    }

    fn join(label: u32, params: Vec<Var>, handler: LComp, body: LComp) -> LComp {
        comp(LCompKind::Join {
            label: JoinId(label),
            params,
            handler: Box::new(handler),
            body: Box::new(body),
        })
    }

    fn def(binding: u32, name: &str, origin: DefOrigin, params: Vec<Var>, body: LComp) -> LowerDef {
        Def {
            binding: BindingId(binding),
            name: name.to_string(),
            origin,
            type_params: Vec::new(),
            effect_params: Vec::new(),
            params,
            ret: Ty::int(),
            eff: EffectSet::empty(),
            body,
            span: span(100 + binding),
            var_count: 100,
        }
    }

    fn user(binding: u32, name: &str, params: Vec<Var>, body: LComp) -> LowerDef {
        def(binding, name, DefOrigin::User, params, body)
    }

    /// 定義の並びから、最後の定義を `main` とするプログラムを作る。
    fn program(defs: Vec<LowerDef>) -> LowerProgram {
        let main = defs.last().unwrap().binding;
        Program {
            defs,
            adts: adts(),
            main,
            main_returns_result: false,
            lambda_count: 0,
        }
    }

    fn generate(p: &LowerProgram) -> CompiledProgram {
        match codegen(p, Arc::new(SourceTable::new())) {
            Ok(c) => c,
            Err(e) => panic!("codegen failed: {e:?}"),
        }
    }

    /// 一つの定義 `f` だけのプログラムを生成し、`f` の原型を返す。
    fn gen_one(params: Vec<Var>, body: LComp) -> (CompiledProgram, Proto) {
        let c = generate(&program(vec![user(1, "f", params, body)]));
        let p = c.protos[0].clone();
        (c, p)
    }

    /// 命令を (種類, A, B, C) の並びにする。跳ぶ命令の B・C は sBx の下位と上位である。
    fn ops(p: &Proto) -> Vec<(Opcode, u16, u16, u16)> {
        p.code
            .iter()
            .map(|i| (i.opcode().unwrap(), i.a(), i.b(), i.c()))
            .collect()
    }

    fn sbx(p: &Proto, pos: usize) -> i32 {
        p.code[pos].sbx()
    }

    fn opcodes(p: &Proto) -> Vec<Opcode> {
        p.code.iter().map(|i| i.opcode().unwrap()).collect()
    }

    fn const_of(p: &Proto, pos: usize) -> &ConstDesc {
        let i = p.code[pos];
        assert_eq!(i.opcode(), Some(O::LoadK));
        &p.consts[usize::try_from(i.bx()).unwrap()]
    }

    /// 演算子の表の行: 名前、組み込みの関数、型の引数、期待する命令、LOADK する定数。
    type OpCase = (
        &'static str,
        BuiltinId,
        Vec<Ty>,
        Vec<(Opcode, u16, u16, u16)>,
        Option<ConstDesc>,
    );

    fn n_var() -> Var {
        var(0, Ty::int())
    }

    // ---- 呼び出しと末尾位置 ----

    #[test]
    fn tail_call_becomes_tailcall_without_call_or_return() {
        // fn g(m) = return m; fn f(n) = g(n)
        let m = var(0, Ty::int());
        let n = n_var();
        let c = generate(&program(vec![
            user(2, "g", vec![m.clone()], ret(v(&m))),
            user(1, "f", vec![n.clone()], app(top(2), vec![v(&n)])),
        ]));
        let f = &c.protos[1];
        assert_eq!(
            ops(f),
            vec![
                (O::LoadK, 1, 0, 0),
                (O::Move, 2, 0, 0),
                (O::TailCall, 0, 1, 1)
            ]
        );
        assert_eq!(const_of(f, 0), &ConstDesc::Proto(ProtoIdx(0)));
        // 値を移す命令は値の由来位置、呼び出しの命令は適用の計算の由来位置を持つ
        assert_eq!(
            f.positions,
            vec![Some(span(1)), Some(span(1)), Some(span(2))]
        );
        assert_eq!(f.num_regs, 3);
        assert_eq!(f.num_params, 1);
    }

    #[test]
    fn non_tail_call_is_call_followed_by_return() {
        // let x ⇐ g(n) in return x
        let n = n_var();
        let x = var(1, Ty::int());
        let (_, f) = gen_one(
            vec![n.clone()],
            let_(&x, app(top(1), vec![v(&n)]), ret(v(&x))),
        );
        assert_eq!(
            ops(&f),
            vec![
                (O::LoadK, 2, 0, 0),
                (O::Move, 3, 0, 0),
                (O::Call, 1, 2, 1),
                (O::Return, 1, 0, 0),
            ]
        );
    }

    #[test]
    fn builtin_application_is_prim_or_io_then_return_in_tail_position() {
        let n = n_var();
        for (id, op) in [
            (BuiltinId::IntToString, O::Prim),
            (BuiltinId::ConsolePrintln, O::Io),
        ] {
            let (c, f) = gen_one(vec![n.clone()], app(builtin(id, vec![]), vec![v(&n)]));
            // 引数を R[1] に置き、結果を R[2] に入れて返す
            assert_eq!(
                ops(&f),
                vec![(O::Move, 1, 0, 0), (op, 2, 0, 1), (O::Return, 2, 0, 0)],
                "{id:?}"
            );
            assert_eq!(c.builtins, vec![id]);
            assert!(!opcodes(&f).contains(&O::Call) && !opcodes(&f).contains(&O::TailCall));
        }
    }

    // ---- 演算子 ----

    #[test]
    fn operators_map_to_dedicated_instructions() {
        let a = var(0, Ty::int());
        let b = var(1, Ty::int());
        let opt = Ty::option(Ty::int());
        let cases: Vec<OpCase> = vec![
            // > はオペランドを入れ替えた <
            (
                "gt",
                BuiltinId::GtInt,
                vec![],
                vec![(O::LtI, 2, 1, 0), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "ge",
                BuiltinId::GeFloat,
                vec![],
                vec![(O::LeF, 2, 1, 0), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "lt",
                BuiltinId::LtChar,
                vec![],
                vec![(O::LtC, 2, 0, 1), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "add",
                BuiltinId::ConcatString,
                vec![],
                vec![(O::Concat, 2, 0, 1), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "rem",
                BuiltinId::RemInt,
                vec![],
                vec![(O::ModI, 2, 0, 1), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "ne string",
                BuiltinId::Ne,
                vec![Ty::string()],
                vec![(O::EqS, 2, 0, 1), (O::Not, 2, 2, 0), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "eq unit",
                BuiltinId::Eq,
                vec![Ty::unit()],
                vec![(O::LoadK, 2, 0, 0), (O::Return, 2, 0, 0)],
                Some(ConstDesc::Bool(true)),
            ),
            (
                "ne unit",
                BuiltinId::Ne,
                vec![Ty::unit()],
                vec![(O::LoadK, 2, 0, 0), (O::Return, 2, 0, 0)],
                Some(ConstDesc::Bool(false)),
            ),
            (
                "eq option",
                BuiltinId::Eq,
                vec![opt.clone()],
                vec![(O::EqV, 2, 0, 1), (O::Return, 2, 0, 0)],
                None,
            ),
            (
                "eq list",
                BuiltinId::Eq,
                vec![Ty::list(Ty::int())],
                vec![(O::EqV, 2, 0, 1), (O::Return, 2, 0, 0)],
                None,
            ),
        ];
        for (name, id, tys, expected, konst) in cases {
            let (c, f) = gen_one(
                vec![a.clone(), b.clone()],
                app(builtin(id, tys), vec![v(&a), v(&b)]),
            );
            assert_eq!(ops(&f), expected, "{name}");
            if let Some(kd) = konst {
                assert_eq!(const_of(&f, 0), &kd, "{name}");
            }
            // 演算子は PRIM を使わないので、組み込みの関数の表に載らない
            assert!(c.builtins.is_empty(), "{name}");
        }

        // 単項の演算子と、非末尾位置で結果を変数のレジスタに入れる形
        let x = var(2, Ty::int());
        let (_, f) = gen_one(
            vec![a.clone()],
            let_(
                &x,
                app(builtin(BuiltinId::NegInt, vec![]), vec![v(&a)]),
                ret(v(&x)),
            ),
        );
        assert_eq!(ops(&f), vec![(O::NegI, 1, 0, 0), (O::Return, 1, 0, 0)]);
    }

    #[test]
    fn equality_on_a_non_equality_type_is_an_internal_error() {
        let a = var(0, Ty::int());
        let fn_ty = Ty::func(vec![], Ty::int(), EffectSet::empty());
        let p = program(vec![user(
            1,
            "f",
            vec![a.clone()],
            app(builtin(BuiltinId::Eq, vec![fn_ty]), vec![v(&a), v(&a)]),
        )]);
        match codegen(&p, Arc::new(SourceTable::new())) {
            Err(CodegenError::Internal(e)) => assert_eq!(e.stage, "codegen"),
            other => panic!("expected an internal error, got {other:?}"),
        }
    }

    // ---- 分岐と合流 ----

    #[test]
    fn non_tail_if_jumps_over_the_else_branch() {
        // let x ⇐ (if c then return 1 else return 2) in return x
        let c = var(0, Ty::bool());
        let x = var(1, Ty::int());
        let (_, f) = gen_one(
            vec![c.clone()],
            let_(&x, if_(v(&c), ret(int(1)), ret(int(2))), ret(v(&x))),
        );
        assert_eq!(
            opcodes(&f),
            vec![O::JmpF, O::LoadK, O::Jmp, O::LoadK, O::Return]
        );
        assert_eq!(f.code[0].a(), 0);
        assert_eq!(sbx(&f, 0), 2, "JMPF lands on the else branch");
        assert_eq!(sbx(&f, 2), 1, "JMP lands after the else branch");
        assert_eq!(const_of(&f, 1), &ConstDesc::Int(1));
        assert_eq!(const_of(&f, 3), &ConstDesc::Int(2));
        assert_eq!(f.code[1].a(), 1);
        assert_eq!(f.code[3].a(), 1);
    }

    #[test]
    fn tail_if_has_no_jump_after_the_then_branch() {
        // if c then g(1) else return 2
        let c = var(0, Ty::bool());
        let (_, f) = gen_one(
            vec![c.clone()],
            if_(v(&c), app(top(1), vec![int(1)]), ret(int(2))),
        );
        assert_eq!(
            opcodes(&f),
            vec![
                O::JmpF,
                O::LoadK,
                O::LoadK,
                O::TailCall,
                O::LoadK,
                O::Return
            ]
        );
        assert_eq!(sbx(&f, 0), 3);
    }

    #[test]
    fn join_places_the_shared_body_once_and_jumps_move_arguments() {
        // join k0(x) = return x in
        //   case o of { 0(y) ⇒ case y of { 0 ⇒ return 10 | _ ⇒ jump k0(o) } | _ ⇒ jump k0(o) }
        let o = var(0, Ty::option(Ty::int()));
        let x = var(1, Ty::option(Ty::int()));
        let y = var(2, Ty::int());
        let inner = comp(LCompKind::CaseConst {
            scrutinee: v(&y),
            arms: vec![ConstArm {
                value: Const::Int(0),
                body: ret(int(10)),
            }],
            default: Some(Box::new(jump(0, vec![v(&o)]))),
        });
        let body = comp(LCompKind::CaseCtor {
            scrutinee: v(&o),
            arms: vec![CtorArm {
                tag: 0,
                fields: vec![y.clone()],
                body: inner,
            }],
            default: Some(Box::new(jump(0, vec![v(&o)]))),
        });
        let (_, f) = gen_one(vec![o.clone()], join(0, vec![x.clone()], ret(v(&x)), body));
        assert_eq!(
            ops(&f)
                .into_iter()
                .map(|(op, a, b, c)| if matches!(op, O::Jmp | O::JmpF) {
                    (op, a, 0, 0)
                } else {
                    (op, a, b, c)
                })
                .collect::<Vec<_>>(),
            vec![
                (O::Switch, 0, 0, 0),
                (O::Field, 2, 0, 0),
                (O::LoadK, 3, 0, 0),
                (O::EqI, 3, 2, 3),
                (O::JmpF, 3, 0, 0),
                (O::LoadK, 3, 1, 0),
                (O::Return, 3, 0, 0),
                (O::Move, 1, 0, 0),
                (O::Jmp, 0, 0, 0),
                (O::Move, 1, 0, 0),
                (O::Jmp, 0, 0, 0),
                (O::Return, 1, 0, 0),
            ]
        );
        assert_eq!(sbx(&f, 4), 2);
        // 二つの jump は、どちらも Lk（位置 11）へ跳ぶ
        assert_eq!(sbx(&f, 8), 2);
        assert_eq!(sbx(&f, 10), 0);
        assert_eq!(
            f.switch_tables,
            vec![SwitchTable {
                targets: vec![Some(0), None],
                default: Some(8),
            }]
        );
    }

    #[test]
    fn non_tail_join_jumps_over_the_shared_body() {
        // let r ⇐ (join k0() = return 1 in if c then jump k0() else return 2) in return r
        let c = var(0, Ty::bool());
        let r = var(1, Ty::int());
        let j = join(
            0,
            vec![],
            ret(int(1)),
            if_(v(&c), jump(0, vec![]), ret(int(2))),
        );
        let (_, f) = gen_one(vec![c.clone()], let_(&r, j, ret(v(&r))));
        assert_eq!(
            opcodes(&f),
            vec![
                O::JmpF,
                O::Jmp,
                O::Jmp,
                O::LoadK,
                O::Jmp,
                O::LoadK,
                O::Return
            ]
        );
        // 0: JMPF →3（else）、1: jump →5（Lk）、2: if の JMP →4、3: LOADK 2、
        // 4: join の JMP →6（Lend）、5: Lk: LOADK 1、6: RETURN
        assert_eq!(sbx(&f, 0), 2, "JMPF lands on the else branch");
        assert_eq!(sbx(&f, 1), 3, "jump lands on Lk");
        assert_eq!(const_of(&f, 3), &ConstDesc::Int(2));
        assert_eq!(sbx(&f, 2), 1, "the if's JMP lands after the else branch");
        assert_eq!(sbx(&f, 4), 1, "JMP →Lend skips the shared body");
        assert_eq!(const_of(&f, 5), &ConstDesc::Int(1));
        assert_eq!(f.code[3].a(), 1);
        assert_eq!(f.code[5].a(), 1);
    }

    #[test]
    fn jump_arguments_that_read_parameter_registers_go_through_temporaries() {
        // join k0(x, y) = (if x then return y else jump k0(y, x)) in jump k0(c, d)
        let c = var(0, Ty::bool());
        let d = var(1, Ty::bool());
        let x = var(2, Ty::bool());
        let y = var(3, Ty::bool());
        let handler = if_(v(&x), ret(v(&y)), jump(0, vec![v(&y), v(&x)]));
        let body = jump(0, vec![v(&c), v(&d)]);
        let (_, f) = gen_one(
            vec![c.clone(), d.clone()],
            join(0, vec![x.clone(), y.clone()], handler, body),
        );
        // x は R2、y は R3。入れ替えの jump は R4・R5 を経由する
        assert_eq!(
            ops(&f)[..8].to_vec(),
            vec![
                (O::Move, 2, 0, 0),
                (O::Move, 3, 1, 0),
                (O::Jmp, 0, 0, 0),
                (O::JmpF, 2, 1, 0),
                (O::Return, 3, 0, 0),
                (O::Move, 4, 3, 0),
                (O::Move, 5, 2, 0),
                (O::Move, 2, 4, 0),
            ]
        );
        assert_eq!(ops(&f)[8], (O::Move, 3, 5, 0));
        assert_eq!(f.code[9].opcode(), Some(O::Jmp));
        assert_eq!(sbx(&f, 2), 0, "the first jump lands on Lk right after it");
        assert_eq!(sbx(&f, 9), -7, "the jump in the handler goes back to Lk");
    }

    #[test]
    fn constructor_case_uses_switch_and_field() {
        // case t of { 0 ⇒ return 0 | 1(l, n, r) ⇒ return n }
        let t = var(0, Ty::con(TREE));
        let l = var(1, Ty::con(TREE));
        let n = var(2, Ty::int());
        let r = var(3, Ty::con(TREE));
        let case = || {
            comp(LCompKind::CaseCtor {
                scrutinee: v(&t),
                arms: vec![
                    CtorArm {
                        tag: 0,
                        fields: vec![],
                        body: ret(int(0)),
                    },
                    CtorArm {
                        tag: 1,
                        fields: vec![l.clone(), n.clone(), r.clone()],
                        body: ret(v(&n)),
                    },
                ],
                default: None,
            })
        };
        let (_, f) = gen_one(vec![t.clone()], case());
        assert_eq!(
            ops(&f),
            vec![
                (O::Switch, 0, 0, 0),
                (O::LoadK, 1, 0, 0),
                (O::Return, 1, 0, 0),
                (O::Field, 1, 0, 0),
                (O::Field, 2, 0, 1),
                (O::Field, 3, 0, 2),
                (O::Return, 2, 0, 0),
            ]
        );
        assert_eq!(
            f.switch_tables,
            vec![SwitchTable {
                targets: vec![Some(0), Some(2)],
                default: None,
            }]
        );

        // 末尾位置でなければ、最後の分岐を除く各分岐の後に case の終わりへの JMP を置く
        let z = var(4, Ty::int());
        let (_, f) = gen_one(vec![t.clone()], let_(&z, case(), ret(v(&z))));
        assert_eq!(
            opcodes(&f),
            vec![
                O::Switch,
                O::LoadK,
                O::Jmp,
                O::Field,
                O::Field,
                O::Field,
                O::Move,
                O::Return
            ]
        );
        assert_eq!(sbx(&f, 2), 4, "JMP lands after the last arm");
        assert_eq!(f.switch_tables[0].targets, vec![Some(0), Some(2)]);
        assert_eq!(ops(&f)[6], (O::Move, 1, 3, 0));
    }

    #[test]
    fn constant_case_compares_each_constant_in_turn() {
        let s = var(0, Ty::string());
        let str_k = |t: &str| Const::Str(t.to_string());
        let arm = |value: Const, n: i64| ConstArm {
            value,
            body: ret(int(n)),
        };
        // String: 定数ごとに LOADK・EQS・JMPF
        let (_, f) = gen_one(
            vec![s.clone()],
            comp(LCompKind::CaseConst {
                scrutinee: v(&s),
                arms: vec![arm(str_k("a"), 1), arm(str_k("b"), 2)],
                default: Some(Box::new(ret(int(3)))),
            }),
        );
        assert_eq!(
            ops(&f)
                .into_iter()
                .map(|(op, a, b, c)| if op == O::JmpF {
                    (op, a, 0, 0)
                } else {
                    (op, a, b, c)
                })
                .collect::<Vec<_>>(),
            vec![
                (O::LoadK, 1, 0, 0),
                (O::EqS, 1, 0, 1),
                (O::JmpF, 1, 0, 0),
                (O::LoadK, 1, 1, 0),
                (O::Return, 1, 0, 0),
                (O::LoadK, 1, 2, 0),
                (O::EqS, 1, 0, 1),
                (O::JmpF, 1, 0, 0),
                (O::LoadK, 1, 3, 0),
                (O::Return, 1, 0, 0),
                (O::LoadK, 1, 4, 0),
                (O::Return, 1, 0, 0),
            ]
        );
        assert_eq!(sbx(&f, 2), 2);
        assert_eq!(sbx(&f, 7), 2);
        assert_eq!(f.consts[0], ConstDesc::Str("a".to_string()));
        assert_eq!(f.consts[2], ConstDesc::Str("b".to_string()));

        // 末尾位置でなければ、比べた分岐の後に case の終わりへの JMP を置く
        // （let z ⇐ case s of { "a" ⇒ 1 | "b" ⇒ 2 | _ ⇒ 3 } in return z）
        let z = var(1, Ty::int());
        let (_, f) = gen_one(
            vec![s.clone()],
            let_(
                &z,
                comp(LCompKind::CaseConst {
                    scrutinee: v(&s),
                    arms: vec![arm(str_k("a"), 1), arm(str_k("b"), 2)],
                    default: Some(Box::new(ret(int(3)))),
                }),
                ret(v(&z)),
            ),
        );
        assert_eq!(
            opcodes(&f),
            vec![
                O::LoadK,
                O::EqS,
                O::JmpF,
                O::LoadK,
                O::Jmp,
                O::LoadK,
                O::EqS,
                O::JmpF,
                O::LoadK,
                O::Jmp,
                O::LoadK,
                O::Return
            ]
        );
        // 分岐の結果は z のレジスタ（R1）に入り、比べる定数は一時的なレジスタ（R2）に置く
        assert_eq!(ops(&f)[1], (O::EqS, 2, 0, 2));
        assert_eq!([3, 8, 10].map(|i| f.code[i].a()), [1, 1, 1]);
        assert_eq!(sbx(&f, 2), 2, "JMPF lands on the next comparison");
        assert_eq!(sbx(&f, 7), 2, "JMPF lands on the default arm");
        assert_eq!(sbx(&f, 4), 6, "JMP lands after the case");
        assert_eq!(sbx(&f, 9), 1, "JMP lands after the case");
        assert_eq!(ops(&f)[11], (O::Return, 1, 0, 0));

        // Bool の二値をすべて並べ default がないときは、最後の分岐を比べない
        let b = var(0, Ty::bool());
        let (_, f) = gen_one(
            vec![b.clone()],
            comp(LCompKind::CaseConst {
                scrutinee: v(&b),
                arms: vec![arm(Const::Bool(true), 1), arm(Const::Bool(false), 2)],
                default: None,
            }),
        );
        assert_eq!(
            opcodes(&f),
            vec![
                O::LoadK,
                O::EqB,
                O::JmpF,
                O::LoadK,
                O::Return,
                O::LoadK,
                O::Return
            ]
        );

        // Unit の定数は比べない
        let u = var(0, Ty::unit());
        let (_, f) = gen_one(
            vec![u.clone()],
            comp(LCompKind::CaseConst {
                scrutinee: v(&u),
                arms: vec![arm(Const::Unit, 1)],
                default: None,
            }),
        );
        assert_eq!(opcodes(&f), vec![O::LoadK, O::Return]);
    }

    // ---- 値 ----

    #[test]
    fn nested_lambdas_capture_from_register_then_from_capture() {
        // fn f(a) = return λ(x). return λ(y). return a
        let a = var(0, Ty::int());
        let x = var(1, Ty::int());
        let y = var(2, Ty::int());
        let inner = lambda(1, vec![y.clone()], ret(v(&a)), 30);
        let outer = lambda(0, vec![x.clone()], ret(inner), 20);
        let (c, f) = gen_one(vec![a.clone()], ret(outer));
        assert_eq!(ops(&f), vec![(O::Closure, 1, 1, 0), (O::Return, 1, 0, 0)]);
        // ラムダの原型は、出会った順に定義の原型の後ろに並ぶ
        let outer_p = &c.protos[1];
        let inner_p = &c.protos[2];
        assert_eq!(outer_p.captures, vec![CaptureSource::Reg(0)]);
        assert_eq!(
            ops(outer_p),
            vec![(O::Closure, 1, 2, 0), (O::Return, 1, 0, 0)]
        );
        assert_eq!(inner_p.captures, vec![CaptureSource::Capture(0)]);
        assert_eq!(
            ops(inner_p),
            vec![(O::GetCap, 1, 0, 0), (O::Return, 1, 0, 0)]
        );
        assert_eq!(inner_p.num_params, 1);
        for (p, at) in [(outer_p, 20), (inner_p, 30)] {
            assert_eq!(p.origin, ProtoOrigin::UserLambda);
            assert_eq!(p.name, "<lambda>");
            assert_eq!(p.lambda_span, Some(span(at)));
        }
    }

    #[test]
    fn builtin_used_as_value_shares_one_prototype() {
        let (c, f) = gen_one(
            vec![],
            ret(list(vec![
                builtin(BuiltinId::IntToString, vec![]),
                builtin(BuiltinId::IntToString, vec![]),
                builtin(BuiltinId::ProcessArgs, vec![]),
            ])),
        );
        assert_eq!(c.protos.len(), 3);
        assert_eq!(
            f.consts,
            vec![ConstDesc::Proto(ProtoIdx(1)), ConstDesc::Proto(ProtoIdx(2))]
        );
        let to_string = &c.protos[1];
        assert_eq!(to_string.origin, ProtoOrigin::BuiltinValue);
        assert_eq!(to_string.name, "Int.toString");
        assert_eq!(to_string.positions, vec![None, None]);
        assert_eq!(
            ops(to_string),
            vec![(O::Prim, 0, 0, 0), (O::Return, 0, 0, 0)]
        );
        assert_eq!((to_string.num_params, to_string.num_regs), (1, 1));
        // 引数のない IO の関数も、結果を入れるレジスタを一つ持つ
        let args = &c.protos[2];
        assert_eq!(args.name, "Process.args");
        assert_eq!(ops(args), vec![(O::Io, 0, 1, 0), (O::Return, 0, 0, 0)]);
        assert_eq!((args.num_params, args.num_regs), (0, 1));
        assert_eq!(
            c.builtins,
            vec![BuiltinId::IntToString, BuiltinId::ProcessArgs]
        );
    }

    #[test]
    fn equal_constants_share_one_entry() {
        let fl = |x: f64| k(Const::Float(x));
        let s = || k(Const::Str("s".to_string()));
        let (_, f) = gen_one(
            vec![],
            ret(list(vec![
                s(),
                s(),
                fl(0.0),
                fl(-0.0),
                fl(f64::NAN),
                fl(f64::NAN),
                fl(0.0),
            ])),
        );
        // NaN どうしは一つにまとめ、0.0 と -0.0 は分ける
        let bits: Vec<Option<u64>> = f
            .consts
            .iter()
            .map(|c| {
                if let ConstDesc::Float(x) = c {
                    Some(x.to_bits())
                } else {
                    None
                }
            })
            .collect();
        assert_eq!(f.consts.len(), 4);
        assert_eq!(f.consts[0], ConstDesc::Str("s".to_string()));
        assert_eq!(
            bits[1..].to_vec(),
            vec![
                Some(0.0f64.to_bits()),
                Some((-0.0f64).to_bits()),
                Some(f64::NAN.to_bits())
            ]
        );
    }

    #[test]
    fn constructors_use_con_and_nullary_ones_use_loadk() {
        // return Some(Node(Leaf, n, Leaf))
        let n = n_var();
        let leaf = || {
            val(
                ValKind::Ctor {
                    con: TREE,
                    tag: 0,
                    tys: vec![],
                    args: vec![],
                },
                Ty::con(TREE),
            )
        };
        let node = val(
            ValKind::Ctor {
                con: TREE,
                tag: 1,
                tys: vec![],
                args: vec![leaf(), v(&n), leaf()],
            },
            Ty::con(TREE),
        );
        let some = val(
            ValKind::Ctor {
                con: TyCon::Option,
                tag: 0,
                tys: vec![Ty::con(TREE)],
                args: vec![node],
            },
            Ty::option(Ty::con(TREE)),
        );
        let (c, f) = gen_one(vec![n.clone()], ret(some));
        assert_eq!(
            ops(&f),
            vec![
                (O::LoadK, 3, 0, 0),
                (O::Move, 4, 0, 0),
                (O::LoadK, 5, 0, 0),
                (O::Con, 2, 0, 3),
                (O::Con, 1, 1, 2),
                (O::Return, 1, 0, 0),
            ]
        );
        assert_eq!(f.consts, vec![ConstDesc::NullaryCtor { tag: 0 }]);
        assert_eq!(
            c.ctors,
            vec![
                CtorInfo {
                    type_name: "Tree".to_string(),
                    ctor_name: "Node".to_string(),
                    tag: 1,
                    arity: 3,
                },
                CtorInfo {
                    type_name: "Option".to_string(),
                    ctor_name: "Some".to_string(),
                    tag: 0,
                    arity: 1,
                },
            ]
        );
    }

    // ---- 原型の表 ----

    #[test]
    fn prototype_table_follows_definition_order_and_origin_kinds() {
        let x = var(0, Ty::int());
        let y = var(1, Ty::int());
        let defs = vec![
            def(
                10,
                "List.map",
                DefOrigin::PreludePublic {
                    module: PreludeModule::List,
                },
                vec![],
                ret(lambda(0, vec![x.clone()], ret(v(&x)), 40)),
            ),
            def(11, "go", DefOrigin::PreludeHelper, vec![], ret(int(0))),
            user(
                12,
                "main",
                vec![],
                ret(lambda(1, vec![y.clone()], ret(v(&y)), 50)),
            ),
        ];
        let mut p = program(defs);
        p.main_returns_result = true;
        let c = generate(&p);
        let summary: Vec<(ProtoOrigin, &str, Option<Span>)> = c
            .protos
            .iter()
            .map(|p| (p.origin, p.name.as_str(), p.lambda_span))
            .collect();
        assert_eq!(
            summary,
            vec![
                (ProtoOrigin::PreludePublic, "List.map", None),
                (ProtoOrigin::PreludeHelper, "go", None),
                (ProtoOrigin::UserFn, "main", None),
                // prelude のソースの中のラムダは補助の関数として扱う
                (ProtoOrigin::PreludeHelper, "<lambda>", None),
                (ProtoOrigin::UserLambda, "<lambda>", Some(span(50))),
            ]
        );
        assert_eq!(
            c.top_fns,
            vec![
                (BindingId(10), ProtoIdx(0)),
                (BindingId(11), ProtoIdx(1)),
                (BindingId(12), ProtoIdx(2)),
            ]
        );
        assert_eq!(c.main, ProtoIdx(2));
        assert_eq!(c.main_kind, MainKind::Result);
        for p in &c.protos {
            assert_eq!(p.positions.len(), p.code.len());
        }
    }

    #[test]
    fn deep_nesting_at_the_parser_limit_is_generated() {
        // 構文解析器の入れ子の上限（1000）程度の深さ: let の連なりと、非末尾位置の if の入れ子
        let depth = 1000u32;
        let c = var(0, Ty::bool());
        let mut ifs = ret(int(0));
        for i in 0..depth {
            ifs = if_(v(&c), ifs, ret(int(i64::from(i))));
        }
        let vars: Vec<Var> = (1..=depth).map(|i| var(i, Ty::int())).collect();
        let mut body = ret(v(&vars[0]));
        for x in vars.iter().rev() {
            body = let_(x, ret(int(1)), body);
        }
        let r = var(depth + 1, Ty::int());
        let (_, f) = gen_one(vec![c.clone()], let_(&r, ifs, body));
        // if は分岐ごとに結果のレジスタを使い回すので、レジスタは c・r と let の変数の分だけ
        assert_eq!(u32::from(f.num_regs), depth + 2);
        assert_eq!(
            opcodes(&f).iter().filter(|op| **op == O::JmpF).count(),
            usize::try_from(depth).unwrap()
        );
    }

    #[test]
    fn deep_cases_joins_and_lambdas_are_generated() {
        let depth = 1000u32;
        // join k0() = return 0 in case o0 of { 0(o1) ⇒ case o1 of { … ⇒ return 1 } | _ ⇒ jump k0() }
        let opt = || Ty::option(Ty::int());
        let os: Vec<Var> = (0..=depth).map(|i| var(i, opt())).collect();
        let mut cases = ret(int(1));
        for i in (0..depth as usize).rev() {
            cases = comp(LCompKind::CaseCtor {
                scrutinee: v(&os[i]),
                arms: vec![CtorArm {
                    tag: 0,
                    fields: vec![os[i + 1].clone()],
                    body: cases,
                }],
                default: Some(Box::new(jump(0, vec![]))),
            });
        }
        let matcher = user(
            1,
            "matcher",
            vec![os[0].clone()],
            join(0, vec![], ret(int(0)), cases),
        );
        // λ(). λ(). … return a（最も内側まで a を捕捉し続ける）
        let a = var(0, Ty::int());
        let mut lam = ret(v(&a));
        for i in 0..depth {
            lam = ret(lambda(i, vec![], lam, 0));
        }
        let lambdas = user(2, "lambdas", vec![a.clone()], lam);
        let c = generate(&program(vec![matcher, lambdas]));
        assert_eq!(
            c.protos[0].switch_tables.len(),
            usize::try_from(depth).unwrap()
        );
        assert_eq!(c.protos.len(), 2 + usize::try_from(depth).unwrap());
        let innermost = c.protos.last().unwrap();
        assert_eq!(innermost.captures, vec![CaptureSource::Capture(0)]);
        assert_eq!(
            ops(innermost),
            vec![(O::GetCap, 0, 0, 0), (O::Return, 0, 0, 0)]
        );
    }

    // ---- 処理系の制限 ----

    fn limit_diags(p: &LowerProgram) -> Vec<Diagnostic> {
        match codegen(p, Arc::new(SourceTable::new())) {
            Err(CodegenError::Limit(d)) => d,
            other => panic!("expected a limit error, got {other:?}"),
        }
    }

    #[test]
    fn too_many_registers_is_l0101_only() {
        // 同じ定数の 70,000 個の要素は、定数表では一つだが、レジスタを 70,000 個使う
        let items = (0..70_000).map(|_| int(7)).collect();
        let d = limit_diags(&program(vec![
            user(1, "fine", vec![], ret(int(0))),
            user(2, "big", vec![], ret(list(items))),
        ]));
        assert_eq!(d.len(), 1);
        assert_eq!(d[0].code, Some(DiagCode::L0101));
        assert_eq!(d[0].message, "the function `big` needs too many registers");
        assert_eq!(d[0].primary.as_ref().map(|l| l.span), Some(span(102)));
        assert_eq!(d[0].notes.len(), 1);
    }

    #[test]
    fn constructor_with_too_many_fields_is_l0101() {
        // 引数が 70,000 個の構成子を作る関数と、それで分岐する関数。どちらもレジスタの上限を超える
        const BIG: TyCon = TyCon::Adt(BindingId(300));
        let n = 70_000u32;
        let x = var(0, Ty::con(BIG));
        let fields: Vec<Var> = (1..=n).map(|i| var(i, Ty::int())).collect();
        let make = user(
            1,
            "make",
            vec![],
            ret(val(
                ValKind::Ctor {
                    con: BIG,
                    tag: 0,
                    tys: vec![],
                    args: (0..n).map(|_| int(0)).collect(),
                },
                Ty::con(BIG),
            )),
        );
        let take = user(
            2,
            "take",
            vec![x.clone()],
            comp(LCompKind::CaseCtor {
                scrutinee: v(&x),
                arms: vec![CtorArm {
                    tag: 0,
                    fields,
                    body: ret(int(0)),
                }],
                default: None,
            }),
        );
        let mut p = program(vec![make, take]);
        p.adts.adts.push(AdtDef {
            con: BIG,
            name: "Big".to_string(),
            type_params: Vec::new(),
            ctors: vec![CtorDef {
                name: "Big".to_string(),
                binding: BindingId(301),
                tag: 0,
                fields: vec![Ty::int(); usize::try_from(n).unwrap()],
            }],
            eq_summary: EqSummary::default(),
        });
        let d = limit_diags(&p);
        let got: Vec<(Option<DiagCode>, &str)> =
            d.iter().map(|d| (d.code, d.message.as_str())).collect();
        assert_eq!(
            got,
            vec![
                (
                    Some(DiagCode::L0101),
                    "the function `make` needs too many registers"
                ),
                (
                    Some(DiagCode::L0101),
                    "the function `take` needs too many registers"
                ),
            ]
        );
    }

    #[test]
    fn too_many_constants_reports_both_limits_with_the_enclosing_definition_name() {
        // ラムダの中の制限は、それを含む定義の名前で報告する
        let items = (0..70_000).map(int).collect();
        let d = limit_diags(&program(vec![user(
            3,
            "big",
            vec![],
            ret(lambda(0, vec![], ret(list(items)), 60)),
        )]));
        let codes: Vec<Option<DiagCode>> = d.iter().map(|d| d.code).collect();
        assert_eq!(codes, vec![Some(DiagCode::L0101), Some(DiagCode::L0102)]);
        assert_eq!(d[1].message, "the function `big` has too many constants");
        assert!(
            d.iter()
                .all(|d| d.primary.as_ref().map(|l| l.span) == Some(span(103)))
        );
    }
}
