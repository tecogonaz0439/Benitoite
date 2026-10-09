//! 字句の間の空白と字下げの整形のテスト（設計書 06-03「字句の間の空白」「字下げ」、
//! 07-03「テストの種類（初回リリース版）」のフォーマッタ）。入力はコメント・空の行・複数行の文字列を含まない
//! ソースに限り（10-17「書き出し」の D01 の範囲）、本物の字句解析・構文解析・役割の表をつないで整形する。
// テストの失敗は panic で表す（00-02「`#[allow]` を書いてよい箇所」）
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use crate::cli::tools::formatter::roles::tests::format;

/// 06-03「字句の間の空白」の表の各行。
const SPACES_INPUT: &str = "\
function main() -> Unit
f( x )
bind xs <- [ 1 , 2 ]
bind u <- ( )
bind n : Integer <- 0
Console . writeLine(n)
bind q <- Person( .. p , age : 1 )
bind r <- [ first , .. rest ]
bind m <- f (x) (y)
bind neg <- - x
bind sum <- - (a + b)
bind s <- \"total: ${ total } and ${ x }!\"
bind l <- lambda (x) return x end lambda
bind t: List [Integer] <- xs
match x with
case 90 .. 100 -> f (a , b)
case 'a' .. 'z' -> ()
case - 1 -> ()
case Shape.Rect (w , h) -> ()
case Person (age : a , ..) -> ()
end match
end function
function getOr [A] (opt : Option [A], default : A) -> A
return default
end function
function apply(f: function (Integer) -> Integer) -> Integer
return f (1)
end function
@ test
function check() -> Unit
()
end function
@ deprecated ( \"use other\" )
function tagged() -> Unit
()
end function
implement [T: Show] Show [Option [T]]
function show(value: Option[T]) -> String
return \"\"
end function
end implement
data Pair [A, B]
Pair (A, B)
end data
function handler() -> Unit
handle
Ask.ask ()
with
case Ask.ask () -> resume (())
end handle
end function
";

const SPACES_EXPECTED: &str = "\
function main() -> Unit
  f(x)
  bind xs <- [1, 2]
  bind u <- ()
  bind n: Integer <- 0
  Console.writeLine(n)
  bind q <- Person(..p, age: 1)
  bind r <- [first, ..rest]
  bind m <- f(x)(y)
  bind neg <- -x
  bind sum <- -(a + b)
  bind s <- \"total: ${total} and ${x}!\"
  bind l <- lambda(x) return x end lambda
  bind t: List[Integer] <- xs
  match x with
    case 90..100 -> f(a, b)
    case 'a'..'z' -> ()
    case -1 -> ()
    case Shape.Rect(w, h) -> ()
    case Person(age: a, ..) -> ()
  end match
end function

function getOr[A](opt: Option[A], default: A) -> A
  return default
end function

function apply(f: function(Integer) -> Integer) -> Integer
  return f(1)
end function

@test
function check() -> Unit
  ()
end function

@deprecated(\"use other\")
function tagged() -> Unit
  ()
end function

implement[T: Show] Show[Option[T]]
  function show(value: Option[T]) -> String
    return \"\"
  end function
end implement

data Pair[A, B]
  Pair(A, B)
end data

function handler() -> Unit
  handle
    Ask.ask()
  with
    case Ask.ask() -> resume(())
  end handle
end function
";

/// 06-03「字句の間の空白」の表の後の段落。括弧の式・リスト・`()` の前は空白を置き、
/// `(`・`[` と単項の `-` の直後は表が優先する。
const PARENS_INPUT: &str = "\
function main() -> Unit
return(x)
bind b <- not(a or b)
match x with
case[x, ..rest] -> ()
end match
bind c <- if a then 0 else(if b then 1 end if) end if
f( (a) )
bind d <- -( x )
bind e <- [ [1] ]
bind g <- try(f(x))
end function
";

const PARENS_EXPECTED: &str = "\
function main() -> Unit
  return (x)
  bind b <- not (a or b)
  match x with
    case [x, ..rest] -> ()
  end match
  bind c <- if a then 0 else (if b then 1 end if) end if
  f((a))
  bind d <- -(x)
  bind e <- [[1]]
  bind g <- try (f(x))
end function
";

/// 二項演算子と `<-` の前後は空白一つ。連続する束縛の `<-` は揃えない。
const OPERATORS_INPUT: &str = "\
function main() -> Unit
bind a<-1+2*3-4/5
shadow abc    <- a div 2 mod 3
bind c<-a=b and c<>d or e<=f
bind d  <-  a<b or a>b or a>=b
bind e<-xs|>List.map(f)
bind f<-lambda(x)->Integer return x end lambda
end function
";

const OPERATORS_EXPECTED: &str = "\
function main() -> Unit
  bind a <- 1 + 2 * 3 - 4 / 5
  shadow abc <- a div 2 mod 3
  bind c <- a = b and c <> d or e <= f
  bind d <- a < b or a > b or a >= b
  bind e <- xs |> List.map(f)
  bind f <- lambda(x) -> Integer return x end lambda
end function
";

/// 06-03「字下げ」の表の各構文。
const BLOCKS_INPUT: &str = "\
function f(x: Integer) -> Integer
return x
end function
data Shape
Circle(Float)
Rect(Float, Float)
end data
record Person
name: String
age: Integer
end record
trait Show[T]
function show(value: T) -> String
end trait
implement Show[Integer]
function show(value: Integer) -> String
return \"int\"
end function
end implement
effect Ask
function ask() -> Integer
end effect
function main() -> Unit uses Console.Write
bind f <- lambda(x)
return x
end lambda
bind w <- with a = 1,
b = 2 do
return a
end with
bind z <- lazy
1
end lazy
if c then
a()
else if d then
b()
else
c()
end if
bind m <- match x with
case 1 ->
a()
case _ -> b()
end match
bind h <- handle
Ask.ask()
with
case Ask.ask() ->
resume(1)
end handle
bind xs <- [
1,
2
]
g(
a,
b
)
end function
";

const BLOCKS_EXPECTED: &str = "\
function f(x: Integer) -> Integer
  return x
end function

data Shape
  Circle(Float)
  Rect(Float, Float)
end data

record Person
  name: String
  age: Integer
end record

trait Show[T]
  function show(value: T) -> String
end trait

implement Show[Integer]
  function show(value: Integer) -> String
    return \"int\"
  end function
end implement

effect Ask
  function ask() -> Integer
end effect

function main() -> Unit uses Console.Write
  bind f <- lambda(x)
    return x
  end lambda
  bind w <- with a = 1,
    b = 2 do
    return a
  end with
  bind z <- lazy
    1
  end lazy
  if c then
    a()
  else if d then
    b()
  else
    c()
  end if
  bind m <- match x with
    case 1 ->
      a()
    case _ -> b()
  end match
  bind h <- handle
    Ask.ask()
  with
    case Ask.ask() ->
      resume(1)
  end handle
  bind xs <- [
    1,
    2
  ]
  g(
    a,
    b
  )
end function
";

/// `with` の 2 つ目以降の束縛の行（ADR 0323 の `Http.serve` の例）。
const WITH_INPUT: &str = "\
function serve() -> Unit
      with listener = try listen(host, port),
             group = TaskGroup.open() do
        return serveLoop(listener, group, handler)
      end with
end function
";

const WITH_EXPECTED: &str = "\
function serve() -> Unit
  with listener = try listen(host, port),
    group = TaskGroup.open() do
    return serveLoop(listener, group, handler)
  end with
end function
";

/// 規則 4 の続きの行（06-03「字下げ」の二つの例）と、一行で複数の構文を開く例。
const CONTINUATION_INPUT: &str = "\
function main() -> Unit
bind total <- price
* quantity
bind n <- lines
|> List.filter(lambda(l) return l <> \"\" end lambda)
|> List.length
List.forEach(items, lambda(item)
bind name <- Item.name(item)
Console.writeLine(name)
end lambda)
f(a,
b +
c)
bind w <- 1 +
with a = 1,
b = 2 do
a
end with
end function
";

const CONTINUATION_EXPECTED: &str = "\
function main() -> Unit
  bind total <- price
    * quantity
  bind n <- lines
    |> List.filter(lambda(l) return l <> \"\" end lambda)
    |> List.length
  List.forEach(items, lambda(item)
    bind name <- Item.name(item)
    Console.writeLine(name)
  end lambda)
  f(a,
    b +
      c)
  bind w <- 1 +
    with a = 1,
      b = 2 do
      a
    end with
end function
";

/// `match` の分岐と `handle` の節の頭（パターン・ガード・操作の引数）を改行したときの続きの行は、
/// その `case` の行より一段深くする（06-03「字下げ」の規則 4、ADR 0326）。
const ARM_HEAD_INPUT: &str = "\
function main() -> Unit
match x with
case n if n > 0
and n < 10 -> f()
case Shape.Circle(r),
Shape.Square(r) ->
g()
end match
handle
f()
with
case Ask.ask(a,
b) -> resume(1)
end handle
end function
";

const ARM_HEAD_EXPECTED: &str = "\
function main() -> Unit
  match x with
    case n if n > 0
      and n < 10 -> f()
    case Shape.Circle(r),
      Shape.Square(r) ->
      g()
  end match
  handle
    f()
  with
    case Ask.ask(a,
      b) -> resume(1)
  end handle
end function
";

const CASES: &[(&str, &str, &str)] = &[
    ("spaces", SPACES_INPUT, SPACES_EXPECTED),
    ("parentheses", PARENS_INPUT, PARENS_EXPECTED),
    ("operators", OPERATORS_INPUT, OPERATORS_EXPECTED),
    ("blocks", BLOCKS_INPUT, BLOCKS_EXPECTED),
    ("with bindings", WITH_INPUT, WITH_EXPECTED),
    ("continuations", CONTINUATION_INPUT, CONTINUATION_EXPECTED),
    (
        "match arm and handle clause heads",
        ARM_HEAD_INPUT,
        ARM_HEAD_EXPECTED,
    ),
];

#[test]
fn formats_into_the_canonical_form() {
    for (name, input, expected) in CASES {
        assert_eq!(format(input), *expected, "case: {name}");
    }
}

#[test]
fn canonical_forms_are_fixed_points() {
    for (name, _, expected) in CASES {
        assert_eq!(format(expected), *expected, "case: {name}");
    }
}

/// 入れ子の深さが構文解析器の上限（`MAX_DEPTH`）の近くでも、普通のテストのスレッドのスタックで整形できる
/// （00-02「再帰の深さ」、D01「手順の要点」の 8）。
#[test]
fn deep_nesting_uses_the_default_test_thread_stack() {
    let wrap = |body: String| format!("function main() -> Unit\n{body}\nend function\n");
    let one_line = [
        (
            "parentheses",
            format!("{}x{}", "( ".repeat(997), " )".repeat(997)),
            format!("  {}x{}", "(".repeat(997), ")".repeat(997)),
        ),
        (
            "lists",
            format!("{}x{}", "[ ".repeat(997), " ]".repeat(997)),
            format!("  {}x{}", "[".repeat(997), "]".repeat(997)),
        ),
        (
            "calls",
            format!("f{}", " ()".repeat(997)),
            format!("  f{}", "()".repeat(997)),
        ),
        (
            "unary",
            format!("{}x", "- ".repeat(997)),
            format!("  {}x", "-".repeat(997)),
        ),
    ];
    for (name, input, expected) in one_line {
        assert_eq!(format(&wrap(input)), wrap(expected), "case: {name}");
    }
    // 行ごとに一段ずつ深くなる `if` の入れ子
    let depth = 490;
    let mut input = String::new();
    let mut expected = String::new();
    for level in 0..depth {
        input.push_str("if c then\n");
        expected.push_str(&format!("{}if c then\n", "  ".repeat(level + 1)));
    }
    input.push_str("x\n");
    expected.push_str(&format!("{}x\n", "  ".repeat(depth + 1)));
    for level in (0..depth).rev() {
        input.push_str("end if\n");
        expected.push_str(&format!("{}end if\n", "  ".repeat(level + 1)));
    }
    let input = format!("function main() -> Unit\n{input}end function\n");
    let expected = format!("function main() -> Unit\n{expected}end function\n");
    assert_eq!(format(&input), expected);
}
