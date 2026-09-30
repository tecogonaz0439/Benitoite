# Benitoite Language Reference

Benitoite is a statically typed, functional scripting language. A script is one source file with the extension `.bnt`. This document describes the syntax of the language and the parts of the standard library that scripts use most often. Read it before writing a script: Benitoite looks similar to other languages in places, but its syntax differs in many details.

## 1. Lexical structure

### Characters and comments

- Source files are UTF-8. Outside string literals, character literals and comments, only ASCII characters may appear.
- A comment starts with `//` and runs to the end of the line. There are no block comments (`/* */`).
- A documentation comment `///` describes the declaration that follows it. A documentation comment `//!` describes the whole file and may only appear at the top of the file, before any import or declaration.
- Semicolons are not used. Braces `{` `}` are not used for blocks; they appear only inside string interpolation (`"${x}"`). Every block starts with a keyword and ends with `end` followed by the name of the construct (`end function`, `end if`, ...).

### Names

- A name that starts with a lowercase letter or `_` is a *lowercase name*: variables, functions, parameters and record fields.
- A name that starts with an uppercase letter is a *capitalized name*: types, constructors, modules, effects and traits.
- A single `_` is not a name. It is the wildcard pattern and the placeholder for partial application. Names such as `_unused` are ordinary lowercase names.
- Names contain only ASCII letters, digits and `_`.

### Keywords

The following words are keywords and cannot be used as names:

`and`, `case`, `const`, `div`, `do`, `effect`, `else`, `end`, `false`, `function`, `handle`, `if`, `implement`, `import`, `lambda`, `lazy`, `let`, `mod`, `not`, `of`, `or`, `public`, `record`, `resume`, `return`, `then`, `trait`, `true`, `type`, `uses`, `when`, `with`

The word `as` has a meaning only in an import declaration (`import Benitoite.Json as J`); elsewhere it is an ordinary name. Similarly, `equality` and `key` have a meaning only as constraints on type parameters.

### Literals

| Kind | Examples |
|---|---|
| Integer (`Integer`, 64-bit) | `0`, `42`, `1_000_000`, `0xff`, `0o755`, `0b1010` |
| Float (`Float`, 64-bit) | `3.14`, `0.5`, `1e10`, `2.5e-3` (write `0.5`, not `.5`; write `1.0`, not `1.`) |
| Decimal (`Decimal`) | `12m`, `19.99m` |
| String (`String`) | `"hello"`, `"line\n"`, `"tab\tquote\"dollar\$"`, `"\u{1F600}"` |
| Character (`Character`) | `'a'`, `'\n'`, `'\''` |
| Boolean (`Boolean`) | `true`, `false` |
| Unit (`Unit`) | `()` |

A string is written on one line. `${expression}` inside a string inserts the value of the expression (interpolation); it works for `Integer`, `Float`, `Decimal`, `String`, `Character` and `Boolean` values. Write `\$` for a literal dollar sign.

```benitoite
let greeting = "Hello, ${name}! You are ${age} years old."
```

A multi-line string starts with `"""` at the end of a line and ends with `"""` on a line of its own. The indentation of the closing `"""` is removed from every line. A raw string `r"..."` (or `r"""..."""`) does not process escapes or interpolation.

```benitoite
let page = """
    <h1>Report</h1>
    <p>Total: ${total}</p>
    """
let pattern = r"\d+\.\d+"
```

### Operators and punctuation

```
+  -  *  /  =  <>  <  <=  >  >=  |>  ->  :  ,  .  ..  (  )  [  ]  _  &  @
```
The postfix operator `?` is also used (see section 5.11).

Equality is `=`, inequality is `<>`, and the logical operators are the keywords `and`, `or` and `not`. There are no `==`, `!=`, `&&`, `||` or `!` operators.
Integer division is the keyword `div` and the remainder is `mod`. `/` divides only `Float` and `Decimal` values. There is no `%` operator.
Outside strings and comments, the symbols `;`, `#`, `|`, `=>`, `==`, `!=`, `&&`, `||`, `!`, `%`, `$` are not part of the language.

### Line breaks

Statements are separated by line breaks. A line break is *not* a separator, and is read like a space, in these cases:

1. The line break is inside parentheses `( )` or brackets `[ ]`, and no block has been opened inside them since.
2. The line ends with a token that cannot end an expression or statement. These tokens are: `&`, `(`, `*`, `+`, `,`, `-`, `->`, `.`, `/`, `:`, `<`, `<=`, `<>`, `=`, `>`, `>=`, `[`, `and`, `case`, `const`, `div`, `do`, `effect`, `else`, `function`, `handle`, `if`, `implement`, `import`, `lambda`, `lazy`, `let`, `mod`, `not`, `of`, `or`, `public`, `record`, `return`, `then`, `trait`, `type`, `uses`, `when`, `with`, `|>`.
3. The next line starts with a token that continues the previous line. These tokens are: `*`, `+`, `->`, `.`, `/`, `<`, `<=`, `<>`, `=`, `>`, `>=`, `and`, `div`, `do`, `else`, `mod`, `of`, `or`, `then`, `|>`.

Rule 2 does not apply to the word after `end` (`end if`, `end function`, ...): a line ending with `end if` is complete.

So, to continue a long expression on the next line, end the line with an operator, or start the next line with `|>`:

```benitoite
let total = price
  * quantity
let count = lines
  |> List.filter(lambda(l) return l <> "" end lambda)
  |> List.length
```

Inside a block that is opened in parentheses (for example a lambda passed as an argument), line breaks separate statements again.

The return type of a function must be on the same line as its parameter list.

## 2. Program structure

A script consists of import declarations followed by declarations. Imports must come before all other declarations. At the top level, only declarations are allowed: functions, constants, types, type aliases, records, traits, effects and implementations. There are no top-level statements or variables.

Execution starts by calling the function `main`, which takes no parameters and returns `Unit` or `Result[Unit, String]`. When `main` returns `Result.Error(message)`, the message is reported and the script exits with a failure status.

```benitoite
import Benitoite.IO.Console

function main(): Unit uses Console.Write
  Console.writeLine("Hello, world")
end function
```

A declaration marked `public` can be used by other modules that import this file. A script that is a single file does not need `public`.

## 3. Declarations

### 3.1 Functions

A function declaration lists every parameter with its type, then `:` and the return type, then optionally `uses` and the effects of the function. The body follows on the next lines and ends with `end function`.

```benitoite
function add(x: Integer, y: Integer): Integer
  return x + y
end function

function greet(name: String): Unit uses Console.Write
  Console.writeLine("Hello, ${name}")
end function
```

- All parameter types and the return type must be written. A function that returns nothing has the return type `Unit`.
- The body returns a value with `return expression`. `return` may appear anywhere in the body. A function whose return type is not `Unit` must return on every path.
- A function without `uses` is pure: it cannot print, read files, and so on (see section 7).
- Functions are not curried. A call must pass all arguments; use the placeholder `_` for partial application (section 5.5).
- Functions may call each other in any order and may be recursive. Tail calls do not grow the stack, so recursion is the way to loop.

Type parameters are written in brackets after the name. A type parameter can have constraints: a trait, or the built-in constraints `equality` (values can be compared with `a = b`) and `key` (values can be keys of a `Map` or elements of a `Set`).
Several constraints on one type parameter are joined with `&`. Effect variables are declared with `effect`.

```benitoite
function firstOr[T](xs: List[T], default: T): T
  return case xs of
    when [x, ..]: x
    when []: default
  end case
end function

function describeAll[T: Describe & equality](items: List[T], skip: T): List[String]
  return items
    |> List.filter(lambda(x) return x <> skip end lambda)
    |> List.map(Describe.describe)
end function

function applyTwice[T, effect E](x: T, f: function(T) -> T uses E): T uses E
  return f(f(x))
end function
```

The type of a function value is written `function(ParameterTypes) -> ReturnType`, optionally followed by `uses` and effects. If such a function type appears inside a list of effects, wrap it in parentheses.

### 3.2 Algebraic data types

An algebraic data type is declared with `type`. Each constructor is written on its own line, with the types of its fields in parentheses. A constructor without fields is written without parentheses. The declaration ends with `end type`.

```benitoite
type Shape
  Circle(Float)
  Rectangle(Float, Float)
  Point
end type

type Tree[T]
  Leaf
  Node(Tree[T], T, Tree[T])
end type
```

Constructors are always qualified with the type name, both in expressions and in patterns: `Shape.Circle(1.0)`, `Shape.Point`, `Tree.Node(Tree.Leaf, 5, Tree.Leaf)`. The same holds for the standard types `Option` and `Result`: `Option.Some(x)`, `Option.None`, `Result.Ok(x)`, `Result.Error(e)`. Writing `Some(x)`, `None`, `Ok(x)` or `Err(e)` is an error.

### 3.3 Records

A record has named fields, one per line.

```benitoite
record Employee
  name: String
  salary: Integer
  department: String
end record
```

- Create a record with named arguments: `Employee(name: "Ann", salary: 5000, department: "Sales")`.
- Copy a record with some fields changed with `..`: `Employee(..e, salary: 6000)`. At least one field must be given.
- Read a field with the accessor function named after the record: `Employee.name(e)`, or `e |> Employee.name`. Writing `e.name` is an error: a value can never be followed by `.`.
- Records can be matched with patterns: `case e of when Employee(name: n, ..): n end case`.

### 3.4 Type aliases

```benitoite
type UserId = Integer
type Validator[T] = function(T) -> Result[T, String]
```

A `type` declaration with `=` after the name is an alias; without `=` it declares an algebraic data type. There is no `type T = A | B` form: constructors are written one per line.

### 3.5 Constants

```benitoite
const maxRetries: Integer = 3
const greeting: String = "hello"
const statusNames: Map[Integer, String] = Map.fromList([Pair(200, "OK"), Pair(404, "Not Found")])
```

The type annotation is required. The value must be a constant expression: literals, other constants, constructors, records, lists, `Pair` and `Triple`, arithmetic and comparison operators, interpolation of constants, and `Map.fromList`, `Set.fromList`, `Map.empty()`, `Set.empty()`. A constant is used by its name (`maxRetries`), not called (`maxRetries()` is an error).

### 3.6 Traits and implementations

A trait (type class) declares method signatures. An implementation provides them for one type.

```benitoite
trait Describe[T]
  function describe(x: T): String
end trait

implement Describe[Employee]
  function describe(x: Employee): String
    return "${Employee.name(x)} works in ${Employee.department(x)}"
  end function
end implement

implement[T: Describe] Describe[List[T]]
  function describe(x: List[T]): String
    return String.join(List.map(x, Describe.describe), ", ")
  end function
end implement
```

- Call a method through the trait name: `Describe.describe(e)`.
- A trait can require another trait: `trait Ordered[T: Describe]`.
- `implement` always names a trait. There is no `implement Employee` block with methods; write top-level functions instead.
- The methods in an implementation and the implementation itself are not marked `public`.

### 3.7 Effects

A user-defined effect declares operations. Operations are called like functions, and a function that calls them lists the effect in `uses`.

```benitoite
effect Log
  function write(message: String): Unit
end effect
```

How to handle an effect is shown in section 5.13.

### 3.8 Imports

```benitoite
import Benitoite.IO.Console
import Benitoite.IO.File
import Benitoite.Json as J
```

An import names a module with capitalized names separated by dots. After the import, the module is used by its last name (`Console.writeLine`, `File.readText`) or by the name after `as`. Modules are never imported with a path string. The modules `List`, `String`, `Integer`, `Float`, `Map`, `Set`, `Option`, `Result`, `Pair`, `Triple`, `Task`, `TaskGroup`, `Assert`, `Reference` and `IO` are available without an import.

### 3.9 Tests

A test is a top-level function with the attribute `@test`, optionally with a description: `@test("description")`. The function takes no parameters, returns `Unit`, and lists `Assert.Check` (and any other effects it uses) in `uses`.

```benitoite
function add(x: Integer, y: Integer): Integer
  return x + y
end function

@test("add sums two numbers")
function addSumsTwoNumbers(): Unit uses Assert.Check
  Assert.equal(add(2, 3), 5)
  Assert.equal(add(-1, 1), 0)
end function
```

Tests are run with `benitoite test`. Other attribute spellings (`@Test`, `#[test]`, `[<Test>]`) are errors.

### 3.10 Attributes and documentation comments

The only attributes are `@test` (above) and `@deprecated("reason")`. An attribute is written on the line before a declaration.

```benitoite
//! Utilities for reading the configuration.

import Benitoite.IO.File

/// Reads the port number from the configuration file.
/// Returns an error when the file does not contain a number.
function readPort(path: String): Result[Integer, String] uses File.Read
  let text = (File.readText(path) |> Result.mapError(_, IOError.message))?
  return Integer.parse(String.trim(text)) |> Option.okOr(_, "not a number")
end function

@deprecated("use readPort instead")
function port(): Integer
  return 8080
end function
```

## 4. Blocks and statements

A block is a sequence of statements separated by line breaks. The bodies of functions, lambdas, `if` branches, pattern-matching arms, `with`, `lazy` and `handle` are blocks. A statement is a local binding or an expression.

`let name = expression` binds a name. Values cannot be changed: `x = 5` is not an assignment. Binding the same name again with a new `let` shadows the old binding. A type annotation is optional.

```benitoite
function normalize(input: String): String
  let text = String.trim(input)
  let text = String.toLowercase(text)
  let words: List[String] = String.split(text, " ")
  return String.join(words, "-")
end function
```

The left side of `let` can be a pattern that always matches, such as `let Pair(count, name) = entry`. To discard a value, write `let _ = f(x)`.

- An expression statement that is not the last statement of a block must have the type `Unit`. Discard other values explicitly as shown above.
- In an `if` branch or a `case` arm, the value of the block is the value of its last expression.
- In the body of a function or lambda, the result is returned with `return`. `return ()` leaves a `Unit` function early.

## 5. Expressions

### 5.1 Operators

Operators from lowest to highest precedence:

| Precedence | Operators | Associativity |
|---|---|---|
| 1 | `\|>` | left |
| 2 | `or` | left |
| 3 | `and` | left |
| 4 | `=` `<>` `<` `<=` `>` `>=` | none |
| 5 | `+` `-` | left |
| 6 | `*` `/` `div` `mod` | left |
| 7 | unary `-` `not` | prefix |
| 8 | call `f(...)` | postfix |
| 8 | postfix `?` | postfix |

`return` binds more loosely than any operator.

### 5.2 Names and calls

A function is called with parentheses: `f(x, y)`. Functions of a module are qualified with the module name: `List.map(xs, f)`, `String.trim(s)`. There are no methods: `xs.map(f)`, `s.length` and `e.name` are errors.

### 5.3 Lists

A list literal is written in brackets: `[1, 2, 3]`, `[]`. Lists are immutable; `List.append(xs, x)` returns a new list. There is no indexing syntax `xs[0]`; use `List.get(xs, 0)`, which returns an `Option`.

### 5.4 Pipes

`x |> f(a, b)` means `f(x, a, b)`: the left value becomes the first argument. `x |> f` means `f(x)`.

```benitoite
let result = lines
  |> List.map(String.trim)
  |> List.filter(lambda(l) return not String.isEmpty(l) end lambda)
  |> String.join(_, "\n")
```

### 5.5 Placeholders

A call with `_` as an argument is a function of the missing arguments: `clamp(0, _, 100)` is the same as `lambda(v) return clamp(0, v, 100) end lambda`. In a pipe, the left value goes where the `_` is: `text |> String.split(_, ",")`. `_` may appear only as a direct argument of a call.

### 5.6 Lambdas

An anonymous function starts with `lambda`, then the parameters in parentheses, optionally `: ReturnType` and `uses`, and then the body, and it ends with `end lambda`. The body returns with `return`. Parameter types can usually be omitted.

```benitoite
let double = lambda(x) return x * 2 end lambda
let add = lambda(x: Integer, y: Integer): Integer return x + y end lambda
List.forEach(names, lambda(name)
  let message = "Hello, ${name}"
  Console.writeLine(message)
end lambda)
```

Parameters of a lambda cannot be `_`; name unused parameters like `_unused`. Forms such as `x => x + 1`, `|x| x + 1`, `fn(x) ...` and `lambda x: x + 1` are errors.

### 5.7 Pairs and triples

Two or three values are grouped with the standard types `Pair` and `Triple`: `Pair(1, "one")`, `Triple(x, y, z)`, with types `Pair[Integer, String]` and `Triple[A, B, C]`. `Pair` and `Triple` are written without a qualifying type name. Take them apart with patterns (`let Pair(n, name) = p`) or with `Pair.first`, `Pair.second`, `Triple.first`, `Triple.second` and `Triple.third`. There are no tuples in parentheses: `(1, "one")` is an error. For four or more values, declare a record. `Map.toList` returns a list of pairs, and `Map.fromList` takes one.

### 5.8 Conditionals

`if condition then ... else ... end if`. The condition is not in parentheses, and an `if` always ends with `end if`. `else if` continues the same `if` and needs only one `end if`. An `if` is an expression: `let sign = if x < 0 then -1 else 1 end if`. An `if` without `else` has the type `Unit`.

```benitoite
function classify(n: Integer): String
  if n < 0 then
    return "negative"
  else if n = 0 then
    return "zero"
  else
    return "positive"
  end if
end function
```

### 5.9 Pattern matching

`case value of ... end case` compares a value with patterns. Each arm is written `when pattern: body`. The body can be one expression on the same line or several statements on the following lines; it runs until the next `when` or `end case`. There is no fallthrough and no `break`.

```benitoite
function area(shape: Shape): Float
  return case shape of
    when Shape.Circle(r): 3.14159 * r * r
    when Shape.Rectangle(w, h):
      let a = w * h
      a
    when Shape.Point: 0.0
  end case
end function

function label(n: Integer): String
  return case n of
    when 0: "zero"
    when 1, 2, 3: "small"
    when 4..9: "medium"
    when k if k < 0: "negative"
    when _: "large"
  end case
end function
```

- Several patterns separated by commas form alternatives.
- A guard is written after the patterns with `if`: `when k if k < 0:`.
- The value of the match is the value of the arm that was taken. The arms must cover all possible values; use `_` for "anything else".

### 5.10 Strings

Strings are concatenated with `+` or built with interpolation: `"${name} has ${count} items"`. Interpolation takes values of the basic types; convert other values with a function first (`Json.stringify(v)`, `describe(x)`). Multi-line and raw strings are described in section 1.

### 5.11 Returning errors early

A `?` after an expression whose value is `Result.Error(e)` (or `Option.None`) returns that value from the current function. Otherwise the expression gives the value inside `Result.Ok` (or `Option.Some`). `?` binds tightly to the preceding call; to apply it to a pipe, put the pipe in parentheses. The error types must match; convert them with `Result.mapError` first. There are no exceptions and no `try`/`catch`.

```benitoite
function loadConfig(path: String): Result[Json.Value, String] uses File.Read
  let text = (File.readText(path) |> Result.mapError(_, IOError.message))?
  let value = (Json.parse(text) |> Result.mapError(_, Json.ParseError.message))?
  return Result.Ok(value)
end function
```

### 5.12 Resources and laziness

`with name = expression do ... end with` binds a resource (an open file, a task group, a server) and releases it when the block ends. Several resources are separated by commas. `lazy ... end lazy` creates a `Lazy[T]` value whose block runs at most once, when `Lazy.force` is called.

```benitoite
function firstLine(path: String): Result[Option[String], IOError] uses File.Read, State
  with reader = File.openReader(path)? do
    return File.readLine(reader)
  end with
end function

function expensive(): Lazy[Integer]
  return lazy
    List.fold(List.range(0, 1000), 0, lambda(acc, x) return acc + x end lambda)
  end lazy
end function
```

### 5.13 Handling effects

`handle body when operation(parameters): ... end handle` runs the body, and each `when` arm handles calls of that operation made in the body. Inside an arm, `resume(value)` continues the body, with `value` as the result of the operation call. An arm that does not call `resume` ends the whole `handle` with its own value.

```benitoite
effect Log
  function write(message: String): Unit
end effect

function sumPrices(items: List[Integer]): Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(items, 0, lambda(acc, x) return acc + x end lambda)
end function

function total(items: List[Integer]): Integer uses Console.Write
  return handle
    sumPrices(items)
  when write(message):
    Console.writeErrorLine(message)
    resume(())
  end handle
end function
```

Operations of an effect declared in the same file are written without a module name (`write`). Operations of other modules are qualified (`Console.writeLine`). Parameters of an arm are names or `_`, not patterns.

## 6. Patterns

| Pattern | Matches |
|---|---|
| `_` | anything |
| `x` | anything, and binds it to `x` |
| `0`, `-1`, `"text"`, `'c'`, `true`, `()` | that literal (not floats) |
| `Shape.Circle(r)`, `Option.None` | a constructor, with patterns for its fields |
| `Employee(name: n, ..)` | a record, with patterns for some fields |
| `Pair(a, b)`, `Triple(a, b, c)` | a pair or triple |
| `1..9`, `'a'..'z'` | a range of integers or characters (both ends included) |
| `[]`, `[x]`, `[first, ..rest]`, `[.., last]` | lists; `..rest` binds the remaining elements |

A lowercase name in a pattern always binds a new variable; it never compares with an existing variable or constant. Use a guard to compare with a variable. Ranges are written with `..` only (not `..=`, `..<` or `...`), and alternatives are separated by commas (not `|`).

## 7. Effects

Every function that performs input or output must list the corresponding effects after `uses`. A function that calls another function must list the callee's effects too (except those it handles). `main` may use any of the built-in effects.

| Effect | Operations | Import |
|---|---|---|
| `Console.Write` | `Console.writeLine`, `Console.write`, `Console.writeErrorLine` | `import Benitoite.IO.Console` |
| `Console.Read` | `Console.readLine`, `Console.readAll`, `Console.readAllLines` | `import Benitoite.IO.Console` |
| `File.Read` | `File.readText`, `File.readLines`, `File.exists`, `File.listDirectory`, `File.openReader`, `File.readLine` | `import Benitoite.IO.File` |
| `File.Write` | `File.writeText`, `File.appendText`, `File.createDirectory`, `File.remove` | `import Benitoite.IO.File` |
| `Process.Environment` | `Process.arguments`, `Process.environmentVariable` | `import Benitoite.IO.Process` |
| `Process.Run` | `Process.run`, `Process.shell` | `import Benitoite.IO.Process` |
| `Process.Exit` | `Process.exit` | `import Benitoite.IO.Process` |
| `Clock.Time` | `Clock.sleep`, `Task.race`, `Task.withTimeout` | `import Benitoite.IO.Clock` |
| `Random.Generate` | random numbers | `import Benitoite.IO.Random` |
| `Http.Listen` | `Http.serve`, `Http.listen`, `Http.accept` | `import Benitoite.Network.Http` |
| `Http.Connect` | `Http.get`, `Http.send` | `import Benitoite.Network.Http` |
| `State` | `Reference.new`, `Reference.get`, `Reference.set`, `TaskGroup.open`, `TaskGroup.spawn`, `Task.await`, closing resources | none |
| `Assert.Check` | `Assert.equal`, `Assert.notEqual`, `Assert.isTrue`, `Assert.fail` | none |
| `IO.All` | all of the local effects above except `Http.*` and `Assert.Check` | none |

`uses IO` is an error; write the specific effects, or `uses IO.All`. Effects are always qualified with their module (`Console.Write`, not `Console`). A user-defined effect declared in the same file is written by its name (`uses Log`).

## 8. Standard library (selection)

Functions take the value they work on as their first argument, so they fit pipes. Failures are returned as `Result` or `Option`, never thrown.

- **Integer**: `Integer.toString(n)`, `Integer.parse(s): Option[Integer]`, `Integer.toFloat(n)`, `Integer.absolute(n)`, `Integer.minimum(a, b)`, `Integer.maximum(a, b)`.
- **Float**: `Float.toString(x)`, `Float.parse(s): Option[Float]`, `Float.round(x)`, `Float.floor(x)`, `Float.truncate(x): Option[Integer]`, `Float.squareRoot(x)`.
- **String**: `String.length` does not exist; use `String.characterCount(s)`. `String.isEmpty(s)`, `String.contains(s, sub)`, `String.startsWith(s, p)`, `String.endsWith(s, p)`, `String.split(s, sep)`, `String.lines(s)`, `String.join(xs, sep)`, `String.trim(s)`, `String.replace(s, old, new)`, `String.repeat(s, n)`, `String.toUppercase(s)`, `String.toLowercase(s)`, `String.characters(s): List[Character]`.
- **List**: `List.length(xs)`, `List.isEmpty(xs)`, `List.head(xs): Option[T]`, `List.tail(xs): Option[List[T]]`, `List.get(xs, i): Option[T]`, `List.append(xs, x)`, `List.prepend(xs, x)`, `List.concatenate(xs, ys)`, `List.reverse(xs)`, `List.take(xs, n)`, `List.drop(xs, n)`, `List.range(start, end)` (end excluded), `List.contains(xs, x)`, `List.sort(xs)`, `List.map(xs, f)`, `List.filter(xs, p)`, `List.fold(xs, initial, f)` where `f(accumulator, element)`, `List.forEach(xs, f)`, `List.any(xs, p)`, `List.all(xs, p)`, `List.find(xs, p)`.
- **Option**: `Option.Some(x)`, `Option.None`, `Option.map(o, f)`, `Option.andThen(o, f)`, `Option.unwrapOr(o, default)`, `Option.isSome(o)`, `Option.isNone(o)`, `Option.okOr(o, error)`.
- **Result**: `Result.Ok(x)`, `Result.Error(e)`, `Result.map(r, f)`, `Result.mapError(r, f)`, `Result.andThen(r, f)`, `Result.unwrapOr(r, default)`, `Result.isOk(r)`, `Result.isError(r)`, `Result.ok(r): Option[T]`.
- **Pair and Triple**: `Pair.first(p)`, `Pair.second(p)`, `Triple.first(t)`, `Triple.second(t)`, `Triple.third(t)`.
- **Map** (keys are ordered): `Map.empty()`, `Map.fromList(pairs)`, `Map.toList(m)`, `Map.get(m, k): Option[V]`, `Map.set(m, k, v)`, `Map.remove(m, k)`, `Map.contains(m, k)`, `Map.size(m)`, `Map.keys(m)`, `Map.values(m)`, `Map.map(m, f)` with `f(k, v)`, `Map.filter(m, p)`, `Map.fold(m, initial, f)` with `f(acc, k, v)`, `Map.forEach(m, f)`.
- **Set**: `Set.empty()`, `Set.fromList(xs)`, `Set.toList(s)`, `Set.contains(s, x)`, `Set.add(s, x)`, `Set.remove(s, x)`, `Set.size(s)`, `Set.union(a, b)`, `Set.intersection(a, b)`, `Set.difference(a, b)`, `Set.map`, `Set.filter`, `Set.fold`, `Set.forEach`.
- **Console** (`Benitoite.IO.Console`): `Console.writeLine(s)`, `Console.write(s)`, `Console.writeErrorLine(s)`, `Console.readLine(): Result[Option[String], IOError]`, `Console.readAll()`.
- **File** (`Benitoite.IO.File`): `File.readText(path): Result[String, IOError]`, `File.readLines(path)`, `File.writeText(path, text): Result[Unit, IOError]`, `File.appendText(path, text)`, `File.exists(path)`, `File.listDirectory(path)`, `File.openReader(path)`, `File.readLine(reader): Result[Option[String], IOError]`.
- **Process** (`Benitoite.IO.Process`): `Process.arguments(): List[String]`, `Process.environmentVariable(name)`, `Process.run(Process.command(program, arguments))`, `Process.exit(code)`.
- **IOError**: `IOError.message(e): String`.
- **Json** (`Benitoite.Json`): `Json.parse(text): Result[Json.Value, Json.ParseError]`, `Json.ParseError.message(e)`, `Json.stringify(v)`, `Json.get(v, key): Option[Json.Value]`, `Json.at(v, index)`, `Json.asString(v)`, `Json.asInteger(v)`, `Json.asFloat(v)`, `Json.asBoolean(v)`, `Json.asArray(v): Option[List[Json.Value]]`, `Json.asObject(v)`. The constructors of `Json.Value` are `Json.Value.Null`, `Json.Value.Boolean(b)`, `Json.Value.Integer(n)`, `Json.Value.Float(x)`, `Json.Value.String(s)`, `Json.Value.Array(xs)`, `Json.Value.Object(map)`.
- **Csv** (`Benitoite.Csv`): `Csv.parse(text): Result[List[List[String]], Csv.ParseError]`, `Csv.parseWithHeader(text): Result[List[Map[String, String]], Csv.ParseError]`, `Csv.ParseError.message(e)`, `Csv.format(rows)`.
- **Task** (no import): `Task.all(actions: List[function() -> T uses E]): List[T]`, `Task.allOk(actions)`, `Task.race(actions)`, `Task.withTimeout(milliseconds, action)`, `TaskGroup.open()` (only as `with group = TaskGroup.open() do ... end with`), `TaskGroup.spawn(group, action): Task[T]`, `Task.await(task)`.
- **Http** (`Benitoite.Network.Http`): `Http.serve(host, port, handler): Result[Unit, NetworkError]` where `handler: function(Http.Request) -> Http.Response`, `Http.Request.method(r)`, `Http.Request.path(r)`, `Http.Request.query(r)`, `Http.Request.body(r)`, `Http.pathSegments(path): List[String]`, `Http.text(status, s)`, `Http.html(status, s)`, `Http.json(status, value)`, `Http.get(url)`, `NetworkError.message(e)`.
- **Assert** (no import, effect `Assert.Check`): `Assert.equal(actual, expected)`, `Assert.notEqual(actual, expected)`, `Assert.isTrue(condition, message)`, `Assert.fail(message)`.
- **Reference** (effect `State`): `Reference.new(v)`, `Reference.get(r)`, `Reference.set(r, v)`, `Reference.update(r, f)`.

## 9. Grammar

The grammar below is in EBNF: `"x"` is a token, `[ A ]` is optional, `{ A }` repeats zero or more times, `( A )` groups, and `A | B` is a choice. `NL` is a line break that separates statements (section 1). `LowerIdent` and `UpperIdent` are lowercase and capitalized names; `IntLit`, `FloatLit`, `DecimalLit`, `StringLit` and `CharLit` are literals; `StrStart`, `StrMid` and `StrEnd` are the parts of a string with interpolation.

```ebnf
CommaList(X) = [ X { "," X } [ "," ] ] .
LineList(X)  = [ NL ] [ X { NL X } [ NL ] ] .

(* program *)
Program     = [ NL ] [ Items [ NL ] ] .
Items       = ImportDecl [ NL Items ]
            | Decls .
Decls       = AttrDecl { NL AttrDecl } .
AttrDecl    = { Attribute [ NL ] } Decl .
Attribute   = "@" LowerIdent [ "(" CommaList(StringLit) ")" ] .
Decl        = [ "public" ] FnDecl
            | [ "public" ] ConstDecl
            | [ "public" ] TypeDecl
            | [ "public" ] AliasDecl
            | [ "public" ] RecordDecl
            | [ "public" ] TraitDecl
            | [ "public" ] EffectDecl
            | ImplDecl .

(* import declaration *)
ImportDecl  = "import" UpperIdent { "." UpperIdent } [ "as" UpperIdent ] .

(* function declaration *)
FnDecl      = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              ":" Type [ Uses ] Body "end" "function" .
FnTypeParams = "[" FnTypeParam { "," FnTypeParam } [ "," ] "]" .
FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" Constraint { "&" Constraint } ] .
Constraint  = QualUpper | LowerIdent .
TypeParamDecl = UpperIdent [ "[" "_" { "," "_" } "]" ] .
Param       = LowerIdent ":" Type .
Uses        = "uses" QualUpper { "," QualUpper } .

(* constant declaration *)
ConstDecl   = "const" LowerIdent ":" Type "=" Expr .

(* type, type alias, record, trait, implementation and effect declarations *)
TypeDecl    = "type" UpperIdent [ TypeParams ] LineList(Variant) "end" "type" .
AliasDecl   = "type" UpperIdent [ TypeParams ] "=" Type .
TypeParams  = "[" UpperIdent { "," UpperIdent } [ "," ] "]" .
Variant     = UpperIdent [ "(" CommaList(Type) ")" ] .
RecordDecl  = "record" UpperIdent [ TypeParams ] LineList(Field) "end" "record" .
Field       = LowerIdent ":" Type .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl [ ":" QualUpper { "&" QualUpper } ] "]"
              LineList(MethodSig) "end" "trait" .
MethodSig   = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" ":" Type [ Uses ] .
ImplDecl    = "implement" [ FnTypeParams ] QualUpper "[" Type "]" LineList(FnDecl) "end" "implement" .
EffectDecl  = "effect" UpperIdent LineList(OpSig) "end" "effect" .
OpSig       = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" ":" Type .

(* types *)
Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(Type) ")" "->" Type [ Uses ]
            | "(" Type ")" .
QualUpper   = UpperIdent { "." UpperIdent } .

(* blocks and statements *)
Body        = LineList(Stmt) .
Stmt        = LetStmt | Expr .
LetStmt     = "let" Pattern [ ":" Type ] "=" Expr .

(* expressions *)
Expr        = "return" Expr
            | PipeExpr .
PipeExpr    = OrExpr { "|>" OrExpr } .
OrExpr      = AndExpr { "or" AndExpr } .
AndExpr     = CmpExpr { "and" CmpExpr } .
CmpExpr     = AddExpr [ CmpOp AddExpr ] .
CmpOp       = "=" | "<>" | "<" | "<=" | ">" | ">=" .
AddExpr     = MulExpr { ( "+" | "-" ) MulExpr } .
MulExpr     = UnaryExpr { ( "*" | "/" | "div" | "mod" ) UnaryExpr } .
UnaryExpr   = ( "-" | "not" ) UnaryExpr | CallExpr .
CallExpr    = Primary { "(" CommaList(Arg) ")" | "?" } .
Arg         = Expr | "_" .
Primary     = Literal
            | InterpString
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "[" CommaList(Expr) "]"
            | IfExpr
            | CaseExpr
            | Lambda
            | RecordExpr
            | "lazy" Body "end" "lazy"
            | WithExpr
            | HandleExpr
            | "resume" "(" Expr ")" .
Literal     = IntLit | FloatLit | DecimalLit | StringLit | CharLit | "true" | "false" .
InterpString = StrStart Expr { StrMid Expr } StrEnd .
Name        = { UpperIdent "." } ( LowerIdent | UpperIdent ) .
RecordExpr  = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")" .
FieldArg    = LowerIdent ":" Expr .
IfExpr      = "if" Expr "then" Body { "else" "if" Expr "then" Body } [ "else" Body ] "end" "if" .
CaseExpr    = "case" Expr "of" [ NL ] Arm { NL Arm } [ NL ] "end" "case" .
Arm         = "when" Pattern { "," Pattern } [ "if" Expr ] ":" ArmBody .
ArmBody     = Stmt { NL Stmt } .
Lambda      = "lambda" "(" CommaList(LambdaParam) ")" [ ":" Type [ Uses ] ] Body "end" "lambda" .
LambdaParam = LowerIdent [ ":" Type ] .
WithExpr    = "with" WithBind { "," WithBind } "do" Body "end" "with" .
WithBind    = LowerIdent "=" Expr .
HandleExpr  = "handle" Body HandleArm { NL HandleArm } [ NL ] "end" "handle" .
HandleArm   = "when" OpName "(" CommaList(OpParam) ")" ":" ArmBody .
OpName      = { UpperIdent "." } LowerIdent .
OpParam     = LowerIdent | "_" .

(* patterns *)
Pattern     = "_"
            | LowerIdent
            | [ "-" ] IntLit
            | StringLit
            | CharLit
            | "true" | "false"
            | "(" ")"
            | QualUpper [ "(" CommaList(Pattern) ")" ]
            | QualUpper "(" FieldPat { "," FieldPat } [ "," ".." ] [ "," ] ")"
            | RangeEnd ".." RangeEnd
            | "[" [ ListPatElem { "," ListPatElem } [ "," ] ] "]" .
FieldPat    = LowerIdent ":" Pattern .
RangeEnd    = [ "-" ] IntLit | CharLit .
ListPatElem = Pattern | ".." [ LowerIdent ] .
```

The grammar alone does not say:
- The name after `end` must match the construct it closes (`if ... end if`).
- The line-break rules of section 1 decide where `NL` appears.
- A list of effects after `uses` is read as long as possible; wrap a function type in parentheses when needed.

## 10. Example programs

### Word frequencies

```benitoite
//! Prints how often each word occurs in a text file.

import Benitoite.IO.Console
import Benitoite.IO.File
import Benitoite.IO.Process

function countWords(text: String): Map[String, Integer]
  let words = String.split(String.toLowercase(text), " ")
    |> List.filter(lambda(w) return not String.isEmpty(w) end lambda)
  return List.fold(words, Map.empty(), lambda(counts, w)
    let current = Map.get(counts, w) |> Option.unwrapOr(_, 0)
    return Map.set(counts, w, current + 1)
  end lambda)
end function

function main(): Result[Unit, String] uses Console.Write, File.Read, Process.Environment
  let path = case Process.arguments() of
    when [first, ..]: first
    when []: "input.txt"
  end case
  let text = (File.readText(path) |> Result.mapError(_, IOError.message))?
  Map.forEach(countWords(text), lambda(word, n)
    Console.writeLine("${word}: ${n}")
  end lambda)
  return Result.Ok(())
end function
```

### Shapes and pattern matching

```benitoite
import Benitoite.IO.Console

type Shape
  Circle(Float)
  Rectangle(Float, Float)
  Triangle(Float, Float, Float)
end type

function area(shape: Shape): Float
  return case shape of
    when Shape.Circle(r): 3.14159 * r * r
    when Shape.Rectangle(w, h): w * h
    when Shape.Triangle(a, b, c):
      let s = (a + b + c) / 2.0
      Float.squareRoot(s * (s - a) * (s - b) * (s - c))
  end case
end function

function sizeLabel(n: Integer): String
  return case n of
    when 0: "none"
    when 1, 2, 3: "few"
    when 4..9: "several"
    when k if k < 0: "invalid"
    when _: "many"
  end case
end function

function main(): Unit uses Console.Write
  let shapes = [Shape.Circle(1.0), Shape.Rectangle(2.0, 3.0)]
  List.forEach(shapes, lambda(s)
    Console.writeLine("area: ${area(s)}")
  end lambda)
  Console.writeLine(sizeLabel(List.length(shapes)))
end function
```

### Records, traits and constraints

```benitoite
import Benitoite.IO.Console

record Employee
  name: String
  salary: Integer
  department: String
end record

trait Describe[T]
  function describe(x: T): String
end trait

implement Describe[Employee]
  function describe(x: Employee): String
    return "${Employee.name(x)} (${Employee.department(x)})"
  end function
end implement

function giveRaise(e: Employee, percent: Integer): Employee
  let increase = Employee.salary(e) * percent div 100
  return Employee(..e, salary: Employee.salary(e) + increase)
end function

function describeOthers[T: Describe & equality](items: List[T], skip: T): List[String]
  return items
    |> List.filter(lambda(x) return x <> skip end lambda)
    |> List.map(Describe.describe)
end function

function main(): Unit uses Console.Write
  let ann = Employee(name: "Ann", salary: 5000, department: "Sales")
  let bob = giveRaise(Employee(name: "Bob", salary: 4000, department: "IT"), 10)
  let lines = describeOthers([ann, bob], ann)
  Console.writeLine(String.join(lines, "\n"))
  Console.writeLine("even salary: ${Employee.salary(bob) mod 2 = 0}")
end function
```

### Durations, constants and tests

```benitoite
const secondsPerMinute: Integer = 60
const secondsPerHour: Integer = 60 * 60

type Seconds = Integer

function formatDuration(total: Seconds): String
  let hours = total div secondsPerHour
  let minutes = total mod secondsPerHour div secondsPerMinute
  let seconds = total mod secondsPerMinute
  let text = "${minutes}m ${seconds}s"
  let text = if hours > 0 then "${hours}h ${text}" else text end if
  return text
end function

@test("formatDuration shows hours only when needed")
function formatDurationShowsHours(): Unit uses Assert.Check
  Assert.equal(formatDuration(59), "0m 59s")
  Assert.equal(formatDuration(3725), "1h 2m 5s")
  Assert.isTrue(not String.isEmpty(formatDuration(0)), "never empty")
end function
```

### Recursion over lists and a user-defined effect

```benitoite
import Benitoite.IO.Console

effect Log
  function write(message: String): Unit
end effect

function sumPositive(xs: List[Integer], acc: Integer): Integer uses Log
  return case xs of
    when []: acc
    when [x, ..rest] if x > 0:
      write("adding ${x}")
      sumPositive(rest, acc + x)
    when [_, ..rest]: sumPositive(rest, acc)
  end case
end function

function main(): Unit uses Console.Write
  let result = handle
    sumPositive([3, -1, 4], 0)
  when write(message):
    Console.writeLine("log: ${message}")
    resume(())
  end handle
  Console.writeLine("sum: ${result}")
end function
```

### Reading JSON, running tasks and serving HTTP

```benitoite
import Benitoite.IO.Console
import Benitoite.IO.File
import Benitoite.Json
import Benitoite.Network.Http

function readTotal(path: String): Result[Integer, String] uses File.Read
  let text = (File.readText(path) |> Result.mapError(_, IOError.message))?
  let value = (Json.parse(text) |> Result.mapError(_, Json.ParseError.message))?
  let items = (Json.asArray(value) |> Option.okOr(_, "expected an array"))?
  return Result.Ok(List.fold(items, 0, lambda(sum, item)
    return case Json.get(item, "amount") of
      when Option.Some(Json.Value.Integer(n)): sum + n
      when _: sum
    end case
  end lambda))
end function

function route(request: Http.Request): Http.Response
  let segments = Http.pathSegments(Http.Request.path(request))
  return case Pair(Http.Request.method(request), segments) of
    when Pair("GET", []): Http.text(200, "hello")
    when Pair("GET", ["items", id]): Http.json(200, Json.Value.String(id))
    when _: Http.text(404, "not found")
  end case
end function

function main(): Result[Unit, String] uses Console.Write, File.Read, Http.Listen, State
  let totals = Task.all([
    lambda() return readTotal("a.json") end lambda,
    lambda() return readTotal("b.json") end lambda
  ])
  List.forEach(totals, lambda(t)
    Console.writeLine(Result.map(t, Integer.toString) |> Result.unwrapOr(_, "error"))
  end lambda)
  return Http.serve("127.0.0.1", 8080, route) |> Result.mapError(_, NetworkError.message)
end function
```
