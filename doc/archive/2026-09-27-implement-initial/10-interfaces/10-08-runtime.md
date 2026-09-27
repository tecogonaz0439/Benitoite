# 実行時の値、VM、ランタイム

本章は、実行時の値、ヒープの確保、止まる理由、IO の操作とハンドラ、VM の状態、IO 実行器、報告の組み立て、プログラムの実行の流れの型とシグネチャを定める。設計書の対応する章は[仮想機械](../../2026-09-27-design-initial/02-impl/02-08-vm.md)と[ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)である。

## 止まる理由

組み込みの関数、ハンドラ、VM の命令が実行を止めるときの理由を `Stop` で表す（02-08「組み込みの関数の呼び出し」）。`Internal` は、型検査を通ったプログラムでは起きないはずの状態（引数の値の種類が違う、表にない番号など）であり、処理系の不具合として報告する。panic を使わずにこれを返す（[実装の規約](../00-common/00-02-conventions.md)）。

```rust file=src/runtime/mod.rs
//! ランタイム（設計書 02-09）: 実行時の値、ヒープ、IO のハンドラ、IO 実行器、報告、実行の流れ。

pub mod executor;
pub mod heap;
pub mod io;
pub mod panic;
pub mod real_io;
pub mod report;
pub mod run;
pub mod test_io;
pub mod value;

/// 一つの操作で作る文字列の大きさの上限（2^30 バイト。02-09、ADR 0049）。
pub const MAX_STRING_BYTES: u64 = 1_073_741_824;
/// 一つの操作で作るリストの長さの上限（2^24 要素）。
pub const MAX_LIST_LEN: u64 = 16_777_216;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Stream {
    Stdout,
    Stderr,
}

/// 実行時エラーの種類（01-08「実行時エラーによる停止」の最小実行版の三種）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum RuntimeError {
    /// R0101
    DivisionByZero,
    /// R0102
    IntegerOverflow,
    /// R0201・R0202。`reason` は `std::io::Error` の文字列
    WriteFailed { stream: Stream, reason: String },
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SizeUnit {
    Bytes,
    Elements,
}

/// 資源の不足の種類（01-08「資源の不足」のうち処理系が上限を設けるもの）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum ResourceError {
    /// R0901。`frames` はそのときの呼び出しの枠の数
    CallStackTooDeep { frames: u64 },
    /// R0902。`function` は値を作ろうとした関数の修飾した名前、または `+`。
    /// リストリテラル（`LIST` の命令）では `"list literal"`（実際には起きない）
    ValueTooLarge {
        function: &'static str,
        size: u64,
        unit: SizeUnit,
        limit: u64,
    },
}

/// 実行を止める理由。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Stop {
    Runtime(RuntimeError),
    Resource(ResourceError),
    /// 処理系の不具合。文字列は調べるための説明（英語）
    Internal(String),
}
```

## 実行時の値

値は Rust の列挙型で表し、ヒープの対象は参照カウント（`Rc`）で指す（02-08「値の表現」、ADR 0028・0078）。ヒープの対象への参照は、中身を非公開にした専用の型（`StrRef`・`FuncRef`・`CtorRef`・`ListRef`・`IoErrorRef`）で包む。これらはランタイムのモジュールの中（`heap.rs`）でだけ作れるので、ヒープの対象を作る処理は `Heap` の一か所に閉じる（ADR 0078、07-03 の「言語の値は、ランタイムの確保の処理を通して作る」）。

```rust file=src/runtime/value.rs
//! 実行時の値（設計書 02-08「値の表現」、03-06「List の内部の表現」）。

use std::rc::Rc;

use crate::base::BindingId;
use crate::builtins::BuiltinId;
use crate::bytecode::program::ProtoIdx;
use crate::ir::core_ir::{LambdaId, VarId};

#[derive(Clone, Debug)]
pub enum Value {
    Int(i64),
    Float(f64),
    Bool(bool),
    Char(char),
    Unit,
    Str(StrRef),
    Func(FuncRef),
    /// 構成子を適用した値。引数のない構成子は `fields` を持たない
    Ctor(CtorRef),
    List(ListRef),
    IoError(IoErrorRef),
}

/// 文字列の対象への参照。中身は常に正しい UTF-8。
#[derive(Clone, Debug)]
pub struct StrRef(Rc<str>);

/// 関数の値の対象への参照。
#[derive(Clone, Debug)]
pub struct FuncRef(Rc<FuncObj>);

/// 関数の値の対象。
#[derive(Debug)]
pub enum FuncObj {
    /// VM の関数の値: 原型と、捕捉した値の並び
    Proto {
        proto: ProtoIdx,
        captures: Vec<Value>,
    },
    /// 参照インタプリタの関数の値: 本体と、捕捉した変数の値
    Ref {
        code: RefCode,
        env: Vec<(VarId, Value)>,
    },
}

/// 参照インタプリタの関数の値の本体。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RefCode {
    Lambda(LambdaId),
    TopFn(BindingId),
    Builtin(BuiltinId),
}

/// 構成子を適用した値。
#[derive(Clone, Debug)]
pub struct CtorRef {
    tag: u32,
    fields: Option<Rc<CtorFields>>,
}

/// 構成子の引数の並び。解放は明示の積み重ねで行う（`Drop` を T06 が書く）。
#[derive(Debug)]
pub struct CtorFields {
    values: Vec<Value>,
}

/// リスト。空のリストはセルを持たない。
#[derive(Clone, Debug)]
pub struct ListRef(Option<Rc<Cell>>);

/// リストのセル（03-06「List の内部の表現」）。作った後に変更しない。解放は明示の積み重ねで行う（`Drop` を T06 が書く）。
#[derive(Debug)]
pub struct Cell {
    head: Value,
    tail: ListRef,
    /// このセルから始まるリストの長さ
    len: u32,
}

/// `IoError` の値の対象。
#[derive(Clone, Debug)]
pub struct IoErrorRef(Rc<IoErrorObj>);

#[derive(Debug)]
pub struct IoErrorObj {
    message: String,
}

/// `ListRef::iter` の返す反復子。`cur` はまだ返していない残りのリスト。
#[derive(Debug)]
pub struct ListIter<'a> {
    cur: &'a ListRef,
}
```

次の関数の中身は作業 T06 が書く。値を作る関数は `pub(super)` にし、`Heap` だけが呼ぶ。`CtorFields`・`Cell`・`FuncObj` の `Drop` も T06 が書く（02-09「メモリの管理」の明示の積み重ねによる解放。関数の値が関数の値を捕捉する連なりも、長くなりうる）。

```rust sig=src/runtime/value.rs
use super::Stop;

impl Value {
    pub fn as_int(&self) -> Option<i64>;
    pub fn as_float(&self) -> Option<f64>;
    pub fn as_bool(&self) -> Option<bool>;
    pub fn as_char(&self) -> Option<char>;
    pub fn as_str(&self) -> Option<&str>;
    pub fn as_list(&self) -> Option<&ListRef>;
    /// 構成子のタグと引数の並び
    pub fn as_ctor(&self) -> Option<(u32, &[Value])>;
    pub fn as_func(&self) -> Option<&FuncObj>;
    pub fn as_io_error(&self) -> Option<&str>;
}

impl StrRef {
    pub(super) fn new(s: &str) -> StrRef;
    pub fn as_str(&self) -> &str;
}

impl FuncRef {
    pub(super) fn new(obj: FuncObj) -> FuncRef;
    pub fn obj(&self) -> &FuncObj;
}

impl CtorRef {
    pub(super) fn new(tag: u32, fields: Vec<Value>) -> CtorRef;
    pub fn tag(&self) -> u32;
    pub fn fields(&self) -> &[Value];
}

impl ListRef {
    pub fn empty() -> ListRef;
    /// 先頭に一つ加えたリスト。長さの上限は呼び出し側（Heap::cons）が確かめる
    pub(super) fn cons(head: Value, tail: &ListRef) -> ListRef;
    pub fn len(&self) -> u32;
    pub fn is_empty(&self) -> bool;
    pub fn head(&self) -> Option<&Value>;
    pub fn tail(&self) -> Option<&ListRef>;
    /// 先頭から順に要素を返す
    pub fn iter(&self) -> ListIter<'_>;
    /// 二つのリストが同じセルを指すか（構造共有のテストに使う）
    pub fn same_cells(&self, other: &ListRef) -> bool;
}

impl<'a> Iterator for ListIter<'a> {
    type Item = &'a Value;
    fn next(&mut self) -> Option<&'a Value>;
}

impl IoErrorRef {
    pub(super) fn new(message: String) -> IoErrorRef;
    pub fn message(&self) -> &str;
}

/// 代数的データ型とリストの構造の `==`（`EQV`、01-06「等値の型」）。Rust の再帰を使わず、明示の積み重ねで辿る。
/// `Float` の成分は IEEE 754 で比べる。関数の値と `IoError` の値に出会ったら `Stop::Internal` を返す。
pub fn values_equal(a: &Value, b: &Value) -> Result<bool, Stop>;
```

## ヒープ

`Heap` は、ヒープの対象を作る唯一の入口であり、確保の回数と量を数える（07-02「測る項目」）。実行ごとに一つ作る。解放の回数は、`alloc-stats` の機能（Cargo の feature）を有効にしたビルドでだけ数える（[実装の規約](../00-common/00-02-conventions.md)の「大域の状態」）。

```rust file=src/runtime/heap.rs
//! ヒープの対象の確保（設計書 02-09「メモリの管理」、ADR 0078）。

/// 確保の統計。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct AllocStats {
    pub allocations: u64,
    /// 確保した対象の大きさの合計（文字列はバイト数、並びは要素の数に 32 を掛けた値、そのほかは 32）
    pub bytes: u64,
}

/// 実行ごとのヒープ。
#[derive(Debug, Default)]
pub struct Heap {
    stats: AllocStats,
}
```

```rust sig=src/runtime/heap.rs
use crate::bytecode::program::ProtoIdx;
use crate::ir::core_ir::VarId;
use super::Stop;
use super::value::{ListRef, RefCode, Value};

impl Heap {
    pub fn new() -> Heap;
    pub fn stats(&self) -> AllocStats;
    /// 文字列の値を作る。大きさの上限は呼び出し側が値を作る前に確かめる（02-09「一つの操作で作る値の大きさの上限」）
    pub fn string(&mut self, s: &str) -> Value;
    pub fn func_proto(&mut self, proto: ProtoIdx, captures: Vec<Value>) -> Value;
    pub fn func_ref(&mut self, code: RefCode, env: Vec<(VarId, Value)>) -> Value;
    /// 構成子を適用した値。`fields` が空なら確保しない
    pub fn ctor(&mut self, tag: u32, fields: Vec<Value>) -> Value;
    /// 先頭に一つ加えたリスト。結果の長さが上限を超えるなら `function` を名前として資源の不足を返す
    pub fn cons(&mut self, head: Value, tail: &ListRef, function: &'static str) -> Result<Value, Stop>;
    /// 並びの順のリストを作る（末尾の要素から順にセルを作る）。長さの上限を確かめる
    pub fn list_from_vec(&mut self, items: Vec<Value>, function: &'static str) -> Result<Value, Stop>;
    pub fn io_error(&mut self, message: String) -> Value;
}

/// 解放した対象の数（機能 `alloc-stats` を有効にしたビルドだけ。00-02「大域の状態」）。
#[cfg(feature = "alloc-stats")]
pub fn freed_count() -> u64;
```

## IO の操作とハンドラ

IO を行う組み込みの関数は、それぞれ一つの IO の操作 `IoOp` に当たる（02-09「ハンドラ表」）。ハンドラ表は、IO の操作から Rust の関数への表である。本プランでは、表を trait `IoHandlers` の実装一つで表す。本番のハンドラ表が `RealIo`、テスト用のハンドラ表が `TestIo` である。

```rust file=src/runtime/io.rs
//! IO の操作とハンドラ表（設計書 02-09「ハンドラ表」）。

use super::Stop;
use super::Stream;
use super::heap::Heap;
use super::value::Value;

/// IO の操作（01-07「IO を行う組み込み関数」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum IoOp {
    /// `Console.print`
    Print,
    /// `Console.println`
    Println,
    /// `Console.eprintln`
    Eprintln,
    /// `File.readText`
    ReadText,
    /// `Process.args`
    Args,
}

/// ハンドラ表。
pub trait IoHandlers {
    /// IO の操作を行い、応答の値か止まる理由を返す。
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop>;

    /// 出力のバッファを、標準出力、標準エラー出力の順にすべて書き出す（02-09「出力のバッファ」）。
    /// 書き出しに失敗した出力と理由を返す。バッファを持たないハンドラ表は何もしない。
    fn flush_all(&mut self) -> Vec<(Stream, String)> {
        Vec::new()
    }
}

/// テスト用のハンドラ表が記録する IO の事象（差分テストで比べる。07-03「差分テスト」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum IoEvent {
    Write { stream: Stream, text: String },
    ReadFile { path: String, ok: bool },
    Args,
}
```

```rust file=src/runtime/test_io.rs
//! テスト用のハンドラ表（設計書 02-09「ハンドラ表」）。

use std::collections::BTreeMap;

use super::io::IoEvent;

/// 書き込みをメモリに記録し、ファイルの内容とコマンドライン引数を与えられた値から返す。
#[derive(Debug, Default)]
pub struct TestIo {
    pub args: Vec<String>,
    /// パス（与えたままの文字列）→ 内容のバイト列
    pub files: BTreeMap<String, Vec<u8>>,
    pub events: Vec<IoEvent>,
    pub stdout: String,
    pub stderr: String,
}
```

```rust sig=src/runtime/test_io.rs
use super::Stop;
use super::heap::Heap;
use super::io::{IoHandlers, IoOp};
use super::value::Value;

impl TestIo {
    pub fn new(args: Vec<String>, files: BTreeMap<String, Vec<u8>>) -> TestIo;
}

impl IoHandlers for TestIo {
    /// 書き込みは `stdout`・`stderr` に加え、事象を記録する。書き込みは失敗しない。
    /// `ReadText` は `files` にあればその内容を UTF-8 として読み（正しくなければ `Err`）、なければ `Err` を返す。
    /// `Err` の `IoError` の文は `builtins::io_error::text` の定数を使い、`RealIo` と揃える（ゴールデンテストの期待値を CLI と一致させるため）。
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop>;
}
```

本番のハンドラ表は、出力のバッファを持つ（02-09「出力のバッファ」）。書き出し先は、テストで差し替えられるように `Write` の trait object で持つ。

```rust file=src/runtime/real_io.rs
//! 本番のハンドラ表と出力のバッファ（設計書 02-09「ハンドラ表」「出力のバッファ」）。

use std::io::Write;

/// バッファの中身を書き出す大きさ（64 KiB）。
pub const FLUSH_THRESHOLD: usize = 65_536;

/// 一つの出力のバッファ。
pub struct OutputBuffer {
    buf: Vec<u8>,
    sink: Box<dyn Write>,
    /// 書き出しに失敗したときの理由。失敗した後は書き込みを捨てる
    failed: Option<String>,
}

/// 本番のハンドラ表。
pub struct RealIo {
    stdout: OutputBuffer,
    stderr: OutputBuffer,
    args: Vec<String>,
    /// デバッグビルドで `BENITOITE_DEV_PANIC=run` のとき true（10-09）。作るときに環境変数を読む
    dev_panic_on_println: bool,
}
```

```rust sig=src/runtime/real_io.rs
use super::{Stop, Stream};
use super::heap::Heap;
use super::io::{IoHandlers, IoOp};
use super::value::Value;

impl OutputBuffer {
    pub fn new(sink: Box<dyn Write>) -> OutputBuffer;
    /// バッファに加える。加えた結果 FLUSH_THRESHOLD 以上になったら書き出す。書き出しに失敗したら理由を返す
    pub fn write(&mut self, bytes: &[u8]) -> Result<(), String>;
    /// 中身をすべて書き出す。前に失敗していれば何もせず `Ok`
    pub fn flush(&mut self) -> Result<(), String>;
    pub fn failure(&self) -> Option<&str>;
}

impl RealIo {
    /// 標準出力と標準エラー出力に書き出す本番のハンドラ表
    pub fn new(args: Vec<String>) -> RealIo;
    /// 書き出し先を与えて作る（テストで使う）
    pub fn with_sinks(args: Vec<String>, stdout: Box<dyn Write>, stderr: Box<dyn Write>) -> RealIo;
}

impl IoHandlers for RealIo {
    /// 書き込みの中の書き出しで失敗したら `Stop::Runtime(RuntimeError::WriteFailed)` を返す。
    /// `ReadText` は、読めない・正しい UTF-8 でないときに `Err(IoError)` の値を返す（ADR 0012）。
    /// ファイルは上限より 1 バイト多い分まで読み、上限を超えたら資源の不足を返す（02-09）。
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop>;
    fn flush_all(&mut self) -> Vec<(Stream, String)>;
}
```

## VM

VM の状態は 02-08「実行ごとの状態のうち VM が使うもの」の表のとおりである。呼び出しの枠 `Frame` の欄は、同じ節の呼び出しの枠の説明に対応する。

```rust file=src/vm/mod.rs
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
```

```rust sig=src/vm/mod.rs
impl<'p> Vm<'p> {
    pub fn new(program: &'p CompiledProgram, config: VmConfig) -> Vm<'p>;
    /// `main` の関数の値を引数なしで呼ぶ呼び出しの枠を積む（02-08「実行の開始と終わり」）。
    pub fn start_main(&mut self) -> Result<(), StopInfo>;
    /// 命令を実行する。直接呼び出しの方式では `Request` を返さない。
    pub fn run(&mut self, io: IoDispatch<'_>) -> VmStep;
    /// 要求と応答の方式で、要求への応答を渡す。続けて `run` を呼ぶ。
    pub fn resume(&mut self, response: Result<Value, Stop>);
    pub fn heap(&self) -> &Heap;
    pub fn heap_mut(&mut self) -> &mut Heap;
}
```

## IO 実行器と panic 境界

```rust sig=src/runtime/executor.rs
use crate::bytecode::program::CompiledProgram;
use crate::vm::StopInfo;
use super::heap::AllocStats;
use super::io::IoHandlers;
use super::panic::PanicReport;
use super::value::Value;

/// IO の命令の実行の方式（ADR 0029）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ExecMode {
    Direct,
    Request,
}

#[derive(Clone, Copy, Debug)]
pub struct ExecOptions {
    pub mode: ExecMode,
    pub max_call_stack_bytes: u64,
}

/// IO 実行器の結果。
#[derive(Debug)]
pub enum ExecEnd {
    Returned(Value),
    Stopped(StopInfo),
    /// 巻き戻しの panic を捕らえた（処理系の不具合）
    Panicked(PanicReport),
}

/// `main` を最後まで実行する（02-09「IO 実行器」）。VM の実行全体を `catch_unwind` で囲む（02-09「panic 境界」）。
/// 実行を終えたときの確保の統計も返す。
pub fn execute(program: &CompiledProgram, io: &mut dyn IoHandlers, opts: ExecOptions) -> (ExecEnd, AllocStats);
```

```rust sig=src/runtime/panic.rs
/// panic hook が記録した内容。
#[derive(Clone, PartialEq, Debug)]
pub struct PanicReport {
    pub message: String,
    /// `ファイル:行:列`
    pub location: Option<String>,
    pub backtrace: Option<String>,
}

/// 処理系の panic hook を設定する。標準エラー出力に何も書かず、panic したスレッドのスレッドローカルな記憶域に記録する。
/// 処理系を使うプログラム（CLI）が、起動の直後、スレッドを作る前に一度だけ呼ぶ（02-09「panic 境界」）。
pub fn install_hook();

/// このスレッドで記録した panic の内容を取り出す（取り出した後は空になる）。
pub fn take_report() -> Option<PanicReport>;

/// `f` を `catch_unwind` で囲んで呼ぶ。panic を捕らえたら記録を取り出して返す。
pub fn catch<T>(f: impl FnOnce() -> T) -> Result<T, PanicReport>;
```

## 報告の組み立てと実行の流れ

```rust sig=src/runtime/report.rs
use crate::bytecode::program::CompiledProgram;
use crate::diag::Diagnostic;
use crate::vm::StopInfo;
use super::panic::PanicReport;

/// 止まったときの記録から、実行時エラー・資源の不足・処理系の不具合の報告を作る。
/// 主な位置と呼び出しの履歴は 02-08「実行時エラーの情報の記録」の 1〜4 で作る。
/// 書き込みの失敗は主な位置と履歴を持たない。
pub fn stop_diagnostic(program: &CompiledProgram, info: &StopInfo) -> Diagnostic;

/// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）。
/// コードを持たないので `DiagBuilder` を使わず、`Diagnostic` を直接組み立てる（kind は `Internal`、文言は `codes::text::INTERNAL_*`）。
/// `stage` は段の名前、`message` は不具合の説明、`panic` は捕らえた panic の内容。
pub fn internal_diagnostic(stage: &str, message: &str, panic: Option<&PanicReport>) -> Diagnostic;
```

```rust sig=src/runtime/run.rs
use std::ffi::OsString;

use crate::bytecode::program::CompiledProgram;
use crate::diag::Diagnostic;
use super::executor::ExecOptions;
use super::heap::AllocStats;
use super::io::IoHandlers;

/// プログラムの実行の流れの結果（02-09「プログラムの実行の流れ」）。
/// 出力のバッファの書き出しは `run_with` の中で済ませてある。呼び出し側（CLI）は、
/// `main_error` があればその文字列と改行を、続けて `reports` を、この順に標準エラー出力に書き、`exit_code` で終わる。
#[derive(Debug)]
pub struct RunEnd {
    pub exit_code: u8,
    /// `main` が返した `Err` の文字列
    pub main_error: Option<String>,
    /// 実行時エラー・資源の不足・処理系の不具合の報告
    pub reports: Vec<Diagnostic>,
    /// 実行を終えたときの確保の統計（`execute` の二つ目の戻り値。CLI の `BENITOITE_DEV_ALLOC_STATS` が使う）
    pub alloc: AllocStats,
}

/// 02-09「プログラムの実行の流れ」の手順 1。コマンドライン引数が正しい UTF-8 でなければ、
/// 最初に見つけた引数の位置（1 から数える）を示す R0301 の報告を返す。呼び出し側は終了状態 1 で終える。
/// 報告を `Box` に入れるのは、`Diagnostic` が大きく、Clippy の `result_large_err` に当たるからである。
pub fn check_args(args: Vec<OsString>) -> Result<Vec<String>, Box<Diagnostic>>;

/// 02-09「プログラムの実行の流れ」の手順 3〜5。`io` は、手順 2 で作ったハンドラ表
/// （CLI は `RealIo`、ゴールデンテストは `TestIo`）。手順 4 の書き出しは `io.flush_all()` で行う。
pub fn run_with(program: &CompiledProgram, io: &mut dyn IoHandlers, opts: ExecOptions) -> RunEnd;
```
