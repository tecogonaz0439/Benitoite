# Benitoite でよくある誤り

> この文書は、`crates/benitoite/skill/references/common-mistakes.md` の日本語の訳である。訳した元は、コミット d2a00c7 の英語の版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

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

- `bind` の代わりの `let`
- 同じ名前を二度束縛する
- ブロックの波括弧
- C の流儀の演算子
- `:` の後の戻り値の型
- 型の名前のない構成子
- IO のモジュールの取り込みを忘れる
- 非公式のモジュールを `Benitoite.X` として取り込む
- `uses` を忘れる
- `Result` を無視する
- `return` のない最後の式
- `for` と `while` の繰り返し
- キーワードを名前に使う
- ラムダの引数としての `_`

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

`bind` は、すでに局所の名前になっている名前を使い直せない。古い名前を意図して隠すなら `shadow` を使い、そうでなければ新しい名前を選ぶ。

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
  shadow x <- x + 1
  return x
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(Integer.toString(next(41)))
end function
```

```output
42
```

## ブロックの波括弧

ブロックは、`end` と、ブロックを始めたキーワードで終える。`end function`、`end if`、`end match`、`end lambda`、`end handle`、`end with`、`end data`、`end record` である。

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
  if 1 < 2 then
    Console.writeLine("hi")
  else
    Console.writeLine("bye")
  end if
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
  return Console.writeLine(if inRange(3) then "yes" else "no" end if)
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

```benitoite error
import Benitoite.Unofficial.IO.File

function main() -> Unit uses File.Write
  File.writeText("out.txt", "data")
  return ()
end function
```

```diagnostic
error[E0416]: the value of this expression is not used
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Result[Unit, String] uses File.Write, Console.Write
  bind _ <- try File.writeText("out.txt", "data") |> Result.mapError(_, IOError.message)
  Console.writeLine("written")
  return Result.Ok(())
end function
```

```output
written
```

## `return` のない最後の式

関数の本体は、`return` で値を返す。ラムダの本体も、値が `Unit` でない限り `return` を要する。

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
  bind doubled <- List.map([1, 2], lambda(x) return x * 2 end lambda)
  return Console.writeLine("${next(1)} ${String.join(List.map(doubled, Integer.toString), ",")}")
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
  List.forEach([1, 2, 3], lambda(x)
    Console.writeLine(Integer.toString(x))
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

次の 34 語はキーワードであり、名前にできない。`and`、`bind`、`case`、`const`、`data`、`div`、`do`、`effect`、`else`、`end`、`false`、`function`、`handle`、`if`、`implement`、`import`、`lambda`、`lazy`、`match`、`mod`、`not`、`or`、`public`、`record`、`resume`、`return`、`shadow`、`then`、`trait`、`true`、`try`、`type`、`uses`、`with`。別の名前を選ぶ。

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

## ラムダの引数としての `_`

`_` だけではラムダの引数にできない。使わない引数には、`_key` のように `_` で始まる名前を使う。

```benitoite error
function evens(m: Map[String, Integer]) -> Map[String, Integer]
  return Map.filter(m, lambda(_, n) return n mod 2 = 0 end lambda)
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
  return Map.filter(m, lambda(_key, n) return n mod 2 = 0 end lambda)
end function

function main() -> Unit uses Console.Write
  return Console.writeLine(String.join(Map.keys(evens(Map.fromList([Pair("a", 1), Pair("b", 2)]))), ","))
end function
```

```output
b
```
