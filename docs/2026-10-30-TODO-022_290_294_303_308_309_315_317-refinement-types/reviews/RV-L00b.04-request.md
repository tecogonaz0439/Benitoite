# RV-L00b.04: 閉じた評価の独立レビュー依頼

2026-10-31。B_WORKは `610bd4ebf54905d36c5ccaeb2f6126d7149448a4`、指定ブランチは `m014/l00b.04` である。担当はgitの操作を行っていない。L00b.02/.03を取り込み済みの状態から、L00b.04だけを実装した。本依頼は担当の自己点検の結果であり、独立レビュー済みという意味ではない。

## 読むものと範囲

[完全署名](../l00b.04/signatures.md)、[結果](../l00b.04/results.md)、[公開する完全な型](../l00b.04/public-api.log)、[境界入力](../l00b.04/boundary.lean)と今回の本番の10ファイルを対象とする。承認元はplanの2026-10-31の行、O046/O169、decisionsのD19、l00b.02/signaturesの閉じた評価・第12.2節・第31〜33節、l00a.06a/contracts、l00a.16a/lemmasである。l00b.03のRegularとCaptureOkを分ける判断を変えていない。

外部の三条件・E_External・stepの改訂はL00b.05である。本群は全入れ子のcarrierと検査、成功後の元の型の再構成と、違反時のerrへの補助を提供する。現行の外部遷移が既にこの検査を使うと評価しない。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態を変更していないことも照合する。

## 優先して確認すること

1. Term.observeは失敗を保持し、Term.interpretは演算の各位置で既定値を使う。observe_soundが成功時の一致を述べ、evalClosedはモデルの既定値だけで成功しない。snapshot内の自由変数もWFが拒否するか。
2. evalClosed_sound/completeの条件、ClosedObservableの構文の検査、Not/And/Orの失敗保存が契約に一致するか。sortの不適格、欠けた欄・鍵、未束縛のsnapshotが真にならないか。
3. Entails.closed/groundの導入が既存の全規則と整合し、weaken/cut/bind/soundの全18場合が閉じているか。境界の正例が実値からgroundを経て型付けと捕捉のfactsへ到達し、結論を仮定していないか。
4. Map/Setの大きさが生の列長でなく鍵の重複縮約後の長さか。Decimalの数の等値、元の鍵と後の値、Map/Setの順序の独立、unknown鍵の失敗、FloatのNaNと符号付き0が保たれるか。既存δとの一致はO022の後続段の義務として残っているか。
5. Ty.carrierが全子・行・Telから篩を除き、ExternalCarrierが名目dataの宣言の具体化した欄まで辿るか。HasTypeV P ... v a.carrierだけをdata欄のcarrierと誤認していないか。注釈・kind・鍵の制約を保持することが篩の真の信用になっていないか。
6. externalCheckが結果の最外、List/Setの要素、Mapの鍵/値、dataの全欄へ再帰し、評価の失敗も篩違反も拒否するか。checked_typedが元の型のHasTypeVへ実際に戻すか。sortのない外部ハンドルのtruthの正例と、carrierを満たしてもdata欄の篩を破る負例を照合する。
7. Outcome.CarrierとexternalCheckedOutcomeの提案が、.05で同じ具体化した結果型を使い、no-exitを保ったまま三条件と遷移を改訂できる形か。新しい外部状態・正常応答の存在・決定性・第四の信頼条件を足していないか。
8. ビルドと公理依存の証拠、残りと送り先、場合の数の誤記の訂正を照合する。O169のfailed所属や独立評価とReleaseの対応を、今回のevalClosedの健全性で完了扱いしていないか。

## 場合の数と検査

Term20、Pred14、Observation14、Ty21/Tel2/Eff1、Measure7/Comparison6/FloatClass6、Entails18（旧17+closed）、ClosedObservable4、ExternalCarrier8/Each2/Fields2である。型付け三族各71とTypedFacts56・Step76は変更していない。[機械の一覧](../l00b.04/case-inventory.txt)を参照する。

既定 `cd formal && lake build` は終了0・694 jobs・sorryなし。境界の名前付き定理81件、公開署名135件が通った。新規・変更した9モジュールの生成・非公開を含む1,344宣言を全件確認し、既定importの旧の主定理等を含め計13,546宣言をA-Lで照合した。依存はpropext・Quot.sound・Classical.choiceだけである。Leanの各プロセスのメモリ上限は-M 12288、RSSは計画上の非採取である。

[検査台本](../l00b.04/validate.py)、[コマンドと終了](../l00b.04/commands.json)、[集計](../l00b.04/validation.json)、[公理依存の集計](../l00b.04/axioms-summary.json)、[大きな記録の大きさとハッシュ](../l00b.04/large-records.md)を根拠にする。既存の区間解析側のLean警告88件とリンカー警告7件は開始時と同じソースのものであり、今回のRefinementの変更の警告は0である。Rustとの全比較とworkは今回の担当では行っていない。

## 変更した既存のファイル

- `formal/Benitoite.lean`
- `formal/Benitoite/Release/Refinement/Logic.lean`
- `formal/Benitoite/Release/Refinement/Basic.lean`

## 新規ファイルの全一覧

以下は本依頼自身と検査台本・補助入力・記録を含む。機械での同じ一覧は [new-files.json](../l00b.04/new-files.json) に置く。100 KBを超える生の記録は改造に置かず、large-records.mdの表で別に示す。

- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/axioms-summary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/boundary-first.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/boundary-initial.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/boundary-local.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/boundary.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/build-warnings.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/build.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/case-inventory.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/commands-initial.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/commands.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/declaration-counts.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/delivery.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/final-check.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/final-check.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/new-files.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/public-api-initial.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/public-api.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/public-api.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/public-targets.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/record-location.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/source-changes.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/validate.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.04/validation.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L00b.04-request.md`
- `formal/Benitoite/Release/Refinement/Carrier.lean`
- `formal/Benitoite/Release/Refinement/ClosedDecidable.lean`
- `formal/Benitoite/Release/Refinement/ClosedEvaluation.lean`
- `formal/Benitoite/Release/Refinement/ClosedKeys.lean`
- `formal/Benitoite/Release/Refinement/ExternalCheck.lean`
- `formal/Benitoite/Release/Refinement/LogicSound.lean`
- `formal/Benitoite/Release/Refinement/Observation.lean`

## 未完の義務の送り先

.05は外部の三条件・E_External・stepの改訂、L20/L40は全経路条件・facts・所属と状態保存、.05/L30/L50は実際の組込み表と観測の一致、L60は外部の三モデル、L70/R50は表層・交換を担当する。前群のnormConts・型置換・Regularの形成とO169も指定先のまま残る。取りまとめが独立レビュー後の取り込み、作業末work、設計者の受け入れを行う。
