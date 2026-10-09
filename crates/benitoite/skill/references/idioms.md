# Benitoite idioms

<!--
How the code examples in this file are checked (tests/skill_examples.rs):
- A `benitoite` block is run, and its standard output is compared with the `output` block after it.
  A last line `exit N` in the `output` block is the expected exit code (0 when absent).
  A `stderr` block after the `output` block is the expected standard error (empty when absent).
- A `benitoite check` block is only checked; it must have no errors and no warnings.
- A `benitoite test` block is run with `benitoite test`; all its tests must pass.
- A `benitoite error` block must fail `benitoite check`, and every line of the `diagnostic` block after it must appear in the report.
- A `files` block before an example creates a file next to the script: the first line is `name: <file name>`, the rest is the content.
- Blocks with other info strings (such as `text` and `sh`) are not checked.
-->

Working programs for common tasks. Copy one and change it. Every example is checked against the current `benitoite`.

All examples import the IO modules under `Benitoite.Unofficial`, because those modules are unofficial in this release.

## Contents

- [Program shape and error handling](#program-shape-and-error-handling)
- [Reading and writing files](#reading-and-writing-files)
- [JSON](#json)
- [CSV](#csv)
- [Running external commands](#running-external-commands)
- [Command-line arguments and environment variables](#command-line-arguments-and-environment-variables)
- [HTTP](#http)
- [Collections](#collections)
- [Records and data types](#records-and-data-types)
- [Writing tests](#writing-tests)

## Program shape and error handling

`main` returns `Result[Unit, String]`. When it returns `Result.Error(message)`, the message is reported and the exit code is 1. `try` returns early with the error of a `Result`; `Result.mapError` turns an `IOError` into a `String` first.

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

Use `Process.exit(code)` (effect `Process.Exit`) only when a specific exit code is needed.

## Reading and writing files

`File.readText` reads a whole file; `File.readLines` reads it as lines. Relative paths are resolved against the directory where `benitoite` was started.

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

A missing file is an `IOError` value, not a crash. Match on the `Result` to handle it.

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

Listing a directory and checking for a file:

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

`Json.parse` returns a `Json.Value`. Read fields with `Json.get` and the `Json.as...` functions, which return `Option`.

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

Build JSON with the constructors of `Json.Value` and write it with `Json.stringify` or `Json.stringifyPretty`. Object members are written in the order of their keys.

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

`Csv.parseWithHeader` reads the first row as the header and returns a map per row. Every field is a `String`; convert numbers with `Integer.parse` or `Decimal.parse`.

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

## Running external commands

`Process.run` starts a program with a list of arguments, without a shell. Arguments are passed as they are: `$HOME` below is not expanded. A non-zero exit code is not an error; read it with `Process.Output.exitCode`.

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

`Process.shell` runs one command line with `/bin/sh -c`. Write only POSIX sh: no bash arrays, no `[[ ]]`, no `{a,b}` brace expansion, no `$'...'`. Prefer `Process.run` when no pipe or redirection is needed.

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

## Command-line arguments and environment variables

`benitoite run script.bnt a b` passes `a` and `b`; `Process.arguments()` returns them (without the script name). Both need the effect `Process.Environment`.

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

A client and a server in one program. The server listens on port 0 (the system picks a free port), serves a fixed number of requests in a task, and the client calls it. `with` releases its resources in reverse order when the block ends, and releasing a `TaskGroup` waits for all its tasks; if the server expects more requests than the client sends, the program waits forever at `end with`. Keep the two counts equal. Network effects are not part of `IO.All`; list them separately.

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

A server that runs until it is stopped is simplest with `Http.serve`, which calls the handler for every request. (This example is only checked, not run, because it never ends.)

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

## Collections

Lists, maps, and sets are persistent: functions return new collections and never change the old one. Maps and sets are ordered by their keys, not by insertion order, so `Map.forEach` and `Set.toList` visit keys in sorted order.

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

`List.range(start, stop)` stops before `stop`. Lists have no index operator; use `List.get(xs, i)`, which returns an `Option`.

Loops are written with recursion or with `List.forEach`, `List.map`, `List.fold`. A function that calls itself last (`return f(...)`) does not grow the stack.

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

A mutable cell is a `Reference`; its functions need the effect `State`.

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

## Records and data types

A record has named fields. Read a field with `Type.field(value)`; make a changed copy with `Type(..value, field: new)`. A data type lists its constructors, which are always written with the type name.

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

## Writing tests

A test is a function with `@test("description")` that takes no arguments and returns `Unit` or `Result[Unit, String]`. A test that uses `try` returns `Result[Unit, String]`; returning `Result.Error(message)` fails the test. Check results with `Assert.equal(actual, expected)` and `Assert.isTrue(condition, message)` (effect `Assert.Check`). Run the file with `benitoite test file.bnt`; do not run `benitoite check` on a test file without `main`.

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

Replace a built-in operation in a test with `handle ... with case Op(args) -> ...`. The handler runs instead of the real operation, so the test does not touch files or start commands. `resume(value)` returns `value` to the code that called the operation. Handling some operations of an effect does not remove the effect from the type, so the test still lists `File.Read` and `Process.Run` in `uses`. Functions whose type has `State` (`Reference`, `TaskGroup`, `Task.await`, the `close...` functions) cannot be handled in a `case`.

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
