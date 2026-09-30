# 相談 第 6 回: 実装プランの VM とハンドラの部分のレビュー

- 状態: 反映済み（下記の「本資料への反映」）
- 対象: 10-09（VM）の枠と区画・振り分けのループ・ハンドラ・枠を降ろす処理と、作業 R09・R20・R21 の文書

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 12:46:05〜12:54:01（約 8 分） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 渡した資料 | 依頼文（英語 約 520 語）。10-09 の行の範囲と R09・R20・R21 の全文（計 約 1,060 行）を一度のコマンドで読ませ、その後の読み取りを 2 回までとした |
| 問いの数 | 6 |
| トークン | 入力 173,865（うちキャッシュ 112,640）、出力 15,359（うち推論 11,574） |
| 検証者が実行したコマンド | 6 回 |
| レートの減り | 83% → 68%（15 ポイント。設計者の報告） |

## 送った依頼文

````text
You are reviewing part of the implementation plan for the runtime redesign of
"Benitoite" (a small statically typed functional scripting language written
in Rust). In earlier rounds you reviewed the design (frames and continuations,
dispatch loop, unwinding) and the heap part of this plan. The plan freezes
Rust types and splits work into tasks for LLM coding agents. You can read the
repository but must NOT modify files or call other tools/agents. Answer in
Japanese; keep identifiers and code in English.

## Reading budget (important)

Every tool call re-sends the whole conversation. Read the review target with
exactly ONE shell command, this one:

    f=docs/implement/10-interfaces/10-09-vm.md; sed -n '220,650p;885,1106p' $f; for t in docs/implement/20-tasks/R09-vm-core.md docs/implement/20-tasks/R20-handlers-and-continuations.md docs/implement/20-tasks/R21-unwinding-and-stop.md; do echo "=== $t"; cat $t; done

Then answer. Use at most 2 further reads, only if a finding truly depends on
it (e.g. docs/design/decisions/0262, 0263, 0267, 0280, or 10-07's instruction
table). Do not read Rust sources.

## Fixed decisions (not up for debate)

Segments own a Vec of call frames, a Vec of wrapping frames (release, update,
cell restore, handle, drop) tagged with depth = number of call frames below at
push time, and a register Vec; one-shot continuations move segments. Dispatch
loop keeps proto/pc/window base in locals (9b); bounds-check skipping (9c) is
deferred. A per-task call budget doubles as a notification for cancellation
and collection requests (remaining budget saved and restored); the interrupt
flag is read Relaxed on every call. Safepoints: calls, tail calls, return
chains and cleanup points, where all live values are in VM-owned root slots.
Frame unwinding is one function per frame kind taking the cause (Return,
Cancel, DropRel, GlobalStop) per a cause x kind table; global stop does not
wake Lazy waiters. Scheduler and resource table live in RunState. CONR
reuses a dead unique object (ADR 0280).

## Questions

1. Frame/segment model: can the depth tagging, RETURN order (own release
   frames, own call frame, own wrapping frames), tail calls, and segment moves
   for handle/resume/drop produce a wrong top-down order or a lost/duplicated
   unwind? Give a concrete instruction sequence if so.
2. Safepoints in the VM: at each place R09/R20/R21 collect or switch, is every
   live value in a root slot (including values held in dispatch-loop locals,
   in-flight call arguments, return values during return chains, handler
   clause arguments, continuation state while moving segments)?
3. Unwinding: is the cause x frame-kind table complete and consistent
   (nested drop inside a captured continuation during GlobalStop, unwinding
   that must wait for a resource return and resumes later, cancellation
   arriving during DropRel)? What state must survive a wait?
4. Budget/request notification with tail calls and return chains; handler
   clause invocation as an implicit call.
5. Task split R09/R20/R21: ordering, hidden dependencies, tests that would not
   catch a real bug (the stage-1 VM is tested with hand-built bytecode until
   the new frontend exists), missing tests.
6. Anything over-engineered that can be cut.

## Output format

Findings list, most severe first: file + heading/line, problem, concrete
fix, severity high/medium/low. Then "Looks fine" in at most 5 lines. Keep the
whole answer under about 2,000 words. Do not restate the documents.
````

## 検証者の回答（そのまま）

1. **high — [R20-handlers-and-continuations.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md)「`RETURN` の包む枠の処理」、[R21-unwinding-and-stop.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R21-unwinding-and-stop.md)「E-DropRel」「`ESCAPE`」：待機後に戻り処理を再開するための状態が足りない。**

   R20 は戻る値を保存するが、戻り先を持つ `CallFrame` は包む枠の処理前に降ろす。R21 は E-DropRel 完了後に「節の呼び出しの枠の `ret`」へ値を入れるとしているものの、その枠は既に存在せず、`Drop` と `UnwindWork` にも戻り先はない。

   具体例は `HANDLE → PERFORM → clause RETURN → DropRel → release Wait` である。待機を挟むと、Rust の局所変数に退避した `ret` では足りない。さらに戻る値を単一の `RunState` の欄に置いたまま別タスクを動かすと、そのタスクの戻り値で上書きされる。

   **修正:** 戻る値の `Slot`、戻り先の区画とレジスタ、戻り処理の段階、診断用の命令位置、完了後の動作を、タスクごとの再開状態として保存すると明記する。R25 が移す対象にも含める。完了後の動作で通常の戻りと `ESCAPE` の継続を区別すれば、`resume_after` と別立ての「値を入れない印」も整理できる。解放待ち中に別タスクが値を返すテストが必要である。

2. **high — [R21-unwinding-and-stop.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R21-unwinding-and-stop.md)「全体の停止」「辿り方」：既に巻き戻しているタスクを全体停止へ移す規則がない。**

   全体停止の手順は各タスクの積み重ねを `UnwindWork` に移すが、既に `DropRel` や `Cancel` で待機中なら、処理すべき区画は既存の `UnwindWork` 側にもある。それを新しい仕事で置き換えると、未解放の区画と解放失敗の記録を失う。また、辿りは区画ごとの原因を使うため、`UnwindWork::cause` だけを `Stop` に変えても不十分である。

   例えば、捕まえた継続の解放待ち中に別タスクが停止原因を発生させ、残った区画を `DropRel` のまま辿ると、`update` が Lazy の待機者を起こしたり、`handle` が子タスクの終了を待ったりする。

   **修正:** 既存の辿り位置・区画・解放失敗・開始済みの解放状態を保って停止へ移行し、残るすべての区画の原因を `Stop` に変更する。通常実行への復帰を無効にし、既存の待機理由も停止時の規則で再評価する。`DropRel` 中の取り消しは、要求を保存し、どの許された位置で適用するかを定める。GC のための後始末の位置から取り消しへ進まない、という固定方針はそのままでよい。

3. **high — [R20-handlers-and-continuations.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md)「`PERFORM` …（E-Op）」手順 4：区画を切り離した後の失敗で、巻き戻す対象を失える。**

   手順 4.2 で区画を切り離して継続を作り、4.3 で `drop` と節の呼び出しに必要な上限を確かめる順序になっている。`HANDLE → USE r → PERFORM op` で、節の枠と窓を追加する余裕だけがない場合、切り離した後に `CallStackTooDeep` になる。継続がまだ VM の巻き戻し対象に登録されていなければ、停止時の積み重ねから `r` の解放枠が消える。GC の根へ保存するだけでは、リソースの解放順までは保証できない。

   **修正:** 節の原型を調べ、追加する枠と窓の上限を、区画の切り離し前に確かめる。残る失敗箇所についても、元の積み重ねか、停止時に辿れる移動先のどちらかが必ず区画を所有する手順を定める。上限直前で `PERFORM` し、停止時に捕獲対象のリソースが一度だけ解放されるテストを R24 へ引き渡す。

4. **medium — [R09-vm-core.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R09-vm-core.md)「命令ごとの処理」「切り替えの位置と回収の位置」、[R20-handlers-and-continuations.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md)「`PERFORM`」：呼び出し前の安全点から、どの段階へ復帰するかが未定義である。**

   `LoopLocals::save/load` は命令位置を保存するだけで、呼び出し前の遅い経路をどこまで実行したかは保存しない。例えば `CALL` を取り出して `pc` を次へ進め、呼び出し前に `Collect` で抜ける実装では、再開時に `CALL` を飛ばす。逆に命令を丸ごと再実行すると、処理済みの予算を再度消費し得る。`TAILCALL` の `LastUse` 引数を先に `take` していた場合は、引数の保存も必要になる。

   **修正:** 呼び出し前の検査、回収・切り替え、引数の移動、呼び出しの成立について順序と再開位置を固定する。安全点までは関数と引数を既存の根に保ち、成立前の命令を飛ばさず、予算は一度だけ数える。引き継いだハンドラの直接実行も同じ呼び出し処理を通すと明記する。R20 の手順 5 には手順 4.1 に相当する検査が明記されておらず、「普通の呼び出し」の解釈に依存している。

   テストには、定数表に残らないヒープ上の引数とクロージャ、`LastUse`、窓の拡大・縮小を伴う `TAILCALL` を使い、呼び出し直前に回収を要求する。結果だけでなく、呼び出し回数と予算も確かめる。

5. **medium — [R20-handlers-and-continuations.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md)「`RETURN` の包む枠の処理」、[R21-unwinding-and-stop.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R21-unwinding-and-stop.md)「辿り方」：降ろした枠自身の `Slot` を捨てる責任が不明確である。**

   手順は窓のレジスタの `clear` と枠の `Vec` からの除去を記すが、`CallFrame::func`、`HandleFrame::record`、`Drop::cont` などの処理を記していない。R09 が明記するように、これらを Rust の `drop` だけで捨てると参照カウントを戻せない。`unwind_handle` などは枠を共有参照で受け取るため、呼び出し側との責任分担が特に重要になる。

   **修正:** `Popped` は「種類ごとの処理が完了した」と定義し、呼び出し側が枠を取り出して、その所有する `Slot` を `NoGcCtx` 経由で一度だけ破棄し、計数を減らす、と統一する。`Traverse` では移動した区画を破棄しない。枠だけが保持していたクロージャの捕捉値が、戻り・停止後に残らないことを両方式で確かめる。

6. **medium — [R20-handlers-and-continuations.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md)「受け入れテスト／長い繰り返し」：正しい実装でも満たせない定数空間の要求がある。**

   本体が `PERFORM; TAILCALL loop` を繰り返し、節が `RESUME; ADDI; RETURN` を実行する場合、各 `RESUME` の後に加算が残る。その節の呼び出し枠と `drop` 枠は、再開した本体が完了するまで保持しなければならない。したがって「継続を保存して再開する節」まで含めて、100 万回を 1 MiB で完走させる要求は成立しない。[コア計算の「末尾呼び出しの保証の読み替え」](/Users/tecogonaz/src/Benitoite/docs/design/01-spec/01-12-core-calculus.md:687)も、この種の継続の増加を許している。

   **修正:** 定数空間のテストは、各反復で `handle` と節が完了してから次の反復へ末尾呼び出しする形にする。再開後の計算を蓄積するケースは、少数回の正しい結果と上限エラーを検査する。引き継いだハンドラの直接実行の反復は R25 で別に検査する。

7. **medium — [R20-handlers-and-continuations.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md)「依存する作業」「受け入れテスト」、[R21-unwinding-and-stop.md](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R21-unwinding-and-stop.md)「受け入れテスト」：テストの前提と後続への引き渡しを具体化する必要がある。**

   R20 は原則としてスクリプトを新しいパイプラインと `run_program` で実行するとしているが、依存する R14・C02 だけでハンドラの構文から実行までが利用可能になることは、この計画では保証されていない。R21 の「解放枠を模した枠の順序」も、実際の解放待ち、再入時の二重解放、原因の変更を検査できない。

   **修正:** R20・R21 の完了を判定するテストは、必要な frontend が揃うまで `bytecode::asm` と VM の実行入口で成立させる。スクリプトによる統合テストは、それを利用可能にする作業へ割り当てる。併せて R24・R25 に、実際の `Wait` を挟む一度だけの解放、`DropRel` 中の取り消し、既存の巻き戻し中の全体停止を、受け入れ条件として明示的に引き渡す。

Looks fine

- 深さ `d ≥ c` の比較と同じ深さでの枠の順序は整合しており、通常の `RETURN` が呼び出し元の解放枠を越える反例はない。
- 区画内の相対位置を維持する移動は、深さの付け替えを必要としない。
- 原因×枠種の表自体は整合している。全体停止で入れ子の `drop` に `Stop` を伝え、Lazy の待機者を起こさない規則も正しい。
- 予算の退避・復元と、戻りの連鎖・後始末で予算とは別に回収要求を調べる構成は妥当である。

## 本資料への反映

7 件の指摘をすべて採った。指摘と変えた箇所の対応は次のとおりである。10-07 と 10-10 は変えていない（命令の表とスケジューラの型に及ぶ指摘はなかった）。作業の依存は変わらないので、README の作業一覧も変えていない。

| 指摘 | 変えた箇所 | 変えた内容 |
|---|---|---|
| 1 待ちをまたぐ戻りの状態 | 10-09「実行ごとの状態」「タスク」「戻りの再開状態」（新設）、`unwind.rs` の `ReturnWork`・`ReturnStage`・`ReturnDest`（新設）、`TaskObj::returning`（新設）、`UnwindWork::resume_after`（削除）、R20「`RETURN` の包む枠の処理」、R21「E-DropRel」「`ESCAPE`」、R22・R23 の `Return` の行、R25「タスクの対象と実行中のタスク」、02-08「実行の手順」の `RETURN` | 戻る値、戻り先、段、診断の命令位置をタスクごとの `ReturnWork` に置き、R25 が切り替えで移し合う。通常の戻りと `ESCAPE` の続きは段（`Wrapping`・`Escaping`）で区別し、`resume_after` と「値を入れない印」をやめた。`unwind_handle` の `Return` は値を入れず、戻りの処理が段に従って入れる。待ちの間に別のタスクが値を返すテストを R25 に置いた |
| 2 巻き戻し中のタスクの全体の停止 | 10-09「既に枠を降ろしているタスクの扱い」（新設）と `UnwindWork::escalate`（新設）、R21「全体の停止」、R25「取り消し」「止める手順」、02-08「取り消し」「止める手順」 | 辿る位置・区画・`log` を保ったまま、残りの区画と積み重ねの原因を `Stop` に改める。子のタスクの終わりの待ちは外し、解放の枠の待ちは残す。E-DropRel の途中の取り消しは記録だけにし、辿り終えた時点で通常の実行に戻らずに取り消しへ移る。後始末の回収の位置から取り消しと停止へ進まないことを明記した |
| 3 `PERFORM` の切り離しの後の失敗 | R20「`PERFORM`」手順 4・5、R24 の受け入れテスト | 節の関数の値と上限を切り離しの前に確かめる。切り離しから `drop` の枠を積むまでに失敗しうる処理を置かず、どの時点でも区画を元の積み重ねか `drop` の枠から辿れる継続が所有するようにした。上限の直前の `PERFORM` で解放が一度だけ行われるテストを R24 へ引き渡した |
| 4 呼び出しの前の安全点の再開の位置 | 10-09「呼び出しの前の安全点」（新設）と手順の表、`TaskObj::precall_done`（新設）、R09「命令ごとの処理」「切り替えの位置と回収の位置」、R20 の `HANDLE`・`PERFORM`、R22 の `FORCE`、R23 の `UPDATE` と `Retry` | 上限 → 切り替えの位置の処理 → 呼び出しの成立の順に固定し、安全点までは関数と引数をレジスタに残す。回収・切り替えの後は命令を初めから実行し直し、「安全点を通った命令」の印で切り替えの位置の処理を飛ばして予算を一度だけ数える。引き継いだハンドラの直接の実行も同じ呼び出しの処理を通す。R09・R20 に、ヒープの引数とクロージャ、`LastUse`、窓を変える `TAILCALL` で呼び出し回数と予算を確かめるテストを置いた |
| 5 降ろした枠の `Slot` を捨てる責任 | 10-09 の手順の表の「降ろした枠の `Slot`」の行と「枠を降ろす原因と処理」の結果ごとの受け持ち、`UnwindStep` の説明、R09・R20・R21・R24 | `Popped` は種類ごとの処理の完了を表し、呼び出し側が枠を取り出して `NoGcCtx::discard` で一度だけ手放す。`unwind_drop` が継続を使用済みにして区画を返し、`Traverse` で受け取った区画は手放さない。枠だけが持つクロージャの捕捉が戻り・停止の後に残らないテストを R09・R20・R21 に置いた |
| 6 成り立たない定数空間のテスト | R20「受け入れテスト」、R25「受け入れテスト」 | 定数空間は各反復で `handle` と節が終わる形に限った。再開の後に計算を積む節は、少ない回数の結果と上限のエラーを確かめる。引き継いだハンドラの直接の実行の繰り返しは R25 で確かめる |
| 7 テストの前提と引き渡し | R20・R21「受け入れテスト」、R21「後の作業へ引き渡すテスト」（新設）、R24・R25「受け入れテスト」 | 完了を判定するテストを `bytecode::asm` と VM の実行の入口で行い、スクリプトの統合テストは追加とした（フロントエンドは R14 を通じて揃っている）。実際の `Wait` を挟む一度だけの解放、E-DropRel の途中の取り消し、既に辿っているタスクの全体の停止を、R25 の受け入れテストとして引き渡した |

あわせて、第 5 回のレビューで残った「R03 の根の置き場ごとの回収の強制のテストが第 2 段の作業にない」ことを直した。R03「根の列挙の引き渡し」の表に戻りの再開状態の行を加え、`UnwindWork` の行の待ちをまたぐ確かめを R25 に移した。R20（`handle` の枠、`drop` の枠と継続、`ReturnWork`）、R21（`UnwindWork` の区画、E-DropRel の間の `ReturnWork`）、R22（`update` の枠、`Before` の本体）、R23（セルの更新の枠、`ReturnWork`）、R25（タスクの対象の各欄、待ちをまたぐ `UnwindWork` と `returning`）、R26（待つ組み込みの関数の引数）の受け入れテストに、その置き場だけに値が残る状態で回収を強制するテストを加えた。

設計書（02-08）には、既存の決定から導ける規則として次の三つを【方針】で加えた。`RETURN` の処理が待つときに戻る値・戻り先・段をタスクごとに保つこと（「実行の手順」）、取り消しの要求が E-DropRel の途中と解放の待ちの間に届いたときの扱い（「取り消し」。ADR 0266 の決定 5 から）、既に枠を降ろしているタスクを全体の停止へ移すときの扱い（「止める手順」。ADR 0266 の決定 1 と ADR 0267 の決定 4 から）。

取り消しの要求が E-DropRel の途中に届いたときの扱いは、2026-09-30 に設計者が【決定】とした（[ADR 0282](../../../../design/decisions/0282-cancellation-timing-during-unwinding-and-requests.md) の決定 1）。
