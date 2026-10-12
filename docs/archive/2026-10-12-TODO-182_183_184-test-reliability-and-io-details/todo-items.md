# 扱う項目の本文の写し

docs/todo は非公開のリポジトリなので、扱う項目の本文を 2026-10-12 に写した。出どころの資料は docs/todo の `sources/` にある。

### TODO-182 間欠的に落ちるテストと、時間に依存するテスト

- 状態: 要検証
- 出どころ: later-issues の 41、later-issues の 59、later-issues の 61、later-issues の 90、later-issues の 92、later-issues の 93、later-issues の 94、later-issues の 103

負荷や時刻の巡り合わせで落ちる、または落ちずに止まるテストをまとめる。どれも、テストの作りの弱さか、処理系の誤りかを分けてから直す。`src/`・`tests/`・`testdata/`・`skill/` で始まるパスは `crates/benitoite/` を起点とし、ほかのパスはリポジトリの根を起点とする。

- 回収の強制のテストの中止（later-issues の 41。要再現）: R15 の後の `check.sh` で、回収の強制の構成のライブラリのテストが non-unwinding panic（SIGABRT）で一度落ちた。再現せず、原因は確かめていない。debug のビルドのスタックの大きさを疑っている。再発したら `RUST_BACKTRACE` と `--test-threads` で絞る。
- `open_062` の R13 のテスト（later-issues の 103。要再現）: `tests/open_062.rs:933` の `open_062_r13_ready_line_arrives_while_another_task_computes` が、回収の強制の段で負荷の高いときに「timed out waiting on channel」で落ちた（単独では通る）。時間に依存する作りの疑いがあり、調べた記録はない。テストは `STALL_TIMEOUT`（同 92 行）の `recv_timeout` を使ったままである。
- 余計な起こしで落ちうる受け取り（later-issues の 59 の 1 点目）: `src/runtime/sched/parts/tests.rs:235-237` は、`idle(None)` の直後に `parts.workers.try_recv().unwrap()` で受ける。EINTR などの余計な起こしがあると落ちうる。`completed()` を繰り返して受ける形に直す。
- 退行で止まるゲートのスレッド（later-issues の 61 の 3 点目）: `tests/runtime_builtins.rs:135-140` のゲートのスレッドは、`receive.recv().unwrap()` で時間の上限なく待つ。退行すると、ゲートが出力先のロックを握ったまま `run_program` の panic 境界が書き出し用のスレッドを join し、テストが失敗せずに止まる。`recv_timeout` を使うか、assert の前に release を送る。
- 一時ディレクトリの `Drop` の二重の panic（later-issues の 61 の 4 点目）: `src/builtins/funcs/runtime_test_support.rs:69-72` が `remove_dir_all(..).unwrap()` とする。同じ形は `src/builtins/funcs/samples.rs:240-243`、`src/refinterp/convert.rs:798-801`、`tests/l10_console_clock_process.rs:103` にもある。panic の巻き戻しの途中で削除に失敗すると中止する。`let _ =` にするか、`std::thread::panicking()` のときだけ無視する。
- HTTP サーバのテストの競合（later-issues の 90 の (2)。要確認）: 終了後の `connect(...).is_err()` が偶然に失敗しうる点と、413・431 を返す接続の RST の扱い。確かめていない。
- L31 のテストのサーバ（later-issues の 92）: `tests/l31_http_serve_and_helpers.rs:133-139` の `impl Drop for Server` は、旗を立てて起こすだけでスレッドを join しない。空いたポートを選んでから待ち受けるまでの間の競合も残る。
- HTTP クライアントのテストの競合（later-issues の 93 のテストの分）: 時間切れのテストで、要求を書き終える前に 100 ms を過ぎる競合。閉じたポートを再利用する競合。失敗の注入の名前の照合で、IPv6 の名前が角括弧付きになって当たらない可能性。
- `open_062_http.rs` の時間の上限の重なり（later-issues の 94）: `tests/open_062_http.rs:22` の上限（10 秒）と、`bounded`（同 39-45 行。20 秒の `recv_timeout` の `unwrap`）が重なり、どこで止まったかが `bounded` の `unwrap` にまとまって分かりにくい。止まったときはスレッドが漏れる。診断の分かりやすさだけの問題である。

### TODO-183 ランタイムの単体テストの確かめと観測の穴

- 状態: 未着手
- 出どころ: later-issues の 43、later-issues の 44、later-issues の 58、later-issues の 60、later-issues の 61、later-issues の 83

VM・ランタイム・組み込みの関数の単体テストのうち、誤った実装を通してしまうもの、テストの道具が誤りを捨てるもの、確かめる経路がないものをまとめる。`src/`・`tests/`・`testdata/`・`skill/` で始まるパスは `crates/benitoite/` を起点とし、ほかのパスはリポジトリの根を起点とする。

- 窓の clear と、除いた入力の件数（later-issues の 43）: (a) `src/vm/tests.rs:1375` の `tail_window_old_objects_are_cleared_at_collection` は、窓が縮む場合に窓の外を clear せず truncate だけする実装を捕まえない。(b) `src/bytecode/codegen/tests.rs:55` の `corpus_prototype_entries_use_only_parameters` は、検査を通らない入力を黙って除き、件数の下限を `programs > 0`・`examples > 0` でしか確かめない。下限を固定する。
- 検証器のテストの弱さ（later-issues の 44）: `tests/verify.rs:118-136` の無作為の変異（kind 7・8）は `must_reject = false` で、範囲の外でも拒むことを主張しない。拒んだ理由（message・pc）を確かめない（同 150-158 行）。ゴールデンの変異は V4・C・分岐表・組み込みと構成子の番号を含まない。`src/bytecode/verify.rs:657-693` の every_opcode は、範囲の外を A の欄だけで確かめる。`CON` の arity が 1 以上であることを確かめない（安全性には関わらない）。検証器は ADR 0315 でテストの道具になったので、優先度は低い。
- 筋書きの実行器が捨てる誤り（later-issues の 58 の 1 点目）: `src/runtime/sched/testing.rs:370-374` の `ScriptWorkers::advance` は、`advance_time` の誤りを `Err(_) => return progressed` で捨てる（コメントは、凍結した口のためと説明する）。筋書きの誤りが、行き詰まりの `ScriptExhausted` まで見えない。`WorkerExec` に既定の本体を持つ確認の関数（`check_progress`）を足して直す。テストの道具の弱さで、実害は小さい。
- 預けた書き込みの記録（later-issues の 60 の R27 services.rs の点）: `src/runtime/io/services.rs:129-132` で `output_trace`（`cfg(test)`）に積むのは、すぐに受け付けた書き込みだけで、預けて後から受け付けた書き込みは記録されない。
- 筋書きが尽きる誤りの報告の遅さ（later-issues の 60 の R27 sched/testing.rs の点）: 筋書きの部品を渡すといつも `Counted` になり、`src/runtime/io/event.rs:115-125` の `wait_counted` が 5 秒の `wait_timeout` で待つ。テストの失敗の報告が遅いだけで、実害はない。
- `readLine` の上限の経路（later-issues の 61 の 2 点目）: `readBytes` の `InputTooLarge` にはテストがある（`src/builtins/funcs/file/path_tests.rs:728-735`、同 763 行）が、`readLine`（`complete_line` の `check_input`）の経路を通すテストは見当たらない。1 GiB の入力が要るので、上限を差し込む口を設けるかを含めて決める。
- `Process.run` の出力の上限の経路（later-issues の 83 の (1)）: 集めた出力が上限（2^30 バイト）を超える経路のテストがない。上限を差し込む口がなく、`src/builtins/funcs/file.rs:208-216` の `read_all_limited` は `MAX_STRING_BYTES` を直接使う。

### TODO-184 IO のモジュールと HTTP のクライアントの細部

- 状態: 未着手
- 出どころ: later-issues の 61・77・79・81・83・93（61 は 1 点目、83 は (2)、93 はテスト以外の点）、取り込み漏れの調査の C-8

初回リリース版の IO のモジュール（`File`・`Process`・`Clock`）と HTTP のクライアントの作業の確認で見つかり、直さずに残した点をまとめる。設計書の記述と実装のずれ、失敗の扱いの定めの不足、事実の確認、軽微なコードとテストの点を含む。

- `File.readLine` の上限の判定が、行末を含めた長さで行われる。`read_line_limited`（`crates/benitoite/src/builtins/funcs/file.rs:218-224`）は行末を含めて `MAX_STRING_BYTES` + 1 バイトまで読み、`complete_line`（同 270-293）は行末を除く前に `check_input`（同 286 行）で判定する。このため、内容がちょうど 2^30 バイトで LF の付いた行も InputTooLarge になり、02-09「一つの操作で作る値の大きさの上限」より 1〜2 バイト厳しい。上限を内容の長さで数えるように直すか、行末を含めて数えると 02-09 に書き添えるかを決める。出どころ: later-issues の 61（1 点目）。
- `File` の上限の失敗の種類が揃っていない。`walk`・`listDirectory` の項目の数の超過は InputTooLarge、`readLines` の行の数の超過は ValueTooLarge になる。どちらに揃えるかを決める（今のコードで揃えた跡は確かめられなかった。要確認）。軽微な点として、`info_done` の欄の位置の定数を子のモジュールに置かず直書きの並びにしている（`file.rs:899-915`）、`exists` の `///` の根拠が実装プランを指す（`file.rs:418`）、不正な UTF-8 の名前のテストが環境によって飛ぶ。出どころ: later-issues の 79。
- `File.Writer` の書き出しの失敗の後の扱い。出どころ: later-issues の 81。
  - `writer_work` の `Stop::Internal` の文が、`writeLine`・`writeChunk` でも "File.write requires ..." になる（`file.rs:1196`・`1202`）。
  - `BufWriter` の途中の書き出しが失敗した後も残りがバッファに残り、後の書き込みや解放の flush が書き直す。書き込みが失敗した後の扱いは 03-07 に定めがない。
  - close(2) が遅れて返す誤り（NFS など）を、drop で捨てている。
  - `closeWriter` が解放を待つ間にタスクが取り消され、ほかに待つ側がいないと、記録した解放の失敗の理由が誰にも取り出されず黙って捨てられる。01-10 の解放の失敗の報告の規則と合うかを決める（設計者に示す）。
- 孫のプロセスがパイプを持ち続けると `Process.run` が返らない。Rust の `Command::output` と同じ性質であるが、03-07 に書いていない。03-07 に書くか、待ち方を改めるかを決める。出どころ: later-issues の 83（(2)）。
- jiff の内部のキャッシュと地方時の確認。出どころ: later-issues の 77、取り込み漏れの調査の C-8。
  - jiff はシステムのタイムゾーンを内部の static に 5 分保持する。AGENTS.md「大域の状態」の例外にも 03-01・03-07 にも書いていない。例外の一つとして書くか、依存のクレートの中の大域の状態として 03-01 などに一言書くかを決める。
  - 【要検証】タイムゾーンのデータを持つ Linux で `Clock.localOffsetMinutes` などの地方時が正しい値を返すか。初回リリース版の作業は macOS でだけ確かめ、実装プランの 10-16 の【要検証】が残った。Linux のコンテナで `scripts/check.sh` が通ったことは、zoneinfo がない環境では期待を 0 にするテストなので、この確認の代わりにならない。
  - 軽微なテストの点（`readAllLines`・`readAllBytes` の InputTooLarge のテスト、UTF-8 の二重の検査、テストの `ScriptDirectory::drop` の `unwrap`、`TZDIR`、`process/tests.rs` の `cfg(unix)`）は、`ScriptDirectory` が今のソースに見当たらず、残っているか確かめていない（要確認）。
- HTTP のクライアントの細部。`"supported architecture"` の文が `text` の子のモジュールの外にある（`crates/benitoite/src/builtins/funcs/http_client.rs:456`）。`timeoutMilliseconds` が `i64::MAX` のときのソケットの時間の設定を確かめていない（`http_client.rs:184` で `Duration::from_millis` に渡すだけで、テストがない。要確認）。出どころ: later-issues の 93（テスト以外の点）。

