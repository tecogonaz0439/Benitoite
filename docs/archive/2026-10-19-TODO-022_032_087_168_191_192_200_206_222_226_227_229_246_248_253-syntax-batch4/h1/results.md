# H1 の結果

基準は開始時の `git merge-base HEAD san_benito` で得た `498943fe6f1b87db71178354e65ba573e46cf492` である。コミットと docs/todo/ の変更は行わない。

## 実装と検査の関門

私有の ToHeapSession/FromHeapSession を epoch 内に作り、引数全体と戻り値ごとに共有を保つ。行きは Rc の同一性・種類・タグ・文字列/Bytes の長さと元の Value の保持、戻りは ObjId/ObjKind と完成した参照値を持つ。明示の作業列の Remember で完成を登録し、処理中への再入を拒否する。通常関数と外部関数へ同じ方式を接続した。Opaque の根と RefValue の世代検査、独自のストアと構築器 Slot の分離は保つ。公開の型・署名、Lean の定義・定理・仮定は変えない。

作成時の関門: 変換境界で六種類の引数間の共有と戻り値内の共有を独立に検査する。内容だけの往復では再展開を検出できないため、実在対象の同一性を観察する。深い共有の子の同一性、同じ並びの異なる種類/タグ、前の区間の RefValue の拒否も検査する。本番の公開の範囲と注入の口は増やしていない。新しい実ソースの差分は List.get/length を通して小さい整数と長さを照合し、正常終了を必須とする。共有を理由にした除外は追加しない。

共有の深さは局所 12、差分 8/12、gc-stress はともに 6 である。既存の百万要素/百万段の長い往復テストは、既定の大きさと全 assert を保ち、gc-stress の入力だけ K に従ってリスト長 64・深さ 16 とした。新しい ignore、assert の削除、期待値の緩和はない。

三種類の copy 後の物理表現は、既存の `runtime::heap::builders::tests::snapshots_capacity_and_list_children_survive_collection` を用いる。実 Host に追記して容量を増やし、元の snapshot（List は共有した文字列の子も含む）を固定の期待値と比較し、GC 後も再確認する。work の lib_default と check-heap の対象であり、抽象ストアの定理を物理表現の証拠にしていない。02-08/09・07-03/04 へ実装と境界を反映した。構文・標準宣言・診断の表は変えておらず、生成Skillの差分はない。

## 途中の検査

- `cargo test -p benitoite --lib refinterp::convert::tests::shared_`: 修正前に新しい2件が失敗し、行き/戻りの文字列の共有喪失を検出した。対応表の実装後は2件成功した。
- 対応表を組み込む初回のコンパイルで、match を囲むブロックの余分なカンマと重複した変数宣言を検出した。これらを修正して fmt を適用した。
- `cargo test -p benitoite --lib refinterp::convert::tests::`: 12件成功、既存の長いテスト1件はignoreのまま。
- `cargo test -p benitoite --test random_programs shared_bridge_values_are_compared_with_small_observations`: 成功。正常終了の要求を追加した後も同じ1件が成功した。

途中のコマンドの外側の時間は未計測である。

## 完了検査

plan の H1 行と補完に従い、同じ基準・指定の dry-run は終了0で選択と理由を確認した。R185 のとおり lint_default を包含する全ターゲット clippy に置き換えた。作業末の work と各補完はそれぞれ一度だけ実行し、すべて終了0で成功した。正確なコマンド・終了状態・外側の時間は [commands.jsonl](commands.jsonl)、各構成の成功/ignore件数と検査単位は [validation-summary.txt](validation-summary.txt) に保存した。

| 実行 | 結果 | 外側の時間 |
|---|---|---|
| H1 の work | lib 1,244件成功・既存ignore21件。指定4統合ターゲットは既定・heap-verify・gc-stressで各26件成功。通常文書17件とcompile_fail17件成功・既存ignore1件。fmt・規約・生成Skill・仕様集計も成功 | 999.60秒 |
| 全ターゲット clippy | 成功 | 33.27秒 |
| refinterp:: の heap-verify | 37件成功・既存ignore1件 | 34.23秒 |
| refinterp:: の heap-verify+gc-stress | 37件成功・既存ignore1件 | 33.60秒 |
| check-heap 全体 | Miri通常58件成功・既存ignore1件、Miri per-object 51件成功・既存ignore1件、到達可能性20,000列の通常実行50件成功・既存ignore2件 | 666.19秒 |

時間はPythonのmonotonicでコマンド全体を外側から測った値である。Miri内のテスト結果に表示される時間とは区別し、表には外側だけを採用した。完了検査の失敗と、その後のソース修正はない。work のgc-stress goldenは内部表示で641.63秒であり、既存の external/root の深さ10,000の再帰を二方式・テキスト・差分比較で実行する部分に時間を要した。既存の入力と期待値は変えていない。

ゴールデンの既存の除外理由・件数は [heap-verify の集計](golden-summary-heap.txt) と [gc-stress の集計](golden-summary-stress.txt) に残した。通常値の共有を理由にした新しい除外はない。

行数はconvert.rsの本番部分が562→698（+136）、同ファイルのテスト部分が607→799（+192）、random_programs.rsが378→434（+56）である。テスト削除はない。

## ずれと申し送り

R185 に lint の置換と B_WORK を記録した。機能の範囲と保証の変更はない。H2 へは通常関数・外部関数の両方で呼び出し区間が共通になった状態を渡す。セル・Lazy・継続・構築器の独自ストアと通常値の変換は分離したままである。workは約16分40秒、check-heap全体はビルドを含め約11分6秒を要したので、後続の検査時間の見込みに使う。深さ24の性能点はこの作業で測定せず、planのM1以降の割り当てに残す。
