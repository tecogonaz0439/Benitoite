# U02b の結果

着手: 2026-10-27 04:54:51 JST。終了: 2026-10-27 05:03:53 JST。所要時間: 9分2秒。

## 基準と変更

B_WORK と着手時の HEAD は `8cff73ac4139560f8af6876d887151ecadb8ad27`、ブランチは `mod012/U02b`。着手時の作業ツリーに差分はなかった。git は読み取りの照会だけを行い、変更操作はしていない。private/ とそこを指すスキルのリンクは読んでいない。test-audit のリンク先が公開の `.claude/skills/test-audit` であることを確認してから、そのスキルを読んだ。

| ファイル | 変更 |
|---|---|
| `docs/design/02-impl/02-10-diagnostics.md` | 用語の初出を用語集にそろえ、局所警告の条件付きの意味と未知・予算超過の扱いを補った。証明と有限の比較の限界を07-04へ参照し、coverageが報告の受け入れや警告の網羅性を意味しないことを明記した |
| `docs/design/06-tooling/06-01-cli.md` | 追加欄を解釈しない受け手にも既存の受け入れ条件を適用することと、allが失敗の全検出を意味しないことを明確にした。解析の保証を02-05へ参照した |
| `docs/design/06-tooling/06-04-test-runner.md` | docのcheck/error例の解析集計と実行のエフェクト集計を区別した。completeとcoverageの独立、および既存の受け入れ条件を明記した |
| `docs/design/06-tooling/06-06-agent-skills.md` | ハーネスが局所警告を条件付きの失敗として説明すること、W0404はシフトだけであること、未知・未対応・超過だけを修正や契約変更の理由にしないことを補った |
| `docs/reference/benitoite.md` | intervalAnalysisの欄と集約、coverageと受け入れの区別、局所性・予算・W0401/W0402/W0404・形式化の限界を説明した。Rangeのfunction summaryを追記し、Http.text/html/jsonと明示したHTTPのレコード構築・局所保存・更新の欄を追わない例を加えた |

D2〜D8・D18・D21と設計者が選んだ二語、D4の変更とD15・D19の追記、RV-C4/RV-X05の対応、studyの指定節、U01の警告・strict・消費の棚卸し、U02aの5章と結果に合わせた。HTTPの欄の追跡を実装済みとは書いていない。07-04は変更せず、X05Tが明記したreturnの返す区間と外部型の未比較の限界を、全プログラムの意味保存の保証へ広げていない。01-spec・処理系・Lean・テスト実行器・生成元・生成物は変更していない。

## 検査

計画のU02b行の名指しの部分選択を一度実行し、同じ指定のdry-runを先に通した。具体的な選択と理由は [dry-run.log](dry-run.log)、実行結果は [work.log](work.log)、検査本体の終了は [work-check-status.json](work-check-status.json)、計時側の終了と外側の時間は [work-status.json](work-status.json)に記す。

```sh
scripts/check.sh --level work --base 8cff73ac4139560f8af6876d887151ecadb8ad27 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples --dry-run
scripts/check.sh --level work --base 8cff73ac4139560f8af6876d887151ecadb8ad27 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples
```

初回のdry-runは終了0。本実行は、追加したHTTP例の `Json.Null` が正しくは `Json.Value.Null` であるため、reference_examplesで終了1となった。44例中1例のE0303であり、処理系の不具合や期待値の緩和ではない。標準ソースの宣言で構成子の所属を確認して例を修正した。局所警告の説明の非空条件とRangeの別名・条件環境合流の境界も同じ英語文書で明確にした。

修正後は、古くなったreference_examplesと、初回には未実行だったskill_docsだけを同じ基準で再実行した。成功済みの単位を重ねて実行していない。再試行も先に同じ指定のdry-runを行った。

```sh
scripts/check.sh --level work --base 8cff73ac4139560f8af6876d887151ecadb8ad27 --only reference_examples,skill_docs --dry-run
scripts/check.sh --level work --base 8cff73ac4139560f8af6876d887151ecadb8ad27 --only reference_examples,skill_docs
```

再試行のdry-runと検査本体は終了0。選択は [retry-dry-run.log](retry-dry-run.log)、実行は [retry.log](retry.log)、検査の終了は [retry-check-status.json](retry-check-status.json)、外側の時間は [retry-status.json](retry-status.json)に記す。

| 検査 | 最終の結果 |
|---|---|
| Skillの手書き例 `skill_examples` | 初回で3件成功 |
| 標準ソースのdoc例 `stdlib_doc_examples` | 初回で1件成功 |
| Skillの生成と鮮度 `skill_generated` | 初回で成功。生成対象の追跡ファイルに差分なし |
| 仕様との対応集計 `spec_tally` | 初回で自己検査と集計が成功。未参照の仕様節を表示し、未記入の初回リリース完了条件は0件 |
| 仕様例 `spec_examples` | 初回で7件成功 |
| 英語参照例 `reference_examples` | 再試行で1件成功。実行器が検査する例は43例から44例へ増え、全例が期待どおり |
| Skill文書 `skill_docs` | 再試行で8件成功 |

指定された6単位の確認を、初回の成功4単位と再試行の成功2単位で完了した。テストの最終の成功は合計20件、ignored・除外は0件である。初回の失敗1件は上記の修正後に成功している。名指しした範囲の成功であり、workの全単位・change・releaseの完了とは区別する。

両本実行を `/usr/bin/time -l` で包んだ。検査の終了を薄いPythonの実行器で別に保存した。初回は検査本体22.934秒・終了1、計時を含む外側22.960秒（time表示: real 22.95秒・user 22.62秒・sys 3.10秒）。再試行は検査本体4.113秒・終了0、外側4.138秒（time表示: real 4.13秒・user 4.28秒・sys 0.33秒）だった。

最大常駐量（maximum resident set size）は取得できなかった。両回とも `/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告したためである。計時側の終了は両回1であり、再試行の検査本体の終了0と区別して保存した。Leanのビルドは実行していない。

## 自己点検と例の作成時の関門

[static-check.json](static-check.json)に、5文書の285箇所の相対リンクとアンカー、フェンスの対応、既存見出しの改名・削除がないこと、公開文書にdocs/todo・private/へのリンクがないことを記す。英語文書に加えた見出しは `Interval analysis coverage` と `Local interval warnings` の二つであり、既存の見出しとコード参照を変更する必要はなかった。git grepで02-10・06-01・06-04・06-06のspec印と関係する見出しの参照を確認した。設計書の章の追加・改名・移動はないため、目次は変更していない。

リンクの自己点検の初回は、06-04のインラインコード内の関数型をリンクとして誤抽出した。フェンスとインラインコードを除外して確認し直し、文書のリンクの欠落は0件となった。初回のHTTP例の更新構文も、実行前の自己点検で既存の `Http.Response(..plain, status: 701)` の形へそろえた。最終の `git diff --check` は終了0であり、保存した記録に手元の絶対パスがないことも確認した。

追加例についてtest-auditの四点を確認した。(1) 公開リファレンスのHttp.text/html/jsonと明示レコード・更新の例が、CLIのcheckで誤り・警告を出さず受理されることを守る。(2) 公開名・シグネチャ・構文の変更や、対象外のHTTP欄に診断を出す変更があれば失敗する。(3) 処理系の挙動の主な検査を重ねて作らず、英語文書固有の綴りや例の破損を既存reference_examplesで検出する。(4) 新しい公開入口・フラグ・ラッパー・テストダブルは不要である。追加は静的な文書例一つだけであり、ネットワーク操作を実行しない。Rustの本番コード・テストコードの行数増減はともに0である。

## 計画との差と申し送り

担当する5文書と結果記録の範囲内で作業した。検査の初回の失敗後、英語例と未実行のSkill文書だけを再実行した点を記録した。計画の検査範囲を追加・省略していない。言語の規則、Leanの主な定理の前提・結論、公理を変える判断は要らなかった。

U03aは、ここでそろえた受け入れ規則・局所警告・未知と超過・HTTP補助関数の境界を、SKILL.md・idioms.md・inspection.mdへ反映する。手書きのSkill文書は今回変更していない。U03bの生成物と全体への引き渡し、独立レビューと受け入れは、計画どおり後続担当・取りまとめが行う。returnの返す区間・外部型の交換・操作とHTTP欄の後の課題をdocs/todoへ回す作業も取りまとめに残す。版上げ・訳・公開の操作は行っていない。

## 取りまとめのレビュー（2026-10-27）

受け入れる。`coverage` と既存の `complete`・報告の受け入れ規則の区別、局所の警告の条件付きの意味、予算と未知の扱い、W0404 の範囲（シフトの直接引数、操作と HTTP の欄を除く）が、02-10・06 系の章と英語リファレンスでそろっている。HTTP の欄を追わない例は `benitoite check` の例として検査される。取りまとめが一点を直した: 英語リファレンスから日本語の設計書の章（07-04）へのリンクを外し、文で参照する形にした（英語リファレンスには設計書へのリンクの前例がなく、利用者向けの英語の文書から日本語の内部の文書へ導かないため）。直した後に `cargo test --test reference_examples` を実行し、1件成功（終了0、3.4秒）。
