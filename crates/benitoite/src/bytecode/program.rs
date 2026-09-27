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
