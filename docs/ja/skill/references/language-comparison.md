# Benitoite とほかの言語の比較

> この文書は、`crates/benitoite/skill/references/language-comparison.md` の日本語の訳である。翻訳元は Benitoite 0.0.11 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

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
- 表の中のコードと、ほかの情報文字列のブロックは検査しない。各表の後の例は、表と同じ形を使う。
-->

Python、JavaScript、Rust のよく使う構文を、Benitoite でどう書くかを示す。prelude の外のモジュール（`Console`、`File`、`Process`、`Json`、`Csv`、`Http` など）は取り込まなければならない。取り込みの名前は `stdlib/index.md`（[英語の原文](../../../../crates/benitoite/skill/references/stdlib/index.md)）を参照する。

## 構文

失敗の伝播については、Rust の `?` は `try result or return` に対応する。裸の `try result` も、同じ失敗を返す意味を保つ。原因を報告して実行を終えるには、Process.Exit とともに `try result or die` を使う。囲む関数の戻り値の型は任意であり、Result のエラーには Show を要する。例外ハンドラではない。[プログラムの形と誤りの扱い](idioms.md#プログラムの形と誤りの扱い)を参照する。

| Python | JavaScript | Rust | Benitoite |
|---|---|---|---|
| `int` | `number` | `i64` | `Integer` |
| `float` | `number` | `f64` | `Float` |
| `str` | `string` | `String` | `String` |
| `bool` | `boolean` | `bool` | `Boolean` |
| `list[int]` | `number[]` | `Vec<i64>` | `List[Integer]` （型の引数には `<>` ではなく必ず `[]` を使う） |
| `dict[str, int]` | `Map<string, number>` | `BTreeMap<String, i64>` | `Map[String, Integer]` |
| `Optional[int]` | `number \| null` | `Option<i64>` | `Option[Integer]` |

| Python | JavaScript | Rust | Benitoite |
|---|---|---|---|
| `x = 1` | `const x = 1` | `let x = 1;` | `bind x <- 1` |
| `x = x + 1`（再束縛） | `let x; x = x + 1` | `let x = x + 1;` | `bind increased <- x + 1`（新しい名前を推奨する。`shadow` は有効だが非推奨） |
| `def f(a: int) -> int:` | `function f(a) {` | `fn f(a: i64) -> i64 {` | `function f(a: Integer) -> Integer` ... `end function` |
| `lambda a: a + 1` | `(a) => a + 1` | `\|a\| a + 1` | `lambda(a) return a + 1` |
| `if c: ... elif d: ... else: ...` | `if (c) {} else if (d) {} else {}` | `if c {} else if d {} else {}` | `if c then ... else if d then ... else ... end if` |
| `a if c else b` | `c ? a : b` | `if c { a } else { b }` | `match c with` / `case true -> a` / `case false -> b` / `end match` |
| `match v:` / `case ...:` | `switch (v)` | `match v { p => e }` | `match v with` / `case p -> e` / `end match` |
| `==`, `!=` | `===`, `!==` | `==`, `!=` | `=`, `<>` |
| `and`, `or`, `not` | `&&`, `\|\|`, `!` | `&&`, `\|\|`, `!` | `and`, `or`, `not` |
| `7 // 2`, `7 % 2` （負の無限大の方向に丸める） | `Math.floor(7 / 2)` | `7_i64.div_euclid(2)` | `Integer.floorDivide(a: 7, b: 2)`, `Integer.floorModulo(a: 7, b: 2)` |
| `int(7 / 2)`, `math.fmod(7, 2)` （0 への丸め） | `Math.trunc(7 / 2)`, `7 % 2` | `7 / 2`, `7 % 2` | `7 div 2`, `7 mod 2` |
| `7 / 2` | `7 / 2` | `7.0 / 2.0` | `7.0 / 2.0` （どちらも `Float`。`Integer` には `/` を使えない） |
| `f"{name}: {n}"` | `` `${name}: ${n}` `` | `format!("{name}: {n}")` | `"${name}: ${n}"` |
| `"a" + "b"` | `"a" + "b"` | `format!("{a}{b}")` | `"a" + "b"` |
| `# comment` | `// comment` | `// comment` | `// comment` |
| `None` | `null`, `undefined` | `None` | `Option.None` |
| `Some` に相当する値 | 値そのもの | `Some(x)` | `Option.Some(x)` |
| `raise E(...)` / `try:` | `throw` / `try {}` | `Err(e)` / `?` | `return Result.Error(e)` / `try expr or return` |
| フィールドを持つ `class P:` | `{ name, age }` | `struct P { name: String }` | `record P` ... `end record` |
| `P(name="a")` | `{ name: "a" }` | `P { name: "a".into() }` | `P(name: "a")` |
| `p.name` | `p.name` | `p.name` | `P.name(p)` |
| `dataclasses.replace(p, age=3)` | `{ ...p, age: 3 }` | `P { age: 3, ..p }` | `P(..p, age: 3)` |
| `Enum` / タグ付き共用体 | タグ付きのオブジェクト | `enum Shape { Circle(f64) }` | `data Shape` / `Circle(Float)` / `end data` |
| `for x in xs:` | `for (const x of xs)` | `for x in xs {}` | `List.forEach(xs: xs, f: lambda(value) ...)` |
| `while` のループ | `while` のループ | `loop` / `while` | 再帰する関数 |
| `import json` | `import fs from "fs"` | `use std::fs;` | `import Benitoite.Unofficial.Json` |
| `def main():` | トップレベルのコード | `fn main()` | `function main() -> Result[Unit, String] uses ...` |

値や処理の選択には `match` を推奨する。条件成立時だけの処理や早期リターンには、`else` のない `if` を使う。表には有効な構文を説明するために `else if` を残しているが、これと `else` は推奨しない。条件の評価順序と回数、分岐の評価、`return` の作用先を保つ。エフェクトを含む条件では、真偽値に対する match を入れ子にする。包括的な最後のパターンには、衝突しない通常の名前を推奨する。構成子内、捨てる束縛、部分適用の `_` はこの推奨の対象ではない。短いラムダは全体が同じ物理行に収まらなければならない。複数行の本体は見出しの次の行に始め、`end lambda` を要する。終端の対応と入れ子のラムダは `grammar.md` を参照する。

数値と範囲についての注意:

- `Integer` は 64 ビットである。桁あふれは、プログラムを実行時エラーで止める（Python の整数には上限がない）。
- `div` は 0 へ向けて丸め、`mod` の符号は被除数に従う: `-7 div 2` は `-3`、`-7 mod 2` は `-1` である。Python の `//` と `%` は負の無限大の方向に丸める（`-7 // 2` は `-4`、`-7 % 2` は `1`）。その振る舞いには `Integer.floorDivide` と `Integer.floorModulo` を使う。
- 0 による `div` と `mod` は、プログラムを実行時エラーで止める。`Float` の 0 による除算は、無限大か NaN になる。
- `Integer` には `/` がない。小数の結果が必要なときは、先に `Integer.toFloat` で変換する。
- 範囲のパターン `case 0..19` は両端を含む（Rust の `0..=19`）。`List.range(start: 0, stop: 20)` は上端を含まない（Rust の `0..20`、Python の `range(0, 20)`）。

`null`、例外、可変の変数、ループの文はない。IO を行う関数は、そのエフェクトを `uses` の後に並べる。

```benitoite
import Benitoite.Unofficial.IO.Console

record Person
  name: String
  age: Integer
end record

function describe(p: Person) -> String
  bind group <- match Person.age(p) < 20 with
    case true -> "young"
    case false -> "adult"
  end match
  return "${Person.name(p)} (${group})"
end function

function main() -> Unit uses Console.Write
  bind ada <- Person(name: "Ada", age: 36)
  bind older <- Person(..ada, age: Person.age(ada) + 1)
  Console.writeLine(describe(older))
  Console.writeLine("${7 div 2} ${7 mod 2} ${Float.toString(7.0 / 2.0)}")
  Console.writeLine("${-7 div 2} ${-7 mod 2} ${Integer.floorDivide(a: -7, b: 2)} ${Integer.floorModulo(a: -7, b: 2)}")
  bind label <- match Person.age(older) with
    case 0..19 -> "teen or child"
    case n if n >= 65 -> "senior"
    case otherAge -> "working age"
  end match
  Console.writeLine(label)
  return ()
end function
```

```output
Ada (adult)
3 1 3.5
-3 -1 -4 1
working age
```

## 関数

二つ以上のパラメータを持つ通常の呼び出しでは、各引数に宣言の名前でラベルを付ける。ラベルは任意の順に書けるが、引数の式は呼ぶ関数の式の後、ソースの記述順に実行する。一引数の呼び出しはラベルを省ける。コールバックの名前と順序は関数型の一部である。`List.map` が求める型は `function(value: T) -> U` なので、別のパラメータ名を持つ既存の関数には `lambda(value) return Integer.toString(value)` のように包むラムダが必要である。`List.fold` が求める名前は `acc, value` であり、未使用のパラメータも期待する名前を保つ。穴、パイプ、生成される名前は `idioms.md` を参照する。

| Python | JavaScript | Rust | Benitoite |
|---|---|---|---|
| `print(s)` | `console.log(s)` | `println!("{s}")` | `Console.writeLine(s)` （エフェクト `Console.Write`） |
| `print(s, end="")` | `process.stdout.write(s)` | `print!("{s}")` | `Console.write(s)` |
| `sys.stderr.write(s)` | `console.error(s)` | `eprintln!("{s}")` | `Console.writeErrorLine(s)` |
| `input()` | `readline` | `stdin().read_line` | `Console.readLine()` （エフェクト `Console.Read`） |
| `str(n)` | `String(n)` | `n.to_string()` | `Integer.toString(n)`, `Float.toString(x)` |
| `int(s)` | `parseInt(s)` | `s.parse::<i64>()` | `Integer.parse(s)` （`Option[Integer]` を返す） |
| `float(n)` | `Number(n)` | `n as f64` | `Integer.toFloat(n)` |
| `len(xs)` | `xs.length` | `xs.len()` | `List.length(xs)` |
| `len(s)` | `s.length` | `s.chars().count()` | `String.characterCount(s)` |
| `xs[i]` | `xs[i]` | `xs.get(i)` | `List.get(xs: xs, i: i)` （`Option` を返す） |
| `xs + [x]` | `[...xs, x]` | `xs.push(x)` | `List.append(xs: xs, x: x)` （新しいリストを返す） |
| `[f(x) for x in xs]` | `xs.map(f)` | `xs.iter().map(f)` | `List.map(xs: xs, f: f)` |
| `[x for x in xs if p(x)]` | `xs.filter(p)` | `xs.iter().filter(p)` | `List.filter(xs: xs, p: p)` |
| `functools.reduce(f, xs, init)` | `xs.reduce(f, init)` | `xs.iter().fold(init, f)` | `List.fold(xs: xs, initial: init, f: f)` |
| `sorted(xs)` | `xs.toSorted((a, b) => a - b)` | `xs.sort()` （その場で並べ替える） | `List.sort(xs)` （新しいリストを返す） |
| `range(a, b)` | | `a..b` | `List.range(start: a, stop: b)` |
| `s.split(",")` | `s.split(",")` | `s.split(',')` | `String.split(s: s, separator: ",")` |
| `",".join(xs)` | `xs.join(",")` | `xs.join(",")` | `String.join(xs: xs, separator: ",")` |
| `s.strip()` | `s.trim()` | `s.trim()` | `String.trim(s)` |
| `s.splitlines()` | `s.split("\n")` | `s.lines()` | `String.lines(s)` |
| `x in s`（文字列） | `s.includes(x)` | `s.contains(x)` | `String.contains(s: s, part: x)` |
| `{"a": 1}` | `new Map([["a", 1]])` | `BTreeMap::from([("a", 1)])` | `Map.fromList([Pair("a", 1)])` （Python のような挿入の順ではなく、キーの順に並ぶ） |
| `d.get(k)` | `m.get(k)` | `m.get(&k)` | `Map.get(m: m, k: k)` （`Option` を返す） |
| `d[k] = v` | `m.set(k, v)` | `m.insert(k, v)` | `Map.set(m: m, k: k, value: v)` （新しいマップを返す） |
| `set(xs)` | `new Set(xs)` | `HashSet::from_iter` | `Set.fromList(xs)` |
| `open(p).read()` | `fs.readFileSync(p, "utf8")` | `fs::read_to_string(p)` | `File.readText(p)` （エフェクト `File.Read`） |
| `open(p, "w").write(s)` | `fs.writeFileSync(p, s)` | `fs::write(p, s)` | `File.writeText(path: p, text: s)` （エフェクト `File.Write`） |
| `os.path.exists(p)` | `fs.existsSync(p)` | `Path::new(p).exists()` | `File.exists(p)` |
| `json.loads(s)` | `JSON.parse(s)` | `serde_json::from_str(s)` | `Json.parse(s)` |
| `json.dumps(v)` | `JSON.stringify(v)` | `serde_json::to_string(&v)` | `Json.stringify(v)` |
| `csv.reader(f)` | | `csv::Reader` | `Csv.parse(text)` |
| `subprocess.run(["ls", "-l"])` | `execFileSync("ls", ["-l"])` | `Command::new("ls").arg("-l")` | `Process.run(Process.command(program: "ls", arguments: ["-l"]))` （エフェクト `Process.Run`） |
| `subprocess.run(s, shell=True)` | `execSync(s)` | `Command::new("sh").arg("-c")` | `Process.shell(s)` |
| `sys.argv[1:]` | `process.argv.slice(2)` | `env::args().skip(1)` | `Process.arguments()` （エフェクト `Process.Environment`） |
| `os.environ.get(k)` | `process.env[k]` | `env::var(k)` | `Process.environmentVariable(k)` |
| `sys.exit(2)` | `process.exit(2)` | `std::process::exit(2)` | `Process.exit(2)` （エフェクト `Process.Exit`） |
| `time.sleep(1)` | `setTimeout` | `thread::sleep` | `Clock.sleep(1000)` （エフェクト `Clock.Time`） |
| `random.randint(1, 6)` | | `rng.gen_range(1..7)` | `Random.integer(low: 1, high: 7)` （エフェクト `Random.Generate`。`high` は含まない） |
| `random.random()` | `Math.random()` | `rng.gen::<f64>()` | `Random.float()` |
| `requests.get(url)` | `fetch(url)` | `reqwest::get(url)` | `Http.get(url)` （エフェクト `Http.Connect`） |
| `assert a == b` | `assert.equal(a, b)` | `assert_eq!(a, b)` | `Assert.equal(actual: a, expected: b)` （`@test` の関数の中で） |

任意の環境のマップを子プロセスの API へ渡す場合と異なり、`Process.Command.environment` の明示設定には、`DYLD_` または `LD_` で始まる名前を使えない（ASCII の大文字小文字を区別しない）。`LD_RUN_PATH`、空値、同じ値の上書きも含む。`Process.run` と `Process.runAttached` はどちらも、子を起動する前に `IOErrorKind.InvalidInput` を返す。`Process.shell` も含め、継承する変数は変えない。`Process.Run` を了承すると、コマンド自身が変数を設定することは依然として可能である。これは入力の規則であり、プロセスを隔離しない。[外部のコマンドの実行](idioms.md#外部のコマンドの実行)を参照する。

Benitoite の宣言したエフェクトは、実行前に検査報告で確認できる。`benitoite check --report=json main.bnt` または `benitoite test --check --report=json tests/` を使い、見直した原子的な集合を、`--allow-effects=<names>` で `run` または実行する `test` へ渡す。テストでは `Assert.Check` を残す。これらは静的な上限であり、サンドボックスや意図した結果の保証ではない。同じ集合で異なるファイルやコマンドを許すこともある。テストの検査報告はテストを実行しない。対応機能の問い合わせと完全な結果の確認は、[実行前の検査](inspection.md)を参照する。

同じ作業を Benitoite で書いたもの（コメントに Python の同等のコードを示す）:

```files
name: words.txt
the quick brown fox
jumps over the lazy dog
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

// counts = {}
// for word in open("words.txt").read().split():
//     counts[word] = counts.get(word, 0) + 1
// for word in sorted(counts):
//     if counts[word] > 1: print(f"{word} {counts[word]}")
function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try File.readText("words.txt") or die
  bind words <- List.filter(xs: String.split(s: String.replace(s: text, old: "\n", new: " "), separator: " "), p: lambda(value) return value <> "")
  bind counts <- List.fold(xs: words, initial: Map.empty(), f: lambda(acc, value)
    return Map.set(m: acc, k: value, value: Option.unwrapOr(o: Map.get(m: acc, k: value), fallback: 0) + 1)
  end lambda)
  Map.forEach(m: Map.filter(m: counts, p: lambda(key, value) return value > 1), f: lambda(key, value)
    Console.writeLine("${key} ${value}")
  end lambda)
  Console.writeLine("${List.length(words)} words, ${Map.size(counts)} distinct")
  return ()
end function
```

```output
the 2
9 words, 8 distinct
```
