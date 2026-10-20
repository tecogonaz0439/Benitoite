# Z2 RV3の指摘の修正

B_WORKは開始時の`git merge-base HEAD san_benito`で得た`376cc390b98b232ad4f27af5cbb3ea4941053965`である。開始時の差分は、オーケストレータが置いた未追跡のreviews/RV3.mdだけであった。同ファイルは変更せず残した。コミットとdocs/todoの変更は行っていない。

対応の一覧は[RV3-response.md](../reviews/RV3-response.md)、判断は[decisions.md](../decisions.md)のR180〜R184にある。

## 変更したファイル

- typeckのsolve/provenance・solve・diagnostics_batch4: 回復前にも失敗した使用の範囲に限り、成功した部分の制約も回復後に再確認する。`gl([s, "x"])`と`gl(["y"])`は宣言の不一致と独立した使用の不一致を2件残す。宣言の型では成功する`gs([s])`と`gs([s, "x"])`は宣言の不一致1件だけを残す。既存のT5のassertを保つ。由来の連結成分の根に宣言の理由と確定の有無を保持し、空の回復情報の探索を省いた。contextの文言はtextの定数へ移した。
- irのdecision・block_tests: 最終出力の予約まで共有判定の試行に含め、Limitなら状態を戻して行照合へ切り替える。最終出力だけが超過する場合の回帰テストと、ガードの選択肢とtailの束縛を両経路からVM/独立参照評価へ渡すテストを追加した。最終予算の注記は作業表の64 MiB超過の一つに固定した。
- pattern_ext・ir/check・decisionの深さのテスト: gc-stressでも元の深さ・長さへ戻した。random_programsの小さいstress入力の経路をコメントに記した。
- bytecodeのprogram・codegen・buildersと原型の組み立て箇所: 専用入力を持つ本体にbuilder_parentを記録し、Closureの生成元と照合する。verifyの表からannotation欄を除き、親の種類・親番号・別の親でのClosure生成の変異を追加した。
- diag/codesと生成Skill: L0112を定義全般の見出しへ替え、到達しないlimit/definitionの注記を削除した。gen_skillで再生成した。builder_testsとpatternsから作業IDの引用を除いた。
- b3/check_local_exchange.pyとexchange-results.json: 独立表層の末尾returnの四箇所だけを補正し、六入口へ再照合した。formal/は変更していない。
- 設計02-05/06/07/10とplan/decisions: 上記の実装、GCを伴わない深さの入力を縮めない区別、M1へ渡す型検査時間の入力を反映した。

## 作成時の関門と途中の確認

持ち主の境界は公開の型検査、下位化から実codegen/verify/VMへの接続、公開の命令検証器である。型検査の既存の表へ、同じ式内に回復対象と独立した文字列がある入力、変数を含まない対照、宣言の型では成功する使用を追加した。新しい公開の差し込み口は加えていない。行照合と最終出力だけのLimitは既存の私有の予算を消費済みにし、経路の予算と実行結果をassertする。

最初の`declaration_provenance_preserves_causes_and_independent_errors`は、修正前に`gl([s, "x"])`のE0401が1件しか出ず失敗した（終了101、テスト本体0.56秒。初期の外側の時間は未計測）。途中では成功した内部の制約の元の型を失った場合の偽の報告を直した。関係する44件の局所テストも成功した。最後の対照では、元の宣言の型で成功する使用への新しい誤りを確認し、再確認の範囲を元の失敗した使用の内側へ限定した。`regression-declaration-success-before.log`のCLIは、この中間状態の余分なE0401を示す（mainのない一時入力なのでE0414も含み、件数の受け入れには使わない）。最後の局所テストはmainを要求しない公開の型検査で件数を固定している。

親番号の検証を一時的に外した対照は、verifyが不正な入力を受理して`unwrap_err`で失敗した。元のファイルを必ず復元し、最後のworkのverify全3件で成功した。最終出力の予約からの行照合、ガードとリストの束縛、最終注記の局所テストも成功した。

既存assertの削除、期待値の緩和、新しいignoreはない。src/testsの作業IDを検索し、残るtraitsのフック名、ヒープの不変条件名、入力の構成子名は0.0.10の作業名の引用ではないことを確認した。

## 作業末の検査

指定の七単位・五統合ターゲットをdry-runで確認してから、次を一度開始した。

```sh
scripts/check.sh --level work --base 376cc390b98b232ad4f27af5cbb3ea4941053965 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test golden --test random_programs --test verify --test coverage_export --test desugar_export
```

最初はlint_defaultで不要な参照二箇所を指摘され終了1となった。参照を直し、依頼の`cargo clippy --all-targets`でこの失敗も確認した。work全体は再起動せず、同じ基準と統合ターゲットで`--only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally`のdry-runと未実行分を続けた。終了0、外側239.104秒。libは1239件成功・既存ignore21件、coverage_exportは3件成功・既存ignore1件、desugar_exportは27件成功・既存ignore1件、goldenは2件、random_programsは6件、verifyは3件が成功した。規約、生成Skillの一致、仕様集計の自己検査も成功し、初回リリース完了条件の空欄は0である。

最後の型検査の範囲の修正で古くなった検査だけを更新した。`cargo test -p benitoite --lib typeck::tests`の44件、`BENITOITE_GOLDEN_FILTER=batch4-provenance cargo test -p benitoite --test golden golden_suite -- --nocapture`、`cargo clippy --all-targets`、`cargo fmt --check`がすべて成功した。他のモジュールや成功する交換入力はこの最後の修正で変えていない。all-targetsのテスト、特殊構成の全件、check-formal全体は実行していない。

作業末の検査と記録した局所確認のコマンド、終了状態、外側の時間は[commands.jsonl](commands.jsonl)に全引数で記録した。主な実行は次のとおりである。外側の時間はビルドとCargoの待ちを含む。

| 実行 | 終了状態 | 外側の秒数 | ログ |
|---|---|---|---|
| work-dry-run | 0 | 0.016 | [work-dry-run.log](work-dry-run.log) |
| work | 1 | 8.467 | [work.log](work.log) |
| clippy-all-targets | 0 | 14.974 | [clippy-all-targets.log](clippy-all-targets.log) |
| work-rest-dry-run | 0 | 0.015 | [work-rest-dry-run.log](work-rest-dry-run.log) |
| work-rest | 0 | 239.104 | [work-rest.log](work-rest.log) |
| typeck-final | 0 | 18.039 | [typeck-final.log](typeck-final.log) |
| golden-provenance-final | 0 | 4.188 | [golden-provenance-final.log](golden-provenance-final.log) |
| clippy-final | 0 | 6.708 | [clippy-final.log](clippy-final.log) |
| fmt-final | 0 | 4.258 | [fmt-final.log](fmt-final.log) |
| local-exchange | 0 | 1.061 | [local-exchange.log](local-exchange.log) |
| build-baseline | 0 | 28.155 | [build-baseline.log](build-baseline.log) |
| build-candidate-forced | 0 | 26.239 | [build-candidate-forced.log](build-candidate-forced.log) |
| check-timings-final | 0 | 2.401 | [check-timings-final.log](check-timings-final.log) |

## 軽4・軽5の特殊構成の個別実行

heapは`--no-default-features --features gc-mark-sweep,heap-verify`、stressはそれにgc-stressを加えた構成である。libの各対象とrandom_programsの該当一件を、それぞれ`-- --exact --nocapture`で名指しした。各構成9件、合計18実行が成功した。全引数と外側の時間はcommands.jsonl、テスト本体の時間は[special-timings.json](special-timings.json)にある。次の表の秒数はRustのテスト実行器が出した本体の時間であり、ビルドを含まない。0.00は実行器の表示精度以下である。

| テスト | heap（秒） | stress（秒） |
|---|---|---|
| `typeck::pattern_ext::tests::deep_expressions_stay_within_the_normal_stack` | 0.47 | 0.48 |
| `typeck::pattern_ext::tests::deep_list_patterns_stay_within_the_normal_stack` | 2.77 | 2.75 |
| `typeck::pattern_ext::tests::deep_constructor_patterns_stay_within_the_normal_stack` | 0.27 | 0.27 |
| `ir::decision::tests::nested_patterns_and_long_lists_preserve_bindings_without_changing_stack_size` | 0.01 | 0.01 |
| `ir::check::tests::deep_ir_is_checked_without_changing_the_thread_stack` | 0.00 | 0.00 |
| `ir::decision::block_tests::row_fallback_preserves_guard_alternatives_and_list_bindings` | 0.08 | 0.08 |
| `ir::decision::block_tests::block_guard_order_survives_shared_decisions_and_row_fallback` | 0.08 | 0.08 |
| `ir::decision::tests::final_output_reservation_falls_back_to_rows` | 0.00 | 0.00 |
| `random_programs::row_fallback_preserves_guard_alternatives_and_list_bindings` | 0.76 | 0.24 |

復元した深さの五件はstressでもすべて30秒未満であった。縮めたままにした対象はない。型検査の450/900等、判定の連鎖64・リスト4096、IR検査の1000を保った。

## 軽7の局所交換

`python3 -B <D>/b3/check_local_exchange.py`は終了0である。2入力10定義・表層10件・Coverage単体1件・プログラムCoverage1件を六入口ですべて照合し、不一致・対象外・除外・燃料切れは0であった。3定義は独立入力301〜303のコア全体とも厳密に一致した。補正は独立表層の末尾returnの続きの四箇所だけであり、returnの頭の型と返す値、コア、ほかの位置は書き換えていない。結果と入力ハッシュは[b3/exchange-results.json](../b3/exchange-results.json)へ更新した。formal/は変更していないのでlake buildは追加していない。

## 中2のrelease CLIの時間

基準はbe7dc868eb821e39a111720c021bd4d201104ccbのgit archiveから、候補はB_WORKとZ2の作業差分から、どちらも`cargo build --release -p benitoite`の既定構成でビルドした。標本採取中は他のビルドと検査を動かしていない。macOS 27.0.1 arm64、rustc 1.98.1。CPU名はsandboxがsysctlを拒否したため未取得である。入力には空のmainを加え、両状態のcheckの終了0をすべて確認した。

[measure_check.py](measure_check.py)で各入力・各状態を2回予熱し、基準と候補の順を標本ごとに反転して各11標本を採取した。CLIの起動・読み込みからcheckの終了までの外側の時間である。入力、SHA-256、全標本、バイナリのSHA-256と候補のRust差分のSHA-256は[check-timings.json](check-timings.json)に保存した。

| 入力 | be7dc868 中央値（ms） | Z2 中央値（ms） | 基準IQR（ms） | Z2 IQR（ms） |
|---|---|---|---|---|
| chain-250 | 11.167 | 12.230 | 0.930 | 1.453 |
| chain-500 | 11.808 | 13.229 | 0.331 | 0.567 |
| chain-900 | 13.152 | 14.934 | 0.459 | 0.155 |
| arithmetic-400 | 11.959 | 13.437 | 0.346 | 0.303 |

N=250から900へ入力が3.6倍になる間、候補の時間の増分は約2.7 msであり、基準の増分は約2.0 msであった。各点の差は約1〜2 msで、レビュー時の二次的な増加は見られず、基準と同程度の増え方へ戻った。これはこの入力と大きさでのCLI時間の観測であり、計算量の証明や全入力の性能保証ではない。時間をassertするテストは追加していない。M1へ連鎖250/500/900文と算術400行をcompareの型検査時間の入力に加える割り当てを追記した。

測定前の最初の試行はCPU名の取得で止まり、標本を一つも採っていない。同じtargetを使った基準ビルドが候補の出力先を上書きし、候補のcargoがFreshのままになることもバイナリのハッシュで検出した。候補のlib/binのfingerprintだけを無効化して既定のreleaseを強制ビルドした後、基準と候補のハッシュが異なることを確認してから採取した。初回のbuild-candidate/build-candidate-freshとcheck-timingsの結果を標本へ混ぜていない。

## 計画からのずれと申し送り

R180で、失敗した外側の比較だけでなく元の使用の内部の制約を保持する必要を記した。R181は連結成分の要約、R182は最終出力の予約までの切替、R183は親の対応を検査するためのProtoのbuilder_parentの追加である。R184はlint失敗後の未実行分の続行と、最後の局所修正で古くなった検査だけの更新を記す。テストの保証は弱めていない。

RV3の中2件・軽10件への対応を終えた。H1はこの状態から進められる。専用入力を持つ手組みのProtoには生成元のbuilder_parentも必要であり、H1以降でProtoを作る場合はこの欄を保つ。M1のcompare入力追加、版全体のchange・全形式化比較・short/targets・公開候補のreleaseは取りまとめと後続の割り当てに残す。この局所の成功を版全体の受け入れ完了には使わない。
