# `.02a`: snapshotとNoneの位置のWF保存

2026-10-31。B_WORKは `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、指定ブランチは `m014/l00b.02`。再レビューの追記と配分の整理を終えて本番実装を始めたが、公開のWF保存の補題に必要な条件が署名に定まっていないため、既定ビルドが通る区切りで止めた。段の上端77時間と、RV-L00b.02-sig2で妥当と判定されたClosedObservableは停止理由ではない。

## 足りない条件と、確認した範囲

対象は [ValueRegularity.lean](../../../formal/Benitoite/Release/Refinement/ValueRegularity.lean) の `termWF_of_sorted`（36行）、`Pred.wf_of_sorted`（42行）、`Ty.wf_bind_values`（207行）、`Eff.wf_bind_values`（224行）である。現在の本番は整数だけの構文なので、これらの既存の定理の反例を見つけたという報告ではない。以下はsignaturesの全sortの定義へ広げたときの問題である。

signature 1.3はsnapshotのsomeスロットにsortを要求しない。3.4は、snapshotにある参照のWFはすべて検査し、SortedだけからWFを導く旧の系を一般化しない、とする。一方、置換の像の条件はHasSortを持つsourceの位置にだけかかり、SubstOkはNoneの位置の像に条件を置かない。

この三点のもとで、次の入力が作れる。

```text
Γ = [none]
Δ = []
t = measure listLength (listValue [some (var 0)])
ν i = some (var 0)
```

sourceのtはWF 1で、根のsortはintegerである。Γに値の束縛はないので、全sortの像の条件は空に成り立つ。置換後もsnapshotのスロットはsome(var 0)であり、空のΔではWF 0でない。

篩のselfの下では、同じ入力の外側のvar 0がvar 1になる。例えば `List[Unit]{eq (measure listLength (listValue [some (var 1)])) (measure listLength (listValue [some (var 1)]))}` の条件は、sourceではselfとNoneの二位置の下でWFで、sortedでもある。upした像はそのvar 1を残すので、targetのselfだけの一位置ではWFを失う。これは閉じた評価の成否とは独立した、構文の参照の上限の問題である。

[02a-wf-boundary.lean](02a-wf-boundary.lean)は、署名のsnapshot・length・部分的な像に限った有限構文で、次を型検査した。

| 補助定理 | 確認した事実 |
|---|---|
| integer_sort_does_not_imply_wf | 根がinteger sortであってもsnapshotの参照のWFは従わない |
| sorted_images_do_not_preserve_wf | sourceのWF/sortと全sortの像の条件を合わせてもtargetのWFは従わない |
| refinement_self_boundary | selfを一つ置いたときも同じ参照の問題が残る |
| actual_substOk_none | 本番の現行SubstOkがΓ=[none]、Δ=[]、値の像がvar 0でも成り立つ |

最初の三つは拡張する定義の小さい再現であり、本番Term/Predの全構成子を実装して実行したものではない。最後は本番のSubstOkの定義そのものに対する証明である。最終の型検査は終了0、公理依存は許可された三つの部分集合である。コマンドと入力のハッシュは [02a-commands.json](02a-commands.json)、出力は [02a-wf-boundary.log](02a-wf-boundary.log) に保存した。

## 署名3.4の説明だけでは閉じない理由

通常値の型付き像から、その観測像の参照の上限を導く方針は保てる。しかしNoneの位置ではSubstOkに型付き像の証拠がない。したがって「型付きの全像のVarsIn/WFから直接導く」と書くだけでは、上のNoneの入力を扱えない。新しいV_Refine/V_Sub等が要求するDeclaredからsourceの注釈がNoneを読まないことを導く案はあるが、一般の `Ty.wf_bind_values` / `Eff.wf_bind_values` はDeclaredもその参照の条件も受け取っていない。

対応には公開補題の前提の追加、または別の公開定義の変更が要る。影響する型と条件を固定しないまま本番のWF・SubstOk・Transportを強めることはしなかった。今回の停止は、起動依頼の「公開の契約を、署名の改訂の範囲を超えて変える必要が出たら、ビルドが通る区切りで止めて報告する」と、signaturesのS1に従う。

## 改訂の候補（未採用）

推す候補は、WFの保存とsortの保存を別に言明し、WFの補題には次の二つを渡す形である。

1. sourceの注釈に実際に出る全変数の位置が、その束縛の文脈でsomeの型を持つ。self/依存する引数の下は、その文脈を延長して検査する。snapshotのsomeスロットも含め、Noneの位置は読まない。
2. sourceにsomeの型がある位置の観測像は、someならtargetの変数の上限を満たす。像がnoneならスロットから消えるのでWFを失わない。通常値の型付け、contVarのlookup、contLocの閉じた型から導く。

このsourceの参照の条件をDeclaredの補題から得るか、独立した構文の判断として公開するかを、取りまとめが署名へ固定する必要がある。整数の `termWF_of_sorted` も、旧の純粋な整数構文に限る条件を明示するか、全sortの参照の補題へ改める。根がintegerという条件だけでは上のmeasureを除けない。

別案は、ΓのNoneも含む全位置の像のWFを外から要求する形である。一般のWFの補題には足りるが、SubstOkからこの条件を導けないため、Noneの像を制限するか、論理の像を文脈に従ってマスクする契約の変更が要る。この案を黙って採ることはしない。

新公理、主定理への新しい外部前提、snapshotの型付けの除外、提供範囲の縮小は提案していない。公開の補助契約を改訂する案として、独立レビューに返す。

## 本番へ置いたものと残り

[ScopeSyntax.lean](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean)に、16型・60構成子の有限構文、RangeIxのinst/WF、旧Ixの埋め込み、Measureの入出力と5補題を置いた。Typesはこのモジュールを既定importする。既存のTerm/Pred/Ty/Transport/HasType判断は整数の完成範囲のままであり、署名の全sortへ切り替えていない。

既定 `lake build` は604ジョブ、終了0。モジュールの公開・private・生成された宣言を定義元のモジュールで抽出した587宣言の公理依存はpropextだけだった。本番を破損したまま止めたものではないが、`.02a` の完了でもない。

| 残る手順 | 担当 | 見込み |
|---|---|---:|
| sourceの参照の条件と観測像のWFの公開署名を固定し、影響する補題を再レビュー | 取りまとめ・独立レビュー | 能動0.5〜1.5時間の案。待ちは不明 |
| 同じセッションで`.02a`を再開し、Term/Pred/Ty/Tel/Atom/Const、全sortのTransportと既存相互補題をまとめて実装 | 実装担当 | 従来の3〜5時間を維持。今回の有限構文の分だけを機械的に減額しない |
| 全既定ビルド・全新規宣言の公理依存・場合の数を確認 | 実装担当 | 修正と記録は実装の内数。待ちは今回の18.65秒を参考に新しい差分で更新 |
| 群末の独立レビュー・受け入れ、work | 取りまとめ・設計者 | 不明 |

追加の主定理の前提変更が要ることまでは示していない。修正版の公開補題から型付き入力で必要な条件を内部で導けるかをレビューする。
