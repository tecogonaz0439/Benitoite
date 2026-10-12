# 実装プラン

作業は直列に進める。どの作業も、メインの作業ディレクトリで作業ごとのブランチ（`mod/<作業>`）の上で Codex（GPT-6.1-Sol、high）が実装し、終えたらすぐ `san_benito` に取り込む。レビュー（Opus）は取り込んだコミットを `git show` で読み、直しは後のコミットで行う。作業ごとには関係するテスト・回収の強制の構成の関係するテスト・clippy・fmt だけを走らせ、`scripts/check.sh` と性能の短い測定は最後に一度だけ行う。設計書・言語リファレンス・CHANGELOG の未リリースの節は、各作業が同じ変更で直す。テストを加えるときは、スキル `test-audit` の作成時の関門を通す。

前の改造（`docs/archive/2026-10-11-TODO-185_201_202-regex-and-http-details/README.md` の「所要時間」）で、回収の強制の構成でだけ落ちるテストが最後の検査で初めて見つかった。そのため、各作業の完了の条件に、関係するテストを回収の強制の構成で走らせるコマンドを含める。以下の `$GCS` は次の機能の指定を表す（`scripts/check.sh` の「gc-stress (mark-sweep)」と同じ構成）。

```sh
GCS='--no-default-features --features gc-mark-sweep,heap-verify,gc-stress'
```

ループバックの TCP を使うテスト（`l30_http_server`・`l31_http_serve_and_helpers`・`l32_http_client`・`open_062_http`）を含む作業（X1・X5）は、Codex をネットワークを許した設定で起動する。

どの作業も VM の命令の振り分けと呼び出しの経路を変えないので、作業ごとの fib・loop の短い測定（`tools/bench/gate.py`）は要らない。最後に一度だけ行う。

## 作業 X1: 時間に依存するテストと後片付けの直し（TODO-182）

テストだけを変える。本番のコードは変えない。詳細は `study.md` の 1 節、判断は `decisions.md` の R10・R12。

内容:

- 巻き戻しの途中で panic しうる後片付けを直す（1.1・1.5 節）。次の `Drop` を、失敗を捨てる形（`let _removed = std::fs::remove_dir_all(..)`）にする。`src/builtins/funcs/runtime_test_support.rs` の `TempDir`、`src/builtins/funcs/samples.rs` の `TempDirectory`、`src/refinterp/convert.rs` の `TempDirectory`、`src/refinterp/tests.rs` の `Directory`、`src/cli/mod.rs` の `Directory`、`tests/l10_console_clock_process.rs` の `ScriptDirectory`。`src/runtime/io/resources/tests.rs` の `Resource::drop` のロックは `unwrap_or_else(std::sync::PoisonError::into_inner)` にする。コメントに「巻き戻しの途中で二度目の panic を起こさない」と書く。
- `src/runtime/sched/parts/tests.rs` の `completion_wakes_idle_without_deadline_and_expired_timer_does_not_wait` で、イベントループを持つ場合も `completed` で受ける（1.3 節）。
- `tests/runtime_builtins.rs` の `injected_parts_wait_for_output_before_reading_stdin` のゲートのスレッドは、`recv_timeout(120 秒)` で待ち、時間切れでもロックを放してから終える（1.4 節）。
- `tests/l31_http_serve_and_helpers.rs`（1.7 節）:
  - `Server::drop` は、結果の channel を `LIMIT` で待ち、受け取れたときだけスレッドを `join` する。
  - `vacant_port` を使う起動を一つの補助にまとめ、`Http.serve` が待ち受けの失敗（ポートが使われている）で終わったときに限り、新しいポートで 3 回までやり直す。ほかの失敗ではやり直さない。
- `tests/l32_http_client.rs` の `closed_listener_port_returns_connection_refused` は、スクリプトの結果が `"closed port connected"` のときに限り 3 回までやり直す（1.8 節）。
- `tests/open_062_http.rs` の `bounded` の上限を 120 秒にし、時間切れの文言に待っていたものを書く。内側の待ち（`Server::port`・`blocked_rx`・読み取り）の `unwrap` も、待っていたものを文言に含める。時間切れのときは中断の印を立ててから失敗させる（1.9 節）。
- `tests/l10_console_clock_process.rs` の `real_clock_reads_tz_without_changing_parent_environment` で、子プロセスの環境から `TZDIR` を除く（`study.md` の 3.5 節）。
- `tests/open_062.rs` は変えない（1.2 節）。
- 文書: 07-03 の「順序を与えるスケジューラと仮想の時間（初回リリース版）」の後に、実時間の待ちの上限と後片付けの決まりを【方針】として足す（上限は停止の検出にだけ使い、内側から外側へ長くする。時間切れの文言に待っていたものを書く。後片付けの `Drop` は panic しない。ポートの競合は競合と分かる結果のときだけやり直す）。CHANGELOG は変えない（利用者から見える変化がない）。

足すテスト: なし（既存のテストの作りを直す）。

完了の条件（リポジトリの根で実行）:

```sh
cargo test -p benitoite --lib -- runtime::sched::parts runtime::io::resources builtins::funcs refinterp cli::
cargo test -p benitoite --test runtime_builtins --test l10_console_clock_process --test l31_http_serve_and_helpers --test l32_http_client --test open_062_http --test open_062 --test l30_http_server
cargo test -p benitoite $GCS --lib -- runtime::sched::parts runtime::io::resources builtins::funcs refinterp
cargo test -p benitoite $GCS --test runtime_builtins --test open_062 --test open_062_http --test l31_http_serve_and_helpers --test l32_http_client
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo fmt --all --check
```

`open_062` は回収の強制の構成で 3 回続けて走らせ、時間を記録する（later-issues の 103 の観察）。

## 作業 X2: ランタイムの単体テストの穴（TODO-183 のうち X3 に含めない点）

詳細は `study.md` の 2 節、判断は `decisions.md` の R11。

内容:

- `src/bytecode/codegen/tests.rs` の `corpus_prototype_entries_use_only_parameters` で、ゴールデンテストのプログラム・仕様の例・標準ライブラリの原型の三つの件数の下限を、実装のときに数えた値で固定する（`>=`）。下限を下げるときは理由を書くようコメントに書く（2.2 節）。
- `tests/verify.rs` の `golden_programs_and_seeded_single_site_mutations` で、kind 0・1・2・6 の変異を拒んだとき、`VerifyError` の `proto` と `pc` が壊した位置と一致することを確かめる（2.3 節）。
- `src/runtime/sched/testing.rs` の `ScriptWorkers::idle` の先頭で、筋書きに誤りが記録されていれば、待たずに `ScriptExhausted` を返す。`advance` のコメントも合わせて直す（2.4・2.6 節）。
- `src/runtime/io/services.rs` の `output_trace` の欄のコメントに、すぐに受け付けた書き込みだけを記録し、預けた書き込みは本物の出力先で確かめると書く（2.5 節）。
- 文書: 設計書と CHANGELOG は変えない（テストとテストの道具だけの変更）。

足すテスト: なし（既存のテストの確かめを強める）。kind 0・1・2・6 の位置の確かめは、検証器の位置の報告を壊すと落ちることを一度確かめる。

完了の条件:

```sh
cargo test -p benitoite --lib -- bytecode::codegen bytecode::verify runtime::sched vm::dispatch::tasks
cargo test -p benitoite --test verify --test open_062 --test runtime_builtins
cargo test -p benitoite $GCS --lib -- bytecode::codegen runtime::sched vm::dispatch::tasks
cargo test -p benitoite $GCS --test open_062
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo fmt --all --check
```

## 作業 X3: 読み取りの上限（TODO-184 の Q1・Q2、TODO-183 の上限の経路）

詳細は `study.md` の 2.7・2.8・3.1・3.2 節、判断は `decisions.md` の Q1・Q2 と R1〜R3。

内容:

- 上限を非公開の関数の引数にする（R1）。`src/builtins/funcs/file.rs` の `read_all_limited`・`read_line_limited`・`check_input`、`src/builtins/funcs/process.rs` の `execute`・`collect_output`・`check_output` に上限の引数を足す。本番の呼び出しは `MAX_STRING_BYTES` を渡す。`src/builtins/funcs/console.rs` の `remaining_input` の上限の確かめと `process.rs` の `check_output` は、`file.rs` の一つの確かめの関数を使う形にまとめる。大域の値も `cfg(test)` の分岐も使わない。
- Q1・R3: `read_line_limited` は上限 + 2 バイトまで読む。`complete_line` は、行末（LF と、その前の CR を一つ）を除いた後の内容の長さで上限を確かめる。LF のないまま `take` で切れた場合も、末尾の CR を除いた長さで確かめる。`File.readLine` と `Console.readLine` の両方に当たる。
- Q2・R2: `File.readLines` と `Console.readAllLines` の行の数の超過を `ResourceError::InputTooLarge { unit: Elements, limit: MAX_LIST_LEN }`（R0903）にする。値を作る前に確かめる位置は今のまま。
- 参照インタプリタ（`src/refinterp/`）が同じ組み込みの関数を通るか、別に上限を持つかを確かめ、別に持つなら同じ規則に揃える。
- テスト:
  - 一行を読む経路: 小さな上限（4 バイトなど）で、表の形のテストを置く。行の例は `abcd\n`・`abcd\r\n`・`abcd`（入力の終わり）・`abcd\r`（入力の終わり）が通り、`abcde\n`・`abcd\r\r\n`・`abcdef`（入力の終わり、上限 + 2 で切れる）が InputTooLarge（関数の名前と上限を確かめる）になる。直す前の数え方では `abcd\r\n` が落ちることを一度確かめる。
  - `Process.run` の上限: `src/builtins/funcs/process/external_tests.rs` で、1 MiB を標準出力に書く `sh` を上限 16 バイトの `execute` で走らせ、返ること（読み捨てが働く）と、上限の確かめが InputTooLarge を返すことを確かめる。
  - `Console.readAll` 系: まとめた確かめの関数を通ることを、小さな上限で一つ確かめる。
  - 行の数の超過: `src/builtins/funcs/file/path_tests.rs` の `oversized_sparse_bytes_and_too_many_lines_stop_before_building_values` の readLines の期待を InputTooLarge に直す。`Console.readAllLines` に同じ大きさ（16 MiB の LF）の標準入力を与える行を足す。
- 文書:
  - 02-09「一つの操作で作る値の大きさの上限」: 一行ずつ読む関数（`File.readLine`・`Console.readLine`）は行末を除いた内容の長さで確かめること、行やディレクトリの項目の数の超過も入力を読む操作の超過（R0903）とすることを書く。
  - 03-07「共通の規則」か `File` の節: 上限は行末を除いた長さで数えると書く。
  - 01-08「資源の不足」の表の「作る値が大きすぎる」の説明が、入力を読む操作のリストの長さを含むかを確かめ、要れば書き足す。02-10 の R0903 の説明も同様。
  - CHANGELOG: Fixed に readLine の上限の数え方、Changed に readLines・readAllLines の行の数の超過の報告が R0903 になったこと。
  - 診断の表や構文の章を変えたら `cargo run -p benitoite --example gen_skill` で Skill の生成物を作り直す。

完了の条件:

```sh
cargo test -p benitoite --lib -- builtins::funcs refinterp runtime::report
cargo test -p benitoite --test l10_console_clock_process --test l13_external_commands --test io_modes --test golden --test reference_examples --test skill_docs
cargo test -p benitoite $GCS --lib -- builtins::funcs
cargo test -p benitoite $GCS --test l13_external_commands --test io_modes
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo fmt --all --check
```

## 作業 X4: `File.Writer` の失敗の後と `Process.run` の文書（TODO-184 の Q3・Q4）

詳細は `study.md` の 3.3・3.4 節、判断は `decisions.md` の Q3・Q4 と R4〜R6。

内容:

- `src/builtins/funcs/file.rs` の `FileWriter` に失敗の状態を持たせる。書き込み（途中の書き出しを含む）が失敗したら、最初の `IoFailure` を記録し、`BufWriter` のバッファを書き出さずに捨てる（`into_parts`）。以後の `write`・`writeLine`・`writeChunk` は記録した失敗を返し、書き込まない。解放（`release`、`closeWriter` と `with` の解放）は、失敗の状態なら書き出さずに閉じ、記録した失敗の文を返す（R4。`closeWriter` の種類は `Other`）。失敗していなければ今のとおり書き出してから閉じる。drop（束縛の文の未解放の Writer を実行の終わりに捨てる）は今のとおり書き出さない。
- `writer_work` に関数の名前を渡し、`Stop::Internal` の文に含める（"File.writeLine requires …" など）。
- `closeWriter` の解放を待つ間に呼んだタスクが取り消されたとき、記録した解放の失敗を捨てて実行が正常に進むことを固定するテストを一つ足す。`src/builtins/funcs/file/resource_tests.rs` の失敗する解放（`FailRelease`）と、仕事の完了を指示する部品（`release_workers`）を使う（R6）。
- テスト（`resource_tests.rs`）:
  - 読み取り専用で開いた実物の `File` を使う既存のテストの形で、大きな書き込み（20,000 バイト）が失敗した後に、バッファに収まる小さな書き込みも同じ失敗を返すこと、`closeWriter` が同じ文の `Result.Error` を返すことを確かめる。直す前のコードでは小さな書き込みが `Result.Ok` を返して落ちることを一度確かめる。
  - 小さな書き込み（バッファに残る）の後に大きな書き込みが失敗し、その後の解放が書き出しを試みないこと（解放の失敗の文が記録した書き込みの失敗と同じであること）を確かめる。
  - `FileWriter` を組み立てる既存のテストを新しい形に直す。
- 文書:
  - 03-07「File」: 書き込みの失敗の後の扱い（Q3）、`closeWriter` が返す誤り（R4）、close(2) の誤りを捨てること（R5）、未解放の Writer を実行の終わりに捨てるときは書き出さないこと。
  - 03-07「Process」: 子が終わっても孫が標準出力・標準エラー出力を開いたままだと `Process.run`・`Process.shell` が返らないこと、`Task.withTimeout` で上限を付けられること（Q4）。`collect_output` の `///` の根拠が合うことを確かめる。
  - 01-10「解放の失敗」: `close` などの関数が解放を待つ間に呼んだタスクが取り消されたときは、その解放の失敗を実行時エラーにも報告の対象にもせず捨てる（R6）。
  - 言語リファレンス（`docs/reference/benitoite.md` の IO の「A few behaviors worth knowing」）: Writer の失敗の後と、孫のプロセスの一文。
  - CHANGELOG: 互換性のない変更の表（Some functions and commands also behave differently）に、Writer の書き込みが失敗した後の書き込みと `closeWriter` が同じ失敗を返すこと（移行の方法: 最初の失敗で書くのをやめ、開き直す）。
  - 07-01 の `File` の記述と 01-07 の IO の失敗の記述が Q3 と食い違わないかを確かめる。

完了の条件:

```sh
cargo test -p benitoite --lib -- builtins::funcs::file runtime::io::resources vm::dispatch::tasks
cargo test -p benitoite --test runtime_builtins --test io_modes --test golden --test reference_examples --test spec_examples
cargo test -p benitoite $GCS --lib -- builtins::funcs::file runtime::io::resources
cargo test -p benitoite $GCS --test io_modes
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo fmt --all --check
```

## 作業 X5: jiff の文書と HTTP のクライアントの細部（TODO-184 の残り）

詳細は `study.md` の 3.5・3.6 節、判断は `decisions.md` の R7〜R9。

内容:

- 文書（R7）: 03-01「使う Rust のクレート」の jiff の項に、システムのタイムゾーンのキャッシュ（5 分）と zoneinfo のデータベースの二つの内部の大域の状態を、出典（jiff 0.2.37 の `src/tz/system/mod.rs`・`src/tz/db/mod.rs`）を添えて書く。03-07「Clock」に、同じプロセスの中ではシステムのタイムゾーンの変更が最大 5 分遅れて `Clock.localOffsetMinutes` に現れることを書く。AGENTS.md「大域の状態」に、規約は処理系のコードに当てはまり、依存のクレートの内部の大域の状態は 03-01 に書くと一文足す。
- `src/builtins/funcs/http_client.rs` の `"supported architecture"` を `text` の子のモジュールに移す。
- R8: ureq に渡す時間を 2^40 ミリ秒で頭打ちにする（定数に名前を付け、理由をコメントに書く）。`tests/l32_http_client.rs` に、`timeoutMilliseconds` を `i64::MAX`（Benitoite の `Integer` の最大）にした要求を、応答するループバックのサーバへ送り、`Result.Ok` を受け取るテストを足す。03-09「クライアント」に頭打ちを書く。
- R9: HTTP のクライアントは、URL の host から IPv6 の角括弧を除いた名前で失敗の表を引く。`tests/network_faults.rs` に、表の `::1` に当てた失敗が `http://[::1]:1/` への要求で返る行を足す（直す前は当たらず、接続を試みることを一度確かめる）。02-09「組み込みの操作とハンドラ表」の表の説明に、IPv6 の名前は角括弧を除いた形で引くと書き添える。
- CHANGELOG: 変えない（R8 は実行の時間として区別できず、R9 はテスト用の表だけの変更）。

完了の条件:

```sh
cargo test -p benitoite --lib -- builtins::funcs::http_client runtime::sched::parts
cargo test -p benitoite --test l32_http_client --test network_faults --test l10_console_clock_process --test spec_examples
cargo test -p benitoite $GCS --test l32_http_client --test network_faults
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo fmt --all --check
```

## 最後に行うこと

1. `scripts/check.sh --base 1ca0f7b --dry-run` で選ばれる検査と理由を確かめ、設計者に知らせてから `scripts/check.sh --base 1ca0f7b` を走らせる。前の改造では 1 回 40〜50 分だった。止まったとき（終了状態 3）は、AGENTS.md「テストの運用」に従って設計者に尋ねる。
2. 性能の短い測定: 改造の前（1ca0f7b）と後の `examples/bench_run` で、`tools/bench/gate.py` の fib・loop を交互に走らせる（07-02「性能の関門」）。VM は変えないので差が出ない見込みである。記録は `tools/bench/results/` に置き、本ディレクトリの README の状態に結果を書く。
3. docs/todo（`docs/todo/README.md` の決まりに従い、`docs/todo/` の中でコミットする）:
   - TODO-182・183・184 を閉じる。扱わなかった点（`decisions.md` の R11）は、閉じる理由とともに項目に書く。
   - 新しい項目を加える: HTTP サーバの段階的な閉じ方（413・431 などで読まなかった要求の残りがあるとき、書き終えた後に読み取りの側を上限付きで読み捨ててから閉じる。RFC 9112 §9.6）。close(2) の誤りを `closeWriter` で返すか（R5 の設計者の確認の結果による）。
4. 本ディレクトリを `git mv` で `docs/archive/` へ移す。

### 任意: Linux の地方時の確認（TODO-184 の【要検証】）

設計者が了承したときだけ行う。オーケストレータは自分で走らせない。

- 目的: タイムゾーンのデータを入れた Linux で、`Clock.localOffsetMinutes` が `TZ=Asia/Tokyo` に 540 を返すこと（`tests/l10_console_clock_process.rs` の `real_clock_reads_tz_without_changing_parent_environment`）を確かめる。あわせて、macOS で飛ぶ不正な UTF-8 の名前のテスト（`study.md` の 3.2 節）と、`l30_http_server`（1.6 節の RST の観察）を走らせる。
- 手順の例（arm64 の Linux。podman は `/opt/podman/bin/podman`）:

  ```sh
  podman machine start
  podman run --rm -v "$PWD":/src:ro -w /work docker.io/library/rust:1.98.1-bookworm bash -c '
    apt-get update && apt-get install -y --no-install-recommends tzdata &&
    cp -a /src/. /work && cd /work &&
    cargo test -p benitoite --test l10_console_clock_process --test l30_http_server &&
    cargo test -p benitoite --lib -- builtins::funcs::file::path_tests'
  ```

  ソースを写してからビルドし、手元の `target/` を書き換えない。`rust-toolchain.toml` の 1.98.1 と同じ版の公式のイメージを使う（タグの名前は取得のときに確かめる）。テストの出力に「invalid UTF-8 filename cases skipped」が出ないことと、l10 のテストが通ることを確かめる。
- 見込みの費用: イメージの取得が約 1.5 GB（初回だけ）、依存とテストのビルドが 10〜20 分、コンテナの中の `target/` が 3〜5 GB（コンテナを消せば残らない）。podman の仮想機械のメモリは 4 GB 以上を要する見込みである。結果は本ディレクトリの README の状態と、docs/todo の TODO-184 を閉じるときの記録に書く。
