# 0317. 取り消したタスクを `Task.await` で待ったら、実行時エラーにする

- 状態: 採択
- 日付: 2026-10-06
- 関連章: [並行処理](../01-spec/01-11-concurrency.md), [評価意味論](../01-spec/01-08-evaluation.md), [仮想機械](../02-impl/02-08-vm.md), [診断エンジン](../02-impl/02-10-diagnostics.md)
- 関連 ADR: [0031](0031-numbered-diagnostic-codes.md), [0064](0064-no-exceptions-runtime-errors-uncatchable.md), [0115](0115-structured-io-concurrency.md), [0161](0161-single-threaded-task-scheduler.md), [0238](0238-task-wait-deadlock-as-runtime-error.md), [0266](0266-task-and-resource-state-machines.md), [0282](0282-cancellation-timing-during-unwinding-and-requests.md)
- 関連する未決事項: なし

## 背景

[並行処理](../01-spec/01-11-concurrency.md)の「取り消し」は、取り消したタスクの結果はないと定める。一方で、取り消したタスクを別のタスクが `Task.await` で待ったときの結果は、01-11 にも [仮想機械](../02-impl/02-08-vm.md)にも書いていなかった。実装プランの作業 R39（タスクの取り消し）の事前点検で、この欠けが見つかった。

`Task.await` に渡せる `Task` の値を返すのは `TaskGroup.spawn` だけであり、`TaskGroup` を束縛した `with` を抜ける時点でその集まりのタスクはすべて終わっている（01-11「構造化」の決定）。それでも、次の手順を踏むと、型検査を通るプログラムが取り消したタスクを待てる。

1. タスク P が `with` で `TaskGroup` を開き、`TaskGroup.spawn` が返した `Task` の値を `Reference` に入れる。
2. P が `Task.race` などで取り消される。01-11「取り消し」により、P が開いている `TaskGroup` で起動したタスクも取り消される。`handle` の節が `resume` を呼ばずに終わり、本体の中で起動したタスクを取り消す場合（01-11「タスクとハンドラ」）も同じである。
3. 別のタスクが `Reference` から `Task` の値を読み、`Task.await` で待つ。

R25 が書いた実装は、この場合に処理系の不具合（`Stop::Internal`）を返していた。実装プランの規約は、`Stop::Internal` を型検査を通ったプログラムでは起きないはずの状態に使う（実装プラン 00-02「失敗を panic で表さない」）。この場合は型検査を通ったプログラムで起きるので、言語の規則として結果を定める必要がある。

## 決定

1. 取り消したタスクを `Task.await` で待つと、待ったタスクの側で実行時エラー（取り消したタスクの結果の待ち）として止まる。待つ時点で既に取り消して終わっていた場合も、待っている間に取り消して終わった場合も同じである。止まった命令は `Task.await` の呼び出しとする。止める手順は、ほかの実行時エラーと同じである。
2. 実行時エラーの種類を [評価意味論](../01-spec/01-08-evaluation.md)の「実行時エラーによる停止」の表に加え、診断コード `R1002` を割り当てる（区分 `R10nn` は並行処理。[ADR 0031](0031-numbered-diagnostic-codes.md)）。
3. 報告の文言は `the awaited task was cancelled, so it has no result` とする。説明は `` `Task.await` cannot return a value for a task that was cancelled. A `Task` value used outside its `with` block may refer to such a task. `` とする。

## 検討した代替案

- **待つ側も取り消す**: 型を加えずに済む。しかし、待つ側が `main` のタスクのときに何を終わり方とするかを別に決める必要がある。取り消しは報告を出さずに止まるので、利用者には待つ側のタスクが黙って止まったように見え、原因が報告に出にくい。
- **R39 の範囲の外として OPEN に登録する**: 今の作業の範囲は増えない。しかし、型検査を通るプログラムで処理系の不具合の報告が出うる状態が、決着まで残る。
- **`Task.await` の型を `Option[T]` などにして、取り消しを値で返す**: 取り消したタスクを待つ使い方は、`Task` の値を `with` の外へ持ち出したときにしか起きない。そのために、普通の使い方のすべての `Task.await` に分岐を書かせることになる（設計原則 6）。

実行時エラーを選んだ理由は二つある。取り消したタスクには結果がない（01-11）ので、`Task.await` が返す値がない。`Task` の値を `with` の外へ持ち出して待つのは構造化の意図から外れた使い方であり、原因と位置を報告に示して止めるのが利用者と LLM にとって分かりやすい（設計原則 3）。実行時エラーは捕捉できない（[ADR 0064](0064-no-exceptions-runtime-errors-uncatchable.md)）ので、プログラムの側で回復する書き方は加えない。

## 帰結

- 01-11「取り消し」に【決定】として規則を加え、`Task.await` の表の値の欄から参照する。01-08「実行時エラーによる停止」の表に種類を加える。
- 02-08「取り消し」に、待つタスクの側で `Task.await` の呼び出しを止まった命令とすることを書く。02-10「診断コード」の `R10nn` の行に `R1002` を加える。
- 実装プランの 10-08 の `RuntimeError`（`file=`、凍結）に変種 `AwaitedTaskCancelled` を加える。凍結したコードへの変種の追加である。10-02 の `diag::codes` の表に `R1002` の行を、「実行時エラー、資源の不足、処理系の制限」の表に `R1002` と `RuntimeError::AwaitedTaskCancelled` の対応を加える。
- 作業 R39 が、処理系の `RuntimeError` の変種、`diag::codes` の項目、`runtime::report` の分岐を加え、R25 が書いた `Stage1StateServices::task_poll`（`src/vm/state.rs`）の `TaskResult::Cancelled` の分岐を、この実行時エラーを返すように直す。
- 待っている間に待たれるタスクが取り消して終わると、R25 の終わりの知らせ（`awaiters` を `wake_if` で起こす）で待つタスクが起き、`PRIM` を実行し直して決定 1 の実行時エラーになる。知らせの仕組みは変えない。
