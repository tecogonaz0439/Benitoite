# W5（e162eb95）のレビュー

対象: `e162eb95`（Escape control characters in text diagnostics and fix internal fault reports (W5)）。ファイルはすべて `git show e162eb95:<path>` で読んだ。ビルドとテストは走らせていない。行番号は e162eb95 の版のもの。

## 総評

計画（W5 の 1〜6）、判断（Q5・Q8・R13〜R17）、事前点検の補足に、ほぼそのまま沿っている。制御文字の逃がしは一つの関数（`escaped_terminal_control`）にまとめられ、色のエスケープと LF の構造を壊さず、二重の逃がしも起きない（逃がしは冪等）。BOM、`FaultThread::Main`、panic の説明の重複の除去、タスクの最初の枠の `call_site`、定義ごとの制限の診断、`case_length` の確かめ、設計書と CHANGELOG の更新は、どれも意図どおりである。

重大な所見はない。中の所見が 3 件ある。うち 1 件（JSON の履歴の名前に逃がしが漏れた）は Q5 と 02-10 の「JSON では逃がさない」に反するので、取り込む前に直すことを勧める。

---

## 中

### 中-1 JSON の `trace`・`taskOrigins`・`waitingTasks` の `function` に、文章の形のための逃がしが入る

- 場所: `crates/benitoite/src/diag/render.rs` 805〜816 行（`trace_frame_name` の最後で `escape_terminal_controls(&name)`）と 907〜913 行（`append_json_frame` が同じ `trace_frame_name` を呼ぶ。909 行）。
- 問題: `trace_frame_name` は文章の形と JSON の形の両方が使う。最後で逃がすようにしたため、JSON の `function` の値も逃がした形になる。`<lambda 表示名:行:列>`・`<handle …>`・`<lazy …>`・`<case …>` はファイルの表示名を含むので、パスに ESC や U+202E があると、JSON に `\\u{1B}` の文字列が入る。履歴の段の名前、起動の履歴の段の名前、待つタスクの `task.function` のすべてが該当する。Q5（「JSON の出力は逃がさない」）、02-10「文章の形式」の方針（「JSON の形式では逃がさず、元の文字を JSON の文字列として書く」）、コミットの説明（「keep JSON as is」）に反する。
- テストが見逃した理由: `diag/render/tests.rs` の `embedded_controls_are_escaped_without_changing_json_or_layout` は、JSON について `message` と `notes[0]` しか比べていない。このテストの診断は名前に制御文字を含む履歴を持つので、`json["trace"][0]["function"]` を比べていれば検出できた。
- 直し方の案: 逃がさない名前を作る関数（例: `frame_name_text`）と、それを逃がす文章の形の関数に分ける。`append_json_frame` は逃がさない方を使い、`append_trace_sections` の幅の計算、`append_frames`、`append_waiting` は逃がす方を使う。上のテストに、`json["trace"][0]["function"]` が `"<lambda x\u{1B}\u{202E}.bnt:1:1>"`（元の文字）であること、`json["trace"][1]["function"]` が元の名前であることの確かめを加える。待つタスクの `waitingTasks[0].task.function` も同様に確かめる。

### 中-2 CLI の単体テストの一時ディレクトリの名前が並列の実行で衝突する（既存の不具合。報告 5 節）

- 場所: `crates/benitoite/src/cli/mod.rs` 795〜810 行（tests の `Directory::new`）。
- 問題: 名前は `pid-ナノ秒の時刻` だけで作る。macOS の `SystemTime` の分解能はマイクロ秒程度なので、同じプロセスの並列のテストが同じ名前を得ることがある。片方の `Drop` がディレクトリを消すと、もう片方のテストがファイルを失って失敗する。実装者は `RUST_TEST_THREADS=1` で完了の条件を確かめたが、計画の完了の条件と `scripts/check.sh` は並列で走らせるので、不安定な失敗になりうる。W5 が持ち込んだ不具合ではないが、W5 が `cli::` のテストを増やしたので当たりやすくなる。
- test-audit の観点: テストの準備が時刻に依存し、順序と並列度で結果が変わる。07-03「テストの設計の原則」の決定性に反する。
- 直し方の案: `tests/cli_process.rs` の `TestDirectory` と同じく、`static NEXT: AtomicUsize` の連番を名前に加える（`pid-連番-時刻`）。テストのビルドだけのコードなので規約上の問題はない。この改造の中で直すか、直さないなら docs/todo に項目を加える。

### 中-3 R17 の変更が HTTP の起動の履歴に与える影響を、まだ確かめていない

- 場所: `crates/benitoite/src/vm/dispatch/tasks.rs` 559 行（`call_site: None`）と、それを読む `crates/benitoite/src/runtime/report.rs` 398〜424 行（`spawn_frame` が `record.spawner_frames` の `call_site` を読む）。
- 問題: 事前点検の補足 5 は、`testdata/network/` のゴールデンと `tests/l30_http_server.rs`・`tests/l31_http_serve_and_helpers.rs` の `taskOrigins` が変わらないことを確かめ、変わったら止めるよう求めた。報告によれば、これらは sandbox の TCP の制限で 27 件が走っていない。コードを読む限り、変わるのは「起動した側のタスクの最初の枠が `Http.serve` などを直接の関数にする」まれな場合だけで、既存のテストの形では変わらない見込みだが、確かめは残っている。
- 直し方の案: 取り込みの前に、sandbox の外で `cargo test -p benitoite --test golden`（`BENITOITE_GOLDEN_FILTER=testdata/network/`）、`--test l30_http_server`、`--test l31_http_serve_and_helpers` を走らせる（`check.sh` の本実行に含まれる）。

---

## 軽微

### 軽-1 写しの判定がリスト全体の一致なので、重なった不具合で写しが残る

- 場所: `crates/benitoite/src/runtime/run.rs` 408〜428 行（`record_internal_panic`）。
- 問題: `end.run.reports.as_slice() == [copied]` は、報告が写しの一件だけのときにしか成り立たない。たとえば、書き出し用のスレッドの panic を VM が先に `Stop::Internal` として写し（`services.rs` 137 行）、その後に作業用のスレッドの不具合が来ると、作業用のスレッドの報告が先頭に入って `[worker, 写し]` になり、最後の書き出し用のスレッドの報告で `[worker, 写し, writer]` と同じ不具合が二件になる。また、VM の panic でない `Stop::Internal`（例: 表の欠け）が先に起きていた場合も、作業用のスレッドの報告を先頭に置くので、02-10 の「作業用のスレッドの不具合は VM の panic より前に」の前提（先に起きた）と順序が逆になりうる。どちらも起きにくい組み合わせである。
- 直し方の案: 全体の一致でなく、`reports` の中で `copied` と等しい要素を探し、あればその場所を元の報告で置き換える（`iter().position(|r| *r == copied)`）。なければ今のとおり挿入か追加をする。順序の注記は「VM の panic の報告より前に」と、対象を panic に限って書けばよい（今の 02-10 の文はその読み方で合う）。

### 軽-2 標準ライブラリの誤りを不具合にする注記の最後に、空白だけの行が出る

- 場所: `crates/benitoite/src/diag/render.rs` 680〜702 行（`append_tagged_line`）と、`crates/benitoite/src/cli/mod.rs` 444〜454 行（`report_check` が `render_one_text` の出力を `message` に入れる）。
- 問題: `render_one_text` の出力は LF で終わるので、`message.split('\n')` の最後に空の要素ができ、字下げの空白（溝の幅＋11 個）だけの行が出る。変更前も空の行は出ていたが、今は末尾に空白が付く。
- 直し方の案: 分ける前に末尾の LF を一つ除く（`message.strip_suffix('\n').unwrap_or(message)`）か、空の続きの行では字下げを書かない。

### 軽-3 定義ごとの制限の鍵が位置だけで、別の定義が同じ位置を持つと一つにまとまる

- 場所: `crates/benitoite/src/bytecode/codegen/mod.rs` 250 行（`definition_limit_keys.insert((code, fg.def.span))`）。
- 問題: 計画と事前点検は `(code, fg.def.span)` を指定したので計画どおりである。ただし、処理系が作る定義（導出の実装など）が同じ宣言の位置を共有する場合、名前の違う二つの定義の診断が一つにまとまる。今そうした定義が制限に当たる経路があるかは確かめていない。
- 直し方の案: 鍵に `fg.def.name` も加える（`(DiagCode, Span, String)`）か、定義の番号で鍵を作る。変えないなら、現状で問題がない理由を `finish` のコメントに一文書く。

### 軽-4 テストの実行器の制限の件数の行を確かめるテストがない

- 場所: `crates/benitoite/src/cli/tools/test_runner/mod.rs` 376〜395 行。
- 問題: `run` の経路は `cli/mod.rs` の `codegen_limit_is_a_run_error_but_check_succeeds` が最後の行を確かめるが、`Verb::Test` の経路を確かめるテストはない。`tests/cli_process.rs` の `decision_tree_limit_is_reported_by_test_but_not_check` は `test` で L0112 を出すので、既にこの経路を通っている。
- 直し方の案: そのテストの `test` の場合に、`could not test` と `due to 1 previous error` を含む行があることを一つ加える（新しいテストは要らない）。

### 軽-5 `record_internal_panic` のテストが期待値を条件分岐で作る

- 場所: `crates/benitoite/src/runtime/run.rs` 836〜885 行（`internal_panic_reports_preserve_distinct_faults_and_replace_copies`）。
- 問題: ループの中で `copied` を計算し、`if copied { … } else { … }` で期待値を切り替えている。テストが本番と同じ判定を書き直しているので、判定を誤って変えたときに、テストも同じ誤りに沿って通る余地がある（test-audit の「期待値は具体的な値で書く」）。
- 直し方の案: 二つの場合を、入力と期待する報告の並びを明示した表（`[(初めの報告, 期待する並び)]`）にする。軽-1 を直すなら、写しが二件目にある場合を表に加える。

### 軽-6 バックトレースの行は逃がさない

- 場所: `crates/benitoite/src/diag/render.rs` 938〜947 行（`append_backtrace`）。
- 問題: Q5 は「全文」を対象にしたが、バックトレースの行はそのまま書く。中身は処理系の関数の名前とビルドの環境のパスで、利用者が制御できる文字はほぼ入らないので、実害は小さい。
- 直し方の案: 各行を `escape_terminal_controls` に通すか、02-10 の対象の一覧から外れることをコメントに書く（02-10 の方針の段落はバックトレースを挙げていないので、設計書との食い違いはない）。

---

## 観点ごとの確認（問題のなかった点）

1. 計画と判断
   - 逃がす文字の集合は補足のとおり（C0・DEL・C1、U+061C、U+200E、U+200F、U+202A〜U+202E、U+2066〜U+2069、U+FEFF）。大文字の 16 進数の形も保った。
   - `FaultThread::Main` と `text::THREAD_MAIN` を加え、`internal_diagnostic` の `match` に枝を足した。網羅する `match` はこれだけである。
   - R13 (a)〜(d)、R14〜R17 は計画どおり。`resolve/tests.rs` に、notes と helps のどちらかを見る確かめは残っていない。
2. 正しさ
   - 逃がしの範囲: 見出し（`append_header`）、ラベル（`append_marker_line`）、注記と help（`append_tagged_line`）、段の名前（`trace_frame_name`）、待つ種類（`append_waiting`）、ファイル名（`append_location`）、件数の行（`render_check_text` の `file`）を確かめた。段の名前（`INTERNAL_STAGE` の `{stage}`）は注記を通るので逃がされる。R0401 などの `{location}` は見出しを通る。`fmt`・`test`・`skill` の行は、従来の `escape_terminal_controls` を通るので、双方向の制御文字も自動で対象に入る。テストの名前は `quoted` が逃がす。
   - 二重の逃がし: 既に逃がした文字列を診断に入れる経路はない。`report_check` の経路は二度通るが、逃がしは冪等である。`trace_frame_name` の名前と `append_location` の位置は別の部分なので重ならない。
   - 色: `push_colored` の出力は逃がしの外にあり、テストも色付きの出力に ESC が残ることを確かめている。
   - 複数行の注記の字下げ: 続きの行の字下げ `gutter_width + tag.len() + 5` は、`= note: ` の後の桁と一致する。
   - BOM: `Source::line_text` の呼び出しは `prepare_label` の一か所だけで、意味の変更はほかに影響しない。`prepare_label` と `prepare_file` はどちらも `excerpt_start_offset` で行の始まりを 3 にし、列の数え方（02-02）と揃う。1 行目以外は変わらない。CRLF の CR は `line_text` と `finish_row` が除く。`bom_at_start` のゴールデン（1 行目の CR、`^` 5 個）と修正案の単体テストで固定した。import の挿入位置（`resolve/imports.rs` 268〜288 行）も BOM の後に置くので、修正案が BOM の中から始まることはない。
   - `FaultThread::Main` の使い分け: 主スレッドの境界は `write_tool_panic`、`execute_script` の外側の `Err(panic)`、テストの実行器の外側の `Err(panic)` の 3 か所で、段のスレッドの `Ok(Ok(Err(panic)))`・コンパイルの panic・`pipeline::check`・フォーマッタは `Stage` のままである。panic のない呼び出しはスレッドを書かない。
   - タスクの最初の枠の `call_site`: `vm/frame.rs` と `vm/mod.rs` の欄の説明（「タスクの最初の枠では `None`」）に実装が合うようになった。呼び出しの履歴（`call_trace` は最も外側の段の位置をもともと示さない）、行き詰まりの待つ位置（`call_sites`）、取り消しのテスト（`spawner` から読むように直した）への影響は意図どおりである。末尾呼び出しの `call_site`（`dispatch.rs` 1250 行）は変えていない。
   - 制限の件数の行: `run` と `test` の文章の形は `render_check_text` を通り、JSON は一件ずつのままである。L0112 も同じ `CompileError::Limit` の経路を通る。
   - `case_length`: `exact.len() == at_least` と各腕の `len == i` を確かめ、外れたら `InternalError` を返す。欠落・重複・逆順・余分の 4 つの場合をテストした。
3. 実装の規約
   - panic、`unwrap`、添字は本番のコードにない。`THREAD_MAIN` は `text` に置いた。`InternalError` の説明の英文は、処理系の不具合の説明なので `text` に載せなくてよい。コメントは日本語で、設計書の節を示している。
4. テスト
   - 退行のテストは、直す前のコードで失敗することを確かめたと報告にある。70,000 要素のテストは 0.22 秒で、長いテストにする必要はない。中-1・中-2・軽-4・軽-5 を除き、test-audit の原則に合う。
5. 設計書と CHANGELOG
   - 02-07（上限の数と定義ごとの報告。全体の表の上限 65,535 は `tables.rs` の `table_limit` と一致）、02-08 の 3、02-09「panic 境界」、02-10「文章の形式」「処理系の不具合と処理系の制限の報告」は実装と合う。ただし 02-10 の「JSON の形式では逃がさず」は、中-1 を直すまで実装と食い違う。06-01・06-04・06-06 の「診断のファイルの表示名と同じく逃がす」は、共通の関数を通るので、双方向の制御文字を含めて合う。
   - CHANGELOG の 3 行は変更の内容と合う。
