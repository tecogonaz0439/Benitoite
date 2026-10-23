# RV-G1 作業 G1 のレビュー

- 日付: 2026-10-24
- 対象: コミット `e0ed5eb2888349dbb0d251843627c527d7ffc0b0`（基準は親の `baca0076e5f08abace9cc22136ed2f690f208684`）。
- 読んだもの: `git show e0ed5eb2` の全差分（20ファイル）。plan.md の「作業 G1」と「検査の割り当て」、decisions.md の D41・D42、reviews/RV-F5.md、RV-I・RV-II・RV-A12・RV-A36・RV-C・RV-F13・RV-F4 の指摘の一覧、28作業の results.md の申し送りの節、`scripts/check.sh` の単位の選び方、`scripts/check-formal.sh` と `formal/tests/test_batch5_exchange.py` の G1 後の全文、`crates/benitoite/src/types/mod.rs` の `Ty`、`formal/Benitoite/Exchange/CheckInput.lean`、`formal/tests/batch5-exchange/corpus.json`、15回の short の `result-manifest.json`・`invocation.json`・`manifest.json`。リポジトリのファイルは `git show` だけで読んだ。作業ツリーで読んだのは、追跡外のログ `target/g1/*.log` だけである（読み取りのみ）。
- 実行していないもの: ビルド、テスト、`check.sh`、`check-formal.sh`。
- 確かめたこと: 記録の SHA-256（入力4ファイル、差分、監査の JSON、ログ）をコミットの内容やログと照合した。short の判定の内訳はスクリプトで数え直した。集約の表の数が元の記録にあるかもスクリプトで照合した。

## 結論

重・中の所見はない。軽の所見が5件ある（いずれも記録の表現か、検査の運用への提案）。観点 1〜3（検査の範囲、match の意味、07-04 の正確さ）に問題はない。観点 4 の集約は、数・判定・コミットとも元の記録と一致した。change の結果は全件の成功を示し、走らなかった単位はない。観点 5 の Z1 への申し送りにも漏れはない。G1 を取り込んでよい。

## 観点ごとの確認

### 1. `check-formal.sh` と `test_batch5_exchange.py`（検査の範囲）

- `test_batch5_exchange.py` の `__main__`（281〜289 行）は、`--rust-dir` の有無にかかわらず `unittest.main(argv=[__file__, *rest], exit=False)` で独立入力の単体テスト8件を先に走らせる。失敗すれば `SystemExit(1)` で止まり、成功したときだけ `check_rust` に進む。したがって、`check-formal.sh` 155 行の一回の呼び出しで、独立入力の単体テストと Rust 出力の六入口の比較がそれぞれ一度ずつ走る。削除した 138〜141 行（旧）の単独の呼び出しも同じ8件を走らせていただけなので、検査の範囲は狭まっていない。`set -euo pipefail` のもとで失敗が全体を止める点も変わらない。
- 違いは実行の順序だけである。独立入力の単体テストは、以前は `cargo test --test desugar_export` の前に走り、今はその後に走る。どちらの順でも、失敗すればスクリプト全体が止まる。
- 数えた値の変更（241〜242 行）について。`formatted_string_fallback = strings - manifest['plainString']` と `require(formatted_string_fallback == 0)` は、旧来の `require(strings == manifest['plainString'])` と同じ条件である（整数の差が0であることと等しいことは同値）。失敗の条件は緩んでいない。報告の欄と標準出力が、定数の0から数えた値に変わっただけである。
- 変更した見出し（`batch5 independent/Rust exchange`）を名前で読む道具やテストはない（`git grep` で確認）。
- ローカルの `target/g1/batch5.log`（SHA-256 は batch5.json の記録と一致）では、`Ran 8 tests ... OK` に続いて `batch5: 32 definitions, 28 formatted, 3 formatted String, 0 fallback; six entries agree` が一度だけ出ている。

### 2. `try_actions_inventory.rs` の match

`Ty` の変種は `Con`・`Fn`・`Param`・`App`・`Rigid` の五つである（`types/mod.rs` 140〜151 行。`#[non_exhaustive]` は付いていない）。新しい第2の腕は五つすべてを挙げ、ガードの外れた `Ty::Fn(_)` も含めて `None` を返す。元の `_ => None` と意味は同じである。網羅性はコンパイラが確かめるので、変種が増えればコンパイルの誤りになる。それが `clippy::wildcard_enum_match_arm` の意図でもある。

### 3. 07-04 の変更

- RV-F5 L1: 「段階 E2 の入口の準備（`Exchange.CheckInput.prepare`）」は実装と一致する。`formal/Benitoite/Exchange/CheckInput.lean` は `namespace Benitoite.Exchange.CheckInput` の中で `def prepare` を定義し、111 行で `validateFormatHeads` を呼ぶ。同章のほかの箇所の「段階 E2」とも表記がそろった。308 行の表も同じ表現にした。設計書のほかの章に旧表現「E2の準備」は残っていない。
- RV-F5 L2: 独立入力 `corpus.json` は29定義（`format-0`〜`format-24` の25件と、`plain-string`・`mixed-string`・`plain-converted`・`empty-interpolation`）である。`check_rust` は `range(25)` で `format{index} (` に当たる25件を比べる。「29定義のうち、Rustのソースと対応する25関数」は正確である。
- 現在の実装だけを書く規約にも反していない。189 行の「`check-formal.sh`はこの独立入力とRust入力の検査を全比較に含める」は、スクリプトの現在の内容（155 行）と一致する。

### 4. 集約の照合

- 作業の表（`results.md` の「作業ごとの照合」）の28行について、各行の時間・件数の数字は、すべて元の `<作業>/results.md` に現れる（スクリプトで照合）。`work-audit.json` の28作業・8レビューの SHA-256 は、コミットの中のファイルと一致した。
- レビューの表の ID は、各レビューの指摘の一覧と過不足なく対応する（RV-I の M1・L1〜L6、RV-II の H1・M1・L1〜L5、RV-A12 の M1・M2・L1〜L7、RV-A36 の中1〜3・軽1〜10、RV-C の P1〜P5・E1・C-1〜C-4・T-1〜T-2、RV-F13 の M1・L1〜L11、RV-F4 の M1・L1〜L7、RV-F5 の M1・L1〜L4）。
- short の15回は、すべて before が W1（`a1f4fb5f…`、D41）で、66点、skipped は空である。達成・判定不能の内訳（W2 1/65、A1〜A6 0/66、C1 2/64、C2 19/47、F1 10/56、C2R 5/61、F2 6/60、F3 6/60、F4a 3/63、F4b 6/60、F5R 3/63）と、退行の疑い0は、元の `result-manifest.json` と一致した。外側の時間も `invocation.json` と合う（F1 の 35.037 秒は f1r/results.md の外側の値で、invocation の 34.991 秒と矛盾しない）。higher-0-300 の +8.4%（0.028500/0.026291）と +4.5%（0.028292/0.027085）も元の表どおりである。W2 の転記の誤りの訂正（「65点すべて」→ 66点、達成1・判定不能65）は正しい。`short-audit.json` の45件の SHA-256 も一致した。「W2Rを含む」などの注記は、取り込みの順序（`git log`）と合う。
- change について。初回 change のログ（`target/g1/change.log`、SHA-256 一致）の自動選択は16単位で、spec_examples・reference_examples・skill_docs は test_default_all に含まれて外れている。続行の `--only` は、そこから fmt・lint_default を除いた14単位と一致する。除いた2単位は、work でも change でも同じコマンド（`cargo fmt --all --check`、`cargo clippy -p benitoite --lib --tests …`）である。修正後の work-rust で成功しており、引用は成り立つ。example を lint するのは lint_heap（`--workspace --all-targets`）だけで、これは続行で走った。続行のログ（SHA-256 一致）には14単位の見出しがすべて現れ、最後は `selected checks passed` で終わる。`check-summary.json` の件数（既定 2918＝lib 1271＋統合 378＋examples 1269、heap 2932、stress 1653＝1278＋375、文書 34、長い対象 29×2、Miri 59・52、到達可能性 51）は g1/results.md の表と一致し、失敗は0件である。
- `input-state.json` の4ファイルの SHA-256 と、`git diff --binary baca0076 -- <4パス>` の SHA-256（`cddae71f…`）は、コミット `e0ed5eb2` の内容と一致した。検査した入力と取り込んだ内容は同じである。
- コミットの差分に手元の絶対パス（利用者のホームディレクトリから始まるもの）は残っていない。
- D42 の扱いについて。K1 は改造の results.md・g1/results.md・plan.md のすべてで参考記録とされ、受け入れの証拠に引用されていない。

### 5. Z1 への申し送り

各作業の申し送りとレビューで Z1 や後の担当へ回した事項（RV-A36 の軽1 の v0.0.11 への固定リンク、軽3 の D37 の三項目と保留理由、軽9、W1・W2 の第三者表示と訳、A4 の 06-09 の訳、RV-II L2 と W2R の幅の表の大きさ、F3R の RV-F13 L5、K2、release_stack、一時防御の照合）は、すべて改造の results.md の「Z1と取りまとめへの申し送り」の表に入っている。F1 の基準版の2失敗は C2R で解決済みである。漏れは見当たらない（所見 L2 の検査の運用の提案を除く）。

## 指摘

### 重

なし。

### 中

なし。

### 軽

#### L1 named_arguments の退行の一行が、見落としの原因を C1 にも帰している

- 場所: 改造の `results.md` 46 行（「C2で入ったnamed_argumentsの退行は、C1・C2のworkが統合テストを名指しで絞ったため見落とされ…」）、`g1/results.md` 16 行（「C1・C2の対象限定で見落とし」）。
- 問題: c2r/results.md の「導入された取り込みの特定」は、A6R の後まで2件とも成功し、C2 で失敗し始めたことから、導入を C2 と特定している。C1 の時点には退行がまだないので、C1 の work の絞り込みは見落としの原因ではない。c2r/results.md 73 行が外したのも「work C2 の関連3ターゲットの限定」である。
- 修正案: 「C2で入ったnamed_argumentsの退行は、C2のworkが統合テストを関連3ターゲットに絞ったため見落とされ、F1の全統合で見つかり、C2Rで導入版を特定して修正した。」とする。g1/results.md 16 行も「C2の対象限定で見落とし」に改める。

#### L2 work の lint が examples を検査しない穴を、申し送りに残していない

- 場所: `g1/results.md` 39 行、改造の `results.md` の「Z1と取りまとめへの申し送り」の「後の課題・任意項目」の行。
- 問題: 全域パターン `_ => None` は A6（`81bf92d4`）が加えた。A6 以降の work の lint_default は `cargo clippy -p benitoite --lib --tests` で examples を含まず、examples を clippy にかけるのは lint_heap（heap の種類か change のときだけ選ばれる）だけである。そのため、A6・A6R・C1 以降の各作業を通り抜け、G1 の change で初めて見つかった。change が安全網として働いたので不具合ではない。ただ、g1/results.md 39 行は原因を説明しただけで、後の課題として誰にも渡していない。
- 修正案: 申し送りの表の「後の課題・任意項目」に「work 水準で examples の変更が clippy にかからない（lint_default は lib/tests のみ、examples は lint_heap か change でだけ検査）。`crates/benitoite/examples/*` の変更で examples の lint を選ぶかを検討」と加え、docs/todo を扱える取りまとめへ渡す。G1 で check.sh を変える必要はない。

#### L3 `check-summary.json` に単位ごとの終了状態がない

- 場所: `g1/check-summary.json` の `units`。
- 問題: lint_heap・source_rules・skill_generated・spec_tally・python_syntax・licenses・heap_checks・formal_build は、件数がすべて0で記録されている。成功は、check.sh が最初の失敗で止まることと、ログの最後の `selected checks passed` から推論するしかない。そのログはリポジトリの外（`target/g1/`、SHA-256 だけを記録）にある。今回はローカルのログで14単位の見出しと最後の成功を確かめたので、結論は変わらない。ただ、保管した後の記録だけでは、走らなかった単位と成功した単位を区別できない。`plan:` の行が単位として並んでいる点もまぎらわしい。
- 修正案: 各単位に `"status": "passed"`（ログの見出しの存在と全体の終了0から導いたもの）を加え、`plan:` の行を `units` から外す。または、`note` に「件数のない単位の成功は、fail-fast の全体の終了0とログの見出しの存在から判断した」と一文を足す。任意。

#### L4 「G1の変更は未コミット」が取り込み後の状態と合わない

- 場所: 改造の `results.md` 3 行、`g1/results.md` 3 行・70 行、`input-state.json` の `head`。
- 問題: 記録の時点では正しいが、取り込んだ後は `e0ed5eb2` にコミットされている。保管した後に読む人は、G1 の検査がどの版に当たるのかを自分で突き合わせることになる。
- 修正案: 取りまとめが取り込みの記録か Z1 の集約に、「G1 は `e0ed5eb2` として取り込んだ。検査は `baca0076`＋未コミット差分で行った。input-state.json の4ファイルの SHA-256 と差分の SHA-256 `cddae71f…` は取り込んだ内容と一致する（RV-G1 で照合）」と一行を加える。任意。

#### L5 「作業28件、追加修正7件」が35件と読める

- 場所: `g1/results.md` 14 行。
- 問題: 作業の表の28行は、追加修正の7作業（W2R・A2R・A6R・C2R・F1R・F3R・F5R）を含む。並べて書くと合計35件に読める。
- 修正案: 「作業28件（うち追加修正7件）」とする。

## 重さの要約

| ID | 重さ | 種類 | 要旨 |
|---|---|---|---|
| L1 | 軽 | 読めば確定 | named_arguments の見落としの原因は C2 の work の絞り込みだけで、C1 は関係しない |
| L2 | 軽 | 運用の提案 | work の lint が examples を含まない穴を、後の課題として申し送る |
| L3 | 軽 | 記録の形（任意） | check-summary.json に単位ごとの成功の印がない |
| L4 | 軽 | 記録の表現（任意） | 「未コミット」の記述と取り込んだ版 e0ed5eb2 の対応を一行で残す |
| L5 | 軽 | 読めば確定 | 「作業28件、追加修正7件」を「28件（うち追加修正7件）」に |

## 取り込みの判断

取り込んでよい。RV-F5 の L1〜L4 は直っている。L4 は検査の範囲を狭めておらず、L3 は失敗の条件を緩めていない。example の修正は意味を変えない。change は、自動選択と同じ単位を全件実行して成功した。fmt と lint_default の引用は同じコマンドの成功に基づく。集約の数・判定・コミットは元の記録と一致する。L1・L5 は Z1 の作業か取り込みの際に文言を直せば足り、L2 は取りまとめが docs/todo に登録するかを判断すればよい。
