# 実装プラン

作業は、事前点検（Opus）で依頼文を直してから Codex（GPT-6.1-Sol、high）が実装し、Opus のレビューの後に、オーケストレータが `scripts/check.sh` を通して `san_benito` に取り込む。作業ごとに git worktree とブランチ `impl/TODO-194-<作業>` を作る。docs/todo は worktree に現れないので、要る内容は依頼文に写す。レビューの記録は `reviews/` に置く。

形式化した範囲（構文・型の規則・脱糖）に触れないので、`scripts/check-formal.sh` は完了の条件に入れない。ただし作業 J は serde_json の機能を変え、形式化の交換形式のテスト（`tests/coverage_export.rs`・`tests/desugar_export.rs`）も同じ依存を使うので、作業 J の完了の条件にそれらのテスト（長いテストを除く）を入れる。

## 作業

| 作業 | 内容 | 主なファイル |
|---|---|---|
| J | TODO-194。Q1・Q2 の答えの形で `Json.parse` を直す。変換できない数を `Result.Error` にする。`Json.stringify` の数の書式化を `arbitrary_precision` なしで同じ文字列にする | `crates/benitoite/Cargo.toml`、`builtins/funcs/json.rs`、`tests/l31_http_serve_and_helpers.rs` か `testdata/network/` |
| W | 文言と値の小さな直しと衛生。TODO-165（E0441）、TODO-169（E0313、`--licenses`、Q6）、TODO-166（`Decimal.parse`）、内部の不具合の文言（Q9）、A-3（Q8）、A-6、A-9。Q3 で拒むときの E0125 の文の追加。ゴールデンの期待と Skill の生成物（`gen_skill`）の作り直し | `diag/codes.rs`、`cli/tools/licenses.rs`、`builtins/funcs/decimal.rs`、`.gitignore`、`tools/syntax-measure/`、`tools/skill-eval/tasks/regex_text/` |
| C1 | TODO-167（Q4）と端末の制御文字（Q5）。`run_tool` を panic の境界で囲む。`DevPanic` に値を足し、CLI を別のプロセスとして起動するテストで確かめる。診断の抜粋とファイル名の制御文字を逃がす関数 | `cli/tools.rs`、`cli/mod.rs`、`tests/cli_process.rs`、`diag/render.rs` |
| C2 | D-2〜D-6。普通のファイルだけを上限付きで読む補助の関数を置き、モジュールの読み込み・`is_ours`・fmt の読み込みに使う。fmt の一時ファイルを `mode(0o600)` で作る。Q3 の答えの扱い。fmt の「would reformat」の行に C1 の逃がす関数を使う | `modules/mod.rs`、`cli/tools/skill/mod.rs`、`cli/tools/formatter/mod.rs` |
| D | 設計書・言語リファレンス・CHANGELOG の未リリースの節への反映と、設計書の注記（docs/todo の TODO-165・166・167 を指すもの）の削除。オーケストレータが作業ごとに行う | `docs/design/`、`docs/reference/benitoite.md`、`CHANGELOG.md` |

## 順序と並べ方

- J・W・C1 は触るファイルが重ならないので並べる（ビルドを伴う Codex は 3 並列まで）。J を最優先とし、最初に取り込む。
- C2 は C1 の逃がす関数を使うので、C1 を取り込んだ後に始める。Q3 で拒むなら E0125 の文を W が `diag/codes.rs` に置くので、W の取り込みの後にする。
- D は各作業の取り込みに合わせて行い、最後にまとめて確かめる。

## 作業ごとの完了の条件

どの作業も、`scripts/check.sh`（選ばれる検査）が通り、受け持つ所見ごとに、直す前に落ち直した後に通るテストを加える（テストの書き方はスキル `test-audit` と 07-03「テストの設計の原則」）。

- J: 特殊なキーの object（値が `"123"`・`"1e9999"`・`"-0"`・`"abc"`、`$` を `\u0024` と書いた形、配列と object の中の入れ子）が object のまま読め、`Json.stringify` で同じ object に戻る。`-0` と `-0.0` の混じる入力と、重複した鍵で捨てられる値の形で、03-08 の数の規則が保たれる。既存の JSON の単体テスト・統合テスト・ゴールデンが期待を変えずに通る（Q2 の順の変化に当たるものを除く）。要求の本体を `Json.parse` に渡すサーバが、特殊なキーの入力の後も次の要求に応える。`cargo test --test coverage_export --test desugar_export` が通る。`json.rs` の解析の経路に、入力によって起きうる `Stop::Internal` が残らない。
- W: E0441 の修正案が `Result.ok` を示す。E0313 が prelude の名前と import の名前で誤った説明をしない。`--licenses` の文が Q6 の形になる。`Decimal.parse` が `"01"`・`"00.5"`・`"-01.5"` で `None`、`"0"`・`"0.5"`・`"-0.5"` で `Some` を返す。`gen_skill` で作り直した Skill の生成物に差が残らない。
- C1: `skill`・`test`・`fmt` の中の panic が、処理系の不具合の報告と終了状態 3 になる（CLI を別のプロセスとして起動するテスト）。ESC・C1 を含むソースとファイル名の診断で、制御文字が見える形に逃がされ、`^`・`~` の位置が合う。
- C2: FIFO を指すモジュール・`SKILL.md`・fmt の引数で止まらず、誤りを報告する（unix だけのテスト）。上限を超えるファイルを全体まで読まない。fmt の一時ファイルが作られた時点から 0600 である。Q3 の答えのとおりに 0444・固いリンク・所有者の違うファイルを扱う。

## 設計書への反映

- 01-04「型の変換」の注記（TODO-166）、01-09 の E0441 の注記（TODO-165）、06-01「`skill` のコマンドライン（初回リリース版）」の注記（TODO-167）を消す。
- 03-08「Json」: Q1 の答えに合わせる（A なら、鍵によって値の読み方を変えないことを一文足すかを決める）。
- 02-04「モジュールの探し方」・06-06「Skill の導入（初回リリース版）」: 普通のファイルだけを上限付きで読むこと。
- 06-01「`fmt` のコマンドライン（初回リリース版）」と言語リファレンスの fmt の説明: 一時ファイルの許可と Q3 の答え。
- 02-10「診断の文章の形式」: Q5 の制御文字の逃がし方。
- 05-01「ライセンスの表示」: Q6 の文。
- CHANGELOG の未リリースの節: Q7 の `Decimal.parse` と、Q3 の fmt の拒否（互換でない変更）、Fixed の各点。

改造を終えたら、docs/todo の TODO-165・166・167・169・194 を閉じ、TODO-177 は残りの点（F-2・A-8）に書き換える。Q5 で含めたら TODO-179 の (e) を消す。

## 実際の分け方

2026-10-11 に、次の作業に分けて進めた。J・W・C1 を並べて進め、C2 は C1 を取り込んだ後に始めた。各作業は、事前点検（Opus）で依頼文を直してから Codex（GPT-6.1-Sol、high）が実装し、Opus のレビューの所見を Codex の追加の作業（W はオーケストレータ）で直してから、`check.sh` を通して取り込んだ。レビューの記録は `reviews/`。

| 作業 | コミット | 要点 |
|---|---|---|
| W | 0ee4514 | E0441 の修正案を `Result.ok` に、E0313 を import と prelude の名前を含む文に、`--licenses` の文を 1 行に、内部の不具合の報告に秘密を除く注意を、E0125 の説明に fmt が拒む三つの場合を書いた。`Decimal.parse` が整数部の先頭の 0 を拒む。`.gitignore`、skill-eval の課題のメールアドレス、syntax-measure の記録の `~`。設計者の指示で `check.sh` は走らせずに取り込んだ |
| C1 | 6e28101 | `skill`・`test`・`fmt` の本体を panic の境界で囲み、終了状態 3 で報告する。`BENITOITE_DEV_PANIC=tool`。文章の形の診断の抜粋・修正案・ファイル名の制御文字を逃がす（`diag::render::escape_terminal_controls`）。レビューの指摘で、要約の行のファイル名と、ファイル名の LF・タブも逃がした |
| J | a73199b | `arbitrary_precision` を外して `float_roundtrip` を付け、自前の `Visitor` で材料の木を作り、数を文書の順に元の字面で分類する。変換できない数は `Json.ParseError`。交換形式の Decimal の仮数を正確な JSON の整数で書く。直接依存は `serde_core`。レビューの指摘で、数の字面を JSON の数の文法で切り、範囲外の数のない構文の誤りの報告を基準と同じにした |
| C2 | b5f2da5 | ソース・`SKILL.md`・fmt の入力を、止まらずに開いてから普通のファイルと確かめ、上限 + 1 バイトまで読む（`base::file_read`）。fmt の一時ファイルを 0600 で作り、三つの場合の置き換えを拒む。fmt・test・skill の報告のファイル名を逃がす |
| D | 9b8f2f7 | 01-04・01-09・02-02・02-04・02-09・02-10・03-01・03-08・06-01・06-04・06-06、言語リファレンス、CHANGELOG の未リリースの節 |

計画と違えた点:

- 作業 J は、serde_json の機能を変えたことで形式化の差分テストの交換形式の書き出し（`tests/desugar_export/exchange.rs`）も直す必要があったので、`check-formal.sh` を完了の条件に加えた。
- 作業 C2 のレビューで、入口のスクリプトを管から渡す使い方が E0101 になることが分かり、設計者が受け入れると決めた（Q10）。
- 作業 W の `.gitignore` の変更で `check.sh` が止まったので、設計者の指示で `.gitignore` を検査の要らないファイルとして扱うよう `check.sh` と 07-03 を直した（cc855c6）。
- E0101・E0125 などの見出しの文に埋めるパスの制御文字と、双方向の書式の制御文字は扱わず、docs/todo の TODO-179 に書き足した。
