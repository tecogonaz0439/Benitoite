# RV5 独立レビュー（0.0.9 最終候補）

対象は次の二つの差分である。

- `git diff ebfd0e26 f7243bb4`（RV4 の後。H1〜H3、A2、V1、取りまとめでの検査の直し、Q1〜Q3）
- `git diff 6b0568a3 f7243bb4`（改造全体。13 件の範囲の網羅を確かめるために読んだ）

作業ディレクトリは、san_benito の f7243bb4 を detached で取り出したものである。読んだのは次のものである。

- 改造の文書: D の design.md（第1・8・11・16〜18節を中心）、decisions.md（R17〜R22・R180〜R191）、plan.md、results.md、h1〜h3・a2・v1・q1〜q3 の results.md、q3/evidence.json の構成、perf/ の記録、reviews/RV4.md
- コード: `resolve/builders.rs`、`typeck/checked_args.rs`、`typeck/effects/declarations.rs`、`diag/codes.rs` の差分、`tests/call_allocations.rs`・`named_arguments.rs`・`property_library.rs` の差分、`desugar_export` の二つの manifest と `check_named.py`、`formal/tests/test_batch2_exchange.py`
- 道具: `tools/bench/compare/` の README・run.py・scenarios
- 文書: 07-02・change-plan-template・benchmark スキルの差分、CHANGELOG の 0.0.9 節、英日リファレンスと Skill の該当節、用語集

cargo・lake・scripts/check.sh は実行していない。実行結果についての判断は、各作業の results.md、D/results.md、q3/results.md と q3/evidence.json に拠る。以下では、コードや文書で確かめたことと、推測とを分けて書く。docs/todo はこの worktree にないので、TODO-262 の中身は確かめていない。

## 結論

**中1 を記録の上で片付ける（R190 に一文を足し、TODO-262 の中身を確かめる）条件で、設計者の受け入れに進めてよい。** 処理系・テスト・標準ソースに、受け入れを止める誤りは見つからなかった。

確かめた主な点は次のとおりである。

- **証拠と実候補の一致**: change を通した b90070b6 の後に、crates/・Cargo.toml・Cargo.lock・formal/ を変えたコミットはない（`git diff --stat b90070b6 f7243bb4 -- crates Cargo.toml Cargo.lock formal` は空）。その後に変わった入力は、`scripts/check.sh` の python_syntax の対象一覧（Q2。compare と scenarios を追加）、tools/bench/compare、AGENTS.md の一行、benchmark スキル、07-02、雛形、改造の記録だけである。check.sh の変更については、q2/results.md で python_syntax と policy_selftest を実行して通している。check-formal は df017c71 で通った。その後の変更は property_library.rs だけで、check-formal の入力ではない。Q3 の候補 92120a2f と f7243bb4 の差は q3 の記録だけである。
- **A2（RV4 の直し）**: 中1〜中3・軽1〜軽6 は、a2/results.md のとおり直っている。
  - 中1: `builder_special` から根 `Benitoite` で全モジュールを探す経路が消え、`upper` が返した import 済みの ModuleId だけを照合している。三種の構築器と Regex を、単一モジュールの場合と別モジュールだけが import する場合の両方で、E0303 二件と厳密に比べるテストがある。
  - 中2: 壁時計の assert だけを外し、512 MiB の上限と診断の assert は残している。
  - 中3: 現行の文書・標準ソース・生成物・Rust のコメントから「local classification／局所分類」は消えている（`git grep` で確かめた）。用語集には、第二級の値・構築器・ShrinkStep・二引数の型クラスが原語と出典付きで加わっている。
  - 軽1: 由来の位置を、直接参照の集合を鍵にして覚える。総確保の退行テストもある。
  - 軽2: E0819 の説明を直した。ただし、別の箇所に旧語が一つ残る（軽5）。
- **取りまとめでの検査の直し**: どれも期待を緩めていない。
  - 2777c244: batch2 の check_rust が求める版を、交換器の今の版 12 に合わせただけである。等値の検査はそのまま残る。
  - df017c71: 増えたのは、K1〜B2 の golden 10 入力（manifest の追加 10 項目と名前が一致する）、l40-regex の 1 定義、G2・G4 の生成例の 27→40 である。`check_named.py` は、項目に `surfaceChecks` があればその値と厳密に比べる形になった。値は manifest に固定してあり、Rust の出力から作っていない。
  - e9e441f8・ce50e3de: `cfg!(feature = "gc-stress")` のときだけ大きさを下げている。期待値は下げた大きさから同じ式で求めており、assert の条件の形は変わらない。既定と heap-verify では元の大きさのまま走る。heap-verify の long_only は change の 2 回目に含まれ、28 件を完了した。上限そのものを heap の構成で確かめるという主張は筋が通る。gc-stress で下げる前例は、interrupt_process・l31・random_programs にある。
- **H1〜H3**: Q3 が実 CLI で次の点を確かめている。
  - 版 2 の報告（testCheckReport・testResults とも [1,2]）。`--doc` のない呼び出しは版 1 のまま。
  - 全例の準備と許可の照合を最初の実行の前に終えること（E0512 で前の例も実行しない）。
  - 元コメントへの位置の対応（UTF-8 の列を含む）と、公開境界（E0301・E0340）。
  - E0506 の help。`Failure.toResult` の案内は、標準の Fail の解決済み ID と一致するときだけ足す。コードの分岐も同じ形である。
- **版・英日・同梱物**: 次のものが 0.0.9 でそろっている。Cargo.toml、Cargo.lock、README、CHANGELOG、英日の reference と install、手書き Skill とその訳、生成参照、bundle の全 70 文書（Q3 第4項）。git archive からのビルドと、生成のやり直しによる一致（Q3 第5項）も確かめてある。Q3 の読み替え 2 件のうち、保存例の 15.1 は書き損じであり、英日リファレンスの API で照合し直している。もう一件は Q3 自身の補助入力の整合である。証拠として十分と判断する（記録の残し方は軽6）。
- **性能**: R17・R19・R22 を達成と書いた箇所は見当たらない。確かめたのは CHANGELOG・英日リファレンス・設計書・results.md・perf/ である。CHANGELOG も "this entry does not claim measured speedups" と書いている。

指摘の数は、重0・中1・軽6 である。

## 重

なし。

## 中

### 中1 maxShrinkWork の推奨値の確定が、R190 で行き先を失っている

- ファイル:
  - D/decisions.md 1530〜1534 行（R190）
  - D/design.md 499 行・1168 行・1213 行
  - D/plan.md 319 行・455 行・497 行
  - D/q2/results.md 92 行（「maxShrinkWorkの推奨値の確定…は取りまとめに残る」）
  - 利用者向けの記述: `CHANGELOG.md` 15 行・33 行、`docs/reference/benitoite.md` 1383 行、`docs/ja/reference/benitoite.md` 1349 行、`docs/ja/skill/SKILL.md` 222 行
- 問題: design と plan は、R20 の推奨値 `maxShrinkWork: 10000` を「本測定後に確定する」としていた。Q2 も、この確定を取りまとめへ渡した。R190 は本測定をやめ、R17・R19・R22 の数値目標を TODO-262 へ送ると書いている。しかし、R20 の推奨値の確定には触れていない。一方で、利用者向けの文書は「subject to final performance measurement」「pending final performance measurements」「最終の性能測定で確認する」と、後で測ることを約束している。記録の上では、この約束を引き受ける項目が見当たらない。推測: TODO-262 にも含まれていない可能性がある（docs/todo は読めないので確かめていない）。TODO-258 を閉じるときに、この残りが落ちやすい。
- 修正案:
  - R190 に一文を足す。例:「R20 の maxShrinkWork の推奨値 10000 と上限 1000000 の妥当性の確認も、TODO-262 の本測定で行う。それまでは暫定の推奨値として案内する」。
  - docs/todo の TODO-262 に、同じ内容と、258 の縮小の目標（R22）が含まれていることを確かめる。
  - TODO-032・257・258 を閉じるときは、数値目標が TODO-262 に移ったことを、閉じる記録に書く。
  - 利用者向けの文言は今のままでよい。より正確にするなら、"a provisional recommendation that has not yet been confirmed by measurement" のように、確かめていないという事実だけを書く形に揃えるとよい。

## 軽

### 軽1 汎用の道具の README と benchmark スキルに、0.0.9 の古い手順が残る

- ファイル: `tools/bench/compare/README.md` の「実行例」の最後の段落（「0.0.9 は改造ディレクトリの `bench-targets.json` を使う targets で本測定する。…Q1 の final は試走用の `b90070b6…` であり、本測定時には受け入れる候補へ置き換える」）。`.claude/skills/benchmark/SKILL.md` の「版どうしの比較」の手順 1（「0.0.9 の本測定はその目標ファイルを使う targets とする」）。
- 問題: R190 で 0.0.9 の本測定は行わないことになったので、どちらの記述も事実と合わない。また、後の改造でも使う汎用の道具とスキルに、特定の版の計画と試走のコミット ID が書かれている（R188 の「コミット名や0.0.9の目標をランナーから除き」という趣旨とも合わない）。
- 修正案: 二つの文を消す。例が要るなら、「目標の例は 0.0.9 の改造の `bench-targets.json`（保管後は docs/archive）にある」と、場所だけを示す。

### 軽2 07-02 に足した二つ目の【決定】に理由がない

- ファイル: `docs/design/07-quality/07-02-performance.md`「測定の環境と記録」の二つ目の【決定】（「quick は出力照合と見込みの算出のための試走とし…」）。
- 問題: AGENTS.md「決定の書き方」は、決定の直後に「理由: 〜。」を 1〜3 文で書くよう定めている。一つ目の【決定】には理由があるが、二つ目にはない。中身は、README・スキル・run.py（quick の標本数・`--confirm-full`・short の 15 分の停止・判定不能）と一致している。
- 修正案: 「理由: 小さい入力と少ない標本では目標の大きさの点を測れず、ぶれ以下の差から合否を断定しないためである。」のような一文を足す。

### 軽3 性能の記録の置き場所と plan の「本測定」の行が、R190 の後の実際と合わない

- ファイル: 07-02「測定の環境と記録」の【方針】（置き場所は `tools/bench/results/`）。benchmark スキルの手順 5。D/plan.md 442 行・509 行（「tools/bench/results/の…追跡記録」）。D/results.md「性能（本測定の代わりの確認）」。
- 問題: 0.0.9 の short と targets の試走は、`--out target/bench/…`（追跡しない）に出力された。追跡するのは D/perf/ の写し 3 点だけである。R190 は測定の種類を変えた決定であり、記録の置き場所までは決めていない。plan の 442 行・497 行・509 行も、本測定を前提にしたまま注記がない。
- 修正案: D/results.md の性能の節に、「性能の受け入れの記録ではない確認の写しなので、tools/bench/results/ ではなく改造のディレクトリに置いた」と一文書く。plan.md の 442 行に「R190 により short と targets の試走に替えた」と注記する。

### 軽4 short で確かめられた範囲を、results.md で狭く書く方がよい

- ファイル: D/results.md 72 行。D/perf/short-results.md。`tools/bench/compare/scenarios/runtime.py`（`SHORT`）。`scenarios/builders.py`（族全体の `requires=('builders',)`）。
- 問題: 三点ある。
  - 実行時の族の short の点は 15〜27 ms で、そのうち約 11 ms は CLI の起動である（空の入力の functions-main-0-0 が約 0.012 秒）。VM の実行時間の退行に対しては感度が低い。0.0.9 は VM・ランタイムを変えていないので、結論そのものは妥当と判断する。しかし「大幅な性能の低下がない」は、主に検査時間の族と起動について言えることである。
  - 判定欄の「達成 38」は、R17・R19・R22 の目標の達成と読まれうる。
  - 構築器の族は、既存関数だけを使う比較の点（concatenate・join・fold）も、0.0.8 側では「missing features: builders」として除いている。そのため、旧版との比較ができる点まで判定不能になっている。
- 修正案:
  - results.md の性能の節に、short の実行時の点は起動の費用が大半であり、VM の退行の検出力は低いこと、0.0.9 は VM を変えていないことを一文で書く。
  - short の判定の語を「退行なし」に改めるか、results.md で「達成は退行幅以内の意味」と注記する。
  - 道具の側では、`requires` を構築器の手法の点だけに付け、既存関数の点を両方の版で測れるようにする（後の改造で直せばよい）。

### 軽5 「opaque representation」の旧語が、文書例の節に一か所残る

- ファイル: `docs/reference/benitoite.md` 1329 行（"including its opaque representation boundary"）。`docs/ja/reference/benitoite.md` 1307 行（「不透明な内部表現の境界」）。
- 問題: R170・R184 は語を「不透明型（opaque type）」に揃えた。A2 の記録は、旧語が残るのは過去の判断とレビュー原文だけと書いているが、H2 が足したこの一文が残っている。意味は通じるので、誤りではない。
- 修正案: "including the boundaries of its opaque types" に改め、訳を「不透明型の境界も含めて」に揃える。

### 軽6 Q3 の結果と保存例の書き損じが、改造の集約の記録に載っていない

- ファイル: D/results.md「release（自動の部分）」。D/q3/results.md「保存例の読み替え…」の 15.1 の行。D/design.md 15.1。
- 問題: 二点ある。
  - D/results.md は「手動照合は Q3 が行う」で終わっている。Q3 の判定（五項目とも一致）、候補の完全 ID（92120a2f）、最終 HEAD f7243bb4 との差が記録だけであることは、集約に書かれていない。
  - Q3 は design.md 15.1 の「checkPath へ一行だけ替える」例の書き損じを見つけ、読み替えて照合した。しかし、R191（15.3 の import）と違って、決定の記録にも design.md の直しにもなっていない。オーケストレータへの申し送りのまま残っている。
- 修正案:
  - D/results.md の release の節に、Q3 の判定・候補 ID・その後の差が記録だけであることを一行で足す。
  - 15.1 の書き損じは、R191 と同じ形で一つの R に記録する（例は直しても、注記だけでもよい）。
- 付記: `property_library.rs` の `deeply_composed_skip_sequences_advance_without_stack_growth` に e9e441f8 が足したコメントは、「大きさだけを下げる」とだけ書いている。元の大きさを既定と heap-verify の構成で確かめていることも書くと、ce50e3de のコメントと揃う。

## 観点ごとの確認の結果（指摘なし）

### 1. 13 件の範囲

- 設計書の 0.0.8 からの差分（40 ファイル）の追加行に、【未決】【要検証】・未実装・「予定」・docs/todo への参照はない（`git diff … | grep` で確かめた）。「本測定」の語は、07-02 の道具の手順の一か所だけである。
- 主な語（@opaque・Scope・Range・E0457・Monad2・StringBuilder・ShrinkStep・maxShrinkWork・--doc・inventory・Show・E0506・toResult）は、設計書・英日リファレンス・手書き Skill のそれぞれに出ている。032・257 の本体の表と制約の索引は、02-05 にだけある。これは、利用者から見える変化がないという design の扱いと一致する。日本語リファレンスの縮小の節は、英語より行が少ないが、Done・Yield・Skip、mapSteps・appendSteps、二つの予算の数え方を同じ内容で訳している。
- design 第1節の除外（Integer の網羅、篩型、型構成子の部分適用など）は、CHANGELOG の "There is no partial application of type constructors…" などと矛盾しない。

### 2. A2・H1〜H3・V1 のコード

- E0506 の説明の文には Failure.Fail の案内が常に入るが、"For the standard Failure.Fail" と範囲を限っている。help の分岐は ID で判定している。
- `origin_labels` のキャッシュは、トップレベル const の依存が本体の検査中に変わらないという前提に依っている。その前提は 02-05 の記述と合っている。

### 3. 道具と文書の一致（Q1・Q2）

- 次の決まりは、README・スキル・07-02・雛形・run.py で一致している。
  - short は 2 状態に限り（`parser.error`）、代表点・5 標本で走る。実入力の照合からの見込みが 15 分を超えれば、標本を採る前に止まる（`enforce_short_budget`）。
  - targets は `--targets` を必須とし、10 標本で走る。
  - full は `--confirm-full` を必須とし、全点の資源を測る。
  - quick は試走であり、受け入れに使わない。
  - 判定不能は、差が両方の半幅の和以下のときである。
  - 機能は小さい check で探り、コミット ID では判定しない。
- 目標のファイル（D/bench-targets.json）は、道具から分かれている。状態名と閾値は、ランナーに埋め込まれていない（古い記述が残る点は軽1）。
