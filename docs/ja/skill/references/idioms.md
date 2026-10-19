# Benitoite の定番の書き方

> この文書は、`crates/benitoite/skill/references/idioms.md` の日本語の訳である。翻訳元は Benitoite 0.0.9 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

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

- [プログラムの形と誤りの扱い](#プログラムの形と誤りの扱い)
- [呼び出し、コールバックの契約、穴、パイプ](#呼び出しコールバックの契約穴パイプ)
- [ファイルの読み書き](#ファイルの読み書き)
- [JSON](#json)
- [CSV](#csv)
- [外部のコマンドの実行](#外部のコマンドの実行)
- [コマンド行の引数と環境変数](#コマンド行の引数と環境変数)
- [HTTP](#http)
- [コレクション](#コレクション)
- [具体的なコンテナと汎用のコンテナ](#具体的なコンテナと汎用のコンテナ)
- [レコードとデータ型](#レコードとデータ型)
- [テストの書き方](#テストの書き方)
- [数値のビット幅と変換](#数値のビット幅と変換)
- [WASM の外部の関数と WIT の型](#wasm-の外部の関数と-wit-の型)

## 具体的なコンテナと汎用のコンテナ

コンテナが既知なら List.map/fold、Option.map/andThen、Result.map/andThen/mapError を使う。複数のコンテナで共用する関数には、使う操作を提供する最小のクラスを要求する。Functor は map、Applicative は pure/apply、Monad は flatMap を加える。二引数版は F[A, X] の第二の型を保つ。クラスの名前には Benitoite.Trait を取り込む。Result 自体は prelude にある。

```benitoite
import Benitoite.Trait
import Benitoite.Unofficial.IO.Console

function twice[F[_, _]: Trait.Functor2, X](x: F[Integer, X]) -> F[Integer, X]
  return Trait.Functor2.map(x: x, f: lambda(value) return value * 2 end lambda)
end function

function main() -> Unit uses Console.Write
  bind concrete: Result[Integer, String] <- Result.map(r: Result.Ok(3), f: lambda(value) return value * 2 end lambda)
  bind generic: Result[Integer, String] <- twice(Result.Ok(3))
  Console.writeLine(Integer.toString(Result.unwrapOr(r: concrete, fallback: 0)))
  Console.writeLine(Integer.toString(Result.unwrapOr(r: generic, fallback: 0)))
end function
```


```output
6
6
```


Trait.Monad2 は Applicative2 と Functor2 を含むため、flatMap も使う関数では継承した map を呼べる。標準実装は Result であり、利用者定義の二引数データ型も実装できる。Applicative2.pure にはエラー型を決める Result[Integer, String] のような結果の注釈が必要なことがある。Applicative2.apply は fs の Error を x より優先し、両方 Ok のときだけ包まれた関数を一度呼ぶ。引数式はソース順に評価する。型を書くときは `Result[(function(value: A) -> B uses E), X]` の括弧を保ち、効果行と X を分ける。

型構成子の部分適用はない。Result を一引数の Monad や Traversable に渡せない。完全適用した透明な別名は通常どおり展開する。裸の別名は独立した型構成子や辞書を選ぶ方法にはならない。

andThen/flatMap は成功値を同じエラー型の計算に渡し、エラー型の調整には Result.mapError を使う。try … or return は失敗を呼び出し側へ返し、or die は報告して実行を終える。Failure.toResult は型付き Fail を処理して値を返し、囲む uses の上限から処理した Fail を除く。表示・比較・結合の関数は意味で選ぶ。Show は文字列を引用することがあり数値の toString とは異なる。Order[Float] は NaN を含む全順序であり、組み込みの比較とは異なる。

## プログラムの形と誤りの扱い

再利用する関数・ライブラリ・コールバックには `or return`、失敗を報告して実行を終える入口には `or die` を使う。この例は、`load` でエラーを保ち、`main` で終了の原因に使う。

```files
name: input.txt
ready
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function load(path: String) -> Result[String, IOError] uses File.Read
  return Result.Ok(try File.readText(path) or return)
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try load("input.txt") or die("could not read input.txt")
  Console.write(text)
end function
```

```output
ready
```

`load` は元の IOError を呼び出し元へそのまま返す。読み込みに失敗すると、`main` は標準の Show の実装を使うので、表示だけのための変換は不要である。Process.Exit の追加は関数の契約を変えるため、処置・戻り値の型・エフェクトを一緒に確認する。

`try e or die` と `try e or die(message)` は、標準の `Result[T, E]` か `Option[T]` を受け取り、成功時は `T` を取り出す。囲む関数の戻り値の型は制限しない。`Process.Exit` を加えるので、`uses` に名前を書くために `Benitoite.Unofficial.IO.Process` を取り込む。このモジュールは `as` で改名できない（E0339）ため、`uses Process.Exit` と書く。コンパイラは標準の Show と終了の参照を内部で接続するが、名前を利用者のスコープに取り込むことはない。ホストによる失敗の報告に `Console.Write` のエフェクトは不要である。

| 処置 | 囲む関数の戻り値の型 | 表示の要件 | 追加のエフェクト |
|---|---|---|---|
| 裸の try または `or return` | 入力に対応する `Result[U, E]` か `Option[U]` | なし | なし |
| `or die` または `or die(message)` | 任意 | Result のエラー型には `Trait.Show`。Option には不要 | `Process.Exit` |

入力は一度だけ評価する。成功時は説明も Show も評価しない。失敗時は、任意の純粋な `String` の説明を一度、エラーの Show を一度、この順に評価し、標準の終了操作を状態 1 で呼ぶ。説明の中でエラーに名前を暗黙に束縛することはない。説明には直接の `return`、`try`、外側の `resume` を書けない。そこに書くラムダは、独自の return の境界を持つ。`IOError`、`NetworkError`、`Json.ParseError`、`Csv.ParseError` は、`message` の文字列をそのまま返す Show を既に実装している。ほかのエラー型では Show を実装するか、`Result.mapError` で Show のある型へ変換する。失敗を返す形には Show は不要である。

String の原因には、Show が付ける引用符とエスケープを保つ。Option.None の原因は、固定の `expected a value, got Option.None` である。説明は通常のテキストとして表示し、空の説明と説明なしを区別する。どちらも原因を消さない。説明か Show が実行時エラーや資源の不足で止まると、die の報告の代わりにその停止を採る。純粋性と静的検査は、停止性、意図した結果、外部操作の成功を保証しない。

既定の終了は、子タスクから呼んだ場合も、実行全体を終える。残るタスクを取り消し、リソースを解放し、バッファにある出力を転送する。その後、CLI は `error: explicit failure exit`、ソースの位置、任意の `message: ...`、`cause: ...` を標準エラー出力へ一度報告する。解放と最後の出力の失敗は補足の報告として後に続き、状態 1 を保つ。`--diagnostics=json` では、die の報告は `kind: "die"`、`code: null` と、同じ位置と notes を持つ。タスクを取り消しても、既に始めた外部の作業を元に戻すことはできない。競合する終了、中断、処理系の不具合は通常の停止規則に従い、採用した die の情報だけを報告する。

言語のハンドラは、既存の `Process.Exit` の操作を置き換えられる。受け取るのは通常の終了コードだけであり、処理した呼び出しの報告は破棄し、後の終了には付けない。`benitoite test` では、die はそのテストを失敗にし、実行器は次のテストへ続く。テキストと JSON の両方で原因・説明・位置を保ち、捕えた出力へ同じ報告を重ねない。任意の終了状態には `Process.exit(code)` を使う。

入力は、同じ深さの `or return` または `or die` までのパイプを含む。通常の真偽値の `or` は演算子のままである。明示形の try に演算子や呼び出しを続けるときは、`(try parsePort(text) or die) + 1` のように括弧で囲む。`or return` は値を取らない。その `return` の直後の物理改行は文を終える。説明の `(` は `die` と同じ物理行で始める。括弧の外では、`die` またはその説明の後の改行は文を終える。短いラムダは、処置と説明の全体を一つの物理行に含める必要がある。フォーマッタは裸の形と明示形を保つ。

次の例では、代わりに、`main` が `Result[Unit, String]` を返すことを契約とする。`Result.Error(message)` を返すと、そのメッセージを報告し、終了コードは 1 になる。`or return`（裸の try と同じ意味）は、エラーで早めに戻る。

```benitoite
import Benitoite.Unofficial.IO.Console

function parsePort(text: String) -> Result[Integer, String]
  return match Integer.parse(text) with
    case Option.Some(n) if n > 0 and n < 65536 -> Result.Ok(n)
    case otherPort -> Result.Error("not a port: ${text}")
  end match
end function

function main() -> Result[Unit, String] uses Console.Write
  bind port <- try parsePort("8080") or return
  Console.writeLine("port ${port}")
  bind other <- try parsePort("http") or return
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

型付きの失敗には Benitoite.Unofficial.Failure を取り込む。Failure.fromResult(result) は Ok の値を返すか、元のエラーで失敗を発生させる。Failure.toResult(body) は body を一度呼び、Failure.Fail[E] 以外のエフェクトを残して Result[T, E] を返す。コールバックの残りの行は Fail を除外しなければならず、この条件はシグネチャから求める。どちらの変換にも Show と equality は要らない。E を推論できなければ、結果の束縛かコールバックの型に注釈を加える。呼び出しには明示的な型引数は書けない。

List.map の外側に toResult を置くと、最初の失敗で map 全体を止める。非再開型の節は残りの計算を飛ばし、入れ子の with を内側から外側へそれぞれ一度解放する。解放の失敗は実行時エラーのままである。コールバックの通常の return と try は toResult へ戻り、その値を、返された Result も含めて Ok に包む。子タスクの内側ごとに toResult を置き、Task.all/allOk を通じて Result を返す。子は親の非再開型のハンドラを使えない（R0502）。lazy 本体の内部で失敗を処理すれば Result を記憶できる。未処理の Fail は本体を不純にする（E0503）。これらの変換は die、Process.Exit、実行時エラー、資源の上限、中断、取り消し、外部のトラップを捕捉しない。

標準 Fail の E0506 は、main または @test の内部の toResult で対処できる。入口の uses から処理した Fail を外し、ほかの効果を保つ。Result.andThen/flatMap は Result 値の連結であり Fail を処理しない。この toResult の案内は Log や利用者定義の同名の効果には適用しない。

## 呼び出し、コールバックの契約、穴、パイプ

二つ以上のパラメータを持つ通常の呼び出しでは、各引数に宣言の名前でラベルを付ける。一引数の呼び出しはラベルを省いてよく、引数がゼロなら `f()` と書く。ラベルは任意の順に書ける。呼ぶ関数の式を最初に評価し、次に各引数をソースの記述順に一度ずつ評価する。

パラメータ名は関数型の一部である。コールバックは、未使用のパラメータも含めて、期待する名前と順序が正確に一致しなければならない。`List.map` は `value` を期待する一方、`Integer.toString` は `n` を宣言しているので、明示のラムダで包んで合わせる。`List.fold` は `acc, value` を期待する。Map のコールバックは多くの場合 `key, value` を期待する。宣言全体は `stdlib/<Module>.md` で読む。複数行のラムダ内で意味を表す別名を束縛すれば、契約を変えずに済む。

穴は、対応するパラメータ名を記述順に保つ。直接の穴のないパイプは、宣言上の最初のパラメータを満たし、残りの引数にはラベルを要する。直接の穴がある場合や、右辺を括弧で囲んだ場合は、その結果の関数を一引数で呼ぶ。構成子の関数値は `arg1`、`arg2`、…の位置名を使う。レコード構成子の関数値はフィールド名を使い、レコードの取り出す関数は `value` を取る。

```benitoite
import Benitoite.Unofficial.IO.Console

function subtract(a: Integer, b: Integer) -> Integer
  return a - b
end function

function main() -> Unit uses Console.Write
  bind xs <- [1, 2, 3]
  bind doubled <- List.map(xs: xs, f: lambda(value) return value * 2)
  bind labels <- doubled |> List.map(f: lambda(value) return Integer.toString(value))
  Console.writeLine(labels |> String.join(separator: ","))
  bind swapped: function(b: Integer, a: Integer) -> Integer <- subtract(b: _, a: _)
  Console.writeLine("${swapped(b: 2, a: 9)}")
  bind make <- Pair
  bind pair <- make(arg1: 4, arg2: "four")
  Console.writeLine("${Pair.first(pair)} ${Pair.second(pair)}")
end function
```

```output
2,4,6
7
4 four
```

E0454 では、コールバックの名前を位置ごとに比べる。E0455 では、関数パラメータに名前を持つ関数型の注釈を付ける。呼び出しのラベル順から契約を決めることはできない。直接の構成子、パターン、属性、ハンドラの束縛、`resume` は、それぞれ専用の構文を保つ。

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
import Benitoite.Unofficial.IO.Process

function main() -> Unit uses File.Read, File.Write, Console.Write, Process.Exit
  bind lines <- try File.readLines("input.txt") or die
  bind total <- List.fold(xs: lines, initial: 0, f: lambda(acc, value)
    return match String.split(s: value, separator: " ") with
      case [_, count] -> acc + Option.unwrapOr(o: Integer.parse(count), fallback: 0)
      case otherFields -> acc
    end match
  end lambda)
  bind report <- "lines: ${List.length(lines)}\ntotal: ${total}\n"
  bind _ <- try File.writeText(path: "report.txt", text: report) or die
  bind _ <- try File.appendText(path: "report.txt", text: "done\n") or die
  Console.write(try File.readText("report.txt") or die)
  return ()
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
      match IOError.kind(error) with
        case IOErrorKind.NotFound -> Console.writeLine("missing.txt does not exist")
        case otherKind -> Console.writeLine("could not read: ${IOError.message(error)}")
      end match
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
import Benitoite.Unofficial.IO.Process

function main() -> Unit uses File.Read, File.Write, Console.Write, Process.Exit
  bind _ <- try File.createDirectory("out") or die
  bind names <- try File.listDirectory(".") or die
  List.forEach(xs: List.sort(names), f: lambda(value) Console.writeLine(value))
  bind found <- try File.exists("notes.md") or die
  Console.writeLine(match found with
    case true -> "notes.md exists"
    case false -> "no notes.md"
  end match)
  return ()
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
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.Json

function amountOf(order: Json.Value) -> Result[Pair[String, Integer], String]
  bind category <- Option.andThen(o: Json.get(value: order, k: "category"), f: Json.asString)
  bind amount <- Option.andThen(o: Json.get(value: order, k: "amount"), f: Json.asInteger)
  return match Pair(category, amount) with
    case Pair(Option.Some(c), Option.Some(a)) -> Result.Ok(Pair(c, a))
    case otherFields -> Result.Error("an order needs a category and an amount")
  end match
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try File.readText("orders.json") or die
  bind parsed <- try Json.parse(text) or die
  bind orders <- try Option.okOr(o: Json.asArray(parsed), error: "orders.json is not an array") or die
  bind totals <- List.fold(xs: orders, initial: Result.Ok(Map.empty()), f: lambda(acc, value)
    bind totalsMap <- try acc or return
    bind entry <- try amountOf(value) or return
    bind current <- Map.get(m: totalsMap, k: Pair.first(entry)) |> Option.unwrapOr(fallback: 0)
    return Result.Ok(Map.set(m: totalsMap, k: Pair.first(entry), value: current + Pair.second(entry)))
  end lambda)
  Map.forEach(m: try totals or die, f: lambda(key, value)
    Console.writeLine("${key}: ${value}")
  end lambda)
  return ()
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
import Benitoite.Unofficial.IO.Process

function scoreOf(row: Map[String, String]) -> Integer
  return Option.andThen(o: Map.get(m: row, k: "score"), f: lambda(value) return Integer.parse(value)) |> Option.unwrapOr(fallback: 0)
end function

function main() -> Unit uses File.Read, File.Write, Console.Write, Process.Exit
  bind text <- try File.readText("scores.csv") or die
  bind rows <- try Csv.parseWithHeader(text) or die
  bind passed <- List.filter(xs: rows, p: lambda(value) return scoreOf(value) >= 80)
  bind output <- List.map(xs: passed, f: lambda(value)
    return [Option.unwrapOr(o: Map.get(m: value, k: "name"), fallback: ""), Integer.toString(scoreOf(value))]
  end lambda)
  bind csv <- Csv.format(List.prepend(xs: output, x: ["name", "score"]))
  bind _ <- try File.writeText(path: "passed.csv", text: csv) or die
  Console.write(csv)
  Console.write(Csv.format([["Bob, Jr.", "75"]]))
  return ()
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

`Process.run` と `Process.runAttached` は、`Command.environment` に明示した名前が `DYLD_` または `LD_` で始まる場合、ASCII の大文字小文字を区別せず、子の起動やパイプの準備より前に拒否する。ビルドの道具が使う `LD_RUN_PATH`、小文字の名前、空値、継承した値と同じ値への設定も含む。`IOErrorKind.InvalidInput` を持つ `Result.Error` を返し、メッセージには元の名前の辞書順で最初の禁止変数名だけを入れ、値は入れない。NUL、空の名前、名前内の `=` に対する既存の検査が優先する。これは IO の失敗の値であり、新しい静的診断ではない。明示設定を見直して取り除くか、規則に適合する操作を選んで処理する。親の環境へ変数を移したり、シェルでコマンドを包んだりして回避しない。

この規則はすべての OS で常に適用するが、継承する変数は取り除かず、`Process.shell` も継承する。`Process.Run` を了承すれば、`env` やシェル自身による変数の設定も許す。この規則は、起動時の環境、`PATH`、コマンド固有の設定、孫プロセス、Windows の DLL 探索全体を制御しない。隔離はハーネスか OS で強制する。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process

function main() -> Unit uses Process.Run, Console.Write, Process.Exit
  bind printed <- try Process.run(Process.command(program: "echo", arguments: ["hello", "$HOME"])) or die
  Console.write(Process.Output.standardOutput(printed))
  bind sort <- Process.Command(..Process.command(program: "sort", arguments: []), environment: Map.fromList([Pair("LC_ALL", "C")]), input: Option.Some("pear\napple\n"))
  bind sorted <- try Process.run(sort) or die
  Console.write(Process.Output.standardOutput(sorted))
  bind failed <- try Process.run(Process.command(program: "sh", arguments: ["-c", "exit 3"])) or die
  Console.writeLine("exit code: ${Process.Output.exitCode(failed)}")
  return ()
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

function main() -> Unit uses Process.Run, Console.Write, Process.Exit
  bind piped <- try Process.shell("printf 'b\\na\\nc\\n' | LC_ALL=C sort | tr 'a-z' 'A-Z'") or die
  Console.write(Process.Output.standardOutput(piped))
  bind checked <- try Process.shell("if [ -d / ]; then echo root; fi; echo oops >&2; exit 2") or die
  Console.write(Process.Output.standardOutput(checked))
  Console.write("stderr: ${Process.Output.standardError(checked)}")
  Console.writeLine("exit code: ${Process.Output.exitCode(checked)}")
  return ()
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

function main() -> Unit uses Process.Environment, Console.Write, Process.Exit
  bind arguments <- Process.arguments()
  Console.writeLine("arguments: ${List.length(arguments)}")
  bind name <- match arguments with
    case [first, ..] -> first
    case [] -> "world"
  end match
  Console.writeLine("Hello, ${name}!")
  bind unset <- try Process.environmentVariable("BENITOITE_SKILL_EXAMPLE_UNSET") or die
  Console.writeLine(Option.unwrapOr(o: unset, fallback: "(not set)"))
  return ()
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
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Network.Http

function route(request: Http.Request) -> Http.Response
  return match Pair(Http.Request.method(request), Http.pathSegments(Http.Request.path(request))) with
    case Pair("GET", ["hello", name]) -> Http.text(status: 200, s: "Hello, ${name}!")
    case Pair("GET", ["items"]) -> Http.json(status: 200, value: Json.Value.Array([Json.Value.Integer(1), Json.Value.Integer(2)]))
    case otherPath -> Http.text(status: 404, s: "not found")
  end match
end function

function serveLoop(listener: Http.Listener, remaining: Integer) -> Result[Unit, String] uses Http.Listen, State
  if remaining = 0 then return Result.Ok(()) end if
  bind exchange <- try Http.accept(listener) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error)) or return
  bind _ <- try Http.respond(exchange: exchange, response: route(Http.requestOf(exchange))) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error)) or return
  bind _ <- try Http.closeExchange(exchange) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error)) or return
  return serveLoop(listener: listener, remaining: remaining - 1)
end function

function show(response: Http.Response) -> Unit uses Console.Write
  bind body <- Option.unwrapOr(o: String.fromUTF8(Http.Response.body(response)), fallback: "(not UTF-8)")
  return Console.writeLine("${Http.Response.status(response)} ${body}")
end function

function main() -> Unit uses Http.Listen, Http.Connect, Console.Write, State, Process.Exit
  with listener = try Http.listen(host: "127.0.0.1", port: 0) or die,
    group = TaskGroup.open() do
    bind base <- "http://127.0.0.1:${Http.listenerPort(listener)}"
    bind server <- TaskGroup.spawn(group: group, action: lambda() return serveLoop(listener: listener, remaining: 3))
    bind hello <- try Http.get(base + "/hello/Ada") or die
    bind items <- try Http.get(base + "/items") or die
    bind request <- Http.ClientRequest(..Http.clientRequest(method: "POST", url: base + "/upload"), body: String.toUTF8("data"))
    bind missing <- try Http.send(request) or die
    bind _ <- try Task.await(server) or die
    List.forEach(xs: [hello, items, missing], f: lambda(value) show(value))
    return ()
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
    case [] -> Http.html(status: 200, s: "<h1>Home</h1>")
    case ["health"] -> Http.text(status: 200, s: "ok")
    case otherPath -> Http.text(status: 404, s: "not found")
  end match
end function

function main() -> Result[Unit, String] uses Http.Listen, State
  return Http.serve(host: "127.0.0.1", port: 8080, handler: respondTo) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error))
end function
```

## コレクション

リスト、マップ、集合は永続である。関数は新しいコレクションを返し、元のコレクションを変えない。マップと集合は、加えた順ではなくキーの順に並ぶので、`Map.forEach` と `Set.toList` はキーを整列した順に辿る。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind numbers <- List.range(start: 1, stop: 6)
  bind squares <- List.map(xs: numbers, f: lambda(value) return value * value)
  bind even <- List.filter(xs: squares, p: lambda(value) return value mod 2 = 0)
  Console.writeLine("${List.length(numbers)} numbers, sum ${List.fold(xs: numbers, initial: 0, f: lambda(acc, value) return acc + value)}")
  Console.writeLine(String.join(xs: List.map(xs: even, f: lambda(value) return Integer.toString(value)), separator: ", "))
  bind words <- String.split(s: "the cat saw the dog", separator: " ")
  bind counts <- List.fold(xs: words, initial: Map.empty(), f: lambda(acc, value)
    return Map.set(m: acc, k: value, value: Option.unwrapOr(o: Map.get(m: acc, k: value), fallback: 0) + 1)
  end lambda)
  Map.forEach(m: counts, f: lambda(key, value) Console.writeLine("${key}=${value}"))
  Console.writeLine(String.join(xs: Set.toList(Set.fromList(words)), separator: " "))
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

`List.range(start: start, stop: stop)` は `stop` の手前で止まる。リストに添字の演算子はない。`List.get(xs: xs, i: i)` を使う。これは `Option` を返す。

繰り返しは、再帰か、`List.forEach`・`List.map`・`List.fold` で書く。最後に自身を呼ぶ関数（`return f(...)`）は、スタックを伸ばさない。

```benitoite
import Benitoite.Unofficial.IO.Console

function countDown(n: Integer, acc: List[String]) -> List[String]
  if n = 0 then return List.reverse(acc) end if
  return countDown(n: n - 1, acc: List.prepend(xs: acc, x: Integer.toString(n)))
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(String.join(xs: countDown(n: 5, acc: []), separator: " "))
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
  List.forEach(xs: [3, 4, 5], f: lambda(value) Reference.set(reference: counter, value: Reference.get(counter) + value))
  return Console.writeLine("total ${Reference.get(counter)}")
end function
```

```output
total 12
```

Character の範囲で Unicode スカラー値の全域を覆う場合は、包括的な最後の分岐は不要である。`case '\u{0}'..'\u{10ffff}' ->` を使うか、`'\u{d7ff}'` と `'\u{e000}'` の間で分ける。レコード、構成子、リストの内部と、全域の範囲を使う bind のパターンにも適用する。その後の包括的な分岐は到達しない（E0602）。コンマで並べた冗長な選択肢は E0608 になる。ガードでは網羅性を成立させず、Integer の範囲には引き続き包括的な分岐を要する。網羅していない文字の match では具体的な未被覆のスカラー値を報告する。例えば `'a'` だけを覆う場合は `'\u{0}'` となる。

## レコードとデータ型

レコードは名前の付いたフィールドを持つ。フィールドは `Type.field(value)` で読み、一部を変えた写しは `Type(..value, field: new)` で作る。データ型はその構成子を並べる。構成子は常に型の名前を付けて書く。

外部のパターンに将来の形も覆うことを求めるには、データ型かレコードの宣言に、引数のない属性 `@extensible` を使う。`public` または `public(package)` があれば、その前に置く。定義したパッケージの中では、現在の構成子の列挙で網羅的と判定できる。外では、ガードのない `case other ->` または `case _ ->` を含める。`Other` という名前の既知の構成子は、将来の形を覆わない。ガード付きの分岐は網羅性に数えない。この規則は、型の別名を通した位置や、`Result`、`Option`、リスト、レコードのフィールドの中にも適用する。パッケージの境界は `public(package)` と同じであり、同じパッケージの別のモジュールも内部に当たる。

標準の失敗型 `IOErrorKind`、`NetworkErrorKind`、`Json.ParseError`、`Json.Codec.ConversionError`、`Csv.ParseError` は、この属性を持つ。`Result` と `Option` は閉じた型のままであり、`Result.Error(error)` はエラーを分解せずに全体を束縛する。二つの ParseError レコードでは、分解よりも `Json.ParseError.message(error)` または `Csv.ParseError.message(error)` を推奨する。`..` を持つレコードパターンは現在の形だけを覆うため、外部の `match` には、別の変数か `_` の分岐を要する（`E0601`）。分解する `bind` や `shadow` は拒否する（`E0607`）。構築・更新・フィールドの取り出しは、引き続き宣言したフィールドを使う。この属性は、レコードのフィールドの追加の互換性を約束しない。

拡張可能なデータ型への構成子の追加は、外部のパターンの網羅性を保つ。ただし、以前 `Other` で表した値を分類し直す場合など、結果を変えることがある。構成子の削除・改名・フィールドの変更は、この保証の範囲外である。閉じた型への属性の追加は、既存の外部のパターンを拒否することがある。属性を取り除くと、集合を閉じたものとする契約になり、分岐が到達不能になることがある。呼び出し側が構成子を追加したり、実行時のタグ、ABI、等価性、キーの制約を変えたりできるようにはならない。WIT の照合は厳密なままであり、この属性は未知の外部のタグを許さない。

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
  List.forEach(xs: shapes, f: lambda(value) Console.writeLine(Float.toString(area(value))))
  return ()
end function
```

```output
pen: 1200
3.0
7.0
```

## テストの書き方

テストは、`@test("description")` を付けた関数であり、引数を取らず、`Unit` か `Result[Unit, String]` を返す。`try e or return` を使うテストは `Result[Unit, String]` を返し、`Result.Error(message)` を返すとテストは失敗する。結果は `Assert.equal(actual: actual, expected: expected)` と `Assert.isTrue(condition: condition, message: message)`（エフェクト `Assert.Check`）で確かめる。修正中は `benitoite test --check file.bnt` で実行せずに検査する。確認の直前に `benitoite test --check --report=json file.bnt` で報告を一度取得し、`Assert.Check` を含めてエフェクトを見直してから、`benitoite test --allow-effects=<accepted names> file.bnt` で実行する。`main` のないテストのファイルに `benitoite check` を実行しない。報告と実行全体の拒否の規則は、[実行前の検査](inspection.md)を参照する。

```benitoite test
function slugify(title: String) -> String
  return String.join(xs: String.split(s: String.toLowercase(String.trim(title)), separator: " "), separator: "-")
end function

@test("slugify lowercases and joins words")
function slugifyJoins() -> Unit uses Assert.Check
  Assert.equal(actual: slugify(" Hello World "), expected: "hello-world")
  Assert.isTrue(condition: String.contains(s: slugify("A B"), part: "-"), message: "the words are joined with -")
end function
```

テストでは、組み込みの操作を `handle ... with case Op(args) -> ...` で置き換える。本物の操作の代わりにハンドラが動くので、テストはファイルに触れず、コマンドも起動しない。`resume(value)` は、操作を呼んだコードへ `value` を返す。エフェクトの一部の操作を扱っても、型からそのエフェクトは消えない。そのため、テストは `uses` に `File.Read` と `Process.Run` をなお並べる。型に `State` を持つ関数（`Reference`、`TaskGroup`、`Task.await`、`close...` の関数）は、`case` で扱えない。

```benitoite test
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function countWords(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(List.length(List.filter(xs: String.split(s: text, separator: " "), p: lambda(value) return value <> "")))
end function

function gitBranch() -> Result[String, String] uses Process.Run
  bind output <- try Process.run(Process.command(program: "git", arguments: ["branch", "--show-current"])) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(String.trim(Process.Output.standardOutput(output)))
end function

@test("countWords reads the file through File.readText")
function countWordsReadsFile() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    countWords("notes.txt")
  with
    case File.readText(path) ->
      Assert.equal(actual: path, expected: "notes.txt")
      resume(Result.Ok("one two  three"))
  end handle
  Assert.equal(actual: result, expected: Result.Ok(3))
end function

@test("gitBranch runs git without starting it")
function gitBranchRunsGit() -> Unit uses Assert.Check, Process.Run
  bind result <- handle
    gitBranch()
  with
    case Process.run(command) ->
      Assert.equal(actual: Process.Command.program(command), expected: "git")
      resume(Result.Ok(Process.Output(exitCode: 0, standardOutput: "main\n", standardError: "")))
  end handle
  Assert.equal(actual: result, expected: Result.Ok("main"))
end function
```

## 数値のビット幅と変換

通常の名前には、別名の `Integer`、`Float`、`Byte` を使う。それぞれの正式な名前は `Integer64`、`Float64`、`UnsignedInteger8` であり、`UnsignedInteger` は `UnsignedInteger64` の別名である。別名は同じ型を表す。七つの型（`Integer8`、`Integer16`、`Integer32`、`UnsignedInteger16`、`UnsignedInteger32`、`UnsignedInteger64`、`Float32`）は、それぞれ異なる型である。数値の型とモジュールはすべて prelude にあり、取り込みは要らない。

接尾辞でビット幅を明示的に選ぶ。`42s16`、`0xffu8`、`65535u16`、`18446744073709551615u64`、`1.5f32` のように書く。接尾辞のない値は `Integer` か `Float` のままであり、期待する型によって変わることはない。接尾辞の表記は暫定であり、構文の見直しで変わることがある。浮動小数点の接尾辞には小数点か指数が要る（`1f32` ではなく `1.0f32`）。符号付きリテラルの範囲の検査に符号を含めるのは、直接付けた負号だけである。`-128s8` は使えるが、`-(128s8)` は使えない。符号なしの型では、0 であっても単項の負号を使えない。`Byte` に算術演算はない。`Integer8`、`Integer16`、`Integer32`、符号なし整数の型、`Byte`、`Float32` は、定数のパターンにも範囲のパターンにもできない。束縛した名前とガードを使う。

範囲を検査する変換は `Option` を返し、整数の算術演算の桁あふれと 0 による除算は実行を止める。狭い整数のモジュールは、`Integer` を通して変換する。`UnsignedInteger64.toInteger` は、その範囲の上半分が収まらないため `Option` を返す。`toDecimal` は全範囲で正確に変換する。`Float32.fromFloat` は丸めを行い、有限の入力が無限大になると `None` を返す。`Float32.toFloat` は、有限の値を正確に広い型へ変換する。算術演算は各演算の後に binary32 に丸める。各関数のシグネチャは、対応する生成のモジュールの参照文書で読む。

```benitoite
import Benitoite.Unofficial.IO.Console

function smallInteger(text: String) -> Option[Integer16]
  bind value <- try Integer.parse(text) or return
  return Integer16.fromInteger(value)
end function

function main() -> Unit uses Console.Write
  bind value <- Option.unwrapOr(o: smallInteger("42"), fallback: 0s16)
  bind wide: UnsignedInteger <- 18446744073709551615u64
  Console.writeLine("${value + 1s16} ${smallInteger("32768") = Option.None}")
  Console.writeLine("${UnsignedInteger64.toDecimal(wide)} ${UnsignedInteger64.toInteger(wide) = Option.None}")
  Console.writeLine("${Float32.toFloat(1.5f32)} ${Byte.toInteger(255u8)}")
end function
```

```output
43 true
18446744073709551615 true
1.5 255
```

## WASM の外部の関数と WIT の型

外部の関数は、本体も `end function` も付けずに宣言し、呼ぶ前にコンポーネントの実際の WIT の契約を確かめる。コンポーネントは、取り込みのないバイナリの Component Model のコンポーネントでなければならず、WASI もホストの関数も使えない。パスは宣言が属する根からの相対パスであり、パッケージのコンポーネントは `wasm/` の下に置かなければならない。公開名は world の関数か `interface#function` であり、版を含むインターフェースの完全な名前と一致させる。宣言は単相であり、具体的な型を使う。実際の引数と結果のフィールドに外部のリソース型を含む関数には `uses State` が要り、ほかの関数は純粋である。

| Benitoite の型 | WIT との対応 |
|---|---|
| `Integer8`/`Integer16`/`Integer32`/`Integer` | `s8`/`s16`/`s32`/`s64` |
| `Byte`/`UnsignedInteger16`/`UnsignedInteger32`/`UnsignedInteger64` | `u8`/`u16`/`u32`/`u64` |
| `Float32`/`Float` | `f32`/`f64` |
| `Bytes`, `List[Byte]`。ほかのリスト、オプション、結果 | `list<u8>`。WIT の list/option/result に再帰的に対応する |
| 具体的なレコードと `data` | 型引数を置き換えた後、宣言の順序と正規化した名前でフィールドとケースを照合する |
| `Set[D]`。D は引数のない構成子を 1〜32 個持つ | `flags`。何も選択しない値も許される |
| `Map[K, V]` | `map`。K は Boolean、整数型、Character、String のいずれかであり、V は対応する任意の型 |
| `Pair`、`Triple`、または引数を一つ以上持つほかの単一の構成子の `data` | 引数の位置に対応する `tuple` |
| 複数の引数を持つ variant の構成子 | 平らなタプル一つをペイロードとし、戻すときはそれらの引数に振り分ける |

レコードとケースの名前は、ハイフンを除き、ASCII の英字を小文字にして照合する。型パラメータを持つ型の有限の入れ子は許されるが、再帰する宣言と未解決の型変数・エフェクト変数は拒む。関数、Decimal、通常の Set の型、タスク、`with` で使うリソースは渡せない。`Unit` は、関数の省略した結果か、標準の `Result` の省略した片側としてだけ許される。

これらの宣言は、リポジトリの実行可能な例 `external/wit-docs-values` で使うコンポーネントの例に対応する。

```text
record Box[T]
  value: T
end record
@external("wasm", "generic.wasm", "box")
function box(v: Box[Integer]) -> Box[Integer]
@external("wasm", "generic.wasm", "nested")
function nested(v: Box[Box[Integer]]) -> Box[Box[Integer]]

data D1
  F1
end data
@external("wasm", "flags.wasm", "f1")
function f1(v: Set[D1]) -> Pair[Set[D1], Integer]

@external("wasm", "maps.wasm", "result")
function result(v: Map[String, Integer]) -> Map[String, Integer]

data Four
  Item(Integer, Integer, Integer, Integer)
end data
@external("wasm", "tuples.wasm", "tuple4")
function tuple4(v: Four) -> Four

data Two
  Value(Integer, Integer)
  Empty
end data
@external("wasm", "variants.wasm", "fields")
function two(v: Two) -> Two
```

WIT の形は、`value: s64` を持つレコード、入れ子のレコード、結果がタプルの `flags { f1 }`、`map<string, s64>`、4 要素の `tuple<s64, s64, s64, s64>`、`variant { value(tuple<s64, s64>), empty }` である。例のゲストは、`box(Box(value: 35))` から 42、`nested(Box(value: Box(value: -7)))` の内側の値として 0、`f1(Set.empty())` から `Pair(Set.fromList([D1.F1]), 0)`、`tuple4(Four.Item(1, 2, 3, 4))` から `Four.Item(12, 14, 16, 18)`、`two(Two.Value(3, 7))` から `Two.Value(14, 29)` を返す。例の `Map.toList(result(Map.empty()))` は `[Pair("a", 2), Pair("z", 3)]` である。返された各項目は正規化の前にすべて検査し、キーが重複すれば最後の値を残し、最終的なマップはキーの順に並ぶ。これらの数値の変換は、例のゲストの動作である。

検査器は実行の前に `typed`、`adapter`、`dynamic`、`stateful` のいずれかを選び、失敗の後に試し直すことはない。`typed` の経路は、バイト数と要素数を数える。ほかの対応する値は生成したアダプタを使い、外部のリソース型は状態を持つ動的な経路を使う。アダプタの生成や配置の上限によって、呼び出し前に動的な経路を選ぶことがある。生成したコードとコンパイル済みのコードは一回の実行の中で共有するが、純粋な呼び出しは毎回新しい Store を使う。

既定の上限は、燃料 10^10、ゲストとアダプタの線形メモリの合計 64 MiB、コアのインスタンス・メモリ・テーブル各 16 個、テーブルごとに 10,000 要素、方向ごとに転送量 256 MiB である。アダプタは、32 バイトのヘッダと詰め物を含め、詰めて格納した引数と結果の列全体を数える。それとは別に、同じ `--wasm-transfer` の値で、方向ごとの論理的な構築量も制限する。言語の値が現れるごとに 16 バイトを数え、文字列と Bytes の内容を加える。Bytes の要素は別の値として数えないが、List[Byte] の要素は数える。キーの重複の正規化で捨てる Map の項目も数える。ABI のためだけの、値をまとめるタプルは言語の値を加えない。これらの上限はプロセスのメモリ全体を制限しない。アダプタの命令は燃料を消費し、SIGINT/SIGTERM に応じる。`Task.withTimeout` は外部呼び出しを取り消せない。文字列、Bytes、リストの大きさの上限も適用する。

`run` と `test` の `--wasm-stats` を使って、経路、代替の経路を選んだ理由、転送量、`construction_bytes`（両方向の合計）、アダプタの失敗を調べる。`--wasm-memory`、`--wasm-fuel`、`--wasm-transfer` は、関数の契約を変えずに上限を変える。燃料の枯渇は R0904、転送量・構築量・メモリの枯渇は R0905、対象数の上限は R0906、戻り値の大きさの上限は R0902 を報告する。トラップとゲストの ABI 違反は R0601 を報告し、宣言した `Result.Error` は通常の値である。これらの実行時の失敗は `match` や `try` で捕えられない。
