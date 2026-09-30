# T23 ランタイム

- 依存する作業: [T22](T22-vm.md), [T05](T05-diag-render.md)
- 難易度: 3（1〜5。README の「難易度の目安」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/T23-runtime

## 目的

VM の外側で実行を支える部分を実装する。本番のハンドラ表と出力のバッファ、IO 実行器（二つの方式の繰り返しと panic 境界）、panic hook、止まったときの報告（主な位置と呼び出しの履歴）の組み立て、プログラムの実行の流れ（コマンドライン引数の検査、`main` の結果による終わり方、出力の書き出しの失敗の扱い、終了状態）である。

## 読む設計書の節

- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「実行ごとの状態」「ハンドラ表」「IO 実行器」「出力のバッファ」「資源の追跡」「一つの操作で作る値の大きさの上限」（`File.readText`）「panic 境界」「プログラムの実行の流れ」
- [仮想機械](../../2026-09-27-design-initial/02-impl/02-08-vm.md)の「実行時エラーの情報の記録」「IO の命令」
- [診断エンジン](../../2026-09-27-design-initial/02-impl/02-10-diagnostics.md)の「診断コード」「実行時エラーと資源の不足の報告」「処理系の不具合と処理系の制限の報告」
- [バイトコードとコード生成](../../2026-09-27-design-initial/02-impl/02-07-bytecode.md)の「原型の名前と由来の種類」
- [エフェクト](../../2026-09-27-design-initial/01-spec/01-07-effects.md)の「IO を行う組み込み関数」「IO の失敗」「外部から受け取る文字列」「プログラムの入口」
- [評価意味論](../../2026-09-27-design-initial/01-spec/01-08-evaluation.md)の「実行時エラーによる停止」「資源の不足」
- [CLI](../../2026-09-27-design-initial/06-tooling/06-01-cli.md)の「終了状態」
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の全体
- [診断](../10-interfaces/10-02-diagnostics.md)の「診断の内部の表現」と診断コードの表の `R` の項目と `text`
- [パイプライン API と CLI](../10-interfaces/10-09-pipeline-api.md)の最後の段落（`BENITOITE_DEV_PANIC`）

## 作るもの

- `src/runtime/real_io.rs`: `OutputBuffer` と `RealIo` の関数と `IoHandlers` の実装（10-08 の `sig=src/runtime/real_io.rs`）。
- `src/runtime/executor.rs`: `ExecMode`・`ExecOptions`・`ExecEnd`・`execute`。
- `src/runtime/panic.rs`: `PanicReport`・`install_hook`・`take_report`・`catch`。
- `src/runtime/report.rs`: `stop_diagnostic`・`internal_diagnostic`。
- `src/runtime/run.rs`: `RunEnd`・`check_args`・`run_with`。
- 上のファイルの中のテスト。

## 手順の要点

### 出力のバッファ（02-09「出力のバッファ」）

- `OutputBuffer::write` は、`failed` が `Some` なら何もせず `Ok` を返す（失敗した出力の以後の書き込みは捨てる）。そうでなければバッファに加え、長さが `FLUSH_THRESHOLD` 以上になったら `flush` する。`flush` の失敗は `failed` に理由を記録し、`Err(理由)` を返す。
- `OutputBuffer::flush` は、`failed` が `Some` なら何もせず `Ok`。そうでなければ `write_all` と `flush` で書き出し、バッファを空にする。失敗したら理由（`std::io::Error` の `to_string()`）を記録して `Err` を返す。もう一度書き出そうとはしない。
- `RealIo` の `Print`・`Println`・`Eprintln` は、書き込みの関数の中の書き出しが失敗したら `Stop::Runtime(RuntimeError::WriteFailed { stream, reason })` を返す。
- `IoHandlers::flush_all` の `RealIo` の実装は、標準出力、標準エラー出力の順に `flush` し、失敗した出力と理由を返す。
- `RealIo::new` は `std::io::stdout()` と `std::io::stderr()` を書き出し先にする。Rust の標準出力は行ごとのバッファを内部に持つが、`OutputBuffer` の `flush` の中で `flush()` を呼ぶので、書き出しの時点は 02-09 の二つの時点に限られる。
- SIGPIPE の設定は変えない（02-09）。読み手の終わったパイプへの書き込みは `BrokenPipe` の誤りになる。

### ファイルの読み込み

`ReadText` は、`std::fs::File::open` で開き、`Read::take(MAX_STRING_BYTES + 1)` で読んだバイト列の長さが `MAX_STRING_BYTES` を超えたら `ValueTooLarge { function: "File.readText", size: 読んだ長さ, unit: Bytes, limit }` を返す。開けない・読めないときは `std::io::Error` の表示を文言とする `Err(IoError)`、正しい UTF-8 でなければ `io_error::text::MSG_INVALID_UTF8`（T10）の `Err`。ディレクトリを開いたときの誤りは OS によって開くときと読むときのどちらで出るかが違うが、どちらも `Err` になる。先頭の BOM は取り除かない（01-07）。

### 開発用の panic（新しく決めること）

`RealIo::new` と `RealIo::with_sinks` は、`cfg!(debug_assertions)` が真で、環境変数 `BENITOITE_DEV_PANIC` の値が `run` のとき、そのことを 10-08 の欄 `dev_panic_on_println` に記録する。記録があれば、最初の `Println` の内容をバッファに加えた直後に `panic!` を起こす。`#[allow(clippy::panic)]` を理由のコメント付きで書く（[実装の規約](../00-common/00-02-conventions.md)の `#[allow]` の表にある箇所）。

### panic hook と panic 境界（02-09「panic 境界」）

- `install_hook` は `std::panic::set_hook` で、標準エラー出力に何も書かない hook を設定する。hook は `PanicHookInfo` から文言（`&str` か `String` の payload。ほかは `"<non-string panic payload>"`）と位置（`ファイル:行:列`）を取り、`std::backtrace::Backtrace::capture()`（環境変数 `RUST_BACKTRACE` に従って取る）の表示を、無効でなければ `backtrace` に入れて、`thread_local!` の `RefCell<Option<PanicReport>>` に記録する。
- `take_report` は記録を取り出す。
- `catch(f)` は `std::panic::catch_unwind(AssertUnwindSafe(f))` を呼び、`Err` なら `take_report()`（なければ文言 `"unknown panic"` の報告）を返す。

### IO 実行器（02-09「IO 実行器」）

`execute` は `catch` の中で次を行う。

1. `Vm::new` で VM を作り、`start_main` を呼ぶ。止まったら `ExecEnd::Stopped`。
2. 直接呼び出しの方式では `vm.run(IoDispatch::Direct(io))` を一度呼ぶ。要求と応答の方式では、`vm.run(IoDispatch::Request)` が `Request` を返すたびに `io.call(op, &args, vm.heap_mut())` を呼んで `vm.resume` し、`Finished` か `Stopped` になるまで繰り返す。
3. `Finished(v)` は `ExecEnd::Returned(v)`、`Stopped(info)` は `ExecEnd::Stopped(info)`。確保の統計は `vm.heap().stats()`。
4. `catch` が panic を捕らえたら `ExecEnd::Panicked(報告)`、統計は既定の値。

### 止まったときの報告（02-08「実行時エラーの情報の記録」、02-10）

`stop_diagnostic(program, info)` は、`stop` の種類でコードを選ぶ。

| `Stop` | コード | 注記など |
|---|---|---|
| `Runtime(DivisionByZero)` | R0101 | |
| `Runtime(IntegerOverflow)` | R0102 | |
| `Runtime(WriteFailed { Stdout, reason })` | R0201 | 注記 `reason`。主な位置と履歴を作らない |
| `Runtime(WriteFailed { Stderr, reason })` | R0202 | 同上 |
| `Resource(CallStackTooDeep { frames })` | R0901 | 注記 `frames`、修正案 `raise` |
| `Resource(ValueTooLarge { .. })` | R0902 | 文言の `function`、注記 `size`（`unit` は `bytes` か `elements`） |
| `Internal(msg)` | なし | `internal_diagnostic("run", msg, None)` を返す |

主な位置と履歴は、次の手順で作る。

1. 段の並び: `info.frames` を内側から順に見て、原型の由来の種類が `PreludeHelper` の段を除く。各段の名前は、`UserLambda` なら `FrameName::Lambda(lambda_span)`、ほかは `FrameName::Named(原型の名前)`。
2. 各段の呼び出した位置: `call_site` の命令の、原型の `positions` の値。`call_site` が `None` の段、位置が `None` の段、位置が prelude のソース（ソースの表の `SourceKind::Prelude`）にある段は、位置を示さない。
3. 主な位置: `info.at` の命令の位置が利用者のソースにあればそれ。そうでなければ、内側の段から順に `call_site` の命令の位置を見て、利用者のソースにある最初のもの。見つからなければ `None`。主な位置にはラベルを付けない。
4. 段が 20 を超えるときは、内側の 10 段と外側の 10 段を残し、除いた段の数を `omitted` にする。数えるのは手順 1 で除いた後の段である。
5. 履歴を持つ報告（実行時エラーと資源の不足。書き込みの失敗を除く）には、`notes` の最後に `text::TRACE_TAIL_NOTE` を置く（R0901 の `frames`・`raise` の注記より後）。T05 はこの注記を合成せず、`notes` をそのまま書く。履歴そのものは `trace` の欄に入れ、文章の形式への並べ方は T05 の書き出しが行う。

`internal_diagnostic(stage, message, panic)` は、`kind: Internal`、`code: None`、文言 `text::INTERNAL_MESSAGE`、注記に `INTERNAL_VERSION`（`env!("CARGO_PKG_VERSION")`）、`INTERNAL_STAGE`、`message`（空でなければ）、`INTERNAL_PANIC`（`panic` があれば）、`INTERNAL_REPORT` の順に並べ、`backtrace` に panic のバックトレースを入れる。

### プログラムの実行の流れ（02-09「プログラムの実行の流れ」）

- `check_args(args)`: 先頭から `into_string()` し、最初に失敗した引数の位置（1 から数える）で R0301 の報告（`index`）を返す。
- `run_with(program, io, opts)`:
  1. `execute` を呼ぶ。二つ目の戻り値の `AllocStats` を `RunEnd` の `alloc` に入れる。
  2. `io.flush_all()` で書き出す。
  3. 終わり方ごとに `RunEnd` を作る。`Returned(v)`: `MainKind::Unit` なら終了状態 0。`MainKind::Result` なら、`v` のタグ 0（`Ok`）で 0、タグ 1（`Err(msg)`）で `main_error = Some(msg)`、終了状態 1。値の形が違えば処理系の不具合（終了状態 3、段は `"run"`）。`Stopped(info)`: `stop_diagnostic`、終了状態は `Internal` なら 3、ほかは 1。`Panicked(p)`: `internal_diagnostic("run", "", Some(&p))`、終了状態 3。
  4. 手順 2 の書き出しの失敗を、02-09 の四つの場合に従って扱う。`main` が `()`・`Ok(())` か `Err(msg)` なら、失敗した出力の R0201 か R0202 の報告を `reports` に加え（`Err(msg)` の `main_error` は残す）、終了状態 1。実行時エラーか資源の不足なら、先の報告の `notes` に `text::FLUSH_FAILED_NOTE`（`stream` は `standard output` か `standard error`）を加え（`TRACE_TAIL_NOTE` があれば、それが最後に残るように、その直前に入れる）、終了状態 1。処理系の不具合なら、失敗を報告に加えず、終了状態 3。

報告を標準エラー出力に書くのは呼び出し側（T24 の CLI、T25 のテストの実行器）である。

## 受け入れテスト

- `OutputBuffer`: 64 KiB 未満の書き込みでは書き出し先に何も届かず、合計が 65,536 バイトに達した書き込みで届く。`flush` で残りが届く。
- 書き出しの失敗: 常に `BrokenPipe` を返す `Write` を書き出し先にした `OutputBuffer` で、`flush` が `Err` を返し、以後の `write` は捨てられて `Ok`、`failure` が理由を返す。`RealIo` の `Println` の中の書き出しが失敗すると `WriteFailed` の `Stop`。
- `ReadText`: 一時ディレクトリ（`std::env::temp_dir` の下にテストが作る）の UTF-8 のファイルが `Ok`、ない名前が `Err`、`[0xff]` の内容が `io_error::text::MSG_INVALID_UTF8` の `Err`。
- 報告の組み立て（T22 と同じく手で組んだプログラムと、手で作った `StopInfo`）: 利用者の関数 → prelude の公開の関数 → prelude の補助の関数 → 利用者のラムダの順に呼ばれ、ラムダの中の除算で止まった場合に、履歴が「ラムダ、公開の関数、利用者の関数」の順で補助の関数を含まず、主な位置が除算の命令の位置になる。止まった命令が prelude のソースにある場合に、主な位置が内側から見て最初の利用者のソースの呼び出した位置になる。25 段の場合に、内側 10 段と外側 10 段と `omitted: 5`。書き込みの失敗の報告が `primary: None`・`trace: None`。
- `check_args`: 2 番目の引数が正しくない UTF-8（Unix の `OsString::from_vec` で作る。`#[cfg(unix)]`）なら R0301 の `index` が `2`。
- `run_with` と `TestIo`: `main` が `()` を返すプログラムで終了状態 0、`Err("bad")` で `main_error` と終了状態 1、除算の 0 で R0101 の報告と終了状態 1。二つの方式（`ExecMode::Direct` と `Request`）で同じ結果。
- 書き出しの失敗の四つの場合（標準出力を失敗する書き出し先にした `RealIo::with_sinks`）: `main` が成功したとき R0201 の報告と終了状態 1、`Err(msg)` のとき `main_error` と R0201、除算の 0 のとき R0101 の報告の注記に書き出しの失敗が加わる。
- panic 境界: `catch(|| panic!(...))` が文言と位置を持つ `PanicReport` を返す（テストの中で `install_hook` を呼ぶ。hook はプロセス全体で一つなので、hook を設定するテストは一つにまとめる）。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 報告を標準エラー出力に直接書く処理が、このモジュールにない（書くのは呼び出し側）

## 難易度の理由

一つ一つの処理は難しくないが、02-09 と 02-10 の細かな規則（書き出しの時点、失敗の後の扱い、終わり方と終了状態の組み合わせ、履歴の段の除き方と省き方）が多く、取り違えるとゴールデンテストの期待値と食い違う。panic hook とスレッドローカルな記録は、プロセス全体の状態に関わるので、テストの書き方にも注意が要る。
