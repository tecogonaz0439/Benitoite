# 段と改造全体の結果

計画の「stage・局所交換・安全点の検査」の区切りごとの記録である。作業ごとの記録は `<小文字作業ID>/results.md` にある。

## 段1末（L1〜L7）

stage は計画どおり省いた。L7 の既定の `lake build`（sorry なし）と六入口の独立入力は l7/results.md、主定理 30 件が変わらず標準の 3 公理だけに依ることは reviews/RV2.md が確かめた。Rust はこの時点で未接続であり、本番の全比較をしたとはしない。

## stage2（T1〜T3）

再実行せず、T3 の作業末の work を引用した（t3/results.md）。T3 の work は stage2 の 4 対象（desugar_export・coverage_export・golden・named_arguments）を含む全統合と局所交換を、T1〜T3 を取り込んだ状態で実行して成功した。T3 の後、K1 の前に関係入力を変えた取り込みはない。判断者は Claude、2026-10-18。

## stage3（K1〜K4）

再実行せず、K4 の作業末の work を引用した（k4/results.md「stage3へ渡す検査状態」）。K4 の work は K1〜K3 を取り込んだ HEAD と K4 の全入力で stage3 の 5 対象（golden・declarations・runtime_builtins・reference_examples・skill_docs）を実行して成功し、検査後の変更は記録の追記だけである。判断者は Claude、2026-10-18。

## stage4（M1・B1〜B3）

- 基準: `B_STAGE4` = 6f60cd22（K4 の取り込み）。HEAD = 90c87a93（B3 の取り込み）。
- コマンド: `scripts/check.sh --level stage --base 6f60cd22 --only tests_related --test desugar_export --test vm_handlers --test vm_lazy --test vm_reference_cells --test named_arguments --test verify`（先に同じ指定の `--dry-run` で選択を確かめた）。
- 終了状態 0、外側の時間 110 秒。6 ターゲットで 52 件成功、ignored 1 件（既存の long）、失敗 0。
- 局所交換（M1・B3）と B1・B2 の局所 heap/stress は各作業の results.md にあり、ここでは重ねていない。

## A1（RV3 の直し）

段の検査の対象ではない。A1 の作業末の work（基準 7f431373、全統合 39 ターゲット）は a1/results.md にある。

## stage5（G1〜G4）

- 基準: `B_STAGE5` = fb1e2f1d（A1 の取り込み）。HEAD = ebfd0e26（G4 の取り込み）。
- コマンド: `scripts/check.sh --level stage --base fb1e2f1d --only tests_related --test declarations --test property_library --test test_command --test desugar_export`（先に同じ指定の `--dry-run` で選択を確かめた）。終了状態 0、外側の時間 26 秒。4 ターゲットで 84 件成功、ignored 2 件（既存の long）、失敗 0。
- 同梱例: `target/debug/benitoite check tools/derive/examples/People.bnt`（終了 0）、`target/debug/benitoite test tools/derive/examples/People.bnt`（2 件成功）、`python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json`（generated regions and records match、終了 0）。

## 段6末（H1〜H3）

計画どおり stage を省いた。直後の V1 の work と、取りまとめの change・全形式化比較が、最終の標準ソースと doc・報告を覆う。H1〜H3 の作業末の work はそれぞれ h1/・h2/・h3/results.md にあり、いずれも成功した。H3 の work で、A1 が足した長い const 連鎖のテストが初回に 10 秒の上限を超え、再実行で通った。これは RV4 の中2 の指摘と同じ現象であり、A2 で時間の assert を外して直す。

## check-formal 全体

- コマンド: `scripts/check-formal.sh`。3 回実行した。
- 1 回目（HEAD 59300538）: 比較はすべて不一致 0 だったが、各プログラムの最終の Rust の書き出しの確認で `corpus: expected batch2 version` で止まった。formal/tests/test_batch2_exchange.py の check_rust が corpus の版を 11 に固定していた。B3 が交換器の corpus を 12 にしたので 12 を求める形に直した（2777c244）。手書きの独立入力の 11 は旧版互換として別に読む。
- 2 回目（HEAD 2777c244）: check_named.py が、routing の固定記録に golden の 10 入力が足りないことで止まった。続けて、全プログラムの振り分け、生成例の定義数、surfaceCheckAll の件数の固定記録も、実際の出力（target/desugar-diff/run-79488）から数え直した（df017c71）。増えた理由は次のとおりである。
  - K1〜B2 が足した golden の 10 入力。
  - K2 が l40-regex に足した `invalid` の関数。
  - G2・G4 の生成例が足した、実装のメソッド 3・上位辞書 3・私有の段の関数 7。
  - 実装を含む例を、表層では実装一件として数えること（named の項目に surfaceChecks を足した）。
  期待値を実際の出力に合わせただけでなく、各増分の出どころを上の作業の変更に対応づけて確かめた。
- 3 回目（HEAD df017c71）: 終了状態 0、外側の時間 15 分。不一致はすべて 0 だった。
  - 脱糖の照合: golden 363 プログラム・1,034 定義、生成入力 1,000 プログラム・72,778 定義。
  - 組み込みの比較: 111,260 件。網羅性の比較: 22,472 件。表層の検査: 51,701 件。
  - batch3 の独立入力: 9 入力・52 定義が六入口すべてで一致した。
- 元の記録: target/desugar-diff/run-88279（一時）。追跡する要約は二つの manifest（exchange-manifest.json・routing-manifest.json）である。

## change

- 基準: `B_CHANGE` = 6b0568a3ddcc46b0a0e64504139ce286a27fd86a。
- 1 回目（HEAD df017c71）: 計画の指定（plan.md「検査の割り当て」の change の行）で実行した。先に同じ指定の `--dry-run` で 17 単位の選択を確かめた。
  - fmt・lint_default・lint_heap・test_default_all・test_heap_all は成功した。
  - test_stress で、G3 が足した `deeply_composed_skip_sequences_advance_without_stack_growth` が 6 時間半を超えて走り続けた。深さ 1024 の map/append の合成を、確保のたびに回収する gc-stress で辿るためである。7 時間 13 分の時点で止めた。
- 直し:
  - e9e441f8: このテストの大きさを、gc-stress の構成でだけ 64 Skip・1024 段から 8 Skip・32 段に下げた。既定の構成では元の大きさで 7.5 秒、gc-stress ではファイル全体で 15 秒になった。
  - ce50e3de: long_only は stress の構成でも ignored を走らせる。そこで、公開の上限（maxShrinkWork 1,000,000・maxShrinks 100,000）まで駆動する長いテスト 2 件も、gc-stress でだけ予算を下げた（作業量 2,000・縮小 200）。heap の構成では元の上限のまま通る（167 秒）ので、上限そのものの確認はそちらで行う。gc-stress では 7 秒である。
  - 期待値は、下げた大きさから同じ式で求める。assert は消しておらず、緩めてもいない。
- 2 回目（HEAD ce50e3de）: 1 回目で通った単位のうち、変えたテストのファイルに関わる fmt・lint_default と、test_stress 以降を名指しした。`--only fmt,lint_default,test_stress,doc_default,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,python_syntax,migrate_selftests,skill_eval_selftest,licenses,policy_selftest,long_only,formal_build`。終了状態 0、外側の時間 47 分。テストの結果は合計で成功 1,637・失敗 0・ignored 31 件、long_only は 28 件を完了した。
  - test_default_all・test_heap_all・lint_heap を再実行しなかったのは、直しがテストのファイル 1 つの gc-stress の分岐だけで、既定と heap の構成ではテストの中身が変わらないためである。既定の構成は該当の 1 件を、heap の構成は長い 2 件を、直した後に直接走らせて通した。
- Python と外部生成の補完: test_derive.py・derive_inventory と CLI の実ビルド・G4 の同梱例の照合は、V1 の結果を引用する（v1/results.md）。V1（ede2d537）の後の変更は、上の formal/tests・manifest・check_named.py・property_library.rs だけで、derive の入力（tools/derive/、標準ソース、crates/benitoite/src/）は変わっていない。判断者は Claude、2026-10-19。

## 性能（本測定の代わりの確認）

R190 により、静かな計算機での本測定は行わず、道具の動作と大幅な低下の有無だけを確かめた。計算機では別のプロジェクトのハーネスが動いており、値にはそのぶれが入る。

- short: `python3 tools/bench/compare/run.py --tier short --state before=6b0568a3ddcc46b0a0e64504139ce286a27fd86a --state after=50f3d4b94ed257c7494263d1aa35ca0c9f3ea389 --out target/bench/v009-short`。終了状態 0、外側の時間 106 秒（候補のビルドを含む）。62 入力・5 標本。出力の照合は全族で通った。退行の疑い（10% か 2 ms の大きい方を超える遅れ）は 0 件だった。判定は達成 38・判定不能 24 で、判定不能は差がぶれ以下のものと、0.0.8 にない構築器の比較である。縮小の最大値の系列（n=24、maxShrinks=20）は約 0.42 秒速くなった。
- targets の試走: `python3 tools/bench/compare/run.py --tier targets --quick --state old=6b0568a3… --state map=f0e6c71d… --state solve=c4310604… --state final=50f3d4b94ed257c7494263d1aa35ca0c9f3ea389 --targets docs/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/bench-targets.json --out target/bench/v009-targets-quick`。終了状態 0、外側の時間 86 秒。4 状態の出力の照合と、169 件の目標の評価の出力まで通った（試走は小さい入力・2 標本なので、判定は達成 2・判定不能 167・未達 0 であり、目標の判定には使わない）。
- 記録の写し: perf/short-results.md、perf/short-result-manifest.json、perf/targets-quick-results.md。
- 候補 50f3d4b94ed257c7494263d1aa35ca0c9f3ea389 の crates/・Cargo.toml・Cargo.lock は b90070b6（change を通した状態）と同じである。
- 判断者は設計者（大幅な低下がなければよい）、確認は Claude、2026-10-19。
- 確かめた範囲（RV5 の軽4）: short の判定欄の「達成」は、退行の幅（10% か 2 ms の大きい方）の内だったという意味であり、R17・R19・R22 の目標の達成ではない。実行時の族の short の点は 15〜27 ms で、そのうち約 11 ms は CLI の起動なので、VM の実行時間の退行の検出力は低い。0.0.9 は VM とランタイムを変えていないので、「大幅な低下がない」は主に検査の時間と起動について言える。構築器の族は、既存の関数だけを使う点も 0.0.8 側で除いており、旧版と比べていない。
- 記録の置き場所（RV5 の軽3）: 性能の受け入れの本測定の記録ではなく、静かでない計算機での確認の写しなので、tools/bench/results/ ではなく改造のディレクトリの perf/ に置いた。

## release（自動の部分）

- 基準: `B_CHANGE` = 6b0568a3ddcc46b0a0e64504139ce286a27fd86a。HEAD = fbead3de（crates/・Cargo.toml・Cargo.lock は change を通した b90070b6 と同じ）。
- コマンド: `scripts/check.sh --level release --base 6b0568a3ddcc46b0a0e64504139ce286a27fd86a`（先に同じ指定の `--dry-run` で release_stack だけが選ばれることを確かめた）。終了状態 0、外側の時間 67 秒。release_stack は最適化の構成で 10 件成功した。
- 受け入れには手動照合が要る。手動照合は Q3（q3/results.md）が行う。
- 手動照合（Q3）: 一度目は design.md 15.3 の保存例の Regex の import の書き損じで止まった（R191 で例を直した）。やり直しで、計画の五つの箇条がすべて一致した（候補 92120a2f。q3/results.md と q3/evidence.json）。保存例の読み替えは 15.1 の checkPath の一行置換の一件で、R192 で design.md に明記した。92120a2f と f7243bb4 の差は記録だけである。

## RV5 の直しの後の検査

- 基準: f7243bb4（Q3 の取り込み）。直しは R192 のとおりで、Rust はテストのコメント一行だけ、ほかは文書・記録・道具の README・スキルである。
- コマンド: `scripts/check.sh --level work --base f7243bb4 --only fmt,reference_examples,skill_docs`（先に同じ指定の `--dry-run` で選択を確かめた）。終了状態 0、外側の時間 9 秒。
- change・check-formal・release・Q3 の結果は、直しが処理系の振る舞い・標準ソース・テストの中身を変えないので、引用のまま有効とする。判断者は Claude、2026-10-19。
