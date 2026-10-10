# 最小実行版のランタイムの現状

- 状態: 検討中
- 対象のコミット: `f994ae4`（最小実行版の実装の完了後。処理系のソースは最小実行版から変わっていない）

## この資料の範囲

最小実行版の処理系が実際にどう作られているかを、ソースから読み取って記す。設計書（[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)、[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)）は初回リリース版の範囲に書き改めてあり、そこにある機構の多くはまだ実装されていない。そこで、最後の節で「実装済み」と「設計のみ」を表に分ける。

## モジュールの構成

値とランタイムにかかわるモジュールは次のとおりである（パスは `crates/benitoite/src/` からの相対）。

| モジュール | 行数 | 役割 |
|---|---:|---|
| [runtime/value.rs](../../../../../crates/benitoite/src/runtime/value.rs) | 857 | 実行時の値の型、構造の等しさ、明示の積み重ねによる解放 |
| [runtime/heap.rs](../../../../../crates/benitoite/src/runtime/heap.rs) | 254 | 値を作る関数（ヒープの対象を作る唯一の経路）と確保の統計 |
| [runtime/io.rs](../../../../../crates/benitoite/src/runtime/io.rs) | 41 | IO の操作の列挙とハンドラ表の trait |
| [runtime/executor.rs](../../../../../crates/benitoite/src/runtime/executor.rs) | 88 | IO 実行器。VM を作り、二つの方式で `main` を最後まで実行する |
| [runtime/real_io.rs](../../../../../crates/benitoite/src/runtime/real_io.rs) | 369 | 本番のハンドラ表と出力のバッファ |
| [runtime/test_io.rs](../../../../../crates/benitoite/src/runtime/test_io.rs) | 277 | テスト用のハンドラ表 |
| [runtime/panic.rs](../../../../../crates/benitoite/src/runtime/panic.rs) | 108 | panic hook と panic 境界 |
| [runtime/run.rs](../../../../../crates/benitoite/src/runtime/run.rs)、[runtime/report.rs](../../../../../crates/benitoite/src/runtime/report.rs) | 404、462 | 実行の流れ、終了状態、実行時エラーの報告 |
| [vm/mod.rs](../../../../../crates/benitoite/src/vm/mod.rs) | 1955 | VM（振り分けのループ、呼び出し、戻り） |
| [bytecode/](../../../../../crates/benitoite/src/bytecode/) | 約 3400 | 命令の符号化、原型とコンパイル済みプログラム、コード生成 |
| [builtins/](../../../../../crates/benitoite/src/builtins/) | 約 3400 | 組み込みの関数（演算子、Int、Float、Char、String、List、IoError）と組み込みの表 |
| [refinterp/mod.rs](../../../../../crates/benitoite/src/refinterp/mod.rs) | 909 | 参照インタプリタ（差分テストの正解） |

`Value` の型を名指しする箇所は、`builtins/list.rs`（129 箇所）、`builtins/string.rs`（76）、`builtins/ops.rs`（71）、`vm/mod.rs`（66）などに広がり、組み込みの関数からヒープの対象を作る呼び出し（`heap.string` など）は 62 箇所ある。値の表現を変えると、組み込みの関数のほぼすべてに手が入る。初回リリース版では標準ライブラリ（U3）がこの数倍に増えるので、値の表現と組み込みの関数の受け渡しの形（[03-options.md](03-options.md) の Q7）は、U3 を書き始める前に固める必要がある。

## 値の表現

### Rust の型

値は Rust の列挙型で表し、ヒープの対象は `std::rc::Rc` で指す（[runtime/value.rs](../../../../../crates/benitoite/src/runtime/value.rs)）。要点だけを抜き出すと次のとおりである。

```rust
pub enum Value {
    Int(i64), Float(f64), Bool(bool), Char(char), Unit,
    Str(StrRef),        // StrRef(Rc<str>)
    Func(FuncRef),      // FuncRef(Rc<FuncObj>)
    Ctor(CtorRef),      // CtorRef { tag: u32, fields: Option<Rc<CtorFields>> }
    List(ListRef),      // ListRef(Option<Rc<Cell>>)。単方向の連結リスト
    IoError(IoErrorRef),
}
pub enum FuncObj {
    Proto { proto: ProtoIdx, captures: Vec<Value> },   // VM の関数の値
    Ref { code: RefCode, env: Vec<(VarId, Value)> },   // 参照インタプリタの関数の値
}
pub struct Cell { head: Value, tail: ListRef, len: u32 }
```

- 参照を包む型（`StrRef` など）の作る関数は `pub(super)` であり、ランタイムの外からは `runtime::heap::Heap` の関数を通してしか値を作れない（[ADR 0078](../../../2026-10-09-design-first-release/decisions/0078-reference-counting-in-minimal.md)）。
- 引数のない構成子は `fields` を持たず、ヒープを確保しない。空のリストもセルを持たない。
- リストは単方向の連結リストである（[ADR 0041](../../../2026-10-09-design-first-release/decisions/0041-list-as-linked-list.md)）。初回リリース版では RRB 木の永続ベクタに置き換える（[ADR 0104](../../../2026-10-09-design-first-release/decisions/0104-list-as-persistent-vector.md)、[標準ライブラリ](../../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「List の内部の表現」）。
- `unsafe` は使わない（`Cargo.toml` の `unsafe_code = "forbid"`、[ADR 0079](../../../2026-10-09-design-first-release/decisions/0079-rust-readings-of-go-based-decisions.md)）。

### 大きさ

処理系のクレートを依存に持つ使い捨てのプログラムで `std::mem::size_of` を測った（2026-09-30、aarch64-apple-darwin、rustc 1.98.1。リポジトリには何も加えていない）。

| 型 | 大きさ（バイト） | 理由 |
|---|---:|---|
| `Value` | 24 | `StrRef` が `Rc<str>`（長さを持つ太いポインタ、16 バイト）であり、`CtorRef` がタグと参照で 16 バイトなので、列挙型の印を加えて 24 になる |
| `Cell`（リストのセル） | 40 | `Value` 24 ＋ `ListRef` 8 ＋ `len` 4、揃えて 40。`Rc` の中の参照の数二つ（16）を加えると、1 要素あたり 56 バイトを確保する |
| `Frame`（呼び出しの枠） | 40 | 後述 |
| `FuncObj` | 40 | |

[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」の方針は「列挙型の値の大きさを 16 バイトに保つ」であるが、実装は 24 バイトであり、方針と合っていない。確保の統計（`alloc-stats`）はセル一つを 32 バイトと数えるが、これは統計のための名目の値であり、実際の確保量（56 バイト＋確保器の管理の分）より小さい。

## ヒープと参照カウント

`Heap`（[runtime/heap.rs](../../../../../crates/benitoite/src/runtime/heap.rs)）は確保の統計だけを持つ構造体であり、対象そのものは Rust の大域の確保器（`malloc`）で `Rc` として確保する。解放は `Rc` の参照の数が 0 になったときに Rust の `Drop` で行う。

長いリストや深い木を落とすときに `Drop` が再帰しないよう、`Cell`・`CtorFields`・`FuncObj` の `Drop` は、子の値のうち解放が連鎖するもの（参照の数が 1 の対象を指すもの）だけを作業列（`ReleaseQueue`）に移し、ループで順に落とす（[ADR 0078](../../../2026-10-09-design-first-release/decisions/0078-reference-counting-in-minimal.md) の決定 3）。連結リストのように一本道の連鎖では作業列の `Vec` を確保しない工夫がある。構造の等しさ（`values_equal`）も、明示の積み重ねで辿る。

解放の回数の計数は、機能 `alloc-stats` を有効にしたビルドだけで、`thread_local!` の計数器で数える（AGENTS.md「大域の状態」の例外の一つ）。

## VM

### 状態

`Vm`（[vm/mod.rs](../../../../../crates/benitoite/src/vm/mod.rs)）は、コンパイル済みプログラムへの参照、レジスタの並び `regs: Vec<Value>`、枠の並び `frames: Vec<Frame>`、ヒープ、呼び出しの情報の大きさの計数、定数の値の表、要求と応答の方式のための保留の欄を持つ。タスク、ハンドラ、継続、リソースの表はない。

```rust
pub struct Frame {
    pub func: FuncRef,               // 実行中の関数の値（参照の数を一つ持つ）
    pub proto: ProtoIdx, pub pc: u32,
    pub base: u32, pub size: u32,    // レジスタの窓
    pub ret_reg: u32,                // 結果を入れる呼び出し元のレジスタ（絶対位置）
    pub call_site: Option<InstrRef>, // 呼び出した命令
}
```

レジスタは一本の `Vec<Value>` を窓に区切って使う。戻っても縮めずに使い回し、窓の後ろは常に `Unit` にしておく（参照が残って解放が遅れないようにするため）。

### 振り分けのループと呼び出し

`run` のループは、命令ごとに `step` を呼ぶ。`step` は毎回、原型の表から原型を引き、`code.get(pc)` で命令を読み、枠の並びの最後の枠を引き、窓の範囲を確かめてから `match` で振り分ける。レジスタの読み書きも `get` と `?` で範囲を確かめ、外れたら `Stop::Internal` を返す（AGENTS.md の「失敗を panic で表さない」と lint の `indexing_slicing` による）。

- `CALL` は、呼び出しの情報の大きさ（枠を 96 バイト、レジスタを 32 バイトとして数える固定の定数。[ADR 0030](../../../2026-10-09-design-first-release/decisions/0030-call-stack-size-limit.md)）を確かめ、新しい窓に引数を複製し、枠を積む。枠は呼ばれた関数の値を `FuncRef` として持つので、呼び出しのたびに参照の数を一つ増やし、戻るときに減らす。
- `TAILCALL` は枠を置き換える。`RETURN` は窓のレジスタをすべて `Unit` にしてから枠を降ろす。
- レジスタの複製（`dup`）と上書き（`store`）は、参照を持たない値のときに `Clone` と `Drop` の処理を通らないよう、手で場合を分けてある。
- `LOADK` は定数の記述から値を作る。文字列と原型の定数だけを、作った値の表に取っておいて使い回す。

### 命令

64 ビット固定長の命令（[ADR 0027](../../../2026-10-09-design-first-release/decisions/0027-register-bytecode.md)）で、最小実行版の命令は 45 種ある（[bytecode/instr.rs](../../../../../crates/benitoite/src/bytecode/instr.rs)）。[バイトコードとコード生成](../../../2026-10-09-design-first-release/02-impl/02-07-bytecode.md)が初回リリース版に加える命令（`GETDICT`・`DICT`・`SUPER`・`METHOD`・`TAILMETHOD`・`ESCAPE`・`LAZY`・`FORCE`・`UPDATE`・`USE`・`RELEASE`・`HANDLE`・`PERFORM`・`RESUME`、`Decimal` と `Byte` の演算と比較）は、まだない。

## 組み込みの関数と IO の呼び方

### 純粋な組み込みの関数

```rust
pub type PureFn = fn(&mut Heap, &[Value]) -> Result<Value, Stop>;
```

`PRIM` は、窓のレジスタの並びをそのまま借りて渡し、結果を結果のレジスタに入れる。組み込みの関数は言語の関数を呼ばない。関数を引数にとる `List.map` などは、prelude のソース（[prelude/list.bnt](../../../../../crates/benitoite/src/prelude/list.bnt)）で書いてある（[ADR 0016](../../../2026-10-09-design-first-release/decisions/0016-calls-off-go-stack.md)）。

### IO の二つの方式

IO を行う組み込みの関数は 5 つ（`Console.print`・`println`・`eprintln`、`File.readText`、`Process.args`）であり、ハンドラ表の trait を通して呼ぶ（[runtime/io.rs](../../../../../crates/benitoite/src/runtime/io.rs)）。

```rust
pub trait IoHandlers {
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop>;
    fn flush_all(&mut self) -> Vec<(Stream, String)> { Vec::new() }
}
```

VM は IO の命令を二つの方式で実行する（[ADR 0029](../../../2026-10-09-design-first-release/decisions/0029-two-io-execution-modes.md)、[ADR 0088](../../../2026-10-09-design-first-release/decisions/0088-keep-both-io-execution-modes.md)）。

| 方式 | 実装 |
|---|---|
| 直接呼び出し | `IoDispatch::Direct(handlers)` を受け取った `run` が、`IO` の命令でハンドラ表を直接呼ぶ |
| 要求と応答 | `run` が `VmStep::Request { op, args }` を返して止まる。IO 実行器（[runtime/executor.rs](../../../../../crates/benitoite/src/runtime/executor.rs)）がハンドラ表を呼び、`resume` で応答を結果のレジスタに入れ、`run` を呼び直す |

どちらも同じスレッドで同期的に操作を行う。イベントループと作業用のスレッドはない。

### 出力のバッファと panic 境界

本番のハンドラ表（[runtime/real_io.rs](../../../../../crates/benitoite/src/runtime/real_io.rs)）は、標準出力と標準エラー出力をそれぞれのバッファに溜め、64 KiB に達したときと実行の終わりに、VM のスレッドで書き出す。書き出しに一度失敗した出力は、以後の書き込みを捨てる。IO 実行器は VM の実行全体を `catch_unwind` で囲み、panic hook はスレッドローカルな記憶域に内容を記録する（[runtime/panic.rs](../../../../../crates/benitoite/src/runtime/panic.rs)）。

## 参照インタプリタとの結び付き

参照インタプリタは、VM と同じ `Value` と `Heap` を使う。関数の値は `FuncObj::Ref` という VM と別の選択肢で表す。そのため、`Value` の表現を変えると参照インタプリタも変わる。差分テストでは、参照インタプリタは VM の正解として使うので、両者が同じ値の実装を共有していると、値の実装の不具合が両方に同じく現れて差分テストで見つからないおそれがある。作り直しでは、この結び付きを保つか切るかを決める（[03-options.md](03-options.md) の Q8）。

## 実装済みのものと設計のみのもの

| 機構 | 最小実行版の実装 | 初回リリース版の設計（未実装） |
|---|---|---|
| 値の種類 | Int・Float・Bool・Char・Unit・String・関数・構成子・連結リスト・IoError | `Byte`・`Decimal`・`Bytes`・永続ベクタのリスト・マップと集合（重みで平衡させる二分木）・`Reference`・`Lazy`・辞書・継続・リソース・`Task`・`NetworkError`・中身を見せない組み込みの値（[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」） |
| メモリの管理 | `Rc` による参照カウント、明示の積み重ねによる解放 | 同じ方式に、`Reference` のセルを起点にした循環の回収を加える（暫定。[ADR 0239](../../../2026-10-09-design-first-release/decisions/0239-cycle-collection-for-reference-cells.md)）。最終的な方式は作り直しで決める |
| 枠の積み重ね | 実行に一つ。呼び出しの枠だけ | タスクごとに、`handle` の枠で区切った区画の連なり。枠の種類は呼び出し・解放・`update`・セルの更新・`handle`・`drop`（[ADR 0160](../../../2026-10-09-design-first-release/decisions/0160-one-shot-continuations-as-stack-segments.md)） |
| ハンドラと継続 | なし | 深いハンドラ、一度だけ再開できる継続、区画の所有の移動、引き継いだハンドラの直接の再開（[ADR 0118](../../../2026-10-09-design-first-release/decisions/0118-effect-handlers.md)、[ADR 0151](../../../2026-10-09-design-first-release/decisions/0151-inherited-handlers-tail-resume-only.md)） |
| タスクとスケジューラ | なし | VM と同じスレッドのスケジューラ、呼び出しの回数の予算、取り消し、待ちの表、行き詰まりの検出（[ADR 0161](../../../2026-10-09-design-first-release/decisions/0161-single-threaded-task-scheduler.md)、[ADR 0238](../../../2026-10-09-design-first-release/decisions/0238-task-wait-deadlock-as-runtime-error.md)） |
| IO 実行器 | 同期的な二つの方式 | `mio` のイベントループ、作業用のスレッド、応答の「待つ」（[ADR 0162](../../../2026-10-09-design-first-release/decisions/0162-event-loop-and-worker-threads-for-io.md)） |
| リソース | なし | 実行ごとのリソースの表、解放の枠、貸し出しの状態、解放の失敗のまとめ方（[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「リソースの追跡」） |
| 可変のセルと明示遅延 | なし | 版の番号によるやり直し（[ADR 0167](../../../2026-10-09-design-first-release/decisions/0167-reference-update-by-version-retry.md)）、`Lazy` の三つの状態と待ち |
| 止める手順 | 実行時エラーで記録して止まる。解放するものはない | 全タスクの枠を上から降ろし、リソースを解放する。`Process.exit`・中断の要求・テストの確認の失敗にも使う |
| 中断の要求 | なし | 原子的な真偽値の印を切り替えの位置で読む（[ADR 0163](../../../2026-10-09-design-first-release/decisions/0163-interrupt-releases-resources.md)） |
| 出力のバッファ | VM のスレッドで溜めて書き出す | 同じ。ただし [OPEN-062](../../../2026-10-09-design-first-release/open-issues.md#open-062) の R04・R13 で転送の分離が候補に挙がっている |

## 測定の結果

最小実行版の測定の記録は [tools/bench/results/2026-09-27-1ff816b0b156.md](../../../../../tools/bench/results/2026-09-27-1ff816b0b156.md) にある（Apple M4、局所的な最適化の後）。作り直しの判断にかかわる事実を抜き出す。

### 実行時間

| ベンチマーク | Benitoite（秒） | OCaml バイトコード（秒） | Lua（秒） | CPython（秒） | ヒープの確保の回数 |
|---|---:|---:|---:|---:|---:|
| fib | 2.12 | 0.159 | 0.252 | 1.27 | 16 |
| loop | 1.03 | 0.072 | 0.055 | 1.09 | 16 |
| list | 1.43 | 0.111 | 0.079 | 0.149 | 975 万 |
| tree | 1.89 | 0.219 | 0.785 | 1.21 | 839 万 |
| eval | 1.75 | 0.088 | 0.298 | 2.01 | 688 |

### CPU プロファイル（self の上位）

| ベンチマーク | 上位 |
|---|---|
| fib | `Vm::run` 52.0%、`Vm::ret` 10.4%、`Vm::call` 8.6%、`Vm::load_const` 7.2%、`int_binary` 5.5%、`Value` の drop 4.3% |
| loop | `Vm::run` 61.2%、`Vm::tail_call` 17.0%、`int_binary` 6.6%、`Vm::load_const` 5.6% |
| list | `Vm::run` 34.2%、`Value` の drop 10.3%、malloc 9.7%、`Vm::call` 5.9%、`Value` の clone 5.4% |
| tree | `Vm::run` 40.5%、malloc 12.1%、`Vm::ret` 9.2%、`Value` の drop 7.9% |
| eval | `Vm::run` 46.0%、`Value` の drop 13.6%、`Vm::ret` 12.3%、`Vm::call` 9.4%、`Value` の clone 7.9% |

### 最大常駐メモリ

tree で 747 MB（OCaml は 104 MB、Lua は 676 MB）、list で 342 MB（OCaml バイトコードは 94 MB）。

### 測定から読み取れること

fib と loop はヒープをほとんど確保しない（確保の回数 16）にもかかわらず、OCaml のバイトコードより 13〜14 倍、Lua より 8〜19 倍遅い。この二つでは、参照カウントの対象の確保と解放は費用にほぼ現れず、時間の大半は振り分けのループ（`Vm::run` の self）と呼び出しと戻りにかかっている。したがって、fib と loop の差は値の表現よりも、命令ごとに原型と枠を引き直し、レジスタの読み書きごとに範囲を確かめて `Result` を返す振り分けのループの組み立てと、呼び出しの手順から来ていると見られる。[ADR 0240](../../../2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md) は OCaml との 1 桁の差の中心を値の表現に置いているが、この見立てが当てはまるのは、list・tree・eval のほうである。list と tree では値の確保と解放（`malloc` と `Value` の drop）が、eval では確保をほとんどしないまま既存の値の参照の数の増減（`Value` の clone と drop）が、それぞれ self の 20〜25% を占める。作り直しでは、値の表現とメモリの管理に加えて、振り分けのループと呼び出しの手順も対象に含める必要がある（[03-options.md](03-options.md) の Q4 と Q9）。これはプロファイルと実装から見立てたものであり、直して測り直して確かめたものではない。
