# L13 外部コマンドの起動

- 依存する作業: [L10](L10-console-clock-process.md)、[R26](R26-dispatch-queue-and-io-executor.md)、[R27](R27-output-writers.md)、[R28](R28-interrupt-and-stop-procedure.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L13-external-commands

## 目的

外部コマンドを起動する三つの操作の本体を書く。10-15 の部分 34（`process::RUN_DECLS`）である。シェルを通さない起動（`Process.run`・`Process.runAttached`）と、文字列をシェルに解釈させる実行（`Process.shell`）を分ける（03-07「外部コマンドの起動とシェル」）。あわせて、`Process.runAttached` の標準入出力のつなぎ先を、実行の環境から決める（10-16「外部コマンドの標準入出力」）。

| 項目 | 権限 | エフェクト |
|---|---|---|
| `Process.run`・`Process.runAttached`・`Process.shell` | `Io` | `Process.Run` |

依存の理由: `Process.Command` を作る `Process.command` のテストと、環境変数・作業ディレクトリの扱い（L10）を使う。`runAttached` は出力の転送の完了を待ってから起動する（R27）。子を待つ仕事は作業用のスレッドで長く続くので、IO 実行器（R26）の上で、中断の要求で止める手順（R28）とあわせて確かめる。

## 読む設計書の節

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「Process」（`run`・`runAttached`・`shell` の行、`Process.Command`・`Process.Output`、既定の値、基準のディレクトリ、`environment` の加え方、`NotFound`、終了状態、UTF-8、シグナルで終わったときの終了状態、`/bin/sh -c`、`runAttached` の標準入出力）、「外部コマンドの起動とシェル」、「IOErrorKind と関数の対応」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」（`runAttached` の出力の転送の完了の待ち、つなぎ先）、「タスクの待ちと取り消し」（作業用のスレッドで続く操作を止めず、起動した外部コマンドを終わらせないこと）、「出力のバッファ」の完了を待つ時点、「一つの操作で作る値の大きさの上限」
- [エフェクト](../../design/01-spec/01-07-effects.md)の「影響の大きい操作（初回リリース版）」
- ADR: [0243](../../design/decisions/0243-signal-exit-code-and-posix-shell.md)、[0165](../../design/decisions/0165-exit-and-stdio-in-embedded-runs.md)、[0184](../../design/decisions/0184-permissions-granted-per-builtin-effect.md)

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
- 起動: `std::process::Command` でシェルを通さずに起動する。引数の単語分割とワイルドカードの展開は行わない。`workingDirectory` が `None` なら基準のディレクトリ、相対パスなら基準のディレクトリから解決する（02-09「組み込みの操作とハンドラ表」の箇条）。処理系のプロセスの作業ディレクトリは変えない（02-09「実行ごとの状態」）。`environment` の組は、スクリプトの環境変数に加えるか置き換える。
- `input`: `Some(s)` なら子の標準入力に `s` を書いて閉じ、`None` なら空の入力（`Stdio::null`）にする。書く側は別のスレッドにし、子の出力を集めるのと並べて行う（両方をパイプにしたまま片方だけを待つと、パイプが詰まって止まる）。
- `run`・`shell` の出力: 標準出力と標準エラー出力をそれぞれ上限（2^30 バイト）より 1 バイト多い分まで集め、上限を超えたら資源の不足（`InputTooLarge`）。UTF-8 でなければ `InvalidUTF8`。上限を超えた後も子の出力を読み捨てて、子が詰まらずに終わるようにする。
- 終了状態: `ExitStatus::code()` があればその値。シグナルで終わったとき（`code()` が `None`）は、`ExitStatusExt::signal()` の番号に 128 を足す（ADR 0243）。0 以外の終了状態でも `Result.Ok`。
- 起動するコマンドが見つからなければ `NotFound`（03-07）。`program` に NUL を含めば `InvalidInput`。
- `shell(commandLine)`: `/bin/sh -c commandLine` を `run` と同じく実行する（ADR 0243）。作業ディレクトリは基準のディレクトリ、環境変数はスクリプトのもの、標準入力は空の入力とする（`Process.Command` の既定の値と同じ）。
- `runAttached`: `WorkerWait::after_output_flush` を付け、出力の転送の完了を待ってから起動する。つなぎ先は `IoServices::runtime_view` で読む `IoRuntime::process_stdio` で決める（10-16）。継がせるときは `Stdio::inherit`、継がせないときは、標準入力を空の入力にし、標準出力と標準エラー出力を集めて、完了の処理で `IoServices::write_output` により標準出力、標準エラー出力の順に書く。`input` を指定した `Command` を `runAttached` に渡したときは、`input` を子の標準入力に書く（継がせる指定より優先する）。この判断を `///` のコメントに書く。結果は終了状態。
- `runtime::run` で `process_stdio` を決める（10-16 の箇条: `StdinSource::Process`・`OutputTarget::Stdout`・`OutputTarget::Stderr` のときだけ継がせる）。
- 取り消しと中断の要求: 作業用のスレッドで続く子の待ちを止めず、起動した外部コマンドを処理系から終わらせない（02-09「タスクの待ちと取り消し」）。中断の要求で止めるときも、処理系は子に何も送らない。README の骨子にあった「中断の要求と取り消しで子プロセスを止めること」は、この 02-09 の定めと食い違うので採らない（README の「U3 の作業の文書で見つかった点」）。取り消した後に子が終わった仕事の結果は、R26 の共通の処理が捨てる。

## 受け入れテスト

- 項目ごとの単体テスト（仕事を `run` して完了の処理を呼ぶ）: `echo` に相当するコマンド（`/bin/sh` ではなく、テストの中で `std::env::current_exe` などで見つけられる確実なコマンド。`/bin/echo` などの存在は環境によるので、`/bin/sh -c` で書ける `shell` のテストと分けて、`sh` が起動できることを前提にしてよい）で、終了状態・標準出力・標準エラー出力。0 以外の終了状態で `Result.Ok`。存在しないコマンドで `NotFound`。`input` を渡して子が読む。`workingDirectory` の相対パスが基準のディレクトリから解決される。`environment` で加えた変数を子が読む。UTF-8 でない出力で `InvalidUTF8`。
- シグナル: `shell("kill -TERM $$")` の終了状態が 143（128 + 15）。
- シェル: `shell("printf '%s' \"$HOME\" | wc -c")` のように、パイプと変数の展開が `/bin/sh` で行われる。`run` に同じ文字列を渡しても展開されない（引数の単語分割をしない）。
- `runAttached` の出力の順（プログラムでの確かめ）: `Console.write("before ")` の後の `runAttached` の子の出力が、捕らえた出力（`OutputTarget::Capture`）で `before ` の後に来る。継がせない場合の標準入力が空の入力である。
- CLI の別のプロセスのテスト: CLI の `run` で `runAttached` の子が処理系のプロセスの標準出力に直接書き、処理系の前の出力の後に出る。
- 取り消し: `Task.withTimeout` で待つ `run`（長く眠るコマンド）が時間切れで `Option.None` を返し、スクリプトは先へ進む。子は処理系からは終わらされない（子の終わりを待たずに実行が終わる。ADR 0266 の決定 11）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- 外部コマンドを処理系から終わらせる処理を書いていない
- `runAttached` の `input` とつなぎ先の判断、テストで前提にしたコマンドを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、作業用のスレッドに言語の値を渡していないか、出力の大きさを値を作る前に確かめているか。
- 子の標準入力への書き込みと出力の読み取りで、詰まりうる順序になっていないか。
- テストが、実時間の待ちに頼らずに書けているか（長く眠るコマンドを使うテストは、仮想の時間の `Task.withTimeout` で時間切れを起こす）。

## 難易度の理由

子プロセスの標準入出力の扱い（詰まらない読み書き、上限、UTF-8）、シグナルで終わったときの終了状態、実行の環境ごとのつなぎ先、出力の転送との順序、取り消しとの関係と、OS に依存する細部が多い。
