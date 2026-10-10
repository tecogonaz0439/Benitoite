# エフェクト

## 目的と範囲

エフェクトの注釈（`uses`）と検査、組み込みのエフェクト、利用者が定義するエフェクトとハンドラを定める。対象は、組み込みのエフェクトとその置き場所、IO が起きる時期と順序、IO の失敗の扱い、プログラムの入口 `main`、IO を行う組み込み関数、可変のセル、影響の大きい操作、利用者が定義するエフェクトとハンドラである。初回リリース版は実行時の権限制御を持たない（後述の「エフェクトの型と権限制御の区別」）。

## 前提

`uses` の構文は[構文](01-02-syntax.md)で定める。関数の型が持つエフェクトの集合、式のエフェクト、関数の本体のエフェクトの検査、エフェクト変数とエフェクトの包含は[型システム](01-06-type-system.md)で定める。本章は、型システムが検査するエフェクトの名前が、実行のときに何を意味するかと、ハンドラの意味を定める。ハンドラの構文は[構文](01-02-syntax.md)で、型付けは[型システム](01-06-type-system.md)で、厳密な意味は[コア計算と脱糖](01-12-core-calculus.md)で定める。

式の評価順序と、実行時エラーが起きたときにプログラムがどう停止するかは[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### エフェクトの型と権限制御の区別

【方針】エフェクトの型は、関数を呼んだときにどの種類の操作が起こりうるかを、実行の前に検査するための情報である。実行のときに、どの操作を許すかを決める権限制御とは別の機構である。

初回リリース版の処理系は、実行時の権限制御を持たず、エフェクトの型による静的な検査だけを保証する。スクリプトは、処理系を起動した利用者の OS の権限で行える操作をすべて行える。保証の範囲は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

### 組み込みのエフェクト

【決定】外部に作用する操作と可変のセルの操作を、細かい組み込みのエフェクトに分ける。理由: ハンドラで組み込みの操作をテストのために差し替えるには、差し替える操作の単位がエフェクトとして型に現れている必要がある。また、関数の型から、ファイルを読むだけか外部コマンドを起動しうるかを読み取れるようにする。

【決定】エフェクトは、モジュールの中で宣言するものであり、ほかのモジュールからはモジュールの名前で修飾して書く。組み込みのエフェクトは、標準ライブラリの次のモジュールの中で宣言する。IO を行うモジュールは `Benitoite.IO` の下に、ネットワークの操作を行うモジュールは `Benitoite.Network` の下にあり、どちらも import しなければ使えない。

| モジュール | エフェクト | 表す操作 |
|---|---|---|
| `Benitoite.IO.Console` | `Console.Write` | 標準出力と標準エラー出力への書き込み |
| 〃 | `Console.Read` | 標準入力の読み取り |
| `Benitoite.IO.File` | `File.Read` | ファイルとディレクトリの読み取り |
| 〃 | `File.Write` | ファイルとディレクトリの作成・書き込み・削除・移動 |
| `Benitoite.IO.Process` | `Process.Run` | 外部コマンドの起動と、シェルによるコマンドの実行 |
| 〃 | `Process.Exit` | 終了状態を指定したプロセスの終了 |
| 〃 | `Process.Environment` | コマンドライン引数・環境変数・作業ディレクトリ・実行を始めるスクリプトのディレクトリの読み取り |
| `Benitoite.IO.Clock` | `Clock.Time` | 時刻の読み取りと、時間の経過を待つこと |
| `Benitoite.IO.Random` | `Random.Generate` | 乱数の生成 |
| `Benitoite.Network.Http` | `Http.Listen` | HTTP の接続の待ち受け、要求の受け付けと応答 |
| 〃 | `Http.Connect` | HTTP のサーバへの接続と、要求の送信 |
| `Benitoite`（prelude） | `State` | 可変のセル（後述の「可変のセル（初回リリース版）」）とタスクの集まりの操作、タスクの結果を待つこと（`Task.await`。[並行処理](01-11-concurrency.md)） |

表のエフェクトの名前は、各モジュールを最後の要素の名前で取り込んだときの書き方である（`import Benitoite.Unofficial.IO.Console` の後の `uses Console.Write`）。`as` で別の名前を付けて取り込んだときは、その名前で修飾する（[名前・スコープ・モジュール](01-03-names-modules.md)）。取り込みは、そのモジュールのエフェクトを `uses` に書くためにも要る。

【決定】各モジュールの IO の関数は、そのモジュールのエフェクトの操作である（`Console.writeLine` は `Console.Write` の操作）。ハンドラで処理でき、どのハンドラも処理しなければ処理系が実際に行う（後述の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。`State` は操作を持たないエフェクトであり、ハンドラで処理できない。`Reference` と `TaskGroup` の関数、`Task.await`、リソースを解放する関数（`File.closeReader` など。[リソース管理](01-10-resources.md)）は、`State` を型に持つ組み込みの関数である。

【決定】prelude のモジュール `IO`（`Benitoite.IO`）が宣言するエフェクトは、`All` だけである。`All` は、prelude の `State` と、`Benitoite.IO` の下のモジュールが宣言するすべての組み込みのエフェクトをまとめたエフェクトである。`uses IO.All` は、まとめたエフェクトをすべて `uses` に書いたのと同じ意味である。`IO.All` を書くのに import は要らない。以下、本章で「IO」と書くときは、`IO.All` に含まれるエフェクトの操作を指す。

【決定】`Benitoite.Network` の下のモジュールのエフェクト（ネットワークのエフェクト）は、`IO.All` に含めない。理由: ネットワークの操作は、スクリプトを動かす機械の外の資源に触れ、機械の中の操作（コンソール、ファイル、プロセス、環境変数、時計、乱数）とは影響の及ぶ範囲が異なる。ネットワークのエフェクトも組み込みのエフェクトであり、その操作（ネットワークの操作）は、IO と同じくハンドラで処理できる。IO とネットワークの両方を使う関数は、`uses IO.All, Http.Connect` のように書く。ネットワークのエフェクトをまとめたエフェクトは、初回リリース版にはない。IO とネットワークの操作を合わせて、外部に作用する操作と呼ぶ。

【決定】`IO` はエフェクトではなく、prelude のモジュールの名前である。`uses IO` と書くと誤りになる。診断は、`uses IO.All` を修正案として示す。

【決定】テストの期待の確認を表す組み込みのエフェクト `Assert.Check` は、prelude のモジュール `Assert` の中で宣言し、`IO.All` に含めない。操作は[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める。

【決定】処理系は、組み込みのモジュールとエフェクトを、綴りではなく、`Benitoite` の名前空間のどの名前かで照合する。利用者のモジュールが、組み込みと同じ綴りの名前のエフェクトを宣言しても、組み込みのエフェクトとして扱わない。

【方針】標準ライブラリの各関数は、行う操作に当たるエフェクトだけを型に持つ。`uses IO.All` と書いた関数の本体が、`IO.All` の一部のエフェクトしか生じないときは、処理系は警告で、本体が生じるエフェクトの集合を示す。

次のものは、どのエフェクトにも含めない。

- 実行時エラー（整数の溢れ、0 による除算など）。実行時エラーを起こしうることは、型にもエフェクトにも表さない（[エラー処理](01-09-errors.md)）。
- 停止しないこと。
- メモリなど、処理系の資源を使い果たすこと。

可変のセルの操作も `State` エフェクトを持つので、純粋な関数（[型システム](01-06-type-system.md)）の結果は引数だけで決まる。資源の不足（[評価意味論](01-08-evaluation.md)）を除けば、同じ引数で二度呼んだとき、どちらも値を返したなら同じ値を返す。どちらかが実行時エラーで止まるとき、どの実行時エラーで止まるかは、関数の中で `Task.all`・`Task.allOk` が起動したタスクの切り替えの順序に依存しうる（[並行処理](01-11-concurrency.md)）。

### IO が起きる時期と順序

【決定】IO は、IO を行う関数の呼び出しを評価したときに起こる。IO の計算を値として構築する型（`IO[T]` など）はない。外部に作用する関数も、普通の関数として呼ぶ。

【方針】IO が起きる時期と順序について、次の規則を定める。

- 一つの呼び出しを評価するたびに、その関数の IO が一度起こる。
- ラムダの式を評価しても、本体の IO は起こらない。本体の IO は、そのラムダを呼び出したときに起こる。
- 複数の IO は、それを含む式を評価する順に起こる。評価の順序は[評価意味論](01-08-evaluation.md)で定める。

ネットワークの操作も、IO と同じく、関数の呼び出しを評価したときに起こり、本節の規則に従う。

【方針】標準出力と標準エラー出力のそれぞれで、書き込んだ内容は書き込みの呼び出しの順に現れる。標準出力と標準エラー出力の間で、現れる順序が呼び出しの順と一致することは保証しない。プログラムが正常に終わる場合、`main` が `Result.Error` を返した場合、実行時エラーで停止する場合、資源の不足で停止する場合は、それまでに書き込んだ内容を、終了の前にすべて出力しなければならない。ただし、書き込みそのものが失敗した場合（次節）と、処理系が上限を設けていない資源が実行環境で尽きた場合（[評価意味論](01-08-evaluation.md)の「資源の不足」）は、書き込んだ内容の一部が出力されないことがある。

### IO の失敗

【決定】外部の状態によって失敗しうる IO の関数は、`Result[T, IOError]` を返す。ネットワークの関数は、`IOError` ではなく `NetworkError` を返す（[エラー処理](01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」）。`IOError` は、構成子を公開しない prelude の型である。`IOError` の値はパターンで分解できない。

【決定】`IOError` は中身を見せない prelude の型であり、基本型にも代数的データ型にも含めない。`IOError` とそれを含む型（`Result[String, IOError]` など）は等値の型ではなく、`=` と `<>` で比べられない（[型システム](01-06-type-system.md)の「等値の型」）。理由: `IOError` の値が等しいとはどういうことかが定まらない。失敗の種類を調べるには、`IOError.kind` で種類を取り出すか、`IOError.message` で文字列にするか、`match` で `Result.Ok` と `Result.Error` を分ける。

【方針】`IOError` に対して、次の関数を定める。

| 関数 | 型 | 値 |
|---|---|---|
| `IOError.message(e)` | `function(IOError) -> String` | 失敗の理由を、人間が読める形で表す文字列 |

`message` の文字列の具体的な文面は定めない。文面は処理系の版によって変わりうるので、失敗の種類を判定する手段にはならない。失敗の種類は `IOError.kind` で取り出す（[エラー処理](01-09-errors.md)）。

【方針】標準出力と標準エラー出力への書き込みが失敗したときは、実行時エラー（書き込みの失敗）とする。書き込みの関数は `Result` を返さない。

【決定】書き込みの失敗は、書き込みの関数を呼び出した時点ではなく、後で検出してよい。理由: 処理系は書き込みをバッファに溜めてまとめて書き出すので、失敗は書き出すときまで分からない。処理系は、失敗を検出した時点で、書き込みの失敗による実行時エラーとして停止する。この報告は、ソース上の位置を持たない。失敗を検出するまでに行った評価と IO は取り消さない。処理系は、失敗を遅くともプログラムを終える前の書き出しで検出する。書き出す時期は処理系の設計（[ランタイム](../02-impl/02-09-runtime.md)）で定める。停止の手順は[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」で定める。

`Result.Error` は、`match`、`Result` を扱う prelude の関数、または `Result.Error` をそのまま呼び出し元へ返す前置の `try`（[エラー処理](01-09-errors.md)）で扱う。

### 外部から受け取る文字列

【決定】外部のバイト列を `String` として受け取る操作は、正しくない UTF-8 のバイト列を置き換えたり捨てたりしない。ファイルの内容が正しい UTF-8 でなければ、`File.readText` は `Result.Error` を返す。コマンドライン引数の扱いは次節で定める。

### プログラムの入口

【決定】プログラムの入口は、実行を始めるモジュール（[名前・スコープ・モジュール](01-03-names-modules.md)）の、引数を取らないトップレベルの関数 `main` である。`main` の戻り値の型は `Unit` か `Result[Unit, String]` である。

【方針】`main` は、加えて次の条件を満たさなければならない。

- 型パラメータとエフェクト変数を持たない。
- エフェクトは、`IO.All` に含まれる組み込みのエフェクトと、ネットワークのエフェクトの任意の集まりである（`uses IO.All` のほか、`uses File.Read, Console.Write` や `uses IO.All, Http.Listen` なども書ける。`uses` を書かなくてもよい）。利用者が定義するエフェクトは、`main` の中で処理しなければならない。`Assert.Check` は含められない。

`main` がないとき、または `main` が上の条件を満たさないときは、型検査の誤りとする。

次の例は、`main` の形と、`Result.Error` を返して失敗を伝える書き方を示す。例は import を省き、エフェクトを `uses IO` と書いているので、このままでは誤りになる。実際のスクリプトでは、`Console` と `File` のモジュールを import し、`uses IO` を `uses IO.All`（または `uses File.Read, Console.Write`）と書く。

```text
function main() -> Result[Unit, String] uses IO
  return match File.readText("input.txt") with
    case Result.Ok(text) ->
      Console.writeLine(Integer.toString(List.length(String.lines(text))))
      Result.Ok(())
    case Result.Error(e) -> Result.Error(IOError.message(e))
  end match
end function
```

【方針】処理系は、プログラムを実行するときに次の順で処理する。

1. コマンドライン引数を検査する。どれかが正しい UTF-8 でなければ、その引数の位置を示す診断を出し、`main` を呼ばずに失敗を表す終了状態で終わる。
2. `main` を一度呼び出す。
3. `main` の戻り値によって終わる。

| `main` の終わり方 | 処理系の振る舞い |
|---|---|
| `()` を返す | 成功を表す終了状態で終わる |
| `Result.Ok(())` を返す | 成功を表す終了状態で終わる |
| `Result.Error(msg)` を返す | `msg` と改行を標準エラー出力に書き、失敗を表す終了状態で終わる |
| 実行時エラーまたは資源の不足で停止する | [評価意味論](01-08-evaluation.md)で定める |

終了状態の具体的な値と、スクリプトにコマンドライン引数を渡す方法は [CLI](../06-tooling/06-01-cli.md) で定める。

### IO を行う組み込み関数

【方針】基本の IO を行う関数として、次のものを定める。これらの関数は `Benitoite.IO` の下のモジュールの関数であり、import しなければ使えない。各関数は、型の `uses` に書いたエフェクトの操作である。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Console.write(s)` | `function(String) -> Unit uses Console.Write` | `s` を標準出力に書く |
| `Console.writeLine(s)` | `function(String) -> Unit uses Console.Write` | `s` と改行を標準出力に書く |
| `Console.writeErrorLine(s)` | `function(String) -> Unit uses Console.Write` | `s` と改行を標準エラー出力に書く |
| `File.readText(path)` | `function(String) -> Result[String, IOError] uses File.Read` | `path` のファイルの内容全体を UTF-8 の文字列として読む |
| `Process.arguments()` | `function() -> List[String] uses Process.Environment` | コマンドライン引数の並びを返す |

- 改行は U+000A 一文字である。
- `File.readText` は、ファイルが存在しない、読む権限がない、ディレクトリである、内容が正しい UTF-8 でない、などの場合に `Result.Error` を返す。相対パスは、処理系を起動したときの作業ディレクトリを基準にする。内容の先頭の BOM（U+FEFF）は取り除かない。
- `Process.arguments()` の並びには、スクリプトのファイルのパスを含めない。スクリプトに渡した引数だけを、渡した順に含む。

【決定】処理系のプロセスの中で複数の実行を行うとき（テストの実行器）は、実行ごとに与える基準のディレクトリを、その実行の作業ディレクトリとして扱う。本章と[IO のモジュール](../03-interop/03-07-io-modules.md)の「処理系を起動したときの作業ディレクトリ」は、この場合は基準のディレクトリと読み替える。`Process.workingDirectory` も基準のディレクトリを返す。

【決定】`Benitoite.IO.Process` は、実行を始めるスクリプトのディレクトリを返す関数を持つ。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Process.scriptDirectory()` | `function() -> String uses Process.Environment` | 実行を始めるスクリプトのファイルがあるディレクトリの絶対パスを返す |

- 返すパスは、シンボリックリンクを解決した絶対パスである。処理系を起動したときの作業ディレクトリには依存しない。
- スクリプトと一緒に置いたファイルは、このパスから作ったパスで操作する。

【方針】バイト列（[標準ライブラリ](../03-interop/03-06-stdlib.md)の `Bytes`）を読み書きする次の関数を定める。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `File.readBytes(path)` | `function(String) -> Result[Bytes, IOError] uses File.Read` | `path` のファイルの内容全体を、文字コードを解釈せずにバイト列として読む |
| `File.writeBytes(path, data)` | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | `path` のファイルを作るか置き換え、内容を `data` にする |

- `File.readBytes` の失敗は、内容の文字コードを除き、`File.readText` と同じである。

IO のモジュールの関数（標準入力の読み取り、ファイルとディレクトリの操作、ファイルのリソースの型、環境変数、外部コマンドの起動、時刻、乱数など）の一覧は、[IO のモジュール](../03-interop/03-07-io-modules.md)で定める。本節の表の関数も、同章の一覧に含める。

### 可変のセル（初回リリース版）

【方針】prelude は、可変のセル `Reference[T]` を扱う関数として次のものを定める。セルの操作のエフェクトは、prelude で宣言した `State` である。これらの関数はエフェクトの操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Reference.new(v)` | `function[T](T) -> Reference[T] uses State` | `v` を入れた新しいセルを作る |
| `Reference.get(r)` | `function[T](Reference[T]) -> T uses State` | `r` に入っている値を返す |
| `Reference.set(r, v)` | `function[T](Reference[T], T) -> Unit uses State` | `r` に入っている値を `v` に変える |
| `Reference.update(r, f)` | `function[T](Reference[T], function(T) -> T) -> Unit uses State` | `r` に入っている値を、それに `f` を適用した値に変える。`f` はエフェクトを持たない |

- セルは値として渡せる。同じセルを指す値はどれも同じセルを指し、一方から書き換えた値は、他方から読んでも見える。
- `Reference.get` は、それまでに最後に `Reference.set` で書いた値（書いていなければ `Reference.new` に渡した値）を返す。
- セルの操作は外部の状態を読み書きしないので、IO の失敗は起きない。
- セルは、並行に進むタスクの間で共有してよい。セルの一つの操作は、ほかのタスクの操作と混ざらない。`Reference.update` の読み出しから書き込みまでの間に、ほかのタスクがそのセルを操作することはない（[並行処理](01-11-concurrency.md)）。
- 可変状態のための型付けの規則（value restriction など）は設けない。局所の束縛は多相にならず、トップレベルに置ける値は定数式の定数に限り、定数は型パラメータを持たず `Reference.new` を呼べないので、セルを多相な名前に束縛する手段がないからである（[型システム](01-06-type-system.md)の「可変状態（初回リリース版）」）。

```text
function countNonEmpty(lines: List[String]) -> Integer uses State
  bind n <- Reference.new(0)
  List.forEach(lines, lambda(line)
    if String.trim(line) <> "" then Reference.set(n, Reference.get(n) + 1) end if
  end lambda)
  return Reference.get(n)
end function
```

### 影響の大きい操作（初回リリース版）

【決定】外部コマンドの起動、終了状態を指定したプロセスの終了、ファイルの書き込みは、それぞれ `Process.Run`・`Process.Exit`・`File.Write` のエフェクトを持つ関数で行う。関数の型のエフェクトにこれらを含まない関数は、これらの操作を行わない。これらの関数は、許可を表す値を引数にとらず、`main` も引数をとらない。理由: 許可を値で渡すと、値をラムダに捕捉できるので、関数の型からその操作を行いうるかが分からない。エフェクトで表せば型から読み取れ、テストではハンドラで差し替えられる。保証の範囲は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

【方針】影響の大きい操作の規則は次のとおりである。

- 外部コマンドの起動の関数（`Process.run` など）とシェルによる実行の関数（`Process.shell`）は、`Benitoite.IO.Process` に置く。名前と型は[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」で定める。
- 終了状態を指定してプロセスを終える関数 `Process.exit` は、`Benitoite.IO.Process` に置く。型は[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」で定める。この関数は、評価をやめ、すべてのタスク（[並行処理](01-11-concurrency.md)）で開いている `with` のリソースを内側のスコープから順に解放し（[リソース管理](01-10-resources.md)）、出力をすべて書き出してから、指定した終了状態で終わる。解放が失敗したときは、その失敗を標準エラー出力に報告し（解放の失敗を実行時エラーにしないリソースの型を除く。[リソース管理](01-10-resources.md)の「解放の失敗」）、終了状態は指定したものから変えない。出力の書き出しが失敗したときも、同じく報告し、終了状態は変えない。

```text
import Benitoite.Unofficial.IO.Process

function tagRelease(tag: String) -> Result[Unit, String] uses Process.Run
  bind output <- try Process.run(Process.command("git", ["tag", tag])) |> Result.mapError(_, IOError.message)
  return if Process.Output.exitCode(output) = 0 then Result.Ok(()) else Result.Error(Process.Output.standardError(output)) end if
end function

function main() -> Result[Unit, String] uses Process.Run
  return tagRelease("v1.0")
end function
```

`Process.run` は、コマンドが 0 以外の終了状態で終わっても `Result.Ok` を返すので、この例は終了状態を調べて失敗を `Result.Error` にする（[IO のモジュール](../03-interop/03-07-io-modules.md)）。

### 利用者が定義するエフェクトとハンドラ（初回リリース版）

【決定】利用者がエフェクトを宣言し、ハンドラでその操作を処理できる。エフェクトはモジュールの中で宣言し、その操作は、エフェクトを宣言したモジュールの関数である。構文は[構文](01-02-syntax.md)の「エフェクトの宣言とハンドラ（初回リリース版）」で定める。

次の例は、一つのファイルの中でエフェクト `Log` を宣言して使う。同じモジュールの中では、エフェクトを `Log`、操作を `write` と修飾せずに書く。

```text
import Benitoite.Unofficial.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function process(items: List[String]) -> Integer uses Log
  List.forEach(items, lambda(item) write("item: " + item) end lambda)
  return List.length(items)
end function

function main() -> Unit uses Console.Write
  bind count <- handle
    process(["a", "b"])
  with
    case write(message) ->
      Console.writeLine(message)
      resume(())
  end handle
  Console.writeLine(Integer.toString(count))
end function
```

同じエフェクトを根の下の `Logging.bnt` で `public effect Log` と宣言したときは、取り込んだ側から、エフェクトを `Logging.Log`、操作を `Logging.write` と書く。ハンドラの節も `case Logging.write(message) ->` と書く。

【方針】エフェクトの宣言と操作の規則は次のとおりである。

- エフェクトの宣言は、エフェクトの名前と、操作（operation）の並びからなる。操作は、名前、引数、戻り値の型を持ち、型パラメータを持ってよい。操作は `uses` を持たない。エフェクトは型パラメータを持たない。
- 操作は、エフェクトを宣言したモジュールの関数であり、関数と同じ名前の規則で呼ぶ。宣言したモジュールの中では `write(引数)`、ほかのモジュールからは `Logging.write(引数)` と書く。操作の呼び出しは、そのエフェクトを生じる。操作の名前は、同じモジュールのほかの関数と同じ名前空間にあり、同じ名前の関数と操作を宣言すると誤りとする。
- 組み込みのエフェクトの操作は、そのエフェクトを宣言した標準ライブラリのモジュールの IO の関数（`Console.writeLine`、`File.readText` など）である。
- エフェクトの名前は、型の名前と同じく大文字の名前であり、`uses` に書ける。宣言したモジュールの中では `Log`、ほかのモジュールからは `Logging.Log` と、モジュールの名前で修飾して書く。モジュールと同じ名前のエフェクトは宣言できない。`public` を付けたエフェクトとその操作は、ほかのモジュールから使える（[名前・スコープ・モジュール](01-03-names-modules.md)）。

【方針】ハンドラ `handle 本体 with case 操作(引数) -> 節 … end handle` の意味は次のとおりである。`case` の後の操作は、式で操作を呼ぶときと同じ名前で書く（`case write(message) ->`、`case Logging.write(message) ->`、`case Console.writeLine(s) ->`）。

- 本体を評価する。本体の評価の途中で操作を呼ぶと、その操作の節を持つ、最も内側のハンドラが処理する。節の引数には、操作の呼び出しの引数を束縛する。
- 節の中で `resume(v)` を評価すると、操作の呼び出しの結果を `v` として、本体の続きを実行する。本体の続きの中で再び呼んだ操作も、同じハンドラが処理する（深いハンドラ）。`resume(v)` の値は、続きを実行し終えたときの `handle` の式の値である。
- 本体が値で終われば、その値が `handle` の式の値である。節が値で終われば、その値が `handle` の式の値である。
- 節は、ハンドラの外側で実行する。節の中で呼んだ操作は、外側のハンドラが処理する。
- 節の中の `return` と `try` は、`handle` を含む関数の呼び出しを終える。
- `handle` の本体の中で起動したタスクは、ハンドラを引き継ぐ。タスクの中で呼んだ操作を引き継いだハンドラが処理するときは、節は末尾で再開する節に限る（[並行処理](01-11-concurrency.md)の「タスクとハンドラ」）。

【決定】継続は一度だけ再開できる。

- `resume` は節の中でだけ直接呼べる。節の中のラムダと `lazy` の本体からは呼べない。理由: ラムダと `lazy` の値は節の外へ持ち出せるので、節が終わった後に続きを再開できてしまい、続きを捨てる時期とリソースを解放する時期を定められない。
- 一つの節の実行の中で `resume` を二度呼ぶと、実行時エラー（継続の二度目の再開）とする。
- 節が `resume` を呼ばずに終わったとき（値で終わるとき、`return` や `try` で関数を終えるとき、実行時エラーで止まるとき）は、本体の続きを捨てる。このとき、本体の中で開いていた `with` のリソースを、内側のスコープから順に解放する（[リソース管理](01-10-resources.md)）。本体の中で起動した、終わっていないタスクは取り消す（[並行処理](01-11-concurrency.md)）。

【方針】組み込みのエフェクトの操作も、`handle` で処理できる。ただし、`State` は操作を持たないエフェクトであり、`State` を型に持つ関数（可変のセルとタスクの集まりの関数、`Task.await`、リソースを解放する関数）を節の `case` に書くと誤りとする。どのハンドラも処理しない組み込みの操作は、処理系が実際に行う。

【方針】ハンドラを使えば、テストで組み込みの操作を差し替えられる。次の例は、ファイルを読む関数を、実際のファイルを読まずに確かめる。

```text
import Benitoite.Unofficial.IO.File

function readPort(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Integer.parse(String.trim(text)) |> Option.okOr(_, "not a number")
end function

function portIsRead() -> Boolean uses File.Read
  bind result <- handle
    readPort("app.conf")
  with
    case File.readText(path) ->
      resume(Result.Ok("8080"))
  end handle
  return result = Result.Ok(8080)
end function
```

`portIsRead` の本体の `handle` は `File.Read` のすべての操作を処理するわけではないが、本体が呼ぶ `File.Read` の操作は `File.readText` だけなので、処理しない操作は呼ばれない。型の上では、一部の操作だけを処理したエフェクトは除かない（[型システム](01-06-type-system.md)）ので、`portIsRead` は `uses File.Read` を書く必要がある。テストの書き方と実行器は[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める。

### 実行時の権限制御（サーバモード）

初回リリース版の処理系は、実行時の権限制御を持たず、エフェクトの型による静的な検査だけを保証する（前述の「エフェクトの型と権限制御の区別」）。

### 外部のライブラリのエフェクトと権限の表示（初回リリース版の後）

初回リリース版は、外部のコマンドやサービスを包むライブラリが宣言したエフェクトを、組み込みのエフェクトと区別して表示する仕組みを持たない。ハンドラで処理したエフェクトは `main` の型に現れないので、そうしたライブラリが既定のハンドラの中で `Process.run` を呼ぶとき、`main` の型に残るのは `Process.Run` だけである。

### 秘密の値とエフェクト（初回リリース版の後）

初回リリース版は、秘密の情報（API キー・アクセス用のトークン・パスワードなど）を表す型と、秘密を扱うエフェクトを持たない。秘密は `String` の値として扱うので、スクリプトはそれを標準出力や記録に書き出せる。
