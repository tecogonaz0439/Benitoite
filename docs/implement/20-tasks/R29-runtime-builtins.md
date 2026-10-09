# R29 ランタイムに結び付いた組み込みの関数と、テストに要る最小限の IO

- 依存する作業: [R26](R26-dispatch-queue-and-io-executor.md)、[R27](R27-output-writers.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R29-runtime-builtins

## 目的

U2 が作る組み込みの関数のうち、R23・R25 が書いたもの（後述）を除いた残りの本体を、型付きの形（ADR 0261）で書く。`IOError.kind`、`Lazy.force` の確かめ、標準入力の読み取り、ファイルの読み書きと `File.Reader`、`Process.exit`、時間の待ちである。これらは、OPEN-062 の再現テスト（R30）、IO の方式と中断の要求のテスト（R31）、ランタイムのゴールデンテスト（C12）が呼ぶ（[ADR 0273](../../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md) の決定 1）。

## 作業の分担

10-12 は、次の 13 項目の本体を R29 に割り当てる（`Reference.new`・`Reference.get`・`Reference.set` は R23、`Task`・`TaskGroup` の七つは R25（四つ）と R39（`Task.allOk`・`Task.race`・`Task.withTimeout`）。どちらも、それぞれの作業の受け入れテストに要るので R29 より前の作業に割り当てた。10-11・10-12「作業の割り当て」）。

| 部分 | 項目 | 権限 |
|---|---|---|
| `io_error` | `IOError.kind` | `Pure` |
| `reference` | `Reference.update`（`raw` は `Stop::Internal` のまま。確かめるだけ） | `State` |
| `lazy` | `Lazy.force`（`raw` は `Stop::Internal` のまま。確かめるだけ） | `Pure` |
| `console` | `Console.readLine`・`Console.readAll` | `Io` |
| `file` | `File.writeText`・`File.appendText`・`File.openReader`・`File.readLine` | `Io` |
| `file` | `IO.File.closeReader` | `State` |
| `process` | `Process.exit` | `Io` |
| `clock` | `Clock.sleep`・`Clock.monotonicMilliseconds` | `Io` |

名前・権限・引数の数と、部分の中の位置は変えない（10-12「まだ書かない項目の仮の本体」）。

`console`・`file`・`process`・`clock` の項目は、属するモジュールとともに非公式から始める（[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。表の名前は標準に加えた後の名前のままであり、テストのスクリプトは `import Benitoite.Unofficial.IO.Console` の形で取り込む。

## 読む設計書の節

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「共通の規則」「Console」「File」（本作業の関数の行と `File.Reader` の箇条）「Process」の `Process.exit` の箇条、「Clock」、「IOErrorKind と関数の対応」
- [エフェクト](../../design/01-spec/01-07-effects.md)の「IO の失敗」「外部から受け取る文字列」「IO を行う組み込み関数」「影響の大きい操作（初回リリース版）」
- [エラー処理](../../design/01-spec/01-09-errors.md)の「IO の失敗の種類」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の「タスクを起動する関数」の `Clock.sleep` の表
- [リソース管理](../../design/01-spec/01-10-resources.md)の「解放の失敗」「解放したリソースの使用」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」（操作を行う場所の表と箇条）、「一つの操作で作る値の大きさの上限」、「出力のバッファ」の完了を待つ時点、「タスクの待ちと取り消し」の `Clock.sleep`
- ADR: [0273](../../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md)、[0261](../../design/decisions/0261-typed-builtin-interface.md)、[0012](../../design/decisions/0012-invalid-utf8-input.md)、[0049](../../design/decisions/0049-size-limit-for-built-values.md)、[0065](../../design/decisions/0065-ioerror-kind.md)、[0144](../../design/decisions/0144-ioerrorkind-constructors.md)、[0150](../../design/decisions/0150-resource-release-as-state.md)

インターフェース:

- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「IO の失敗と、ランタイムに結び付いた関数」「IO のモジュール」「確かめること」「構成子のタグ」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の全体（`builtin!`、`IoReply`・`IoWait`・`WorkerWait`・`Lend`・`CompleteFn`・`OsResource`・`IoServices::register_resource`・`StateServices::begin_release`）
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「大きさを確かめる構築」、`ValueCtx::alloc_str_utf8`、`FieldsKind::IoError`

## 作るもの

- `src/builtins/funcs/` の `io_error.rs`・`console.rs`・`file.rs`・`process.rs`・`clock.rs`: 上の表の項目の本体（R08 が置いた仮の本体を置き換える）と、項目ごとの単体テスト。`reference.rs`・`lazy.rs` は、`raw` が `Stop::Internal` を返すことの単体テストだけを加える。この二つの `raw` の `Stop::Internal` の説明の文字列（今は "not implemented yet"）は、恒久の状態を表す文（例 命令 `FORCE`・`UPDATE` が実行するので呼ばれないこと）に改めてよい（処理系の不具合を調べるための文字列で、診断の表と `text` には載せない）。
- `src/builtins/funcs/mod.rs` のテスト `placeholders_and_their_wrappers_fail_without_runtime_operations`（R08 のファイル）は、本作業が本体を書く関数の仮の本体が "is not implemented yet" を返すことを期待しているので、本作業の後は必ず失敗する。このテストと、そのためだけにある `UnusedState` を消し、`Lazy.force`・`Reference.update` の `raw` の確かめは `lazy.rs`・`reference.rs` の単体テストに移す（ほかの作業のファイルだが、00-03 の「ほかの作業のファイル」として止まらない）。本作業の後、`src/` に "not implemented yet" の仮の本体は残らない。
- `File.Reader` の `OsResource` の実装（`file.rs` の中の非公開の型）。
- OS の誤りから `IOErrorKind` への対応（R08 が `File.readText` のために置いたもの）を、本作業の関数が要る分だけ広げる。
- 上のファイルのテストと、`tests/` の下の統合テストのファイル。

## 手順の要点

### 共通

- 権限が `Io` の関数は、送り出しの列を通って呼ばれる（R26）。関数は応答を返すだけで、列・完了の保存・取り消しとの競合・リソースの返却に触れない（ADR 0261 の決定 6）。
- 作業用のスレッドで行う関数（02-09「組み込みの操作とハンドラ表」の表の「作業用のスレッドで行う」の行）は `IoReply::Wait(IoWait::Worker(WorkerWait::new(..)))` を返す。仕事の閉包は `Send + 'static` で、引数は Rust の型（`String`・`PathBuf` など）に変えてから捕える。完了の処理は環境を捕えない `fn` で書き、待つ間に要る言語の値は捕えずに `args` から読み直す。
- 大きさの決まっていない入力（`Console.readAll`、`File.readLine` の一行、`Console.readLine` の一行）は、上限（2^30 バイト）より 1 バイト多い分まで読み、上限を超えたら資源の不足（`ResourceError::InputTooLarge`。報告は R0903）とする（02-09「一つの操作で作る値の大きさの上限」）。
- 読んだバイト列を文字列にするときは `alloc_str_utf8` を使い、正しくない UTF-8 は `IOErrorKind.InvalidUTF8` の `Result.Error` にする（ADR 0012）。確かめは VM のスレッドの完了の処理で行う。
- OS の誤りは、`std::io::ErrorKind` から次のように `IOErrorKind` にする。理由の文字列は `std::io::Error` の表示とする。

| `std::io::ErrorKind` | `IOErrorKind` |
|---|---|
| `NotFound` | `NotFound` |
| `PermissionDenied` | `PermissionDenied` |
| `AlreadyExists` | `AlreadyExists` |
| `IsADirectory` | `IsDirectory` |
| `NotADirectory` | `NotDirectory` |
| `DirectoryNotEmpty` | `DirectoryNotEmpty` |
| `InvalidInput`（パスに NUL を含むなど） | `InvalidInput` |
| `InvalidData`（UTF-8 の誤りとして処理系が作ったもの） | `InvalidUTF8` |
| そのほか | `Other` |

`IsADirectory`・`NotADirectory`・`DirectoryNotEmpty` は、R08 の `file.rs` の対応（`IoFailure`）ですでに使っていてビルドが通る。本作業はその対応を使い（二つ目を作らない）、要る分（`InvalidData` など）を加える。

### 項目ごと

- `IOError.kind(e)`: `IOError` の値（`FieldsKind::IoError`）の `tag` を `Value::Tag(CtorTag(tag))` にして返す（10-12 の箇条）。
- `Console.readLine()`: `Lend::Stdin` で標準入力の読み手を借り、`after_output_flush` を付けた仕事にする（出力の転送の完了を待ってから読む。02-09「出力のバッファ」）。一行を読み、行末の LF と、その直前にあれば CR を一つ取り除いた文字列の `Option.Some` を返す（03-07「共通の規則」。`String.lines` と同じ分け方）。LF のないまま入力の終わりに達したら、残り（末尾に CR があれば一つ除く）を一つの行として返し、次の呼び出しで `Option.None` を返す。何も読まずに入力の終わりなら `Option.None`。結果の型は `Result[Option[String], IOError]`。
- `Console.readAll()`: 同じく借りて、残りをすべて読む。
- `File.writeText(path, text)`・`File.appendText(path, text)`: 作業用のスレッドで書く。パスは基準のディレクトリから解決する（`IoServices::working_directory`。02-09「組み込みの操作とハンドラ表」）。
- `File.openReader(path)`: 作業用のスレッドで開き、完了の処理で `IoServices::register_resource(ResourceKind::FileReader, 資源, site)` でリソースの表に加え、リソースの値の `Result.Ok` を返す。`File.Reader` の `OsResource` は、`BufReader<File>` を持ち、`release` はファイルを閉じる（Rust の `File` は閉じるときの誤りを返さないので、`release` は常に `Ok`）。
- `File.readLine(reader)`: `Lend::Resource(番号)` で借りて一行を読む。行の扱いは `Console.readLine` と同じ。解放したリソースなら、共通の部分（R26）が `ReleasedResourceUsed` にする。
- `IO.File.closeReader(reader)`（`State`）: `StateServices::begin_release` で解放を始める。すぐに終われば `Result.Ok(())`、待つなら `StateReply::Wait`（VM は `WaitReason::Release` で待たせ、解放の完了の後に `PRIM` をもう一度実行する。そのときは `begin_release` が、記録した解放の失敗を取り出して扱う。R25）。解放済みのリソースに呼んだときも `Result.Ok(())` とする（01-10「解放の失敗」の最後の段落、01-12 の解放済みの `release(V)` の規則）。
- `Process.exit(code)`: `code` が 0 以上 255 以下なら `IoReply::Exit(ExitStatus(code))`、範囲の外なら `ArgumentOutOfDomain` の実行時エラー（R0701。欄 `argument` は 0 から数えるので `argument: 0`。報告の `{index}` は `argument + 1` から作られて 1 になる）とする（03-07「Process」）。
- `Clock.sleep(ms)`: `ms` が 0 以下なら待たずに `()` を返す。そうでなければ `IoReply::Wait(IoWait::Sleep { millis })`。待ちとタイマーは R25・R26 が扱う。
- `Clock.monotonicMilliseconds()`: `IoServices::monotonic_millis` を返す。テスト用の部品では仮想の時間になる。

## 受け入れテスト

- 項目ごとの単体テスト（10-12「確かめること」）: 本体の関数を直接呼び、設計書の意味どおりの応答・値・実行時エラーを確かめる。第 1 段の `stage1_io::TestIo::register_resource` は呼ばれると処理系の不具合を記録するので使えない。`openReader` の完了の処理と `closeReader` をつなげる単体テストは、`&mut ResourceTable` を持つテスト用の `IoServices` をテストのモジュールに書いて `Stage1StateServices` と表を共有するか、R26 の `IoView` を使う。作業用のスレッドの仕事を返す関数は、返った `WorkerWait` を `run` して完了の処理を呼ぶところまでを、一時ディレクトリ（`std::env::temp_dir` の下にテストが作る）で確かめる。
  - `readLine`: 二行の入力で二回 `Some`、三回目で `None`。行末の扱い: `"a\r\n"` で `"a"`、`"a\n"` で `"a"`、`"a"`（LF のない終わり）で `"a"` の後に `None`、`"a\r"`（LF のない終わり）で `"a"`。正しくない UTF-8 の行で `InvalidUTF8`。
  - `readAll`: `readLine` で一行読んだ後の残りだけを返す（03-07「Console」の箇条）。
  - `writeText` の後の `readText` で同じ内容、`appendText` で加わる。ない親ディレクトリで `NotFound`、ディレクトリへの書き込みで `IsDirectory`。
  - `openReader` と `readLine` と `closeReader`: 開いて読んで閉じる。二度目の `closeReader` が `Result.Ok(())`。（閉じた後の `readLine` の `ReleasedResourceUsed` は、判定が共通の部分（R26）にあるので、下の「プログラムでの確かめ」で確かめる。本体の中に判定を書かない）
  - `Process.exit`: 0・255 で `Exit`、-1・256 で `ArgumentOutOfDomain`。
  - `Clock.sleep`: 0 と負の値で待たない。
  - `IOError.kind`: 九つの種類のそれぞれ。
  - `Reference.update`・`Lazy.force` の `raw` が `Stop::Internal` を返す。
- プログラムでの確かめ（R25 のテスト用の部品と、両方の IO の方式で実行する）:
  - `with r = try File.openReader(path) do … end with`（`Result` を返す関数の中。`openReader` は `Result[File.Reader, IOError]` を返すので `try` で取り出す。01-10「with の規則」）でリソースが一度だけ解放される。閉じた後の `File.readLine` が `ReleasedResourceUsed` の実行時エラーになる。`with` の中で 0 の除算を起こしても解放される。
  - 読んでいるタスク（`File.readLine` の仕事をまだ実行していない）を `Task.race` で取り消し、その後に仕事を実行すると、`File.Reader` が表に戻ってから解放される（ADR 0266 の決定 4・5。OPEN-062 の R05 の形。正式な再現テストは R30）。
  - `Clock.sleep` で待つタスクがあるあいだ、ほかのタスクが進む。仮想の時間を進めるまで起きない。
  - `Console.write("Name: ")` の後の `Console.readLine()` の仕事が始まる時点で、`"Name: "` が出力先に届いている（OPEN-062 の R13 の形。正式な再現テストは R30）。
  - 統合テスト（`tests/` の下）: `run_program` に `RunEnv::parts` で筋書きの部品（R25・R26 の `testing`）を渡し、`Console.write("Name: ")` の後の `Console.readLine()` が出力の完了の待ち（`AwaitFlush`）を経て読み、正常に終わることを確かめる。R27 が加えた `WorkerExec::wakeup`（`ScriptWorkers` が待てる形の `Wakeup` を返し、`run_program` がそれを出力と IO 実行器に渡す）により、部品を渡す経路でも書き出し用のスレッドの知らせを待てる。R27 では `Console.readLine` の本体がなく書けなかったので、本作業が加える。
  - `Process.exit(3)` で止まる実行が、`with` のリソースを解放し、出力を転送してから `Exited(3)` と終了状態 3 で終わる（R21 の止める手順と `run.rs` の `EndKind::Exited`。R28 が先に入っていれば R28 の経路）。
- 回収の強制のビルドで、上のテストがすべて通る。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-12 の項目の名前・権限・引数の数と位置を変えていない
- 作業用のスレッドに渡すものに言語の値を含めていない
- `std::io::ErrorKind` の対応で判断したことを、完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行（型付きの形、大きさの上限を値を作る前に確かめること、作業用のスレッドへ渡すもの）。
- 貸し出しと返却、取り消しとの競合を、個々の関数の中に書いていないか（共通の部分に任せているか）。
- 外部から受け取るバイト列を、UTF-8 を確かめずに文字列の値にしていないか。
- `Clock.monotonicMilliseconds` と `Clock.sleep` が、差し替えられる時計（`IoServices`）だけを使っているか（`std::time` を直接読んでいないか）。

## 難易度の理由

一つ一つの関数は短いが、作業用のスレッドの仕事、貸し出し、完了の処理、出力の完了の待ちの規則を正しく使い分ける必要がある。仕組みそのものは R24〜R27 が作ってあり、本作業はそれを使う側なので、難易度は中程度である。
