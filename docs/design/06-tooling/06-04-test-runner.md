# 利用者プログラムのテスト


## 目的と範囲

利用者がスクリプトに書くテストと、それを実行する `benitoite test` の振る舞いを定める。対象は、テストの書き方、期待の確認、組み込みの操作の差し替え、テストの実行と結果の報告、非実行の検査と契約の報告、実行前のエフェクト上限の照合、純粋な生成・縮小と性質の試行である。

## 前提

- 属性の構文は[構文](../01-spec/01-02-syntax.md)の「属性（初回リリース版）」で定める。
- エフェクトとハンドラは[エフェクト](../01-spec/01-07-effects.md)で定める。
- `test` のコマンドラインと終了状態は、[CLI](06-01-cli.md)の「`test` のコマンドライン（初回リリース版）」で定める。

## 仕様

関数一覧の表の `f(a, b)` は、関数とパラメータを示す記法である。実際のコードでは、複数の引数を取る通常の関数は宣言のパラメータ名を付けて名前付きで呼ぶ。

### テストの関数

【決定】テストは、`@test` を付けたトップレベルの関数である。

```text
function add(a: Integer, b: Integer) -> Integer
  return a + b
end function

@test("add sums two numbers")
function addSumsTwoNumbers() -> Unit uses Assert.Check
  Assert.equal(actual: add(a: 2, b: 3), expected: 5)
  Assert.equal(actual: add(a: -1, b: 1), expected: 0)
end function
```

【方針】テストの関数の規則は次のとおりである。

- 型パラメータと引数を持たない。戻り値の型は `Unit` か `Result[Unit, String]` である。`Result[Unit, String]` のテストは、`Result.Error(message)` を返すと失敗する。`try` を使うテストは、この形にする。
- エフェクトは、組み込みのエフェクト（[エフェクト](../01-spec/01-07-effects.md)）と `Assert.Check` の任意の集まりである。利用者が定義するエフェクトと `Failure.Fail[E]` は、テストの関数の中で処理しなければならない。未処理の Fail は非実行の検査でも E0506 として拒否し、検査報告の `expanded` と実行前の許可名には加えない。
- `@test("説明")` の説明は、結果の報告でテストの名前として示す。説明を省いた `@test` では、関数の名前を示す。
- テストの関数は、どのモジュールにも書ける。同じモジュールの非公開の関数も呼べる。ほかの関数から、テストの関数を普通の関数として呼んでもよい。
- `run` はテストの関数を実行しない。テストの関数も、`check` と `run` の型検査の対象である。

上の規則に合わない関数に `@test` を付けると、型検査の誤りとする。

### 期待の確認

【決定】期待の確認は、prelude のモジュール `Assert` が宣言するエフェクト `Assert.Check` の操作で行う。操作は `Assert` のモジュールの関数であり、import なしに使える。`Assert.Check` は `IO.All` に含めない。`main` のエフェクトには `Assert.Check` を含められない（[エフェクト](../01-spec/01-07-effects.md)の「プログラムの入口」）。

| 操作 | 型 | 失敗する条件 |
|---|---|---|
| `Assert.equal(actual, expected)` | `function[T: equality](actual: T, expected: T) -> Unit uses Assert.Check` | `actual = expected` が `false` |
| `Assert.notEqual(actual, expected)` | `function[T: equality](actual: T, expected: T) -> Unit uses Assert.Check` | `actual = expected` が `true` |
| `Assert.isTrue(condition, message)` | `function(condition: Boolean, message: String) -> Unit uses Assert.Check` | `condition` が `false` |
| `Assert.fail(message)` | `function[T](message: String) -> T uses Assert.Check` | 常に失敗する |

- 確認が失敗すると、そのテストは失敗として終わる。以後の文は評価しない。テストの中で開いていた `with` のリソースは、内側のスコープから順に解放する（[エフェクト](../01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。
- 補助の関数の中でも確認できる。補助の関数は `uses Assert.Check` を持つ。
- `Assert.Check` の操作は、テストの実行器がハンドラとして処理する。利用者のハンドラで `Assert.Check` を処理してもよい（テストの補助の関数のテストなど）。

### 組み込みの操作の差し替え

【方針】テストでは、組み込みの操作をハンドラで差し替える。次の例は、ファイルを読む関数と外部コマンドを起動する関数を、実際のファイルとコマンドを使わずに確かめる。`Process.run` と `Process.command` は[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」で定める。ファイルとプロセスの関数は `Benitoite.IO` の下のモジュールにあるので、テストのファイルでも import する。

```text
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function readPort(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Integer.parse(String.trim(text)) |> Option.okOr(o: _, error: "not a number")
end function

@test("readPort reads the number in the file")
function readPortReadsNumber() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    readPort("app.conf")
  with
    case File.readText(path) ->
      Assert.equal(actual: path, expected: "app.conf")
      resume(Result.Ok("8080\n"))
  end handle
  Assert.equal(actual: result, expected: Result.Ok(8080))
end function

function tagRelease(tag: String) -> Result[Unit, String] uses Process.Run
  bind output <- try Process.run(Process.command(program: "git", arguments: ["tag", tag])) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return if Process.Output.exitCode(output) = 0 then Result.Ok(()) else Result.Error(Process.Output.standardError(output)) end if
end function

@test
function tagReleaseRunsGit() -> Unit uses Assert.Check, State, Process.Run
  bind calls <- Reference.new([])
  bind result <- handle
    tagRelease("v1.0")
  with
    case Process.run(command) ->
      Reference.set(reference: calls, value: List.append(xs: Reference.get(calls), x: Process.Command.arguments(command)))
      resume(Result.Ok(Process.Output(exitCode: 0, standardOutput: "", standardError: "")))
  end handle
  Assert.equal(actual: result, expected: Result.Ok(()))
  Assert.equal(actual: Reference.get(calls), expected: [["tag", "v1.0"]])
end function
```

`readPortReadsNumber` の `handle` は、`File.Read` の操作のうち `File.readText` だけを処理する。一部の操作だけを処理したエフェクトは型から除かない（[型システム](../01-spec/01-06-type-system.md)の「エフェクトの宣言とハンドラの型付け（初回リリース版）」）ので、この関数の `uses` には `File.Read` が要る。`tagReleaseRunsGit` の `Process.Run` も同じである。どちらのテストも、実際にはファイルを読まず、コマンドを起動しない。

### 表形式のテスト

【方針】表形式のテストのための専用の構文は設けない。入力と期待する値の組をリストにし、テストの中で順に確かめる。

```text
@test("add handles several cases")
function addCases() -> Unit uses Assert.Check
  List.forEach(xs: [Triple(1, 2, 3), Triple(0, 0, 0), Triple(-1, 1, 0)], f: lambda(value)
    Assert.equal(actual: add(a: Triple.first(value), b: Triple.second(value)), expected: Triple.third(value))
  end lambda)
end function
```

最初に失敗した組でテストは終わる。失敗の報告に示す呼び出しの履歴から、どの組で失敗したかを辿れる。

### テストの実行

【決定】`benitoite test <パス>...` は、指定したファイルを検査し、それぞれのファイルに書いたテストの関数を実行する。ディレクトリを指定したときは、その下のすべての `.bnt` のファイルを指定したものとし、各ファイルの根のディレクトリは、指定したディレクトリとする。走査では `package.bnt` に完全に一致する名前のファイルを除き、指定したディレクトリより下で直下に `package.bnt` を持つディレクトリには入らない。パッケージのテストは、そのパッケージの根を指定して実行する。上限を指定しない場合、検査の誤りがあるファイルは、テストを実行せずに `check` と同じく誤りを報告し、ほかのファイルのテストは続けて実行する。

【方針】指定したファイルが取り込むモジュールのテストの関数は、そのモジュールのファイルを指定しない限り実行しない。

【決定】通常の `test`、`test --check`、公開の `test_entries` は、内部の同じ探索処理を一度呼んで入口を選ぶ。パスの指定順と明示した重複を保ち、ディレクトリ内のファイルはパスの辞書順に並べる。直接指定したファイルの根は、そのファイルの親ディレクトリとする。ディレクトリの走査ではシンボリックリンクを辿らず、入口にも加えない。

【決定】内部の探索結果は、指定番号を持つ選択済みの入口一覧と、探索全体の完了または失敗（指定番号、パスと IO の理由）を持つ。失敗時に残すのは、それより前の指定パスについて選び終えた入口であり、走査に失敗したディレクトリ内の部分一覧は返さない。通常の実行と非実行の検査は、探索失敗を E0101 で報告して終了状態 2 で終え、どの入口の検査も実行も始めない。公開の `test_entries` は部分一覧を捨て、従来の `Err((path, error))` を返す。理由: 探索が途中で終わったことを、対象が少なかった成功と取り違えないためである。

【決定】検査成功後のテストの収集では、入口の AST と各テストの束縛・型が存在することを確認する。欠けていれば処理系の不具合として報告し、終了状態 3 で終える。対象を黙って除外したり、欠けた型を戻り値の種類で補ったりしない。理由: 検査済みの情報が欠けた状態で実行を続けると、未実行のテストを残したまま成功を報告するおそれがあるためである。

【決定】テストは、一つずつ別の実行として動かす。コンパイル済みプログラムは実行の間で共有し、実行ごとの状態（ヒープ、タスク、リソース）は実行ごとに持つ（[ランタイム](../02-impl/02-09-runtime.md)）。

【決定】実行器は、ファイルごとの検査・コンパイル・実行の入力の作成・全テストの原型の確認を準備としてまとめ、その成果物を同じファイルの全テストで使う。入力を作れない場合やテストの原型が欠けている場合は、処理系の不具合として終了状態 3 で終え、そのファイルのテストを一つも始めない。ソースを開き直さず、上限を指定しない場合は、現在のファイルのテストを終えてから次のファイルを準備する。準備と実行の間で保持する状態は、[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)の「テストの実行」で定める。

【決定】`--allow-effects` を指定した実行では、全入口の準備を実行より先に済ませる。各入口の型検査後、`collect_tests` が集めた各テストの束縛・名前・位置から宣言上限を取り出し、[CLI](06-01-cli.md#実行前のエフェクト上限の照合)と同じ ID による包含を判定する。不足した関数には入口順・宣言順に E0512 を一件ずつ出し、その入口のコンパイルは行わない。検査失敗・不足・コンパイル制限があっても後の入口の準備を続ける。不具合と中断は準備を止める。全入口が成功した場合だけ、保持した成果物を入口順に消費し、各テストを従来どおり別の実行として動かす。理由: 後の入口の拒否が分かる前に、先のテストが外部への書き込みなどを行うことを防ぐためである。

【決定】探索完了後、実行開始前に全体を拒否した場合は、テストの結果行を作らない。集計の成功数・失敗数は0、実行しなかった入口数は、誤りのない入口・テストのない入口・明示パスの重複を含む全入口数とする。通常の拒否は終了状態2、不具合は3、中断は `interrupted=true`・130で終える。件数が u32 に収まらない場合は内部エラーとし、飽和させた件数を報告しない。探索失敗、使い方の誤り、対象数を確定できない外側の不具合では集計を出さない。理由: 誤りのない入口も全体の拒否で開始しなかったためであり、誤りのある入口だけを数えると非実行数を過少に報告するためである。

- 一つのテストで実行時エラーが起きても、そのテストが失敗するだけであり、ほかのテストは続ける。実行時エラーそのものは、スクリプトからは捕捉できない。
- テストは、ほかのテストの実行の順序と、実行したかどうかに依存してはならない。処理系は、テストを並行に動かしてよい。
- 実行器は、実際に行う IO の許可を調べない。初回リリース版は実行時の権限制御を持たない（[エフェクト](../01-spec/01-07-effects.md)）。
- テストの関数の中で標準出力と標準エラー出力に書いた内容は、実行器が受け取る。そのテストが失敗したときに、報告に加えて示す。標準入力は空の入力につなぐ。
- 実行器はファイルの `main` を呼ばない。テストのファイルに `main` はなくてよい。テストの中の `Process.arguments` は空のリストを返す。
- テストの中で `Process.exit` を呼ぶと、そのテストだけを終え、失敗として報告する。
- 実行器が中断の要求（`SIGINT` など）を受けたら、実行中のテストを取り消してリソースを解放し、それまでの結果を報告して、終了状態 130 で終わる。テストの関数が値で終わった後に中断の印を見つけた場合も、そのテストの結果を報告せず、数にも入れずに中断として終える（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)の「テストの実行」）。

### テストの非実行の検査

【決定】`test --check <パス>...` は、通常の `test` と同じ探索で入口を選び、各入口を読み込みから型検査後の外部宣言の静的な照合まで検査する。`main` を要求せず、テストのないファイルと空ディレクトリも受け付ける。通常の検査の誤りがあっても、ほかの入口の検査を続ける。処理系の不具合があればそこで終える。

【決定】非実行の検査では、確認の表（`AssertTable`）の構築、脱糖、コンパイル、VM と `RuntimeParts` の生成、利用者コードと外部関数の実行を行わない。型検査の既存の定数の計算と外部宣言の静的な確認は行う。理由: 実行前に型とエフェクトの規則への適合を確認するための操作である。コンパイルの制限まで通ることや、通常の `test` で実行できることは保証しない。

【決定】報告を指定しなければ標準出力は成功時も空とし、テストごとの結果と集計を書かない。警告と誤りは、`--diagnostics` で指定した既存の形式で標準エラー出力に書く。警告だけなら終了状態 0、検査の誤りか `--deny-warnings` による拒否なら 2、処理系の不具合なら 3 とする。探索に失敗した場合は検査を始めず、診断を書いて 2 とする。

【決定】中断は入口を始める前にだけ確認し、そこで要求を観測すれば、結果と集計を出さずに終了状態 130 で終える。入口の後や終了直前には読み取りを加えない。最後の入口の検査中の要求は反映できない場合があり、型検査を即時に停止する保証はしない。

【決定】`--report=json` を付けた非実行の検査は、同じ `collect_tests` の一覧と型検査済みの宣言上限を束縛で照合し、単一の `testCheckReport` を返す。取り込んだモジュールのテストを入口の一覧に加えない。成功したテストなしの入口は空配列、検査に失敗した入口は未確定の null とし、検査失敗後の成功も保持する。`Assert.Check` を含む契約、説明、位置、ソースの識別値、診断の対応と部分結果の形式は [CLI](06-01-cli.md#テストの非実行の検査報告)で定める。診断は報告内だけに置き、テストの結果と集計は出さない。

【決定】同じ表示パスのファイルを直接指定とディレクトリ経由で選んだ場合も、入口とその根をそれぞれ保持する。明示した重複を報告で統合しない。走査ではリンクを除外するが、直接指定したファイルやディレクトリのリンクは辿る。理由: 報告する入口と、通常の `test` が検査・実行する入口との対応を保つためである。

【決定】`Assert.Check` は各テストの宣言上限と全体の和の両方に含める。確認画面向けに処理系で省略しない。対応する報告形式は、`--version=json` の `formats.testCheckReport: [1]` で問い合わせられる。

### 結果の報告

【方針】実行器は、テストごとに、名前と結果（成功、失敗）を報告する。失敗したテストについては、次のものを示す。

| 失敗の理由 | 示すもの |
|---|---|
| `Assert` の確認の失敗 | 失敗した確認の位置と呼び出しの履歴。`Assert.equal` と `Assert.notEqual` では両方の値、`Assert.isTrue` と `Assert.fail` では文字列 |
| `Result.Error(message)` を返した | `message` |
| 実行時エラー | 実行時エラーの報告と同じ内容（種類、位置、呼び出しの履歴。[診断エンジン](../02-impl/02-10-diagnostics.md)） |

- 値は、処理系が人間の読める形に書き出す。代数的データ型は構成子と引数を、レコードはフィールドの名前と値を、リスト・マップ・集合は要素を示す。この表記は言語から呼べる関数ではない。
- 【方針】型パラメータを持つ補助の関数の本体に直接ある確認では、比べる値の型を直接の呼び出し元から求める。具体的な型を書いた呼び出し元からなら、末尾呼び出しでも型を求められる。ラムダの本体・`handle` の本体と節の中の確認では、定義元の起動を枠から決めず、使用箇所の候補を使う。実装のメソッドの中の確認では、呼び出し元から型を求めない。

  型パラメータを持つ関数が末尾呼び出しで別の関数を呼んだ場合は、呼び出し元の型引数が枠から分からない。この場合や、関数を値として渡した場合などは、全使用箇所の型引数を展開でき、しかも比べる二つの値の形から型が一つに決まるときだけ、その型を使う。

  実装のメソッドの中の型パラメータを含む使用などで候補が欠ける場合や、自分を呼ぶ型パラメータの補助の関数で探索が循環する場合には、型が決まらないことがある。

  一つに決まらない位置では、構成子を `<constructor #n of an unknown type>` と書く。`n` は型の宣言の中の構成子の位置（0 から数える）である。比べる値の型を具体的な型にした確認では、構成子を名前で書く。理由: 値の形が同じ型どうしを実行時に区別する型の情報は値に含まれないため、決まらない型の名前を推測して報告しない。
- 【決定】一つの値の書き出しは 4 KiB（4,096 バイト）以下とする。超えるときは、4,093 バイト以下の最後の文字の境界で切り、末尾に `…`（U+2026）を置いて省いたことを示す。`…` を含めて 4,096 バイト以下とする。超過が分かった時点で、値の残りを辿るのをやめる。理由: 共有した構造を持つ値は、値の大きさに対して書き出しが指数的に長くなりうるので、報告の大きさと書き出しの時間を抑えるためである。
- 最後に、成功と失敗の数を示す。すべてのテストが成功すれば成功を、一つでも失敗すれば失敗を表す終了状態で終わる。終了状態の値は [CLI](06-01-cli.md) で定める。

【決定】通常の実行では、テストごとの結果と、最後の数の集計を標準出力に書く。非実行の検査の出力は前節に従う。検査の誤りの診断と処理系の不具合の報告は、`check` と `run` と同じく標準エラー出力に書く。`--diagnostics=json` を指定したときは、結果も JSON Lines の形で書き、テストごとに一行を、最後に集計の一行を書く。テストの結果は、`test` の成果であるため標準出力に置く。

【決定】報告の形は次のとおりとする。

- 文章の形は、Rust の `cargo test` の形に合わせる。テストごとに `test <ファイル>: <名前> ... ok` か `... FAILED` の一行を書く。名前は、`@test` の説明があれば引用符で囲んだ説明、なければ関数の名前とする。
- 失敗したテストがあれば、すべてのテストの行の後に `failures:` の見出しを書き、失敗したテストごとに `---- <ファイル>: <名前> ----` の見出しと、上の表の失敗の詳細を書く。位置と呼び出しの履歴は、[診断エンジン](../02-impl/02-10-diagnostics.md)の文章の形式と同じ形で書く。テストの関数が起動したタスクの中で失敗したときは、タスクの起動の履歴の最後の段を、`main` ではなくテストの関数の名前にする。タスクの待ち合いの行き詰まりの報告で待つタスクを並べるときも、最初のタスクをテストの関数の名前で示す（テストでは最初のタスクがテストの関数であるため）。テストが書いた出力があれば、`---- captured stdout ----`・`---- captured stderr ----` の見出しに続けて示す。
- 集計を書く場合は、最後に `test result: ok.` か `test result: FAILED.` に続けて、成功の数と失敗の数を書く。実行しなかった入口があれば `; {count} files not run` を加え、中断で終えたときは `; interrupted` を加える。失敗数・非実行数がともに0で、中断もない場合だけ `ok` とする。通常の上限なしの実行にも同じ文言を用いる。
- 文章の形のテストの行と失敗の見出しでは、`<ファイル>` に含まれる端末の制御文字を、診断のファイルの表示名と同じく逃がして書く（[診断エンジン](../02-impl/02-10-diagnostics.md)の「文章の形式」）。JSON Lines の形の `file` には、元のパスをそのまま書く。
- テストを並行に動かしても、報告は、ファイルを指定した順（ディレクトリの下ではパスの辞書順）と、ファイルの中のテストの関数の宣言の順に書く。報告を実行ごとに変えないためである。

```text
test tests/sum.bnt: "adds two numbers" ... ok
test tests/sum.bnt: sumOfEmpty ... FAILED

failures:

---- tests/sum.bnt: sumOfEmpty ----
assertion failed: Assert.equal
  left:  3
  right: 4
  --> tests/sum.bnt:14:3
   = note: call trace (innermost first):
             sumOfEmpty
   = note: functions left by tail calls are not shown

test result: FAILED. 12 passed; 1 failed
```

- JSON Lines の形では、テストごとに `kind` が `"test"` の一行を書く。項目は、`file`、`name`（説明か関数の名前）、`function`（関数の名前）、`location`（関数の宣言の位置。診断の位置の形）、`outcome`（`"passed"` か `"failed"`）、`failure`（成功では `null`）、`stdout`・`stderr`（捕らえた内容の文字列）である。
- `failure` は、`reason`（`"assert"`・`"error"`・`"runtime"`・`"exit"`）と `message` のほかに、理由に応じた項目を持つ。`"assert"` は失敗した確認の位置 `primary` と `trace`、`Assert.equal`・`Assert.notEqual` では値を書き出した文字列 `left`・`right` を持つ。`left`・`right` は文章の形と同じ文字列で、上記の 4 KiB の上限と省略の規則に従う。`"error"` は `Result.Error` の文字列を `message` に持つ。`"runtime"` は、実行時エラーの報告の JSON の形式の項目（`code`・`primary`・`trace`・`traceOmitted`・`taskOrigins` など）を持つ。`"exit"` は `Process.exit` の終了状態 `exitCode` を持つ。
- `"assert"` と `"exit"` は、`"runtime"` と同じく注記の文字列の配列 `notes` も持つ。`"assert"` の `notes` は、実行時エラーの報告の `notes` と同じ並びで、止める途中の解放の失敗ごとの注記（[診断エンジン](../02-impl/02-10-diagnostics.md)の「解放の失敗の報告」の、実行時エラーで止める途中の解放の注記と同じ文）を並べ、最後に末尾呼び出しの注記を置く。`"exit"` の `notes` は、止める途中の解放の失敗ごとに同じ文を一つずつ並べ、失敗がなければ空の配列とする。
- 内部の `Failure::Exit` は明示的な失敗終了の原因・任意の説明・位置も保持できる。die の文章では通常の「called `Process.exit` with status 1」の行を省き、補足の報告の前に [CLI](06-01-cli.md) の「終了状態」と同じ失敗終了の報告を一度だけ描画する。JSON は `reason: "exit"` と `exitCode`・`notes` を保ち、情報がある場合だけ `die` に `kind: "die"` の診断オブジェクトを加える。捕らえた `stdout`・`stderr` へこの報告を書き足さない。通常の exit は従来の形式を保ち、終了状態 0 でもテストの失敗である。ソースの `or die` も一件の失敗として記録し、次のテストを実行する。
- 集計を書く場合は、最後に `kind` が `"testSummary"` の一行を書く。項目は、`passed`、`failed`、`filesNotRun`（検査の誤りなどで実行しなかった入口数。上限付きの全体拒否では全入口数）、`interrupted`（中断の要求で終えたか）である。

【決定】成功した空のディレクトリと、成功したテストのない入口は、終了状態0、成功数・失敗数・非実行数0、`interrupted:false` の集計を返す。受け手は成功数と失敗数だけで成功を決めず、終了状態・非実行数・中断・集計行の有無を確認する。成功数・失敗数・非実行数は u32 の範囲を検査し、超えれば内部エラーとする。

### プロパティベーステスト

【決定】非公式の `Benitoite.Test.Property` は、純粋な生成・縮小・性質の試行を通常の標準ソースで提供する。`import Benitoite.Unofficial.Test.Property` で取り込む。専用の属性や CLI の seed 指定は設けず、通常の `@test` 一件から `Property.check` の結果を返す。`test --check` は型とエフェクトの検査だけを行い、生成器・縮小器・性質を実行しない。

`Gen[T]` は `run: function(generator: Random.Generator, size: Integer) -> Pair[T, Random.Generator]`、`Shrinker[T]` は `candidates: function(value: T) -> List[T]` を持つ公開レコードである。`Random` は `Benitoite.Unofficial.IO.Random` を指す。

`Config` の欄は `seed`・`trials`・`size`・`maxShrinks`（すべて Integer）であり、seed は全域、trials は1〜10000、size は0〜10000、maxShrinks は0〜100000を許す。`check[T](config, gen, shrinker, property)` の property の型は `function(value: T) -> Result[Unit, String]`、結果は `Result[Unit, CheckFailure[T]]` である。誤設定ならコールバックを一度も呼ばず `CheckFailure.InvalidConfig(String)` を返す。有効な設定では、返された Generator を次へ渡し、全試行へ同じ size を渡す。Gen.run の直接の呼び出しを丸める機構はなく、size の解釈は保持した関数の契約に従う。

【決定】基本の生成器は `constant[T](value)`・`map[A,B](gen, f)`・`both[A,B](left, right)`・`integer(low, high)`・`boolean()`・`float()`・`string()`・`list[T](element)`・`option[T](element)`・`stringMap[T](value)` とする。integer だけは `Result[Gen[Integer], String]`、ほかは対応する Gen を返す。map の f は `function(value: A) -> B` とする。map は逆写像や縮小器を推測しない。both は左から右へ乱数状態を渡し、同じ size を使う。

integer は両端を含み、low > high なら Error、low = high なら乱数を進めない。low < high では、まず `nextInteger(0, 8)` の枝番号を引く。0なら範囲内の0（範囲外ならlow）、1ならlow、2ならhighを返す。3〜7では次の `nextInteger(0, 2)` が0ならhigh、1ならさらに `nextInteger(low, high)` の半開区間から引く。各抽選で次の状態を渡す。high+1 や high-low を計算せず整数全域に対応する。値の重複分の確率は加算し、一様な分布は保証しない。

boolean は0/1の抽選、float は0・1・-1・nextFloat由来の[-1,1)を各1/4の枝で選び、有限値だけを返す。string は0以上0x10F800未満の番号を引き、0xD800以上へ0x800を加えて有効な Unicode スカラー値へ写す。

string・list・stringMap は0〜sizeの長さ・要素数・抽選回数を使う。組み込みのこれらの run を直接呼ぶときも size は0〜10000とする。入れ子には同じ size を渡し、全体の要素数の絶対上限とはしない。stringMap は鍵・値の順に毎回生成し、重複鍵では最初の値を残す。空きを埋める再抽選はしない。option は None を1/4、Someを3/4で選ぶ。乱数方式そのものは [Random](../03-interop/03-07-io-modules.md#random) の契約に従う。

【決定】縮小器は `shrinkInteger()`・`shrinkBoolean()`・`shrinkFloat()`・`shrinkString()` と、要素の Shrinker を受ける `shrinkList[T: equality](element)`・`shrinkOption[T: equality](element)`・`shrinkStringMap[T: equality](value)` とする。整数は0・元の値を0へ向けて繰り返し二分した値、Floatは0・半分の有限値、Booleanはtrueからfalseを候補にする。整数の最小値を符号反転せず、Floatの非有限値には0だけを候補にする。String/Listは空・連続する部分の削除・一要素ずつの縮小の順とし、削除幅は長さの半分から1へ二分し、同じ幅では先頭から順に位置を動かす。Stringはバイトでなくスカラー値を扱う。Mapは鍵順の一鍵ずつの削除・値の縮小、OptionはNone・中身の縮小の順とする。組み込みは元の値と等しい候補と既出の候補を除く。一般の Gen・Shrinker・check は等値制約を要求しない。

組み込みの List・String・Map の縮小は、候補の生成と重複除去に元の長さの二乗を超える費用がかかる場合があるため、size は小さく保つ。maxShrinks は候補を試す回数を制限するが、候補列の生成の費用は制限しない。

【決定】最初の性質の Error を見つけたら、現在値の候補を順に試す。Okなら次へ進み、Errorならその候補と説明を採用し、候補列の先頭から再開する。候補の試行のたびに総数を増やし、maxShrinksに達したら止める。0なら縮小器を呼ばず、上限到達を記録する。手書きの縮小器が同じ値や循環を返しても試行の予算を使う。コールバック自体の停止性や資源量の絶対上限は保証しない。実行時エラーと中断は通常の停止として伝わり、IO・Assert・exitを行う関数は純粋なコールバックの型に適合しない。

失敗は `CheckFailure.Falsified(Counterexample[T])` で返す。Counterexampleの欄はconfig・1起算のtrial・original・reduced・originalMessage・message・shrinks・limitReached・libraryVersionである。入力と対応する失敗の説明を保ち、reducedの最小性は保証しない。ライブラリの生成・縮小規則の版は `1.0.0` とする。

`formatFailure[T](failure, show)` は `function(value: T) -> String` を受け、設定と版、元と縮小後の入力・説明、候補試行数と上限到達を文字列にする。通常の@testではこれをResult.Errorで一度返す。Assertへ接続する場合も試行の最後に一度だけ使う。

同じseed・config・生成と縮小の規則の版・性質・手書きの関数なら同じ順に試行する。表示関数が入力の情報を省けば、報告からの完全な復元は保証しない。長期の再現には具体的な入力を通常の固定例として残す。Random.fromSeedの版をまたぐ契約を、Propertyの規則の版をまたぐ保証へ広げない。

開発用の宣言収集 example は型の構造を読むが、本体を検査しない。その成功は `test --check` の成功ではなく、テストの列挙・実行にもならない（[外部生成の宣言情報](../03-interop/03-06-stdlib.md#外部生成の宣言情報)）。外部生成の道具は、型パラメータのない非循環レコードからゼロ引数の `genPerson() -> Property.Gen[Person]`・`shrinkPerson() -> Property.Shrinker[Person]` の形の通常の関数を生成する。関数の可視性は型に合わせる。

【決定】自動生成では String・Boolean・Integer 全域・有限 Float・List・String 鍵の Map・Option と、別の Property target に指定した非循環レコードを扱う。生成は宣言順に乱数状態を渡し、同じ size を各欄に使う。縮小は一欄だけを変えた候補を宣言順に連結する。欄ごとのカスタム関数は、純粋かつ単相なゼロ引数の `Gen[欄の型]`・`Shrinker[欄の型]` を返す対として指定し、シグネチャを生成前に照合する。レコード全体の欄間の条件は型の構造から保証せず、必要な場合は型全体の生成器・縮小器を手書きする。

Property 単独の入れ子 Option は区別を保つ。JSON と併用する場合は JSON の対応範囲も満たす必要がある。別モジュールのレコードは公開型とそのモジュールの公開の生成関数を使い、再帰型・型パラメータ・Show/Order の導出は扱わない。手順と設定は [生成道具](../../../tools/derive/README.md#property-generation-contracts) に定める。生成道具の版と設定ハッシュは生成記録に保存し、反例を報告するときはその記録を添える。同じ型の構造・設定・版・手書きの関数と性質を再現の条件に含める。

外部生成の自己検査は、管理領域の編集と照合に加え、生成した JSON 変換・生成器・縮小器を通常の check・test に渡す（[外部生成の管理と照合](../03-interop/03-06-stdlib.md#外部生成の管理と照合)）。生成領域を使う場合は道具の check で記録との一致も確かめる。通常のテスト実行器は生成記録を読まない。
