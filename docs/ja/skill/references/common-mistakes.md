# Benitoite でよくある誤り

> この文書は、`crates/benitoite/skill/references/common-mistakes.md` の日本語の訳である。翻訳元は Benitoite 0.0.6 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

<!--
このファイルのコードの例の検査の方法（tests/skill_examples.rs）:
- `benitoite error` のブロックは `benitoite check` で失敗しなければならず、後に続く `diagnostic` のブロックの各行が報告に現れなければならない。
- `benitoite` のブロックは実行し、その標準出力を、後に続く `output` のブロックと比べる。
  `output` のブロックの最後の行 `exit N` は、期待する終了コードである（ないときは 0）。
  `output` のブロックの後の `stderr` のブロックは、期待する標準エラー出力である（ないときは空）。
- `benitoite check` のブロックは検査だけを行う。誤りも警告もあってはならない。
- `benitoite test` のブロックは `benitoite test` で実行する。そのテストはすべて通らなければならない。
- 例の前の `files` のブロックは、スクリプトの隣にファイルを作る。最初の行は `name: <ファイル名>`、残りが中身である。
- ほかの情報文字列のブロック（`text` など）は検査しない。
- この訳のコードの例は検査しない。検査するのは英語の版である。
-->

ほかの言語の癖のうち `benitoite check` が拒むものを、報告の最初の行と正しい書き方とあわせて示す。報告に知らないコードがあれば、[`diagnostics.md`](../../../../crates/benitoite/skill/references/diagnostics.md) で調べる。

## 目次

- [`bind` の代わりの `let`](#bind-の代わりの-let)
- [同じ名前を二度束縛する](#同じ名前を二度束縛する)
- [ブロックの波括弧](#ブロックの波括弧)
- [C の流儀の演算子](#c-の流儀の演算子)
- [`:` の後の戻り値の型](#-の後の戻り値の型)
- [型の名前のない構成子](#型の名前のない構成子)
- [IO のモジュールの取り込みを忘れる](#io-のモジュールの取り込みを忘れる)
- [非公式のモジュールを `Benitoite.X` として取り込む](#非公式のモジュールを-benitoitex-として取り込む)
- [`uses` を忘れる](#uses-を忘れる)
- [`Result` を無視する](#result-を無視する)
- [`return` のない最後の式](#return-のない最後の式)
- [`for` と `while` の繰り返し](#for-と-while-の繰り返し)
- [キーワードを名前に使う](#キーワードを名前に使う)
- [契約と異なるコールバックのパラメータ名](#契約と異なるコールバックのパラメータ名)
- [ラムダの引数としての `_`](#ラムダの引数としての-_)

## `bind` の代わりの `let`

```benitoite error
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  let total = 1 + 2
  return Console.writeLine(Integer.toString(total))
end function
```

```diagnostic
error[E0230]: `let` is not used to bind names
```

`bind name <- expression` と書く:

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind total <- 1 + 2
  return Console.writeLine(Integer.toString(total))
end function
```

```output
3
```

## 同じ名前を二度束縛する

`bind` は、既に局所の名前であるものを再び使えない。新しい値の意味を表す別の名前を推奨する。`shadow` は明示的に古い名前を隠せるが、意図的な隠蔽であっても推奨しない。有効な構文として残り、警告は出ない。

```benitoite error
function next(n: Integer) -> Integer
  bind x <- n
  bind x <- x + 1
  return x
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0334]: `x` is already a local name here
```

```benitoite
import Benitoite.Unofficial.IO.Console

function next(n: Integer) -> Integer
  bind x <- n
  bind increased <- x + 1
  return increased
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(Integer.toString(next(41)))
end function
```

```output
42
```

## ブロックの波括弧

短いラムダ（`grammar.md` を参照する）を除き、ブロックは、`end` とブロックを開いたキーワードで終わる。`end function`、`end if`、`end match`、`end lambda`、`end handle`、`end with`、`end data`、`end record` である。

```benitoite error
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write {
  return Console.writeLine("hi")
}
```

```diagnostic
error[E0212]: blocks are not written with braces
```

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  match 1 < 2 with
    case true -> Console.writeLine("hi")
    case false -> Console.writeLine("bye")
  end match
  return ()
end function
```

```output
hi
```

## C の流儀の演算子

`==`、`!=`、`&&`、`||`、`!` は演算子ではない。等しいは `=`、等しくないは `<>` で書き、論理の演算子は語 `and`、`or`、`not` である。

```benitoite error
function inRange(n: Integer) -> Boolean
  return n >= 0 && n != 10
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0211]: `&&` is not an operator in Benitoite
```

```benitoite error
function isZero(n: Integer) -> Boolean
  return n == 0
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0211]: `==` is not an operator in Benitoite
```

```benitoite
import Benitoite.Unofficial.IO.Console

function inRange(n: Integer) -> Boolean
  return n >= 0 and n <> 10 and not (n = 7)
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(match inRange(3) with
    case true -> "yes"
    case false -> "no"
  end match)
end function
```

```output
yes
```

## `:` の後の戻り値の型

```benitoite error
function double(n: Integer): Integer
  return n * 2
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0234]: the return type is written after `->`
```

```benitoite
import Benitoite.Unofficial.IO.Console

function double(n: Integer) -> Integer
  return n * 2
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(Integer.toString(double(21)))
end function
```

```output
42
```

## 型の名前のない構成子

`Some`、`None`、`Ok`、`Error` と、自分で定義した `data` の型の構成子は、型の名前を付けて書く。`Option.Some(x)`、`Option.None`、`Result.Ok(x)`、`Result.Error(e)`、`Shape.Circle(r)` のように書く。パターンでも同じである。

```benitoite error
function first(xs: List[Integer]) -> Option[Integer]
  return match xs with
    case [] -> None
    case [x, ..] -> Some(x)
  end match
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0331]: the constructor `None` must be written with its type name
```

```benitoite
import Benitoite.Unofficial.IO.Console

function first(xs: List[Integer]) -> Option[Integer]
  return match xs with
    case [] -> Option.None
    case [x, ..] -> Option.Some(x)
  end match
end function

function main() -> Unit uses Console.Write
  return match first([7, 8]) with
    case Option.Some(x) -> Console.writeLine(Integer.toString(x))
    case Option.None -> Console.writeLine("empty")
  end match
end function
```

```output
7
```

## IO のモジュールの取り込みを忘れる

`Console`、`File`、`Process`、`Clock`、`Random`、`Json`、`Csv`、`Http` など、prelude の外のモジュールは取り込まなければならない。`uses` にだけ現れるときも同じである。

```benitoite error
function main() -> Unit uses Console.Write
  return Console.writeLine("hi")
end function
```

```diagnostic
error[E0332]: the module `Console` is not imported
```

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  return Console.writeLine("hi")
end function
```

```output
hi
```

## 非公式のモジュールを `Benitoite.X` として取り込む

非公式のモジュールは `Benitoite.Unofficial` の下から取り込む。各モジュールの取り込みの名前は、[`stdlib/index.md`](../../../../crates/benitoite/skill/references/stdlib/index.md) の表にある。

```benitoite error
import Benitoite.IO.Console

function main() -> Unit uses Console.Write
  return Console.writeLine("hi")
end function
```

```diagnostic
error[E0321]: `Benitoite.IO.Console` is not a standard library module
```

正しい取り込みは、前の節のとおり `import Benitoite.Unofficial.IO.Console` である。モジュールは、取り込んだ後も `Console` の名前で参照する。

## `uses` を忘れる

エフェクトを起こす関数は、直接でも、呼ぶ関数を通してでも、そのエフェクトを `uses` の後に並べる。

```benitoite error
import Benitoite.Unofficial.IO.Console

function greet(name: String) -> Unit
  return Console.writeLine("Hello, ${name}!")
end function

function main() -> Unit uses Console.Write
  return greet("Ada")
end function
```

```diagnostic
error[E0501]: this function performs `Console.Write` but does not declare it
```

```benitoite
import Benitoite.Unofficial.IO.Console

function greet(name: String) -> Unit uses Console.Write
  return Console.writeLine("Hello, ${name}!")
end function

function main() -> Unit uses Console.Write
  return greet("Ada")
end function
```

```output
Hello, Ada!
```

## `Result` を無視する

値が `Unit` でない文は誤りである。失敗しうる IO の関数は `Result` を返す。`try` か `match` で扱い、誤りを本当に無視したいときに限って `_` に束縛する。

再利用するコードでは `try operation or return` と書き、対応する Result/Option の戻り値の型を保つ。終了する入口では、`uses Process.Exit` と `import Benitoite.Unofficial.IO.Process` を付けて `try operation or die` と書く。ホストの die の報告だけのために Console.Write を加えない。Result のエラーには Show を要する。IOError、NetworkError、Json.ParseError、Csv.ParseError は既に実装を持つので、表示だけのために String へ変換しない。裸の try は main の中でも常に失敗を返し、die を推測しない。完全な明示形の例は[プログラムの形と誤りの扱い](idioms.md#プログラムの形と誤りの扱い)を参照する。

明示した処置は try の式を終える。`try r or return + 1` ではなく `(try r or return) + 1` と書く。`or return` は値を取らず、`die()` と `die(a, b)` は無効である。説明は失敗時にだけ評価する純粋な String であり、直接の return・try・外側の resume を含められない。開き括弧は die と同じ物理行で始める。短いラムダは、処置と説明の全体を一行に収める必要がある。

```benitoite error
import Benitoite.Unofficial.IO.File

function main() -> Unit uses File.Write
  File.writeText(path: "out.txt", text: "data")
  return ()
end function
```

```diagnostic
error[E0416]: the value of this expression is not used
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function main() -> Unit uses File.Write, Console.Write, Process.Exit
  bind _ <- try File.writeText(path: "out.txt", text: "data") or die
  Console.writeLine("written")
  return ()
end function
```

```output
written
```

## `return` のない最後の式

関数の本体は、`return` で値を返す。ラムダの本体も、値が `Unit` でない限り `return` を要する。値は `return` と同じ物理行で書き始める。直後の改行は、括弧の中でも、次の行の先頭が演算子でも E0201 になる。コメントや空行を挟んでも、値を後の行から書き始めることはできない。書き始めた後は、通常の継続の規則で複数行にできる。`return x +` の後に次のオペランド、`return (` の後に括弧で囲む値、`return f(` の後に引数、`return if condition then` の後に分岐を続けられる。短いラムダは、全体を一つの物理行に収める必要がある。`benitoite fmt` は誤りを報告し、ファイルを変えない。行を結合することはない。

```benitoite error
function next(n: Integer) -> Integer
  n + 1
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0416]: the value of this expression is not used
```

```benitoite
import Benitoite.Unofficial.IO.Console

function next(n: Integer) -> Integer
  return n + 1
end function

function main() -> Unit uses Console.Write
  bind doubled <- List.map(xs: [1, 2], f: lambda(value) return value * 2)
  return Console.writeLine("${next(1)} ${String.join(xs: List.map(xs: doubled, f: lambda(value) return Integer.toString(value)), separator: ",")}")
end function
```

```output
2 2,4
```

## `for` と `while` の繰り返し

繰り返しの文はない。`List.forEach`、`List.map`、`List.fold` か、再帰の関数を使う。

```benitoite error
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  for x in [1, 2, 3] do
    Console.writeLine(Integer.toString(x))
  end for
  return ()
end function
```

```diagnostic
error[E0201]: expected a newline or the end of the block, found `x`
```

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  List.forEach(xs: [1, 2, 3], f: lambda(value)
    Console.writeLine(Integer.toString(value))
  end lambda)
  return ()
end function
```

```output
1
2
3
```

## キーワードを名前に使う

次の 35 語はキーワードであり、名前にできない。`and`、`bind`、`case`、`const`、`data`、`die`、`div`、`do`、`effect`、`else`、`end`、`false`、`function`、`handle`、`if`、`implement`、`import`、`lambda`、`lazy`、`match`、`mod`、`not`、`or`、`public`、`record`、`resume`、`return`、`shadow`、`then`、`trait`、`true`、`try`、`type`、`uses`、`with`。別の名前を選ぶ。この制限は、引数のラベル、フィールド、取り込みの別名、ドットの後の名前にも適用する。`die` は失敗時の処置 `try value or die` と `try value or die(message)` としてだけ受理する。単独の `die` の式は拒否する。`Die`、`died`、`dieLater` は通常の識別子である。

`fn`、`pub`、`impl`、`mut` は通常の名前であり、構文の略記ではない。宣言には `function`、`public`、`implement`、無名関数には `lambda` を使う。`for`、`while`、`loop`、`break`、`continue`、`switch`、`where`、`async`、`await`、`spawn`、`select` も予約語ではない。繰り返しには `List.map`、`List.fold`、`List.forEach` などのコレクションの関数、並行処理には `Task.await`、`TaskGroup.spawn`、`Task.race` などの API を使う。

`as` は取り込みの宣言の中でだけ特別な意味を持つ。`language`、`dependency`、`package` とヘッダのフィールド名は、ファイルのヘッダで特別に読む。`equality` と `key` は組み込みの制約名であり、`ordered` は標準ライブラリのソースでだけ使える制約である。属性名（`external`、`test`、`deprecated`、`extensible`、標準ライブラリ専用の `builtin`）は、属性の外では通常の識別子である。`@extensible` は、データ型かレコードの宣言に引数なしで書く。定義したパッケージの外では、ガードのない変数か `_` で将来の形を覆う。`Other` を含む全既知構成子の列挙だけでは足りない。四つの標準の失敗型とレコードの分解の制限は、[レコードとデータ型](idioms.md#レコードとデータ型)を参照する。レコードパターンの `..` は将来の形を覆わない。取り出す関数を使うか、拒否された束縛を、ガードのない `case _ ->` の分岐を持つ `match` に書き直す。

```benitoite error
function handle(request: String) -> String
  return request
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0216]: `handle` is a keyword and cannot be used as a name
```

## 契約と異なるコールバックのパラメータ名

`List.map` が期待する型は `function(value: T) -> U` である。ラムダのパラメータを `x` と名付けると、その契約が変わる。暗黙に `value` へ改名されることはない。一引数のコールバックでも名前は一致しなければならず、複数のパラメータを持つコールバックでは順序も一致しなければならない。

```benitoite error
function main() -> Unit
  bind _ <- List.map(xs: [1, 2], f: lambda(x) return x * 2)
  return ()
end function
```

```diagnostic
error[E0454]: function parameter names do not match
```

パラメータと束縛された参照を一緒に改名し、`List.map(xs: [1, 2], f: lambda(value) return value * 2)` とする。パラメータが `n` である `Integer.toString` などの既存の関数を渡すには、`lambda(value) return Integer.toString(value)` で包む。意味を表す局所名が必要なら、複数行のラムダ内で別名を束縛する。未使用のパラメータも必要な名前を保つ。完全な例は `idioms.md` を参照する。

## ラムダの引数としての `_`

`_` だけではラムダのパラメータにできない。未使用でも、コールバックの契約が求めるパラメータ名を保つ。`Map.filter` が求める名前は `key, value` なので、使わないキーも `key` と名付ける。期待する契約のない独立したラムダでは、`_key` などの識別子も有効だが、その識別子が関数型の一部となる。

```benitoite error
function evens(m: Map[String, Integer]) -> Map[String, Integer]
  return Map.filter(m: m, p: lambda(_, value) return value mod 2 = 0 end lambda)
end function

function main() -> Unit
  return ()
end function
```

```diagnostic
error[E0210]: `_` cannot be a lambda parameter
```

```benitoite
import Benitoite.Unofficial.IO.Console

function evens(m: Map[String, Integer]) -> Map[String, Integer]
  return Map.filter(m: m, p: lambda(key, value) return value mod 2 = 0 end lambda)
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(String.join(xs: Map.keys(evens(Map.fromList([Pair("a", 1), Pair("b", 2)]))), separator: ","))
end function
```

```output
b
```
