# Benitoite の定番の書き方

> この文書は、`crates/benitoite/skill/references/idioms.md` の日本語の訳である。訳した元は、コミット d2a00c7 の英語の版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

<!--
このファイルのコードの例の検査の方法（tests/skill_examples.rs）:
- `benitoite` のブロックは実行し、その標準出力を、後に続く `output` のブロックと比べる。
  `output` のブロックの最後の行 `exit N` は、期待する終了コードである（ないときは 0）。
  `output` のブロックの後の `stderr` のブロックは、期待する標準エラー出力である（ないときは空）。
- `benitoite check` のブロックは検査だけを行う。誤りも警告もあってはならない。
- `benitoite test` のブロックは `benitoite test` で実行する。そのテストはすべて通らなければならない。
- `benitoite error` のブロックは `benitoite check` で失敗しなければならず、後に続く `diagnostic` のブロックの各行が報告に現れなければならない。
- 例の前の `files` のブロックは、スクリプトの隣にファイルを作る。最初の行は `name: <ファイル名>`、残りが中身である。
- ほかの情報文字列のブロック（`text` や `sh` など）は検査しない。
- この訳のコードの例は検査しない。検査するのは英語の版である。
-->

よくある作業のための、動くプログラムを集めた。一つを写して変えればよい。どの例も、現在の `benitoite` で検査してある。

どの例も、IO のモジュールを `Benitoite.Unofficial` の下から取り込む。この版では、それらのモジュールが非公式のモジュールだからである。

## 目次

- プログラムの形と誤りの扱い
- ファイルの読み書き
- JSON
- CSV
- 外部のコマンドの実行
- コマンド行の引数と環境変数
- HTTP
- コレクション
- レコードとデータ型
- テストの書き方

## プログラムの形と誤りの扱い

`main` は `Result[Unit, String]` を返す。`Result.Error(message)` を返すと、そのメッセージを報告し、終了コードは 1 になる。`try` は、`Result` が誤りならその誤りで早めに戻る。その前に、`Result.mapError` で `IOError` を `String` に変える。

```benitoite
import Benitoite.Unofficial.IO.Console

function parsePort(text: String) -> Result[Integer, String]
  return match Integer.parse(text) with
    case Option.Some(n) if n > 0 and n < 65536 -> Result.Ok(n)
    case _ -> Result.Error("not a port: ${text}")
  end match
end function

function main() -> Result[Unit, String] uses Console.Write
  bind port <- try parsePort("8080")
  Console.writeLine("port ${port}")
  bind other <- try parsePort("http")
  Console.writeLine("never printed ${other}")
  return Result.Ok(())
end function
```

```output
port 8080
exit 1
```

```stderr
not a port: http
```

`Process.exit(code)`（エフェクト `Process.Exit`）は、特定の終了コードが必要なときにだけ使う。

## ファイルの読み書き

`File.readText` はファイル全体を読み、`File.readLines` は行の並びとして読む。相対パスは、`benitoite` を起動したディレクトリを基準に解決する。

```files
name: input.txt
apple 3
banana 5
cherry 7
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Result[Unit, String] uses File.Read, File.Write, Console.Write
  bind lines <- try File.readLines("input.txt") |> Result.mapError(_, IOError.message)
  bind total <- List.fold(lines, 0, lambda(sum, line)
    return match String.split(line, " ") with
      case [_, count] -> sum + Option.unwrapOr(Integer.parse(count), 0)
      case _ -> sum
    end match
  end lambda)
  bind report <- "lines: ${List.length(lines)}\ntotal: ${total}\n"
  bind _ <- try File.writeText("report.txt", report) |> Result.mapError(_, IOError.message)
  bind _ <- try File.appendText("report.txt", "done\n") |> Result.mapError(_, IOError.message)
  Console.write(try File.readText("report.txt") |> Result.mapError(_, IOError.message))
  return Result.Ok(())
end function
```

```output
lines: 3
total: 15
done
```

ファイルがないことは、異常終了ではなく `IOError` の値になる。扱うには、`Result` に対して match を書く。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Unit uses File.Read, Console.Write
  return match File.readText("missing.txt") with
    case Result.Ok(text) -> Console.write(text)
    case Result.Error(error) ->
      if IOError.kind(error) = IOErrorKind.NotFound then
        Console.writeLine("missing.txt does not exist")
      else
        Console.writeLine("could not read: ${IOError.message(error)}")
      end if
  end match
end function
```

```output
missing.txt does not exist
```

ディレクトリの一覧を得て、ファイルがあるかを確かめる例:

```files
name: notes.md
# notes
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Result[Unit, String] uses File.Read, File.Write, Console.Write
  bind _ <- try File.createDirectory("out") |> Result.mapError(_, IOError.message)
  bind names <- try File.listDirectory(".") |> Result.mapError(_, IOError.message)
  List.forEach(List.sort(names), lambda(name) Console.writeLine(name) end lambda)
  bind found <- try File.exists("notes.md") |> Result.mapError(_, IOError.message)
  Console.writeLine(if found then "notes.md exists" else "no notes.md" end if)
  return Result.Ok(())
end function
```

```output
main.bnt
notes.md
out
notes.md exists
```

## JSON

`Json.parse` は `Json.Value` を返す。フィールドは、`Json.get` と `Json.as...` の関数で読む。これらは `Option` を返す。

```files
name: orders.json
[
  {"category": "book", "amount": 1200},
  {"category": "food", "amount": 300},
  {"category": "book", "amount": 800}
]
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Json

function amountOf(order: Json.Value) -> Result[Pair[String, Integer], String]
  bind category <- Option.andThen(Json.get(order, "category"), Json.asString)
  bind amount <- Option.andThen(Json.get(order, "amount"), Json.asInteger)
  return match Pair(category, amount) with
    case Pair(Option.Some(c), Option.Some(a)) -> Result.Ok(Pair(c, a))
    case _ -> Result.Error("an order needs a category and an amount")
  end match
end function

function main() -> Result[Unit, String] uses File.Read, Console.Write
  bind text <- try File.readText("orders.json") |> Result.mapError(_, IOError.message)
  bind value <- try Json.parse(text) |> Result.mapError(_, Json.ParseError.message)
  bind orders <- try Option.okOr(Json.asArray(value), "orders.json is not an array")
  bind totals <- List.fold(orders, Result.Ok(Map.empty()), lambda(acc, order)
    return Result.andThen(acc, lambda(m)
      return Result.map(amountOf(order), lambda(entry)
        bind current <- Map.get(m, Pair.first(entry)) |> Option.unwrapOr(_, 0)
        return Map.set(m, Pair.first(entry), current + Pair.second(entry))
      end lambda)
    end lambda)
  end lambda)
  Map.forEach(try totals, lambda(category, total)
    Console.writeLine("${category}: ${total}")
  end lambda)
  return Result.Ok(())
end function
```

```output
book: 2000
food: 300
```

JSON は `Json.Value` の構成子で組み立て、`Json.stringify` か `Json.stringifyPretty` で書き出す。オブジェクトのメンバは、キーの順に書き出す。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.Json

function main() -> Unit uses Console.Write
  bind value <- Json.Value.Object(Map.fromList([
    Pair("name", Json.Value.String("benitoite")),
    Pair("tags", Json.Value.Array([Json.Value.String("script"), Json.Value.String("typed")])),
    Pair("stars", Json.Value.Integer(42)),
    Pair("archived", Json.Value.Boolean(false)),
    Pair("license", Json.Value.Null)
  ]))
  return Console.writeLine(Json.stringify(value))
end function
```

```output
{"archived":false,"license":null,"name":"benitoite","stars":42,"tags":["script","typed"]}
```

## CSV

`Csv.parseWithHeader` は、最初の行を見出しとして読み、行ごとに一つのマップを返す。欄はすべて `String` である。数は `Integer.parse` か `Decimal.parse` で変換する。

```files
name: scores.csv
name,score
Alice,90
"Bob, Jr.",75
Carol,82
```

```benitoite
import Benitoite.Unofficial.Csv
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function scoreOf(row: Map[String, String]) -> Integer
  return Option.andThen(Map.get(row, "score"), Integer.parse) |> Option.unwrapOr(_, 0)
end function

function main() -> Result[Unit, String] uses File.Read, File.Write, Console.Write
  bind text <- try File.readText("scores.csv") |> Result.mapError(_, IOError.message)
  bind rows <- try Csv.parseWithHeader(text) |> Result.mapError(_, Csv.ParseError.message)
  bind passed <- List.filter(rows, lambda(row) return scoreOf(row) >= 80 end lambda)
  bind output <- List.map(passed, lambda(row)
    return [Option.unwrapOr(Map.get(row, "name"), ""), Integer.toString(scoreOf(row))]
  end lambda)
  bind csv <- Csv.format(List.prepend(output, ["name", "score"]))
  bind _ <- try File.writeText("passed.csv", csv) |> Result.mapError(_, IOError.message)
  Console.write(csv)
  Console.write(Csv.format([["Bob, Jr.", "75"]]))
  return Result.Ok(())
end function
```

```output
name,score
Alice,90
Carol,82
"Bob, Jr.",75
```

## 外部のコマンドの実行

`Process.run` は、シェルを介さずに、引数のリストを渡してプログラムを起動する。引数はそのまま渡すので、下の `$HOME` は展開されない。0 でない終了コードは誤りではない。`Process.Output.exitCode` で読む。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process

function main() -> Result[Unit, String] uses Process.Run, Console.Write
  bind printed <- try Process.run(Process.command("echo", ["hello", "$HOME"])) |> Result.mapError(_, IOError.message)
  Console.write(Process.Output.standardOutput(printed))
  bind sort <- Process.Command(..Process.command("sort", []), environment: Map.fromList([Pair("LC_ALL", "C")]), input: Option.Some("pear\napple\n"))
  bind sorted <- try Process.run(sort) |> Result.mapError(_, IOError.message)
  Console.write(Process.Output.standardOutput(sorted))
  bind failed <- try Process.run(Process.command("sh", ["-c", "exit 3"])) |> Result.mapError(_, IOError.message)
  Console.writeLine("exit code: ${Process.Output.exitCode(failed)}")
  return Result.Ok(())
end function
```

```output
hello $HOME
apple
pear
exit code: 3
```

`Process.shell` は、一つのコマンド行を `/bin/sh -c` で実行する。POSIX の sh だけで書く。bash の配列、`[[ ]]`、`{a,b}` の波括弧の展開、`$'...'` は使わない。パイプもリダイレクトも要らないときは、`Process.run` を使う。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process

function main() -> Result[Unit, String] uses Process.Run, Console.Write
  bind piped <- try Process.shell("printf 'b\\na\\nc\\n' | LC_ALL=C sort | tr 'a-z' 'A-Z'") |> Result.mapError(_, IOError.message)
  Console.write(Process.Output.standardOutput(piped))
  bind checked <- try Process.shell("if [ -d / ]; then echo root; fi; echo oops >&2; exit 2") |> Result.mapError(_, IOError.message)
  Console.write(Process.Output.standardOutput(checked))
  Console.write("stderr: ${Process.Output.standardError(checked)}")
  Console.writeLine("exit code: ${Process.Output.exitCode(checked)}")
  return Result.Ok(())
end function
```

```output
A
B
C
root
stderr: oops
exit code: 2
```

## コマンド行の引数と環境変数

`benitoite run script.bnt a b` は `a` と `b` を渡し、`Process.arguments()` がそれらを返す（スクリプトの名前は含まない）。引数と環境変数の読み出しは、どちらもエフェクト `Process.Environment` を要する。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process

function main() -> Result[Unit, String] uses Process.Environment, Console.Write
  bind arguments <- Process.arguments()
  Console.writeLine("arguments: ${List.length(arguments)}")
  bind name <- match arguments with
    case [first, ..] -> first
    case [] -> "world"
  end match
  Console.writeLine("Hello, ${name}!")
  bind unset <- try Process.environmentVariable("BENITOITE_SKILL_EXAMPLE_UNSET") |> Result.mapError(_, IOError.message)
  Console.writeLine(Option.unwrapOr(unset, "(not set)"))
  return Result.Ok(())
end function
```

```output
arguments: 0
Hello, world!
(not set)
```

## HTTP

クライアントとサーバを一つのプログラムに書いた例である。サーバはポート 0 で待ち受け（空いているポートをシステムが選ぶ）、タスクの中で決まった数の要求に応え、クライアントがそれを呼ぶ。`with` はブロックが終わるときにリソースを逆の順に解放し、`TaskGroup` の解放はそのタスクをすべて待つ。そのため、クライアントが送るより多くの要求をサーバが待つと、プログラムは `end with` で永久に待つ。二つの数を等しくしておく。ネットワークのエフェクトは `IO.All` に含まれないので、別に並べる。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Network.Http

function route(request: Http.Request) -> Http.Response
  return match Pair(Http.Request.method(request), Http.pathSegments(Http.Request.path(request))) with
    case Pair("GET", ["hello", name]) -> Http.text(200, "Hello, ${name}!")
    case Pair("GET", ["items"]) -> Http.json(200, Json.Value.Array([Json.Value.Integer(1), Json.Value.Integer(2)]))
    case _ -> Http.text(404, "not found")
  end match
end function

function serveLoop(listener: Http.Listener, remaining: Integer) -> Result[Unit, String] uses Http.Listen, State
  if remaining = 0 then return Result.Ok(()) end if
  bind exchange <- try Http.accept(listener) |> Result.mapError(_, NetworkError.message)
  bind _ <- try Http.respond(exchange, route(Http.requestOf(exchange))) |> Result.mapError(_, NetworkError.message)
  bind _ <- try Http.closeExchange(exchange) |> Result.mapError(_, NetworkError.message)
  return serveLoop(listener, remaining - 1)
end function

function show(response: Http.Response) -> Unit uses Console.Write
  bind body <- Option.unwrapOr(String.fromUTF8(Http.Response.body(response)), "(not UTF-8)")
  return Console.writeLine("${Http.Response.status(response)} ${body}")
end function

function main() -> Result[Unit, String] uses Http.Listen, Http.Connect, Console.Write, State
  with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message),
    group = TaskGroup.open() do
    bind base <- "http://127.0.0.1:${Http.listenerPort(listener)}"
    bind server <- TaskGroup.spawn(group, lambda() return serveLoop(listener, 3) end lambda)
    bind hello <- try Http.get(base + "/hello/Ada") |> Result.mapError(_, NetworkError.message)
    bind items <- try Http.get(base + "/items") |> Result.mapError(_, NetworkError.message)
    bind request <- Http.ClientRequest(..Http.clientRequest("POST", base + "/upload"), body: String.toUTF8("data"))
    bind missing <- try Http.send(request) |> Result.mapError(_, NetworkError.message)
    bind _ <- try Task.await(server)
    List.forEach([hello, items, missing], show)
    return Result.Ok(())
  end with
end function
```

```output
200 Hello, Ada!
200 [1,2]
404 not found
```

止められるまで動き続けるサーバは、`Http.serve` を使うのがいちばん簡単である。`Http.serve` は要求ごとにハンドラを呼ぶ。（この例は終わらないので、実行せず検査だけを行う。）

```benitoite check
import Benitoite.Unofficial.Network.Http

function respondTo(request: Http.Request) -> Http.Response
  return match Http.pathSegments(Http.Request.path(request)) with
    case [] -> Http.html(200, "<h1>Home</h1>")
    case ["health"] -> Http.text(200, "ok")
    case _ -> Http.text(404, "not found")
  end match
end function

function main() -> Result[Unit, String] uses Http.Listen, State
  return Http.serve("127.0.0.1", 8080, respondTo) |> Result.mapError(_, NetworkError.message)
end function
```

## コレクション

リスト、マップ、集合は永続である。関数は新しいコレクションを返し、元のコレクションを変えない。マップと集合は、加えた順ではなくキーの順に並ぶので、`Map.forEach` と `Set.toList` はキーを整列した順に辿る。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind numbers <- List.range(1, 6)
  bind squares <- List.map(numbers, lambda(n) return n * n end lambda)
  bind even <- List.filter(squares, lambda(n) return n mod 2 = 0 end lambda)
  Console.writeLine("${List.length(numbers)} numbers, sum ${List.fold(numbers, 0, lambda(a, n) return a + n end lambda)}")
  Console.writeLine(String.join(List.map(even, Integer.toString), ", "))
  bind words <- String.split("the cat saw the dog", " ")
  bind counts <- List.fold(words, Map.empty(), lambda(m, w)
    return Map.set(m, w, Option.unwrapOr(Map.get(m, w), 0) + 1)
  end lambda)
  Map.forEach(counts, lambda(word, count) Console.writeLine("${word}=${count}") end lambda)
  Console.writeLine(String.join(Set.toList(Set.fromList(words)), " "))
  return ()
end function
```

```output
5 numbers, sum 15
4, 16
cat=1
dog=1
saw=1
the=2
cat dog saw the
```

`List.range(start, stop)` は `stop` の手前で止まる。リストに添字の演算子はない。`List.get(xs, i)` を使う。これは `Option` を返す。

繰り返しは、再帰か、`List.forEach`・`List.map`・`List.fold` で書く。最後に自身を呼ぶ関数（`return f(...)`）は、スタックを伸ばさない。

```benitoite
import Benitoite.Unofficial.IO.Console

function countDown(n: Integer, acc: List[String]) -> List[String]
  if n = 0 then return List.reverse(acc) end if
  return countDown(n - 1, List.prepend(acc, Integer.toString(n)))
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(String.join(countDown(5, []), " "))
end function
```

```output
5 4 3 2 1
```

可変のセルは `Reference` である。その関数はエフェクト `State` を要する。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write, State
  bind counter <- Reference.new(0)
  List.forEach([3, 4, 5], lambda(n) Reference.set(counter, Reference.get(counter) + n) end lambda)
  return Console.writeLine("total ${Reference.get(counter)}")
end function
```

```output
total 12
```

## レコードとデータ型

レコードは名前の付いたフィールドを持つ。フィールドは `Type.field(value)` で読み、一部を変えた写しは `Type(..value, field: new)` で作る。データ型はその構成子を並べる。構成子は常に型の名前を付けて書く。

```benitoite
import Benitoite.Unofficial.IO.Console

record Item
  name: String
  price: Integer
  quantity: Integer
end record

data Shape
  Circle(Float)
  Rectangle(Float, Float)
end data

function area(shape: Shape) -> Float
  return match shape with
    case Shape.Circle(r) -> 3.0 * r * r
    case Shape.Rectangle(w, h) -> w * h
  end match
end function

function main() -> Unit uses Console.Write
  bind item <- Item(name: "pen", price: 120, quantity: 3)
  bind more <- Item(..item, quantity: 10)
  Console.writeLine("${Item.name(more)}: ${Item.price(more) * Item.quantity(more)}")
  bind shapes <- [Shape.Circle(1.0), Shape.Rectangle(2.0, 3.5)]
  List.forEach(shapes, lambda(s) Console.writeLine(Float.toString(area(s))) end lambda)
  return ()
end function
```

```output
pen: 1200
3.0
7.0
```

## テストの書き方

テストは、`@test("description")` を付けた関数であり、引数を取らず、`Unit` か `Result[Unit, String]` を返す。`try` を使うテストは `Result[Unit, String]` を返し、`Result.Error(message)` を返すとテストは失敗する。結果は `Assert.equal(actual, expected)` と `Assert.isTrue(condition, message)`（エフェクト `Assert.Check`）で確かめる。ファイルは `benitoite test file.bnt` で実行する。`main` のないテストのファイルに `benitoite check` を実行しない。

```benitoite test
function slugify(title: String) -> String
  return String.join(String.split(String.toLowercase(String.trim(title)), " "), "-")
end function

@test("slugify lowercases and joins words")
function slugifyJoins() -> Unit uses Assert.Check
  Assert.equal(slugify(" Hello World "), "hello-world")
  Assert.isTrue(String.contains(slugify("A B"), "-"), "the words are joined with -")
end function
```

テストでは、組み込みの操作を `handle ... with case Op(args) -> ...` で置き換える。本物の操作の代わりにハンドラが動くので、テストはファイルに触れず、コマンドも起動しない。`resume(value)` は、操作を呼んだコードへ `value` を返す。エフェクトの一部の操作を扱っても、型からそのエフェクトは消えない。そのため、テストは `uses` に `File.Read` と `Process.Run` をなお並べる。型に `State` を持つ関数（`Reference`、`TaskGroup`、`Task.await`、`close...` の関数）は、`case` で扱えない。

```benitoite test
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function countWords(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Result.Ok(List.length(List.filter(String.split(text, " "), lambda(w) return w <> "" end lambda)))
end function

function gitBranch() -> Result[String, String] uses Process.Run
  bind output <- try Process.run(Process.command("git", ["branch", "--show-current"])) |> Result.mapError(_, IOError.message)
  return Result.Ok(String.trim(Process.Output.standardOutput(output)))
end function

@test("countWords reads the file through File.readText")
function countWordsReadsFile() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    countWords("notes.txt")
  with
    case File.readText(path) ->
      Assert.equal(path, "notes.txt")
      resume(Result.Ok("one two  three"))
  end handle
  Assert.equal(result, Result.Ok(3))
end function

@test("gitBranch runs git without starting it")
function gitBranchRunsGit() -> Unit uses Assert.Check, Process.Run
  bind result <- handle
    gitBranch()
  with
    case Process.run(command) ->
      Assert.equal(Process.Command.program(command), "git")
      resume(Result.Ok(Process.Output(exitCode: 0, standardOutput: "main\n", standardError: "")))
  end handle
  Assert.equal(result, Result.Ok("main"))
end function
```
