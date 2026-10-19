# G4: 縮小の予算と公開API・生成の移行

基準のコミット（B_WORK）は `4a5c133f60d1ecc42b0bdbdb32f5196dcad06465`。開始時の差分はない。コミットとdocs/todoの変更は行わない。

## 変更

PropertyのShrinkerをShrinkStepへ接続し、maxShrinkWork・shrinkWork・libraryVersion 2.0.0を公開した。初回・続き・候補propertyの呼び出しを直前に一度数え、二つの予算・既知/不明のDone・Error後の累積と再開を末尾呼び出しで駆動する。旧collectSteps/listSteps/elementStepperは撤去した。

生成テンプレートは各欄のmapSteps/appendStepsと遅らせたfactory/candidatesへ移し、Propertyテンプレートの版を2にした。手書きの利用例、英語リファレンス・Skill、03-06・06-04・07-04を更新した。形式化の規則・定理・仮定・GC/VMは変えない。

## test-auditの作成時の四問

1. 本物のpipeline/VMと生成道具の管理境界で、既存候補順・二つの予算・呼び出し回数・再開後の累積・公開APIの互換性拒否・生成factoryの遅延と管理記録の一致を観察する。
2. 生成/比較/propertyの二重計数や無計数、Doneの確認呼び出し、未試行候補の採用、再開時のリセット、次の欄のfactoryの先行評価、全量収集、古い記録の黙認で失敗する。呼ばれないべき続き/factoryは0除算で停止する純粋な関数として観察する。
3. 候補順・InvalidConfig・反例・純粋性は既存テストのassertを保って入力と必要な期待を移す。新しいwork予算の境界・旧契約拒否・上限駆動と、生成factoryの評価時点だけを新しいテストとする。同梱例の主張はR124に従い、G1〜G3のmigration_requiredからG4の新版check成功・空diffへ戻す。旧記録拒否自体は独立した一時プロジェクトの既存の移行テストに残す。
4. テスト用の公開口・フラグ・内部注入は足さない。既存の候補順の期待はテスト側の末尾再帰の消費関数でShrinkStepから観察し、本番へ全Listアダプタを残さない。生成コードも通常のcheck/testへ渡す。

## 検査

作業途中の関係テストを直接実行した。新しいテスト入力で外側のvalueを隠すE0338と、引数名を変えたE0454を直した。反例8→4の累積作業量は、候補property5回と初回/続き6回の計11であるため、手計算の期待12を11へ訂正した。旧Listの最後の候補と上限が一致する期待はR175に従って変更し、候補数・反例と説明は保った。既存assertの削除・緩和・既存テストのignore化はない。

- property_libraryの既存12件（深い合成以外）の局所確認: 終了0、12件成功（0.79秒）。
- work予算の境界テストと旧API拒否: 修正後に各終了0（それぞれ1件、0.17秒）。
- `cargo test -p benitoite --test property_library maximum_work_budget -- --ignored`: 終了0、1件成功（60.53秒）。上限1,000,000の合成したSkip列でスタックを溢れさせず正確に打ち切った。10秒を超える新規テストなのでlongに分類し、最終changeのlong_onlyへ引き継ぐ。
- `python3 -B tools/derive/test_derive.py PropertyGeneration.test_field_order_state_size_custom_functions_and_one_field_shrinks PropertyGeneration.test_property_only_nested_option_private_record_and_custom_unsupported_field PropertyGeneration.test_generated_shrinker_defers_later_factories_and_continuations`: 終了0、3件成功（4.491秒）。

上の時間はテスト部分の表示であり、局所の外側の時間は未計測である。編集としてのcargo fmt、benitoite fmtによる標準ソースの整形とgen_skillによる生成は終了0。

作業末の指定検査はdry-runで選択を確認し、次を一度ずつ実行した。外側の時間は/usr/bin/time -pで計った。

| コマンド | 終了 | 外側の時間 | 結果 |
|---|---|---|---|
| `scripts/check.sh --level work --base 4a5c133f60d1ecc42b0bdbdb32f5196dcad06465 --test '*' --dry-run` | 0 | 未計測（1秒未満） | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftestsを選択 |
| 上と同じwork（--dry-runなし） | 0 | 421.62秒 | lib 1211件成功・既存ignore 21件。39統合ターゲットは296件成功・ignore 8件（従来7件と新規long 1件）。fmt・通常clippy・規約・生成Skill・仕様集計・Python構文・二つの移行自己検査も成功 |
| `cargo clippy --all-targets` | 0 | 12.86秒 | exampleを含む全ターゲットのlint成功 |
| `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | 0.68秒 | 最終のexample/CLIをビルド |
| `python3 -B tools/derive/test_derive.py` | 0 | 61.72秒 | 全34件成功。旧記録・旧manifest・本文改変拒否・再適用・復旧と通常check/testを含む |
| `target/debug/benitoite check tools/derive/examples/People.bnt` | 0 | 0.64秒 | 通常の型・エフェクト検査成功 |
| `target/debug/benitoite test tools/derive/examples/People.bnt` | 0 | 1.04秒 | 通常テスト2件成功 |
| `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 0 | 0.58秒 | 新版の本文・記録・設定と一致 |

生成例と記録の新版check成功・次previewの差分空という主張へ戻した。G1〜G3の過渡期のmigration_requiredという主張は同梱例から取り除き、旧記録に対する拒否は独立した移行テストに保った。stage5の四統合ターゲットはworkの全統合に含まれる。stageの実行または引用の判断は取りまとめへ渡す。

workが実行したRustの検査は `cargo test -p benitoite --lib`、`cargo test -p benitoite --test '*'`、`cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`、`cargo fmt --all --check` である。Propertyの通常15件は7.96秒で成功し、新規のlong 1件は局所で実行済みである。source-migrateとtry-actions-migrateの自己検査は各6件成功した。本検査枠の外側の時間の計は499.14秒。workの再実行はなく、完了後は本結果の記録と、06-04の「私有のShrinkStep」を「私有の補助関数で公開のShrinkStepを作る」へ直す用語の修正だけを行った。公開済みの型と私有の補助関数を区別する文章の修正であり、入力コード・仕様の規則・生成物は変えていない。git diff --checkも終了0。formal/に触れていないためlake buildを加えず、gc-stress・全体all-targets・change・全形式化比較・releaseは実行していない。

テストは削除していない。新規テストはproperty_libraryに3件（うち上限駆動のlong 1件）、deriveに1件である。本番Property.bntは45行追加・51行削除、生成テンプレートのderive.pyは15行追加・12行削除。property_library.rsは190行追加・36行削除、test_command.rsは2行追加・2行削除、test_derive.pyは63行追加・9行削除であり、既存の候補順と値の期待は維持した。

## 計画との差と申し送り

開始版と具体化をR175に記録した。性能の本測定・change・全形式化比較・releaseは取りまとめへ残す。推奨maxShrinkWork=10000を本測定で確定したとは扱わない。日本語訳はV1へ残す。

## 生成差分の確認

旧管理領域のbytesは旧記録のoutputSha256に一致し、新previewが両領域を受理した。同梱例を複写し、Configの必須欄・領域外のTrait import・Show/Orderの選択を準備した一時プロジェクト `/private/tmp/benitoite-g4-migration` で作ったmanifestのSHA-256は `0cfd5111be2bd3091689623ebbb763ca51ffe8942b2ecc1b39d53f5de241d547`。同じハッシュを指定したapplyは終了0（2ソース）、通常testは2件成功し、derive checkも終了0であった。具体的な生成差分は[migration.diff](migration.diff)、版2の生成記録は[migration-record.json](migration-record.json)に保存する。G4の依頼範囲に含まれる同梱例の移行として、具体的な差分・版2の記録と上のハッシュを照合し、hash指定applyが作ったPeople.bnt・Address.bnt・設定・記録をそのまま同梱例へ反映した。追加確認の質問を一度出したが、当初のG4実装依頼に移行が含まれるため追加の承認待ちを取り消し、既存の依頼に基づいて進めた。一般の利用者ファイルへの承認の代用にはしない。

## R130の件数集約への申し送り

標準Test/Property.bntの関数定義は50から49（公開21は不変）、型定義6は不変である。私有collectSteps・listSteps・elementStepperを撤去し、advance・budgetReachedを追加した。reduce・tryCandidates・七つの公開縮小器と私有mapShrinkerを新契約へ接続した。ConfigにmaxShrinkWork、Counterexampleにshrinksの直後のshrinkWorkを追加し、公開Shrinker.candidatesの戻り型を変えた。

同梱例はPersonのShow一メソッド、AddressのShow/Order二メソッドと、欄を進める私有関数をPersonに6件、Addressに1件追加する差分である。生成例の関数本体の合計は27から37となり、設定はPersonにshow、Addressにshow/orderを追加する。新しいgoldenの固定入力は追加しない。交換manifestとrouting-manifestは変更せず、最終候補の標準ソースと生成例からの定義・脱糖・表層・網羅性・対象外の実数は取りまとめが再集計する。宣言数をcorpusごとの出現件数へそのまま写さない。

## 完了と後の作業

G4の実装と指定検査を完了した。同梱例・設定・新版記録は同じ移行結果となり、通常check/test・derive checkと次previewの空diffが一致した。stage5の四対象はworkの全統合で確認済みであるが、別状態への結果の引用を本記録だけで承認したとは扱わない。取りまとめは必要な証拠欄をそろえて引用するか、計画のstage5を実行する。上限駆動は最終changeのlong_onlyでも対象になる。V1の訳と最終の版合わせ、R130の二manifestの最終集約、本測定・全形式化比較・change/releaseを引き継ぐ。
