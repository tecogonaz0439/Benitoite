# RV-L00b.05: 証明書の葉と外部受信検査のレビュー依頼

2026-10-31。作業L00b.05の群末レビューを依頼する。B_WORKは`0f771fa1789728aa00dc35b1eb6db9ac6345833e`、指定ブランチは`m014/l00b.05`。実装担当はgitの照合・操作を行っていない。レビュー結果・受け入れは未実施である。

[完全署名](../l00b.05/signatures.md)、[結果](../l00b.05/results.md)、[境界入力](../l00b.05/boundary.lean)を起点とする。planの2026-10-31の全行、第12.2・25節、.04の申し送り、READMEの強いKleeneの三値を正とする。external_typedのcarrier化と受信検査は承認済みD28であり、再判断を求める変更ではない。

## 確認してほしい点

1. external_typedの正常結果がOutcome.Carrierだけになり、元の篩の所属をゲストに信頼していないこと。元の宣言の名目dataの欄も扱うOutcome.CarrierとTy.carrierの区別が正しいこと。
2. 宣言と実引数から結果型を具体化するexternalReceiveが、三条件・E_External/E_ExternalErr・stepの同じ入口となること。成功・違反・raw err・exitの扱い、no-exit、obs=[]、ラベルnoneと固定σを照合すること。
3. carrierの値構造からadequateを導き、第四の信頼条件を加えていないこと。HasTypeの実観測からTel.argumentsEnvとtermBindの実際の項を得られ、snapshotのnoneと根の既定値を混同していないこと。
4. 境界入力が、成功と違反それぞれでStateTy→Step→StateTyとstepの選択を結論の仮定なしに示すこと。
5. 証明書の枝内の参照・consume/cases/discard・構文等号によるsubstitute・葉の検査・sortの入口のsoundが成立すること。空でない代表からEntailsを得て、破損した入力を拒否すること。
6. 今回のEqProofは構文等号、PreparedLeafは閉じた葉の代表であり、全sortの意味上の別名合同、否定標準形、線形算術、実δとの全入力の一致を既に証明したと説明していないこと。L30/L50へ固定した前提・結論がO019/O022を受け持ち、主定理の未検査の前提や新しい公理にしていないこと。
7. importの移動が旧体系へ逆向きの依存を追加せず、既定の全対象・旧主定理を維持すること。公理依存の対象が新規・変更のprivate・生成宣言を含むこと。

## 新規ファイルの全一覧

本番の新規は次の3ファイルである。

- `formal/Benitoite/Release/Refinement/Certificate.lean`
- `formal/Benitoite/Release/Refinement/ExternalObservation.lean`
- `formal/Benitoite/Release/Refinement/ExternalConnection.lean`

改造内の新規は次の17ファイル（この依頼を含む）である。

- `l00b.05/signatures.md`
- `l00b.05/results.md`
- `l00b.05/boundary.lean`
- `l00b.05/boundary.log`
- `l00b.05/axioms.lean`
- `l00b.05/axioms-summary.json`
- `l00b.05/axiom-targets.txt`
- `l00b.05/case-inventory.txt`
- `l00b.05/public-api.lean`
- `l00b.05/public-api.log`
- `l00b.05/public-targets.txt`
- `l00b.05/verify.py`
- `l00b.05/verification.json`
- `l00b.05/inputs-sha256.json`
- `l00b.05/build.log`
- `l00b.05/large-records.md`
- `reviews/RV-L00b.05-request.md`

既存の変更は次の5ファイルである。

- `formal/Benitoite/Release/Refinement/ExternalCheck.lean`
- `formal/Benitoite/Release/Refinement/ExternalResponse.lean`
- `formal/Benitoite/Release/Refinement/Semantics.lean`
- `formal/Benitoite/Release/Refinement/Step.lean`
- `formal/Benitoite.lean`

plan・処理系のRust・現行設計書・既存のレビュー記録・rv-*は変更していない。

## 検査と残り

既定`lake build`は増分697 jobsで終了0、境界入力と公開署名の検査も終了0。公理依存は7モジュール764宣言と旧主定理等12宣言、計776で、propext・Quot.sound・Classical.choiceだけである。sorryAxはない。Leanはすべて`-M 12288`を使った。148,307バイトの公理依存の生出力は`<tmp>`へ置き、大きさとSHA-256をlarge-records.mdへ残した。

作業末のworkは取りまとめ担当で未実施。全sortの証明書と実δとの一致はL30/L50、外部三モデルの充足はL60、全状態の保存と表層・交換はL20/L70/R50に残る。受信で拒否したownハンドルの解放も既定のR50/L70の義務を保つ。L00b.11には進んでいない。
