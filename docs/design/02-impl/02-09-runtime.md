# ランタイム

- 状態: 確定
- 関連ADR: [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0015](../decisions/0015-shared-program-per-execution-state.md), [0016](../decisions/0016-calls-off-go-stack.md), [0029](../decisions/0029-two-io-execution-modes.md), [0030](../decisions/0030-call-stack-size-limit.md), [0037](../decisions/0037-exit-status-values.md), [0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md), [0045](../decisions/0045-late-detection-of-output-write-failure.md), [0049](../decisions/0049-size-limit-for-built-values.md), [0068](../decisions/0068-release-resources-on-stop.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0072](../decisions/0072-permission-path-matching.md), [0073](../decisions/0073-run-permission-command-matching.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0079](../decisions/0079-rust-readings-of-go-based-decisions.md), [0088](../decisions/0088-keep-both-io-execution-modes.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0143](../decisions/0143-http-and-tls-crates.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0150](../decisions/0150-resource-release-as-state.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0152](../decisions/0152-task-allok-list-order.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0164](../decisions/0164-taskgroup-release-while-stopping.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0167](../decisions/0167-reference-update-by-version-retry.md), [0170](../decisions/0170-http-accept-failure-classification.md), [0176](../decisions/0176-first-release-targets-and-static-linux-build.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0183](../decisions/0183-single-policy-for-all-permission-layers.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0186](../decisions/0186-run-time-policy-can-only-narrow.md), [0187](../decisions/0187-standalone-reads-user-policy-file.md), [0204](../decisions/0204-standalone-runs-in-sandboxed-child.md), [0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md), [0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md), [0222](../decisions/0222-http-tests-over-loopback.md), [0237](../decisions/0237-no-heap-usage-limit-in-first-release.md), [0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md), [0239](../decisions/0239-cycle-collection-for-reference-cells.md), [0240](../decisions/0240-runtime-redesign-in-first-release-plan.md), [0255](../decisions/0255-bind-and-shadow.md), [0259](../decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md), [0260](../decisions/0260-heap-and-unsafe-boundary.md), [0261](../decisions/0261-typed-builtin-interface.md), [0264](../decisions/0264-single-dispatch-queue-for-builtin-operations.md), [0265](../decisions/0265-output-transfer-by-writer-threads.md), [0266](../decisions/0266-task-and-resource-state-machines.md), [0268](../decisions/0268-staged-runtime-rebuild.md), [0270](../decisions/0270-open-062-items-in-runtime-rebuild.md), [0277](../decisions/0277-refcount-defers-freeing-to-safepoints.md), [0280](../decisions/0280-reuse-by-dedicated-construct-instruction.md), [0281](../decisions/0281-heap-number-in-slot-and-contract-safety.md), [0282](../decisions/0282-cancellation-timing-during-unwinding-and-requests.md), [0283](../decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)
- 未決事項: [OPEN-036](../open-issues.md#open-036), [OPEN-051](../open-issues.md#open-051), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-062](../open-issues.md#open-062)
- 移行元: [設計メモ](../sources/fp-language-design.md) 7

## 目的と範囲

メモリの管理、IO 実行器、リソースの追跡、panic 境界、実行ごとの状態の管理。外部に作用する組み込みの操作を行う場所であり、実行時の権限制御の判定と、外部の誤りを言語の値（`IOError`・`NetworkError`）へ変える処理もここに置く。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。対象は、メモリの管理、実行ごとの状態、組み込みの操作を行うハンドラ表、IO 実行器（イベントループと作業用のスレッド）、タスクの切り替えのうちランタイムが受け持つ部分、実行時の権限制御の判定の位置、リソースの追跡、出力のバッファ、一つの操作で作る値の大きさの上限、中断の要求、panic 境界、プログラムの実行の流れである。実行時の権限制御と MCP サーバは、初回リリース版には含めず、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。本章のそれらにかかわる記述は、サーバモードで実装する予定の設計である。

初回リリース版には外部の関数の層を設けず、外部に作用する組み込みの関数はすべて処理系の一部として IO 実行器を通る（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。後の版の外部の関数は WASM のモジュールの関数とし、ホストの関数を通じてだけ外部に作用させる（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)、[ADR 0077](../decisions/0077-abolish-go-layer.md)）。ホストの関数の登録形式、呼び出し規約、外部の関数から言語へ戻るときの扱いは、外部の関数を実装する版で定める（[OPEN-051](../open-issues.md#open-051)）。

## 前提

組み込みのエフェクトと操作、ハンドラの意味、実行時の権限制御の規則は[エフェクト](../01-spec/01-07-effects.md)で、実行時エラーと資源の不足による停止は[評価意味論](../01-spec/01-08-evaluation.md)で、リソースの解放の時期と順序は[リソース管理](../01-spec/01-10-resources.md)で、タスク・取り消し・停止は[並行処理](../01-spec/01-11-concurrency.md)で定める。各組み込みの操作の振る舞いは[IO のモジュール](../03-interop/03-07-io-modules.md)と[ネットワークのモジュール](../03-interop/03-09-network.md)で定める。本章は、これらを処理系がどう行うかだけを定め、振る舞いを繰り返さない。

VM の実行の手順、ハンドラの継続、タスクごとの呼び出しの積み重ねは[仮想機械](02-08-vm.md)で定める。各機構の保証の範囲は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

## 仕様

### メモリの管理

【決定】言語の値のヒープの対象は、実行ごとのヒープに、自前の確保器で確保する。対象の確保と、対象が指す値を辿る処理は、ランタイムのヒープのモジュールに閉じ込め、`unsafe` はこのモジュールでだけ使う（[ADR 0260](../decisions/0260-heap-and-unsafe-boundary.md)）。長いリストや深い木の値を解放・印付けするときは、処理系のスタックを使い果たさないよう、明示の積み重ねで辿る。

【決定】ヒープのモジュールは、回収しない区間を Rust の寿命で表す型（`Value<'epoch>`・`NoGcCtx<'epoch>`）を外に出し、区間の中の処理には回収の機能を渡さない。安全点へ戻る前に、この先使う値を VM の根の保存領域に置く。区間の寿命を外した値を扱うのは、根の保存領域と根の列挙を管理する小さな内部の実装だけである。別の実行のヒープの値を渡す誤りは、区間の中では型の印で防ぎ、根の保存領域では、保存した値が持つヒープの番号をすべてのビルドで比べて見つける（[ADR 0260](../decisions/0260-heap-and-unsafe-boundary.md)、[ADR 0281](../decisions/0281-heap-number-in-slot-and-contract-safety.md)）。根の列挙の漏れは型で防げないので、ヒープのモジュールの API が安全と言えるのは、VM が根を漏れなく列挙し、列挙しなかった根を回収の後に読まないかぎりにおいてである（ADR 0281）。

【未決】使わなくなった対象を回収する方式は、次の二つを作り直しの第 1 段で試作し、測定で暫定に選び、ハンドラ・タスク・IO を加えた後に確かめて確定する（[ADR 0259](../decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)、[ADR 0268](../decisions/0268-staged-runtime-rebuild.md)、[OPEN-036](../open-issues.md#open-036)）。二つは、同じ値の配置・確保器・VM の上で入れ替えられる形で作り、生きている値の集合を揃えて比べる。

| 方式 | 概要 |
|---|---|
| マーク・スイープ | 止めて行う非移動のマーク・スイープ。回収は安全点（[仮想機械](02-08-vm.md)の「タスクの切り替え」）でだけ行う。前回の回収からの確保の量 A が、前回の回収で数えた生きている量 L に対して `A >= max(4 MiB, k × L)` を満たしたら回収を要求する。k は 1 から始め、第 1 段で 0.5・1・2 を比べて決める |
| 改良した参照カウント | 対象の頭に参照の数を置く。数は、根の保存領域と対象の中にある参照だけで数え、回収しない区間の中の値の写しは数えない。区間の中で数が 0 になった対象は、区間の中では解放せず、安全点の回収で解放する（[ADR 0277](../decisions/0277-refcount-defers-freeing-to-safepoints.md)）。したがって、この方式でも前述の区間と根の規則が要る。コード生成が最後の使用を移動にし、`match` で分けた値の対象を、ほかに参照がなければ同じ大きさの構成子を適用した値にその場で再利用する（専用の命令 `CONR` で行い、実行ごとのヒープの設定で無効にできる。[ADR 0280](../decisions/0280-reuse-by-dedicated-construct-instruction.md)）。循環は、`Reference` のセルだけを起点に回収する（[ADR 0239](../decisions/0239-cycle-collection-for-reference-cells.md)。この方式を採る場合に限り残す） |

言語には値を解放するときに走る処理がなく、リソースはメモリの管理では解放されない（後述の「リソースの追跡」）。したがって、どちらの方式でも回収の時期は観測できない。

書き込みの障壁を差し込む位置（セルの書き込み、`Lazy` の結果の書き込み、タスクの結果の書き込み、継続の状態の変更）は、API の上で一か所ずつにまとめる。増分の回収や若い世代を後で加えるときに使う。

リソースの値は、後述の「リソースの追跡」のとおり、リソースの表の番号として持つ。リソースの表の項目は言語の値を指さないので、リソースの値を捕捉したラムダをタスクとして起動しても、参照の循環はできない。

### 実行ごとの状態

【方針】ランタイムは、実行を一つ始めるたびに実行ごとの状態を作る（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）。一つの実行を同時に進めるスレッドは一つだけであり、以下、このスレッドを VM のスレッドと呼ぶ。実行ごとの状態は、VM が使うもの（タスクごとの呼び出しの積み重ね、スケジューラ、リソースの表。[仮想機械](02-08-vm.md)、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）に加えて、次のものを持つ。

| 状態 | 内容 |
|---|---|
| ハンドラ表 | 組み込みの操作ごとに、それを行う Rust の関数を持つ表（後述の「組み込みの操作とハンドラ表」） |
| イベントループ | `mio` の待ち受けの登録と、時間の経過を待つタイマーの並び（後述の「IO 実行器」） |
| 送り出しの列 | 言語のハンドラが処理しなかった組み込みのエフェクトの操作の要求の並び（後述の「IO 実行器」、[ADR 0264](../decisions/0264-single-dispatch-queue-for-builtin-operations.md)） |
| 外部の操作の記録 | 作業用のスレッドとイベントループで行っている操作を、操作の番号から引く表。操作を待つタスク（いれば）と、貸したリソースを持つ。タスクへの結果の配送を取り消しても、完了するまで消さない（[ADR 0266](../decisions/0266-task-and-resource-state-machines.md)） |
| 待ちの表 | 外部に作用する操作の完了を待つタスクを、操作の番号から引く表 |
| 権限の判定器 | 実行時の権限制御の判定を行うもの（後述の「実行時の権限制御の判定」。サーバモード） |
| 出力先と出力のバッファ | 標準出力と標準エラー出力それぞれの書き出し先、バッファ、書き出し用のスレッドとの連絡の口（後述の「出力のバッファ」、[ADR 0265](../decisions/0265-output-transfer-by-writer-threads.md)） |
| 標準入力の読み手 | 標準入力をバッファ付きで読む読み手。実行の中の読み取りの位置を保つ |
| 実行の入力 | コマンドライン引数の並び、基準のディレクトリ、実行を始めるスクリプトのディレクトリ（[スクリプト実行と埋め込み](02-11-embedding.md)の「実行の入力と結果」） |
| 時計の起点 | 実行を始めた時点の単調な時計の値。`Clock.monotonicMilliseconds` はここからの経過のミリ秒を返す |
| 隠れた乱数の生成器 | `Random.Generate` の操作が使う生成器（後述の「組み込みの操作とハンドラ表」） |
| 中断の要求の読み口 | 中断の印を読むところ（後述の「中断の要求」） |
| 実行時エラーの情報 | 実行時エラーまたは資源の不足の種類、止まったタスクと命令、呼び出しの履歴とタスクの起動の位置の材料（[仮想機械](02-08-vm.md)の「実行時エラーの情報の記録」） |
| 書き込みの失敗の記録 | 標準出力と標準エラー出力それぞれについて、書き出しに失敗したか、失敗の理由（Rust の `std::io::Error` の文字列） |
| 終わり方の記録 | 止める手順を始めた理由（実行時エラー、資源の不足、`Process.exit` とその終了状態、中断の要求、テストの確認の失敗） |

基準のディレクトリは、相対パスを解決する起点である。CLI の `run` とサーバモードの子プロセスでは処理系を起動したときの作業ディレクトリであり（サーバモードではデーモンが子プロセスの作業ディレクトリを決める。[スクリプト実行と埋め込み](02-11-embedding.md)の「サーバモードの実行」）、テストの実行器の実行では、実行ごとに与える（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。処理系は、プロセスの作業ディレクトリと環境変数を、実行ごとに変えない。

### 組み込みの操作とハンドラ表

【決定】組み込みのエフェクトの操作（[エフェクト](../01-spec/01-07-effects.md)の「組み込みのエフェクト」。`Console.writeLine`、`File.readText`、`Http.send` など）は、それぞれハンドラ表の一つの項目に当たる。ハンドラ表の項目は、引数の値の並びを受け取り、後述の応答を返す Rust の関数である。項目の関数は、組み込みの関数と同じく、名前と型の付いた引数を受け取る形で書き、宣言から登録する（[ADR 0261](../decisions/0261-typed-builtin-interface.md)）。

ハンドラ表は、言語のハンドラ（`handle` の式）とは別のものである。言語のハンドラは、スクリプトが書いた節で操作を処理し、ハンドラ表は、どの言語のハンドラも処理しなかった組み込みの操作を、処理系が実際に行うための表である。

`State` を型に持つ組み込みの関数（`Reference` と `TaskGroup` の関数、`Task.await`、リソースを解放する関数）は操作ではない（[ADR 0150](../decisions/0150-resource-release-as-state.md)）ので、ハンドラ表と送り出しの列を通さず、言語のハンドラも権限の判定器も調べない。ただし、タスクの終わりやリソースの返却を待つことはある（[仮想機械](02-08-vm.md)の「組み込みの関数の呼び出し」の待つ理由）。

【方針】ハンドラ表は次の二つを用意し、実行を始めるときにどちらかを実行ごとの状態に入れる。

| ハンドラ表 | 使う場面 | 内容 |
|---|---|---|
| 本番のハンドラ表 | `run`・`test`、サーバモードの子プロセスの実行 | 操作を実際に行う |
| テスト用のハンドラ表 | 処理系のテスト（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)） | 書き込みをメモリに記録し、ファイルの内容・コマンドライン引数・時刻・乱数などを与えられた値から返す。ネットワークの操作は本番と同じく実際に行い、テストが指定した操作にだけ、ループバックの通信では起こしにくい失敗（名前の解決の失敗、接続の拒否、接続のリセット、時間切れ）を返す（[ADR 0222](../decisions/0222-http-tests-over-loopback.md)） |

利用者のプログラムのテスト（`test`）は本番のハンドラ表を使う。組み込みの操作を差し替えるのは、スクリプトが書いた言語のハンドラである（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)）。

【方針】ハンドラ表の関数は、[仮想機械](02-08-vm.md)の「組み込みの関数の呼び出し」の応答のうち、完了・待つ・終了（`Process.exit`）のどれかを返す。操作ごとに次の場所で操作を行う（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）。

| 行う場所 | 操作 |
|---|---|
| VM のスレッドで、すぐに完了する | `Console.write`・`Console.writeLine`・`Console.writeError`・`Console.writeErrorLine`（出力のバッファに書く。転送していない量の上限で受け付けられなければ待つ。後述の「出力のバッファ」）、`Process.arguments`・`Process.scriptDirectory`・`Process.workingDirectory`・`Process.environmentVariable`、`Process.exit`（応答の「終了」を返し、[仮想機械](02-08-vm.md)の「止める手順」を始める）、`Http.listenerPort`、`Clock.now`・`Clock.localOffsetMinutes`・`Clock.monotonicMilliseconds`、`Random` の操作 |
| イベントループで待つ | `Clock.sleep`、`Http.listenerPort` を除く `Http.Listen` の操作（`Http.listen`・`Http.accept`・`Http.respond`） |
| 作業用のスレッドで行う | `Console.readLine`・`Console.readAll`・`Console.readAllLines`・`Console.readAllBytes`、`File.Read`・`File.Write` のすべての操作（`File.Reader`・`File.Writer` の読み書きを含む）、`Process.run`・`Process.runAttached`・`Process.shell`、`Http.Connect` の操作（`Http.get`・`Http.send`）、`Http.listen` の名前の解決 |

- `Process.workingDirectory` は基準のディレクトリの絶対パスを返し、相対パスは基準のディレクトリから解決する。外部コマンドは、`Process.Command` の `workingDirectory` が `Option.None` なら基準のディレクトリを作業ディレクトリとして起動し、相対パスで指定されていれば基準のディレクトリから解決する（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- `Process.scriptDirectory` は、実行を始めたときに解決した値を実行の入力から返す（[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)）。
- 隠れた乱数の生成器は、実行を始めるときに `getrandom` で得た OS の乱数を種とし、`Random.fromSeed` と同じアルゴリズム（[IO のモジュール](../03-interop/03-07-io-modules.md)の「Random」）で値を作る（[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)）。
- 標準入力の読み取りは、実行ごとの状態の標準入力の読み手を作業用のスレッドに渡して行う。二つのタスクが同時に標準入力を読むときは、操作を呼んだ順に一つずつ行う。
- `Process.runAttached` は、コマンドを起動する前に、それまでの出力の転送の完了を待つ（後述の「出力のバッファ」）。スクリプトがそれまでに書いた内容を、コマンドの出力より前に出すためである。コマンドの標準入出力は、実行ごとの状態の出力先と標準入力につなぐ（CLI の `run` とサーバモードの子プロセスでは処理系のプロセスのもの。テストの実行器の実行では、空の入力と、その実行の出力先。[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- HTTP のサーバは、`httparse` で要求を解析し、`mio` で待ち受けと読み書きを行う層を自作する。HTTP のクライアントは `ureq` を作業用のスレッドで呼ぶ（[ADR 0143](../decisions/0143-http-and-tls-crates.md)、[ネットワークのモジュール](../03-interop/03-09-network.md)の「実装に使うクレート」）。
- `Http.accept` は、受け付けの失敗を接続ごとの失敗・資源の不足・待ち受けの失敗に分け、待ち受けの失敗だけを `NetworkError` にして返す（[ネットワークのモジュール](../03-interop/03-09-network.md)の「失敗の種類」、[ADR 0170](../decisions/0170-http-accept-failure-classification.md)）。資源の不足に当たる OS の誤りは、Unix では `EMFILE`・`ENFILE`・`ENOBUFS`・`ENOMEM` である。資源の不足でやり直すまで待つ時間は、`Clock.sleep` と同じくイベントループの時間の経過で待つ。
- OS やクレートが返した誤りは、ハンドラ表の関数が `IOErrorKind`・`NetworkErrorKind` の値と、理由の文字列を持つ `IOError`・`NetworkError` の値に変える。どの誤りをどの種類にするかは、実装プランで定める。
- 外部から受け取るバイト列を `String` にする操作は、VM のスレッドで UTF-8 として正しいかを確かめ、正しくなければ `IOErrorKind.InvalidUTF8` を返す。確かめは文字列の値を作る API に集め、確かめない経路で文字列の値を作れないようにする（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。

【方針】組み込みの関数が言語の関数を呼ぶ必要があるとき（`Reference.update` の `f` など）も、Rust の関数の中から言語の関数を入れ子に呼ばない（[ADR 0016](../decisions/0016-calls-off-go-stack.md)）。標準ライブラリのソースで書くか、VM に呼び出しを戻す形（応答の「タスクの起動」、専用の命令 `UPDATE`・`FORCE`）で実装する。`Reference.update` は、`f` を呼ぶ間もタスクを切り替えてよく、書き込むときにセルの版の番号を確かめて、変わっていれば読み出しからやり直す（[仮想機械](02-08-vm.md)の「可変のセル」、[ADR 0167](../decisions/0167-reference-update-by-version-retry.md)）。

### 操作の振り分け

【方針】VM がタスクの中で組み込みの操作の呼び出しを評価したときは、次の順に処理する（[エフェクト](../01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」、[セキュリティモデル](../07-quality/07-01-security-model.md)）。

1. VM が、そのタスクのハンドラの連鎖から、その操作の節を持つ最も内側の言語のハンドラを探す（[仮想機械](02-08-vm.md)、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。見つかれば、その節を実行する。タスクが引き継いだハンドラの節が末尾で再開する節でなければ、実行時エラー（引き継いだハンドラの節の誤り）とする（[ADR 0151](../decisions/0151-inherited-handlers-tail-resume-only.md)）。この場合、操作はランタイムに渡らず、権限の判定もしない。
2. 見つからなければ、VM は操作と引数の値の並びを番号付きの要求にし、タスクを待たせてから、送り出しの列に置く（[ADR 0264](../decisions/0264-single-dispatch-queue-for-builtin-operations.md)）。IO 実行器は列から要求を受け取る。
3. IO 実行器は、その操作が権限を要するものであれば、権限の判定器で判定する（後述の「実行時の権限制御の判定」）。拒否されたら、操作を行わずに実行時エラー（権限の拒否）とする。この手順はサーバモードで加える。初回リリース版では判定をせず、次の手順に進む。
4. 許可されたら、ハンドラ表の関数で操作を行う。

利用者が定義するエフェクトの操作は、型検査によって必ずどこかの言語のハンドラが処理する（[エフェクト](../01-spec/01-07-effects.md)の「プログラムの入口」）ので、手順 2 に達しない。達したときは処理系の不具合とする。`Assert.Check` の操作は、テストの実行器が処理する（[スクリプト実行と埋め込み](02-11-embedding.md)の「テストの実行」）。

### 実行時の権限制御の判定

【決定】初回リリース版のランタイムは、実行時の権限制御の判定を行わない。組み込みの操作は、処理系を起動した利用者の OS の権限の範囲で、すべて行う（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。本節は、初回リリース版の後にサーバモードとあわせて加える判定の設計である。サーバモードを加えた後は、サーバモードでもスタンドアロンモードでも、スクリプトを OS のサンドボックスを掛けた子プロセスで実行し、判定はその子プロセスの中で行う（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)、[ADR 0204](../decisions/0204-standalone-runs-in-sandboxed-child.md)）。初回リリース版の実装に判定を差し込む位置（すべてを許可する判定器など）を残すかは、[OPEN-055](../open-issues.md#open-055) で決める。

【方針】実行時の権限制御の判定は、上の手順 3 の一か所だけで行う。拒否できるのは、この位置を通る操作に限る（[セキュリティモデル](../07-quality/07-01-security-model.md)の「保証が成り立つ条件」）。判定の中身は、実行ごとの状態に入れる権限の判定器が決める。権限の判定器は、次の入力を受け取り、許可か拒否を返す Rust の trait として表す。

| 入力 | 内容 |
|---|---|
| 許可の単位 | 組み込みのエフェクト（`File.Read`・`File.Write`・`Process.Run`・`Process.Environment`・`Process.Exit`・`Http.Listen`・`Http.Connect`）と、シェルによる実行（[エフェクト](../01-spec/01-07-effects.md)の「実行時の権限制御」、[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)） |
| 対象 | パスの権限では、スクリプトが渡したパスと、それを解決した絶対パス（[ADR 0072](../decisions/0072-permission-path-matching.md)）。`Process.Run` では、スクリプトが渡したコマンドの名前と、見つけた実行ファイルの絶対パス（[ADR 0073](../decisions/0073-run-permission-command-matching.md)）。`Process.Environment` では環境変数の名前。シェルによる実行と `Process.Exit` ではなし |
| 操作 | 操作の名前（`File.openWriter` など） |

- パスの解決（基準のディレクトリから辿って絶対パスにし、シンボリックリンクを解決し、まだ存在しない残りの構成要素を付ける）と、`Process.Run` のコマンドの PATH からの探索は、ランタイムが行ってから判定器に渡す。どちらもファイルシステムを読むので、作業用のスレッドで行い、結果を VM のスレッドに返してから判定する。判定器は、許可したパスとコマンドを、ADR 0072 と ADR 0073 の照合の規則で解決した値と比べる。
- 判定するのは、[IO のモジュール](../03-interop/03-07-io-modules.md)と[ネットワークのモジュール](../03-interop/03-09-network.md)の「要する権限」の欄に権限を示した操作だけである。リソースを開く操作（`File.openReader` など）は開くときに一度だけ判定し、開いたリソースに対する操作は判定しない。リソースの解放は判定しない（[ADR 0150](../decisions/0150-resource-release-as-state.md)）。`Http.accept` が返す `Http.Exchange` に対する操作も、判定しない。
- 拒否したときの実行時エラーの報告には、許可の単位、操作、スクリプトが渡した対象、解決した絶対パス（`Process.Run` では見つけた実行ファイルの絶対パス）を含める（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)、[ADR 0073](../decisions/0073-run-permission-command-matching.md)）。報告の形式は[診断エンジン](02-10-diagnostics.md)で定める。

【決定】権限の判定器は、利用者が一つの形で書いた方針から作る（[ADR 0183](../decisions/0183-single-policy-for-all-permission-layers.md)）。サーバモードでは、デーモンが、サーバの方針、選んだプロファイル、実行のときに渡した方針のすべてが許す操作だけを許す実行ごとの方針を決め、子プロセスはその方針から判定器を作る（[ADR 0186](../decisions/0186-run-time-policy-can-only-narrow.md)、[サーバモード](../06-tooling/06-07-server.md)の「実行の手順」）。スタンドアロンモードでは、利用者単位の方針のファイルを起動のたびに読んで判定器を作る（[ADR 0187](../decisions/0187-standalone-reads-user-policy-file.md)）。許可の単位は、上の表の組み込みのエフェクトとシェルによる実行である（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。【決定】判定器は、方針の除外（`deny`）を許可より先に調べ、除外に当たる操作を拒否する（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。対象の並びを空にして許した単位では、どの対象の操作も拒否する（[ADR 0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md)）。【未決】ネットワークの操作の対象の書き方と照合、リダイレクトの判定、テストの実行器が作る判定器と与える許可は、[OPEN-052](../open-issues.md#open-052) で決める。判定器の入力は、この決定にあわせて見直す。OS のサンドボックスによる強制は [OS のサンドボックス](02-12-os-sandbox.md)で定める。

### IO 実行器

【決定】IO 実行器は、組み込みの操作を行い、その完了を待つタスクを管理するランタイムの部分である。ランタイムは、VM のスレッドで `mio` のイベントループを動かす。ソケットの待ち受けと読み書き、時間の経過の待ち（`Clock.sleep`、`Task.withTimeout`）はイベントループで待つ。ブロックする操作は作業用のスレッドで行う。引数は `Send` を満たす Rust の型に変えてから作業用のスレッドに渡し、結果は VM のスレッドで言語の値に変える。完了は channel と `mio::Waker` で知らせる（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）。

【決定】組み込みの操作の実行には、直接呼び出しと、要求と応答の二つの方式があり、処理系の内部の設定で切り替える。二つとも残し、既定を直接呼び出しとする（[ADR 0029](../decisions/0029-two-io-execution-modes.md)、[ADR 0088](../decisions/0088-keep-both-io-execution-modes.md)）。どちらの方式も、組み込みの操作の応答には、完了のほかに「待つ」がある（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）。応答の種類は[仮想機械](02-08-vm.md)の「組み込みの関数の呼び出し」で定める。

【決定】どちらの方式でも、組み込みの操作の要求は一つの送り出しの列に置く。二つの方式の違いは、列を処理する部品だけである（[ADR 0264](../decisions/0264-single-dispatch-queue-for-builtin-operations.md)）。

- 直接呼び出しの方式では、送り出しの部品が、列の要求をその場でハンドラ表の関数に渡し、関数が応答を返す。
- 要求と応答の方式では、要求を置いたタスクを待たせる位置で、進められるタスクが残っていても、VM は列の要求の並びを返して止まる。応答のない要求がある間は、予算を使い切るたびに空の並びを返して止まり、届いた応答を受け取る（[仮想機械](02-08-vm.md)の「タスクの切り替え」「IO の命令」）。IO 実行器は、要求ごとにハンドラ表の関数を呼び、応答が待つであれば、完了するまでそのタスクに応答を返さず、VM の実行はすぐ再開する。

【決定】列の扱いは次の規則に従う。

- タスクを待ちの状態にしてから、要求を列に公開する。すぐに完了する操作でも、この順序を守る。
- 要求には番号を付け、要求と、待つタスクの保存した枠との対応を、この番号で持つ。
- 要求を出したタスクを取り消したときと、止める手順を始めたときは、外部の操作に移る前の要求（列にある要求、要求と応答の方式で応答を待つ要求、貸すリソースの返却か出力の転送の完了を待つ要求）を失効させる。失効させた要求では、組み込みの関数を呼ばない。要求を処理する部品（要求と応答の方式では、外側の実行器が呼ぶ処理）は、要求が失効していないことと、要求を出したタスクが同じ世代のまま、その要求の応答を待っていることを確かめてから、ハンドラ表の関数を呼ぶ。失効した要求の処理を求められたら何もしない（[ADR 0282](../decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。
- どちらの方式でも、タスクを待たせる位置で列の要求を送り出し、完了した操作を取り込む。完了の取り込みは、予算を使い切った遅い経路でも行う（[仮想機械](02-08-vm.md)の「タスクの切り替え」）。IO 実行器は、外部の操作の終わりを待って VM を止めない。
- 【未決】すぐに完了する操作（出力のバッファへの書き込みなど）の近道は設けずに測る。列を通る費用が大きければ、近道を送り出しの部品の中の分岐として一か所に置き、同じ待ちの登録・ハンドラの呼び出し・完了の処理を使う。要求と応答の方式には近道を設けない。

どちらの方式でも、待つタスクはスケジューラの進められるタスクの待ち行列から待ちの表に移り、操作が完了したら結果を受け取って待ち行列に戻る。処理系のテストは、二つの方式で同じ結果になることを確かめる（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)）。方式を切り替える設定は、利用者向けの CLI のオプションにしない（[CLI](../06-tooling/06-01-cli.md)の「開発用の設定」）。

【方針】IO 実行器は、次のように待つ。

- VM は、タスクを切り替える位置（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）で、イベントループを待たずに調べ、完了した操作を待ちの表から進められるタスクに戻す。
- 進められるタスクがなく、待つタスクだけが残ったときは、VM のスレッドはイベントループで待つ。待つ時間の上限は、最も早く期限が来るタイマーまでとする。このとき外部の待ちの理由で待つタスクもタイマーもなければ、イベントループで待たずに、VM がタスクの待ち合いの行き詰まりの実行時エラーとする（[ADR 0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)、[仮想機械](02-08-vm.md)の「タスクの切り替え」）。どのタスクも待っていない外部の操作（配送先を外した操作の記録）と出力の転送が残っていても、行き詰まりとする（[ADR 0283](../decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）。
- 作業用のスレッドは、完了したら結果を channel に送り、`mio::Waker` でイベントループを起こす。作業用のスレッドは、仕事を出すときに空いたスレッドがなければ新しく作り、数の上限を 64 とする。上限に達したときは、仕事は空くまで列で待つ。空いたスレッドは実行の終わりまで残す。標準入力の読み取りや外部コマンドの待ちでスレッドが長く埋まっても、ほかの仕事を始められるようにするためであり、上限は OS の資源を使い尽くさないためである（値は実装プランで定めたもの）。作業用のスレッドは言語の値に触れない。値の型は `Send` でないので、言語の値を作業用のスレッドに渡す書き方はコンパイルの誤りになる。作業用のスレッドに渡す仕事と結果は `Send + 'static` の型にする（[ADR 0261](../decisions/0261-typed-builtin-interface.md)）。

【方針】作業用のスレッドが返す結果を言語の値に変えるときに、後述の「一つの操作で作る値の大きさの上限」を確かめる。作業用のスレッドは、読む大きさが決まっていない入力（ファイル全体、標準入力の残り、コマンドの出力、HTTP の応答の本体）を上限より 1 バイト多い分まで読み、上限を超えたことを結果として返す。

【決定】作業用のスレッドの中の処理は `catch_unwind` で囲む。貸したリソースは `catch_unwind` で囲む処理の外で持ち、panic が起きても完了の返すリソースの欄を作れるようにする（[ADR 0266](../decisions/0266-task-and-resource-state-machines.md)）。作業用のスレッドで Rust の panic が起きたときは、その panic の記録（後述の「panic 境界」）を結果として VM のスレッドに渡し、VM のスレッドで処理系の不具合として扱う（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）。

### タスクの待ちと取り消し

タスクの切り替えの仕組み（タスクごとの呼び出しの積み重ね、切り替える位置、呼び出しの回数の予算、`Lazy` の評価の待ち）は[仮想機械](02-08-vm.md)と [ADR 0161](../decisions/0161-single-threaded-task-scheduler.md) で定める。本節は、ランタイムが受け持つ部分を定める。

【方針】`Clock.sleep(ms)` は、イベントループに期限が今から `ms` ミリ秒後のタイマーを登録し、そのタスクを待ちの表に移す。`Task.withTimeout(ms, action)` は、`action` のタスクを起動し、同じくタイマーを登録する。タイマーの期限が来る前に `action` が終われば、タイマーを外して結果を返し、期限が来たら `action` のタスクを取り消す。`ms` が 0 以下のときの扱いは[並行処理](../01-spec/01-11-concurrency.md)に従う。

【方針】`Task.race` は、最初に終わったタスクの結果を返し、ほかのタスクを取り消す。`Task.allOk` は、`actions` の中の位置を覚え、`Result.Error` を返したタスクより後ろのタスクだけを取り消し、前のタスクの終わりを待つ（[ADR 0152](../decisions/0152-task-allok-list-order.md)）。起動したタスクは、起動したタスクのハンドラの連鎖を引き継ぐ（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。

【方針】タスクを取り消すときは、[並行処理](../01-spec/01-11-concurrency.md)の「取り消し」に従い、次のようにする。

- そのタスクが待ちの表にあれば、表から外す。登録していたタイマーと、イベントループの待ち受けの登録を外す。貸しているリソースの返却を待つ並びからも外す。ただし、解放の枠が解放の完了を待つ待ちは外さない（[仮想機械](02-08-vm.md)の「取り消し」）。
- 外部の操作に移る前の要求は失効させ、組み込みの関数を呼ばない（前述の「IO 実行器」、[ADR 0282](../decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。
- 作業用のスレッドで続いている操作は止めない。起動した外部コマンドを終わらせることもしない。外部の操作の記録は、タスクへの結果の配送を取り消した印を付けて残す。取り消しがその操作の起きなかったことを保証しないのは、仕様のとおりである。配送を取り消した操作は、どのタスクも待っていなければ、行き詰まりの判定で外部の待ちに数えない（[ADR 0283](../decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)）。
- 後述の「リソースの追跡」に従い、そのタスクの `with` のリソースを解放する。

【決定】作業用のスレッドとイベントループからの完了は、「タスクへの結果」と「返すリソース」の二つの欄を持つ。タスクへの結果は、値、失敗（`IOError` などにする元）、処理系の不具合（作業用のスレッドの panic の記録）のどれかである。完了を受け取る共通の処理は、次の順に行う。返却を個々の組み込みの関数に任せない（[ADR 0266](../decisions/0266-task-and-resource-state-machines.md)）。

1. 返すリソースをリソースの表に戻す。
2. 結果が処理系の不具合であれば、タスクがその結果を待っているかによらず、後述の「panic 境界」の処理（処理系の不具合の報告）に移る。
3. そうでなければ、タスクがまだその操作の結果を待っているかを調べ、待っていれば結果を渡して起こし、待っていなければ結果を捨てる。

### リソースの追跡

【方針】リソースの型の値（`File.Reader`・`File.Writer`・`Http.Listener`・`Http.Exchange`・`TaskGroup`）は、実行ごとの状態のリソースの表の番号として表す。番号は一つの実行の中で使い回さない。リソースの表の項目は、次のものを持つ。

| 項目 | 内容 |
|---|---|
| 種類 | リソースの型 |
| 中身 | OS の資源（ファイル、ソケットなど）、`TaskGroup` では起動したタスクの並び（所有しない世代付きのタスクの番号。[仮想機械](02-08-vm.md)の「実行ごとの状態のうち VM が使うもの」） |
| 状態 | `Open`（開いている）、`Lent(操作の番号, 閉じる要求)`（作業用のスレッドに貸している）、`Releasing(操作の番号)`（解放を行っている）、`Released`（解放した）（[ADR 0266](../decisions/0266-task-and-resource-state-machines.md)） |
| 開いた位置 | リソースを開いた呼び出しのソース上の位置。解放の失敗の報告に使う |

- リソースに対する操作は、まず状態を調べ、解放したリソースであれば、操作を行わずに実行時エラー（解放したリソースの使用）とする（[リソース管理](../01-spec/01-10-resources.md)の「解放したリソースの使用」）。番号を使い回さないので、解放したリソースの使用を取りこぼさない。
- 作業用のスレッドで行う操作は、OS の資源を操作の間だけ作業用のスレッドに貸し、完了とともに返させる。貸している間に別のタスクが同じリソースを操作するときは、返されるまで待たせ、呼んだ順に行う。

【決定】タスクの状態（[仮想機械](02-08-vm.md)の「取り消し」）とリソースの状態の組み合わせは、次のように扱い、組み合わせごとにテストを置く（[ADR 0266](../decisions/0266-task-and-resource-state-machines.md)）。

| タスク × リソース | 扱い |
|---|---|
| `Waiting(操作)` × `Lent(操作, 閉じる要求なし)` | 完了でリソースを表に戻してから、タスクに結果を渡す |
| `Unwinding` × `Lent(操作, 閉じる要求あり)` | 返るまで待ち、返った後に解放する。新しい貸し出しは受け付けない |
| `Waiting`・`Unwinding` × `Releasing` | 解放の完了で元の処理を再開する。取り消したタスクを通常の実行に戻さない |
| 操作の待ち × `Released` | 待ちを解き、解放したリソースの使用として処理する |
| `Done` × `Lent` | 借りたタスクと解放の責任を持つタスクが別のときに起きうる。操作の記録は残す。自分の解放が終わっていないタスクは `Done` にしない |

【方針】`with` で束縛したリソースは、VM がタスクの枠の積み重ねの解放の枠として持つ（[仮想機械](02-08-vm.md)の「枠の種類」「リソースの解放の枠」）。`with` を抜けるときは逆の順に解放する。束縛の文（`bind`・`shadow`）で束縛したリソースは解放の枠を積まない。ハンドラの継続の区画は、その区画の中で積んだ解放の枠を含む。解放の枠を辿り、次のときに解放する（[リソース管理](../01-spec/01-10-resources.md)の「解放の時期と順序」）。

| 時期 | 解放するもの |
|---|---|
| `with` を抜けるとき（`return`・`try` で抜けるときを含む） | その `with` の解放の枠のリソース |
| ハンドラの節が `resume` を呼ばずに終わり、本体の続きを捨てるとき | 捨てる継続の区画の中の解放の枠のリソースを、内側から |
| タスクを取り消すとき | そのタスクのすべての解放の枠のリソースを、内側から |
| 止める手順（[仮想機械](02-08-vm.md)の「止める手順」） | すべてのタスクのすべての解放の枠のリソースを、タスクごとに内側から。タスクの間の順序は定めない |

【方針】リソースの型ごとの解放の処理は次のとおりである。どれも権限を判定しない。

- `File.Reader` は、ファイルを閉じる。`File.Writer` は、書いた内容を書き出してから閉じる。
- `Http.Listener` は、イベントループの登録を外し、待ち受けを閉じる。
- `Http.Exchange` は、応答を送っていなければ状態コード 500 の応答を送ってから、接続を閉じる。失敗しても、実行時エラーにも報告にもせず、捨てる（[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）。
- `TaskGroup` は、`with` を抜けるときは起動したすべてのタスクの終わりを待つ。取り消しの途中では、そのタスクを取り消し、止まるのを待つ。止める手順の途中では、子のタスクの終わりを待たない。子のタスクも同じ止める手順で止まる（[ADR 0164](../decisions/0164-taskgroup-release-while-stopping.md)）。

解放でブロックする処理（`File.Writer` の書き出しなど）は、作業用のスレッドで行い、解放するタスクを待たせる。止める手順の途中でも同じであり、待つ間はほかのタスクの手順を進める（[仮想機械](02-08-vm.md)の「止める手順」）。解放を行っているリソースと、返却を待ってから解放するリソースの解放の枠は、解放の完了まで降ろさない。解放の完了で元の処理を再開するためである（[ADR 0266](../decisions/0266-task-and-resource-state-machines.md) の決定 5）。

【方針】解放の失敗は、次のようにまとめる。

- `with` を抜けるとき、取り消しの途中、ハンドラが本体の続きを捨てるときは、一つが失敗しても残りのリソースの解放を続け、失敗をすべて集めてから、実行時エラー（リソースの解放の失敗）とする（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」）。
- 実行時エラーか資源の不足で止める途中の失敗は、先の実行時エラーを置き換えず、その報告に加える（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。テストの確認の失敗で止める途中の失敗も、同じくそのテストの失敗の報告に加える。
- `Process.exit` と中断の要求で止める途中の失敗は、標準エラー出力に報告し、終了状態は変えない（[エフェクト](../01-spec/01-07-effects.md)の「影響の大きい操作（初回リリース版）」、[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。
- 報告には、リソースの型、開いた位置、失敗の理由を含める。形式は[診断エンジン](02-10-diagnostics.md)で定める。

【方針】束縛の文で束縛して解放しなかったリソースは、止める手順でも解放しない（[リソース管理](../01-spec/01-10-resources.md)）。実行を終えて実行ごとの状態を捨てるときに、ランタイムはリソースの表に残った OS の資源を閉じる。これは言語の解放ではなく、`File.Writer` の書き出していない内容は書き出さず、失敗も報告しない。テストの実行器で繰り返し実行するときに、OS の資源が実行をまたいで残らないようにするためである。

【決定】すべてのタスクが終わっても、外部の操作が残ることがある（取り消したタスクの標準入力の読み取り、束縛の文のリソースを貸したまま取り消した操作など）。`with` で束縛したリソースは、解放の枠が返却を待ってから解放するので、残る操作が持つのは、束縛の文のリソースと、リソースを持たない操作に限られる。実行を終えるときは、残った外部の操作の完了を待たない。待つと、終わらない読み取りなどで実行が終われなくなるからである。実行ごとの状態を捨てるときに、外部の操作の記録も捨てる。作業用のスレッドが後で完了したときは、受け取る側がないので、返すリソースは作業用のスレッドの側で破棄され、OS の資源が閉じる。これも言語の解放ではなく、失敗は報告しない。

【方針】呼び出しの情報は VM が実行ごとの状態の中にデータとして持ち（[ADR 0016](../decisions/0016-calls-off-go-stack.md)）、その大きさの上限は、すべてのタスクと保存した継続の枠を合わせて数える（[ADR 0030](../decisions/0030-call-stack-size-limit.md)、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)、[仮想機械](02-08-vm.md)）。

【決定】初回リリース版の処理系は、ヒープの使用量に上限を設けない。メモリの使用量の上限は、処理系を起動する側（ハーネス、`ulimit`、コンテナなど）に委ねる（[ADR 0237](../decisions/0237-no-heap-usage-limit-in-first-release.md)）。一度に巨大な値を作る誤りは、後述の「一つの操作で作る値の大きさの上限」で止まる。ヒープが足りなくなったときは、[評価意味論](../01-spec/01-08-evaluation.md)の資源の不足の手順によらずに終わる（[ADR 0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md)）。終わり方は、メモリの不足がどこで起きるかによって次のように分かれる。

- 処理系のヒープの確保が失敗したとき: Rust の標準ライブラリの既定の振る舞いで、標準エラー出力にメッセージを書いてプロセスを abort する（[handle_alloc_error](https://doc.rust-lang.org/std/alloc/fn.handle_alloc_error.html)）。abort は巻き戻しを伴わないので、後述の panic 境界は働かない。終了状態は OS が決め、処理系は定めない（[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。
- 確保が失敗する前に、OS の側でメモリが足りなくなったとき（Linux の overcommit の設定による場合など）: プロセスがどう終わるかは確かめておらず、処理系は終わり方を定めない。

どちらの場合も、出力のバッファに残った内容は書き出されず、リソースは解放されないことがある。サーバモードでは実行ごとに子プロセスが分かれるので、一つの実行がメモリを使い尽くしてもほかの実行に及ばない。子プロセスに OS の仕組み（Linux の cgroup、`setrlimit` など）でメモリの上限を掛けるかは、サーバモードの設計で決める（[OPEN-055](../open-issues.md#open-055)、[ADR 0237](../decisions/0237-no-heap-usage-limit-in-first-release.md)）。

### 一つの操作で作る値の大きさの上限

【決定】一つの組み込みの関数の呼び出しで作る文字列の大きさ（バイト数）とリストの長さに、処理系が上限を設ける。組み込みの関数は、値を作る前に結果の大きさを計算し、上限を超えるときは値を作らずに、資源の不足として[評価意味論](../01-spec/01-08-evaluation.md)の手順で停止する（[ADR 0049](../decisions/0049-size-limit-for-built-values.md)）。

【方針】上限の値は次のとおりとする。利用者が変える手段を設けない。`Bytes` にも文字列と同じ上限を当てる。

| 値 | 上限 |
|---|---|
| 文字列、`Bytes` | 2^30 バイト（1,073,741,824 バイト、1 GiB） |
| リスト | 2^24 要素（16,777,216 要素） |

【方針】上限を確かめる対象は、結果として `String`・`Bytes`・`List` の値を新しく作る組み込みの関数（組み込みの操作を含む）と、`CONCAT` の命令のすべてである。上限を超えたときは、資源の不足の種類「作る値が大きすぎる」を返す（[仮想機械](02-08-vm.md)の「組み込みの関数の呼び出し」）。報告には、値を作ろうとした関数、計算した結果の大きさ、上限を含める。

- 結果の大きさは、値を作り始める前に、引数から計算する。計算は Rust の `i64` の溢れを検査する演算（`checked_mul` など）で行う（`String.repeat(s, n)` では、`n` が「上限 ÷ `s` のバイト数」を超えるかで判定する、など）。`String.replace` のように、引数から大きさを求めるのに走査が要る関数は、先に出現を数えてから大きさを計算する。
- 読む大きさが決まっていない入力を読む操作（`File.readText`・`File.readBytes`・`File.readLines`、`Console.readAll`・`Console.readAllLines`・`Console.readAllBytes`、`Process.run`・`Process.shell` の標準出力と標準エラー出力、`Http.get`・`Http.send` の応答の本体）は、上限より 1 バイト多い分まで読み、上限を超えたら資源の不足とする。行やディレクトリの項目を並べる操作（`File.readLines`・`Console.readAllLines`・`File.listDirectory`・`File.walk`）は、リストの長さも確かめる。
- `File.readChunk(reader, maximumBytes)` は、`maximumBytes` が上限を超えるときは、上限までを読む。
- HTTP のサーバが受け付ける要求の本体には、これより小さい別の上限を設け、超えた要求には処理系が状態コード 413 の応答を返す（[ネットワークのモジュール](../03-interop/03-09-network.md)）。値は実装プランで定める。
- `List.prepend` と `List.append` も、結果の長さ（元の長さに 1 を加えた値）を確かめる。
- 結果の大きさが引数の大きさを超えない関数（`List.take`・`String.trim`・`Bytes.slice` など）は、引数が上限の中にあるので、確かめなくてよい。

どの操作も上限を確かめるので、上限を超える文字列・`Bytes`・リストの値は作られない。この上限は一つの操作で作る値だけを抑える。小さな値を何度も作ってヒープが足りなくなる場合は、前節に従って終わる。

### 出力のバッファ

【方針】標準出力と標準エラー出力への書き込み（`Console.write`・`Console.writeLine`・`Console.writeError`・`Console.writeErrorLine`）は、VM のスレッドで、それぞれのバッファに加える。一回の書き込みの呼び出しの文字列は一度にバッファに加えるので、ほかのタスクの出力に割り込まれない（[並行処理](../01-spec/01-11-concurrency.md)）。バッファの中身は、書き込みの呼び出しの順に出力に現れる。二つの出力の間の順序は保証しない（[エフェクト](../01-spec/01-07-effects.md)）。

【方針】バッファの書き出し先（出力先）は、実行を始めるときに実行ごとの状態に入れる。CLI の `run` とサーバモードの子プロセスでは処理系のプロセスの標準出力と標準エラー出力であり、テストの実行器の実行では、その実行の結果に含めるためにメモリに捕らえる出力先である（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)、[スクリプト実行と埋め込み](02-11-embedding.md)）。メモリに捕らえる出力先も、同じ転送と完了の手順を通す。

【決定】バッファの中身の出力先への転送は、標準出力と標準エラー出力ごとに一つ置く書き出し用のスレッドで行う（[ADR 0265](../decisions/0265-output-transfer-by-writer-threads.md)）。転送の時点は、転送を依頼するだけの時点と、それまでの出力の転送の完了を待つ時点に分ける。

| 種類 | 時点 | 動作 |
|---|---|---|
| 依頼するだけ | 書き込みの関数がバッファに追加した結果、そのバッファの中身が 64 KiB（65,536 バイト）以上になったとき | そのバッファの中身の転送を依頼し、VM は進める |
| 依頼するだけ | 進められるタスクがなくなり、イベントループで待つ前 | 両方のバッファの中身の転送を依頼する |
| 依頼するだけ | 出力先が端末であり、書き込みで改行を書いたとき | そのバッファの中身の転送を依頼する |
| 完了を待つ | 標準入力を読む前、`Process.runAttached` がコマンドを起動する前 | 標準出力、標準エラー出力の順に、その時点までの出力の転送の完了を待ってから、読み取りか起動を始める |
| 完了を待つ | 止める手順の終わりと、プログラムを終える前（後述の「プログラムの実行の流れ」の手順 4。panic 境界で処理系の不具合を報告する前も含む） | 標準出力、標準エラー出力の順に、最後の転送と失敗の確かめを終える |

完了を待つ間も、VM はイベントの処理と中断の印の確かめを続ける。完了を待つのは、その時点までに加えた出力に限り、ほかのタスクが後から加える出力は待たない。出力先が端末かどうかの判定の方法は、後述の値の表で定める。

【決定】転送していない量は、バッファ・書き出し用のスレッドの列・転送中の量の合計で数える。転送していない量を N、書き込む量を n、上限を B として、書き込みは次のように受け付ける。

- N + n ≤ B であれば、バッファに加える。
- n > B（一回の書き込みが上限より大きい）であれば、N = 0 のときに限り加える。
- それ以外は、バッファの中身の転送を依頼してから、書いたタスクを出力の待ちにする。容量が空いたら、待っている書き込みを呼んだ順に同じ規則で受け付ける。待っている書き込みがある間は、後から来た書き込みもその後ろで待ち、追い越さない。

受け付けた出力は、書いたタスクを取り消しても取り下げない。待っている間に取り消されたタスクの書き込みは、受け付けていないので加えない。上限 B の値は、次の表で定める。

【方針】出力のバッファの値は、実装プランで定めた次のものとする。

| 項目 | 値 | 理由 |
|---|---|---|
| 出力先が端末かどうかの判定 | 実行を始めるときに、出力先ごとに一度だけ Rust の標準ライブラリの `std::io::IsTerminal` で判定する。メモリに捕らえる出力先は端末でないものとする | 標準ライブラリで判定でき、依存のクレートを増やさない |
| 転送していない量の上限 B | 出力ごとに 1 MiB（1,048,576 バイト） | 転送を依頼する大きさ（64 KiB）の 16 倍とし、書き出しの遅い出力先でも VM がすぐには待たないようにする |

【決定】書き出しの失敗は、書き込みの関数を呼び出した時点ではなく、書き出したときに検出する。遅くとも、プログラムを終える前の書き出しで検出する（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。

【方針】書き出しに失敗したときは、次のように扱う。

- 書き出し用のスレッドが、失敗を出力ごとの書き込みの失敗の記録に残す。その出力の以後の書き込みは、バッファに溜めずに捨てる。失敗した出力を、もう一度書き出そうとはしない。失敗したら、その出力の容量と完了の待ちを解く。失敗の記録と知らせ方を、書いたタスクの寿命に依存させない。
- 書き出し用のスレッドの中の処理も `catch_unwind` で囲む。panic が起きたら、panic の記録を処理系の不具合としてその出力の記録に残し、容量と完了の待ちを解いて終わる。VM のスレッドは、失敗の記録を読むときにこれを見つけたら、後述の「panic 境界」の処理に移る。
- VM のスレッドは、書き込みの関数の中と、転送の依頼と完了の待ちのときに失敗の記録を読む。失敗が記録されていれば、そのハンドラ表の関数は書き込みの失敗の実行時エラーの種類を返す。この実行時エラーは、ソース上の位置と呼び出しの履歴を持たない（[仮想機械](02-08-vm.md)の「実行時エラーの情報の記録」）。失敗を検出するまでに行った評価と外部に作用する操作は取り消さない。
- 終える前の転送で失敗したときの報告は、後述の「プログラムの実行の流れ」で定める。

【方針】Unix 系の OS では、Rust の標準ライブラリが `main` の前に SIGPIPE を無視する設定にし、読み手の終わったパイプへの書き込みは `ErrorKind::BrokenPipe` の誤りになる（[on-broken-pipe](https://doc.rust-lang.org/beta/unstable-book/compiler-flags/on-broken-pipe.html)、2026-09-27 に確認）。処理系はこの既定の設定を変えない。パイプの読み手が先に終わった場合も、書き込みの失敗の実行時エラーとして扱える（[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。

【方針】処理系が標準エラー出力に書く報告（`main` の `Result.Error` の文字列、警告と検査の診断、実行時エラー・資源の不足・解放の失敗・処理系の不具合の報告）は、バッファを通さずに、出力の最後の転送の完了を待った後で標準エラー出力に直接書く。テストの実行器の実行では、標準エラー出力ではなく、その実行の結果に報告として含める。報告の書き込みがさらに失敗したときは、それを報告せず、終了状態だけを定めどおりにする。

### 中断の要求

【決定】CLI の `run` と `test` は、`SIGINT` と `SIGTERM`（Windows では Ctrl-C と Ctrl-Break）を受けたら、プロセス全体で一つの中断の印を立てる。印は、シグナルの登録を扱う既存のクレートと、原子的な真偽値で表す。中断の印は、大域の可変状態を持たない規則（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）の例外であり、印を書くのはシグナルの登録の仕組みだけ、読むのは VM の実行の区切りだけである（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。

【方針】実行ごとの状態は、中断の要求の読み口を持つ。CLI とサーバモードの子プロセスでは、読み口はプロセス全体の中断の印を読む。サーバモードの実行時間の上限と停止は、デーモンが子プロセスに `SIGTERM` を送って行う（[スクリプト実行と埋め込み](02-11-embedding.md)の「サーバモードの実行」）。後で加える Rust のライブラリとして処理系を呼び出す API では、呼び出す側が実行ごとの印を与えてよい。その印は実行ごとの状態の一部であり、大域の状態ではない。

【決定】VM は、タスクを切り替える位置と、外部に作用する操作を待つ位置で中断の印を調べる。印が立っていれば、[仮想機械](02-08-vm.md)の「止める手順」を中断の要求として始め、終了状態 130 で終える。解放の失敗は報告し、終了状態は変えない。解放の途中で二度目の中断の要求を受けたら、解放を待たずに OS の既定の振る舞いで終える（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。

【方針】イベントループで待っている間に中断の要求を受けたときも、待ちを終えて印を調べられるように、中断の要求はイベントループを起こす。一度目の要求を受けた後は、二度目の要求で OS の既定の振る舞いが起きるように登録を戻す。これらを実現する方法は、実装プランで定める。

【方針】シグナルの登録には、`signal-hook` 0.4.4 と、`mio` のイベントループからシグナルを待つための `signal-hook-mio` 0.3.0 を使う（どちらもライセンスは `MIT OR Apache-2.0` で、[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md) の許可の一覧に含まれる。版とライセンスは 2026-09-30 に `cargo info` で確認した）。初回リリース版の対応環境は macOS と Linux だけである（[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md)）ので、二つのクレートは Unix 系の OS のシグナルの登録にだけ使えればよく、Windows での振る舞いは確かめていない。上の Windows の Ctrl-C と Ctrl-Break の扱いは、Windows に対応するときに、使うクレートとあわせて改めて定める。

### 止める手順でランタイムが行うこと

【方針】実行時エラー、資源の不足、`Process.exit` の操作、中断の要求、テストの確認の失敗（[スクリプト実行と埋め込み](02-11-embedding.md)の「テストの実行」）で実行を止める手順は、[仮想機械](02-08-vm.md)の「止める手順」で定める。ランタイムは、その手順のうち次のことを行う（[評価意味論](../01-spec/01-08-evaluation.md)の「実行時エラーによる停止」、[並行処理](../01-spec/01-11-concurrency.md)の「失敗と停止」、[エフェクト](../01-spec/01-07-effects.md)の「影響の大きい操作（初回リリース版）」）。

1. 止める理由を終わり方の記録に残す。
2. 待ちの表から、止める前から待っていた操作を外し、タイマーと待ち受けの登録を外す。外部の操作に移る前の要求は失効させ、組み込みの関数を呼ばない（前述の「IO 実行器」、[ADR 0282](../decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。作業用のスレッドで続いている操作は、取り消しと同じく、外部の操作の記録を残し、完了したら返すリソースを表に戻してから結果を捨てる。
3. VM が解放の枠を辿ってリソースを解放するときに、リソースの型ごとの解放の処理（前述の「リソースの追跡」）を行う。
4. VM が止まり方を返したら、出力の最後の転送の完了を待ち、後述の「プログラムの実行の流れ」の手順 5 に進む。

止める手順の途中では言語の関数を呼ばないので、別の実行時エラーや `Process.exit` は起きない。解放の失敗は、止める理由を置き換えない。

### panic 境界

【決定】処理系は、panic が巻き戻しを行う設定でビルドし、IO 実行器は VM の実行全体を `catch_unwind` で囲む（[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。イベントループと HTTP のサーバの層は VM のスレッドで動くので、この境界の中にある。`catch_unwind` が捕らえるのは巻き戻しによる panic だけであり、abort で終わる場合（ヒープの確保の失敗など）は捕らえない（[catch_unwind](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html)）。

【方針】組み込みの関数、ハンドラ表の関数、作業用のスレッド、書き出し用のスレッドの中で Rust の panic が起きたとき（処理系の不具合）は、実行時エラーとしては扱わず、処理系の不具合として報告する。報告の前に出力の転送の完了を待つが、リソースの解放は行わない。処理系の不具合の報告を標準エラー出力に直接書いて、終了状態 3 で終わる（[ADR 0037](../decisions/0037-exit-status-values.md)）。報告の形式は[診断エンジン](02-10-diagnostics.md)で定める。

組み込みの関数とハンドラ表の関数は、言語の規則で定めた失敗（除算の 0、IO の失敗など）を panic で表さず、実行時エラーの種類か `Result.Error` の値として返す。

【方針】Rust の panic hook は、panic を `catch_unwind` が捕らえる前に呼ばれ、既定の hook は標準エラー出力にメッセージを書く（[set_hook](https://doc.rust-lang.org/std/panic/fn.set_hook.html)）。既定の hook のままでは、出力のバッファより先に、診断の形式によらないメッセージが出る。そこで、処理系を使うプログラム（CLI、サーバモードのデーモンと子プロセスなど）は、起動の直後、スレッドを作る前に一度だけ、処理系の hook を設定する。処理系の hook は標準エラー出力に何も書かず、panic の内容、panic の起きたソース上の位置、バックトレースを、panic したスレッドのスレッドローカルな記憶域に記録する。panic 境界は、捕らえた後にこの記録を取り出して報告に使う。作業用のスレッドの境界は、取り出した記録を VM のスレッドに渡す。hook はプロセス全体で一つなので、実行ごとに設定し直さない。

【方針】CLI は、検査の各段（読み込みからコード生成まで）の処理も `catch_unwind` で囲み、そこで捕らえた panic も、同じく処理系の不具合として報告する（[診断エンジン](02-10-diagnostics.md)の「処理系の不具合と処理系の制限の報告」）。hook の出力が出ないことと報告の順序は、処理系の API を呼ぶテストでは確かめられないので、CLI を別のプロセスとして起動するテストで、標準エラー出力の内容を確かめる（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)）。

### プログラムの実行の流れ

【方針】`run` は、コンパイル済みプログラムを受け取った後、次の順に処理する（[エフェクト](../01-spec/01-07-effects.md)の「プログラムの入口」）。

1. コマンドライン引数を検査する。正しい UTF-8 でない引数があれば、その引数の位置を示す診断を出し、`main` を呼ばずに終了状態 1 で終わる（[ADR 0012](../decisions/0012-invalid-utf8-input.md)、[ADR 0037](../decisions/0037-exit-status-values.md)）。
2. 実行ごとの状態を作る。本番のハンドラ表、実行の入力、出力先、権限の判定器（サーバモード）、中断の要求の読み口を入れ、時計の起点を記録し、隠れた乱数の生成器の種を決める。
3. IO 実行器で、`main` の呼び出しを最初のタスクとして実行する。すべてのタスクが終わるか、止める手順を終えるまで続ける。
4. 出力のバッファの最後の転送を、標準出力、標準エラー出力の順に行い、完了を待つ（「出力のバッファ」）。止める手順を終えた場合は、前述の「止める手順でランタイムが行うこと」の手順 4 の転送がこれに当たる。
5. 終わり方に応じて、次の報告を標準エラー出力に直接書き、次の終了状態で終わる。

| 終わり方 | 報告 | 終了状態 |
|---|---|---|
| `main` が `()` または `Result.Ok(())` を返した | なし | 0 |
| `main` が `Result.Error(msg)` を返した | `msg` と改行（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)） | 1 |
| 実行時エラーで止まった | 実行時エラーの報告。止める途中の解放の失敗を注記として加える（[評価意味論](../01-spec/01-08-evaluation.md)） | 1 |
| 資源の不足で止まった | 資源の不足の報告。止める途中の解放の失敗を注記として加える | 1 |
| `Process.exit(code)` で止まった | 止める途中の解放の失敗があれば、その報告 | `code` |
| 中断の要求で止まった | 止める途中の解放の失敗があれば、その報告 | 130 |
| 処理系の不具合（panic 境界で捕捉した Rust の panic） | 処理系の不具合の報告（「panic 境界」） | 3 |

構造化された並行処理（[並行処理](../01-spec/01-11-concurrency.md)の「タスク」）により、`main` の呼び出しが終わった時点で終わっていないタスクはない。

手順 4 の転送に失敗したときは、次のようにする。

- 終わり方が `main` の `()` か `Result.Ok(())` であれば、書き込みの失敗の実行時エラーの報告を書き、終了状態 1 で終わる。
- 終わり方が `main` の `Result.Error(msg)` であれば、`msg` と改行を書いた後に、書き込みの失敗の実行時エラーの報告を書き、終了状態 1 で終わる。
- 終わり方が実行時エラーか資源の不足であれば、先の報告に、書き出しの失敗を注記として加え、終了状態 1 で終わる。
- 終わり方が `Process.exit` か中断の要求であれば、書き出しの失敗を報告し、終了状態は上の表のとおりとする。解放の失敗と同じく、止める理由を変えない。
- 終わり方が処理系の不具合であれば、その報告だけを書き、終了状態 3 で終わる。

標準エラー出力に書く報告の形式は[診断エンジン](02-10-diagnostics.md)で定める。終了状態の値は [CLI](../06-tooling/06-01-cli.md) の「終了状態」と同じであり、[ADR 0037](../decisions/0037-exit-status-values.md) と [ADR 0163](../decisions/0163-interrupt-releases-resources.md) に従う。テストの実行器の実行では、手順 5 で終了状態でプロセスを終えずに、終わり方と終了状態を実行の結果として返す（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)、[スクリプト実行と埋め込み](02-11-embedding.md)）。

## 未決事項

- [OPEN-036](../open-issues.md#open-036): メモリの管理の方式（マーク・スイープか改良した参照カウントか。第 1 段の測定で暫定に選び、ハンドラ・タスク・IO を加えた後に確定する。[ADR 0259](../decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)）
- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（権限の判定器の作り方、許可の単位、ネットワークの操作の権限）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R02・R04・R05・R13・R14。扱いは [ADR 0270](../decisions/0270-open-062-items-in-runtime-rebuild.md)）
