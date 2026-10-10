# IO のモジュール

- 状態: 確定
- 関連ADR: [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0067](../decisions/0067-with-resource-scope.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0107](../decisions/0107-bytes.md), [0115](../decisions/0115-structured-io-concurrency.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0144](../decisions/0144-ioerrorkind-constructors.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0150](../decisions/0150-resource-release-as-state.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md), [0172](../decisions/0172-random-conversion-procedure.md), [0176](../decisions/0176-first-release-targets-and-static-linux-build.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0243](../decisions/0243-signal-exit-code-and-posix-shell.md), [0254](../decisions/0254-return-type-after-arrow.md), [0256](../decisions/0256-data-keyword-for-algebraic-types.md), [0257](../decisions/0257-match-with-case-arms.md), [0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md), [0287](../decisions/0287-stdlib-details-decided-in-u3-plan.md), [0291](../decisions/0291-file-copy-limit-and-http-server-details.md), [0322](../decisions/0322-stdlib-details-from-u3-preflight.md), [0327](../decisions/0327-fmt-symlink-and-process-attached-details.md), [0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md), [0336](../decisions/0336-command-substitute-library-policy.md), [0337](../decisions/0337-file-transfer-for-large-copies.md), [0338](../decisions/0338-password-manager-wrappers-as-official-libraries.md)
- 未決事項: [OPEN-046](../open-issues.md#open-046), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-079](../open-issues.md#open-079), [OPEN-080](../open-issues.md#open-080), [OPEN-082](../open-issues.md#open-082), [OPEN-083](../open-issues.md#open-083), [OPEN-084](../open-issues.md#open-084), [OPEN-086](../open-issues.md#open-086), [OPEN-087](../open-issues.md#open-087), [OPEN-088](../open-issues.md#open-088), [OPEN-089](../open-issues.md#open-089), [OPEN-090](../open-issues.md#open-090)
- 移行元: [設計メモ](../sources/fp-language-design.md) 15, 16, 0.2

## 目的と範囲

`Benitoite.IO` の下の IO を行うモジュール（`Console`・`File`・`Process`・`Clock`・`Random`）の範囲、関数、エフェクト、要する権限を定める。外部コマンドの起動とシェルによる実行の API もここで扱う。

現在の版は、各モジュールのエフェクトと権限の対応、初回リリース版で各モジュールに入れる機能の範囲（[ADR 0137](../decisions/0137-first-release-library-scope.md)）、各関数の名前と型の草稿を定める。ネットワークの操作を行うモジュールは `Benitoite.IO` の下に置かず、[ネットワークのモジュール](03-09-network.md)で定める（[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。

初回リリース版では、本章のモジュールはどれも非公式のモジュールであり、`import Benitoite.Unofficial.IO.Console` の形で取り込む（[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」、[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)）。本章は、標準に加えた後の名前（`Benitoite.IO.Console`）で書く。取り込んだ後の書き方（`Console.writeLine`、`uses Console.Write`）は、どちらの名前で取り込んでも同じである。

## 前提

IO を行う関数の振る舞い、IO の失敗、実行時の権限制御は[エフェクト](../01-spec/01-07-effects.md)で、リソースの型と `with` は[リソース管理](../01-spec/01-10-resources.md)で、タスクと時間の経過を待つことは[並行処理](../01-spec/01-11-concurrency.md)で定める。IO を行う組み込みの関数は、すべて IO 実行器を通す（[ライブラリの構成](03-01-library-structure.md)、[ランタイム](../02-impl/02-09-runtime.md)）。標準ライブラリの名前空間と prelude は[標準ライブラリ](03-06-stdlib.md)で定める。

## 仕様

### モジュールとエフェクト

【決定】IO を行う関数は、`Benitoite.IO` の下のモジュールに置く。各モジュールは組み込みのエフェクトを宣言し、IO の関数はそのエフェクトの操作である（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。ただし、リソースを解放する関数（`File.closeReader`・`File.closeWriter`）は、操作ではなく `State` を型に持つ組み込みの関数である（[ADR 0150](../decisions/0150-resource-release-as-state.md)）。各関数の型と振る舞いは本章で定め、すべて組み込みで実装する。IO が起きる時期と順序、IO の失敗の扱いは[エフェクト](../01-spec/01-07-effects.md)で、`Clock.sleep` がタスクを止める意味は[並行処理](../01-spec/01-11-concurrency.md)で定める。

| モジュール | エフェクト | 関数 | 要する権限 |
|---|---|---|---|
| `Benitoite.IO.Console` | `Console.Write` | `Console.write`・`Console.writeLine`・`Console.writeError`・`Console.writeErrorLine` | なし |
| 〃 | `Console.Read` | 標準入力を読む関数（後述の「各モジュールの範囲」） | なし |
| `Benitoite.IO.File` | `File.Read` | パスを受け取って読む関数（後述の「File」） | `File.Read`（対象: パス） |
| 〃 | `File.Write` | パスを受け取って書く関数（後述の「File」） | `File.Write`（対象: パス） |
| `Benitoite.IO.Process` | `Process.Environment` | `Process.arguments`・`Process.scriptDirectory`（[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)）・`Process.workingDirectory`・`Process.environmentVariable` | `Process.environmentVariable` は `Process.Environment`（対象: 環境変数の名前）、ほかはなし |
| 〃 | `Process.Run` | `Process.run`・`Process.runAttached`・`Process.shell` | `Process.Run`（対象: コマンド）。`Process.shell` はシェルによる実行の許可 |
| 〃 | `Process.Exit` | `Process.exit` | `Process.Exit` |
| `Benitoite.IO.Clock` | `Clock.Time` | `Clock.sleep` と、時刻を読む関数 | なし |
| `Benitoite.IO.Random` | `Random.Generate` | 乱数の関数（後述の「各モジュールの範囲」） | なし |

「要する権限」の欄は、関数が要する許可の単位（組み込みのエフェクトと、シェルによる実行）と、その対象を示す（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。許可の単位と対象、許可を要しない操作は[エフェクト](../01-spec/01-07-effects.md)の実行時の権限制御の節で定める。この欄は、初回リリース版の後にサーバモードとあわせて加える実行時の権限制御が使うものであり、初回リリース版の処理系は許可を調べない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[OPEN-055](../open-issues.md#open-055)）。「—」は、許可を調べない関数（開いたリソースに対する操作と、純粋な関数）を示す。

【方針】`IOError` と `IOErrorKind` は prelude の型であり、`IOError.message` は[エフェクト](../01-spec/01-07-effects.md)で定め、組み込みで実装する。IO の失敗は `Result.Error` で返す（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。`File.readText` は、ファイルの内容が正しい UTF-8 でなければ `Result.Error` を返す（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。

### 各モジュールの範囲

【方針】初回リリース版の各モジュールには、次の機能を入れる（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。関数の一覧は後述の各節で定める。

| モジュール | 機能 |
|---|---|
| `Console` | 標準出力と標準エラー出力への書き込み。標準入力の読み取り（一行ずつ、全体） |
| `File` | ファイルの読み書きと追記。ディレクトリの一覧、存在の確認、ファイルの情報、ディレクトリの作成、削除、移動、コピー。一行ずつ読み書きするリソースの型 |
| `Process` | コマンドライン引数、環境変数、作業ディレクトリ、実行を始めるスクリプトのディレクトリ。外部コマンドの起動、シェルによる実行、終了状態を指定した終了 |
| `Clock` | 現在の時刻、経過時間の計測、時間の経過を待つこと |
| `Random` | 整数と浮動小数の乱数、リストの並べ替え。種を与えて同じ列を作る純粋な生成器 |

時刻の値の型は `Benitoite.Time`、パスの結合と分解は `Benitoite.Path` で定める（[テキストとデータの処理](03-08-text-and-data.md)）。`Clock` は時刻を読む操作だけを持つ。

### 共通の規則

【方針】各モジュールの関数は、次の規則に従う。

- パスは `String` で表す。相対パスは、実行ごとの基準のディレクトリから辿る（[エフェクト](../01-spec/01-07-effects.md)、[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。基準のディレクトリは、CLI の `run` とテストの実行器では処理系を起動したときの作業ディレクトリであり、サーバモードの子プロセスではデーモンが子プロセスの作業ディレクトリにしたディレクトリである（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)、[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。パスの組み立ては `Benitoite.Path` の関数で行う。
- 外部の状態によって失敗しうる関数は `Result[T, IOError]` を返す（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。利用者が許可していない操作の拒否は、`IOError` ではなく実行時エラー（権限の拒否）である（[エフェクト](../01-spec/01-07-effects.md)の実行時の権限制御の節）。この拒否は、サーバモードとあわせて加える実行時の権限制御で起こり、初回リリース版では起こらない。OS が操作を拒んだときは `IOErrorKind.PermissionDenied` を返す。
- テキストは UTF-8 で読み書きする。読んだ内容が正しい UTF-8 でなければ、`IOErrorKind.InvalidUTF8` の `Result.Error` を返す（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。
- 行に分けるときは、LF（U+000A）で区切り、各行の末尾に CR（U+000D）が一つあれば取り除く。最後の LF の後に文字が残れば、それも一つの行とする。行の値は、区切りの文字を含まない。この分け方は `String.lines`（[標準ライブラリ](03-06-stdlib.md)）と同じであり、内容全体を行に分ける関数（`File.readLines`・`Console.readAllLines`）にも、一行ずつ読む関数（`Console.readLine`・`File.readLine`）にも当てはまる。一行ずつ読む関数は、行の末尾の LF と、その直前にあれば CR を一つ取り除いた値を返す。LF のないまま入力の終わりに達したときは、残りの文字（末尾に CR が一つあれば取り除く）を一つの行として返し、次の呼び出しで `Option.None` を返す。
- 時間の長さは、ミリ秒を単位とする `Integer` で表す（`Clock.sleep`・`Task.withTimeout` と同じ。[並行処理](../01-spec/01-11-concurrency.md)）。
- ディレクトリの中の名前を並べる関数は、名前を UTF-8 のバイト列の辞書式の順に並べる。OS が返す順に依存しないので、同じ内容のディレクトリからは、同じ結果が得られる。

### Console

【方針】`Benitoite.IO.Console` の関数は次のとおりとする。どれも許可を要しない。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Console.write(s)` | `function(String) -> Unit uses Console.Write` | `s` を標準出力に書く |
| `Console.writeLine(s)` | `function(String) -> Unit uses Console.Write` | `s` と LF を標準出力に書く |
| `Console.writeError(s)` | `function(String) -> Unit uses Console.Write` | `s` を標準エラー出力に書く |
| `Console.writeErrorLine(s)` | `function(String) -> Unit uses Console.Write` | `s` と LF を標準エラー出力に書く |
| `Console.readLine()` | `function() -> Result[Option[String], IOError] uses Console.Read` | 標準入力から一行を読む。入力の終わりに達していれば `Option.None` |
| `Console.readAll()` | `function() -> Result[String, IOError] uses Console.Read` | 標準入力の残りをすべて読む |
| `Console.readAllLines()` | `function() -> Result[List[String], IOError] uses Console.Read` | 標準入力の残りをすべて読み、行に分ける |
| `Console.readAllBytes()` | `function() -> Result[Bytes, IOError] uses Console.Read` | 標準入力の残りを、文字コードを解釈せずにすべて読む |

- 書き込みの関数は `Result` を返さない。書き込みの失敗は実行時エラーとする（[エフェクト](../01-spec/01-07-effects.md)の「IO の失敗」）。
- 読み取りの関数は、それまでに読んだ位置から続けて読む。`Console.readLine` で一部の行を読んだ後に `Console.readAll` を呼ぶと、残りだけを返す。
- テストの実行器とサーバモードの子プロセスでの実行では、標準入力は空の入力である。`Console.readLine` は `Result.Ok(Option.None)` を、`Console.readAll` などは空の値を返す。標準出力と標準エラー出力に書いた内容は、テストの実行器ではテストごとに捕らえて結果に含め、サーバモードではデーモンがジョブの出力として保存する（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)、[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。

### File

【方針】`Benitoite.IO.File` のパスを受け取る関数は次のとおりとする。

| 関数 | 型 | 振る舞い | 要する権限 |
|---|---|---|---|
| `File.readText(path)` | `function(String) -> Result[String, IOError] uses File.Read` | ファイルの内容全体を文字列として読む | `File.Read`（対象: `path`） |
| `File.readBytes(path)` | `function(String) -> Result[Bytes, IOError] uses File.Read` | ファイルの内容全体を、文字コードを解釈せずに読む | `File.Read`（対象: `path`） |
| `File.readLines(path)` | `function(String) -> Result[List[String], IOError] uses File.Read` | ファイルの内容全体を読み、行に分ける | `File.Read`（対象: `path`） |
| `File.exists(path)` | `function(String) -> Result[Boolean, IOError] uses File.Read` | パスが指すものがあるか。ないときだけ `false`。調べられないときは `Result.Error` | `File.Read`（対象: `path`） |
| `File.info(path)` | `function(String) -> Result[File.Info, IOError] uses File.Read` | ファイルの情報。最後の構成要素がシンボリックリンクなら、リンクそのものの情報を返す | `File.Read`（対象: `path`） |
| `File.listDirectory(path)` | `function(String) -> Result[List[String], IOError] uses File.Read` | ディレクトリの中の名前（パスではない）を並べたリスト。`.` と `..` を含まない。名前を UTF-8 のバイト列として比べた辞書式の順に並べる | `File.Read`（対象: `path`） |
| `File.walk(path)` | `function(String) -> Result[List[String], IOError] uses File.Read` | ディレクトリの下のすべてのファイルとディレクトリを、`path` からの相対パスで並べたリスト。ディレクトリを指すシンボリックリンクの先は辿らない | `File.Read`（対象: `path`） |
| `File.canonicalize(path)` | `function(String) -> Result[String, IOError] uses File.Read` | シンボリックリンクを解決した絶対パス | `File.Read`（対象: `path`） |
| `File.writeText(path, text)` | `function(String, String) -> Result[Unit, IOError] uses File.Write` | ファイルを作るか置き換え、内容を `text` にする | `File.Write`（対象: `path`） |
| `File.writeBytes(path, data)` | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | ファイルを作るか置き換え、内容を `data` にする | `File.Write`（対象: `path`） |
| `File.appendText(path, text)` | `function(String, String) -> Result[Unit, IOError] uses File.Write` | ファイルの末尾に `text` を加える。ファイルがなければ作る | `File.Write`（対象: `path`） |
| `File.appendBytes(path, data)` | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | ファイルの末尾に `data` を加える。ファイルがなければ作る | `File.Write`（対象: `path`） |
| `File.createDirectory(path)` | `function(String) -> Result[Unit, IOError] uses File.Write` | ディレクトリを作る。途中のディレクトリがなければ作る。既にディレクトリがあれば何もしない | `File.Write`（対象: `path`） |
| `File.remove(path)` | `function(String) -> Result[Unit, IOError] uses File.Write` | ファイル、シンボリックリンク、空のディレクトリを削除する | `File.Write`（対象: `path`） |
| `File.removeTree(path)` | `function(String) -> Result[Unit, IOError] uses File.Write` | ディレクトリとその下をすべて削除する。シンボリックリンクの先は削除しない | `File.Write`（対象: `path`） |
| `File.rename(from, to)` | `function(String, String) -> Result[Unit, IOError] uses File.Write` | `from` を `to` に移す | `from` と `to` の両方に `File.Write` |
| `File.copy(from, to)` | `function(String, String) -> Result[Unit, IOError] uses File.Read, File.Write` | 普通のファイル `from` の内容を `to` に写す。`to` があれば置き換える | `from` に `File.Read`、`to` に `File.Write` |

```text
record Info
  kind: EntryKind
  size: Integer
  modified: Time.Instant
end record

data EntryKind
  RegularFile
  Directory
  SymbolicLink
  Other
end data
```

- `File.Info` の `size` はバイトの数、`modified` は最後に内容を変えた時刻（`Benitoite.Time` の `Time.Instant`）である。`File.Info` と `File.EntryKind` は `Benitoite.IO.File` の型であり、`File.Info.size(info)` のように使う。
- `File.walk` は、並べる順を、相対パスを UTF-8 のバイト列として比べた辞書式の順とする。
- `File.createDirectory` は、パスに普通のファイルがあれば `IOErrorKind.AlreadyExists` を返す。`File.remove` は、空でないディレクトリに `IOErrorKind.DirectoryNotEmpty` を返す。
- 【方針】`File.copy` は、`File.readBytes` と `File.writeBytes` を呼ぶ標準ライブラリのソースの関数とする。内容を一度 `Bytes` の値に読むので、写せるファイルの大きさは 2^30 バイト（1 GiB）までである。これを超えるファイルでは、`File.readBytes` と同じく資源の不足として停止する（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」、[ADR 0291](../decisions/0291-file-copy-limit-and-http-server-details.md)）。

【方針】ファイルを一行ずつ、または一定の大きさずつ読み書きするために、リソースの型 `File.Reader` と `File.Writer` を置く（[リソース管理](../01-spec/01-10-resources.md)）。

| 関数 | 型 | 振る舞い | 要する権限 |
|---|---|---|---|
| `File.openReader(path)` | `function(String) -> Result[File.Reader, IOError] uses File.Read` | ファイルを読むために開く | `File.Read`（対象: `path`） |
| `File.readLine(reader)` | `function(File.Reader) -> Result[Option[String], IOError] uses File.Read` | 一行を読む。ファイルの終わりに達していれば `Option.None` | — |
| `File.readChunk(reader, maximumBytes)` | `function(File.Reader, Integer) -> Result[Option[Bytes], IOError] uses File.Read` | 最大 `maximumBytes` バイトを読む。ファイルの終わりに達していれば `Option.None` | — |
| `File.closeReader(reader)` | `function(File.Reader) -> Result[Unit, IOError] uses State` | 閉じる | — |
| `File.openWriter(path, mode)` | `function(String, File.WriteMode) -> Result[File.Writer, IOError] uses File.Write` | ファイルを書くために開く。`WriteMode.Replace` なら作るか空にし、`WriteMode.Append` なら末尾に加える | `File.Write`（対象: `path`） |
| `File.write(writer, text)` | `function(File.Writer, String) -> Result[Unit, IOError] uses File.Write` | `text` を書く | — |
| `File.writeLine(writer, text)` | `function(File.Writer, String) -> Result[Unit, IOError] uses File.Write` | `text` と LF を書く | — |
| `File.writeChunk(writer, data)` | `function(File.Writer, Bytes) -> Result[Unit, IOError] uses File.Write` | `data` を書く | — |
| `File.closeWriter(writer)` | `function(File.Writer) -> Result[Unit, IOError] uses State` | 書いた内容を書き出してから閉じる | — |

```text
data WriteMode
  Replace
  Append
end data
```

- 権限は、開くときに一度だけ判定する。開いた後の読み書きは、許可を改めて調べない。
- `with` で束縛したときの解放は、`File.Reader` では `File.closeReader`、`File.Writer` では `File.closeWriter` と同じ処理である。`File.closeReader` と `File.closeWriter` は、`File.Read`・`File.Write` の操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。解放のエフェクトは `State` である（[リソース管理](../01-spec/01-10-resources.md)、[ADR 0150](../decisions/0150-resource-release-as-state.md)）。
- 解放した後の `File.Reader` と `File.Writer` に対する操作は、実行時エラー（解放したリソースの使用）とする（[リソース管理](../01-spec/01-10-resources.md)の「解放したリソースの使用」）。
- `File.readChunk` の `maximumBytes` が 1 未満なら、実行時エラーとする。

```text
import Benitoite.IO.File

function countLines(path: String) -> Result[Integer, IOError] uses File.Read, State
  with reader = try File.openReader(path) do
    return countFrom(reader, 0)
  end with
end function

function countFrom(reader: File.Reader, count: Integer) -> Result[Integer, IOError] uses File.Read
  return match try File.readLine(reader) with
    case Option.Some(_) -> countFrom(reader, count + 1)
    case Option.None -> Result.Ok(count)
  end match
end function
```

### Process

【方針】`Benitoite.IO.Process` の関数は次のとおりとする。

| 関数 | 型 | 振る舞い | 要する権限 |
|---|---|---|---|
| `Process.arguments()` | `function() -> List[String] uses Process.Environment` | コマンドライン引数の並び（[エフェクト](../01-spec/01-07-effects.md)） | なし |
| `Process.scriptDirectory()` | `function() -> String uses Process.Environment` | 実行を始めるスクリプトのディレクトリの絶対パス（[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)） | なし |
| `Process.environmentVariable(name)` | `function(String) -> Result[Option[String], IOError] uses Process.Environment` | 環境変数の値。定義されていなければ `Option.None` | `Process.Environment`（対象: `name`） |
| `Process.workingDirectory()` | `function() -> Result[String, IOError] uses Process.Environment` | 作業ディレクトリの絶対パス | なし |
| `Process.command(program, arguments)` | `function(String, List[String]) -> Process.Command` | 後述の既定の値を入れた `Process.Command` を作る。純粋な関数である | — |
| `Process.run(command)` | `function(Process.Command) -> Result[Process.Output, IOError] uses Process.Run` | コマンドを起動し、終わるのを待ち、標準出力と標準エラー出力を集めて返す | `Process.Run`（対象: `command` のコマンド） |
| `Process.runAttached(command)` | `function(Process.Command) -> Result[Integer, IOError] uses Process.Run` | コマンドを起動し、標準入力・標準出力・標準エラー出力をスクリプトのものにつないで、終わるのを待つ。終了状態を返す | `Process.Run`（対象: `command` のコマンド） |
| `Process.shell(commandLine)` | `function(String) -> Result[Process.Output, IOError] uses Process.Run` | 文字列をシェルに渡して実行し、`Process.run` と同じく結果を返す | シェルによる実行 |
| `Process.exit(code)` | `function[T](Integer) -> T uses Process.Exit` | 終了状態を `code` にして実行を終える。呼び出し元へは戻らない | `Process.Exit` |

```text
record Command
  program: String
  arguments: List[String]
  workingDirectory: Option[String]
  environment: Map[String, String]
  input: Option[String]
end record

record Output
  exitCode: Integer
  standardOutput: String
  standardError: String
end record
```

- `Process.command(program, arguments)` は、`workingDirectory` を `Option.None`（基準のディレクトリを使う）、`environment` を空のマップ（スクリプトの環境変数をそのまま渡す）、`input` を `Option.None`（標準入力に何も渡さない）にする。ほかの値にするときは、レコードの更新（`Process.Command(..cmd, workingDirectory: Option.Some("./sub"))`）で変える。
- 基準のディレクトリは、前述の「共通の規則」のとおりである。`workingDirectory` に相対パスを指定したときは、基準のディレクトリから辿る。
- `program` が `/` を含む相対パス（`./tool` など）のときは、子の作業ディレクトリ（`workingDirectory` を解決したもの。`Option.None` なら基準のディレクトリ）から辿って絶対パスにしてから起動する。シェルで `cd dir && ./tool` と書いたときと同じ場所のファイルを起動する。`/` を含まない名前は、環境変数 `PATH` から探す（[ADR 0327](../decisions/0327-fmt-symlink-and-process-attached-details.md) の決定 4）。
- `environment` の組は、スクリプトの環境変数に加えるか、同じ名前の変数を置き換える。
- 起動するコマンドが見つからなければ `IOErrorKind.NotFound` を返す。コマンドが 0 以外の終了状態で終わっても、`Result.Ok` を返す。終了状態は `exitCode` で調べる。
- `Process.run`・`Process.shell` で、集めた出力が正しい UTF-8 でなければ、`IOErrorKind.InvalidUTF8` を返す。
- 【決定】`Process.run`・`Process.runAttached` で `input` に `Option.Some` を指定したとき、子が入力を読み切らずに終わり、子の標準入力への書き込みが失敗しても（読み手のいないパイプへの書き込み。Rust の `std::io::ErrorKind::BrokenPipe`）、誤りにしない。書けた分で入力を終えたものとし、子の終了状態と集めた出力を `Result.Ok` で返す（[ADR 0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 4）。
- 【決定】シグナルで終わったコマンドの `exitCode` は、Unix では 128 にシグナルの番号を足した値とする（[ADR 0243](../decisions/0243-signal-exit-code-and-posix-shell.md)）。POSIX のシェルがシグナルで終わったコマンドに与える終了状態と同じ形である。Rust の標準ライブラリはこのとき終了コードを返さない（`ExitStatus::code()` が `None`）ので、処理系はシグナルの番号（`ExitStatusExt::signal()`）から計算する。
- 【決定】`Process.shell` は、Unix では `/bin/sh -c` で文字列を実行する（ADR 0243）。`/bin/sh` の実装は OS と設定によって違う。macOS の `/bin/sh` は、設定によって bash・dash・zsh のどれかとして動き、Debian の `/bin/sh` は dash である。そのため、`Process.shell` に渡す文字列は POSIX の sh の範囲で書く必要がある。同梱の Agent Skill は、そのように書くようエージェントに指示する（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)）。
- 【方針】Windows で直接動く実行ファイルでは、`Process.shell` は `cmd.exe /C` を使う。Windows の項目（強制的に終わらせられたプロセスの終了状態、`cmd.exe` に渡す文字列の引用の規則）は、その実行ファイルを配ると決めるときに確かめる（[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md)、ADR 0243）。
- `Process.exit` の `code` は 0 以上 255 以下でなければならず、範囲の外なら実行時エラーとする。終える前に、開いている `with` のリソースを解放し（[リソース管理](../01-spec/01-10-resources.md)）、出力を書き出す。
- CLI の `run` では、`Process.exit` は処理系のプロセスを終える。サーバモードの子プロセスでは、子プロセスを終え、デーモンがその終了状態をジョブの結果とする（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。テストの実行器では、処理系のプロセスを終えず、その実行だけを終え、そのテストを失敗として報告する（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)、[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- `Process.runAttached` で起動したコマンドの標準入出力は、スクリプトの標準入出力と同じつなぎ先につなぐ。テストの実行器とサーバモードの子プロセスでは、空の入力と、その実行の出力の受け取り先である。ただし、`input` に `Option.Some` を指定した `Process.Command` では、指定した文字列を子の標準入力にする。標準出力と標準エラー出力は、`input` の指定にかかわらずスクリプトと同じつなぎ先につなぐ（[ADR 0322](../decisions/0322-stdlib-details-from-u3-preflight.md) の決定 5）。
- テストの実行器とサーバモードの子プロセスの `Process.runAttached` では、処理系が子の標準出力と標準エラー出力を集め、子が終わった後に、その実行の出力の受け取り先へ書く。集めた出力が正しい UTF-8 でなければ、壊れたバイトの並びを置換文字 U+FFFD に置き換えて書き、`IOErrorKind.InvalidUTF8` は返さない。集める出力の大きさには `Process.run`・`Process.shell` と同じ上限を当て、標準出力と標準エラー出力のどちらかが 2^30 バイトを超えたら、資源の不足として停止する（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」、[ADR 0327](../decisions/0327-fmt-symlink-and-process-attached-details.md) の決定 2・3）。

### Clock

【方針】`Benitoite.IO.Clock` の関数は次のとおりとする。どれも許可を要しない。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Clock.now()` | `function() -> Time.Instant uses Clock.Time` | 現在の時刻 |
| `Clock.localOffsetMinutes()` | `function() -> Integer uses Clock.Time` | 現在の時刻での、地方時の UTC からの差（東を正とする分の数） |
| `Clock.monotonicMilliseconds()` | `function() -> Integer uses Clock.Time` | 経過時間を計るための値。起点は定めず、一回の実行の中で減らない |
| `Clock.sleep(milliseconds)` | `function(Integer) -> Unit uses Clock.Time` | 呼び出したタスクを止める（[並行処理](../01-spec/01-11-concurrency.md)） |

- `Time.Instant` は `Benitoite.Time` の型である（[テキストとデータの処理](03-08-text-and-data.md)）。
- OS から地方時の UTC からの差を得られないとき（タイムゾーンの設定を持たない最小のコンテナなど）、`Clock.localOffsetMinutes` は 0 を返す。実行時エラーにも `IOError` にもしない（[ADR 0287](../decisions/0287-stdlib-details-decided-in-u3-plan.md)）。
- 経過時間は、`Clock.monotonicMilliseconds` の二つの値の差で計る。`Clock.now` は、OS の時計が調整されると戻ることがあるので、経過時間の計測には使わない。

### Random

【方針】`Benitoite.IO.Random` の関数は次のとおりとする。どれも許可を要しない。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Random.integer(low, high)` | `function(Integer, Integer) -> Integer uses Random.Generate` | `low` 以上 `high` 未満の整数 |
| `Random.float()` | `function() -> Float uses Random.Generate` | 0.0 以上 1.0 未満の浮動小数 |
| `Random.boolean()` | `function() -> Boolean uses Random.Generate` | `true` か `false` |
| `Random.shuffle(xs)` | `function[T](List[T]) -> List[T] uses Random.Generate` | 要素を並べ替えたリスト |
| `Random.choose(xs)` | `function[T](List[T]) -> Option[T] uses Random.Generate` | 要素の一つ。空なら `Option.None` |
| `Random.fromSeed(seed)` | `function(Integer) -> Random.Generator` | 種から生成器を作る。純粋な関数である |
| `Random.nextInteger(generator, low, high)` | `function(Random.Generator, Integer, Integer) -> Pair[Integer, Random.Generator]` | `low` 以上 `high` 未満の整数と、次の生成器 |
| `Random.nextFloat(generator)` | `function(Random.Generator) -> Pair[Float, Random.Generator]` | 0.0 以上 1.0 未満の浮動小数と、次の生成器 |
| `Random.shuffleWith(generator, xs)` | `function[T](Random.Generator, List[T]) -> Pair[List[T], Random.Generator]` | 要素を並べ替えたリストと、次の生成器 |

- `Random.integer` と `Random.nextInteger` は、`high` が `low` 以下なら実行時エラーとする。
- `Random.Generator` は中身を見せない型であり、等値の型ではない（[ADR 0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md)）。生成器の関数は、エフェクトを持たない純粋な関数であり、同じ生成器からは同じ値を返す。
- 生成器のアルゴリズムは、種を SplitMix64 で広げ、xoshiro256** で値を作るものとする。範囲の中の値への変換の手順も仕様で固定し、同じ種からは処理系の版によらず同じ列を作る（[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0172](../decisions/0172-random-conversion-procedure.md)）。手順は次のとおりである。以下の x は、xoshiro256** が次に返す 64 ビットの符号なしの値である。
  - 種は、64 ビットの 2 の補数として符号なしの値に読み替えて SplitMix64 に与え、SplitMix64 が続けて返す 4 個の値を xoshiro256** の状態とする。`Random.Generate` の隠れた生成器の種は、OS の乱数から得た 64 ビットの値である。
  - `low` 以上 `high` 未満の整数: 幅 n = high − low を符号なしの 64 ビットで求める。x が 2^64 − (2^64 mod n) 未満なら low + (x mod n) とし、そうでなければ次の x でやり直す。
  - 0.0 以上 1.0 未満の浮動小数: x を 11 ビット右にずらした値に 2^−53 を掛ける。
  - 真偽値: x の最上位のビットが 1 なら `true`。
  - 並べ替え（`Random.shuffle`・`Random.shuffleWith`）: 長さ m のリストについて、i を m − 1 から 1 まで減らしながら、0 以上 i + 1 未満の整数 j を上の手順で作り、位置 i と j の要素を入れ替える。
  - 要素の選択（`Random.choose`）: 0 以上 m 未満の整数を上の手順で作り、その位置の要素を返す。空のリストでは x を使わない。
- `Random.Generate` の操作（`Random.integer` など）は、実行の始めに OS の乱数で種を決めた、隠れた生成器を使う。テストでは、`Random.Generate` をハンドラで処理して値を固定できる（[エフェクト](../01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。

### IOErrorKind と関数の対応

【方針】各モジュールの関数が返しうる `IOErrorKind`（[エラー処理](../01-spec/01-09-errors.md)、[ADR 0144](../decisions/0144-ioerrorkind-constructors.md)）は、主に次のとおりである。`IOErrorKind.PermissionDenied` と `IOErrorKind.Other` は、どの関数も返しうる。

| `IOErrorKind` | 返す主な関数 |
|---|---|
| `NotFound` | パスを受け取る `File` の関数（`File.exists` を除く）、`Process.run`・`Process.runAttached`（コマンドが見つからない） |
| `AlreadyExists` | `File.createDirectory`（ファイルがある）、`File.rename` |
| `IsDirectory` | ファイルの内容を読み書きする `File` の関数と `File.copy`（パスがディレクトリを指す）、`File.rename`（`from` がファイルで、`to` がディレクトリ） |
| `NotDirectory` | `File.listDirectory`・`File.walk`・`File.removeTree`、途中の構成要素がファイルであるパス |
| `DirectoryNotEmpty` | `File.remove` |
| `InvalidUTF8` | テキストを読む関数、`Process.environmentVariable`、`Process.run`・`Process.shell` |
| `InvalidInput` | パスに NUL が含まれるなど、OS に渡せない引数 |

### 外部コマンドの起動とシェル

【方針】外部コマンドを起動する API と、文字列をシェルに解釈させる API を分ける（[設計メモ](../sources/fp-language-design.md) 16）。

- 外部コマンドの起動（`Process.run`・`Process.runAttached`）は、コマンドと引数の並び、作業ディレクトリ、環境変数を明示して、シェルを通さずに起動する。引数の単語分割やワイルドカードの展開は行わない。
- シェルによる実行（`Process.shell`）は、文字列をシステムのシェルに渡して解釈させる。実行する内容は実行時まで分からないので、エフェクトは `Process.Run` であるが、`Process.Run` とは別の、シェルによる実行の許可を要する（[エフェクト](../01-spec/01-07-effects.md)、[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。
- 【方針】POSIX sh との構文互換・意味論互換は目標としない。

起動したコマンドが中で行う操作は、処理系の検査の外にある（[セキュリティモデル](../07-quality/07-01-security-model.md)の「ハーネスとの分担」）。

### 大きなファイルを流す操作（初回リリース版の後）

初回リリース版の `File.copy` は、内容を一度 `Bytes` の値に読むので、1 GiB を超えるファイルを写せない（前述の「File」）。初回リリース版の後に、開いたリソースどうしを流す操作を加えて、この上限をなくす。

【決定】次の改造は初回リリース版に入れず、初回リリース（`0.0.1`）の後の版で行う（[ADR 0337](../decisions/0337-file-transfer-for-large-copies.md)）。

- `File.transfer(reader, writer)` を加える。`File.Reader` の残りをすべて `File.Writer` に書く。`File.Write` の操作であり、`File.Read` には属さない。読む権限と書く権限は、`File.openReader` と `File.openWriter` で開くときに確かめ済みなので、`File.transfer` は改めて権限を判定しない。処理系は、流す処理を IO 実行器の作業用のスレッドの中でまとめて行う。戻り値の型と流す単位の大きさは、この改造の実装プランで定める。
- `File.copy` を、`File.openReader` と `File.openWriter` で開き、`File.transfer` で流し、閉じる標準ライブラリのソースの関数に書き直す。写せるファイルの大きさの上限はなくなる。型は、解放のエフェクト `State` が加わり、`function(String, String) -> Result[Unit, IOError] uses File.Read, File.Write, State` となる。
- `File.copy` の型の変更は、`uses File.Read, File.Write` と細かく書いたスクリプトを型の誤りにする互換性を壊す変更なので、`CHANGELOG` に移行の手順を記録する（[ADR 0236](../decisions/0236-compatibility-during-0x.md)）。`uses IO.All` と書いたスクリプトは影響を受けない。
- `File.Read` を処理するハンドラは、`File.transfer` が行う読みを捕らえない。

【未決】同じ形を HTTP の応答の本体と外部コマンドの出力に広げるか、少しずつ計算するハッシュの関数を加えるか、`File.copy` が途中で失敗したときに書きかけのファイルを残さないか、OS の速いコピーの機能を使えるかは [OPEN-086](../open-issues.md#open-086) で決める。

### コマンドを代替する機能と外部コマンドの起動の拡張（初回リリース版の後）

初回リリース版の後に本章のモジュールへ加える機能は、コマンドを代替するライブラリの作り方（[ライブラリの構成](03-01-library-structure.md)の「コマンドを代替するライブラリの作り方（初回リリース版の後）」、[ADR 0336](../decisions/0336-command-substitute-library-policy.md)）に従う。

【未決】次の点は未決である。

- ディレクトリの複写と属性の引き継ぎ、glob、grep に当たる検索、原子的な書き換え、権限の属性の取得と設定、一時ファイル、ファイルシステムをまたぐ `File.rename` など、どの機能をどの順で加えるか（[OPEN-079](../open-issues.md#open-079)）。
- 外部コマンドに当たる操作を、標準ライブラリの関数、コマンドを包むライブラリ、`Process.run` の順で選ばせるか。選ばせるなら、同梱の Agent Skill の指示と、標準ライブラリに同じ操作があるコマンドを `Process.command` に定数で渡したときの警告のどちらで示すか（[OPEN-080](../open-issues.md#open-080)）。
- git を型の付いた関数として提供するか、提供するなら CLI を包むか、エフェクトをどう分けるか（[OPEN-082](../open-issues.md#open-082)）。
- `Process.Run` の許可の対象を、コマンドの名前から引数の先頭まで細かくするか（[OPEN-083](../open-issues.md#open-083)）。
- 裏で動かし続けて後で止めるプロセス、タスクを取り消したときに起動したコマンドを終わらせるか、出力をバイト列で受け取る `Process.run`（[OPEN-084](../open-issues.md#open-084)）。

### 秘密の情報の扱い（初回リリース版の後）

API キー・アクセス用のトークン・パスワードなどの秘密の情報（以下、秘密）を、スクリプトが受け取って外部コマンドや HTTP の要求に渡す場面がある（[秘密の情報の扱いの検討メモ](../sources/post-first-release/post-first-release-secrets.md)）。初回リリース版では、秘密は `Process.environmentVariable` や `Console.readLine` で読んだ `String` の値として扱うほかなく、`Process.run` で起動したコマンドはスクリプトの環境変数をすべて受け取る（前述の「Process」）。

【決定】初回リリース版の後に、主なパスワードマネージャ（Proton Pass、KeePass 系、1Password、Bitwarden）のラッパーを、公式のライブラリとして用意する（[ADR 0338](../decisions/0338-password-manager-wrappers-as-official-libraries.md)）。ラッパーは、コマンドを代替するライブラリの作り方（[ADR 0336](../decisions/0336-command-substitute-library-policy.md)）に従い、取り出す操作を型の付いた関数として表す。標準ライブラリに入れるか、公式の追加のライブラリとして配るかは、[OPEN-078](../open-issues.md#open-078) で決める。

【未決】次の点は未決である。

- 外部コマンドに渡す環境変数を、スクリプトの環境変数から切り離す方法。`Process.Command` に引き継ぐかを選ぶ欄（`inheritEnvironment` の案）を加えるか、そのとき `program` をどの `PATH` で探すか（[OPEN-087](../open-issues.md#open-087)）。
- 中身を見せない秘密の型と、秘密を外へ渡す受け取り口（外部コマンドの環境変数と標準入力、HTTP の要求のヘッダ）、秘密を扱うエフェクト（[OPEN-088](../open-issues.md#open-088)。[エフェクト](../01-spec/01-07-effects.md)の「秘密の値とエフェクト（初回リリース版の後）」）。
- 人間から秘密を受け取る経路。標準入力ではなく、制御端末、サーバモードの承認の画面、スタンドアロンモードの別の端末で開く入力の画面などで受け取る案がある（[OPEN-089](../open-issues.md#open-089)）。
- OS のキーストアから秘密を読む方法と、各パスワードマネージャのラッパーの作り方（錠の開け方、KeePass 系のデータベースのファイルを処理系が読むか）（[OPEN-090](../open-issues.md#open-090)）。

### 最小実行版との違い

最小実行版では、IO を行う関数（`Console.write`・`Console.writeLine`・`Console.writeErrorLine`・`File.readText`・`Process.arguments`）は prelude にあり、エフェクトは `IO` である。

## 未決事項

- [OPEN-046](../open-issues.md#open-046): プロパティベーステストと、入力の生成器の導出（乱数の種の固定）
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ネットワークの操作の対象の書き方と照合、テストの実行で与える許可）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-079](../open-issues.md#open-079): コマンドを代替する機能の範囲と優先度
- [OPEN-080](../open-issues.md#open-080): 外部コマンドを使う操作の選び方と、エージェントへの示し方
- [OPEN-082](../open-issues.md#open-082): git の提供のしかたと、エフェクトの分け方
- [OPEN-083](../open-issues.md#open-083): `Process.Run` の許可の対象を引数まで細かくするときの照合の規則
- [OPEN-084](../open-issues.md#open-084): 裏で動かすプロセスと、取り消しのときの子プロセスの扱い
- [OPEN-086](../open-issues.md#open-086): 開いたリソースへ流す操作の広げ方と、`File.copy` の細部
- [OPEN-087](../open-issues.md#open-087): 外部コマンドに渡す環境変数を、スクリプトの環境変数から切り離す方法
- [OPEN-088](../open-issues.md#open-088): 秘密の値の型と、秘密を扱うエフェクト
- [OPEN-089](../open-issues.md#open-089): 人間から秘密を受け取る経路
- [OPEN-090](../open-issues.md#open-090): OS のキーストアと、パスワードマネージャのラッパーの作り方
