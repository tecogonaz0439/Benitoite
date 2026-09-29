# パイプライン

- 状態: 確定
- 関連ADR: [0014](../decisions/0014-fine-grain-cbv-core.md), [0015](../decisions/0015-shared-program-per-execution-state.md), [0016](../decisions/0016-calls-off-go-stack.md), [0017](../decisions/0017-ir-in-core-calculus-form.md), [0018](../decisions/0018-reference-interpreter.md), [0019](../decisions/0019-stop-after-failing-stage.md), [0022](../decisions/0022-side-tables-keyed-by-node.md), [0030](../decisions/0030-call-stack-size-limit.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0079](../decisions/0079-rust-readings-of-go-based-decisions.md), [0083](../decisions/0083-constant-descriptions-in-shared-program.md), [0087](../decisions/0087-pipeline-stages-on-large-stack-thread.md), [0115](../decisions/0115-structured-io-concurrency.md), [0123](../decisions/0123-top-level-constants.md), [0126](../decisions/0126-import-by-module-name.md), [0127](../decisions/0127-directory-run-and-root.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0137](../decisions/0137-first-release-library-scope.md), [0156](../decisions/0156-module-loading-and-whole-program-checking.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0158](../decisions/0158-type-classes-by-dictionary-passing.md), [0159](../decisions/0159-pattern-extensions-in-decision-trees.md), [0160](../decisions/0160-one-shot-continuations-as-stack-segments.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md)
- 未決事項: [OPEN-007](../open-issues.md#open-007), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055)
- 移行元: [設計メモ](../sources/fp-language-design.md) 6, 5.3

## 目的と範囲

処理の段と段間で受け渡すデータ構造、VM の再入可能性（reentrancy）、実行方式の選定。各段の中の作り方は、段ごとの章（[ソース管理と位置情報](02-02-source-and-spans.md)から[スクリプト実行と埋め込み](02-11-embedding.md)まで）が定める。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。初回リリース版のプログラムは、実行を始めるモジュールと、そこから import で辿れるすべてのモジュールからなる（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)の「実行を始めるモジュール（初回リリース版）」）。REPL、LSP サーバ、スクリプトを埋め込んだ実行ファイルの経路は、それぞれを設計するときに本章へ加える。

## 前提

処理系の段の並びと、「検査」と「実行」の区別は[全体像](../00-overview/00-02-architecture.md)で定めた。言語の意味は[コア計算と脱糖](../01-spec/01-12-core-calculus.md)で定め、処理系の実行結果はコア計算の実行結果と一致しなければならない（[ADR 0014](../decisions/0014-fine-grain-cbv-core.md)）。

## 仕様

### 実行方式

【方針】実行方式は、自作のバイトコード VM（JIT なし）とする（[設計メモ](../sources/fp-language-design.md) 6）。ほかの言語のソースへのトランスパイルと、処理系コアの WASM 化は代替案として残す。WASM 化の採否は [OPEN-007](../open-issues.md#open-007) で扱う。

### 段と段の間のデータ

【方針】処理系は、スクリプトを次の段で順に処理する。各段は入力を書き換えず、新しいデータを出力する。

| 段 | 入力 | 出力 | 定める章 |
|---|---|---|---|
| 読み込み | 実行を始めるファイルのパス、処理系に埋め込んだ標準ライブラリのソース、構文解析した各ファイルの import の宣言 | ソース（ファイル ID と内容のバイト列）の表と、モジュールの表（モジュールの名前、ファイル ID、import の宣言が指すモジュール） | [ソース管理と位置情報](02-02-source-and-spans.md)、[名前解決とモジュール読込](02-04-resolver.md) |
| 字句解析 | ソース | span 付きの字句の列 | [字句解析器と構文解析器](02-03-frontend.md) |
| 構文解析 | 字句の列 | モジュールごとの、span 付きの抽象構文木（abstract syntax tree、AST）とコメントの一覧 | [字句解析器と構文解析器](02-03-frontend.md) |
| 名前解決 | すべてのモジュールの AST | 名前の参照ごとに、それが指す束縛を定めた表と、モジュールごとの公開の表 | [名前解決とモジュール読込](02-04-resolver.md) |
| 型検査 | 名前解決の結果を伴う AST | 式の型、型の引数、演算子の型、ラムダのエフェクト、宣言の型、型クラスの制約の解き方の各表と、定数の値（[型検査器](02-05-typechecker.md)の「出力」） | [型検査器](02-05-typechecker.md) |
| 脱糖 | 型検査の結果を伴う AST | コア IR と下位 IR（中間表現の二つの段階） | [中間表現と脱糖](02-06-ir-and-lowering.md) |
| コード生成 | 下位 IR と定数の値 | コンパイル済みプログラム | [バイトコードとコード生成](02-07-bytecode.md) |
| 実行 | コンパイル済みプログラムと、実行の入力（コマンドライン引数、標準入出力のつなぎ先、ハンドラ表） | 実行の結果（出力、終了状態、実行時エラーの情報） | [仮想機械](02-08-vm.md), [ランタイム](02-09-runtime.md), [スクリプト実行と埋め込み](02-11-embedding.md) |

【決定】読み込み・字句解析・構文解析は、ファイルごとに続けて行う。読み込みの段は、実行を始めるファイルから始め、ファイルを一つ読むたびに字句解析と構文解析を行い、その import の宣言が指すモジュールを、読むファイルの一覧（作業の一覧）に積む。根のディレクトリの下のファイルのうち、import で辿れないものは読まない（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）。作業の一覧の進め方とファイル ID の振り方は[ソース管理と位置情報](02-02-source-and-spans.md)で、モジュールの名前からファイルを探す方法と循環の検出は[名前解決とモジュール読込](02-04-resolver.md)で定める。

【決定】名前解決と型検査は、プログラム全体を一つの単位として行う。名前解決は、すべてのモジュールのトップレベルの宣言を先に集めて公開の表を作り、その後で本体を解決する。型検査は、宣言をプログラム全体で先に検査し、その後で関数の本体を一つずつ検査する。モジュールの間の参照は、検査全体で一意な束縛の番号で結び付ける（リンク）。変わったモジュールだけを検査し直すインクリメンタルな処理は、初回リリース版では行わない（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）。

【決定】名前解決と型検査は AST を変更せず、AST のノードを鍵とする表として結果を出力する（[ADR 0022](../decisions/0022-side-tables-keyed-by-node.md)）。表の中身は[名前解決とモジュール読込](02-04-resolver.md)と[型検査器](02-05-typechecker.md)で定める。

公開の検査（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)の「公開（初回リリース版）」）は、名前解決の段で行う（[名前解決とモジュール読込](02-04-resolver.md)）。[コア計算と脱糖](../01-spec/01-12-core-calculus.md)は公開の検査を脱糖の前に終えるとしており、脱糖の段はモジュールと公開を扱わず、束縛の番号で定義を指す。

【決定】標準ライブラリのソースは、利用者のモジュールと同じ構文のモジュールとして書き、利用者のモジュールと同じ段を通して、同じコンパイル済みプログラムに含める（[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。読むのは、prelude のモジュールと、import で辿れる標準ライブラリのモジュールだけである（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）。標準ライブラリのソースは、処理系の実行ファイルに埋め込んだ文字列として持ち、読み込みの段はファイルシステムから読まずにソースの表に加える（[ソース管理と位置情報](02-02-source-and-spans.md)、[名前解決とモジュール読込](02-04-resolver.md)）。

【方針】コンパイル済みプログラムをファイルに保存しない。実行のたびにソースから作る。スクリプトを埋め込んだ実行ファイルでソースとコンパイル済みプログラムのどちらを埋め込むかは、その実行ファイルを設計するときに[スクリプト実行と埋め込み](02-11-embedding.md)で定める。

### 定数の評価

【方針】トップレベルの定数（[構文](../01-spec/01-02-syntax.md)の「定数（初回リリース版）」）の値は、型検査の段の最後に求める。型検査器は、定数の宣言の型を検査した後、型の付いた定数式の AST を評価する専用の評価器で、定数を一つずつ評価する。評価器は、基本型の演算と `Map.fromList`・`Set.fromList` などの組み込みの関数を、実行時と同じ Rust の実装で計算する。定数どうしの循環は名前解決で誤りにしてある（[名前解決とモジュール読込](02-04-resolver.md)）ので、参照される定数から順に評価できる。

計算が実行時エラーの条件に当たるときは、検査の誤りとする（[ADR 0123](../decisions/0123-top-level-constants.md)）。評価の結果は値の記述としてコード生成に渡し、コード生成はそれを定数表に置く（[ADR 0083](../decisions/0083-constant-descriptions-in-shared-program.md)）。定数を実行の前に一度だけ計算して共有しても、観測できる違いはない（[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の「トップレベルの定数」）。評価器と値の記述の形は[型検査器](02-05-typechecker.md)と[バイトコードとコード生成](02-07-bytecode.md)で定める。

### 中間表現

【決定】処理系の中間表現（intermediate representation）は、[コア計算と脱糖](../01-spec/01-12-core-calculus.md)のコア計算と同じ形にする（[ADR 0017](../decisions/0017-ir-in-core-calculus-form.md)）。項を値と計算に分け、計算は `return` と `let` でつなぐ。各ノードは、型とエフェクトと、由来するソース上の位置を持つ。脱糖の段は、コア計算と脱糖の章の脱糖の規則を実装する。中間表現は、コア計算と同じ形のコア IR と、コア IR の `match` を判定の木に置き換えた下位 IR の二つの段階からなる（[中間表現と脱糖](02-06-ir-and-lowering.md)）。

【決定】パターンのガード、範囲、リストのパターンは、コア IR の `match` に残し、判定の木に変換する段で扱う。これは ADR 0017 の例外である（[ADR 0159](../decisions/0159-pattern-extensions-in-decision-trees.md)）。型クラスの制約は、型検査が記録した制約の解き方に従い、脱糖の段が実装の辞書の引数として加える（[ADR 0158](../decisions/0158-type-classes-by-dictionary-passing.md)）。

### 検査と実行の経路

【方針】ツールごとに、次の範囲の段を通す（[全体像](../00-overview/00-02-architecture.md)）。

| 経路 | 通す段 | 定める章 |
|---|---|---|
| `check` | 読み込みから型検査まで（定数の評価を含む） | [CLI](../06-tooling/06-01-cli.md) |
| `run`（`run` を省いた実行とシェバンによる実行を含む） | 読み込みから実行まで | [CLI](../06-tooling/06-01-cli.md)、[スクリプト実行と埋め込み](02-11-embedding.md) |
| `test` | 読み込みからコード生成までを一度行い、テストの関数ごとに別の実行として実行する | [利用者プログラムのテスト](../06-tooling/06-04-test-runner.md) |
| `fmt` | 指定したファイルの読み込みと構文解析だけ。import を辿らない | [フォーマッタ](../06-tooling/06-03-formatter.md) |
| MCP サーバの検査（サーバモード） | `check` と同じ | [サーバモード](../06-tooling/06-07-server.md) |
| MCP サーバの実行（サーバモード） | `run` と同じ。実行は、デーモンが起動する実行ごとの子プロセスで行う（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)） | [サーバモード](../06-tooling/06-07-server.md)、[スクリプト実行と埋め込み](02-11-embedding.md) |

MCP サーバは、初回リリース版には含めず、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。上の表の MCP サーバの行は、そのときの経路の予定である。`check`・`run`・`test` と MCP サーバの経路は、型検査までの段を同じ実装で行う。型検査までに誤りが見つかったときの振る舞いは、どの経路でも `check` と同じである。

【決定】処理系のプロセスの中で実行を一つだけ行う CLI の `run` を除き、`Process.exit` はプロセスを終えず、その実行だけを終える。MCP サーバとテストの実行器での実行では、標準入力を空の入力につなぎ、標準出力と標準エラー出力を実行ごとに捕らえて結果に含める（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。

初回リリース版は、実行の前に権限を示す手順も、実行時の権限制御も持たない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。実行の前に、プログラムが要る権限を利用者に示して許可を得る手順は、サーバモードの設計（[OPEN-055](../open-issues.md#open-055)）で、許可を与える方法とあわせて [OPEN-052](../open-issues.md#open-052) で決める。その手順をどの経路のどの段の後に置くかも、そこで定める。

【決定】中間表現をコア計算の実行の規則どおりに実行する参照インタプリタ（reference interpreter）を、処理系に含める（[ADR 0018](../decisions/0018-reference-interpreter.md)）。参照インタプリタは、脱糖の段が作るコア IR（[中間表現と脱糖](02-06-ir-and-lowering.md)）を入力とし、判定の木への変換、コード生成、VM を通さない。テストだけに使い、同じプログラムを参照インタプリタと VM で実行して結果を突き合わせる差分テスト（differential testing）に使う。利用者が使う経路には含めない。タスクはコア計算に含まれないので、差分テストはタスクを使わないプログラムに限る（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。差分テストの進め方は[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)で定める。

### 誤りが見つかったときの段の進め方

【決定】検査の各段（読み込みから型検査まで）は、出力と診断の組を返す。誤りの診断が一つでもあれば、次の段を行わない。警告の診断は、次の段に進むことを妨げない（[ADR 0019](../decisions/0019-stop-after-failing-stage.md)）。

【決定】読み込み・字句解析・構文解析はファイルごとに続けて行うので、一つのファイルに誤りがあっても、作業の一覧のすべてのファイルの構文解析を終えるまで続ける。どれか一つのファイルに読み込みか構文の誤りがあれば、そこで止め、名前解決に進まない（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）。

各段の中では、誤りから回復して処理を続け、その段で見つけられる誤りをできるだけ多く報告する。構文解析器の回復の方法は[字句解析器と構文解析器](02-03-frontend.md)で、型検査器が回復して検査を続ける単位は[型検査器](02-05-typechecker.md)で定める。

【決定】警告は、`check` でも `run` でも、誤りと同じ形で報告する。オプション `--deny-warnings` を指定したときは、警告を誤りとして扱う（[ADR 0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md)）。

【方針】`--deny-warnings` を指定しても、検査の段は警告を理由に途中で止めず、型検査まで進める。型検査を終えた時点で警告が一つでもあれば、誤りとして扱い、脱糖に進まない。途中で止めると、後の段で見つかる警告を報告できないからである。

脱糖とコード生成の段は、型検査を通ったプログラムだけを受け取るので、利用者のプログラムの誤りを報告しない。これらの段で処理を続けられない状態になったときは、処理系の不具合として扱う。その報告の形は[診断エンジン](02-10-diagnostics.md)で定める。

実行時エラーを標準エラー出力に書く形式も、[診断エンジン](02-10-diagnostics.md)で定める（[評価意味論](../01-spec/01-08-evaluation.md)）。

### コンパイル済みプログラムと実行ごとの状態

【決定】コード生成が出力するコンパイル済みプログラム（バイトコード、定数表、関数の表、ソース上の位置の表）は、生成の後に変更しない。複数の実行と複数のスレッドが、同じコンパイル済みプログラムを同時に読んでよい（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)、[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。

【決定】実行中に変わる状態は、実行ごとに作るオブジェクト（実行ごとの状態）に持たせる。一つの実行を同時に進めてよいスレッドは一つだけとし、一つの実行を複数のスレッドで同時に進めるための排他制御は入れない（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）。タスクの切り替えも、この一つのスレッドの上で、実行ごとの状態の一部であるスケジューラが行う（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。

【方針】スレッドの間で共有するコンパイル済みプログラムには、スレッドをまたいで共有できる型（Rust の `Send` と `Sync` を満たす型）だけを持たせる。実行中の言語の値は参照カウントで管理し（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）、一つの実行の中だけで使うので、定数表には実行中の値そのものを置かない。定数表には値の記述を置き、`LOADK` が実行中の値を作る（[バイトコードとコード生成](02-07-bytecode.md)の「値の移し方」、[ADR 0083](../decisions/0083-constant-descriptions-in-shared-program.md)）。

実行ごとの状態は、次のものを含む。

| 状態 | 内容 | 定める章 |
|---|---|---|
| 呼び出しの情報 | タスクごとの、戻り先、引数、局所の変数の積み重ね。`handle` の枠で区切った区画の連なりとして持ち、捕まえた継続の区画もここから移す（[ADR 0160](../decisions/0160-one-shot-continuations-as-stack-segments.md)） | [仮想機械](02-08-vm.md) |
| ハンドラの連鎖 | タスクごとの、評価中の `handle` の並び。タスクを起動するときは、起動したタスクの連鎖を引き継ぐ（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)） | [仮想機械](02-08-vm.md) |
| スケジューラ | 進められるタスクの待ち行列と、外部に作用する操作の完了を待つタスクの表（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)） | [仮想機械](02-08-vm.md), [ランタイム](02-09-runtime.md) |
| ハンドラ表 | 言語のハンドラが処理しない組み込みの操作を行う Rust の関数の表。`run`・`test`・MCP サーバの実行は本番のハンドラ表を使い、テスト用のハンドラ表は処理系のテストだけで使う | [ランタイム](02-09-runtime.md) |
| イベントループと待ちの表 | イベントループ、作業用のスレッドから完了を受け取る通路、外部に作用する操作の完了を待つタスクの表（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)） | [ランタイム](02-09-runtime.md) |
| リソースの表 | 開いているリソースと解放したリソースの記録。`with` で束縛したリソースは、呼び出しの情報の解放の枠が表の番号で指し、プログラムが止まるときはその枠を辿って解放する | [ランタイム](02-09-runtime.md), [仮想機械](02-08-vm.md) |
| 権限の判定器 | 実行時の権限制御の判定を行うもの（サーバモード）。初回リリース版は判定を行わない。初回リリース版の実行ごとの状態にこの欄を置くかは [OPEN-055](../open-issues.md#open-055) で、作り方と利用者が与える許可の形は [OPEN-052](../open-issues.md#open-052) で決める | [ランタイム](02-09-runtime.md) |
| 実行の入力 | コマンドライン引数、相対パスを解決する基準のディレクトリ、実行を始めるスクリプトのディレクトリ、標準入出力のつなぎ先（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)） | [スクリプト実行と埋め込み](02-11-embedding.md) |
| 出力先と出力のバッファ | 標準出力と標準エラー出力の書き出し先と、書き込んだがまだ書き出していない出力 | [ランタイム](02-09-runtime.md) |
| 中断の要求の読み口 | 中断の印を読むところ。CLI とサーバモードの子プロセスではプロセス全体の印を読む。後で加える埋め込みの API では、呼び出す側が実行ごとの印を与えてよい（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)） | [ランタイム](02-09-runtime.md) |
| 大きさの計数 | 呼び出しの入れ子の大きさ（すべてのタスクと保存した継続の枠を合わせて数える。[ADR 0030](../decisions/0030-call-stack-size-limit.md)、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。ヒープの使用量には上限を設けない | [仮想機械](02-08-vm.md) |
| 実行時エラーの情報 | 実行時エラーまたは資源の不足の種類と、呼び出しの履歴とタスクの起動の履歴を作る材料 | [仮想機械](02-08-vm.md), [ランタイム](02-09-runtime.md) |

【決定】処理系のどの段も、パッケージ変数などの大域的な可変状態を持たない。初期化の後に変更しない表（組み込みの関数の表など）は、大域に置いてよい（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）。この規則は、実行だけでなく検査の段にも適用する。

【決定】中断の要求（`SIGINT`・`SIGTERM`）を受けたことを表す印は、この規則の例外とし、プロセス全体で一つ持つ。印を書くのはシグナルの登録の仕組みだけであり、VM はタスクを切り替える位置と外部に作用する操作を待つ位置で印を読む（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。印を立てるのは CLI の `run` と `test` と、サーバモードの子プロセスである。サーバモードの実行時間の上限と `server job stop` による中断は、デーモンが子プロセスに `SIGTERM` を送って行うので、子プロセスの中では CLI と同じ印で表す（[スクリプト実行と埋め込み](02-11-embedding.md)の「サーバモードの実行」）。

### 関数の呼び出しと処理系のスタック

【決定】VM は、呼び出しの情報を実行ごとの状態の中に VM が管理するデータ構造として持ち、言語の関数の呼び出しと戻りで Rust の関数を入れ子に呼ばない（[ADR 0016](../decisions/0016-calls-off-go-stack.md)、[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。データ構造の形は[仮想機械](02-08-vm.md)で定める。

組み込みの関数（Rust で実装した関数）は、VM から Rust の関数として呼ぶ。初回リリース版には、関数を引数にとる組み込みの関数がある（`Task.all`・`TaskGroup.spawn`・`Reference.update` など）。タスクを起動する関数は、受け取った関数を新しいタスクの最初の呼び出しとして、そのタスクの呼び出しの情報に積む（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。組み込みの関数が受け取った関数を呼ぶときに、Rust の関数を入れ子に呼ばずに済ませる方法は、[仮想機械](02-08-vm.md)と[ランタイム](02-09-runtime.md)で定める。

【決定】検査・脱糖・コンパイルの段は AST と中間表現を再帰で辿るので、その深さは入れ子の上限（[字句解析器と構文解析器](02-03-frontend.md)の「入れ子の深さ」）で抑えられるが、使う Rust のスタックの量は最適化の水準などで変わる。そこで、これらの段を呼ぶパイプラインの公開の関数は、内部で 64 MiB のスタックを持つスレッドを作って段を実行し、結果を待つ。スレッドの中の panic は呼び出し側のスレッドで再び起こす。実行（VM）は呼び出し側のスレッドで行う（[ADR 0087](../decisions/0087-pipeline-stages-on-large-stack-thread.md)）。

## 未決事項

- [OPEN-007](../open-issues.md#open-007): WASM コア化の採否
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（実行の前に権限を示す経路と、実行ごとの状態に持つ許可の形）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
