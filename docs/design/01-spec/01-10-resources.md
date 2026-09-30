# リソース管理

- 状態: 確定
- 関連ADR: [0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0067](../decisions/0067-with-resource-scope.md), [0068](../decisions/0068-release-resources-on-stop.md), [0096](../decisions/0096-explicit-return.md), [0097](../decisions/0097-prefix-try.md), [0115](../decisions/0115-structured-io-concurrency.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0137](../decisions/0137-first-release-library-scope.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0145](../decisions/0145-network-error.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0150](../decisions/0150-resource-release-as-state.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0164](../decisions/0164-taskgroup-release-while-stopping.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0257](../decisions/0257-match-with-case-arms.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012)
- 移行元: [設計メモ](../sources/fp-language-design.md) 4

## 目的と範囲

リソーススコープ（resource scope）の構文、解放順序、エラー時の解放。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。対象は、リソースの型、`with` の構文と意味、解放の時期と順序、解放の失敗、解放したリソースを使ったときの扱いである。具体的なリソースの型（一行ずつ読み書きするファイルなど）と、それを開く関数は、[IO のモジュール](../03-interop/03-07-io-modules.md)と[ネットワークのモジュール](../03-interop/03-09-network.md)で定める（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。

## 前提

ここでいうリソース（resource）は、使い終えた時点で閉じるか後始末をする必要があるものである。ファイルやネットワークの接続などの OS の資源のほか、起動したタスクの終わりを待つ必要があるタスクの集まり `TaskGroup` も含む。メモリの回収は処理系が行い（[ランタイム](../02-impl/02-09-runtime.md)）、本章の対象ではない（[設計メモ](../sources/fp-language-design.md) 4）。

`try` の意味と、例外を設けないこと（[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）は[エラー処理](01-09-errors.md)で、実行時エラーと資源の不足による停止の手順は[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### リソースの型

【決定】リソースにできる値は、標準ライブラリが定めるリソースの型の値に限る（[ADR 0067](../decisions/0067-with-resource-scope.md)）。

【方針】リソースの型は中身を見せない型であり、等値の型ではない。利用者が定義する型をリソースにする方法は、初回リリース版にはない。

初回リリース版のタスクの集まり `TaskGroup` もリソースの型であり、その解放は、集まりで起動したタスクがすべて終わるのを待つ（[並行処理](01-11-concurrency.md)）。

【方針】リソースの型ごとに、解放（release）の処理が一つ決まっている。解放の処理は、リソースの型ごとに標準ライブラリで定める。リソースの型は、`with` を使わずに解放する関数（`close` など）も持ってよい。この関数は、そのリソースの型の失敗の型 `E`（ファイルのリソースの型なら `IOError`、ネットワークのリソースの型なら `NetworkError`）について `Result[Unit, E]` を返し、解放の失敗をスクリプトが扱えるようにする。

【決定】解放のエフェクトは、どのリソースの型でも `State` である（[ADR 0150](../decisions/0150-resource-release-as-state.md)）。解放する関数も `State` を型に持つ組み込みの関数であり、エフェクトの操作ではない。`State` はハンドラで処理できない（[エフェクト](01-07-effects.md)）ので、`with` の解放と解放する関数は、どのハンドラの中でも処理系が実際に行う。解放は、実行時の権限制御の対象にしない。

### `with` の構文

【決定】`with x = e do ... end with` は、`e` の値のリソースを `x` に束縛してブロックを評価し、ブロックを抜けるときに `x` を解放する。`with a = e1, b = e2 do ... end with` のように複数を並べられる（[ADR 0067](../decisions/0067-with-resource-scope.md)）。

```text
import Benitoite.IO.File

function copyHeader(src: String, dst: String) -> Result[Unit, String] uses File.Read, File.Write, State
  with input = try File.openReader(src) |> Result.mapError(_, IOError.message),
       output = try File.openWriter(dst, File.WriteMode.Replace) |> Result.mapError(_, IOError.message) do
    bind line <- try File.readLine(input) |> Result.mapError(_, IOError.message)
    return File.writeLine(output, Option.unwrapOr(line, "")) |> Result.mapError(_, IOError.message)
  end with
end function
```

ファイルのリソースの型 `File.Reader`・`File.Writer` と、それを開く関数・読み書きする関数は[IO のモジュール](../03-interop/03-07-io-modules.md)で定める。

【方針】`with` の規則は次のとおりである。

- `with` は式であり、値はブロックの値、型はブロックの型である。`with` のエフェクトは、束縛する式と本体のエフェクトに、解放のエフェクト `State`（前述の「リソースの型」）を加えたものである。
- `e` の型はリソースの型でなければならない。失敗しうる操作でリソースを開くときは、`try` か `match` で `Result` から取り出してから束縛する。
- `x` の有効範囲は、`with` のブロックと、後に並べた `e` の中である。`with a = e1, b = e2` では、`e2` の中で `a` を使える。
- 並べた `e1`、`e2`、… は書いた順に評価し、それぞれを評価した直後に束縛する。途中の `e` の評価で `try` が関数を終えたときは、それまでに束縛したリソースだけを解放する。

構文は[構文](01-02-syntax.md)の「リソーススコープ（初回リリース版）」で定める。

### 解放の時期と順序

【方針】`with` で束縛したリソースは、次のときに、束縛と逆の順に解放する。

- ブロックの評価が終わったとき。ブロックの値を決めてから解放する。
- ブロックの中の `return` か `try` が、`with` を含む関数かラムダの呼び出しを終えるとき。`return` の式を評価した後で、内側の `with` から順に解放する。
- 実行時エラーか資源の不足でプログラムが止まるとき。その時点で開いているすべての `with` のリソースを、内側のスコープから順に解放してから止まる（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。手順の順序は[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」で定める。
- `Process.Exit` のエフェクトの操作で、終了状態を指定してプロセスを終えるとき。その時点で開いているすべての `with` のリソースを、内側のスコープから順に解放してから終わる（[エフェクト](01-07-effects.md)の「影響の大きい操作（初回リリース版）」）。
- ハンドラの節が `resume` を呼ばずに終わり、`handle` の本体の続きを捨てるとき。本体の中で開いていた `with` のリソースを、内側のスコープから順に解放する（[エフェクト](01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。
- タスクを取り消すとき。取り消したタスクの中で開いている `with` のリソースを、内側のスコープから順に解放してから、タスクを止める（[並行処理](01-11-concurrency.md)の「取り消し」）。
- 処理系が中断の要求（`SIGINT` など。[CLI](../06-tooling/06-01-cli.md)）を受けてプログラムを止めるとき。すべてのタスクを取り消し、各タスクで開いている `with` のリソースを、内側のスコープから順に解放してから終わる（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。

【決定】処理系が上限を設けていない資源が実行環境で尽きたとき（[ADR 0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md)）は、解放することを保証しない（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。

`with` のブロックの最後の式と、`with` のブロックの中の `return` の式は、その後に解放が続くので、末尾位置にない（[評価意味論](01-08-evaluation.md)の「末尾呼び出し」）。

### 解放の失敗

【方針】ブロックを抜けるときの解放が失敗したときは、実行時エラー（リソースの解放の失敗）とする。残りのリソースの解放は続け、失敗をすべて報告する。タスクの取り消しと、ハンドラが本体の続きを捨てるときの解放の失敗も、同じく実行時エラーとする。

【決定】実行時エラーか資源の不足で止まる途中で解放が失敗したときは、止まる理由の報告に解放の失敗を加える。先の実行時エラーを置き換えない（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。

【決定】リソースの型を定める章は、そのリソースの型の解放の失敗を実行時エラーにしない例外を定めてよい（[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）。例外のリソースの型の解放の失敗は、上の二つの規則によらず、どの時期の解放でも、実行時エラーにも報告の対象にもせず、捨てる。初回リリース版の例外は、`Http.Exchange`（[ネットワークのモジュール](../03-interop/03-09-network.md)）だけである。

解放の失敗をスクリプトの中で扱うときは、ブロックの最後で、リソースの型の `close` などの関数を呼んで `Result` を調べる。

【方針】`close` などの関数を呼んだリソースは、`close` が `Result.Error` を返したときも解放済みとみなす。解放済みのリソースを `with` がもう一度解放することはない。

### 解放したリソースの使用

【方針】リソースの値は、`with` のブロックの外へ返したり、ラムダに捕捉したりして、解放した後に使えてしまう。解放したリソースに対する操作は、実行時エラー（解放したリソースの使用）とする。これを検査で見つける仕組み（線形型など）は、初回リリース版にはない。

【方針】リソースの型の値を、`with` を使わずに束縛の文（`bind`・`shadow`）で束縛することもできる。ただし、`TaskGroup` は `with` の束縛の外で作れない（[並行処理](01-11-concurrency.md)の「タスクの集まり」、[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)）。この値は、スクリプトが `close` などで解放しない限り、プログラムが終わるまで解放しない。プログラムが止まるときに解放するのは、`with` で束縛したリソースだけである。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（`with` の書き方の成功率）
