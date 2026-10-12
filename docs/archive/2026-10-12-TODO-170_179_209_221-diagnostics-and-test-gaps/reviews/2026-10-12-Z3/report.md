# Z3（ef6f8307）のレビュー

対象: コミット `ef6f8307`（12 ファイル、+124・-44）。W5・W6 の `report.md` と `handling.md`、指示 `Z3-extra.md`、報告 `Z3-report.md` と照らした。ファイルはすべて `git show ef6f8307:<path>` で読み、ビルドとテストは走らせていない。行番号は ef6f8307 の版のもの。

## 結論

重大・中の所見はない。直すよう指示された指摘（W5 の中-1・中-2・軽-1・軽-2・軽-4・軽-5・軽-6、W6 の L1〜L5）は、どれも `handling.md` の記述どおりに直っている。直さないとした W5 の中-3・軽-3、W6 の L6 には触れていない。新しい誤りは見つからなかった。軽微な所見を 4 件挙げる。いずれも取り込みを止める理由にはならない。

## 観点ごとの確かめ

### (1) 指摘ごとの直し

| 指摘 | 確かめた内容 |
|---|---|
| W5 中-1 | `render.rs` 806〜820 行で、逃がさない `frame_name_text` と、それを逃がす `trace_frame_name` に分けた。JSON の `append_json_frame`（911〜917 行）だけが `frame_name_text` を使い、`trace`・`taskOrigins`（`json_trace_fields`）と `waitingTasks[].task`（`render_json_line`）の三つがこれを通る。文章の形の幅の計算（`append_trace_sections` 719 行）、`append_frames`（778 行）、`append_waiting`（850 行）は逃がす方を使い、幅と表示が一致する。テストは `trace[0]`（匿名）・`trace[1]`（名前付き）・`taskOrigins[0]`・`waitingTasks[0].task.function` を元の文字で比べ、指摘の案より広い。 |
| W5 中-2 | `cli/mod.rs` 799 行に `static NEXT: AtomicUsize` を置き、名前を `pid-連番-時刻` にした。`tests/cli_process.rs` の `TestDirectory` と同じ形。並列で 65 件が通ったと報告にある。 |
| W5 軽-1 | `run.rs` 410〜430 行。`end != Internal` の場合を先に分け、`Internal` のときは `iter_mut().find(\|r\| **r == copied)` で写しをその位置で置き換え、なければ従来どおり作業用のスレッドは先頭へ挿入、書き出し用は末尾へ追加する。以前の「`[copied]` と全体が一致したら `*end = plain(…internal_end_fields())` で作り直す」経路は、`Internal` のときは `check_failure` が `None`・`release_failures` が空・`heap` は後で `vm.heap_stats()` で上書き（401 行）なので、その場の置き換えと結果が同じになる。振る舞いの退行はない。 |
| W5 軽-2 | `append_tagged_line`（697 行）で末尾の LF を一つ除く。`report_check`（`cli/mod.rs` 445 行）が埋める `render_one_text` の出力は LF 一つで終わる（`render_one_text` の末尾は `output.push('\n')` の行で終わり、空の行を足さない）ので、一つ除けば足りる。 |
| W5 軽-4 | `tests/cli_process.rs` 37〜41 行で、`test` の場合に `could not test` と `due to 1 previous error` が同じ行にあることを確かめる。文言は `codes::text::SUMMARY_ONE` と合う。 |
| W5 軽-5 | `run.rs` 856〜901 行。条件分岐で期待値を作る処理を除き、入力と期待する並びの表にした。写しが二件目にある場合と、写しの後に別の報告がある場合を加えた。 |
| W5 軽-6 | `append_backtrace`（948 行）で各行を `escape_terminal_controls` に通す。JSON の `backtrace`（`render_json_line`）は元のまま。テストで両方を確かめる。 |
| W6 L1 | `blank_lines_comments.bnt` に、空の `then` の後の `else if` と、空の `else if` の分岐の後の `else if` を加えた。どちらも `ElseBranch::If` の枝を通る。枝を除くと失敗することを実装者が確かめている。`.formatted` の 7 行は内側の段にコメントを置き、空の行を除いており、06-03 の規則に合う。 |
| W6 L2 | `print.rs` 377〜379 行のコメントを、閉じの字句と、空の分岐・本体の後の `else`・`with` を挙げる形に直し、06-03「コメント」を引いた。 |
| W6 L3 | 03-08 155 行の `Regex.maxStringBytes` の文を「入力の終わりでは…一致なしとする。」の後へ移し、「入力を切り出さずに探す」の主語が `findAt`・`spanAt` の直後に戻った。所見 3 を参照。 |
| W6 L4 | CHANGELOG 79 行に `fmt --check` の一文を足し、Fixed の先頭の項目の後の空の行を除いた。Fixed の項目はすべて空の行なしで並ぶ形に揃った。 |
| W6 L5 | 07-03 107 行の BLESS の段落の末尾に「`fmt` の方式で冪等性の確かめが失敗したテストは、期待値を書き直さない。」を足した。 |

### (2) 新しい誤りの有無

- JSON と文章の形の分け方: JSON で逃がしを通る経路は残っていない。`render_json_line` は `message`・`notes`・`helps`・`waitsFor`・`backtrace` を元のまま書き、名前だけが `frame_name_text` を通る。文章の形で逃がしを通らない名前の経路もない（`trace_frame_name` を呼ぶ 3 か所がすべて文章の形）。
- バックトレースの逃がし: `str::lines` で分けるので、各行の末尾の CR LF の CR は除かれ、行の途中の CR とタブは `\u{D}`・`\u{9}` になる。Rust のバックトレースは空白で字下げするので、表示は変わらない。逃がしは冪等であり、二重の逃がしは起きない。
- 不具合の報告の置き換えと順序: 置き換えは最初に一致した一件だけ。作業用のスレッドと書き出し用のスレッドが同じ説明で panic した場合も、それぞれの写しが一件ずつ置き換わる（二件の写しがあれば一件ずつ、なければ挿入・追加）。順序は所見 2。
- 一時ディレクトリの名前: 連番は同じプロセスの中で一意であり、プロセスをまたぐ衝突は pid が防ぐ。`Ordering::Relaxed` で足りる。
- フォーマッタのコメント: コメントの内容は `walk.rs`・`roles.rs` の説明と 06-03 と合う。

### (3) AGENTS.md の実装の規約

本番のコードに `unwrap`・`expect`・添字・panic は加わっていない（`iter_mut().find` で置き換える）。`as` の変換はない。コメントは日本語で、設計書の節を引いている。`static NEXT: AtomicUsize` はテストのビルドだけのモジュールの中にあり、処理系のコードの大域の状態ではない（所見 4）。

### (4) テスト

新しいテストの関数は加えず、既存のテストとゴールデンを広げた（test-audit の関門に合う）。退行を入れて失敗することを実装者が確かめている（JSON の名前、バックトレース、空白だけの行、二件目の写し、`else if`）。期待値は具体的な値で書かれている。重複はない（`run.rs` の二つのループは、作業用→書き出し用の連続と、書き出し用の写しの位置の違いを分けて確かめる）。

### (5) 設計書・CHANGELOG

- 02-10 193・195 行: バックトレースを逃がしの対象に加え、末尾の LF を一つ除くこと、バックトレースを行ごとに逃がすことを書いた。実装と合う。
- 02-10 358 行: 写しをその位置で置き換えること、写しがないときの順序を書いた。所見 2。
- 03-08・07-03: 上の表のとおり。
- CHANGELOG 43・45 行: 実装と合う。所見 1。

## 所見

### 重大

なし。

### 中

なし。

### 軽微

**1. CHANGELOG 43 行の「multiline notes omit one final line feed」の範囲と書き方**
- 場所: `CHANGELOG.md` 43 行。
- 問題: 実装（`append_tagged_line`）は注記だけでなく help の文の末尾の LF も除き、対象は複数行の注記に限らず LF で終わる注記・help すべてである。また「JSON trace names retain the original characters」は、0.0.2 から変わっていない振る舞いを書いており、Changed の項目の中では変更点のように読める（Unreleased の中で W5 が入れて Z3 が戻した中間の状態は、利用者から見えない）。
- 直し方の案: 例「Text diagnostics escape … and backtraces; JSON output keeps the original characters. A note or help ending with a line feed no longer leaves a blank indented line.」のように、対象を「note or help」にし、JSON については「変わらない」ことが分かる形にする。直さなくても誤りではない。

**2. 02-10 358 行の順序の記述が、実装の「先頭に挿入」より狭い**
- 場所: `docs/design/02-impl/02-10-diagnostics.md` 358 行、`crates/benitoite/src/runtime/run.rs` 425〜427 行。
- 問題: 文書は「写した報告がないときは、作業用のスレッドの不具合は VM の panic より前に」と書くが、実装は `insert(0, …)` で報告の並びの先頭に置く。VM が panic でない `Stop::Internal`（表の欠けなど）を報告していた場合も、その前に置かれる。W5 の軽-1 の案はこの読み方で合うとしたので食い違いとまでは言えないが、実装者がこの記述だけでは位置を決めきれない。
- 直し方の案: 「作業用のスレッドの不具合は報告の並びの先頭に、書き出し用のスレッドの不具合は最後に書く」と、実装に合わせて書く。

**3. 03-08 155 行で「ほかの公開の関数」の直前に非公開の関数の文が来る**
- 場所: `docs/design/03-interop/03-08-text-and-data.md` 155 行。
- 問題: 移した文「非公開の組み込みの関数 `Regex.maxStringBytes` は…を返す。」の直後に「ほかの公開の関数は組み込みで実装する。」が続き、「ほかの」が項目の先頭の `Regex.findAll` などではなく、直前の非公開の関数を受けるようにも読める。W6 の L3 の案は「前か後」のどちらでもよいとしていたので、指示からの逸脱ではない。
- 直し方の案: `Regex.maxStringBytes` の文を「ほかの公開の関数は組み込みで実装する。」の後へ移す。

**4. テストの `static NEXT` に理由のコメントがない**
- 場所: `crates/benitoite/src/cli/mod.rs` 799 行。
- 問題: `src/` の中の `static` の原子的な計数器は、AGENTS.md「大域の状態」の例外の一覧にあるヒープの番号（`runtime/heap/core.rs`）だけである。テストのビルドだけのコードなので規約の対象外と読めるが、後で `git grep 'static .*Atomic'` で大域の状態を調べる人が迷う。
- 直し方の案: 「テストのビルドだけの連番。並列のテストの一時ディレクトリの名前を分ける（処理系の大域の状態ではない）。」の一行のコメントを添える。

## 範囲の外で気づいたこと（参考）

`cli/tools/args/tests.rs` 95 行、`cli/tools/formatter/tests.rs` 423 行、`cli/tools/skill/tests.rs` 23 行、`tests/fmt_command.rs` 26 行も、一時ディレクトリの名前を `タグ-pid-時刻` で作る。テストごとにタグが違えば衝突せず、`create_dir` を使うものは衝突しても黙って消し合わず失敗として現れるので、今回の中-2 ほどの危険はない。同じタグを並列のテストで共有していないかは確かめていない。気になるなら docs/todo の項目にする。
