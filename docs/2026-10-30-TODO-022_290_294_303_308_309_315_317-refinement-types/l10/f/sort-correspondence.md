# O015: sortごとのWF・Sorted・Source・意味の対応

2026-11-01。Sortの13個の引数なしの構成子と、targetの三種類（path/host/endpoint）を16行で列挙した。これは現行定義の実在と対応の確認であり、L30の有限規則の全健全性やL50の所属の全接続の完了ではない。

全行のWFは `TermSyntax.lean` の termWF/Pred.WF（VarsInによる番号の上限）を読む。参照の可読性とsortの検査は `Context.lean` の Term.References/Shape/HasSort と Pred.Sortedであり、Sortedから番号の上限へは Term.references_wf/Pred.references_wfを使う。宣言の存在と欄の照合はDeclaredの別条件で、WFやSortedに含めたと説明しない。数値の表現可能性はConstOKの別条件である。

Sourceは `TermSyntax.lean` のTerm.Source/Pred.Sourceである。内部の複合snapshotとtargetValueはSourceではない。measureはvar又はfieldを入力とするものだけがSourceであり、measureの入れ子や一般の関数呼出しを足さない。

意味の欄は `Observation.lean` のObservation.sort/measure、Term.observe/interpret と `ClosedEvaluation.lean` のObservation.compare、Pred.atomValue/interpret/atomReady/evalWith/evalClosedを対応させる。interpretの既定射影と部分的なobserveの成功を同一視せず、評価不能を真へ変えない。述語のevalWithは強いKleeneの三値である。

| sort | 対象・measure/述語 | WFの対応 | Sortedの対応 | Sourceの対応 | 意味・閉じた評価 |
|---|---|---|---|---|---|
| integer | 七整数とByte、整数定数、加算/負号/定数倍、全measureの出力 | 定数は閉。算術は子のtermWFを連言 | Ty.sort?の七整数/Byte、Term.Shapeのinteger/算術、eq/le/ltはintegerを要求 | 整数定数/var、var又はfieldを入力とするmeasure、許可した算術 | Observation.integer、数学上のInt、integerAsとeq/le/lt |
| character | Character、characterCodeの入力 | 定数は閉。var/fieldは参照の番号 | Ty.sort? character、Term.Shape character、compareの六比較 | character定数、var/field。characterCodeはvar/fieldの観測 | Observation.character、符号の順序、measureはc.toNat |
| float64 | Floatのビット列 | 定数は閉。var/fieldは参照の番号 | Ty.sort? float→float64、Shape float64、floatClass binary64/compare | float64定数、var/field | Observation.float64、ieeeClass/ieeeCompareの52/11、NaN/±0を区別 |
| float32 | Float32のビット列 | 定数は閉。var/fieldは参照の番号 | Ty.sort? float32、Shape float32、floatClass binary32/compare | float32定数、var/field | Observation.float32、ieeeClass/ieeeCompareの23/8。実装の丸めの証明とは別 |
| decimal | Decimalの係数とscale | 定数は閉。var/fieldは参照の番号 | Ty.sort? decimal、Shape decimal、compare/decimalRepresented | decimal定数、var/field | Observation.decimal、10の冪で尺度をそろえた比較、係数とscaleの表現可能性 |
| boolean | Boolean | 定数は閉。var/fieldは参照の番号 | Ty.sort? boolean、Shape boolean、Comparison.Allowedはeq/neだけ | boolean定数、var/field | Observation.boolean、eq/ne。述語のAnd/Or/Notは下の別表 |
| unit | Unit | 定数は閉。var/fieldは参照の番号 | Ty.sort? unit、Shape unit、compareはeq/neだけ | unitValue定数、var/field | Observation.unitValue、等号は真 |
| string | String、stringBytes/stringCharacters、charactersIn | 定数は閉。var/fieldは参照の番号 | Ty.sort? string、Shape string、charactersInはstring、compareはeq/ne | string定数、var/field。二measureの入力はvar/field | Observation.string、utf8ByteSizeとtoList.length、文字ごとの符号の閉区間 |
| list | Listのsnapshot、listLength | 内部snapshotの全some slotの番号を再帰検査 | Ty.sort? list、Shape listValue/measure listLength | var/fieldのみ。listValueは内部の観測用でSourceは偽 | Observation.listValue、slotを保つListの長さ。要素の全観測成功を要求しない |
| bytes | Bytesのsnapshot、bytesLength | 内部snapshotは閉、var/fieldは参照の番号 | Ty.sort? bytes、Shape bytesValue/measure bytesLength | var/fieldのみ。bytesValue自体はSourceでない | Observation.bytesValue、全byte≤255なら長さ、違反時はnone。型付けV_Bytesの前提とは別 |
| map | Mapのsnapshot、mapSize | 内部snapshotの鍵/値の全some slotを再帰検査 | Ty.sort? map、Shape mapValue/measure mapSize | var/fieldのみ。mapValue自体はSourceでない | Observation.mapValue、mapKeysで鍵コードを得て重複を縮約し大きさを観測 |
| set | Setのsnapshot、setSize | 内部snapshotの全some slotを再帰検査 | Ty.sort? set、Shape setValue/measure setSize | var/fieldのみ。setValue自体はSourceでない | Observation.setValue、keySetCodesの重複縮約後の大きさ |
| data | data/record、FieldRef、constructorIs | 内部snapshotの全some欄を再帰検査 | Ty.sort? data、Shape dataValue/field、constructorIsはdata | var/fieldの欄連鎖のみ。dataValue自体はSourceでない | Observation.dataValue、宣言照合した欄の射影、constructor名の一致 |
| target path | Pathの保持対象、member path | targetValueは閉、var/fieldは参照の番号 | Ty.sort? scopedのkind=path、Shape targetValue、memberはtarget path | var/fieldのみ。targetValue自体はSourceでない | Observation.targetValueのpath、SnapshotMem。memberReadyが対象/範囲/σ/解決成功を検査 |
| target host | Hostの保持対象、member host | targetValueは閉、var/fieldは参照の番号 | Ty.sort? scopedのkind=host、Shape targetValue、memberはtarget host | var/fieldのみ。targetValue自体はSourceでない | Observation.targetValueのhost、SnapshotMem。同じkindとスナップショットで読む |
| target endpoint | Endpointの保持対象、member endpoint | targetValueは閉、var/fieldは参照の番号 | Ty.sort? scopedのkind=endpoint、Shape targetValue、memberはtarget endpoint | var/fieldのみ。targetValue自体はSourceでない | Observation.targetValueのendpoint、SnapshotMem。要求の同じ端点と保持内容は型付け側の別条件 |

| 対象の述語 | WF | Sorted | Source | 意味・評価 |
|---|---|---|---|---|
| member k t r | tの番号の上限。rのWF/種類は別の条件 | t.HasSort … (target k) | t.Source | SnapshotMem、memberReady。未解決の所属はevalWith/evalClosedでnoneであり、falseの観測とは区別 |
| constructorIs t c | tの番号の上限 | t.HasSort … data | t.Source | 観測したdataの構成子名とcの一致。欄の宣言の検査を別に保つ |
| truth/falsity | 常にWF | 常にSorted | 常にSource | true/falseの確定値 |
| And/Or/Not | 全子のWF | 全子のSorted | 全子のSource | interpretは二値の論理、evalWith/evalClosedは強いKleene。Not noneはnone、And/Orは未確定の部分が結果を左右しないときだけ確定 |

欄のsortを部分型の元へ反映する観測の準備には、DeclaredだけでなくProgram.VarianceValidを使う（群Vのrv-v-t4のsort_reflect_aux）。L30/L40の担当は、この前提を検証済みの同じPから供給する。
