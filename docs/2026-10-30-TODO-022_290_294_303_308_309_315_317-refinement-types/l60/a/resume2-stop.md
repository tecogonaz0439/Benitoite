# 17名に限定した写像で分離できないList.filterFrom

再開3で解消した。現在の判定は [results.md の再開3](results.md#再開3)。

2026-11-05。再開2の短い試行の準備で、通常の公開filterからの参照に、承認済みの17名の外の衝突を確認した。L60.04と群Aは未完であり、L60.05は未着手である。mapFromと公開mapの4本の試行は、同じP/Bでの全lookup・型付けの完成に至っていない。停止条件を確認した時点で全件への実装の展開を止めた。

## 全本体の参照と、出典に直接含まれないhelper

[reference-inventory.lean](reference-inventory.lean)は全159本体出典について、元Defの本体を構文の構成子へ還元し、fnRefをすべて列挙する。長い具体の列・範囲・閉じた実行は評価せず、関数名の有限の文字列だけを読み取る。[reference_inventory.py](reference_inventory.py)は台帳の159出典との集合一致と重複を照合し、[集計](resume2-reference-summary.json)と分割した全参照グラフを生成する。

129個の異なる元Defのうち44個に、延べ61箇所の関数参照がある。出典行では68行・92箇所である。17衝突名を参照するのは16出典行・14個の異なるDefであり、一覧は集計のsources_referencing_renamed_namesへ保存した。これらを全て合成済みとはしていない。

| 出典 | 元Def・本体 | List.filterFromの要求 |
|---|---|---|
| E01.110 | `(StandardBodies.listHigherRow true).definition` | 通常helper。第3引数に整数0を渡す |
| E13.002 | `StandardHeadTail.fromDefinition true` | 精密helper自身の再帰2箇所。第3引数は残りのList |
| E13.004 | `StandardHeadTail.publicDefinition true` | 精密helper。第3引数に元のListを渡す |

E01〜E15に直接含まれるList.filterFromのDef出典はE13.002だけである。通常helperの `StandardBodies.listFromDefinition true` は、E01.110の既存証明が要求するが、159本体出典に直接登録されていない。そのため、同名の直接出典対だけを比較した前回の17組には現れない。通常helperの既存証拠は `StandardActualListBodies.from_typed true` であり、新しい算法を作る要求ではない。

## 全称の拒否と写像への帰結

[reference-closure-obstruction.lean](reference-closure-obstruction.lean)は、次をLeanのカーネルで証明する。

- `filter_helper_outside`: List.filterFromは承認済みの17名に含まれない。
- `filter_reference_fixed`: 17名以外を固定する任意の名前の写像はList.filterFromを固定する。単射に限定しても同じ結論になる。
- `filter_lookup_incompatible`: 任意Pについて、通常helperと精密helperを同じList.filterFromのlookupへ要求する副条件からFalseを導く。
- `ordinary_call_rejected`: 任意P/B/ストア/文脈/結果/効果と任意Def dについて、dのtelが精密helperのtelと等しく、同名のlookupがdを返すなら、整形式のストア・文脈で通常filterの呼出しを型付ける導出からFalseを導く。本体d.bodyは量化したままである。
- `ordinary_filter_not_typed`: 任意P/B/dについて、精密helperと同じtelのdを同名でlookupできるとき、通常公開filterのDef.WellTypedからFalseを導く。ストア・文脈の整形式性はDef.WellTypedの注釈から供給し、独立の仮定として残さない。
- `ordinary_filter_copy_eq/not_typed`: 通常公開filterの唯一のfnRefへ任意の名前の写像を当てたDefを定義し、17名以外を固定する全写像について元Defと等しいことと、同じ拒否を示す。

`app_tel`・`inv_fnRef`・`TelClosure.apply`で、C_App/C_DependentAppとV_Sub/V_Normal/V_Refineを通る導出も扱う。元の精密telへの引数の移送後、第3引数の整数0をListへ型付ける導出からFalseを得る。これは既存証明の再利用に失敗したという範囲だけの言明ではなく、上記の全称条件での型付けの不成立である。

精密helperの本体だけを名前の写像で変えてもtelは保持されるため、上の任意dに含まれる。通常公開filterの本体はList.filterFrom以外の関数参照を持たず、17名に限った写像では変わらない。したがって今回の許可範囲では両者を同じPで閉じられない。これは、名前の写像をより広い範囲へ適用した場合まで不可能とする言明ではない。

## 差と代案、時間、実用への影響

| 案 | 今回の許可との差 | 次の作業と所要 | 実用への影響 |
|---|---|---|---|
| 参照先のhelperまで写像の対象を閉じる（推奨） | 少なくともList.filterFromを追加し、通常helperの既存Def・証拠も補助の合成行として保持する。直接出典17名だけという範囲を広げる | まずmap/filterの通常・精密helperと公開側を同じP/Bで15〜30分の試行。全参照先の元lookupから必要な補助Defを再帰的に列挙し、全件の所要を再見積りする。全件の時間は現時点では不明 | 元のtel・算法・証拠・裸dataの入力を保持する候補。公開形とU02の選択を伴わない。型付けと全表の充足は未証明 |
| 一方のfilter/helperを削る、通常入力を拒む、telを変える | 提供範囲・元Def保持の条件に反するため採らない | 実装しない | 既存契約を保てない |

List.appendの通常/精密の組込み署名にも差がある。精密な結果を通常型へ忘却して通常本体を再証明する可能性が残るため、この差だけでは不成立と判定していない。List.filterFromの拒否の証明はBを任意に量化しており、この組込み署名の選択に依存しない。

短い試行の単位は08:59:39〜09:05:47 JST、外側6分08秒である。15〜30分の枠は上限の目安とし、停止条件を確かめた後に時間を満たすだけの実装を足していない。現行の17名限定の条件では全件完了の有限の所要を見積もれない。上限11時間30分の超過による停止ではない。能動時間と待ちは未分離であり、外側時間を能動時間としない。

主な10言明、型付け規則、前段の実署名、既存Def・証拠、処理系は変更していない。新しい公理・信頼条件・精密な外部状態も加えていない。今回の反例と参照一覧は改造内の検査入力であり、既定importへ加える本番モジュールではない。写しの更新を要する本番変更も0である。
