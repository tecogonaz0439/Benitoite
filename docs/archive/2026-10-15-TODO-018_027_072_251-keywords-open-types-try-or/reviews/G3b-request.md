# G3b・G3 全体のレビュー用の照合

## 対象と前提

対象は D7〜D9 と G3a の修正を含む段 2 D である。D9 開始時の HEAD は `47fab7e777272e6a33ceb553fe6b1c33d65683f8` である。本書は自己確認とレビューの依頼材料であり、外部レビューの完了を示さない。

G3a の指摘と対応は [G3a-report.md](G3a-report.md)、定義・言明の先行レビューは [G2-report.md](G2-report.md) と [Z2-check.md](Z2-check.md) に残している。D9 ではエージェントや外部の LLM を起動しない。

## 差分と検査の対応

| 確認する契約 | 実装・主となる検査と記録 |
|---|---|
| 四つの失敗型だけを指定し、Result・Option を閉じたままにする | 四つの stdlib 宣言、skill_docs、型検査の標準型の拒否、交換形式の破損入力。[D7](../d7/results.md)、G3a の R44 |
| 属性を受理した時点から所属と view を判定へ使う | parser の属性の表、pattern_ext のソースの表、coverage_export・desugar_export、六入口。[D6c](../d6c/results.md) |
| 別名・ジェネリックな型引数・入れ子・同パッケージの別モジュール・bind | pattern_ext の表と D8 の package golden。[D8](../d8/results.md)、G3a の R45 |
| 将来の形を覆う分岐を下流へ渡し、既知の値の出力を保つ | d8-extensible-run の十一行の出力、Direct/Request・VM/参照インタプリタ・desugarDiff。data の変数分岐と record の `_` 分岐を含む |
| record の構築・更新・getter と外部での保守的な分解制限 | l21_json・l23_csv、D8 の golden、D9 の英語リファレンスの実行例。R2 の欄の追加の互換性は保証しない |
| 宣言の表示と診断 | Skill の四型の宣言出力、E0601/E0607 の文章/JSON golden。反例・宣言の副位置・help を厳密に比較。R43 の E0607 の match への書き換えの案内を文書にも反映 |
| 形式化と処理系の接続 | corpus 9・型表 3・網羅性 3。六入口と二つの manifest を照合し、既存入力の識別子・診断列・対象内件数・対象外理由を保持 |
| 文書と互換性 | 01-05・03-10・用語集・06-06・07-04、英語リファレンスと Skill。属性の導入・除去、Other の再分類、構成子削除・改名・欄の変更、WIT の別契約を説明 |

## 段末の結果と残る関門

D9 の具体的なコマンド・結果・六入口の件数・manifest のハッシュは [D9 の作業記録](../d9/results.md) に記す。既存の assert の削除、期待値の緩和、ignore の追加、対象内件数の下方修正はしない。

今回の依頼により、check.sh（dry-run を含む）と gc-stress はオーケストレータの最終検査へ引き継ぐ。G3b の外部レビューと G3 全体の取り込み判断もオーケストレータが行う。版・E0908・CHANGELOG の公開用の移行案内・日本語訳の最終照合は計画の M の担当とする。B の未実装の try の処置を現行の文書へ加えない。
