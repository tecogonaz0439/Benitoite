# Common mistakes in Benitoite

<!--
How the code examples in this file are checked (tests/skill_examples.rs):
- A `benitoite error` block must fail `benitoite check`, and every line of the `diagnostic` block after it must appear in the report.
- A `benitoite` block is run, and its standard output is compared with the `output` block after it.
  A last line `exit N` in the `output` block is the expected exit code (0 when absent).
  A `stderr` block after the `output` block is the expected standard error (empty when absent).
- A `benitoite check` block is only checked; it must have no errors and no warnings.
- A `benitoite test` block is run with `benitoite test`; all its tests must pass.
- A `files` block before an example creates a file next to the script: the first line is `name: <file name>`, the rest is the content.
- Blocks with other info strings (such as `text`) are not checked.
-->

Habits from other languages that `benitoite check` rejects, with the first line of the report and the correct way to write it. When a report has a code you do not know, look it up in `diagnostics.md`.

## Contents

- [`let` instead of `bind`](#let-instead-of-bind)
- [Binding the same name twice](#binding-the-same-name-twice)
- [Braces for blocks](#braces-for-blocks)
- [C-style operators](#c-style-operators)
- [The return type after `:`](#the-return-type-after-)
- [Constructors without their type name](#constructors-without-their-type-name)
- [Forgetting to import an IO module](#forgetting-to-import-an-io-module)
- [Importing an unofficial module as `Benitoite.X`](#importing-an-unofficial-module-as-benitoitex)
- [Forgetting `uses`](#forgetting-uses)
- [Ignoring a `Result`](#ignoring-a-result)
- [A last expression without `return`](#a-last-expression-without-return)
- [`for` and `while` loops](#for-and-while-loops)
- [Keywords as names](#keywords-as-names)
- [`_` as a lambda parameter](#_-as-a-lambda-parameter)

## `let` instead of `bind`

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

Write `bind name <- expression`:

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

## Binding the same name twice

`bind` cannot reuse a name that is already a local name. Use `shadow` to hide the old one on purpose, or pick a new name.

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

## Braces for blocks

Blocks end with `end` and the keyword that opened them: `end function`, `end if`, `end match`, `end lambda`, `end handle`, `end with`, `end data`, `end record`.

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

## C-style operators

`==`, `!=`, `&&`, `||`, and `!` are not operators. Equality is `=`, inequality is `<>`, and the logical operators are the words `and`, `or`, `not`.

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

## The return type after `:`

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

## Constructors without their type name

`Some`, `None`, `Ok`, `Error`, and the constructors of your own `data` types are written with the type name: `Option.Some(x)`, `Option.None`, `Result.Ok(x)`, `Result.Error(e)`, `Shape.Circle(r)`. This holds in patterns too.

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

## Forgetting to import an IO module

`Console`, `File`, `Process`, `Clock`, `Random`, `Json`, `Csv`, `Http`, and other modules outside the prelude must be imported, also when they only appear in `uses`.

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

## Importing an unofficial module as `Benitoite.X`

Unofficial modules are imported under `Benitoite.Unofficial`. The table in `stdlib/index.md` gives the import name of every module.

```benitoite error
import Benitoite.IO.Console

function main() -> Unit uses Console.Write
  return Console.writeLine("hi")
end function
```

```diagnostic
error[E0321]: `Benitoite.IO.Console` is not a standard library module
```

The correct import is `import Benitoite.Unofficial.IO.Console`, as in the previous section. The module is still referred to as `Console`.

## Forgetting `uses`

Every function that performs an effect, directly or through a function it calls, lists the effect after `uses`.

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

## Ignoring a `Result`

A statement whose value is not `Unit` is an error. IO functions that can fail return `Result`; handle it with `try`, `match`, or bind it to `_` only when you really want to ignore the error.

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

## A last expression without `return`

A function body returns its value with `return`. A lambda body also needs `return` unless its value is `Unit`.

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

## `for` and `while` loops

There are no loop statements. Use `List.forEach`, `List.map`, `List.fold`, or a recursive function.

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

## Keywords as names

These 34 words are keywords and cannot be names: `and`, `bind`, `case`, `const`, `data`, `div`, `do`, `effect`, `else`, `end`, `false`, `function`, `handle`, `if`, `implement`, `import`, `lambda`, `lazy`, `match`, `mod`, `not`, `or`, `public`, `record`, `resume`, `return`, `shadow`, `then`, `trait`, `true`, `try`, `type`, `uses`, `with`. Choose another name.

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

## `_` as a lambda parameter

`_` alone cannot be a lambda parameter. For an unused parameter, use a name that starts with `_`, such as `_key`.

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
