# U02a の結果

着手: 2026-10-27 04:44:55 JST。終了: 2026-10-27 04:53:37 JST。所要時間: 8分42秒。

## 基準と変更

B_WORK と着手時の HEAD は `5a1d90a38ae4a053f216205040f14b98eff6bb76`、ブランチは `mod012/U02a`。着手時の作業ツリーに差分はなかった。git の読み取りの照会だけを行い、変更操作はしていない。private/ とそこを指すスキルのリンクは読んでいない。

| 章 | 変更 |
|---|---|
| 00-04 | 区間解析と原語 function summary を一般の言語処理系の語として追加した。「対象構文の評価関係」の既存行は選択済みの表記と定義を保った |
| 01-04 | W0404 を許可の規範へ加え、全引数の正常値とシフト量の非空の区間全体が定義域外である条件を明記した。Byte・別名・純粋なシフトの対象を示した。定数式の既存警告と E0435 の条件を局所解析から区別した |
| 02-05 | 解析の範囲と保証、Top/Bottom、局所性・予算・strict の扱い、用語の出典をまとめた。Range の function summary と直接の value の区間を明確にし、Http.text/html/json と明示した HTTP の欄を追わない現在の境界を記した |
| 03-06 | Range の function summary と用語の原語をそろえ、実 VM 比較が未完という古い説明を現在の有限の比較範囲と限界へ改めた |
| 07-04 | A1 の基準と用語の出典を加え、信頼する評価規則を Range と純粋なシフトに具体化した。X05T の return の区間と外部型の未比較範囲・件数・受け入れ条件は保った |

D2〜D8・D18・D21、D4 の変更と D15・D19 の追記、設計者の用語の選択、RV-C4/RV-X05 の対応、study の指定節と U01 の棚卸しに従った。01-04 の幅付き整数の標準関数の定数警告は、B_WORK ですでに訂正されていたため、その規範を保った。

用語の一次資料は2026-10-27に本文を確認した Cousot の Abstract Interpretation §4.2、関口の論文 §3.1（印刷頁38）、angr の Symbolic Function Summaries、Software Foundations の Imp: Evaluation as a Relation を使い、02-05 と07-04に出典を置いた。新しい訳語の判断は加えていない。

## 検査

指定の名指しの部分選択を一度実行した。事前の dry-run と本実行の基準・単位・統合ターゲットは同じである。

```sh
scripts/check.sh --level work --base 5a1d90a38ae4a053f216205040f14b98eff6bb76 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples --dry-run
scripts/check.sh --level work --base 5a1d90a38ae4a053f216205040f14b98eff6bb76 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples
```

本実行は `/usr/bin/time -l` の内側で実行した。検査本体の終了と計時の終了を区別できるよう、薄い Python の実行器で検査本体の終了状態も保存した。dry-run の選択と理由は [dry-run.log](dry-run.log)、本実行の出力は [work.log](work.log)、終了と外側の経過時間は [work-status.json](work-status.json)に記す。

dry-run は終了0。本実行の検査本体も終了0（selected checks passed）だった。薄い実行器と計時を含む外側の実測は75.045秒、time の表示は real 75.04秒・user 422.26秒・sys 18.89秒だった。

| 検査 | 結果 |
|---|---|
| Skill の手書き例 `skill_examples` | 3件成功 |
| 標準ソースの文書例 `stdlib_doc_examples` | 1件成功 |
| Skill の生成と鮮度 `skill_generated` | 成功。生成対象の追跡ファイルに差分なし |
| 仕様との対応集計 `spec_tally` | 自己検査と集計が成功。仕様節の未参照一覧を表示し、未記入の初回リリース完了条件は0件 |
| 仕様例 `spec_examples` | 7件成功 |
| 英語参照例 `reference_examples` | 1件成功 |
| Skill 文書 `skill_docs` | 8件成功 |

選択したテストは合計20件成功、失敗・ignored・除外は0件。初回の依存と対象のビルドは53.74秒だった。名指しした六単位の成功であり、work の全単位・change・release の完了とは区別する。

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告したためである。計時の終了は1、検査本体は0であり、検査の失敗や成功0件とは扱わない。実行ログと終了状態を分けて保存した。

最終照合では、追跡ファイルの差分が対象5章だけであること、生成物に差分がないこと、X05T の return と外部型の比較の限界の二段落が B_WORK から変わっていないことも確認した。

5章の自己点検では、既存の見出しの改名・削除とコードフェンスの変更がないこと、相対リンクの参照先と追加したアンカー、docs/todo・private/ へのリンクがないことを確認した（[static-check.json](static-check.json)）。git grep で01-04の spec 印と既存見出しの参照を検索した。新しい見出しは02-05の「区間解析の範囲と保証」だけであり、既存の spec 印や生成器の参照を変更する必要はなかった。自己点検で追加リンクの「初回リリース版」の欠落を検出して修正した。リンク抽出器は既存の記法の例 `[...] (...)` の省略記号を実リンクとして数えないようにして再確認した。`git diff --check` は終了0だった。

## 計画との差と申し送り

計画の対象5章と指定の検査の範囲内で作業した。処理系・Lean・テスト・コード例・生成元は変更していない。生成物の再生成と鮮度の照合は指定の skill_generated に任せた。Lean のビルドと全比較を新たに実行した記録としては扱わない。

言語の規則、Lean の定理の前提・結論、公理の追加判断は要らなかった。return の返す区間、外部型、HTTP の欄の追跡を実装済みの保証には加えていない。return と外部型の未比較、操作と HTTP の欄に関する後の課題の docs/todo への引き継ぎは、依頼どおり取りまとめの担当に残す。

U02b は本変更の用語と警告の範囲を使い、02-10・06-01・06-04・06-06 と英語参照をそろえる。独立レビューと受け入れは取りまとめが行う。本記録は U02a の指定した検査の結果であり、改造全体の受け入れを完了した記録ではない。

## 取りまとめのレビュー（2026-10-27）

受け入れる。設計者が選んだ二語（function summary、対象構文の評価関係（evaluation relation for the target fragment））を用語集・02-05・03-06・07-04にそろえた。01-04 の W0404 は D4 の変更（シフトの直接引数だけ、操作と HTTP の欄を除く）の後の実装と一致し、除く理由を 01-07 のハンドラへの参照で示している。E0435 の書き換え（定数の評価が実際に失敗したときだけ）は 02-05 の定数の評価器の記述と一致する。`return` の区間・外部型の未比較は X05T の 07-04 の記述を保ち、未実装の機能を設計書に書いていない。
