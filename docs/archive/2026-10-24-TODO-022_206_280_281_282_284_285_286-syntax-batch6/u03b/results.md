# U03b の結果

着手: 2026-10-27 05:20:10 JST。終了: 2026-10-27 05:25:53 JST。所要時間: 5分43秒。着手時刻は最初の時刻付き点検の記録である。

## 基準と変更

B_WORK と着手時の HEAD は `89c7a777c664bc0cd5b728019f0ce983bda4c0cf`、ブランチは `mod012/U03b`。着手時の作業ツリーに差分はなかった。git の操作は status・diff・show・rev-parse・branch の読み取りの照会だけであり、変更操作はしていない。private/ とそこを指すリンクは読んでいない。サブエージェントは使用していない。

U03 の共通範囲と U03b の行、前提・受け渡す契約・検査の割り当て、D9/D12/D21/D22 と後の訂正、study の7.2・9.4、U03a/U02a/U02b の結果と集約の「U03 の前の short」を読んだ。言語の規則、Lean の主な定理の前提・結論、公理を変更する判断は不要だった。

| 対象 | 結果 |
|---|---|
| Skill の生成参照 | `cargo run -p benitoite --example gen_skill` を実行した。文法・診断・標準ライブラリの66参照と bundle を再生成し、B_WORK から差分がないことを確認した。生成物は手で編集していない |
| `docs/reference/install.md` | 変更なし。導入・更新・Skill の取得方法・ハーネスが検査報告から実行へ進む手順はこの改造で変わっておらず、追加説明は既存リンク先の英語リファレンスと Skill にある。過去の移行節は保ち、0.0.12 の版表記・移行案内は Z01a/Z01b がそろえる |
| 本改造の `results.md` | U03b の引き渡しと「訳の引き渡し」を追記した。改造開始版からの英語の変更18ファイル（手書き4、生成14）、118項目を列挙し、行番号・見出し・段落の冒頭を付けた |
| [translation-inventory.json](translation-inventory.json) | 各項目の原文、変更行、ファイルとブロックの SHA-256、B0 と B_WORK、変更前後の範囲を保存した。段落だけでなく表・箇条書き・見出し・コードと期待出力を含む。Z01a は手書き文書の4つの既存訳へ同期する。生成参照には現存する対応訳がないため、原文照合の対象として全て列挙した |

今回の一覧は U02b/U03a だけに限定せず、前段の Log.formatRecord・開いた Writer/JSON の例・derive の現行案内・R0906 の取っ手上限・生成されたシフトと Range の参照も含む。install.md・grammar.md・stdlib/index.md など差分のない文書も明示した。日本語訳そのものは Z01a の担当であり、Skill の同梱物へ訳を入れていない。

## 検査

U03b の指定6単位を一度実行し、その前に同じ基準・指定の dry-run を通した。

```sh
scripts/check.sh --level work --base 89c7a777c664bc0cd5b728019f0ce983bda4c0cf --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples --dry-run
scripts/check.sh --level work --base 89c7a777c664bc0cd5b728019f0ce983bda4c0cf --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples
```

選択と理由は [dry-run.log](dry-run.log)、dry-run の終了と時間は [dry-run-status.json](dry-run-status.json)、本実行の出力は [work.log](work.log)、検査本体の終了と時間は [work-check-status.json](work-check-status.json)、計時側の終了と外側の時間は [work-status.json](work-status.json)に保存した。dry-run は終了0、本検査の本体も終了0（selected checks passed）だった。

| 検査 | 結果 |
|---|---|
| Skill の手書き例 `skill_examples` | 3件成功。既存の文書例実行器を経由した |
| 標準ソースの文書例 `stdlib_doc_examples` | 1件成功 |
| Skill の生成と鮮度 `skill_generated` | 成功。生成器の再実行による差分なし |
| 仕様との対応集計 `spec_tally` | 自己検査と集計が成功。未参照節の一覧を表示し、未記入の初回リリース完了条件は0件 |
| 仕様例 `spec_examples` | 7件成功 |
| 英語参照例 `reference_examples` | 1件成功 |
| Skill 文書 `skill_docs` | 8件成功 |

対象テストは合計20件成功、失敗・ignored・除外は0件。生成元は変えていないため、追加の生成照合は work の skill_generated に任せた。Rust の全 lib・clippy・fmt、Lean のビルド・全比較、段・change・release は今回の文書の指定範囲に足していない。

本検査を `/usr/bin/time -l` で包み、薄い Python の実行器で検査本体の終了と時間も別に保存した。検査本体は23.637秒、計時を含む外側は23.664秒（time 表示: real 23.66秒・user 23.88秒・sys 3.26秒）だった。最大常駐量（maximum resident set size）は取得できなかった。time が `sysctl kern.clockrate: Operation not permitted` を報告したためである。計時側の終了1と検査本体の終了0を区別し、検査失敗として数えていない。

## 自己点検と short の扱い

[static-check.json](static-check.json)に、一覧の全変更行・原文・SHA-256・文書の件数、相対リンクと版付き英語参照の見出し、公開英語文書のリンク制約、手元の絶対パスの伏せ、処理系と英語文書に B_WORK から差分がないこと、`git diff --check` の結果を記録した。

一覧の自己点検の初回では、原文の目次行を抜粋した表の中のリンクが、集約文書自身のリンクとして解釈されることを検出した。原文照合用の抜粋をインラインコードで囲み、目次の元の文字列を示す形へ直して再確認した。英語原文や検査入力の修正はなく、成功した work を反復する必要はなかった。続く自己点検では保存前の static-check.json 自身へのリンクの確認が先行したため停止した。結果ファイルの保存順を直して全項目の照合を通した。

新しい英語参照は v0.0.12 のタグを指す。現在の本文に Interval analysis coverage と Local interval warnings の見出しがあることを確認した。既存の必須欄と受け入れ規則を参照する v0.0.11 は、ローカルの同タグの英語リファレンスに Inspection reports があることを確認した。将来の v0.0.12 タグの公開・到達性を確認済みとは扱わず、Z01b の候補照合へ渡す。英語から日本語の設計書・docs/todo・private/ へのリンク、中間コミットへの参照はない。

処理系の経路・標準ソース・依存・生成器・bundle・Lean に変更はなく、最終差分は引き渡しと結果の記録だけである。集約の「U03 の前の short」で取りまとめが済ませた最後の short の判断に、処理系の変更を追加していない。この枝では測定していない。以前の測定や Lean の全比較を、新しく実行した記録として引用していない。

## 計画との差と申し送り

U03b の生成・導入文書の必要性の確認・訳の引き渡し・指定検査を完了した。計画の範囲・検査指定の追加や省略はない。ユーザーの補足どおり、U01〜U03 の全体レビューは取りまとめが別に行う。自己点検だけでそのレビューや改造全体の受け入れを閉じていない。

Z01a は集約の「訳の引き渡し」の18ファイル・118項目と inventory を使って訳を同期し、Z01b は版上げ後の英語・訳・生成物・同梱 Skill・参照タグの見出しを照合する。G01 の change、Z01b の K2/release、return の区間・外部型などの後の課題の登録、独立レビューと受け入れは計画どおり取りまとめと後続の担当に残す。コミット・取り込み・docs/todo の更新・保管・タグ・公開の操作は行っていない。

## 取りまとめのレビュー（2026-10-27）

受け入れる。生成参照と bundle に差分がないこと、install.md を変えない理由、訳の引き渡しの18ファイル・118項目と translation-inventory.json の対応を確かめた。0.0.12 の版表記と訳の同期は Z01a・Z01b で行う。RV-U の軽7（英語リファレンスの訳の対象の一覧）の補いは U03R で行い、この一覧へ足す。
