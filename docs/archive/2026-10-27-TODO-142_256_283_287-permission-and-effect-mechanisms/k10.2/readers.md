# 読者・全比較・manifest の接続

B_WORK は `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。git の状態を変える操作、Lean のソースの編集・ビルド、全比較の実行はしていない。`private/` と `docs/todo/` は読んでいない。

## 作成時の関門

守る契約は、版の対応・全入力の routing・非空の比較・範囲の群の非Topを、交換の本物の入口で検査することである。現実的な退行は、生産側だけの版更新、sidecar の取り違え、corpus の一部欠落、候補だけに残った非Topである。既存の版の読者は corpus15 を読めず、既存の非Top件数には候補も含まれたため、この接続を検査できなかった。既存の表形式のテストと台本を拡張し、本番の差し込み口は足していない。

## 変更

- `formal/tests/test_batch2_exchange.py::check_rust` と `test_batch5_exchange.py::check_rust` は、Rust の出力を corpus15/sidecar7 に固定した。手書きの旧版独立入力と、その互換検査は保持した。
- `test_batch3_exchange.py::rust_inputs` は12/4・13/5・14/6・15/7をそれぞれ受理する。同じ corpus に違う版の sidecar を混ぜた入力は拒否する。既存の件数契約のテストへ、この四組と混在の拒否を加えた。
- `check_batch3.py` の構築器と batch5 の書式の独立期待値は、旧版の保存済み期待値を読む。比較時だけ `check_named.py::explicit_top_ranges` で同じ意味の明示Topと空の呼び出し範囲へ移す。Rust の出力から期待値を生成しない。
- batch3 の manifest に k3（5定義）とk4（7定義）を加えた。これらの件数は通常ソースの関数・照合の件数に対応する。全比較は b3・blocks・g2・g3・k3・k4・m1・t3 の8組を `check_batch3.py` へ渡す。
- k3 はプログラム網羅性の対象が0件である。その入口には終了1・matched0・不一致0・対象外0・燃料切れ0を要求し、`statuses` と `empty_comparisons` に記録する。空の比較を成功とは数えない。ほかの5入口と非空の独立網羅性は成功を要求する。全ての群に0件を許す変更ではない。
- named-declarations の manifest に `rangeComparison=true` を加えた。`check_named` は候補を除いた corpus を保存して desugarDiff と surfaceCheckAll へ渡し、両方の報告の `nonTopRanges` が実際の型と項の件数に一致し、0より大きいことを要求する。
- 全比較へ `test_range_exchange.py --output <E>/range-exchange-comparison` を加えた。既存の六入口、intervalDiff、四書き出し、独立交換、profile/VMを保持した。
- CLI のビルド後に、新しい独立実ソースの比較 `test_range_sources.py --exports <E>/range-sources --cli target/debug/benitoite --output <E>/range-source-comparison` を接続した。
- `formal_interval.py` の最終manifestは独立実ソースの summary を読み、成功、非空の群と定義、拒否と診断付き除外、六入口の重複のない集合、範囲の各群の `nonTopRanges>0` を要求する。全入力と報告は既存の inventory のSHA-256照合へ入る。

## 局所の検査

最初の再現は [readers-before.log](readers-before.log) である。旧読者は corpus15 に `expected corpus12, corpus13 or corpus14` と返して終了1であった。15/7への追随後に、独立の旧版期待値との比較も含めて下記を通した。

| 検査 | 結果 | 外側の時間 |
|---|---|---:|
| batch2 の独立交換とRust op出力 | unittest 8成功・失敗0、Rust六入口成功 | time-p real 2.58秒 |
| batch3 の独立交換とRust b3出力 | unittest 7成功・失敗0、Rust六入口成功 | time-p real 4.78秒 |
| batch5 の独立交換とRust出力 | unittest 8成功・失敗0、Rust六入口成功 | time-p real 2.50秒 |
| named-declarations の候補除外 | 5定義一致、両報告の非Top17 | 単調時計0.125秒 |
| 同入力の本体を全Topとし候補だけ非Topを残す変更 | `all-Top range comparison` で意図した拒否 | 同じ局所台本 |

正確なコマンドとgetrusageの補助最大常駐量は [readers-tests.json](readers-tests.json) と各 `readers-batch*-tests.log` に保存した。同じPython親から逐次起動した三コマンドの最大の子の値は51,871,744 bytes = 49.46875 MiBであり、三コマンドそれぞれの値とは主張しない。batch5 の各入口の報告は [readers-batch5-report.json](readers-batch5-report.json)、named-declarations の入力と各報告は [readers-named/](readers-named/)、正負の結果は [readers-named-probe.json](readers-named-probe.json) に保存した。

8組の最終の台本照合は [readers-batch3-runs.json](readers-batch3-runs.json) にコマンド・終了・外側時間・入力ハッシュを残した。入力自体も `readers-batch3-inputs/` へ写した。b3・blocks・g2・g3・k3・k4・m1・t3 はそれぞれ52・10・11・8・5・7・31・9定義で、全て終了0である。k3の空のプログラム網羅性だけは上記の終了1を報告に残した。

追加の件数検査の初回には、独立coverageDiffにも `outOfScope` 欄があるとして8組とも `KeyError` で失敗した。coverageDiff はその欄を持たず、coverageProgramDiff は持つ。両形式を区別して、プログラム網羅性にだけ対象外0を要求するように直し、8組を再実行した。失敗は `readers-*-guard-failure.log` と [readers-batch3-guard-failure.json](readers-batch3-guard-failure.json) に保持した。成功だけへ上書きしていない。

変更したPython6本を構文解析し、`bash -n scripts/check-formal.sh` を実行して成功した。[readers-syntax.json](readers-syntax.json) に対象を記録した。作業末の検査は取りまとめが実施する。

全 corpus の routing の書き出しと照合も完了した。結果・保存物・互換検査の補足を以下に記す。

batch4 の旧版の互換検査も `python3 -B formal/tests/test_batch4_exchange.py` で実行し、15成功・失敗0、終了0、time-p real6.53秒であった。[readers-batch4-compat.json](readers-batch4-compat.json) と [ログ](readers-batch4-compat.log) を保存した。補助最大常駐量42,582,016 bytes = 40.609375 MiBである。batch3 の corpus12 の構築器に版13への再生成を要求する入力、batch4 の旧版の分岐、batch5 の8〜14の世代の検査を保持した。区間の手書きSurface14と、range交換の版14に範囲の欄を置く拒否入力も旧版境界の検査なので変更していない。

8組の最終の台本照合の外側時間の合計は2.772秒、同じPython親の子の最大常駐量は51,773,440 bytes = 49.375 MiBである。保存した40入力の合計は2,319,591 bytesである。

予算の実ソースの書き出しも全件の Rust テストから採取する。全比較のCLIビルド後に `test_range_budget_sources.py --rust-dir <E>/range-budget --output-dir <E>/range-budget-comparison` を接続した。最終manifestは Rust 独自の番号付け停止1件と、Leanと直接比較する2件・Requiredの理由比較2件を区別する。Leanの比較の各行に定義と候補除外の非Topを要求する。補助の期待値の不一致は件数と一覧の整合だけを検査し、内容と成功の射程をそのまま残す。補助不一致1件を全比較の受け入れ条件には固定しない。

候補だけの非Topを拒否する局所台本は [readers-named-probe.py](readers-named-probe.py) に保存した。`python3 -B <改造のディレクトリ>/k10.2/readers-named-probe.py` で再実行できる。対象は保存した5定義の入力であり、非Top17の独立した件数も照合する。

否定入力の候補は正規形の `IO.File.Read` の `/data/**` である。候補だけに非Topを残した入力を、改造前のmanifest相当（`rangeComparison` がない設定）へ渡すと、両入口が一致し `nonTopRanges=1` になることも確かめた。同じ入力は新しい条件では `all-Top range comparison` で拒否する。[否定入力と旧条件での報告](readers-named-negative/) を保存した。候補の形式の誤りによる拒否とは混同しない。

既知の差のCLI台本 `test_range_known_differences.py --cli target/debug/benitoite --output-dir <E>/range-known-differences` も全比較へ接続した。最終manifestには E0711・Leanの文字列の精度差の各1件の名指し除外と、除外しない受理の対照1件を含む3件を別に収録する。同じRust/Leanの受理・理由の成功へ加算しない。

最終manifestの範囲の部分は `formal_interval.py::range_counts` に集め、実際の比較の後にその報告を読む。手書きの `range-sources/expected.json` と成功群・全定義数・範囲の群・Top互換群・全定義の検査を照合し、`report-expected.json` から報告側の入力数とコマンド数も照合する。両期待値のSHA-256を保存するので、最終manifestを読み戻す際にも、期待値の取り違えや変更を拒む。今回の実際の報告は15群・18定義・拒否6件・診断付き除外8件、範囲12群・Top互換3群、報告側26入力・50コマンドである。

この読者は主源・予算・既知差の実際の3summaryで成功した。[読み取った結果](readers-range-manifest-probe.json) を保存した。範囲の群を一つ欠く、定義の合計を一つ減らす、全Topの固定した対照を非Topへ変える、予算比較の出現の鍵を欠く、既知差の除外件数を変える、の5変更をそれぞれ意図した理由で拒否した。[結果](readers-range-manifest-negatives.json) を保存した。最初の局所照合では旧Scopeと同名利用者関数にも任意の厳密件数 `nonTopRanges` を要求して KeyError となった。手書きの期待値が持つ最低件数を使い、厳密件数を持つ入力だけ厳密に照合するように直した。期待値は変更していない。

batch2の読者の呼び出し元が三種類あるため、`check_rust` を `target/formal-batch2-failure` と `target/formal-batch2-character` にも直接適用して成功した。failure は14定義であり、既存の `check_failure.py::check` のNoFailの拒否理由と不正署名の終了2も確認した。結果は [readers-batch2-additional.json](readers-batch2-additional.json) に保存した。opで一度成功したunittest8件は繰り返していない。

## 全 corpus の routing

`BENITOITE_DESUGAR_DIFF_DIR=target/k10.2-readers-routing /usr/bin/time -p cargo test --test desugar_export export_desugar_corpus -- --exact --ignored --nocapture` を一度実行した。終了0、1792入力（golden792・random1000、書き出し1373・診断付き除外419・対象外0）であった。time-pは real1346.50秒・user1337.25秒・sys6.60秒、Python親の外側は1346.507秒、getrusageの子最大常駐量は401,522,688 bytes = 382.921875 MiBであった。[コマンドと計時](readers-routing-export.json)・[生ログ](readers-routing-export.log) を保存した。全比較は実行していない。

`/usr/bin/time -p python3 -B <改造のディレクトリ>/k10.2/readers-routing.py` は `check_named.py::check_routing` をこの全1792入力へ適用する。最初は既存のmanifestに埋め込まれた元リポジトリの根と、今回の作業用ディレクトリの違いで終了1となった。対象は `NoMainFile` の3入力であり、除外種類と対象の相対位置には差がなかった。初回はreal14.59秒、getrusageの子最大常駐量8,219,148,288 bytesであった。[初回ログ](readers-routing-first-failure.log)・[初回の計時](readers-routing-run-first-failure.json) を保持した。

期待値は書き換えず、読者が `NoMainFile` のディレクトリだけを移動に依存しない形にした。絶対パスであり、`crates/benitoite/` とそのentryの完全な相対名で終わることを要求し、除外種類・相対位置・ほかの分類は比較する。basenameだけの一致では通らない。同じ相対入力の移動は一致し、除外種類・別の相対ディレクトリ・scope分類を変えた3負例は拒否することを [局所確認](readers-routing-relocation-probe.json) に残した。

修正後の全件の照合は終了0、識別子・除外・scope・coverageが全て一致した。time-pは real14.37秒・user13.54秒・sys0.78秒、Python親の外側14.383秒、getrusageの子最大常駐量は8,808,923,136 bytes = 8,400.84375 MiB = 8.203948974609375 GiBである。いずれも逐次に起動した子の最大値であり、同時使用量の和ではない。[一致の記録](readers-routing-agreement.json)・[生ログ](readers-routing.log)・[計時](readers-routing-run.json) に保存した。

実際の出力1009ファイル・合計2,676,913,918 bytesの大きさとSHA-256は [readers-routing-artifacts.json](readers-routing-artifacts.json) に保存した。大きい交換・区間の生の出力はこの一覧を残し、本文を改造のディレクトリへ複写していない。生成した1000実ソースは [readers-routing-generated-sources.zip](LARGE-FILES.md)（4,505,234 bytes）へ写した。[固定のrouting期待値の写し](LARGE-FILES.md) は手元のパスを `<home>` に伏せた閲覧用である。比較で読んだ元ファイル自体は変更せず、元のSHA-256も一致の記録に保存した。記録の台本から再実行できる。

この書き出しだけで約22.44分かかったため、K10.3の全比較は30〜45分を見込む。全六入口の全定義・全件の比較、独立交換、四つの区間の書き出しとprofile/VM、manifestの最後の読戻しの新版全体は未実測であり、この幅は保証ではない。全比較の実行前に取りまとめがこの見込みを示す。今回、全比較・Leanのビルド・性能比較を実行していない。

担当の編集はここで終了した。処理系の本体の簡素化やテストの削除はなく、Rust/Leanの本体は変更していない。新しいCARGO_TARGET_DIR、target外のビルド・基準版の展開は作っていない。台本の一時ディレクトリはその終了時に解放した。停止条件への該当はない。能動時間は約20分の概算であり、約22.44分の書き出し待ちと重なるので加算しない。作業末のW-Kは主担当へ引き渡した。全比較の実行と独立レビュー・受け入れは主担当・取りまとめの担当である。

担当した読者・検査台本・manifestの9ファイルは追加208行・削除24行であり、内訳を [readers-change-counts.json](readers-change-counts.json) に保存した。Rust/Leanの本体は追加0行・削除0行である。最終の対象ファイルのSHA-256は [readers-source-hashes.json](readers-source-hashes.json) に保存し、Python6本とシェルの構文検査の成功も最後の修正後に取り直した。

## W-K 後の入口の調整

主担当の W-K は、Rust の全件と指定統合・仕様例は成功したが、policy_selftest の `test_formal_entries_and_failure_propagation` がシェルの `check_batch3.py` の呼び出し4回を固定しており、追加した8回との不一致で終了1となった。編集できない test_policy.py は変更せず、既存のシェル4入口（b3/blocks/g2/g3）を保ち、残るk3/k4/m1/t3は最終読者 `check_named.py::check_remaining_batch3` から同じ検査関数を呼ぶ形へそろえた。全8群の六入口は減らしていない。check_named の失敗は既存の外側の入口へ伝播する。

[追加4群の実交換](final-batch3-reader/summary.json) は5/7/31/9定義・各六入口で成功した（k3の空のプログラム網羅性は従来どおり成功へ算入しない）。終了0、外側1.562258541秒、補助RSS47,120,384 bytesである。[policy_selftestの部分再検査](work-policy-retry.json) は30成功・終了0・外側26.570396292秒である。初回の終了1と生ログは work-check に残し、Rust入力が変わらない既存の成功を重ねて再実行していない。
