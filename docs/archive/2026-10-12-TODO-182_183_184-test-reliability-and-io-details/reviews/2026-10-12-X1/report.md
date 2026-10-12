# 作業 X1 のレビュー（コミット 6af9bbcb）

- 対象: `6af9bbcb Make time-dependent tests bounded and their cleanup panic-free`（`san_benito` に取り込み済み）
- 照らした文書: `plan.md` の「作業 X1」、`study.md` の 1 節、`decisions.md` の R10・R12、実装者への指示（事前点検の補足を含む）と実装者の報告
- 観点:
  - (1) 上限のない待ち、偽の失敗、やり直しの条件の精度
  - (2) `Drop` が巻き戻しの途中で panic しないこと、スレッドの漏れ
  - (3) 元のアサーションを弱めていないこと
  - (4) 07-03 の追記
  - (5) lint の規約
- 方法: 差分と周辺のコードを読んで確かめた。テストは走らせていない。読んだ周辺のコードは次のとおり。
  - `runtime/sched/parts.rs` の `ThreadWorkers::idle`
  - `runtime/io/event.rs` の `Events::wait`
  - `prelude/stdlib/Network/Http.bnt` の `serve`
  - 03-09「失敗の種類」

## 所見

### 1.【要修正】`completed` の補助は 10 秒を過ぎると上限なく空回りし、変えたテストの退行の場合を止まらない形にした

- 場所: `crates/benitoite/src/runtime/sched/parts/tests.rs:78-86`（`completed`）、同 `:235`（`completion_wakes_idle_without_deadline_and_expired_timer_does_not_wait`）
- 問題: `completed` は `idle(Some(10_000))` を期限として呼ぶ。期限は、部品を作った時点からの単調な時計のミリ秒である（`runtime/sched/parts.rs:192-201` の `timeout`、`:88` の `started`）。
  - 部品を作ってから 10 秒を過ぎると、待ち時間は 0 になる。すると `Events::wait`（`runtime/io/event.rs:203-218`）も、Poll のない形（`parts.rs:275-282`）も、すぐに `IdleWake::Progress` を返す。
  - 完了が届かないかぎり `loop` は終わらず、CPU を使い続けて止まらない。
  - コメント「不具合で通知がなくても期限で戻る」が保証するのは `idle` が戻ることだけで、補助の全体には上限がない。
- 今回の変更との関係: この作業で、イベントループを持つ場合（`poll = true`）も、この補助を通すようにした。
  - 直す前は `try_recv().unwrap()` だったので、「起こしは届くが完了が届かない」退行（完了を別の channel に送る、`pending` を落とす、など）は即座に失敗した。
  - 直した後は、同じ退行でテストのバイナリが止まらなくなる。
  - これは観点 (1) と、07-03 に足した方針（上限は停止の検出に使う）に反する。
- 修正案: `completed` に全体の上限を付ける。例:

  ```rust
  fn completed(workers: &mut dyn WorkerExec) -> Completion {
      let started = std::time::Instant::now();
      loop {
          if let Some(completion) = workers.try_recv() {
              return completion;
          }
          assert!(
              started.elapsed() < std::time::Duration::from_secs(120),
              "no worker completion arrived within 120 s"
          );
          // 不具合で通知がなくても期限で戻る。時間の経過は結果の判定に使わない。
          assert!(matches!(workers.idle(Some(10_000)), IdleWake::Progress));
      }
  }
  ```

  - 期限の `10_000` を、呼び出しの時点の時計の今の時刻に足した値にすると、コメントのとおり「期限で戻る」待ちになり、空回りも避けられる。
  - `completed` はこのファイルの 8 箇所が使うので、ほかのテストの同じ穴も一緒に塞がる。

### 2.【推奨】同じテストの `idle(None)` は、起こしが届かない退行で上限なく止まる

- 場所: `crates/benitoite/src/runtime/sched/parts/tests.rs:234`
- 問題: このテストは「完了が期限なしの `idle` を起こす」ことを確かめるために `idle(None)` を呼ぶ。
  - 完了が起こしを送らない退行は、このテストが捕まえたい退行そのものだが、その場合テストは失敗せずに止まる。
  - この行は今回変えていない。ただし変えたテストの中の上限のない待ちであり、07-03 に足した方針とも合わない。
- 修正案: 見張りのスレッドを置く。
  - `Wakeup` は `Clone` で、別のスレッドへ写せる。`parts.workers.wakeup()` の写しを持つスレッドが、120 秒待ってから印（`AtomicBool`）を立てて `wake()` する。
  - テストは `idle(None)` の後に、印が立っていないことを確かめる（`"idle(None) was woken only by the watchdog"` の趣旨の文言）。
  - 完了が先に届いた場合は、channel で見張りを止める。
  - 印で偽の起こしを見分けるので、退行を隠さない。

### 3.【推奨】07-03 の新しい方針は、既存のテストの多くが満たしていない一般の決まりとして書かれている

- 場所: `docs/design/07-quality/07-03-compiler-testing.md:254-256`（「実時間の待ちの上限とテストの後片付け」の 1・2 段落）
- 問題: 「時間切れの文言には待っていたものを書き」を満たさない箇所が、今回触れたファイルの中にも残る。
  - 今回触れたファイル: `tests/l31_http_serve_and_helpers.rs:99`（`wake_rx.recv_timeout(LIMIT).unwrap()`）、同 `:128`（`finish` の `recv_timeout(LIMIT).unwrap()`）、`tests/l32_http_client.rs:83`。時間切れのとき「timed out waiting on channel」だけを出す。
  - ほかのファイルの同じ形: `tests/l30_http_server.rs:91,141`、`tests/http_exchange_release.rs:152,216`、`tests/http_descriptor_exhaustion.rs:122,158`。
  - 設計書は「処理系が今実装している内容だけを書く」（AGENTS.md「設計書の規約」）。すべてのテストが従っているように読める書き方は、実装と食い違う。
- 修正案: 次のどちらか。
  - (a) 今回触れた L31 の 2 箇所と L32 の 1 箇所を `unwrap_or_else(|error| panic!("waiting for …: {error}"))` に直す。方針の文を「テストを書く・直すときは」で始めて、適用の範囲を示す。残りのファイルは docs/todo の項目にする。
  - (b) 残りのファイルも同じ改造で直す（機械的な置き換えで、各 1〜2 行）。

### 4.【軽微】07-03 の追記に、時間切れのときにスレッドを待たないことと、節の対象が書かれていない

- 場所: `docs/design/07-quality/07-03-compiler-testing.md:252-260`
- 問題が二つある。
  - コードは、時間切れのときに止まったスレッドを `join` せずに離す（`tests/open_062_http.rs:41-59` の `bounded`、`tests/l31_http_serve_and_helpers.rs:133-148` の `Server::drop`）。止まった待ちで後片付けごと止まらないための、意図した選択である。しかし方針の 2 段落目は「中断の印を立てるか、ロックを放してから失敗させる」までで、スレッドを待たないことを書いていない。
  - 直前の節（順序を与えるスケジューラ）との違いを示す導入の一文がない。この節は、Rust のテストが実際のスレッドとループバックの通信を待つ場合の決まりである。
- 修正案:
  - 2 段落目に「印で解けない待ちがあるので、時間切れのときは止まったスレッドを待たずに離す」を加える。
  - 節の頭に「スケジューラの差し替えで順序を与えられない、実際のスレッドとループバックの通信を待つテストの決まりである」の趣旨の一文を置く。

### 5.【軽微】`open_062_http.rs` のサーバのスレッドの登録の `unwrap` が、離したスレッドで二度目の panic の文言を出しうる

- 場所: `crates/benitoite/tests/open_062_http.rs:125-127`
- 問題: `stopper.send(..).unwrap()` は、受け手（`bounded` の `stops`）が先に捨てられていると panic する。
  - 例: `Server::start` の `wake_rx.recv_timeout(LIMIT)` が時間切れになって閉包が panic し、`bounded` が `resume_unwind` で戻る。その後に、遅れて起動したサーバのスレッドが送る。
  - このとき、テストの結果とは無関係の panic の文言が出力に混ざり、最初の失敗を読み取りにくくする。テストの結果は変わらない。
- 修正案: `let _registered = stopper.send((Arc::clone(&interrupted), wakeup.clone()));` とする。登録できなかったときは、外側の上限が既に過ぎているので、印を立てる相手がいない。

### 6.【軽微】`open_062_r14_client_header_returns_invalid_http_data` の `accept` は、クライアントが接続せずに終わると 120 秒待ってから、原因を示さずに落ちる

- 場所: `crates/benitoite/tests/open_062_http.rs:348`
- 問題: スクリプトが接続の前に終わった場合（`Http.get` の前の失敗など）、`listener.accept()` は上限なく待つ。
  - 外側の `bounded` が、120 秒後に「did not finish within 120 s」で落とす。クライアントの `RunEnd` は文言に入らない。
  - 上限はあるので、観点 (1) の「上限のない待ち」ではない。事前点検の補足が意図して残した形でもある。ただし診断が遅く、情報が少ない。
- 修正案（任意）:
  - `listener.set_nonblocking(true)` にして、`LIMIT` まで `accept` と `client.result.try_recv()` を交互に試す。
  - クライアントが先に終わったら、その `RunEnd` を文言に入れて落とす。
  - 受け付けた後は `stream.set_nonblocking(false)` に戻す。

## 確かめて問題がなかった点

- **後片付けの七つの `Drop`**（`runtime_test_support.rs`、`samples.rs`、`cli/mod.rs`、`refinterp/convert.rs`、`refinterp/tests.rs`、`resources/tests.rs`、`l10_console_clock_process.rs`）は、どれも panic しない形になった。`resources/tests.rs` の `PoisonError::into_inner` は計数の値をそのまま使うので、確かめの意味を変えない。
- **L31 の `Server::drop`**:
  - 結果を既に受け取った場合（`start_on_vacant_port` のやり直し、`wait_line` の失敗）は、送り手が捨てられて `Disconnected` になり、すぐに `join` する。
  - `finish` の後は `thread` が `None` で、待たない。
  - `finish` の `join().unwrap()` が panic した場合も、`thread` は取り出し済みなので、二度目の panic は起きない。
  - 待ちは `LIMIT`（30 秒）で終わる。
- **L31 のやり直しの精度**:
  - やり直すのは `main_error == "address in use"` のときだけである。この文字列は、スクリプトが `NetworkErrorKind.AddressInUse` から作る決まった値で、OS の文言に頼らない。
  - いつも `AddressInUse` になる退行は 4 回目で落ち、最後の結果を文言に入れる。
  - 確かめの接続は要求を送らずに閉じる。03-09「失敗の種類」の「接続ごとの失敗」として `accept` が捨てるので、ハンドラは呼ばれない（`Http.bnt` の `serveLoop` は、`accept` の後にだけタスクを起動する）。
  - `serve_returns_network_error_when_port_is_in_use` は変えておらず、種類の分類はそこで確かめ続けている。
  - 残る限界（確かめの接続がほかの相手につながる場合）は、コメントに書いてある。
- **L32 のやり直しの精度**:
  - やり直すのは `"closed port connected"` のときだけで、4 回目は `script_output` の確かめで落ちる。
  - 閉じたポートで `Http.get` が `Ok` を返すのは、別の相手が HTTP で応答したときだけである。したがって、決まって起きる退行は隠れない。
  - `run_script` の確かめ（終了の種類、`main_error`、報告、標準エラー出力）は `script_output` に移しただけで、変わっていない。
- **`runtime_builtins.rs` のゲート**: 結果によらずロックを放してから、時間切れの真偽値を返す。ゲートのスレッドの中では panic しない。元のアサーションはすべて残り、時間切れでないことの確かめが加わった。
- **`open_062_http.rs` の `bounded`**:
  - 外側 120 秒と内側 10 秒の重なりは解けた。最も長い r04 でも、内側の待ちの和は約 70 秒である。
  - 時間切れのときは、届いた組のすべてに印を立てて起こし、`what` を文言に入れる。
  - 成功のときは今までどおり `join` して、閉包の panic を伝える。
  - r04 のゲートは、閉包が巻き戻ると `release_tx` が捨てられて放される。
- **L10 の `TZDIR`**: 期待値の判定（`/usr/share/zoneinfo/Asia/Tokyo` の有無）と、子プロセスが読む場所が揃った。
- **アサーションの弱め**: 所見 1 の `completed` への置き換えのほかに、確かめを弱めた箇所はない。この置き換えは `study.md` 1.3 節の意図どおりで、`idle(None)` が `Progress` を返す確かめは残っている。
- **lint**:
  - 変えた `src/` のファイルは `#[cfg(test)]` のモジュールで、新しい `unwrap`・`expect` はない。
  - `tests/` の各ファイルは `clippy::unwrap_used`・`clippy::panic` を許しており、`expect` は新しく使っていない。
  - `unsafe` はない。
  - 新しいコメントは日本語で、作業の ID や TODO の番号を引いていない。
- **07-03 の追記**:
  - 既存の見出しを変えずに、新しい見出しを加えた。
  - 四つの方針のそれぞれに【方針】と「理由: 〜。」の 1 文があり、常体で書かれている。
  - R10 の「回収の強制の構成でだけ上限を延ばさない」も書かれており、今のテストに構成で上限を変える箇所はない。

## 判定

取り込みは妥当だが、所見 1（要修正）を追いの修正で直すことを求める。変えたテストに、退行の場合に止まらない空回りを持ち込んでおり、この作業の目的（時間に依存するテストに上限を付ける）と、07-03 に足した方針の両方に反するからである。修正は `completed` に数行を足すだけで済む。

所見 2・3 は、同じ追いの修正で扱うことを勧める。所見 3 で (a) を選ぶなら、残りのファイルを docs/todo の項目にする。所見 4〜6 は任意である。
