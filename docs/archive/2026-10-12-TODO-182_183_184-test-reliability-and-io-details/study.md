# 調査（TODO-182・183・184）

2026-10-12 に、`todo-items.md` の各点を HEAD 1ca0f7b のコードで確かめた。パスは `crates/benitoite/` を起点とする（`docs/`・`AGENTS.md` などはリポジトリの根から）。行番号は 1ca0f7b のものである。

分類は次の五つとする。

- テストの直し: テストの作りの弱さを直す。本番のコードは変えない。
- 実装の直し: 本番のコードを変える（テストも足す）。
- 文書だけ: 設計書・言語リファレンス・コメントに書く。
- 既に直っている: 今のコードでは当たらない。
- 扱わない: 直さない。理由を書く。

決めた点の理由は `decisions.md` の「推奨どおりとした問い」にも短く書いた。

## 1. TODO-182 間欠的に落ちるテストと、時間に依存するテスト

### 1.1 回収の強制のテストの中止（later-issues の 41）

- 今の状態: 再現の記録はない。落ちたときの文言「thread caused non-unwinding panic. aborting.」は、Rust がスタックの溢れではなく、巻き戻しの途中の `Drop` で二度目の panic が起きたときなどに出すものである（スタックの溢れは「has overflowed its stack」になる）。ライブラリのテストには、後片付けで panic しうる `Drop` が次の七つある。
  - `src/builtins/funcs/runtime_test_support.rs:69-73`（`TempDir`、`remove_dir_all(..).unwrap()`）
  - `src/builtins/funcs/samples.rs:240-244`（`TempDirectory`、同じ形）
  - `src/refinterp/convert.rs:795-799`（`TempDirectory`、同じ形）
  - `src/refinterp/tests.rs:407-411`（`Directory`、同じ形）
  - `src/cli/mod.rs:792-796`（`Directory`、同じ形）
  - `src/runtime/io/resources/tests.rs:38-42`（`Resource`、`counts.lock().unwrap()`。ロックが壊れていると panic する）
  - 統合テストの `tests/l10_console_clock_process.rs:101-105`（`ScriptDirectory`、同じ形）
- 原因の見立て: 何かのテストが一度失敗し、その巻き戻しの途中で上の `Drop` が二度目の panic を起こし、テストのバイナリ全体が中止したと見るのが、文言と合う。最初の失敗の内容は、中止で捕らえた出力ごと失われた。最初の失敗が何だったかは確かめられない。
- 直し方: テストの直し。上の `Drop` を、失敗を捨てる形（`let _removed = ...`、ロックは `unwrap_or_else(PoisonError::into_inner)`）にする。ほかのテストのファイルが既に使っている形に揃える。これで、同じことが起きても、最初に落ちたテストの名前と内容が報告に残る。原因の再現は試みない。

### 1.2 `open_062` の R13 のテスト（later-issues の 103）

- 今の状態: `tests/open_062.rs:933` のテストの待ちは、すべて `receive`（同 90-98 行）を通り、上限は `STALL_TIMEOUT` の 120 秒（同 89 行）である。時間切れの文言は「hang detected while waiting for …」になり、later-issues の 103 の「timed out waiting on channel」（`recv_timeout` の誤りをそのまま `unwrap` したときの文言）は出ない。待ちの形は、0.0.1 のコミット（1f0e3d03）の時点でこの形になっていた。
- 残る時間の依存: 筋書きの実行器が、出力の知らせを 5 秒だけ待つ（`src/runtime/io/event.rs:129-140` の `wait_counted`、`src/runtime/sched/testing.rs:403-416`）。この 5 秒を過ぎると「scheduler script exhausted …」で落ちる。
- 直し方: 既に直っている（待ちの統一）。5 秒の待ちは、筋書きの誤りを報告するまでの時間でもあり（1.12 節の later-issues の 60 の点）、延ばすと誤りの報告が遅れるので変えない。X1 の完了の条件で、このテストを回収の強制の構成で走らせる。再び落ちたら、文言から止まった待ちが分かる。

### 1.3 余計な起こしで落ちうる受け取り（later-issues の 59 の 1 点目）

- 今の状態: `src/runtime/sched/parts/tests.rs:234-240`。イベントループを持つ場合（`poll`）だけ、`idle(None)` の直後に `try_recv().unwrap()` で受ける。持たない場合は既に `completed`（同 78-86 行）で受けている。
- 直し方: テストの直し。両方の場合を `completed` で受ける。`idle(None)` が `Progress` を返すことの確かめは残す。

### 1.4 退行で止まるゲートのスレッド（later-issues の 61 の 3 点目）

- 今の状態: `tests/runtime_builtins.rs:134-139` のゲートのスレッドは、`receive.recv().unwrap()` で上限なく待つ。
- 直し方: テストの直し。`recv_timeout`（120 秒）で待ち、時間切れでもロックを放してからスレッドを終える。ロックを放せば `run_program` が終わり、後の `assert` が失敗として報告する。

### 1.5 一時ディレクトリの `Drop` の二重の panic（later-issues の 61 の 4 点目）

- 1.1 節と同じ直しに含める。`todo-items.md` が挙げた四つのほか、`src/refinterp/tests.rs:407` と `src/cli/mod.rs:792` も同じ形だった。

### 1.6 HTTP サーバのテストの競合（later-issues の 90 の (2)）

- 終了後の `connect(...).is_err()`: 今の `tests/` には見当たらない。既に直っている（消えている）。
- 413・431 を返す接続の RST: `tests/l30_http_server.rs:126-138` の `request` は、RST で終わっても先に応答を受けていれば通す。サーバは `shutdown(Both)` の後に閉じる（`src/runtime/io/http.rs:604-615`）。読まなかった要求の残りがあると RST になり、OS によっては、クライアントがまだ読んでいない応答が RST で消えうる。今のテストの要求は小さく、431 の 64 KiB の行の場合でも残りは数バイトで、落ちた記録はない。
- 直し方: 扱わない。テストの側だけでは、応答が消える場合を防げない。防ぐには、サーバが書き終えた後に読み取りの側を少し読み捨ててから閉じる（RFC 9112 §9.6 の段階的な閉じ方）実装の直しが要り、この改造の範囲を超える。docs/todo に新しい項目として残す（「最後に行うこと」）。Linux のコンテナの確認（plan.md の最後の任意の手順）で `l30_http_server` も走らせて観察する。

### 1.7 L31 のテストのサーバ（later-issues の 92）

- 今の状態: `tests/l31_http_serve_and_helpers.rs:133-139` の `Drop` は、印を立てて起こすだけで、スレッドを待たない。`vacant_port`（同 197-203 行）は、空いたポートを選んで閉じた後に `Http.serve` へ渡すので、その間にほかのテストが同じポートを取る競合が残る。`Http.serve` は選んだポートを返さないので、ポート 0 を渡す形にはできない。
- 直し方: テストの直し。`Drop` は、結果の channel を上限（`LIMIT`）付きで待ち、受け取れたときだけ `join` する（受け取れないときは待たずに離す）。`vacant_port` を使う起動は、待ち受けの失敗（ポートが使われている）で終わったときに限り、新しいポートで 3 回までやり直す補助にまとめる。

### 1.8 HTTP クライアントのテストの競合（later-issues の 93 のテストの分）

- 時間切れのテストの競合: `tests/l32_http_client.rs:495-520` は、サーバが要求を受け付けない形に改めてあり（FLNX、ADR 0335）、要求を書き終える前の時間切れでも `TimedOut` になる。既に直っている。
- 閉じたポートの再利用: `tests/l32_http_client.rs:522-542`。スクリプトが待ち受けを閉じてから接続するまでに、ほかのテストが同じポートを取ると、`"closed port connected"` か別の失敗になる。
  - 直し方: テストの直し。結果が `"closed port connected"`（ほかの相手に接続できた）のときに限り、3 回までやり直す。分類の退行（`ConnectionRefused` 以外の種類になる）は、別の文言になるのでやり直さずに落ちる。
- IPv6 の名前の照合: 実装の点なので 3.6 節で扱う。

### 1.9 `open_062_http.rs` の時間の上限の重なり（later-issues の 94）

- 今の状態: `tests/open_062_http.rs:22` の `LIMIT`（10 秒）と、`bounded`（同 39-48 行）の 20 秒の `recv_timeout(..).unwrap()` が重なる。内側の待ちが二つ続けて 10 秒近くかかると、外側の `unwrap` が先に落ち、どこで止まったかが分からない。外側で落ちたときは、内側のスレッドが残る。
- 直し方: テストの直し。`bounded` の上限を内側の上限の和より長く（120 秒）し、時間切れの文言に「何を待っていたか」を書く。内側の `unwrap` も、待っていたものを文言に含める。時間切れのときは中断の印を立ててから panic し、内側の実行を止める。

## 2. TODO-183 ランタイムの単体テストの確かめと観測の穴

### 2.1 窓の clear（later-issues の 43 の (a)）

- 今の状態: `src/vm/tests.rs:1376` のテスト。末尾呼び出しの窓の縮小は `shrink_tail_window`（`src/vm/dispatch.rs:1322-1336`）が、外になる場所を `ctx.clear` してから `truncate` する。`clear` の中の解放の通知（`src/runtime/heap/core.rs:823-831`）は、回収の方式が mark-sweep だけになった今、何もしない（`src/runtime/heap/core/mark_sweep.rs:41`）。`truncate` で根からも外れる。
- 直し方: 扱わない。今の回収の方式では、`clear` を省いた実装と今の実装の振る舞いに差がなく、捕まえるべき誤りがない。差を見るには、テストのためだけの計数の口（`notification_counts` は `pub(super)`）を VM のテストへ開く必要があり、test-audit の関門に反する。later-issues の 43 自身が書くとおり、書き込みの障壁や参照の数を使う回収の方式を加えるときに確かめる。

### 2.2 コード生成のテストの入力の件数（later-issues の 43 の (b)）

- 今の状態: `src/bytecode/codegen/tests.rs:55-113` 以降。検査を通らない入力を除き、件数は `programs > 0`・`examples > 0` でしか確かめない。
- 直し方: テストの直し。ゴールデンテストのプログラム・仕様の例・標準ライブラリの原型の三つの件数の下限を、実装のときに数えた値で固定する（等号ではなく下限。ゴールデンテストを足しても落ちない）。下限を下げるときは理由をコメントに書く。

### 2.3 検証器のテストの弱さ（later-issues の 44）

- 今の状態: `tests/verify.rs:108-175`。必ず拒む変異（kind 0・1・2・6 など）でも、拒んだ位置を確かめない。kind 7・8 は拒むことを主張しない。`src/bytecode/verify.rs:653-691` の every_opcode は A の欄だけを範囲の外にする。
- 直し方: テストの直し（範囲を絞る）。命令の一か所を壊す kind（0・1・2・6）で、`VerifyError` の `proto` と `pc` が壊した位置と一致することを確かめる。それ以外は扱わない。理由: 検証器は ADR 0315 で本番の読み込みの経路から外したテストの道具であり、kind 7・8 に拒むことを主張させるには、検証器と独立したオペランドの表をテストに持つ必要がある。表の不整合と生存の情報の位置は、既に `rejects_table_and_liveness_contract_violations_at_the_right_site` が位置まで確かめている。`CON` の arity は安全性に関わらない。

### 2.4 筋書きの実行器が捨てる誤り（later-issues の 58 の 1 点目）

- 今の状態: `src/runtime/sched/testing.rs:366-389` の `advance` は、`advance_time` の誤りを捨てて進行を止める。誤りは筋書きの記録に残る（`set_error` は最初の誤りを残す。同 186-190 行）。その後の `idle`（同 403-416 行）は、知らせを 5 秒待ってから「exhausted」を記録しようとし（最初の誤りが残るので上書きはしない）、`ScriptExhausted` を返す。
- 直し方: テストの道具の直し。`idle` の先頭で、筋書きに誤りが記録されていれば待たずに `ScriptExhausted` を返す。`WorkerExec` に関数を足す案（later-issues の 58）は、凍結した口を変えるので採らない。この直しは、誤りの内容を変えず報告を 5 秒早めるだけで、時間で確かめるテストは作らない（作成時の関門の問い 2 に答えられる退行が時間だけなので）。

### 2.5 預けた書き込みの記録（later-issues の 60 の services.rs の点）

- 今の状態: `src/runtime/io/services.rs:118-125` の `output_written` は、すぐに受け付けた書き込みだけを `output_trace`（`cfg(test)`）に積む。預けた後に受け付けた書き込み（`src/runtime/io/output.rs:195-232` の `poll`）は積まない。`output_trace` を読むのは VM の単体テストの `take_output`（`src/vm/dispatch/test_support.rs:61-63`）だけで、預ける場合（1 MiB を超える出力）を確かめるテストは、本物の出力先（`OutputTarget::Capture`）で確かめている。
- 直し方: 文書だけ。`output_trace` の欄のコメントに「すぐに受け付けた書き込みだけを記録する。預けた書き込みは本物の出力先で確かめる」と書く。記録を足すには、本番のファイルに `cfg(test)` の経路を増やす必要があり、使うテストがない。

### 2.6 筋書きが尽きる誤りの報告の遅さ（later-issues の 60 の sched/testing.rs の点）

- 2.4 節の直しで、誤りが記録された場合は待たなくなる。誤りのないまま本当に尽きた場合の 5 秒は、1.2 節の理由で残す。

### 2.7 `readLine` の上限の経路（later-issues の 61 の 2 点目）

- 今の状態: 一行を読む `read_line_limited`（`src/builtins/funcs/file.rs:218-224`）と、上限を確かめる `check_input`（同 236-245 行）は、`MAX_STRING_BYTES` を直接使う。`File.readLine` と `Console.readLine` が共有する（`src/builtins/funcs/console.rs:60`・`119`）。1 GiB の入力なしに上限の経路を通す手段がない。
- 直し方: 実装の直し（3.1 節の Q1 と一緒に行う）。上限を、非公開の関数の引数として渡す形にする。本番の呼び出しは `MAX_STRING_BYTES` を渡し、テストは小さな上限（4 バイトなど）を渡す。大域の状態も `cfg(test)` の分岐も使わない。テストは、行末の有無と CR・LF の組み合わせを表の形で並べる。

### 2.8 `Process.run` の出力の上限の経路（later-issues の 83 の (1)）

- 今の状態: `collect_output`（`src/builtins/funcs/process.rs:365-370`）は `read_all_limited`（`file.rs:208-216`）を通して `MAX_STRING_BYTES` を使い、`check_output`（`process.rs:372-385`）も直接使う。`Console.readAll` 系の上限の確かめ（`console.rs:183-189`）も同じ形の別の写しで、テストがない。
- 直し方: 実装の直し。`read_all_limited` と、`Process` の実行の関数（`execute`、`process.rs:272`）と、上限の確かめに上限の引数を足す。`Console`・`File`・`Process` の上限の確かめを一つの関数にまとめる。テストは、本物の子プロセス（1 MiB を出す `sh`）を小さな上限で走らせ、返ること（読み捨てが働き、子が満杯のパイプで止まらない）と `InputTooLarge` を確かめる。

## 3. TODO-184 IO のモジュールと HTTP のクライアントの細部

### 3.1 `File.readLine` の上限の数え方（Q1）

- 今の状態: `read_line_limited` は行末を含めて上限 + 1 バイトまで読み、`complete_line`（`file.rs:270-300`）は行末を除く前に確かめる（同 286 行）。
- 直し方: 実装の直し。上限 + 2 バイト（内容と CR・LF）まで読み、行末を除いた後の内容の長さで確かめる。`take` で切れて LF がないときも、末尾の CR を除いた長さが上限を超えるので正しく止まる。`Console.readLine` も同じ関数を通るので同じ規則になる（03-07「共通の規則」は両方を一つの規則で定める）。2.7 節のテストで確かめる。

### 3.2 `File` の上限の失敗の種類（Q2）

- 今の状態: `File.readLines`（`file.rs:868`）と `Console.readAllLines`（`console.rs:217`）の行の数の超過は `CheckedLen::elements` で ValueTooLarge（R0902）になる。`walk`・`listDirectory` の項目の数の超過は InputTooLarge（R0903。`file.rs:722-724`）。テスト `src/builtins/funcs/file/path_tests.rs:705-765` は readLines の ValueTooLarge を正として固定している。
- 直し方: 実装の直し。`File.readLines` と `Console.readAllLines` の行の数の超過を InputTooLarge（単位は要素、上限は 2^24）にする。`Console.readAllLines` も、大きさの決まっていない外部の入力を読む操作なので Q2 の理由が当てはまる。`String.lines` などの純粋な関数は ValueTooLarge のままとする。
- 軽微な点:
  - `info_done` の欄の位置の定数（`file.rs:899-915`）: 扱わない。根拠の決まり（実装プランの 10-15）は保管した実装プランにだけあり、今のコードは `time.rs` と同じく宣言の順をコメントで示す形で揃っている。
  - `exists` の `///` の根拠（`file.rs:418`）: 既に直っている。今は 03-07「File」を挙げる（TODO-174 で直した）。
  - 不正な UTF-8 の名前のテスト（`path_tests.rs:421-434`）: 扱わない。飛ばすのは OS が名前を拒んだときだけで、理由を標準エラー出力に書く。macOS の APFS は拒み、Linux では通る。Linux のコンテナの確認（plan.md の最後の任意の手順）で走らせる。

### 3.3 `File.Writer` の書き込みが失敗した後の扱い（Q3）

- `writer_work` の文言（`file.rs:1189-1217`）: `writeLine`・`writeChunk` でも "File.write requires …" になる。実装の直し。関数の名前を引数で受け取り、文言に含める（処理系の不具合の説明なので `text` には載せない。AGENTS.md「文言」）。
- 失敗の後のバッファ: 今の `FileWriter`（同 1155-1185 行）は `Option<BufWriter<File>>` だけを持ち、途中の書き出しが失敗しても残りをバッファに残す。後の書き込みと解放の `flush` が書き直す。実装の直し。失敗の状態を持たせ、最初の失敗（`IoFailure`）を記録し、バッファを捨てる。以後の `write`・`writeLine`・`writeChunk` は記録した失敗を返し、`closeWriter`（解放）は書き出さずに閉じて同じ失敗の文を返す。
  - `closeWriter` の誤りの種類: 解放の結果は共通の口（`OsResource::release` の `Result<(), String>`）で文だけを運び、`closeWriter` は `IOErrorKind.Other` を付ける（`file.rs:1133-1152`）。記録した失敗の種類は運ばない。共通の口を変えるとほかのリソースにも及ぶので、文は同じで種類は `Other` とする。
- close(2) の遅れて返す誤り: 今は解放（`release`）でも捨てる（`File` の drop が close(2) の結果を返さない）。安全な Rust の標準ライブラリには close(2) の結果を受け取る口がなく、rustix の `try_close` は `unsafe fn` で、AGENTS.md は `unsafe` を `runtime::heap` の内部の層に限る。Q3 の「明示の `closeWriter` は close の失敗を返す」は、この制約のため書き出し（`flush`）の失敗を返すところまでとし、close(2) の誤りは明示の `closeWriter` でも drop でも捨てる。03-07 にそう書く（設計者に確かめる点として報告する）。
- `closeWriter` が解放を待つ間の取り消し: 2026-10-07 に設計者が「取り消しで理由を捨てるのは今のままでよい」とした（later-issues の 81）。01-10「解放の失敗」の取り消しの規則は `with` のブロックを抜けるときの解放についてのもので、`close` を呼んだリソースは解放済みとみなす（同節の最後の段落）。`close` の結果を受け取るのは呼んだタスクの続きだけなので、それが捨てられたときに失敗を捨てるのは規則と矛盾しない。文書だけ（01-10 に一文足す）と、振る舞いを固定するテストを一つ足す。

### 3.4 孫のプロセスがパイプを持ち続ける場合の `Process.run`（Q4）

- 今の状態: `collect_output` の `///`（`process.rs:362-364`）は「設計書 03-07『Process』の出力の収集」を根拠に挙げるが、03-07 に該当の記述がない。
- 直し方: 文書だけ。03-07「Process」に、子が終わっても孫が標準出力・標準エラー出力を開いたままだと `Process.run`・`Process.shell` が返らないこと、`Task.withTimeout` で上限を付けられることを書く。言語リファレンスにも一文足す。`///` の根拠はそのままで合うようになる。

### 3.5 jiff の内部のキャッシュと地方時の確認

- 内部の大域の状態: jiff 0.2.37 は、システムのタイムゾーンを `static CACHE: RwLock<Cache>` に 5 分（`static TTL`）保持する（`~/.cargo/registry/src/index.crates.io-…/jiff-0.2.37/src/tz/system/mod.rs:69`・`87`）。zoneinfo のデータベースも `static DB: OnceLock<TimeZoneDatabase>`（同 `src/tz/db/mod.rs:68`）に保持する。処理系は `src/runtime/sched/parts.rs:127` の `TimeZone::try_system()` でこれを使う。
  - 直し方: 文書だけ。03-01「使う Rust のクレート」の jiff の項に、二つの大域の状態と、同じプロセスの中ではシステムのタイムゾーンの変更が最大 5 分遅れて `Clock.localOffsetMinutes` に現れることを書く。03-07「Clock」にも振る舞いを一文書く。AGENTS.md「大域の状態」に、規約は処理系のコードに当てはまり、依存のクレートの内部の状態は 03-01 に書くと一文足す。
- 【要検証】Linux の地方時: `tests/l10_console_clock_process.rs:107-144` は、`/usr/share/zoneinfo/Asia/Tokyo` があれば 540 を期待する。タイムゾーンのデータを入れた Linux のコンテナでこのテストを走らせれば確かめられる。plan.md の最後の任意の手順にした。
- 軽微なテストの点:
  - `readAllLines`・`readAllBytes` の InputTooLarge のテスト: 2.8 節の上限の確かめの統一でテストする。
  - UTF-8 の二重の検査（`console.rs:206-225`、`file.rs:858-875`）: 扱わない。全体を `from_utf8` で確かめた後、行ごとに UTF-8 を確かめる確保の口を通すのは、コメント（`console.rs:220`）のとおり意図したものであり、計算量は線形で振る舞いに差がない。
  - `ScriptDirectory::drop` の `unwrap`: 1.1 節で直す。
  - `TZDIR`: jiff は `TZDIR` を読む（`jiff-0.2.37/src/tz/db/zoneinfo/enabled.rs:44`）。テストを走らせる環境に `TZDIR` があると期待値の判定（`/usr/share/zoneinfo` の有無）とずれる。テストの直し。子プロセスの環境から `TZDIR` を除く。
  - `process/tests.rs` の `cfg(unix)`: 扱わない。処理系の対象の環境はどれも Unix 系であり（05-01「対応環境（初回リリース版）」）、クレートはほかの箇所でも Unix の API を使う。

### 3.6 HTTP のクライアントの細部

- `"supported architecture"` の文（`src/builtins/funcs/http_client.rs:456`）: 実装の直し。`text` の子のモジュール（同 522-527 行）に移す。
- `timeoutMilliseconds` が `i64::MAX` のとき: `Duration::from_millis` に渡し（同 155-156・184 行）、ureq は `Instant + Duration` で期限を計算する（ureq 3.4.2 の `src/unversioned/transport/time.rs:82-95`。標準ライブラリの `Instant` の足し算は溢れると panic する）。macOS と Linux の `Instant` は秒を `i64` で持つので、約 2.9 億年を足しても溢れない見込みだが、確かめていない。
  - 直し方: 実装の直し。ureq に渡す時間を 2^40 ミリ秒（約 34.8 年）で頭打ちにする。実行が終わるまでの時間として区別できず、OS とライブラリの内部の計算に頼らずに済む。ループバックのサーバへ `timeoutMilliseconds` を `i64::MAX` にした要求を送り、応答を受け取れるテストを足す（TCP が要る）。
- 失敗の注入の名前の照合（later-issues の 93）: `http::Uri::host()` は IPv6 の名前を角括弧付き（`[::1]`）で返し、`NetworkFaults::lookup`（`src/runtime/sched/parts.rs:344-349`）はそのまま比べるので、表に `::1` と書いた失敗が当たらない。実装の直し。クライアントは角括弧を除いた名前で引く。02-09「組み込みの操作とハンドラ表」の表の名前は「URL の host」なので、角括弧を除いた形と書き添える。テストは `tests/network_faults.rs` に、`http://[::1]:1/` への要求に注入した失敗が返る行を足す（注入した失敗は接続の前に返るので、実際の通信は起きない）。
