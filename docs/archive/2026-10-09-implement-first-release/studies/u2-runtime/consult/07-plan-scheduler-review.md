# 相談 第 7 回: 実装プランのタスク・スケジューラ・IO の部分のレビュー

- 状態: 反映済み（2026-09-30）。設計者の判断を要する事項は下記の表の後に挙げる
- 対象: 10-09 のタスクの節、10-10 の要所、作業 R24・R25・R26 の文書

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 13:19:58〜13:29:43（約 10 分） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 渡した資料 | 依頼文（英語 約 600 語）。10-09・10-10 の行の範囲と R24〜R26 の全文（計 約 1,220 行）を一度のコマンドで読ませ、その後の読み取りを 2 回までとした |
| 問いの数 | 7 |
| トークン | 入力 184,634（うちキャッシュ 112,000）、出力 18,950（うち推論 14,486） |
| 検証者が実行したコマンド | 4 回 |
| レートの減り | 68% → 50%（18 ポイント。設計者の報告） |

## 送った依頼文

````text
You are reviewing part of the implementation plan for the runtime redesign of
"Benitoite" (a small statically typed functional scripting language written
in Rust). In earlier rounds you reviewed the design (scheduler, I/O executor,
task/resource state machines, Lazy) and the heap and VM parts of this plan.
The plan freezes Rust types and splits work into tasks for LLM coding agents.
You can read the repository but must NOT modify files or call other
tools/agents. Answer in Japanese; keep identifiers and code in English.

## Reading budget (important)

Every tool call re-sends the whole conversation. Read the review target with
exactly ONE shell command, this one:

    sed -n '736,950p' docs/archive/2026-10-09-implement-first-release/10-interfaces/10-09-vm.md; sed -n '23,95p;183,524p;662,771p' docs/archive/2026-10-09-implement-first-release/10-interfaces/10-10-scheduler-and-io.md; for t in docs/archive/2026-10-09-implement-first-release/20-tasks/R24-resources.md docs/archive/2026-10-09-implement-first-release/20-tasks/R25-tasks-and-scheduler.md docs/archive/2026-10-09-implement-first-release/20-tasks/R26-dispatch-queue-and-io-executor.md; do echo "=== $t"; cat $t; done

Then answer. Use at most 2 further reads, only if a finding truly depends on
it (e.g. docs/archive/2026-10-09-design-first-release/decisions/0264, 0266, 0274, or 10-10 lines 96-182 on the
swappable test parts). Do not read Rust sources.

## Fixed decisions (not up for debate)

Single VM thread; single-threaded scheduler switching only at calls and
external waits; worker threads never touch language values; mio event loop.
Every builtin effect operation not handled by a language handler goes into
one dispatch queue in both I/O modes (direct call, request/response); the task
waits before the request is published; switch points always dispatch
requests and absorb completions. Operation records outlive task delivery;
completion handling returns resources first, then reports panics, then
delivers. Task states Ready/Waiting/Unwinding/Done; resource states
Open/Lent/Releasing/Released. Back-references to tasks are non-owning ids
with generation. A handle keeps its record until its body ends and its task
count is 0; grandchildren register with the same handle. Deadlock detection
(ADR 0238) runs after absorbing completions and counts resource return,
release and output-completion waits as external. Scheduler and resource table
live in RunState. Tests can swap the task picker, clock and worker execution
(ADR 0274). OPEN-062 items are verified by reproduction tests, not by extra
machinery.

## Questions

1. State machines: any reachable combination of task state, resource state,
   operation record and handle record that the documents leave undefined or
   that leads to a leak, double release, lost wakeup, or a task resumed after
   cancellation? Give a concrete event sequence.
2. Dispatch queue in the two I/O modes: does the plan make R02-style "request
   never sent" impossible, and are the request-id / saved-frame mapping and
   the fast path (if any) consistent across R25/R26?
3. Deadlock detection timing and the stop procedure: false positives while a
   worker still holds a lent resource, or while output is being flushed;
   interaction with GlobalStop.
4. Deterministic scheduler / virtual time: can the swappable parts actually
   force the interleavings needed for OPEN-062 R01-R05 and R13 reproduction
   tests? What is missing?
5. Task split R24/R25/R26: ordering, hidden dependencies, tests that would not
   catch real bugs, missing tests.
6. A known suspect to check: in R24, a task waiting for a release could be
   woken early, see the resource in Releasing and take the AlreadyReleased
   path, returning Popped before the release completes. The plan currently
   avoids this only by the rule "release-frame waits are not removed by
   cancellation or global stop". Is that sufficient?
7. Anything over-engineered that can be cut.

## Output format

Findings list, most severe first: file + heading/line, problem, concrete
fix, severity high/medium/low. Then "Looks fine" in at most 5 lines. Keep the
whole answer under about 2,000 words. Do not restate the documents.
````

## 検証者の回答（そのまま）

1. **high — 解放待ちを取り消さない規則だけでは、早期の `Popped` を防げない。**  
   [R24-resources.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R24-resources.md)「ResourceTable の関数」「unwind_release」、[R26-dispatch-queue-and-io-executor.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R26-dispatch-queue-and-io-executor.md)「完了の処理」

   具体的には、A が資源 r の貸し出しを待って `r.waiters` に入り、取り消されて、自分の解放枠で `AfterReturn` を待つ場合である。R25 の取り消し手順には `ResourceEntry::waiters` から除く指定がない。元の仕事が r を返すと、R26 はブロックする解放を始めて `Releasing` にし、返却待ちの A を起こせる。再実行された `unwind_release` は `AlreadyReleased → Popped` となり、解放の完了前に枠を降ろす。取り消しによる起床を禁止しても、この返却による起床は防げない。

   **修正:** `AlreadyReleased` は `Released` に限定し、`Releasing` では再び解放完了を待つ。これは 10-10 の状態遷移表にも一致する。取り消し時には貸し出し待ちの登録を除き、起床時にも待つ対象を照合する。受け入れテストは「返却後、解放完了を保留しても枠とタスクが残る」「完了時の失敗が元の原因に従って報告される」を確かめる。現行の「返却**か**解放完了の後に `Popped`」というテスト条件も直す必要がある。

2. **high — `TaskGroup` の終了待ち中に取り消されると、子の取り消しを飛ばせる。**  
   [R24-resources.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R24-resources.md)「request_release」「unwind_release」、[R25-tasks-and-scheduler.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R25-tasks-and-scheduler.md)「取り消し」

   P が `with` を抜けると、G は先に `Released` になり、P は子 C の終了を `TaskEnd(TaskGroupRelease(G))` で待つ。この間に `Task.race` などが P を取り消すと、内部の待ちは外され、同じ解放枠を原因 `Cancel` で辿る。しかし `request_release(G)` は既に `AlreadyReleased` を返すため、C を取り消す分岐に到達しない。P だけが終了し、C が残り得る。

   **修正:** 新しい `spawn` を禁止する状態と、その解放枠の子の終了待ちが済んだことを区別する。G が `Released` でも、解放枠の待ちが残る間は子一覧を再評価し、原因が `Cancel` に変われば生存する子を取り消して待つ。R25 の `Task.race` テストに、**本体の実行中ではなく、既に `TaskGroup` の終了を待っている親**を取り消す場合を加える。

3. **high — `accept_completion` の凍結した入出力では、指定された照合と配送を実装できない。**  
   [10-10-scheduler-and-io.md](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-10-scheduler-and-io.md)「外部の操作の記録と完了」、R26「完了の処理」

   `accept_completion` はタスク表もスケジューラも受け取らないため、「そのタスクがまだその操作を待つか」を調べられない。さらに R26 は操作記録を削除してから `Accepted::Deliver { task, outcome }` を返し、その後で VM が「記録の `site`」を読むよう指示する。操作番号も `site` も返り値にない。例えば A の完了を B の実行中に取り込むと、配送先 A は分かっても、指定された経路では A の結果レジスタを決める情報が失われる。

   **修正:** 配送候補に `ExtOpId` と `site` を含め、待ちの照合を VM 側で行うか、必要な `OpRecord` 自体を返す。記録を削除する前に必要情報を確保する。`OpKind::Release(resource)` の完了は、タスクへの配送とは独立して `finish_release` と失敗の記録まで処理する、と明記する。

4. **high — 未実行の要求を取り消す手順と、資源待ちになった要求の保存先がない。**  
   [R26-dispatch-queue-and-io-executor.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R26-dispatch-queue-and-io-executor.md)「要求の処理」「二つの部品」、R25「取り消し」「止める手順」

   要求応答方式で A の要求 q を外側へ返し、応答を保留したまま VM を進め、別タスクが A を取り消す場合を考える。`OpTable::detach_task` はまだ操作記録のない q には作用しない。後から `serve_request(q)` を呼ぶと、指定手順には失効確認がなく、既に降ろした枠を読むか、取り消した要求の副作用を実行し得る。`GlobalStop` 時の未実行要求にも同じ問題がある。

   また、要求を取り出した後に `lend` が `MustWait` を返す場合、命令位置は既に次へ進んでおり、再処理する `Request` の保存先が指定されていない。出力の転送を待ってから仕事を出す場合も同様である。

   **修正:** 要求が「未処理・資源／出力待ち・外部操作へ移行・失効」のどこにある間も、呼び出し位置を保持する場所を一つに決める。取り消しと停止で未実行要求を失効させ、`serve_request` も世代と現在の待ちを確認する。両方式で、遅れて処理される失効要求と、資源返却後の要求の再処理をテストする。

5. **medium — R24 から R26 へブロックする解放仕事を渡す所有権の経路が未定義である。**  
   [R24-resources.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R24-resources.md)「unwind_release」手順 4、R26「作るもの」「作業用のスレッド」

   `request_release` は表から資源を取り出して `Blocking(Box<dyn OsResource>)` を返す。一方、`unwind_release` が返すのは `Wait(ResourceId)` だけであり、同関数から `IoRuntime` にも触れない。この `Box` を誰が保持し、R26 がどこから取り出すかが決まっていない。「R26 が仕事を出す」とするだけでは、凍結した型を扱う別々の実装担当者が接続できない。

   **修正:** 例えば、投入前の資源を表に保持し、共通の待ち処理で R26 が取り出す手順を明示する。必要な欄は凍結前に確定する。R26 の完了条件に、解放仕事の投入から `Outcome::Released`、状態更新、失敗の報告までを加える。現在の「直接 `unwind_release` を呼び、補助で完了を記録する」テストでは、この接続が欠けても通る。

6. **medium — 行き詰まりの共通手順と、外部の待ちを数える条件が一致していない。**  
   [10-10-scheduler-and-io.md](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-10-scheduler-and-io.md)「完了の処理と行き詰まりの判定の順序」手順 4〜6、R26「待たせる位置と遅い経路の順序」

   共通手順 5 は `Scheduler::is_deadlocked()` だけで判定するが、その型は `OpTable`、要求、出力の状態を参照できない。R26 の「これらも外部の待ちに数える」という追記との接続が必要である。

   例えば、配送先を外した仕事が資源を借りたまま残り、全タスクが内部待ちになれば、スケジューラ単体では行き詰まりになる。出力も、手順 4 で転送を始めた直後には、対応する `Waiting(Output)` が存在するとは限らない。現行の「仕事を待つタスクがある」テストは、どちらの誤判定も検出しない。

   **修正:** 共通の呼び出し側で、スケジューラの判定に加え、未完了操作・有効な要求・出力の転送がないことを確認する。出力の状態は `request_transfer` **後**に評価する。配送先のない操作と、タスクの待ちを伴わない出力転送のテストを R26／後続作業へ割り当てる。`GlobalStop` 中も完了処理は進め、元の停止理由を保持する。

7. **medium — 実行可能なタスクがある間に、筋書きを進める契機が定義されていない。**  
   [10-10-scheduler-and-io.md](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-10-scheduler-and-io.md)「テストで差し替える部品」、R25「テスト用の部品」、R26「WorkerExec のテスト用の実装」

   明示された筋書きの進行口は `idle` だが、B が計算を続ける場合には呼ばれない。`TaskPicker` は次のタスクを選び、`try_recv` は届いた完了を返すだけの契約なので、要求された「B の計算中に仕事を実行する」指示を誰が消費するかが未定義である。実行可能なタスクがある間の仮想時間の進行も同じ問題を持つ。

   **修正:** 三部品で共有する筋書きについて、選択または完了確認のどの境界で、仕事の実行と時間の進行を処理するかを R25 で決め、R26 が従う。型を増やす必要はない。R01–R05／R13 の再現テストでは、FIFO へのフォールバックで偶然通ることを避け、必要な指示が消費され、狙った順序になったことも確かめる。

8. **medium — `Task.allOk` のテストは、前方の子を早く取り消す誤りを見逃す。**  
   [R25-tasks-and-scheduler.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R25-tasks-and-scheduler.md)「受け入れテスト」`Task.allOk`

   第 1 子と第 3 子がともに `Error` の場合だけでは、第 3 子の失敗で第 2 子を誤って取り消しても、最終結果は期待どおり第 1 子の `Error` になる。

   **修正:** 「第 3 子が先に `Error` → 第 1 子が `Ok` → 第 2 子が `Error`」を加え、第 2 子が途中で取り消されず、その `Error` が結果になることを確かめる。「第 2 子以降を取り消す」という現行のテスト記述は、第 1 子の失敗を確認した後であることも明記する。

9. **low — 応答の形だけを確かめる七つの単体テストは削減できる。**  
   [R25-tasks-and-scheduler.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R25-tasks-and-scheduler.md)「本作業が書く組み込みの関数」「受け入れテスト」

   `StateReply` を組み立てるだけの関数について、その構造をそのまま期待値にするテストは、列挙済みのスクリプトによるテストと重複する。応答の形の誤りも、それらの実行結果で検出できる。

   **修正:** 単なる構造の一致を確かめるテストは省き、期限の正規化など、独立した境界条件があるものだけ残す。その分を上記の待ち・取り消し・完了をまたぐテストに充てる。

**Looks fine**

- 公開前の `park` と、実行可能なタスクが残っていても `VmStep::Requests` を返す規則は、R02 型の要求送信漏れを防ぐ。
- 最終形では即時完了の近道がなく、予算が残る場合も要求発行は待ち処理を通る。R25 の直接実行は、R26 で消す一時的な実装として整合している。
- 孫の同じ `handle` への登録と、本体終了かつ所属タスク数ゼロまで記録を残す規則は整合している。
- 操作記録を配送先より長く保持し、返却を先に行い、配送先がなくても panic を報告する方針は妥当である。

## 本資料への反映

九つの指摘をすべて、検証者の修正案のとおりに反映した。凍結する型を改めたのは C02 が置く章（10-09 の `vm/task.rs`、10-10 の全体）だけであり、C01 の置くものは変えていない。

| 指摘 | 変えたこと |
|---|---|
| 1（解放の完了の前の `Popped`） | 10-09: `WaitReason::Resource` を `Lend`（貸し出しのための返却の待ち。取り消しで外す）と `Release`（解放の完了の待ち。外さない）に分けた。10-10: `ReleaseStart::InProgress` を加え、`AlreadyReleased` を `Released` に限った。`Scheduler::wake_if`・`wake_all`（理由を照合して起こす）、`ResourceTable::remove_waiter`・`pop_waiter`、`ResourceEntry::release_failure`・`take_release_failure` を加え、`finish_release` が結果を受け取る形にした。R24: `unwind_release` の手順 1・4 と遷移、受け入れテスト（返却の後に解放の完了を保留しても枠が残る、失敗が原因の規則で報告される）を改めた。R25: 取り消しで返却を待つ並びから除く、知らせで起こすときに理由を照合する。R26: 指摘の反例の順序のテストを加えた |
| 2（`TaskGroup` の終わりを待つ親の取り消し） | 10-09・R24: `Released` は新しい `spawn` を受け付けないことだけを表し、解放の枠は呼ばれるたびに子の並びを評価し直す（`request_release` が `Released` の `TaskGroup` にも子の並びを返す）。原因が `Cancel` に変われば子を取り消して待つ。R25: 取り消しの手順の箇条と、`TaskGroup` の終わりを待つ親を `Task.race` が取り消すテストを加えた。02-08「取り消し」に同じ規則を加えた |
| 3（`accept_completion` の照合と配送） | 10-10: `Accepted::Deliver` に操作の番号と `site` を持たせ、待ちの照合を VM の側に置いた。`Returned`・`ReleaseFinished` を加え、種類 `Release` の完了は配送と別に `finish_release` まで行うとした。R26: 完了の処理の手順と `Accepted` ごとの VM の処理を書き直した |
| 4（未実行の要求の失効と保存先） | 10-10: 要求の段階の表を加え、`DispatchQueue` を `queued`（番号）と `live`（`LiveRequest`。段階 `Queued`・`Outstanding`・`AwaitLend`・`AwaitFlush`）に改めた。`take_for_serve`・`park_request`・`take_task_request`・`expire_task`・`expire_all`・`has_live`・`has_outstanding` を加え、`ServeNow` を番号の並びにした。R26: 「仕事を出す手順」を加え、組み込みの関数を呼び直さずに待った手順から続ける形にした。両方式の失効した要求と、返却の後のやり直しのテストを加えた。R27・R28 の受け渡しを改めた |
| 5（ブロックする解放の仕事の受け渡し） | 10-10: `ReleaseStart::Blocking` から資源を外し、資源は項目に残して `ResourceTable::release_jobs` に番号を置く形にした。`take_release_job` と `JobWork`（`Builtin`・`Release`）を加えた。R24 は列に置くまで、R26 は手順 1 の後に取り出して記録と仕事を出すまでを受け持つ。R26: 実際の `USE`・`RETURN` の経路で仕事の投入から状態の更新と失敗の報告までを確かめるテストに改めた |
| 6（行き詰まりの判定の条件） | 10-10 手順 5: スケジューラの判定に、外部の操作の記録・生きている要求・転送中の出力（`OutputPort::transfer_pending`。手順 4 の後）がないことを加えた。止める手順の途中も同じ関数で完了を取り込み、元の理由を保つことを書いた。R25・R26・R27 に条件の分担と、配送先のない操作と待つタスクのない転送のテストを割り当てた |
| 7（筋書きを進める境界） | 10-10「テストで差し替える部品」: タスクを選ぶ指示は `pick`、時間を進める指示と仕事を実行する指示は完了の取り込みの境界（`try_recv`）と `idle` で行うと決めた。筋書きの記録で、使い切ったことと狙った順序を確かめる。R25（一時的な形を含む）・R26・R30 を合わせた |
| 8（`Task.allOk` のテスト） | R25: 「3 番目が `Error` → 1 番目が `Ok` → 2 番目が `Error`」のテストを加え、取り消しは 1 番目の失敗を確かめた後と明記した |
| 9（応答の形だけの単体テスト） | R25・10-12「作業の割り当て」: 七つの応答の形のテストを外し、`Task.withTimeout` の期限の正規化だけを単体テストとした。浮いた分は、取り消しと待ちをまたぐテスト（指摘 1・2・8 の分）に充てた |

設計書（02-08「取り消し」、02-09「タスクの待ちと取り消し」「リソースの追跡」）には、既存の ADR（0164、0266 の決定 5）から導かれる規則だけを加えた。次の事項は既存の ADR から直接は導かれないので、設計者の判断を要する。

- 取り消しと止める手順で、外部の操作に移る前の要求を失効させ、組み込みの関数を呼ばない（指摘 4）。仕様（01-11「取り消し」）は操作が起きなかったことを保証しないので、どちらも仕様に反しないが、実装プランで選んだ。
- 行き詰まりの判定で、配送先を外した外部の操作の記録と、待つタスクのない出力の転送も外部の待ちに数える（指摘 6）。ADR 0266 の決定 8 と 02-08 の定義の読み方としては自然だが、取り消したタスクの標準入力の読み取りのように終わらない操作が残ると、実際の行き詰まりが報告されずに待ち続ける。
- `Task`・`TaskGroup` の七つの組み込みの関数について、ADR 0276 の決定 4（組み込みの関数ごとの単体テスト）の代わりに、スクリプトの受け入れテストで各項目を確かめる（指摘 9）。

設計者は 2026-09-30 に、失効（指摘 4）と七つの組み込みの関数のテスト（指摘 9）を上のとおり採り、行き詰まりの判定（指摘 6）は、タスクを起こしうる外部の完了だけを数える形に改めた。配送先を外した操作と、待つタスクのない出力の転送は数えない。記録は [ADR 0282](../../../../2026-10-09-design-first-release/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)・[ADR 0283](../../../../2026-10-09-design-first-release/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)・[ADR 0284](../../../../2026-10-09-design-first-release/decisions/0284-task-builtins-tested-by-scripts.md) にある。
