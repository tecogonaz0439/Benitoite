# Benitoite

> この文書は、`crates/benitoite/skill/SKILL.md` の日本語の訳である。翻訳元は Benitoite 0.0.9 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

原文の前付けを次に示す。この訳では説明用の `text` ブロックであり、実際の YAML frontmatter ではない。`{{benitoite-version}}` は英語の Skill を取得・インストールするときに置換するための印であり、この説明の写しには残す。

```text
---
name: benitoite
description: Write, check, and run Benitoite scripts (`.bnt`) with the `benitoite` command.
license: MIT OR Apache-2.0
metadata:
  benitoite-version: "{{benitoite-version}}"
---
```

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
- ほかの情報文字列（`text` や `sh` など）のブロックは検査しない。
-->

Benitoite は、静的に型付けされる関数型のスクリプト言語である。スクリプトの拡張子は `.bnt` であり、コマンド `benitoite` で実行する。検査器は、何かを実行する前に、型の誤りと宣言していないエフェクトを報告する。変更のたびに検査器を使う。

## 最初に版を確かめる

`benitoite --version` を実行し、その最初の行の版（`benitoite X.Y.Z`）を、このファイルの先頭の `metadata.benitoite-version` と比べる。異なるときは、この Skill は別の版の言語を説明しているので、`benitoite skill install` をもう一度実行するよう利用者に伝える。

機械可読な対応機能の情報には、最初の引数だけに `--version=json` を指定して `benitoite --version=json` を実行する。既知の `schemaVersion` と、`formats` 内の必要な整数の版を要求し、リリース番号から対応を推測しない。未知の形式・状態・エフェクト名は未対応であり、成功や空集合として扱わない。ビルド情報はビルド時の自己申告である。`build.dirty: null` は変更なしではなく不明を表し、dirty の入力を省略した場合の由来は `notCollected` となる。

この実行ファイルの Skill をインストールせずに読むには、`benitoite skill list` と `benitoite skill show references/idioms.md` を使う。名前は一覧にある大文字小文字を区別する論理名であり、OS のパスではない。`--format=json` は一つの `skillList` または `skillDocument` オブジェクトを返す。長さと SHA-256 のハッシュは、このファイルの版の置換も含め、`install` が書くものと同じ置換後の UTF-8 本文を表す。これらの問い合わせは `HOME` やインストール済みの写しを調べない。ハーネスを連携させるときや検査の JSON を解釈するときは、[実行前の検査](references/inspection.md)を読む。

## スクリプトを作る手順

1. 書く前に、`references/idioms.md` と、スクリプトが使うモジュールごとにそのファイル `references/stdlib/<Module>.md` を読む（`references/` のディレクトリは、このファイルと同じ場所にある）。関数の名前、欄の名前、取り込みの名前を推測せず、そこで調べる。それからスクリプトを書く。合う例があれば、`references/idioms.md` の例から始める。
2. `benitoite check script.bnt` を実行し、利用者の関数を実行せずに検査する。
3. 標準エラー出力の診断を読み、スクリプトを直す。診断は `E0230` のようなコードを示す。その意味がわからないときは、`references/diagnostics.md` でコードを引く。
4. 検査が終了状態 0 で成功するまで、2 と 3 を繰り返す。警告も直す。警告はたいてい実際の誤りを指している。
5. [実行の前に](#実行の前に)の確認の直前に、`benitoite check --report=json script.bnt` を一度実行し、`main` の宣言したエフェクトを得る。完全な単一の JSON オブジェクト、既知の `schemaVersion` と `kind: "checkReport"`、`status: "ok"`、`complete: true`、終了状態 0 を要求する。欠けた報告、部分的な報告、失敗した報告を空のエフェクト集合として扱わない。失敗した場合は通常の検査に戻ってスクリプトを直し、確認の前に新しい報告を得る。
6. [実行の前に](#実行の前に)の確認を行い、`aggregateEffects.expanded` の了承済みの原子的な名前を使って、`benitoite run --allow-effects=<accepted names> script.bnt [arguments...]` を実行する。純粋なスクリプトには `--allow-effects=` と書く。`E0512` が追加のエフェクトを報告したら、許す集合を変える前に、もう一度検査して見直す。

`run` の終了コード: `main` が終わったときは 0、`main` が `Result.Error` を返したとき、処理されない `or die` が実行を終えたとき、プログラムが実行時エラーで止まったときは 1、スクリプトが検査を通らないとき、許すエフェクトを超えたとき、コンパイラの制限に達したとき、コマンドラインが誤っているときは 2、`benitoite` の処理系の不具合のときは 3 である。`Process.exit(n)` は `n` で終わる。`run` と実行する `test` は、中断されたとき（`SIGINT` か `SIGTERM`）に 130 で終わる。出力の失敗は 1 で終わる。

## テストの手順

`benitoite check` は `main` のないファイルに誤りを報告するので、テストのファイルには `check` を使わない。

1. テストの関数を書く（[テスト](#テスト)を参照する）。
2. `benitoite test --check file.bnt`（またはディレクトリ）を実行する。診断を直し、検査が終了状態 0 で成功するまで繰り返す。警告も直す。実行時と同じ選択済みテストを実行せずに検査し、`main` は要求しない。診断は標準エラー出力へ書き、標準出力には何も書かない。
3. 確認の直前に、`benitoite test --check --report=json file.bnt` を一度実行する。`kind: "testCheckReport"` とし、スクリプトと同じ報告の受理条件を適用する。失敗した場合は通常の `test --check` に戻ってファイルを直し、確認の前に新しい報告を得る。`aggregateEffects.expanded` にあるテストの関数の宣言したエフェクトの和を使い、[実行の前に](#実行の前に)の確認を行う。`Assert.Check` はテストの契約の一部なので、許す集合に残す。
4. `benitoite test --allow-effects=<accepted names> file.bnt` を実行する。このオプションを指定すると、すべての入口が準備とエフェクトの比較を通るまで、どのテストも開始しない。失敗すれば実行全体を拒否する。修正してもう一度検査し、許す集合を変える前に、追加されたエフェクトを利用者に示す。このオプションがなければ、検査の誤りがあるファイルを飛ばしてほかのファイルを実行できる。

文書の例を含める場合は、検査と実行の両コマンドに --doc を付ける。testCheckReport と testResults の版 2 を要求し、通常のテストと実行する例のエフェクトの和を確認する。check/error の例は実行の許可を増やさない。四モード、公開の取り込み、不完全な結果、集計は[実行前の検査](references/inspection.md)を参照する。

`test --check` は `--allow-effects`、`--max-call-stack`、すべての `--wasm-*` オプションを拒否する。`--check` のない `test --report=json` は使い方の誤りである。非実行の検査は `test` や `testSummary` の行を書かない。部分結果、終了状態、実行するテストの集計を扱うときは、[実行前の検査](references/inspection.md)を読む。

## 実行の前に

スクリプトを初めて実行する前と、`main` のエフェクトが前回利用者に示したものより増えたときには、次のことを行う。

1. 成功した検査報告の宣言上限（`main.effects` または選択された各テストの `effects`、および `aggregateEffects`）を読み、後掲の表の言葉で、プログラムが宣言する操作の種類を利用者に伝える。コードを説明するときは `uses` のシグネチャと照合する。宣言して使わないエフェクトも数える。
2. 並びに `File.Write`、`Process.Run`、`Http.Connect`、`Http.Listen` のどれかがあるときは、実行する前に利用者に確認を求める。`Process.Run` については、スクリプトが起動するコマンドの名前も挙げる。それらのコマンドが何をするかは、`benitoite` の検査の範囲の外にある。
3. `IO.All` は `File.Write` と `Process.Run` を含むものとして扱う。`uses` には、`IO.All` の代わりに個別のエフェクトを書く。

`check` を通ったスクリプトは、`main` の `uses` の外の組み込みの操作を行わない。`--allow-effects` は、改めて検査した宣言上限が了承済みの集合に含まれることを確かめ、その同じ検査済みのプログラムを実行する。原子的な正規名を受け付け、取り込みの別名、`IO.All`、`*` は受け付けない。エフェクトが表すのは許される操作の種類だけであり、どのファイル・コマンド・ホストかは表さない。書き込み先や内容、`Process.Run` 内のコマンドの変更が、同じ集合に収まることもある。検査報告のハッシュは後の実行の入力を固定しない。静的検査は、意図した結果、停止性、外部操作の成功を保証しない。この版の `benitoite` は、実行中の操作を制限しない。スクリプトはエージェントのサンドボックスの中で実行する。

`processShellReference` は、使わない関数や依存も含め、検査したプログラム全体にある標準の shell 関数の式の参照を表す。到達性の解析ではない。`present` はシェルが実行される証明にはならず、`absent` も外部コマンドの安全性を示さない。`Process.Run` を了承するときは実際のコマンドを見直す。

`Process.run` と `Process.runAttached` は、`Command.environment` に明示した名前が `DYLD_` または `LD_` で始まる場合、ASCII の大文字小文字を区別せず、子を起動する前に `IOErrorKind.InvalidInput` で拒否する。`LD_RUN_PATH`、空値、同じ値の上書きも含む。`Process.shell` も含め、継承する変数は変えない。`Process.Run` を許せば、`env` やシェル自身がこれらの変数を設定することは依然として可能である。この入力の規則は OS の隔離の代わりにはならない。[外部のコマンドの実行](references/idioms.md#外部のコマンドの実行)を参照する。

| エフェクト | 利用者に伝える内容 |
|---|---|
| `Console.Write` | 標準出力と標準エラー出力に書く |
| `Console.Read` | 標準入力を読む |
| `File.Read` | ファイルとディレクトリを読む |
| `File.Write` | ファイルとディレクトリを作る・変える・移す・消す |
| `Process.Run` | 外部のコマンドを起動する（その名前を挙げる） |
| `Process.Exit` | 選んだ終了コードで実行を終える。`or die` は原因と任意の説明を標準エラー出力に報告し、終了状態 1 で終える |
| `Process.Environment` | コマンドラインの引数、環境変数、作業ディレクトリ、スクリプトのディレクトリを読む |
| `Clock.Time` | 時計を読み、時間が経つのを待つ |
| `Random.Generate` | 乱数を作る |
| `Http.Listen` | HTTP のサーバとしてネットワークの接続を受け付ける |
| `Http.Connect` | ネットワーク越しに HTTP のサーバへ接続する |
| `State` | プログラムの中で可変のセルと並行のタスクを使う（外部への作用はない） |
| `Assert.Check` | テストで期待を確かめる（外部への作用はない） |
| `IO.All` | 前掲の `Console`、`File`、`Process`、`Clock`、`Random`、`State` のすべて |

## ほかの言語と異なる言語の規則

- キーワードは 35 語ある。[キーワードを名前に使う](references/common-mistakes.md#キーワードを名前に使う)を参照する。`die` は予約語であり、ラベル、フィールド、取り込みの別名、ドットの後の名前を含め、名前に使えない。`try value or die` と `try value or die(message)` の中でだけ受理し、説明は純粋な String、Result のエラーには Show の制約、エフェクトには Process.Exit を要する。単独の `die` は拒否する。`fn`、`pub`、`impl`、`mut`、`async`、`await`、`spawn`、`select` は通常の名前のままであり、構文の略記ではない。宣言には `function`、`public`、`implement`、無名関数には `lambda` を使う。`as`、ファイルのヘッダの語、属性名は、それぞれの文脈でだけ特別な意味を持つ。`extensible` は通常の名前である。引数のない属性 `@extensible` は、データ型とレコードの宣言に使える。定義したパッケージの外では、ガードのない変数か `_` のパターンで将来の形も覆う必要がある。
- 短いラムダを除き、ブロックは `end` とキーワードで終わる: `end function`、`end if`、`end match`、`end lambda`、`end data`、`end record`、`end handle`、`end with`。波括弧も字下げの規則もない。
- 局所の名前は、`let` ではなく `bind x <- e` で束縛する。`shadow x <- e` は既に見えている局所名を隠せるが、推奨しない。意図的な隠蔽でも、新しい値の意味を表す別の名前を使う。名前に再代入はできない。
- 関数は `function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2` ... `end function` と書く。戻り値の型は `:` ではなく必ず `->` の後に書く。値は `return` で返す。値は `return` と同じ物理行で書き始める。直後の改行は、括弧の中でも文を終え、誤り（E0201）になる。値を書き始めた後は、通常の複数行の継続（演算子、括弧、呼び出しの引数、`then`）を使える。短いラムダは、一つの物理行に収める必要がある。
- 値や処理の選択には `match` を推奨する。条件成立時だけの処理や早期リターンには、`else` のない `if` を使う。`else` と `else if` は有効な構文だが、推奨しない。この助言による警告は加えない。条件の評価回数と順序を保ち、選ばれた分岐だけを評価し、`return` の作用先を同じ関数かラムダに保つ。エフェクトを含む条件をガードへ移さず、真偽値に対する match を入れ子にする。
- 包括的な最後の分岐には、`case other ->` や `case otherCode ->` のような、衝突しない名前を推奨する。予約語ではなく通常の束縛である。外側の局所名との衝突を避け、後ろに到達しない分岐を置かない。`case _ ->` も有効である。この助言は、構成子内、捨てる束縛、部分適用の `_` には適用しない。
- 一文には短いラムダを推奨する: `List.map(xs: xs, f: lambda(value) return value * 2)`。見出しと本体の全体が同じ物理行に収まる必要があり、`Unit` 以外の結果には `return` を要する。本体を見出しの最後の行に始める場合は、その一文の直後の同じ物理行にある `end lambda` だけを取る。後の行の終端は対応する外側のラムダを閉じる。空行やコメント行を挟んでも対応は変わらない。複数行の本体は見出しの次の行に始め、`end lambda` を加える。二文目を加える前に複数行形式に変える。フォーマッタは選んだ終端を保つ。
- 直接に入れ子になった二つのラムダのどちらかで終端を省く場合は、内側を括弧で囲む: `lambda(x) return (lambda(y) return x + y)`。呼び出しの引数と束縛文は、それぞれ独立した区切りとなる。`lambda(x) return x + 1 |> increment` のパイプは本体に属し、`(lambda(x) return x + 1)(3)` はラムダ自体を呼ぶ。
- パターンの照合は、`match value with` の後に、1 行に一つずつ `case pattern -> body` を書き、`end match` で終える。ハンドラは `handle body with` / `case Module.operation(arguments) -> clause` / `end handle` と書く。
- データ型は `data Name` ... `end data` で、レコードは `record Name` ... `end record` で宣言する。
- `IOErrorKind`、`NetworkErrorKind`、`Json.ParseError`、`Json.Codec.ConversionError`、`Csv.ParseError` には `@extensible` が付く。利用者のデータ型とレコードにも使える。定義したパッケージの外では、全既知構成子（`Other` を含む）を列挙した後でも、ガードのない変数か `_` で将来の形を覆う。レコードパターンの `..` は現在のフィールドの省略にすぎない。分解する `bind` の代わりに、取り出す関数か、将来の形の分岐を持つ `match` を使う。構築・更新・フィールドの取り出しは契約を保つ。レコードのフィールドの追加に互換性の保証はない。`Result` と `Option` は閉じた型のままである。[レコードとデータ型](references/idioms.md#レコードとデータ型)を参照する。
- 構成子は、式でもパターンでも型の名前を付けて書く: `Option.Some(x)`、`Option.None`、`Result.Ok(x)`、`Result.Error(e)`、`Shape.Circle(r)`。
- 演算子: `=` と `<>` は比較、`and`・`or`・`not` は論理演算、`div` と `mod` は整数の除算である。`+` は文字列の連結にも使う。`==`、`!=`、`&&`、`||`、`!` は存在しない。
- 再利用する関数・ライブラリ・コールバックには `try e or return` を使う。最も内側の関数かラムダから失敗を返し、その戻り値の型は、対応する Result か Option でなければならない。エラーの型が異なるときは、先に `Result.mapError` で変換する。裸の `try e` も同じ失敗を返す意味に固定し、Show の要件を加えない。入力は処置までのパイプを含む: `try File.readText(p) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return`。
- 失敗時に終える入口では、`try e or die` または `try e or die(message)` を推奨する。囲む関数の戻り値の型は任意であり、Process.Exit を加える。`uses Process.Exit` のために `Benitoite.Unofficial.IO.Process` を取り込む。Result のエラーには Trait.Show を要し、Option には要しない。IOError、NetworkError、Json.ParseError、Csv.ParseError の標準の Show は、message をそのまま返す。成功時は純粋な String の説明も Show も評価せず、失敗時は説明、Show、終了の順に評価する。ホストの報告に Console.Write は不要である。境界・ハンドラ・停止の規則は[プログラムの形と誤りの扱い](references/idioms.md#プログラムの形と誤りの扱い)を参照する。Result.Error を返す main や Process.Exit を使えない main には `or return` を使える。
- 二つ以上のパラメータを持つ通常の呼び出しでは、引数すべてにラベルを付ける: `List.map(xs: xs, f: action)`。名前付き引数と位置引数を混在させない。一引数の関数は `f(value)` または `f(name: value)`、引数がゼロなら `f()` と書く。ラベルは任意の順に書けるが、呼ぶ関数の式を最初に評価し、次に引数の式をソースの記述順に一度ずつ評価する。ラベルは局所の値ではなくパラメータを指す。組み込みの関数、関数値、メソッド、エフェクトの操作、外部の関数にもこの規則を適用する。直接のデータ構成子とパターン、属性、ハンドラの束縛、`resume` は専用の構文を保つ。
- 関数型には名前を含める: `function(value: T) -> U`。一引数でも、名前と順序はコールバックの契約と一致しなければならない。`List.map` は `value`、`List.fold` は `acc, value`、`Map.map` は `key, value`、`Result.mapError` は `error` を取る。未使用でも期待する名前を保ち、意味を表す別名には局所の `bind` を使う。契約が異なる関数は `lambda(value) return Integer.toString(value)` で包む。呼び出しのラベル順から契約を作らない。E0455 が契約の未確定を報告したら、名前を持つ関数型の注釈を加える。
- 直接の穴がなければ、`xs |> List.map(f: action)` は宣言上の最初のパラメータを満たす。残りの引数にラベルを付け、最初のパラメータを二度指定しない。評価順は、左辺を一度、次に右辺の呼ぶ関数の式、次に明示引数をソースの記述順である。直接の穴がある場合や右辺を括弧で囲んだ場合は、その結果の関数を一引数で呼ぶ。二つの穴を自動で部分適用することはない。
- `_` が部分適用を作るのは、呼び出しの直接の引数としてだけである: `Result.mapError(r: _, f: lambda(error) return IOError.message(error))`。穴は対応するパラメータ名をソース順に引き継ぎ、`f(b: _, a: _)` は `b, a` を取る。呼ぶ関数の式と固定した式は、生成した関数を呼ぶときに実行する。位置構成子の関数値と直接の構成子の穴は、`arg1`、`arg2`、…の元の位置名を使う。レコード構成子の関数値はフィールド名を使い、レコードの取り出す関数は `value` を取る。契約を合わせる例は `references/idioms.md` を参照する。
- `return` は関数とラムダの本体で使う。`if`、`match` の分岐、ハンドラの節の値は、その最後の式である。`case` の本体の中の `return` は、関数全体から戻る。値を作る関数とラムダは、最後の式が `match` や `if` のときも、`return` で終わらなければならない: `lambda(acc, value) return acc + value`。`lazy` の本体と `match` のガードは、`return` も `try` も含められない。ただし、そこに書いたラムダの中は除く（`_` を持つ呼び出しの中は除かない）。
- `Unit` 型の値は `()` と書く: `Result.Ok(())`。
- レコードは名前付きの引数で作り、型の名前で読む: `bind item <- Item(name: "pen", price: 120)`、`Item.price(item)`。一部を変えた写しは `Item(..item, price: 100)` で作る。`item.price`、`Item { ... }`、`Item(price = 100)` は誤りである。
- 呼び出しは型引数をとらない: `Map.empty[String, Integer]()` でなく `Map.empty()` と書く。map に項目を加えるのは `Map.set(m: m, k: key, value: value)` であり、`Map.insert` はない。`Integer.parse` などの解析の関数は `Option` を返す。
- 型の引数には角括弧を使う: `List[Integer]`、`Map[String, Integer]`、`Result[Unit, String]`。`List<Integer>` は正しくない。
- `with r = acquire() do ... end with` は、ブロックが終わるときに、そのリソースを逆の順に解放する。`TaskGroup.spawn(group: group, action: lambda() ... end lambda)` は、`TaskGroup.open()` で開いたタスクの集まりの中でタスクを起動し、`Task.await(task)` はその結果を待つ。タスクの集まりを解放すると、そのすべてのタスクを待つ。
- 利用者が定義する操作の値型のパラメータには、`function render[T: Trait.Show](value: T) -> String` のように制約を付けられる。呼び出し側が実装を選び、節は呼び出し側のどの型にもそのメソッドを使える。制約によって公開の引数が増えることはない。関数値、`_` の穴、`|>` も、直接の呼び出しと同じ公開のパラメータ名と評価順を使う。節内のラムダは制約を捕捉でき、入れ子の節はそれぞれの制約を保つ。操作は型構築子パラメータ、エフェクト変数、独自の uses を宣言できない。
- エフェクトの操作の一部だけを処理するハンドラは、型からそのエフェクトを取り除かない。型に `State` を持つ関数（`Reference`、`TaskGroup`、`Task.await`、`close...`）はハンドラで処理できない。
- マップと集合は、挿入の順ではなくキーの順に並ぶ。
- 数値のビット幅ごとに型が異なり、暗黙の変換はない。接尾辞のない `1` は常に `Integer` である。`Integer32` には `1s32`、`Float32` には `1.0f32` を使う。接尾辞（`s8`–`s64`、`u8`–`u64`、`f32`/`f64`）は暫定であり、構文の見直しで変わることがある。`Integer64` = `Integer`、`Float64` = `Float`、`UnsignedInteger8` = `Byte`、`UnsignedInteger` = `UnsignedInteger64` である。通常の名前には `Integer`、`Float`、`Byte` を使う。`Byte` に算術演算はなく、符号なしの型に単項の負号はない。
- 整数の算術演算は、桁あふれ（符号なし整数の減算で 0 より小さくなる場合を含む）と 0 による除算で止まる。数値の変換の失敗は `Option.None` を返す。モジュールごとのシグネチャを確かめる。`Float32` は各演算の後に丸める。`references/idioms.md` の数値の変換の例を参照する。
- 実験的な `@external("wasm", "path.wasm", "export")` の関数は、取り込みのないバイナリの Component Model のコンポーネントを使い、本体も `end function` も持たない。具体的なレコードとデータ型、引数のない構成子の `Set` で表すフラグ、WIT に対応するキーを持つ `Map` を境界越しに渡せる。外部のリソース型には `uses State` が必要であり、ほかの外部呼び出しは純粋である。生成したアダプタは、詰めて格納したバイト数を数え、それとは別に、同じ `--wasm-transfer` の値で値の構築量の論理的な上限を設ける。`references/idioms.md` の WIT の例と上限を参照する。
- 文字列補間は `"${expression}"` と書く。コメントは `//` で始まる。
- `null` も例外もループの文もない。`Option`、`try` を伴う `Result`、および `List.map`・`List.fold`・`List.forEach` か再帰を使う。
- prelude の外のモジュールは、`uses` にだけ現れるときも含めて、すべて取り込む。非公式のモジュール（IO とネットワークのすべてのモジュール、`Json`、`Csv` など）は `Benitoite.Unofficial` の下で取り込む: `import Benitoite.Unofficial.IO.Console` と書き、`Console` として参照する。`import Benitoite.IO.Console` は誤りである。非公式のモジュールは `IO.Console`、`IO.File`、`IO.Process`、`IO.Clock`、`IO.Random`、`Network.Http`、`Json`、`Json.Codec`、`Failure`、`Test.Property`、`Csv`、`Regex`、`Scope`、`Range`、`Path`、`Time`、`Encoding`、`Hash` である。たとえば `import Benitoite.Unofficial.Network.Http` は `Http` として参照する。エフェクトを宣言するモジュール（IO とネットワークのモジュール、`IO`、`Assert`）の名前を `as` で変えない。`uses` が常に本当のエフェクトの名前を示すように、名前を変えると誤りになる。
- エフェクトを直接または呼び出しを通して行う関数は、すべてそのエフェクトを `uses` の後に並べる。ネットワークのエフェクト（`Http.Connect`、`Http.Listen`）は `IO.All` に含まれない。
- 値が `Unit` でない文は誤りである。各 `Result` を、`try`、`match`、`bind _ <-` のどれかで処理する。
- `Process.shell` は、その文字列を `/bin/sh -c` で実行する。POSIX の sh だけを書く。bash の配列、`[[ ]]`、`{a,b}` の展開、`$'...'` は使わない。シェルの機能が要らないときは、引数の並びを渡す `Process.run` を使う。

完全なスクリプトの例:

```files
name: input.txt
one
two
three
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Result[Unit, String] uses File.Read, Console.Write
  bind lines <- try File.readLines("input.txt") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  List.forEach(xs: lines, f: lambda(value) Console.writeLine("${String.characterCount(value)} ${value}"))
  return match List.head(lines) with
    case Option.Some(first) -> Result.Ok(Console.writeLine("first: ${first}"))
    case Option.None -> Result.Error("input.txt is empty")
  end match
end function
```

```output
3 one
3 two
5 three
first: one
```

## 検査済みの値と局所の構築器

不透明型には公開の作成・検査関数を使う。構成子、更新、パターン、自動アクセサは所有モジュール内だけで使える（外では E0340）。Regex/Scope の直接呼び出しは、テスト内でも既知の不正な入力を拒否する。実行時 Error のテストには通常の関数の引数を経由させる。Range は定数にも実行時の Result.Error を保つ。Scope が保証するのは表記の所属であり、権限、DNS/ファイルの実体、IO の成功ではない。references/common-mistakes.md と、生成参照の Scope.md / Range.md を参照する。

Benitoite.StringBuilder、Benitoite.ListBuilder、Benitoite.BytesBuilder を明示的に取り込む。構築器は第二級の値である。対応する種類を注釈した局所 bind と直接の new() で宣言し、専用の操作だけを直接呼ぶ。copy/length を含む全操作に State を要する。通常の関数への引数渡し、返却、格納、比較、文字列への埋め込み、ラムダ・lazy・部分適用・ハンドラ節への捕捉はできない。コールバックを作る前に copy や length を束縛し、appendAll の前に断片列を作る。コピーは不変の構造を保つが、参照を持つ要素のセルは共有する。State の消去、clear/reserve/finish、ネイティブのバッファによる高速化の保証はない。シグネチャは生成参照の各 Builder モジュールを参照する。

## コレクションと連結の関数を選ぶ

コンテナが既知なら List.map/fold、Option.map/andThen、Result.map/andThen/mapError を使う。一つの関数を複数のコンテナで使う場合だけ、必要最小のクラス制約を要求する。一引数には Trait.Functor、Trait.Applicative、Trait.Monad、二引数には Trait.Functor2、Trait.Applicative2、Trait.Monad2 を使い、Benitoite.Trait を明示的に取り込む。二引数クラスは F[A, X] の X を保って写し、標準実装は Result である。一引数の Monad や Traversable に Result を渡せるようにはならない。

andThen/flatMap は成功値から同じエラー型の計算を続ける。異なるエラー型は Result.mapError でそろえる。try … or return は呼び出し側へ失敗を返し、or die は報告して実行を終え、Failure.toResult は型付き Failure.Fail[E] を Result に変換して、囲む効果上限から処理した Fail を除く。標準 Fail の E0506 には Benitoite.Unofficial.Failure を取り込み、main または @test 関数内で Failure.toResult を呼び、その入口の uses から処理した Fail を外してほかのエフェクトを保つ。利用者定義の Fail や Log は専用のハンドラを要する。表示・比較・結合は意味で選ぶ。数値の toString を機械的に Show へ、組み込みの Float 比較を Order[Float] へ置き換えない。[具体的なコンテナと汎用のコンテナ](references/idioms.md#具体的なコンテナと汎用のコンテナ)に検査済みの例がある。

## テスト

テストは、`@test("description")` を付け、引数を持たず、戻り値の型が `Unit` か `Result[Unit, String]` の関数である（テストが `try e or return` を使うときは後者にする）。`Assert.equal(actual: actual, expected: expected)` で確かめる。テストが外の世界に触れないように、`File.readText` や `Process.run` などの操作をハンドラで置き換える。ほかの例は `references/idioms.md` にある。型パラメータを持つ補助の関数の中の確かめは、呼び出し元の型を決められるときは、構成子の名前を復元する。決められないときは、型が不明のまま残ることがある。報告が `<constructor #n of an unknown type>`（n は 0 から数えた構成子の位置）を示すときは、確かめの中で具体的な型の値を比べると、構成子の名前が表示される。

```benitoite test
import Benitoite.Unofficial.IO.File

function firstLine(path: String) -> Result[String, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Option.okOr(o: List.head(String.lines(text)), error: "empty file")
end function

@test("firstLine returns the first line")
function firstLineWorks() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    firstLine("data.txt")
  with
    case File.readText(_) -> resume(Result.Ok("alpha\nbeta\n"))
  end handle
  Assert.equal(actual: result, expected: Result.Ok("alpha"))
end function
```

## 参照の文書

必要なときに次の文書を読む。

| 文書 | 読むとき |
|---|---|
| `references/idioms.md` | よくある作業（ファイル、JSON、CSV、外部のコマンド、引数、HTTP、コレクション、レコード、テスト、数値の変換、WASM/WIT の宣言）を書くとき。 |
| `references/inspection.md` | ハーネスを連携させるとき、または検査報告、ビルド情報、エフェクト上限、テストの集計、同梱 Skill の問い合わせを解釈するとき。 |
| `references/common-mistakes.md` | ほかの言語の習慣（`let`、波括弧、`==`、取り込みの漏れ）から診断が出たとき。 |
| `references/language-comparison.md` | Python、JavaScript、Rust での書き方は知っていて、Benitoite の形が必要なとき。 |
| `references/diagnostics.md` | 診断のコード（`E0201`、`W0501` など）の意味がわからないとき。 |
| `references/grammar.md` | 構文の正確な形が必要なとき。 |
| `references/stdlib/index.md` | 標準ライブラリのモジュールが必要なとき。すべてのモジュールを取り込みの名前とともに挙げている。 |

各モジュールには、`references/stdlib/List.md` や `references/stdlib/IO.Console.md` のように、`references/stdlib/<Module>.md` という名前のファイルがある。`references/stdlib/index.md` からのリンクを辿る。

（訳注）この訳のある参照の文書: [idioms.md](references/idioms.md)、[inspection.md](references/inspection.md)、[common-mistakes.md](references/common-mistakes.md)、[language-comparison.md](references/language-comparison.md)。生成の文書（[grammar.md](../../../crates/benitoite/skill/references/grammar.md)、[diagnostics.md](../../../crates/benitoite/skill/references/diagnostics.md)、[stdlib/index.md](../../../crates/benitoite/skill/references/stdlib/index.md)）は訳さないので、英語の原文を参照する。

純粋な JSON の変換には Benitoite.Unofficial.Json.Codec を取り込む。基本型とコンテナの関数は Result[..., Codec.ConversionError] を返す。Integer と Float の種類は厳密に区別し、有限でない Float は拒否する。List と Map は最初の添字かキーの失敗で止まる。ConversionError は、外側から内側へ Field/Index/Key の経路を持つ。Show は経路と種類を報告し、入力値を自動では表示しない。codec には Fail は不要である。アプリケーションの境界で Failure.fromResult を明示的に選ぶ。

純粋な性質の試行には Benitoite.Unofficial.Test.Property を取り込み、通常の @test 一つから `Property.check(config: ..., gen: ..., shrinker: ..., property: ...)` を呼ぶ。性質は Result[Unit, String] を返し、全コールバックは純粋である。実行時の停止と中断はそのまま伝播する。Error を照合し、Property.formatFailure(failure: ..., show: ...) をテストの String のエラーとして返す。show の型は function(value: T) -> String である。test --check はコールバックを実行しない。

Config は明示した seed と、両端を含む予算 trials 1〜10000、size 0〜10000、maxShrinks 0〜100000、maxShrinkWork 0〜1000000 を使う。五つのフィールドをすべて指定する。小さな例では maxShrinkWork: 10000 から始める。この推奨値は最終の性能測定で確認する。不正な設定はコールバックを呼ばない。Shrinker.candidates は List ではなく ShrinkStep（Done/Yield/Skip）を返す。全候補の List を先に作らず、遅延した継続を書く。最初の candidates と各継続は一単位の仕事、各候補への性質の呼び出しは一単位の仕事と一回の縮小に数える。どちらかの予算が零なら縮小器を呼ばない。失敗した候補からやり直しても両計数を累積する。予算を使い切った後は Done の確認だけのために継続を呼ばない。予算はコールバック内部の時間や確保を制限しない。

Integer の生成は両端を含み、Float の生成は有限値に限る。入れ子のコンテナの size は資源全体の上限ではない。縮小は循環も含め、全候補の試行を数え、最小の反例を約束しない。再現には config、libraryVersion（2.0.0）、生成コードの GENERATOR_VERSION、手書きのソース、元と縮小後の入力と説明を残す。同じ seed だけではライブラリの版をまたいで反例を再現できない。Gen/Shrinker のフィールドと各 API は、references/stdlib/Test.Property.md を参照する。

ソースのリポジトリには、レコードの codec、Gen/Shrinker 関数、明示的に要求した Show/Order 実装を生成する開発用の derive がある（tools/derive/README.md）。Show/Order の指定は独立した真偽値である。対象は循環せず型パラメータを持たないレコードに限り、各フィールドに対応する辞書を要する。Show は宣言順と各値の引用に従い、Order は最初の非 Equal で止まる。組み込みの等値、キー制約、直列化形式は提供しない。既存の手書き実装を保護する。不透明なレコードも所有モジュール内で Show/Order を明示的に要求できるが、適用前に表示の内容を確認する。宣言の inventory と生成記録は版 2、設定は版 1 である。古い記録は新しい preview を確認して移す。不透明型には手書きの検査済み作成関数を使い、不透明なフィールドには独自の codec/generator を指定する。配布した実行ファイルと Skill だけの環境では、Codec と Property の API を使って関数を直接書く。
