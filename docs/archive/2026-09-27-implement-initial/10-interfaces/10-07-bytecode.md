# バイトコード

本章は、命令の符号化（命令の種類の番号）、分岐表の形、関数の原型、定数の記述、コンパイル済みプログラム、コード生成の関数のシグネチャを定める。設計書の対応する章は[バイトコードとコード生成](../../2026-09-27-design-initial/02-impl/02-07-bytecode.md)であり、02-07 が「実装プランで定める」とした命令の種類ごとの番号と分岐表の形を、本章で決める。

## 命令の符号化

命令は 64 ビットの固定長である（02-07「レジスタ型の命令」）。ビットの割り当ては次のとおりとする。

| ビット | 内容 |
|---|---|
| 0〜7 | 命令の種類（`Opcode` の番号） |
| 8〜23 | オペランド A |
| 24〜39 | オペランド B |
| 40〜55 | オペランド C |
| 56〜63 | 使わない（0） |

Bx は B を下位、C を上位とする 32 ビットの符号なし整数、sBx は同じ 32 ビットを 2 の補数で読んだ符号付き整数である。跳ぶ先の相対位置 sBx は、跳ぶ命令の次の命令の位置からの距離である（`JMP 0` は何もしない）。

命令の種類の番号は、分類ごとに区切って振る。番号は、処理系の外に出さない（コンパイル済みプログラムをファイルに保存しない。02-01）ので、後で振り直してもよい。

| 番号 | 命令 | 番号 | 命令 | 番号 | 命令 |
|---|---|---|---|---|---|
| 0 | `MOVE A B` | 24 | `ADDF` | 40 | `LES` |
| 1 | `LOADK A Bx` | 25 | `SUBF` | 41 | `EQC` |
| 2 | `GETCAP A B` | 26 | `MULF` | 42 | `LTC` |
| 3 | `CLOSURE A Bx` | 27 | `DIVF` | 43 | `LEC` |
| 4 | `CALL A B C` | 28 | `NEGF A B` | 44 | `EQB` |
| 5 | `TAILCALL B C`（A は使わない） | 30 | `CONCAT` | 45 | `EQV` |
| 6 | `RETURN A` | 32 | `EQI` | 46 | `NOT A B` |
| 7 | `PRIM A B C` | 33 | `LTI` | 48 | `CON A B C` |
| 8 | `IO A B C` | 34 | `LEI` | 49 | `LIST A B C` |
| 16 | `ADDI` | 35 | `EQF` | 50 | `FIELD A B C` |
| 17 | `SUBI` | 36 | `LTF` | 56 | `JMP sBx`（A は使わない） |
| 18 | `MULI` | 37 | `LEF` | 57 | `JMPF A sBx` |
| 19 | `DIVI` | 38 | `EQS` | 58 | `SWITCH A Bx` |
| 20 | `MODI` | 39 | `LTS` | | |
| 21 | `NEGI A B` | | | | |

表で形を書いていない演算と比較の命令は `A B C` の形で、`R[A] ← R[B] ⊕ R[C]` である（02-07「命令」）。

オペランドの意味で、02-07 の表に加えて本章で決めるものは次のとおりである。

- `PRIM A B C`・`IO A B C` の B は、コンパイル済みプログラムの組み込みの関数の参照（`builtins`）の番号である。引数の数は組み込みの表の型の引数の数による。
- `CON A B C` の B は、コンパイル済みプログラムの構成子の表（`ctors`）の番号である。引数の数は構成子の表の `arity` による。`arity` が 0 の構成子は `CON` を使わず `LOADK` で作る（02-07「値の移し方」）。
- `FIELD A B C` の C は、0 から数えた構成子の引数の位置である。
- `LOADK A Bx` の Bx は原型の定数表の番号であり、16 ビットに収める（02-07「処理系の制限」。超えたら L0102）。`SWITCH A Bx` の Bx は原型の分岐表の並びの番号、`CLOSURE A Bx` の Bx は原型の表の番号であり、どちらも 32 ビットの Bx をそのまま使う（02-07「処理系の制限」は分岐表の番号を挙げていないので、上限を設けない）。
- レジスタの数は `u16` で持つので、一つの原型のレジスタは 65535 個までである。これを超えるとき L0101 とする。`CALL`・`LIST` などの C が表す個数は、同時に使うレジスタの数を超えないので、L0101 の検査を通れば 16 ビットに収まる。

```rust file=src/bytecode/instr.rs
//! 命令の符号化（本章「命令の符号化」）。

/// 命令の種類。番号は本章の表のとおり。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
#[repr(u8)]
pub enum Opcode {
    Move = 0,
    LoadK = 1,
    GetCap = 2,
    Closure = 3,
    Call = 4,
    TailCall = 5,
    Return = 6,
    Prim = 7,
    Io = 8,
    AddI = 16,
    SubI = 17,
    MulI = 18,
    DivI = 19,
    ModI = 20,
    NegI = 21,
    AddF = 24,
    SubF = 25,
    MulF = 26,
    DivF = 27,
    NegF = 28,
    Concat = 30,
    EqI = 32,
    LtI = 33,
    LeI = 34,
    EqF = 35,
    LtF = 36,
    LeF = 37,
    EqS = 38,
    LtS = 39,
    LeS = 40,
    EqC = 41,
    LtC = 42,
    LeC = 43,
    EqB = 44,
    EqV = 45,
    Not = 46,
    Con = 48,
    List = 49,
    Field = 50,
    Jmp = 56,
    JmpF = 57,
    Switch = 58,
}

impl Opcode {
    pub fn from_u8(n: u8) -> Option<Opcode> {
        let op = match n {
            0 => Opcode::Move,
            1 => Opcode::LoadK,
            2 => Opcode::GetCap,
            3 => Opcode::Closure,
            4 => Opcode::Call,
            5 => Opcode::TailCall,
            6 => Opcode::Return,
            7 => Opcode::Prim,
            8 => Opcode::Io,
            16 => Opcode::AddI,
            17 => Opcode::SubI,
            18 => Opcode::MulI,
            19 => Opcode::DivI,
            20 => Opcode::ModI,
            21 => Opcode::NegI,
            24 => Opcode::AddF,
            25 => Opcode::SubF,
            26 => Opcode::MulF,
            27 => Opcode::DivF,
            28 => Opcode::NegF,
            30 => Opcode::Concat,
            32 => Opcode::EqI,
            33 => Opcode::LtI,
            34 => Opcode::LeI,
            35 => Opcode::EqF,
            36 => Opcode::LtF,
            37 => Opcode::LeF,
            38 => Opcode::EqS,
            39 => Opcode::LtS,
            40 => Opcode::LeS,
            41 => Opcode::EqC,
            42 => Opcode::LtC,
            43 => Opcode::LeC,
            44 => Opcode::EqB,
            45 => Opcode::EqV,
            46 => Opcode::Not,
            48 => Opcode::Con,
            49 => Opcode::List,
            50 => Opcode::Field,
            56 => Opcode::Jmp,
            57 => Opcode::JmpF,
            58 => Opcode::Switch,
            _ => return None,
        };
        Some(op)
    }
}

/// 64 ビットの命令。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct Instr(pub u64);

impl Instr {
    pub fn abc(op: Opcode, a: u16, b: u16, c: u16) -> Instr {
        Instr(
            u64::from(op as u8) | (u64::from(a) << 8) | (u64::from(b) << 24) | (u64::from(c) << 40),
        )
    }

    pub fn abx(op: Opcode, a: u16, bx: u32) -> Instr {
        Instr(u64::from(op as u8) | (u64::from(a) << 8) | (u64::from(bx) << 24))
    }

    pub fn asbx(op: Opcode, a: u16, sbx: i32) -> Instr {
        Instr::abx(op, a, u32::from_ne_bytes(sbx.to_ne_bytes()))
    }

    /// 命令の種類。知らない番号なら `None`（処理系の不具合）。
    pub fn opcode(self) -> Option<Opcode> {
        Opcode::from_u8((self.0 & 0xff) as u8)
    }

    pub fn a(self) -> u16 {
        ((self.0 >> 8) & 0xffff) as u16
    }

    pub fn b(self) -> u16 {
        ((self.0 >> 24) & 0xffff) as u16
    }

    pub fn c(self) -> u16 {
        ((self.0 >> 40) & 0xffff) as u16
    }

    pub fn bx(self) -> u32 {
        ((self.0 >> 24) & 0xffff_ffff) as u32
    }

    pub fn sbx(self) -> i32 {
        i32::from_ne_bytes(self.bx().to_ne_bytes())
    }
}
```

`as` による数値の変換は、上の符号化の関数の中だけで使う。いずれも、マスクした後の値を、それが収まる幅の型に移すものである。

## 関数の原型とコンパイル済みプログラム

02-07「コンパイル済みプログラム」の要素を構造体の欄にする。コンパイル済みプログラムは、生成の後に変更せず、スレッドの間で共有できる（`Send` と `Sync` を満たす）。これをコンパイルの時点で確かめる関数を置く。

分岐表 `SwitchTable` は、タグを添字とする跳ぶ先の並びと、表にないタグのときの跳ぶ先を持つ。跳ぶ先は、`SWITCH` の次の命令の位置からの相対位置である（02-07）。`_` の分岐がない `case`（すべての構成子を並べた `case`）では、`default` に `None` を入れる。VM は、`targets` にないタグで `default` が `None` なら、処理系の不具合として止まる。

定数から作った値を使い回すかは、02-07 が実装プランに委ねた。本プランでは、`String` の定数と関数の原型の定数から作った値を、実行ごとの表に取っておいて使い回す（[実行時の値](10-08-runtime.md)の `Vm` の `const_cache`）。そのほかの定数はヒープを確保しないので、`LOADK` のたびに作る。

```rust file=src/bytecode/program.rs
//! 関数の原型とコンパイル済みプログラム（設計書 02-07「コンパイル済みプログラム」）。

use std::sync::Arc;

use crate::base::{BindingId, SourceTable, Span};
use crate::builtins::BuiltinId;

use super::instr::Instr;

/// 原型の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ProtoIdx(pub u32);

/// 原型の由来の種類（02-07「原型の名前と由来の種類」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ProtoOrigin {
    UserFn,
    UserLambda,
    PreludePublic,
    /// prelude の補助の関数と、prelude のソースの中のラムダ。呼び出しの履歴に示さない
    PreludeHelper,
    /// 値として使う組み込みの関数
    BuiltinValue,
}

/// 捕捉する値の取り方（02-07「関数の値と捕捉」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum CaptureSource {
    /// 作る側の関数のレジスタ
    Reg(u16),
    /// 作る側の関数が捕捉した値
    Capture(u16),
}

/// 定数の記述（02-07「値の移し方」、ADR 0083）。実行中の値そのものは置かない。
#[derive(Clone, PartialEq, Debug)]
pub enum ConstDesc {
    Int(i64),
    Float(f64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    /// 引数のない構成子。タグだけで値が決まる
    NullaryCtor {
        tag: u32,
    },
    /// 何も捕捉しない関数の原型
    Proto(ProtoIdx),
}

/// `SWITCH` の分岐表。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct SwitchTable {
    /// タグを添字とする跳ぶ先。そのタグの分岐がなければ `None`
    pub targets: Vec<Option<i32>>,
    /// 表にないタグのときの跳ぶ先（`_` の分岐）
    pub default: Option<i32>,
}

/// 関数の原型。
#[derive(Clone, PartialEq, Debug)]
pub struct Proto {
    pub name: String,
    pub origin: ProtoOrigin,
    /// 利用者のラムダでは、ラムダを書いた位置（`<lambda ファイル:行:列>` の表示に使う）
    pub lambda_span: Option<Span>,
    pub code: Vec<Instr>,
    pub consts: Vec<ConstDesc>,
    pub switch_tables: Vec<SwitchTable>,
    pub num_regs: u16,
    pub num_params: u16,
    pub captures: Vec<CaptureSource>,
    /// 命令ごとの由来位置。`code` と同じ長さ。値として使う組み込みの関数の原型では `None`
    pub positions: Vec<Option<Span>>,
}

/// 構成子の表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CtorInfo {
    pub type_name: String,
    pub ctor_name: String,
    pub tag: u32,
    pub arity: u16,
}

/// `main` の戻り値の型。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum MainKind {
    Unit,
    /// `Result[Unit, String]`
    Result,
}

/// コンパイル済みプログラム。
#[derive(Debug)]
pub struct CompiledProgram {
    pub protos: Vec<Proto>,
    /// トップレベルの関数と prelude のソースの関数から、原型への対応（束縛の番号で引く）
    pub top_fns: Vec<(BindingId, ProtoIdx)>,
    pub ctors: Vec<CtorInfo>,
    /// `PRIM`・`IO` の B が指す組み込みの関数
    pub builtins: Vec<BuiltinId>,
    pub main: ProtoIdx,
    pub main_kind: MainKind,
    pub sources: Arc<SourceTable>,
}

impl CompiledProgram {
    pub fn proto(&self, idx: ProtoIdx) -> Option<&Proto> {
        usize::try_from(idx.0).ok().and_then(|i| self.protos.get(i))
    }
}

/// コンパイル済みプログラムがスレッドの間で共有できることを、コンパイルの時点で確かめる（ADR 0015）。
#[allow(dead_code)]
fn assert_shareable() {
    fn check<T: Send + Sync>() {}
    check::<CompiledProgram>();
}
```

## コード生成

```rust file=src/bytecode/mod.rs
//! バイトコードとコード生成（設計書 02-07）。

pub mod codegen;
pub mod disasm;
pub mod instr;
pub mod program;
```

```rust sig=src/bytecode/codegen.rs
use std::sync::Arc;

use crate::base::SourceTable;
use crate::diag::Diagnostic;
use crate::ir::InternalError;
use crate::ir::lower_ir::LowerProgram;
use super::program::CompiledProgram;

/// コード生成の失敗。
#[derive(Debug)]
pub enum CodegenError {
    /// 処理系の制限（L0101・L0102）。制限に当たった関数ごとに一つ
    Limit(Vec<Diagnostic>),
    Internal(InternalError),
}

/// 下位 IR からコンパイル済みプログラムを作る（02-07「コード生成」）。
pub fn codegen(program: &LowerProgram, sources: Arc<SourceTable>) -> Result<CompiledProgram, CodegenError>;
```

逆アセンブラは、テストの失敗を調べるときと、設計者が生成したコードを読むときに使う。

```rust sig=src/bytecode/disasm.rs
use super::program::CompiledProgram;

/// コンパイル済みプログラムを、原型ごとに命令を一行ずつ並べた文字列にする。
/// 各行は命令の位置、命令の名前（`LOADK` など大文字）、オペランドを示す。形式はテストで比べない。
pub fn disassemble(program: &CompiledProgram) -> String;
```
