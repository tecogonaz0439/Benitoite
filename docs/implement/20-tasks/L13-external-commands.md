# L13 外部コマンドの起動

- 依存する作業: [L10](L10-console-clock-process.md)、[R40](R40-event-loop-and-worker-threads.md)、[R27](R27-output-writers.md)、[R28](R28-interrupt-and-stop-procedure.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L13-external-commands

## 目的

外部コマンドを起動する三つの操作の本体を書く。10-15 の部分 34（`process::RUN_DECLS`）である。シェルを通さない起動（`Process.run`・`Process.runAttached`）と、文字列をシェルに解釈させる実行（`Process.shell`）を分ける（03-07「外部コマンドの起動とシェル」）。あわせて、`Process.runAttached` の標準入出力のつなぎ先を、実行の環境から決める（10-16「外部コマンドの標準入出力」）。

| 項目 | 権限 | エフェクト |
|---|---|---|
| `Process.run`・`Process.runAttached`・`Process.shell` | `Io` | `Process.Run` |

依存の理由: `Process.Command` を作る `Process.command` のテストと、環境変数・作業ディレクトリの扱い（L10）を使う。`runAttached` は出力の転送の完了を待ってから起動する（R27）。子を待つ仕事は作業用のスレッドで長く続くので、IO 実行器（R26）と作業用のスレッドの実際の実装（R40）の上で、中断の要求で止める手順（R28）とあわせて確かめる。

## 読む設計書の節

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「Process」（`run`・`runAttached`・`shell` の行、`Process.Command`・`Process.Output`、既定の値、基準のディレクトリ、`environment` の加え方、`NotFound`、終了状態、UTF-8、シグナルで終わったときの終了状態、`/bin/sh -c`、`runAttached` の標準入出力）、「外部コマンドの起動とシェル」、「IOErrorKind と関数の対応」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」（`runAttached` の出力の転送の完了の待ち、つなぎ先）、「タスクの待ちと取り消し」（作業用のスレッドで続く操作を止めず、起動した外部コマンドを終わらせないこと）、「出力のバッファ」の完了を待つ時点、「一つの操作で作る値の大きさの上限」
- [エフェクト](../../design/01-spec/01-07-effects.md)の「影響の大きい操作（初回リリース版）」
- ADR: [0243](../../design/decisions/0243-signal-exit-code-and-posix-shell.md)、[0165](../../design/decisions/0165-exit-and-stdio-in-embedded-runs.md)、[0184](../../design/decisions/0184-permissions-granted-per-builtin-effect.md)、[0322](../../design/decisions/0322-stdlib-details-from-u3-preflight.md)（決定 5 と帰結の実時間の待ちの例外）、[0327](../../design/decisions/0327-fmt-symlink-and-process-attached-details.md)（決定 2〜4）

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表、`IO/Process.bnt` に加えた宣言（`Run`・`Command`・`Output`・`command`）、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「外部コマンドの標準入出力」（`ProcessStdio`・`IoRuntime::process_stdio`）、「ランタイムの内部への口」、「作業用のスレッドで行う操作」
- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「実行の流れ」（`RunEnv` の `stdin`・`stdout`・`stderr`）
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `WorkerWait::after_output_flush`

## 作るもの

- `src/builtins/funcs/process.rs` の `RUN_DECLS` の 3 項目の本体と単体テスト
- `runtime::run`（R26 が第 2 段の IO 実行器に移したもの）で `IoRuntime::process_stdio` を決める数行
- 統合テスト（`tests/` の下）

## 手順の要点

- `Process.Command` の値は、レコードの欄（`program`・`arguments`・`workingDirectory`・`environment`・`input`）を宣言の順で読む（10-15「レコードの値の作り方」）。仕事の閉包には、Rust の `String`・`Vec<String>`・`PathBuf`・`Vec<(String, String)>` に変えたものだけを渡す。
- 起動: `std::process::Command` でシェルを通さずに起動する。引数の単語分割とワイルドカードの展開は行わない。`workingDirectory` が `None` なら基準のディレクトリ、相対パスなら基準のディレクトリから解決する（02-09「組み込みの操作とハンドラ表」の箇条）。処理系のプロセスの作業ディレクトリは変えない（02-09「実行ごとの状態」）。`environment` の組は、スクリプトの環境変数に加えるか置き換える。`environment`（`Map[String, String]`）は、`runtime::map::map_to_vec` で鍵と値の組の列にしてから Rust の文字列に変える。
- `program` の解決: `/` を含む相対パスのときは、上で解決した子の作業ディレクトリに繋いで絶対パスにしてから `std::process::Command::new` に渡す。`/` を含まない名前は、そのまま渡して `PATH` から探させる（03-07「Process」、ADR 0327 の決定 4）。Rust の標準ライブラリの文書は、相対の program を `current_dir` と組み合わせたときの振る舞いをプラットフォーム依存としているので、この解決を省かない。`shell` の `/bin/sh` は絶対パスなので解決しない。
- `input`: `Some(s)` なら子の標準入力に `s` を書いて閉じ、`None` なら空の入力（`Stdio::null`）にする。書く側は別のスレッドにし、子の出力を集めるのと並べて行う（両方をパイプにしたまま片方だけを待つと、パイプが詰まって止まる）。子が入力を読み切らずに終わって書き込みが `BrokenPipe` になっても誤りにせず、書けた分で入力を終えたものとする（03-07「Process」、[ADR 0333](../../design/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 4）。
- `run`・`shell` の出力: 標準出力と標準エラー出力をそれぞれ上限（2^30 バイト）より 1 バイト多い分まで集め、上限を超えたら資源の不足（`InputTooLarge`）。UTF-8 でなければ `InvalidUTF8`。上限を超えた後も子の出力を読み捨てて、子が詰まらずに終わるようにする。
- 終了状態: `ExitStatus::code()` があればその値。シグナルで終わったとき（`code()` が `None`）は、`ExitStatusExt::signal()` の番号に 128 を足す（ADR 0243）。0 以外の終了状態でも `Result.Ok`。
- 起動するコマンドが見つからなければ `NotFound`（03-07）。`program`・引数・環境変数の名前と値のどれかに NUL を含めば `InvalidInput`。環境変数の名前が空か `=` を含むときも `InvalidInput` とする。03-07 はこの場合を定めていないので、この扱いを完了の報告に書く。
- `shell(commandLine)`: `/bin/sh -c commandLine` を `run` と同じく実行する（ADR 0243）。作業ディレクトリは基準のディレクトリ、環境変数はスクリプトのもの、標準入力は空の入力とする（`Process.Command` の既定の値と同じ）。
- `runAttached`: `WorkerWait::after_output_flush` を付け、出力の転送の完了を待ってから起動する。つなぎ先は `IoServices::runtime_view` で読む `IoRuntime::process_stdio` で決める（10-16）。継がせるときは `Stdio::inherit`、継がせないときは、標準入力を空の入力にし、標準出力と標準エラー出力を集めて、完了の処理で `IoServices::write_output` により標準出力、標準エラー出力の順に書く。結果は終了状態。
- 継がせない `runAttached` が集める出力: `run`・`shell` と同じく、標準出力と標準エラー出力をそれぞれ上限（2^30 バイト）より 1 バイト多い分まで集め、どちらかが上限を超えたら資源の不足（`InputTooLarge`）とする。集めた出力が正しい UTF-8 でなければ、`String::from_utf8_lossy` で壊れたバイトの並びを U+FFFD に置き換えて書き、`InvalidUTF8` は返さない（03-07「Process」、10-16「外部コマンドの標準入出力」、ADR 0327 の決定 2・3）。
- 完了の処理で `write_output` が容量の待ち（`Some(IoWait)`）を返したときは、待たずに進む。書き込みは預けられ、後の書き込みに追い越されないので、出力の順は崩れない（10-16「外部コマンドの標準入出力」、ADR 0265 の決定 4）。
- `runAttached` に `input` を指定した（`Option.Some(s)` の）`Command` を渡したときは、つなぎ先によらず、子の標準入力をパイプにして `s` を書いて閉じる（03-07「Process」の `runAttached` の標準入出力、ADR 0322 の決定 5。継がせる指定と空の入力の指定より優先する）。書く側は `run` の `input` と同じく別のスレッドにする。標準出力と標準エラー出力は、`input` の指定にかかわらず上のつなぎ先の規則に従う。この規則と ADR 0322 を `///` のコメントに書く。
- `runtime::run` で `process_stdio` を決める（10-16 の箇条: `StdinSource::Process`・`OutputTarget::Stdout`・`OutputTarget::Stderr` のときだけ継がせる）。`src/runtime/run.rs` の `match env.stdin`（標準入力の読み手を作る箇所）は `env.stdin` を消費するので、`process_stdio` はその `match` より前に決める。
- テスト用の `IoServices` の実装（`src/builtins/funcs/stage1_io.rs` の `TestIo` など）に与えた環境変数は、`Process.environmentVariable` が読む値であり、起動した子に渡る実際の環境（処理系のプロセスの環境に `environment` の組を加えたもの）とは別である。子の環境を確かめるテストは、`environment` で加えた変数を子に出力させて確かめる。
- 長い `run` は、子が終わるまで作業用のスレッドを一本占める。作業用のスレッドは最大 64 本（`src/runtime/sched/parts.rs` の `MAX_WORKERS`）なので、終わらない子を多く起動すると、ほかの仕事が待たされうる。この性質を `///` のコメントに書く。
- 取り消しと中断の要求: 作業用のスレッドで続く子の待ちを止めず、起動した外部コマンドを処理系から終わらせない（02-09「タスクの待ちと取り消し」）。中断の要求で止めるときも、処理系は子に何も送らない。README の骨子にあった「中断の要求と取り消しで子プロセスを止めること」は、この 02-09 の定めと食い違うので採らない（README の「U3 の作業の文書で見つかった点」）。取り消した後に子が終わった仕事の結果は、R26 の共通の処理が捨てる。

## 受け入れテスト

- `runAttached` の単体テストは、`IoServices::runtime_view` が `None` を返すテスト用の部品では `Stop::Internal` になるので、`IoView`（`IoRuntime` と `ResourceTable`）を作って呼ぶ形か、プログラムでの確かめ（下の項目）に寄せる。どちらでもよい。
- 継がせる指定（`Stdio::inherit`）で起動した子は、テストのプロセスの標準出力・標準エラー出力のパイプを持ち続ける。継がせる指定の子を起動するテストは CLI の別のプロセスのテストに限り、すぐに終わるコマンドを使う（テストの出力の読み手が、子の終わりまで待たされないようにする）。
- 前提にしてよいコマンド: 単体テストは、`PATH` の `sh`（`sh -c 'printf ...'` の形）・`cat`・`sleep` を起動できることを前提にしてよい（macOS と Linux の両方にある）。統合テスト（`tests/`）では `CARGO_BIN_EXE_benitoite` も使える。
- 項目ごとの単体テスト（仕事を `run` して完了の処理を呼ぶ）: `sh -c 'printf ...'` で、終了状態・標準出力・標準エラー出力。0 以外の終了状態で `Result.Ok`。存在しないコマンドで `NotFound`。`input` を渡して子が読む。`workingDirectory` の相対パスが基準のディレクトリから解決される。`environment` で加えた変数を子が読む。UTF-8 でない出力で `InvalidUTF8`。NUL を含む引数と、空か `=` を含む環境変数の名前で `InvalidInput`。`/` を含む相対パスの `program`（`workingDirectory` に置いた実行の許可のあるスクリプト `./tool`）が、子の作業ディレクトリから解決されて起動する。
- シグナル: `shell("kill -TERM $$")` の終了状態が 143（128 + 15）。
- シェル: `shell("X=abc; printf '%s' \"$X\" | wc -c")` の標準出力を trim して `3` と比べ、パイプと変数の展開が `/bin/sh` で行われることを確かめる（macOS の `wc -c` は数の前に空白を付けるので trim する。展開する変数はシェルの中で代入したものにし、`HOME` などの環境に頼らない）。`run` に同じ文字列を渡しても展開されない（引数の単語分割をしない）。
- `runAttached` の出力の順（プログラムでの確かめ）: `Console.write("before ")` の後の `runAttached` の子の出力が、捕らえた出力（`OutputTarget::Capture`）で `before ` の後に来る。継がせない場合の標準入力が空の入力である。継がせない場合に、UTF-8 でない子の出力が U+FFFD に置き換わって捕らえた出力に入る。
- CLI の別のプロセスのテスト: CLI の `run` で `runAttached` の子が処理系のプロセスの標準出力に直接書き、処理系の前の出力の後に出る。
- `runAttached` の `input`: 継がせない場合（プログラムでの確かめ）に、`input` を指定した `Command` で起動した子（`cat` に相当するコマンド）が `input` を読み、その出力が捕らえた出力に入る。継がせる場合（CLI の別のプロセスのテスト）に、CLI の標準入力に与えた内容ではなく `input` の内容を子が読む。`input` が `Option.None` のときは、これまでどおりのつなぎ先（継がせる場合は CLI の標準入力、継がせない場合は空の入力）である。
- 取り消し: `Task.withTimeout` で待つ `run`（長く眠るコマンド）が時間切れで `Option.None` を返し、スクリプトは先へ進む。子は処理系からは終わらされない（子の終わりを待たずに実行が終わる。ADR 0266 の決定 11）。このテストに限り、実時間の短い待ちを許す（ADR 0322 の帰結）。仮想の時間の部品（R25 のテスト用の部品）では、子のプロセスを起動して待ちつつ VM を止めない形を作れないためである。本物の部品（作業用のスレッドとイベントループ）で動かし、時間切れは 100 ms 程度、子は時間切れより十分長く（数秒）眠るコマンドにし、実行が子の終わりより先に終わることを経過時間で確かめる。ほかのテストには実時間の待ちを使わない。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（ADR 0286 の決定 3）で書く。本作業のテストでは `import Benitoite.Unofficial.IO.Process`・`import Benitoite.Unofficial.IO.Console` を使い、`Task.withTimeout` を使うときは、そのエフェクト `Clock.Time` のために `import Benitoite.Unofficial.IO.Clock` も加える（`withTimeout` は `uses Clock.Time, State, E`）。03-08 などの設計書の例の `import Benitoite.Json` の形を写すと、E0321 になる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- 外部コマンドを処理系から終わらせる処理を書いていない
- `runAttached` の `input` とつなぎ先の判断、テストで前提にしたコマンドを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、作業用のスレッドに言語の値を渡していないか、出力の大きさを値を作る前に確かめているか。
- 子の標準入力への書き込みと出力の読み取りで、詰まりうる順序になっていないか。
- テストが、実時間の待ちに頼らずに書けているか。例外は、取り消したときに子を終わらせないことのテストだけである（ADR 0322 の帰結）。そのテストの待ちが短く、時間切れと子の眠りの長さの差が十分か。

## 難易度の理由

子プロセスの標準入出力の扱い（詰まらない読み書き、上限、UTF-8）、シグナルで終わったときの終了状態、実行の環境ごとのつなぎ先、出力の転送との順序、取り消しとの関係と、OS に依存する細部が多い。
