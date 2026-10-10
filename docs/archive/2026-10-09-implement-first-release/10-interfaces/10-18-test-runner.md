# テストの実行器

本章は、`benitoite test` の型と関数のシグネチャを定める。`Assert` のソース、テストの関数を一つの実行として動かす関数（`runtime::run` に加える）、`Assert.Check` の操作の処理と 10-09 の `StopReason::CheckFailed`・10-13 の `EndKind::CheckFailed` の中身、値の書き出し、結果の報告の文章の形と JSON Lines の形である。設計書の対応する章は[利用者プログラムのテスト](../../2026-10-09-design-first-release/06-tooling/06-04-test-runner.md)、[スクリプト実行と埋め込み](../../2026-10-09-design-first-release/02-impl/02-11-embedding.md)の「テストの実行」、[CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md)の「`test` のコマンドライン（初回リリース版）」、[診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「テストの実行器への受け渡し」であり、判断の根拠は [ADR 0120](../../2026-10-09-design-first-release/decisions/0120-test-functions-and-assert-effect.md)・[ADR 0206](../../2026-10-09-design-first-release/decisions/0206-test-command-line-and-exit-status.md)・[ADR 0208](../../2026-10-09-design-first-release/decisions/0208-test-report-destination.md)・[ADR 0252](../../2026-10-09-design-first-release/decisions/0252-test-report-format.md) である。

- 置く作業: D00

本章は、10-02・10-09・10-12・10-13・10-14 を広げる。どれも、既存のファイルの末尾に `sig=` を足すか、新しいファイルを置く形で行い、凍結した型とシグネチャは変えない。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/prelude/stdlib/Assert.bnt` | 置く（`text file=`） | — |
| `src/prelude/mod.rs` | `STDLIB` の末尾に `Assert` の項目を足す（`append=`） | — |
| `src/builtins/funcs/assert.rs` | D00 が本章の「組み込みの関数の表の部分」のとおりに書く（ブロックを置かない。10-12 の部分の書き方） | —（D00 が最終の形で書く） |
| `src/runtime/run.rs` | 末尾に足す（`sig=`） | D10 |
| `src/runtime/mod.rs` | 末尾に足す（`append=`）。`assert` のモジュールの宣言 | — |
| `src/runtime/assert.rs` | 置く（`file=` と `sig=`） | D10 |
| `src/vm/mod.rs` | 末尾に足す（`sig=`） | D10 |
| `src/diag/render.rs` | 末尾に足す（`sig=`） | D11 |
| `src/cli/tools.rs` | 末尾に足す（`append=`）。モジュールの宣言 | — |
| `src/cli/tools/test_runner/mod.rs` | 置く（`file=` と `sig=`） | D11 |
| `src/cli/tools/test_runner/report.rs` | 置く（`sig=`） | D11 |

## `Assert` のモジュール

prelude のモジュール `Benitoite.Assert` は、エフェクト `Assert.Check` と四つの操作を宣言する（06-04「期待の確認」、03-06「Assert（初回リリース版）」）。標準のモジュールであり、prelude に入る（[README](../README.md) の「U3・U4 で決めたこと」の 1）。組み込みのエフェクトの表（10-05）の `Assert.Check` は `declared_in_source` が真なので、このソースの宣言から束縛を作る。

```text file=src/prelude/stdlib/Assert.bnt
//! Checks of expected values in tests. The runner of `benitoite test` handles them.

/// Checks in test functions. `main` cannot use this effect.
public effect Check
  /// Fails the test when `actual = expected` is false.
  function equal[T: equality](actual: T, expected: T) -> Unit
  /// Fails the test when `actual = expected` is true.
  function notEqual[T: equality](actual: T, expected: T) -> Unit
  /// Fails the test with `message` when `condition` is false.
  function isTrue(condition: Boolean, message: String) -> Unit
  /// Fails the test with `message`. It does not return.
  function fail[T](message: String) -> T
end effect
```

`STDLIB` の末尾に次の項目を足す。U3 の L00 が足す項目との前後は、先に取り込んだ作業が先になる。表の順はモジュールの ID の振り方を決めるが、値をコードに書き込まないので、どちらの順でもよい（10-14「ファイルとモジュールの名前」）。

```rust append=src/prelude/mod.rs::STDLIB
    StdlibModuleSource {
        path: &["Assert"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Assert.bnt"),
    },
```

## 組み込みの関数の表の部分

名前解決は、組み込みのエフェクトの操作ごとに `Benitoite.` から始まる名前で組み込みの関数の表を引き、表にない操作を処理系の不具合とする（10-04「名前解決の表」）。prelude のモジュールはどの検査でも読むので、`Assert` のソースを置く D00 は、同時に表の部分を加える。そうしないと、D00 の後のすべての検査が処理系の不具合で止まる。

D00 は、`src/builtins/funcs/assert.rs` を作り、次の四つの項目を `builtin!` の `io` の権限で宣言し、`src/builtins/funcs/mod.rs` に子のモジュールを宣言して、`PARTS` の末尾に部分 `assert::DECLS` を加える（10-12「部分と番号」。00-03「インターフェースの凍結」の `funcs/mod.rs` の例外）。

| 名前 | 権限 | 引数の数 | 型（ソースの宣言） |
|---|---|---|---|
| `Benitoite.Assert.equal` | `Io` | 2 | `function[T: equality](T, T) -> Unit` |
| `Benitoite.Assert.notEqual` | `Io` | 2 | `function[T: equality](T, T) -> Unit` |
| `Benitoite.Assert.isTrue` | `Io` | 2 | `function(Boolean, String) -> Unit` |
| `Benitoite.Assert.fail` | `Io` | 1 | `function[T](String) -> T` |

四つの本体は、引数を使わずに `Err(Stop::Internal(…))` を返す（説明は `"Assert operation reached the handler table"`）。この本体は最終の形であり、後の作業は書き換えない。`Assert` の操作は、どの言語のハンドラも処理しなかったときに、VM が送り出しの列に置かずにテストの実行器へ渡す（本章「`Assert.Check` の処理」）ので、ハンドラ表の関数としては呼ばれないからである。`run` の経路では、`main` のエフェクトに `Assert.Check` を書けない（E0415）ので、型検査を通ったプログラムがこの本体に達することはない。達したら処理系の不具合である。

引数の Rust の型は `Value<'e>` でよい（10-12「まだ書かない項目の仮の本体」と同じ）。10-12 の照合のテスト（F06）は、この部分を含めて通る。

## `Assert.Check` の処理

`Assert.Check` の操作は、次のように処理する（[README](../README.md) の「U3・U4 で決めたこと」の 12、02-11「テストの実行」、02-09「操作の振り分け」）。

1. VM は、`IO` の命令で、ほかの組み込みの操作と同じく、そのタスクのハンドラの連鎖から操作の節を探す（10-07 の命令の表の `IO`）。見つかれば、その節を実行する。利用者が `Assert.Check` を処理する言語のハンドラを書いたときは、この手順で先に処理される。
2. 見つからず、実行ごとの状態に `AssertTable` があり、`BuiltinRef::id` が `AssertTable::op_of` で `Assert` の操作と分かれば、VM は要求を送り出しの列に置かず、その場で `assert::evaluate` を呼ぶ。直接呼び出しと要求と応答のどちらの方式でも同じに扱う。
3. `AssertVerdict::Passed` なら、結果のレジスタに `()` を入れて次の命令へ進む（02-11 の「確認が成り立てば操作の呼び出しに `()` を返して続け」）。
4. `AssertVerdict::Failed` なら、VM は、枠を一つも降ろさないうちに `CheckFailure`（操作、文字列、書き出した値、呼んだ命令、呼び出しの枠、タスクの起動の履歴）を作って実行ごとの状態に置き、`StopReason::CheckFailed(操作の名前)`（`"Assert.equal"` など）で止める手順を始める（02-08「止める手順」の「テストの確認の失敗」）。止める手順は `Process.exit` と同じく、すべてのタスクの枠を降ろし、`with` のリソースを内側から解放する。
5. `evaluate` が `Err(Stop)` を返したら、その停止で止める（処理系の不具合）。

手順 2 はどのタスクでも行うので、起動したタスクで呼んだ `Assert` の操作も同じに処理される。02-11 の「最初のタスクのハンドラの連鎖の最も外側に置く組み込みのハンドラで、起動したタスクにも引き継がれる」と同じ結果になる。引き継いだハンドラの節は末尾で再開しなければならない（ADR 0151）が、手順 3 はすぐに続けるので、この条件を満たす。

`AssertTable` がないとき（`run` の経路）は、手順 2 を行わず、ほかの組み込みの操作と同じく送り出しの列に置く。表の本体が `Stop::Internal` を返す。

### 確認と値の書き出し

`evaluate` は、操作ごとに次のように確かめる。

| 操作 | 失敗する条件（06-04） | `Failed` の `message` | `left`・`right` |
|---|---|---|---|
| `Assert.equal(actual, expected)` | 10-08 の `runtime::equal::values_equal` が偽 | `assertion failed: Assert.equal` | 二つの値を書き出したもの |
| `Assert.notEqual(actual, expected)` | `values_equal` が真 | `assertion failed: Assert.notEqual` | 同上 |
| `Assert.isTrue(condition, message)` | `condition` が偽 | 引数の `message` | `None` |
| `Assert.fail(message)` | 常に | 引数の `message` | `None` |

値の書き出し（`render_value`）は、値を 03-06「標準の型クラス（初回リリース版）」の `Show.show` の形に揃えて書く（06-04「結果の報告」の「値は、処理系が人間の読める形に書き出す」）。値だけでは構成子の名前もフィールドの名前も分からない（VM の値は構成子のタグしか持たない。10-07「構成子のタグ」）ので、`Assert.equal`・`Assert.notEqual` を呼んだ式の静的な型を使う。

- 型は、テストの実行器がファイルの検査の結果から `AssertTable::build` で集める。利用者のモジュールの AST を辿り、`Assert.equal`・`Assert.notEqual` の操作の束縛（10-04 の `stdlib_names` の `Benitoite.Assert.equal`・`Benitoite.Assert.notEqual`）を名前で指す呼び出しの式ごとに、その名前のノードの型引数（10-05 の `TypeckOutput::type_args` の最初の型）を、呼び出しの式の span を鍵として `value_types` に入れる。パイプの右辺の呼び出しは、パイプの式全体の span も鍵にする。脱糖は、呼び出しの計算の由来位置を、呼び出しの式（パイプの展開ではパイプの式全体）とするからである（02-02「合成ノードの由来位置」）。
- VM は、操作を呼んだ命令の由来位置（10-13 の `runtime::report::instr_span`）を `evaluate` に渡し、`evaluate` はそれで型を引く。

型ごとの書き方は次のとおりである。値の中を辿る処理は、実行時の値を辿るので、Rust の再帰でなく明示の積み重ねで書く（00-02「再帰の深さ」）。

| 型 | 書き方 |
|---|---|
| `Integer`・`Float`・`Decimal`・`Byte` | それぞれの `toString` と同じ文字列（`Float` は 10-01 の `base::prim::float_to_text`） |
| `Boolean`・`Unit` | `true`・`false`、`()` |
| `String`・`Character` | リテラルの形（`Trait.showString`・`Trait.showCharacter` と同じエスケープ） |
| `List[T]` | `[1, 2, 3]` |
| `Map[K, V]`・`Set[T]` | `Map.fromList([Pair(1, "a")])`・`Set.fromList([1, 2])`。要素は鍵の順序 |
| `Bytes` | `Bytes.fromList([1, 2])`（要素は `Byte.toString`） |
| 代数的データ型 | `型.構成子` と、引数があれば `(引数, …)`。構成子が一つで型と同じ名前のもの（`Pair`・`Triple`）は型で修飾しない（10-14「書き方の方針」の修飾の規則と同じ） |
| レコード | `Person(name: "a", age: 3)`（フィールドを宣言の順に） |
| 中身を見せない組み込みの型 | `<型の名前>`（10-05 の組み込みの型の表の名前） |

型が分からないとき（鍵に当たる型がない、型が型パラメータを含む）は、値の形だけから書く。数・文字・文字列・リスト・マップ・集合は上の表と同じに書き、構成子の値は、型の名前と構成子の名前の代わりに `<constructor #タグ>` と書く（引数があれば `(引数, …)` を続ける）。型パラメータを持つ補助の関数の中で `Assert.equal` を呼ぶと、このように書かれる。

## テストの関数の実行

`runtime::run::run_test` は、`run_program` と同じ実行の流れ（02-09「プログラムの実行の流れ」の手順 2〜5）で、`main` の代わりにテストの関数を最初のタスクとして呼ぶ（02-11「テストの実行」）。`RunEnv` は、テストの実行器が次のように作る。

| 欄 | 値 |
|---|---|
| `input` | 引数は空の並び、基準のディレクトリは `CliEnv::working_directory`、実行を始めるスクリプトのディレクトリはそのファイルから求める（10-13 の `run_input`） |
| `stdin` | `StdinSource::Empty` |
| `stdout`・`stderr` | テストごとに新しい `OutputTarget::Capture` |
| `interrupt` | `test` のコマンドの一回の実行で一つ作った中断の要求の読み口を、テストごとの `RunEnv` で共有する（共有の包みは D11 が非公開の型で書く） |
| `parts` | 常に `None`（`RuntimeParts` は Clone できず、テストごとの `RunEnv` に渡せない） |
| `mode` | `CliEnv::mode` |
| `vm` | `max_call_stack_bytes` は `--max-call-stack` の値（06-01。一つのテストごとの上限） |
| `heap` | `CliEnv::heap` |
| `dev_panic_after_first_write` | 偽 |

終わり方と終了状態は次のとおりとする。10-13「実行の流れ」の表のうち `CheckFailed` の行を、この表で定める。

| VM の結果 | `run.end` | `run.exit_code` | `run.reports` | そのほかの欄 | テストの結果（06-04） |
|---|---|---|---|---|---|
| `Finished(MainOutcome::Ok)` | `Returned` | 0 | なし | — | 成功 |
| `Finished(MainOutcome::Error(msg))` | `MainError` | 1 | なし（`main_error` に `msg`） | — | 失敗（`"error"`） |
| `Stopped` で `Error(info)`、`Stop::Internal` でない | `Stopped` | 1 | `run_program` と同じ | — | 失敗（`"runtime"`） |
| `Stopped` で `Exit(code)` | `Exited(code)` | `code` | `run_program` と同じ | — | 失敗（`"exit"`） |
| `Stopped` で `CheckFailed(_)` | `CheckFailed` | 1 | なし | `check_failure` に記録、`release_failures` に止める途中の解放の失敗 | 失敗（`"assert"`） |
| `Stopped` で `Interrupted` | `Interrupted` | 130 | `run_program` と同じ | — | 実行器を止める |
| `Stopped` で `Stop::Internal`、捕らえた panic | `Internal` | 3 | `run_program` と同じ | — | 実行器を止める |

出力の最後の転送の失敗の扱いは `run_program` と同じである（10-13「実行の流れ」）。捕らえる出力先への転送は失敗しない。

`run_test` の中身は、`run_program` と共通の非公開の関数にまとめてよい。そのとき `run_program` のシグネチャと振る舞いは変えない。

```rust sig=src/runtime/run.rs needs=10-07,10-09
use crate::bytecode::program::{MainKind, ProtoIdx};
use crate::runtime::ReleaseFailure;
use crate::runtime::assert::{AssertTable, CheckFailure};

/// テストの関数一つの実行の指定（02-11「テストの実行」）。
#[derive(Clone, Debug)]
pub struct TestTarget {
    /// テストの関数の原型（10-07 の `CompiledProgram::top_fns` から引く）
    pub proto: ProtoIdx,
    /// 戻り値の型（`Unit` か `Result[Unit, String]`）
    pub kind: MainKind,
    /// ファイル一つの検査の結果から作った表。そのファイルのテストで共有する
    pub assert: Arc<AssertTable>,
}

/// テストの関数一つの実行の結果。
#[derive(Debug)]
pub struct TestEnd {
    /// 終わり方と報告（本章「テストの関数の実行」の表）
    pub run: RunEnd,
    /// `run.end` が `EndKind::CheckFailed` のときの確認の失敗の記録
    pub check_failure: Option<CheckFailure>,
    /// `run.end` が `EndKind::CheckFailed` のときの、止める途中の解放の失敗
    pub release_failures: Vec<ReleaseFailure>,
}

/// テストの関数を、引数なしで最初のタスクとして実行する（本章「テストの関数の実行」）。
/// VM の実行を `runtime::panic::catch` で囲み、捕らえた panic は処理系の不具合（終了状態 3）にする。
pub fn run_test(program: &CompiledProgram, target: TestTarget, env: RunEnv) -> TestEnd;
```

```rust append=src/runtime/mod.rs
pub mod assert;
```

`assert` は `runtime::run` の子にせず、`runtime` の直下に置く。`runtime::run` は C01 が宣言し C02 が `run.rs` として置くので、その下にファイルを置くと、C01 の時点で道具が `run/mod.rs` を作り、`run.rs` と重なるからである。

```rust file=src/runtime/assert.rs
//! テストの実行器が処理する `Assert.Check` の操作（設計書 02-11「テストの実行」、06-04「期待の確認」「結果の報告」、
//! 実装プラン README「U3・U4 で決めたこと」の 12）。どの言語のハンドラも処理しなかった `Assert` の操作を、
//! VM は送り出しの列に置かずに `evaluate` へ渡す。

use std::collections::HashMap;

use crate::base::Span;
use crate::builtins::BuiltinId;
use crate::types::{AdtTable, Ty};
use crate::vm::{FrameRecord, InstrRef, SpawnRecord};

/// `Assert.Check` の四つの操作（06-04「期待の確認」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum AssertOp {
    Equal,
    NotEqual,
    IsTrue,
    Fail,
}

impl AssertOp {
    /// 報告に書く操作の名前。
    pub fn name(self) -> &'static str {
        match self {
            AssertOp::Equal => "Assert.equal",
            AssertOp::NotEqual => "Assert.notEqual",
            AssertOp::IsTrue => "Assert.isTrue",
            AssertOp::Fail => "Assert.fail",
        }
    }
}

/// テストの実行器が VM に渡す表。ファイル一つの検査の結果から一度作り、そのファイルのテストで共有する。
#[derive(Debug)]
pub struct AssertTable {
    /// 組み込みの関数の表の項目と操作の対応（`Benitoite.Assert.equal` などを 10-11 の `lookup_builtin` で引いたもの）
    pub ops: Vec<(BuiltinId, AssertOp)>,
    /// `Assert.equal`・`Assert.notEqual` を呼ぶ式の span → 比べる値の型（本章「確認と値の書き出し」）
    pub value_types: HashMap<Span, Ty>,
    /// 型の中の代数的データ型とレコードを引く表（10-05 の `TypeckOutput::adts` の写し）
    pub adts: AdtTable,
}

/// 確認の結果。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum AssertVerdict {
    Passed,
    Failed {
        message: String,
        left: Option<String>,
        right: Option<String>,
    },
}

/// 確認の失敗の記録。VM が失敗を見つけた時点で、枠を一つも降ろさないうちに作る（10-09 の `StopInfo` と同じ時点）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CheckFailure {
    pub op: AssertOp,
    /// `AssertVerdict::Failed` の `message`
    pub message: String,
    pub left: Option<String>,
    pub right: Option<String>,
    /// 操作を呼んだ命令
    pub at: InstrRef,
    /// 失敗したタスクの呼び出しの枠（内側から外側の順）
    pub frames: Vec<FrameRecord>,
    pub spawns: Vec<SpawnRecord>,
}
```

```rust sig=src/runtime/assert.rs needs=10-08,10-13
use crate::pipeline::CheckedProgram;
use crate::runtime::Stop;
use crate::runtime::heap::{Value, ValueCtx};

impl AssertTable {
    /// 検査を通ったプログラムから表を作る（本章「確認と値の書き出し」）。`Assert` の操作が組み込みの関数の表か
    /// 標準ライブラリの名前の索引にないときは、処理系の不具合として説明の文字列を返す。
    pub fn build(checked: &CheckedProgram) -> Result<AssertTable, String>;

    /// 組み込みの関数の項目が `Assert` の操作なら、その操作を返す。
    pub fn op_of(&self, id: BuiltinId) -> Option<AssertOp>;
}

/// 確認を行う（本章「確認と値の書き出し」）。`args` は操作の引数、`site` は操作を呼んだ命令の由来位置。
pub fn evaluate<'e>(ctx: &ValueCtx<'e>, table: &AssertTable, op: AssertOp, args: &[Value<'e>], site: Option<Span>) -> Result<AssertVerdict, Stop>;

/// 値を 03-06 の `Show.show` の形に揃えて書き出す。`ty` が `None` か型パラメータを含むときは、値の形だけから書く。
pub fn render_value<'e>(ctx: &ValueCtx<'e>, table: &AssertTable, value: Value<'e>, ty: Option<&Ty>) -> Result<String, Stop>;
```

VM の側は、テストの関数を最初のタスクにする関数と、確認の失敗の記録を取り出す関数を加える。`AssertTable` と最初のタスクの戻り値の型は、`RunState` の欄として D10 が加える（10-09「実行ごとの状態」の「欄は作業が決める」）。`start_test` を呼ばない実行（`run`）では、`AssertTable` の欄は空である。

```rust sig=src/vm/mod.rs needs=10-07
use std::sync::Arc;

use crate::bytecode::program::MainKind;
use crate::runtime::assert::{AssertTable, CheckFailure};

impl<'p> Vm<'p> {
    /// テストの関数 `proto` を引数なしで呼ぶ呼び出しの枠一つを積んだ最初のタスクを作り、`Assert` の操作の表を置く
    /// （02-11「テストの実行」）。最初のタスクの戻り値は、`CompiledProgram::main_kind` の代わりに `kind` で読む。
    /// `proto` が表にないときは、枠を積まずに `Stop::Internal` の記録を返す。
    pub fn start_test(&mut self, proto: ProtoIdx, kind: MainKind, assert: Arc<AssertTable>) -> Result<(), Box<StopInfo>>;

    /// 確認の失敗で止めたときの記録を取り出す（取り出した後は空になる）。
    pub fn take_check_failure(&mut self) -> Option<CheckFailure>;
}
```

## 結果の報告

テストの実行器は、ファイルを指定した順（ディレクトリの下ではパスの辞書順）に検査とコード生成を行い、ファイルの中のテストの関数を宣言の順に一つずつ実行する（06-04「テストの実行」、ADR 0206）。テストは並行に動かさない（[README](../README.md) の「U3・U4 で決めたこと」の 13）。報告は ADR 0252 の形で、標準出力に書く。

### ファイルごとの手順

1. 与えたパスから、テストするファイルの並びを作る（`test_entries`）。ファイルは 10-13 の `pipeline::entry_spec` でそのまま扱い、ディレクトリは 10-17 の `bnt_files` で展開して、根のディレクトリを指定したディレクトリにする（ADR 0206 の決定 2）。表示名は、ディレクトリのパスに相対パスを続けたものとする。パスのディレクトリを読めないときは、E0101（`path` と `reason`）を `--diagnostics` の形式で `env.stderr` に書き、テストを一つも実行せずに終了状態 2 とする。
2. `pipeline::check`（`require_main` は偽、`deny_warnings` は `--deny-warnings`）で検査する。検査の診断は、`--diagnostics` の形式で `env.stderr` に書く（文章の形式は `render_check_text`、`Verb::Test`）。誤りがあれば、そのファイルのテストを実行せず、`files_not_run` に数え、次のファイルへ進む。
3. 標準ライブラリのソースの中の誤りは、`check` と同じく処理系の不具合とする（10-13「コマンドの実行」の手順 4）。
4. `collect_tests` でテストの関数を集め、`AssertTable::build` で表を作り、`pipeline::desugar_checked`・`compile` を行う。処理系の制限（`CompileError::Limit`）は診断を書いて `files_not_run` に数える。処理系の不具合は報告を書いて終了状態 3 で終える。
5. テストの関数ごとに、`run_test` を呼び、結果を `TestResult` にする。テストごとの一行（文章の形）か JSON の一行を、そのテストを終えるたびに `env.stdout` に書く。失敗の詳細（文章の形）は、すべてのテストの行の後にまとめて書くので、ファイルのソースの表が使えるうちに `report::text_failure` で文字列にして溜めておく。
6. `run.end` が `Interrupted` なら、残りのテストとファイルを実行せず、集計に `interrupted` を立てて報告を終える。`Internal` なら、報告（`run.reports`）を `env.stderr` に書き、終了状態 3 で終える（02-11「テストの実行」の「処理系の不具合が起きたときは、ほかのテストを続けず」）。テストごとの行（文章の形の一行か JSON の一行）はテストを終えるたびに書くので、それまでのテストの行は既に出ている。このとき書かないのは、溜めておいた失敗の詳細（`failures:` の節）と集計の行だけである。

中断の要求の読み口は、コマンドラインを解釈した後、最初の検査の前に 10-13 の `process_interrupt` で一度だけ作る（`env.interrupt` があればそれを使う）。ファイルの検査の前にも読み口を調べ、要求があれば手順 6 と同じく終える。

### 文章の形

```text
test tests/sum.bnt: "adds two numbers" ... ok
test tests/sum.bnt: sumOfEmpty ... FAILED

failures:

---- tests/sum.bnt: sumOfEmpty ----
assertion failed: Assert.equal
  left:  3
  right: 4
  --> tests/sum.bnt:14:3
   = note: call trace (innermost first):
             sumOfEmpty
   = note: functions left by tail calls are not shown

test result: FAILED. 12 passed; 1 failed
```

- テストの名前は、`@test` の説明があれば、説明を `Trait.showString` と同じ形の文字列リテラルにしたもの、なければ関数の名前である。
- 失敗がなければ、`failures:` の節を書かない。テストの行と集計の行の間には空の行を一つ置く。
- 失敗の詳細は、理由ごとに次のとおりとする。どの理由でも、捕らえた出力があれば、その後に `text::CAPTURED_STDOUT`・`text::CAPTURED_STDERR` の見出しに続けて示す（捕らえたバイト列を、正しくない UTF-8 を U+FFFD に置き換えて書く）。失敗したテストの詳細の間には空の行を一つ置く。

| 理由 | 詳細 |
|---|---|
| `"assert"` | `text::ASSERT_FAILED`、`Assert.equal`・`notEqual` では `text::LEFT`・`text::RIGHT`、`isTrue`・`fail` では `text::MESSAGE`。続けて、位置の行と呼び出しの履歴（10-02 の `render_trace_text`）。止める途中の解放の失敗は、10-13 の `add_release_failures` と同じ注記の文で示す。注記の並びは実行時エラーの報告と同じく、解放の注記を末尾呼び出しの注記の前に置く |
| `"error"` | `text::RETURNED_ERROR` |
| `"runtime"` | 実行時エラーの報告を `render_one_text` で書いたもの |
| `"exit"` | `text::EXITED`。解放の失敗の報告があれば `render_one_text` で続ける |

- `"assert"` と `"runtime"` では、タスクの起動の履歴の最後の段と、行き詰まり（R1001）の報告で待つ最初のタスクを、`main` ではなくテストの関数の名前にする（[ADR 0324](../../2026-10-09-design-first-release/decisions/0324-test-task-origins-end-at-test-function.md)）。`runtime::report` はこれらを常に `main` の段にするので、テストの実行器が `Failure` を作るときに、報告のデータ（`Diagnostic` の `task_origins`・`waiting` と `Failure::Assert` の `task_origins`）の上で書き換える。文字列にした後の置換はしない。JSON Lines の形も、書き換えた報告から書く。

- 集計の行は `text::RESULT` で、`{outcome}` は、`failed` が 0、`files_not_run` が 0、中断の要求で終えていない、のすべてを満たすときだけ `text::OUTCOME_OK`、ほかは `text::OUTCOME_FAILED` とする（終了状態が 0 になるときだけ `ok`）。検査の誤りで実行しなかったファイルがあれば `text::FILES_NOT_RUN` を、中断の要求で終えたときは `text::INTERRUPTED` を続ける。テストが一つもないときも集計の行を書く。

### JSON Lines の形

`--diagnostics=json` のときは、テストごとに `kind` が `"test"` の一行、最後に `kind` が `"testSummary"` の一行を `env.stdout` に書く（ADR 0252 の決定 5〜7）。項目の順は次のとおりとし、`:` と `,` の後に空白を入れない（10-02「診断の書き出し」と同じ）。

- `"test"`: `kind`・`file`・`name`・`function`・`location`・`outcome`・`failure`・`stdout`・`stderr`。`name` は説明（引用符を付けない文字列）か関数の名前、`location` は関数の名前の span の位置の形（10-02 の `json_location`。ラベルは空の文字列）、`failure` は成功では `null`。
- `failure` の項目: `"assert"` は `reason`・`message`・`primary`・`notes`・`trace`・`traceOmitted`・`taskOrigins`、`Assert.equal`・`notEqual` では続けて `left`・`right`。`"error"` は `reason`・`message`。`"exit"` は `reason`・`message`（`text::EXITED` の文）・`exitCode`・`notes`。`notes` は注記の文字列の配列で、実行時エラーの報告の JSON の `notes` と同じ形に書く（[ADR 0333](../../2026-10-09-design-first-release/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 2、06-04「結果の報告」）。
  - `"assert"` の `notes` は、`Failure::Assert` の `notes`（止める途中の解放の失敗の注記。10-13 の `add_release_failures` と同じ `codes::text::RELEASE_WHILE_STOPPING` の文）を順に並べ、最後に `codes::text::TRACE_TAIL_NOTE` を置く。文章の形の詳細の注記と同じ並びである。
  - `"exit"` の `notes` は、`Failure::Exit` の `reports`（10-13 の `release_report` の報告）ごとに、`RELEASE_WHILE_STOPPING` と同じ文を一つずつ並べる。報告の `message` は R0401 の文言（``failed to release `{resource}` opened at {location}``）で、最初の注記が失敗の理由なので、文は `while stopping, ` に `message` を続け、`: ` と最初の注記を続けて作る。付ける語は `test_runner` の `text` の定数にしてよい（非公開の定数を加えることは、凍結したコードを変えることに当たらない）。`reports` が空なら空の配列とする。`"runtime"` は `{"reason":"runtime",` の後に、実行時エラーの報告を `render_json_line` で書いた一行の先頭の `{` を除いたものを続ける（実行時エラーの報告の JSON の形式の項目を、同じ順でそのまま持つ）。
- `"testSummary"`: `kind`・`passed`・`failed`・`filesNotRun`・`interrupted`。

### 終了状態

06-01「`test` のコマンドライン」の表のとおり、当たる行のうち最も上の行の値で終える: 中断の要求 130、処理系の不具合 3、検査の誤り・処理系の制限・読めないファイル・使い方の誤り 2、失敗したテスト 1、ほか 0。使い方の誤りは、10-17 の `parse_path_args` の文を 10-13 の `cli::text::USAGE_ERROR` に埋めた行と `SEE_HELP` の行を `env.stderr` に書く。

```rust append=src/cli/tools.rs
pub mod test_runner;
```

```rust file=src/cli/tools/test_runner/mod.rs
//! `benitoite test`（設計書 06-04「テストの実行」「結果の報告」、06-01「`test` のコマンドライン（初回リリース版）」、
//! 02-11「テストの実行」、ADR 0206・0208・0252）。テストは一つずつ別の実行として順に動かす。

pub mod report;

use crate::base::{BindingId, Span};
use crate::bytecode::program::MainKind;
use crate::diag::{CallTrace, Diagnostic, TraceFrame};
use crate::runtime::assert::AssertOp;

/// テストの関数一つ（06-04「テストの関数」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TestFn {
    /// 関数の名前
    pub function: String,
    /// `@test("…")` の説明。省いたときは `None`
    pub description: Option<String>,
    /// 関数の名前の span（JSON の `location`）
    pub location: Span,
    pub binding: BindingId,
    /// 戻り値の型
    pub kind: MainKind,
}

/// 失敗の理由と詳細（06-04「結果の報告」の表、ADR 0252 の決定 6）。
#[derive(Clone, PartialEq, Debug)]
pub enum Failure {
    /// `Assert` の確認の失敗
    Assert {
        op: AssertOp,
        message: String,
        left: Option<String>,
        right: Option<String>,
        /// 失敗した確認の位置（操作を呼んだ命令の由来位置）
        primary: Option<Span>,
        trace: CallTrace,
        task_origins: Vec<TraceFrame>,
        /// 止める途中の解放の失敗の注記
        notes: Vec<String>,
    },
    /// `Result.Error(message)` を返した
    Error { message: String },
    /// 実行時エラーか資源の不足（解放の失敗の注記を加えた報告）
    Runtime { report: Box<Diagnostic> },
    /// `Process.exit` で止まった。`reports` は止める途中の解放の失敗の報告
    Exit { code: u8, reports: Vec<Diagnostic> },
}

/// テスト一つの結果。
#[derive(Clone, PartialEq, Debug)]
pub struct TestResult {
    pub test: TestFn,
    /// 成功なら `None`
    pub failure: Option<Failure>,
    /// 捕らえた標準出力と標準エラー出力
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
}

/// 集計（ADR 0252 の決定 3・7）。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct Summary {
    pub passed: u32,
    pub failed: u32,
    /// 検査の誤りか処理系の制限で実行しなかったファイルの数
    pub files_not_run: u32,
    /// 中断の要求で終えたか
    pub interrupted: bool,
}

/// 報告の文（ADR 0033、ADR 0252）。`{名前}` は埋める値。
pub mod text {
    pub const TEST_LINE: &str = "test {file}: {name} ... {outcome}";
    pub const OUTCOME_OK: &str = "ok";
    pub const OUTCOME_FAILED: &str = "FAILED";
    pub const FAILURES: &str = "failures:";
    pub const FAILURE_HEADER: &str = "---- {file}: {name} ----";
    /// `{operation}` は `Assert.equal` など
    pub const ASSERT_FAILED: &str = "assertion failed: {operation}";
    pub const LEFT: &str = "  left:  {value}";
    pub const RIGHT: &str = "  right: {value}";
    pub const MESSAGE: &str = "  message: {value}";
    pub const RETURNED_ERROR: &str = "returned `Result.Error`: {message}";
    pub const EXITED: &str = "called `Process.exit` with status {code}";
    pub const CAPTURED_STDOUT: &str = "---- captured stdout ----";
    pub const CAPTURED_STDERR: &str = "---- captured stderr ----";
    /// `{outcome}` は `OUTCOME_OK` か `OUTCOME_FAILED`
    pub const RESULT: &str = "test result: {outcome}. {passed} passed; {failed} failed";
    pub const FILES_NOT_RUN: &str = "; {count} files not run due to errors";
    pub const INTERRUPTED: &str = "; interrupted";
    /// 処理系の不具合の報告（10-13 の `internal_diagnostic`）の段の名前
    pub const STAGE_TEST: &str = "test";
}
```

```rust sig=src/cli/tools/test_runner/mod.rs needs=10-04,10-13
use std::path::PathBuf;

use crate::base::FileId;
use crate::cli::CliEnv;
use crate::modules::EntrySpec;
use crate::pipeline::CheckedProgram;
use super::args::PathArgs;

/// `benitoite test` を実行し、終了状態を返す（本章「結果の報告」）。
pub fn run_test_command(args: PathArgs, env: CliEnv) -> u8;

/// 与えたパスから、テストするファイルの並びを作る（本章「ファイルごとの手順」の 1）。
/// 読めないディレクトリがあれば、そのパスと理由を返す。
pub fn test_entries(paths: &[PathBuf]) -> Result<Vec<EntrySpec>, (PathBuf, std::io::Error)>;

/// 実行を始めるファイル `entry` のトップレベルの `@test` の関数を、宣言の順に集める（06-04「テストの実行」の
/// 「取り込むモジュールのテストの関数は実行しない」）。
pub fn collect_tests(checked: &CheckedProgram, entry: FileId) -> Vec<TestFn>;
```

```rust sig=src/cli/tools/test_runner/report.rs needs=10-02
//! テストの結果の報告の文章の形と JSON Lines の形（設計書 06-04「結果の報告」、ADR 0252）。

use crate::base::SourceTable;
use crate::diag::render::TextOptions;
use super::{Summary, TestFn, TestResult};

/// テストの名前（説明を文字列リテラルの形にしたものか、関数の名前）。
pub fn test_name(test: &TestFn) -> String;

/// テストごとの一行（改行で終える）。`file` はファイルの表示名。
pub fn text_line(file: &str, result: &TestResult) -> String;

/// 失敗したテスト一つの詳細（`----` の見出しから、捕らえた出力まで）。成功なら空の文字列。
pub fn text_failure(file: &str, result: &TestResult, sources: &SourceTable, opts: TextOptions) -> String;

/// 集計の行（改行で終える）。
pub fn text_summary(summary: &Summary) -> String;

/// テストごとの JSON の一行（末尾に改行を付けない）。
pub fn json_test(file: &str, result: &TestResult, sources: &SourceTable) -> String;

/// 集計の JSON の一行（末尾に改行を付けない）。
pub fn json_summary(summary: &Summary) -> String;
```

## 診断の書き出しに加える関数

確認の失敗の位置と呼び出しの履歴は、実行時エラーの報告と同じ形で書く（ADR 0252 の決定 2・6）。その部分だけを書く関数を 10-02 の `render.rs` に加える。中身は D11 が、F16 の書いた `render_one_text`・`render_json_line` の同じ部分と共通にして書く。`render_trace_text` の位置の行の字下げは、`render_one_text` と同じく溝の幅（主な位置の行番号の桁数、最小 2）の空白とする（本章「文章の形」の例の `  --> tests/sum.bnt:14:3`）。下のコメントの ` --> ` は行の形を示したもので、字下げの数を定めたものではない。

```rust sig=src/diag/render.rs
/// 位置の行（主な位置があれば ` --> ファイル:行:列`。抜粋は書かない）と、呼び出しの履歴・タスクの起動の履歴・末尾呼び出しの
/// 注記の行を、`render_one_text` の同じ部分と同じ形で書く（02-10「実行時エラーと資源の不足の報告」）。
pub fn render_trace_text(primary: Option<crate::base::Span>, trace: &super::CallTrace, task_origins: &[super::TraceFrame], sources: &SourceTable, opts: TextOptions) -> String;

/// 位置を JSON の位置の形（`file`・`start`・`end`・`label`）のオブジェクトにする。
pub fn json_location(span: crate::base::Span, label: &str, sources: &SourceTable) -> String;

/// 呼び出しの履歴を、JSON の `"trace":[…],"traceOmitted":n,"taskOrigins":[…]` の項目の並びにする（前後の `{`・`}` と
/// 先頭の `,` を含めない）。
pub fn json_trace_fields(trace: &super::CallTrace, task_origins: &[super::TraceFrame], sources: &SourceTable) -> String;

/// 文字列を JSON の文字列（引用符を含む）にする。
pub fn json_string(text: &str) -> String;
```

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| D00 | 本章の `file=`・`append=` と、`sig=` の `todo!()` の仮置き、`Assert` のソースと `STDLIB` の項目、組み込みの関数の表の部分（`funcs/assert.rs` と `PARTS`） |
| D10 | `runtime::run::run_test`、`runtime::assert` の関数、`Vm::start_test`・`take_check_failure`、VM の `IO` の命令の手順 2〜5（R20・R26 が書いた命令の処理に分岐を加える）、`RunState` の欄 |
| D11 | `cli::tools::test_runner` の関数、`render.rs` に加えた四つの関数、`cli::tools::run_tool` の `test` の振り分け |
| D12 | ゴールデンテストの `test` の方式 |

## 未定のこと

- なし。型が分からない値の書き方（本章「確認と値の書き出し」の最後の段落）は、06-04 が定めていないので本章で `<constructor #タグ>` と決め、設計者が確かめた（2026-09-30。README の「U4 の作業の文書で見つかった点」の 1）。
