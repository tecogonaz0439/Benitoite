# 利用者プログラムのテスト

- 状態: 確定
- 関連ADR: [0015](../decisions/0015-shared-program-per-execution-state.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0119](../decisions/0119-attributes-test-and-deprecated.md), [0120](../decisions/0120-test-functions-and-assert-effect.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0204](../decisions/0204-standalone-runs-in-sandboxed-child.md), [0206](../decisions/0206-test-command-line-and-exit-status.md), [0208](../decisions/0208-test-report-destination.md), [0252](../decisions/0252-test-report-format.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0257](../decisions/0257-match-with-case-arms.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-046](../open-issues.md#open-046), [OPEN-052](../open-issues.md#open-052)
- 移行元: [設計メモ](../sources/fp-language-design.md) 24

## 目的と範囲

テストの実行器、プロパティベーステスト、DI の書き方。ADT の構造からジェネレータを合成する derive 機構を採用する場合、導出規則とコード生成をどの章が担当するかを決め、この章では利用方法を扱う。

現在の版は、初回リリース版の範囲を定める。対象は、テストの書き方、期待の確認、組み込みの操作の差し替え、テストの実行と結果の報告である。プロパティベーステストは [OPEN-046](../open-issues.md#open-046) で検討する。

## 前提

- 属性の構文は[構文](../01-spec/01-02-syntax.md)の「属性（初回リリース版）」で定める。
- エフェクトとハンドラは[エフェクト](../01-spec/01-07-effects.md)で、実行時の権限制御も同章で定める。
- `test` のコマンドラインと終了状態は、[CLI](06-01-cli.md)の「`test` のコマンドライン（初回リリース版）」で定める。

## 仕様

### テストの関数

【決定】テストは、`@test` を付けたトップレベルの関数である（[ADR 0120](../decisions/0120-test-functions-and-assert-effect.md)）。

```text
function add(a: Integer, b: Integer) -> Integer
  return a + b
end function

@test("add sums two numbers")
function addSumsTwoNumbers() -> Unit uses Assert.Check
  Assert.equal(add(2, 3), 5)
  Assert.equal(add(-1, 1), 0)
end function
```

【方針】テストの関数の規則は次のとおりである。

- 型パラメータと引数を持たない。戻り値の型は `Unit` か `Result[Unit, String]` である。`Result[Unit, String]` のテストは、`Result.Error(message)` を返すと失敗する。`try` を使うテストは、この形にする。
- エフェクトは、組み込みのエフェクト（[エフェクト](../01-spec/01-07-effects.md)）と `Assert.Check` の任意の集まりである。利用者が定義するエフェクトは、テストの関数の中で処理しなければならない。
- `@test("説明")` の説明は、結果の報告でテストの名前として示す。説明を省いた `@test` では、関数の名前を示す。
- テストの関数は、どのモジュールにも書ける。同じモジュールの非公開の関数も呼べる。ほかの関数から、テストの関数を普通の関数として呼んでもよい。
- `run` はテストの関数を実行しない。テストの関数も、`check` と `run` の型検査の対象である。

上の規則に合わない関数に `@test` を付けると、型検査の誤りとする。

### 期待の確認

【決定】期待の確認は、prelude のモジュール `Assert` が宣言するエフェクト `Assert.Check` の操作で行う（[ADR 0120](../decisions/0120-test-functions-and-assert-effect.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。操作は `Assert` のモジュールの関数であり、import なしに使える。`Assert.Check` は `IO.All` に含めない。`main` のエフェクトには `Assert.Check` を含められない（[エフェクト](../01-spec/01-07-effects.md)の「プログラムの入口」）。

| 操作 | 型 | 失敗する条件 |
|---|---|---|
| `Assert.equal(actual, expected)` | `function[T: equality](T, T) -> Unit uses Assert.Check` | `actual = expected` が `false` |
| `Assert.notEqual(actual, expected)` | `function[T: equality](T, T) -> Unit uses Assert.Check` | `actual = expected` が `true` |
| `Assert.isTrue(condition, message)` | `function(Boolean, String) -> Unit uses Assert.Check` | `condition` が `false` |
| `Assert.fail(message)` | `function[T](String) -> T uses Assert.Check` | 常に失敗する |

- 確認が失敗すると、そのテストは失敗として終わる。以後の文は評価しない。テストの中で開いていた `with` のリソースは、内側のスコープから順に解放する（[エフェクト](../01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。
- 補助の関数の中でも確認できる。補助の関数は `uses Assert.Check` を持つ。
- `Assert.Check` の操作は、テストの実行器がハンドラとして処理する。利用者のハンドラで `Assert.Check` を処理してもよい（テストの補助の関数のテストなど）。

### 組み込みの操作の差し替え

【方針】テストでは、組み込みの操作をハンドラで差し替える（[ADR 0117](../decisions/0117-capabilities-as-effects.md)、[ADR 0118](../decisions/0118-effect-handlers.md)）。次の例は、ファイルを読む関数と外部コマンドを起動する関数を、実際のファイルとコマンドを使わずに確かめる。`Process.run` と `Process.command` は[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」で定める。ファイルとプロセスの関数は `Benitoite.IO` の下のモジュールにあるので、テストのファイルでも import する。

```text
import Benitoite.IO.File
import Benitoite.IO.Process

function readPort(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Integer.parse(String.trim(text)) |> Option.okOr(_, "not a number")
end function

@test("readPort reads the number in the file")
function readPortReadsNumber() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    readPort("app.conf")
  with
    case File.readText(path) ->
      Assert.equal(path, "app.conf")
      resume(Result.Ok("8080\n"))
  end handle
  Assert.equal(result, Result.Ok(8080))
end function

function tagRelease(tag: String) -> Result[Unit, String] uses Process.Run
  bind output <- try Process.run(Process.command("git", ["tag", tag])) |> Result.mapError(_, IOError.message)
  return if Process.Output.exitCode(output) = 0 then Result.Ok(()) else Result.Error(Process.Output.standardError(output)) end if
end function

@test
function tagReleaseRunsGit() -> Unit uses Assert.Check, State, Process.Run
  bind calls <- Reference.new([])
  bind result <- handle
    tagRelease("v1.0")
  with
    case Process.run(command) ->
      Reference.set(calls, List.append(Reference.get(calls), Process.Command.arguments(command)))
      resume(Result.Ok(Process.Output(exitCode: 0, standardOutput: "", standardError: "")))
  end handle
  Assert.equal(result, Result.Ok(()))
  Assert.equal(Reference.get(calls), [["tag", "v1.0"]])
end function
```

`readPortReadsNumber` の `handle` は、`File.Read` の操作のうち `File.readText` だけを処理する。一部の操作だけを処理したエフェクトは型から除かない（[型システム](../01-spec/01-06-type-system.md)の「エフェクトの宣言とハンドラの型付け（初回リリース版）」）ので、この関数の `uses` には `File.Read` が要る。`tagReleaseRunsGit` の `Process.Run` も同じである。どちらのテストも、実際にはファイルを読まず、コマンドを起動しない。

### 表形式のテスト

【方針】表形式のテストのための専用の構文は設けない。入力と期待する値の組をリストにし、テストの中で順に確かめる。

```text
@test("add handles several cases")
function addCases() -> Unit uses Assert.Check
  List.forEach([Triple(1, 2, 3), Triple(0, 0, 0), Triple(-1, 1, 0)], lambda(c)
    Assert.equal(add(Triple.first(c), Triple.second(c)), Triple.third(c))
  end lambda)
end function
```

最初に失敗した組でテストは終わる。失敗の報告に示す呼び出しの履歴から、どの組で失敗したかを辿れる。

### テストの実行

【決定】`benitoite test <パス>...` は、指定したファイルを検査し、それぞれのファイルに書いたテストの関数を実行する。ディレクトリを指定したときは、その下のすべての `.bnt` のファイルを指定したものとし、各ファイルの根のディレクトリは、指定したディレクトリとする。検査の誤りがあるファイルは、テストを実行せずに `check` と同じく誤りを報告し、ほかのファイルのテストは続けて実行する（[ADR 0206](../decisions/0206-test-command-line-and-exit-status.md)）。

【方針】指定したファイルが取り込むモジュールのテストの関数は、そのモジュールのファイルを指定しない限り実行しない。

【決定】テストは、一つずつ別の実行として動かす（[ADR 0120](../decisions/0120-test-functions-and-assert-effect.md)、[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）。

- 一つのテストで実行時エラーが起きても、そのテストが失敗するだけであり、ほかのテストは続ける。実行時エラーそのものは、これまでどおり捕捉できない（[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）。
- テストは、ほかのテストの実行の順序と、実行したかどうかに依存してはならない。処理系は、テストを並行に動かしてよい。
- 初回リリース版の実行器は、実際に行う IO の許可を調べない。実行時の権限制御は、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。加えた後は、実際に行う IO は実行時の権限制御の対象になり、許されない操作は実行時エラー（権限の拒否）になって、そのテストは失敗する。テストの実行で許可を与える方法は、実行時の権限制御の方式とあわせて [OPEN-052](../open-issues.md#open-052) で決める（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）。ハンドラで差し替えた操作は、処理系が行わないので、許可を要しない。サーバモードを加えた後、[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)が拒否した操作は、実行時エラーではなく IO の失敗（`Result.Error`）として返る。テストの実行器と、スクリプトを子プロセスで実行する仕組み（[ADR 0204](../decisions/0204-standalone-runs-in-sandboxed-child.md)）との関係は、[OPEN-052](../open-issues.md#open-052) に残る論点である。
- テストの関数の中で標準出力と標準エラー出力に書いた内容は、実行器が受け取る。そのテストが失敗したときに、報告に加えて示す。標準入力は空の入力につなぐ（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- 実行器はファイルの `main` を呼ばない。テストのファイルに `main` はなくてよい。テストの中の `Process.arguments` は空のリストを返す。
- テストの中で `Process.exit` を呼ぶと、そのテストだけを終え、失敗として報告する（ADR 0165）。
- 実行器が中断の要求（`SIGINT` など）を受けたら、実行中のテストを取り消してリソースを解放し、それまでの結果を報告して、終了状態 130 で終わる（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。

### 結果の報告

【方針】実行器は、テストごとに、名前と結果（成功、失敗）を報告する。失敗したテストについては、次のものを示す。

| 失敗の理由 | 示すもの |
|---|---|
| `Assert` の確認の失敗 | 失敗した確認の位置と呼び出しの履歴。`Assert.equal` と `Assert.notEqual` では両方の値、`Assert.isTrue` と `Assert.fail` では文字列 |
| `Result.Error(message)` を返した | `message` |
| 実行時エラー | 実行時エラーの報告と同じ内容（種類、位置、呼び出しの履歴。[診断エンジン](../02-impl/02-10-diagnostics.md)） |

- 値は、処理系が人間の読める形に書き出す。代数的データ型は構成子と引数を、レコードはフィールドの名前と値を、リスト・マップ・集合は要素を示す。この表記は言語から呼べる関数ではない。
- 最後に、成功と失敗の数を示す。すべてのテストが成功すれば成功を、一つでも失敗すれば失敗を表す終了状態で終わる。終了状態の値は [CLI](06-01-cli.md) で定める。

【決定】テストごとの結果と、最後の数の集計は、標準出力に書く。検査の誤りの診断と処理系の不具合の報告は、`check` と `run` と同じく標準エラー出力に書く。`--diagnostics=json` を指定したときは、結果も JSON Lines の形で書き、テストごとに一行を、最後に集計の一行を書く（[ADR 0208](../decisions/0208-test-report-destination.md)）。

【決定】報告の形は次のとおりとする（[ADR 0252](../decisions/0252-test-report-format.md)）。

- 文章の形は、Rust の `cargo test` の形に合わせる。テストごとに `test <ファイル>: <名前> ... ok` か `... FAILED` の一行を書く。名前は、`@test` の説明があれば引用符で囲んだ説明、なければ関数の名前とする。
- 失敗したテストがあれば、すべてのテストの行の後に `failures:` の見出しを書き、失敗したテストごとに `---- <ファイル>: <名前> ----` の見出しと、上の表の失敗の詳細を書く。位置と呼び出しの履歴は、[診断エンジン](../02-impl/02-10-diagnostics.md)の文章の形式と同じ形で書く。テストが書いた出力があれば、`---- captured stdout ----`・`---- captured stderr ----` の見出しに続けて示す。
- 最後に `test result: ok.` か `test result: FAILED.` に続けて、成功の数と失敗の数を書く。検査の誤りでテストを実行しなかったファイルがあれば、その数を書く。中断の要求で終えたときは、そのことを書く。
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

test result: FAILED. 12 passed; 1 failed
```

- JSON Lines の形では、テストごとに `kind` が `"test"` の一行を書く。項目は、`file`、`name`（説明か関数の名前）、`function`（関数の名前）、`location`（関数の宣言の位置。診断の位置の形）、`outcome`（`"passed"` か `"failed"`）、`failure`（成功では `null`）、`stdout`・`stderr`（捕らえた内容の文字列）である。
- `failure` は、`reason`（`"assert"`・`"error"`・`"runtime"`・`"exit"`）と `message` のほかに、理由に応じた項目を持つ。`"assert"` は失敗した確認の位置 `primary` と `trace`、`Assert.equal`・`Assert.notEqual` では値を書き出した文字列 `left`・`right` を持つ。`"error"` は `Result.Error` の文字列を `message` に持つ。`"runtime"` は、実行時エラーの報告の JSON の形式の項目（`code`・`primary`・`trace`・`traceOmitted`・`taskOrigins` など）を持つ。`"exit"` は `Process.exit` の終了状態 `exitCode` を持つ。
- 最後に `kind` が `"testSummary"` の一行を書く。項目は、`passed`、`failed`、`filesNotRun`（検査の誤りで実行しなかったファイルの数）、`interrupted`（中断の要求で終えたか）である。

### プロパティベーステスト

【未決】ランダムに作った入力で性質を確かめるプロパティベーステストと、型の構造から入力の生成器を導出する仕組み（[設計メモ](../sources/fp-language-design.md) 24.3）を設けるかは、[OPEN-046](../open-issues.md#open-046) で検討する。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（属性とテストの書き方）
- [OPEN-046](../open-issues.md#open-046): プロパティベーステストと、入力の生成器の導出
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（テストの実行で許可を与える方法、テストの実行器と子プロセスでの実行の関係）
