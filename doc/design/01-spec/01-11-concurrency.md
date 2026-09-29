# 並行処理

- 状態: 確定
- 関連ADR: [0015](../decisions/0015-shared-program-per-execution-state.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0067](../decisions/0067-with-resource-scope.md), [0115](../decisions/0115-structured-io-concurrency.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0118](../decisions/0118-effect-handlers.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0142](../decisions/0142-http-api-shape.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0152](../decisions/0152-task-allok-list-order.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0164](../decisions/0164-taskgroup-release-while-stopping.md), [0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-044](../open-issues.md#open-044), [OPEN-062](../open-issues.md#open-062)
- 移行元: [設計メモ](../sources/fp-language-design.md) 5.1, 5.2

## 目的と範囲

採用した並行操作の意味・保証・制限。VM を複数のスレッドから利用するかは処理系の設計事項であり、[パイプライン](../02-impl/02-01-pipeline.md)と [ADR 0015](../decisions/0015-shared-program-per-execution-state.md) が扱う。

現在の版は、初回リリース版の範囲を定める。初回リリース版の並行処理は、外部に作用する操作（IO とネットワークの操作。[エフェクト](01-07-effects.md)）の完了を待つ間にほかの計算を進めるものであり、複数のコアで同時に計算すること（並列）は含まない。並列の方式は [OPEN-044](../open-issues.md#open-044) で決める。最小実行版には並行処理はない。

## 前提

- タスクを起動する関数は、起動する関数のエフェクトをエフェクト変数で受け渡す（[型システム](01-06-type-system.md)）。時間に依存する操作は `Benitoite.IO.Clock` のエフェクト `Clock.Time`、タスクの集まりの操作は prelude のエフェクト `State` を持つ（[エフェクト](01-07-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。
- タスクの中の評価の順序は、[評価意味論](01-08-evaluation.md)に従う。
- `TaskGroup` はリソースの型であり、`with` の規則（[リソース管理](01-10-resources.md)）に従う。
- 実行時エラーは捕捉できない（[エラー処理](01-09-errors.md)）。

## 仕様

### タスク

【決定】タスク（task）は、ほかのタスクと並行に進む計算である（[ADR 0115](../decisions/0115-structured-io-concurrency.md)）。プログラムの `main` の呼び出しは、最初のタスクとして進む。タスクは、引数のない関数（`function() -> T uses E`）を渡して起動し、その関数の呼び出しとして進む。関数の戻り値が、タスクの結果である。

【決定】並行処理は構造化されている。タスクを起動する操作は、後述の `Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout` と `TaskGroup.spawn` だけである。次のどちらかの時点で、起動したタスクはすべて終わっている。

- `Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout` の呼び出しが終わる時点。これらの関数が起動したタスクについて成り立つ。
- `TaskGroup` を束縛した `with` を抜ける時点。その `TaskGroup` で起動したタスクについて成り立つ。

したがって、`main` の呼び出しが終わった時点で、終わっていないタスクはない。起動した側が終わりを待たないタスクを作る操作はない。

### タスクの切り替え

【方針】初回リリース版の処理系は、同時に一つのタスクだけを進める。進めるタスクは、次のように切り替える。

- 外部に作用する操作の完了を待つタスクがあれば、その間にほかの進められるタスクを進める。
- 外部に作用する操作を行わずに計算を続けるタスクがあっても、処理系は一定の量を実行するごとに、ほかの進められるタスクに切り替える。進められるタスクが、ほかのタスクの計算のために止まり続けることはない。

【決定】タスクを切り替える位置は、処理系が決める。プログラムは、切り替わる位置に依存してはならない。二つのタスクの操作がどの順に起きるかは定めない。ただし、あるタスクの結果を待つ操作（後述の `Task.await`・`Task.all` など）の後に起きる操作は、待ったタスクのすべての操作の後に起きる。複数のコアで並列に実行する処理系（[OPEN-044](../open-issues.md#open-044)）でも、本章の意味は変えない。

【決定】次の操作は、ほかのタスクの操作と混ざらずに、一つのまとまりとして起きる。

- 可変のセルの操作（`Reference.new`・`Reference.get`・`Reference.set`・`Reference.update`。[エフェクト](01-07-effects.md)）。
- 標準出力と標準エラー出力への一回の書き込み（`Console.writeLine` などの一回の呼び出しの文字列は、ほかのタスクの出力に割り込まれない）。

同じタスクの中の操作は、[評価意味論](01-08-evaluation.md)の順序で起きる。

### タスクを起動する関数

【方針】タスクを起動し、結果を待つ関数は次のとおりである。すべて prelude の `Task` モジュールの関数である。起動する関数のエフェクト `E` は、呼び出しのエフェクトになる。どのタスクの結果が先に得られるかは時間に依存するので、`Task.race` と `Task.withTimeout` は `Clock.Time` のエフェクトも持つ。`Task` は prelude のモジュールなので import なしで呼べるが、これらを呼ぶ関数の `uses` に `Clock.Time` を書くには、`Benitoite.IO.Clock` の import が要る（`uses IO.All` と書くときは要らない。[エフェクト](01-07-effects.md)）。表の `actions` はタスクとして起動する関数のリストであり、`action` は一つの関数である。

| 関数 | 型 | 値 |
|---|---|---|
| `Task.all(actions)` | `function[T, effect E](List[function() -> T uses E]) -> List[T] uses E` | `actions` の各関数をタスクとして起動し、すべてが終わるのを待って、結果を `actions` と同じ順に並べたリスト |
| `Task.allOk(actions)` | `function[T, X, effect E](List[function() -> Result[T, X] uses E]) -> Result[List[T], X] uses E` | すべてのタスクが `Result.Ok` を返したら、値を `actions` と同じ順に並べたリストの `Result.Ok`。どれかが `Result.Error` を返したら、`Result.Error` を返したタスクのうち `actions` の中で最も前にあるものの `Result.Error`（後述） |
| `Task.race(actions)` | `function[T, effect E](List[function() -> T uses E]) -> Option[T] uses Clock.Time, E` | 最初に終わったタスクの結果の `Option.Some`。そのほかのタスクは取り消す。`actions` が空なら `Option.None` |
| `Task.withTimeout(milliseconds, action)` | `function[T, effect E](Integer, function() -> T uses E) -> Option[T] uses Clock.Time, E` | `action` を起動し、`milliseconds` ミリ秒以内に終われば結果の `Option.Some`。終わらなければタスクを取り消して `Option.None`。`milliseconds` が 0 以下なら、0 として扱う |

【決定】`Task.allOk` の結果は、タスクを切り替える位置によらない（[ADR 0152](../decisions/0152-task-allok-list-order.md)）。`actions` の i 番目のタスクが `Result.Error` を返したら、i より後ろの、終わっていないタスクを取り消し、i より前のタスクの終わりを待つ。i より前のタスクがすべて `Result.Ok` を返したら、i 番目のタスクの `Result.Error` を返す。i より前のタスクが `Result.Error` を返したら、そのタスクについて同じ規則を繰り返す。結果の値は、各関数を `actions` の順に呼び、最初の `Result.Error` で打ち切ったときの値と一致する。

【方針】呼び出したタスクを止めて時間の経過を待つ関数は、`Benitoite.IO.Clock` のエフェクト `Clock.Time` の操作であり、`Task` には置かない（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `Clock.sleep(milliseconds)` | `function(Integer) -> Unit uses Clock.Time` | 呼び出したタスクを、少なくとも `milliseconds` ミリ秒止める。その間、ほかのタスクを進める。`milliseconds` が 0 以下なら、止めずに戻る |

### タスクの集まり

【方針】要求を受け付けるたびに処理を起動する場合のように、起動するタスクの数が前もって決まらないときは、タスクの集まり `TaskGroup` を使う。`TaskGroup` はリソースの型であり、`with` で束縛して使う（[リソース管理](01-10-resources.md)）。

【決定】`TaskGroup.open()` の呼び出しは、`with` の束縛の式（`with group = TaskGroup.open() do`）としてだけ書ける（[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)）。それ以外の位置の呼び出しと、`TaskGroup.open` を関数の値として参照すること（引数に渡す、`let` で束縛するなど）は、型検査の誤りとする。診断は、`with` で束縛する書き方を修正案として示す。`with` で束縛した `TaskGroup` を、関数の引数に渡したり、ラムダに捕捉したりするのはよい。`Task[T]` は、起動したタスクを表す、中身を見せない prelude の型である（[型システム](01-06-type-system.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `TaskGroup.open()` | `function() -> TaskGroup uses State` | 空のタスクの集まり |
| `TaskGroup.spawn(group, action)` | `function[T, effect E](TaskGroup, function() -> T uses E) -> Task[T] uses State, E` | `action` をタスクとして起動し、`group` に加える。起動したタスクの終わりを待たずに戻る |
| `Task.await(task)` | `function[T](Task[T]) -> T uses State` | `task` が終わるのを待ち、その結果を返す。終わっていれば、すぐに結果を返す |

【方針】`TaskGroup` の解放（`with` を抜けるとき）は、その集まりで起動したすべてのタスクが終わるのを待つ。タスクを取り消しはしない。`Task.await` で待たなかったタスクの結果は捨てる。解放した `TaskGroup` に `TaskGroup.spawn` でタスクを加えると、実行時エラー（解放したリソースの使用）とする。

【決定】プログラムが止まる途中（実行時エラー、資源の不足、`Process.exit`、中断の要求）の `TaskGroup` の解放は、その集まりで起動したタスクの終わりを待たない。それらのタスクも、同じ停止の手順で止まる（後述の「失敗と停止」、[ADR 0164](../decisions/0164-taskgroup-release-while-stopping.md)）。

タスクの中で、別の `TaskGroup` を開いたり、`Task.all` などを呼んだりしてよい。タスクの集まりは入れ子にできる。

### 取り消し

【方針】`Task.allOk`・`Task.race`・`Task.withTimeout` は、終わっていないタスクを取り消す。取り消しは次のとおりである。

- 取り消したタスクは、処理系が次にそのタスクを切り替えうる位置で止まる。外部に作用する操作の完了を待っているタスクは、待つのをやめて止まる。`Task.all` などで起動したタスクの終わりを待っているタスクを取り消すと、待っていたタスクも取り消す。
- 止まる前に、そのタスクの中で開いている `with` のリソースを、内側のスコープから順に解放する。解放の失敗の扱いは[リソース管理](01-10-resources.md)の「解放の失敗」に従う。そのタスクが開いている `TaskGroup` で起動したタスクも、取り消す。
- 取り消したタスクの結果はない。取り消したタスクの `return` と `try` は、呼び出し元に値を返さない。
- 取り消したタスクが始めていた外部に作用する操作は、取り消した時点で終わっているとは限らない。取り消しは、その操作（ファイルの書き込み、コマンドの実行、HTTP の要求の送信など）が起きなかったことを保証しない。

`TaskGroup.spawn` で起動したタスクを、プログラムから取り消す関数は、初回リリース版にはない。

### タスクとハンドラ

【決定】`handle` の本体の中で起動したタスクは、そのハンドラを引き継ぐ（[ADR 0118](../decisions/0118-effect-handlers.md)）。タスクの中で呼んだ操作は、タスクを起動した位置で有効だったハンドラが処理し、節はその操作を呼んだタスクの中で実行する。

- `handle` は、本体の中で起動したタスク（外側で開いた `TaskGroup` に加えたものを含む）がすべて終わるまで終わらない。本体が途中の `return` や `try` で `handle` を抜けるときも同じである。
- `handle` を評価したタスク自身が呼んだ操作の節が `resume` を呼ばずに終わったときは、本体の中で起動した、終わっていないタスクを取り消す（前述の「取り消し」）。

【決定】タスクの中で呼んだ操作を、そのタスクが引き継いだハンドラ（そのタスクの外で評価を始めた `handle`）が処理するときは、その操作の節は末尾で再開する節でなければならない（[ADR 0151](../decisions/0151-inherited-handlers-tail-resume-only.md)）。

- 末尾で再開する節とは、節の本体のどの終わり方も末尾位置の `resume(v)` であり、節の中に `return` と `try` がない節である。末尾で再開するかどうかは、節ごとに構文から決まる。
- 末尾で再開する節は、操作を呼んだタスクの中で実行する。`resume(v)` に達したら、操作の呼び出しの結果を `v` とし、そのタスクの続きを実行する。節の値は使わない。
- 操作の節が末尾で再開する節でなければ、節を実行せずに実行時エラー（引き継いだハンドラの節の誤り）とする。

```text
handle
  Task.all([lambda() return File.readText("a.txt") end lambda])
when File.readText(path):
  resume(Result.Ok("text"))       // よい: 末尾で再開する節
end handle
```

### 失敗と停止

【決定】どれかのタスクで実行時エラーが起きたら、プログラム全体を止める（[ADR 0115](../decisions/0115-structured-io-concurrency.md)、[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）。止める手順は[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」に従う。このとき、すべてのタスクについて、そのタスクの中で開いている `with` のリソースを内側のスコープから順に解放する。タスクの間で解放する順序は定めない。`Process.Exit` のエフェクトの操作によってプロセスを終えるときも同じである（[エフェクト](01-07-effects.md)の「影響の大きい操作（初回リリース版）」）。

【決定】進められるタスクがなく、外部に作用する操作の完了（標準入力の読み取り、`Http.accept` の次の要求、`Clock.sleep` と `Task.withTimeout` の時間の経過など）を待つタスクもないときに、待つタスクがあれば、実行時エラー（タスクの待ち合いの行き詰まり）とする（[ADR 0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)）。ここで待つタスクとは、ほかのタスクの終わり（`Task.await`・`Task.all` などの呼び出し、`handle` の終わり、`TaskGroup` を束縛した `with` の終わり）か、ほかのタスクが評価している `Lazy` の評価の終わりを待つタスクである。この状態では、実行の外で何が起きても、どのタスクも進まない。`Task` の値を可変のセルに入れて、二つのタスクが互いを `Task.await` で待つ場合などに起きる。

- 止める手順は、ほかの実行時エラーと同じである。
- 報告は、待つタスクごとに、何を待っているかと、その位置を示す。形式は[診断エンジン](../02-impl/02-10-diagnostics.md)で定める。
- 外部に作用する操作の完了を待つタスクがあるあいだは、ほかのタスクが待ち合っていても、この実行時エラーにしない。

タスクの中の失敗を呼び出し元で扱うときは、タスクの関数が `Result` を返すようにする。`Task.allOk` は、そのための関数である。

### 例

次の例は、HTTP の要求を受け付けるたびに、その処理をタスクとして起動する。`Http.listen`・`Http.accept`・`Http.requestOf`・`Http.respond` は、`Benitoite.Network.Http` の関数である（[ネットワークのモジュール](../03-interop/03-09-network.md)）。`respondTo` は、要求から応答を作る利用者の関数とする。ファイルに `import Benitoite.Network.Http` が要る。

```text
function serve(listener: Http.Listener, group: TaskGroup): Result[Unit, NetworkError] uses Http.Listen, State
  let exchange = try Http.accept(listener)
  let _ = TaskGroup.spawn(group, lambda()
    with current = exchange do
      return Http.respond(current, respondTo(Http.requestOf(current)))
    end with
  end lambda)
  return serve(listener, group)
end function

function main(): Result[Unit, String] uses Http.Listen, State
  with listener = try Http.listen("127.0.0.1", 8080) |> Result.mapError(_, NetworkError.message),
       group = TaskGroup.open() do
    return serve(listener, group) |> Result.mapError(_, NetworkError.message)
  end with
end function
```

同じ振る舞いのサーバは、`Http.serve("127.0.0.1", 8080, respondTo)` の一回の呼び出しでも書ける。`Http.accept` が次の要求を待つ間も、処理系は起動済みの要求の処理を進める。一つの要求の処理が長い計算を続けても、ほかの要求の処理と受け付けは止まらない。クライアントが接続を切っても、`with` を抜けるときの `Http.Exchange` の解放の失敗は実行時エラーにならないので、サーバは止まらない（[ネットワークのモジュール](../03-interop/03-09-network.md)、[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）。

次の例は、二つのコマンドを並行に実行し、両方の結果を待つ。`Process.run` と `Process.command` は、`Benitoite.IO.Process` の関数である（[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」）。この式のエフェクトは `Process.Run` であり、ファイルに `import Benitoite.IO.Process` が要る。

```text
let outputs = Task.all([
  lambda() return Process.run(Process.command("git", ["status"])) end lambda,
  lambda() return Process.run(Process.command("git", ["log", "-1"])) end lambda
])
```

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（並行処理の語を予約語にして診断で書き方を示すか）
- [OPEN-044](../open-issues.md#open-044): 複数のコアで並列に計算する方式
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R01・R03・R04）
