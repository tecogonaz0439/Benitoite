# R40 イベントループと作業用のスレッド

- 依存する作業: [R26](R26-dispatch-queue-and-io-executor.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R40-event-loop-and-worker-threads

## 目的

R26 が一時的な形で置いた `RuntimeParts::real`（仕事を VM のスレッドでその場で実行する）と、何もしない `Wakeup` を、本物に置き換える。作業用のスレッドで仕事を行い、完了を channel とイベントループの起こしで知らせる `WorkerExec` の実際の実装と、`mio` によるイベントループ（`mio::Poll` と `mio::Waker`、タイマーの期限までの待ち）を書く（ADR 0162、02-09「IO 実行器」）。

R26 は、送り出しの列、要求の段階と失効、外部の操作の記録と完了の処理、テスト用の `WorkerExec` を作り、テストを順序を与える部品で書いた。本作業は、その上で、作業用のスレッドとイベントループという、実時間とスレッドに依存する部分だけを受け持つ。完了の処理の順序と配送の照合は R26 のまま変えない。

## 読む設計書の節

- [ランタイム](../../design/02-impl/02-09-runtime.md)の「IO 実行器」（作業用のスレッドの数、channel と `mio::Waker`）、「リソースの追跡」（すべてのタスクが終わった後に残る操作の段落）、「panic 境界」、「中断の要求」（イベントループを起こす口）
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「IO の方式のテスト」「ヒープとランタイムの確かめ方（初回リリース版）」の最後の行
- ADR: [0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md) の決定 9・11、[0274](../../design/decisions/0274-deterministic-scheduler-and-virtual-time-for-tests.md) の決定 1・2、[0313](../../design/decisions/0313-vm-performance-recovery-before-stage-2.md) の帰結
- 検討資料: [相談の第 3 回](../studies/u2-runtime/consult/03-scheduler-and-io.md)のその他の箇条（作業用のスレッドが panic しても返却の欄を作れるよう、貸したリソースを `catch_unwind` の外で持つ）

インターフェース:

- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「実装プランで決める値」（作業用のスレッドの数）、「テストで差し替える部品」（`WorkerExec`・`IdleWake`・`RuntimeParts::real`）、「イベントループ」、「外部の操作の記録と完了」の `WorkerJob`・`Completion`・`LentOwned`
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の「作業用のスレッドの仕事」、`WorkerWait`・`Lent`
- R26 の作業文書の「一時的な `RuntimeParts::real` と `Wakeup`」と「`WorkerExec` のテスト用の実装」（仕事を実行する共通の関数）

## 作るもの

- `crates/benitoite/Cargo.toml` と `Cargo.lock`: 依存に `mio` を加える（後述）。
- `src/runtime/io/event.rs`: `WakeupInner` に `mio` を使う形を加え、`Wakeup::wake` の本物と、イベントループの本体を書く（後述）。このファイルの `todo!()` をすべて書き換えたら（R26 が書き換えていれば、すでにない）、仮置きの許可とコメント（00-02）が残っていないことを確かめる。
- `src/runtime/sched/parts.rs`: `RuntimeParts::real` を、`WorkerExec` の実際の実装（作業用のスレッド）を使う形に置き換える。R26 の一時的な `WorkerExec` は消す。R26 が置いた共有の仕事の実行の関数（`runtime::io::ops::execute_job(WorkerJob) -> Completion`、`pub(crate)`。中で `runtime::panic::catch` を使い、貸したものは閉包の外に置く。R26 の一時的な `InlineWorkers` と、R25・R26 のテスト用の `ScriptWorkers` が共有する）と一時的な `WorkerExec`（`parts.rs` の非公開の `InlineWorkers`。`submit` がその場で `execute_job` を呼んで `wakeup.wake()` し、`idle` は期限まで `thread::sleep` で眠る）について、公開の範囲を `pub(crate)` にする・`parts.rs` などへ移す・消すことは本作業の受け持ちであり、00-03 の「ほかの作業のファイル」に当たらない（R26 が `sched/testing.rs` などに置いていても止まらずに行う）。
- `src/runtime/run.rs`: `run_program` が、`RunEnv::parts` が `None`（本物の部品を使う）のときに `Wakeup` を `mio` を使う形で作るようにする（数行。テスト用の部品のときは今の形のまま）。
- 上のファイルのテスト。

R26 が置いた `event.rs`・`parts.rs`・`run.rs` の上の箇所は、本作業の処理を入れる場所であり、00-03 の「ほかの作業のファイル」には当たらない。

### 加えるクレート

- `mio` 1.2.3（[ADR 0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)。[実装の規約](../00-common/00-02-conventions.md)の「依存するクレート」が版と機能を記録したクレート）。ライセンスは `MIT`、`rust-version` は 1.71 である。`default-features = false` とし、機能 `os-poll` と `os-ext` を有効にする（`net` は U3 の HTTP の作業が加える）。`Cargo.lock` に版を固定する。本作業の時点で 1.2.3 より新しい 1.x の版があれば、その版の文書で機能の名前が変わっていないことを確かめて使い、版を完了の報告に書く。`cargo deny check licenses` を通す。`MIT` は ADR 0138 の許可の一覧にあり `deny.toml` で許可済みの見込みなので、足りなければ要るものだけを加える。

## 手順の要点

### `Wakeup` とイベントループ（10-10「イベントループ」）

- `WakeupInner`（10-10 の `file=` で凍結した struct。名前と `#[derive(Debug)]` は変えない）は、R26 の時点で欄のない構造体である（`event::wakeup_without_poll()` が作り、`wake()` は何もしない）。本作業が非公開の欄を一つ加え、その型を二つの分岐の `enum` にする: `mio` を使わない分岐（何もしない。テスト用の部品と `wakeup_without_poll()` のために残す）と、`mio::Waker` と `RuntimeParts::real` が一度だけ取り出す `Mutex<Option<mio::Poll>>` を持つ分岐。欄を加えることは 10-10 のコメント（欄は R26・R40 が決める）が認めている。
- `Wakeup` を `mio` を使う形で作る `pub(crate)` の関数（例 `event::wakeup_with_poll() -> std::io::Result<Wakeup>`）を `event.rs` に置く。`Poll::new` で `Poll` を作り、その `Registry` と決まったトークンで `Waker` を作る。`run_program` はこれを使い、作れなければ（OS の資源の不足など）処理系の不具合として内部の誤りで終える。扱いを完了の報告の「判断したこと」に書く。R26 の `mio` を使わない形を作る関数は、そのまま残す。
- `Wakeup::wake` は `Waker::wake` を呼ぶ。失敗は捨ててよい（起こしそこねても、`idle` は次のタイマーの期限か channel の確かめで戻る。理由をコメントに書く）。
- `mio` の型（`Poll`・`Waker`・`Registry`・`Token`・`Events`）は `runtime::io::event` の外に出さない。作業用のスレッドの実装は、`event.rs` の `pub(crate)` の関数（例 イベントループの待ちを包む型）を通して使う。
- R28 は、中断のシグナルを `signal-hook-mio` でイベントループに登録するために、`Registry` を使う（R28「中断の印」）。本作業は、R28 が `Registry` を借りられる `pub(crate)` の口（例 `Registry::try_clone` したものを取り出す関数）を `event.rs` に置いておくか、置き方を R28 が決められるように、イベントループの待ちを包む型の形を完了の報告に書く。中断のシグナルに使うトークンは、`Waker` のトークンと別の定数として `event.rs` に予約しておく。

### `WorkerExec` の実際の実装

- 仕事を出すときに空いたスレッドがなければ新しく作り、数の上限を 64 とする。上限に達したら、仕事は空くまで列で待つ。空いたスレッドは実行の終わりまで残す（10-10「実装プランで決める値」）。
- スレッドは、R26 が独立した関数として書いた仕事の実行 `runtime::io::ops::execute_job`（`WorkerJob::lent` を `catch_unwind` の外で持ち、借りた `Lent` を仕事に渡して `WorkerWait::run` を `catch_unwind` で囲んで呼ぶ。`JobWork::Release` は `OsResource::release` を囲んで呼ぶ。panic なら `Outcome::Panicked` にし、貸したものを `returned` に入れる。ADR 0266 の決定 9）を使う。panic の記録は、作業用のスレッドのスレッドローカルな記録（02-09「panic 境界」）から取り出す。
- 完了は `std::sync::mpsc` の channel で送り、`Wakeup::wake` でイベントループを起こす。
- `try_recv`: channel から完了を一つ受け取る。待たない。
- `idle(deadline)`: channel に完了があれば待たずに `Progress` を返す。なければイベントループ（`mio::Poll::poll`）を、次のタイマーの期限までの時間を上限に待つ（期限がなければ上限なし）。`Waker` のトークンで起きたか、期限が来たら `Progress` を返す。中断のシグナルのトークン（上で予約したもの）で起きたら `Interrupted` を返す。中断の登録は R28 が行うので、本作業の時点ではこのトークンは届かない。
- 実行ごとの状態を捨てるとき（`IoRuntime` を落とすとき）に、スレッドに終わるよう知らせる。終わっていない仕事を待たない（ADR 0266 の決定 11）。仕事が後で完了したときは、送り先がないので `returned` を破棄して OS の資源を閉じる。スレッドを `join` しない。
- 作業用のスレッドに渡すものは `Send + 'static` の型であり、言語の値を含めない（00-02「組み込みの関数の書き方」）。

### `RuntimeParts::real`

`RuntimeParts::real(wakeup)` は、`FifoPicker`、R25 の `RealClock`、上の実際の `WorkerExec` の組を返す。`WorkerExec` は `wakeup` から `Poll` を一度だけ取り出し、自分で持つ。`wakeup` が `mio` を使わない形のときは、正当な代わりの動きとして、イベントループを使わずに期限まで眠る `idle` で動く形にする（テストが使ってよい。`debug_assert!` を置かない）。`Poll` がすでに取り出されていたとき（同じ `Wakeup` で二度呼んだ）は、凍結した戻り値で誤りを返せないので、同じく眠る `idle` で動く形にし、`debug_assert!` で不具合を示す。`idle` の期限（`RealClock::monotonic_millis` の値）を待ち時間に直せるように、`RuntimeParts::real` の中で `RealClock` と `WorkerExec` に同じ開始時点（`Instant`）を渡す。待ち時間はミリ秒の切り上げにして、早く起きて空回りするのを防ぐ。扱いを完了の報告の「判断したこと」に書く。

### 凍結した戻り値で処理系の不具合を扱う方法

`WorkerExec::submit -> ()`（スレッドを作れない）と `RuntimeParts::real -> RuntimeParts`（上の `Poll` の扱い）の戻り値は凍結しており（10-10 の `sig=`）、処理系の不具合を表せない。スレッドを作れないとき（`std::thread::Builder::spawn` の失敗）は、仕事を列に残して空いたスレッドを待ち、スレッドが一つもなければ、その仕事の完了を `Outcome::Panicked`（説明の文字列を入れた `PanicReport`）として列に置き、貸したものを `returned` で返す。VM はこれを処理系の不具合として報告する。扱いを完了の報告の「判断したこと」に書く。

### 性能

普通の経路に処理を足さない。作業用のスレッドとイベントループは、待たせる位置の順序の関数と要求の処理からだけ呼ばれる（`submit` は手順 1 と要求の処理、`try_recv` は手順 2、`idle` は手順 6。R26）。`try_recv` は channel の受信を一度試すだけにし、ロックを取らない。

完了の報告に、短い測定と機械語の数を書く（ADR 0313 の帰結、2026-10-06）。作業を始めたときの `san_benito` の HEAD と本作業の版の `examples/stage1_bench`（release）を、fib(30)・loop 300 万回で交互に 5 回以上走らせ、`run_nanos` の最小値を比べる。release の振り分けのループ（`run_until_exit`）の頭の機械語の命令の数とスタックへの退避（`[sp, …]` への `str` とそこからの `ldr`）の数も、始めた版と比べる。比較の版の展開と target は作業ディレクトリの `target/` の下に置き、終えたら消す。時間の本測定はしない（本作業を取り込んだ後と最後に、オーケストレータが行う）。

本測定の道具（`examples/stage1_bench.rs` と `tools/bench/`）は変えない。release で `stage1_bench` が fib と loop を走らせて `run_nanos` を出すことを確かめる。`stage1_bench` は `RunEnv { parts: None, .. }` で本作業の `RuntimeParts::real` を使う。

## 受け入れテスト

作業用のスレッドとイベントループの単体テストは、実時間の待ちやスレッドの実行の順序の偶然に頼らず、channel と、仕事の中で止めておける同期の道具（`std::sync::Barrier`・`mpsc` など）で順序を決めて確かめる。`scripts/check-heap.sh` の Miri は `runtime::heap::` と `vm::miri_tests` のテストだけを走らせる（ADR 0318）。本作業のテストは `vm::miri_tests` に置かない（`Poll` は Miri で動かない見込みであり、作業用のスレッドとイベントループは `unsafe` のヒープを新しい形で使わない）。

- 作業用のスレッドの panic: 実際の実装に panic する仕事を直接出す単体テストで、完了が `Outcome::Panicked(PanicReport)` になり（panic hook はプロセス全体で一つで、ライブラリの単体テストでは設定されないので、記録の文言と位置まで確かめるなら `runtime/panic.rs` の既存のテストと同じ子プロセスの形を使う。そうでなければ種類だけを確かめる）、貸したもの（偽の資源と標準入力の読み手）が `returned` で返る。
- 作業用のスレッドの上限: 実際の実装に、channel で止めておける仕事を 65 個出すと、64 個が始まり、1 個が待つ。一つを終わらせると待っていた仕事が始まる（実時間の待ちではなく、channel で順序を決めて確かめる）。空いたスレッドに次の仕事が渡り、スレッドの数が増えない。
- 完了の知らせ: 仕事の完了で `Wakeup::wake` が呼ばれ、期限のない `idle` が `Progress` で戻り、続く `try_recv` が完了を返す。
- タイマーの期限: 完了のないまま、すでに過ぎた期限で `idle` を呼ぶと、待たずに `Progress` で戻る。
- ブロックする解放の仕事: `JobWork::Release` を出すと、作業用のスレッドで `OsResource::release` が一度呼ばれ、`Outcome::Released` が返る。解放が失敗する偽の資源では失敗の文字列が入る。
- 実行ごとの状態を捨てるとき: 終わらない仕事（channel で止めたもの）を出したまま `IoRuntime` を落としても、落とす処理が仕事の終わりを待たずに戻る。その後に仕事を終わらせると、`returned` の偽の資源が破棄される（破棄を記録する偽の資源で確かめる）。
- 二つの方式で同じ結果: `File.readText` と `Console.writeLine` を使う既存のゴールデンテストのうち C05 が移したものが、本作業の `RuntimeParts::real` で両方式で通る（`run_program` の `RunEnv::parts` を `None` にした経路）。
- R26 の受け入れテストが、本作業の後もすべて通る（テスト用の部品の経路は変えない）。
- 回収の強制のビルドで、上のテストがすべて通る。

## 完了条件

- `scripts/check.sh` が通る
- `scripts/check-heap.sh` が通り、10 分以内に終わる（ADR 0318）
- 受け入れテストのすべての場合を確かめるテストがある
- `mio` の版と機能が上の記録（1.2.3、`os-poll`・`os-ext`）と一致するか、新しい版を使ったときはその版を完了の報告に書いている。`cargo deny check licenses` が通る
- R26 の一時的な `WorkerExec` が残っていない
- 実時間の待ちやスレッドの実行の順序の偶然に頼るテストがない（[実装の規約](../00-common/00-02-conventions.md)の「テストの規約」）
- 完了の報告に、短い測定と機械語の数、`Registry` を R28 に渡す口の形、前述の「判断したこと」に書く項目を書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「スケジューラと IO」の行。
- 作業用のスレッドに渡すものに言語の値が入っていないか（型で防いであるが、`Send` の抜け道を作っていないか）。
- 貸したものを `catch_unwind` の外で持ち、panic しても `returned` で返しているか。
- イベントループが VM を止めていないか。外部の操作の終わりを VM のスレッドで待っていないか（`idle` は進められるタスクがないときだけ呼ばれるか）。実行ごとの状態を捨てるときに、終わっていない仕事を待っていないか。
- `mio` の型が `runtime::io::event` の外に出ていないか。

## 難易度の理由

作業用のスレッドの数の上限と列、panic と貸したものの返却、実行の終わりで仕事を待たないことを、実時間とスレッドの順序の偶然に頼らないテストで確かめる必要がある。完了の処理の順序は R26 が決めてあるので、本作業はスレッドとイベントループの正しさに集中できる。
