# F18 パイプラインと CLI

- 依存する作業: [F11](F11-desugar.md), [F15](F15-codegen.md), [F16](F16-diagnostics.md), R09, R38
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）（テストを含む Rust の行数の目安）
- ブランチ: impl/F18-pipeline-cli

## 目的

初回リリース版の段をつなぐ公開の関数（`pipeline`）、実行の流れ（`runtime::run`）の最初の形、CLI（`cli`）を書く。検査は実行を始めるファイルから import を辿ってプログラム全体を読み（ADR 0156）、ディレクトリを指定した実行（ADR 0127）と `run` を省いた実行・シェバンによる実行（ADR 0135）、警告と `--deny-warnings`（ADR 0166）、予約したサブコマンドの名前（ADR 0209）を扱う。

実行の流れは、第 1 段の VM の実行の関数（10-09 の `Vm::run_stage1`・`serve_request_stage1`）と、R08 の第 1 段の `IoServices` の一時的な実装で書く。R26 が第 2 段の IO 実行器へ、R27 が出力の最後の転送へ、R28 が中断の要求へ中身を移す。どの段階でも、10-13 のシグネチャは変えない。

本作業の後、C05 が `main.rs` を `cli::main` を呼ぶ形に切り替え、ゴールデンテストの実行器（C10）が `cli::execute` で書き直した最小実行版のテストを走らせる。本作業は `main.rs` を変えない。CLI のプロセスのテスト（`tests/cli_process.rs`）は C05 まで最小実行版の CLI を確かめ続けるので、本作業は `cli::execute` を直接呼ぶテストで確かめる。

R08 の第 1 段の `IoServices` の一時的な実装は、F06 が R08 に依存するので、F11 を経て取り込み済みである。

## 読む設計書の節

- [パイプライン](../../2026-10-09-design-first-release/02-impl/02-01-pipeline.md)の「段と段の間のデータ」「検査と実行の経路」「誤りが見つかったときの段の進め方」「関数の呼び出しと処理系のスタック」
- [スクリプト実行と埋め込み](../../2026-10-09-design-first-release/02-impl/02-11-embedding.md)の「状態の分け方」「実行を始めるファイルとプログラムの読み込み」「CLI の一回の実行」「実行の入力と結果」
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「中断の要求」「panic 境界」「プログラムの実行の流れ」「出力のバッファ」
- [ソース管理と位置情報](../../2026-10-09-design-first-release/02-impl/02-02-source-and-spans.md)の「ソースとファイル ID」（表示名）
- [診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「警告の扱い」「文章の形式」「JSON の形式」「処理系の不具合と処理系の制限の報告」
- [CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md)の「コマンドラインの形」「ディレクトリの指定（初回リリース版）」「`run` を省いた実行とシェバン（初回リリース版）」「予約したサブコマンドの名前（初回リリース版）」「オプション」「サブコマンドの振る舞い」「標準入出力」「終了状態」「開発用の設定」
- [字句構造](../../2026-10-09-design-first-release/01-spec/01-01-lexical.md)の「シェバンの行（初回リリース版）」
- ADR: [0019](../../2026-10-09-design-first-release/decisions/0019-stop-after-failing-stage.md)、[0037](../../2026-10-09-design-first-release/decisions/0037-exit-status-values.md)、[0087](../../2026-10-09-design-first-release/decisions/0087-pipeline-stages-on-large-stack-thread.md)、[0127](../../2026-10-09-design-first-release/decisions/0127-directory-run-and-root.md)、[0131](../../2026-10-09-design-first-release/decisions/0131-script-directory-and-permission-base.md)、[0135](../../2026-10-09-design-first-release/decisions/0135-shebang-line-and-implicit-run.md)、[0156](../../2026-10-09-design-first-release/decisions/0156-module-loading-and-whole-program-checking.md)、[0165](../../2026-10-09-design-first-release/decisions/0165-exit-and-stdio-in-embedded-runs.md)、[0166](../../2026-10-09-design-first-release/decisions/0166-warnings-reported-by-run-and-deny-option.md)、[0209](../../2026-10-09-design-first-release/decisions/0209-reserved-subcommand-names.md)、[0243](../../2026-10-09-design-first-release/decisions/0243-signal-exit-code-and-posix-shell.md)
- インターフェース: [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の全体、[モジュールと名前解決](../10-interfaces/10-04-modules-and-resolve.md)の「読み込みの段」、[標準ライブラリのソース](../10-interfaces/10-14-prelude-and-stdlib-sources.md)の「置き方」（`STDLIB`）、[診断](../10-interfaces/10-02-diagnostics.md)の「診断の書き出し」、[仮想機械](../10-interfaces/10-09-vm.md)の「第 1 段の実行の関数」と `Vm::new`・`start_main`・`VmStep`・`StopEnd`、[スケジューラと IO](../10-interfaces/10-10-scheduler-and-io.md)の `RunInput`・`InterruptSource`、[組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の「ランタイムの口」（`IoServices`）、[値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「panic 境界」と `HeapConfig`・`HeapStats`
- [実装の規約](../00-common/00-02-conventions.md)の「`#[allow]` を書いてよい箇所」（`BENITOITE_DEV_PANIC`）

## 作るもの

- `src/pipeline.rs`: 10-13 の `sig=src/pipeline.rs` の関数。`src/legacy/pipeline.rs` を写して広げてよい。
- `src/runtime/run.rs`: 10-13 の `sig=src/runtime/run.rs` の関数（`OutputTarget::write_bytes`・`is_terminal`、`check_args`、`run_input`、`process_interrupt`、`run_program`）。`src/legacy/runtime/run.rs` を写して広げてよい。
- `src/cli/mod.rs`: 10-13 の `sig=src/cli/mod.rs` の関数（`parse_args`・`parse_size`・`execute`・`main`）。`src/legacy/cli/mod.rs` を写して広げてよい。
- `src/cli/tools.rs`: `run_tool` と `print_licenses` の仮の中身（後述）。
- 各ファイルの `#[cfg(test)] mod tests`。
- `testdata-next/` の下のゴールデンテスト（後述の「受け入れテスト」）。

`main.rs` と `tests/cli_process.rs` は変えない（C05 が改める）。`runtime::report` の関数は R38 が書いたものを呼ぶだけにする。

## 手順の要点

### パイプライン

- `entry_spec` は 10-13 のシグネチャの説明のとおり。ディレクトリの判定は `Path::is_dir` で行う。表示名は、ディレクトリのときはコマンドラインで与えたパスに `main.bnt` を続けた名前（区切りは `Path::join`）、ファイルのときは `Path::display` の文字列とする（02-02「ソースとファイル ID」）。根のディレクトリは、読むファイルの親（親が空なら `.`）。
- `check` は 10-13「段をつなぐ関数」の手順 1〜6 のとおり。標準ライブラリのソースは `prelude::STDLIB` を `load_program` に渡す。`require_main` と `deny_warnings` は `CheckOptions` から取る。
  - 段の中身は、`std::thread::Builder::new().stack_size(STAGE_STACK_BYTES)` で作ったスレッドで行い、`join` の結果が panic なら `std::panic::resume_unwind` で呼び出し側のスレッドで起こし直す（ADR 0087）。`desugar_checked` と `compile` も同じ。`execute` が `run` のときに作ったコア IR と下位 IR（文と要素の数だけ入れ子になる）は、呼び出し側のスレッドで捨てると深いプログラムで溢れうるので、段のスレッドの中で捨てる（コンパイル済みのプログラムだけを返す）。スレッドは `std::thread::scope` と `Builder::spawn_scoped` で作る。`check` の引数 `fs: &(dyn ModuleFs + Sync)` が `'static` でなく、`spawn` には渡せないからである（`src/legacy/pipeline.rs` の `on_large_stack` と同じ形）。スレッドへ渡すものと返すものが `Send` でない場合は、スレッドの中で作って結果だけを返す形にする。
  - 段のスレッドを作れなかったとき（`spawn_scoped` の `Err`）は、`check` は `runtime::report::internal_diagnostic`（段は `check`、スレッドは `FaultThread::Stage`）で作った診断を `diagnostics` に入れ、`program` を `None` にして返す。`execute` は、検査の結果の診断に報告の種類（`ReportKind`）が `Internal` のものがあれば、終了状態 3 の処理系の不具合として扱う。
  - `check` に限り、段のスレッドの中で `runtime::panic::catch` で囲み、panic を `PanicReport` として返す形にしてもよい（`desugar_checked` と `compile` は戻り値が `PanicReport` を持てないので、`resume_unwind` で起こし直す形にする。panic の場所が分からない報告になる制約は受け入れる）。panic hook は panic の内容を、panic を起こしたスレッドのスレッドローカルな記憶域に記録するので、呼び出し側のスレッドの `runtime::panic::take_report` では取り出せないからである（`src/runtime/panic.rs`）。この形をとったときは、返した `PanicReport` を `internal_diagnostic` の `panic` に渡し（スレッドは `FaultThread::Stage`）、処理系の不具合として報告する。
  - 診断の並べ替え（手順 6）は、段ごとに、主な位置のファイル ID、開始の位置の順の安定な並べ替えで行う。主な位置のない診断は、その段の最後に置く。
  - 標準ライブラリのソースの中を主な位置とする警告を除く（手順 5）。ソースの種類は `SourceKind::Prelude` で判定する。誤りは除かない。この除去は、次の `deny_warnings` の扱い（手順 4）より先に行う（10-13 の手順 4・5）。
  - `deny_warnings` のときは、誤りで途中の段で止めた場合も含めて、除いた後に残ったすべての警告に `Diagnostic::deny_warning` を適用し、警告が一つでもあれば `program` を `None` にする（手順 4）。
  - `entry` は、読み込みの段が実行を始めるファイルを読めたときの、そのファイル ID（作業の一覧の最初のファイル）である。
- `check_path` は `entry_spec` と `RealFs` で `check` を行う。
- `check_files` は、ファイルシステムを使わない `ModuleFs` の実装を本ファイルの非公開の型として書き、仮の根のディレクトリ（`/` などの絶対パスでよい）の下に `files` の各パスを置く。`list_dir` は、与えたパスから作ったディレクトリの項目を返し、`canonicalize` はパスをそのまま返す。最初の要素が実行を始めるファイルで、表示名はそのパスとする。F05 がテスト用に置いたメモリの上のファイルシステム（`#[cfg(test)]`）は公開の関数から使えないので、同じ振る舞いのものを本ファイルに書く（大文字と小文字の照合は F05 の本番の実装と同じく、項目の名前の一覧で行う）。
- `check_text` は `check_files(&[(name, text)], opts)`。
- `desugar_checked` は 10-06 の `desugar`、`compile` は `ir::decision::lower_program` と `bytecode::codegen::codegen` を呼ぶ。`CodegenError::Limit` は `CompileError::Limit`、`InternalError` は `CompileError::Internal` にする。

### 実行の流れ

`run_program` は、02-09「プログラムの実行の流れ」の手順 2〜5 を、第 1 段の実行の関数で行う。

1. R08 の第 1 段の `IoServices` の一時的な実装（`src/builtins/funcs/stage1_io.rs`。本番の出力とテスト用の出力の二つ）を、`env.input`（引数、基準のディレクトリ、スクリプトのディレクトリ）から作る。`stdout` が `OutputTarget::Stdout`、`stderr` が `OutputTarget::Stderr` なら本番の出力を、`Capture` を含むならテスト用の出力を使い、`Capture` の出力先には、テスト用の出力が捕らえたバイト列を書いた順に写す（最後の書き出しの位置で写す）。`Stdout`・`Stderr` と `Capture` が混ざる組と、`stdout` に `Stderr` を置くなど取り違えた組は、テストの口として使わないので、使い方の不具合として `Stop::Internal` と同じく処理系の不具合にしてよい。R08 の実装の作り方がこれを受け付けないときは、作業を止めて報告する（後述の「確認の観点」の最後の項目）。`Capture` のときもテスト用の出力（`TestIo`）のままとし、その環境変数（`TestIo::environment`）は空、時計（`now`・`monotonic`）と地方時の差と乱数の値は 0 である（`TestIo::new` の初期値）。R26 が IO 実行器へ移すまで、C10 のゴールデンテストはこの値で走る。
2. `Vm::new(program, env.vm, env.heap)`、`start_main`。`start_main` の失敗は `StopInfo` として止まった場合と同じく扱う。
3. `runtime::panic::catch` で囲んで `run_stage1(services, env.mode)` を行う。要求と応答の方式（`ExecMode::Request`）では、`VmStep::Requests(ids)` を受けるたびに、各 `id` を `serve_request_stage1` で行ってから `run_stage1` を呼び直す。
4. 10-13「実行の流れ」の表のとおりに `EndKind`・報告・終了状態を決める。報告は R38 の `stop_diagnostic`・`add_release_failures`・`release_report`・`internal_diagnostic` で作る。捕らえた panic は、スレッドを `FaultThread::Vm` とする。止める手順の理由が `StopReason::CheckFailed` のときは、`main` の実行では起きないので、処理系の不具合（終了状態 3）とする。`main` の実行が終わったとき（どの終わり方でも）も、`RealIo::take_internal_error`・`TestIo::take_internal_error` を確かめ、`Some` なら処理系の不具合とする（使わないはずの口の呼び出しは、次の書き込みがなければ実行の終わりまで残るため。`src/builtins/funcs/stage1_io.rs` の `take_internal_error` のコメント）。
5. 出力の最後の書き出しは、R08 の実装が持つ書き出しの関数で標準出力、標準エラー出力の順に行い、失敗したときの扱いを 10-13 の表の後の段落のとおりにする（`write_failed`・`add_flush_failure`）。書き出し用のスレッドによる転送は R27 が加える。
6. `RunEnd::heap` は `Vm::heap_stats` の値とする。
7. `env.parts` と `env.stdin` は第 1 段では使わない（第 1 段の IO の組み込みの関数に標準入力を読むものはない）。`dev_panic_after_first_write` が真なら、最初の書き込みを出力に加えた直後に panic を起こす（`#[allow(clippy::panic)]` を付け、理由をコメントに書く。00-02「`#[allow]` を書いてよい箇所」の表の `BENITOITE_DEV_PANIC` の行）。一時的な実装がこの差し込みを持たないときは、`IoServices` を包む非公開の型で行う。

- `check_args` は、`OsString::into_string` の失敗で最初の引数の位置（1 から数える）を R0301 の報告にする。報告の文言は 10-02 の型板で作る。
- `run_input` は、`entry.path` を `std::fs::canonicalize` した絶対パスの親をスクリプトのディレクトリとし、`working_directory` をそのまま基準のディレクトリにする（ADR 0131）。
- `process_interrupt` は、`NoInterrupt` を `Box` に入れて返す仮の中身とする（R28 が書き換える）。`execute` は、`process_interrupt` の `Err` を処理系の不具合（`internal_diagnostic`、終了状態 3）とする。
- `OutputTarget::write_bytes` は、`Stdout` なら標準出力に、`Stderr` なら標準エラー出力に書いて flush し、`Capture` なら末尾に加える。`is_terminal` はそれぞれのストリームを `std::io::IsTerminal` で判定し、`Capture` は偽とする。`cli::main` は `CliEnv` を `stdout: OutputTarget::Stdout, stderr: OutputTarget::Stderr` で作る。

### CLI

- `parse_args` は 10-13「コマンドライン」の規則のとおり。オプションは `--diagnostics=text|json`、`--max-call-stack=<大きさ>`、`--deny-warnings` の三つで、`run`・`check` と `run` を省いた実行で受け付ける。二度の指定は使い方の誤り（`DUPLICATE_OPTION`）。`--check` は `fmt` のオプションなので、`run`・`check` では知らないオプションとする。使い方の誤りの文は `text` の定数から作る。
- `parse_size` は、`KiB`・`MiB`・`GiB` を付けた正の整数だけを受け付け、溢れれば `None`。単位のない値と 0 は受け付けない（06-01「オプション」の書き方に合わせる。本プランの決定）。
- `execute` は 10-13「コマンドの実行」の手順 1〜9 のとおり。手順 4 のとおり、検査の誤りのうち主な位置が標準ライブラリのソース（`SourceKind::Prelude`）の中にあるものが一つでもあれば、処理系の不具合として `internal_diagnostic` を書き、終了状態 3 で終える。この判定（検査の結果から、`SourceKind::Prelude` の位置の最初の誤りを探す）は非公開の小さな関数に分ける。報告は `--diagnostics` の形式で `env.stderr` に書く。文章の形式の色は `env.color`。`EntryError::NoMainFile` は使い方の誤り（`NO_MAIN_FILE`）として `USAGE_ERROR` と `SEE_HELP` の 2 行を書き、終了状態 2 で終える。`--diagnostics=json` でも、使い方の誤りと `main` が返した `Result.Error` の文字列は文章のまま書く（06-01「オプション」）。`DevPanic::Check` は、誤りのない検査の結果を得た後に panic を起こす。
- `Version` は `text::VERSION` の `{version}` にクレートの版（`env!("CARGO_PKG_VERSION")`）、`{unicode}` に `char::UNICODE_VERSION` を `major.minor.update` の形で埋める。
- `Tool` と `Licenses` は、`tools::run_tool`・`print_licenses` の仮の中身を呼ぶ。仮の中身は、`TOOL_UNAVAILABLE`（`{name}` は `test`・`fmt`・`skill`・`--licenses`）を `USAGE_ERROR` に埋めた行と `SEE_HELP` を `env.stderr` に書き、終了状態 2 を返す（10-13「U4 のサブコマンドの入口」）。
- `main` は、`runtime::panic::install_hook` を設定し、`std::env::args_os().skip(1)` を `parse_args` に渡し、環境変数を読んで `CliEnv` を作り、`execute` を呼ぶ。`BENITOITE_DEV_IO_MODE` は `direct`（既定）か `request`、`BENITOITE_DEV_PANIC` はデバッグのビルド（`cfg!(debug_assertions)`）でだけ読み `check` か `run`、`BENITOITE_DEV_ALLOC_STATS` は機能 `alloc-stats` のビルドでだけ読む。それ以外の値は使い方の誤り。`color` は、標準エラー出力が端末で `NO_COLOR` がないときに真。`working_directory` は `std::env::current_dir`（失敗は処理系の不具合として報告する）。`heap` は `HeapConfig` の既定、`parts` は `None`、`interrupt` は `None`。`parse_args` の呼び出しから、使い方の誤りの 2 行の書き出しと `execute` の呼び出しまでは、引数の並びと `CliEnv` を受け取り終了状態を返す非公開の関数に分け、`main` はそれを呼んだ結果を `ExitCode` にする（10-13 の `main` のシグネチャは変えない）。
- 終了状態の値は `runtime::run` の定数（`EXIT_OK` など）を使う。

## 受け入れテスト

テストは、`cli::execute` を `CliEnv` の出力先を `Capture`、標準入力を `Empty`、`interrupt` を `Some(Box::new(NoInterrupt))`、`color` を偽にして呼び、終了状態と捕らえた標準出力・標準エラー出力を確かめる。ファイルを要するテストは、テストの一時ディレクトリにスクリプトを書いて使う。パイプラインの関数は `check_files`・`check_text` で確かめる。使い方の誤りの終了状態 2（「予約した名前」「使い方の誤り」の場合）は、`parse_args` の `Err` の文と、`main` の本体を分けた前述の非公開の関数（引数と `CliEnv` を受け取り終了状態を返す）で確かめる。

| 場合 | 入力 | 期待する結果 |
|---|---|---|
| 実行 | `Console.writeLine("hello")` の `main` を `run`（`Console` は prelude にないので、`import Benitoite.Unofficial.IO.Console` と、`main` の `uses Console.Write` が要る） | 標準出力 `hello\n`、終了状態 0 |
| `run` の省略 | 同じスクリプトを `benitoite <パス>` の形で | 同じ結果 |
| シェバン | 1 行目が `#!/usr/bin/env benitoite` のスクリプト。行番号は、同じくシェバンを持ち 3 行目に型の誤りを置いたスクリプトを `check` して確かめる | 同じ結果。誤りの報告の位置が `:3:` で、シェバンの行を 1 行目として数える |
| ディレクトリの指定 | `main.bnt` と `Lib/Text.bnt` を持つディレクトリを `run`。表示名は、`main.bnt` の 3 行目に型の誤りを置いたディレクトリを `check` して確かめる | import した関数が呼ばれる。誤りの報告の位置が `<ディレクトリ>/main.bnt:3:` の形 |
| `main.bnt` のないディレクトリ | 空のディレクトリ | 標準エラー出力に `NO_MAIN_FILE` と `SEE_HELP`、終了状態 2 |
| 予約した名前 | `server` | 使い方の誤り（`RESERVED_COMMAND`）、終了状態 2 |
| U4 のサブコマンド | `test`、`fmt`、`skill`、`--licenses` | `TOOL_UNAVAILABLE`、終了状態 2 |
| スクリプトの引数 | `run a.bnt --x y` | `--x` と `y` をスクリプトの引数として解釈せずに渡す（`parse_args` の単体テスト） |
| 使い方の誤り | 知らないオプション、値の誤った `--diagnostics`、`--max-call-stack` の二度の指定、スクリプトのパスがない、`check` のパスの後の引数 | 各 `text` の文、終了状態 2 |
| `parse_size` | `512MiB`、`2GiB`、`1KiB`、`0MiB`、`10`、`1TiB`、非常に大きい値 | 前の三つだけ値を返す |
| 検査の誤り | 型の誤りのあるスクリプトを `check` と `run` | 診断（文章）と件数の行、終了状態 2。`run` は実行しない |
| JSON の形式 | 同じスクリプトを `--diagnostics=json` | 1 行に 1 件の JSON |
| 警告 | `@deprecated` を付けた関数を使うスクリプトを `check` と `run` | 警告を書き、`check` は終了状態 0、`run` は実行する |
| `--deny-warnings` | 同じスクリプトに `--deny-warnings` | 警告を誤りとして書き、終了状態 2、実行しない |
| 標準ライブラリの中の警告 | 標準ライブラリのソースの中を主な位置とする警告（テストでは `check_files` の結果の診断で、`SourceKind::Prelude` の位置の警告が除かれていることを確かめる） | 除かれる |
| 診断の順 | 二つのファイルにそれぞれ名前の誤りがあるプログラム | ファイル ID の順、ファイルの中では位置の順 |
| 読み込みの誤りで止める | 一つのファイルに構文の誤り、別のファイルに型の誤り | 構文の誤りだけを報告する |
| `main` の `Result.Error` | `main` が `Result.Error("bad")` を返す | 標準エラー出力に `bad` と改行、終了状態 1 |
| 実行時エラー | `1 div 0` | R0101 の報告、終了状態 1 |
| 処理系の制限 | プログラム全体の制限に当たるスクリプト（例: 構成子を 65,536 個持つ `data` を宣言するスクリプトで L0105。テストの中で生成する）を `run` と `check`。L0101 は入れ子の深さの上限 1000（02-03）のためスクリプトでは届かないので使わない。デバッグのビルドで型検査が遅すぎるなら、一つの関数に互いに異なる整数の定数（変数を混ぜて一つの定数に畳まれないようにする）を 65,536 個を超えて置く L0102 にしてよい | `run` は終了状態 2、`check` は終了状態 0 |
| 処理系の不具合 | デバッグのビルドで `DevPanic::Check`（テストでは panic hook を設定しない。プロセス全体の hook が変わるため。hook がなくても終了状態 3 は確かめられる） | 処理系の不具合の報告、終了状態 3 |
| 標準ライブラリのソースの誤り | 手順 4 の判定の関数の単体テスト。`SourceKind::Prelude` の位置の誤りを含む検査の結果を手で作る（`check_files` では標準ライブラリを差し替えられないので） | その誤りを返し、`execute` の経路では処理系の不具合の報告（段 `check`、`message` はその誤りの色なしの文章の形式）と終了状態 3。利用者のソースの誤りだけの結果には何も返さない |
| 引数の UTF-8 | 正しくない UTF-8 の引数（Unix だけ。`OsString::from_vec`） | R0301、終了状態 1 |
| 要求と応答の方式 | 出力を書くスクリプトを `ExecMode::Request` で | 直接呼び出しと同じ出力 |
| 大きなスタック | 入れ子の深さ 1000 近くの、`else if` を含む入れ子の `if` を持つスクリプトを `check` | 呼び出し側のスレッドのスタックの大きさによらず終わる |

誤りのないプログラムで出力が仕様で決まり、段が 1 の命令だけに移るもの（上の「実行」「`run` の省略」「ディレクトリの指定」）は、`run` のゴールデンテストとして `testdata-next/modules/` に置く（07-03「ゴールデンテストの形式（初回リリース版）」。ディレクトリの指定は `<名前>/` の形）。実行器（C10）で走らせるのは C05 である。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 使い方の誤りと報告の文を、`cli::text`・`diag::codes` の外に書いていない
- `main.rs` と `tests/cli_process.rs` と `src/legacy/` を変えていない

## 確認の観点

- `check` の診断の並べ方と、`deny_warnings` の扱いが 10-13 の手順 4〜6 のとおりか。
- 段のスレッドの panic を呼び出し側で起こし直しているか。VM を呼び出し側のスレッドで実行しているか（ADR 0087）。
- `run_program` の終わり方と終了状態の表、出力の書き出しの失敗の規則が 10-13 のとおりか。
- `run` を省いた実行で、サブコマンドの名前と予約した名前だけをサブコマンドとし、それ以外をスクリプトのパスとしているか。
- R08 の第 1 段の `IoServices` の一時的な実装の作り方（出力先の差し替え、最後の書き出し、書き出しの失敗の取り出し）は、10-11 と 10-12 が名前とシグネチャを凍結していない。R08 の実装がこれらを備えていないときは、本作業が一時的な実装を変えずに、作業を止めて報告しているか。

## 難易度の理由

関数の多くは最小実行版の `pipeline`・`cli`・`runtime::run` を写して広げられ、仕様は 10-13 と 06-01 に揃っている。加わるのは、ディレクトリとシェバン、予約した名前、警告の扱い、複数のファイルの診断の並べ方であり、どれも規則は単純である。難しさは、第 1 段の一時的な実行の関数と R08 の一時的な実装を、後の R26〜R28 が中身を移せる形で組むことと、終わり方の表の場合分けの多さにある。
