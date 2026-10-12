# 作業 C1 のレビュー

- 対象: git worktree `Benitoite-C`（ブランチ `impl/TODO-194-C`、基準 61c32e5）のコミットしていない変更。`crates/benitoite/src/cli/mod.rs`、`src/cli/tools.rs`、`src/cli/tools/skill/mod.rs`、`src/diag/render.rs`、`src/diag/render/excerpt.rs`、`src/diag/render/tests.rs`、`tests/cli_process.rs`、`testdata/lexical/todo194-control-escape.*`（新規 5 件）。
- 観点: 依頼文の 1〜4（panic の境界、制御文字の逃がし、テストの質、規約）。
- 走らせた検査: `cargo test --test cli_process`（4 件成功）、`cargo test -p benitoite --lib diag::render`（33 件成功）、`BENITOITE_GOLDEN_FILTER=todo194 cargo test --test golden`（成功）。加えて、デバッグのビルドの実行ファイルで、ESC を含むファイル名のスクリプトを `check`・`test` にかけて出力を確かめた。

## 結論

所見 1（要約の行のファイル名）を直せば取り込んでよい。panic の境界は、三つの道具の本体を漏れなく囲み、報告の形も `run`・`check` と揃っている。抜粋・修正案・位置の行の逃がしは正しく、`^`・`-`・`~` の位置も合う。所見 1 は数行の直しで、同じ `render.rs` の中にある。所見 2 以降は直さなくても取り込める。

## 所見

### 1. 要約の行のファイル名を逃がしていない

- 重さ: 直すべき
- 場所: `crates/benitoite/src/diag/render.rs` の 77 行付近（`codes::text::SUMMARY_ONE`・`SUMMARY_MANY` に `{file}` を埋める箇所）
- 問題: `-->` の行は `e\u{1B}x.bnt:2:13` と逃がすが、同じ出力の最後の行は `error: could not check e<ESC>x.bnt due to 1 previous error` と ESC をそのまま書く（`check` と `test` で確かめた）。study の 6 節は「ファイル名を書く箇所」を同じ関数で逃がすとし、plan.md の C1 の完了の条件も「ファイル名の診断で、制御文字が見える形に逃がされ」とする。要約の行は診断の文章の出力の一部であり、`render.rs` の中で組み立てるので、C1 の範囲に入る。
- 直し方の案: `{file}` に埋める値を `escape_terminal_controls(...)` に通す。`render/tests.rs` の `terminal_controls_are_escaped_in_excerpts_and_locations` か新しいテストで、`render_text`（要約の行を出す公開の関数）の出力に生の ESC が残らないことを確かめる。JSON の側は変えない。

### 2. `escape_terminal_controls` が LF を逃がさない

- 重さ: 直すとよい
- 場所: `crates/benitoite/src/diag/render.rs` の 444〜460 行（`escaped_terminal_control`、`escape_terminal_controls`）
- 問題: 公開した `escape_terminal_controls` は LF を残す。この関数を使うのはファイル名（`append_location`、所見 1 の要約の行、C2 の「would reformat」の行）だけであり、LF を含むファイル名は一行の出力を二行に割り、偽の `-->` の行や「would reformat」の行を作れる。doc コメントは「修正案の行分割は呼び出し側に委ねる」と書くが、抜粋と修正案の行は `escape_terminal_controls` でなく `append_terminal_character`（`render_source_line` 経由）を通り、しかもその時点で LF を含まない（`Source::line_text` が LF を除き、`excerpt.rs` は LF で行を分けてから `render_source_line` に渡す）。`display_width` に渡すバイト列も行の中だけである。したがって `escaped_terminal_control` で LF も逃がしても、抜粋・修正案の出力は変わらない。
- 直し方の案: `escaped_terminal_control` の除外をタブだけにし（`'\n'` を除外から外す）、doc コメントの「LF は保ち」を直す。ファイル名に LF を含む例を単体テストに一つ足す。直さない場合は、C2 の依頼文に「LF は逃がさないので、一行の出力に使うときは注意」と書く。

### 3. 道具の報告で、ファイル名や利用者の文字列を書くほかの行

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/cli/tools/test_runner/report.rs` の 27 行付近（`TEST_LINE` の `{file}`・`{name}`）、`src/cli/tools/skill/mod.rs` の `INSTALLED`・`REMOVED`・`WRITE_FAILED` などの `{path}`、診断の `message`・ラベルの文・`note`・`help` の文
- 問題: Q5 の範囲（抜粋、`-->` の行のファイル名、「would reformat」の行）の外で、ファイル名や利用者が決める文字列を文章の出力にそのまま書く箇所が残る。`test` の各テストの行のファイル名は、所見 1 と同じ種類の入力で ESC を出しうる。実行時の誤りの文に利用者の文字列が入るかは確かめていない。
- 直し方の案: 今回の範囲は決定どおりとし、残りを docs/todo の TODO-179 に書き残す（オーケストレータの判断）。`test` の行は C2 で逃がす関数を使うときに一緒に直してもよい。

### 4. EOF の単独の CR を修正案の行に残すようになった

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/diag/render/excerpt.rs` の 87〜93 行（最後の `finish_row` の `before_lf`）
- 問題: 前は最後の行の末尾の CR を、後に LF がなくても消していた。今は後に LF があるときだけ消し、ファイルの末尾の単独の CR は `\u{D}` と出す。`Source::line_text`（LF の直前の CR だけを除く）と揃うので、正しい方向の変更である。既存のテストは落ちていない。
- 直し方の案: なし。設計書 02-10 に制御文字の置き換えを書き足すとき、単独の CR も `\u{D}` と出ることを一緒に書くとよい。

### 5. `write_tool_panic` と `write_internal` の重なり

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/cli/mod.rs` の 391〜423 行
- 問題: `write_tool_panic` は、出力先と色を値で受け取ることを除けば、`write_internal(..., &SourceTable::new(), stage, &panic.message, Some(panic))` と同じである。
- 直し方の案: `write_internal` の本体を `write_report_to` を使う形にし、`write_tool_panic` から共通の補助を呼ぶとまとまる。動作は変わらないので、今回は直さなくてよい。

## 確かめて問題がなかった点

- panic の境界: `run_body`（`cli/tools.rs` の 38 行付近）が、`test`・`fmt` では引数の解釈の後の本体全体を、`skill` では `HOME` の取得を含む分岐の全体を `runtime::panic::catch` で囲む。境界の外に残るのは、引数の解釈（`args::parse_path_args`）と使い方の誤りの報告、`stderr.clone()` だけで、`run`・`check` も引数の解釈を境界の外で行うので揃っている。`test`・`fmt` の中の既存の境界（`test_runner/mod.rs` の 324 行、`formatter/mod.rs` の 180 行）は残る。
- 報告の形: `report::internal_diagnostic(stage, &panic.message, Some(panic), FaultThread::Stage)` と空の `SourceTable` で書き、終了状態 3 を返す。`check` の段の panic の報告（`execute_script`）と同じ組み立てである。段の名前は `STAGE_TEST`・`STAGE_FMT`・新しい `skill::text::STAGE_SKILL`。`--diagnostics=json` のときは `parsed.diagnostics` に従い一行の JSON になり、`skill` は文章の形で書く（補足 5 のとおり）。hook は記録だけで標準エラー出力に書かない（`runtime/panic.rs` の `install_hook`）ので、新しい仕組みは要らない。
- `BENITOITE_DEV_PANIC=tool`: `read_development_environment` の `cfg!(debug_assertions)` の分岐の中で読むので、リリースのビルドでは効かない。panic は本体の先頭（ファイルに触れる前）で起こす。`development_tool_panic` の `#[allow(clippy::panic)]` は AGENTS.md の表の「`src/cli/` の `BENITOITE_DEV_PANIC` の処理」に当たり、理由のコメントもある。
- 制御文字の範囲: `'\u{0}'..='\u{1F}' | '\u{7F}'..='\u{9F}'` からタブと LF を除く。逃がす形は `format!("\\u{{{:X}}}", ...)` で、lexer の修正案と同じ（大文字、0 で埋めない）。幅は逃がした後の文字数（ASCII なのでバイト数と同じ）で、`^`（主）・`-`（副）・`~`（修正案）の位置が合う。単体テストの期待（インデント 5、印 18 個、修正案の印 12 個・11 個）と、ゴールデンの `^` の位置（26 桁目から 6 個）を数えて確かめた。全角文字・結合文字の幅を 1 と数えるのは今までと同じで、この変更で悪くならない。
- `append_location` で逃がすことの副作用: 呼び出しはすべて文章の描画の中（`-->`・`:::`・修正案の組・履歴・待ちの表）で、ファイルを開く処理や JSON の描画（`push_json_string`）には使われていない。待ちの表は逃がした後の文字列で幅を数えるので、桁も揃う。
- 修正案の組み立て（`excerpt.rs`）: 行の分け方（`'\n'`）と CR LF の CR の除き方を保ち、タブの展開と逃がしを `render_source_line` に任せる形にした。CR の印の除き方を `source_unit_width('\r')` 個に変えたのは、CR の幅が 6 になったことに合う。正しくない UTF-8 は U+FFFD として `text` に入り、`render_source_line` でも幅 1 のまま出る。
- テストの質: プロセスのテストは公開の境界（別のプロセスの終了状態、標準出力・標準エラー出力）で確かめ、`current_dir` と `HOME` を一時ディレクトリにし、`.claude` を作らないことも確かめる。実装者は、境界を入れる前に終了状態 101 で落ちることと、逃がす前に描画のテストとゴールデンが落ちることを確かめたと報告している。テストの前の関門のコメントもある。
- 規約: 本番のコードに `unwrap`・`expect`・添字はない。文言は `text` のモジュールに置いた。コメントは日本語で理由と設計書の節を書く（`escape_terminal_controls` の doc コメントは設計書の節を示さないが、02-10 への反映がまだなので、反映の後に節を書き足すとよい）。
