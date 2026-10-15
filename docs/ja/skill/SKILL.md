# Benitoite

> この文書は、`crates/benitoite/skill/SKILL.md` の日本語の訳である。翻訳元は Benitoite 0.0.5 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

原文の前付け:

```text
---
name: benitoite
description: Write, check, and run Benitoite scripts (`.bnt`) with the `benitoite` command.
license: MIT OR Apache-2.0
metadata:
  benitoite-version: "{{benitoite-version}}"
---
```

<!--
このファイルのコードの例の検査の仕方（tests/skill_examples.rs）:
- この訳のコードの例は検査しない。検査するのは英語の版である。
- `benitoite` のブロックは実行し、その標準出力を、後に続く `output` のブロックと比べる。
  `output` のブロックの最後の行が `exit N` であれば、それが期待する終了コードである（ないときは 0）。
  `output` のブロックの後に `stderr` のブロックがあれば、それが期待する標準エラー出力である（ないときは空）。
- `benitoite check` のブロックは検査だけを行う。誤りも警告もあってはならない。
- `benitoite test` のブロックは `benitoite test` で実行する。そのテストはすべて通らなければならない。
- `benitoite error` のブロックは `benitoite check` で失敗しなければならず、後に続く `diagnostic` のブロックのすべての行が報告に現れなければならない。
- 例の前の `files` のブロックは、スクリプトの隣にファイルを作る。最初の行は `name: <file name>` であり、残りが内容である。
- ほかの情報文字列（`text` や `sh` など）のブロックは検査しない。
-->

Benitoite は、静的に型付けされる関数型のスクリプト言語である。スクリプトの拡張子は `.bnt` であり、コマンド `benitoite` で実行する。検査器は、何かを実行する前に、型の誤りと宣言していないエフェクトを報告する。変更のたびに検査器を使う。

## 最初に版を確かめる

`benitoite --version` を実行し、その最初の行の版（`benitoite X.Y.Z`）を、このファイルの先頭の `metadata.benitoite-version` と比べる。異なるときは、この Skill は別の版の言語を説明しているので、`benitoite skill install` をもう一度実行するよう利用者に伝える。

## スクリプトを作る手順

1. 書く前に、`references/idioms.md` と、スクリプトが使うモジュールごとにそのファイル `references/stdlib/<Module>.md` を読む（`references/` のディレクトリは、このファイルと同じ場所にある）。関数の名前、欄の名前、取り込みの名前を推測せず、そこで調べる。それからスクリプトを書く。合う例があれば、`references/idioms.md` の例から始める。
2. `benitoite check script.bnt` を実行する。
3. すべての診断を読み、スクリプトを直す。報告は `E0230` のようなコードを示す。その意味がわからないときは、`references/diagnostics.md` でコードを引く。`--diagnostics=json` を加えると、診断ごとに一つの JSON のオブジェクトが得られる。
4. `check` が誤りを報告しなくなるまで、2 と 3 を繰り返す。警告も直す。警告はたいてい実際の誤りを指している。
5. [実行の前に](#実行の前に)の確認を行う。
6. `benitoite run script.bnt [arguments...]` を実行する。

`run` の終了コード: `main` が終わったときは 0、`main` が `Result.Error` を返したときとプログラムが実行時エラーで止まったときは 1、スクリプトが検査を通らないときとコマンドラインが誤っているときは 2、`benitoite` の処理系の不具合のときは 3 である。`Process.exit(n)` は `n` で終わる。`run` と `test` は、中断されたとき（`SIGINT` か `SIGTERM`）に 130 で終わる。

## テストの手順

`benitoite check` は `main` のないファイルに誤りを報告するので、テストのファイルには `check` を使わない。

1. テストの関数を書く（[テスト](#テスト)を参照する）。
2. [実行の前に](#実行の前に)の確認を、`main` の代わりにテストの関数のエフェクトを使って行う。
3. `benitoite test file.bnt`（またはディレクトリ）を実行する。ファイルに検査の誤りがあるとき、`test` はテストを一つも実行せず、`check` と同じように誤りを報告する。誤りを直して、もう一度 `test` を実行する。直したことでテストの関数にエフェクトが加わったときは、そのエフェクトを利用者にもう一度示す。

## 実行の前に

スクリプトを初めて実行する前と、`main` のエフェクトが前回利用者に示したものより増えたときには、次のことを行う。

1. `main` のシグネチャの `uses` の並び（テストでは、実行するテストの関数のすべてのエフェクト）を読み、後掲の表の言葉で、プログラムに許されている操作を利用者に伝える。
2. 並びに `File.Write`、`Process.Run`、`Http.Connect`、`Http.Listen` のどれかがあるときは、実行する前に利用者に確認を求める。`Process.Run` については、スクリプトが起動するコマンドの名前も挙げる。それらのコマンドが何をするかは、`benitoite` の検査の範囲の外にある。
3. `IO.All` は `File.Write` と `Process.Run` を含むものとして扱う。`uses` には、`IO.All` の代わりに個別のエフェクトを書く。

`check` を通ったスクリプトは、`main` の `uses` の外の組み込みの操作を行わない。エフェクトが表すのは許される操作の種類だけであり、どのファイル・コマンド・ホストかは表さない。この版の `benitoite` は、実行中の操作を制限しない。スクリプトはエージェントのサンドボックスの中で実行する。

| エフェクト | 利用者に伝える内容 |
|---|---|
| `Console.Write` | 標準出力と標準エラー出力に書く |
| `Console.Read` | 標準入力を読む |
| `File.Read` | ファイルとディレクトリを読む |
| `File.Write` | ファイルとディレクトリを作る・変える・移す・消す |
| `Process.Run` | 外部のコマンドを起動する（その名前を挙げる） |
| `Process.Exit` | 選んだ終了コードでプログラムを終える |
| `Process.Environment` | コマンドラインの引数、環境変数、作業ディレクトリ、スクリプトのディレクトリを読む |
| `Clock.Time` | 時計を読み、時間が経つのを待つ |
| `Random.Generate` | 乱数を作る |
| `Http.Listen` | HTTP のサーバとしてネットワークの接続を受け付ける |
| `Http.Connect` | ネットワーク越しに HTTP のサーバへ接続する |
| `State` | プログラムの中で可変のセルと並行のタスクを使う（外部への作用はない） |
| `Assert.Check` | テストで期待を確かめる（外部への作用はない） |
| `IO.All` | 前掲の `Console`、`File`、`Process`、`Clock`、`Random`、`State` のすべて |

## ほかの言語と異なる言語の規則

- 短いラムダを除き、ブロックは `end` とキーワードで終わる: `end function`、`end if`、`end match`、`end lambda`、`end data`、`end record`、`end handle`、`end with`。波括弧も字下げの規則もない。
- 局所の名前は、`let` ではなく `bind x <- e` で束縛する。`shadow x <- e` は既に見えている局所名を隠せるが、推奨しない。意図的な隠蔽でも、新しい値の意味を表す別の名前を使う。名前に再代入はできない。
- 関数は `function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2` ... `end function` と書く。戻り値の型は `:` ではなく必ず `->` の後に書く。値は `return` で返す。
- 値や処理の選択には `match` を推奨する。条件成立時だけの処理や早期リターンには、`else` のない `if` を使う。`else` と `else if` は有効な構文だが、推奨しない。この助言による警告は加えない。条件の評価回数と順序を保ち、選ばれた分岐だけを評価し、`return` の作用先を同じ関数かラムダに保つ。エフェクトを含む条件をガードへ移さず、真偽値に対する match を入れ子にする。
- 包括的な最後の分岐には、`case other ->` や `case otherCode ->` のような、衝突しない名前を推奨する。予約語ではなく通常の束縛である。外側の局所名との衝突を避け、後ろに到達しない分岐を置かない。`case _ ->` も有効である。この助言は、構成子内、捨てる束縛、部分適用の `_` には適用しない。
- 一文には短いラムダを推奨する: `List.map(xs: xs, f: lambda(value) return value * 2)`。見出しと本体の全体が同じ物理行に収まる必要があり、`Unit` 以外の結果には `return` を要する。本体を見出しの最後の行に始める場合は、その一文の直後の同じ物理行にある `end lambda` だけを取る。後の行の終端は対応する外側のラムダを閉じる。空行やコメント行を挟んでも対応は変わらない。複数行の本体は見出しの次の行に始め、`end lambda` を加える。二文目を加える前に複数行形式に変える。フォーマッタは選んだ終端を保つ。
- 直接に入れ子になった二つのラムダのどちらかで終端を省く場合は、内側を括弧で囲む: `lambda(x) return (lambda(y) return x + y)`。呼び出しの引数と束縛文は、それぞれ独立した区切りとなる。`lambda(x) return x + 1 |> increment` のパイプは本体に属し、`(lambda(x) return x + 1)(3)` はラムダ自体を呼ぶ。
- パターンの照合は、`match value with` の後に、1 行に一つずつ `case pattern -> body` を書き、`end match` で終える。ハンドラは `handle body with` / `case Module.operation(arguments) -> clause` / `end handle` と書く。
- データ型は `data Name` ... `end data` で、レコードは `record Name` ... `end record` で宣言する。
- 構成子は、式でもパターンでも型の名前を付けて書く: `Option.Some(x)`、`Option.None`、`Result.Ok(x)`、`Result.Error(e)`、`Shape.Circle(r)`。
- 演算子: `=` と `<>` は比較、`and`・`or`・`not` は論理演算、`div` と `mod` は整数の除算である。`+` は文字列の連結にも使う。`==`、`!=`、`&&`、`||`、`!` は存在しない。
- `try e` は、パイプを含めて、右側の式全体に適用される: `try File.readText(p) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error))`。`try` は `Result`（または `Option`）を返す関数の中でだけ使う。エラーの型が異なるときは、先に `Result.mapError` で変換する。
- 二つ以上のパラメータを持つ通常の呼び出しでは、引数すべてにラベルを付ける: `List.map(xs: xs, f: action)`。名前付き引数と位置引数を混在させない。一引数の関数は `f(value)` または `f(name: value)`、引数がゼロなら `f()` と書く。ラベルは任意の順に書けるが、呼ぶ関数の式を最初に評価し、次に引数の式をソースの記述順に一度ずつ評価する。ラベルは局所の値ではなくパラメータを指す。組み込みの関数、関数値、メソッド、エフェクトの操作、外部の関数にもこの規則を適用する。直接のデータ構成子とパターン、属性、ハンドラの束縛、`resume` は専用の構文を保つ。
- 関数型には名前を含める: `function(value: T) -> U`。一引数でも、名前と順序はコールバックの契約と一致しなければならない。`List.map` は `value`、`List.fold` は `acc, value`、`Map.map` は `key, value`、`Result.mapError` は `error` を取る。未使用でも期待する名前を保ち、意味を表す別名には局所の `bind` を使う。契約が異なる関数は `lambda(value) return Integer.toString(value)` で包む。呼び出しのラベル順から契約を作らない。E0455 が契約の未確定を報告したら、名前を持つ関数型の注釈を加える。
- 直接の穴がなければ、`xs |> List.map(f: action)` は宣言上の最初のパラメータを満たす。残りの引数にラベルを付け、最初のパラメータを二度指定しない。評価順は、左辺を一度、次に右辺の呼ぶ関数の式、次に明示引数をソースの記述順である。直接の穴がある場合や右辺を括弧で囲んだ場合は、その結果の関数を一引数で呼ぶ。二つの穴を自動で部分適用することはない。
- `_` が部分適用を作るのは、呼び出しの直接の引数としてだけである: `Result.mapError(r: _, f: lambda(error) return IOError.message(error))`。穴は対応するパラメータ名をソース順に引き継ぎ、`f(b: _, a: _)` は `b, a` を取る。呼ぶ関数の式と固定した式は、生成した関数を呼ぶときに実行する。位置構成子の関数値と直接の構成子の穴は、`arg1`、`arg2`、…の元の位置名を使う。レコード構成子の関数値はフィールド名を使い、レコードの取り出す関数は `value` を取る。契約を合わせる例は `references/idioms.md` を参照する。
- `return` は関数とラムダの本体で使う。`if`、`match` の分岐、ハンドラの節の値は、その最後の式である。`case` の本体の中の `return` は、関数全体から戻る。値を作る関数とラムダは、最後の式が `match` や `if` のときも、`return` で終わらなければならない: `lambda(acc, value) return acc + value`。`lazy` の本体と `match` のガードは、`return` も `try` も含められない。ただし、そこに書いたラムダの中は除く（`_` を持つ呼び出しの中は除かない）。
- `Unit` 型の値は `()` と書く: `Result.Ok(())`。
- レコードは名前付きの引数で作り、型の名前で読む: `bind item <- Item(name: "pen", price: 120)`、`Item.price(item)`。一部を変えた写しは `Item(..item, price: 100)` で作る。`item.price`、`Item { ... }`、`Item(price = 100)` は誤りである。
- 呼び出しは型引数をとらない: `Map.empty[String, Integer]()` でなく `Map.empty()` と書く。map に項目を加えるのは `Map.set(m: m, k: key, value: value)` であり、`Map.insert` はない。`Integer.parse` などの解析の関数は `Option` を返す。
- 型の引数には角括弧を使う: `List[Integer]`、`Map[String, Integer]`、`Result[Unit, String]`。`List<Integer>` は正しくない。
- `with r = acquire() do ... end with` は、ブロックが終わるときに、そのリソースを逆の順に解放する。`TaskGroup.spawn(group: group, action: lambda() ... end lambda)` は、`TaskGroup.open()` で開いたタスクの集まりの中でタスクを起動し、`Task.await(task)` はその結果を待つ。タスクの集まりを解放すると、そのすべてのタスクを待つ。
- エフェクトの操作の一部だけを処理するハンドラは、型からそのエフェクトを取り除かない。型に `State` を持つ関数（`Reference`、`TaskGroup`、`Task.await`、`close...`）はハンドラで処理できない。
- マップと集合は、挿入の順ではなくキーの順に並ぶ。
- 数値のビット幅ごとに型が異なり、暗黙の変換はない。接尾辞のない `1` は常に `Integer` である。`Integer32` には `1s32`、`Float32` には `1.0f32` を使う。接尾辞（`s8`–`s64`、`u8`–`u64`、`f32`/`f64`）は暫定であり、構文の見直しで変わることがある。`Integer64` = `Integer`、`Float64` = `Float`、`UnsignedInteger8` = `Byte`、`UnsignedInteger` = `UnsignedInteger64` である。通常の名前には `Integer`、`Float`、`Byte` を使う。`Byte` に算術演算はなく、符号なしの型に単項の負号はない。
- 整数の算術演算は、桁あふれ（符号なし整数の減算で 0 より小さくなる場合を含む）と 0 による除算で止まる。数値の変換の失敗は `Option.None` を返す。モジュールごとのシグネチャを確かめる。`Float32` は各演算の後に丸める。`references/idioms.md` の数値の変換の例を参照する。
- 実験的な `@external("wasm", "path.wasm", "export")` の関数は、取り込みのないバイナリの Component Model のコンポーネントを使い、本体も `end function` も持たない。具体的なレコードとデータ型、引数のない構成子の `Set` で表すフラグ、WIT に対応するキーを持つ `Map` を境界越しに渡せる。外部のリソース型には `uses State` が必要であり、ほかの外部呼び出しは純粋である。生成したアダプタは、詰めて格納したバイト数を数え、それとは別に、同じ `--wasm-transfer` の値で値の構築量の論理的な上限を設ける。`references/idioms.md` の WIT の例と上限を参照する。
- 文字列補間は `"${expression}"` と書く。コメントは `//` で始まる。
- `null` も例外もループの文もない。`Option`、`try` を伴う `Result`、および `List.map`・`List.fold`・`List.forEach` か再帰を使う。
- prelude の外のモジュールは、`uses` にだけ現れるときも含めて、すべて取り込む。非公式のモジュール（IO とネットワークのすべてのモジュール、`Json`、`Csv` など）は `Benitoite.Unofficial` の下で取り込む: `import Benitoite.Unofficial.IO.Console` と書き、`Console` として参照する。`import Benitoite.IO.Console` は誤りである。非公式のモジュールは `IO.Console`、`IO.File`、`IO.Process`、`IO.Clock`、`IO.Random`、`Network.Http`、`Json`、`Csv`、`Regex`、`Path`、`Time`、`Encoding`、`Hash` である。たとえば `import Benitoite.Unofficial.Network.Http` は `Http` として参照する。エフェクトを宣言するモジュール（IO とネットワークのモジュール、`IO`、`Assert`）の名前を `as` で変えない。`uses` が常に本当のエフェクトの名前を示すように、名前を変えると誤りになる。
- エフェクトを直接または呼び出しを通して行う関数は、すべてそのエフェクトを `uses` の後に並べる。ネットワークのエフェクト（`Http.Connect`、`Http.Listen`）は `IO.All` に含まれない。
- 値が `Unit` でない文は誤りである。各 `Result` を、`try`、`match`、`bind _ <-` のどれかで処理する。
- `Process.shell` は、その文字列を `/bin/sh -c` で実行する。POSIX の sh だけを書く。bash の配列、`[[ ]]`、`{a,b}` の展開、`$'...'` は使わない。シェルの機能が要らないときは、引数の並びを渡す `Process.run` を使う。

完全なスクリプトの例:

```files
name: input.txt
one
two
three
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Result[Unit, String] uses File.Read, Console.Write
  bind lines <- try File.readLines("input.txt") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error))
  List.forEach(xs: lines, f: lambda(value) Console.writeLine("${String.characterCount(value)} ${value}"))
  return match List.head(lines) with
    case Option.Some(first) -> Result.Ok(Console.writeLine("first: ${first}"))
    case Option.None -> Result.Error("input.txt is empty")
  end match
end function
```

```output
3 one
3 two
5 three
first: one
```

## テスト

テストは、`@test("description")` を付け、引数を持たず、戻り値の型が `Unit` か `Result[Unit, String]` の関数である（テストが `try` を使うときは後者にする）。`Assert.equal(actual: actual, expected: expected)` で確かめる。テストが外の世界に触れないように、`File.readText` や `Process.run` などの操作をハンドラで置き換える。ほかの例は `references/idioms.md` にある。型パラメータを持つ補助の関数の中の確かめは、呼び出し元の型を決められるときは、構成子の名前を復元する。決められないときは、型が不明のまま残ることがある。報告が `<constructor #n of an unknown type>`（n は 0 から数えた構成子の位置）を示すときは、確かめの中で具体的な型の値を比べると、構成子の名前が表示される。

```benitoite test
import Benitoite.Unofficial.IO.File

function firstLine(path: String) -> Result[String, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error))
  return Option.okOr(o: List.head(String.lines(text)), error: "empty file")
end function

@test("firstLine returns the first line")
function firstLineWorks() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    firstLine("data.txt")
  with
    case File.readText(_) -> resume(Result.Ok("alpha\nbeta\n"))
  end handle
  Assert.equal(actual: result, expected: Result.Ok("alpha"))
end function
```

## 参照の文書

必要なときに次の文書を読む。

| 文書 | 読むとき |
|---|---|
| `references/idioms.md` | よくある作業（ファイル、JSON、CSV、外部のコマンド、引数、HTTP、コレクション、レコード、テスト、数値の変換、WASM/WIT の宣言）を書くとき。 |
| `references/common-mistakes.md` | ほかの言語の習慣（`let`、波括弧、`==`、取り込みの漏れ）から診断が出たとき。 |
| `references/language-comparison.md` | Python、JavaScript、Rust での書き方は知っていて、Benitoite の形が必要なとき。 |
| `references/diagnostics.md` | 診断のコード（`E0201`、`W0501` など）の意味がわからないとき。 |
| `references/grammar.md` | 構文の正確な形が必要なとき。 |
| `references/stdlib/index.md` | 標準ライブラリのモジュールが必要なとき。すべてのモジュールを取り込みの名前とともに挙げている。 |

各モジュールには、`references/stdlib/List.md` や `references/stdlib/IO.Console.md` のように、`references/stdlib/<Module>.md` という名前のファイルがある。`references/stdlib/index.md` からのリンクを辿る。

（訳注）この訳のある参照の文書: [idioms.md](references/idioms.md)、[common-mistakes.md](references/common-mistakes.md)、[language-comparison.md](references/language-comparison.md)。生成の文書（[grammar.md](../../../crates/benitoite/skill/references/grammar.md)、[diagnostics.md](../../../crates/benitoite/skill/references/diagnostics.md)、[stdlib/index.md](../../../crates/benitoite/skill/references/stdlib/index.md)）は訳さないので、英語の原文を参照する。
