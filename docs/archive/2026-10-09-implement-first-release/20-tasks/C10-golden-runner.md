# C10 初回リリース版のゴールデンテストの実行器

- 依存する作業: [F18](F18-pipeline-cli.md), [F13](F13-core-check.md), [F14](F14-refinterp.md), [C03](C03-test-rewrite.md)（理由は「依存を見直した理由」）
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/C10-golden-runner

## 目的

初回リリース版のゴールデンテストの実行器を作る。最小実行版の実行器（C04 の後の `tests/golden.rs`。`legacy` の API で動く）を写し、初回リリース版の CLI の関数（[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の `cli::parse_args`・`cli::execute`）で実行するように改め、複数のモジュールからなるテスト（ディレクトリ）と CLI のオプション（`.options`）に広げる（[ADR 0224](../../2026-10-09-design-first-release/decisions/0224-golden-test-format-for-first-release.md)）。同じ実行器の中で、IO の二つの方式のテスト、参照インタプリタとの差分テスト、コア IR の検査を行う。`test`・`fmt`・`fmt-check` の方式と、フォーマッタの性質の自動の確かめは U4 が加える。

移行の間、この実行器は `testdata-next/runner/` だけを走らせる。テストと CLI の切り替え（C05）が、C03 の書き直したテストを `testdata/` に移すときに、走らせる範囲を `testdata/` に広げ、ファイルの名前を `tests/golden.rs` に改める。

## 依存を見直した理由

骨子の段階では C10 の依存を C02 としていた。しかし、実行器を働かせて受け入れテストを通すには、中身のある `cli::execute` と `pipeline` の関数（F18）、コア IR の検査器（F13）、参照インタプリタ（F14）が要る。C02 の時点ではこれらの関数に中身がなく、実行器の受け入れテストが通らない。また、実行器を確かめるテストの一部は、C03 が書き直した `testdata-next/runner/` の 4 件である。そこで依存を F18・F13・F14・C03 とした。

## 読む設計書の節

- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md): 「前提」「テストの種類（初回リリース版）」「ゴールデンテスト」「ゴールデンテストの形式（初回リリース版）」「差分テスト」「IO の方式のテスト」「コア IR の検査」
- [ADR 0039](../../2026-10-09-design-first-release/decisions/0039-golden-test-files.md)、[ADR 0224](../../2026-10-09-design-first-release/decisions/0224-golden-test-format-for-first-release.md)、[ADR 0018](../../2026-10-09-design-first-release/decisions/0018-reference-interpreter.md)、[ADR 0276](../../2026-10-09-design-first-release/decisions/0276-reference-interpreter-shares-builtin-bodies.md)
- [スクリプト実行と埋め込み](../../2026-10-09-design-first-release/02-impl/02-11-embedding.md): 「CLI の一回の実行」「実行の入力と結果」
- [CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md): 「コマンドラインの形」「ディレクトリの指定」「オプション」「終了状態」
- [中間表現と脱糖](../../2026-10-09-design-first-release/02-impl/02-06-ir-and-lowering.md): 「参照インタプリタの範囲」
- [診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md): 「JSON の形式」「文章の形式」
- インターフェース: [10-13](../10-interfaces/10-13-pipeline-and-cli.md) の全体（特に「テストの実行器とゴールデンテストの実行器が使う口」）、[10-06](../10-interfaces/10-06-ir.md) の「コア IR の検査器」「参照インタプリタ」、[10-11](../10-interfaces/10-11-builtin-interface.md) の `IoServices`、[10-02](../10-interfaces/10-02-diagnostics.md) の「診断の書き出し」、[10-04](../10-interfaces/10-04-modules-and-resolve.md) の `EntrySpec`・`RealFs`

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `tests/golden_next.rs`: 実行器、IO の方式のテスト、差分テスト、コア IR の検査。補助のモジュールを `tests/golden_next/` の下に分けてよい。ファイルの先頭に、テストのコードに許す lint の `#![allow(...)]` を書く（[実装の規約](../00-common/00-02-conventions.md)の「`#[allow]` を書いてよい箇所」）。
- `tests/golden_next/differential.rs`: 差分テストの部分（後述の「差分テストとコア IR の検査」の手順 2〜6）を、ほかの統合テストからも使える形で置く。入力は検査を通したプログラム（`CheckedProgram` と `Arc<SourceTable>`）、実行の入力（`runtime::io::services::RunInput`。欄が公開なので呼ぶ側が作る。ゴールデンテストの側は `run_input` で作り、ファイルのないプログラムを渡す C14 の側は直接作る。`run_input` はパスを `canonicalize` するため）と `VmConfig`、出力は比べた結果（一致、食い違いの説明、外した理由）とする。無作為に生成したプログラムの差分テスト（C14）が、`#[path = "golden/differential.rs"] mod differential;` の形で同じコードを使う（C05 がディレクトリの名前を `tests/golden/` に改めた後）。このファイルは `golden_next` の外の型に依存させない。外から呼ぶ関数は一つにまとめる。取り込んだ側で使わない項目があると `dead_code` の警告になり、警告は誤りになる（`tests/` のファイルに許す lint に `dead_code` は含まれない）。
- `testdata-next/runner/`: 実行器が働くことを示すテスト（下の「受け入れテスト」）。C03 が置いた 4 件は、期待値のファイルを確かめて必要なら直す（後述）。

`src/` と、最小実行版の実行器 `tests/golden.rs` と `testdata/` は変えない。

## 手順の要点

### 走らせる範囲

- 走らせる根のディレクトリを、実行器の先頭の定数 `GOLDEN_ROOTS: &[&str] = &["testdata-next/runner"]` に置く。C05 が `&["testdata"]` に改める。
- 差分テストにかけるベンチマークのディレクトリを、定数 `BENCH_DIRS: &[&str] = &[]` に置く。ベンチマークのプログラムは C05 まで古い構文で書いてあるので、空にしておく。C05 が `&["../../tools/bench/programs"]` に改める。
- パスは、処理系のクレートのディレクトリ（`env!("CARGO_MANIFEST_DIR")`）からの相対パスとして扱う。`cargo test` は統合テストをクレートのディレクトリを作業ディレクトリにして実行する。念のため、実行器の最初に作業ディレクトリが `CARGO_MANIFEST_DIR` と一致することを確かめ、違えば理由を示して失敗させる。

### テストの見つけ方と表示名

- 根のディレクトリの下の区分のディレクトリを辿る。区分の一覧はコードに書かない。
- 一つのテストは、`<名前>.bnt` のファイルか、`<名前>/` のディレクトリ（中に `main.bnt` を置く）のどちらかと、隣の `<名前>.mode` からなる（07-03「ゴールデンテストの形式（初回リリース版）」）。`.mode` のないディレクトリと、`<名前>.files/`・`<名前>.formatted`・`<名前>.formatted/` はテストとみなさない。
- 処理系に与えるパスは、クレートのディレクトリからの相対パス（`testdata-next/runner/hello.bnt`、ディレクトリなら `testdata-next/runner/modules_basic`）とする。CLI の表示名はコマンドラインで与えたパスなので、期待値の中の表示名はこのパスになる（最小実行版の実行器は区分からの相対パスを表示名にしていた。C05 はこの差を期待値の変化として受け入れる）。
- テストは一つの `#[test]` 関数の中で順に実行し、失敗をすべて集めてから、テストの名前と期待値との差を並べて失敗させる。環境変数 `BENITOITE_GOLDEN_FILTER` に文字列を与えたら、名前にその文字列を含むテストだけを実行する。

### 期待値のファイル

07-03 の二つの表のファイルを読む。最小実行版の実行器と違う点は次のとおりである。

| ファイル | 読み方 |
|---|---|
| `.mode` | `check`・`run` を実行する。`test`・`fmt`・`fmt-check` は、U4 が扱いを加えるまで「U4 の方式」と示してテストを失敗させる（黙って飛ばさない） |
| `.options` | 一行に一つの CLI のオプション。コマンドラインの、サブコマンドとスクリプトのパスの間に並べる |
| `.args` | 一行に一つのスクリプトの引数。コマンドラインのスクリプトのパスの後に並べる（`run` だけ） |
| `.files/` | 中身を、テストごとに作る一時ディレクトリに写す（後述の「実行の環境」）。スクリプトは相対パスで読む |
| `.stdin` | 標準入力に与えるバイト列。ないときは空の入力（07-03 の表の `.stdin`）。10-13 の `StdinSource::Bytes` が「ゴールデンテストの実行器」のためにある |
| `.opts` | 最小実行版の形式。見つけたら、`.options` に改めるよう示してテストを失敗させる |

### 実行の手順

`check` と `run` のテストごとに、次を行う。

1. コマンドラインを組み立てる: `[<mode>, "--diagnostics=json", <.options の行>…, <パス>, <.args の行>…]`。`.options` に `--diagnostics` があるときは、`--diagnostics=json` を加えない（そのテストは `.diag.json` を持てない。持っていたら実行器の誤りとして示す）。`cli::parse_args` で解釈する。使い方の誤り（`Err`）は、CLI と同じく `text::USAGE_ERROR` と `text::SEE_HELP` の 2 行を標準エラー出力とし、終了状態 2 として比べる。
2. `CliEnv` を作る: 標準出力と標準エラー出力は `OutputTarget::Capture`、標準入力は `.stdin` があれば `StdinSource::Bytes`・なければ `StdinSource::Empty`、`working_directory` はテストごとの一時ディレクトリ、`color` は偽、`interrupt` は `Some(Box::new(NoInterrupt))`、`parts` は `None`、`heap` は `HeapConfig::default()`（機能 `gc-stress` のビルドでは回収の強制になる）、`dev_panic` は `DevPanic::None`、`dev_alloc_stats` は偽。
3. `cli::execute` を呼び、終了状態・標準出力・標準エラー出力を得る。
4. 標準エラー出力を行に分け、JSON の形式の報告の行（`{` で始まり `}` で終わる行）と、それ以外に分ける。報告の行の並びを `.diag.json` と、それ以外の行をつなげたバイト列を `.stderr` と比べる。この分け方のため、スクリプトが `{` で始まる行を標準エラー出力に書くテストと、改行で終えずに標準エラー出力に書いてから止まるテストは置かない（そのことを実行器の先頭のコメントに書く）。
5. `run` のテストは、IO の方式を `ExecMode::Direct` と `ExecMode::Request` に替えて手順 2〜4 を二度行い、それぞれを期待値と比べる（07-03「IO の方式のテスト」）。失敗の一覧には、どちらの方式で食い違ったかを示す。
6. `.text.stderr` があれば、`--diagnostics=json` を加えずに（文章の形式、色なし）`ExecMode::Direct` でもう一度実行し、標準エラー出力の全体を `.text.stderr` と比べる。最小実行版では報告の部分だけを比べたが、`check` のテストでは標準エラー出力が報告だけなので、同じものを比べることになる。

### 実行の環境

- 一時ディレクトリは `std::env::temp_dir()` の下に、プロセスの番号とテストの番号から名前を作る。`.files/` があれば中身を写す。一時ディレクトリは実行ごと（二つの IO の方式、`.text.stderr` のための実行、差分テスト）に作り直す。前の実行が書いたファイルを残さないためである。実行器の最初に `runtime::panic::install_hook()` を一度呼ぶ（捕らえた panic の文言を報告に入れるため）。テストの後に消す。消せなかったら、テストを失敗させずに一覧の最後に警告として示す。
- 基準のディレクトリを一時ディレクトリにするので、スクリプトは相対パスで `.files/` の中身を読み、リポジトリのほかのファイルを相対パスで読めない（02-11「実行の入力と結果」の基準のディレクトリ）。

### 差分テストとコア IR の検査

`run` のテストのうち検査に誤りのないものについて、次を行う（07-03「差分テスト」「コア IR の検査」）。

1. `pipeline::entry_spec` と `pipeline::check_path`（`require_main` は真、`deny_warnings` は `.options` に従う）、`pipeline::desugar_checked` を呼ぶ。脱糖の `Err` は処理系の不具合としてテストを失敗させる。
2. `ir::check::check_program` の結果が空であることを確かめる。空でなければ「コア IR の検査の失敗」として示す。
3. `pipeline::compile` の後、`runtime::run::run_program` を `ExecMode::Direct` で呼ぶ（`RunEnv` は手順 2 と同じ考え方で作る）。
4. 同じ `CoreProgram` を `refinterp::run` で実行する。`IoServices` は、実行器の中に書くテスト用の実装を渡す。書き込みを出力先ごとに記録し、引数・基準のディレクトリ・実行を始めるスクリプトのディレクトリは VM の側と同じ値を返す。時計と乱数は、VM の側の値と比べられないので、それらを使うテストは差分テストから外す（外す印は、`.options` に置けないので、実行器の中の定数の一覧に名前で書く）。
5. 比べるものは、出力先ごとに書いた内容、終わり方（10-06 の `RefOutcome` と 10-13 の `EndKind` の対応）、`main` の `Result.Error` の文字列、実行時エラーの種類（`Stop` の値）、止まった位置である。VM の側の `RunEnd` は `Stop` を持たないので、実行時エラーの種類は、参照インタプリタの `Stop` から `StopInfo { stop, at: None, frames: vec![], spawns: vec![], deadlock: vec![] }` を作って `runtime::report::stop_diagnostic` にかけ、得たコードと文言を VM の報告のコードと文言と比べる。位置は、VM の側は報告の主な位置、参照インタプリタの側は `RefOutcome::Stopped` の `origin` とし、両方が利用者のソースにあるときだけ比べる。
- 手順 2〜6 は、`pipeline::STAGE_STACK_BYTES` のスタックを持つスレッドで行う（`CheckedProgram`・`CoreProgram` の破棄と `check_program` は深い構造を再帰で辿る。CLI の段と同じ条件にするためであり、00-02「再帰の深さ」の「スレッドのスタックの大きさを変えてテストを通すこと」には当たらない）。`VmConfig` の呼び出しの入れ子の上限は、`.options` の `--max-call-stack` に従う（`cli::parse_args` の結果から取る）。参照インタプリタに渡す `IoServices` のテスト用の実装は、環境変数を `None` として返す（VM の側の第 1 段の `TestIo` と同じ）。
6. 比べる対象から外すのは、資源の不足で止まったもの（ADR 0018）、参照インタプリタが `RefOutcome::Unsupported` を返したもの（タスクを起動する組み込みの関数。02-06「参照インタプリタの範囲」）、`.stdin` を持つもの（参照インタプリタに標準入力を与える口がない）である。外した数を、理由ごとに最後に示す。
7. `BENCH_DIRS` の各ディレクトリの `<名前>.bnt` のうち `<名前>.args.small` があるものを、期待値のファイルなしで、手順 1〜6 と同じく差分テストにかける。基準のディレクトリはそのベンチマークのディレクトリとする（`lines` が小さな入力のファイルを相対パスで読むため）。

### 書き直しの指定

環境変数 `BENITOITE_BLESS=1` を与えたときは、比べる代わりに実際の結果で期待値のファイルを書き直す（ADR 0039）。`ExecMode::Direct` の結果で書き、二つの方式の結果が食い違うときは書き直さずに失敗させる。空になるファイル（`.stdout`・`.stderr`・`.diag.json`）は消す。`.exit` も書き直す（0 のときも書く。07-03 で必須のファイルである）。`.mode`・`.options`・`.args`・`.files/`・`.stdin` は書き直さない。`.text.stderr` は、あるときだけ書き直す。`scripts/check.sh` は書き直しの指定を使わない。

### C03 の 4 件

`testdata-next/runner/` の C03 の 4 件（最小実行版の実行器が働くことを示したテスト）を、この実行器で走らせる。期待値が書き直しの前と違うときは、[作業の進め方](../00-common/00-03-workflow.md)の「構文の改めとテストの移行」と C05 の文書の「受け入れる期待値の変化」に当てはまるものだけを直し、直した箇所を完了の報告に挙げる。当てはまらない差は、処理系の不具合として報告する。C03 は期待値を確かめていない（00-03）。`check-error` の期待値は古い構文の結果のまま（位置 3:5、ソースの抜き出しの `fn main() -> Unit {`、注記 "the function body must match…"、表示名 `runner/…`）なので、コードが E0401、終了状態が 2、主な位置が戻り値の `1`、補助の位置が戻り値の型の `Unit` を指す場合は、位置・ソースの抜き出しの行・注記・表示名を書き直してよい。

## 受け入れテスト

`testdata-next/runner/` に、C03 の 4 件に加えて、次のテストを置く。

| テスト | 確かめること |
|---|---|
| ディレクトリのテスト | `<名前>/main.bnt` が `<名前>/Lib/Text.bnt` を import し、標準出力に書く。期待値の表示名がディレクトリのパスに `main.bnt` を続けたものになる |
| `.options` のテスト | 警告の出るスクリプトに `--deny-warnings` を与えると、終了状態 2 で実行しない（ADR 0166）。同じスクリプトを `.options` なしで `run` すると、警告を報告して実行する |
| 使い方の誤りのテスト | `.options` に知らないオプションを書くと、終了状態 2 と使い方の誤りの 2 行になる |
| `.files/` のテスト | スクリプトが相対パスで `.files/` の中のファイルを読む |

あわせて、次を確かめる。

- 実行器の検出力: どれかのテストの期待値を 1 バイト変えるとテストが失敗し、失敗の一覧にそのテストの名前と差分が出る（手で確かめ、完了の報告に書く。テストとしては残さない）。
- 書き直しの指定: 期待値のファイルを消して `BENITOITE_BLESS=1 cargo test --test golden_next` を実行するとファイルが作られ、続けて指定なしで実行すると通る（手で確かめる）。
- 差分テストとコア IR の検査が、`run` のテストに対して実行されている。失敗の一覧が、差分テストの失敗とコア IR の検査の失敗を区別して示す。
- `.stdin` の読み方は、標準入力を読む組み込みの関数（R29）がまだないので、この作業では確かめない。C12 が確かめる。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」。回収の強制の行もこの実行器を走らせる）
- 受け入れテストのすべての場合を確かめるテストか確認の記録がある
- 完了の報告に、表示名が変わったことを挙げる

## 難易度の理由

扱う組み合わせ（方式、IO の方式、差分テスト、コア IR の検査、書き直しの指定、ディレクトリのテスト）は多いが、どれも公開の API を呼んで結果を比べる処理である。判断が要るのは、標準エラー出力の中の報告とスクリプトの出力を分ける規則、差分テストから外す条件、参照インタプリタに渡す `IoServices` のテスト用の実装を VM の側の入力と揃えることである。
