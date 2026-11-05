# 合成先で同じ名前に置く本体と署名の衝突

再開3で解消した。現在の判定は [results.md の再開3](results.md#再開3)。

初回の停止の記録である。再開1の現在の停止は [元本体内の参照名の衝突](resume1-stop.md) を正とする。内部名の方式はRange.minimumの試行で成功したが、全件の照合でList.mapFromの異なる問題が残った。

L60.04で停止した。L60.05は開始していない。J60-3=(a)を変更したのではなく、E01・E12・E15の証拠を同じlookupへ対応させる条件の不成立を報告する。証拠のある行を仮定側へ移す処置は行わない。

## 再現した不成立

E01の `Range.minimum` は、E15の `StandardOrdinaryCoreBodies.Getter.minimum.publicDefinition` を使う。入力は裸の `Benitoite.Range.CheckedInteger`、名前はvalue、本体は自動getterへのappである。`StandardOrdinaryCoreProgram.declarations_typed (.projection .minimum)` が、lookupと型付けを与える。

E12の同名の子行は `StandardSafe.PreciseGetter.minimum.row` である。入力は同じdataに篩を付けた型、名前はchecked、本体は直接のmatchである。`StandardSafe.precise_row_typed .minimum` がこの行の `BodyTyped` を与える。これは同じDefへの証拠の重複ではない。

[contract-collision.lean](contract-collision.lean) の全称の言明は、任意のPとpreciseについて、次の三条件の連言からFalseを導く。

```lean
StandardSafe.PreciseGetter.minimum.row.definition = some precise
P.defs "Range.minimum" =
  some StandardOrdinaryCoreBodies.Getter.minimum.publicDefinition
P.defs "Range.minimum" = some precise
```

`minimum_bodies_differ` と `minimum_inputs_differ` が、本体と入力型の列それぞれの不一致を証明する。単なる型検査の失敗ではない。両方の元の型付け証拠を同じ検査入力の末尾で適用しており、片方が空疎又は未実装だから生じた衝突でもない。Leanは終了0、三つの反例の公理依存はpropextだけだった。大きな具体値の評価は使わない。

## 現在の契約との差と停止の理由

tablesの照合条件は全出典行から合成行への対応、及び同じ署名・同じ本体のlookupを要求する。一方、同じ名前に採る署名・δは一つである。通常側と精密側を同じlookupの同じDefとして保持する解釈では、上の全称の反例により不成立となる。

精密側だけを採れば、通常側が受け付ける裸のdataをそのまま受け付ける契約を保てない。通常側だけを採って精密側の出典を捨てれば、全既存証拠の対応という完了条件を満たさない。元のどちらかの名前・tel・本体を変更すれば前段の固定署名の変更になる。いずれも担当の判断で行わず、署名の固定を停止した。主定理の形、新公理、精密状態、利用者Pの制限は追加していない。

この反例は同じDefの要求についてのものである。両方の算法の観測上の不一致や、範囲を保った別の合成方式の不可能性までは主張しない。別の実装へ置き換える意味保存や、異なる契約の導出を新しい対応として許す場合は、その対応の言明と完了条件を取りまとめで定める必要がある。

| 選択肢 | 元の条件との差 | 所要と待ち | 実用への影響 |
|---|---|---|---|
| 内部の二つの名前へ分け、同じ元Defをそれぞれ保持する | 証拠からlookupへの対応に名前の対応表を認める。公開名の選択はU02へ先送りしたまま、内部名と公開形を分ける | 未試行で不明。対応表と二行を使う短い試行20〜30分で再見積り。レビュー待ちは不明 | 元の通常入力と精密な内部契約を両方残せる。名前の対応を交換・合成の読者が扱う必要がある |
| 一つの実装に通常契約と精密契約の双方を再証明し、元の証拠との対応を別の関係で示す | 同じ元Defのlookupという条件を、同じ動作と各契約の導出へ置き換える。新しい対応の言明が要る | 未試行で不明。対象一名の試行30〜60分で再見積り。レビュー待ちは不明 | 利用者の書ける形を保つ案である。全出典の本体・署名との対応を別に確認する必要がある |

片方の出典の削除、精密側の仮定分類、裸のdata入力の拒否、Pを制限する案は採っていない。L60.27の80〜140分は、この衝突の処置の実績がないため検証できていない。従来の見込みのまま完了可能とは報告しない。

## 取りまとめへ返す未完

L60.02の七射影・型付けの方式とF08二葉、L60.03のF04/F06の関係は本番に置いた。F07の証明先の形は [standard-contract.md](standard-contract.md) にあるが、採る行と衝突の解消は未確定である。L60.04の台帳は合成**対象**の全出典とRust登録を対応させたものであり、合成済みのlookupの証明ではない。L60.05のcarrier12枝・Args・全F署名の検査と、本体証拠の三種の全件分類は未実施である。
