# G3: 一段ずつの縮小候補と合成部品

基準のコミット（B_WORK）は `c5491f6f86b2bb662bc039a9f811093752ba37a3`。開始時の差分はない。コミットとdocs/todoの変更は行わない。

## 変更

- Property.bntへ公開dataのShrinkStepとmapSteps/appendStepsを追加した。Done/Yield/Skipを保ち、保持した続きを先に呼ばず、続きからの再帰を末尾位置へ置く。左がDoneのappendStepsはSkip(right)を返す。
- 標準の整数・Float・Boolean・Option・List・String・Mapの縮小を私有の段へ移した。原値と既出の候補の比較をそれぞれ一回ずつの段へ分け、equality・初出順・Unicodeスカラー・Mapの鍵順を保つ。候補全体のListと一括重複除去を内部で作らない。
- 旧Shrinkerの入口は段を全量収集してListを返す。要素の旧ShrinkerからListを受け取る橋渡しも保つ。Config・Counterexample・check・libraryVersion 1.0.0と生成テンプレートは切り替えず、作業量の予算を実装済みとは説明しない。
- 既存の候補順のassertを保持し、削除幅・位置の全順序、Optionの元値/重複、サロゲートになる中間値の除外を追加した。新しい合成の遅延・型の変更・純粋性・equality不要と、1024段のmap/appendで64個のSkipを終端まで進める検査を追加した。
- 03-06・06-04・07-04の形式化の境界と英語リファレンスを更新し、gen_skillで生成参照を更新した。日本語訳はV1へ残す。

## 検査

作業途中はproperty_libraryの関係するテストだけを実行した。新しい標準ソースのラムダが外側の名前を隠すE0338と、引数名を変えたことで関数型に一致しないE0454が発生した。元の公開の引数名を保ち、要素縮小器の橋渡しを私有のelementStepperへ分けて修正した。既存assertの削除・緩和・ignoreの追加はない。

- `cargo test -p benitoite --test property_library builtin_shrinkers_have_ordered_distinct_candidates`: 修正途中の2回は終了101。修正後、Floatの比較を段へ分けた最終実装と追加ケースで終了0（1件、0.23秒）。
- `cargo test -p benitoite --test property_library shrink_steps_preserve_single_transitions_and_defer_callbacks`: 上の標準ソースの型不一致が残った1回は終了101。修正後は終了0（1件、0.17秒）。
- `cargo test -p benitoite --test property_library`: 局所の確認として終了0（13件、7.54秒）。その後のFloatの私有処理と追加の境界ケースは、直した箇所の局所検査と作業末のworkで確認した。
- `cargo test -p benitoite --test property_library effectful_callbacks_are_rejected_at_the_public_contract`: 合成部品の純粋性の追加ケースも含め終了0（1件、0.44秒）。

上の秒数はCargoが表示したテスト部分の時間であり、局所検査の外側の時間は未計測である。編集としてのcargo fmtとcargo run -p benitoite --example gen_skillは終了0。

作業末は次を各一度実行した。時間は/usr/bin/timeでプロセスの外側から計った値である。workはrtk proxy、追加clippyはrtkを経由した。

| コマンド | 終了 | 外側の時間 | 結果 |
|---|---|---|---|
| `scripts/check.sh --level work --base c5491f6f86b2bb662bc039a9f811093752ba37a3 --test '*' --dry-run` | 0 | 未計測（1秒未満） | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択 |
| 上と同じ指定のwork（`--dry-run`なし） | 0 | 400.28秒 | lib 1211件成功・既存ignore 21件。39統合ターゲットは294件成功・既存ignore 7件。Propertyは全13件成功（7.79秒）。fmt・通常clippy・規約・生成Skill・仕様集計も成功 |
| `cargo clippy --all-targets` | 0 | 11.86秒 | exampleを含む全ターゲットのlint成功 |

workが実行したRustの検査は `cargo test -p benitoite --lib`、`cargo test -p benitoite --test '*'`、`cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`、`cargo fmt --all --check` である。追加clippyを含む本検査の外側の時間は計412.14秒。git diff --checkも終了0。workの再実行はない。dry-run以降に追加・確定したのは本結果の記録だけであり、実装・テスト・生成物の入力を変えていない。formal/へ触れていないためlake buildを追加せず、全体・特殊構成・形式化比較は取りまとめへ残す。

## test-auditの作成時の四問

1. 公開のpipelineから実VMまでつなぎ、候補の順、Done/Yield/Skipの境界、遅らせた評価、純粋性、長い合成でも停止まで進められる契約を守る。
2. 続きや右列を先に呼ぶ、Skipを内部で走り切る、候補を逆順にする、既出との比較を省く、合成の戻り待ちを段を越えて積み重ねる退行で失敗する。未評価であるべき続きは、呼ぶと0除算で実行停止する純粋関数を使い、成功する経路で呼ばれていないことを観測する。
3. 既存のList返却APIの検査では合成部品の段と遅延を観測できないため、公開ShrinkStepの検査を2件追加した。候補順とコールバックの型の検査は既存テストへケースを追加し、同じ境界のテストを重ねない。
4. テスト用の公開口・フラグ・内部の差し込みは加えず、本番の標準ソース・型検査・脱糖・VMを使う。私有の縮小処理は公開の旧Shrinkerの候補で確認し、その私有関数をテストのために公開しない。

本番のProperty.bntは182行追加・71行削除、property_library.rsは106行追加・削除なし。新規テスト2件、既存2件へケース追加。

## 計画との差と申し送り

R174に開始版と移行境界を記録した。旧要素ShrinkerがListを返す境界を保ち、G4でcollectSteps・listSteps・elementStepperを撤去し、公開Shrinkerから私有の各段へ接続する。全量収集する入口を最終APIへの移行の既定アダプタにしない。G4へ公開API・Config/Counterexample・予算・libraryVersion 2.0.0・手書き/生成テンプレート・同梱例/記録の一度の移行を残す。性能の本測定・change・全形式化比較・releaseは取りまとめへ残す。

R130の集計への申し送り: 変更した標準ソースはTest/Property.bntのみ。関数定義は38から50（公開19から21、私有19から29）、型定義は5から6である。ShrinkStep一型とDone/Yield/Skipの三構成子を追加した。

- 追加した関数19件: mapSteps、appendSteps、collectSteps、listSteps、elementStepper、integerSteps、floatSteps、booleanSteps、optionSteps、listShrinkSteps、deleteSteps、replaceSteps、uniqueSteps、compareSeen、characterSteps、scalarSteps、mapShrinkSteps、deleteMapSteps、replaceMapSteps。
- 撤去した私有関数7件: deleteWidths、replaceElements、unique、shrinkCharacter、scalarCandidates、mapCandidates、replaceMapValues。既存の七つの公開縮小器と私有のintegerHalves/mapShrinkerの本体を新しい部品へ接続し、integerHalvesの私有署名を変えた。
- 生成例・設定・記録・golden入力の増減は0。統合テストは上記2件追加だが、形式化corpusの固定入力は追加していない。交換manifestとrouting-manifestは更新せず、最終候補の標準ソースの定義・脱糖・表層・網羅性・対象外件数を取りまとめが再集計する。上の宣言数の差を各corpusへの出現回数へそのまま写さない。

formal/・本体の型とエフェクトの規則・定理・仮定・GC/VMは変更していない。
