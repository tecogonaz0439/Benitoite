# R28 中断の要求と、ランタイムの止める手順

- 依存する作業: [R40](R40-event-loop-and-worker-threads.md)（R26 を含む）
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R28-interrupt

## 目的

`SIGINT`・`SIGTERM` による中断の要求を受け、各タスクの `with` のリソースを解放してから終了状態 130 で終える（ADR 0163）。あわせて、止める手順のうちランタイムが受け持つ部分（02-09「止める手順でランタイムが行うこと」）が、実行時エラー・資源の不足・`Process.exit`・中断の要求のすべての止まり方でつながっていることを確かめる。VM の側の枠の辿り（R21・R25）、待ちの整理（R25・R26）、出力の最後の転送（R26 の一時的な `finish`。R27 が並行して書き出し用のスレッドの形に置き換える）、報告の組み立て（R38）はすでにある。本作業が書くのは、中断の印の読み出し（切り替えの位置と待つ位置）とシグナルの登録であり、ほかはすでにあるものを止まり方ごとに確かめる。

## 読む設計書の節

- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「中断の要求」「止める手順でランタイムが行うこと」「リソースの追跡」の解放の失敗のまとめ方、「プログラムの実行の流れ」の表と転送の失敗の箇条
- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「実行ごとの状態のうち VM が使うもの」の最後の段落（中断の印の読み口）、「タスクの切り替え」（切り替えの位置の処理の手順 1、待つ位置でも中断の印を調べること）、「止める手順」（二度目の中断の要求の段落を含む）
- [エフェクト](../../2026-10-09-design-first-release/01-spec/01-07-effects.md)の「影響の大きい操作（初回リリース版）」（`Process.exit`）
- [IO のモジュール](../../2026-10-09-design-first-release/03-interop/03-07-io-modules.md)の「Process」の `Process.exit` の箇条（範囲の外の `code`）
- [スクリプト実行と埋め込み](../../2026-10-09-design-first-release/02-impl/02-11-embedding.md)の「CLI の一回の実行」「資源の上限と中断」
- [診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「解放の失敗の報告」
- [CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md)の「終了状態」
- ADR: [0163](../../2026-10-09-design-first-release/decisions/0163-interrupt-releases-resources.md)、[0263](../../2026-10-09-design-first-release/decisions/0263-dispatch-loop-locals-and-verifier.md) の決定 4（`Relaxed` の読み出し）、[0165](../../2026-10-09-design-first-release/decisions/0165-exit-and-stdio-in-embedded-runs.md)、[0037](../../2026-10-09-design-first-release/decisions/0037-exit-status-values.md)、[0015](../../2026-10-09-design-first-release/decisions/0015-shared-program-per-execution-state.md)（大域の可変状態の例外）

インターフェース:

- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「止まったときの報告」（`release_report`・`ReleaseCause`）、「実行の流れ」（`process_interrupt`・`NoInterrupt`・`run_program` の終わり方の表）、「未定のこと」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の `InterruptSource`（`attach` を含む）、`Wakeup`、`InterruptGuard`、`IdleWake::Interrupted`、「作業の割り当て」の R28 の行
- [仮想機械](../10-interfaces/10-09-vm.md)の `StopReason`・`StopEnd`

## 作るもの

- `src/runtime/io/services.rs` と `src/runtime/io/event.rs`: 10-10 の `file=` に加えた `InterruptSource::attach`（既定の本体付きの関数）と `InterruptGuard` を写す（後述の「読み口のトレイトへの追加」）。
- `src/runtime/run.rs`: `process_interrupt` の中身（F18 の仮の中身を置き換える）と、`run_program` で本物の部品を使うとき（`RunEnv::parts` が `None`）に `attach` を呼び、返った印を実行の終わりまで持つ処理。
- 中断の印を持つ非公開のモジュール（例 `src/runtime/run/interrupt.rs`。`run.rs` の中で宣言する）: 印の `Arc<AtomicBool>` と、`signal-hook` による印の登録と、`process_interrupt` が返す読み口の型。
- `src/runtime/io/event.rs`: シグナルを `signal-hook-mio` で R40 のイベントループに登録する `pub(crate)` の関数と、`InterruptGuard` の中身（落とすと登録を外す）。R40 は `Registry` を借りる関数を置いていない。`attach` から届くのは `Wakeup` だけなので、`event.rs` の中で `WakeupInner` の欄（非公開の `WakeBackend`）の `WithPoll` の分岐の `poll`（`Mutex<Option<mio::Poll>>`）をロックし、`poll.registry().try_clone()` で `Registry` を複製する。`Signals` をその `Registry` に中断のシグナルに予約したトークン `INTERRUPT_TOKEN`（`event.rs` の同じモジュールの定数）で登録し、複製した `Registry` と `Signals` を `InterruptGuard` に持たせ、落とすときにその `Registry` で登録を外す。`Poll` がすでに取り出されていた（`EventLoop::take` の後）か、`WithoutPoll` の分岐なら、`Err` を返す。
- `src/runtime/sched/parts.rs`: R40 の `WorkerExec` の実際の実装の `idle` の、予約のトークンで起きたときの側（`IdleWake::Interrupted` を返す処理。R40 がすでに書いていれば確かめるだけ）。`Signals` は `run_program` が持つ `InterruptGuard` の中にあり `idle` からは触れないので、届いたシグナルを `idle` で読み捨てる処理は書かない（`mio` はエッジで知らせるので、読み捨てなくても新しいシグナルのたびに起きる。中断の要求の有無は印で判定する）。
- `src/vm/dispatch.rs` と `src/vm/dispatch/tasks.rs`: 切り替えの位置での印の読み出しと、`switch_inner` の `IdleWake::Interrupted` の処理（後述の「印を調べる位置」）。
- `crates/benitoite/Cargo.toml` と `Cargo.lock`: 下の「加えるクレート」の二つを加える。
- AGENTS.md の「大域の状態」の中断の印の箇所に、実際に置いたファイルのパスを書き足す（C00 が 00-02 の規約を写した節）。
- 上のファイルのテスト。

R40 が置いた `event.rs`・`parts.rs` と、R25・R26 が置いた `dispatch.rs`・`tasks.rs`・`run.rs` の上の箇所は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。

### 並行して実装する場合

R27 も `switch_inner` の `idle` の直前（R27 は手順 4 の転送の依頼、本作業は `IdleWake::Interrupted` の処理）を書き換える。R27 と R28 は順に取り込み、後に取り込む方が `switch_inner` の衝突を直す。

### 加えるクレート

シグナルの登録には `signal-hook` と `signal-hook-mio` 0.3.0 を使う（2026-09-30、設計者の判断。02-09「中断の要求」、[実装の規約](../00-common/00-02-conventions.md)の「依存するクレート」、10-13「未定のこと」、[README](../README.md) の「決めたこと」の 14）。`signal-hook` は、決めたときの 0.4.4 より新しい 0.4.5 を使ってよい。手元のレジストリには `signal-hook` 0.4.5（と 0.4.4）、その依存の `signal-hook-registry` 1.4.8、`signal-hook-mio` 0.3.0 をオーケストレータが取得してある（作業の環境はネットワークにつながらない）。三つのライセンスは `MIT OR Apache-2.0` であり、`deny.toml` の `allow`（`MIT`・`Apache-2.0`）で通る。`rust-version` は `signal-hook` 0.4.5 と `signal-hook-mio` 0.3.0 が 1.66、`signal-hook-registry` 1.4.8 が 1.26 である。Unix 系の OS でだけ使えればよい（ADR 0176）。

`signal-hook-mio` は、`mio` 1.x に合わせる機能 `support-v1_0` で使う。この機能は `mio` を機能 `net` と `os-ext` 付きで要求するので、本作業の後は、機能の統合により `mio` の `net` も有効になる（00-02「依存するクレート」）。R40 が `mio` に付けた `default-features = false` と `os-poll`・`os-ext` の指定は変えない。

## 手順の要点

### 読み口のトレイトへの追加（10-10「実行ごとの状態と VM のつなぎ目」）

`InterruptSource` は `requested` だけを持ち、プロセス全体の印から実行ごとのイベントループ（`Wakeup` の `Poll`）へシグナルを届ける口がない。そのままでは、`idle` で待っている VM を中断の要求で起こせない。そこで、10-10 の `file=` の `InterruptSource` に、既定の本体を持つ関数 `fn attach(&self, _wakeup: &Wakeup) -> std::io::Result<Option<InterruptGuard>> { Ok(None) }` を加え、`event.rs` に不透明な型 `InterruptGuard`（落とすと登録を外す）を置いた。R25 の `TaskPicker::spawned` と同じく、既存の実装（`NoInterrupt` とテストの偽の読み口）を変えずに済む追加である。本作業は、これを `src/` に写す。

- `NoInterrupt` は既定の本体のまま `Ok(None)` を返す。テスト（`golden.rs`・`vm_handlers.rs`・`call_allocations.rs`・CLI のテスト）は `NoInterrupt` を使うので、`parts: None` で `attach` が呼ばれても登録せず、テストのプロセスにシグナルの処理は入らない。
- `process_interrupt` が返す読み口の `attach` は、`event.rs` の `pub(crate)` の関数で、`signal_hook_mio` の `Signals`（`SIGINT`・`SIGTERM`）を R40 が予約したトークンで `Registry` に登録し、`Signals` を包んだ `InterruptGuard` を返す。`InterruptGuard` を落とすと、`Registry` から外し、`Signals` の登録を消す。
- `run_program` は、`RunEnv::parts` が `None` のときに `attach` を呼び、返った印を実行の終わり（最後の転送の後）まで持つ。`attach` が失敗したら（OS の資源の不足など）、R40 の `Wakeup` を作れないときと同じく処理系の不具合として内部の誤りで終える。呼ぶ順は、`run.rs` で `wakeup_with_poll()`（R40）で `Wakeup` を作った後、`RuntimeParts::real` を呼ぶ前とする（`RuntimeParts::real` が `EventLoop::take` で `Poll` を取り出した後は、`Registry` を複製できない）。

### 中断の印（02-09「中断の要求」）

- 印は、プロセス全体で一つの `AtomicBool` とする。大域の可変状態の例外の一つであり（AGENTS.md「大域の状態」）、印を書くのはシグナルの登録の仕組みだけ、読むのは VM の実行の区切りだけである。印は `process_interrupt` が一度だけ作る `Arc<AtomicBool>` でよく、`static` にしなくてよい（`process_interrupt` は CLI がプロセスで一度だけ呼ぶ）。
- `process_interrupt` は、`SIGINT`・`SIGTERM` のそれぞれについて、同じ `Arc<AtomicBool>` で `signal_hook::flag::register_conditional_default` を先に、`signal_hook::flag::register` を後に登録する（`signal-hook` の `flag` モジュールの文書が勧める形）。一度目の要求では印が立つだけで、印が立った後の二度目の要求では OS の既定の振る舞い（プロセスの終わり）が起きる。処理系は二度目を受け取らない。読み口の型は、印を `Relaxed` で読む `requested` と、前述の `attach` を持つ。
- シグナルの処理の中で許される操作の範囲は、`signal-hook` の文書に従う。
- CLI の `run` と `test` が、コマンドラインを解釈した後、検査の前に一度だけ呼ぶ（呼ぶ側は F18 が書いた）。テストの経路と `check` は `NoInterrupt` を使う。

### 印を調べる位置（02-08「タスクの切り替え」、ADR 0263 の決定 4）

印の読み出しは、今はどこにもない（`rt.interrupt` はまだどこからも読まれていない）。本作業が次の二か所に加える。

- 切り替えの位置の処理の手順 1: 呼び出しの命令の処理で、予算を減らす前（`state.budget.tick()` の前）に、`InterruptSource::requested` を `Relaxed` で読む。立っていて `state.stopping` が `None` なら、`StopReason::Interrupted` を入れて止める手順（`cleanup`）へ進む。
- 待つ位置: `switch_inner` で、`WorkerExec::idle` が `IdleWake::Interrupted` を返したら印を調べ、立っていて `state.stopping` が `None` なら、`StopReason::Interrupted` を入れて `begin_stop_all` を呼び、周回を続ける（行き詰まりの分岐と同じ形）。今は `IdleWake::Progress` と同じく何もしない。

止める手順の途中で印が立っても、始めた止める手順の理由は変えない（`state.stopping` が `Some` なら何もしない）。

### 性能

印は呼び出しのたびに `Relaxed` で読む（ADR 0263 の決定 4）。呼び出しの速い経路は `rt` を受け取らないので、`InterruptSource::flag`（10-10 に加えた既定の本体付きの関数。オーケストレータが本作業の起こしで加えた）で印の `&AtomicBool` を取り出し、振り分けのループ（`run_until_exit`）の局所の変数（例 `Option<&AtomicBool>`）に持って、呼び出しの命令の処理で `load(Relaxed)` する。呼び出しのたびに `&dyn InterruptSource` の動的な呼び出しをしない。本作業の本物の読み口は `flag` で印を返す。`flag` が `None` の読み口（`NoInterrupt` など）では、印を読む処理を飛ばしてよい（中断の要求が来ないので）。`LoopLocals` は 10-09 で凍結した型なので、欄を加えない。借用の衝突を避ける形は本作業が決める。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（オーケストレータが行う）。本測定の道具（`examples/stage1_bench.rs` と `tools/bench/`）は変えない。

fib か loop の `run_nanos` の最小値が、始めた版より 5% を超えて遅くなったら、実装を進めずに止まって報告する。印を予算を使い切ったときだけ読む形は、ADR 0263 で却下した案（ADR 0163 の「切り替えの位置で調べる」を改めることになる）なので、採るには設計者の判断が要る。報告には、測った値と、考えられる案を書く。

### `Process.exit`（E-Exit）

すでにある処理を確かめるだけとする。R26 の `serve_inner`（`vm/dispatch/tasks/io.rs`）は、`Reply::Exit(status)` を受けたら、`state.stopping` が `None` のときだけ `StopReason::Exit(status)` を入れ、続く `serve` が `begin_stop_all` と `reflect_cancellation` を呼ぶ。`code` の範囲の確かめ（0 以上 255 以下。範囲の外は実行時エラー）は、組み込みの関数の本体（R29）が行う。

### 止める手順でランタイムが行うこと（02-09 の同節の手順 1〜4）

次の手順は、R21・R24・R25・R26 がすでに書いた。本作業は、中断の要求で止めるときにもこれらが同じ順で働くことを、受け入れテストで確かめるだけとする。食い違いを見つけたら、直す前に報告する。

1. 止める理由を終わり方の記録に残す: `state.stopping` に最初の理由だけを入れる（`RunState::fail`、R26 の `fail_task`、上の `Reply::Exit` の分岐、行き詰まりの分岐。どれも `state.stopping` が `None` のときだけ書く）。
2. 待ちを整理する: `begin_stop_all`（`vm/dispatch/tasks.rs`）が、解放の完了の待ち `WaitReason::Release` を残して待ちを外し、返却を待つ並びからタスクを除き（`ResourceTable::remove_waiter`）、`state.scheduling.expire_io` を立てる。R26 の `reflect_cancellation` が、これを受けて生きている要求を `DispatchQueue::expire_all` で失効させ（[ADR 0282](../../2026-10-09-design-first-release/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）、標準入力の返却の待ちと `Sleep` のタイマーの記録を消し、作業用のスレッドで続いている操作の配送先を外す（完了したら R26 の `accept_completion` が返すリソースを表に戻してから結果を捨てる）。出力の容量の待ちと完了の待ちの取り下げ（`OutputPort::cancel_pending`）は、R27 が同じ `reflect_cancellation` に入れる。
3. VM が解放の枠を辿ってリソースを解放する: `cleanup` と `begin_stop`（`vm/dispatch/unwinding.rs`）が枠を辿り、リソースの型ごとの解放（R24）を行う。解放が完了を待つときは、止める途中でも待たせる位置の順序の関数（完了の取り込みとイベントループ）を続ける。
4. VM が止まり方を返したら、`run_program` が出力の最後の転送（R26 の一時的な `finish`。R27 が置き換える）を行い、`step_end` で終わり方の処理に進む。

止める途中で二度目の中断の要求を受けたら、解放を待たずに OS の既定の振る舞いで終える（ADR 0163）。これは、前述の「中断の印」の `register_conditional_default` で実現する（処理系は二度目を受け取らない）。

止める途中では言語の関数を呼ばないので、別の実行時エラーや `Process.exit` は起きない。止める途中の行き詰まりの判定は、元の理由を置き換えない（R25）。

### 終わり方と報告（10-13「実行の流れ」の表）

`run.rs` の `step_end` が、すでに次のとおりに扱っている。本作業は確かめるだけとする。

- `Exited(code)`: 止める途中の解放の失敗ごとに `release_report(.., ReleaseCause::Exit(code))` の報告を加える。終了状態は `code`。
- `Interrupted`: 同じく `ReleaseCause::Interrupted`。終了状態は 130（`EXIT_INTERRUPTED`）。
- 解放の失敗を報告しないリソースの型（`HttpExchange`）の失敗は渡さない（R24 がすでに捨てている）。
- 出力の最後の転送の失敗は、`run.rs` の `flush_failure` の規則（`write_failed` を加え、終了状態を変えない）に従う（R26 が置き、R27 が確かめる）。

## 受け入れテスト

中断の要求を実際のシグナルで確かめるテストは、別のプロセスで CLI を起動して行う（07-03「中断の要求のテスト（初回リリース版）」、ADR 0223）。それは R31 が書く。本作業のテストは、印を立てられる `InterruptSource` の偽の実装と、R25 のテスト用の部品を使い、処理系の関数を直接呼んで確かめる。テスト用の部品の `idle` は `IdleWake::Interrupted` を返す筋書きを持たないので、`Interrupted` を返す偽の `WorkerExec` をテストに書くか、`sched/testing.rs` に `Interrupted` を返す筋書きの指示を加えてよい。

- 計算を続けるタスクがあるとき: 末尾再帰で計算を続けるプログラムの途中で印を立てると、次の切り替えの位置で止める手順が始まり、`Interrupted` と終了状態 130 で終わる。
- 待っているとき: タイマーを待つタスクだけがあるとき（`WorkerExec::idle` で待っているとき）に印を立てると、`IdleWake::Interrupted` で戻って止める手順が始まる。
- 止める手順の解放: 中断で止める途中で、すべてのタスクの解放の枠が内側から解放される（偽の資源を使う VM の単体テストで確かめる）。解放の失敗が `release_report` の報告になり、終了状態は 130 のまま変わらない。
- 待っていた操作の整理: 作業用のスレッドの仕事を待つタスクがあるときに中断すると、実行は仕事の完了を待たずに終わる。仕事が後で完了しても、返すリソースは破棄される。
- 出力: 中断の前に書いた出力が、止める手順の終わりの転送で出力先に届く。
- 止める手順の途中の印: 実行時エラーで止める途中に印を立てても、終わり方は元の理由のまま変わらない。
- `Process.exit`: `IoReply::Exit` を返す組み込みの関数の本体は R29 が書くので、`Exited` の経路のテストは R29 の受け入れテストと R31 で確かめる。本作業では、止める手順を `StopReason::Exit(3)` で始める VM の単体テストで、終わり方と終了状態を確かめる。
- `attach`: `NoInterrupt` の `attach` が `Ok(None)` を返し、`parts: Some(..)` の `run_program` が `attach` を呼ばない。
- `process_interrupt` の単体テスト: 同じプロセスでシグナルを送るテストは、テストの実行器のほかのテストに影響するので書かない。R31 の別のプロセスのテストで確かめる。

## 完了条件

- `scripts/check.sh` が通る
- `scripts/check-heap.sh` は本作業では走らせなくてよい。`vm/` を変えるので、オーケストレータが取り込むときに走らせ、10 分以内に終わることを確かめる（ADR 0318 の決定 5）。本作業のテストは `vm::miri_tests` に置かない
- 受け入れテストのすべての場合を確かめるテストがある
- 中断の印のほかに、大域の可変状態を加えていない
- `signal-hook`（0.4.5 か 0.4.4）と `signal-hook-mio` 0.3.0（機能 `support-v1_0`）を加え、`cargo deny check licenses` が通る。使った版を完了の報告に書く
- 完了の報告に、短い測定と機械語の数と、シグナルから実行ごとのイベントループを起こす方法（`attach` の中身と、`InterruptGuard` を落とすときの処理）を「判断したこと」に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「大域の状態」と「スケジューラと IO」の行。
- 印を読む位置が、切り替えの位置と待つ位置の二つに限られているか。印を書く箇所がシグナルの登録の仕組みだけか。
- 一度目の要求の後に二度目で OS の既定の振る舞いが起きるか（`register_conditional_default` を `register` より先に登録しているか）。
- テストの経路（`NoInterrupt`、`parts: Some(..)`）でシグナルを登録していないか。
- 止める手順の途中で、取り消しの手順や行き詰まりの判定に移っていないか。
- 解放の失敗の報告の種類（`Release`）と終了状態が、02-10「解放の失敗の報告」と 10-13 の表のとおりか。

## 難易度の理由

シグナルの処理、イベントループの起こし方、止める手順の途中の待ちの扱いが絡み、誤るとプログラムが終わらないか、リソースを解放しないまま終わる。同じプロセスではシグナルを確かめにくいので、実際のシグナルの確かめは R31 に分け、本作業では偽の読み口で順序を確かめる。
