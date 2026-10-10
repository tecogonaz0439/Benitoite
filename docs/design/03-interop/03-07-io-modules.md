# IO のモジュール

## 目的と範囲

`Benitoite.IO` の下の IO を行うモジュール（`Console`・`File`・`Process`・`Clock`・`Random`）の範囲、関数、エフェクトを定める。外部コマンドの起動とシェルによる実行の API もここで扱う。

ネットワークの操作を行うモジュールは `Benitoite.IO` の下に置かず、[ネットワークのモジュール](03-09-network.md)で定める。

初回リリース版では、本章のモジュールはどれも非公式のモジュールであり、`import Benitoite.Unofficial.IO.Console` の形で取り込む（[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）。本章は、モジュールの名前を `Unofficial` を挟まない名前（`Benitoite.IO.Console`）で書き、import の例は取り込みの名前で書く。取り込んだ後の書き方（`Console.writeLine`、`uses Console.Write`）は、取り込みの名前によらない。

## 前提

IO を行う関数の振る舞いと IO の失敗は[エフェクト](../01-spec/01-07-effects.md)で、リソースの型と `with` は[リソース管理](../01-spec/01-10-resources.md)で、タスクと時間の経過を待つことは[並行処理](../01-spec/01-11-concurrency.md)で定める。IO を行う組み込みの関数は、すべて IO 実行器を通す（[ライブラリの構成](03-01-library-structure.md)、[ランタイム](../02-impl/02-09-runtime.md)）。標準ライブラリの名前空間と prelude は[標準ライブラリ](03-06-stdlib.md)で定める。

## 仕様

### モジュールとエフェクト

【決定】IO を行う関数は、`Benitoite.IO` の下のモジュールに置く。各モジュールは組み込みのエフェクトを宣言し、IO の関数はそのエフェクトの操作である。ただし、リソースを解放する関数（`File.closeReader`・`File.closeWriter`）は、操作ではなく `State` を型に持つ組み込みの関数である。各関数の型と振る舞いは本章で定め、標準ライブラリのソースの関数とする `File.copy` と `Process.command` を除き、組み込みで実装する。IO が起きる時期と順序、IO の失敗の扱いは[エフェクト](../01-spec/01-07-effects.md)で、`Clock.sleep` がタスクを止める意味は[並行処理](../01-spec/01-11-concurrency.md)で定める。

| モジュール | エフェクト | 関数 |
|---|---|---|
| `Benitoite.IO.Console` | `Console.Write` | `Console.write`・`Console.writeLine`・`Console.writeError`・`Console.writeErrorLine` |
| 〃 | `Console.Read` | 標準入力を読む関数（後述の「各モジュールの範囲」） |
| `Benitoite.IO.File` | `File.Read` | パスを受け取って読む関数（後述の「File」） |
| 〃 | `File.Write` | パスを受け取って書く関数（後述の「File」） |
| `Benitoite.IO.Process` | `Process.Environment` | `Process.arguments`・`Process.scriptDirectory`・`Process.workingDirectory`・`Process.environmentVariable` |
| 〃 | `Process.Run` | `Process.run`・`Process.runAttached`・`Process.shell` |
| 〃 | `Process.Exit` | `Process.exit` |
| `Benitoite.IO.Clock` | `Clock.Time` | `Clock.sleep` と、時刻を読む関数 |
| `Benitoite.IO.Random` | `Random.Generate` | 乱数の関数（後述の「各モジュールの範囲」） |

初回リリース版は実行時の権限制御を持たず、本章のどの関数も、実行のときに許可を調べない（[エフェクト](../01-spec/01-07-effects.md)の「エフェクトの型と権限制御の区別」）。スクリプトは、処理系を起動した利用者の OS の権限で行える操作をすべて行える。

【方針】`IOError` と `IOErrorKind` は prelude の型であり、`IOError.message` は[エフェクト](../01-spec/01-07-effects.md)で定め、組み込みで実装する。IO の失敗は `Result.Error` で返す。`File.readText` は、ファイルの内容が正しい UTF-8 でなければ `Result.Error` を返す。

### 各モジュールの範囲

【方針】各モジュールには、次の機能を入れる。関数の一覧は後述の各節で定める。

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

- パスは `String` で表す。相対パスは、実行ごとの基準のディレクトリから辿る（[エフェクト](../01-spec/01-07-effects.md)）。基準のディレクトリは、CLI の `run` とテストの実行器では処理系を起動したときの作業ディレクトリである（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)）。パスの組み立ては `Benitoite.Path` の関数で行う。
- 外部の状態によって失敗しうる関数は `Result[T, IOError]` を返す。OS が操作を拒んだときは `IOErrorKind.PermissionDenied` を返す。
- テキストは UTF-8 で読み書きする。読んだ内容が正しい UTF-8 でなければ、`IOErrorKind.InvalidUTF8` の `Result.Error` を返す。
- 行に分けるときは、LF（U+000A）で区切り、各行の末尾に CR（U+000D）が一つあれば取り除く。最後の LF の後に文字が残れば、それも一つの行とする。行の値は、区切りの文字を含まない。この分け方は `String.lines`（[標準ライブラリ](03-06-stdlib.md)）と同じであり、内容全体を行に分ける関数（`File.readLines`・`Console.readAllLines`）にも、一行ずつ読む関数（`Console.readLine`・`File.readLine`）にも当てはまる。一行ずつ読む関数は、行の末尾の LF と、その直前にあれば CR を一つ取り除いた値を返す。LF のないまま入力の終わりに達したときは、残りの文字（末尾に CR が一つあれば取り除く）を一つの行として返し、次の呼び出しで `Option.None` を返す。
- 時間の長さは、ミリ秒を単位とする `Integer` で表す（`Clock.sleep`・`Task.withTimeout` と同じ。[並行処理](../01-spec/01-11-concurrency.md)）。
- ディレクトリの中の名前を並べる関数は、名前を UTF-8 のバイト列の辞書式の順に並べる。OS が返す順に依存しないので、同じ内容のディレクトリからは、同じ結果が得られる。

### Console

【方針】`Benitoite.IO.Console` の関数は次のとおりとする。

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
- テストの実行器での実行では、標準入力は空の入力である。`Console.readLine` は `Result.Ok(Option.None)` を、`Console.readAll` などは空の値を返す。標準出力と標準エラー出力に書いた内容は、テストごとに捕らえて結果に含める（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)）。

### File

【方針】`Benitoite.IO.File` のパスを受け取る関数は次のとおりとする。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `File.readText(path)` | `function(String) -> Result[String, IOError] uses File.Read` | ファイルの内容全体を文字列として読む |
| `File.readBytes(path)` | `function(String) -> Result[Bytes, IOError] uses File.Read` | ファイルの内容全体を、文字コードを解釈せずに読む |
| `File.readLines(path)` | `function(String) -> Result[List[String], IOError] uses File.Read` | ファイルの内容全体を読み、行に分ける |
| `File.exists(path)` | `function(String) -> Result[Boolean, IOError] uses File.Read` | パスが指すものがあるか。ないときだけ `false`。調べられないときは `Result.Error` |
| `File.info(path)` | `function(String) -> Result[File.Info, IOError] uses File.Read` | ファイルの情報。最後の構成要素がシンボリックリンクなら、リンクそのものの情報を返す |
| `File.listDirectory(path)` | `function(String) -> Result[List[String], IOError] uses File.Read` | ディレクトリの中の名前（パスではない）を並べたリスト。`.` と `..` を含まない。名前を UTF-8 のバイト列として比べた辞書式の順に並べる |
| `File.walk(path)` | `function(String) -> Result[List[String], IOError] uses File.Read` | ディレクトリの下のすべてのファイルとディレクトリを、`path` からの相対パスで並べたリスト。ディレクトリを指すシンボリックリンクの先は辿らない |
| `File.canonicalize(path)` | `function(String) -> Result[String, IOError] uses File.Read` | シンボリックリンクを解決した絶対パス |
| `File.writeText(path, text)` | `function(String, String) -> Result[Unit, IOError] uses File.Write` | ファイルを作るか置き換え、内容を `text` にする |
| `File.writeBytes(path, data)` | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | ファイルを作るか置き換え、内容を `data` にする |
| `File.appendText(path, text)` | `function(String, String) -> Result[Unit, IOError] uses File.Write` | ファイルの末尾に `text` を加える。ファイルがなければ作る |
| `File.appendBytes(path, data)` | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | ファイルの末尾に `data` を加える。ファイルがなければ作る |
| `File.createDirectory(path)` | `function(String) -> Result[Unit, IOError] uses File.Write` | ディレクトリを作る。途中のディレクトリがなければ作る。既にディレクトリがあれば何もしない |
| `File.remove(path)` | `function(String) -> Result[Unit, IOError] uses File.Write` | ファイル、シンボリックリンク、空のディレクトリを削除する |
| `File.removeTree(path)` | `function(String) -> Result[Unit, IOError] uses File.Write` | ディレクトリとその下をすべて削除する。シンボリックリンクの先は削除しない |
| `File.rename(from, to)` | `function(String, String) -> Result[Unit, IOError] uses File.Write` | `from` を `to` に移す。`to` にファイルがあれば置き換える |
| `File.copy(from, to)` | `function(String, String) -> Result[Unit, IOError] uses File.Read, File.Write` | 普通のファイル `from` の内容を `to` に写す。`to` があれば置き換える |

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
- 【方針】`File.copy` は、`File.readBytes` と `File.writeBytes` を呼ぶ標準ライブラリのソースの関数とする。内容を一度 `Bytes` の値に読むので、写せるファイルの大きさは 2^30 バイト（1 GiB）までである。これを超えるファイルでは、`File.readBytes` と同じく資源の不足として停止する（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。

【方針】ファイルを一行ずつ、または一定の大きさずつ読み書きするために、リソースの型 `File.Reader` と `File.Writer` を置く（[リソース管理](../01-spec/01-10-resources.md)）。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `File.openReader(path)` | `function(String) -> Result[File.Reader, IOError] uses File.Read` | ファイルを読むために開く |
| `File.readLine(reader)` | `function(File.Reader) -> Result[Option[String], IOError] uses File.Read` | 一行を読む。ファイルの終わりに達していれば `Option.None` |
| `File.readChunk(reader, maximumBytes)` | `function(File.Reader, Integer) -> Result[Option[Bytes], IOError] uses File.Read` | 最大 `maximumBytes` バイトを読む。ファイルの終わりに達していれば `Option.None` |
| `File.closeReader(reader)` | `function(File.Reader) -> Result[Unit, IOError] uses State` | 閉じる |
| `File.openWriter(path, mode)` | `function(String, File.WriteMode) -> Result[File.Writer, IOError] uses File.Write` | ファイルを書くために開く。`WriteMode.Replace` なら作るか空にし、`WriteMode.Append` なら末尾に加える |
| `File.write(writer, text)` | `function(File.Writer, String) -> Result[Unit, IOError] uses File.Write` | `text` を書く |
| `File.writeLine(writer, text)` | `function(File.Writer, String) -> Result[Unit, IOError] uses File.Write` | `text` と LF を書く |
| `File.writeChunk(writer, data)` | `function(File.Writer, Bytes) -> Result[Unit, IOError] uses File.Write` | `data` を書く |
| `File.closeWriter(writer)` | `function(File.Writer) -> Result[Unit, IOError] uses State` | 書いた内容を書き出してから閉じる |

```text
data WriteMode
  Replace
  Append
end data
```

- `with` で束縛したときの解放は、`File.Reader` では `File.closeReader`、`File.Writer` では `File.closeWriter` と同じ処理である。`File.closeReader` と `File.closeWriter` は、`File.Read`・`File.Write` の操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。解放のエフェクトは `State` である（[リソース管理](../01-spec/01-10-resources.md)）。
- 解放した後の `File.Reader` と `File.Writer` に対する操作は、実行時エラー（解放したリソースの使用）とする（[リソース管理](../01-spec/01-10-resources.md)の「解放したリソースの使用」）。
- `File.readChunk` の `maximumBytes` が 1 未満なら、実行時エラーとする。

```text
import Benitoite.Unofficial.IO.File

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

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Process.arguments()` | `function() -> List[String] uses Process.Environment` | コマンドライン引数の並び（[エフェクト](../01-spec/01-07-effects.md)） |
| `Process.scriptDirectory()` | `function() -> String uses Process.Environment` | 実行を始めるスクリプトのディレクトリの絶対パス |
| `Process.environmentVariable(name)` | `function(String) -> Result[Option[String], IOError] uses Process.Environment` | 環境変数の値。定義されていなければ `Option.None` |
| `Process.workingDirectory()` | `function() -> Result[String, IOError] uses Process.Environment` | 作業ディレクトリの絶対パス |
| `Process.command(program, arguments)` | `function(String, List[String]) -> Process.Command` | 後述の既定の値を入れた `Process.Command` を作る。純粋な関数である |
| `Process.run(command)` | `function(Process.Command) -> Result[Process.Output, IOError] uses Process.Run` | コマンドを起動し、終わるのを待ち、標準出力と標準エラー出力を集めて返す |
| `Process.runAttached(command)` | `function(Process.Command) -> Result[Integer, IOError] uses Process.Run` | コマンドを起動し、標準入力・標準出力・標準エラー出力をスクリプトのものにつないで、終わるのを待つ。終了状態を返す |
| `Process.shell(commandLine)` | `function(String) -> Result[Process.Output, IOError] uses Process.Run` | 文字列をシェルに渡して実行し、`Process.run` と同じく結果を返す |
| `Process.exit(code)` | `function[T](Integer) -> T uses Process.Exit` | 終了状態を `code` にして実行を終える。呼び出し元へは戻らない |

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
- `program` が `/` を含む相対パス（`./tool` など）のときは、子の作業ディレクトリ（`workingDirectory` を解決したもの。`Option.None` なら基準のディレクトリ）から辿って絶対パスにしてから起動する。シェルで `cd dir && ./tool` と書いたときと同じ場所のファイルを起動する。`/` を含まない名前は、環境変数 `PATH` から探す。
- `environment` の組は、スクリプトの環境変数に加えるか、同じ名前の変数を置き換える。起動したコマンドは、スクリプトの環境変数をすべて受け取る。初回リリース版は、子に渡す環境変数をスクリプトのものから切り離す方法と、API キーやパスワードなどの秘密の情報を区別して扱う型を持たない。
- 起動するコマンドが見つからなければ `IOErrorKind.NotFound` を返す。コマンドが 0 以外の終了状態で終わっても、`Result.Ok` を返す。終了状態は `exitCode` で調べる。
- `Process.run`・`Process.shell` で、集めた出力が正しい UTF-8 でなければ、`IOErrorKind.InvalidUTF8` を返す。
- 【決定】`Process.run`・`Process.runAttached` で `input` に `Option.Some` を指定したとき、子が入力を読み切らずに終わり、子の標準入力への書き込みが失敗しても（読み手のいないパイプへの書き込み。Rust の `std::io::ErrorKind::BrokenPipe`）、誤りにしない。書けた分で入力を終えたものとし、子の終了状態と集めた出力を `Result.Ok` で返す。
- 【決定】シグナルで終わったコマンドの `exitCode` は、Unix では 128 にシグナルの番号を足した値とする。POSIX のシェルがシグナルで終わったコマンドに与える終了状態と同じ形である。Rust の標準ライブラリはこのとき終了コードを返さない（`ExitStatus::code()` が `None`）ので、処理系はシグナルの番号（`ExitStatusExt::signal()`）から計算する。
- 【決定】`Process.shell` は、Unix では `/bin/sh -c` で文字列を実行する。`/bin/sh` の実装は OS と設定によって違う。macOS の `/bin/sh` は、設定によって bash・dash・zsh のどれかとして動き、Debian の `/bin/sh` は dash である。そのため、`Process.shell` に渡す文字列は POSIX の sh の範囲で書く必要がある。同梱の Agent Skill は、そのように書くようエージェントに指示する（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)）。
- `Process.exit` の `code` は 0 以上 255 以下でなければならず、範囲の外なら実行時エラーとする。終える前に、開いている `with` のリソースを解放し（[リソース管理](../01-spec/01-10-resources.md)）、出力を書き出す。
- CLI の `run` では、`Process.exit` は処理系のプロセスを終える。テストの実行器では、処理系のプロセスを終えず、その実行だけを終え、そのテストを失敗として報告する（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)）。
- `Process.runAttached` で起動したコマンドの標準入出力は、スクリプトの標準入出力と同じつなぎ先につなぐ。テストの実行器では、空の入力と、その実行の出力の受け取り先である。ただし、`input` に `Option.Some` を指定した `Process.Command` では、指定した文字列を子の標準入力にする。標準出力と標準エラー出力は、`input` の指定にかかわらずスクリプトと同じつなぎ先につなぐ。
- テストの実行器の `Process.runAttached` では、処理系が子の標準出力と標準エラー出力を集め、子が終わった後に、その実行の出力の受け取り先へ書く。集めた出力が正しい UTF-8 でなければ、壊れたバイトの並びを置換文字 U+FFFD に置き換えて書き、`IOErrorKind.InvalidUTF8` は返さない。集める出力の大きさには `Process.run`・`Process.shell` と同じ上限を当て、標準出力と標準エラー出力のどちらかが 2^30 バイトを超えたら、資源の不足として停止する（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。

### Clock

【方針】`Benitoite.IO.Clock` の関数は次のとおりとする。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Clock.now()` | `function() -> Time.Instant uses Clock.Time` | 現在の時刻。精度はミリ秒であり、`unixNanoseconds` の下 6 桁は 0 である |
| `Clock.localOffsetMinutes()` | `function() -> Integer uses Clock.Time` | 現在の時刻での、地方時の UTC からの差（東を正とする分の数） |
| `Clock.monotonicMilliseconds()` | `function() -> Integer uses Clock.Time` | 経過時間を計るための値。起点は定めず、一回の実行の中で減らない |
| `Clock.sleep(milliseconds)` | `function(Integer) -> Unit uses Clock.Time` | 呼び出したタスクを止める（[並行処理](../01-spec/01-11-concurrency.md)） |

- `Time.Instant` は `Benitoite.Time` の型である（[テキストとデータの処理](03-08-text-and-data.md)）。
- OS から地方時の UTC からの差を得られないとき（タイムゾーンの設定を持たない最小のコンテナなど）、`Clock.localOffsetMinutes` は 0 を返す。実行時エラーにも `IOError` にもしない。
- 経過時間は、`Clock.monotonicMilliseconds` の二つの値の差で計る。`Clock.now` は、OS の時計が調整されると戻ることがあるので、経過時間の計測には使わない。

### Random

【方針】`Benitoite.IO.Random` の関数は次のとおりとする。

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
- `Random.Generator` は中身を見せない型であり、等値の型ではない。生成器の関数は、エフェクトを持たない純粋な関数であり、同じ生成器からは同じ値を返す。
- 生成器のアルゴリズムは、種を SplitMix64 で広げ、xoshiro256** で値を作るものとする。範囲の中の値への変換の手順も仕様で固定し、同じ種からは処理系の版によらず同じ列を作る。手順は次のとおりである。以下の x は、xoshiro256** が次に返す 64 ビットの符号なしの値である。
  - 種は、64 ビットの 2 の補数として符号なしの値に読み替えて SplitMix64 に与え、SplitMix64 が続けて返す 4 個の値を xoshiro256** の状態とする。`Random.Generate` の隠れた生成器の種は、OS の乱数から得た 64 ビットの値である。
  - `low` 以上 `high` 未満の整数: 幅 n = high − low を符号なしの 64 ビットで求める。x が 2^64 − (2^64 mod n) 未満なら low + (x mod n) とし、そうでなければ次の x でやり直す。
  - 0.0 以上 1.0 未満の浮動小数: x を 11 ビット右にずらした値に 2^−53 を掛ける。
  - 真偽値: x の最上位のビットが 1 なら `true`。
  - 並べ替え（`Random.shuffle`・`Random.shuffleWith`）: 長さ m のリストについて、i を m − 1 から 1 まで減らしながら、0 以上 i + 1 未満の整数 j を上の手順で作り、位置 i と j の要素を入れ替える。
  - 要素の選択（`Random.choose`）: 0 以上 m 未満の整数を上の手順で作り、その位置の要素を返す。空のリストでは x を使わない。
- `Random.Generate` の操作（`Random.integer` など）は、実行の始めに OS の乱数で種を決めた、隠れた生成器を使う。テストでは、`Random.Generate` をハンドラで処理して値を固定できる（[エフェクト](../01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。

### IOErrorKind と関数の対応

【方針】各モジュールの関数が返しうる `IOErrorKind`（[エラー処理](../01-spec/01-09-errors.md)）は、主に次のとおりである。`IOErrorKind.PermissionDenied` と `IOErrorKind.Other` は、どの関数も返しうる。

| `IOErrorKind` | 返す主な関数 |
|---|---|
| `NotFound` | パスを受け取る `File` の関数（`File.exists` を除く）、`Process.run`・`Process.runAttached`（コマンドが見つからない） |
| `AlreadyExists` | `File.createDirectory`（ファイルがある） |
| `IsDirectory` | ファイルの内容を読み書きする `File` の関数と `File.copy`（パスがディレクトリを指す）、`File.rename`（`from` がファイルで、`to` がディレクトリ） |
| `NotDirectory` | `File.listDirectory`・`File.walk`・`File.removeTree`、途中の構成要素がファイルであるパス |
| `DirectoryNotEmpty` | `File.remove` |
| `InvalidUTF8` | テキストを読む関数、`Process.environmentVariable`、`Process.workingDirectory`、`Process.run`・`Process.shell`、名前やパスを返す `File` の関数（`File.listDirectory`・`File.walk`・`File.canonicalize`。返す名前やパスが正しい UTF-8 でない） |
| `InvalidInput` | パスに NUL が含まれるなど、OS に渡せない引数 |

### 外部コマンドの起動とシェル

【方針】外部コマンドを起動する API と、文字列をシェルに解釈させる API を分ける。

- 外部コマンドの起動（`Process.run`・`Process.runAttached`）は、コマンドと引数の並び、作業ディレクトリ、環境変数を明示して、シェルを通さずに起動する。引数の単語分割やワイルドカードの展開は行わない。
- シェルによる実行（`Process.shell`）は、文字列をシステムのシェルに渡して解釈させる。エフェクトは `Process.Run` である。実行する内容は実行時まで分からず、型からは何を実行するかを読み取れない。
- 【方針】POSIX sh との構文互換・意味論互換は目標としない。

起動したコマンドが中で行う操作は、処理系の検査の外にある（[セキュリティモデル](../07-quality/07-01-security-model.md)の「ハーネスとの分担」）。

