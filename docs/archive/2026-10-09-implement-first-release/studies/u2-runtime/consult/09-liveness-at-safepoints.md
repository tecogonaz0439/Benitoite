# 相談の第 9 回: 使わなくなったレジスタを回収の安全点で空にする案（ADR 0314・R16）

- 日付: 2026-10-05
- 相談先: GPT-6.1-Sol（Codex、推論の度合い high、読み取りだけ）
- 結果の反映: ADR 0314 の決定 4・5 と帰結、R16 の手順 3・受け入れテスト・性能の確かめ方

## 依頼文

あなたは Benitoite（Rust で実装する関数型スクリプト言語の処理系）の設計の相談相手である。ファイルを変更しない。cargo を実行しない。リポジトリは /Users/tecogonaz/src/Benitoite（ブランチ san_benito）。日本語で答える。

以前の相談（docs/archive/2026-10-09-implement-first-release/studies/u2-runtime/consult/08-vm-performance.md の回答の 1）で、あなたは「命令ごとの take/clear を回収の安全点へ移す案はマーク・スイープなら妥当だが、安全点ごとの生きている集合が要る、根は pc だけで決まらない、Unit にする形がよい」などの条件を挙げた。それを受けて、次の二つを起草した。

- ADR 0314（提案）: docs/archive/2026-10-09-design-first-release/decisions/0314-clear-dead-registers-at-safepoints.md
- 作業文書 R16: docs/archive/2026-10-09-implement-first-release/20-tasks/R16-liveness-at-safepoints.md
- 生存の情報の型の改め: docs/archive/2026-10-09-implement-first-release/10-interfaces/10-07-bytecode.md の file=src/bytecode/liveness.rs（LiveInfo に live_in_starts・live_in・call_writes を加えた）

背景の数値: R15 の後の VM は最小実行版の VM に fib(35) 2.71 s 対 2.05 s、loop 1.73 s 対 0.995 s で届かない。命令ごとの生存の情報の処理が fib 21%、loop 31%（処理を外した版との差）。

実装の事実（読んで確かめてよい）: crates/benitoite/src/vm/dispatch.rs（run_epoch、call、RETURN の処理、cleanup）、vm/stage1.rs（LoopExit::Collect で Heap::collect）、vm/frame.rs（Segment::trace はすべての regs を辿る）、bytecode/liveness.rs（compute_liveness は live_in・live_out を求めている）。呼び出し元の枠の pc は、呼び出しの命令の次を指して保存される。回収は、呼び出しの前の安全点（予算が尽き回収の要求があるとき。枠の pc は呼び出しの命令、印 precall_done）、RETURN の後（戻り先の枠が最も上、結果は書き込み済み）、止める手順の途中でだけ起きる。

問い:
1. ADR 0314 の決定 3 の規則（タスクの最も内側の枠は live_in(pc)、ほかの枠は命令 pc−1 が呼び出しの命令なら live_in(pc) から結果のレジスタを除く、それ以外は保守的に残す）は安全か。空にしてはいけないレジスタを空にする反例があれば挙げる（第 1 段の VM の範囲と、第 2 段のハンドラ・継続・タスク・待ちで起きうるもの）。精度の面で大きな取りこぼしがあれば挙げる。
2. 呼び出しの命令の一覧（CALL・METHOD・HANDLE・FORCE・UPDATE・PERFORM・IO・RESUME）は妥当か。10-07 の命令の意味（docs/archive/2026-10-09-implement-first-release/10-interfaces/10-07-bytecode.md）と 10-09 の枠の規則（docs/archive/2026-10-09-implement-first-release/10-interfaces/10-09-vm.md）と照らして、結果を書いてから次の命令で再開しない命令が混じっていないか、漏れがないか。
3. live_in を命令ごとに持つ形と call_writes の形で、R20〜R25 の作業が困らないか。足りない情報があるか。
4. R16 の作業文書で、実装担当が誤りやすい点、受け入れテストの不足、性能の確かめ方の不足があれば挙げる。
5. 回収の時に全枠のレジスタを走査する費用（深い再帰で回収が多い場合）について、注意すべきことがあれば挙げる。

重要な指摘から順に、根拠のファイルと行を添えて、80 行以内で答える。

## 回答

**第 1 段の現在の回収経路では、決定 3 は安全であり、必要なレジスタを消す反例は見つからなかった。第 2 段まで適用するには、pc の更新と枠の状態の分類を補う必要がある。** 重要度順に指摘する。ファイル変更と cargo の実行は行っていない。

1. **第 2 段の `HANDLE`・`RESUME` では、呼び出し元の pc を進める手順を明記する必要がある（問い 1・4）。**
   R20 は「局所の状態を書き戻す」としており、両命令で pc を次へ進める記述がない。文字どおり実装すると、`CALL r0 …; RESUME r2 …; USE(r0)` で、再開した本体の回収時に節の保存 pc が `RESUME` を指し、pc−1 の `CALL` の結果 r0 を消してしまう。`HANDLE` でも同じ反例が成立する。
   **呼び出し成立時に pc を次へ進め、保存までを回収なしで行う**ことを明記すれば、この反例はなくなる。根拠：[R20:63](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md:63)、[R20:95](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md:95)。

2. **待ちの完了では、結果の書き込みと pc の更新を一続きにする必要がある（問い 1・3）。**
   待つ間は `live_in(IO/PRIM)` で引数を残せる。しかし、完了が結果 A を書いた後も pc がその命令を指したまま回収すると、A が引数でない場合、`live_in` は A を含まず、新しい結果を消す。
   R25 の子の結果配送と 10-10 の外部完了処理には、結果を書いて起こす記述はあるが、pc の更新が明記されていない。**完了で次の命令へ進める経路と、`Task.await` のように同じ命令を再実行する経路を区別する**必要がある。根拠：[R25:109](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R25-tasks-and-scheduler.md:109)、[R25:116](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R25-tasks-and-scheduler.md:116)、[10-10:356](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-10-scheduler-and-io.md:356)。

3. **第 1 段の安全性は、実装の保存順序で説明できる（問い 1）。**
   呼び出し前は pc が呼び出し命令を指し、成立後は呼び出し元の pc が次へ進む。RETURN 後は結果を書いてから回収する。したがって、最内側の `live_in(pc)` と、下の枠の `live_in(pc) − {結果}` は必要な値を残す。停止途中は通常実行へ戻らず、残る関数の値は窓外の `CallFrame::func` が保持する。
   第 2 段の UPDATE の再試行も、セルと関数を `CellUpdate` から読む限り安全である。消した元の被演算子を読み直す実装にはできない。根拠：[dispatch:810](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:810)、[dispatch:932](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:932)、[dispatch:343](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:343)、[R23:76](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R23-reference-cells.md:76)。

4. **命令の一覧は妥当だが、「呼ばれた側が戻るときに結果を書く」という定義は `PERFORM` に合わない（問い 2）。**
   捕捉する `PERFORM`／ハンドラ付き `IO` では、節の戻り値は handle の結果となり、操作の結果 A は継続を `RESUME` したときに書かれる。捕捉継続の最上位の枠には、`live_in(pc) − {A}` を適用してよいが、通常の呼び出し待ちとは状態が違う。
   `call_writes` を「中断中の旧値を除ける、再開前に書かれる結果レジスタ」と定義する方が正確である。CALL・METHOD・HANDLE・FORCE・UPDATE・RESUME は該当する。TAILCALL・TAILMETHOD・RETURN・ESCAPE の除外は正しい。PRIM の子タスクは別タスクなので、一覧への追加は不要である。根拠：[ADR:31](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0314-clear-dead-registers-at-safepoints.md:31)、[R20:87](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md:87)、[10-07:125](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-07-bytecode.md:125)。

5. **静的情報の型は足りるが、R20〜R25 には状態別の適用表と、捕捉継続を整理する手順が必要である（問い 3）。**
   少なくとも「命令入口」「結果未書き込みの呼び出し元」「捕捉継続の最上位」「同じ命令を再実行する待ち」「完了後」「ReturnWork／UnwindWork」を区別する。pc−1 の命令だけで、その状態に該当すると推定してはいけない。
   継続の区画は Host 対象内にあり、既存の `Trace` は読み取り専用なので、`state.stack` の整理を広げるだけでは到達できない。**捕捉時に保存 pc を確定して窓を整理し、捕捉中は窓が変わらない契約**にすれば、回収前に全継続を可変走査する必要を避けられる。Host 内の整理には `SlotOps::clear` を使う記述も必要である。根拠：[ADR:30](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0314-clear-dead-registers-at-safepoints.md:30)、[10-09:1000](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-09-vm.md:1000)、[ctx:569](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/runtime/heap/ctx.rs:569)。

6. **R16 の受け入れテストには、連続する呼び出しと、回収後の上書きを加える価値がある（問い 4）。**
   前の CALL の結果を次の CALL の引数にし、その呼び出し前で回収する例は、最内側にも結果除外を適用する誤りを捕まえる。回収した死んだレジスタを後で上書きする例は、根から除くだけで Unit にし忘れる誤りを捕まえる。停止途中の回収も、R16 の対象なのに受け入れ項目には明示されていない。
   生存解析の期待集合は手で定め、解析結果自身から期待値を作らない。既存の深い戻り・重なる末尾引数のテストは再利用し、上記 1・2 の反例は R20・R25／R26 に引き渡す。根拠：[R16:70](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R16-liveness-at-safepoints.md:70)、[tests:1278](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/tests.rs:1278)、[tests:1308](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/tests.rs:1308)。

7. **R16 の実装手順では、集合の取得失敗と空集合、レジスタ番号の基準を強調した方がよい（問い 4）。**
   `live_in_at == None` は保存、`Some(&[])` は窓全体の消去であり、両者を混同すると必要な値を消す。`call_write` は原型の相対番号、`CallFrame::ret` は区画内の位置なので、dest の除外に base を二重に加えてはいけない。昇順・範囲の検査は消去を始める前に行う。
   現在の検証器は仮置きなので、検証器が新しい表を検査することを前提にできない。根拠：[R16:61](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R16-liveness-at-safepoints.md:61)、[10-07:987](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-07-bytecode.md:987)、[verify:19](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/bytecode/verify.rs:19)。

8. **`pause_nanos` だけでは、今回追加する停止時間を測れない（問い 4・5）。**
   計時はヒープの `collect` 内で始まり、その前の窓の整理を含まない。整理と回収を合わせた時間を別に測り、総時間・p95／p99／最大停止時間・最大ヒープ量を比較する必要がある。生存量が減ると回収閾値も下がるので、回収回数の増加だけを失敗条件にはできない。
   全枠の総レジスタ数を S とすると、整理は回収ごとに O(S)。深さ D で頻繁に回収すれば累積 O(D²) になりうる。既存のマークも全 regs を走査するため同じ次数だが、追加走査と書き込みの定数倍は測る必要がある。深さ・窓幅・回収頻度を変える負荷を加えるべきである。根拠：[R16:84](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R16-liveness-at-safepoints.md:84)、[mark_sweep:149](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/runtime/heap/core/mark_sweep.rs:149)、[mark_sweep:45](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/runtime/heap/core/mark_sweep.rs:45)、[frame:181](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/frame.rs:181)。

9. **精度と情報量について、ADR の帰結を限定する必要がある（問い 1・3）。**
   未確認状態を全保存する第 2 段まで含めると、「従来と同じか小さい」は保証できない。未確認状態には同等の精度を約束せず、状態ごとに検証する形がよい。現在の `reg_use(CONR)` は再利用候補 A を読むため、再利用しない VM でも、その候補だけから辿れる大きな構造を余分に保持しうる。これは安全だが精度の取りこぼしである。
   live_in の保存量は最悪 O(命令数×レジスタ数) であり、「プログラムに比べて小さい」とは限らない。10 万命令で各入口に 256 レジスタが生きれば、レジスタ列だけで約 51 MB になる。R16 では生成物のサイズとコンパイル時の最大メモリも記録するとよい。根拠：[ADR:41](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0314-clear-dead-registers-at-safepoints.md:41)、[ADR:47](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0314-clear-dead-registers-at-safepoints.md:47)、[liveness:183](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/bytecode/liveness.rs:183)。