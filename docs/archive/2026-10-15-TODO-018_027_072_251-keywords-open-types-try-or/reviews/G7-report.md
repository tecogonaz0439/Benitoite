# G7 レビュー報告（M1〜M5、移行）

対象: `git diff 4836bbba bd9be1d0`（M1 bc64ce5a、M2 bee15f92、M3 062429d5、M4 1a51244b、M5 0d269a63 とそれぞれの取り込み）。cargo・check.sh は実行せず、git の読み取り（`git grep bd9be1d0`、`git show`、`git diff`、`git log`）だけで確かめた。

## 結論

重大 0 件、中 2 件、軽 3 件。サンプルの移行（観点 1）、テストのデータの保持（観点 2）、意味の保存（観点 3）に、移行の漏れや誤りは見つからなかった。指摘は、移行の道具の分類の穴と旧移行器の残件の扱い、文書の小さな不整合である。

## 観点ごとの確認結果

### (1) サンプルの取り残し

bd9be1d0 の時点で、`docs/design`・`docs/reference`・`crates/benitoite/skill`・`crates/benitoite/examples`・`tools` を次のように探した。

- `git grep -nw try` から ` or ` を含む行を除き、ファイルごとに数えて全行を読んだ。
- コードらしい形（`= try X`、`(try X`、`<- try X`、行頭の `try X`、`|> try`、行末の `try`、`, try`、`{ try`、`: try`）を `or return` / `or die` なしで探した。
- `or` の後が `return` / `die` でない `try … or …` を探した（0 件）。
- テスト以外のすべての `.bnt`（testdata・tests・fuzz・archive・改造のディレクトリを除く）を探した。ヒットは skill-eval の 3 ファイルだけだった。この 3 件は複数行の `List.fold(... lambda ... end lambda) or return` であり、処置は lambda の後の行にある（csv_report:23-26、http_client:30-34、json_summary:27-30）。

残った裸の `try e` はすべて、意図して裸を示す箇所か、サンプルではない箇所だった。

- 裸の意味・型規則・脱糖・優先順位を説明する一般形: 01-09:37,41-44,62、01-12:435,464,741-742、02-02:111、02-05:238、01-02:220-221 など。M5 の review.md の「裸の一般形 4 件」と M3 の「AST の裸 26 件」に記録がある。
- `crates/benitoite/examples/stack_probe/support.rs:160,172`: スタックの深さを測る生成断片。M4 results.md に hold 7 件として保持の理由がある。
- `tools/syntax-measure/`: 構文の測定の固定入力。decisions.md:323（R1）で歴史資料として編集しないと定めている。
- Python の `try:`、Gleam の `result.try`（08-04:1002,1058-1059）、Zig の `try`（08-03:230）。

英語の現行のサンプルに、裸の try の取り残しはない。docs/ja には触れていない（M8 の担当。`git diff --stat` は空）。

### (2) テストのデータ

`crates/benitoite/testdata`・`tests`・`fuzz`・`formal` で変わったのは、`testdata/lexical/unknown_symbol.diag.json` の E0211 の help の全文だけである。これは診断の期待値で、裸の try の入力ではない。`.bnt` の検査入力は 1 件も変わっていない。M5 の audit.py は、golden の 66 入力と関連する 254 ファイルのハッシュの一致、Rust の検査断片 163 件の一致、差のある 5 断片の個別の対応付けを記録している。通常の検査には、裸のまま残すことを確かめる常設の検査はない。その代わり、移行器の `editable()` が `role()` を独自に計算し直し、test・history・generator への適用を拒否する。manifest の role 欄を書き換えても、この拒否は外れない。この二つで保持は担保されていると判断した。

### (3) 意味の保存

- `or return` への書き換え（M3 の 26 箇所と手作業の 12 箇所、M4 の 136 箇所）は、01-02 の「`try r or return` と裸の `try r` は、型と評価の意味が同じ」により意味を変えない。入れ子の引数（http_client:26 の `o: try … or return,`）、`with` の束縛（`… or return,` / `… or return do`）、`match try … or return with`（03-07:162）、複数行の lambda の末尾は、AST の operand の末尾に挿入されていた。
- `or die` は、一回限りの入口の 11 個の main だけに使っていた（idioms、common-mistakes、language-comparison、benitoite.md の orders の例）。main を `Unit` にし、`Process.Exit` と import を加え、mapError を外している。どれも 01-09・06-06 の「入口は or die」に沿う。Show の要求は、IOError・NetworkError・Json.ParseError・Csv.ParseError・String が満たす。失敗時の出力（文言と終了状態）は変わるが、成功時の出力の期待は変わらず、Q6 の範囲内である。HTTP の例（idioms:470-484）は `with … TaskGroup.open()` の中で die するようになった。旧形は、失敗するとサーバのタスクの終わりを待つ形だったので、悪化ではない。
- main が Result.Error を返す契約を教える例（benitoite.md 9 章、idioms:94-100、SKILL.md:128）、標準ライブラリ、ベンチマーク、skill-eval の参照解は `or return` を保っている。M4 results.md の表に理由がある。

### (4) 移行の道具の安全性

- `apply` は、外から渡した SHA-256 と manifest 全体のハッシュを照合する（`shared.reviewed_manifest`）。続けて全入力のハッシュ、編集範囲の重なりと変更前の内容を確かめてから書き込む。receipt による再適用は差分なしになる。
- `selected(approved=True)` は、`confirmation == approved`、保留なし、`typed`、処置の編集がちょうど 1 つであること、die の契約の確認を求める。入れ子の部分的な承認は拒否する（R77）。`inventory` と `diff` は書き込まない。
- 旧 named-arguments-migrate は共通部分へつないだ。削除した行は、共通化した関数の旧い実装だけである。テストの assert は削っておらず、追加は 1 件（`test_reviewed_manifest_cli_without_inventory`）である。receipt の照合は、全入力のパスの集合の一致を加えて厳しくなった（R76）。

### (5) 旧移行器の 8 件中 6 件の失敗

既知の問題で、この改造が壊したものではない。

- `n1/joins.json`・`call-candidates.json` は、TODO-247 の保管のコミット（旧履歴の 808d4a48 "Remove machine outputs over 100 KB"。書き換え後の 0.0.5、5ef09b51）で除かれている。5ef09b51 の時点で、`docs/archive/…TODO-247…/n1/` に joins.json はなく、migrate.py:350 はすでにそれを読んでいた。
- 旧構文を拒否する E0257・E0449・E0454 も 5ef09b51 からある。旧い自己検査は、0.0.5 の時点で通らなくなっていた。
- 件数の違い（R75 は 7 件中 6 件、M5 は 8 件中 6 件）は、M1 が成功する 1 件を加えたためで、整合している。

### (6) テストを弱めていないか・規約

- Rust のテストは、`help_tests.rs` に 1 行と全文の厳密な assert を加えただけである。削除・緩和・ignore はない。
- 公開の文書に `docs/todo` へのリンクはない。AGENTS.md の表に 2 つの道具を追記し、check.sh の glob・変更分類・自己検査へ登録した。見出しの改名はない。

## 指摘

### 【中】1. 移行器が `benitoite test` などの実行用の fence を「notation」に分類し、保留として出さない

- 場所: `tools/try-actions-migrate/migrate.py` の `markdown_extras`（info 文字列が `''`・`text`・`bnt`・`benitoite` 以外の fence を `non_executable_fence` とする）と、`inventory` の classification の判定の順（`'notation' if not t and unit['kind'] in ('markdown_inline', 'markdown_notation')` が `'hold' if holds` より先にある）。
- 問題: info 文字列が `benitoite test` の fence の中の裸の try は、hold の理由に `non_executable_fence` を持つのに、分類は `notation` になる。M3 の manifest で確かめると、移行前の SKILL.md:152、idioms.md:645・650、benitoite.md:948 の裸の try は、どれも `notation` だった。M3 は R79 で手作業で拾ったので、現在のサンプルに漏れはない。しかし、道具の集計では手本の漏れが「記法」に紛れる。M5 の review.md は notation 244 件を「語、EBNF、構文・型・脱糖の一般形」と説明しているが、移行済みの `benitoite test` の fence の候補もここに入っており、説明が実態とずれる。道具は後の改造（TODO-250 の後の弾）でも使う前提である。
- 修正案: info 文字列の最初の語が `benitoite` の fence をコードとして解析する（`test` の文脈で AST を取る）。それができなければ、`non_executable_fence` の保留を持つ断片を `notation` ではなく `hold` に分類する。あわせて、自己検査に `benitoite test` の fence の裸の try が hold か change になる例を加え、README の `notation` の説明を直す。M5 の review.md の notation の内訳に、`benitoite test` の fence を含むことを書き足す。

### 【中】2. 旧移行器の自己検査が通らない残件（R75）が、docs/todo にも道具の README にもない

- 場所: `tools/named-arguments-migrate/`（README.md、migrate.py:13 の BASE、:319 の joins.json の読み込み）。decisions.md の R75、m5/results.md の検査の表。
- 問題: (5) のとおり既知で、この改造の責任ではない。ただし、道具は AGENTS.md の表に使える道具として載っている。check.sh の python の検査はこの自己検査を呼ばないので、壊れたまま気付かれにくい。docs/todo を `git grep` しても、この残件の項目はない（overview-and-roadmap.md:146 は「TODO-247 の移行の道具を再利用する」と書いているだけである）。plan の M1「旧 CLI とテストの結果を保つ」と M5「新旧の移行器の自己検査」は、形式上は満たされていない。
- 修正案: オーケストレータが G7 の判断として R75 を受け入れ、docs/todo に項目を加える（例: 「named-arguments-migrate の inventory と自己検査は、0.0.5 の保管で除いた n1 の基準データと旧構文の入力に依存しており、通らない。道具を歴史資料にするか、基準データなしで動く形に直すかを決める」）。README の冒頭にも、inventory と自己検査が今は通らないことを一文で書く。

### 【軽】3. 01-09 の「裸の形の優先順位では」が、明示形の優先順位は違うと読める

- 場所: `docs/design/01-spec/01-09-errors.md:62`
- 問題: 「裸の形の優先順位では、`try f(x) + 1` は `try (f(x) + 1)` である」とある。明示形でも、`try f(x) + 1 or return` は `try (f(x) + 1) or return` で、優先順位は同じである。限定の語が、違いがあるかのように読ませる。
- 修正案: 「処置の有無によらず、`try f(x) + 1 or return` は `try (f(x) + 1) or return` である。」とし、サンプルの方針どおり明示形で例示する。

### 【軽】4. idioms.md の導入文が、直後の例と合わない（もとからある問題）

- 場所: `crates/benitoite/skill/references/idioms.md:82`
- 問題: 「Bare try, like `or return`, returns early with the error; `Result.mapError` turns an IOError into a String first.」とある。直後の例は `or return` を使い、mapError も IOError も出てこない（parsePort は String の誤りを返す）。後半はもとからある問題だが、例を明示形にしたことで、裸の try を主語にする書き出しとも合わなくなった。Skill は LLM が手本として読む。
- 修正案: 「`or return` (with the same meaning as bare try) returns early with the error.」とし、mapError の部分を削る。gen_skill の対象ではない手書きの文書なので、手で直す。docs/ja の訳は M8 で合わせる。

### 【軽】5. 足した `import …IO.Process` が、ほかの例の import の並び（アルファベット順）を崩す

- 場所: `crates/benitoite/skill/references/idioms.md:259`（Json の後）、`:447`（Network.Http の後）、`docs/reference/benitoite.md:1132`（Json の後）
- 問題: ほかの例は `IO.Console`・`IO.File`・`IO.Process`・`Json` の順で並べているが、この 3 箇所だけ IO.Process が末尾にある。文法上の誤りではないが、手本の一貫性を欠く。
- 修正案: `import Benitoite.Unofficial.IO.Process` を `IO.File` の直後へ移す（出力の期待は変わらない）。

## 備考（指摘ではない）

- check.sh の classify に加えた `tools/source-migrate/*|tools/named-arguments-migrate/*|tools/try-actions-migrate/*` は、次の `tools/*` と同じく python を選ぶだけなので、冗長だが害はない。
- python の検査で `cargo build --example try_actions_inventory` を走らせるので、Python の道具だけを変えたときにも cargo のビルドが要る。意図した接続と読んだ。

## 対応

2026-10-16、Z9 で次を修正した。

1. 【中】1: info 文字列の先頭の語が `benitoite` の未解析の実行用 fence を `hold` に分類するよう修正した。`non_executable_fence` の保留理由を維持し、解析の追加は行っていない。既存の分類の自己検査へ `benitoite test` の例を追加し、修正前に `notation` と `hold` の不一致で失敗することを確認した。既存の assert はすべて残した。README と M5 の notation 244件の説明も直し、過去の集計値は当時の記録として維持した。判断は decisions.md の R80 に記録した。
2. 【中】2: 旧移行器の README に、TODO-247 の移行は完了済みであり、0.0.5 の保管で N1 の入力の記録を除いたため inventory は通らず、自己検査は8件中6件が失敗することを追記した。オーケストレータが登録した docs/todo の TODO-253 を文字で参照し、M1・M5 の完了条件との差を R75 に補足した。旧検査の assert は変更していない。M5 の段末の `scripts/check.sh --only rust,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python` は、オーケストレータが bd9be1d0 で通過を確認済みである（2026-10-16、35分）。Z9 では再実行していない。
3. 【軽】3: 01-09 の優先順位の説明を「処置の有無によらず」とし、明示形で例示した。
4. 【軽】4: idioms.md の導入を `or return` の説明に直し、直後の例にない `Result.mapError`・IOError の説明を除いた。同ファイルは手書きの文書であり、生成元の変更は不要だった。
5. 【軽】5: idioms.md の2箇所と benitoite.md の1箇所で、IO.Process の import をアルファベット順へ移した。HTTP の例には IO.File の import がないため、IO.Console の直後とした。docs/ja の訳は M8 に引き継ぐ。

検査: 次が通過した。

- `cargo build -p benitoite --example try_actions_inventory`
- `python3 -B tools/try-actions-migrate/test_migrate.py`（6件）
- `cargo run -p benitoite --example gen_skill`（生成物・bundle の差分なし）
- `cargo test -p benitoite --lib`（1,194件成功、既存の21件は ignore）
- `cargo test -p benitoite --test reference_examples --test skill_docs --test skill_examples --test spec_examples`（計19件成功）
- `cargo clippy --all-targets`
- `cargo fmt --check`

テストの assert の削除・期待値の緩和・ignore の追加はない。formal/ と docs/todo/ は変更していない。`scripts/check.sh` と gc-stress の構成の検査は、依頼のとおりオーケストレータに委ねる。
