# スクリプト実行と埋め込み

- 状態: 確定
- 関連ADR: [0015](../decisions/0015-shared-program-per-execution-state.md), [0030](../decisions/0030-call-stack-size-limit.md), [0037](../decisions/0037-exit-status-values.md), [0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md), [0049](../decisions/0049-size-limit-for-built-values.md), [0083](../decisions/0083-constant-descriptions-in-shared-program.md), [0120](../decisions/0120-test-functions-and-assert-effect.md), [0123](../decisions/0123-top-level-constants.md), [0127](../decisions/0127-directory-run-and-root.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0135](../decisions/0135-shebang-line-and-implicit-run.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0156](../decisions/0156-module-loading-and-whole-program-checking.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md), [0175](../decisions/0175-script-embedded-binary-before-stable-release.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0182](../decisions/0182-mcp-server-as-stdio-relay.md), [0206](../decisions/0206-test-command-line-and-exit-status.md), [0207](../decisions/0207-fmt-command-line.md), [0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md), [0237](../decisions/0237-no-heap-usage-limit-in-first-release.md)
- 未決事項: [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055)
- 移行元: [設計メモ](../sources/fp-language-design.md) 6, 20

## 目的と範囲

スクリプト実行のライフサイクルと埋め込み API。コンパイル済みプログラムと実行ごとの状態（モジュール状態、ハンドラ表、診断、資源追跡）の分離、実行環境の入力、結果の返却、中断の要求、後始末、再利用の可否を扱う。CLI の一回の実行、テストの実行器の繰り返しの実行、サーバモードの子プロセスでの実行、REPL の継続セッションで保持する状態の範囲を区別し、中断や資源上限のうち処理系が実装する部分とハーネスに委ねる部分を示す。シェバン、スクリプトを埋め込んだ実行ファイル、Rust のライブラリとして処理系を呼び出す API もここで扱う。言語から観測できるエントリポイントは[評価意味論](../01-spec/01-08-evaluation.md)、中断時の解放規則は[リソース管理](../01-spec/01-10-resources.md)、終了コードと標準入出力は[CLI](../06-tooling/06-01-cli.md)が扱う。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。初回リリース版でスクリプトを実行する手段は、スタンドアロンモードの CLI の `run`（`run` を省いた実行とシェバンによる実行を含む）と、CLI の `test` によるテストの実行である。サーバモードによる実行（デーモンが起動する子プロセスでの実行）は、初回リリース版の後に加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。本章のサーバモードにかかわる記述は、そのときの予定の設計である。REPL とスクリプトを埋め込んだ実行ファイルは初回リリース版の後に加え、Rust のライブラリとして処理系を呼び出す API は、ロードマップに時期を定めていない。本版は、それらを加えるときに守る状態の分け方も定める。

## 前提

コンパイル済みプログラムは実行の間で共有でき、実行中に変わる状態は実行ごとに分ける（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）。実行ごとの状態の中身と、実行の流れ・止める手順・中断の要求の扱いは[パイプライン](02-01-pipeline.md)、[仮想機械](02-08-vm.md)、[ランタイム](02-09-runtime.md)で定める。コマンドラインの形とオプションは [CLI](../06-tooling/06-01-cli.md) で、テストの書き方と結果の報告は[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で、MCP サーバの道具と通信の形は[サーバモード](../06-tooling/06-07-server.md)の「MCP の道具」で定める（[ADR 0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md)）。

## 仕様

### 状態の分け方

【方針】スクリプトの実行に関わる状態を、次の三つに分ける。

| 状態 | 中身 | 作る時期 | 共有 |
|---|---|---|---|
| 検査の状態 | ソースの表（実行を始めるファイル、import で辿ったモジュール、読んだ標準ライブラリのソース）、ノード番号と束縛の番号の数え上げ、名前解決と型検査の表、診断の一覧 | 検査ごと | しない |
| コンパイル済みプログラム | [バイトコードとコード生成](02-07-bytecode.md)の「コンパイル済みプログラム」。トップレベルの定数の値の記述を含む | 検査を通ったプログラムのコード生成ごと | 複数の実行とスレッドで共有してよい |
| 実行ごとの状態 | [ランタイム](02-09-runtime.md)の「実行ごとの状態」（タスクと呼び出しの情報、ハンドラ表、イベントループ、リソースの表、権限の判定器、出力先と出力のバッファ、実行の入力、実行時エラーの情報など） | 実行ごと | しない |

【方針】初回リリース版のトップレベルに置ける値は定数だけであり、定数の値はプログラムの実行の前に定まる（[ADR 0123](../decisions/0123-top-level-constants.md)）。定数の値の記述はコンパイル済みプログラムに置き、言語の値は実行の中で記述から作る（[パイプライン](02-01-pipeline.md)の「コンパイル済みプログラムと実行ごとの状態」、[ADR 0083](../decisions/0083-constant-descriptions-in-shared-program.md)）。可変のセルとリソースは実行の中でだけ作れるので、実行の間に持ち越すモジュールの状態はない。

### 実行を始めるファイルとプログラムの読み込み

【決定】`run`・`check` にディレクトリを指定したときは、そのディレクトリの `main.bnt` を実行を始めるファイルとし、ファイルを指定したときは、そのファイルを実行を始めるファイルとする。根のディレクトリは、実行を始めるファイルがあるディレクトリである。処理系は、プロジェクトの設定ファイルを読まない（[ADR 0127](../decisions/0127-directory-run-and-root.md)、[CLI](../06-tooling/06-01-cli.md)の「ディレクトリの指定（初回リリース版）」）。`test` にディレクトリを指定したときは、その下のすべての `.bnt` のファイルを、それぞれ実行を始めるファイルとし、根のディレクトリは指定したディレクトリとする（[ADR 0206](../decisions/0206-test-command-line-and-exit-status.md)）。

【決定】`benitoite [オプション] <スクリプトのパス> [スクリプトの引数...]` は `benitoite run` と同じ意味である。シェバンによる実行は、OS がシェバンの行に従ってこの形で処理系を起動するものであり、CLI の `run` による一回の実行と同じである（[ADR 0135](../decisions/0135-shebang-line-and-implicit-run.md)、[CLI](../06-tooling/06-01-cli.md)の「`run` を省いた実行とシェバン（初回リリース版）」）。字句解析はシェバンの行を読み飛ばす（[字句構造](../01-spec/01-01-lexical.md)の「シェバンの行（初回リリース版）」）。

【決定】読み込みの段は、実行を始めるファイルから始め、import が指すファイルを辿って読む。根のディレクトリの下のファイルのうち、import で辿れないものは読まない。名前解決と型検査は、プログラム全体を一つの単位として行う（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)、[名前解決とモジュール読込](02-04-resolver.md)）。

【方針】`Process.scriptDirectory()` が返す実行を始めるスクリプトのディレクトリは、実行を始めるファイルのパスから、実行を始めるときに一度だけ求め、実行の入力に入れる。シンボリックリンクを解決した絶対パスとし、作業ディレクトリに依存させない（[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)、[エフェクト](../01-spec/01-07-effects.md)）。

### CLI の一回の実行

【方針】`run` は、次の順に処理する。

1. コマンドラインを解釈し、実行を始めるファイルを決める。使い方の誤りがあれば、終了状態 2 で終わる（[CLI](../06-tooling/06-01-cli.md)）。
2. 中断の要求（`SIGINT`・`SIGTERM`）を受ける設定をする（[ランタイム](02-09-runtime.md)の「中断の要求」、[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。
3. 検査の状態を作り、読み込みから型検査までの段を行う。誤りがあれば、診断を書いて終了状態 2 で終わる（[パイプライン](02-01-pipeline.md)、[ADR 0037](../decisions/0037-exit-status-values.md)）。警告は書き、`--deny-warnings` を指定していなければ次へ進む（[ADR 0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md)）。
4. 脱糖とコード生成を行い、コンパイル済みプログラムを作る。処理系の制限に当たれば、診断を書いて終了状態 2 で、処理系の不具合が起きれば、その報告を書いて終了状態 3 で終わる（[診断エンジン](02-10-diagnostics.md)）。検査の状態は、ここで不要になる。
5. 実行ごとの状態を作り、`main` を実行して、終わり方に応じて終える（[ランタイム](02-09-runtime.md)の「プログラムの実行の流れ」）。

`check` は、1 と 3 だけを行う。どちらも、終わったときにすべての状態を捨てる。

### テストの実行

【方針】`test` は、実行を始めるファイルごとに 1・3・4 と同じく検査とコード生成を行い、そのファイルに書いたテストの関数を実行する（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)の「テストの実行」）。一つのファイルのテストは、同じコンパイル済みプログラムを共有する。検査の誤りがあるファイルのテストは実行せず、ほかのファイルへ進む（[ADR 0206](../decisions/0206-test-command-line-and-exit-status.md)）。

【決定】テストは、一つずつ別の実行として動かす（[ADR 0120](../decisions/0120-test-functions-and-assert-effect.md)）。

【方針】テストの実行器は、テストごとに次のように実行する。

- 実行ごとの状態を作り、`main` の代わりにテストの関数を、引数なしで最初のタスクとして呼ぶ。ハンドラ表は本番のものである（[ランタイム](02-09-runtime.md)の「組み込みの操作とハンドラ表」）。
- `Assert.Check` の操作は、テストの実行器が、最初のタスクのハンドラの連鎖の最も外側に置く組み込みのハンドラで処理する。このハンドラは、起動したタスクにも引き継がれる。確認が成り立てば操作の呼び出しに `()` を返して続け、成り立たなければ、確認の失敗を理由に[仮想機械](02-08-vm.md)の「止める手順」でそのテストの実行を止める。利用者が `Assert.Check` を処理する言語のハンドラを書いたときは、そちらが先に処理する（[ランタイム](02-09-runtime.md)の「操作の振り分け」）。
- テストの関数が `()` か `Result.Ok(())` を返せば成功、`Result.Error(message)` を返すか、確認の失敗、実行時エラー、資源の不足、`Process.exit` で止まれば失敗とする（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。実行時エラーと資源の不足の報告は、[診断エンジン](02-10-diagnostics.md)の実行時エラーの報告と同じ内部の表現で作り、テストの結果に含める。
- 標準入力は空の入力とし、標準出力と標準エラー出力は、テストごとに捕らえて結果に含める（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。基準のディレクトリは、処理系を起動したときの作業ディレクトリとする。コマンドライン引数は空の並びとする。
- 初回リリース版のテストの実行器は、実行時の権限制御の判定を行わない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。サーバモードで権限制御を加えるときに、テストの実行器が作る権限の判定器と、与える許可を [OPEN-052](../open-issues.md#open-052) で決める（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）。
- 処理系の不具合が起きたときは、ほかのテストを続けず、その報告を書いて終了状態 3 で終わる。

【方針】テストを複数のスレッドで同時に実行するかは、実装プランで定める。テストごとに実行ごとの状態を分けるので、同時に実行しても一つのテストの結果は変わらない。ただし、テストが外部の状態（ファイル、環境）を共有すれば結果が変わりうるので、テストはほかのテストの実行に依存してはならない（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)）。

【方針】`test` の実行中に中断の要求を受けたときは、実行中のテストを止める手順で止め、残りのテストを実行せずに、それまでの結果を報告して終了状態 130 で終える（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。

### サーバモードの実行

【決定】サーバモードは、初回リリース版の後に加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。デーモンは、スクリプトを実行ごとの子プロセスで実行し、一つの子プロセスは一つの実行だけを行う。MCP サーバ（`benitoite mcp`）は、要求をデーモンに中継するだけで、自分では実行しない（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)、[ADR 0182](../decisions/0182-mcp-server-as-stdio-relay.md)）。デーモンの運用（ジョブ、出力の保存、実行時間の上限）は[サーバモード](../06-tooling/06-07-server.md)で、子プロセスに掛ける制限は [OS のサンドボックス](02-12-os-sandbox.md)で定める。

【方針】子プロセスの中の一回の実行は、CLI の `run` による一回の実行と同じ状態の持ち方をする（前述の「CLI の一回の実行」）。検査の状態、コンパイル済みプログラム、実行ごとの状態は、どれも子プロセスの中で作り、子プロセスが終わるときに捨てる。デーモンは、検査の結果を保存するが（[ADR 0191](../decisions/0191-server-data-storage.md)）、コンパイル済みプログラムと実行ごとの状態は持たない。

【方針】子プロセスの実行は、CLI の `run` と次の点が異なる。

- 標準入力は空の入力につなぐ。標準出力と標準エラー出力は、デーモンにつなぎ、デーモンがジョブの出力として保存する（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- 基準のディレクトリは、デーモンが子プロセスの作業ディレクトリにする。子プロセスには、実行ごとに一つの基準のディレクトリしかないので、CLI の `run` と同じく作業ディレクトリから相対パスを辿る。
- 環境変数は、デーモンが選んだもの（`--env` で指定したものと、プロキシの環境変数）だけを渡す（[サーバモード](../06-tooling/06-07-server.md)の「実行の手順」）。
- `Process.exit` は、子プロセスを指定した終了状態で終える。デーモンは、その終了状態をジョブの結果とする。
- 実行時間の上限と `server job stop` による停止は、デーモンが子プロセスに中断の要求（`SIGTERM`）を送って行う。子プロセスは、CLI の中断の要求と同じ止める手順で止まる（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。
- 処理系の不具合（panic）は、子プロセスの中で報告して子プロセスを終える。デーモンとほかのジョブには及ばない。

子プロセスごとにメモリが分かれるので、一つの実行のメモリの使い尽くしは、ほかの実行に及ばない。子プロセスに OS の仕組みでメモリの上限を掛けるかは、サーバモードの設計（[OPEN-055](../open-issues.md#open-055)）で決める（[ADR 0237](../decisions/0237-no-heap-usage-limit-in-first-release.md)）。

### 実行の入力と結果

【方針】スクリプトが実行の外から受け取るものは、次のものに限る。

| 入力 | CLI の `run` | テストの実行器 | サーバモードの子プロセス | 使う操作 |
|---|---|---|---|---|
| コマンドライン引数 | スクリプトのパスより後の引数 | 空の並び | 要求の `--` より後の引数 | `Process.arguments` |
| 標準入力 | 処理系のプロセスの標準入力 | 空の入力 | 空の入力 | `Console.Read` の操作、`Process.runAttached` |
| 環境変数 | 処理系のプロセスの環境変数 | 同じ | デーモンが選んだもの（[サーバモード](../06-tooling/06-07-server.md)の「実行の手順」） | `Process.environmentVariable`、外部コマンドの起動 |
| 基準のディレクトリ | 処理系を起動したときの作業ディレクトリ | 同じ | デーモンが与える子プロセスの作業ディレクトリ | 相対パスを受け取る操作、`Process.workingDirectory`、外部コマンドの起動 |
| 実行を始めるスクリプトのディレクトリ | 実行を始めるファイルから求める | 同じ | 同じ | `Process.scriptDirectory` |
| ファイルシステム | OS | 同じ | 同じ | `File` の操作 |
| 外部コマンド | OS | 同じ | 同じ | `Process.Run` の操作 |
| 時刻 | OS の時計。単調な時計の起点は実行を始めた時点 | 同じ | 同じ | `Clock.Time` の操作 |
| 乱数の種 | 実行を始めるときに OS の乱数から決める | 同じ | 同じ | `Random.Generate` の操作 |
| ネットワーク | OS | 同じ | 同じ | `Http.Listen`・`Http.Connect` の操作 |
| 利用者の許可 | なし。初回リリース版は実行時の権限制御を行わず、すべての操作を行える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)） | 同じ | 実行ごとの方針（[サーバモード](../06-tooling/06-07-server.md)の「実行の手順」） | 権限の判定器（[ランタイム](02-09-runtime.md)の「実行時の権限制御の判定」） |

言語のハンドラで処理した組み込みの操作は、上の入力を使わない。

【方針】実行の結果は次のものである。CLI の `run` では、出力は処理系のプロセスの標準出力と標準エラー出力に書き、終わり方は終了状態で表す。テストの実行器では、処理系のプロセスを終えずに、これらを結果として受け取る（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。サーバモードでは、デーモンが子プロセスの出力と終了状態を受け取る。

| 結果 | 内容 |
|---|---|
| 終わり方 | `main`（テストではテストの関数）が値を返した、`Result.Error` を返した、実行時エラー、資源の不足、確認の失敗（テストだけ）、`Process.exit`、中断の要求、処理系の不具合 |
| 終了状態 | CLI の終了状態と同じ値（[CLI](../06-tooling/06-01-cli.md)の「終了状態」）。`Process.exit` では指定した値、中断の要求では 130 |
| 出力 | スクリプトが標準出力と標準エラー出力に書いた内容 |
| 報告 | 警告、`main` の `Result.Error` の文字列、実行時エラー・資源の不足・解放の失敗・処理系の不具合の報告（[診断エンジン](02-10-diagnostics.md)） |

### 資源の上限と中断

【方針】処理系が実装する資源の上限は、呼び出しの情報の大きさ（すべてのタスクと保存した継続を合わせて数える。[ADR 0030](../decisions/0030-call-stack-size-limit.md)、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）と、一つの操作で作る文字列・`Bytes`・リストの大きさ（[ADR 0049](../decisions/0049-size-limit-for-built-values.md)、[ランタイム](02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）と、サーバモードの実行時間の上限（[サーバモード](../06-tooling/06-07-server.md)の「ジョブ」）である。CLI の実行時間とヒープの使用量の上限は、処理系を起動する側（Agent Skills を実行するハーネス、シェル、OS）に委ねる（[ADR 0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md)、[ADR 0237](../decisions/0237-no-heap-usage-limit-in-first-release.md)）。

【決定】CLI の `run` と `test` は、中断の要求（`SIGINT`・`SIGTERM`）を受けたら、すべてのタスクを取り消し、`with` のリソースを解放し、出力を書き出してから、終了状態 130 で終える。解放の途中で二度目の要求を受けたら、OS の既定の振る舞いで終える（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。仕組みは[ランタイム](02-09-runtime.md)の「中断の要求」で定める。`check` と `fmt` は中断の要求を特別に扱わず、OS の既定の振る舞いに任せる（`fmt` は [ADR 0207](../decisions/0207-fmt-command-line.md)。途中で中断されてもファイルを壊さないように、整形の結果を一時ファイルに書いてから名前の変更で置き換える）。

### 後から加える実行の形

【方針】初回リリース版の後に加える実行の形は、状態の分け方に従い、次のように状態を持つ。

| 実行の形 | 検査の状態 | コンパイル済みプログラム | 実行ごとの状態 |
|---|---|---|---|
| REPL（初回リリース版の後） | 入力のたびに、それまでの定義を含めて検査する形を、REPL を設計するときに決める | 同じ | セッションの間、何を持ち越すかを REPL を設計するときに決める |
| Rust のライブラリとして処理系を呼び出す API（時期は未定）、スクリプトを埋め込んだ実行ファイル（初回リリース版の後、正式リリース版の前まで。[ADR 0175](../decisions/0175-script-embedded-binary-before-stable-release.md)） | API を設計するときに決める | 一度作って、複数の実行とスレッドで共有できる | 呼び出しごとに作る |

API を設計するときは、テストの実行器と同じく、出力先、標準入力、基準のディレクトリ、中断の要求の読み口、権限の判定器（実行時の権限制御を加えた後）を、呼び出す側が実行ごとに与える形にする。

## 未決事項

- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（サーバモードで、CLI・テストの実行器・デーモンが与える許可）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
