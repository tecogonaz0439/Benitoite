# U03R の結果

着手: 2026-10-27 09:25:21 JST。終了: 2026-10-27 09:33:08 JST。所要時間: 7分47秒。着手時刻は最初の時刻付き点検による。

## 基準と範囲

B_WORK と着手時の HEAD は `56af9133e2a354770ac8d0dcd1c41a685cd02966`、ブランチは `mod012/U03R`。着手時の差分はなかった。git は読み取りの照会だけを行い、変更操作はしていない。private/ とそこを指すリンクは読んでいない。サブエージェントは使用していない。

AGENTS.md、共通依頼文、plan.md の前提・受け渡す契約・U03R の表と U 群の検査割り当て、decisions.md、RV-U と取りまとめの対応表、U01 の警告記録、U01b・U02a・U02b・U03a・U03b の結果、テスト補助と pipeline の on_large_stack を確認した。文書には japanese-tech-writing、テスト補助には test-audit、コマンドの出力整理には rtk を適用した。

## 修正と追加測定

| 所見 | 対応 |
|---|---|
| 軽1 coverage | 英語リファレンス・inspection.md・06-01・02-05 を修正。本体なしは件数0の all、本体が一つ以上あり全て型検査で無効なら none、有効・無効の混在なら some と明記した |
| 軽2 比較の範囲 | 英語リファレンスと02-05に、一部の有限入力の比較であり return の返す区間など未比較の結果があることを明記した |
| 軽3 型の正名・別名 | 01-04 を UnsignedInteger8（別名 Byte）と二つのモジュールの説明へ直した |
| 軽4 スタック | cfg(test) の interval_inventory.rs だけを変更。独自のスレッド作成を既存の on_large_stack へ置き換え、本番の段と同じスタックで check_stages を呼ぶ目的をコメントした |
| 軽5 HTTP と一次位置 | idioms.md の HTTP の節は使い方から始め、注意と例を Explaining local interval warnings の HTTP values are not tracked 小節へ移した。元の節の末尾から一文で案内し、W0404 の一次位置を引数の式 n と書いた |
| 軽6 phaseStops | 英語リファレンスに別本体制御と検査全体の停止を明記した |
| 軽7 消費と訳 | U02b・U03a の追加4例を既存の観測入口で測定し、u01/warnings.md に追記した。訳の一覧がU02bの全節を既に含むことを照合し、U03Rの英語変更3文書・10ブロックを集約の「訳の引き渡し」に追加した |
| 02-10 の既存の別名表記 | Integer と UnsignedInteger の別名にそろえた |

追加4入口・4 Target・8本体の最大は本体254操作・51項目、検査全体376操作・73項目で、上限到達・番号未取得・深さ停止・ほかの段停止は全て0件だった。[入力一覧](inputs.json)・[生の観測](observations.jsonl)・[集計](consumption.json)・[収集器](collect.py)に本文と根拠を残した。通常の pipeline と観測ありの型検査の集計は全欄一致した。測定ではスクリプトと利用者テストを実行していない。

U01 の旧一覧や数値は変更せず、追加4例を別測定にした。コード例の本文も移動以外は変えていない。言語の規則・Lean・本番の Rust の経路・予算の定数は変えていない。

## 作業末の検査

検査前に種類を報告し、同じ基準・指定の dry-run の後に work を一度実行した。plan の U03R の行とユーザーの補足に従い、自動の Rust work に関係する統合ターゲットを指定した。U03a/b の文書だけの名指し指定は使わず、既定 lib・clippy・fmt・ソース規約も含める。文書例を tests_related で通すため、spec_examples と reference_examples の独立単位は実行器が重複を省く。

```sh
scripts/check.sh --level work --base 56af9133e2a354770ac8d0dcd1c41a685cd02966 --test reference_examples --test skill_examples --test skill_docs --test spec_examples --test stdlib_doc_examples --dry-run
scripts/check.sh --level work --base 56af9133e2a354770ac8d0dcd1c41a685cd02966 --test reference_examples --test skill_examples --test skill_docs --test spec_examples --test stdlib_doc_examples
```

実行場所は `<repo>`、Cargo は `CARGO_HOME=<tmp>/benitoite-a01a-cargo`、既定構成である。clippy は実行器が gc-mark-sweep 構成で lib/tests/examples を検査する。[run.py](run.py)で出力のパスを伏せ、検査本体の終了と外側の `/usr/bin/time -l` の終了を分けて記録した。dry-run は終了0、外側0.087秒で、選択と理由は [dry-run.log](dry-run.log)に保存した。

本検査の本体は **終了0、136.541秒**、計時を含む外側は **136.567秒**だった（time 表示: real 136.56秒・user 559.22秒・sys 28.46秒）。[本検査のログ](work.log)・[本体の終了と時間](work.json)・[計時ログ](work-time.log)・[外側の終了と時間](work-time.json)に保存した。

| 検査 | 結果 |
|---|---|
| fmt | 成功 |
| clippy（lib/tests/examples、gc-mark-sweep） | 成功 |
| 既定 lib 全件 | 1,333件成功・失敗0・既存 ignored 21件。interval_inventory の既定3入力も含む |
| 英語リファレンスの例 reference_examples | 1件成功 |
| Skill 文書 skill_docs | 8件成功 |
| Skill の手書き例 skill_examples | 3件成功 |
| 仕様例 spec_examples | 7件成功 |
| 標準ソースの文書例 stdlib_doc_examples | 1件成功 |
| ソース規約 source_rules | allow・unsafe の規約とも成功 |
| 生成物の再生成照合 skill_generated | 成功。gen_skill を実行し、生成参照と bundle は B_WORK から差分なし。生成物は手で編集していない |
| 仕様対応集計 spec_tally | 自己検査・集計が成功。未参照節の一覧を表示し、未記入の初回リリース完了条件は0件 |

work の7単位は全て成功し、テストは合計 **1,353件成功・失敗0・既存 ignored 21件**だった。関係する統合ターゲットは5件・20テストである。局所の4例の消費取得の1テストはこの件数に重ねて足していない。検査の失敗・再実行・期待値の変更はない。

最大常駐量（maximum resident set size）は **取得できなかった**。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告したためである。計時側の終了1と検査本体の終了0を別に保存し、計時の取得不能を検査の失敗や常駐量0とは扱わない。Lean のビルド・単一ファイル検査・全比較、stage・change・release は実行していない。

## 自己点検と申し送り

[static-check.json](static-check.json)に、変更した公開7文書のコード例の本文が移動を含めて一致すること、既存見出しを消していないこと、リンクの制約、新しい HTTP のアンカー、追加4例のB_WORKとの一致を記録した。公開の文書から docs/todo・private/ へのリンク、英語から日本語の設計書へのリンクは追加していない。

test-audit の作成時の関門では、既存テストの通常の pipeline と観測付き型検査の集計一致という契約を維持した。現実的な退行は観測による消費の変更と、拒否時の有効な本体の取りこぼしであり、既存の持ち主のテストを残す。新しい重複テスト・公開入口・フラグ・テストダブルは足していない。本番の Rust は追加0・削除0行、テスト専用 Rust は追加3・削除6行。期待値・入力の大きさ・ignore・上限を緩めていない。

U03b の翻訳記録18ファイル・118項目は過去の状態として維持し、本改造 results.md の「訳の引き渡し」にU03Rの差分を重ねた。[追加の原文一覧](translation-inventory.json)は現在の原文とハッシュを保存し、移動先も示す。Z01a は訳を同期し、Z01b は候補の版・生成物・同梱物と照合する。

独立レビューと受け入れ、G01 の改造全体の回帰、Z01 の候補検査、コミットと取り込みは取りまとめと後続担当の範囲である。言語規則や Lean の主な定理の前提・結論、公理を変更する判断は不要だった。


## 最終照合と計画との差

work の後は記録だけを更新し、[検査入力のハッシュ](checked-inputs.json)に保存したテスト補助と公開文書が変わっていないこと、生成参照と bundle に差分がないことを確認した。`git diff --check` は終了0。保存記録の手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せ、各記録は1 MB未満である。

U03R の対応表の範囲と指定した検査を完了した。独立レビュー・受け入れをこの自己点検で済ませたとは扱わない。計画との差はなく、担当範囲の未完や停止条件に当たる判断はない。最大常駐量の取得不能だけを環境の制限として引き渡す。

## 取りまとめのレビュー（2026-10-27）

受け入れる。差分を読み、coverage の三つの場合を `typeck/interval/summary.rs` の `Report::summary` と照らした（無効な本体は `Coverage::None` の本体として残り、有効な本体と混じれば未完として `some`、有効な入力が0で無効な本体があれば `none`、本体がなければ件数0の `all`）。`interval_inventory.rs` は `on_large_stack` へ替わり、規約の例外の一覧の外のスタックの指定はなくなった。HTTP の注意は局所警告の小節へ移り、元の位置からリンクで指す。RV-U の軽1〜軽7 はこれで閉じる。
