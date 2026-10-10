//! 関数の原型とコンパイル済みプログラム（設計書 02-07「コンパイル済みプログラム」、実装プラン 10-07）。
//! 生成の後に変更せず、スレッドの間で共有する（設計書 02-01「コンパイル済みプログラムと実行ごとの状態」）。

use std::sync::Arc;

use crate::base::{BindingId, SourceTable, Span};
use crate::builtins::BuiltinId;
use crate::builtins::iface::Capability;

use super::instr::{Instr, Opcode};
use super::liveness::LiveInfo;

/// 原型の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ProtoIdx(pub u32);

/// 定数の記述の並び（`CompiledProgram::consts`）の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ConstIdx(pub u32);

/// 構成子の表の番号（構成子のタグとは別）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct CtorIdx(pub u32);

/// 型クラスの表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct TraitIdx(pub u32);

/// 実装の表の番号。辞書の対象の `tag` に入れる。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ImplIdx(pub u32);

/// 操作の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct OpIdx(pub u32);

/// 組み込みの関数の参照の並びの番号（`PRIM`・`IO` の B）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinRefIdx(pub u32);

/// ハンドラの記述の並びの番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct HandlerIdx(pub u32);

/// 原型の由来の種類（02-07「原型の名前と由来の種類」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ProtoOrigin {
    /// 利用者のトップレベルの関数（フィールドを取り出す関数を含む）
    UserFn,
    /// 利用者の実装のメソッド
    UserMethod,
    /// 利用者のラムダ（`<lambda>` と位置）
    UserLambda,
    /// 利用者の `handle` の本体（`<handle>` と位置）
    UserHandleBody,
    /// 利用者の `handle` の節（`<case 操作の名前>` と位置）
    UserHandleClause,
    /// 利用者の `lazy` の本体（`<lazy>` と位置）
    UserLazy,
    /// 標準ライブラリの公開の関数と実装のメソッド
    StdlibPublic,
    /// 標準ライブラリの補助の関数と、標準ライブラリのソースの中のラムダ・`handle` の本体と節・`lazy` の本体
    StdlibHelper,
    /// 値として使う組み込みの関数と操作
    BuiltinValue,
}

impl ProtoOrigin {
    /// 呼び出しの履歴に示すか（02-08「実行時エラーの情報の記録」の手順 1）。
    pub fn shown_in_trace(self) -> bool {
        self != ProtoOrigin::StdlibHelper
    }
}

/// 捕捉する値の取り方（02-07「関数の値と捕捉」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum CaptureSource {
    /// 作る側の関数のレジスタ
    Reg(u16),
    /// 作る側の関数が捕捉した値
    Capture(u16),
}

/// 定数の記述（02-07「定数表」）。実行中の値そのものは置かない。
/// 子の記述を指す番号は、その記述自身の番号より小さい（VM は番号の小さい順に作れば子が先にできる）。
#[derive(Clone, PartialEq, Debug)]
pub enum ConstDesc {
    Int(i64),
    Float(f64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    Byte(u8),
    /// `Decimal` の値 `mantissa / 10^scale`（10-01 の `base::Decimal` の仮数と小数の桁数）。
    /// `base::Decimal` は C02 で置くので、C01 の本章は同じ二つの値を直接持つ
    Decimal {
        mantissa: i128,
        scale: u8,
    },
    /// 構成子を適用した値。`args` が空なら引数のない構成子（`Value::Tag`）
    Ctor {
        ctor: CtorIdx,
        args: Vec<ConstIdx>,
    },
    List(Vec<ConstIdx>),
    /// 鍵の順に並べた組。同じ鍵は現れない
    Map(Vec<(ConstIdx, ConstIdx)>),
    /// 鍵の順に並べた要素。同じ要素は現れない
    Set(Vec<ConstIdx>),
    /// 何も捕捉しない関数の原型（トップレベルの関数、値として使う組み込みの関数と操作）
    Func(ProtoIdx),
    /// 制約の辞書を持たない実装の辞書
    Dict(ImplIdx),
}

/// `SWITCH` の分岐表。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct SwitchTable {
    /// タグを添字とする跳ぶ先。そのタグの分岐がなければ `None`
    pub targets: Vec<Option<i32>>,
    /// 表にないタグのときの跳ぶ先（`_` の分岐）
    pub default: Option<i32>,
}

/// ハンドラの記述の節一つ（02-07「コンパイル済みプログラム」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ClauseDesc {
    pub op: OpIdx,
    /// 末尾で再開する節か（02-05「書く位置の検査」）
    pub tail_resumptive: bool,
}

/// ハンドラの記述（`HANDLE` 一つにつき一つ）。節の並びは `HANDLE` の節の関数の並びと同じ順。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct HandlerDesc {
    pub clauses: Vec<ClauseDesc>,
}

/// 関数の原型。
#[derive(Clone, PartialEq, Debug)]
pub struct Proto {
    /// 呼び出しの履歴に示す名前（02-07「原型の名前と由来の種類」）
    pub name: String,
    pub origin: ProtoOrigin,
    /// ラムダ・`handle` の本体と節・`lazy` の本体を書いた位置（名前とともに示す）。ほかの原型では `None`
    pub span: Option<Span>,
    /// 関数の境界か（02-07「関数の境界」）。`ESCAPE` はこの印の呼び出しの枠で止まる
    pub boundary: bool,
    pub code: Vec<Instr>,
    /// `LOADK` の Bx が指す、定数の記述の番号の並び
    pub consts: Vec<ConstIdx>,
    pub switch_tables: Vec<SwitchTable>,
    /// `HANDLE` の C が指す、ハンドラの記述の番号の並び
    pub handlers: Vec<HandlerIdx>,
    pub num_regs: u16,
    pub num_params: u16,
    pub captures: Vec<CaptureSource>,
    /// 命令ごとの由来位置。`code` と同じ長さ。値として使う組み込みの関数と操作の原型では `None`
    pub positions: Vec<Option<Span>>,
    /// 命令ごとのメソッドの呼び出しの型クラス。`code` と同じ長さ。`METHOD`・`TAILMETHOD` の位置に
    /// `Some(型クラスの表の番号)`、ほかの位置に `None`（02-07「辞書とメソッドの呼び出し」）。引数の並びの長さを
    /// `TraitInfo::methods[C].arity` から決めるために使う
    pub method_traits: Vec<Option<TraitIdx>>,
    /// 生存の情報（10-07「生存の情報」）
    pub live: LiveInfo,
}

/// 構成子の表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CtorInfo {
    /// 型の名前（`AdtDef::name`。モジュールで修飾しない）
    pub type_name: String,
    pub ctor_name: String,
    /// 型の宣言の中で 0 から数えたタグ
    pub tag: u32,
    pub arity: u16,
}

/// 型クラスのメソッド一つ。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct MethodInfo {
    /// メソッドの名前（型クラスの実装のメソッドの `Def::name` の最後の段。`show`）
    pub name: String,
    /// 引数の数（メソッド自身の制約の辞書の引数を含む）
    pub arity: u16,
}

/// 型クラスの表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TraitInfo {
    pub name: String,
    pub methods: Vec<MethodInfo>,
    /// 上位の型クラス（宣言の順）
    pub supers: Vec<TraitIdx>,
}

/// 上位の型クラスの辞書の作り方（02-07「辞書とメソッドの呼び出し」の辞書の式）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum DictRecipe {
    /// 実装の辞書。`args` はその実装の制約の辞書の作り方（制約を持たなければ空）
    Impl { imp: ImplIdx, args: Vec<DictRecipe> },
    /// この実装の i 番目の制約の辞書
    Param(u16),
    /// 上位の型クラスの `index` 番目の辞書
    Super { of: Box<DictRecipe>, index: u16 },
}

/// 実装の表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct ImplInfo {
    /// 表示のための名前（`Show[Person]`）
    pub name: String,
    pub trait_: TraitIdx,
    /// 実装の型パラメータの制約の辞書の数
    pub dict_arity: u16,
    /// メソッドの原型（型クラスのメソッドの順）
    pub methods: Vec<ProtoIdx>,
    /// 上位の型クラスの辞書の作り方（型クラスの上位の型クラスの順）
    pub supers: Vec<DictRecipe>,
}

/// 操作の表の項目（利用者のエフェクトの操作と組み込みのエフェクトの操作）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct OpInfo {
    /// エフェクトで修飾した名前（`Log.write`、`Console.writeLine`）。引き継いだハンドラの節の誤りの報告に使う
    pub name: String,
    /// エフェクトの名前（利用者のエフェクトは `name` の最後の `.` より前の `Log`、組み込みのエフェクトは `Console.Write`）
    pub effect: String,
    pub arity: u16,
    /// 組み込みのエフェクトの操作なら、対応する組み込みの関数の参照
    pub builtin: Option<BuiltinRefIdx>,
}

/// 組み込みの関数の参照（`PRIM`・`IO` の B が指す）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinRef {
    pub id: BuiltinId,
    pub arity: u16,
    /// 権限（10-11 の `BuiltinDecl::capability` と同じ）。生存の情報と VM が、待ちうる呼び出しかを決める
    pub capability: Capability,
    /// 組み込みのエフェクトの操作なら、その操作（`IO` が節を探す鍵）
    pub op: Option<OpIdx>,
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
    pub consts: Vec<ConstDesc>,
    /// トップレベルの関数（標準ライブラリのソースの関数を含む）の束縛の番号から原型への対応
    pub top_fns: Vec<(BindingId, ProtoIdx)>,
    pub ctors: Vec<CtorInfo>,
    pub traits: Vec<TraitInfo>,
    pub impls: Vec<ImplInfo>,
    pub ops: Vec<OpInfo>,
    pub builtins: Vec<BuiltinRef>,
    pub handlers: Vec<HandlerDesc>,
    /// `main` の原型。コア IR の `Program::main` が `None`（`main` を検査しない経路）なら `None`
    pub main: Option<ProtoIdx>,
    /// `main` が `None` のときは `MainKind::Unit` を入れ、読まない
    pub main_kind: MainKind,
    /// 位置の表の span が指すソース（利用者のモジュールと、読んだ標準ライブラリのソース）
    pub sources: Arc<SourceTable>,
}

/// `PRIM`・`IO` の命令の被演算子（10-10 の要求と完了の処理が、引数と結果のレジスタを決めるのに使う）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinCallOperands {
    pub result: u16,
    pub builtin: BuiltinRefIdx,
    pub args_start: u16,
    pub arg_count: u16,
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn at<T>(items: &[T], index: u32) -> Option<&T> {
    usize::try_from(index).ok().and_then(|i| items.get(i))
}

impl CompiledProgram {
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn proto(&self, idx: ProtoIdx) -> Option<&Proto> {
        at(&self.protos, idx.0)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn constant(&self, idx: ConstIdx) -> Option<&ConstDesc> {
        at(&self.consts, idx.0)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn ctor(&self, idx: CtorIdx) -> Option<&CtorInfo> {
        at(&self.ctors, idx.0)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn trait_info(&self, idx: TraitIdx) -> Option<&TraitInfo> {
        at(&self.traits, idx.0)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn impl_info(&self, idx: ImplIdx) -> Option<&ImplInfo> {
        at(&self.impls, idx.0)
    }

    pub fn op(&self, idx: OpIdx) -> Option<&OpInfo> {
        at(&self.ops, idx.0)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn builtin(&self, idx: BuiltinRefIdx) -> Option<&BuiltinRef> {
        at(&self.builtins, idx.0)
    }

    pub fn handler(&self, idx: HandlerIdx) -> Option<&HandlerDesc> {
        at(&self.handlers, idx.0)
    }

    /// `PRIM`・`IO` の命令の被演算子。ほかの命令か、参照の番号が表にないときは `None`。
    pub fn builtin_call_operands(&self, instr: Instr) -> Option<BuiltinCallOperands> {
        let op = instr.opcode()?;
        if op != Opcode::Prim && op != Opcode::Io {
            return None;
        }
        let builtin = BuiltinRefIdx(u32::from(instr.b()));
        let arg_count = self.builtin(builtin)?.arity;
        Some(BuiltinCallOperands {
            result: instr.a(),
            builtin,
            args_start: instr.c(),
            arg_count,
        })
    }
}

impl Proto {
    /// `LOADK` の Bx が指す定数の記述の番号。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn constant(&self, bx: u32) -> Option<ConstIdx> {
        at(&self.consts, bx).copied()
    }

    /// `HANDLE` の C が指すハンドラの記述の番号。
    pub fn handler(&self, c: u16) -> Option<HandlerIdx> {
        at(&self.handlers, u32::from(c)).copied()
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn switch_table(&self, bx: u32) -> Option<&SwitchTable> {
        at(&self.switch_tables, bx)
    }
}

/// コンパイル済みプログラムがスレッドの間で共有できることを、コンパイルの時点で確かめる（02-01「コンパイル済みプログラムと実行ごとの状態」）。
// 呼ばれない関数で、型の性質をコンパイルの時点で確かめる（00-02「`#[allow]` を書いてよい箇所」）。
#[allow(dead_code)]
fn assert_shareable() {
    fn check<T: Send + Sync>() {}
    check::<CompiledProgram>();
}
