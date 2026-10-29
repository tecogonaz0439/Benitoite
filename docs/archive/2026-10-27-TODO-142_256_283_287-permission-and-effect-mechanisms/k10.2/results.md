# K10.2: 独立入力・読者・manifest の接続

## 作業と状態

B_WORK と HEAD は `c3ca4504dae42271df7336aca41d0a6d5447d0e3`、ブランチは `m013/k10.2` である。開始は2026-10-29 12:09:55 UTCである。処理系の本番コード・共通の型・Lean のソース・規則・主定理・Assumptions・依存・ツールチェーンは変更していない。変更はテストの書き出し・読者・独立入力・全比較への接続・指定した設計書の対応記述と本ディレクトリの記録である。git の状態を変える操作、本線への書き込み、`private/`・そこを指すスキル・`docs/todo/` の読み取りは行っていない。

独立した範囲の実ソース、拒否理由の比較、旧版の互換、観測、manifest の受け入れ条件を全比較の入口へ接続した。小入力の比較と全比較の完了は区別する。この枝では `lake build`、単一の Lean ファイルの検査、`scripts/check-formal.sh` 全体、short の性能比較は実行していない。全比較とその独立レビュー・受け入れは取りまとめと K10.3 の担当である。

## 独立入力と期待値

比較前に実ソース29件と手書きの期待値を固定した。主な保存先は [初稿と期待値](independent/)、[初稿のSHA-256一覧](independent-sha256.json)、[固定の台本](freeze-inputs.py)、現在の入力は [range-sources](../../../../crates/benitoite/tests/desugar_export/range-sources/expected.json) である。固定台本は処理系を呼ばず、初稿固定後の上書きを拒む。期待する終了・コード・理由・Required の添字と鍵・受理・非 Top の下限・実行結果は手書きであり、Rust/Lean の出力を生成元にしていない。

| 群 | 独立した契約 | 結果と非 Top 件数（候補を除く） |
|---|---|---|
| host-one / host-many | ホスト名の one/many、ポート443、Required の添字と先行順0 | 各1定義受理、各3 |
| ipv4-exact / ipv4-cidr | `192.0.2.7` と `192.0.2.0/24` | 各1定義受理、各3 |
| ipv6-exact / ipv6-cidr | `2001:db8::7` と `2001:db8::/32` | 各1定義受理、各3 |
| port-range | exact host と80..443 | 1定義受理、3 |
| path-tree | `/data/**` の検査 | 1定義受理、3 |
| request-retained | 要求の検査・明示拡大・元の同じ成功値の射影、五欄のレコード操作 | 1定義受理、12 |
| path-widen | 検査した値の明示拡大と元の成功値の直接射影 | 1定義受理、10 |
| shorthand-location | 略記から二原子への展開、元ソース4行目の呼び出しのバイト位置 | 1定義受理、8 |
| request-errors | IPv4射影対象とmappedの InvalidTarget、reqTarget=none の InvalidUrl | 2定義受理、3。VM出力 `InvalidTarget / InvalidUrl / InvalidTarget` |
| old-ip | 旧 Scope の IP/CIDR の checkHost/checkEndpoint | 2定義受理、0。非 Top の証拠へ加えない |
| user-spelling | 同じ綴りの利用者 checkPathIn を標準規則に認定しない | 2定義受理、0、Required の呼び出し0件 |
| all-top | 動的条件から Top を選ぶ旧互換 | 1定義受理、0 |
| 必須判定3入力 | notCovered、unknownSource、要求の widen の未知を先に報告 | E0519。共通の手書きの鍵・添字・理由へそれぞれ照合 |
| 効果上限3入力 | notCovered、atomicCoverOnly、Top の unknownSource | E0519 と Lean の型付け拒否を別に比較 |
| 既知不良8入力 | 旧/新の各 E0459〜E0462 | コード付き除外。四理由の直接比較へ加えない |

実ソースの成功は15群18定義、範囲の12群は合計57、Top の互換は3群である。プログラム網羅性は非空3項目と、空の群を区別した。空の群の `coverageProgramDiff` の終了1を成功した非空比較と数えず、独立した `coverageDiff` の1件の成功も別に要求する。[実ソースの全入力・型表・定義のmanifest](range-source-comparison/source-manifest.json) と [集計](range-source-comparison/summary.json) に、成功・拒否・コード付き除外・全 Top・非 Top、型表の全項目と本体の定義の鍵を保存した。

R40.3 の26入力は報告側の部分集合として [入力と期待値](independent/report-expected.json) をそのまま保持し、同じ内容をテストの入力へ写した。通常 check/test と doc の正しい入口を計50コマンド実行し、終了・契約・コード・理由を照合した。[報告側の集計](range-source-comparison/report-subset/summary.json) は26入力・50成功である。doc の check/error の空の Effects は純粋な契約を意味しない。

初稿の実ソース3件を訂正した。widen の結果は局所の由来を持たないため、射影は元の同じ成功値へ行う形へ直した2件と、Console の公開効果名を `Console.Write` とした1件である。[入力の訂正と理由](input-fixes.json) に前後の SHA-256 を残した。[期待値の整合](expectation-integrity.json) は、29件の期待値について `sha256` 以外の値の変更0件を確認する。初稿を後の成功入力へ上書きしていない。

既存の手書き交換は [独立交換の固定入力](independent-exchange/) に残した。正式な期待値は B_WORK に既に存在した `test_range_exchange.py` の手書きの PATH_CASES・BUDGET_CASES・各検査であり、原文を expected-source.py に保存した。主担当が別に転記した未使用の補助初稿には fn:1/fn:2 の取り違えがあった。補助初稿を変更せず `supplemental-draft-not-used.json` に保持し、成功証拠には使っていない。実行した正式な期待値は最初から正しく、比較による変更はない。

## 拒否理由の対応

必須判定の三拒否では、Rust の実ソースの診断と、同じ形の手書き交換の Lean の報告を、それぞれ同じ手書きの鍵・添字・理由と照合する。同一入力の直接比較は予算の2件である。対応は README の DET-05 の比較方法に従う。型付けの失敗を同じ cover 理由へ変換せず、予期しない終了・別の型エラーを無視する catch-all を置いていない。[手書きの拒否入力と期待値](independent-rejections/)、[対応の詳細](independent-rejections/results.md)、[各入口の報告](range-source-comparison/rejections/summary.json) を参照する。

| 入力 | Rust | Lean | 照合の単位 |
|---|---|---|---|
| required-not-covered | E0519 notCovered、Required=`/data/**` | result.cover notCovered | `.sample` と fn:901 を手で対応付け、共通の期待（先行順0・添字・理由）へそれぞれ照合 |
| required-unknown | E0519 unknownSource、Required=Top | result.cover unknownSource | 手書きの宣言対応と先行順0へそれぞれ照合 |
| request-widen-rejected | E0519 unknownSource、Required=Top | result.cover unknownSource | 手書きの宣言対応と先行順0へそれぞれ照合。許容失敗より Required の未知を先に分類 |
| last-run-exceeded | budgetExceeded、Required=Top | result.cover budgetExceeded | 実ソースの同じ定義 fn:43、先行順6 |
| inner-exceeded-outer-recovered | 内側 unknownSource、外側 `/outer/**` を保持 | 内側 result.cover unknownSource | 同じ定義 fn:43、内側19・外側27 |
| effect-not-covered | E0519 notCovered | typing: effect exceeds the allowed effect | 拒否の一致。同じ cover 理由と数えない |
| effect-atomic | E0519 atomicCoverOnly | typing: effect exceeds the allowed effect | 拒否の一致。意味は独立の和の入力で照合 |
| effect-top | E0519 unknownSource | typing: effect exceeds the allowed effect | 非超過の入力。Lean の原子の理由の観測値は null と記録し、typing から捏造しない |
| numbering-stop | raw全6規則 Top、番号なし、budgetExceeded | 対応する番号付け上限なし | Rust独自差。途中の番号を使わず、直接一致の件数へ加えない |

`acceptRange` の到達する三理由と、`acceptAtom` の四理由を区別した。atomicCoverOnly の意味は endpoint の0..9を0..4/5..9の和で受理しない1件と、それぞれ一原子に覆われる受理2件で別に照合した。各拒否の受理する対も含め、独立拒否群は15群24定義、非 Top 合計54、通常の必須判定の独立期待値との照合3・効果上限比較3・独立の和の拒否1・受理8である。`surfaceCheckAll` の拒否文と `nonTopRanges`、`desugarDiff` の全定義と同件数も照合した。

Top の効果原子に対する `atomFailure` は、由来が exceeded なら budgetExceeded を返しうる。今回の effect-top は非超過で、Rust は unknownSource である。Lean の入口は typing のみを返すので、原子の理由を実測したとは書かない。予算の由来と Required.ofIndex の選択は、別の予算2入力の同じ鍵の比較で確認した。

予算の入力・手書き期待値は [independent-budget](independent-budget/) と [詳細](budget.md)、正式な出力は [budget-output](budget-output/range-budget/)、最終比較は [budget-compare-confirmed](budget-compare-confirmed/summary.json) に残した。二つの Lean 比較の非 Top は候補を除いて5・16、全定義1件ずつ、対象外と除外0である。補助期待 `firstStopPreorder=6` は実測4と不一致1件だった。これは後に拒否される射影位置6と、その原因の Ok 移行の停止位置4の取り違えである。固定した値は変更せず、全不一致を summary に残し、Required の主契約の一致と区別した。これは K10.2 初回の扱いである。K10.2b では初稿6を残し、定義に基づく訂正値4・理由・判断者・日付を別欄へ加え、訂正値との一致を必須にした（末尾の対応記録）。

## 読者と全比較への接続

変更と局所検査は [読者の記録](readers.md) にまとめた。batch2 の check_rust、batch3 の rust_inputs、batch5 の check_rust を現行15/7へ追随させた。batch3 の12→4・13→5・14→6の対応と15→7を分岐で検査し、旧版の独立交換・構築器の再生成要求・書式付き補間の旧版拒否を維持する。区間の手書き Surface14 と、range交換の版14に範囲の欄を置く意図した拒否入力も変更していない。

`check_batch3.py` の8経路は b3/blocks/g2/g3/k3/k4/m1/t3、定義数は52/10/11/8/5/7/31/9で全て通った。k3 の空のプログラム網羅性は終了1・matched0を明示して、非空の独立 coverage と他入口の成功から区別した。Rust の側の manifest に存在しなかった k3/k4 の件数も加えた。

全比較の入口は既存六入口・intervalDiff・四つの区間書き出し・独立交換・profile/VM を保ち、`test_range_exchange.py`、実ソースと拒否の比較、予算の比較、既知差の名指しを加えた。`formal_interval.py` の最終manifestは独立した expected.json の群・定義数・範囲群・Top互換群、報告側26入力50コマンド、期待値のSHA-256、予算と既知除外の summary を照合して保存する。五つの欠落・Top退行の負例も意図した理由で拒否した。

候補の収集は既存の `candidate_atoms` が、署名の固定の原子と呼び出しの範囲で具体化した原子を `candidates` にそろえる。`rkinds` と添字・種類を検査し、rvar は corpus へ移さない。`desugarDiff` 自体は型表を引数に取らず、corpus 全体の `collectAtoms` の一覧を候補にも使う。脱糖は項の範囲の列を保存し、新しい原子を作らない。検査器側の `CheckInput.atomsFor` は型表と具体化した署名の原子を含めて `instClosed` を満たし、Prepared.writeEffNames_complete の経路へ渡す。`candidates` は Lean の必須欄ではなく、脱糖結果に影響しない。この区別を保ち、named-declarations の5定義を候補なし・非 Top17で比較した。候補だけ非 Top1、本体全 Top の同じ入力は旧条件なら通るが、新しい条件は拒否した。局所の F-local の候補込み18とは区別する。

## 既知の差、観測と互換層

[観測と互換層](observations.md)、[既知差の具体入力と結果](known-differences/results.md) に対象・根拠・限界を記録した。

- k3 は R10.5 の宣言同一性の対応表を元TSVと照合し、現在の比較対象5関数と補充型27件を対応付けた。現在までの39宣言の消失・3宣言の追加は、単なる番号差と別に記録した。生のハッシュだけや全整数の一律の差し引きは使っていない。
- E0711 は `/data/**` のクラス宣言に `/data/a` の実装宣言を与える入力を名指しし、Rust の構造上の包含の追加制約を保った。Lean の checkMethods の被覆へ合わせて広げていない。
- U+0000 は整数と読める接尾辞を持つ文字列の抽象表現の精度差に限定した。直接の不良 host 条件は E0459、局所変数へ保存した対照は受理であり、同じ受理・理由の一致へ算入しない。通常整数、通常文字列、要求レコード全体、検査済み実行値の unsupported へ除外を広げていない。
- 六 File の保持 path と sendIn の保持 endpoint 一つを、B-Lean で検査済みの encodeObservation/observationAllowed の独立例と、実ファイル・ループバックの3試験で対応付けた。外側2.480/3.893/1.876秒、全て終了0である。DNS/TLS の OS の副次通信を含めず、旧 Top の完全な外部観測を新たに証明したとはしていない。
- 旧 Scope は既存112入力（host64/path24/endpoint24）の成功31・失敗81と、成功値の正規形の保存・再利用を Direct/Request で確認した。1試験成功、終了0、外側0.7216415秒である。
- AcceptInput.noRules・旧版 reader・fromEffNames の既定候補の使用箇所を棚卸しした。必要な旧像の互換と補題を残し、ModelTargets の旧 File.readText を全Rust操作表の完全な対応と数えない。

検査済み値の整形式性・同じ要求の保持は実装と独立境界の照合であり、一般の型付けだけから導く保証へ広げていない。07-03・07-04・01-12の対応記述を現状へそろえ、作業IDを設計書へ書いていない。

## 局所比較の実行と結果

正確なコマンド・開始終了・外側時間・補助RSSは各 JSON、生ログは同名の log にある。計時は `/usr/bin/time -p`、補助RSSは macOS の getrusage(RUSAGE_CHILDREN) の bytes である。一つの子の最大値であり、並行使用の総和ではない。

| 検査 | 入力・出力と件数 | 終了 | 外側時間 |
|---|---|---:|---:|
| F-local 書き出し | [f-local](f-local/)、通常ソース5定義、corpus15/sidecar7 | 0 | 0.719327792秒 |
| F-local desugarDiff | 5一致・除外/対象外/不一致0、非 Top18（候補を含む） | 0 | 0.02469325秒 |
| F-local builtinCheck | 1入力70 prim変換、96 summary比較・不一致0 | 0 | 0.025365583秒 |
| F-local surfaceCheckAll | 5一致・他分類0、非 Top18（候補を含む） | 0 | 0.027655125秒 |
| F-local surfaceCheck | result.ok=true、5定義 | 0 | 0.0292855秒 |
| F-range 最終 | [f-range-final](f-range-final/)、9検査。独立14定義の脱糖一致、表層は9受理/5指定拒否、全体36・群別30/6 | 0 | 1.706651083秒 |
| 独立実ソース・拒否・報告側・manifest | [全報告](range-source-comparison/)、上記の15群18定義・拒否6・除外8・報告26入力50コマンド | 0 | 9.570250167秒 |
| 予算2実ソース3ケース | [最終報告](budget-compare-confirmed/summary.json)。番号停止1はRust独自、Lean比較2 | 0（主契約） | 0.250233875秒。補助期待不一致1を別記 |
| 既知差3入力 | [正式報告](known-differences/cli-main/summary.json)。E0711/E0459の拒否と局所保存の受理 | 0 | 0.323964583秒 |
| F-interval/VM identity書き出し | [詳細](interval-local.md)・[要約](f-interval-vm/summary.json)・[生出力の一覧](LARGE-FILES.md) | 0 | 12.22秒 |
| F-interval/VM VM書き出し | 算術80/Range96/shift108操作 | 0 | 3.36秒 |
| F-interval/VM CLIビルド | 既存targetの実CLI | 0 | 21.62秒 |
| F-interval/VM 局所比較（修正後） | 237呼出、7群584本体、五profile、算術39/Range37/shift108実行（比較46/独立のみ62）、深さ除外0 | 0 | 38.16秒 |

F-range は最初の8検査の終了0・1.314273541秒も [初回](f-range.json) に保持する。群ごとの両入口の報告の条件と、interval の入力・報告の保存を加えたため、古くなったこの局所比較だけを再実行した。固定入力・正式な手書きの期待値の内容は変えていない。

F-local の4比較の補助RSSは40,058,880 / 40,484,864 / 42,270,720 / 41,844,736 bytes、F-range最終46,399,488 bytes、実ソース全比較45,875,200 bytesである。F-interval/VM の最大は CLIビルド3,830,333,440 bytes = 3,652.890625 MiB = 3.567 GiBで、局所比較自体は97,386,496 bytesである。個別値と単位を各 JSON に残した。

## 初回の失敗と修正

| 対象 | 初回の失敗 | 修正と扱い |
|---|---|---|
| 新しいRustテストのコンパイル | 作成途中の range_budget の宣言先置きと、test helperの非公開のrange呼び出しで101 | 実体と宣言をそろえ、既存の公開 index 書き出しを再利用。本番の公開範囲を増やさない |
| 実ソース2入力の射影 | widen結果の由来を認定できずE0519 | 元の同じ成功値から射影する入力へ訂正。期待値変更0、初稿保持 |
| 実ソース request-errors | Consoleモジュールを効果名にしてE0315 | 入力の宣言をConsole.Writeへ訂正。期待値変更0 |
| Requiredの観測JSON | IPv4のbitsが十進文字列のまま | 観測にも既存ExchangeJsonを使い、交換形式と同じ整数へ書く。規則を変更しない |
| 親の集計接続 | 返値checkedを仮定したKeyError | 実際のsourceRejections欄へ接続 |
| 報告側doc入力 | 通常check入口でmainを要求して失敗 | 元の固定入力の契約どおりtest --doc --checkで照合。期待を変更しない |
| F-interval/VM | Surface15のprimName標識を固定辞書の完全一致が認定せず終了1 | ranges:[]を現行読者へ追随。比較だけ再実行 |
| batch3の読者 | 15未受理で8経路停止 | 15/7へ追随し全8経路成功 |
| batch3の件数ガード | coverageDiffにoutOfScopeがあると仮定し8経路KeyError | プログラム網羅性だけの欄と区別。全8経路再成功 |
| 予算の補助期待 | firstStopPreorderの期待6に実測4 | 値は変更せず全不一致を記録し、Requiredの主契約の一致と分離 |
| 予算の入口 | builtinCheckの引数不足で終了2 | 引数を既存CLIの契約へそろえ再成功 |
| 既知差のCLI準備 | option位置/拒否の終了値/main欠落による追加E0414 | 初稿と全ログを保存。正しい入口とmainを持つ入力を比較前に固定し直した。コードの期待不変 |

各初回のログは削除していない。失敗した初稿の補助期待を後の成功証拠へ置き換えていない。

## B-Lean の引用と作業末の検査

取りまとめの [b-lean.log](b-lean.log) を formal_build の結果として引用する。HEAD/B_WORK はともに上記の完全ID、formalで `/usr/bin/time -p lake build`、573ジョブ・終了0・real0.39秒である。全て既存生成物を使ったことも元ログのとおりで、新しい実ビルドと説明しない。最大常駐量は元ログにないので取得不能である。

[Lean入力と道具の一覧](b-lean-inputs-and-tools.json) に、追跡する .lean と lakefile/manifest/toolchain の331入力、交換の7実行ファイル、版・ハッシュ・環境を保存した。Lean入力は B_WORK から差分0、-M12288を維持する。変更したformal/testsの読者とRustのテストは lake build の入力を変えないため、この結果を引用できる。引用の判断者はK10.2主担当、日付は2026-10-29である。Rust/Lean全比較の結果としては引用しない。

指定の [自動選択のdry-run](work-dry-run.log) は、Python読者の変更でformal_build、check台本の変更でpolicy_selftestを選んだ。01-12の対応記述の変更でspec_examplesも選んだ。READMEのK10.1/K10.2の判断に従いformal_buildだけをB-Leanから引用し、[名指しのdry-run](work-selected-dry-run.log) で残りを確認した。通常のRust全lib・指定5統合・clippy・fmtを一つの入口へ任せ、独立して重ねていない。共通の型を変えていないのでW-Rへ広げていない。ヒープの不変条件・値の保持・VM/最適化/枠を変えておらずH/release_stack/shortは対象外である。

W-Kの確定値、全routingの結果、全比較の見込みと最終の状態は後掲に追記する。

### 全 corpus の routing と K10.3 の見込み

`check_named.py::check_routing` を全 corpus へ実行した。[書き出しの計時](readers-routing-export.json) は終了0・real1346.50秒（22.44分）、1792入力（golden792/random1000）、1373書き出し・診断付き除外419・対象外0である。補助最大RSSは401,522,688 bytes = 382.921875 MiBであった。生成した1000実ソースは [zip](LARGE-FILES.md)、大きい生出力1009ファイル約2.68 GBは [大きさとSHA-256](readers-routing-artifacts.json) に保存した。target内の生出力だけを恒久の根拠にしていない。

routing の初回は [終了1・real14.59秒](readers-routing-run-first-failure.json) だった。差は NoMainFile の3入力に埋め込まれた元リポジトリの根だけだった。期待値を現在の出力へ書き換えず、除外の種類と対象 entry の完全なリポジトリ相対位置を厳密に保つ読者の正規化を加えた。basename だけでは受理せず、他の除外はそのまま比較する。除外種類・相対位置・scopeを変えた3負例も拒否した。[最終](readers-routing-run.json) は終了0・real14.37秒、全1792入力の識別子・除外・scope・coverageが一致した。[一致の集計](readers-routing-agreement.json) を保存した。最終の補助最大RSSは8,808,923,136 bytes = 8.204 GiBであり、小入力の比較のRSSより大きい。

K10.3 の `scripts/check-formal.sh` 全体は **30〜45分** と見積もる。既に実測した全 corpus の書き出し22.44分、局所の F-local/F-range と追加の独立源比較約10秒、区間/VM一組75.36秒、routing約15秒を根拠とする。六入口の全件比較・残る区間3群・全入力の個別表層検査・最終manifestの作成は新版全体では未実測であり、残りの幅に含めた。前の版の約16分と同じ見込みは使わない。今回の routing のピーク約8.20 GiBも取りまとめへ渡す。これは性能比較ではなく検査の待ち時間の見積もりである。

| 残る手順 | 担当・見込み |
|---|---|
| 新しい全接続の独立レビュー、必要な修正と古くなった局所検査の再実行 | 取りまとめ。レビュー10〜20分、修正は指摘次第で不明 |
| K10.3 全比較の実行 | 取りまとめが新版の見込みを示して了承を得てから起動。全体30〜45分、能動作業は計画2〜4.5時間 |
| 全比較の件数・非Top・拒否・manifest・引用条件の照合と段全体の独立レビュー | K10.3/取りまとめ。レビュー20〜40分、修正は不明 |
| 受け入れ | 設計者・取りまとめ、時期不明 |

## 停止条件、片付けと申し送り

Lean の規則・交換の共通の型・主定理・Assumptions・保証を変える必要は見つからず、停止条件への該当はない。共通依頼文の勧告照合と設計者の「組み込まない」を引き継ぎ、依存や固定版を更新していない。上端の2倍の10時間にも達していない。

新しい CARGO_TARGET_DIR、target外の一時ビルド、基準版の展開は作っていない。k3採取の実行ファイルは既存target内へ作り、採取後に削除した。一時のPython交換入力は各台本が清掃し、必要な入力・報告は本ディレクトリへ保存した。区間の反復する大きい中間JSON69件53,303,746 bytesは各ハッシュを確認して圧縮保管し、展開した複写を削除した。[圧縮物の点検](archive-redaction.json) で、生成ソース1000件と中間JSON69件の中にも手元の絶対パスがないことを確認した。ソースのアーカイブや git bundle の新設・削除は行っていない。

K10.3 は既存六入口・intervalDiff・四つの区間書き出し・独立交換・profile/VMを全て実行し、今回追加した主源/拒否/予算/既知差の summary と全関係定義を最終manifestへ載せる。初稿の補助期待との不一致を保持し、訂正値との一致を要求する。同じ理由を出さない typing の報告差も隠さない。初期の同じ ε、BA末尾の整形式性、Top定数のshapeAt、旧像の同値と要求保持の形式化の限界を保つ。全比較後の状態を V10 が引用する際は07-03の全欄をそろえる。本枝の局所成功を全比較へ読み替えない。

## W-K の確定値と最後の調整

実行した作業末の入口は次のとおりである。`run-command.py` がこのコマンドを `/usr/bin/time -p` で包み、check.sh自身の終了を直接受け取った。名指しはREADMEのB-Lean引用の扱いに従い、01-12から自動選択されたspec_examplesも落としていない。

```sh
scripts/check.sh --level work \
  --base c3ca4504dae42271df7336aca41d0a6d5447d0e3 \
  --test desugar_export --test coverage_export --test golden \
  --test verify --test random_programs \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,python_syntax,policy_selftest
```

[初回の計時](work-check.json)・[生ログ](work-check.log)・[直接の終了](work-check.exit) のとおり、check.sh自身は **終了1、外側319.103203167秒、time-p real319.09秒・user1128.33秒・sys38.14秒** だった。失敗は最後のpolicy_selftestの1件だけで、Rustの失敗ではない。

| 対象 | 成功 | 失敗 | 既存の無視 | ターゲット内の時間 |
|---|---:|---:|---:|---:|
| 既定lib全件 | 1,392 | 0 | 22 | 77.53秒 |
| coverage_export | 3 | 0 | 1 | 1.10秒 |
| desugar_export | 48 | 0 | 1 | 12.29秒 |
| golden | 2 | 0 | 0 | 58.32秒 |
| random_programs | 7 | 0 | 0 | 47.66秒 |
| verify | 3 | 0 | 0 | 68.24秒 |
| spec_examples | 7 | 0 | 0 | 3.44秒 |
| Rust合計 | **1,462** | **0** | **24** | 外側時間とは別 |
| policy_selftest初回 | 29 | 1 | 0 | 18.582秒 |
| policy_selftest修正後 | 30 | 0 | 0 | 26.522秒 |

fmt、lint_default、source_rules、skill_generated、spec_tally、python_syntax は成功した。仕様の未参照節の表示は既定の動作で終了0、初回リリースの未記入はnoneである。random_programs全体は47.66秒で、random_differentialの300件・60秒予算のアサートも成功した。件数・予算・種の上書きと単独の再実行はない。verifyの60秒超の通知は成功した一件であり、乱数の予算超過とは別である。

初回失敗は、全比較のシェルのbatch3呼び出しを4回から8回へ増やしたことと、既存policyの4回の入口契約の不一致だった。範囲外のtest_policy.pyを変えず、シェルの既存b3/blocks/g2/g3の4入口を保ち、残るk3/k4/m1/t3は最終の `check_named.py` から同じ `check_batch3.check` を呼ぶ形へ直した。[局所再検査](final-batch3-reader.json) は5/7/31/9定義の各六入口で終了0・外側1.562258541秒であった。全8群を減らしてpolicyだけを通したものではない。

古くなったpolicyだけを次で再実行し、[終了0・外側26.570396292秒](work-policy-retry.json)（time-p real26.56・user15.27・sys8.49秒）、30件成功を確認した。部分選択の終了0をwork全体の一括終了0とは呼ばない。初回の他九項目の成功と、修正後のpolicyの成功と追加4群の局所成功をそろえた判定である。

```sh
scripts/check.sh --level work \
  --base c3ca4504dae42271df7336aca41d0a6d5447d0e3 \
  --only policy_selftest
```

初回の補助最大RSSは **2,372,452,352 bytes = 2,262.546875 MiB = 2.2095184326171875 GiB**、policy再検査は24,477,696 bytes、追加4群は47,120,384 bytesである。いずれもgetrusageの子プロセス一つの最大値であり、同時使用の総和ではない。

W-K後の実質変更は上記のPython読者とシェルの2件だけで、Rust・入力・期待値・表の生成元/生成物・Lean・設定・固定版は変わらない。初回状態の2ファイルは操作記録から実行後に再構成したものであり、事前採取と偽らず [差分とハッシュ](work-followup-state.json) にその旨を明記した。追加関数は既存の書き出しや、局所照合で使う他の関数を変えない。Rustの九項目の成功とF-local/F-range/区間/VM/routingは古くならないため再実行していない。構文は [直接のAST検査](final-python-direct.json)、新しい呼び出しは上の実交換で確認した。

## 作成時の関門と最終状態

公開のtest-auditの作成時の関門に従った。守る契約は、実pipelineからの範囲付きの型/項/Requiredと、交換の独立した受理・拒否、全関係定義と群ごとの非Top、既存の入口の失敗伝播である。現実的な退行として、15/7の読者の未追随、型表だけの一致、本体の全Top退行、拒否入力の欠落、typingをcoverへ変換する誤報、番号停止の接頭辞の流用を失敗にする。既存の短い成功smokeとLeanだけの手書き交換では、通常の実ソースを経たこの接続を確かめられないため、同じ持ち主の書き出しと表形式の入力を拡張した。値の保持とIOの実対象は既存の公開境界の試験を再利用し、似た試験を重複追加していない。本番の差し込み口・公開範囲・フラグは増やしていない。

本番コードの追加/削除は0/0行である。テスト・読者・入力の行数は [集計](line-counts.json) に、本番と分けて記録した。[最終ソース状態](final-source-state.json) に基準・HEAD・差分一覧とSHA-256・未追跡の入力を含む86ファイルのSHA-256を、[保存物一覧](LARGE-FILES.md) に入力・期待値・ログ・報告と圧縮物の大きさ・SHA-256を保存した。記録の相対リンクと空白、許可した編集範囲、Lean入力の差分0、記録内の絶対パスなしを最後に確認する。

## 時間

主担当の開始は2026-10-29 12:09:55 UTC、最終確認の時計は2026-10-29 12:51:38 UTCで、外側の所要は2503.645秒（約41.7分）である。主担当の能動時間は約30〜35分の概算で、読解・実装・文書と検査中の照合を含む。作業末の検査待ちは初回319.103秒とpolicy再検査26.570秒、全routing用の書き出し待ちは分担で1346.50秒であり、互いに重なるため単純に加算しない。分担の能動時間は各記録に残した概算で、厳密な合算値は未採取である。計画の2〜5時間と停止条件10時間を超えていない。独立レビューと設計者の受け入れはこの時間に含まない。

## K10.2b: RV-K10.2 への対応（2026-10-29）

B_WORK と HEAD は引き続き `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。担当の開始は2026-10-29 13:06:36 UTC。レビュー本文と `rv-probes/` は変更していない。以下は K10.2 の初回の状態と区別した追加の記録である。

| 指摘 | 対応と判定 |
|---|---|
| 中1 | 07-04 と本記録の三拒否を独立期待との照合へ限定した。契約だけ変えた三つの受理ソースを `range-sources/contract-counterparts/` へ置き、Rust の実 pipeline から書き出した。既存の `test_range_rejections.py` が変更箇所とソースのハッシュを検査し、手書き交換との型・本体の全欄の一致を要求する。[対応の報告](k10.2b-source-comparison/rejections/summary.json) の `contractCounterparts` は3件成功である。追加は1時間以内に完了した |
| 軽1 | 拒否・予算・既知差の三台本、および K10.2 に新しく書いた検査台本の `assert` を `require` へ置換した。レビューアの台本と、元からある独立交換の原文の写しは保持した。`PYTHONOPTIMIZE=1` の実比較と、最適化後の拒否の負例が成功した |
| 軽2 | `range-budget/expected.json` は初稿の `firstStopPreorder: 6` を保持し、訂正値4・定義上の理由・判断者・日付を `firstStopPreorderCorrection` へ追加した。Rust の書き出し、予算の読者、最終 manifest の読者が訂正値との一致を要求する。内側の13を12へずらす負例と、不一致を追加して件数だけ合わせる負例も拒否した |
| 軽3 | `range-sources/expected.json` に12範囲群の完全件数と、old-ip/user-spelling の0を追加した。日付・理由・判断者と数え方は `nonTopRangesAddition` に記録した。初稿は [保存した期待値](k10.2b-before/crates/benitoite/tests/desugar_export/range-sources/expected.json) と `independent/expected.json` に残した。元の下限も消していない。実比較と最終 manifest の両方で完全一致を要求する |
| 軽4 | `effect-top-exceeded.bnt` を追加した。513個の検査結果で本体の保持件数上限512を超え、番号付けは完了し、最後の Run が `Body/Items` で停止したことを、契約だけTopにした同じ本体から確認した。Rust は E0519/unknownSource、Lean の手書き交換（body.operations=0）は型付けの拒否を返した。原子の理由の観測は null、定義上の `atomFailure` の分類は budgetExceeded と分けて記録した |
| 軽6 | 07-04 の余分な空行を除き、`test_range_known_differences.py` を明示した。01-12 の重複した比較の説明は 07-04 への参照だけにした |
| 軽7 | 生の比較出力と200 KiB超のファイルを `target/k10.2-raw/` の同じ相対位置へ移した。[大きさとハッシュ](LARGE-FILES.md) に一覧を残す。exchange/routing の両 manifest は完全なリポジトリ相対位置へ正規化し、読者は手元の異なる根からの絶対位置とその相対位置を照合できる。全1792入力の routing も再成功した |
| 軽8 | `path-widen-projection-rejected.bnt` に初稿の widen 結果を射影する形を追加した。手書きの期待 E0519/unknownSource と Required=Top に一致した。Rust の実ソースの拒否として記録し、同一入力の Lean 比較へ加えていない |

三拒否の構造の照合では、固定の番号を推測でずらさず、同じ組み込み表の `valKinds` と `dataDecls.typeName` で宣言を対応付ける。独立交換が抽象型として置く ScopeError と、実ソースの標準 ScopeError の宣言は同一性で対応させる。末尾の `lastBind` は Unit を返す `bind` へ展開する。範囲の契約だけを印に置き換え、その個数、引数位置、リテラル、表層とコアの構造、範囲以外の型の欄は保持して比較する。定義名・所属パッケージ・網羅性に使う環境の一覧は、二つの入力で異なるメタデータとして比較対象から外す。この照合は型と本体についてのもので、交換全体のバイト一致ではない。パターンのリテラルを `/backup/**` へ変える負例は拒否した。同一入力を直接渡した三拒否と説明していない。

非 Top の件数は出力を見て転記せず、次の形で数えた。候補の一覧と `scopeAcceptance` のパターン・ホストは含めない。

| ソースの形 | 手で数えた内訳 | 期待 |
|---|---|---:|
| host-one/many、v4/v6 exact/CIDR、port-range、path-tree | 検査の bind の型1、表層の呼び出しの範囲1、コアの呼び出しの範囲1 | 各3 |
| request-retained | 検査3、widen の型1と二つの呼び出しの範囲2ずつで5、元の成功値の射影2回の表層・コアで4 | 12 |
| path-widen | 検査3、widen 5、射影の表層・コアで2 | 10 |
| shorthand-location | 表層・コアの引数型2、両 header に二効果原子ずつで4、呼び出しの範囲2 | 8 |
| request-errors | classify の検査3、main は範囲なし | 3 |
| old-ip / user-spelling / all-top | 範囲付きの型・原子・呼び出しがない | 各0 |

[負例の台本](k10.2b-check-guards.py) と [判定](k10.2b-guards-summary.json) は、完全件数12を1へ落とす部分退行、Top互換の0を1へ変える退行、停止位置と不一致集合のずれ、契約以外の式の変化、期待した理由の欠落、誤った相対位置を拒否した。`require` の関数自体も optimize=2 で実行し、False を拒否した。元のガードは最適化で消え、補助不一致の件数だけの比較は追加の不一致を通す構造だったが、修正後は両方の実経路で拒否する。

追加の初回失敗は保存した。超過の初稿は16385個の Unit 文を並べたため E0208（深さ1000）に先に拒否された。単なる Unit は由来の費用も持たないため、513個の検査結果により保持件数を超える入力へ訂正した。[初稿](k10.2b-exceeded-first-draft.bnt)・[当時の期待](k10.2b-exceeded-first-expected.json)・[診断](k10.2b-export-exceeded-detail.log) を保持する。Lean の独立入力で上限の辞書を共有していたため、初回は他の群も超過と分類された。上限を変更する一入力だけ辞書を複写して修正し、[初回ログ](k10.2b-rejections-first.log) と後の成功を分けて残した。

### K10.2b の検査と K10.3 への申し送り

F-range は9検査、実ソースは受理15群18定義・拒否8・除外8、範囲の12群は合計57・Top互換は3群、報告側は26入力50コマンドで成功した。独立拒否交換は16群26定義・非 Top56、必須判定の手書き期待との照合3・効果上限の拒否の照合4・和の拒否1・受理8である。追加した widen 射影の拒否は Rust 独自の記録1件であり、この16群へ混ぜない。予算は番号付け停止1・同一入力の直接比較2、補助の停止位置は null/4/13 に一致した。初稿との不一致は last-run-exceeded の6→4だけを要求する。具体的なコマンドと時間は `k10.2b-*.json`、対応するログと直接の終了は `.log`・`.exit` にある。局所検査は `PYTHONOPTIMIZE=1` で行った。

`formal_build` は [B-Lean](b-lean.log) と [入力・道具の一覧](b-lean-inputs-and-tools.json) を再引用する。[再照合](k10.2b-b-lean-reuse.json) で、331個のLean等の入力と7個の実行ファイル、計338個のハッシュ、およびB-Leanログのハッシュの一致を確認した。今回も Lean のソースとビルドの入力・設定・固定版に変更はない。判断者はK10.2b担当、日付2026-10-29である。Rust と Python の局所検査を Lean の新しいビルドや全比較の成功とは説明しない。本番の変更は0行である。追加した検査は公開 pipeline・既存の交換・最終manifestの境界を使い、同じ持ち主の表を拡張した。守る契約と退行は上表のとおりで、本番の差し込み口は増やしていない。

K10.3 への申し送りは次のとおりである。

- **軽5のpolicy**: 新しい4つの比較の呼び出しと `check_named.py::check_remaining_batch3` の4群の入口を `scripts/check/test_policy.py` へ追加する。このファイルは今回の編集範囲外である。現在も失敗はシェルの `set -e` と読者の例外で伝播する。
- **中1の残り**: 三拒否は手書き期待への個別照合と、契約を変えた受理ソースとの構造の照合まで完了した。拒否した実ソースそのものを Lean へ渡す直接比較ではない。この限界を全比較の件数と設計書で保つ。同一入力の直接比較は予算2件である。追加検査の実装の未完はない。
- **軽4の残り**: 超過したTop原子の入力とRustの理由・Leanのtypingの報告は追加済みである。Leanの入口が原子の理由を返さない制約が残る。budgetExceededは定義上の分類であり実測値ではない。typingを同じ四理由へ変換しない。追加入力の未検査はない。
- 全比較は既存の見込み30〜45分を保つ。各段の最大常駐量を記録し、check_named（routingを含む）には8〜9 GiBを見込む。Leanの交換実行ファイルを全corpusで動かした最大常駐量は未実測で、lakefileの `-M 12288` はPythonにも交換実行ファイルにも適用されない。16 GBの別機で走らせず、起動前に空きメモリを確認する。この条件はレビュー中2の取りまとめ側の起動依頼にも反映する。

`private/`・そこを指すリンク・`docs/todo/` は読んでいない。依存・本番の実装・Lean・主定理・仮定・保証を変える必要はなく、停止条件への該当はない。Gitの状態を変える操作、新しい CARGO_TARGET_DIR、target外の一時ビルド・基準版の展開はない。全体の比較、lake build、shortは実行していない。

K10.2b の途中の検査の実測は次のとおりである。全て `/usr/bin/time -p` の直接の終了を記録した。RSSはmacOSの子プロセス一つの最大値で、並行する使用量の総和ではない。

| 対象 | 終了 | 外側時間 | 補助最大RSS（bytes） |
|---|---:|---:|---:|
| [F-range：9検査](k10.2b-f-range.json) | 0 | 1.343538秒 | 46,317,568 |
| [実ソース・拒否・契約対照・報告側](k10.2b-sources.json) | 0 | 9.158009秒 | 45,203,456 |
| [予算：訂正値と直接比較2件](k10.2b-budgets.json) | 0 | 0.433353秒 | 42,188,800 |
| [既知差3入力](k10.2b-known.json) | 0 | 1.632947秒 | 37,945,344 |
| [退行させた入力12項目](k10.2b-guards.json) | 0 | 1.147995秒 | 41,975,808 |
| [相対のmanifestと全routing](k10.2b-routing.json) | 0 | 16.095769秒 | 8,243,232,768（7.6771 GiB） |

超過の初稿のRust書き出しは終了101、訂正後は終了0であった。最初の `rtk` の要約が診断を省略したため、同じ初稿を通常のCargoで再実行してE0208を記録した。正式な独立比較の実行前の修正であり、失敗した入力を成功として数えていない。新しく作った CARGO_TARGET_DIR やtarget外のビルドはない。

K10.2b の W-K は [dry-run](k10.2b-work-dry-run.log) で K10.2 と同じ10項目を確認し、次を `/usr/bin/time -p` で包んで一度実行した。`formal_build` は前記のB-Leanを引用し、名指しに含めていない。

```sh
scripts/check.sh --level work \
  --base c3ca4504dae42271df7336aca41d0a6d5447d0e3 \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,python_syntax,policy_selftest \
  --test desugar_export --test coverage_export --test golden \
  --test verify --test random_programs
```

[計時](k10.2b-work-check.json)・[生ログ](k10.2b-work-check.log)・[直接の終了](k10.2b-work-check.exit) は、**check.sh 自身が終了0、外側326.588962秒**、time-p の real326.58・user1138.49・sys40.41秒であった。補助最大RSSは 2,265,612,288 bytes = 2160.656250 MiB = 2.110016 GiBである。[件数](k10.2b-work-test-counts.json) はRustの成功1,462・失敗0・既存の無視24、policyは30成功・失敗0である。fmt・clippy・source_rules・生成Skillの一致・仕様の集計・Python構文も成功した。random_programs全体47.89秒、300件/60秒の差分検査も成功し、件数・種・予算の変更や単独再実行はない。

W-K開始後の編集は本ディレクトリの記録・選別と確認の台本だけであり、Rust・formal/tests・scripts/check・交換の入力と期待値・設計書の対応記述は変えていない。W-Kの対象は古くなっていない。後から加えた記録確認の台本は実行し、全てのPythonの構文と最適化で消えるassertの残存も検査する。[最終の関係状態](k10.2b-source-state.json) と [記録の最終確認](k10.2b-record-verification.json) に編集範囲・HEAD/indexの不変・本番とLeanの差分なしを保存する。移動は 2,723ファイル・54,992,547 bytes（52.44 MiB）で、元の相対位置と全ハッシュが一致する。

記録時の時計は2026-10-29 13:23:24 UTC、開始からの外側の所要は1008.1秒（約16.8分）である。能動時間は約10〜12分の概算、W-K待ちは326.589秒であり、記録の整理と一部重なる。局所検査・routingの待ちも一部並行したため単純には加算しない。見込み1〜2時間と停止条件3時間を超えていない。独立レビューと設計者の受け入れは取りまとめが行う。

記録の最終確認の初回は、まだ生成していない関係状態のJSONへのリンクで終了1となった。[失敗と修正](k10.2b-records-first-failure.json) のとおり、JSONを先に生成する順へ直し、記録の確認だけを再実行した。W-Kの対象は変えていない。
