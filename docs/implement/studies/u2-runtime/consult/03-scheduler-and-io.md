# 相談 第 3 回: スケジューラと IO、`Lazy` と `Reference`、OPEN-062

- 状態: 回答を受領。本資料へ反映済み
- 問い: Q5・Q6 と OPEN-062（[04-consult-plan.md](../04-consult-plan.md) の第 3 回）

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 00:58:23〜01:06:22（約 8 分） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 起動の形 | 第 1 回と同じ（読み取り専用） |
| 渡した資料 | 依頼文（英語 約 750 語）。読む範囲を行で指定し、ほかのファイルを読む回数を 5 回までとした |
| 問いの数 | 5 |
| トークン | 入力 158,888（うちキャッシュ 101,248）、出力 15,651（うち推論 10,916） |
| 検証者が実行したコマンド | 18 回 |
| レートの減り | 60% → 46%（14 ポイント。設計者の報告） |

## 送った依頼文

````text
You are reviewing part 3 of a runtime redesign for "Benitoite", a small
statically typed functional scripting language whose processor is written in
Rust. You can read the repository (current working directory) but must NOT
modify any file or call other tools/agents. Please answer in Japanese; keep
identifiers and code in English.

## Reading budget (important)

To save cost, read ONLY the following, and only the listed line ranges:

- docs/implement/studies/u2-runtime/03-options.md lines 231-301 (Q5 scheduler and I/O executor, Q6 Lazy and Reference)
- docs/design/02-impl/02-09-runtime.md lines 63-110 (builtin operations, handler table, dispatch), 129-213 (I/O executor, waiting and cancellation, resource tracking), 236-284 (output buffer, interrupt, stop procedure)
- docs/design/02-impl/02-08-vm.md lines 151-173 (Lazy, cells), 203-242 (task switching), 271-296 (stop procedure)
- docs/design/open-issues.md lines 998-1016 (OPEN-062: runtime counterexamples found by desk review)

Open other files only if an answer truly depends on it, and at most 5 more
reads in total. Do not read the Rust sources.

## Decisions already made (fixed for this round)

- 16-byte non-Send values; stage 1 prototypes both safepoint-only mark-sweep
  and improved reference counting and picks one by measurement; no-GC
  regions are branded with a lifetime and live values go to VM-owned roots
  before a safepoint.
- Builtins: implementers write typed functions; pure builtins get a context
  that cannot touch clock/random/resources and cannot return Wait,
  SpawnTasks or Exit. Worker jobs and results are `Send + 'static`;
  completion handlers are plain `fn` pointers; storing completions,
  spawning, cancellation races and returning lent resources are done by a
  shared mechanism, never by each builtin.
- Designer's decision for OPEN-062 R04/R13: output is appended to a buffer
  on the VM thread; transfer to the OS happens on a writer thread per output.
- Policy: OPEN-062 items are desk counterexamples. We do NOT add machinery
  just in case; we want a design in which they are structurally impossible
  when that is cheap, and otherwise cheap reproduction tests at
  implementation time.

## Other fixed constraints

- One execution = one VM thread; single-threaded scheduler switches only at
  calls and external waits; blocking I/O on worker threads that never touch
  language values; `mio` event loop.
- Two I/O execution modes must remain (ADR 0088): direct call (the VM calls
  the handler table) and request/response (the VM returns a request to an
  outer executor, read as a Freer monad, ADR 0029).
- No finalizers; resources are released only by `with` scopes and the stop
  procedure. Deadlock detection per ADR 0238.

## Questions

For each: position (agree / disagree / depends), reasons, main risk, and a
concrete test to write at implementation time.

1. Q5 option 5b (every builtin operation, in both modes, puts a request in
   one dispatch queue and makes the task wait; two dispatcher components
   differ only in who drains the queue and when). Does it really make R02
   structurally impossible? Does it preserve the Freer-monad reading? Is a
   fast path for immediately completing operations (buffered println) worth
   it, and where should it live?
2. Output: writer thread per output vs. transfer jobs on the shared worker
   pool. Consider flush points (64 KiB, before stdin read, idle, newline on
   a terminal, before Process.runAttached, stop/exit), late error detection
   (ADR 0045), backpressure, and tests with captured output.
3. Cancellation + stop procedure + lent resources + deadlock detection:
   with completions split into "task result" and "returned resources",
   and tasks recording their owning `handle` (R03), list the state
   combinations that can still go wrong (e.g. cancelled task whose worker
   still holds a file, stop procedure waiting on a worker while deadlock
   detection runs, a `handle` exiting while descendant tasks wait). Propose
   the minimal state machine (task states x resource states) we should
   write down and test.
4. Q6: Lazy with three states in the heap object (before / in progress with
   thunk, evaluating task and waiters / done), reverting to "before" on
   cancellation, stop and E-DropRel through one per-frame-kind unwind
   function. Any hole? Does a Lazy waited on by another task need anything
   beyond counting it as a waiting task for ADR 0238 deadlock detection?
   Should the waiter list be GC-traced or rely on the task table?
5. Among OPEN-062 R01-R05, R13, R14: which ones does the design above make
   structurally impossible, which still need a reproduction test, and
   which do you think are not real problems? Be brief.

## Output format

- Numbered sections matching the questions, then "Other issues" (short).
- For facts about other implementations or libraries (Tokio, libuv, mio,
  Go), state confidence and where to verify.
- Keep the whole answer under about 2,000 words.
````

## 検証者の回答（そのまま）

回答の中のリンクは、検証者が書いた絶対パスのまま残す。

1. **Q5：条件付きで賛成。R02 を防ぐのは、単一の列と、それを必ず処理するスケジューラの規則である。**

[5b の記述](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/03-options.md:250)にある「切替点で列が空でなければ VM から戻る」を必須にすれば、R02 の未送出は防げる。次の不変条件まで明記したい。

- タスクを `Waiting(request_id)` にしてから要求を公開する。即時完了でも、この順序を守る。
- 実行可能なタスクが残っていても、切替点で要求を送り出す。完了の取り込みも行い、計算を続けるタスクによって応答が放置されないようにする。
- IO 実行器は、外部操作の終了を待って VM 全体を止めず、操作を開始して VM に制御を戻す。

**Freer モナドとしての読み方は保たれる。** 要求が操作を表し、対応するタスクの保存済みの枠が継続を表す。要求と応答の方式で、その操作を外側の実行器が解釈して継続を再開するならよい。列そのものには継続がないため、要求と保存した継続との対応は明示する。

対象は、言語のハンドラで処理されなかった組み込みのエフェクト操作に限る。純粋な組み込み関数や `Reference.get/set` まで待たせると、現在の不可分性の規則を変えてしまう。

即時完了の最適化は、測定で費用が確認されてからでよい。置くなら送り出しの部品に置き、同じ待ち登録・ハンドラ呼び出し・完了処理を使って、その場で再開する。論理上の待ちに、別タスクの実行を伴わせる必要はない。要求と応答の方式では、`println` だけ VM 内で実行する近道は設けない。

**主なリスク：** 要求の送出だけ直して完了の取り込みを忘れることと、即時完了後に待ち状態を上書きすること。**テスト：** R02 の A=`File.readText` 後にセル更新、B=セルを末尾再帰で監視、を両方式で実行する。制御可能な IO 実行器で、即時完了と、B の実行中に到着する完了の両方を確かめる。

2. **出力：出力ごとの writer thread に賛成。共有 worker pool より、転送が進む条件を少ない規則で定められる。**

stdout/stderr ごとに直列の writer を置けば、出力順序を保てる。有限の共有 pool では、入力待ちや外部コマンド待ちで全 worker が埋まり、転送ジョブが開始できない場合がある。これを防ぐ専用の実行枠を追加するなら、今回の writer thread に近い構成になる。負担は、実行ごとのスレッド生成と終了処理である。

転送契機は、**転送の依頼**と**先行出力の完了待ち**に分ける。

| 契機 | 必要な動作 |
|---|---|
| 64 KiB、idle、端末への改行 | 転送を依頼する。VM は進める。idle 時はイベント待ちに入る前に依頼する |
| stdin 読み取り前、`Process.runAttached` 前 | その時点までの出力の完了通知を待ってから、読み取り・子プロセス起動を始める |
| stop/exit、通常終了 | 最後の転送と失敗確認を終えてから実行結果を返す |

完了待ちは、対象時点までの出力に対するものとする。他タスクが後から追加する出力まで待ち続ける必要はない。待つ間も VM のイベント処理と中断確認を続ける。

Backpressure は VM のバッファだけでなく、writer の列と転送中の量も数える。上限に達した後の書き込みは、追加前に待たせる。追加してから待つだけでは、多数のタスクがそれぞれ上限を超過できる。超過を許すなら、一回の不可分な書き込み分までと明記する。受理済みの出力は、そのタスクの取り消しでは撤回しない。

失敗は出力ごとに保持し、次の書き込み・転送時、遅くとも終了前に観測する。失敗時には容量待ちと転送完了待ちを解除する。失敗の記録と通知を、書き込んだタスクの寿命に依存させないことが、[現在の遅延検出の規則](/Users/tecogonaz/src/Benitoite/docs/design/02-impl/02-09-runtime.md:252)を保つ条件である。

**主なリスク：** 転送の依頼を完了と扱うこと、満杯の channel への送信や `join` で VM を止めること。**テスト：** 転送を止められる出力先で、stdout が詰まっても stderr・タイマー・中断が進むことを確かめる。各転送契機、最後の書き込み後の失敗、捕捉出力を取得する前の完了待ちも検査する。メモリへの捕捉でも同じ転送・完了の手順を使い、常に即時成功する代替だけで済ませない。

3. **取り消し・停止・貸出：方向に賛成。ただし、タスクの寿命と外部操作の寿命を分ける必要がある。**

タスクは `Ready`、`Waiting(reason)`、`Unwinding(cause, cursor, wait)`、`Done`。資源は `Open`、`Lent(op_id, close_requested)`、`Releasing(op_id)`、`Released` とすれば足りる。`Unwinding` は解放待ちでも辿っている枠を保持し、同じ枠を二度解放しない。

| 組み合わせ | 必要な遷移・制約 |
|---|---|
| `Waiting(op)` × `Lent(op, false)` | 完了で資源を表へ戻してから、タスクへ結果を渡す |
| `Unwinding` × `Lent(op, true)` | 返却まで待ち、返却後に解放する。新たな貸出は受け付けない |
| `Waiting` / `Unwinding` × `Releasing` | 完了で元の処理を再開する。取り消し済みタスクを通常実行へ戻さない |
| 操作待ち × `Released` | 待ちを解除して、解放済み資源の使用として処理する |
| `Done` × `Lent` | 借りたタスクと解放責任を持つタスクが別ならあり得る。操作記録は残す。自身の解放が未完了なら `Done` にしない |

外部操作の記録は `op_id` で管理し、タスクへの結果配送を取り消しても消さない。完了の共通処理は、まず返却欄を処理し、その後で「このタスクがこの操作の結果をまだ待っているか」を調べる。この順序なら、結果の変換に失敗した場合も返却を失わない。

`handle` は、本体が終わり、所属する未終了タスクがゼロになるまで保持する。正常終了を待つ途中で子が孫を起動しても、同じ所有者へ登録する。登録は親を終了扱いにする前に行う。継続を捨てる場合は子孫を取り消し、解放終了まで記録を残す。全体停止では、`TaskGroup` と同様に `handle` も子孫の終了を個別に待たず、全タスクを停止手順で処理する。

[ADR 0238 に対応する判定](/Users/tecogonaz/src/Benitoite/docs/design/02-impl/02-08-vm.md:217)には、資源返却・解放・出力の完了待ちも含める。要求と未処理の完了を処理してから、実行可能な処理と外部の完了待ちがなく、内部で待つタスクが残っているかを調べる。全体停止中には通常の行き詰まりエラーを再発生させて、元の停止理由を置き換えない。

**主なリスク：** 貸出中なのに操作記録を消すこと、解放要求後の再貸出、古い完了によるタスクの復活、`handle` の早すぎる破棄。**テスト：** 取り消しと完了の順序を入れ替え、返却と解放が一度ずつ行われることを確かめる。貸出中の全体停止、解放の失敗、外側の `TaskGroup` を使う A→B の孫タスクを含む `handle` の正常終了・継続破棄も再現する。

4. **Q6：三状態と枠の種類ごとの unwind に賛成。全体停止時の起床方法に修正が必要である。**

`Before(thunk)`、`Evaluating(thunk, owner, waiters)`、`Done(value)` で足りる。キャンセルと E-DropRel では、`Before` に戻してから有効な待ち手を起こし、再度 `FORCE` させる。正常完了では、`Done` にしてから起こす。

ただし、**全体停止中には待ち手を通常実行へ戻さない。** [現在の記述](/Users/tecogonaz/src/Benitoite/docs/design/02-impl/02-08-vm.md:160)をそのまま共通化すると、止めている途中に thunk を再評価できてしまう。共通 unwind は停止理由を受け取り、全体停止では停止状態を保つ必要がある。捕捉した継続内の `update` 枠にも同じ処理を適用する。

ADR 0238 のために、`Lazy` 専用の依存関係グラフは不要である。`Lazy` 待ちは内部の待ちとして数え、外部の完了待ちには数えない。評価者の取り消しで待ち手が起こされることと、評価者の更新枠が失われないことは別途必要である。

待ち手の並びは、**所有しない `TaskId`** を推す。未終了タスクはタスク表が根として保持し、待つタスク自身は待ち先の `Lazy` を保持する。`Lazy` 内の thunk・結果は GC の追跡対象とし、`TaskId` は追跡しない。番号を再利用するなら世代を検査する。タスクへの強い参照を並べる方式は、参照カウント案で循環を作りやすい。

**主なリスク：** 取り消した待ち手への通知、失効した更新枠による上書き、GC 時の待ち先の消失。**テスト：** 二タスクが同じ `Lazy` を force し、評価者だけを取り消して残る待ち手が完了する場合、待ち手だけを取り消す場合、全体停止、E-DropRel を確かめる。待機中の safepoint を挟み、両メモリ管理案で保持と回収を確認する。

5. **OPEN-062：R02〜R05 は条件付きで構造的に防げる。R01・R13・R14 は再現確認が残る。**

[対象の反例](/Users/tecogonaz/src/Benitoite/docs/design/open-issues.md:1005)を、今回の提案との関係で分類すると次のとおりである。

| 項目 | 判定 |
|---|---|
| R01 | 今回の機構では除けない。切替順による値・停止の違いを再現し、純粋性の保証との整合を確認する。関連する、`Clock.Time` を除いた `Task.race` も型の確認が必要 |
| R02 | 要求送出と完了取り込みを必須にすれば構造的に防げる。両方式で一つの回帰テストを残す |
| R03 | 全起動・終了・取り消しが所有者の共通管理を通れば防げる。所有者番号を持つだけでは足りない |
| R04 | 出力先への転送と、満杯時の制御が VM をブロックしなければ防げる。止めた出力先で確認する |
| R05 | 資源返却を結果配送より先に共通処理すれば防げる。取り消しと完了の交差を確認する |
| R13 | stdin 前のプロンプトは改善する。パイプへ準備完了の行を書いた後、別タスクが計算を続ける場合は、端末改行・idle の条件では転送されない。再現テストの実行順序に依存する |
| R14 | 入力の解釈の問題であり、今回の機構では除けない。`%FF`、`%G0`、UTF-8 でないヘッダの受信結果を確認する |

現時点で、項目全体を「問題ではない」と断定できるものはない。ただし、取り消し後も worker が外部操作を続けることや、ブロック中の操作の返却を解放が待つこと自体は、固定された仕様に沿う。

**Other issues**

worker の panic でも返却欄を作れるよう、貸した資源を `catch_unwind` の外側で保持する構成を確認したい。また、[現行の出力規則](/Users/tecogonaz/src/Benitoite/docs/design/02-impl/02-09-runtime.md:238)には「書き込みは待たない」「VM で転送する」が残っている。採用時には、取り消し時の「結果を捨てる」という記述と併せて、今回の状態遷移に揃える必要がある。

## 要点

1. **要求の置き場を一つにする形（5b）に条件付きで賛成。** R02 を防ぐのは列そのものではなく、「タスクを待ちにしてから要求を公開する」「進められるタスクが残っていても切り替えの位置で要求を送り出し、完了を取り込む」「IO 実行器は外部の操作の終わりを待って VM を止めない」という規則である。Freer モナドとしての読み方は保たれるが、要求と保存した継続の対応を明示する。列に置くのは、言語のハンドラで処理されなかった組み込みのエフェクトの操作に限り、純粋な関数や `Reference` の操作は待たせない。すぐ完了する操作の近道は、測ってから、送り出しの部品の中に置く。
2. **出力ごとの書き出し用のスレッドに賛成。** 共有の作業用のスレッドでは、入力待ちなどで全部が埋まると転送が始まらない。転送の時点は「依頼するだけ（64 KiB、進めるタスクがないとき、端末の改行）」と「それまでの出力の完了を待つ（標準入力を読む前、`Process.runAttached` の前、終わる前）」に分ける。上限は書き出しの列と転送中の量も数え、加える前に待たせる。
3. **取り消し・止める手順・貸し出しは、タスクの寿命と外部の操作の寿命を分ける。** タスクは `Ready`・`Waiting`・`Unwinding`・`Done`、リソースは `Open`・`Lent`・`Releasing`・`Released` の状態で足りる。外部の操作は番号で記録し、タスクへの結果の配送を取り消しても消さない。完了の共通の処理は、先に返却の欄を処理してから、タスクがまだ結果を待っているかを調べる。`handle` は、本体が終わり属するタスクが 0 になるまで残す。行き詰まりの判定には、返却・解放・出力の完了の待ちも含める。
4. **`Lazy` の三つの状態と、枠の種類ごとの降ろす処理に賛成。ただし止める手順の途中では、待っているタスクを通常の実行に戻さない**（戻すと、止めている途中に本体を評価し直せてしまう）。待つタスクの並びは所有しないタスクの番号とし、GC では辿らない。
5. **OPEN-062**: R02〜R05 は、上の規則を共通の部分で必ず行えば構造上起きない（両方式の回帰テストは残す）。R01・R14 は今回の仕組みでは除けないので、再現を確かめる。R13 は改善するが、パイプに準備完了の行を書いた後で別のタスクが計算を続ける場合は、端末の改行と「進めるタスクがない」の条件では転送されないので、再現を確かめる。

その他: 作業用のスレッドが panic しても返却の欄を作れるよう、貸したリソースを `catch_unwind` の外で持つ。設計書 02-09 の出力の規則（「書き込みは待たない」「VM で転送する」）は、採るときに今回の形に揃える。

## 本資料への反映

- [03-options.md](../03-options.md) の Q5・Q6 の暫定の推奨に、上の規則と状態を加えた。

## 一次資料で確かめる事実

- なし（今回の回答は外部の処理系の事実に頼っていない）
