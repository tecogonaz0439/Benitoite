# Benitoite でよくある誤り

> この文書は、`crates/benitoite/skill/references/common-mistakes.md` の日本語の訳である。翻訳元は Benitoite 0.0.10 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

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

## 検査報告・診断・実行の混同

- `benitoite check` は `main` を要求する。テストのファイルには、実行せずに検査する `benitoite test --check` を使い、契約を得るには `--report=json` を加える。`test --report=json` だけでは使い方の誤りになり、結果の形式を変えてテストを実行することにはならない。
- `--diagnostics=json` だけなら、診断の JSON Lines を選ぶ。`check --report=json` と `test --check --report=json` は、診断を中に含む一つのオブジェクトを標準出力へ書く。明示した `--diagnostics=text` は報告と併用できない。集計を受理するには、既知の版と kind を持つ完全なオブジェクト、`status: "ok"`、`complete: true`、終了状態 0 を要求する。null や欠けた契約は不明であり、純粋ではない。
- E0512 は、改めて検査した宣言上限が `--allow-effects` を超えたことを表す。許す集合を変える前に、追加されたエフェクトを検査して見直す。拒否された集合を自動で写して了承済みとしない。空白や重複を含まない原子的な正規名を使う。`IO.All`、別名、`*` は許さない。外部操作を宣言していなくても、テストには `Assert.Check` が必要である。`IO.All` はこれと HTTP のエフェクトを含まない。純粋な集合は `--allow-effects=` と書く。
- エフェクト上限を指定すると、一つでもテストの入口の準備に失敗すれば、すべてのテストの開始を拒否する。成功数も失敗数もゼロであることだけでは、成功と判断できない。終了状態、集計の有無、`filesNotRun`、`interrupted` を確かめる。非実行の検査にはテストの集計行がない。
- ソースのハッシュは次の実行の入力を固定せず、了承済みのエフェクト集合もファイル・コマンド・内容を固定しない。shell の参照は呼び出しや到達性の証明ではなく、参照がないことも外部コマンドからシェルを起動できないことを示さない。隔離はハーネスか OS で行う。

手順全体と部分結果の規則は、[実行前の検査](inspection.md)を参照する。

## 禁止されたコマンド環境変数の設定

`Process.run` と `Process.runAttached` は、`Command.environment` に明示した名前が `DYLD_` または `LD_` で始まる場合、ASCII の大文字小文字を区別せず、子を起動する前に `IOErrorKind.InvalidInput` を持つ `Result.Error` を返す。ビルドの道具が使う `LD_RUN_PATH`、空値、継承した値と同じ値への再設定も含む。静的検査は成功することもある。失敗は Result の値であり、新しい E 診断ではない。`or die` を使うと、既存の die の報告と終了状態 1 になる。

明示設定を見直して取り除くか、対応する操作を選ぶ。親の環境へ設定を移したり、シェルで規則を回避したりする案を勧めない。継承する変数は変えず、`Process.Run` を許せば、`env` のようなコマンドやシェル自身が変数を設定することも許す。この規則はプロセスを隔離しない。[外部のコマンドの実行](idioms.md#外部のコマンドの実行)を参照する。

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

短いラムダ（`grammar.md` を参照する）を除き、ブロックは、`end` とブロックを開いたキーワードで終わる。`end function`、`end if`、`end match`、`end lambda`、`end handle`、`end with`、`end data`、`end record`、`end block` である。

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

次の 36 語はキーワードである。`and`、`bind`、`block`、`case`、`const`、`data`、`die`、`div`、`do`、`effect`、`else`、`end`、`false`、`function`、`handle`、`if`、`implement`、`import`、`lambda`、`lazy`、`match`、`mod`、`not`、`or`、`public`、`record`、`resume`、`return`、`shadow`、`then`、`trait`、`true`、`try`、`type`、`uses`、`with`。`record` は、引数、引数のラベル、束縛、値の参照など、小文字の名前を要する位置でも使える。宣言の位置では引き続きレコードの宣言を始める。他のキーワードには別の名前を選ぶ。この制限は、引数のラベル、フィールド、取り込みの別名、ドットの後の名前にも適用する。`die` は失敗時の処置 `try value or die` と `try value or die(message)` としてだけ受理する。単独の `die` の式は拒否する。`Die`、`died`、`dieLater` は通常の識別子である。

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


## 定数の正規表現

不正な定数の source を使う Regex.compile の直接呼び出しは、テストや match の内側でも E0457（構文）または E0458（実行時のコンパイル制限）で拒否する。取り込みの別名も対象である。トップレベルの const は引き続き Regex.compile を呼べない（E0433）。Result.Error のテストには、String を引数に取る通常の関数内で Regex.compile(source) を呼び、不正なパターンをその関数へ渡す。動的入力、局所の関数値、穴、パイプは実行時の検査を保つ。追加検査の予算を超えても実行時に残す。検査の成功によって Result を除いたり、コンパイル済みのパターンを埋め込んだりはしない。

## 検査済みの Scope を権限と見なす

Scope.checkHost、Scope.checkPath、Scope.checkEndpoint は、条件と対象を保持した不透明な値を返す。公開の射影を使い、変更は検査し直す。外からの構築、更新、パターン、自動アクセサは E0340 となる。保存した条件が保証するのは表記の所属である。権限、DNS、実ファイルとリンク、隔離、IO の成功は別に判断する。

直接呼び出しは、既知の不正なパターン（E0459）、対象（E0460）、ポートと端点（E0461）、所属の不適合（E0462）をテスト内でも拒否する。Endpoint は既知のホストの二入力と整数の三入力を独立に検査する。実行時 Error のテストには通常の関数の引数を使う。局所の関数値、プレースホルダ、パイプは実行時に検査する。*.example.com は直前の一ラベル、**.example.com は一つ以上に一致する。どちらも example.com 自体には一致しない。パスのツリーは幹を含み、成分の境界で照合する。

不透明型の構成子は宣言モジュール内だけで使える。@opaque のデータ型とレコードは内容の等値規則に従う。等値比較から除くのは、IOError や Regex.Pattern など等値を持たない組み込みの不透明型と、外部の型である。

## コールバックへの構築器の捕捉

構築器は第二級の値であり、通常の関数の引数や格納できる可変コンテナではない。List.forEach へ渡すラムダは構築器を捕捉できない（E0465）。先に List.map で不変の断片を作って appendAll へ渡すか、コールバックを作る前に copy/length を束縛する。別モジュールの取り込みは名前を追加しないため、使うモジュールごとに各構築器を取り込む。直接の new と注釈付きの局所宣言を要する（E0463）。操作の関数値、穴、パイプは E0466 となる。宣言と専用操作は State を加えず、通常の引数のエフェクトは残る。block ... end block で局所の範囲から不変のコピーを返せる。copy は物理コピーであり、繰り返すと内容に比例する費用を要する。通常の Reference、タスク、リソースの解放のエフェクトは残る。
