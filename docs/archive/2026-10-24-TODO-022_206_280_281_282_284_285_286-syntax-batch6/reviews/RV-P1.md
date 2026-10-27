# RV-P1: 第6弾の判断の記録と実装プランのレビュー

- 日付: 2026-10-24
- 担当: Claude Code のサブエージェント（Opus 5.5）。この報告のほかはファイルを書き換えていない。git の操作もしていない
- 対象: `decisions.md`（D1〜D22）、`plan.md`（69作業）、`implementation-request.md`、`preflight.md`、README の文書の一覧への追記（いずれも P1、未コミット）
- 方法: 文書と、処理系のソース・Lean・`scripts/check.sh`・07-03・07-04 の読み取りだけで行った。ビルド・テスト・`check.sh`（dry-run を含む）・lake・処理系の実行はしていない

## 確かめて正しかった主な事実

- **設計者の決定との対応**: D1〜D14 は README の二つの決定（Q1 の案 I・II・III、Q2 の A1、Q3 の W0401・W0402 の拡張と案 III の新しいコード、Q4、TODO-206 の A'、TODO-280 の C・a・A、TODO-281 の A、TODO-282 の B）と一致する。範囲を勝手に広げた・狭めた箇所は見つからなかった。ただし、D10 は README の「preview で断る」を、preview・初回 apply・check に共通の prepare で断る形に具体化している。旧記録はもともと E0401 で壊れているので、利用者の負担は増えない。
- **型検査の差し込み位置**: `typeck/generate.rs:139–163` の順序は solve → 型の上限 → 到達性 → valid → `consts::warnings` → `finish` → `checked_args::check` である。`consts::warnings` は Prelude・Stdlib のモジュールの本体を飛ばす（consts.rs:1167–1180）。`std_call`（:178）と `standard_argument`（:591）は実在し、`solver.finalize`（solve.rs:476）もある。`TypeckOutput`（mod.rs:141–167）と `CheckResult.program`（pipeline.rs:51–60。deny-warnings のときは `None`）も plan の記述どおりである。
- **診断コード**: `diag/codes.rs` の W04 は W0401〜W0403 だけである。W0404 は使われておらず、`RETIRED` にも入っていない。表の形は「コード・種類・主文・ラベル・[注記]・fix・説明」であり、ラベルに `{…}` を埋め込む例（E0201 など）もある。
- **案 III の定義域**: 実行時に失敗することを実装で確かめた。
  - シフト量は `shift_amount` で失敗する（integer.rs:138、byte.rs:72）。
  - `Process.exit` は `u8::try_from`（process.rs:45）、`Http.listen` は `u16::try_from`（http_server.rs:18）で失敗する。
  - `Http.respond` の status は `200..=599`（http_server.rs:104）、`ClientRequest.timeoutMilliseconds` は `< 1` で失敗する（http_client.rs:156。ネットワークに触る前に検査する）。
  - `Response.status`・`ClientRequest.timeoutMilliseconds` は Integer の欄である（Network/Http.bnt:38–50）。
- **Lean**: `Surface/Syntax.lean:299–430` の Expr の構成子は 53 個で、plan の分類表は 53 個をちょうど一回ずつ覆っている（13＋3＋7＋3＋9＋18）。そのほか次の名前が実在する。
  - `Release.min64`・`max64`
  - `Benitoite.Release.Builtins.Assumptions`（Release/Assumptions.lean:40）
  - `Checked/Range.lean` の `make_ok`（:47）・`erase_make`（:69）・`project_value`（:80）
- **検査の入口**: plan が使う単位名は、すべて `check.sh` の `work_names`・`stage_names` にある。
  - 単位名: formal_build・spec_examples・spec_tally・python_syntax・policy_selftest・reference_examples・skill_docs・skill_generated・tests_related。
  - stage で `--only tests_related` を指定すると `--test` が必須になる（check.sh:447–449）。`lint_default` は `--lib --tests` である（:541）。
  - plan が名指す統合ターゲットは実在する（統合ターゲットは 40 本）。名指しはすべて `tests/*.rs` にある: declarations・checked_args・named_arguments・golden・cli_process・test_command・runtime_builtins・desugar_export・coverage_export・property_library・stdlib_doc_examples・skill_examples・l30_http_server・l32_http_client。
- **相乗り**: 次の記述は実装と一致する。
  - Log の交換: `batch3::export_batch4_log_standard` の出力は `target/formal-batch3/g2`（batch3.rs:85–87、193–198）で、`check_batch3.py` は `--rust-dir`・`--report` を受け取る。g2 の manifest は 10 定義である。
  - `formatRecord` は Log.bnt:158 で非公開の `@builtin` である。
  - derive の版の定数は `GENERATOR_VERSION = '3.1.0-syntax-batch5'`・`INVENTORY_VERSION = 3`・`HASH_VERSION = 3`・`propertyLibraryVersion '2.0.0'`、`prepare` は derive.py:1009 にある。
  - compare の `run.py` は `--tier`・`--state`・`--quick`・`--out`・`--estimate-from` を受け取る。
- **見積もりの算術**: 次の算術は合っている。
  - 69作業の内訳（L29・R8・A21・X5・U3・M1・G1・Z1）と、着手枠の和（51.75〜69時間）。
  - 段ごとの和: Lean 44〜84、処理系と交換 64〜114、相乗り 8〜16、文書 10〜18、全体 3〜6、計 129〜238 時間。
  - study の共通費と三案の追加費の和（Lean 42〜74、処理系 58〜102）とも整合する。
- **文書の規範**: 手元の絶対パス、`docs/todo` へのリンク、敬体は見つからなかった。相対リンクの先はすべて実在する。

## 所見

読めば確定する誤りには「（確定）」、実行や判断を要する点には「（要判断）」を付ける。

### 重大

なし。設計者の決定と食い違う箇所や、決定の範囲を独断で変えた箇所は見つからなかった。

### 中1. X04・X05 の work の行は、`--test` が使われずに終了2になる（確定）

- **場所:** plan.md「検査の割り当て」の work の表、X04（701行）・X05（702行）。
- **問題:**
  - X04 が触るのは `scripts/check-formal.sh`・`scripts/check/test_policy.py`・07-03・07-04・`formal/README.md` だけで、`crates/` のファイルを含まない。自動分類が選ぶのは formal_build と policy_selftest だけで、tests_related を選ばない。そのため check.sh:451–452 の `--test is unused by the selected checks` で終了2になる。
  - X05 は results.md とレビューの記録だけを変えるので、何も選ばれず、同じく終了2になる。
  - 逆に、X01〜X03 が `src/`（A01 の識別表を外へ見せる内部の sink など）に手を入れた場合は、desugar_export・coverage_export の名指しだけでは、前回の named_arguments と同じ見落としが起こりうる。
- **修正案:** X04 は `scripts/check.sh --level work --base B_WORK`（自動。policy_selftest と formal_build）にする。X05 は「文書のみなら対象なし、K1 は別の行」とする。X01〜X03 には、R08 の行と同じく「`src/` を変えたら `--test` を省いて全統合にする」を加える。

### 中2. R04・R06（と S-R2）の検査が skill_examples を落としている（確定。前回の named_arguments と同じ型の漏れ）

- **場所:** plan.md の work の表の R04（672行）・R06（674行）、stage S-R2（722行）。U03（705行）も関係する。
- **問題:**
  - `tests/skill_examples.rs` は `SKILL.md`・`references/idioms.md` などの手で書く文書の例を実行して検査する。あわせて、SKILL.md が 500 行未満であること、参照の一覧が揃っていることも確かめる（:20–94）。
  - R04 は SKILL.md の版の表記を変え、R06 は SKILL.md と idioms.md に実行できる例を加える。ところが両行の `--only reference_examples,skill_docs,skill_generated` には skill_examples が入っていない。skill_examples は work の単位名ではなく、`tests_related --test skill_examples` でしか選べない。
  - S-R2 も skill_examples を名指ししていない。preflight の「R の公開 API は読者を明示した」という記述とも食い違う。
  - U03 は skill_examples を work の外の直接の `cargo test` で確かめる形であり、AGENTS.md「作業末は work を一度」に沿わない。
- **修正案:** R04・R06・U03 の行を `--level work --base B_WORK --only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples` にする（R06 で Log.bnt に doc を加えたなら `--test stdlib_doc_examples` も加える）。S-R2 にも `--test skill_examples` を加える。

### 中3. A12 の触るファイルが検査報告の記述の所在と合わず、Skill の報告の説明が漏れている（確定）

- **場所:** plan.md の作業 A12（470行）、契約表「非実行の検査報告」（53行）、作業 U03（606行）。
- **問題:**
  - checkReport・testCheckReport を記述しているのは 06-01・06-04・02-10（:255）・06-06（:156）であり、A12 が挙げる 02-02（ソースと位置）には記述がない。
  - 手で書く `skill/references/inspection.md` には報告の欄の表がある（:25–35）。SKILL.md:39・50・61 にも受け入れ規則（`complete: true` を要求し、"partial" な報告を空の集合と扱わない）がある。A12 と U03 は、どちらもこれらを直す対象に挙げていない。
  - 新しい欄の `intervalAnalysis.status: partial` は、既存の受け入れ規則の "partial" と語が重なる。LLM が報告全体を不合格と読む誤りを招く。
- **修正案:**
  - A12 の触るファイルを 06-01・06-04・02-10 に改め、06-06 と `skill/references/inspection.md` も見直す対象に加える。
  - U03 では SKILL.md に一文加え、`intervalAnalysis` が受け入れの判定（`complete`）に関わらないことを明記する。
  - status の語は、受け入れ規則と重ならない語（例: `coverage: all/some/none`）にするかを A12 の前に決める。

### 中4. 記憶量の予算は、単位が未定義のままではホストの幅で結果が変わり、Lean との比較もできない（要判断）

- **場所:** decisions.md D16・D20、plan.md の作業 L11・A11、契約表「独立交換」「比較報告」。
- **問題:**
  - 「補助記憶 4／16 MiB」をホストのバイト数（`size_of` や容量）で数えると、32 ビットと 64 ビットのホストで超過する位置が変わる。その結果、警告の有無と `--deny-warnings` の受理がホストによって変わる。これは D20 と AGENTS.md「64 ビットだけを前提にするコードを増やさない」の趣旨に反する。
  - L11 は Lean でも記憶量を予算に含めるとするが、Lean にはバイトがない。X02 で Rust と Lean の結果を比べるとき、記憶量で退いた本体の比較の扱いが決まっていない。
  - 初期値（10万／100万回）の根拠も示されていない。同じ数は既存の E1010 の型の展開の予算（codes.rs:1276「100,000 expanded nodes per type, 1,000,000 per check」）にあり、先例として引ける。
  - D16 は「短い試行で調整」とするが、既存の入力（tests・testdata・examples・文書例）で本体ごとと全体の最大の消費を測る作業がどこにも割り当てられていない。
  - 超過したときに診断を出すのかも、本文で明言していない。E1010 は全体の予算の超過を注記（`declaration_budget`）で知らせる先例であり、これと違う扱いにする理由が要る。
- **修正案:**
  - 記憶量は、ホストに依存しない抽象の単位で数え、Lean と同じ定義にする（例: 環境の項目・由来・番号の対応表の要素数）。あるいは、記憶量の上限を「操作回数より先に当たらない安全のための停止」と定め、比較の対象から外す区分を契約表に加える。
  - A11 または U01 の完了条件に、既存の入力での最大の消費の記録と、上限に当たる入力が 0 件であることの確認を加える。
  - D16 に「超過では警告・注記を出さず、報告の件数だけに残す」と、その理由（`--deny-warnings` の受理を超過で狭めない）を明記する。

### 中5. Range と固定の定義域の意味が、部分評価器の定義か定理の前提かが曖昧であり、停止条件に触れうる（要判断）

- **場所:** decisions.md D18、plan.md の作業 L18・L22〜L24、停止条件（33行）、契約表「評価と中心定理」。
- **問題:**
  - D18 は、表現可能性・端点の順序・標準束縛の同一性・三欄の保存・失敗の優先を、「明示した局所の接続条件」として局所の補題に置くとする。範囲の profile の中心定理がこれらを前提として持つと、C1 の後に中心定理の前提が増える。停止条件の「本計画の正常値・警告の中心定理の前提・結論を変更する必要」に当たるおそれがある。
  - 案 III の Process.exit・Http などの失敗の規則を Release の抽象的な δ から得ようとすると、`Builtins.Assumptions` への追加が要る。
- **修正案:** 次の三点を D18 と L02 に明記する。
  - (a) 標準の Range と固定の定義域の API の振る舞いは、新しい部分評価器の定義（交換で渡す標準束縛の表に付く評価規則）として与える。中心定理の前提にも δ の仮定にもしない。
  - (b) その評価規則は A1 の信頼の範囲であり、VM との比較だけで確かめると 07-04 に書く。
  - (c) L02 で中心定理の言明を確定するとき、profile ごとの拡張がこの形で前提を増やさないことをレビューの観点にする。

  前提として持たせる設計を選ぶ場合は、停止条件との関係を設計者に相談する。

### 中6. 案 III の VM との比較が計画にない（確定）

- **場所:** plan.md の作業 X03（567–568行）、作業 L25、Q2 の決定。
- **問題:**
  - Q2 の A1 は、01-12 との一致を VM との差分テストで確かめることを条件にしている。X03 が具体に挙げるのは、算術・短絡・Range だけで、W0404 の対象（シフト量・Process.exit・Http.listen・Http.respond・Http.request）を比べる条件と入力がない。
  - シフト量、Process.exit(300)、Http.listen の範囲外のポート、timeout 0 は、外部へ触る前に失敗するので比較できる（http_client.rs:156 は接続の前に検査する）。一方 `Http.respond` は、実行中のサーバの Exchange がないと呼べない。
- **修正案:** X03 に案 III の比較用の入力を加え、比べられる API と比べられない API（`Http.respond` は独立の期待値だけで確かめる）を分けて固定する。比べられない分を A1 の限界として 07-04 に書くことを、X03 か U02 の完了条件に加える。

### 中7. W0404 の文言が表の一行として未完であり、欄の場合を覆っていない（要判断）

- **場所:** decisions.md D19、plan.md の作業 A21。
- **問題:**
  - D19 は、主文 `argument `{parameter}` to `{function}` is outside its domain` とラベル `always outside {domain}` だけを決めている。表の行に要る英語の説明（explanation）と、注記の鍵と文（求めた区間・許される区間・局所の解析であること）が未定である。担当が英語の文を作ることになる。
  - W0401・W0402 に加える注記の英語（A07）も同様に未定である。
  - `Http.respond` で範囲外になるのは、引数 `response` の欄 `status` である。主文の `argument `{parameter}`` では、欄を指せない。
  - 実行時の対応は R0701 `argument {index} of `{function}` is out of range` であり、"domain" と "out of range" で語が揃っていない。
  - 日本語の説明「引数を正常に得て呼び出すと、引数が定義域の外になる」は同語反復である。示すべきなのは「呼び出しが実行時に停止する」ことである。
- **修正案:** 計画の段階で次の英語の文を決め、D19 に書く。
  - W0404 の行の全体（主文・ラベル・注記の鍵と文・説明）。
  - 欄の場合の主文（例: `field `status` of argument `response` to `Http.respond` is always out of range`）。
  - W0401・W0402 に加える注記。

  語は R0701 の "out of range" に揃えるのが自然である。

### 中8. 用語: function summary の表記を設計者に選ばせていない。「部分評価器」が既存の術語と重なる（確定）

- **場所:** decisions.md D21、plan.md の作業 U02、study/interval-analysis.md 1.1。
- **問題:**
  - study 1.1 は、案 I を選んだ場合には原語 function summary と候補「関数要約」「関数のサマリ」を示して、設計者に表記を選んでもらうとしていた。AGENTS.md「文章の規範」も同じことを求めている。ところが D21 は計画の判断として原語に決めている。
  - 「部分評価器」は、プログラムの特殊化を指す確立した術語「部分評価（partial evaluation）」と重なる。この計画の意味は「対象の構文に限った評価関係」である。README は「部分の評価器」と書いていた。study 1.1 はこの語を調べておらず、07-04 と用語集に入ると誤解を招く。
- **修正案:**
  - function summary の表記は、候補を添えて設計者の選択を仰ぐ（原語を推すのはよい）。
  - 「部分評価器」は、別の呼び名（例: 「対象の構文の評価関係」「区間解析の参照の評価器」）にするか、用例を調べて用語集に定義を加える。どちらにするかを U02 の前に決める。

### 中9. 作業の大きさが、計画自身の見積もりと 30〜60 分の目安とで大きく食い違う（確定）

- **場所:** plan.md 14行、「残りの作業・検査・測定・レビュー・受け入れ」の表、implementation-request.md 22・28行。
- **問題:** 完了までの見込みを作業数で割ると、一作業は平均約 1.9〜3.4 時間である。目安の 30〜60 分には収まらない。群ごとには次のとおりである。
  - A19〜A21: 12〜24 時間で、一作業 4〜8 時間。
  - A16〜A18: 一作業 3.3〜6 時間。
  - A13〜A15: 一作業 2.7〜5.3 時間。
  - X01〜X05: 一作業 2.4〜4 時間。
  - L01〜L12: 一作業 1.7〜3 時間。

  計画は「収まらないと分かれば分割する」という事後の扱いだけである。そのため、Codex の一回の依頼で終わる大きさになっていない作業が多い。重いと読める作業は、A01（53構成子の訪問表と識別）、A12（報告の欄・CheckResult・三つの章）、L07・L10・L12（中心定理の閉鎖）、L27（新しい交換の読者と実行ファイル）、X03（標識付きソースによる VM 比較）である。
- **修正案:** 少なくとも A19〜A21・A16〜A18・A12・A01・X03・L27 は、計画の段階で枝の ID に分ける（例: 表の作成／照合／診断の接続）。表の目安と見積もりの関係（目安は着手の単位、完了は平均 2〜3 時間）を 14行に明記し、依頼文の「30〜60分」と plan の「45〜60分」もそろえる。

### 中10. Lean の行き詰まりの判断の基準がなく、段の表と作業ごとの依存が食い違う（要判断）

- **場所:** plan.md「段とレビュー」の III の行（26行）・31行、作業 A01 の依存（385行）、decisions.md D15。
- **問題:**
  - 段の表と A01 は「原則 C5 後」としている。一方、作業ごとの依存は A01〜A12 が C0／C1 と L26、A13〜A21 がそれぞれ C2・C3・C4 である。表の「原則 C5 後」は、作業ごとの依存より強い。
  - 処理系へ早く進める条件は「停止」だけである。停止条件は、主定理・公理の変更や A2 が必要になった場合に限られる。証明が単に長引く場合（見込みの2倍を超える、など）に土台へ進んでよいかの基準がない。
  - その結果、通常の経路では Lean の 44〜84 時間を終えるまで処理系に着手できない。A01〜A12 が実際に要るのは C1 と L26 だけである。
- **修正案:** 31行に二点を明記する。(a) 「C1 と L26 が閉じれば A01〜A12 に進める。C2・C3・C4 はそれぞれ A13〜15・A16〜18・A19〜21 の、C5 は X の前提とする」。(b) 「拡張の L が見込みの2倍を超えたら、取りまとめが設計者に、閉じた範囲で処理系へ進むかを尋ねる」。直列で進める判断を保つなら、その理由（レビューの負荷など）を D15 に書く。

### 軽

1. **Q4 の文書の訂正を Lean の後ろに置いている（plan.md A07、431行）。** D7 は振る舞いを変えない 01-04 の訂正なので、R の段（例: R07 と同じ作業か、独立の R）に移すと、Lean が止まっても決定 Q4 を満たせる。
2. **A 作業の「examples 込みの lint」は R01 の取り込みが前提である（677–697行）。** R01 を A01 の依存に加えるか、表の注記にする。
3. **L05 の「div／mod」（110行）。** Lean の整数の除算は `BinOp.intDiv` であり、`.div` は Float・Float32・Decimal 専用である（BuiltinTable.lean:166–169）。Decimal の除数0を誤って対象にしないよう、構成子名で書く。
4. **分類表の「block」（61–62行）。** 土台の「block」と C1 の「全 Block 形」の境界が曖昧である。L06 の bind・shadow が使う `Block.bind`・`lastBind` などを土台に含めることを明記する。
5. **01-04 の規範の強さ（A07・U02）。** 局所の解析の警告は予算で退くので、01-04 では「処理系は警告してよい」なのか「予算内で必ず警告する」なのかを決めて書く（AGENTS.md「仕様としての十分さ」）。
6. **`Http.text`・`html`・`json` の扱い（Network/Http.bnt:90–101）。** これらの補助関数が返す Response は一般の関数の戻り値なので、Unknown になる。利用者がよく書く形なので、U02・U03 の文書で追わない形として明示する。
7. **derive.py:25 のコメント「Bump when rules change」。** D11（事前の拒否では版を上げない）と字面が食い違う。R02 で、拒否の追加は版を上げる規則の変更に当たらない理由をコメントか README に一文書く。
8. **見積もりの内訳。** study と比べると、文書（study は 12〜22 時間、plan は 10〜18 時間）と、設計の固定・接続の記録・全体レビュー・公開候補（study は 16〜32 時間、plan は「全体／候補」3〜6 時間）の幅が小さい。合計は近い。後者は X05・G01・Z01 などに分散したと読めるが、どこへ移したかを一文書く。
9. **implementation-request.md の 20行と 22行。** 「最初に AGENTS.md を読む」が二度ある。一つにまとめる。
10. **README の文書の一覧への追記。** 既存の行はバッククォートのファイル名、追記の行はリンクで、書き方が揃っていない。
11. **decisions.md と plan.md の読みやすさ。** 和文の中に英語の識別子と略記（「番号付け超過は未取得」「全Topだけ」など）が詰まり、読み手の負荷が高い。少なくとも D16・D17・D21 と契約表は、文を分ける。

## 実行しないと分からない点（確かめていない）

- X04・X05 の行が実際に終了2になること（check.sh:446–453 の読み取りによる推論。dry-run で確かめられる）。
- 新しい警告が tests・testdata・examples・文書例に何件出るか、`--deny-warnings` の拒否が何件増えるか（U01）。
- 既存の入力での解析の操作数の最大値と、10万／100万の上限に当たる入力があるか。
- Lean の各区切りの実際の大きさと、中心定理を profile ごとに前提を増やさずに拡張できるか。
- derive の JSON の生成物が、容器の中にレコードを持つ型で実際に E0401 になるか（R02 の最初の手順）。
- `intervalAnalysis` の欄を加えたとき、既存の厳密な読者（Skill の手順、tools/skill-eval の集計など）が壊れないか。

## 観点ごとの判定

| 観点 | 判定 |
|---|---|
| 1 設計者の決定との一致 | 一致。範囲の拡大・縮小はない。用語（中8）だけ、設計者の選択を経ていない |
| 2 粒度と依存 | 依存の循環・矛盾はない。粒度は見積もりと合わない（中9）。段の表と作業の依存の食い違い（中10） |
| 3 Lean の区切り | C0・C1 を先に閉じ、C2〜C4 を独立させる形は妥当。早く進める条件（中10）と、前提の扱い（中5）を明記する |
| 4 W0404 と予算 | 文言（中7）、予算の単位・根拠・超過のふるまい（中4）を補う |
| 5 検査の割り当て | A 作業を全統合にした判断は妥当。X04・X05 の誤り（中1）、R04・R06 の skill_examples の漏れ（中2）。change・release・K1・K2・heap の割り当ては 07-03 と AGENTS.md に合う |
| 6 見積もりと preflight | 算術は合う。preflight の「R の読者を明示」は中2と食い違う。内訳の差（軽8） |
| 7 文書の規範 | 常体。絶対パスとリンクの問題はない。造語の疑い（中8）、読みやすさ（軽11） |
