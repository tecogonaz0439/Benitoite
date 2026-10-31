# RV-L00b.02c: 共有層と既定 import の群末レビュー依頼

2026-10-31。L00b.02c の本番の共有数値層、近似、adapter と既定 import を独立に確認してほしい。実装担当による自己点検とビルド・公理依存の確認は済んだが、独立レビューと受け入れは未実施である。レビューの出力先は `RV-L00b.02c.md` とし、本依頼は所見の記録を兼ねない。

## 基準と境界

- ブランチは起動依頼の `m014/l00b.02c`、B_WORK は `3a41d6c1b8b2922bbd04d89946a7b986bed05286`。直前の取り込みは起動依頼の `45a17a0f` として受け取った。gitの照合・操作は行っていない。
- 正は [implementation-request.md](../implementation-request.md)、[READMEの設計者の決定](../README.md#設計者の決定)、[decisions.md](../decisions.md)、[契約](../l00a.06a/contracts.md)。補助契約の裁量は起動依頼と [signatures第32節](../l00b.02/signatures.md) に従う。
- 主な定理の前提と結論、新公理、提供範囲、利用者の書ける形、精密な外部状態は変えていない。CoreAssumptions・Step/step・既存の型付けは変更0件。
- 新しいReleaseの値・計算・状態の構成子は0である。共有の抽象値等の4/3/1/3構成子を、三族の各71場合とTypedFacts56場合へ加算していない。
- L00b.03、`.04/.05`、L20の全状態保存・進行、作業末のworkは実施していない。workは取りまとめの担当である。
- 処理系・現行設計書・plan・既存レビュー・rv-*の編集はしていない。固定対象4,368件の開始時ハッシュを照合した。

## 読む順と重点

1. [signatures第12・30・31・32節](../l00b.02/signatures.md) と [resultsの今回の節](../l00b.02/results.md)。第31節の義務を今回の証明済みと読まない。
2. Shared.Integer / Shared.Interval / Shared.Approximation。推移importがReleaseの型・項・独立評価を読まないこと、旧の公開名と宣言を保っていること。
3. Interval.TypeAdapter / Domain / ApproxAdapter と Releaseの新旧ApproxAdapter。値域の証拠・幅・other/unknown・三結果・埋め込みの観測の対応を確認する。
4. Benitoite.lean と [import比較](../l00b.02/02c-imports.json)。新旧の既定モジュール、ClosureTyping/StateTyping/LocalResolve/LocalResolveLemmasの到達を確認する。
5. [旧言明14件](../l00b.02/02c-old-statements.lean)、[旧原文のハッシュ](../l00b.02/02c-original-records.json)、[前群の公開型の再出力](../l00b.02/02c-closures-api.log)、[新しい公開型39件](../l00b.02/02c-public-api.md)。原文と80公開型が一致することと、意味の接続がまだ残ることを区別する。

特に、旧FlowApproxが戻り値の情報を持たないため、`toShared flow returned` がその近似を明示引数で受ける契約を確認してほしい。正常の所属は一般補題で移送し、returnedは引数そのものの所属である。戻り値の評価の健全性をこの引数から導いたことにはしていない。旧のInteger64/Boolean以外の正常域のBoolは、falseをbottom、trueをunknownへ写す。範囲外の旧整数定数をotherへ写しても、適格な入力の型付けや閉じた篩の評価を証明したことにはしていない。

## 検査と残る証明

| 検査 | 証拠・結果 |
|---|---|
| 全既定 `cd formal && lake build` | [記録](../l00b.02/02c-build-record.json)、[出力](../l00b.02/02c-build.log)。終了0、683 jobs、148.98秒。増分ビルドで、旧読者の再コンパイルと全8ターゲットを含む。sorryなし |
| 共有層だけのimport | [入力](../l00b.02/02c-shared-imports.lean)。終了0、Release.Syntax/Types/Typing・Interval.Domain/Eval/Flowは読み込まれていない |
| 既定import | [入力](../l00b.02/02c-default-imports.lean)。新旧424モジュールを実importで確認。8既定ターゲットの旧モジュールの脱落0、循環0、旧ReleaseからRefinementへの逆依存0 |
| 旧言明・公開型 | 移設した14定理の原言明を再型検査。閉包群の公開型80件は第4版とバイト単位で一致。新公開型39件も型検査 |
| 境界確認 | [入力](../l00b.02/02c-boundary.lean)、[出力](../l00b.02/02c-boundary.log)。幅・不正な旧定数・normal/returnedの分離・失敗理由・旧Flow・具体値と旧値の対応の6定理。すべて終了0、公理はpropextのみ |
| 本番の公理依存 | [入力](../l00b.02/02c-axioms.lean)、[集計](../l00b.02/02c-axioms-summary.json)。本番109モジュール＋旧7確認対象、12,188宣言。許可はpropext・Quot.sound・Classical.choiceだけ、許可外0 |
| 固定対象・原文・入力 | [検査台本](../l00b.02/02c-validate.py)、[集計](../l00b.02/02c-validation.json)、[最終入力](../l00b.02/02c-inputs-final.json)。本番437入力、既存変更3＋新規7。検査中の変更0。相対リンク等は[最終確認](../l00b.02/02c-final-check.json) |

各Leanプロセスは `-M 12288` を使った。既存のsimp等とリンクの警告はあるが、新規ファイルの警告・sorryはない。100 KBを超える生の記録は `<tmp>` に置き、[large-records.md](../l00b.02/large-records.md)へ大きさとSHA-256を記録した。RSSは未取得（計画上の非採取）。外側の時間は [受け渡し記録](../l00b.02/02c-delivery.json) を参照する。

返送時は、ファイルと見出し又は行、問題、修正案、重さ、根拠を付けてほしい。読めば確定する誤りと、実行して確かめるべき振る舞いを分ける。主な定理の仮定の変更や新公理を必要とする指摘は、その境界を明記する。独立した確認で問題がなければ、この群を閉じる判断を取りまとめへ返してほしい。

残るものは、L00b.03の参照順序・None/extend、`.04/.05`の閉じた条件と外部受信の検査、O169のL10/L20/L40/L70/R10b/R50の意味・WF・実装・交換の接続である。閉包群第31節のnormContsとbuilderBody_image_norm、緩い捕捉条件からの正則性、範囲外の値変数を行に持つE_Op、型/行/範囲/値の置換の型付けはL20の担当のまま保った。今回の共有層の実装で追加した未完の証明は0件である。

## 変更した既存ファイル

- [formal/Benitoite.lean](../../../formal/Benitoite.lean)
- [formal/Benitoite/Release/Syntax.lean](../../../formal/Benitoite/Release/Syntax.lean)
- [formal/Benitoite/Interval/Domain.lean](../../../formal/Benitoite/Interval/Domain.lean)
- [l00b.02/signatures.md](../l00b.02/signatures.md)
- [l00b.02/results.md](../l00b.02/results.md)
- [l00b.02/large-records.md](../l00b.02/large-records.md)

## 新規ファイルの全一覧

本番の7ファイルは次のとおりである。

- [formal/Benitoite/Interval/ApproxAdapter.lean](../../../formal/Benitoite/Interval/ApproxAdapter.lean)
- [formal/Benitoite/Interval/TypeAdapter.lean](../../../formal/Benitoite/Interval/TypeAdapter.lean)
- [formal/Benitoite/Release/ApproxAdapter.lean](../../../formal/Benitoite/Release/ApproxAdapter.lean)
- [formal/Benitoite/Release/Refinement/ApproxAdapter.lean](../../../formal/Benitoite/Release/Refinement/ApproxAdapter.lean)
- [formal/Benitoite/Shared/Approximation.lean](../../../formal/Benitoite/Shared/Approximation.lean)
- [formal/Benitoite/Shared/Integer.lean](../../../formal/Benitoite/Shared/Integer.lean)
- [formal/Benitoite/Shared/Interval.lean](../../../formal/Benitoite/Shared/Interval.lean)

改造内の新規ファイルは次のとおりである。100 KBを超える一時の生の記録は一覧の外で、large-recordsの表を正とする。

- [02c-axioms-summary.json](../l00b.02/02c-axioms-summary.json)
- [02c-axioms.lean](../l00b.02/02c-axioms.lean)
- [02c-boundary-first.log](../l00b.02/02c-boundary-first.log)
- [02c-boundary.lean](../l00b.02/02c-boundary.lean)
- [02c-boundary.log](../l00b.02/02c-boundary.log)
- [02c-build-record.json](../l00b.02/02c-build-record.json)
- [02c-build.log](../l00b.02/02c-build.log)
- [02c-closures-api.log](../l00b.02/02c-closures-api.log)
- [02c-commands.json](../l00b.02/02c-commands.json)
- [02c-default-imports.lean](../l00b.02/02c-default-imports.lean)
- [02c-default-imports.log](../l00b.02/02c-default-imports.log)
- [02c-delivery.json](../l00b.02/02c-delivery.json)
- [02c-final-check.json](../l00b.02/02c-final-check.json)
- [02c-imports.json](../l00b.02/02c-imports.json)
- [02c-inputs-final.json](../l00b.02/02c-inputs-final.json)
- [02c-local-adapter-final.log](../l00b.02/02c-local-adapter-final.log)
- [02c-old-default-imports.txt](../l00b.02/02c-old-default-imports.txt)
- [02c-old-interval-domain.txt](../l00b.02/02c-old-interval-domain.txt)
- [02c-old-release-syntax.txt](../l00b.02/02c-old-release-syntax.txt)
- [02c-old-statements.lean](../l00b.02/02c-old-statements.lean)
- [02c-old-statements.log](../l00b.02/02c-old-statements.log)
- [02c-original-records.json](../l00b.02/02c-original-records.json)
- [02c-public-api.lean](../l00b.02/02c-public-api.lean)
- [02c-public-api.log](../l00b.02/02c-public-api.log)
- [02c-public-api.md](../l00b.02/02c-public-api.md)
- [02c-shared-imports.lean](../l00b.02/02c-shared-imports.lean)
- [02c-shared-imports.log](../l00b.02/02c-shared-imports.log)
- [02c-source-changes.json](../l00b.02/02c-source-changes.json)
- [02c-start.json](../l00b.02/02c-start.json)
- [02c-validate.py](../l00b.02/02c-validate.py)
- [02c-validation.json](../l00b.02/02c-validation.json)
- [reviews/RV-L00b.02c-request.md](RV-L00b.02c-request.md)（本書）
