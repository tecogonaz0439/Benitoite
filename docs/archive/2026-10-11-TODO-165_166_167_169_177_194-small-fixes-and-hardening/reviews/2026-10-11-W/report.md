# 作業 W のレビュー

- 対象: git worktree のブランチ `impl/TODO-194-W`（基準 61c32e5）のコミットしていない変更 19 ファイル。依頼文と補足、実装者の報告、改造の文書（study.md の 1・2・4・5 節、decisions.md の Q3・Q6〜Q9、plan.md の作業 W）と突き合わせた。
- レビューした人: Claude（Opus 5.5）。2026-10-11。
- 結論: **取り込んでよい**。直すべき所見はない。直すとよい所見が 2 件（E0313 の説明の文の言い回し、E0441 の単体テストの確かめの精度）あり、取り込みの前に直しても、そのまま取り込んでもよい。E0125 の説明の文は C2 が拒む処理を実装するまで事実と食い違うので、W と C2 の間でリリースや push をしないこと（所見 3）。

## 確かめたこと

- `Decimal.parse`（`crates/benitoite/src/builtins/funcs/decimal.rs` 88〜99 行）: `-` を一つ外した後、最初の `.` の前を `decimal_integer` で検査してから `parse_literal` に渡す。境目の入力を一つずつ追った。
  - `"-"`・`"."`・`"-.5"`・`".5"`: 整数部が空なので `decimal_integer` が偽を返し `None`。直す前も `parse_literal` が整数部が空のとき `None` を返していたので、扱いは変わらない。
  - `"1."`: 整数部 `"1"` は通り、`parse_literal` が小数部が空なので `None`。変わらない。
  - `"1.2.3"`: 整数部 `"1"` は通り、`parse_literal` が小数部の `.` で `None`。変わらない。
  - `"--1"`・`"+1"`・`" 1"`・`"１２"`: 整数部が数字だけでないので `None`。変わらない。
  - `"0"`・`"-0"`・`"0.5"`・`"-0.5"`・`"0.00"`・`"-0.00"`: 整数部 `"0"` は通り、今と同じ値。
  - 新しく `None` になるのは、整数部が 2 文字以上で `0` で始まる入力（`"01"`・`"007"`・`"00.5"`・`"-01.5"` など）だけである。`Integer.parse`・`Float.parse` と同じ規則で、`parse_literal`（`base/decimal.rs`）は変えていない。
- E0441 の注記 `convert` が `Result.ok` を示す。`Result.toOption` は処理系・Skill・ゴールデン・`docs/reference/` のどこにも残っていない。
- E0313: 判定（`resolve/lookup.rs` の `upper` を `parameters = false` で呼ぶ）は、同じモジュールのトップレベル、import で付けた名前、prelude、`Benitoite`（prelude の表から引く）を見る。新しい文言の三つの分類はこの範囲と一致し、`Benitoite` は「a prelude name」に含まれる。注記の鍵 `declared` は変えていない。
- `INTERNAL_REPORT`・`NOT_BUNDLED` は Q9・Q6 の決定どおりである。`NOT_BUNDLED` は末尾の改行を残している。どちらも、期待に文を持つテストやゴールデンはない（テストは定数と比べる）。
- ゴールデンの差は、`names/type_param_toplevel.diag.json` の message 2 件とラベル 1 件、`types/todo178-placeholder-try-error.diag.json` の helps の文 1 件だけで、位置・コード・他の欄は同じである。Skill の生成物 `skill/references/diagnostics.md` の差は E0125・E0313・E0441 の文言だけである。
- `tools/syntax-measure/results/*.jsonl` の 2 ファイルは、基準の版に `s#/Users/<名前>/#~/#g` を当てたものとバイト単位で一致した。基準の版に `/Users/<名前>` の後が `/` でない出現はなく、書き換えた後に `/Users/` は残らない。どちらの jsonl も各行が JSON として読める。meta・archive・md の 6 ファイルの差も、同じ置換だけである。archive.json の sha256 は変えていない。
- `harness.py` の `recorded_path` は、記録の辞書に入れる値にだけ使い、`run_agent` に渡す `cmd`・`cwd`、`trial_dir` の戻り値、アーカイブを作るパスは変えていない。記録を読み戻すのは `report.py` の表示（`outside_access` と archive の `path`）だけで、パスとして開く箇所はない。接頭辞は `os.path.expanduser('~') + os.sep` で、`expanduser` は末尾の区切りを除くので、`HOME` が `/Users/<名前>2` などのときに `/Users/<名前>/` の部分が誤って当たることはなく、家のディレクトリが `/Users/<名前>` 以外でもその家の接頭辞が置き換わる。worktree の `target/sm-check/results/` に残る直した後の偽エージェントの記録（`w-final-2.*`）に `/Users/` がないことも確かめた（直す前の試し `20261011T001634Z-fake.meta.json` には残っており、補足の 6 か所に加えてコマンドの型板と版の取得の文を置き換えた判断の根拠と合う）。
- `.gitignore`: `git ls-files -ci --exclude-standard` は空で、追跡中のファイルを新しく無視しない。`git check-ignore --no-index` で、根と深い位置の `.claude/settings.local.json`、深い位置の `__pycache__/`、`.env`（根と下位）、`*.pem` が当たることを確かめた。`.claude/settings.local.json` は途中に `/` を含むので、`**/` がないと根にだけ当たる。`**/` を付けたのは、依頼の「どの深さの」に合う。
- skill-eval の `regex_text`: 参照の解答 `reference.bnt` を、worktree で作った処理系で直した後の `messages.txt` に対して走らせ、出力が `expected.stdout` と一致した。並びは task.md の「in alphabetical order」どおり（`example.com`・`example.org`・`sub.example.net`）。

## 所見

### 1. E0313 の説明の文の「the uppercase names of the module」があいまい

- 重さ: 直すとよい。
- 場所: `crates/benitoite/src/diag/codes.rs` 407 行（E0313 の説明の文）。生成物は `crates/benitoite/skill/references/diagnostics.md` 751 行付近。
- 問題: 「Type parameters and effect variables cannot reuse the uppercase names of the module, imported names, prelude names, or `Benitoite`.」の「the uppercase names of the module」は、どのモジュールか（自分のモジュールのトップレベル）が読み取りにくい。見出しの文の「a top-level declaration」とも語が揃っていない。study の案をそのまま使ったもので、誤りではない。
- 直し方の案: 「Type parameters and effect variables cannot reuse the module's top-level uppercase names, imported names, prelude names, or `Benitoite`.」とし、`gen_skill` で生成物を作り直す。

### 2. E0441 の単体テストの確かめが緩く、同じ定数を 2 行で確かめている

- 重さ: 直すとよい（そのままでも可）。
- 場所: `crates/benitoite/src/typeck/effects/tests.rs` 391〜393 行。
- 問題: `contains("Result.ok")` は `Result.okay` などの誤記でも通る。また E0441 の注記は向きによらず一つの定数なので、表の E0441 の 2 行で同じ文を確かめており、ゴールデン `types/todo178-placeholder-try-error.diag.json` も同じ文を全体で確かめている（test-audit の「同じ契約を、同じ呼び出しで繰り返すテスト」に近い）。依頼どおりの追加で、直す前に失敗することも確かめてあるので、害はない。
- 直し方の案: 確かめる文字列を `` "`Result.ok`" ``（逆引用符を含む）にする。重なりが気になるなら、`if code == C::E0441` の確かめを残したまま、表の `help` の欄を E0441 の行だけ `` "`Result.ok`" `` に変えて `if` を消す形もある。

### 3. E0125 の説明の文が、C2 の実装より先に「拒む」と書く

- 重さ: 記録だけ。
- 場所: `crates/benitoite/src/diag/codes.rs` 170 行（E0125 の説明の文）、`skill/references/diagnostics.md` 215 行。
- 問題: 「It refuses to replace a read-only file, a file with more than one hard link, or a file owned by another user.」は、C2 が拒む処理を入れるまで事実と合わない（今の fmt は 0444 のファイルも置き換える）。plan.md は C2 を W の取り込みの後に置くと定めており、改造の中の順としては問題ない。文自体は Q3 の決定と一致し、英語として自然である。「Writing or renaming failed or was refused」も、拒むときに注記 `reason` で理由を示す C2 の設計と合う。
- 直し方の案: 直さない。W を取り込んだ後、C2 を取り込むまでの間にリリース・push・Skill の配布をしない。C2 のレビューで、拒む 3 つの場合がこの文と一致すること（特に「owned by another user」が、実行した利用者と所有者の比較であること）を確かめる。

### 4. E0313 のラベル「the other declaration is here」が import の行を指す

- 重さ: 記録だけ。
- 場所: `crates/benitoite/src/diag/codes.rs` 406 行。
- 問題: import の別名と衝突したとき、補助の位置は import の行を指し、ラベルは「declaration」と呼ぶ。import も名前を導入する宣言とみなせるので誤りとまではいえず、study の案どおりである。prelude の名前は位置を持たないので、補助の位置は付かない（今のまま）。
- 直し方の案: 直さない。気になるなら、後で「the other name is declared here」などを検討する。

### 5. `recorded_path` は文字列の途中も置き換え、実パスと別名の家は扱わない

- 重さ: 記録だけ。
- 場所: `tools/syntax-measure/bntmeasure/harness.py` 49〜55 行。
- 問題: (a) 文字列の途中の出現も置き換えるので、`/x/Users/<名前>/…` のような家の下でないパスも `/x~/…` になる。版の取得の失敗の文を伏せるための意図した挙動で（docstring に書いてある）、現実の記録で起きる見込みは小さい。(b) `find_outside_access` は `os.path.realpath` で得たパスを記録するので、家のディレクトリがシンボリックリンクを含む環境（`HOME` と実パスが違う環境）では、実パスの接頭辞が置き換わらずに残る。macOS の `/Users/<名前>` では起きない。(c) 家が `/` のときは接頭辞が `//` になり何も置き換えない。いずれも記録の見た目だけの話で、実際に使うパスと測定の結果には響かない。
- 直し方の案: 直さない。必要になったら、`os.path.expanduser('~')` と `os.path.realpath` の両方の接頭辞を置き換える。

### 6. regex_text の課題の変更で、過去の評価の記録と比べられなくなる

- 重さ: 記録だけ。
- 場所: `tools/skill-eval/tasks/regex_text/input/messages.txt` 2 行、`expected.stdout`。
- 問題: study.md の A-9 に書いたとおり、課題の入力と期待が変わるので、`tools/skill-eval/results/` の過去の記録の regex_text とは比べられない。次の評価の記録に、課題を変えたコミットを書き添えるとよい。
- 直し方の案: 直さない。改造を閉じるときの記録（CHANGELOG ではなく評価の道具の側）で触れる。

## 規約の確かめ

- 文言はすべて `diag/codes.rs` の表と `cli/tools/licenses.rs` の `text` にあり、処理の関数の中に英語の文を書いていない。
- `decimal.rs` の本体は `unwrap`・`expect`・添字を使っていない（`map_or` と `split_once`）。テストのモジュールの `unwrap` は許可の範囲である。
- 追加のコメントはない（`recorded_path` の docstring は日本語で理由を書いている）。設計書・`docs/reference/`・CHANGELOG・`formal/`・他の作業のファイル（`json.rs`・`Cargo.toml`・`cli/tools.rs`・`cli/mod.rs`・`diag/render.rs`・`tests/cli_process.rs`）は変えていない。
- 設計書への反映（01-04「型の変換」と 01-09 の注記の削除、06-01 の fmt の説明、CHANGELOG の Q7）は、依頼どおりオーケストレータに残っている。
